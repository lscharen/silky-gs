; Routines that control the execution into and out of the ROM code.
;
; Execution model
; ---------------
; The runtime is split into two tasks that share the CPU:
;
;   GS  task : the IIgs event loop / renderer, running on the application stack
;   NES task : the NES ROM code, running on the NES stack page (DP_NES+$100)
;
; Each task's full context (P, PC, PBR, A, X, Y, D, DBR) is kept on its own stack and
; only the stack pointer is stored in tcbS.  A task switch pushes the outgoing
; context, swaps S and pops the incoming one, finishing with an RTI.  Because the
; RTI restores P exactly, neither task's processor mode or interrupt state is ever
; assumed.
;
; The NES task is a coroutine.  It runs one NES frame (the NMI handler and, for
; games whose reset code is their main loop, that loop up to its next yield), clears nesBusy and
; voluntarily switches back to the GS task.
;
; With interrupts enabled, the scheduler (schedTask, run by the IRQ.VBL handler irqVbl) only
; decides which task runs.  It never runs ROM code itself:
;
;   - If the GS task is running, it starts a new NES frame (or continues a frame that
;     was cut short) by switching to the NES task.
;   - If the NES task is running, the frame overran the VBL.  After NES_OVERRUN_LIMIT
;     consecutive overruns, the GS task gets the next VBL so that the screen keeps
;     updating.  The game runs slowly instead of starving the renderer.
;   - The 60Hz audio driver is called on every VBL, regardless of the NES state.
;
; A switch is made by redirecting the interrupt's return to irqResume, which runs after the
; firmware interrupt handler has completely finished, so the ROM code always runs outside of
; interrupt context.
;
; With NO_INTERRUPTS (a debugging / profiling mode), there is no scheduler and the
; event loop runs NES frames and renders sequentially through NES_TriggerNMI.

NES_OVERRUN_LIMIT equ 5                   ; Consecutive overrun VBLs before the GS task gets a VBL

; Task state
curTask     dw    0                       ; 0 = GS task, 2 = NES task
tcbS        dw    0,0                     ; Saved stack pointer of each task
nesActive   dw    0                       ; Non-zero once the NES task has been created
nesBusy     dw    0                       ; Non-zero while the NES task owes a frame
nesOverrun  dw    0                       ; Consecutive VBLs that the current NES frame has overrun
irqFrameS   dw    0                       ; The interrupted code's S (irqHook): P at +4; 0 if not native
renderActive ENT
             dw   0                       ; RENDER_VBL_COUNT: non-zero while the GS task is inside RenderScreen
renderVblTicks ENT
               dw 0                       ; RENDER_VBL_COUNT: VBLs counted during the current / last render

; Miscellaneous data fields
singleStepMode dw  0                      ; If non-zero, the runtime will wait for a user keypress between frames
nesStackTop dw    0                       ; Initial NES stack pointer (top of the NES stack page)

; mapper state
mapper_bank ENT
            ds    2                       ; 64kb IIgs bank that holds the current active 16kb NES bank. 2 bytes for convenience.

; switchTask
;
; Voluntarily give the CPU to the other task.  Returns when this task is scheduled
; again with all registers, D, DBR and P preserved.  Callable from either task.
            mx    %00
switchTask
            phk                           ; Build an RTI frame that resumes at :ret
            per   :ret
            php                           ; I flag is captured before the SEI so it is restored by the RTI
            sei
            jmp   saveCtx
:ret        rts

; saveCtx
;
; Common task switch.  Entered with 16-bit registers, interrupts disabled and an RTI
; frame for the outgoing task on top of the stack.
            mx    %00
saveCtx
            pha
            phx
            phy
            phd
            phb

            ldal  curTask
            tax
            tsc
            stal  tcbS,x                  ; Save the outgoing stack

            txa
            eor   #2
            stal  curTask
            tax

            ldal  config_video_nescpu     ; VIDEO > SHOW NES CPU: border color = task that owns the CPU
            beq   :no_border
            sep   #$20
            mx    %10
            ldal  BORDER_REG
            and   #$F0                    ; High nibble is the RTC interface; preserve it
            cpx   #0
            bne   :nes_color
            ora   #TASK_COLOR_GS
            bra   :set_border
:nes_color  ora   #TASK_COLOR_NES
:set_border stal  BORDER_REG
            rep   #$20
            mx    %00
:no_border

            ldal  tcbS,x                  ; Switch to the incoming stack
            tcs

            plb
            pld
            ply
            plx
            pla
            rti

; nesTaskInit
;
; (Re)create the NES task with a fresh stack.  When first scheduled, it calls the
; reset vector.  Called from the GS task.
            mx    %00
nesTaskInit
            php
            sei
            tsc
            tay                           ; Keep the GS stack in Y

            ldal  nesStackTop
            tcs

            phk                           ; RTI frame -> nesTaskMain
            pea   nesTaskMain
            sep   #$20
            lda   #$00                    ; P: 16-bit registers, interrupts enabled
            pha
            rep   #$20
            pea   0                       ; A
            pea   0                       ; X
            pea   0                       ; Y
            ldal  DP_NES                  ; D
            pha
            phk                           ; DBR

            tsc
            stal  tcbS+2

            tya
            tcs

            lda   #2
            stal  nesActive
            plp
            rts

; nesTaskMain
;
; Body of the NES task.  When the reset code is the game's main loop, it never returns
; here; the loop calls yield every frame instead.
            mx    %00
nesTaskMain
            ldal  ROMBase+$FFFC           ; Reset Vector
            jsr   nesCall
:loop
            jsr   nesWaitFrame
            jsr   nesRunNMI
            bra   :loop

; nesWaitFrame
;
; Mark the current NES frame as complete and give the CPU back to the GS task.
; Returns when a new frame should run and the ROM has NMIs enabled.
            mx    %00
nesWaitFrame
            lda   #0
            stal  nesBusy
            stal  nesOverrun
            stal  frameReady
            jsr   switchTask
            ldal  ppuctrl                 ; If the ROM has not enabled VBL NMI, skip this frame
            bit   #$80
            beq   nesWaitFrame
            rts

; nesRunNMI
;
; Execute the ROM's NMI handler on the NES task
            mx    %00
nesRunNMI
            ldal  ROMBase+$FFFA           ; NMI Vector
            jsr   nesCall
            rts

; nesCall
;
; Call into the ROM at the address in the accumulator, in the current mapper bank,
; on the NES task.  The ROM code returns via RTL.
            mx    %00
nesCall
            stal  :disp+1                 ; Save the target address

            ldal  DP_NES
            tcd

            sep   #$30
            ldal  mapper_bank
            stal  :disp+3                 ; Target the current mapper bank for the running code

            lda   #^ROMBase               ; But the base bank is *always* used for the data bank
            pha
            plb

:disp       jsl   $000000                 ; ROM code needs rti->rtl

            rep   #$30
            rts

; yield - allow the ROM to give up control.  Called with JSL from the main loop of games
;         whose reset code is their main loop, when it is waiting for the next VBL.  The
;         current frame is complete; when the next frame starts, the NMI handler runs and control
;         then returns to the main loop.
            mx    %11
yield       ENT
            php
            rep   #$30
            pha
            phx
            phy
            phd
            phb

            phk
            plb
            jsr   nesWaitFrame
            jsr   nesRunNMI

            rep   #$30
            plb
            pld
            ply
            plx
            pla
            plp
            rtl

; NES_ColdBoot / NES_WarmBoot
;
; (Re)start the NES task at the reset vector and run it until the reset code
; completes its first frame (ROM returns or yields).
            mx    %00
NES_ColdBoot
NES_WarmBoot
            jsr   nesTaskInit
            lda   #1
            stal  nesBusy
:wait       jsr   switchTask
            ldal  nesBusy
            bne   :wait
            rts

; Trigger an NMI in the ROM.  Only used when NO_INTERRUPTS is set, where the event
; loop alternates sequentially between NES frames and renders.
            mx    %00
NES_TriggerNMI

; If the audio engine is not running off of its own ESQ interrups at 240Hz or 120Hz, then it must be manually drive
; at 60Hz
            lda   apu_mode                ; The running mode (config_audio_quality is the menu setting)
            bne   :audio_uses_interrupts
            sep   #$30
            jsl   APU_quarter_speed_driver
            rep   #$30
:audio_uses_interrupts

            lda   #1
            stal  nesBusy
:wait       jsr   switchTask              ; Run the NES task until the frame is complete
            ldal  nesBusy
            bne   :wait
            rts

            DO    NO_INTERRUPTS
            ELSE
; Interrupts
;
; Three handlers, installed with SetVector by InstallIrqHandlers (IntStartUp, core/CoreImpl.s):
;
;   irqHook  ($0004, the Interrupt Manager)  runs first for every IRQ and BRK, before the firmware has
;            touched the stack, and only records where the interrupted code's hardware frame is
;   irqVbl   ($000C, IRQ.VBL)                the VBL housekeeping and the scheduler (schedTask)
;   irqScan  ($000A, IRQ.SCAN)               the joystick's scanline interrupts (JoyScanService)
;
; The firmware decides which interrupt it is and calls the IRQ.xxx handlers; they chain to the handlers
; that were there before (the firmware's VBL handler clears the interrupt and runs the heartbeat tasks).

; irqHook
;
; S is the hardware frame's address only in a native-mode interrupt: an emulation-mode one has a 3-byte
; frame with no PBR, so the scheduler can't switch out of it, and irqFrameS = 0.  BRKs are recorded
; too (harmless: the VBL handler doesn't run for them).  The firmware gets the registers, P and the
; mode exactly as they were.
            mx    %11
irqHook
            php
            clc
            xce                           ; C = the interrupted E
            rep   #$20
            mx    %01
            pha                           ; (16-bit, so that tsc doesn't lose B)
            bcs   :emu
            tsc
            stal  irqFrameS               ; Hardware frame: P at +4, PC at +5, PBR at +7
            pla
            plp
irqChain    jml   $000000                 ; The previous Interrupt Manager (InstallIrqHandlers)

:emu        lda   #0
            stal  irqFrameS
            pla
            sec
            xce                           ; Back to emulation mode, then the original P (and C)
            plp
            bra   irqChain

; irqVbl
;
; IRQ.VBL: called (jsl) by the firmware for every VBL, in either mode, with interrupts off.  Runs the
; VBL housekeeping, then the scheduler (schedTask) if the interrupted code's frame is known (a native-mode
; interrupt), then the previous VBL handler.
            mx    %11
irqVbl
            php
            rep   #$30
            pha
            phx
            phy
            phb
            phd

            phk
            plb
            lda   DPSave
            tcd

            DO    APU_STATS
            inc   apu_stat_vbl            ; APU rate check (see apu_stats in apu/apu.s)
            FIN

            ldal  ppustatus               ; The PPU's VBL flag, on every VBL as on the NES (a $2002 read
            ora   #$80                    ; clears it), so ROM code can also spin on it in the NES task
            stal  ppustatus

            lda   skipInterruptHandling
            bne   :out

            DO    RENDER_VBL_COUNT        ; Count the VBLs that elapse during one RenderScreen call
            lda   renderActive
            beq   :not_rendering
            inc   renderVblTicks
:not_rendering
            FIN

; If the audio engine is not running off of its own ESQ interrups at 240Hz or 120Hz, then it must be manually drive
; at 60Hz.  This is done on every VBL so the audio stays real-time, even when the NES code is running slowly.
            lda   apu_mode                ; The running mode (config_audio_quality is the menu setting)
            bne   :audio_uses_interrupts
            sep   #$30
            jsl   APU_quarter_speed_driver
            rep   #$30
:audio_uses_interrupts

            lda   irqFrameS               ; Only switch tasks out of a native-mode interrupt
            beq   :out
            jsr   schedTask

:out        pld
            plb
            ply
            plx
            pla
            plp
vblChain    jml   $000000                 ; The previous VBL handler (InstallIrqHandlers)

; schedTask
;
; The scheduler.  Decides which task runs after this VBL; a switch is made by redirecting the
; interrupt's return (irqSwitch).  Called by irqVbl when irqFrameS is set, with 16-bit registers,
; DBR = this bank, D = the runtime's direct page.
            mx    %00
schedTask
            lda   nesActive
            beq   :out

            lda   curTask
            bne   :nes_running

; The GS task is running.  Give the CPU to the NES task.
            lda   nesBusy
            bne   irqSwitch               ; Continue a frame that was cut short

; (The inputs are read when the game reads its controller: NES_ReadJoy, rom_input.s)

            lda   singleStepMode
            bne   :out

            lda   #1
            sta   nesBusy
            bra   irqSwitch

; The NES task is running, so the current frame did not finish within one VBL.
:nes_running
            lda   nesBusy
            beq   :out
            inc   nesOverrun
            lda   nesOverrun
            cmp   #NES_OVERRUN_LIMIT+1
            bcc   :out

            ldx   irqFrameS               ; Never preempt the NES task in the ENGINE segment (e.g. halfway
            sep   #$20                    ; through a PPU write: the shims in ppu_regs.s); try again on the
            ldal  $000007,x               ; next VBL.  Code the NES task must not be preempted in goes there.
            cmp   #^RenderLatch           ; Interrupted PBR = the ENGINE bank?
            rep   #$20
            beq   :out

            stz   nesOverrun
            stz   frameReady              ; Let the renderer show the partially completed frame
            bra   irqSwitch
:out        rts

; irqSwitch
;
; Make the interrupt return to irqResume rather than to the interrupted code: its hardware frame's P,
; PC and PBR are saved (irqSave*) and replaced with P = native, 16-bit registers, interrupts off, and
; irqResume.  The firmware's RTI then lands there with the interrupted task's registers restored.
            mx    %00
irqSwitch
            ldx   irqFrameS
            ldal  $000005,x               ; PC
            sta   irqSavePC
            sep   #$20
            ldal  $000004,x               ; P
            sta   irqSaveP
            ldal  $000007,x               ; PBR
            sta   irqSavePBR
            lda   #$04                    ; P: I = 1, M = X = 0
            stal  $000004,x
            phk
            pla
            stal  $000007,x
            rep   #$20
            lda   #irqResume
            stal  $000005,x
            rts

irqSaveA    dw    0                       ; irqResume's saved A
irqSavePC   dw    0                       ; The interrupted code's hardware frame (irqSwitch)
irqSaveP    db    0
irqSavePBR  db    0

; irqResume
;
; Where an interrupt that switches tasks returns, after the firmware handler has completely finished
; (interrupts off, 16-bit registers, the interrupted task's registers, D and DBR).  Puts the interrupted
; code's hardware frame back on the stack, which is exactly the form that saveCtx expects.
            mx    %00
irqResume
            stal  irqSaveA
            sep   #$20
            ldal  irqSavePBR
            pha
            rep   #$20
            ldal  irqSavePC
            pha
            sep   #$20
            ldal  irqSaveP
            pha
            rep   #$20
            ldal  irqSaveA
            jmp   saveCtx

; irqScan
;
; IRQ.SCAN: called (jsl) by the firmware for a scanline interrupt.  While the joystick has armed them
; (JoyScanArm, core/blitter/JoyProbes.s), JoyScanService takes it and clears it; otherwise the previous
; handler does.
            DO    JOYSTICK_SUPPORT
            mx    %11
irqScan
            php
            ldal  joyScanArmed
            beq   :chain
            rep   #$30
            jsl   JoyScanService
            plp
            clc                           ; Serviced
            rtl
:chain      plp
scanChain   jml   $000000                 ; The previous scanline handler (InstallIrqHandlers)
            FIN

; InstallIrqHandlers / RemoveIrqHandlers
;
; Called by IntStartUp / IntShutDown: 16-bit registers, DBR = this bank.  irqHook goes in first and comes
; out last, so irqVbl never sees a stale irqFrameS.  InstallIrqHandlers returns C set if a toolbox call
; failed.
SV_INT_MGR  equ   $0004                   ; SetVector / GetVector vector numbers
SV_IRQ_SCAN equ   $000A
SV_IRQ_VBL  equ   $000C

            mx    %00
InstallIrqHandlers
            stz   irqFrameS
            ldx   #irqChain+1
            ldy   #SV_INT_MGR
            lda   #irqHook
            jsr   :install
            bcs   :done

            ldx   #vblChain+1
            ldy   #SV_IRQ_VBL
            lda   #irqVbl
            jsr   :install

            DO    JOYSTICK_SUPPORT
            bcs   :done
            ldx   #scanChain+1
            ldy   #SV_IRQ_SCAN
            lda   #irqScan
            jsr   :install
            FIN
:done       rts

; X = the JML operand that gets the old handler, Y = the vector, A = the new handler (in this bank)
:install    sta   irqNewL
            stx   irqOperand
            sty   irqVector

            pea   0                       ; The old handler
            pea   0
            phy
            _GetVector
            ldx   irqOperand
            pla
            sta:  0,x
            pla
            sep   #$20
            sta:  2,x
            rep   #$20
            bcs   :error

            lda   irqVector
            pha
            phk                           ; The new handler: this bank
            phk
            pla
            and   #$00FF
            pha
            lda   irqNewL
            pha
            _SetVector
:error      rts

            mx    %00
RemoveIrqHandlers
            DO    JOYSTICK_SUPPORT
            ldx   #scanChain+1
            ldy   #SV_IRQ_SCAN
            jsr   :restore
            FIN
            ldx   #vblChain+1
            ldy   #SV_IRQ_VBL
            jsr   :restore
            ldx   #irqChain+1
            ldy   #SV_INT_MGR

; X = the JML operand that has the old handler, Y = the vector
:restore    phy
            lda:  2,x
            and   #$00FF
            pha
            lda:  0,x
            pha
            _SetVector
            rts

irqNewL     dw    0                       ; InstallIrqHandlers' scratch
irqOperand  dw    0
irqVector   dw    0
            FIN

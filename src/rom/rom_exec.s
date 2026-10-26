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
; With interrupts enabled, the scheduler (schedTask, run by irqPost after every native-mode VBL) only
; decides which task runs.  It never runs ROM code itself:
;
;   - If the GS task is running, it starts a new NES frame (or continues a frame that
;     was cut short) by switching to the NES task.
;   - If the NES task is running, the frame overran the VBL.  After NES_OVERRUN_LIMIT
;     consecutive overruns, the GS task gets the next VBL so that the screen keeps
;     updating.  The game runs slowly instead of starving the renderer.
;   - The 60Hz audio driver is called on every VBL, regardless of the NES state.
;
; irqHook redirects a VBL interrupt's return to irqPost, which runs after the interrupt handling (the
; firmware's included) has completely finished, so the scheduling and the ROM code always run outside
; of interrupt context, and no stack address is kept from one interrupt to the next.
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
engineVideoOn ENT
            dw    0                       ; Non-zero once the engine has turned SHR on (_GrafOn, core/Graphics.s)
engineSuspended dw 0                      ; Non-zero while something else has the display (irqVbl)

; irqHook takes the engine's interrupts itself, without the firmware's IRQ dispatch.  It leaves the VBL to
; the firmware (irqVbl) while something needs the system's interrupt handling: a GS/OS call in progress
; (irqSysDepth, IrqSystemEnter / Leave around misc/io.s) or the engine suspended (the CDA menu, which runs
; on the firmware's VBL handling).  Otherwise the firmware's VBL handler doesn't run: its heartbeat tasks
; (cursor, Event Manager, ...) stop, which the engine doesn't use.
irqSysDepth dw    0
irqTaken    db    0                       ; irqHook: one of the engine's sources was handled in this pass
irqPass     db    0                       ; irqHook: one is the firmware's (follows irqTaken: cleared together)
irqPostWork dw    0                       ; irqHook: irqPost runs vblWork (0: the firmware's irqVbl did)
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

; CHR-ROM bank switching (CNROM): the 8KB CHR-ROM bank the ROM selected, and a flag set when it changes.
; The ROM's bank write sets both; the game's PRE_RENDER loads the bank into CHR_ROM (PPU_ReloadCHR).
ppu_bank    ENT
            ds    2
ppu_bank_changed ENT
            ds    2

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

; irqPost enters here with the registers already pushed
saveCtxSwitch
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

; IrqSystemEnter / IrqSystemLeave
;
; Around code that needs the system's own interrupt handling (GS/OS calls: misc/io.s): irqHook leaves
; the VBL to the firmware from the first Enter to the matching Leave (they nest).  Keep A, X, Y and P (Leave keeps
; the caller's C).  16-bit registers, any data bank.
            mx    %00
IrqSystemEnter
            php
            pha
            ldal  irqSysDepth
            inc
            stal  irqSysDepth
            pla
            plp
            rts

IrqSystemLeave
            php
            pha
            ldal  irqSysDepth
            dec
            stal  irqSysDepth
            pla
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
            DO    APU_STATS
            ldal  apu_stat_nmi            ; (apu/apu.s)
            inc
            stal  apu_stat_nmi
            FIN
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
; Two handlers, installed with SetVector by InstallIrqHandlers (IntStartUp, core/CoreImpl.s):
;
;   irqHook  ($0004, the Interrupt Manager)  runs first for every IRQ and BRK, before the firmware has
;            touched the stack: records where the interrupted code's hardware frame is and handles the
;            engine's interrupt sources itself (scanline, DOC timer, VBL)
;   irqVbl   ($000C, IRQ.VBL)                the VBL work for the VBLs left to the firmware (a GS/OS call
;            in progress, the engine suspended, bank 0 I/O off); chains to the previous VBL handler
;
; Everything else goes to the firmware, which decides which interrupt it is and calls the IRQ.xxx handlers.

; irqHook
;
; One pass over the engine's sources, in order of latency, each handled if it is pending:
;
;   1. The joystick's scanline interrupts (JoyScanService), while armed during dirty renders
;   2. The DOC timer oscillator (APU_timer_tick), the 120 / 240Hz audio
;   3. The VBL: the interrupt's hardware frame (P at 4,s, PC at 5,s, PBR at 7,s) is redirected to
;      irqPost (saved in irqSave*), which runs vblWork and the scheduler after the rti
;
; Then rti if any of them was handled.  Nothing else is cleared, so another pending source holds the IRQ
; line and comes right back here; a pass that finds none of ours goes to the firmware.  A scanline pass
; skips the DOC test: the scanline interrupts come dozens of times a frame, and testing the DOC (~75
; cycles with the GLU's registers kept) costs about what a second pass for a pending tick does.  Two go
; to the firmware in the same pass: an interrupt from another DOC oscillator (reading the DOC's
; oscillator interrupt register has acknowledged it, as the firmware's own dispatch does) and a VBL that
; the firmware must take.  Through the firmware, a DOC timer tick cost ~6,800 cycles (~5,900 of them its
; dispatch) and a VBL ~1,100 more than here; a scanline interrupt ~715 (~550 the dispatch).
;
; An emulation-mode interrupt has a 3-byte frame with no PBR, so the scheduler can't switch out of it:
; the firmware takes it, and irqVbl runs only vblWork (the dirty renders that arm the scanline interrupts
; run in native mode).  A VBL the firmware must take (a GS/OS call in progress, bank 0 I/O off) is
; redirected all the same, to run only the scheduler: the firmware's rti lands in irqPost after irqVbl.  BRKs (the firmware's stubs at
; $C071 / $C074 enter with V set for a BRK, clear for an IRQ) go to the firmware.  The firmware gets the
; registers, P and the mode exactly as they were.
;
; The register widths on entry are the interrupted code's: the tests run with an 8-bit A (A is saved in
; full first); X and Y are saved before anything that uses them.
            mx    %11
irqHook
            php
            clc
            xce                           ; C = the interrupted E
            bcc   :native
            xce                           ; An emulation-mode interrupt (C = 1): the firmware's.  Back to
                                          ; emulation mode, then the original P (and C)
            plp
            brl   irqChain

:native     rep   #$20
            mx    %01
            pha                           ; A in full (B too: the handlers use 16-bit A)
            bvc   :irq
            brl   irqHookChain            ; A BRK
:irq
            lda   #0
            stal  irqTaken                ; (and irqPass)
            sep   #$20
            mx    %11                     ; (X: the interrupted code's width; no X immediates)

            DO    JOYSTICK_SUPPORT
            ldal  VGC_INT_REG             ; (8-bit: $C024 is the mouse data, read-sensitive)
            and   #$20                    ; Scanline interrupt pending?
            beq   :doc
            lda   #$FF-$20
            stal  VGC_INT_CLEAR           ; Clear it
            stal  irqTaken                ; (A non-zero)
            ldal  joyScanArmed            ; (only armed during dirty renders)
            beq   :vbl
            jsl   JoyScanService          ; (core/blitter/JoyProbes.s; keeps every register)
            bra   :vbl                    ; (no DOC test: a pending tick comes right back)
            FIN

:doc        ldal  apu_mode                ; The DOC timer runs the audio (120 / 240Hz)?
            beq   :vbl
            ldal  SHADOW_REG              ; The APU reaches the GLU through D = $C000: bank 0 I/O must be on
            and   #$40
            bne   :vbl
            ldal  $E0C03C                 ; The sound GLU's control and address registers, put back after:
            pha                           ; the interrupted code may be using them
            ldal  $E0C03E
            pha
            ldal  $E0C03F
            pha
            ldal  irq_volume              ; DOC registers, no auto-increment (access_doc_registers)
            stal  $E0C03C
            lda   #$E0                    ; The oscillator interrupt register (reading it acknowledges
            stal  $E0C03E                 ; the interrupt)
            ldal  $E0C03D                 ; (the first read returns the previous value)
            ldal  $E0C03D
            bmi   :doc_done               ; Bit 7 set: no oscillator interrupt
            and   #%00111110
            cmp   #2*interrupt_oscillator
            beq   :tick
            lda   #1                      ; Another oscillator's: the firmware's
            stal  irqPass
            bra   :doc_done

:tick       rep   #$10                    ; X / Y in full
            phx
            phy
            sep   #$10
            jsl   APU_timer_tick          ; (apu/apu.s; 8-bit registers, keeps none)
            rep   #$10
            ply
            plx
            lda   #1
            stal  irqTaken

:doc_done   pla                           ; The GLU's registers back
            stal  $E0C03F
            pla
            stal  $E0C03E
            pla
            stal  $E0C03C

:vbl        ldal  $E0C046                 ; Mega II interrupt flags: bit 3 = VBL
            and   #$08
            beq   :exit
            ldal  engineSuspended         ; Suspended (the CDA menu runs on the firmware's VBL handling):
            bne   :vbl_fw                 ; the firmware's, and no scheduling
            ldal  SHADOW_REG              ; The firmware takes it while bank 0 I/O is off (the 60Hz audio
            and   #$40                    ; reaches the GLU through D = $C000) or a GS/OS call is in
            oral  irqSysDepth             ; progress (IrqSystemEnter / Leave): irqPost only schedules
            bne   :vbl_sys
            stal  $E0C047                 ; Clear the VBL (and quarter second) interrupt: any write
            inc
            stal  irqTaken
            bra   :redirect               ; (A = 1: irqPost runs vblWork)

:vbl_sys    lda   #1                      ; The firmware's, in this same pass (irqVbl runs vblWork)
            stal  irqPass
            dec
:redirect   stal  irqPostWork
            lda   4,s                     ; The hardware frame's P and PBR to irqSave*, and P = interrupts
            stal  irqSaveP                ; off, 16-bit registers, PBR = this bank
            lda   7,s
            stal  irqSavePBR
            lda   #$04
            sta   4,s
            phk
            pla
            sta   7,s
            rep   #$20
            lda   5,s                     ; The PC
            stal  irqSavePC
            lda   #irqPost
            sta   5,s
            sep   #$20
            bra   :taken

:vbl_fw     lda   #1                      ; In this same pass
            stal  irqPass
:exit       ldal  irqTaken                ; None of ours: the firmware's
            beq   irqHookChain
:taken      ldal  irqPass
            bne   irqHookChain
            rep   #$20
            pla
            plp
            rti

; To the firmware: A (16-bit) and P pushed, native mode, either A width
irqHookChain
            rep   #$20
            mx    %01
            DO    APU_STATS
            ldal  apu_stat_chain          ; Interrupts left to the firmware (apu/apu.s)
            inc
            stal  apu_stat_chain
            FIN
            pla
            plp
irqChain    jml   $000000                 ; The previous Interrupt Manager (InstallIrqHandlers)

; irqVbl
;
; IRQ.VBL: called (jsl) by the firmware for the VBLs that irqHook leaves to it, with interrupts off.  Runs
; the VBL work, then the previous VBL handler.  The scheduling is irqPost's (a native-mode interrupt).
            mx    %11
irqVbl
            php
            rep   #$30
            pha
            phx
            phy
            phb
            phd
            jsr   vblWork
            pld
            plb
            ply
            plx
            pla
            plp
vblChain    jml   $000000                 ; The previous VBL handler (InstallIrqHandlers)

; vblWork
;
; The VBL work, for irqPost and irqVbl (the VBLs left to the firmware): the VBL housekeeping, the
; suspension test and the 60Hz audio.  16-bit registers; B and D are set here (the callers save them).
            mx    %00
vblWork
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

; The CDA menu (or another system screen) has the display: the Desk Manager turns SHR off for it and puts
; it back afterwards.  While it is off (once the engine has turned it on), the engine is suspended: no task
; switches, so the game doesn't run under the menu, and the APU silent.
            lda   engineVideoOn
            beq   :set_susp               ; (A = 0: not suspended)
            sep   #$20
            ldal  NEW_VIDEO_REG
            rep   #$20
            and   #$0080
            eor   #$0080                  ; Non-zero when SHR is off
:set_susp   sta   engineSuspended
            stal  apu_suspended           ; (apu/apu.s)

; If the audio engine is not running off of its own ESQ interrups at 240Hz or 120Hz, then it must be manually drive
; at 60Hz.  This is done on every VBL so the audio stays real-time, even when the NES code is running slowly.
            lda   apu_mode                ; The running mode (config_audio_quality is the menu setting)
            bne   :audio_uses_interrupts
            sep   #$30
            jsl   APU_quarter_speed_driver
            rep   #$30
:audio_uses_interrupts

:out        rts

; schedTask
;
; The scheduler.  Decides which task runs after this VBL: returns C = 1 to switch tasks.  Called by
; irqPost with 16-bit registers, DBR = this bank, D = the runtime's direct page.
            mx    %00
schedTask
            lda   nesActive
            beq   :out

            lda   curTask
            bne   :nes_running

; The GS task is running.  Give the CPU to the NES task.
            lda   nesBusy
            bne   :switch                 ; Continue a frame that was cut short

; (The inputs are read when the game reads its controller: NES_ReadJoy, rom_input.s)

            lda   singleStepMode
            bne   :out

            lda   #1
            sta   nesBusy
:switch     sec
            rts

; The NES task is running, so the current frame did not finish within one VBL.
:nes_running
            lda   nesBusy
            beq   :out
            inc   nesOverrun
            lda   nesOverrun
            cmp   #NES_OVERRUN_LIMIT+1
            bcc   :out

            sep   #$20                    ; Never preempt the NES task in the ENGINE segment (e.g. halfway
            lda   irqSavePBR              ; through a PPU write: the shims in ppu_regs.s); try again on the
            cmp   #^RenderLatch           ; next VBL.  Code the NES task must not be preempted in goes there.
            rep   #$20                    ; (The interrupted PBR = the ENGINE bank?)
            beq   :out

            stz   nesOverrun
            stz   frameReady              ; Let the renderer show the partially completed frame
            sec
            rts
:out        clc
            rts

irqSaveA    dw    0                       ; irqPost's saved A
irqSavePC   dw    0                       ; The interrupted code's hardware frame (irqHook)
irqSaveP    db    0
irqSavePBR  db    0

; irqPost
;
; Where a native-mode interrupt with a VBL returns (irqHook redirects its hardware frame), after the
; interrupt handling has completely finished: interrupts off, 16-bit registers, the interrupted code's
; registers, D and DBR.  Puts the interrupted code's hardware frame back on the stack and the registers
; on top of it, as saveCtx does, runs the VBL work (unless the firmware's irqVbl did) and the scheduler,
; then either returns to the interrupted code or switches tasks (saveCtxSwitch).  No scheduling while
; suspended, nor out of the firmware or the toolbox (PBR $E0 - $FF: e.g. the Desk Manager entering the
; CDA menu).
            mx    %00
irqPost
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
            pha
            phx
            phy
            phd
            phb

            phk
            plb
            lda   DPSave
            tcd
            lda   irqPostWork
            beq   :sched
            jsr   vblWork

:sched      lda   skipInterruptHandling
            ora   engineSuspended
            bne   :ret
            sep   #$20
            lda   irqSavePBR
            cmp   #$E0
            rep   #$20
            bcs   :ret
            jsr   schedTask
            bcc   :ret
            jmp   saveCtxSwitch

:ret        plb
            pld
            ply
            plx
            pla
            rti

; InstallIrqHandlers / RemoveIrqHandlers
;
; Called by IntStartUp / IntShutDown: 16-bit registers, DBR = this bank.  Both handlers go in and come out
; with interrupts off, so neither runs without the other.  InstallIrqHandlers returns C set if a toolbox
; call failed.
SV_INT_MGR  equ   $0004                   ; SetVector / GetVector vector numbers
SV_IRQ_VBL  equ   $000C

            mx    %00
InstallIrqHandlers
            php
            sei
            ldx   #irqChain+1
            ldy   #SV_INT_MGR
            lda   #irqHook
            jsr   :install
            bcs   :fail

            ldx   #vblChain+1
            ldy   #SV_IRQ_VBL
            lda   #irqVbl
            jsr   :install
            bcs   :fail
            plp
            clc
            rts
:fail       plp
            sec
            rts

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
            php
            sei
            ldx   #vblChain+1
            ldy   #SV_IRQ_VBL
            jsr   :restore
            ldx   #irqChain+1
            ldy   #SV_INT_MGR
            jsr   :restore
            plp
            rts

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

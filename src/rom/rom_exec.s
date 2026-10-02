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
; ROM_DRIVER_MODE games, the main loop up to its next yield), clears nesBusy and
; voluntarily switches back to the GS task.
;
; With interrupts enabled, the VBL heartbeat (schedTask) is a pure scheduler.  It
; never runs ROM code itself:
;
;   - If the GS task is running, it starts a new NES frame (or continues a frame that
;     was cut short) by switching to the NES task.
;   - If the NES task is running, the frame overran the VBL.  After NES_OVERRUN_LIMIT
;     consecutive overruns, the GS task gets the next VBL so that the screen keeps
;     updating.  The game runs slowly instead of starving the renderer.
;   - The 60Hz audio driver is called on every VBL, regardless of the NES state.
;
; Switches requested by the scheduler are carried out by irqPost after the firmware
; interrupt handler has completely finished, so the ROM code always runs outside of
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
switchPending dw  0                       ; Set by the scheduler, consumed by irqPost
irqFrameS   dw    0                       ; Address of the hardware IRQ frame while in a native-mode IRQ, else 0
renderActive dw   0                       ; RENDER_VBL_COUNT: non-zero while the GS task is inside RenderScreen
renderVblTicks dw 0                       ; RENDER_VBL_COUNT: VBLs counted during the current / last render

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

            DO    TASK_TIME_BORDER        ; Raster bar: border color = task that owns the CPU
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
            FIN

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
; Body of the NES task.  For ROM_DRIVER_MODE games, the reset code never returns
; here; its main loop calls yield every frame instead.
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
            DO    SHOW_ROM_EXECUTION_TIME
            lda   #2
            jsr   _SetBorderColor
            FIN

            ldal  ROMBase+$FFFA           ; NMI Vector
            jsr   nesCall

            DO    SHOW_ROM_EXECUTION_TIME
            lda   #0
            jsr   _SetBorderColor
            FIN
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

; yield - allow the ROM to give up control.  Called with JSL from the NES main loop of
;         ROM_DRIVER_MODE games when it is waiting for the next VBL.  The current frame
;         is complete; when the next frame starts, the NMI handler runs and control
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

; Each call to NES_TriggerNMI represents one virtual 1/60th-of-a-second
; NES frame boundary, regardless of how many times NES_ReadInput itself
; gets called within it -- so this is where the MAME bench harness's
; canned input index advances (see BENCH_MODE / BenchInputData in the
; game's Main.s, and src/rom/rom_input.s).
            DO    BENCH_MODE
            ldal  BenchInputIndex
            inc
            stal  BenchInputIndex
            FIN

; If the audio engine is not running off of its own ESQ interrups at 240Hz or 120Hz, then it must be manually drive
; at 60Hz
            lda   config_audio_quality
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
; Scheduler
;
; VBL heartbeat task.  Runs inside the firmware interrupt handler and only decides
; which task should run; the switch itself is performed by irqPost.
            mx    %11
schedTask
            php
            rep   #$30
            phb
            phd

            phk
            plb
            lda   DPSave
            tcd

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
            lda   config_audio_quality
            bne   :audio_uses_interrupts
            sep   #$30
            jsl   APU_quarter_speed_driver
            rep   #$30
:audio_uses_interrupts

            lda   nesActive
            beq   :out
            lda   irqFrameS               ; Only switch tasks out of a native-mode IRQ
            beq   :out

            lda   curTask
            bne   :nes_running

; The GS task is running.  Give the CPU to the NES task.
            lda   nesBusy
            bne   :switch                 ; Continue a frame that was cut short

            ldal  ppustatus               ; Set the bit that the VBL has started
            ora   #$80
            stal  ppustatus

            jsr   NES_ReadInput           ; Put the IIgs inputs into the NES controller bytes

            lda   singleStepMode
            bne   :out

            DO    BENCH_MODE              ; See NES_TriggerNMI
            ldal  BenchInputIndex
            inc
            stal  BenchInputIndex
            FIN

            lda   #1
            sta   nesBusy
            bra   :switch

; The NES task is running, so the current frame did not finish within one VBL.
:nes_running
            lda   nesBusy
            beq   :out
            inc   nesOverrun
            lda   nesOverrun
            cmp   #NES_OVERRUN_LIMIT+1
            bcc   :out

            ldx   irqFrameS               ; Never preempt the NES task inside the runtime (e.g. halfway
            sep   #$20                    ; through a PPU write); try again on the next VBL
            ldal  $000004,x               ; Interrupted PBR
            cmp   #^schedTask
            rep   #$20
            beq   :out

            stz   nesOverrun
            stz   frameReady              ; Let the renderer show the partially completed frame
:switch
            lda   #1
            sta   switchPending
:out
            pld
            plb
            plp
            rtl

; IRQ hook
;
; Installed at $E1/0010, ahead of the firmware interrupt handler.  For native-mode
; IRQs it records the location of the hardware interrupt frame and pushes a fake
; RTI frame so that the firmware returns to irqPost instead of the interrupted code.
; BRKs (V=1) and emulation-mode interrupts are passed through untouched.
            mx    %00
irqHook
            clc
            xce                           ; C = interrupted E flag; now native (firmware does the same)
            bcs   :emu
            bvs   :chain                  ; BRK: leave the frame alone

            rep   #$30                    ; The firmware switches to 16-bit registers too
            pha
            tsc
            inc
            inc
            stal  irqFrameS               ; Hardware frame: P at +1, PC at +2, PBR at +4
            pla

            phk                           ; Fake RTI frame -> irqPost (P: I=1, 16-bit)
            per   irqPost
            php
:chain      jml   irqChain

:emu        sec
            xce
            jml   irqChain

irqChain    ds    4                       ; Copy of the original $E1/0010 JML

; The firmware interrupt handler is completely done.  The interrupted task's registers
; are restored and its hardware frame is on top of the stack, which is exactly
; the form that saveCtx expects.
            mx    %00
irqPost
            pha
            lda   #0
            stal  irqFrameS
            ldal  switchPending
            bne   :switch
            pla
            rti
:switch
            lda   #0
            stal  switchPending
            pla
            jmp   saveCtx

; Install / remove the IRQ hook
            mx    %00
InstallIrqHook
            php
            sei
            ldal  $E10010
            stal  irqChain
            ldal  $E10012
            stal  irqChain+2

            sep   #$20
            lda   #$5C                    ; JML irqHook
            stal  $E10010
            lda   #^irqHook
            stal  $E10013
            rep   #$20
            lda   #irqHook
            stal  $E10011
            plp
            rts

            mx    %00
RemoveIrqHook
            php
            sei
            ldal  irqChain
            stal  $E10010
            ldal  irqChain+2
            stal  $E10012
            plp
            rts
            FIN

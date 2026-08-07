; Routines that control the execution into and out of the ROM code.  Depending on how
; a NES ROM is structures, there are different methods of control flow.

            mx  %00

; Simple ROM control transfer. This acts like an interrupt to the ROM code in the sense
; that we do restore the ROM stack pointer, but jump to an absolute address and
; the registers can be any value.
;
; X = ROM Address
;
; The code sets up the NES environment such that
;
; S = stack address from the last yield or ExtRtn
; D = NES direct page location
; K = mapper_bank
;
; All of the registers are left because, since this simulated an interrupt, the
; interrupt handler could be called with arbitrary values in the registers.
;
; See the resume function for the control where the ROM code voluntarily returns
; control via the yield entry point

; Interrupts must be disabled
            mx  %00
romxfer                 
            tsc
            sta   StkSave                   ; Save the current stack in the main program

            lda   DP_NES
            tcd

            stx   :disp+1                   ; Save the target address

            ldx   yield_s                   ; Put 16-bit stack addr in X to protect against NES code using TXS
            txs

            sep   #$30

;            lda   mapper_bank
;            sta   :disp+3                   ; Target the current mapper bank
            lda   #^ROMBase
            pha
            plb

; :disp       jsl   $000000                   ; breaking change; ROM code needs rti->rtl, not rti->rts like it was
:disp       jsl   ROMBase

; We do not need to save the databank register.  The MMC1 shims are responsible for updating mapper_bank
; when they are called from the ROM code.

            mx  %00
            rep   #$30                      ; Back to 16-bit mode

            tsx                             ; Copy the stack address returned by the emulator
            
            ldal  StkSave
            tcs

            phk
            plb

            lda   DPSave
            tcd
            stx   yield_s                   ; Keep an updated copy of the stack address

            rts

; Miscellaneous data fields
singleStepMode dw  0                        ; If non-zero, the runtime will wait for a user keypress between frames

; Location to save the 16-bit stack from the native IIgs execution context
StkSave     dw    0

; yield - allow the ROM to give up control.  Only one yield may be active at a given time. This
;         must be called from the NES ROM code, so 8-bit execution and the relevant softswitch
;         states are assumed and not specifically saved.
yield_a     ds    1
yield_x     ds    1
yield_y     ds    1
yield_p     ds    1
yield_s     ds    2                         ; 2 bytes so we can load/save the full 16-bit stack pointer

; mapper state
mapper_bank ENT
            ds    2                         ; 64kb IIgs bank that holds the current active 16kb NES bank. 2 bytes for convenience.

            mx    %11
yield       ENT

; First, preserve the state from the ROM code

            phk
            plb                             ; Reset the bank register.

            php
            sta   yield_a                   ; Save all of the volatile registers
            pla
            sta   yield_p
            stx   yield_x
            sty   yield_y
            tsx
            stx   yield_s

            rep   #$30
            lda   DPSave
            tcd
            lda   StkSave
            tcs
            rts

; resume - return control to the NES rom
;
; No consideration of the mapper_bank because this is a suspend/resume
; sequence so the RTL will return to the bank that invoked the yield.
            mx    %00
resume
            tsc
            sta   StkSave                  ; Save the current stack location

            lda   DP_NES
            tcd

            lda   yield_s
            tcs

            sep   #$30                     ; Enter 8-bit mode

            ldy   yield_y
            ldx   yield_x
            lda   yield_p
            pha
;            lda   mapper_bank              ; Set the data bank
            lda   #^ROMBase
            pha
            lda   yield_a
            plb
            plp
            rtl                            ; JSL return address should still be on the stack

; NMI Task 
;
; This is the VBL interrupt routine that is responsible for executing code in the NES
; ROM at a consistent 60Hz cadence.
            mx    %11
nmiTask
            php
            rep   #$30
            phb
            phd

            phk
            plb
            lda   DPSave
            tcd

            lda   skipInterruptHandling
            bne   :no_nmi

            ldal  ppustatus             ; Set the bit that the VBL has started
            ora   #$80
            stal  ppustatus

            jsr   NES_ReadInput         ; Put the IIgs inputs into the NES controller bytes

            ldal  singleStepMode
            bne   :no_nmi

            DO SHOW_ROM_EXECUTION_TIME
            lda   #1
            jsr   _SetBorderColor
            FIN

            jsr   NES_TriggerNMI
            stz   frameReady

            DO SHOW_ROM_EXECUTION_TIME
            lda   #0
            jsr   _SetBorderColor
            FIN

:no_nmi
            pld
            plb
            plp
            rtl


; Trigger an NMI in the ROM.  The code actually jumps into the NMI vector.
;
; There are two ways that a ROM is usually driven.  Either the NMI interrupt does minimal work to copy essential
; data into the PPU and the program code runs from the reset vector, or the reset vector code enters into an
; infinite loop and the NMI interrupt drives all of the game logic and display work.
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
; at 60Hz from the VBL/NMI handler

            lda   config_audio_quality
            bne   :audio_uses_interrupts
            sep   #$30
            jsl   APU_quarter_speed_driver
            rep   #$30
:audio_uses_interrupts

            ldal  ppuctrl               ; If the ROM has not enabled VBL NMI, also skip
            bit   #$80
            beq   :skip

            DO    SHOW_ROM_EXECUTION_TIME
            lda   #2
            jsr   _SetBorderColor
            FIN

            ldal  ROMBase+$FFFA         ; NMI Vector
            tax
            jsr   romxfer               ; Execute NMI handler

            DO    SHOW_ROM_EXECUTION_TIME
            lda   #1
            jsr   _SetBorderColor
            FIN

            DO    ROM_DRIVER_MODE
            jsr   resume                ; Yield control back to the ROM until it is waiting for the next VBL
            FIN
:skip
            rts
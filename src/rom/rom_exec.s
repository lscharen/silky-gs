; Routines that control the execution into and out of the ROM code.  Depending on how
; a NES ROM is structures, there are different methods of control flow.

            mx  %00

; Simple ROM control transfer. This acts like an interrupt to the ROM code in the sense
; that we do restore the ROM stack pointer, but jump to an absolute address and
; the registers can be any value.
;
; X = ROM Address
; Interrupts must be disabled
            mx  %00
romxfer     tsc
            sta   StkSave                   ; Save the current stack in the main program

            lda   DP_NES
            tcd

;            sep   #$20
;            lda   #^ExtIn                   ; Set the bank to the ROM
;            pha
;            plb
;            rep   #$20

;            ldal   yield_s
;            tcs
            txa                             ; Put address in A
            ldx   yield_s                   ; Put 16-bit stack addr in X to protect against NES code using TXS

            jml   ExtIn
            mx  %00
ExtRtn      ENT

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
singleStepMode dw  0                        ; If non-zero, the runtime will waut for a user keypress between frames

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

            mx    %11
yield       ENT

; First, preserve the state from the ROM code

            phk
            plb                             ; Reset the bank register.  NES ROM is always B=01, so no need to save

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
            lda   #^ExtIn                   ; Set the bank to the ROM
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
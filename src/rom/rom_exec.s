; Routines that control the execution into and out of the ROM code.  Depending on how
; a NES ROM is structures, there are different methods of control flow.

            mx  %00

; Simple ROM control transfer. This acts like an interrupt to the ROM code in the sense
; that we do restore the ROM stack pointer, but jump to an absolute address and
; the registers can be any value.
;
; X = ROM Address
; Interrupts must be disabled
romxfer     tsc
            sta   StkSave                   ; Save the current stack in the main program

            lda   yield_s                   ; Set the stacak to watever the ROM is currently at
            and   #$00FF
            ora   #$0100
            sta   :patch+1

            sep   #$20
            lda   #^ExtIn                   ; Set the bank to the ROM
            pha
            plb

            ldal  STATE_REG
            ora   #$80                      ; ALTZP on
            stal  STATE_REG
            rep   #$20

:patch      lda   #$0000                    ; Set the ROM stack address
            tcs
            lda   #$0000                    ; Set the ROM zero page
            tcd

            jml   ExtIn
ExtRtn      ENT

            tsx                             ; Copy the stack address returned by the emulator
            ldal  StkSave
            tcs

            phk
            plb

            lda   DPSave
            tcd
            sep   #$30
            stx   yield_s                   ; Keep an updated copy of the stack address
            ldal  STATE_REG                 ; Get back to Bank 0 R/W
            and   #$7F
            stal  STATE_REG
            rep   #$30

            rts

; Miscellaneous data fields
singleStepMode dw  0                        ; If non-zero, the runtime will waut for a user keypress between frames

; Location to save the 16-bit stack from the natvie IIgs execution context
StkSave     dw    0

; yield - allow the ROM to give up control.  Only one yield may be active at a given time. This
;         must be called from the NES ROM code, so 8-bit execution and the relevant softswitch
;         states are assumed and not specifically saved.
yield_a     ds    1
yield_x     ds    1
yield_y     ds    1
yield_p     ds    1
yield_s     ds    1

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

            ldal  STATE_REG                 ; Get back to Bank 0 R/W
            and   #$7F
            stal  STATE_REG

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

            lda   #$0000                   ; set direct page and stack addresses
            tcd

            lda   yield_s
            and   #$00FF
            ora   #$0100
            tcs

            sep   #$30                     ; Enter 8-bit mode
            ldal  STATE_REG
            ora   #$80                     ; ALTZP on
            stal  STATE_REG

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
;            beq   :skip

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
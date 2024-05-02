; Handle input from different I/O devices and map to the NES controller input format

            mx  %00

; Expose joypad bits to the ROM for two controllers: A-B-Select-Start-Up-Down-Left-Right
;   
native_joy  ENT
            db   0,0

; NES_ReadInput
;
; Read input for the configured controller inputs and place in the appropriate joypad byte
; for the ROM routines to read.
NES_ReadInput
            jsr   _ReadControl
            sta   LastRead
            pha
            sep   #$20
            xba
            sta   native_joy
            sta   native_joy+1
            rep   #$20
            pla
            rts

; Map the field to the NES controller format: A-B-Select-Start-Up-Down-Left-Right

            pha
            and   #PAD_BUTTON_A+PAD_BUTTON_B        ; bits 0x200 and 0x100
            lsr
            lsr
            sta  native_joy

            sep   #$20
            lda   1,s
            cmp   #9           ; TAB, was 'n' mapped to Select
            bne   *+6
            lda   #$20
            bra   :nes_merge
            cmp   #13          ; RETURN, was 'm' mapped to Start
            bne   *+6
            lda   #$10
            bra   :nes_merge
            cmp   #UP_ARROW
            bne   *+6
            lda   #$08
            bra   :nes_merge
            cmp   #DOWN_ARROW
            bne   *+6
            lda   #$04
            bra   :nes_merge
            cmp   #LEFT_ARROW
            bne   *+6
            lda   #$02
            bra   :nes_merge
            cmp   #RIGHT_ARROW
            bne   *+6
            lda   #$01
            bra   :nes_merge
            lda   #0
:nes_merge  ora  native_joy 
            sta  native_joy
            sta  native_joy+1

:nes_done
            rep   #$20
            pla
            rts

; Handle input from different I/O devices and map to the NES controller input format

            mx  %00

; Expose joypad bits to the ROM for two controllers: A-B-Select-Start-Up-Down-Left-Right
native_joy  ENT
            db   0,0

; NES_ReadInput
;
; Read input for the configured controller inputs and place in the appropriate joypad byte
; for the ROM routines to read.
            mx  %00
NES_ReadInput
            jsr   _ReadControl
            sta   LastRead               ; The keyboard input is replicated in both, so save it

            pha
            sep   #$20
            lda   InputPlayer1+1         ; Copy the top byte into the native input locations
            sta   native_joy
            lda   InputPlayer2+1
            sta   native_joy+1
            rep   #$20
            pla
            rts

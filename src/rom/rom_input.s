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
            DO    BENCH_MODE
; MAME bench harness (scripts/run-bench.js): feed player 1 from a canned
; input file instead of the keyboard/joystick (see BenchInputData /
; BENCH_MODE in the game's Main.s). NES_ReadInput may be called more than
; once within the same virtual 1/60th of a second, so the index is NOT
; advanced here -- only src/rom/rom_exec.s::NES_TriggerNMI (one call per
; virtual NMI) advances it, so every read within that frame returns the
; same value.
            sep   #$20
            ldx   BenchInputIndex
            lda   BenchInputData,x
            sta   native_joy
            stz   native_joy+1           ; player 2: no input
            rep   #$20
            rts
            ELSE
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
            FIN

; Handle input from different I/O devices and map to the NES controller input format

            mx  %00

; Expose joypad bits to the ROM for two controllers: A-B-Select-Start-Up-Down-Left-Right
native_joy  ENT
            db   0,0

; The last new key press (key code | $80, and the modifiers ($C025) in the high byte), for the event loop
; (NES_TakeKey).  Set by _KbdPoll (rom/rom_kbd_basic.s) when the keyboard strobe is set, so each press, and each
; auto-repeat, is one event; taking it clears it.
KeyEvent    dw   0

; Non-zero once the NES task has polled the inputs since the event loop last looked (NES_TakeKey)
nesPolled   dw   0

; NES_ReadJoy / NES_ReadJoy1
;
; The ROMs' controller routines call these (jsl) in place of `ldal native_joy,x`, so the game reads the
; inputs as they are when it asks for them, even in a frame that runs late.  NES_ReadJoy: X = the
; controller (0 / 1); NES_ReadJoy1: controller 0.  Reading controller 0 polls the inputs (NES_PollInput);
; controller 1 comes from the same poll.  Returns A = the controller byte with N and Z set from it, like
; the ldal it replaces.  Every other register and flag, the data bank and the direct page are preserved,
; in any register width.
            mx  %00
NES_ReadJoy1 ENT
            php
            rep   #$30
            phx
            ldx   #0
            jsr   ReadJoyPoll
            plx
            plp
            ldal  native_joy
            rtl

            mx  %00
NES_ReadJoy ENT
            php
            rep   #$30
            phx
            jsr   ReadJoyPoll
            plx
            plp
            ldal  native_joy,x
            rtl

; X = the controller.  16-bit registers, any data bank and direct page.
            mx  %00
ReadJoyPoll
            cpx   #0
            bne   :out
            phy
            phd
            phb
            phk
            plb
            lda   DPSave                  ; The runtime's direct page (InputPlayer1, LastKey, ...)
            tcd
            jsr   NES_PollInput
            lda   #1
            sta   nesPolled
            plb
            pld
            ply
:out        rts

; NES_PollInput
;
; Read the configured controller inputs and put them in the joypad bytes for the ROM, and the keyboard
; state in LastRead.  This is the only place the keyboard is read while a game runs; it is called by
; the NES task when the game reads its controller (NES_ReadJoy) and by the event loop when the NES task
; hasn't (NES_TakeKey).  Interrupts are off while it runs, so the two can't interleave (the NES task can
; take over the GS task at a VBL).  D = the runtime's direct page, DBR = the main bank.
            mx  %00
NES_PollInput
            php
            sei
            jsr   _ReadControl
            sta   LastRead               ; The keyboard input is replicated in both, so save it

            sep   #$20
            lda   InputPlayer1+1         ; Copy the top byte into the native input locations
            sta   native_joy
            lda   InputPlayer2+1
            sta   native_joy+1
            rep   #$20

            lda   config_autofire_a
            ora   config_autofire_b
            beq   :out
            jsr   _ApplyAutofire
:out        plp
            rts

; _ApplyAutofire
;
; TURBO > AUTOFIRE A / B (config_autofire_a / b: 0 = off, otherwise N = 1, 2 or 4).  While a button is held,
; the ROM sees it down for N NES frames, up for N, and so on, from the frame the press was first seen; a
; button that is not held passes through, and pressing it again starts over.  The phase comes from the frame
; number rather than a count of polls, so reading the controller more than once in a frame, or the event
; loop's poll (NES_TakeKey), doesn't advance it.  Both players use the same settings; native_joy read as a word
; is P1 in the low byte and P2 in the high byte.  Interrupts are off.  No direct page temporaries: this can run
; on the NES task in the middle of a render.
            mx  %00
_ApplyAutofire
            ldx   #0
            ldy   #$0080                  ; P1 A
            lda   config_autofire_a
            jsr   :button
            ldx   #2
            ldy   #$8000                  ; P2 A
            lda   config_autofire_a
            jsr   :button
            ldx   #4
            ldy   #$0040                  ; P1 B
            lda   config_autofire_b
            jsr   :button
            ldx   #6
            ldy   #$4000                  ; P2 B
            lda   config_autofire_b

; X = the button's state, Y = its bit in native_joy, A = N (Z set if off)
:button     beq   :done
            sta   afPeriod
            tya
            bit   native_joy
            bne   :down
            stz   afHeld,x                ; Released: the next press starts over
:done       rts

:down       lda   afHeld,x
            bne   :held
            inc   afHeld,x                ; A new press: it goes through
            ldal  nesFrameCount
            sta   afStart,x
            rts

:held       ldal  nesFrameCount           ; N is a power of 2, so its bit in the frames since the
            sec                           ; press says which half of the cycle this is
            sbc   afStart,x
            bit   afPeriod
            beq   :done
            tya
            trb   native_joy
            rts

afPeriod    dw    0
afHeld      dw    0,0,0,0                 ; Non-zero while held: P1 A, P2 A, P1 B, P2 B
afStart     dw    0,0,0,0                 ; nesFrameCount at the press

; NES_TakeKey
;
; For the event loop: A = the key code of the last new key press (0 if none), which is then cleared, and
; X = the modifiers ($C025 bits) when it was pressed.
; The NES task normally polls the inputs every frame; if it hasn't since the last call (it is paused,
; or the game is not reading its controller), poll here so the event loop still gets its keys.
; D = the runtime's direct page, DBR = the main bank.
            mx  %00
NES_TakeKey
            php
            sei
            lda   nesPolled
            bne   :polled
            jsr   NES_PollInput           ; (interrupts stay off: it saves and restores P itself)
:polled     stz   nesPolled
            lda   KeyEvent
            stz   KeyEvent
            plp
            pha
            xba
            and   #$00FF
            tax                           ; X = the modifiers
            pla
            and   #$007F                  ; Z set if there is no key
            rts

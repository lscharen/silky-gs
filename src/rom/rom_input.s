; Handle input from different I/O devices and map to the NES controller input format

            mx  %00

; Expose joypad bits to the ROM for two controllers: A-B-Select-Start-Up-Down-Left-Right
native_joy  ENT
            db   0,0

; The last new key press (key code | $80), for the event loop (NES_TakeKey).  Set by _ReadKeypress when the
; keyboard strobe is set, so each press, and each auto-repeat, is one event; taking it clears it.
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
            plp
            rts

; NES_TakeKey
;
; For the event loop: A = the key code of the last new key press (0 if none), which is then cleared.
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
            and   #$007F                  ; Z set if there is no key
            rts

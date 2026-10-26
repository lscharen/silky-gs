; J13 keyboard driver: keyboard input with several keys held at once
;
; Adapted from the J13 keyboard driver of the IIgs Wolfenstein 3D port
; (github.com/Webifi/iigs-wolfenstein3d, src/iigs/j13.s).  $C000 / $C010 only give the last key pressed
; and whether any key is down, so the BASIC driver (rom/rom_kbd_basic.s) sees one key at a time and can
; only guess which are still held.  On ROM 00 / 01 the ADB microcontroller keeps the keys that are down in its
; RAM ($31 - $3A, one bit per key, 0 = down), and ADB command $09 (read memory) returns a byte of it.
;
; This driver keeps up to 3 held keys, as ADB key codes (J13_ADBKeys), oldest first:
;
;   - a new key ($C000 strobe, seen by _KbdPoll, rom/rom_kbd_basic.s) is added to them
;   - no key down ($C010 bit 7 = 0) releases them all
;   - with 2 or 3 held keys, their rows are read one at a time and the keys that are up are released
;
; A key with no row (J13_RowMask = 0) is held alone, as is every key when the rows can't be read: then
; J13 works like BASIC.  The rows are only read if the microcontroller firmware matches the one
; the tables are for (J13_Init compares 64 bytes of it), so ROM 3 and emulators that don't run the real
; firmware get the single key.
;
; A row read sends 3 bytes ($09, address low, address high) and takes a 1 byte reply.  It is a small state
; machine (j13Pump) that every poll advances as far as the microcontroller allows, checking the ADB status
; at most J13_SPIN times: the poll runs with interrupts off and never waits for the microcontroller.
; While a read is in flight the ADB data interrupt is off, so the firmware's interrupt handler doesn't
; take the reply; the interrupt enables are put back when it is done.

; The keyboard driver used by the KEYBOARD input type (config_kbd_driver, DRIVERS menu; KbdDriverPad,
; core/CoreImpl.s).  Only one is used at a time: with another driver, J13_Poll keeps no held keys.  The
; configuration screen always reads the keyboard directly (_KbdReadRaw), whichever driver is set.
; (KBD_DRIVER_J13, and the KBD_J13 flag that builds the driver's hooks: core/Defs.s)

; The keyboard hardware this file uses (and the ADB GLU's, below)
J13_KBD_STROBE_REG equ  $E0C010       ; Bit 7: a key is down (AKD); bits 0 - 6: the last key pressed
J13_MOD_REG       equ   $E0C025       ; The modifiers of the last key press

ADB_DATA          equ   $E0C026       ; ADB command / data register
ADB_STATUS        equ   $E0C027       ; Keyboard / mouse status and interrupt enables
ZIP_CANCEL        equ   $E0C05F       ; Written after each ADB command byte (ZipGS)
ROM_VERSION       equ   $FFFB59       ; 0 / 1 on ROM 00 / 01

J13_SPIN          equ   64            ; ADB status checks per poll while a row read is in flight
J13_TIMEOUT       equ   60            ; Polls before a row read is given up (and rows are no longer read)
J13_ID_TAB        equ   $30           ; ADB key codes of the Select (Tab) and Start (Return) keys
J13_ID_RETURN     equ   $24

j13Matrix         dw    0             ; Non-zero if the rows can be read (J13_Init)
j13Keys           ds    8             ; The held keys (ADB key codes, words), oldest first; 1 word of padding
j13Count          dw    0             ; Number of held keys * 2
j13Gen            dw    0             ; Changes with the held keys, so a reply older than a change is ignored
j13New            dw    0             ; The new key (key code | $80), set by _KbdPoll, taken by J13_Poll
j13Down           dw    0
j13State          dw    0             ; 0 = idle, 1 / 2 = send the address low / high byte, 3 = wait for the reply
j13Polls          dw    0
j13ReqGen         dw    0
j13Enables        dw    0             ; ADB interrupt enables to put back after a row read
j13Next           dw    0             ; Held key whose row was read last
j13Row            dw    0             ; Microcontroller address of the row being read
j13Expect         dw    0             ; Its held keys (1 = down)
j13Value          dw    0             ; The reply (1 = up)
j13Pad            dw    0
j13Ids            ds    J13_IDS       ; ADB key codes of Right, Left, Down, Up, Start, Select, then the
                                      ; diagonals UL, UR, DL, DR (J13_Pad; $FFFF = no key)
J13_IDS           equ   20

; J13_Init
;
; Called once by NES_StartUp, before the audio interrupts start.  Checks the ROM version and the
; microcontroller firmware, with interrupts off.  16-bit registers.
            mx    %00
J13_Init
            php
            sei
            sep   #$20
            ldal  ROM_VERSION
            cmp   #2
            bcs   :done               ; ROM 3: no rows

            ldy   #256                ; Take any byte waiting in the data register
:drain      ldal  ADB_STATUS
            and   #$20
            beq   :check
            ldal  ADB_DATA
            dey
            bne   :drain
            bra   :done

:check      ldx   #0                  ; Firmware bytes $18AC - $18CB and $1A10 - $1A2F
:loop       phx
            rep   #$20
            txa
            cpx   #32
            bcc   :first
            adc   #$1A10-32-1         ; (carry set)
            bra   :addr
:first      adc   #$18AC              ; (carry clear)
:addr       tax
            sep   #$20
            jsr   j13ReadMCU
            plx
            bcs   :done
            cmp   J13_Firmware,x
            bne   :done
            inx
            cpx   #64
            bcc   :loop
            lda   #1
            sta   j13Matrix
:done       plp
            rts

; Read the microcontroller byte at X.  8-bit A, 16-bit X / Y.  Returns A = the byte, carry set if the
; microcontroller did not answer.
            mx    %10
j13ReadMCU
            lda   #$09
            jsr   j13Send
            bcs   :done
            txa
            jsr   j13Send
            bcs   :done
            rep   #$20
            txa
            xba
            sep   #$20
            jsr   j13Send
            bcs   :done
            jsr   j13Read
:done       rts

            mx    %10
j13Send     pha
            ldy   #16384
:wait       ldal  ADB_STATUS
            lsr                       ; Bit 0: command register full
            bcc   :ready
            dey
            bne   :wait
            pla
            sec
            rts
:ready      pla
            stal  ADB_DATA
            stal  ZIP_CANCEL
            clc
            rts

            mx    %10
j13Read     ldy   #16384
:wait       ldal  ADB_STATUS
            and   #$20                ; Bit 5: data register full
            bne   :ready
            dey
            bne   :wait
            sec
            rts
:ready      ldal  ADB_DATA
            clc
            rts

; J13_ShutDown
;
; Put the ADB interrupt enables back if a row read is in flight.  16-bit registers.
            mx    %00
J13_ShutDown
            lda   j13State
            beq   :done
            jmp   j13Finish
:done       rts

; J13_Poll
;
; Called by _ReadControl on every poll, after _KbdPoll, with interrupts off.  Updates the held keys if
; the J13 driver is set, and advances a row read.  16-bit registers, DBR = the main bank, D = the
; runtime's direct page.
            mx    %00
J13_Poll
            sep   #$20
            ldal  J13_KBD_STROBE_REG  ; Bit 7: a key is down (AKD)
            rep   #$20
            and   #$00FF
            sta   j13Down
            lda   config_kbd_driver
            cmp   #KBD_DRIVER_J13
            beq   :active
            stz   j13New              ; Not used: no held keys, but finish a row read in flight
            jsr   j13Clear
            jmp   j13Pump

:active     lda   j13New
            beq   :held
            stz   j13New
            jsr   j13Press
:held       lda   j13Down
            bit   #$0080
            beq   :none
            ldx   j13Count
            bne   :pump
            jsr   j13Press            ; A key is down but none is held (it was down before): the last key
            bra   :pump               ; pressed, as for BASIC
:none       jsr   j13Clear            ; No key is down
:pump       jmp   j13Pump

j13Clear    lda   j13Count
            beq   :done
            stz   j13Count
            inc   j13Gen
:done       rts

; A = the new key (key code | $80)
j13Press    and   #$007F
            tax
            lda   J13_ADBKeys,x
            and   #$00FF
            tay                       ; Y = its ADB key code

            ldx   #0
:find       cpx   j13Count
            bcs   :not_held
            cmp   j13Keys,x
            beq   :done               ; Already held (pressed again, or the firmware's auto-repeat)
            inx
            inx
            bra   :find

:not_held   sep   #$20
            ldal  J13_MOD_REG
            rep   #$20
            and   #$0008              ; An auto-repeat is not a new press: it only adds a key if none is held
            beq   :fresh
            lda   j13Count
            bne   :done

:fresh      lda   j13Matrix
            beq   :single
            lda   J13_RowMask,y
            and   #$00FF
            beq   :single             ; No row: held alone
            lda   j13Count
            cmp   #6
            bcs   :done               ; 3 keys at most
            cmp   #2
            bne   :append
            ldx   j13Keys
            lda   J13_RowMask,x
            and   #$00FF
            beq   :single             ; The held key has no row, so it can't be released by one: replace it
:append     ldx   j13Count
            bra   :add
:single     ldx   #0
:add        tya
            sta   j13Keys,x
            inx
            inx
            stx   j13Count
            inc   j13Gen
:done       rts

; Release the held key at offset X; the later ones move down.  X is kept.
j13Remove   phx
:shift      lda   j13Keys+2,x
            sta   j13Keys,x
            inx
            inx
            cpx   #4
            bcc   :shift
            plx
            dec   j13Count
            dec   j13Count
            inc   j13Gen
            rts

; The row read state machine
            mx    %00
j13Pump     lda   j13State
            bne   :busy
            lda   j13Count
            cmp   #4
            bcc   :out                ; 0 or 1 held key: $C010 gives its release

            sep   #$20                ; Start when nothing is being sent and no reply or mouse data waits
            ldal  ADB_STATUS
            bit   #$A1
            bne   :out8
            rep   #$20
            jsr   j13PickRow
            sep   #$20
            ldal  ADB_STATUS
            and   #$54
            sta   j13Enables
            and   #$44                ; Data interrupt off; the mouse and keyboard interrupts stay as they are
            stal  ADB_STATUS
            lda   #$09                ; Read memory
            stal  ADB_DATA
            stal  ZIP_CANCEL
            rep   #$20
            lda   j13Gen
            sta   j13ReqGen
            lda   #1
            sta   j13State
            stz   j13Polls

:busy       inc   j13Polls
            lda   j13Polls
            cmp   #J13_TIMEOUT
            bcs   :timeout
            ldy   #J13_SPIN
:step       sep   #$20
            ldal  ADB_STATUS
            bit   #$20
            bne   :data
            lsr                       ; Carry = command register full
            rep   #$20
            bcs   :next
            lda   j13State
            cmp   #3
            bcs   :next               ; All sent: wait for the reply
            dec
            bne   :high
            lda   j13Row              ; State 1: address low byte
            bra   :send
:high       lda   #0                  ; State 2: address high byte
:send       sep   #$20
            stal  ADB_DATA
            stal  ZIP_CANCEL
            rep   #$20
            inc   j13State
:next       dey
            bne   :step
:out        rts

            mx    %10
:out8       rep   #$20
            rts

            mx    %10
:data       ldal  ADB_DATA
            rep   #$20
            and   #$00FF
            sta   j13Value
            lda   j13State
            cmp   #3
            bcc   :next               ; A status byte while sending: ignore it
            jsr   j13Reply
            bcs   :next               ; A status byte before the reply: keep waiting
            jmp   j13Finish

            mx    %00
:timeout    stz   j13Matrix           ; The microcontroller doesn't answer: stop reading rows
            jmp   j13Finish

            mx    %00
j13Finish   sep   #$20
            lda   j13Enables
            stal  ADB_STATUS
            rep   #$20
            stz   j13State
            rts

; Pick the next held key's row (round robin) and the mask of every held key in that row
            mx    %00
j13PickRow  ldx   j13Next
            inx
            inx
            cpx   j13Count
            bcc   :ok
            ldx   #0
:ok         stx   j13Next
            ldy   j13Keys,x
            lda   J13_Row,y
            and   #$00FF
            sta   j13Row

            stz   j13Expect
            ldx   #0
:loop       ldy   j13Keys,x
            lda   J13_Row,y
            and   #$00FF
            cmp   j13Row
            bne   :next
            lda   J13_RowMask,y
            and   #$00FF
            tsb   j13Expect
:next       inx
            inx
            cpx   j13Count
            bcc   :loop
            rts

; A byte came back (j13Value).  Returns carry set if it is an ADB status byte and the reply is still to come.
            mx    %00
j13Reply    lda   j13Value
            eor   #$00FF              ; 1 = down
            cmp   j13Expect
            beq   :done               ; Every held key of the row is still down
            ora   j13Expect
            cmp   j13Expect
            beq   :valid              ; Only held keys of the row are down: release the others
            lda   j13Value
            and   #$0087
            beq   :wait               ; A status byte ($08 / $20 / $40) can come before the reply
:done       clc                       ; Otherwise another key of the row is down: no releases
            rts
:wait       sec
            rts

:valid      lda   j13ReqGen
            cmp   j13Gen
            bne   :done               ; The held keys changed since the read was sent
            ldx   #0
:loop       cpx   j13Count
            bcs   :done
            ldy   j13Keys,x
            lda   J13_Row,y
            and   #$00FF
            cmp   j13Row
            bne   :keep
            lda   J13_RowMask,y
            and   j13Value
            and   #$00FF
            beq   :keep
            jsr   j13Remove           ; Up: release it (the next key moves to X)
            bra   :loop
:keep       inx
            inx
            bra   :loop

; J13_Pad
;
; X = the player's configuration block.  Returns A = the pad bits of the held keys.  Opposite directions
; can't both be down on a pad: the newer key wins (a diagonal key sets two directions and clears their
; opposites).  16-bit registers, DBR = the main bank.
            mx    %00
J13_Pad
            lda:  PLAYER_INPUT_KEY_RIGHT,x
            jsr   j13Id
            sta   j13Ids
            lda:  PLAYER_INPUT_KEY_LEFT,x
            jsr   j13Id
            sta   j13Ids+2
            lda:  PLAYER_INPUT_KEY_DOWN,x
            jsr   j13Id
            sta   j13Ids+4
            lda:  PLAYER_INPUT_KEY_UP,x
            jsr   j13Id
            sta   j13Ids+6
            lda   #J13_ID_RETURN
            sta   j13Ids+8
            lda   #J13_ID_TAB
            sta   j13Ids+10
            lda:  PLAYER_INPUT_KEY_UL,x
            jsr   j13Id
            sta   j13Ids+12
            lda:  PLAYER_INPUT_KEY_UR,x
            jsr   j13Id
            sta   j13Ids+14
            lda:  PLAYER_INPUT_KEY_DL,x
            jsr   j13Id
            sta   j13Ids+16
            lda:  PLAYER_INPUT_KEY_DR,x
            jsr   j13Id
            sta   j13Ids+18

            stz   j13Pad
            ldy   #0
:key        cpy   j13Count
            bcs   :done
            lda   j13Keys,y
            ldx   #0
:map        cmp   j13Ids,x
            bne   :no_map
            pha
            lda   j13Pad
            and   J13_PadClear,x
            ora   J13_PadBits,x
            sta   j13Pad
            pla
:no_map     inx
            inx
            cpx   #J13_IDS
            bcc   :map
            iny
            iny
            bra   :key
:done       lda   j13Pad
            rts

; KbdJ13_Pad
;
; The driver's pad routine (KbdDriverPad, core/CoreImpl.s): X = the player's configuration block.
; Returns A = the full pad: the held keys (J13_Pad) and the buttons (the push buttons, PAD_PUSH_BUTTONS).
; Sets kbdHandled if the last key pressed is one of the player's keys (j13Ids), compared as J13 does, by
; ADB key code.
            mx    %00
KbdJ13_Pad
            phx                       ; The configuration block, for the buttons
            jsr   kbdJ13Dirs
            plx
            PAD_PUSH_BUTTONS
            rts

kbdJ13Dirs  sep   #$20
            ldal  J13_KBD_STROBE_REG  ; Bit 7: a key is down (AKD); bits 0 - 6: the last key pressed
            rep   #$20
            and   #$00FF
            pha
            jsr   J13_Pad
            pha
            lda   3,s
            bit   #PAD_KEY_DOWN
            beq   :out
            and   #PAD_KEY_MASK
            tax
            lda   J13_ADBKeys,x
            and   #$00FF
            ldx   #J13_IDS-2
:loop       cmp   j13Ids,x
            beq   :handled
            dex
            dex
            bpl   :loop
            bra   :out
:handled    lda   #1
            sta   kbdHandled
:out        pla
            ply                       ; (the key)
            rts

j13Id       and   #$007F              ; (0 = no key: an id no key has)
            bne   *+6
            lda   #$FFFF
            rts
            tay
            lda   J13_ADBKeys,y
            and   #$00FF
            rts

J13_PadBits  dw   PAD_RIGHT,PAD_LEFT,PAD_DOWN,PAD_UP,PAD_START,PAD_SELECT
             dw   PAD_UP+PAD_LEFT,PAD_UP+PAD_RIGHT,PAD_DOWN+PAD_LEFT,PAD_DOWN+PAD_RIGHT
J13_PadClear dw   $FFFF-PAD_LEFT,$FFFF-PAD_RIGHT,$FFFF-PAD_UP,$FFFF-PAD_DOWN,$FFFF,$FFFF
             dw   $FFFF-PAD_DOWN-PAD_RIGHT,$FFFF-PAD_DOWN-PAD_LEFT,$FFFF-PAD_UP-PAD_RIGHT,$FFFF-PAD_UP-PAD_LEFT

; The ADB key code of each character (the low 7 bits).  Shifted characters map to their unshifted key and
; the control characters to their letter, except the arrows (Ctrl-H = Left, Ctrl-J = Down, Ctrl-K = Up,
; Ctrl-U = Right), Tab, Return and Escape.  Keys that make the same character can't be told apart.
J13_ADBKeys
            hex   31000b08020e03053b303d3e25242d1f
            hex   230c0f01113c090d071006352a1e161b
            hex   3112271415171a27191d1c182b1b2f2c
            hex   1d1213141517161a1c1929292b182f2c
            hex   13000b08020e030504222628252e2d1f
            hex   230c0f011120090d071006212a1e161b
            hex   32000b08020e030504222628252e2d1f
            hex   230c0f011120090d071006212a1e3233

; The microcontroller row (address) and switch bit of each ADB key code.  Mask 0 = no row.
J13_Row
            hex   31333235343631323334ff3532333435
            hex   3637323334353637383a383a39393a3a
            hex   38393938373a373a383937383a363739
            hex   31393737ff31ffffffffff393a3838ff
J13_RowMask
            hex   04040404040408080808000802020202
            hex   02020101010101011001011001102002
            hex   02200220400404400404100808080808
            hex   02402080000100000000008080804000

; Microcontroller firmware bytes $18AC - $18CB and $1A10 - $1A2F of the ROM 00 / 01 firmware the rows are for
J13_Firmware
            hex   3cffe4a20922593c0a48c648305ba548
            hex   aa8b85e4b53145e23cffe4f0eda00888
            hex   22b4f74c0515319531608f0ae70f0649
            hex   ff3531953122c5331cf31aa64ce037f0

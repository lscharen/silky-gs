; KEYBOARD 2: keyboard input with several keys held at once
;
; Adapted from the J13 keyboard driver of the IIgs Wolfenstein 3D port
; (github.com/Webifi/iigs-wolfenstein3d, src/iigs/j13.s).  $C000 / $C010 only give the last key pressed
; and whether any key is down, so the KEYBOARD input type sees one key at a time: holding Right and
; pressing Up drops Right.  On ROM 00 / 01 the ADB microcontroller keeps the keys that are down in its
; RAM ($31 - $3A, one bit per key, 0 = down), and ADB command $09 (read memory) returns a byte of it.
;
; This driver keeps up to 3 held keys, as ADB key codes (KB2_ADBKeys), oldest first:
;
;   - a new key ($C000 strobe, seen by _ReadKeypress) is added to them
;   - no key down ($C010 bit 7 = 0) releases them all
;   - with 2 or 3 held keys, their rows are read one at a time and the keys that are up are released
;
; A key with no row (KB2_RowMask = 0) is held alone, as is every key when the rows can't be read: then
; KEYBOARD 2 works like KEYBOARD.  The rows are only read if the microcontroller firmware matches the one
; the tables are for (KB2_Init compares 64 bytes of it), so ROM 3 and emulators that don't run the real
; firmware get the single key.
;
; A row read sends 3 bytes ($09, address low, address high) and takes a 1 byte reply.  It is a small state
; machine (kb2Pump) that every poll advances as far as the microcontroller allows, checking the ADB status
; at most KB2_SPIN times: the poll runs with interrupts off and never waits for the microcontroller.
; While a read is in flight the ADB data interrupt is off, so the firmware's interrupt handler doesn't
; take the reply; the interrupt enables are put back when it is done.

INPUT_KEYBOARD2   equ   4             ; config_input_p1_type / config_input_p2_type value (_ReadControl)

ADB_DATA          equ   $E0C026       ; ADB command / data register
ADB_STATUS        equ   $E0C027       ; Keyboard / mouse status and interrupt enables
ZIP_CANCEL        equ   $E0C05F       ; Written after each ADB command byte (ZipGS)
ROM_VERSION       equ   $FFFB59       ; 0 / 1 on ROM 00 / 01

KB2_SPIN          equ   64            ; ADB status checks per poll while a row read is in flight
KB2_TIMEOUT       equ   60            ; Polls before a row read is given up (and rows are no longer read)
KB2_ID_TAB        equ   $30           ; ADB key codes of the Select (Tab) and Start (Return) keys
KB2_ID_RETURN     equ   $24

kb2Matrix         dw    0             ; Non-zero if the rows can be read (KB2_Init)
kb2Keys           ds    8             ; The held keys (ADB key codes, words), oldest first; 1 word of padding
kb2Count          dw    0             ; Number of held keys * 2
kb2Gen            dw    0             ; Changes with the held keys, so a reply older than a change is ignored
kb2New            dw    0             ; The new key (key code | $80), set by _ReadKeypress, taken by KB2_Poll
kb2Down           dw    0
kb2State          dw    0             ; 0 = idle, 1 / 2 = send the address low / high byte, 3 = wait for the reply
kb2Polls          dw    0
kb2ReqGen         dw    0
kb2Enables        dw    0             ; ADB interrupt enables to put back after a row read
kb2Next           dw    0             ; Held key whose row was read last
kb2Row            dw    0             ; Microcontroller address of the row being read
kb2Expect         dw    0             ; Its held keys (1 = down)
kb2Value          dw    0             ; The reply (1 = up)
kb2Pad            dw    0
kb2Ids            ds    12            ; ADB key codes of Right, Left, Down, Up, Start, Select (KB2_Pad)

; KB2_Init
;
; Called once by NES_StartUp, before the audio interrupts start.  Checks the ROM version and the
; microcontroller firmware, with interrupts off.  16-bit registers.
            mx    %00
KB2_Init
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
            jsr   kb2ReadMCU
            plx
            bcs   :done
            cmp   KB2_Firmware,x
            bne   :done
            inx
            cpx   #64
            bcc   :loop
            lda   #1
            sta   kb2Matrix
:done       plp
            rts

; Read the microcontroller byte at X.  8-bit A, 16-bit X / Y.  Returns A = the byte, carry set if the
; microcontroller did not answer.
            mx    %10
kb2ReadMCU
            lda   #$09
            jsr   kb2Send
            bcs   :done
            txa
            jsr   kb2Send
            bcs   :done
            rep   #$20
            txa
            xba
            sep   #$20
            jsr   kb2Send
            bcs   :done
            jsr   kb2Read
:done       rts

            mx    %10
kb2Send     pha
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
kb2Read     ldy   #16384
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

; KB2_ShutDown
;
; Put the ADB interrupt enables back if a row read is in flight.  16-bit registers.
            mx    %00
KB2_ShutDown
            lda   kb2State
            beq   :done
            jmp   kb2Finish
:done       rts

; KB2_Poll
;
; Called by _ReadControl on every poll, with interrupts off.  A = the _ReadKeypress value (bit 7 set if
; a key is down).  Updates the held keys if a player uses KEYBOARD 2, and advances a row read.
; 16-bit registers, DBR = the main bank.
            mx    %00
KB2_Poll
            sta   kb2Down
            lda   #INPUT_KEYBOARD2
            cmp   config_input_p1_type
            beq   :active
            cmp   config_input_p2_type
            beq   :active
            stz   kb2New              ; Not used: no held keys, but finish a row read in flight
            jsr   kb2Clear
            jmp   kb2Pump

:active     lda   kb2New
            beq   :held
            stz   kb2New
            jsr   kb2Press
:held       lda   kb2Down
            bit   #$0080
            beq   :none
            ldx   kb2Count
            bne   :pump
            jsr   kb2Press            ; A key is down but none is held (it was down before): the last key
            bra   :pump               ; pressed, as for KEYBOARD
:none       jsr   kb2Clear            ; No key is down
:pump       jmp   kb2Pump

kb2Clear    lda   kb2Count
            beq   :done
            stz   kb2Count
            inc   kb2Gen
:done       rts

; A = the new key (key code | $80)
kb2Press    and   #$007F
            tax
            lda   KB2_ADBKeys,x
            and   #$00FF
            tay                       ; Y = its ADB key code

            ldx   #0
:find       cpx   kb2Count
            bcs   :not_held
            cmp   kb2Keys,x
            beq   :done               ; Already held (pressed again, or the firmware's auto-repeat)
            inx
            inx
            bra   :find

:not_held   sep   #$20
            ldal  MOD_REG
            rep   #$20
            and   #$0008              ; An auto-repeat is not a new press: it only adds a key if none is held
            beq   :fresh
            lda   kb2Count
            bne   :done

:fresh      lda   kb2Matrix
            beq   :single
            lda   KB2_RowMask,y
            and   #$00FF
            beq   :single             ; No row: held alone
            lda   kb2Count
            cmp   #6
            bcs   :done               ; 3 keys at most
            cmp   #2
            bne   :append
            ldx   kb2Keys
            lda   KB2_RowMask,x
            and   #$00FF
            beq   :single             ; The held key has no row, so it can't be released by one: replace it
:append     ldx   kb2Count
            bra   :add
:single     ldx   #0
:add        tya
            sta   kb2Keys,x
            inx
            inx
            stx   kb2Count
            inc   kb2Gen
:done       rts

; Release the held key at offset X; the later ones move down.  X is kept.
kb2Remove   phx
:shift      lda   kb2Keys+2,x
            sta   kb2Keys,x
            inx
            inx
            cpx   #4
            bcc   :shift
            plx
            dec   kb2Count
            dec   kb2Count
            inc   kb2Gen
            rts

; The row read state machine
            mx    %00
kb2Pump     lda   kb2State
            bne   :busy
            lda   kb2Count
            cmp   #4
            bcc   :out                ; 0 or 1 held key: $C010 gives its release

            sep   #$20                ; Start when nothing is being sent and no reply or mouse data waits
            ldal  ADB_STATUS
            bit   #$A1
            bne   :out8
            rep   #$20
            jsr   kb2PickRow
            sep   #$20
            ldal  ADB_STATUS
            and   #$54
            sta   kb2Enables
            and   #$44                ; Data interrupt off; the mouse and keyboard interrupts stay as they are
            stal  ADB_STATUS
            lda   #$09                ; Read memory
            stal  ADB_DATA
            stal  ZIP_CANCEL
            rep   #$20
            lda   kb2Gen
            sta   kb2ReqGen
            lda   #1
            sta   kb2State
            stz   kb2Polls

:busy       inc   kb2Polls
            lda   kb2Polls
            cmp   #KB2_TIMEOUT
            bcs   :timeout
            ldy   #KB2_SPIN
:step       sep   #$20
            ldal  ADB_STATUS
            bit   #$20
            bne   :data
            lsr                       ; Carry = command register full
            rep   #$20
            bcs   :next
            lda   kb2State
            cmp   #3
            bcs   :next               ; All sent: wait for the reply
            dec
            bne   :high
            lda   kb2Row              ; State 1: address low byte
            bra   :send
:high       lda   #0                  ; State 2: address high byte
:send       sep   #$20
            stal  ADB_DATA
            stal  ZIP_CANCEL
            rep   #$20
            inc   kb2State
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
            sta   kb2Value
            lda   kb2State
            cmp   #3
            bcc   :next               ; A status byte while sending: ignore it
            jsr   kb2Reply
            bcs   :next               ; A status byte before the reply: keep waiting
            jmp   kb2Finish

            mx    %00
:timeout    stz   kb2Matrix           ; The microcontroller doesn't answer: stop reading rows
            jmp   kb2Finish

            mx    %00
kb2Finish   sep   #$20
            lda   kb2Enables
            stal  ADB_STATUS
            rep   #$20
            stz   kb2State
            rts

; Pick the next held key's row (round robin) and the mask of every held key in that row
            mx    %00
kb2PickRow  ldx   kb2Next
            inx
            inx
            cpx   kb2Count
            bcc   :ok
            ldx   #0
:ok         stx   kb2Next
            ldy   kb2Keys,x
            lda   KB2_Row,y
            and   #$00FF
            sta   kb2Row

            stz   kb2Expect
            ldx   #0
:loop       ldy   kb2Keys,x
            lda   KB2_Row,y
            and   #$00FF
            cmp   kb2Row
            bne   :next
            lda   KB2_RowMask,y
            and   #$00FF
            tsb   kb2Expect
:next       inx
            inx
            cpx   kb2Count
            bcc   :loop
            rts

; A byte came back (kb2Value).  Returns carry set if it is an ADB status byte and the reply is still to come.
            mx    %00
kb2Reply    lda   kb2Value
            eor   #$00FF              ; 1 = down
            cmp   kb2Expect
            beq   :done               ; Every held key of the row is still down
            ora   kb2Expect
            cmp   kb2Expect
            beq   :valid              ; Only held keys of the row are down: release the others
            lda   kb2Value
            and   #$0087
            beq   :wait               ; A status byte ($08 / $20 / $40) can come before the reply
:done       clc                       ; Otherwise another key of the row is down: no releases
            rts
:wait       sec
            rts

:valid      lda   kb2ReqGen
            cmp   kb2Gen
            bne   :done               ; The held keys changed since the read was sent
            ldx   #0
:loop       cpx   kb2Count
            bcs   :done
            ldy   kb2Keys,x
            lda   KB2_Row,y
            and   #$00FF
            cmp   kb2Row
            bne   :keep
            lda   KB2_RowMask,y
            and   kb2Value
            and   #$00FF
            beq   :keep
            jsr   kb2Remove           ; Up: release it (the next key moves to X)
            bra   :loop
:keep       inx
            inx
            bra   :loop

; KB2_Pad
;
; X = the player's configuration block.  Returns A = the pad bits of the held keys.  Opposite directions
; can't both be down on a pad: the newer key wins.  16-bit registers, DBR = the main bank.
            mx    %00
KB2_Pad
            lda:  PLAYER_INPUT_KEY_RIGHT,x
            jsr   kb2Id
            sta   kb2Ids
            lda:  PLAYER_INPUT_KEY_LEFT,x
            jsr   kb2Id
            sta   kb2Ids+2
            lda:  PLAYER_INPUT_KEY_DOWN,x
            jsr   kb2Id
            sta   kb2Ids+4
            lda:  PLAYER_INPUT_KEY_UP,x
            jsr   kb2Id
            sta   kb2Ids+6
            lda   #KB2_ID_RETURN
            sta   kb2Ids+8
            lda   #KB2_ID_TAB
            sta   kb2Ids+10

            stz   kb2Pad
            ldy   #0
:key        cpy   kb2Count
            bcs   :done
            lda   kb2Keys,y
            ldx   #0
:map        cmp   kb2Ids,x
            bne   :no_map
            pha
            lda   kb2Pad
            and   KB2_PadClear,x
            ora   KB2_PadBits,x
            sta   kb2Pad
            pla
:no_map     inx
            inx
            cpx   #12
            bcc   :map
            iny
            iny
            bra   :key
:done       lda   kb2Pad
            rts

kb2Id       and   #$007F
            tay
            lda   KB2_ADBKeys,y
            and   #$00FF
            rts

KB2_PadBits  dw   PAD_RIGHT,PAD_LEFT,PAD_DOWN,PAD_UP,PAD_START,PAD_SELECT
KB2_PadClear dw   $FFFF-PAD_LEFT,$FFFF-PAD_RIGHT,$FFFF-PAD_UP,$FFFF-PAD_DOWN,$FFFF,$FFFF

; The ADB key code of each character (the low 7 bits).  Shifted characters map to their unshifted key and
; the control characters to their letter, except the arrows (Ctrl-H = Left, Ctrl-J = Down, Ctrl-K = Up,
; Ctrl-U = Right), Tab, Return and Escape.  Keys that make the same character can't be told apart.
KB2_ADBKeys
            hex   31000b08020e03053b303d3e25242d1f
            hex   230c0f01113c090d071006352a1e161b
            hex   3112271415171a27191d1c182b1b2f2c
            hex   1d1213141517161a1c1929292b182f2c
            hex   13000b08020e030504222628252e2d1f
            hex   230c0f011120090d071006212a1e161b
            hex   32000b08020e030504222628252e2d1f
            hex   230c0f011120090d071006212a1e3233

; The microcontroller row (address) and switch bit of each ADB key code.  Mask 0 = no row.
KB2_Row
            hex   31333235343631323334ff3532333435
            hex   3637323334353637383a383a39393a3a
            hex   38393938373a373a383937383a363739
            hex   31393737ff31ffffffffff393a3838ff
KB2_RowMask
            hex   04040404040408080808000802020202
            hex   02020101010101011001011001102002
            hex   02200220400404400404100808080808
            hex   02402080000100000000008080804000

; Microcontroller firmware bytes $18AC - $18CB and $1A10 - $1A2F of the ROM 00 / 01 firmware the rows are for
KB2_Firmware
            hex   3cffe4a20922593c0a48c648305ba548
            hex   aa8b85e4b53145e23cffe4f0eda00888
            hex   22b4f74c0515319531608f0ae70f0649
            hex   ff3531953122c5331cf31aa64ce037f0

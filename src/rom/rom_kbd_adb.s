; ADB keyboard driver: every key's up / down state, from the ADB keyboard itself
;
; The technique of the IIgs Wolfenstein 3D port (Eric Shepherd, KansasFest 2004, "Reading Multiple Keys
; Down at Once"): keyboard autopolling is turned off (SendInfo setModes), so the ADB microcontroller no
; longer collects the keys, and a completion routine is put in the ADB Tool Set's SRQ list for the
; keyboard (SRQPoll).  When the keyboard has events, it asks for service; the tool set reads its
; register 0 and calls KbdAdb_SRQ with them.  Each event is a key code and whether the key went down or up,
; so adbKeys always holds which keys are down, however many.
;
; Each event is then passed to the microcontroller (SendInfo keyCode), which handles it as if it had polled
; the keyboard itself: $C000 / $C010 / $C025, the auto-repeat, the configuration screen, the hotkeys and the
; buttons (_KbdButtons, core/CoreImpl.s) work as with the other drivers.
;
; Works on every ROM, unlike J13 (rom/rom_kbd_j13.s), whose tables and key code map (J13_ADBKeys) it uses.
;
; A pad can't have opposite directions down: of the player's left / right keys that are down, the one
; pressed last wins, and the same for up / down (a diagonal key counts for both of its directions).
;
; Known limits: the Control Panel's ToBRAMSetup turns the SRQ completion routine off (until ApplyConfig
; puts it back, when leaving the configuration screen), and Control-Reset alone does nothing while the
; driver is in (Control-Command-Reset restarts the machine).

KBD_DRIVER_ADB    equ   4             ; config_kbd_driver (KbdDriverPad, core/CoreImpl.s)

ADB_SET_MODES     equ   $04           ; SendInfo commands
ADB_CLEAR_MODES   equ   $05
ADB_RESET_SYS     equ   $10
ADB_KEY_CODE      equ   $11
ADB_MODE_NO_POLL  equ   $01           ; setModes / clearModes: keyboard autopolling off
ADB_KBD           equ   $0002         ; SRQPoll / SRQRemove: the keyboard's ADB address

ADB_SRQ_PTR       equ   7             ; The data pointer's offset from S when KbdAdb_SRQ is called: the tool
                                      ; set pushes it (pea 0 / phd), calls the SRQ vector ($E103DC), which
                                      ; calls KbdAdb_SRQ, so two return addresses are above it.  The caller
                                      ; pulls it.  (Measured on ROM 3.)
ADB_SRQ_DP        equ   ADB_SRQ_PTR+3 ; ... in KbdAdb_SRQ's direct page (D = S after B and D are pushed)
ADB_RESET         equ   $7F           ; The reset key's code (both bytes of register 0)
ADB_KEY_CONTROL   equ   $36
ADB_KEY_COMMAND   equ   $37
ADB_KEY_MODS      equ   $36           ; Control, Command, Shift, Caps Lock, Option: $36 - $3A
ADB_KEY_SHIFT     equ   $38
ADB_KEY_RSHIFT    equ   $7B           ; (only reported apart from Shift if the keyboard is asked to)

ADB_IDS           equ   20            ; One player's key ids (adbIds)

adbInstalled      dw    0             ; Non-zero while the SRQ routine is in and autopolling is off
adbKeys           ds    256           ; Each key code's word: 0 = up, otherwise when it went down (adbStamp)
adbStamp          dw    0             ; Counts the key presses (never 0)
adbIds            ds    ADB_IDS*2     ; Each player's keys (KbdAdbIds, the J13_PadBits order), as adbKeys
                                      ; offsets (key code * 2); $FFFF = no key
adbModeByte       db    ADB_MODE_NO_POLL ; SendInfo data: the main code's and KbdAdb_SRQ's own
adbKeyByte        db    0

; KbdAdb_Pad
;
; The driver's pad routine (KbdDriverPad, core/CoreImpl.s): A = the key (_ReadKeypress), Y = the player
; (0 / 1).  Returns A = the pad bits of the player's keys that are down, and sets kbdHandled if the key is
; one of the player's keys.  Called with interrupts off, so adbKeys doesn't change meanwhile.  16-bit
; registers, DBR = the main bank.
                mx %00
KbdAdb_Pad
                  pha                           ; The key
                  lda       #0
                  cpy       #0
                  beq       *+5
                  lda       #ADB_IDS
                  sta       adbBase
                  stz       adbLR
                  stz       adbLRStamp
                  stz       adbUD
                  stz       adbUDStamp
                  stz       adbOther

                  ldy       #0
:key              tya
                  clc
                  adc       adbBase
                  tax
                  lda       adbIds,x
                  bmi       :next               ; No key
                  tax
                  lda       adbKeys,x
                  beq       :next               ; Up
                  sta       adbT

                  lda       J13_PadBits,y
                  and       #PAD_START+PAD_SELECT
                  tsb       adbOther

                  lda       J13_PadBits,y
                  and       #PAD_LEFT+PAD_RIGHT
                  beq       :ud
                  sta       adbBits
                  lda       adbLRStamp
                  beq       :lr                 ; The first left / right key down
                  lda       adbT
                  sec
                  sbc       adbLRStamp
                  bmi       :ud                 ; Pressed before the one that is set
:lr               lda       adbBits
                  sta       adbLR
                  lda       adbT
                  sta       adbLRStamp

:ud               lda       J13_PadBits,y
                  and       #PAD_UP+PAD_DOWN
                  beq       :next
                  sta       adbBits
                  lda       adbUDStamp
                  beq       :ud_set
                  lda       adbT
                  sec
                  sbc       adbUDStamp
                  bmi       :next
:ud_set           lda       adbBits
                  sta       adbUD
                  lda       adbT
                  sta       adbUDStamp

:next             iny
                  iny
                  cpy       #ADB_IDS
                  bcc       :key

                  lda       1,s                 ; Is the key one of the player's?  (by ADB key code, as J13)
                  bit       #PAD_KEY_DOWN
                  beq       :out
                  and       #PAD_KEY_MASK
                  tax
                  lda       J13_ADBKeys,x
                  and       #$00FF
                  asl
                  ldy       #ADB_IDS-2
:find             pha
                  tya
                  clc
                  adc       adbBase
                  tax
                  pla
                  cmp       adbIds,x
                  beq       :handled
                  dey
                  dey
                  bpl       :find
                  bra       :out
:handled          lda       #1
                  sta       kbdHandled

:out              pla                           ; (the key)
                  lda       adbLR
                  ora       adbUD
                  ora       adbOther
                  rts

adbBase           dw    0             ; KbdAdb_Pad: the player's offset in adbIds
adbT              dw    0             ; ... the key's adbKeys value
adbBits           dw    0             ; ... its direction bits on one axis
adbLR             dw    0             ; ... the left / right bit set, and when its key went down
adbLRStamp        dw    0
adbUD             dw    0             ; ... the same for up / down
adbUDStamp        dw    0
adbOther          dw    0             ; ... Start and Select

; KbdAdb_FixKey
;
; TEMPORARY WORKAROUND for GSSquared: its microcontroller types a key passed back to it (SendInfo keyCode)
; without the modifiers, so Shift-/ reaches $C000 as '/', and the '?' hotkey (the configuration screen)
; can't be typed while this driver is in.  Called by _ReadKeypress (core/CoreImpl.s) for a new key: if the
; driver is in and Shift is down (adbKeys), the unshifted keys of the hotkeys ? ! @ # become the hotkeys.
; Remove once GSSquared applies the modifiers (real hardware is expected to; not yet tested).
; A = the key from $C000 (bit 7 set), 8-bit A, 16-bit X / Y, DBR = the main bank.  Returns A; keeps Y.
                mx %10
KbdAdb_FixKey
                  ldx       adbInstalled
                  beq       :out
                  ldx       adbKeys+{ADB_KEY_SHIFT*2}
                  bne       :shift
                  ldx       adbKeys+{ADB_KEY_RSHIFT*2}
                  beq       :out
:shift            ldx       #AdbShiftTo-AdbShiftFrom-1
:find             cmp       AdbShiftFrom,x
                  beq       :swap
                  dex
                  bpl       :find
                  rts
:swap             lda       AdbShiftTo,x
:out              rts

AdbShiftFrom      db    $AF,$B1,$B2,$B3     ; / 1 2 3 (bit 7 set, as in $C000)
AdbShiftTo        db    $BF,$A1,$C0,$A3     ; ? ! @ #

; KbdAdb_Apply
;
; Called at start-up (after the preferences are loaded) and by ApplyConfig.  Takes the players' keys
; (adbIds), and puts the driver in if it is the one set, or takes it out if not.  If it can't be put in,
; the BASIC driver is set instead.  16-bit registers, DBR = the main bank.
                mx %00
KbdAdb_Apply
                  ldx       #config_block_p1
                  ldy       #0
                  jsr       :ids
                  ldx       #config_block_p2
                  ldy       #ADB_IDS
                  jsr       :ids

                  lda       config_kbd_driver
                  cmp       #KBD_DRIVER_ADB
                  beq       *+5
                  jmp       KbdAdb_ShutDown
                  lda       adbInstalled        ; (again, after the configuration screen: ToBRAMSetup may
                  beq       :install            ; have turned the SRQ routine off)
                  jsr       KbdAdb_ShutDown
:install          jmp       adbInstall

; X = the player's configuration block, Y = its offset in adbIds
:ids              stx       adbBlock
                  sty       adbBase
                  ldy       #0
:id               lda       AdbKeyOffsets,y
                  bne       :configured
                  lda       AdbKeyFixed,y       ; Start / Select: Return / Tab
                  bra       :store
:configured       clc
                  adc       adbBlock
                  tax
                  lda:      0,x
                  and       #$007F
                  beq       :none               ; (0 = no key)
                  tax
                  lda       J13_ADBKeys,x
                  and       #$00FF
                  asl
                  bra       :store
:none             lda       #$FFFF
:store            pha
                  tya
                  clc
                  adc       adbBase
                  tax
                  pla
                  sta       adbIds,x
                  iny
                  iny
                  cpy       #ADB_IDS
                  bcc       :id
                  rts

adbBlock          dw    0

; The configuration block offsets of a player's keys, in the J13_PadBits order (0: a fixed key, AdbKeyFixed)
AdbKeyOffsets     dw    PLAYER_INPUT_KEY_RIGHT,PLAYER_INPUT_KEY_LEFT,PLAYER_INPUT_KEY_DOWN,PLAYER_INPUT_KEY_UP
                  dw    0,0
                  dw    PLAYER_INPUT_KEY_UL,PLAYER_INPUT_KEY_UR,PLAYER_INPUT_KEY_DL,PLAYER_INPUT_KEY_DR
AdbKeyFixed       dw    0,0,0,0,J13_ID_RETURN*2,J13_ID_TAB*2,0,0,0,0

; Put the driver in: clear the keys, keyboard autopolling off, then the SRQ routine (the slides' order)
                mx %00
adbInstall
                  ldx       #256-2
:clear            stz       adbKeys,x
                  dex
                  dex
                  bpl       :clear
                  stz       adbStamp

                  pea       1
                  PushLong  #adbModeByte
                  pea       ADB_SET_MODES
                  Tool      $909                ; SendInfo
                  bcs       :failed

                  PushLong  #KbdAdb_SRQ
                  pea       ADB_KBD
                  Tool      $1409               ; SRQPoll
                  bcs       :poll_on

                  lda       #1
                  sta       adbInstalled
                  rts

:poll_on          jsr       adbPollOn
:failed           lda       #KBD_DRIVER_BASIC   ; Use the BASIC driver
                  sta       config_kbd_driver
                  rts

; KbdAdb_ShutDown
;
; Take the driver out, if it is in: the SRQ routine, then keyboard autopolling back on.  Called by
; KbdAdb_Apply and NES_ShutDown (rom/scaffold.s).  16-bit registers, DBR = the main bank.
                mx %00
KbdAdb_ShutDown
                  lda       adbInstalled
                  beq       :done
                  stz       adbInstalled
                  pea       ADB_KBD
                  Tool      $1509               ; SRQRemove
                  jmp       adbPollOn
:done             rts

adbPollOn         pea       1
                  PushLong  #adbModeByte
                  pea       ADB_CLEAR_MODES
                  Tool      $909                ; SendInfo
                  rts

; KbdAdb_SRQ
;
; The SRQ completion routine.  Called (jsl) by the ADB Tool Set at interrupt time, in native mode with 8-bit
; registers, with a pointer to the data (a count byte, then the keyboard's register 0) on the stack
; (ADB_SRQ_PTR).
; Must keep DBR, D and the 8-bit mode, and return (rtl) with carry clear.
;
; Register 0 has two events, one per byte: bit 7 = the key went up, bits 0 - 6 = its key code; $FF = no
; event.  Both bytes are $7F when the reset key goes down ($FF when it goes up).
                mx %11
KbdAdb_SRQ
                  phb
                  phd
                  rep       #$30
                  tsc                           ; D = S: the data pointer is a direct page pointer
                  tcd
                  phk
                  plb

                  lda       [ADB_SRQ_DP]
                  and       #$00FF
                  beq       :done               ; No data
                  ldy       #1
                  lda       [ADB_SRQ_DP],y      ; The two events, one per byte
                  sta       adbReg
                  and       #$7F7F
                  cmp       #{ADB_RESET*256}+ADB_RESET
                  beq       :reset

                  lda       adbReg
                  xba                           ; The same key in both, once down and once up: a tap
                  eor       adbReg              ; (lo ^ hi = $80).  Which byte is the first event isn't
                  and       #$00FF              ; certain (emulators differ), so it is handled as down,
                  cmp       #$0080              ; then up, whatever the order: up first would leave the
                  bne       :two                ; key down in adbKeys
                  lda       adbReg
                  and       #$007F
                  jsr       adbEvent            ; Down
                  lda       adbReg
                  and       #$007F
                  ora       #$0080
                  jsr       adbEvent            ; Up
                  bra       :done

:two              lda       adbReg              ; Otherwise the order only matters to which of two keys
                  xba                           ; pressed together counts as the later one
                  and       #$00FF
                  jsr       adbEvent
                  lda       adbReg
                  and       #$00FF
                  jsr       adbEvent

:done             sep       #$30
                  pld
                  plb
                  clc
                  rtl

                mx %00
:reset            lda       adbReg              ; Control-Command-Reset (down): restart the machine
                  cmp       #{ADB_RESET*256}+ADB_RESET
                  bne       :done
                  lda       adbKeys+{ADB_KEY_CONTROL*2}
                  beq       :done
                  lda       adbKeys+{ADB_KEY_COMMAND*2}
                  beq       :done
                  pea       0
                  PushLong  #adbKeyByte
                  pea       ADB_RESET_SYS
                  Tool      $909                ; SendInfo
                  bra       :done

adbReg            dw    0

; A = an event byte: update adbKeys, then pass the event to the microcontroller
                mx %00
adbEvent
                  cmp       #$00FF
                  beq       :out                ; No event
                  pha
                  and       #$007F
                  asl
                  tax
                  lda       1,s
                  bit       #$0080
                  bne       :up
                  lda       adbKeys,x
                  bne       :pass               ; Already down
                  inc       adbStamp
                  bne       *+5
                  inc       adbStamp            ; (never 0)
                  lda       adbStamp
                  sta       adbKeys,x
                  bra       :pass
:up               stz       adbKeys,x

:pass             pla
                  cmp       #ADB_KEY_MODS
                  bcc       :send
                  cmp       #ADB_KEY_MODS+5
                  bcs       :send
                  tax                           ; A modifier going down: not passed if $C025 has it down
                  sep       #$20                ; already (the slides' PassADBKeyIfOK)
                  ldal      MOD_REG
                  and       AdbModBits-ADB_KEY_MODS,x
                  rep       #$20
                  bne       :out
                  txa
:send             cmp       #$00E0              ; (not the $E0 - $FE prefix codes)
                  bcs       :out
                  sep       #$20
                  sta       adbKeyByte
                  rep       #$20
                  pea       1
                  PushLong  #adbKeyByte
                  pea       ADB_KEY_CODE
                  Tool      $909                ; SendInfo
:out              rts

; The $C025 bit of each modifier key: Control, Command, Shift, Caps Lock, Option
AdbModBits        db    $02,$80,$01,$04,$40

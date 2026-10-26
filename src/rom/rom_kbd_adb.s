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
; the keyboard itself: $C000 / $C010 / $C025, the auto-repeat, the configuration screen and the hotkeys
; work as with the other drivers.  The pad's buttons come from the driver's own key table (adbButtons).
;
; Works on every ROM, unlike J13 (rom/rom_kbd_j13.s), whose tables and key code map (J13_ADBKeys) it uses.
;
; A pad can't have opposite directions down: of the player's left / right keys that are down, the one
; pressed last wins, and the same for up / down (a diagonal key counts for both of its directions).
;
; The reset key and Control-Command-Esc: with autopolling off the microcontroller doesn't see the keyboard,
; so the driver does what the firmware would.  Each first turns autopolling back on, so the firmware has the
; keyboard again (after a reset, and in the CDA menu, which can't count on the SRQ routine), and suspends
; the driver (adbSuspended) until KbdAdb_Resume puts it back:
;
;   - Control-Reset: a reset (SendInfo resetSys)
;   - Control-Command-Reset: the power-up byte made invalid, then a reset, so it is always a cold start
;     (a restart), whatever the microcontroller thinks the modifiers are
;   - Control-Command-Esc: the Esc is passed on as usual, now with autopolling on (the CDA menu)
;
; If the reset doesn't happen, the keyboard is the firmware's (autopolling on), so pressing it again works
; without the driver.
;
; Known limit: the Control Panel's ToBRAMSetup turns the SRQ completion routine off (until ApplyConfig
; puts it back, when leaving the configuration screen).

; (KBD_DRIVER_ADB, and the KBD_ADB flag that builds the driver's hooks: core/Defs.s)

; The keyboard hardware this file reads (the rest goes through the ADB Tool Set)
ADB_KBD_STROBE_REG equ  $E0C010       ; Bit 7: a key is down (AKD); bits 0 - 6: the last key pressed
ADB_MOD_REG       equ   $E0C025       ; The firmware's modifiers (while autopolling is on)
ADB_MOD_CONTROL   equ   $02           ; ... their bits
ADB_MOD_COMMAND   equ   $80
ADB_BUTTON0_REG   equ   $E0C061       ; Bit 7: push button 0 (Command) down

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
ADB_KEY_ESC       equ   $35
ADB_KEY_CONTROL   equ   $36
ADB_KEY_COMMAND   equ   $37
ADB_KEY_MODS      equ   $36           ; Control, Command, Shift, Caps Lock, Option: $36 - $3A
ADB_KEY_SHIFT     equ   $38
ADB_KEY_RSHIFT    equ   $7B           ; (only reported apart from Shift if the keyboard is asked to)
ADB_KEY_RCONTROL  equ   $7D
ADB_KEY_OPTION    equ   $3A
ADB_KEY_ROPTION   equ   $7C
PWRUP_CHECK       equ   $0003F3       ; The reset vector's high byte: the power-up byte must be it EOR $A5
PWRUP_BYTE        equ   $0003F4       ; ... or the reset is a cold start

ADB_IDS           equ   20            ; One player's key ids (adbIds)

adbInstalled      dw    0             ; Non-zero while the SRQ routine is in and autopolling is off
adbSuspended      dw    0             ; Non-zero while autopolling is back on for a reset or the CDA menu
                                      ; (KbdAdb_Resume)
adbKeys           ds    256           ; Each key code's word: 0 = up, otherwise when it went down (adbStamp)
adbStamp          dw    0             ; Counts the key presses (never 0)
adbIds            ds    ADB_IDS*2     ; Each player's keys (KbdAdbIds, the J13_PadBits order), as adbKeys
                                      ; offsets (key code * 2); $FFFF = no key
adbModeByte       db    ADB_MODE_NO_POLL ; SendInfo data: the main code's and KbdAdb_SRQ's own
adbKeyByte        db    0

; KbdAdb_Pad
;
; The driver's pad routine (KbdDriverPad, core/CoreImpl.s): X = the player's configuration block, Y = the
; player (0 / 1).  Returns A = the full pad: the player's keys that are down, and the buttons from the
; driver's own key table (adbButtons).  Sets kbdHandled if the last key pressed is one of the player's
; keys.  Called with interrupts off, so adbKeys doesn't change meanwhile.  16-bit registers, DBR = the
; main bank.
                mx %00
KbdAdb_Pad
                  phx                           ; The configuration block, for the buttons
                  jsr       kbdAdbDirs
                  plx
                  jmp       adbButtons

kbdAdbDirs        sep       #$20
                  ldal      ADB_KBD_STROBE_REG  ; Bit 7: a key is down (AKD); bits 0 - 6: the last key pressed
                  rep       #$20
                  and       #$00FF
                  pha
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

; A = the pad bits, X = the player's configuration block: returns A with the player's A / B buttons added,
; from the driver's own key table rather than the push buttons: BUTTON_SWITCH_C061 is Command, C062
; Option (either side)
                mx %00
adbButtons        pha
                  lda:      PLAYER_INPUT_BUTTON_A,x
                  jsr       :down
                  beq       :no_a
                  lda       #PAD_BUTTON_A
                  ora       1,s
                  sta       1,s
:no_a             lda:      PLAYER_INPUT_BUTTON_B,x
                  jsr       :down
                  beq       :no_b
                  lda       #PAD_BUTTON_B
                  ora       1,s
                  sta       1,s
:no_b             pla
                  rts

; A = a BUTTON_SWITCH_*: Z clear if its key is down
:down             cmp       #BUTTON_SWITCH_C062
                  beq       :option
                  lda       adbKeys+{ADB_KEY_COMMAND*2}
                  rts
:option           lda       adbKeys+{ADB_KEY_OPTION*2}
                  ora       adbKeys+{ADB_KEY_ROPTION*2}
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
; can't be typed while this driver is in.  Called by _KbdPoll (rom/rom_kbd_basic.s) for a new key: if the
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
                  stz       adbSuspended

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
                  stz       adbSuspended
                  pea       ADB_KBD
                  Tool      $1509               ; SRQRemove
                  jmp       adbPollOn
:done             rts

adbPollOn         pea       1
                  PushLong  #adbModeByte
                  pea       ADB_CLEAR_MODES
                  Tool      $909                ; SendInfo
                  rts

; KbdAdb_Resume
;
; Called by the event loop (NES_EvtLoop, rom/scaffold.s): puts the driver back in after a reset key or
; Control-Command-Esc suspended it (the CDA menu has been left, or the reset didn't happen), once Control
; and Command are up, so they don't count as held.  16-bit registers, DBR = the main bank.
                mx %00
KbdAdb_Resume
                  lda       adbSuspended
                  beq       :out
                  sep       #$20
                  ldal      ADB_BUTTON0_REG     ; Command (live)
                  bmi       :held
                  ldal      ADB_MOD_REG         ; Control (autopolling is on: $C025 is the firmware's)
                  and       #ADB_MOD_CONTROL+ADB_MOD_COMMAND
                  bne       :held
                  rep       #$20
                  jsr       KbdAdb_ShutDown
                  jmp       adbInstall
:held             rep       #$20
:out              rts

; Z clear if Control (either) and Command are down by adbKeys
                mx %00
adbCtrlCmd        lda       adbKeys+{ADB_KEY_CONTROL*2}
                  ora       adbKeys+{ADB_KEY_RCONTROL*2}
                  beq       :out
                  lda       adbKeys+{ADB_KEY_COMMAND*2}
:out              rts

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
:reset            lda       adbReg              ; The reset key going down ($FFFF: going up)
                  cmp       #{ADB_RESET*256}+ADB_RESET
                  bne       :done
                  lda       adbKeys+{ADB_KEY_CONTROL*2}
                  ora       adbKeys+{ADB_KEY_RCONTROL*2}
                  beq       :done               ; Reset alone does nothing, as without the driver
                  jsr       adbPollOn           ; The firmware has the keyboard again (after the reset, or
                  lda       #1                  ; if it doesn't happen: KbdAdb_Resume)
                  sta       adbSuspended
                  lda       adbKeys+{ADB_KEY_COMMAND*2}
                  beq       :warm
                  sep       #$20                ; Control-Command-Reset: the power-up byte made invalid, so
                  ldal      PWRUP_CHECK         ; the reset is a cold start
                  eor       #$5A                ; (not $A5)
                  stal      PWRUP_BYTE
                  rep       #$20
:warm             pea       0
                  PushLong  #adbKeyByte
                  pea       ADB_RESET_SYS
                  Tool      $909                ; SendInfo: pulls the system reset line
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
                  bne       :drop               ; Already down: nothing changed, nothing to pass
                  inc       adbStamp
                  bne       *+5
                  inc       adbStamp            ; (never 0)
                  lda       adbStamp
                  sta       adbKeys,x
                  lda       1,s                 ; Control-Command-Esc: autopolling back on before the Esc
                  cmp       #ADB_KEY_ESC        ; goes to the firmware, so the CDA menu has the keyboard
                  bne       :pass
                  jsr       adbCtrlCmd
                  beq       :pass
                  jsr       adbPollOn
                  lda       #1
                  sta       adbSuspended
                  bra       :pass
:up               stz       adbKeys,x

:pass             pla                           ; Every change is passed, modifiers included: the
                  cmp       #$00E0              ; microcontroller's PROCESS_ADB_KEY sets / clears them in
                  bcs       :out                ; MODKEYS, which drives $C061 / $C062 (docs/adb).  ($C025
                  sep       #$20                ; can't tell whether one is already down: it is only
                  sta       adbKeyByte          ; written with a key press.)  Not the $E0 - $FE prefix codes.
                  rep       #$20
                  pea       1                   ; keyCode ($11) reads exactly one byte: any more would be
                  PushLong  #adbKeyByte         ; taken as the next command (docs/adb, $F2CC)
                  pea       ADB_KEY_CODE
                  Tool      $909                ; SendInfo
:out              rts
:drop             pla
                  rts

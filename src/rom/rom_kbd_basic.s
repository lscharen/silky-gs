; BASIC keyboard driver, and the keyboard layer every driver and the configuration screen use
;
; This file and the optional drivers (rom_kbd_j13.s, rom_kbd_adb.s) are the only code that touches the
; keyboard hardware ($C000, $C010, $C025, and the Command / Option push buttons $C061 / $C062).  The rest
; of the runtime goes through the _Kbd* routines at the end of this file.
;
; The pad: $C010 gives whether any key is down (AKD, bit 7) and the last key pressed (bits 0 - 6), so
; this driver sees one key at a time.  It doesn't use the $C000 strobe (the latch of a new key press):
; that is _KbdPoll's, for the event loop's keys, and _KbdReadRaw's, for the configuration screen.
;
; Latching (config_kbd_latch, the DRIVERS menu's LATCH DIRS; off by default): off, the pad is the key
; that is down, and the diagonals come from the diagonal keys.  On, to allow diagonals from two keys, the
; directions are held (kbdHeld): a left / right key replaces the held
; left / right and keeps the held up / down, and the other way round, so holding left and pressing up
; gives up + left.  The held directions stay while any key is down (a key that is not one of the
; player's directions changes nothing) and are dropped when no key is down.  So releasing one of two
; held directions doesn't show until every key is up or the opposite direction is pressed.  A key
; pressed and released between two polls is not seen.
;
; A diagonal key (PLAYER_INPUT_KEY_UL ... DR) is not held: while it is the last key pressed, it gives
; its two directions, and the held directions are left as they are for the keys after it.
;
; The keys go through kbdMaps (KbdBuildMaps), so that a key reads the same whatever modifiers were held
; when it was pressed.  The buttons come from the push buttons $C061 / $C062 (PAD_PUSH_BUTTONS,
; rom/rom_kbd_macs.s).

; (KBD_DRIVER_BASIC: core/Defs.s)

; The keyboard hardware this file uses
BASIC_KBD_REG     equ   $E0C000       ; Bits 0 - 6: the last key pressed; bit 7: the strobe (a new press)
BASIC_KBD_STROBE_REG equ $E0C010      ; Bit 7: a key is down (AKD), bits 0 - 6 as $C000; reading or
                                      ; writing it clears the strobe
BASIC_MOD_REG     equ   $E0C025       ; The modifiers (only written with a key press: docs/adb)
BASIC_BUTTON0_REG equ   $E0C061       ; Bit 7: push button 0 (Command) down
BASIC_BUTTON1_REG equ   $E0C062       ; Bit 7: push button 1 (Option) down

; KbdBasic_Pad
;
; The driver's pad routine (KbdDriverPad, core/CoreImpl.s): X = the player's configuration block, Y = the
; player (0 / 1).  Returns A = the full pad: the directions, Start and Select of the key that is down
; ($C010) and the held directions, and the buttons.  Sets kbdHandled if the key is one of the player's.
; 16-bit registers, DBR = the main bank.
                mx %00
KbdBasic_Pad      phx                           ; The configuration block, for the buttons
                  jsr       kbdBasicDirs
                  plx
                  PAD_PUSH_BUTTONS
                  rts

; Y = the player: returns A = the pad bits of the key that is down and, if latching, the held directions
; (kbdHeld stays 0 while latching is off)
kbdBasicDirs      sty       kbdHeldX
                  sep       #$20
                  ldal      BASIC_KBD_STROBE_REG ; Bit 7: a key is down (AKD); bits 0 - 6: the last key pressed
                  rep       #$20
                  and       #$00FF
                  bit       #PAD_KEY_DOWN
                  beq       :release            ; No key down: no direction is held
                  and       #PAD_KEY_MASK
                  cpy       #0                  ; The key in this player's half of kbdMaps
                  beq       *+5
                  ora       #$0080
                  tax
                  sep       #$20
                  lda       kbdMaps,x
                  beq       :held               ; Not the player's: the held directions stay
                  sta       kbdHandled          ; (non-zero: a control, not a built-in key)
                  ldx       config_kbd_latch
                  beq       :out                ; Not latching: just this key's pad bits
                  ldx       kbdHeldX
                  bit       #>{PAD_LEFT+PAD_RIGHT}
                  beq       :no_lr
                  bit       #>{PAD_UP+PAD_DOWN}
                  bne       :out                ; A diagonal key: its two directions, nothing held
                  pha                           ; Left / right replaces the held left / right
                  lda       kbdHeld,x
                  and       #>{PAD_UP+PAD_DOWN}
                  sta       kbdHeld,x
                  pla
:no_lr            bit       #>{PAD_UP+PAD_DOWN}
                  beq       :no_ud
                  pha                           ; Up / down replaces the held up / down
                  lda       kbdHeld,x
                  and       #>{PAD_LEFT+PAD_RIGHT}
                  sta       kbdHeld,x
                  pla
:no_ud            pha                           ; Keep the key's Start / Select
                  and       #>{PAD_UP+PAD_DOWN+PAD_LEFT+PAD_RIGHT}
                  ora       kbdHeld,x
                  sta       kbdHeld,x
                  pla
                  ora       kbdHeld,x
                  bra       :out

:held             ldx       kbdHeldX
                  lda       kbdHeld,x
:out              xba                           ; The pad bits go in the high byte
                  lda       #0
                  rep       #$20
                  rts

:release          ldx       kbdHeldX
                  sep       #$20
                  stz       kbdHeld,x
                  rep       #$20
                  lda       #0
                  rts

kbdHeld           db        0,0                 ; The held directions (pad bits >> 8), per player
kbdHeldX          dw        0                   ; ... the player's index in kbdHeld

; kbdMaps
;
; The key maps: the pad bits (the high byte: PAD_UP, PAD_START, ...) of each key code ($00 - $7F), player
; 1's then player 2's.  Built by KbdBuildMaps from the players' keys, so that a key reads the same whatever
; modifiers were held when it was pressed (the modifiers can be buttons, and $C000 keeps the code the key
; had when it went down):
;
;   - the player's direction keys (the diagonal ones get two directions), then Tab (Select) and Return
;     (Start), as they are
;   - then, for a letter, its other case (Shift, Caps Lock) and its Control code, unless that is an arrow
;     key's code (Control-H, J, K and U are $08, $0A, $0B and $15): every key goes to both players, so
;     player 2's J (left) would otherwise also be player 1's down arrow
;
; An entry already set is kept, so the keys as set come first.
kbdMaps           ds        256

kbdPlayer         dw        0                   ; KbdBuildMaps: the player's half of kbdMaps
kbdBlock          dw        0                   ; ... the player's configuration block
kbdBits           dw        0                   ; ... the key's pad bits
kbdCode           dw        0                   ; ... the key

; The direction keys' offsets in a configuration block and their pad bits
KbdKeys           dw        PLAYER_INPUT_KEY_DOWN,PAD_DOWN/256
                  dw        PLAYER_INPUT_KEY_UP,PAD_UP/256
                  dw        PLAYER_INPUT_KEY_LEFT,PAD_LEFT/256
                  dw        PLAYER_INPUT_KEY_RIGHT,PAD_RIGHT/256
                  dw        PLAYER_INPUT_KEY_UL,{PAD_UP+PAD_LEFT}/256
                  dw        PLAYER_INPUT_KEY_UR,{PAD_UP+PAD_RIGHT}/256
                  dw        PLAYER_INPUT_KEY_DL,{PAD_DOWN+PAD_LEFT}/256
                  dw        PLAYER_INPUT_KEY_DR,{PAD_DOWN+PAD_RIGHT}/256
KbdKeysEnd

; KbdBuildMaps
;
; Build kbdMaps from the players' keys.  Called at start-up (after the preferences are loaded) and by
; ApplyConfig.  16-bit registers, DBR = the main bank.
                mx %00
KbdBuildMaps
                  ldx       #256-2
:clear            stz       kbdMaps,x
                  dex
                  dex
                  bpl       :clear
                  ldx       #config_block_p1
                  lda       #0
                  jsr       :player
                  ldx       #config_block_p2
                  lda       #$80

:player           sta       kbdPlayer
                  stx       kbdBlock
                  ldy       #0                  ; The direction keys
:exact            jsr       :key
                  jsr       :set
                  iny
                  iny
                  iny
                  iny
                  cpy       #KbdKeysEnd-KbdKeys
                  bcc       :exact
                  lda       #PAD_SELECT/256
                  sta       kbdBits
                  lda       #9                  ; Tab
                  jsr       :set
                  lda       #PAD_START/256
                  sta       kbdBits
                  lda       #13                 ; Return
                  jsr       :set

                  ldy       #0                  ; The letters' other case and Control code
:alias            jsr       :key
                  and       #$007F
                  sta       kbdCode
                  and       #$005F              ; Upper case
                  cmp       #'A'
                  bcc       :next
                  cmp       #'Z'+1
                  bcs       :next
                  lda       kbdCode
                  eor       #$0020
                  jsr       :set
                  lda       kbdCode
                  and       #$001F
                  jsr       :ctrl
:next             iny
                  iny
                  iny
                  iny
                  cpy       #KbdKeysEnd-KbdKeys
                  bcc       :alias
                  rts

; Y = the KbdKeys entry: returns the player's key in A, and its pad bits in kbdBits
:key              lda       KbdKeys+2,y
                  sta       kbdBits
                  lda       KbdKeys,y
                  clc
                  adc       kbdBlock
                  tax
                  lda:      0,x
                  rts

; A = a letter's Control code: as :set, unless it is an arrow key's code
:ctrl             cmp       #LEFT_ARROW
                  beq       :arrow
                  cmp       #RIGHT_ARROW
                  beq       :arrow
                  cmp       #UP_ARROW
                  beq       :arrow
                  cmp       #DOWN_ARROW
                  bne       :set
:arrow            rts

; A = a key code: give it kbdBits, unless it has pad bits already (0 = no key: nothing)
:set              and       #$007F
                  beq       :none
                  ora       kbdPlayer
                  tax
                  sep       #$20
                  lda       kbdMaps,x
                  bne       :taken
                  lda       kbdBits
                  sta       kbdMaps,x
:taken            rep       #$20
:none             rts

; --- The keyboard layer ----------------------------------------------------------------------------------
;
; The low-level keyboard routines.  Everything outside the keyboard driver files reads the keyboard
; through these, so only one place owns the $C000 strobe.  They keep no engine state: the caller keeps
; what it needs (_ReadControl puts the poll's key in LastKey).  16-bit registers unless noted, DBR = the
; main bank.

kbdNewKey         dw        0                   ; Non-zero if this poll saw a new key press (_KbdPoll)

; _KbdPoll
;
; The game poll's key (_ReadControl): a new key press ($C000 strobe) goes to KeyEvent with its modifiers,
; for the event loop (NES_TakeKey), and sets kbdNewKey.  Returns A = the last key pressed | PAD_KEY_DOWN
; if a key was just pressed or is held, 0 if no key is down.
                mx %00
_KbdPoll
                  stz       kbdNewKey
                  pea       $0000               ; temporary space
                  sep       #$20

                  ldal      BASIC_KBD_REG       ; read the keyboard
                  bit       #$80                ; was the strobe bit set? If yes, then this is a new key
                  beq       :no_new_key

                  DO        KBD_ADB
                  jsr       KbdAdb_FixKey       ; (the ADB driver's shifted hotkeys, rom/rom_kbd_adb.s)
                  FIN
                  sta       1,s
                  sta       kbdNewKey           ; (for _ReadControl)
                  stal      KeyEvent            ; a new press, for the event loop (NES_TakeKey)
                  DO        KBD_J13
                  stal      j13New              ; and for the J13 keyboard driver (J13_Poll)
                  FIN
                  ldal      BASIC_MOD_REG       ; with the modifiers of the key (read before the strobe is
                  stal      KeyEvent+1          ; reset, while they still belong to it)
                  stal      BASIC_KBD_STROBE_REG ; reset the strobe
                  bra       :done               ; return the key value

:no_new_key
                  ldal      BASIC_KBD_STROBE_REG ; see if the key is being held
                  bit       #$80
                  beq       :done               ; No key down: 0

; The held key is the last one pressed.  Its code stays in $C000 bits 0-6 after the strobe is cleared,
; so take it from there: if something else cleared the strobe first (e.g. a keyboard interrupt handler
; left installed by an INIT or CDA), this poll never saw the key as new.
                  ldal      BASIC_KBD_REG
                  ora       #$80                ; same value as when the key was new
                  sta       1,s

:done
                  rep       #$20
                  pla
                  rts

; _KbdReadRaw
;
; For the configuration screen: A = the key code | PAD_KEY_DOWN if a key was just pressed ($C000 strobe,
; which is then cleared), 0 if not.  Held keys don't count.
                mx %00
_KbdReadRaw
                  pea       $0000               ; temporary space
                  sep       #$20

                  ldal      BASIC_KBD_REG       ; read the keyboard
                  bit       #$80                ; was the strobe bit set? If yes, then this is a new key
                  beq       :done

                  stal      BASIC_KBD_STROBE_REG ; reset the strobe
                  and       #$7F                ; isolate the key code
                  ora       #PAD_KEY_DOWN       ; set the keydown flag
                  sta       1,s

:done
                  rep       #$20
                  pla
                  rts

; _KbdWaitKey
;
; Clear the strobe, then wait for a new key press: returns A = its key code.
                mx %00
_KbdWaitKey       sep       #$20
                  stal      BASIC_KBD_STROBE_REG ; clear the strobe
:WFK              ldal      BASIC_KBD_REG
                  bpl       :WFK
                  rep       #$20
                  and       #$007F
                  rts

; _KbdClearStrobe
;
; Drop a key press that is waiting ($C000 strobe).
                mx %00
_KbdClearStrobe   sep       #$20
                  stal      BASIC_KBD_STROBE_REG
                  rep       #$20
                  rts

; _KbdWaitAllUp
;
; Wait until no key is down ($C010 AKD), then drop any key press waiting (the $C010 read clears the
; strobe), so the key that closed a screen doesn't reach the game.
                mx %00
_KbdWaitAllUp     sep       #$20
:held             ldal      BASIC_KBD_STROBE_REG ; Bit 7: a key is down (the read also clears the strobe)
                  bmi       :held
                  rep       #$20
                  rts

; _KbdReadButton
;
; For the configuration screen: A = a BUTTON_SWITCH_* (core/Defs.s): returns the push button's soft switch
; ($C061 / $C062), N = 1 if the button (Command / Option, or a joystick's) is down.  8-bit A, 16-bit X / Y
; (kept).
                mx %10
_KbdReadButton    cmp       #BUTTON_SWITCH_C062
                  beq       :c062
                  ldal      BASIC_BUTTON0_REG
                  rts
:c062             ldal      BASIC_BUTTON1_REG
                  rts
                mx %00

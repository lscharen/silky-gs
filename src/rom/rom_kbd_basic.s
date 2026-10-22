; BASIC keyboard driver: the keyboard through $C000 / $C010 only
;
; $C000 gives the last key pressed and $C010 whether any key is down, so this driver sees one key at a
; time.  To allow diagonals, the directions are held (kbdHeld): a left / right key replaces the held
; left / right and keeps the held up / down, and the other way round, so holding left and pressing up
; gives up + left.  The held directions stay while any key is down (a key that is not one of the
; player's directions changes nothing) and are dropped when no key is down.  So releasing one of two
; held directions doesn't show until every key is up or the opposite direction is pressed.  A key
; pressed and released between two polls still counts once.
;
; A diagonal key (PLAYER_INPUT_KEY_UL ... DR) is not held: while it is the last key pressed, it gives
; its two directions, and the held directions are left as they are for the keys after it.
;
; The keys go through kbdMaps (KbdBuildMaps), so that a key reads the same whatever modifiers were held
; when it was pressed.  The buttons are read by the KEYBOARD input type (_KbdButtons, core/CoreImpl.s).

KBD_DRIVER_BASIC  equ   0             ; config_kbd_driver (KbdDriverPad, core/CoreImpl.s)

; KbdBasic_Pad
;
; The driver's pad routine (KbdDriverPad, core/CoreImpl.s): A = the key (_ReadKeypress), Y = the player
; (0 / 1).  Returns A = the pad bits of the key and the held directions, and sets kbdHandled if the key
; is one of the player's.  16-bit registers, DBR = the main bank.
                mx %00
KbdBasic_Pad      sty       kbdHeldX
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

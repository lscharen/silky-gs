; Keyboard driver macros, shared by the keyboard drivers (rom/rom_kbd_*.s) and the joystick input type.
; Put by every game's Main.s with the runtime's constants (src/runtime/head.txt).  Macros only, no code.

; PAD_PUSH_BUTTONS
;
; A = the pad bits, X = the player's configuration block (PLAYER_INPUT_*): returns A with the player's
; A / B buttons added, each read from the push button soft switch it is mapped to (config_input_button_a /
; b: BUTTON_SWITCH_C061 / C062).  The switches follow Command / Option, and a joystick's buttons, live,
; even while another key is held ($C025 doesn't on real hardware: docs/adb).  16-bit registers in and out;
; X and Y are kept.  The branches use offsets, since a macro can't have local labels.
PAD_PUSH_BUTTONS  MAC
                  pha
                  sep       #$20
                  lda:      PLAYER_INPUT_BUTTON_A,x
                  cmp       #BUTTON_SWITCH_C062
                  beq       *+8                 ; -> ldal $E0C062
                  ldal      $E0C061             ; Button 0 / Command
                  bra       *+6                 ; -> bpl
                  ldal      $E0C062             ; Button 1 / Option
                  bpl       *+8                 ; Up: -> the B button
                  lda       #>PAD_BUTTON_A
                  ora       2,s
                  sta       2,s
                  lda:      PLAYER_INPUT_BUTTON_B,x
                  cmp       #BUTTON_SWITCH_C062
                  beq       *+8
                  ldal      $E0C061
                  bra       *+6
                  ldal      $E0C062
                  bpl       *+8
                  lda       #>PAD_BUTTON_B
                  ora       2,s
                  sta       2,s
                  rep       #$20
                  pla
                  <<<

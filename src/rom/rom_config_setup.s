; Shared configuration setup
;
; Defines the built-in configuration variables, the configuration screen menus/controls
; (rendered by rom_config.s) and ApplyConfig.  Each game's Main.s selects which built-in
; menus to show and can add its own settings through the following definitions:
;
;   CONFIG_DEFAULT_AUDIO equ APU_60HZ / APU_120HZ / APU_240HZ
;                                  Default audio quality
;   CONFIG_VIDEO_MENU    equ 0/1   Show the VIDEO menu (status bar, fast blit)
;   CONFIG_INPUT_BUTTONS equ 0/1   Allow remapping the A/B buttons for keyboard input
;   CONFIG_INPUT_2P      equ 0/1   Show P1/P2 tabs on the INPUT menu (otherwise P1 only)
;   CONFIG_GAME_MENU     equ 0/1   Append the game's own menu.  Main.s must then define a menu
;                                  block labeled GAME_CONFIG whose previous menu item is
;                                  INPUT_CONFIG and next menu item is 0.
;
;   config_game_start / config_game_end
;                                  Labels (required, may be empty) bracketing the game's own
;                                  configuration variables.  This block is saved to / loaded
;                                  from the preferences file right after the built-in block,
;                                  so game controls can point their value address into it.
;
;   CONFIG_APPLY_HOOK mac          Callback invoked at the end of ApplyConfig, after the built-in
;                                  settings have been applied.  Define an empty macro for no
;                                  callback.  On entry (16-bit registers, B = program bank):
;
;                                    X = config_block_start (built-in values, CFG_* offsets)
;                                    Y = config_game_start  (game values)

; ApplyConfig
;
; Read the variables set up by the configuration screen and apply them to the runtime engine.
            mx    %00
ApplyConfig
            lda   config_video_fastmode
            beq   :normal_video
            lda   #CTRL_EVEN_RENDER
            tsb   ControlBits
            bra   :apply_video
:normal_video
            lda   #CTRL_EVEN_RENDER
            trb   ControlBits
:apply_video
            lda   #0
            jsr   FillScreen
            jsr   _InitRenderMode

            lda   config_audio_quality
            jsr   APUReload

            ldx   #config_block_start
            ldy   #config_game_start
            CONFIG_APPLY_HOOK

            rep   #$30
            rts

; Configuration screen and variables
;
; The configuration screen has two sections -- the menu and the controls.  Each
; menu defines a set of controls and each control references a memory location
; that stores a configuration value.
;
; The focus can either be on the menu column or the control column and code tracks
; the active menu and the active control.  Navigation is primarily controlled
; by prev/next pointers on the menu and control itmes that direct which control to
; select in response to the user's inputs.

config_block_start                    ; range saved / loaded by misc/io.s
config_audio_quality   dw  CONFIG_DEFAULT_AUDIO  ; good / better / best audio quality (60Hz, 120Hz, 240Hz audio interrupts)
config_video_statusbar dw  1  ; exclude the status bar from the animate playfield area or not
config_video_fastmode  ds  2  ; use the "skip line" rendering mode

; player 1 config block (layout is fixed by the PLAYER_INPUT_* offsets in core/CoreImpl.s)
config_block_p1
config_input_p1_type   dw  0  ; keyboard / snes max
config_input_key_left  dw  LEFT_ARROW
config_input_key_right dw  RIGHT_ARROW
config_input_key_up    dw  UP_ARROW
config_input_key_down  dw  DOWN_ARROW
config_input_snesmax_port dw 4
config_input_button_a  dw  MOD_REG_COMMAND_DOWN
config_input_button_b  dw  MOD_REG_OPTION_DOWN

; player 2 config block
config_block_p2
config_input_p2_type      dw  0
config_input_p2_key_left  dw  'j'
config_input_p2_key_right dw  'l'
config_input_p2_key_up    dw  'i'
config_input_p2_key_down  dw  'k'
config_input_p2_snesmax_port dw 4
config_input_p2_button_a  dw  MOD_REG_CONTROL_DOWN
config_input_p2_button_b  dw  MOD_REG_SHIFT_DOWN
config_block_end

; Offsets of the built-in values from config_block_start (X register in CONFIG_APPLY_HOOK)
CFG_AUDIO_QUALITY   equ config_audio_quality-config_block_start
CFG_VIDEO_STATUSBAR equ config_video_statusbar-config_block_start
CFG_VIDEO_FASTMODE  equ config_video_fastmode-config_block_start
CFG_INPUT_P1        equ config_block_p1-config_block_start
CFG_INPUT_P2        equ config_block_p2-config_block_start

             DO   CONFIG_INPUT_2P
config_tab_value    dw 0      ; selected INPUT tab (UI state only, not saved)
             FIN

AUDIO_TITLE_STR     str 'AUDIO'
AUDIO_QUALITY_STR   str 'QUALITY'
AUDIO_QUALITY_60HZ  str ' 60 HZ'
AUDIO_QUALITY_120HZ str '120 HZ'
AUDIO_QUALITY_240HZ str '240 HZ'

             DO   CONFIG_VIDEO_MENU
VIDEO_TITLE_STR      str 'VIDEO'
VIDEO_FASTMODE_STR   str 'FAST BLIT'
VIDEO_STATUS_BAR_STR str 'STATUS BAR'
             FIN

INPUT_TITLE_STR     str 'INPUT'
INPUT_TYPE_STR      str 'TYPE'
INPUT_TYPE_OPT_1    str 'KEYBOARD'
INPUT_TYPE_OPT_2    str 'JOYSTICK'
INPUT_TYPE_OPT_3    str 'SNES MAX'
INPUT_LEFT_MAP_STR  str 'LEFT'
INPUT_RIGHT_MAP_STR str 'RIGHT'
INPUT_UP_MAP_STR    str 'UP'
INPUT_DOWN_MAP_STR  str 'DOWN'
INPUT_SNESMAX_PORT_STR str 'SLOT'
             DO   CONFIG_INPUT_BUTTONS
INPUT_BUTTON_A_STR  str 'A BUTTON'
INPUT_BUTTON_B_STR  str 'B BUTTON'
             FIN

             DO   CONFIG_INPUT_2P
PLAYER_INPUT_STR    str 'PLAYER INPUTS'
PLAYER_1_STR        str 'P1'
PLAYER_2_STR        str 'P2'
             FIN

; The configuration screen leverages the NES runtime itself
CONFIG_BLK   db   CONFIG_PALETTE        ; Which background palette to use
             db   TILE_TOP_LEFT         ; Define the tiles to use for the UI
             db   TILE_TOP_RIGHT
             db   TILE_HORIZONTAL_TOP
             db   TILE_HORIZONTAL_BOTTOM
             db   TILE_VERTICAL_LEFT
             db   TILE_VERTICAL_RIGHT
             db   TILE_ZERO             ; First tile for the 0 - 9 characters
             db   TILE_A                ; First tile for the alphabet A - Z characters
             db   TILE_SPACE

; Menu list: "Audio", ["Video"], "Input", [game menu]
CONFIG_MENU  dw   2+CONFIG_VIDEO_MENU+CONFIG_GAME_MENU
             dw   AUDIO_CONFIG
             DO   CONFIG_VIDEO_MENU
             dw   VIDEO_CONFIG
             FIN
             dw   INPUT_CONFIG
             DO   CONFIG_GAME_MENU
             dw   GAME_CONFIG
             FIN

AUDIO_CONFIG dw   AUDIO_TITLE_STR
             dw   0                     ; previous menu item
             DO   CONFIG_VIDEO_MENU
             dw   VIDEO_CONFIG          ; next menu item
             ELSE
             dw   INPUT_CONFIG
             FIN

             dw   1                     ; One configuration element
             dw   AUDIO_ITEM_1

AUDIO_ITEM_1 dw   RADIO                 ; A radio button (mutually exclusive) option
             dw   0                     ; previous control
             dw   0                     ; next control
             dw   3,2                   ; X,Y location of control in the config area
             dw   AUDIO_QUALITY_STR     ; Title
             dw   config_audio_quality  ; Memory address to write the configuration value
             dw   3                     ; Three options

             dw   APU_60HZ              ; config value
             dw   AUDIO_QUALITY_60HZ    ; config label
             dw   0                     ; conditional control (if null, nothing)

             dw   APU_120HZ
             dw   AUDIO_QUALITY_120HZ
             dw   0

             dw   APU_240HZ
             dw   AUDIO_QUALITY_240HZ
             dw   0

             DO   CONFIG_VIDEO_MENU
VIDEO_CONFIG dw   VIDEO_TITLE_STR
             dw   AUDIO_CONFIG          ; previous menu item
             dw   INPUT_CONFIG          ; next menu item

             dw   2                     ; Two configuration elements
             dw   VIDEO_ITEM_1
             dw   VIDEO_ITEM_2

VIDEO_ITEM_1 dw   CHKBOX                ; Checkbox just forces a 0/1 for False/True
             dw   0                     ; previous control
             dw   VIDEO_ITEM_2          ; next control
             dw   3,2
             dw   VIDEO_STATUS_BAR_STR
             dw   config_video_statusbar

VIDEO_ITEM_2 dw   CHKBOX
             dw   VIDEO_ITEM_1          ; previous control
             dw   0                     ; next control
             dw   3,4
             dw   VIDEO_FASTMODE_STR
             dw   config_video_fastmode
             FIN

INPUT_CONFIG dw   INPUT_TITLE_STR
             DO   CONFIG_VIDEO_MENU
             dw   VIDEO_CONFIG          ; previous menu item
             ELSE
             dw   AUDIO_CONFIG
             FIN
             DO   CONFIG_GAME_MENU
             dw   GAME_CONFIG           ; next menu item
             ELSE
             dw   0
             FIN

             dw   1
             DO   CONFIG_INPUT_2P
             dw   TAB_ITEM_1
             ELSE
             dw   INPUT_ITEM_1
             FIN

; Vertical layout of the input controls.  The P1/P2 tabs push everything down.
             DO   CONFIG_INPUT_2P
INPUT_TYPE_Y   equ 5
INPUT_LIST_Y   equ 10
INPUT_BUTTON_Y equ 15
             ELSE
INPUT_TYPE_Y   equ 2
INPUT_LIST_Y   equ 8
INPUT_BUTTON_Y equ 13
             FIN
INPUT_KEY_COUNT equ 4+{2*CONFIG_INPUT_BUTTONS}

             DO   CONFIG_INPUT_2P
TAB_ITEM_1   dw   TAB
             dw   0
             dw   0
             dw   3,2
             dw   PLAYER_INPUT_STR
             dw   config_tab_value

             dw   2                    ; two tabs

             dw   0                    ; selection, value
             dw   PLAYER_1_STR
             dw   4                    ; label width
             dw   INPUT_ITEM_1

             dw   1
             dw   PLAYER_2_STR
             dw   4
             dw   INPUT_ITEM_P2
             FIN

; Player 1 input controls
INPUT_ITEM_1 dw   RADIO
             DO   CONFIG_INPUT_2P
             dw   TAB_ITEM_1
             ELSE
             dw   0
             FIN
             dw   0                    ; No NEXT defined, use the selected item
             dw   3,INPUT_TYPE_Y
             dw   INPUT_TYPE_STR
             dw   config_input_p1_type
             dw   2

             dw   0
             dw   INPUT_TYPE_OPT_1
             dw   KEYBOARD_LIST

             dw   2
             dw   INPUT_TYPE_OPT_3
             dw   SNESMAX_LIST

SNESMAX_LIST  dw  NUMBER_SELECT
              dw  INPUT_ITEM_1
              dw  0
              dw  3,INPUT_LIST_Y
              dw  INPUT_SNESMAX_PORT_STR
              dw  config_input_snesmax_port

              dw  1            ; minimum value
              dw  7            ; maximum value

KEYBOARD_LIST dw  CTRL_LIST
              dw  INPUT_KEY_COUNT
              dw  INPUT_ITEM_2
              dw  INPUT_ITEM_3
              dw  INPUT_ITEM_4
              dw  INPUT_ITEM_5
             DO   CONFIG_INPUT_BUTTONS
              dw  INPUT_ITEM_6
              dw  INPUT_ITEM_7
             FIN

INPUT_ITEM_2 dw   KEYMAP
             dw   INPUT_ITEM_1
             dw   INPUT_ITEM_3
             dw   3,INPUT_LIST_Y
             dw   INPUT_LEFT_MAP_STR
             dw   config_input_key_left

INPUT_ITEM_3 dw   KEYMAP
             dw   INPUT_ITEM_2
             dw   INPUT_ITEM_4
             dw   3,INPUT_LIST_Y+1
             dw   INPUT_RIGHT_MAP_STR
             dw   config_input_key_right

INPUT_ITEM_4 dw   KEYMAP
             dw   INPUT_ITEM_3
             dw   INPUT_ITEM_5
             dw   3,INPUT_LIST_Y+2
             dw   INPUT_UP_MAP_STR
             dw   config_input_key_up

INPUT_ITEM_5 dw   KEYMAP
             dw   INPUT_ITEM_4
             DO   CONFIG_INPUT_BUTTONS
             dw   INPUT_ITEM_6
             ELSE
             dw   0
             FIN
             dw   3,INPUT_LIST_Y+3
             dw   INPUT_DOWN_MAP_STR
             dw   config_input_key_down

             DO   CONFIG_INPUT_BUTTONS
INPUT_ITEM_6 dw   BTNMAP
             dw   INPUT_ITEM_5
             dw   INPUT_ITEM_7
             dw   3,INPUT_BUTTON_Y
             dw   INPUT_BUTTON_A_STR
             dw   config_input_button_a

INPUT_ITEM_7 dw   BTNMAP
             dw   INPUT_ITEM_6
             dw   0
             dw   3,INPUT_BUTTON_Y+1
             dw   INPUT_BUTTON_B_STR
             dw   config_input_button_b
             FIN

; Player 2 input controls
             DO   CONFIG_INPUT_2P
INPUT_ITEM_P2 dw  RADIO
             dw   TAB_ITEM_1
             dw   0                    ; No NEXT defined, use the selected item
             dw   3,INPUT_TYPE_Y
             dw   INPUT_TYPE_STR
             dw   config_input_p2_type
             dw   2

             dw   0
             dw   INPUT_TYPE_OPT_1
             dw   KEYBOARD_LIST_2

             dw   2
             dw   INPUT_TYPE_OPT_3
             dw   SNESMAX_LIST_2

SNESMAX_LIST_2 dw NUMBER_SELECT
              dw  INPUT_ITEM_P2
              dw  0
              dw  3,INPUT_LIST_Y
              dw  INPUT_SNESMAX_PORT_STR
              dw  config_input_p2_snesmax_port

              dw  1            ; minimum value
              dw  7            ; maximum value

KEYBOARD_LIST_2 dw CTRL_LIST
              dw  INPUT_KEY_COUNT
              dw  INPUT_ITEM_8
              dw  INPUT_ITEM_9
              dw  INPUT_ITEM_10
              dw  INPUT_ITEM_11
             DO   CONFIG_INPUT_BUTTONS
              dw  INPUT_ITEM_12
              dw  INPUT_ITEM_13
             FIN

INPUT_ITEM_8 dw   KEYMAP
             dw   INPUT_ITEM_P2
             dw   INPUT_ITEM_9
             dw   3,INPUT_LIST_Y
             dw   INPUT_LEFT_MAP_STR
             dw   config_input_p2_key_left

INPUT_ITEM_9 dw   KEYMAP
             dw   INPUT_ITEM_8
             dw   INPUT_ITEM_10
             dw   3,INPUT_LIST_Y+1
             dw   INPUT_RIGHT_MAP_STR
             dw   config_input_p2_key_right

INPUT_ITEM_10 dw  KEYMAP
             dw   INPUT_ITEM_9
             dw   INPUT_ITEM_11
             dw   3,INPUT_LIST_Y+2
             dw   INPUT_UP_MAP_STR
             dw   config_input_p2_key_up

INPUT_ITEM_11 dw  KEYMAP
             dw   INPUT_ITEM_10
             DO   CONFIG_INPUT_BUTTONS
             dw   INPUT_ITEM_12
             ELSE
             dw   0
             FIN
             dw   3,INPUT_LIST_Y+3
             dw   INPUT_DOWN_MAP_STR
             dw   config_input_p2_key_down

             DO   CONFIG_INPUT_BUTTONS
INPUT_ITEM_12 dw  BTNMAP
             dw   INPUT_ITEM_11
             dw   INPUT_ITEM_13
             dw   3,INPUT_BUTTON_Y
             dw   INPUT_BUTTON_A_STR
             dw   config_input_p2_button_a

INPUT_ITEM_13 dw  BTNMAP
             dw   INPUT_ITEM_12
             dw   0
             dw   3,INPUT_BUTTON_Y+1
             dw   INPUT_BUTTON_B_STR
             dw   config_input_p2_button_b
             FIN
             FIN

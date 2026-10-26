; Shared configuration setup
;
; Defines the built-in configuration variables, the configuration screen menus/controls
; (rendered by rom_config.s) and ApplyConfig.  Each game's Main.s selects which built-in
; menus to show and can add its own settings through the following definitions:
;
;   CONFIG_DEFAULT_AUDIO equ APU_60HZ / APU_120HZ / APU_240HZ
;                                  Default audio quality
;   CONFIG_VIDEO_MENU    equ 0/1   Show the VIDEO menu (show FPS, show NES CPU, status bar, fast blit)
;   CONFIG_VIDEO_STATUSBAR equ 0/1 Show the STATUS BAR option on the VIDEO menu (needs CONFIG_VIDEO_MENU).
;                                  For the games with a separately drawn status bar (SMB, Excitebike,
;                                  Balloon Fight); the value is config_video_statusbar (CFG_VIDEO_STATUSBAR).
;                                  Nothing reads it yet: it is for a deferred optimization that skips
;                                  redrawing a scrolling game's fixed status bar when no sprite is on it
;                                  and it hasn't changed, and only redraws the scrolling area (16 lines a
;                                  frame for SMB).  Left out of dist/README.TXT until it does something.
;   CONFIG_VIDEO_FASTBLIT equ 0/1  Show the FAST BLIT option on the VIDEO menu (needs CONFIG_VIDEO_MENU).
;                                  Only useful for scrolling games, which do full renders.  When 0, a
;                                  fast blit setting in an old preferences file is ignored.
;   CONFIG_INPUT_2P      equ 0/1   Show P1/P2 tabs on the INPUT menu (otherwise P1 only)
;   CONFIG_GAME_MENU     equ 0/1   Append the game's own menu.  Main.s must then define a menu
;                                  block labeled GAME_CONFIG whose previous menu item is
;                                  DRIVERS_CONFIG and next menu item is CREDITS_CONFIG.
;
; The CREDITS menu is always last.  At most 10 menus fit on the screen.
;
;   CONFIG_GAME_DEFAULTS mac       The game's own configuration values: CONFIG_GAME_SIZE (128) bytes
;                                  at config_game_start, right after the built-in block and saved with
;                                  it.  The macro lays out their default values (dw / db), each at its
;                                  ID: the value's byte offset in the block, which the game defines
;                                  (e.g. CFG_GAME_X equ 0, CFG_GAME_Y equ 2 for two words).  The rest
;                                  of the block is 0.  A game control's value address is
;                                  config_game_start+ID, and the hook below reads ID,y.  New values
;                                  go after the existing ones, with a default of 0 in an older
;                                  preferences file, so the file keeps its size and keeps loading.
;                                  A single ';' line for a game with no values (an empty macro body
;                                  breaks the build).
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
            DO    CONFIG_VIDEO_FASTBLIT
            lda   config_video_fastmode
            beq   :normal_video
            lda   #CTRL_EVEN_RENDER
            tsb   ControlBits
            bra   :apply_video
:normal_video
            lda   #CTRL_EVEN_RENDER
            trb   ControlBits
:apply_video
            FIN
            jsr   _ClearShadowScreen          ; With shadowing on, so fast blit leaves no stale lines
            jsr   KbdBuildMaps                ; The BASIC keyboard driver's key maps
            DO    KBD_ADB
            jsr   KbdAdb_Apply                ; The ADB driver's keys, and put it in or take it out
            FIN
            DO    JOYSTICK_SUPPORT
            jsl   JoyConfigureL               ; Before _InitRenderMode, which hooks the probe rows if used
            FIN
            jsr   _InitRenderMode

            lda   config_audio_quality
            jsr   APUReload

            ldx   #config_block_start
            ldy   #config_game_start
            CONFIG_APPLY_HOOK

            rep   #$30
            rts

; _FixPrefInputTypes
;
; After LoadPrefData: an input type with no reader in _ReadControl becomes KEYBOARD, a keyboard driver
; that isn't built BASIC, an older file's joystick sensitivity (0) the default, and an older file's button
; mappings ($C025 bits) the defaults.
            mx    %00
_FixPrefInputTypes
            lda   config_kbd_driver
            beq   :drv_ok                     ; BASIC
            DO    KBD_J13
            cmp   #KBD_DRIVER_J13
            beq   :drv_ok
            FIN
            DO    KBD_ADB
            cmp   #KBD_DRIVER_ADB
            beq   :drv_ok
            FIN
            stz   config_kbd_driver
:drv_ok
            ldx   #config_input_button_a
            lda   #BUTTON_SWITCH_C061
            jsr   :button
            ldx   #config_input_button_b
            lda   #BUTTON_SWITCH_C062
            jsr   :button
            ldx   #config_input_p2_button_a
            lda   #BUTTON_SWITCH_C061
            jsr   :button
            ldx   #config_input_p2_button_b
            lda   #BUTTON_SWITCH_C062
            jsr   :button
            lda   config_joy_sens
            bne   *+8
            lda   #JOY_DEFAULT_SENS
            sta   config_joy_sens
            ldx   #config_input_p1_type
            jsr   :fix
            ldx   #config_input_p2_type
:fix        lda:  0,x
            beq   :ok                         ; KEYBOARD
            cmp   #2
            beq   :ok                         ; SNES MAX
            DO    JOYSTICK_SUPPORT
            cmp   #INPUT_JOYSTICK
            beq   :ok
            FIN
            stz:  0,x
:ok         rts

; X = a button mapping, A = its default: the default unless it is a BUTTON_SWITCH_*
:button     pha
            lda:  0,x
            cmp   #BUTTON_SWITCH_C061
            beq   :keep
            cmp   #BUTTON_SWITCH_C062
            beq   :keep
            pla
            sta:  0,x
            rts
:keep       pla
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
config_video_statusbar dw  1  ; exclude the status bar from the animate playfield area or not (not used yet)
config_video_fastmode  ds  2  ; use the "skip line" rendering mode

; player 1 config block (layout is fixed by the PLAYER_INPUT_* offsets in core/CoreImpl.s)
config_block_p1
config_input_p1_type   ENT
                       dw  0  ; 0 = keyboard, 2 = snes max, INPUT_JOYSTICK = joystick
config_input_key_left  dw  LEFT_ARROW
config_input_key_right dw  RIGHT_ARROW
config_input_key_up    dw  UP_ARROW
config_input_key_down  dw  DOWN_ARROW
config_input_snesmax_port dw 4
config_input_button_a  dw  BUTTON_SWITCH_C061  ; the soft switch each button reads (PAD_PUSH_BUTTONS)
config_input_button_b  dw  BUTTON_SWITCH_C062

; player 2 config block
config_block_p2
config_input_p2_type      ENT
                          dw  0
config_input_p2_key_left  dw  'a'
config_input_p2_key_right dw  'd'
config_input_p2_key_up    dw  'w'
config_input_p2_key_down  dw  's'
config_input_p2_snesmax_port dw 4
config_input_p2_button_a  dw  BUTTON_SWITCH_C061
config_input_p2_button_b  dw  BUTTON_SWITCH_C062

; Added after the original layout, so the values above keep their offsets
config_video_fps       dw  0  ; show the renders per second at the top-left of the screen (DrawFPS)
config_video_nescpu    dw  0  ; border = the task that owns the CPU, a raster bar of game logic time (saveCtx)
config_kbd_driver      dw  KBD_DRIVER_BASIC  ; keyboard driver of the KEYBOARD input type (rom/rom_kbd_j13.s)
config_joy_cx          ENT                ; The joystick's calibrated center, X (VBL_VERT_REG steps x 16;
                       dw  0              ; 0 = not calibrated)
config_joy_cy          ENT                ; ... Y
                       dw  0
config_joy_sens        ENT                ; Its sensitivity, 1 - 7 (dead zone = 8 - it steps; an older
                       dw  JOY_DEFAULT_SENS  ; file's 0 is made the default by _FixPrefInputTypes)
config_kbd_latch       dw  0              ; BASIC keyboard driver: hold the directions while any key is down
                                          ; (kbdHeld); 0 = only the key that is down.  (Was the joystick's
                                          ; offset, so an older file has 0 here)

; The diagonal keys of each player (0 = none), at the same distance from each player's block
; (PLAYER_INPUT_KEY_UL ... DR, core/CoreImpl.s), so player 2's follow 8 bytes after player 1's
config_input_key_ul    dw  0
config_input_key_ur    dw  0
config_input_key_dl    dw  0
config_input_key_dr    dw  0
                       ds  8
config_input_p2_key_ul dw  0
config_input_p2_key_ur dw  0
config_input_p2_key_dl dw  0
config_input_p2_key_dr dw  0
            ERR   {config_input_p2_key_ul-config_block_p2}-{config_input_key_ul-config_block_p1}
            ERR   {config_input_key_ul-config_block_p1}-PLAYER_INPUT_KEY_UL
            ERR   {config_input_key_dr-config_block_p1}-PLAYER_INPUT_KEY_DR

; Room for new built-in values.  Add them here (taking from the reserve), so the size of the block, and
; with it the preferences file, stays the same and older files keep loading (misc/io.s checks the size).
; A new value must default to 0, since an older file has 0 in its place.
config_reserved        ds  92
config_block_end

; The game's own values (CONFIG_GAME_DEFAULTS, the game's Main.s), in a block of a fixed size, saved and
; loaded together with the built-in block (misc/io.s)
CONFIG_GAME_SIZE equ 128
config_game_start
            CONFIG_GAME_DEFAULTS
            ERR   {*-config_game_start}/{CONFIG_GAME_SIZE+1}  ; The game's values are over CONFIG_GAME_SIZE
            ds    CONFIG_GAME_SIZE-{*-config_game_start}
config_game_end

; Offsets of the built-in values from config_block_start (X register in CONFIG_APPLY_HOOK)
CFG_AUDIO_QUALITY   equ config_audio_quality-config_block_start
CFG_VIDEO_STATUSBAR equ config_video_statusbar-config_block_start
CFG_VIDEO_FASTMODE  equ config_video_fastmode-config_block_start
CFG_INPUT_P1        equ config_block_p1-config_block_start
CFG_INPUT_P2        equ config_block_p2-config_block_start
CFG_VIDEO_FPS       equ config_video_fps-config_block_start
CFG_VIDEO_NESCPU    equ config_video_nescpu-config_block_start
CFG_KBD_DRIVER      equ config_kbd_driver-config_block_start

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
VIDEO_FPS_STR        str 'SHOW FPS'
VIDEO_NESCPU_STR     str 'SHOW NES CPU'
VIDEO_STATUS_BAR_STR str 'STATUS BAR'
             FIN

INPUT_TITLE_STR     str 'INPUT'
INPUT_TYPE_STR      str 'TYPE'
INPUT_TYPE_OPT_1    str 'KEYBOARD'
INPUT_TYPE_OPT_2    str 'JOYSTICK'
INPUT_TYPE_OPT_3    str 'SNES MAX'
INPUT_KEYS_STR      str 'KEYS'
INPUT_SNESMAX_PORT_STR str 'SLOT'
INPUT_BUTTON_A_STR  str 'A BUTTON'
INPUT_BUTTON_B_STR  str 'B BUTTON'

DRIVERS_TITLE_STR   str 'DRIVERS'
DRIVERS_KBD_STR     str 'KEYBOARD'
DRIVERS_LATCH_STR   str 'LATCH DIRS'  ; the BASIC driver's held directions (config_kbd_latch)
DRIVERS_KBD_BASIC   str 'BASIC'        ; the last key pressed, directions held (rom/rom_kbd_basic.s)
DRIVERS_KBD_J13     str 'J13 ROM 01'   ; several keys held at once, ROM 00 / 01 firmware only (rom/rom_kbd_j13.s; the font has no parentheses)
DRIVERS_KBD_ADB     str 'ADB'          ; every key's up / down state from the ADB keyboard, any ROM (rom/rom_kbd_adb.s)

CREDITS_TITLE_STR   str 'CREDITS'

; The credits text: upper case letters, digits and spaces only (other characters are drawn blank),
; at most 19 characters per line
CREDITS_HEADER_STR  str 'THANKS TO'
CREDITS_LINE_1      str ' ALEX LEE'
CREDITS_LINE_2      str ' BRUTAL DELUXE'
CREDITS_LINE_3      str ' CHRIS VAVRUSKA'
CREDITS_LINE_4      str ' FATDOG'
CREDITS_LINE_5      str ' IAN BRUMBY'
CREDITS_LINE_6      str ' JAWAID BAZYAR'
CREDITS_LINE_7      str ' JAY CRAFT'
CREDITS_LINE_8      str 'AND EVERYONE ON THE'
CREDITS_LINE_9      str 'APPLE II INFINITUM'
CREDITS_LINE_10     str 'THANK YOU ALL'

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

; Menu list: "Audio", ["Video"], "Input", "Drivers", [game menu], "Credits"
CONFIG_MENU  dw   4+CONFIG_VIDEO_MENU+CONFIG_GAME_MENU
             dw   AUDIO_CONFIG
             DO   CONFIG_VIDEO_MENU
             dw   VIDEO_CONFIG
             FIN
             dw   INPUT_CONFIG
             dw   DRIVERS_CONFIG
             DO   CONFIG_GAME_MENU
             dw   GAME_CONFIG
             FIN
             dw   CREDITS_CONFIG

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

             dw   2+CONFIG_VIDEO_STATUSBAR+CONFIG_VIDEO_FASTBLIT ; Number of configuration elements
             dw   VIDEO_ITEM_FPS
             dw   VIDEO_ITEM_NESCPU
             DO   CONFIG_VIDEO_STATUSBAR
             dw   VIDEO_ITEM_SB
             FIN
             DO   CONFIG_VIDEO_FASTBLIT
             dw   VIDEO_ITEM_FB
             FIN

; SHOW FPS and SHOW NES CPU are always shown; STATUS BAR (CONFIG_VIDEO_STATUSBAR) and FAST BLIT
; (CONFIG_VIDEO_FASTBLIT) follow when the game shows them.  Every item is assembled, so the links and
; rows are expressions of the flags rather than DO / ELSE blocks.  A link to the item itself means there
; is nothing in that direction (moving there leaves the cursor where it is).
VIDEO_ITEM_FPS dw CHKBOX                ; Checkbox just forces a 0/1 for False/True
             dw   0                     ; previous control
             dw   VIDEO_ITEM_NESCPU     ; next control
             dw   3,2
             dw   VIDEO_FPS_STR
             dw   config_video_fps

VIDEO_ITEM_NESCPU dw CHKBOX
             dw   VIDEO_ITEM_FPS        ; previous control
             dw   VIDEO_ITEM_NESCPU+{CONFIG_VIDEO_STATUSBAR*{VIDEO_ITEM_SB-VIDEO_ITEM_NESCPU}}+{{1-CONFIG_VIDEO_STATUSBAR}*CONFIG_VIDEO_FASTBLIT*{VIDEO_ITEM_FB-VIDEO_ITEM_NESCPU}} ; next: STATUS BAR, FAST BLIT or none
             dw   3,4
             dw   VIDEO_NESCPU_STR
             dw   config_video_nescpu

VIDEO_ITEM_SB dw  CHKBOX
             dw   VIDEO_ITEM_NESCPU     ; previous control
             dw   VIDEO_ITEM_SB+{CONFIG_VIDEO_FASTBLIT*{VIDEO_ITEM_FB-VIDEO_ITEM_SB}} ; next: FAST BLIT or none
             dw   3,6
             dw   VIDEO_STATUS_BAR_STR
             dw   config_video_statusbar

VIDEO_ITEM_FB dw  CHKBOX
             dw   VIDEO_ITEM_NESCPU+{CONFIG_VIDEO_STATUSBAR*{VIDEO_ITEM_SB-VIDEO_ITEM_NESCPU}} ; previous: STATUS BAR or SHOW NES CPU
             dw   0                     ; next control
             dw   3,6+{2*CONFIG_VIDEO_STATUSBAR}
             dw   VIDEO_FASTMODE_STR
             dw   config_video_fastmode
             FIN

INPUT_CONFIG dw   INPUT_TITLE_STR
             DO   CONFIG_VIDEO_MENU
             dw   VIDEO_CONFIG          ; previous menu item
             ELSE
             dw   AUDIO_CONFIG
             FIN
             dw   DRIVERS_CONFIG        ; next menu item

             dw   1
             DO   CONFIG_INPUT_2P
             dw   TAB_ITEM_1
             ELSE
             dw   INPUT_ITEM_1
             FIN

; Vertical layout of the input controls.  The P1/P2 tabs push everything down.
             DO   CONFIG_INPUT_2P
INPUT_TYPE_Y   equ 5
INPUT_LIST_Y   equ 10+JOYSTICK_SUPPORT          ; (the JOYSTICK option is a third line)
INPUT_BUTTON_Y equ 15+JOYSTICK_SUPPORT
             ELSE
INPUT_TYPE_Y   equ 2
INPUT_LIST_Y   equ 8
INPUT_BUTTON_Y equ 13
             FIN
INPUT_KEY_COUNT equ 3                    ; The grid and the A / B buttons

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
             dw   2+JOYSTICK_SUPPORT

             dw   0
             dw   INPUT_TYPE_OPT_1
             dw   KEYBOARD_LIST

             DO   JOYSTICK_SUPPORT
             dw   INPUT_JOYSTICK
             dw   INPUT_TYPE_OPT_2
             dw   JOYSTICK_LIST
             FIN

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
              dw  INPUT_ITEM_6
              dw  INPUT_ITEM_7

; The direction keys: a 3 x 3 grid around a hole (KEYGRID, rom/rom_config.s)
INPUT_ITEM_2 dw   KEYGRID
             dw   INPUT_ITEM_1
             dw   INPUT_ITEM_6
             dw   3,INPUT_LIST_Y
             dw   INPUT_KEYS_STR
             dw   config_block_p1

INPUT_ITEM_6 dw   BTNMAP
             dw   INPUT_ITEM_2
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

; Player 2 input controls
             DO   CONFIG_INPUT_2P
INPUT_ITEM_P2 dw  RADIO
             dw   TAB_ITEM_1
             dw   0                    ; No NEXT defined, use the selected item
             dw   3,INPUT_TYPE_Y
             dw   INPUT_TYPE_STR
             dw   config_input_p2_type
             dw   2+JOYSTICK_SUPPORT

             dw   0
             dw   INPUT_TYPE_OPT_1
             dw   KEYBOARD_LIST_2

             DO   JOYSTICK_SUPPORT
             dw   INPUT_JOYSTICK
             dw   INPUT_TYPE_OPT_2
             dw   JOYSTICK_LIST_2
             FIN

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
              dw  INPUT_ITEM_12
              dw  INPUT_ITEM_13

INPUT_ITEM_8 dw   KEYGRID
             dw   INPUT_ITEM_P2
             dw   INPUT_ITEM_12
             dw   3,INPUT_LIST_Y
             dw   INPUT_KEYS_STR
             dw   config_block_p2

INPUT_ITEM_12 dw  BTNMAP
             dw   INPUT_ITEM_8
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

; Drivers: the keyboard driver used by the KEYBOARD input type.  The key mappings stay on the INPUT menu
; and apply to either driver.
DRIVERS_CONFIG dw DRIVERS_TITLE_STR
             dw   INPUT_CONFIG          ; previous menu item
             DO   CONFIG_GAME_MENU
             dw   GAME_CONFIG           ; next menu item
             ELSE
             dw   CREDITS_CONFIG
             FIN

             dw   1
             dw   DRIVERS_ITEM_1

DRIVERS_ITEM_1 dw RADIO
             dw   0                     ; previous control
             dw   0                     ; next control
             dw   3,2
             dw   DRIVERS_KBD_STR
             dw   config_kbd_driver
             dw   1+KBD_J13+KBD_ADB     ; the drivers that are built (core/Defs.s)

             dw   KBD_DRIVER_BASIC
             dw   DRIVERS_KBD_BASIC
             dw   DRIVERS_ITEM_LATCH    ; shown while BASIC is selected

             DO   KBD_J13
             dw   KBD_DRIVER_J13
             dw   DRIVERS_KBD_J13
             dw   0
             FIN

             DO   KBD_ADB
             dw   KBD_DRIVER_ADB
             dw   DRIVERS_KBD_ADB
             dw   0
             FIN

; The BASIC driver's option: hold the directions (on: holding left and pressing up gives up + left, until
; every key is up; off: only the key that is down, the diagonal keys for diagonals)
DRIVERS_ITEM_LATCH dw CHKBOX
             dw   DRIVERS_ITEM_1        ; previous control
             dw   0                     ; next control
             dw   3,6+KBD_J13+KBD_ADB   ; below the driver list
             dw   DRIVERS_LATCH_STR
             dw   config_kbd_latch


; The joystick (INPUT_JOYSTICK)
;
; Its settings: the calibrated center of each axis (config_joy_cx / cy) and the sensitivity (the dead zone
; around the center).  JoyConfigureL (core/blitter/JoyProbes.s) turns them into thresholds.  The
; configuration screen measures the timers itself, by busy reads (JoyMeasureL): spinning is fine there.
             DO   JOYSTICK_SUPPORT

JOYSTICK_LIST dw  CTRL_LIST
              dw  3
              dw  JOY_ITEM_CAL
              dw  JOY_ITEM_SENS
              dw  JOY_ITEM_TEST

JOY_ITEM_CAL dw ACTION
             dw   INPUT_ITEM_1
             dw   JOY_ITEM_SENS
             dw   3,INPUT_LIST_Y
             dw   JOY_CAL_STR
             dw   JoyCalibrate          ; The action
             dw   JoyDrawCenter         ; Drawn after the title

JOY_ITEM_SENS dw NUMBER_SELECT
             dw   JOY_ITEM_CAL
             dw   JOY_ITEM_TEST
             dw   3,INPUT_LIST_Y+1
             dw   JOY_SENS_STR
             dw   config_joy_sens
             dw   1                     ; minimum value
             dw   7                     ; maximum value

JOY_ITEM_TEST dw ACTION
             dw   JOY_ITEM_SENS
             dw   0
             dw   3,INPUT_LIST_Y+2
             dw   JOY_TEST_STR
             dw   JoyTest
             dw   0

             DO   CONFIG_INPUT_2P
JOYSTICK_LIST_2 dw CTRL_LIST
              dw  3
              dw  JOY_ITEM_CAL_2
              dw  JOY_ITEM_SENS_2
              dw  JOY_ITEM_TEST_2

JOY_ITEM_CAL_2 dw ACTION
             dw   INPUT_ITEM_P2
             dw   JOY_ITEM_SENS_2
             dw   3,INPUT_LIST_Y
             dw   JOY_CAL_STR
             dw   JoyCalibrate          ; The action
             dw   JoyDrawCenter         ; Drawn after the title

JOY_ITEM_SENS_2 dw NUMBER_SELECT
             dw   JOY_ITEM_CAL_2
             dw   JOY_ITEM_TEST_2
             dw   3,INPUT_LIST_Y+1
             dw   JOY_SENS_STR
             dw   config_joy_sens
             dw   1                     ; minimum value
             dw   7                     ; maximum value

JOY_ITEM_TEST_2 dw ACTION
             dw   JOY_ITEM_SENS_2
             dw   0
             dw   3,INPUT_LIST_Y+2
             dw   JOY_TEST_STR
             dw   JoyTest
             dw   0
             FIN

JOY_CAL_STR     str 'CALIBRATE'
JOY_SENS_STR    str 'SENSITIVITY'
JOY_TEST_STR    str 'TEST'
JOY_CENTER_STR  str 'CENTER THE STICK'
JOY_PRESS_STR   str 'THEN PRESS A KEY'
JOY_NONE_STR    str 'NO JOYSTICK'
JOY_STOP_STR    str 'ANY KEY STOPS'
JOY_X_STR       str 'X'
JOY_Y_STR       str 'Y'
JOY_LEFT_STR    str 'LEFT'
JOY_RIGHT_STR   str 'RIGHT'
JOY_UP_STR      str 'UP'
JOY_DOWN_STR    str 'DOWN'
JOY_MID_STR     str 'CENTER'

; Two status rows under the joystick's controls (the panel is redrawn after an action, which clears them)
JOY_STATUS_0 equ  CONFIG_PANEL_ORIGIN+{{INPUT_LIST_Y+5}*ROW_STEP}+{3*COL_STEP}
JOY_STATUS_1 equ  JOY_STATUS_0+ROW_STEP

joyCalN     dw    0
joyCalSumX  dw    0
joyCalSumY  dw    0
joyTmpW     dw    0
joyTestPad  dw    0
joyTestLast dw    0
joyTestLastPad dw 0

; CALIBRATE: measure the center of each axis (16 busy reads, averaged) and apply it
            mx    %00
JoyCalibrate
            jsr   JoyClearStatus
            ldx   #JOY_CENTER_STR
            ldy   #JOY_STATUS_0
            lda   #TEXT_NORMAL
            jsr   ConfigDrawString
            ldx   #JOY_PRESS_STR
            ldy   #JOY_STATUS_1
            lda   #TEXT_NORMAL
            jsr   ConfigDrawString
            jsr   _WaitForKeyUp

            stz   joyCalSumX
            stz   joyCalSumY
            lda   #16
            sta   joyCalN
:loop       jsl   JoyMeasureL
            bcs   :none
            txa
            clc
            adc   joyCalSumX
            sta   joyCalSumX
            tya
            clc
            adc   joyCalSumY
            sta   joyCalSumY
            dec   joyCalN
            bne   :loop

            lda   joyCalSumX                ; Steps x 16.  A timer is seen done up to a step after it
            sec                             ; is (JoyMeasureL), half a step later on average
            sbc   #8
            sta   config_joy_cx
            lda   joyCalSumY
            sec
            sbc   #8
            sta   config_joy_cy
            jsl   JoyConfigureL
            rts

:none       jsr   JoyClearStatus
            ldx   #JOY_NONE_STR
            ldy   #JOY_STATUS_0
            lda   #TEXT_NORMAL
            jsr   ConfigDrawString
            ldx   #JOY_PRESS_STR
            ldy   #JOY_STATUS_1
            lda   #TEXT_NORMAL
            jsr   ConfigDrawString
            jmp   _WaitForKeyUp

; Drawn after CALIBRATE's title (Y = its address): each axis' center, in steps (hex)
JoyDrawCenter
            tya
            clc
            adc   #11*COL_STEP
            pha
            lda   config_joy_cx
            jsr   :steps
            tax
            ply
            phy
            lda   #TEXT_NORMAL
            jsr   ConfigDrawByte
            pla
            clc
            adc   #3*COL_STEP
            tay
            lda   config_joy_cy
            jsr   :steps
            tax
            lda   #TEXT_NORMAL
            jmp   ConfigDrawByte

:steps      bne   *+5
            lda   #JOY_DEFAULT_CENTER*16
            clc
            adc   #8
            lsr
            lsr
            lsr
            lsr
            rts

; TEST: show each axis' timer (steps, hex) and direction, live, until a key is pressed.  Redrawn only
; when they change (a redraw blanks the fields first, which would flicker).
JoyTest
            jsl   JoyConfigureL             ; The current sensitivity
            jsr   JoyClearStatus
            lda   #$FFFF
            sta   joyTestLast               ; Draw the first reading
            sta   joyTestLastPad
:loop       jsl   JoyMeasureL
            phy
            phx
            jsl   JoyClassifyL
            sta   joyTestPad
            lda   1,s                       ; X and Y's times, in one word
            xba
            ora   3,s
            cmp   joyTestLast
            bne   :draw
            lda   joyTestPad
            cmp   joyTestLastPad
            bne   :draw
            plx
            ply
            bra   :next
:draw       lda   1,s
            xba
            ora   3,s
            sta   joyTestLast
            lda   joyTestPad
            sta   joyTestLastPad

            ldx   #JOY_X_STR
            ldy   #JOY_STATUS_0
            lda   #TEXT_NORMAL
            jsr   ConfigDrawString
            plx
            ldy   #JOY_STATUS_0+{2*COL_STEP}
            lda   #TEXT_NORMAL
            jsr   ConfigDrawByte
            ldy   #JOY_STATUS_0+{5*COL_STEP}
            ldx   #JOY_MID_STR
            lda   joyTestPad
            bit   #PAD_LEFT
            beq   *+5
            ldx   #JOY_LEFT_STR
            bit   #PAD_RIGHT
            beq   *+5
            ldx   #JOY_RIGHT_STR
            jsr   JoyDrawField

            ldx   #JOY_Y_STR
            ldy   #JOY_STATUS_1
            lda   #TEXT_NORMAL
            jsr   ConfigDrawString
            plx
            ldy   #JOY_STATUS_1+{2*COL_STEP}
            lda   #TEXT_NORMAL
            jsr   ConfigDrawByte
            ldy   #JOY_STATUS_1+{5*COL_STEP}
            ldx   #JOY_MID_STR
            lda   joyTestPad
            bit   #PAD_UP
            beq   *+5
            ldx   #JOY_UP_STR
            bit   #PAD_DOWN
            beq   *+5
            ldx   #JOY_DOWN_STR
            jsr   JoyDrawField

:next       jsr   _KbdReadRaw
            bit   #PAD_KEY_DOWN
            bne   *+5
            brl   :loop
            rts

; X = string, Y = address: draw the string, then blank the rest of a 6-character field (a tile overwrites
; whatever was under it, so nothing is blanked first: no flicker)
JoyDrawField
            phx
            phy
            lda   #TEXT_NORMAL
            jsr   ConfigDrawString
            ply
            plx
            lda:  0,x                       ; The string's length
            and   #$00FF
            sta   joyCalN
            asl
            asl                             ; x COL_STEP
            sty   joyTmpW
            clc
            adc   joyTmpW
            tay
:blank      lda   joyCalN
            cmp   #6
            bcs   :done
            phy
            lda   #TILE_SPACE
            ldx   #TEXT_NORMAL
            jsr   _blitTileNoMask
            pla
            clc
            adc   #COL_STEP
            tay
            inc   joyCalN
            bra   :blank
:done       rts

; Clear the two status rows (from their first column to the panel's border)
JOY_STATUS_WORDS equ {CONFIG_PANEL_INTERIOR_WIDTH-{2*COL_STEP}}/2
JoyClearStatus
            ldx   #JOY_STATUS_0
            jsr   :row
            ldx   #JOY_STATUS_1
:row        lda   #8                        ; Lines
            sta   joyCalN
:line       phx
            ldy   #JOY_STATUS_WORDS
            lda   #0
:word       stal  $010000,x                 ; (the shadow screen, and with it the display)
            stal  $E10000,x
            inx
            inx
            dey
            bne   :word
            pla
            clc
            adc   #160
            tax
            dec   joyCalN
            bne   :line
            rts

             FIN

; Credits.  The panel is cleared down to row 18, so the text must end there.
CREDITS_CONFIG dw CREDITS_TITLE_STR
             DO   CONFIG_GAME_MENU
             dw   GAME_CONFIG           ; previous menu item
             ELSE
             dw   DRIVERS_CONFIG
             FIN
             dw   0                     ; next menu item

             dw   1
             dw   CREDITS_ITEM_1

CREDITS_ITEM_1 dw TEXT
             dw   0                     ; previous control
             dw   0                     ; next control
             dw   1,2
             dw   CREDITS_HEADER_STR
             dw   0                     ; no value

             dw   12                    ; number of lines (0 = blank line)
             dw   CREDITS_LINE_1
             dw   CREDITS_LINE_2
             dw   CREDITS_LINE_3
             dw   CREDITS_LINE_4
             dw   CREDITS_LINE_5
             dw   CREDITS_LINE_6
             dw   CREDITS_LINE_7
             dw   0
             dw   CREDITS_LINE_8
             dw   CREDITS_LINE_9
             dw   0
             dw   CREDITS_LINE_10

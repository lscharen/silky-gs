; Control types
RADIO           equ 1     ; radio (mutually exclusive options)
CHKBOX          equ 2     ; checkbox (boolean)
KEYMAP          equ 3     ; keymap (reads input character; tab to enter/exit)
CTRL_LIST       equ 4     ; list of other controls (no UI)
NUMBER_SELECT   equ 5     ; select from a range of single-digit numbers
BTNMAP          equ 6     ; button mapping: the soft switch ($C061 / $C062) a button reads; space, then the button
TAB             equ 7     ; tab control
TEXT            equ 8     ; static lines of text (no value, no cursor)
ACTION          equ 9     ; runs a routine (the value word) on space; optional extra draw routine
KEYGRID         equ 10    ; a player's 8 direction keys in a 3 x 3 grid (value = the player's config block)

CHKBOX_YES      str 'YES'
CHKBOX_NO       str ' NO'
CHKBOX_ON       str ' ON'
CHKBOX_OFF      str 'OFF'

BTNMAP_C061     str 'BTN1'          ; $C061 (button 0: Command)
BTNMAP_C062     str 'BTN2'          ; $C062 (button 1: Option)

; Control offsets from their base address
MENU_TITLE      equ  0 
MENU_PREV       equ  2
MENU_NEXT       equ  4
MENU_CTRL_COUNT equ  6
MENU_CTRL_LIST  equ  8

CTRL_TYPE       equ  0
CTRL_PREV       equ  2
CTRL_NEXT       equ  4
CTRL_POS        equ  6
CTRL_POS_X      equ  6
CTRL_POS_Y      equ  8
CTRL_TITLE      equ  10
CTRL_VALUE_ADDR equ  12
CTRL_DATA       equ  14

; Control-specific offsets
CTRL_TAB_OPTION_COUNT    equ CTRL_DATA
CTRL_TAB_OPTION_VALUE    equ CTRL_DATA+2
CTRL_TAB_OPTION_LABEL    equ CTRL_DATA+4
CTRL_TAB_OPTION_WIDTH    equ CTRL_DATA+6
CTRL_TAB_OPTION_NEXT     equ CTRL_DATA+8
CTRL_TAB_OPTION_SIZEOF   equ 8

CTRL_RADIO_OPTION_COUNT  equ CTRL_DATA
CTRL_RADIO_OPTION_VALUE  equ CTRL_DATA+2
CTRL_RADIO_OPTION_LABEL  equ CTRL_DATA+4
CTRL_RADIO_OPTION_NEXT   equ CTRL_DATA+6
CTRL_RADIO_OPTION_SIZEOF equ 6

CTRL_LIST_COUNT  equ CTRL_PREV

CTRL_NUMBER_MIN  equ CTRL_DATA
CTRL_NUMBER_MAX  equ CTRL_DATA+2

CTRL_TEXT_LINE_COUNT equ CTRL_DATA
CTRL_ACTION_DRAW     equ CTRL_DATA       ; drawn after the title (X = control, Y = title address), 0 = none
CTRL_TEXT_LINES      equ CTRL_DATA+2   ; string address per line (0 = blank line)

; Units to move text around
COL_STEP    equ 4
ROW_STEP    equ {8*160}

; NES Playfield origin
PLAYFIELD_ORIGIN equ {$2000+x_offset}
PLAYFIELD_WIDTH  equ {32*COL_STEP}
PLAYFIELD_HEIGHT equ 200

; Menu panel area
MENU_PANEL_ORIGIN equ PLAYFIELD_ORIGIN
MENU_PANEL_WIDTH  equ {11*COL_STEP}

; Config / Control panel area
CONFIG_PANEL_ORIGIN equ MENU_PANEL_ORIGIN+MENU_PANEL_WIDTH
CONFIG_PANEL_WIDTH equ {PLAYFIELD_WIDTH-MENU_PANEL_WIDTH}
CONFIG_PANEL_INTERIOR_WIDTH equ {CONFIG_PANEL_WIDTH-{2*COL_STEP}}
CONFIG_PANEL_HEIGHT equ 144

; Palette select for normal / selected / yes / no test
TEXT_NORMAL equ CONFIG_PALETTE*2
TEXT_SELECTED equ 2
TEXT_HIGHLIGHTED equ 4
TEXT_YES equ 2
TEXT_NO equ 0

CONFIG_PALETTE       equ 0
TILE_TOP_LEFT        equ rom_cfg_chr_top_left
TILE_TOP_RIGHT       equ rom_cfg_chr_top_right
TILE_BOTTOM_LEFT     equ rom_cfg_chr_bot_left
TILE_BOTTOM_RIGHT    equ rom_cfg_chr_bot_right
TILE_HORIZONTAL      equ rom_cfg_chr_horz
TILE_HORIZONTAL_TOP  equ rom_cfg_chr_horz_top
TILE_HORIZONTAL_BOTTOM  equ rom_cfg_chr_horz_bot
TILE_VERTICAL_LEFT   equ rom_cfg_chr_vert_left
TILE_VERTICAL_RIGHT  equ rom_cfg_chr_vert_right
TILE_ZERO            equ rom_cfg_chr_0     ; must be followed by digits 1 - 9
TILE_A               equ rom_cfg_chr_a     ; must be followed by B - Z
TILE_SPACE           equ rom_cfg_chr_space
TILE_CURSOR          equ rom_cfg_chr_cursor

_ConfigSaveBuffer ds 256+32

SAFE_JSR    mac
            phx
            phy
            jsr ]1
            ply
            plx
            <<<

TO_DIGIT_ADDR mac
            asl
            asl
            asl
            asl
            asl
            clc
            adc  #rom_cfg_chr_0
            <<<

TO_ALPHA_ADDR mac
            asl
            asl
            asl
            asl
            asl
            clc
            adc  #rom_cfg_chr_a
            <<<

; Preserve the SCBs and the first palette.
_ConfigEntry
            ldx  #{256+32}-2
:loop
            ldal $E19D00,x
            sta  _ConfigSaveBuffer,x
            dex
            dex
            bpl  :loop 
            rts

_ConfigExit
            ldx  #{256+32}-2
:loop
            lda  _ConfigSaveBuffer,x
            stal $E19D00,x
            dex
            dex
            bpl  :loop

; Flush the input before the game runs again.  The key that closed the screen (Return, the same key
; as the Start button) is still held, and a held key keeps reading as pressed (_KbdPoll), so
; wait for it to be released, then clear the strobe and every input value the game could see.

            jsr  _KbdWaitAllUp            ; (rom/rom_kbd_basic.s)
            stz  LastKey
            stz  LastRead
            stz  InputPlayer1
            stz  InputPlayer2
            lda  #0
            stal KeyEvent
            stal native_joy               ; Both controller bytes
            rts

; Palette for the configuration screen (4 palettes of 4 colors, defined by NES colors)
ConfScrnPal dw   $0F, $00, $00, $10, $0F, $00, $00, $20, $00, $00, $00, $20, $0F, $00, $00, $00

; Creates a UI for the runtime configuration
ShowConfig

            jsr  _ConfigEntry

; Set the palette for the config screen

            lda  #0
            jsr  _SetSCBs

            lda  #0
            jsr  _ClearToColor

            lda  #0
            ldx  #ConfScrnPal
            jsr  NES_SetPalette

; Set the top menu item active by default

            lda CONFIG_MENU+2
            sta config_active_menu       ; Intialize the active components
            lda AUDIO_CONFIG+MENU_CTRL_LIST
            sta config_active_ctrl

            lda #1
            sta config_focus             ; focus must always be non-zero

            jsr _DrawConfigMenu
            jsr _DrawControlBorder

:loop
            jsr _UpdateMenuCursor
            jsr _DrawActiveMenuControls
            jsr _UpdateControlCursor

; Wait for a key to be released before committing it
:keyloop
            jsr  _WaitForKeyUp

            cmp  #UP_ARROW
            beq  :decrement
            cmp  #DOWN_ARROW
            beq  :increment
            cmp  #RIGHT_ARROW
            beq  :move_right
            cmp  #LEFT_ARROW
            beq  :move_left
            cmp  #' '
            beq  :toggle
            cmp  #'q'
            beq  :abort
            cmp  #13
            bne  :keyloop

            jsr  _ConfigExit
            clc
            rts
:abort
            jsr  _ConfigExit
            sec
            rts
:toggle
            jsr  _ToggleActiveControl
            brl  :loop

; When the uses the arrow keys, we set the focus based on
; the user's current location.  Menu focus in the low byte
; and control focus is the high byte
:move_right
            lda   #$0100
            sta   config_focus
            brl   :loop

:move_left
            lda   #$0001
            sta   config_focus
            brl   :loop

:increment
            lda   config_focus
            bit   #$00FF           ; Is focus on the menu?
            beq   :inc_chk_ctrl_focus

            jsr   :menu_down
            brl   :loop

:inc_chk_ctrl_focus
            bit   #$FF00
            beq   :focus_done

            jsr   :ctrl_down
            brl   :loop

:decrement
            lda   config_focus
            bit   #$00FF
            beq   :dec_chk_ctrl_focus

            jsr   :menu_up
            brl   :loop

:dec_chk_ctrl_focus
            bit   #$FF00
            beq   :focus_done

            jsr   :ctrl_up
            brl   :loop

:focus_done
            brl   :loop

:menu_up
            ldx   config_active_menu
            lda:  MENU_PREV,x
            beq   :no_action
            sta   config_active_menu
            tax
            jmp   :set_first_control_active

:ctrl_up
            ldx   config_active_ctrl
            beq   :no_action
            lda:  CTRL_PREV,x
            beq   :no_action
            sta   config_active_ctrl
            rts

:menu_down
            ldx   config_active_menu
            lda:  MENU_NEXT,x
            beq   :no_action
            sta   config_active_menu
            tax
            jmp   :set_first_control_active

:ctrl_down
            ldx   config_active_ctrl
            beq   :no_action
            lda:  CTRL_NEXT,x
            beq   :chk_radio
            sta   config_active_ctrl
            rts

; A bit of complexity for handling more sophisticated controls
:chk_radio  lda:  CTRL_TYPE,x
            cmp   #RADIO
            bne   :not_radio
            jsr   _SelectedRadioItem
            beq   :not_radio
            tax
            lda:  CTRL_RADIO_OPTION_NEXT,x
:tab_and_radio
            beq   :not_radio
            tax
            lda:  CTRL_TYPE,x
            cmp   #CTRL_LIST
            bne   :not_list
            lda:  CTRL_LIST_COUNT+2,x
            tax
:not_list   stx   config_active_ctrl
:not_tab
:no_action  rts

:not_radio
            cmp   #TAB
            bne   :not_tab
            jsr   _SelectedTabItem
            beq   :not_tab
            tax
            lda:  CTRL_TAB_OPTION_NEXT,x
            bra   :tab_and_radio

:set_first_control_active
            lda:  MENU_CTRL_COUNT,x
            beq   :no_items
            lda:  MENU_CTRL_LIST,x
            sta   config_active_ctrl
:no_items
            rts

; ConfirmQuit
;
; The quit confirmation (Q in NES_EvtLoop): a box, in the configuration screen's colors, asking the user
; to confirm.  Y quits; N or Escape goes back to the game.  Returns carry set to quit.
QUIT_BOX_ORIGIN equ PLAYFIELD_ORIGIN+{8*COL_STEP}+{9*ROW_STEP}   ; 16 x 7 tiles, centered

QUIT_TITLE_STR  str 'QUIT GAME'
QUIT_KEYS_STR   str 'Y YES   N NO'

            mx   %00
ConfirmQuit
            jsr  _ConfigEntry
            lda  #0
            jsr  _SetSCBs
            lda  #0
            jsr  _ClearToColor
            lda  #0
            ldx  #ConfScrnPal
            jsr  NES_SetPalette

            ldy  #QUIT_BOX_ORIGIN
            ldx  #14
            jsr  ConfigDrawTopBorder
            ldy  #QUIT_BOX_ORIGIN+ROW_STEP
            ldx  #5
            lda  #COL_STEP*15
            jsr  ConfigDrawSideBorder
            ldy  #QUIT_BOX_ORIGIN+{6*ROW_STEP}
            ldx  #14
            jsr  ConfigDrawBottomBorder

            ldx  #QUIT_TITLE_STR
            ldy  #QUIT_BOX_ORIGIN+{2*ROW_STEP}+{4*COL_STEP}
            lda  #TEXT_NORMAL
            jsr  ConfigDrawString
            ldx  #QUIT_KEYS_STR
            ldy  #QUIT_BOX_ORIGIN+{4*ROW_STEP}+{2*COL_STEP}
            lda  #TEXT_NORMAL
            jsr  ConfigDrawString

:key        jsr  _WaitForKeyUp                     ; (the Q's auto-repeat is ignored)
            cmp  #$1B                              ; Escape
            beq  :cancel
            ora  #$0020                            ; Either case
            cmp  #'y'
            beq  :quit
            cmp  #'n'
            bne  :key
:cancel     jsr  _ConfigExit
            clc
            rts
:quit       jsr  _ConfigExit
            sec
            rts

; config_keypress    ds 2    ; use to wait until a keyup event
config_active_menu ds 2    ; currently selected menu item
config_active_ctrl ds 2    ; currently selected control
config_focus       ds 2

; Render the border for the control panel
_DrawControlBorder
:count      equ  tmp14
:addr       equ  tmp15

            ldy  #CONFIG_PANEL_ORIGIN
            ldx  #19
            jsr  ConfigDrawTopBorder

            ldy  #CONFIG_PANEL_ORIGIN+ROW_STEP
            ldx  #20
            lda  #COL_STEP*20
            jsr  ConfigDrawSideBorder

            ldy  #CONFIG_PANEL_ORIGIN+{21*ROW_STEP}
            ldx  #19
            jsr  ConfigDrawBottomBorder

            rts

; Render the configuration sidebar: one box, the same height as the control panel, with the menu
; titles on every other row starting at MENU_FIRST_ROW (room for 10 menus)
MENU_FIRST_ROW equ 2
MENU_ROW_STEP  equ 2

_DrawConfigMenu
:count      equ  tmp14
:addr       equ  tmp15

            ldy  #MENU_PANEL_ORIGIN
            ldx  #9
            jsr  ConfigDrawTopBorder

            ldy  #MENU_PANEL_ORIGIN+ROW_STEP
            ldx  #20
            lda  #COL_STEP*10
            jsr  ConfigDrawSideBorder

            ldy  #MENU_PANEL_ORIGIN+{21*ROW_STEP}
            ldx  #9
            jsr  ConfigDrawBottomBorder

            lda  CONFIG_MENU
            asl
            sta  :count

            ldx  #0

            lda  #MENU_PANEL_ORIGIN+{MENU_FIRST_ROW*ROW_STEP}+{3*COL_STEP} ; Room for 7 characters before the right border
            sta  :addr
:dcm_loop
            phx

            lda: CONFIG_MENU+2,x               ; Get the address of the config block for this menu item
            tax

            ldy  :addr
            lda: MENU_TITLE,x                  ; Load the title pointer
            tax
            lda  #CONFIG_PALETTE*2
            jsr  ConfigDrawString

            lda  :addr
            clc
            adc  #MENU_ROW_STEP*ROW_STEP
            sta  :addr

            plx
            inx
            inx
            cpx  :count
            bcc  :dcm_loop
            rts

; Clear the interior of the control panel area
;
; +----------+
; |xxxxxxxxxx|
; |xxxxxxxxxx|
; |..........|
_ClearPanel
:line       equ  tmp15

            lda  #CONFIG_PANEL_HEIGHT
            sta  :line

            ldx  #CONFIG_PANEL_ORIGIN+ROW_STEP+COL_STEP
:oloop
            ldy  #CONFIG_PANEL_INTERIOR_WIDTH
            lda  #0
:iloop
            stal $E10000,x
            inx
            inx
            dey
            dey
            bne  :iloop

            txa
            clc
            adc  #160-CONFIG_PANEL_INTERIOR_WIDTH
            tax

            dec  :line
            bne  :oloop
            rts

_OffsetToAddr
            lda: CTRL_POS_Y,x      ; Load the y-block
            and  #$00FF
            xba           ; addr = (y * 8) * 160 = y * 8 * (32 + 128)
            pha           ;      = y * 256 + y * 1024
            asl
            asl
            clc
            adc  1,s
            sta  1,s

            lda: CTRL_POS_X,x      ; Load the x-block
            asl
            asl
            clc
            adc  1,s
            clc
            adc  #CONFIG_PANEL_ORIGIN
            sta  1,s
            ply
            rts

; Y = screen addr
; X = control addr
;
; Draw the list of other controls
_DrawControlList
            ldy: CTRL_LIST_COUNT,x
            beq  :done

            dey                        ; Start counting from the end
:loop       phy
            phx
            lda: CTRL_LIST_COUNT+2,x
            tax
            jsr  _DrawControl
            pla
            clc
            adc  #2                    ; Each entry is a 2-byte address
            tax
            ply
            dey
            bpl  :loop
:done
            rts

; Y = screen addr
; X = control addr
;
; +----------------
; + XX <title>  
;
; Where XX is the character hex code
_DrawBtnmap
            lda  #0

_DrawBtnmap0
:addr       equ  tmp15
:highlight  equ  tmp14

; Save the palette select

            sta  :highlight

; First two words are the offset coordinates of the control

            jsr  _OffsetToAddr
            sta  :addr

; Move label to right for yes/no label

            clc
            adc  #COL_STEP*5
            tay

; Move to the label string

            phx
            lda: CTRL_TITLE,x
            tax
            lda  #TEXT_NORMAL
            jsr  ConfigDrawString
            plx

            ldy: CTRL_VALUE_ADDR,x      ; load the variable address
            lda: 0,y                    ; load the variable value: BUTTON_SWITCH_C061 / C062

            ldx  #BTNMAP_C061
            cmp  #BUTTON_SWITCH_C062
            bne  *+5
            ldx  #BTNMAP_C062
            ldy  :addr
            lda  :highlight
            jmp  ConfigDrawString

; Y = screen addr
; X = control addr
;
; +----------------
; + XX <title>  
;
; Where XX is the character hex code
_DrawKeymap
            lda  #0

_DrawKeymap0
:addr       equ  tmp15
:highlight  equ  tmp14

; Save the palette select

            sta  :highlight

; First two words are the offset coordinates of the control

            jsr  _OffsetToAddr
            sta  :addr

; Move label to right for yes/no label

            clc
            adc  #COL_STEP*3
            tay

; Move to the label string

            phx
            lda: CTRL_TITLE,x
            tax
            lda  #TEXT_NORMAL
            jsr  ConfigDrawString
            plx

            ldy: CTRL_VALUE_ADDR,x      ; load the variable address
            ldx: 0,y                    ; load the variable value

            ldy  :addr
            lda  :highlight
            jmp  ConfigDrawByte

;   <title> UL  U UR
;            L     R          (the key codes in hex; 00 = none)
;           DL  D DR
;
; X = control addr.  _DrawKeygrid0: A = the cell to highlight (0 - 7, KeygridVal order), else $FFFF.
_DrawKeygrid
            lda  #$FFFF

_DrawKeygrid0
:addr       equ  tmp15
:highlight  equ  tmp14
:cell       equ  tmp13
:ctrl       equ  tmp12

            sta  :highlight
            stx  :ctrl
            jsr  _OffsetToAddr            ; Y = the title's screen address
            sta  :addr

            lda: CTRL_TITLE,x
            tax
            lda  #TEXT_NORMAL
            jsr  ConfigDrawString

            lda  #7
            sta  :cell
:loop       lda  :cell
            asl
            tay
            lda  KeygridPos,y             ; The cell's screen address
            clc
            adc  :addr
            pha
            ldx  :ctrl
            lda: CTRL_VALUE_ADDR,x        ; The key, in the player's block
            clc
            adc  KeygridVal,y
            tax
            lda: 0,x
            tax
            lda  #TEXT_NORMAL
            ldy  :cell
            cpy  :highlight
            bne  *+5
            lda  #TEXT_HIGHLIGHTED
            ply
            jsr  ConfigDrawByte
            dec  :cell
            bpl  :loop
            rts

; The cells, in edit order: screen offsets from the title, and the keys' offsets in a player's block
KEYGRID_X   equ  5*COL_STEP
KeygridPos  dw   KEYGRID_X,KEYGRID_X+{3*COL_STEP},KEYGRID_X+{6*COL_STEP}
            dw   KEYGRID_X+ROW_STEP,KEYGRID_X+ROW_STEP+{6*COL_STEP}
            dw   KEYGRID_X+{2*ROW_STEP},KEYGRID_X+{2*ROW_STEP}+{3*COL_STEP},KEYGRID_X+{2*ROW_STEP}+{6*COL_STEP}
KeygridVal  dw   PLAYER_INPUT_KEY_UL,PLAYER_INPUT_KEY_UP,PLAYER_INPUT_KEY_UR
            dw   PLAYER_INPUT_KEY_LEFT,PLAYER_INPUT_KEY_RIGHT
            dw   PLAYER_INPUT_KEY_DL,PLAYER_INPUT_KEY_DOWN,PLAYER_INPUT_KEY_DR

; X = control addr
;
; Edit the grid: each cell is highlighted in turn.  A key press sets the cell's key (Delete clears it),
; Space moves to the next cell (after the last, the editing ends), Return or Escape ends it.
_ToggleKeygrid
            stx  keygridCtrl
            stz  keygridCell
:draw       ldx  keygridCtrl
            lda  keygridCell
            jsr  _DrawKeygrid0
:key        jsr  _WaitForKeyUp
            cmp  #' '
            beq  :next
            cmp  #13
            beq  :done
            cmp  #27
            beq  :done
            cmp  #127                     ; Delete: no key
            bne  *+5
            lda  #0
            pha
            lda  keygridCell
            asl
            tay
            ldx  keygridCtrl
            lda: CTRL_VALUE_ADDR,x
            clc
            adc  KeygridVal,y
            tax
            pla
            sta: 0,x
            bra  :draw

:next       lda  keygridCell
            inc
            cmp  #8
            bcs  :done
            sta  keygridCell
            bra  :draw
:done       rts

keygridCtrl dw   0
keygridCell dw   0

; Y = screen addr
; X = control addr
;
; +------------
; |  d <title>
_DrawNumber
:addr       equ  tmp15
:count      equ  tmp14

; First two words are the offset coordinates of the control

            jsr  _OffsetToAddr
            sta  :addr

; Move label to right for yes/no label

            clc
            adc  #COL_STEP*5
            tay

; Move to the label string

            phx
            lda: CTRL_TITLE,x
            tax
            lda  #0
            jsr  ConfigDrawString
            plx

            ldy: CTRL_VALUE_ADDR,x      ; load the variable address
            lda: 0,y                    ; load the variable value
            TO_DIGIT_ADDR
            ldx  #TEXT_NORMAL
            ldy  :addr
            jsr  _blitTileNoMask

            rts

; Y = screen addr
; X = control addr
;
; +------------
; | YES <title>
; |  NO <title>
_DrawCheckbox
:addr       equ  tmp15
:count      equ  tmp14

; First two words are the offset coordinates of the control

            jsr  _OffsetToAddr
            sta  :addr

; Move label to right for yes/no label

            clc
            adc  #COL_STEP*5
            tay

; Move to the label string

            phx
            lda: CTRL_TITLE,x
            tax
            lda  #0
            jsr  ConfigDrawString
            plx

            ldy: CTRL_VALUE_ADDR,x      ; load the variable address
            lda: 0,y                    ; load the variable value
            beq  :draw_no
            ldx  #CHKBOX_YES
            ldy  :addr
            lda  #TEXT_YES
            jsr  ConfigDrawString
            bra  :draw_done

:draw_no
            ldx  #CHKBOX_NO
            ldy  :addr
            lda  #TEXT_NO
            jsr  ConfigDrawString

:draw_done
            rts

; X = control addr
_ToggleNumber
:addr       equ  tmp15
            lda: CTRL_VALUE_ADDR,x
            sta  :addr   ; address of the value

            lda  (:addr)
            cmp: CTRL_NUMBER_MAX,x
            bcc  :ok
            lda: CTRL_NUMBER_MIN,x
            bra  :ok2
:ok         inc
:ok2        sta  (:addr)

            rts

; Wait for button 0 or 1 ($C061 / $C062) to be pressed: returns C = 0 and A = its BUTTON_SWITCH_*, or
; C = 1 if Esc is pressed instead.  Both buttons must be up first, so one that is already held doesn't
; count.
            mx        %00
_WaitForButton
            sep       #$20
:up         lda       #BUTTON_SWITCH_C061 ; (_KbdReadButton: rom/rom_kbd_basic.s)
            jsr       _KbdReadButton
            bmi       :up
            lda       #BUTTON_SWITCH_C062
            jsr       _KbdReadButton
            bmi       :up
:down       lda       #BUTTON_SWITCH_C061
            jsr       _KbdReadButton
            bmi       :c061
            lda       #BUTTON_SWITCH_C062
            jsr       _KbdReadButton
            bmi       :c062
            rep       #$20
            jsr       _KbdReadRaw
            cmp       #PAD_KEY_DOWN+27    ; Esc
            beq       :cancel
            sep       #$20
            bra       :down

:c061       rep       #$20
            lda       #BUTTON_SWITCH_C061
            clc
            rts
:c062       rep       #$20
            lda       #BUTTON_SWITCH_C062
            clc
            rts
:cancel     sec
            rts

; Wait for a new key press
_WaitForKeyUp
:waitloop1
            jsr  _KbdReadRaw                            ; Read keyboard directly, and only for raw keystrokes
            bit  #PAD_KEY_DOWN
            beq  :waitloop1
            and  #$7F
            rts

; X = control addr
;
; Set mode (space): the control is highlighted until button 0 or 1 is pressed, and the button's soft switch
; becomes the mapping (Esc leaves it as it was)
_ToggleBtnmap
:addr       equ  tmp15

            phx
            lda  #TEXT_HIGHLIGHTED
            jsr  _DrawBtnmap0
            plx

            lda: CTRL_VALUE_ADDR,x
            sta  :addr   ; address of the value

            jsr  _WaitForButton
            bcs  :cancel
            sta  (:addr)
:cancel     rts

; X = control addr
;
; Wait for the user to press a key
_ToggleKeymap
:addr       equ  tmp15

            phx
            lda  #TEXT_HIGHLIGHTED
            jsr  _DrawKeymap0
            plx

            lda: CTRL_VALUE_ADDR,x
            sta  :addr   ; address of the value

            jsr  _WaitForKeyUp
            sta  (:addr)

            rts

; X = control addr
;
; Move the checkbox to the next value
_ToggleCheckbox
:addr       equ  tmp15

            lda: CTRL_VALUE_ADDR,x
            sta  :addr   ; address of the value

            lda  (:addr)
            eor  #$0001
            sta  (:addr)

            rts

; X = control addr
;
; Move the tab to the next value
_ToggleTab
:value      equ  tmp15     ; shared with _SelectedRadioItem
:count      equ  tmp14     ; shared with _SelectedRadioItem
:addr       equ  tmp13

            stx  :addr

            jsr  _SelectedTabItem
            bne  :found
            rts

:found
            tya
            inc
            cmp  :count
            bcc  *+5
            lda  #0

; multiply by sizeof record

            asl
            asl
            asl
            clc
            adc  :addr
            tax
            lda: CTRL_TAB_OPTION_VALUE,x
            sta  (:value)          ; Update the value

:done
            rts

; X = control addr
;
; Return A = address of selected tab. 0 is no match
;        Y = index of selected item
_SelectedTabItem
:value      equ  tmp15
:count      equ  tmp14

            lda: CTRL_VALUE_ADDR,x
            sta  :value

            lda: CTRL_TAB_OPTION_COUNT,x
            beq  :empty_list
            sta  :count
            ldy  #0

:loop
            lda:  CTRL_TAB_OPTION_VALUE,x
            cmp   (:value)
            beq   :found

            txa
            clc
            adc  #CTRL_TAB_OPTION_SIZEOF
            tax

            iny
            cpy  :count
            bcc  :loop

:empty_list
            lda   #0
            rts

:found
            txa
            rts

; X = control addr
;
; Return A = address of selected option. 0 is no match
;        Y = index of selected item
_SelectedRadioItem
:value      equ  tmp15
:count      equ  tmp14

            lda: CTRL_VALUE_ADDR,x
            sta  :value

            lda: CTRL_RADIO_OPTION_COUNT,x
            beq  :empty_list
            sta  :count
            ldy  #0

:loop
            lda:  CTRL_RADIO_OPTION_VALUE,x
            cmp   (:value)
            beq   :found

            txa
            clc
            adc  #CTRL_RADIO_OPTION_SIZEOF
            tax

            iny
            cpy  :count
            bcc  :loop

:empty_list
            lda   #0
            rts

:found
            txa
            rts

; X = control addr
;
; Move the radio to the next value
_ToggleRadio
:value      equ  tmp15     ; shared with _SelectedRadioItem
:count      equ  tmp14     ; shared with _SelectedRadioItem
:addr       equ  tmp13

            stx  :addr

            jsr  _SelectedRadioItem
            bne  :found
            rts

:found
            tya
            inc
            cmp  :count
            bcc  *+5
            lda  #0

            asl
            sta  :count
            asl                    ; multiply by 6 to get the option item
            clc
            adc  :count
            adc  :addr
            tax
            lda: CTRL_RADIO_OPTION_VALUE,x
            sta  (:value)          ; Update the value

:done
            rts

; Y = screen addr
; X = control addr
;
; +--------------------------
; | option 1 | option 2 | ...
_DrawTab
:addr       equ  tmp15
:count      equ  tmp14
:value      equ  tmp13
:palette    equ  tmp12
:next       equ  tmp11           ; next control to draw (must use tail-call, draw routines not recursive)

; First two words are the offset coordinates of the control

            jsr  _OffsetToAddr
            sty  :addr

; Clear the next control (conditional control shows when options are selected)

            stz  :next

; Move to the label string

            phx
            lda: CTRL_TITLE,x
            tax
            lda  #0
            jsr  ConfigDrawString
            plx

            lda  :addr
            clc
            adc  #{1*ROW_STEP}+0              ; Go to the next line to show the tab values
            sta  :addr

            lda: CTRL_VALUE_ADDR,x            ; Get a copy of the config value address
            sta  :value

            ldy: CTRL_TAB_OPTION_COUNT,x    ; Load the number of options
            beq  :done

:loop
            phx
            phy

            stz  :palette
            lda: CTRL_TAB_OPTION_VALUE,x    ; See if this options matches the current value
            cmp  (:value)
            bne  :no_match
            lda: CTRL_TAB_OPTION_NEXT,x     ; Mark the next control to show based on this selection
            sta  :next
            lda  #2
            sta  :palette
:no_match

            ldy  :addr
            lda: CTRL_TAB_OPTION_WIDTH,x    ; Make space
            asl
            asl
            clc
            adc  :addr
            sta  :addr
            lda: CTRL_TAB_OPTION_LABEL,x    ; Load the string address
            tax

            lda  :palette
            jsr  ConfigDrawString
            ply

            pla
            clc
            adc  #CTRL_TAB_OPTION_SIZEOF    ; number of bytes per radio option entry
            tax

            dey
            bne  :loop

:done
            ldx  :next                        ; Is there another control to draw?
            beq  *+5
            jmp  _DrawControl                 ; Tail call

            rts

; Y = screen addr
; X = control addr
;
; +------------
; |<title>
; |  [] option 1
; |  [] option 2
; |  ...
; |  [] option N
_DrawRadio
:addr       equ  tmp15
:count      equ  tmp14
:value      equ  tmp13
:palette    equ  tmp12
:next       equ  tmp11           ; next control to draw (must use tail-call, draw routines not recursive)

; First two words are the offset coordinates of the control

            jsr  _OffsetToAddr
            sty  :addr

; Clear the next control (conditional control shows when options are selected)

            stz  :next

; Move to the label string

            phx
            lda: CTRL_TITLE,x
            tax
            lda  #0
            jsr  ConfigDrawString
            plx

            lda  :addr
            clc
            adc  #{2*ROW_STEP}+4              ; Indent for the options
            sta  :addr

            lda: CTRL_VALUE_ADDR,x            ; Get a copy of the config value address
            sta  :value

            ldy: CTRL_RADIO_OPTION_COUNT,x    ; Load the number of options
            beq  :done

:loop
            phx
            phy

            stz  :palette
            lda: CTRL_RADIO_OPTION_VALUE,x    ; See if this options matches the current value
            cmp  (:value)
            bne  :no_match
            lda: CTRL_RADIO_OPTION_NEXT,x     ; Mark the next control to show based on this selection
            sta  :next
            lda  #2
            sta  :palette
:no_match

            lda  :addr
            tay
            clc
            adc  #ROW_STEP
            sta  :addr
            lda: CTRL_RADIO_OPTION_LABEL,x    ; Load the string address
            tax

            lda  :palette
            jsr  ConfigDrawString
            ply

            pla
            clc
            adc  #CTRL_RADIO_OPTION_SIZEOF    ; number of bytes per radio option entry
            tax

            dey
            bne  :loop

:done
            ldx  :next                        ; Is there another control to draw?
            beq  *+5
            jmp  _DrawControl                 ; Tail call

            rts

; Y = screen addr
; X = control addr
;
; +------------
; |<title>
; |
; |<line 1>
; |...
; |<line N>
_DrawText
:addr       equ  tmp15
:count      equ  tmp14

; First two words are the offset coordinates of the control

            jsr  _OffsetToAddr
            sty  :addr

            phx
            lda: CTRL_TITLE,x
            tax
            lda  #TEXT_NORMAL
            jsr  ConfigDrawString
            plx

            lda: CTRL_TEXT_LINE_COUNT,x
            beq  :done
            sta  :count

            lda  :addr
            clc
            adc  #2*ROW_STEP                  ; Leave a blank line under the title
:loop
            sta  :addr
            phx
            lda: CTRL_TEXT_LINES,x            ; Load the string address
            beq  :next                        ; Blank line (an empty string would draw 64K characters)
            tax
            ldy  :addr
            lda  #TEXT_NORMAL
            jsr  ConfigDrawString
:next
            plx
            inx                               ; Each entry is a 2-byte address
            inx

            lda  :addr
            clc
            adc  #ROW_STEP
            dec  :count
            bne  :loop
:done
            rts


; Iterate through the control list of the active control
; and draw them in the configuration panel
_DrawControl
            lda: CTRL_TYPE,x             ; Load the control type
            cmp  #RADIO
            bne  :not_radio
            jmp  _DrawRadio      ; _DrawXXX updates the x-register

:not_radio  cmp  #CHKBOX
            bne  :not_chkbox
            jmp  _DrawCheckbox

:not_chkbox cmp  #KEYMAP
            bne  :not_keymap
            jmp  _DrawKeymap

:not_keymap cmp  #CTRL_LIST
            bne  :not_list
            jmp  _DrawControlList

:not_list   cmp  #NUMBER_SELECT
            bne  :not_number
            jmp  _DrawNumber

:not_number cmp  #BTNMAP
            bne  :not_btnmap
            jmp  _DrawBtnmap

:not_btnmap cmp  #TAB
            bne  :not_tab
            jmp  _DrawTab

:not_tab    cmp  #TEXT
            bne  :not_text
            jmp  _DrawText
:not_text   cmp  #ACTION
            bne  :not_action
            jmp  _DrawAction
:not_action cmp  #KEYGRID
            bne  :not_keygrid
            jmp  _DrawKeygrid
:not_keygrid
            rts

; Y = screen addr
; X = control addr
;
; +------------
; |  <title> <the control's own drawing>
_DrawAction
            jsr  _OffsetToAddr
            phy
            phx
            lda: CTRL_TITLE,x
            tax
            lda  #TEXT_NORMAL
            jsr  ConfigDrawString
            plx
            ply
            lda: CTRL_ACTION_DRAW,x
            beq  :done
            db   $7C                         ; jmp (CTRL_ACTION_DRAW,x): Merlin32 can't assemble
            dw   CTRL_ACTION_DRAW            ; jmp (abs,x) for an operand below $100
:done       rts

; Switch the value of the active control
_ToggleActiveControl
            lda  config_focus
            bit  #$FF00
            bne  *+3
            rts

            ldx  config_active_ctrl
            bne  *+3                   ; Check that it is set
            rts

            lda: CTRL_TYPE,x             ; Load the control type
            cmp  #RADIO
            bne  :not_radio
            jmp  _ToggleRadio

:not_radio  cmp  #CHKBOX
            bne  :not_chkbox
            jmp  _ToggleCheckbox

:not_chkbox cmp  #KEYMAP
            bne  :not_keymap
            jmp  _ToggleKeymap

:not_keymap cmp  #NUMBER_SELECT
            bne  :not_number
            jmp  _ToggleNumber

:not_number cmp  #BTNMAP
            bne  :not_btnmap
            jmp  _ToggleBtnmap

:not_btnmap cmp  #TAB
            bne  :not_tab
            jmp  _ToggleTab

:not_tab    cmp  #ACTION
            bne  :not_action
            db   $7C                         ; jmp (CTRL_VALUE_ADDR,x): the action's routine (X = the
            dw   CTRL_VALUE_ADDR             ; control); see _DrawAction

:not_action cmp  #KEYGRID
            bne  :not_keygrid
            jmp  _ToggleKeygrid
:not_keygrid
            rts

; Loads the active menu address from config_active_menu
_DrawActiveMenuControls
            ldx  config_active_menu
            bne  *+3                   ; Check that it is set
            rts

; X = menu item address
_DrawMenuControls
            SAFE_JSR  _ClearPanel

            lda: MENU_CTRL_COUNT,x     ; Get the number of controls
            beq  :empty

            dec
            tay                        ; Start counting from the end

:loop       phy
            phx
            lda: MENU_CTRL_LIST,x
            tax
            jsr  _DrawControl
            pla
            clc
            adc  #2                    ; Each entry is a 2-byte address
            tax
            ply
            dey
            bpl  :loop
:empty      rts

; X = address
; Return A = index of the menu item in the list
_GetMenuItemIndex
            phy
            phx
            ldy  #0
:loop
            lda  CONFIG_MENU+2,y
            cmp  1,s
            beq  :found
            iny
            iny
            tya
            lsr
            cmp  CONFIG_MENU  ; number of items
            bcc  :loop
            ldy  #0           ; pick index zero by default

:found      tya
            lsr

            plx
            ply
            rts

; If the focus is on the config panel, draw the cursor next to the
; active control. This actuallydraws a cursor next to *all* the controls
; that have a cursor position, but draws an empty square if the control
; is not the active one.
_UpdateControlCursor
            ldx  config_active_menu
            bne  *+3                   ; Check that it is set
            rts

            lda: MENU_CTRL_COUNT,x
            beq  :no_controls
            tay

:loop
            lda: MENU_CTRL_LIST,x
            SAFE_JSR  _DrawControlCursor
            inx
            inx
            dey
            bne  :loop

:no_controls
            rts

; A = control address
_DrawControlCursor
:tile       equ  tmp15
:value      equ  tmp14

            pha
            ldx  #TILE_SPACE
            lda  config_focus
            bit  #$FF00
            beq  :no_focus
            lda  1,s
            cmp  config_active_ctrl
            bne  :no_focus
            ldx  #TILE_CURSOR
:no_focus
            stx  :tile
            lda  1,s
            tax

; If this is a list or text control, nothing to draw
            lda:  CTRL_TYPE,x
            cmp   #CTRL_LIST
            beq   :no_draw
            cmp   #TEXT
            beq   :no_draw

            jsr  _OffsetToAddr            ; Address of control label
            tya
            sec
            sbc  #2*COL_STEP
            tay                           ; Move to the left

            lda   :tile
            ldx   #CONFIG_PALETTE*2
            jsr   _blitTileNoMask

:no_draw
            plx                           ; restore the control address

; If this is a list control, call for each of its controls

            lda:  CTRL_TYPE,x
            cmp   #CTRL_LIST
            bne   :not_list

            ldy:  CTRL_LIST_COUNT,x
            beq   :empty_list
:loop_list
            lda:  CTRL_LIST_COUNT+2,x
            SAFE_JSR _DrawControlCursor
            inx
            inx
            dey
            bne   :loop_list
:empty_list
:not_found
:not_tab
            rts

; If it's a radio, check it's selected value and see if it points to conditional control
:not_list   cmp  #RADIO
            bne  :not_radio

            jsr  _SelectedRadioItem
            beq  :not_found

            lda: CTRL_RADIO_OPTION_NEXT,x
            beq  :not_radio
            jmp  _DrawControlCursor

:not_radio
            cmp  #TAB
            bne  :not_tab

            jsr  _SelectedTabItem
            beq  :not_found

            lda: CTRL_TAB_OPTION_NEXT,x
            beq  :not_tab
            jmp  _DrawControlCursor

_UpdateMenuCursor
            ldx  #0
:loop
            phx
            lda  CONFIG_MENU+2,x
            jsr  _DrawMenuCursor
            plx
            inx
            inx
            txa
            lsr
            cmp  CONFIG_MENU             ; number of menu items
            bcc  :loop
            rts

_DrawMenuCursor
:tile       equ  tmp15

            pha
            ldx  #TILE_SPACE
            lda  config_focus
            bit  #$00FF
            beq  :no_focus
            lda  1,s
            cmp  config_active_menu
            bne  :no_focus
            ldx  #TILE_CURSOR
:no_focus
            stx  :tile
            plx
            jsr  _GetMenuItemIndex

            asl
            asl
            asl
            asl                           ; x16 lines (MENU_ROW_STEP rows of 8 lines)

            asl                           ; x2 for indexing
            tax
            ldal  Mul160Tbl,x
            clc
            adc   #MENU_PANEL_ORIGIN+{MENU_FIRST_ROW*ROW_STEP}+{1*COL_STEP} ; A blank column before the title
            tay

            lda   :tile
            ldx   #CONFIG_PALETTE*2
            jsr   _blitTileNoMask

            rts

; Y = address
; X = number of rows
; A = width
ConfigDrawSideBorder
            sta  tmp10
:loop
            phx

            phy
            lda  #TILE_VERTICAL_LEFT
            ldx  #CONFIG_PALETTE*2
            jsr  _blitTileNoMask
            pla
            clc
            adc  tmp10
            tay
            phy
            lda  #TILE_VERTICAL_RIGHT
            ldx  #CONFIG_PALETTE*2
            jsr  _blitTileNoMask
            pla
            clc
            adc  #{8*160}
            sec
            sbc  tmp10
            tay

            plx
            dex
            bne  :loop
            rts

; Y = address
; X = number of center items
ConfigDrawTopBorder
            phx
            phy
            lda  #TILE_TOP_LEFT
            ldx  #CONFIG_PALETTE*2
            jsr  _blitTileNoMask
            ply
            plx

:hloop
            tya
            clc
            adc #4
            tay

            phy
            phx
            lda  #TILE_HORIZONTAL_TOP
            ldx  #CONFIG_PALETTE*2
            jsr  _blitTileNoMask
            plx
            ply
            dex
            bne  :hloop

            tya
            clc
            adc  #4
            tay
            lda  #TILE_TOP_RIGHT
            ldx  #CONFIG_PALETTE*2
            jsr  _blitTileNoMask
            rts

; Y = address
; X = number of center items
ConfigDrawBottomBorder
            phx
            phy
            lda  #TILE_BOTTOM_LEFT
            ldx  #CONFIG_PALETTE*2
            jsr  _blitTileNoMask
            ply
            plx

:hloop
            tya
            clc
            adc #4
            tay

            phy
            phx
            lda  #TILE_HORIZONTAL_BOTTOM
            ldx  #CONFIG_PALETTE*2
            jsr  _blitTileNoMask
            plx
            ply
            dex
            bne  :hloop

            tya
            clc
            adc  #4
            tay
            lda  #TILE_BOTTOM_RIGHT
            ldx  #CONFIG_PALETTE*2
            jsr  _blitTileNoMask
            rts

; X = hex value (only lower byte) 
; Y = address
; A = palette select (0, 2, 4, or 6)
ConfigDrawByte
            stx   tmp0
            sty   tmp1
            sta   tmp2


            lda   tmp0
            and   #$00F0
            lsr
            lsr
            lsr
            lsr
            cmp   #$000A
            bcc   :drawDigitHigh
            sbc   #$000A
            TO_ALPHA_ADDR
            bra   :drawHigh
:drawDigitHigh
            TO_DIGIT_ADDR

:drawHigh
            ldy  tmp1
            ldx  tmp2
            jsr  _blitTileNoMask

            lda   tmp1
            clc
            adc   #4
            sta   tmp1


            lda   tmp0
            and   #$000F
            cmp   #$000A
            bcc   :drawDigitLow
            sbc   #$000A
            TO_ALPHA_ADDR
            bra   :drawLow
:drawDigitLow
            TO_DIGIT_ADDR

:drawLow
            ldy  tmp1
            ldx  tmp2
            jmp  _blitTileNoMask

; X = string pointer
; Y = address
; A = palette select (0, 2, 4, or 6)
ConfigDrawString
            stx   tmp0
            sty   tmp1
            sta   tmp2
            lda   (tmp0)
            and   #$00FF
            tax
            ldy   #1
:loop
            phx
            phy

            lda   (tmp0),y
            and   #$007F
            cmp   #'A'
            bcc   :not_letter
            sbc   #'A'
            TO_ALPHA_ADDR
            bra   :draw
:not_letter
            cmp   #'0'
            bcc   :skip
            sbc   #'0'
            TO_DIGIT_ADDR
:draw
            ldy  tmp1
            ldx  tmp2
            jsr  _blitTileNoMask

:skip
            lda   tmp1
            clc
            adc   #4
            sta   tmp1

            ply
            plx

            iny
            dex
            bne   :loop
            rts

; Draw one tile of the built-in font (moved here from ppu.s: only the configuration screen uses it).
; The tile data is read through DBR (this bank); the rest is direct page and long stores.
        mx    %00
_blitTileNoMask
; A = tile address
; Y = screen address
; X = palette select 0,2,4,6
;
; Raw data draw -- expands the tile data from w_wxxy_yzz0 to 00ww_00xx_00yy_00zz and then adds an offset based on the
; palette select

        sta   sprTmp0
        sty   sprTmp1

        txa
        and   #$0006
        asl
        sta   sprTmp3
        asl
        asl
        asl
        asl
        ora   sprTmp3
        sta   sprTmp3
        xba
        ora   sprTmp3
        sta   sprTmp3

        ldy   sprTmp0
        ldx   sprTmp1
        lda   #8
        sta   sprTmp4

]line   equ   0
:loop
        lda:  {]line*4},y                            ; Load the tile data lookup value
        lsr
        and   #$0003
        sta   sprTmp2
        lda:  {]line*4},y
        asl
        and   #$0030
        tsb   sprTmp2
        lda:  {]line*4},y
        asl
        asl
        asl
        and   #$0300
        tsb   sprTmp2
        lda:  {]line*4},y
        asl
        asl
        asl
        asl
        asl
        and   #$3000
        ora   sprTmp2
        xba
        ora   sprTmp3
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        lda:  {]line*4}+2,y
        lsr
        and   #$0003
        sta   sprTmp2
        lda:  {]line*4}+2,y
        asl
        and   #$0030
        tsb   sprTmp2
        lda:  {]line*4}+2,y
        asl
        asl
        asl
        and   #$0300
        tsb   sprTmp2
        lda:  {]line*4}+2,y
        asl
        asl
        asl
        asl
        asl
        and   #$3000
        ora   sprTmp2
        xba
        ora   sprTmp3
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

        iny
        iny
        iny
        iny

        txa
        clc
        adc   #160
        tax

        dec   sprTmp4
        beq   :done
        brl   :loop
:done
        rts

; Built-in font w/widgets to avoid depending on CHR-ROMs (32 bytes/tile)
;
; The binary format of these tiles are the same and the internal format that NES CHR
; data is converted to.  The LSB is zero and bits 1 - 9 designate which BGND palette
; entry to use when drawing.

            ds    \,$00
rom_cfg_chr 
rom_cfg_chr_a
            dw    %000011110,%110000000
            dw    %001111000,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111111110,%111111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %000000000,%000000000

            dw    %111111110,%111100000     ; B
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111111110,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111111110,%111100000
            dw    %000000000,%000000000

            dw    %000011110,%111100000     ; C
            dw    %001111000,%001111000
            dw    %111100000,%000000000
            dw    %111100000,%000000000
            dw    %111100000,%000000000
            dw    %001111000,%001111000
            dw    %000011110,%111100000
            dw    %000000000,%000000000

            dw    %111111110,%110000000     ; D
            dw    %111100000,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%111100000
            dw    %111111110,%110000000
            dw    %000000000,%000000000

            dw    %111111110,%111111000     ; E
            dw    %111100000,%000000000
            dw    %111100000,%000000000
            dw    %111111110,%111100000
            dw    %111100000,%000000000
            dw    %111100000,%000000000
            dw    %111111110,%111111000
            dw    %000000000,%000000000

            dw    %111111110,%111111000     ; F
            dw    %111100000,%000000000
            dw    %111100000,%000000000
            dw    %111111110,%111100000
            dw    %111100000,%000000000
            dw    %111100000,%000000000
            dw    %111100000,%000000000
            dw    %000000000,%000000000

            dw    %000011110,%111111000     ; G
            dw    %001111000,%000000000
            dw    %111100000,%000000000
            dw    %111100110,%111111000
            dw    %111100000,%001111000
            dw    %001111000,%001111000
            dw    %001111110,%111111000
            dw    %000000000,%000000000

            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111111110,%111111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %000000000,%000000000

            dw    %001111110,%111111000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %001111110,%111111000
            dw    %000000000,%000000000

            dw    %000000110,%111111000
            dw    %000000000,%001111000
            dw    %000000000,%001111000
            dw    %000000000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %001111110,%111100000
            dw    %000000000,%000000000

            dw    %111100000,%001111000
            dw    %111100000,%111100000
            dw    %111100110,%110000000
            dw    %111111110,%000000000
            dw    %111111110,%110000000
            dw    %111100110,%111100000
            dw    %111100000,%111111000
            dw    %000000000,%000000000

            dw    %001111000,%000000000
            dw    %001111000,%000000000
            dw    %001111000,%000000000
            dw    %001111000,%000000000
            dw    %001111000,%000000000
            dw    %001111000,%000000000
            dw    %001111110,%111111000
            dw    %000000000,%000000000

            dw    %111100000,%001111000
            dw    %111111000,%111111000
            dw    %111111110,%111111000
            dw    %111111110,%111111000
            dw    %111100110,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %000000000,%000000000

            dw    %111100000,%001111000
            dw    %111111000,%001111000
            dw    %111111110,%001111000
            dw    %111111110,%111111000
            dw    %111100110,%111111000
            dw    %111100000,%111111000
            dw    %111100000,%001111000
            dw    %000000000,%000000000

            dw    %001111110,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %001111110,%111100000
            dw    %000000000,%000000000

            dw    %001111110,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111111110,%111100000
            dw    %111100000,%000000000
            dw    %111100000,%000000000
            dw    %000000000,%000000000

            dw    %001111110,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100110,%111111000
            dw    %111100000,%111100000
            dw    %001111110,%110011000
            dw    %000000000,%000000000

            dw    %111111110,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%111111000
            dw    %111111110,%110000000
            dw    %111100110,%111100000
            dw    %111100000,%111111000
            dw    %000000000,%000000000

            dw    %001111110,%110000000
            dw    %111100000,%111100000
            dw    %111100000,%000000000
            dw    %001111110,%111100000
            dw    %000000000,%001111000
            dw    %111100000,%001111000
            dw    %001111110,%111100000
            dw    %000000000,%000000000

            dw    %001111110,%111111000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000000,%000000000

            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %001111110,%111100000
            dw    %000000000,%000000000

            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111111000,%111111000
            dw    %001111110,%111100000
            dw    %000011110,%110000000
            dw    %000000110,%000000000
            dw    %000000000,%000000000

            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100110,%001111000
            dw    %111111110,%111111000
            dw    %111111110,%111111000
            dw    %111111000,%111111000
            dw    %111100000,%001111000
            dw    %000000000,%000000000

            dw    %111100000,%001111000
            dw    %111111000,%111111000
            dw    %001111110,%111100000
            dw    %000011110,%110000000
            dw    %001111110,%111100000
            dw    %111111000,%111111000
            dw    %111100000,%001111000
            dw    %000000000,%000000000

            dw    %001111000,%001111000
            dw    %001111000,%001111000
            dw    %001111000,%001111000
            dw    %000011110,%111100000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000000,%000000000

            dw    %111111110,%111111000
            dw    %000000000,%111111000
            dw    %000000110,%111100000
            dw    %000011110,%110000000
            dw    %001111110,%000000000
            dw    %111111000,%000000000
            dw    %111111110,%111111000
            dw    %000000000,%000000000

rom_cfg_chr_0
            dw    %000011110,%110000000
            dw    %001100000,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %001111000,%001100000
            dw    %000011110,%110000000
            dw    %000000000,%000000000

            dw    %000000110,%110000000
            dw    %000011110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %000000110,%110000000
            dw    %001111110,%111111000
            dw    %000000000,%000000000

            dw    %001111110,%111100000
            dw    %111100000,%001111000
            dw    %000000000,%111111000
            dw    %000011110,%111100000
            dw    %001111110,%110000000
            dw    %111111000,%000000000
            dw    %111111110,%111111110
            dw    %000000000,%000000000

            dw    %001111110,%111111000
            dw    %000000000,%111100000
            dw    %000000110,%110000000
            dw    %000011110,%111100000
            dw    %000000000,%001111000
            dw    %111100000,%001111000
            dw    %001111110,%111100000
            dw    %000000000,%000000000

            dw    %000000110,%111100000
            dw    %000011110,%111100000
            dw    %001111000,%111100000
            dw    %111100000,%111100000
            dw    %111111110,%111111000
            dw    %000000000,%111100000
            dw    %000000000,%111100000
            dw    %000000000,%000000000

            dw    %111111110,%111100000
            dw    %111100000,%000000000
            dw    %111111110,%111100000
            dw    %000000000,%001111000
            dw    %000000000,%001111000
            dw    %111100000,%001111000
            dw    %001111110,%111100000
            dw    %000000000,%000000000

            dw    %000011110,%111100000
            dw    %001111000,%000000000
            dw    %111100000,%000000000
            dw    %111111110,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %001111110,%111100000
            dw    %000000000,%000000000

            dw    %111111110,%111111000
            dw    %111100000,%001111000
            dw    %000000000,%111100000
            dw    %000000110,%110000000
            dw    %000011110,%000000000
            dw    %000011110,%000000000
            dw    %000011110,%000000000
            dw    %000000000,%000000000

            dw    %001111110,%110000000
            dw    %111100000,%001100000
            dw    %111111000,%001100000
            dw    %001111110,%110000000
            dw    %110000000,%001111000
            dw    %110000000,%001111000
            dw    %001111110,%111100000
            dw    %000000000,%000000000

            dw    %001111110,%111100000
            dw    %111100000,%001111000
            dw    %111100000,%001111000
            dw    %001111110,%111111000
            dw    %000000000,%001111000
            dw    %000000000,%111100000
            dw    %001111110,%110000000
            dw    %000000000,%000000000

rom_cfg_chr_space
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000

rom_cfg_chr_cursor
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000011110,%111100000
            dw    %000011110,%111100000
            dw    %000011110,%111100000
            dw    %000011110,%111100000
            dw    %000000000,%000000000
            dw    %000000000,%000000000

rom_cfg_chr_vert_left
            dw    %001100000,%000000000
            dw    %001100000,%000000000
            dw    %001100000,%000000000
            dw    %001100000,%000000000
            dw    %001100000,%000000000
            dw    %001100000,%000000000
            dw    %001100000,%000000000
            dw    %001100000,%000000000

rom_cfg_chr_vert_right
            dw    %000000000,%000011000
            dw    %000000000,%000011000
            dw    %000000000,%000011000
            dw    %000000000,%000011000
            dw    %000000000,%000011000
            dw    %000000000,%000011000
            dw    %000000000,%000011000
            dw    %000000000,%000011000

rom_cfg_chr_top_left
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000011110,%111111110
            dw    %001100000,%000000000
            dw    %001100000,%000000000

rom_cfg_chr_top_right
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %111111110,%111100000
            dw    %000000000,%000011000
            dw    %000000000,%000011000

rom_cfg_chr_bot_left
            dw    %001100000,%000000000
            dw    %001100000,%000000000
            dw    %000011110,%111111110
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000

rom_cfg_chr_bot_right
            dw    %000000000,%000011000
            dw    %000000000,%000011000
            dw    %111111110,%111100000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000

rom_cfg_chr_horz_top
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %111111110,%111111110
            dw    %000000000,%000000000
            dw    %000000000,%000000000

rom_cfg_chr_horz_bot
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %111111110,%111111110
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000

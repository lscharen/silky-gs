; Control types
RADIO           equ 1     ; radio (mutually exclusive options)
CHKBOX          equ 2     ; checkbox (boolean)
KEYMAP          equ 3     ; keymap (reads input character; tab to enter/exit)

CHKBOX_YES          str 'YES'
CHKBOX_NO           str ' NO'
CHKBOX_ON           str ' ON'
CHKBOX_OFF          str 'OFF'


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
CTRL_RADIO_OPTION_COUNT  equ CTRL_DATA
CTRL_RADIO_OPTION_VALUE  equ CTRL_DATA+2
CTRL_RADIO_OPTION_LABEL  equ CTRL_DATA+4
CTRL_RADIO_OPTION_SIZEOF equ 4

; Units to move text around
COL_STEP    equ 4
ROW_STEP    equ {8*160}

; Menu panel area
MENU_PANEL_ORIGIN equ $2000+x_offset+4+{160*16}

; Config / Control palen area
CONFIG_PANEL_ORIGIN equ $2000+x_offset+48+{160*8}
CONFIG_PANEL_WIDTH equ {160-44-x_offset}
CONFIG_PANEL_HEIGHT equ 144

; Palette select for normal / selected / yes / no test
TEXT_NORMAL equ CONFIG_PALETTE*2
TEXT_SELECTED equ 2
TEXT_YES equ 2
TEXT_NO equ 0

; Creates a UI for the runtime configuration
ShowConfig

; Set the palette for the config screen

            lda  #0
            jsr  _SetSCBs

            lda  #0
            jsr  ClearScreen

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

:loop
            jsr _UpdateMenuCursor
            jsr _DrawActiveMenuControls
            jsr _UpdateControlCursor

:waitloop
            jsr  _ReadControl
            bit  #PAD_KEY_DOWN
            beq  :waitloop

            and  #$007F
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
            bne  :waitloop
            clc
            rts
:abort
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
            beq   :no_action
            sta   config_active_ctrl
            rts

:no_action
            rts

:set_first_control_active
            lda:  MENU_CTRL_COUNT,x
            beq   :no_items
            lda:  MENU_CTRL_LIST,x
            sta   config_active_ctrl
:no_items
            rts

config_active_menu ds 2    ; currently selected menu item
config_active_ctrl ds 2    ; currently selected control
config_focus       ds 2


; Render the configuration sidebar
_DrawConfigMenu
:count      equ  tmp14
:addr       equ  tmp15

            lda  CONFIG_MENU
            asl
            sta  :count

            ldx  #0

            lda  #MENU_PANEL_ORIGIN
            sta  :addr
:dcm_loop
            phx

            lda: CONFIG_MENU+2,x               ; Get the address of the config block for this menu item
            tax

            lda  :addr
            clc
            adc  #4*COL_STEP
            tay

            lda: MENU_TITLE,x                  ; Load the title pointer
            tax
            lda  #CONFIG_PALETTE*2
            jsr  ConfigDrawString

            lda  :addr
            sec
            sbc  #2*ROW_STEP
            tay
            jsr  ConfigDrawTopBorder

            lda  :addr
            sec
            sbc  #1*ROW_STEP
            tay
            jsr  ConfigDrawSideBorder

            lda  :addr
            clc
            adc  #4*ROW_STEP
            sta  :addr

            plx
            inx
            inx
            cpx  :count
            bcc  :dcm_loop
            rts

_ClearPanel
:line       equ  tmp15

            phx
            phy

            lda  #CONFIG_PANEL_HEIGHT
            sta  :line

            ldx  #CONFIG_PANEL_ORIGIN
:oloop
            ldy  #CONFIG_PANEL_WIDTH
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
            adc  #160-CONFIG_PANEL_WIDTH
            tax

            dec  :line
            bne  :oloop

            ply
            plx
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
; +----------------
; + XX <title>  
;
; Where XX is the character hex code
_DrawKeymap
:addr       equ  tmp15

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
            lda  #TEXT_NORMAL
            jmp  ConfigDrawByte
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
;
; Wait for the user to press a key
_ToggleKeymap
:addr       equ  tmp15

            lda: CTRL_VALUE_ADDR,x
            sta  :addr   ; address of the value

:waitloop   jsr  _ReadControl
            bit  #PAD_KEY_DOWN
            beq  :waitloop

            and  #$007F
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
; Move the radio to the next value
_ToggleRadio
:value      equ  tmp15
:count      equ  tmp14
:addr       equ  tmp13

            stx  :addr

            lda: CTRL_VALUE_ADDR,x
            sta  :value                       ; address of the value

            lda: CTRL_RADIO_OPTION_COUNT,x
            beq  :done

            sta  :count
            ldy  #0

:loop

; Find the index of the current value

            lda: CTRL_RADIO_OPTION_VALUE,x
            cmp  (:value)
            beq  :found

            txa
            clc
            adc  #CTRL_RADIO_OPTION_SIZEOF
            tax

            iny
            cpy  :count
            bcc  :loop
            rts

:found
            tya
            inc
            cmp  :count
            bcc  *+5
            lda  #0

            asl
            asl                    ; multiply by 4 to get the option item
            clc
            adc  :addr
            tax
            lda: CTRL_RADIO_OPTION_VALUE,x
            sta  (:value)          ; Update the value

:done
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

; First two words are the offset coordinates of the control

            jsr  _OffsetToAddr
            sty  :addr

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

:not_keymap
            rts

; Switchthe value of the active control
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

:not_keymap
            rts

; Loads the active menu address from config_active_menu
_DrawActiveMenuControls
            ldx  config_active_menu
            bne  *+3                   ; Check that it is set
            rts

; X = menu item address
_DrawMenuControls
            jsr  _ClearPanel

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
            cpy  #8           ; number of items
            bcc  :loop
            ldy  #0           ; pick index zero by default

:found      tya
            lsr

            plx
            ply
            rts

; If the focus is on the config panel, draw the curson next to the
; active control
_UpdateControlCursor
            ldx  config_active_menu
            bne  *+3                   ; Check that it is set
            rts

            lda: MENU_CTRL_COUNT,x
            beq  :no_controls
            tay

:loop
            phx
            phy
            lda: MENU_CTRL_LIST,x
            jsr  _DrawControlCursor
            ply
            pla
            clc
            adc #2
            tax
            dey
            bne  :loop

:no_controls
            rts

_DrawControlCursor
:tile       equ  tmp15

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
            plx

            jsr  _OffsetToAddr            ; Address of control label
            tya
            sec
            sbc  #2*COL_STEP
            tay                           ; Move to the left

            lda   :tile
            ldx   #CONFIG_PALETTE*2
            jsr   blitTile

            rts

_UpdateMenuCursor
            lda  CONFIG_MENU+2
            jsr  _DrawMenuCursor
            lda  CONFIG_MENU+4
            jsr  _DrawMenuCursor
            lda  CONFIG_MENU+6
            jsr  _DrawMenuCursor
            lda  CONFIG_MENU+8
            
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
            asl                           ; x8

            asl
            asl                           ; x4 spaces between 

            asl                           ; x2 for indexing
            tax
            lda   Mul160Tbl,x
            clc
            adc   #MENU_PANEL_ORIGIN
            clc
            adc   #8
            tay

            lda   :tile
            ldx   #CONFIG_PALETTE*2
            jsr   blitTile

            rts

; Y = address
ConfigDrawSideBorder
            ldx  #3
:loop
            phx

            phy
            lda  #TILE_VERTICAL_LEFT
            ldx  #CONFIG_PALETTE*2
            jsr  blitTile
            pla
            clc
            adc  #40
            tay
            phy
            lda  #TILE_VERTICAL_RIGHT
            ldx  #CONFIG_PALETTE*2
            jsr  blitTile
            pla
            clc
            adc  #{8*160}-40
            tay

            plx
            dex
            bne  :loop
            rts

; Y = address
ConfigDrawTopBorder
            phy
            lda  #TILE_TOP_LEFT
            ldx  #CONFIG_PALETTE*2
            jsr  blitTile
            ply

            ldx  #9
:hloop
            tya
            clc
            adc #4
            tay

            phy
            phx
            lda  #TILE_HORIZONTAL
            ldx  #CONFIG_PALETTE*2
            jsr  blitTile
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
            jsr  blitTile
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
            clc
            adc   #TILE_A
            bra   :drawHigh
:drawDigitHigh
            clc
            adc   #TILE_ZERO

:drawHigh
            ldy  tmp1
            ldx  tmp2
            jsr  blitTile

            lda   tmp1
            clc
            adc   #4
            sta   tmp1


            lda   tmp0
            and   #$000F
            cmp   #$000A
            bcc   :drawDigitLow
            sbc   #$000A
            clc
            adc   #TILE_A
            bra   :drawLow
:drawDigitLow
            clc
            adc   #TILE_ZERO

:drawLow
            ldy  tmp1
            ldx  tmp2
            jmp  blitTile

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
            clc
            adc   #TILE_A
            bra   :draw
:not_letter
            cmp   #'0'
            bcc   :skip
            sbc   #'0'
            clc
            adc   #TILE_ZERO
:draw
            ldy  tmp1
            ldx  tmp2
            jsr  blitTile

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
            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   ../../Externals.s
            put   ../../core/Defs.s

            mx    %00

; Define all of the macros that are used to callback into this
; code.  Defining an empty macro will result in no callback

; Callback before entering the main event loop
PRE_EVT_LOOP mac
;
             <<<

POST_EVT_LOOP mac
;
             <<<

EVT_LOOP_BEGIN mac
;
             <<<

; This hook happens immediately after all key presses have been handled by the scaffold and gives
; user-code a change to implement custom key commands
EVT_LOOP_END mac
             cmp  #'d'
             bne  not_d
             lda  disableDirtyRendering
             eor  #1
             sta  disableDirtyRendering
not_d
             <<<

; Pre-render check to see if there are any background tiles queued for updates.  If so, we will do
; a regular rendering.  If not, use dirty rendering.
PRE_RENDER   mac

             stz  use_dirty
             lda  at_queue_tail
             cmp  tmp4                    ; If there are any attribute changes, render the full screen
             bne  do_full
             inc  use_dirty
do_full
             <<<

POST_RENDER  mac
;
             <<<

; Put in additional conditions to skip sprites when scanning the OAM table to decide what to
; render.  Set the carry flag to keep, clear the carry flag to skip
;
; Input: The accumulator holds the first two OAM bytes (y-position and tile id)
SCAN_OAM_XTRA_FILTER mac
            eor    #$FC00             ; Is the tile == $FC? This is a blank tile in this ROM
            cmp    #$0100
            <<<

; Define which PPU address has the background and sprite tiles
PPU_BG_TILE_ADDR  equ #$1000
PPU_SPR_TILE_ADDR equ #$0000

; Flag if the NES_StartUp code should keep a spriteable bitmap copy of the background tiles,
; in addition to the compiled representation
BG_TILES_AS_SPRITES equ 1

; Define what kind of execution harness to use
;
; 0 = Reset code drops into an infinite loop
; 1 = Reset code is the game code
ROM_DRIVER_MODE   equ 1

; Flag whether the backend should use the OAMDMA to get the sprite information,
; or if it can scan the NES RAM area directly
;
; 0  = use OAM DMA
; >0 = read $100 bytes directly from NES RAM at this address (typically $200)
DIRECT_OAM_READ   equ $200

; Flag whether to ignore Sprite 0.  Some games use this sprite only for the 
; special sprite 0 collision behavior, which is not supported in this runtime
ALLOW_SPRITE_0    equ 1   ; Sprite 0 is the lightning spark

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.
NO_INTERRUPTS     equ 1

; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ BF_PALETTE_DISPATCH

; Turn on code that visualizes the CPU time used by the ROM code
SHOW_ROM_EXECUTION_TIME equ 0

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 3 
y_height_rows equ 25
y_offset      equ {y_offset_rows*8}
y_height      equ {y_height_rows*8}
min_nes_y     equ 24
max_nes_y     equ min_nes_y+y_height

x_offset      equ 16                      ; number of bytes from the left edge

            phk
            plb

; Call startup immediately after entering the application: A = memory manager user ID

            jsr   NES_StartUp

; Initialize the game-specific variables

            stz   LastAreaType            ; Check if the palettes need to be updates

; This is set up to let the game define all colors.  We only need to set up a single, static
; swizzle table

            lda   SwizzleTables+2
            ldx   SwizzleTables
            jsr   NES_SetPaletteMap

; Show the configuration screen

            ldx   #CONFIG_BLK
            jsr   ShowConfig
            bcc   *+5
            jmp   quit

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Start the FPS counter

            ldal  OneSecondCounter
            sta   OldOneSec
            lda   frameCount
            sta   oldFrameCount

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
; Call the boot code in the ROM

            jsr   NES_ColdBoot

; We _never_ scroll vertically, so just set it once.  This is to make sure these kinds of optimizations
; can be set up in the generic structure

            lda   #24
            jsr   _SetBG0YPos
            jsr   _ApplyBG0YPosPreLite
            jsr   _ApplyBG0YPosLite

; Start up the NES
:start
            jsr   NES_EvtLoop

            cmp   #USER_SAYS_QUIT
            beq   quit

            cmp   #USER_SAYS_RESET
            bne   quit

            jsr   NES_WarmBoot
            bra   :start

; The user has existed the runtime
quit
            jsr   NES_ShutDown

; Exit the application

            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

Greyscale   dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF

TmpPalette  ds    32

; Program variables
singleStepMode    dw  0
LastAreaType      dw  0
show_vbl_cpu      dw  0
user_break        dw  0
use_dirty         dw  0        ; can use dirty rendering for this frame
oldFrameCount     dw  0
disableDirtyRendering dw 0

; Helper to initialize the playfield based on the selected VideoMode
InitPlayfield
;            lda   #16
            lda   #24
            sta   NesTop

            lda   VideoMode
            cmp   #0
            beq   :good
            cmp   #2
            beq   :better

            lda   #0
            sta   MinYScroll

            lda   #200
            sta   ScreenHeight
            bra   :common

:better
;            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
            lda   #24
            sta   MinYScroll

            lda   #160           ; 160 lines high for 'better'
            sta   ScreenHeight
            bra   :common

:good
;            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
            lda   #24
            sta   MinYScroll

            lda   #128           ; Only 128 lines tall for speed
            sta   ScreenHeight

; Common follow-on initialization
:common
            lda   ScreenHeight
            lsr
            lsr
            lsr
            sta   ScreenRows

            lda   #200           ; Only display down to this row
            sec
            sbc   ScreenHeight
            sta   MaxYScroll

            lda   NesTop
            clc
            adc   ScreenHeight
            sec
            sbc   #8
            inc
            sta   NesBottom

; Initialize the graphics screen playfield

            ldx   #128
            ldy   ScreenHeight
            jsr   _SetScreenMode                 ; This is also called in the Init

            lda   ScreenY0
            asl
            asl
            asl
            asl
            asl
            sta   ScreenBase
            asl
            asl
            clc
            adc   ScreenBase
            clc
            adc   #$2000+x_offset
            sta   ScreenBase

; Set a default palette for the title screen

            ldx   #TitleScreen
            lda   #0
            jsr   NES_SetPalette

            rts


; When the NES ROM code tried to write to the PPU palette space, intercept here.
BF_PALETTE_DISPATCH
        dw   BF_3F00,BF_3F01,BF_3F02,BF_3F03
        dw   ppu_3F04,BF_3F05,BF_3F06,BF_3F07
        dw   ppu_3F08,BF_3F09,BF_3F0A,BF_3F0B
        dw   ppu_3F0C,BF_3F0D,BF_3F0E,BF_3F0F

        dw   BF_3F10,BF_3F11,BF_3F12,BF_3F13
        dw   ppu_3F14,ppu_3F15,ppu_3F16,ppu_3F17
        dw   ppu_3F18,BF_3F19,BF_3F1A,BF_3F1B
        dw   ppu_3F1C,BF_3F1D,BF_3F1E,BF_3F1F

; Background color
BF_3F00 ldal PPU_MEM+$3F00
        jsr  NES_ColorToIIgs
        stal $E19E00
        stal $E19E20
        stal $E19E40
        rts

BF_3F10 ldal PPU_MEM+$3F10
        jsr  NES_ColorToIIgs
        stal $E19E00
        stal $E19E20
        stal $E19E40
        rts

; Tile palette 1, color 1
BF_3F01 ldal PPU_MEM+$3F01
        jsr  NES_ColorToIIgs
;        stal $E19E02
        stal $E19E22
        stal $E19E42
        rts

; Tile palette 1, color 2
BF_3F02 ldal PPU_MEM+$3F02
        jsr  NES_ColorToIIgs
;        stal $E19E04
        stal $E19E24
        stal $E19E44
        rts

; Tile palette 1, color 3
BF_3F03 ldal PPU_MEM+$3F03
        jsr  NES_ColorToIIgs
;        stal $E19E06
        stal $E19E26
        stal $E19E46
        rts


; Tile palette 2, color 1
BF_3F05 ldal PPU_MEM+$3F05
        jsr  NES_ColorToIIgs
        stal $E19E08
        stal $E19E02
        rts

; Tile palette 2, color 2
BF_3F06 ldal PPU_MEM+$3F06
        jsr  NES_ColorToIIgs
        stal $E19E0A
        stal $E19E04
        rts

; Tile palette 2, color 3
BF_3F07 ldal PPU_MEM+$3F07
        jsr  NES_ColorToIIgs
        stal $E19E0C
        stal $E19E06
        rts


; Tile palette 3, color 1
BF_3F09 ldal PPU_MEM+$3F09
        jsr  NES_ColorToIIgs
        stal $E19E28
        rts

; Tile palette 3, color 2
BF_3F0A ldal PPU_MEM+$3F0A
        jsr  NES_ColorToIIgs
        stal $E19E2A
        rts

; Tile palette 3, color 3
BF_3F0B ldal PPU_MEM+$3F0B
        jsr  NES_ColorToIIgs
        stal $E19E2C
        rts


; Tile palette 4, color 1
BF_3F0D ldal PPU_MEM+$3F0D
        jsr  NES_ColorToIIgs
        stal $E19E48
        rts

; Tile palette 4, color 2
BF_3F0E ldal PPU_MEM+$3F0E
        jsr  NES_ColorToIIgs
        stal $E19E4A
        rts

; Tile palette 4, color 3
BF_3F0F ldal PPU_MEM+$3F0F
        jsr  NES_ColorToIIgs
        stal $E19E4C
        rts


; Sprite palette 1, color 1
BF_3F11 ldal PPU_MEM+$3F11
        jsr  NES_ColorToIIgs
        stal $E19E0E
        stal $E19E2E
        stal $E19E4E
        rts

; Sprite palette 1, color 2
BF_3F12 ldal PPU_MEM+$3F12
        jsr  NES_ColorToIIgs
        stal $E19E10
        stal $E19E30
        stal $E19E50
        rts

; Sprite palette 1, color 3
BF_3F13 ldal PPU_MEM+$3F13
        jsr  NES_ColorToIIgs
        stal $E19E12
        stal $E19E32
        stal $E19E52
        rts

; Sprite palette 2 is mapped to palette 1 colors

; Sprite palette 3, color 1
BF_3F19 ldal PPU_MEM+$3F19
        jsr  NES_ColorToIIgs
        stal $E19E14
        stal $E19E34
        stal $E19E54
        rts

; Sprite palette 3, color 2
BF_3F1A ldal PPU_MEM+$3F1A
        jsr  NES_ColorToIIgs
        stal $E19E16
        stal $E19E36
        stal $E19E56
        rts

; Sprite palette 3, color 3
BF_3F1B ldal PPU_MEM+$3F1B
        jsr  NES_ColorToIIgs
        stal $E19E18
        stal $E19E38
        stal $E19E58
        rts


; Sprite palette 4, color 1
BF_3F1D ldal PPU_MEM+$3F1D
        jsr  NES_ColorToIIgs
        stal $E19E1A
        stal $E19E3A
        stal $E19E5A
        rts

; Sprite palette 4, color 2
BF_3F1E ldal PPU_MEM+$3F1E
        jsr  NES_ColorToIIgs
        stal $E19E1C
        stal $E19E3C
        stal $E19E5C
        rts

; Sprite palette 4, color 3
BF_3F1F ldal PPU_MEM+$3F1F
        jsr  NES_ColorToIIgs
        stal $E19E1E
        stal $E19E3E
        stal $E19E5E
        rts


; Make the screen appear
nesTopOffset    ds 2
nesBottomOffset ds 2

; Patch the PEA field based on the current PPU parameters
_SetupPEAField
; Now render the top 16 lines to show the status bar area

            clc
            lda   #24*2
            sta   tmp1                    ; virt_line_x2
            lda   #16*2
            sta   tmp2                    ; lines_left_x2
            lda   #0                      ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesTopOffset            ; cache the :exit_offset value returned from this function

; Next render the remaining lines

            lda   #40*2
            sta   tmp1                ; virt_line_x2
            lda   ScreenHeight
            sec
            sbc   #16
            asl
            sta   tmp2                ; lines_left_x2
            lda   StartX              ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesBottomOffset

            lda   #1
            sta   peaFieldIsPatched
            rts

; Restore the patched PEA field to put it back into a clean state
_ResetPEAField
            stz   peaFieldIsPatched

            lda   #24                     ; virt_line
            ldx   #16                     ; lines_left
            ldy   nesTopOffset            ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            lda   ScreenHeight
            sec
            sbc   #16
            tax                           ; lines_left
            lda   #40                     ; virt_line
            ldy   nesBottomOffset         ; offset to patch
            jmp   _RestoreBG0OpcodesAltLite

; Track if the PEA field is patched or not
peaFieldIsPatched dw 0

RenderScreen

; Do the basic setup

            sep   #$20
            lda   ppuctrl                 ; Bit 0 is the high bit of the X scroll position
            lsr                           ; put in the carry bit
            lda   ppuscroll+1             ; load the scroll value
            ror                           ; put the high bit and divide by 2 for the engine
            rep   #$20
            and   #$00FF                  ; make sure nothing is in the high byte
            jsr   _SetBG0XPos

            lda   ppumask
            and   ppumask_override
            and   #NES_PPUMASK_BG
            jsr   EnableBackground

            lda   ppumask
            and   ppumask_override
            and   #NES_PPUMASK_SPR
            jsr   EnableSprites


; Determine if this will be a dirty update or not

            lda   DirtyBits
            bit   #DIRTY_BIT_BG0_X+DIRTY_BIT_BG0_REFRESH
            bne   :full_update
            lda   disableDirtyRendering
            bne   :full_update
            lda   use_dirty
            bne   :dirty_update
:full_update
            lda   peaFieldIsPatched
            beq   :no_restore
            jsr   _ResetPEAField          ; A full update needs to restore the PEA field before changing the XPos
:no_restore
            jsr   _SetupPEAField
            jsr   drawScreen
            bra   :complete
:dirty_update
            lda   peaFieldIsPatched
            bne   :no_patch
            jsr   _SetupPEAField
:no_patch
            jsr   drawDirtyScreen
:complete

; Patch the PEA field give the current frame's parameters

;            jsr   _SetupPEAField

; See if we are doing a dirty update or a full render

;            lda   DirtyBits
;            bit   #DIRTY_BIT_BG0_X+DIRTY_BIT_BG0_REFRESH
;            bne   :full_update
;            lda   disableDirtyRendering
;            bne   :full_update
;            lda   use_dirty
;            beq   :full_update

;            jsr   drawDirtyScreen
;            bra   :complete

;:full_update
;            jsr   drawScreen

;:complete

; Clear any dirty flags

;            lda   #DIRTY_BIT_BG0_X+DIRTY_BIT_BG0_REFRESH
;            trb   DirtyBits
             stz   DirtyBits
;:done

; Restore the PEA field

;            jsr   _ResetPEAField


; Optionally show the frames per second
            DO    SHOW_DEBUG_VARS
            ldal  OneSecondCounter
            cmp   OldOneSec
            beq   :skip_fps

            sta   OldOneSec
            ldx   frameCount
            txa
            sec
            sbc   oldFrameCount
            stx   oldFrameCount
            ldx   #0
            ldy   #$FFFF
            jsr   DrawByte
:skip_fps

            lda   disableDirtyRendering
            ldx   #8*160
            ldy   #$FFFF
            jsr   DrawByte
            FIN

            stz   LastPatchOffset
            rts

; For this game, we utilize multiple palettes to conserve palette colors and reserve colors for the sprites
SetDefaultPalette

; Set the tile/sprite mapping

            lda   SwizzleTables+2
            ldx   SwizzleTables
            jsr   NES_SetPaletteMap

; Set the SCB ranges

            ldx   #0
            lda   #$0000
:scb1       stal  $E19D00,x
            inx
            inx
            cpx   #16
            bcc   :scb1


            lda   #$0202
:scb2       stal  $E19D00,x
            inx
            inx
            cpx   #192
            bcc   :scb2

            lda   #$0101
:scb3       stal  $E19D00,x
            inx
            inx
            cpx   #200
            bcc   :scb3

            rts


SwizzleTables adrl L1_T0

; Palettes of NES color indexes
ConfScrnPal  dw    $0F, $30, $27, $2A, $15, $02, $21, $00, $10, $16, $12, $37, $21, $17, $11, $2B
TitleScreen  dw    $0F, $30, $27, $2A, $15, $02, $21, $00, $10, $16, $12, $37, $21, $17, $11, $2B
LevelHeader1 dw    $0F, $2A, $09, $07, $30, $27, $16, $11, $21, $00, $10, $12, $37, $17, $35, $2B

ClearScreen
            ldx  #$7CFE
:loop       stal $012000,x
            dex
            dex
            bpl  :loop
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

config_audio_quality   ds  2  ; good / better / best audio quality (60Hz, 120Hz, 240Hz audio interrupts)
config_video_statusbar dw  1  ; exclude the status bar from the animate playfield area or not
config_video_fastmode  ds  2  ; use the "skip line" rendering mode
config_video_notwinkle ds  2  ; disable the background star animation
config_input_type      dw  0  ; keyboard / joystick / snes max
config_input_key_left  dw  LEFT_ARROW
config_input_key_right dw  RIGHT_ARROW
config_input_key_up    dw  UP_ARROW
config_input_key_down  dw  DOWN_ARROW

CONFIG_PALETTE  equ 0
TILE_TOP_LEFT   equ $1E0
TILE_TOP_RIGHT  equ $1E2
TILE_HORIZONTAL equ $1E1
TILE_VERTICAL   equ $1E1
TILE_ZERO       equ $100
TILE_A          equ $10A
TILE_SPACE      equ $124
TILE_CURSOR     equ $0A0  ; $10A

; Control types
RADIO           equ 1     ; radio (mutually exclusive options)
CHKBOX          equ 2     ; checkbox (boolean)
KEYMAP          equ 3     ; keymap (reads input character; tab to enter/exit)

CHKBOX_YES          str 'YES'
CHKBOX_NO           str ' NO'
CHKBOX_ON           str ' ON'
CHKBOX_OFF          str 'OFF'

AUDIO_TITLE_STR     str 'AUDIO'
AUDIO_QUALITY_STR   str 'QUALITY'
AUDIO_QUALITY_OPT_1 str ' 60 HZ'
AUDIO_QUALITY_OPT_2 str '120 HZ'
AUDIO_QUALITY_OPT_3 str '240 HZ'

VIDEO_TITLE_STR      str 'VIDEO'
VIDEO_FASTMODE_STR   str 'FAST BLIT'
VIDEO_STATUS_BAR_STR str 'STATUS BAR'

INPUT_TITLE_STR     str 'INPUT'
INPUT_TYPE_STR      str 'TYPE'
INPUT_TYPE_OPT_1    str 'KEYBOARD'
INPUT_TYPE_OPT_2    str 'JOYSTICK'
INPUT_TYPE_OPT_3    str 'SNES MAX'
INPUT_LEFT_MAP_STR  str 'LEFT'
INPUT_RIGHT_MAP_STR str 'RIGHT'
INPUT_UP_MAP_STR    str 'UP'
INPUT_DOWN_MAP_STR  str 'DOWN'

GAME_TITLE_STR      str 'GAME'
GAME_NO_ANIM_STR    str 'STAR ANIMATION'

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
TEXT_NORMAL equ 0
TEXT_SELECTED equ 2
TEXT_YES equ 2
TEXT_NO equ 0

; The configuration screen leverages the NES runtime itself
CONFIG_BLK   db   CONFIG_PALETTE        ; Which background palette to use
             db   TILE_TOP_LEFT         ; Define the tiles to use for the UI
             db   TILE_TOP_RIGHT
             db   TILE_HORIZONTAL
             db   TILE_VERTICAL
             db   TILE_ZERO             ; First tile for the 0 - 9 characters
             db   TILE_A                ; First tile for the alphabet A - Z characters
             db   TILE_SPACE
CONFIG_MENU  dw   4                     ; Four screens "Audio", "Video", "Input", "Game"
             dw   AUDIO_CONFIG
             dw   VIDEO_CONFIG
             dw   INPUT_CONFIG
             dw   GAME_CONFIG

AUDIO_CONFIG dw   AUDIO_TITLE_STR
             dw   0                     ; previous menu item
             dw   VIDEO_CONFIG          ; next menu item

             dw   1                     ; One configuration element
             dw   AUDIO_ITEM_1

AUDIO_ITEM_1 dw   RADIO                 ; A radio button (mutually exclusive) option
             dw   0                     ; previous control
             dw   0                     ; next control
             dw   3,1                   ; X,Y location of control in the config area
             dw   AUDIO_QUALITY_STR     ; Title
             dw   config_audio_quality  ; Memory address to write the configuration value
             dw   3                     ; Three options
             dw   0                     ; config value
             dw   AUDIO_QUALITY_OPT_1   ; config label
             dw   2
             dw   AUDIO_QUALITY_OPT_2
             dw   4
             dw   AUDIO_QUALITY_OPT_3

VIDEO_CONFIG dw   VIDEO_TITLE_STR
             dw   AUDIO_CONFIG          ; previous menu item
             dw   INPUT_CONFIG          ; next menu item

             dw   2                     ; Two configuration elements
             dw   VIDEO_ITEM_1
             dw   VIDEO_ITEM_2

VIDEO_ITEM_1 dw   CHKBOX                ; Checkbox just forces a 0/1 for False/True
             dw   0                     ; previous control
             dw   VIDEO_ITEM_2          ; next control
             dw   3,1
             dw   VIDEO_STATUS_BAR_STR
             dw   config_video_statusbar

VIDEO_ITEM_2 dw   CHKBOX
             dw   VIDEO_ITEM_1          ; previous control
             dw   0                     ; next control
             dw   3,3
             dw   VIDEO_FASTMODE_STR
             dw   config_video_fastmode

INPUT_CONFIG dw   INPUT_TITLE_STR
             dw   VIDEO_CONFIG          ; previous menu item
             dw   GAME_CONFIG           ; next menu item

             dw   5
             dw   INPUT_ITEM_1
             dw   INPUT_ITEM_2
             dw   INPUT_ITEM_3
             dw   INPUT_ITEM_4
             dw   INPUT_ITEM_5

INPUT_ITEM_1 dw   RADIO
             dw   0
             dw   INPUT_ITEM_2
             dw   3,1
             dw   INPUT_TYPE_STR
             dw   config_input_type
             dw   3
             dw   0
             dw   INPUT_TYPE_OPT_1
             dw   2
             dw   INPUT_TYPE_OPT_2
             dw   4
             dw   INPUT_TYPE_OPT_3

INPUT_ITEM_2 dw   KEYMAP
             dw   INPUT_ITEM_1
             dw   INPUT_ITEM_3
             dw   3,7
             dw   INPUT_LEFT_MAP_STR
             dw   config_input_key_left

INPUT_ITEM_3 dw   KEYMAP
             dw   INPUT_ITEM_2
             dw   INPUT_ITEM_4
             dw   3,8
             dw   INPUT_RIGHT_MAP_STR
             dw   config_input_key_right

INPUT_ITEM_4 dw   KEYMAP
             dw   INPUT_ITEM_3
             dw   INPUT_ITEM_5
             dw   3,9
             dw   INPUT_UP_MAP_STR
             dw   config_input_key_up

INPUT_ITEM_5 dw   KEYMAP
             dw   INPUT_ITEM_4
             dw   0
             dw   3,10
             dw   INPUT_DOWN_MAP_STR
             dw   config_input_key_down


GAME_CONFIG  dw   GAME_TITLE_STR
             dw   INPUT_CONFIG          ; previous menu item
             dw   0                     ; next menu item

             dw   1
             dw   GAME_ITEM_1

GAME_ITEM_1  dw   CHKBOX
             dw   0
             dw   0
             dw   3,1
             dw   GAME_NO_ANIM_STR
             dw   config_video_notwinkle

; Draw PPU tiles to the screen for a UI
;
; 0 - 9 starts at tile 256
; A - Z starts at tile 266
; mushroom is $1CE = 462
;TILE_ZERO   equ 256
;TILE_A      equ 266
;TILE_SHROOM equ 462
;TILE_BLANK  equ 295
_PutTile    mac
            lda  ]1
            sta  tmp0
            lda  #$2000+{]2*COL_STEP}+{]3*ROW_STEP}
            sta  tmp1
            jsr  drawTileToScreen
            <<<
_PutStr     mac
            ldx #]1
            ldy #$2000+{]2*COL_STEP}+{]3*ROW_STEP}
            jsr ConfigDrawString
            <<<

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
            lda  #0
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
            ldx   #0
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
;            jmp  _DrawMenuCursor
            
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
            ldx   #0
            jsr   blitTile

            rts

config_active_menu ds 2    ; currently selected menu item
config_active_ctrl ds 2    ; currently selected control
config_focus       ds 2

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

GoodPalette   dw    0,2,2
BetterPalette dw    2,0,2
BestPalette   dw    2,2,0

; Y = address
ConfigDrawSideBorder
            ldx  #3
:loop
            phx

            phy
            lda  #TILE_VERTICAL
            ldx  #0
            jsr  blitTile
            pla
            clc
            adc  #40
            tay
            phy
            lda  #TILE_VERTICAL
            ldx  #0
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
            ldx  #0
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
            ldx  #0
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
            ldx  #0
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

            put   ../../misc/App.Msg.s
            put   ../../misc/font.s
            put   ../../ppu/ppu.s

; Palette remapping
            put   palettes.s
            put   ../../apu/apu.s

; Core code
            put   ../../rom/scaffold.s
            put   ../../rom/rom_helpers.s
            put   ../../rom/rom_input.s
            put   ../../rom/rom_exec.s
            put   ../../core/ControlBits.s
            put   ../../core/CoreData.s
            put   ../../core/CoreImpl.s
            put   ../../core/Graphics.s
            put   ../../core/Math.s
            put   ../../core/Memory.s
            put   ../../core/blitter/BlitterLite.s
            put   ../../core/blitter/PEISlammer.s
            put   ../../core/blitter/HorzLite.s
            put   ../../core/blitter/VertLite.s
            put   ../../core/tiles/CompileTile.s

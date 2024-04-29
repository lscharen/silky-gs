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
; in addition to the compiled representation (usually yes, since this is used for the config
; screen)
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

CONFIG_PALETTE       equ 0
TILE_TOP_LEFT        equ $1E0
TILE_TOP_RIGHT       equ $1E2
TILE_HORIZONTAL      equ $1E1
TILE_VERTICAL_LEFT   equ $1E1
TILE_VERTICAL_RIGHT  equ $1E1
TILE_ZERO            equ $100
TILE_A               equ $10A
TILE_SPACE           equ $124
TILE_CURSOR          equ $0A0  ; $10A

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

; The configuration screen leverages the NES runtime itself
CONFIG_BLK   db   CONFIG_PALETTE        ; Which background palette to use
             db   TILE_TOP_LEFT         ; Define the tiles to use for the UI
             db   TILE_TOP_RIGHT
             db   TILE_HORIZONTAL
             db   TILE_VERTICAL_LEFT
             db   TILE_VERTICAL_RIGHT
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

            DO    SHOW_DEBUG_VARS
            put   ../../misc/App.Msg.s
            put   ../../misc/font.s
            FIN

            put   ../../ppu/ppu.s

; Palette remapping
            put   palettes.s
            put   ../../apu/apu.s

; Core code
            put   ../../rom/scaffold.s
            put   ../../rom/rom_helpers.s
            put   ../../rom/rom_input.s
            put   ../../rom/rom_exec.s
            put   ../../rom/rom_config.s

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

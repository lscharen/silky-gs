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
;
             <<<

; Pre-render check to see if there are any background tiles queued for updates.  If so, we will do
; a regular rendering.  If not, use dirty rendering.
PRE_RENDER   mac
;
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

; What kind of Nametable mirroring for this game
NAMETABLE_MIRRORING equ VERTICAL_MIRRORING

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
DIRECT_OAM_READ   equ 1

; Define a range of OAM entries to scan.  Many games do not use all 64
; sprite slots, so we can avoid doing unecessary work by only scanning
; OAM entries that may be on-screen
OAM_START_INDEX   equ 0     ; Should ignore sprite zero, but it's used on the title screen - ignore Tile Index $FF instead
OAM_END_INDEX     equ 64

; Allow the engine to use dirty rendering (drawing only lines where sprites
; have changed) if the background did not scroll compared to the previous frame
ENABLE_DIRTY_RENDERING equ 0

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP  equ 0

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.
NO_INTERRUPTS     equ 1

; Flag to turn off the configuration support
NO_CONFIG         equ 0

; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ PALETTE_DISPATCH

; Turn on code that visualizes the CPU time used by the ROM code
SHOW_ROM_EXECUTION_TIME equ 0

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Game has two scroll positions for split scroll
;
; ram_scroll_X / ram_scroll_Y plus ram_for_2000 | ram_004D_base_nametable ($12, $13))
; ram_0050_scroll_X / ram_0050_scroll_Y plus ram_for_2000 | ram_004E_base_nametable ($50, $51)
; sub_D1A9 - sets to 0,0
; sub_D3C1 - sets to 0,0
;
; Provide alternative ways of locking in the scroll and ppu control values after a frame
CUSTOM_PPU_CTRL_LOCK equ 0
CUSTOM_PPU_SCROLL_LOCK equ 1

CUSTOM_PPU_CTRL_LOCK_CODE mac
;
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
                          ldal $010050
                          sta  _topscroll
                          ldal $010012
                          xba
                          <<<

COMPILED_SPRITE_LIST_COUNT equ 0
COMPILED_SPRITE_LIST       mac
;
                           <<<

; Do we have a custom routine to execite RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 1
CUSTOM_RENDER_SCREEN_ADDR equ _RenderScreen

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 3   ; Ideally make this 2 for the title screen and 3 for the gameplay
y_height_rows equ 25
y_ending_row  equ {y_offset_rows+y_height_rows}

y_offset      equ {y_offset_rows*8}
y_height      equ {y_height_rows*8}
min_nes_y     equ y_offset
max_nes_y     equ min_nes_y+y_height

x_offset      equ 16                      ; number of bytes from the left edge

            phk
            plb

; Call startup immediately after entering the application: A = memory manager user ID

            jsr   NES_StartUp

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Call the boot code in the ROM

            jsr   NES_ColdBoot

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

InitPlayfield
            ldx   #TitleScreen
            lda   #0
            jsr   NES_SetPalette
            rts

ConfScrnPal
TitleScreen  dw    $02,$0F,$30,$21
             dw    $15,$02,$2A,$3C
             dw    $27,$20,$16,$13
             dw    $2C,$08,$0F,$0F

; When the NES ROM code tried to write to the PPU palette space, intercept here.
PALETTE_DISPATCH
        dw   ppu_3F00,ppu_3F01,ppu_3F02,ppu_3F03
        dw   ppu_3F04,ppu_3F05,ppu_3F06,ppu_3F07
        dw   ppu_3F08,ppu_3F09,ppu_3F0A,ppu_3F0B
        dw   ppu_3F0C,ppu_3F0D,ppu_3F0E,ppu_3F0F

        dw   ppu_3F10,ppu_3F11,ppu_3F12,ppu_3F13
        dw   ppu_3F14,ppu_3F15,ppu_3F16,ppu_3F17
        dw   ppu_3F18,ppu_3F19,ppu_3F1A,ppu_3F1B
        dw   ppu_3F1C,ppu_3F1D,ppu_3F1E,ppu_3F1F

; Make the screen appear
_topscroll      ds 2
_top_bg_x       ds 2
nesCrowdOffset  ds 2
nesTopOffset    ds 2
nesBottomOffset ds 2
_RenderScreen

; If we are not in-game, defer to the standard renderer

;            ldal  $010047
;            and   #$00FF
;            bne   :racing
;            jmp   RenderScreen

:racing
; Do the basic setup
;
; ram_004E_base_nametable is for the crowd offset
; ram_004D_base_nametable is for the track offset

            sep   #$20
;            lda   _ppuctrl                ; Bit 0 is the high bit of the X scroll position
            ldal  $01004D
            lsr                           ; put in the carry bit
            lda   _ppuscroll+1            ; load the scroll value
            ror                           ; put the high bit and divide by 2 for the engine
            rep   #$20
            and   #$00FF                  ; make sure nothing is in the high byte
            jsr   _SetBG0XPos

            sep   #$20
            ldal  $01004E                ; Bit 0 is the high bit of the X scroll position
            lsr                           ; put in the carry bit
            lda   _topscroll              ; load the scroll value
            ror                           ; put the high bit and divide by 2 for the engine
            rep   #$20
            and   #$00FF                  ; make sure nothing is in the high byte
            sta   _top_bg_x

            lda   #y_offset
            jsr   _SetBG0YPos

            lda   ppumask
            and   ppumask_override
            and   #NES_PPUMASK_BG
            jsr   EnableBackground

            lda   ppumask
            and   ppumask_override
            and   #NES_PPUMASK_SPR
            jsr   EnableSprites

; Lock in the verical position

            jsr   _ApplyBG0YPosPreLite
            jsr   _ApplyBG0YPosLite       ; Set up the code field

; First, render the crowd (40 scanlines)

            lda   #{y_offset*2}
            sta   tmp1                ; virt_line_x2
            lda   #40*2
            sta   tmp2                ; lines_left_x2
            lda   _top_bg_x           ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesCrowdOffset

; Next render top part of the screen to move with the player

            lda   #{y_offset+40}*2
            sta   tmp1                ; virt_line_x2
            lda   #{200-32-40}*2
            sta   tmp2                ; lines_left_x2
            lda   StartX              ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesTopOffset

; Now render the bottom 32 lines to show the status bar area

            lda   #{y_offset+200-32}*2
            sta   tmp1                    ; virt_line_x2
            lda   #{32*2}
            sta   tmp2                    ; lines_left_x2
            lda   #0                      ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesBottomOffset            ; cache the :exit_offset value returned from this function

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen

; Restore the buffer

            lda   #y_offset               ; virt_line
            ldx   #40                     ; lines_left
            ldy   nesCrowdOffset          ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            lda   #y_offset+40            ; virt_line
            ldx   #{200-32-40}            ; lines_left
            ldy   nesTopOffset            ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            lda   #{y_offset+200-32}      ; virt_line
            ldx   #32                     ; lines_left
            ldy   nesBottomOffset         ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

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

            lda   InputPlayer1
            ldx   #8*160
            ldy   #$FFFF
            jsr   DrawWord

            lda   LastRead
            ldx   #16*160
            ldy   #$FFFF
            jsr   DrawWord
            FIN

            stz   DirtyBits
            rts

; For this game, we utilize a single, static palette
SetDefaultPalette

; Set the tile/sprite mapping

            lda   SwizzleTables+2
            ldx   SwizzleTables
            jsr   NES_SetPaletteMap
            rts

SwizzleTables adrl L1_T0

; ApplyConfig
;
; Read the variabled set up the configuration screen and apply them to the runtime engine.
ApplyConfig
            lda   config_video_fastmode
            beq   :normal_video
            lda   #CTRL_EVEN_RENDER
            tsb   GTEControlBits
            bra   :apply_video
:normal_video
            lda   #CTRL_EVEN_RENDER
            trb   GTEControlBits
:apply_video
            lda   #0
            jsr   FillScreen
            jsr   _InitRenderMode

            lda   config_audio_quality
            jsr   APUReload

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

config_audio_quality   dw  APU_60HZ  ; good / better / best audio quality (60Hz, 120Hz, 240Hz audio interrupts)
config_video_statusbar dw  1         ; exclude the status bar from the animate playfield area or not
config_video_fastmode  ds  2         ; use the "skip line" rendering mode
config_input_p1_type   dw  0         ; keyboard / snes max
config_input_key_left  dw  LEFT_ARROW
config_input_key_right dw  RIGHT_ARROW
config_input_key_up    dw  UP_ARROW
config_input_key_down  dw  DOWN_ARROW
config_input_snesmax_port dw 4

CONFIG_PALETTE       equ 0
TILE_TOP_LEFT        equ $105
TILE_TOP_RIGHT       equ $106
TILE_BOTTOM_LEFT     equ $107
TILE_BOTTOM_RIGHT    equ $108
TILE_HORIZONTAL      equ $10A
TILE_HORIZONTAL_TOP  equ $10A
TILE_HORIZONTAL_BOTTOM  equ $10A
TILE_VERTICAL_LEFT   equ $10E
TILE_VERTICAL_RIGHT  equ $10D
TILE_ZERO            equ $100
TILE_A               equ $12E
TILE_SPACE           equ $100
TILE_CURSOR          equ $149  ; $10A

AUDIO_TITLE_STR     str 'AUDIO'
AUDIO_QUALITY_STR   str 'QUALITY'
AUDIO_QUALITY_60HZ  str ' 60 HZ'
AUDIO_QUALITY_120HZ str '120 HZ'
AUDIO_QUALITY_240HZ str '240 HZ'

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
INPUT_SNESMAX_PORT_STR str 'SLOT'

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
CONFIG_MENU  dw   3                     ; Four screens "Audio", "Video", "Input", "Game"
             dw   AUDIO_CONFIG
             dw   VIDEO_CONFIG
             dw   INPUT_CONFIG

AUDIO_CONFIG dw   AUDIO_TITLE_STR
             dw   0                     ; previous menu item
             dw   VIDEO_CONFIG          ; next menu item

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

INPUT_CONFIG dw   INPUT_TITLE_STR
             dw   VIDEO_CONFIG          ; previous menu item
             dw   0                     ; next menu item

             dw   1
             dw   INPUT_ITEM_1

INPUT_ITEM_1 dw   RADIO
             dw   0
             dw   0                    ; No NEXT defined, use the selected item
             dw   3,2
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
              dw  3,8
              dw  INPUT_SNESMAX_PORT_STR
              dw  config_input_snesmax_port

              dw  1            ; minimum value
              dw  7            ; maximum value

KEYBOARD_LIST dw  CTRL_LIST
              dw  4
              dw  INPUT_ITEM_2
              dw  INPUT_ITEM_3
              dw  INPUT_ITEM_4
              dw  INPUT_ITEM_5

INPUT_ITEM_2 dw   KEYMAP
             dw   INPUT_ITEM_1
             dw   INPUT_ITEM_3
             dw   3,8
             dw   INPUT_LEFT_MAP_STR
             dw   config_input_key_left

INPUT_ITEM_3 dw   KEYMAP
             dw   INPUT_ITEM_2
             dw   INPUT_ITEM_4
             dw   3,9
             dw   INPUT_RIGHT_MAP_STR
             dw   config_input_key_right

INPUT_ITEM_4 dw   KEYMAP
             dw   INPUT_ITEM_3
             dw   INPUT_ITEM_5
             dw   3,10
             dw   INPUT_UP_MAP_STR
             dw   config_input_key_up

INPUT_ITEM_5 dw   KEYMAP
             dw   INPUT_ITEM_4
             dw   0
             dw   3,11
             dw   INPUT_DOWN_MAP_STR
             dw   config_input_key_down

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
            put   ../../core/sprites/CompileSprites.s

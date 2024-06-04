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

EVT_LOOP_END mac
;
             <<<

PRE_RENDER   mac
;
             <<<

POST_RENDER  mac
             jsr  CheckForPaletteChange
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
ROM_DRIVER_MODE   equ 0

; Flag whether the backend should use the OAMDMA to get the sprite information,
; or if it can scan the NES RAM area directly
;
; 0  = use OAM DMA
; >0 = read $100 bytes directly from NES RAM
DIRECT_OAM_READ   equ $0200

; Flag whether to ignore Sprite 0.  Somce games use this sprite only for the 
; special sprite 0 collision behavior, which is not supported in this runtime
ALLOW_SPRITE_0    equ 0

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP equ 1

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.
NO_INTERRUPTS     equ 0

; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ SMB_PALETTE_DISPATCH

; Turn on code that visualizes the CPU time used by the ROM code
SHOW_ROM_EXECUTION_TIME equ 0

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Provide alternative ways of locking in the scroll and ppu control values after a frame
CUSTOM_PPU_CTRL_LOCK equ 1
CUSTOM_PPU_SCROLL_LOCK equ 1

;Mirror_PPU_CTRL_REG1  = $0778
;HorizontalScroll      = $073f
;VerticalScroll        = $0740
CUSTOM_PPU_CTRL_LOCK_CODE mac
                          ldal ROMBase+$0778
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
                          ldal ROMBase+$073f
                          xba
                          <<<

; Define a list of sprites that should be compiled (must be in order and the tile address offset (x16))
COMPILED_SPRITE_LIST_COUNT equ 4
COMPILED_SPRITE_LIST       mac
                           dw  $70*16,$71*16,$72*16,$73*16     ; goombas
                           <<<

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 2
y_height_rows equ 25
y_ending_row  equ {y_offset_rows+y_height_rows}

y_offset    equ {y_offset_rows*8}
y_height    equ {y_height_rows*8}
min_nes_y   equ 16
max_nes_y   equ min_nes_y+y_height

x_offset    equ   16                      ; number of bytes from the left edge

            phk
            plb

            jsr   NES_StartUp

            stz   LastAreaType            ; Check if the palettes need to be updates

; Set the palettes and swizzle tables

            jsr   SetDefaultPalette

; Show the configuration screen

;            ldx   #CONFIG_BLK
;            jsr   ShowConfig
;            bcc   *+5
;            jmp   quit
;            jsr   ApplyConfig

; Start the FPS counter
            ldal  OneSecondCounter
            sta   OldOneSec

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
; Call the boot code in the ROM

            jsr   NES_ColdBoot

; Apply hacks
;WorldNumber           = $075f
;LevelNumber           = $075c
;AreaNumber            = $0760
ContinueWorld         = $07fd
;OffScr_WorldNumber    = $0766
;OffScr_AreaNumber     = $0767
;OffScr_LevelNumber    = $0763
ContinueArea          = $7E00   ; patches operand

; We _never_ scroll vertically, so just set it once.  This is to make sure these kinds of optimizations
; can be set up in the generic structure

            lda   #16
            jsr   _SetBG0YPos
            jsr   _ApplyBG0YPosPreLite
            jsr   _ApplyBG0YPosLite       ; Set up the code field

; Start up the NES
:start
; Hack for testing
            sep   #$20
            lda   #3
            stal  ROMBase+ContinueWorld
            lda   #1
            stal  ROMBase+ContinueArea
            rep   #$20

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

; Helper to initialize the playfield based on the selected VideoMode
InitPlayfield
            lda   #16            ; We render starting at line 16 in the NES video buffer
            sta   NesTop

;            lda   VideoMode
;            cmp   #0
;            beq   :good
;            cmp   #2
;            beq   :better

            lda   #0
            sta   MinYScroll

            lda   #200
            sta   ScreenHeight
            bra   :common

:better
            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
            sta   MinYScroll

            lda   #160           ; 160 lines high for 'better'
            sta   ScreenHeight
            bra   :common

:good
            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
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

            ldx   #Area1Palette
            lda   #TmpPalette
            jsr   NES_PaletteToIIgs

            lda   #0
            ldx   #TmpPalette
            jsr   _SetPalette

            rts

; When the NES ROM code tried to write to the PPU palette space, intercept here.
;
; Based on the palette data that SMB uses, we remap the NES palette entries
; based on the AreaType, so most of the PPU writes are ignored.  However,
; we do update some specific palette entries to support some color cycling effects
;
; BG0,0 maps to IIgs Palette index 0    (Background color)
; BG3,1 maps to IIgs Palette index 1    (Color cycle for blocks)
; SP0,1 maps to IIgs Palette index 14   (Player primary color; changes with fire flower)
; SP0,3 maps to IIgs Palette index 15   (Player primary color; changes with fire flower)

SMB_PALETTE_DISPATCH
        dw   ppu_3F00,ppu_3F01,ppu_3F02,ppu_3F03
        dw   ppu_3F04,ppu_3F05,ppu_3F06,ppu_3F07
        dw   ppu_3F08,ppu_3F09,ppu_3F0A,ppu_3F0B
        dw   ppu_3F0C,SMB_3F0D,ppu_3F0E,ppu_3F0F
        dw   ppu_3F10,SMB_3F11,ppu_3F12,SMB_3F13
        dw   ppu_3F14,SMB_3F15,SMB_3F16,SMB_3F17
        dw   ppu_3F18,ppu_3F19,ppu_3F1A,ppu_3F1B
        dw   ppu_3F1C,ppu_3F1D,ppu_3F1E,ppu_3F1F

; Tile palette 3, color 1
SMB_3F0D    ldal PPU_MEM+$3F0D
            jsr  NES_ColorToIIgs
            stal $E19E02
            rts

; Sprite Palette 0, color 1
SMB_3F11    ldal PPU_MEM+$3F11
            jsr  NES_ColorToIIgs
            stal $E19E00+28
            rts

; Sprite Palette 0, color 3
SMB_3F13    ldal PPU_MEM+$3F13
            jsr  NES_ColorToIIgs
            stal $E19E00+30
            rts

; Allow the second sprite palette to be set by the ROM in world *-4 because it switches to the bowser
; palette when player reaches the end of the level.  Mapped to IIgs palette indices 8, 9, 10
CASTLE_AREA_TYPE equ 3
SMB_3F15
            lda  LastAreaType
            cmp  #CASTLE_AREA_TYPE
            bne  :no_change

            ldal PPU_MEM+$3F15
            jsr  NES_ColorToIIgs
            stal $E19E00+{8*2}
:no_change  rts

SMB_3F16
            lda  LastAreaType
            cmp  #CASTLE_AREA_TYPE
            bne  :no_change

            ldal PPU_MEM+$3F16
            jsr  NES_ColorToIIgs
            stal $E19E00+{9*2}
:no_change  rts

SMB_3F17
            lda  LastAreaType
            cmp  #CASTLE_AREA_TYPE
            bne  :no_change

            ldal PPU_MEM+$3F17
            jsr  NES_ColorToIIgs
            stal $E19E00+{10*2}
:no_change  rts

; Check the AreaType and see if the palette needs to be changed. We do this after the screen is blitted
; so the palette does not get changed too early while old pixels are still on the screen.

CheckForPaletteChange
            ldal  ROMBase+$074E
            and   #$0003                  ; There are four area types
            cmp   LastAreaType            ;   order is WaterPaletteData, <GroundPaletteData, <UndergroundPaletteData, <CastlePaletteData
            beq   :no_area_change
            sta   LastAreaType
            jsr   SetAreaPalette
:no_area_change
            rts

; Make the screen appear
nesTopOffset    ds 2
nesBottomOffset ds 2
RenderScreen

; Do the basic setup

            sep   #$20
            lda   _ppuctrl                ; Bit 0 is the high bit of the X scroll position
            lsr                           ; put in the carry bit
            lda   _ppuscroll+1            ; load the scroll value
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

; Now render the top 16 lines to show the status bar area

            clc
            lda   #16*2
            sta   tmp1                    ; virt_line_x2
            lda   #16*2
            sta   tmp2                    ; lines_left_x2
            lda   #0                      ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesTopOffset            ; cache the :exit_offset value returned from this function

; Next render the remaining lines

            lda   #32*2
            sta   tmp1                ; virt_line_x2
            lda   ScreenHeight
            sec
            sbc   #16
            asl
            sta   tmp2                ; lines_left_x2
            lda   StartX              ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesBottomOffset

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen

; Restore the buffer

            lda   #16                     ; virt_line
            ldx   #16                     ; lines_left
            ldy   nesTopOffset            ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            lda   ScreenHeight
            sec
            sbc   #16
            tax                           ; lines_left
            lda   #32                     ; virt_line
            ldy   nesBottomOffset         ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            DO    SHOW_DEBUG_VARS
            lda   InputPlayer1
            ldx   #8*160
            ldy   #$FFFF
            jsr   DrawWord
            FIN

            stz   DirtyBits
;            stz   LastPatchOffset
            rts

SetDefaultPalette
            lda   #0
SetAreaPalette
            cmp   #5
            bcs   :out

            asl
            tay
            ldx   AreaPalettes,y      ; First parameter to NESColorToIIgs
            phx

            asl
            tay
            lda   SwizzleTables+2,y
            ldx   SwizzleTables,y
            jsr   NES_SetPaletteMap
            
            plx
            lda   #TmpPalette
            jsr   NES_PaletteToIIgs

; Special copy routine; do not touch color indices 0, 1, 14 or 15 -- we let the NES PPU handle those

            ldx   #4
:loop
            lda   TmpPalette,x
            stal  $E19E00,x
            inx
            inx
            cpx   #2*14
            bcc   :loop
:out
            rts

AreaPalettes  dw   WaterPalette,Area1Palette,Area2Palette,Area3Palette,Area2Palette
SwizzleTables adrl AT0_T0,AT1_T0,AT2_T0,AT3_T0,AT2_T0

; ApplyConfig
;
; Read the variables set up the configuration screen and apply them to the runtime engine.
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
            rts

; Copy just the tiles that change directly to the graphics screen

MemOffsets    dw    67, 68, 69, 70, 71,                        82, 83, 84, 85, 86,  89, 90, 91, 92
              dw    99,100,101,102,103,104,  107,108,109,110,     115,116,117,         122,123,124

ScreenOffsets dw    12, 16, 20, 24, 28,                        72, 76, 80, 84, 88,  100,104,108,112
              dw    ROW_STEP+12,ROW_STEP+16,ROW_STEP+20,ROW_STEP+24,ROW_STEP+28,ROW_STEP+32
              dw    ROW_STEP+44,ROW_STEP+48,ROW_STEP+52,ROW_STEP+56
              dw    ROW_STEP+76,ROW_STEP+80,ROW_STEP+84
              dw    ROW_STEP+104,ROW_STEP+108,ROW_STEP+112

CopyStatusToScreen

            lda   ScreenBase
            sec
            sbc   #160*16
            sta   tmp0

            ldy   #0
:loop
            phy                             ; preserve reg
            ldx   MemOffsets,y
            ldal  PPU_MEM+TILE_SHADOW,x
;            and   #$00FF
;            ora   #$0100+TILE_USER_BIT
;            pha

            lda   ScreenOffsets,y
            clc
            adc   tmp0
;            pha

            lda   #$8002
            cpx   #107                      ; This one is palette 3
            bne   *+5
            ora   #$0001
;            pha
;            _GTEDrawTileToScreen           ; call NESTileBlitter

            ply
            iny
            iny
            cpy   #30*2
            bcc   :loop
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
config_video_small     ds  2  ; use a smaller playfield screen size
config_input_p1_type   dw  0  ; keyboard  / snes max
config_input_key_left  dw  LEFT_ARROW
config_input_key_right dw  RIGHT_ARROW
config_input_key_up    dw  UP_ARROW
config_input_key_down  dw  DOWN_ARROW
config_input_snesmax_port dw 4

CONFIG_PALETTE      equ 1
TILE_TOP_LEFT       equ $144
TILE_TOP_RIGHT      equ $149
TILE_BOTTOM_LEFT    equ $15F
TILE_BOTTOM_RIGHT   equ $17A
TILE_HORIZONTAL_TOP equ $148
TILE_HORIZONTAL_BOTTOM equ $178
TILE_VERTICAL_LEFT  equ $146
TILE_VERTICAL_RIGHT equ $14A
TILE_ZERO           equ $100
TILE_A              equ $10A
TILE_SPACE          equ $124
TILE_CURSOR         equ $1CE

AUDIO_TITLE_STR     str 'AUDIO'
AUDIO_QUALITY_STR   str 'QUALITY'
AUDIO_QUALITY_60HZ  str ' 60 HZ'
AUDIO_QUALITY_120HZ str '120 HZ'
AUDIO_QUALITY_240HZ str '240 HZ'

VIDEO_TITLE_STR      str 'VIDEO'
VIDEO_FASTMODE_STR   str 'FAST BLIT'
VIDEO_STATUS_BAR_STR str 'STATUS BAR'
VIDEO_SMALL_STR      str 'SMALL SCRN'

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
CONFIG_MENU  dw   3                     ; Four screens "Audio", "Video", "Input"
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
             dw   config_audio_quality  ; Memory address to write the configuration value (set to zero if not saved)
             dw   3                     ; Three options

             dw   APU_60HZ              ; config value
             dw   AUDIO_QUALITY_60HZ    ; config label
             dw   0                     ; conditional control (if null, nothing)

             dw   APU_120HZ
             dw   AUDIO_QUALITY_120HZ
             dw   0                     ; conditional control (if null, nothing)

             dw   APU_240HZ
             dw   AUDIO_QUALITY_240HZ
             dw   0                     ; conditional control (if null, nothing)

VIDEO_CONFIG dw   VIDEO_TITLE_STR
             dw   AUDIO_CONFIG          ; previous menu item
             dw   INPUT_CONFIG          ; next menu item

             dw   3                     ; Two configuration elements
             dw   VIDEO_ITEM_1
             dw   VIDEO_ITEM_2
             dw   VIDEO_ITEM_3

VIDEO_ITEM_1 dw   CHKBOX                ; Checkbox just forces a 0/1 for False/True
             dw   0                     ; previous control
             dw   VIDEO_ITEM_2          ; next control
             dw   3,2
             dw   VIDEO_STATUS_BAR_STR
             dw   config_video_statusbar

VIDEO_ITEM_2 dw   CHKBOX
             dw   VIDEO_ITEM_1          ; previous control
             dw   VIDEO_ITEM_3          ; next control
             dw   3,4
             dw   VIDEO_FASTMODE_STR
             dw   config_video_fastmode

VIDEO_ITEM_3 dw   CHKBOX
             dw   VIDEO_ITEM_2          ; previous control
             dw   0                     ; next control
             dw   3,6
             dw   VIDEO_SMALL_STR
             dw   config_video_small

INPUT_CONFIG dw   INPUT_TITLE_STR
             dw   VIDEO_CONFIG          ; previous menu item
             dw   0                     ; next menu item

             dw   1
             dw   INPUT_ITEM_1

INPUT_ITEM_1 dw   RADIO
             dw   0
             dw   0
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

            ds    \,$00                      ; pad to the next page boundary

; Mapping tables to take a nametable address and return the appropriate attribute memory location.  This is a table with
; 960 entries.  This table is just the 64 offsets above address $2xC0 stored as bytes to keep the table size reasonably
; conpact
PPU_ATTR_ADDR
]row        =     0
            lup   30
            db    $C0+{8*{]row/4}}+0, $C0+{8*{]row/4}}+0, $C0+{8*{]row/4}}+0, $C0+{8*{]row/4}}+0, $C0+{8*{]row/4}}+1, $C0+{8*{]row/4}}+1, $C0+{8*{]row/4}}+1, $C0+{8*{]row/4}}+1,
            db    $C0+{8*{]row/4}}+2, $C0+{8*{]row/4}}+2, $C0+{8*{]row/4}}+2, $C0+{8*{]row/4}}+2, $C0+{8*{]row/4}}+3, $C0+{8*{]row/4}}+3, $C0+{8*{]row/4}}+3, $C0+{8*{]row/4}}+3,
            db    $C0+{8*{]row/4}}+4, $C0+{8*{]row/4}}+4, $C0+{8*{]row/4}}+4, $C0+{8*{]row/4}}+4, $C0+{8*{]row/4}}+5, $C0+{8*{]row/4}}+5, $C0+{8*{]row/4}}+5, $C0+{8*{]row/4}}+5,
            db    $C0+{8*{]row/4}}+6, $C0+{8*{]row/4}}+6, $C0+{8*{]row/4}}+6, $C0+{8*{]row/4}}+6, $C0+{8*{]row/4}}+7, $C0+{8*{]row/4}}+7, $C0+{8*{]row/4}}+7, $C0+{8*{]row/4}}+7,
]row        =     ]row+1
            --^
            
PPU_ATTR_MASK
            lup   7
            db    $03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C
            db    $03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C
            db    $30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0
            db    $30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0
            --^
            db    $03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C
            db    $03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C

; Palette for the configuration screen
ConfScrnPal  dw     $0F, $00, $29, $1A, $0F, $36, $17, $30, $21, $27, $1A, $16, $00, $00, $16, $18

; If AreaStyle is 1 then load an alternate palette 'b'
;
; Palettes of NES color indexes
Area1Palette dw     $22, $00, $29, $1A, $0F, $36, $17, $30, $21, $27, $1A, $16, $00, $00, $16, $18

; Underground
Area2Palette dw     $0F, $00, $29, $1A, $09, $3C, $1C, $30, $21, $17, $27, $36, $16, $1D, $16, $18

; Castle
Area3Palette dw     $0F, $00, $30, $10, $00, $16, $17, $27, $1C, $36, $1D, $00, $00, $00, $16, $18

; Water
WaterPalette dw     $22, $00, $15, $12, $25, $3A, $1A, $0F, $30, $12, $27, $10, $16, $00, $16, $18

; Palette remapping
            put   pal_w11.s
            put   ../../apu/apu.s

; Core code
            put   ../../rom/scaffold.s
            put   ../../rom/rom_helpers.s
            put   ../../rom/rom_input.s
            put   ../../rom/rom_exec.s
            put   ../../rom/rom_config.s

            put   ../../core/CoreData.s
            put   ../../core/CoreImpl.s
            put   ../../core/ControlBits.s
            put   ../../core/Memory.s
            put   ../../core/Graphics.s
            put   ../../core/Math.s
            put   ../../core/blitter/BlitterLite.s
            put   ../../core/blitter/PEISlammer.s
            put   ../../core/blitter/HorzLite.s
            put   ../../core/blitter/VertLite.s
            put   ../../core/tiles/CompileTile.s
            put   ../../core/sprites/CompileSprites.s

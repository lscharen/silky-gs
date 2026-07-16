            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   ../../../Externals.s
            put   ../../../core/Defs.s

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
             jsr  ApplyMirrorMode   ; finish any mirroring-mode change requested since the last frame
             <<<

POST_RENDER  mac
;
             <<<

; Put in additional conditions to skip sprites when scanning the OAM table to decide what to
; render.  Set the carry flag to keep, clear the carry flag to skip
;
; Input: The accumulator holds the first two OAM bytes (y-position and tile id)
SCAN_OAM_XTRA_FILTER mac
            sec               ; pass everything
            <<<

; Define which PPU address has the background and sprite tiles
;
; Zelda uses CHR-RAM (tiles uploaded dynamically via PPUDATA writes into
; $0000-$1FFF), not fixed CHR-ROM -- see HAS_CHR_RAM below. These addresses
; still matter: they say which 4KB half of CHR-RAM is background vs sprite,
; used both by PPUDATA_WRITE's dirty-marking and by the on-demand tile
; recompilation at draw time.
PPU_BG_TILE_ADDR  equ $1000
PPU_SPR_TILE_ADDR equ $0000

; This game uploads its own CHR data at runtime rather than using a fixed
; CHR-ROM image -- see MarkTileDirty (ppu_regs.s), DrawPPUTile
; (ppu_attributes.s), CheckSprTileDirty (ppu.s), and NES_StartUp (scaffold.s).
HAS_CHR_RAM equ 1

; TODO-DEFERRED: Zelda switches nametable mirroring at runtime (vertical for
; some rooms, horizontal for others -- see SetMMC1Control call sites in the
; disassembly). This engine only supports a compile-time mirroring choice
; (6 DO/ELSE sites across ppu_regs.s/ppu_init.s/Memory.s/CoreImpl.s/
; HorzLite.s). Horizontal is Zelda's default/most common mode; runtime
; switching is deferred follow-up work.
NAMETABLE_MIRRORING equ HORIZONTAL_MIRRORING

; Flag if the NES_StartUp code should keep a spriteable bitmap copy of the background tiles,
; in addition to the compiled representation (usually yes, since this is used for the config
; screen)
BG_TILES_AS_SPRITES equ 1

; Define what kind of execution harness to use
;
; 0 = Reset code drops into an infinite loop
; 1 = Reset code is the game code
ROM_DRIVER_MODE   equ 0

; MAME cycle-count benchmark harness flag (scripts/run-bench.js) -- see
; src/games/smb/Main.s for details. Always 0 here; rom_input.s is shared
; across all games and must default to normal (non-bench) behavior.
BENCH_MODE        equ 0

; Flag whether the backend should use the OAMDMA to get the sprite information,
; or if it can scan the NES RAM area directly
;
; 0  = use OAM DMA
; >0 = read $100 bytes directly from NES RAM at this address (typically $200)
DIRECT_OAM_READ   equ $200

; Define a range of OAM entries to scan.  Many games do not use all 64
; sprite slots, so we can avoid doing unecessary work by only scanning
; OAM entries that may be on-screen
OAM_START_INDEX   equ 0
OAM_END_INDEX     equ 64

; Allow the engine to use dirty rendering (drawing only lines where sprites
; have changed) if the background did not scroll compared to the previous frame
ENABLE_DIRTY_RENDERING equ 0

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP  equ 1

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.
NO_INTERRUPTS     equ 1

; Flag to turn off the configuration support
NO_CONFIG         equ 1

; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ PALETTE_DISPATCH
AUTOMATIC_PALETTE_MAPPING equ 0

; Turn on code that visualizes the CPU time used by the ROM code
SHOW_ROM_EXECUTION_TIME equ 0

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Provide alternative ways of locking in the scroll and ppu control values after a frame
CUSTOM_PPU_CTRL_LOCK equ 0
CUSTOM_PPU_SCROLL_LOCK equ 0
CUSTOM_PPU_CTRL_LOCK_CODE mac
;
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
;
                          <<<

COMPILED_SPRITE_LIST_COUNT equ 0
COMPILED_SPRITE_LIST       mac
;
                           <<<

; Do not check for specific Tile IDs to exclude from drawing
NO_TILE_EXCLUDE equ 1

; Do we have a custom routine to execite RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 0

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 2
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

; The user has exited the runtime
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

TitleScreen  dw    $0F, $00, $10, $20, $0F, $00, $10, $20, $0F, $00, $10, $20, $0F, $00, $10, $20

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


; TODO-DEFERRED: placeholder static palette/swizzle mapping, copied from
; src/games/wumpus/palettes.s. Real Zelda palette handling depends on the
; CHR-RAM work deferred above.
SetDefaultPalette

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

            rep   #$30
            rts

; Configuration screen and variables (required even with NO_CONFIG set --
; scaffold.s references these unconditionally)
config_block_start

config_audio_quality   ds  2
config_video_statusbar dw  1
config_video_fastmode  ds  2
config_video_small     ds  2

; player 1 config block
config_block_p1
config_input_p1_type   dw  0
config_input_key_left  dw  LEFT_ARROW
config_input_key_right dw  RIGHT_ARROW
config_input_key_up    dw  UP_ARROW
config_input_key_down  dw  DOWN_ARROW
config_input_snesmax_port dw 4
config_input_button_a  dw  MOD_REG_COMMAND_DOWN
config_input_button_b  dw  MOD_REG_OPTION_DOWN

; player 2 config block (Zelda is single-player; kept only because
; core/CoreImpl.s unconditionally references config_block_p2)
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

            mput  ../../../ppu
            put    ../../../ppu/ppu_macros.s
            put    ../../../ppu/ppu_init.s
            put    ../../../ppu/ppu_shadowlist.s
            put    ../../../ppu/ppu.s
            put    ../../../ppu/ppu_attributes.s
            put    ../../../ppu/ppu_tiles.s
            put    ../../../ppu/ppu_metatiles.s
            put    ../../../ppu/ppu_nametable.s
            put    ../../../ppu/ppu_queues.s
            put    ../../../ppu/ppu_palette.s
            put    ../../../ppu/ppu_regs.s
            put    ../../../ppu/ppu_render.s
            put    ../../../ppu/ppu_sprites.s
            put    ../../../ppu/ppu_tile_blitters.s
            put    ../../../ppu/scanline_bitmap.s

; Palette remapping
            put   palettes.s
            put   ../../../apu/apu.s

; Core code
            put   ../../../rom/scaffold.s
            put   ../../../rom/rom_color.s
            put   ../../../rom/rom_helpers.s
            put   ../../../rom/rom_input.s
            put   ../../../rom/rom_exec.s
            put   ../../../rom/rom_config.s

            put   ../../../core/ControlBits.s
            put   ../../../core/CoreData.s
            put   ../../../core/CoreImpl.s
            put   ../../../core/Graphics.s
            put   ../../../core/Math.s
            put   ../../../core/Memory.s
            put   ../../../core/blitter/BlitterLite.s
            put   ../../../core/blitter/PEISlammer.s
            put   ../../../core/blitter/HorzLite.s
            put   ../../../core/blitter/VertLite.s
            put   ../../../core/tiles/CompileTile.s
            put   ../../../core/sprites/CompileSprites.s

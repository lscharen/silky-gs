            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   ../../Externals.s
L0_T0       EXT                       ; Swizzle tables live in the PALDATA segment (palettes.s)
AT2_T0      EXT
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

; Callback before each sprite is set up and drawn (drawSprites, ppu.s): X = OAM index, ]1 = the
; sprite height (8 or 16), DBR = $01 (the shadow screen), 16-bit registers.  It can set sprClipTop to
; hide the sprite's top lines.
SPRITE_PRE_DRAW  mac
;
             <<<

; Non-zero if SPRITE_PRE_DRAW can set sprClipTop: the sprite renderer only tests it then
SPRITE_CLIP equ 0

; Define which PPU address has the background and sprite tiles
PPU_BG_TILE_ADDR  equ $1000
PPU_SPR_TILE_ADDR equ $0000

; Flag whether this game uploads its own CHR data at runtime (CHR-RAM) rather
; than using a fixed CHR-ROM image loaded once at startup
HAS_CHR_RAM equ 0

; No battery-backed WRAM to load and save (see HAS_BACKED_WRAM in scaffold.s)
HAS_BACKED_WRAM equ 0


; Flag if the NES_StartUp code should keep a spriteable bitmap copy of the background tiles,
; in addition to the compiled representation (usually yes)
BG_TILES_AS_SPRITES equ 1

; Define what kind of execution harness to use
;
; 0 = Reset code drops into an infinite loop
; 1 = Reset code is the game code
ROM_DRIVER_MODE   equ 1

; MAME cycle-count benchmark harness flag (scripts/run-bench.js) -- see
; src/games/smb/Main.s for details. Always 0 here; rom_input.s is shared
; across all games and must default to normal (non-bench) behavior.
BENCH_MODE        equ 0
BENCH_MODE_LEN    equ 4500            ; Frames in bench_input.bin

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

; Allow the engine to use dirty rendering (drawing only lines/blocks where sprites
; have changed) if the background did not scroll compared to the previous frame
ENABLE_DIRTY_RENDERING equ 1

; Use the screen-aligned 8x8 grid dirty renderer (erase from the PEA field, BG tile updates
; without a full refresh).  Requires ENABLE_DIRTY_RENDERING.  See BG_TILE_DIRTY_PLAN.md
GRID_DIRTY_RENDERING equ 1
GRID_MAX_BG_TILES    equ 64

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP  equ 0

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.
NO_INTERRUPTS     equ 0

; Flag to turn off the configuration support
NO_CONFIG         equ 0

; Decode the DMC samples listed in DMC_SAMPLE_LIST into DOC RAM at start-up (see apu/apu.s).
; 0 = decode each sample when the game plays it.
CACHE_DMC_SAMPLES equ 0

; Configuration screen setup (see rom/rom_config_setup.s)
CONFIG_DEFAULT_AUDIO equ APU_60HZ   ; default audio quality
CONFIG_VIDEO_MENU    equ 0          ; show the VIDEO menu
CONFIG_INPUT_BUTTONS equ 1          ; allow remapping the A/B buttons
CONFIG_INPUT_2P      equ 1          ; show P1/P2 tabs on the INPUT menu
CONFIG_GAME_MENU     equ 0          ; append a GAME_CONFIG menu defined by this file

; Callback after the configuration has been applied.  X = config_block_start, Y = config_game_start
CONFIG_APPLY_HOOK mac
;
             <<<

; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ PALETTE_DISPATCH
AUTOMATIC_PALETTE_MAPPING equ 0

; Turn on code that visualizes the CPU time used by the ROM code
SHOW_ROM_EXECUTION_TIME equ 0

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Show the number of VBLs each screen render takes at the top-left of the screen (debug)
RENDER_VBL_COUNT equ 0
; Show the renders per second (decimal) at the top-left of the screen
SHOW_FPS equ 0

; Provide alternative ways of locking in the scroll and ppu control values after a frame
CUSTOM_PPU_CTRL_LOCK equ 0
CUSTOM_PPU_SCROLL_LOCK equ 0
CUSTOM_PPU_CTRL_LOCK_CODE mac
;
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
;
                          <<<

; Mario occupies the first 48 sprite tiles
COMPILED_SPRITE_LIST_COUNT equ 108
COMPILED_SPRITE_LIST       mac
                           dw  $FFFF
                           <<<

; Do not check for specific Tile IDs to exclude from drawing
NO_TILE_EXCLUDE equ 1

; Do we have a custom routine to execute RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 0

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 3 
y_height_rows equ 25
y_ending_row  equ {y_offset_rows+y_height_rows}

y_offset      equ {y_offset_rows*8}
y_height      equ {y_height_rows*8}
min_nes_y     equ y_offset
max_nes_y     equ min_nes_y+y_height

x_offset      equ 16                      ; number of bytes from the left edge

            phk
            plb

; Call startup immediately after entering the application with the cartridge configuration

            tax                           ; X = memory manager user ID (passed in A by GS/OS)
            lda   #HORIZONTAL_MIRRORING    ; A = cartridge nametable mirroring at power on
            jsr   NES_StartUp

; This an NROM game, so all of the sprite and background tiles are static.  They have been
; converted into the runtime's internal representation by build.js and loaded into the tiledata
; bank, so all that's left is to compile them

            jsr   ROM_CompileBackgroundTiles    ; Compile the background tiles
            jsr   ROM_CompileSpriteTiles        ; Compile the COMPILED_SPRITE_LIST tiles

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Load in the game preferences (if they exist)

            jsr   LoadPrefData

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

; Save the user preferences

            jsr   SavePrefData

; Exit the application

        _QuitGS    qtRec
qtRec   adrl  $0000
        da    $00

            DO    BENCH_MODE
; Canned controller input for benchmarking, one byte per virtual NES frame in the
; A-B-Select-Start-Up-Down-Left-Right bit layout (see src/rom/rom_input.s)
;BenchInputIndex   dw    0
;BenchInputData
;            putbin bench_input.bin
            FIN

; Name of the save and preference files
SAVE_FILENAME strl '1/mb.sav'
PREF_FILENAME strl '1/mb.prefs'

InitPlayfield
        ldx   #AllColors
        lda   #0
        jsr   NES_SetPalette
        rts

SwizzleTables
        adrl L0_T0
        adrl  AT2_T0

; Are there less than 15 total color combos? Yes! This game can use a fixed palette
;                      1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
AllColors   dw     $0F,$06,$09,$12
            dw     $16,$18,$19,$25
            dw     $26,$27,$29,$2C
            dw     $30,$35,$3C,$37

; When the NES ROM code tried to write to the PPU palette space, intercept here.
PALETTE_DISPATCH
        dw   ppu_3F00,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F04,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F08,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F0C,dk_3Fxx,dk_3Fxx,dk_3Fxx

        dw   ppu_3F10,dk_3Fxx,dk_3Fxx,mb_3F13
        dw   ppu_3F14,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F18,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F1C,dk_3Fxx,dk_3Fxx,dk_3Fxx

; Watch this palette entry to determine when to swap swizzle tables
mb_3F13
        cmp   #$0035
        bne  :tbl2

        phd
        ldal  DPSave
        tcd
        lda   SwizzleTables+2          ; title screen palette
        ldx   SwizzleTables
        jsr   NES_SetPaletteMap

        lda   #DIRTY_BIT_PAL_CHANGE    ; this needs to be set when the background palettes are changed
        tsb   DirtyBits

        pld
        rts

:tbl2
        phd
        ldal  DPSave
        tcd
        lda   SwizzleTables+6          ; gameplay palette
        ldx   SwizzleTables+4
        jsr   NES_SetPaletteMap

        lda   #DIRTY_BIT_PAL_CHANGE
        tsb   DirtyBits

        pld
        rts

; The the phase changes, set a flag, but way for the transition time to drop below $70
; before applying the change.
;HasPaletteChange dw 0

; X = 2*nes_palette_index
dk_3Fxx
        rts
; Palette
;
; 0 = background
; 

; For this game, we utilize a single, static palette
SetDefaultPalette

; Set the tile/sprite mapping

        lda   SwizzleTables+2
        ldx   SwizzleTables
        jmp   NES_SetPaletteMap

; Game-specific configuration values, saved after the built-in values by misc/io.s.  The
; built-in values, menus and ApplyConfig are defined in rom/rom_config_setup.s
config_game_start
config_game_end

            DO    SHOW_DEBUG_VARS+RENDER_VBL_COUNT+SHOW_FPS ; debug text (DrawByte / DrawWord)
            put   ../../misc/App.Msg.s
            FIN
            put   ../../misc/io.s
            
            mput  ../../ppu
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            put    ../../ppu/ppu_macros.s
            put    ../../ppu/ppu_init.s
            put    ../../ppu/ppu_shadowlist.s
            put    ../../ppu/ppu.s
            put    ../../ppu/ppu_attributes.s
            put    ../../ppu/ppu_tiles.s
            put    ../../ppu/ppu_metatiles.s
            put    ../../ppu/ppu_nametable2.s
            put    ../../ppu/ppu_queues.s
            put    ../../ppu/ppu_palette.s
            put    ../../ppu/ppu_regs.s
            put    ../../ppu/ppu_render.s
            put    ../../ppu/ppu_grid.s
            put    ../../ppu/ppu_grid_quads.s
            put    ../../ppu/ppu_sprites.s
            put    ../../ppu/ppu_tile_blitters.s
            put    ../../ppu/scanline_bitmap.s
; AUTOINC:END

            put   ../../apu/apu.s

; Core code
            put   ../../rom/scaffold.s
            put   ../../rom/rom_color.s
            put   ../../rom/rom_tiles.s
            put   ../../rom/rom_helpers.s
            put   ../../rom/rom_input.s
            put   ../../rom/rom_exec.s
            put   ../../rom/rom_config.s
            put   ../../rom/rom_config_setup.s

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

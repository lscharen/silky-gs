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
             jsr  CheckForPaletteChange   ; Update the swizzle tables before drawing any tiles (cannot use tmp3 or tmp4)
             <<<

POST_RENDER  mac
;
             <<<

; Callback before each sprite is set up and drawn (drawSprites, ppu.s): X = OAM index, ]1 = the
; sprite height (8 or 16), DBR = the tiledata bank, 16-bit registers.  It can set sprClipTop to
; hide the sprite's top lines.
SPRITE_PRE_DRAW  mac
             <<<

; Define which PPU address has the background and sprite tiles
PPU_BG_TILE_ADDR  equ $1000
PPU_SPR_TILE_ADDR equ $0000

; Flag whether this game uploads its own CHR data at runtime (CHR-RAM) rather
; than using a fixed CHR-ROM image loaded once at startup
HAS_CHR_RAM equ 0

; No battery-backed WRAM to load and save (see HAS_BACKED_WRAM in scaffold.s)
HAS_BACKED_WRAM equ 0


; Flag if the NES_StartUp code should keep a spriteable bitmap copy of the background tiles,
; in addition to the compiled representation (usually yes, since this is used for the config
; screen)
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
CONFIG_INPUT_2P      equ 0          ; show P1/P2 tabs on the INPUT menu
CONFIG_GAME_MENU     equ 0          ; append a GAME_CONFIG menu defined by this file

; Callback after the configuration has been applied.  X = config_block_start, Y = config_game_start
CONFIG_APPLY_HOOK mac
;
             <<<

; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ PALETTE_DISPATCH
PPU_PALETTE_MAP equ dk_palette_map
AUTOMATIC_PALETTE_MAPPING equ 1

; Turn on code that visualizes the CPU time used by the ROM code
SHOW_ROM_EXECUTION_TIME equ 0

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Show the number of VBLs each screen render takes at the top-left of the screen (debug)
RENDER_VBL_COUNT equ 0

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
                           dw   246,247,248,249,250,251                 ; Hammer sprites
                           dw   252,253,254,255                         ; Oil barrel flames
                           dw   128,129,130,131,132,133,134,135         ; Rolling barrels 128 - 151
                           dw   136,137,138,139,140,141,142,143
                           dw   144,145,146,147,148,149,150,151
                           dw   213,214,215,216,217,218,219,220,221,222 ; Pauline
                           dw   152,153,154,155,156,157,158,159         ; Flame dude
                           dw   168,169,170,171,172,173,174,175
                           dw   0,1,2,3,4,5,6,7                         ; Mario ex death and ladder animation 0 - 47
                           dw   8,9,10,11,12,13,14,15
                           dw   16,17,18,19,20,21,22,23
                           dw   24,25,26,27,28,29,30,31
                           dw   32,33,34,35,36,37,38,39
                           dw   40,41,42,43,44,45,46,47
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

            jsr   ROM_CompileBackgroundTiles    ; Convert the background tiles (PPU:$1000) to compiled format
            jsr   ROM_CompileSpriteTiles        ; Convert the COMPILED_SPRITE_LIST tiles to compiled format

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Load in the game preferences (if they exist)

            jsr   LoadPrefData

; Call the boot code in the ROM

            jsr   NES_ColdBoot

; Load in the saved high score from disk

            ldx   #$0507                 ; Area of RAM to load into
            lda   #3                     ; Only three bytes
            jsr   LoadROMData

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

; Save the high score file

            ldx   #$0507                 ; Area of RAM to load into
            lda   #3                     ; Only three bytes
            jsr   SaveROMData

; Save the user preferences

            jsr   SavePrefData

; Exit the application

        _QuitGS    qtRec
qtRec   adrl  $0000
        da    $00

; Name of the save and preference files
SAVE_FILENAME strl '1/dk.sav'
PREF_FILENAME strl '1/dk.prefs'

InitPlayfield
        ldx   #AllColors
        lda   #0
        jsr   NES_SetPalette

; Initialize the reverse color map lookup since we will not allow the IIgs palette to change

        ldx  #0
:rloop
        lda  AllColors,x   
        asl
        tay
        txa
        sta  ReverseMap,y
        inx
        inx
        cpx  #32
        bcc  :rloop
        rts

SwizzleTables
            adrl L0_T0

; Are there less than 15 total color combos? Yes! This game can use a fixed palette
;                      1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
AllColors   dw     $0F,$02,$06,$12
            dw     $15,$16,$17,$24
            dw     $25,$27,$28,$2C
            dw     $30,$36,$37,$38

; When the NES ROM code tried to write to the PPU palette space, intercept here.
PALETTE_DISPATCH
        dw   ppu_3F00,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F04,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F08,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F0C,dk_3Fxx,dk_3Fxx,dk_3Fxx

        dw   ppu_3F10,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F14,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F18,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F1C,dk_3Fxx,dk_3Fxx,dk_3Fxx

dk_palette_map
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1
            dw    0,  1,  2,  3    ; donkey kong background tiles are mapped to fixed colors
            dw    0, -1, -1, -1

            dw    0,  4,  5,  6    ; jumpman is always set to his own colors
            dw    0, -1, -1, -1    ; everything else is dynamically assigned
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1

; The the phase changes, set a flag, but way for the transition time to drop below $70
; before applying the change.
HasPaletteChange dw 0

; X = 2*nes_palette_index
dk_3Fxx
        txy
        txa
        lsr
        tax

        ldal PPU_MEM+$3F00,x
        and  #$003F
        sta  nes_palette,y

        inc
        sta  HasPaletteChange

        rts

CheckForPaletteChange

        lda  HasPaletteChange
        bne  :update_palette
        rts

:update_palette
;       jsr  NES_BuildPalette         ; Create a mapping of the NES palette to the Apple IIgs palette
        jsr  NES_BuildStaticPalette    ; Create a mapping to a static list of colors

        ldy  #current
        lda  SwizzleTables
        ldx  SwizzleTables+2
        jsr  NES_BuildSwizzleTable

        clc
        ldy  #current+{4*2}
        lda  SwizzleTables
        adc  #$200
        ldx  SwizzleTables+2
        jsr  NES_BuildSwizzleTable

        clc
        ldy  #current+{8*2}
        lda  SwizzleTables
        adc  #$400
        ldx  SwizzleTables+2
        jsr  NES_BuildSwizzleTable

        clc
        ldy  #current+{12*2}
        lda  SwizzleTables
        adc  #$600
        ldx  SwizzleTables+2
        jsr  NES_BuildSwizzleTable

        clc
        ldy  #current+{16*2}
        lda  SwizzleTables
        adc  #$800
        ldx  SwizzleTables+2
        jsr  NES_BuildSwizzleTable

        clc
        ldy  #current+{20*2}
        lda  SwizzleTables
        adc  #$A00
        ldx  SwizzleTables+2
        jsr  NES_BuildSwizzleTable

        clc
        ldy  #current+{24*2}
        lda  SwizzleTables
        adc  #$C00
        ldx  SwizzleTables+2
        jsr  NES_BuildSwizzleTable

        clc
        ldy  #current+{28*2}
        lda  SwizzleTables
        adc  #$E00
        ldx  SwizzleTables+2
        jsr  NES_BuildSwizzleTable
        
        stz  HasPaletteChange

;        jsr  ForceMetatileRefresh     ; Repaint the scene
;        jsr  RenderScreen

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
        jsr   NES_SetPaletteMap
        rts

; Game-specific configuration values, saved after the built-in values by misc/io.s.  The
; built-in values, menus and ApplyConfig are defined in rom/rom_config_setup.s
config_game_start
config_game_end

            DO    SHOW_DEBUG_VARS+RENDER_VBL_COUNT    ; debug text (DrawByte / DrawWord)
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
            mput  ../../rom
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            put    ../../rom/scaffold.s
            put    ../../rom/rom_color.s
            put    ../../rom/rom_tiles.s
            put    ../../rom/rom_helpers.s
            put    ../../rom/rom_input.s
            put    ../../rom/rom_exec.s
            put    ../../rom/rom_config.s
            put    ../../rom/rom_config_setup.s
; AUTOINC:END

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

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

; Before each render: pick up the palette changes
PRE_RENDER   mac
             jsr  ApplyPaletteChange ; switch to a new palette detected since the last frame
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

; Dirty rendering: when the background did not scroll, the screen-aligned 8x8 grid renderer
; (ppu_grid.s, ppu_grid_quads.s) redraws only the cells that changed, erasing from the PEA field.  0 =
; every frame is a full render.
ENABLE_DIRTY_RENDERING equ 0

GRID_MAX_BG_TILES    equ 64

; Draw sprites on single pixels (compiled variants shifted one pixel to the right for a sprite on an
; odd pixel).  Off: sprites are drawn on even pixels (IIgs bytes), with the scroll's half-pixel
; correction, and the sprite cache uses smaller slots.
SPR_PIXEL_SHIFT equ 1

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP  equ 1

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.
NO_INTERRUPTS     equ 0

; Flag to turn off the configuration support
NO_CONFIG         equ 0

; Decode the DMC samples listed in DMC_SAMPLE_LIST into DOC RAM at start-up (see apu/apu.s).
; 0 = decode each sample when the game plays it.
CACHE_DMC_SAMPLES equ 0

; Configuration screen setup (see rom/rom_config_setup.s)
CONFIG_DEFAULT_AUDIO equ APU_120HZ  ; default audio quality
CONFIG_VIDEO_MENU    equ 1          ; show the VIDEO menu
CONFIG_VIDEO_FASTBLIT equ 0         ; show the FAST BLIT option (scrolling games only)
CONFIG_VIDEO_STATUSBAR equ 0        ; show the STATUS BAR option (separately drawn status bar)
CONFIG_INPUT_BUTTONS equ 0          ; allow remapping the A/B buttons
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

; Do not check for specific Tile IDs to exclude from drawing
NO_TILE_EXCLUDE equ 1

; Do we have a custom routine to execite RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 0

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 2
y_height_rows equ 25

y_offset      equ {y_offset_rows*8}
y_height      equ {y_height_rows*8}
min_nes_y     equ y_offset
max_nes_y     equ min_nes_y+y_height

x_offset      equ 16                      ; number of bytes from the left edge

            phk
            plb

; Call startup immediately after entering the application with the cartridge configuration

            tax                           ; X = memory manager user ID (passed in A by GS/OS)
            lda   #VERTICAL_MIRRORING      ; A = cartridge nametable mirroring at power on
            jsr   NES_StartUp

; This an NROM game, so all of the sprite and background tiles are static.  They have been
; converted into the runtime's internal representation by build.js and loaded into the tiledata
; bank, so all that's left is to compile the background tiles (sprites are compiled when they
; are first drawn, SprCompileTile)

            jsr   ROM_CompileBackgroundTiles    ; Compile the background tiles

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

; Name of the save and preference files (used by misc/io.s)
SAVE_FILENAME strl '1/wump.sav'
PREF_FILENAME strl '1/wump.prefs'

; Palette management.  The game's single palette is described in palettes/, and pal_transitions.s
; (generated from them by build.js) gives each palette a fixed IIgs slot layout and swizzle tables.  A palette
; RAM write (WUMP_PalWrite) only marks the palette dirty; at the next render, ApplyPaletteChange (GS task)
; identifies the palette in palette RAM and switches to it (redrawing tiles when needed), or shows the
; changed colors in the current palette's layout.
wumpCurPal    dw    0                         ; PAL_* id of the palette on screen
wumpPalDirty  dw    0                         ; palette RAM changed since the last render

; The ROM uploads its palette once, at start-up.  InitPlayfield is called by NES_StartUp.
InitPlayfield
SetDefaultPalette
            ldy   #PAL_GAME
            sty   wumpCurPal
            ldx   PAL_SWIZZLE_LO,y
            lda   PAL_SWIZZLE_HI,y
            jmp   NES_SetPaletteMap

; Palette RAM write ($3F01-$3F1F, except the color 0s), on the NES task.  The palette RAM is already
; updated (and only changed values get here): just note that it changed.
WUMP_PalWrite
            lda   #1
            sta   wumpPalDirty
WUMP_PalNone  rts

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to it,
; or show its changed colors in the current palette's layout
ApplyPaletteChange
            lda   wumpPalDirty
            beq   :none
            lda   _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            stz   wumpPalDirty                ; (first, so a write from here on is seen next time)
            ldx   wumpCurPal
            jsr   DetectNESPalette          ; A = Y = palette id, 0 if none
            beq   :colors                   ; not a known palette (e.g. at power-on)
            cmp   wumpCurPal
            beq   :colors
            ldx   wumpCurPal
            sty   wumpCurPal
            jmp   UpdatePalette             ; X = from, Y = to
:colors     ldy   wumpCurPal
            jmp   LoadPaletteColors
:none       rts

            put   pal_transitions.s

; Color 0: $3F00 / $3F10 is always IIgs slot 0, so it is set straight away (ppu_palette.s); the
; other color 0s aren't shown.  The rest go to WUMP_PalWrite.
PALETTE_DISPATCH
        dw   ppu_3F00,WUMP_PalWrite,WUMP_PalWrite,WUMP_PalWrite
        dw   WUMP_PalNone,WUMP_PalWrite,WUMP_PalWrite,WUMP_PalWrite
        dw   WUMP_PalNone,WUMP_PalWrite,WUMP_PalWrite,WUMP_PalWrite
        dw   WUMP_PalNone,WUMP_PalWrite,WUMP_PalWrite,WUMP_PalWrite
        dw   ppu_3F10,WUMP_PalWrite,WUMP_PalWrite,WUMP_PalWrite
        dw   WUMP_PalNone,WUMP_PalWrite,WUMP_PalWrite,WUMP_PalWrite
        dw   WUMP_PalNone,WUMP_PalWrite,WUMP_PalWrite,WUMP_PalWrite
        dw   WUMP_PalNone,WUMP_PalWrite,WUMP_PalWrite,WUMP_PalWrite

; Game-specific configuration values (none): CONFIG_GAME_DEFAULTS lays out their defaults at their IDs in
; the game's block (see rom/rom_config_setup.s, which also has the built-in values, menus and ApplyConfig)
CONFIG_GAME_DEFAULTS mac
;
             <<<

            put   ../../misc/App.Msg.s         ; Text (DrawByte / DrawWord): VIDEO > SHOW FPS and the debug displays
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

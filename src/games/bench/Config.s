; Engine benchmark -- engine configuration
;
; Constants only (no code, no macros): put by Main.s and Engine.s.  The callbacks and the flags that
; enable them are in Hooks.s.


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

; Define a range of OAM entries to scan.  Only the sprites of the four figures are scanned
; (BENCH_SPRITES in sprites.s, checked below).
OAM_START_INDEX   equ 0
OAM_END_INDEX     equ 28

; Dirty rendering: when the background did not scroll, the screen-aligned 8x8 grid renderer
; (ppu_grid.s, ppu_grid_quads.s) redraws only the cells that changed, erasing from the PEA field.  0 =
; every frame is a full render.  The bench scrolls on every render.
ENABLE_DIRTY_RENDERING equ 0

GRID_MAX_BG_TILES    equ 64

; Draw sprites on single pixels (compiled variants shifted one pixel to the right for a sprite on an
; odd pixel).  Off: sprites are drawn on even pixels (IIgs bytes), with the scroll's half-pixel
; correction, and the sprite cache uses smaller slots.
SPR_PIXEL_SHIFT equ 0

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP  equ 1

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.
NO_INTERRUPTS     equ 0

; Flag to turn off the configuration support
NO_CONFIG         equ 0

; Read the game-port joystick with probes hooked into the PEA field (core/blitter/JoyProbes.s)
JOYSTICK_SUPPORT  equ 0

; Decode the DMC samples listed in DMC_SAMPLE_LIST into DOC RAM at start-up (see apu/apu.s).
; 0 = decode each sample when the game plays it.
CACHE_DMC_SAMPLES equ 0

; Configuration screen setup (see rom/rom_config_setup.s)
CONFIG_DEFAULT_AUDIO equ APU_60HZ   ; default audio quality
CONFIG_VIDEO_MENU    equ 1          ; show the VIDEO menu
CONFIG_VIDEO_FASTBLIT equ 1         ; show the FAST BLIT option (scrolling games only)
CONFIG_VIDEO_STATUSBAR equ 0        ; show the STATUS BAR option (separately drawn status bar)
CONFIG_INPUT_2P      equ 0          ; show P1/P2 tabs on the INPUT menu
CONFIG_GAME_MENU     equ 0          ; append a GAME_CONFIG menu defined by this file

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Show the number of VBLs each screen render takes at the top-left of the screen (debug)
RENDER_VBL_COUNT equ 0

; Do not check for specific Tile IDs to exclude from drawing
NO_TILE_EXCLUDE equ 1

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen.  The level has
; nothing above line 32 (SMB's status bar area), so the screen shows lines 32 - 231.
y_offset_rows equ 4
y_height_rows equ 25

y_offset      equ {y_offset_rows*8}
y_height      equ {y_height_rows*8}
min_nes_y     equ y_offset
max_nes_y     equ min_nes_y+y_height

x_offset      equ 16                      ; number of bytes from the left edge

; The benchmark's settings
BENCH_SCROLL_STEP  equ 2                  ; NES pixels the screen scrolls for each render (1 IIgs byte)
BENCH_ANIM_RENDERS equ 4                  ; renders between the steps of the walk animation
BENCH_PPUCTRL      equ $90                ; NMI on, background tiles at $1000, 8x8 sprites at $0000

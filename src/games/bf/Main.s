            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   ../../Externals.s
L1_T0       EXT                       ; Swizzle tables live in the PALDATA segment (palettes.s)
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

; Dirty rendering: when the background did not scroll, the screen-aligned 8x8 grid renderer
; (ppu_grid.s, ppu_grid_quads.s) redraws only the cells that changed, erasing from the PEA field.  0 =
; every frame is a full render.
ENABLE_DIRTY_RENDERING equ 1

GRID_MAX_BG_TILES    equ 64

; Draw sprites on single pixels (compiled variants shifted one pixel to the right for a sprite on an
; odd pixel).  Off: sprites are drawn on even pixels (IIgs bytes), with the scroll's half-pixel
; correction, and the sprite cache uses smaller slots.
SPR_PIXEL_SHIFT equ 1

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP equ 0

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
CONFIG_VIDEO_MENU    equ 1          ; show the VIDEO menu
CONFIG_INPUT_BUTTONS equ 0          ; allow remapping the A/B buttons
CONFIG_INPUT_2P      equ 0          ; show P1/P2 tabs on the INPUT menu
CONFIG_GAME_MENU     equ 1          ; append a GAME_CONFIG menu defined by this file

; Callback after the configuration has been applied.  X = config_block_start, Y = config_game_start
CONFIG_APPLY_HOOK mac
             jsr   BF_ApplyConfig
             <<<

; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ BF_PALETTE_DISPATCH
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

COMPILED_SPRITE_LIST_COUNT equ 100
COMPILED_SPRITE_LIST       mac
                           dw  $FFFF
                           <<<

; Do not check for specific Tile IDs to exclude from drawing
NO_TILE_EXCLUDE equ 0

; Do we have a custom routine to execute RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 1
CUSTOM_RENDER_SCREEN_ADDR equ _RenderScreen

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 3 
y_height_rows equ 25
y_ending_row  equ {y_offset_rows+y_height_rows}

y_offset      equ {y_offset_rows*8}
y_height      equ {y_height_rows*8}
min_nes_y     equ 24
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
; bank, so all that's left is to compile them

            jsr   ROM_CompileBackgroundTiles    ; Convert the background tiles (PPU:$1000) to compiled format
            jsr   ROM_CompileSpriteTiles        ; Convert the COMPILED_SPRITE_LIST tiles to compiled format

; This is set up to let the game define all colors.  We only need to set up a single, static
; swizzle table

            lda   SwizzleTables+2
            ldx   SwizzleTables
            jsr   NES_SetPaletteMap

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
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
SAVE_FILENAME strl '1/bf.sav'
PREF_FILENAME strl '1/bf.prefs'

; Helper to initialize the playfield based on the selected VideoMode
InitPlayfield

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
_RenderScreen

; If we're not on Balloon Trip, jut use the default render function

            ldx   DP_NES
            ldal  $000016,x
            and   #$00FF           ; Balloon Trip mode; $16 = !0
            bne   :trip_renderer
            jmp   RenderScreen

; Otherwise turn off dirty rendering and do the split-screen rendering
; like Super Mario
:trip_renderer
            lda   _ppuctrl
            ldx   _ppuscroll_x
            ldy   _ppuscroll_y
            jsr   NES_SetScroll

; Now render the top 16 lines to show the status bar area

            lda   #0
            ldx   #16
            ldy   #0                      ; Xmod256 = 0
            jsr   _BltSetupAlt
            sta   nesTopOffset            ; cache the :exit_offset value returned from this function

; Next render the remaining lines

            lda   ScreenHeight
            sec
            sbc   #16
            tax                       ; The rest of the screen is height - 16
            lda   #16                 ; Start at line 16
            ldy   StartX
            jsr   _BltSetupAlt
            sta   nesBottomOffset

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen

; drawScreen's drawSprites marked this frame's sprite cells and records for the grid renderer.  As in
; the default RenderScreen full-render path, close the frame out so those per-frame lists are reset;
; without this, every Balloon Trip frame appended to them until they overran into the code that
; follows (OAM_COPY, shadowBitmap0/1 and scanOAMSprites) and crashed.

            DO    ENABLE_DIRTY_RENDERING
            jsr   gridEndFull
            FIN

; Restore the buffer

            lda   #0                      ; virt_line
            ldx   #16                     ; lines_left
            ldy   nesTopOffset            ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            lda   ScreenHeight
            sec
            sbc   #16
            tax                           ; lines_left
            lda   #16                     ; virt_line
            ldy   nesBottomOffset         ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            stz   DirtyBits
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
TitleScreen  dw    $0F, $30, $27, $2A, $15, $02, $21, $00, $10, $16, $12, $37, $21, $17, $11, $2B
LevelHeader1 dw    $0F, $2A, $09, $07, $30, $27, $16, $11, $21, $00, $10, $12, $37, $17, $35, $2B

; Game-specific configuration values, saved after the built-in values by misc/io.s.  The
; built-in values, menus and ApplyConfig are defined in rom/rom_config_setup.s
config_game_start
config_video_twinkle   dw  1  ; animate the background stars
config_game_end

GAME_TITLE_STR      str 'GAME'
GAME_NO_ANIM_STR    str 'STAR ANIM'

GAME_CONFIG  dw   GAME_TITLE_STR
             dw   INPUT_CONFIG          ; previous menu item
             dw   0                     ; next menu item

             dw   1
             dw   GAME_ITEM_1

GAME_ITEM_1  dw   CHKBOX
             dw   0
             dw   0
             dw   3,2
             dw   GAME_NO_ANIM_STR
             dw   config_video_twinkle

; Apply the game-specific settings (CONFIG_APPLY_HOOK)
;
; Y = config_game_start
star_patch EXT
BF_ApplyConfig
            ldx:  {config_video_twinkle-config_game_start},y   ; read while Y is still 16-bit
            sep   #$30
            lda   #$80          ; BRA instruction (skip the star animation)
            cpx   #0
            beq   :turn_off
            lda   #$F0          ; BEQ instruction
:turn_off   stal  star_patch
            rep   #$30
            rts

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

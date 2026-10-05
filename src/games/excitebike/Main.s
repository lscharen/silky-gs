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
             jsr  CheckForPaletteChange   ; Update the swizzle tables before drawing any tiles
             <<<

POST_RENDER  mac
;
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
OAM_START_INDEX   equ 0     ; Should ignore sprite zero, but it's used on the title screen - ignore Tile Index $FF instead
OAM_END_INDEX     equ 64

; Allow the engine to use dirty rendering (drawing only lines where sprites
; have changed) if the background did not scroll compared to the previous frame
ENABLE_DIRTY_RENDERING equ 0

; Use the screen-aligned 8x8 grid dirty renderer (erase from the PEA field, BG tile updates
; without a full refresh).  Requires ENABLE_DIRTY_RENDERING.  See BG_TILE_DIRTY_PLAN.md
GRID_DIRTY_RENDERING equ 0
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
CONFIG_VIDEO_MENU    equ 1          ; show the VIDEO menu
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
PPU_PALETTE_MAP equ eb_palette_map
AUTOMATIC_PALETTE_MAPPING equ 1

; Turn on code that visualizes the CPU time used by the ROM code
SHOW_ROM_EXECUTION_TIME equ 0

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Show the number of VBLs each screen render takes at the top-left of the screen (debug)
RENDER_VBL_COUNT equ 0

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

; Read the scroll positions from the NES zero page
CUSTOM_PPU_SCROLL_LOCK_CODE mac
        ldx   DP_NES
        ldal  $000050,x
        sta   _topscroll    ; order Y, X
        ldal  $000012,x
        xba
        <<<

COMPILED_SPRITE_LIST_COUNT equ 0
COMPILED_SPRITE_LIST       mac
;
                           <<<

; Do not check for specific Tile IDs to exclude from drawing
NO_TILE_EXCLUDE equ 0

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

; Call startup immediately after entering the application with the cartridge configuration

            tax                           ; X = memory manager user ID (passed in A by GS/OS)
            lda   #VERTICAL_MIRRORING      ; A = cartridge nametable mirroring at power on
            jsr   NES_StartUp

; This an NROM game, so all of the sprite and background tiles are static.  They have been
; converted into the runtime's internal representation by build.js and loaded into the tiledata
; bank, so all that's left is to compile them

            jsr   ROM_CompileBackgroundTiles    ; Compile the background tiles
            jsr   ROM_CompileSpriteTiles        ; Compile the COMPILED_SPRITE_LIST tiles

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

TitleScreen  dw    $02,$0F,$30,$21
             dw    $15,$02,$2A,$3C
             dw    $27,$20,$16,$13
             dw    $2C,$08,$0F,$0F

RacePal1     dw    $29,$27,$22,$30
             dw    $18,$36,$0F,$16
             dw    $13,$31,$1C,$19
             dw    $0F,$0F,$0F,$0F

; When the NES ROM code tried to write to the PPU palette space, intercept here.
;PALETTE_DISPATCH
;        dw   ppu_3F00,ppu_3F01,ppu_3F02,ppu_3F03
;        dw   ppu_3F04,ppu_3F05,ppu_3F06,ppu_3F07
;        dw   ppu_3F08,ppu_3F09,ppu_3F0A,ppu_3F0B
;        dw   ppu_3F0C,ppu_3F0D,ppu_3F0E,ppu_3F0F

;        dw   ppu_3F10,ppu_3F11,ppu_3F12,ppu_3F13
;        dw   ppu_3F14,ppu_3F15,ppu_3F16,ppu_3F17
;        dw   ppu_3F18,ppu_3F19,ppu_3F1A,ppu_3F1B
;        dw   ppu_3F1C,ppu_3F1D,ppu_3F1E,ppu_3F1F

PALETTE_DISPATCH
        dw   ppu_3F00,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F04,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F08,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F0C,dk_3Fxx,dk_3Fxx,dk_3Fxx

        dw   ppu_3F10,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F14,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F18,dk_3Fxx,dk_3Fxx,dk_3Fxx
        dw   ppu_3F1C,dk_3Fxx,dk_3Fxx,dk_3Fxx

eb_palette_map
            dw    0,  1, -1,  2    ; These two color are used for end-of-race color cycling
            dw    0, -1, -1, -1 
            dw    0, -1, -1, -1 
            dw    0, -1, -1, -1

            dw    0,  4,  5,  6    ; reserve player colors
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1


; When the phase changes, set a flag, but wait for the transition time to drop below $70
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
        jsr  NES_BuildPalette         ; Create a mapping of the NES palette to the Apple IIgs palette

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

; Make the screen appear
_topscroll      ds 2
_top_bg_x       ds 2
nesCrowdOffset  ds 2
nesTopOffset    ds 2
nesBottomOffset ds 2
_RenderScreen

; If we are not in-game, defer to the standard renderer

        ldx  DP_NES
        ldal  $000047,x
        and   #$00FF
        bne   :racing
        jmp   RenderScreen

:racing

; Do the basic setup
;
; ram_004E_base_nametable is for the crowd offset
; ram_004D_base_nametable is for the track offset
;
; These set the horizontal scroll position.  The vertical scroll position is never changed.
;
        sep   #$20
        ldal  $00004E,x               ; Bit 0 is the high bit of the X scroll position
        lsr                           ; put in the carry bit
        lda   _topscroll              ; load the scroll value
        ror                           ; put the high bit and divide by 2 for the engine
        rep   #$20
        and   #$00FF                  ; make sure nothing is in the high byte
        sta   _top_bg_x               ; This is used directly so needs a byte offset (0 - 255)

        ldal  $00004D,x
        and   #$0001                  ; Isolate the X nametable select bit
        ldx   _ppuscroll_x
        ldy   #0
        jsr   NES_SetScroll

        lda   ppumask
        and   ppumask_override
        and   #NES_PPUMASK_BG
        jsr   EnableBackground

        lda   ppumask
        and   ppumask_override
        and   #NES_PPUMASK_SPR
        jsr   EnableSprites

; First, render the crowd (40 scanlines)

        lda   #0
        ldx   #40
        ldy   _top_bg_x           ; Xmod256
        jsr   _BltSetupAlt
        sta   nesCrowdOffset

; Next render top part of the screen to move with the player

        lda   #40
        ldx   #{200-32-40}
        ldy   StartX              ; Xmod256
        jsr   _BltSetupAlt
        sta   nesTopOffset

; Now render the bottom 32 lines to show the status bar area

        lda   #200-32
        ldx   #32
        ldy   #0                         ; Xmod256
        jsr   _BltSetupAlt
        sta   nesBottomOffset            ; cache the :exit_offset value returned from this function

; Copy the sprites and buffer to the graphics screen

        jsr   drawScreen

; Restore the buffer

        lda   #0
        ldx   #40
        ldy   nesCrowdOffset          ; offset to patch
        jsr   _RestoreBG0OpcodesAltLite

        lda   #40
        ldx   #{200-32-40}
        ldy   nesTopOffset            ; offset to patch
        jsr   _RestoreBG0OpcodesAltLite

        lda   #200-32
        ldx   #32
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
;              adrl L2_T0

; Game-specific configuration values, saved after the built-in values by misc/io.s.  The
; built-in values, menus and ApplyConfig are defined in rom/rom_config_setup.s
config_game_start
config_game_end

            DO    SHOW_DEBUG_VARS+RENDER_VBL_COUNT    ; debug text (DrawByte / DrawWord)
            put   ../../misc/App.Msg.s
            FIN
            DO    SHOW_DEBUG_VARS
            put   ../../misc/io.s
            FIN

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

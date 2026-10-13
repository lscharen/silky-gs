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
; >0 = read $100 bytes directly from NES RAM
DIRECT_OAM_READ   equ $0200

; Define a range of OAM entries to scan.  Many games do not use all 64
; sprite slots, so we can avoid doing unecessary work by only scanning
; OAM entries that may be on-screen
OAM_START_INDEX   equ 1
OAM_END_INDEX     equ 64

; Dirty rendering: when the background did not scroll, the screen-aligned 8x8 grid renderer
; (ppu_grid.s, ppu_grid_quads.s) redraws only the cells that changed, erasing from the PEA field.  0 =
; every frame is a full render.
ENABLE_DIRTY_RENDERING equ 0

GRID_MAX_BG_TILES    equ 64

; Draw sprites on single pixels (compiled variants shifted one pixel to the right for a sprite on an
; odd pixel).  Off: sprites are drawn on even pixels (IIgs bytes), with the scroll's half-pixel
; correction, and the sprite cache uses smaller slots.
SPR_PIXEL_SHIFT equ 0

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP equ 1

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
CONFIG_VIDEO_FASTBLIT equ 1         ; show the FAST BLIT option (scrolling games only)
CONFIG_VIDEO_STATUSBAR equ 1        ; show the STATUS BAR option (separately drawn status bar)
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
PPU_PALETTE_DISPATCH equ SMB_PALETTE_DISPATCH

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Show the number of VBLs each screen render takes at the top-left of the screen (debug)
RENDER_VBL_COUNT equ 0

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

; Do not check for specific Tile IDs to exclude from drawing
NO_TILE_EXCLUDE equ 0

; Do we have a custom routine to execute RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 1
CUSTOM_RENDER_SCREEN_ADDR equ _RenderScreen

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 2
y_height_rows equ 25

y_offset    equ {y_offset_rows*8}
y_height    equ {y_height_rows*8}
min_nes_y   equ y_offset
max_nes_y   equ min_nes_y+y_height

x_offset    equ   16                      ; number of bytes from the left edge

            nop                           ; workaround when loading into emulator memory before boot.  The ROM memory detection routine writed to the first two bytes
            nop

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

            jsr   ROM_CompileBackgroundTiles    ; Convert the background tiles (PPU:$1000) to compiled format

; Now, initialize the game-specific functionality that this wrapper needs in order to
; run the game in an effective manner.

; Set the palettes and swizzle tables

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

; Apply hacks
;WorldNumber           = $075f
;LevelNumber           = $075c
;AreaNumber            = $0760
ContinueWorld          = $07fd
;OffScr_WorldNumber    = $0766
;OffScr_AreaNumber     = $0767
;OffScr_LevelNumber    = $0763
ContinueArea           = $7E00   ; patches operand

;            lda   #16
;            jsr   _SetBG0YPos
;            jsr   _ApplyBG0YPosPreLite
;            jsr   _ApplyBG0YPosLite       ; Set up the code field

; Start up the NES
:start
; Hack for testing
;            sep   #$20
;            lda   #3
;            stal  ROMBase+ContinueWorld
;            lda   #1
;            stal  ROMBase+ContinueArea
;            rep   #$20

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
SAVE_FILENAME strl '1/smb.sav'
PREF_FILENAME strl '1/smb.prefs'

Greyscale   dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF

; Program variables

show_vbl_cpu      dw  0
user_break        dw  0
oldFrameCount     dw  0

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
;            sta   MinYScroll

            lda   #200
            sta   ScreenHeight
            bra   :common

:better
            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
;            sta   MinYScroll

            lda   #160           ; 160 lines high for 'better'
            sta   ScreenHeight
            bra   :common

:good
            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
;            sta   MinYScroll

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
;            sta   MaxYScroll

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
;            sta   ScreenBase
            asl
            asl
            clc
;            adc   ScreenBase
            clc
            adc   #$2000+x_offset
;            sta   ScreenBase

; Start with the title screen's (ground) palette

            jmp   SetDefaultPalette

; Make the screen appear
_RenderScreen

; Do the basic setup
            jsr   _ShowDebugInfo

            lda   _ppuctrl
            ldx   _ppuscroll_x
            ldy   #0                      ; We _never_ scroll vertically
            jsr   NES_SetScroll

            lda   ppumask
            and   ppumask_override
            and   #NES_PPUMASK_BG
            jsr   EnableBackground

            lda   ppumask
            and   ppumask_override
            and   #NES_PPUMASK_SPR
            jsr   EnableSprites

; Now render the top 16 lines to show the status bar area

            lda   #0
            ldx   #16
            ldy   #0                      ; Xmod256 = 0
            jsr   _BltSetupAlt

; Next render the remaining lines

            lda   ScreenHeight
            sec
            sbc   #16
            tax                       ; The rest of the screen is height - 16
            lda   #16                 ; Start at line 16
            ldy   StartX
            jsr   _BltSetupAlt

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen

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

; Palette management.  The palettes the game shows (ground, snow, mushroom, underground, water, castle and
; castle with Bowser's colors) are described in palettes/, and pal_transitions.s (generated from them by
; build.js) gives each one a fixed IIgs slot layout and swizzle tables.  A palette RAM write (SMB_PalWrite)
; only marks the palette dirty; at the next render, ApplyPaletteChange (GS task) identifies the palette in
; palette RAM and switches to it (redrawing tiles when needed), or shows the changed colors in the current
; palette's layout (the question block color cycling and the player colors are reserved cells).
smbCurPal   dw    0                         ; PAL_* id of the palette on screen
smbPalDirty dw    0                         ; palette RAM changed since the last render

; Start with the ground palette (the title screen), so its layout is used until the game's palette is
; detected.  Called by InitPlayfield (NES_StartUp) and at start-up.
SetDefaultPalette
            ldy   #PAL_GROUND
            sty   smbCurPal
            ldx   PAL_SWIZZLE_LO,y
            lda   PAL_SWIZZLE_HI,y
            jmp   NES_SetPaletteMap

; Palette RAM write ($3F01-$3F1F, except the color 0s), on the NES task.  The palette RAM is already
; updated (and only changed values get here): just note that it changed.
SMB_PalWrite
            lda   #1
            sta   smbPalDirty
SMB_PalNone rts

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to it,
; or show its changed colors in the current palette's layout
ApplyPaletteChange
            lda   smbPalDirty
            beq   :none
            lda   _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            stz   smbPalDirty               ; (first, so a write from here on is seen next time)
            ldx   smbCurPal
            jsr   DetectNESPalette          ; A = Y = palette id, 0 if none
            beq   :colors                   ; not a known palette
            cmp   smbCurPal
            beq   :colors
            ldx   smbCurPal
            sty   smbCurPal
            jmp   UpdatePalette             ; X = from, Y = to
:colors     ldy   smbCurPal
            jmp   LoadPaletteColors
:none       rts

            put   pal_transitions.s

; Color 0: $3F00 / $3F10 is always IIgs slot 0, so it is set straight away (ppu_palette.s); the
; other color 0s aren't shown.  The question block color and the player colors are pinned to one slot in
; every palette (the [fixed] section in palettes/transitions.txt), so they are also set straight away.
; The rest go to SMB_PalWrite.
SMB_PALETTE_DISPATCH
        dw   ppu_3F00,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_3F0D,SMB_PalWrite,SMB_PalWrite
        dw   ppu_3F10,SMB_3F11,SMB_PalWrite,SMB_3F13
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite

; The pinned colors, written straight to their IIgs palette slots (PAL_SLOT_*, pal_transitions.s).  A =
; the NES color.  They are reserved cells, so palette detection doesn't depend on them either.
SMB_3F0D    jsr  NES_ColorToIIgs            ; BG3:1, the question block color (ColorRotation)
            stal SHR_PALETTES+{2*PAL_SLOT_BG3_1}
            rts

SMB_3F11    jsr  NES_ColorToIIgs            ; SP0:1, player color (GetPlayerColors)
            stal SHR_PALETTES+{2*PAL_SLOT_SP0_1}
            rts

SMB_3F13    jsr  NES_ColorToIIgs            ; SP0:3, player color (GetPlayerColors)
            stal SHR_PALETTES+{2*PAL_SLOT_SP0_3}
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

;            lda   ScreenBase
;            sec
;            sbc   #160*16
;            sta   tmp0
;
;            ldy   #0
;:loop
;            phy                             ; preserve reg
;            ldx   MemOffsets,y
;            ldal  PPU_MEM+TILE_SHADOW,x
;            and   #$00FF
;            ora   #$0100+TILE_USER_BIT
;            pha

;            lda   ScreenOffsets,y
;            clc
;            adc   tmp0
;            pha

;            lda   #$8002
;            cpx   #107                      ; This one is palette 3
;            bne   *+5
;            ora   #$0001
;            pha
;            _GTEDrawTileToScreen           ; call NESTileBlitter

;            ply
;            iny
;            iny
;            cpy   #30*2
;            bcc   :loop
;            rts


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

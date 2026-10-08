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
             jsr  ApplyPaletteChange ; switch to a new palette detected since the last frame
             jsr  HideDoorBands      ; the NES 8-sprites-per-line limit at the top and bottom doors
             <<<

POST_RENDER  mac
;
             <<<

; Callback before each sprite is set up and drawn (drawSprites, ppu.s): X = OAM index, ]1 = the
; sprite height (8 or 16), DBR = $01 (the shadow screen), 16-bit registers.  Sets sprClipTop, the lines
; to hide at the top of the sprite: here, the lines in the door bands (see HideDoorBands).
SPRITE_PRE_DRAW  mac
             ldal  zDoorBands
             beq   *+8
             lda   #]1
             jsr   ZSpriteClip
             <<<

; Non-zero if SPRITE_PRE_DRAW can set sprClipTop: the sprite renderer only tests it then
SPRITE_CLIP equ 1

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

; Benchmark flag, driven by the gs2-mcp harness (scripts/bench-zelda.js).  See rom/rom_input.s.  The
; controller input is read from BenchInputData, one byte per NES frame, and the run ends after
; BENCH_MODE_LEN frames at BenchDone, which is before NES_ShutDown, so the save file is read but never
; written: the harness puts a zelda.wram with a registered name next to the application, so the run
; does not have to go through the registration screens.  BENCH_MODE does not
; change NO_INTERRUPTS: with interrupts on, the input advances once per VBL (schedTask), so a run
; lasts a fixed number of VBLs; with NO_INTERRUPTS it advances once per NES frame (NES_TriggerNMI),
; so the cycles between BenchStart and BenchDone measure the work done for those frames.
;
; 0 = normal build
; 1 = benchmark build
BENCH_MODE        equ 0
BENCH_MODE_LEN    equ 3600                  ; at most 6144 (BENCH_INPUT_ADDR to $1FFF)

; The cartridge has battery-backed WRAM ($6000-$7FFF).  NES_StartUp loads it from
; WRAM_FILENAME and NES_ShutDown saves it back (scaffold.s, misc/io.s).
HAS_BACKED_WRAM equ 1

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
; >0 = read $100 bytes directly from NES RAM at this address (typically $200)
DIRECT_OAM_READ   equ $200

; Define a range of OAM entries to scan.  Many games do not use all 64
; sprite slots, so we can avoid doing unecessary work by only scanning
; OAM entries that may be on-screen
OAM_START_INDEX   equ 0
OAM_END_INDEX     equ 64

; Allow the engine to use dirty rendering (drawing only lines where sprites
; have changed) if the background did not scroll compared to the previous frame
ENABLE_DIRTY_RENDERING equ 1

; Use the screen-aligned 8x8 grid dirty renderer (erase from the PEA field, BG tile updates
; without a full refresh).  Requires ENABLE_DIRTY_RENDERING.  See BG_TILE_DIRTY_PLAN.md
GRID_DIRTY_RENDERING equ 1
GRID_MAX_BG_TILES    equ 64

; Flag to determine if sprites are not drawn when any part of them goes out
; side of the defined playfield area.  When the playfield is full-height,
; this prevents *any* access to memory outside of the SHR screen.
NO_VERTICAL_CLIP  equ 1

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.
NO_INTERRUPTS     equ 0

; Flag to turn off the configuration support
NO_CONFIG         equ 0

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

; Decode the DMC samples listed in DMC_SAMPLE_LIST into DOC RAM at start-up (see apu/apu.s).
; 0 = decode each sample when the game plays it.
CACHE_DMC_SAMPLES equ 1

; Dispatch table for palette RAM writes: every entry goes to Z_PalWrite (palette management)
PPU_PALETTE_DISPATCH equ ZELDA_PALETTE_DISPATCH
AUTOMATIC_PALETTE_MAPPING equ 0

; Turn on code that visualizes the CPU time used by the ROM code
SHOW_ROM_EXECUTION_TIME equ 0

; Turn on some off-screen information
SHOW_DEBUG_VARS equ 0

; Show the number of VBLs each screen render takes at the top-left of the screen (debug)
RENDER_VBL_COUNT equ 0
; Show the renders per second (decimal) at the top-left of the screen
SHOW_FPS equ 1

; Provide alternative ways of locking in the scroll and ppu control values after a frame
CUSTOM_PPU_CTRL_LOCK equ 0
CUSTOM_PPU_SCROLL_LOCK equ 1               ; also latches the room transition split (Z_LatchSplit)
CUSTOM_PPU_CTRL_LOCK_CODE mac
;
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
                          jsr   Z_LatchSplit
                          lda   ppuscroll
                          <<<

COMPILED_SPRITE_LIST_COUNT equ 0
COMPILED_SPRITE_LIST       mac
;
                           <<<

; Do not check for specific Tile IDs to exclude from drawing
NO_TILE_EXCLUDE equ 0

; Do we have a custom routine to execite RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 1
CUSTOM_RENDER_SCREEN_ADDR equ _RenderScreen     ; split screen during room transitions

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

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Call the boot code in the ROM

            DO    BENCH_MODE
            lda   #BENCH_MODE_LEN         ; Load the canned input, one byte per frame
            ldx   #BENCH_INPUT_ADDR
            ldy   #benchCreateRec
            jsr   LoadROMFile
BenchStart                                ; The harness starts counting cycles here
            FIN
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
            DO    BENCH_MODE
BenchDone   bra   BenchDone               ; The harness reads the cycle count and the cache statistics here
            FIN
            jsr   NES_ShutDown

; Exit the application

            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

; DMC samples decoded at start-up: count, then $4012 address, $4013 length, $4010 rate for each
; (from SampleAddrs / SampleLengths / SampleRates in rom_00.s)
DMC_SAMPLE_LIST
            db    7
            db    $00,$75,$0F           ; $01 sword shot
            db    $4C,$C0,$0F           ; $02 boss hit / shout
            db    $80,$40,$0D           ; $04 door
            db    $1D,$0A,$0F           ; $08 hurt
            db    $20,$B0,$0E           ; $10 Aquamentus / Gleeok / Ganon roar
            db    $28,$90,$0F           ; $20 Dodongo / Gohma roar
            db    $4C,$D0,$0E           ; $40 Digdogger / Manhandla / Patra roar

            DO    BENCH_MODE
; Canned controller input, one byte per NES frame in the A-B-Select-Start-Up-Down-Left-Right layout
; (rom_input.s).  It is read from BENCH_FILENAME, next to the application, into the part of the NES
; address space that nothing uses ($0800-$1FFF of the ROMBase bank), so the script can change without
; a rebuild (scripts/bench-zelda.js --input).
BENCH_INPUT_ADDR equ $0800
BenchInputIndex dw  0
BenchInputData  equ ROMBase+BENCH_INPUT_ADDR
BENCH_FILENAME  strl '1/zelda.bench'
benchCreateRec  dw  4                     ; pCount (LoadROMFile only uses the file name)
                adrl BENCH_FILENAME
                dw  $00C3
                dw  $0006
                dw  $0000,$0000
            FIN

; Files used by misc/io.s.  WRAM_FILENAME holds the battery-backed save RAM (HAS_BACKED_WRAM).
WRAM_FILENAME strl '1/zelda.wram'
SAVE_FILENAME strl '1/zelda.sav'     ; unused
PREF_FILENAME strl '1/zelda.prefs'   ; unused

; Palette management.  The palettes the game uses are described in ../palettes/, and
; pal_transitions.s (generated from them) gives each one a fixed IIgs slot layout and swizzle
; tables.  A palette RAM write (Z_PalWrite) only marks the palette dirty; at the next render,
; ApplyPaletteChange (GS task) identifies the palette in palette RAM and switches to it (redrawing
; tiles when needed), or shows the changed colors in the current palette's layout.
zCurPal     dw    0                         ; PAL_* id of the palette on screen (0 = none yet)
zPalDirty   dw    0                         ; palette RAM changed since the last render

; Point the swizzle tables at the first palette until the game sets one.  InitPlayfield is called
; by NES_StartUp.
InitPlayfield
SetDefaultPalette
            ldx   PAL_SWIZZLE_LO+2
            lda   PAL_SWIZZLE_HI+2
            jmp   NES_SetPaletteMap

; Palette RAM write ($3F00-$3F1F), on the NES task.  The palette RAM is already updated: just note
; that it changed.  Everything else happens at the next render (ApplyPaletteChange), so the colors
; change together with the tiles and the PPUMASK state they go with (a game typically loads a new
; palette while the screen is blank, or before the new screen's tiles are drawn).
Z_PalWrite
            lda   #1
            sta   zPalDirty
Z_PalNone   rts

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to
; it, or show its changed colors in the current palette's layout
ApplyPaletteChange
            lda   zPalDirty
            beq   :none
            lda   _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            stz   zPalDirty                 ; (first, so a write from here on is seen next time)
            ldx   zCurPal
            jsr   DetectNESPalette          ; A = Y = palette id, 0 if none
            beq   :colors                   ; not a known palette (e.g. a step of a fade)
            cmp   zCurPal
            beq   :colors
            ldx   zCurPal
            sty   zCurPal
            jmp   UpdatePalette             ; X = from, Y = to
:colors     ldy   zCurPal
            beq   :none
            jmp   LoadPaletteColors
:none       rts

            put   pal_transitions.s

; Link goes under the top and bottom doors of the dungeons by the NES limit of 8 sprites per
; scanline: WriteBlankPrioritySprites (bank 1) puts 8 transparent sprites (tile $1C, behind the
; background, X 0) at Y $3D and 8 at Y $DD in the first 16 OAM slots, Link's highest and lowest
; positions, so the NES drops every other sprite on those 16 lines.  The engine has no sprite limit,
; so ZSpriteClip hides the sprites' lines in those bands as they are drawn (sprClipTop, ppu.s).  Tile
; $1C is in tile_exclude, so the 16 blank sprites themselves are never drawn.
zDoorBands  dw    0                         ; non-zero if either band is active this frame
zTopBand    dw    0                         ; first line of the top door band (OAM Y + 1), or 0
zBotBand    dw    0                         ; first line of the bottom door band, or 0

            mx    %00
HideDoorBands
            stz   zDoorBands
            stz   zTopBand
            stz   zBotBand
            stz   sprClipTop                ; (ZSpriteClip sets it for each sprite while a band is on)
            ldal  ROMBase+DIRECT_OAM_READ+0  ; OAM 0: Y $3D, tile $1C
            cmp   #$1C3D
            bne   :bottom
            ldal  ROMBase+DIRECT_OAM_READ+2  ; attributes $20, X 0
            cmp   #$0020
            bne   :bottom
            lda   #$3D+1
            sta   zTopBand
            sta   zDoorBands
:bottom     ldal  ROMBase+DIRECT_OAM_READ+4  ; OAM 1: Y $DD, tile $1C
            cmp   #$1CDD
            bne   :done
            ldal  ROMBase+DIRECT_OAM_READ+6
            cmp   #$0020
            bne   :done
            lda   #$DD+1
            sta   zBotBand
            sta   zDoorBands
:done       rts

; SPRITE_PRE_DRAW, while a door band is on.  X = OAM index, A = sprite height.  A sprite that starts
; in the top band has its lines down to the end of the band hidden (Link walking up into the door);
; one that starts in the bottom band is hidden entirely (only the band's first two lines are on the
; IIgs screen).  Sprites never start above the top band: that is the status bar.
            mx    %00
ZSpriteClip
            phb
            phk
            plb
            sta   :h
            stz   :clip
            ldal  OAM_COPY,x                ; first line (OAM Y + 1)
            and   #$00FF
            sta   :y
            lda   zTopBand
            beq   :bot
            lda   :y
            cmp   zTopBand
            bcc   :bot                      ; above the band
            lda   zTopBand
            clc
            adc   #16
            sec
            sbc   :y                        ; lines from the sprite's top to the end of the band
            beq   :bot
            bmi   :bot                      ; below the band
            sta   :clip
:bot        lda   zBotBand
            beq   :done
            lda   :y
            cmp   zBotBand
            bcc   :done
            lda   :h                        ; starts in the bottom band: hide it all
            sta   :clip
:done       lda   :clip
            sta   sprClipTop
            plb
            rts
:h          dw    0
:y          dw    0
:clip       dw    0

; Room transitions scroll the play area under a fixed status bar.  The NES does it with a sprite-0
; hit at the bottom of the status bar: the NMI shows the status bar at scroll (0,0), then
; WaitAndScrollToSplitBottom (bank 5) changes the scroll for the play area from NES scanline 64.
;
; The engine isn't cycle accurate, so the split is recorded instead: WaitAndScrollToSplitBottom calls
; Z_RecordSplit, in the NMI, which works out the play area's scroll from the game state the routine
; uses.  NES_RenderFrame latches it (Z_LatchSplit, the scroll lock) together with the PPU registers,
; the OAM and the nametable queue, so a render shows the play area at the scroll of the same NES frame
; as its tiles.  (The game state itself is a frame ahead by then: the NMI's mode update has already
; moved the scroll for the next frame and queued the row or column that goes with it.)
;
; While a split was made since the last render, this renderer redraws just the play area at that
; scroll and leaves the status bar on the screen as it is.  The rest of the time the default renderer
; is used.

Z_GameMode            equ $12               ; NES zero page variables
Z_GameSubmode         equ $13
Z_VScrollAddrHi       equ $58
Z_OddBaseNTOverride   equ $5F
Z_ObjDir              equ $98
Z_VScrollAddrLo       equ $E2
Z_CurHScroll          equ $FD
Z_CurPpuControl       equ $FF

ZELDA_SPLIT_LINE      equ 64-y_offset       ; screen line of NES scanline 64, the top of the play area
ZELDA_PF_LINES        equ y_height-ZELDA_SPLIT_LINE

zSplitSeen  dw    0                         ; NES side: a split was made since the last render
zSplitNT    dw    0                         ; NES side: the play area scroll of the last split
zSplitX     dw    0
zSplitY     dw    0
zSplitAddr  dw    0                         ; (scratch: the PPU address of a vertical split)

zPfSplit    dw    0                         ; Latched for the render: draw the screen split
zPfNT       dw    0                         ; and the play area's nametable select and scroll
zPfX        dw    0
zPfY        dw    0
zWasSplit   dw    0                         ; the previous render was split

; Called by WaitAndScrollToSplitBottom (JSL from bank 5) with the NES direct page, before it sets the
; scroll for the play area.  All registers are preserved.
            mx    %11
Z_RecordSplit ENT
            php
            phb
            phk
            plb
            rep   #$30
            pha
            phx

            lda   Z_CurPpuControl           ; The status bar is from nametable 0 or 2 at (0,0)
            and   #$0002
            sta   zSplitNT                  ; Default: the play area isn't split off
            stz   zSplitX
            stz   zSplitY

            lda   Z_GameMode
            and   #$00FF
            cmp   #$08
            bcc   :early

; GameMode 8 - $10 turn the video off below the split (the latched PPUMASK has the background and
; sprites off, so the play area is drawn blank); $11 and up switch the base nametable (0 -> 1, 2 -> 3).

            cmp   #$11
            bcc   :late_done
            lda   #$0001
            tsb   zSplitNT
:late_done  brl   :done

:early      lda   Z_GameSubmode
            and   #$00FF
            beq   :done                     ; Submode 0: the scroll isn't changed
            lda   Z_ObjDir
            and   #$00FF
            cmp   #$04
            bcs   :vertical

; Horizontal: nametable (CurPpuControl & $FE) | OddBaseNameTableOverride, X = CurHScroll.  The Y
; scroll written mid-frame doesn't move the rows, so they stay where they are.

            lda   Z_OddBaseNTOverride
            and   #$0001
            tsb   zSplitNT
            lda   Z_CurHScroll
            and   #$00FF
            sta   zSplitX
            bra   :done

; Vertical (horizontal mirroring): PPUADDR = VScrollAddr, so that nametable row (from its fine Y
; line) is drawn from NES scanline 64.  Nametable 0 is lines 0-239 of the code field and nametable 2
; lines 240-479.

:vertical   lda   Z_VScrollAddrLo
            and   #$00FF
            sta   zSplitAddr
            lda   Z_VScrollAddrHi
            and   #$00FF
            xba
            tsb   zSplitAddr                ; zSplitAddr = PPU address

            and   #$0800                    ; nametable 2?
            beq   *+5
            lda   #240
            sta   zSplitY

            lda   zSplitAddr
            and   #$03E0                    ; coarse Y << 5
            lsr
            lsr                             ; coarse Y * 8
            clc
            adc   zSplitY
            sta   zSplitY

            lda   zSplitAddr                ; The $2006 write also sets the fine Y scroll, to
            xba                             ; address bits 12-14 (2 for $2xxx), and the two $2007
            lsr                             ; reads after it, during rendering, each move it down
            lsr                             ; one more line
            lsr
            lsr
            and   #$0007
            clc
            adc   #2
            adc   zSplitY                   ; V = line of the row in the code field
            sec
            sbc   #ZELDA_SPLIT_LINE+y_offset ; scroll that puts line V at NES scanline 64
            bpl   *+6
            clc
            adc   #480
            ldx   #0
            cmp   #240
            bcc   :v_set
            sbc   #240                      ; (carry is set)
            ldx   #2
:v_set      sta   zSplitY
            stx   zSplitNT

:done       lda   #1
            sta   zSplitSeen
            plx
            pla
            plb
            plp
            rtl

; The scroll lock in NES_RenderFrame, with interrupts off: latch the split for this render
            mx    %00
Z_LatchSplit
            lda   zSplitSeen
            sta   zPfSplit
            stz   zSplitSeen
            lda   zSplitNT
            sta   zPfNT
            lda   zSplitX
            sta   zPfX
            lda   zSplitY
            sta   zPfY
            rts

            mx    %00
_RenderScreen
            lda   zPfSplit
            bne   :split

; Coming out of a transition the play area was last drawn at another scroll position, so redraw
; everything once rather than letting the dirty renderer keep it.

            lda   zWasSplit
            beq   :default
            stz   zWasSplit
            lda   #DIRTY_BIT_BG0_REFRESH
            tsb   DirtyBits
:default    jmp   RenderScreen

; Draw only the play area, at its own scroll position.  The status bar doesn't move during a
; transition, so it is left as it is on the screen.

:split      sta   zWasSplit
            jsr   _ShowDebugInfo

            lda   zPfNT
            ldx   zPfX
            ldy   zPfY
            jsr   NES_SetScroll
            lda   #ZELDA_SPLIT_LINE
            ldx   #ZELDA_PF_LINES
            jsr   drawScreenRange

            stz   DirtyBits
            rts

; Color 0: $3F00 / $3F10 is always IIgs slot 0, so it is set straight away (ppu_palette.s); the
; other color 0s aren't shown.  The rest go to Z_PalWrite.
ZELDA_PALETTE_DISPATCH
        dw   ppu_3F00,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   ppu_3F10,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite

; Game-specific configuration values, saved after the built-in values by misc/io.s.  The
; built-in values, menus and ApplyConfig are defined in rom/rom_config_setup.s
config_game_start
config_game_end

            DO    SHOW_DEBUG_VARS+RENDER_VBL_COUNT+SHOW_FPS ; debug text (DrawByte / DrawWord)
            put   ../../../misc/App.Msg.s
            FIN

            mput  ../../../ppu
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            put    ../../../ppu/ppu_macros.s
            put    ../../../ppu/ppu_init.s
            put    ../../../ppu/ppu_shadowlist.s
            put    ../../../ppu/ppu.s
            put    ../../../ppu/ppu_attributes.s
            put    ../../../ppu/ppu_tiles.s
            put    ../../../ppu/ppu_metatiles.s
            put    ../../../ppu/ppu_nametable2.s
            put    ../../../ppu/ppu_queues.s
            put    ../../../ppu/ppu_palette.s
            put    ../../../ppu/ppu_regs.s
            put    ../../../ppu/ppu_render.s
            put    ../../../ppu/ppu_grid.s
            put    ../../../ppu/ppu_grid_quads.s
            put    ../../../ppu/ppu_sprites.s
            put    ../../../ppu/ppu_tile_blitters.s
            put    ../../../ppu/scanline_bitmap.s
; AUTOINC:END

            put   ../../../apu/apu.s

; Core code
            put   ../../../rom/scaffold.s
            put   ../../../rom/rom_color.s
            put   ../../../rom/rom_tiles.s
            put   ../../../rom/rom_helpers.s
            put   ../../../rom/rom_input.s
            put   ../../../rom/rom_exec.s
            put   ../../../rom/rom_config.s
            put   ../../../rom/rom_config_setup.s

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

; GS/OS file load / save (battery-backed WRAM, see HAS_BACKED_WRAM)
            put   ../../../misc/io.s

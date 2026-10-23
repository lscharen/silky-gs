; Contra -- game definition: the engine callbacks
;
; Every callback macro the engine expands, the flags that enable them, and the code and data behind
; them.  Every segment source that assembles engine code puts this file (after Config.s).  A macro
; only produces code where the engine expands it.
;
; The code and data are in two fences, by the segment the engine calls them from:
;
;   DO SEG_MAIN    the event loop and frame hooks: PRE_EVT_LOOP, POST_EVT_LOOP, EVT_LOOP_BEGIN /
;                  END, PRE_RENDER, POST_RENDER, CONFIG_APPLY_HOOK, start-up (InitPlayfield)
;   DO SEG_ENGINE  the renderer and the PPU write shims: SPRITE_PRE_DRAW, CUSTOM_PPU_CTRL_LOCK_CODE,
;                  CUSTOM_PPU_SCROLL_LOCK_CODE, CUSTOM_RENDER_SCREEN_ADDR, PPU_PALETTE_DISPATCH
;
; A segment source sets SEG_MAIN / SEG_ENGINE to 1 for the fences it assembles.  A macro calls the
; code in its own fence with jsr; anything in the other fence is in another bank.  Each fence starts
; and ends with an explicit mx (Merlin32 tracks sep / rep even in a skipped DO block).
;
; Merlin32 ignores a put inside a put file, so pal_transitions.s is put by Main.s.

            mx    %00

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

; Before each render: apply a palette change, then redraw the electric barriers if their tiles changed
; (DrawBarriers)
PRE_RENDER   mac
             jsr  ApplyPaletteChange ; switch to a new palette detected since the last frame
             jsr  DrawBarriers
             <<<

POST_RENDER  mac
;
             <<<

; Callback before each sprite is set up and drawn (drawSprites, ppu.s): X = OAM index, ]1 = the
; sprite height (8 or 16), DBR = $01 (the shadow screen), 16-bit registers.  Can set sprClipTop, the
; lines to hide at the top of the sprite (none here).
SPRITE_PRE_DRAW  mac
;
             <<<

; Non-zero if SPRITE_PRE_DRAW can set sprClipTop: the sprite renderer only tests it then
SPRITE_CLIP equ 0

; Callback after the configuration has been applied.  X = config_block_start, Y = config_game_start
CONFIG_APPLY_HOOK mac
;
             <<<

; Game-specific configuration values (none): CONFIG_GAME_DEFAULTS lays out their defaults at their IDs in
; the game's block (see rom/rom_config_setup.s, which also has the built-in values, menus and ApplyConfig)
CONFIG_GAME_DEFAULTS mac
;
             <<<

; Provide alternative ways of locking in the scroll and ppu control values after a frame
CUSTOM_PPU_CTRL_LOCK equ 0
CUSTOM_PPU_SCROLL_LOCK equ 0
CUSTOM_PPU_CTRL_LOCK_CODE mac
;
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
;
                          <<<

; Do we have a custom routine to execite RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 0
; (CUSTOM_RENDER_SCREEN_ADDR is in the engine fence below)

; ===========================================================================
; MAIN side: called from the event loop, the frame hooks and start-up
; ===========================================================================
            DO    SEG_MAIN
            mx    %00

zPalDirty   EXT                             ; (the engine side's, in the other segment)
DrawBarriersL EXT                           ; (the engine side's)

; Palette management.  The palettes the game uses are described in ../palettes/, and
; pal_transitions.s (generated from them) gives each one a fixed IIgs slot layout and swizzle
; tables.  A palette RAM write (Z_PalWrite) only marks the palette dirty; at the next render,
; ApplyPaletteChange (GS task) identifies the palette in palette RAM and switches to it (redrawing
; tiles when needed), or shows the changed colors in the current palette's layout.
zCurPal     ENT                             ; PAL_* id of the palette on screen (0 = none yet; read by
            dw    0                         ; the palette dispatch, Z_PalCycle)

; Point the swizzle tables at the first palette until the game sets one.  InitPlayfield is called
; by NES_StartUp.
InitPlayfield
SetDefaultPalette
            ldx   PAL_SWIZZLE_LO+2
            lda   PAL_SWIZZLE_HI+2
            jmp   NES_SetPaletteMap

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to
; it, or show its changed colors in the current palette's layout
ApplyPaletteChange
            ldal  zPalDirty
            beq   :none
            ldal  _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            lda   #0
            stal  zPalDirty                 ; (first, so a write from here on is seen next time)
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

; PRE_RENDER: the electric barriers, in levels 2 and 4 only (DrawBarriersL, in the engine fence below)
CURRENT_LEVEL_ZP equ $30                    ; (equates.inc: CURRENT_LEVEL, 0 = level 1)
DrawBarriers
            ldal  DP_NES                    ; The NES zero page
            tax
            ldal  $000000+CURRENT_LEVEL_ZP,x
            and   #$00FD                    ; Levels 2 and 4 (1 and 3) -> 1
            cmp   #$0001
            bne   :none
            jsl   DrawBarriersL
:none       rts

            FIN
            mx    %00

; ===========================================================================
; ENGINE side: called from the renderer (per sprite, per render) and the PPU write shims
; ===========================================================================
            DO    SEG_ENGINE
            mx    %00

; Dispatch table for palette RAM writes: every entry goes to Z_PalWrite (palette management), except
; the color-cycled cells (Z_PalCycle)
PPU_PALETTE_DISPATCH equ CONTRA_PALETTE_DISPATCH

zCurPal     EXT                             ; (the MAIN side's)

zPalDirty   ENT                             ; palette RAM changed since the last render
            dw    0

; Palette RAM write ($3F00-$3F1F), on the NES task.  The palette RAM is already updated: just note
; that it changed.  Everything else happens at the next render (ApplyPaletteChange), so the colors
; change together with the tiles and the PPUMASK state they go with (a game typically loads a new
; palette while the screen is blank, or before the new screen's tiles are drawn).
Z_PalWrite
            lda   #1
            sta   zPalDirty
Z_PalNone   rts

; The cells the game color-cycles in levels 1 - 3 (BG2:1, BG3:1 - 3: reserved, *$xx, in their palette
; files, and pinned to the same IIgs slots by [fixed] in transitions.txt).  While one of those levels is
; on screen, a write goes straight to its slot: the palette doesn't need identifying again (reserved
; cells match any color), so the color changes at once and costs no palette detection at the next
; render.  Otherwise (another palette, or none yet), it is an ordinary palette write.
; A = the NES color, 16-bit registers (PPUDATA_WRITE), DBR = this bank.
Z_PalBG2_1  ldx   #PAL_SLOT_BG2_1*2
            bra   Z_PalCycle
Z_PalBG3_1  ldx   #PAL_SLOT_BG3_1*2
            bra   Z_PalCycle
Z_PalBG3_2  ldx   #PAL_SLOT_BG3_2*2
            bra   Z_PalCycle
Z_PalBG3_3  ldx   #PAL_SLOT_BG3_3*2
Z_PalCycle  jsr   NES_ColorToIIgs
            stal  SHR_PALETTES,x
            rts

CONTRA_PALETTE_DISPATCH
        dw   ppu_3F00,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalBG2_1,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalBG3_1,Z_PalBG3_2,Z_PalBG3_3
        dw   ppu_3F10,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite

; The electric barriers (levels 2 and 4).  The game animates them by rewriting background tiles $FC - $FF
; in CHR-RAM (all four, every 5 frames or so), which writes no nametable byte, so the engine never
; redraws their cells.  When one of them changed (its ChrRamDirty background bit), recompile all four
; (which clears their bits, also for a tile that isn't on screen) and redraw the cells that show them
; in the barriers' two rows of CIRAM page 0, $227 - $238 and $267 - $278.
;
; PRE_RENDER (MAIN) calls it with JSL: 16-bit registers.
BARRIER_TILE  equ   $FC                     ; The first of the four tiles
            mx    %00
DrawBarriersL ENT
            phb
            phk
            plb
            lda   bgadr_hi                  ; $8000: the background pattern table is at $1000
            beq   *+5
            lda   #$0100
            tax                             ; X = the pattern table's ChrRamDirty index
            sep   #$20
            lda   ChrRamDirty+BARRIER_TILE,x
            ora   ChrRamDirty+BARRIER_TILE+1,x
            ora   ChrRamDirty+BARRIER_TILE+2,x
            ora   ChrRamDirty+BARRIER_TILE+3,x
            rep   #$20
            and   #CHRRAM_BG_DIRTY
            beq   :out

]n          =     0
            lup   4
            lda   #{BARRIER_TILE+]n}*128    ; The tile's slot
            ora   bgadr_hi
            jsr   CheckBgTileDirty          ; Recompile it
]n          =     ]n+1
            --^

            lda   stkAnyPatched             ; The PEA field must not have patched exits under the tiles
            beq   *+5
            jsr   _PEAFieldStable
            sep   #$20
            ldx   #$0227
            jsr   :row
            ldx   #$0267
            jsr   :row
            rep   #$20                      ; (_DrawPPUTile doesn't mark the dirty renderer's cells)
            lda   #DIRTY_BIT_BG0_REFRESH
            tsb   DirtyBits
:out        plb
            rtl

; X = the row's first cell; 18 cells.  8-bit A, 16-bit X / Y.
            mx    %10
:row        ldy   #18
:cell       ldal  PPU_MEM+TILE_SHADOW,x
            cmp   #BARRIER_TILE
            bcc   :next
            phx
            phy
            jsr   _DrawPPUTile              ; A = the tile, X = its CIRAM address
            ply
            plx
:next       inx
            dey
            bne   :cell
            rts

            FIN
            mx    %00

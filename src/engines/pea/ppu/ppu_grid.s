; ppu_grid.s - 8x8 grid dirty renderer
;
; See BG_TILE_DIRTY_PLAN.md and plans/UNALIGNED_DIRTY_RENDERING.md for the design.  Summary:
;
; The playfield is divided into a grid of 8x8 cells (32 columns x y_height/8 rows) that follows the
; nametable: every cell maps onto exactly one nametable tile, and the operands of that tile's PEA
; instructions in the code field are the final pixels of the background.  So, instead of saving the
; screen beneath each sprite, a cell can be "erased" by copying 16 words from the code field to the
; shadow screen.  Changed background tiles have already been compiled into the code field by
; PPUFlushQueuesAlt, so they are handled by just marking their cells.
;
; The horizontal scroll must be cell-aligned.  The vertical one too, unless GRID_UNALIGNED_Y: then the
; grid is shifted up by j = (StartY + y_offset) & 7 lines, there is one more row, and the first and the
; last rows are edge rows, of which only lines j - 7 (top) or 0 - (j - 1) (bottom) are on the screen.
; Their cells are copied by the edge sequences of ppu_grid_marks.s, which ignore the quadrant masks.
;
; This file has the setup shared by the renderer: the fallback decision (gridPrepare), the cell tables
; and maps (gridBuildTable, gridBuildScr), the sprite table phase (gridSetPhase) and the metatile list.
; The per-frame bookkeeping (quadrant masks with per-sprite records), erase and expose are in
; ppu_grid_quads.s.
;
; Invariant after every frame (full or grid-dirty): the $01 playfield holds background + the current
; sprites, and the previous frame's sprite records cover exactly the cells of those sprites.

            DO    ENABLE_DIRTY_RENDERING

GRID_COLS   equ   32
GRID_ROWS   equ   {y_height/8}
GRID_MAX_METATILES equ 64                 ; Metatiles with redrawn tiles (palette changes or tile writes) tracked per frame

; Sprites whose OAM bytes did not change, and which nothing being redrawn reaches, are neither
; erased nor redrawn (8x8 sprites).
GRID_SPRITE_SKIP equ 1

; Keep the frame / cell / tile counters (gs*) of the dirty and full renders (~150 cycles per frame;
; only for measurements)
GRID_STATS  equ 0
GQ_PITCH2   equ   {{GRID_COLS+1}*2}         ; Bytes per padded grid row (one pad column)
GRID_X0     equ   GQ_PITCH2                 ; Index of the first visible cell (one pad row above)

INC32       mac
            inc   ]1
            bne   *+5
            inc   ]1+2
            <<<

; Add the accumulator to a 32-bit counter
ADD32       mac
            clc
            adc   ]1
            sta   ]1
            bcc   *+5
            inc   ]1+2
            <<<

; ---------------------------------------------------------------------------
; gridPrepare
; ---------------------------------------------------------------------------
; Decide if this frame can be rendered with the grid renderer.  The caller has already checked the
; scroll / refresh dirty bits.  Rebuilds the cell tables if the scroll position or mirroring mode
; changed since they were last built.
;
; Returns C = 0 if the grid renderer can be used, C = 1 to fall back to a full render
            mx    %00
gridPrepare
            phb
            phk
            plb

            lda   ControlBits             ; If the background is disabled, the code field does not
            bit   #CTRL_BKGND_ENABLE      ; match the (blank) screen
            beq   :fb

            lda   gmtOverflow             ; Attribute updates redrew more metatiles than can be tracked
            bne   :fb

            lda   StartX                  ; The horizontal scroll position must be cell-aligned
            and   #$0003
            bne   :fb
            DO    1-GRID_UNALIGNED_Y      ; (GRID_UNALIGNED_Y: the grid follows the nametable vertically)
            lda   StartY                  ; The vertical scroll position must be cell-aligned
            clc
            adc   #y_offset
            and   #$0007
            bne   :fb
            FIN

            lda   StartX
            cmp   gridKeyX
            bne   :rebuild
            lda   StartY
            cmp   gridKeyY
            bne   :rebuild
            lda   BltMirrorP
            cmp   gridKeyM
            beq   :ok
:rebuild    jsr   gridBuildTable
:ok         plb
            clc
            rts

:fb         plb
            sec
            rts

; One-time initialization, called from PPUStartUp
            mx    %00
gridStartUp
            phb
            phk
            plb
            jsr   gqInitTables
            stz   gbJ                     ; The cells' SHR addresses at j = 0
            jsr   gridBuildScr
            plb
            rts

; ---------------------------------------------------------------------------
; gridBuildTable
; ---------------------------------------------------------------------------
; Build the cell tables for the current scroll position: for every cell, the code field address of the
; tile shown in it (GRID_CELL_PEA) and its erase routine set (GRID_CELL_EQ); and the tile row / column
; -> cell maps that gridCiramToCell reads.
;
; The tables are separable: a tile's code field address is a row part (the page of its line, and the
; odd page for CIRAM page 1 under horizontal mirroring) plus a column part (its offset in the line, and
; the odd page for CIRAM page 1 under vertical mirroring), and its bank depends on the row only
; (_InitCIRAMTileMapping).  So the rows and the columns are walked once each, from the scroll origin
; (which takes care of every wrap), and each cell is one add.  Both parts are read from TILE_ADDR:
; a row's is the address of its column 0, a column's is the address of its tile in row 0 minus that
; of tile 0.
;
; The grid follows the nametable: cell row 0 is the tile row that holds the first visible line
; (StartY + y_offset).  Without GRID_UNALIGNED_Y that line is always the first line of a tile.
; GRID_CELL_SCR does not depend on the scroll (gridBuildScr), except for j with GRID_UNALIGNED_Y.
; DBR = K.
GB_ROWS     equ   GRID_ROWS+GRID_UNALIGNED_Y  ; Cell rows built (the extra one is the bottom edge row)

            mx    %00
gridBuildTable
            lda   StartX
            sta   gridKeyX
            lda   StartY
            sta   gridKeyY
            lda   BltMirrorP
            sta   gridKeyM

            lda   StartY                  ; Virtual line of the first visible line
            clc
            adc   #y_offset
            DO    GRID_UNALIGNED_Y
            pha
            and   #$0007
            sta   gbJ                     ; j: its line in its tile
            pla
            FIN
            and   #$FFF8                  ; The first line of its tile
:vm         cmp   MaxY
            bcc   :vmok
            sbc   MaxY
            bra   :vm
:vmok       sta   gbVL

; Rows: for every cell row, the code field address of its column 0 (gridRowPea) and its erase routine
; set (gridRowEq); and the tile row -> cell row map (gridRowMap, indexed by the row index * 2: the row,
; + 32 for CIRAM page 1 under horizontal mirroring).

            ldx   #63*2
            lda   #$8000                  ; Not visible
:rmc        sta   gridRowMap,x
            dex
            dex
            bpl   :rmc

            lda   #GRID_X0
            sta   gbCell                  ; Padded grid offset of the cell row
            ldy   #0                      ; Y = cell row * 2
:row
            DO    GRID_UNALIGNED_Y
            cpy   #GRID_ROWS*2            ; The extra row is a pad row when j = 0
            bne   :vis
            lda   gbJ
            bne   :vis
            lda   #64
            sta   gridRowEq,y
            bra   :next
:vis
            FIN
            lda   gbVL
            lsr
            lsr
            lsr                           ; Tile row in the ring (0 - 29, or 0 - 59 with horizontal mirroring)
            cmp   #30
            bcc   *+5
            adc   #2-1                    ; (C = 1) rows 30 - 59 are CIRAM page 1: row index 32 - 61
            asl
            tax
            lda   gbCell
            sta   gridRowMap,x
            txa
            asl
            asl
            asl
            asl                           ; Row index * 32: CIRAM address of the row's first tile
            tax
            sep   #$20
            ldal  PPU_MEM+TILE_ADDR_HI,x
            xba
            ldal  PPU_MEM+TILE_ADDR_LO,x
            rep   #$20
            sta   gridRowPea,y
            sep   #$20                    ; The erase routine set of the row's code field bank
            ldal  PPU_MEM+TILE_BANK,x
            cmp   #^lite_base_2
            rep   #$20
            beq   :bank2
            lda   #0
            bra   :bank
:bank2      lda   #32
:bank       sta   gridRowEq,y

            DO    GRID_UNALIGNED_Y        ; The edge rows' sets: 96 / 128 top, 160 / 192 bottom (bank 1 / 2)
            lda   gbJ
            beq   :next
            tya
            beq   :top
            cmp   #GRID_ROWS*2
            bne   :next
            lda   #160
            bra   :edge
:top        lda   #96
:edge       clc
            adc   gridRowEq,y
            sta   gridRowEq,y
            FIN

:next       lda   gbVL
            clc
            adc   #8
            cmp   MaxY
            bcc   *+4
            sbc   MaxY
            sta   gbVL
            lda   gbCell
            clc
            adc   #GQ_PITCH2
            sta   gbCell
            iny
            iny
            cpy   #GB_ROWS*2
            bcs   *+5
            brl   :row

; Columns: for every cell column, the code field offset of its tile from column 0 (gridColPea); and the
; tile column -> cell column map (gridColMap, indexed by the column * 2: 0 - 31, or 0 - 63 with vertical
; mirroring, where columns 32 - 63 are CIRAM page 1).

            ldx   #63*2
            lda   #$8000                  ; Not visible
:cmc        sta   gridColMap,x
            dex
            dex
            bpl   :cmc

            sep   #$20                    ; The code field address of tile 0
            ldal  PPU_MEM+TILE_ADDR_HI
            xba
            ldal  PPU_MEM+TILE_ADDR_LO
            rep   #$20
            sta   gbPea0

            lda   MaxX                    ; Width of a code field line in bytes
            lsr
            sta   gbW
            lda   StartX
            sta   gbHB                    ; Byte offset of the cell column in the line
            ldy   #0                      ; Y = cell column * 2
:col        lda   gbHB
            lsr
            lsr                           ; Tile column
            asl
            tax
            tya
            sta   gridColMap,x
            txa
            lsr
            cmp   #32
            bcc   *+5
            adc   #$0400-32-1             ; (C = 1) columns 32 - 63 are CIRAM page 1
            tax                           ; X = CIRAM address of the column's tile in row 0
            sep   #$20
            ldal  PPU_MEM+TILE_ADDR_HI,x
            xba
            ldal  PPU_MEM+TILE_ADDR_LO,x
            rep   #$20
            sec
            sbc   gbPea0
            sta   gridColPea,y
            lda   gbHB
            clc
            adc   #4
            cmp   gbW
            bcc   *+5
            sbc   gbW
            sta   gbHB
            iny
            iny
            cpy   #GRID_COLS*2
            bcc   :col

; The cells: row part + column part

            ldx   #GRID_X0                ; X = cell index * 2 (padded grid)
            ldy   #0                      ; Y = cell row * 2
:crow       lda   gridRowPea,y
            sta   gbRowPea
            lda   gridRowEq,y
            sta   gbRowEq
            phy
            ldy   #0                      ; Y = cell column * 2
:ccol       lda   gridColPea,y
            clc
            adc   gbRowPea
            stal  PPU_MEM+GRID_CELL_PEA,x
            lda   gbRowEq
            stal  PPU_MEM+GRID_CELL_EQ,x
            inx
            inx
            iny
            iny
            cpy   #GRID_COLS*2
            bcc   :ccol
            inx                           ; Skip the pad column
            inx
            ply
            iny
            iny
            cpy   #GB_ROWS*2
            bcc   :crow

            DO    GRID_UNALIGNED_Y        ; The SHR addresses and the edge copies follow j
            lda   gbJ
            cmp   gridScrJ
            beq   :scr_ok
            jsr   gridBuildScr
            jsr   gridPatchEdges
:scr_ok
            FIN
            rts

; ---------------------------------------------------------------------------
; gridBuildScr
; ---------------------------------------------------------------------------
; GRID_CELL_SCR: the SHR address of each cell, which starts at screen line 8 * row - j, byte 4 * column.
; Once at start-up; with GRID_UNALIGNED_Y also when j changes (gridBuildTable).  With GRID_UNALIGNED_Y,
; the edge rows' addresses have bit 0 set (gqExposeOp and the edge erase stubs take it off; the addresses
; are even, x_offset being even, and span $1Bxx - $9Cxx, so no high bit is free), and the extra row is a
; pad cell (1) when j = 0.  Pad cells are 0 without GRID_UNALIGNED_Y (gqInitTables).
; gbJ = j.  DBR = K.
            mx    %00
gridBuildScr
            DO    GRID_UNALIGNED_Y
            lda   gbJ
            sta   gridScrJ
            asl
            tay
            lda   Mul160Tbl,y
            sta   gbJ160                  ; j * 160
            lda   #y_height
            ldy   gbJ
            beq   *+5
            lda   #y_height+8             ; The bottom edge row
            sta   gbScrEnd
            FIN

            ldx   #GRID_X0
            stz   gbCY8                   ; Screen line of the cell row's first tile line, + j
:row        lda   gbCY8
            asl
            tay
            lda   Mul160Tbl,y
            clc
            adc   #$2000+x_offset
            DO    GRID_UNALIGNED_Y
            sec
            sbc   gbJ160
            ldy   gbJ
            beq   :flag_ok
            ldy   gbCY8                   ; The first and the last row are edge rows
            beq   :flag
            cpy   #y_height
            bne   :flag_ok
:flag       ora   #$0001
:flag_ok
            FIN
            ldy   #GRID_COLS
:col        stal  PPU_MEM+GRID_CELL_SCR,x
            clc
            adc   #4
            inx
            inx
            dey
            bne   :col
            inx                           ; Skip the pad column
            inx
            lda   gbCY8
            clc
            adc   #8
            sta   gbCY8
            DO    GRID_UNALIGNED_Y
            cmp   gbScrEnd
            FIN
            DO    1-GRID_UNALIGNED_Y
            cmp   #y_height
            FIN
            bcc   :row

            DO    GRID_UNALIGNED_Y        ; j = 0: the extra row is a pad row
            lda   gbJ
            bne   :out
            ldy   #GRID_COLS
            lda   #$0001
:pad        stal  PPU_MEM+GRID_CELL_SCR,x
            inx
            inx
            dey
            bne   :pad
:out
            FIN
            rts

            DO    GRID_UNALIGNED_Y
; ---------------------------------------------------------------------------
; gridPatchEdges
; ---------------------------------------------------------------------------
; Point the edge copy stubs (ppu_grid_marks.s) at the entries for j, and set the cell limits of the
; sprites that touch an edge row (gqSkipPrepare never skips those: an edge copy ignores the quadrant
; masks).  gbJ = j.  DBR = K.
            mx    %00
gridPatchEdges
            lda   gbJ
            bne   :on
            stz   gqEdgeLo                ; No edge rows
            lda   #$FFFF
            sta   gqEdgeHi
            rts
:on         lda   #2*GQ_PITCH2            ; A sprite in the pad row or in row 0 touches the top edge
            sta   gqEdgeLo
            lda   #GRID_ROWS*GQ_PITCH2    ; A sprite in row 24 or below touches the bottom edge (row 25)
            sta   gqEdgeHi
            lda   gbJ
            asl
            tax                           ; X = j * 2
            lda   gqEF1Tbl,x              ; Top edge: lines j - 7, forward from line j
            sta   gqETop1J+1
            lda   gqEF2Tbl,x
            sta   gqETop2J+1
            lda   gqXFTbl,x
            sta   gqXTopJ+1
            lda   gqER1Tbl-2,x            ; Bottom edge: lines 0 - (j - 1), backward from line j - 1
            sta   gqEBot1J+1
            lda   gqER2Tbl-2,x
            sta   gqEBot2J+1
            lda   gqXRTbl-2,x
            sta   gqXBotJ+1
            rts

; ---------------------------------------------------------------------------
; gridSetPhase
; ---------------------------------------------------------------------------
; A = the new StartY (_UpdateScrollStart).  When j = (StartY + y_offset) & 7 changes, shift the bases of
; the sprite row / line class tables by j: a sprite at OAM y is in the cell row and at the line of the
; table entry for y + j.  Every renderer marks the sprites (full renders record them for the next
; frame), so this happens when StartY changes, not when the grid tables are built.  Any DBR; A and X
; preserved.
            mx    %00
gridSetPhase
            pha
            phx
            phb
            phk
            plb
            clc
            adc   #y_offset
            and   #$0007
            cmp   gridJ
            beq   :out
            sta   gridJ
            tax
            clc
            adc   #gridRowLo
            sta   gqPRL1+1
            sta   gqPRL2+1
            sta   gqPRL3+1
            txa
            clc
            adc   #gridRowHi
            sta   gqPRH1+1
            sta   gqPRH2+1
            sta   gqPRH3+1
            txa
            clc
            adc   #gridKCls
            sta   gqPKC1+1
            sta   gqPKC2+1
            sta   gqPKC3+1
:out        plb
            plx
            pla
            rts
            FIN

; ---------------------------------------------------------------------------
; gridCiramToCell
; ---------------------------------------------------------------------------
; A = CIRAM address ($000 - $7FF).  Returns C = 1 if the tile is not visible, otherwise C = 0 and
; X = cell index * 2.  Reads the maps of gridBuildTable.  Y preserved.  DBR = K.
            mx    %00
gridCiramToCell
            sta   gcC
            and   CIRAMRowMask            ; The row, with the page bit under horizontal mirroring, * 32
            lsr
            lsr
            lsr
            lsr                           ; Row index * 2
            tax
            lda   gridRowMap,x
            bmi   :off
            sta   gcCell
            lda   gcC
            and   CIRAMColMask            ; The column, with the page bit under vertical mirroring
            cmp   #$0400
            bcc   *+5
            eor   #$0420                  ; CIRAM page 1: columns 32 - 63
            asl
            tax
            lda   gridColMap,x
            bmi   :off
            clc
            adc   gcCell
            tax
            clc
            rts
:off        sec
            rts

; ---------------------------------------------------------------------------
; gridRecordMetatile
; ---------------------------------------------------------------------------
; Record redrawn tiles of a metatile so the grid renderer exposes them instead of forcing a full render.
; Entries are (CIRAM address of the top-left tile, nibble of tiles: bit 0 = +0, bit 1 = +1, bit 2 = +32,
; bit 3 = +33).  gridRecordMetatile (from RefreshMetatile) records all 4 tiles; PPUFlushQueuesAlt adds
; partial metatiles inline.  The list is consumed by gridDrawDirty and cleared by gridEndFrame.
;
; X = CIRAM address of the top-left tile of the metatile.  Any width / DBR.  Preserves A, X, Y and P.
            mx    %10
gridRecordMetatile
            php
            rep   #$30
            mx    %00                     ; Assemble the body for 16-bit A/X/Y; plp restores the caller's widths
            pha
            phy
            lda   #$000F
            pha                           ; Nibble
            txy                           ; Y = CIRAM address
            ldal  gmtEnd
            cmp   #GRID_MAX_METATILES*4
            bcs   :overflow
            tax
            tya
            stal  gmtList,x
            pla
            and   #$000F
            stal  gmtList+2,x
            txa
            clc
            adc   #4
            stal  gmtEnd
            bra   :out
:overflow   pla
            lda   #1
            stal  gmtOverflow
:out        tyx
            ply
            pla
            plp
            rts

; Number of 8x8 sprite tiles drawn this frame
            mx    %00
gridSpriteTiles
            lda   spriteCount
            lsr
            lsr
            tay
            lda   _ppuctrl
            bit   #NES_PPUCTRL_SPRSIZE
            beq   :x1
            tya
            asl
            rts
:x1         tya
            rts

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
gridKeyX        dw    $FFFF
gridKeyY        dw    $FFFF
gridKeyM        dw    $FFFF

gbW             dw    0
gbCY8           dw    0
gbVL            dw    0
gbHB            dw    0
gbCell          dw    0
gbPea0          dw    0
gbRowPea        dw    0
gbRowEq         dw    0
gbJ             dw    0                   ; j of the tables being built
gbBgCount       dw    0
gbMtCount       dw    0

gcC             dw    0
gcCell          dw    0

; gridBuildTable's row and column parts, and the tile row / column -> cell maps (gridCiramToCell)
gridRowPea      ds    GB_ROWS*2           ; Code field address of the row's column 0
gridRowEq       ds    GB_ROWS*2           ; Erase routine set of the row
gridColPea      ds    GRID_COLS*2         ; Code field offset of the column from column 0
gridRowMap      ds    64*2                ; By row index (+ 32 for CIRAM page 1, horizontal mirroring): padded row offset, or $8000
gridColMap      ds    64*2                ; By column (+ 32 for CIRAM page 1, vertical mirroring): column * 2, or $8000

            DO    GRID_UNALIGNED_Y
gridJ           dw    0                   ; j of the sprite table bases (gridSetPhase)
gridScrJ        dw    $FFFF               ; j of GRID_CELL_SCR and of the edge stubs
gbJ160          dw    0
gbScrEnd        dw    0
gqEdgeLo        dw    0                   ; gqSkipPrepare: cells of the sprites that touch an edge row
gqEdgeHi        dw    $FFFF               ;   (cell < gqEdgeLo or cell >= gqEdgeHi; none when j = 0)
            FIN

; Statistics block.  The signature makes it easy to find from a debugger.  All counters are 32-bit.
gridStatsSig    asc   'GRIDSTAT'
gsDirtyFrames   ds    4
gsFullFrames    ds    4
gsErased        ds    4               ; Cells copied from the code field
gsExposed       ds    4               ; Cells exposed (shadowed copies)
gsSprTiles      ds    4               ; 8x8 sprite tiles drawn in grid-dirty frames
gsBgCells       ds    4               ; Visible background tiles updated in grid-dirty frames
gsFbBgOff       ds    4               ; (unused: kept so the block's layout does not change)
gsFbAttr        ds    4
gsFbMany        ds    4
gsFbAlign       ds    4
gsFbScroll      ds    4
gsBgFrames      ds    4               ; Grid-dirty frames with at least one visible BG tile update
gsMetatiles     ds    4               ; Metatiles redrawn by attribute updates in grid-dirty frames
gsMtCells       ds    4               ; Visible cells marked for those metatiles
gsAttrFrames    ds    4               ; Grid-dirty frames with at least one attribute-driven cell
gsEraseWords    ds    4               ; 16-bit words copied from the code field
gsExposeWords   ds    4               ; 16-bit words exposed (copied with shadowing on)
gsLastErased    dw    0
gsLastExposed   dw    0
gsLastSprTiles  dw    0
gsLastBg        dw    0

gmtEnd          dw    0
gmtOverflow     dw    0
gmtNib          dw    0
gmtList         ds    GRID_MAX_METATILES*4    ; (CIRAM address of the top-left tile, nibble of tiles) pairs

; cellScr / cellPea / cellEq live in the PPU_MEM bank (GRID_CELL_* in Defs.s) to save space here

            FIN

; ppu_grid_quads.s - Grid dirty renderer, quadrant masks
;
; Each 8x8 cell is split into 4 quadrants of 4 lines x 1 word (TL = 1, TR = 2, BL = 4, BR = 8).  The cell
; state is one word, with the masks pre-shifted so that an AND gives mask * 2 for the dispatch tables:
;
;   bits 1-4   quadrants still to erase (previous frame's sprites, background / attribute updates)
;   bits 9-12  quadrants to expose
;
; The grid is padded (one column on the right, rows above and below the playfield), so a sprite always
; touches the cells at Y, Y+2, Y+PITCH and Y+PITCH+2 (plus one more row for 8x16) with no bounds checks;
; anything that lands in a pad cell is ignored because pad cells have no SHR address.  Byte tables
; indexed by the OAM coordinates give the cell offset and the sprite's quadrant pattern (the classes of
; k = its line and p = its pixel in the cell: gridKCls | gridPCls), and ppu_grid_marks.s has a mark routine
; per pattern with the masks as immediates.
;
; Lists are code.  The cells touched this frame form an array of "ldy #cell / jsr gqCellOp" entries: a
; cell's first touch just stores its index into the next entry's operand.  A pass patches gqCellOp to
; jump to its handler, pokes an RTS over the first unused entry and calls the array:
;
;   erase:  copy the erase quadrants (the cell is left as it is)
;   expose: copy the erase and expose quadrants, then zero the cell (this is also the end-of-frame clear)
;
; The sprites drawn this frame are recorded the same way, as "ldy #cell / jsr gqR8_n" (gqR16_n) entries, so
; the next frame replays them into the erase nibble by calling the array (with X = the cell list's write
; pointer, which the replay routines keep in X).

            DO    ENABLE_DIRTY_RENDERING

GQ_ROWS     equ   {GRID_ROWS+4+GRID_UNALIGNED_Y}  ; Pad row above, playfield rows (+ the bottom edge row), pad rows below (8x16 reach)
GQ_BYTES    equ   {GQ_ROWS*GQ_PITCH2}
GQ_PITCH2X2 equ   {GQ_PITCH2*2}
GQ_MAXREC   equ   64                        ; One record per OAM entry
GQ_TALL     equ   $8000                     ; 8x16 sprite
GQ_MAXCELLS equ   {GQ_MAXREC*6*2}+GRID_MAX_BG_TILES+{GRID_MAX_METATILES*4}  ; old + new sprite cells, BG, metatiles
GQ_ENTRY    equ   6                         ; ldy #cell / jsr gqCellOp
GQ_CODEBYTES equ  {GQ_MAXCELLS+1}*GQ_ENTRY  ; +1 entry for the RTS
GQ_RENTRY   equ   6                         ; ldy #cell / jsr gqR8_n|gqR16_n
GQ_RECBYTES equ   {GQ_MAXREC+1}*GQ_RENTRY
GQ_ERASE    equ   $001E                     ; Erase nibble (mask * 2)
GQ_EXPOSE   equ   $1E00                     ; Expose nibble (mask * 2 << 8)
GRID_CELL_STATS equ 0                       ; Count cells erased / exposed (~7 cycles per cell per pass)

; ---------------------------------------------------------------------------
; gqInitTables -- coordinate lookup tables and code array templates (once, from PPUStartUp)
; ---------------------------------------------------------------------------
            mx    %00
gqInitTables
            phb
            phk
            plb

; y (OAM, already +1): row offset in the padded grid (low / high bytes) and the class of k (the sprite's
; line in its cell) * 8.  Rows above the playfield map to the pad row above it and rows below map to the
; pad rows below it.

            ldy   #0
:yl         tya
            sec
            sbc   #y_offset
            sta   gqCell                  ; s, signed
            and   #$0007
            tax
            lda   gqClsTbl,x              ; k class * 8
            and   #$00FF
            asl
            asl
            asl
            sep   #$20
            sta   gridKCls,y
            rep   #$20
            lda   gqCell
            bpl   :ypos
            lda   #0                      ; Above the playfield: pad row 0
            bra   :ymul
:ypos       lsr
            lsr
            lsr
            cmp   #GRID_ROWS+GRID_UNALIGNED_Y  ; (GRID_UNALIGNED_Y: the bottom edge row, or a pad row when j = 0)
            bcc   *+5
            lda   #GRID_ROWS+GRID_UNALIGNED_Y
            inc                           ; Padded row = row + 1
:ymul       tax
            lda   #0
:ym         cpx   #0
            beq   :ymd
            clc
            adc   #GQ_PITCH2
            dex
            bra   :ym
:ymd        sep   #$20
            sta   gridRowLo,y
            xba
            sta   gridRowHi,y
            rep   #$20
            iny
            cpy   #256
            bcc   :yl

; x (NES pixels): column offset and the class of p (the sprite's pixel in its cell, x & 7; without
; SPR_PIXEL_SHIFT the sprites are drawn on even pixels, x & 6) * 2.  The scroll is always a multiple of 8
; when the grid is used, so the half-pixel parity in SPR_SETUP is 0.

            ldy   #0
:xl         tya
            lsr                           ; IIgs byte
            lsr
            lsr
            asl
            sep   #$20
            sta   gridColOff,y
            rep   #$20
            tya
            DO    SPR_PIXEL_SHIFT
            and   #$0007                  ; p
            FIN
            DO    1-SPR_PIXEL_SHIFT
            and   #$0006                  ; p (even)
            FIN
            tax
            lda   gqClsTbl,x              ; p class * 2
            and   #$00FF
            asl
            sep   #$20
            sta   gridPCls,y
            rep   #$20
            iny
            cpy   #256
            bcc   :xl

; SPR_SETUP's results, for gridMarkSprite8/16 (GQ_SPR_SETUP): by OAM y (+1), the SHR address of the
; sprite's line at byte 0; with SPR_PIXEL_SHIFT, by OAM x, sprShift (4 on an odd pixel) and the right clip
; (sprTmp4).  From byte 124 on, sprites are drawn on even pixels and clipped by the bytes past 124.

            ldy   #0
            lda   #$2000-{y_offset*160}+x_offset
:sy         sep   #$20
            sta   gqSprYLo,y
            xba
            sta   gqSprYHi,y
            xba
            rep   #$20
            clc
            adc   #160
            iny
            cpy   #256
            bcc   :sy

            DO    SPR_PIXEL_SHIFT
            ldy   #0
:sx         tya
            and   #$0001
            asl
            asl
            tax                           ; the shift on an odd pixel
            tya
            lsr                           ; IIgs byte
            cmp   #124
            bcc   :sxin
            sbc   #124                    ; (carry set) the bytes past 124, on an even pixel
            ldx   #0
            bra   :sxs
:sxin       lda   #0
:sxs        sep   #$20
            sta   gqSprXC,y
            txa
            sta   gqSprXS,y
            rep   #$20
            iny
            cpy   #256
            bcc   :sx
            FIN

; Cell code array: A0 00 00 / 20 <gqCellOp> = ldy #0000 / jsr gqCellOp

            ldx   #0
:cf         lda   #$00A0
            sta   gqCode,x
            lda   #$2000
            sta   gqCode+2,x
            lda   #gqCellOp
            sta   gqCode+4,x
            txa
            clc
            adc   #GQ_ENTRY
            tax
            cpx   #GQ_CODEBYTES
            bcc   :cf

; Record code arrays: A0 00 00 / 20 <gqRepNop> = ldy #0000 / jsr gqRepNop

            ldx   #0
:rf         lda   #$00A0
            sta   gqRec,x
            lda   #$2000
            sta   gqRec+2,x
            lda   #gqRepNop
            sta   gqRec+4,x
            txa
            clc
            adc   #GQ_RENTRY
            tax
            cpx   #GQ_RECBYTES*2
            bcc   :rf

; Erase routine sets: every cell starts as a pad cell (nothing to copy); gridBuildTable sets the playfield
; cells to their code field bank's set

            ldx   #0
            lda   #64
:eq         stal  PPU_MEM+GRID_CELL_EQ,x
            inx
            inx
            cpx   #GQ_BYTES
            bcc   :eq

; SHR addresses: every cell starts as a pad cell (0; 1 with GRID_UNALIGNED_Y, whose edge cells have bit 0
; set too: a cell's SHR address is always even); gridBuildScr sets the playfield cells

            ldx   #0
            lda   #GRID_UNALIGNED_Y
:scr        stal  PPU_MEM+GRID_CELL_SCR,x
            inx
            inx
            cpx   #GQ_BYTES
            bcc   :scr

; The erase routines read the code field with long addressing: store each set's bank in its operands

            ldx   #0
:eb         sep   #$20
            ldy   gqEBSites1,x
            lda   #^lite_base_1
            sta:  $0000,y
            ldy   gqEBSites2,x
            lda   #^lite_base_2
            sta:  $0000,y
            rep   #$20
            inx
            inx
            cpx   #GQ_EBSITES*2
            bcc   :eb

            DO    GRID_UNALIGNED_Y        ; The edge sequences' bank bytes
            ldx   #0
:ee         sep   #$20
            ldy   gqEESites1,x
            lda   #^lite_base_1
            sta:  $0000,y
            ldy   gqEESites2,x
            lda   #^lite_base_2
            sta:  $0000,y
            rep   #$20
            inx
            inx
            cpx   #GQ_EESITES*2
            bcc   :ee
            FIN

            lda   #gqRec                  ; Current records in the first array, none previous
            sta   gqRecBase
            sta   gqRecPtr
            sta   gqRecEnd
            lda   #gqRec+GQ_RECBYTES
            sta   gqPrevBase
            sta   gqPrevEnd
            lda   #gqCode+1               ; Empty cell array (points at the first operand)
            sta   GridLPtr
            plb
            rts

; ---------------------------------------------------------------------------
; gridMarkSprite8 / gridMarkSprite16 -- called from drawSprites (DBR = $01).  X = OAM_COPY index (preserved)
;
; They also set the sprite up for drawing, as SPR_SETUP does (sprTmp1, sprShift, sprTmp4), from the same
; coordinates and with the same 8-bit registers: drawSprites calls them instead of SPR_SETUP.
; ---------------------------------------------------------------------------

; The setup, with SPR_PIXEL_SHIFT: X = OAM y, Y = OAM x, 8-bit registers, DBR = K.  The high byte of
; sprShift is 0 (drawSprites).  ]1 = 8, or 16 (SPR_TALL: sprShift for the whole 8x16 sprite, 0 / 8).
GQ_SPR_SETUP mac
            tya
            lsr                           ; IIgs byte
            clc
            adc   gqSprYLo,x
            sta   sprTmp1
            lda   gqSprYHi,x
            adc   #0
            sta   sprTmp1+1
            lda   gqSprXS,y
            DO    SPR_TALL*{]1/16}
            asl
            FIN
            sta   sprShift
            lda   gqSprXC,y
            sta   sprTmp4
            stz   sprTmp4+1
            <<<

; Without SPR_PIXEL_SHIFT: from X = the OAM offset, sets X = OAM y and Y = the grid's x (the pixel the sprite
; is drawn at: OAM x + the scroll's parity, as the background starts at an even pixel; $FF past the right
; edge).  The sprite's byte is half the 9-bit sum, clipped from 125 on.  8-bit registers, DBR = K.
GQ_SPR_SETUP0 mac
            lda   OAM_COPY+3,x
            clc
            adc   sprXPar
            tay
            ror                           ; IIgs byte: (x + parity) / 2, 128 past the right edge
            bpl   *+4
            ldy   #$FF                    ; (past the right edge)
            sta   sprTmp1
            cmp   #125
            bcc   *+6
            sbc   #124                    ; (carry set) the bytes past 124
            bra   *+4
            lda   #0
            sta   sprTmp4
            stz   sprTmp4+1
            lda   OAM_COPY,x              ; Y-coordinate (already adjusted by +1)
            tax
            lda   sprTmp1
            clc
            adc   gqSprYLo,x
            sta   sprTmp1
            lda   gqSprYHi,x
            adc   #0
            sta   sprTmp1+1
            <<<

            mx    %00
gridMarkSprite8
            phx
            phb
            phk
            plb

            sep   #$30                    ; 8-bit: the coordinates index the byte tables directly
            mx    %11
            DO    SPR_PIXEL_SHIFT
            ldy   OAM_COPY+3,x            ; X-coordinate
            lda   OAM_COPY,x              ; Y-coordinate (already adjusted by +1)
            tax
            GQ_SPR_SETUP 8
            FIN
            DO    1-SPR_PIXEL_SHIFT
            GQ_SPR_SETUP0
            FIN
            DO    GRID_UNALIGNED_Y
gqPRL1
            FIN
            lda:  gridRowLo,x             ; cell = row offset + column offset (gridSetPhase patches the
            clc                           ; three table bases by j)
            adc   gridColOff,y
            sta   gqCell
            DO    GRID_UNALIGNED_Y
gqPRH1
            FIN
            lda:  gridRowHi,x
            adc   #0
            sta   gqCell+1
            DO    GRID_UNALIGNED_Y
gqPKC1
            FIN
            lda:  gridKCls,x              ; pattern * 2 (ppu_grid_marks.s)
            ora   gridPCls,y
            tax
            rep   #$30                    ; X high byte is 0
            mx    %00

            ldy   gqRecPtr                ; Record "ldy #cell / jsr gqR8_n" for the next frame
            lda   gqCell
            sta:  $0001,y
            lda   gqR8Tbl,x
            sta:  $0004,y
            tya                           ; The next record down: the sprites are drawn last to first
            sec
            sbc   #GQ_RENTRY
            sta   gqRecPtr
            ldy   gqCell
            jmp   (gqM8Tbl,x)             ; Marks the cells, then plb / plx / rts

            mx    %00
gridMarkSprite16
            phx
            phb
            phk
            plb

            sep   #$30                    ; 8-bit: the coordinates index the byte tables directly
            mx    %11
            DO    SPR_PIXEL_SHIFT
            ldy   OAM_COPY+3,x            ; X-coordinate
            lda   OAM_COPY,x              ; Y-coordinate (already adjusted by +1)
            tax
            GQ_SPR_SETUP 16
            FIN
            DO    1-SPR_PIXEL_SHIFT
            GQ_SPR_SETUP0
            FIN
            DO    GRID_UNALIGNED_Y
gqPRL2
            FIN
            lda:  gridRowLo,x             ; cell = row offset + column offset (gridSetPhase patches the
            clc                           ; three table bases by j)
            adc   gridColOff,y
            sta   gqCell
            DO    GRID_UNALIGNED_Y
gqPRH2
            FIN
            lda:  gridRowHi,x
            adc   #0
            sta   gqCell+1
            DO    GRID_UNALIGNED_Y
gqPKC2
            FIN
            lda:  gridKCls,x              ; pattern * 2 (ppu_grid_marks.s)
            ora   gridPCls,y
            tax
            rep   #$30                    ; X high byte is 0
            mx    %00

            ldy   gqRecPtr                ; Record "ldy #cell / jsr gqR16_n" for the next frame
            lda   gqCell
            sta:  $0001,y
            lda   gqR16Tbl,x
            sta:  $0004,y
            tya                           ; The next record down: the sprites are drawn last to first
            sec
            sbc   #GQ_RENTRY
            sta   gqRecPtr
            ldy   gqCell
            jmp   (gqM16Tbl,x)            ; Marks the cells, then plb / plx / rts

; ---------------------------------------------------------------------------
; gridDrawDirty
; ---------------------------------------------------------------------------
            mx    %00
gridDrawDirty
            DO    JOYSTICK_SUPPORT
            jsr   JoyScanArm              ; Read the joystick from scanline interrupts (JoyProbes.s)
            FIN
            jsr   _PEAFieldStable         ; Erased cells are copied from the PEA field
            phb
            phk
            plb
            DO    GRID_SPRITE_SKIP
            jsr   gqSkipPrepare           ; Unchanged sprites: their old records become no-ops
            FIN

; 1. Replay the previous frame's sprites into the erase nibble: call the record array

            ldx   gqPrevEnd
            cpx   gqPrevBase
            beq   :rdone
            sep   #$20
            mx    %10
            lda   #$60                    ; RTS after the last record
            sta:  $0000,x
            rep   #$20
            mx    %00
            lda   gqPrevBase
            sta   :rjsr+1
            ldx   GridLPtr                ; The replay routines keep the list write pointer in X
:rjsr       jsr   $0000
            stx   GridLPtr
            ldx   gqPrevEnd
            sep   #$20
            mx    %10
            lda   #$A0                    ; Restore the template
            sta:  $0000,x
            rep   #$20
            mx    %00
:rdone

; 2. Background tiles and attribute-driven metatiles: whole cells

            DO    GRID_STATS
            stz   gbBgCount               ; (Tile writes now arrive through the metatile list)
            stz   gbMtCount
            FIN
            ldy   #0
            bra   :t3
:l3         lda   gmtList+2,y             ; Nibble: the metatile's tiles to expose
            sta   gmtNib
            lsr   gmtNib
            bcc   :mq1
            lda   gmtList,y
            jsr   gqMarkCiram             ; top-left
:mq1        lsr   gmtNib
            bcc   :mq2
            lda   gmtList,y
            inc
            jsr   gqMarkCiram             ; top-right
:mq2        lsr   gmtNib
            bcc   :mq3
            lda   gmtList,y
            clc
            adc   #32
            jsr   gqMarkCiram             ; bottom-left
:mq3        lsr   gmtNib
            bcc   :mq4
            lda   gmtList,y
            clc
            adc   #33
            jsr   gqMarkCiram             ; bottom-right
:mq4        iny
            iny
            iny
            iny
:t3         cpy   gmtEnd
            bcc   :l3
            DO    GRID_STATS
            tya
            lsr
            lsr
            ADD32 gsMetatiles
            FIN

            DO    GRID_SPRITE_SKIP
            jsr   gqSkipCascade           ; Changed sprites' new positions, then everything they reach
            FIN

; 3. Erase (shadowing off) every cell listed so far: the code field into the shadow screen

            jsr   _ShadowOff
            DO    GRID_CELL_STATS
            stz   tmp7                    ; Cells erased
            stz   gbEraseW
            stz   gbExposeW
            FIN
            lda   GridLPtr
            dec
            tax                           ; Opcode of the first unused entry
            ldy   #$0101                  ; Run with DBR = $01 (the copy routines index the SHR page)
            lda   #gqEraseOp
            jsr   gqRunCells
            DO    GRID_CELL_STATS
            lda   tmp7
            sta   gbErase
            FIN

; 4. New sprites (mark the expose nibble, extend the cell array and record themselves)

            jsr   drawSprites
            DO    GRID_SPRITE_SKIP
            jsr   gqSkipClear
            FIN
            jsr   _ShadowOn

; 5. Expose and clear every cell

            DO    GRID_CELL_STATS
            stz   tmp7                    ; Cells exposed
            FIN
            lda   GridLPtr
            dec
            tax
            ldy   #$0101                  ; Run with DBR = $01 (the expose routines index the SHR page)
            lda   #gqExposeOp
            jsr   gqRunCells
            DO    GRID_CELL_STATS
            lda   tmp7
            sta   gbExpose
            FIN

; Statistics

            DO    GRID_STATS
            INC32 gsDirtyFrames
            lda   gbErase
            sta   gsLastErased
            ADD32 gsErased
            lda   gbExpose
            sta   gsLastExposed
            ADD32 gsExposed
            lda   gbBgCount
            sta   gsLastBg
            beq   :no_bg
            ADD32 gsBgCells
            INC32 gsBgFrames
:no_bg      lda   gbMtCount
            beq   :no_mt
            ADD32 gsMtCells
            INC32 gsAttrFrames
:no_mt
            DO    GRID_CELL_STATS
            lda   gbEraseW
            ADD32 gsEraseWords
            lda   gbExposeW
            ADD32 gsExposeWords
            FIN
            jsr   gridSpriteTiles
            sta   gsLastSprTiles
            ADD32 gsSprTiles
            FIN

            jsr   gqSwap
            plb
            rts

; Run the cell code array up to (not including) the entry whose opcode is at X, with handler A and DBR
; set from Y (both bytes).  DBR = K on entry and on exit.
            mx    %00
gqRunCells
            sta   gqCellOp+1
            stx   gqRunEnd
            sep   #$20
            mx    %10
            lda   #$60                    ; RTS
            sta:  $0000,x
            rep   #$20
            mx    %00
            phy
            plb
            plb
            jsr   gqCode
            phk                           ; Back to DBR = K
            plb
            ldx   gqRunEnd
            sep   #$20
            mx    %10
            lda   #$A0                    ; Restore the template
            sta:  $0000,x
            rep   #$20
            mx    %00
            rts

; Every cell array entry calls this; it is patched to jump to the current pass's handler (Y = cell)
gqCellOp    jmp   $0000

; Erase handler.  Y = cell.  The cell keeps its erase bits: the expose pass exposes the erase and expose
; quadrants.  DBR = $01: the copy routines read the code field with long addressing, from the routine set
; of the cell's code field bank (GRID_CELL_EQ, which also sends a pad cell to an RTS).
            mx    %00
gqEraseOp
            tyx
            ldal  gqGrid,x
            and   #GQ_ERASE
            DO    GRID_CELL_STATS
            pha
            tax
            ldal  gqQuadWords,x
            clc
            adcl  gbEraseW
            stal  gbEraseW
            inc   tmp7                    ; (pad cells included)
            tyx
            pla
            FIN
            oral  PPU_MEM+GRID_CELL_EQ,x
            tax
            ldal  gridEQTbl,x
            stal  :pp+1
            tyx
            ldal  PPU_MEM+GRID_CELL_SCR,x
            tay                           ; Y = SHR address
            ldal  PPU_MEM+GRID_CELL_PEA,x
            tax                           ; X = code field address
:pp         jmp   $0000                   ; The copy routine returns to the cell array

; Expose handler.  Y = cell.  DBR = $01, so the grid and cell tables are reached with long addressing and
; the copy routine is entered with an indexed indirect jump (Y = SHR address).
            mx    %00
gqExposeOp
            tyx
            ldal  gqGrid,x                ; erase | expose quadrants: the high byte read at +1 is in the low
            oral  gqGrid+1,x              ; byte (bits 8-15 hold the next cell's erase byte)
            and   #GQ_ERASE
            sta   tmp5                    ; mask * 2
            lda   #0
            stal  gqGrid,x
            ldal  PPU_MEM+GRID_CELL_SCR,x
            DO    1-GRID_UNALIGNED_Y
            beq   :out                    ; Pad cell
            FIN
            DO    GRID_UNALIGNED_Y
            bit   #$0001                  ; Pad cell or edge cell (bit 0: the addresses are even, and
            bne   :special                ; span $1Bxx - $9Cxx, so no high bit is free)
            FIN
            tay
            DO    GRID_CELL_STATS
            inc   tmp7
            FIN
            ldx   tmp5
            DO    GRID_CELL_STATS
            ldal  gqQuadWords,x
            clc
            adcl  gbExposeW
            stal  gbExposeW
            FIN
            jmp   (gridXQTbl,x)           ; The copy routine returns to the cell array
:out        rts
            DO    GRID_UNALIGNED_Y
:special    and   #$FFFE
            beq   :out                    ; Pad cell
            tay                           ; Edge cell: its visible lines, whatever the mask (X = cell)
            ldal  PPU_MEM+GRID_CELL_EQ,x
            lsr
            lsr
            lsr
            lsr
            tax
            jmp   (gridXETbl,x)           ; (by the cell's erase routine set: top or bottom)
            FIN

; Clear handler (after a full render).  Y = cell.  DBR = K.
            mx    %00
gqClearOp
            lda   #0
            sta   gqGrid,y
            rts

; Mark a whole cell for erase + expose.  X = cell.  DBR = K.
            mx    %00
gqMarkBg
            lda   gqGrid,x
            bne   :have
            txa
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   #0
:have       ora   #GQ_ERASE
            sta   gqGrid,x
            rts

; A = CIRAM address of a tile redrawn by an attribute update.  Y preserved.
            mx    %00
gqMarkCiram
            phy
            jsr   gridCiramToCell
            bcs   :off
            DO    GRID_STATS
            inc   gbMtCount
            FIN
            jsr   gqMarkBg
:off        ply
            rts

; Called after a full render: drawSprites marked the expose nibble, filled in the cell array and recorded
; the sprites, so just clear the cells and rotate the arrays.
            mx    %00
gridEndFull
            phb
            phk
            plb
            DO    GRID_STATS
            INC32 gsFullFrames
            FIN
            DO    GRID_SPRITE_SKIP
            jsr   gqSkipSync              ; Every sprite was drawn
            FIN
            lda   GridLPtr
            dec
            tax
            phk
            phk
            ply
            lda   #gqClearOp
            jsr   gqRunCells
            jsr   gqSwap
            plb
            rts

; Make this frame's records the previous ones and reset the per-frame arrays.  DBR = K.
            mx    %00
gqSwap
            lda   _ppuctrl                ; Records of 8x16 sprites can't be skipped next frame
            and   #NES_PPUCTRL_SPRSIZE
            sta   gqPrevTall
            lda   gqRecBase
            sta   gqPrevBase
            lda   gqRecEnd
            sta   gqPrevEnd
            lda   gqRecBase
            cmp   #gqRec
            beq   :second
            lda   #gqRec
            bra   :set
:second     lda   #gqRec+GQ_RECBYTES
:set        sta   gqRecBase
            sta   gqRecPtr
            sta   gqRecEnd
            lda   #gqCode+1
            sta   GridLPtr
            stz   gmtEnd
            stz   gmtOverflow
            rts

; ---------------------------------------------------------------------------
; Unchanged-sprite skip (GRID_SPRITE_SKIP, 8x8 sprites only)
; ---------------------------------------------------------------------------
; A sprite whose 4 OAM bytes match the previous frame's (same index) is "unchanged".  Its old record
; erases nothing and it is not redrawn -- unless the area being redrawn reaches it:
;
;   erase set = old positions of changed / vanished sprites + background / attribute cells
;   cascade   = an unchanged sprite with a quadrant in the erase set, or under a changed sprite's new
;               position (marked in the expose nibble), is redrawn, and its quadrants join the erase set
;               (repeat until nothing new joins)
;
; Every drawn sprite then has all of its quadrants erased first, so the draw order is preserved, and an
; unchanged sprite outside the erase set keeps its pixels on screen untouched.  Skipped sprites still
; record themselves for the next frame (gridRecordSprite8).

; Per sprite (X = OAM offset): changed test.  An unchanged sprite gets its cell / table index and skip flag
; and its old record turned into a no-op; a changed one only updates GQ_PREV_OAM.  DBR = K.
            mx    %00
gqSkipPrepare
            stz   gqUnch
            lda   _ppuctrl
            and   #NES_PPUCTRL_SPRSIZE
            ora   gqPrevTall
            beq   :go
            jmp   gqSkipSync              ; 8x16 now or last frame: no skipping
:go
            DO    1-SPR_PIXEL_SHIFT
            lda   _ppuscroll_x            ; The scroll's parity changed since the sprites were drawn (the
            eor   gqLastPar               ; byte it shows didn't): a sprite at an odd pixel moves a byte
            and   #$0001                  ; even if its OAM bytes didn't change, so none is skipped
            beq   *+5
            jmp   gqSkipSync
            FIN
            lda   gqPrevBase
            sta   gqRecK                  ; Previous frame's record of sprite 0
            ldx   #0
:loop       cpx   spriteCount
            bcs   :inv
            lda   OAM_COPY,x
            cmpl  PPU_MEM+GQ_PREV_OAM,x
            bne   :chg
            lda   OAM_COPY+2,x
            cmpl  PPU_MEM+GQ_PREV_OAM+2,x
            bne   :chg
            jsr   gqCellIdx               ; Unchanged: cell / pattern, skip flag
            DO    GRID_UNALIGNED_Y        ; A sprite that touches an edge row is never skipped: the edge
            cpy   gqEdgeLo                ; copies ignore the quadrant masks, so they can reach any of
            bcc   :chg                    ; its quadrants (gqCellIdx kept X)
            cpy   gqEdgeHi
            bcs   :chg
            FIN
            ora   #$0100
            sta   gqSI,x
            tya
            sta   gqSC,x
            ldy   gqRecK
            lda   #gqRepNop               ; Its old record erases nothing
            sta:  $0004,y
            inc   gqUnch
            bra   :nx
:chg        lda   OAM_COPY,x
            stal  PPU_MEM+GQ_PREV_OAM,x
            lda   OAM_COPY+2,x
            stal  PPU_MEM+GQ_PREV_OAM+2,x
:nx         lda   gqRecK
            clc
            adc   #GQ_RENTRY
            sta   gqRecK
            inx
            inx
            inx
            inx
            bra   :loop
:inv        lda   #$FFFF                  ; Entries past the count were not drawn: never match
:il         cpx   gqOAMEnd
            bcs   :id
            stal  PPU_MEM+GQ_PREV_OAM,x
            inx
            inx
            inx
            inx
            bra   :il
:id         lda   spriteCount
            sta   gqOAMEnd
            rts

; Cell and pattern of sprite X (OAM offset, preserved): A = pattern * 2, Y = cell.  DBR = K.
            mx    %00
gqCellIdx
            stx   gqLoopX
            sep   #$30
            mx    %11
            DO    SPR_PIXEL_SHIFT
            lda   OAM_COPY+3,x
            FIN
            DO    1-SPR_PIXEL_SHIFT
            lda   _ppuscroll_x            ; the pixel the sprite is drawn at: + the scroll's parity
            and   #$01
            clc
            adc   OAM_COPY+3,x
            bcc   *+4
            lda   #$FF
            FIN
            tay
            lda   OAM_COPY,x
            tax
            DO    GRID_UNALIGNED_Y
gqPRL3
            FIN
            lda:  gridRowLo,x             ; (gridSetPhase patches the three table bases by j)
            clc
            adc   gridColOff,y
            sta   gqCell
            DO    GRID_UNALIGNED_Y
gqPRH3
            FIN
            lda:  gridRowHi,x
            adc   #0
            sta   gqCell+1
            DO    GRID_UNALIGNED_Y
gqPKC3
            FIN
            lda:  gridKCls,x
            ora   gridPCls,y
            rep   #$30
            mx    %00
            and   #$00FF
            ldy   gqCell
            ldx   gqLoopX
            rts

; GQ_PREV_OAM := OAM_COPY (every sprite was drawn), entries past the count invalidated.  DBR = K.
;
; Not needed while the sprites are 8x16: they are never skipped, and the first 8x8 frame after them
; comes here anyway (gqPrevTall), so GQ_PREV_OAM is only read after it has been synced again.
            mx    %00
gqSkipSync
            stz   gqUnch
            lda   _ppuctrl
            and   #NES_PPUCTRL_SPRSIZE
            beq   *+3
            rts
            ldx   #0
:cp         cpx   spriteCount
            bcs   :inv
            lda   OAM_COPY,x
            stal  PPU_MEM+GQ_PREV_OAM,x
            lda   OAM_COPY+2,x
            stal  PPU_MEM+GQ_PREV_OAM+2,x
            inx
            inx
            inx
            inx
            bra   :cp
:inv        lda   #$FFFF
:il         cpx   gqOAMEnd
            bcs   :id
            stal  PPU_MEM+GQ_PREV_OAM,x
            inx
            inx
            inx
            inx
            bra   :il
:id         lda   spriteCount
            sta   gqOAMEnd
            rts

; After the replay and the background marks: mark changed sprites' new positions (expose nibble), then
; the cascade.  Nothing to do when no sprite is unchanged.  DBR = K.
            mx    %00
gqSkipCascade
            lda   gqUnch
            bne   *+3
            rts
            ldx   #0
:c1         cpx   spriteCount
            bcs   :casc
            lda   gqSkip,x
            cmp   #$0100
            bcs   :c1n
            jsr   gqCellIdx               ; Changed sprite: its new position, for detection only
            tax
            jsr   (gqH8Tbl,x)
            ldx   gqLoopX
:c1n        inx
            inx
            inx
            inx
            bra   :c1
:casc       stz   gqMore
            ldx   #0
:c2         cpx   spriteCount
            bcs   :c2e
            lda   gqSkip,x
            cmp   #$0100
            bcc   :c2n
            stx   gqLoopX
            ldy   gqSC,x
            lda   gqSI,x
            and   #$00FF
            tax
            lda   gqGrid,y                ; Any of its quadrants being erased, or under a changed sprite?
            and   gqX8TL,x
            bne   :hit
            lda   gqGrid+2,y
            and   gqX8TR,x
            bne   :hit
            lda   gqGrid+GQ_PITCH2,y
            and   gqX8BL,x
            bne   :hit
            lda   gqGrid+GQ_PITCH2+2,y
            and   gqX8BR,x
            bne   :hit
            ldx   gqLoopX
            bra   :c2n
:hit        jsr   (gqR8LTbl,x)            ; Redraw it: its quadrants join the erase set
            stx   GridLPtr
            ldx   gqLoopX
            lda   gqSkip,x
            and   #$00FF
            sta   gqSkip,x
            inc   gqMore
:c2n        inx
            inx
            inx
            inx
            bra   :c2
:c2e        lda   gqMore
            bne   :casc
            rts

; After drawSprites: no skip flags outside the dirty-frame draw.  DBR = K.
            mx    %00
gqSkipClear
            lda   gqUnch
            beq   :out
            ldx   #0
:l          cpx   spriteCount
            bcs   :out
            lda   gqSkip,x
            and   #$00FF
            sta   gqSkip,x
            inx
            inx
            inx
            inx
            bra   :l
:out        rts

; Record a skipped sprite for the next frame, from the cell / pattern gqSkipPrepare computed.  Called from
; drawSprites (DBR = tiledata).  X = OAM offset, preserved.
            mx    %00
gridRecordSprite8
            phx
            phb
            phk
            plb
            ldy   gqRecPtr
            lda   gqSC,x
            sta:  $0001,y
            lda   gqSI,x
            and   #$00FF                  ; (drop the skip flag)
            tax
            lda   gqR8Tbl,x
            sta:  $0004,y
            tya                           ; The next record down: the sprites are drawn last to first
            sec
            sbc   #GQ_RENTRY
            sta   gqRecPtr
            plb
            plx
            rts

; A sprite that is hidden entirely (sprClipTop) is not marked: its record erases nothing next frame.
; Called from drawSprites (any DBR).  X = OAM offset, preserved.
            mx    %00
gridRecordNone
            phx
            phb
            phk
            plb
            ldy   gqRecPtr
            lda   #gqRepNop
            sta:  $0004,y
            tya                           ; The next record down: the sprites are drawn last to first
            sec
            sbc   #GQ_RENTRY
            sta   gqRecPtr
            plb
            plx
            rts

; The records are in OAM_COPY order, one per sprite, so gqSkipPrepare finds sprite k's record at entry k.
; drawSprites draws the sprites from the last to the first, and every sprite writes exactly one record
; (gridMarkSprite8/16, gridRecordSprite8 or gridRecordNone), so the write pointer starts at the last
; sprite's entry and moves down one entry per sprite.  A path that skipped a record would put the
; records out of step.  Set the end of this frame's records (where the replay pokes its RTS) and the
; write pointer from the sprite count.  Called from drawSprites (any DBR).  A is trashed.
            mx    %00
gridRecordsBegin
            ldal  spriteCount             ; count * 4
            pha
            lsr                           ; count * 2 (C = 0)
            adc   1,s                     ; 6 * count = GQ_RENTRY * count
            adcl  gqRecBase
            stal  gqRecEnd
            sec
            sbc   #GQ_RENTRY              ; the last sprite's entry
            stal  gqRecPtr
            pla
            rts

gqRepNop    rts

; The quadrant copy routines and their dispatch tables (gridEQTbl / gridXQTbl) are in ppu_grid_marks.s
            DO    GRID_CELL_STATS
gqQuadWords dw    0,4,4,8,4,8,8,12,4,8,8,12,8,12,12,16   ; words copied per mask (4 per quadrant)
            FIN


; Class of a sprite's line k or pixel p in its cell: {0}, {1-3}, {4}, {5-7} (the patterns, ppu_grid_marks.s)
gqClsTbl    db    0,1,1,1,2,3,3,3,0

gqCell      dw    0
gqEraseEnd  dw    0
gqRunEnd    dw    0
gqRecBase   dw    0
gqRecPtr    dw    0                         ; Write pointer (moves down: see gridRecordsBegin)
gqRecEnd    dw    0                         ; End of this frame's records
gqPrevBase  dw    0
gqPrevEnd   dw    0
gbErase     dw    0
gbExpose    dw    0
gbEraseW    dw    0                         ; (GRID_CELL_STATS) words erased / exposed this frame
gbExposeW   dw    0

; The OAM coordinate tables gridRowLo, gridRowHi, gridKCls, gridColOff and gridPCls (read with 8-bit
; index registers in gridMarkSprite8/16) and gqSC / gqSI / gqSkip are in core/Data.s, page-aligned
gqRec       ds    GQ_RECBYTES*2           ; Two record code arrays (current / previous)
gqCode      ds    GQ_CODEBYTES            ; Cell code array
gqGrid      ds    GQ_BYTES
gqOAMEnd    dw    256
gqPrevTall  dw    1                       ; (no skipping before the first full frame)
gqUnch      dw    0                       ; Unchanged sprites this frame (0: no skipping, no cascade)
gqRecK      dw    0
gqLoopX     dw    0
gqLastPar   dw    0                         ; scroll_x & 1 when the sprites were last drawn (no SPR_PIXEL_SHIFT)
gqMore      dw    0

            FIN

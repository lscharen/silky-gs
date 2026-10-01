; ppu_grid_quads.s - Grid dirty renderer, quadrant masks (GRID_QUADS)
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
; indexed by the OAM coordinates give the cell offset and the table index (k * 8 + b * 2, k = y & 7,
; b = x/2 & 3), and the quadrant tables give each of the sprite's cells directly.
;
; Lists are code.  The cells touched this frame form an array of "ldy #cell / jsr gqCellOp" entries: a
; cell's first touch just stores its index into the next entry's operand.  A pass patches gqCellOp to
; jump to its handler, pokes an RTS over the first unused entry and calls the array:
;
;   erase:  copy the erase quadrants, then move them up into the expose nibble
;   expose: copy the expose quadrants, then zero the cell (this is also the end-of-frame clear)
;
; The sprites drawn this frame are recorded the same way, as "ldx #index / ldy #cell / jsr gqRep8|16"
; entries, so the next frame replays them into the erase nibble by calling the array.

            DO    GRID_DIRTY_RENDERING
            DO    GRID_QUADS

GQ_ROWS     equ   {GRID_ROWS+4}             ; Pad row above, playfield rows, pad rows below (8x16 reach)
GQ_BYTES    equ   {GQ_ROWS*GQ_PITCH2}
GQ_PITCH2X2 equ   {GQ_PITCH2*2}
GQ_MAXREC   equ   64                        ; One record per OAM entry
GQ_TALL     equ   $8000                     ; 8x16 sprite
GQ_MAXCELLS equ   {GQ_MAXREC*6*2}+GRID_MAX_BG_TILES+{GRID_MAX_METATILES*4}  ; old + new sprite cells, BG, metatiles
GQ_ENTRY    equ   6                         ; ldy #cell / jsr gqCellOp
GQ_CODEBYTES equ  {GQ_MAXCELLS+1}*GQ_ENTRY  ; +1 entry for the RTS
GQ_RENTRY   equ   9                         ; ldx #index / ldy #cell / jsr gqRep8|16
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

; y (OAM, already +1): row offset in the padded grid (low / high bytes) and k * 8.  Rows above the
; playfield map to the pad row above it and rows below map to the pad rows below it.

            ldy   #0
:yl         tya
            sec
            sbc   #y_offset
            sta   gqCell                  ; s, signed
            and   #$0007
            asl
            asl
            asl
            sep   #$20
            sta   gridKIdx,y
            rep   #$20
            lda   gqCell
            bpl   :ypos
            lda   #0                      ; Above the playfield: pad row 0
            bra   :ymul
:ypos       lsr
            lsr
            lsr
            cmp   #GRID_ROWS
            bcc   *+5
            lda   #GRID_ROWS
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

; x (NES pixels): column offset and b * 2.  The scroll is always a multiple of 8 when the grid is used,
; so the half-pixel parity in :setupSprite is 0.

            ldy   #0
:xl         tya
            lsr                           ; IIgs byte
            pha
            lsr
            lsr
            asl
            sep   #$20
            sta   gridColOff,y
            rep   #$20
            pla
            and   #$0003
            asl
            sep   #$20
            sta   gridBIdx,y
            rep   #$20
            iny
            cpy   #256
            bcc   :xl

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

; Record code arrays: A2 00 00 / A0 00 00 / 20 <gqRep8> = ldx #0000 / ldy #0000 / jsr gqRep8

            ldx   #0
:rf         lda   #$00A2
            sta   gqRec,x
            lda   #$A000
            sta   gqRec+2,x
            lda   #$0000
            sta   gqRec+4,x
            lda   #gqRep8
            sta   gqRec+7,x
            sep   #$20
            lda   #$20
            sta   gqRec+6,x
            rep   #$20
            txa
            clc
            adc   #GQ_RENTRY
            tax
            cpx   #GQ_RECBYTES*2
            bcc   :rf

            lda   #gqRec                  ; Current records in the first array, none previous
            sta   gqRecBase
            sta   gqRecPtr
            lda   #gqRec+GQ_RECBYTES
            sta   gqPrevBase
            sta   gqPrevEnd
            lda   #gqCode+1               ; Empty cell array (points at the first operand)
            sta   GridLPtr
            plb
            rts

; ---------------------------------------------------------------------------
; gridMarkSprite8 / gridMarkSprite16 -- called from drawSprites (any DBR).  X = OAM_COPY index (preserved)
; ---------------------------------------------------------------------------
            mx    %00
gridMarkSprite8
            phx
            phb
            phk
            plb

            sep   #$30                    ; 8-bit: the coordinates index the byte tables directly
            mx    %11
            lda   OAM_COPY,x              ; Y-coordinate (already adjusted by +1)
            ldy   OAM_COPY+3,x            ; X-coordinate
            tax
            lda   gridRowLo,x             ; cell = row offset + column offset
            clc
            adc   gridColOff,y
            sta   gqCell
            lda   gridRowHi,x
            adc   #0
            sta   gqCell+1
            lda   gridKIdx,x              ; table index = k * 8 + b * 2
            ora   gridBIdx,y
            tax
            rep   #$30                    ; X high byte is 0
            mx    %00

            ldy   gqRecPtr                ; Record "ldx #index / ldy #cell / jsr gqRep8" for the next frame
            txa
            sta:  $0001,y
            lda   gqCell
            sta:  $0004,y
            lda   #gqRep8
            sta:  $0007,y
            tya
            clc
            adc   #GQ_RENTRY
            sta   gqRecPtr
            ldy   gqCell

            lda   gqGrid,y
            bne   :h1
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHTL,x
            sta   gqGrid,y
            bra   :d1
:h1       ora   gqHTL,x
            sta   gqGrid,y
:d1
            lda   gqHTR,x
            beq   :done_r
            lda   gqGrid+2,y
            bne   :h2
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHTR,x
            sta   gqGrid+2,y
            bra   :d2
:h2       ora   gqHTR,x
            sta   gqGrid+2,y
:d2
:done_r
            lda   gqHBL,x
            beq   :done
            lda   gqGrid+GQ_PITCH2,y
            bne   :h3
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHBL,x
            sta   gqGrid+GQ_PITCH2,y
            bra   :d3
:h3       ora   gqHBL,x
            sta   gqGrid+GQ_PITCH2,y
:d3
            lda   gqHBR,x
            beq   :done
            lda   gqGrid+GQ_PITCH2+2,y
            bne   :h4
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2+2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHBR,x
            sta   gqGrid+GQ_PITCH2+2,y
            bra   :d4
:h4       ora   gqHBR,x
            sta   gqGrid+GQ_PITCH2+2,y
:d4
:done
            plb
            plx
            rts

            mx    %00
gridMarkSprite16
            phx
            phb
            phk
            plb

            sep   #$30                    ; 8-bit: the coordinates index the byte tables directly
            mx    %11
            lda   OAM_COPY,x              ; Y-coordinate (already adjusted by +1)
            ldy   OAM_COPY+3,x            ; X-coordinate
            tax
            lda   gridRowLo,x             ; cell = row offset + column offset
            clc
            adc   gridColOff,y
            sta   gqCell
            lda   gridRowHi,x
            adc   #0
            sta   gqCell+1
            lda   gridKIdx,x              ; table index = k * 8 + b * 2
            ora   gridBIdx,y
            tax
            rep   #$30                    ; X high byte is 0
            mx    %00

            ldy   gqRecPtr                ; Record "ldx #index / ldy #cell / jsr gqRep16" for the next frame
            txa
            sta:  $0001,y
            lda   gqCell
            sta:  $0004,y
            lda   #gqRep16
            sta:  $0007,y
            tya
            clc
            adc   #GQ_RENTRY
            sta   gqRecPtr
            ldy   gqCell

            lda   gqGrid,y
            bne   :h5
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHTL,x
            sta   gqGrid,y
            bra   :d5
:h5       ora   gqHTL,x
            sta   gqGrid,y
:d5
            lda   gqHTR,x
            beq   :done_r
            lda   gqGrid+2,y
            bne   :h6
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHTR,x
            sta   gqGrid+2,y
            bra   :d6
:h6       ora   gqHTR,x
            sta   gqGrid+2,y
:d6
:done_r
            lda   gqGrid+GQ_PITCH2,y
            bne   :h7
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHFL,x
            sta   gqGrid+GQ_PITCH2,y
            bra   :d7
:h7       ora   gqHFL,x
            sta   gqGrid+GQ_PITCH2,y
:d7
            lda   gqHFR,x
            beq   :done_f
            lda   gqGrid+GQ_PITCH2+2,y
            bne   :h8
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2+2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHFR,x
            sta   gqGrid+GQ_PITCH2+2,y
            bra   :d8
:h8       ora   gqHFR,x
            sta   gqGrid+GQ_PITCH2+2,y
:d8
:done_f
            lda   gqHBL,x
            beq   :done
            lda   gqGrid+GQ_PITCH2X2,y
            bne   :h9
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2X2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHBL,x
            sta   gqGrid+GQ_PITCH2X2,y
            bra   :d9
:h9       ora   gqHBL,x
            sta   gqGrid+GQ_PITCH2X2,y
:d9
            lda   gqHBR,x
            beq   :done
            lda   gqGrid+GQ_PITCH2X2+2,y
            bne   :h10
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2X2+2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHBR,x
            sta   gqGrid+GQ_PITCH2X2+2,y
            bra   :d10
:h10       ora   gqHBR,x
            sta   gqGrid+GQ_PITCH2X2+2,y
:d10
:done
            plb
            plx
            rts

; ---------------------------------------------------------------------------
; Record replay: X = table index, Y = cell.  Marks the erase nibble.  DBR = K.
; ---------------------------------------------------------------------------
            mx    %00
gqRep8
            lda   gqGrid,y
            bne   :h11
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLTL,x
            sta   gqGrid,y
            bra   :d11
:h11       ora   gqLTL,x
            sta   gqGrid,y
:d11
            lda   gqLTR,x
            beq   :done_r
            lda   gqGrid+2,y
            bne   :h12
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLTR,x
            sta   gqGrid+2,y
            bra   :d12
:h12       ora   gqLTR,x
            sta   gqGrid+2,y
:d12
:done_r
            lda   gqLBL,x
            beq   :done
            lda   gqGrid+GQ_PITCH2,y
            bne   :h13
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLBL,x
            sta   gqGrid+GQ_PITCH2,y
            bra   :d13
:h13       ora   gqLBL,x
            sta   gqGrid+GQ_PITCH2,y
:d13
            lda   gqLBR,x
            beq   :done
            lda   gqGrid+GQ_PITCH2+2,y
            bne   :h14
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2+2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLBR,x
            sta   gqGrid+GQ_PITCH2+2,y
            bra   :d14
:h14       ora   gqLBR,x
            sta   gqGrid+GQ_PITCH2+2,y
:d14
:done
            rts

            mx    %00
gqRep16
            lda   gqGrid,y
            bne   :h15
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLTL,x
            sta   gqGrid,y
            bra   :d15
:h15       ora   gqLTL,x
            sta   gqGrid,y
:d15
            lda   gqLTR,x
            beq   :done_r
            lda   gqGrid+2,y
            bne   :h16
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLTR,x
            sta   gqGrid+2,y
            bra   :d16
:h16       ora   gqLTR,x
            sta   gqGrid+2,y
:d16
:done_r
            lda   gqGrid+GQ_PITCH2,y
            bne   :h17
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLFL,x
            sta   gqGrid+GQ_PITCH2,y
            bra   :d17
:h17       ora   gqLFL,x
            sta   gqGrid+GQ_PITCH2,y
:d17
            lda   gqLFR,x
            beq   :done_f
            lda   gqGrid+GQ_PITCH2+2,y
            bne   :h18
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2+2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLFR,x
            sta   gqGrid+GQ_PITCH2+2,y
            bra   :d18
:h18       ora   gqLFR,x
            sta   gqGrid+GQ_PITCH2+2,y
:d18
:done_f
            lda   gqLBL,x
            beq   :done
            lda   gqGrid+GQ_PITCH2X2,y
            bne   :h19
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2X2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLBL,x
            sta   gqGrid+GQ_PITCH2X2,y
            bra   :d19
:h19       ora   gqLBL,x
            sta   gqGrid+GQ_PITCH2X2,y
:d19
            lda   gqLBR,x
            beq   :done
            lda   gqGrid+GQ_PITCH2X2+2,y
            bne   :h20
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            clc
            adc   #GQ_PITCH2X2+2
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqLBR,x
            sta   gqGrid+GQ_PITCH2X2+2,y
            bra   :d20
:h20       ora   gqLBR,x
            sta   gqGrid+GQ_PITCH2X2+2,y
:d20
:done
            rts

; ---------------------------------------------------------------------------
; gridDrawDirty
; ---------------------------------------------------------------------------
            mx    %00
gridDrawDirty
            phb
            phk
            plb

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
:rjsr       jsr   $0000
            ldx   gqPrevEnd
            sep   #$20
            mx    %10
            lda   #$A2                    ; Restore the template
            sta:  $0000,x
            rep   #$20
            mx    %00
:rdone

; 2. Background tiles and attribute-driven metatiles: whole cells

            stz   gbBgCount
            ldy   prev_nt_list_start
            bra   :t2
:l2         lda   nt_list,y
            phy
            jsr   gridCiramToCell
            bcs   :skip2
            inc   gbBgCount
            jsr   gqMarkBg
:skip2      ply
            iny
            iny
:t2         cpy   prev_nt_list_end
            bcc   :l2

            stz   gbMtCount
            ldy   #0
            bra   :t3
:l3         phy
            lda   gmtList,y
            jsr   gqMarkCiram             ; top-left
            lda   gmtList,y
            inc
            jsr   gqMarkCiram             ; top-right
            lda   gmtList,y
            clc
            adc   #32
            jsr   gqMarkCiram             ; bottom-left
            lda   gmtList,y
            clc
            adc   #33
            jsr   gqMarkCiram             ; bottom-right
            ply
            iny
            iny
:t3         cpy   gmtEnd
            bcc   :l3
            tya
            lsr
            ADD32 gsMetatiles

; 3. Erase (shadowing off) every cell listed so far.  The erase handler leaves DBR on the last code
;    field bank it used; tmp4 tracks it.

            jsr   _ShadowOff
            stz   tmp4                    ; No code field bank selected yet
            stz   tmp7                    ; Cells erased (GRID_CELL_STATS)
            lda   GridLPtr
            dec
            tax                           ; Opcode of the first unused entry
            phk
            phk
            ply                           ; Run with DBR = K
            lda   #gqEraseOp
            jsr   gqRunCells
            lda   tmp7
            sta   gbErase

; 4. New sprites (mark the expose nibble, extend the cell array and record themselves)

            jsr   drawSprites
            jsr   _ShadowOn

; 5. Expose and clear every cell

            stz   tmp7                    ; Cells exposed (GRID_CELL_STATS)
            lda   GridLPtr
            dec
            tax
            ldy   #$0101                  ; Run with DBR = $01 (the expose routines index the SHR page)
            lda   #gqExposeOp
            jsr   gqRunCells
            lda   tmp7
            sta   gbExpose

; Statistics

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
:no_mt      jsr   gridSpriteTiles
            sta   gsLastSprTiles
            ADD32 gsSprTiles

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
            phk                           ; The handlers may leave DBR anywhere
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

; Erase handler.  Y = cell.  Every entry in the erase range was appended by a replay or background mark, so
; it always has erase bits.  DBR = K or a code field bank (everything here is long or direct page).
            mx    %00
gqEraseOp
            tyx
            ldal  gqGrid,x
            sta   tmp5
            xba                           ; Erase bits -> expose bits
            and   #GQ_EXPOSE
            ora   tmp5
            and   #$FF00
            stal  gqGrid,x
            ldal  PPU_MEM+GRID_CELL_SCR,x
            beq   :out                    ; Pad cell
            sta   tmp6
            ldal  PPU_MEM+GRID_CELL_BANK,x
            cmp   tmp4
            beq   :same
            sta   tmp4
            pha
            plb
            plb                           ; DBR = code field bank
:same
            DO    GRID_CELL_STATS
            inc   tmp7
            FIN
            ldal  PPU_MEM+GRID_CELL_PEA,x
            tay                           ; Y = code field address
            lda   tmp5
            and   #GQ_ERASE
            tax
            ldal  gridEQTbl,x
            stal  :pp+1
            ldx   tmp6                    ; X = SHR address
:pp         jmp   $0000                   ; The copy routine returns to the cell array
:out        rts

; Expose handler.  Y = cell.  DBR = $01, so the grid and cell tables are reached with long addressing and
; the copy routine is entered with an indexed indirect jump (Y = SHR address).
            mx    %00
gqExposeOp
            tyx
            ldal  gqGrid,x
            and   #GQ_EXPOSE
            xba
            sta   tmp5                    ; mask * 2
            lda   #0
            stal  gqGrid,x
            ldal  PPU_MEM+GRID_CELL_SCR,x
            beq   :out                    ; Pad cell
            tay
            DO    GRID_CELL_STATS
            inc   tmp7
            FIN
            ldx   tmp5
            jmp   (gridXQTbl,x)           ; The copy routine returns to the cell array
:out        rts

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
            inc   gbMtCount
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
            INC32 gsFullFrames
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
            lda   gqRecBase
            sta   gqPrevBase
            lda   gqRecPtr
            sta   gqPrevEnd
            lda   gqRecBase
            cmp   #gqRec
            beq   :second
            lda   #gqRec
            bra   :set
:second     lda   #gqRec+GQ_RECBYTES
:set        sta   gqRecBase
            sta   gqRecPtr
            lda   #gqCode+1
            sta   GridLPtr
            stz   gmtEnd
            stz   gmtOverflow
            rts

; ---------------------------------------------------------------------------
; Copy routines: one per quadrant mask
; ---------------------------------------------------------------------------
; Erase: X = SHR address, Y = code field address, DBR = code field bank.  Expose: Y = SHR address,
; DBR = $01.  Both return straight to the cell code array.
gridQE0
            rts
gridQE1
            lda:  {0*_LINE_SPAN}+4,y
            stal  $010000+{0*SHR_LINE_WIDTH},x
            lda:  {1*_LINE_SPAN}+4,y
            stal  $010000+{1*SHR_LINE_WIDTH},x
            lda:  {2*_LINE_SPAN}+4,y
            stal  $010000+{2*SHR_LINE_WIDTH},x
            lda:  {3*_LINE_SPAN}+4,y
            stal  $010000+{3*SHR_LINE_WIDTH},x
            rts
gridQE2
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            rts
gridQE3
            lda:  {0*_LINE_SPAN}+4,y
            stal  $010000+{0*SHR_LINE_WIDTH},x
            lda:  {1*_LINE_SPAN}+4,y
            stal  $010000+{1*SHR_LINE_WIDTH},x
            lda:  {2*_LINE_SPAN}+4,y
            stal  $010000+{2*SHR_LINE_WIDTH},x
            lda:  {3*_LINE_SPAN}+4,y
            stal  $010000+{3*SHR_LINE_WIDTH},x
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            rts
gridQE4
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            rts
gridQE5
            lda:  {0*_LINE_SPAN}+4,y
            stal  $010000+{0*SHR_LINE_WIDTH},x
            lda:  {1*_LINE_SPAN}+4,y
            stal  $010000+{1*SHR_LINE_WIDTH},x
            lda:  {2*_LINE_SPAN}+4,y
            stal  $010000+{2*SHR_LINE_WIDTH},x
            lda:  {3*_LINE_SPAN}+4,y
            stal  $010000+{3*SHR_LINE_WIDTH},x
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            rts
gridQE6
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            rts
gridQE7
            lda:  {0*_LINE_SPAN}+4,y
            stal  $010000+{0*SHR_LINE_WIDTH},x
            lda:  {1*_LINE_SPAN}+4,y
            stal  $010000+{1*SHR_LINE_WIDTH},x
            lda:  {2*_LINE_SPAN}+4,y
            stal  $010000+{2*SHR_LINE_WIDTH},x
            lda:  {3*_LINE_SPAN}+4,y
            stal  $010000+{3*SHR_LINE_WIDTH},x
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            rts
gridQE8
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            rts
gridQE9
            lda:  {0*_LINE_SPAN}+4,y
            stal  $010000+{0*SHR_LINE_WIDTH},x
            lda:  {1*_LINE_SPAN}+4,y
            stal  $010000+{1*SHR_LINE_WIDTH},x
            lda:  {2*_LINE_SPAN}+4,y
            stal  $010000+{2*SHR_LINE_WIDTH},x
            lda:  {3*_LINE_SPAN}+4,y
            stal  $010000+{3*SHR_LINE_WIDTH},x
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            rts
gridQE10
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            rts
gridQE11
            lda:  {0*_LINE_SPAN}+4,y
            stal  $010000+{0*SHR_LINE_WIDTH},x
            lda:  {1*_LINE_SPAN}+4,y
            stal  $010000+{1*SHR_LINE_WIDTH},x
            lda:  {2*_LINE_SPAN}+4,y
            stal  $010000+{2*SHR_LINE_WIDTH},x
            lda:  {3*_LINE_SPAN}+4,y
            stal  $010000+{3*SHR_LINE_WIDTH},x
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            rts
gridQE12
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            rts
gridQE13
            lda:  {0*_LINE_SPAN}+4,y
            stal  $010000+{0*SHR_LINE_WIDTH},x
            lda:  {1*_LINE_SPAN}+4,y
            stal  $010000+{1*SHR_LINE_WIDTH},x
            lda:  {2*_LINE_SPAN}+4,y
            stal  $010000+{2*SHR_LINE_WIDTH},x
            lda:  {3*_LINE_SPAN}+4,y
            stal  $010000+{3*SHR_LINE_WIDTH},x
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            rts
gridQE14
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            rts
gridQE15
            lda:  {0*_LINE_SPAN}+4,y
            stal  $010000+{0*SHR_LINE_WIDTH},x
            lda:  {1*_LINE_SPAN}+4,y
            stal  $010000+{1*SHR_LINE_WIDTH},x
            lda:  {2*_LINE_SPAN}+4,y
            stal  $010000+{2*SHR_LINE_WIDTH},x
            lda:  {3*_LINE_SPAN}+4,y
            stal  $010000+{3*SHR_LINE_WIDTH},x
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            rts
gridQX0
            rts
gridQX1
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
            rts
gridQX2
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
            rts
gridQX3
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
            rts
gridQX4
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            rts
gridQX5
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            rts
gridQX6
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            rts
gridQX7
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            rts
gridQX8
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            rts
gridQX9
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            rts
gridQX10
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            rts
gridQX11
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            rts
gridQX12
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            rts
gridQX13
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            rts
gridQX14
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            rts
gridQX15
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            rts
gridEQTbl   dw    gridQE0,gridQE1,gridQE2,gridQE3,gridQE4,gridQE5,gridQE6,gridQE7,gridQE8,gridQE9,gridQE10,gridQE11,gridQE12,gridQE13,gridQE14,gridQE15
gridXQTbl   dw    gridQX0,gridQX1,gridQX2,gridQX3,gridQX4,gridQX5,gridQX6,gridQX7,gridQX8,gridQX9,gridQX10,gridQX11,gridQX12,gridQX13,gridQX14,gridQX15

; ---------------------------------------------------------------------------
; Tables
; ---------------------------------------------------------------------------
; Quadrants per cell, indexed by k * 8 + b * 2.  T = first cell row, B = next cell row, F = full middle row
; of an 8x16 sprite (depends only on b); L = the cell the sprite starts in, R = the cell to its right.
; gqL* mark the erase nibble (bits 1-4) when replaying records, gqH* the expose nibble (bits 9-12).
gqLTL
            dw    $001E,$001E,$0014,$0014   ; k = 0
            dw    $001E,$001E,$0014,$0014   ; k = 1
            dw    $001E,$001E,$0014,$0014   ; k = 2
            dw    $001E,$001E,$0014,$0014   ; k = 3
            dw    $0018,$0018,$0010,$0010   ; k = 4
            dw    $0018,$0018,$0010,$0010   ; k = 5
            dw    $0018,$0018,$0010,$0010   ; k = 6
            dw    $0018,$0018,$0010,$0010   ; k = 7
gqLTR
            dw    $0000,$000A,$000A,$001E   ; k = 0
            dw    $0000,$000A,$000A,$001E   ; k = 1
            dw    $0000,$000A,$000A,$001E   ; k = 2
            dw    $0000,$000A,$000A,$001E   ; k = 3
            dw    $0000,$0008,$0008,$0018   ; k = 4
            dw    $0000,$0008,$0008,$0018   ; k = 5
            dw    $0000,$0008,$0008,$0018   ; k = 6
            dw    $0000,$0008,$0008,$0018   ; k = 7
gqLBL
            dw    $0000,$0000,$0000,$0000   ; k = 0
            dw    $0006,$0006,$0004,$0004   ; k = 1
            dw    $0006,$0006,$0004,$0004   ; k = 2
            dw    $0006,$0006,$0004,$0004   ; k = 3
            dw    $0006,$0006,$0004,$0004   ; k = 4
            dw    $001E,$001E,$0014,$0014   ; k = 5
            dw    $001E,$001E,$0014,$0014   ; k = 6
            dw    $001E,$001E,$0014,$0014   ; k = 7
gqLBR
            dw    $0000,$0000,$0000,$0000   ; k = 0
            dw    $0000,$0002,$0002,$0006   ; k = 1
            dw    $0000,$0002,$0002,$0006   ; k = 2
            dw    $0000,$0002,$0002,$0006   ; k = 3
            dw    $0000,$0002,$0002,$0006   ; k = 4
            dw    $0000,$000A,$000A,$001E   ; k = 5
            dw    $0000,$000A,$000A,$001E   ; k = 6
            dw    $0000,$000A,$000A,$001E   ; k = 7
gqLFL
            dw    $001E,$001E,$0014,$0014   ; k = 0
            dw    $001E,$001E,$0014,$0014   ; k = 1
            dw    $001E,$001E,$0014,$0014   ; k = 2
            dw    $001E,$001E,$0014,$0014   ; k = 3
            dw    $001E,$001E,$0014,$0014   ; k = 4
            dw    $001E,$001E,$0014,$0014   ; k = 5
            dw    $001E,$001E,$0014,$0014   ; k = 6
            dw    $001E,$001E,$0014,$0014   ; k = 7
gqLFR
            dw    $0000,$000A,$000A,$001E   ; k = 0
            dw    $0000,$000A,$000A,$001E   ; k = 1
            dw    $0000,$000A,$000A,$001E   ; k = 2
            dw    $0000,$000A,$000A,$001E   ; k = 3
            dw    $0000,$000A,$000A,$001E   ; k = 4
            dw    $0000,$000A,$000A,$001E   ; k = 5
            dw    $0000,$000A,$000A,$001E   ; k = 6
            dw    $0000,$000A,$000A,$001E   ; k = 7
gqHTL
            dw    $1E00,$1E00,$1400,$1400   ; k = 0
            dw    $1E00,$1E00,$1400,$1400   ; k = 1
            dw    $1E00,$1E00,$1400,$1400   ; k = 2
            dw    $1E00,$1E00,$1400,$1400   ; k = 3
            dw    $1800,$1800,$1000,$1000   ; k = 4
            dw    $1800,$1800,$1000,$1000   ; k = 5
            dw    $1800,$1800,$1000,$1000   ; k = 6
            dw    $1800,$1800,$1000,$1000   ; k = 7
gqHTR
            dw    $0000,$0A00,$0A00,$1E00   ; k = 0
            dw    $0000,$0A00,$0A00,$1E00   ; k = 1
            dw    $0000,$0A00,$0A00,$1E00   ; k = 2
            dw    $0000,$0A00,$0A00,$1E00   ; k = 3
            dw    $0000,$0800,$0800,$1800   ; k = 4
            dw    $0000,$0800,$0800,$1800   ; k = 5
            dw    $0000,$0800,$0800,$1800   ; k = 6
            dw    $0000,$0800,$0800,$1800   ; k = 7
gqHBL
            dw    $0000,$0000,$0000,$0000   ; k = 0
            dw    $0600,$0600,$0400,$0400   ; k = 1
            dw    $0600,$0600,$0400,$0400   ; k = 2
            dw    $0600,$0600,$0400,$0400   ; k = 3
            dw    $0600,$0600,$0400,$0400   ; k = 4
            dw    $1E00,$1E00,$1400,$1400   ; k = 5
            dw    $1E00,$1E00,$1400,$1400   ; k = 6
            dw    $1E00,$1E00,$1400,$1400   ; k = 7
gqHBR
            dw    $0000,$0000,$0000,$0000   ; k = 0
            dw    $0000,$0200,$0200,$0600   ; k = 1
            dw    $0000,$0200,$0200,$0600   ; k = 2
            dw    $0000,$0200,$0200,$0600   ; k = 3
            dw    $0000,$0200,$0200,$0600   ; k = 4
            dw    $0000,$0A00,$0A00,$1E00   ; k = 5
            dw    $0000,$0A00,$0A00,$1E00   ; k = 6
            dw    $0000,$0A00,$0A00,$1E00   ; k = 7
gqHFL
            dw    $1E00,$1E00,$1400,$1400   ; k = 0
            dw    $1E00,$1E00,$1400,$1400   ; k = 1
            dw    $1E00,$1E00,$1400,$1400   ; k = 2
            dw    $1E00,$1E00,$1400,$1400   ; k = 3
            dw    $1E00,$1E00,$1400,$1400   ; k = 4
            dw    $1E00,$1E00,$1400,$1400   ; k = 5
            dw    $1E00,$1E00,$1400,$1400   ; k = 6
            dw    $1E00,$1E00,$1400,$1400   ; k = 7
gqHFR
            dw    $0000,$0A00,$0A00,$1E00   ; k = 0
            dw    $0000,$0A00,$0A00,$1E00   ; k = 1
            dw    $0000,$0A00,$0A00,$1E00   ; k = 2
            dw    $0000,$0A00,$0A00,$1E00   ; k = 3
            dw    $0000,$0A00,$0A00,$1E00   ; k = 4
            dw    $0000,$0A00,$0A00,$1E00   ; k = 5
            dw    $0000,$0A00,$0A00,$1E00   ; k = 6
            dw    $0000,$0A00,$0A00,$1E00   ; k = 7

gqCell      dw    0
gqEraseEnd  dw    0
gqRunEnd    dw    0
gqRecBase   dw    0
gqRecPtr    dw    0
gqPrevBase  dw    0
gqPrevEnd   dw    0
gbErase     dw    0
gbExpose    dw    0

; Byte tables read with 8-bit index registers in gridMarkSprite8/16: page-aligned so no indexed read
; crosses a page (no extra cycle).  The five tables are 256 bytes each, so one alignment covers them all.
            ds    \,$00
gridRowLo   ds    256                     ; Indexed by OAM y
gridRowHi   ds    256
gridKIdx    ds    256
gridColOff  ds    256                     ; Indexed by OAM x
gridBIdx    ds    256
gqRec       ds    GQ_RECBYTES*2           ; Two record code arrays (current / previous)
gqCode      ds    GQ_CODEBYTES            ; Cell code array
gqGrid      ds    GQ_BYTES

            FIN
            FIN

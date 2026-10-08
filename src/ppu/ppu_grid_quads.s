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

            DO    GRID_SPRITE_SKIP
            ldx   #62                     ; gqX* = gqL* | gqH* (cascade test tables)
:xo         lda   gqLTL,x
            ora   gqHTL,x
            sta   gqXTL,x
            lda   gqLTR,x
            ora   gqHTR,x
            sta   gqXTR,x
            lda   gqLBL,x
            ora   gqHBL,x
            sta   gqXBL,x
            lda   gqLBR,x
            ora   gqHBR,x
            sta   gqXBR,x
            dex
            dex
            bpl   :xo
            FIN

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

; Same as gqRep8 for the expose nibble: X = table index, Y = cell.  Used by the sprite skip to mark changed
; sprites' new positions before the cascade.  DBR = K.
            mx    %00
gqRepH8
            lda   gqGrid,y
            bne   :hH1
            tya                           ; First touch: fill in the next "ldy #cell" of the code array
            sta   (GridLPtr)
            lda   GridLPtr
            clc
            adc   #GQ_ENTRY
            sta   GridLPtr
            lda   gqHTL,x
            sta   gqGrid,y
            bra   :dH1
:hH1       ora   gqHTL,x
            sta   gqGrid,y
:dH1
            lda   gqHTR,x
            beq   :done_r
            lda   gqGrid+2,y
            bne   :hH2
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
            bra   :dH2
:hH2       ora   gqHTR,x
            sta   gqGrid+2,y
:dH2
:done_r
            lda   gqHBL,x
            beq   :done
            lda   gqGrid+GQ_PITCH2,y
            bne   :hH3
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
            bra   :dH3
:hH3       ora   gqHBL,x
            sta   gqGrid+GQ_PITCH2,y
:dH3
            lda   gqHBR,x
            beq   :done
            lda   gqGrid+GQ_PITCH2+2,y
            bne   :hH4
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
            bra   :dH4
:hH4       ora   gqHBR,x
            sta   gqGrid+GQ_PITCH2+2,y
:dH4
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

; 3. Erase (shadowing off) every cell listed so far.  The erase handler leaves DBR on the last code
;    field bank it used; tmp4 tracks it.

            jsr   _ShadowOff
            stz   tmp4                    ; No code field bank selected yet
            DO    GRID_CELL_STATS
            stz   tmp7                    ; Cells erased
            FIN
            lda   GridLPtr
            dec
            tax                           ; Opcode of the first unused entry
            phk
            phk
            ply                           ; Run with DBR = K
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
:no_mt      jsr   gridSpriteTiles
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
; and its old record turned into a no-op; a changed one only updates gqPrevOAM.  DBR = K.
            mx    %00
gqSkipPrepare
            stz   gqUnch
            lda   _ppuctrl
            and   #NES_PPUCTRL_SPRSIZE
            ora   gqPrevTall
            beq   :go
            jmp   gqSkipSync              ; 8x16 now or last frame: no skipping
:go         lda   gqPrevBase
            sta   gqRecK                  ; Previous frame's record of sprite 0
            ldx   #0
:loop       cpx   spriteCount
            bcs   :inv
            lda   OAM_COPY,x
            cmp   gqPrevOAM,x
            bne   :chg
            lda   OAM_COPY+2,x
            cmp   gqPrevOAM+2,x
            bne   :chg
            jsr   gqCellIdx               ; Unchanged: cell / index, skip flag
            ora   #$0100
            sta   gqSI,x
            tya
            sta   gqSC,x
            ldy   gqRecK
            lda   #gqRepNop               ; Its old record erases nothing
            sta:  $0007,y
            inc   gqUnch
            bra   :nx
:chg        lda   OAM_COPY,x
            sta   gqPrevOAM,x
            lda   OAM_COPY+2,x
            sta   gqPrevOAM+2,x
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
            sta   gqPrevOAM,x
            inx
            inx
            inx
            inx
            bra   :il
:id         lda   spriteCount
            sta   gqOAMEnd
            rts

; Cell and table index of sprite X (OAM offset, preserved): A = table index, Y = cell.  DBR = K.
            mx    %00
gqCellIdx
            stx   gqLoopX
            sep   #$30
            mx    %11
            lda   OAM_COPY+3,x
            tay
            lda   OAM_COPY,x
            tax
            lda   gridRowLo,x
            clc
            adc   gridColOff,y
            sta   gqCell
            lda   gridRowHi,x
            adc   #0
            sta   gqCell+1
            lda   gridKIdx,x
            ora   gridBIdx,y
            rep   #$30
            mx    %00
            and   #$00FF
            ldy   gqCell
            ldx   gqLoopX
            rts

; gqPrevOAM := OAM_COPY (every sprite was drawn), entries past the count invalidated.  DBR = K.
;
; Not needed while the sprites are 8x16: they are never skipped, and the first 8x8 frame after them
; comes here anyway (gqPrevTall), so gqPrevOAM is only read after it has been synced again.
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
            sta   gqPrevOAM,x
            lda   OAM_COPY+2,x
            sta   gqPrevOAM+2,x
            inx
            inx
            inx
            inx
            bra   :cp
:inv        lda   #$FFFF
:il         cpx   gqOAMEnd
            bcs   :id
            sta   gqPrevOAM,x
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
            jsr   gqRepH8
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
            and   gqXTL,x
            bne   :hit
            lda   gqGrid+2,y
            and   gqXTR,x
            bne   :hit
            lda   gqGrid+GQ_PITCH2,y
            and   gqXBL,x
            bne   :hit
            lda   gqGrid+GQ_PITCH2+2,y
            and   gqXBR,x
            bne   :hit
            ldx   gqLoopX
            bra   :c2n
:hit        jsr   gqRep8                  ; Redraw it: its quadrants join the erase set
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

; Record a skipped sprite for the next frame, from the cell / index gqSkipPrepare computed.  Called from
; drawSprites (DBR = tiledata).  X = OAM offset, preserved.
            mx    %00
gridRecordSprite8
            phx
            phb
            phk
            plb
            ldy   gqRecPtr
            lda   gqSI,x
            and   #$00FF                  ; (drop the skip flag)
            sta:  $0001,y
            lda   gqSC,x
            sta:  $0004,y
            lda   #gqRep8
            sta:  $0007,y
            tya
            clc
            adc   #GQ_RENTRY
            sta   gqRecPtr
            plb
            plx
            rts

gqRepNop    rts

; ---------------------------------------------------------------------------
; Copy routines: one per quadrant mask
; ---------------------------------------------------------------------------
; Erase: X = SHR address, Y = code field address, DBR = code field bank.  Expose: Y = SHR address,
; DBR = $01.  Both return straight to the cell code array.
; Each mask is its highest quadrant's block followed by the routine for the remaining quadrants,
; so the routines share their tails: a chain falls through to the next smaller mask, and ends with
; an RTS at mask 0 or a branch into a routine laid out earlier.  (Generated; every entry point copies
; exactly its mask's quadrants.)
gridQE14
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
gridQE6
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
gridQE2
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
gridQE0
            rts
gridQE12
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
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
gridQE10
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            bra   gridQE2
gridQE13
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
gridQE5
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
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
gridQE11
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
gridQE3
            lda:  {0*_LINE_SPAN}+1,y
            stal  $010000+{0*SHR_LINE_WIDTH}+2,x
            lda:  {1*_LINE_SPAN}+1,y
            stal  $010000+{1*SHR_LINE_WIDTH}+2,x
            lda:  {2*_LINE_SPAN}+1,y
            stal  $010000+{2*SHR_LINE_WIDTH}+2,x
            lda:  {3*_LINE_SPAN}+1,y
            stal  $010000+{3*SHR_LINE_WIDTH}+2,x
            bra   gridQE1
gridQE9
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
            bra   gridQE1
gridQE15
            lda:  {4*_LINE_SPAN}+1,y
            stal  $010000+{4*SHR_LINE_WIDTH}+2,x
            lda:  {5*_LINE_SPAN}+1,y
            stal  $010000+{5*SHR_LINE_WIDTH}+2,x
            lda:  {6*_LINE_SPAN}+1,y
            stal  $010000+{6*SHR_LINE_WIDTH}+2,x
            lda:  {7*_LINE_SPAN}+1,y
            stal  $010000+{7*SHR_LINE_WIDTH}+2,x
gridQE7
            lda:  {4*_LINE_SPAN}+4,y
            stal  $010000+{4*SHR_LINE_WIDTH},x
            lda:  {5*_LINE_SPAN}+4,y
            stal  $010000+{5*SHR_LINE_WIDTH},x
            lda:  {6*_LINE_SPAN}+4,y
            stal  $010000+{6*SHR_LINE_WIDTH},x
            lda:  {7*_LINE_SPAN}+4,y
            stal  $010000+{7*SHR_LINE_WIDTH},x
            bra   gridQE3
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

gridQX15
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
gridQX7
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
gridQX3
            lda:  {0*SHR_LINE_WIDTH}+2,y
            sta:  {0*SHR_LINE_WIDTH}+2,y
            lda:  {1*SHR_LINE_WIDTH}+2,y
            sta:  {1*SHR_LINE_WIDTH}+2,y
            lda:  {2*SHR_LINE_WIDTH}+2,y
            sta:  {2*SHR_LINE_WIDTH}+2,y
            lda:  {3*SHR_LINE_WIDTH}+2,y
            sta:  {3*SHR_LINE_WIDTH}+2,y
gridQX1
            lda:  {0*SHR_LINE_WIDTH},y
            sta:  {0*SHR_LINE_WIDTH},y
            lda:  {1*SHR_LINE_WIDTH},y
            sta:  {1*SHR_LINE_WIDTH},y
            lda:  {2*SHR_LINE_WIDTH},y
            sta:  {2*SHR_LINE_WIDTH},y
            lda:  {3*SHR_LINE_WIDTH},y
            sta:  {3*SHR_LINE_WIDTH},y
gridQX0
            rts
gridQX13
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
gridQX5
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
            bra   gridQX1
gridQX11
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            bra   gridQX3
gridQX9
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            bra   gridQX1
gridQX14
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
gridQX6
            lda:  {4*SHR_LINE_WIDTH},y
            sta:  {4*SHR_LINE_WIDTH},y
            lda:  {5*SHR_LINE_WIDTH},y
            sta:  {5*SHR_LINE_WIDTH},y
            lda:  {6*SHR_LINE_WIDTH},y
            sta:  {6*SHR_LINE_WIDTH},y
            lda:  {7*SHR_LINE_WIDTH},y
            sta:  {7*SHR_LINE_WIDTH},y
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
gridQX12
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
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
gridQX10
            lda:  {4*SHR_LINE_WIDTH}+2,y
            sta:  {4*SHR_LINE_WIDTH}+2,y
            lda:  {5*SHR_LINE_WIDTH}+2,y
            sta:  {5*SHR_LINE_WIDTH}+2,y
            lda:  {6*SHR_LINE_WIDTH}+2,y
            sta:  {6*SHR_LINE_WIDTH}+2,y
            lda:  {7*SHR_LINE_WIDTH}+2,y
            sta:  {7*SHR_LINE_WIDTH}+2,y
            bra   gridQX2
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
gqSC        ds    256                     ; Per OAM offset: +0 cell, +2 table index, +3 skip flag
gqSI        equ   gqSC+2                  ;   (byte; read as a word, the high byte is the skip flag)
gqSkip      equ   gqSC+2                  ;   word: table index | skip << 8 -- skip when >= $100
gqPrevOAM   ds    256                     ; OAM_COPY as last drawn
gqOAMEnd    dw    256
gqXTL       ds    64                      ; gqL* | gqH*: a sprite's quadrants in either nibble
gqXTR       ds    64
gqXBL       ds    64
gqXBR       ds    64
gqPrevTall  dw    1                       ; (no skipping before the first full frame)
gqUnch      dw    0                       ; Unchanged sprites this frame (0: no skipping, no cascade)
gqRecK      dw    0
gqLoopX     dw    0
gqMore      dw    0

            FIN
            FIN

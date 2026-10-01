; ppu_grid.s - Screen-aligned 8x8 grid dirty renderer
;
; See BG_TILE_DIRTY_PLAN.md for the design.  Summary:
;
; The playfield is divided into a fixed grid of 8x8 cells (32 columns x y_height/8 rows).  When the
; scroll position is cell-aligned, every cell maps onto exactly one nametable tile, and the operands of
; that tile's PEA instructions in the code field are the final pixels of the background.  So, instead of
; saving the screen beneath each sprite, a cell can be "erased" by copying 16 words from the code field
; to the shadow screen.  Changed background tiles have already been compiled into the code field by
; PPUFlushQueuesAlt, so they are handled by just marking their cells.
;
; Per frame bookkeeping
;
;   gridFlags : one word per cell.  GRID_IN_L = cell is in the erase/expose list, GRID_IN_S = cell is
;               covered by a sprite drawn this frame
;   gridL     : list of cell indices (x2) touched this frame
;   gridS     : two lists of cell indices (x2) covered by sprites, current frame and previous frame
;
; Invariant after every frame (full or grid-dirty): the $01 playfield holds background + the current
; sprites, and the previous sprite list holds exactly the cells covered by those sprites.

            DO    GRID_DIRTY_RENDERING

GRID_COLS   equ   32
GRID_ROWS   equ   {y_height/8}
GRID_CELLS  equ   {GRID_COLS*GRID_ROWS}
GRID_IN_L   equ   $0001
GRID_IN_S   equ   $0002
GRID_MAX_METATILES equ 32                 ; Metatiles redrawn by attribute updates that can be tracked per frame

; Experimental: track which lines / words of each cell were touched, so erase and expose only copy those
; (see "Cell masks" below).  0 = every touched cell is copied in full.
;
; Measured in the BF demo (BG_TILE_DIRTY_PLAN.md): masks cut the words copied by ~40% and make erase
; ~12-25% cheaper, but the extra sprite marking (+33%) and per-cell dispatch make frames ~11% slower
; overall in GSSquared, which does not charge extra for shadowed writes.  Off until that changes.
GRID_CELL_MASKS equ 0

; Experimental: quadrant masks with per-sprite records (ppu_grid_quads.s).  4 bits per cell, one per
; quadrant of 4 lines x 1 word, on a padded grid so a sprite's cells are at fixed offsets and marking is
; a table load + ORA per cell.  Replaces the cell lists below.  Requires GRID_CELL_MASKS = 0.
GRID_QUADS  equ 1
GRID_MASKED equ GRID_CELL_MASKS

; Cell mask layout (GRID_CELL_MASKS), an 8-bit key:
;   bits 0-3   line pairs, bit i = lines 2i and 2i+1 of the cell.  Sprites only ever cover a prefix (lines
;              0..k-1), a suffix (lines k..7) or all 8 lines of a cell, so the union is always prefix | suffix
;   bits 4-5   words (bit 4 = left word, bit 5 = right word) used by the prefix lines
;   bits 6-7   words used by the suffix lines
; Every update is an ORA, so the value is closed under union.  A non-zero value means the cell is in gridL.
; The key indexes precomputed tables of entry points into the unrolled copy sequences, so decoding a
; cell is a single table lookup.  Line pairs (rather than single lines) keep the key to 8 bits.
GRID_FULL   equ   $00FF

; Count words copied per cell (costs ~13 cycles per cell per pass; only for measurements)
GRID_WORD_STATS equ 0
GQ_PITCH2   equ   {{GRID_COLS+1}*2}         ; Quad mode: bytes per padded grid row (one pad column)
GRID_X0     equ   {GRID_QUADS*GQ_PITCH2}    ; Quad mode: index of the first visible cell (one pad row above)
GRID_XPAD   equ   {GRID_QUADS*2}            ; Quad mode: skip the pad column at the end of each row
GRID_S_CAP  equ   512                     ; Sprite cells per frame: 64 sprites x at most 6 cells < 512
GRID_S_BYTES equ  {GRID_MASKED*GRID_S_CAP*2}+{{1-GRID_MASKED}*GRID_CELLS*2}  ; Bytes per sprite cell list


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
; scroll / refresh dirty bits.  Rebuilds the cell -> code field table if the scroll position or
; mirroring mode changed since it was last built.
;
; Returns C = 0 if the grid renderer can be used, C = 1 to fall back to a full render
            mx    %00
gridPrepare
            phb
            phk
            plb

            lda   ControlBits             ; If the background is disabled, the code field does not
            bit   #CTRL_BKGND_ENABLE      ; match the (blank) screen
            beq   :fb_bgoff

            lda   gmtOverflow             ; Attribute updates redrew more metatiles than can be tracked
            bne   :fb_attr

            lda   prev_nt_list_end        ; Too many background tiles?
            sec
            sbc   prev_nt_list_start
            cmp   #{GRID_MAX_BG_TILES*2}+1
            bcs   :fb_many

            lda   StartX                  ; The scroll position must be cell-aligned
            and   #$0003
            bne   :fb_unaligned
            lda   StartY
            clc
            adc   #y_offset
            and   #$0007
            bne   :fb_unaligned

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

:fb_bgoff   INC32 gsFbBgOff
            bra   :fb
:fb_attr    INC32 gsFbAttr
            bra   :fb
:fb_many    INC32 gsFbMany
            bra   :fb
:fb_unaligned INC32 gsFbAlign
:fb         plb
            sec
            rts

; One-time initialization, called from PPUStartUp
            mx    %00
gridStartUp
            DO    GRID_QUADS
            jmp   gqInitTables
            ELSE
            rts
            FIN

; ---------------------------------------------------------------------------
; gridBuildTable
; ---------------------------------------------------------------------------
; For every cell, compute the SHR address and the code field location (bank + address) of the
; nametable tile that is displayed in the cell at the current scroll position.  DBR = K.
            mx    %00
gridBuildTable
            lda   StartX
            sta   gridKeyX
            lda   StartY
            sta   gridKeyY
            lda   BltMirrorP
            sta   gridKeyM

            lda   MaxX                    ; Width of a code field line in bytes
            lsr
            sta   gbW

            ldx   #GRID_X0                ; X = cell index * 2 (padded grid in quad mode)
            stz   gbCY8                   ; Screen line of the cell row
:row
            stz   gbCX4                   ; Screen byte of the cell column
:col
            lda   gbCY8                   ; SHR address of the cell
            asl
            tay
            lda   Mul160Tbl,y
            clc
            adc   gbCX4
            adc   #$2000+x_offset
            stal  PPU_MEM+GRID_CELL_SCR,x

            lda   gbCY8                   ; Virtual line in the code field
            clc
            adc   #y_offset
            adc   StartY
:vlmod      cmp   MaxY
            bcc   :vlok
            sbc   MaxY
            bra   :vlmod
:vlok       sta   gbVL

            lda   gbCX4                   ; Byte offset in the code field line
            clc
            adc   StartX
:hbmod      cmp   gbW
            bcc   :hbok
            sbc   gbW
            bra   :hbmod
:hbok       sta   gbHB

            lda   BltMirrorP
            beq   :vert

; Horizontal mirroring: virtual lines 240 - 479 are CIRAM page 1
            ldy   #0
            lda   gbVL
            cmp   #240
            bcc   :h1
            sbc   #240
            ldy   #$0400
:h1         and   #$FFF8                  ; row * 32
            asl
            asl
            sta   gbCI
            tya
            ora   gbCI
            sta   gbCI
            lda   gbHB
            lsr
            lsr
            ora   gbCI
            sta   gbCI
            bra   :lookup

; Vertical mirroring: bytes 128 - 255 of the line are CIRAM page 1
:vert       lda   gbVL
            and   #$FFF8
            asl
            asl
            sta   gbCI
            lda   gbHB
            cmp   #128
            bcc   :v1
            sbc   #128
            pha
            lda   gbCI
            ora   #$0400
            sta   gbCI
            pla
:v1         lsr
            lsr
            ora   gbCI
            sta   gbCI

:lookup     phx
            ldx   gbCI
            sep   #$20
            ldal  PPU_MEM+TILE_ADDR_HI,x
            xba
            ldal  PPU_MEM+TILE_ADDR_LO,x
            rep   #$20
            sta   gbPea
            sep   #$20
            ldal  PPU_MEM+TILE_BANK,x
            xba
            ldal  PPU_MEM+TILE_BANK,x
            rep   #$20
            plx
            stal  PPU_MEM+GRID_CELL_BANK,x              ; Bank in both bytes for pha / plb / plb
            lda   gbPea
            stal  PPU_MEM+GRID_CELL_PEA,x

            inx
            inx
            lda   gbCX4
            clc
            adc   #4
            sta   gbCX4
            cmp   #GRID_COLS*4
            bcs   *+5
            brl   :col

            DO    GRID_QUADS
            inx                           ; Skip the pad column
            inx
            FIN
            lda   gbCY8
            clc
            adc   #8
            sta   gbCY8
            cmp   #y_height
            bcs   *+5
            brl   :row
            rts

; ---------------------------------------------------------------------------
; gridCiramToCell
; ---------------------------------------------------------------------------
; A = CIRAM address ($000 - $7FF).  Returns C = 1 if the tile is not visible, otherwise C = 0 and
; X = cell index * 2.  Requires a cell-aligned scroll position.  DBR = K.
            mx    %00
gridCiramToCell
            sta   gcC
            and   #$03E0
            cmp   #$03C0                  ; Rows 30 and 31 are attribute bytes
            bcc   *+5
            brl   :off
            lsr
            lsr                           ; row * 8 = first line of the tile in the page
            sta   gcVL
            lda   gcC
            and   #$001F
            asl
            asl
            sta   gcHB                    ; column * 4 = first byte of the tile in the page

            lda   gcC
            and   #$0400
            beq   :p0
            lda   BltMirrorP
            beq   :vp
            lda   gcVL                    ; Horizontal mirroring: CIRAM page 1 is lines 240 - 479
            clc
            adc   #240
            sta   gcVL
            bra   :p0
:vp         lda   gcHB                    ; Vertical mirroring: CIRAM page 1 is bytes 128 - 255
            ora   #128
            sta   gcHB
:p0
            lda   MaxY                    ; s = (vl - StartY - y_offset) mod MaxY, biased positive
            asl
            clc
            adc   gcVL
            sec
            sbc   StartY
            sec
            sbc   #y_offset
:m1         cmp   MaxY
            bcc   :m1ok
            sbc   MaxY
            bra   :m1
:m1ok       cmp   #y_height
            bcs   :off
            and   #$FFF8
            DO    GRID_QUADS
            lsr
            lsr
            sta   gcCell                  ; (s / 8) * 2
            asl
            asl
            asl
            asl
            asl                           ; (s / 8) * 64
            clc
            adc   gcCell
            adc   #GQ_PITCH2              ; ((s / 8) + 1) * 66: padded row
            ELSE
            asl
            asl
            asl                           ; (s / 8) * 64
            FIN
            sta   gcCell

            lda   MaxX                    ; b = (hb - StartX) mod width, biased positive
            lsr
            sta   gcW
            clc
            adc   gcHB
            sec
            sbc   StartX
:m2         cmp   gcW
            bcc   :m2ok
            sbc   gcW
            bra   :m2
:m2ok       cmp   #GRID_COLS*4
            bcs   :off
            lsr
            and   #$FFFE                  ; (b / 4) * 2
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
; Called from RefreshMetatile whenever an attribute update redraws a metatile in the code field, so the
; grid renderer can expose those 4 tiles instead of forcing a full render.  The list is consumed by
; gridDrawDirty and cleared by gridEndFrame.
;
; X = CIRAM address of the top-left tile of the metatile.  Any width / DBR.  Preserves A, X, Y and P.
            mx    %10
gridRecordMetatile
            php
            rep   #$30
            mx    %00                     ; Assemble the body for 16-bit A/X/Y; plp restores the caller's widths
            pha
            phy
            txy                           ; Y = CIRAM address
            ldal  gmtEnd
            cmp   #GRID_MAX_METATILES*2
            bcs   :overflow
            tax
            tya
            stal  gmtList,x
            inx
            inx
            txa
            stal  gmtEnd
            bra   :out
:overflow   lda   #1
            stal  gmtOverflow
:out        tyx
            ply
            pla
            plp
            rts

            DO    1-GRID_QUADS                ; The cell-list implementation (quad mode: ppu_grid_quads.s)

; ---------------------------------------------------------------------------
; Cell marking.  DBR = K, X = cell index * 2 (preserved).  A and Y are clobbered.
; ---------------------------------------------------------------------------
            DO    GRID_MASKED

; Mark a whole cell (background / attribute updates)
            mx    %00
gridMarkL
            lda   #GRID_FULL

; OR the mask in A into the cell, adding the cell to the erase / expose list the first time
gridOrL
            sta   gmV
            lda   gridFlags,x
            bne   :have
            ldy   gridLEnd
            txa
            sta   gridL,y
            iny
            iny
            sty   gridLEnd
            lda   #0
:have       ora   gmV
            sta   gridFlags,x
            rts

; Sprite cell: also accumulate the sprite-only mask that the next frame has to erase
            mx    %00
gridMarkSpr
            sta   gmV2
            lda   sprMask,x
            bne   :have
            ldy   gridSCurEnd
            txa
            sta   gridS,y
            iny
            iny
            sty   gridSCurEnd
            lda   #0
:have       ora   gmV2
            sta   sprMask,x
            lda   gmV2
            bra   gridOrL

            ELSE

            mx    %00
gridMarkL
            lda   gridFlags,x
            bit   #GRID_IN_L
            bne   :out
            ora   #GRID_IN_L
            sta   gridFlags,x
            ldy   gridLEnd
            txa
            sta   gridL,y
            iny
            iny
            sty   gridLEnd
:out        rts

            mx    %00
gridMarkSpr
            lda   gridFlags,x
            cmp   #GRID_IN_L+GRID_IN_S
            beq   :out
            bit   #GRID_IN_S
            bne   :s_ok
            ldy   gridSCurEnd
            txa
            sta   gridS,y
            iny
            iny
            sty   gridSCurEnd
            lda   gridFlags,x
:s_ok       bit   #GRID_IN_L
            bne   :l_ok
            ldy   gridLEnd
            txa
            sta   gridL,y
            iny
            iny
            sty   gridLEnd
:l_ok       lda   #GRID_IN_L+GRID_IN_S
            sta   gridFlags,x
:out        rts

            FIN

; ---------------------------------------------------------------------------
; gridMarkSprite
; ---------------------------------------------------------------------------
; Mark the cells covered by a sprite.  Called from drawSprites with any DBR.
;
; X = OAM_COPY index (preserved)
; A = sprite height - 1 (7 or 15)
            DO    GRID_CELL_MASKS

; The sprite's top line is k = top & 7 lines into its first cell row.  If k = 0 every cell row it covers
; is full.  Otherwise the first cell row gets the suffix k..7, the last gets the prefix 0..k-1 and any
; row in between (8x16) is full.  The sprite's byte offset b = x & 3 picks the words it covers in the
; cell it starts in and, when b != 0, the cell to its right.
; Entry points by sprite size (the quad renderer has separate ones)
            mx    %00
gridMarkSprite8
            lda   #8-1
            bra   gridMarkSprite
gridMarkSprite16
            lda   #16-1
gridMarkSprite
            phx
            phb
            phk
            plb

            sta   gmH
            lda   OAM_COPY,x              ; Y-coordinate (already adjusted by +1)
            and   #$00FF
            sec
            sbc   #y_offset
            sta   gmTop                   ; Signed screen line of the top edge
            and   #$0007
            asl
            sta   gmK2                    ; k * 2

            lda   gmTop
            and   #$FFF8
            asl
            asl
            asl
            sta   gmRow                   ; floor(top / 8) * 64, signed
            sta   gmRowFirst
            lda   gmTop
            clc
            adc   gmH
            and   #$FFF8
            asl
            asl
            asl
            sta   gmRowEnd                ; floor(bottom / 8) * 64, signed and not clamped
            bpl   *+5
            brl   :done                   ; Entirely above the playfield

            lda   OAM_COPY+3,x            ; X-coordinate in bytes, same as :setupSprite
            and   #$00FF
            sta   gmX
            lda   _ppuscroll_x
            and   #$0001
            clc
            adc   gmX
            lsr
            sta   gmX
            and   #$0003
            asl
            tay
            lda   gridColsPL,y
            sta   gmCPL
            lda   gridColsSL,y
            sta   gmCSL
            lda   gridColsPR,y
            sta   gmCPR
            lda   gridColsSR,y
            sta   gmCSR

            lda   gmX
            lsr
            lsr
            cmp   #GRID_COLS
            bcc   *+5
            brl   :done
            asl
            sta   gmC0
            lda   gmCPR                   ; b = 0 => the sprite does not reach the next cell
            beq   :noc1
            lda   gmC0
            inc
            inc
            cmp   #GRID_COLS*2
            bcc   :c1ok
:noc1       lda   #$FFFF
:c1ok       sta   gmC1

:rowloop    lda   gmRow
            bmi   :next                   ; Above the playfield
            cmp   #GRID_ROWS*64
            bcc   *+5
            brl   :done                   ; Below the playfield (rows only increase)

            ldy   gmK2
            beq   :full                   ; Aligned sprite: every row is full
            cmp   gmRowFirst
            beq   :suffix
            cmp   gmRowEnd
            beq   :prefix
:full       lda   gmCPL
            ora   gmCSL
            ora   #$000F
            sta   gmVL
            lda   gmCPR
            ora   gmCSR
            ora   #$000F
            sta   gmVR
            bra   :mark
:suffix     lda   gridSufRows,y
            sta   gmT
            ora   gmCSL
            sta   gmVL
            lda   gmT
            ora   gmCSR
            sta   gmVR
            bra   :mark
:prefix     lda   gridPreRows,y
            sta   gmT
            ora   gmCPL
            sta   gmVL
            lda   gmT
            ora   gmCPR
            sta   gmVR

:mark       lda   gmRow
            clc
            adc   gmC0
            tax
            lda   gmVL
            jsr   gridMarkSpr
            lda   gmC1
            bmi   :next
            lda   gmRow
            clc
            adc   gmC1
            tax
            lda   gmVR
            jsr   gridMarkSpr

:next       lda   gmRow
            cmp   gmRowEnd
            beq   :done
            clc
            adc   #64
            sta   gmRow
            brl   :rowloop

:done       plb
            plx
            rts

; Line pairs covered when the sprite starts k lines into the cell (suffix: lines k..7) or ends there
; (prefix: lines 0..k-1), rounded out to whole pairs
gridSufRows dw    $0F,$0F,$0E,$0E,$0C,$0C,$08,$08
gridPreRows dw    $00,$01,$01,$03,$03,$07,$07,$0F

; Words covered for sprite byte offset b = 0..3: L = cell the sprite starts in, R = the next cell.
; P = placed in the prefix field (bits 4-5), S = suffix field (bits 6-7).  Left word = 1, right = 2.
gridColsPL  dw    $0030,$0030,$0020,$0020
gridColsSL  dw    $00C0,$00C0,$0080,$0080
gridColsPR  dw    $0000,$0010,$0010,$0030
gridColsSR  dw    $0000,$0040,$0040,$00C0

            ELSE

; Entry points by sprite size (the quad renderer has separate ones)
            mx    %00
gridMarkSprite8
            lda   #8-1
            bra   gridMarkSprite
gridMarkSprite16
            lda   #16-1
gridMarkSprite
            phx
            phb
            phk
            plb

            sta   gmH
            lda   OAM_COPY,x              ; Y-coordinate (already adjusted by +1)
            and   #$00FF
            sec
            sbc   #y_offset
            sta   gmTop                   ; Signed screen line of the top edge

            clc
            adc   gmH                     ; Bottom edge
            bpl   *+5
            brl   :done
            cmp   #y_height
            bcc   *+5
            lda   #y_height-1
            and   #$FFF8
            asl
            asl
            asl
            sta   gmRowEnd                ; (bottom / 8) * 64

            lda   gmTop
            bpl   *+5
            lda   #0
            cmp   #y_height
            bcc   *+5
            brl   :done
            and   #$FFF8
            asl
            asl
            asl
            sta   gmRow                   ; (top / 8) * 64

            lda   OAM_COPY+3,x            ; X-coordinate in bytes, same as :setupSprite
            and   #$00FF
            sta   gmX
            lda   _ppuscroll_x
            and   #$0001
            clc
            adc   gmX
            lsr
            sta   gmX

            lsr
            lsr
            cmp   #GRID_COLS
            bcs   :done
            asl
            sta   gmC0

            lda   gmX
            clc
            adc   #3
            lsr
            lsr
            cmp   #GRID_COLS
            bcc   *+5
            lda   #GRID_COLS-1
            asl
            sta   gmC1

:rowloop    lda   gmRow
            clc
            adc   gmC0
            tax
            jsr   gridMarkSpr
            lda   gmC1
            cmp   gmC0
            beq   :next
            lda   gmRow
            clc
            adc   gmC1
            tax
            jsr   gridMarkSpr
:next       lda   gmRow
            cmp   gmRowEnd
            bcs   :done
            adc   #64                     ; Carry is clear
            sta   gmRow
            bra   :rowloop

:done       plb
            plx
            rts

            FIN

; ---------------------------------------------------------------------------
; gridEraseList
; ---------------------------------------------------------------------------
; Copy the background from the code field into the shadow screen for the first gridEraseEnd/2 cells
; of the list.  Shadowing should be off.  DBR = K.
            DO    GRID_CELL_MASKS

; Each cell's key is split into a prefix run (line pairs from the top, words from bits 4-5) and a suffix
; run (line pairs from the bottom, words from bits 6-7).  Each run is copied by entering an unrolled
; 8-line sequence part way through: the prefix sequences hold lines 7..0 and the suffix sequences lines
; 0..7, so a run of n lines starts at start + (8 - n) * block size, and n = 0 is the trailing RTS.
            mx    %00
gridEraseList
            lda   gridEraseEnd
            bne   *+3
            rts
            sta   tmp1
            phb
            ldx   #0
:loop
            phk                           ; Tables, patches and cell data live in this bank
            plb
            phx
            lda   gridL,x
            tax
            lda   gridFlags,x
            asl
            tay
            lda   gridEPreTbl,y
            sta   :pp+1
            lda   gridESufTbl,y
            sta   :sp+1
            DO    GRID_WORD_STATS
            lda   gridWordsTbl,y
            clc
            adc   gbWordsE
            sta   gbWordsE
            FIN

            ldal  PPU_MEM+GRID_CELL_SCR,x
            sta   tmp0
            ldal  PPU_MEM+GRID_CELL_PEA,x
            tay
            ldal  PPU_MEM+GRID_CELL_BANK,x
            pha
            plb
            plb                           ; DBR = code field bank
            ldx   tmp0                    ; X = SHR address, Y = code field address
:pp         jsr   $0000
:sp         jsr   $0000
            plx
            inx
            inx
            cpx   tmp1
            bcs   *+5
            brl   :loop
            plb
            rts

; Erase sequences.  X = SHR address, Y = code field address, DBR = code field bank.  Line n's left
; word is the operand at +4 + n*_LINE_SPAN, the right word at +1 + n*_LINE_SPAN.
GRID_EB1    equ   7                       ; bytes per line, one word
GRID_EB2    equ   14                      ; bytes per line, both words

gridEPreL
]n          equ   7
            lup   8
            lda:  {]n*_LINE_SPAN}+4,y
            stal  $010000+{]n*SHR_LINE_WIDTH},x
]n          equ   ]n-1
            --^
            rts
gridEPreR
]n          equ   7
            lup   8
            lda:  {]n*_LINE_SPAN}+1,y
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n-1
            --^
            rts
gridEPreLR
]n          equ   7
            lup   8
            lda:  {]n*_LINE_SPAN}+4,y
            stal  $010000+{]n*SHR_LINE_WIDTH},x
            lda:  {]n*_LINE_SPAN}+1,y
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n-1
            --^
            rts
gridESufL
]n          equ   0
            lup   8
            lda:  {]n*_LINE_SPAN}+4,y
            stal  $010000+{]n*SHR_LINE_WIDTH},x
]n          equ   ]n+1
            --^
            rts
gridESufR
]n          equ   0
            lup   8
            lda:  {]n*_LINE_SPAN}+1,y
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n+1
            --^
            rts
gridESufLR
]n          equ   0
            lup   8
            lda:  {]n*_LINE_SPAN}+4,y
            stal  $010000+{]n*SHR_LINE_WIDTH},x
            lda:  {]n*_LINE_SPAN}+1,y
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n+1
            --^
gridRts     rts

; ---------------------------------------------------------------------------
; gridExposeList
; ---------------------------------------------------------------------------
; Copy the touched lines / words of every cell in the list from the shadow screen to itself with
; shadowing on.  DBR = K.
            mx    %00
gridExposeList
            lda   gridLEnd
            bne   *+3
            rts
            sta   tmp1
            ldx   #0
:loop
            phx
            lda   gridL,x
            tax
            lda   gridFlags,x
            asl
            tay
            lda   gridXPreTbl,y
            sta   :pp+1
            lda   gridXSufTbl,y
            sta   :sp+1
            DO    GRID_WORD_STATS
            lda   gridWordsTbl,y
            clc
            adc   gbWordsX
            sta   gbWordsX
            FIN
            ldal  PPU_MEM+GRID_CELL_SCR,x
            tax
:pp         jsr   $0000
:sp         jsr   $0000
            plx
            inx
            inx
            cpx   tmp1
            bcs   *+5
            brl   :loop
            rts

; Expose sequences.  X = SHR address.
GRID_XB1    equ   8
GRID_XB2    equ   16

gridXPreL
]n          equ   7
            lup   8
            ldal  $010000+{]n*SHR_LINE_WIDTH},x
            stal  $010000+{]n*SHR_LINE_WIDTH},x
]n          equ   ]n-1
            --^
            rts
gridXPreR
]n          equ   7
            lup   8
            ldal  $010000+{]n*SHR_LINE_WIDTH}+2,x
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n-1
            --^
            rts
gridXPreLR
]n          equ   7
            lup   8
            ldal  $010000+{]n*SHR_LINE_WIDTH},x
            stal  $010000+{]n*SHR_LINE_WIDTH},x
            ldal  $010000+{]n*SHR_LINE_WIDTH}+2,x
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n-1
            --^
            rts
gridXSufL
]n          equ   0
            lup   8
            ldal  $010000+{]n*SHR_LINE_WIDTH},x
            stal  $010000+{]n*SHR_LINE_WIDTH},x
]n          equ   ]n+1
            --^
            rts
gridXSufR
]n          equ   0
            lup   8
            ldal  $010000+{]n*SHR_LINE_WIDTH}+2,x
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n+1
            --^
            rts
gridXSufLR
]n          equ   0
            lup   8
            ldal  $010000+{]n*SHR_LINE_WIDTH},x
            stal  $010000+{]n*SHR_LINE_WIDTH},x
            ldal  $010000+{]n*SHR_LINE_WIDTH}+2,x
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n+1
            --^
            rts

; Entry points for each cell key (index = key * 2)
gridEPreTbl
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{4*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{2*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{4*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{0*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{4*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{2*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{4*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{0*GRID_EB1}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{4*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{2*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{4*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{0*GRID_EB2}
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridEPreL+{0*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{4*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{2*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{4*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{0*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{4*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{2*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{4*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreLR+{0*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{4*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{2*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{4*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{0*GRID_EB2}
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridEPreR+{0*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{4*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{2*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{4*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreLR+{0*GRID_EB2}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{4*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{2*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{4*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{0*GRID_EB1}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{4*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{2*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{4*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{0*GRID_EB2}
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridEPreLR+{0*GRID_EB2}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{4*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{2*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreL+{4*GRID_EB1}
            dw    gridRts,gridEPreL+{6*GRID_EB1},gridRts,gridEPreLR+{0*GRID_EB2}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{4*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{2*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreR+{4*GRID_EB1}
            dw    gridRts,gridEPreR+{6*GRID_EB1},gridRts,gridEPreLR+{0*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{4*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{2*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{4*GRID_EB2}
            dw    gridRts,gridEPreLR+{6*GRID_EB2},gridRts,gridEPreLR+{0*GRID_EB2}
gridESufTbl
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1}
            dw    gridESufL+{4*GRID_EB1},gridESufL+{4*GRID_EB1},gridESufL+{2*GRID_EB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1}
            dw    gridESufL+{4*GRID_EB1},gridESufL+{4*GRID_EB1},gridESufL+{2*GRID_EB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1}
            dw    gridESufL+{4*GRID_EB1},gridESufL+{4*GRID_EB1},gridESufL+{2*GRID_EB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1},gridESufL+{6*GRID_EB1}
            dw    gridESufL+{4*GRID_EB1},gridESufL+{4*GRID_EB1},gridESufL+{2*GRID_EB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1}
            dw    gridESufR+{4*GRID_EB1},gridESufR+{4*GRID_EB1},gridESufR+{2*GRID_EB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1}
            dw    gridESufR+{4*GRID_EB1},gridESufR+{4*GRID_EB1},gridESufR+{2*GRID_EB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1}
            dw    gridESufR+{4*GRID_EB1},gridESufR+{4*GRID_EB1},gridESufR+{2*GRID_EB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1},gridESufR+{6*GRID_EB1}
            dw    gridESufR+{4*GRID_EB1},gridESufR+{4*GRID_EB1},gridESufR+{2*GRID_EB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2}
            dw    gridESufLR+{4*GRID_EB2},gridESufLR+{4*GRID_EB2},gridESufLR+{2*GRID_EB2},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2}
            dw    gridESufLR+{4*GRID_EB2},gridESufLR+{4*GRID_EB2},gridESufLR+{2*GRID_EB2},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2}
            dw    gridESufLR+{4*GRID_EB2},gridESufLR+{4*GRID_EB2},gridESufLR+{2*GRID_EB2},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2},gridESufLR+{6*GRID_EB2}
            dw    gridESufLR+{4*GRID_EB2},gridESufLR+{4*GRID_EB2},gridESufLR+{2*GRID_EB2},gridRts
gridXPreTbl
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{4*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{2*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{4*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{0*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{4*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{2*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{4*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{0*GRID_XB1}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{4*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{2*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{4*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{0*GRID_XB2}
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridXPreL+{0*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{4*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{2*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{4*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{0*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{4*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{2*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{4*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreLR+{0*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{4*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{2*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{4*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{0*GRID_XB2}
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridXPreR+{0*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{4*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{2*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{4*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreLR+{0*GRID_XB2}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{4*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{2*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{4*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{0*GRID_XB1}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{4*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{2*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{4*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{0*GRID_XB2}
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridXPreLR+{0*GRID_XB2}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{4*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{2*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreL+{4*GRID_XB1}
            dw    gridRts,gridXPreL+{6*GRID_XB1},gridRts,gridXPreLR+{0*GRID_XB2}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{4*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{2*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreR+{4*GRID_XB1}
            dw    gridRts,gridXPreR+{6*GRID_XB1},gridRts,gridXPreLR+{0*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{4*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{2*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{4*GRID_XB2}
            dw    gridRts,gridXPreLR+{6*GRID_XB2},gridRts,gridXPreLR+{0*GRID_XB2}
gridXSufTbl
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1}
            dw    gridXSufL+{4*GRID_XB1},gridXSufL+{4*GRID_XB1},gridXSufL+{2*GRID_XB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1}
            dw    gridXSufL+{4*GRID_XB1},gridXSufL+{4*GRID_XB1},gridXSufL+{2*GRID_XB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1}
            dw    gridXSufL+{4*GRID_XB1},gridXSufL+{4*GRID_XB1},gridXSufL+{2*GRID_XB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1},gridXSufL+{6*GRID_XB1}
            dw    gridXSufL+{4*GRID_XB1},gridXSufL+{4*GRID_XB1},gridXSufL+{2*GRID_XB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1}
            dw    gridXSufR+{4*GRID_XB1},gridXSufR+{4*GRID_XB1},gridXSufR+{2*GRID_XB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1}
            dw    gridXSufR+{4*GRID_XB1},gridXSufR+{4*GRID_XB1},gridXSufR+{2*GRID_XB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1}
            dw    gridXSufR+{4*GRID_XB1},gridXSufR+{4*GRID_XB1},gridXSufR+{2*GRID_XB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1},gridXSufR+{6*GRID_XB1}
            dw    gridXSufR+{4*GRID_XB1},gridXSufR+{4*GRID_XB1},gridXSufR+{2*GRID_XB1},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2}
            dw    gridXSufLR+{4*GRID_XB2},gridXSufLR+{4*GRID_XB2},gridXSufLR+{2*GRID_XB2},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2}
            dw    gridXSufLR+{4*GRID_XB2},gridXSufLR+{4*GRID_XB2},gridXSufLR+{2*GRID_XB2},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2}
            dw    gridXSufLR+{4*GRID_XB2},gridXSufLR+{4*GRID_XB2},gridXSufLR+{2*GRID_XB2},gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridRts,gridRts,gridRts,gridRts
            dw    gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2},gridXSufLR+{6*GRID_XB2}
            dw    gridXSufLR+{4*GRID_XB2},gridXSufLR+{4*GRID_XB2},gridXSufLR+{2*GRID_XB2},gridRts

            DO    GRID_WORD_STATS
; Words copied for each cell key
gridWordsTbl
            dw    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
            dw    0,2,0,4,0,2,0,6,0,2,0,4,0,2,0,8
            dw    0,2,0,4,0,2,0,6,0,2,0,4,0,2,0,8
            dw    0,4,0,8,0,4,0,12,0,4,0,8,0,4,0,16
            dw    0,0,0,0,0,0,0,0,2,2,2,2,4,4,6,8
            dw    0,2,0,4,0,2,0,6,2,4,2,6,4,6,6,8
            dw    0,2,0,4,0,2,0,6,2,4,2,6,4,6,6,16
            dw    0,4,0,8,0,4,0,12,2,6,2,10,4,8,6,16
            dw    0,0,0,0,0,0,0,0,2,2,2,2,4,4,6,8
            dw    0,2,0,4,0,2,0,6,2,4,2,6,4,6,6,16
            dw    0,2,0,4,0,2,0,6,2,4,2,6,4,6,6,8
            dw    0,4,0,8,0,4,0,12,2,6,2,10,4,8,6,16
            dw    0,0,0,0,0,0,0,0,4,4,4,4,8,8,12,16
            dw    0,2,0,4,0,2,0,6,4,6,4,8,8,10,12,16
            dw    0,2,0,4,0,2,0,6,4,6,4,8,8,10,12,16
            dw    0,4,0,8,0,4,0,12,4,8,4,12,8,12,12,16
            FIN

            ELSE

            mx    %00
gridEraseList
            lda   gridEraseEnd
            bne   *+3
            rts
            sta   tmp0

            phb
            ldx   #0
:loop
            phx
            ldal  gridL,x
            tax
            ldal  PPU_MEM+GRID_CELL_SCR,x
            sta   tmp1
            ldal  PPU_MEM+GRID_CELL_PEA,x
            tay
            ldal  PPU_MEM+GRID_CELL_BANK,x
            pha
            plb
            plb                           ; DBR = code field bank
            ldx   tmp1                    ; X = SHR address, Y = code field address

; Within a tile, line n's left word is the operand at +4 + n*_LINE_SPAN and the right word is the
; operand at +1 + n*_LINE_SPAN (see CompileTile :word_addr)
]n          equ   0
            lup   8
            lda:  {]n*_LINE_SPAN}+4,y
            stal  $010000+{]n*SHR_LINE_WIDTH},x
            lda:  {]n*_LINE_SPAN}+1,y
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n+1
            --^

            plx
            inx
            inx
            cpx   tmp0
            bcs   *+5
            brl   :loop
            plb
            rts

; ---------------------------------------------------------------------------
; gridExposeList
; ---------------------------------------------------------------------------
; Copy every cell in the list from the shadow screen to itself with shadowing on.  DBR = K.
            mx    %00
gridExposeList
            ldy   #0
            cpy   gridLEnd
            bcc   :loop
            rts
:loop
            ldx   gridL,y
            ldal  PPU_MEM+GRID_CELL_SCR,x
            tax
]n          equ   0
            lup   8
            ldal  $010000+{]n*SHR_LINE_WIDTH},x
            stal  $010000+{]n*SHR_LINE_WIDTH},x
            ldal  $010000+{]n*SHR_LINE_WIDTH}+2,x
            stal  $010000+{]n*SHR_LINE_WIDTH}+2,x
]n          equ   ]n+1
            --^
            iny
            iny
            cpy   gridLEnd
            bcs   *+5
            brl   :loop
            rts

            FIN

; ---------------------------------------------------------------------------
; gridEndFrame
; ---------------------------------------------------------------------------
; Clear the grid flags, empty the list and make this frame's sprite cells the "previous" list.  DBR = K.
            mx    %00
gridEndFrame
            DO    GRID_CELL_MASKS
            ldy   gridSCurBase            ; Save this frame's sprite-only masks with the sprite cell
            bra   :stest                  ; list; the next frame erases exactly those lines / words
:sloop      ldx   gridS,y
            lda   sprMask,x
            sta   gridSM,y
            stz   sprMask,x
            iny
            iny
:stest      cpy   gridSCurEnd
            bcc   :sloop
            FIN

            ldy   #0
            bra   :test
:loop       ldx   gridL,y
            stz   gridFlags,x
            iny
            iny
:test       cpy   gridLEnd
            bcc   :loop
            stz   gridLEnd
            stz   gmtEnd                  ; Attribute metatile list is per-frame
            stz   gmtOverflow

            lda   gridSCurBase
            sta   gridSPrevStart
            lda   gridSCurEnd
            sta   gridSPrevEnd
            lda   gridSCurBase
            eor   #GRID_S_BYTES
            sta   gridSCurBase
            sta   gridSCurEnd
            rts

; ---------------------------------------------------------------------------
; gridDrawDirty
; ---------------------------------------------------------------------------
; Render a frame with the grid renderer.  gridPrepare must have returned C = 0.
            mx    %00
gridDrawDirty
            phb
            phk
            plb

; Erase the sprites from the previous frame

            stz   gbWordsE
            stz   gbWordsX
            ldy   gridSPrevStart
            bra   :t1
:l1         ldx   gridS,y
            phy
            DO    GRID_MASKED
            lda   gridSM,y                ; Only the lines / words the old sprites covered
            jsr   gridOrL
            ELSE
            jsr   gridMarkL
            FIN
            ply
            iny
            iny
:t1         cpy   gridSPrevEnd
            bcc   :l1

; Redraw the background tiles that changed

            stz   gbBgCount
            ldy   prev_nt_list_start
            bra   :t2
:l2         lda   nt_list,y
            phy
            jsr   gridCiramToCell
            bcs   :skip
            inc   gbBgCount
            jsr   gridMarkL
:skip       ply
            iny
            iny
:t2         cpy   prev_nt_list_end
            bcc   :l2

; Redraw the metatiles that changed palettes because of attribute updates

            stz   gbMtCount
            ldy   #0
            bra   :t3
:l3         phy
            lda   gmtList,y
            jsr   gridMarkCiram           ; top-left
            lda   gmtList,y
            inc
            jsr   gridMarkCiram           ; top-right
            lda   gmtList,y
            clc
            adc   #32
            jsr   gridMarkCiram           ; bottom-left
            lda   gmtList,y
            clc
            adc   #33
            jsr   gridMarkCiram           ; bottom-right
            ply
            iny
            iny
:t3         cpy   gmtEnd
            bcc   :l3
            tya
            lsr
            ADD32 gsMetatiles

            lda   gridLEnd
            sta   gridEraseEnd

            jsr   _ShadowOff
            jsr   gridEraseList
            jsr   drawSprites             ; Marks the cells of the new sprites
            jsr   _ShadowOn
            jsr   gridExposeList

; Statistics

            INC32 gsDirtyFrames
            lda   gridEraseEnd
            lsr
            sta   gsLastErased
            ADD32 gsErased
            lda   gridLEnd
            lsr
            sta   gsLastExposed
            ADD32 gsExposed

            DO    GRID_MASKED
            ELSE
            lda   gridEraseEnd            ; Full cells: 16 words each
            asl
            asl
            asl
            sta   gbWordsE
            lda   gridLEnd
            asl
            asl
            asl
            sta   gbWordsX
            FIN
            lda   gbWordsE
            ADD32 gsEraseWords
            lda   gbWordsX
            ADD32 gsExposeWords
            lda   gbBgCount
            sta   gsLastBg
            beq   :no_bg
            ADD32 gsBgCells
            INC32 gsBgFrames               ; The old renderer would have forced a full frame
:no_bg
            lda   gbMtCount
            beq   :no_mt
            ADD32 gsMtCells
            INC32 gsAttrFrames             ; The old renderer would have forced a full frame
:no_mt
            jsr   gridSpriteTiles
            sta   gsLastSprTiles
            ADD32 gsSprTiles

            jsr   gridEndFrame
            plb
            rts

; Mark the cell showing a CIRAM tile, if it is visible.  A = CIRAM address.  DBR = K.  Y is preserved.
            mx    %00
gridMarkCiram
            phy
            jsr   gridCiramToCell
            bcs   :off
            inc   gbMtCount
            jsr   gridMarkL
:off        ply
            rts

; Called after a full render.  drawSprites has marked the sprite cells, so just rotate the lists.
            mx    %00
gridEndFull
            phb
            phk
            plb
            INC32 gsFullFrames
            jsr   gridEndFrame
            plb
            rts

            FIN                           ; 1-GRID_QUADS

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
gridLEnd        dw    0
gridEraseEnd    dw    0
gridSCurBase    dw    0
gridSCurEnd     dw    0
gridSPrevStart  dw    0
gridSPrevEnd    dw    0
gridKeyX        dw    $FFFF
gridKeyY        dw    $FFFF
gridKeyM        dw    $FFFF

gbW             dw    0
gbCX4           dw    0
gbCY8           dw    0
gbVL            dw    0
gbHB            dw    0
gbCI            dw    0
gbPea           dw    0
gbBgCount       dw    0
gbMtCount       dw    0

gcC             dw    0
gcVL            dw    0
gcHB            dw    0
gcW             dw    0
gcCell          dw    0

gmH             dw    0
gmTop           dw    0
gmRow           dw    0
gmRowEnd        dw    0
gmX             dw    0
gmC0            dw    0
gmC1            dw    0
gmRowFirst      dw    0
gmK2            dw    0
gmCPL           dw    0
gmCSL           dw    0
gmCPR           dw    0
gmCSR           dw    0
gmVL            dw    0
gmVR            dw    0
gmT             dw    0
gmV             dw    0
gmV2            dw    0
gmB2            dw    0
gmPL            dw    0
gmPR            dw    0

gdM             dw    0
gdT             dw    0
gdPre           dw    0
gdSuf           dw    0
gbWordsE        dw    0               ; Words copied this frame
gbWordsX        dw    0

; Statistics block.  The signature makes it easy to find from a debugger.  All counters are 32-bit.
gridStatsSig    asc   'GRIDSTAT'
gsDirtyFrames   ds    4
gsFullFrames    ds    4
gsErased        ds    4               ; Cells copied from the code field
gsExposed       ds    4               ; Cells exposed (shadowed copies)
gsSprTiles      ds    4               ; 8x8 sprite tiles drawn in grid-dirty frames
gsBgCells       ds    4               ; Visible background tiles updated in grid-dirty frames
gsFbBgOff       ds    4               ; Fallbacks to a full render, by reason
gsFbAttr        ds    4
gsFbMany        ds    4
gsFbAlign       ds    4
gsFbScroll      ds    4               ; Scroll / refresh dirty bits were set
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
gmtList         ds    GRID_MAX_METATILES*2

            DO    1-GRID_QUADS
gridFlags       ds    GRID_CELLS*2
gridL           ds    GRID_CELLS*2
gridS           ds    GRID_S_BYTES*2         ; Two sprite cell lists (current / previous)
            DO    GRID_MASKED
gridSM          ds    GRID_S_BYTES*2         ; Sprite-only masks, parallel to gridS
            FIN
            DO    GRID_CELL_MASKS
sprMask         ds    GRID_CELLS*2           ; Sprite-only mask per cell, this frame
            FIN
            FIN                           ; 1-GRID_QUADS
; cellScr / cellPea / cellBank live in the PPU_MEM bank (GRID_CELL_* in Defs.s) to save space here


            FIN

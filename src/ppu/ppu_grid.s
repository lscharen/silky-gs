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
; This file has the setup shared by the renderer: the fallback decision (gridPrepare), the cell ->
; code field table and the metatile list.  The per-frame bookkeeping (quadrant masks with per-sprite
; records), erase and expose are in ppu_grid_quads.s.
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
            lda   #FB_COLOR_BGOFF
            bra   :fb
:fb_attr    INC32 gsFbAttr
            lda   #FB_COLOR_METATILES
            bra   :fb
:fb_many    INC32 gsFbMany
            lda   #FB_COLOR_MANY
            bra   :fb
:fb_unaligned INC32 gsFbAlign
            lda   #FB_COLOR_UNALIGNED
:fb         sta   gridFbReason            ; Read by the scaffold's GRID_FALLBACK_BORDER indicator
            plb
            sec
            rts

; One-time initialization, called from PPUStartUp
            mx    %00
gridStartUp
            jmp   gqInitTables

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

            ldx   #GRID_X0                ; X = cell index * 2 (padded grid)
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

            inx                           ; Skip the pad column
            inx
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
gridFbReason    dw    0               ; FB_COLOR_* of the last gridPrepare fallback
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

; cellScr / cellPea / cellBank live in the PPU_MEM bank (GRID_CELL_* in Defs.s) to save space here

            FIN

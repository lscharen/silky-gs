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

; Opcode for STA [dp],y.  Brackets inside LUP/macro bodies confuse the Merlin macro processor.
STA_IND_LONG_IDX equ $97

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

            ldx   #0                      ; X = cell index * 2
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
            sta   cellScr,x

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
            sta   cellBank,x              ; Bank in both bytes for pha / plb / plb
            lda   gbPea
            sta   cellPea,x

            inx
            inx
            lda   gbCX4
            clc
            adc   #4
            sta   gbCX4
            cmp   #GRID_COLS*4
            bcs   *+5
            brl   :col

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
            bcs   :off
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
            asl
            asl
            asl                           ; (s / 8) * 64
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

; ---------------------------------------------------------------------------
; Cell marking.  DBR = K, X = cell index * 2 (preserved).  A and Y are clobbered.
; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; gridMarkSprite
; ---------------------------------------------------------------------------
; Mark the cells covered by a sprite.  Called from drawSprites with any DBR.
;
; X = OAM_COPY index (preserved)
; A = sprite height - 1 (7 or 15)
            mx    %00
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

; ---------------------------------------------------------------------------
; gridEraseList
; ---------------------------------------------------------------------------
; Copy the background from the code field into the shadow screen for the first gridEraseEnd/2 cells
; of the list.  Shadowing should be off.  DBR = K.
            mx    %00
gridEraseList
            lda   gridEraseEnd
            bne   *+3
            rts
            sta   tmp0

; Set up 16 long pointers to $01:{n*160} and $01:{n*160+2} in blttmp .. tmp15

]n          equ   0
            lup   8
            lda   #{]n*SHR_LINE_WIDTH}
            sta   blttmp+{]n*6}
            lda   #{]n*SHR_LINE_WIDTH}+2
            sta   blttmp+{]n*6}+3
]n          equ   ]n+1
            --^
            sep   #$20
            lda   #$01
]n          equ   0
            lup   8
            sta   blttmp+{]n*6}+2
            sta   blttmp+{]n*6}+5
]n          equ   ]n+1
            --^
            rep   #$20

            phb
            ldx   #0
:loop
            phx
            ldal  gridL,x
            tax
            ldal  cellScr,x
            tay
            ldal  cellBank,x
            pha
            plb
            plb
            ldal  cellPea,x
            tax
            jsr   gridEraseCell
            plx
            inx
            inx
            cpx   tmp0
            bcc   :loop
            plb
            rts

; DBR = code field bank, X = code field address of the tile, Y = SHR address of the cell
;
; Within a tile, line n's left word is the operand at +4 + n*_LINE_SPAN and the right word is the
; operand at +1 + n*_LINE_SPAN (see CompileTile :word_addr)
            mx    %00
gridEraseCell
]n          equ   0
            lup   8
            lda:  {]n*_LINE_SPAN}+4,x
            db    STA_IND_LONG_IDX,blttmp+{]n*6}
            lda:  {]n*_LINE_SPAN}+1,x
            db    STA_IND_LONG_IDX,blttmp+{]n*6}+3
]n          equ   ]n+1
            --^
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
            lda   cellScr,x
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

; ---------------------------------------------------------------------------
; gridEndFrame
; ---------------------------------------------------------------------------
; Clear the grid flags, empty the list and make this frame's sprite cells the "previous" list.  DBR = K.
            mx    %00
gridEndFrame
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
            eor   #GRID_CELLS*2
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

            ldy   gridSPrevStart
            bra   :t1
:l1         ldx   gridS,y
            phy
            jsr   gridMarkL
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
gsLastErased    dw    0
gsLastExposed   dw    0
gsLastSprTiles  dw    0
gsLastBg        dw    0

gmtEnd          dw    0
gmtOverflow     dw    0
gmtList         ds    GRID_MAX_METATILES*2

gridFlags       ds    GRID_CELLS*2
gridL           ds    GRID_CELLS*2
gridS           ds    GRID_CELLS*4
cellScr         ds    GRID_CELLS*2
cellPea         ds    GRID_CELLS*2
cellBank        ds    GRID_CELLS*2

            FIN

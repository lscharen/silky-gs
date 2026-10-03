; ppu_queues.s - Nametable / attribute update tracking
;
; Tracking is keyed by attribute byte.  Every 4x4 tile group (one attribute byte) has a 16-bit mask of
; the tiles written since the last render, and only the attribute index is queued (at_list), at most
; once per render.  At render time the attribute change (EOR against the last applied value) is
; expanded into whole metatiles, merged with the tile mask and drawn in one pass, one metatile (nibble)
; at a time.
;
; Mask layout (one byte per half, so the 8-bit write path sets a bit with one ORA):
;
;   LO byte = attribute quadrants 0, 1 (rows 0-1 of the group)   HI byte = quadrants 2, 3 (rows 2-3)
;   nibble q = attribute quadrant q (bits 2q..2q+1 of the attribute byte) = mask bits 4q..4q+3
;   within a nibble: bit 0 = top-left tile (+0), bit 1 = top-right (+1), bit 2 = bottom-left (+32),
;   bit 3 = bottom-right (+33)
;
; Double-buffered shadows.  PPUDATA_WRITE stores every changed nametable byte into PPU_CIRAM *and* into
; the current buffer: the byte itself (PPU_MEM) and, for a tile, its bit in the group mask (main bank).
; A group is queued on at_list when the first bit of a mask half is set, or when its attribute byte is
; first written (flag), so a group can appear up to three times; repeat visits find nothing to do.
; PPUFreezeNametableUpdates (interrupts off) only flips the write path to the other buffer by patching
; its operands.  PPUFlushQueuesAlt reads the previous buffer with interrupts on while the ROM fills the
; other one.  A buffer's data is valid exactly where its masks / flags say a byte was written; every
; other value is unchanged since the last render and already in TILE_SHADOW.  The flush clears the
; masks and flags it consumes, so a buffer is clean again before it becomes current.
;
; Buffers (buffer 1 = buffer 0 + $2000 in PPU_MEM, + $100 in the main bank):
;
;   PPU_MEM+NTM_SB0     data, indexed by CIRAM address
;   NTM_MASK0           16-bit tile masks, one word per group (index * 2; T2IDX = index * 2 + half)
;   NTM_FLAG0           attribute-written flag per group (index * 2)
;
; Attribute index = CIRAM page << 6 | attribute offset ($00-$3F).
;
; Routines:
;   ntmWriteTail / atmWriteTail - End of PPUDATA_WRITE for a tile / attribute byte
;   PPUFreezeNametableUpdates - Flip the write path to the other buffer (interrupts off)
;   PPUFlushQueuesAlt         - Draw the previous buffer's updates into the PEA field
;   PPUResetQueues            - Empty queues, clean buffers, write path on buffer 0

NTM_SB0     equ   $C800                     ; Shadow data buffer 0 (PPU_MEM offset); buffer 1 is $2000 higher
NTM_SB1     equ   NTM_SB0+$2000

; Attribute indices queued for rendering.  Two halves: the ROM fills curr while the render reads prev;
; NES_RenderFrame swaps them with interrupts off.  Up to 3 entries per group (2 mask halves, attribute).
AT_LIST_LEN        equ 384
curr_at_list_start dw 0
curr_at_list_end   dw 0
prev_at_list_start dw {AT_LIST_LEN*2}
prev_at_list_end   dw {AT_LIST_LEN*2}
at_list            ds {AT_LIST_LEN*4}

ntmSel      dw    0                         ; $00 / $20: high-byte offset of the PPU_MEM buffer being written
ntmDelta    dw    0                         ; Operand adjustment for the PPU_MEM sites ($20 / $E0)
ntmDelta2   dw    0                         ; Operand adjustment for the main bank sites ($01 / $FF)
ntmY        dw    0
ntmBit      dw    0

; Masks and flags of both buffers, each array page-aligned (no page-crossing cycles; buffer 1 = +$100)
            ds    \,$00
NTM_MASK0   ds    256
NTM_MASK1   ds    256
NTM_FLAG0   ds    256
NTM_FLAG1   ds    256

; ---------------------------------------------------------------------------
; ntmWriteTail
; ---------------------------------------------------------------------------
; Jumped to from PPUDATA_WRITE once a *changed* nametable byte has been stored in PPU_CIRAM.  A = value
; (8-bit), X = CIRAM address (16-bit X/Y), DBR = K, PPUDATA_WRITE's saved P / B / A / X on the stack.
; The *Site* operands address the current buffer and are moved by PPUFreezeNametableUpdates, so this
; routine uses global labels only.  Y belongs to the ROM and is preserved.
            mx    %10
ntmWriteTail
ntmSiteD    stal  PPU_MEM+NTM_SB0,x           ; The byte, for the render that reads this buffer
            sty   ntmY
            lda   #0
            xba                               ; B = 0 for the transfers to Y
            lda   T2BIT,x
            beq   atmWrite                    ; Attribute bytes have no tile bit
            sta   ntmBit
            lda   T2IDX,x
            tay                               ; Y = group index * 2 + half
ntmSiteM0   lda   NTM_MASK0,y
            beq   ntmFirst
            ora   ntmBit
ntmSiteM1   sta   NTM_MASK0,y
            ldy   ntmY
            bra   ntmExit

ntmFirst    lda   ntmBit                      ; First tile in this half of the group: queue the group
ntmSiteM2   sta   NTM_MASK0,y
            bra   ntmPush

atmWrite    lda   T2IDX,x
            tay                               ; Y = group index * 2
atmSiteF0   lda   NTM_FLAG0,y
            bne   ntmDone                     ; Already flagged (and queued) this period
            inc
atmSiteF1   sta   NTM_FLAG0,y

ntmPush     rep   #$20                        ; Append the group index to at_list
            tya
            lsr
            ldx   curr_at_list_end
            sta   at_list,x
            inx
            inx
            stx   curr_at_list_end
ntmDone     ldy   ntmY
ntmExit     sep   #$30
            plx
            pla
            plb
            plp
            rtl

; ---------------------------------------------------------------------------
; PPUFreezeNametableUpdates
; ---------------------------------------------------------------------------
; Called with interrupts off, right after NES_RenderFrame swapped the at_list halves.  Moves the write
; path to the other buffer; the flush reads the one it was filling.
        mx  %00
PPUFreezeNametableUpdates
        sep  #$20
        lda  ntmSel
        eor  #$20
        sta  ntmSel
        beq  :down
        lda  #$20                             ; Buffer 0 -> buffer 1
        bra  :set
:down   lda  #$E0                             ; Buffer 1 -> buffer 0
:set    sta  ntmDelta
        asl                                   ; $20 -> C = 0 (buffer 0 -> 1), $E0 -> C = 1 (1 -> 0)
        lda  #$01
        bcc  :fw
        lda  #$FF
:fw     sta  ntmDelta2

        lda  ntmSiteD+2
        clc
        adc  ntmDelta
        sta  ntmSiteD+2
        lda  ntmSiteM0+2
        clc
        adc  ntmDelta2
        sta  ntmSiteM0+2
        lda  ntmSiteM1+2
        clc
        adc  ntmDelta2
        sta  ntmSiteM1+2
        lda  ntmSiteM2+2
        clc
        adc  ntmDelta2
        sta  ntmSiteM2+2
        lda  atmSiteF0+2
        clc
        adc  ntmDelta2
        sta  atmSiteF0+2
        lda  atmSiteF1+2
        clc
        adc  ntmDelta2
        sta  atmSiteF1+2
        rep  #$20
        rts

; ---------------------------------------------------------------------------
; PPUFlushQueuesAlt
; ---------------------------------------------------------------------------
; Draw every queued attribute group from the previous buffer into the PEA field.  For each group:
;
;   1. take its tile mask and flags from the buffer (and clear them)
;   2. attribute value: from the buffer if it was written, else the last applied one (no change)
;   3. mask = tile mask | palette changes expanded to whole metatiles
;   4. per metatile (nibble): all 4 tiles -> copy the written ones from the buffer into TILE_SHADOW,
;      then SyncPPUMetatile / RefreshMetatile (batched); otherwise dispatch on the nibble to a routine
;      that copies and draws just those tiles
        mx    %00
PPUFlushQueuesAlt
        lda   ntmSiteD+1                      ; The previous buffer is the one not being written now: the
        eor   #$2000                          ; write path's (relocated) operand with buffer 0 <-> 1.  Not
        sta   NtmPtr                          ; #PPU_MEM+NTM_SB0: when PPU_MEM is EXT (Zelda) the loader drops
        lda   ntmSiteD+3                      ; the +constant of a 16-bit operand (MERLIN32_OMF_EXT_OFFSET_BUG.md)
        and   #$00FF
        sta   NtmPtr+2
        lda   ntmSel
        and   #$00FF
        eor   #$0020
        lsr
        lsr
        lsr
        lsr
        lsr
        xba                                   ; $20 -> $0100
        sta   NtmPrev                         ; Its masks / flags: main bank offset $000 / $100
        stz   NtmNib                          ; (only its low byte is written below)

        ldy   prev_at_list_start
:entry  cpy   prev_at_list_end
        bcc   *+5
        brl   :done
        phy
        lda   at_list,y
        sta   NtmIdx                          ; page << 6 | attribute offset
        asl
        tax                                   ; X = index * 2
        lda   AttrBaseTbl,x                   ; Top-left tile of the group
        sta   NtmBase
        txa
        clc
        adc   NtmPrev
        tay                                   ; Y = the group's mask / flag in the buffer being drawn

; 1. Mask and flag, cleared for the buffer's next period.  A group queued more than once (both mask halves
;    and / or the attribute) finds them already consumed on the later visits.

        lda   NTM_FLAG0,y                     ; (the odd byte is never written: high byte 0)
        bne   :attr_written
        lda   NTM_MASK0,y                     ; Tiles only: palette unchanged
        bne   *+5
        brl   :next                           ; Repeat visit
        sta   NtmTMask
        sta   NtmMask
        lda   #0
        sta   NTM_MASK0,y
        lda   #$8000                          ; Attribute value loaded on demand (whole-metatile redraw)
        sta   NtmAttr
        stz   NtmDiff
        bra   :draw

; 2. Attribute written: its change against the last applied value (TILE_SHADOW at the attribute address)

:attr_written
        lda   NTM_MASK0,y
        sta   NtmTMask
        lda   #0
        sta   NTM_MASK0,y
        sta   NTM_FLAG0,y
        lda   AttrAddrTbl,x                   ; CIRAM address of the attribute byte
        sta   NtmAttrAddr
        tax
        tay
        sep   #$20
        stz   NtmAttr+1
        stz   NtmDiff+1
        lda   [NtmPtr],y
        sta   NtmAttr
        eorl  PPU_MEM+TILE_SHADOW,x
        sta   NtmDiff
        lda   NtmAttr
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20

; 3. Palette changes redraw whole metatiles.  Rows 30-31 of the last attribute row are attribute bytes,
;    so that row has no bottom metatiles.

        lda   NtmDiff
        asl
        tax
        lda   AttrExpand,x
        ora   NtmTMask
        sta   NtmMask
        lda   NtmIdx
        and   #$0038
        cmp   #$0038
        bne   :draw
        lda   #$FF00
        trb   NtmMask

; 4. Draw, one metatile at a time.  Each written tile is first copied from the buffer to TILE_SHADOW
;    (only those positions are valid in the buffer).
:draw

        sep   #$20
        lda   NtmMask                       ; Metatiles 0, 1
        bne   *+5
        brl   :hi
        lda   NtmMask                       ; Metatile 0
        and   #$0F
        bne   *+5
        brl   :d0
        cmp   #$0F
        beq   *+5
        brl   :p0
        rep   #$20
        lda   NtmTMask
        bit   #$0001
        beq   :f00
        lda   NtmBase
        clc
        adc   #0
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f00
        lda   NtmTMask
        bit   #$0002
        beq   :f01
        lda   NtmBase
        clc
        adc   #1
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f01
        lda   NtmTMask
        bit   #$0004
        beq   :f02
        lda   NtmBase
        clc
        adc   #32
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f02
        lda   NtmTMask
        bit   #$0008
        beq   :f03
        lda   NtmBase
        clc
        adc   #33
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f03
        lda   NtmAttr                         ; All 4 tiles: batched redraw with the metatile's palette
        bpl   :a0
        lda   NtmIdx                          ; (tile-only group: attribute not loaded yet)
        asl
        tax
        lda   AttrAddrTbl,x
        tax
        ldal  PPU_MEM+TILE_SHADOW,x
        and   #$00FF
        sta   NtmAttr
:a0   and   #$0003
        asl                         ; Palette select * 2
        sta   NtmPal
        lda   NtmBase
        clc
        adc   #0
        tax
        lda   #0                              ; (B = 0 for the metatile routines)
        sep   #$20
        lda   NtmDiff
        and   #$03
        beq   :r0
        lda   NtmPal
        jsr   SyncPPUMetatile                 ; Palette changed: update ATTR_SHADOW too
        brl   :row0
:r0   lda   NtmPal
        jsr   RefreshMetatile
        brl   :row0
:p0   sta   NtmNib
        rep   #$20
        lda   NtmBase
        clc
        adc   #0
        sta   NtmQBase
        lda   NtmNib
        asl
        tax
        jsr   (ntmPartTbl,x)                  ; Copy + draw the set tiles
        DO    GRID_DIRTY_RENDERING
        ldx   gmtEnd                          ; Let the grid renderer expose these tiles (gmtList entry)
        cpx   #GRID_MAX_METATILES*4
        bcs   :o0
        lda   NtmQBase
        sta   gmtList,x
        lda   NtmNib
        sta   gmtList+2,x
        txa
        clc
        adc   #4
        sta   gmtEnd
        bra   :row0
:o0   lda   #1
        sta   gmtOverflow
        FIN
:row0
        sep   #$20
:d0
        lda   NtmMask                       ; Metatile 1
        lsr
        lsr
        lsr
        lsr
        bne   *+5
        brl   :d1
        cmp   #$0F
        beq   *+5
        brl   :p1
        rep   #$20
        lda   NtmTMask
        bit   #$0010
        beq   :f10
        lda   NtmBase
        clc
        adc   #2
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f10
        lda   NtmTMask
        bit   #$0020
        beq   :f11
        lda   NtmBase
        clc
        adc   #3
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f11
        lda   NtmTMask
        bit   #$0040
        beq   :f12
        lda   NtmBase
        clc
        adc   #34
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f12
        lda   NtmTMask
        bit   #$0080
        beq   :f13
        lda   NtmBase
        clc
        adc   #35
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f13
        lda   NtmAttr                         ; All 4 tiles: batched redraw with the metatile's palette
        bpl   :a1
        lda   NtmIdx                          ; (tile-only group: attribute not loaded yet)
        asl
        tax
        lda   AttrAddrTbl,x
        tax
        ldal  PPU_MEM+TILE_SHADOW,x
        and   #$00FF
        sta   NtmAttr
:a1   and   #$000C
        lsr                         ; Palette select * 2
        sta   NtmPal
        lda   NtmBase
        clc
        adc   #2
        tax
        lda   #0                              ; (B = 0 for the metatile routines)
        sep   #$20
        lda   NtmDiff
        and   #$0C
        beq   :r1
        lda   NtmPal
        jsr   SyncPPUMetatile                 ; Palette changed: update ATTR_SHADOW too
        brl   :row1
:r1   lda   NtmPal
        jsr   RefreshMetatile
        brl   :row1
:p1   sta   NtmNib
        rep   #$20
        lda   NtmBase
        clc
        adc   #2
        sta   NtmQBase
        lda   NtmNib
        asl
        tax
        jsr   (ntmPartTbl,x)                  ; Copy + draw the set tiles
        DO    GRID_DIRTY_RENDERING
        ldx   gmtEnd                          ; Let the grid renderer expose these tiles (gmtList entry)
        cpx   #GRID_MAX_METATILES*4
        bcs   :o1
        lda   NtmQBase
        sta   gmtList,x
        lda   NtmNib
        sta   gmtList+2,x
        txa
        clc
        adc   #4
        sta   gmtEnd
        bra   :row1
:o1   lda   #1
        sta   gmtOverflow
        FIN
:row1
        sep   #$20
:d1
:hi
        lda   NtmMask+1                       ; Metatiles 2, 3
        bne   *+5
        brl   :dn
        lda   NtmMask+1                       ; Metatile 2
        and   #$0F
        bne   *+5
        brl   :d2
        cmp   #$0F
        beq   *+5
        brl   :p2
        rep   #$20
        lda   NtmTMask
        bit   #$0100
        beq   :f20
        lda   NtmBase
        clc
        adc   #64
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f20
        lda   NtmTMask
        bit   #$0200
        beq   :f21
        lda   NtmBase
        clc
        adc   #65
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f21
        lda   NtmTMask
        bit   #$0400
        beq   :f22
        lda   NtmBase
        clc
        adc   #96
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f22
        lda   NtmTMask
        bit   #$0800
        beq   :f23
        lda   NtmBase
        clc
        adc   #97
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f23
        lda   NtmAttr                         ; All 4 tiles: batched redraw with the metatile's palette
        bpl   :a2
        lda   NtmIdx                          ; (tile-only group: attribute not loaded yet)
        asl
        tax
        lda   AttrAddrTbl,x
        tax
        ldal  PPU_MEM+TILE_SHADOW,x
        and   #$00FF
        sta   NtmAttr
:a2   and   #$0030
        lsr
        lsr
        lsr                         ; Palette select * 2
        sta   NtmPal
        lda   NtmBase
        clc
        adc   #64
        tax
        lda   #0                              ; (B = 0 for the metatile routines)
        sep   #$20
        lda   NtmDiff
        and   #$30
        beq   :r2
        lda   NtmPal
        jsr   SyncPPUMetatile                 ; Palette changed: update ATTR_SHADOW too
        brl   :row2
:r2   lda   NtmPal
        jsr   RefreshMetatile
        brl   :row2
:p2   sta   NtmNib
        rep   #$20
        lda   NtmBase
        clc
        adc   #64
        sta   NtmQBase
        lda   NtmNib
        asl
        tax
        jsr   (ntmPartTbl,x)                  ; Copy + draw the set tiles
        DO    GRID_DIRTY_RENDERING
        ldx   gmtEnd                          ; Let the grid renderer expose these tiles (gmtList entry)
        cpx   #GRID_MAX_METATILES*4
        bcs   :o2
        lda   NtmQBase
        sta   gmtList,x
        lda   NtmNib
        sta   gmtList+2,x
        txa
        clc
        adc   #4
        sta   gmtEnd
        bra   :row2
:o2   lda   #1
        sta   gmtOverflow
        FIN
:row2
        sep   #$20
:d2
        lda   NtmMask+1                       ; Metatile 3
        lsr
        lsr
        lsr
        lsr
        bne   *+5
        brl   :d3
        cmp   #$0F
        beq   *+5
        brl   :p3
        rep   #$20
        lda   NtmTMask
        bit   #$1000
        beq   :f30
        lda   NtmBase
        clc
        adc   #66
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f30
        lda   NtmTMask
        bit   #$2000
        beq   :f31
        lda   NtmBase
        clc
        adc   #67
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f31
        lda   NtmTMask
        bit   #$4000
        beq   :f32
        lda   NtmBase
        clc
        adc   #98
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f32
        lda   NtmTMask
        bit   #$8000
        beq   :f33
        lda   NtmBase
        clc
        adc   #99
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        rep   #$20
:f33
        lda   NtmAttr                         ; All 4 tiles: batched redraw with the metatile's palette
        bpl   :a3
        lda   NtmIdx                          ; (tile-only group: attribute not loaded yet)
        asl
        tax
        lda   AttrAddrTbl,x
        tax
        ldal  PPU_MEM+TILE_SHADOW,x
        and   #$00FF
        sta   NtmAttr
:a3   and   #$00C0
        lsr
        lsr
        lsr
        lsr
        lsr                         ; Palette select * 2
        sta   NtmPal
        lda   NtmBase
        clc
        adc   #66
        tax
        lda   #0                              ; (B = 0 for the metatile routines)
        sep   #$20
        lda   NtmDiff
        and   #$C0
        beq   :r3
        lda   NtmPal
        jsr   SyncPPUMetatile                 ; Palette changed: update ATTR_SHADOW too
        brl   :row3
:r3   lda   NtmPal
        jsr   RefreshMetatile
        brl   :row3
:p3   sta   NtmNib
        rep   #$20
        lda   NtmBase
        clc
        adc   #66
        sta   NtmQBase
        lda   NtmNib
        asl
        tax
        jsr   (ntmPartTbl,x)                  ; Copy + draw the set tiles
        DO    GRID_DIRTY_RENDERING
        ldx   gmtEnd                          ; Let the grid renderer expose these tiles (gmtList entry)
        cpx   #GRID_MAX_METATILES*4
        bcs   :o3
        lda   NtmQBase
        sta   gmtList,x
        lda   NtmNib
        sta   gmtList+2,x
        txa
        clc
        adc   #4
        sta   gmtEnd
        bra   :row3
:o3   lda   #1
        sta   gmtOverflow
        FIN
:row3
        sep   #$20
:d3
:dn     rep   #$20
:next   ply
        iny
        iny
        brl   :entry
:done
        rts

; Partial metatiles: copy each written tile of nibble n from the buffer into TILE_SHADOW and draw it.
; NtmQBase = CIRAM address of the metatile's top-left tile.  16-bit A on entry and exit.
        mx    %00
ntmPart1
        ldx   NtmQBase
        txy
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart2
        lda   NtmQBase
        clc
        adc   #1
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart3
        ldx   NtmQBase
        txy
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #1
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart4
        lda   NtmQBase
        clc
        adc   #32
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart5
        ldx   NtmQBase
        txy
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #32
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart6
        lda   NtmQBase
        clc
        adc   #1
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #32
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart7
        ldx   NtmQBase
        txy
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #1
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #32
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart8
        lda   NtmQBase
        clc
        adc   #33
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart9
        ldx   NtmQBase
        txy
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #33
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart10
        lda   NtmQBase
        clc
        adc   #1
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #33
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart11
        ldx   NtmQBase
        txy
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #1
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #33
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart12
        lda   NtmQBase
        clc
        adc   #32
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #33
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart13
        ldx   NtmQBase
        txy
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #32
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #33
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts
ntmPart14
        lda   NtmQBase
        clc
        adc   #1
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #32
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        lda   NtmQBase
        clc
        adc   #33
        tax
        tay
        sep   #$20
        lda   [NtmPtr],y
        stal  PPU_MEM+TILE_SHADOW,x
        jsr   DrawPPUTile
        rep   #$20
        rts

ntmPartTbl  dw    0,ntmPart1,ntmPart2,ntmPart3,ntmPart4,ntmPart5,ntmPart6,ntmPart7
            dw    ntmPart8,ntmPart9,ntmPart10,ntmPart11,ntmPart12,ntmPart13,ntmPart14,0

; ---------------------------------------------------------------------------
; PPUResetQueues
; ---------------------------------------------------------------------------
        mx    %00
PPUResetQueues
        stz    curr_at_list_start
        stz    curr_at_list_end
        lda    #{AT_LIST_LEN*2}
        sta    prev_at_list_start
        sta    prev_at_list_end

        lda    ntmSel                         ; Write path back on buffer 0
        and    #$00FF
        beq    :sel0
        jsr    PPUFreezeNametableUpdates
:sel0
        ldx    #$03FE                          ; Clean both buffers' masks and flags
        lda    #0
:clr    sta    NTM_MASK0,x
        dex
        dex
        bpl    :clr
        rts

; ---------------------------------------------------------------------------
; Tables (generated)
; ---------------------------------------------------------------------------

; CIRAM address -> group index * 2 (+ row bit 1 for tiles, i.e. the LO / HI byte of the group mask)
T2IDX
            db    $00,$00,$00,$00,$02,$02,$02,$02,$04,$04,$04,$04,$06,$06,$06,$06
            db    $08,$08,$08,$08,$0A,$0A,$0A,$0A,$0C,$0C,$0C,$0C,$0E,$0E,$0E,$0E
            db    $00,$00,$00,$00,$02,$02,$02,$02,$04,$04,$04,$04,$06,$06,$06,$06
            db    $08,$08,$08,$08,$0A,$0A,$0A,$0A,$0C,$0C,$0C,$0C,$0E,$0E,$0E,$0E
            db    $01,$01,$01,$01,$03,$03,$03,$03,$05,$05,$05,$05,$07,$07,$07,$07
            db    $09,$09,$09,$09,$0B,$0B,$0B,$0B,$0D,$0D,$0D,$0D,$0F,$0F,$0F,$0F
            db    $01,$01,$01,$01,$03,$03,$03,$03,$05,$05,$05,$05,$07,$07,$07,$07
            db    $09,$09,$09,$09,$0B,$0B,$0B,$0B,$0D,$0D,$0D,$0D,$0F,$0F,$0F,$0F
            db    $10,$10,$10,$10,$12,$12,$12,$12,$14,$14,$14,$14,$16,$16,$16,$16
            db    $18,$18,$18,$18,$1A,$1A,$1A,$1A,$1C,$1C,$1C,$1C,$1E,$1E,$1E,$1E
            db    $10,$10,$10,$10,$12,$12,$12,$12,$14,$14,$14,$14,$16,$16,$16,$16
            db    $18,$18,$18,$18,$1A,$1A,$1A,$1A,$1C,$1C,$1C,$1C,$1E,$1E,$1E,$1E
            db    $11,$11,$11,$11,$13,$13,$13,$13,$15,$15,$15,$15,$17,$17,$17,$17
            db    $19,$19,$19,$19,$1B,$1B,$1B,$1B,$1D,$1D,$1D,$1D,$1F,$1F,$1F,$1F
            db    $11,$11,$11,$11,$13,$13,$13,$13,$15,$15,$15,$15,$17,$17,$17,$17
            db    $19,$19,$19,$19,$1B,$1B,$1B,$1B,$1D,$1D,$1D,$1D,$1F,$1F,$1F,$1F
            db    $20,$20,$20,$20,$22,$22,$22,$22,$24,$24,$24,$24,$26,$26,$26,$26
            db    $28,$28,$28,$28,$2A,$2A,$2A,$2A,$2C,$2C,$2C,$2C,$2E,$2E,$2E,$2E
            db    $20,$20,$20,$20,$22,$22,$22,$22,$24,$24,$24,$24,$26,$26,$26,$26
            db    $28,$28,$28,$28,$2A,$2A,$2A,$2A,$2C,$2C,$2C,$2C,$2E,$2E,$2E,$2E
            db    $21,$21,$21,$21,$23,$23,$23,$23,$25,$25,$25,$25,$27,$27,$27,$27
            db    $29,$29,$29,$29,$2B,$2B,$2B,$2B,$2D,$2D,$2D,$2D,$2F,$2F,$2F,$2F
            db    $21,$21,$21,$21,$23,$23,$23,$23,$25,$25,$25,$25,$27,$27,$27,$27
            db    $29,$29,$29,$29,$2B,$2B,$2B,$2B,$2D,$2D,$2D,$2D,$2F,$2F,$2F,$2F
            db    $30,$30,$30,$30,$32,$32,$32,$32,$34,$34,$34,$34,$36,$36,$36,$36
            db    $38,$38,$38,$38,$3A,$3A,$3A,$3A,$3C,$3C,$3C,$3C,$3E,$3E,$3E,$3E
            db    $30,$30,$30,$30,$32,$32,$32,$32,$34,$34,$34,$34,$36,$36,$36,$36
            db    $38,$38,$38,$38,$3A,$3A,$3A,$3A,$3C,$3C,$3C,$3C,$3E,$3E,$3E,$3E
            db    $31,$31,$31,$31,$33,$33,$33,$33,$35,$35,$35,$35,$37,$37,$37,$37
            db    $39,$39,$39,$39,$3B,$3B,$3B,$3B,$3D,$3D,$3D,$3D,$3F,$3F,$3F,$3F
            db    $31,$31,$31,$31,$33,$33,$33,$33,$35,$35,$35,$35,$37,$37,$37,$37
            db    $39,$39,$39,$39,$3B,$3B,$3B,$3B,$3D,$3D,$3D,$3D,$3F,$3F,$3F,$3F
            db    $40,$40,$40,$40,$42,$42,$42,$42,$44,$44,$44,$44,$46,$46,$46,$46
            db    $48,$48,$48,$48,$4A,$4A,$4A,$4A,$4C,$4C,$4C,$4C,$4E,$4E,$4E,$4E
            db    $40,$40,$40,$40,$42,$42,$42,$42,$44,$44,$44,$44,$46,$46,$46,$46
            db    $48,$48,$48,$48,$4A,$4A,$4A,$4A,$4C,$4C,$4C,$4C,$4E,$4E,$4E,$4E
            db    $41,$41,$41,$41,$43,$43,$43,$43,$45,$45,$45,$45,$47,$47,$47,$47
            db    $49,$49,$49,$49,$4B,$4B,$4B,$4B,$4D,$4D,$4D,$4D,$4F,$4F,$4F,$4F
            db    $41,$41,$41,$41,$43,$43,$43,$43,$45,$45,$45,$45,$47,$47,$47,$47
            db    $49,$49,$49,$49,$4B,$4B,$4B,$4B,$4D,$4D,$4D,$4D,$4F,$4F,$4F,$4F
            db    $50,$50,$50,$50,$52,$52,$52,$52,$54,$54,$54,$54,$56,$56,$56,$56
            db    $58,$58,$58,$58,$5A,$5A,$5A,$5A,$5C,$5C,$5C,$5C,$5E,$5E,$5E,$5E
            db    $50,$50,$50,$50,$52,$52,$52,$52,$54,$54,$54,$54,$56,$56,$56,$56
            db    $58,$58,$58,$58,$5A,$5A,$5A,$5A,$5C,$5C,$5C,$5C,$5E,$5E,$5E,$5E
            db    $51,$51,$51,$51,$53,$53,$53,$53,$55,$55,$55,$55,$57,$57,$57,$57
            db    $59,$59,$59,$59,$5B,$5B,$5B,$5B,$5D,$5D,$5D,$5D,$5F,$5F,$5F,$5F
            db    $51,$51,$51,$51,$53,$53,$53,$53,$55,$55,$55,$55,$57,$57,$57,$57
            db    $59,$59,$59,$59,$5B,$5B,$5B,$5B,$5D,$5D,$5D,$5D,$5F,$5F,$5F,$5F
            db    $60,$60,$60,$60,$62,$62,$62,$62,$64,$64,$64,$64,$66,$66,$66,$66
            db    $68,$68,$68,$68,$6A,$6A,$6A,$6A,$6C,$6C,$6C,$6C,$6E,$6E,$6E,$6E
            db    $60,$60,$60,$60,$62,$62,$62,$62,$64,$64,$64,$64,$66,$66,$66,$66
            db    $68,$68,$68,$68,$6A,$6A,$6A,$6A,$6C,$6C,$6C,$6C,$6E,$6E,$6E,$6E
            db    $61,$61,$61,$61,$63,$63,$63,$63,$65,$65,$65,$65,$67,$67,$67,$67
            db    $69,$69,$69,$69,$6B,$6B,$6B,$6B,$6D,$6D,$6D,$6D,$6F,$6F,$6F,$6F
            db    $61,$61,$61,$61,$63,$63,$63,$63,$65,$65,$65,$65,$67,$67,$67,$67
            db    $69,$69,$69,$69,$6B,$6B,$6B,$6B,$6D,$6D,$6D,$6D,$6F,$6F,$6F,$6F
            db    $70,$70,$70,$70,$72,$72,$72,$72,$74,$74,$74,$74,$76,$76,$76,$76
            db    $78,$78,$78,$78,$7A,$7A,$7A,$7A,$7C,$7C,$7C,$7C,$7E,$7E,$7E,$7E
            db    $70,$70,$70,$70,$72,$72,$72,$72,$74,$74,$74,$74,$76,$76,$76,$76
            db    $78,$78,$78,$78,$7A,$7A,$7A,$7A,$7C,$7C,$7C,$7C,$7E,$7E,$7E,$7E
            db    $00,$02,$04,$06,$08,$0A,$0C,$0E,$10,$12,$14,$16,$18,$1A,$1C,$1E
            db    $20,$22,$24,$26,$28,$2A,$2C,$2E,$30,$32,$34,$36,$38,$3A,$3C,$3E
            db    $40,$42,$44,$46,$48,$4A,$4C,$4E,$50,$52,$54,$56,$58,$5A,$5C,$5E
            db    $60,$62,$64,$66,$68,$6A,$6C,$6E,$70,$72,$74,$76,$78,$7A,$7C,$7E
            db    $80,$80,$80,$80,$82,$82,$82,$82,$84,$84,$84,$84,$86,$86,$86,$86
            db    $88,$88,$88,$88,$8A,$8A,$8A,$8A,$8C,$8C,$8C,$8C,$8E,$8E,$8E,$8E
            db    $80,$80,$80,$80,$82,$82,$82,$82,$84,$84,$84,$84,$86,$86,$86,$86
            db    $88,$88,$88,$88,$8A,$8A,$8A,$8A,$8C,$8C,$8C,$8C,$8E,$8E,$8E,$8E
            db    $81,$81,$81,$81,$83,$83,$83,$83,$85,$85,$85,$85,$87,$87,$87,$87
            db    $89,$89,$89,$89,$8B,$8B,$8B,$8B,$8D,$8D,$8D,$8D,$8F,$8F,$8F,$8F
            db    $81,$81,$81,$81,$83,$83,$83,$83,$85,$85,$85,$85,$87,$87,$87,$87
            db    $89,$89,$89,$89,$8B,$8B,$8B,$8B,$8D,$8D,$8D,$8D,$8F,$8F,$8F,$8F
            db    $90,$90,$90,$90,$92,$92,$92,$92,$94,$94,$94,$94,$96,$96,$96,$96
            db    $98,$98,$98,$98,$9A,$9A,$9A,$9A,$9C,$9C,$9C,$9C,$9E,$9E,$9E,$9E
            db    $90,$90,$90,$90,$92,$92,$92,$92,$94,$94,$94,$94,$96,$96,$96,$96
            db    $98,$98,$98,$98,$9A,$9A,$9A,$9A,$9C,$9C,$9C,$9C,$9E,$9E,$9E,$9E
            db    $91,$91,$91,$91,$93,$93,$93,$93,$95,$95,$95,$95,$97,$97,$97,$97
            db    $99,$99,$99,$99,$9B,$9B,$9B,$9B,$9D,$9D,$9D,$9D,$9F,$9F,$9F,$9F
            db    $91,$91,$91,$91,$93,$93,$93,$93,$95,$95,$95,$95,$97,$97,$97,$97
            db    $99,$99,$99,$99,$9B,$9B,$9B,$9B,$9D,$9D,$9D,$9D,$9F,$9F,$9F,$9F
            db    $A0,$A0,$A0,$A0,$A2,$A2,$A2,$A2,$A4,$A4,$A4,$A4,$A6,$A6,$A6,$A6
            db    $A8,$A8,$A8,$A8,$AA,$AA,$AA,$AA,$AC,$AC,$AC,$AC,$AE,$AE,$AE,$AE
            db    $A0,$A0,$A0,$A0,$A2,$A2,$A2,$A2,$A4,$A4,$A4,$A4,$A6,$A6,$A6,$A6
            db    $A8,$A8,$A8,$A8,$AA,$AA,$AA,$AA,$AC,$AC,$AC,$AC,$AE,$AE,$AE,$AE
            db    $A1,$A1,$A1,$A1,$A3,$A3,$A3,$A3,$A5,$A5,$A5,$A5,$A7,$A7,$A7,$A7
            db    $A9,$A9,$A9,$A9,$AB,$AB,$AB,$AB,$AD,$AD,$AD,$AD,$AF,$AF,$AF,$AF
            db    $A1,$A1,$A1,$A1,$A3,$A3,$A3,$A3,$A5,$A5,$A5,$A5,$A7,$A7,$A7,$A7
            db    $A9,$A9,$A9,$A9,$AB,$AB,$AB,$AB,$AD,$AD,$AD,$AD,$AF,$AF,$AF,$AF
            db    $B0,$B0,$B0,$B0,$B2,$B2,$B2,$B2,$B4,$B4,$B4,$B4,$B6,$B6,$B6,$B6
            db    $B8,$B8,$B8,$B8,$BA,$BA,$BA,$BA,$BC,$BC,$BC,$BC,$BE,$BE,$BE,$BE
            db    $B0,$B0,$B0,$B0,$B2,$B2,$B2,$B2,$B4,$B4,$B4,$B4,$B6,$B6,$B6,$B6
            db    $B8,$B8,$B8,$B8,$BA,$BA,$BA,$BA,$BC,$BC,$BC,$BC,$BE,$BE,$BE,$BE
            db    $B1,$B1,$B1,$B1,$B3,$B3,$B3,$B3,$B5,$B5,$B5,$B5,$B7,$B7,$B7,$B7
            db    $B9,$B9,$B9,$B9,$BB,$BB,$BB,$BB,$BD,$BD,$BD,$BD,$BF,$BF,$BF,$BF
            db    $B1,$B1,$B1,$B1,$B3,$B3,$B3,$B3,$B5,$B5,$B5,$B5,$B7,$B7,$B7,$B7
            db    $B9,$B9,$B9,$B9,$BB,$BB,$BB,$BB,$BD,$BD,$BD,$BD,$BF,$BF,$BF,$BF
            db    $C0,$C0,$C0,$C0,$C2,$C2,$C2,$C2,$C4,$C4,$C4,$C4,$C6,$C6,$C6,$C6
            db    $C8,$C8,$C8,$C8,$CA,$CA,$CA,$CA,$CC,$CC,$CC,$CC,$CE,$CE,$CE,$CE
            db    $C0,$C0,$C0,$C0,$C2,$C2,$C2,$C2,$C4,$C4,$C4,$C4,$C6,$C6,$C6,$C6
            db    $C8,$C8,$C8,$C8,$CA,$CA,$CA,$CA,$CC,$CC,$CC,$CC,$CE,$CE,$CE,$CE
            db    $C1,$C1,$C1,$C1,$C3,$C3,$C3,$C3,$C5,$C5,$C5,$C5,$C7,$C7,$C7,$C7
            db    $C9,$C9,$C9,$C9,$CB,$CB,$CB,$CB,$CD,$CD,$CD,$CD,$CF,$CF,$CF,$CF
            db    $C1,$C1,$C1,$C1,$C3,$C3,$C3,$C3,$C5,$C5,$C5,$C5,$C7,$C7,$C7,$C7
            db    $C9,$C9,$C9,$C9,$CB,$CB,$CB,$CB,$CD,$CD,$CD,$CD,$CF,$CF,$CF,$CF
            db    $D0,$D0,$D0,$D0,$D2,$D2,$D2,$D2,$D4,$D4,$D4,$D4,$D6,$D6,$D6,$D6
            db    $D8,$D8,$D8,$D8,$DA,$DA,$DA,$DA,$DC,$DC,$DC,$DC,$DE,$DE,$DE,$DE
            db    $D0,$D0,$D0,$D0,$D2,$D2,$D2,$D2,$D4,$D4,$D4,$D4,$D6,$D6,$D6,$D6
            db    $D8,$D8,$D8,$D8,$DA,$DA,$DA,$DA,$DC,$DC,$DC,$DC,$DE,$DE,$DE,$DE
            db    $D1,$D1,$D1,$D1,$D3,$D3,$D3,$D3,$D5,$D5,$D5,$D5,$D7,$D7,$D7,$D7
            db    $D9,$D9,$D9,$D9,$DB,$DB,$DB,$DB,$DD,$DD,$DD,$DD,$DF,$DF,$DF,$DF
            db    $D1,$D1,$D1,$D1,$D3,$D3,$D3,$D3,$D5,$D5,$D5,$D5,$D7,$D7,$D7,$D7
            db    $D9,$D9,$D9,$D9,$DB,$DB,$DB,$DB,$DD,$DD,$DD,$DD,$DF,$DF,$DF,$DF
            db    $E0,$E0,$E0,$E0,$E2,$E2,$E2,$E2,$E4,$E4,$E4,$E4,$E6,$E6,$E6,$E6
            db    $E8,$E8,$E8,$E8,$EA,$EA,$EA,$EA,$EC,$EC,$EC,$EC,$EE,$EE,$EE,$EE
            db    $E0,$E0,$E0,$E0,$E2,$E2,$E2,$E2,$E4,$E4,$E4,$E4,$E6,$E6,$E6,$E6
            db    $E8,$E8,$E8,$E8,$EA,$EA,$EA,$EA,$EC,$EC,$EC,$EC,$EE,$EE,$EE,$EE
            db    $E1,$E1,$E1,$E1,$E3,$E3,$E3,$E3,$E5,$E5,$E5,$E5,$E7,$E7,$E7,$E7
            db    $E9,$E9,$E9,$E9,$EB,$EB,$EB,$EB,$ED,$ED,$ED,$ED,$EF,$EF,$EF,$EF
            db    $E1,$E1,$E1,$E1,$E3,$E3,$E3,$E3,$E5,$E5,$E5,$E5,$E7,$E7,$E7,$E7
            db    $E9,$E9,$E9,$E9,$EB,$EB,$EB,$EB,$ED,$ED,$ED,$ED,$EF,$EF,$EF,$EF
            db    $F0,$F0,$F0,$F0,$F2,$F2,$F2,$F2,$F4,$F4,$F4,$F4,$F6,$F6,$F6,$F6
            db    $F8,$F8,$F8,$F8,$FA,$FA,$FA,$FA,$FC,$FC,$FC,$FC,$FE,$FE,$FE,$FE
            db    $F0,$F0,$F0,$F0,$F2,$F2,$F2,$F2,$F4,$F4,$F4,$F4,$F6,$F6,$F6,$F6
            db    $F8,$F8,$F8,$F8,$FA,$FA,$FA,$FA,$FC,$FC,$FC,$FC,$FE,$FE,$FE,$FE
            db    $80,$82,$84,$86,$88,$8A,$8C,$8E,$90,$92,$94,$96,$98,$9A,$9C,$9E
            db    $A0,$A2,$A4,$A6,$A8,$AA,$AC,$AE,$B0,$B2,$B4,$B6,$B8,$BA,$BC,$BE
            db    $C0,$C2,$C4,$C6,$C8,$CA,$CC,$CE,$D0,$D2,$D4,$D6,$D8,$DA,$DC,$DE
            db    $E0,$E2,$E4,$E6,$E8,$EA,$EC,$EE,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE
; Tile CIRAM address -> bit in its mask byte: 1 << ((col bit 1) * 4 + (row bit 0) * 2 + col bit 0)
T2BIT
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20,$01,$02,$10,$20
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80,$04,$08,$40,$80
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Attribute EOR value -> mask with $F in the nibble of every quadrant whose palette changed
AttrExpand
            dw    $0000,$000F,$000F,$000F,$00F0,$00FF,$00FF,$00FF
            dw    $00F0,$00FF,$00FF,$00FF,$00F0,$00FF,$00FF,$00FF
            dw    $0F00,$0F0F,$0F0F,$0F0F,$0FF0,$0FFF,$0FFF,$0FFF
            dw    $0FF0,$0FFF,$0FFF,$0FFF,$0FF0,$0FFF,$0FFF,$0FFF
            dw    $0F00,$0F0F,$0F0F,$0F0F,$0FF0,$0FFF,$0FFF,$0FFF
            dw    $0FF0,$0FFF,$0FFF,$0FFF,$0FF0,$0FFF,$0FFF,$0FFF
            dw    $0F00,$0F0F,$0F0F,$0F0F,$0FF0,$0FFF,$0FFF,$0FFF
            dw    $0FF0,$0FFF,$0FFF,$0FFF,$0FF0,$0FFF,$0FFF,$0FFF
            dw    $F000,$F00F,$F00F,$F00F,$F0F0,$F0FF,$F0FF,$F0FF
            dw    $F0F0,$F0FF,$F0FF,$F0FF,$F0F0,$F0FF,$F0FF,$F0FF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $F000,$F00F,$F00F,$F00F,$F0F0,$F0FF,$F0FF,$F0FF
            dw    $F0F0,$F0FF,$F0FF,$F0FF,$F0F0,$F0FF,$F0FF,$F0FF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $F000,$F00F,$F00F,$F00F,$F0F0,$F0FF,$F0FF,$F0FF
            dw    $F0F0,$F0FF,$F0FF,$F0FF,$F0F0,$F0FF,$F0FF,$F0FF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FF00,$FF0F,$FF0F,$FF0F,$FFF0,$FFFF,$FFFF,$FFFF
            dw    $FFF0,$FFFF,$FFFF,$FFFF,$FFF0,$FFFF,$FFFF,$FFFF
; Attribute index -> CIRAM address of the attribute byte
AttrAddrTbl
            dw    $03C0,$03C1,$03C2,$03C3,$03C4,$03C5,$03C6,$03C7
            dw    $03C8,$03C9,$03CA,$03CB,$03CC,$03CD,$03CE,$03CF
            dw    $03D0,$03D1,$03D2,$03D3,$03D4,$03D5,$03D6,$03D7
            dw    $03D8,$03D9,$03DA,$03DB,$03DC,$03DD,$03DE,$03DF
            dw    $03E0,$03E1,$03E2,$03E3,$03E4,$03E5,$03E6,$03E7
            dw    $03E8,$03E9,$03EA,$03EB,$03EC,$03ED,$03EE,$03EF
            dw    $03F0,$03F1,$03F2,$03F3,$03F4,$03F5,$03F6,$03F7
            dw    $03F8,$03F9,$03FA,$03FB,$03FC,$03FD,$03FE,$03FF
            dw    $07C0,$07C1,$07C2,$07C3,$07C4,$07C5,$07C6,$07C7
            dw    $07C8,$07C9,$07CA,$07CB,$07CC,$07CD,$07CE,$07CF
            dw    $07D0,$07D1,$07D2,$07D3,$07D4,$07D5,$07D6,$07D7
            dw    $07D8,$07D9,$07DA,$07DB,$07DC,$07DD,$07DE,$07DF
            dw    $07E0,$07E1,$07E2,$07E3,$07E4,$07E5,$07E6,$07E7
            dw    $07E8,$07E9,$07EA,$07EB,$07EC,$07ED,$07EE,$07EF
            dw    $07F0,$07F1,$07F2,$07F3,$07F4,$07F5,$07F6,$07F7
            dw    $07F8,$07F9,$07FA,$07FB,$07FC,$07FD,$07FE,$07FF
; Attribute index -> CIRAM address of the top-left tile of its 4x4 group
AttrBaseTbl
            dw    $0000,$0004,$0008,$000C,$0010,$0014,$0018,$001C
            dw    $0080,$0084,$0088,$008C,$0090,$0094,$0098,$009C
            dw    $0100,$0104,$0108,$010C,$0110,$0114,$0118,$011C
            dw    $0180,$0184,$0188,$018C,$0190,$0194,$0198,$019C
            dw    $0200,$0204,$0208,$020C,$0210,$0214,$0218,$021C
            dw    $0280,$0284,$0288,$028C,$0290,$0294,$0298,$029C
            dw    $0300,$0304,$0308,$030C,$0310,$0314,$0318,$031C
            dw    $0380,$0384,$0388,$038C,$0390,$0394,$0398,$039C
            dw    $0400,$0404,$0408,$040C,$0410,$0414,$0418,$041C
            dw    $0480,$0484,$0488,$048C,$0490,$0494,$0498,$049C
            dw    $0500,$0504,$0508,$050C,$0510,$0514,$0518,$051C
            dw    $0580,$0584,$0588,$058C,$0590,$0594,$0598,$059C
            dw    $0600,$0604,$0608,$060C,$0610,$0614,$0618,$061C
            dw    $0680,$0684,$0688,$068C,$0690,$0694,$0698,$069C
            dw    $0700,$0704,$0708,$070C,$0710,$0714,$0718,$071C
            dw    $0780,$0784,$0788,$078C,$0790,$0794,$0798,$079C

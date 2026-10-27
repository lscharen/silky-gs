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
; the current buffer: the byte itself (PPU_MEM) and, for a tile, its bit in the group mask, or for the
; attribute byte, the group's attribute-written flag (main bank).  The group's flag byte also has a
; queued bit: the first write to a group in a period puts it on at_list, so at_list holds every group
; that needs drawing exactly once.
; PPUFreezeNametableUpdates (interrupts off) only flips the write path, and the at_list append, to the
; other buffer by patching their operands.  PPUFlushQueuesAlt reads the previous buffer with interrupts on while the ROM fills the
; other one.  A buffer's data is valid exactly where its masks / flags say a byte was written; every
; other value is unchanged since the last render and already in TILE_SHADOW.  The flush clears the
; masks and flags it consumes, so a buffer is clean again before it becomes current.
;
; Buffers (buffer 1 = buffer 0 + $2000 in PPU_MEM, + $100 in the main bank):
;
;   PPU_MEM+NTM_SB0     data, indexed by CIRAM address
;   NTM_MASK0           16-bit tile masks, one word per group (index * 2; T2IDX = index * 2 + half)
;   NTM_FLAG0           flags per group (index * 2): NTM_QUEUED | NTM_ATTR
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

; Attribute indices queued for rendering.  One list per buffer, at the same offset as its masks and
; flags (buffer 1 = +$100): the ROM appends to the current buffer's list (ntmSiteL, moved with the other
; sites) while the render reads the previous one.  A group is queued at most once per period, so there
; are at most 128 entries (2 CIRAM pages x 64 attribute bytes).
AT_LIST_LEN        equ 128
NTM_QUEUED         equ $80                  ; NTM_FLAG bits: the group is on at_list
NTM_ATTR           equ $01                  ;                its attribute byte was written
at_count           dw 0                     ; Bytes in the current buffer's list (the ROM appends here)
at_prev_count      dw 0                     ; Bytes in the previous buffer's list (the render draws these)
at_list            ds {AT_LIST_LEN*4}

ntmSel      dw    0                         ; $00 / $20: high-byte offset of the PPU_MEM buffer being written
ntmY        dw    0
ntmFlushEnd dw    0                         ; PPUFlushQueuesAlt: end of the list being drawn

; The masks and flags of both buffers (NTM_MASK0 / 1, NTM_FLAG0 / 1; buffer 1 = +$100) and the
; generated tables (T2IDX, T2BIT, AttrExpand, AttrAddrTbl, AttrBaseTbl) are in core/Data.s, page-aligned


; ---------------------------------------------------------------------------
; ntmWriteTail
; ---------------------------------------------------------------------------
; Jumped to from PPUDATA_WRITE once a *changed* nametable byte has been stored in PPU_CIRAM.  A = value
; (8-bit), X = CIRAM address (16-bit X/Y), DBR = K, PPUDATA_WRITE's saved P / B / A / X on the stack.
; The *Site* operands address the current buffer and are moved by PPUFreezeNametableUpdates, so this
; routine uses global labels only.  Y belongs to the ROM and is preserved.
            mx    %10
ntmWriteTail ENT
            phb
            phk
            plb

ntmSiteD    stal  PPU_MEM+NTM_SB0,x           ; The byte, for the render that reads this buffer
            sty   ntmY
            lda   #0
            xba                               ; B = 0 for the transfers to Y
            lda   T2IDX,x
            tay                               ; Y = group index * 2 (+1 for the HI half of a tile mask)
            lda   T2BIT,x
            beq   ntmAttr                     ; Attribute bytes have no tile bit
ntmSiteM0   ora   NTM_MASK0,y                 ; Tile: add its bit to the group's mask
ntmSiteM1   sta   NTM_MASK0,y
            tya
            and   #$FE
            tay                               ; Y = group index * 2
ntmSiteF0   lda   NTM_FLAG0,y
            bmi   ntmDone                     ; Already on at_list this period: nothing to store
            ora   #NTM_QUEUED
ntmSiteF1   sta   NTM_FLAG0,y
            bra   ntmAppend

ntmAttr
ntmSiteF2   lda   NTM_FLAG0,y
            bmi   ntmAttrQ
            ora   #NTM_QUEUED+NTM_ATTR
ntmSiteF3   sta   NTM_FLAG0,y

ntmAppend   rep   #$20                        ; First write to the group: append its index to at_list
            tya
            lsr
            ldx   at_count
ntmSiteL    sta   at_list,x
            inx
            inx
            stx   at_count
ntmDone     ldy   ntmY
ntmExit
;            sep   #$30
;            plx
;            pla
;            plb
;            plp
            plb
            rtl

            mx    %10                         ; (entered from ntmAttr: 8-bit A, 16-bit X/Y)
ntmAttrQ    ora   #NTM_ATTR                   ; Already on at_list: just flag the attribute byte
ntmSiteF4   sta   NTM_FLAG0,y
            bra   ntmDone

; ---------------------------------------------------------------------------
; PPUFreezeNametableUpdates
; ---------------------------------------------------------------------------
; Called by NES_RenderFrame with interrupts off.  The current buffer and its at_list become the ones the
; render draws, and the write path moves to the other buffer, whose list starts empty: the PPU_MEM site
; moves by $2000 and the main bank sites (masks, flags, list) by one page, in the high byte of each operand.
        mx  %00
PPUFreezeNametableUpdates
        lda  at_count
        sta  at_prev_count
        stz  at_count

        sep  #$20
        lda  ntmSel
        eor  #$20
        sta  ntmSel
        beq  :down

        lda  ntmSiteD+2                       ; Buffer 0 -> buffer 1
        clc
        adc  #$20
        sta  ntmSiteD+2
        inc  ntmSiteM0+2
        inc  ntmSiteM1+2
        inc  ntmSiteF0+2
        inc  ntmSiteF1+2
        inc  ntmSiteF2+2
        inc  ntmSiteF3+2
        inc  ntmSiteF4+2
        inc  ntmSiteL+2
        rep  #$20
        rts

        mx   %10                              ; (reached from the beq above: 8-bit A)
:down   lda  ntmSiteD+2                       ; Buffer 1 -> buffer 0
        sec
        sbc  #$20
        sta  ntmSiteD+2
        dec  ntmSiteM0+2
        dec  ntmSiteM1+2
        dec  ntmSiteF0+2
        dec  ntmSiteF1+2
        dec  ntmSiteF2+2
        dec  ntmSiteF3+2
        dec  ntmSiteF4+2
        dec  ntmSiteL+2
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

        lda   NtmPrev                         ; The buffer's list is at the same offset as its masks / flags
        tay
        clc
        adc   at_prev_count
        sta   ntmFlushEnd
:entry  cpy   ntmFlushEnd
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

; 1. Mask and flags, cleared for the buffer's next period.  Every group is on at_list once, and has a
;    non-zero mask or its attribute flag.

        lda   NTM_FLAG0,y                     ; (the odd byte is never written: high byte 0)
        bit   #NTM_ATTR
        bne   :attr_written
        lda   NTM_MASK0,y                     ; Tiles only: palette unchanged
        sta   NtmTMask
        sta   NtmMask
        lda   #0
        sta   NTM_MASK0,y
        sta   NTM_FLAG0,y
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
        DO    ENABLE_DIRTY_RENDERING
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
        DO    ENABLE_DIRTY_RENDERING
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
        DO    ENABLE_DIRTY_RENDERING
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
        DO    ENABLE_DIRTY_RENDERING
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
        lda    ntmSel                         ; Write path back on buffer 0
        and    #$00FF
        beq    :sel0
        jsr    PPUFreezeNametableUpdates
:sel0   stz    at_count                       ; Both lists empty
        stz    at_prev_count
        ldx    #$03FE                          ; Clean both buffers' masks and flags
        lda    #0
:clr    sta    NTM_MASK0,x
        dex
        dex
        bpl    :clr
        rts


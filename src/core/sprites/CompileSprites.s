; Compile an 8x8 bitmap into executable code into the SpriteBank
;
; Y = address in the compile bank
; A = low address of bitmap in tiledata bank
;
; Algorithm is simple O(n^2), but there are only 16 words
;   Load first word
;   Emit a load instruction
;   Emit a store instruction
;   Mark word as done
;   Scan for any duplicate words and mark complete
;   Continue until no words are left
;
; This routine differs from the CompileTile routine in a few ways.  First, duplicate
; words that have a mask are cached to save the lookup time, but can't be used
; immediately.  Second, the compilation needs to produce vertical and horizontally
; flipped versions of the sprite, which take up more space.  So the compiled sprite
; actually has an 8-byte header with the offsets for each variant.
; Emitted code is:
;
;  ldy #data
;  lda $0000,x
;  and #mask
;  ora [ActivePtr],y
;  sta $0000,x
;
;  ldy #data
;  lda [ActivePtr],y
;  sta $0000,x
;
;  ...

BOTH_ADDR_OFFSET equ 13
VERT_ADDR_OFFSET equ 21
HORZ_ADDR_OFFSET equ 24
PREAMBLE_SIZE    equ 26

        mx    %00
CompileSprite
:base    equ tmp9                 ; start of the sprite
:src     equ tmp10

; Sprite are called with OAM Byte 2 in the accumulator and X set to the sprite index. The
; direct page location sprTmp1 holds the SHR address.  The compiled sprite has a preamble
; that dispatches to the correct compiled tile based on the value in the accumulator
;
; This is the template code that each compiled sprite starts with
;
;            ldx   sprTmp1         ; 2 bytes
;            and   #$00C0          ; 3 bytes
;            beq   normal          ; 2 bytes
;            cmp   #$00C0          ; 3 bytes
;            bne   *+5             ; 2 bytes
;            jmp   both            ; 3 bytes
;            bit   #$0080          ; 3 bytes
;            beq   *+5             ; 2 bytes
;            jmp   vertical        ; 3 bytes
;            jmp   horizontal      ; 3 bytes = 26 bytes
; normal     ...
; horizontal ...
;            ...
;            jml   draw_rtn2

        sty  :base               ; base address of the sprite code in the CompileSprite bank
        sta  :src                ; address of the source tile data in the tiledata bank (updated)

; Gerenate the preamble

        jsr  CompileSpritePreamble

; Build each sprite and insert it's address into the preamble code.  The normal sprite
; (no horizontal or vertical flip) doesn't need any patching because it's always located
; immediately after the preable

        jsr  CompileSpriteNormal

; Build the horizontally flipped version

        phy
        lda  :base
        clc
        adc  #HORZ_ADDR_OFFSET
        tay
        lda  1,s
        sta  [SpriteBank0],y
        ply
        jsr  CompileSpriteHorz

; Build the vertically flipped version

        phy
        lda  :base
        clc
        adc  #VERT_ADDR_OFFSET
        tay
        lda  1,s
        sta  [SpriteBank0],y
        ply
        jsr  CompileSpriteVert

; Build the vertically and horizontally flipped version

        phy
        lda  :base
        clc
        adc  #BOTH_ADDR_OFFSET
        tay
        lda  1,s
        sta  [SpriteBank0],y
        ply
        jsr  CompileSpriteBoth

; Return with the new address in the Y-register

        rts

        mx    %00
CompileSpritePreamble

        lda  #$A6+{256*sprTmp1}  ; LDX dp
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$0029              ; AND #$00C0
        sta  [SpriteBank0],y
        iny
        lda  #$00C0
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$13F0              ; BEQ normal
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$00C9              ; CMP #$00C0
        sta  [SpriteBank0],y
        iny
        lda  #$00C0
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$03D0              ; BNE *+5
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$004C              ; JMP both
        sta  [SpriteBank0],y
        iny
        iny
        iny

        lda  #$0089              ; BIT #$0080
        sta  [SpriteBank0],y
        iny
        lda  #$0080
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$03F0              ; BEQ *+5
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$004C              ; JMP horizontal
        sta  [SpriteBank0],y
        iny
        iny
        iny

        lda  #$004C              ; JMP vertical
        sta  [SpriteBank0],y
        iny
        iny
        iny

        rts

        mx    %00
CompileSpriteNormal
:flags  equ tmp8

        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated

; In this loop, Y and X always point to the compile bank address and data index, respectively

        ldx  #0
:loop
        lda  bit_mask,x          ; Get the flag for the current word
        and  :flags              ; Has this word already been generated?
        beq  :skip

        lda  word_addr,x
        jsr  emit_op

:skip
        inx
        inx                      ; Advance to the next word
        cpx  #32
        bcc  :loop

:exit
        jmp  _EmitReturn

        mx    %00
CompileSpriteHorz
:flags  equ tmp8

        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated

; In this loop, Y and X always point to the compile bank address and data index, respectively

        ldx  #64                 ; Move to the horizontal flipped data
:loop
        lda  bit_mask-64,x       ; Get the flag for the current word
        and  :flags              ; Has this word already been generated?
        beq  :skip

        lda  word_addr-64,x
        jsr  emit_op

:skip
        inx
        inx
        cpx  #96
        bcc  :loop

:exit
        jmp  _EmitReturn

        mx    %00
CompileSpriteVert
:flags  equ tmp8

        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated

; In this loop, Y and X always point to the compile bank address and data index, respectively

        ldx  #0
:loop
        lda  bit_mask,x          ; Get the flag for the current word
        and  :flags              ; Has this word already been generated?
        beq  :skip

        lda  word_addr_flip,x
        jsr  emit_op_flip

:skip
        inx
        inx                      ; Advance to the next word
        cpx  #32
        bcc  :loop

:exit
        jmp  _EmitReturn

        mx    %00
CompileSpriteBoth
:flags  equ tmp8

        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated

; In this loop, Y and X always point to the compile bank address and data index, respectively

        ldx  #64
:loop
        lda  bit_mask-64,x       ; Get the flag for the current word
        and  :flags              ; Has this word already been generated?
        beq  :skip

        lda  word_addr_flip-64,x
        jsr  emit_op_flip

:skip
        inx
        inx                      ; Advance to the next word
        cpx  #96
        bcc  :loop

:exit
        jmp  _EmitReturn

        mx    %00
_EmitReturn
        lda  #$005C           ; return instruction jumps back to draw_rtn
        sta  [SpriteBank0],y
        iny
        lda  #draw_rtn2
        sta  [SpriteBank0],y
        iny
        iny
        lda  #^draw_rtn2
        sta  [SpriteBank0],y
        iny

        rts

        mx    %00
emit_op
:xsave  equ tmp11
:src    equ tmp10

        sta  tmp7

        stx  :xsave
        txa
        clc
        adc  :src
        tax

        ldal tiledata+32,x          ; Check if the mask is zero of not
        beq  :no_mask
        cmp  #$FFFF
        beq  :no_data

        lda  #$00A0                 ; ldy #imm
        sta  [SpriteBank0],y
        iny
        ldal tiledata,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$00BD                 ; lda abs,x
        sta  [SpriteBank0],y
        iny
        lda  tmp7
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$0029                 ; and #imm
        sta  [SpriteBank0],y
        iny
        ldal tiledata+32,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$17+{ActivePtr*256}   ; ora [ActivePtr],y
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$009D                 ; sta abs,x
        sta  [SpriteBank0],y
        iny
        lda  tmp7
        sta  [SpriteBank0],y
        iny
        iny
:no_data
        ldx  :xsave
        rts

:no_mask
        lda  #$00A0                 ; ldy #imm
        sta  [SpriteBank0],y
        iny
        ldal tiledata,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$B7+{ActivePtr*256}   ; lda [ActivePtr],y
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$009D                 ; sta abs,x
        sta  [SpriteBank0],y
        iny
        lda  tmp7
        sta  [SpriteBank0],y
        iny
        iny
        ldx  :xsave
        rts

        mx    %00
emit_op_flip
:xsave  equ tmp11
:src    equ tmp10

        sta  tmp7

        stx  :xsave
        txa
        clc
        adc  :src
        tax

        ldal tiledata+32,x          ; Check if the mask is zero or not
        beq  :no_mask_flip
        cmp  #$FFFF
        beq  :no_data_flip

        lda  #$00A0                 ; ldy #imm
        sta  [SpriteBank0],y
        iny
        ldal tiledata,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$00BD                 ; lda abs,x
        sta  [SpriteBank0],y
        iny
        lda  tmp7
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$0029                 ; and #imm
        sta  [SpriteBank0],y
        iny
        ldal tiledata+32,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$17+{ActivePtr*256}   ; ora [ActivePtr],y
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$009D                 ; sta abs,x
        sta  [SpriteBank0],y
        iny
        lda  tmp7
        sta  [SpriteBank0],y
        iny
        iny
:no_data_flip
        ldx  :xsave
        rts

:no_mask_flip
        lda  #$00A0                 ; ldy #imm
        sta  [SpriteBank0],y
        iny
        ldal tiledata,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$B7+{ActivePtr*256}   ; lda [ActivePtr],y
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$009D                 ; sta abs,x
        sta  [SpriteBank0],y
        iny
        lda  tmp7
        sta  [SpriteBank0],y
        iny
        iny
        ldx  :xsave
        rts

; data tables for generating code
word_addr
        dw {0*SHR_LINE_WIDTH}+0
        dw {0*SHR_LINE_WIDTH}+2
        dw {1*SHR_LINE_WIDTH}+0
        dw {1*SHR_LINE_WIDTH}+2
        dw {2*SHR_LINE_WIDTH}+0
        dw {2*SHR_LINE_WIDTH}+2
        dw {3*SHR_LINE_WIDTH}+0
        dw {3*SHR_LINE_WIDTH}+2
        dw {4*SHR_LINE_WIDTH}+0
        dw {4*SHR_LINE_WIDTH}+2
        dw {5*SHR_LINE_WIDTH}+0
        dw {5*SHR_LINE_WIDTH}+2
        dw {6*SHR_LINE_WIDTH}+0
        dw {6*SHR_LINE_WIDTH}+2
        dw {7*SHR_LINE_WIDTH}+0
        dw {7*SHR_LINE_WIDTH}+2

word_addr_flip
        dw {7*SHR_LINE_WIDTH}+0
        dw {7*SHR_LINE_WIDTH}+2
        dw {6*SHR_LINE_WIDTH}+0
        dw {6*SHR_LINE_WIDTH}+2
        dw {5*SHR_LINE_WIDTH}+0
        dw {5*SHR_LINE_WIDTH}+2
        dw {4*SHR_LINE_WIDTH}+0
        dw {4*SHR_LINE_WIDTH}+2
        dw {3*SHR_LINE_WIDTH}+0
        dw {3*SHR_LINE_WIDTH}+2
        dw {2*SHR_LINE_WIDTH}+0
        dw {2*SHR_LINE_WIDTH}+2
        dw {1*SHR_LINE_WIDTH}+0
        dw {1*SHR_LINE_WIDTH}+2
        dw {0*SHR_LINE_WIDTH}+0
        dw {0*SHR_LINE_WIDTH}+2

bit_mask
        dw $8000,$4000,$2000,$1000,$0800,$0400,$0200,$0100,$0080,$0040,$0020,$0010,$0008,$0004,$0002,$0001
; ---------------------------------------------------------------------------------------------------
; Compiled sprite cache
;
; The sprite compile bank is not big enough to hold a compiled version of every sprite tile, so the
; tiles are compiled on demand into a fixed number of slots (see SPR_* in Defs.s):
;
; * Slots are not packed.  A compiled sprite is at most 938 bytes (26 byte preamble + 4 variants of 16
;   words * 14 bytes + a 4 byte return), so each slot is SPR_SLOT_SIZE = 1KB and slot 0 is left unused
;   because address $0000 is the "not compiled" value in SPR_COMP_TBL.
; * SPR_COMP_TBL maps a tile index (tile | pattern table << 8, times 2) to its slot address.
; * Tiles with a slot are on a circular doubly linked list ordered by use.  The list is stored as
;   structure of arrays (SPR_NEXT / SPR_PREV) with a sentinel node, so the move-to-front on a hit and
;   taking the least recently used tile on a miss are both O(1).
; * The slots that no tile owns are on a stack (SPR_FREE).
; * drawSprites draws a sprite that misses from its bitmap and queues it (SPR_PEND, at most
;   SPR_COMPILE_PER_RENDER entries).  SprCacheService compiles the queue when drawSprites is done.
; * CHR-RAM writes invalidate the compiled sprite through the existing dirty flags (SprInvalidate,
;   called by CheckSprTileDirty).
; ---------------------------------------------------------------------------------------------------

; Start with an empty cache where every slot is free.  Called once from PPUStartUp.
        mx    %00
SprCacheInit
        lda   #SPR_SENT                  ; the empty list is the sentinel pointing at itself
        stal  PPU_MEM+SPR_HEAD
        stal  PPU_MEM+SPR_TAIL

        lda   #0                         ; nothing is compiled
        ldx   #1022
:clear
        stal  PPU_MEM+SPR_COMP_TBL,x
        dex
        dex
        bpl   :clear

        ldx   #0                         ; push the slot addresses $0400, $0800, ... $FC00
        lda   #SPR_SLOT_SIZE
:fill
        stal  PPU_MEM+SPR_FREE,x
        inx
        inx
        clc
        adc   #SPR_SLOT_SIZE
        cpx   #2*SPR_SLOTS
        bcc   :fill

        lda   #2*SPR_SLOTS
        stal  PPU_MEM+SPR_FREE_TOP
        lda   #0
        stal  PPU_MEM+SPR_PEND_CNT
        rts

; A compiled sprite was just dispatched to; make it the most recently used.
;
; X = tile index * 2.  A/X/Y trashed.
        mx    %00
SprTouch
        txa
        cmpl  PPU_MEM+SPR_HEAD           ; Already the most recently used?  Then there is nothing to do
        beq   :done
        SPR_UNLINK
        SPR_INSERT_HEAD
:done
        rts

; Make sure a sprite tile has a compiled version.  If a slot is free, it is used.  If not, the least
; recently used tile is evicted and its slot is taken over.  The new tile becomes the most recently used.
; The tile data in the tiledata bank must be valid.
;
; X = tile index * 2.  All registers trashed.
        mx    %00
SprCompileTile
        ldal  PPU_MEM+SPR_COMP_TBL,x
        bne   :done                      ; already compiled (a tile can be queued more than once)

        phx                              ; save the tile index * 2
        ldal  PPU_MEM+SPR_FREE_TOP
        beq   :evict
        sec
        sbc   #2
        stal  PPU_MEM+SPR_FREE_TOP       ; pop a free slot
        tax
        ldal  PPU_MEM+SPR_FREE,x
        bra   :have_slot

:evict
        ldal  PPU_MEM+SPR_TAIL           ; the least recently used tile owns a slot to take over
        tax
        ldal  PPU_MEM+SPR_COMP_TBL,x
        pha                              ; the slot
        lda   #0
        stal  PPU_MEM+SPR_COMP_TBL,x     ; it no longer has a compiled version
        SPR_UNLINK
        pla

:have_slot
        pha                              ; slot at 1,s and tile index * 2 at 3,s
        tay                              ; Y = address in the compile bank
        lda   3,s
        asl
        asl
        asl
        asl
        asl
        asl                              ; A = tile index * 128 = tiledata source address
        jsr   CompileSprite              ; trashes tmp7 - tmp11 (SprCacheService saves them)

        pla                              ; A = slot
        plx                              ; X = tile index * 2
        stal  PPU_MEM+SPR_COMP_TBL,x
        SPR_INSERT_HEAD
:done
        rts

; A tile's pixels changed (CHR-RAM write), so its compiled sprite is stale.  If it has one, drop it and
; return the slot to the free stack so it is reused before any live tile is evicted.
;
; X = tile index * 2.  All registers trashed.
        mx    %00
SprInvalidate
        ldal  PPU_MEM+SPR_COMP_TBL,x
        beq   :done                      ; never compiled, or already evicted
        pha                              ; the slot
        lda   #0
        stal  PPU_MEM+SPR_COMP_TBL,x
        SPR_UNLINK

        ldal  PPU_MEM+SPR_FREE_TOP
        tax
        pla
        stal  PPU_MEM+SPR_FREE,x         ; push the slot
        inx
        inx
        txa
        stal  PPU_MEM+SPR_FREE_TOP
:done
        rts

; Compile the tiles that missed during drawSprites (at most SPR_COMPILE_PER_RENDER of them).  The
; tiles are drawn from their bitmaps until then, so the cost is spread over the next renders.  It is
; run at the end of drawSprites, in whatever data bank and with whatever direct page temps the
; caller has, so both are preserved.
        mx    %00
SprCacheService
        ldal  PPU_MEM+SPR_PEND_CNT
        beq   :exit

        phb
        phk
        plb                              ; CompileSprite's data tables are addressed with the program bank
        pei   tmp7
        pei   tmp8
        pei   tmp9
        pei   tmp10
        pei   tmp11

        ldx   #0                         ; X = offset in the pending list
:next
        phx
        ldal  PPU_MEM+SPR_PEND,x
        tax
        jsr   SprCompileTile
        plx
        inx
        inx
        txa
        cmpl  PPU_MEM+SPR_PEND_CNT
        bcc   :next

        lda   #0
        stal  PPU_MEM+SPR_PEND_CNT

        pla
        sta   tmp11
        pla
        sta   tmp10
        pla
        sta   tmp9
        pla
        sta   tmp8
        pla
        sta   tmp7
        plb
:exit
        rts

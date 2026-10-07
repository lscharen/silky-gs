; Compile an 8x8 bitmap into executable code in the SpriteBank
;
; Y = address in the compile bank
; A = low address of bitmap in tiledata bank
; X = 0 for the sprite as it is, non-zero for the vertically flipped sprite
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
; immediately.  Second, the compilation produces a horizontally flipped version of the
; sprite as well, which takes up more space.  The vertical flip is part of the cache key
; (see SPR_* in Defs.s), so one compiled sprite is for one vertical orientation only: either
; the normal and horizontally flipped code, or the vertically flipped and both-ways flipped
; code.  The compiled sprite starts with a small preamble that selects between the two.
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

HORZ_ADDR_OFFSET equ 8                 ; offset of the horizontal variant's address in the preamble
PREAMBLE_SIZE    equ 10

        mx    %00
CompileSprite
:base    equ tmp9                 ; start of the sprite
:src     equ tmp10

; Sprites are called with OAM Byte 2 in the accumulator and the direct page location sprTmp1 holds
; the SHR address.  The compiled sprite has a preamble that dispatches on the horizontal flip bit
; in the accumulator.  This is the template code that each compiled sprite starts with
;
;            ldx   sprTmp1         ; 2 bytes
;            bit   #$0040          ; 3 bytes
;            beq   normal          ; 2 bytes
;            jmp   horizontal      ; 3 bytes = 10 bytes
; normal     ...
; horizontal ...
;            ...
;            jml   draw_rtn2

        sty  :base               ; base address of the sprite code in the CompileSprite bank
        sta  :src                ; address of the source tile data in the tiledata bank (updated)
        phx                      ; vertical flip flag: 0 or 2, which is also the offset in the tables of variants below

; Gerenate the preamble

        jsr  CompileSpritePreamble

; Build the first variant, which doesn't need any patching because it's always located
; immediately after the preable.  (X is still the flag.)

        jsr  (:first,x)

; Insert the address of the second variant into the preamble

        phy
        lda  :base
        clc
        adc  #HORZ_ADDR_OFFSET
        tay
        lda  1,s
        sta  [SpriteBank0],y
        ply

; Build the horizontally flipped version of the first variant and return with the new address in the Y-register

        plx
        jmp  (:second,x)

:first  dw   CompileSpriteNormal,CompileSpriteVert
:second dw   CompileSpriteHorz,CompileSpriteBoth

        mx    %00
CompileSpritePreamble

; The template code as words (little endian): A6 sprTmp1 | 89 40 | 00 F0 | 03 4C | horizontal address

        lda  #$A6+{256*sprTmp1}  ; LDX dp
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$4089              ; BIT #$0040 (the high byte of the operand is in the next word)
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$F000              ; ... / BEQ *+5
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$4C03              ; ... / JMP horizontal (the address is filled in once it is known)
        sta  [SpriteBank0],y
        iny
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
; sprites are compiled on demand into a fixed number of slots (see SPR_* in Defs.s):
;
; * A compiled sprite is for one tile and one vertical orientation, and has the normal and the horizontally
;   flipped code (a preamble picks one by the horizontal flip bit).  Most games flip horizontally all the
;   time, but a vertical flip is rare, so the vertical flip is part of the cache key.
; * Slots are not packed.  A compiled sprite is at most 466 bytes (10 byte preamble + 2 variants of 16
;   words * 14 bytes + a 4 byte return), so each slot is SPR_SLOT_SIZE = 512 bytes and slot 0 is left unused
;   because address $0000 is the "not compiled" value in SPR_COMP_TBL.
; * SPR_COMP_TBL maps a key (tile | pattern table << 8, vertical flip) to its slot address.  Keys are
;   handled as "key offsets": the key doubled again, as an index in a table of words.
; * Keys with a slot are on a circular doubly linked list, in the order they were compiled: a new key goes to the
;   head and the key at the tail, the oldest, is the one replaced when there are no free slots.  The list is
;   stored as structure of arrays (SPR_NEXT / SPR_PREV) with a sentinel node, so all of this is O(1), including
;   taking out a key from the middle when a CHR-RAM write invalidates it.  A hit does nothing: it takes 127 new
;   compiles (SPR_SLOTS) to replace a compiled sprite, which makes this a FIFO, not an LRU, and a lot cheaper.
; * The slots that no key owns are on a stack (SPR_FREE).
; * drawSprites draws a sprite that misses from its bitmap and queues it (SPR_PEND, at most
;   SPR_COMPILE_PER_RENDER entries).  SprCacheService compiles the queue when drawSprites is done.
; * CHR-RAM writes invalidate the compiled sprites of the tile (both vertical orientations) through the
;   existing dirty flags (SprInvalidate, called by CheckSprTileDirty).
; ---------------------------------------------------------------------------------------------------

; Start with an empty cache where every slot is free.  Called once from PPUStartUp.
        mx    %00
SprCacheInit
        lda   #SPR_SENT                  ; the empty list is the sentinel pointing at itself
        stal  PPU_MEM+SPR_HEAD
        stal  PPU_MEM+SPR_TAIL

        lda   #0                         ; nothing is compiled
        ldx   #2046
:clear
        stal  PPU_MEM+SPR_COMP_TBL,x
        dex
        dex
        bpl   :clear

        ldx   #2*{SPR_SLOTS-1}           ; push the slot addresses $FE00 ... $0400, $0200 (at most 127 slots)
        lda   #SPR_SLOTS*SPR_SLOT_SIZE
        sec                              ; (stays set: A never goes below zero)
:fill
        stal  PPU_MEM+SPR_FREE,x
        sbc   #SPR_SLOT_SIZE
        dex
        dex
        bpl   :fill

        lda   #2*SPR_SLOTS
        stal  PPU_MEM+SPR_FREE_TOP
        lda   #0
        stal  PPU_MEM+SPR_PEND_CNT
        rts

; Make sure a sprite has a compiled version.  If a slot is free, it is used.  If not, the oldest key
; is evicted and its slot is taken over.  The new key becomes the newest.
; The tile data in the tiledata bank must be valid.
;
; X = key offset.  All registers trashed.
        mx    %00
SprCompileTile
        ldal  PPU_MEM+SPR_COMP_TBL,x
        beq   :compile
        rts                              ; already compiled (a tile can be queued more than once)

:compile
        phx                              ; save the key offset
        ldal  PPU_MEM+SPR_FREE_TOP
        beq   :evict
        dec
        dec
        stal  PPU_MEM+SPR_FREE_TOP       ; pop a free slot
        tax
        ldal  PPU_MEM+SPR_FREE,x
        bra   :have_slot

:evict
        ldal  PPU_MEM+SPR_TAIL           ; the oldest key owns a slot to take over
        tax
        ldal  PPU_MEM+SPR_COMP_TBL,x
        pha                              ; the slot
        lda   #0
        stal  PPU_MEM+SPR_COMP_TBL,x     ; it no longer has a compiled version
        SPR_UNLINK
        pla

:have_slot
        pha                              ; slot at 1,s and key offset at 3,s
        tay                              ; Y = address in the compile bank
        lda   3,s
        and   #$0002
        tax                              ; X = 2 for a vertically flipped sprite, else 0
        lda   3,s
        and   #$07FC                     ; (pattern table << 8 | tile) * 4
        asl
        asl
        asl
        asl
        asl                              ; A = (pattern table << 8 | tile) * 128 = tiledata source address
        jsr   CompileSprite              ; trashes tmp7 - tmp11 (SprCacheService saves them)

        pla                              ; A = slot
        plx                              ; X = key offset
        stal  PPU_MEM+SPR_COMP_TBL,x
        SPR_INSERT_HEAD
        rts

; A tile's pixels changed (CHR-RAM write), so its compiled sprites are stale.  If a key has one, drop it and
; return the slot to the free stack so it is reused before any live key is evicted.  This is for one key;
; the caller does both vertical orientations of the tile.
;
; X = key offset.  All registers trashed.
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
        inc
        inc
        stal  PPU_MEM+SPR_FREE_TOP
        pla
        stal  PPU_MEM+SPR_FREE,x         ; push the slot
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

        tax                              ; X = the end of the pending list; compile the last key first
:next
        dex
        dex
        phx
        ldal  PPU_MEM+SPR_PEND,x
        tax
        jsr   SprCompileTile
        plx
        bne   :next                      ; (not the first entry yet)

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

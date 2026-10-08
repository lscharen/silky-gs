; Compile an 8x8 bitmap into executable code in the SpriteBank
;
; Y = address in the compile bank
; A = low address of bitmap in tiledata bank
; X = 0 for the sprite as it is, 2 for the vertically flipped sprite
;
; Returns the address of the horizontally flipped variant in A, and the end of the code in Y
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
; code.  Each of the two has its own entry in SPR_COMP_TBL, so there is no dispatch code.
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

        mx    %00
CompileSprite
:base    equ tmp9                 ; start of the sprite
:src     equ tmp10

; Sprites are called with X = the SHR address (sprTmp1) and the data bank set to the shadow
; screen.  Each variant ends with a JML back to draw_rtn2.

        sty  :base               ; base address of the sprite code in the CompileSprite bank
        sta  :src                ; address of the source tile data in the tiledata bank (updated)

        phx                      ; vertical flip flag: 0 or 2, the offset in the tables of variants below
        jsr  (:first,x)          ; the sprite as it is (or flipped vertically) at the start of the slot
        plx
        phy                      ; the horizontally flipped variant follows it
        jsr  (:second,x)
        pla                      ; A = the address of the horizontally flipped variant
        rts

:first  dw   CompileSpriteNormal,CompileSpriteVert
:second dw   CompileSpriteHorz,CompileSpriteBoth

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
;   flipped code.  Most games flip horizontally all the time, but a vertical flip is rare, so the vertical
;   flip is part of the cache key.  Both variants have an entry in SPR_COMP_TBL, so a hit jumps straight
;   into the code of the variant it needs.
; * Slots are not packed.  A compiled sprite is at most 456 bytes (2 variants of 16 words * 14 bytes + a 4
;   byte return), so each slot is SPR_SLOT_SIZE = 512 bytes and slot 0 is left unused because address $0000
;   is the "not compiled" value in SPR_COMP_TBL.
; * The slots are used in turn (SPR_CURSOR), so the one that is replaced is the one that was filled the
;   longest time ago: a FIFO.  A hit does nothing; it takes SPR_SLOTS new compiles to replace a sprite.
;   SPR_OWNER has the key offset of each slot's sprite, to clear its SPR_COMP_TBL entries when it is replaced.
; * drawSprites draws a sprite that misses from its bitmap and queues it (SPR_PEND, at most
;   SPR_COMPILE_PER_RENDER entries).  SprCacheService compiles the queue when drawSprites is done.
; * CHR-RAM: the first write to a tile drops its compiled sprites (both vertical orientations) and sets its
;   sprite dirty flag (PPUDATA_WRITE), and a dirty tile is never compiled (SprCompileTile), so a hit needs no
;   check.  The bitmap draws reconvert a dirty tile first (sprChrCheck in ppu.s).
; ---------------------------------------------------------------------------------------------------

; Start with an empty cache.  Called once from PPUStartUp.
        mx    %00
SprCacheInit
        lda   #0                         ; nothing is compiled
        ldx   #4094
:clear
        stal  PPU_MEM+SPR_COMP_TBL,x
        dex
        dex
        bpl   :clear

        lda   #$FFFF                     ; no slot has an owner
        ldx   #254
:owners
        stal  PPU_MEM+SPR_OWNER,x
        dex
        dex
        bpl   :owners

        lda   #SPR_SLOT_SIZE             ; start with the first slot
        stal  PPU_MEM+SPR_CURSOR
        lda   #0
        stal  PPU_MEM+SPR_PEND_CNT
        rts

; Make sure a sprite has a compiled version, in the next slot of the ring.  If a sprite owns that slot,
; it is evicted.  The tile data in the tiledata bank must be valid.
;
; CHR-RAM: a tile whose sprite dirty flag is set never keeps a compiled sprite, because a compiled-sprite
; hit does not check the flag (PPUDATA_WRITE drops the compiled sprites on the first write to a tile).
; The tile may be rewritten after the miss that queued it converted it, so the flag is tested before
; compiling, and again, with interrupts off, before the result is stored.
;
; X = key offset (horizontal flip bit clear).  All registers trashed.
        mx    %00
SprCompileTile
        ldal  PPU_MEM+SPR_COMP_TBL,x
        beq   :compile
        rts                              ; already compiled (a key can be queued more than once)

:compile
        DO    HAS_CHR_RAM
        jsr   :chr_dirty
        beq   *+3
        rts                              ; rewritten since it was converted: a later miss converts and
                                         ; queues it again
        FIN
        phx                              ; save the key offset
        ldal  PPU_MEM+SPR_CURSOR         ; take the next slot and move the cursor on
        pha                              ; slot at 1,s and key offset at 3,s
        cmp   #SPR_SLOTS*SPR_SLOT_SIZE   ; the last slot?  Then the first one is next
        bcc   :advance
        lda   #0
:advance
        clc
        adc   #SPR_SLOT_SIZE
        stal  PPU_MEM+SPR_CURSOR

        lda   1,s                        ; make the new key the owner of the slot
        xba
        and   #$00FF
        tax                              ; X = slot address >> 8
        ldal  PPU_MEM+SPR_OWNER,x
        tay                              ; Y = the previous owner
        lda   3,s
        stal  PPU_MEM+SPR_OWNER,x
        tya
        bmi   :have_slot                 ; the slot was free
        tax
        lda   #0                         ; evict the previous owner: both of its variants
        stal  PPU_MEM+SPR_COMP_TBL,x
        stal  PPU_MEM+SPR_COMP_TBL+2,x

:have_slot
        lda   1,s
        tay                              ; Y = address in the compile bank
        lda   3,s
        and   #$0004
        lsr
        tax                              ; X = 2 for a vertically flipped sprite, else 0
        lda   3,s
        and   #$0FF8                     ; (pattern table << 8 | tile) * 8
        asl
        asl
        asl
        asl                              ; A = (pattern table << 8 | tile) * 128 = tiledata source address
        jsr   CompileSprite              ; A = the horizontally flipped variant (trashes tmp7 - tmp11, which
                                         ; SprCacheService saves)
        tay
        pla                              ; A = slot: the variant without the horizontal flip
        plx                              ; X = key offset
        DO    HAS_CHR_RAM
        php
        sei                              ; (the flag test and the store, with no NES task in between)
        pha
        jsr   :chr_dirty
        bne   :stale
        pla
        FIN
        stal  PPU_MEM+SPR_COMP_TBL,x
        tya
        stal  PPU_MEM+SPR_COMP_TBL+2,x
        DO    HAS_CHR_RAM
        plp
        FIN
        rts

        DO    HAS_CHR_RAM
:stale  pla                              ; Rewritten while it was compiled: free the slot instead
        xba
        and   #$00FF
        tax
        lda   #$FFFF
        stal  PPU_MEM+SPR_OWNER,x
        plp
        rts

; Z = 0 if the tile of the key in X has its sprite dirty flag set.  X is preserved.
:chr_dirty
        phx
        txa
        lsr
        lsr
        lsr                              ; (pattern table << 8 | tile): the 0-511 index of ChrRamDirty
        tax
        ldal  ChrRamDirty,x
        plx
        and   #CHRRAM_SPR_DIRTY
        rts
        FIN

; A tile's pixels changed (CHR-RAM write), so its compiled sprites are stale.  If a key has a compiled sprite,
; drop it and free its slot; the slot is used again when the cursor gets back to it.  This is for one key; the
; caller does both vertical orientations of the tile.
;
; X = key offset (horizontal flip bit clear).  All registers trashed.
        mx    %00
SprInvalidate
        ldal  PPU_MEM+SPR_COMP_TBL,x
        beq   :done                      ; never compiled, or already evicted
        xba
        and   #$00FF
        tay                              ; Y = slot address >> 8
        lda   #0
        stal  PPU_MEM+SPR_COMP_TBL,x
        stal  PPU_MEM+SPR_COMP_TBL+2,x
        tyx
        dec                              ; A = $FFFF: no owner
        stal  PPU_MEM+SPR_OWNER,x
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

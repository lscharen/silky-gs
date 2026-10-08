; Compile an 8x8 sprite tile into executable code in the SpriteBank, for one sprite palette
;
; Y = address in the compile bank
; A = address of the tile in the tiledata bank (as is at +0 / mask +32, flipped horizontally at +64 / +96)
; X = 0 for the sprite as it is, 2 for the vertically flipped sprite
; sprPalPtr = long pointer to the swizzle table of the sprite palette (SwizzlePtr2 + palette * $200)
; DBR = the program bank
;
; The horizontally flipped variant goes at Y + $100.
;
; The swizzle table is applied here, so the code has the final pixel values as immediates.  The
; vertical flip is part of the cache key (see SPR_* in Defs.s), so one compiled sprite is for one
; vertical orientation and one palette: the code as is (or flipped vertically) and flipped
; horizontally.  Each of the two has its own entry in SPR_COMP_TBL, so there is no dispatch code.
;
; Sprites are called with X = the SHR address (sprTmp1) and the data bank set to the shadow screen
; ($01).  Each variant ends with a JML back to draw_rtn2.  Emitted code:
;
;  lda $0000,x            ; each word with transparent pixels
;  and #mask
;  ora #pixels            ; (left out when the pixels are all 0)
;  sta $0000,x
;
;  lda #pixels            ; the opaque words, grouped by value: one load for each value
;  sta $0000,x
;  sta $0002,x
;  ...

sprPalPtr equ tmp12              ; (3 bytes) swizzle table of the palette being compiled

        mx    %00
CompileSprite
:atbl    equ tmp9                ; word_addr or word_addr_flip
:src     equ tmp10

        sta  :src
        lda  #word_addr          ; screen offsets of the 16 words: in order, or flipped vertically
        cpx  #0
        beq  *+5
        lda  #word_addr_flip
        sta  :atbl

        phy
        jsr  EmitSpriteVariant   ; the sprite as it is (or flipped vertically) at the start of the slot
        pla
        clc
        adc  #$100               ; the horizontally flipped variant at slot + $100
        tay
        lda  :src
        clc
        adc  #64
        sta  :src
        jmp  EmitSpriteVariant

; Emit one variant: the 16 words of the tile data at :src, to the screen offsets in :atbl.
;
; Y = output address in the compile bank.  Returns Y = the end of the code.
        mx    %00
EmitSpriteVariant
:j       equ tmp8
:atbl    equ tmp9
:src     equ tmp10
:out     equ tmp11
:v       equ tmp14

        sty  :out

; 1. The mask and the final pixels of each word

        lda  #30
        sta  :j
:resolve
        lda  :j
        clc
        adc  :src
        tax
        ldal tiledata+32,x       ; mask: 0 = opaque, $FFFF = transparent
        pha
        ldal tiledata,x          ; swizzle table index of the 4 pixels
        tay
        lda  [sprPalPtr],y       ; the 4 pixels in the palette's IIgs colors
        ldx  :j
        sta  cs_val,x
        pla
        sta  cs_msk,x
        dec  :j
        dec  :j
        bpl  :resolve

; 2. The words with transparent pixels: read, mask, merge and write back

        ldx  #0
:masked
        lda  cs_msk,x
        beq  :m_next             ; opaque
        cmp  #$FFFF
        beq  :m_next             ; transparent
        stx  :j
        txy
        lda  (:atbl),y
        sta  :v                  ; (the screen offset)
        ldx  #$BD                ; lda abs,x
        jsr  :emit3
        ldx  :j
        lda  cs_msk,x
        ldx  #$29                ; and #mask
        jsr  :emit3
        ldx  :j
        lda  cs_val,x
        beq  :no_ora
        ldx  #$09                ; ora #pixels
        jsr  :emit3
:no_ora
        lda  :v
        ldx  #$9D                ; sta abs,x
        jsr  :emit3
        ldx  :j
:m_next
        inx
        inx
        cpx  #32
        bcc  :masked

; 3. The opaque words, one load for each value: A still holds it after each store

        ldx  #0
:opaque
        lda  cs_msk,x
        bne  :o_next             ; not opaque, or already stored
        stx  :j
        lda  cs_val,x
        sta  :v
        ldx  #$A9                ; lda #pixels
        jsr  :emit3
        ldx  :j
:same
        lda  cs_msk,x            ; every opaque word from here on with the same value
        bne  :s_next
        lda  cs_val,x
        cmp  :v
        bne  :s_next
        dec  cs_msk,x            ; = $FFFF: stored
        txy
        lda  (:atbl),y
        phx
        ldx  #$9D                ; sta abs,x
        jsr  :emit3
        plx
:s_next
        inx
        inx
        cpx  #32
        bcc  :same
        ldx  :j
:o_next
        inx
        inx
        cpx  #32
        bcc  :opaque

        ldy  :out
        jmp  _EmitReturn

; Emit an instruction with a 16-bit operand.  X = opcode, A = operand.
:emit3
        pha
        txa
        ldy  :out
        sta  [SpriteBank0],y     ; (the high byte is overwritten by the operand)
        iny
        pla
        sta  [SpriteBank0],y
        iny
        iny
        sty  :out
        rts

cs_val  ds   32                  ; the 16 words being compiled: final pixels
cs_msk  ds   32                  ;                              mask

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
; * The colors are compiled in, so a change to the sprite swizzle tables drops every compiled sprite
;   (SprRequestFlush / SprCacheFlush).
; * CHR-RAM: the first write to a tile drops its compiled sprites (every palette and orientation) and sets its
;   sprite dirty flag (PPUDATA_WRITE), and a dirty tile is never compiled (SprCompileTile), so a hit needs no
;   check.  The bitmap draws reconvert a dirty tile first (sprChrCheck in ppu.s).
; ---------------------------------------------------------------------------------------------------

; Start with an empty cache.  Called once from PPUStartUp.
        mx    %00
SprCacheInit
        lda   #0                         ; nothing is compiled
        ldx   #$1FFE
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
        lda   #0                         ; evict the previous owner
        stal  PPU_MEM+SPR_COMP_TBL,x

:have_slot
        lda   3,s                        ; The palette's swizzle table: SwizzlePtr2 + palette * $200
        and   #$0C00
        lsr
        clc
        adc   SwizzlePtr2
        sta   sprPalPtr
        lda   SwizzlePtr2+2
        sta   sprPalPtr+2

        lda   3,s                        ; The tile in the tiledata bank: pattern table * $8000 + tile * 128
        and   #$1000
        asl
        asl
        asl
        sta   tmp14
        lda   3,s
        and   #$03FC                     ; tile * 4
        asl
        asl
        asl
        asl
        asl
        ora   tmp14
        pha
        lda   5,s
        and   #$0002
        tax                              ; X = 2 for a vertically flipped sprite, else 0
        lda   3,s
        tay                              ; Y = address in the compile bank
        pla
        jsr   CompileSprite              ; (trashes tmp7 - tmp14, which SprCacheService saves)
        pla                              ; A = slot
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
        and   #$1000                     ; pattern table << 12 -> << 8
        lsr
        lsr
        lsr
        lsr
        pha
        txa
        lsr
        lsr
        and   #$00FF                     ; tile
        ora   1,s                        ; the 0-511 index of ChrRamDirty
        tax
        pla
        ldal  ChrRamDirty,x
        plx
        and   #CHRRAM_SPR_DIRTY
        rts
        FIN

; The sprite swizzle tables changed (a new palette map, or a table rebuilt in place), so every compiled
; sprite has the old colors: drop them all.  Requested through SprFlushReq (SprRequestFlush, from either
; task) and done by drawSprites before it draws, on the GS task.
        mx    %00
SprCacheFlush
        lda   #0
        stal  SprFlushReq                ; (first: a request during the flush is seen next time)
        ldx   #{SPR_SLOTS+1}*2-2
:slot
        ldal  PPU_MEM+SPR_OWNER,x
        bmi   :next                      ; free
        phx
        tax
        lda   #0
        stal  PPU_MEM+SPR_COMP_TBL,x
        plx
        lda   #$FFFF
        stal  PPU_MEM+SPR_OWNER,x
:next
        dex
        dex
        bpl   :slot
        rts

; Ask for SprCacheFlush.  Callable from either task, in any data bank; A is trashed.
        mx    %00
SprRequestFlush
        lda   #1
        stal  SprFlushReq
        rts

SprFlushReq dw 0

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
        pei   tmp12
        pei   tmp13
        pei   tmp14

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
        sta   tmp14
        pla
        sta   tmp13
        pla
        sta   tmp12
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

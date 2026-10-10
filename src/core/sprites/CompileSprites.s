; Compile an 8x8 sprite tile into executable code in a sprite compile bank, for one sprite palette
;
; Y = address of the slot in its compile bank (SpriteBank = the slot's bank)
; A = address of the tile in the tiledata bank (as is at +0 / mask +32, flipped horizontally at +64 / +96)
; X = 0 for the sprite as it is, 2 for the vertically flipped sprite
; sprPalPtr = long pointer to the swizzle table of the sprite palette (SwizzlePtr2 + palette * $200)
; DBR = the program bank
;
; The variants go in the slot's 512 byte parts (see SPR_* in Defs.s).  With cs_mode = 0, the sprite as
; is at Y and flipped horizontally at Y + $200; with cs_mode = 1, both of those shifted one pixel to the
; right (for a sprite on an odd pixel) at Y + $400 and Y + $600.  The shifted pair is compiled later, the
; first time the sprite is drawn on an odd pixel (SprCompileShift).  Without SPR_PIXEL_SHIFT, there are
; only the first two, at Y and Y + $100.
;
; The swizzle table is applied here, so the code has the final pixel values as immediates.  The
; vertical flip is part of the cache key (see SPR_* in Defs.s), so one compiled sprite is for one
; vertical orientation and one palette.  The dispatch ORs the variant's page offset into the slot's
; SPR_COMP_TBL entry, so there is no dispatch code.
;
; Sprites are called with Y = the SHR address (sprTmp1) and the data bank set to the shadow screen
; ($01); X is not touched (drawSprites keeps the OAM index in it).  Each variant ends with a JML back to
; draw_rtn2.  Emitted code:
;
;  lda $0000,y            ; each word with transparent pixels
;  and #mask
;  ora #pixels            ; (left out when the pixels are all 0)
;  sta $0000,y
;
;  lda #pixels            ; the opaque words, grouped by value: one load for each value
;  sta $0000,y
;  sta $0002,y
;  ...

sprPalPtr equ tmp12              ; (3 bytes) swizzle table of the palette being compiled

        mx    %00
CompileSprite
:src     equ tmp10

        sta  :src
        sty  cs_slot
        DO   SPR_PIXEL_SHIFT
        lda  #word_addr          ; screen offsets of the words: in order, or flipped vertically
        ldy  #word_addr_shift
        cpx  #0
        beq  *+8
        lda  #word_addr_flip
        ldy  #word_addr_shift_flip
        sta  cs_atbl
        tya
        sec
        sbc  #32                 ; (the shifted words are at cs_val + 32 / cs_msk + 32)
        sta  cs_satbl
        ELSE
        lda  #word_addr          ; screen offsets of the words: in order, or flipped vertically
        cpx  #0
        beq  *+5
        lda  #word_addr_flip
        sta  cs_atbl
        FIN

        ldy  cs_slot
        jsr  EmitSpriteVariant   ; the sprite as it is (or flipped vertically): slot + $000 or + $400
        lda  :src
        clc
        adc  #64
        sta  :src
        lda  cs_slot
        clc
        adc  #SPR_FLIP_PAGE*256
        tay
        jmp  EmitSpriteVariant   ; flipped horizontally: slot + $200 or + $600 (+ $100 without SPR_PIXEL_SHIFT)

; Emit one variant: the 16 words of the tile data at :src, to the screen offsets in cs_atbl, at Y; or with
; cs_mode = 1, the 24 words of the sprite shifted one pixel to the right, to the screen offsets in
; cs_satbl, at Y + $400.
        mx    %00
EmitSpriteVariant
:src     equ tmp10

; 1. The mask and the final pixels of each word, two words (a line) at a time.  The tiledata segment is a
;    whole bank, so tiledata is at $0000 and the tile's offset in the bank is patched into the loads.

        lda  :src
        sta  :ldv1+1
        inc
        inc
        sta  :ldv0+1                     ; (the second word of the line)
        clc
        adc  #32
        sta  :ldm0+1
        dec
        dec
        sta  :ldm1+1
        phy                              ; the output address
        ldx  #28
:resolve
:ldm0   ldal tiledata+32+2,x             ; mask: 0 = opaque, $FFFF = transparent (patched: :src + 34)
        sta  cs_msk+2,x
:ldv0   ldal tiledata+2,x                ; swizzle table index of the 4 pixels (patched: :src + 2)
        tay
        lda  [sprPalPtr],y               ; the 4 pixels in the palette's IIgs colors
        sta  cs_val+2,x
:ldm1   ldal tiledata+32,x
        sta  cs_msk,x
:ldv1   ldal tiledata,x
        tay
        lda  [sprPalPtr],y
        sta  cs_val,x
        dex
        dex
        dex
        dex
        bpl  :resolve
        ply

; 2. The code: as is, the words at 0 - 30, or shifted, the words at 32 - 78

        DO   SPR_PIXEL_SHIFT
        lda  cs_mode
        bne  :shifted
        FIN
        lda  #32
        sta  cs_end
        lda  cs_atbl
        ldx  #0
        jsr  EmitSpriteWords
        jmp  _EmitReturn

        DO   SPR_PIXEL_SHIFT
:shifted
        phy
        jsr  ShiftSpriteWords
        pla
        clc
        adc  #$400
        tay
        lda  #80
        sta  cs_end
        lda  cs_satbl
        ldx  #32
        jsr  EmitSpriteWords
        jmp  _EmitReturn

        FIN

; Shift each line of cs_val / cs_msk (2 words, 4 bytes) one pixel to the right, into 3 words (6 bytes) at
; cs_val + 32 / cs_msk + 32.  The leftmost pixel of a line is the high nibble of its first byte, the low
; byte of its first word, so a line is shifted as a big-endian (XBA) 32-bit value: its pixels p0 - p7
; become f p0 - p7 f f f, with f = a transparent pixel: value 0, mask $F.
        DO    SPR_PIXEL_SHIFT
        mx    %00
ShiftSpriteWords
:n       equ tmp8                        ; lines left
:hi      equ tmp7                        ; p0 - p3, big-endian
:lo      equ tmp9                        ; p4 - p7, big-endian
:t       equ tmp14

        ldx  #0                          ; The values: f = 0
        txa
        sta  :fill2+1
        jsr  :pass
        ldx  #cs_msk-cs_val              ; The masks: f = $F
        lda  #$0FFF
        sta  :fill2+1
        lda  #$F000

; A = the fill of the first word (f in its first pixel); X = the offset of the 4 byte lines from cs_val
:pass   sta  :fill0+1
        txa
        clc
        adc  #32
        tay                              ; Y = the 6 byte lines
        lda  #8
        sta  :n
:line   lda  cs_val,x
        xba
        sta  :hi
        lsr
        lsr
        lsr
        lsr
:fill0  ora  #$0000                      ; f p0 p1 p2
        xba
        sta  cs_val,y
        lda  cs_val+2,x
        xba
        sta  :lo
        lsr
        lsr
        lsr
        lsr
        sta  :t
        lda  :hi
        and  #$000F
        xba
        asl
        asl
        asl
        asl
        ora  :t                          ; p3 p4 p5 p6
        xba
        sta  cs_val+2,y
        lda  :lo
        and  #$000F
        xba
        asl
        asl
        asl
        asl
:fill2  ora  #$0000                      ; p7 f f f
        xba
        sta  cs_val+4,y
        inx
        inx
        inx
        inx
        tya
        clc
        adc  #6
        tay
        dec  :n
        bne  :line
        rts
        FIN

; Emit the code for some of the resolved words in cs_val / cs_msk.
;
; X = the offset of the first word, cs_end = the offset after the last one, A = the table of their screen
; offsets, minus X (patched into the loads below), Y = the output address in the compile bank.  Returns Y =
; the end of the code.  Each instruction is written as a word, opcode first: its high byte is overwritten
; by the operand.
;
; The words are destroyed: the opaque ones are listed, in order, at the start of the range (value in cs_val,
; screen offset in cs_msk).  The list never gets ahead of the word being read, and nothing reads the words
; again (each variant resolves its own).
        mx    %00
EmitSpriteWords
:k       equ tmp7                        ; the end of the opaque list
:j       equ tmp8
:v       equ tmp14

        sta  :off1+1
        sta  :off2+1
        sta  :off4+1
        stx  :k
        phx

; 1. The words with transparent pixels: read, mask, merge and write back.  The opaque ones are listed.

:masked
        lda  cs_msk,x
        beq  :opq                        ; opaque
        cmp  #$FFFF
        beq  :m_next                     ; transparent
        lda  #$B9                        ; lda abs,y
        sta  [SpriteBank0],y
        iny
:off1   lda: $0000,x                     ; (the screen offset)
        sta  [SpriteBank0],y
        iny
        iny
        lda  #$29                        ; and #mask
        sta  [SpriteBank0],y
        iny
        lda  cs_msk,x
        sta  [SpriteBank0],y
        iny
        iny
        lda  cs_val,x
        beq  :no_ora
        lda  #$09                        ; ora #pixels
        sta  [SpriteBank0],y
        iny
        lda  cs_val,x
        sta  [SpriteBank0],y
        iny
        iny
:no_ora
        lda  #$99                        ; sta abs,y
        sta  [SpriteBank0],y
        iny
:off2   lda: $0000,x
        sta  [SpriteBank0],y
        iny
        iny
:m_next
        inx
        inx
        cpx  cs_end
        bcc  :masked
        bra  :list

:opq    phy                              ; Opaque: add it to the list
        ldy  :k
        lda  cs_val,x
        sta  cs_val,y
:off4   lda: $0000,x
        sta  cs_msk,y
        iny
        iny
        sty  :k
        ply
        bra  :m_next

; 2. The opaque words, one load for each value: A still holds it after each store.  A stored word's offset
;    becomes $FFFF (the offsets are under $8000).

:list   plx
        bra  :o_test
:opaque
        lda  cs_msk,x
        bmi  :o_next                     ; already stored
        stx  :j
        lda  #$A9                        ; lda #pixels
        sta  [SpriteBank0],y
        iny
        lda  cs_val,x
        sta  [SpriteBank0],y
        iny
        iny
        sta  :v
:same
        lda  cs_msk,x                    ; every listed word from here on with the same value
        bmi  :s_next
        lda  cs_val,x
        cmp  :v
        bne  :s_next
        lda  #$99                        ; sta abs,y
        sta  [SpriteBank0],y
        iny
        lda  cs_msk,x
        sta  [SpriteBank0],y
        iny
        iny
        lda  #$FFFF
        sta  cs_msk,x
:s_next
        inx
        inx
        cpx  :k
        bcc  :same
        ldx  :j
:o_next
        inx
        inx
:o_test cpx  :k
        bcc  :opaque
        rts

        DO   SPR_PIXEL_SHIFT
cs_val  ds   80                          ; the words being compiled: final pixels (16 words, then the 24 shifted)
cs_msk  ds   80                          ;                              mask (right after cs_val: ShiftSpriteWords)
cs_satbl dw  0                           ; word_addr_shift or word_addr_shift_flip, minus 32
cs_mode  dw  0                           ; 0: the sprite as is and flipped; 1: the shifted pair
        ELSE
cs_val  ds   32                          ; the words being compiled: final pixels
cs_msk  ds   32                          ;                              mask
        FIN
cs_atbl  dw  0                           ; word_addr or word_addr_flip
cs_slot  dw  0                           ; the slot being compiled
cs_end   dw  0                           ; EmitSpriteWords: the offset after the last word

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

; The stubs on the odd pages of a slot whose shifted pair is not compiled yet: its SPR_COMP_TBL entry has
; page bit 0 set, so the dispatch lands on slot + $100 / $300 (on an even pixel) or + $500 / $700 (odd):
;
;   + $100  jml slot+$000                           + $300  jml slot+$200
;   + $500  jsl SprQueueShift / jml slot+$000       + $700  jsl SprQueueShift / jml slot+$200
;
; The plain variants are at most 196 bytes, so pages + $100 / $300 are free.  The shifted pair overwrites
; the other two when it is compiled.  Y = the slot's address, SpriteBank = its bank.
        DO    SPR_PIXEL_SHIFT
        mx    %00
EmitShiftStubs
        sty  cs_slot
        tya
        ora  #$0100
        tay
        lda  cs_slot
        jsr  :jml
        lda  cs_slot
        ora  #$0300
        tay
        lda  cs_slot
        ora  #$0200
        jsr  :jml
        lda  cs_slot
        ora  #$0500
        tay
        jsr  :jsl
        lda  cs_slot
        jsr  :jml
        lda  cs_slot
        ora  #$0700
        tay
        jsr  :jsl
        lda  cs_slot
        ora  #$0200
:jml                             ; jml A (in the slot's bank) at Y.  (The bank's high byte, 0, is written
        pha                      ; after it: nothing is there)
        lda  #$005C
        sta  [SpriteBank0],y
        iny
        pla
        sta  [SpriteBank0],y
        iny
        iny
        lda  SpriteBank
        sta  [SpriteBank0],y
        iny
        rts
:jsl
        lda  #$0022              ; jsl SprQueueShift
        sta  [SpriteBank0],y
        iny
        lda  #SprQueueShift
        sta  [SpriteBank0],y
        iny
        iny
        lda  #^SprQueueShift
        sta  [SpriteBank0],y
        iny
        rts
        FIN

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

; The shifted variants: 3 words per line
        DO   SPR_PIXEL_SHIFT
word_addr_shift
        dw {0*SHR_LINE_WIDTH}+0
        dw {0*SHR_LINE_WIDTH}+2
        dw {0*SHR_LINE_WIDTH}+4
        dw {1*SHR_LINE_WIDTH}+0
        dw {1*SHR_LINE_WIDTH}+2
        dw {1*SHR_LINE_WIDTH}+4
        dw {2*SHR_LINE_WIDTH}+0
        dw {2*SHR_LINE_WIDTH}+2
        dw {2*SHR_LINE_WIDTH}+4
        dw {3*SHR_LINE_WIDTH}+0
        dw {3*SHR_LINE_WIDTH}+2
        dw {3*SHR_LINE_WIDTH}+4
        dw {4*SHR_LINE_WIDTH}+0
        dw {4*SHR_LINE_WIDTH}+2
        dw {4*SHR_LINE_WIDTH}+4
        dw {5*SHR_LINE_WIDTH}+0
        dw {5*SHR_LINE_WIDTH}+2
        dw {5*SHR_LINE_WIDTH}+4
        dw {6*SHR_LINE_WIDTH}+0
        dw {6*SHR_LINE_WIDTH}+2
        dw {6*SHR_LINE_WIDTH}+4
        dw {7*SHR_LINE_WIDTH}+0
        dw {7*SHR_LINE_WIDTH}+2
        dw {7*SHR_LINE_WIDTH}+4

word_addr_shift_flip
        dw {7*SHR_LINE_WIDTH}+0
        dw {7*SHR_LINE_WIDTH}+2
        dw {7*SHR_LINE_WIDTH}+4
        dw {6*SHR_LINE_WIDTH}+0
        dw {6*SHR_LINE_WIDTH}+2
        dw {6*SHR_LINE_WIDTH}+4
        dw {5*SHR_LINE_WIDTH}+0
        dw {5*SHR_LINE_WIDTH}+2
        dw {5*SHR_LINE_WIDTH}+4
        dw {4*SHR_LINE_WIDTH}+0
        dw {4*SHR_LINE_WIDTH}+2
        dw {4*SHR_LINE_WIDTH}+4
        dw {3*SHR_LINE_WIDTH}+0
        dw {3*SHR_LINE_WIDTH}+2
        dw {3*SHR_LINE_WIDTH}+4
        dw {2*SHR_LINE_WIDTH}+0
        dw {2*SHR_LINE_WIDTH}+2
        dw {2*SHR_LINE_WIDTH}+4
        dw {1*SHR_LINE_WIDTH}+0
        dw {1*SHR_LINE_WIDTH}+2
        dw {1*SHR_LINE_WIDTH}+4
        dw {0*SHR_LINE_WIDTH}+0
        dw {0*SHR_LINE_WIDTH}+2
        dw {0*SHR_LINE_WIDTH}+4
        FIN

; ---------------------------------------------------------------------------------------------------
; Compiled sprite cache
;
; The sprite compile banks are not big enough to hold a compiled version of every sprite tile, so the
; sprites are compiled on demand into a fixed number of slots (see SPR_* in Defs.s):
;
; * A compiled sprite is for one tile and one vertical orientation, and has the normal, the horizontally
;   flipped and the two shifted (odd pixel) variants.  Most games flip horizontally all the time, but a
;   vertical flip is rare, so the vertical flip is part of the cache key.  The SPR_COMP_TBL entry is the
;   slot's bank:page, and the dispatch ORs in the page offset of the variant it needs.
; * The shifted pair is compiled lazily: until it is, the entry has page bit 0 set and the dispatch lands
;   on stubs (EmitShiftStubs) that jump to the plain variants, and on an odd pixel queue the shifted pair
;   (SprQueueShift, SprCompileShift) and draw the sprite a pixel to the left this time.  A sprite that is
;   never on an odd pixel never pays for its shifted code.
; * Slots are not packed.  Each slot is SPR_SLOT_SIZE = 2KB, 512 bytes per variant, 32 per compile bank, in
;   up to SPR_MAX_BANKS banks (InitMemory gets as many as there is memory for).  SPR_SLOT_TBL has each
;   slot's bank:page.  Without SPR_PIXEL_SHIFT, there are no shifted variants or stubs, and a slot is 512
;   bytes, 256 per variant, 128 in one bank (the sizes are in ppu.s).
; * The slots are used in turn (SPR_CURSOR), so the one that is replaced is the one that was filled the
;   longest time ago: a FIFO.  A hit does nothing; it takes a full round of new compiles to replace a sprite.
;   SPR_OWNER has the key offset of each slot's sprite, to clear its SPR_COMP_TBL entry when it is replaced.
; * drawSprites draws a sprite that misses from its bitmap and queues it (SPR_PEND, at most
;   SPR_COMPILE_PER_RENDER entries).  SprCacheService compiles the queue when drawSprites is done.
; * The colors are compiled in, so a change to the sprite swizzle tables drops every compiled sprite
;   (SprRequestFlush / SprCacheFlush).
; * CHR-RAM: the first write to a tile drops its compiled sprites (every palette and orientation) and sets its
;   sprite dirty flag (PPUDATA_WRITE), and a dirty tile is never compiled (SprCompileTile), so a hit needs no
;   check.  The bitmap draws reconvert a dirty tile first (sprChrCheck in ppu.s).
; ---------------------------------------------------------------------------------------------------

; Start with an empty cache, and lay the slots out in the banks InitMemory got.  Called once from
; PPUStartUp.
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
        ldx   #SPR_MAX_SLOTS*2-2
:owners
        stal  PPU_MEM+SPR_OWNER,x
        dex
        dex
        bpl   :owners

        ldx   #0                         ; SPR_SLOT_TBL: bank << 8 | page, SPR_BANK_SLOTS per bank
        txy                              ; Y = the bank's index in SprBanks
:bank
        tya
        cmpl  SprBankCount
        bcs   :slots_done
        phx
        tyx
        ldal  SprBanks,x
        plx
        xba
        and   #$FF00                     ; the bank, page 0
:slot
        stal  PPU_MEM+SPR_SLOT_TBL,x
        inx
        inx
        clc
        adc   #SPR_SLOT_SIZE/256
        bit   #$00FF
        bne   :slot                      ; (until the page wraps to 0)
        iny
        bra   :bank
:slots_done
        txa                              ; the number of slots * 2
        stal  PPU_MEM+SPR_NSLOTS

        lda   #0                         ; start with the first slot
        stal  PPU_MEM+SPR_CURSOR
        stal  PPU_MEM+SPR_PEND_CNT
        DO    SPR_CACHE_STATS
        ldx   #SPR_ST_SIZE-2
:stats  stal  PPU_MEM+SPR_STATS,x
        dex
        dex
        bpl   :stats
        FIN
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
        pha                              ; slot * 2 at 1,s and key offset at 3,s
        inc
        inc
        cmpl  PPU_MEM+SPR_NSLOTS         ; past the last slot?  Then the first one is next
        bcc   :advance
        lda   #0
:advance
        stal  PPU_MEM+SPR_CURSOR

        lda   1,s                        ; make the new key the owner of the slot
        tax                              ; X = slot * 2
        ldal  PPU_MEM+SPR_OWNER,x
        tay                              ; Y = the previous owner
        lda   3,s
        stal  PPU_MEM+SPR_OWNER,x
        tya
        bmi   :have_slot                 ; the slot was free
        tax
        lda   #0                         ; evict the previous owner
        stal  PPU_MEM+SPR_COMP_TBL,x
        SPR_STAT SPR_ST_EVICTS

:have_slot
        SPR_STAT SPR_ST_COMPILES
        lda   1,s                        ; The slot
        tax
        ldal  PPU_MEM+SPR_SLOT_TBL,x     ; bank << 8 | page
        tay
        lda   3,s
        tax
        tya
        jsr   SprCompileSetup
        jsr   CompileSprite              ; (cs_mode = 0: the sprite as is and flipped; trashes tmp7 - tmp14)
        DO    SPR_PIXEL_SHIFT
        ldy   cs_slot
        jsr   EmitShiftStubs             ; (the shifted pair is compiled when it is first needed)
        FIN
        pla                              ; A = slot * 2
        plx                              ; X = key offset
        DO    HAS_CHR_RAM
        php
        sei                              ; (the flag test and the store, with no NES task in between)
        pha
        jsr   :chr_dirty
        bne   :stale
        pla
        FIN
        phx
        tax
        ldal  PPU_MEM+SPR_SLOT_TBL,x     ; the entry: the slot's bank:page, with page bit 0 set: the
        plx                              ; shifted pair is not compiled
        DO    SPR_PIXEL_SHIFT
        ora   #$0001
        FIN
        stal  PPU_MEM+SPR_COMP_TBL,x
        DO    HAS_CHR_RAM
        plp
        FIN
        rts

        DO    HAS_CHR_RAM
:stale  pla                              ; Rewritten while it was compiled: free the slot instead
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

; Compile the shifted pair of a compiled sprite, asked for by the stubs (EmitShiftStubs, SprQueueShift)
; the first time it is drawn on an odd pixel.  The tile data is the one the pair was compiled from: a
; CHR-RAM write clears the entry (PPUDATA_WRITE), and the entry is only updated if it did not change.
;
; X = key offset (bit 0, the shift request, is ignored).  All registers trashed.
        DO    SPR_PIXEL_SHIFT
        mx    %00
SprCompileShift
        txa
        and   #$FFFE
        tax
        ldal  PPU_MEM+SPR_COMP_TBL,x
        bit   #$0001
        bne   :compile
        rts                              ; not compiled (evicted or dropped), or the pair is there already
:compile
        phx                              ; key offset at 3,s
        pha                              ; entry at 1,s
        SPR_STAT SPR_ST_SHIFTS
        lda   1,s
        jsr   SprCompileSetup
        inc   cs_mode
        jsr   CompileSprite              ; (trashes tmp7 - tmp14)
        stz   cs_mode
        pla
        plx
        DO    HAS_CHR_RAM
        php
        sei                              ; (the test and the store, with no NES task in between)
        FIN
        cmpl  PPU_MEM+SPR_COMP_TBL,x
        bne   :changed                   ; dropped while it was compiled
        and   #$FFFE                     ; the shifted pair is there
        stal  PPU_MEM+SPR_COMP_TBL,x
:changed
        DO    HAS_CHR_RAM
        plp
        FIN
        rts
        FIN

; Set up CompileSprite for a key: its palette (sprPalPtr), and its slot's bank (SpriteBank).
; A = the slot's entry (bank << 8 | page; page bit 0 is ignored), X = key offset.  Returns A = the tile in
; the tiledata bank, X = 2 for a vertically flipped sprite (else 0), Y = the slot's address.
        mx    %00
SprCompileSetup
        xba
        sep   #$20
        sta   SpriteBank                 ; the bank for [SpriteBank0],y
        rep   #$20
        and   #$10000-SPR_SLOT_SIZE      ; (slots are aligned to their size)
        sta   cs_slot

        txa                              ; The palette's swizzle table: SwizzlePtr2 + palette * $200
        and   #$0C00
        lsr
        clc
        adc   SwizzlePtr2
        sta   sprPalPtr
        lda   SwizzlePtr2+2
        sta   sprPalPtr+2

        txa                              ; The tile in the tiledata bank: pattern table * $8000 + tile * 128
        and   #$1000
        asl
        asl
        asl
        sta   tmp14
        txa
        and   #$03FC                     ; tile * 4
        asl
        asl
        asl
        asl
        asl
        ora   tmp14
        tay
        txa
        and   #$0002
        tax
        tya
        ldy   cs_slot
        rts

; The sprite swizzle tables changed (a new palette map, or a table rebuilt in place), so every compiled
; sprite has the old colors: drop them all.  Requested through SprFlushReq (SprRequestFlush, from either
; task) and done by drawSprites before it draws, on the GS task.
        mx    %00
SprCacheFlush
        lda   #0
        stal  SprFlushReq                ; (first: a request during the flush is seen next time)
        ldx   #SPR_MAX_SLOTS*2-2
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
; run at the end of drawSprites (it only has to run before the next one), and trashes tmp7 - tmp14:
; nothing that calls drawSprites keeps them across it.  The caller's data bank is preserved.
        mx    %00
SprCacheService
        ldal  PPU_MEM+SPR_PEND_CNT
        beq   :exit

        phb
        phk
        plb                              ; CompileSprite's data tables are addressed with the program bank

        tax                              ; X = the end of the pending list; compile the last key first
:next
        dex
        dex
        phx
        ldal  PPU_MEM+SPR_PEND,x
        tax
        DO    SPR_PIXEL_SHIFT
        lsr                              ; bit 0: the shifted pair of a compiled sprite
        bcs   :shift
        jsr   SprCompileTile
        bra   :done
:shift  jsr   SprCompileShift
        ELSE
        jsr   SprCompileTile
        FIN
:done   plx
        bne   :next                      ; (not the first entry yet)

        lda   #0
        stal  PPU_MEM+SPR_PEND_CNT
        plb
:exit
        rts

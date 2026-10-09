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
; first time the sprite is drawn on an odd pixel (SprCompileShift).
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

        ldy  cs_slot
        jsr  EmitSpriteVariant   ; the sprite as it is (or flipped vertically): slot + $000 or + $400
        lda  :src
        clc
        adc  #64
        sta  :src
        lda  cs_slot
        clc
        adc  #$200
        tay
        jmp  EmitSpriteVariant   ; flipped horizontally: slot + $200 or + $600

; Emit one variant: the 16 words of the tile data at :src, to the screen offsets in cs_atbl, at Y; or with
; cs_mode = 1, the 24 words of the sprite shifted one pixel to the right, to the screen offsets in
; cs_satbl, at Y + $400.
        mx    %00
EmitSpriteVariant
:j       equ tmp8
:src     equ tmp10
:out     equ tmp11

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

; 2. The code: as is, the words at 0 - 30

        lda  cs_mode
        bne  :shifted
        lda  cs_atbl
        ldx  #0
        ldy  #32
        jsr  EmitSpriteWords
        jmp  _EmitReturn

; or shifted, the words at 32 - 78

:shifted
        jsr  ShiftSpriteWords
        lda  :out
        clc
        adc  #$400
        sta  :out
        lda  cs_satbl
        ldx  #32
        ldy  #80
        jsr  EmitSpriteWords
        jmp  _EmitReturn

; Shift each line of cs_val / cs_msk (2 words, 4 bytes) one pixel to the right, into 3 words (6 bytes) at
; cs_val + 32 / cs_msk + 32.  The leftmost pixel of a line is the high nibble of its first byte (the low
; byte of the first word), so each new byte is the low nibble of the byte before it and the high nibble
; of its own.  The pixels shifted in (the first one and the last three) are transparent: value 0, mask $F.
        mx    %00
ShiftSpriteWords
        ldx  #0                  ; X = the line in the 4 byte lines, Y = in the 6 byte lines
        ldy  #32
:line
        phx
        phy
        lda  #$00                ; the pixels
        jsr  :shift
        ply
        plx
        phx
        phy
        txa
        clc
        adc  #cs_msk-cs_val
        tax
        tya
        clc
        adc  #cs_msk-cs_val
        tay
        lda  #$0F                ; the mask
        jsr  :shift
        ply
        plx
        inx
        inx
        inx
        inx
        tya
        clc
        adc  #6
        tay
        cpx  #32
        bcc  :line
        rts

; One line: X = the 4 source bytes, Y = the 6 destination bytes (offsets from cs_val), A = the fill nibble.
:shift
        sep  #$20
        mx   %10
        sta  cs_fill
        asl
        asl
        asl
        asl
        sta  cs_prev             ; the low nibble of the byte before, in the high nibble
        lda  #4
        sta  cs_cnt
:byte
        lda  cs_val,x
        pha
        lsr
        lsr
        lsr
        lsr
        ora  cs_prev
        sta  cs_val,y
        pla
        asl
        asl
        asl
        asl
        sta  cs_prev
        inx
        iny
        dec  cs_cnt
        bne  :byte
        lda  cs_prev             ; the last pixel and a transparent one
        ora  cs_fill
        sta  cs_val,y
        lda  cs_fill             ; two transparent pixels
        asl
        asl
        asl
        asl
        ora  cs_fill
        sta  cs_val+1,y
        rep  #$20
        mx   %00
        rts

; Emit the code for some of the resolved words in cs_val / cs_msk.
;
; X = the offset of the first word, Y = the offset after the last one, A = the table of their screen
; offsets, minus X.  Writes the code at :out, and leaves :out at the end of it; returns Y = :out.
        mx    %00
EmitSpriteWords
:j       equ tmp8
:atbl    equ tmp9
:out     equ tmp11
:v       equ tmp14

        sta  :atbl
        stx  cs_first
        sty  cs_end

; 1. The words with transparent pixels: read, mask, merge and write back

:masked
        lda  cs_msk,x
        beq  :m_next             ; opaque
        cmp  #$FFFF
        beq  :m_next             ; transparent
        stx  :j
        txy
        lda  (:atbl),y
        sta  :v                  ; (the screen offset)
        ldx  #$B9                ; lda abs,y
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
        ldx  #$99                ; sta abs,y
        jsr  :emit3
        ldx  :j
:m_next
        inx
        inx
        cpx  cs_end
        bcc  :masked

; 2. The opaque words, one load for each value: A still holds it after each store

        ldx  cs_first
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
        ldx  #$99                ; sta abs,y
        jsr  :emit3
        plx
:s_next
        inx
        inx
        cpx  cs_end
        bcc  :same
        ldx  :j
:o_next
        inx
        inx
        cpx  cs_end
        bcc  :opaque

        ldy  :out
        rts

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

cs_val  ds   80                  ; the words being compiled: final pixels (16 words, then the 24 shifted)
cs_msk  ds   80                  ;                              mask (right after cs_val: ShiftSpriteWords)
cs_atbl  dw  0                   ; word_addr or word_addr_flip
cs_satbl dw  0                   ; word_addr_shift or word_addr_shift_flip, minus 32
cs_slot  dw  0                   ; the slot being compiled
cs_mode  dw  0                   ; 0: the sprite as is and flipped; 1: the shifted pair
cs_first dw  0                   ; EmitSpriteWords: the words to emit
cs_end   dw  0
cs_fill  db  0                   ; ShiftSpriteWords: the nibble shifted in
cs_prev  db  0                   ;                   the low nibble of the byte before, << 4
cs_cnt   db  0                   ;                   bytes left in the line

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
;   slot's bank:page.
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

        ldx   #0                         ; SPR_SLOT_TBL: bank << 8 | page, 32 slots per bank
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
        bne   :slot                      ; (32 slots of 8 pages, then the page wraps to 0)
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
        ldy   cs_slot
        jsr   EmitShiftStubs             ; (the shifted pair is compiled when it is first needed)
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
        ora   #$0001
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

; Set up CompileSprite for a key: its palette (sprPalPtr), and its slot's bank (SpriteBank).
; A = the slot's entry (bank << 8 | page; page bit 0 is ignored), X = key offset.  Returns A = the tile in
; the tiledata bank, X = 2 for a vertically flipped sprite (else 0), Y = the slot's address.
        mx    %00
SprCompileSetup
        xba
        sep   #$20
        sta   SpriteBank                 ; the bank for [SpriteBank0],y
        rep   #$20
        and   #$F800                     ; (slots are 8-page aligned)
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
        lsr                              ; bit 0: the shifted pair of a compiled sprite
        bcs   :shift
        jsr   SprCompileTile
        bra   :done
:shift  jsr   SprCompileShift
:done   plx
        bne   :next                      ; (not the first entry yet)

        lda   #0
        stal  PPU_MEM+SPR_PEND_CNT
        plb
:exit
        rts

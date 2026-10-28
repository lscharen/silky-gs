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
;
;  sep #$20               ; the words with one byte transparent, as the other byte (when that saves more
;  lda $0000,y            ; than the sep / rep: EmitSpriteWords): the bytes with transparent pixels,
;  and #mask              ; then the opaque ones, grouped by value
;  ora #pixels
;  sta $0000,y
;  lda #pixels
;  sta $0003,y
;  ...
;  rep #$20

sprPalPtr equ tmp12              ; (3 bytes) swizzle table of the palette being compiled

        mx    %00
CompileSprite
:src     equ tmp10

        sta  :src
        sty  cs_slot
        stx  cs_vflip

; The parameters of the sprite's size (cs_params): 8x8, or with cs_tall (SPR_TALL) a whole 8x16 sprite
        ldx  #0
        DO   SPR_TALL
        lda  cs_tall
        beq  *+5
        ldx  #CS_PSIZE
        FIN
        ldy  #0
:par    lda  cs_params,x
        sta  cs_atbl,y
        inx
        inx
        iny
        iny
        cpy  #CS_PSIZE
        bcc  :par

        lda  cs_vflip            ; screen offsets of the words: in order, or flipped vertically
        beq  :emit
        lda  cs_atblf
        sta  cs_atbl
        DO   SPR_PIXEL_SHIFT
        lda  cs_satblf
        sta  cs_satbl
        FIN
:emit
        ldy  cs_slot
        jsr  EmitSpriteVariant   ; the sprite as it is (or flipped vertically): slot + $000 or + cs_spage
        lda  :src
        clc
        adc  #64
        sta  :src
        lda  cs_slot
        clc
        adc  cs_fpage
        tay
        jmp  EmitSpriteVariant   ; flipped horizontally: slot + cs_fpage (+ cs_spage)

; Emit one variant: the 16 words of the tile data at :src (32 for a whole 8x16 sprite), to the screen offsets
; in cs_atbl, at Y; or with cs_mode = 1, the 24 (48) words of the sprite shifted one pixel to the right, to
; the screen offsets in cs_satbl, at Y + cs_spage.
        mx    %00
EmitSpriteVariant
:src     equ tmp10

; 1. The mask and the final pixels of each word, two words (a line) at a time.  A whole 8x16 sprite
;    (cs_tall) has the next tile (:src + 128) as its bottom half, in words 16 - 31.

        phy                              ; the output address
        DO   SPR_TALL
        lda  cs_tall
        beq  :top
        lda  #32
        sta  cs_rlo
        lda  :src
        clc
        adc  #128-32                     ; (the offsets of words 16 - 31 are 32 - 63)
        ldx  #60
        jsr  SprResolve
:top
        FIN
        stz  cs_rlo
        lda  :src
        ldx  #28
        jsr  SprResolve
        ply

; 2. The code: as is, the words at 0 - cs_wend, or shifted, the words at cs_soff - cs_send

        DO   SPR_PIXEL_SHIFT
        lda  cs_mode
        bne  :shifted
        FIN
        lda  cs_wend
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
        adc  cs_spage
        tay
        lda  cs_send
        sta  cs_end
        lda  cs_satbl
        ldx  cs_soff
        jsr  EmitSpriteWords
        jmp  _EmitReturn

        FIN

; Resolve the lines of a tile into cs_val / cs_msk, from the last one: X = the offset of the last line's
; first word (4 bytes a line), down to cs_rlo; A = the tile in the tiledata bank, minus the offset of its
; first line.  The tiledata segment is a whole bank, so tiledata is at $0000 and the tile's offset in the
; bank is patched into the loads.  Y is trashed.
        mx    %00
SprResolve
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
:resolve
:ldm0   ldal tiledata+32+2,x             ; mask: 0 = opaque, $FFFF = transparent (patched: tile + 34)
        sta  cs_msk+2,x
:ldv0   ldal tiledata+2,x                ; swizzle table index of the 4 pixels (patched: tile + 2)
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
        bmi  :done
        cpx  cs_rlo
        bcs  :resolve
:done   rts

; Shift each line of cs_val / cs_msk (2 words, 4 bytes; cs_lines of them) one pixel to the right, into 3
; words (6 bytes) at cs_val + cs_soff / cs_msk + cs_soff.  The leftmost pixel of a byte is its high nibble, so
; the line's bytes b0 - b3 (pixels p0 - p7) become f p0 / p1 p2 / p3 p4 / p5 p6 / p7 f / f f, with f = a
; transparent pixel: value 0, mask $F.  Output byte k is the low byte of (b(k-1) << 8 | b(k)) >> 4: a word
; read at byte k - 1 (b(k) << 8 | b(k-1)), swapped and shifted.  Each is stored as a word at byte k, and the
; next store writes over its high byte.  The values and the masks are done together.
        DO    SPR_PIXEL_SHIFT
        mx    %00
ShiftSpriteWords
:n       equ tmp8                        ; lines left

        ldx  #0
        ldy  cs_soff                     ; Y = the 6 byte lines
        lda  cs_lines
        sta  :n
:line   lda  cs_val,x                    ; f p0
        and  #$00FF
        lsr
        lsr
        lsr
        lsr
        sta  cs_val,y
        lda  cs_msk,x
        and  #$00FF
        ora  #$0F00
        lsr
        lsr
        lsr
        lsr
        sta  cs_msk,y
        lda  cs_val+0,x
        xba
        lsr
        lsr
        lsr
        lsr
        sta  cs_val+1,y
        lda  cs_msk+0,x
        xba
        lsr
        lsr
        lsr
        lsr
        sta  cs_msk+1,y
        lda  cs_val+1,x
        xba
        lsr
        lsr
        lsr
        lsr
        sta  cs_val+2,y
        lda  cs_msk+1,x
        xba
        lsr
        lsr
        lsr
        lsr
        sta  cs_msk+2,y
        lda  cs_val+2,x
        xba
        lsr
        lsr
        lsr
        lsr
        sta  cs_val+3,y
        lda  cs_msk+2,x
        xba
        lsr
        lsr
        lsr
        lsr
        sta  cs_msk+3,y
        lda  cs_val+3,x                  ; p7 f, f f
        and  #$000F
        asl
        asl
        asl
        asl
        sta  cs_val+4,y
        lda  cs_msk+3,x
        and  #$000F
        asl
        asl
        asl
        asl
        ora  #$FF0F
        sta  cs_msk+4,y
        inx
        inx
        inx
        inx
        tya
        clc
        adc  #6
        tay
        dec  :n
        beq  *+5
        brl  :line
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
:end     equ tmp8                        ; the offset after the last word (cs_end)
:j       equ tmp8                        ;   (the grouping loops, after the words)
:nb      equ tmp9                        ; the end of the byte list (cs_bent)
:o       equ tmp11                       ; the screen offset of the word being written
:v       equ tmp14

        sta  :off1+1                     ; (the patches are written with DBR = the program bank)
        sta  :off4+1
        sta  :off5+1
        sta  :off6+1
        stx  :k
        stz  :nb
        lda  cs_end
        sta  :end
        phb
        phx
        sep  #$20                        ; DBR = the compile bank: the code is written with abs,Y stores at
        lda  SpriteBank                  ; fixed offsets, and the tables here are read with long addressing
        pha                              ; (the same cycles as abs,X with 16-bit index registers)
        plb
        rep  #$20

; 1. The words with transparent pixels: read, mask, merge and write back.  The opaque ones are listed, and
;    so are the bytes of the words with one byte transparent (cs_bent: offset, value | mask << 8): with
;    8-bit A, an opaque byte is a 5 cycle store (and a 2 cycle load for each value) instead of the word's
;    18 cycle read-mask-write, a byte with some transparent pixels a 14 cycle one (3, below).

:masked
        ldal cs_msk,x
        beq  :opq                        ; opaque
        cmp  #$FFFF
        beq  :m_next                     ; transparent
        cmp  #$FF00
        bcs  :b_lo                       ; the high byte is transparent
        and  #$00FF
        cmp  #$00FF
        bne  :rmw16                      ; (neither byte is transparent)

; A byte: its value | mask << 8 (for the high byte, the word's high bytes: read at X + 1), then its offset
:b_hi   ldal cs_msk+1,x
        xba
        and  #$FF00
        sta  :v
        ldal cs_val+1,x
        and  #$00FF
        ora  :v
        sta  :v
:off5   ldal word_addr,x
        inc                              ; the high byte
        bra  :b_add
:b_lo   ldal cs_msk,x
        xba
        and  #$FF00
        sta  :v
        ldal cs_val,x
        and  #$00FF
        ora  :v
        sta  :v
:off6   ldal word_addr,x
:b_add  phx
        ldx  :nb
        stal cs_bent,x
        lda  :v
        stal cs_bent+2,x
        inx
        inx
        inx
        inx
        stx  :nb
        plx
:m_next
        inx
        inx
        cpx  :end
        bcc  :masked
        bra  :list

:opq    ldal cs_val,x                    ; Opaque: add it to the list
        sta  :v
:off4   ldal word_addr,x
        phx
        ldx  :k
        stal cs_msk,x
        lda  :v
        stal cs_val,x
        inx
        inx
        stx  :k
        plx
        bra  :m_next

:rmw16
        lda  #$B9                        ; lda abs,y
        sta  $0000,y
:off1   ldal word_addr,x                 ; (patched: the screen offset)
        sta  $0001,y
        sta  :o
        lda  #$29                        ; and #mask
        sta  $0003,y
        ldal cs_msk,x
        sta  $0004,y
        ldal cs_val,x
        beq  :no_ora
        pha
        lda  #$09                        ; ora #pixels
        sta  $0006,y
        pla
        sta  $0007,y
        lda  #$99                        ; sta abs,y
        sta  $0009,y
        lda  :o
        sta  $000A,y
        tya
        clc
        adc  #12
        tay
        bra  :m_next
:no_ora
        lda  #$99                        ; sta abs,y
        sta  $0006,y
        lda  :o
        sta  $0007,y
        tya
        clc
        adc  #9
        tay
        bra  :m_next

; 2. The opaque words, one load for each value: A still holds it after each store.  A stored word's offset
;    becomes $FFFF (the offsets are under $8000).

:list   plx
        bra  :o_test
:opaque
        ldal cs_msk,x
        bmi  :o_next                     ; already stored
        stx  :j
        lda  #$A9                        ; lda #pixels
        sta  $0000,y
        ldal cs_val,x
        sta  $0001,y
        sta  :v
        iny
        iny
        iny
:same
        ldal cs_val,x                    ; every listed word from here on with the same value
        cmp  :v
        bne  :s_next
        ldal cs_msk,x
        bmi  :s_next                     ; (stored)
        sta  $0001,y
        lda  #$99                        ; sta abs,y (the operand first: its high byte is written over)
        sep  #$20
        sta  $0000,y
        rep  #$20
        iny
        iny
        iny
        lda  #$FFFF
        stal cs_msk,x
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

; 3. The bytes, if they save more than the sep / rep around them (6 cycles) and a load; otherwise they are
;    written as words after all (:words).

        ldx  :nb
        bne  *+5
        brl  :exit
        lda  #0
        ldx  #0
:est    sta  :v
        ldal cs_bent+3,x                 ; the mask
        and  #$00FF
        beq  :e_opq
        lda  #4                          ; 18 - 14
        bra  :e_add
:e_opq  lda  #11                         ; 18 - 5 - 2
:e_add  clc
        adc  :v
        inx
        inx
        inx
        inx
        cpx  :nb
        bcc  :est
        cmp  #8
        bcs  :bytes
        brl  :words

:bytes
        lda  #$20E2                      ; sep #$20
        sta  $0000,y
        iny
        iny
        ldx  #0
:rb     ldal cs_bent+3,x                 ; the mask
        and  #$00FF
        beq  :rb_next                    ; opaque: below
        xba
        ora  #$0029                      ; and #mask
        sta  $0003,y
        lda  #$B9                        ; lda abs,y
        sta  $0000,y
        ldal cs_bent,x
        sta  $0001,y
        sta  :o
        ldal cs_bent+2,x                 ; ora #pixels (left out when they are all 0)
        and  #$00FF
        beq  :rb_no
        xba
        ora  #$0009
        sta  $0005,y
        lda  #$99                        ; sta abs,y
        sta  $0007,y
        lda  :o
        sta  $0008,y
        tya
        clc
        adc  #10
        tay
        bra  :rb_done
:rb_no  lda  #$99
        sta  $0005,y
        lda  :o
        sta  $0006,y
        tya
        clc
        adc  #8
        tay
:rb_done
        lda  #$FFFF
        stal cs_bent,x
:rb_next
        inx
        inx
        inx
        inx
        cpx  :nb
        bcc  :rb

        ldx  #0
:ob     ldal cs_bent,x
        bmi  :ob_next                    ; already written
        stx  :j
        ldal cs_bent+2,x                 ; lda #pixels
        and  #$00FF
        sta  :v
        xba
        ora  #$00A9
        sta  $0000,y
        iny
        iny
:os     ldal cs_bent+2,x                 ; every listed byte from here on with the same value
        and  #$00FF
        cmp  :v
        bne  :os_next
        ldal cs_bent,x
        bmi  :os_next                    ; (written)
        sta  $0001,y
        lda  #$99                        ; sta abs,y (the operand first: its high byte is written over)
        sep  #$20
        sta  $0000,y
        rep  #$20
        iny
        iny
        iny
        lda  #$FFFF
        stal cs_bent,x
:os_next
        inx
        inx
        inx
        inx
        cpx  :nb
        bcc  :os
        ldx  :j
:ob_next
        inx
        inx
        inx
        inx
        cpx  :nb
        bcc  :ob

        lda  #$20C2                      ; rep #$20
        sta  $0000,y
        iny
        iny
:exit   plb
        rts

; The bytes as words: read, mask, merge and write back the word, with the other byte's mask $FF
:words  ldx  #0
:w      ldal cs_bent+2,x                 ; value | mask << 8
        sta  :v
        ldal cs_bent,x
        and  #$FFFE
        sta  :o                          ; the word's offset
        lda  #$B9                        ; lda abs,y
        sta  $0000,y
        lda  :o
        sta  $0001,y
        lda  #$29                        ; and #mask
        sta  $0003,y
        ldal cs_bent,x
        lsr                              ; carry = the high byte
        lda  :v
        bcs  :w_hi
        ora  #$00FF                      ; (the low byte: mask << 8, value)
        xba                              ; mask | $FF00
        sta  $0004,y
        lda  :v
        and  #$00FF                      ; the value
        bra  :w_ora
:w_hi   and  #$FF00                      ; (the high byte: the mask is the high byte, the value the low one)
        ora  #$00FF
        sta  $0004,y
        lda  :v
        xba
        and  #$FF00
:w_ora  beq  :w_no
        pha
        lda  #$09                        ; ora #pixels
        sta  $0006,y
        pla
        sta  $0007,y
        lda  #$99
        sta  $0009,y
        lda  :o
        sta  $000A,y
        tya
        clc
        adc  #12
        tay
        bra  :w_next
:w_no   lda  #$99
        sta  $0006,y
        lda  :o
        sta  $0007,y
        tya
        clc
        adc  #9
        tay
:w_next inx
        inx
        inx
        inx
        cpx  :nb
        bcc  :w
        plb
        rts

cs_bent ds   4*48                        ; EmitSpriteWords: the byte writes (offset, value | mask << 8)

        DO   SPR_PIXEL_SHIFT
cs_val  ds   80*{1+SPR_TALL}             ; the words being compiled: final pixels (16 words, then the 24 shifted;
cs_msk  ds   80*{1+SPR_TALL}             ; mask (right after cs_val: ShiftSpriteWords)     8x16: 32, then 48)
cs_mode  dw  0                           ; 0: the sprite as is and flipped; 1: the shifted pair
        ELSE
cs_val  ds   32*{1+SPR_TALL}             ; the words being compiled: final pixels
cs_msk  ds   32*{1+SPR_TALL}             ;                              mask
        FIN
cs_slot  dw  0                           ; the slot being compiled
cs_end   dw  0                           ; EmitSpriteWords: the offset after the last word
cs_vflip dw  0                           ; CompileSprite: X (2 = flipped vertically)
cs_rlo   dw  0                           ; SprResolve: the offset of the first line
cs_tall  dw  0                           ; 1: a whole 8x16 sprite (SPR_TALL; SprCompileSetup)

; The parameters of the sprite being compiled, copied from cs_params by CompileSprite
cs_atbl  dw  0                           ; the screen offsets of the words (word_addr ...)
cs_atblf dw  0                           ;   flipped vertically
cs_wend  dw  0                           ; the offset after the last word
cs_fpage dw  0                           ; the offset of the horizontally flipped variant in the slot
        DO   SPR_PIXEL_SHIFT
cs_satbl dw  0                           ; the screen offsets of the shifted words, minus cs_soff
cs_satblf dw 0                           ;   flipped vertically
cs_soff  dw  0                           ; the offset of the first shifted word
cs_send  dw  0                           ; the offset after the last shifted word
cs_lines dw  0                           ; the number of lines
cs_spage dw  0                           ; the offset of the shifted variants in the slot
        FIN
CS_PSIZE equ  8+{12*SPR_PIXEL_SHIFT}

cs_params                                ; 8x8
        dw   word_addr,word_addr_flip,32,SPR_FLIP_PAGE*256
        DO   SPR_PIXEL_SHIFT
        dw   word_addr_shift-32,word_addr_shift_flip-32,32,80,8,$400
        FIN
        DO   SPR_TALL                    ; a whole 8x16 sprite
        dw   word_addr16,word_addr16_flip,64,SPR16_FLIP_PAGE*256
        FIN
        DO   SPR_TALL*SPR_PIXEL_SHIFT
        dw   word_addr16_shift-64,word_addr16_shift_flip-64,64,160,16,SPR16_SHIFT_PAGE*256
        FIN

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

; The stubs of a whole 8x16 sprite (SPR_TALL) whose shifted pair is not compiled yet: they are the shifted
; variants until it is (the plain ones can be longer than a page, and nothing sets a stub bit in the entry):
;
;   + $800  jsl SprQueueTall / jml slot+$000        + $C00  jsl SprQueueTall / jml slot+$400
;
; SprCompileShift checks for the jsl ($22) before compiling the pair.  Y = the slot's address, SpriteBank =
; its bank.
        DO    SPR_PIXEL_SHIFT*SPR_TALL
        mx    %00
EmitTallStubs
        sty  cs_slot
        tya
        ora  #SPR16_SHIFT_PAGE*256
        tay
        jsr  :jsl
        lda  cs_slot
        jsr  :jml
        lda  cs_slot
        ora  #{SPR16_SHIFT_PAGE+SPR16_FLIP_PAGE}*256
        tay
        jsr  :jsl
        lda  cs_slot
        ora  #SPR16_FLIP_PAGE*256
:jml                             ; jml A (in the slot's bank) at Y
        pha
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
        lda  #$0022              ; jsl SprQueueTall
        sta  [SpriteBank0],y
        iny
        lda  #SprQueueTall
        sta  [SpriteBank0],y
        iny
        iny
        lda  #^SprQueueTall
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

; A whole 8x16 sprite (SPR_TALL): 16 lines
        DO   SPR_TALL
word_addr16
]l      =    0
        lup  16
        dw   {]l*SHR_LINE_WIDTH}+0
        dw   {]l*SHR_LINE_WIDTH}+2
]l      =    ]l+1
        --^

word_addr16_flip
]l      =    15
        lup  16
        dw   {]l*SHR_LINE_WIDTH}+0
        dw   {]l*SHR_LINE_WIDTH}+2
]l      =    ]l-1
        --^
        FIN

        DO   SPR_TALL*SPR_PIXEL_SHIFT
word_addr16_shift
]l      =    0
        lup  16
        dw   {]l*SHR_LINE_WIDTH}+0
        dw   {]l*SHR_LINE_WIDTH}+2
        dw   {]l*SHR_LINE_WIDTH}+4
]l      =    ]l+1
        --^

word_addr16_shift_flip
]l      =    15
        lup  16
        dw   {]l*SHR_LINE_WIDTH}+0
        dw   {]l*SHR_LINE_WIDTH}+2
        dw   {]l*SHR_LINE_WIDTH}+4
]l      =    ]l-1
        --^
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
        lda   #0                         ; nothing is compiled (SPR_TALL: SPR16_COMP_TBL too)
        ldx   #$1FFE+{$1000*SPR_TALL}
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
        FIN
        DO    SPR_PIXEL_SHIFT*SPR_TALL
        lda   cs_tall
        beq   :stubs8
        jsr   EmitTallStubs              ; (the shifted pair is compiled when it is first needed)
        bra   :stubs_done
:stubs8
        FIN
        DO    SPR_PIXEL_SHIFT
        jsr   EmitShiftStubs             ; (the shifted pair is compiled when it is first needed)
:stubs_done
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
        plx                              ; shifted pair is not compiled (not for a whole 8x16 sprite: its
        DO    SPR_PIXEL_SHIFT*SPR_TALL   ; stubs are its shifted variants)
        cpx   #SPR16_KEY
        bcs   *+5
        FIN
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

; Z = 0 if the tile of the key in X (either tile of a whole 8x16 sprite) has its sprite dirty flag set.  X
; is preserved.
:chr_dirty
        phx
        txa
        jsr   SprKeyTile                 ; the tile's address in the tiledata bank
        DO    SPR_TALL
        cpx   #SPR16_KEY
        bcc   :one
        pha
        clc
        adc   #128                       ; the bottom tile
        CHR_INDEX
        ldal  ChrRamDirty,x
        and   #CHRRAM_SPR_DIRTY
        bne   :two
        pla
:one
        FIN
        CHR_INDEX                        ; X = its ChrRamDirty index
        ldal  ChrRamDirty,x
        plx
        and   #CHRRAM_SPR_DIRTY
        rts
        DO    SPR_TALL
:two    pla
        plx
        lda   #1                         ; (Z = 0)
        rts
        FIN
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
        DO    SPR_TALL
        cpx   #SPR16_KEY
        bcs   :tall
        FIN
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

; A whole 8x16 sprite (SPR_TALL): its shifted variants are stubs (EmitTallStubs) until the pair is compiled.
; A CHR-RAM write that drops the sprite while it is compiled leaves the code in a slot that nothing points
; at (the slot is recompiled, with new stubs, when the cursor gets back to it).
        DO    SPR_TALL
:tall
        tay
        bne   *+3
        rts                              ; not compiled (evicted or dropped)
        phx
        pha
        jsr   SprCompileSetup            ; A = the tile, X = the vertical flip, Y = the slot
        pha
        tya
        ora   #SPR16_SHIFT_PAGE*256
        tay
        lda   [SpriteBank0],y
        and   #$00FF
        cmp   #$22                       ; jsl SprQueueTall: still the stub
        bne   :t_skip                    ; (the pair is there already)
        SPR_STAT SPR_ST_SHIFTS
        pla
        ldy   cs_slot
        inc   cs_mode
        jsr   CompileSprite              ; (trashes tmp7 - tmp14)
        stz   cs_mode
        bra   :t_done
:t_skip pla
:t_done pla
        plx
        rts
        FIN
        FIN

; Set up CompileSprite for a key: its palette (sprPalPtr), and its slot's bank (SpriteBank).
; A = the slot's entry (bank << 8 | page; page bit 0 is ignored), X = key offset.  Returns A = the tile in
; the tiledata bank, X = 2 for a vertically flipped sprite (else 0), Y = the slot's address.
        mx    %00
SprCompileSetup
        DO    SPR_TALL
        stz   cs_tall                    ; a whole 8x16 sprite?
        cpx   #SPR16_KEY
        bcc   *+5
        inc   cs_tall
        FIN
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

        txa
        jsr   SprKeyTile                 ; the tile in the tiledata bank
        pha
        txa
        and   #$0002
        tax
        pla
        ldy   cs_slot
        rts

; The tile of a cache key in the tiledata bank (pattern table * $8000 + tile * 128).  A = the key offset.
; Returns A; Y is trashed.
        mx    %00
SprKeyTile
        DO    SPR_TALL
        cmp   #SPR16_KEY
        bcs   :tall
        FIN
        pha                              ; the key
        and   #$03FC                     ; tile * 4
        asl
        asl
        asl
        asl
        asl                              ; tile * 128
        pha
        lda   3,s
        and   #$1000                     ; pattern table << 12
        asl
        asl
        asl                              ; << 15
        ora   1,s
        ply                              ; (drop both)
        ply
        rts

; A whole 8x16 sprite: the top tile (the OAM tile ID with bit 0 clear) of the pattern table in bit 0
        DO    SPR_TALL
:tall   tay
        and   #$0004                     ; the pattern table
        beq   *+5
        lda   #$8000
        pha
        tya
        and   #$03F8                     ; (tile & $FE) * 4
        asl
        asl
        asl
        asl
        asl                              ; * 128
        ora   1,s
        ply                              ; (drop it)
        rts
        FIN

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

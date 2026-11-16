; Compile an 8x8 background tile (its 16 words of tiledata) into code in the compile bank
;
; Y = address in the compile bank: the tile's 128-byte slot, tile number * 128 (0 - 511, pattern table
;     $1000 = 256 - 511) -- the same offset as its data in the tiledata bank
; A = low address of the tile's data
; X = high address (bank) of the tile's data
;
; Returns A = the address after the code, C = 0.
;
; Each distinct word value is loaded once through the palette's swizzle table and stored to every
; word that has it; zero words are a single stz.  Word 0 is done last and not stored: the code returns
; with its value in A, and the caller's CALL_COMPILED_TILE (ppu/ppu_macros.s) stores it.  So no tile
; is larger than 128 bytes: the worst case, 16 distinct non-zero words, is 15 * 8 + 5 + 1 = 126 bytes.
;
;  ldy #value         opcode = $A0    (3)  a distinct value
;  lda [ActivePtr],y  opcode = $B7    (2)
;  sta $0001,x        opcode = $9D    (3)  each word with that value
;  stz $0004,x        opcode = $9E    (3)  each zero word
;  ...
;  ldy #value0 / lda [ActivePtr],y / sta ... (word 0's value last, its other words; or lda #0)
;  rtl                opcode = $6B    (1)
;
; Algorithm is simple O(n^2), but there are only 16 words
        mx    %00
CompileTile
:target equ tmp4
:source equ tmp5
:copy   equ tmp7
:flags  equ tmp8
:w0     equ tmp9

        sty  :target             ; Pointer to the target code address

        sta  :source             ; Pointer to the source data
        stx  :source+2
        jsr  :copy_to_tmp        ; Copy the tile data to a temporary buffer on the direct page

        ldy  :target             ; This is the pointer to the compilation bank address
        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated
        lda  :bit_mask           ; Word 0 is done last (below)
        trb  :flags
        lda  blttmp
        sta  :w0                 ; word 0's value

; Pre-loop to check for any zeros which can be stored via a single STZ command  It's not much
; but does save an immediate load and 3 bytes of space
        ldx  #2                  ; (not word 0)
:zloop  lda  blttmp,x
        bne  :zskip
        jsr  :emit_stz
        lda  :bit_mask,x
        trb  :flags
:zskip
        inx
        inx
        cpx  #32
        bcc  :zloop
        ldx  #2

; In this loop, Y and X always point to the compile bank address and data index, respectively.  The
; words with word 0's value are left for the end.
:loop
        lda  :bit_mask,x        ; Get the flag for the current word
        and  :flags             ; Has this work already been generated?
        beq  :skip
        lda  blttmp,x
        cmp  :w0
        beq  :skip              ; (word 0's value: last)

; Found a new word, so create a lda #imm / sta abs,y code

        jsr  :emit_load_imm
        jsr  :emit_store

; Now search ahead and see if there are any other words with the same value

        cpx  #30              ; was this the last word?
        beq  :last

        lda  blttmp,x
        sta  :copy            ; keep a copy of the word

        phx                   ; save the current index
:loop2
        inx                   ; advance to the next word
        inx
        cmp  blttmp,x         ; if this word the same as the previous value?
        bne  :no_copy         ; no, look at the next one
        jsr  :emit_store      ; emit a store instructore for the current index
        lda  :bit_mask,x
        trb  :flags           ; mark this word as emitted
        lda  :copy            ; reload the test value

:no_copy
        cpx  #30
        bcc  :loop2           ; are there more to check?
        plx                   ; restore the current index


:skip   inx
        inx                   ; Advance to the next word
        cpx  #32
        bcc  :loop

; Word 0's value last, left in A for the caller to store into word 0: load it and store it to the
; other words that have it, or (zero) just load 0 -- the other zero words already have their stz.
:last
        ldx  #0
        lda  :w0
        beq  :w0_zero
        jsr  :emit_load_imm     ; ldy #value0 / lda [ActivePtr],y
        ldx  #2
:w0_loop
        lda  :bit_mask,x
        and  :flags
        beq  :w0_next           ; (a zero word)
        lda  blttmp,x
        cmp  :w0
        bne  :w0_next           ; (another value: done in the loop above)
        jsr  :emit_store
:w0_next
        inx
        inx
        cpx  #32
        bcc  :w0_loop
        bra  :exit

:w0_zero
        lda  #$00A9             ; lda #0
        sta  [CompileBank0],y
        iny
        lda  #0
        sta  [CompileBank0],y
        iny
        iny

:exit
        lda  #$006B           ; return instruction
        sta  [CompileBank0],y
        iny
        tya                   ; Put the address in the accumulator
        clc
        rts

:emit_load_imm
        lda  #$00A0                 ; ldy #imm
        sta  [CompileBank0],y
        iny
        lda  blttmp,x
        sta  [CompileBank0],y
        iny
        iny
        lda  #$B7+{ActivePtr*256}   ; lda [ActivePtr],y
        sta  [CompileBank0],y
        iny
        iny
        rts

; Zero is zero -- no need to do anything. Zero is always mapped to Universal Background Color
:emit_stz
        lda  #$009E           ; stz abs,x
        sta  [CompileBank0],y
        iny
        lda  :word_addr,x
        sta  [CompileBank0],y
        iny
        iny
        rts

:emit_store
        lda  #$009D           ; sta abs,x
        sta  [CompileBank0],y
        iny
        lda  :word_addr,x
        sta  [CompileBank0],y
        iny
        iny
        rts

:copy_to_tmp
        ldy   #0
:ctt_loop
        tyx
        lda   [:source],y
        sta   blttmp,x
        iny
        iny
        cpy   #32
        bcc   :ctt_loop
        rts

; data tables for generating code
:word_addr
        dw {0*_LINE_SPAN}+$0004            ; reverse interleave to account for the within-tile reverse due to using push instructions
        dw {0*_LINE_SPAN}+$0001
        dw {1*_LINE_SPAN}+$0004
        dw {1*_LINE_SPAN}+$0001
        dw {2*_LINE_SPAN}+$0004
        dw {2*_LINE_SPAN}+$0001
        dw {3*_LINE_SPAN}+$0004
        dw {3*_LINE_SPAN}+$0001
        dw {4*_LINE_SPAN}+$0004
        dw {4*_LINE_SPAN}+$0001
        dw {5*_LINE_SPAN}+$0004
        dw {5*_LINE_SPAN}+$0001
        dw {6*_LINE_SPAN}+$0004
        dw {6*_LINE_SPAN}+$0001
        dw {7*_LINE_SPAN}+$0004
        dw {7*_LINE_SPAN}+$0001

:bit_mask
        dw $8000,$4000,$2000,$1000,$0800,$0400,$0200,$0100,$0080,$0040,$0020,$0010,$0008,$0004,$0002,$0001

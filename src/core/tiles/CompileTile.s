; Compile an 8x8 bitmap into executabl code into the CompileBank
;
; Y = address in the compile bank
; 
; A = low address of bitmap
; X = high address of bitmap
;
; Algorithm is simple O(n^2), but there are only 16 words
;   Load first word
;   Emit a load instruction
;   Emit a store instruction
;   Mark work as done
;   Scan for any duplicate words and mark complete
;   Continue until no words are left
;
; Emitted code is:
;
;  lda #value    opcode = $A9
;  sta $0001,x   opcode = $9D
;  stz $0004,x   opcode = $9E
;  ...
;  rtl
CompileTile
        sty  tmp2             ; Pointer to the target code address

        sta  tmp0             ; Pointer to the source data
        stx  tmp1
        jsr  :copy_to_tmp     ; Copy the tile data to a temporary buffer on the direct page

        ldy  tmp2             ; This is the pointer to the compilation bank address
        ldx  #0               ; This is the index into the tile data array on the direct page
        lda  #$FFFF
        sta  tmp3             ; When this value is zero, all 16 words have been generated

; Pre-loop to check for any zeros which can be stored via a single STZ command  It's not much
; but does save an immediate load and 3 bytes of space
:zloop  lda  blttmp,x
        bne  :zskip
        jsr  :emit_stz
        lda  :bit_mask,x
        trb  tmp3
:zskip
        inx
        inx
        cpx  #32
        bcc  :zloop
        ldx  #0

; In this loop, Y and X always point to the compile bank address and data index, respectively
:loop
        lda  :bit_mask,x      ; Get the flag for the current word
        and  tmp3             ; Has this work already been generated?
        beq  :skip

; Found a new word, so create a lda #imm / sta abs,y code

        jsr  :emit_load_imm
        jsr  :emit_store

; Now search ahead and see if there are any other words with the same value

        cpx  #30              ; was this the last word?
        beq  :exit

        lda  blttmp,x
        sta  tmp4             ; keep a copy of the word


        phx                   ; save the current index
:loop2
        inx                   ; advance to the next word
        inx
        cmp  blttmp,x         ; if this word the save as the previous value?
        bne  :no_copy         ; no, look at the next one
        jsr  :emit_store      ; emit a store instructore for the current index
        lda  :bit_mask,x
        trb  tmp3             ; mark this word as emitted
        lda  tmp4             ; reload the test value

:no_copy
        cpx  #30
        bcc  :loop2           ; are there more to check?
        plx                   ; restore the current index


:skip   inx
        inx                   ; Advance to the next word
        cpx  #32
        bcc  :loop
:exit
        lda  #$006B           ; return instruction
        sta  [CompileBank0],y
        iny
        tya                   ; Put the address in the accumulator
        clc
        rts

:emit_load_imm
        lda  #$00A9           ; lda #imm
        sta  [CompileBank0],y
        iny
        lda  blttmp,x
        sta  [CompileBank0],y
        iny
        iny
        rts

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
        lda   [tmp0],y
        sta   blttmp,x
        iny
        iny
        cpy   #32
        bcc   :ctt_loop
        rts

; data tables for generating code
:word_addr
        dw {0*_LINE_SIZE}+$0004            ; reverse interleave to account for the within-tile reverse due to using push instructions
        dw {0*_LINE_SIZE}+$0001
        dw {1*_LINE_SIZE}+$0004
        dw {1*_LINE_SIZE}+$0001
        dw {2*_LINE_SIZE}+$0004
        dw {2*_LINE_SIZE}+$0001
        dw {3*_LINE_SIZE}+$0004
        dw {3*_LINE_SIZE}+$0001
        dw {4*_LINE_SIZE}+$0004
        dw {4*_LINE_SIZE}+$0001
        dw {5*_LINE_SIZE}+$0004
        dw {5*_LINE_SIZE}+$0001
        dw {6*_LINE_SIZE}+$0004
        dw {6*_LINE_SIZE}+$0001
        dw {7*_LINE_SIZE}+$0004
        dw {7*_LINE_SIZE}+$0001

:bit_mask
        dw $8000,$4000,$2000,$1000,$0800,$0400,$0200,$0100,$0080,$0040,$0020,$0010,$0008,$0004,$0002,$0001


; Draw a compiled tile into the code field
;
; A = compiled tile address
; X = tile column (0 to 63)
; Y = tile row (0 to 29)
DrawCompiledTile
        phb

        sta  :patch+1     ; patch in the address

        txa
        asl
        tax

        tya
        asl
        asl
        asl
        asl
        tay

        sep  #$20
        lda  BTableHigh,y
        pha
        lda  CompileBank             ; This can be done once in startup
        sta  :patch+3
        rep  #$20

        lda  BTableLow,y
        clc
        adc  Col2CodeOffset+2,x      ; Due to reverse order, the address has to be the second column of the tile
        tax

        plb                          ; pop the bank for the tile that we're rendering
:patch  jsl  $000000
        plb
        rts


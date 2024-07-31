        ;; Makes a move at (crsr_x, crsr_y). Doesn't touch scratch.
make_move
        ldx     crsr_y
        ldy     crsr_x
        lda     move_edge,y
        eor     grid-1,x
        sta     grid-1,x
        lda     move_edge,y
        eor     grid+1,x
        sta     grid+1,x
        lda     move_center,y
        eor     grid,x
        sta     grid,x
        rts


randomize_board
:count = scratch
:index = scratch+1
:curr  = scratch+2

        ldx     #$01
        stx     :count
        dex
        stx     :index
        lda     #$04
        sta     crsr_y
:row    lda     #$04
        sta     crsr_x
:cell   dec     :count
        bne     :l0
        ;; Out of bits, reset counter, load next rndval
        ldx     :index
        lda     rndval,x
        sta     :curr
        lda     #$08
        sta     :count
        inc     :index
:l0     lsr     :curr
        bcc     :l1
        jsr     make_move
:l1     dec     crsr_x
        bpl     :cell
        dec     crsr_y
        bpl     :row
        ;; Reset cursor on the way out
        lda     #$02
        sta     crsr_x
        sta     crsr_y
        rts

        ;; Checks to see if the puzzle is solved. Zero flag set if it is.
is_solved
        ldx     #$05
:lp     lda     grid-1,x
        bne     :done
        dex
        bne     :lp
:done   rts

move_edge
        db   $10,$08,$04,$02,$01
move_center
        db   $18,$1C,$0E,$07,$03
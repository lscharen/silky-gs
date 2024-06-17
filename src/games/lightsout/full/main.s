;        .import __OAM_START__

;        .importzp scratch, vstat, j0stat, frames
;        .import vidbuf, make_move, move_edge, randomize_board, is_solved
;        .export main
;        .exportzp crsr_x, crsr_y, grid

;.macro  vload   src
vload   mac
        lda     #<]1
        ldx     #>]1
        jsr     vblit
        <<<
;.endmacro

;.macro  vflush
;        .local  lp
vflush  mac
        lda     #$80
        sta     vstat
;lp      bit     vstat            ; IIgs -- yield here
;        bmi     lp
        jsl     yield
        <<<
;.endmacro

;        .zeropage
;crsr_x: .res    1               ; X loc of cursor (0-4)
;crsr_y: .res    1               ; Y loc of cursor (0-4)
;dx:     .res    1               ; Currently input legal cursor motion
;dy:     .res    1
;nx:     .res    1               ; Remaining distance in cursor motion
;ny:     .res    1
;cx:     .res    1               ; Current direction of animated motion
;cy:     .res    1
;        .res    1               ; Scratch byte to make moves easier
;grid:   .res    5               ; The grid
;        .res    1               ; Scratch byte to make moves easier


;        .code

main    ;; Draw the initial screen, except for the board cells
        ldy     #$00
:lp     ldx     screen_base,y
        beq     :done
        iny
        lda     screen_base+1,y
        sta     $2006
        lda     screen_base,y
        sta     $2006
        iny
        iny
:blk    lda     screen_base,y
        sta     $2007
        iny
        dex
        bne     :blk
        beq     :lp
:done   ;; Move all sprites off the screen
        lda     #$ff
        ldy     #$00
:l0     sta     __OAM_START__,y
        iny
        iny
        iny
        iny
        bne     :l0
        ;; Enable graphics
        lda     #$a0
        sta     $2000
        lda     #$1e
        sta     $2001

        ;; Draw the cells one row per frame...
        vload   cell_row_tiles
        vflush
        ;; Change the upper-left tile for mid-board rows
        lda     #$0d
        sta     vidbuf+3

        ;; And draw four more copies of it down the screen
        ldx     #$04
:l1     clc
        lda     vidbuf+1
        adc     #64
        sta     vidbuf+1
        bcc     :l2
        inc     vidbuf+2
:l2      lda     #$80
        sta     vstat
        vflush
        dex
        bne     :l1

        ;; Fall through into game_start

game_start
        ;; Nothing to do until player hits START.
        lda     #$10
        and     j0stat
        beq     game_start

new_game
        ;; Hide the arrow sprite.
        lda     #$ff
        sta     arrow_y

        ;; Since any still-running SFX
        lda     #$00
        sta     $4015

        ;; Update status bar.
        vload   randomizing_msg
        vflush

        ;; Amount of time from poweron to here determines initial puzzle state.
scramble
        jsr     randomize_board
        jsr     grid_to_attr
        ;; If start button is pressed, keep randomizing...
        lda     #$10
        and     j0stat
        bne     scramble

scrambled
        ;; Make sure we didn't actually create a pre-solved puzzle.
        jsr     is_solved
        bne     puzzle_ok
        ;; Whoops! Try again.
        jsr     randomize_board
        jsr     grid_to_attr
        jmp     scrambled

        ;; Put the in-game instructions in place.
puzzle_ok
        vload   instructions
        vflush

        ;; Put the cursor back in the center.
        lda     #74
        sta     arrow_tile
        lda     #127
        sta     arrow_x
        lda     #109
        sta     arrow_y
        lda     #$02
        sta     crsr_x
        sta     crsr_y

player_move
        lda     j0stat
        and     #$10            ; Pressed START?
        bne     new_game
        lda     j0stat          ; Refresh for non-RESET
        bpl     no_flip         ; Pressed A?

        jsr     animate_move
        jsr     is_solved       ; Did we win?
        bne     player_move     ; If not, back to main loop
        jmp     victory

no_flip
        jsr     decode_dirs
        lda     dx              ; Any motion?
        ora     dy
        beq     player_move     ; If not, we're done here

        ;; We're going to move!
        clc
        lda     dx
        sta     cx              ; Copy direction to cached
        adc     crsr_x          ; Compute new grid loc
        sta     crsr_x
        clc
        lda     dy
        sta     cy
        adc     crsr_y
        sta     crsr_y
        lda     #$00            ; Set distance for each axis
        sta     nx
        sta     ny
        ldx     #$10
        lda     dx
        beq     :l4
        stx     nx
:l4     lda     dy
        beq     anim_loop
        stx     ny
anim_loop
        lda     nx              ; Any distance left to move?
        ora     ny
        beq     player_move     ; If not, we're done
        clc
        lda     arrow_x
        adc     cx
        sta     arrow_x
        clc
        lda     arrow_y
        adc     cy
        sta     arrow_y
        jsr     next_frame
        lda     nx              ; Decrement NX and NY if > 0
        beq     :l5
        dec     nx
        bne     :l5
        lda     #$00
        sta     cx
:l5     lda     ny
        beq     :l6
        dec     ny
        bne     :l6
        lda     #$00
        sta     cy
:l6     lda     nx              ; If we're perfectly cell-aligned
        ora     ny              ; go back and check other buttons
        beq     player_move
        lda     j0stat
        jsr     decode_dirs
        lda     dx
        beq     :l7
        cmp     cx
        beq     :l7
        ;; Start (or reverse) horiz motion late.
        sta     cx
        clc
        adc     crsr_x          ; Compute new grid loc
        sta     crsr_x
        lda     #$10
        sec
        sbc     nx
        sta     nx
:l7     lda     dy
        beq     anim_loop
        cmp     cy
        beq     anim_loop
        ;; Start vert motion late.
        sta     cy
        clc
        adc     crsr_y
        sta     crsr_y
        lda     #$10
        sec
        sbc     ny
        sta     ny
        bne     anim_loop

victory
        ;; Hide the arrow sprite.
        lda     #$ff
        sta     arrow_y

        vload   victory_msg
        vflush
        jsr     tada
        jmp     game_start

decode_dirs
        ldx     #$00
        stx     dx
        stx     dy
        lsr
        bcc     :l8
        inc     dx
:l8     lsr
        bcc     :l9
        dec     dx
:l9     lsr
        bcc     :l10
        inc     dy
:l10    lsr
        bcc     :l11
        dec     dy
:l11    lda     crsr_x          ; Bounds-check DX
        clc
        adc     dx
        cmp     #$05
        bcc     :l12
        lda     #$00            ; No motion at edge
        sta     dx
:l12    lda     crsr_y          ; Bounds-check DY
        clc
        adc     dy
        cmp     #$05
        bcc     :l13
        lda     #$00            ; No motion at edge
        sta     dy
:l13    rts


animate_move
        jsr     make_move
        jsr     grid_to_attr
        dec     arrow_x
        inc     arrow_y
        vload   pushed_button
        ;; Adjust the address to match the cursor position
        lda     crsr_y
        clc
        ror
        ror
        ror
        bcc     :l14
        inc     vidbuf+2
        inc     vidbuf+7
:l14    clc
        adc     crsr_x
        adc     crsr_x
        adc     vidbuf+1
        sta     vidbuf+1
        bcc     :l15
        inc     vidbuf+2
        inc     vidbuf+7
:l15    clc
        adc     #$20
        sta     vidbuf+6
        vflush
        jsr     is_solved       ; Is this a winning move?
        beq     :l16            ; If so, skip the move-sound
        jsr     make_ding       ; Otherwise, make a ding based on state
:l16    lda     j0stat          ; Wait for A to be released
        bmi     :l16
        ;; Unpush the button on the way out
        ldy     #$03
:l17    ldx     button_idx,y
        sec
        lda     vidbuf,x
        sbc     #$04
        sta     vidbuf,x
        dey
        bpl     :l17
        inc     arrow_x
        dec     arrow_y
        vflush
        rts

;;; --------------------------------------------------------------------------
;;; * GRAPHICS ROUTINES
;;; --------------------------------------------------------------------------

vblit
        sta     scratch
        stx     scratch+1
        ldy     #$42
:lp     lda     (scratch),y
        sta     vidbuf,y
        dey
        bpl     :lp
        rts


next_frame
        pha
        lda     frames
:lp     cmp     frames
        beq     :lp
        pla
        rts


grid_to_attr
:row    equ scratch
:col    equ scratch+1
:curr   equ scratch+2

        vload   attr_base
        lda     #$04
        sta     :row
        ldy     #$00
:rowlp   lda     #$05
        sta     :col
        ldx     :row
        lda     grid,x
        sta     :curr
:collp   lsr     :curr
        bcc     :next
        ldx     attr_offsets,y
        lda     attr_bit,y
        ora     vidbuf,x
        sta     vidbuf,x
:next    iny
        dec     :col
        bne     :collp
        dec     :row
        bpl     :rowlp
        vflush
        rts


make_ding
        lda     #$01            ; Enable Pulse 1
        sta     $4015
        lda     #$84            ; 50% Duty cycle, 1.25-frame envelope
        sta     $4000
        lda     #$00            ; No sweep
        sta     $4001

        ldx     crsr_y
        lda     grid,x
        ldx     crsr_x
        and     move_edge,x
        beq     low_ding
        ;; Otherwise, high ding
        lda     #$d5
        sta     $4002
        lda     #$08
        sta     $4003
        rts
low_ding
        lda     #$AA
        sta     $4002
        lda     #$09
        sta     $4003
        rts


tada
        lda     #$03            ; Enable Pulse 1 and 2
        sta     $4015
        lda     #$8f            ; 50% Duty cycle, 4-frame envelope
        sta     $4000
        sta     $4004
        lda     #$00            ; No sweep
        sta     $4001
        sta     $4005
        lda     #$69
        sta     $4002           ; C6 on Pulse 1
        lda     #$a8
        sta     $4006           ; E5 on Pulse 2
        lda     #$08            ; Maximum length counter
        sta     $4003
        sta     $4007
        ldx     #$08            ; 8 frames for first note
:lp     jsr     next_frame
        dex
        bne     :lp
        sta     $4003           ; Regate notes
        sta     $4007
        rts                     ; And let them reverberate


attr_offsets
        db   17,16,16,15,15,17,16,16,15,15
        db   11,10,10,9,9,11,10,10,9,9
        db   5,4,4,3,3
attr_bit
        db   $10,$40,$10,$40,$10,$01,$04,$01,$04,$01
        db   $10,$40,$10,$40,$10,$01,$04,$01,$04,$01
        db   $10,$40,$10,$40,$10
button_idx
        db   3,4,8,9

attr_base
        db   3
        dw   $23d3
        db   0,0,0
        db   3
        dw   $23db
        db   0,0,0
        db   3
        dw   $23e3
        db   0,0,0
        db   0

pushed_button
        db   2
        dw   $214c
        db   5,6
        db   2
        dw   $216c
        db   7,8
        db   0

screen_base
        ;; Palette
        db   32
        dw   $3f00
        db   $0f,$00,$0f,$10,$0f,$00,$16,$10,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
        db   $0f,$0f,$00,$30,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

        ;; Logo
        db   12
        dw   $208b
        db   18,19,20,21,22,23,24,25,26,27,28,29
        db   16
        dw   $20a9
        db   30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45

        ;; Board edges
        db   12
        dw   $212b
        db   9,10,10,10,10,10,10,10,10,10,10,11
        db   12
        dw   $228b
        db   15,16,16,16,16,16,16,16,16,16,16,17

        ;; Initial instructions
        db   63
        dw   $2321
        asc  "   BUMBERSHOOT SOFTWARE, 2022   "
        asc  "      PRESS START TO BEGIN     "
        db   0

cell_row_tiles
        db   44
        dw   $214b
        db   12,1,2,1,2,1,2,1,2,1,2,14,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   13,3,4,3,4,3,4,3,4,3,4,14
        db   0

randomizing_msg
        db   63
        dw   $2321
        asc  "         RANDOMIZING...         "
        asc  "                               "
        db   0

instructions
        db   63
        dw   $2321
        asc  "   D-PAD: MOVE        A: FLIP   "
        asc  "      START:  RESET PUZZLE     "
        db   0

victory_msg
        db   63
        dw   $2321
        asc  "        CONGRATULATIONS!        "
        asc  "      PRESS START TO RESET     "
        db   0
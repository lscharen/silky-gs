; Subroutines that deal with the vertical scrolling and rendering.  The primary function
; of these routines are to adjust tables and patch in new values into the code field
; when the virtual Y-position of the play field changes.
_ApplyBG0YPosPreLite
                     lda   StartY               ; This is the base line of the virtual screen
                     jsr   Mod240
                     sta   StartYMod240
                     rts

_ApplyBG0YPosLite

:virt_line_x2        equ   tmp1
:lines_left_x2       equ   tmp2

; First task is to fill in the STK_ADDR values by copying them from the RTable array.  We
; copy from RTable[i] into BlitField[StartY+i].

                     lda   ScreenHeight
                     asl
                     sta   :lines_left_x2

                     lda   StartYMod240
                     asl
                     sta   :virt_line_x2        ; Keep track of it

                     lda   #0

_ApplyBG0YPosAltLite
:rtbl_idx_x2         equ   tmp0
:virt_line_x2        equ   tmp1
:lines_left_x2       equ   tmp2
:draw_count_x2       equ   tmp3

; Check to see if we need to split the update into multiple parts

                    sta   :rtbl_idx_x2

                    ldx   :lines_left_x2             ; 200
                    lda   :virt_line_x2              ;  40
                    cmp   #_LINES_PER_BANK*2         ; 120
                    bcc   *+5
                    sbc   #_LINES_PER_BANK*2
                    sec
                    eor   #$FFFF
                    adc   #_LINES_PER_BANK*2         ; 120 - 40 = 80
                    cmp   :lines_left_x2             ; 200
                    bcs   :one_pass

                    tax                              ; Draw to the bottom of the bank -- draw 80 lines
                    jsr   :one_pass

                    lda   #{_LINES_PER_BANK-1}*2     ; Set the virtual line to the top of the next bank (0 or 120) = 119
                    cmp   :virt_line_x2              ; 40
                    lda   #0
                    bcc   *+5
                    lda   #{_LINES_PER_BANK*2}       ; 120
                    sta   :virt_line_x2

                    lda   :rtbl_idx_x2
                    clc
                    adc   :draw_count_x2
                    sta   :rtbl_idx_x2

                    lda   :lines_left_x2
                    sec
                    sbc   :draw_count_x2              ; This many left to draw
                    sta   :lines_left_x2
                    tax
                    cmp   #{_LINES_PER_BANK+1}*2      ; Can we finish?
                    bcc   :one_pass

                    ldx   #_LINES_PER_BANK*2          ; Nope, so do a full bank
                    jsr   :one_pass

                    lda   :virt_line_x2               ; At this point :vert_line_x2 is either 0 or _LINES_PER_BANK*2
                    eor   #{_LINES_PER_BANK*2}
                    sta   :virt_line_x2

                    lda   :rtbl_idx_x2
                    clc
                    adc   :draw_count_x2
                    sta   :rtbl_idx_x2

                    lda   :lines_left_x2              ; Set up the remainder
                    sec
                    sbc   :draw_count_x2
                    tax

; Set up the addresses for filling in the code field
:one_pass
                     stx   :draw_count_x2

                     phb                             ; Save the current bank

                     ldx   :virt_line_x2
                     lda   BTableLow,x                ; Get the address of the first code field line
                     tay
                     iny                              ; Fill in the first byte (_ENTRY_1 = 0)

                     sep   #$20                       ; Set the data bank to the code field
                     lda   BTableHigh,x
                     pha
                     plb
                     rep   #$21                       ; clear the carry while we're here...

                     ldx   :rtbl_idx_x2               ; Load the stack address from here

                     lda   :draw_count_x2             ; Do this many lines
                     asl                              ; x4
                     asl                              ; x8
                     asl                              ; x16
                     sec
                     sbc   :draw_count_x2             ; x14
                     lsr                              ; x7
                     eor   #$FFFF
                     sec
                     adc   #:bottom
                     stal  :entry+1                   ; patch in the dispatch address

; This is an inline, unrolled version of CopyRTableToStkAddr
:entry               jmp   $0000
]line                equ   119
                     lup   120
                     ldal  RTable+{]line*2},x
                     sta   {]line*_LINE_SIZE_V},y
]line                equ   ]line-1
                     --^
:bottom
copyr_bottom
;                     plb
                     rts

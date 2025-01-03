                  DO    NAMETABLE_MIRRORING&HORIZONTAL_MIRRORING
_Apply            equ   _ApplyHorzMirroring
                  ELSE
_Apply            equ   _ApplyVertMirroring
                  FIN

; Helper function that takes care of the bookkeeping of iterating over a range of virtual
; lines while taking into consideration the fact that the blitter code spans multiple
; banks.
;
; A = starting virtual line in the code field (0 - 239)
; X = number of lines to render (0 - 200)
; Y = address of callback routine
_ApplyVertMirroring
:virt_line          equ   tmp1
:lines_left         equ   tmp2

                    stx   :lines_left       ; See parallel code on line 305
                    sta   :virt_line
                    sty   :patch+1

; First step is to determine the starting bank.  It's a bit of calculation to figure out
; whether the update can be done in one pass, but after that it becomes easier until
; the last update.  For code size and efficiency, we build up the arguments on the stack
; and then unwind them at once.  This allows most of the calculations to keep their
; values in registers

                    cmp   #_LINES_PER_BANK
                    bcs   :start_in_bank_2

; The update is starting in the first code bank.

                    eor   #$FFFF
                    sec
                    adc   #_LINES_PER_BANK      ; how many lines from the starting point to the end of the bank?
                    cmp   :lines_left           ; is there enough to accomodate the number of lines to draw?
                    bcc   :split_bank_1         ; if not, break up the callback into multiple pieces

                    lda   :virt_line            ; restore the starting line.  :lines_left is still in the X register
                    bra   :patch                ; jump to the callback routine just once

; The region goes to the end of the first bank and then continues
:split_bank_1
                    tax                         ; this is the number of lines that can be drawn in the bank

                    eor   #$FFFF
                    sec
                    adc   :lines_left           ; calculate the number that will remain to be drawn in the second bank
                    sta   :lines_left

                    lda   :virt_line            ; restore the original virtual line number. x-reg is set above
                    jsr   :patch                ; call the subroutine

                    lda   #_LINES_PER_BANK      ; If the number of reamining lines is less than the lines in the
                    ldx   :lines_left           ; bank, we can be done now
                    cpx   #_LINES_PER_BANK+1
                    bcc   :patch

                    ldx   #_LINES_PER_BANK
                    jsr   :patch                ; Otherwise, apply against the full bank and come back to finish

                    lda   :lines_left
                    sec
                    sbc   #_LINES_PER_BANK
                    tax
                    lda   #0                    ; Now we're at the top of the first bank
                    bra   :patch
 
; The region is starting in the second bank.  Do the same thing as above, but the constants are
; a bit different
:start_in_bank_2
                    sbc   #_LINES_PER_BANK      ; Put the number into the range of one bank (carry is set)
                    eor   #$FFFF
                    sec
                    adc   #_LINES_PER_BANK      ; how many lines from the starting point to the end of the bank?
                    cmp   :lines_left           ; is there enough to accomodate the number of lines to draw?
                    bcc   :split_bank_2         ; if not, break up the callback into multiple pieces

                    lda   :virt_line            ; restore the starting line
                    bra   :patch                ; jump to the callback routine just once

; The region goes to the end of the second bank and then continues
:split_bank_2
                    tax                         ; this is the number of lines that can be drawn in the bank

                    eor   #$FFFF
                    sec
                    adc   :lines_left           ; calculate the number that will be draw in the first bank
                    sta   :lines_left

                    lda   :virt_line            ; restore the original virtual line number. x-reg is set above
                    jsr   :patch                ; call the subroutine

                    lda   #0                    ; If the number of reamining lines is less than the lines in the
                    ldx   :lines_left           ; bank, we can be done now
                    cpx   #_LINES_PER_BANK+1
                    bcc   :patch

                    ldx   #_LINES_PER_BANK
                    jsr   :patch                ; Otherwise, apply against the full bank and come back to finish

                    lda   :lines_left
                    sec
                    sbc   #_LINES_PER_BANK
                    tax
                    lda   #_LINES_PER_BANK      ; Now we're at the top of the second bank

:patch              jmp   $0000


; A = starting virtual line in the code field (0 - 479)
; X = number of lines to render (0 - 200)
; Y = address of callback routine
;
; This needs to be a bit more generalized that before.  Really, we don't need to care about the actual
; bank, it's just a matter of rouding to the nearest 120-line boundary.
_ApplyHorzMirroring
:virt_line          equ   tmp1
:lines_left         equ   tmp2

                    stx   :lines_left
                    sta   :virt_line
                    sty   :patch+1

; First, determine how many lines between the virtual line and the next bank boundary. If
; there are more lines availble than need to be drawn, it is an early out.

                    cmp   #_LINES_PER_BANK
                    bcc   :bank_1

                    cmp   #_LINES_PER_BANK*2
                    bcc   :bank_2

                    cmp   #_LINES_PER_BANK*3
                    bcc   :bank_3

                    eor   #$FFFF
                    adc   #{4*_LINES_PER_BANK} ; carry is set
                    cmp   :lines_left
                    bcc   :split_bank_4

                    lda   :virt_line            ; easy, all lines fit in this bank
                    brl   :patch

:split_bank_4
                    tax
                    eor   #$FFFF                ; Subtract from the number of lines remaining
                    sec
                    adc   :lines_left
                    sta   :lines_left

                    lda   :virt_line            ; set the virtual line number.
                    jsr   :patch                ; call the subroutine

                    lda   #_LINES_PER_BANK
                    cmp   :lines_left
                    bcc   :split_bank_4b

                    ldx   :lines_left
                    lda   #{0*_LINES_PER_BANK}
                    brl   :patch

:split_bank_4b
                    tax
                    lda   #{0*_LINES_PER_BANK}
                    jsr   :patch

                    sec
                    lda   :lines_left
                    sbc   #_LINES_PER_BANK
                    tax
                    lda   #{1*_LINES_PER_BANK}
                    brl   :patch

:bank_1             eor   #$FFFF
                    adc   #_LINES_PER_BANK+1    ; carry is clear and we want to add +1
                    cmp   :lines_left
                    bcc   :split_bank_1

                    lda   :virt_line            ; easy, all lines fit in this bank
                    brl   :patch

:bank_2             eor   #$FFFF
                    adc   #{2*_LINES_PER_BANK}+1
                    cmp   :lines_left
                    bcc   :split_bank_2

                    lda   :virt_line            ; easy, all lines fit in this bank
                    brl   :patch

:bank_3             eor   #$FFFF
                    adc   #{3*_LINES_PER_BANK}+1
                    cmp   :lines_left
                    bcc   :split_bank_3

                    lda   :virt_line            ; easy, all lines fit in this bank
                    brl   :patch

; At this point we know the number of lines_left is more than the space remaining in the bank.  The
; number of lines that can be drawn is in the accumulator and A > lines_left
; 
:split_bank_1
                    tax                         ; set the number of lines that will be drawn

; Subtract from the number of lines remaining

                    eor   #$FFFF
                    sec
                    adc   :lines_left
                    sta   :lines_left

; Call the worker with A = virtual line, X = number of lines

                    lda   :virt_line            ; set the virtual line number.
                    jsr   :patch                ; call the subroutine

; Advance to the next bank

                    lda   #_LINES_PER_BANK
                    cmp   :lines_left
                    bcc   :split_bank_1b

                    ldx   :lines_left
                    bra   :patch

:split_bank_1b
                    ldx   #_LINES_PER_BANK
                    jsr   :patch

; At this point, we know that this will be the last call.  A 200-line update can span, at most, three 120-line
; segments

                    sec
                    lda   :lines_left
                    sbc   #_LINES_PER_BANK
                    tax
                    lda   #{2*_LINES_PER_BANK}
                    bra   :patch

:split_bank_2
                    tax
                    eor   #$FFFF                ; Subtract from the number of lines remaining
                    sec
                    adc   :lines_left
                    sta   :lines_left

                    lda   :virt_line            ; set the virtual line number.
                    jsr   :patch                ; call the subroutine

                    lda   #_LINES_PER_BANK
                    cmp   :lines_left
                    bcc   :split_bank_2b

                    ldx   :lines_left
                    lda   #{2*_LINES_PER_BANK}
                    bra   :patch

:split_bank_2b
                    tax
                    lda   #{2*_LINES_PER_BANK}
                    jsr   :patch

                    sec
                    lda   :lines_left
                    sbc   #_LINES_PER_BANK
                    tax
                    lda   #{3*_LINES_PER_BANK}
                    bra   :patch

:split_bank_3
                    tax
                    eor   #$FFFF                ; Subtract from the number of lines remaining
                    sec
                    adc   :lines_left
                    sta   :lines_left

                    lda   :virt_line            ; set the virtual line number.
                    jsr   :patch                ; call the subroutine

                    lda   #_LINES_PER_BANK
                    cmp   :lines_left
                    bcc   :split_bank_3b

                    ldx   :lines_left
                    lda   #{3*_LINES_PER_BANK}
                    bra   :patch

:split_bank_3b
                    tax
                    lda   #{3*_LINES_PER_BANK}
                    jsr   :patch

                    sec
                    lda   :lines_left
                    sbc   #_LINES_PER_BANK
                    tax
                    lda   #{0*_LINES_PER_BANK}
                    bra   :patch

:patch              jmp   $0000


; Subroutines that deal with the horizontal scrolling in the blitter. These functions
; take in account the visible playfield and update the PEA fields in the two banks to
; set up the entry and exit points.
;
; A = starting virtual line in the code field (0 - 239)
; X = number of lines to render (0 - 200)
; Y = offset into the PEA field

_RestoreBG0OpcodesLite
;                    ldy   LastPatchOffset
                    lda   #0
                    ldx   ScreenHeight

_RestoreBG0OpcodesAltLite
:exit_addr          equ   tmp4                               ; only the botton 8-bits are valid

                    sty   :exit_addr

                    clc
                    adc   StartYMod240        ; Load the starting virtual line within the PEA renderer
                    cmp   MaxY
                    bcc   *+4
                    sbc   MaxY

                    ldy   #_RestoreBG0OpcodesCallback

                    jmp   _Apply

; This will get called with A, X set and guaranteed to be within a contiguous range
; of the blitter code.  This allows the data bank to be set once and then all of the
; bank manipulations done without worrying about changing the bank.
_RestoreBG0OpcodesCallback
:draw_count_x2      equ   tmp3
:exit_addr          equ   tmp4
:save_addr          equ   tmp5
:btable_low         equ   tmp6

                    phb

                    asl                               ; 2 x :virt_line
                    tay                               ; use to load the base address

                    lda   #_SAVE_OFFSET-1             ; Fixed location
                    sta   :save_addr

                    txa
                    asl
                    sta   :draw_count_x2              ; this is the number of lines we will do right now
                    asl
                    adc   :draw_count_x2              ; multiple by 6 to calculate the jump offset

                    eor   #$FFFF
                    sec
                    adc   #x2y_bottom
                    sta   :do_restore+1

                    sep   #$20
                    lda   BTableHigh,y               ; BTableHigh has the standard bank in the high word
                    pha                              ; Push two bytes
                    rep   #$21

                    lda   BTableLow,y                ; Get the address of the first code field line
                    and   #$FF00
                    sta   :btable_low
                    adc   :save_addr
                    tax

                    lda   :btable_low
                    adc   :exit_addr
                    tay

                    plb                              ; Pop one byte to set the bank to the code field
:do_restore         jsr   $0000                      ; Jump in and copy the saved patch value back into the code field, copy abs,X -> abs,Y

                    plb                              ; Restore the current bank
                    rts

; Copy from the offset at X to the offset at Y
;
; Y = code field offset
; X = value
CopyXToYPrep        mac
                    lda   #x2y_bottom
                    sbc   ]2                      ; count_x6
                    stal  ]1+1                    ; A jmp/jsr instruction
                    <<<
]line               equ   119                     ; A maximum of 120 lines per bank (2 x 120 = 240)
                    lup   120
                    lda:  {]line*_LINE_SIZE_V},x
                    sta:  {]line*_LINE_SIZE_V},y
]line               equ   ]line-1
                    --^
x2y_bottom          rts

; Set a constant 8-bit value across the code field
;
; Y = code field offset
LiteSetConstPrep    mac
                    lda   #lsc_bottom
                    sbc   ]2                      ; count_x3
                    stal  ]1+1                    ; A jmp/jsr instruction
                    <<<

]line               equ   119                     ; A maximum of 120 lines per bank (2 x 120 = 240)
                    lup   120
                    sta:  {]line*_LINE_SIZE_V},y
]line               equ   ]line-1
                    --^
lsc_bottom          rts

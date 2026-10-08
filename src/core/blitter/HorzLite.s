; Helper function that takes care of the bookkeeping of iterating over a range of virtual lines. The
; range is split into pieces that each lie within a single blitter bank and a single CIRAM page, and
; the callback is invoked once per piece so it can set the data bank once.
;
; Virtual lines 0 - 239 are the rows of CIRAM page 0.  With horizontal mirroring (MaxY = 480), virtual
; lines 240 - 479 are the rows of CIRAM page 1.  The range wraps around at MaxY.
;
; A = starting virtual line in the code field (0 - MaxY-1)
; X = number of lines to render (0 - 200)
; Y = address of callback routine
;
; The callback is called with
;
; A = physical row (0 - 239)
; X = number of lines (all within one bank)
; BltSegPage = $0000 or $0100, the offset of the CIRAM page within the row
                    mx    %00
_Apply
:virt_line          equ   tmp1
:lines_left         equ   tmp2

                    sty   :patch+1
                    sta   :virt_line
                    stx   :lines_left
                    beq   :done

:loop
                    ldy   #0                    ; Split the virtual line into a CIRAM page and physical row
                    cmp   #_LINES_PER_BANK*2
                    bcc   :page0
                    sbc   #_LINES_PER_BANK*2
                    ldy   #$0100
:page0              sty   BltSegPage
                    pha                         ; Save the physical row

                    cmp   #_LINES_PER_BANK      ; Calculate the number of lines to the end of the bank
                    bcc   *+5
                    sbc   #_LINES_PER_BANK
                    eor   #$FFFF
                    sec
                    adc   #_LINES_PER_BANK
                    cmp   :lines_left           ; Limit to the number of lines left to do
                    bcc   :partial
                    lda   :lines_left
:partial            tax                         ; This is the number of lines for this call

                    eor   #$FFFF                ; Update the loop state before calling the callback
                    sec
                    adc   :lines_left
                    sta   :lines_left

                    txa
                    clc
                    adc   :virt_line
                    cmp   MaxY
                    bcc   *+4
                    sbc   MaxY
                    sta   :virt_line

                    pla                         ; Restore the physical row
                    jsr   :patch

                    lda   :lines_left
                    beq   :done
                    lda   :virt_line
                    bra   :loop
:done               rts

:patch              jmp   $0000


; Subroutines that deal with the horizontal scrolling in the blitter. These functions
; take in account the visible playfield and update the PEA fields in the two banks to
; set up the entry and exit points.
;
; A = first playfield line (0 - 199)
; X = number of lines to render (0 - 200)
; Y = offset into the PEA field

; The renderers call these after drawing, but _BltSetupAlt leaves its exits patched until the PEA field
; needs to be stable (_PEAFieldStable), so there is nothing to do here.
_RestoreBG0OpcodesLite
_RestoreBG0OpcodesAltLite
                    rts

; Restore the exits of a range right away.  Only for exits patched outside of _BltSetupAlt's tracking
; (_BltSetupDirty).
_RestoreBG0OpcodesNowLite
                    lda   #0
                    ldx   ScreenHeight

_RestoreBG0OpcodesNowAltLite
:exit_addr          equ   tmp4                               ; row-relative exit offset returned by _BltSetup

                    sty   :exit_addr

                    clc
                    add_y_offset           ; Playfield line to NES scanline
                    adc   StartY              ; Load the starting virtual line within the PEA renderer
                    cmp   MaxY
                    bcc   *+4
                    sbc   MaxY

                    ldy   #_RestoreBG0OpcodesCallback
                    jmp   _Apply

; This will get called with A, X set and guaranteed to be within a contiguous range
; of the blitter code.  This allows the data bank to be set once and then all of the
; bank manipulations done without worrying about changing the bank.
;
; The saved PEA opcode and low operand byte in the even page are copied back over the BRA
; that was patched in the exit page.
_RestoreBG0OpcodesCallback
:draw_count_x2      equ   tmp3
:exit_addr          equ   tmp4
:btable_low         equ   tmp6

                    phb

                    asl                               ; 2 x :virt_line
                    tay                               ; use to load the base address

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
                    sta   :btable_low
                    adc   #_E_EXIT_OFFSET            ; The saved PEA opcode and operand
                    tax

                    lda   :btable_low
                    adc   BltSegPage                 ; The exit is in this CIRAM page
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
                    lda:  {]line*_LINE_SPAN},x
                    sta:  {]line*_LINE_SPAN},y
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
                    sta:  {]line*_LINE_SPAN},y
]line               equ   ]line-1
                    --^
lsc_bottom          rts

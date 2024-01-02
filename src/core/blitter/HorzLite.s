; Helper function that takes care of the bookkeeping of iterating over a range of virtual
; lines while taking into consideration the fact that the blitter code spans multiple
; banks.
;
; A = starting virtual line in the code field (0 - 239)
; X = number of lines to render (0 - 200)
; Y = address of callback routine
_Apply
:virt_line          equ   tmp1
:lines_left         equ   tmp2

                    sta   :virt_line
                    stx   :lines_left
                    sty   :patch+1

                    cmp   #120
                    bcs   :bank_2

; The region is starting in the first bank
:bank_1
                    eor   #$FFFF
                    sec
                    adc   #120                  ; how many lines from the starting point to the end of the bank?
                    cmp   :lines_left           ; is there enough to accomodate the number of lines to draw?
                    bcc   :split_bank_1         ; if not, break up the callback into multiple pieces

                    lda   :virt_line            ; restore the starting line
                    bra   :patch                ; jump to the callback routine just once

; The region goes to the end of the first bank and then continues
:split_bank_1
                    tax                         ; this is the number of lines that can be drawn in the bank

                    eor   #$FFFF
                    sec
                    adc   :lines_left           ; calculate the number that will be draw in the second bank
                    pha                         ; and save for the second call

                    lda   :virt_line            ; restore the original virtual line number. x-reg is set above
                    jsr   :patch                ; call the subroutine

                    lda   #120                  ; for the second bank, we know we're at the top
                    plx                         ; and have this many more lines to draw
                    bra   :patch

; The region is starting in the second bank.  Do the same thing as above, but the constants are
; a bit different
:bank_2
                    eor   #$FFFF
                    sec
                    adc   #240                  ; how many lines from the starting point to the end of the bank?
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
                    pha                         ; and save for the second call

                    lda   :virt_line            ; restore the original virtual line number. x-reg is set above
                    jsr   :patch                ; call the subroutine

                    lda   #0                    ; for the first bank, we know we're at the top
                    plx                         ; and have this many more lines to draw
:patch              jmp   $0000

; Subroutines that deal with the horizontal scrolling in the blitter. These functions
; take in account the visible playfield and update the PEA fields in the two banks to
; set up the entry and exit points.
;
; A = starting virtual line in the code field (0 - 239)
; X = number of lines to render (0 - 200)

_RestoreBG0OpcodesLite
                    ldy   #_RestoreBG0OpcodesCallback
                    jmp   _Apply

; This will get called with A, X set and guaranteed to be within a contiguous range
; of the blitter code.  This allows the data bank to be set once and then all of the
; bank manipulations done without worrying about changing the bank.
_RestoreBG0OpcodesCallback
:draw_count_x2      equ   tmp3

                    asl                              ; 2 x :virt_line
                    tay                              ; use to load the base address

                    txa
                    asl
                    sta   :draw_count_x2              ; this is the number of lines we will do right now
                    asl
                    adc   :draw_count_x2              ; multiple by 6 to calculate the jump offset

                    eor   #$FFFF
                    sec
                    adc   #x2y_bottom
                    sta   :do_restore+1

                    clc
                    lda   BTableLow,y                ; Get the address of the first code field line
                    adc   #_LOW_SAVE
                    tax                              ; address of the save location

                    lda   BTableHigh,y               ; BTableHigh has the standard bank in the high word
                    pha                              ; Push two bytes

                    lda   BTableLow,y
                    adc   LastPatchOffset            ; Add some offsets to get the base address in the code field line
                    tay

                    plb                              ; Pop one byte to set the bank to the code field
:do_restore         jsr   $0000                      ; Jump in and copy the saved patch value back into the code field, copy abs,X -> abs,Y

                    stz   LastPatchOffset            ; Clear the value once completed
                    plb                              ; Restore the current bank
                    rts

; Set up the entry point into each line of the blitter.  The starting point depends
; on which nametable is selected and the mirroring configuation.  Also, the fact
; that data is pushed onto the screen in reverse order means that the ordering can
; be a bit confusing.
;
; For example, assume that vertical mirroring is on and the current nametable is
; set to $2000 and the SCROLL register is set to 2 -- so that the rendered playfield
; will show 256 pixels with the rightmost word (2 bytes) coming from the PEA field
; corresponding to nametable $2400.

; This function is where the reverse-mapping aspect of the code field is compensated
; for.  In the initialize case where X = 0, the exit point is at the *end* of 
; the code buffer line
;
;      Nametable $2000                          Nametable $2400
; +----+----+ ... +----+----+----+      +----+----+ ... +----+----+----+
; | 62 | 60 |     | 04 | 02 | 00 |      | 62 | 60 |     | 04 | 02 | 00 | - JMP --+
; +----+----+ ... +----+----+----+      +----+----+ ... +----+----+----+         |
; ^                         ^exit                                 ^enter         |
; |                                                                              |
; +------------------------------------------------------------------------------+
;
; As the screen scrolls right-to-left, the exit position moves to earlier memory
; locations until wrapping around from 163 to 0.
;
; The net calculation are
;
;   x_exit = (164 - x) % 164
;   x_enter = (164 - x - width) % 164
;

_ApplyBG0XPosLite
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2

; If there are saved opcodes that have not been restored, do not run this routine
                    lda   LastPatchOffset
                    beq   *+3
                    rts

; This code is fairly succinct.  See the corresponding code in Vert.s for more detailed comments.

                    lda   StartYMod240               ; This is the base line of the virtual screen
                    asl
                    sta   :virt_line_x2              ; Keep track of it

                    lda   ScreenHeight
                    asl
                    sta   :lines_left_x2

; Calculate the exit and entry offsets into the code fields.
;
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;       | 04 | 06 | 08 | 0A | 0C |       | 44 | 46 | 48 | 4A |
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;                 |                                |
;                 +---- screen width --------------+
;           entry |                                | exit
;
; Here is an example of a screen 64 bytes wide. When everything is aligned to an even offset
; then the entry point is column $08 and the exit point is column $48
;
; If we move the screen forward one byte (which means the pointers move backwards) then the low-byte
; of column $06 will be on the right edge of the screen and the high-byte of column $46 will left-edge
; of the screen. Since the one-byte edges are handled specially, the exit point shifts one column, but
; the entry point does not.
;
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;       | 04 | 06 | 08 | 0A | 0C |       | 44 | 46 | 48 | 4A |
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;              |  |                           |  |
;              +--|------ screen width -------|--+
;           entry |                           | exit
;
; When the screen is moved one more byte forward, then the entry point will move to the 
; next column.
;
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;       | 04 | 06 | 08 | 0A | 0C |       | 44 | 46 | 48 | 4A |
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;            |                                |
;            +------ screen width ------------+
;      entry |                                | exit
;
; So, in short, the entry position is rounded up from the x-position and the exit
; position is rounded down.
;
; Now, the left edge of the screen is pushed last, so we need to exit one instruction *after*
; the location
;
; x = 0
;
;  | PEA $0000 |
;  +-----------+
;  | PEA $0000 | 
;  +-----------+ 
;  | JMP loop  | <-- Exit here
;  +-----------+
;
; x = 1 and 2
;
;  | PEA $0000 |
;  +-----------+
;  | PEA $0000 | <-- Exit Here
;  +-----------+ 
;  | JMP loop  |
;  +-----------+

                    lda   StartXMod256     ; For vertical mirroring, x can range from [0, 255]. For horizontal, x is [0, 127]

; Alternate entry point if the virt_line_x2 and lines_left_x2 and XMod256 values are passed in externally

_ApplyBG0XPosAltLite
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:draw_count_x2      equ   tmp3
:exit_offset        equ   tmp4
:entry_offset       equ   tmp5
:exit_bra           equ   tmp6
:exit_address       equ   tmp7
:base_address       equ   tmp8
:opcode             equ   tmp9
:odd_entry_offset   equ   tmp10
:draw_count_x3      equ   blttmp                     ; steal even more direct page temp space...
:draw_count_x6      equ   blttmp+2
:entry_jmp_addr     equ   blttmp+4
:low_save_addr      equ   blttmp+6
:draw_count_x3      equ   blttmp+8
:draw_count_x6      equ   blttmp+10
:entry_odd_addr     equ   blttmp+12
:exit_odd_addr      equ   blttmp+14

                    bit   #$0001

                    beq   *+5
                    jmp   :odd_case                  ; Specialized routines for even/odd cases

; We are blitting an aligned range of words, so we will need to exit at the instruction immediately after the
; instruction that corresponds to the left edge of the screen

                    tax
                    lda   CodeFieldEvenBRA-2,x
                    sta   :exit_bra

                    lda   Col2CodeOffset-2,x         ; offset from :base that is the exit location
                    sta   :exit_offset
                    sta   LastPatchOffset            ; Cache as a flag for later

; Calculate the entry point into the code field by calculating the right edge

                    txa                              ; lda StartXMod256
                    clc
                    adc   ScreenWidth                ; move to the right edge (always 128 bytes)
                    and   #255                       ; Keep the value in range

; Lookup the relative offset that we will be entering the code field.  The entry happens _on_ the instruction,
; so subtract one column to adjust for the width

                    tax
                    lda   Col2CodeOffset-2,x         ; offset from base
                    clc
                    adc   #-{_ENTRY_JMP+3}
                    sta   :opcode                    ; while accounting for the col2code offset value

; Now update the code field to get ready to execute. We set the bank register to the code
; field to make updates faster.  The primary actions to do are.
;
; 1. Saves the low operand byte in the code field (opcode is always $F4)
; 2. Writes the BRA instruction to exit the code field
; 3. Writes the JMP entry point to enter the code field
;
; This code is set up to efficiently set up a single top-to-bottom block of lines.  Since each bank holds 120
; lines and the screen size can be up to 200 lines, the worst case is to fill one full bank of 120 lines and have
; some amount left over in the top and bottom of the other bank.
;
; There is a small bit of code to decompose the sections and then call the fast code to fill in the ranges.

; First, find out how many lines exist from the current virtual line to the end of the code buffer
; This is (lines_per_bank - virt_line % lines_per_bank)

                    ldx   :lines_left_x2
                    lda   :virt_line_x2
                    cmp   #_LINES_PER_BANK*2
                    bcc   *+5
                    sbc   #_LINES_PER_BANK*2
                    sec
                    eor   #$FFFF
                    adc   #_LINES_PER_BANK*2
                    cmp   :lines_left_x2
                    bcs   :one_pass_even             ; There are enough lines in the bank to draw the remaining lines

                    tax                              ; Draw to the bottom of the bank
                    jsr   :one_pass_even

                    lda   #{_LINES_PER_BANK-1}*2         ; Set the virtual line to the top of the next bank (0 or 120)
                    cmp   :virt_line_x2
                    lda   #0
                    bcc   *+5
                    lda   #{_LINES_PER_BANK*2}
                    sta   :virt_line_x2

                    lda   :lines_left_x2
                    sec
                    sbc   :draw_count_x2              ; This many left to draw
                    tax
                    cmp   #{_LINES_PER_BANK+1}*2      ; Can we finish?
                    bcc   :one_pass_even

                    jsr   :one_pass_even

                    lda   :virt_line_x2               ; At this point :vert_line_x2 is either 0 or _LINES_PER_BANK*2
                    eor   #{_LINES_PER_BANK*2}
                    sta   :virt_line_x2

                    lda   :lines_left_x2              ; Set up the remainder
                    sec
                    sbc   :draw_count_x2
                    tax

:one_pass_even
                    txa
                    sta   :draw_count_x2              ; this is the number of lines we will do right now
                    asl
                    adc   :draw_count_x2
                    sta   :draw_count_x6
                    lsr
                    sta   :draw_count_x3

                    phb                              ; Save the existing bank

                    ldx   :virt_line_x2
                    sep   #$20                       ; Set the data bank to the code field
                    lda   BTableHigh,x
                    pha
                    plb
                    rep   #$21                       ; clear the carry while we're here...

                    ldal  BTableLow,x                ; Get the address of the code field line
                    sta   :base_address              ; Will use this address a few times

                    adc   #_ENTRY_JMP                ; Add the offsets in order to get absolute addresses
                    sta   :entry_jmp_addr
                    adc   #{_LOW_SAVE-_ENTRY_JMP}
                    sta   :low_save_addr

                    lda   :base_address
                    adc   :exit_offset               ; Add the offset to get the absolute address in the code field line
                    sta   :exit_address

; First step is to set the BRA instruction to exit the code field at the proper location.  There
; are two sub-steps to do here; we need to save the 8-bit value that exists at the location+1 and
; then overwrite it with the branch instruction.

                    sec                              ; These macros perform subtractions that do not underflow
                    CopyXToYPrep      :do_save_entry_e;:draw_count_x6
                    LiteSetConstPrep  :do_set_bra_e;:draw_count_x3
                    stal  :do_setopcode_e+1
                    stal  :do_set_rel_e+1

                    sep   #$20
                    ldy   :entry_jmp_addr
                    lda   #$82
:do_setopcode_e     jsr   $0000                       ; Copy in the BRL opcode into the entry point

                    ldx   :exit_address
                    inx
                    ldy   :low_save_addr
                    iny
:do_save_entry_e    jsr   $0000                       ; Copy a byte from offset x to y
                    rep   #$20

                    ldy   :exit_address
                    lda   :exit_bra
:do_set_bra_e       jsr   $0000                       ; Set the BRA instruction in the code field to exit

                    ldy   :entry_jmp_addr
                    iny
                    lda   :opcode
:do_set_rel_e       jsr   $0000                       ; Set the relative offset for all BRL instructions

                    plb
                    rts

; Odd case if very close to the even case, except that the code is entered a word later.  It is still
; exited at the same word.  There is extra work done because we have to save the third byte of the 
; exit location to fill in the left edge and we have to patch a different BRL to enter the code field
; afte the right-edge byte is pushed onto the screen 
:odd_case
                    dec
                    tax
                    lda   CodeFieldOddBRA,x
                    sta   :exit_bra

                    lda   Col2CodeOffset,x
                    sta   :exit_offset
                    sta   LastPatchOffset            ; Cache as a flag for later

                    txa                              ; StartXMod164 - 1
                    clc
                    adc   ScreenWidth

                    and   #255                       ; Keep the value in range

                    tax
                    lda   Col2CodeOffset,x
                    clc
                    adc   #-{_ENTRY_JMP+3}        ; In this case it gets loaded in the X-register
                    sta   :opcode

                    lda   Col2CodeOffset-2,x
                    clc
                    adc   #-{_ENTRY_ODD+3}
                    sta   :odd_entry_offset

; Main loop

                    ldx   :lines_left_x2
                    lda   #208*2
                    sec
                    sbc   :virt_line_x2              ; calculate number of lines to the end of the buffer
                    cmp   :lines_left_x2
                    bcs   :one_pass_odd             ; if there's room, do it in one shot

                    tax
                    jsr   :one_pass_odd

                    stz   :virt_line_x2

                    lda   :lines_left_x2
                    sec
                    sbc   :draw_count_x2              ; this many left to draw. Fall through to finish up
                    tax

:one_pass_odd
                    txa
                    sta   :draw_count_x2              ; this is the number of lines we will do right now
                    asl
                    adc   :draw_count_x2
                    sta   :draw_count_x6
                    lsr
                    sta   :draw_count_x3

                    phb                              ; Save the existing bank

                    sep   #$20
                    lda   BTableHigh                 ; Get the bank
                    pha
                    plb
                    rep   #$21

                    ldx   :virt_line_x2
                    ldal  BTableLow,x                ; Get the address of the first code field line
                    sta   :base_address              ; Save it to use as the base address

                    adc   #_ENTRY_JMP                ; Add the offsets in order to get absolute addresses
                    sta   :entry_jmp_addr
                    adc   #{_ENTRY_ODD-_ENTRY_JMP}
                    sta   :entry_odd_addr
                    adc   #{_EXIT_ODD-_ENTRY_ODD}
                    sta   :exit_odd_addr
                    adc   #{_LOW_SAVE-_EXIT_ODD}
                    sta   :low_save_addr

                    lda   :base_address
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line
                    sta   :exit_address

; Setup the jumps into the unrolled loops

                    sec
                    CopyXToYPrep      :do_save_entry_o;:draw_count_x6
                    stal  :do_save_high_byte+1
                    LiteSetConstPrep  :do_set_bra_o;:draw_count_x3
                    stal  :do_setopcode_o+1
                    stal  :do_set_rel_o+1
                    stal  :do_odd_code_entry+1

                    sep   #$20
                    ldy   :entry_jmp_addr
                    lda   #$A2
:do_setopcode_o     jsr   $0000                      ; Copy in the LDX opcode into the entry point

                    ldx   :exit_address
                    inx
                    inx
                    ldy   :exit_odd_addr
                    iny
:do_save_high_byte  jsr   $0000                      ; Copy high byte of the exit location into the odd handling path

                    ldx   :exit_address
                    inx
                    ldy   :low_save_addr
                    iny
:do_save_entry_o    jsr   $0000                      ; Save the low byte of the exit operand into a save location for restore later
                    rep   #$20

                    ldy   :exit_address
                    lda   :exit_bra
:do_set_bra_o       jsr   $0000                      ; Insert a BRA instruction over the saved word

                    ldy   :entry_jmp_addr
                    iny
                    lda   :opcode                    ; Store the same relative address to use for loading the entry word data
:do_set_rel_o       jsr   $0000

; The odd case need to do a bit of extra work

                    ldy   :entry_odd_addr
                    iny
                    lda   :odd_entry_offset
:do_odd_code_entry  jsr   $0000                          ; Fill in the BRL argument for the odd entry

                    plb
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
                    lda:  {]line*_LINE_SIZE},x
                    sta:  {]line*_LINE_SIZE},y
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
                    sta:  {]line*_LINE_SIZE},y
]line               equ   ]line-1
                    --^
lsc_bottom          rts

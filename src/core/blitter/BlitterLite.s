; This is the method that is most useful from the high-level code.  We want the
; freedom to blit a range of lines.  This subroutine can assume that all of the
; data in the code fields is set up properly.
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200

; This should only be called from _Render when it is determined to be safe
                mx    %00

_BltRangeLite
:exit_ptr       equ   tmp0
:jmp_low_save   equ   tmp2

                sty   tmp0           ; Range check
                cpx   tmp0
                bcc   *+3
                rts

                lda   GTEControlBits
                bit   #CTRL_EVEN_RENDER
                beq   :normal

                txa
                inc
                and   #$FFFE
                tax
                stx   tmp0

                tya                         ; Examples:
                dec                         ;   (0, 200) -> (0, 199)
                and   #$FFFE                ;   (1, 100) -> (2, 99)
                inc                         ;   (1, 99)  -> (2, 99)
                tay

; If the original X was odd and Y = X+1, then the values are reversed and we can skip

                cpy   tmp0
                bcs   *+3
                rts

:normal
;                lda   GTEControlBits 
;                bit   #CTRL_BKGND_ENABLE
;                bne   *+5
;                brl   :no_background

                clc
                dey
                tya                  ; Get the address of the line that we want to return from
                adc   StartYMod240   ; and create a pointer to it
                cmp   MaxY           ; There are this many addresses
                bcc   *+4
                sbc   MaxY
                asl
                tay
                lda   BTableLow,y    ; The blitter code spans two banks, so need to use long indirect addressing
                sta   :exit_ptr
                lda   BTableHigh,y
                sta   :exit_ptr+2

; Save and patch the exit instructions

                ldy   #{_E_EXIT_OFFSET-_ENTRY_OFFSET+1}    ; this is a JMP/JML instruction that points to the next line.
                lda   [:exit_ptr],y       ; we have to save because not every line points to the same
                sta   :jmp_low_save       ; position in the next code line

                lda   #0                  ; long return jump in always at the start of the
                sta   [:exit_ptr],y       ; patch out the address of the JMP
                ldy   #{_O_EXIT_OFFSET-_ENTRY_OFFSET+1}
                sta   [:exit_ptr],y

                phb                       ; save the current bank
                php                       ; save interrupt state (and M/X bits)

; Now do the entry point

                txa                  ; get the first line (0 - 239)
                adc   StartYMod240   ; add in the virtual offset -- max value of 478
                cmp   MaxY
                bcc   *+4
                sbc   MaxY
                asl
                tax                  ; this is the offset into the blitter table

                lda   BTableLow,x    ; patch in the address
                sta   blt_entry_lite+1

                sep   #$20
                lda   BTableHigh,x
                sta   blt_entry_lite+3
                pha

; Set the environment for the blitter and dispatch

                plb                       ; set bank to PEA fields -- can be removed if we tweak the save/restore
                sei                       ; disable interrupts
                tsx                       ; save the stack pointer in Y
                stx   STK_SAVE            ; write to direct page before changing the softswitch

                lda   STATE_REG_BLIT
                stal  STATE_REG

blt_entry_lite  jml   lite_base_1         ; Jump into the blitter code $ZZ/YYXX (Does not modify Y or X)

blt_return_lite ENT
                lda   STATE_REG_R0W0      ; This is ok for both 8-bit and 16-bit
                stal  STATE_REG
                ldx   STK_SAVE
                txs                       ; restore the stack
                plp                       ; re-enable interrupts (maybe, if interrupts disabled when we are called, they are not re-enabled)
                plb                       ; restore the bank

:exit_ptr       equ   tmp0
:jmp_low_save   equ   tmp2
                mx    %00

; Restore the exit code in the blitter

                ldy   #{_E_EXIT_OFFSET-_ENTRY_OFFSET+1}
                lda   :jmp_low_save
                sta   [:exit_ptr],y
                ldy   #{_O_EXIT_OFFSET-_ENTRY_OFFSET+1}
                sta   [:exit_ptr],y

                rts

; Special mode to use when the background is disabled.  Just slam a bunch of $0000 values
;
; This is simpler because X and Y are logical values.  Because we're not invoking the PEA
; table, there is no need to offset by the StartYMod240 value
:no_background
                bit   #CTRL_EVEN_RENDER     ; Need to check this again -- X and Y are already set correctly, though
                bne   :even_only
                lda   #2
                bra   *+5
:even_only      lda   #4

                sta   tmp1                  ; Increment for Y

; Calculate the index of the first physical line in the

                tya
                asl
                sta   tmp0                ; Loop end

                txa
                asl
                tay                       ; Use Y for the loop counter

                tsc
                dec
                sta   :patch+1            ; save the stack once (compensate for the PHP below)

:no_bg_loop
                sep   #$20                ; 8-bit mode
                php                       ; save the current processor flags
                ldx   RTable,y            ; This is the right edge

                sei                       ; disable interrupts
                lda   STATE_REG_BLIT
                stal  STATE_REG           ; Write to Bank $01
                txs                       ; set the stack to the right edge

                ldx   #0                  ; Blank out the line (16-bit pushes)
                lup   64
                phx
                --^

                lda   STATE_REG_R0W0
                stal  STATE_REG
:patch          ldx   #0000               ; stack save
                txs                       ; restore the stack
                plp                       ; re-enable interrupts
                rep   #$21                ; 16-bit and clear carry

                tya
                adc   tmp1
                tay
                cpy   tmp0
                bcc   :no_bg_loop

                rts

; Helper routine that takes the horizontal and vertical scoll coordinated in the X and Y registers
; and sets up the appropriate engine values.  
;
; The range of values is 0 - 511 for both X and Y.  This routine applies the mirroring masks and
; adjusts the Y value to map onto the valid range of 0 - 479 renderable lines.
NES_SetScrollX
                txa
                and   MirrorMaskX
                lsr
                sta   StartXMod256
                rts

NES_SetScroll   jsr   NES_SetScrollX      ; Call and then fall trough to NES_SetScrollY

NES_SetScrollY
                tya
                and   MirrorMaskY
                asl                       ; Lookup the correct virtual line
                tay
                lda   NES2Virtual,y
 
                clc
                adc   #y_offset           ; Shift down by the viewport offset
                cmp   MaxY
                bcc   *+4
                sbc   MaxY

                sta   StartYMod240

                
                txa
                and   MirrorMaskX
                lsr
                sta   StartXMod256

                tya
                and   MirrorMaskY
                asl                       ; Lookup the correct virtual line
                tay
                lda   NES2Virtual,y
 
                clc
                adc   #y_offset           ; Shift down by the viewport offset
                cmp   MaxY
                bcc   *+4
                sbc   MaxY

                sta   StartYMod240

                rts

; This is a rewrite of a routing that uses the NES scroll position + mirroring information to calculate
; the vertical and horizontal patch information to render the full screen.
;
; Changes from the old routine
;
;  1. Use single-byte patches and change BRL to JMP instructions (saves 1 cycle)
;  2. Bank register set to PEA field (allow referencing local patch data)
;  3. Unified odd/even exit code path (both load and push an extra value)
;  4. Entry and exit patching is done separately
;     a. This allows both horizontal and vertical mirroring to be handled uniformly
;     b. All calculations and patches are limited to a single page of memory (supports item (1))
_BltSetup
               ldy   StartXMod256
               lda   #0
               ldx   ScreenHeight

_BltSetupAlt

; tmp1 and tmp2 are used by the _Apply helper methods

:num_lines     equ tmp3
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:opcode        equ tmp6
:save_addr     equ tmp7
:entry_addr    equ tmp8
:draw_count_x2 equ tmp9
:virt_start    equ tmp10
:rtbl_idx_x2   equ tmp11
:odd_addr      equ tmp12
:odd_opcode    equ tmp13

; A = first virtual line
; X = number of lines
; Y = horizontal offset

                asl
                sta   :rtbl_idx_x2        ; Relative location on the screen to draw
                lsr

                adc   StartYMod240        ; Load the starting virtual line within the PEA renderer
                cmp   MaxY
                bcc   *+4
                sbc   MaxY

                sta   :virt_start
                stx   :num_lines
                tya                       ; Put the offset in the accumulator

; Calculate where the horizontal entry and exit points are. The IIgs graphic screen has 2 pixels per byte,
; so the effective horizontal resolution is half the NES value.
;
; We need to know which PEA line the blit will start and end in.  The rules are different for horzontal and
; vertical mirroring.
;
; For horizontal mirroring, every blitted line is limited to a single PEA line, so eveything stays within
; the same page that the BTableLow address points to and all of the offsets are just one byte.
;
; For vertical mirroring, the blitted line can, and often does, span the two adjacent PEA lines.
;
;        entry   exit
; word
;    0       0      0
;    1       1      0
;   ...
;   63       1      0
;   64       1      1
;   65       0      1
;   ...
;  127       0      1


;                lda   StartXMod256        ; This is the value in bytes
                bit   #$0001              ; Check if the starting byte value is even or odd
                beq   :blt_even
                brl   :blt_odd

; At this point the accumulator has the left edge coordinate in bytes (0 - 255) and we know it's an even
; number.  The high bit will tell us which page the starting coordinate is on, because the value can only be
; >= 128 in vertical mirroring mode when adjacent PEA field lines are used for rendering.
:blt_even
                and   #$00FE              ; LSB is already zero, this just converts to words
                tax                       ; look up the page offset for the left-edge word

                lda   Col2PageOffset,x    ; this is the offset that control will exit from
                sta   :exit_addr          ; This will be a 16-bit value later, but put the low byte in for now

                lda   CodeFieldEvenBRA,x  ; This is the instruction that will be patched into
                sta   :exit_bra           ; each line

                lda   Col2CodeOffset-2,x  ; The entry point is always 63 words later (-1 with wrap-around)
                clc
                adc   #{_PEA_OFFSET-_ENTRY_PATCH-3}
                sta   :opcode             ; Convert to a relative branch

                lda   #_ENTRY_PATCH+1     ; Fixed location
                sta   :entry_addr

                lda   #_SAVE_OFFSET       ; Fixed location
                sta   :save_addr

; Now, the constant values used to patch the PEA field are set.  Next, the vertical loop is performed
; to set the values in the contiguous ranges of lines within each bank.
;
; The vertical bit is more complicated.  Use a table lookup to find the starting line because the
; screen is only 240 line tall, but the coordinate could be >240.  In that case the real NES hardware
; draws the attribute area as tiles, but does _not_ advance to the next nametable when the line becomes
; greater than 255.  We do not support rendering the attribute bytes because there are only 240 lines
; in the PEA field. So, instead the lookup table will map to an appropriate line such that the non-attribute
; lines appear correct.

                lda   :virt_start
                ldx   :num_lines
                ldy   #_SetupStack
                jsr   _Apply

                lda   :virt_start
                ldx   :num_lines
                ldy   #_SetupPEAFieldLinesEven
                jsr   _Apply              ; Handle the interations through the code fields (the accumulator from here is returned)
                rts

; The odd case is very close to the even case, with the following differences
;
; 1. The JMP entry instruction is changed to a LDX (but the address is the same as the even case)
; 2. The odd entry address needs to be set to the work that _follows_ the address in (1)
; 3. The exit address is exactly the same
:blt_odd
                and   #$00FE              ; LSB is one, this zeros out the LSB and MSB and converts to words
                tax

                lda   Col2PageOffset,x    ; Exit at the same word as the even case
                sta   :exit_addr

                lda   CodeFieldOddBRA,x   ; This is the instruction that will be patched into
                sta   :exit_bra           ; each line

; For horizontal mirroring where only a single PEA line is executed, the patched instruction
; represents both the start and end of the line.  The low byte is the right edge of the screen
; and the high byte is the left edge.  Therefore, the entry code need to load the data byte from
; the save space

                lda   #_ENTRY_PATCH+1      ; Fixed location
                sta   :entry_addr

                lda   #_SAVE_OFFSET       ; Fixed location
                sta   :save_addr

                lda   #_ODD_PATCH+1
                sta   :odd_addr

                stz   :opcode             ; First BRL continues execution

                lda   Col2CodeOffset-2,x  ; The entry point is always 63 words later (-1 with wrap-around)
                clc
                adc   #{_PEA_OFFSET-_ODD_PATCH-3}
                sta   :odd_opcode         ; Convert to a relative branch

                lda   :virt_start
                ldx   :num_lines          ; Set up for a full screen
                ldy   #_SetupStack
                jsr   _Apply

                lda   :virt_start
                ldx   :num_lines
                ldy   #_SetupPEAFieldLinesOdd
                jsr   _Apply              ; Handle the interations through the code fields (the accumulator from here is returned)
                rts

_SetupStack
:draw_count_x2 equ tmp9
:virt_start    equ tmp10
:rtbl_idx_x2   equ tmp11
:odd_addr      equ tmp12
:odd_opcode    equ tmp13
:draw_count_x1 equ tmp14

                phb

                asl                              ; 2 x :virt_line
                tay                              ; use to load the base address

                txa
                sta   :draw_count_x1
                asl
                sta   :draw_count_x2
                asl
                asl
                sec
                sbc   :draw_count_x1
                eor   #$FFFF
;                sec                             ; carry is already set
                adc   #copyr_bottom
                sta   :entry+1                   ; patch in the dispatch address

                ldx   BTableLow,y                ; Get the address of the first code field line
                inx                              ; Fill in the first byte (_ENTRY_1 = 0)

                sep   #$20                       ; Set the data bank to the code field
                lda   BTableHigh,y
                pha
                plb
                rep   #$21                       ; clear the carry while we're here...

                txy
                ldx   :rtbl_idx_x2               ; Load the stack address from here
:entry          jsr   $0000                      ; Perform the copy

                txa
                clc
                adc   :draw_count_x2
                sta   :rtbl_idx_x2

                plb
                rts

_SetupPEAFieldLinesEven
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:opcode        equ tmp6
:save_addr     equ tmp7
:entry_addr    equ tmp8
:draw_count_x2 equ tmp9

                phb

                asl                              ; 2 x :virt_line
                tay                              ; use to load the base address

                txa
                asl
                sta   :draw_count_x2              ; this is the number of lines we will do right now
                asl
                adc   :draw_count_x2              ; multiple by 6 to calculate the jump offset
                tax                               ; save for a moment

                eor   #$FFFF
                sec
                adc   #x2y_bottom
                sta   :save_operand+1             ; patch for saving the PEA instruction

                txa
                lsr
                eor   #$FFFF
                sec
                adc   #lsc_bottom
                sta   :set_bra+1                  ; patch for inserting the BRA instruction and entry jmp opcode
                sta   :set_opcode+1

; Setup all of the copy routines

                sep   #$20
                lda   BTableHigh,y                ; Get the bank for this range of PEA field lines
                pha

                lda   BTableLow+1,y               ; Get the just the page of the code field
                sta   :exit_addr+1
                sta   :save_addr+1
                sta   :entry_addr+1
                rep   #$21

; Perform all of the intra-bank copies

                plb                       ; Set the data bank to the target PEA field range

                ldx   :exit_addr          ; This is the 16-bit address where the first BRA opcode is patched in
                inx                       ; We are saving the PEA operand
                ldy   :save_addr          ; This is location where the 16-bit PEA operand is saved
:save_operand   jsr   $0000

                ldy   :entry_addr         ; Set the BRL operand to enter the even-aligned opcode
                lda   :opcode             ; Set the same constant value in every line
:set_opcode     jsr   $0000

                ldy   :exit_addr          ; Set the BRA instruction in the code field to exit
                lda   :exit_bra           ; The same constant value is set for all lines
:set_bra        jsr   $0000

                plb                       ; Restore the data bank
                lda   :exit_addr          ; Return the calculated exit address to be used for restore
                rts


_SetupPEAFieldLinesOdd
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:opcode        equ tmp6
:save_addr     equ tmp7
:entry_addr    equ tmp8
:draw_count_x2 equ tmp9
:virt_start    equ tmp10
:rtbl_idx_x2   equ tmp11
:odd_addr      equ tmp12
:odd_opcode    equ tmp13

                phb

                asl                              ; 2 x :virt_line
                tay                              ; use to load the base address

                txa
                asl
                sta   :draw_count_x2              ; this is the number of lines we will do right now
                asl
                adc   :draw_count_x2              ; multiple by 6 to calculate the jump offset
                tax                               ; save for a moment

                eor   #$FFFF
                sec
                adc   #x2y_bottom
                sta   :save_operand+1             ; patch for saving the PEA instruction

                txa
                lsr
                eor   #$FFFF
                sec
                adc   #lsc_bottom
                sta   :set_bra+1                  ; patch for inserting the BRA instruction and entry jmp opcode
                sta   :set_opcode+1
                sta   :set_odd+1

; Setup all of the copy routines

                sep   #$20
                lda   BTableHigh,y                ; Get the bank for this range of PEA field lines
                pha

                lda   BTableLow+1,y               ; Get the just the page of the code field
                sta   :exit_addr+1
                sta   :save_addr+1
                sta   :entry_addr+1
                sta   :odd_addr+1
                rep   #$21

; Perform all of the intra-bank copies

                plb                       ; Set the data bank to the target PEA field range

                ldx   :exit_addr          ; This is the 16-bit address where the BRA opcode is patched in (this is off by one word $DC vs $DF)
                inx                       ; We are saving the PEA operand
                ldy   :save_addr          ; This is location where the 16-bit PEA operand is saved
:save_operand   jsr   $0000

                ldy   :entry_addr         ; Set the BRL operand to zero to enter the odd-aligned code path
                lda   :opcode             ; Set the same constant value in every line
:set_opcode     jsr   $0000

                ldy   :exit_addr          ; Set the BRA instruction in the code field to exit
                lda   :exit_bra           ; The same constant value is set for all lines
:set_bra        jsr   $0000

                ldy   :odd_addr
                lda   :odd_opcode         ; Set the BRL operand to jump into the PEA field
:set_odd        jsr   $0000

                plb                       ; Restore the data bank
                lda   :exit_addr          ; Return the calculated exit address to be used for restore
                rts

; This is the method that is most useful from the high-level code.  We want the
; freedom to blit a range of lines.  This subroutine can assume that all of the
; data in the code fields is set up properly.
;
; X = first line (inclusive), valid range of 0 to 239
; Y = last line  (exclusive), valid range >X up to 240

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
                asl
                tay
                lda   BTableLow,y    ; The blitter code spans two banks, so need to use long indirect addressing
                sta   :exit_ptr
;                lda   BTableHigh,y
;                sta   :exit_ptr+2

                txa                  ; get the first line (0 - 239)
                adc   StartYMod240   ; add in the virtual offset (0, 239) -- max value of 478
                asl
                tax                  ; this is the offset into the blitter table

;                lda   BTableHigh-1,x
;                sta   blt_entry_lite+2
                lda   BTableLow,x    ; patch in the address
                sta   blt_entry_lite+1

                sep   #$20
                lda   BTableHigh,y
                sta   :exit_ptr+2
                lda   BTableHigh,x
                sta   blt_entry_lite+3
                phb                  ; save the current bank
                pha
                rep   #$20

; The way we patch the exit code is subtle, but very fast.  The CODE_EXIT offset points to
; an JMP/JML instruction that transitions to the next line after all of the code has been
; executed.
;
; The trick we use is to patch the low word to force the code to jump to a special return
; function (jml blt_return) in the *next* code field line.

;                ldy   #_EXIT_EVEN+1       ; this is a JMP/JML instruction that points to the next line.
                ldy   #{_EXIT_OFFSET-_ENTRY_OFFSET+1}
                lda   [:exit_ptr],y       ; we have to save because not every line points to the same
                sta   :jmp_low_save       ; position in the next code line

;                lda   #lite_full_return   ; this is the address of the return code
                lda   #0                  ; long return jump in always at the start of the
                sta   [:exit_ptr],y       ; patch out the address of the JMP

                plb                       ; set bank to PEA fields -- can be removed if we tweak the save/restore
                php                       ; save the current processor flags

;                sep   #$20                ; run the lite blitter in 8-bit accumulator mode for odd-alignment, 16-bit for even
                ldy   #0                   ; Y = 0 for even alignment, Y = 1 for odd.

;                lda   :exit_ptr+2         ; set the bank to the code field
;                pha
;                plb

                sei                       ; disable interrupts
                tsx                       ; save the stack pointer in Y
;                txy
                stx   STK_SAVE            ; write to direct page before changing the softswitch

                lda   STATE_REG_BLIT
                stal  STATE_REG

blt_entry_lite  jml   lite_base_1         ; Jump into the blitter code $ZZ/YYXX (Does not modify Y or X)

blt_return_lite ENT
                lda   STATE_REG_R0W0
                stal  STATE_REG
                ldx   STK_SAVE
                txs                       ; restore the stack
                plp                       ; re-enable interrupts (maybe, if interrupts disabled when we are called, they are not re-enabled)
                plb                       ; restore the bank

:exit_ptr       equ   tmp0
:jmp_low_save   equ   tmp2
                mx    %00

;                ldy   #_EXIT_EVEN+1
                ldy   #{_EXIT_OFFSET-_ENTRY_OFFSET+1}
                lda   :jmp_low_save
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
;     b. All calculations and patching are limited to a single page of memory (supports item (1))

_BltSetup
; tmp1 and tmp2 are reserved by the _Apply helper methods
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:opcode        equ tmp6
:save_addr     equ tmp7
:entry_addr    equ tmp8
:draw_count_x2 equ tmp9
:virt_start    equ tmp10
:rtbl_idx_x2   equ tmp11

                stz   :rtbl_idx_x2

; Calculate where the horizontal entry and exit points are. The IIgs graphic screen has 2 pixels per byte,
; so the effective horizontal resolution is half the NES value.

                txa                       ; Initial range is 0 - 511
                and   MirrorMaskX         ; This is $01FF for vertical mirroring, $00FF for horizontal mirroring
                lsr                       ; Convert pixels to bytes
                bit   #$0001              ; Check if the starting byte value is even or odd
                beq   :blt_even
                brl   :blt_odd

; At this point the accumulator has the left edge coordinate in bytes (0 - 255) and we know it's an even
; number.  The high bit will tell us which page the starting coordinate is on, because the value can only be
; >= 128 in vertical mirroring mode when adjacent PEA field lines are used for rendering.
:blt_even
;                cmp   #64                 ; set the carry bit if the starting location is in the next nametable

                and   #$007E              ; LSB is already zero, this just zeros out the MSB
                tax                       ; look up the page offset for the left-edge word
                lda   Col2PageOffset,x    ; this is the offset that control will exit from
                sta   :exit_addr          ; This will be a 16-bit value later, but put the low byte in for now

                lda   CodeFieldBRA,x      ; This is the instruction that will be patched into
                sta   :exit_bra           ; each line

                lda   Col2PageOffset-2,x  ; The entry point is always 63 words later (-1 with wrap-around)
                xba                       ; and is used to create a JMP instruction
                ora   #$004C
                sta   :opcode

                lda   #_ENTRY_PATCH       ; Fixed location
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

                tya                       ; Possible range is 0 - 511, but valid from 0 - 239 and 256 - 495
                and   MirrorMaskY         ; This is $00FF for vertical mirroring, $01FF for horizontal
                asl                       ; Lookup the correct virtual line
                tay
                lda   NES2Virtual,y       ; Now we have virt_line in the register
                sta   :virt_start

                ldx   ScreenHeight
                ldy   #_SetupStack
                jsr   _Apply

                lda   :virt_start
                ldx   ScreenHeight        ; Need to do this many lines
                ldy   #_SetupPEAFieldLines
                jsr   _Apply              ; Handle the interations through the code fields (the accumulator from here is returned)
                rts

_SetupStack
:draw_count_x1  equ tmp9
:draw_count_x7  equ tmp10
:rtbl_idx_x2    equ tmp11
:draw_count_x2  equ tmp12

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

_SetupPEAFieldLines
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

                ldy   :entry_addr         ; Set the JMP $xx-- instruction to enter the even-aligned opcode
                lda   :opcode             ; Set the same constant value in every line
:set_opcode     jsr   $0000

                ldy   :exit_addr          ; Set the BRA instruction in the code field to exit
                lda   :exit_bra           ; The same constant value is set for all lines
:set_bra        jsr   $0000

                plb                       ; Restore the data bank
                lda   :exit_addr          ; Return the calculated exit address to be used for restore
                rts

; There are a couple of small indexing adjustments to make for an odd-aligned blit, plus one extra patch instruction
:blt_odd
                rts

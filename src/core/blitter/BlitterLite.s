; This is the method that is most useful from the high-level code.  We want the
; freedom to blit a range of lines.  This subroutine can assume that all of the
; data in the code fields is set up properly.
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200
;
; The screen is made up of one or more blocks of lines that were set up by _BltSetup/_BltSetupAlt,
; each with its own scroll parameters.  A range that crosses a block boundary is blitted as separate
; pieces, because the processor flags (C = odd-aligned, V = horizontal mirroring) and the Y register
; (odd edge byte offset) are only set once when entering the code field.

; This should only be called from _Render when it is determined to be safe
                mx    %00

_BltRangeLite
                sty   tmp0           ; Range check
                cpx   tmp0
                bcc   *+3
                rts

                DO    DIRTY_RENDERING_VISUALS
; Set SCB values for debugging
                php
                phx
                phy
:dbg_loop
                sep  #$20
                lda  DebugSCB
                oral $E19D00,x
                stal $E19D00,x
                rep  #$30
                inx
                txa
                cmp  1,s
                bcc  :dbg_loop
                ply
                plx
                plp
                FIN

                lda   ControlBits
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
                lda   ControlBits
                bit   #CTRL_BKGND_ENABLE
                bne   *+5
                brl   :no_background

                sty   BltRangeEnd

; Find the block that contains the first line.  The last block covers any lines past its end.

:next_piece
                txa
                ldy   #0
:find           cpy   BltBlockLast
                bcs   :found
                cmp   BltBlockEnd,y
                bcc   :found
                iny
                iny
                bra   :find
:found
                sty   BltBlockIdx

                lda   BltRangeEnd           ; This piece ends at the end of the range or the block
                cpy   BltBlockLast
                bcs   :piece_end
                cmp   BltBlockEnd,y
                bcc   :piece_end
                lda   BltBlockEnd,y
:piece_end      sta   BltPieceEnd

                jsr   _BltPieceLite

                ldx   BltPieceEnd
                cpx   BltRangeEnd
                bcc   :next_piece
                rts

; Special mode to use when the background is disabled.  Just slam a bunch of $0000 values
;
; This is simpler because X and Y are logical values.  Because we're not invoking the PEA
; table, there is no need to offset by the StartYMod240 value
;
; If the previous frame was drawn with the background disabled then we can skip everything.  This
; is actually not uncommon -- make games disable sprites and background when clearing or initializing the
; full screen, so tracking this allows us to perform updates to the PEA field quickly without wasting time
; redrawing a blank background for a few frames.
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
                lda   STATE_REG_R0W1
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

; Blit the lines from X up to BltPieceEnd, all within block BltBlockIdx
_BltPieceLite
:exit_ptr       equ   tmp0
:jmp_low_save   equ   tmp2

                clc
                lda   BltPieceEnd
                dec
                adc   StartRow       ; Get the PEA row of the line that we want to return from
                cmp   #240
                bcc   *+5
                sbc   #240
                asl
                tay
                lda   BTableLow,y    ; The blitter code spans two banks, so need to use long indirect addressing
                sta   :exit_ptr
                lda   BTableHigh,y
                sta   :exit_ptr+2

; Save and patch the exit instructions.  Both exits of a line always jump to the same place.

                ldy   #_E_JMP_OFFSET+1    ; this is a JMP/JML instruction that points to the next line.
                lda   [:exit_ptr],y       ; we have to save because not every line points to the same
                sta   :jmp_low_save       ; position in the next code line

                lda   #0                  ; long return jump in always at the start of the bank
                sta   [:exit_ptr],y       ; patch out the address of the JMP
                ldy   #_O_JMP_OFFSET+1
                sta   [:exit_ptr],y

                phb                       ; save the current bank
                php                       ; save interrupt state (and M/X bits)

; Now do the entry point.  Every line is entered through its even page.

                clc
                txa                  ; get the first line
                adc   StartRow       ; add in the physical row offset
                cmp   #240
                bcc   *+5
                sbc   #240
                asl
                tax                  ; this is the offset into the blitter table

                lda   BTableLow,x    ; patch in the address (carry is clear from the ASL)
                adc   #_ENTRY_OFFSET
                sta   blt_entry_lite+1

                sep   #$20
                mx    %10
                lda   BTableHigh,x
                sta   blt_entry_lite+3
                pha                       ; bank of the PEA field

; Push the processor status for this block. C indicates if this is an even/odd blit and V indicates if this
; is horizontal or vertical mirroring.  It also sets I = 1 (interrupts off), M = 1 and X = 0.  Nothing in the
; code field changes these flags.

                ldy   BltBlockIdx
                lda   BltBlockP,y
                pha
                ldx   BltBlockY,y         ; Offset of the right edge byte for odd-aligned blits
                txy

; Set the environment for the blitter and dispatch

                plp                       ; set the blitter flags and disable interrupts
                plb                       ; set bank to PEA fields
                tsx                       ; save the stack pointer
                stx   STK_SAVE            ; write to direct page before changing the softswitch

                lda   STATE_REG_BLIT
                stal  STATE_REG

blt_entry_lite  jml   lite_base_1         ; Jump into the blitter code $ZZ/YYXX

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

; Restore the exit code in the blitter

                lda   :jmp_low_save
                ldy   #_E_JMP_OFFSET+1
                sta   [:exit_ptr],y
                ldy   #_O_JMP_OFFSET+1
                sta   [:exit_ptr],y

                rts

; The blocks of lines set up by _BltSetupAlt.  Each block is a range of screen lines that share
; the same scroll parameters.  A block that starts at line zero resets the list.
BLT_MAX_BLOCKS  equ   4
BltBlockLast    dw    0                     ; 2 x (number of blocks - 1)
BltBlockEnd     ds    2*BLT_MAX_BLOCKS      ; screen line after the last line of the block
BltBlockP       dw    BLT_P_BASE,BLT_P_BASE,BLT_P_BASE,BLT_P_BASE   ; P register value (low byte)
BltBlockY       ds    2*BLT_MAX_BLOCKS      ; Y register value
BltBlockIdx     dw    0
BltRangeEnd     dw    0
BltPieceEnd     dw    0

; Helper routine that takes the horizontal and vertical scoll coordinates in the X and Y registers
; and sets up the appropriate engine values.
;
; The range of values is 0 - 511 for both X and Y.  This routine applies the mirroring masks and
; adjusts the Y value to map onto the valid range of 0 - 479 renderable lines.
NES_SetScrollX
                txa
                and   MirrorMaskX
                lsr

                cmp   StartXMod256
                beq   :out                       ; Easy, if nothing changed, then nothing changes

                sta   StartXMod256               ; Save the new position

                lda   #DIRTY_BIT_BG0_X
                tsb   DirtyBits

:out            rts

NES_SetScroll   jsr   NES_SetScrollX
;                jmp   NES_SetScrollY     ; Fall through

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

                cmp   StartYMod240
                beq   :out                       ; Easy, if nothing changed, then nothing changes

                sta   StartYMod240               ; Save the new position
                cmp   #240                       ; Virtual lines 240 - 479 are the same rows in CIRAM page 1
                bcc   *+5
                sbc   #240
                sta   StartRow

                lda   #DIRTY_BIT_BG0_Y
                tsb   DirtyBits

:out            rts

; Set up the code field to render a block of lines with a horizontal scroll offset.  This patches the
; entry point, the stack address and the exit point of every line and records the block for _BltRangeLite.
;
; With horizontal mirroring, each line stays within the CIRAM page (even or odd page of the row) that
; it is entered in.  With vertical mirroring, a line covers both pages and the page of the entry and
; exit points depends on the horizontal scroll.  Either way, every line is entered through its even
; page, and the entry BRL jumps to the first PEA.
;
; A = first screen line
; X = number of lines
; Y = horizontal offset in bytes (0 - 255)
;
; Returns the row-relative offset of the exit PEA, which is passed to _RestoreBG0OpcodesAltLite
_BltSetup
               ldy   StartXMod256
               lda   #0
               ldx   ScreenHeight

_BltSetupAlt
:num_lines     equ tmp3
:exit_addr     equ tmp4
:virt_start    equ tmp10

               jsr   _BltSetupBlock
               sta   :virt_start

               ldx   :num_lines
               ldy   #_SetupStack
               jsr   _Apply

               lda   :virt_start
               ldx   :num_lines
               ldy   #_SetupPEAFieldLines
               jsr   _Apply

               lda   :exit_addr
               rts

; A small variant for dirty rendering that just sets the BRA instruction in the code field assuming
; that everything else has not changed, e.g. saved value and entry/exit points.
_BltSetupDirty
               ldy   StartXMod256
               lda   #0
               ldx   ScreenHeight

_BltSetupDirtyAlt
:num_lines     equ tmp3
:exit_addr     equ tmp4

               jsr   _BltSetupBlock
               ldx   :num_lines
               ldy   #_SetupPEAFieldLinesDirty
               jsr   _Apply

               lda   :exit_addr
               rts

; Common setup for a block of lines.  Calculates the patch values from the horizontal scroll and
; records the block.
;
; A = first screen line
; X = number of lines
; Y = horizontal offset in bytes (0 - 255)
;
; Returns the first virtual line of the block in the accumulator
_BltSetupBlock
:num_lines     equ tmp3
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:entry_rel     equ tmp6
:odd_y         equ tmp7
:blt_p         equ tmp8
:rtbl_idx_x2   equ tmp11
:first_line    equ tmp12
:word          equ tmp13

               sta   :first_line
               stx   :num_lines
               asl
               sta   :rtbl_idx_x2        ; Relative location on the screen to draw

; The processor status used to enter the code field. C = 1 for an odd-aligned blit

               tya
               and   #BLT_P_ODD
               ora   #BLT_P_BASE
               ora   BltMirrorP
               sta   :blt_p

; The exit point is the PEA of the left-most word on the screen, L.  Words 64 - 127 are in the odd
; page of the row, which only happens with vertical mirroring because the scroll position is masked
; to 0 - 127 with horizontal mirroring.

               tya
               lsr
               sta   :word               ; L = byte offset / 2

               asl                       ; carry is clear because L < 128
               and   #$007E
               tax                       ; 2 x (L mod 64)
               lda   Col2CodeOffset,x
               adc   #_PEA_OFFSET
               ldy   :word
               cpy   #64
               bcc   *+5
               ora   #$0100
               sta   :exit_addr

; The BRA instruction is the same for both pages, but differs between the even and odd cases

               lda   :blt_p
               lsr                       ; C = odd-aligned
               lda   CodeFieldEvenBRA,x
               bcc   *+5
               lda   CodeFieldOddBRA,x
               sta   :exit_bra

; For odd-aligned blits, the right edge byte is the low byte of word L+64.  With horizontal mirroring
; that is word L itself, whose operand gets copied into the save slot.  With vertical mirroring it is
; the same column in the other page and can be read directly from the PEA operand.

               lda   BltMirrorP
               beq   :vert_y
               lda   #_SAVE_OFFSET
               bra   :set_y
:vert_y        lda   :exit_addr
               eor   #$0100
               inc
:set_y         sta   :odd_y

; The entry point is the PEA of the right-most word on the screen, L+63.  Horizontal mirroring
; wraps within 64 words and vertical mirroring within 128 words.

               lda   :word
               clc
               adc   #63
               ldy   BltMirrorP
               beq   :v_mask
               and   #$003F
               bra   *+5
:v_mask        and   #$007F
               tay
               asl
               and   #$007E
               tax
               lda   Col2CodeOffset,x
               cpy   #64
               bcc   *+5
               ora   #$0100
               clc
               adc   #_PEA_OFFSET-_ENTRY_PATCH-3  ; Make it relative to the BRL
               sta   :entry_rel

; Record the block for _BltRangeLite

               lda   :first_line
               beq   :first_block        ; A block that starts at line 0 resets the list
               ldy   BltBlockLast
               cpy   #{BLT_MAX_BLOCKS-1}*2
               bcs   :store_block        ; If the list is full, replace the last block
               iny
               iny
               bra   :store_block
:first_block   ldy   #0
:store_block   sty   BltBlockLast
               clc
               adc   :num_lines
               sta   BltBlockEnd,y
               lda   :blt_p
               sta   BltBlockP,y
               lda   :odd_y
               sta   BltBlockY,y

; Map the first line to a virtual line in the code field

               lda   :first_line
               clc
               adc   StartYMod240
               cmp   MaxY
               bcc   *+4
               sbc   MaxY
               rts

; Copy the right edge screen addresses into the LDX at the entry point of each line
;
; A = physical row
; X = number of lines
_SetupStack
:draw_count_x2 equ tmp9
:rtbl_idx_x2   equ tmp11
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

                lda   BTableLow,y                ; Get the address of the first code field line
                clc
                adc   #_ENTRY_OFFSET+1           ; The operand of the LDX
                tax

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

; Patch the entry and exit points of a range of lines.
;
; A = physical row
; X = number of lines
; BltSegPage = offset of the CIRAM page, only non-zero with horizontal mirroring
_SetupPEAFieldLines
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:entry_rel     equ tmp6
:draw_count_x2 equ tmp9
:btable_low    equ tmp12
:exit_loc      equ tmp13

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
                sta   :save_operand+1             ; patch for saving the PEA operand

                txa
                lsr
                eor   #$FFFF
                sec
                adc   #lsc_bottom
                sta   :set_bra+1                  ; patch for inserting the BRA instruction
                sta   :set_entry+1                ; and the entry BRL operand

                sep   #$20
                lda   BTableHigh,y                ; Get the bank for this range of PEA field lines
                pha
                rep   #$21

                lda   BTableLow,y
                sta   :btable_low
                adc   BltSegPage
                adc   :exit_addr
                sta   :exit_loc                   ; The PEA that gets replaced by the BRA
                inc
                tax                               ; Its operand

                lda   :btable_low
                adc   #_SAVE_OFFSET
                tay

                plb                       ; Set the data bank to the target PEA field range
:save_operand   jsr   $0000               ; Copy the PEA operand into the save slot

                ldy   :exit_loc
                lda   :exit_bra           ; The same constant value is set for all lines
:set_bra        jsr   $0000

                lda   :btable_low
                clc
                adc   #_ENTRY_PATCH+1
                tay
                lda   :entry_rel          ; The BRL is always in the even page, so add the page offset
                adc   BltSegPage          ; to jump into the odd page
:set_entry      jsr   $0000

                plb                       ; Restore the data bank
                rts

; Only patch the BRA instructions
_SetupPEAFieldLinesDirty
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:draw_count_x2 equ tmp9

                phb

                asl                              ; 2 x :virt_line
                tay                              ; use to load the base address

                txa
                asl
                sta   :draw_count_x2
                txa
                adc   :draw_count_x2              ; multiply by 3 to calculate the jump offset (carry is clear)
                eor   #$FFFF
                sec
                adc   #lsc_bottom
                sta   :set_bra+1

                sep   #$20
                lda   BTableHigh,y                ; Get the bank for this range of PEA field lines
                pha
                rep   #$21

                lda   BTableLow,y
                adc   BltSegPage
                adc   :exit_addr
                tay

                plb                       ; Set the data bank to the target PEA field range
                lda   :exit_bra           ; The same constant value is set for all lines
:set_bra        jsr   $0000

                plb                       ; Restore the data bank
                rts

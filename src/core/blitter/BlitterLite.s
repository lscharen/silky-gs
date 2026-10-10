; This is the method that is most useful from the high-level code.  We want the
; freedom to blit a range of lines.  This subroutine can assume that all of the
; data in the code fields is set up properly.
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200
;
; Every line holds its own scroll alignment (patched by _BltSetup/_BltSetupAlt), so any range of lines
; can be drawn, even when parts of the screen were set up with different horizontal scroll positions.
; The only global state is the mirroring mode, which is passed to the code field in the V flag.

; This should only be called from _Render when it is determined to be safe
                mx    %00

_BltRangeLite
                sty   tmp0           ; Range check
                cpx   tmp0
                bcc   *+3
                rts

                lda   ControlBits             ; The common case (background on, every line) needs
                and   #CTRL_EVEN_RENDER+CTRL_BKGND_ENABLE   ; one test and falls into the body
                cmp   #CTRL_BKGND_ENABLE
                bne   :not_simple
                sty   tmp1                ; Save the last line for the exit point
                jmp   _BltRangeLiteBody

:not_simple     bit   #CTRL_EVEN_RENDER
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

                sty   tmp1                ; Save the last line for the exit point
                jmp   _BltRangeLiteBody

; Special mode to use when the background is disabled.  Just slam a bunch of $0000 values
;
; This is simpler because X and Y are logical values.  Because we're not invoking the PEA
; table, there is no need to offset by the StartY value
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

; Blit the lines from X up to tmp1 (exclusive)
_BltRangeLiteBody
:exit_ptr       equ   tmp0
:last_line      equ   tmp1
:jmp_low_save   equ   tmp2

                clc
                lda   :last_line
                dec
                add_y_offset      ; Playfield line to NES scanline
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
                add_y_offset      ; Playfield line to NES scanline
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

; Push the processor status for the code field. V indicates if this is horizontal or vertical mirroring. It
; also sets I = 1 (interrupts off), M = 1 and X = 0.  Nothing in the code field changes these flags.

                lda   BltMirrorP
                ora   #BLT_P_BASE
                pha

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

; Set the engine scroll position from values in the form of the NES PPU registers.  The caller passes
; the values, so a custom renderer can use different scroll positions for different parts of the screen.
; NES_SetScrollX, NES_SetScrollY and NES_SetScrollNT change just one of the values.
;
; A = nametable select (PPUCTRL bits 1:0)
; X = scroll_x (0 - 255)
; Y = scroll_y (0 - 255)
NES_SetScroll
                stx   ScrollX
                sty   ScrollY

; A = nametable select (PPUCTRL bits 1:0)
NES_SetScrollNT
                and   #$0003
                sta   ScrollNT
                bra   _UpdateScrollStart

; X = scroll_x (0 - 255)
NES_SetScrollX
                stx   ScrollX
                bra   _UpdateScrollStart

; Y = scroll_y (0 - 255)
NES_SetScrollY
                sty   ScrollY

; Derive the blitter values from the scroll position.  Sets StartX (the byte offset of the left edge),
; StartY (the virtual line of NES scanline 0) and StartRow, and sets the dirty bits when they change.
;
; Only one of the nametable select bits picks the CIRAM page: the X bit (bit 0) with vertical mirroring
; and the Y bit (bit 1) with horizontal mirroring.  The other bit selects a mirror of the same page.
_UpdateScrollStart

; With vertical mirroring, a line spans both CIRAM pages and the X nametable bit is the high bit of
; a 9-bit horizontal position.

                lda   BltMirrorP
                bne   :horz_x
                lda   ScrollNT
                xba
                and   #$0100
                ora   ScrollX
                bra   :set_x
:horz_x         lda   ScrollX
:set_x          lsr                              ; NES pixels to IIgs bytes
                cmp   StartX
                beq   :y                         ; Easy, if nothing changed, then nothing changes

                sta   StartX
                lda   #DIRTY_BIT_BG0_X
                tsb   DirtyBits

; Scroll values of 240 - 255 start the screen in the attribute area of the nametable.  The PEA field does
; not have those lines, so rows 28 and 29 are shown instead.  With horizontal mirroring, the Y nametable
; bit selects CIRAM page 1, which is virtual lines 240 - 479.

:y              lda   ScrollY
                cmp   #240
                bcc   *+5
                sbc   #16
                ldx   BltMirrorP
                beq   :set_y                     ; Vertical mirroring
                ldx   ScrollNT
                cpx   #2                         ; Is the Y nametable bit set?
                bcc   :set_y
                adc   #240-1                     ; Carry is set
:set_y
                cmp   StartY
                beq   :out                       ; Easy, if nothing changed, then nothing changes

                sta   StartY                     ; Save the new position
                cmp   #240                       ; Virtual lines 240 - 479 are the same rows in CIRAM page 1
                bcc   *+5
                sbc   #240
                sta   StartRow

                lda   #DIRTY_BIT_BG0_Y
                tsb   DirtyBits

:out            rts

; Set up the code field to render a range of lines with a horizontal scroll offset.  This patches the
; entry point, the even/odd alignment, the stack address and the exit point of every line.
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
               ldy   StartX
               lda   #0
               ldx   ScreenHeight

STK_ENTRIES    equ   4                   ; Ranges remembered by _BltSetupAlt
;
; The code field keeps the setup of the last few ranges (STK_ENTRIES), so a range that is set up again
; only patches what changed:
;
;   - stack addresses: depend on the virtual line, the screen line and the number of lines
;   - entry / alignment / edge patches: also on the horizontal offset and the mirroring mode
;   - exit (save slot + BRA): left in place after the render; restored only when something needs the
;     PEA field to be stable (_PEAFieldStable: a tile is drawn into it, or a dirty renderer reads it),
;     when the range's horizontal offset changes, or when its rows are given to another range
;
; Every row with a patched exit belongs to exactly one entry (entries never overlap), so restoring an
; entry's exits always puts its rows back to the plain PEA field.  SetScreenRect clears the entries.
_BltSetupAlt
:num_lines     equ tmp3
:exit_addr     equ tmp4
:virt_start    equ tmp10
:first_line    equ tmp12                 ; (set by _BltSetupCommon)

               pha
               lda   BltMirrorP
               xba
               sta   stkCurXM
               tya
               ora   stkCurXM
               sta   stkCurXM            ; horizontal offset | mirroring << 8
               pla

               jsr   _BltSetupCommon
               sta   :virt_start

               ldx   #{STK_ENTRIES-1}*2
:find          cmp   stkKeyVirt,x         ; A = virtual line
               bne   :next
               lda   :first_line
               cmp   stkKeyFirst,x
               bne   :next0
               lda   :num_lines
               cmp   stkKeyCount,x
               bne   :next0
               brl   :hit
:next0         lda   :virt_start
:next          dex
               dex
               bpl   :find

; New range.  The code rows are the virtual lines mod 240; rows [new, new+n) and [row, row+count)
; overlap iff (row - new) mod 240 < n or (new - row) mod 240 < count.  Overlapped entries are
; restored and dropped.

               cmp   #240
               bcc   *+5
               sbc   #240
               sta   stkNewRow
               ldx   #{STK_ENTRIES-1}*2
:inval         lda   stkKeyCount,x
               bmi   :inval_next          ; ($FFFF = unused)
               lda   stkKeyRow,x
               sec
               sbc   stkNewRow
               bcs   *+5
               adc   #240
               cmp   :num_lines
               bcc   :drop
               lda   stkNewRow
               sec
               sbc   stkKeyRow,x
               bcs   *+5
               adc   #240
               cmp   stkKeyCount,x
               bcs   :inval_next
:drop          jsr   stkRestore
               lda   #$FFFF
               sta   stkKeyCount,x
:inval_next    dex
               dex
               bpl   :inval

               ldx   #{STK_ENTRIES-1}*2   ; An unused entry, or the next one in turn
:free          lda   stkKeyCount,x
               bmi   :slot
               dex
               dex
               bpl   :free
               ldx   stkNextSlot
               jsr   stkRestore
               txa
               inc
               inc
               and   #{STK_ENTRIES*2}-1
               sta   stkNextSlot
:slot          stx   stkCurSlot
               lda   :virt_start
               sta   stkKeyVirt,x
               lda   stkNewRow
               sta   stkKeyRow,x
               lda   :first_line
               sta   stkKeyFirst,x
               lda   :num_lines
               sta   stkKeyCount,x
               lda   stkCurXM
               sta   stkKeyXM,x
               stz   stkSkipEntry        ; New rows: patch everything

               ldx   :num_lines
               ldy   #_SetupStack
               lda   :virt_start
               jsr   _Apply
               bra   :patch

; Same rows as an entry
:hit           stx   stkCurSlot
               lda   stkCurXM
               cmp   stkKeyXM,x
               bne   :new_x
               lda   stkPatched,x         ; Same offset: if the exits are still patched, everything is
               bne   :done                ; in place; otherwise only the exits are patched
               lda   #1
               sta   stkSkipEntry
               bra   :patch
:new_x         jsr   stkRestore           ; The exits move: put the old ones back first
               lda   stkCurXM
               sta   stkKeyXM,x
               stz   stkSkipEntry

:patch         lda   :virt_start
               ldx   :num_lines
               ldy   #_SetupPEAFieldLines
               jsr   _Apply

               ldx   stkCurSlot
               lda   :exit_addr
               sta   stkExitAddr,x
               lda   #1
               sta   stkPatched,x
               sta   stkAnyPatched
:done          lda   :exit_addr
               rts

; Restore the exits of entry X if they are patched.  X and tmp1 - tmp12 are preserved (it is called
; in the middle of _BltSetupAlt).  DBR = K.
               mx    %00
stkRestore
               lda   stkPatched,x
               bne   :go
               rts
:go            stz   stkPatched,x
               phx
               pei   tmp1
               pei   tmp2
               pei   tmp3
               pei   tmp4
               pei   tmp5
               pei   tmp6
               pei   tmp7
               pei   tmp8
               pei   tmp9
               pei   tmp10
               pei   tmp11
               pei   tmp12

               lda   stkExitAddr,x
               sta   tmp4                 ; :exit_addr of _RestoreBG0OpcodesCallback
               lda   stkKeyCount,x
               pha
               lda   stkKeyVirt,x
               plx
               ldy   #_RestoreBG0OpcodesCallback
               jsr   _Apply

               pla
               sta   tmp12
               pla
               sta   tmp11
               pla
               sta   tmp10
               pla
               sta   tmp9
               pla
               sta   tmp8
               pla
               sta   tmp7
               pla
               sta   tmp6
               pla
               sta   tmp5
               pla
               sta   tmp4
               pla
               sta   tmp3
               pla
               sta   tmp2
               pla
               sta   tmp1
               plx
               rts

; Put back every exit that _BltSetupAlt left patched, so the PEA field holds only plain PEAs.  Called
; before anything writes tiles into the PEA field or reads background data from it.  Any register
; widths; all registers, DBR and the tmp variables are preserved.  D = the engine's direct page.
_PEAFieldStable
               php
               rep   #$30
               pha
               phx
               phy
               phb
               phk
               plb
               lda   stkAnyPatched
               beq   :out
               ldx   #{STK_ENTRIES-1}*2
:loop          lda   stkKeyCount,x
               bmi   *+5
               jsr   stkRestore
               dex
               dex
               bpl   :loop
               stz   stkAnyPatched
:out           plb
               ply
               plx
               pla
               plp
               rts

; Common setup for a range of lines.  Calculates the patch values from the horizontal scroll.
;
; A = first screen line
; X = number of lines
; Y = horizontal offset in bytes (0 - 255)
;
; Returns the first virtual line of the range in the accumulator
_BltSetupCommon
:num_lines     equ tmp3
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:entry_rel     equ tmp6
:edge_offset   equ tmp7
:align         equ tmp8
:rtbl_idx_x2   equ tmp11
:first_line    equ tmp12
:word          equ tmp13

               sta   :first_line
               stx   :num_lines
               asl
               sta   :rtbl_idx_x2        ; Relative location on the screen to draw

; The instruction patched into each line to select the even or odd code path

               tya
               lsr                       ; C = odd-aligned
               lda   #BLT_ALIGN_EVEN
               bcc   *+5
               lda   #BLT_ALIGN_ODD
               sta   :align

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

               lda   :align
               cmp   #BLT_ALIGN_ODD
               beq   :odd_bra
               lda   CodeFieldEvenBRA,x
               bra   :set_bra
:odd_bra       lda   CodeFieldOddBRA,x
:set_bra       sta   :exit_bra

; For odd-aligned blits, the right edge byte is the low byte of word L+64.  With horizontal mirroring
; that is word L itself, whose operand gets copied into the save slot.  With vertical mirroring it is
; the same column in the other page and can be read directly from the PEA operand.  The offset is
; patched into the LDX at _EDGE_PATCH.

               lda   BltMirrorP
               beq   :vert_edge
               lda   #_SAVE_OFFSET
               bra   :set_edge
:vert_edge     lda   :exit_addr
               eor   #$0100
               inc
:set_edge      sta   :edge_offset

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

; Map the first line to a virtual line in the code field

               lda   :first_line
               clc
               add_y_offset           ; Playfield line to NES scanline
               adc   StartY
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

; Patch the entry and exit points and the even/odd alignment of a range of lines.
;
; A = physical row
; X = number of lines
; BltSegPage = offset of the CIRAM page, only non-zero with horizontal mirroring
_SetupPEAFieldLines
:exit_addr     equ tmp4
:exit_bra      equ tmp5
:entry_rel     equ tmp6
:edge_offset   equ tmp7
:align         equ tmp8
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
                sta   :set_bra+1                  ; patch for inserting the BRA instruction,
                sta   :set_entry+1                ; the entry BRL operand,
                sta   :set_align+1                ; the even/odd code path
                sta   :set_edge+1                 ; and the right edge byte offset

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

                ldal  stkSkipEntry        ; Entry / alignment / edge already in place (_BltSetupAlt)
                bne   :done

                lda   :btable_low
                clc
                adc   #_ENTRY_PATCH+1
                tay
                lda   :entry_rel          ; The BRL is always in the even page, so add the page offset
                adc   BltSegPage          ; to jump into the odd page
:set_entry      jsr   $0000

                lda   :btable_low         ; Select the even or odd code path
                clc
                adc   #_ALIGN_PATCH
                tay
                lda   :align
:set_align      jsr   $0000

                cmp   #BLT_ALIGN_ODD      ; Odd lines also need the offset of the right edge byte
                bne   :done
                lda   :btable_low
                clc
                adc   #_EDGE_PATCH+1
                tay
                lda   :edge_offset
:set_edge       jsr   $0000

:done           plb                       ; Restore the data bank
                rts

; The ranges remembered by _BltSetupAlt (count $FFFF = unused)
stkKeyVirt     dw    $FFFF,$FFFF,$FFFF,$FFFF  ; first virtual line
stkKeyFirst    dw    $FFFF,$FFFF,$FFFF,$FFFF  ; first screen line
stkKeyCount    dw    $FFFF,$FFFF,$FFFF,$FFFF  ; number of lines
stkKeyRow      dw    0,0,0,0              ; first code row (virtual line mod 240)
stkKeyXM       dw    0,0,0,0              ; horizontal offset | mirroring << 8 of the entry patches
stkExitAddr    dw    0,0,0,0              ; row-relative exit offset of the patched exits
stkPatched     dw    0,0,0,0              ; non-zero: the exits (save slot + BRA) are patched
stkAnyPatched  dw    0                    ; non-zero: some entry's exits are patched
stkNewRow      dw    0
stkCurXM       dw    0                    ; this setup's horizontal offset | mirroring << 8
stkCurSlot     dw    0
stkNextSlot    dw    0                    ; Entry to replace when all are in use
stkSkipEntry   dw    0                    ; non-zero: _SetupPEAFieldLines skips the entry patches

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
                DO    JOYSTICK_SUPPORT
                jsr   JoyScanDisarm  ; The code field reads the joystick itself (JoyProbes.s): no scanline interrupts
                FIN
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

; A line that an earlier render left blank on both screens ($01 and $E1, nbgLine) and that nothing has
; drawn on since is not blanked again.  So while a game keeps the background off (transitions, loading
; screens), only the lines of the sprites are drawn.  A line blanked with shadowing off is blank in $01
; only: the sprites are drawn on it next (drawShadowList), so it is not marked.

                sep   #$20
                ldal  SHADOW_REG
                rep   #$20
                and   #$0008              ; Shadowing of the SHR screen off?
                sta   nbgShOff
                lda   #1
                sta   nbgAny

:no_bg_loop
                lda   nbgLine,y
                beq   :nbg_draw
                lda   nbgShOff
                beq   :nbg_next           ; blank on both screens: nothing to do
                lda   #0                  ; a sprite line: $01 is blank already, but the sprites
                sta   nbgLine,y           ; drawn on it next make it not blank any more
                bra   :nbg_next

:nbg_draw
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
                rep   #$20                ; 16-bit

                lda   nbgShOff            ; Blank on both screens now, unless shadowing was off
                eor   #$0008
                sta   nbgLine,y           ; (non-zero: blank)

:nbg_next       clc
                tya
                adc   tmp1
                tay
                cpy   tmp0
                bcs   *+5
                brl   :no_bg_loop

                rts

; nbgLine: for each screen line (index = line * 2), non-zero if both screens have it blank (color 0)
; since a render with the background off.  nbgAny is set when some may be non-zero.  The marks are
; dropped when the background is drawn (_BltRangeLiteBody) and at a forced refresh (RenderDraw:
; DIRTY_BIT_BG0_REFRESH -- the background turned on or off, the configuration screen, ...).
nbgLine         ds    400
nbgAny          dw    0
nbgShOff        dw    0

; Forget the blank lines: something else drew on the screen.  Only A is changed.
nbgInvalidate
                lda   nbgAny
                beq   :done
                stz   nbgAny
                phy
                ldy   #398
                lda   #0
:loop           sta   nbgLine,y
                dey
                dey
                bpl   :loop
                ply
:done           rts

; Blit the lines from X up to tmp1 (exclusive)
_BltRangeLiteBody
:exit_ptr       equ   tmp0
:last_line      equ   tmp1
:jmp_low_save   equ   tmp2

                jsr   nbgInvalidate       ; The background is drawn: no line is known to be blank

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

                DO    JOYSTICK_SUPPORT
                ldy   #0                  ; No joystick probe run started in this range (JoyProbes.s)
                FIN

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
; the values, so a renderer can use different scroll positions for different parts of the screen (games:
; NES_SetScroll, the long entry in ppu_api.s).
; _SetScrollX, _SetScrollY and _SetScrollNT change just one of the values.
;
; A = nametable select (PPUCTRL bits 1:0)
; X = scroll_x (0 - 255)
; Y = scroll_y (0 - 255)
_SetScroll
                stx   ScrollX
                sty   ScrollY

; A = nametable select (PPUCTRL bits 1:0)
_SetScrollNT
                and   #$0003
                sta   ScrollNT
                bra   _UpdateScrollStart

; X = scroll_x (0 - 255)
_SetScrollX
                stx   ScrollX
                bra   _UpdateScrollStart

; Y = scroll_y (0 - 255)
_SetScrollY
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
; Returns the row-relative offset of the exit PEA
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
               lda   #1
               sta   stkSetOpcode

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
               lda   stkCurXM             ; The even / odd opcode only changes with the offset's parity
               eor   stkKeyXM,x
               and   #$0001
               sta   stkSetOpcode
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
               sty   :align              ; (the offset, until the code path is chosen below)

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

; The even or odd code path.  It selects the exit BRA (the same for both pages), the opcode patched into
; each line (low byte of :align) and the location of the entry BRL's operand (high byte of :align), and
; the entry BRL's offset from the PEA, which is added to the entry point below (:entry_rel).

               lsr   :align              ; C = odd-aligned
               bcs   :odd_path
               lda   CodeFieldEvenBRA,x
               sta   :exit_bra
               lda   #BLT_ALIGN_EVEN+{{_ALIGN_PATCH+1}*256}
               sta   :align
               lda   #_PEA_OFFSET-_ALIGN_PATCH-3
               bra   :set_path
:odd_path      lda   CodeFieldOddBRA,x
               sta   :exit_bra
               lda   #BLT_ALIGN_ODD+{{_ODD_ENTRY_PATCH+1}*256}
               sta   :align
               lda   #_PEA_OFFSET-_ODD_ENTRY_PATCH-3
:set_path      sta   :entry_rel

; For odd-aligned blits, the right edge byte is the low byte of word L+64.  With horizontal mirroring
; that is word L itself, whose operand gets copied into the save slot.  With vertical mirroring it is
; the same column in the other page and can be read directly from the PEA operand.  The offset is
; patched into the LDX operand at _ALIGN_PATCH+1.

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
               clc                        ; Make it relative to the BRL of the line's code path
               adc   :entry_rel
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
                sta   :set_align+1                ; the even/odd opcode,
                sta   :set_edge+1                 ; the right edge byte offset (odd)
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

                ldal  stkSkipEntry        ; Entry / alignment / edge already in place (_BltSetupAlt)
                bne   :done

                ldal  stkSetOpcode        ; Zero: these rows were last set up with the same parity, so
                beq   :operands           ; the opcode is already in place
                lda   :btable_low         ; Select the even or odd code path (8-bit opcode stores)
                clc
                adc   #_ALIGN_PATCH
                tay
                lda   :align
                sep   #$20
:set_align      jsr   $0000
                rep   #$20

:operands       lda   :align
                bit   #BLT_ALIGN_EVEN!BLT_ALIGN_ODD
                beq   :entry              ; Even
                lda   :btable_low         ; Odd: the LDX operand at _ALIGN_PATCH is the offset of the
                clc                       ; right edge byte
                adc   #_ALIGN_PATCH+1
                tay
                lda   :edge_offset
:set_edge       jsr   $0000
                lda   :align

:entry          xba                       ; The entry BRL's operand: at _ALIGN_PATCH+1 (even) or
                and   #$00FF              ; _ODD_ENTRY_PATCH+1 (odd), from the high byte of :align
                clc
                adc   :btable_low
                tay
                lda   :entry_rel          ; The BRL is always in the even page, so add the page offset
                adc   BltSegPage          ; to jump into the odd page
:set_entry      jsr   $0000

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
stkSetOpcode   dw    1                    ; non-zero: _SetupPEAFieldLines writes the even / odd opcode

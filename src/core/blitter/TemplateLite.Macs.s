; Shared row template for the Lite blitter banks (TemplateLiteBank1.s / TemplateLiteBank2.s).
;
; Each PPU row is a pair of pages.  The even page (P0) holds CIRAM page 0 for that row and the
; odd page (P1) holds CIRAM page 1.  This mapping is fixed -- it does not change with the mirroring
; mode -- so nothing in the rows has to be re-patched when the mirroring mode changes.
;
; The mirroring mode is selected at runtime by the V flag, which no instruction in the code field
; modifies:
;
;   V = 0 : vertical mirroring     V = 1 : horizontal mirroring
;
; With vertical mirroring, execution falls off the end of a page's PEA run into the other page's
; PEA run (a 512-pixel wide line).  With horizontal mirroring, execution loops within the page it
; was entered in (a 256-pixel wide line).
;
; The even/odd alignment is patched into each line at _ALIGN_PATCH, so lines with different
; alignments can be drawn in a single pass.  Even lines BRA over the edge byte code.  Odd lines
; execute an 8-bit LDA #imm (a two byte no-op) and push the right edge byte, whose P0-relative
; offset is patched into the LDX.
;
; Every row is entered at P0+_ENTRY_OFFSET, regardless of which page the blit actually starts in.
; The BRL at P0+_ENTRY_PATCH is patched to reach the first PEA in either page. The next-row JMPs
; always target the next row's P0, so line chaining is static.
;
; P0 layout                                   P1 layout
;  $00 interrupt window (17 bytes)             $00 -- unused --
;  $11 ldx #0000 / txs                         $21 jmp P0+exit_even
;  $15 bra $1E (even) / lda #imm (odd)         $24 jmp P0+exit_odd
;  $17 ldx #edge                               $27 64 x pea
;  $1A lda: P0,x / pha                         $E7 bvc *+5
;  $1E brl <entry>                             $E9 jmp P1+$27   (horizontal: stay in page)
;  $21 jmp exit_even                           $EC jmp P0+$27   (vertical: cross to P0)
;  $24 jmp exit_odd                            $EF jmp P0+exit_even
;  $27 64 x pea                                $F6 jmp P0+exit_odd
;  $E7 bvc P1+$27  (vertical: cross to P1)
;  $E9 jmp P0+$27  (horizontal: stay in page)
;  $EF exit_even: pea <saved>  (save slot)
;  $F2 jmp next_row+$11 / jml
;  $F6 exit_odd: lda: P0+$F1 / pha
;  $FA jmp next_row+$11 / jml
;
; The exit offsets in both pages are identical, so a single BRA table serves either page.
;
; These macros reference the ]page variable (the P0 base address of the row) directly.

PEA64              mac
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   <<<

; Even page, from the interrupt window through the even exit's save slot ($00 - $F1)
LITE_P0            mac
                   ldx   STK_SAVE                   ; $00: Interrupt window. Restore the stack
                   txs
                   lda   STATE_REG_R0W0             ; The blitter runs with an 8-bit accumulator
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG

                   ldx   #0000                      ; $11: Normal entry.  Screen address (right edge)
                   txs
                   dw    BLT_ALIGN_EVEN             ; $15: Patched. BRA to the BRL (even) or LDA #imm (odd)
                   ldx   #0000                      ; $17: Odd-aligned, P0-relative offset of the right edge byte
                   lda:  ]page,x                    ; $1A: Push the right edge byte
                   pha
                   brl   ]page+_E_OUT_OFFSET        ; $1E: Patched to jump to the first PEA in P0 or P1
                   jmp   ]page+_E_EXIT_OFFSET       ; $21
                   jmp   ]page+_O_EXIT_OFFSET       ; $24
                   PEA64                            ; $27
                   bvc   ]page+$100+_PEA_OFFSET     ; $E7: Vertical mirroring continues in P1
                   jmp   ]page+_PEA_OFFSET          ; $E9: Horizontal mirroring wraps within P0
                   ds    3
                   dfb   $F4,$00,$00                ; $EF: exit_even. Saved PEA operand, pushed as the left edge
                   <<<

; Odd page ($100 - $1FF)
LITE_P1            mac
                   ds    _E_OUT_OFFSET              ; $00 - $20 are unused
                   jmp   ]page+_E_EXIT_OFFSET       ; $21
                   jmp   ]page+_O_EXIT_OFFSET       ; $24
                   PEA64                            ; $27
                   bvc   *+5                        ; $E7
                   jmp   ]page+$100+_PEA_OFFSET     ; $E9: Horizontal mirroring wraps within P1
                   jmp   ]page+_PEA_OFFSET          ; $EC: Vertical mirroring continues in P0
                   jmp   ]page+_E_EXIT_OFFSET       ; $EF
                   ds    4
                   jmp   ]page+_O_EXIT_OFFSET       ; $F6
                   ds    \,$00
                   <<<

; A complete row that chains to the next row in the same bank
LITE_ROW           mac
                   LITE_P0
                   jmp   ]page+$200+_ENTRY_OFFSET   ; $F2: Next row
                   ds    1                          ; Space for a JML
                   lda:  ]page+_SAVE_OFFSET+1       ; $F6: exit_odd.  Push the left edge byte
                   pha
                   jmp   ]page+$200+_ENTRY_OFFSET   ; $FA: Next row
                   ds    \,$00
                   LITE_P1
                   <<<

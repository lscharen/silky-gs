; Shared row template for the Lite blitter banks (TemplateLiteBank1.s / TemplateLiteBank2.s).
;
; Each PPU row is a pair of pages.  The even page (P0) holds CIRAM page 0 for that row and the
; odd page (P1) holds CIRAM page 1.  This mapping is fixed -- it does not change with the mirroring
; mode -- so nothing in the rows has to be re-patched when the mirroring mode changes.
;
; Control flow is selected at runtime by the processor flags, which no instruction in the code
; field modifies:
;
;   C = 0 : even-aligned blit      C = 1 : odd-aligned blit (push an extra edge byte on entry/exit)
;   V = 0 : vertical mirroring     V = 1 : horizontal mirroring
;
; With vertical mirroring, execution falls off the end of a page's PEA run into the other page's
; PEA run (a 512-pixel wide line).  With horizontal mirroring, execution loops within the page it
; was entered in (a 256-pixel wide line).
;
; Every row is entered at P0+_ENTRY_OFFSET, regardless of which page the blit actually starts in.
; The BRL at P0+_ENTRY_PATCH is patched to reach the first PEA in either page. The next-row JMPs
; always target the next row's P0, so line chaining is static.
;
; The Y register holds the P0-relative offset of the right-edge byte for odd-aligned blits.
;
; P0 layout                                   P1 layout
;  $00 interrupt window (17 bytes)             $00 -- unused --
;  $11 ldx #0000 / txs                         $1E jmp P0+exit_even
;  $15 bcc $1B                                 $21 jmp P0+exit_odd
;  $17 lda: P0,y / pha                         $24 64 x pea
;  $1B brl <entry>                             $E4 bvc *+5
;  $1E jmp exit_even                           $E6 jmp P1+$24   (horizontal: stay in page)
;  $21 jmp exit_odd                            $E9 jmp P0+$24   (vertical: cross to P0)
;  $24 64 x pea                                $EC jmp P0+exit_even
;  $E4 bvc P1+$24  (vertical: cross to P1)     $F3 jmp P0+exit_odd
;  $E6 jmp P0+$24  (horizontal: stay in page)
;  $EC exit_even: pea <saved>  (save slot)
;  $EF jmp next_row+$11 / jml
;  $F3 exit_odd: lda: P0+$EE / pha
;  $F7 jmp next_row+$11 / jml
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

; Even page, from the interrupt window through the even exit's save slot ($00 - $EE)
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
                   bcc   *+6                        ; $15: Even-aligned blits skip the edge byte
                   lda:  ]page,y                    ; $17: Odd-aligned, push the right edge byte
                   pha
                   brl   ]page+_E_OUT_OFFSET        ; $1B: Patched to jump to the first PEA in P0 or P1
                   jmp   ]page+_E_EXIT_OFFSET       ; $1E
                   jmp   ]page+_O_EXIT_OFFSET       ; $21
                   PEA64                            ; $24
                   bvc   ]page+$100+_PEA_OFFSET     ; $E4: Vertical mirroring continues in P1
                   jmp   ]page+_PEA_OFFSET          ; $E6: Horizontal mirroring wraps within P0
                   ds    3
                   dfb   $F4,$00,$00                ; $EC: exit_even. Saved PEA operand, pushed as the left edge
                   <<<

; Odd page ($100 - $1FF)
LITE_P1            mac
                   ds    _E_OUT_OFFSET              ; $00 - $1D are unused
                   jmp   ]page+_E_EXIT_OFFSET       ; $1E
                   jmp   ]page+_O_EXIT_OFFSET       ; $21
                   PEA64                            ; $24
                   bvc   *+5                        ; $E4
                   jmp   ]page+$100+_PEA_OFFSET     ; $E6: Horizontal mirroring wraps within P1
                   jmp   ]page+_PEA_OFFSET          ; $E9: Vertical mirroring continues in P0
                   jmp   ]page+_E_EXIT_OFFSET       ; $EC
                   ds    4
                   jmp   ]page+_O_EXIT_OFFSET       ; $F3
                   ds    \,$00
                   <<<

; A complete row that chains to the next row in the same bank
LITE_ROW           mac
                   LITE_P0
                   jmp   ]page+$200+_ENTRY_OFFSET   ; $EF: Next row
                   ds    1                          ; Space for a JML
                   lda:  ]page+_SAVE_OFFSET+1       ; $F3: exit_odd.  Push the left edge byte
                   pha
                   jmp   ]page+$200+_ENTRY_OFFSET   ; $F7: Next row
                   ds    \,$00
                   LITE_P1
                   <<<

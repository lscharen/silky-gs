; This is a specialized blitter specifically made for supporting NES PPU graphics.  Each PPU row is
; a pair of pages that map 1:1 onto the two pages of NES CIRAM (the even page is CIRAM page 0 and
; the odd page is CIRAM page 1).  The mirroring mode is selected at runtime by the V flag, so the
; code field never needs to be re-patched when the mirroring changes.  See TemplateLite.Macs.s for
; the row layout.
;
; The memory layout of the bank is
;
; $0000    JML  RETURN
; $0004    Entry stub when arriving from the other bank
; ...
; $0100    ROW 0   (CIRAM page 0)
; $0200    ROW 0   (CIRAM page 1)
; $0300    ROW 1   (CIRAM page 0)
; ...
; $EF00    ROW 119 (CIRAM page 0)
; $F000    ROW 119 (CIRAM page 1)
;
; Rows 0 - 119 live in this bank, rows 120 - 239 in TemplateLiteBank2.s
blt_return_lite    EXT
lite_bank_entry_2  EXT

                   use   GTE.Macs.s
                   use   ../Defs.s
                   use   TemplateLite.Macs.s

                   mx    %00                        ; Code can actually be run with M = 0 or 1

; Return to caller -- this is the target address to patch in the JMP instruction on the last rendered line. We
; put it at the beginning so the rest of the bank can be replicated line templates.

                   jml   blt_return_lite            ; Full exit (must be at address $0000)

; This is the entry point when coming from the other bank.  Need to set the data bank register and
; then move to the first line of code.
lite_bank_entry_1  ENT
                   ldx   STK_SAVE_BANK              ; Load the address to a location where this bank's high byte is stored
                   txs
                   plb
                   jmp   lite_base_1+_ENTRY_OFFSET

                   ds    \,$00                      ; pad so that the PEA code is aligned on the page boundary

; lite_base_1 is the P0 base address of row 0.  Rows are _LINE_SPAN bytes apart.
lite_start_page_1  ENT
lite_base_1        ENT
]page              equ   $0100
                   lup   119
                   LITE_ROW
]page              equ   ]page+$200
                   --^

; The last row jumps to the first row of the other bank
]page              equ   $0100+{119*_LINE_SPAN}
                   LITE_P0
                   jml   lite_bank_entry_2          ; $EF
                   lda:  ]page+_SAVE_OFFSET+1       ; $F3
                   pha
                   jml   lite_bank_entry_2          ; $F7
                   ds    \,$00
                   LITE_P1

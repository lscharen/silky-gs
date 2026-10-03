; Second bank of the Lite blitter.  Holds rows 120 - 239.  See TemplateLiteBank1.s and
; TemplateLite.Macs.s for details.
blt_return_lite    EXT
lite_bank_entry_1  EXT

                   use   GTE.Macs.s
                   use   ../Defs.s
                   use   TemplateLite.Macs.s

                   mx    %00                        ; Code can actually be run with M = 0 or 1

; Return to caller -- this is the target address to patch in the JMP instruction on the last rendered line. We
; put it at the beginning so the rest of the bank can be replicated line templates.

                   jml   blt_return_lite            ; Full exit (must be at address $0000)

; This is the entry point when coming from the other bank.  Need to set the data bank register and
; then move to the first line of code.
lite_bank_entry_2  ENT
                   ldx   STK_SAVE_BANK              ; Load the address to a location where this bank's high byte is stored
                   inx
                   txs
                   plb
                   jmp   lite_base_2+_ENTRY_OFFSET

                   ds    \,$00                      ; pad so that the PEA code is aligned on the page boundary

; lite_base_2 is the P0 base address of row 120.  Rows are _LINE_SPAN bytes apart.
lite_start_page_2  ENT
lite_base_2        ENT
]page              equ   $0100
                   lup   119
                   LITE_ROW
]page              equ   ]page+$200
                   --^

; The last row jumps to the first row of the other bank
]page              equ   $0100+{119*_LINE_SPAN}
                   LITE_P0
                   jml   lite_bank_entry_1          ; $F2
                   lda:  ]page+_SAVE_OFFSET+1       ; $F6
                   pha
                   jml   lite_bank_entry_1          ; $FA
                   ds    \,$00
                   LITE_P1

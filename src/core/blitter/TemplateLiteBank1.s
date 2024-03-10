; This is a speicalized blitter specifically made for supporting NES PPU graphics.  Instead of a single, full-screen
; PEA field (328x208), instead we define two PEA fields (256x240) that can be configured to match the NES PPU nametable
; mirroring structure.
;
; This provides a 1:1 correspondence between PPU nametable addresses and blitter tile addresses.  Also, the PPU
; SCROLLX and SCROLLY register values can be used directly to set the origin point for the blitter.
;
; The memory layout of the bank is
;
; $0000    JML  RETURN
; $0004    TABLE DATA
; ...
; $0200    LINE 1A
; $0300    LINE 1B
; $0400    LINE 2A
; $0500    LINE 2B
; ...
; $F000    LINE 119A
; $F100    LINE 119B
; $F200    LINE 120A
; $F300    LINE 120B
; $F400
; 
; Template and equates for GTE blitter
blt_return_lite    EXT
lite_base_2        EXT

                   use   GTE.Macs.s
                   use   ../Defs.s

                   mx    %10            ; 8-bit accumulator, 16-bit index registers

; Return to caller -- this is the target address to patch in the JMP instruction on the last rendered line. We
; put it at the beginning so the rest of the bank can be replicated line templates.
                   jml   blt_return_lite            ; Full exit (must be at address $0000)

; Start of the template code.  This code contains two sets of 64 PEA instructions to
; represent two nametables set up in vertical mirroring mode.  These lines are
; replicated 120 times over 2 banks to cover the full 240 lines of the NES PPU.
;
; The lite blitter is crafted to allow the accumulator to be in 8-bit mode and avoid any
; need for rep/sep instructions to handle the odd-aligned case

                   ds    $200-15-4                  ; pad so that the PEA code aligned on the page boundary
lite_base          ENT
lite_entry_1       ldx   #0000                      ; Sets screen address (right edge)
                   txs

lite_entry_jmp     brl   $0000                      ; If the screen is odd-aligned, then the opcode is set to 
                                                    ; $A2 to convert to a LDX #imm instruction.  This puts the
                                                    ; relative offset of the instruction field in the register
                                                    ; and falls through to the next instruction.

                   ldal  *+1,x                      ; Get the low byte and push onto the stack
                   pha
lite_odd_entry     brl   $0000                      ; unconditionally jump into the "next" instruction in the 
                                                    ; code field.  This is OK, even if the entry point was the
                                                    ; last instruction, because there is a JMP at the end of
                                                    ; the code field, so the code will simply jump to that
                                                    ; instruction directly. (14 bytes)

; This is where we are page-aligned.  It's a small optimization that allows
;
; 1. All of the instructions for updating the field never cross a page boundary (saves 1 cycle)
; 2. Only the low address byte needs to be updated in some cases

                   jmp   lite_even_exit             ; Alternate exit point depending on whether the left edge is 
                   jmp   lite_odd_exit              ; even- or odd-aligned

lite_prev          lup   64                         ; Set up 64 PEA instructions, which is 256 pixels and consumes 192 bytes
                   pea   $0000
                   --^
                   jmp   lite_next                  ; Go to the next nametable PEA
                   jmp   lite_even_exit
                   jmp   lite_odd_exit

                   ds    \,$00                      ; pad to the next page boundary
                   jmp   lite_even_exit             ; Alternate exit point depending on whether the left edge is 
                   jmp   lite_odd_exit              ; odd-aligned
lite_next          lup   64
                   pea   $0000
                   --^
                   jmp   lite_prev
lite_loop_exit_3b  jmp   lite_even_exit
lite_odd_exit      lda   #0                         ; get the high byte of the saved PEA operand (odd-case is already in 8-bit mode)
                   pha
lite_even_exit     jmp   $0400-15                   ; Jump to the next line.
                   ds    1                          ; Space for when the exit vector is a JML to cross a bank
                   dfb   $F4,$00                    ; low-word of the saved PEA instruction (410 bytes)

; Align to the next page to keep everything aligned to a 512 byte boundary.  Repeat the code 118 times and
; manually create the last line to jump to the next bank

]page              equ   $400
                   lup   118
                   ds    43-15
                   ldx   #0000
                   txs
                   dfb   $82,$00,$00
                   ldal  *+1,x
                   pha
                   dfb   $82,$00,$00
                   jmp   ]page+$1CF
                   jmp   ]page+$1CC

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

                   jmp   ]page+$106
                   jmp   ]page+$1CF
                   jmp   ]page+$1CC
                   ds    49

                   jmp   ]page+$1CF
                   jmp   ]page+$1CC

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

                   jmp   ]page+$006
                   jmp   ]page+$1CF
                   lda   #0
                   pha
                   jmp   ]page+$200-15
                   ds    1
                   dfb   $F4,$00

]page              equ   ]page+$200
                   --^

                   ds    43-15                     ; More padding
                   ldx   #0000
                   txs
                   brl   *+3

                   ldal  *+1,x
                   pha
                   brl   *+3

                   jmp   lite_even_exit2
                   jmp   lite_odd_exit2

lite_prev2         lup   64
                   pea   $0000
                   --^
                   jmp   lite_next2
                   jmp   lite_even_exit2
                   jmp   lite_odd_exit2

                   ds    \,$00
                   jmp   lite_even_exit2
                   jmp   lite_odd_exit2
lite_next2         lup   64
                   pea   $0000
                   --^
                   jmp   lite_prev2
                   jmp   lite_even_exit2
lite_odd_exit2     lda   #0                         ; get the high byte of the saved PEA operand (odd-case is already in 8-bit mode)
                   pha
lite_even_exit2    jml   lite_base_2                ; Jump to the next bank
                   dfb   $F4,$00

; The even_exit JMP from the previous line will jump here every 8 or 16 lines in order to give
; the system time to handle interrupts.
;
; This code is placed here to allow it to fall-through and avoid an extra branch
lite_enable_int    tyx
                   txs                              ; restore the stack. No 2-layer support, so B and D point to useful data
                   lda   STATE_REG_R0W0             ; we are in 8-bit mode the whole time...
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT             ; External values 
                   stal  STATE_REG
;                   bra   lite_entry_1               ; (18 bytes)

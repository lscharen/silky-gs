; This is a specialized blitter specifically made for supporting NES PPU graphics.  Instead of a single, full-screen
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

                   mx    %00                        ; Code can actually be run with M = 0 or 1

; Return to caller -- this is the target address to patch in the JMP instruction on the last rendered line. We
; put it at the beginning so the rest of the bank can be replicated line templates.

                   jml   blt_return_lite            ; Full exit (must be at address $0000)

; This is the entry point when coming from the other bank.  Need to set the data bank register and
; then move to the first line of code

; offset = 4
                   ldx   STK_SAVE_BANK              ; Load the address to a location where this bank's high byte is stored
                   txs
                   plb
                   jmp   lite_base_1
                   nop                              ; pad to match other bank code

; offset = 12
                   ldx   STK_SAVE_BANK              ; Load the address to a location where this bank's high byte is stored
                   txs
                   plb
                   jmp   lite_base_1+$100
                   nop                              ; pad to match other bank code

                   ds    \,$00                      ; pad so that the PEA code is aligned on the page boundary
                  
; Pre-code area that holds optional entry points for enabling interrups, reading the
; joystick and other operations that may need to be interwoven with the PEA field
; execution

lite_start_page_1  ENT
lite_enable_int_1  ldx   STK_SAVE
                   txs                              ; restore the stack. No 2-layer support, so B and D point to useful data
                   lda   STATE_REG_R0W0             ; we are in 8-bit mode the whole time...
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT             ; External values 
                   stal  STATE_REG                  ; = 16 bytes

; Start of the template code.  This code contains two sets of 64 PEA instructions to
; represent two nametables set up in vertical mirroring mode.  These lines are
; replicated 120 times over 2 banks to cover the full 240 lines of the NES PPU.
;
; The lite blitter is crafted to allow the accumulator to be in 8-bit mode and avoid any
; need for rep/sep instructions to handle the odd-aligned case

lite_base_1        ENT
lite_entry         ldx   #0000                      ; Sets screen address (right edge)
                   txs

lite_entry_jmp     jmp   lite_prev-3                ; If the screen is odd-aligned, then the opcode is set to 
                                                    ; $A2 to convert to a LDX #imm instruction.  This puts the
                                                    ; address of the instruction field in the register
                                                    ; and falls through to the next instruction.

                   lda:  1,x                        ; Get the low byte and push onto the stack
                   pha
lite_odd_entry     jmp  lite_prev                   ; unconditionally jump into the "next" instruction in the 
                                                    ; code field.  This is OK, even if the entry point was the
                                                    ; last instruction, because there is a JMP at the end of
                                                    ; the code field, so the code will simply jump to that
                                                    ; instruction directly. (14 bytes)

; This is where we are page-aligned.  It's a small optimization that allows
;
; 1. All of the instructions for updating the field never cross a page boundary (saves 1 cycle, sometimes)
; 2. Only the low address byte needs to be updated (sometimes)
; 3. The BRA instruction to exit the blitter never crosses a page boundary (saves 1 cycles, sometimes)

                   jmp   lite_exit                  ; Exit the line
lite_prev          lup   64                         ; Set up 64 PEA instructions, which is 256 pixels and consumes 192 bytes
                   pea   $0000
                   --^
                   jmp   lite_next                  ; Go to the next nametable PEA. This is a JMP lite_prev for horizontal mirrring
                   lda:  *+9,y                      ; Load from the patch save location. A = 8-bit for odd, 16-bit for even, Y = 1 or odd, 0 for even
                   pha
lite_exit          jmp   $0300-14                   ; Jump to the next line.  Not used for horizonal mirroring
                   ds    1                          ; Space for when the exit vector is a JML to cross a bank
lite_save          dfb   $F4,$00,$00                ; Storage for the patched PEA data

                   ds    \,$00                         ; pad to the next page boundary
                   ldx   STK_SAVE
                   txs
                   lda   STATE_REG_R0W0
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG

                   ldx   #0000                      ; Normal entry point
                   txs
                   jmp   lite_next-3
                   lda:  1,x
                   pha
                   jmp   lite_next
                   jmp   lite_exit
lite_next          lup   64
                   pea   $0000
                   --^
                   jmp   lite_prev                  ; This is a JMP lite_next for horizontal mirroring
                   lda:  *+9,y
                   pha
                   jmp   $0400-14                   ; Jump to the next line.
                   ds    1                          ; Space for when the exit vector is a JML to cross a bank
                   dfb   $F4,$00,$00                ; low-word of the saved PEA instruction (410 bytes)

; Align to the next page to keep everything aligned to a 512 byte boundary.  Repeat the code 118 times and
; manually create the last line to jump to the next bank

]page              equ   $400
                   lup   118

                   ds    \,$00
                   ldx   STK_SAVE
                   txs
                   lda   STATE_REG_R0W0
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG

                   ldx   #0000
                   txs
                   jmp   ]page
                   lda:  1,x
                   pha
                   jmp   ]page+3

                   jmp   ]page+$1CA
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
                   jmp   ]page+$103

                   lda:  *+9,y
                   pha
                   jmp   ]page+$2F2
                   ds    1
                   dfb   $F4,$00,$00
                   ds    \,$00

                   ldx   STK_SAVE
                   txs
                   lda   STATE_REG_R0W0
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG

                   ldx   #0000
                   txs
                   jmp   ]page+$100
                   lda:  1,x
                   pha
                   jmp   ]page+$103

                   jmp   ]page+$1CA
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
                   jmp   ]page+$003

                   lda:  *+9,y
                   pha
                   jmp   ]page+$1F2
                   ds    1
                   dfb   $F4,$00,$00

]page              equ   ]page+$200
                   --^

                   ds    \,$00
                   ldx   STK_SAVE
                   txs
                   lda   STATE_REG_R0W0
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG

                   ldx   #0000
                   txs
                   jmp   ]page
                   lda:  1,x
                   pha
                   jmp   ]page+3

                   jmp   ]page+$1CA
                   lup   64
                   pea   $0000
                   --^
                   jmp   ]page+$103

                   lda:  *+9,y
                   pha
                   jml   lite_base_2
                   dfb   $F4,$00,$00
                   ds    \,$00

                   ldx   STK_SAVE
                   txs
                   lda   STATE_REG_R0W0
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG

                   ldx   #0000
                   txs
                   jmp   ]page+$100
                   lda:  1,x
                   pha
                   jmp   ]page+$103

                   jmp   ]page+$1CA
                   lup   64
                   pea   $0000
                   --^
                   jmp   ]page+$003

                   lda:  *+9,y
                   pha
                   jml   lite_base_2
                   dfb   $F4,$00,$00

                   ds    \,$00                        ; More padding
                   ldx   STK_SAVE
                   txs
                   lda   STATE_REG_R0W0
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG
                   jml   lite_base_2               ; A catch-all in case anyone tries to go past the end

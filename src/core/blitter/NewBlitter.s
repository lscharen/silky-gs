; This is the design for a new blitter which is more aligned with the NES PPU needs.  All of the blitter chunks
; are page-aligned which provides two benefits:

            org     $0000                     ; PEA field for lines from ICRAM page 0 are aligned on even pages

            ldx     STK_SAVE                  ; This first block of code is for enabling interrupts during blitting
            txs                               ; periodiclly.  Currently the default is to enable interrupts every
            lda     STATE_REG_R0W0            ; 16 lines.
            stal    STATE_REG
            cli
            sei
            lda     STATE_REG_BLIT
            stal    STATE_REG

; Now we are byte offset $11.  This is the entry point offset when the scroll origin is
; located in ICRA Mpage 0

            ldx   #0000
            txs

; Use the carry flag to signal even/odd entry.  This eliminates the need to re-patch as the screen scrolls
; horizontalls.  No instructions in the blitter affect the carry flag.

            bcc    :even_entry

; The odd case falls through to these instruction.  The PHA places the edge byte onto the graphics screen and then
; falls into the second patch location.
;
; The Y-register is set before entry.  Its value will depend on whether horizontal or vertical mirroring is enabled.
;
; For horizontal mirroring, the execution remains within a single PEA loop and the instruction that is patched out
; hold the left and right edge bytes.  Since the right edge of the screen corresponds to the low byte, which is
; replaced by the BRA opcode, the right bytes needs to be loaded from the save area.
;
; For vertical mirroring, the BRA instructio is in the other PEA loop, so the save area holds data for just the left
; edge.  In this case, the right edge needs to be loaded from the PEA instruction just prior to the entry point. 

            lda:   $0000,y
            pha

; Entry patch location.  The entry point could be in the first or second page, so the branch does need to be a full
; 16-bit write.

:even_entry brl    $0000                        ; Patched, total time 4 + 6

; This is the core code structure of the PEA field.  It is comprised of 64 PEA instructions with various control
; flow instructions on either end.  The code exits this infinite loop by patching in a BRA instruction at the
; appropriate location.

            jmp   exit_even
            jmp   exit_odd
fld_start
            lup   64
            pea   $0000
            --^
            bvc   fld_next                      ; The next page is close enough to that a reative branch can reach
            jmp   fld_start                     ; for veritical mirroring.  Otherwise loop within this 256-pixel segment

; This is a patch location that holds the copy of the PEA operans that was patched out by the BRA
; instruction.  This is needed in order to restore the PEA instructions after the blitter finishes.

exit_even
patch3      dfb   $F4,$00,$00                ; Storage for the patched PEA data, also executable code for even case

            jmp   $0000                      ; Jump to the next line at either $xx00 or $xx11 depending
            ds    1                          ; Space for when the exit vector is a JML to cross a bank

; This is the odd-aligned exit point
exit_odd
            lda:  patch3+2                   ; Load from the patch save location.
            pha
            jmp   $0000
            ds    1                          ; Space for when the exit vector is a JML to cross a bank

            ds    \,$00                      ; Go to the next page
            ds    $1F                        ; Pad 31 bytes so the PEA instructions are at the same offset

            jmp   exit_even
            jmp   exit_odd
fld_next
            lup   64
            pea   $0000
            --^
            bvc   *+5                        ; Need to use a longer jump to loop around from here
            jmp   fld_start                  ; Horizontal mirroring stay local
            jmp   fld_prev

            jmp   exit_even                  ; Fastest to jump spend 3 cycles to jump back
            ds    4
            jmp   exit_odd

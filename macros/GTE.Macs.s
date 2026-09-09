jne     mac
        beq   *+5
        jmp   ]1
        <<<

jeq     mac
        bne   *+5
        jmp   ]1
        <<<

; Marker macro used in conjunction with scrips/gen-include.js.  A macro both can't
; be empty otherwise the assembly process terminated after "Replace Macros with Code..."
; with no error message.
mput    mac
        ds   0                ;       include module ]1
        <<<

_Deref  MAC
        phb                   ; save caller's data bank register
        pha                   ; push high word of handle on stack
        plb                   ; sets B to the bank byte of the pointer
        lda   |$0002,x        ; load the high word of the master pointer
        pha                   ; and save it on the stack
        lda   |$0000,x        ; load the low word of the master pointer
        tax                   ; and return it in X
        pla                   ; restore the high word in A
        plb                   ; pull the handle's high word high byte off the
                                ; stack
        plb                   ; restore the caller's data bank register    
        <<<

; There are two 1kb physical pages of Console Internal RAM (CIRAM) that back the four nametables. We need
; to convert the logical PPU address that's in the range $2000 - $2FFF into the internal RAM address.
;
; If VERTICAL mirroring, then CIRAM A10 == PPU A10:  ciram_addr = ppu_arr & 0x07FF
; If HORIZONTAL mirroring, then CIRAM A10 = PPU A11: ciram_addr = ((ppu_addr & 0x0800) >> 1) | (ppu_addr & 0x03FF)

ppu2ciram MAC
        andl MirrorMaskLong   ; V = 0x07FF (keep A10 only), H = 0x0BFF (clear A10, keep A11)
        cmp  #$0800           ; Test for A11, if V then carry is always clear
        bcc  *+5
        eor  #$0C00           ; If H *and* A11 = 1, then clear A11 and set A10
        <<<

; Calculates the logical tile row from a CIRAM address.  This does depend on the mirroring mode. When
; horizontal mirroring is enabled, the second CIRAM page has logical rows 30 through 59.  When vertical
; mirroring is enabled, the second CIRAM page rows and just 0 through 29, like the first page.
;
; We isolate bits 5:10 from the CIRAM address. The mask is set based on the mirroring mode and the
; row is adjusted if the high bit is set.  We preserve the quirk that rows 30 and 31 can appear twice
ciram2row MAC
        andl  CIRAMRowMask    ; V = 0x3E0, H = 0x7E0
        lsr
        lsr
        lsr
        lsr
        lsr                   ; Move the 6-bit coarse y value into the low bits
        cmp   #32             ; Are we into the second page?
        bcc   skip
        sbc   #2              ; Adjust so that the first row on the second page is 30, not 32
skip
        <<<

ciram2rowX8 MAC
        andl  CIRAMRowMask    ; V = 0x3E0, H = 0x7E0
        lsr
        lsr
        cmp   #$0100          ; Are we into the second page?
        bcc   skip
        sbc   #$0010          ; Adjust so that the first row on the second page is 30, not 32
skip
        <<<

ciram2rowX32 MAC
        andl  CIRAMRowMask    ; V = 0x3E0, H = 0x7E0
        cmp   #$0400          ; Are we into the second page?
        bcc   skip
        sbc   #$0040          ; Adjust so that the first row on the second page is 30, not 32
skip
        <<<

; Calculates the logical tile column from a CIRAM address.  Under vertical mirroring the second
; CIRAM page holds columns 32 through 63; under horizontal mirroring both pages are columns 0-31.
;
; column = coarse_x + (page ? 32 : 0)   [vertical]
; column = coarse_x                     [horizontal]
ciram2col MAC
        andl  CIRAMColMask    ; V = $041F, H = $001F
        cmp   #$0400
        bcc   skip
        eor   #$0420          ; clear bit 10, set bit 5
skip
        <<<
; ppu_nametable2.s - NES CIRAM-to-PEA-Field Mapping Initialization
;
; The NES PPU has 2KB of nametable RAM that covers a 4KB address space
; ($2000-$2FFF) through mirroring.  This file contains the initialization
; routines that build the lookup tables used to map every internal NES
; nametable tile address to the corresponding location in the IIgs PEA code
; field.
;
; The PPU only has 2kb of RAM, which has to cover 4kb of address space ($2000 - $2FFF). The solution
; in the NES is to mirror hald of the address space either "vertically" or "horizontally".  This
; terminology comes from the fact that the 4kb address space is accessed by the PPU as a 2x2 grid
;
; +-----+-----+
; |  A  |  B  |
; +-----+-----+
; |  C  |  D  |
; +-----+-----+
;
; When horizontal mirroring is enabled, the left column (A+C) references the same RAM as the right columns (B+D),
; so [$2000,$23FF] === [$2400,$27FF] and [$2800,$2BFF] === [$2C00,$2FFF]
;
; Vertical mirroring is similar, except that it is the rows that are paired, so (A+B) references the same RAM
; as (C+D)
;
; Unlike the ppu_nametable.s which work on the logical PPU addresses, this routine directly models the
; underlying 2kb of console internal RAM (CIRAM) which have a fixed 1:1 mapping to the PEA field.
;
; This removes the need to recalculate the tables when the mirroring changes.
;
; The first nametable is always in the A location, so it's logical row and column values are fixed.  The second
; nametable is logically in the D position and appears in C or B depending on mirroring, so it's logical row
; and column *does* change when mirroring changes.  We will maintain that data table until the rest of the
; engine canbe revised to remove this dependency.

        mx    %00
_InitCIRAMTileMapping
:row       equ  tmp3
:col       equ  tmp4
:ciramAddr equ  tmp5

        stz  :row
        stz  :col
        stz  :ciramAddr

:loop
        jsr  :initCIRAMBank0
        jsr  :initCIRAMBank1
        
        inc  :ciramAddr             ; Advance to the next address in the CIRAM memory

        lda  :col
        inc
        sta  :col
        cmp  #32                    ; The first nametable is always logical columns 0 - 31
        bcc  :loop

        stz  :col
        lda  :row
        inc
        sta  :row
        cmp  #30                    ; The first nametable is always logical rows 0 - 29
        bcc  :loop

        rts

:initCIRAMBank0

        lda  :row
        asl
        asl
        asl
        asl
        tay                          ; Will use the for lookup later (line = row * 8)

        lda  :col
        asl
        asl
        tax                          ; Use this for a lookup
        clc
        lda  BTableLow,y             ; Load the base address of the PEA row

        and  #$FF00                  ; Just keep the page
        adc  Col2CodeOffset+2,x      ; Combine with the current column (get the left half of the tile)
        adc  #_PEA_OFFSET
        ldx  :ciramAddr

        sep  #$20                    ; Switch to 8-bit mode to store the values
        stal PPU_MEM+TILE_ADDR_LO,x  ; Store the low byte of the PEA tile address
        xba
        stal PPU_MEM+TILE_ADDR_HI,x  ; Store the high byte of the PEA tile address

        lda  BTableHigh,y            ; Load the bank byte
        stal PPU_MEM+TILE_BANK,x     ; Store it in the PPU bank (Nametable 1)

        rep  #$21
        rts

:initCIRAMBank1

        lda  :row
        asl
        asl
        asl
        asl
        tay                             ; Will use the for lookup later (line = row * 8)

        lda  :col
        asl
        asl
        tax                             ; Use this for a lookup
        clc
        lda  BTableLow+{240*2},y        ; Load the base address of the PEA row for the second buffer

        and  #$FF00                     ; Just keep the page
        adc  Col2CodeOffset+2,x         ; Combine with the current column (get the left half of the tile)
        adc  #_PEA_OFFSET
        ldx  :ciramAddr

        sep  #$20                         ; Switch to 8-bit mode to store the values
        stal PPU_MEM+TILE_ADDR_LO+$400,x  ; Store the low byte of the PEA tile address
        xba
        stal PPU_MEM+TILE_ADDR_HI+$400,x  ; Store the high byte of the PEA tile address

        lda  BTableHigh,y                 ; Load the bank byte
        stal PPU_MEM+TILE_BANK+$400,x     ; Store it in the PPU bank (Nametable 1)

        rep  #$21
        rts

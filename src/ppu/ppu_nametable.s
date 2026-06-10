; ppu_nametable.s - NES Nametable-to-PEA-Field Mapping Initialization
;
; The NES PPU has 2KB of nametable RAM that covers a 4KB address space
; ($2000-$2FFF) through mirroring.  This file contains the initialization
; routines that build the lookup tables used to map every NES nametable tile
; address to the corresponding location in the IIgs PEA code field.
;
; The double-buffered NT/AT update queues and their processing routines live
; in ppu_queues.s.  Called once at startup from PPUStartUp in ppu_init.s.
;
; The mapping depends on the mirroring mode selected at compile time:
;
;   Vertical mirroring:   [$2000,$23FF] = [$2800,$2BFF]   (A mirrors C)
;                         [$2400,$27FF] = [$2C00,$2FFF]   (B mirrors D)
;   Horizontal mirroring: [$2000,$23FF] = [$2400,$27FF]   (A mirrors B)
;                         [$2800,$2BFF] = [$2C00,$2FFF]   (C mirrors D)
;
; Called once at startup from PPUStartUp in ppu.s.
;
; HMIRROR_ADDR = PPU_ADDR & $FBFF
; VMIRROR_ADDR = PPU_ADDR & $FDFF
;
; Set up the lookup table to map the PPU Nametable tiles to the PEA field.
;
; The mapping varies depending on whether horizontal or vertical mirroring is set up.  Since this
; is core to the PPU emulation, some extra explanation.
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
; This impacts the emulation layer in two ways.  First, we do not have a 2kb shadow RAM for the PPU.  Instead,
; the PEA field that draws the graphics has two nametable's worth of memory and is reconfigured based on the
; mirroring, so when a PPU address is written, it need to be mapped into the appropriate PEA table location.
; Second, the runtime maintains several shadow RAM areas that cover the full 4kb of memory to make it fast to
; look up data
;
; HMIRROR_ADDR = PPU_ADDR & $FBFF
; VMIRROR_ADDR = PPU_ADDR & $FDFF

        mx    %00
_InitPPUTileMappingVert
:row     equ  tmp3
:col     equ  tmp4
:ppuaddr equ  tmp5

; Run through the PEA field block addresses and then map the information to
; the appropriate PPU Nametable locations

        stz  :row
        stz  :col

:loop
        jsr  :setVerticalMirror

        lda  :col
        inc
        sta  :col
        cmp  #64                    ; There are two sets of 32 tiles each in the PEA field
        bcc  :loop

        stz  :col
        lda  :row
        inc
        sta  :row
        cmp  #30                    ; There are 30 rows of tiles
        bcc  :loop
        rts

; Load the information about the PEA tile at (:col, :row) and store it in the appropriate PPU address location
:setVerticalMirror

; First, do some pre-calculations that are the same regardless which nametable we're in

        lda  :row                    ; Multiple the row by 32
        asl
        asl
        asl
        asl
        tay                          ; Will use the for lookup later (line = row * 8)
        asl
        sta  :ppuaddr                ; Save

; Next, pick a routine to use based on which nametable the current tile is in

        lda  :col
        cmp  #32
        bcc  :left

        and  #$001F                  ; Clamp the address for nametable 1
        ora  :ppuaddr
        ora  #$2400                  ; Go to the second nametable
        sta  :ppuaddr
        bra  :common

:left
        ora  :ppuaddr                ; We already know the value is less than 32, merge with the base address
        ora  #$2000                  ; And set the offset to nametable 0
        sta  :ppuaddr

:common
        lda  :col
        asl
        asl
        tax                          ; Use this for a lookup
        clc
        lda  BTableLow,y             ; Load the base address of the PEA row

        and  #$FF00                  ; Just keep the page
        adc  Col2CodeOffset+2,x      ; Combine with the current column (get the left half of the tile)
        adc  #_PEA_OFFSET
        ldx  :ppuaddr

        sep  #$20                         ; Switch to 8-bit mode to store the values
        stal PPU_MEM+TILE_ADDR_LO+$000,x  ; Store the low byte of the PEA tile address
        stal PPU_MEM+TILE_ADDR_LO+$800,x
        xba
        stal PPU_MEM+TILE_ADDR_HI+$000,x  ; Store the high byte of the PEA tile address
        stal PPU_MEM+TILE_ADDR_HI+$800,x

        lda  BTableHigh,y              ; Load the bank byte
        stal PPU_MEM+TILE_BANK+$000,x  ; Store it in the PPU bank (Nametable 1)
        stal PPU_MEM+TILE_BANK+$800,x  ; Store it in the PPU bank (Nametable 3)

        lda  :row
        stal PPU_MEM+TILE_ROW,x
        stal PPU_MEM+TILE_ROW+$800,x

        lda  :col
        stal PPU_MEM+TILE_COL,x
        stal PPU_MEM+TILE_COL+$800,x

        rep  #$21
        rts

        mx    %00
_InitPPUTileMappingHorz
:row     equ  tmp3
:col     equ  tmp4
:ppuaddr equ  tmp5
:row_idx equ  tmp6
; Run through the PEA field block addresses and then map the information to
; the appropriate PPU Nametable locations

        stz  :row
        stz  :col

:loop
        jsr  :setHorizontalMirror

        lda  :col
        inc
        sta  :col
        cmp  #32
        bcc  :loop

        stz  :col
        lda  :row
        inc
        sta  :row

        cmp  #60                    ; There are 60 rows of tiles with the stacked nametables
        bcc  :loop
        rts

; Load the information about the PEA tile at (:col, :row) and store it in the appropriate PPU address location
:setHorizontalMirror

; First, do some pre-calculations that are the same regardless which nametable we're in

        lda  #$2000
        sta  :ppuaddr                ; Assume first nametable
        stz  :row_idx

        lda  :row                    ; Multiple the row by 32
        cmp  #30
        bcc  :top
        sbc  #30
        ldy  #$2800                  ; In the bottom nametable
        sty  :ppuaddr
        ldy  #30*16                  ; Index into the next table
        sty  :row_idx
:top
        asl
        asl
        asl
        asl
        tay                          ; Will use the for lookup later (line = row * 8) where row = 0 to 59
        asl
        ora  :ppuaddr                ; Save
        sta  :ppuaddr

        tya
        adc  :row_idx
        tay

; Next, add the column (0 - 31)

        lda  :col
        ora  :ppuaddr                ; We already know the value is less than 32, merge with the base address
        sta  :ppuaddr

        lda  :col
        asl
        asl
        tax                          ; Use this for a lookup
;        clc
        lda  BTableLow,y             ; Load the base address of the PEA row (rows 0 - 59)

        and  #$FF00                  ; Just keep the page
;        ora  Col2PageOffset+2,x
;        adc  Col2CodeOffset+2,x      ; Combine with the current column (get the left half of the tile)
        adc  Col2CodeOffset+2,x
        adc  #_PEA_OFFSET
        ldx  :ppuaddr

        sep  #$20                         ; Switch to 8-bit mode to store the values
        stal PPU_MEM+TILE_ADDR_LO+$000,x  ; Store the low byte of the PEA tile address
        stal PPU_MEM+TILE_ADDR_LO+$400,x
        xba
        stal PPU_MEM+TILE_ADDR_HI+$000,x  ; Store the high byte of the PEA tile address
        stal PPU_MEM+TILE_ADDR_HI+$400,x

        lda  BTableHigh,y              ; Load the bank byte
        stal PPU_MEM+TILE_BANK+$000,x  ; Store it in the PPU bank (Nametable 1)
        stal PPU_MEM+TILE_BANK+$400,x  ; Store it in the PPU bank (Nametable 3)

        lda  :row
        stal PPU_MEM+TILE_ROW,x
        stal PPU_MEM+TILE_ROW+$400,x

        lda  :col
        stal PPU_MEM+TILE_COL,x
        stal PPU_MEM+TILE_COL+$400,x

        rep  #$21
        rts

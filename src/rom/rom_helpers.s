; Subroutines for working with ROM data, primarily tiles
;
            mx %00

; ROM_CompileBackgroundTiles
;
; Compile all 256 tiles of the background pattern table (bgadr) out of the tiledata bank, which
; build.js has already filled with every converted CHR-ROM tile (scripts/lib/nromBuild.js).  The
; tiledata bank holds pattern table $0000 in its first half and $1000 in its second half; there
; is sufficient room to compile *all* 256 tiles.
ROM_CompileBackgroundTiles

            ldal bgadr           ; address in PPU memory to read for each tile 
            cmp  #$1000
            lda  #$0000
            ror                  ; pattern table select determines if the tile is saved in first or second half of memory

            ldy  #0              ; start at the beginning of the bank
:loop
            pha                  ; save the tiledata source address (A) across the call
            phy                  ; save the compiled tile slot address (Y) across the call

            ldx  #^tiledata
            jsl  CompileTileL

            pla
            clc
            adc  #$100           ; the next compiled tile slot is 256 further
            tay

            pla
            clc
            adc  #128          ; the next set of tile bitmap lookup data is 128 bytes in the tiledata bank

            cpy  #0              ; did we reach the end of the bank?
            bne  :loop
            rts

; ConvertROMTile3, ROMTileToBitmap, ConvertROMTile2, ROMTileToLookup, reverse2,
; reverse4, TileBuff, and the DLUT2/DLUT2_shft/DLUT4/MLUT4 lookup tables live
; in rom_tiles.s (put alongside this file by each game's Main.s) -- see that
; file for the low-level CHR-ROM decoding this file's loaders call into.

            mput  rom_color.s

; Convert NES palette entries to IIgs
; X = NES palette (16 color indices)
; A = 32 byte array to write results
NES_PaletteToIIgs
            sta   tmp0
            stz   tmp1

:loop       lda:  0,x
            jsr   NES_ColorToIIgs
            ldy   tmp1
            sta   (tmp0),y

            inx
            inx

            iny
            iny
            sty   tmp1
            cpy   #32
            bcc   :loop
            rts

; Help to take a palette of 16 NES colors and convert them to IIgs
; colors and set a specific palette on the IIgs SHR screen
;
; A = palette number
; X = NES color palette address
NES_SetPalette
            pha
            lda   #TmpPalette
            jsr   NES_PaletteToIIgs

            pla
            ldx   #TmpPalette
            jmp   _SetPalette

TmpPalette  ds    32

; Initialize the swizzle pointer to the set of palette maps.  The pointer must
;
; 1. Be page-aligned
; 2. Point to 8 2kb remapping tables
; 3. The first 4 tables are for background tiles and second are for sprites
;
; A = high word, X = low word
;
; The compiled sprites have the sprite palettes' colors compiled in, so a different map drops them.
NES_SetPaletteMap
            cmp   SwizzlePtr+2
            bne   :changed
            cpx   SwizzlePtr
            beq   :set
:changed    pha
            jsl   SprRequestFlushL
            pla
:set
            sta   SwizzlePtr+2
            sta   SwizzlePtr2+2
            sta   ActivePtr+2
            stx   SwizzlePtr
            stx   ActivePtr
            txa
            clc
            adc   #$0800            ; Pre-advance to the sprite table
            sta   SwizzlePtr2
            rts

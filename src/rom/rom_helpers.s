; Subroutines for working with ROM data, primarily tiles
;
            mx %00

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

; rom_tiles.s - Low-level NES CHR-ROM tile conversion routines
;
; Extracts NES pattern-table (CHR-ROM) tile data and converts it from the
; interleaved bit-plane format into the layouts the runtime's compiled
; tile/sprite renderers expect. Split out of rom_helpers.s so it can be
; assembled (and unit tested) without the per-game tile-loading/sprite-
; compilation machinery in that file -- see tests/rom/rom_tiles.test.mjs.
;
; Exports: ConvertROMTile3, ROMTileToBitmap, ConvertROMTile2, ROMTileToLookup,
;          reverse2, reverse4, TileBuff, DLUT2, DLUT2_shft, MLUT4,
;          FastROMTileToLookup, RLUT0_HI, RLUT0_LO, RLUT1_HI, RLUT1_LO,
;          FastROMMaskedTileToLookup, TILE_MASK, TILE_REVERSE
;          (DLUT4 is commented out -- unused, see INPROGRESS.md)
;
            mx %00

; Low-level utility functions to extract the NES Tile data and convert it
; from the interleaved format into something that the runtime can handle
; more efficiently.


; X = address in the rom file
; A = address to write
;
; This keeps the tile in 2-bit mode in a format that makes it easy to look up pixel data
; based on a dynamic palette selection
;
; Tiles are stored in a pre-shifted, 16-bit format (2 bits per pixel): 0000000w wxxyyzz0
; When rendered, the 2-bit palette selection is passed in bits 9 and 10 and ORed with
; the palette data to create a single word of 00000ppw wxxyyzz0.  This value is used
; to index directly into a 2048-byte swizzel table that will load the appropriate
; pixel data for the word.  There are 2 swizzle tables, one for tiles and one for sprites
; that take care of mapping the 25 possible on-screen colors to a 16-color palette.
ConvertROMTile3
            phy                       ; Save y -- this is the compiled address location to use
            jsr   ROMTileToBitmap
            ply

; Now we have the NES pixel data in a more linear format that matches the IIgs screen

            lda   #TileBuff
            ldx   #^TileBuff
            jmp   CompileTile

ROMTileToBitmap
:DPtr       equ   tmp1
:save       equ   tmp2

; This routine is used for background tiles, so there is no need to create masks or
; to provide alternative vertically and horizontally flipped variants.  Instead,
; we leverage this to create optimized, compiled representations of the background tiles

            jsr   ROMTileToLookup      ; A = address to write, X = address in CHR ROM

; The :DPtr is set to point at the data buffer, so now convert the lookup values to data nibbles

            sep   #$30                ; 8-bit mode
            ldy   #0
:loop
            lda   (:DPtr),y           ; Load the index for this tile byte
            tax
            lda   DLUT2_shft,x        ; Look up the two, 2-bit pixel values for this quad of bits.  This remains a 4-bit value
            sta   tmp3

            iny
            lda   (:DPtr),y
            tax
            lda   DLUT2,x             ; Look up the two, 2-bit pixel values for next quad of bits
            ora   tmp3                ; Move it into the top nibble since it will decode to the top-byte on the SHR screen

            dey
            asl
            sta   (:DPtr),y
            iny
            lda   #0
            rol
            sta   (:DPtr),y

            iny
            cpy   #32
            bcc   :loop

            rep    #$30
            rts

ConvertROMTile2
:DPtr       equ   tmp1
:MPtr       equ   tmp2

            jsr   ROMTileToLookup

; Now we have 32 bytes (4 x 8) with each byte being a 4-bit value that holds two pairs of bits
; from the PPU pattern table.  We use these 4-bit values as lookup indices into tables
; that decode the values differently depending on the use case.

            sta   :DPtr
            clc
            adc   #32                ; Move to the mask
            sta   :MPtr

            lda   #0                 ; Zero out high byte
            sep   #$30               ; 8-bit mode
            ldy   #0

:loop
            lda   (:DPtr),y           ; Load the index for the initial high nibble
            tax
            lda   MLUT4,x             ; Look up the mask value for this byte. This table decodes the 4 bits into an 8-bit mask
            sta   (:MPtr),y

            lda   DLUT2,x             ; Look up the two, 2-bit pixel values for this quad of bits.  This remains a 4-bit value
            asl
            asl
            asl
            asl
            sta   tmp3

            iny
            lda   (:DPtr),y
            tax
            lda   DLUT2,x             ; Look up the two, 2-bit pixel values for next quad of bits
            ora   tmp3                ; Move it into the top nibble since it will decode to the top-byte on the SHR screen

            dey
            sta   (:DPtr),y           ; Put in low byte
            iny
            lda   #0
            sta   (:DPtr),y           ; Zero high byte

            lda   MLUT4,x
            sta   (:MPtr),y

            iny
            cpy   #32
            bcc   :loop

; Reverse and shift the data

            rep    #$30
            ldy    #8
            ldx    :DPtr

:rloop
            lda:   0,x              ; Load the word: xx00
            jsr    reverse2         ; Reverse the bottom byte in chunks of 2 bits
            asl                     ; Shift by 1 for indexing
            sta:   66,x
            asl:   0,x              ; Shift the original word, too

            lda:   2,x
            jsr    reverse2
            asl
            sta:   64,x
            asl:   2,x

            lda:   32,x
            jsr    reverse4
            sta:   98,x
            lda:   34,x
            jsr    reverse4
            sta:   96,x

            inx
            inx
            inx
            inx
            dey
            bne    :rloop
            rts

; Build a table of index values for the ROM tile data.  The different routines
; can mix and match the lookup table information as they see fit
;
; X = address in the rom file
; A = address to write
;
; For each byte of pattern table memory, we create two bytes in the DPtr with
; a lookup value for the pixels corresponding to bits in that location
;
; Example:
;   Tile 0: $03,$0F,$1F,$1F,$1C,$24,$26,$66, $00,$00,$00,$00,$1F,$3F,$3F,$7F
;
;                                      0,1  2,3  4,5  6,7
;
;   $03 | 00000011 | 00000000 | $00 -> 0000 0000 0000 0011 -> 00 00 05 00
;   $0F | 00001111 | 00000000 | $00 -> 0000 0000 0011 0011 -> 00 00 55 00
;   $1F | 00011111 | 00000000 | $00 -> 0000 0001 0011 0011 -> 01 00 55 00
;   $1F | 00011111 | 00000000 | $00 -> 0000 0001 0011 0011 -> 01 00 55 00
;   $1C | 00011100 | 00011111 | $1F -> 0000 0101 1111 1100 -> 03 00 FA 00
;   $24 | 00100100 | 00111111 | $3F -> 0000 1110 1101 1100 -> 0E 00 BA 00
;   $26 | 00100110 | 00111111 | $3F -> 0000 1110 1101 1110 -> 0E 00 BE 00
;   $66 | 01100110 | 01111111 | $7F -> 0101 1110 1101 1110 -> 3E 00 BE 00
;
;
; e.g. Plane 0   = 0101 0001 (LSB)
;      Plane 1   = 1001 0001 (MSB)
;
;      For speed, use a table and convert one pair at a time
;
;      Pair 1 = 1001 -> 1001
;      Pair 2 = 0101 -> 0011
;      Pair 3 = 0000 -> 0000
;      Pair 4 = 0101 -> 0011
;
;      Lookup[0] = 10 01 00 11
;      Lookup[1] = 00 00 00 11
;
;      Tile Data  = 63 00 03 00
;      Pixel Data = 12 03 00 03

ROMTileToLookup
:DPtr       equ   tmp1
            pha
            phx

            sta   :DPtr
            lda   #0                 ; Clear A and B

            sep   #$20               ; 8-bit mode
            ldy   #0

:loop

; Top two bits from each byte defines the two left-most pixels

            ldal  CHR_ROM,x          ; Load the low bits
            and   #$C0
            lsr
            lsr
            sta   tmp0

            ldal  CHR_ROM+8,x        ; Load the high bits
            and   #$C0
            ora   tmp0
            lsr
            lsr
            lsr
            lsr
            sta   (:DPtr),y          ; First byte
            iny

; Repeat for bits 4 & 5

            ldal  CHR_ROM,x
            and   #$30
            lsr
            lsr
            sta   tmp0

            ldal  CHR_ROM+8,x
            and   #$30
            ora   tmp0
            lsr
            lsr
            sta   (:DPtr),y
            iny

; Repeat for bits 2 & 3

            ldal  CHR_ROM,x
            and   #$0C
            lsr
            lsr
            sta   tmp0

            ldal  CHR_ROM+8,x
            and   #$0C
            ora   tmp0               ; Combine the two and create a lookup value
            sta   (:DPtr),y
            iny

; Repeat for bits 0 & 1

            ldal  CHR_ROM,x          ; Load the high bits
            and   #$03
            sta   tmp0

            ldal  CHR_ROM+8,x
            and   #$03
            asl
            asl
            ora   tmp0                ; Combine the two and create a lookup value
            sta   (:DPtr),y
            iny

            inx
            cpy   #32
            bcc   :loop

            rep    #$20
            plx
            pla
            rts

; FastROMMaskedTileToLookup -- direct CHR_ROM -> tiledata conversion for one tile
;                              plus masks.
;
; Only called from 
            mx    %00
FastROMMaskedTileToLookup

            phb                        ; save the current bank (defensive)

            phk
            plb
            jsr   FastROMTileToLookup  ; build the data tile in tiledata memory

            pea   #^tiledata           ; work fully within the tiledata bank
            plb


            ldy   TileDataPtr          ; load the base address of the tile data
:loop
            ldx:  0,y                  ; load the data word (0000_000w_wxxy_yzz0). LSB is always zero.
            ldal  TILE_MASK,x          ; load the mask for this word (512 byte lookup table)
            sta:  32,y
            ldal  TILE_REVERSE,x       ; load the reversed value
            sta:  66,y
            tax
            ldal  TILE_MASK,x
            sta:  98,y

            ldx:  2,y           ; load the data word (0000_000w_wxxy_yzz0). LSB is always zero.
            ldal  TILE_MASK,x          ; load the mask for this word (512 byte lookup table)
            sta:  34,y
            ldal  TILE_REVERSE,x       ; load the reversed value
            sta:  64,y
            tax
            ldal  TILE_MASK,x
            sta:  96,y

            tya
            clc
            adc   #4
            tay
            and   #$001F
            bne   :loop

            plb                 ; pop the extra byte we pushed to get into the tiledata bank
            plb
            rts


; FastROMTileToLookup -- direct CHR_ROM -> tiledata conversion for one tile
;
; Unlike ROMTileToLookup (which builds a 32-byte intermediate lookup-index
; buffer for ROMTileToBitmap to walk a second time via DLUT2/DLUT2_shft),
; this looks up each CHR-ROM byte directly against the RLUT0_*/RLUT1_*
; tables (see the derivation above them) and writes the final pre-shifted
; tiledata bytes in a single pass -- no intermediate buffer, no second walk.
;
; X = CHR-ROM offset of the tile's low bit-plane byte (8 bytes, followed by
; 8 high bit-plane bytes at X+8 -- standard NES tile layout, same convention
; as ROMTileToLookup). TileDataPtr (a 24-bit far pointer, expected from the
; assembly context -- tiledata lives in its own dedicated bank, see
; core/static/TileData.s, so a plain 2-byte direct-page pointer can't reach
; it) must already point at the tile's 32-byte destination slot in tiledata.
;
; Trashes X (advances by 8, to one past the tile's low bit-plane data) and
; TileDataPtr's contents are read but not modified -- Y carries the running
; write offset into it instead, so the same tile can be reconverted without
; the caller having to re-point TileDataPtr in between.
;
; Y does double duty: it's the running 0..31 write offset into tiledata
; across the whole loop, but is briefly repurposed as the RLUT lookup index
; for each CHR-ROM byte (a value 0-255, unrelated to the write offset) --
; phy/ply bracket that reuse so the write offset survives.
;
; A = destination in the tiledata bank (assumes it is within the allocated range)
; X = address in the CHR-ROM bank

            mx    %00
FastROMTileToLookup
TileDataPtr equ   tmp0
            sta   TileDataPtr
            lda   #^tiledata
            sta   TileDataPtr+2

            lda   #0                  ; clear the accumulator, high and low bytes

            sep   #$20                ; 8-bit A; X/Y stay 16-bit throughout
            ldy   #0
:loop
            phy                       ; save the write offset

            ldal  CHR_ROM,x           ; low bit-plane byte for this row
            tay                       ; become the lookup index instead

            lda   RLUT0_LO,y
            sta   tmp3
            lda   RLUT1_LO,y
            sta   tmp4

            ldal  CHR_ROM+8,x         ; high bit-plane byte for this row (X unchanged)
            tay

            lda   RLUT0_HI,y
            ora   tmp3
            sta   tmp3                ; word0, unshifted
            lda   RLUT1_HI,y
            ora   tmp4
            sta   tmp4                ; word1, unshifted

            ply                       ; restore the write offset

; Shift each combined byte into its pre-shifted word and store straight into
; tiledata via TileDataPtr -- one ASL/carry-extract pair per word, same
; technique ROMTileToBitmap uses, just targeting a long indirect pointer
; instead of a same-bank buffer.

            lda   tmp3
            asl   a
            sta   [TileDataPtr],y
            iny
            lda   #0
            rol
            sta   [TileDataPtr],y
            iny

            lda   tmp4
            asl   a
            sta   [TileDataPtr],y
            iny
            lda   #0
            rol
            sta   [TileDataPtr],y
            iny

            inx
            cpy   #32
            bcc   :loop

            rep   #$30
            rts

; Reverse the 2-bit fields in a byte
            mx   %00
reverse2
            php
            sta  tmp0
            stz  tmp1

            sep  #$20

            and  #$C0
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            tsb  tmp1

            lda  tmp0
            and  #$30
            lsr
            lsr
            tsb  tmp1

            lda  tmp0
            and  #$0C
            asl
            asl
            tsb  tmp1

            lda  tmp0
            and  #$03
            asl
            asl
            asl
            asl
            asl
            asl
            ora  tmp1

            plp
            rts

; Reverse the nibbles in a word
            mx   %00
reverse4
            xba
            sta   tmp0
            and   #$0F0F
            asl
            asl
            asl
            asl
            sta   tmp1
            lda   tmp0
            and   #$F0F0
            lsr
            lsr
            lsr
            lsr
            ora   tmp1
            rts


; The lookup tables (DLUT2, DLUT2_shft, MLUT4, TILE_MASK, TILE_REVERSE, RLUT0_HI / LO, RLUT1_HI / LO)
; are in core/Data.s, page-aligned

; Extracted tiles
TileBuff    ds    128



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
;                              plus masks and 
            mx    %00
FastROMMaskedTileToLookup
            jsr   FastROMTileToLookup  ; build the data tile in tiledata memory
            phb

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

; TILE_MASK / TILE_REVERSE -- lookup tables for FastROMMaskedTileToLookup,
; indexed directly by a tiledata pixel word (the pre-shifted "0000000w
; wxxyyzz0" format FastROMTileToLookup writes, i.e. word = combined << 1,
; always even, 0..510). Since the loop above reads them with a 16-bit `ldal
; TABLE,x`, each table is laid out as a flat 512-byte array where TABLE[word]
; and TABLE[word+1] hold the little-endian 16-bit result for index `word` --
; not 512 independently-addressable word entries.
;
; TILE_MASK[word]: expand each of the word's four 2-bit pixel fields into a
; 4-bit mask nibble ($F if that pixel's value is 0 i.e. transparent, $0
; otherwise), matching the two MLUT4 lookups ConvertROMTile2 stores at
; buf[32+y]/buf[32+y+1] for the same word, packed into one 16-bit value.
;
; TILE_REVERSE[word]: reverse the order of the word's four 2-bit pixel
; fields (0000000w wxxyyzz0 -> 0000000z zyyxxww0), i.e. reverse2() of the
; word's pre-shift "combined" byte, re-shifted -- the per-word half of
; ConvertROMTile2's horizontal-flip step (the caller is responsible for
; swapping which of the row's two words each result lands in).
;
; Both derived and verified against scripts/lib/nesTileConvert.js's
; convertRomTile2() -- 20,000/20,000 random tiles plus zero/solid edge cases
; matched byte-for-byte when combined with FastROMMaskedTileToLookup's
; row-at-a-time loop (including the TILE_MASK[TILE_REVERSE[w]] ==
; reverse4(TILE_MASK[w]) identity the loop relies on for the h-flip mask).

TILE_MASK   db    $FF,$FF,$FF,$F0,$FF,$F0,$FF,$F0,$FF,$0F,$FF,$00,$FF,$00,$FF,$00
            db    $FF,$0F,$FF,$00,$FF,$00,$FF,$00,$FF,$0F,$FF,$00,$FF,$00,$FF,$00
            db    $F0,$FF,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$0F,$F0,$00,$F0,$00,$F0,$00
            db    $F0,$0F,$F0,$00,$F0,$00,$F0,$00,$F0,$0F,$F0,$00,$F0,$00,$F0,$00
            db    $F0,$FF,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$0F,$F0,$00,$F0,$00,$F0,$00
            db    $F0,$0F,$F0,$00,$F0,$00,$F0,$00,$F0,$0F,$F0,$00,$F0,$00,$F0,$00
            db    $F0,$FF,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$0F,$F0,$00,$F0,$00,$F0,$00
            db    $F0,$0F,$F0,$00,$F0,$00,$F0,$00,$F0,$0F,$F0,$00,$F0,$00,$F0,$00
            db    $0F,$FF,$0F,$F0,$0F,$F0,$0F,$F0,$0F,$0F,$0F,$00,$0F,$00,$0F,$00
            db    $0F,$0F,$0F,$00,$0F,$00,$0F,$00,$0F,$0F,$0F,$00,$0F,$00,$0F,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $0F,$FF,$0F,$F0,$0F,$F0,$0F,$F0,$0F,$0F,$0F,$00,$0F,$00,$0F,$00
            db    $0F,$0F,$0F,$00,$0F,$00,$0F,$00,$0F,$0F,$0F,$00,$0F,$00,$0F,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $0F,$FF,$0F,$F0,$0F,$F0,$0F,$F0,$0F,$0F,$0F,$00,$0F,$00,$0F,$00
            db    $0F,$0F,$0F,$00,$0F,$00,$0F,$00,$0F,$0F,$0F,$00,$0F,$00,$0F,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$FF,$00,$F0,$00,$F0,$00,$F0,$00,$0F,$00,$00,$00,$00,$00,$00
            db    $00,$0F,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$00,$00,$00,$00,$00

TILE_REVERSE db   $00,$00,$80,$00,$00,$01,$80,$01,$20,$00,$A0,$00,$20,$01,$A0,$01
            db    $40,$00,$C0,$00,$40,$01,$C0,$01,$60,$00,$E0,$00,$60,$01,$E0,$01
            db    $08,$00,$88,$00,$08,$01,$88,$01,$28,$00,$A8,$00,$28,$01,$A8,$01
            db    $48,$00,$C8,$00,$48,$01,$C8,$01,$68,$00,$E8,$00,$68,$01,$E8,$01
            db    $10,$00,$90,$00,$10,$01,$90,$01,$30,$00,$B0,$00,$30,$01,$B0,$01
            db    $50,$00,$D0,$00,$50,$01,$D0,$01,$70,$00,$F0,$00,$70,$01,$F0,$01
            db    $18,$00,$98,$00,$18,$01,$98,$01,$38,$00,$B8,$00,$38,$01,$B8,$01
            db    $58,$00,$D8,$00,$58,$01,$D8,$01,$78,$00,$F8,$00,$78,$01,$F8,$01
            db    $02,$00,$82,$00,$02,$01,$82,$01,$22,$00,$A2,$00,$22,$01,$A2,$01
            db    $42,$00,$C2,$00,$42,$01,$C2,$01,$62,$00,$E2,$00,$62,$01,$E2,$01
            db    $0A,$00,$8A,$00,$0A,$01,$8A,$01,$2A,$00,$AA,$00,$2A,$01,$AA,$01
            db    $4A,$00,$CA,$00,$4A,$01,$CA,$01,$6A,$00,$EA,$00,$6A,$01,$EA,$01
            db    $12,$00,$92,$00,$12,$01,$92,$01,$32,$00,$B2,$00,$32,$01,$B2,$01
            db    $52,$00,$D2,$00,$52,$01,$D2,$01,$72,$00,$F2,$00,$72,$01,$F2,$01
            db    $1A,$00,$9A,$00,$1A,$01,$9A,$01,$3A,$00,$BA,$00,$3A,$01,$BA,$01
            db    $5A,$00,$DA,$00,$5A,$01,$DA,$01,$7A,$00,$FA,$00,$7A,$01,$FA,$01
            db    $04,$00,$84,$00,$04,$01,$84,$01,$24,$00,$A4,$00,$24,$01,$A4,$01
            db    $44,$00,$C4,$00,$44,$01,$C4,$01,$64,$00,$E4,$00,$64,$01,$E4,$01
            db    $0C,$00,$8C,$00,$0C,$01,$8C,$01,$2C,$00,$AC,$00,$2C,$01,$AC,$01
            db    $4C,$00,$CC,$00,$4C,$01,$CC,$01,$6C,$00,$EC,$00,$6C,$01,$EC,$01
            db    $14,$00,$94,$00,$14,$01,$94,$01,$34,$00,$B4,$00,$34,$01,$B4,$01
            db    $54,$00,$D4,$00,$54,$01,$D4,$01,$74,$00,$F4,$00,$74,$01,$F4,$01
            db    $1C,$00,$9C,$00,$1C,$01,$9C,$01,$3C,$00,$BC,$00,$3C,$01,$BC,$01
            db    $5C,$00,$DC,$00,$5C,$01,$DC,$01,$7C,$00,$FC,$00,$7C,$01,$FC,$01
            db    $06,$00,$86,$00,$06,$01,$86,$01,$26,$00,$A6,$00,$26,$01,$A6,$01
            db    $46,$00,$C6,$00,$46,$01,$C6,$01,$66,$00,$E6,$00,$66,$01,$E6,$01
            db    $0E,$00,$8E,$00,$0E,$01,$8E,$01,$2E,$00,$AE,$00,$2E,$01,$AE,$01
            db    $4E,$00,$CE,$00,$4E,$01,$CE,$01,$6E,$00,$EE,$00,$6E,$01,$EE,$01
            db    $16,$00,$96,$00,$16,$01,$96,$01,$36,$00,$B6,$00,$36,$01,$B6,$01
            db    $56,$00,$D6,$00,$56,$01,$D6,$01,$76,$00,$F6,$00,$76,$01,$F6,$01
            db    $1E,$00,$9E,$00,$1E,$01,$9E,$01,$3E,$00,$BE,$00,$3E,$01,$BE,$01
            db    $5E,$00,$DE,$00,$5E,$01,$DE,$01,$7E,$00,$FE,$00,$7E,$01,$FE,$01

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

; Look up the 2-bit indexes for the data words
DLUT2       db    $00,$01,$04,$05    ; CHR_ROM[0] = xy, CHR_ROM[8] = 00 -> 0x0y
            db    $02,$03,$06,$07    ; CHR_ROM[0] = xy, CHR_ROM[8] = 01 -> 0x1y
            db    $08,$09,$0C,$0D    ; CHR_ROM[0] = xy, CHR_ROM[8] = 10 ->
            db    $0A,$0B,$0E,$0F    ; CHR_ROM[0] = xy, CHR_ROM[8] = 11

; Shifted version of the table
DLUT2_shft  db    $00,$10,$40,$50    ; CHR_ROM[0] = xy, CHR_ROM[8] = 00 -> 0x0y
            db    $20,$30,$60,$70    ; CHR_ROM[0] = xy, CHR_ROM[8] = 01 -> 0x1y
            db    $80,$90,$C0,$D0    ; CHR_ROM[0] = xy, CHR_ROM[8] = 10 ->
            db    $A0,$B0,$E0,$F0    ; CHR_ROM[0] = xy, CHR_ROM[8] = 11

; Look up the 4-bit indexes for the data words
; Unused -- no remaining call site references DLUT4. Commented out rather
; than deleted (see INPROGRESS.md legacy-helper removal assessment).
;DLUT4       db    $00,$01,$10,$11    ; CHR_ROM[0] = xx, CHR_ROM[8] = 00
;            db    $02,$03,$12,$13    ; CHR_ROM[0] = xx, CHR_ROM[8] = 01
;            db    $20,$21,$30,$31    ; CHR_ROM[0] = xx, CHR_ROM[8] = 10
;            db    $22,$23,$32,$33    ; CHR_ROM[0] = xx, CHR_ROM[8] = 11

MLUT4       db    $FF,$F0,$0F,$00
            db    $F0,$F0,$00,$00
            db    $0F,$00,$0F,$00
            db    $00,$00,$00,$00

; Inverted mask for using eor/and/eor rendering
;MLUT4       db    $00,$0F,$F0,$FF
;            db    $0F,$0F,$FF,$FF
;            db    $F0,$FF,$F0,$FF
;            db    $FF,$FF,$FF,$FF

; Extracted tiles
TileBuff    ds    128


; word0 tables: fold the upper nibble (bits 7-4) of the source byte
RLUT0_HI    db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
            db    $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08
            db    $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
            db    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
            db    $22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22
            db    $28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28
            db    $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A
            db    $80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80
            db    $82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82
            db    $88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88
            db    $8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A,$8A
            db    $A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0
            db    $A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2
            db    $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
            db    $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA

RLUT0_LO    db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
            db    $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
            db    $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
            db    $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
            db    $11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
            db    $14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14
            db    $15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15
            db    $40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40
            db    $41,$41,$41,$41,$41,$41,$41,$41,$41,$41,$41,$41,$41,$41,$41,$41
            db    $44,$44,$44,$44,$44,$44,$44,$44,$44,$44,$44,$44,$44,$44,$44,$44
            db    $45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45
            db    $50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50
            db    $51,$51,$51,$51,$51,$51,$51,$51,$51,$51,$51,$51,$51,$51,$51,$51
            db    $54,$54,$54,$54,$54,$54,$54,$54,$54,$54,$54,$54,$54,$54,$54,$54
            db    $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55

; word1 tables: fold the lower nibble (bits 3-0) of the source byte
RLUT1_HI    db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA
            db    $00,$02,$08,$0A,$20,$22,$28,$2A,$80,$82,$88,$8A,$A0,$A2,$A8,$AA

RLUT1_LO    db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
            db    $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55

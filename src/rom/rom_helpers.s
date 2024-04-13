; Subroutines for working with ROM data, primarily tiles
;
            mx %00

; ROM_LoadBackgroundTiles
;
; Scan a CHR-ROM and convert a set of 256 tiles as background
; tiles.  This means the tiles are converted into a compiled
; tile representation.
;
; Bank is selected by the PPU_BG_TILE_ADDR variable
ROM_LoadBackgroundTiles

            ldx  PPU_BG_TILE_ADDR
            ldy  #0

:tloop
            phx
            phy

            lda  #TileBuff
            jsr  ConvertROMTile3

            clc
            pla
            adc  #$0100          ; Put the next compiled tile on the next page
            tay

            pla
            adc  #16             ; NES tiles are 16 bytes
            tax

            cpx  #16*512         ; Have we done the last background tile?
            bcc  :tloop

            rts

; ROM_LoadSpriteTiles
;
; Scan a CHR-ROM and convert a set of 256 tiles as sprite
; tiles.  Sprite tile are saved as data blocks in order to
; support horizontal and vertical mirroring, as well as
; sprite priority
;
; Bank is selected by the PPU_SPR_TILE_ADDR variable
ROM_LoadSpriteTiles

            ldx  PPU_SPR_TILE_ADDR
            ldy  #0

:sloop
            phx
            phy

            lda  #TileBuff
            jsr  ConvertROMTile2 ; Convert the tile, extract the mask and create horizontally flipped versions

            ldy  #0              ; Copy the converted tile data into the  tiledata bank
            plx
:cploop
            lda  TileBuff,y
            stal tiledata,x
            iny
            iny
            inx
            inx
            cpy  #128
            bcc  :cploop

            txy
            pla
            clc
            adc  #16             ; NES tiles are 16 bytes
            tax

            cpx  #16*256         ; Have we done the last sprite tile?
            bcc  :sloop
            rts

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
:DPtr       equ   tmp1
:save       equ   tmp2

; This routine is used for background tiles, so there is no need to create masks or
; to provide alternative vertically and horizontally flipped variants.  Instead,
; we leverage this to create optimized, compiled representations of the background tiles

            phy                        ; Save y -- this is the compiled address location to use
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
            ora   tmp3                ; Move it int othe top nibble since it will decode to the top-byte on the SHR screen

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

; Now we have the NES pixel data in a more linear format that matches the IIgs screen

            ply
            lda   #TileBuff
            ldx   #^TileBuff
            jmp   CompileTile

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
DLUT4       db    $00,$01,$10,$11    ; CHR_ROM[0] = xx, CHR_ROM[8] = 00
            db    $02,$03,$12,$13    ; CHR_ROM[0] = xx, CHR_ROM[8] = 01
            db    $20,$21,$30,$31    ; CHR_ROM[0] = xx, CHR_ROM[8] = 10
            db    $22,$23,$32,$33    ; CHR_ROM[0] = xx, CHR_ROM[8] = 11

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

; NES Palette (52 entries)
nesPalette
    dw  $0777
    dw  $004A
    dw  $001B
    dw  $0409
    dw  $0A06
    dw  $0C02
    dw  $0C10
    dw  $0910
    dw  $0630
    dw  $0140
    dw  $0050
    dw  $0043
    dw  $0046
    dw  $0000
    dw  $0111
    dw  $0111

    dw  $0CCC
    dw  $007F
    dw  $025F
    dw  $083F
    dw  $0F3B
    dw  $0F35
    dw  $0F20
    dw  $0D30
    dw  $0C60
    dw  $0380
    dw  $0190
    dw  $0095
    dw  $00AD
    dw  $0222
    dw  $0111
    dw  $0111

    dw  $0FFF
    dw  $01DF
    dw  $07AF
    dw  $0D8F
    dw  $0F4F
    dw  $0F69
    dw  $0F93
    dw  $0F91
    dw  $0FC2
    dw  $0AE1
    dw  $03F3
    dw  $01FA
    dw  $00FF
    dw  $0666
    dw  $0111
    dw  $0111

    dw  $0FFF
    dw  $0AFF
    dw  $0BEF
    dw  $0DAF
    dw  $0FBF
    dw  $0FAB
    dw  $0FDB
    dw  $0FEA
    dw  $0FF9
    dw  $0DE9
    dw  $0AEB
    dw  $0AFD
    dw  $09FF
    dw  $0EEE
    dw  $0111
    dw  $0111

; Convert a single NES palette entry to IIgs RGB
; A = NES color index
; Y is overwritten
;
; Returns RGB value in A
NES_ColorToIIgs
            asl
            tay
            lda   nesPalette,y
            rts

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


; Initialize the swizzle pointer to the set of palette maps.  The pointer must
;
; 1. Be page-aligned
; 2. Point to 8 2kb remapping tables
; 3. The first 4 tables are for background tiles and second are for sprites
;
; A = high word, X = low word
NES_SetPaletteMap
            sta   SwizzlePtr+2
            sta   ActivePtr+2
            stx   SwizzlePtr
            stx   ActivePtr
            rts
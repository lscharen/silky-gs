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

            DO   BG_TILES_AS_SPRITES
            ldx  PPU_BG_TILE_ADDR
            ldy  #$8000
:tloop2
            phx
            phy

            lda  #TileBuff
            jsr  ROMTileToBitmap ; Convert the tile, no mask and create horizontally flipped versions

            ldy  #0              ; Copy the converted tile data into the tiledata bank
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

            cpx  #16*512         ; Have we done the last background tile?
            bcc  :tloop2
            FIN
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

; If this sprite is in the compilation list, also compile it

            lda  1,s
            jsr  FindInList
            bcc  :no_match

; Y = address in the compile bank
; A = low address of bitmap
; X = high address of bitmap

            phx
            lsr                  ; A = sprite_idx * 16
            lsr
            lsr                  ; Make it sprite_idx * 2
            tax
            lda  SpriteBankPos
            sta  spr_comp_tbl,x  ; Put the compiled sprite address in the table

            tay
            lda  #TileBuff
            ldx  #^TileBuff
            jsr  CompileSprite
            sty  SpriteBankPos
            plx
:no_match

            txy
            pla
            clc
            adc  #16             ; NES tiles are 16 bytes
            tax

            cpx  #16*256         ; Have we done the last sprite tile?
            bcc  :sloop
            rts

; Find a value in the compiled sprite list
; A = value
; Can use y-reg
FindInList
            ldy #2*{COMPILED_SPRITE_LIST_COUNT-1}
            bmi :no_match

            ldy :compiled_sprite_list
            bmi :match_first_n
            ldy #2*{COMPILED_SPRITE_LIST_COUNT-1}

:loop
            cmp :compiled_sprite_list,y
            beq :match
            dey
            dey
            bpl :loop
:no_match
            clc
            rts
:match
            sec
            rts

:match_first_n
            cmp  #16*COMPILED_SPRITE_LIST_COUNT
            bcc  :match
            bra  :no_match

:compiled_sprite_list COMPILED_SPRITE_LIST

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
   dw $0777
   dw $000f
   dw $000b
   dw $042b
   dw $0908
   dw $0a02
   dw $0a10
   dw $0810
   dw $0530
   dw $0070
   dw $0060
   dw $0050
   dw $0045
   dw $0000
   dw $0000
   dw $0000
   dw $0bbb
   dw $007f
   dw $005f
   dw $064f
   dw $0d0c
   dw $0d05
   dw $0f30
   dw $0d51
   dw $0a70
   dw $00b0
   dw $00a0
   dw $00a4
   dw $0088
   dw $0000
   dw $0000
   dw $0000
   dw $0fff
   dw $04bf
   dw $068f
   dw $097f
   dw $0f7f
   dw $0f59
   dw $0f75
   dw $0f94
   dw $0fb0
   dw $0bf1
   dw $05d5
   dw $05f9
   dw $00ed
   dw $0777
   dw $0000
   dw $0000
   dw $0fff
   dw $0adf
   dw $0bbf
   dw $0dbf
   dw $0fbf
   dw $0fab
   dw $0eca
   dw $0fda
   dw $0fd7
   dw $0df7
   dw $0bfb
   dw $0bfd
   dw $00ff
   dw $0fdf
   dw $0000
   dw $0000

; Convert a single NES palette entry to IIgs RGB
; A = NES color index
; Y is overwritten
;
; Returns RGB value in A
NES_ColorToIIgs
            and   #$003F
            asl
            tay
            lda   nesPalette,y
            rts

; Convert a single NES palette entry to IIgs RGB
; A = NES color index
; X is overwritten
;
; Returns RGB value in A
NES_ColorToIIgs_X
            and   #$003F
            asl
            tax
            lda   nesPalette,x
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
NES_SetPaletteMap
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

; Routines to facilitate automatic palette mapping for games

; Example mapper for donkey kong
mapping     equ   PPU_PALETTE_MAP

; The current IIgs palette index for each NES palette entry. Will match the mapping value for non-negative entries
current     dw    0, -1, -1, -1
            dw    0, -1, -1, -1
            dw    0,  1, -1, -1
            dw    0, -1, -1, -1

            dw    0, -1, -1, -1
            dw    0,  1, -1, -1
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1

iigs_nes_colors ds   32   ; list of NES colors assigned to each IIgs index location

; Given two NES colors, return a value for how close they are.  This should use a table lookup to have
; a custom mapping later, but for now calculate a mahalanobis distance between the two colors.
ABS_VAL     mac
            bpl   done
            eor   #$FFFF
            inc
done
            <<<

color_dist
            pha
            and  #$000F
            pha
            lda  3,s
            and  #$00F0
            sta  3,s

            txa
            and  #$000F
            sec
            sbc  1,s        ; Subtract low nibble
            ABS_VAL
            sta  1,s

            txa
            and  #$00F0
            sec
            sbc  3,s
            ABS_VAL
            lsr
            lsr
            lsr
            lsr
            clc
            adc  1,s
            sta  3,s
            pla
            pla
            rts

; Scan the current palette to see if there is an match to the NES color and return the index
; A = nes color
find_exact_match
            pha
            ldx  #0
:loop
            lda  iigs_nes_colors,x
            cmp  1,s
            beq  :match
            inx
            inx
            cpx  #32
            bcc  :loop

            pla
            lda  #$FFFF
            rts

:match
            pla
            txa
            rts

; Scan the current palette to find the closes color and return the index
; A = nes color
; X/Y are used
find_closest_match
            pea  $ffff                ; best match found so far
            pea  $ffff                ; distance to best match so far

            pha
            ldy  #0
:loop
            lda  iigs_nes_colors,y
            bmi  :skip                ; don't calculate distance to non-colors
            cmp  1,s
            beq  :match               ; cool -- an exact match is great because we can stop early

            tax                       ; compare these two colors
            lda  1,s
            jsr  color_dist
            cmp  3,s
            bcs  :skip

            sta  3,s
            tya
            sta  5,s

:skip       iny
            iny
            cpy  #32
            bcc  :loop

            pla
            pla
            pla             ; best match
            rts

:match
            pla
            pla
            pla             ; ignore because we found an exact match
            tya
            rts

; Build a IIgs palette from a NES palette
;
; Some notes:
;
;  1. We can always ignore entries 0, 4, ..., 24, 28 because they are fixed / ignored as the background or transparent color
;  2. Handle any fixed entries first and look for duplicates in the other palette entries
;  3. Finally, handle the dynamic colors.
BitMask     dw   $0001,$0002,$0004,$0008,$0010,$0020,$0040,$0080
            dw   $0100,$0200,$0400,$0800,$1000,$2000,$4000,$8000

; These are the NES palette locations that need to be scanned
NESPalIndices dw  2,  4,  6, 10, 12, 14, 18, 20, 22, 26, 28, 30
              dw 34, 36, 38, 42, 44, 46, 50, 52, 54, 58, 60, 62

ReverseMap  ds   64*2

; A = bitmask
; return index of the first zero bit: 0 = LSB, 15 = MSB
find_free_slot
            bit  #$8000
            bne  *+6
            lda  #15
            rts

            bit  #$4000
            bne  *+6
            lda  #14
            rts

            bit  #$2000
            bne  *+6
            lda  #13
            rts

            bit  #$1000
            bne  *+6
            lda  #12
            rts

            bit  #$0800
            bne  *+6
            lda  #11
            rts

            bit  #$0400
            bne  *+6
            lda  #10
            rts

            bit  #$0200
            bne  *+6
            lda  #9
            rts

            bit  #$0100
            bne  *+6
            lda  #8
            rts

            bit  #$0080
            bne  *+6
            lda  #7
            rts

            bit  #$0040
            bne  *+6
            lda  #6

            bit  #$0020
            bne  *+6
            lda  #5

            bit  #$0010
            bne  *+6
            lda  #4

            bit  #$0008
            bne  *+6
            lda  #3
            rts

            bit  #$0004
            bne  *+6
            lda  #2

            bit  #$0002
            bne  *+6
            lda  #1

            bit  #$0001
            bne  *+6         ; Value is $FFFF, so returning -1 means no free slots
            lda  #0

            rts


NES_BuildPalette
:bitmask    equ  tmp0

; Initialize the bitmask to indicate that all (except index 0) are free

            lda  #$0001
            sta  :bitmask

; Zero out the reverse map (identified which IIgs palette index contains a NES color)

            ldx  #126
            lda  #$FFFF
:loop0      sta  ReverseMap,x
            dex
            dex
            bpl  :loop0

; Scan the mapping to find the fixed indices and copy their colors

            ldx  #0
:loop1      ldy  NESPalIndices,x
            lda  mapping,y
            bmi  :not_fixed
            sta  current,y          ; Save a copy into the current palette mapping table

            phx                     ; Save the index

            asl
            tax                     ; This is an index into the IIgs palette (0 - 15  (x2))

            jsr  assign_color
            plx                     ; Restore the index

:not_fixed  inx
            inx
            cpx  #{24*2}
            bcc  :loop1

; Scan the mapping to handle the dynamic palette entries

            ldx  #0
:loop2      ldy  NESPalIndices,x
            lda  mapping,y
            bpl  :not_dyn

            phx                     ; Save the index

; First, check if this color is already in the IIgs palette

            lda  nes_palette,y
            asl
            tax
            lda  ReverseMap,x
            bmi  :not_mapped

            lsr
            sta  current,y          ; It is already mapped, so just mark it in the current table
            bra  :next

; This color is not already mapped.  If there is an open slot, then we can assign to that index
:not_mapped
            lda  :bitmask
            cmp  #$FFFF
            beq  :no_free_slot
            jsr  find_free_slot     ; Return index of first zero bit in the bitmask
            sta  current,y

            asl
            tax                     ; This is the index that we will use
            jsr  assign_color
            bra  :next

; At this point, all we can do is find the closest color and use that index
:no_free_slot
            lda  nes_palette,y
            phy
            jsr  find_closest_match
            ply
            sta  current,y

:next       plx
:not_dyn    inx
            inx
            cpx  #{24*2}
            bcc  :loop2

            rts

; X = IIgs palette index (x2)
; Y = NES palette index (x2)
assign_color
            lda  BitMask,x          ; Mark this IIgs palette index as unavailable
            tsb  :bitmask

            lda  nes_palette,y      ; Load the NES color in this palette location
            sta  iigs_nes_colors,x  ; Update the color
            jsr  NES_ColorToIIgs    ; Convert the NES color to IIgs RGB
            stal $E19E00,x          ; Put the RGB color into the hardware palette

            lda  iigs_nes_colors,x
            asl
            tay
            txa
            sta  ReverseMap,y
            rts

; Build a swizzle table
; A/X = pointer to table
; Y = address of palette indices
;
; Create a table of a[y].a[z].a[w].a[x] where w,x,y,z in [0, 1, 2, 3]
; and a[] is the look value from the pal array
NES_BuildSwizzleTable
:ptr equ 11
:pal equ 9
:w   equ 7
:x   equ 5
:y   equ 3
:z   equ 1

            phx
            pha
            phy
            
            pha    ; local variable space
            pha
            pha
            pha

            tsc
            phd
            tcd

;            sta  :ptr
;            stx  :ptr+2
;            sty  :pal

            ldx  #0

            stz  :w
:wloop      stz  :x
:xloop      stz  :y
:yloop      stz  :z
:zloop
            ldy  :y
            lda  (:pal),y
            ldy  :z
            asl
            asl
            asl
            asl
            ora  (:pal),y
            ldy  :w
            asl
            asl
            asl
            asl
            ora  (:pal),y
            ldy  :x
            asl
            asl
            asl
            asl
            ora  (:pal),y

            txy
            sta  [:ptr],y
            inx
            inx

            lda  :z
            inc
            inc
            sta  :z
            cmp  #4*2
            bcc  :zloop

            lda  :y
            inc
            inc
            sta  :y
            cmp  #4*2
            bcc  :yloop

            lda  :x
            inc
            inc
            sta  :x
            cmp  #4*2
            bcc  :xloop

            lda  :w
            inc
            inc
            sta  :w
            cmp  #4*2
            bcc  :wloop

            pld
            tsc
            clc
            adc  #14
            tcs
            rts

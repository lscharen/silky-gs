; chr_convert.s - one CHR tile into the tiledata bank: silky's, out of rom_tiles.s, for both engines.  The tables it reads
; (TILE_MASK, TILE_REVERSE, RLUT0_*, RLUT1_*) are the engine's: PEA keeps them page aligned in its Data.s, the tile engine in ChrTables.s.

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


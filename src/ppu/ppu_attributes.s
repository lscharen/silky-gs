; ppu_attributes.s - NES Attribute Byte and Tile Rendering
;
; This file handles decoding NES PPU attribute bytes and driving per-tile
; updates into the IIgs PEA code field.
;
; Key routines:
;   DrawPPUAttribute      - Decode an attribute byte and call SyncPPUMetatile
;                           for each of the up to 4 metatiles it controls
;   _DrawPPUAttribute     - Alternate entry from the ATQueuePush macro
;   RefreshPPUTiles       - Refresh all 256 tiles in a nametable page
;   DrawPPUTile           - Draw one tile (by PPU address) into the PEA field
;
; patch0 is a jsl instruction label patched at startup (PPUStartUp) with the
; correct bank address for the tile compilation bank.

; Alternate entry point to DrawPPUAttribute from the ATQueuePush macro
        mx    %00
_DrawPPUAttribute
        tya
        sep   #$20
        stal  PPU_MEM+TILE_SHADOW,x

; Draw an attribute from the PPU into the code field by updating any changed metatiles
;
; X = CIRAM attribute address
; A = Attribute value
; B = Attribute EOR value
;
; A = 8 bit, X/Y = 16bit on entry
        mx    %10
DrawPPUAttribute
        bra  :enter

:attr_diff   ds 2
:attr_copy   ds 2
:mt_base0    ds 2
:mt_base2    ds 2
:mt_base64   ds 2
:mt_base66   ds 2

:enter
        sta  :attr_copy             ; Keep a copy of the actual value
        xba
        sta  :attr_diff

; Since we are going to assume at least one of the metatile attributes have changed, caculate the PPU address
; of the upper-left tile of the metatiles corresponding to this attribute byte.

        rep  #$20
        txa                         ; Get the PPU attribute address ($2{n}C0 - $2{n+3}FF)
        and  #$003F                 ; Isolate the attribute offset
        asl                         ; x2 for indexing
        tay

        txa
        and  #$2C00                 ; Keep the nametable bits
        ora  metatile_corner,y      ; Insert the relative offset within the nametable
        tax                         ; This is constant for the ATTR_SHADOW updates
        adc  #$0002                 ; adc #2 faster than two increments
        sta  :mt_base2              ; Calculate the other offsets while it's fast to do so
        adc  #$003E
        sta  :mt_base64
        adc  #$0002
        sta  :mt_base66

        lda  #$0000                 ; Clear accumulator so the high byte is zero in 8-bit mode for tay/tax
        sep  #$20

        lda  :attr_diff
        bit  #$03
        beq  :not_top_left

        lda  :attr_copy
        and  #$03
        asl
        jsr  SyncPPUMetatile

        lda  :attr_diff

:not_top_left
        bit  #$0C
        beq  :not_top_right

        ldx  :mt_base2
        lda  :attr_copy
        and  #$0C
        lsr
        jsr  SyncPPUMetatile

        lda  :attr_diff

:not_top_right
        bit  #$30
        beq  :not_bot_left

        ldx  :mt_base64
        lda  :attr_copy
        and  #$30
        lsr
        lsr
        lsr
        jsr  SyncPPUMetatile

        lda  :attr_diff

:not_bot_left
        bit  #$C0
        beq  :not_bot_right

        ldx  :mt_base66
        lda  :attr_copy
        and  #$C0                 ; This could be done with 4 ROL instructions instead
        lsr
        lsr
        lsr
        lsr
        lsr
        jsr  SyncPPUMetatile

:not_bot_right
        rts

; Draw all of the tiles in one physical (CIRAM) nametable.  The attribute bytes at the end
; of the nametable have a zero TILE_BANK entry, so DrawPPUTile skips them.
;
; X = CIRAM nametable base ($0000 or $0400) -- the PPU_MEM tile tables are indexed by CIRAM
;     address, not by the logical PPU address ($2000-$2FFF)
        mx    %00
RefreshPPUTiles
        php
        sep   #$20
        lda   #$ff
        sta   pputmp
:loop
        ldal  PPU_MEM+TILE_SHADOW,x
        phx
        jsr   DrawPPUTile
        plx
        inx
        ldal  PPU_MEM+TILE_SHADOW,x
        phx
        jsr   DrawPPUTile
        plx
        inx
        ldal  PPU_MEM+TILE_SHADOW,x
        phx
        jsr   DrawPPUTile
        plx
        inx
        ldal  PPU_MEM+TILE_SHADOW,x
        phx
        jsr   DrawPPUTile
        plx
        inx`
        dec   pputmp               ; 256 * 4 iterations
        bne   :loop

        plp
        rts

; Draw a tile from the CIRAM into the code field
;
; X = CIRAM address
; A = Tile value
;
; A = 8 bit, X/Y = 16bit on entry
        mx    %10
DrawPPUTile
        pha                           ; The PEA field must not have patched exits under the tile
        ldal  stkAnyPatched
        beq   :stable
        jsr   _PEAFieldStable
:stable pla

        sta   patch0+2                ; Put the tile ID into the page byte of the address first

        DO    HAS_CHR_RAM
; CHR-RAM support: if this tile ID was marked dirty by a PPUDATA write since
; it was last drawn, recompile it now (FastROMTileToLookup + CompileTile,
; same technique as CheckBgTileDirty in ppu_metatiles.s) before using the
; (possibly stale) compiled code below. A = tile ID, X = PPU address (both
; must be preserved for the rest of the routine).

; ChrRamDirty is indexed 0-511, spanning *both* CHR-RAM pattern tables (see
; PPUDATA_WRITE, ppu_regs.s), so merge in bgadr_lo (0 or $0100) to check the
; table the background is actually reading from right now -- otherwise this
; only ever sees pattern table 0's dirty flags and stale tiles never get
; recompiled whenever bgadr is $1000. The same combined value is reused
; below to derive the CHR-RAM source address (same technique as
; CheckSprTileDirty, ppu.s / CheckBgTileDirty, ppu_metatiles.s).

        phx
        rep   #$20                    ; 16-bit A for the table-offset merge
        and   #$00FF                  ; isolate the tile index
        oral  bgadr_lo
        tax                           ; X = dirty-array index (0-511)

        sep   #$20                    ; back to 8-bit A for the byte-table check/clear
        ldal  ChrRamDirty,x
        bit   #CHRRAM_BG_DIRTY        ; test only the background-form-dirty bit
        beq   :bgt_clean
        and   #CHRRAM_BG_DIRTY!$FF    ; clear only the BG bit, preserve the sprite bit
        stal  ChrRamDirty,x

        rep   #$30                    ; 16-bit A/X/Y for the recompile

; Both the CHR-RAM source address and the tiledata destination stay
; table-aware -- the combined (tile ID | bgadr_lo) index is kept all the way
; through, matching CheckBgTileDirty/CheckSprTileDirty.

        txa                           ; A = combined index (tile ID | bgadr_lo)
        asl   a
        asl   a
        asl   a
        asl   a                       ; A = tile ID * 16 + bgadr (CHR-RAM source address)
        tax                           ; X = CHR-RAM source address (FastROMTileToLookup's X arg)

        asl   a
        asl   a
        asl   a                       ; A = combined index * 128 (tiledata destination)
        pha                           ; save it -- also needed as CompileTile's bitmap-source address

        jsr   FastROMTileToLookup     ; A = tiledata destination, X = CHR-RAM source address -- writes the
                                      ; 32-byte bitmap directly into tiledata; trashes A/X/Y

        lda   1,s                     ; reload the tiledata destination of combined index * 128
        asl   a                       ; one more shift spills the high bit and leaves just the tile ID * 256
        tay                           ; Y = compiled-code destination page (CompileTile's Y arg)

        pla                           ; A = tiledata destination again (CompileTile's "low address of bitmap" arg)
        ldx   #^tiledata              ; X = bank of the bitmap source (CompileTile's "high address" arg)
        jsr   CompileTile             ; A = bitmap source addr, X = bitmap source bank, Y = dest page

        sep   #$20
:bgt_clean
        plx
        FIN

        clc
        ldal  PPU_MEM+ATTR_SHADOW,x   ; Load the palette select byte from shadow memory
        adc   SwizzlePtr+1
        sta   ActivePtr+1             ; Update the high byte of the active palette pointer

        ldal  PPU_MEM+TILE_BANK,x    ; Load the bank byte for tile
        beq   bad_tile               ; If the PPU address is in Attribute range, abort
        phb
        pha
        plb

        ldal  PPU_MEM+TILE_ADDR_HI,x ; Load the high byte for this tile address
        xba
        ldal  PPU_MEM+TILE_ADDR_LO,x ; Load the low byte for this tile address
        tax

        rep   #$21
patch0  jsl   $000000
        sep   #$20
        plb

bad_tile
        rts

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
; patch0 is a CALL_COMPILED_TILE (ppu_macros.s): PPUStartUp patches the compile bank into it, and
; SET_COMPILED_TILE points it at the tile before each call.

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

; Attribute byte index -> offset from its nametable ($2000, $2400, $2800, $2C00) to the top-left tile of
; each metatile (DrawPPUAttribute).  Read with 16-bit index registers, so its alignment doesn't matter.
metatile_corner
]row    =    0
        lup  8
        dw   {128*{]row}}+0
        dw   {128*{]row}}+4
        dw   {128*{]row}}+8
        dw   {128*{]row}}+12
        dw   {128*{]row}}+16
        dw   {128*{]row}}+20
        dw   {128*{]row}}+24
        dw   {128*{]row}}+28
]row    =    ]row+1
        --^

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
        inx
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

; CHR-RAM support: if the game changed the tile in CHR-RAM since it was last compiled, recompile it
; before the call below uses it.  CheckBgTileDirty takes the tile's slot, which SET_COMPILED_TILE has
; just put into the call's address.
        DO    HAS_CHR_RAM
        SET_COMPILED_TILE patch0      ; Point the call below at this tile's compiled code first
        rep   #$20
        lda   patch0+1                ; the slot: tile * 128 | bgadr_hi
        phx
        CHR_INDEX                     ; X = the tile's ChrRamDirty index
        ldal  ChrRamDirty,x
        plx
        bit   #CHRRAM_BG_DIRTY        ; (tested here: the call only when the tile is dirty)
        beq   :chr_ok
        lda   patch0+1
        jsr   CheckBgTileDirty        ; (preserves X and Y)
:chr_ok sep   #$20
        bra   _DrawPPUTileSet
        FIN

; _DrawPPUTile: DrawPPUTile without its checks, for a caller that has made the PEA field stable
; (_PEAFieldStable) and, in a CHR-RAM game, knows the tile is compiled (CheckBgTileDirty).  The same
; registers.
        mx    %10
_DrawPPUTile
        SET_COMPILED_TILE patch0      ; Point the call below at this tile's compiled code
_DrawPPUTileSet
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
patch0  CALL_COMPILED_TILE
        sep   #$20
        plb

bad_tile
        rts

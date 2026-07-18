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
;   RenderPPUAttr         - Process one attribute byte change from the AT queue;
;                           marks tiles with a version stamp so the NT queue
;                           can skip tiles already updated by an attribute change
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
; X = PPU attribute address
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

; Draw all of the tiles
;
; X = nametable base ($2000, $2400, $2800, or $2C00)
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

; Draw a tile from the PPU into the code field
;
; X = PPU address
; A = Tile value
;
; A = 8 bit, X/Y = 16bit on entry
        mx    %10
DrawPPUTile

        sta   patch0+2                ; Put the tile ID into the page byte of the address first

        DO    HAS_CHR_RAM
; CHR-RAM support: if this tile ID was marked dirty by a PPUDATA write since
; it was last drawn, recompile it now (ConvertROMTile3) before using the
; (possibly stale) compiled code below. A = tile ID, X = PPU address (both
; must be preserved for the rest of the routine).
        sta   :p1+1               ; A is 8-bit, but need a 16-bit load.  Can't risk copying a stale high word ffrom A into Y.
        sta   :p2+2               ; This is intentionally going into the high byte (multiply by 256)
:p1     ldy   #$0000
        lda   [TileChrMem],y
        beq   :bgt_clean
        lda   #0
        sta   [TileChrMem],y

        phx
        rep   #$30

        tya
        asl   a
        asl   a
        asl   a
        asl   a                       ; A = tile ID * 16
;        clc                          ; High bits are zero, so carry will be cleared
        adc   #PPU_BG_TILE_ADDR
        tax                           ; X = CHR-RAM source address

        lda   #TileBuff
:p2     ldy   #$0000
        jsr   ConvertROMTile3

        sep   #$20
        plx

:bgt_clean
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

; X = PPU Attribute byte address
; A = 8-bit attribute value

        mx    %10
RenderPPUAttr
:attr_diff equ tmp5
:attr_copy equ tmp6
:mt_base2  equ tmp7              ; metatile base PPU address
:mt_base64 equ tmp10
:mt_base66 equ tmp11
:mt_base   equ tmp12

        sta  :attr_copy             ; Keep a copy of the actual value
        eorl PPU_MEM+TILE_SHADOW,x  ; Get the bit difference from the previous applied value
        sta  :attr_diff

; Store the attribute into the shadow ram

        lda  :attr_copy
        stal PPU_MEM+TILE_SHADOW,x  ; Now that we have the diff, put the actual value into the TILE_SHADOW

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
        sta  :mt_base               ; This is constant for the ATTR_SHADOW updates
        adc  #$0002
        sta  :mt_base2              ; Calculate the tile address offsets for the four
        adc  #$003E                 ; metatiles controlled by this attribute byte
        sta  :mt_base64
        adc  #$0002
        sta  :mt_base66

        lda  #$0000                 ; clear the high byte of the accumulator
        sep  #$20

; Check to see if we're on the bottom of the screen (rows 30 and 31 are invalid).  This row only has the top two metatiles.

        cpy  #$38*2
        bcs  :skip_bot

; First, check the metatile bits in the attribute byte to see if a given metatile has changed its value
; from what is currently in the PPU Nametable RAM and what was last rendered into the PEA field.

        lda  :attr_diff
        bit  #$30
        beq  :not_bot_left

        ldx  :mt_base64
        lda  _ppuversion
        stal PPU_MEM+TILE_VERSION1+$00,x
        stal PPU_MEM+TILE_VERSION1+$01,x
        stal PPU_MEM+TILE_VERSION1+$20,x
        stal PPU_MEM+TILE_VERSION1+$21,x

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
        lda  _ppuversion
        stal PPU_MEM+TILE_VERSION1+$00,x
        stal PPU_MEM+TILE_VERSION1+$01,x
        stal PPU_MEM+TILE_VERSION1+$20,x
        stal PPU_MEM+TILE_VERSION1+$21,x

        lda  :attr_copy
        and  #$C0                 ; This could be done with 4 ROL instructions instead
        lsr
        lsr
        lsr
        lsr
        lsr
        jsr  SyncPPUMetatile

        lda  :attr_diff

:skip_bot
:not_bot_right
        bit  #$03
        beq  :not_top_left

; Metatile address is already in the X-register, so mark these tiles as
; being updated

        ldx  :mt_base
        lda  _ppuversion
        stal PPU_MEM+TILE_VERSION1+$00,x
        stal PPU_MEM+TILE_VERSION1+$01,x
        stal PPU_MEM+TILE_VERSION1+$20,x
        stal PPU_MEM+TILE_VERSION1+$21,x

; The first step is to calculate the tile select value and store that into the appropriate locations
; in a shadow table that is used by the low-level tile drawing code.

        lda  :attr_copy
        and  #$03
        asl
        jsr  SyncPPUMetatile

; Reload the attribute difference and proceed to the next metatile

        lda  :attr_diff

:not_top_left
        bit  #$0C
        beq  :not_top_right

        ldx  :mt_base2
        lda  _ppuversion
        stal PPU_MEM+TILE_VERSION1+$00,x
        stal PPU_MEM+TILE_VERSION1+$01,x
        stal PPU_MEM+TILE_VERSION1+$20,x
        stal PPU_MEM+TILE_VERSION1+$21,x

        lda  :attr_copy
        and  #$0C
        lsr
        jsr  SyncPPUMetatile

:not_top_right
        rts

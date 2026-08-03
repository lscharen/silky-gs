; ppu_metatiles.s - NES Metatile Rendering
;
; This file handles syncing metatile palette state into the IIgs PEA code
; field.  A "metatile" is a 2x2 block of NES tiles (16x16 pixels) that
; shares a single palette assignment from the attribute table.
;
; Key routines:
;   ForceMetatileRefresh  - Debug helper: re-syncs all metatiles from shadow RAM
;   SyncPPUMetatile       - Update one metatile (4 tiles) in the PEA field and
;                           its shadow RAM from a new attribute value
;   RefreshMetatile       - Alternate entry: refresh without changing the value
;
; metatile_corner is a lookup table mapping attribute-byte index to the PPU
; nametable address of the top-left tile of each metatile.
;
; patch1-4 are jsl instruction labels patched at startup (PPUStartUp) with the
; correct bank addresses for the tile compilation banks.

; Wrapper to run through and re-sync the metatiles with the graphics screen.  Mostly used
; as a debugging aid.
        mx %00
ForceMetatileRefresh
        ldy  #0
        pha                         ; work space on stack
:loop
        lda  #$2000
        ora  metatile_corner,y      ; calculate the tile address of the metatile corner
        tax                         ; use for indexing
        sta  1,s                    ; save for later

        phy

        jsr  :do_metatile
        lda  3,s
        clc
        adc  #$0002
        tax
        jsr  :do_metatile
        lda  3,s
        clc
        adc  #$0040
        tax
        jsr  :do_metatile
        lda  3,s
        clc
        adc  #$0042
        tax
        jsr  :do_metatile

        ply
        iny
        iny
        cpy  #64*2                  ; end of the metatile array?
        bcc  :loop

; Refresh the second page
:loop2

        lda  MirrorMaskX
        bit  #$0100
        beq  :horz
        lda  #$2800
        bra  :next
:horz   lda  #$2400
:next
        ora  metatile_corner,y      ; calculate the tile address of the metatile corner
        tax                         ; use for indexing
        sta  1,s                    ; save for later

        phy

        jsr  :do_metatile
        lda  3,s
        clc
        adc  #$0002
        tax
        jsr  :do_metatile
        lda  3,s
        clc
        adc  #$0040
        tax
        jsr  :do_metatile
        lda  3,s
        clc
        adc  #$0042
        tax
        jsr  :do_metatile

        ply
        iny
        iny
        cpy  #64*2                  ; end of the metatile array?
        bcc  :loop2

        pla                         ; pop the work space
        rts

:do_metatile
        sep  #$20
        ldal PPU_MEM+ATTR_SHADOW,x
        jsr  RefreshMetatile
        rep  #$20
        rts

; Sync a metatile value to the PPU data bank and to the code field
;
; This is called "sync" instead of "draw" because this routine takes care
; of updating the various shadow values in the PPU data base as well as
; actually drawing the tiles to the PEA field.
;
; There's a bit of nuance, too, because the bottow row of metatiles that corresponds
; to the top 4 bits of the PPU Attribute bytes does not actually exist and must
; be skipped.  This is detected by storing a zero in the TILE_BANK shadow memory
; since the PEA fields will never be allocated in Bank 00.
;
; X = PPU address of the top-left corner of the metatile
; A = Palette select value for all tiles
; P = 8-bit A / 16-bit XY
        mx    %10
SyncPPUMetatile
        stal PPU_MEM+ATTR_SHADOW+$00,x     ; Store the palette select bits in the shadow page of the PPU MEM bank ($6000 - $7FFF)
        stal PPU_MEM+ATTR_SHADOW+$01,x
        stal PPU_MEM+ATTR_SHADOW+$20,x
        stal PPU_MEM+ATTR_SHADOW+$21,x

        mx    %10
RefreshMetatile                            ; Alternate entry point is not setting a new value, just drawing
        clc
        adc   SwizzlePtr+1                 ; Set the palette selection (used for all 4 tiles)
        sta   ActivePtr+1

        ldal  PPU_MEM+TILE_SHADOW+$00,x
        sta   patch1+2
        DO    HAS_CHR_RAM
        jsr   CheckBgTileDirty
        FIN
        ldal  PPU_MEM+TILE_SHADOW+$01,x
        sta   patch2+2
        DO    HAS_CHR_RAM
        jsr   CheckBgTileDirty
        FIN
        ldal  PPU_MEM+TILE_SHADOW+$20,x
        sta   patch3+2
        DO    HAS_CHR_RAM
        jsr   CheckBgTileDirty
        FIN
        ldal  PPU_MEM+TILE_SHADOW+$21,x
        sta   patch4+2
        DO    HAS_CHR_RAM
        jsr   CheckBgTileDirty
        FIN

        ldal  PPU_MEM+TILE_BANK,x     ; The tiles in the same row will have the same bank
        beq   bad_row2                ; The bottom metatile row is not defined

        phb                           ; Save the current bank

        pha                           ; Point to the PEA code bank
        plb

; Calculate a few values for the next row

        ldal  PPU_MEM+TILE_BANK+$20,x
        pha

; This saves a net amount of 14 cycles

        ldal  PPU_MEM+TILE_ADDR_HI+$20,x
        pha

        ldal  PPU_MEM+TILE_ADDR_LO+$20,x
        pha                                ; Push the address onto the stack directly instead of going through a 16-bit register

; Now get the values for the top two tiles

        ldal  PPU_MEM+TILE_ADDR_HI,x  ; Load the high byte for this tile address
        xba
        ldal  PPU_MEM+TILE_ADDR_LO,x  ; Load the low byte for this tile address
        tax

        rep   #$21                    ; 16-bit mode for the tile copy

patch1  jsl   $000000

        txa
        sec
        sbc   #6                      ; Move to the next PEA tile address
        tax

patch2  jsl   $000000

        plx                           ; Load up for the next row
        plb                           ; This almost never changes... :(

patch3  jsl   $000000

        txa
        sec
        sbc   #6                      ; Move the the next PEA tile address
        tax

patch4  jsl   $000000

        plb                           ; Restore the original bank
        sep   #$20
bad_row2
        rts

; CHR-RAM support: recompile one background tile (ConvertROMTile3) if its
; dirty flag is set, before RefreshMetatile dispatches through the compiled
; tile code. Without this, a metatile whose attribute byte changes before
; DrawPPUTile has ever compiled the referenced tile would jsl into a stale
; or uninitialized compiled-code address and crash.
;
; A = tile ID (8-bit), P = 8-bit A / 16-bit XY (mx %10)
; X (metatile PPU address) is preserved for the caller
        DO    HAS_CHR_RAM
        mx    %10
CheckBgTileDirty
        pha
        phx
        phy

        xba                           ; defensive clear of high accumulator byte
        lda   #0
        xba

        tay                           ; Y = tile ID (zero-extended)
        lda   [TileChrMem],y
        beq   :bgclean
        lda   #0
        sta   [TileChrMem],y
        
        rep   #$30                    ; 16-bit A/X/Y for the recompile
        tya
        pha
        asl   a
        asl   a
        asl   a
        asl   a                       ; A = tile ID * 16
        clc
        adc   #PPU_BG_TILE_ADDR
        tax                           ; X = CHR-RAM source address

        pla
        xba                           ; A = tile ID << 8 (compiled-code dest page)
        tay

        lda   #TileBuff
        jsr   ConvertROMTile3

        sep   #$20
:bgclean
        ply
        plx
        pla
        rts
        FIN

; offset from a nametable ($2000, $2400, $2800, $2C00) to the top-left tile of each metatile
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

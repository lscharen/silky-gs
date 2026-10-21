; ppu_metatiles.s - NES Metatile Rendering
;
; This file handles syncing metatile palette state into the IIgs PEA code
; field.  A "metatile" is a 2x2 block of NES tiles (16x16 pixels) that
; shares a single palette assignment from the attribute table.
;
; Key routines:
;   ForceMetatileRefresh  - Debug helper: re-syncs all metatiles from shadow RAM
;   RefreshPPUAttributes  - Redraw the metatiles that use the given background palettes
;   SyncPPUMetatile       - Update one metatile (4 tiles) in the PEA field and
;                           its shadow RAM from a new attribute value
;   RefreshMetatile       - Alternate entry: refresh without changing the value
;
; patch1-4 are CALL_COMPILED_TILEs (ppu_macros.s): PPUStartUp patches the compile bank into them,
; and SET_COMPILED_TILE points each at its tile before the calls.

; Re-sync every metatile with the graphics screen.  Used by the 'f' key.
        mx %00
ForceMetatileRefresh
        lda  #%1111

; Redraw the metatiles of both physical (CIRAM) nametables that use the given background palettes,
; with the current swizzle tables.  Used when a palette change moves a background palette's colors
; to other IIgs palette slots.  The tile tables are indexed by CIRAM address: page $000 and $400,
; 15 rows of 16 metatiles each (the attribute bytes start at $3C0).
;
; A = background palettes to redraw (bit 0 = palette 0 .. bit 3 = palette 3)
        mx %00
RefreshPPUAttributes
        and  #$000F
        bne  :go
        rts
:go     sta  :mask
        ldx  #$0000                 ; CIRAM address of the metatile's top-left tile
:loop
        ldal PPU_MEM+ATTR_SHADOW,x  ; palette select * 2
        and  #$0006
        tay
        lda  :bits,y
        and  :mask
        beq  :skip
        tya
        phx
        sep  #$20
        jsr  RefreshMetatile        ; A = palette select * 2, X = corner (trashes X and Y)
        rep  #$20
        plx
:skip   inx                         ; next metatile in the row
        inx
        txa
        bit  #$001F
        bne  :loop
        clc                         ; end of a row: skip the row of bottom tiles
        adc  #$0020
        tax
        and  #$03FF
        cmp  #$03C0
        bcc  :loop
        txa                         ; end of a page: skip its attribute bytes
        adc  #$003F                 ; (carry is set)
        tax
        cpx  #$0800
        bcc  :loop

        lda  #DIRTY_BIT_BG0_REFRESH
        tsb  DirtyBits
        rts

:mask   ds   2
:bits   dw   %0001,%0010,%0100,%1000

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
; X = CIRAM address of the top-left corner of the metatile
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
        pha                                ; The PEA field must not have patched exits under the tiles
        ldal  stkAnyPatched
        beq   :stable
        jsr   _PEAFieldStable
:stable pla
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridRecordMetatile           ; Let the grid renderer expose these 4 tiles (preserves A, X, Y)
        FIN
        clc
        adc   SwizzlePtr+1                 ; Set the palette selection (used for all 4 tiles)
        sta   ActivePtr+1

; Point the four calls at the tiles' compiled code (16-bit: the tile ID is loaded into the high byte)

        rep   #$20
        ldal  PPU_MEM+TILE_SHADOW-1+$00,x  ; the tile ID in the high byte
        SET_COMPILED_TILE_HI patch1
        DO    HAS_CHR_RAM
        jsr   CheckBgTileDirty        ; A = the slot; preserves X and Y
        FIN
        ldal  PPU_MEM+TILE_SHADOW-1+$01,x  ; the tile ID in the high byte
        SET_COMPILED_TILE_HI patch2
        DO    HAS_CHR_RAM
        jsr   CheckBgTileDirty        ; A = the slot; preserves X and Y
        FIN
        ldal  PPU_MEM+TILE_SHADOW-1+$20,x  ; the tile ID in the high byte
        SET_COMPILED_TILE_HI patch3
        DO    HAS_CHR_RAM
        jsr   CheckBgTileDirty        ; A = the slot; preserves X and Y
        FIN
        ldal  PPU_MEM+TILE_SHADOW-1+$21,x  ; the tile ID in the high byte
        SET_COMPILED_TILE_HI patch4
        DO    HAS_CHR_RAM
        jsr   CheckBgTileDirty        ; A = the slot; preserves X and Y
        FIN
        sep   #$20

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

patch1  CALL_COMPILED_TILE

        txa
        sec
        sbc   #6                      ; Move to the next PEA tile address
        tax

patch2  CALL_COMPILED_TILE

        plx                           ; Load up for the next row
        plb                           ; This almost never changes... :(

patch3  CALL_COMPILED_TILE

        txa
        sec
        sbc   #6                      ; Move the the next PEA tile address
        tax

patch4  CALL_COMPILED_TILE

        plb                           ; Restore the original bank
        sep   #$20
bad_row2
        rts

; CHR-RAM support: recompile one background tile if its dirty flag is set, before RefreshMetatile
; dispatches through the compiled tile code.  Without this, a metatile whose attribute byte changes
; before DrawPPUTile has ever compiled the referenced tile would jsl into a stale or uninitialized
; compiled-code address and crash.
;
; A = the tile's compiled-code slot (tile * 128 | bgadr_hi, from SET_COMPILED_TILE_HI); 16-bit A, X
; and Y.  X (the metatile's CIRAM address) and Y are preserved; A is not.  The slot >> 7 is the tile's
; ChrRamDirty index (0 - 511: ChrRamDirty spans both CHR-RAM pattern tables, see PPUDATA_WRITE), and
; the slot is also the tile's offset in the tiledata bank.
        DO    HAS_CHR_RAM
        mx    %00
CheckBgTileDirty
        phx
        pha                           ; the slot, which is also the tile's tiledata address
        CHR_INDEX                     ; X = the tile's ChrRamDirty index

        sep   #$20                    ; 8-bit A for the byte-table check/clear
        ldal  ChrRamDirty,x
        bit   #CHRRAM_BG_DIRTY        ; test only the background-form-dirty bit
        beq   :bgclean
        and   #CHRRAM_BG_DIRTY!$FF    ; clear only the BG bit, preserve the sprite bit
        stal  ChrRamDirty,x
        rep   #$20
        phy                           ; (the slot at 3,s)

        lda   3,s
        lsr
        lsr
        lsr
        tax                           ; X = the CHR-RAM source address (index * 16 = slot / 8)
        lda   3,s                     ; A = the tiledata destination (the slot)
        jsr   FastROMTileToLookup     ; writes the 32-byte bitmap directly into tiledata; trashes A/X/Y
        lda   3,s
        tay                           ; Y = the compiled-code slot, A = the bitmap (the same offset)
        ldx   #^tiledata              ; X = bank of the bitmap source
        jsr   CompileTile
        ply
:bgclean
        rep   #$20
        pla                           ; (the slot)
        plx
        rts
        FIN

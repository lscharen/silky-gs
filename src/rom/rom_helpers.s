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

            ldx  bgadr           ; address in PPU memory to read for each tile 

            cpx  #$1000
            lda  #$0000
            ror                  ; pattern table select determines if the tile is saved in first or second half of memory
            tay                  ; starting value of $0000 or $8000

:loop
            phx
            phy

            tya                       ; move the tiledata address into the y-register
            jsr  FastROMTileToLookup

            pla
            clc
            adc  #128               ; Move to the next tiledata slot
            tay

            pla
            clc
            adc  #16                  ; NES tiles are 16 bytes
            tax

            and  #$0FFF          ; did we reach the end of a 4kb block?
            bne  :loop
            rts

; Companion routine to ROM_LoadBackgroundTiles that can be called after the bg tile data is
; converted. There is sufficient room to compile *all* 256 tiles.
ROM_CompileBackgroundTiles

            lda  bgadr           ; address in PPU memory to read for each tile 
            cmp  #$1000
            lda  #$0000
            ror                  ; pattern table select determines if the tile is saved in first or second half of memory

            ldy  #0              ; start at the beginning of the bank
:loop
            pha                  ; save the tiledata source address (A) across the call
            phy                  ; save the compiled tile slot address (Y) across the call

            ldx  #^tiledata
            jsr  CompileTile

            pla
            clc
            adc  #$100           ; the next compiled tile slot is 256 further
            tay

            pla
            clc
            adc  #128          ; the next set of tile bitmap lookup data is 128 bytes in the tiledata bank

            cpy  #0              ; did we reach the end of the bank?
            bne  :loop
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

            ldx  spadr           ; address in PPU memory to read for each tile index

            cpx  #$1000
            lda  #$0000
            ror                  ; pattern table select determines if the tile is saved in first or second half of memory
            tay                  ; starting value of $0000 or $8000

:sloop
            phx                  ; save the PPU pattern table address and the IIgs buffer address
            phy

            lda  #TileBuff
            jsr  ConvertROMTile2 ; convert the tile, extract the mask and create horizontally flipped versions

            ldy  #0              ; copy the converted tile data into the tiledata bank
            plx                  ; this was the y-register value
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

            txy                  ; y register is now 128 bytes ahead of where it was at the start of the loop
            pla                  ; pop the original x register value
            clc
            adc  #16             ; NES tiles are 16 bytes each
            tax

            and  #$0FFF          ; did we reach the end of a 4kb block?
            bne  :sloop
            rts

; Companion routing to ROM_LoadSpriteTiles that can be called after the sprite tile data is
; converted and will compile any tiles that are marked by in the COMPILED_SPRITE_LIST.
;
; The compiled sprite buffer only uses a single bank, so there is not enough space to
; compile all of the sprite tiles, but this is useful for optimizing the drawing of the
; player character or other sprites that are commonly on screen and never have their
; sprite priority bit set.
ROM_CompileSpriteTiles

            lda #2*{COMPILED_SPRITE_LIST_COUNT-1}         ; are any compiled sprite tiles defined?
            bmi :empty_list

            lda :compiled_sprite_list                     ; is there a list of IDs?
            bmi :match_first_n                            ; no, then just compile tiles 0 .. n

            ldy  #0                                       ; scan the compiled sprite list
:loop1
            phy                                           ; save the current index

            lda  :compiled_sprite_list,y                  ; load the tile index
            asl                                           ; make it tile_idx * 2
            tay

            jsr  :compile_sprite_tile

            ply                                           ; restore the current index
            iny
            iny
            cpy  #2*{COMPILED_SPRITE_LIST_COUNT-1}
            bcc  :loop1

:empty_list
            rts

; This is a simple case, just compile the first N sprites
:match_first_n
            ldy  #0                                       ; scan the compiled sprite list

:loop2
            phy                                           ; save the current index

            jsr  :compile_sprite_tile

            ply                                           ; restore the current index
            iny
            iny
            cpy  #2*{COMPILED_SPRITE_LIST_COUNT-1}
            bcc  :loop2

; Common code to actually compile a tile
;
; Y = tile index * 2
; All registers are changed
:compile_sprite_tile
            lda  SpriteBankPos                            ; this is the current free address in the bank
            sta  spr_comp_tbl,y                           ; put the compiled sprite address in the table

            tya                                           ; convert the tile index * 2 into an address in the tiledata bank
            lsr                                           ; put it back as the normal tile_index
            xba                                           ; each tile takes up 128 bytes

            ldx  spadr                                    ; load the sprite pattern table address ($0000 or $1000)
            cpx  #$1000                                   ; put the pattern table select in the carry
            ror  a                                        ; roll the pattern table select into high bit and divide tile_index * 256 by 2 at the same time

            ldy  SpriteBankPos                            ; the CompileSprite routine uses the y-register
            ldx  #^tiledata                               ; read directly from the tiledata bank

            jsr  CompileSprite
            sty  SpriteBankPos                            ; save the updated address for the next compiled sprite
            rts

:compiled_sprite_list COMPILED_SPRITE_LIST

; Find a value in the compiled sprite list
; A = value (index * 16)
; Can use y-reg
FindInList
            ldy #2*{COMPILED_SPRITE_LIST_COUNT-1}
            bmi :no_match

            ldy :compiled_sprite_list
            bmi :match_first_n
            ldy #2*{COMPILED_SPRITE_LIST_COUNT-1}

            pha
            lsr
            lsr
            lsr
            lsr
:loop
            cmp :compiled_sprite_list,y
            beq :match0
            dey
            dey
            bpl :loop
            pla
:no_match
            clc
            rts
:match0
            pla
:match
            sec
            rts

:match_first_n
            cmp  #16*COMPILED_SPRITE_LIST_COUNT
            bcc  :match
            bra  :no_match

:compiled_sprite_list COMPILED_SPRITE_LIST

; ConvertROMTile3, ROMTileToBitmap, ConvertROMTile2, ROMTileToLookup, reverse2,
; reverse4, TileBuff, and the DLUT2/DLUT2_shft/DLUT4/MLUT4 lookup tables live
; in rom_tiles.s (put alongside this file by each game's Main.s) -- see that
; file for the low-level CHR-ROM decoding this file's loaders call into.

            mput  rom_color.s

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
            DO    AUTOMATIC_PALETTE_MAPPING

; Example mapper for donkey kong
mapping     equ   PPU_PALETTE_MAP

; A 16-bit version of the NES palette values.  The high byte is always zero, but it makes it easy to write
; 8-bit values and then read 16-bit values later.  This table must match the layout of the "current" table
; below.  If one changes, then the other must change, too.
nes_palette
bg0_palette ds    8
bg1_palette ds    8
bg2_palette ds    8
bg3_palette ds    8
sp0_palette ds    8
sp1_palette ds    8
sp2_palette ds    8
sp3_palette ds    8

; The current IIgs palette index for each NES palette entry. Will match the mapping value for non-negative entries
current     dw    0, -1, -1, -1
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1

            dw    0, -1, -1, -1
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1
            dw    0, -1, -1, -1

bg0_changed db $ff
bg1_changed db $ff
bg2_changed db $ff
bg3_changed db $ff
sp0_changed db $ff
sp1_changed db $ff
sp2_changed db $ff
sp3_changed db $ff

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
NESPalIndices 
BG0_PAL_IDX dw    2,  4,  6
BG1_PAL_IDX dw   10, 12, 14
BG2_PAL_IDX dw   18, 20, 22
BG3_PAL_IDX dw   26, 28, 30
SP0_PAL_IDX dw   34, 36, 38
SP1_PAL_IDX dw   42, 44, 46
SP2_PAL_IDX dw   50, 52, 54
SP3_PAL_IDX dw   58, 60, 62

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

; Used when the game uses no more than 16 unique colors
NES_BuildStaticPalette
            ldx  #0
:loop1      ldy  NESPalIndices,x
            lda  nes_palette,y          ; What color is in the NES palette
            asl
            tay
            lda  ReverseMap,y           ; Lookup the IIgs palette index for this color

            ldy  NESPalIndices,x
            lsr
            sta  current,y              ; Store the index in the current table

            inx
            inx
            cpx  #{24*2}
            bcc  :loop1

            rts

; Tries to find the best mapping between the current NES palette and the IIgs color palette and updates
; the swizzle tables as needed.  The input data structures are
;
; nes_palette: A 16-bit version of the PPU palette values (0 - 63)
;
; ReverseMap: A mapping from NES Colors (0 - 63) to the IIgs palette index that currently represents that color (-1 is unmapped)
; NESPalIndices: A array of 24 indices that represet the NES palette location that matter.  The first (color 0) of each palette doesn't matter (is transparent)
; mapping: A mapping table the identified reserved entries and other constraints. 
;          $00xx = FIXED (use the value as a literal and add to the reverse map)
;          $40xx = NO_MAP (use the bottom byte as a literal value in the 'current' array, but do not add to the reverse map, e.g. this color cannot be reused)
;          $8xxx = DYNAMIC (can allocate a IIgs index for the NES color in this palette entry)
; current: word[64] - The current IIgs palette index for each NES palette entry.  Negative values are unassigned.
;
; The goal is to try and keep the tile palette mappings as stable as possible so that
; the least amount of tiles need to be redrawn.  The code tracks which palettes have been
; changed and then scans the Attribute bytes to mark the metatiles that need to be redrawn
; because their palette indices are different.

NES_BuildPalette
:bitmask    equ  tmp0

; Initialize the bitmask to indicate that all (except index 0) are free

            lda  #$0001
            sta  :bitmask

; Zero out the reverse map (identifies which IIgs palette index contains a NES color)

            ldx  #126
            lda  #$FFFF
:loop0      sta  ReverseMap,x
            dex
            dex
            bpl  :loop0

; Put color 0 into the map

            lda  nes_palette
            asl
            tax
            stz  ReverseMap,x

; Scan the mapping to find the fixed indices and copy their colors

            ldx  #0
:loop1      ldy  NESPalIndices,x
            lda  mapping,y
            bmi  :not_fixed

            phx                     ; Save the index

            bit  #$4000             ; Is the "NO_MAP" flag set?
            bne  :no_map

            sta  current,y          ; Save a copy into the current palette mapping table
            asl
            tax                     ; This is an index into the IIgs palette (0 - 15  (x2))
            jsr  assign_color
            jsr  add_to_reverse_map
            bra  :next1

:no_map
            and  #$003F
            sta  current,y          ; Save a copy into the current palette mapping table
            asl
            tax                     ; This is an index into the IIgs palette (0 - 15  (x2))
            jsr  assign_color

:next1
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
            jsr  add_to_reverse_map
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
            rts

; X = IIgs palette index
add_to_reverse_map
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

            FIN

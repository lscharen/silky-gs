; Helper functions for manipulating and mapping NES palettes
; onto the IIgs hardware
;
; This is a challenging task because the NES can display up to 25 distinct colors
; on screen at once, but the IIgs can only display 16 colors per scanline.  There
; are no scanline limitations on the NES, so there are some screens that are simply
; not possible to replicate on the IIgs.
;
; However, most games reuse colors heavily and there are often less than 16 colors
; on screen at once, so with clever palette management, we can get close to the 
; original source.
;
; Some of the constraints that we are working under are:
;
; - The IIgs runtime will always redraw sprites on every frame, but background
;   tiles are cached and expensive to draw.  So it is much more efficient to try
;   and keep the background tile colors mapped to the same IIgs palette index
;   across frames.
;
; - Sprite palettes -- especially the player sprite -- often change their colors
;   to refect player state, e.g. invincibility, power-ups, etc.  So it is important
;   to avoid sharing colors with the main charaters palette since that could lead
;   to unexpected color changes in the background or on other sprites that coincidentally
;   share the same color.
;
; - There are some simple games (like Donkey Kong), that use a very limited palette
;   across the entire game and can be configured to use a static color palette.  This
;   is much simpler and more efficient and is available as a runtime option.
;
; Since we must accept that not all games can be perfectly replicated, the runtime support
; tries to include a number of hooks and configuration options to allow per-game heuristics
; to be implemented, and to prioritize certain palettes over others.

color_freq ds 128            ; Technically there are 64 possible colors, but only 52 legal ones

; ROM_CountFreq
;
; Scan the PPU memory and build a frequence table of the current palette colors.
    mx   %00
ROM_CountFreq
    ldx  #126
:lp stz  color_freq,x       ; Clear the array to all zeros (16-bit operations)
    dex
    dex
    bpl  :lp

    php
    sep  #$30
    ldy  #0

:loop
    ldx  NESPalIndices,y    ; Load one of the palette colors that matters.  Mostly skips index 0....
    ldal PPU_MEM+$3F00,x    ; Load the color index from the PPU memory
    tax
    inc  color_freq,x       ; Increment the color count

    iny
    iny
    cpy  #{24*2}
    bcc  :loop

    plp
    rts

; ROM_UpdateFreq
;
; A helper function to incrementally maintain the color_freq table as new values are written to
; X = old color
; A = new color
    mx   %11
ROM_UpdateFreq
    dec  color_freq,x
    tax
    inc  color_freq,x
    rts

; NES_BuildStaticPalette
;
; Build a static palette for the NES game and is used when the game uses no more than 16
; unique colors over all of the game content.
    mx   %00
NES_BuildStaticPalette
    ldx  #0
:loop
    ldy  NESPalIndices,x
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
    bcc  :loop
    rts

    ldx  #0
:loop
    ldy  NESPalIndices,x
    lda  nes_palette,y          ; What color is in the NES palette


    inx
    inx
    cpx  #{24*2}

; NES_BuildGreedyPalette
;
; Scan through the current NES palette and assign colors to IIgs palette indices one at a time.
; The code is structured so that the order of palette evaluation can be easily changed.
;
; Rather than use a bitmask to identify free slots, assume that all of the fixed
; palette indices come first and then increment a free slot counter for each color
; that is needed to be assigned.
    mx   #$00
NES_BuildGreedyPalette
    lda  #FIRST_OPEN_INDEX      ; Defined by the game driver, e.g. SMB reserves 5 colors (background, coin, and the three player colors)
    sta  :next_index

; Generally the background colors take priority, because if we can maintain the same background color mapping
; to the IIgs palette indices, then less redraw needs to happen to get the IIgs graphics screen in sync with
; the current NES color palettes.

    lda  bg0_changed
    bmi  :skip_bg0
    ldy  #{bg0_palette-nes_palette}
    jsr  :assign_all_colors
:skip_bg0

    lda  bg1_changed
    bmi  :skip_bg1
    ldy  #{bg1_palette-nes_palette}
    jsr  :assign_all_colors
:skip_bg1

    ldy  #{bg2_palette-nes_palette}
    jsr  :assign_all_colors
    ldy  #{bg3_palette-nes_palette}
    jsr  :assign_colors_2_and_3

;    ldy  #{sp0_palette-nes_palette}
;    jsr  :assign_all_colors
    ldy  #{sp1_palette-nes_palette}
    jsr  :assign_all_colors
    ldy  #{sp2_palette-nes_palette}
    jsr  :assign_all_colors
    ldy  #{sp3_palette-nes_palette}
;    jmp  :assign_all_colors

:assign_all_colors
    ldx: nes_palette,y
    lda  ReverseMap,x           ; Is this color index already assigned to a IIgs palette index?
    bne  :pal_1_mapped          ; Palette zero is reserved and used as a value for "not assigned"
    lda  :next_index            ; Load the next free IIgs palette index value
    beq  :skip_1                ; No more slot available for new colors
    inc  :next_index
    sta  ReverseMap,x           ; Store it as the reverse mapping
:pal_1_mapped
    sta  current,y              ; Assign this color to BG0[1]
:skip_1

:assign_colors_2_and_3
    ldx: nes_palette+2,y
    lda  ReverseMap,x
    bne  :pal_2_mapped
    lda  :next_index            ; Load the next free IIgs palette index value
    beq  :skip_2
    inc  :next_index
    sta  ReverseMap,x           ; Store it as the reverse mapping
:pal_2_mapped
    sta  current+2,y            ; Assign this color to BG0[2]
:skip_2

    ldx  nes_palette+4,y
    lda  ReverseMap,x
    bne  :pal_3_mapped
    lda  :next_index            ; Load the next free IIgs palette index value
    beq  :skip_3
    inc  :next_index
    sta  ReverseMap,x           ; Store it as the reverse mapping
:pal_3_mapped
    sta  current+4,y            ; Assign this color to BG0[2]
:skip_3

    lda  :next_index
    cmp  #16                    ; Have we exceeded the 16 palette maximum?
    beq  :disable               ; If the next_index is exactly 16, then we didn't assign an invalid value and can skip the checks
    bcs  :repair                ; Otherwise, at least one NES color is assigned to a IIgs palette index >16. Find and fix.
    rts                         ; No problem, return normally

; If the prior code has assigned a palette index >16 for a NES color, find the entries
; that have out-of-bounds values and set them to ... something. Just use the background
; color for now.
;
; Also set the next_index to a zero (a reserved index), so no more color are assigned.  It's
; still ok to call the assign_colors function, becuase there may be colors that can
; be reused from other palettes.
:repair
    lda  current,y
    cmp  #16
    bcc  :ok_1
    ldx  nes_palette,y
    lda  #0
    sta  ReverseMap,x
    sta  current,y
:ok_1

    lda  current+2,y
    cmp  #16
    bcc  :ok_2
    ldx  nes_palette+2,y
    lda  #0
    sta  ReverseMap,x
    sta  current+2,y
:ok_2

    lda  current+4,y
    cmp  #16
    bcc  :ok_3
    ldx  nes_palette+4,y
    lda  #0
    sta  ReverseMap+4,x
    sta  current+4,y
:ok_3

:disable
    stz  :next_index
    rts

; NES_UpdateSwizzleTable
;
; A swizzle table provides a mapping from un-interleaved NES tile data to a 4-bit
; per-pixel word value that can be written to the IIgs video memory.  There is one
; swizzle table per NES palette.
;
; The tiles are stored in a pre-shifted, 16-bit format (2 bits per pixel): 0000000w wxxyyzz0
; When rendered, the 2-bit palette selection is passed in bits 9 and 10 and ORed with
; the palette data to create a single word of 00000ppw wxxyyzz0.  This value is used
; to index directly into a 2048-byte memory block that holds four consecutive swizzel tables
; with the appropriate pixel data for the word.
;
; There are 2 sets of swizzle tables, one for tiles and one for sprites, that take care of
; mapping the 25 possible on-screen colors to a 16-color palette.
;
; Updating a swizzle table requires the code to set the values for a single NES palette index.
; The table has a recursive 4x4 structure as shown below, and within each block each variable
; pair steps from 0 to 3 with the 16-bit value in the table and each subblock had the same symmetry
;
; Also, the table as a whole is anti-symmetric where
; A' = swap(A) and swap exchanges the high and low bytes of the 16-bit word.  This can
; implemented efficiently by using the 65816 XBA instruction.

NES_UpdateSwizzleTable

; UpdateSingle
;
; If only one index is changed, then each block can be updated more efficiently. 

; The W bits change every 4 word, but are constant in each column
; X = block offset
; Y = palette index select
UpdateOnlyW
    lda:  {0*ROW_WIDTH}+{0*COL_WIDTH},x
    and   #$0FFF
    ora   pal_w,y
    sta:  {0*ROW_WIDTH}+{0*COL_WIDTH},x
    

; The X bits change every word, but are contant in each column
UpdateOnlyX

; The Y bits change every 4 rows, and are constant in each row
UpdateOnlyY

; The Z bits change every row, and are constant in each row
UpdateOnlyZ


; _UpdateDiagonalBlock
;
; A diagonal block is one where the outer variables (W and Y) are set to the same NES palette index. The
; block itself is symmetric and can be updated slightly more efficiently, since the two variables will
; map to the same IIgs palette index.
;
; X = block index
; Y = palette index
;
; For a given palette, there are four values that are set that contain the IIgs palette index for the NES palette index. Note that zero is always zero.
; Use a single address offset to reference a mask table.
;
; pal_w  dw  $0000, $5000, $E000, $2000   <-- Example NES palette that is mapped to IIgs indices (0, 5, E, 2) on NES indices (0, 1, 2, 3)
; pal_x  dw  $0000, $0500, $0E00, $0200
; pal_y  dw  $0000, $0050, $00E0, $0020
; pal_z  dw  $0000, $0005, $000E, $0002
_UpdateDiagonalBlock

    sta:  {0*ROW_WIDTH}+{0*COL_WIDTH},x             ; Save this value in the top-left corner, a[0][0]
    ora   pal_x+2
    ora   pal_z+2
    sta:  {1*ROW_WIDTH}+{1*COL_WIDTH},x             ; Save on the next diagonal, a[1][1]
    and   #$F0F0
    ora   pal_x+4
    ora   pal_z+4
    sta:  {2*ROW_WIDTH}+{2*COL_WIDTH},x             ; a[2][2]
    and   #$F0F0
    ora   pal_x+6
    ora   pal_z+6
    sta:  {3*ROW_WIDTH}+{3*COL_WIDTH},x             ; a[3][3]

; Now, fill in the off-diagonal entries. These are calculated in a zig-zag pattern to keep the working value in the acumulator
; and to utilize the XBA symmetry of the block to avoid extra calculations.
;
; +---+---+---+---+
; | 0 | 1 | 2 | 3 |  Order:
; +---+---+---+---+   1 -> XBA -> 4
; | 4 | 5 | 6 | 7 |   8 -> XBA -> 2
; +---+---+---+---+   3 -> XBA -> C -> 9 -> XBA -> 6
; | 8 | 9 | A | B |   7 -> XBA -> D
; +---+---+---+---+   E -> XBA -> B
; | C | D | E | F |
; +---+---+---+---+

    and   #$F0F0                            ; Clear the X/Z nibbles
    ora   pal_x+2
    sta:  {0*ROW_WIDTH}+{1*COL_WIDTH},x     ; Store in location [1]
    xba
    sta:  {1*ROW_WIDTH}+{0*COL_WIDTH},x     ; Store in location [4]
    and   #$FFF0                            ; Only clear the Z nibble, X remains constant
    ora   pal_z+4
    sta:  {2*ROW_WIDTH}+{0*COL_WIDTH},x     ; Store in location [8]
    xba
    sta:  {0*ROW_WIDTH}+{2*COL_WIDTH},x     ; Store in location [2]
    and   #$FFF0                            ; Only clear the Z nibble, X remains constant
    ora   pal_z+2
    sta:  {1*ROW_WIDTH}+{2*COL_WIDTH},x     ; Store in location [6]
    xba
    sta:  {2*ROW_WIDTH}+{1*COL_WIDTH},x     ; Store in location [9]
    and   #$FFF0                            ; Only clear the Z nibble, X remains constant
    ora   pal_z+6
    sta:  {3*ROW_WIDTH}+{1*COL_WIDTH},x     ; Store in location [D]
    xba 
    sta:  {1*ROW_WIDTH}+{3*COL_WIDTH},x     ; Store in location [7]
    and   #$FFF0                            ; Only clear the Z nibble, X remains constant
    ora   pal_z+0
    sta:  {0*ROW_WIDTH}+{3*COL_WIDTH},x     ; Store in location [3]
    xba
    sta:  {3*ROW_WIDTH}+{0*COL_WIDTH},x
    and   #$F0FF                            ; Only clear the X nibble, Z remains constant
    ora   pal_x+6
    sta:  {3*ROW_WIDTH}+{2*COL_WIDTH},x     ; Store in location [E]
    xba
    sta:  {2*ROW_WIDTH}+{3*COL_WIDTH},x     ; Store in location [B]
    rts

; _UpdateOffDiagonalBlock
;
; Updates a 4x4 block of the swizzle table.  Within each block, two of the values remain constant
; and the other two values take on the four index values.  The first index value is always zero
; because it represents the transparent color, so only three of the values need to be set.
;
; When 

_UpdateBlock
    lda  #$0000



    sta: 0,x

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
;
; There are also lookup table provided that return the closest perceptual color to an given
; NES color.  This can be leverages to perform palette decimation or possibly constrain
; the total number of colors used in a game to 16 while degrading fidelity and contrast.

COL_WIDTH   equ  2            ; each cell is a word
ROW_WIDTH   equ  COL_WIDTH*16 ; 4 columns per block; 4 blocks per row

color_freq ds 128             ; Technically there are 64 possible colors, but only 52 legal ones

; Store pre-shifted values for the mapped palette values which can be used to construct
; the swizzle table quickly.
_indexLow
    db  $00,$01,$02,$03,$04,$05,$06,$07
    db  $08,$09,$0A,$0B,$0C,$0D,$0E,$0F
_indexHigh
    db  $00,$10,$20,$30,$40,$50,$60,$70
    db  $80,$90,$A0,$B0,$C0,$D0,$E0,$F0

; Define the fixed swizzle table. Page-aligned and 4kb of memory total
            ds    \,$00
_swizzleTbl ds    4096

; Scratch variables used by _fillSwizzleTable.
; Caller sets _palIdx0..3 to the IIgs palette indices for NES colors 0-3,
; and _tblPtr to the 16-bit base address of the 512-byte swizzle table to fill.

; Temp variables to store the IIgs palette indexes for a NES palette
_palIdx0    equ tmp0
_palIdx1    equ tmp0+1
_palIdx2    equ tmp0+2
_palIdx3    equ tmp0+3

; Temp variables to store the low and high nibbles for each palette index to make it fast
; to construct pairs by ORA instructions.
_nibLo0     equ tmp0+4
_nibLo1     equ tmp0+5
_nibLo2     equ tmp0+6
_nibLo3     equ tmp0+7
_nibHi0     equ tmp0+8
_nibHi1     equ tmp0+9
_nibHi2     equ tmp0+10
_nibHi3     equ tmp0+11

; When Filling the table, each full row has the fixed w/x pair in the low byte
; and each column has a fixed y/z pair in the high byte.
;
; X = row offset (16-bit)
; A = constant (8-bit)
    mx     %10
_fillSwizzleRow
    sta:   _swizzleTbl+{0*COL_WIDTH},x
    sta:   _swizzleTbl+{1*COL_WIDTH},x
    sta:   _swizzleTbl+{2*COL_WIDTH},x
    sta:   _swizzleTbl+{3*COL_WIDTH},x

    sta:   _swizzleTbl+{4*COL_WIDTH},x
    sta:   _swizzleTbl+{5*COL_WIDTH},x
    sta:   _swizzleTbl+{6*COL_WIDTH},x
    sta:   _swizzleTbl+{7*COL_WIDTH},x

    sta:   _swizzleTbl+{8*COL_WIDTH},x
    sta:   _swizzleTbl+{9*COL_WIDTH},x
    sta:   _swizzleTbl+{10*COL_WIDTH},x
    sta:   _swizzleTbl+{11*COL_WIDTH},x

    sta:   _swizzleTbl+{12*COL_WIDTH},x
    sta:   _swizzleTbl+{13*COL_WIDTH},x
    sta:   _swizzleTbl+{14*COL_WIDTH},x
    sta:   _swizzleTbl+{15*COL_WIDTH},x

    rts

; X = row offset (16-bit)
; A = constant (8-bit)
    mx     %10
_fillSwizzleColumn
    sta:   _swizzleTbl+{0*ROW_WIDTH},x
    sta:   _swizzleTbl+{1*ROW_WIDTH},x
    sta:   _swizzleTbl+{2*ROW_WIDTH},x
    sta:   _swizzleTbl+{3*ROW_WIDTH},x

    sta:   _swizzleTbl+{4*ROW_WIDTH},x
    sta:   _swizzleTbl+{5*ROW_WIDTH},x
    sta:   _swizzleTbl+{6*ROW_WIDTH},x
    sta:   _swizzleTbl+{7*ROW_WIDTH},x

    sta:   _swizzleTbl+{8*ROW_WIDTH},x
    sta:   _swizzleTbl+{9*ROW_WIDTH},x
    sta:   _swizzleTbl+{10*ROW_WIDTH},x
    sta:   _swizzleTbl+{11*ROW_WIDTH},x

    sta:   _swizzleTbl+{12*ROW_WIDTH},x
    sta:   _swizzleTbl+{13*ROW_WIDTH},x
    sta:   _swizzleTbl+{14*ROW_WIDTH},x
    sta:   _swizzleTbl+{15*ROW_WIDTH},x
    rts

; _fillSetup
;
; For any of the _fill* functions, start by setting up the index mapping. This
; cost can be amortized over many updates, if needed.
;
; Assumes that _palIdx0..3 are set to the IIgs palette indices for NES colors 0-3.
    mx     %11
_fillSetup
    ldx    _palIdx0
    lda    _indexLow,x
    sta    _nibLo0
    lda    _indexHigh,x
    sta    _nibHi0

    ldx    _palIdx1
    lda    _indexLow,x
    sta    _nibLo1
    lda    _indexHigh,x
    sta    _nibHi1

    ldx    _palIdx2
    lda    _indexLow,x
    sta    _nibLo2
    lda    _indexHigh,x
    sta    _nibHi2

    ldx    _palIdx3
    lda    _indexLow,x
    sta    _nibLo3
    lda    _indexHigh,x
    sta    _nibHi3
    
    rts

; _fillSwizzleBlock
;
; Fill a 4x4 block in the swizzle table.  Assumes that the _nibLo and _nibHi values
; have bee setup properly.
;
; A = yy
; Y = ww
; X = block offset (16-bit)  address = 128*blk_y + 8*blk_x
    mx     %10
_fillSwizzleBlock
    ora    _nibLo0
    sta:   _swizzleTbl+{0*ROW_WIDTH}+{0*COL_WIDTH},x
    sta:   _swizzleTbl+{0*ROW_WIDTH}+{1*COL_WIDTH},x
    sta:   _swizzleTbl+{0*ROW_WIDTH}+{2*COL_WIDTH},x
    sta:   _swizzleTbl+{0*ROW_WIDTH}+{3*COL_WIDTH},x
    and    #$F0
    ora    _nibLo1
    sta:   _swizzleTbl+{1*ROW_WIDTH}+{0*COL_WIDTH},x
    sta:   _swizzleTbl+{1*ROW_WIDTH}+{1*COL_WIDTH},x
    sta:   _swizzleTbl+{1*ROW_WIDTH}+{2*COL_WIDTH},x
    sta:   _swizzleTbl+{1*ROW_WIDTH}+{3*COL_WIDTH},x
    and    #$F0
    ora    _nibLo2
    sta:   _swizzleTbl+{2*ROW_WIDTH}+{0*COL_WIDTH},x
    sta:   _swizzleTbl+{2*ROW_WIDTH}+{1*COL_WIDTH},x
    sta:   _swizzleTbl+{2*ROW_WIDTH}+{2*COL_WIDTH},x
    sta:   _swizzleTbl+{2*ROW_WIDTH}+{3*COL_WIDTH},x
    and    #$F0
    ora    _nibLo3
    sta:   _swizzleTbl+{3*ROW_WIDTH}+{0*COL_WIDTH},x
    sta:   _swizzleTbl+{3*ROW_WIDTH}+{1*COL_WIDTH},x
    sta:   _swizzleTbl+{3*ROW_WIDTH}+{2*COL_WIDTH},x
    sta:   _swizzleTbl+{3*ROW_WIDTH}+{3*COL_WIDTH},x

    tya
    ora    _nibLo0
    sta:   _swizzleTbl+{0*ROW_WIDTH}+{0*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{1*ROW_WIDTH}+{0*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{2*ROW_WIDTH}+{0*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{3*ROW_WIDTH}+{0*COL_WIDTH}+1,x
    and    #$F0
    ora    _nibLo1
    sta:   _swizzleTbl+{0*ROW_WIDTH}+{1*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{1*ROW_WIDTH}+{1*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{2*ROW_WIDTH}+{1*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{3*ROW_WIDTH}+{1*COL_WIDTH}+1,x
    and    #$F0
    ora    _nibLo2
    sta:   _swizzleTbl+{0*ROW_WIDTH}+{2*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{1*ROW_WIDTH}+{2*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{2*ROW_WIDTH}+{2*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{3*ROW_WIDTH}+{2*COL_WIDTH}+1,x
    and    #$F0
    ora    _nibLo3
    sta:   _swizzleTbl+{0*ROW_WIDTH}+{3*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{1*ROW_WIDTH}+{3*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{2*ROW_WIDTH}+{3*COL_WIDTH}+1,x
    sta:   _swizzleTbl+{3*ROW_WIDTH}+{3*COL_WIDTH}+1,x
    rts

; _fillSwizzleTable
;
; Fill the entire 512-byte swizzle table for one NES palette.
;
; Before calling, set:
;   _palIdx0..3 = IIgs palette indices for NES colors 0, 1, 2, 3
;
; The table is divided into 16 rows (one per (ww,xx) pair) and 16 columns
; (one per (yy,zz) pair).  Each row gets a constant low byte written to all
; 16 of its word entries via _fillSwizzleRow; each column gets a constant
; high byte written to all 16 of its word entries via _fillSwizzleColumn.
;
; Low byte  for row    (ww,xx) = _indexHigh[p_ww] | _indexLow[p_xx]
; High byte for column (yy,zz) = _indexHigh[p_yy] | _indexLow[p_zz]
;
; Row offsets (bytes from base):    ww*128 + xx*32 = 0, 32, 64, ..., 480
; Column offsets (high-byte addr):  yy*8   + zz*2  + 1 = 1, 3, 5, ..., 31
;
; A = 8-bit, X/Y = 16-bit
;
; On entry, X/Y contain the index bytes

    mx   %10
_fillSwizzleTable
    php                    ; save caller's P (M and X flags)
    sep  #$20              ; A = 8-bit (M=1); X/Y unchanged (still 16-bit from caller)

    stx  _palIdx0
    sty  _palIdx2          ; Now all four palette indices are set

    sep  #$10
    jsr  _fillSetup        ; Cache some intermediate values
    rep  #$10

; Now, just blast each row and column
    lda  _nibHi0
    ora  _nibLo0

    ldx  #{0*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{0*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo1
    ldx  #{1*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{1*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo2
    ldx  #{2*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{2*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo3
    ldx  #{3*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{3*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    lda  _nibHi1
    ora  _nibLo0
    ldx  #{4*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{4*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo1
    ldx  #{5*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{5*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo2
    ldx  #{6*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{6*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo3
    ldx  #{7*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{7*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    lda  _nibHi2
    ora  _nibLo0
    ldx  #{8*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{8*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo1
    ldx  #{9*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{9*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo2
    ldx  #{10*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{10*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo3
    ldx  #{11*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{11*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    lda  _nibHi3
    ora  _nibLo0
    ldx  #{12*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{12*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo1
    ldx  #{13*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{13*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo2
    ldx  #{14*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{14*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    and  #$F0
    ora  _nibLo3
    ldx  #{15*ROW_WIDTH}+{0*COL_WIDTH}
    jsr  _fillSwizzleRow
    ldx  #{0*ROW_WIDTH}+{15*COL_WIDTH}+1
    jsr  _fillSwizzleColumn

    plp                    ; restore caller's P (M and X flags)
    rts

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
    lda: nes_palette,x      ; Load the color index from nes_palette (already a byte offset)
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
    mx   %00
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
    lda: nes_palette,y
    asl
    tax
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
    lda: nes_palette+2,y
    asl
    tax

    lda  ReverseMap,x
    bne  :pal_2_mapped
    lda  :next_index            ; Load the next free IIgs palette index value
    beq  :skip_2
    inc  :next_index
    sta  ReverseMap,x           ; Store it as the reverse mapping
:pal_2_mapped
    sta  current+2,y            ; Assign this color to BG0[2]
:skip_2

    lda  nes_palette+4,y
    asl
    tax

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
    lda  nes_palette,y
    asl
    tax
    lda  #0
    sta  ReverseMap,x
    sta  current,y
:ok_1

    lda  current+2,y
    cmp  #16
    bcc  :ok_2
    lda  nes_palette+2,y
    asl
    tax
    lda  #0
    sta  ReverseMap,x
    sta  current+2,y
:ok_2

    lda  current+4,y
    cmp  #16
    bcc  :ok_3
    lda  nes_palette+4,y
    asl
    tax    
    lda  #0
    sta  ReverseMap,x
    sta  current+4,y
:ok_3

:disable
    stz  :next_index
    rts

:next_index ds   2           ; scratch: next free IIgs palette slot index (0 = exhausted)

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
; pair steps from 0 to 3 with the 16-bit value in the table and each subblock have the same symmetry
;
; Also, the table as a whole is anti-symmetric where
; A' = swap(A) and swap exchanges the high and low bytes of the 16-bit word.  This can
; implemented efficiently by using the 65816 XBA instruction.

        mx   %00
NES_UpdateSwizzleTable
        rts

; _ClearBlock
;
; Zeros all 16 entries of a 4×4 block of the swizzle table.  Equivalent to calling
; _UpdateBlock with A=0 and all pal_z/pal_x entries zero.
;
; X = block base byte offset (= w*128 + y*8 within the 512-byte palette sub-table)
    mx    %00
_clearSwizzleTable
    lda   #0
    ldx   #{16*ROW_WIDTH}+{16*COL_WIDTH}-2
:loop
    sta:  _swizzleTbl,x
    dex
    dex
    bpl   :loop
    rts

_clearBlock
    ldx   #0
_fillBlock
    sta:  {0*ROW_WIDTH}+{0*COL_WIDTH},x
    sta:  {1*ROW_WIDTH}+{0*COL_WIDTH},x
    sta:  {2*ROW_WIDTH}+{0*COL_WIDTH},x
    sta:  {3*ROW_WIDTH}+{0*COL_WIDTH},x
    sta:  {0*ROW_WIDTH}+{1*COL_WIDTH},x
    sta:  {1*ROW_WIDTH}+{1*COL_WIDTH},x
    sta:  {2*ROW_WIDTH}+{1*COL_WIDTH},x
    sta:  {3*ROW_WIDTH}+{1*COL_WIDTH},x
    sta:  {0*ROW_WIDTH}+{2*COL_WIDTH},x
    sta:  {1*ROW_WIDTH}+{2*COL_WIDTH},x
    sta:  {2*ROW_WIDTH}+{2*COL_WIDTH},x
    sta:  {3*ROW_WIDTH}+{2*COL_WIDTH},x
    sta:  {0*ROW_WIDTH}+{3*COL_WIDTH},x
    sta:  {1*ROW_WIDTH}+{3*COL_WIDTH},x
    sta:  {2*ROW_WIDTH}+{3*COL_WIDTH},x
    sta:  {3*ROW_WIDTH}+{3*COL_WIDTH},x
    rts

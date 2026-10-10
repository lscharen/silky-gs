; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.
; Helper to perform the essential functions of rendering a frame
_ppuctrl     ds  2
_ppuscroll_y dw  0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppuscroll_x dw  0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppumask     ds  2


sprTmp0      equ pputmp
sprTmp1      equ pputmp+2
sprTmp2      equ pputmp+4
sprTmp3      equ pputmp+6
sprTmp4      equ pputmp+8
sprMul160    equ pputmp+12          ; (3 bytes) long pointer to Mul160Tbl
sprXPar      equ pputmp+15          ; (byte) scroll_x & 1, the half-pixel offset of every sprite this frame (byte-positioned sprites only)
sprBankSwap  equ unused174          ; $01 << 8 | ^tiledata: pei / plb selects the tiledata bank, plb back to $01
sprTmp5      equ sprTmp5Hi          ; tiledata bank offset for the tile to draw: $0000 or $8000
; sprCompTbl (Defs.s): long pointer to SPR_COMP_TBL, plus $1000 (the pattern table bit of the key offset)
; for pattern table 1, so the lookup does not fold it into the key (see :blitResolvedSprite)

; SPR_PIXEL_SHIFT (the game's Main.s): sprites are drawn on single pixels, sprShift selects the compiled
; variants shifted one pixel to the right.

; The compiled sprite cache's slots (see SPR_* in Defs.s and CompileSprites.s).  With the shifted
; variants: 2KB, 4 variants of 512 bytes, 32 slots per bank in up to 4 banks.  Without them: 512 bytes,
; 2 variants of 256, 128 slots in one bank.  SPR_FLIP_PAGE is the page offset of the horizontally
; flipped variant, ORed into the slot's SPR_COMP_TBL entry by the dispatch.  The SPR_OWNER and
; SPR_SLOT_TBL tables have room for 128 slots.
        DO    SPR_PIXEL_SHIFT
SPR_SLOT_SIZE equ $0800
SPR_BANK_SLOTS equ 32
SPR_MAX_BANKS equ 4
SPR_FLIP_PAGE equ 2
        ELSE
SPR_SLOT_SIZE equ $0200
SPR_BANK_SLOTS equ 128
SPR_MAX_BANKS equ 1
SPR_FLIP_PAGE equ 1
        FIN
SPR_MAX_SLOTS equ SPR_BANK_SLOTS*SPR_MAX_BANKS

; Set up a sprite for drawing.  X = OAM index (preserved).
;
; Sets sprTmp1 = SHR address, sprTmp4 = horizontal clip amount (0 = no clipping), sprShift = $0004 for
; a sprite on an odd pixel (else 0; SPR_PIXEL_SHIFT) and ActivePtr = the sprite's palette.  A macro, so each sprite size gets its own copy and the setup is not a nested call.
SPR_SETUP mac
        ldal  OAM_COPY,x               ; Y-coordinate
        and   #$00FF
        asl                            ; (carry clear)
        tay
        db    $B7,sprMul160            ; lda [sprMul160],y
        adc   #$2000-{y_offset*160}+x_offset
        sta   sprTmp1

        sep   #$20                     ; Palette: ActivePtr selects the swizzle table of the sprite palette
        ldal  OAM_COPY+2,x
        and   #$03
        asl
        adc   SwizzlePtr2+1            ; (carry clear from the asl)
        sta   ActivePtr+1

        DO    SPR_PIXEL_SHIFT
        ldal  OAM_COPY+3,x             ; X-coordinate: NES pixels to IIgs bytes, the pixel in the byte
        lsr                            ; into the carry.  No scroll correction: the sprite is drawn on
        ELSE                           ; its exact pixel even though the background moves in bytes
        lda   sprXPar                  ; X-coordinate: IIgs byte ((scroll_x & 1) + x) / 2.  The background
        adcl  OAM_COPY+3,x             ; starts at byte scroll_x / 2, so this is the byte that shows the
        and   #$FE                     ; sprite's NES pixel.  (Mask before the shift so that a 0 goes into
        ror                            ; the carry; the carry from the add is bit 8)
        FIN
        rep   #$20
        and   #$00FF
        tay
        DO    SPR_PIXEL_SHIFT          ; (no sep / rep in a DO: Merlin32 applies them to the MX state
        lda   #0                       ; of the code after it even when it is skipped)
        rol                            ; sprShift = 4 on an odd pixel: the shifted variants (+$400)
        asl                            ; (carry clear)
        asl
        sta   sprShift
        tya
        FIN
        adc   sprTmp1                  ; Add to the base address calculated from the Y-coordinate
        sta   sprTmp1                  ; This is the SHR address at which to draw the sprite

        stz   sprTmp4                  ; Clip a sprite that runs off the right edge
        DO    SPR_PIXEL_SHIFT
        cpy   #124                     ; From byte 124 on, sprites are drawn on even pixels: shifted,
        bcc   *+10                     ; one at 124 would run off the edge, and the clipped routines
        stz   sprShift                 ; draw on even pixels
        tya
        sbc   #124                     ; (carry set; 0 at byte 124: not clipped)
        sta   sprTmp4
        ELSE
        cpy   #125
        bcc   *+8
        tya
        sbc   #124                     ; (carry set)
        sta   sprTmp4
        FIN
        <<<

        mx   %00
drawSprites

:spriteCount equ pputmp+10

; Run through the copy of the OAM memory and render each sprite to the graphics screen.  Typically,
; shadowing is disabled during this routine.

; Put some variables on the direct page so we don't have to change the bank in each iteration

        lda   spriteCount
        sta   :spriteCount
        bne   *+3
        rts

        lda   #Mul160Tbl
        sta   sprMul160
        sep   #$20
        lda   #^Mul160Tbl
        sta   sprMul160+2
        DO    1-SPR_PIXEL_SHIFT
        lda   _ppuscroll_x             ; The scroll's half-pixel offset is the same for every sprite
        and   #$01
        sta   sprXPar
        DO    ENABLE_DIRTY_RENDERING
        stal  gqLastPar                ; (the grid renderer's unchanged-sprite skip)
        FIN
        FIN
        rep   #$20
        lda   CMPL_BANK                ; For switching to the tiledata bank and back to $01
        xba
        sta   sprBankSwap
        sep   #$20
        lda   #^PPU_MEM                ; SPR_COMP_TBL's bank (the low word is set for 8x8 mode below, or
        sta   sprCompTbl+2             ; per sprite in 8x16 mode)
        rep   #$20

        ldal  SprFlushReq              ; The sprite swizzle tables changed: the compiled sprites have
        beq   *+5                      ; the old colors
        jsr   SprCacheFlush

; The loop runs with the data bank set to the shadow screen ($01), so compiled sprites are called
; directly.  The bitmap routines switch to the tiledata bank themselves (as_bitmap).

        DO    ENABLE_DIRTY_RENDERING
        jsr   gridRecordsBegin         ; The sprites' records for the grid renderer's next frame
        FIN

        phb                            ; Save the current data bank
        pea   $0101
        lda   :spriteCount             ; Draw the sprites from the last to the first: the NES draws a
        sec                            ; lower OAM index on top
        sbc   #4
        tax

; Determine if we are in 8x8 sprite mode, or 8x16 sprite mode.  Have a specialized loop for
; each.

        lda   _ppuctrl
        bit   #NES_PPUCTRL_SPRSIZE
        bne   :is_8x16

; 8x8 mode: the pattern table is whatever PPUCTRL/spadr currently selects for all sprites (unlike
; 8x16 mode, where each sprite's own tile ID picks the table), so it is set once

        lda   spadr_hi                 ; ($0000 / $8000)
        sta   sprTmp5
        lsr                            ; $8000 -> $1000: pattern table 1's half of SPR_COMP_TBL
        lsr
        lsr                            ; (carry clear)
        adc   #SPR_COMP_TBL            ; (PPU_MEM is at the start of its bank)
        sta   sprCompTbl
        plb

; X = the OAM index for the whole loop, from the last sprite down to 0.  Everything a sprite goes through
; preserves it (a compiled sprite uses only Y), so the loop does not save it.

:oam_loop_8x8

        DO    ENABLE_DIRTY_RENDERING
        ldal  gqSkip,x                ; Unchanged and out of reach of anything redrawn: just record it
        cmp   #$0100                  ; (word = table index | skip flag << 8)
        bcc   :draw8
        jsr   gridRecordSprite8
        bra   :next8
:draw8
        FIN

; The game can hide the sprite's top lines (sprClipTop, see SPRITE_PRE_DRAW and SPRITE_CLIP).

        SPRITE_PRE_DRAW 8
        DO    SPRITE_CLIP
        ldal  sprClipTop
        bne   :clip8
        FIN

        jsr   :setupSprite8
        ldal  OAM_COPY+1,x            ; Tile and attributes
        sta   sprTmp2
        jsr   :blitResolvedSprite

; Restore and continue processing the OAMtable

:next8
        dex
        dex
        dex
        dex
        bpl   :oam_loop_8x8

        plb
        plb
        jmp   SprCacheService         ; Compile the sprite tiles that missed (returns to the caller)

; A sprite with top lines to hide: one that is hidden entirely is not set up, marked or drawn.  The
; others go through the clipped draw routines, with the lines in the high byte of sprTmp4.

        DO    SPRITE_CLIP
:clip8  cmp   #8
        bcs   :hide8
        jsr   :setupSprite8
        ldal  OAM_COPY+1,x
        sta   sprTmp2
        ldal  sprClipTop
        sep   #$20
        sta   sprTmp4+1
        rep   #$20
        lda   sprTmp2
        jsr   :blitResolvedSprite
        bra   :next8
:hide8
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridRecordNone           ; (a record that erases nothing next frame)
        FIN
        bra   :next8
        FIN

:is_8x16
        plb

:oam_loop_8x16

; The game can hide the sprite's top lines (sprClipTop, see SPRITE_PRE_DRAW and SPRITE_CLIP).

        SPRITE_PRE_DRAW 16
        DO    SPRITE_CLIP
        ldal  sprClipTop
        bne   :clip16
        FIN

; Draw both halves of the 8x16 sprite (pattern table select comes from bit 0
; of the tile ID, not from spadr/PPUCTRL -- see :drawSprite16)

        jsr   :setupSprite16
        jsr   :drawSprite16

:next16
        dex
        dex
        dex
        dex
        bpl   :oam_loop_8x16

        plb
        plb
        jmp   SprCacheService         ; Compile the sprite tiles that missed (returns to the caller)

        DO    SPRITE_CLIP
:clip16 cmp   #16                     ; Hidden entirely: not set up, marked or drawn
        bcs   :hide16
        jsr   :setupSprite16
        jsr   :drawSprite16c
        bra   :next16
:hide16
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridRecordNone
        FIN
        bra   :next16
        FIN

:setupSprite8
        SPR_SETUP

        DO   ENABLE_DIRTY_RENDERING
        jmp  gridMarkSprite8           ; The grid renderer erases from the code field, so nothing is
                                       ; saved; just mark the cells that this sprite covers
        ELSE
        rts
        FIN

:setupSprite16
        SPR_SETUP

        DO   ENABLE_DIRTY_RENDERING
        jmp  gridMarkSprite16
        ELSE
        rts
        FIN

; Draw a single 8x16 sprite (both halves)
;
; X = OAM index (0, 4, 8, ..., 248, 252)
; sprTmp1/sprTmp4 already set by :setupSprite16 for the top-left position
;
; Unlike 8x8 mode, the NES ignores PPUCTRL/spadr for 8x16 sprites: bit 0 of the OAM
; tile ID selects the pattern table, and bits 7-1 select the tile pair within it
; (top tile = tile_id & $FE, bottom tile = top tile + 1, both from the same table).
        mx    %00
:drawSprite16
        ldal  OAM_COPY+1,x
        sta   sprTmp2                  ; {attribute, tile_id}

        and   #$0001                   ; isolate the pattern-table select bit
        beq   :spr16_tbl0
        lda   #$8000
        sta   sprTmp5
        lda   #SPR_COMP_TBL+$1000      ; pattern table 1's half of SPR_COMP_TBL
        sta   sprCompTbl
        bra   :spr16_tbl_done
:spr16_tbl0
        stz   sprTmp5
        lda   #SPR_COMP_TBL
        sta   sprCompTbl
:spr16_tbl_done

        lda   sprTmp2
        and   #$FFFE                   ; top-half tile id (pattern-table bit cleared), attribute preserved
        sta   sprTmp2

        bit   #$8000                   ; test the vertical-flip attribute bit
        bne   :spr16_vflip

; Normal order: low tile (tile_id & $FE) on top, low+1 tile on bottom
        lda   sprTmp2
        jsr   :blitResolvedSprite

        lda   sprTmp1
        clc
        adc   #8*160
        sta   sprTmp1

        inc   sprTmp2
        lda   sprTmp2
        jsr   :blitResolvedSprite
        rts

:spr16_vflip
; Flipped order: low+1 tile on top, low tile on bottom -- each half's own
; vertical-flip rendering is already selected by the (unchanged) attribute byte
        inc   sprTmp2
        lda   sprTmp2
        jsr   :blitResolvedSprite

        lda   sprTmp1
        clc
        adc   #8*160
        sta   sprTmp1

        dec   sprTmp2
        lda   sprTmp2
        jsr   :blitResolvedSprite
        rts

; :drawSprite16 with the top sprClipTop lines (1-15) hidden: a half with all of its lines hidden is
; skipped, a half with some hidden has them in the high byte of sprTmp4 (clipped draw routines)
:drawSprite16c
        ldal  OAM_COPY+1,x
        sta   sprTmp2                  ; {attribute, tile_id}

        and   #$0001                   ; isolate the pattern-table select bit
        beq   :c16tbl0
        lda   #$8000
        sta   sprTmp5
        lda   #SPR_COMP_TBL+$1000
        sta   sprCompTbl
        bra   :c16tbl
:c16tbl0
        stz   sprTmp5
        lda   #SPR_COMP_TBL
        sta   sprCompTbl
:c16tbl
        lda   sprTmp2
        and   #$FFFE                   ; top-half tile id
        sta   sprTmp2
        bit   #$8000                   ; vertical flip: the low+1 tile is on top
        beq   *+4
        inc   sprTmp2

        ldal  sprClipTop               ; Top half: min(clip, 8) lines hidden
        cmp   #8
        bcs   :c16bot
        sep   #$20
        sta   sprTmp4+1
        rep   #$20
        lda   sprTmp2
        jsr   :blitResolvedSprite

:c16bot
        lda   sprTmp1
        clc
        adc   #8*160
        sta   sprTmp1
        lda   sprTmp2
        eor   #$0001                   ; the other tile
        sta   sprTmp2
        ldal  sprClipTop               ; Bottom half: max(clip - 8, 0) lines hidden
        sec
        sbc   #8
        bcs   *+5
        lda   #0
        sep   #$20
        sta   sprTmp4+1
        rep   #$20
        lda   sprTmp2
        jmp   :blitResolvedSprite

; Draw a single 8x8 sprite
;
; X = OAM index (0, 4, 8, ..., 248, 252)
; A = OAM[1] and OAM[2], also in sprTmp2
; :blitResolvedSprite is the shared draw tail used by both 8x8 sprites (called
; from the loop, with sprTmp5/sprCompTbl = the current global sprite table, set once)
; and 8x16 sprites (entered directly by :drawSprite16, with sprTmp5/sprCompTbl set
; per-sprite from the OAM tile ID's own pattern-table bit). Requires sprTmp2
; (tile id + attribute) already loaded into A, and sprTmp1/sprTmp4
; (screen address / clip amount) already set up by SPR_SETUP.  DBR = $01.
; X (the OAM index) is preserved: the compiled sprite path uses only Y, and the
; other paths save it.
:blitResolvedSprite

; CHR-RAM: a compiled-sprite hit needs no dirty check -- PPUDATA_WRITE drops a rewritten tile's
; compiled sprites, and SprCompileTile does not keep one whose tile is dirty.  The bitmap paths below
; read the converted tile data directly, so they reconvert a dirty tile first (sprChrCheck).

; This is the point to check if there is a compiled version of this sprite

        ldy  sprTmp4        ; Test if this sprite needs clipping (first test; Y, so X keeps the OAM index)
        DO   SPR_CACHE_STATS
        beq  *+5            ; (the counters put the target out of reach)
        brl  as_bitmap_clip
        ELSE
        bne  as_bitmap_clip
        FIN

        bit  #$2000         ; Is the priority bit set?
        bne  as_bitmap

; The key offset is (pattern table << 12) | (palette << 10) | (tile << 2) | (vertical flip << 1), an index in
; the table of words.  In the attribute and tile word, the flips are bits 15 and 14, the priority bit (13) is
; clear here and the palette is bits 9-8.  The pattern table is left out: sprCompTbl points at its half of
; the table.  The first shift moves the vertical flip into the carry, and the ADC adds it at the bottom; the
; second leaves the horizontal flip in the carry.  The entry is the bank:page of the slot of the compiled
; variants: the horizontally flipped code is at slot + SPR_FLIP_PAGE pages, and with SPR_PIXEL_SHIFT the
; shifted (odd pixel) ones at + $400 / + $600.  Slots are aligned to their size, so the ORs never carry.
; Until the shifted pair is compiled, page bit 0 of the entry is set and the variants' stubs are on the odd
; pages (EmitShiftStubs).

        and  #$C3FF         ; tile, palette and the two flips
        asl                 ; carry = vertical flip
        adc  #0
        asl                 ; carry = horizontal flip
        tay
        lda  [sprCompTbl],y
        beq  sprCacheMiss   ; zero value means no compiled sprite for this key
        bcc  *+5
        ora  #SPR_FLIP_PAGE ; the horizontally flipped variant
        DO   SPR_PIXEL_SHIFT
        ora  sprShift       ; the shifted variant for a sprite on an odd pixel
        FIN

; Vector through the compiled sprite table.  The compiled sprites are in other banks, so just check
; for a sentinel value and manually jump into the compiled sprite code to avoid a double-jump and having to
; have a second jump table in the compile sprite code bank.

        stal csd+2                     ; patch in the page and bank directly (csd+1 is always $00)
        SPR_STAT SPR_ST_HITS

; A hit changes nothing in the cache: it is replaced in the order it was compiled (see SPR_* in Defs.s)

        ldy  sprTmp1                   ; the SHR address for the compiled code (DBR = $01)
csd     jml  $000000
draw_rtn2                             ; Return from compiled sprite
        DO   SHOW_DEBUG_VARS
        lda  #$7777
        stal outlineColor
        phx
        ldx  sprTmp1
        jsr  drawOutline
        plx
        FIN
        rts

; Compiled sprite cache miss.  Y = key offset without the pattern table.  Queue the sprite to be compiled
; after drawSprites (SprCacheService), unless this render's compile quota is already used up, and draw
; the sprite from its bitmap this time.
sprCacheMiss
        SPR_STAT SPR_ST_MISSES
        phx                            ; the OAM index (as_bitmap restores it)
        ldal PPU_MEM+SPR_PEND_CNT
        cmp  #2*SPR_COMPILE_PER_RENDER
        bcs  :no_queue
        tax                            ; X = end of the pending list
        lda  sprTmp5                   ; A = key offset (both horizontal flips are compiled together): Y
        lsr                            ; with the pattern table, $8000 -> $1000
        lsr
        lsr
        phy
        ora  1,s
        ply
        stal PPU_MEM+SPR_PEND,x
        inx
        inx
        txa
        stal PPU_MEM+SPR_PEND_CNT
:no_queue
        bra  as_bitmap_saved

; Finish calculating the jump address. We dispatch differently based on the horizontal flip, vertical
; flip and priority bits. when calling the rendering function, Y = screen address, X = tile data address

        mx    %00
as_bitmap
        phx                           ; the OAM index
as_bitmap_saved
        DO   HAS_CHR_RAM
        jsr  sprChrCheck
        FIN
        DO   SHOW_DEBUG_VARS
        lda  #$FFFF         ; color for priority bit
        stal outlineColor
        FIN
        lda  sprTmp2+1
        and  #$00E0
        lsr
        lsr
        lsr
        lsr
        tax

; Calculate the address of the tile data

        lda  sprTmp2-1
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data -- this clears the carry flag
        ora  sprTmp5                  ; fold in the pattern-table offset ($0000 or $8000)
        pei  sprBankSwap              ; The tile routines read the tile data with DBR = tiledata
        plb
        jsr  (drawProcs,x)
        plb                           ; DBR = $01
        DO   SHOW_DEBUG_VARS
        ldx  sprTmp1
        jsr  drawOutline
        FIN
        plx
        rts

        mx    %00
as_bitmap_clip
        phx                           ; the OAM index
        DO   HAS_CHR_RAM
        jsr  sprChrCheck
        FIN
        lda  sprTmp2+1
        and  #$00E0
        lsr
        lsr
        lsr
        lsr
        tax
        lda  sprTmp2-1
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data -- this clears the carry flag
        ora  sprTmp5                  ; fold in the pattern-table offset ($0000 or $8000)
        pei  sprBankSwap              ; The tile routines read the tile data with DBR = tiledata
        plb
        jsr  (drawProcsClipped,x)
        plb                           ; DBR = $01
        plx
        rts

; CHR-RAM support, for the bitmap draws (as_bitmap, as_bitmap_clip): if the sprite's tile was
; rewritten since it was converted, reconvert it.  sprTmp2 = tile and attributes, sprTmp5 = the
; pattern table select.  DBR = $01.  A, X and Y are trashed.
        DO    HAS_CHR_RAM
        mx    %00
sprChrCheck
        lda  sprTmp5                  ; ($0000 / $8000 -> $0000 / $0100)
        xba
        asl
        pha
        lda  sprTmp2
        and  #$00FF
        ora  1,s                      ; tile | pattern table select: the 0-511 index of ChrRamDirty
        tax
        pla
        ldal ChrRamDirty,x
        bit  #CHRRAM_SPR_DIRTY
        bne  *+3
        rts
        pei  sprBankSwap              ; (with DBR = the tiledata bank, as it was written for)
        plb
        jsr  CheckSprTileDirty
        plb
        rts
        FIN

; CHR-RAM support: reconvert one sprite tile whose sprite dirty flag is set (the
; caller, sprChrCheck, tests it), with FastROMMaskedTileToLookup.
;
; X = the 0-511 index of the tile in ChrRamDirty (tile | pattern table << 8).
; 16-bit A/X/Y; all are trashed.
        DO    HAS_CHR_RAM
        mx    %00
CheckSprTileDirty

; The ChrRamDirty array is indexed 0-511, spanning *both* CHR-RAM pattern
; tables.  Clear the flag with an 8-bit store: a 16-bit one would also write the next
; tile's flags, which the NES task may set in between.

        sep   #$20
        ldal  ChrRamDirty,x
        and   #CHRRAM_SPR_DIRTY!$FF   ; clear only the sprite bit, preserve the BG bit
        stal  ChrRamDirty,x
        rep   #$20

        txa                           ; get back the value $0 - $1FF
        asl   a
        asl   a
        asl   a
        asl   a
        tax                           ; X = CHR-RAM source address (tile ID * 16)

        asl   a
        asl   a
        asl   a                       ; A = tile ID * 128 (tiledata offset)

; The tile has no compiled sprites to drop: PPUDATA_WRITE dropped them when the flag was set, and
; SprCompileTile does not compile a tile while its flag is set.

        jmp   FastROMMaskedTileToLookup
        FIN

; A compiled sprite on an odd pixel whose shifted pair is not compiled yet: called by its stub
; (EmitShiftStubs) with a JSL from the compile bank, which then draws the plain variant, a pixel to the
; left.  Queue the shifted pair (bit 0 of the key: SprCacheService), unless this render's compile quota is
; used up.  DBR = $01; X (the OAM index) and Y (the SHR address) are preserved.
        DO    SPR_PIXEL_SHIFT
        mx    %00
SprQueueShift
        SPR_STAT SPR_ST_SHREQ
        phx
        ldal PPU_MEM+SPR_PEND_CNT
        cmp  #2*SPR_COMPILE_PER_RENDER
        bcs  :full
        tax                            ; X = end of the pending list
        lda  sprTmp5                   ; the pattern table, $8000 -> $1000, and the shift request
        lsr
        lsr
        lsr
        ora  #$0001
        pha
        lda  sprTmp2                   ; the key offset, as in :blitResolvedSprite
        and  #$83FF                    ; tile, palette and vertical flip
        asl
        adc  #0
        asl
        ora  1,s
        stal PPU_MEM+SPR_PEND,x
        pla
        inx
        inx
        txa
        stal PPU_MEM+SPR_PEND_CNT
:full   plx
        rtl
        FIN

; Lines to hide at the top of the sprite being drawn, set by the game's SPRITE_PRE_DRAW callback
; (stays 0 if the game never sets it).  At least the sprite's height hides it entirely.
sprClipTop    dw 0

drawProcs
        dw drawTileToScreen,drawTileToScreenP,drawTileToScreenH,drawTileToScreenPH
        dw drawTileToScreenV,drawTileToScreenPV,drawTileToScreenHV,drawTileToScreenPHV

drawProcsClipped
        dw drawClippedTileToScreen,drawClippedTileToScreenP,drawClippedTileToScreenH,drawClippedTileToScreenPH
        dw drawClippedTileToScreenV,drawClippedTileToScreenPV,drawClippedTileToScreenHV,drawClippedTileToScreenPHV

; The compiled sprite dispatch table is in the PPU_MEM bank (PPU_MEM+SPR_COMP_TBL, Defs.s), indexed by the
; key offset built in :blitResolvedSprite.  An entry of $0000 means the sprite has no compiled version.

        mx    %00
_blitTileNoMask
; A = tile address
; Y = screen address
; X = palette select 0,2,4,6
;
; Raw data draw -- expands the tile data from w_wxxy_yzz0 to 00ww_00xx_00yy_00zz and then adds an offset based on the
; palette select

        sta   sprTmp0
        sty   sprTmp1

        txa
        and   #$0006
        asl
        sta   sprTmp3
        asl
        asl
        asl
        asl
        ora   sprTmp3
        sta   sprTmp3
        xba
        ora   sprTmp3
        sta   sprTmp3

        ldy   sprTmp0
        ldx   sprTmp1
        lda   #8
        sta   sprTmp4

]line   equ   0
:loop
        lda:  {]line*4},y                            ; Load the tile data lookup value
        lsr
        and   #$0003
        sta   sprTmp2
        lda:  {]line*4},y
        asl
        and   #$0030
        tsb   sprTmp2
        lda:  {]line*4},y
        asl
        asl
        asl
        and   #$0300
        tsb   sprTmp2
        lda:  {]line*4},y
        asl
        asl
        asl
        asl
        asl
        and   #$3000
        ora   sprTmp2
        xba
        ora   sprTmp3
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        lda:  {]line*4}+2,y
        lsr
        and   #$0003
        sta   sprTmp2
        lda:  {]line*4}+2,y
        asl
        and   #$0030
        tsb   sprTmp2
        lda:  {]line*4}+2,y
        asl
        asl
        asl
        and   #$0300
        tsb   sprTmp2
        lda:  {]line*4}+2,y
        asl
        asl
        asl
        asl
        asl
        and   #$3000
        ora   sprTmp2
        xba
        ora   sprTmp3
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

        iny
        iny
        iny
        iny

        txa
        clc
        adc   #160
        tax

        dec   sprTmp4
        beq   :done
        brl   :loop
:done
        rts

; Blits from the top-half of the tiledata bank.  Assumes no mask. This routine is used in the dirty
; renderer to selectively update the screen when a small number of backgrond tiles have changed.
;
; X = tile address
; Y = screen address
;
; Bank must be set to the tiledata bank
        mx    %00
_blitBGTile

; Load data from the tiledata,x and store in a direct page buffer. The
; Y register is over-written.

        phy
        jsr   _copyTileToBuffer

; Copy data from the direct page buffer into the SHR screen memory

        plx
        jmp   _copyBufferToScreenNoMask

        mx    %00
incborder
        php
        sep  #$20
        ldal $E0C034
        inc
        eorl $E0C034
        and  #$0F
        eorl $E0C034
        stal $E0C034
        plp
        rts

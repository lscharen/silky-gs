; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.
; Helper to perform the essential functions of rendering a frame
_ppuctrl     ds  2
_ppuscroll_y dw  0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppuscroll_x dw  0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppumask ENT
             ds  2


; sprTmp0 - sprTmp4 (pputmp + 0 - 8) are in Defs.s: the configuration screen's font blitter uses them too
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
SPR_FLIP_PAGE equ 2
        ELSE
SPR_SLOT_SIZE equ $0200
SPR_BANK_SLOTS equ 128
SPR_FLIP_PAGE equ 1
        FIN
SPR_MAX_SLOTS equ SPR_BANK_SLOTS*SPR_MAX_BANKS   ; (SPR_MAX_BANKS is in Defs.s: InitMemory uses it too)

; 8x16 sprites: the pattern table is bit 0 of the sprite's own tile ID (PPUCTRL doesn't select it), so
; set the sprite's sprTmp5 (the table's offset in the tiledata bank: $0000 / $8000) and sprCompTbl (its
; half of SPR_COMP_TBL).  A = the OAM tile and attribute word; A is trashed.  (Relative branches, not
; local labels: the macro is expanded twice in drawSprites.)
SPR16_TABLE mac
        and   #$0001                   ; the pattern table bit
        beq   *+14                     ; (table 0: the three lines after the bra)
        lda   #$8000
        sta   sprTmp5
        lda   #SPR_COMP_TBL+$1000
        sta   sprCompTbl
        bra   *+9
        stz   sprTmp5
        lda   #SPR_COMP_TBL
        sta   sprCompTbl
        <<<

; Set up a sprite for drawing.  X = OAM index (preserved).
;
; Sets sprTmp1 = SHR address, sprTmp4 = horizontal clip amount (0 = no clipping), sprShift = $0004 for
; a sprite on an odd pixel (else 0; SPR_PIXEL_SHIFT).  A macro, so each sprite size gets its own copy and the setup is not a nested call.
; The palette (ActivePtr) is set only by the bitmap draws (SPR_PALETTE): compiled sprites have their colors built in.
SPR_SETUP mac
        ldal  OAM_COPY,x               ; Y-coordinate
        and   #$00FF
        asl                            ; (carry clear)
        tay
        db    $B7,sprMul160            ; lda [sprMul160],y
        adc   #$2000-{y_offset*160}+x_offset
        sta   sprTmp1                  ; (carry clear: the address is below $10000)

        sep   #$20
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

; ActivePtr = the swizzle table of the sprite's palette (attribute bits 1-0, in the high byte of sprTmp2), for
; the bitmap draws.  A is trashed.
SPR_PALETTE mac
        sep   #$20
        lda   sprTmp2+1
        and   #$03
        asl
        adc   SwizzlePtr2+1            ; (carry clear from the asl)
        sta   ActivePtr+1
        rep   #$20
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
        beq   *+5
        brl   :is_8x16

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

        SPR_SETUP
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridMarkSprite8     ; Mark the cells that this sprite covers (nothing is saved)
        FIN
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
        SPR_SETUP
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridMarkSprite8     ; Mark the cells that this sprite covers (nothing is saved)
        FIN
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
        lda   #SPR_COMP_TBL            ; The fast path's keys include the pattern table (:drawSprite16)
        sta   sprCompTbl
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

        SPR_SETUP
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridMarkSprite16     ; Mark the cells that this sprite covers (nothing is saved)
        FIN
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
        SPR_SETUP
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridMarkSprite16     ; Mark the cells that this sprite covers (nothing is saved)
        FIN
        jsr   :drawSprite16c
        lda   #SPR_COMP_TBL            ; (SPR16_TABLE moved it)
        sta   sprCompTbl
        bra   :next16
:hide16
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridRecordNone
        FIN
        bra   :next16
        FIN

; Draw a single 8x16 sprite (both halves)
;
; X = OAM index (0, 4, 8, ..., 248, 252)
; sprTmp1/sprTmp4 already set by SPR_SETUP for the top-left position
;
; Unlike 8x8 mode, the NES ignores PPUCTRL/spadr for 8x16 sprites: bit 0 of the OAM
; tile ID selects the pattern table, and bits 7-1 select the tile pair within it
; (top tile = tile_id & $FE, bottom tile = top tile + 1, both from the same table).
;
; Fast path: when both halves are compiled (and not clipped or behind the background), the top half is
; called with draw_rtn2's RTS returning to sprTramp, which moves Y (the SHR address: compiled sprites
; leave it alone) down 8 lines and jumps to the bottom half, whose own return goes back to the loop.
; The keys include the pattern table (sprCompTbl = SPR_COMP_TBL in the 8x16 loop), and the halves are
; the two tiles of a pair, so their keys differ only in bit 2 (tile bit 0).  On an odd pixel, a half
; whose shifted pair is not compiled yet (page bit 0: its stub calls SprQueueShift, which takes the key
; from sprTmp2) takes the slow path, so that the right tile is queued.
        mx    %00
:drawSprite16
        ldal  OAM_COPY+1,x             ; {attribute, tile_id}
        ldy   sprTmp4                  ; Clipped on the right, or behind the background: the slow path
        bne   :spr16_slow
        bit   #$2000
        bne   :spr16_slow
        and   #$C3FF                   ; The key, as in :blitResolvedSprite
        asl                            ; carry = vertical flip
        adc   #0
        asl                            ; carry = horizontal flip (kept to the second lookup: nothing
        bit   #$0004                   ; below changes it).  Bit 2 is the tile ID's bit 0, the pattern
        beq   *+5                      ; table: move it to bit 12
        eor   #$1004
        bit   #$0002                   ; Flipped vertically: the odd tile is on top
        beq   *+5
        eor   #$0004
        tay
        lda   [sprCompTbl],y           ; Top half
        beq   :spr16_slow
        bcc   *+5
        ora   #SPR_FLIP_PAGE
        DO    SPR_PIXEL_SHIFT
        ora   sprShift
        FIN
        sta   sprTmp0
        tya
        eor   #$0004
        tay
        lda   [sprCompTbl],y           ; Bottom half
        beq   :spr16_slow
        bcc   *+5
        ora   #SPR_FLIP_PAGE
        DO    SPR_PIXEL_SHIFT
        ora   sprShift
        FIN
        stal  sprTrampJ+2              ; (a slow path after this leaves the trampoline unused)
        DO    SPR_PIXEL_SHIFT
        ldy   sprShift                 ; Odd pixel: neither half may still be a stub
        beq   :spr16_go
        ora   sprTmp0
        lsr
        bcs   :spr16_slow
:spr16_go
        FIN
        SPR_STAT SPR_ST_HITS
        SPR_STAT SPR_ST_HITS
        pea   sprTramp-1               ; draw_rtn2's RTS after the top half
        lda   sprTmp0
        stal  :c16+2
        ldy   sprTmp1
:c16    jml   $000000

; Slow path: each half through :blitResolvedSprite, with sprCompTbl set to the tile's half of the table
; (SPR16_TABLE) and put back afterwards
:spr16_slow
        jsr   :spr16_halves
        lda   #SPR_COMP_TBL
        sta   sprCompTbl
        rts

:spr16_halves
        ldal  OAM_COPY+1,x
        sta   sprTmp2                  ; {attribute, tile_id}
        SPR16_TABLE                    ; the pattern table from the tile ID's bit 0

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
        SPR16_TABLE                    ; the pattern table from the tile ID's bit 0
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

; The bottom half of an 8x16 sprite on the fast path (:drawSprite16): entered by draw_rtn2's RTS after the
; top half, with Y = the top half's SHR address.  The JML is patched with the bottom half's entry.
sprTramp
        tya
        clc
        adc   #8*160
        tay
sprTrampJ
        jml   $000000

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
        tya                            ; A = key offset (both horizontal flips are compiled together): Y
        clc                            ; with the pattern table, from its half of SPR_COMP_TBL
        adc  sprCompTbl
        sec
        sbc  #SPR_COMP_TBL
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
        DO   HAS_CHR_RAM              ; The tile's address first: reconvert it if CHR-RAM changed it
        lda  sprTmp2-1
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data -- this clears the carry flag
        ora  sprTmp5                  ; fold in the pattern-table offset ($0000 or $8000)
        tay                           ; (kept across the check)
        jsr  sprChrCheck
        FIN
        DO   SHOW_DEBUG_VARS
        lda  #$FFFF         ; color for priority bit
        stal outlineColor
        FIN
        SPR_PALETTE
        lda  sprTmp2+1
        and  #$00E0
        lsr
        lsr
        lsr
        lsr
        tax

; Calculate the address of the tile data

        DO   HAS_CHR_RAM
        tya                           ; (computed above)
        ELSE
        lda  sprTmp2-1
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data -- this clears the carry flag
        ora  sprTmp5                  ; fold in the pattern-table offset ($0000 or $8000)
        FIN
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
        DO   HAS_CHR_RAM              ; The tile's address first: reconvert it if CHR-RAM changed it
        lda  sprTmp2-1
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data -- this clears the carry flag
        ora  sprTmp5                  ; fold in the pattern-table offset ($0000 or $8000)
        tay                           ; (kept across the check)
        jsr  sprChrCheck
        FIN
        SPR_PALETTE
        lda  sprTmp2+1
        and  #$00E0
        lsr
        lsr
        lsr
        lsr
        tax
        DO   HAS_CHR_RAM
        tya                           ; (computed above)
        ELSE
        lda  sprTmp2-1
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data -- this clears the carry flag
        ora  sprTmp5                  ; fold in the pattern-table offset ($0000 or $8000)
        FIN
        pei  sprBankSwap              ; The tile routines read the tile data with DBR = tiledata
        plb
        jsr  (drawProcsClipped,x)
        plb                           ; DBR = $01
        plx
        rts

; CHR-RAM support, for the bitmap draws (as_bitmap, as_bitmap_clip): if the sprite's tile was rewritten
; since it was converted, reconvert it (FastROMMaskedTileToLookup).  A = Y = the tile's address in the
; tiledata bank (tile * 128 | sprTmp5).  DBR = $01.  Y is preserved; A and X are not.
        DO    HAS_CHR_RAM
        mx    %00
sprChrCheck
        CHR_INDEX                     ; X = the tile's ChrRamDirty index
        ldal  ChrRamDirty,x
        bit   #CHRRAM_SPR_DIRTY
        bne   :dirty
        rts

; Clear the flag with an 8-bit store: a 16-bit one would also write the next tile's flags, which the
; NES task may set in between.  The tile has no compiled sprites to drop: PPUDATA_WRITE dropped them
; when the flag was set, and SprCompileTile does not compile a tile while its flag is set.
:dirty  sep   #$20
        and   #CHRRAM_SPR_DIRTY!$FF   ; clear only the sprite bit, preserve the BG bit
        stal  ChrRamDirty,x
        rep   #$20
        phy
        pei   sprBankSwap             ; (with DBR = the tiledata bank, as it was written for)
        plb
        tya
        lsr
        lsr
        lsr
        tax                           ; X = the CHR-RAM source address (index * 16 = address / 8)
        tya                           ; A = the tiledata address
        jsr   FastROMMaskedTileToLookup
        plb
        ply
        rts
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
        lda  sprCompTbl                ; the pattern table (from its half of SPR_COMP_TBL: $0000 / $1000)
        sec
        sbc  #SPR_COMP_TBL-1           ; and the shift request (+ 1)
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
sprClipTop ENT
              dw 0

drawProcs
        dw drawTileToScreen,drawTileToScreenP,drawTileToScreenH,drawTileToScreenPH
        dw drawTileToScreenV,drawTileToScreenPV,drawTileToScreenHV,drawTileToScreenPHV

drawProcsClipped
        dw drawClippedTileToScreen,drawClippedTileToScreenP,drawClippedTileToScreenH,drawClippedTileToScreenPH
        dw drawClippedTileToScreenV,drawClippedTileToScreenPV,drawClippedTileToScreenHV,drawClippedTileToScreenPHV

; The compiled sprite dispatch table is in the PPU_MEM bank (PPU_MEM+SPR_COMP_TBL, Defs.s), indexed by the
; key offset built in :blitResolvedSprite.  An entry of $0000 means the sprite has no compiled version.

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

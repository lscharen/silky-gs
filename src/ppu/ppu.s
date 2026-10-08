; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.
; Helper to perform the essential functions of rendering a frame
_ppuctrl     ds  2
_ppuscroll_y dw  0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppuscroll_x dw  0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppumask     ds  2


; Change all of the 1-bits from the MSB to the first one bit to zeros, i.e. 11011000 -> 00011000
flipLeadingOnes
        db   $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F
        db   $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F
        db   $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F
        db   $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F
        db   $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
        db   $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F
        db   $60,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6A,$6B,$6C,$6D,$6E,$6F
        db   $70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7A,$7B,$7C,$7D,$7E,$7F

        db   $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F  ; $80 - $8F
        db   $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F  ; $90 - $9F
        db   $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F  ; $A0 - $AF
        db   $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F  ; $B0 - $BF

        db   $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F  ; $C0 - $CF
        db   $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F  ; $D0 - $DF

        db   $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F  ; $E0 - $EF
        db   $00,$01,$02,$03,$04,$05,$06,$07,$00,$01,$02,$03,$00,$01,$00,$00  ; $F0 - $FF

; Change all of the 0-bits from the MSB to the first zero bit to ones, i.e. 00100111 -> 11100111
flipLeadingZeros
        db   $FF,$FF,$FE,$FF,$FC,$FD,$FE,$FF,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $00 - $0F
        db   $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $10 - $1F

        db   $E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF  ; $20 - $2F
        db   $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $30 - $3F

        db   $C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF  ; $40 - $4F
        db   $D0,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF  ; $50 - $5F
        db   $E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF  ; $60 - $6F
        db   $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $70 - $7F

        db   $80,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8A,$8B,$8C,$8D,$8E,$8F  ; $80 - $8F
        db   $90,$91,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$9B,$9C,$9D,$9E,$9F  ; $90 - $9F
        db   $A0,$A1,$A2,$A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AB,$AC,$AD,$AE,$AF  ; $A0 - $AF
        db   $B0,$B1,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$BB,$BC,$BD,$BE,$BF  ; $B0 - $BF
        db   $C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF  ; $C0 - $CF
        db   $D0,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF  ; $D0 - $DF
        db   $E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF  ; $E0 - $EF
        db   $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $F0 - $FF

; Variation on shadowBitmapToList that uses a temporary variable for the current byte and does not modify
; the bitmap list itself
;
; X = bitmap address
; Y = starting byte
; A = ending byte (exclusive)
;
; Scan bytes 2 through 10 at address $1234
; X = $1234
; Y = 2
; A = 11


; Direct-page aliases used by the WALK_BITMAP macro in scanline_bitmap.s and by _drawBackground/_exposeScreen
walk_top     equ tmp3
walk_bottom  equ tmp4
walk_curr    equ tmp5
walk_prev    equ tmp6

; Setup all of the sprites from the NES OAM memory.  If possible, we read the OAM information directly
; from a game-specific area of NES RAM, rather than supporting the OAMDMA operation, to avoid extra
; copying.
;        mx  %11
;drawOAMSprites

; Step 1: Scan the OAM sprite information.  Since we're reading NES RAM, we disable interrupts so that
;         a VBL cannot fire while we sync the data.

; This step was done at the start of RenderFrame

; Step 2: Convert the bitmap to a list of (top, bottom) pairs in order to update the screen

;        jmp   shadowBitmapToList

; Dirty rendering.  Only draw differences

; Set up specialized methods to walk the bitmaps (called in 8-bit mode), guaranteed to have
; the carry clear when called, must return with the carry clear as well.
        mx   %11
_drawBackground
        phx
        phy
        php
        rep  #$30
        ldx  walk_top
        ldy  walk_bottom
        jsr  _BltRangeLite           ; BltRangeLite uses tmp0, tmp1, tmp2
        plp
        ply
        plx
        rts

        mx   %11
_exposeScreen
        phx
        phy
        php
        rep  #$30
        ldx  walk_top
        tay
        ldy  walk_bottom
        jsr  _PEISlam               ; PEISlam uses tmp0
        plp
        ply
        plx
        rts

        mx   %00
clearPreviousSprites
        WALK_BITMAP LOAD_INTERSECTION;y_offset_rows;y_ending_row;_drawBackground

        mx    %00
exposeCurrentSprites
        WALK_BITMAP LOAD_CURRENT;y_offset_rows;y_ending_row;_exposeScreen

        mx    %00
drawOtherLines
        WALK_BITMAP LOAD_OTHERS;y_offset_rows;y_ending_row;_drawBackground

; Handles horizontal mirroring where the top of the screen could start at any scanline.  The PPU
; emulation is based on nametable addresses, the any bitmap that marks dirty scanlines is independent
; of the YSCROLL values.  Sprites are also independent of YSCROLL values and are placed directly in
; screen-space coordinates.
;
; The trick here is to be able to generate, on the fly, a union of sprite bitmap values and tile row values. The
; extra wrinkle is that the index register is also working in screen-space, so it can directly lookup the
; sprite bitmap, but we need to adjust the tileBitmap on a per-bit basis.
LOAD_HORZ_MIRROR mac
        lda  (TileBitmap),y          ; Set TileBitmap pointer to the closest 
        lda  (CurrShadowBitmap),y    ; y = screen_y / 8

        <<<

; alignedTileBuffer = btmap fill based on YSCROLL
;
;       ldx  tile_row     ; logical row (0 - 30 for V_MIRROR, 0 - 60 for H_MIRROR)
;       ldy  y_scroll_mod_8
;       lda  y2bits,y    ; 16-bit mask value based on YSCOLL mod 8. If YSCROLL = 0, mask = $00FF.  YSCROLL = 7, mask = $FE01
;       ora  tileBitmap,x
;       sta  tileBitmap,x
;
; When blitting, set a pointer to the 
; Update the minimal amount of the screen just based on what has changed from the prior
; frame.  We track three bitmaps of information that identify which lines different
; components are on.
;
; shadowBitmap0 and shadowBitmap1 track the lines that hold sprites from the previous
; and current frame.
;
; There are actually two phases to the dirty rendering.  The first is when the prior
; frame was rendered normally and the second in when the prior frame used the dirty
; renderer.
;
; When performing dirty rendering for the first time, the sprites from the last frame have
; to be erased by drawing the background on the lines previously occupied, then the new sprites
; drawn and the updated lines exposed
;
; When rendering a dirty frame, the expectation is that the next frame will use the dirty
; renderer as well, so the pipeline changes to improve efficieny.  The screen data beneath
; a sprite is saved before drawing and, on the next frame used to restore the graphic
; screen rather than re-rendering the full background.
;
; New sprites are drawn and the 8x8 patches of the previous sprites are used to update only
; the active portions of the screen.  Sprites are drawn in a top-down order, if possible
; to avoid bubbling. Exposing the erased sprites *after* drawing the current sprites will
; avoid flicker.
;
; When the drawing transitions back to a normal rendering frame, nothing special needs to
; be done as the normal blit will erase all of the previous sprites.

sprTmp0      equ pputmp
sprTmp1      equ pputmp+2
sprTmp2      equ pputmp+4
sprTmp3      equ pputmp+6
sprTmp4      equ pputmp+8
sprMul160    equ pputmp+12          ; (3 bytes) long pointer to Mul160Tbl
sprXPar      equ pputmp+15          ; (byte) scroll_x & 1, the half-pixel offset of every sprite this frame
sprBankSwap  equ unused174          ; $01 << 8 | ^tiledata: pei / plb selects the tiledata bank, plb back to $01
sprTmp5      equ sprTmp5Hi          ; tiledata bank offset for the tile to draw: $0000 or $8000
sprTmp6      equ sprTmp6Lo          ; same selection in $0000/$0100 form (merges with tile ID like spadr_lo)

; Set up a sprite for drawing.  X = OAM index (preserved).
;
; Sets sprTmp1 = SHR address, sprTmp4 = horizontal clip amount (0 = no clipping) and ActivePtr = the
; sprite's palette.  A macro, so each sprite size gets its own copy and the setup is not a nested call.
SPR_SETUP mac
        ldal  OAM_COPY,x               ; Y-coordinate
        and   #$00FF
        asl                            ; (carry clear)
        tay
        db    $B7,sprMul160            ; lda [sprMul160],y
        adc   #$2000-{y_offset*160}+x_offset
        sta   sprTmp1
        DO    1-GRID_DIRTY_RENDERING
        sta   sprTmp3                  ; Clamped address, for the old dirty renderer's sprite save
        FIN

        sep   #$20                     ; Palette: ActivePtr selects the swizzle table of the sprite palette
        ldal  OAM_COPY+2,x
        and   #$03
        asl
        adc   SwizzlePtr2+1            ; (carry clear from the asl)
        sta   ActivePtr+1

        lda   sprXPar                  ; X-coordinate: NES pixels to IIgs bytes, with the scroll's
        adcl  OAM_COPY+3,x             ; half-pixel offset
        and   #$FE                     ; Mask before the shift so that a 0 goes into the carry
        ror                            ; Bring the carry into the high bit in case of overflow
        rep   #$20
        and   #$00FF
        tay
        adc   sprTmp1                  ; Add to the base address calculated from the Y-coordinate
        sta   sprTmp1                  ; This is the SHR address at which to draw the sprite

        stz   sprTmp4                  ; Clip a sprite that runs off the right edge
        cpy   #125
        bcc   *+8
        tya
        sbc   #124                     ; (carry set)
        sta   sprTmp4
        DO    1-GRID_DIRTY_RENDERING
        tya                            ; Clamped address, for the old dirty renderer's sprite save
        cmp   #125
        bcc   *+5
        lda   #124
        clc
        adc   sprTmp3
        sta   sprTmp3
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
        lda   _ppuscroll_x             ; The scroll's half-pixel offset is the same for every sprite
        and   #$01
        sta   sprXPar
        rep   #$20
        lda   CMPL_BANK                ; For switching to the tiledata bank and back to $01
        xba
        sta   sprBankSwap

; The loop runs with the data bank set to the shadow screen ($01), so compiled sprites are called
; directly.  The bitmap routines switch to the tiledata bank themselves (as_bitmap).

        phb                            ; Save the current data bank
        pea   $0101
        ldx   #0

; Determine if we are in 8x8 sprite mode, or 8x16 sprite mode.  Have a specialized loop for
; each.

        lda   _ppuctrl
        bit   #NES_PPUCTRL_SPRSIZE
        bne   :is_8x16

; 8x8 mode: the pattern table is whatever PPUCTRL/spadr currently selects for all sprites (unlike
; 8x16 mode, where each sprite's own tile ID picks the table), so it is set once

        lda   spadr_hi
        sta   sprTmp5
        lda   spadr_lo
        sta   sprTmp6
        plb

:oam_loop_8x8
        phx                           ; Save x

        DO    GRID_DIRTY_RENDERING
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
        plx
        inx
        inx
        inx
        inx
        cpx   :spriteCount
        bcc   :oam_loop_8x8

        plb
        plb
        jmp   SprCacheService         ; Compile the sprite tiles that missed (returns to the caller)

; A sprite with top lines to hide: one that is hidden entirely is not set up, marked or drawn.  The
; others go through the clipped draw routines, with the lines in the high byte of sprTmp4.

        DO    SPRITE_CLIP
:clip8  cmp   #8
        bcs   :next8
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
        FIN

:is_8x16
        plb

:oam_loop_8x16
        phx                    ; Save x

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
        plx
        inx
        inx
        inx
        inx
        cpx   :spriteCount
        bcc   :oam_loop_8x16

        plb
        plb
        jmp   SprCacheService         ; Compile the sprite tiles that missed (returns to the caller)

        DO    SPRITE_CLIP
:clip16 cmp   #16                     ; Hidden entirely: not set up, marked or drawn
        bcs   :next16
        jsr   :setupSprite16
        jsr   :drawSprite16c
        bra   :next16
        FIN

:setupSprite8
        SPR_SETUP

        DO   GRID_DIRTY_RENDERING
        jmp  gridMarkSprite8           ; The grid renderer erases from the code field, so nothing is
                                       ; saved; just mark the cells that this sprite covers
        ELSE
        ; If we are in DirtyState 1 or 2, then the sprite data should be copied
        lda  DirtyState
        beq  :not_dirty8
        phx
        ldx  sprTmp1
        ldy  sprTmp3                   ; Save the clamped screen address in sprTmp3
        jsr  saveTileFromScreen8
        plx
:not_dirty8
        rts
        FIN

:setupSprite16
        SPR_SETUP

        DO   GRID_DIRTY_RENDERING
        jmp  gridMarkSprite16
        ELSE
        ; If we are in DirtyState 1 or 2, then the sprite data should be copied
        lda  DirtyState
        beq  :not_dirty16
        phx
        ldx  sprTmp1
        ldy  sprTmp3                   ; Save the clamped screen address in sprTmp3
        jsr  saveTileFromScreen16
        plx
:not_dirty16
        rts
        FIN

; Draw a single 8x16 sprite (both halves)
;
; X = OAM index (0, 4, 8, ..., 248, 252)
; sprTmp1/sprTmp3/sprTmp4 already set by :setupSprite16 for the top-left position
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
        lda   #$0100
        sta   sprTmp6
        bra   :spr16_tbl_done
:spr16_tbl0
        stz   sprTmp5
        stz   sprTmp6
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
        lda   #$0100
        sta   sprTmp6
        bra   :c16tbl
:c16tbl0
        stz   sprTmp5
        stz   sprTmp6
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
; from the loop, with sprTmp5/sprTmp6 = the current global sprite table, set once)
; and 8x16 sprites (entered directly by :drawSprite16, with sprTmp5/sprTmp6 set
; per-sprite from the OAM tile ID's own pattern-table bit). Requires sprTmp2
; (tile id + attribute) already loaded into A, and sprTmp1/sprTmp3/sprTmp4
; (screen address / clip amount) already set up by SPR_SETUP.  DBR = $01.
:blitResolvedSprite

; CHR-RAM: a compiled-sprite hit needs no dirty check -- PPUDATA_WRITE drops a rewritten tile's
; compiled sprites, and SprCompileTile does not keep one whose tile is dirty.  The bitmap paths below
; read the converted tile data directly, so they reconvert a dirty tile first (sprChrCheck).

; This is the point to check if there is a compiled version of this sprite

        ldx  sprTmp4        ; Test if this sprite needs clipping (first test)
        bne  as_bitmap_clip

        bit  #$2000         ; Is the priority bit set?
        bne  as_bitmap

; The key offset is (pattern table << 11) | (tile << 3) | (vertical flip << 2) | (horizontal flip << 1), an
; index in the table of words.  The flips are bits 15 and 14 of the attribute and tile word (the priority bit,
; 13, is clear here).  Each shift moves the next flip bit into the carry, and the ADC adds it at the bottom.

        and  #$C0FF         ; tile and the two flips
        ora  sprTmp6        ; fold in the pattern-table select (0 or $0100)
        asl                 ; carry = vertical flip
        adc  #0
        asl                 ; carry = horizontal flip
        adc  #0
        asl
        tax
        ldal PPU_MEM+SPR_COMP_TBL,x
        beq  sprCacheMiss   ; zero value means no compiled sprite for this key

; Vector through the compiled sprite table.  The compiled sprites are in a different bank, so just check
; for a sentinel value and manually jump into the compiled sprite code to avoid a double-jump and having to
; have a second jump table in the compile sprite code bank.

        stal csd+1                     ; patch in the long address directly

; A hit changes nothing in the cache: it is replaced in the order it was compiled (see SPR_* in Defs.s)

        ldx  sprTmp1                   ; the SHR address for the compiled code (DBR = $01)
csd     jml  $000000
draw_rtn2                             ; Return from compiled sprite
        DO   SHOW_DEBUG_VARS
        lda  #$7777
        stal outlineColor
        ldx  sprTmp1
        jmp  drawOutline
        FIN
        rts

; Compiled sprite cache miss.  X = key offset.  Queue the sprite to be compiled after drawSprites
; (SprCacheService), unless this render's compile quota is already used up, and draw the sprite from
; its bitmap this time.  Both horizontal flips are compiled together, so the key is queued without it.
sprCacheMiss
        ldal PPU_MEM+SPR_PEND_CNT
        cmp  #2*SPR_COMPILE_PER_RENDER
        bcs  :no_queue
        tay                            ; Y = end of the pending list
        txa
        and  #$FFFD                    ; A = key offset, horizontal flip bit clear
        tyx
        stal PPU_MEM+SPR_PEND,x
        inx
        inx
        txa
        stal PPU_MEM+SPR_PEND_CNT
:no_queue
        DO   SHOW_DEBUG_VARS
        ldx  #$2222         ; color for missing compiled sprite
        FIN                            ; fall through to as_bitmap

; Finish calculating the jump address. We dispatch differently based on the horizontal flip, vertical
; flip and priority bits. when calling the rendering function, Y = screen address, X = tile data address

        mx    %00
as_bitmap
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
        jmp  drawOutline
        ELSE
        rts
        FIN

        mx    %00
as_bitmap_clip
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
        rts

; CHR-RAM support, for the bitmap draws (as_bitmap, as_bitmap_clip): if the sprite's tile was
; rewritten since it was converted, reconvert it.  sprTmp2 = tile and attributes, sprTmp6 = the
; pattern table select.  DBR = $01.  A, X and Y are trashed.
        DO    HAS_CHR_RAM
        mx    %00
sprChrCheck
        lda  sprTmp2
        and  #$00FF
        ora  sprTmp6                  ; tile | pattern table select: the 0-511 index of ChrRamDirty
        tax
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
; caller, sprChrCheck, tests it), with FastROMMaskedTileToLookup, and
; invalidate its compiled sprites (SprInvalidate).
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
        pha                           ; the key offset of the tile with no flips (tile index * 8), for the
                                      ; compiled sprite cache invalidation below
        asl   a
        tax                           ; X = CHR-RAM source address (tile ID * 16)

        asl   a
        asl   a
        asl   a                       ; A = tile ID * 128 (tiledata offset)

        jsr   FastROMMaskedTileToLookup

; The tile's pixels changed, so any compiled copy of it is stale.  Drop both of its compiled sprites from the
; compiled sprite cache; the next time it is drawn, it is a miss and gets compiled again from the new data.

        plx
        phx
        jsr   SprInvalidate
        plx
        inx
        inx
        inx
        inx                           ; ... and with the vertical flip
        jmp   SprInvalidate
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

; The compiled sprite dispatch table is in the PPU_MEM bank (PPU_MEM+SPR_COMP_TBL, Defs.s).  An entry of
; $0000 means the sprite tile has no compiled representation.
;
; 512 word entries (1024 bytes): the low 256 entries are tile ids 0-255 in pattern
; table 0, the high 256 entries (index 256-511, i.e. byte offset 512-1023) are tile
; ids 0-255 in pattern table 1 -- indexed via (tile_id | sprTmp6) above, matching the
; ChrRamDirty/spadr_lo convention.

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

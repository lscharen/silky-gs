; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.
; Helper to perform the essential functions of rendering a frame
_ppuctrl     ds  2
_ppuscroll_y dw  0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppuscroll_x dw  0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppumask     ds  2
_ppuversion  ds  2

; Alternate scanOAMSprites that unrolls the loop, uses exclusion tables and 8-bit operations
; to improve scanning speed

        mx   %00
scanOAMSprites2

; Since it's rare that all 64 sprites are active, the code is
; slightly biased for fast skipping.  Most NES games place sprites
; that are not in use below the screen, so we try to do an early
; out by testing the vertical range first.  Also, the IIgs screen
; is shorter than the NES screen, so even more sprites are rejected
; quickly.

; The first loop is optimized for exlcusions and simply
; records the index of the sprites that pass on the stack
; which can be processed with a more efficient register
; setup later.  The extra cycles saved by staying in 8-bit
; mode more than make up for the PHX instruction

; TIP: Put the exclusion tables in NES RAM space around $1000

        sep    #$30                 ; 8-bit index registers

        phb
        lda    #^ROMBase
        pha
        plb

        clc
        ldx    #OAM_START_INDEX*4   ; This is in the range [0, 252]
        txa                         ; Keep X = A
:loop
        ldy    ROMBase+DIRECT_OAM_READ,x
        ldx    y_exclude,y
        bne    :next

        DO  NO_TILE_EXCLUDE
        ELSE
        tax                         ; Restore the X-register
        ldy    ROMBase+DIRECT_OAM_READ+1,x
        ldx    tile_exclude,y
        bne    :next
        FIN

        pha                         ; Since A = X, we can just save it directly and fall through
:next
        adc    #4
        tax
        cmp    #OAM_END_INDEX*4
        bcc    :loop

; Now we have the index values on the stack.  Switch to 16-bit mode and start
; pre-computing essential data

        lda    ROMBase+DIRECT_OAM_READ,x

        rep    #$20
        ldy    #0
:loop2
        plx
        lda    ROMBase+DIRECT_OAM_READ,x
        inc
        sta    OAM_COPY,y

        lda    ROMBase+DIRECT_OAM_READ+2,x
        sta    OAM_COPY+2,y

        iny
        iny
        iny
        iny

        plb                         ; Restore the bank back to
        rts



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
; and current frame. tileBitmap marks lines that had a tile updated since the last frame.
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
sprAddrMin   equ unused132
sprAddrMax   equ unused134

        mx   %00
drawSprites

:spriteCount equ pputmp+10
:mul160      equ pputmp+12

; Run through the copy of the OAM memory and render each sprite to the graphics screen.  Typically,
; shadowing is disabled during this routine.

; Put some variables on the direct page so we don't have to change the bank in each iteration

        lda   spriteCount
        sta   :spriteCount
        lda   #Mul160Tbl
        sta   :mul160
        lda   #^Mul160Tbl
        sta   :mul160+2

        ldx   #0
        cpx   :spriteCount
        bne   *+3
        rts

; Set up the data bank to point to the tile data

        phb                          ; Save the current data bank
        pea   #^tiledata             ; Put the tile data bank on the stack

; Determine if we are in 8x8 sprite mode, or 8x16 sprite mode.  Have a specialized loop for
; each.

        lda   _ppuctrl
        bit   #NES_PPUCTRL_SPRSIZE
        bne   :is_8x16

        plb

:oam_loop_8x8
        phx                           ; Save x

; Regardless of whether the PPUCTRL is in 8x8 or 8x16 mode, the 
; starting SHR address and palette selection is the same

        jsr   :setupSprite8

; Copy bytes 1 and 2 into temp space

        ldal  OAM_COPY+1,x
        sta   sprTmp2

; Draw the tile

        jsr   :drawSprite8x8

; Restore and continue processing the OAMtable

        plx
        inx
        inx
        inx
        inx
        cpx   :spriteCount
        bcc   :oam_loop_8x8

        plb
        plb
        rts

:is_8x16
        plb

:oam_loop_8x16
        phx                    ; Save x

; Setup the sprite

        jsr   :setupSprite16

; Copy bytes 1 and 2 into temp space
;  (only support the first nametable at the moment)

        ldal  OAM_COPY+1,x
        and   #$FFFE           ; mask low bit
        sta   sprTmp2

; Draw the top tile

        jsr   :drawSprite8x8

        lda   sprTmp1          ; Advance the address on screen
        clc
        adc   #8*160
        sta   sprTmp1

        lda   sprTmp2          ; Advance to the next tile index
        inc
        sta   sprTmp2          ; Value needs to be in accumulator and sprTmp2 for drawSprite8x8

; Draw the bottom tile

        jsr   :drawSprite8x8

        plx
        inx
        inx
        inx
        inx
        cpx   :spriteCount
        bcc   :oam_loop_8x16

        plb
        plb
        rts

:setupSprite8
        lda   #$2000+x_offset
        sta   sprAddrMin
        lda   #$2000+{{200-8}*160}+x_offset
        sta   sprAddrMax

        jsr   :setupSprite

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

:setupSprite16
        lda   #$2000+x_offset
        sta   sprAddrMin
        lda   #$2000+{{200-16}*160}+x_offset
        sta   sprAddrMax

        jsr   :setupSprite

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

; X = OAM index
:setupSprite
        ldal  OAM_COPY,x               ; Y-coordinate
        and   #$00FF
        asl
        tay
        lda  [:mul160],y
        adc  #$2000-{y_offset*160}+x_offset
        sta  sprTmp1

;        cmp  sprAddrMin
;        bcs  :chk_max
;        lda  sprAddrMin
;:chk_max
;        cmp  sprAddrMax
;        bcc  :chk_done
;        lda  sprAddrMax
;:chk_done
        sta   sprTmp3

; Do some stuff that is faster in 8-bit mode

        sep  #$20

; Set the palette pointer for this sprite

        ldal OAM_COPY+2,x              ; Put attribute byte in the high byte
        and  #$03
        asl
        adc  SwizzlePtr2+1             ; Carry is clear from the asl
        sta  ActivePtr+1               ; Select the second set of palettes

; Convert the x-coordinate.

        ldal _ppuscroll_x
        and  #$01
        adcl OAM_COPY+3,x             ; X-coordinate (In NES pixels, need to convert to IIgs bytes)
        and  #$FE                     ; Mask before the shift so that we know a 0 goes into the carry
        ror                           ; Rotate to bring the carry into the high bit in case of overflow
        rep  #$20
        and  #$00FF
        tay
        adc  sprTmp1                  ; Add to the base address calculated fom the Y-coordinate
        sta  sprTmp1                  ; This is the SHR address at which to draw the sprite

        stz  sprTmp4                  ; Assume no clipping
        tya
        cmp  #125
        bcc  :no_x_clamp

        sbc  #124                   ; get the difference
        sta  sprTmp4

        lda  #124
        clc

:no_x_clamp
        adc  sprTmp3
        sta  sprTmp3
        rts

; Calculate the on-screen address for the sprite
;
; Input:
;  X = OAM index (0, 4, 8, ..., 248, 252)
;
; Output:
;  sprTmp1 = SHR address
;  sprTmp3 = clamped SHR address
;  sprTmp4 = clipping amount (0 = no clipping)
;
; Modified:
;  sprTmp0 used for temporary data
;  ActivePtr set to sprite palette

; Draw a single 8x8 sprite
;
; X = OAM index (0, 4, 8, ..., 248, 252)
; A = OAM[1] and OAM[2], also in sprTmp2
:drawSprite8x8

; CHR-RAM support: recompile this sprite tile now if it was marked dirty by a
; PPUDATA write sinkce it was last drawn. HAS_CHR_RAM games always take the
; bitmap (as_bitmap/as_bitmap_clip) path below, never the compiled-sprite
; path above, so this one call covers both.
        DO   HAS_CHR_RAM
        jsr  CheckSprTileDirty
        lda  sprTmp2              ; restore
        FIN

; This is the point to check if there is a compiled version of this sprite

        ldx  sprTmp4        ; Test if this sprite needs clipping (first test)
        bne  as_bitmap_clip

        bit  #$2000         ; Is the priority bit set?
        bne  as_bitmap

        and  #$00FF
        asl
        tax
        ldal spr_comp_tbl,x
        DO   SHOW_DEBUG_VARS
        ldx  #$2222         ; color for missing compiled sprite
        cmp  #0             ; re-establish the equality test
        FIN
        beq  as_bitmap      ; zero value means no compiled sprite for this tile IDs

; Vector through the compiled sprite table.  The compiled sprites are in a different bank, so just check
; for a sentinel value and manually jump into the compiled sprite code to avoid a double-jump and having to
; have a second jump table in the compile sprite code bank.

        stal csd+1                     ; patch in the long address directly
        lda  sprTmp2+1                 ; load OAM[2] into accumulator
        pei  CMPL_BANK
        plb
csd     jml  $000000
draw_rtn2
        plb                           ; Return from compiled sprite
        DO   SHOW_DEBUG_VARS
        lda  #$7777
        stal outlineColor
        ldx  sprTmp1
        jmp  drawOutline
        FIN
        rts

; Finish calculating the jump address. We dispatch differently based on the horizontal flip, vertical
; flip and priority bits. when calling the rendering function, Y = screen address, X = tile data address

        mx    %00
as_bitmap
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
        DO   SHOW_DEBUG_VARS
        jsr  (drawProcs,x)            ; Executes an RTS to return directly to caller
        ldx  sprTmp1
        jmp  drawOutline
        ELSE
        jmp  (drawProcs,x)            ; Executes an RTS to return directly to caller
        FIN

        mx    %00
as_bitmap_clip
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
        jmp  (drawProcsClipped,x)

; CHR-RAM support: recompile one sprite tile (FastROMMaskedTileToLookup,
; no CompileSprite -- HAS_CHR_RAM games don't support compiled sprites) if
; its dirty flag is set. Input: sprTmp2 low byte = tile ID (OAM[1]). 16-bit
; A/X/Y required and preserved.
        DO    HAS_CHR_RAM
        mx    %00
CheckSprTileDirty
        and   #$00FF
        oral  spadr_lo                ; are we within the first or second set of tiles?
        tax

; The ChrRamDirty array is indexed 0-511, spanning *both* CHR-RAM pattern
; tables

        sep   #$20                    ; 8-bit A for the byte-table check/clear
        ldal  ChrRamDirty,x
        beq   :sprclean
        lda   #0
        stal  ChrRamDirty,x           ; STZ has no long,x addressing mode
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

        jmp   FastROMMaskedTileToLookup

:sprclean
        rep   #$20
        rts
        FIN

drawProcs
        dw drawTileToScreen,drawTileToScreenP,drawTileToScreenH,drawTileToScreenPH
        dw drawTileToScreenV,drawTileToScreenPV,drawTileToScreenHV,drawTileToScreenPHV

drawProcsClipped
        dw drawClippedTileToScreen,drawClippedTileToScreenP,drawClippedTileToScreenH,drawClippedTileToScreenPH
        dw drawClippedTileToScreenV,drawClippedTileToScreenPV,drawClippedTileToScreenHV,drawClippedTileToScreenPHV

; Array of dispatch addresses.  There is a special address of $0000 in the table that immediately returns
; from the compiled sprite code bank for sprites that do not have a compiled representation.
spr_comp_tbl ds 512,$00

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

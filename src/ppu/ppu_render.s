; ppu_render.s - Full renders
;
; drawScreen redraws the whole screen; drawScreenRange redraws a range of lines (custom renderers, split
; screens).  They are used when the background scrolled or has to be refreshed, and by the games
; without dirty rendering.  Frames with a still, cell-aligned background go to the grid renderer
; instead (gridDrawDirty, ppu_grid_quads.s).  In a full render:
;   1. The shadow bitmap is converted to a list of (top, bottom) scanline runs
;      that contain active sprites.
;   2. Scanlines with sprites are rendered into the shadow screen with
;      shadowing OFF (so sprites are invisible until exposed).
;   3. Sprites are drawn on top.
;   4. Shadowing is turned ON and the sprite/background runs are exposed
;      to the real SHR screen with alternating BltRange/PEISlam passes.

; VOC spike (SMB only): the background is drawn into bank $01 and shadowed to $E1, and the sprites go
; straight into bank $E0, the Video Overlay Card's plane.  The sprites are tracked with the grid
; renderer's records (ppu_grid_quads.s): the previous frame's sprite cells are erased to zero (the
; chroma key) with the VOC capture off, the new sprites are drawn with it on, and then every cell that
; was erased or drawn is written again (the expose pass, with DBR = $E0), so the VOC sees the result.
        mx   %00
drawScreen
        ldx   #0                      ; The background, in one pass (shadowing is on)
        ldy   #y_height
        jsr   _BltRangeLite

; 0. The span of the plane the Memory Manager owns (core/Memory.s): its bytes out, the plane's in (the
; sprite routines read the plane).  Until step 5, nothing may call the Memory Manager.

        jsr   VocCaptureOff
        jsr   vocSwapIn

; 1. Replay the previous frame's sprite records into the erase nibble (as gridDrawDirty)

        ldx   gqPrevEnd
        cpx   gqPrevBase
        beq   :rdone
        sep   #$20
        mx    %10
        lda   #$60                    ; RTS after the last record
        sta:  $0000,x
        rep   #$20
        mx    %00
        lda   gqPrevBase
        sta   :rjsr+1
        ldx   GridLPtr                ; The replay routines keep the list write pointer in X
:rjsr   jsr   $0000
        stx   GridLPtr
        ldx   gqPrevEnd
        sep   #$20
        mx    %10
        lda   #$A0                    ; Restore the template
        sta:  $0000,x
        rep   #$20
        mx    %00
:rdone

; 2. Erase them in bank $E0 without the VOC seeing it

        jsr   VocCaptureOff
        lda   GridLPtr
        dec
        tax
        ldy   #$E0E0
        lda   #gqVocEraseOp
        jsr   gqRunCells
        jsr   VocCaptureOn

; 3. The new sprites (drawSprites runs with DBR = $E0), which mark their cells' expose nibble

        jsr   drawSprites

; 4. Write the erased and drawn cells again for the VOC, and clear the cells

        lda   GridLPtr
        dec
        tax
        ldy   #$E0E0
        lda   #gqExposeOp
        jsr   gqRunCells
        jsr   gqSwap

; 5. The span back to the Memory Manager, with the capture off: the VOC keeps the sprites

        jsr   VocCaptureOff
        jsr   vocSwapOut
        jmp   VocCaptureOn

; Swap the Memory Manager's span of the plane (vocLoAddr, vocLen bytes) through the swap bank B
; (vocSwapBank): the plane's copy at B/addr - $2000, the Memory Manager's bytes at B/addr + $6000.  DBR = K.
        mx   %00
vocSwapIn
        ldal  vocLen
        beq   :out
        ; $E0 span -> B/addr + $6000
        jsr   vocSetBanks
        ldal  vocLoAddr
        tax
        clc
        adc   #$6000
        tay
        jsr   vocMove
        ; B/addr - $2000 -> $E0 span
        jsr   vocSetBanksRev
        ldal  vocLoAddr
        tay
        sec
        sbc   #$2000
        tax
        jsr   vocMove
:out    rts

        mx   %00
vocSwapOut
        ldal  vocLen
        beq   :out
        ; $E0 span -> B/addr - $2000
        jsr   vocSetBanks
        ldal  vocLoAddr
        tax
        sec
        sbc   #$2000
        tay
        jsr   vocMove
        ; B/addr + $6000 -> $E0 span
        jsr   vocSetBanksRev
        ldal  vocLoAddr
        tay
        clc
        adc   #$6000
        tax
        jsr   vocMove
:out    rts

; Patch the move's banks: vocSetBanks = from $E0 to B, vocSetBanksRev = from B to $E0
        mx   %00
vocSetBanks
        ldal  vocSwapBank
        sep   #$20
        sta   vocMv+1                 ; (MVN: opcode, destination bank, source bank)
        lda   #$E0
        sta   vocMv+2
        rep   #$20
        rts

        mx   %00
vocSetBanksRev
        ldal  vocSwapBank
        sep   #$20
        sta   vocMv+2
        lda   #$E0
        sta   vocMv+1
        rep   #$20
        rts

; X = source address, Y = destination address: move vocLen bytes.  DBR = K on exit.
        mx   %00
vocMove
        ldal  vocLen
        dec
        phb
vocMv   db    $54,$00,$00             ; mvn (patched)
        plb
        rts

; The VOC erase handler (gqRunCells).  Y = cell, DBR = $E0.  Zero the cell's erase quadrants (4 lines x
; 1 word each: TL, TR, BL, BR = bits 1-4 of the mask * 2).  The cell keeps its bits for the expose pass.
        mx   %00
gqVocEraseOp
        tyx
        ldal  gqGrid,x
        and   #GQ_ERASE
        beq   :out
        sta   tmp5
        ldal  PPU_MEM+GRID_CELL_SCR,x
        beq   :out                    ; Pad cell
        tay
        lda   #0
        lsr   tmp5                    ; (bit 0 is always clear)
        lsr   tmp5
        bcc   :tr
        sta:  {0*SHR_LINE_WIDTH},y
        sta:  {1*SHR_LINE_WIDTH},y
        sta:  {2*SHR_LINE_WIDTH},y
        sta:  {3*SHR_LINE_WIDTH},y
:tr     lsr   tmp5
        bcc   :bl
        sta:  {0*SHR_LINE_WIDTH}+2,y
        sta:  {1*SHR_LINE_WIDTH}+2,y
        sta:  {2*SHR_LINE_WIDTH}+2,y
        sta:  {3*SHR_LINE_WIDTH}+2,y
:bl     lsr   tmp5
        bcc   :br
        sta:  {4*SHR_LINE_WIDTH},y
        sta:  {5*SHR_LINE_WIDTH},y
        sta:  {6*SHR_LINE_WIDTH},y
        sta:  {7*SHR_LINE_WIDTH},y
:br     lsr   tmp5
        bcc   :out
        sta:  {4*SHR_LINE_WIDTH}+2,y
        sta:  {5*SHR_LINE_WIDTH}+2,y
        sta:  {6*SHR_LINE_WIDTH}+2,y
        sta:  {7*SHR_LINE_WIDTH}+2,y
:out    rts

; The engine's full render, before the VOC spike
        mx   %00
drawScreenShadow

; Step 0: Convert the bitmap into a list since it can be reused in Steps 1 and 3

        jsr   shadowBitmapToList

; Step 1: Draw the PEA lines that have sprites on them

        jsr   _ShadowOff
        jsr   drawShadowList

; Step 2: Draw the sprites

        jsr   drawSprites
        jsr   _ShadowOn

; Step 3: Reveal the sprites and background using alternating render and PEI slams

        jmp   exposeShadowList

; Full redraw of a range of screen lines at the current scroll position (_SetScroll), as drawScreen
; does for the whole screen.  This also sets up the code field, for these lines only.
; The other lines are not touched, so a custom renderer can draw each part of a split screen with
; its own scroll position, or leave a part of the screen as it is.
;
; A = first screen line
; X = number of lines
        mx   %00
drawScreenRange
        sta   dsrTop
        stx   dsrEnd
        clc
        adc   dsrEnd
        sta   dsrEnd

        ldy   StartX
        lda   dsrTop
        jsr   _BltSetupAlt

        jsr   shadowBitmapToList      ; Sprite lines, clipped to the range
        ldx   dsrEnd
        lda   dsrTop
        bne   :clip
        cpx   #y_height               ; (the list is already within the whole screen)
        bcs   :no_clip
:clip   jsr   clipShadowList
:no_clip

        jsr   _ShadowOff
        jsr   drawShadowList
        jsr   drawSprites
        jsr   _ShadowOn
        ldx   dsrTop
        ldy   dsrEnd
        jsr   exposeShadowListRange

        DO    ENABLE_DIRTY_RENDERING
        jsr   gridEndFull             ; drawSprites recorded this frame's sprite cells
        FIN
        rts

dsrTop    dw  0
dsrEnd    dw  0

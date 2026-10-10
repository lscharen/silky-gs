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

; Render the prepared frame data
        mx   %00
drawScreen

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

; Full redraw of a range of screen lines at the current scroll position (NES_SetScroll), as drawScreen
; does for the whole screen.  This also sets up and restores the code field, for these lines only.
; The other lines are not touched, so a custom renderer can draw each part of a split screen with
; its own scroll position, or leave a part of the screen as it is.
;
; A = first screen line
; X = number of lines
        mx   %00
drawScreenRange
        sta   dsrTop
        stx   dsrCount
        clc
        adc   dsrCount
        sta   dsrEnd

        ldy   StartX
        lda   dsrTop
        jsr   _BltSetupAlt
        sta   dsrExit

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

        lda   dsrTop
        ldx   dsrCount
        ldy   dsrExit
        jmp   _RestoreBG0OpcodesAltLite

dsrTop    dw  0
dsrCount  dw  0
dsrEnd    dw  0
dsrExit   dw  0

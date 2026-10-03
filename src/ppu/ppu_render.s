; ppu_render.s - Frame Rendering Mode Dispatchers
;
; This file contains the two top-level rendering routines that orchestrate
; how a completed NES frame is drawn to the IIgs SHR screen.
;
; drawScreen -- Full redraw (used when the background is scrolling)
; ---------------------------------------------------------------
; When scroll_x or scroll_y changes between frames the entire background must
; be regenerated from the PEA field.  In this mode:
;   1. The shadow bitmap is converted to a list of (top, bottom) scanline runs
;      that contain active sprites.
;   2. Scanlines with sprites are rendered into the shadow screen with
;      shadowing OFF (so sprites are invisible until exposed).
;   3. Sprites are drawn on top.
;   4. Shadowing is turned ON and the sprite/background runs are exposed
;      to the real SHR screen with alternating BltRange/PEISlam passes.
; After drawScreen completes, DirtyState is reset to 0.
;
; drawDirtyScreen -- Optimized redraw (static background)
; -------------------------------------------------------
; When the background does not scroll, only the scanlines occupied by sprites
; need to be touched.  This routine manages a three-state state machine:
;
;   DirtyState 0 -> 1 (first dirty frame after a full redraw):
;     The previous frame's sprites are still on-screen.  Erase them by
;     re-rendering the affected background scanlines (shadow off), then draw
;     the new sprites and expose only the changed scanlines.
;
;   DirtyState 1 -> 2 (steady-state dirty rendering):
;     Previous sprite pixels were saved to a backing store before drawing.
;     Restore those pixels (erasing old sprites), draw new sprites into the
;     backing store, then expose the changed 8x8 blocks.
;
;   DirtyState 2 (maintained):
;     Same as state 2 above; stays in state 2 as long as the background is
;     static and the dirty bit is not cleared.
;
; Calling drawScreen always resets DirtyState to 0.

        mx   %00
drawDirtyScreen

        lda   DirtyState              ; Move the Dirty State from 0 -> 1, 1 -> 2, or 2 -> 2
        cmp   #2                      ; Calling the drawScreen function will always set the
        bcs   :no_change              ; dirty state to zero.
        inc
        sta   DirtyState
:no_change

        cmp   #1                      ; Are we in a transitional state?
        beq   :dirty_state_1

; Dirty State 2 -- erase the old sprites by restoring the background data and draw the new
;                  sprites on top and then blit 8x8 regions to expose the changes.
;
;                  In this state any background tile updates are drawn on-screen and into
;                  the background, as well.  This is still a win in the common cases where
;                  only a score or timer is changing a few frames each second.  The code
;                  to determine whether there are "too many" background tiles updated happen
;                  outside of this loop and are responsible for setting the appropriate DirtyBits
;
; An simple sequence of actions are
;
; 1. Turn shadowing off
; 2. Erase sprites from the prior frame using the backing store
; 3. Draw scanlines that were updated this frame AND intersect sprites from the current frame
; 4. Turn shadowing on
; 5. Draw the new sprites
; 6. Draw the scanlines that were updated this frame AND NOT intersect sprites from the current frame
; 7. Expose the scanlines from (3)
; 8. Expose the 8x8 blocks from the sprites erased in (2)
;
; An ideal scenario would have a fast way to test if an 8x8 block was covered by the scanline update so that
; sprites in (2) could be skipped if the full scanline would be updated in (3) any way.
;
; Also, for the sprites themselves, we can bin the sprites into 16x16 blocks so that the prior location of a sprite
; and the current location have a high probability of being exposed by a single 16x16 blit.  This is also helpful
; because sprites and extend off the edge of the screen, and by binning, we can be sure that the sprite data
; located off-screen is ever exposed.

        jsr   _ShadowOff              ; Hide the fact that we're erasing the sprites from the priorframe
        jsr   restoreTilesToScreen    ; Redraw the background for all of the previous sprites.  The background is now fully restored.

        jsr   _ShadowOn               ; Now we can show the sprites again
        jsr   drawSprites             ; Draw the new sprites; some parts of the old sprites may still be on-screen

        jsr   exposeTilesToScreen

        rts

; Dirty State 1 -- no saved sprite data, so need to redraw whole scanlines to erase the previous frame's
;                  sprites
;
; Step 1: Draw the lines that had sprites on them and need to have sprites drawn
;         this frame.  This is shadowBitmap0 AND shadowBitmap1.  This is drawn with
;         shadowing off just to prep the screen.
:dirty_state_1

        DO    DIRTY_RENDERING_VISUALS
        lda   #1
        sta   DebugSCB
        FIN

        jsr   _ShadowOff
        jsr   clearPreviousSprites

; Step 2: Draw the sprites

        DO    DIRTY_RENDERING_VISUALS
        lda   #2
        sta   DebugSCB
        FIN

        jsr   drawSprites
        jsr   _ShadowOn

; Step 3: This is different than the non-dirty case.  Because the background is presumed to
;         not be moving, we are not as constrained to do a single top-to-bottom wipe to minimize
;         tearing.  So, instead we do two separate passes to "erase" the lines that held prior
;         sprites, but are not in the current frame, plus the background lines.
;
;         The bitmap is (prev | background) & ~current

        DO    DIRTY_RENDERING_VISUALS
        lda   #4
        sta   DebugSCB
        FIN

        jsr   drawOtherLines

; Step 4: This is the PEI Slam of the current sprites.

        jmp   exposeCurrentSprites


; Render the prepared frame date
        mx   %00
drawScreen

; Reset the dirty state to 0 (normal)

        stz   DirtyState

; Clear any saved sprite background data if the previous frame was dirty

        lda   SprSaveTop
        sta   SprSaveAddr

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

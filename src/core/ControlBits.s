; A = 0 turn off background
; A > 0 turn on background
          mx    %00
EnableBackground
    cmp   #0
    beq   :turn_off
    lda   #CTRL_BKGND_ENABLE
    tsb   ControlBits
    bne   :done
    lda   #DIRTY_BIT_BG0_REFRESH     ; If the state of the background enable bit changed, trigger a refresh
    tsb   DirtyBits
    rts

:turn_off
    lda   #CTRL_BKGND_ENABLE
    trb   ControlBits
    beq   :done
    lda   #DIRTY_BIT_BG0_REFRESH     ; If the state of the background enable bit changed, trigger a refresh
    tsb   DirtyBits

:done
    rts

; A = 0 turn off sprites
; A > 0 turn on sprites
          mx    %00
EnableSprites
    cmp   #0
    beq   :turn_off
    lda   #CTRL_SPRITE_ENABLE
    tsb   ControlBits
    rts

:turn_off
    lda   #CTRL_SPRITE_ENABLE
    trb   ControlBits
    rts

; A = HORIZONTAL_MIRRORING or VERTICAL_MIRRORING
;
; Lightweight entry point, safe to call directly from NES ROM code (JSL,
; cross-bank -- see the Zelda ROM segments' SetMMC1Control patch). The
; engine's own direct page is NOT active there (NES ROM code runs with its
; own direct page), so this must touch only absolute/long-addressable
; state, never DP -- it just remembers the requested mode in
; PendingMirrorMode (scaffold.s) for ApplyMirrorMode (below) to pick up at
; render time, when the engine's own direct page is active again and it's
; safe to actually reconfigure anything.
          mx    %00
SetMirrorMode ENT
    stal  PendingMirrorMode
    rtl                      ; called via JSL from a different physical bank

; Finish reconfiguring the engine for a mode change SetMirrorMode (above)
; requested -- the parts too expensive/disruptive to do mid-frame from NES
; ROM code (PEA-field patching, blitter jump tables, PPU tile-mapping
; tables; DP MirrorMask/MirrorMaskX/MirrorMaskY, Defs.s, get set as a side
; effect inside _InitHorizontalMirroring/_InitVerticalMirroring). Call this
; once per frame before rendering (see PRE_RENDER in each game's Main.s,
; matching the existing CheckForPaletteChange precedent).
          mx    %00
ApplyMirrorMode
    lda   PendingMirrorMode
    beq   :done

    jsr   PPUSetMirrorMode
    stz   PendingMirrorMode

:done
    rts
; ppu_frame.s - The engine side of a frame render
;
; NES_RenderFrame (scaffold.s) runs the game's PRE_RENDER / POST_RENDER hooks around two calls into
; the engine:
;
;   RenderLatch  latch the NES state the render uses (nametable queues, PPU registers, OAM) with
;                interrupts off
;   RenderDraw   apply the queued tile updates and draw the screen (RenderScreen, or the game's
;                CUSTOM_RENDER_SCREEN_ADDR)
;
; Both are called with JSL and set DBR to the engine bank.  RenderScreen, the debug display and the
; shadowing / screen rectangle helpers the renderer uses are here as well.

; Latch the NES state for this render.  Called with JSL; 16-bit registers.
            mx  %00
RenderLatch ENT
            phb
            phk
            plb
; First, disable interrupts and perform the most essential functions to copy any critical NES data and
; registers into local memory so that the rendering is consistent and not affected if a VBL interrupt
; occures between here and the actual screen blit

            php
            sei

; Freeze the nametable updates: the buffer and attribute list the ROM has been filling become the ones
; this render draws, and new PPU writes go to the other buffer, so they don't interfere with the render
            jsr  PPUFreezeNametableUpdates

            DO   CUSTOM_PPU_CTRL_LOCK
            CUSTOM_PPU_CTRL_LOCK_CODE
            ELSE
            lda  ppuctrl                  ;  Cache these values that are used to set the view port
            FIN
            sta  _ppuctrl
            jsr  PPUCtrlDecode            ; Resolve the pattern table addresses from the last PPUCTRL write

            DO   CUSTOM_PPU_SCROLL_LOCK
            CUSTOM_PPU_SCROLL_LOCK_CODE
            ELSE
            lda  ppuscroll
            FIN
            sep  #$20
            sta  _ppuscroll_y             ; 8-bit values are not contiguous in order to allow blended 8/16 access
            xba
            sta  _ppuscroll_x
            rep  #$20

            lda  ppumask
            and  ppumask_override
            sta  _ppumask

            and  #NES_PPUMASK_BG         ; honor the PPU enable flags for sprites and background. It's important to 
            jsr  EnableBackground        ; set the sprite disable flag here because it is used by scanOAMSprites

            lda  _ppumask
            and  #NES_PPUMASK_SPR
            jsr  EnableSprites

            jsr  scanOAMSprites            ; Copy the sprite OAM data into internal RAM space for rendering

            plp
            plb
            rtl

; Apply the queued tile updates and draw the screen.  Called with JSL; 16-bit registers.
            mx  %00
RenderDraw ENT
            phb
            phk
            plb

; If there are background updates to make, force a screen refresh.  Here and not in RenderLatch: the
; game's PRE_RENDER hook runs in between and can add to the frozen queues.  The grid renderer decides
; for itself in gridPrepare, since it can apply a limited number of background tile updates directly.

            DO   ENABLE_DIRTY_RENDERING
            bra  :no_force
            FIN
            lda  at_prev_count            ; Any queued attribute group means background changes
            beq  :no_force
            lda  #DIRTY_BIT_BG0_REFRESH
            tsb  DirtyBits
:no_force

; Apply all of the tile updates that were made during the previous frame(s).  The color attribute bytes are always set
; in the PPUDATA hook, but then the appropriate tiles are queued up.  These tiles, the tiles written to by PPUDATA in
; the range ($2{n+0}00 - $2{n+3}C0)
;
; The queue is set up as a Set, so if the same tile is affected by more than one action, it will only be drawn once.
; Practically, most NES games already try to minimize the number of tiles to update per frame.

;            jsr   PPUFlushQueues
            jsr   PPUFlushQueuesAlt

; The game switched the background pattern table (PPUCtrlDecode): every tile in the PEA field is from
; the old table, so redraw them all -- both pattern tables are compiled -- and render the whole screen.
; Here, for every renderer, the custom ones included.

            lda   #DIRTY_BIT_TILE_REDRAW
            trb   DirtyBits               ; (Z: it wasn't set)
            beq   :no_redraw
            ldx   #$0000                  ; The tile tables are indexed by CIRAM address, so refresh
            jsr   RefreshPPUTiles         ; both physical nametables ($000 and $400), not PPU $2000
            ldx   #$0400
            jsr   RefreshPPUTiles
            lda   #DIRTY_BIT_BG0_REFRESH
            tsb   DirtyBits
:no_redraw

; Finally, render the PEA field to the Super Hires screen.  The performance of the runtime is limited by this
; step and it is important to keep the high-level rendering code generalized so that optimizations, like falling
; back to a dirty-rectangle mode when the NES PPUSCROLL does not change, will be important to support good performance
; in some games -- especially early games that do not use a scrolling playfield.

            DO    RENDER_VBL_COUNT       ; schedTask counts the VBLs that occur while renderActive is set
            lda   #0
            stal  renderVblTicks
            lda   #1
            stal  renderActive
            FIN

            DO    CUSTOM_RENDER_SCREEN
            jsr   CUSTOM_RENDER_SCREEN_ADDR
            ELSE
            jsr   RenderScreen
            FIN

            plb
            rtl

; The PPUMASK enable bits, latched by RenderLatch (moved here from ControlBits.s)
;
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

; Helper that can be called by custom renderers to display the standard debug variable
_ShowDebugInfo
            DO    SHOW_DEBUG_VARS
            inc   dirtyCount
            ldx   frameTick
            lda   Mul160Tbl,x
            tax
            lda   #$EEEE
            stal  $012000+{40*160},x

; Show the current frames per second
            ldal  framesPerSecond
            ldx   #0
            ldy   #$FFFF
            jsl   DrawByteL

; Show the current player one input byte
            lda   InputPlayer1
            ldx   #8*160
            ldy   #$FFFF
            jsl   DrawWordL

; Show the number of dirty and full frames rendered
            lda   dirtyCount
            ldx   #16*160
            ldy   #$EEEE
            jsl   DrawWordL

            lda   fullCount
            ldx   #24*160
            ldy   #$8888
            jsl   DrawWordL


; Show the size of the attribute queues (current, previous)
            lda   at_count
            ldx   #{0*160}+144
            ldy   #$FFFF
            jsl   DrawWordL

            lda   at_prev_count
            ldx   #{8*160}+144
            ldy   #$FFFF
            jsl   DrawWordL

; Move the frameTick to the next position
            lda   frameTick
            inc
            inc
            and   #$00FE
            sta   frameTick
            FIN

            rts

; Default render screen implementation.  The user-code can override this and provide their
; own to improve performance.
            mx  %00
RenderScreen
            jsr   _ShowDebugInfo
            
            lda   _ppuctrl                ; Set the engine to the scroll position from this frame's
            ldx   _ppuscroll_x            ; PPU register values (the nametable select bits are masked
            ldy   _ppuscroll_y            ; by NES_SetScroll)
            jsr   NES_SetScroll

; Dirty rendering (the grid renderer) or not

            DO    ENABLE_DIRTY_RENDERING

; If this frame did not scroll, the grid renderer may be able to draw only what changed

            lda   #DIRTY_BIT_BG0_X+DIRTY_BIT_BG0_Y+DIRTY_BIT_BG0_REFRESH
            bit   DirtyBits
            bne   :full_update
            lda   disableDirtyRendering
            bne   :full_update

; The grid renderer never executes the code field, so it does not need the exit points patched
            jsr   gridPrepare
            bcs   :full_update
            jsr   gridDrawDirty
            bra   :done

:full_update
            lda   #0                      ; (grid builds: drawScreenRange records the sprite cells
            ldx   ScreenHeight            ; for the next frame)
            jsr   drawScreenRange
:done

            ELSE

            jsr   _BltSetup

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen
            FIN

            stz   DirtyBits
            rts

; If dirty rendering is turned on, provide a way to override it
disableDirtyRendering dw 0


; Debug counters (SHOW_DEBUG_VARS)
fullCount       dw  0
dirtyCount      dw  0
frameTick       dw  0

; Enable/Disable Shadowing.
                 mx    %00
_ShadowOn
                 sep   #$20
                 ldal  SHADOW_REG
;                 and   #$F7
                 and   #$F1
                 stal  SHADOW_REG
                 rep   #$20
                 rts

                 mx    %00
_ShadowOff
                 sep   #$20
                 ldal  SHADOW_REG
;                 ora   #$08
                 ora   #$0E
                 stal  SHADOW_REG
                 rep   #$20
                 rts

; Set the physical location of the virtual screen on the physical screen. The
; screen size must by a multiple of 8
;
; A = XXYY where XX is the left edge [0, 159] and YY is the top edge [0, 199]
; X = width (in bytes)
; Y = height (in lines)
;
; This subroutine stores the screen positions in the direct page space and fills
; in the double-length ScreenAddrR table that holds the address of the right edge
; of the playfield.  This table is used to set addresses in the code banks when the
; virtual origin is changed.
;
; We are not concerned about the raw performance of this function because it should
; usually only be executed once during app initialization.  It doesn't get called
; with any significant frequency.

                   mx    %00
SetScreenRect      sty   ScreenHeight               ; Save the screen height and width
                   stx   ScreenWidth

                   jsr   _PEAFieldStable            ; RTable changes: forget the code field's
                   pha                              ; ranges (their stack addresses must be
                   lda   #$FFFF                     ; copied again)
                   stal  stkKeyCount
                   stal  stkKeyCount+2
                   stal  stkKeyCount+4
                   stal  stkKeyCount+6
                   pla

                   tax                              ; Temp save of the accumulator
                   and   #$00FF
                   sta   ScreenY0
                   clc
                   adc   ScreenHeight
                   sta   ScreenY1

                   txa                              ; Restore the accumulator
                   xba
                   and   #$00FF
                   sta   ScreenX0
                   clc
                   adc   ScreenWidth
                   sta   ScreenX1

                   lda   ScreenY0                   ; Calculate the address of the first byte
                   asl                              ; of the right side of the playfield
                   tax
;                   lda   ScreenAddr,x               ; This is the address for the edge of the physical screen
;                   clc
                   lda   Mul160Tbl,x
                   adc   #$2000
                   adc   ScreenX1
                   dec
                   pha                              ; Save for second loop

                   ldx   #0
                   ldy   ScreenHeight
:loop              clc
                   sta   RTable,x
                   adc   #160
                   inx
                   inx
                   dey
                   bne   :loop

                   ldy   ScreenHeight
                   pla                              ; Reset the address and continue filling in the
:loop2             clc
                   sta   RTable,x
                   adc   #160
                   inx
                   inx
                   dey
                   bne   :loop2

; Calculate the screen locations for each tile corner

                   lda   ScreenY0                   ; Calculate the address of the first byte
                   asl                              ; of the right side of the playfield
                   tax
;                   lda   ScreenAddr,x               ; This is the address for the left edge of the physical screen
;                   clc
                   lda   Mul160Tbl,x
                   adc   #$2000
                   adc   ScreenX0

                   rts

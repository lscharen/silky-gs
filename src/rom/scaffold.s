; This file contains all of the core routines that should be called from the
; wrapper code.  It is expected that the wrapped defined several callback functions
; and constants that can be used to parametering the NES runtime layer

; Scaffold init
;
; Should be called immediately after the application gets control from GS/OS and
; only called once.
;
; A = cartridge configuration.  Bits 0 and 1 are the nametable mirroring at power on
;     (HORIZONTAL_MIRRORING or VERTICAL_MIRRORING).  For mappers that can switch the
;     mirroring, like the MMC1, this is the mode at a cold start.
; X = memory manager user ID (GS/OS passes it to the application in A)
            mx    %00
NES_StartUp
            stx   UserId
            and   #HORIZONTAL_MIRRORING+VERTICAL_MIRRORING
            sta   PendingMirrorMode       ; Applied by PPUStartUp
            _MTStartUp                    ; Require the miscellaneous toolset to be running
            bcc   *+5
            brl   Fail

; Keep a copy of the application's direct page to be restored later

            tdc
            sta   DPSave

            clc
            adc   #$100
            sta   DP_OAM                  ; Use direct page space for the PPU OAM memory

            clc
            adc   #$100                   ; This is the NES direct page space
            sta   DP_NES
            adc   #$1FF                   ; And the next page is the stack page

; Set up the initial register values when transferring control to the NES ROM code

            sta   nesStackTop             ; Initial NES task stack pointer

; Default bank for MMC1 games

            lda   #^ROMBase               ; Start off in Bank 0 of the ROM
            and   #$00FF
            sta   mapper_bank

            stz   chr_bank                 ; Stub for future MMC1 CHR-bank switching

; Set the pointers to the CHR memory dirty bytes for CHR-RAM games

            lda   #ChrRamDirty
            sta   TileChrMem
            clc
            adc   #$100
            sta   SprChrMem
            lda   #^ChrRamDirty
            sta   TileChrMem+2
            sta   SprChrMem+2

; Initialize some application variables

            ldal  OneSecondCounter
            sta   OldOneSec

            stz   ShowFPS

            lda   #$0008
            sta   LastEnable

            stz   LastStatusUdt

            jsr   _GetBorderColor
            sta   BorderColor
            lda   #0
            jsr   _SetBorderColor

; Used for VOC rendering mode to toggle target of the PEA field render between
; bank $01 and $00

            lda   #1
            sta   ActiveBank

; Start up the runtime

            jsr   StartUp
            bcc   *+5
            jmp   Fail

; Initialize the PPU

            jsr   PPUStartUp
            bcc   *+5
            jmp   Fail

; Build the sprite Y filter used by scanOAMSprites from this game's playfield settings

            jsr   InitYExclude

; Initialize the sound hardware for APU emulation

            DO    NO_INTERRUPTS
            ELSE
            lda   config_audio_quality
            jsr   APUStartUp              ; APU_60HZ (external driver), APU_120HZ or APU_240HZ
            FIN

; Decode the game's DMC samples into DOC RAM up front (see DMC_SAMPLE_LIST in Main.s)

            DO    CACHE_DMC_SAMPLES
            jsr   APUCacheDMC
            FIN

; Clear the IIgs screen and initialize the rendering infrastrucure

            lda   #0
            jsr   _ClearToColor
            jsr   InitPlayfield

; CHR-ROM games have their tiles converted offline into the tiledata bank by
; build.js (scripts/lib/nromBuild.js) and compiled by Main.s. CHR-RAM games don't
; have a fixed image to pre-convert -- mark every tile dirty instead, so
; DrawPPUTile/CheckSprTileDirty lazily compile each tile the first time it's
; actually drawn (once the game has uploaded real data for it).

            DO    HAS_CHR_RAM
            ldx   #0
            lda   #$0303           ; both bytes = CHRRAM_BG_DIRTY+CHRRAM_SPR_DIRTY
:mtloop     sta   ChrRamDirty,x
            inx
            inx
            cpx   #512
            bcc   :mtloop
            FIN

; Battery-backed cartridges: restore the WRAM image ($6000-$7FFF of the NES address space, in the
; ROMBase bank) before any ROM code runs.  If there is no file yet (first run), WRAM is left as-is
; and the game sees the same uninitialized memory as a new cartridge.  Saved by NES_ShutDown.

            DO    HAS_BACKED_WRAM
            lda   #$2000
            ldx   #$6000
            ldy   #wrCreateRec
            jsr   LoadROMFile
            FIN

; Now the core of the runtime has been initialized
            rts

; Catastrophic failure
Fail        brk   $FE


; Perform any initialization actions
            mx  %00
StartUp
            lda   UserId
            jmp   _CoreStartUp

; Perform any shutdown/cleanup actions
            mx  %00
ShutDown
            jmp   _CoreShutDown

; NES_ColdBoot / NES_WarmBoot are in rom_exec.s

; A pair of utility functions to stop/start the actual execution of the game runtime.  This is
; used to cleanly suspend the VBL interrupt driver and allow "something else" to happen.  Typically
; this can be used to invoke the configuration screen and reset the runtime in the middle of running
; a ROM.
;
; NES_StopExecution
; NES_StartExecution
            mx  %00
NES_StopExecution
            lda  #1
            sta  skipInterruptHandling
            rts

            mx  %00
NES_StartExecution
            lda  #0
            sta  skipInterruptHandling
            rts

; NES_EvtLoop
;
; The main control loop.  Pressing 'q' will exit the driver.
            PRE_EVT_LOOP
            mx  %00
NES_EvtLoop
            EVT_LOOP_BEGIN

; If interrupts are disabled, then the ROM NMI interrupt needs to
; driven manually

            DO    NO_INTERRUPTS
            jsr   NES_TriggerNMI
            jsr   NES_ReadInput           ; .fm2 docs imply that the controller input is latched following the NMI
            ELSE

; Wait for a frame to become available.  This almost never waits, unless
; dirty rendering mode is on and there are no updates to the screen,
; or the user is running under emulation

:spin       lda  frameReady
            bne  :spin
            inc  frameReady
            FIN

; When this code has control the ROM is not executing, so render the
; current frame

            jsr   NES_RenderFrame

; MAME bench harness (scripts/run-bench.js): once the canned input file
; (BenchInputData) is exhausted, quit -- this has to happen here, right
; after a frame has actually rendered, rather than relying on the normal
; LastRead/PAD_KEY_DOWN check below returning control to the caller,
; since BENCH_MODE's NES_ReadInput never sets LastRead and the check
; below would just loop back to NES_EvtLoop forever.
            DO    BENCH_MODE
            ldal  BenchInputIndex
            cmp   #BENCH_MODE_LEN-1
            bcc   :bench_not_done
            lda   #'q'             ; make it a quit
            brl   :exit
:bench_not_done
            FIN

; The input is read from the VBL interrupt handler.  If no
; new key input is available, then nothing else to do here

            lda   LastRead
            bit   #PAD_KEY_DOWN
            beq   NES_EvtLoop

; Isolate the keycode and handle all of the built-in
; actions.  Afterwared, allow for application-specific
; handlers.

            and   #$007F

; '?' to bring up the configuration screen and reapply the settings

            DO    NO_CONFIG
            ELSE
            cmp   #'?'
            bne   :not_config
            jsr   APUStop                                ; Turn off the APU (restarted in Apply Config)
            jsr   NES_StopExecution                       ; Pause emulation nicely
            jsr   ShowConfig                              ; Let the user reconfigure
            jsr   ApplyConfig                             ; Apply to the running configuration
            lda   #DIRTY_BIT_BG0_REFRESH                  ; Force a full page refresh on config exit
            tsb   DirtyBits
            jsr   NES_StartExecution
            brl   NES_EvtLoop
:not_config
            FIN

; '0': force all of the APU channels to be turned off
;            cmp   #'0'
;            bne   :not_0
;            stz   APU_FORCE_OFF
;            brl   NES_EvtLoop
;:not_0
;
; '1' - '4': toggle individual APU channels
;            cmp   #'1'
;            bne   :not_1
;            lda   #$01
;            jsr   ToggleAPUChannel
;            brl   NES_EvtLoop
;:not_1
;
;            cmp   #'2'
;            bne   :not_2
;            lda   #$02
;            jsr   ToggleAPUChannel
;            brl   NES_EvtLoop
;:not_2
;
;            cmp   #'3'
;            bne   :not_3
;            lda   #$04
;            jsr   ToggleAPUChannel
;            brl   NES_EvtLoop
;:not_3
;
;            cmp   #'4'
;            bne   :not_4
;            lda   #$08
;            jsr   ToggleAPUChannel
;            brl   NES_EvtLoop
;:not_4

; From this point forward, only check alpha characters, so normalize to lower case

            ora   #$0020

; 'f': force a full repaint of the screen
            cmp   #'f'
            bne   :not_f
            jsr   ForceMetatileRefresh
            brl   NES_EvtLoop
:not_f

; 'b': force the NES Background bit to be toggled

            cmp   #'b'
            bne   :not_b
            lda   ppumask_override
            eor   #NES_PPUMASK_BG
            sta   ppumask_override
            brl   NES_EvtLoop
:not_b

; 's': force the NES Sprite bit to be toggled

            cmp   #'s'
            bne   :not_s
            lda   ppumask_override
            eor   #NES_PPUMASK_SPR
            sta   ppumask_override
            brl   NES_EvtLoop
:not_s

            cmp   #'r'
            beq   :exit

            cmp   #'q'
            beq   :exit

:next_loop
            EVT_LOOP_END
            brl   NES_EvtLoop
:exit
            POST_EVT_LOOP
            rts

; Clean up the runtime
            mx  %00
NES_ShutDown
            lda   BorderColor              ; Restore the border color
            jsr   _SetBorderColor

            DO    NO_INTERRUPTS
            ELSE
            jsr   APUShutDown
            FIN
            jsr   ShutDown

; Battery-backed cartridges: write the WRAM image back out.  Done after ShutDown, when the NES task
; can no longer be scheduled, so WRAM can't change while it is being written.

            DO    HAS_BACKED_WRAM
            lda   #$2000
            ldx   #$6000
            ldy   #wrCreateRec
            jsr   SaveROMFile
            FIN
            rts

OneSecondCounter  dw  0
DPSave            dw  0
DP_OAM            dw  0
DP_NES            dw  0
BorderColor       dw  0            ; save/restore border color

; Runtime nametable-mirroring mask, set by SetMirrorMode (ControlBits.s).
; Duplicates the DP MirrorMask (Defs.s) for use from contexts where the
; engine's own direct page isn't active (e.g. ppu_regs.s's PPU write
; handlers, entered from NES ROM code with the NES's own direct page) --
; those sites access this copy with long addressing (andl MirrorMaskLong)
; instead.
MirrorMaskLong ENT
             dw  0

; Corresponding mask for calculating the CIRAM location for a PPU
; nametable address
CIRAMRowMask ENT
             dw  0
CIRAMColMask ENT
             dw  0

; 0 = no mirroring-mode change pending; else HORIZONTAL_MIRRORING/
; VERTICAL_MIRRORING, the target mode ApplyMirrorMode should switch to at
; the next render (see core/ControlBits.s SetMirrorMode/ApplyMirrorMode).
; Absolute, not DP, for the same reason as MirrorMaskLong above --
; SetMirrorMode writes it via long addressing from NES ROM code.
;
; Note that the actual mask values have to be update dimmediately.  This
; flag is purly for deferred work that needs to happen before the next
; *render*
PendingMirrorMode ENT
            dw  0

; Built-in user key actions

; Toggle an APU control bit
            mx  %00
ToggleAPUChannel
            pha
            lda   #$0001
            stal  APU_FORCE_OFF
            pla

            php
            sep   #$30
            eorl  APU_STATUS
            jsl   APU_STATUS_FORCE
            plp
            rts


; Helper to perform the essential functions of rendering a frame
            mx  %00
NES_RenderFrame

; First, disable interrupts and perform the most essential functions to copy any critical NES data and
; registers into local memory so that the rendering is consistent and not affected if a VBL interrupt
; occures between here and the actual screen blit

            php
            sei

; Swap the attribute list halves so that any new PPU writes do not interfere with the current screen
; rendering code (PPUFreezeNametableUpdates below moves the write path to the other shadow buffer)

            lda  curr_at_list_start
            ldy  curr_at_list_end

            ldx  prev_at_list_start       ; Copy the previous list start address

            sta  prev_at_list_start       ; Make the previous list range point to the memory range
            sty  prev_at_list_end         ; of the current list and then reset the current list

            stx  curr_at_list_start       ; to point at the other memory range and initialize it
            stx  curr_at_list_end         ; to be an empty list ready for the next round of PPU writes

; If there are background updates to make, force a screen refresh.  The grid renderer decides for
; itself in gridPrepare, since it can apply a limited number of background tile updates directly.

            DO   ENABLE_DIRTY_RENDERING
            bra  :no_force
            FIN
            lda  prev_at_list_start       ; Any queued attribute group means background changes
            cmp  prev_at_list_end
            beq  :no_force
            lda  #DIRTY_BIT_BG0_REFRESH
            tsb  DirtyBits
:no_force

            DO   CUSTOM_PPU_CTRL_LOCK
            CUSTOM_PPU_CTRL_LOCK_CODE
            ELSE
            lda  ppuctrl                  ;  Cache these values that are used to set the view port
            FIN
            sta  _ppuctrl

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
            jsr  PPUFreezeNametableUpdates ; Copy the updated tile data into internal RAM space for rendering

            plp

; Allow the user code to introspect and intervene at this point

            PRE_RENDER

; Apply all of the tile updates that were made during the previous frame(s).  The color attribute bytes are always set
; in the PPUDATA hook, but then the appropriate tiles are queued up.  These tiles, the tiles written to by PPUDATA in
; the range ($2{n+0}00 - $2{n+3}C0)
;
; The queue is set up as a Set, so if the same tile is affected by more than one action, it will only be drawn once.
; Practically, most NES games already try to minimize the number of tiles to update per frame.

;            jsr   PPUFlushQueues
            jsr   PPUFlushQueuesAlt

; Finally, render the PEA field to the Super Hires screen.  The performance of the runtime is limited by this
; step and it is important to keep the high-level rendering code generalized so that optimizations, like falling
; back to a dirty-rectangle mode when the NES PPUSCROLL does not change, will be important to support good performance
; in some games -- especially early games that do not use a scrolling playfield.

            DO    RENDER_VBL_COUNT        ; schedTask counts the VBLs that occur while renderActive is set
            stz   renderVblTicks
            lda   #1
            sta   renderActive
            FIN

            DO    CUSTOM_RENDER_SCREEN
            jsr   CUSTOM_RENDER_SCREEN_ADDR
            ELSE
            jsr   RenderScreen
            FIN

            DO    RENDER_VBL_COUNT        ; Show the VBLs this render took at the top-left of the screen
            stz   renderActive
            lda   renderVblTicks
            ldx   #0                      ; SHR $2000
            ldy   #$FFFF                  ; colour 15
            jsr   DrawByte
            FIN

            DO    SHOW_FPS                ; Renders per second at the top-left of the screen
            jsr   DrawFPS
            FIN

; Game specific post-render logic

            POST_RENDER

; Internal post-render logic

            inc   frameCount       ; Tick over to a new frame
            rts

; SHOW_FPS: once a second (OneSecondCounter), draw the number of renders in the last second
; (framesPerSecond), in decimal, at the top-left of the screen (SHR $2000, the border left of the
; playfield).
; fpsValue keeps the number for tools that read memory.
            DO    SHOW_FPS
            mx    %00
DrawFPS
            ldal  OneSecondCounter
            cmp   fpsLastSec
            beq   :out
            sta   fpsLastSec
            ldal  framesPerSecond         ; Saved (8-bit) by the one-second interrupt, which also
            and   #$00FF                  ; resets frameCount
            sta   fpsValue
            ldx   #0                      ; To two BCD digits (at most 60 renders a second)
:tens       cmp   #10
            bcc   :bcd
            sbc   #10
            inx
            bra   :tens
:bcd        sta   fpsTmp
            txa
            asl
            asl
            asl
            asl
            ora   fpsTmp
            ldx   #0                      ; SHR $2000
            ldy   #$FFFF                  ; colour 15
            jsr   DrawByte
:out        rts

fpsLastSec   dw  0
fpsValue     dw  0
fpsTmp       dw  0
            FIN

; Helper functions for patching and restoring the PEA field.  These could
; be overridden for games that want to preserve the ability to switch between
; dirty and full rendering, but still have a custom screen layout
            mx  %00
_SetupPEAField
            jsr   _BltSetup
            sta   exitOffset              ; cache the :exit_offset value returned from this function

            lda   #1
            sta   peaFieldIsPatched
            rts

            mx  %00
_ResetPEAField
            stz   peaFieldIsPatched

            ldy   exitOffset              ; offset to patch
            jmp   _RestoreBG0OpcodesLite

; Given a nametable address ($2000 - $2FFF), return the screen address taking into account the current
; scroll position.
;
; The address is in the range $2000
;
; Input
;  X = nametable address
;
; Output
;  X = SHR address
;  C = 0 if visible, 1 if address is off-screen
            mx  %00
_NametableToScreen

; The hardest issue to handle here is properly handling wrap-around based on the current mirroring
; state of the game.
;
; Conceptually, the code looks up the logical row and column for the address and then adjusts the
; value by both the current scroll position as well as the clipped range of what is actually
; visible on the IIgs screen.
;
; Example: scroll_x = 45 and scroll_y = 168.  If vertical mirroring is on, then the maximum Y
;          value is 239 and the maximum X value is 511.  Assume the 
;
; x_blk = 8
;
; col[addr] = 0 to 32/64
; row[addr] = 0 to 30/60
;
; if mirror == horizontal, then all columns are always visible
; if mirror == vertical, then
; 
; The visible blocks are

; First, find the IIgs on-screen offset for this nametable address.

;            ldal PPU_MEM+TILE_COL,x       ; Get the logical column of this address
;            and  #$00FF

            txa
            ciram2col

            asl
            asl                           ; Multiple by 4 to convert column to width in IIgs SHR bytes
            sec
            sbc  _ppuscroll_x             ; Subtract off the current scroll position
            clc
            adc  MaxX                     ; Add in the width of the NES nametables, which depends on the mirroring mode
            cmp  MaxX
            bcc  :no_wrap_x
            sbc  MaxX                     ; If we wrapped around, subtract the width to get back into the visible range
:no_wrap_x
            cmp  #128                   ; Check to see if we're off outside of the visible area. C = 1 means abort
            bcc  :x_visible
            rts

:x_visible
;            ldal PPU_MEM+TILE_ROW,x       ; Get the logical row of this address
;            and  #$00FF
;            asl
;            asl
;            asl
            
            txa
            ciram2rowX8                   ; Get the logical row of this address and multiple by 8 to get a line

            sbc  _ppuscroll_y
            clc
            adc  MaxY                     ; Add in the height of the NES nametables,
            cmp  MaxY
            bcc  :no_wrap_y               ; If we wrapped around, subtract the height to get back into the visible range
            sbc  MaxY
:no_wrap_y

; At this point we have the scanline in term of NES scanlines, but the IIgs screen is only 200 lines tall,
; so it clips a 200-line range

            cmp  #y_offset
            bcc  :y_not_visible
            cmp  #max_nes_y
            bcc  :y_visible
:y_not_visible
            sec
:y_visible  rts


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
            lda   framesPerSecond
            ldx   #0
            ldy   #$FFFF
            jsr   DrawByte

; Show the current player one input byte
            lda   InputPlayer1
            ldx   #8*160
            ldy   #$FFFF
            jsr   DrawWord

; Show the number of dirty and full frames rendered
            lda   dirtyCount
            ldx   #16*160
            ldy   #$EEEE
            jsr   DrawWord

            lda   fullCount
            ldx   #24*160
            ldy   #$8888
            jsr   DrawWord


; Show the size of the attribute queues (current, previous)
            lda   curr_at_list_end
            sec
            sbc   curr_at_list_start
            ldx   #{0*160}+144
            ldy   #$FFFF
            jsr   DrawWord

            lda   prev_at_list_end
            sec
            sbc   prev_at_list_start
            ldx   #{8*160}+144
            ldy   #$FFFF
            jsr   DrawWord

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

; If this frame changed any of the background palettes, then we have to refresh all of the background tiles

            lda   #DIRTY_BIT_PAL_CHANGE
            bit   DirtyBits
            beq   :no_refresh
            ldx   #$0000                  ; The tile tables are indexed by CIRAM address, so refresh
            jsr   RefreshPPUTiles         ; both physical nametables ($000 and $400), not PPU $2000
            ldx   #$0400
            jsr   RefreshPPUTiles
            lda   #DIRTY_BIT_BG0_REFRESH
            tsb   DirtyBits
:no_refresh

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
            DO    GRID_FALLBACK_BORDER
            lda   #FB_COLOR_GRID          ; Grid frame: no fallback
            jsr   gridFallbackBorder
            FIN
            jsr   gridDrawDirty
            bra   :done

:full_update
            DO    ENABLE_DIRTY_RENDERING*GRID_FALLBACK_BORDER
            jsr   gridFallbackColor       ; Border color = why we fell back to a full render
            jsr   gridFallbackBorder
            FIN
            lda   #0                      ; (grid builds: drawScreenRange records the sprite cells
            ldx   ScreenHeight            ; for the next frame)
            jsr   drawScreenRange
:done

            ELSE

            jsr   _BltSetup
            sta   exitOffset              ; cache the :exit_offset value returned from this function

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen

; Restore the buffer

            ldy   exitOffset              ; offset to patch
            jsr   _RestoreBG0OpcodesLite
            FIN

            stz   DirtyBits
            rts

            DO    ENABLE_DIRTY_RENDERING*GRID_FALLBACK_BORDER
; Returns A = the border color for the reason this frame fell back to a full render.  The scaffold's
; own reasons are checked first; if none apply, gridPrepare was called and recorded its reason in
; gridFbReason.  Colors are listed with GRID_FALLBACK_BORDER in Defs.s.
            mx    %00
gridFallbackColor
            lda   DirtyBits
            bit   #DIRTY_BIT_BG0_X+DIRTY_BIT_BG0_Y
            bne   :scroll
            bit   #DIRTY_BIT_PAL_CHANGE
            bne   :palette
            bit   #DIRTY_BIT_BG0_REFRESH
            bne   :refresh
            lda   disableDirtyRendering
            bne   :disabled
            ldal  gridFbReason
            and   #$000F
            rts
:scroll     lda   #FB_COLOR_SCROLL
            rts
:palette    lda   #FB_COLOR_PALETTE
            rts
:refresh    lda   #FB_COLOR_REFRESH
            rts
:disabled   lda   #FB_COLOR_DISABLED
            rts

; A = border color (0-15).  Only the low nibble of $C034 is the border; the high nibble is the
; RTC interface and must be preserved.
            mx    %00
gridFallbackBorder
            sep   #$20
            pha
            ldal  BORDER_REG
            and   #$F0
            ora   1,s
            stal  BORDER_REG
            pla
            rep   #$20
            rts
            FIN

; Track if the PEA field is patched or not (for dirty rendering)
peaFieldIsPatched dw 0

; If dirty rendering is turned on, provide a way to override it
disableDirtyRendering dw 0

; PEA field offset for the right edge where the BRA instructions are patched in
exitOffset   ds 2

; Tracks the number of times NES_RenderFrame has been called
frameCount      dw  0
framesPerSecond dw  0
fullCount       dw  0
dirtyCount      dw  0
frameTick       dw  0

; Cleared when the NMI handler has run.  Used to limit updates to 60fps
frameReady      dw  0

; Set to abort from the VBL interrupt handler.  Effectively stops the execution of the ROM game code
skipInterruptHandling dw 0

; Flag to say if we're in pause/single-step mode
inSingleStep   dw 0
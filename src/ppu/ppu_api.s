; ppu_api.s - The engine's standard API for games
;
; The engine entry points a game's code (Main.s, and the callbacks its Hooks.s names) may call.  Each
; is called with JSL and returns with RTL, wherever the engine and the game are assembled; each sets
; the data bank it needs and restores the caller's.  16-bit registers on entry and exit; A, X and Y are
; not preserved.  Everything else in the engine is internal (ppu_entry.s has the runtime's own entry
; points) and may change.
;
; Data a game may read, with long addressing:
;   _ppuctrl, _ppuscroll_x, _ppuscroll_y   the PPU registers latched for the current render
; and, on the runtime's direct page: ScreenHeight (the playfield's lines) and StartX (the horizontal
; byte offset of the scroll position set by NES_SetScroll).
;
; The custom render screen.  A game that draws (some) renders itself sets CUSTOM_RENDER_SCREEN equ 1
; and CUSTOM_RENDER_SCREEN_ADDR equ <its routine> in Hooks.s, with "<routine> EXT" there and
; "<routine> ENT" at its definition.  RenderDraw (ppu_frame.s) calls it with JSL for every render, with
; 16-bit registers, D = the runtime's direct page and DBR = the engine's bank (use long addressing for
; the game's data, or set the bank and restore it).  It returns with RTL and
;   C = 1  it drew the screen (NES_SetScroll, then PPU_DrawScreenRange or PPU_SetupLines + PPU_DrawScreen),
;          A = the DirtyBits for the next render: normally 0; DIRTY_BIT_BG0_REFRESH if the engine may draw
;          the next one, so its renderer redraws everything (it can't know what the game's left on the
;          screen, e.g. the play area of a split screen at another scroll position)
;   C = 0  it did nothing: the engine's renderer draws the screen (and clears DirtyBits)
; The engine shows the debug display before it.
;
; The scroll and control locks.  A render latches the PPU registers' last values (RenderLatch); a game
; whose own copies are the ones to show (or that has more to latch with them) sets CUSTOM_PPU_CTRL_LOCK /
; CUSTOM_PPU_SCROLL_LOCK equ 1 and CUSTOM_PPU_CTRL_LOCK_ADDR / CUSTOM_PPU_SCROLL_LOCK_ADDR equ <routine>
; in Hooks.s, declared and defined as above.  RenderLatch calls them with JSL for every render, with
; interrupts off, 16-bit registers, D = the runtime's direct page and DBR = the engine's bank.  They
; return with RTL and
;   C = 1  A = the value to latch: PPUCTRL; or the scroll, X in the high byte and Y in the low byte
;   C = 0  the engine latches the register's last value
; The control lock runs first, then the scroll lock, both before the OAM is scanned.

            mx    %00

; Set the scroll position for what is drawn next, from values in the form of the NES PPU registers.
;
; A = nametable select (PPUCTRL bits 1:0)
; X = scroll x (0 - 255)
; Y = scroll y (0 - 255)
NES_SetScroll ENT
            phb
            phk
            plb
            jsr   _SetScroll
            plb
            rtl

; Draw a range of screen lines at the scroll position (NES_SetScroll): the background and the sprites.
; The other lines are left as they are, so a split screen draws each part with its own scroll position,
; or leaves a part as it is.
;
; A = first screen line
; X = number of lines
PPU_DrawScreenRange ENT
            phb
            phk
            plb
            jsr   drawScreenRange
            plb
            rtl

; Set up a band of screen lines for PPU_DrawScreen, at its own horizontal offset: StartX after
; NES_SetScroll, or e.g. 0 for a status bar that doesn't scroll.  The bands set up for a render cover
; the screen (ScreenHeight lines) without overlapping.
;
; A = first screen line
; X = number of lines
; Y = horizontal offset in bytes (0 - 255)
PPU_SetupLines ENT
            phb
            phk
            plb
            jsr   _BltSetupAlt
            plb
            rtl

; Draw the whole screen, in the bands PPU_SetupLines set up: the background and the sprites
PPU_DrawScreen ENT
            phb
            phk
            plb
            jsr   drawScreen
            DO    ENABLE_DIRTY_RENDERING
            jsr   gridEndFull             ; drawSprites recorded this frame's sprite cells
            FIN
            plb
            rtl

; The CHR-ROM (CHR_ROM, PPU $0000-$1FFF) was replaced, e.g. a CHR-ROM bank switch: convert all 512 tiles
; into the tiledata bank again, recompile the background tiles, drop the compiled sprites and redraw the
; whole background.  Very slow (a few seconds' worth of frames): for games that switch banks between
; screens.  Call from PRE_RENDER, with D = the runtime's direct page.
PPU_ReloadCHR ENT
            phb
            phk
            plb
            lda   #0                      ; the tile's tiledata address (tile * 128)
:tile       pha
            lsr                           ; X = its CHR address (tile * 16)
            lsr
            lsr
            tax
            lda   1,s
            jsr   FastROMMaskedTileToLookup
            pla
            clc
            adc   #128
            bne   :tile                   ; (512 tiles fill the bank: done when the address wraps to 0)
            jsr   ROM_CompileBackgroundTiles
            jsr   SprRequestFlush
            lda   #%1111                  ; every background palette's metatiles (and DIRTY_BIT_BG0_REFRESH)
            jsr   RefreshPPUAttributes
            plb
            rtl

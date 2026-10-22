; Contra -- game definition: the engine callbacks
;
; Every callback macro the engine expands, the flags that enable them, and the code and data behind
; them.  Every segment source that assembles engine code puts this file (after Config.s).  A macro
; only produces code where the engine expands it.
;
; The code and data are in two fences, by the segment the engine calls them from:
;
;   DO SEG_MAIN    the event loop and frame hooks: PRE_EVT_LOOP, POST_EVT_LOOP, EVT_LOOP_BEGIN /
;                  END, PRE_RENDER, POST_RENDER, CONFIG_APPLY_HOOK, start-up (InitPlayfield)
;   DO SEG_ENGINE  the renderer and the PPU write shims: SPRITE_PRE_DRAW, CUSTOM_PPU_CTRL_LOCK_CODE,
;                  CUSTOM_PPU_SCROLL_LOCK_CODE, CUSTOM_RENDER_SCREEN_ADDR, PPU_PALETTE_DISPATCH
;
; A segment source sets SEG_MAIN / SEG_ENGINE to 1 for the fences it assembles.  A macro calls the
; code in its own fence with jsr; anything in the other fence is in another bank.  Each fence starts
; and ends with an explicit mx (Merlin32 tracks sep / rep even in a skipped DO block).
;
; Merlin32 ignores a put inside a put file, so pal_transitions.s is put by Main.s.

            mx    %00

; Callback before entering the main event loop
PRE_EVT_LOOP mac
;
             <<<

POST_EVT_LOOP mac
;
             <<<

EVT_LOOP_BEGIN mac
;
             <<<

; This hook happens immediately after all key presses have been handled by the scaffold and gives
; user-code a change to implement custom key commands
EVT_LOOP_END mac
;
             <<<

; Pre-render check to see if there are any background tiles queued for updates.  If so, we will do
; a regular rendering.  If not, use dirty rendering.
PRE_RENDER   mac
             jsr  ApplyPaletteChange ; switch to a new palette detected since the last frame
             <<<

POST_RENDER  mac
;
             <<<

; Callback before each sprite is set up and drawn (drawSprites, ppu.s): X = OAM index, ]1 = the
; sprite height (8 or 16), DBR = $01 (the shadow screen), 16-bit registers.  Sets sprClipTop, the lines
; to hide at the top of the sprite: here, the lines in the door bands (see HideDoorBands).
SPRITE_PRE_DRAW  mac
;
             <<<

; Non-zero if SPRITE_PRE_DRAW can set sprClipTop: the sprite renderer only tests it then
SPRITE_CLIP equ 0

; Callback after the configuration has been applied.  X = config_block_start, Y = config_game_start
CONFIG_APPLY_HOOK mac
;
             <<<

; Game-specific configuration values (none): CONFIG_GAME_DEFAULTS lays out their defaults at their IDs in
; the game's block (see rom/rom_config_setup.s, which also has the built-in values, menus and ApplyConfig)
CONFIG_GAME_DEFAULTS mac
;
             <<<

; Provide alternative ways of locking in the scroll and ppu control values after a frame
CUSTOM_PPU_CTRL_LOCK equ 0
CUSTOM_PPU_SCROLL_LOCK equ 0
CUSTOM_PPU_CTRL_LOCK_CODE mac
;
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
;
                          <<<

; Do we have a custom routine to execite RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 0
; (CUSTOM_RENDER_SCREEN_ADDR is in the engine fence below)

; ===========================================================================
; MAIN side: called from the event loop, the frame hooks and start-up
; ===========================================================================
            DO    SEG_MAIN
            mx    %00

zPalDirty   EXT                             ; (the engine side's, in the other segment)

; Palette management.  The palettes the game uses are described in ../palettes/, and
; pal_transitions.s (generated from them) gives each one a fixed IIgs slot layout and swizzle
; tables.  A palette RAM write (Z_PalWrite) only marks the palette dirty; at the next render,
; ApplyPaletteChange (GS task) identifies the palette in palette RAM and switches to it (redrawing
; tiles when needed), or shows the changed colors in the current palette's layout.
zCurPal     dw    0                         ; PAL_* id of the palette on screen (0 = none yet)

; Point the swizzle tables at the first palette until the game sets one.  InitPlayfield is called
; by NES_StartUp.
InitPlayfield
SetDefaultPalette
            ldx   PAL_SWIZZLE_LO+2
            lda   PAL_SWIZZLE_HI+2
            jmp   NES_SetPaletteMap

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to
; it, or show its changed colors in the current palette's layout
ApplyPaletteChange
            ldal  zPalDirty
            beq   :none
            ldal  _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            lda   #0
            stal  zPalDirty                 ; (first, so a write from here on is seen next time)
            ldx   zCurPal
            jsr   DetectNESPalette          ; A = Y = palette id, 0 if none
            beq   :colors                   ; not a known palette (e.g. a step of a fade)
            cmp   zCurPal
            beq   :colors
            ldx   zCurPal
            sty   zCurPal
            jmp   UpdatePalette             ; X = from, Y = to
:colors     ldy   zCurPal
            beq   :none
            jmp   LoadPaletteColors
:none       rts

            FIN
            mx    %00

; ===========================================================================
; ENGINE side: called from the renderer (per sprite, per render) and the PPU write shims
; ===========================================================================
            DO    SEG_ENGINE
            mx    %00

; Dispatch table for palette RAM writes: every entry goes to Z_PalWrite (palette management)
PPU_PALETTE_DISPATCH equ CONTRA_PALETTE_DISPATCH

zPalDirty   ENT                             ; palette RAM changed since the last render
            dw    0

; Palette RAM write ($3F00-$3F1F), on the NES task.  The palette RAM is already updated: just note
; that it changed.  Everything else happens at the next render (ApplyPaletteChange), so the colors
; change together with the tiles and the PPUMASK state they go with (a game typically loads a new
; palette while the screen is blank, or before the new screen's tiles are drawn).
Z_PalWrite
            lda   #1
            sta   zPalDirty
Z_PalNone   rts

CONTRA_PALETTE_DISPATCH
        dw   ppu_3F00,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   ppu_3F10,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite

            FIN
            mx    %00

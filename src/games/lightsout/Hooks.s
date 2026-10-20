; Lights Out -- game definition: the engine callbacks
;
; Every callback macro the engine expands, the flags that enable them, and the code and data behind
; them.  Main.s and Engine.s both put this file (after Config.s); a macro only produces code where the
; engine expands it.
;
; The code and data are in two fences, by the segment the engine calls them from:
;
;   DO SEG_MAIN    the event loop and frame hooks: PRE_EVT_LOOP, POST_EVT_LOOP, EVT_LOOP_BEGIN /
;                  END, PRE_RENDER, POST_RENDER, CONFIG_APPLY_HOOK, start-up (InitPlayfield)
;   DO SEG_ENGINE  the renderer and the PPU write shims: SPRITE_PRE_DRAW, CUSTOM_PPU_CTRL_LOCK_CODE,
;                  CUSTOM_PPU_SCROLL_LOCK_CODE, CUSTOM_RENDER_SCREEN_ADDR, PPU_PALETTE_DISPATCH
;
; Main.s sets SEG_MAIN and Engine.s SEG_ENGINE.  A macro calls the code in its own fence with jsr;
; anything in the other fence is in another bank: long addressing, "label ENT" at the definition and
; "label EXT" on the other side.  Each fence starts and ends with an explicit mx (Merlin32 tracks sep /
; rep even in a skipped DO block).
;
; Merlin32 ignores a put inside a put file, so the generated files are put by Main.s.

            mx    %00

; Define all of the macros that are used to callback into this
; code.  Defining an empty macro will result in no callback

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

; Before each render: pick up the palette changes
PRE_RENDER   mac
             jsr  ApplyPaletteChange ; switch to a new palette detected since the last frame
             <<<

POST_RENDER  mac
;
             <<<

; Callback before each sprite is set up and drawn (drawSprites, ppu.s): X = OAM index, ]1 = the
; sprite height (8 or 16), DBR = $01 (the shadow screen), 16-bit registers.  It can set sprClipTop to
; hide the sprite's top lines.
SPRITE_PRE_DRAW  mac
;
             <<<

; Non-zero if SPRITE_PRE_DRAW can set sprClipTop: the sprite renderer only tests it then
SPRITE_CLIP equ 0

; Callback after the configuration has been applied.  X = config_block_start, Y = config_game_start
CONFIG_APPLY_HOOK mac
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

; Game-specific configuration values (none): CONFIG_GAME_DEFAULTS lays out their defaults at their IDs in
; the game's block (see rom/rom_config_setup.s, which also has the built-in values, menus and ApplyConfig)
CONFIG_GAME_DEFAULTS mac
;
             <<<

; ===========================================================================
; MAIN side: called from the event loop, the frame hooks and start-up
; ===========================================================================
            DO    SEG_MAIN
            mx    %00

loPalDirty  EXT

; Palette management.  The game's single palette is described in palettes/, and pal_transitions.s
; (generated from them by build.js) gives each palette a fixed IIgs slot layout and swizzle tables.  A palette
; RAM write (LO_PalWrite) only marks the palette dirty; at the next render, ApplyPaletteChange (GS task)
; identifies the palette in palette RAM and switches to it (redrawing tiles when needed), or shows the
; changed colors in the current palette's layout.
loCurPal    dw    0                         ; PAL_* id of the palette on screen

; The ROM uploads its palette once, with its screen.  InitPlayfield is called by NES_StartUp.
InitPlayfield
SetDefaultPalette
            ldy   #PAL_GAME
            sty   loCurPal
            ldx   PAL_SWIZZLE_LO,y
            lda   PAL_SWIZZLE_HI,y
            jmp   NES_SetPaletteMap

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to it,
; or show its changed colors in the current palette's layout
ApplyPaletteChange
            ldal   loPalDirty
            beq   :none
            ldal   _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            lda   #0
            stal   loPalDirty                ; (first, so a write from here on is seen next time)
            ldx   loCurPal
            jsr   DetectNESPalette          ; A = Y = palette id, 0 if none
            beq   :colors                   ; not a known palette (e.g. at power-on)
            cmp   loCurPal
            beq   :colors
            ldx   loCurPal
            sty   loCurPal
            jmp   UpdatePalette             ; X = from, Y = to
:colors     ldy   loCurPal
            jmp   LoadPaletteColors
:none       rts

            FIN
            mx    %00

; ===========================================================================
; ENGINE side: called from the renderer (per sprite, per render) and the PPU write shims
; ===========================================================================
            DO    SEG_ENGINE
            mx    %00

; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ PALETTE_DISPATCH
loPalDirty ENT
            dw    0                         ; palette RAM changed since the last render

; Palette RAM write ($3F01-$3F1F, except the color 0s), on the NES task.  The palette RAM is already
; updated (and only changed values get here): just note that it changed.
LO_PalWrite
            lda   #1
            sta   loPalDirty
LO_PalNone  rts

; Color 0: $3F00 / $3F10 is always IIgs slot 0, so it is set straight away (ppu_palette.s); the
; other color 0s aren't shown.  The rest go to LO_PalWrite.
PALETTE_DISPATCH
        dw   ppu_3F00,LO_PalWrite,LO_PalWrite,LO_PalWrite
        dw   LO_PalNone,LO_PalWrite,LO_PalWrite,LO_PalWrite
        dw   LO_PalNone,LO_PalWrite,LO_PalWrite,LO_PalWrite
        dw   LO_PalNone,LO_PalWrite,LO_PalWrite,LO_PalWrite
        dw   ppu_3F10,LO_PalWrite,LO_PalWrite,LO_PalWrite
        dw   LO_PalNone,LO_PalWrite,LO_PalWrite,LO_PalWrite
        dw   LO_PalNone,LO_PalWrite,LO_PalWrite,LO_PalWrite
        dw   LO_PalNone,LO_PalWrite,LO_PalWrite,LO_PalWrite

            FIN
            mx    %00

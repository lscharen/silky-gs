; Excitebike -- the engine callbacks
;
; Every callback macro the engine expands and the flags that enable them: macros and constants only.
; Main.s and the engine segment (src/Engine.s, staged) both put this file; a macro only produces code
; where the engine expands it.  A macro calls the game's code in Main.s with jsl, and the routine
; returns with rtl; the data bank is the caller's, so the routine uses long addressing for the game's
; variables or sets the bank itself.  SPRITE_PRE_DRAW, which the engine expands for every sprite, may
; instead jsr to code in EngineExt.s, in the engine's bank.  A Main.s routine the engine calls is
; declared here ("label EXT") and defined there ("label ENT").

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
             jsl  ApplyPaletteChange ; switch to a new palette detected since the last frame
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

; Game has two scroll positions for split scroll
;
; ram_scroll_X / ram_scroll_Y plus ram_for_2000 | ram_004D_base_nametable ($12, $13))
; ram_0050_scroll_X / ram_0050_scroll_Y plus ram_for_2000 | ram_004E_base_nametable ($50, $51)
; sub_D1A9 - sets to 0,0
; sub_D3C1 - sets to 0,0
;
; Palette RAM writes: the engine's handlers (ppu/ppu_palette.s) mark the palette dirty for the code
; generated from palettes/, or write a [direct] cell straight to its slot.  A game with handlers of its own
; sets CUSTOM_PPU_PALETTE_DISPATCH equ 1 and PPU_PALETTE_DISPATCH equ its table, and defines the table
; (and the handlers) in EngineExt.s: the PPU write shim reads it with 16-bit addresses in the engine's bank.
CUSTOM_PPU_PALETTE_DISPATCH equ 0

; The PPU register values a render latches (RenderLatch), when they aren't simply the registers' last
; values: CUSTOM_PPU_CTRL_LOCK / CUSTOM_PPU_SCROLL_LOCK equ 1, and CUSTOM_PPU_CTRL_LOCK_ADDR /
; CUSTOM_PPU_SCROLL_LOCK_ADDR equ the routine in Main.s ("label EXT" here, "label ENT" there).  See
; ppu/ppu_api.s
CUSTOM_PPU_CTRL_LOCK equ 0
CUSTOM_PPU_SCROLL_LOCK equ 1
EB_ScrollLock EXT                         ; (Main.s)
CUSTOM_PPU_SCROLL_LOCK_ADDR equ EB_ScrollLock

; The game draws the race renders itself (the crowd, the track and the status bar at their own
; scroll positions); the engine draws the rest
CUSTOM_RENDER_SCREEN equ 1
EB_RenderScreen EXT                         ; (Main.s)
CUSTOM_RENDER_SCREEN_ADDR equ EB_RenderScreen

; Game-specific configuration values (none): CONFIG_GAME_DEFAULTS lays out their defaults at their IDs in
; the game's block (see rom/rom_config_setup.s, which also has the built-in values, menus and ApplyConfig)
CONFIG_GAME_DEFAULTS mac
;
             <<<

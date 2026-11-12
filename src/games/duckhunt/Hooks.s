; Duck Hunt -- the engine callbacks
;
; Every callback macro the engine expands and the flags that enable them: macros and constants only.
; Main.s and the engine segment (src/Engine.s, staged) both put this file; a macro only produces code
; where the engine expands it.  A macro calls the game's code in Main.s with jsl, and the routine
; returns with rtl; the data bank is the caller's, so the routine uses long addressing for the game's
; variables or sets the bank itself.  SPRITE_PRE_DRAW, which the engine expands for every sprite, may
; instead jsr to code in EngineExt.s, in the engine's bank.  A Main.s routine the engine calls is
; declared here ("label EXT") and defined there ("label ENT").

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

; Before each render: pick up the palette changes, and show the Zapper's pointer (the mouse; GAME menu:
; the cursor's size and strobe)
PRE_RENDER   mac
             jsl  ApplyPaletteChange ; switch to a new palette detected since the last frame
             DO   MOUSE_ZAPPER
             jsl  DH_ShowPointer
             FIN
             <<<

POST_RENDER  mac
;
             <<<

; Callback before each sprite is set up and drawn (drawSprites, ppu.s): X = OAM index, ]1 = the
; sprite height (8 or 16), DBR = $01 (the shadow screen), 16-bit registers.  It can set sprClipTop to
; hide the sprite's top lines.
;
; The pointer is drawn from pattern table 1 (EngineExt.s): DH_PointerTable for the pointer and for the
; sprite after it.  The game only draws 8x8 sprites.
SPRITE_PRE_DRAW  mac
             DO   16-]1
             txa
             cmpl dhPtrIdx            ; The pointer?
             beq  *+8
             ldal dhPtrTbl1           ; Or the sprite after it?
             beq  *+5
             jsr  DH_PointerTable
             FIN
             <<<

; Non-zero if SPRITE_PRE_DRAW can set sprClipTop: the sprite renderer only tests it then
SPRITE_CLIP equ 0

; Callback after the configuration has been applied.  X = config_block_start, Y = config_game_start.
; The game expects a controller in port 1 and the Zapper in port 2: player 1 is the keyboard, player 2
; the mouse (whatever the preferences file says).  Then the GAME menu's values (DH_ApplyConfig, Main.s).
CONFIG_APPLY_HOOK mac
             DO   MOUSE_ZAPPER
             lda  #0                  ; KEYBOARD
             stal config_input_p1_type
             lda  #INPUT_MOUSE
             stal config_input_p2_type
             jsl  DH_ApplyConfig
             FIN
             <<<

; Game-specific configuration values (the GAME menu, Main.s).  Each has an ID, its byte offset in the
; game's block, and CONFIG_GAME_DEFAULTS lays out the defaults at those offsets (see
; rom/rom_config_setup.s, which also has the built-in values, menus and ApplyConfig).  Add new values after
; the last one.  0 is each one's default, as in a preferences file from before it existed.
CFG_GAME_CURSOR equ 0                   ; (word) the pointer: 0 = LARGE, 1 = SMALL
CFG_GAME_JITTER equ 2                   ; (word) 0 - 3: the bits of the video counter the shot moves by
CFG_GAME_STROBE equ 4                   ; (word) the frames of each second the still pointer is hidden:
                                        ; 0, 15, 30, 45, 60 (0 - 100%)

CONFIG_GAME_DEFAULTS mac
             dw   0                     ; CFG_GAME_CURSOR: LARGE
             dw   0                     ; CFG_GAME_JITTER
             dw   0                     ; CFG_GAME_STROBE
             <<<

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
CUSTOM_PPU_SCROLL_LOCK equ 0

; The game draws (some) renders itself: CUSTOM_RENDER_SCREEN equ 1, and CUSTOM_RENDER_SCREEN_ADDR equ the
; routine in Main.s ("label EXT" here, "label ENT" there).  See ppu/ppu_api.s
CUSTOM_RENDER_SCREEN equ 0

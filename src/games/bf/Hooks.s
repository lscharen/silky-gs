; Balloon Fight -- game definition: the engine callbacks
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

; Pre-render check to see if there are any background tiles queued for updates.  If so, we will do
; a regular rendering.  If not, use dirty rendering.
PRE_RENDER   mac
;
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
             jsr   BF_ApplyConfig
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

; Do we have a custom routine to execute RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 1

; Game-specific configuration values.  Each has an ID, its byte offset in the game's block, and
; CONFIG_GAME_DEFAULTS lays out the defaults at those offsets (see rom/rom_config_setup.s, which also has
; the built-in values, menus and ApplyConfig).  Add new values after the last one.
CFG_GAME_TWINKLE equ 0                  ; (word) animate the background stars

CONFIG_GAME_DEFAULTS mac
             dw   1                     ; CFG_GAME_TWINKLE
             <<<

; ===========================================================================
; MAIN side: called from the event loop, the frame hooks and start-up
; ===========================================================================
            DO    SEG_MAIN
            mx    %00

; Helper to initialize the playfield based on the selected VideoMode
InitPlayfield

; Set a default palette for the title screen

            ldx   #TitleScreen
            lda   #0
            jsr   NES_SetPalette

            rts

; For this game, we utilize multiple palettes to conserve palette colors and reserve colors for the sprites
SetDefaultPalette

; Set the tile/sprite mapping

            lda   SwizzleTables+2
            ldx   SwizzleTables
            jsr   NES_SetPaletteMap

; Set the SCB ranges

            ldx   #0
            lda   #$0000
:scb1       stal  $E19D00,x
            inx
            inx
            cpx   #16
            bcc   :scb1

            lda   #$0202
:scb2       stal  $E19D00,x
            inx
            inx
            cpx   #192
            bcc   :scb2

            lda   #$0101
:scb3       stal  $E19D00,x
            inx
            inx
            cpx   #200
            bcc   :scb3

            rts

SwizzleTables adrl L1_T0

; Palettes of NES color indexes
TitleScreen  dw    $0F, $30, $27, $2A, $15, $02, $21, $00, $10, $16, $12, $37, $21, $17, $11, $2B
LevelHeader1 dw    $0F, $2A, $09, $07, $30, $27, $16, $11, $21, $00, $10, $12, $37, $17, $35, $2B

GAME_TITLE_STR      str 'GAME'
GAME_NO_ANIM_STR    str 'STAR ANIM'

GAME_CONFIG  dw   GAME_TITLE_STR
             dw   DRIVERS_CONFIG        ; previous menu item
             dw   CREDITS_CONFIG        ; next menu item

             dw   1
             dw   GAME_ITEM_1

GAME_ITEM_1  dw   CHKBOX
             dw   0
             dw   0
             dw   3,2
             dw   GAME_NO_ANIM_STR
             dw   config_game_start+CFG_GAME_TWINKLE

; Apply the game-specific settings (CONFIG_APPLY_HOOK)
;
; Y = config_game_start
star_patch EXT
BF_ApplyConfig
            ldx:  CFG_GAME_TWINKLE,y   ; read while Y is still 16-bit
            sep   #$30
            lda   #$80          ; BRA instruction (skip the star animation)
            cpx   #0
            beq   :turn_off
            lda   #$F0          ; BEQ instruction
:turn_off   stal  star_patch
            rep   #$30
            rts

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
PPU_PALETTE_DISPATCH equ BF_PALETTE_DISPATCH
CUSTOM_RENDER_SCREEN_ADDR equ _RenderScreen

; When the NES ROM code tried to write to the PPU palette space, intercept here.
BF_PALETTE_DISPATCH
        dw   BF_3F00,BF_3F01,BF_3F02,BF_3F03
        dw   ppu_3F04,BF_3F05,BF_3F06,BF_3F07
        dw   ppu_3F08,BF_3F09,BF_3F0A,BF_3F0B
        dw   ppu_3F0C,BF_3F0D,BF_3F0E,BF_3F0F

        dw   BF_3F10,BF_3F11,BF_3F12,BF_3F13
        dw   ppu_3F14,ppu_3F15,ppu_3F16,ppu_3F17
        dw   ppu_3F18,BF_3F19,BF_3F1A,BF_3F1B
        dw   ppu_3F1C,BF_3F1D,BF_3F1E,BF_3F1F

; Background color (A = the NES color), in all three IIgs palettes.  $3F00 and $3F10 are the
; same entry, so store it in both (see ppu_palette.s)
BF_3F00
BF_3F10 sep  #$20
        stal PPU_MEM+$3F00
        stal PPU_MEM+$3F10
        rep  #$20
        jsr  NES_ColorToIIgs
        stal $E19E00
        stal $E19E20
        stal $E19E40
        rts

; Tile palette 1, color 1
BF_3F01 ldal PPU_MEM+$3F01
        jsr  NES_ColorToIIgs
;        stal $E19E02
        stal $E19E22
        stal $E19E42
        rts

; Tile palette 1, color 2
BF_3F02 ldal PPU_MEM+$3F02
        jsr  NES_ColorToIIgs
;        stal $E19E04
        stal $E19E24
        stal $E19E44
        rts

; Tile palette 1, color 3
BF_3F03 ldal PPU_MEM+$3F03
        jsr  NES_ColorToIIgs
;        stal $E19E06
        stal $E19E26
        stal $E19E46
        rts

; Tile palette 2, color 1
BF_3F05 ldal PPU_MEM+$3F05
        jsr  NES_ColorToIIgs
        stal $E19E08
        stal $E19E02
        rts

; Tile palette 2, color 2
BF_3F06 ldal PPU_MEM+$3F06
        jsr  NES_ColorToIIgs
        stal $E19E0A
        stal $E19E04
        rts

; Tile palette 2, color 3
BF_3F07 ldal PPU_MEM+$3F07
        jsr  NES_ColorToIIgs
        stal $E19E0C
        stal $E19E06
        rts

; Tile palette 3, color 1
BF_3F09 ldal PPU_MEM+$3F09
        jsr  NES_ColorToIIgs
        stal $E19E28
        rts

; Tile palette 3, color 2
BF_3F0A ldal PPU_MEM+$3F0A
        jsr  NES_ColorToIIgs
        stal $E19E2A
        rts

; Tile palette 3, color 3
BF_3F0B ldal PPU_MEM+$3F0B
        jsr  NES_ColorToIIgs
        stal $E19E2C
        rts

; Tile palette 4, color 1
BF_3F0D ldal PPU_MEM+$3F0D
        jsr  NES_ColorToIIgs
        stal $E19E48
        rts

; Tile palette 4, color 2
BF_3F0E ldal PPU_MEM+$3F0E
        jsr  NES_ColorToIIgs
        stal $E19E4A
        rts

; Tile palette 4, color 3
BF_3F0F ldal PPU_MEM+$3F0F
        jsr  NES_ColorToIIgs
        stal $E19E4C
        rts

; Sprite palette 1, color 1
BF_3F11 ldal PPU_MEM+$3F11
        jsr  NES_ColorToIIgs
        stal $E19E0E
        stal $E19E2E
        stal $E19E4E
        rts

; Sprite palette 1, color 2
BF_3F12 ldal PPU_MEM+$3F12
        jsr  NES_ColorToIIgs
        stal $E19E10
        stal $E19E30
        stal $E19E50
        rts

; Sprite palette 1, color 3
BF_3F13 ldal PPU_MEM+$3F13
        jsr  NES_ColorToIIgs
        stal $E19E12
        stal $E19E32
        stal $E19E52
        rts

; Sprite palette 2 is mapped to palette 1 colors

; Sprite palette 3, color 1
BF_3F19 ldal PPU_MEM+$3F19
        jsr  NES_ColorToIIgs
        stal $E19E14
        stal $E19E34
        stal $E19E54
        rts

; Sprite palette 3, color 2
BF_3F1A ldal PPU_MEM+$3F1A
        jsr  NES_ColorToIIgs
        stal $E19E16
        stal $E19E36
        stal $E19E56
        rts

; Sprite palette 3, color 3
BF_3F1B ldal PPU_MEM+$3F1B
        jsr  NES_ColorToIIgs
        stal $E19E18
        stal $E19E38
        stal $E19E58
        rts

; Sprite palette 4, color 1
BF_3F1D ldal PPU_MEM+$3F1D
        jsr  NES_ColorToIIgs
        stal $E19E1A
        stal $E19E3A
        stal $E19E5A
        rts

; Sprite palette 4, color 2
BF_3F1E ldal PPU_MEM+$3F1E
        jsr  NES_ColorToIIgs
        stal $E19E1C
        stal $E19E3C
        stal $E19E5C
        rts

; Sprite palette 4, color 3
BF_3F1F ldal PPU_MEM+$3F1F
        jsr  NES_ColorToIIgs
        stal $E19E1E
        stal $E19E3E
        stal $E19E5E
        rts

; Make the screen appear
_RenderScreen

; If we're not on Balloon Trip, jut use the default render function

            ldal  DP_NES                  ; (scaffold.s, in MAIN)

            tax
            ldal  $000016,x
            and   #$00FF           ; Balloon Trip mode; $16 = !0
            bne   :trip_renderer
            jmp   RenderScreen

; Otherwise turn off dirty rendering and do the split-screen rendering
; like Super Mario
:trip_renderer
            lda   _ppuctrl
            ldx   _ppuscroll_x
            ldy   _ppuscroll_y
            jsr   NES_SetScroll

; Now render the top 16 lines to show the status bar area

            lda   #0
            ldx   #16
            ldy   #0                      ; Xmod256 = 0
            jsr   _BltSetupAlt

; Next render the remaining lines

            lda   ScreenHeight
            sec
            sbc   #16
            tax                       ; The rest of the screen is height - 16
            lda   #16                 ; Start at line 16
            ldy   StartX
            jsr   _BltSetupAlt

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen

; drawScreen's drawSprites marked this frame's sprite cells and records for the grid renderer.  As in
; the default RenderScreen full-render path, close the frame out so those per-frame lists are reset;
; without this, every Balloon Trip frame appended to them until they overran into the code that
; follows (OAM_COPY, shadowBitmap0/1 and scanOAMSprites) and crashed.

            DO    ENABLE_DIRTY_RENDERING
            jsr   gridEndFull
            FIN

            stz   DirtyBits
            rts

            FIN
            mx    %00

; Super Mario Bros. -- game definition: the engine callbacks
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

EVT_LOOP_END mac
;
             <<<

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
CUSTOM_PPU_CTRL_LOCK equ 1
CUSTOM_PPU_SCROLL_LOCK equ 1

;Mirror_PPU_CTRL_REG1  = $0778
;HorizontalScroll      = $073f
;VerticalScroll        = $0740
CUSTOM_PPU_CTRL_LOCK_CODE mac
                          ldal ROMBase+$0778
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
                          ldal ROMBase+$073f
                          xba
                          <<<

; Do we have a custom routine to execute RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 1

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

smbPalDirty EXT

Greyscale   dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF

; Program variables

show_vbl_cpu      dw  0
user_break        dw  0

; Helper to initialize the playfield based on the selected VideoMode
InitPlayfield
            lda   #16            ; We render starting at line 16 in the NES video buffer
            sta   NesTop

            lda   #200
            sta   ScreenHeight
            lsr
            lsr
            lsr
            sta   ScreenRows

            lda   NesTop
            clc
            adc   ScreenHeight
            sec
            sbc   #8
            inc
            sta   NesBottom

; Initialize the graphics screen playfield

            ldx   #128
            ldy   ScreenHeight
            jsr   _SetScreenMode                 ; This is also called in the Init

; Start with the title screen's (ground) palette

            jmp   SetDefaultPalette

; Palette management.  The palettes the game shows (ground, snow, mushroom, underground, water, castle and
; castle with Bowser's colors) are described in palettes/, and pal_transitions.s (generated from them by
; build.js) gives each one a fixed IIgs slot layout and swizzle tables.  A palette RAM write (SMB_PalWrite)
; only marks the palette dirty; at the next render, ApplyPaletteChange (GS task) identifies the palette in
; palette RAM and switches to it (redrawing tiles when needed), or shows the changed colors in the current
; palette's layout (the question block color cycling and the player colors are reserved cells).
smbCurPal   dw    0                         ; PAL_* id of the palette on screen

; Start with the ground palette (the title screen), so its layout is used until the game's palette is
; detected.  Called by InitPlayfield (NES_StartUp) and at start-up.
SetDefaultPalette
            ldy   #PAL_GROUND
            sty   smbCurPal
            ldx   PAL_SWIZZLE_LO,y
            lda   PAL_SWIZZLE_HI,y
            jmp   NES_SetPaletteMap

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to it,
; or show its changed colors in the current palette's layout
ApplyPaletteChange
            ldal   smbPalDirty
            beq   :none
            ldal   _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            lda   #0
            stal   smbPalDirty               ; (first, so a write from here on is seen next time)
            ldx   smbCurPal
            jsr   DetectNESPalette          ; A = Y = palette id, 0 if none
            beq   :colors                   ; not a known palette
            cmp   smbCurPal
            beq   :colors
            ldx   smbCurPal
            sty   smbCurPal
            jmp   UpdatePalette             ; X = from, Y = to
:colors     ldy   smbCurPal
            jmp   LoadPaletteColors
:none       rts

; Copy just the tiles that change directly to the graphics screen

MemOffsets    dw    67, 68, 69, 70, 71,                        82, 83, 84, 85, 86,  89, 90, 91, 92
              dw    99,100,101,102,103,104,  107,108,109,110,     115,116,117,         122,123,124

ScreenOffsets dw    12, 16, 20, 24, 28,                        72, 76, 80, 84, 88,  100,104,108,112
              dw    ROW_STEP+12,ROW_STEP+16,ROW_STEP+20,ROW_STEP+24,ROW_STEP+28,ROW_STEP+32
              dw    ROW_STEP+44,ROW_STEP+48,ROW_STEP+52,ROW_STEP+56
              dw    ROW_STEP+76,ROW_STEP+80,ROW_STEP+84
              dw    ROW_STEP+104,ROW_STEP+108,ROW_STEP+112

CopyStatusToScreen

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
PPU_PALETTE_DISPATCH equ SMB_PALETTE_DISPATCH
CUSTOM_RENDER_SCREEN_ADDR equ _RenderScreen

; Make the screen appear
_RenderScreen

; Do the basic setup
            jsr   _ShowDebugInfo

            lda   _ppuctrl
            ldx   _ppuscroll_x
            ldy   #0                      ; We _never_ scroll vertically
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

            DO    SHOW_DEBUG_VARS
            lda   LastRead                ; The keyboard input (_ShowDebugInfo has the rest)
            ldx   #32*160
            ldy   #$FFFF
            jsl   DrawWordL
            FIN

            stz   DirtyBits
            rts
smbPalDirty ENT
            dw    0                         ; palette RAM changed since the last render

; Palette RAM write ($3F01-$3F1F, except the color 0s), on the NES task.  The palette RAM is already
; updated (and only changed values get here): just note that it changed.
SMB_PalWrite
            lda   #1
            sta   smbPalDirty
SMB_PalNone rts

; Color 0: $3F00 / $3F10 is always IIgs slot 0, so it is set straight away (ppu_palette.s); the
; other color 0s aren't shown.  The question block color and the player colors are pinned to one slot in
; every palette (the [fixed] section in palettes/transitions.txt), so they are also set straight away.
; The rest go to SMB_PalWrite.
SMB_PALETTE_DISPATCH
        dw   ppu_3F00,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_3F0D,SMB_PalWrite,SMB_PalWrite
        dw   ppu_3F10,SMB_3F11,SMB_PalWrite,SMB_3F13
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite
        dw   SMB_PalNone,SMB_PalWrite,SMB_PalWrite,SMB_PalWrite

; The pinned colors, written straight to their IIgs palette slots (PAL_SLOT_*, pal_transitions.s).  A =
; the NES color.  They are reserved cells, so palette detection doesn't depend on them either.
SMB_3F0D    jsr  NES_ColorToIIgs            ; BG3:1, the question block color (ColorRotation)
            stal SHR_PALETTES+{2*PAL_SLOT_BG3_1}
            rts

SMB_3F11    jsr  NES_ColorToIIgs            ; SP0:1, player color (GetPlayerColors)
            stal SHR_PALETTES+{2*PAL_SLOT_SP0_1}
            rts

SMB_3F13    jsr  NES_ColorToIIgs            ; SP0:3, player color (GetPlayerColors)
            stal SHR_PALETTES+{2*PAL_SLOT_SP0_3}
            rts

            FIN
            mx    %00

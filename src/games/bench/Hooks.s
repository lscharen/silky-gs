; Engine benchmark -- game definition: the engine callbacks
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


; Engine benchmark.  A World 1-1 style level (two nametables, vertical mirroring) scrolls to the left
; under four walking figures: big Mario, Bowser, a Koopa Troopa and a Goomba.  There is no game logic:
; the NES program (bench_rom.s) only sets up the screen and plays the music from its NMI handler.
; Each render scrolls the screen by one IIgs byte (2 NES pixels) and steps the walk animation every
; BENCH_ANIM_RENDERS renders (BenchStep), so the speed of the scrolling is the speed of the engine.
; Turn on VIDEO > SHOW FPS in the configuration screen (?) to see the renders per second.
;
; The keys 1 - 3 pick the height of the playfield (BenchKey): 1 = 256x200, 2 = 256x176, 3 = 256x160.
; The playfield is shortened from the top, so the ground and the figures stay where they are.  Picking
; a size clears the screen and restarts the scrolling and the animation.

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
; user-code a change to implement custom key commands.  A = the key code.
EVT_LOOP_END mac
             jsr  BenchKey
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
             jsr  BenchSetSCBs            ; (the configuration screen sets every SCB to 0)
             <<<

; Provide alternative ways of locking in the scroll and ppu control values after a frame.  The bench
; doesn't write the scroll registers: BenchStep moves the screen on by one step for each render, when
; the render latches the registers.
CUSTOM_PPU_CTRL_LOCK equ 1
CUSTOM_PPU_SCROLL_LOCK equ 1
CUSTOM_PPU_CTRL_LOCK_CODE mac
                          jsr  BenchStep
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
                          lda  benchScroll
                          <<<

; Do we have a custom routine to execite RenderScreen.  If yes, put its address here
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

benchScrollX EXT
benchScroll EXT
benchAnimTimer EXT
benchAnimOfs EXT
benchPalDirty EXT
            ERR   BENCH_SPRITES-OAM_END_INDEX   ; OAM_END_INDEX must be the number of sprites
benchTop ENT
                dw  0                     ; first screen line of the playfield (200 - its height)
benchLines ENT
                dw  200                   ; height of the playfield

; The playfield sizes of the keys 1 - 3: the first screen line and the number of lines.  The first line
; must be even (FAST BLIT draws every other line).
BenchSizeTop    dw  0,24,40
BenchSizeLines  dw  200,176,160

; Copy the figures' OAM entries into the NES OAM buffer (DIRECT_OAM_READ).  The positions never change.
; Also (re)starts the scrolling and the animation.
            mx    %00
BenchInit
            lda   #0

            stal   benchScrollX
            lda   #0

            stal   benchScroll
            lda   #0

            stal   benchAnimOfs
            lda   #BENCH_ANIM_RENDERS
            stal   benchAnimTimer
            ldx   #0
:loop       lda   BenchOAMInit,x
            stal  ROMBase+DIRECT_OAM_READ,x
            inx
            inx
            cpx   #BENCH_SPRITES*4
            bcc   :loop
            rts

; EVT_LOOP_END, on the GS task (between renders): the keys 1 - 3 pick the playfield size.  Clear the
; screen, give the lines above the playfield the black palette and restart the demo.  A = the key code.
            mx    %00
BenchKey
            and   #$007F
            sec
            sbc   #'1'
            cmp   #3
            bcs   :out
            asl
            tax
            lda   BenchSizeTop,x
            sta   benchTop
            lda   BenchSizeLines,x
            sta   benchLines
            jsr   _ClearShadowScreen        ; both the shadow screen and the SHR screen
            jsr   BenchSetSCBs
            jmp   BenchInit
:out        rts

; The SCBs: the lines above the playfield use palette 1, black with a white color 15 (the FPS digits),
; and the playfield uses palette 0
            mx    %00
BenchSetSCBs
            ldx   #30
            lda   #$0FFF
:pal        stal  SHR_PALETTES+32,x
            lda   #$0000
            dex
            dex
            bpl   :pal

            ldx   #0
            sep   #$20
:scb        lda   #$01
            cpx   benchTop
            bcc   *+4
            lda   #$00
            stal  SHR_SCB,x
            inx
            cpx   #200
            bcc   :scb
            rep   #$20
            rts

; Palette management.  The bench's single palette is described in palettes/, and pal_transitions.s
; (generated from them by build.js) gives each palette a fixed IIgs slot layout and swizzle tables.  A palette
; RAM write (Bench_PalWrite) only marks the palette dirty; at the next render, ApplyPaletteChange (GS task)
; identifies the palette in palette RAM and switches to it (redrawing tiles when needed), or shows the
; changed colors in the current palette's layout.
benchCurPal   dw  0                         ; PAL_* id of the palette on screen

; The ROM uploads its palette once, with its screen.  InitPlayfield is called by NES_StartUp.
InitPlayfield
SetDefaultPalette
            ldy   #PAL_GROUND
            sty   benchCurPal
            ldx   PAL_SWIZZLE_LO,y
            lda   PAL_SWIZZLE_HI,y
            jmp   NES_SetPaletteMap

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to it,
; or show its changed colors in the current palette's layout
ApplyPaletteChange
            ldal   benchPalDirty
            beq   :none
            ldal   _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            lda   #0

            stal   benchPalDirty             ; (first, so a write from here on is seen next time)
            ldx   benchCurPal
            jsr   DetectNESPalette          ; A = Y = palette id, 0 if none
            beq   :colors                   ; not a known palette (e.g. at power-on)
            cmp   benchCurPal
            beq   :colors
            ldx   benchCurPal
            sty   benchCurPal
            jmp   UpdatePalette             ; X = from, Y = to
:colors     ldy   benchCurPal
            jmp   LoadPaletteColors
:none       rts

            FIN
            mx    %00

; ===========================================================================
; ENGINE side: called from the renderer (per sprite, per render) and the PPU write shims
; ===========================================================================
            DO    SEG_ENGINE
            mx    %00

benchTop    EXT
benchLines  EXT


; Dispatch table to handle palette changes. The ppu_<addr> functions are the default
; runtime behaviors.  Currently, only ppu_3F00 and ppu_3F10 do anything, which is to
; set the background color.
PPU_PALETTE_DISPATCH equ PALETTE_DISPATCH
CUSTOM_RENDER_SCREEN_ADDR equ BenchRenderScreen   ; draws only the playfield lines of the selected size

benchScrollX ENT
                dw  0                     ; horizontal scroll position, 0 - 511
benchScroll ENT
                dw  0                     ; the scroll for the render: X in the high byte, Y (0) in the low byte
benchAnimTimer ENT
                dw  BENCH_ANIM_RENDERS    ; renders left until the next animation step
benchAnimOfs ENT
                dw  0                     ; offset of the current step in BenchOAMAnim

; CUSTOM_PPU_CTRL_LOCK_CODE: called by NES_RenderFrame for each render, before the scroll is latched and
; the OAM is scanned (interrupts off, DBR = this bank).  Scroll one step to the left and, every
; BENCH_ANIM_RENDERS renders, write the tile and attribute bytes of the next animation step into the
; OAM buffer.  Returns A = the PPUCTRL value for the render, with the nametable of the scroll position.
            mx    %00
BenchStep
            dec   benchAnimTimer
            bne   :scroll
            jsr   BenchAnimate

:scroll     lda   benchScrollX
            clc
            adc   #BENCH_SCROLL_STEP
            and   #$01FF
            sta   benchScrollX
            xba                           ; X & $FF in the high byte, the nametable bit in the low byte
            tax
            and   #$FF00
            sta   benchScroll
            txa
            and   #$0001
            ora   #BENCH_PPUCTRL
            rts

; The next step of the walk animation: only the tile and attribute bytes of the OAM entries change
            mx    %00
BenchAnimate
            lda   #BENCH_ANIM_RENDERS
            sta   benchAnimTimer

            lda   benchAnimOfs
            clc
            adc   #BENCH_SPRITES*2
            cmp   #BENCH_SPRITES*2*BENCH_ANIM_STEPS
            bcc   *+5
            lda   #0
            sta   benchAnimOfs
            tax
]n          =     0
            lup   OAM_END_INDEX
            lda   BenchOAMAnim+{]n*2},x
            stal  ROMBase+DIRECT_OAM_READ+1+{]n*4}    ; tile and attributes
]n          =     ]n+1
            --^
            rts

; CUSTOM_RENDER_SCREEN: a full render of the playfield lines only (drawScreenRange).  The lines above it
; are never drawn, so they stay as BenchKey cleared them.
            mx    %00
BenchRenderScreen
            lda   _ppuctrl
            ldx   _ppuscroll_x
            ldy   _ppuscroll_y
            jsr   NES_SetScroll
            ldal  benchLines              ; (MAIN: BenchKey sets the size)
            tax
            ldal  benchTop
            jsr   drawScreenRange
            stz   DirtyBits
            rts
benchPalDirty ENT
              dw  0                         ; palette RAM changed since the last render

; Palette RAM write ($3F01-$3F1F, except the color 0s), on the NES task.  The palette RAM is already
; updated (and only changed values get here): just note that it changed.
Bench_PalWrite
            lda   #1
            sta   benchPalDirty
Bench_PalNone rts

; Color 0: $3F00 / $3F10 is always IIgs slot 0, so it is set straight away (ppu_palette.s); the
; other color 0s aren't shown.  The rest go to Bench_PalWrite.
PALETTE_DISPATCH
        dw   ppu_3F00,Bench_PalWrite,Bench_PalWrite,Bench_PalWrite
        dw   Bench_PalNone,Bench_PalWrite,Bench_PalWrite,Bench_PalWrite
        dw   Bench_PalNone,Bench_PalWrite,Bench_PalWrite,Bench_PalWrite
        dw   Bench_PalNone,Bench_PalWrite,Bench_PalWrite,Bench_PalWrite
        dw   ppu_3F10,Bench_PalWrite,Bench_PalWrite,Bench_PalWrite
        dw   Bench_PalNone,Bench_PalWrite,Bench_PalWrite,Bench_PalWrite
        dw   Bench_PalNone,Bench_PalWrite,Bench_PalWrite,Bench_PalWrite
        dw   Bench_PalNone,Bench_PalWrite,Bench_PalWrite,Bench_PalWrite

            FIN
            mx    %00

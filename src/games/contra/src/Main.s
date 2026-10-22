            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   ../../../Externals.s
            put   ../../../core/Defs.s
            put   ../../../ImportEngine.s     ; The engine is in its own segment (Engine.s)

; This segment assembles the main side of Hooks.s; the engine side is in Engine.s
SEG_MAIN    equ   1
SEG_ENGINE  equ   0

; The game's configuration (constants) and its callbacks (Hooks.s, put after the entry code)
            put   Config.s
            put   pal_defs.s                  ; Palette ids (generated from palettes/)

            mx    %00

            phk
            plb

            tax
            lda   #VERTICAL_MIRRORING
            jsr   NES_StartUp

            jsr   SetDefaultPalette
            jsr   NES_ColdBoot

:start
            jsr   NES_EvtLoop

            cmp   #USER_SAYS_QUIT
            beq   quit

            cmp   #USER_SAYS_RESET
            bne   quit

            jsr   NES_WarmBoot
            bra   :start

quit
            jsr   NES_ShutDown

            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

; Two unique samples.  $4012 $F0 is NES $FC00, $F3 is $FCC0.
DMC_SAMPLE_LIST
            db    2
            db    $F0,$05,$0F
            db    $F3,$25,$0F

WRAM_FILENAME strl '1/contra.wram'
SAVE_FILENAME strl '1/contra.sav'
PREF_FILENAME strl '1/contra.prefs'

; The engine callbacks: the macros, and their code and data
            put   Hooks.s

; The palette management generated from ../palettes/ (ApplyPaletteChange; Merlin32 only reads puts
; from the segment source itself, so it is not put by Hooks.s)
            put   pal_transitions.s

            put   ../../../misc/App.Msg.s
            put   ../../../apu/apu.s

; Core code (the engine -- the ppu/ files, the blitter, the tile and sprite compilers -- is in Engine.s)
            put   ../../../rom/scaffold.s
            put   ../../../rom/rom_color.s        ; (also in Engine.s: for the palette code here)
            put   ../../../rom/rom_helpers.s
            put   ../../../rom/rom_input.s
            put   ../../../rom/rom_kbd_basic.s
            put   ../../../rom/rom_kbd_j13.s
            put   ../../../rom/rom_exec.s
            put   ../../../rom/rom_config.s
            put   ../../../rom/rom_config_setup.s

            put   ../../../core/ControlBits.s
            put   ../../../core/CoreImpl.s
            put   ../../../core/Graphics.s
            put   ../../../core/Math.s
            put   ../../../core/Memory.s

; GS/OS file load / save (battery-backed WRAM, see HAS_BACKED_WRAM)
            put   ../../../misc/io.s

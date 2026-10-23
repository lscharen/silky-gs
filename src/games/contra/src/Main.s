; The runtime's declarations (the build expands the list: src/runtime/head.txt)
; mput ../../../runtime/head.txt
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            REL
            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s
            put    ../../../Externals.s
            put    ../../../core/Defs.s
            put    ../../../ImportEngine.s
; AUTOINC:END

; The game's configuration (constants) and its callbacks (Hooks.s, macros only: put after the entry code)
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

; The engine callbacks (the macros; the code they call is below, and the engine side's in EngineExt.s)
            put   Hooks.s

; ===========================================================================
; The game's code: start-up, the event loop and frame hooks
; ===========================================================================
            mx    %00

DrawBarriersL EXT                           ; (the engine side's)

; Start-up (NES_StartUp).  The palettes are managed by the code generated from palettes/
; (pal_transitions.s): SetDefaultPalette, and ApplyPaletteChange, the PRE_RENDER hook.
InitPlayfield
            jmp   SetDefaultPalette

; PRE_RENDER: the electric barriers, in levels 2 and 4 only (DrawBarriersL, in EngineExt.s)
CURRENT_LEVEL_ZP equ $30                    ; (equates.inc: CURRENT_LEVEL, 0 = level 1)
DrawBarriers
            ldal  DP_NES                    ; The NES zero page
            tax
            ldal  $000000+CURRENT_LEVEL_ZP,x
            and   #$00FD                    ; Levels 2 and 4 (1 and 3) -> 1
            cmp   #$0001
            bne   :none
            jsl   DrawBarriersL
:none       rtl

            mx    %00

; The palette management generated from ../palettes/ (ApplyPaletteChange; Merlin32 only reads puts
; from the segment source itself, so it is not put by Hooks.s)
            put   pal_transitions.s

; The runtime's code (the build expands the list: src/runtime/code.txt)
            mput  ../../../runtime/code.txt
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            put    ../../../misc/App.Msg.s
            put    ../../../misc/io.s
            put    ../../../apu/apu.s
            put    ../../../rom/scaffold.s
            put    ../../../rom/rom_color.s
            put    ../../../rom/rom_helpers.s
            put    ../../../rom/rom_input.s
            put    ../../../rom/rom_kbd_basic.s
            put    ../../../rom/rom_kbd_j13.s
            put    ../../../rom/rom_kbd_adb.s
            put    ../../../rom/rom_exec.s
            put    ../../../rom/rom_config.s
            put    ../../../rom/rom_config_setup.s
            put    ../../../core/ControlBits.s
            put    ../../../core/CoreImpl.s
            put    ../../../core/Graphics.s
            put    ../../../core/Math.s
            put    ../../../core/Memory.s
; AUTOINC:END

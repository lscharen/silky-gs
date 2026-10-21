            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   ../../Externals.s
            put   ../../core/Defs.s
            put   ../../ImportEngine.s        ; The engine is in its own segment (Engine.s)

; This segment assembles the main side of Hooks.s; the engine side is in Engine.s
SEG_MAIN    equ   1
SEG_ENGINE  equ   0

; The game's configuration (constants) and its callbacks (Hooks.s, put after the entry code)
            put   Config.s
            put   pal_defs.s                  ; Palette ids (generated from palettes/)

            mx    %00

            phk
            plb

; Call startup immediately after entering the application with the cartridge configuration

            tax                           ; X = memory manager user ID (passed in A by GS/OS)
            lda   #HORIZONTAL_MIRRORING    ; A = cartridge nametable mirroring at power on
            jsr   NES_StartUp

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Call the boot code in the ROM

            jsr   NES_ColdBoot

; Start up the NES
:start
            jsr   NES_EvtLoop

            cmp   #USER_SAYS_QUIT
            beq   quit

            cmp   #USER_SAYS_RESET
            bne   quit

            jsr   NES_WarmBoot
            bra   :start

; The user has exited the runtime
quit
            jsr   NES_ShutDown

; Exit the application

        _QuitGS    qtRec
qtRec   adrl  $0000
        da    $00

; Name of the save and preference files
SAVE_FILENAME strl '1/mb.sav'
PREF_FILENAME strl '1/mb.prefs'

; The engine callbacks: the macros, and the main side's code and data
            put   Hooks.s

; The palette management generated from palettes/ (ApplyPaletteChange)
            put   pal_transitions.s

            put   ../../misc/App.Msg.s         ; Text (DrawByte / DrawWord): VIDEO > SHOW FPS and the debug displays
            put   ../../misc/io.s
            

            put   ../../apu/apu.s

; Core code
            put   ../../rom/scaffold.s
            put   ../../rom/rom_color.s        ; (also in Engine.s: for the palette code here)
            put   ../../rom/rom_helpers.s
            put   ../../rom/rom_input.s
            put   ../../rom/rom_kbd_j13.s
            put   ../../rom/rom_exec.s
            put   ../../rom/rom_config.s
            put   ../../rom/rom_config_setup.s

            put   ../../core/ControlBits.s
            put   ../../core/CoreImpl.s
            put   ../../core/Graphics.s
            put   ../../core/Math.s
            put   ../../core/Memory.s

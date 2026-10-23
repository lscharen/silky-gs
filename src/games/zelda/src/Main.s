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
qtRec       adrl  $0000
            da    $00

; DMC samples decoded at start-up: count, then $4012 address, $4013 length, $4010 rate for each
; (from SampleAddrs / SampleLengths / SampleRates in rom_00.s)
DMC_SAMPLE_LIST
            db    7
            db    $00,$75,$0F           ; $01 sword shot
            db    $4C,$C0,$0F           ; $02 boss hit / shout
            db    $80,$40,$0D           ; $04 door
            db    $1D,$0A,$0F           ; $08 hurt
            db    $20,$B0,$0E           ; $10 Aquamentus / Gleeok / Ganon roar
            db    $28,$90,$0F           ; $20 Dodongo / Gohma roar
            db    $4C,$D0,$0E           ; $40 Digdogger / Manhandla / Patra roar

; Files used by misc/io.s.  WRAM_FILENAME holds the battery-backed save RAM (HAS_BACKED_WRAM).
WRAM_FILENAME strl '1/zelda.wram'
SAVE_FILENAME strl '1/zelda.sav'     ; unused
PREF_FILENAME strl '1/zelda.prefs'

; The engine callbacks: the macros, and their code and data
            put   Hooks.s

; The palette management generated from ../palettes/ (ApplyPaletteChange; Merlin32 only reads puts
; from the segment source itself, so it is not put by Hooks.s)
            put   pal_transitions.s

            put   ../../../misc/App.Msg.s         ; Text (DrawByte / DrawWord): VIDEO > SHOW FPS and the debug displays

            put   ../../../apu/apu.s

; Core code (the engine -- the ppu/ files, the blitter, the tile and sprite compilers -- is in Engine.s)
            put   ../../../rom/scaffold.s
            put   ../../../rom/rom_color.s        ; (also in Engine.s: for the palette code here)
            put   ../../../rom/rom_helpers.s
            put   ../../../rom/rom_input.s
            put   ../../../rom/rom_kbd_basic.s
            put   ../../../rom/rom_kbd_j13.s
            put   ../../../rom/rom_kbd_adb.s
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

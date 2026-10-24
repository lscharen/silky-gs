; Tengen Tetris -- the entry point and the game's code
;
; The runtime's declarations (the build expands the list: src/runtime/head.txt)
; mput ../../runtime/head.txt
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            REL
            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s
            put    ../../Externals.s
            put    ../../core/Defs.s
            put    ../../ImportEngine.s
; AUTOINC:END

; The game's configuration (constants) and its callbacks (Hooks.s, macros only: put after the entry code)
            put   Config.s
            put   pal_defs.s                  ; Palette ids (generated from palettes/)

            mx    %00

            phk
            plb

; Call startup immediately after entering the application with the cartridge configuration

            tax                               ; X = memory manager user ID (passed in A by GS/OS)
            lda   #VERTICAL_MIRRORING         ; A = cartridge nametable mirroring at power on (iNES header)
            jsr   NES_StartUp

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Load the leaderboard before the ROM boots: its reset code keeps the scores when the magic number
; (initMagic, $04F7) and the digits check out, and clears them otherwise

            ldx   #LEADERBOARD_RAM
            lda   #LEADERBOARD_SIZE
            jsr   LoadROMData

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

; Save the leaderboard

            ldx   #LEADERBOARD_RAM
            lda   #LEADERBOARD_SIZE
            jsr   SaveROMData

; Exit the application

            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

; The scores, lines and levels, the leaderboard, the menu settings and initMagic ($0418-$04FA in ram.s)
LEADERBOARD_RAM  equ $0418
LEADERBOARD_SIZE equ $04FB-$0418

; Name of the save and preference files
SAVE_FILENAME strl '1/tetris.sav'
PREF_FILENAME strl '1/tetris.prefs'

; The engine callbacks (the macros; the code they call is below)
            put   Hooks.s

; ===========================================================================
; The game's code: start-up, the event loop and frame hooks
; ===========================================================================
            mx    %00

; Start-up (NES_StartUp).  The palettes are managed by the code generated from palettes/
; (pal_transitions.s): SetDefaultPalette, and ApplyPaletteChange, the PRE_RENDER hook.
InitPlayfield
            jmp   SetDefaultPalette

; PRE_RENDER: a CHR-ROM bank switch.  The ROM's setCNROMBank records the bank in ppu_bank and sets
; ppu_bank_changed (SetCNROMBank_GS, support.s); copy the bank from the ROM segment (rom.s) into the
; PPU's CHR_ROM, then convert and compile every tile again and redraw the background (PPU_ReloadCHR).
; Very slow, but the game only switches banks between screens.  The flag is cleared first, so a switch
; while this runs is seen at the next render.
CHR_BANKS   EXT                               ; rom.s
CHR_BANK1   EXT

CheckCHRBank
            ldal  ppu_bank_changed
            bne   :changed
            rtl
:changed    lda   #0
            stal  ppu_bank_changed
            ldx   #0
            ldal  ppu_bank
            and   #$0001
            bne   :bank1
:copy0      ldal  CHR_BANKS,x
            stal  CHR_ROM,x
            inx
            inx
            cpx   #$2000
            bcc   :copy0
            bra   :reload
:bank1      ldal  CHR_BANK1,x
            stal  CHR_ROM,x
            inx
            inx
            cpx   #$2000
            bcc   :bank1
:reload     jsl   PPU_ReloadCHR
            rtl

            mx    %00

; The palette management generated from palettes/ (ApplyPaletteChange; Merlin32 only reads puts
; from the segment source itself, so it is not put by Hooks.s)
            put   pal_transitions.s

; The runtime's code (the build expands the list: src/runtime/code.txt)
            mput  ../../runtime/code.txt
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            put    ../../misc/App.Msg.s
            put    ../../misc/io.s
            put    ../../apu/apu.s
            put    ../../rom/scaffold.s
            put    ../../rom/rom_color.s
            put    ../../rom/rom_helpers.s
            put    ../../rom/rom_input.s
            put    ../../rom/rom_kbd_basic.s
            put    ../../rom/rom_kbd_j13.s
            put    ../../rom/rom_kbd_adb.s
            put    ../../rom/rom_exec.s
            put    ../../rom/rom_config.s
            put    ../../rom/rom_config_setup.s
            put    ../../core/ControlBits.s
            put    ../../core/CoreImpl.s
            put    ../../core/Graphics.s
            put    ../../core/Math.s
            put    ../../core/Memory.s
; AUTOINC:END

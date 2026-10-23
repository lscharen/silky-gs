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

L1_T0       EXT                       ; Swizzle tables live in the PALDATA segment (palettes.s)

; The game's configuration (constants) and its callbacks (Hooks.s, macros only: put after the entry code)
            put   Config.s

            mx    %00

            phk
            plb

; Call startup immediately after entering the application with the cartridge configuration

            tax                           ; X = memory manager user ID (passed in A by GS/OS)
            lda   #VERTICAL_MIRRORING      ; A = cartridge nametable mirroring at power on
            jsr   NES_StartUp

; This is set up to let the game define all colors.  We only need to set up a single, static
; swizzle table

            lda   SwizzleTables+2
            ldx   SwizzleTables
            jsr   NES_SetPaletteMap

; Initialize the graphics for the main game mode

            jsr   SetDefaultPalette

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
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

; The user has existed the runtime
quit
            jsr   NES_ShutDown

; Exit the application

            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

; Name of the save and preference files (used by misc/io.s)
SAVE_FILENAME strl '1/bf.sav'
PREF_FILENAME strl '1/bf.prefs'

; The engine callbacks (the macros; the code they call is below, and the engine side's in EngineExt.s)
            put   Hooks.s

; ===========================================================================
; The game's code: start-up, the event loop and frame hooks
; ===========================================================================
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
            rtl

            mx    %00

; The render screen (CUSTOM_RENDER_SCREEN_ADDR, see ppu/ppu_api.s).  In Balloon Trip the status bar, the
; top 16 lines, doesn't scroll and the rest of the screen does, as in Super Mario Bros.; otherwise the
; engine draws the screen.
            mx    %00
BF_RenderScreen ENT
            ldal  DP_NES
            tax
            ldal  $000016,x               ; Balloon Trip mode: $16 != 0
            and   #$00FF
            bne   :trip
            clc                           ; Not drawn
            rtl

:trip       ldal  _ppuscroll_y
            tay
            ldal  _ppuscroll_x
            tax
            ldal  _ppuctrl
            jsl   NES_SetScroll

            lda   #0                      ; The status bar
            ldx   #16
            ldy   #0
            jsl   PPU_SetupLines

            lda   ScreenHeight            ; The rest of the screen
            sec
            sbc   #16
            tax
            lda   #16
            ldy   StartX
            jsl   PPU_SetupLines

            jsl   PPU_DrawScreen
            lda   #DIRTY_BIT_BG0_REFRESH  ; Drawn; the engine redraws everything if it draws the next one
            sec
            rtl

            mx    %00

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

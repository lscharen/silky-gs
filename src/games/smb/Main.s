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

            tax                           ; X = memory manager user ID (passed in A by GS/OS)
            lda   #VERTICAL_MIRRORING      ; A = cartridge nametable mirroring at power on
            jsr   NES_StartUp

; Now, initialize the game-specific functionality that this wrapper needs in order to
; run the game in an effective manner.

; Set the palettes and swizzle tables

            jsr   SetDefaultPalette

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
; Call the boot code in the ROM

            jsr   NES_ColdBoot

; Apply hacks
;WorldNumber           = $075f
;LevelNumber           = $075c
;AreaNumber            = $0760
ContinueWorld          = $07fd
;OffScr_WorldNumber    = $0766
;OffScr_AreaNumber     = $0767
;OffScr_LevelNumber    = $0763
ContinueArea           = $7E00   ; patches operand

;            lda   #16
;            jsr   _SetBG0YPos
;            jsr   _ApplyBG0YPosPreLite
;            jsr   _ApplyBG0YPosLite       ; Set up the code field

; Start up the NES
:start
; Hack for testing
;            sep   #$20
;            lda   #3
;            stal  ROMBase+ContinueWorld
;            lda   #1
;            stal  ROMBase+ContinueArea
;            rep   #$20

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
SAVE_FILENAME strl '1/smb.sav'
PREF_FILENAME strl '1/smb.prefs'

; The engine callbacks (the macros; the code they call is below, and the engine side's in EngineExt.s)
            put   Hooks.s

; ===========================================================================
; The game's code: start-up, the event loop and frame hooks
; ===========================================================================
            mx    %00

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

            ldy   ScreenHeight
            jsr   _SetScreenHeight               ; This is also called in the Init

; Start with the title screen's (ground) palette

            jmp   SetDefaultPalette

; Copy just the tiles that change directly to the graphics screen

MemOffsets    dw    67, 68, 69, 70, 71,                        82, 83, 84, 85, 86,  89, 90, 91, 92
              dw    99,100,101,102,103,104,  107,108,109,110,     115,116,117,         122,123,124

ScreenOffsets dw    12, 16, 20, 24, 28,                        72, 76, 80, 84, 88,  100,104,108,112
              dw    ROW_STEP+12,ROW_STEP+16,ROW_STEP+20,ROW_STEP+24,ROW_STEP+28,ROW_STEP+32
              dw    ROW_STEP+44,ROW_STEP+48,ROW_STEP+52,ROW_STEP+56
              dw    ROW_STEP+76,ROW_STEP+80,ROW_STEP+84
              dw    ROW_STEP+104,ROW_STEP+108,ROW_STEP+112

CopyStatusToScreen

            mx    %00

; The palette management generated from palettes/ (ApplyPaletteChange)
            put   pal_transitions.s

; The render screen (CUSTOM_RENDER_SCREEN_ADDR, see ppu/ppu_api.s): the status bar, the top 16 lines,
; doesn't scroll; the rest of the screen is at the scroll position.  The game never scrolls vertically.
            mx    %00
SMB_RenderScreen ENT
            ldal  _ppuscroll_x
            tax
            ldal  _ppuctrl
            ldy   #0
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

            DO    SHOW_DEBUG_VARS
            lda   LastRead                ; The keyboard input (the engine shows the rest)
            ldx   #32*160
            ldy   #$FFFF
            jsl   DrawWordL
            FIN

            lda   #0                      ; Drawn: DirtyBits = 0
            sec
            rtl

            mx    %00

; The control and scroll locks (CUSTOM_PPU_CTRL_LOCK_ADDR / CUSTOM_PPU_SCROLL_LOCK_ADDR, see ppu/ppu_api.s):
; the game's own copies of the registers, Mirror_PPU_CTRL_REG1 ($0778), HorizontalScroll ($073F) and
; VerticalScroll ($0740)
            mx    %00
SMB_CtrlLock ENT
            ldal  ROMBase+$0778
            sec
            rtl

SMB_ScrollLock ENT
            ldal  ROMBase+$073f           ; X, Y
            xba                           ; X in the high byte, Y in the low byte
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

; Duck Hunt -- the entry point and the game's code
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
            put    ../../rom/rom_kbd_macs.s
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
            lda   #VERTICAL_MIRRORING      ; A = cartridge nametable mirroring at power on (iNES header)
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

; DMC samples decoded at start-up: count, then $4012 address, $4013 length, $4010 rate for each
; (_func_f591, $F591: the sound requests in $F2 bits 0 and 1)
DMC_SAMPLE_LIST
            db    2
            db    $EC,$20,$0E           ; $F2 bit 0: $FB00, 513 bytes
            db    $F4,$20,$0F           ; $F2 bit 1: $FD00, 513 bytes

; Name of the save and preference files (nothing is saved yet: the top score is not kept)
SAVE_FILENAME strl '1/duckhunt.sav'
PREF_FILENAME strl '1/duckhunt.prefs'

; The engine callbacks (the macros; the code they call is below, and the engine side's in EngineExt.s)
            put   Hooks.s

; ===========================================================================
; The game's code: start-up, the event loop and frame hooks
; ===========================================================================
            mx    %00

; Start-up (NES_StartUp).  The palettes are managed by the code generated from palettes/
; (pal_transitions.s): SetDefaultPalette, and ApplyPaletteChange, the PRE_RENDER hook.
InitPlayfield
            jmp   SetDefaultPalette

            DO    MOUSE_ZAPPER

; The GAME menu (CONFIG_GAME_MENU): the pointer's size, the shot's jitter and the still pointer's strobe.
; The values are the CFG_GAME_* words (Hooks.s), applied by DH_ApplyConfig.
GAME_TITLE_STR      str 'GAME'
GAME_CURSOR_STR     str 'CURSOR SIZE'
GAME_LARGE_STR      str 'LARGE'
GAME_SMALL_STR      str 'SMALL'
GAME_JITTER_STR     str 'JITTER'
GAME_STROBE_STR     str 'STROBE'
GAME_0_STR          str '0'
GAME_1_STR          str '1'
GAME_2_STR          str '2'
GAME_3_STR          str '3'
GAME_25_STR         str '25'
GAME_50_STR         str '50'
GAME_75_STR         str '75'
GAME_100_STR        str '100'

GAME_CONFIG  dw   GAME_TITLE_STR
             dw   DRIVERS_CONFIG        ; previous menu item
             dw   CREDITS_CONFIG        ; next menu item

             dw   3
             dw   GAME_ITEM_CURSOR
             dw   GAME_ITEM_JITTER
             dw   GAME_ITEM_STROBE

GAME_ITEM_CURSOR dw RADIO
             dw   0                     ; previous control
             dw   GAME_ITEM_JITTER      ; next control
             dw   3,2
             dw   GAME_CURSOR_STR
             dw   config_game_start+CFG_GAME_CURSOR
             dw   2
             dw   0,GAME_LARGE_STR,0
             dw   1,GAME_SMALL_STR,0

GAME_ITEM_JITTER dw RADIO
             dw   GAME_ITEM_CURSOR
             dw   GAME_ITEM_STROBE
             dw   3,7
             dw   GAME_JITTER_STR
             dw   config_game_start+CFG_GAME_JITTER
             dw   4
             dw   0,GAME_0_STR,0
             dw   1,GAME_1_STR,0
             dw   2,GAME_2_STR,0
             dw   3,GAME_3_STR,0

GAME_ITEM_STROBE dw RADIO
             dw   GAME_ITEM_JITTER
             dw   0
             dw   12,7
             dw   GAME_STROBE_STR
             dw   config_game_start+CFG_GAME_STROBE
             dw   5
             dw   0,GAME_0_STR,0        ; the frames of each second it is hidden
             dw   15,GAME_25_STR,0
             dw   30,GAME_50_STR,0
             dw   45,GAME_75_STR,0
             dw   60,GAME_100_STR,0

; Apply the GAME menu's values (CONFIG_APPLY_HOOK): Y = config_game_start, 16-bit registers, DBR = this
; bank
DH_ApplyConfig
            lda:  CFG_GAME_CURSOR,y
            beq   :large
            lda   #DH_CURSOR_SMALL
            bra   :cursor
:large      lda   #DH_CURSOR_LARGE
:cursor     sta   dhPointer
            lda:  CFG_GAME_JITTER,y     ; 0 - 3 -> the mask: 0, 1, 3, 7
            tax
            lda   #0
:mask       dex
            bmi   :jitter
            sec
            rol
            bra   :mask
:jitter     sta   mouseJitter           ; (rom/rom_mouse.s)
            lda:  CFG_GAME_STROBE,y
            sta   dhStrobeHide
            rtl

; The Zapper's pointer (PRE_RENDER): the mouse driver's sprite (rom/rom_mouse.s), a 7x7 cursor in color 1
; of palette 0, in front of the background.  The cursors are tiles $E1 / $E6 of pattern table 1
; (tools/convert.js, CURSOR_TILES), which SPRITE_PRE_DRAW selects for the pointer (EngineExt.s, dhPtrIdx).
;
; The strobe: while the mouse is still (no move in the last DH_STILL_VBLS VBLs), the pointer is hidden
; for the first dhStrobeHide VBLs of every second (dhStrobePhase: 0 - 59, counted in VBLs, vblCount).
; 16-bit registers, DBR = this bank.
DH_CURSOR_LARGE equ $00E1               ; attributes << 8 | tile
DH_CURSOR_SMALL equ $00E6
DH_STILL_VBLS   equ 8

dhPtrIdx    EXT                         ; (EngineExt.s)

DH_ShowPointer
            lda   #$FFFF                ; Not shown, unless it is added below
            stal  dhPtrIdx

            lda   vblCount              ; The strobe's phase, from the VBLs since the last render
            sec
            sbc   dhLastVbl
            clc
            adc   dhStrobePhase
:wrap       cmp   #60
            bcc   :phase
            sbc   #60
            bra   :wrap
:phase      sta   dhStrobePhase
            lda   vblCount
            sta   dhLastVbl

            lda   mouseX                ; Has the mouse moved?  (rom/rom_mouse.s)
            cmp   dhLastX
            bne   :moved
            lda   mouseY
            cmp   dhLastY
            bne   :moved
            lda   vblCount
            sec
            sbc   dhMovedVbl
            cmp   #DH_STILL_VBLS
            bcc   :show                 ; Moved a moment ago: still moving
            lda   dhStrobePhase
            cmp   dhStrobeHide
            bcc   :out                  ; Still, in the hidden part of the second
            bra   :show

:moved      lda   mouseX                ; (either one changed: take both)
            sta   dhLastX
            lda   mouseY
            sta   dhLastY
            lda   vblCount
            sta   dhMovedVbl

:show       lda   dhPointer
            jsr   Mouse_AddPointer      ; Y = its OAM_COPY index
            tya
            stal  dhPtrIdx
:out        rtl

dhPointer     dw  DH_CURSOR_LARGE       ; DH_ApplyConfig: the cursor's tile
dhStrobeHide  dw  0                     ; DH_ApplyConfig: VBLs of each second the still pointer is hidden
dhStrobePhase dw  0
dhLastVbl     dw  0
dhMovedVbl    dw  0
dhLastX       dw  0
dhLastY       dw  0
            FIN

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
            put    ../../rom/rom_mouse.s
            put    ../../rom/rom_exec.s
            put    ../../rom/rom_config.s
            put    ../../rom/rom_config_setup.s
            put    ../../core/ControlBits.s
            put    ../../core/CoreImpl.s
            put    ../../core/Graphics.s
            put    ../../core/Math.s
            put    ../../core/Memory.s
; AUTOINC:END

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
            lda   #VERTICAL_MIRRORING      ; A = cartridge nametable mirroring at power on
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

; The user has existed the runtime
quit
            jsr   NES_ShutDown

; Exit the application

            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

; Name of the save and preference files (used by misc/io.s)
SAVE_FILENAME strl '1/eb.sav'
PREF_FILENAME strl '1/eb.prefs'

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

            mx    %00

; The palette management generated from palettes/ (ApplyPaletteChange)
            put   pal_transitions.s

; The render screen (CUSTOM_RENDER_SCREEN_ADDR, see ppu/ppu_api.s).  During a race the crowd (the top 40
; lines) scrolls at its own speed, the track with the player, and the status bar (the bottom 32 lines)
; doesn't; otherwise the engine draws the screen.  The vertical scroll position is never changed.
;
; ram_004E_base_nametable is for the crowd offset, ram_004D_base_nametable for the track offset.
_topscroll  ds    2                       ; The crowd's scroll position (EB_ScrollLock)
_top_bg_x   ds    2

            mx    %00
EB_RenderScreen ENT
            phb
            phk
            plb
            ldal  DP_NES
            tax
            ldal  $000047,x
            and   #$00FF
            bne   :racing
            plb
            clc                           ; Not drawn
            rtl

:racing     sep   #$20
            ldal  $00004E,x               ; Bit 0 is the high bit of the X scroll position
            lsr                           ; put in the carry bit
            lda   _topscroll              ; load the scroll value
            ror                           ; put the high bit and divide by 2 for the engine
            rep   #$20
            and   #$00FF                  ; make sure nothing is in the high byte
            sta   _top_bg_x               ; This is used directly so needs a byte offset (0 - 255)

            ldal  $00004D,x
            and   #$0001                  ; Isolate the X nametable select bit
            pha
            ldal  _ppuscroll_x
            tax
            pla
            ldy   #0
            jsl   NES_SetScroll

            lda   #0                      ; The crowd (40 lines)
            ldx   #40
            ldy   _top_bg_x
            jsl   PPU_SetupLines

            lda   #40                     ; The track, which moves with the player
            ldx   #{200-32-40}
            ldy   StartX
            jsl   PPU_SetupLines

            lda   #200-32                 ; The status bar (32 lines)
            ldx   #32
            ldy   #0
            jsl   PPU_SetupLines

            jsl   PPU_DrawScreen

            DO    SHOW_DEBUG_VARS
            lda   LastRead                ; The keyboard input (the engine shows the rest)
            ldx   #32*160
            ldy   #$FFFF
            jsl   DrawWordL
            FIN

            plb
            lda   #0                      ; Drawn: DirtyBits = 0
            sec
            rtl

            mx    %00

; The scroll lock (CUSTOM_PPU_SCROLL_LOCK_ADDR, see ppu/ppu_api.s): the game's scroll position ($12, $13)
; and the crowd's ($50), for EB_RenderScreen
            mx    %00
EB_ScrollLock ENT
            ldal  DP_NES
            tax
            ldal  $000050,x
            stal  _topscroll
            ldal  $000012,x               ; Y, X
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
            put    ../../rom/rom_exec.s
            put    ../../rom/rom_config.s
            put    ../../rom/rom_config_setup.s
            put    ../../core/ControlBits.s
            put    ../../core/CoreImpl.s
            put    ../../core/Graphics.s
            put    ../../core/Math.s
            put    ../../core/Memory.s
; AUTOINC:END

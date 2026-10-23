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

; The engine callbacks (the macros; the code they call is below, and the engine side's in EngineExt.s)
            put   Hooks.s

; ===========================================================================
; The game's code: start-up, the event loop and frame hooks
; ===========================================================================
            mx    %00

zDoorBand   EXT

; Start-up (NES_StartUp).  The palettes are managed by the code generated from palettes/
; (pal_transitions.s): SetDefaultPalette, and ApplyPaletteChange, the PRE_RENDER hook.
InitPlayfield
            jmp   SetDefaultPalette

; Link goes under the top door of the dungeons by the NES limit of 8 sprites per scanline (see the
; door band in EngineExt.s).  PRE_RENDER: the band is on if OAM 0 in NES RAM is one of the blank
; sprites: Y $3D and tile $1C, one compare (the Y too: the game hides sprites by their Y alone, so the
; tile stays in OAM 0 after a dungeon).
            mx    %00
HideDoorBand
            lda   #0
            stal  sprClipTop                ; (ZSpriteClip sets it for each sprite while the band is on)
            stal  zDoorBand
            ldal  ROMBase+DIRECT_OAM_READ   ; OAM 0: Y, tile
            cmp   #$1C3D
            bne   :off
            lda   #1
            stal  zDoorBand
:off        rtl

            mx    %00

; The palette management generated from ../palettes/ (ApplyPaletteChange; Merlin32 only reads puts
; from the segment source itself, so it is not put by Hooks.s)
            put   pal_transitions.s

; Room transitions scroll the play area under a fixed status bar.  The NES does it with a sprite-0
; hit at the bottom of the status bar: the NMI shows the status bar at scroll (0,0), then
; WaitAndScrollToSplitBottom (bank 5) changes the scroll for the play area from NES scanline 64.
;
; The engine isn't cycle accurate, so the split is recorded instead: WaitAndScrollToSplitBottom calls
; Z_RecordSplit, in the NMI, which works out the play area's scroll from the game state the routine
; uses.  NES_RenderFrame latches it (Z_LatchSplit, the scroll lock) together with the PPU registers,
; the OAM and the nametable queue, so a render shows the play area at the scroll of the same NES frame
; as its tiles.  (The game state itself is a frame ahead by then: the NMI's mode update has already
; moved the scroll for the next frame and queued the row or column that goes with it.)
;
; While a split was made since the last render, this renderer redraws just the play area at that
; scroll and leaves the status bar on the screen as it is.  The rest of the time the default renderer
; is used.

Z_GameMode            equ $12               ; NES zero page variables
Z_GameSubmode         equ $13
Z_VScrollAddrHi       equ $58
Z_OddBaseNTOverride   equ $5F
Z_ObjDir              equ $98
Z_VScrollAddrLo       equ $E2
Z_CurHScroll          equ $FD
Z_CurPpuControl       equ $FF

ZELDA_SPLIT_LINE      equ 64-y_offset       ; screen line of NES scanline 64, the top of the play area
ZELDA_PF_LINES        equ y_height-ZELDA_SPLIT_LINE

zSplitSeen  dw    0                         ; NES side: a split was made since the last render
zSplitNT    dw    0                         ; NES side: the play area scroll of the last split
zSplitX     dw    0
zSplitY     dw    0
zSplitAddr  dw    0                         ; (scratch: the PPU address of a vertical split)

zPfSplit    dw    0                         ; Latched for the render: draw the screen split
zPfNT       dw    0                         ; and the play area's nametable select and scroll
zPfX        dw    0
zPfY        dw    0

; Called by WaitAndScrollToSplitBottom (JSL from bank 5) with the NES direct page, before it sets the
; scroll for the play area.  All registers are preserved.
            mx    %11
Z_RecordSplit ENT
            php
            phb
            phk
            plb
            rep   #$30
            pha
            phx

            lda   Z_CurPpuControl           ; The status bar is from nametable 0 or 2 at (0,0)
            and   #$0002
            sta   zSplitNT                  ; Default: the play area isn't split off
            stz   zSplitX
            stz   zSplitY

            lda   Z_GameMode
            and   #$00FF
            cmp   #$08
            bcc   :early

; GameMode 8 - $10 turn the video off below the split (the latched PPUMASK has the background and
; sprites off, so the play area is drawn blank); $11 and up switch the base nametable (0 -> 1, 2 -> 3).

            cmp   #$11
            bcc   :late_done
            lda   #$0001
            tsb   zSplitNT
:late_done  brl   :done

:early      lda   Z_GameSubmode
            and   #$00FF
            beq   :done                     ; Submode 0: the scroll isn't changed
            lda   Z_ObjDir
            and   #$00FF
            cmp   #$04
            bcs   :vertical

; Horizontal: nametable (CurPpuControl & $FE) | OddBaseNameTableOverride, X = CurHScroll.  The Y
; scroll written mid-frame doesn't move the rows, so they stay where they are.

            lda   Z_OddBaseNTOverride
            and   #$0001
            tsb   zSplitNT
            lda   Z_CurHScroll
            and   #$00FF
            sta   zSplitX
            bra   :done

; Vertical (horizontal mirroring): PPUADDR = VScrollAddr, so that nametable row (from its fine Y
; line) is drawn from NES scanline 64.  Nametable 0 is lines 0-239 of the code field and nametable 2
; lines 240-479.

:vertical   lda   Z_VScrollAddrLo
            and   #$00FF
            sta   zSplitAddr
            lda   Z_VScrollAddrHi
            and   #$00FF
            xba
            tsb   zSplitAddr                ; zSplitAddr = PPU address

            and   #$0800                    ; nametable 2?
            beq   *+5
            lda   #240
            sta   zSplitY

            lda   zSplitAddr
            and   #$03E0                    ; coarse Y << 5
            lsr
            lsr                             ; coarse Y * 8
            clc
            adc   zSplitY
            sta   zSplitY

            lda   zSplitAddr                ; The $2006 write also sets the fine Y scroll, to
            xba                             ; address bits 12-14 (2 for $2xxx), and the two $2007
            lsr                             ; reads after it, during rendering, each move it down
            lsr                             ; one more line
            lsr
            lsr
            and   #$0007
            clc
            adc   #2
            adc   zSplitY                   ; V = line of the row in the code field
            sec
            sbc   #ZELDA_SPLIT_LINE+y_offset ; scroll that puts line V at NES scanline 64
            bpl   *+6
            clc
            adc   #480
            ldx   #0
            cmp   #240
            bcc   :v_set
            sbc   #240                      ; (carry is set)
            ldx   #2
:v_set      sta   zSplitY
            stx   zSplitNT

:done       lda   #1
            sta   zSplitSeen
            plx
            pla
            plb
            plp
            rtl

; The scroll lock (CUSTOM_PPU_SCROLL_LOCK_ADDR, see ppu/ppu_api.s), with interrupts off: latch the split
; for this render; the engine latches the scroll register itself
            mx    %00
Z_LatchSplit ENT
            phb
            phk
            plb
            lda   zSplitSeen
            sta   zPfSplit
            stz   zSplitSeen
            lda   zSplitNT
            sta   zPfNT
            lda   zSplitX
            sta   zPfX
            lda   zSplitY
            sta   zPfY
            plb
            clc                             ; The scroll is the register's
            rtl

; The render screen (CUSTOM_RENDER_SCREEN_ADDR, see ppu/ppu_api.s).  While split, draw only the play area,
; at its own scroll position: the status bar doesn't move during a transition, so it is left as it is on
; the screen.  Otherwise the engine draws the screen (and redraws all of it once after a transition).
            mx    %00
Z_RenderScreen ENT
            phb
            phk
            plb
            lda   zPfSplit
            bne   :split
            plb
            clc                             ; Not drawn
            rtl

:split      lda   zPfNT
            ldx   zPfX
            ldy   zPfY
            jsl   NES_SetScroll
            lda   #ZELDA_SPLIT_LINE
            ldx   #ZELDA_PF_LINES
            jsl   PPU_DrawScreenRange
            plb
            lda   #DIRTY_BIT_BG0_REFRESH    ; Drawn; the engine redraws everything if it draws the next one
            sec
            rtl

            mx    %00

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

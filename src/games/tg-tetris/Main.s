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

; ===========================================================================
; The scores beside the playfield
; ===========================================================================
;
; The playfield is the left 128 bytes of each screen line (x_offset = 0); the gutter is the other 32
; bytes, from SHR $2080: 8 characters of the runtime's built-in font (rom_config.s), drawn straight to
; the screen (and its shadow) in one palette slot.  It follows the game: a number is drawn after a
; space, with its leading zeros dropped.
;
;   title, menus,       one player game     two player or
;   leaderboard         (and the demo)      co-op game
;
;   H. SCORE            H. SCORE            P1 SCORE
;    17000               17000               1230
;
;                       SCORE               P2 SCORE
;                        1230                880
;
; TT_LatchScores (CUSTOM_PPU_SCROLL_LOCK) copies the scores and works out the layout from the NES RAM
; with the rest of the render's state; TT_RenderScreen (CUSTOM_RENDER_SCREEN) draws the gutter when
; they changed since it last drew it, when the palette changed (the text slot depends on it), or when
; the engine is about to redraw the whole screen (DIRTY_BIT_BG0_REFRESH, e.g. back from the
; configuration screen), and then lets the engine draw the screen.

TT_P1_SCORE   equ $0418                     ; player1ScoreHundredThousands: 6 digits, '0' - '9'
TT_P2_SCORE   equ $041E                     ; player2ScoreHundredThousands
TT_HIGH_SCORE equ $043C                     ; highScoreHundredThousands
TT_GAME_STATE equ $29                       ; gameState (NES zero page)
TT_PLAY_MODE  equ $2F                       ; playMode: $00 = 1p, $01 = 2p, $FF = co-op
GAMESTATE_GAMEOVER_TT equ $F9               ; (ram.s, in the ROM segment, has the names)
GAMESTATE_DEMO_TT     equ $FB
TT_GUTTER     equ $2080                     ; SHR offset of the gutter's first character
TT_ROW        equ {8*160}                   ; one row of characters

; The layouts (ttLatch+18)
TT_MENUS      equ 0
TT_GAME_1P    equ 2
TT_GAME_2P    equ 4

; CUSTOM_PPU_SCROLL_LOCK: latch the scores and the layout (interrupts off, DBR = the engine's bank).
; C = 0: the scroll is the register's last value.
            mx    %00
TT_LatchScores ENT
            phb
            sep   #$20
            lda   #^ROMBase                 ; The NES RAM
            pha
            plb
            rep   #$20
            ldx   #4
:copy       lda   TT_P1_SCORE,x
            stal  ttLatch,x
            lda   TT_HIGH_SCORE,x
            stal  ttLatch+6,x
            lda   TT_P2_SCORE,x
            stal  ttLatch+12,x
            dex
            dex
            bpl   :copy
            plb

            ldal  DP_NES                    ; The NES zero page
            tax
            ldy   #TT_MENUS
            ldal  TT_GAME_STATE,x           ; In a game: playing, paused, level up ($00 - $03), game over
            and   #$00FF                    ; ($F9) or the demo ($FB)
            cmp   #$80
            bcc   :game
            cmp   #GAMESTATE_GAMEOVER_TT
            beq   :game
            cmp   #GAMESTATE_DEMO_TT
            bne   :layout
:game       ldy   #TT_GAME_1P
            ldal  TT_PLAY_MODE,x
            and   #$00FF
            beq   :layout
            ldy   #TT_GAME_2P
:layout     tya
            stal  ttLatch+18
            clc
            rtl

; CUSTOM_RENDER_SCREEN: draw the gutter if it changed (DBR = the engine's bank, D = the runtime's direct
; page).  C = 0: the engine draws the screen.
TT_RenderScreen ENT
            phb
            phk
            plb
            lda   DirtyBits
            bit   #DIRTY_BIT_BG0_REFRESH
            bne   :draw
            lda   palCurrent
            cmp   ttDrawnPal
            bne   :draw
            ldx   #18
:cmp        lda   ttLatch,x
            cmp   ttDrawn,x
            bne   :draw
            dex
            dex
            bpl   :cmp
            bra   :done

:draw       ldx   #18
:save       lda   ttLatch,x
            sta   ttDrawn,x
            dex
            dex
            bpl   :save
            lda   palCurrent
            sta   ttDrawnPal
            jsr   ttDrawGutter

:done       plb
            clc
            rtl

; Draw the five rows of the layout (ttLayouts)
ttDrawGutter
            ldx   ttDrawnPal
            lda   ttColorTbl,x
            sta   ttColor

            lda   ttDrawn+18                ; Layout * 2 -> its 5 entries (20 bytes)
            asl
            sta   ttRow
            asl
            asl
            adc   ttRow
            tax
            ldy   #TT_GUTTER
:row        phx
            phy
            lda   ttLayouts,x               ; 0 = text, 1 = a number
            pha
            lda   ttLayouts+2,x
            tax
            pla
            bne   :number
            jsr   ttDrawText
            bra   :next
:number     jsr   ttDrawNumber
:next       pla
            clc
            adc   #TT_ROW
            tay
            pla
            adc   #4
            tax
            cpy   #TT_GUTTER+{5*TT_ROW}
            bcc   :row
            rts

; Per layout, 5 rows of (0, text) or (1, the address of 6 digits)
ttLayouts   dw    0,ttHighText,1,ttDrawn+6,0,ttBlankText,0,ttBlankText,0,ttBlankText      ; TT_MENUS
            dw    0,ttHighText,1,ttDrawn+6,0,ttBlankText,0,ttScoreText,1,ttDrawn          ; TT_GAME_1P
            dw    0,ttP1Text,1,ttDrawn,0,ttBlankText,0,ttP2Text,1,ttDrawn+12              ; TT_GAME_2P

; X = 6 digits, Y = SHR offset.  Draws a space, the number without its leading zeros (at least one
; digit) and spaces to fill the 8 characters.
ttDrawNumber
            sep   #$20
            phy
            lda   #' '
            ldy   #7
:clear      sta   ttNumBuf,y
            dey
            bpl   :clear
            lda   #5                        ; Digits left after the current one
            sta   ttCount
:skip       lda:  0,x
            cmp   #'0'
            bne   :digits
            inx
            dec   ttCount
            bne   :skip
:digits     ldy   #1
:copy       lda:  0,x
            sta   ttNumBuf,y
            inx
            iny
            dec   ttCount
            bpl   :copy
            ply
            rep   #$20
            ldx   #ttNumBuf

; X = 8 characters (upper case letters, digits, '.' and spaces), Y = SHR offset
            mx    %00
ttDrawText
            lda   #8
            sta   ttChars
:char       phx
            phy
            lda:  0,x
            and   #$00FF
            jsr   ttGlyph
            plx                             ; X = SHR offset
            phx
            jsr   ttDrawGlyph
            ply
            plx
            iny
            iny
            iny
            iny
            inx
            dec   ttChars
            bne   :char
            rts

; A = character -> A = its glyph: the built-in font's (32 bytes per glyph), or ttChrPeriod
ttGlyph
            cmp   #'A'
            bcc   :digit
            sbc   #'A'
            asl
            asl
            asl
            asl
            asl
            adc   #TILE_A
            rts
:digit      cmp   #'0'
            bcc   :other
            sbc   #'0'
            cmp   #10
            bcs   :other
            asl
            asl
            asl
            asl
            asl
            adc   #TILE_ZERO
            rts
:other      cmp   #'.'
            bne   :space
            lda   #ttChrPeriod
            rts
:space      lda   #TILE_SPACE
            rts

; A = glyph, X = SHR offset.  Each line of a glyph is two words of 4 pixels (w_wxxy_yzz0, 2 bits each);
; a pixel is drawn in ttColor wherever the font has one.
ttDrawGlyph
            tay
            lda   #8
            sta   ttLines
:line       lda:  0,y
            jsr   ttPixels
            stal  $E10000,x
            stal  $010000,x
            lda:  2,y
            jsr   ttPixels
            stal  $E10002,x
            stal  $010002,x
            iny
            iny
            iny
            iny
            txa
            clc
            adc   #160
            tax
            dec   ttLines
            bne   :line
            rts

; A = 4 pixels of the font -> A = 4 screen pixels
ttPixels
            sta   ttWord
            lsr
            tsb   ttWord                    ; Bits 7, 5, 3 and 1: pixels 0-3 are drawn
            stz   ttOut
            lda   #$0080
            bit   ttWord
            beq   :p1
            lda   #$00F0
            tsb   ttOut
:p1         lda   #$0020
            bit   ttWord
            beq   :p2
            lda   #$000F
            tsb   ttOut
:p2         lda   #$0008
            bit   ttWord
            beq   :p3
            lda   #$F000
            tsb   ttOut
:p3         lda   #$0002
            bit   ttWord
            beq   :p4
            lda   #$0F00
            tsb   ttOut
:p4         lda   ttOut
            and   ttColor
            rts

; The text's slot in every pixel of a word, by palette id (PAL_*, pal_defs.s): $30 (white) is in slot
; 10 of every palette but title's, which has no white; there it is $37, in slot 7.  0 = no palette yet.
ttColorTbl  dw    $7777                     ; (none yet: title's layout)
            dw    $7777                     ; PAL_TITLE
            dw    $AAAA                     ; PAL_MENU
            dw    $AAAA                     ; PAL_GAME_1P
            dw    $AAAA                     ; PAL_GAME_2P
            dw    $AAAA                     ; PAL_LEADERBOARD
            dw    $AAAA                     ; PAL_BONUS

ttHighText  asc   'H. SCORE'
ttScoreText asc   'SCORE   '
ttP1Text    asc   'P1 SCORE'
ttP2Text    asc   'P2 SCORE'
ttBlankText asc   '        '

ttChrPeriod dw    %000000000,%000000000     ; The font has no '.'
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000000000,%000000000
            dw    %000011110,%000000000
            dw    %000011110,%000000000
            dw    %000000000,%000000000

ttLatch     ds    20                        ; Latched: player 1's score, the high score, player 2's score, the layout
ttDrawn     ds    20                        ; The same, as the gutter shows them
ttDrawnPal  dw    $FFFF                     ; The palette it was drawn in ($FFFF = not drawn yet)
ttNumBuf    ds    8
ttColor     dw    0
ttRow       dw    0
ttCount     dw    0
ttChars     dw    0
ttLines     dw    0
ttWord      dw    0
ttOut       dw    0

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

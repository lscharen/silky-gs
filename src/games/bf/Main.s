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

            mx    %00

; Define all of the macros that are used to callback into this
; code.  Defining an empty macro will result in no callback

; Callback before entering the main event loop
PRE_EVT_LOOP mac
;
             <<<

POST_EVT_LOOP mac
;
             <<<

EVT_LOOP_BEGIN mac
;
             <<<

EVT_LOOP_END mac
;
             <<<

PRE_RENDER   mac
;
             <<<

; For this ROM, we check the NES RAM after each rendered frame to see if the
; mapped palette needs to be updated
POST_RENDER  mac
            ldal  $0100c8               ; ROM zero page, $00C8 = Phase Type (00 = Regular, 01 = Bonus)
            and   #$00FF
            bne   bonus

            ldal  $01003c               ; $003B = Current Phase
            and   #$000C	            ;  | Select Palette based
            lsr
            lsr
            inc                         ; +1 because palette index 0 is the title screen
            bra   apply_pal
bonus
            lda   #0
apply_pal
            cmp   LastAreaType
            beq   no_area_change
            sta   LastAreaType
            jsr   SetPalette
no_area_change
            <<<

; Define which PPU address has the background and sprite tiles
PPU_BG_TILE_ADDR  equ #$1000
PPU_SPR_TILE_ADDR equ #$0000

x_offset    equ   16                      ; number of bytes from the left edge

            phk
            plb

; Call startup immediately after entering the application: A = memory manager user ID

            jsr   NES_StartUp

; Initialize the game-specific variables

            stz   LastAreaType            ; Check if the palettes need to be updates

; Show the configuration screen

;            jsr   ShowConfig

; Set the palettes and swizzle tables

            jsr   SetDefaultPalette


; Start the FPS counter

            ldal  OneSecondCounter
            sta   OldOneSec

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
; Call the boot code in the ROM

            jsr   NES_ColdBoot

; We _never_ scroll vertically, so just set it once.  This is to make sure these kinds of optimizations
; can be set up in the generic structure

            lda   #24
            jsr   _SetBG0YPos
            jsr   _ApplyBG0YPosPreLite
            jsr   _ApplyBG0YPosLite

; Start up the NES
:start
            jsr   NES_EvtLoop

            cmp   #USER_SAYS_QUIT
            beq   :quit

            cmp   #USER_SAYS_RESET
            bne   :quit

            jsr   NES_WarmBoot
            bra   :start

; The user has existed the runtime
:quit
            jsr   NES_ShutDown

; Exit the application

            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

Greyscale   dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF

drawStats
            ldx   #0
            ldy   #$FFFF
            sec
            lda  at_queue_head          ; Calculate the number of elements in the queue
            sbc  at_queue_tail
            and  #AT_QUEUE_MASK
            jsr  DrawWord

            ldx   #8*160
            ldy   #$FFFF
            sec
            lda  nt_queue_head          ; Calculate the number of elements in the queue
            sbc  nt_queue_tail
            and  #NT_QUEUE_MASK
            jsr  DrawWord

            rts

TmpPalette  ds    32

; Program variables
singleStepMode    dw  0
; nmiCount    dw    0
OldOneSecVec      ds  4
StkSave           dw  0
LastAreaType      dw  0
frameCount        dw  0
show_vbl_cpu      dw  0
user_break        dw  0

; From the IIgs ref 
DefaultPalette   dw    $0000,$0777,$0841,$072C
                 dw    $000F,$0080,$0F70,$0D00
                 dw    $0FA9,$0FF0,$00E0,$04DF
                 dw    $0DAF,$078F,$0CCC,$0FFF

; Convert NES palette entries to IIgs
; X = NES palette (16 color indices)
; A = 32 byte array to write results
NESColorToIIgs
            sta   tmp0
            stz   tmp1

:loop       lda:  0,x
            asl
            tay
            lda   nesPalette,y
            ldy   tmp1
            sta   (tmp0),y

            inx
            inx

            iny
            iny
            sty   tmp1
            cpy   #32
            bcc   :loop
            rts

; Helper to initialize the playfield based on the selected VideoMode
InitPlayfield
;            lda   #16            ; We render starting at line 16 in the NES video buffer
            lda   #24
            sta   NesTop

            lda   VideoMode
            cmp   #0
            beq   :good
            cmp   #2
            beq   :better

            lda   #0
            sta   MinYScroll

            lda   #200
            sta   ScreenHeight
            bra   :common

:better
;            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
            lda   #24
            sta   MinYScroll

            lda   #160           ; 160 lines high for 'better'
            sta   ScreenHeight
            bra   :common

:good
;            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
            lda   #24
            sta   MinYScroll

            lda   #128           ; Only 128 lines tall for speed
            sta   ScreenHeight

; Common follow-on initialization
:common
            lda   ScreenHeight
            lsr
            lsr
            lsr
            sta   ScreenRows

            lda   #200           ; Only display down to this row
            sec
            sbc   ScreenHeight
            sta   MaxYScroll

            lda   NesTop
            clc
            adc   ScreenHeight
            sec
            sbc   #8
            inc
            sta   NesBottom

; Initialize the graphics screen playfield

            ldx   #128
            ldy   ScreenHeight
            jsr   _SetScreenMode                 ; This is also called in the Init

            lda   ScreenY0
            asl
            asl
            asl
            asl
            asl
            sta   ScreenBase
            asl
            asl
            clc
            adc   ScreenBase
            clc
            adc   #$2000+x_offset
            sta   ScreenBase

; Set a default palette for the title screen

            ldx   #TitleScreen
            lda   #TmpPalette
            jsr   NESColorToIIgs

            lda   #0
            ldx   #TmpPalette
            jsr   _SetPalette

            rts

; Make the screen appear
nesTopOffset    ds 2
nesBottomOffset ds 2
RenderScreen

; Do the basic setup

            sep   #$20
            lda   ppuctrl                 ; Bit 0 is the high bit of the X scroll position
            lsr                           ; put in the carry bit
            lda   ppuscroll+1             ; load the scroll value
            ror                           ; put the high bit and divide by 2 for the engine
            rep   #$20
            and   #$00FF                  ; make sure nothing is in the high byte
            jsr   _SetBG0XPos

; Now render the top 16 lines to show the status bar area

            clc
;            lda   #16*2
            lda   #24*2
            sta   tmp1                    ; virt_line_x2
            lda   #16*2
            sta   tmp2                    ; lines_left_x2
            lda   #0                      ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesTopOffset            ; cache the :exit_offset value returned from this function

; Next render the remaining lines

;            lda   #32*2
            lda   #40*2
            sta   tmp1                ; virt_line_x2
            lda   ScreenHeight
            sec
            sbc   #16
            asl
            sta   tmp2                ; lines_left_x2
            lda   StartX              ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesBottomOffset

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen

; Restore the buffer

            lda   #24                     ; virt_line
            ldx   #16                     ; lines_left
            ldy   nesTopOffset            ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            lda   ScreenHeight
            sec
            sbc   #16
            tax                           ; lines_left
            lda   #40                     ; virt_line
            ldy   nesBottomOffset         ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            stz   LastPatchOffset
            rts

; Initialize the swizzle pointer to the set of palette maps.  The pointer must
;
; 1. Be page-aligned
; 2. Point to 8 2kb remapping tables
; 3. The first 4 tables are for background tiles and second are for sprites
;
; A = high word, X = low word
SetPaletteMap
            sta   SwizzlePtr+2
            sta   ActivePtr+2
            stx   SwizzlePtr
            stx   ActivePtr
            rts

SetDefaultPalette
            lda   #0
SetPalette
            and   #$0001              ; only two palettes defined right now...
            asl
            tay
            ldx   AreaPalettes,y      ; First parameter to NESColorToIIgs
            phx

            asl
            tay
            lda   SwizzleTables+2,y
            ldx   SwizzleTables,y
            jsr   SetPaletteMap

            plx
            lda   #TmpPalette
            jsr   NESColorToIIgs

; Special copy routine; do not touch color index 0 -- we let the NES PPU handle that

            ldx   #2
:loop
            lda   TmpPalette,x
            stal  $E19E00,x
            inx
            inx
            cpx   #2*16
            bcc   :loop
:out

; Redraw the whole
            rts

AreaPalettes  dw   TitleScreen,LevelHeader1
SwizzleTables adrl TS_T0,L1_T0

; Palettes of NES color indexes
TitleScreen  dw    $0F, $30, $27, $2A, $15, $02, $21, $00, $10, $16, $12, $37, $21, $17, $11, $2B
LevelHeader1 dw    $0F, $2A, $09, $07, $30, $27, $16, $11, $21, $00, $10, $12, $37, $17, $35, $2B

ClearScreen
            ldx  #$7CFE
:loop       stal $012000,x
            dex
            dex
            bpl  :loop
            rts

; Draw PPU tiles to the screen for a UI
;
; 0 - 9 starts at tile 256
; A - Z starts at tile 266
; mushroom is $1CE = 462
TILE_ZERO   equ 256
TILE_A      equ 266
TILE_SHROOM equ 462
TILE_BLANK  equ 295
COL_STEP    equ 4
ROW_STEP    equ {8*160}
_PutTile    mac
;            pea {]1}+TILE_USER_BIT
;            pea $2000+{]2*COL_STEP}+{]3*ROW_STEP}
;            pea ]4
;            _GTEDrawTileToScreen     ; call NESTileBlitter direction
            <<<
_PutStr     mac
            ldx #]1
            ldy #$2000+{]2*COL_STEP}+{]3*ROW_STEP}
            jsr ConfigDrawString
            <<<

ShowConfig
;            lda #1
;            jsr SetAreaType

            lda #$0000
            stal $E19E00

            lda #0
            jsr ClearScreen

            ldx #0                  ; Config setting index
:loop
            phx
            cpx #0
            beq :video
            cpx #1
            beq :audio
            bra :skip_selector
:video
            _PutTile TILE_SHROOM;2;2;1
            _PutTile TILE_BLANK;2;7;1
            bra :skip_selector
:audio
            _PutTile TILE_SHROOM;2;7;1
            _PutTile TILE_BLANK;2;2;1
            bra :skip_selector

:skip_selector
            lda #2
            _PutStr  VideoTitle;4;2

            ldx VideoMode
            lda GoodPalette,x
            _PutStr  GoodStr;6;4
            ldx VideoMode
            lda BetterPalette,x
            _PutStr  BetterStr;12;4
            ldx VideoMode
            lda BestPalette,x
            _PutStr  BestStr;20;4

            lda #2
            _PutStr  AudioTitle;4;7

            ldx AudioMode
            lda GoodPalette,x
            _PutStr  GoodStr;6;9
            ldx AudioMode
            lda BetterPalette,x
            _PutStr  BetterStr;12;9
            ldx AudioMode
            lda BestPalette,x
            _PutStr  BestStr;20;9

:waitloop
            jsr  _ReadControl
            bit  #PAD_KEY_DOWN
            beq  :waitloop

            plx
            and  #$007F
            cmp  #UP_ARROW
            beq  :decrement
            cmp  #DOWN_ARROW
            beq  :increment
            cmp  #' '
            beq  :toggle
            cmp  #13
            bne  :waitloop
            rts
:toggle
            cpx  #0
            beq  :toggle_video
            lda  AudioMode
            inc
            inc
            cmp  #6
            bcc  *+5
            lda  #0
            sta  AudioMode
            brl  :loop
:toggle_video
            lda  VideoMode
            inc
            inc
            cmp  #6
            bcc  *+5
            lda  #0
            sta  VideoMode
            brl  :loop

:increment
            ldx   #1
            brl   :loop
:decrement  ldx   #0
            brl   :loop

GoodPalette   dw    0,2,2
BetterPalette dw    2,0,2
BestPalette   dw    2,2,0

; X = string pointer
; Y = address

ConfigDrawString
            stx   tmp0
            sty   tmp1
            sta   tmp2
            lda   (tmp0)
            and   #$00FF
            tax
            ldy   #1
:loop
            phx
            phy

            lda   (tmp0),y
            and   #$007F
            cmp   #'A'
            bcc   :not_letter
            sbc   #'A'
            clc
            adc   #TILE_A
            bra   :draw
:not_letter
            cmp   #'0'
            bcc   :skip
            sbc   #'0'
            clc
            adc   #TILE_ZERO
:draw
;            ora   #TILE_USER_BIT
;            pha
;            pei   tmp1
;            pei   tmp2                 ; palette select
;            _GTEDrawTileToScreen       ; call NESTileBlitter

:skip
            lda   tmp1
            clc
            adc   #4
            sta   tmp1

            ply
            plx

            iny
            dex
            bne   :loop
            rts

VideoTitle  str  'VIDEO QUALITY'
AudioTitle  str  'AUDIO QUALITY'
GoodStr     str  'GOOD'
BetterStr   str  'BETTER'
BestStr     str  'BEST'
VOCTitle    str  'ENABLE VOC ACCELERATION'
YesStr      str  'YES'
NoStr       str  'NO'

            put   ../../App.Msg.s
            put   ../../font.s
            put   ../../palette.s
            put   ../../ppu_wip.s

; Palette remapping
            put   palettes.s
            put   ../../apu/apu.s

; Core code
            put   ../../scaffold.s
            put   ../../rom_helpers.s
            put   ../../rom_input.s
            put   ../../rom_exec.s
            put   ../../core/CoreData.s
            put   ../../core/CoreImpl.s
            put   ../../core/ControlBits.s
            put   ../../core/Memory.s
            put   ../../core/Graphics.s
            put   ../../core/Math.s
            put   ../../core/blitter/BlitterLite.s
            put   ../../core/blitter/PEISlammer.s
            put   ../../core/blitter/HorzLite.s
            put   ../../core/blitter/VertLite.s
            put   ../../core/tiles/CompileTile.s

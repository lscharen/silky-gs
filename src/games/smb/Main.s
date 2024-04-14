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

POST_RENDER  mac
             jsr  CheckForPaletteChange
             <<<

; Put in additional conditions to skip sprites when scanning the OAM table to decide what to
; render.  Set the carry flag to keep, clear the carry flag to skip
;
; Input: The accumulator holds the first two OAM bytes (y-position and tile id)
SCAN_OAM_XTRA_FILTER mac
            eor    #$FC00             ; Is the tile == $FC? This is a blank tile in this ROM
            cmp    #$0100
            <<<

; Define which PPU address has the background and sprite tiles
PPU_BG_TILE_ADDR  equ #$1000
PPU_SPR_TILE_ADDR equ #$0000

; Define what kind of execution harness to use
;
; 0 = Reset code drops into an infinite loop
; 1 = Reset code is the game code
ROM_DRIVER_MODE   equ 0

; Flag whether the backend should use the OAMDMA to get the sprite information,
; or if it can scan the NES RAM area directly
;
; 0  = use OAM DMA
; >0 = read $100 bytes directly from NES RAM

DIRECT_OAM_READ   equ 0

; Flag whether to ignore Sprite 0.  Somce games use this sprite only for the 
; special sprite 0 collision behavior, which is not supported in this runtime

ALLOW_SPRITE_0   equ 0

; Flag to turn off interupts.  This will run the ROM code with no sound and
; the frames will be driven sychronously by the event loop.  Useful for debugging.

NO_INTERRUPTS    equ 0

; Define the area of PPU nametable space that will be shown in the IIgs SHR screen
y_offset_rows equ 2
y_height_rows equ 25
y_offset    equ {y_offset_rows*8}
y_height    equ {y_height_rows*8}
min_nes_y   equ 16
max_nes_y   equ min_nes_y+y_height

x_offset    equ   16                      ; number of bytes from the left edge

            phk
            plb

            jsr   NES_StartUp

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

; Apply hacks
;WorldNumber           = $075f
;LevelNumber           = $075c
;AreaNumber            = $0760
;OffScr_WorldNumber    = $0766
;OffScr_AreaNumber     = $0767
;OffScr_LevelNumber    = $0763

; We _never_ scroll vertically, so just set it once.  This is to make sure these kinds of optimizations
; can be set up in the generic structure

            lda   #16
            jsr   _SetBG0YPos
            jsr   _ApplyBG0YPosPreLite
            jsr   _ApplyBG0YPosLite       ; Set up the code field

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
LastAreaType      dw  0
show_vbl_cpu      dw  0
user_break        dw  0

; Helper to initialize the playfield based on the selected VideoMode
InitPlayfield
            lda   #16            ; We render starting at line 16 in the NES video buffer
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
            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
            sta   MinYScroll

            lda   #160           ; 160 lines high for 'better'
            sta   ScreenHeight
            bra   :common

:good
            lda   #16            ; Keep the GTE playfield below the status bar in PPU RAM
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

            ldx   #Area1Palette
            lda   #TmpPalette
            jsr   NES_PaletteToIIgs

            lda   #0
            ldx   #TmpPalette
            jsr   _SetPalette

            rts

; Check the AreaType and see if the palette needs to be changed. We do this after the screen is blitted
; so the palette does not get changed too early while old pixels are still on the screen.

CheckForPaletteChange

            ldal  ROMBase+$074E
            and   #$00FF
            cmp   LastAreaType
            beq   :no_area_change
            sta   LastAreaType
            jsr   SetAreaPalette
:no_area_change
            rts

; Make the screen appear
nesTopOffset    ds 2
nesBottomOffset ds 2
RenderScreen

; Do the basic setup

            sep   #$20
            lda   _ppuctrl                ; Bit 0 is the high bit of the X scroll position
            lsr                           ; put in the carry bit
            lda   _ppuscroll+1             ; load the scroll value
            ror                           ; put the high bit and divide by 2 for the engine
            rep   #$20
            and   #$00FF                  ; make sure nothing is in the high byte
            jsr   _SetBG0XPos

; Now render the top 16 lines to show the status bar area

            clc
            lda   #16*2
            sta   tmp1                    ; virt_line_x2
            lda   #16*2
            sta   tmp2                    ; lines_left_x2
            lda   #0                      ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesTopOffset            ; cache the :exit_offset value returned from this function

; Next render the remaining lines

            lda   #32*2
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

            lda   #16                     ; virt_line
            ldx   #16                     ; lines_left
            ldy   nesTopOffset            ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            lda   ScreenHeight
            sec
            sbc   #16
            tax                           ; lines_left
            lda   #32                     ; virt_line
            ldy   nesBottomOffset         ; offset to patch
            jsr   _RestoreBG0OpcodesAltLite

            stz   LastPatchOffset
            rts

SetDefaultPalette
            lda   #0
SetAreaPalette
            cmp   #5
            bcs   :out

            asl
            tay
            ldx   AreaPalettes,y      ; First parameter to NESColorToIIgs
            phx

            asl
            tay
            lda   SwizzleTables+2,y
            ldx   SwizzleTables,y
            jsr   NES_SetPaletteMap
            
            plx
            lda   #TmpPalette
            jsr   NES_PaletteToIIgs

; Special copy routine; do not touch color indices 0, 1, 14 or 15 -- we let the NES PPU handle those

            ldx   #4
:loop
            lda   TmpPalette,x
            stal  $E19E00,x
            inx
            inx
            cpx   #2*14
            bcc   :loop
:out
            rts

AreaPalettes  dw   WaterPalette,Area1Palette,Area2Palette,Area3Palette,Area2Palette
SwizzleTables adrl AT0_T0,AT1_T0,AT2_T0,AT3_T0,AT2_T0

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
            jsr SetDefaultPalette

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

; Copy just the tiles that change directly to the graphics screen

MemOffsets    dw    67, 68, 69, 70, 71,                        82, 83, 84, 85, 86,  89, 90, 91, 92
              dw    99,100,101,102,103,104,  107,108,109,110,     115,116,117,         122,123,124

ScreenOffsets dw    12, 16, 20, 24, 28,                        72, 76, 80, 84, 88,  100,104,108,112
              dw    ROW_STEP+12,ROW_STEP+16,ROW_STEP+20,ROW_STEP+24,ROW_STEP+28,ROW_STEP+32
              dw    ROW_STEP+44,ROW_STEP+48,ROW_STEP+52,ROW_STEP+56
              dw    ROW_STEP+76,ROW_STEP+80,ROW_STEP+84
              dw    ROW_STEP+104,ROW_STEP+108,ROW_STEP+112

CopyStatusToScreen

            lda   ScreenBase
            sec
            sbc   #160*16
            sta   tmp0

            ldy   #0
:loop
            phy                             ; preserve reg
            ldx   MemOffsets,y
            ldal  PPU_MEM+TILE_SHADOW,x
;            and   #$00FF
;            ora   #$0100+TILE_USER_BIT
;            pha

            lda   ScreenOffsets,y
            clc
            adc   tmp0
;            pha

            lda   #$8002
            cpx   #107                      ; This one is palette 3
            bne   *+5
            ora   #$0001
;            pha
;            _GTEDrawTileToScreen           ; call NESTileBlitter

            ply
            iny
            iny
            cpy   #30*2
            bcc   :loop
            rts

            put   ../../misc/App.Msg.s
            put   ../../misc/font.s
;            put   ../../palette.s
            put   ../../ppu/ppu.s

            ds    \,$00                      ; pad to the next page boundary

; Mapping tables to take a nametable address and return the appropriate attribute memory location.  This is a table with
; 960 entries.  This table is just the 64 offsets above address $2xC0 stored as bytes to keep the table size reasonably
; conpact
PPU_ATTR_ADDR
]row        =     0
            lup   30
            db    $C0+{8*{]row/4}}+0, $C0+{8*{]row/4}}+0, $C0+{8*{]row/4}}+0, $C0+{8*{]row/4}}+0, $C0+{8*{]row/4}}+1, $C0+{8*{]row/4}}+1, $C0+{8*{]row/4}}+1, $C0+{8*{]row/4}}+1,
            db    $C0+{8*{]row/4}}+2, $C0+{8*{]row/4}}+2, $C0+{8*{]row/4}}+2, $C0+{8*{]row/4}}+2, $C0+{8*{]row/4}}+3, $C0+{8*{]row/4}}+3, $C0+{8*{]row/4}}+3, $C0+{8*{]row/4}}+3,
            db    $C0+{8*{]row/4}}+4, $C0+{8*{]row/4}}+4, $C0+{8*{]row/4}}+4, $C0+{8*{]row/4}}+4, $C0+{8*{]row/4}}+5, $C0+{8*{]row/4}}+5, $C0+{8*{]row/4}}+5, $C0+{8*{]row/4}}+5,
            db    $C0+{8*{]row/4}}+6, $C0+{8*{]row/4}}+6, $C0+{8*{]row/4}}+6, $C0+{8*{]row/4}}+6, $C0+{8*{]row/4}}+7, $C0+{8*{]row/4}}+7, $C0+{8*{]row/4}}+7, $C0+{8*{]row/4}}+7,
]row        =     ]row+1
            --^
            
PPU_ATTR_MASK
            lup   7
            db    $03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C
            db    $03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C
            db    $30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0
            db    $30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0,$30,$30,$C0,$C0
            --^
            db    $03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C
            db    $03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C,$03,$03,$0C,$0C

; If AreaStyle is 1 then load an alternate palette 'b'
;
; Palettes of NES color indexes
Area1Palette dw     $22, $00, $29, $1A, $0F, $36, $17, $30, $21, $27, $1A, $16, $00, $00, $16, $18

; Underground
Area2Palette dw     $0F, $00, $29, $1A, $09, $3C, $1C, $30, $21, $17, $27, $36, $16, $1D, $16, $18

; Castle
Area3Palette dw     $0F, $00, $30, $10, $00, $16, $17, $27, $1C, $36, $1D, $00, $00, $00, $16, $18

; Water
WaterPalette dw     $22, $00, $15, $12, $25, $3A, $1A, $0F, $30, $12, $27, $10, $16, $00, $16, $18

; Palette remapping
            put   pal_w11.s
            put   ../../apu/apu.s

; Core code
            put   ../../rom/scaffold.s
            put   ../../rom/rom_helpers.s
            put   ../../rom/rom_input.s
            put   ../../rom/rom_exec.s

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

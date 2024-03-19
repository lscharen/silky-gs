            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   Externals.s
            put   core/Defs.s

            mx    %00

x_offset    equ   16                      ; number of bytes from the left edge

            phk
            plb
            sta   UserId                  ; GS/OS passes the memory manager user ID for the application into the program
            _MTStartUp                    ; Require the miscellaneous toolset to be running
            bcc   *+5
            brl   Fail

            stz   LastAreaType            ; Check if the palettes need to be updates
            stz   ShowFPS
            stz   YOrigin

            lda   #4                      ; Default to "Best" mode
            sta   VideoMode
            sta   AudioMode

            lda   #1
            sta   BGToggle

            lda   #$0008
            sta   LastEnable

            stz   LastStatusUdt

            lda   #1
            sta   ActiveBank

; The next two direct pages will be used by the engine, so get another 2 pages beyond that for the ROM.  We get
; 4K of DP/Stack space by default, so there is plenty to share

            tdc
            sta   DPSave
            clc
            adc   #$300
            sta   ROMZeroPg
            clc
            adc   #$1FF                   ; Stack starts at the top of the page
            sta   ROMStk

; Start up the engine

            jsr   StartUp
            bcc   *+5
            jmp   Fail

; Initialize the PPU 

            jsr   PPUStartUp
            bcc   *+5
            jmp   Fail

; Clear the IIgs screen and initialize the rendering parameters.

            lda   #0
            jsr   ClearScreen
            jsr   InitPlayfield

; Convert the CHR ROM from the cart into GTE tiles

            jsr   LoadTilesFromROM

; Show the configuration screen
;            jsr   ShowConfig

; Set the palettes and swizzle tables

            lda   #1
            jsr   SetAreaType

; Fill the buffer with tiles

            sep   #$20
            ldx   #$2000
            lda   #0
:drawloop
            pha
            phx

            and   #$03
            asl
            stal  PPU_MEM+ATTR_SHADOW,x               ; force palette selection
            lda   3,s

            jsr   DrawPPUTile

            plx
            inx
            pla
            inc
            bne   :drawloop
            rep   #$20

; Render again, just to make sure it works

;            jsr   _ApplyBG0YPosLite       ; Set up the code field
;            jsr   _ApplyBG0XPosLite       ; Set up the code field
;            ldx   #0
;            ldy   #200
;            jsr   _BltRangeLite
;            lda   StartYMod240            ; Restore the fields back to their original state
;            ldx   ScreenHeight
;            jsr   _RestoreBG0OpcodesLite
;            stz   LastPatchOffset

            jsr   RenderScreen
            jsr   WaitForKey

; Start the FPS counter
            ldal  OneSecondCounter
            sta   OldOneSec

; Initialize the sound hardware for APU emulation

            lda   #2
            jsr   APUStartUp              ; 0 = 240Hz, 1 = 120Hz, 2 = 60Hz (external)

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
; Call the boot code in the ROM

            ldx   #ROMReset
            jsr   romxfer

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

EvtLoop
;            jsr   readInput              ; Uncomment if interrupts are off
;            jsr   triggerNMI

            jsr   RenderFrame

;            jsr   RenderScreen
;            jsr   WaitForKey
;            brl   Exit

;            lda   singleStepMode
;            bne   :skip_render
;            jsr   RenderFrame

            lda   ShowFPS
            beq   :no_fps

            ldal  OneSecondCounter
            cmp   OldOneSec
            beq   :skip_render
            sta   OldOneSec
            
            ldx   #0
            ldy   #$FFFF
            lda   frameCount

            jsr   DrawByte
            lda   frameCount
            stz   frameCount
:no_fps
:skip_render

            lda   LastRead
            bit   #PAD_KEY_DOWN
            beq   EvtLoop

            and   #$007F
            pha

; Put the game in single-step mode
;            cmp   #'s'
;            bne   :not_s

;            lda   #1                         ; Stop the VBL interrupt from running the game logic
;            sta   singleStepMode

;            brl   EvtLoop
;:not_s
            pla
            cmp   #'f'
            bne   :not_f
            lda   #1
            eor   ShowFPS
            sta   ShowFPS
            bne   :no_clear
            ldx   #0
            jsr   ClearWord
:no_clear
            brl   EvtLoop
:not_f

            cmp   #'b'                       ; Toggle background flag
            bne   :not_b
            lda   BGToggle
            eor   #$0001
            sta   BGToggle
            jsr   EnableBackground
            brl   EvtLoop
:not_b

            cmp   #'g'                       ; Re-enable VBL-drive game logic
            bne   :not_g
            stz   singleStepMode
            brl   EvtLoop
:not_g

            cmp   #'a'                       ; Show how much time APU simulation is taking
            bne   :not_a
            lda   show_border
            eor   #$0001
            sta   show_border
            brl   EvtLoop
:not_a

            cmp   #'0'
            bne   :not_0
            stz   APU_FORCE_OFF
            brl   EvtLoop
:not_0

            cmp   #'1'
            bne   :not_1
            lda   #$01
            jsr   ToggleAPUChannel
            brl   EvtLoop
:not_1

            cmp   #'2'
            bne   :not_2
            lda   #$02
            jsr   ToggleAPUChannel
            brl   EvtLoop
:not_2

            cmp   #'3'
            bne   :not_3
            lda   #$04
            jsr   ToggleAPUChannel
            brl   EvtLoop
:not_3

            cmp   #'4'
            bne   :not_4
            lda   #$08
            jsr   ToggleAPUChannel
            brl   EvtLoop
:not_4
            cmp   #'t'             ; show VBL interrupt time
            bne   :not_t
            lda   show_vbl_cpu
            eor   #1
            sta   show_vbl_cpu
            brl   EvtLoop
:not_t

            cmp   #'x'             ; break
            bne   :not_x
            lda   #1
            sta   user_break
            brl   EvtLoop
:not_x

            cmp   #'q'
            beq   Exit
            brl   EvtLoop

Exit
            jsr   APUShutDown
            jsr   ShutDown
Quit
            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00
Greyscale   dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF

Fail        brk   $FE

TmpPalette  ds    32

; Program variables
singleStepMode    dw  0
; nmiCount    dw    0
OneSecondCounter  dw  0
OldOneSecVec      ds  4
DPSave            dw  0
LastAreaType      dw  0
frameCount        dw  0
show_vbl_cpu      dw  0
user_break        dw  0

; From the IIgs ref 
DefaultPalette   dw    $0000,$0777,$0841,$072C
                 dw    $000F,$0080,$0F70,$0D00
                 dw    $0FA9,$0FF0,$00E0,$04DF
                 dw    $0DAF,$078F,$0CCC,$0FFF

; Toggle an APU control bit
ToggleAPUChannel
            pha
            lda   #$0001
            stal  APU_FORCE_OFF
            pla

            sep   #$30
            eorl  APU_STATUS
            jsl   APU_STATUS_FORCE
            rep   #$30
            rts

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

; Loop through the tiles and convert them from the NES ROM format into a custom
; internal format.
LoadTilesFromROM

; First loop is to convert the background tiles (tile numbers 256 to 511)

            ldx  #256*16
            ldy  #0

:tloop
            phx
            phy

            lda  #TileBuff
            jsr  ConvertROMTile3

            clc
            pla
            adc  #$0100          ; Put the next compiled tile on the next page
            tay

            pla
            adc  #16             ; NES tiles are 16 bytes
            tax

            cpx  #16*512         ; Have we done the last background tile?
            bcc  :tloop

; Second loop is to convert the sprite tiles (tile numbers 0 to 255)

            ldx  #0
            ldy  #0

:sloop
            phx
            phy

            lda  #TileBuff
            jsr  ConvertROMTile2 ; Convert the tile, extract the mask and create horizontally flipped versions

            ldy  #0              ; Copy the converted tile data into the  tiledata bank
            plx
:cploop
            lda  TileBuff,y
            stal tiledata,x
            iny
            iny
            inx
            inx
            cpy  #128
            bcc  :cploop

            txy
            pla
            clc
            adc  #16             ; NES tiles are 16 bytes
            tax

            cpx  #16*256         ; Have we done the last sprite tile?
            bcc  :sloop
            rts

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
            jsr   NESColorToIIgs

            lda   #0
            ldx   #TmpPalette
            jsr   _SetPalette

            rts

; Helper to perform the essential functions of rendering a frame
RenderFrame

; Apply all of the tile updates that were made during the previous frame(s).  The color attribute bytes are always set
; in the PPUDATA hook, but then the appropriate tiles are queued up.  These tiles, the tiles written to by PPUDATA in
; the range ($2{n+0}00 - $2{n+3}C0)
;
; The queue is set up as a Set, so if the same tile is affected by more than one action, it will only be drawn once.
; Practically, most NES games already try to minimize the number of tiles to update per frame.

            jsr   PPUFlushQueues

; Now that the PEA field is in sync with the PPU Nametable data, we can setup the current frame's sprites.  No
; sprites are actually drawn here, but the PPU OAM memory if scanned and copied into a more efficient internal
; representation.

            jsr   drawOAMSprites

; Finally, render the PEA field to the Super Hires screen.  The performance of the runtime is limited by this
; step and it is important to keep the high-level rendering code generalized so that optimizations, like falling
; back to a dirty-rectangle mode when the NES PPUSCROLL does not change, will be important to support good performance
; in some games -- especially early games that do not use a scrolling playfield.

            jsr   RenderScreen

; Game specific post-render logic
;
; Check the AreaType and see if the palette needs to be changed. We do this after the screen is blitted
; so the palette does not get changed too early while old pixels are still on the screen.

            ldal  ROMBase+$074E
            and   #$00FF
            cmp   LastAreaType
            beq   :no_area_change
            sta   LastAreaType
            jsr   SetAreaType
:no_area_change

            inc   frameCount       ; Tick over to a new frame
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
            lda   #16*2
            sta   tmp1                    ; virt_line_x2
            lda   #16*2
            sta   tmp2                    ; lines_left_x2
            lda   #0                      ; Xmod256
            jsr   _ApplyBG0XPosAltLite
            sta   nesTopOffset            ; cache the :exit_offset value returned form this function

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

SetAreaType
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
            jsr   SetPaletteMap
            
            plx
            lda   #TmpPalette
            jsr   NESColorToIIgs

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
            lda #1
            jsr SetAreaType

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

; Trigger an NMI in the ROM
triggerNMI

; If the audio engine is not running off of its own ESQ interrups at 240Hz or 120Hz, then it must be manually drive
; at 60Hz from the VBL/NMI handler

;            lda   AudioMode
;            bne   :good_audio
            sep   #$30
            jsl   quarter_speed_driver
            rep   #$30
;:good_audio

            ldal  ppuctrl               ; If the ROM has not enabled VBL NMI, also skip
            bit   #$80
            beq   :skip

            ldal  ppustatus             ; Set the bit that the VBL has started
            ora   #$80
            stal  ppustatus

            ldx   #NonMaskableInterrupt
            jsr   romxfer

:skip
            rts

; Expose joypad bits from GTE to the ROM: A-B-Select-Start-Up-Down-Left-Right
native_joy  ENT
            db   0,0

; X = address in the rom file
; A = address to write
;
; This keeps the tile in 2-bit mode in a format that makes it easy to look up pixel data
; based on a dynamic palette selection
;
; Tiles are stored in a pre-shifted, 16-bit format (2 bits per pixel): 0000000w wxxyyzz0
; When rendered, the 2-bit palette selection is passed in bits 9 and 10 and ORed with
; the palette data to create a single word of 00000ppw wxxyyzz0.  This value is used
; to index directly into a 2048-byte swizzel table that will load the appropriate
; pixel data for the word.  There are 2 swizzle tables, one for tiles and one for sprites
; that take care of mapping the 25 possible on-screen colors to a 16-color palette.
ConvertROMTile3
:DPtr       equ   tmp1
:save       equ   tmp2

; This routine is used for background tiles, so there is no need to create masks or
; to provide alternative vertically and horizontally flipped variants.  Instead,
; we leverage this to create optimized, compiled representations of the background tiles

            phy                        ; Save y -- this is the compiled address location to use
            jsr   ROMTileToLookup      ; A = address to write, X = address in CHR ROM

; The :DPtr is set to point at the data buffer, so now convert the lookup values to data nibbles

            sep   #$30                ; 8-bit mode
            ldy   #0
:loop
            lda   (:DPtr),y           ; Load the index for this tile byte
            tax
            lda   DLUT2_shft,x        ; Look up the two, 2-bit pixel values for this quad of bits.  This remains a 4-bit value
            sta   tmp3

            iny
            lda   (:DPtr),y
            tax
            lda   DLUT2,x             ; Look up the two, 2-bit pixel values for next quad of bits
            ora   tmp3                ; Move it int othe top nibble since it will decode to the top-byte on the SHR screen

            dey
            asl
            sta   (:DPtr),y
            iny
            lda   #0
            rol
            sta   (:DPtr),y

            iny
            cpy   #32
            bcc   :loop
            rep    #$30

; Now we have the NES pixel data in a more linear format that matches the IIgs screen

            ply
            lda   #TileBuff
            ldx   #^TileBuff
            jmp   CompileTile

ConvertROMTile2
:DPtr       equ   tmp1
:MPtr       equ   tmp2

            jsr   ROMTileToLookup

; Now we have 32 bytes (4 x 8) with each byte being a 4-bit value that holds two pairs of bits
; from the PPU pattern table.  We use these 4-bit values as lookup indices into tables
; that decode the values differently depending on the use case.

            sta   :DPtr
            clc
            adc   #32                ; Move to the mask
            sta   :MPtr

            lda   #0                 ; Zero out high byte
            sep   #$30               ; 8-bit mode
            ldy   #0

:loop
            lda   (:DPtr),y           ; Load the index for the initial high nibble
            tax
            lda   MLUT4,x             ; Look up the mask value for this byte. This table decodes the 4 bits into an 8-bit mask
            sta   (:MPtr),y

            lda   DLUT2,x             ; Look up the two, 2-bit pixel values for this quad of bits.  This remains a 4-bit value
            asl
            asl
            asl
            asl
            sta   tmp3

            iny
            lda   (:DPtr),y
            tax
            lda   DLUT2,x             ; Look up the two, 2-bit pixel values for next quad of bits
            ora   tmp3                ; Move it into the top nibble since it will decode to the top-byte on the SHR screen

            dey
            sta   (:DPtr),y           ; Put in low byte
            iny
            lda   #0
            sta   (:DPtr),y           ; Zero high byte

            lda   MLUT4,x
            sta   (:MPtr),y

            iny
            cpy   #32
            bcc   :loop

; Reverse and shift the data

            rep    #$30
            ldy    #8
            ldx    :DPtr

:rloop
            lda:   0,x              ; Load the word: xx00
            jsr    reverse2         ; Reverse the bottom byte in chunks of 2 bits
            asl                     ; Shift by 1 for indexing
            sta:   66,x
            asl:   0,x              ; Shift the original word, too

            lda:   2,x
            jsr    reverse2
            asl
            sta:   64,x
            asl:   2,x

            lda:   32,x
            jsr    reverse4
            sta:   98,x
            lda:   34,x
            jsr    reverse4
            sta:   96,x

            inx
            inx
            inx
            inx
            dey
            bne    :rloop
            rts

; X = address in the rom file
; A = address to write

ConvertROMTile
:DPtr        equ   tmp1
:MPtr        equ   tmp2

            jsr   ROMTileToLookup

            sta   :DPtr
            clc
            adc   #32                ; Move to the mask
            sta   :MPtr

            sep   #$30               ; 8-bit mode
            ldy   #0

:loop
            lda   (:DPtr),y           ; Load the index for this tile byte
            tax
            lda   DLUT4,x             ; Look up the two, 4-bit pixel values for this quad of bits
            sta   (:DPtr),y
            lda   MLUT4,x             ; Look up the mask value for this byte
            sta   (:MPtr),y
            iny
            cpy   #32
            bcc   :loop

; Switch back to 16-bit mode and flip the tile data before returning

            rep    #$20
            ldy    #16
            ldx    :DPtr

:rloop
            lda:   0,x
            jsr    reverse4
            sta:   66,x
            lda:   2,x
            jsr    reverse4
            sta:   64,x
            inx
            inx
            inx
            inx
            dey
            bne    :rloop
            rts

; Build a table of index values for the ROM tile data.  The different routines
; can mix and match the lookup table information as they see fit
;
; X = address in the rom file
; A = address to write
;
; For each byte of pattern table memory, we create two bytes in the DPtr with
; a lookup value for the pixels corresponding to bits in that location
;
; Example:
;   Tile 0: $03,$0F,$1F,$1F,$1C,$24,$26,$66, $00,$00,$00,$00,$1F,$3F,$3F,$7F
;
;                                      0,1  2,3  4,5  6,7
;
;   $03 | 00000011 | 00000000 | $00 -> 0000 0000 0000 0011 -> 00 00 05 00 
;   $0F | 00001111 | 00000000 | $00 -> 0000 0000 0011 0011 -> 00 00 55 00
;   $1F | 00011111 | 00000000 | $00 -> 0000 0001 0011 0011 -> 01 00 55 00
;   $1F | 00011111 | 00000000 | $00 -> 0000 0001 0011 0011 -> 01 00 55 00
;   $1C | 00011100 | 00011111 | $1F -> 0000 0101 1111 1100 -> 03 00 FA 00
;   $24 | 00100100 | 00111111 | $3F -> 0000 1110 1101 1100 -> 0E 00 BA 00
;   $26 | 00100110 | 00111111 | $3F -> 0000 1110 1101 1110 -> 0E 00 BE 00
;   $66 | 01100110 | 01111111 | $7F -> 0101 1110 1101 1110 -> 3E 00 BE 00
;
;   
; e.g. Plane 0   = 0101 0001 (LSB)
;      Plane 1   = 1001 0001 (MSB)
;
;      For speed, use a table and convert one pair at a time
;
;      Pair 1 = 1001 -> 1001
;      Pair 2 = 0101 -> 0011
;      Pair 3 = 0000 -> 0000
;      Pair 4 = 0101 -> 0011
;
;      Lookup[0] = 10 01 00 11
;      Lookup[1] = 00 00 00 11
;
;      Tile Data  = 63 00 03 00
;      Pixel Data = 12 03 00 03
            mx   %00
ROMTileToLookup
:DPtr       equ   tmp1
            pha
            phx

            sta   :DPtr
            lda   #0                 ; Clear A and B

            sep   #$20               ; 8-bit mode
            ldy   #0

:loop

; Top two bits from each byte defines the two left-most pixels

            ldal  CHR_ROM,x          ; Load the low bits
            and   #$C0
            lsr
            lsr
            sta   tmp0

            ldal  CHR_ROM+8,x        ; Load the high bits
            and   #$C0
            ora   tmp0
            lsr
            lsr
            lsr
            lsr
            sta   (:DPtr),y          ; First byte
            iny

; Repeat for bits 4 & 5

            ldal  CHR_ROM,x
            and   #$30
            lsr
            lsr
            sta   tmp0

            ldal  CHR_ROM+8,x
            and   #$30
            ora   tmp0
            lsr
            lsr
            sta   (:DPtr),y
            iny

; Repeat for bits 2 & 3

            ldal  CHR_ROM,x
            and   #$0C
            lsr
            lsr
            sta   tmp0

            ldal  CHR_ROM+8,x
            and   #$0C
            ora   tmp0               ; Combine the two and create a lookup value
            sta   (:DPtr),y
            iny

; Repeat for bits 0 & 1

            ldal  CHR_ROM,x          ; Load the high bits
            and   #$03
            sta   tmp0

            ldal  CHR_ROM+8,x
            and   #$03
            asl
            asl
            ora   tmp0                ; Combine the two and create a lookup value
            sta   (:DPtr),y
            iny

            inx
            cpy   #32
            bcc   :loop

            rep    #$20
            plx
            pla
            rts

; Reverse the 2-bit fields in a byte
            mx   %00
reverse2
            php
            sta  tmp0
            stz  tmp1

            sep  #$20

            and  #$C0
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            tsb  tmp1

            lda  tmp0
            and  #$30
            lsr
            lsr
            tsb  tmp1

            lda  tmp0
            and  #$0C
            asl
            asl
            tsb  tmp1

            lda  tmp0
            and  #$03
            asl
            asl
            asl
            asl
            asl
            asl
            ora  tmp1

            plp
            rts

; Reverse the nibbles in a word
            mx   %00
reverse4
            xba
            sta   tmp0
            and   #$0F0F
            asl
            asl
            asl
            asl
            sta   tmp1
            lda   tmp0
            and   #$F0F0
            lsr
            lsr
            lsr
            lsr
            ora   tmp1
            rts

; Look up the 2-bit indexes for the data words
DLUT2       db    $00,$01,$04,$05    ; CHR_ROM[0] = xy, CHR_ROM[8] = 00 -> 0x0y
            db    $02,$03,$06,$07    ; CHR_ROM[0] = xy, CHR_ROM[8] = 01 -> 0x1y
            db    $08,$09,$0C,$0D    ; CHR_ROM[0] = xy, CHR_ROM[8] = 10 ->
            db    $0A,$0B,$0E,$0F    ; CHR_ROM[0] = xy, CHR_ROM[8] = 11

; Shifted version of the table
DLUT2_shft  db    $00,$10,$40,$50    ; CHR_ROM[0] = xy, CHR_ROM[8] = 00 -> 0x0y
            db    $20,$30,$60,$70    ; CHR_ROM[0] = xy, CHR_ROM[8] = 01 -> 0x1y
            db    $80,$90,$C0,$D0    ; CHR_ROM[0] = xy, CHR_ROM[8] = 10 ->
            db    $A0,$B0,$E0,$F0    ; CHR_ROM[0] = xy, CHR_ROM[8] = 11

; Look up the 4-bit indexes for the data words
DLUT4       db    $00,$01,$10,$11    ; CHR_ROM[0] = xx, CHR_ROM[8] = 00
            db    $02,$03,$12,$13    ; CHR_ROM[0] = xx, CHR_ROM[8] = 01
            db    $20,$21,$30,$31    ; CHR_ROM[0] = xx, CHR_ROM[8] = 10
            db    $22,$23,$32,$33    ; CHR_ROM[0] = xx, CHR_ROM[8] = 11

MLUT4       db    $FF,$F0,$0F,$00
            db    $F0,$F0,$00,$00
            db    $0F,$00,$0F,$00
            db    $00,$00,$00,$00

; Inverted mask for using eor/and/eor rendering
;MLUT4       db    $00,$0F,$F0,$FF
;            db    $0F,$0F,$FF,$FF
;            db    $F0,$FF,$F0,$FF
;            db    $FF,$FF,$FF,$FF

; Extracted tiles
TileBuff    ds    128

StartUp
            jsr   PPUResetQueues
            lda   UserId
            jmp   _CoreStartUp

ShutDown
            jmp   _CoreShutDown

* ; Store sprite and tile data as 0000000w wxxyyzz0 to facilitate swizzle loads

* ; sprite high priority (8-bit acc, compiled)
*             ldy   #PPU_DATA
*             lda   screen
*             andl  tilemask,x
*             ora   (palptr),y          ; 512 byte lookup table per palette
*             sta   screen

* ; sprite low (this is just slow) ....
*             lda   screen
*             beq   empty
*             ; do 4 bits to figure out a mask and then


*             bit   #$FF00
*             ...
*             ...
*             ldy   #PPU_DATA
*             lda   (palptr),y
*             eor   screen
*             andl  tilemask,x
*             and   bgmask
*             eor   screen
*             sta   screen

* ; tile
*             ldy   tiledata,x
*             lda   (palptr),y
*             ldy   tmp
*             sta   abs,y


* ; Custom tile renderer that swizzles the tile data based on the PPU attribute tables. This
* ; is more complicate than just combining the palette select bits with the tile index bits
* ; because the NES can have >16 colors on screen at once, we remap the possible colors
* ; onto a smaller set of indices.
* SwizzleTile
*                  tax
* ]line            equ             0
*                  lup             8
*                  ldal            tiledata+{]line*4},x     ; Tile data is 00ww00xx 00yy00zz
*                  ora             metatile                 ; Pre-calculated metatile mask
*                  and             tilemask+{]line*4},x     ; Set any zero indices to actual zero
*                  sta:            $0004+{]line*$1000},y
*                  ldal            tiledata+{]line*4}+2,x
*                  sta:            $0001+{]line*$1000},y
* ]line            equ             ]line+1
*                  --^
*                  plb
*                  rts



; Transfer control to the ROM.  This function is trampoline that is responsible for
; setting up the direct page and stack for the ROM and then passing control into
; the ROM wrapped in a JSL/RTL vector stashed in the ROM space.
;
; X = ROM Address
romxfer     phb                             ; Save the bank and direct page
            phd
            tsc
            sta   StkSave+1                 ; Save the current stack in the main program
            pea   #^ExtIn                   ; Set the bank to the ROM
            plb

            lda   ROMStk                    ; Set the ROM stack address
            tcs
            lda   ROMZeroPg                 ; Set the ROM zero page
            tcd

            jml   ExtIn
ExtRtn      ENT
            tsx                             ; Copy the stack address returned by the emulator
StkSave     lda   #$0000
            tcs

            pld
            plb
            stx   ROMStk                    ; Keep an updated copy of the stack address
            rts

nmiTask
            mx    %11
            php
            rep   #$30
            phb
            phd

            phk
            plb
            lda   DPSave
            tcd

            jsr   readInput

            ldal  singleStepMode
            bne   :no_nmi

            ldal  show_vbl_cpu
            beq   :no_show_1
;            jsr   incborder
:no_show_1

            jsr   triggerNMI

            ldal  show_vbl_cpu
            beq   :no_nmi
;            jsr   decborder

:no_nmi
            pld
            plb
            plp
:skip
            rtl
            mx    %00



readInput
            jsr   _ReadControl
            sta   LastRead

; Map the GTE field to the NES controller format: A-B-Select-Start-Up-Down-Left-Right

            pha
            and   #PAD_BUTTON_A+PAD_BUTTON_B        ; bits 0x200 and 0x100
            lsr
            lsr
            sta  native_joy

            sep   #$20
            lda   1,s
            cmp   #9           ; TAB, was 'n' mapped to Select
            bne   *+6
            lda   #$20
            bra   :nes_merge
            cmp   #13          ; RETURN, was 'm' mapped to Start
            bne   *+6
            lda   #$10
            bra   :nes_merge
            cmp   #UP_ARROW
            bne   *+6
            lda   #$08
            bra   :nes_merge
            cmp   #DOWN_ARROW
            bne   *+6
            lda   #$04
            bra   :nes_merge
            cmp   #LEFT_ARROW
            bne   *+6
            lda   #$02
            bra   :nes_merge
            cmp   #RIGHT_ARROW
            bne   *+6
            lda   #$01
            bra   :nes_merge
            lda   #0
:nes_merge  ora  native_joy 
            sta  native_joy
            sta  native_joy+1

:nes_done
            rep   #$20
            pla
            rts

            put   App.Msg.s
            put   font.s
            put   palette.s
            put   ppu_wip.s

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
            put   apu/apu.s

; Core code
            put   core/CoreData.s
            put   core/CoreImpl.s
            put   core/ControlBits.s
            put   core/Memory.s
            put   core/Graphics.s
            put   core/Math.s
            put   core/blitter/BlitterLite.s
            put   core/blitter/PEISlammer.s
            put   core/blitter/HorzLite.s
            put   core/blitter/VertLite.s
            put   core/tiles/CompileTile.s


; Fixed tile
; Bank is set, X = tile corner, A = palette select in bits 9 and 10: 00000ppw wxxyyzz0
Tile1
            ora  #%0000_0000_1010_1010
            bra  TileConst
Tile0
TileConst
            tay
            lda   [SwizzlePtr],y
            sta:  $001,x
            sta:  $004,x
            sta:  $201,x
            sta:  $204,x
            sta:  $401,x
            sta:  $404,x
            sta:  $601,x
            sta:  $604,x
            sta:  $801,x
            sta:  $804,x
            sta:  $A01,x
            sta:  $A04,x
            sta:  $C01,x
            sta:  $C04,x
            sta:  $E01,x
            sta:  $E04,x
            rts

; Compiled Tile template
; Bank is set, X = tile corner, A = palette select in bits 9 and 10: 00000ppw wxxyyzz0
; Swizzle Ptr is aligned to a 2048-byte boundary
;DrawTile
;            sta   SwizzlePtr
;            ldy   #DATA             ; %0000_000w_wxxy_yzz0

;            lda   #MASK
;            and:  $001,x
;            ora   [SwizzlePtr],y
;            sta:  $001,x

;            lda   #MASK             ; Skip ldy for repeating data
;            and:  $004,x
;            ora   [SwizzlePtr],y
;            sta:  $004,x

;            ldy   #DATA             ; No mask for solid words
;            lda   [SwizzlePtr],y
;            sta:  $201,x
;            sta:  $204,x            ; Repeat solid, unmasked values
;            sta:  $401,x
;            sta:  $404,x
;            rts

; Compiles sprites for "normal" sprites -- have a fallback routine for sprites that
; cross the nametable boundary
; CompiledSpriteTemplate
;            sta   SwizzlePtr

;            ldy   #DATA             ; No mask for solid words
;            lda:  $201,x
;            pha                     ; stash the data
;            lda   [SwizzlePtr],y
;            sta:  $201,x

;            ldy   #DATA 
;            lda:  $204,x
;            pha
;            and   #MASK
;            ora   [SwizzlePtr],y
;            sta:  $001,x

;            pea   %1101_1100_0011_111           ; push bitfield of which words to restore (expect sprites to be dense)

* ; and  #MASK                ; 3
* ; ora  [USER_FREE_SPACE],y  ; 7 lookup and merge in swizzled tile data = *(SwizzlePtr + palbits)
* ; sta: 0,x                  ; 6 = 25 cycles / word; 13 bytes
            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   Externals.s
            use   GTE.Macs.s
            use   core/Defs.s

            mx    %00

x_offset    equ   8                       ; number of bytes from the left edge

            phk
            plb
            sta   UserId                  ; GS/OS passes the memory manager user ID for the application into the program
            _MTStartUp                    ; Require the miscellaneous toolset to be running
            bcc   *+5
            brl   Fail

;            stz   LastScroll
;            stz   TileX
;            stz   TileY
;            stz   ROMScreenEdge
;            stz   ROMScrollEdge
;            stz   ROMScrollDelta
;            stz   OldROMScrollEdge
            stz   LastAreaType
            stz   ShowFPS
            stz   YOrigin

            stz   VideoMode
            stz   AudioMode

            lda   #1
            sta   BGToggle

            lda   #$0008
            sta   LastEnable

            stz   LastStatusUdt

            lda   #1
            sta   ActiveBank

;            lda   #$6000                 ; Stack at $00/6000 to save graphics data when drawing sprites
;            sta   SpriteStack

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

; Install a custom sprite renderer that will read directly off of the OAM table
;            pea   extSpriteRenderer
;            pea   #^drawOAMSprites
;            pea   #drawOAMSprites
;            pea   #^nesRenderWithVOC
;            pea   #nesRenderWithVOC
;            _GTESetAddress

; Install a custom callback to update the tile store as the screen scrolls
;            pea   extBG0TileUpdate
;            pea   #^UpdateFromPPU
;            pea   #UpdateFromPPU
;            _GTESetAddress

; Install a custom tile blitter to merge PPU attributes with the extracted tile data
;            pea   userTileCallback
;            pea   #^NESTileBlitter
;            pea   #NESTileBlitter
;            _GTESetAddress

; Install a custom tile callback to draw tiles directly on the screen w/proper palettes
;            pea   userTileDirectCallback
;            pea   #^NESDirectTileBlitter
;            pea   #NESDirectTileBlitter
;            _GTESetAddress

;            pea   #liteBlitter
;            _GTEGetAddress                  ; Need the bank that the lite blitter is in
;            pla
;            pla
;            sta   LiteBank

; Convert the CHR ROM from the cart into GTE tiles

            jsr   LoadTilesFromROM

; Set the palettes and swizzle tables

            lda   #1
            jsr   SetAreaType

; Fill the buffer with tiles

            ldx   #0
            ldy   #0
            lda   #0
:drawloop
            pha
            phx
            phy
            jsr   DrawCompiledTile

            clc
            pla
            adc   #$0100
            tay

            pla
            inc
            bit   #32
            beq   :drawloop1
            clc
            adc   #$0100
            and   #$FF00
:drawloop1  tax

            pla
            adc   #$0200
            and   #$0600

            cpy   #0
            bne   :drawloop

            lda   #0
            jsr   _SetBG0XPos
            lda   #0
            jsr   _SetBG0YPos

            jsr   _ApplyBG0YPosLite       ; Set up the code field
            jsr   _ApplyBG0XPosLite       ; Set up the code field
            ldx   #0
            ldy   #200
            jsr   _BltRangeLite

            jsr   WaitForKey
            brl   Exit

; Start the FPS counter
            ldal  OneSecondCounter
            sta   OldOneSec

; Show the configuration screen
            jsr   ShowConfig
            lda   #0
            jsr   ClearScreen
            jsr   InitPlayfield

; Initialize the sound hardware for APU emulation

            lda   #4
            sec
            sbc   AudioMode               ; 0 = good, 2 = better, 4 = best
            lsr 
            jsr   APUStartUp              ; 0 = 240Hz, 1 = 120Hz, 2 = 60Hz (external)

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
; Call the boot code in the ROM

            ldx   #SMBStart
            jsr   romxfer

; Apply hacks
;WorldNumber                 =     $075f
;LevelNumber                 =     $075c
;AreaNumber                  =     $0760
;OffScr_WorldNumber    = $0766
;OffScr_AreaNumber     = $0767
;OffScr_LevelNumber    = $0763

EvtLoop
;            sep   #$20
;            lda   #0
;            stal  ROMBase+$075f
;            stal  ROMBase+$0766

;            lda   #3
;            stal  ROMBase+$0763
;            stal  ROMBase+$075c

;            lda   #4
;            stal  ROMBase+$0767
;            stal  ROMBase+$0760
;            rep   #$30

; The GTE playfield is 41 tiles wide, but the NES is 32 tiles wide.  Fortunately, the game
; keeps track of the global coordinates of each level at
;
; ScreenEdge_PageLoc          =     $071a
; ScreenEdge_X_Pos            =     $071c
;
; So we can keep our scrolling in sync with the game.  In order to efficiently update the
; GTE tile store, we handle this in two stages
;
; 1. When new column(s) are exposed, set the tiles directly from the PPU nametable memory
; 2. When the PPU nametable memory is updated in an area that is already on-screen, set the tile

            lda   singleStepMode
            bne   :skip_render
            jsr   RenderFrame

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

            lda   lastKey

            bit   #PAD_KEY_DOWN
            beq   EvtLoop

            and   #$007F

; Put the game in single-step mode
            cmp   #'s'
            bne   :not_s

            lda   #1                         ; Stop the VBL interrupt from running the game logic
            sta   singleStepMode

            jsr   triggerNMI
            jsr   RenderFrame
            brl   EvtLoop
:not_s

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

            cmp   #'r'               ; Refresh
            bne   :not_r
            jsr   CopyStatus

;            lda   ROMScreenEdge      ; global tile index
;            and   #$003F             ; mod the mirrored nametable size
;            ldx   #33
;            ldy   #0
;            jsr   CopyNametable
;            brl   EvtLoop
:not_r

            cmp   #'v'
            bne   :not_v
;            lda   ROMScreenEdge
;            clc
;            adc   #33
;            and   #$003F
;            ldx   #1
;            ldy   #33
;            jsr   CopyNametable
            brl   EvtLoop
:not_v
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

            jsr   APUShutDown

Exit
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

mytile      db    $00,$11,$00,$22
            db    $11,$00,$22,$00
            db    $00,$33,$00,$44
            db    $11,$00,$22,$00
            db    $00,$55,$00,$66
            db    $11,$00,$22,$00
            db    $00,$77,$00,$88
            db    $11,$00,$22,$00


TmpPalette  ds    32

; Program variables
lastKey           dw  0
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
            rts

; Helper to initialize the GTE playfield based on the selected VideoMode
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
            jsr   _SetScreenMode

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

; Get the current global coordinates

            sei
;            lda   nt_queue_end      ; Freeze the end of the queue that contains updates up until "now"
;            sta   CurrNTQueueEnd
;            lda   ROMScrollEdge     ; This is set in the VBL IRQ
;            sta   CurrScrollEdge    ; Freeze it, then we can let the IRQs continue
            cli

            lsr
            lsr
            lsr
;            sta   ROMScreenEdge

; Calculate how many blocks have been scrolled into view

;            lda   CurrScrollEdge
;            sec
;            sbc   OldROMScrollEdge
;            sta   tmp1             ; This is the raw number of pixels moved

;            lda   OldROMScrollEdge ; This is the number of partial pixels the old scroll position occupied
;            and   #7
;            sta   tmp0
;            lda   #7
;            sec
;            sbc   tmp0             ; This account for situations where going from 8 -> 9 reveals a new column
;            clc
;            adc   tmp1
;            lsr
;            lsr
;            lsr
;            sta   ROMScrollDelta   ; This many columns have been revealed

;            lda   CurrScrollEdge
;            sta   OldROMScrollEdge ; Stash a copy for the next round through
;            lsr
;            pha

; Get the player's Y coordinate and determine of we need to adjust the camera based on the physical play field size
            ldx   ROMZeroPg
            ldal  $0000b5,x      ; Player_Y_Page      ; 0 = above screen, 1 = on screen, 2 = below
            and   #$00FF
            beq   :max_clamp
            cmp   #2
            beq   :min_clamp

            ldal  $0000ce,x      ; Player_Y_Position
            and   #$00FF

; The "full screen" size is 200 lines that cover NES rows 16 through 216.  If the
; size of the playfield is less, then we adjust the origin a bit.
;
; The goal is to only scroll up once the player is in the top third
; of the screen.  It's better to keep an eye on the ground when jumping
; 
; Y_Origin = min(200 - ScreenHeight, max(0, ROMPlayerY - NesTop))

            sec
            sbc   NesTop
            bmi   :max_neg
            cmp   MinYScroll
            bcc   :max_clamp

            cmp   MaxYScroll
            bcc   :set_y
:min_clamp  lda   MaxYScroll
            bra   :set_y
:max_neg
:max_clamp
            lda   MinYScroll
:set_y
            sta   YOrigin
;            pha
;            _GTESetBG0Origin

;            lda   ppumask
;            and   #$0008     ; Isolate background enable/disable bit
;            cmp   LastEnable
;            beq   :bghop
;            sta   LastEnable
;            jsr   EnableBackground
;:bghop

            lda   VideoMode
            cmp   #4
            beq   :full_screen

; Pull in _RenderNES anad _RenderNES2 functions
;
;            pea   $FFFD             ; Render just the playfield area
;            _GTERender

            lda   frameCount        ; Update the status area once every 8 renders ~1 time per second
            sec
            sbc   LastStatusUdt
            cmp   #8
            bcc   :render_done
            lda   frameCount
            sta   LastStatusUdt
            jsr   CopyStatusToScreen
            bra   :render_done

:full_screen
; Pull in _RenderNES anad _RenderNES2 functions
;
;            pea   $FFFF             ; Render the fixed status bar and playfield
;            _GTERender
:render_done

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

SetAreaType
            cmp   #5
            bcs   :out

            asl
            tay
            ldx   AreaPalettes,y      ; First parameter to NESColorToIIgs

            asl
            tay
            lda   SwizzleTables,y
            sta   SwizzlePtr
            lda   SwizzleTables+2,y
            sta   SwizzlePtr+2

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
;SwizzlePtr    adrl AT1_T0

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

; Take a PPU address and convert it to a tile store coordinate
;
; Inputs
;   A = PPU address
;   X = Global Address in GTE bytes

; Outputs
;   X = relative tile store column
;   Y = relative tile store row
PPUAddrToTileStore
:PPUAddr    equ   tmp0
:PPUTopLeft equ   tmp1

            sta   :PPUAddr

; Based on the global coordiate, figure out whhat the left column in the PPU RAM is
            txa
            lsr                        ; Convert from bytes to tiles
            lsr
            and   #$003F               ; Logically there are 64 tiles in the mirrored PPU RAM
            sta   :PPUTopLeft

; Now we have the PPU address of the column that corresponds to the left edge of the GTE
; playfield.  Now, calculate the relative coordinates of the passed PPU address

; The y-coordinate is easy. Since the top-left address is always on the top row (row = 0),
; we just have to extract the row that the PPU address occupies.

            lda   :PPUAddr
            and   #$03E0               ; Take the middle 5 bits (ignore nametable)
            lsr
            lsr
            lsr
            lsr
            lsr
            tay                        ; Save the y-index here

; The GTE playfield is positioned with the third PPU row as it's origin and is 25 tiles high.
; If the PPU tile is in rows 0, 1, 27, 28 or 29 then we can ignore it

            cpy  #2
            bcc  :outOfRange
            cpy  #27
            bcs  :outOfRange

; Adjust the relative position down by 2

            dey
            dey

; The horizontal coordinate is a bit trickier. We need to add 32 to the horizontal
; coordinate in it's in the second nametable

            lda   :PPUAddr
            and   #$041F               ; Project it to the top row
            bit   #$0400
            beq   *+5
            ora   #$0020               ; Add 32
            and   #$003F               ; Clamp to range of 0 - 63

; If we're in the top two row, they don't scroll, so skip the displacement
            cpy   #2
            bcc   :noshift
 
; Now calculate the difference between the PPUTopLeft index and this value

            cmp   :PPUTopLeft
            bcs   :ahead               ; If the provided address is > than the origin, just calc the difference
            adc   #64                  ; Else distance is (a - 0) + (64 - b) = a + 64 - b
            sec
:ahead      sbc   :PPUTopLeft
:noshift

; If this value is larger than the payfield + 1, then we have the carry set or clear

            tax
            cmp   #33
            rts

:outOfRange
            sec
            rts

:set_tile
; Now we have the relative position from the left edge of the tile.  Add the origin
; tile to it (unless we're in rows 0 or 1)

            txa
            cpy   #2
            bcc   :toprow
            clc
;            adc   TileX
;            cmp   #41
            bcc   *+5
            sbc   #41
:toprow
            pha                             ; Tile Store horizontal tile coordinate
            phy                             ; No translation needed for y

            ldx   :PPUAddr
            lda   PPU_MEM,x
;            and   #$00FF
;            ora   #$0100+TILE_USER_BIT
            pha
            jsr   GetPaletteSelect
            ora   1,s                      ; Merge bits 9 and 10 into the Tile ID that's on the stack
            sta   1,s

; NOTE: Better to draw this into the PEA field directly.  Calling GTESetTile queues up the tile and can cause
;       issues because many frames can pass before Render gets control again.  We need to expose a 
;       _SetTileImmediate function in the list of function callbacks....

; The PPU memeory *is* our backing store -- so just call NESRenderTile
;            _GTESetTileImmediate
;            _GTESetTile
;            inc   :Count
;            brl   :skip


; Do the calculation to get the palette select bits from the attribute byte that corresponds to the
; PPU address in the x-registers
GetPaletteSelect

; Get the palette select bits.  We need to calculate both the address of the attribute value and 
; which bits to isolate from the byte and then merge into the TileId.  The most straighforward way
; is to identify the quadrant right away and have alternate code paths

            txa
            and   #$2C00
            ora   #$23C0                   ; Make sure to put the addr in the $2xxx range
            sta   tmp6                     ; Base attribute table address

; Not calculate the byte within the attribute table

            txa
            and   #$001F                   ; 32 byte rows, divide by 4
            lsr
            lsr
            ora   tmp6
            sta   tmp6

            txa
            and   #$0380                   ; Isolate the top 3 bits
            lsr
            lsr
            lsr
            lsr
            ora   tmp6
            tay

            lda   PPU_MEM,y                ; This is the attribute byte
            and   #$00FF
            pha                            ; Which we save for a minute

; Now figure out the quadrant that this address is in for the attribute byte value

            txa
            bit  #%01000010
            beq  :top_left
            bit  #%01000000
            beq  :top_right
            bit  #%00000010
            beq  :bot_left

:bot_right
            pla
            and  #$00C0
            asl
            asl
            asl
            bra  :set_palette

:bot_left
            pla
            and  #$0030
            xba
            lsr
            lsr
            lsr
            bra  :set_palette

:top_right
            pla
            and  #$000C
            xba
            lsr
            bra  :set_palette

:top_left
            pla
            and  #$0003
            xba
            asl

:set_palette
            rts

; Copy the necessary columns into the TileStore when setting a new scroll position
UpdateFromPPU
:StartXMod164 equ   36

            phb
            phd

; Snag the StartXmod164 value from the GTE direct page so we can calulate the tile origin
; ourselves

            ldx  :StartXMod164

            phk
            plb
            lda   DPSave
            tcd

            txa
            lsr
            lsr
;            sta   TileX              ; Tile column of playfield origin

; Debug the PPU writes

*             ldy   #0
*             ldx   #0
*             lda   #0
* :log_loop
*             phy
*             pha

*             cpy   ppu_write_log_len
*             bcc   :write_val

*             pha
*             tax
*             ldy   #$FFFF
*             jsr   ClearWord

*             pla
*             clc
*             adc   #160-16
*             tax
*             jsr   ClearWord

*             bra   :next

* :write_val
*             pha
*             phy

*             tax
*             lda   ppu_write_log,y
*             ldy   #$FFFF
*             jsr   DrawWord

*             ply
*             pla
*             clc
*             adc   #160-16
*             tax
*             lda   ppu_write_log+50,y
*             ldy   #$FFFF
*             jsr   DrawWord

* :next       pla
*             ply

*             iny
*             iny

*             clc
*             adc   #8*160

*             cpy   #50
*             bcc   :log_loop

*             stz   ppu_write_log_len

; Show the queue depth

;            lda   CurrNTQueueEnd
;            sec
;            sbc   nt_queue_front
;            bpl   *+5
;            adc   #NT_QUEUE_SIZE
;            lsr                      ; Number of items in the queue
;            ldx   #0
;            ldy   #$FFFF
;            jsr   DrawWord

; Check the scroll delta, if it's negative or just large enough, do a whole copy of the current PPU
; memory into the TileStore

;            lda   ROMScrollDelta
;            beq   :queue

            cmp   #32
            bcc   :partial

;            jsr   ClearNTQueue       ; kill any pending updates
;            lda   ROMScreenEdge      ; global tile index
;            and   #$003F             ; mod the mirrored nametable size
;            ldx   #33                ; do the full width
;            ldy   #0
;            jsr   CopyNametable
            bra   :done

; Calculate the difference between the old and new
:partial
;            jsr   DrainNTQueue

;            lda   #33
;            sec
;            sbc   ROMScrollDelta
;            tay

;            ldx   ROMScrollDelta
;            inx
;            inx

;            lda   ROMScreenEdge
;            clc
;            adc   #33
;            sec
;            sbc   ROMScrollDelta
;            and   #$003F

;            jsr   CopyNametable
:done
            pld
            plb
            rtl

; Just drain the queue of any on-screen changes and then exit
:queue
;            jsr   DrainNTQueue
            pld
            plb
            rtl

CopyStatus
; Copy the first two rows from $2400 because they don't scroll

            ldy   #0
:yloop
            ldx   #0
            tya
            clc
            adc   #2
            asl
            asl
            asl
            asl
            asl
            sta   tmp2
            stz   tmp3
:xloop
            phx                            ; Save X and Y
            phy

;            phx                            ; x = GTE tile index = PPU tile index
;            phy                            ; No vertical scroll, so screen_y = tile_y

            ldx   tmp2                     ; Nametable address
            lda   PPU_MEM+$2000,x
;            and   #$00FF
;            ora   #$0100+TILE_USER_BIT
;            pha
            jsr   GetPaletteSelect
;            ora   1,s                      ; Merge bits 9 and 10 into the Tile ID that's on the stack
;            sta   1,s

; Advance to the next tile (no wrapping needed)

            inx
            stx   tmp2

; The PPU memeory *is* our backing store -- so just call NESRenderTile
;            _GTESetTileImmediate

            ply
            plx

            inx
            cpx   #33
            bcc   :xloop

            iny
            cpy   #2
            bcc   :yloop
            rts

; Copy just the tiles that change directly tothe graphics screen

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

            ldx   #0
:loop
            phx                             ; preserve x
            ldy   MemOffsets,x
            lda   PPU_MEM+$2000,y
;            and   #$00FF
;            ora   #$0100+TILE_USER_BIT
;            pha

            lda   ScreenOffsets,x
            clc
            adc   tmp0
;            pha

            lda   #$8002
            cpy   #107                      ; This one is palette 3
            bne   *+5
            ora   #$0001
;            pha
;            _GTEDrawTileToScreen           ; call NESTileBlitter

            plx
            inx
            inx
            cpx   #30*2
            bcc   :loop
            rts

; Copy the tile and attribute bytes into the GTE buffer
;
; A = logical column in mirrored PPU memory (0 - 63)
; X = number of columns to copy
; Y = number of GTE tiles to offset
CopyNametable
            sta   tmp2
            bit   #$0020                  ; Is it >32?
            beq   *+5
            ora   #$0400                  ; Move to the next nametable
            and   #$041F                  ; Mask to the top of a valid column

            clc                           ; Add in the offset since we only copy rows 2 - 27
            adc   #4*32
            sta   tmp0                    ; base address offset into nametable memory

            stx   tmp4

            tya
            clc
;            adc   TileX
            cmp   #41
            bcc   *+5
            sbc   #41
            sta   tmp5

; NES RAM $6D = page, $86 = player_x_in_page can be used to get a global position in the level, then subtracting the 
; player's x coordinate will give us the global coordinate of the left edge of the screen and allow us to map between
; the GTE tile buffer and the PPU nametables

; Skip the first two rows -- call CopyStatus to get those

            ldy   #2
:yloop
            ldx   #0

            lda   tmp0                    ; Get the base address for this row
            sta   tmp2                    ; coarse x-scroll

            lda   tmp5
            sta   tmp3                    ; Keep a separate variable for the GTE tile position
:xloop
            phx                            ; Save X and Y
            phy

;            pei   tmp3                     ; Wrap-around tile column
;            phy                            ; No vertical scroll, so screen_y = tile_y

            ldx   tmp2                     ; Nametable address
            lda   PPU_MEM+$2000,x
;            and   #$00FF
;            ora   #$0100+TILE_USER_BIT     ; Use top 256 tiles and set as a user-defined tile
;            pha
            jsr   GetPaletteSelect
;            ora   1,s                      ; Merge bits 9 and 10 into the Tile ID that's on the stack
;            sta   1,s

; Advance to the next tile (handle nametable wrapping)

            lda   #$001F
            and   tmp2
            cmp   #$001F
            bne   :inc_x
            txa
            and   #$FFE0
            eor   #$0400
            sta   tmp2
            bra   :x_hop

:inc_x      inx
            stx   tmp2
:x_hop

;            _GTESetTile

; The PPU memeory *is* our backing store -- so just call NESRenderTile
;            _GTESetTileImmediate

            ply
            plx

            lda   tmp3
            inc
            cmp   #41
            bcc   *+5
            lda   #0
            sta   tmp3

            inx
            cpx   tmp4
            bcc   :xloop

            lda   tmp0
            clc
            adc   #32
            sta   tmp0

            iny
            cpy   #25
            bcc   :yloop

            rts

; Trigger an NMI in the ROM
triggerNMI
            lda   AudioMode
            bne   :good_audio
            sep   #$30
            jsl   quarter_speed_driver
            rep   #$30
:good_audio

;            ldal  ppuctrl               ; If the ROM has not enabled VBL NMI, also skip
;            bit   #$80
;            beq   :skip

;            ldal  ppustatus             ; Set the bit that the VBL has started
;            ora   #$80
;            stal  ppustatus

            ldx   #NonMaskableInterrupt
            jsr   romxfer

; Immediately after the NMI returns, freeze some of the global state variables so we can sync up with this frame when
; we render the next frame.  Since we're in an interrupt handler here, sno change of the variables changing under
; our nose

            sep   #$20
            ldal  ROMBase+$071a
            xba
            ldal  ROMBase+$071c
            rep   #$20
;            sta   ROMScrollEdge

:skip       rts

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
            lda   DLUT2_shft,x       ; Look up the two, 2-bit pixel values for this quad of bits.  This remains a 4-bit value
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
            ora   tmp3                ; Move it int othe top nibble since it will decode to the top-byte on the SHR screen

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

            lda   CHR_ROM,x          ; Load the low bits
            and   #$C0
            lsr
            lsr
            sta   tmp0

            lda   CHR_ROM+8,x        ; Load the high bits
            and   #$C0
            ora   tmp0
            lsr
            lsr
            lsr
            lsr
            sta   (:DPtr),y          ; First byte
            iny

; Repeat for bits 4 & 5

            lda   CHR_ROM,x
            and   #$30
            lsr
            lsr
            sta   tmp0

            lda   CHR_ROM+8,x
            and   #$30
            ora   tmp0
            lsr
            lsr
            sta   (:DPtr),y
            iny

; Repeat for bits 2 & 3

            lda   CHR_ROM,x
            and   #$0C
            lsr
            lsr
            sta   tmp0

            lda   CHR_ROM+8,x
            and   #$0C
            ora   tmp0               ; Combine the two and create a lookup value
            sta   (:DPtr),y
            iny

; Repeat for bits 0 & 1

            lda   CHR_ROM,x          ; Load the high bits
            and   #$03
            sta   tmp0

            lda   CHR_ROM+8,x
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

; X, Y
SetBG0Origin
            phy
            txa
            jsr     _SetBG0XPos
            pla
            jmp     _SetBG0YPos

StartUp
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

; VBL Interrupt task (called in native 8-bit mode directly from the interrupt handler)
            mx    %11
nmiTask
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
            stal  lastKey                          ; Cache for other code

; Map the GTE field to the NES controller format: A-B-Select-Start-Up-Down-Left-Right

            pha
            and   #PAD_BUTTON_A+PAD_BUTTON_B        ; bits 0x200 and 0x100
            lsr
            lsr
            sta  native_joy

            sep   #$20
            lda   1,s
            cmp   #9           ; TAB, was 'n'
            bne   *+6
            lda   #$20
            bra   :nes_merge
            cmp   #13          ; RETURN, was 'm'
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
PPU_MEM
CHR_ROM     put   chr2.s         ; 8K of CHR-ROM at PPU memory $0000 - $2000
PPU_NT      ds    $2000          ; Nametable memory from $2000 - $3000, $3F00 - $3F14 is palette RAM
PPU_OAM     ds    256            ; 256 bytes of separate OAM RAM

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
DrawTile
            sta   SwizzlePtr
;            ldy   #DATA             ; %0000_000w_wxxy_yzz0

;            lda   #MASK
            and:  $001,x
            ora   [SwizzlePtr],y
            sta:  $001,x

;            lda   #MASK             ; Skip ldy for repeating data
            and:  $004,x
            ora   [SwizzlePtr],y
            sta:  $004,x

;            ldy   #DATA             ; No mask for solid words
            lda   [SwizzlePtr],y
            sta:  $201,x
            sta:  $204,x            ; Repeat solid, unmasked values
            sta:  $401,x
            sta:  $404,x
            rts

; Compiles sprites for "normal" sprites -- have a fallback routine for sprites that
; cross the nametable boundary
CompiledSpriteTemplate
            sta   SwizzlePtr

;            ldy   #DATA             ; No mask for solid words
            lda:  $201,x
            pha                     ; stash the data
            lda   [SwizzlePtr],y
            sta:  $201,x

;            ldy   #DATA 
            lda:  $204,x
            pha
;            and   #MASK
            ora   [SwizzlePtr],y
            sta:  $001,x

            pea   %1101_1100_0011_111           ; push bitfield of which words to restore (expect sprites to be dense)

* ; and  #MASK                ; 3
* ; ora  [USER_FREE_SPACE],y  ; 7 lookup and merge in swizzled tile data = *(SwizzlePtr + palbits)
* ; sta: 0,x                  ; 6 = 25 cycles / word; 13 bytes
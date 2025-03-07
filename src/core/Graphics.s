
; Graphic screen initialization
InitGraphics
                 jsr   _ShadowOn
                 jsr   _GrafOn

; Clear the SCBs and Palettes

                 ldx   #$2FE
                 lda   #0
:lp              stal  $E19D00,x
                 dex
                 dex
                 bpl   :lp

                 ldx   #2                    ; NES screen size
                 jsr   _SetScreenMode        ; Calls SetScreenRect

; Put some different colors into palette index 0 for the 16 palettes in case scanline debugging is turned on

                  ldx       #0
                  txy
:scb_loop
                  lda       SystemPalette,y
                  stal      $E19E00,x
                  iny
                  iny
                  txa
                  clc
                  adc       #32
                  tax
                  cpx       #512
                  bcc       :scb_loop

                 clc
                 rts

; From the IIgs ref 
SystemPalette   dw    $0000,$0777,$0841,$072C
                dw    $000F,$0080,$0F70,$0D00
                dw    $0FA9,$0FF0,$00E0,$04DF
                dw    $0DAF,$078F,$0CCC,$0FFF

; Allow the user to dynamically select one of the pre-configured screen sizes, or pass
; in a specific width and height.  The screen is automatically centered.  If this is
; not desired, then SetScreenRect should be used directly
;
;  0. Full Screen           : 40 x 25   320 x 200 (32,000 bytes (100.0%)) 
;  1. Sword of Sodan        : 34 x 24   272 x 192 (26,112 bytes ( 81.6%))
;  2. ~NES                  : 32 x 25   256 x 200 (25,600 bytes ( 80.0%))
;  3. Task Force            : 32 x 22   256 x 176 (22,528 bytes ( 70.4%))
;  4. Defender of the World : 35 x 20   280 x 160 (22,400 bytes ( 70.0%))
;  5. Rastan                : 32 x 20   256 x 160 (20,480 bytes ( 64.0%))
;  6. Game Boy Advanced     : 30 x 20   240 x 160 (19,200 bytes ( 60.0%))
;  7. Ancient Land of Y's   : 36 x 16   288 x 128 (18,432 bytes ( 57.6%))
;  8. Game Boy Color        : 20 x 18   160 x 144 (11,520 bytes ( 36.0%))
;  9. Agony (Amiga)         : 36 x 24   288 x 192 (27,648 bytes ( 86.4%))
; 10. Atari Lynx            : 20 x 13   160 x 102 (8,160 bytes  ( 25.5%))
;
;  X = mode number OR width in bytes
;  Y = height in pixels (if X > 8)
_SetScreenMode
                  cpx       #11
                  bcs       :direct             ; if x > 10, then assume X and Y are the dimensions

                  txa
                  asl
                  tax

                  ldy       ScreenModeHeight,x
                  lda       ScreenModeWidth,x
                  tax

:direct           cpy       #SHR_SCREEN_HEIGHT+1
                  bcs       :exit

                  cpx       #SHR_LINE_WIDTH+1
                  bcs       :exit

                  phx                           ; Save X (width) and Y (height)
                  phy

                  lda       #SHR_LINE_WIDTH    ; Center the screen
                  sec
                  sbc       3,s
                  lsr
                  xba
                  pha                           ; Save half the origin coordinate

                  lda       #SHR_SCREEN_HEIGHT
                  sec
                  sbc       3,s                 ; This is now Y because of the PHA above
                  lsr
                  ora       1,s

                  plx                           ; Throw-away to pop the stack
                  ply
                  plx

                  jsr       SetScreenRect

                  lda       #0
                  jmp       FillScreen          ; tail return
:exit
                  rts

; Return the current border color ($0 - $F) in the accumulator
_GetBorderColor  lda   #0000
                 sep   #$20
                 ldal  BORDER_REG
                 and   #$0F
                 rep   #$20
                 rts

; Set the border color to the accumulator value.
_SetBorderColor  sep   #$20                 ; ACC = $X_Y, REG = $W_Z
                 eorl  BORDER_REG           ; ACC = $(X^Y)_(Y^Z)
                 and   #$0F                 ; ACC = $0_(Y^Z)
                 eorl  BORDER_REG           ; ACC = $W_(Y^Z^Z) = $W_Y
                 stal  BORDER_REG
                 rep   #$20
                 rts

; Clear to SHR screen to a specific color
_ClearToColor
                 ldx  #$7CFE
:loop            stal $012000,x
                 dex
                 dex
                 bpl  :loop
                 rts

; Set a palette values
; A = palette number, X = palette address
_SetPalette
                 and   #$000F               ; palette values are 0 - 15 and each palette is 32 bytes
                 asl
                 asl
                 asl
                 asl
                 asl
                 txy
                 tax

]idx             equ   0
                 lup   16
                 lda:  $0000+]idx,y
                 stal  SHR_PALETTES+]idx,x
]idx             equ   ]idx+2
                 --^
                 rts

; Initialize the SCB
_SetSCBs
                 ldx   #$0100               ;set all $100 scbs to A
:scbloop         dex
                 dex
                 stal  SHR_SCB,x
                 bne   :scbloop
                 rts

; Turn SHR screen On/Off
_GrafOn
                 sep   #$20
                 lda   #$C1              ; SHR On, Linear Memory Map On, Ignore Bank Latch
                 stal  NEW_VIDEO_REG
                 rep   #$20
                 rts

_GrafOff
                 sep   #$20
                 lda   #$01              ; SHR Off, Linear Memory Map Off
                 stal  NEW_VIDEO_REG
                 rep   #$20
                 rts

; Enable/Disable Shadowing.
_ShadowOn
                 sep   #$20
                 ldal  SHADOW_REG
;                 and   #$F7
                 and   #$F1
                 stal  SHADOW_REG
                 rep   #$20
                 rts

_ShadowOff
                 sep   #$20
                 ldal  SHADOW_REG
;                 ora   #$08
                 ora   #$0E
                 stal  SHADOW_REG
                 rep   #$20
                 rts

_GetVBL
                 sep   #$20
                 ldal  VBL_HORZ_REG
                 asl
                 ldal  VBL_VERT_REG
                 rol                        ; put V5 into carry bit, if needed. See TN #39 for details.
                 rep   #$20
                 and   #$00FF
                 rts

_WaitForVBL
                 sep   #$20
:wait1           ldal  VBL_STATE_REG        ; If we are already in VBL, then wait
                 bmi   :wait1
:wait2           ldal  VBL_STATE_REG
                 bpl   :wait2               ; spin until transition into VBL
                 rep   #$20
                 rts

; Set the physical location of the virtual screen on the physical screen. The
; screen size must by a multiple of 8
;
; A = XXYY where XX is the left edge [0, 159] and YY is the top edge [0, 199]
; X = width (in bytes)
; Y = height (in lines)
;
; This subroutine stores the screen positions in the direct page space and fills
; in the double-length ScreenAddrR table that holds the address of the right edge
; of the playfield.  This table is used to set addresses in the code banks when the
; virtual origin is changed.
;
; We are not concerned about the raw performance of this function because it should
; usually only be executed once during app initialization.  It doesn't get called
; with any significant frequency.

SetScreenRect      sty   ScreenHeight               ; Save the screen height and width
                   stx   ScreenWidth

                   tax                              ; Temp save of the accumulator
                   and   #$00FF
                   sta   ScreenY0
                   clc
                   adc   ScreenHeight
                   sta   ScreenY1

                   txa                              ; Restore the accumulator
                   xba
                   and   #$00FF
                   sta   ScreenX0
                   clc
                   adc   ScreenWidth
                   sta   ScreenX1

                   lda   ScreenHeight               ; Divide the height in scanlines by 8 to get the number tiles
                   lsr
                   lsr
                   lsr
                   sta   ScreenTileHeight

                   lda   ScreenWidth                ; Divide width in bytes by 4 to get the number of tiles
                   lsr
                   lsr
                   sta   ScreenTileWidth

                   lda   ScreenY0                   ; Calculate the address of the first byte
                   asl                              ; of the right side of the playfield
                   tax
                   lda   ScreenAddr,x               ; This is the address for the edge of the physical screen
                   clc
                   adc   ScreenX1
                   dec
                   pha                              ; Save for second loop

                   ldx   #0
                   ldy   ScreenHeight
:loop              clc
                   sta   RTable,x
                   adc   #160
                   inx
                   inx
                   dey
                   bne   :loop

                   ldy   ScreenHeight
                   pla                              ; Reset the address and continue filling in the
:loop2             clc
                   sta   RTable,x
                   adc   #160
                   inx
                   inx
                   dey
                   bne   :loop2

; Calculate the screen locations for each tile corner

                   lda   ScreenY0                   ; Calculate the address of the first byte
                   asl                              ; of the right side of the playfield
                   tax
                   lda   ScreenAddr,x               ; This is the address for the left edge of the physical screen
                   clc
                   adc   ScreenX0

                   rts

; Clear the SHR screen and then infill the defined field
FillScreen         cmp   #0
                   bne   :fullfill
                   jmp   _ClearToColor

:fullfill
                   pha
                   lda   #0
                   jsr   _ClearToColor

                   ldy   ScreenY0
:yloop
                   tya
                   asl   a
                   tax
                   lda   ScreenAddr,x
                   clc
                   adc   ScreenX0
                   tax
                   phy

                   lda   ScreenWidth
                   lsr
                   tay
                   lda   1,s
:xloop             stal  $E10000,x                  ; X is the absolute address
                   inx
                   inx
                   dey
                   bne   :xloop

                   ply
                   iny
                   cpy   ScreenY1
                   bcc   :yloop

                   pla
                   rts


; SetBG0XPos
;
; Set the virtual horizontal position of the primary background layer.  In addition to 
; updating the direct page state locations, this routine needs to preserve the original
; value as well.  This is a bit subtle, because if this routine is called multiple times
; with different values, we need to make sure the *original* value is preserved and not
; continuously overwrite it.
;
; We assume that there is a clean code field in this routine
_SetBG0XPos
                    DO    NAMETABLE_MIRRORING&HORIZONTAL_MIRRORING
                    and   #$007F                     ; X position capped for horizontal mirroring
                    ELSE
                    and   #$00FF
                    FIN

                    cmp   StartX
                    beq   :out                       ; Easy, if nothing changed, then nothing changes

                    ldx   StartX                     ; Load the old value (but don't save it yet)
                    sta   StartX                     ; Save the new position

                    lda   #DIRTY_BIT_BG0_X
                    tsb   DirtyBits                  ; Check if the value is already dirty, if so exit
                    bne   :out                       ; without overwriting the original value

                    stx   OldStartX                  ; First change, so preserve the prior value
:out                rts


; SetBG0YPos
;
; Set the virtual position of the primary background layer.
_SetBG0YPos
                     cmp   StartY
                     beq   :out                 ; Easy, if nothing changed, then nothing changes

                     ldx   StartY               ; Load the old value (but don't save it yet)
                     sta   StartY               ; Save the new position

                     lda   #DIRTY_BIT_BG0_Y
                     tsb   DirtyBits            ; Check if the value is already dirty, if so exit
                     bne   :out                 ; without overwriting the original value

                     stx   OldStartY            ; First change, so preserve the value
:out                 rts

;  0. Full Screen           : 40 x 25   320 x 200 (32,000 bytes (100.0%)) 
;  1. Sword of Sodan        : 34 x 24   272 x 192 (26,112 bytes ( 81.6%))
;  2. ~NES                  : 32 x 25   256 x 200 (25,600 bytes ( 80.0%))
;  3. Task Force            : 32 x 22   256 x 176 (22,528 bytes ( 70.4%))
;  4. Defender of the World : 35 x 20   280 x 160 (22,400 bytes ( 70.0%))
;  5. Rastan                : 32 x 20   256 x 160 (20,480 bytes ( 64.0%))
;  6. Game Boy Advanced     : 30 x 20   240 x 160 (19,200 bytes ( 60.0%))
;  7. Ancient Land of Y's   : 36 x 16   288 x 128 (18,432 bytes ( 57.6%))
;  8. Game Boy Color        : 20 x 18   160 x 144 (11,520 bytes ( 36.0%))
;  9. Agony (Amiga)         : 36 x 24   288 x 192 (27,648 bytes ( 86.4%))
; 10. Atari Lynx            : 20 x 13   160 x 102 (8,160 bytes  ( 25.5%))
ScreenModeWidth  dw        160,136,128,128,140,128,120,144,80,144,80,160
ScreenModeHeight dw        200,192,200,176,160,160,160,128,144,192,102,1

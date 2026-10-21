
; Graphic screen initialization
                 mx %00
InitGraphics
                 jsl   _ShadowOnL
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
                 mx    %00
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

                  jsl       SetScreenRectL

                  lda       #0
                  jmp       FillScreen          ; tail return
:exit
                  rts

; Return the current border color ($0 - $F) in the accumulator
                 mx    %00
_GetBorderColor  lda   #0000
                 sep   #$20
                 ldal  BORDER_REG
                 and   #$0F
                 rep   #$20
                 rts

; Set the border color to the accumulator value.
                 mx    %00
_SetBorderColor  sep   #$20                 ; ACC = $X_Y, REG = $W_Z
                 eorl  BORDER_REG           ; ACC = $(X^Y)_(Y^Z)
                 and   #$0F                 ; ACC = $0_(Y^Z)
                 eorl  BORDER_REG           ; ACC = $W_(Y^Z^Z) = $W_Y
                 stal  BORDER_REG
                 rep   #$20
                 rts

; Clear to SHR screen to a specific color
                 mx    %00
_ClearToColor
                 ldx  #$7CFE
:loop            stal $012000,x
                 dex
                 dex
                 bpl  :loop
                 rts

; Clear the SHR shadow screen ($01/2000) to zeros with shadowing on, so the visible screen ($E1/2000)
; is cleared as well.  Needed when CTRL_EVEN_RENDER is turned on: only every other line is drawn
; after that, and the lines in between would keep whatever was on the screen.  The shadowing state
; is restored afterwards.
                 mx    %00
_ClearShadowScreen
                 sep   #$20
                 ldal  SHADOW_REG
                 pha
                 rep   #$20
                 jsl   _ShadowOnL
                 lda   #0
                 jsr   _ClearToColor
                 sep   #$20
                 pla
                 stal  SHADOW_REG
                 rep   #$20
                 rts

; Set a palette values
; A = palette number, X = palette address
                 mx    %00
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
                 mx    %00
_SetSCBs
                 ldx   #$0100               ;set all $100 scbs to A
:scbloop         dex
                 dex
                 stal  SHR_SCB,x
                 bne   :scbloop
                 rts

; Turn SHR screen On/Off
                 mx    %00
_GrafOn
                 sep   #$20
                 lda   #$C1              ; SHR On, Linear Memory Map On, Ignore Bank Latch
                 stal  NEW_VIDEO_REG
                 rep   #$20
                 rts

                 mx    %00
_GrafOff
                 sep   #$20
                 lda   #$01              ; SHR Off, Linear Memory Map Off
                 stal  NEW_VIDEO_REG
                 rep   #$20
                 rts

                 mx    %00
_GetVBL
                 sep   #$20
                 ldal  VBL_HORZ_REG
                 asl
                 ldal  VBL_VERT_REG
                 rol                        ; put V5 into carry bit, if needed. See TN #39 for details.
                 rep   #$20
                 and   #$00FF
                 rts

                 mx    %00
_WaitForVBL
                 sep   #$20
:wait1           ldal  VBL_STATE_REG        ; If we are already in VBL, then wait
                 bmi   :wait1
:wait2           ldal  VBL_STATE_REG
                 bpl   :wait2               ; spin until transition into VBL
                 rep   #$20
                 rts

; Clear the SHR screen and then infill the defined field
                   mx    %00
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
;                   lda   ScreenAddr,x
;                   clc
                   ldal  Mul160Tbl,x
                   adc   #$2000
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

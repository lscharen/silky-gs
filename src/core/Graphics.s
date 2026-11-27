
; Graphic screen initialization
                 mx %00
InitGraphics
                 jsl   _ShadowOnL
                 jsr   _GrafOn

; Clear the SCBs and Palettes

                 ldx   #$2FE
                 lda   #0
:lp              stal  $E19D00,x
                 stal  $E09D00,x             ; (VOC spike) the sprite plane's SCBs and palettes
                 dex
                 dex
                 bpl   :lp
                 jsr   SetupVOC              ; (VOC spike) the chroma key, which the clear just zeroed

                 ldy   #200                  ; Full height
                 jsr   _SetScreenHeight      ; Calls SetScreenRect

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

; Set the height of the playfield (Y = lines, a multiple of 8, at most 200) and clear the screen.
; The playfield is always the NES's 256 pixels (128 bytes), from byte x_offset of each line
; (SetScreenRect); it is centered vertically.
                 mx    %00
_SetScreenHeight
                  cpy       #SHR_SCREEN_HEIGHT+1
                  bcs       :exit

                  phy
                  lda       #SHR_SCREEN_HEIGHT
                  sec
                  sbc       1,s
                  lsr                           ; A = top line
                  ply
                  jsl       SetScreenRectL

                  lda       #0
                  jmp       _ClearToColor       ; tail return
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
                 stal $E02000,x              ; (VOC spike) the sprite plane: all transparent
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
                 lda   #1                ; The engine has the display (irqVbl, rom/rom_exec.s: SHR off after
                 stal  engineVideoOn     ; this means the CDA menu has it)
                 jmp   SetupVOC

; VOC two-plane spike (from dwsJason on Apple II Infinitum slack):
;
; 1. Feed the IIgs motherboard composite output into the VOC input
; 2. Set the VOC to display from main memory bank $E0 (bits 5:4 of $C0B1 = 01) with linearization enabled
;
; The background is rendered into bank $01 with shadowing to $E1, as usual; the sprites go straight to
; bank $E0, whose color 0 is the chroma key, so the background shows through it.  The VOC doesn't scan
; out IIgs memory, it captures the writes into its own, so the sprite plane is erased with the capture
; off and the erased cells are written again afterwards (drawScreen, ppu/ppu_render.s).
                 mx    %00
SetupVOC
                 lda   #ChromaKeyRGB
                 stal  $E09E00
                 sep   #$20
                 xba                     ; Red, with the blanking source and genlock set to the NTSC input
                 and   #$0F
                 ora   #$30
                 stal  VOC_RED_REGISTER
                 lda   #ChromaKeyRGB&$FF ; Blue / green
                 stal  VOC_BLUE_GREEN_REGISTER

                 ldal  VOC_CONTROL_REGISTER   ; Main bank page select, linearization, capture on
                 and   #%11000110
                 ora   #%00011000
                 stal  VOC_CONTROL_REGISTER

                 ldal  VOC_DISSOLVE_REGISTER  ; Bank $E0 graphics are 100% opaque
                 and   #%11111000
                 stal  VOC_DISSOLVE_REGISTER
                 rep   #$20
                 rts

                 mx    %00
_GrafOff
                 lda   #0
                 stal  engineVideoOn
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



TitleNMI

	;draw sprites
	lda #$02 ; page 200
	jsr STA_4014       ; set the high byte (02) of the RAM address, start the transfer


    LDA #$00        ;;tell the ppu there is no background scrolling
    jsr STA_2005
    jsr STA_2005

    jsr PlayMusic
    jsr ReadController
    inc randLo
    rol randHi
    rol randHi

    lda #1
    sta nmiFlag

    pla 
    tay
    pla 
    tax
    pla  
;  rti
  rts

TitleMain
    lda #0
    sta nmiFlag
:lp 
    jsl yield
    lda nmiFlag
    beq :lp

    lda buttonPresses
    and #BUTTON_START.BUTTON_A
    beq :x
:start
    jsr StopMusic
;    jsr RestartGame

    jsr TransitionStartScreen
:x  rts

BASE_LINE equ 16

DrawTitleScreen

    jsr HideSprites

     ;setup bat 
	lda #BAT_SPRITE1
	sta BAT_SPRITES
	sta BAT_SPRITES+4

	;sprite flags
	lda #0
	sta LARGE_BAT_ATTRS
	lda #FLIP_H
	sta LARGE_BAT_ATTRS+4

    lda #108
    sta BAT_SPRITES_X
    lda #116
    sta BAT_SPRITES_X+4
    lda #158-BASE_LINE
    sta BAT_SPRITES_Y
    sta BAT_SPRITES_Y+4


    ;upper teeth

	lda #UPPER_TEETH_TILE
	sta UPPER_TEETH_SPRITES
	sta UPPER_TEETH_SPRITES+4
	sta UPPER_TEETH_SPRITES+8

    lda #70-BASE_LINE
    sta UPPER_TEETH_SPRITES_Y
    sta UPPER_TEETH_SPRITES_Y+4
    sta UPPER_TEETH_SPRITES_Y+8

    lda #48
    sta UPPER_TEETH_SPRITES_X
    lda #56 
    sta UPPER_TEETH_SPRITES_X+4
    lda #64 
    sta UPPER_TEETH_SPRITES_X+8

    ;bottom teeth
    lda #<LOWER_TEETH_TILE
	sta LOWER_TEETH_SPRITES
	sta LOWER_TEETH_SPRITES+4
	sta LOWER_TEETH_SPRITES+8

    lda #88-BASE_LINE
    sta LOWER_TEETH_SPRITES_Y
    sta LOWER_TEETH_SPRITES_Y+4
    sta LOWER_TEETH_SPRITES_Y+8

    ;set teeth palette
	lda #3
	sta UPPER_TEETH_SPRITES_ATTRS
	sta UPPER_TEETH_SPRITES_ATTRS+4
    sta UPPER_TEETH_SPRITES_ATTRS+8
    sta UPPER_TEETH_SPRITES_ATTRS+12
    sta UPPER_TEETH_SPRITES_ATTRS+16
    sta UPPER_TEETH_SPRITES_ATTRS+20

    lda #48
    sta LOWER_TEETH_SPRITES_X
    lda #56 
    sta LOWER_TEETH_SPRITES_X+4
    lda #64 
    sta LOWER_TEETH_SPRITES_X+8

    ;wumpus eyes
    lda #WUMPUS_EYES_TILE
    sta WUMPUS_EYES_SPRITES
    sta WUMPUS_EYES_SPRITES+4
    
    ;eyes top
	lda #WUMPUS_EYES_TOP-8-BASE_LINE
	sta WUMPUS_EYES_SPRITES_Y
	sta WUMPUS_EYES_SPRITES_Y+4

    lda #40
	sta WUMPUS_EYES_SPRITES_X
    clc
    adc #32
	sta WUMPUS_EYES_SPRITES_X+4

    lda #>TitleScreenData
    sta srcPtrHi 	
	lda #<TitleScreenData
    sta srcPtrLo 
    jsr RLDecompTileMap
  
    ;set palettes
	lda #3
	sta WUMPUS_EYES_SPRITES_ATTRS
	sta WUMPUS_EYES_SPRITES_ATTRS+4


	;set palettes for 4 large bat sprites
    ldy #0
:lp2    
	lda LARGE_BAT_ATTRS,y
	ora #3
    sta LARGE_BAT_ATTRS,y
	iny
	iny
	iny
	iny
    cpy #16
    bne :lp2

;	lda #$21
;	sta destPtrHi
;	lda #$00
;	sta destPtrLo

;	lda #>BigWumpusIcon
;	sta srcPtrHi
;	lda #<BigWumpusIcon
;	sta srcPtrLo
;	jsr Copy16Tiles

  lda #>TitleMusicTreble
  sta channel1PtrHi
  lda #<TitleMusicTreble
  sta channel1PtrLo

  lda #>TitleMusicBass
  sta channel2PtrHi
  lda #<TitleMusicBass
  sta channel2PtrLo


    lda #>TitleMain
    sta mainFnHi
    lda #<TitleMain
    sta mainFnLo

    lda #>TitleNMI
    sta NMIHanlderHi
    lda #<TitleNMI
    sta NMIHanlderLo

    rts
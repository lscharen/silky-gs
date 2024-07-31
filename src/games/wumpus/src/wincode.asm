wincode

VictoryMain
    ;is music done?
    ldy channel1Index
    lda VictoryMusic,y
    bne :x

	;wait for input
	lda #0
	sta nmiFlag
:lp
    jsl yield
    lda nmiFlag
	beq :lp

    jsr ReadController
	lda buttonPresses
	and #BUTTON_A
	beq :x
	jsr TransitionScoreboard
:x  rts
    
VictoryNMI

   jsr PlayMusic
 
	lda #1
	sta nmiFlag

  LDA #$00        ;;tell the ppu there is no background scrolling
  jsr STA_2005
  jsr STA_2005
  dec counter
  pla 
  tay
  pla 
  tax
  pla 
;  rti
  rts


DrawVictoryScreen
 jsr HideSprites
    jsr DrawHorizontalTunnel ; don't need to do this...tunnel already drawn
 

	lda #96
	sta textX
	lda #100
	sta textY
	lda #0
	sta textPalette
	lda #>VictoryTextSpr
	sta srcPtrHi
	lda #<VictoryTextSpr
	sta srcPtrLo
	lda #50 ; start sprite
	jsr DrawSpriteText

	;setup music
	lda #>VictoryMusic
	sta channel1PtrHi
	lda #<VictoryMusic
	sta channel1PtrLo
 
	lda #>VictoryMusicBass
	sta channel2PtrHi
	lda #<VictoryMusicBass
	sta channel2PtrLo

	;move arrow sprite to wumpus
;	lda #$49
;	sta ARROW_SPRITES
;	lda #112
;	sta ARROW_SPRITES_X
;	lda #128
;	sta ARROW_SPRITES_Y
;	lda #$03 ; black palette
;	sta ARROW_SPRITES_Y+2

	 
  ldx #0
	ldy #0
	lda #0
:lp2
	pha
	lda DeadWumpusSprites,x
	sta DEAD_WUMPUS_SPRITES_TILE,y
  lda #2
  sta DEAD_WUMPUS_SPRITES_TILE+1,y
  inx
	iny
	iny
	iny
	iny
	pla
  clc
	adc #1
	cmp #12
	bne :lp2

;apply x offsets to each sprite
	ldx #0
  ldy #$7B
:lp3
	clc
	lda DeadWumpusXCoords,x
	sta $200,y
	tya
	clc
	adc #4
	tay
	inx
	cpx #12
	bne :lp3

	;apply y offsets to each sprite
	ldx #0
  ldy #$78
:lp4
	clc
	lda DeadWumpusYCoords,x
	sta $200,y
	tya
	clc
	adc #4
	tay	
	inx
	cpx #12
	bne :lp4	
	rts
 
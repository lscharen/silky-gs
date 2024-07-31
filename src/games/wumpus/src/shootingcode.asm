;shootingcode.asm

 



;sets the positions and ids of the arrow sprites
SetupArrow
	lda #TICKS_PER_ARROW_MOVE
	sta counter
	lda #0
	sta doneFalling
	lda direction
	asl a ; x 2
	tay
	;sprite numbers
	lda ArrowSprites,y
	sta ARROW_SPRITES
	lda ArrowSprites+1,y
	sta ARROW_SPRITES+4

	;sprite flags
	lda ArrowSpriteFlags,y
	sta ARROW_SPRITE_FLAGS
	lda ArrowSpriteFlags+1,y
	sta ARROW_SPRITE_FLAGS+4
	
	
	;sprite x coords
	lda ArrowXCoords,y
	sta ARROW_SPRITES_X
	lda ArrowXCoords+1,y
	sta ARROW_SPRITES_X+4
	
	;y coords
	lda ArrowYCoords,y
	sta ARROW_SPRITES_Y
	lda ArrowYCoords+1,y
	sta ARROW_SPRITES_Y+4
	;set update function
	lda direction
	cmp #UP
	bne :d
	lda #<MoveArrowUp
	sta UpdateArrowFnLo
	lda #>MoveArrowUp	
	sta UpdateArrowFnHi
	jmp :x
:d	cmp #DOWN
	bne :lft
	lda #<MoveArrowDown
	sta UpdateArrowFnLo
	lda #>MoveArrowDown	
	sta UpdateArrowFnHi
	jmp :x
:lft
	cmp #LEFT	
	bne :rt
	lda #<MoveArrowLeft
	sta UpdateArrowFnLo
	lda #>MoveArrowLeft	
	sta UpdateArrowFnHi	
	jmp :x
:rt
	lda #<MoveArrowRight
	sta UpdateArrowFnLo
	lda #>MoveArrowRight	
	sta UpdateArrowFnHi	
:x
	rts
 
 ;main loop when in "shooting mode"
ArrowMain
	lda counter
	bne dx	
    lda doneFalling
	bne d
;	jmp [UpdateArrowFnLo]
    lda UpdateArrowFnLo
	sta :p+1
	lda UpdateArrowFnLo+1
	sta :p+2
:p  jmp $0000

ArrowMoved	; global return label
	;reset timer
	lda #TICKS_PER_ARROW_MOVE
	sta counter
	jmp dx
d
	;did player hit the wumpus or not?
	jsr HitWumpus
	lda targetRoom
	cmp playerRoom
	beq :hitSelf
;	bne :hitSelf
	lda hitWumpusFlag
    beq :miss
	lda playerScore
	jsr BCDInc
	sta playerScore
	jsr VictoryTransition	
	jmp dx
:hitSelf
	jsr TransitionShootSelf
	jmp dx	
:miss
  	lda wumpusScore
    jsr BCDInc
    sta wumpusScore
	jsr DeathTransition
dx	rts
 
 ;b4 is a background tile 
 ;25 is a white tile
DrawVerticalTunnel
	jsr LDA_2002
	lda #$20
	jsr STA_2006
	jsr STA_2006	
	ldx #28
:outer
	;draw 12 black tiles
	ldy #12
	lda #$B4
:lp1
	jsr STA_2007
	dey
	bne :lp1
	;draw 8 white tiles
	ldy #8
	lda #WHITE_TILE
:lp2
	jsr STA_2007
	dey
	bne :lp2
	
	;draw 12 black tiles
	ldy #12
	lda #SOLID_TILE
:lp3
	jsr STA_2007
	dey
	bne :lp3
	dex
	bne :outer

	rts

 
DrawHorizontalTunnel

	;jsr ClearPPU
 
	
	lda #$20
	jsr STA_2006
	jsr STA_2006	
	ldx #28

	;10 solid lines 
	ldy #10
:outer1	
	ldx #32
	lda #SOLID_TILE
:lp1
	jsr STA_2007
	dex
	bne :lp1
	dey
	bne :outer1
	
	;8 WHITE lines 
	ldy #8
:outer2	
	ldx #32
	lda #WHITE_TILE
:lp2
	jsr STA_2007
	dex
	bne :lp2
	dey
	bne :outer2

	;10 solid lines 
	ldy #10
:outer3	
	ldx #32
	lda #SOLID_TILE
:lp3
	jsr STA_2007
	dex
	bne :lp3
	dey
	bne :outer3	
	rts
 

MoveArrowUp
	dec ARROW_SPRITES_Y
	dec 4+ARROW_SPRITES_Y
	dec ARROW_SPRITES_Y
	dec 4+ARROW_SPRITES_Y
	bne :x
	lda #1
	sta doneFalling
:x	
	jmp ArrowMoved

MoveArrowDown
	inc ARROW_SPRITES_Y
	inc 4+ARROW_SPRITES_Y
	inc ARROW_SPRITES_Y
	inc 4+ARROW_SPRITES_Y
	lda 4+ARROW_SPRITES_Y
	cmp #232  ; bottom
	bne :x
	lda #1
	sta doneFalling
:x	jmp ArrowMoved

MoveArrowLeft
	dec ARROW_SPRITES_X
	dec 4+ARROW_SPRITES_X
	dec ARROW_SPRITES_X
	dec 4+ARROW_SPRITES_X
	bne :x
	lda #1
	sta doneFalling	
:x	jmp ArrowMoved

MoveArrowRight
	inc ARROW_SPRITES_X
	inc 4+ARROW_SPRITES_X
	inc ARROW_SPRITES_X
	inc 4+ARROW_SPRITES_X
	lda 4+ARROW_SPRITES_X
	cmp #248
	bne :x
	lda #1
	sta doneFalling
:x
	jmp ArrowMoved
 
ShootRight
	lda #RIGHT
	sta direction
	tay
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	bmi :beep
	jsr ShootTransition
	jmp :x
:beep
	jsr PlayErrorBeep
:x	rts

ShootLeft
	lda #LEFT
	sta direction
	tay
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	bmi :beep	
	jsr ShootTransition
	jmp :x
:beep
	jsr PlayErrorBeep
:x	rts

ShootUp
	lda #UP
	sta direction
	tay
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	bmi :beep		
	jsr ShootTransition
	jmp :x
:beep
	jsr PlayErrorBeep
:x	rts


ShootDown
	lda #DOWN
	sta direction
	tay
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	bmi :beep	
	jsr ShootTransition
	jmp :x
:beep
	jsr PlayErrorBeep
:x	rts

TunnelRLEData
	db $FF,$DF,$61,$DF,$FF,$DD,$01,$DD,$FF,$DF,$61,$DF,$00


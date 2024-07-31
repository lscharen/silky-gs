;bat code

BatNMI
	LDA #$00        ;;tell the ppu there is no background scrolling
    jsr STA_2005
    jsr STA_2005

	lda counter
	beq :x
	dec counter
:x 

	lda #1
	sta nmiFlag

    pla 
    tay
    pla 
    tax
    pla  
;    rti
    rts


BatMain
	lda counter
	bne :x	
    lda doneFalling
	bne :reset
	jsr UpdateBat
	lda #1
	sta counter
	jmp :x
:reset
	jsr DropPlayer	
:x    
	rts

    ;sets the positions and ids of the arrow sprites
SetupBat
	lda #$01
	sta batCounter
	lda #0
	sta doneFalling
	 
	
	;player sprites don't change, but do need to move
	lda #$48
	sta $201 ; player sprite
	lda #$58
	sta $205 ; player sprite
	
	lda #04
	sta $203 ; playerX
	sta $207 ; playerX
	lda #120
	sta $200 ; playerY
	lda #128
	sta $204 ; playerY
	
	;setup bat sprites
	
	sta ARROW_SPRITE_FLAGS
	
	lda #BAT_SPRITE1
	sta BAT_SPRITES
	sta BAT_SPRITES+4

	;sprite flags
	lda #3
	sta LARGE_BAT_ATTRS

	lda #FLIP_H
	lda LARGE_BAT_ATTRS+4
	ora #FLIP_H
	sta LARGE_BAT_ATTRS+4
	
	;sprite x coords
	lda #0
	sta BAT_SPRITES_X
	lda #8
	sta BAT_SPRITES_X+4
	
	;bats y coords
	lda #112
	sta BAT_SPRITES_Y
	sta BAT_SPRITES_Y+4

	;bat palette2

:x
	rts
 
 
 
MoveBat
	rts


 
 
UpdateBat
	;check the counter
	dec batCounter
	bne :x
	;reset counter
	lda #$08
	sta batCounter
	;make the flap sound
	lda #ENABLE_STATIC ;turn on static
;	sta APU_STATUS
	jsr STA_4015

	lda #$1F 
;	ora #ENABLE_LENGTH ; set volume
;	sta APU_NOISE1  
    jsr STA_400c
	lda #$02 ; freq lo
;	sta APU_NOISE2
	jsr STA_400e

	lda #$18 ;turn on static ; len + freq hi
;	sta APU_NOISE3
	jsr STA_400f
	;make the bat flap
	lda batUp
	bne :down
	lda #1
	sta batUp
	lda #BAT_SPRITE1
	jmp :done
:down
	lda #0
	sta batUp
	lda #BAT_SPRITE2	
:done
	sta BAT_SPRITES
	sta BAT_SPRITES+4
	lda BAT_SPRITES_X+4
	sta BAT_SPRITES_X
	lda BAT_SPRITES_X+4
	clc
	adc #8
	sta BAT_SPRITES_X+4
	;done?
	cmp #248
	bne :nd
	sta doneFalling
:nd
	;move player, too
	clc
	lda $203
	adc #8
	sta $203
	sta $207
	
:x	rts

 
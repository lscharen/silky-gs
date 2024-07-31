;pitcode.asm


PitNMI
 
	lda counter
	beq :noDec  
	dec counter
	jmp :x
:noDec
	jsr ReadController
	 
 
	
:x

	lda #1
	sta nmiFlag

  LDA #$00        ;;tell the ppu there is no background scrolling
  jsr STA_2005
  jsr STA_2005
 
  pla 
  tay
  pla 
  tax
  pla 
;  rti
  rts


SetupPit
	
	lda #%00000111 ;enable Sq1, Sq2 and Tri channels
	jsr STA_4015
	;Square 1
	lda #%00011000 ;Duty 00, Volume 8 (half volume)
	sta shadowChannel1
	jsr STA_4000
	lda #$10 ;$0C9 is a C# in NTSC mode
	jsr STA_4002 ;low 8 bits of period
	lda #$10
	jsr STA_4003 ;high 3 bits of period

	lda #$10
	sta note

	;setup player sprite
	lda #$59
	sta	$201
	lda #$5A
	sta	$205
	
	
	lda #120
	sta PLAYER_X
	lda #128
	sta PLAYER_X+4
	lda #8
	sta PLAYER_Y
	sta PLAYER_Y+4

    rts


;b4 is a background tile 
 ;25 is a white tile
DrawPitBackground
	jsr LDA_2002
	lda #$20
	jsr STA_2006
	jsr STA_2006
;	ldx #27
	ldx #25
:outer
	;draw 12 black tiles
	ldy #12
	lda #SOLID_TILE
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

	;one solid line 
	ldx #32
	lda #SOLID_TILE
:lp4
	jsr STA_2007
	dex
	bne :lp4
	
	rts

;pit main
PitMain
	lda counter
	bne :x	 ; wait for it to hit 0
    lda doneFalling
	bne :w
 
	inc note
	lda note
	jsr STA_4002
 
	lda #$10
	jsr STA_4003 ;high 3 bits of period
	inc PLAYER_Y
	inc PLAYER_Y+4
	inc PLAYER_Y
	inc PLAYER_Y+4
	lda PLAYER_Y
;	cmp #216	
	cmp #200	
	bne :d
	;change player sprite
	inc $201
	inc $201
	inc $205
	inc $205	
	sta doneFalling

	;draw pit text
	lda #112
	sta textX
	lda #100
	sta textY
	lda #0
	sta textPalette
	lda #>PitTextSpr
	sta srcPtrHi
	lda #<PitTextSpr
	sta srcPtrLo
	lda #50 ; start sprite

	jsr DrawSpriteText

	;turn on static
	lda #ENABLE_STATIC
;	sta APU_STATUS
	jsr STA_4015
	lda #$1F  ; set volume
;	sta APU_NOISE1
    jsr STA_400c

	lda #$02 ; freq lo
;	sta APU_NOISE2
	jsr STA_400e

	lda #$00 ; len + freq hi
;	sta APU_NOISE3
	jsr STA_400f
	
:d	lda #1
	sta counter
	jmp :x
:w	lda buttonPresses
	and #BUTTON_A
	beq :x
	jsr TransitionScoreboard
:x    rts
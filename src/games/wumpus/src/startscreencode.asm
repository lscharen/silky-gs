

StartScreenMain

	; wait for NMI to read controllers
	lda #0
	sta nmiFlag 
:lp
    jsl yield
    lda nmiFlag
	beq :lp

	;read buttons sequentially
	lda buttonPresses        
	and #BUTTON_A.BUTTON_START
	beq :readUp	    ; branch to ReadADone if button is NOT pressed (0) 
	lda skillLevel
	cmp #3
	beq :help 	
	jsr RestartGame 
	jmp :x	
:help
	jsr TransitionHelp
	jmp :x
	 
	 
:readUp	 
	lda buttonPresses       ; player 1 - Up
	and #BUTTON_UP  ; only look at bit 0
	beq :readUpDone   ; branch to ReadADone if button is NOT pressed (0)
				  ; add instructions here to do something when button IS pressed (1)
	jsr DecSkillLevel
	jmp :x
:readUpDone


	lda buttonPresses       ; player 1 - Down
	and #BUTTON_DOWN.BUTTON_SELECT ; only look at bit 0
	beq :readDownDone   ; branch to ReadADone if button is NOT pressed (0)
				  ; add instructions here to do something when button IS pressed (1)
	jsr IncSkillLevel
	jmp :x	
 
:readDownDone
  

;	lda buttonPresses       ; player 1 - Start
;	and #BUTTON_START  ; only look at bit 0
;	beq :readStartDone   ; branch to ReadADone if button is NOT pressed (0)
;	jsr RestartGame			 
;	jmp :x	
;:readStartDone


	lda buttonPresses       ; player 1 - Select
	and #BUTTON_SELECT  ; only look at bit 0
	beq :readSelectDone   ; branch to ReadADone if button is NOT pressed (0)
	jsr IncSkillLevel
	jmp :x	
:readSelectDone


:x	rts


 


StartScreenNMI
 

    LDA #$00        ;;tell the ppu there is no background scrolling
    jsr STA_2005
    jsr STA_2005

	jsr UpdateBatCursor

	jsr ReadController


	lda #1
	sta nmiFlag

    pla 
    tay
    pla 
    tax
    pla  
;  rti
  rts

DrawStartScreen

	jsr HideSprites

	lda #>ScoreScreenData
    sta srcPtrHi
    lda #<ScoreScreenData
    sta srcPtrLo
    jsr RLDecompTileMap


	;draw scorboard ScoreBoardText
	lda #>PREPARE_TEXT_ADDR
	sta destPtrHi
	lda #<PREPARE_TEXT_ADDR
	sta destPtrLo
	lda #>PrepareText
	sta srcPtrHi
	lda #<PrepareText
	sta srcPtrLo
	jsr DrawText

	;draw scorboard ScoreBoardText
	lda #>SELECT_TEXT_ADDR
	sta destPtrHi
	lda #<SELECT_TEXT_ADDR
	sta destPtrLo
	lda #>SelectDifficultyText
	sta srcPtrHi
	lda #<SelectDifficultyText
	sta srcPtrLo
	jsr DrawText


 
	 
	;draw play again text
	lda #>EASY_TEXT_ADDR
	sta destPtrHi
	lda #<EASY_TEXT_ADDR
	sta destPtrLo
	lda #>EasyText
	sta srcPtrHi
	lda #<EasyText
	sta srcPtrLo
	jsr DrawText

	;draw play again text
	lda #>TWISTY_TEXT_ADDR
	sta destPtrHi
	lda #<TWISTY_TEXT_ADDR
	sta destPtrLo
	lda #>TwistyText
	sta srcPtrHi
	lda #<TwistyText
	sta srcPtrLo
	jsr DrawText

	lda #>VERY_TWISTY_TEXT_ADDR
	sta destPtrHi
	lda #<VERY_TWISTY_TEXT_ADDR
	sta destPtrLo
	lda #>VeryTwistyText
	sta srcPtrHi
	lda #<VeryTwistyText
	sta srcPtrLo
	jsr DrawText


	lda #>HELP_TEXT_ADDR
	sta destPtrHi
	lda #<HELP_TEXT_ADDR
	sta destPtrLo
	lda #>NeedHelpText
	sta srcPtrHi
	lda #<NeedHelpText
	sta srcPtrLo
	jsr DrawText

    rts    


IncSkillLevel
	;draw the skill level sprite text
	lda skillLevel
	cmp #3
	beq :x
	inc skillLevel
	ldy	skillLevel
	lda SkillLevelCursorY,y
	sta CURSOR_SPRITE_Y
	sta CURSOR_SPRITE2_Y
:x	rts

DecSkillLevel
	;draw the skill level sprite text
	lda skillLevel
	beq :x
	dec skillLevel
	ldy skillLevel
	lda SkillLevelCursorY,y
	sta CURSOR_SPRITE_Y
	sta CURSOR_SPRITE2_Y
:x	rts

UpdateBatCursor
	inc counter
	lda counter 
	cmp #10
	beq :flap1
	cmp #20
	beq :flap2
	jmp :x
:flap1
	inc CURSOR_SPRITE_Y+1
	inc CURSOR_SPRITE2_Y+1
	jmp :x
:flap2
	dec CURSOR_SPRITE_Y+1
	dec CURSOR_SPRITE2_Y+1
	lda #0
	sta counter
:x rts

SkillLevelCursorY
	db 102,126,150,174
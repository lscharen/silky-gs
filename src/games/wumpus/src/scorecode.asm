

ScoreMain

	lda #0
	sta nmiFlag
:lp
    jsl yield
	lda nmiFlag
	beq :lp
 

	;read buttons sequentially
	lda buttonPresses        
	and #BUTTON_A  
	beq :readUp	    ; branch to ReadADone if button is NOT pressed (0)
 
	lda selectedOption
	bne :reveal	
	jsr RestartGame 
	jmp :x 
:reveal
	cmp #1
	bne :main
	jsr TransitionReveal
	jmp :x
:main
	jsr TransitionStartScreen
	jmp :x
	 
	 
:readUp	 
	lda buttonPresses       ; player 1 - Up
	and #BUTTON_UP   ; only look at bit 0
	beq :readUpDone   ; branch to ReadADone if button is NOT pressed (0)
				  ; add instructions here to do something when button IS pressed (1)
	jsr DecScoreboardOption
	jmp :x
:readUpDone


	lda buttonPresses       ; player 1 - Up
	and #BUTTON_DOWN.BUTTON_SELECT ; only look at bit 0
	beq :readDownDone   ; branch to ReadADone if button is NOT pressed (0)
				  ; add instructions here to do something when button IS pressed (1)
	jsr IncScoreboardOption
	jmp :x	
 
:readDownDone
 
:x	rts


IncScoreboardOption	
	inc selectedOption
	lda selectedOption
	cmp #3
	bne :d
	lda #0
	sta selectedOption
:d	
	tay
	lda ScoreBoardCursorY,y
	sta CURSOR_SPRITE_Y
	sta CURSOR_SPRITE2_Y
	rts

DecScoreboardOption
	dec selectedOption
	lda selectedOption
	bpl :d
	lda #2
	sta selectedOption
:d	
	tay
	lda ScoreBoardCursorY,y
	sta CURSOR_SPRITE_Y
	sta CURSOR_SPRITE2_Y
	rts

ScoreboardNMI
 

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

DrawScoreBoard
	;jsr ClearPPU 


	;draw scorboard ScoreBoardText
	lda #>SCOREBOARD_TEXT_ADDR
	sta destPtrHi
	lda #<SCOREBOARD_TEXT_ADDR
	sta destPtrLo
	lda #>ScoreBoardText
	sta srcPtrHi
	lda #<ScoreBoardText
	sta srcPtrLo
	jsr DrawText

	;draw wumpus icon
	lda #>WUMPUS_ICON_ADDR
	sta destPtrHi
	lda #<WUMPUS_ICON_ADDR
	sta destPtrLo

	lda #>BigWumpusIcon
	sta srcPtrHi
	lda #<BigWumpusIcon
	sta srcPtrLo
	jsr Copy12TilesH

	;draw pit icon
	lda #>PIT_ICON_ADDR
	sta destPtrHi
	lda #<PIT_ICON_ADDR
	sta destPtrLo

	lda #>PitPattern
	sta srcPtrHi
	lda #<PitPattern
	sta srcPtrLo
	jsr Copy16Tiles

	;draw player icon
	lda #>PLAYER_ICON_ADDR
	sta destPtrHi
	lda #<PLAYER_ICON_ADDR
	sta destPtrLo

	lda #>PlayerIconPattern
	sta srcPtrHi
	lda #<PlayerIconPattern
	sta srcPtrLo
	jsr Copy12TilesV

	;setup drawing ptr
	lda #>PLAYER_SCORE
	sta destPtrHi
	lda #<PLAYER_SCORE
	sta destPtrLo

	lda playerScore
	jsr DrawBCDNumber

	;setup drawing ptr
	lda #>PIT_SCORE
	sta destPtrHi
	lda #<PIT_SCORE
	sta destPtrLo

	lda pitScore
	jsr DrawBCDNumber

	;setup drawing ptr
	lda #>WUMPUS_SCORE
	sta destPtrHi
	lda #<WUMPUS_SCORE
	sta destPtrLo

	lda wumpusScore
	jsr DrawBCDNumber
 
	;draw play again text
	lda #>PLAY_AGAIN_TEXT_ADDR
	sta destPtrHi
	lda #<PLAY_AGAIN_TEXT_ADDR
	sta destPtrLo
	lda #>HuntWumpusText
	sta srcPtrHi
	lda #<HuntWumpusText
	sta srcPtrLo
	jsr DrawText

	;draw play again text
	lda #>REVEAL_BOARD_TEXT_ADDR
	sta destPtrHi
	lda #<REVEAL_BOARD_TEXT_ADDR
	sta destPtrLo
	lda #>ShowMapText
	sta srcPtrHi
	lda #<ShowMapText
	sta srcPtrLo
	jsr DrawText

	;draw skill level text
	lda #>CHANGE_DIFFICULTY_TEXT_ADDR
	sta destPtrHi
	lda #<CHANGE_DIFFICULTY_TEXT_ADDR
	sta destPtrLo
	lda #>SetSkillText
	sta srcPtrHi
	lda #<SetSkillText
	sta srcPtrLo
	jsr DrawText


    lda #0
    sta counter
	
    rts    

ScoreBoardCursorY
	db 134,158,182
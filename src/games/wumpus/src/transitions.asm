;transitions.asm
;code for transitioning to another game screen

TransitionStartScreen
    jsr PPUOff

    jsr DrawStartScreen

    lda #0
    sta counter

 ;set NMI handler
    lda #>StartScreenNMI
    sta NMIHanlderHi
    lda #<StartScreenNMI
    sta NMIHanlderLo

    ;set Main ptr
    lda #>StartScreenMain
    sta mainFnHi
    lda #<StartScreenMain
    sta mainFnLo

    ;set cursor
	ldy	skillLevel
	lda SkillLevelCursorY,y
	sta CURSOR_SPRITE_Y
	sta CURSOR_SPRITE2_Y

    ;set bat sprite
    lda #$4D
    sta CURSOR_SPRITE_Y+1
    sta CURSOR_SPRITE2_Y+1
    
    lda #3  
    sta CURSOR_SPRITE_ATTRS
    lda #FLIP_H + 3
    sta CURSOR_SPRITE2_ATTRS

    lda #64
    sta CURSOR_SPRITE_X
    lda #72
    sta CURSOR_SPRITE2_X

    lda #$FF
    sta prevControllerState
    lda #0
    sta buttonPresses
    sta controllerState

    jsr PPUOn

    rts



ShootTransition

    ;hide player (not sure why HideSprites not working)
    lda #240
    sta $200
    lda #240
    sta $204

    jsr PPUOff
 
    ;set up shootingcode

	;Now test it
	lda direction
	beq :v
	cmp #1
	beq :v
	jsr DrawHorizontalTunnel
	jmp :d2
:v
	jsr DrawVerticalTunnel
:d2

    
    jsr HideSprites
    jsr SetupArrow

    ;set the main loop
    lda #>ArrowMain
    sta mainFnHi
    lda #<ArrowMain
    sta mainFnLo

    lda #0
    sta noButton

    jsr PPUOn

    rts

PitTransition

    lda #0
    sta selectedOption
    jsr StopMusic

    jsr PPUOff

    lda pitScore
    jsr BCDInc
    sta pitScore

    jsr HideSprites
    jsr SetupPit
    jsr DrawPitBackground

    ;set NMI handler
    lda #>PitNMI
    sta NMIHanlderHi
    lda #<PitNMI
    sta NMIHanlderLo

    ;set Main ptr
    lda #>PitMain
    sta mainFnHi
    lda #<PitMain
    sta mainFnLo

    lda #0
    sta doneFalling
    lda #1
    sta counter

    jsr PPUOn

    rts

BatTransition

    jsr PPUOff

    lda #1
	sta counter
	 
    jsr HideSprites
	jsr DrawHorizontalTunnel
	jsr SetupBat

    lda #>BatMain
    sta mainFnHi
    lda #<BatMain
    sta mainFnLo


    lda #>BatNMI
    sta NMIHanlderHi
    lda #<BatNMI
    sta NMIHanlderLo

    jsr PPUOn

    rts


VictoryTransition

    jsr PPUOff

    jsr StopMusic
    jsr InitAPU
    
	lda #1
	sta counter

    jsr ResetScreenAttrs
    jsr DrawVictoryScreen

    ;set new main function
    lda #>VictoryMain
    sta mainFnHi
    lda #<VictoryMain
    sta mainFnLo

    ;set new NMI handler
	lda #>VictoryNMI
	sta NMIHanlderHi
	lda #<VictoryNMI
	sta NMIHanlderLo

    jsr PPUOn


    rts


DeathTransition 

    lda #0
    sta selectedOption

    ;wait for vblank
    jsr PPUOff

    ;set screen to black
    lda #$0D
    jsr SetBackgroundColor

  

    jsr StopMusic
    
  
    lda #>RequiemTreble
    sta channel1PtrHi
    lda #<RequiemTreble
    sta channel1PtrLo

    lda #>RequiemBass
    sta channel2PtrHi
    lda #<RequiemBass
    sta channel2PtrLo
    jsr InitAPU

    
	jsr ClearPPU
    jsr ResetScreenAttrs

    lda #<DeathScreenData
    sta srcPtrLo
    lda #>DeathScreenData
    sta srcPtrHi
	jsr RLDecompTileMap


    jsr HideSprites
    jsr SetupTeeth

 
    lda #0
    sta smile

    ;Set NMI Handler
	lda #>DeathNMI
	sta NMIHanlderHi
	lda #<DeathNMI
	sta NMIHanlderLo
     
    ;set the main loop
    lda #>DeathMain
    sta mainFnHi
    lda #<DeathMain
    sta mainFnLo

    jsr PPUOn

    rts

;transition back to the map after a bat sequence
TransitionPlaying

    jsr PPUOff 

    jsr InitSprites ;hide all except 1

    jsr ClearPPU

    jsr WriteBoardToPPU

    jsr SetPlayerCoord

    ;set main
    lda #>Main
    sta mainFnHi
    lda #<Main
    sta mainFnLo

    ;set NMI
    lda #>MainNMI
    sta NMIHanlderHi
    lda #<MainNMI
    sta NMIHanlderLo
    
    jsr RefreshBat
 
    jsr PPUOn

    rts

;shows bat if it's location has been visitted
RefreshBat
   ;if bat room is visitted, show bat
    ldy #ROOM_FLAGS
;    lda [batRoomPtrLo],y
    lda (batRoomPtrLo),y
    and #VISITTED_BIT
    beq :batDone
    jsr ShowBat    
:batDone
    rts

TransitionScoreboard

    jsr PPUOff
   
    lda #0
    sta buttonPresses
    lda #$FF
    sta prevControllerState 

  

    lda #$22
    jsr SetBackgroundColor

    jsr HideSprites
 
    

    lda #>ScoreScreenData
    sta srcPtrHi
    lda #<ScoreScreenData
    sta srcPtrLo
    jsr RLDecompTileMap

    jsr DrawScoreBoard

    ;set bat sprite
    lda #$4D
    sta CURSOR_SPRITE_Y+1
    sta CURSOR_SPRITE2_Y+1


    lda #0
    sta noButton
    lda #CURSOR_PLAY_AGAIN_Y
    sta CURSOR_SPRITE_Y
    lda #90
    sta CURSOR_SPRITE_X
    lda #98
    sta CURSOR_SPRITE2_X

    lda #>ScoreMain
    sta mainFnHi
    lda #<ScoreMain
    sta mainFnLo

    lda #>ScoreboardNMI
    sta NMIHanlderHi
    lda #<ScoreboardNMI
    sta NMIHanlderLo
    
    ;set the cursor position
    ldx #CURSOR_PLAY_AGAIN_Y
    lda selectedOption 
    beq :d
	ldx #CURSOR_SKILL_LEVEL_Y
:d
	stx CURSOR_SPRITE_Y
    stx CURSOR_SPRITE2_Y


    jsr PPUOn

    rts

TransitionReveal

    jsr PPUOff

    jsr HideSprites
    jsr ClearPPU
    jsr ShowBoard
    jsr WriteBoardToPPU
    jsr ShowBat
    jsr ShowWumpus  

    lda #>RevealNMI
    sta NMIHanlderHi
    lda #<RevealNMI
    sta NMIHanlderLo


    lda #>RevealMain
    sta mainFnHi
    lda #<RevealMain
    sta mainFnLo

    lda #0
    sta noButton

    jsr PPUOn

    rts
 
TransitionHelp
    jsr PPUOff
    
    jsr DrawHelpScreen

    lda #>HelpNMI
    sta NMIHanlderHi
    lda #<HelpNMI
    sta NMIHanlderLo

    lda #>HelpMain
    sta mainFnHi
    lda #<HelpMain
    sta mainFnLo 

    jsr PPUOn
    rts
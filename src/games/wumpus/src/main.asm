;main.asm


;main routine while playing the game
Main   
	
	lda inputProcessed
	beq :go ; wait until input available
	jmp :x
:go  ; no handle input

	lda buttonPresses
	and #%10000000
	beq :skipButtonA
	;toggle firing
	lda shooting
	eor #$ff
	sta shooting
    jsr SetPlayerSprite ; refresh image with bow
:skipButtonA	 
	 	
	;don't care about start
	;don't case about select

	lda buttonPresses
	and #BUTTON_UP
	beq :skipButtonUp	
	lda shooting
	bne :shootUp
	jsr MoveUp 
	jmp :p
:shootUp	
	jsr ShootUp	
	jmp :p
:skipButtonUp	

	lda buttonPresses
	and #BUTTON_DOWN
	beq :skipButtonDown	
	lda shooting
	bne :shootDown
	jsr MoveDown 
	jmp :p
:shootDown	
	jsr ShootDown	
	jmp :p
:skipButtonDown

  	lda buttonPresses
	and #BUTTON_LEFT
	beq :skipButtonLeft
	lda shooting
	bne :shootLeft
	jsr MoveLeft 
	jmp :p
:shootLeft	
	jsr ShootLeft	
	jmp :p
:skipButtonLeft

	lda buttonPresses
	and #BUTTON_RIGHT
	beq :skipButtonRight
	lda shooting
	bne :shootRight
	jsr MoveRight 
	jmp :p
:shootRight	
	jsr ShootRight	
	jmp :p
:skipButtonRight
    ;tell controller to read again
:p	lda #1
	sta inputProcessed
:x 	rts

;called after the bat sequence
DropPlayer
  ;pick any random room
  jsr NextRand
  sta playerRoom
  jsr VisitRoom
  lda #1
  sta redraw
  jsr SetPlayerRoomPtr
  ldy #ROOM_FLAGS
;  lda [playerRoomPtrLo],y
  lda (playerRoomPtrLo),y
  and #ANY_HAZARD
  beq  :playerSafe
  jsr CheckHazards	
  jmp :x
:playerSafe
  jsr RepositionBat
  jsr RefreshBat	
  jsr TransitionPlaying
:x  rts


;If wumpus hit, A=0
;otherwise non-zero
HitWumpus
	;unvisit all rooms
	jsr ClearVisittedBits 
	;revisit current room
	ldy #ROOM_FLAGS
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	ora #VISITTED_BIT
;	sta [playerRoomPtrLo],y
	sta (playerRoomPtrLo),y
	;get ptr to room we are shooting into
	ldy direction
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	jsr GetRoomPtr
	;get room at end
	jsr MoveToEndAndSetBit  ; sets destptr
	ldy #ROOM_FLAGS
;	lda [destPtrLo],y
	lda (destPtrLo),y
	and #WUMPUS_BIT
	sta hitWumpusFlag
	rts

;Creates a new game
PlaceHazards
	jsr InitBoard 
	jsr SetNeighbors

	lda skillLevel
	tax
	lda SkillLevels,x
	tax
:lp	
	txa
	pha
	jsr CreateTunnel
	pla
	tax
	dex
	bpl :lp

	jsr PlacePit
	jsr PlacePit
	jsr PlaceWumpus
	jsr PlaceBat
	jsr PlacePlayer
	
	jsr ClearPPU
	jsr WriteBoardToPPU

	lda #>LevelStartMusic
	sta channel1PtrHi
	lda #<LevelStartMusic
	sta channel1PtrLo

	jsr InitAPU
	rts
 
RestartGame
	jsr PPUOff
	jsr StopMusic

	lda #0
	sta controllerState
	sta buttonPresses
	sta shooting
	sta noButton
	sta nmiFlag
	lda #$ff
	sta prevControllerState
	sta controllerState
	lda #20
	sta btnCounter

	jsr HideSprites
	jsr PlaceHazards
	jsr SetPlayerSprite
  
	;reset main
	lda #>Main
	sta mainFnHi
	lda #<Main
	sta mainFnLo
 
	;reset NMI
	lda #>MainNMI
	sta NMIHanlderHi
	lda #<MainNMI
	sta NMIHanlderLo


	jsr PPUOn
	rts

PlayFootSteps
	jsr InitAPU
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
	rts


PlayErrorBeep
	jsr InitAPU
	lda #>ErrorBeep
	sta channel1PtrHi
	lda #<ErrorBeep
	sta channel1PtrLo
	lda #0
	sta channel1Index
	rts

SkillLevels
	db 5, 11,25

;shootself.asm


ShootSelfNMI

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

ShootSelfMain
    ;wait for nmi
    lda #0
    sta nmiFlag
:lp
    jsl yield
    lda nmiFlag
    beq :lp

    inc ARROW_SPRITES_X
    inc ARROW_SPRITES_X
    inc ARROW_SPRITES_X+4
    inc ARROW_SPRITES_X+4

    lda ARROW_SPRITES_X
    cmp #120
    bne :x
    jsr DeathTransition
:x  rts


TransitionShootSelf

    jsr PPUOff

    ;draw horizontal tunnel
    jsr ClearPPU
    jsr DrawHorizontalTunnel

     

    ;put arrow at left edge
    lda direction
    pha
    lda #RIGHT
    sta direction
    jsr SetupArrow
    pla
    sta direction
    ;draw the player
    ldy #0
:lp
    lda LargePlayerData,y
    sta LARGE_PLAYER_Y,y
    iny 
    cpy #32
    bne :lp

  ;set main
    lda #>ShootSelfMain
    sta mainFnHi
    lda #<ShootSelfMain
    sta mainFnLo

    ;set NMI
    lda #>ShootSelfNMI
    sta NMIHanlderHi
    lda #<ShootSelfNMI
    sta NMIHanlderLo


    jsr PPUOn

    rts


;y,sprite,attrs,x for 8 large player sprites
LargePlayerData
    db 111,1,3,128
    db 111,2,3,136    

    db 119,17,3,128
    db 119,18,3,136        

    db 127,33,3,128
    db 127,34,3,136            

    db 135,49,3,128
    db 135,50,3,136            
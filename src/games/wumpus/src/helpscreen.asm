

HelpNMI
    jsr ReadController

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
;    rti
    rts


HelpMain
    lda #0
    sta nmiFlag
:lp
    jsl yield
    lda nmiFlag
    beq :lp

    lda buttonPresses
    beq :x 
    jsr TransitionStartScreen
:x    rts    


DrawHelpScreen
	jsr HideSprites

	lda #>HelpScreenData
    sta srcPtrHi
    lda #<HelpScreenData
    sta srcPtrLo
    jsr RLDecompTileMap

    rts

 

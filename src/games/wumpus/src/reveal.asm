

RevealMain
    lda #0
    sta nmiFlag
:lp
    jsl yield
    lda nmiFlag
    beq :lp

    lda buttonPresses
    and #BUTTON_A.BUTTON_B
    beq :x
    jsr TransitionScoreboard
:x	rts


RevealNMI
    LDA #$00        ;;tell the ppu there is no background scrolling
    jsr STA_2005
    jsr STA_2005

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
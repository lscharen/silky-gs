; A = 0 turn off background
; A > 0 turn on background
EnableBackground
    cmp   #0
    beq   :turn_off
    lda   #CTRL_BKGND_ENABLE
    tsb   GTEControlBits
    bra   :done
:turn_off
    lda   #CTRL_BKGND_ENABLE
    trb   GTEControlBits
:done
    rts

; A = 0 turn off sprites
; A > 0 turn on sprites
EnableSprites
    cmp   #0
    beq   :turn_off
    lda   #CTRL_SPRITE_ENABLE
    tsb   GTEControlBits
    bra   :done
:turn_off
    lda   #CTRL_SPRITE_ENABLE
    trb   GTEControlBits
:done
    rts
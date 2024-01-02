; A = 0 turn off background
; A = 1 turn on background
EnableBackground
    cmp #0
    beq     :turn_off
    lda     #CTRL_BKGND_DISABLE
    trb     GTEControlBits
    bra     :done
:turn_off
    lda     #CTRL_BKGND_DISABLE
    tsb     GTEControlBits
:done
    rts
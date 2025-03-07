; A = 0 turn off background
; A > 0 turn on background
EnableBackground
    cmp   #0
    beq   :turn_off
    lda   #CTRL_BKGND_ENABLE
    tsb   GTEControlBits
    bne   :done
    lda   #DIRTY_BIT_BG0_REFRESH     ; If the state of the background enable bit changed, trigger a refresh
    tsb   DirtyBits
    rts

:turn_off
    lda   #CTRL_BKGND_ENABLE
    trb   GTEControlBits
    beq   :done
    lda   #DIRTY_BIT_BG0_REFRESH     ; If the state of the background enable bit changed, trigger a refresh
    tsb   DirtyBits

:done
    rts

; A = 0 turn off sprites
; A > 0 turn on sprites
EnableSprites
    cmp   #0
    beq   :turn_off
    lda   #CTRL_SPRITE_ENABLE
    tsb   GTEControlBits
    rts

:turn_off
    lda   #CTRL_SPRITE_ENABLE
    trb   GTEControlBits
    rts
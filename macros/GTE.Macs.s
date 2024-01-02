jne     mac
        beq   *+5
        jmp   ]1
        <<<

jeq     mac
        bne   *+5
        jmp   ]1
        <<<

_Deref  MAC
        phb                   ; save caller's data bank register
        pha                   ; push high word of handle on stack
        plb                   ; sets B to the bank byte of the pointer
        lda   |$0002,x        ; load the high word of the master pointer
        pha                   ; and save it on the stack
        lda   |$0000,x        ; load the low word of the master pointer
        tax                   ; and return it in X
        pla                   ; restore the high word in A
        plb                   ; pull the handle's high word high byte off the
                                ; stack
        plb                   ; restore the caller's data bank register    
        <<<
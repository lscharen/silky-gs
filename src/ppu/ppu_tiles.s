
; Copies the screen data into a buffer to be restored later.  The save buffer is just a chunk of Bank 0 memory
; that is 4kb + 256b.  The extra space is because the address of the 8x8 block is pushed last and an interrupt
; may happen during this process, so we need to keep some extra stack space available.
;
; In the worst case, we may have to save 64 8x16 sprites, which corresponds to 64 * 4 * 16 = 4096 bytes, plus
; 4 bytes per sprite for the screen and shadow addresses, which adds up to 256 additional bytes
;
; Input: X register is the SHR address
; Input: Y register is the Clamped SHR address
          mx  %00
saveTileFromScreen16

          jsr   saveTileFromScreen8
          txa
          clc
          adc   #8*160
          tax
          tya
          clc
          adc   #8*160
          tay

        mx    %00
saveTileFromScreen8

          tsc
          sta   sprTmp0                                ; Save the current stack in the y-register

          lda   SprSaveAddr
          tcs                                          ; Set the stack to the save buffer area
          clc

]line     equ   0
          lup   8

          ldal  $010000+{]line*SHR_LINE_WIDTH},x       ; Load the screen data
          pha                                          ; Save onto the stack
          ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
          pha

]line     equ   ]line+1
          --^

          phy                                          ; Save the SHR screen address for shadowing
          phx                                          ; Save the SHR screen address of the 8x8 block
          tsc
          sta   SprSaveAddr

          lda   sprTmp0                                ; Restore the original stack
          tcs

          rts

sprBlockAddr ds 64*2           ; Maximum of 64 8x8 blocks, each with a 16-bit address 

; Expose the 8x8 blocks from the list populated by saveTileFromScreen.
        mx  %00
exposeTilesToScreen

        ldy   SprAddrCount     ; Number of sprite block addresses (x2)
        bne   :ok
        rts

:ok
        dey                    ; Can be done in any order
        dey

:loop
        ldx   sprBlockAddr,y   ; Load the screen address
]line   equ   7
        lup   8

        ldal  $010000+{]line*SHR_LINE_WIDTH},x
        stal  $010000+{]line*SHR_LINE_WIDTH},x
        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line   equ   ]line-1
        --^

        dey
        dey
        bmi   :out
        brl   :loop            ; Are there more blocks to expose?
:out
        stz   SprAddrCount
        rts

; Restores all of the saved tiles to the screen using the data from the stack.  The stack
; format is a set of nine 16-bit values.
;
;   <base_address> <tile_data x 8>
;
; The data is pushed onto the stack in top-down, left-right order so it needs to be restored
; in bottom-up, right-left order.  There can be at most 128 8x8 pixel tiles saved, so the
; stack depth is at most 128 * 9 * 2 = 2304 bytes (11 bits).

        mx    %00
restoreTilesToScreen

        ldy   #0

        lda   SprSaveAddr                            ; If the stack is empty, do nothing
        cmp   SprSaveTop
        beq   :done

        tsx
        stx   tmp0
        tcs

:loop
        plx                                          ; Pop the SHR screen address
        pla                                          ; Pop the SHR shadow address
        sta   sprBlockAddr,y                         ; Save it for later use

]line   equ   7
        lup   8

        pla                                          ; Load the screen data (5 cycles)
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; And write back to the screen (reverse order)
        pla
        stal  $010000+{]line*SHR_LINE_WIDTH},x

]line   equ   ]line-1
        --^

        iny
        iny

:test
        tsc
        cmp   SprSaveTop
        bcc   :loop

        sta   SprSaveAddr                            ; Update the save stack pointer to indicate an empty buffer

        lda   tmp0                                   ; Restore the original stack pointer
        tcs

:done
        sty   SprAddrCount
        rts

; For debugging. Render tiles with a border around them.
outlineColor ds 2

        mx    %00
drawOutline
        ldal  outlineColor
        stal  $010000+{0*SHR_LINE_WIDTH},x
        stal  $010000+{0*SHR_LINE_WIDTH}+2,x
        stal  $010000+{7*SHR_LINE_WIDTH},x
        stal  $010000+{7*SHR_LINE_WIDTH}+2,x

]line   equ   1
        lup   6
        ldal  $010000+{]line*SHR_LINE_WIDTH},x
        eorl  outlineColor
        and   #$00F0
        eorl  $010000+{]line*SHR_LINE_WIDTH},x
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
        eorl  outlineColor
        and   #$0F00
        eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x
]line   equ   ]line+1
        --^
        rts

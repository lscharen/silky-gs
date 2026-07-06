
; Define the opcodes directly so we can use then in a macro.  The bracket from long-indirect addressing, e.g. [],
; causes the macro processor to get confused since variables can be written as "]x"
LDA_IND_LONG_IDX equ $B7
ORA_IND_LONG_IDX equ $17
AND_IND_LONG_IDX equ $37

        mx    %00
drawClippedTileToScreenHV
        adc   #64

drawClippedTileToScreenV
        tax
        jsr   _copyTileToBufferV
        bra   _clippedCommon

drawClippedTileToScreenH
        adc   #64

drawClippedTileToScreen
        tax
        jsr   _copyTileToBuffer

_clippedCommon
        jsr   clipBuffer
        txy
        ldx   sprTmp1
        jmp   _copyBufferToScreen

; Drawing to the screen can happen two ways.
;
; If the sprite is being drawn this way, then the compiled version cannot be used for some reason.  To flexibly
; handle corner cases, the sprite data and mask are copied into temporary direct page space and then copied
; to the screen.  This helps maximize the use of registers and allows the data or mask to be altered before
; drawing, if needed.
        mx    %00
copyTileToBufferHV
        adc   #64

copyTileToBufferV
        tax                                          ; Put the sprite data address in the register

_copyTileToBufferV
]line   equ   0
        lup   8

        ldy:  {7-]line*4},x                          ; Load the tile data lookup value
        db    LDA_IND_LONG_IDX,ActivePtr             ; Lookup the data from the swizzle table
        sta   blttmp+{]line*4}                       ; Save on the direct page

        ldy:  {7-]line*4}+2,x
        db    LDA_IND_LONG_IDX,ActivePtr
        sta   blttmp+{]line*4}+2

]line   equ   ]line+1
        --^
        rts

        mx    %00
copyTileToBufferH
        adc   #64

copyTileToBuffer
        tax                                          ; Put the sprite data address in the register

_copyTileToBuffer
]line   equ   0
        lup   8

        ldy:  {]line*4},x                            ; Load the tile data lookup value
        db    LDA_IND_LONG_IDX,ActivePtr             ; Lookup the data from the swizzle table
        sta   blttmp+{]line*4}                       ; Save on the direct page

        ldy:  {]line*4}+2,x
        db    LDA_IND_LONG_IDX,ActivePtr
        sta   blttmp+{]line*4}+2

]line   equ   ]line+1
        --^
        rts

; Blit from the direct page buffer to the screen using the tile mask in the data bank
;
; A = tile address
; X = screen address
        mx    %00
copyBufferToScreenH
        adc   #64

        mx    %00
copyBufferToScreen
        tay

        mx    %00
_copyBufferToScreen
]line   equ   0
        lup   8

        ldal  $010000+{]line*SHR_LINE_WIDTH},x       ; Load the screen data
        and:  {]line*4}+32,y                         ; mask
        ora   blttmp+{]line*4}
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; Load the screen data
        and:  {]line*4}+32+2,y                       ; mask
        ora   blttmp+{]line*4}+2
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line   equ   ]line+1
        --^
        rts

        mx    %00
_copyBufferToScreenNoMask
]line   equ   0
        lup   8

        lda   blttmp+{]line*4}
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        lda   blttmp+{]line*4}+2
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line   equ   ]line+1
        --^
        rts

; If the tile needs to be clipped, then set the pixels in the direct page buffer to zero.  This is not exact clipping, but
; creates the illusion of the sprite being clipped.  The only time this actually matters is when dirty rendering is engaged
; and a sprite is placed with x in [125, 126, 127].
        mx    %00
clipBuffer
        lda   sprTmp4
        bne   *+3
        rts
        dec
        beq   clipBuffer125
        dec
        beq   clipBuffer126
;        bra   clipBuffer127      ; Fall through

clipBuffer127
        sep   #$20
]line   equ   0
        lup   8
        stz   blttmp+{]line*4}+1
]line   equ   ]line+1
        --^
        rep   #$20

clipBuffer126
]line   equ   0
        lup   8
        stz   blttmp+{]line*4}+2
]line   equ   ]line+1
        --^
        rts

clipBuffer125
        sep   #$20
]line   equ   0
        lup   8
        stz   blttmp+{]line*4}+3
]line   equ   ]line+1
        --^
        rep   #$20
        rts

        mx    %00
drawTileToScreenH
          adc   #64

drawTileToScreen
          sta   sprTmp0

]line     equ   0
          lup   8

          ldx   sprTmp0
          ldy:  {]line*4},x                            ; Load the tile data lookup value
          lda:  {]line*4}+32,x                         ; Load the mask value
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH},x       ; Mask against the screen
          db    ORA_IND_LONG_IDX,ActivePtr             ; Merge in the remapped tile data
          stal  $010000+{]line*SHR_LINE_WIDTH},x

          ldx   sprTmp0
          ldy:  {]line*4}+2,x
          lda:  {]line*4}+32+2,x
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH}+2,x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line     equ   ]line+1
          --^

          rts

        mx    %00
drawTileToScreenHV
          adc   #64

drawTileToScreenV

          sta   sprTmp0

]line     equ   0
          lup   8

          ldx   sprTmp0
          ldy:  {{7-]line}*4},x
          lda:  {{7-]line}*4}+32,x
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH},x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH},x

          ldx   sprTmp0
          ldy:  {{7-]line}*4}+2,x
          lda:  {{7-]line}*4}+32+2,x
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH}+2,x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line     equ   ]line+1
          --^

          rts

        mx    %00
drawClippedTileToScreenPHV
drawClippedTileToScreenPH

        adc   #64

drawClippedTileToScreenPV
drawClippedTileToScreenP

        tay
        ldx   sprTmp1

        jsr   _copyMaskToBufferP      ; Build a screen mask in the direct page
        jsr   clipBuffer
;        jmp   _copyBufferToScreenP

        mx    %00
_copyBufferToScreenP
        ldx   sprTmp0
]line   equ   0
        lup   8

        lda   blttmp+{]line*4}+0                    ; Early out for zero masks (no sprite data will show through)
        beq   zl

        ldy:  {]line*4}+0,x                         ; Load the packed sprite data
        ldx   sprTmp1
        db    AND_IND_LONG_IDX,ActivePtr
        oral  $010000+{]line*SHR_LINE_WIDTH}+0,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+0,x

        ldx   sprTmp0
zl
        lda   blttmp+{]line*4}+2
        beq   zr

        ldy:  {]line*4}+2,x
        ldx   sprTmp1
        db    AND_IND_LONG_IDX,ActivePtr
        oral  $010000+{]line*SHR_LINE_WIDTH}+2,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

        ldx   sprTmp0
zr
]line   equ   ]line+1
        --^
        rts

        mx    %00
_copyMaskToBufferP
]line   equ   0
        lup   8
        ldal  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; create mask where 0 = !0 and 0 = F.
        beq   zero_left
        bit   #$F000
        beq   *+5
        ora   #$F000     ; 3+3 / 3+2+3 = 6 / 8 = ~7 cycles per pixel average
        bit   #$0F00
        beq   *+5
        ora   #$0F00
        bit   #$00F0
        beq   *+5
        ora   #$00F0
        bit   #$000F
        beq   *+5
        ora   #$000F
zero_left
        sta   blttmp+{]line*4}

        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; create mask where 0 = !0 and 0 = F.
        beq   zero_right
        bit   #$F000
        beq   *+5
        ora   #$F000     ; 3+3 / 3+2+3 = 6 / 8 = ~7 cycles per pixel average
        bit   #$0F00
        beq   *+5
        ora   #$0F00
        bit   #$00F0
        beq   *+5
        ora   #$00F0
        bit   #$000F
        beq   *+5
        ora   #$000F
zero_right
        sta   blttmp+{]line*4}+2

]line   equ   ]line+1
        --^
        rts

        mx    %00
drawTileToScreenPHV
drawTileToScreenPH

        adc   #64

        mx    %00
drawTileToScreenPV
drawTileToScreenP

          sta   sprTmp0
          ldx   sprTmp1                                ; Get the screen address

]line     equ   0
          lup   8

          ldal  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; create mask where 0 = !0 and 0 = F.
          beq   zero_left
          bit   #$F000
          beq   *+5
          ora   #$F000     ; 3+3 / 3+2+3 = 6 / 8 = ~7 cycles per pixel average
          bit   #$0F00
          beq   *+5
          ora   #$0F00
          bit   #$00F0
          beq   *+5
          ora   #$00F0
          bit   #$000F
          beq   *+5
          ora   #$000F
zero_left
          eor   #$FFFF
          beq   skip_left                              ; zero means no sprite data will show through

          ldx   sprTmp0                                ; delay loading the sprite data until needed
          ldy:  {]line*4}+0,x                          ; load the lookup value
          ldx   sprTmp1                                ; restore the screen address

          db    AND_IND_LONG_IDX,ActivePtr             ; Apply against the sprite data
          oral  $010000+{]line*SHR_LINE_WIDTH}+0,x
          stal  $010000+{]line*SHR_LINE_WIDTH}+0,x

skip_left
          ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; create mask where F = !0 and 0 = 0.
          beq   zero_right
          bit   #$F000
          beq   *+5
          ora   #$F000
          bit   #$0F00
          beq   *+5
          ora   #$0F00
          bit   #$00F0
          beq   *+5
          ora   #$00F0
          bit   #$000F
          beq   *+5
          ora   #$000F
zero_right
          eor   #$FFFF
          beq   skip_right

          ldx   sprTmp0
          ldy:  {]line*4}+2,x                          ; load the lookup value
          ldx   sprTmp1                                ; restore the screen address

          db    AND_IND_LONG_IDX,ActivePtr
          oral  $010000+{]line*SHR_LINE_WIDTH}+2,x
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x
skip_right

]line     equ   ]line+1
          --^
          rts

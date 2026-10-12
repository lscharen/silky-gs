; ppu_tiles.s - Sprite debugging (SHOW_DEBUG_VARS)

        DO    SHOW_DEBUG_VARS
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
        FIN

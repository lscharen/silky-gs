; This is an inline, unrolled version of CopyRTableToStkAddr
]line                equ   119
                     lup   120
                     ldal  RTable+{]line*2},x
                     sta   {]line*_LINE_SPAN},y
]line                equ   ]line-1
                     --^
copyr_bottom
                     rts

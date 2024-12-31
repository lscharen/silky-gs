; All of the data tables and structures

; A table of pre-multiplied values of 160
Mul160Tbl
]step       equ   0
            lup   256
            dw    160*]step
]step       equ   ]step+1
            --^

; The blitter table (BTable) is a double-length table that holds the full 4-byte address of each
; line of the blit fields.  We decompose arrays of pointers into separate high and low words so
; that everything can use the same indexing offsets
BTableHigh  ds    2*2*240
BTableLow   ds    2*2*240

; Table of BRA instructions that are used to exit the code field. There are separate tables
; for the odd and even cases since their wrap-around behavior and transition point from negative
; to positive branch offsets are different
;
; The code template is 64 PEA instructions with exit code around each.  The code is structured
; such that there are two rows ajacent to each other to represent the two NES nametables.
;
;            jmp  exit_even
;            jmp  exit_odd
; prev_table pea  $0000             ; word 0
;            ...
;            pea  $0000             ; word 63
;            jmp  next_table
;            jmp  exit_even
;            jmp  exit_odd
; <padding>
;            jmp  exit_even
;            jmp  exit_odd
; next_table pea  $0000              ; word 0
;            ...
;            pea  $0000              ; word 63
;            <exit_odd_code>
;            jmp  prev_table
;            jmp  exit_even
;            jmp  exit_odd

* CodeFieldBRA
*             bra   *+6         ; 63 -- need to skip over the JMP loop that passes control back
*             bra   *+9         ; 62
*             bra   *+12        ; 61
*             bra   *+15        ; 60
*             bra   *+18        ; 59
*             bra   *+21        ; 58
*             bra   *+24        ; 57
*             bra   *+27        ; 56
*             bra   *+30        ; 55
*             bra   *+33        ; 54
*             bra   *+36        ; 53
*             bra   *+39        ; 52
*             bra   *+42        ; 51
*             bra   *+45        ; 50
*             bra   *+48        ; 49
*             bra   *+51        ; 48
*             bra   *+54        ; 47
*             bra   *+57        ; 46
*             bra   *+60        ; 45
*             bra   *+63        ; 44
*             bra   *+66        ; 43
*             bra   *+69        ; 42
*             bra   *+72        ; 41
*             bra   *+75        ; 40
*             bra   *+78        ; 39
*             bra   *+81        ; 38
*             bra   *+84        ; 37
*             bra   *+87        ; 36
*             bra   *+90        ; 35
*             bra   *+93        ; 34
*             bra   *+96        ; 33
*             bra   *+99        ; 32
*             bra   *+102       ; 31
*             bra   *+105       ; 30
*             bra   *+108       ; 29
*             bra   *+111       ; 28
*             bra   *+114       ; 27
*             bra   *+117       ; 26
*             bra   *+120       ; 25
*             bra   *+123       ; 24
*             bra   *+126       ; 23

*             bra   *-69        ; 22
*             bra   *-66        ; 21
*             bra   *-63        ; 20
*             bra   *-60        ; 19
*             bra   *-57        ; 18
*             bra   *-54        ; 17
*             bra   *-51        ; 16
*             bra   *-48        ; 15
*             bra   *-45        ; 14
*             bra   *-42        ; 13
*             bra   *-39        ; 12
*             bra   *-36        ; 11
*             bra   *-33        ; 10
*             bra   *-30        ; 9
*             bra   *-27        ; 8
*             bra   *-24        ; 7
*             bra   *-21        ; 6
*             bra   *-18        ; 5
*             bra   *-15        ; 4
*             bra   *-12        ; 3
*             bra   *-9         ; 2
*             bra   *-6         ; 1
*             bra   *-3         ; 0 -- branch back 3


            bra   *-6
CodeFieldEvenBRA
            bra   *+6         ; 63 -- need to skip over the JMP loop that passes control back
            bra   *+9         ; 62
            bra   *+12        ; 61
            bra   *+15        ; 60
            bra   *+18        ; 59
            bra   *+21        ; 58
            bra   *+24        ; 57
            bra   *+27        ; 56
            bra   *+30        ; 55
            bra   *+33        ; 54
            bra   *+36        ; 53
            bra   *+39        ; 52
            bra   *+42        ; 51
            bra   *+45        ; 50
            bra   *+48        ; 49
            bra   *+51        ; 48
            bra   *+54        ; 47
            bra   *+57        ; 46
            bra   *+60        ; 45
            bra   *+63        ; 44
            bra   *+66        ; 43
            bra   *+69        ; 42
            bra   *+72        ; 41
            bra   *+75        ; 40
            bra   *+78        ; 39
            bra   *+81        ; 38
            bra   *+84        ; 37
            bra   *+87        ; 36
            bra   *+90        ; 35
            bra   *+93        ; 34
            bra   *+96        ; 33
            bra   *+99        ; 32
            bra   *+102       ; 31
            bra   *+105       ; 30
            bra   *+108       ; 29
            bra   *+111       ; 28
            bra   *+114       ; 27
            bra   *+117       ; 26
            bra   *+120       ; 25
            bra   *+123       ; 24
            bra   *+126       ; 23

            bra   *-72        ; 22
            bra   *-69        ; 21
            bra   *-66        ; 20
            bra   *-63        ; 19
            bra   *-60        ; 18
            bra   *-57        ; 17
            bra   *-54        ; 16
            bra   *-51        ; 15
            bra   *-48        ; 14
            bra   *-45        ; 13
            bra   *-42        ; 12
            bra   *-39        ; 11
            bra   *-36        ; 10
            bra   *-33        ; 9
            bra   *-30        ; 8
            bra   *-27        ; 7
            bra   *-24        ; 6
            bra   *-21        ; 5
            bra   *-18        ; 4
            bra   *-15        ; 3
            bra   *-12        ; 2
            bra   *-9         ; 1
            bra   *-6         ; 0     ; branch over the "jmp exit_odd" instruction

            bra   *+6         ; 63 -- need to skip over the JMP loop that passes control back
            bra   *+9         ; 62
            bra   *+12        ; 61
            bra   *+15        ; 60
            bra   *+18        ; 59
            bra   *+21        ; 58
            bra   *+24        ; 57
            bra   *+27        ; 56
            bra   *+30        ; 55
            bra   *+33        ; 54
            bra   *+36        ; 53
            bra   *+39        ; 52
            bra   *+42        ; 51
            bra   *+45        ; 50
            bra   *+48        ; 49
            bra   *+51        ; 48
            bra   *+54        ; 47
            bra   *+57        ; 46
            bra   *+60        ; 45
            bra   *+63        ; 44
            bra   *+66        ; 43
            bra   *+69        ; 42
            bra   *+72        ; 41
            bra   *+75        ; 40
            bra   *+78        ; 39
            bra   *+81        ; 38
            bra   *+84        ; 37
            bra   *+87        ; 36
            bra   *+90        ; 35
            bra   *+93        ; 34
            bra   *+96        ; 33
            bra   *+99        ; 32
            bra   *+102       ; 31
            bra   *+105       ; 30
            bra   *+108       ; 29
            bra   *+111       ; 28
            bra   *+114       ; 27
            bra   *+117       ; 26
            bra   *+120       ; 25
            bra   *+123       ; 24
            bra   *+126       ; 23

            bra   *-72        ; 22
            bra   *-69        ; 21
            bra   *-66        ; 20
            bra   *-63        ; 19
            bra   *-60        ; 18
            bra   *-57        ; 17
            bra   *-54        ; 16
            bra   *-51        ; 15
            bra   *-48        ; 14
            bra   *-45        ; 13
            bra   *-42        ; 12
            bra   *-39        ; 11
            bra   *-36        ; 10
            bra   *-33        ; 9
            bra   *-30        ; 8
            bra   *-27        ; 7
            bra   *-24        ; 6
            bra   *-21        ; 5
            bra   *-18        ; 4
            bra   *-15        ; 3
            bra   *-12        ; 2
            bra   *-9         ; 1
            bra   *-6         ; 0     ; branch over the "jmp exit_odd" instruction


            bra   *-3
CodeFieldOddBRA
            bra   *+13        ; 63 -- need to skip over two JMP instructions and a PEA, plut one padding byte
            bra   *+16        ; 62
            bra   *+19        ; 61
            bra   *+22        ; 60
            bra   *+25        ; 59
            bra   *+28        ; 58
            bra   *+31        ; 57
            bra   *+34        ; 56
            bra   *+37        ; 55
            bra   *+40        ; 54
            bra   *+43        ; 53
            bra   *+46        ; 52
            bra   *+49        ; 51
            bra   *+52        ; 50
            bra   *+55        ; 49
            bra   *+58        ; 48
            bra   *+61        ; 47
            bra   *+64        ; 46
            bra   *+67        ; 45
            bra   *+70        ; 44
            bra   *+73        ; 43
            bra   *+76        ; 42
            bra   *+79        ; 41
            bra   *+82        ; 40
            bra   *+85        ; 39
            bra   *+88        ; 38
            bra   *+91        ; 37
            bra   *+94        ; 36
            bra   *+97        ; 35
            bra   *+100        ; 34
            bra   *+103       ; 33
            bra   *+106       ; 32
            bra   *+109       ; 31
            bra   *+112       ; 30

            bra   *-90        ; 29
            bra   *-87        ; 28
            bra   *-84        ; 27
            bra   *-81        ; 26
            bra   *-78        ; 25
            bra   *-75        ; 24
            bra   *-72        ; 23
            bra   *-69        ; 22
            bra   *-66        ; 21
            bra   *-63        ; 20
            bra   *-60        ; 19
            bra   *-57        ; 18
            bra   *-54        ; 17
            bra   *-51        ; 16
            bra   *-48        ; 15
            bra   *-45        ; 14
            bra   *-42        ; 13
            bra   *-39        ; 12
            bra   *-36        ; 11
            bra   *-33        ; 10
            bra   *-30        ; 9
            bra   *-27        ; 8
            bra   *-24        ; 7
            bra   *-21        ; 6
            bra   *-18        ; 5
            bra   *-15        ; 4
            bra   *-12        ; 3
            bra   *-9         ; 2
            bra   *-6         ; 1
            bra   *-3         ; 0 -- branch back 3

            bra   *+13        ; 63 -- need to skip over two JMP instructions and a PEA, plut one padding byte
            bra   *+16        ; 62
            bra   *+19        ; 61
            bra   *+22        ; 60
            bra   *+25        ; 59
            bra   *+28        ; 58
            bra   *+31        ; 57
            bra   *+34        ; 56
            bra   *+37        ; 55
            bra   *+40        ; 54
            bra   *+43        ; 53
            bra   *+46        ; 52
            bra   *+49        ; 51
            bra   *+52        ; 50
            bra   *+55        ; 49
            bra   *+58        ; 48
            bra   *+61        ; 47
            bra   *+64        ; 46
            bra   *+67        ; 45
            bra   *+70        ; 44
            bra   *+73        ; 43
            bra   *+76        ; 42
            bra   *+79        ; 41
            bra   *+82        ; 40
            bra   *+85        ; 39
            bra   *+88        ; 38
            bra   *+91        ; 37
            bra   *+94        ; 36
            bra   *+97        ; 35
            bra   *+100        ; 34
            bra   *+103       ; 33
            bra   *+106       ; 32
            bra   *+109       ; 31
            bra   *+112       ; 30

            bra   *-90        ; 29
            bra   *-87        ; 28
            bra   *-84        ; 27
            bra   *-81        ; 26
            bra   *-78        ; 25
            bra   *-75        ; 24
            bra   *-72        ; 23
            bra   *-69        ; 22
            bra   *-66        ; 21
            bra   *-63        ; 20
            bra   *-60        ; 19
            bra   *-57        ; 18
            bra   *-54        ; 17
            bra   *-51        ; 16
            bra   *-48        ; 15
            bra   *-45        ; 14
            bra   *-42        ; 13
            bra   *-39        ; 12
            bra   *-36        ; 11
            bra   *-33        ; 10
            bra   *-30        ; 9
            bra   *-27        ; 8
            bra   *-24        ; 7
            bra   *-21        ; 6
            bra   *-18        ; 5
            bra   *-15        ; 4
            bra   *-12        ; 3
            bra   *-9         ; 2
            bra   *-6         ; 1
            bra   *-3         ; 0 -- branch back 3

; Map the NES PPU lines to valid PEA field lines.  It's possible to tell the NES to start
; drawing in the tile attribute space ($2nC0).  We have a lookup table to map the whole
; 512 line PPU range into the valid 480 PEA lines
NES2Virtual
]line       =     0
            lup   240
            dw    ]line
]line       =     ]line+1
            --^
]line       =     224
            lup   16
            dw    ]line
]line       =     ]line+1
            --^
]line       =     240
            lup   240
            dw    ]line
]line       =     ]line+1
            --^
]line       =     464
            lup   16
            dw    ]line
]line       =     ]line+1
            --^

; Col2PageOffset
;
; Takes a byte coordinate and returns the page offset to the PEA instruction
; in the blitter code page that holds the data byte.  The coordinates are in
; the range 0 to 127.  This table handles even and odd cases.
;
; byte 0 (left edge) -> 3 * 63 (last word)
; byte 1 -> 3 * 63
; byte 2 -> 3 * 62
; ...
; byte 125 -> 3
; byte 126 -> 0 (first word)
; byte 127 -> 0 (first word)
;                 dw    _PEA_OFFSET
;Col2PageOffset
;]coord           equ   0
;                 lup   64
;                 dw    _PEA_OFFSET+{PER_TILE_SIZE*{63-]coord}}
;]coord           equ   ]coord+1
;                 --^
;                 dw     _PEA_OFFSET+{PER_TILE_SIZE*63}

; Col2CodeOffset
;
; Takes a column number (0 - 63) and returns the offset into the blitter code
; template, relative to the BTableLow address.
;
; The table values are pre-reversed so that loop can go in logical order 0, 2, 4, ...
; and the resulting offsets will map to the code instructions in right-to-left order.
;
; Remember, because the data is pushed on to the stack, the last instruction, which is
; in the highest memory location, pushed data that appears on the left edge of the screen.

                 dw    0
Col2CodeOffset
]coord           equ   0
                 lup   64
                 dw    {PER_TILE_SIZE*{63-]coord}}
]coord           equ   ]coord+1
                 --^
]coord           equ   0
                 lup   64
                 dw    256+{PER_TILE_SIZE*{63-]coord}}
]coord           equ   ]coord+1
                 --^
]coord           equ   0
                 lup   64
                 dw    {PER_TILE_SIZE*{63-]coord}}
]coord           equ   ]coord+1
                 --^
                 dw     {PER_TILE_SIZE*63}

*                   dw    256+_CODE_TOP     ; wrap around
* Col2CodeOffset
* ; The first 64 values are for the words in the first nametable space.
* ]step             equ   0
*                   lup   64
*                   dw    _CODE_TOP+{{63-]step}*PER_TILE_SIZE}
* ]step             equ   ]step+1
*                   --^
* ; The second 64 values are for the words in the second nametable space. These are all exactly $100 bytes
* ; past the other nametable
* ]step             equ   0
*                   lup   64
*                   dw    256+_CODE_TOP+{{63-]step}*PER_TILE_SIZE}
* ]step             equ   ]step+1
*                   --^
*                   dw    _CODE_TOP+{63*PER_TILE_SIZE}


; Table of address for the left edge of the 200 physical lines on the SHR graphics screen
]step             equ   $2000
ScreenAddr        ENT
                  lup   200
                  dw    ]step
]step             =     ]step+160
                  --^

; Table of addresses for the right edge of the current screen rectangle.  This is not the same size as
; the physical screen and will be double the length of the ScreenHeight, up to a maximum of 200 lines
RTable            ds    400
                  ds    400
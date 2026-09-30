; All of the data tables and structures

; A table of pre-multiplied values of 160
Mul160Tbl
]step       equ   0
            lup   256
            dw    160*]step
]step       equ   ]step+1
            --^

; The blitter table (BTable) holds the full 4-byte address of the even page (P0) of each of the 240
; PEA rows.  The row for CIRAM page 1 is at +$0100.  The high and low words are kept in separate
; arrays so everything can use the same index (2 x row).  Filled once by _InitBTable (ppu_init.s).
BTableHigh  ds    2*240
BTableLow   ds    2*240

; Tables of BRA instructions that are patched in to exit the code field, indexed by 2 x the column
; within the page (0 - 63) of the left-most word on the screen.  The BRA replaces that word's PEA
; opcode and branches to whichever exit_even / exit_odd JMP is in range.  Both pages of a row use
; the same offsets, so the same table works in either page.  See TemplateLite.Macs.s.
CodeFieldEvenBRA
            dfb   $80,$09     ; col 0: $E1 -> $EC
            dfb   $80,$0C     ; col 1: $DE -> $EC
            dfb   $80,$0F     ; col 2: $DB -> $EC
            dfb   $80,$12     ; col 3: $D8 -> $EC
            dfb   $80,$15     ; col 4: $D5 -> $EC
            dfb   $80,$18     ; col 5: $D2 -> $EC
            dfb   $80,$1B     ; col 6: $CF -> $EC
            dfb   $80,$1E     ; col 7: $CC -> $EC
            dfb   $80,$21     ; col 8: $C9 -> $EC
            dfb   $80,$24     ; col 9: $C6 -> $EC
            dfb   $80,$27     ; col 10: $C3 -> $EC
            dfb   $80,$2A     ; col 11: $C0 -> $EC
            dfb   $80,$2D     ; col 12: $BD -> $EC
            dfb   $80,$30     ; col 13: $BA -> $EC
            dfb   $80,$33     ; col 14: $B7 -> $EC
            dfb   $80,$36     ; col 15: $B4 -> $EC
            dfb   $80,$39     ; col 16: $B1 -> $EC
            dfb   $80,$3C     ; col 17: $AE -> $EC
            dfb   $80,$3F     ; col 18: $AB -> $EC
            dfb   $80,$42     ; col 19: $A8 -> $EC
            dfb   $80,$45     ; col 20: $A5 -> $EC
            dfb   $80,$48     ; col 21: $A2 -> $EC
            dfb   $80,$4B     ; col 22: $9F -> $EC
            dfb   $80,$4E     ; col 23: $9C -> $EC
            dfb   $80,$51     ; col 24: $99 -> $EC
            dfb   $80,$54     ; col 25: $96 -> $EC
            dfb   $80,$57     ; col 26: $93 -> $EC
            dfb   $80,$5A     ; col 27: $90 -> $EC
            dfb   $80,$5D     ; col 28: $8D -> $EC
            dfb   $80,$60     ; col 29: $8A -> $EC
            dfb   $80,$63     ; col 30: $87 -> $EC
            dfb   $80,$66     ; col 31: $84 -> $EC
            dfb   $80,$69     ; col 32: $81 -> $EC
            dfb   $80,$9E     ; col 33: $7E -> $1E
            dfb   $80,$A1     ; col 34: $7B -> $1E
            dfb   $80,$A4     ; col 35: $78 -> $1E
            dfb   $80,$A7     ; col 36: $75 -> $1E
            dfb   $80,$AA     ; col 37: $72 -> $1E
            dfb   $80,$AD     ; col 38: $6F -> $1E
            dfb   $80,$B0     ; col 39: $6C -> $1E
            dfb   $80,$B3     ; col 40: $69 -> $1E
            dfb   $80,$B6     ; col 41: $66 -> $1E
            dfb   $80,$B9     ; col 42: $63 -> $1E
            dfb   $80,$BC     ; col 43: $60 -> $1E
            dfb   $80,$BF     ; col 44: $5D -> $1E
            dfb   $80,$C2     ; col 45: $5A -> $1E
            dfb   $80,$C5     ; col 46: $57 -> $1E
            dfb   $80,$C8     ; col 47: $54 -> $1E
            dfb   $80,$CB     ; col 48: $51 -> $1E
            dfb   $80,$CE     ; col 49: $4E -> $1E
            dfb   $80,$D1     ; col 50: $4B -> $1E
            dfb   $80,$D4     ; col 51: $48 -> $1E
            dfb   $80,$D7     ; col 52: $45 -> $1E
            dfb   $80,$DA     ; col 53: $42 -> $1E
            dfb   $80,$DD     ; col 54: $3F -> $1E
            dfb   $80,$E0     ; col 55: $3C -> $1E
            dfb   $80,$E3     ; col 56: $39 -> $1E
            dfb   $80,$E6     ; col 57: $36 -> $1E
            dfb   $80,$E9     ; col 58: $33 -> $1E
            dfb   $80,$EC     ; col 59: $30 -> $1E
            dfb   $80,$EF     ; col 60: $2D -> $1E
            dfb   $80,$F2     ; col 61: $2A -> $1E
            dfb   $80,$F5     ; col 62: $27 -> $1E
            dfb   $80,$F8     ; col 63: $24 -> $1E
CodeFieldOddBRA
            dfb   $80,$10     ; col 0: $E1 -> $F3
            dfb   $80,$13     ; col 1: $DE -> $F3
            dfb   $80,$16     ; col 2: $DB -> $F3
            dfb   $80,$19     ; col 3: $D8 -> $F3
            dfb   $80,$1C     ; col 4: $D5 -> $F3
            dfb   $80,$1F     ; col 5: $D2 -> $F3
            dfb   $80,$22     ; col 6: $CF -> $F3
            dfb   $80,$25     ; col 7: $CC -> $F3
            dfb   $80,$28     ; col 8: $C9 -> $F3
            dfb   $80,$2B     ; col 9: $C6 -> $F3
            dfb   $80,$2E     ; col 10: $C3 -> $F3
            dfb   $80,$31     ; col 11: $C0 -> $F3
            dfb   $80,$34     ; col 12: $BD -> $F3
            dfb   $80,$37     ; col 13: $BA -> $F3
            dfb   $80,$3A     ; col 14: $B7 -> $F3
            dfb   $80,$3D     ; col 15: $B4 -> $F3
            dfb   $80,$40     ; col 16: $B1 -> $F3
            dfb   $80,$43     ; col 17: $AE -> $F3
            dfb   $80,$46     ; col 18: $AB -> $F3
            dfb   $80,$49     ; col 19: $A8 -> $F3
            dfb   $80,$4C     ; col 20: $A5 -> $F3
            dfb   $80,$4F     ; col 21: $A2 -> $F3
            dfb   $80,$52     ; col 22: $9F -> $F3
            dfb   $80,$55     ; col 23: $9C -> $F3
            dfb   $80,$58     ; col 24: $99 -> $F3
            dfb   $80,$5B     ; col 25: $96 -> $F3
            dfb   $80,$5E     ; col 26: $93 -> $F3
            dfb   $80,$61     ; col 27: $90 -> $F3
            dfb   $80,$64     ; col 28: $8D -> $F3
            dfb   $80,$67     ; col 29: $8A -> $F3
            dfb   $80,$6A     ; col 30: $87 -> $F3
            dfb   $80,$6D     ; col 31: $84 -> $F3
            dfb   $80,$70     ; col 32: $81 -> $F3
            dfb   $80,$A1     ; col 33: $7E -> $21
            dfb   $80,$A4     ; col 34: $7B -> $21
            dfb   $80,$A7     ; col 35: $78 -> $21
            dfb   $80,$AA     ; col 36: $75 -> $21
            dfb   $80,$AD     ; col 37: $72 -> $21
            dfb   $80,$B0     ; col 38: $6F -> $21
            dfb   $80,$B3     ; col 39: $6C -> $21
            dfb   $80,$B6     ; col 40: $69 -> $21
            dfb   $80,$B9     ; col 41: $66 -> $21
            dfb   $80,$BC     ; col 42: $63 -> $21
            dfb   $80,$BF     ; col 43: $60 -> $21
            dfb   $80,$C2     ; col 44: $5D -> $21
            dfb   $80,$C5     ; col 45: $5A -> $21
            dfb   $80,$C8     ; col 46: $57 -> $21
            dfb   $80,$CB     ; col 47: $54 -> $21
            dfb   $80,$CE     ; col 48: $51 -> $21
            dfb   $80,$D1     ; col 49: $4E -> $21
            dfb   $80,$D4     ; col 50: $4B -> $21
            dfb   $80,$D7     ; col 51: $48 -> $21
            dfb   $80,$DA     ; col 52: $45 -> $21
            dfb   $80,$DD     ; col 53: $42 -> $21
            dfb   $80,$E0     ; col 54: $3F -> $21
            dfb   $80,$E3     ; col 55: $3C -> $21
            dfb   $80,$E6     ; col 56: $39 -> $21
            dfb   $80,$E9     ; col 57: $36 -> $21
            dfb   $80,$EC     ; col 58: $33 -> $21
            dfb   $80,$EF     ; col 59: $30 -> $21
            dfb   $80,$F2     ; col 60: $2D -> $21
            dfb   $80,$F5     ; col 61: $2A -> $21
            dfb   $80,$F8     ; col 62: $27 -> $21
            dfb   $80,$FB     ; col 63: $24 -> $21

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

; Col2CodeOffset
;
; Takes a column number (0 - 63) and returns the offset of its PEA instruction relative to
; the start of the PEA run (_PEA_OFFSET) in either page of a row.  Add $100 for CIRAM page 1.
;
; The table values are pre-reversed so that loop can go in logical order 0, 2, 4, ...
; and the resulting offsets will map to the code instructions in right-to-left order.
;
; Remember, because the data is pushed on to the stack, the last instruction, which is
; in the highest memory location, pushed data that appears on the left edge of the screen.
Col2CodeOffset
]coord           equ   0
                 lup   64
                 dw    {PER_TILE_SIZE*{63-]coord}}
]coord           equ   ]coord+1
                 --^

; Table of address for the left edge of the 200 physical lines on the SHR graphics screen
;]step             equ   $2000
;ScreenAddr        ENT
;                  lup   200
;                  dw    ]step
;]step             =     ]step+160
;                  --^

; Table of addresses for the right edge of the current screen rectangle.  This is not the same size as
; the physical screen and will be double the length of the ScreenHeight, up to a maximum of 200 lines
RTable            ds    400
                  ds    400

; CHR-RAM support: two independent dirty bits per tile, set by PPUDATA_WRITE
; when the game writes into CHR-RAM ($0000-$1FFF) and checked at draw time
; (DrawPPUTile / CheckBgTileDirty / CheckSprTileDirty) to recompile just that
; tile on demand. Only used by games with HAS_CHR_RAM equ 1, but reserved
; unconditionally (512 bytes) since MarkTileDirty (ppu_regs.s)
;
; A single tile ID can be drawn as both a background tile and a sprite (e.g.
; the same CHR-RAM tile reused for a title-screen sprite and a level-map
; tile), and each form is recompiled into a *different* destination (the
; compiled background code field vs. spr_comp_tbl/tiledata's sprite layout)
; by a different consumer. Whichever consumer runs first must NOT clear the
; other consumer's need to recompile -- that was the bug: a single "dirty"
; flag got zeroed by whichever of CheckSprTileDirty/DrawPPUTile/
; CheckBgTileDirty happened to see it first, leaving the other form's
; compiled code uninitialized, which a later unconditional jump into it would
; crash on. So each byte holds two independent bits, tested/cleared
; separately by the BG- and sprite-side consumers:
CHRRAM_BG_DIRTY   equ   $01     ; DrawPPUTile / CheckBgTileDirty
CHRRAM_SPR_DIRTY  equ   $02     ; CheckSprTileDirty
;
; This array is just a block of 512 bytes.  There are direct page pointers
; to access the background vs sprite ranges since those are configurable at
; runtime.
ChrRamDirty       ENT
                  ds    512

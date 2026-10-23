; Contra -- the code the engine calls in its own bank
;
; The build stages this file into src/game/ and src/Engine.s puts it in the ENGINE segment: the code
; and data the renderer or the PPU write shims call with jsr or read with 16-bit addresses (a game's own
; palette dispatch table, SPRITE_PRE_DRAW's code), or that works on the engine's internals.  Main.s is in another bank: its symbols are reached with long addressing ("label EXT" here,
; "label ENT" at the definition) and so are this file's from there.

            mx    %00

; The electric barriers (levels 2 and 4).  The game animates them by rewriting background tiles $FC - $FF
; in CHR-RAM (all four, every 5 frames or so), which writes no nametable byte, so the engine never
; redraws their cells.  When one of them changed (its ChrRamDirty background bit), recompile all four
; (which clears their bits, also for a tile that isn't on screen) and redraw the cells that show them
; in the barriers' two rows of CIRAM page 0, $227 - $238 and $267 - $278.
;
; PRE_RENDER (MAIN) calls it with JSL: 16-bit registers.
BARRIER_TILE  equ   $FC                     ; The first of the four tiles
            mx    %00
DrawBarriersL ENT
            phb
            phk
            plb
            lda   bgadr_hi                  ; $8000: the background pattern table is at $1000
            beq   *+5
            lda   #$0100
            tax                             ; X = the pattern table's ChrRamDirty index
            sep   #$20
            lda   ChrRamDirty+BARRIER_TILE,x
            ora   ChrRamDirty+BARRIER_TILE+1,x
            ora   ChrRamDirty+BARRIER_TILE+2,x
            ora   ChrRamDirty+BARRIER_TILE+3,x
            rep   #$20
            and   #CHRRAM_BG_DIRTY
            beq   :out

]n          =     0
            lup   4
            lda   #{BARRIER_TILE+]n}*128    ; The tile's slot
            ora   bgadr_hi
            jsr   CheckBgTileDirty          ; Recompile it
]n          =     ]n+1
            --^

            lda   stkAnyPatched             ; The PEA field must not have patched exits under the tiles
            beq   *+5
            jsr   _PEAFieldStable
            sep   #$20
            ldx   #$0227
            jsr   :row
            ldx   #$0267
            jsr   :row
            rep   #$20                      ; (_DrawPPUTile doesn't mark the dirty renderer's cells)
            lda   #DIRTY_BIT_BG0_REFRESH
            tsb   DirtyBits
:out        plb
            rtl

; X = the row's first cell; 18 cells.  8-bit A, 16-bit X / Y.
            mx    %10
:row        ldy   #18
:cell       ldal  PPU_MEM+TILE_SHADOW,x
            cmp   #BARRIER_TILE
            bcc   :next
            phx
            phy
            jsr   _DrawPPUTile              ; A = the tile, X = its CIRAM address
            ply
            plx
:next       inx
            dey
            bne   :cell
            rts

            mx    %00

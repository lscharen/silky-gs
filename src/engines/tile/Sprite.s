; M13 -- the sprite bank: live OAM, sprites drawn immediately, for fixed and scrolled frames alike.  The rule the rest follows from:
;
;   A cell's bank byte is the expose bank exactly while the cell is in N (has a sprite in it now).
;
; SprDraw (shadowing off), per sprite in OAM_COPY, last to first: on a cell's first touch this frame it is stamped and listed, its
; bytes are set if it is new to N, and its background is drawn: a tile may have changed under it, even on a still frame
; (the dynamic tiles).  Then the sprite is drawn now.
; SprLeave (shadowing on): O cells no longer in N get their bytes back.  Where the thread would skip them, they are also drawn.
; Then the thread runs, on every frame, and its N cells expose themselves.
;
; The list says which cells are in N and where.  The fixed band's (ListB) is code, as the thread never visits those cells:
; ldx #cell / ldy #screen / jsl word:expose bank
; Tiles, sprites and exposes all take Y = the screen address with DBR = $01.

            rel
            mx    %00
            put   ../../game/tile/SprEqu.s
            put   ../../game/Config.s
            put   SprSlots.s
            put   ../../game/Hooks.s          ; SPRITE_PRE_DRAW, which may jsr to the game's code in EngineExt.s, in this segment

OAM_COPY    EXT                       ; OamScan.s
spriteCount EXT
Mul160Tbl   EXT
_ppuscroll_x EXT
PPU_MEM     EXT
SprFrameL   EXT                       ; SprLib.s
SprSlowL    EXT
SprMissL    EXT
SprServiceL EXT
SprSlow16L  EXT
_ppuctrl    EXT
sprClipTop  EXT

            put   Dp.s
            put   Stats.s

X2          equ   tmp+0
Cell1       equ   tmp+4
J2          equ   tmp+8
Row0        equ   tmp+12
Row1        equ   tmp+14
Col0        equ   tmp+16
Col1        equ   tmp+18
SprA        equ   tmp+20              ; The sprite's screen address
CellAddr    equ   tmp+22              ; Its first cell's
SprWord     equ   tmp+24              ; OAM's tile and attributes
SprS        equ   tmp+26              ; SprEdge: its screen line
SprByte     equ   tmp+28
TRow        equ   tmp+2               ; SprEdge: the band's rows
TRow1       equ   tmp+4
TAddr       equ   tmp+2               ; The view's rows
TSub        equ   tmp+4
TEnd        equ   tmp+6
TFirst      equ   tmp+10
TW          equ   tmp+30
TBAddr      equ   Col0                ; The band's cells
TCol        equ   Col1
Row2        equ   TEnd                ; An 8x16 sprite's third row, and whether it has one
RowFine     equ   TFirst
FtScreen    equ   SprWord             ; FirstTouch: the screen address (SprWord is only set once the cells are done)

; A first touch in the fixed band, on its own list.  Y = the cell, X = its screen address: stamp it and add it to the list, with
; its word.  Leaves Y = the screen address, and the word in CallT
ListCellB   mac
            lda   Stamp
            sta   [StampPtr],y
            lda   [CellW],y
            stal  CallT+1
            phx
            lda   [FlagPtr],y
            and   #6
            tax
            lda   HomeFlip,x
            stal  CallT+3
            plx
            tya
            txy
            ldx   NEndB
            stal  ListB+1,x
            tya
            stal  ListB+4,x
            ldal  CallT+1
            stal  ListB+7,x
            txa
            clc
            adc   #LISTENTRY
            sta   NEndB
            <<<

; A cell new to N: SprLeave's count of them, in list bytes.  Trashes A and the carry
CountNew    mac
            lda   NewBD
            clc
            adc   #LISTENTRY
            sta   NewBD
            <<<

; An 8x16 sprite's cell, row ]1 and column ]2, at CellAddr + ]3: its first touch this frame?  A row and a column never have a
; bit in common, so ora adds them.  The screen address is only worked out for a first touch.  Trashes A, X and Y
TouchAt     mac
            lda   ]1
            ora   ]2
            tay
            lda   [StampPtr],y
            cmp   Stamp
            beq   *+20
            cmp   PStamp
            beq   *+5
            jsr   MarkNew
            lda   CellAddr
            clc
            adc   #]3                 ; (leaves C clear, for ListCell)
            sta   FtScreen
            jsr   ListCell
            <<<

; The same at CellAddr itself
TouchAt0    mac
            lda   ]1
            ora   ]2
            tay
            lda   [StampPtr],y
            cmp   Stamp
            beq   *+17
            cmp   PStamp
            beq   *+5
            jsr   MarkNew
            lda   CellAddr
            sta   FtScreen
            clc
            jsr   ListCell
            <<<

; ---- Once: fill the expose bank (per tile slot, the expose body at its compiled tile's place, and a jmp > to the edge's
; trampoline at each of its role entries: the tile bank's addresses) and the list's opcodes
SprInit     ENT
:base       equ   tmp+0
:hi         equ   tmp+2
:stub       equ   tmp+4
            phb
            phk
            plb
            phk
            phk
            pla
            and   #$FF00
            sta   :hi
            lda   #$8000              ; The tile slots: the bank's high half (a cell's word is $8000 up)
            sta   :base
:t          ldx   #0
            ldy   :base
:b          lda   ExposeBody,x
            sta   [ExpPtr],y
            iny
            iny
            inx
            inx
            cpx   #BODYBYTES
            bcc   :b
            lda   :base               ; The slot's advance (as Tiles.s), in the 4 bytes before it: tya / adc Step / tay
            sec
            sbc   #4
            tay
            lda   #$6598
            sta   [ExpPtr],y
            iny
            iny
            lda   #Step+$A800
            sta   [ExpPtr],y
            lda   :base               ; The clip entries: jmp to the stubs in the bank's first page
            clc
            adc   #ROLE0
            tay
            lda   #ESTUB
            sta   :stub
            ldx   #8
:e          lda   #$004C
            sta   [ExpPtr],y
            iny
            lda   :stub
            sta   [ExpPtr],y
            clc
            adc   #4
            sta   :stub
            iny
            iny
            dex
            bne   :e
            lda   :base
            clc
            adc   #128
            sta   :base
            bne   :t
            ldx   #0                  ; The stubs: jmp > to the edge's trampoline
            ldy   #ESTUB
:st         lda   EVec,x
            xba
            and   #$FF00
            ora   #$005C
            sta   [ExpPtr],y
            iny
            iny
            lda   EVec,x
            xba
            and   #$00FF
            ora   :hi
            sta   [ExpPtr],y
            iny
            iny
            inx
            inx
            cpx   #16
            bcc   :st
            ldx   #0
:l          lda   #$00A2              ; ldx #
            sta   List,x
            lda   #$00A0              ; ldy #
            sta   List+3,x
            lda   #$0022              ; jsl
            sta   List+6,x
            lda   ExposeBank
            sta   List+9,x
            txa
            clc
            adc   #LISTENTRY
            tax
            cpx   #LISTSWAP*2
            bcc   :l
            ldx   #0
:lb         lda   #$00A2
            sta   ListB,x
            lda   #$00A0
            sta   ListB+3,x
            lda   #$0022
            sta   ListB+6,x
            lda   ExposeBank
            sta   ListB+9,x
            txa
            clc
            adc   #LISTENTRY
            tax
            cpx   #LISTBSWAP*2
            bcc   :lb
            lda   #LISTBSWAP
            sta   OStartB
            stz   NEndB
            ldy   #BLANK              ; The blank stubs' addresses (Lists.s): a blank cell with a sprite exposes, by the solid slot's advance
            ldx   #BLANK_N
:bl         lda   #$004C
            sta   [ExpPtr],y
            iny
            lda   #SOLIDWORD-4
            sta   [ExpPtr],y
            tya
            clc
            adc   #7
            tay
            dex
            bne   :bl
            lda   #$9D80              ; A cell entered at the solid tile's test exposes too: bra to the body
            ldy   #SOLIDTEST
            sta   [ExpPtr],y
            lda   #SOLIDWORD
            sta   StaleCall+1
            sta   NbrCall+1
            sep   #$20                ; The solid tile's body is the same in every background bank
            lda   HomeFlip
            sta   StaleCall+3
            sta   NbrCall+3
            rep   #$20
            lda   ExposeBank          ; A cell's bank word: the bank byte, and the tya that follows it in CallT
            ora   #$9800
            sta   FlipOn
            ldy   #CELL_Z             ; Every cell's CELL_Z: CallZ, for the background off (SprBgOffL)
:cz         lda   #CallZ
            sta   [CellPtr],y
            tya
            clc
            adc   #32
            tay
            cmp   #CELL_Z
            bne   :cz
            plb
            lda   #2
            sta   Stamp
            stz   NStart
            stz   NEnd
            rtl

; ---- A frame's cells and sprites, shadowing off
SprDraw     ENT
            phb
            pea   $0101
            plb
            plb
            lda   Stamp
            sta   PStamp
            inc
            bne   :st
            jsr   StampWrap
            lda   #2
:st         sta   Stamp
            stz   NewBD
            stz   SprShD
            ldal  SprOy
            sta   SprOyD
            ldal  SprBase
            sta   SprBaseD
            lda   NEnd                ; Last frame's list is O; this frame's is the other one
            sta   OEnd
            lda   NStart
            sta   OStart
            eor   #LISTSWAP
            sta   NStart
            sta   NEnd
            lda   NEndB               ; The same for the fixed band's list
            sta   OEndB
            lda   OStartB
            eor   #LISTBSWAP
            sta   OStartB
            eor   #LISTBSWAP
            sta   NEndB
            jsl   SprFrameL           ; A = the pattern table's half of the compiled sprites' table
            sta   SprTbl
            lda   #^PPU_MEM
            sta   SprTbl+2
            ldal  _ppuctrl            ; This render's sprite size picks the loop
            and   #$0020
            beq   :is8
            lda   #SPR_COMP_TBL+SPR16_KEY ; The keys of whole 8x16 sprites: the OAM tile's bit 0 is the pattern table
            sta   SprTbl
            lda   #SprLoop16
            stal  SprNextJ+1
            lda   #15
            bra   :size
:is8        lda   #SprLoop
            stal  SprNextJ+1
            lda   #7
:size       stal  SprHm1
            eor   #$FFFF
            sec
            adcl  SprLines
            sta   SprLimD             ; (lines - height + 1)
            lda   #0
            DO    1-SPR_PIXEL_SHIFT   ; On even bytes, with the scroll's half pixel.  With SPR_PIXEL_SHIFT, on their exact pixel
            ldal  _ppuscroll_x
            and   #1
            FIN
            sta   SprPar
            ldal  spriteCount
            bne   :some
            brl   SprOut
:some       sta   J2
            jmp   SprNext

SprLoop     stx   J2
            TSADD tsSprTiles;1
            SPRITE_PRE_DRAW 8
            DO    SPRITE_CLIP         ; The game can hide the sprite's top lines; all of them hides it
            ldal  sprClipTop
            cmp   #8
            bcc   *+5
            jmp   SprNext
            FIN
            DO    SPR_PIXEL_SHIFT
            ldal  OAM_COPY+3,x        ; An odd pixel: the shifted variants
            and   #1
            asl
            asl
            sta   SprShD
            FIN
            ldal  OAM_COPY+3,x        ; The byte that shows it: (scroll_x & 1 + x) / 2, * 4
            and   #$00FF
            clc
            adc   SprPar
            and   #$01FE
            asl
            sta   X2
            ldal  OAM_COPY,x          ; Its line in the view (OAM's Y + 1, already)
            and   #$00FF
            sec
            sbc   SprOyD
            cmp   SprLimD
            bcs   :edge
            tay
            lda   X2
            cmp   #120*4
            bcs   :edge
            tya
            asl
            tay
            lda   X2
            lsr                       ; The sprite's screen address
            lsr
            tyx
            clc
            adcl  SprY,x
            adc   SprBaseD
            sta   SprA
            txa                       ; Its row in the world (the table wraps; C is clear), the first cell's line
            adc   WorldY
            tax
            ldal  WRow,x
            sta   Row0
            txa
            and   #14
            bne   :tt

; ---- One row of cells: 1 or 2
            lda   X2                  ; Its column in the world (C is clear)
            adc   WorldX
            tax
            ldal  WCol,x
            adc   Row0
            tay                       ; The first cell
            txa
            and   #14
            bne   :wide
            DO    SPR_PIXEL_SHIFT     ; A shifted sprite is 5 bytes: from a cell's start, it reaches the next
            lda   SprShD
            beq   *+5
            brl   :wide0
            FIN
            lda   [StampPtr],y        ; 1 cell, at the sprite's own address
            cmp   Stamp
            bne   :one
            brl   :draw
:one        ldx   SprA
            jsr   FirstTouch
            brl   :draw
:tt         brl   :tall
:edge       jsr   SprEdge
            brl   :draw

; 2 cells, the usual case.  The first touches are in line
:wide0      lda   #0
:wide       lsr                       ; The first cell's byte
            lsr
            eor   #$FFFF
            sec
            adc   SprA
            sta   CellAddr
            ldal  WCol+16,x           ; The second cell
            clc
            adc   Row0
            sta   Cell1
            lda   [StampPtr],y
            cmp   Stamp
            bne   :w1
            brl   :w2
:w1
            cmp   PStamp
            beq   :s1                 ; Was in O: its bytes are set
            lda   FlipOn
            jsr   CellFlip            ; (and its list entries)
            TSINC tsErasedNew
            CountNew
:s1          lda   Stamp
            TSINC tsErased
            TSINC tsListed
            sta   [StampPtr],y
            lda   [FlagPtr],y
            and   #6
            tax
            lda   HomeFlip,x
            stal  CallT+3
            ldx   NEnd
            lda   [CellW],y
            stal  CallT+1
            DO    TILE_STILL_DIRTY    ; Its word, for SprExposeN
            stal  List+7,x
            FIN
            tya
            stal  List+1,x
            lda   CellAddr
            stal  List+4,x
            tay                       ; Y = the screen address, for the tile
            txa
            clc
            adc   #LISTENTRY
            sta   NEnd
:c1          jsr   CallT
:w2         ldy   Cell1
            lda   [StampPtr],y
            cmp   Stamp
            bne   :w3
            brl   :draw
:w3
            cmp   PStamp
            beq   :s2                 ; Was in O: its bytes are set
            lda   FlipOn
            jsr   CellFlip            ; (and its list entries)
            TSINC tsErasedNew
            CountNew
:s2          lda   Stamp
            TSINC tsErased
            TSINC tsListed
            sta   [StampPtr],y
            lda   [FlagPtr],y
            and   #6
            tax
            lda   HomeFlip,x
            stal  CallT+3
            ldx   NEnd
            lda   [CellW],y
            stal  CallT+1
            DO    TILE_STILL_DIRTY    ; Its word, for SprExposeN
            stal  List+7,x
            FIN
            tya
            stal  List+1,x
            lda   CellAddr
            clc
            adc   #4
            stal  List+4,x
            tay                       ; Y = the screen address, for the tile
            txa
            clc
            adc   #LISTENTRY
            sta   NEnd
:c2          jsr   CallT

:draw       ldx   J2                  ; The sprite.  X (the OAM index) and D aren't touched by a compiled one
            ldal  OAM_COPY+1,x
            sta   SprWord
            lda   X2
            cmp   #128*4              ; Past the edge
            bcc   *+5
            jmp   SprNext
            DO    SPR_PIXEL_SHIFT     ; From byte 124 on, sprites are drawn on even pixels (as silky's)
            cmp   #124*4
            bcc   *+9
            lda   #0
            sta   SprShD
            lda   X2
            FIN
            cmp   #125*4              ; Runs off the right edge: from the bitmap, clipped
            bcs   :clip
            DO    SPRITE_CLIP         ; Top lines hidden: the bitmap draws clip them
            ldal  sprClipTop
            bne   :prio
            FIN
            lda   SprWord
            bit   #$2000              ; Behind the background: from the bitmap
            bne   :prio
            and   #$C3FF              ; The key offset: pal << 10 | tile << 2 | vflip << 1; the carry has the hflip
            asl
            adc   #0
            asl
            tay
            lda   [SprTbl],y
            beq   :miss
            bcc   *+5
            ora   #SPR_FLIP_PAGE
            DO    SPR_PIXEL_SHIFT
            ora   SprShD              ; The shifted variant (the entry's page bit 0 makes it a stub until that is compiled)
            FIN
            stal  :csd+2              ; The page and bank: :csd+1 is always 0
            ldy   SprA
            TSINC PPU_MEM+SPR_STATS_A+SPR_ST_HITS_A
:csd        hex   5C000000
:miss       tya                       ; Queue it, and draw it from its bitmap this time
            TSINC PPU_MEM+SPR_STATS_A+SPR_ST_MISSES_A
            clc
            adc   SprTbl
            sec
            sbc   #SPR_COMP_TBL
            jsl   SprMissL
:prio       ldx   #0
            bra   :slow
:clip       lsr
            lsr
            sec
            sbc   #124
            tax
:slow       lda   SprWord
            ldy   SprA
            TSINC tsSprSlow
            jsl   SprSlowL
            jmp   SprNext

; ---- Two rows of cells: 2 or 4
:tall       tay                       ; The first cell's line
            ldal  WRow+16,x
            sta   Row1
            tyx
            lda   SprA
            sec
            sbcl  Sub160,x
            sta   CellAddr
            lda   X2
            clc
            adc   WorldX
            tax
            ldal  WCol,x
            sta   Col0
            txa
            and   #14
            DO    SPR_PIXEL_SHIFT
            ora   SprShD              ; (a shifted sprite reaches the next cell from a cell's start)
            FIN
            beq   :tall1
            DO    SPR_PIXEL_SHIFT
            txa
            and   #14
            FIN
            lsr                       ; 4 cells
            lsr
            eor   #$FFFF
            sec
            adc   CellAddr
            sta   CellAddr
            ldal  WCol+16,x
            sta   Col1
            ldx   CellAddr            ; (Row0, Col1)
            inx
            inx
            inx
            inx
            lda   Row0
            clc
            adc   Col1
            jsr   TryCell
            lda   CellAddr            ; (Row1, Col1)
            clc
            adc   #1284
            tax
            lda   Row1
            adc   Col1
            jsr   TryCell
:tall1      ldx   CellAddr            ; (Row0, Col0)
            lda   Row0
            clc
            adc   Col0
            jsr   TryCell
            lda   CellAddr            ; (Row1, Col0)
            clc
            adc   #1280
            tax
            lda   Row1
            adc   Col0
            jsr   TryCell
            brl   :draw

draw_rtn2   ENT                       ; The name core/sprites/CompileSprites.s uses
SprNext
            ldx   J2
            dex
            dex
            dex
            dex
            bmi   SprOut
SprNextJ    jmp   SprLoop             ; (or SprLoop16: SprDraw)
SprOut      jsl   SprServiceL
            plb
            rtl

; ---- 8x16 sprites: up to 3 rows of cells, each of 1 or 2
SprLoop16   stx   J2
            TSADD tsSprTiles;2
            SPRITE_PRE_DRAW 16
            DO    SPRITE_CLIP
            ldal  sprClipTop
            cmp   #16
            bcc   *+5
            jmp   SprNext
            FIN
            DO    SPR_PIXEL_SHIFT
            ldal  OAM_COPY+3,x
            and   #1
            asl
            asl
            asl                       ; SPR16_SHIFT_PAGE on an odd pixel
            sta   SprShD
            FIN
            ldal  OAM_COPY+3,x
            and   #$00FF
            clc
            adc   SprPar
            and   #$01FE
            asl
            sta   X2
            ldal  OAM_COPY,x
            and   #$00FF
            sec
            sbc   SprOyD
            cmp   SprLimD
            bcs   :edgej
            tay
            lda   X2
            cmp   #120*4
            bcc   *+5
:edgej      brl   :edge
            tya
            asl
            tax                       ; Its line in the view * 2
            lda   X2
            lsr
            lsr
            clc
            adcl  SprY,x
            adc   SprBaseD
            sta   SprA
            txa
            adc   WorldY              ; (C is clear)
            tax
            ldal  WRow,x
            sta   Row0
            ldal  WRow+16,x
            sta   Row1
            ldal  WRow+32,x
            sta   Row2
            txa
            and   #14
            sta   RowFine
            tax
            lda   SprA
            sec
            sbcl  Sub160,x
            sta   CellAddr
            lda   X2
            clc
            adc   WorldX
            tax
            ldal  WCol,x
            sta   Col0
            ldal  WCol+16,x
            sta   Col1
            txa
            and   #14
            sta   TSub
            lsr
            lsr
            eor   #$FFFF
            sec
            adc   CellAddr
            sta   CellAddr
            lda   TSub                ; 2 or 3 rows of 1 or 2 cells
            DO    SPR_PIXEL_SHIFT     ; (a shifted sprite reaches the next cell from a cell's start)
            ora   SprShD
            FIN
            bne   *+5
            brl   :cols1
            TouchAt0 Row0;Col0
            TouchAt Row0;Col1;4
            TouchAt Row1;Col0;1280
            TouchAt Row1;Col1;1284
            lda   RowFine
            bne   *+5
            brl   :sprite
            TouchAt Row2;Col0;2560
            TouchAt Row2;Col1;2564
            brl   :sprite
:cols1      TouchAt0 Row0;Col0
            TouchAt Row1;Col0;1280
            lda   RowFine
            beq   :sprite
            TouchAt Row2;Col0;2560

; The sprite: whole, if it is compiled (it returns to SprNext), else its two halves from their bitmaps.  One this far from
; the edges needs none of :edge's checks
:sprite     ldx   J2
            ldal  OAM_COPY+1,x
            sta   SprWord
:lookup
            DO    SPRITE_CLIP
            ldal  sprClipTop
            bne   :halves
            FIN
            lda   SprWord
            bit   #$2000
            bne   :halves
            DO    SPR_TALL
            and   #$C3FF              ; tile, palette and the two flips
            asl
            adc   #0
            asl
            tay
            lda   [SprTbl],y
            beq   :miss
            bcc   *+5
            ora   #SPR16_FLIP_PAGE
            FIN
            DO    SPR_TALL*SPR_PIXEL_SHIFT
            ora   SprShD
            FIN
            DO    SPR_TALL
            stal  :c16+2
            ldy   SprA
            TSINC PPU_MEM+SPR_STATS_A+SPR_ST_HITS_A
:c16        hex   5C000000
:miss       tya
            TSINC PPU_MEM+SPR_STATS_A+SPR_ST_MISSES_A
            clc
            adc   SprTbl
            sec
            sbc   #SPR_COMP_TBL
            jsl   SprMissL
            FIN
:halves     ldx   #0
            bra   :slow
:clip       lsr
            lsr
            sec
            sbc   #124
            tax
:slow       lda   SprWord
            ldy   SprA
            TSINC tsSprSlow
            jsl   SprSlow16L
            jmp   SprNext

; Near an edge of the view or over the fixed band: its cells, and whether and how it can be drawn
:edge       jsr   SprEdge
            ldx   J2
            ldal  OAM_COPY+1,x
            sta   SprWord
            lda   X2
            cmp   #128*4
            bcc   *+5
            jmp   SprNext
            DO    SPR_PIXEL_SHIFT
            cmp   #124*4
            bcc   *+9
            lda   #0
            sta   SprShD
            lda   X2
            FIN
            cmp   #125*4
            bcs   :clip
            brl   :lookup

; A sprite near an edge of the view or over the fixed band: the cells it touches, band by band.  X2 has its byte.  Off-screen
; cells aren't touched.  Sets SprA
SprEdge
            ldx   J2
            ldal  OAM_COPY,x
            and   #$00FF
            sec
            sbc   #y_offset           ; Its screen line (from -7)
            sta   SprS
            lda   X2
            lsr
            lsr
            sta   SprByte
            cmp   #128
            bcc   :in
            rts                       ; (past the edge: :draw skips it)
:in         lda   SprS                ; Its screen address
            bmi   :above
            asl
            tax
            ldal  Mul160Tbl,x
            bra   :adr
:above      eor   #$FFFF
            inc
            asl
            tax
            lda   #0
            sec
            sbcl  Mul160Tbl,x
:adr        clc
            adc   SprByte
            adc   #$2000+x_offset
            sta   SprA

; The lines above the view are the band: its rows under the sprite
            ldal  SprTop
            beq   :pfj
            lda   SprS
            cmpl  SprTop
            bmi   :b0
:pfj        brl   :pf
:b0         lda   SprS                ; The first row: 0 if it starts above the screen
            bpl   :b1
            lda   #0
:b1         lsr
            lsr
            lsr
            sta   TRow
            lda   SprS
            clc
            adcl  SprHm1
            cmpl  SprTop
            bcc   :b2
            ldal  SprTop
            dec
:b2         lsr
            lsr
            lsr
            sta   TRow1
:brow       jsr   TouchBandRow
            lda   TRow
            inc
            sta   TRow
            cmp   TRow1
            bcc   :brow
            beq   :brow

; The scrolling view: its part of the sprite
:pf         lda   SprS
            clc
            adcl  SprHm1
            sec
            sbcl  SprTop              ; The last line in the view
            bpl   :e0
            rts
:e0         cmpl  SprLines
            bcc   :e1
            ldal  SprLines
            dec
:e1         sta   TEnd
            lda   SprS
            sec
            sbcl  SprTop              ; The first
            bpl   :e2
            lda   #0
:e2         cmpl  SprLines
            bcc   :e3
            rts
:e3         sta   TFirst
            asl                       ; Its row in the world, and the screen address of that row's start at this byte
            clc
            adc   WorldY
            sta   TW
            tax
            ldal  WRow,x
            sta   Row0
            ldal  WRow+16,x
            sta   Row1
            lda   TFirst
            asl
            tax
            ldal  SprY,x
            clc
            adc   SprBaseD
            adc   SprByte
            sta   CellAddr
            lda   TW
            and   #14
            tax
            lda   CellAddr
            sec
            sbcl  Sub160,x
            sta   CellAddr
            jsr   TouchViewRow        ; The first row
            jsr   :span               ; A second, if the sprite's last line in the view reaches it
            cmp   #8
            bcc   :x
            lda   Row1
            sta   Row0
            lda   CellAddr
            clc
            adc   #1280
            sta   CellAddr
            jsr   TouchViewRow
            jsr   :span               ; A third (8x16)
            cmp   #16
            bcc   :x
            ldx   TW
            ldal  WRow+32,x
            sta   Row0
            lda   CellAddr
            clc
            adc   #1280
            sta   CellAddr
            jmp   TouchViewRow
:x          rts
:span       lda   TW                  ; From its first row's first line to its last line in the view
            and   #14
            lsr
            clc
            adc   TEnd
            sec
            sbc   TFirst
            rts

; Row0 = a cell row, CellAddr = the screen address of its start at the sprite's byte: its cells under the sprite
TouchViewRow
            lda   X2
            clc
            adc   WorldX
            tax
            and   #14                 ; The first cell's start, on the screen
            lsr
            lsr
            eor   #$FFFF
            sec
            adc   CellAddr
            sta   TAddr
            ldal  WCol,x
            sta   Col0
            ldal  WCol+16,x
            sta   Col1
            txa
            and   #14
            sta   TSub
            ldx   TAddr
            lda   Row0
            clc
            adc   Col0
            jsr   TryCell
            lda   TSub                ; A second cell, if the sprite reaches one on the screen
            DO    SPR_PIXEL_SHIFT
            ora   SprShD
            FIN
            beq   :x
            lda   TSub
            lsr
            lsr
            eor   #$FFFF
            sec
            adc   SprByte
            clc
            adc   #4                  ; The second cell's first byte in the view
            cmp   #128
            bcs   :x
            lda   TAddr
            clc
            adc   #4
            tax
            lda   Row0
            clc
            adc   Col1
            jsr   TryCell
:x          rts

; TRow = a row of the fixed band: its cells under the sprite
TouchBandRow
            lda   SprByte
            lsr
            lsr
            jsr   :cell
            lda   SprByte
            and   #3
            bne   :two
            DO    SPR_PIXEL_SHIFT
            lda   SprShD
            bne   :two
            FIN
            rts
:two        lda   SprByte
            lsr
            lsr
            inc
            cmp   #32
            bcc   :cell
            rts
:cell       sta   TCol
            lda   TRow
            clc
            adc   #y_offset_rows
            asl
            tax
            ldal  WRow2,x
            sta   TBAddr
            lda   TCol
            asl
            tax
            ldal  WCol2,x
            clc
            adc   TBAddr
            adcl  SprBand             ; (the band's page of CIRAM)
            pha
            lda   TRow
            asl
            tax
            ldal  Band1280,x
            sta   TBAddr
            lda   TCol
            asl
            asl
            clc
            adc   TBAddr
            adc   #$2000+x_offset
            tax
            pla
            tay                       ; Its first touch this frame?  As a fixed frame's, on its own list
            lda   [StampPtr],y
            cmp   Stamp
            beq   :x
            cmp   PStamp
            beq   :draw
            lda   FlipOn
            jsr   CellFlip            ; (and its list entries)
            TSINC tsListed
            ListCellB
:x          rts
:draw       ListCellB
            TSINC tsListed
            TSINC tsErased
            jmp   CallT

; A = a cell, X = its screen address: its first touch this frame?
TryCell     tay
            lda   [StampPtr],y
            cmp   Stamp
            bne   FirstTouch
            rts

; A = the cell's old stamp, Y = the cell, X = its screen address.  Stamp it, set its bytes if it is new to N, list it,
; and draw its background.
FirstTouch  stx   FtScreen
            cmp   PStamp
            beq   *+5                 ; Was in O: its bytes are set
            jsr   MarkNew
            clc
            bra   ListCell

; A = a bank word (FlipOn, or the palette's HomeFlip), Y = a cell: its bank byte, in the cell and in its two list entries
; (Lists.s: the cell holds their addresses).  Keeps A, X and Y
CellFlip    sta   [FlipPtr],y
            phx
            pha
            lda   [LrPtr],y
            tax
            lda   [LcPtr],y
            phy
            tay
            sep   #$20
            lda   3,s
            stal  $000002,x
            tyx
            stal  $000002,x
            rep   #$20
            ply
            pla
            plx
            rts
            
; Y = a cell new to N: its bytes
MarkNew     lda   FlipOn
            jsr   CellFlip            ; (and its list entries)
            TSINC tsErasedNew
            CountNew
            rts

; Y = the cell, FtScreen = its screen address, C clear.  Stamp it, list it and draw its background (it runs on into CallT)
ListCell    lda   Stamp
            TSINC tsErased
            TSINC tsListed
            sta   [StampPtr],y
            lda   [FlagPtr],y         ; Its palette's bank, for CallT
            and   #6
            tax
            lda   HomeFlip,x
            stal  CallT+3
            ldx   NEnd                ; Its list entry: the cell, the word, the screen address
            tya
            stal  List+1,x
            lda   [CellW],y
            stal  CallT+1
            DO    TILE_STILL_DIRTY    ; (for SprExposeN)
            stal  List+7,x
            FIN
            ldy   FtScreen            ; Y = the screen address, for the tile
            tya
            stal  List+4,x
            txa
            adc   #LISTENTRY          ; (C is clear)
            sta   NEnd

; A cell's tile, with Y = the screen address.  The caller writes the word at +1, and at +3 a HomeFlip word: the bank, and
; the tya here
CallT       hex   22000000
            tya
            rts

; ---- The background off (PPUMASK): the sprites over a blank screen.  A cell's tile is then a zero fill whatever the cell holds:
; CallT's jsl becomes a jmp, and CellW points at each cell's CELL_Z, which holds CallZ's address (SprInit), so every caller of
; CallT runs CallZ unchanged.  A list entry's word is then CallZ's too, so the cells are exposed by SprExposeZ, not the list.
; The view may still be last frame's scroll, a fine one: a line off the screen is left alone.

SCREEN_END  equ   $2000+200*160       ; (the SCBs follow)

; A = 0: the cells' tiles again; 1: the zero fill; 2: no draws at all (the screen was just blanked).  D = the engine's page
SprBgOffL   ENT
            tax
            ldal  CallT
            and   #$00FF
            cmp   #$22
            bne   :set                ; (off already: CellW is CELL_Z)
            lda   CellW
            stal  BgOffW
:set        cpx   #0
            bne   :off
            ldal  BgOffW
            bra   :w
:off        lda   #CELL_Z
:w          sta   CellW
            sep   #$20
            ldal  CallOps,x
            stal  CallT
            rep   #$20
            rtl
BgOffW      dw    0
CallOps     db    $22,$4C,$60         ; jsl, jmp CallZ, rts

; Y = a cell's screen address, DBR = $01: its lines on the screen, in color 0.  Keeps X; A = Y, as CallT
CallZ       phx
            phy
            ldx   #8
:l          cpy   #$2000
            bcc   :n
            cpy   #SCREEN_END-3
            bcs   :n
            lda   #0
            sta:  $0000,y
            sta:  $0002,y
:n          tya
            clc
            adc   #160
            tay
            dex
            bne   :l
            ply
            plx
            tya
            rts

; Shadowing on, the background off, after SprLeave: last frame's cells that have no sprite now, in color 0 on the screen.  (SprLeave
; only draws the cells the thread would skip, and there is no thread)
SprLeaveZ   ENT
            phb
            pea   $0101
            plb
            plb
            ldx   OStart
:c          cpx   OEnd
            beq   :x
            ldal  List+1,x
            tay
            lda   [StampPtr],y
            cmp   Stamp
            beq   :n                  ; Still in N
            ldal  List+4,x
            tay
            jsr   CallZ
:n          txa
            clc
            adc   #LISTENTRY
            tax
            bra   :c
:x          plb
            rtl

; Shadowing on, the background off: this frame's sprite cells, onto the screen (their lines on it)
SprExposeZ  ENT
            phb
            pea   $0101
            plb
            plb
            ldx   NStart
:c          cpx   NEnd
            beq   :x
            ldal  List+4,x
            tay
            lda   #8
            sta   J2
:l          cpy   #$2000
            bcc   :n
            cpy   #SCREEN_END-3
            bcs   :n
            lda:  $0000,y
            sta:  $0000,y
            lda:  $0002,y
            sta:  $0002,y
:n          tya
            clc
            adc   #160
            tay
            dec   J2
            bne   :l
            txa
            clc
            adc   #LISTENTRY
            tax
            bra   :c
:x          plb
            rtl
; Every 65,536 frames: the stamps restart, with last frame's cells at 1 (PStamp)
StampWrap   ldy   #0
:c          lda   [StampPtr],y
            cmp   PStamp
            beq   :o
            lda   #0
            bra   :w
:o          lda   #1
:w          sta   [StampPtr],y
            tya
            clc
            adc   #32
            tay
            and   #$7FFF
            cmp   #$7800              ; The rest of the nametable is its unused bytes
            bcc   :c
            tya
            bmi   :x
            ldy   #$8000
            bra   :c
:x          lda   #1
            sta   PStamp
            rts

; ---- Shadowing on: the cells the sprites left get their bytes back.
;
; On a frame that skips, a cell must not skip over old sprite pixels.  Last frame's cell has moved, so its old pixels are on
; it and on one neighbor (SetDirection says which): where those would skip, they are drawn now.  The thread draws the
; rest, and runs the expose for those in N.  A neighbor that was in O and has left draws itself, as an O cell.
;
; Most O cells are still in N, with a neighbor in N, and draw nothing: that path runs straight through, jumping to this
; direction's neighbor code, and finds nothing else out until it has to.
SprLeave    ENT
            phb
            pea   $0101
            plb
            plb
            ldx   OStart
            cpx   OEnd
            beq   LeaveX
            lda   StaleOn
            bne   *+5
            brl   LeavePlain
            ldx   NbrIdx              ; This frame's neighbor
            ldal  NbrTab,x
            stal  LeaveNb+1
            ldx   OStart
LeaveLoop   ldal  List+1,x
            tay
            lda   [StampPtr],y
            cmp   Stamp
            bne   LeaveLeft
LeaveNb     jmp   NbrRight            ; (the operand is written above)
NbrDone     lda   [StampPtr],y        ; Y = the neighbor
            cmp   Stamp
            beq   LeaveNext           ; (these leave C set)
            cmp   PStamp
            beq   LeaveNext
            lda   [CellW],y
            cmp   #SOLIDTEST
            bne   LeaveDrawn
            lda   [FlagPtr],y
            and   FlagMask
            beq   LeaveDrawn
            ldal  List+4,x
            clc
            adc   NbrDY
            cmpl  SprVStart           ; Only on the view: a neighbor past its edge has moved off it (scrolling vertically, past
            bcc   LeaveDrawn          ; the screen's last line)
            cmpl  SprVEnd
            bcs   LeaveDrawn
            tay
            TSINC tsNbr
NbrCall     hex   22000000            ; (the solid tile's body: SprInit)
LeaveDrawn  sec
LeaveNext   txa
            adc   #LISTENTRY-1
            tax
            cpx   OEnd
            bne   LeaveLoop
LeaveX      plb
            rtl

; An O cell that has left N: its bytes back, and itself, then on to its neighbor
LeaveLeft
            TSINC tsLeft
            phx
            lda   [FlagPtr],y
            and   #6
            tax
            lda   HomeFlip,x
            plx
            jsr   CellFlip            ; (and its list entries)
            lda   [CellW],y
            cmp   #SOLIDTEST
            bne   :nbr
            lda   [FlagPtr],y
            and   FlagMask
            beq   :nbr
            ldal  List+4,x
            clc
            adc   StaleDY
            cmpl  SprVStart           ; (as NbrCall)
            bcc   :nbr
            cmpl  SprVEnd
            bcs   :nbr
            tay
            TSINC tsLeftDrawn
StaleCall   hex   22000000            ; (the solid tile's body: SprInit)
:nbr        ldal  List+1,x
            tay
            brl   LeaveNb

; A frame with no motion to follow: a full render, or a still frame
; N's cells less the ones new to it are the cells of O still in N.  If that is all of O, none left and there is nothing to
; scan.  (A cell the band listed last frame also has last frame's stamp, without being in O: then the count can't be trusted.)
LeavePlain  lda   OEndB
            cmp   OStartB
            bne   :w
            lda   NEnd
            sec
            sbc   NStart
            sec
            sbc   NewBD
            clc
            adc   OStart
            cmp   OEnd
            bne   :w
            brl   LeaveX
:w          ldal  List+1,x
            tay
            lda   [StampPtr],y
            cmp   Stamp
            beq   :n                  ; Still in N (C is set)
            TSINC tsLeft
            phx
            lda   [FlagPtr],y
            and   #6
            tax
            lda   HomeFlip,x
            plx
            jsr   CellFlip            ; (and its list entries)
            lda   FlagMask            ; A full render: the thread draws it
            beq   :s
            lda   [CellW],y           ; Still: the thread skips a solid cell, so its tile goes straight to the screen.  (With
            DO    1-TILE_STILL_DIRTY  ; TILE_STILL_DIRTY there is no thread: every cell left goes straight to the screen)
            cmp   #SOLIDTEST
            bne   :s
            FIN
            stal  CallT+1
            phx
            lda   [FlagPtr],y
            and   #6
            tax
            lda   HomeFlip,x
            stal  CallT+3
            plx
            ldal  List+4,x
            tay
            stx   J2
            TSINC tsLeftDrawn
            jsr   CallT
            ldx   J2
:s          sec
:n          txa
            adc   #LISTENTRY-1
            tax
            cpx   OEnd
            bne   :w
            brl   LeaveX

; Y = a cell: Y = its neighbor, in the order of SetDirection: right, left, below, above
NbrTab      dw    NbrRight,NbrLeft,NbrDown,NbrUp
            dw    NbrRightH,NbrLeftH,NbrDownH,NbrUpH
NbrRight    tya
            clc
            adc   #32
            tay
            and   #$03FF
            beq   :seam
            brl   NbrDone
:seam       tya                       ; Past a nametable's end: the same row, in the other nametable
            sec
            sbc   #1024
            eor   #$8000
            tay
            brl   NbrDone
NbrLeft     tya
            and   #$03FF
            beq   :seam
            tya
            sec
            sbc   #32
            tay
            brl   NbrDone
:seam       tya
            clc
            adc   #31*32
            eor   #$8000
            tay
            brl   NbrDone
NbrDown     tya
            clc
            adc   #1024
            tay
            and   #$7C00
            cmp   #30*1024
            beq   :top
            brl   NbrDone
:top        tya
            sec
            sbc   #30*1024
            tay
            brl   NbrDone
NbrUp       tya
            and   #$7C00
            beq   :bot
            tya
            sec
            sbc   #1024
            tay
            brl   NbrDone
:bot        tya
            clc
            adc   #29*1024
            tay
            brl   NbrDone

; The same on the map of horizontal mirroring: the columns wrap in their row, and the rows run on through the other page
NbrRightH   tya
            clc
            adc   #32
            tay
            and   #$03FF
            beq   :seam
            brl   NbrDone
:seam       tya
            sec
            sbc   #1024
            tay
            brl   NbrDone
NbrLeftH    tya
            and   #$03FF
            beq   :seam
            tya
            sec
            sbc   #32
            tay
            brl   NbrDone
:seam       tya
            clc
            adc   #31*32
            tay
            brl   NbrDone
NbrDownH    tya
            clc
            adc   #1024
            tay
            and   #$7C00
            cmp   #30*1024
            beq   :top
            brl   NbrDone
:top        tya
            sec
            sbc   #30*1024
            eor   #$8000
            tay
            brl   NbrDone
NbrUpH      tya
            and   #$7C00
            beq   :bot
            tya
            sec
            sbc   #1024
            tay
            brl   NbrDone
:bot        tya
            clc
            adc   #29*1024
            eor   #$8000
            tay
            brl   NbrDone

; ---- Every frame, shadowing on: the fixed band's cells the sprites left get their tiles back
SprLeaveB   ENT
            phb
            pea   $0101
            plb
            plb
            ldx   OStartB
:w          cpx   OEndB
            beq   :x
            ldal  ListB+1,x
            tay
            lda   [StampPtr],y
            cmp   Stamp
            beq   :n
            phx
            lda   [FlagPtr],y
            and   #6
            tax
            lda   HomeFlip,x
            stal  CallT+3
            plx
            jsr   CellFlip            ; (and its list entries)
            lda   [CellW],y
            stal  CallT+1
            ldal  ListB+4,x
            tay
            stx   J2
            TSINC tsLeft
            TSINC tsLeftDrawn
            jsr   CallT
            ldx   J2
:n          txa
            clc
            adc   #LISTENTRY
            tax
            bra   :w
:x          plb
            rtl

; Every frame, shadowing on: the fixed band's sprite cells, onto the screen
SprExposeB  ENT
            phb
            pea   $0101
            plb
            plb
            ldx   NEndB
            lda   #$0060              ; rts at the end
            stal  ListB,x
            lda   OStartB
            eor   #LISTBSWAP
            bne   :b
            jsr   ListB
            bra   :r
:b          jsr   ListB+LISTBSWAP
:r          ldx   NEndB
            lda   #$00A2
            stal  ListB,x
            plb
            rtl

; ---- From the front: the view, and the map

; A = the view's first line, X = its lines
SprViewL    ENT
            stal  SprTop
            clc
            adc   #y_offset
            stal  SprOy
            txa
            stal  SprLines
            ldal  SprTop
            asl
            tax
            ldal  Mul160Tbl,x
            stal  SprBase
            clc
            adc   #$2000
            stal  SprVStart
            ldal  SprLines            ; A whole cell from SprVEnd on would run past the view
            sec
            sbc   #7
            clc
            adcl  SprTop
            asl
            tax
            ldal  Mul160Tbl,x
            clc
            adc   #$2000
            stal  SprVEnd
            rtl

; A = the band's page, as an offset in the cell bank
SprBandL    ENT
            stal  SprBand
            rtl

; A = 0 for vertical mirroring: the world's tables for this map
SprMirrorL  ENT
            phb
            phk
            plb
            cmp   #0
            bne   :h
            ldx   #WROWS*2-2
:rv         lda   WRowV,x
            sta   WRow,x
            dex
            dex
            bpl   :rv
            ldx   #WCOLS*2-2
:cv         lda   WColV,x
            sta   WCol,x
            dex
            dex
            bpl   :cv
            plb
            rtl
:h          ldx   #WROWS*2-2
:rh         lda   WRowH,x
            sta   WRow,x
            dex
            dex
            bpl   :rh
            ldx   #WCOLS*2-2
:ch         lda   WColH,x
            sta   WCol,x
            dex
            dex
            bpl   :ch
            plb
            rtl

            DO    TILE_STILL_DIRTY
; A frame that doesn't scroll, shadowing on: this frame's sprite cells, onto the screen.  The list is code, as the fixed band's:
; ldx #cell / ldy #screen / jsl word:expose bank
SprExposeN  ENT
            phb
            pea   $0101
            plb
            plb
            ldx   NEnd
            lda   #$0060              ; rts at the end
            stal  List,x
            lda   NStart
            bne   :b
            jsr   List
            bra   :r
:b          jsr   List+LISTSWAP
:r          ldx   NEnd
            lda   #$00A2
            stal  List,x
            plb
            rtl
            FIN

; ---- Data
SprTop      dw    0                   ; The view's first line, and its lines
SprLines    dw    200
SprOy       dw    y_offset            ; OAM's Y of the view's first line
SprBase     dw    0                   ; The view's first line * 160
SprBand     dw    0
SprVStart   dw    $2000               ; The screen addresses a whole cell of the view starts in
SprVEnd     dw    $2000+193*160
SprHm1      dw    7                   ; A sprite's height - 1, this render
List        ds    LISTSWAP*2+16
ListB       ds    LISTBSWAP*2+16

            DO    TILE_STATS          ; The counters (Stats.s)
tsSig       asc   'TILESTAT'
tsFrames    ENT
            ds    4                   ; Renders with the background on
tsFull      ENT
            ds    4                   ;   of which full renders (FlagMask 0)
tsStill     ENT
            ds    4                   ;   still frames (FLAG_STILL)
tsMoved     ENT
            ds    4                   ;   scrolled frames
tsSprTiles  ds    4                   ; 8x8 sprite tiles processed (an 8x16 sprite is 2: as PEA's gsSprTiles)
tsListed    ds    4                   ; Sprite cells listed: each is exposed once (PEA's gsExposed)
tsErased    ds    4                   ; Sprite cells whose tile was drawn under the sprite, shadowing off (PEA's gsErased)
tsErasedNew ds    4                   ;   of which the cell had no sprite last frame
tsLeft      ds    4                   ; Cells with a sprite last frame and none now
tsLeftDrawn ds    4                   ;   of which drawn by SprLeave / SprLeaveB (the rest: the thread)
tsNbr       ds    4                   ; Neighbors drawn for old sprite pixels (scrolled frames)
tsBgCells   ENT
            ds    4                   ; Changed cells drawn (DrawChanged; PEA's gsBgCells)
tsAttrs     ENT
            ds    4                   ; Changed attribute bytes (DrawAttr: up to 16 cells each)
tsSprSlow   ds    4                   ; Sprites drawn from their bitmaps (misses, clipped, behind the background)
tsTileComp  ENT
            ds    4                   ; Background slots compiled (TileInstance)
tsBankInval ENT
            ds    4                   ; Background banks invalidated (InvalidateMask: a palette group's color slots moved)
tsSprFlush  ENT
            ds    4                   ; Compiled sprite cache flushes (the sprite swizzle tables changed)
tsTplBuild  ENT
            ds    4                   ; Background templates built (BuildTemplate)
tsRecolor   ENT
            ds    4                   ; Compiled slots recolored by a palette remap (RecolorMask)
            FIN

            put   ../../game/tile/SprCode.s
            put   ../../game/tile/SprData.s
            put   ../../game/EngineExt.s

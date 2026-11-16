; Lists.s -- the display lists (docs/m17-thread-design.md): the screen's draw order, as data, and the thread that runs it.
; Two lists in bank 0 hold one entry per cell of the map, ListR by rows and ListC by columns.  An entry is the 3 bytes an
; rtl pulls: where the thread goes for that cell.  It is a function of the cell's own state and nothing else (ListSync):
;
;   a tile                the tile's slot, 4 bytes early: its advance (Tiles.s), in the cell's bank byte's bank
;   a tile on an edge     its clip entry (the word's role bits), in that bank
;   the solid tile        blank stub f, f from its four neighbor flags, in that bank
;
; The bank is the cell's bank byte in every case: its palette's bank, or the expose bank while a sprite is in the cell.  So a
; sprite coming or going changes only that byte, and the address is the same in either bank: the expose bank has its body
; at a tile's slot and at a blank stub.
;
; A strip (a map row in ListR, a map column in ListC) is its cells' entries in order, then one wrap entry (WrapR, WrapC): the
; map is a ring.  ListR: row * (ColsN + 1) entries + column; ListC: column * (RowsN + 1) + row.
;
; Every writer of a cell's word or flags calls ListSync for it.  A cell holds its two entries' addresses (ListAddr), so a
; sprite coming or going stores its bank byte in the cell and in both entries (Sprite.s CellFlip), and nothing looks anything up.
;
; The thread (DrawThread) draws the view by rows: S runs along ListR, and each rtl is the next cell.  While the view is where
; it is, each visible strip's entry after its last visible cell holds the strip's link (ListLink), and the cell's own entry
; is kept in LkSave: the cell's ListR address is its place there meanwhile, so its writers need not know.  ListC is kept up
; to date, and nothing runs it yet.

LIST_C      equ   $1800               ; ListC, from ListBase (ListR is 60 * 33 * 3 = 5940 bytes at most)
LIST_BYTES  equ   $3000               ; (ListC is 64 * 31 * 3 = 5952 at most)
LK_SAVE     equ   $2F40               ; LkSave, after ListC: per strip of the view, the entry its link stands in for (32 * 3 + 1 bytes)

; Both lists: one block in bank 0
AllocLists
:handle     equ   tmp+0
            pea   0
            pea   0
            pea   0
            pea   LIST_BYTES
            ldal  UserId
            pha
            pea   %11000000_00010101  ; Locked, fixed, page aligned, no bank crossing, in the bank given
            pea   0
            pea   0
            _NewHandle
            bcc   :ok
            brk   $04
:ok         pla
            sta   :handle
            pla
            sta   :handle+2
            lda   [:handle]
            sta   ListBase
            clc
            adc   #LK_SAVE
            sta   LkSaveA
            sta   RingL1+1
            inc
            inc
            sta   RingL2+1
            lda   #$FFFF
            sta   LkCol
            stz   LkN3
            rts

; The map's shape (after SetMirror): where a cell's entries are.  RowTab is indexed by the cell's high byte and $FC (its page
; and row, * 4): the row's strip in ListR, and its place in a column's strip.  ColTab by page * 128 + column * 4: its place
; in a row's strip, and the column's strip in ListC.  A page is 30 more rows (horizontal mirroring) or 32 more columns.
; RowAddr is a map row's strip in ListR.  The links' and wraps' operands are a strip's bytes, and the whole list's
ListGeom    lda   ColsN
            inc
            sta   LgT
            asl
            adc   LgT
            sta   LgStripR
            sta   WrapR+2
            sta   LinkR+8
            sta   LinkRing+8
            lda   RowsN
            inc
            sta   LgT
            asl
            adc   LgT
            sta   LgStripC
            sta   WrapC+2
            ldx   #0                  ; RowAddr, and the list's end
            lda   ListBase
:ra         sta   RowAddr,x
            clc
            adc   LgStripR
            inx
            inx
            cpx   #122                ; (60 rows, and the end)
            bcc   :ra
            lda   RowsN
            asl
            tax
            lda   RowAddr,x
            sta   LgEndR
            sec
            sbc   ListBase
            sta   LinkR+15
            sta   LinkRing+15
            ldx   #0
:l          txa
            lsr
            lsr
            and   #31
            sta   LgN
            txa
            and   #$0080
            sta   LgPage
            beq   :r
            lda   MirrorH
            beq   :r
            lda   #30
:r          clc                       ; (A = 0, or 30 on the second page of rows)
            adc   LgN
            sta   LgT
            asl
            adc   LgT
            sta   RowTab+2,x
            lda   LgT
            ldy   LgStripR
            jsr   :mul
            clc
            adc   ListBase
            sta   RowTab,x
            lda   LgPage
            beq   :c
            lda   MirrorH
            beq   :c32
            lda   #0
            bra   :c
:c32        lda   #32
:c          clc
            adc   LgN
            sta   LgT
            asl
            adc   LgT
            sta   ColTab,x
            lda   LgT
            ldy   LgStripC
            jsr   :mul
            clc
            adc   ListBase
            adc   #LIST_C
            sta   ColTab+2,x
            inx
            inx
            inx
            inx
            cpx   #256
            bcc   :l
            rts
:mul        sta   LgA                 ; A * Y, by adding (A is under 64).  X is kept
            sty   LgB
            lda   #0
:m          dec   LgA
            bmi   :mx
            clc
            adc   LgB
            bra   :m
:mx         rts

; Both lists, whole, from the cells: at the start, and when the map's shape changes (the links are off then: ListUnlink)
BuildLists  jsr   ListGeom
            stz   LgRow
:r          stz   LgCol
:c          lda   LgCol
            ldx   LgRow
            jsr   CellAt
            tay
            jsr   ListAddr
            jsr   ListSync
            inc   LgCol
            lda   LgCol
            cmp   ColsN
            bcc   :c
            inc   LgRow
            lda   LgRow
            cmp   RowsN
            bcc   :r
            lda   ListBase            ; The wrap entries: each strip's last
            ldy   RowsN
:wr         clc
            adc   LgStripR
            pha
            sec
            sbc   #3
            tax
            lda   #WrapR-1
            stal  $000000,x
            sep   #$20
            phk
            pla
            stal  $000002,x
            rep   #$20
            pla
            dey
            bne   :wr
            lda   ListBase
            clc
            adc   #LIST_C
            ldy   ColsN
:wc         clc
            adc   LgStripC
            pha
            sec
            sbc   #3
            tax
            lda   #WrapC-1
            stal  $000000,x
            sep   #$20
            phk
            pla
            stal  $000002,x
            rep   #$20
            pla
            dey
            bne   :wc
            rts

; A strip's wrap entry: S back to the strip's first entry.  The operands are a strip's bytes (ListGeom).  C clear, as a tile leaves it
WrapR       tsc
            sbc   #0                  ; (C is clear: one less)
            inc
            tcs
            clc
            rtl
WrapC       tsc
            sbc   #0
            inc
            tcs
            clc
            rtl

; Y = a cell: its entry, into both lists, at the addresses the cell holds.  Any DBR.  Keeps Y
ListSync    lda   [CellR],y
            tax
            and   #$007F
            cmp   #ROLE0
            bcs   :role
            cpx   #SOLIDTEST
            beq   :blank
            txa                       ; A tile: its advance - 1
            sec
            sbc   #5
            bra   :have
:role       txa                       ; A clip entry - 1
            dec
            bra   :have
:blank      lda   [FlagPtr],y         ; L, R, U, D are bits 0, 4, 8, 12
            and   #$1111
            pha
            xba
            asl
            asl
            ora   1,s
            and   #$00FF
            asl
            asl
            asl
            clc
            adc   #BLANK-1
            plx
:have       pha
            lda   [LcPtr],y
            tax
            lda   1,s
            stal  $000000,x
            sep   #$20
            lda   [FlipPtr],y
            stal  $000002,x
            rep   #$20
            lda   [LrPtr],y
            tax
            pla
            stal  $000000,x
            sep   #$20
            lda   [FlipPtr],y
            stal  $000002,x
            rep   #$20
            rts
            
; A = a cell: the same.  Keeps X and Y
ListSyncA   phx
            phy
            tay
            jsr   ListSync
            ply
            plx
            rts
            
; Y = a cell: where its two entries are, into the cell (the map's shape: ListGeom).  DBR = this bank.  Keeps Y
ListAddr    tya
            xba
            and   #$00FC
            tax
            lda   RowTab,x
            sta   LsR
            lda   RowTab+2,x
            sta   LsRow3
            tya
            and   #$03E0
            lsr
            lsr
            lsr
            cpy   #$8000
            bcc   :c
            ora   #$0080
:c          tax
            lda   ColTab+2,x
            clc
            adc   LsRow3
            sta   [LcPtr],y
            lda   ColTab,x
            clc
            adc   LsR
            sta   [LrPtr],y
            rts
            
; ---- The links: for the view at OriginRow, OriginCol, NR and NC (PatchLinks, when one of them changes).  A visible strip's
; entry after its last visible cell is the link to the next strip, or the exit.  That is the wrap entry when the view ends
; at the map's last column, and a cell's entry otherwise: its own goes to LkSave, and the cell's ListR address is its place
; there until the link comes off.  When the view is the whole ring (32
; columns of 32) the entry after the last cell is the first cell's, so the link starts the next strip by that cell's saved
; entry, and S starts past it (LinkRing)

; Both loops below run with DBR = 0 (the lists' bank), one pass per strip, and keep their state in the direct page:
LkE         equ   tmp+0               ; An entry's address
LkS         equ   tmp+2               ; The strip's place in LkSave
LkR2        equ   tmp+4               ; The strip's map row * 2
LkCC        equ   tmp+6               ; The links' column, as the cells' offset (CellCol)
LkCnt       equ   tmp+8
LkW         equ   tmp+10              ; A link's word
LkB         equ   tmp+12              ; and its bank byte: this bank
LkRows2     equ   tmp+14              ; The map's rows * 2
LkI3        equ   tmp+16              ; The links' place in a strip
LkHas       equ   tmp+18              ; Negative: the links are in the wrap entries, which are no cell's

; The links off: the entries back, and their cells' addresses
ListUnlink  lda   LkN3
            bne   :go
            rts
:go         jsr   LkSetup
            phb
            pea   $0000
            plb
            plb
:l          ldx   LkR2
            ldal  RowAddr,x
            clc
            adc   LkI3
            tax                       ; X = the entry, Y = its place in LkSave
            ldy   LkS
            sep   #$20
            lda:  $0002,y
            sta:  $0002,x
            rep   #$20
            lda:  $0000,y
            sta:  $0000,x
            bit   LkHas
            bmi   :nc
            stx   LkE                 ; Its cell writes to the entry again
            ldx   LkR2
            ldal  CellRow,x
            clc
            adc   LkCC
            tay
            lda   LkE
            sta   [LrPtr],y
:nc         lda   LkS
            clc
            adc   #3
            sta   LkS
            lda   LkR2
            inc
            inc
            cmp   LkRows2
            bcc   :k
            lda   #0
:k          sta   LkR2
            dec   LkCnt
            bne   :l
            plb
            stz   LkN3
            rts

; The loops' state, from the view the links are (or are about to be) placed for
LkSetup     lda   LkSaveA
            sta   LkS
            lda   LkRow0
            asl
            sta   LkR2
            lda   LkRows
            asl
            sta   LkRows2
            lda   LkIdx3
            sta   LkI3
            lda   LkNR
            sta   LkCnt
            lda   LkCol
            sta   LkHas
            bmi   :x
            asl
            tax
            lda   CellCol,x
            sta   LkCC
:x          rts

ListLink    stz   LkRing
            lda   RowsN
            sta   LkRows
            asl
            adc   RowsN
            sta   LkRing3
            lda   OriginRow
            sta   LkRow0
            asl
            adc   OriginRow
            sta   LkRow3
            lda   OriginCol
            clc
            adc   NC
            cmp   ColsN
            bne   :cell
            asl                       ; The wrap entry: no cell
            adc   ColsN
            sta   LkIdx3
            lda   #$FFFF
            bra   :col
:cell       bcc   :in
            sbc   ColsN               ; Around the ring
            pha
            lda   NC
            cmp   ColsN
            bne   :nr
            inc   LkRing
:nr         pla
:in         sta   LgT
            asl
            adc   LgT
            sta   LkIdx3
            lda   LgT
:col        sta   LkCol
            lda   NR
            sta   LkNR
            asl
            adc   NR
            sta   LkN3
            jsr   LkSetup
            lda   #LinkR-1
            ldy   LkRing
            beq   :lw
            lda   #LinkRing-1
:lw         sta   LkW
            sep   #$20
            phk
            pla
            sta   LkB
            rep   #$20
            phb
            pea   $0000
            plb
            plb
:l          ldx   LkR2
            ldal  RowAddr,x
            clc
            adc   LkI3
            tax                       ; X = the entry the link takes, Y = its place in LkSave: its own goes there
            ldy   LkS
            lda:  $0000,x
            sta:  $0000,y
            lda:  $0001,x
            sta:  $0001,y             ; (a byte into the next strip's: they are written in order, and LkSave has one to spare)
            lda   LkW
            sta:  $0000,x
            sep   #$20
            lda   LkB
            sta:  $0002,x
            rep   #$20
            stx   LkE
            bit   LkHas
            bmi   :nc
            ldx   LkR2                ; Its cell writes there meanwhile
            ldal  CellRow,x
            clc
            adc   LkCC
            tay
            lda   LkS
            sta   [LrPtr],y
:nc         lda   LkS
            clc
            adc   #3
            sta   LkS
            lda   LkR2
            inc
            inc
            cmp   LkRows2
            bcc   :k
            lda   #0
:k          sta   LkR2
            dec   LkCnt
            bne   :l
            ldx   LkE                 ; The last strip's is the exit
            lda   #ExitR-1
            sta:  $0000,x
            plb
            rts

; ---- The thread

; A blank stub's byte after its advance, in each background bank: rtl when this frame's mask finds one of its flags (a solid
; neighbor on that side, or FLAG_STILL: every one), nop to run on to the solid tile's body.  Only when the mask changes
StubsFor    lda   FlagMask
            and   SolidMask
            cmp   StubMask
            beq   :x
            sta   StubMask
            ldx   #0
:l          lda   StubTab,x
            tay
            lda   StubTab+2,x
            and   StubMask
            sep   #$20
            mx    %10
            beq   :draw
            lda   #$6B
            bra   :put
:draw       lda   #$EA
:put        sta   [BgPtr],y
            sta   [BgPtr+4],y
            sta   [BgPtr+8],y
            sta   [BgPtr+12],y
            rep   #$20
            mx    %00
            inx
            inx
            inx
            inx
            cpx   #64
            bcc   :l
:x          rts
StubMask    dw    0
StubTab     dw    BLANK+4,$0008       ; Per L + 2R + 4U + 8D: the stub's byte, and its flags
            dw    BLANK+12,$0009
            dw    BLANK+132,$0018
            dw    BLANK+140,$0019
            dw    BLANK+36,$0108
            dw    BLANK+44,$0109
            dw    BLANK+164,$0118
            dw    BLANK+172,$0119
            dw    BLANK+516,$1008
            dw    BLANK+524,$1009
            dw    BLANK+644,$1018
            dw    BLANK+652,$1019
            dw    BLANK+548,$1108
            dw    BLANK+556,$1109
            dw    BLANK+676,$1118
            dw    BLANK+684,$1119

; The view, by rows, top down.  Shadowing is on.  Interrupts are off while S is in the list, and let in once per strip
DrawThread  jsr   StubsFor
            lda   #4
            sta   Step
            lda   OriginCol           ; S for a strip: before its first visible entry, or after it when the link starts it
            asl
            adc   OriginCol
            dec
            ldx   LkRing
            beq   :p
            clc
            adc   #3
:p          sta   LgT
            lda   OriginRow
            asl
            tax
            lda   RowAddr,x
            clc
            adc   LgT
            sta   ThNextS
            lda   LgEndR
            clc
            adc   LgT
            sta   ThEnd
            stz   ThI
            lda   StartY
            sec
            sbc   #4
            tay
            phb
            php
            lda   1,s                 ; Interrupts are let in only if they were on
            and   #$0004
            sep   #$20
            mx    %10
            beq   :en
            lda   #$EA
            bra   :w
:en         lda   #$58
:w          sta   LinkR+23
            sta   RingWin
            sta   MissWin
            rep   #$20
            mx    %00
            sei
            ldx   LkRing
            pea   $0101
            plb
            plb
            tsc
            sta   ThS
            cpx   #0
            bne   :ring
            lda   ThNextS
            tcs
            clc
            rtl
:ring       jmp   RingGo

; The last strip's link: back to DrawThread's caller
ExitR       lda   ThS
            tcs
            stz   ThS
            plp
            plb
            rts

; A strip's link.  +8: a strip's bytes; +15: the list's; +23: cli or nop
LinkR       tya
            clc
            adc   Span
            tay
            lda   ThNextS
            adc   #0
            cmp   ThEnd
            bcc   :ok
            sbc   #0
:ok         sta   ThNextS
            tax
            lda   ThS
            tcs
            cli
            nop
            sei
            txs
            clc
            rtl

; The same when the view is the whole ring: the strip starts with its first cell's saved entry
LinkRing    tya
            clc
            adc   Span
            tay
            lda   ThNextS
            adc   #0
            cmp   ThEnd
            bcc   :ok
            sbc   #0
:ok         sta   ThNextS
            lda   ThS
            tcs
RingWin     cli
            nop
            sei
RingGo      ldal  ThI
            tax
            clc
            adc   #3
            stal  ThI
RingL1      ldal  $000000,x           ; (LkSave: AllocLists)
            inc
            stal  RingJ+1
            sep   #$20
RingL2      ldal  $000000,x           ; (LkSave + 2)
            stal  RingJ+3
            rep   #$20
            lda   ThNextS
            tcs
            clc
RingJ       jml   $000000

; TileMiss's window (Tiles.s): cli or nop
MissWin     cli
            rts

ListBase    ENT
            dw    0
RowTab      ENT
            ds    256
ColTab      ENT
            ds    256
RowAddr     ds    122
LkSaveA     ENT                       ; LkSave's address, in the lists' block
            dw    0
LkRow3      ENT                       ; The view the links are for: its first row * 3, its strips * 3, the link's place in a strip * 3
            dw    0
LkN3        ENT
            dw    0
LkIdx3      ENT
            dw    0
LkCol       dw    $FFFF               ; The map column whose entries the links stand in ($FFFF: none, the wrap entries)
LkRing      dw    0                   ; Not 0: the view is the whole ring
LkRing3     dw    0                   ; The map's rows * 3
LkRows      dw    0
LkRow0      dw    0
LkNR        dw    0                   ; The strips the links are in
ThI         dw    0                   ; LinkRing: the strip * 3
LgEndR      dw    0
LgStripR    dw    0
LgStripC    dw    0
LgT         dw    0
LgN         dw    0
LgPage      dw    0
LgA         dw    0
LgB         dw    0
LgRow       dw    0
LgCol       dw    0
LsR         dw    0
LsRow3      dw    0

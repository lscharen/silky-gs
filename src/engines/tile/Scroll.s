; Scroll.s -- the cells and their state layer.  The cell bank is a whole bank with one 32-byte record per CIRAM byte, at
; its offset * 32, so a nametable update touches one record.  A cell is data: what the thread does there is in the display
; lists (Lists.s), which every writer of a cell keeps in step.
;
;   +1   dw  flags          a bit per solid neighbor, FLAG_STILL, and the palette in bits 1-2
;   +4   dw  word           the tile's slot (tile * 128, plus an edge's role bits): SOLIDTEST for the solid tile with no role
;   +6   db  bank           its palette's bank, or the expose bank while a sprite is in the cell (Sprite.s).  Written as a
;                           word: +7 is CallT's tya
;   +8   dw  ListR address  where its entry is in each list (ListAddr).  ListR's is its place in LkSave while a link
;   +10  dw  ListC address  stands in the entry
;   +12  dw  CallZ          the same in every cell: the word the sprites use while the background is off (CELL_Z, Sprite.s)
;   +30  dw  stamp          the last frame with a sprite in this cell (Sprite.s)
;
; Each field has one job: the word says which tile and clip, the bank byte the palette's bank or the expose bank.  Edges are
; patched plainly: restore the old lines and apply the new ones, only when they change.

WORD        equ   4                   ; A cell's word
CELL_LR     equ   8                   ; Its list entries' addresses
CELL_LC     equ   10

; ---- Setup

AllocCells  jsr   AllocBank
            stz   CellPtr
            sta   CellPtr+2
            sta   CellW+2
            sta   FlipPtr+2
            sta   LrPtr+2
            sta   LcPtr+2
            sta   StampPtr+2
            xba
            ora   CellPtr+2
            sta   CellBankW
            lda   #WORD
            sta   CellW
            lda   #6
            sta   FlipPtr
            lda   #CELL_LR
            sta   LrPtr
            lda   #CELL_LC
            sta   LcPtr
            lda   #30
            sta   StampPtr
            lda   #WORD
            sta   CellR
            lda   CellPtr+2
            sta   CellR+2
            lda   #1
            sta   FlagPtr
            lda   CellPtr+2
            sta   FlagPtr+2
            rts


; The expose bank: filled by SprInit
AllocExpose jsr   AllocBank
            stz   ExpPtr
            sta   ExpPtr+2
            sta   ExposeBank
            rts

; Every cell from CIRAM: its word, its palette's bank, no stamp.  (SetFlags: the flags.  BuildLists: its entries)
BuildCells
:row        equ   tmp+0
:col        equ   tmp+2
:cell       equ   tmp+4
:word       equ   tmp+6
            phb
            pei   CellBankW
            plb
            plb
            stz   :row
:r          stz   :col
:c          lda   :row
            asl
            tax
            ldal  CellRow,x
            sta   :cell
            lda   :col
            asl
            tax
            ldal  CellCol,x
            clc
            adc   :cell
            sta   :cell
            lsr                       ; Its CIRAM byte: cell / 32
            lsr
            lsr
            lsr
            lsr
            tax
            ldal  PPU_CIRAM,x
            and   #$00FF
            xba
            lsr
            ora   #BGWORD
            cmp   #SOLIDWORD          ; The solid tile's word
            bne   :w
            lda   #SOLIDTEST
:w          sta   :word
            ldx   :cell
            lda   :word
            sta:  WORD,x
            lda   :cell               ; Its palette's bank
            lsr
            lsr
            lsr
            lsr
            lsr
            tax
            jsr   PalOf
            tax
            lda   HomeFlip,x
            ldx   :cell
            sta:  $0006,x
            stz:  $001E,x             ; The stamp
            inc   :col
            lda   :col
            cmpl  ColsN
            bcs   :nc
            brl   :c
:nc         inc   :row
            lda   :row
            cmpl  RowsN
            bcs   :done
            brl   :r
:done       lda   #$FFFF
            plb
            sta   FineScroll
            rts
            
; ---- The solid-background skip.  A cell holding the solid tile has flags with a bit for each neighbor that is solid.  They
; say what last frame's screen could have shown under it: scrolling left by up to a cell, its bytes showed this cell and the
; one to its left.  Its list entry is the blank stub for its four bits, and each frame's mask says which stubs skip
; (StubsFor): this direction's bit, FLAG_STILL on a still frame (every blank cell skips, and whatever else is on the screen is
; drawn again), nothing on a full render.  A direct call simply draws.
FLAG_L      equ   $0001
FLAG_R      equ   $0010
FLAG_U      equ   $0100
FLAG_D      equ   $1000
FLAG_STILL  equ   $0008               ; Set in every cell: on a still frame, a solid cell always skips
SkipRow     equ   tmp+20
SkipCol     equ   tmp+22

; All the flags, once
SetFlags    stz   SkipRow
:r          stz   SkipCol
:c          jsr   FlagCell
            inc   SkipCol
            lda   SkipCol
            cmp   ColsN
            bcc   :c
            inc   SkipRow
            lda   SkipRow
            cmp   RowsN
            bcc   :r
            rts
            
; SkipRow, SkipCol: the cell's flags, from CIRAM and its neighbors on this map
FlagCell
:flags      equ   tmp+24
:mask       equ   tmp+26
            lda   SkipCol             ; Its palette, in two spare bits of the flags
            ldx   SkipRow
            jsr   CellAt
            lsr
            lsr
            lsr
            lsr
            lsr
            tax
            jsr   PalOf
            ora   #FLAG_STILL
            sta   :flags
            lda   SkipCol             ; Left
            dec
            and   ColMask
            ldx   SkipRow
            ldy   #FLAG_L
            jsr   :nbr
            lda   SkipCol             ; Right
            inc
            and   ColMask
            ldx   SkipRow
            ldy   #FLAG_R
            jsr   :nbr
            lda   SkipRow             ; Up
            dec
            bpl   :u
            lda   RowLast
:u          tax
            lda   SkipCol
            ldy   #FLAG_U
            jsr   :nbr
            lda   SkipRow             ; Down
            inc
            jsr   ModRows
            tax
            lda   SkipCol
            ldy   #FLAG_D
            jsr   :nbr
            lda   SkipCol
            ldx   SkipRow
            jsr   CellAt
            tay
            lda   :flags
            sta   [FlagPtr],y
            rts
:nbr        sty   :mask
            jsr   IsSolid
            bne   :n
            lda   :flags
            ora   :mask
            sta   :flags
:n          rts

; ---- A change of mirroring (PPUSetMirrorModeL): what differs between the maps is on their seams

; Edges and links back to plain, under the map they were made on
UnpatchView lda   #2
            sta   WKind
            jsr   RestoreEdges
            jsr   ListUnlink
            stz   EdgeNC
            stz   LinkN
            rts
            
; The new map's seams: the flags of its first and last columns and rows, including where a page ends
SeamFix     lda   #0
            jsr   :col
            lda   #31
            jsr   :col
            lda   #0
            jsr   :row
            lda   #29
            jsr   :row
            lda   MirrorH
            bne   :h
            lda   #32
            jsr   :col
            lda   #63
            jmp   :col
:h          lda   #30
            jsr   :row
            lda   #59
:row        sta   SkipRow
            stz   SkipCol
:rl         jsr   FlagCell
            inc   SkipCol
            lda   SkipCol
            cmp   ColsN
            bcc   :rl
            rts
:col        sta   SkipCol
            stz   SkipRow
:cl         jsr   FlagCell
            inc   SkipRow
            lda   SkipRow
            cmp   RowsN
            bcc   :cl
            rts

; A = a column, X = a row: the cell's offset
CellAt      asl
            tay
            txa
            asl
            tax
            lda   CellRow,x
            clc
            adc   CellCol,y
            rts

; A = a column, X = a row: Z set if that cell holds the solid tile.  From its word: CIRAM can be ahead of the cells, by the
; writes since the latch
IsSolid     jsr   CellAt
            tay
            lda   [CellR],y
            and   #$FF80
            cmp   #SOLIDWORD
            rts

; This frame's motion, when it has moved (tmp+0, tmp+2: the scroll; tmp+4, tmp+6: last frame's): which flag the solid tile tests, and what
; SprLeave needs for old sprite pixels.  One axis, by up to a cell: anything else is a full render
SetDirection
:px         equ   tmp+0
:py         equ   tmp+2
:lastx      equ   tmp+4
:lasty      equ   tmp+6
:dx         equ   tmp+8
:dy         equ   tmp+10
            stz   StaleOn
            lda   :lastx
            cmp   #$FFFF              ; (Nothing on the screen yet)
            bne   :go
:full       stz   FlagMask
            rts
:go
            lda   :px
            sec
            sbc   :lastx
            and   #$00FF
            cmp   #$0080
            bcc   :xs
            ora   #$FF00
:xs         sta   :dx
            lda   :py
            sec
            sbc   :lasty
            bpl   :y1
            clc
            adc   RowLines            ; 0 to the map's last line
:y1         cmp   RowHalf
            bcc   :ys
            sbc   RowLines
:ys         sta   :dy
            lda   :dx
            beq   :vert
            ldx   :dy
            bne   :full
            tax                       ; Across
            bmi   :xneg
            cmp   #5
            bcs   :full
            eor   #$FFFF              ; Left: the old pixels are on the cell and the one to its right
            inc
            sta   StaleDY
            ldx   #0
            lda   #4
            bra   :set
:xneg       cmp   #-4
            bcc   :full
            eor   #$FFFF              ; Right
            inc
            sta   StaleDY
            ldx   #1
            lda   #-4
            bra   :set
:vert       lda   :dy
            bmi   :yneg
            cmp   #9
            bcs   :full
            asl                       ; Up: on the cell and the one below it
            tay
            lda   #0
            sec
            sbc   Line160,y
            sta   StaleDY
            ldx   #2
            lda   #1280
            bra   :set
:yneg       cmp   #-8
            bcs   :y8
            brl   :full
:y8
            eor   #$FFFF              ; Down
            inc
            asl
            tay
            lda   Line160,y
            sta   StaleDY
            ldx   #3
            lda   #-1280
:set        clc
            adc   StaleDY
            sta   NbrDY
            txa
            asl
            tax
            ora   MirrorH             ; (the other map's neighbors are NbrTab's second half)
            sta   NbrIdx
            lda   FlagBits,x
            sta   FlagMask
            lda   #1
            sta   StaleOn
            rts
FlagBits    dw    FLAG_L,FLAG_R,FLAG_U,FLAG_D

; ---- The frame

Update
:px         equ   tmp+0
:py         equ   tmp+2
            lda   ViewPx
            sta   :px
            lda   ViewPy
            sta   :py
            cmp   LastPy
            bne   :moved
            lda   :px
            cmp   LastPx
            bne   :moved
            lda   #FLAG_STILL         ; Still: the thread runs, and every solid cell skips
            sta   FlagMask
            stz   StaleOn
            rts
:moved      lda   LastPx
            sta   tmp+4
            lda   LastPy
            sta   tmp+6
            lda   :px
            sta   LastPx
            asl
            asl
            sta   WorldX
            lda   :px
            and   #3
            sta   SX
            lda   :px
            lsr
            lsr
            sta   OriginCol
            lda   :py
            sta   LastPy
            asl
            sta   WorldY
            lda   :py
            and   #7
            sta   SY
            lda   :py
            lsr
            lsr
            lsr
            sta   OriginRow
            stz   Order               ; (rows, top-down: the thread runs ListR)
            jsr   SetDirection

            ldy   #32
            lda   Order
            asl
            ldx   SX
            beq   :h
            iny
            ora   #1
:h          sty   NC
            asl
            ldy   ViewRows
            ldx   SY
            beq   :v
            iny
            ora   #1
:v          sty   NR
            sta   FrameType

            lda   SY
            asl
            asl
            ora   SX
            cmp   FineScroll
            beq   :vecs
            sta   FineScroll
            jsr   ClipCases
:vecs
MarkPatch   ENT
            jsr   PatchEdges
            jsr   PatchLinks
            jmp   FrameVals

ClipCases   stz   HC
            stz   HC+2
            stz   HC+4
            stz   VC
            stz   VC+2
            stz   VC+4
            lda   SX
            beq   :v
            asl
            asl
            asl
            asl
            asl
            sta   HC+2
            lda   #7
            sec
            sbc   SX
            asl
            asl
            asl
            asl
            asl
            sta   HC+4
:v          lda   SY
            beq   :set
            asl
            sta   VC+2
            lda   #15
            sec
            sbc   SY
            asl
            sta   VC+4
:set        jsl   SetEVecs
            jmp   SetVecs

; ---- Walking a line of cells

WFix        equ   tmp+0               ; The fixed row (row runs) or column (column runs)
WIdx        equ   tmp+2               ; The first column (row runs) or row (column runs)
WCount      equ   tmp+4
WVal        equ   tmp+6
WKind       equ   tmp+8               ; 0 role WVal, 2 no role
WSeg        equ   tmp+12
WTab        equ   tmp+14              ; The unrolled run's entries (Walk.s)

; WCount cells of row WFix from column WIdx.  Columns are 32 cells apart, up to the nametable's end
WalkRowRun
:seg        lda   WIdx
            and   #31
            eor   #$FFFF
            sec
            adc   #32
            cmp   WCount
            bcc   :n
            lda   WCount
:n          sta   WSeg
            lda   WIdx
            asl
            tay
            lda   WFix
            asl
            tax
            lda   CellRow,x
            clc
            adc   CellCol,y
            tay
            ldx   WKind
            jsr   (ActRowTab,x)
            lda   WIdx
            clc
            adc   WSeg
            and   ColMask
            sta   WIdx
            lda   WCount
            sec
            sbc   WSeg
            sta   WCount
            bne   :seg
            rts

; WCount cells of column WFix from row WIdx.  Rows are 1024 bytes apart, to the end of a page of CIRAM
WalkColRun
:seg        lda   WIdx
            cmp   #30
            bcc   :in
            sbc   #30
:in         eor   #$FFFF
            sec
            adc   #30
            cmp   WCount
            bcc   :n
            lda   WCount
:n          sta   WSeg
            lda   WFix
            asl
            tay
            lda   WIdx
            asl
            tax
            lda   CellRow,x
            clc
            adc   CellCol,y
            tay
            ldx   WKind
            jsr   (ActColTab,x)
            lda   WIdx
            clc
            adc   WSeg
            cmp   RowsN
            bcc   :w
            lda   #0
:w          sta   WIdx
            lda   WCount
            sec
            sbc   WSeg
            sta   WCount
            bne   :seg
            rts

ActRowTab   dw    ActRoleR,ActClearR
ActColTab   dw    ActRoleC,ActClearC
            
; WSeg cells from cell Y, by the unrolled runs in Walk.s: each enters at its WSeg'th entry and ends plb / rts.  A run writes
; each cell's word and its two list entries (at the addresses the cell holds)
ActRoleR    lda   #RoleRow            ; The word keeps its tile and takes role WVal (not 0)
            bra   ActWord
ActRoleC    lda   #RoleCol
            bra   ActWord
ActClearR   lda   #ClearRow           ; The word keeps its tile and loses its role
            bra   ActWord
ActClearC   lda   #ClearCol
ActWord     sta   WTab
            lda   WSeg
            asl
            adc   WTab
            tax
            phb
            pei   CellBankW
            plb
            plb
            jmp   ($0000,x)
            
; A = a row + A's ring distance: around the map
ModRows     cmp   RowsN
            bcc   :x
            sbc   RowsN
:x          rts

; ---- The edges: 2 lines across, 2 along, whichever fine scroll has them.  No dependence on the order

PatchEdges  lda   ViewRows
            cmp   EdgeVR
            bne   :go
            lda   OriginCol
            cmp   EdgeCol
            bne   :go
            lda   OriginRow
            cmp   EdgeRow
            bne   :go
            lda   NC
            cmp   EdgeNC
            bne   :go
            lda   NR
            cmp   EdgeNR
            bne   :go
            rts
:go         lda   #2
            sta   WKind
            jsr   RestoreEdges
            stz   WKind
            jsr   ApplyEdges
            lda   OriginCol
            sta   EdgeCol
            lda   OriginRow
            sta   EdgeRow
            lda   NC
            sta   EdgeNC
            lda   NR
            sta   EdgeNR
            lda   ViewRows
            sta   EdgeVR
            rts
            
; The old lines back to plain tiles (a corner twice)
RestoreEdges
:col        equ   tmp+16
:row        equ   tmp+18
:nc         equ   tmp+20
:nr         equ   tmp+22
:vr         equ   tmp+24
            lda   EdgeVR
            sta   :vr
            lda   EdgeCol
            sta   :col
            lda   EdgeRow
            sta   :row
            lda   EdgeNR
            sta   :nr
            lda   EdgeNC
            sta   :nc
            beq   :x                  ; (never patched)
            cmp   #33
            bne   :rows
            lda   :col                ; The left column
            sta   WFix
            lda   :row
            sta   WIdx
            lda   :nr
            sta   WCount
            jsr   WalkColRun
            lda   :col                ; The right column
            clc
            adc   :nc
            dec
            and   ColMask
            sta   WFix
            lda   :row
            sta   WIdx
            lda   :nr
            sta   WCount
            jsr   WalkColRun
:rows       lda   :nr
            cmp   :vr
            beq   :x
            lda   :row                ; The top row
            sta   WFix
            lda   :col
            sta   WIdx
            lda   :nc
            sta   WCount
            jsr   WalkRowRun
            lda   :row                ; The bottom row
            clc
            adc   :nr
            dec
            jsr   ModRows
            sta   WFix
            lda   :col
            sta   WIdx
            lda   :nc
            sta   WCount
            jsr   WalkRowRun
:x          rts

; The new lines, with their corners last
ApplyEdges
:top        equ   tmp+16
:bottom     equ   tmp+18
:right      equ   tmp+20
:inRows     equ   tmp+22
            lda   OriginRow
            sta   :top
            clc
            adc   NR
            dec
            jsr   ModRows
            sta   :bottom
            lda   OriginCol
            clc
            adc   NC
            dec
            and   ColMask
            sta   :right
            lda   SX
            beq   :rows
            lda   :top                ; The columns, without their corners
            ldx   NR
            ldy   SY
            beq   :c1
            inc
            jsr   ModRows
            dex
            dex
:c1         sta   :inRows
            stx   WCount
            sta   WIdx
            lda   OriginCol
            sta   WFix
            lda   RoleTab+2
            sta   WVal
            jsr   WalkColRun
            lda   :inRows
            sta   WIdx
            ldx   NR
            ldy   SY
            beq   :c2
            dex
            dex
:c2         stx   WCount
            lda   :right
            sta   WFix
            lda   RoleTab+4
            sta   WVal
            jsr   WalkColRun
:rows       lda   SY
            bne   :doRows
            rts
:doRows
            lda   OriginCol           ; The rows, without their corners
            ldx   NC
            ldy   SX
            beq   :r1
            inc
            and   ColMask
            dex
            dex
:r1         sta   :inRows
            sta   WIdx
            stx   WCount
            lda   :top
            sta   WFix
            lda   RoleTab+6
            sta   WVal
            jsr   WalkRowRun
            lda   :inRows
            sta   WIdx
            ldx   NC
            ldy   SX
            beq   :r2
            dex
            dex
:r2         stx   WCount
            lda   :bottom
            sta   WFix
            lda   RoleTab+12
            sta   WVal
            jsr   WalkRowRun
            lda   SX
            beq   :x
            lda   #1                  ; The corners
            sta   WCount
            lda   :top
            sta   WFix
            lda   OriginCol
            sta   WIdx
            lda   RoleTab+8
            sta   WVal
            jsr   WalkRowRun
            lda   #1
            sta   WCount
            lda   :right
            sta   WIdx
            lda   RoleTab+10
            sta   WVal
            jsr   WalkRowRun
            lda   #1
            sta   WCount
            lda   :bottom
            sta   WFix
            lda   OriginCol
            sta   WIdx
            lda   RoleTab+14
            sta   WVal
            jsr   WalkRowRun
            lda   #1
            sta   WCount
            lda   :right
            sta   WIdx
            lda   RoleTab+16
            sta   WVal
            jsr   WalkRowRun
:x          rts

; ---- The links: the lists' (Lists.s ListLink), placed again only when they move.  A link is in the entry after its strip's
; last visible cell, at column OriginCol + NC: so of the two frames that take the view across a cell (onto the cell's edge,
; 32 columns, and off it again, 33) only one moves them

PatchLinks  lda   OriginCol
            clc
            adc   NC
            tax                       ; X = the links' column
            ldy   #0                  ; Y = the view is the whole ring
            lda   NC
            cmp   ColsN
            bne   :k
            iny
:k          cpx   LinkEnd
            bne   :go
            cpy   LinkWasRing
            bne   :go
            lda   OriginRow
            cmp   LinkRow
            bne   :go
            lda   NR
            cmp   LinkN
            bne   :go
            rts
:go         stx   LinkEnd
            sty   LinkWasRing
            jsr   ListUnlink
            lda   OriginRow
            sta   LinkRow
            lda   NR
            sta   LinkN
            jmp   ListLink

; ---- The frame's values: O(1)
FrameVals
            lda   FrameType
            asl
            asl
            asl
            asl
            tax
            lda   SY
            asl
            tay
            lda   ViewportA           ; Where the top-left tile would start if it were not clipped
            sec
            sbc   Line160,y
            sbc   SX                  ; (C is still set)
            clc
            adc   FV+2,x
            sta   StartY
            lda   FV,x
            sta   Span
            rts
            
; ---- Data
Order       ds    2
FrameType   ds    2
EdgeCol     ds    2                   ; What the edges were last patched for (EdgeNC 0: never)
EdgeRow     ds    2
EdgeNC      ds    2
EdgeNR      ds    2
EdgeVR      ds    2
LinkEnd     ds    2                   ; What the links were last placed for (LinkN 0: never)
LinkRow     ds    2
LinkWasRing    ds    2
LinkN       ds    2

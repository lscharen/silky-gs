; Dp.s -- the engine's direct page: the page after the runtime's (Front.s PPUStartUpL).  The direct page holds only the state that lasts between frames, and tmp, the
; temporaries.  A routine names the temporaries it uses with local equates (:thing equ tmp+n), so they are valid
; only until it returns.

; ---- The program
Step        equ   0           ; The thread's step from a cell's screen address to the next: 4 by rows, 1280 by columns (a slot's advance adds it)
OStartB     equ   2           ; The fixed band's list (index): last frame's

; ---- Long pointers into the two allocated banks (4 bytes each).  With Y = a cell: its word, bank byte, stamp
CellPtr     equ   4
CellW       equ   8
FlipPtr     equ   12          ; (its bank byte)
LrPtr       equ   16          ; Its ListR entry's address (in LkSave while a link stands there: Lists.s)
StampPtr    equ   20
ExpPtr      equ   24
CELL_Z      equ   12          ; (a cell's field, not the page: CallZ's address, where CellW points while the background is off: Sprite.s)
CellBankW   equ   32          ; The cell bank in both bytes (pei / plb / plb)
ExposeBank  equ   34

; ---- The frame's values, read by the thread's links (with any DBR)
Span        equ   36          ; Strip to strip
ThNextS     equ   38          ; The thread (Lists.s): S for the strip being drawn, in ListR
ThS         equ   40          ; The real stack while the thread runs, 0 while it doesn't: the slow paths test it
ThEnd       equ   42          ; ThNextS past the map's last row: around to the first
StartY      equ   46
LcPtr       equ   48          ; Long pointer: with Y = a cell, its ListC entry's address (48-51)

; ---- The view
LastPx      equ   52          ; The scroll, in bytes and lines
LastPy      equ   54
WorldX      equ   56          ; px * 4 and py * 2: add x * 2 or y * 2 to index WCol and WRow
WorldY      equ   58
DynD        equ   60          ; This frame's page of dynamic tiles (Tiles.s): set once per frame, read by each dynamic tile
OriginCol   equ   62          ; The first visible map column / row, and the fine scroll in it
SX          equ   64
OriginRow   equ   66
SY          equ   68
NC          equ   70          ; Visible columns: 32, or 33 with a fine horizontal scroll
NR          equ   72          ; Visible rows: VIEWROWS, or one more with a fine vertical scroll
FineScroll  equ   74          ; sy << 2 | sx: what the clip cases were last set for
HC          equ   76          ; The clip cases: h * 32 for mid / left / right (SetVecs, SetEVecs)
VC          equ   82          ; v * 2 for mid / top / bottom

; ---- The sprites
Stamp       equ   88          ; This frame's stamp, last frame's
PStamp      equ   90
FlipOn      equ   92          ; A cell's bank word with a sprite in the cell (HomeFlip: without)
NStart      equ   96          ; The list (index): this frame's cells
NEnd        equ   98
OStart      equ   100         ; Last frame's
OEnd        equ   102
FlagPtr     equ   104         ; Long pointer: with Y = a cell, its flags
StaleOn     equ   108         ; Not 0: this frame's cells may skip, so old sprite pixels need drawing
StaleDY     equ   110         ; From a cell's screen address last frame to this frame's
NbrIdx      equ   112         ; The neighbor that holds a cell's old sprite pixels: * 2, for NbrTab
NbrDY       equ   114         ; From a cell's screen address last frame to its neighbor's this frame
FlagMask    equ   116         ; This direction's bit in the flags

; ---- The tileset (Tiles.s)
BgPtr       equ   118         ; Long pointers to the four background banks: 118, 122, 126, 130
ColorPtr    equ   134         ; The colored bitmap bank
ColorW      equ   138         ; Its bank in both bytes (pei / plb / plb)
BitsPtr     equ   140         ; The 2-bit tiles
SwzPtr      equ   144         ; This palette's swizzle tables
LzPtr       equ   148         ; A background bank, for the routines below
HomeFlip    equ   152         ; Per palette * 2: a cell's bank word with no sprite in the cell (8 bytes)
LzBase      equ   160         ; Palette * $4000
LzTile      equ   162         ; Tile * 128
LzScreen    equ   164
LzRet       equ   166
LzIdx       equ   168         ; Palette * $200: into the swizzle tables
LzDst       equ   170         ; The tile's colored bitmap
LzV         equ   172
LzI         equ   174
LzN         equ   176
LzMask      equ   178         ; The background groups being invalidated
SkipW       equ   180         ; The slot InvalidateBank leaves alone
OEndB       equ   182
TplPtr      equ   184         ; Long pointer: the template bank (Tiles.s), indexed as tiledata (184-187)

CellR       equ   190         ; Long pointer: with Y = a cell, its word (as CellW)
NwVal       equ   194         ; The cell writes' temporaries (Front.s)
NwCell      equ   198
NwNew       equ   200
NwOld       equ   202
NwRow       equ   204
NwCol       equ   206
NwE         equ   208
NwT         equ   210
NwA         equ   212         ; PutAttr's: to 223

; SprDraw's and SprLeave's, in the cell writes' words: ApplyNt runs before them and Promote after, so these are free then
SprOyD      equ   NwVal       ; SprOy, SprBase: the view's (SprViewL), for this frame
SprBaseD    equ   196         ; (its own word: no cell write uses it)
SprLimD     equ   NwCell      ; (lines - height + 1)
SprShD      equ   NwNew       ; This sprite's shifted variant, as a page offset
NewBD       equ   NwOld       ; This frame's cells new to N, in list bytes (CountNew)

NEndB       equ   188         ; The fixed band's list: this frame's starts at OStartB eor LISTBSWAP
SprTbl      equ   28          ; Long pointer: this pattern table's half of the compiled sprites' table
SprPar      equ   94          ; scroll_x & 1: the half-pixel offset of every sprite this frame

; ---- The temporaries: tmp to the end of the page, for routines' local equates
tmp         equ   224
ThFix       equ   tmp+28      ; In the thread: what the slot's jsr wrote over, for ClipDone (ClipCode.s).  4 bytes

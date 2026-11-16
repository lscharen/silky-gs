; Tiles.s -- the tileset: one background bank per attribute palette, filled lazily.  Three forms of a tile, each kept:
;
;   TileBits    the 2-bit tile (silky's tiledata): tile * 128, palette independent
;   the template bank   indexed as tiledata: the tile's code with its swizzle indices as the operands, palette independent
;   the colored bitmap bank   palette * $4000 + tile * 32: its 32 screen bytes, through the palette's swizzle table
;   a background bank, one per palette   tile * 128: its slot
;
; A slot, 128 bytes, so 512 fill a bank:
;
;   +0    the compiled tile (at most 97 bytes), or jsr to a stub (below)
;   +97   3 spare bytes: in the solid tile's slot, jmp to its body (SOLIDTEST: the word of a cell that holds it)
;   +100  8 clip entries: jsr to a stub, 3 bytes each
;   +124  the next slot's advance: tya / adc Step / tay, which runs into its +0.  The thread of display lists enters a slot
;         there (4 bytes before it); a call enters at +0 and keeps Y.  Written once (TilesInit): nothing else stores there
;
; A bank's low half holds no slots (a cell's word is $8000 up): its stubs are there, STUB_GAP apart from STUBQ, and the blank stubs.
;
; A cell's word is tile * 128, plus ROLE0 + (edge - 1) * 3 when clipped, and its bank byte is its palette's bank.  Any
; word and bank are callable.  The stubs are the same in every bank but for the palette: lda #palette * $4000 / jmp >target.
; A slot's jsr leaves its address on the stack, so the target knows the tile.
;
;   Empty     +0 and the clip entries: jsr StubQ.  TileMiss (or Sweep, for the tiles CIRAM shows) makes the colored
;             bitmap and the code, and draws from the colored bitmap this once
;   Compiled  +0: the code.  The clip entries: jsr StubE<e>, which draw from the colored bitmap
;
; The code comes from the tile's template (TileInstance): its code is built once from the 2-bit tile, with each distinct
; swizzle index loaded once and stored to every place it goes, and a palette's copy only swaps those operands for its
; colors.  So a slot is compiled the first time it is needed, for the cost of a copy, and a palette's slots need no
; compiler.  The solid tile is compiled at the start and never invalidated: color 0 is slot 0 in every palette.
;
; A template (128 bytes, at the tile's tiledata offset):
;
;   +0    the code (at most 97 bytes): lda #index / sta offset,y ... / rtl
;   +97   its length, +98 the number of operands, +99 each operand's offset (up to 16)

STUBQ       equ   $40                 ; The stubs, STUB_GAP apart, in the bank's first page (EmptyOne: the high byte is 0)
STUB_GAP    equ   8
STUBF       equ   STUBQ+8
STUBE       equ   STUBQ+16            ; Edges 1-8
STUBD       equ   STUBQ+80            ; A dynamic tile's edges 1-8
STUBS_N     equ   18
JSR_STUBQ   equ   STUBQ*256+$20       ; The word at a slot's +0 when it is empty: jsr StubQ
TPL_LEN     equ   97                  ; A template's length, operand count and operand offsets (above)
TPL_N       equ   98
TPL_OPS     equ   99

; ---- Setup

AllocTiles  ldx   #0
:b          phx
            jsr   AllocBank
            plx
            stz   BgPtr,x
            sta   BgPtr+2,x
            pha
            txa
            lsr
            tax
            pla
            ora   #$9800              ; A cell's bank word: the bank byte, and the tya that follows it in CallT
            sta   HomeFlip,x
            txa
            asl
            inc
            inc
            inc
            inc
            tax
            cpx   #16
            bcc   :b
            jsr   AllocBank
            stz   ColorPtr
            sta   ColorPtr+2
            sta   ColorW
            xba
            ora   ColorW
            sta   ColorW
            lda   #tiledata
            sta   BitsPtr
            lda   #^tiledata
            sta   BitsPtr+2
            jsr   AllocBank           ; The templates
            stz   TplPtr
            sta   TplPtr+2
            rts

; Every bank: stubs, every slot empty, the solid tile compiled (its colored bitmap is only slot 0, from ZeroSw)
TilesInit
:i          equ   tmp+0
            lda   #ZeroSw
            sta   SwzPtr
            phk
            phk
            pla
            and   #$00FF
            sta   SwzPtr+2
            lda   #$FFFF
            sta   SkipW
            stz   :i
:b          ldx   :i
            lda   BgPtr+2,x
            sta   LzPtr+2
            stz   LzPtr
            jsr   MakeStubs
            jsr   InvalidateBank
            jsr   DynInstall
            lda   :i                  ; The solid tile
            xba
            asl
            asl
            asl
            asl
            sta   LzBase
            lda   #SOLIDWORD
            sta   LzTile
            jsr   MakeTile
            lda   :i
            lsr
            lsr
            ora   #SOLIDWORD
            jsr   CompileOne
            jsr   SlotFixed
            lda   :i
            clc
            adc   #4
            sta   :i
            cmp   #16
            bcc   :b
            lda   #SOLIDWORD
            sta   SkipW
            ldx   #TPL_OK_N*2-2       ; No template is made yet
:t          stz   TplOk,x
            dex
            dex
            bpl   :t
            rts

; ---- What the slots hold changes: the background table, or a tile in CHR-RAM.  On the render, before anything is drawn.
; The solid tile's cells skip only while it is blank (SolidMask, DrawThread).  While it isn't, its slot is like any other.

; PPUCTRL selected the other table: every slot holds the wrong tile
BgSwitch    lda   BgNew
            cmp   BgHi
            bne   :go
            rts
:go         sta   BgHi
            jsr   SolidCheck
            lda   #$000F
            sta   LzMask
            jsr   InvalidateMask
            lda   #1
            sta   RefreshF
            sta   StatusF
            rts

; Is the solid tile blank in this table?  A change compiles it again, or lets it be invalidated like the rest.  Without
; SOLID_CHECK (the game's TileGame.js: solidCheck: false) it is always blank: the CHR isn't read
SolidCheck
:i          equ   tmp+0
            lda   #SOLID_CHECK        ; (Tables.s, assembled after this file: an operand, not a DO)
            beq   :blank
            lda   BgHi
            lsr
            lsr
            lsr                       ; $1000 for the table at $1000
            ora   #SOLIDTILE*16
            tax
            ldy   #8
:b          ldal  PPU_MEM,x
            bne   :notblank
            inx
            inx
            dey
            bne   :b
:blank      lda   SolidMask           ; Blank
            bne   :same
            lda   #$FFFF
            sta   SolidMask
            lda   #SOLIDWORD
            sta   SkipW
            lda   SwzPtr              ; Its body is only slot 0, in every palette
            pha
            lda   SwzPtr+2
            pha
            lda   #ZeroSw
            sta   SwzPtr
            phk
            phk
            pla
            and   #$00FF
            sta   SwzPtr+2
            stz   :i
:s          lda   :i
            xba
            asl
            asl
            asl
            asl
            sta   LzBase
            lda   #SOLIDWORD
            sta   LzTile
            jsr   MakeTile
            lda   :i
            lsr
            lsr
            ora   #SOLIDWORD
            jsr   CompileOne
            lda   :i
            clc
            adc   #4
            sta   :i
            cmp   #16
            bcc   :s
            pla
            sta   SwzPtr+2
            pla
            sta   SwzPtr
:same       rts
:notblank   lda   SolidMask
            beq   :same
            stz   SolidMask
            lda   #$FFFF
            sta   SkipW
            lda   #SOLIDWORD
            jmp   EmptySlots
SolidMask   dw    $FFFF

; A = a slot: empty, in each of the four banks where it is compiled
EmptySlots
:i          equ   tmp+0
:slot       equ   tmp+2
            sta   :slot
            stz   :i
:b          ldx   :i
            phb
            sep   #$20
            lda   BgPtr+2,x
            pha
            plb
            rep   #$20
            ldy   :slot
            lda:  0,y                 ; Only where it is compiled: an empty slot stays as it is
            cmp   #JSR_STUBQ
            beq   *+5
            jsr   EmptyOne
            plb
            lda   :i
            clc
            adc   #4
            sta   :i
            cmp   #16
            bcc   :b
            rts

            DO    HAS_CHR_RAM
; The tiles rewritten since the last render: slots of the table in use go back to empty, and a tile is reconverted when it is next
; needed (ChrFresh).  Cells need nothing: the thread draws every one that isn't the solid tile.  The queue holds a tile once, until
; its background flag is cleared (ChrFresh), so it can't overflow
ChrDrain
:t          equ   tmp+4
            ldx   ChrHead
:l          cpx   ChrTail
            beq   :x
            lda   ChrQ,x
            sta   :t
            txa
            inc
            inc
            and   #CHRQMASK
            pha
            lda   :t                  ; This table's?
            xba
            ror                       ; (the table bit, from bit 8, to bit 15)
            ror
            and   #$8000
            cmp   BgHi
            bne   :n
            lda   :t
            and   #$00FF
            cmp   #SOLIDTILE
            bne   :e
            jsr   SolidCheck
            lda   SolidMask
            bne   :n
            lda   #SOLIDTILE
:e          xba
            lsr
            ora   #BGWORD
            jsr   EmptySlots
            DO    TILE_STILL_DIRTY    ; A still frame draws only what changed: the tile's cells are found by a full render
            lda   #1
            sta   RefreshF
            FIN
:n          plx
            stx   ChrHead
            bra   :l
:x          rts

; The render is about to read LzSrc's tile: reconvert it if it was rewritten
ChrFresh    lda   LzSrc
            asl
            xba
            and   #$00FF
            bcc   *+5
            ora   #$0100
            tax
            ldal  ChrRamDirty,x
            bit   #CHRRAM_BG_DIRTY
            beq   :x
            sep   #$20                ; (8 bits: the next tile's flags are the NES task's)
            and   #CHRRAM_BG_DIRTY!$FF
            stal  ChrRamDirty,x
            rep   #$20
            lda   LzSrc
            jsl   ChrConvertL
            lda   LzSrc               ; Its template was made from the old tile (TplOk index: as CHR_INDEX, * 2)
            asl
            xba
            and   #$00FF
            bcc   *+5
            ora   #$0100
            asl
            tax
            stz   TplOk,x
:x          rts

; The NES task (CHR_WRITE_HOOK, ppu_regs.s): X = the tile, 8-bit A, 16-bit X.  A and X are kept; DBR is the ROM's
            mx    %10
ChrNote     pha
            rep   #$20
            mx    %00
            phx
            ldal  ChrTail
            tax
            lda   1,s
            stal  ChrQ,x
            txa
            inc
            inc
            and   #CHRQMASK
            stal  ChrTail
            plx
            sep   #$20
            mx    %10
            pla
            rts
            mx    %00
CHRQMASK    equ   $03FF
ChrHead     dw    0
ChrTail     dw    0
ChrQ        ds    CHRQMASK+1
            FIN

; LzMask = background groups whose color slots moved: they lose their tiles, and the ones CIRAM uses are queued again.  (The
; caller asks for the full render.)
InvalidateMask
:m          ldx   #0
:b          txa
            lsr
            tay
            lda   PalBitW,y
            and   LzMask
            beq   :n
            lda   BgPtr+2,x
            sta   LzPtr+2
            stz   LzPtr
            TSINC tsBankInval
            jsr   InvalidateBank
            jsr   DynInstall
:n          inx
            inx
            inx
            inx
            cpx   #16
            bcc   :b
            jmp   Sweep

; LzMask = background groups whose color slots moved (a palette remap).  The code's shape doesn't depend on the palette, so
; each compiled slot of their banks takes the new colors in place, from its template (TplPatch), and so does its colored
; bitmap (TileColors: the clip entries and TileFallback read it).  Nothing is emptied: a slot that isn't compiled is made
; when it is next drawn.  The dynamic tiles' slots (lda DynD) and the solid tile's (SkipW, color 0 in every palette) stay
; as they are.  (The caller asks for the full render.)
RecolorMask
:g          equ   tmp+0
            stz   :g
:b          ldx   :g
            lda   PalBitW,x
            and   LzMask
            beq   :n
            txa                       ; The group's palette * $4000
            xba
            asl
            asl
            asl
            asl
            asl
            sta   LzBase
            jsr   BankPtr
            ldy   #BGWORD
:s          lda   [LzPtr],y
            and   #$00FF
            cmp   #$00A9              ; Compiled: the code starts with lda #
            bne   :ns
            cpy   SkipW
            beq   :ns
            sty   LzTile
            tya
            and   #$7F80
            ora   BgHi
            sta   LzSrc
            asl                       ; Its template (TplOk index, as CHR_INDEX * 2)
            xba
            and   #$00FF
            bcc   *+5
            ora   #$0100
            asl
            tax
            lda   TplOk,x
            beq   :stale
            TSINC tsRecolor
            jsr   TileColors
            jsr   TplPatch
            bra   :nx
:stale      phb                       ; (no template: empty it, so it is made when drawn)
            sep   #$20
            lda   LzPtr+2
            pha
            plb
            rep   #$20
            ldy   LzTile
            jsr   EmptyOne
            plb
:nx         ldy   LzTile
:ns         tya
            clc
            adc   #128
            tay
            bne   :s
:n          inc   :g
            inc   :g
            lda   :g
            cmp   #8
            bcc   :b
            rts

; LzPtr = a bank: the solid tile's entry, every slot's advance and the blank stubs.  Once: nothing else stores to these bytes
SlotFixed
            ldy   #SOLIDTEST          ; A cell that holds the solid tile has this word, so a direct call enters here: on to the body
            lda   #$004C
            sta   [LzPtr],y
            iny
            lda   #SOLIDWORD
            sta   [LzPtr],y
            ldy   #BGWORD-128+SLOT_ADV ; Every slot's advance: tya / adc Step / tay
:adv        lda   #$6598
            sta   [LzPtr],y
            iny
            iny
            lda   #Step+$A800
            sta   [LzPtr],y
            tya
            clc
            adc   #126
            tay
            bcc   :adv
            ldy   #BLANK              ; The blank stubs (Lists.s): tya / adc Step / tay / nop, or rtl to skip (StubsFor) / jmp to the solid body
            ldx   #BLANK_N
:bl         lda   #$6598
            sta   [LzPtr],y
            iny
            iny
            lda   #Step+$A800
            sta   [LzPtr],y
            iny
            iny
            lda   #$4CEA
            sta   [LzPtr],y
            iny
            iny
            lda   #SOLIDWORD
            sta   [LzPtr],y
            iny
            iny
            dex
            bne   :bl
            rts

; LzPtr = a bank: its stubs.  (Before InvalidateBank: a stub's last store runs one byte past it.)
MakeStubs
:k          equ   tmp+2
            phk
            phk
            pla
            and   #$00FF
            sta   tmp+4
            stz   :k
:s          lda   :k
            asl
            tax
            lda   StubT,x
            sta   tmp+6
            lda   :k                  ; Stub k
            asl
            asl
            asl
            clc
            adc   #STUBQ
            tay
            lda   tmp+0               ; lda #palette * $4000: tmp+0 is palette * 4
            xba
            asl
            asl
            asl
            asl
            sta   tmp+8
            lda   LzPtr+2             ; (the low byte: this bank, for the thread's clip path)
            and   #$00FF
            xba
            ora   #$00A9
            sta   [LzPtr],y
            iny
            iny
            lda   tmp+8
            xba
            and   #$00FF
            ora   #$5C00              ; jmp >
            sta   [LzPtr],y
            iny
            iny
            lda   tmp+6
            sta   [LzPtr],y
            iny
            iny
            lda   tmp+4
            sta   [LzPtr],y
            inc   :k
            lda   :k
            cmp   #STUBS_N
            bcc   :s
            rts

; LzPtr = a bank: every tile slot empty ($8000 up: cells call nothing below), but for SkipW's.  X is kept
InvalidateBank
            phb
            sep   #$20
            lda   LzPtr+2
            pha
            plb
            rep   #$20
            ldy   #BGWORD
:t          cpy   SkipW
            beq   :n
            jsr   EmptyOne
:n          tya
            clc
            adc   #128
            tay
            bne   :t
            plb
            rts

; Y = a slot, DBR = its bank: empty.  X and Y are kept
EmptyOne    lda   #JSR_STUBQ
            sta:  0,y
            sta:  ROLE0,y
            sta:  ROLE0+6,y
            sta:  ROLE0+12,y
            sta:  ROLE0+18,y
            lda   #$2000              ; (StubQ's high byte, the next jsr)
            sta:  ROLE0+2,y
            sta:  ROLE0+8,y
            sta:  ROLE0+14,y
            sta:  ROLE0+20,y
            lda   #STUBQ              ; (StubQ's low byte, its high byte)
            sta:  ROLE0+4,y
            sta:  ROLE0+10,y
            sta:  ROLE0+16,y
            sta:  ROLE0+22,y
            lda   #0
            sta:  2,y
            rts

; The tiles CIRAM uses under the groups in LzMask: colored bitmaps and code made, so the next frame draws compiled tiles
Sweep
:cell       equ   tmp+0
            ldy   #0
:c          lda   [FlagPtr],y
            and   #6
            tax
            lda   PalBitW,x
            and   LzMask
            beq   :n
            sty   :cell
            txa
            xba
            asl
            asl
            asl
            asl
            asl
            sta   LzBase
            lda   [CellW],y
            and   #$FF80
            sta   LzTile
            jsr   BankPtr
            ldy   LzTile
            lda   [LzPtr],y
            cmp   #JSR_STUBQ
            bne   :k
            jsr   MakeTile
            jsr   TileInstance
:k          ldy   :cell
:n          tya
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
:x          rts

; ---- The dynamic tiles.  One has an id, 0 to DYN_TILES - 1, and reads its 32 screen bytes from the direct page at id * 32, so a
; page holds them all, DYN_PAGES of them are allocated in bank 0, and DynD picks one once per frame: everything on a page changes
; for one store.  Its slot holds its own code:
;
;   +0    lda DynD / tcd / (lda id * 32 + n / sta: offset,y) * 16 / lda #the engine's page / tcd / rtl: 88 bytes
;   +100  8 clip entries: jsr to the bank's dynamic stubs, which read the same bytes (DynE<e>, in ClipCode.s)
;
; The slot stands for the tile in every background bank, whatever the cell's palette: a page's bytes are colors already, in
; DYN_PAL.  It is never empty, so it is never queued, and it isn't solid, so the thread always draws it.

; LzPtr = a bank: the dynamic tiles' slots.  X is kept.  D = the engine's page
DynInstall
:id         equ   tmp+10
:slot       equ   tmp+12
:n          equ   tmp+14
            phx
            stz   :id
:t          lda   :id
            asl
            tax
            lda   DynTiles,x
            bmi   :nx
            xba
            lsr
            ora   #BGWORD
            sta   :slot
            tay
            lda   DynBodyT,x
            tax
            lda   #DYN_BODY/2
            sta   :n
:b          lda:  $0000,x
            sta   [LzPtr],y
            inx
            inx
            iny
            iny
            dec   :n
            bne   :b
            lda   :slot               ; The engine's page, in its lda #
            clc
            adc   #DYN_PAGEOP
            tay
            tdc
            sta   [LzPtr],y
            lda   :slot
            clc
            adc   #ROLE0
            tay
            lda   #STUBD
            sta   :n
            ldx   #8
:e          lda   #$0020              ; jsr
            sta   [LzPtr],y
            iny
            lda   :n
            sta   [LzPtr],y
            iny
            iny
            clc
            adc   #STUB_GAP
            sta   :n
            dex
            bne   :e
:nx         inc   :id
            lda   :id
            cmp   #DYN_TILES
            bcc   :t
            plx
            rts

; The pages, from the art (DynBits: its 2-bit tiles, page by page), through this palette's swizzle tables, if these aren't the
; tables they were made with.  (A palette needn't move any slots to be the first one here, so the pointer decides this, not
; InvalidateMask.)  Each frame, before anything is drawn
DynFill
:p          equ   tmp+10
            lda   SwzPtr
            cmp   DynSwz
            bne   :go
            lda   SwzPtr+2
            cmp   DynSwz+2
            bne   :go
            rts
:go         lda   SwzPtr
            sta   DynSwz
            lda   SwzPtr+2
            sta   DynSwz+2
            ldx   #0
:w          cpx   #DYN_PAGES*DYN_ART*32
            bcs   :x
            lda   DynBits,x
            ora   #DYN_PAL*$200
            tay
            txa
            and   #$0180              ; Page * 128 to page * 256
            asl
            sta   :p
            txa
            and   #$007F
            ora   :p
            clc
            adc   DynBase
            phx
            tax
            lda   [SwzPtr],y
            stal  $000000,x
            plx
            inx
            inx
            bra   :w
:x          rts

; ---- The forms of a tile

; LzBase = palette * $4000: LzPtr = its bank
BankPtr     lda   LzBase
            xba
            lsr
            lsr
            lsr
            lsr
            tax
            lda   BgPtr+2,x
            sta   LzPtr+2
            stz   LzPtr
            rts

; LzBase = palette * $4000, LzTile = tile * 128, LzSrc = the tile in tiledata: the colored bitmap, through this palette's
; swizzle table.  Sets LzIdx
TileColors  lda   LzBase
            lsr
            lsr
            lsr
            lsr
            lsr
            sta   LzIdx
            lda   LzTile
            lsr
            lsr
            ora   LzBase
            sta   LzDst
            ldx   #0
:w          txa
            ora   LzSrc
            tay
            lda   [BitsPtr],y
            ora   LzIdx
            tay
            lda   [SwzPtr],y
            sta   LzV
            txa
            ora   LzDst
            tay
            lda   LzV
            sta   [ColorPtr],y
            inx
            inx
            cpx   #32
            bcc   :w
            rts

; LzBase = palette * $4000, LzTile = tile * 128, DBR = K: the colored bitmap, the clip entries' jsrs to its stubs, and +0
; jsr StubF, which draws from it (until TileInstance writes the code).  Sets LzSrc and LzIdx for TileInstance
MakeTile    lda   LzTile              ; The tile in the table the slots hold
            and   #$7F80
            ora   BgHi
            sta   LzSrc
            DO    HAS_CHR_RAM
            jsr   ChrFresh
            FIN
            jsr   TileColors
            jsr   BankPtr
            lda   LzTile
            clc
            adc   #ROLE0+1
            tay
            lda   #STUBE
            ldx   #8
:e          sta   [LzPtr],y
            iny
            iny
            iny
            clc
            adc   #STUB_GAP
            dex
            bne   :e
            ldy   LzTile
            iny
            lda   #STUBF
            sta   [LzPtr],y
            rts

; After MakeTile (LzTile, LzSrc, LzIdx, LzPtr = the bank, DBR = K): the slot's code, from the tile's template: a block copy,
; then each operand, a swizzle index, becomes this palette's color.  Nothing runs the slot meanwhile (Sweep and TileMiss are on
; the render's task).  Uses no tmp: TileMiss calls it from the middle of SprDraw and the thread
TileInstance
            TSINC tsTileComp
            lda   LzSrc               ; Its TplOk index: LzSrc / 128 (as CHR_INDEX), * 2
            asl
            xba
            and   #$00FF
            bcc   *+5
            ora   #$0100
            asl
            tax
            lda   TplOk,x
            bne   :have
            jsr   BuildTemplate
:have       lda   LzSrc               ; The code: mvn, its banks patched in (the slot's and the templates')
            ora   #TPL_LEN
            tay
            lda   [TplPtr],y          ; The length (the operand count is the high byte)
            and   #$00FF
            dec
            pha
            sep   #$20
            lda   LzPtr+2
            sta   :mv+1               ; (the object code is 54 / destination bank / source bank)
            lda   TplPtr+2
            sta   :mv+2
            rep   #$20
            pla
            ldx   LzSrc
            ldy   LzTile
            phb
:mv         hex   540000              ; mvn: A + 1 bytes from X to Y; DBR = the destination's bank after it
            plb
            jmp   TplPatch            ; The operands

; LzSrc, LzTile, LzIdx, LzPtr = the bank: the slot's operands, each a swizzle index in the template, take this palette's colors
TplPatch    lda   LzSrc
            ora   #TPL_N
            tay
            lda   [TplPtr],y
            and   #$00FF
            sta   LzN
            lda   LzSrc
            ora   #TPL_OPS
            sta   LzI
:o          ldy   LzI
            lda   [TplPtr],y
            and   #$00FF
            sta   LzV                 ; An operand's offset
            ora   LzSrc
            tay
            lda   [TplPtr],y          ; Its swizzle index
            ora   LzIdx
            tay
            lda   [SwzPtr],y          ; Its color
            pha
            lda   LzV
            ora   LzTile
            tay
            pla
            sta   [LzPtr],y
            inc   LzI
            dec   LzN
            bne   :o
            rts

; LzSrc = the tile in tiledata, X = its TplOk index, DBR = K: its template, from the 2-bit tile (the 16 words' swizzle
; indices): each distinct index loaded once, and stored to every place it goes, in the order of its first place (as
; CompileOne).  One pass finds the groups: TplGrp maps an index to its group (0: none, and put back after), and each place
; links to the next one of its group.  X is kept
BuildTemplate
            TSINC tsTplBuild
            phx
            stz   TplK                ; The groups so far, * 2
            ldx   #0
:r          txa
            ora   LzSrc
            tay
            lda   [BitsPtr],y
            sta   CWords,x
            and   #$01FE              ; (an index is even and under $200)
            tay
            lda   #$FFFF              ; The last place of its group, so far
            sta   TplNext,x
            lda   TplGrp,y
            bne   :old
            lda   TplK                ; A new group
            inc
            inc
            sta   TplK
            sta   TplGrp,y
            tay
            txa
            sta   TplFirst-2,y
            sta   TplLast-2,y
            lda   CWords,x
            sta   TplVal-2,y
            bra   :n
:old        tay                       ; Its group's last place links to this one
            txa
            pha
            lda   TplLast-2,y
            tax
            pla
            sta   TplNext,x
            tax
            sta   TplLast-2,y
:n          inx
            inx
            cpx   #32
            bcc   :r
            ldy   LzSrc               ; The code
            lda   #2
            sta   TplG
:g          ldx   TplG
            lda   #$00A9              ; lda #
            sta   [TplPtr],y
            iny
            tya                       ; The operand's offset, for TileInstance
            sec
            sbc   LzSrc
            pha
            txa
            lsr
            dec
            tax
            pla
            sep   #$20
            sta   TplOps,x
            rep   #$20
            ldx   TplG
            lda   TplVal-2,x
            sta   [TplPtr],y
            iny
            iny
            lda   TplFirst-2,x
            tax
:p          lda   #$0099              ; sta abs,y, to each of its places
            sta   [TplPtr],y
            iny
            lda   COff,x
            sta   [TplPtr],y
            iny
            iny
            lda   TplNext,x
            tax
            bpl   :p
            lda   TplG
            inc
            inc
            sta   TplG
            cmp   TplK
            bcc   :g
            beq   :g
            sep   #$20                ; A byte: a body of 97 ends right before the length
            lda   #$6B                ; rtl
            sta   [TplPtr],y
            rep   #$20
            iny
            lda   TplK
            lsr
            sta   TplN
            tya                       ; The length, then the number of operands
            sec
            sbc   LzSrc
            sta   LzV
            lda   LzSrc
            ora   #TPL_LEN
            tay
            sep   #$20
            lda   LzV
            sta   [TplPtr],y
            iny
            lda   TplN
            sta   [TplPtr],y
            rep   #$20
            ldx   #0                  ; Their offsets
:c          cpx   TplN
            bcs   :d
            txa
            clc
            adc   #TPL_OPS
            ora   LzSrc               ; (LzSrc's low 7 bits are 0, and TPL_OPS + 16 is under 128)
            tay
            sep   #$20
            lda   TplOps,x
            sta   [TplPtr],y
            rep   #$20
            inx
            bra   :c
:d          ldx   #30                 ; TplGrp back to empty
:z          lda   CWords,x
            and   #$01FE
            tay
            lda   #0
            sta   TplGrp,y
            dex
            dex
            bpl   :z
            plx
            lda   #1
            sta   TplOk,x
            rts

; A = tile * 128 + palette, DBR = K.  The compiled tile, from its colored bitmap: each distinct word loaded once, and
; stored to every place it goes.  Leaves LzPtr = the bank, and the slot's +0 replaced first to last with no one running it.
; For the solid tile only (TilesInit, SolidCheck): compiled from ZeroSw, every word is color 0, so one load serves them all
CompileOne
            pha
            and   #$FF80
            sta   LzTile
            pla
            and   #3
            xba
            asl
            asl
            asl
            asl
            asl
            asl
            sta   LzBase
            jsr   BankPtr
            lda   LzTile
            lsr
            lsr
            ora   LzBase
            sta   LzDst
            ldx   #0
:r          txa
            ora   LzDst
            tay
            lda   [ColorPtr],y
            sta   CWords,x
            stz   CDone,x
            inx
            inx
            cpx   #32
            bcc   :r
            ldy   LzTile
            ldx   #0
:i          lda   CDone,x
            bne   :ni
            lda   CWords,x
            sta   LzV
            lda   #$00A9              ; lda #
            sta   [LzPtr],y
            iny
            lda   LzV
            sta   [LzPtr],y
            iny
            iny
            stx   LzI
:j          lda   CDone,x
            bne   :jn
            lda   CWords,x
            cmp   LzV
            bne   :jn
            inc   CDone,x
            lda   #$0099              ; sta abs,y
            sta   [LzPtr],y
            iny
            lda   COff,x
            sta   [LzPtr],y
            iny
            iny
:jn         inx
            inx
            cpx   #32
            bcc   :j
            ldx   LzI
:ni         inx
            inx
            cpx   #32
            bcc   :i
            sep   #$20                ; A byte: a body of 97 ends right before the spare bytes
            lda   #$6B                ; rtl
            sta   [LzPtr],y
            rep   #$20
            rts

; ---- A tile reached through its slot, from a jsl with Y = the screen address and DBR = $01.  A = palette * $4000, and the
; slot's jsr return address on the stack.  Keep Y; on return C is clear, as a tile's

; An empty slot: its other forms, then what the caller wanted, by the return address: the body or a clip entry
TileMiss    tax                       ; (its low byte: the bank)
            and   #$C000
            sta   LzBase
            sty   LzScreen
            pla
            sta   LzRet
            lda   ThS
            beq   :go
            stx   ThFix+2             ; In the thread: ThFix, as the clip entries (ClipCode.s)
            lda   LzRet
            and   #$007F
            cmp   #2
            beq   :b7
            lda   LzRet               ; A clip entry: it has no advance in front of it
            sta   ThFix
            tya
            clc
            adc   Step
            tay
            sty   LzScreen
            bra   :sw
:b7         lda   LzRet
            sec
            sbc   #7
            sta   ThFix
:sw         tsc                       ; Off the list: nothing may push on its entries.  Interrupts can come in meanwhile
            stal  ThList
            lda   ThS
            tcs
            jsr   MissWin             ; (cli, unless the thread was entered with interrupts off)
:go         lda   LzRet
            and   #$FF80
            sta   LzTile
            phb
            phk
            plb
            jsr   MakeTile
            jsr   TileInstance
            plb
            lda   ThS
            beq   :ret
            sei
            ldal  ThList
            tcs
:ret        lda   LzRet               ; (in the thread this lands on the entry again: ClipDone puts it back)
            pha
            and   #$007F
            cmp   #2                  ; The jsr at +0: its return address is +2
            beq   :body
            sec
            sbc   #ROLE0+2            ; 0, 3, ... 21
            asl
            tax
            lda   LzBase
            ldy   LzScreen
            jmp   (ClipJ,x)
:body       lda   LzBase
            ldy   LzScreen
            jmp   TileFallX

ClipJ       dw    ClipX1,0,0,ClipX2,0,0,ClipX3,0,0,ClipX4,0,0,ClipX5,0,0,ClipX6,0,0,ClipX7,0,0,ClipX8   ; (past their ThFix: TileMiss set it)
ThList      dw    0                   ; S in the list, while TileMiss is off it

StubT       dw    TileMiss,TileFallback,ClipE1,ClipE2,ClipE3,ClipE4,ClipE5,ClipE6,ClipE7,ClipE8
            dw    DynE1,DynE2,DynE3,DynE4,DynE5,DynE6,DynE7,DynE8

; ---- The palette of cells

; X = a CIRAM byte of a tile: A = its attribute palette * 2
PalOf
:a          equ   tmp+30
            txa
            and   #$0400
            sta   :a
            txa
            and   #31
            lsr
            lsr
            ora   :a
            ora   #$03C0
            sta   :a
            txa
            and   #$0380
            lsr
            lsr
            lsr
            lsr
            ora   :a
            phx
            tax
            ldal  PPU_CIRAM,x
            plx
            and   #$00FF
            sta   :a
            txa
            and   #$0040
            beq   :h
            lda   :a
            lsr
            lsr
            lsr
            lsr
            sta   :a
:h          txa
            and   #2
            beq   :v
            lda   :a
            lsr
            lsr
            sta   :a
:v          lda   :a
            and   #3
            asl
            rts

; One cell of a quadrant, ]1 bytes from Y: its palette, and its bank byte unless it is exposing a sprite
AttrCell    mac
            lda:  ]1+1,y
            and   #$FFF9
            ora   ApPal
            sta:  ]1+1,y
            lda:  ]1+6,y
            cmp   FlipOn
            beq   *+7
            lda   ApHome
            sta:  ]1+6,y
            tya                       ; Its list entries
            clc
            adc   #]1
            jsr   ListSyncA
            <<<
            
ApPal       equ   NwA+8
ApHome      equ   NwA+10

; Y = an attribute byte's CIRAM offset, A = its new value, DBR = the cell bank.  For each quadrant that changes, its four cells
; take the palette.  Nothing is drawn or compiled here: the cell's next draw lands on a slot that is always callable
PutAttr
:new        equ   NwA+0
:old        equ   NwA+2
:corner     equ   NwA+4               ; The top-left cell
:q          equ   NwA+6
:lim        equ   NwCell              ; (done with by now)
:t          equ   NwRow
            and   #$00FF
            sta   :new
            tya
            and   #$0400
            sta   :corner
            lsr
            lsr
            lsr
            lsr
            sta   :t
            tya
            and   #$003F
            ora   :t
            tax
            ldal  AttrShadow,x
            and   #$00FF
            sta   :old
            cmp   :new
            beq   :x
            sep   #$20
            mx    %10
            lda   :new
            stal  AttrShadow,x
            rep   #$20
            mx    %00
            tya
            and   #7
            asl
            asl
            ora   :corner
            sta   :corner
            tya
            and   #$0038
            cmp   #$0038              ; The last row's lower half is rows 30 and 31, which have no cells
            bne   :four
            lda   #2
            bra   :l1
:four       lda   #4
:l1         sta   :lim
            tya
            and   #$0038
            asl
            asl
            asl
            asl
            ora   :corner
            asl
            asl
            asl
            asl
            asl
            sta   :corner
            stz   :q
:qq         lda   :old
            eor   :new
            and   #3
            beq   :nq
            lda   :new
            and   #3
            asl
            sta   ApPal
            tax
            lda   HomeFlip,x
            sta   ApHome
            lda   :q
            asl
            tax
            ldal  QuadCell,x
            clc
            adc   :corner
            tay
            jsr   AttrQuad
:nq         lsr   :old
            lsr   :old
            lsr   :new
            lsr   :new
            inc   :q
            lda   :q
            cmp   :lim
            bcc   :qq
:x          rts

AttrQuad    AttrCell 0
            AttrCell 32
            AttrCell 1024
            AttrCell 1056
            rts
QuadCell    dw    0,64,2048,2112

; ---- Data
LzSrc       dw    0                   ; MakeTile: the tile in the tiledata bank
DynSwz      dw    $FFFF,$FFFF
PalBitW     dw    1,2,4,8
COff        dw    0,2,160,162,320,322,480,482,640,642,800,802,960,962,1120,1122
CWords      ds    32
CDone       ds    32
TPL_OK_N    equ   512                 ; Per tile of both tables: non-zero while its template matches the tile
TplOk       ds    TPL_OK_N*2
TplOps      ds    16                  ; BuildTemplate: the operands' offsets
TplK        dw    0                   ;   the groups * 2, and the operands
TplN        dw    0
TplG        dw    0                   ;   the group being written, * 2
TplGrp      ds    512                 ;   per swizzle index: its group * 2, or 0
TplFirst    ds    32                  ;   per group: its first and last places, and its index
TplLast     ds    32
TplVal      ds    32
TplNext     ds    32                  ;   per place: the next place of its group, or $FFFF

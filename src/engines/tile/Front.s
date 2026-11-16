; Front.s -- the tile engine's front: what the runtime and the game call (silky-gs's ppu_frame.s, ppu_entry.s, ppu_api.s), and
; the NES task's PPU writes.  ppu_regs.s and ppu_palette.s are silky's own.
;
; Two tasks share the CPU (rom_exec.s).  The render (the GS task) can lose the CPU at any instruction, for a whole NES frame,
; except with interrupts off.  The NES task is never preempted in this segment, so a PPU write here runs whole.
;
; The NES task only records what changed (CellWrite): each CIRAM byte written since the last render goes on a list, once, however
; often the ROM writes it.  The list is swapped at the latch, and the render puts its bytes' current values on the cells before it
; draws (ApplyNt).  So only the render writes cells, and the NES task's time for a PPU write doesn't depend on what the write does
; to the cells.  The same list says which cells to draw on a frame that doesn't scroll, and which solid cells to promote after it.
;
;   A cell's flag bit for a neighbor may be cleared at once, but is set only after a complete pass has drawn the change.
;   Until then that cell draws, instead of skipping over pixels that may be stale, which could then last across a run of
;   solid cells.
;
; D = the engine's page in everything below, except where it says D = the runtime's.  DBR = this bank, except while tiles run.

EngD        ENT                       ; The page
            dw    0
UserId      dw    0                   ; The program's (off the direct page: only the allocations read it)
ViewPx      dw    0                   ; The scroll asked for: in bytes, and lines
ViewPy      dw    0
ScrollNt    dw    0                   ; NES_SetScroll's: the form of the PPU registers
ScrollX     dw    0
ScrollY     dw    0
ReqTop      dw    0                   ; What this render asks for (RenderDraw, PPU_SetupLines, PPU_DrawScreenRange): the view's first
ReqLines    dw    200                 ; line and its lines, and the rows of the fixed band above it
ReqBand     dw    0
ViewTop     dw    $FFFF               ; What is set up (ApplyView)
ViewLines   dw    0
ViewRows    dw    0
ViewportA   dw    0                   ; The view's top-left on the screen
StatusRows  dw    0                   ; Rows of the fixed band at the top of the screen (PPU_SetupLines)
BandPage    dw    0                   ; CIRAM's page ($0000 / $0400) the lines above the view come from
BgHi        dw    0                   ; The background pattern table, as an offset in the tiledata bank: what the slots hold
BgNew       dw    0                   ; The one PPUCTRL selects (RenderLatch)

; The map over the cells: 64 columns by 30 rows with vertical mirroring, 32 by 60 with horizontal
MirrorH     dw    0                   ; 0 vertical, 8 horizontal (an index in NbrTab's second half)
NbrColX     dw    $8000               ; A cell's page bit, to flip when a neighbor wraps across columns (vertical) or rows
NbrRowX     dw    0                   ; (horizontal): NbrFlags
ColMask     ENT
            dw    63
ColsN       dw    64
RowsN       dw    30
RowLast     dw    29
RowLines    dw    240
RowHalf     dw    120
RefreshF    dw    1                   ; Not 0: the next frame is a full render
StatusF     dw    1                   ; Not 0: the next frame draws the fixed band
BgOn        dw    0
BgWasOn     dw    0
BlankF      dw    0                   ; Not 0: this frame blanked the screen (the background off)
SwzL        dw    0                   ; The runtime's swizzle pointer, at the last render
SwzH        dw    0
NtTail      EXT                       ; The list being written, and where it ends: in the base ROM bank (ppu/ppu_reg_vars.s)
NtSel       dw    0
NtFStart    dw    0                   ; The list the render reads
NtFEnd      dw    0
NtFillF     dw    0                   ; Nametables filled whole (bit 0: CIRAM $000, bit 1: $400), since the latch
NtFillR     dw    0                   ; The same, for the list the render reads
NtBig       dw    0                   ; Not 0: so many cells changed that this render is a full one
NT_BIG      equ   480                 ; How many changed cells that takes (an attribute byte counts for its 16)

_ppuctrl    ENT
            dw    0
_ppuscroll_x ENT
            ds    2
_ppuscroll_y ENT
            ds    2
_ppumask    ENT
            dw    0
sprClipTop  ENT
            dw    0
chr_bank    ENT
            dw    0

; ---- Start-up

; D = the runtime's page; the engine's is the next one (the OAM's page, which a DIRECT_OAM_READ game doesn't use)
PPUStartUpL ENT
            phb
            phk
            plb
            lda   S_UserId
            pha
            tdc
            clc
            adc   #$100
            sta   EngD
            phd
            tcd
            lda   3,s                 ; (the page, then the user id)
            stal  UserId
            stz   ThS
            jsr   AllocCells
            jsr   AllocExpose
            jsr   AllocTiles
            jsr   AllocDyn
            lda   PendingMirrorMode   ; (NES_StartUp's: the cartridge's mirroring)
            jsr   SetMirror
            jsr   BuildCells
            jsr   SetFlags
            jsr   AllocLists
            jsr   BuildLists
            jsr   TilesInit
            jsl   SprInit
            lda   MirrorH
            jsl   SprMirrorL
            jsl   SprCacheInitL
            lda   #$FFFF
            sta   LastPx
            pld
            pla
            lda   #0
            sta   PendingMirrorMode
            lda   #$FFFF              ; Palette RAM to out-of-range values: the first real write is never skipped
            ldx   #0
:p          stal  PPU_MEM+$3F00,x
            inx
            inx
            cpx   #$20
            bcc   :p
            DO    HAS_CHR_RAM         ; A CHR-RAM game has no image yet: both forms of every tile are dirty until it is written
            ldx   #0
            lda   #{CHRRAM_BG_DIRTY+CHRRAM_SPR_DIRTY}*$101
:cd         sta   ChrRamDirty,x
            inx
            inx
            cpx   #512
            bcc   :cd
            FIN
            plb
            clc
            rtl

; A = the mirroring (ApplyMirrorMode, before a render).  D = the runtime's page.  Only the seams of the map differ, so only they
; are patched: edges and links back to plain under the old map, the new map's values, and the slots and flags on its seams.  The
; next render is a full one.  (A game may ask for the mode it is already in, on every mapper write.)
PPUSetMirrorModeL ENT
            phb
            phk
            plb
            jsr   MirrorOf
            cmp   MirrorH
            beq   :x
            phd
            pha
            lda   EngD
            tcd
            jsr   UnpatchView
            pla
            pha
            jsr   SetMirrorI
            pla
            jsl   SprMirrorL
            jsr   SeamFix
            jsr   BuildLists          ; (the lists are laid out by the map's shape)
            lda   #$FFFF
            sta   LastPx
            sta   FineScroll
            lda   #1
            sta   RefreshF
            sta   StatusF
            pld
:x          plb
            rtl

; A = the mirroring: A = the value for MirrorH (as silky's PPUSetMirrorMode, anything but vertical is horizontal)
MirrorOf    bit   #VERTICAL_MIRRORING
            beq   :h
            bit   #HORIZONTAL_MIRRORING
            bne   :h
            lda   #0
            rts
:h          lda   #8
            rts

; A = the mirroring: the map's values
SetMirror   jsr   MirrorOf
SetMirrorI  sta   MirrorH
            bne   :h
            lda   #VERTICAL_MIRROR_MASK
            stal  MirrorMaskLong
            lda   #$03E0
            stal  CIRAMRowMask
            lda   #$041F
            stal  CIRAMColMask
            lda   #63
            sta   ColMask
            lda   #64
            sta   ColsN
            lda   #30
            sta   RowsN
            lda   #29
            sta   RowLast
            lda   #240
            sta   RowLines
            lda   #120
            sta   RowHalf
            lda   #$8000
            sta   NbrColX
            stz   NbrRowX
            rts
:h          lda   #HORIZONTAL_MIRROR_MASK
            stal  MirrorMaskLong
            lda   #$07E0
            stal  CIRAMRowMask
            lda   #$001F
            stal  CIRAMColMask
            lda   #31
            sta   ColMask
            lda   #32
            sta   ColsN
            lda   #60
            sta   RowsN
            lda   #59
            sta   RowLast
            lda   #480
            sta   RowLines
            lda   #240
            sta   RowHalf
            stz   NbrColX
            lda   #$8000
            sta   NbrRowX
            rts
MirrorMaskLong ENT
            dw    0
CIRAMRowMask ENT
            dw    0
CIRAMColMask ENT
            dw    0
PendingMirrorMode ENT
            dw    0

; A whole 64KB bank, at offset 0.  Returns A = the bank
AllocBank
:handle     equ   tmp+0
            pea   0
            pea   0
            pea   1                   ; $10000 bytes
            pea   0
            ldal  UserId
            pha
            pea   %11000000_00011100  ; Locked, fixed, no special memory, page aligned, no bank crossing
            pea   0
            pea   0
            _NewHandle
            bcc   :ok
            brk   $01
:ok         pla
            sta   :handle
            pla
            sta   :handle+2
            lda   [:handle]
            beq   :low
            brk   $02
:low        ldy   #2
            lda   [:handle],y
            rts

; The dynamic tiles' pages: DYN_PAGES of 256 bytes, page aligned, in bank 0, to be the direct page
AllocDyn
:handle     equ   tmp+0
            pea   0
            pea   0
            pea   0
            pea   DYN_PAGES*256
            ldal  UserId
            pha
            pea   %11000000_00010101  ; Locked, fixed, page aligned, no bank crossing, in the bank given
            pea   0
            pea   0
            _NewHandle
            bcc   :ok
            brk   $03
:ok         pla
            sta   :handle
            pla
            sta   :handle+2
            lda   [:handle]
            sta   DynBase
            rts
DynBase     ENT
            dw    0

; ---- The runtime's other entries

SetScreenRectL ENT
            sty   S_ScreenHeight
            rtl
_ShadowOnL  ENT
            sep   #$20
            ldal  SHADOW_REG
            and   #$F1
            stal  SHADOW_REG
            rep   #$20
            rtl
ForceMetatileRefreshL ENT
            lda   #1
            stal  RefreshF
            stal  StatusF
            rtl
ROM_CompileBackgroundTilesL ENT       ; (tiles compile as they are needed)
PPU_ReloadCHR ENT
EngineAllocL ENT                      ; (its banks are its own: PPUStartUpL)
EngineStartUpL ENT
EngineRenderModeL ENT
JoyInstallProbesL ENT                 ; (M14: the joystick)
JoyScanService ENT
JoyScanDisarmL ENT
JoyConfigureL ENT
JoyGetPadL  ENT
JoyClassifyL ENT
JoyMeasureL ENT
            rtl
InitYExcludeL ENT
            phb
            phk
            plb
            jsr   InitYExclude
            plb
            rtl
joyScanArmed ENT
            dw    0
ChrRamDirty ENT
            ds    512                 ; Per tile, both pattern tables: CHRRAM_BG_DIRTY, CHRRAM_SPR_DIRTY (a CHR-RAM game: all, PPUStartUpL)
Mul160Tbl   ENT
]n          =     0
            lup   200
            dw    ]n*160
]n          =     ]n+1
            --^

; The palette RAM writes that go straight to a slot: as silky's PPU_SetPaletteWritesL (ppu_entry.s)
PPU_SetPaletteWritesL ENT
            phb
            phk
            plb
            php
            sei
            sta   :src+1
            sep   #$20
            txa
            sta   :src+3
            rep   #$20
            ldx   #62
:src        ldal  $000000,x
            sta   ppuPalWrites,x
            dex
            dex
            bpl   :src
            plp
            plb
            rtl

; A = the background groups whose color slots moved (UpdatePalette, after NES_SetPaletteMap): their compiled tiles take the new
; colors (RecolorMask).
; D = the runtime's page
RefreshPPUAttributesL ENT
            phb
            phk
            plb
            and   #$000F
            beq   :x
            pha
            lda   S_SwizzlePtr
            sta   SwzL
            lda   S_SwizzlePtr+2
            sta   SwzH
            lda   #1
            sta   RefreshF
            sta   StatusF
            pla
            phd
            pha
            lda   EngD
            tcd
            pla
            sta   LzMask
            lda   SwzL
            sta   SwzPtr
            lda   SwzH
            sta   SwzPtr+2
            jsr   RecolorMask
            pld
:x          plb
            rtl

; Add a sprite to this render's, after the game's (so it is drawn under them), e.g. a pointer: as the PEA engine's (ppu_api.s).
; Call from PRE_RENDER: RenderLatch has copied the game's sprites by then.  It is drawn even while the game has the sprites off,
; and dropped if the render has 64 sprites already.
;
; A = the OAM entry's first word: Y in the low byte (the sprite's top line is Y + 1, as on the NES), the tile
; X = its second word: the attributes in the low byte, X
; Returns Y = the sprite's OAM_COPY index (count * 4), or 256 or more when there was no room
PPU_AddSprite ENT
            phb
            phk
            plb
            ldy   spriteCount             ; (count * 4)
            cpy   #256
            bcs   :full
            inc                           ; Y + 1, as scanOAMSprites
            sta   OAM_COPY,y
            txa
            sta   OAM_COPY+2,y
            tya
            adc   #4                      ; (carry clear)
            sta   spriteCount
:full       plb
            rtl

; ---- A render

; Latch the NES state, interrupts off.  D = the runtime's page.
RenderLatch ENT
            phb
            phk
            plb
            php
            sei
            lda   NtSel               ; The list the ROM has been filling is the one this render reads
            sta   NtFStart
            ldal  NtTail
            sta   NtFEnd
            lda   NtSel
            eor   #NTLIST
            sta   NtSel
            stal  NtTail
            lsr                       ; (a list's bytes: 2 per CIRAM byte, so its marks are half as far along)
            clc
            adc   #NtSeen
            sta   NtS0+1
            sta   NtS1+1
            lda   NtFillF
            sta   NtFillR
            stz   NtFillF
            DO    CUSTOM_PPU_CTRL_LOCK
            jsl   CUSTOM_PPU_CTRL_LOCK_ADDR
            bcs   :ctrl
            FIN
            ldal  ppuctrl
:ctrl       sta   _ppuctrl
            ldal  ppuctrl             ; The background pattern table.  What the slots hold changes when the render gets to it
            and   #$0010
            beq   :bgt
            lda   #$8000
:bgt        sta   BgNew
            DO    CUSTOM_PPU_SCROLL_LOCK
            jsl   CUSTOM_PPU_SCROLL_LOCK_ADDR
            bcs   :scroll
            FIN
            ldal  ppuscroll
:scroll     sep   #$20
            sta   _ppuscroll_y
            xba
            sta   _ppuscroll_x
            rep   #$20
            ldal  ppumask
            andl  ppumask_override
            sta   _ppumask
            and   #NES_PPUMASK_BG
            beq   :off
            lda   #CTRL_BKGND_ENABLE
            tsb   S_ControlBits
            bne   :spr
            bra   :chg
:off        lda   #CTRL_BKGND_ENABLE
            trb   S_ControlBits
            beq   :spr
:chg        lda   #DIRTY_BIT_BG0_REFRESH
            tsb   S_DirtyBits
:spr        lda   _ppumask
            and   #NES_PPUMASK_SPR
            beq   :sprs0
            lda   #CTRL_SPRITE_ENABLE
            tsb   S_ControlBits
            bra   :scan
:sprs0      lda   #CTRL_SPRITE_ENABLE
            trb   S_ControlBits
:scan       jsr   scanOAMSprites
            plp
            plb
            rtl

; Draw the screen.  D = the runtime's page.
RenderDraw  ENT
            phb
            phk
            plb
            phd                       ; (first: a game's render screen may draw nothing, and the list must still be applied)
            lda   EngD
            tcd
            jsr   ApplyNt
            pld
            lda   S_SwizzlePtr
            sta   SwzL
            lda   S_SwizzlePtr+2
            sta   SwzH
            lda   S_ControlBits
            and   #CTRL_BKGND_ENABLE
            sta   BgOn
            lda   S_DirtyBits
            and   #DIRTY_BIT_BG0_REFRESH
            beq   :nr
            sta   RefreshF
            sta   StatusF
:nr         stz   ReqTop              ; The whole screen at one scroll, unless the game's render screen says otherwise
            stz   ReqBand
            lda   S_ScreenHeight
            sta   ReqLines
            DO    CUSTOM_RENDER_SCREEN
            lda   BgOn                ; The background off: the whole screen is the view, blanked here, without the game's bands
            beq   :render
            jsl   CUSTOM_RENDER_SCREEN_ADDR
            bcc   :render
            sta   S_DirtyBits
            plb
            rtl
:render
            FIN
            lda   _ppuctrl
            ldx   _ppuscroll_x
            ldy   _ppuscroll_y
            jsr   SetScroll
            jsr   DrawScreen
            stz   S_DirtyBits
            plb
            rtl

; A = the nametable select (PPUCTRL bits 1:0), X = scroll x, Y = scroll y.  D = the runtime's page
NES_SetScroll ENT
            phb
            phk
            plb
            jsr   SetScroll
            plb
            rtl
SetScroll   sta   ScrollNt
            stx   ScrollX
            sty   ScrollY
            jsr   ScrollBytes
            sta   S_StartX
            rts

; The horizontal scroll in bytes, on this map.  With 32 columns a fine scroll would need one cell at both edges: whole columns only
ScrollBytes lda   ScrollX
            and   #$00FF
            sta   :x
            lda   MirrorH
            bne   :h
            lda   ScrollNt
            and   #1
            xba
            ora   :x
            lsr                       ; 512 pixels to 256 bytes
            rts
:h          lda   :x
            lsr
            and   #$007C
            rts
:x          dw    0

; A = the first line, X = the lines, Y = the horizontal offset.  A band from line 0 is the fixed band; any other is the
; scrolling view.  D = the runtime's page
PPU_SetupLines ENT
            cmp   #0
            bne   :v
            txa
            lsr
            lsr
            lsr
            stal  ReqBand
            rtl
:v          stal  ReqTop
            txa
            stal  ReqLines
            rtl

; This render's view: set up if it has changed, then the scroll.  The lines above the view are the band: rows of a page of CIRAM.
; With vertical mirroring that is page 0; with horizontal, the nametable PPUCTRL selects
ApplyView   lda   ReqTop
            cmp   ViewTop
            bne   :ch
            lda   ReqLines
            cmp   ViewLines
            bne   :ch
            lda   ReqBand
            cmp   StatusRows
            beq   :same
:ch         lda   ReqBand
            sta   StatusRows
            lda   ReqLines
            sta   ViewLines
            clc
            adc   #7
            lsr
            lsr
            lsr
            sta   ViewRows
            lda   ReqTop
            sta   ViewTop
            asl
            tax
            lda   Mul160Tbl,x
            clc
            adc   #$2000+x_offset
            sta   ViewportA
            lda   ViewTop
            ldx   ViewLines
            jsl   SprViewL
            lda   #1
            sta   RefreshF
            sta   StatusF
            sta   BgWasOn             ; (the background off blanks only the view, so a new view needs it again)
:same       lda   MirrorH
            beq   :p
            lda   _ppuctrl
            and   #2
            beq   :p
            lda   #$0400
:p          sta   BandPage
            asl
            asl
            asl
            asl
            asl
            sta   BandCell            ; (the page's offset in the cell bank)
            lda   BandCell
            jsl   SprBandL
            jsr   ScrollBytes
            sta   ViewPx
            lda   ScrollY
            and   #$00FF
            tax
            lda   MirrorH
            beq   :y
            lda   ScrollNt
            and   #2
            beq   :y
            txa
            clc
            adc   #240
            tax
:y          txa
            clc
            adc   #y_offset
            adc   ViewTop
:w          cmp   RowLines            ; A scroll wraps on the map
            bcc   :ok
            sbc   RowLines
            bra   :w
:ok         sta   ViewPy
            rts
BandCell    dw    0

; D = the runtime's page
PPU_DrawScreen ENT
            phb
            phk
            plb
            jsr   DrawScreen
            plb
            rtl

; A = the first line, X = the lines.  The other lines stay as they are
PPU_DrawScreenRange ENT
            phb
            phk
            plb
            sta   ReqTop
            stx   ReqLines
            stz   ReqBand
            jsr   DrawScreen
            plb
            rtl

DrawScreen  phd
            lda   EngD
            tcd
            ldal  nesFrameCount       ; The dynamic tiles' page, for the whole frame
            lsr
            lsr
            lsr
            and   #DYN_PAGES-1
            xba
            clc
            adc   DynBase
            sta   DynD
            lda   SwzL
            sta   SwzPtr
            lda   SwzH
            sta   SwzPtr+2
            DO    HAS_CHR_RAM
            jsr   ChrDrain            ; Tiles the NES task rewrote
            FIN
            jsr   BgSwitch
            jsr   ApplyView
            jsr   DynFill
            lda   BgOn
            bne   :on
            lda   BgWasOn             ; The background is off: blank, once (BlankF says it was this frame)
            sta   BlankF
            beq   :off
            stz   BgWasOn
            jsr   BlankView
:off        lda   #1                  ; The sprites (if they are on: spriteCount) over the blank screen: every cell's tile is a zero
            jsl   SprBgOffL           ; fill.  SprLeave only gives the cells they left their bytes back (as a full render's), and
            stz   FlagMask            ; SprLeaveZ blanks them
            stz   StaleOn
            jsr   ShadowOff
            jsl   SprDraw
            jsr   ShadowOn
            lda   BlankF
            beq   :lv
            lda   #2                  ; The screen was just blanked: the cells left are blank already, and may be on another grid
            jsl   SprBgOffL           ; (a new view), over this frame's.  They only get their bytes back
:lv         jsl   SprLeave
            lda   BlankF
            bne   :lb
            jsl   SprLeaveZ
:lb         jsl   SprLeaveB
            jsl   SprExposeZ
            lda   #0
            jsl   SprBgOffL
            jsr   Promote
            pld
            rts
:on         sta   BgWasOn
            lda   RefreshF
            beq   :u
            stz   RefreshF
            lda   #$FFFF
            sta   LastPx
:u          jsr   Update
            TSINC tsFrames
            DO    TILE_STATS
            lda   FlagMask
            bne   :ts1
            TSINC tsFull
            bra   :ts3
:ts1        cmp   #FLAG_STILL
            bne   :ts2
            TSINC tsStill
            bra   :ts3
:ts2        TSINC tsMoved
:ts3
            FIN
            jsr   DrawChanged
            jsr   ShadowOff
            jsl   SprDraw
            jsr   ShadowOn
            jsl   SprLeave
            jsl   SprLeaveB
            DO    TILE_STILL_DIRTY    ; A frame that doesn't scroll: only the sprites' cells, from their list.  The changed cells
            lda   FlagMask            ; are drawn (DrawChanged), and so are the cells the sprites left (SprLeave)
            cmp   #FLAG_STILL
            bne   :thr
            jsl   SprExposeN
            bra   :thd
            FIN
:thr        jsr   DrawThread
:thd        jsl   SprExposeB
            jsr   Promote
            pld
            rts

; The view's lines, in color 0.  Shadowing is on
BlankView   lda   ViewTop
            asl
            tax
            lda   Mul160Tbl,x
            sta   :first
            lda   ViewLines
            xba
            lsr
            lsr                       ; Lines * 64
            sta   :n
            lda   ViewLines
            asl
            asl
            asl
            asl
            asl                       ; Lines * 32
            clc
            adc   :n                  ; Lines * 96
            sta   :n
            lda   ViewLines
            asl
            asl
            asl
            asl
            asl
            asl                       ; Lines * 64
            clc
            adc   :n                  ; Lines * 160
            clc
            adc   :first
            dec
            dec
            tax
            lda   #0
:cl         stal  $012000,x
            dex
            dex
            cpx   :first
            bcc   :x
            bpl   :cl
:x          rts
:first      dw    0
:n          dw    0

ShadowOff   sep   #$20
            ldal  SHADOW_REG
            ora   #$08
            stal  SHADOW_REG
            rep   #$20
            rts
ShadowOn    sep   #$20
            ldal  SHADOW_REG
            and   #$F7
            stal  SHADOW_REG
            rep   #$20
            rts

; (DrawThread is in Lists.s)

; The end of a clipped tile (X = the screen address, and the clip entry pushed the DBR)
ClipDone    txy
            plb
            lda   ThS
            bne   :fix
            rtl
:fix        pei   ThFix+1             ; In the thread: S is at the last byte of this cell's entry.  Its last two bytes back
            pla
            clc
            rtl
            
; A cell's tile, with Y = the screen address and DBR = $01.  The caller writes the cell's word at +1, and at +3 a HomeFlip
; word: the bank, and the tya here
CallT       hex   22000000
            tya
            rts

; ---- The cells changed since the last latch.  A frame that scrolls draws only the fixed band's: the thread draws the rest.
; A still frame draws them all: its thread skips the solid ones.
DrawChanged lda   StatusF             ; The fixed band, whole
            beq   :list
            stz   StatusF
            lda   StatusRows
            beq   :list
            asl
            asl
            asl
            asl
            asl
            sta   :end
            ldx   #0
:sb         phx
            txa
            clc
            adc   #y_offset_rows*32
            adc   BandPage
            tax
            jsr   DrawCell
            plx
            inx
            cpx   :end
            bcc   :sb
:list       lda   NtBig               ; (ApplyNt: the render is a full one, and draws them all)
            beq   *+3
            rts
            ldx   NtFStart
:l          cpx   NtFEnd
            beq   :x
            phx
            lda   NtBuf,x
            and   #$07FF              ; (bit 15: ApplyNt's)
            tax
            and   #$03FF
            cmp   #$03C0
            bcs   :attr
            TSINC tsBgCells
            jsr   DrawCell
:n          plx
            inx
            inx
            bra   :l
:x          rts
:attr       TSINC tsAttrs
            jsr   DrawAttr
            bra   :n
:end        dw    0

; X = an attribute byte's CIRAM offset: the 16 cells under it
DrawAttr
:corner     equ   tmp+14
:n          equ   tmp+16
            txa
            and   #$0400
            sta   :corner
            txa
            and   #7
            asl
            asl
            ora   :corner
            sta   :corner
            txa
            and   #$0038
            asl
            asl
            asl
            asl
            ora   :corner
            sta   :corner
            stz   :n
:c          lda   :n
            and   #3
            sta   tmp+18
            lda   :n
            and   #$000C
            asl
            asl
            asl
            ora   tmp+18
            clc
            adc   :corner
            tax
            and   #$03E0
            cmp   #30*32
            bcs   :s
            jsr   DrawCell
:s          inc   :n
            lda   :n
            cmp   #16
            bcc   :c
            rts

; X = a tile's CIRAM offset: draw its cell, if it is on the screen.  Shadowing is on
DrawCell
:o          equ   tmp+20
:row        equ   tmp+22
:col        equ   tmp+24
            stx   :o
            txa
            and   #31
            sta   :col
            txa
            and   #$03E0
            lsr
            lsr
            lsr
            lsr
            lsr
            sta   :row
            txa
            and   #$0400
            cmp   BandPage
            bne   :nt1
            lda   :row                ; The fixed band?
            sec
            sbc   #y_offset_rows
            cmp   StatusRows
            bcs   :nt1
            asl                       ; Its row and column on the screen
            tax
            lda   :col
            asl
            asl
            clc
            adc   #$2000+x_offset
            adc   Mul1280,x
            bra   :call
:nt1        lda   :o                  ; Its place on the map
            and   #$0400
            beq   :view
            lda   MirrorH
            bne   :nth
            lda   :col
            ora   #32
            sta   :col
            bra   :view
:nth        lda   :row
            clc
            adc   #30
            sta   :row
:view       lda   FlagMask            ; (a scrolled frame's thread draws it)
            cmp   #FLAG_STILL
            bne   :x
            lda   :col
            sec
            sbc   OriginCol
            and   ColMask
            cmp   NC
            bcs   :x
            asl
            asl
            sta   :col
            lda   :row
            sec
            sbc   OriginRow
            bpl   :r
            clc
            adc   RowsN
:r          cmp   NR
            bcs   :x
            asl
            tax
            lda   SY
            asl
            tay
            lda   :col
            clc
            adc   Mul1280,x
            adc   ViewportA
            sec
            sbc   Mul160Tbl,y
            sec
            sbc   SX
:call       sta   :row
            lda   :o
            asl
            asl
            asl
            asl
            asl
            tay
            lda   [CellW],y
            sta   CallT+1
            lda   [FlagPtr],y
            and   #6
            tax
            lda   HomeFlip,x
            sta   CallT+3
            ldy   :row
            phb
            pea   $0101
            plb
            plb
            jsr   CallT
            plb
:x          rts
Mul1280
]n          =     0
            lup   32
            dw    ]n*1280
]n          =     ]n+1
            --^

; ---- After the frame: the solid cells in the list have been drawn by a complete pass, so their neighbors may skip
Promote
:end        equ   tmp+0
            ldx   NtFStart
            lda   NtFEnd
            sta   :end
            phb
            pei   CellBankW
            plb
            plb
:l          cpx   :end
            beq   :x
            ldal  NtBuf,x             ; The cells ApplyNt found solid have bit 15
            bpl   :n
            and   #$07FF
            asl
            asl
            asl
            asl
            asl
            tay
            phx
            lda   #$FFFF
            jsr   NbrFlags
            plx
:n          inx
            inx
            bra   :l
:x          plb
            lda   NtFEnd              ; (read once)
            sta   NtFStart
            rts

; ---- The NES task's PPU writes.  The shim (rom_inject.s STA_2007) has stored a changed byte in PPU_CIRAM.  A = the byte
; (8-bit), X = its CIRAM offset, DBR = the base ROM bank (NtTail is there), D = the NES's.  Y belongs to the ROM (untouched).  A and
; X are STA_2007's to restore.  On the list if it isn't yet: a list holds each byte once, so it can't overflow.  (The list and the
; marks in use are RenderLatch's to change)
            mx    %10
ntmWriteTail ENT                      ; The name rom/rom_inject.s calls
CellWrite
;            phb
;            phk
;            plb
;NtS0        lda   NtSeen,x            ; (the operand: this list's marks)
;            bne   NtWDone
;            inc
;NtS1        sta   NtSeen,x
;            rep   #$20
;            mx    %00
;            phy
;            ldy   NtTail
;            txa
;            sta   NtBuf,y
;            iny
;            iny
;            sty   NtTail
;            ply
;NtWDone     plb
;            rtl

NtS0        ldal  NtSeen,x            ; (the operand: this list's marks)
            bne   NtWDone
            inc
NtS1        stal  NtSeen,x
            rep   #$20
            mx    %00
            txa
            ldx   NtTail              ; (DBR = the base ROM bank, which holds NtTail)
            stal  NtBuf,x
            inx
            inx
            stx   NtTail
NtWDone     rtl

; A whole nametable was filled: X = its CIRAM page ($000 or $400), DBR = the ROM's.  The render puts all its bytes on the list
ntmFillTail ENT
            phb
            phk
            plb
            txa
            and   #$0400
            beq   :p0
            lda   #2
            bra   :set
:p0         lda   #1
:set        tsb   NtFillF
            plb
            rtl

; The bytes on the list this render reads, onto the cells: each with its value now.  (A later write to one is on the next list,
; so it is applied again then.)  D = the engine's page.  The data bank is the cell bank from here to the end of the list
ApplyNt
:end        equ   tmp+0
:w          equ   tmp+2               ; The cells changed
:pages      equ   tmp+4
:lim        equ   tmp+6
:v          equ   tmp+8
:app        equ   tmp+10
            stz   NtBig
            stz   :w
            ldx   NtFStart
            lda   NtFEnd
            sta   :end
            txa
            lsr                       ; (RenderLatch's)
            clc
            adc   #NtSeen
            sta   :seen+1
            sta   :seen2+1
            sta   :seen3+1
            lda   NtFillR             ; A nametable filled whole: its bytes that differ from their cells, and aren't on the list yet
            beq   :gone
            sta   :pages
            stz   NtFillR
            lda   :end
            sta   :app
            ldx   #0
            phb
            pei   CellBankW
            plb
            plb
:pg         lsr   :pages
            bcc   :npg
            phx
            txa
            clc
            adc   #960
            sta   :lim
:f
:seen2      ldal  NtSeen,x
            and   #$00FF
            bne   :inl
            ldal  PPU_CIRAM,x
            and   #$00FF
            xba
            lsr
            ora   #BGWORD
            sta   :v
            txa
            asl
            asl
            asl
            asl
            asl
            tay
            lda:  WORD,y
            and   #$FF80
            cmp   :v
            beq   :inl
            jsr   :add
:inl        inx
            cpx   :lim
            bcc   :f
            txa                       ; Its attribute bytes, if not on the list yet (PutAttr finds whether they changed)
            clc
            adc   #64
            sta   :lim
:fa
:seen3      ldal  NtSeen,x
            and   #$00FF
            bne   :ina
            jsr   :add
:ina        inx
            cpx   :lim
            bcc   :fa
            plx
:npg        txa
            clc
            adc   #$0400
            tax
            lda   :pages
            bne   :pg
            plb
            lda   :app
            sta   :end
            sta   NtFEnd
:gone       ldx   NtFStart
            phb
            pei   CellBankW
            plb
            plb
:l          cpx   :end
            beq   :x
            phx
            ldal  NtBuf,x
            tax                       ; X = the CIRAM byte, to the end of the entry
            sep   #$20
            mx    %10
            lda   #0
:seen       stal  NtSeen,x
            rep   #$20
            mx    %00
            ldal  PPU_CIRAM,x
            and   #$00FF
            sta   NwVal
            txa
            and   #$03FF
            cmp   #$03C0
            bcs   :attr
            txa
            asl
            asl
            asl
            asl
            asl
            tay
            jsr   PutCell
            inc   :w
            lda   NwVal
            cmp   #SOLIDTILE
            bne   :n
            lda   1,s                 ; Solid: bit 15 on its entry, for Promote
            tax
            ldal  NtBuf,x
            ora   #$8000
            stal  NtBuf,x
:n          plx
            inx
            inx
            bra   :l
:attr       txy
            lda   NwVal
            jsr   PutAttr
            lda   :w
            clc
            adc   #16
            sta   :w
            bra   :n
:x          plb
            lda   :w
            cmp   #NT_BIG
            bcc   :small
            lda   #1
            sta   RefreshF
            sta   StatusF
            sta   NtBig
:small      rts
:add        txa                       ; X = a CIRAM byte: onto the list
            phx
            ldx   :app
            stal  NtBuf,x
            inx
            inx
            stx   :app
            plx
            rts

; Y = a cell, NwVal its tile, DBR = the cell bank.  A cell on an edge keeps its role; the solid tile's word is SOLIDTEST
PutCell     lda   NwVal
            xba
            lsr
            ora   #BGWORD
            sta   NwNew
            lda:  WORD,y
            and   #$FF80
            sta   NwOld
            cmp   NwNew
            bne   :ch
            rts
:ch         lda   NwNew
            cmp   #SOLIDWORD
            bne   :notnew
            lda   #SOLIDTEST          ; Becoming solid.  Promote sets its neighbors' bits
            bra   :word
:notnew     lda   NwOld
            cmp   #SOLIDWORD
            bne   :plain
            lda   #0                  ; Leaving solid
            jsr   NbrFlags
:plain      lda   NwNew
:word       sta   NwT
            lda:  WORD,y
            and   #$007F
            cmp   #ROLE0
            bcs   :r1
            lda   NwT
            bra   :w1
:r1         ora   NwNew
:w1         sta:  WORD,y
            tya
            jmp   ListSyncA
            
; A cell's neighbors, from the cell above it (inside its page: NbrFlags)
NBR_L       equ   1024-32             ; From the cell above to the left neighbor
NBR_R       equ   1024+32
NBR_D       equ   2048

; A cell's flags, the cell at X + ]2: add the bit ]1, or remove it
FlagSet     mac
            lda:  ]2+1,x
            ora   #]1
            sta:  ]2+1,x
            txa                       ; Its list entries (a blank cell's stub is by its flags)
            clc
            adc   #]2
            jsr   ListSyncA
            <<<
FlagClr     mac
            lda:  ]2+1,x
            and   #$FFFF-]1
            sta:  ]2+1,x
            txa                       ; Its list entries (a blank cell's stub is by its flags)
            clc
            adc   #]2
            jsr   ListSyncA
            <<<

; Y = a cell, A = $FFFF to set, 0 to clear, DBR = the cell bank: this cell's bit in its 4 neighbors' flags.  Keeps Y.
; A cell inside its page has them all past the one above it: one index, four offsets.  One on the page's edge works out each
; neighbor from its offset: a column wrap flips the page with vertical mirroring (NbrColX), a row wrap with horizontal (NbrRowX)
NbrFlags    tax                       ; (set or clear)
            tya
            and   #$03E0              ; Column 0 or 31, row 0 or 29: the edge
            beq   :edgej
            cmp   #$03E0
            beq   :edgej
            tya
            and   #$7C00
            beq   :edgej
            cmp   #29*1024
            beq   :edgej              ; (C clear from here: the row is below 29)
            txa
            beq   :clr
            tya
            sbc   #1024-1             ; X = the cell above
            tax
            FlagSet FLAG_D;0
            FlagSet FLAG_R;NBR_L
            FlagSet FLAG_L;NBR_R
            FlagSet FLAG_U;NBR_D
            rts
:edgej      jmp   :edge
:clr        tya
            sbc   #1024-1
            tax
            FlagClr FLAG_D;0
            FlagClr FLAG_R;NBR_L
            FlagClr FLAG_L;NBR_R
            FlagClr FLAG_U;NBR_D
            rts

:edge       stx   NwE
            tya                       ; Above: row 0's is row 29 (vertical: this page; horizontal: the other)
            bit   #$7C00
            bne   :u1
            eorl  NbrRowX
            clc
            adc   #30*1024
:u1         sec
            sbc   #1024
            sta   NwRow
            tya                       ; Left: column 0's is column 31 (vertical: the other page; horizontal: this one)
            bit   #$03E0
            bne   :l1
            eorl  NbrColX
            clc
            adc   #32*32
:l1         sec
            sbc   #32
            sta   NwCol
            tya                       ; Right: column 31's is column 0
            and   #$03E0
            cmp   #$03E0
            beq   :r0
            tya
            adc   #32                 ; (C clear: the column is below 31)
            bra   :r1
:r0         tya
            eorl  NbrColX
            sec
            sbc   #31*32
:r1         sta   NwCell
            tya                       ; Below: row 29's is row 0
            and   #$7C00
            cmp   #29*1024
            beq   :d0
            tya
            adc   #1024               ; (C clear: the row is below 29)
            bra   :d1
:d0         tya
            eorl  NbrRowX
            sec
            sbc   #29*1024
:d1         tax
            lda   NwE
            beq   :eclr
            FlagSet FLAG_U;0
            ldx   NwRow
            FlagSet FLAG_D;0
            ldx   NwCol
            FlagSet FLAG_R;0
            ldx   NwCell
            FlagSet FLAG_L;0
            rts
:eclr       FlagClr FLAG_U;0
            ldx   NwRow
            FlagClr FLAG_D;0
            ldx   NwCol
            FlagClr FLAG_R;0
            ldx   NwCell
            FlagClr FLAG_L;0
            rts

; ---- Buffers
NTLIST      equ   $1000               ; A list's bytes: 2 for each of the 2048 CIRAM bytes
NtBuf       ds    NTLIST*2            ; The two lists of changed CIRAM offsets
NtSeen      ds    $1000               ; Per list, per CIRAM byte: not 0 if it is on the list
AttrShadow  ds    128                 ; The attribute bytes the cells have (PutAttr)
ZeroSw      ds    $800                ; "Swizzle tables" for the solid tile, before there are any: every index of all four palettes,
                                      ; as the tile read may not be blank (a table PPUCTRL hasn't selected yet, or CHR-RAM not loaded)

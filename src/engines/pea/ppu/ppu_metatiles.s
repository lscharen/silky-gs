; ppu_metatiles.s - NES Metatile Rendering
;
; This file handles syncing metatile palette state into the IIgs PEA code
; field.  A "metatile" is a 2x2 block of NES tiles (16x16 pixels) that
; shares a single palette assignment from the attribute table.
;
; Key routines:
;   ForceMetatileRefresh  - Debug helper: re-syncs all metatiles from shadow RAM
;   RefreshPPUAttributes  - Redraw the metatiles that use the given background palettes
;   SyncPPUMetatile       - Update one metatile (4 tiles) in the PEA field and
;                           its shadow RAM from a new attribute value
;   RefreshMetatile       - Alternate entry: refresh without changing the value
;
; patch1-4 are CALL_COMPILED_TILEs (ppu_macros.s): PPUStartUp patches the compile bank into them,
; and SET_COMPILED_TILE points each at its tile before the calls.

; Re-sync every metatile with the graphics screen.  Used by the 'f' key.
        mx %00
ForceMetatileRefresh
        lda  #%1111

; Redraw the metatiles of both physical (CIRAM) nametables that use the given background palettes,
; with the current swizzle tables.  Used when a palette change moves a background palette's colors
; to other IIgs palette slots.  The tile tables are indexed by CIRAM address: page $000 and $400,
; 15 rows of 16 metatiles each (the attribute bytes start at $3C0).
;
; A = background palettes to redraw (bit 0 = palette 0 .. bit 3 = palette 3)
        mx %00
RefreshPPUAttributes
        and  #$000F
        bne  :go
        rts
:go     sta  :mask
        ldx  #$0000                 ; CIRAM address of the metatile's top-left tile
:loop
        ldal PPU_MEM+ATTR_SHADOW,x  ; palette select * 2
        and  #$0006
        tay
        lda  :bits,y
        and  :mask
        beq  :skip
        tya
        phx
        sep  #$20
        jsr  RefreshMetatile        ; A = palette select * 2, X = corner (trashes X and Y)
        rep  #$20
        plx
:skip   inx                         ; next metatile in the row
        inx
        txa
        bit  #$001F
        bne  :loop
        clc                         ; end of a row: skip the row of bottom tiles
        adc  #$0020
        tax
        and  #$03FF
        cmp  #$03C0
        bcc  :loop
        txa                         ; end of a page: skip its attribute bytes
        adc  #$003F                 ; (carry is set)
        tax
        cpx  #$0800
        bcc  :loop

        lda  #DIRTY_BIT_BG0_REFRESH
        tsb  DirtyBits
        rts

:mask   ds   2
:bits   dw   %0001,%0010,%0100,%1000

; Sync a metatile value to the PPU data bank and to the code field
;
; This is called "sync" instead of "draw" because this routine takes care
; of updating the various shadow values in the PPU data base as well as
; actually drawing the tiles to the PEA field.
;
; There's a bit of nuance, too, because the bottow row of metatiles that corresponds
; to the top 4 bits of the PPU Attribute bytes does not actually exist and must
; be skipped.  This is detected by storing a zero in the TILE_BANK shadow memory
; since the PEA fields will never be allocated in Bank 00.
;
; X = CIRAM address of the top-left corner of the metatile
; A = Palette select value for all tiles
; P = 8-bit A / 16-bit XY
        mx    %10
SyncPPUMetatile
        stal PPU_MEM+ATTR_SHADOW+$00,x     ; Store the palette select bits in the shadow page of the PPU MEM bank ($6000 - $7FFF)
        stal PPU_MEM+ATTR_SHADOW+$01,x
        stal PPU_MEM+ATTR_SHADOW+$20,x
        stal PPU_MEM+ATTR_SHADOW+$21,x

        mx    %10
RefreshMetatile                            ; Alternate entry point is not setting a new value, just drawing
        pha                                ; The PEA field must not have patched exits under the tiles
        ldal  stkAnyPatched
        beq   :stable
        jsr   _PEAFieldStable
:stable pla
        DO    ENABLE_DIRTY_RENDERING
        jsr   gridRecordMetatile           ; Let the grid renderer expose these 4 tiles (preserves A, X, Y)
        FIN
        clc
        adc   SwizzlePtr+1                 ; Set the palette selection (used for all 4 tiles)
        sta   ActivePtr+1

; Point the four calls at the tiles' compiled code (16-bit: the tile ID is loaded into the high byte)

        rep   #$20
        ldal  PPU_MEM+TILE_SHADOW-1+$00,x  ; the tile ID in the high byte
        SET_COMPILED_TILE_HI patch1
        ldal  PPU_MEM+TILE_SHADOW-1+$01,x  ; the tile ID in the high byte
        SET_COMPILED_TILE_HI patch2
        ldal  PPU_MEM+TILE_SHADOW-1+$20,x  ; the tile ID in the high byte
        SET_COMPILED_TILE_HI patch3
        ldal  PPU_MEM+TILE_SHADOW-1+$21,x  ; the tile ID in the high byte
        SET_COMPILED_TILE_HI patch4
        sep   #$20

        ldal  PPU_MEM+TILE_BANK,x     ; The tiles in the same row will have the same bank
        beq   bad_row2                ; The bottom metatile row is not defined

        phb                           ; Save the current bank

        pha                           ; Point to the PEA code bank
        plb

; Calculate a few values for the next row

        ldal  PPU_MEM+TILE_BANK+$20,x
        pha

; This saves a net amount of 14 cycles

        ldal  PPU_MEM+TILE_ADDR_HI+$20,x
        pha

        ldal  PPU_MEM+TILE_ADDR_LO+$20,x
        pha                                ; Push the address onto the stack directly instead of going through a 16-bit register

; Now get the values for the top two tiles

        ldal  PPU_MEM+TILE_ADDR_HI,x  ; Load the high byte for this tile address
        xba
        ldal  PPU_MEM+TILE_ADDR_LO,x  ; Load the low byte for this tile address
        tax

        rep   #$21                    ; 16-bit mode for the tile copy

patch1  CALL_COMPILED_TILE

        txa
        sec
        sbc   #6                      ; Move to the next PEA tile address
        tax

patch2  CALL_COMPILED_TILE

        plx                           ; Load up for the next row
        plb                           ; This almost never changes... :(

patch3  CALL_COMPILED_TILE

        txa
        sec
        sbc   #6                      ; Move the the next PEA tile address
        tax

patch4  CALL_COMPILED_TILE

        plb                           ; Restore the original bank
        sep   #$20
bad_row2
        rts

; ---------------------------------------------------------------------------
; CHR-RAM background tiles: recompiled when they are called (HAS_CHR_RAM)
; ---------------------------------------------------------------------------
;
; A tile the game rewrites in CHR-RAM is recompiled the first time it is drawn afterwards, without the
; draw paths testing anything: its compiled slot holds a stub instead of the tile's code,
;
;   phk / pea slot-1 / jml BgTileFault
;
; and BgTileFault recompiles the tile into the slot (over the stub) and continues into it.  The stubs
; are written on the GS task, which is the only one that runs compiled tiles: the NES task could
; preempt it inside the very tile it rewrites.  So a CHR-RAM write only queues the tile (ChrQueueBg,
; from PPUDATA_WRITE_CHR, the first time its CHRRAM_BG_DIRTY bit is set), RenderLatch freezes the queue
; with the rest of the NES state, and ChrInstallStubs, right after it, stubs the tiles that are still
; dirty.  A cell drawn between a CHR-RAM write and the next latch shows the old pattern, as a cell drawn
; before the write does (nothing redraws cells when CHR-RAM changes).
;
; CHRRAM_BG_DIRTY (ChrRamDirty) means "queued or stubbed, not recompiled yet": set by the write, cleared
; only by the recompile (ChrRecompileBg).  At start-up every tile is dirty and stubbed (ChrStartUp).
;
; The queue is double-buffered: the NES task appends to one list while ChrInstallStubs reads the other.
; A list that fills up is marked instead, and the installer then visits all 512 tiles.
        DO    HAS_CHR_RAM
CHR_PEND_MAX    equ   128               ; Entries per list
chrPendSel      dw    0                 ; 0 / CHR_PEND_MAX*2: the list the NES task appends to
chrPendCnt      dw    0                 ; Bytes in it
chrPendAll      dw    0                 ; Non-zero: it overflowed
chrPendPrevCnt  dw    0                 ; The frozen list (RenderLatch) for ChrInstallStubs
chrPendPrevAll  dw    0
chrInsPtr       dw    0
chrInsEnd       dw    0
chrStubW2       dw    0                 ; The stub's last two words: $5C (jml), BgTileFault (ChrStartUp)
chrStubW3       dw    0
chrPendList     ds    CHR_PEND_MAX*4    ; Both lists: tile indexes (0 - 511), one word each

; Queue a tile whose CHRRAM_BG_DIRTY bit has just been set.  NES task (the PPUDATA_WRITE_CHR jsl),
; DBR = the ROM's, 8-bit A, 16-bit X = the tile (0 - 511).  A, X and Y are preserved.
        mx    %10
ChrQueueBg
        phb
        phk
        plb
        pha
        rep   #$20
        lda   chrPendCnt
        cmp   #CHR_PEND_MAX*2
        bcs   :full
        phy
        adc   chrPendSel                ; (C = 0)
        tay
        txa
        sta   chrPendList,y
        ply
        inc   chrPendCnt
        inc   chrPendCnt
        sep   #$20
        pla
        plb
        rts
        mx    %00
:full   lda   #1                        ; (no room: visit every tile)
        sta   chrPendAll
        sep   #$20
        pla
        plb
        rts

; Freeze the queue.  RenderLatch, interrupts off, 16-bit registers, DBR = K.
        mx    %00
ChrLatchQueue
        lda   chrPendCnt
        sta   chrPendPrevCnt
        stz   chrPendCnt
        lda   chrPendAll
        sta   chrPendPrevAll
        stz   chrPendAll
        lda   chrPendSel
        eor   #CHR_PEND_MAX*2
        sta   chrPendSel
        rts

; Stub the frozen list's tiles that are still dirty (a game can recompile one itself in between:
; CheckBgTileDirty).  GS task, interrupts on, 16-bit registers, DBR = K, D = the runtime's (CompileBank0).
; A, X and Y are trashed.
        mx    %00
ChrInstallStubs
        lda   chrPendPrevAll
        bne   :all
        lda   chrPendSel                ; The frozen list is the one not being appended to
        eor   #CHR_PEND_MAX*2
        sta   chrInsPtr
        clc
        adc   chrPendPrevCnt
        sta   chrInsEnd
:next   ldx   chrInsPtr
        cpx   chrInsEnd
        bcs   :done
        lda   chrPendList,x
        inx
        inx
        stx   chrInsPtr
        tax
        jsr   :one
        bra   :next

:all    ldx   #0
:anext  jsr   :one
        inx
        cpx   #512
        bcc   :anext
:done   stz   chrPendPrevCnt
        stz   chrPendPrevAll
        rts

; X = the tile (preserved)
:one    lda   ChrRamDirty,x             ; (a 16-bit read: only bit 0 is tested)
        bit   #CHRRAM_BG_DIRTY
        beq   :clean
        txa                             ; the slot: tile * 128
        lsr
        xba
        bcc   *+5
        ora   #$0080
        tay
        lda   #$F44B                    ; phk / pea
        sta   [CompileBank0],y
        tya
        dec                             ; slot - 1: the rtl at the end of BgTileFault lands on the slot
        iny
        iny
        sta   [CompileBank0],y
        iny
        iny
        lda   chrStubW2                 ; jml BgTileFault
        sta   [CompileBank0],y
        iny
        iny
        lda   chrStubW3
        sta   [CompileBank0],y
:clean  rts

; Stub every tile and mark it dirty (PPUStartUp: nothing has been uploaded yet).  16-bit registers,
; DBR = K, D = the runtime's.
        mx    %00
ChrStartUp
        lda   #BgTileFault              ; The stub's jml operand
        xba
        pha
        and   #$FF00
        ora   #$005C                    ; jml, then the address' low byte
        sta   chrStubW2
        pla
        and   #$00FF                    ; the address' high byte, then the bank
        sta   chrStubW3
        sep   #$20
        phk
        pla
        sta   chrStubW3+1
        rep   #$20

        ldx   #0
        lda   #{CHRRAM_BG_DIRTY+CHRRAM_SPR_DIRTY}*$0101
:mark   sta   ChrRamDirty,x
        inx
        inx
        cpx   #512
        bcc   :mark
        stz   chrPendCnt
        stz   chrPendAll
        lda   #1                        ; visit them all
        sta   chrPendPrevAll
        jmp   ChrInstallStubs

; A stubbed tile was called (CALL_COMPILED_TILE: 16-bit registers, X = the code field address, DBR =
; the code field bank; the compiled code itself sets Y and A).  The stub left the compile bank and
; slot - 1 on the stack, over the caller's return address.  Recompile the tile, then rtl into it: it
; returns to the caller.  X, DBR and P are preserved.
        mx    %00
BgTileFault
        php
        phb
        phx
        phk
        plb
        lda   5,s                       ; slot - 1 (X at 1,s, B at 3,s, P at 4,s)
        inc
        jsr   ChrRecompileBg
        plx
        plb
        plp
        rtl

; Recompile a background tile: convert its CHR-RAM bytes into its tiledata slot and compile them into
; its compiled slot (over a stub, if it has one).  A = the slot (tile * 128 | bgadr_hi: also the tile's
; tiledata offset), 16-bit registers, DBR = K.  A, X and Y are trashed.
;
; The bit is cleared before the bytes are read, so a write that comes in meanwhile marks the tile again
; (and queues it).  With interrupts off: the NES task may set the byte's other bit in between.
        mx    %00
ChrRecompileBg
        pha                             ; the slot
        CHR_INDEX                       ; X = the tile's ChrRamDirty index
        sep   #$20
        php
        sei
        lda   ChrRamDirty,x
        and   #CHRRAM_BG_DIRTY!$FF      ; clear only the BG bit, keep the sprite bit
        sta   ChrRamDirty,x
        plp
        rep   #$20

        lda   1,s
        lsr
        lsr
        lsr
        tax                             ; X = the CHR-RAM source address (index * 16 = slot / 8)
        lda   1,s                       ; A = the tiledata destination (the slot)
        jsr   FastROMTileToLookup       ; writes the 32-byte bitmap directly into tiledata; trashes A/X/Y
        lda   1,s
        tay                             ; Y = the compiled-code slot, A = the bitmap (the same offset)
        ldx   #^tiledata                ; X = bank of the bitmap source
        jsr   CompileTile
        pla
        rts

; Recompile a background tile now if it is dirty: for a game that redraws tiles itself after
; rewriting them (Contra's barriers, EngineExt.s).  A = the slot; 16-bit registers, DBR = K.  X and Y
; are preserved; A is not.
        mx    %00
CheckBgTileDirty
        phx
        phy
        pha
        CHR_INDEX                       ; X = the tile's ChrRamDirty index
        lda   ChrRamDirty,x             ; (a 16-bit read: only bit 0 is tested)
        bit   #CHRRAM_BG_DIRTY
        beq   :clean
        lda   1,s
        jsr   ChrRecompileBg
:clean  pla
        ply
        plx
        rts
        FIN

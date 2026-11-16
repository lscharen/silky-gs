; SprLib.s -- silky-gs's sprite cache and bitmap draws, in their own segment.  They use the runtime's direct page and its names
; (Defs.s), so an entry here switches to that page and back.  Sprite.s does the cell tracking and calls compiled sprites itself.

            rel
            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   ../../Externals.s
            put   ../../core/Defs.s
            put   ../../game/Config.s
            put   ../../game/pal_defs.s
            put   SprSlots.s
            put   ../../game/Hooks.s          ; (SPRITE_CLIP)
            put   Stats.s
            DO    TILE_STATS
tsSprFlush  EXT                       ; Sprite.s (Stats.s)
            FIN

CHRRAM_BG_DIRTY equ $01                ; ChrRamDirty's bits (as silky's CoreData.s)
CHRRAM_SPR_DIRTY equ $02

draw_rtn2   EXT                       ; Sprite.s: where a compiled sprite returns (CompileSprites.s)
EngD        EXT                       ; Front.s: the engine's page
SprBanks    EXT                       ; Memory.s: the cache's banks
SprBankCount EXT
_ppuctrl    EXT
_ppuscroll_x EXT
OAM_COPY    EXT
sprClipTop  EXT
ChrRamDirty EXT

            mx    %00

SPR_MAX_SLOTS equ SPR_BANK_SLOTS*SPR_MAX_BANKS
SPR_STAT    mac                       ; (as the PEA engine's ppu_macros.s: A and the flags are trashed)
            DO    SPR_CACHE_STATS
            ldal  PPU_MEM+SPR_STATS+]1
            inc
            stal  PPU_MEM+SPR_STATS+]1
            bne   *+11
            ldal  PPU_MEM+SPR_STATS+]1+2
            inc
            stal  PPU_MEM+SPR_STATS+]1+2
            FIN
            <<<
; A tile's ChrRamDirty index from its address in the tiledata bank: X = A >> 7.  A is trashed
CHR_INDEX   mac
            asl
            xba
            and   #$00FF
            bcc   *+5
            ora   #$0100
            tax
            <<<
sprBankSwap equ unused174             ; $01 << 8 | ^tiledata: pei / plb selects the tiledata bank, plb back to $01
sprTmp5     equ sprTmp5Hi             ; tiledata bank offset for the pattern table: $0000 or $8000

SPR_PALETTE mac
            sep   #$20
            lda   sprTmp2+1
            and   #$03
            asl
            adc   SwizzlePtr2+1
            sta   ActivePtr+1
            rep   #$20
            <<<

; Switch to the runtime's page and data bank K, and back
RUNPAGE     mac
            phd
            pha
            ldal  EngD
            sec
            sbc   #$100
            tcd
            pla
            <<<

SprCacheInitL ENT
            RUNPAGE
            jsr   SprCacheInit
            pld
            rtl

SprRequestFlushL ENT
            phb
            phk
            plb
            jsr   SprRequestFlush
            plb
            rtl

; Before a frame's sprites: a flush if the swizzle tables changed; the pattern table's offset for the bitmap draws.  Returns
; A = the offset of SPR_COMP_TBL's half for this table, in PPU_MEM's bank
SprFrameL   ENT
            RUNPAGE
            phb
            phk
            plb
            lda   #^tiledata
            and   #$00FF
            ora   #$0100
            sta   sprBankSwap
            ldal  SprFlushReq
            beq   :f
            TSINC tsSprFlush
            jsr   SprCacheFlush
:f          ldal  _ppuctrl
            and   #$0008              ; The sprite pattern table
            beq   :t0
            lda   #$8000
:t0         sta   sprTmp5
            plb
            lsr
            lsr
            lsr
            clc
            adc   #SPR_COMP_TBL
            pld
            rtl

; A sprite with no compiled form, or clipped, or behind the background.  A = OAM's tile and attributes, X = bytes past the
; right edge's safe limit (0: not clipped), Y = its screen address, DBR = $01.  From the bitmap
SprSlowL    ENT
            RUNPAGE
            sta   sprTmp2
            stx   sprTmp4
            sty   sprTmp1
            DO    SPRITE_CLIP
            ldal  sprClipTop          ; The top lines to hide, for the clipped draws
            sep   #$20
            sta   sprTmp4+1
            rep   #$20
            FIN
            jsr   SprBitmap
            pld
            rtl

; An 8x16 sprite's two halves: A, X, Y as above.  OAM's tile bit 0 is the pattern table, and the flipped sprite has the odd tile on top
SprSlow16L  ENT
            RUNPAGE
            sta   sprTmp2
            stx   sprTmp4
            sty   sprTmp1
            and   #$0001
            beq   :t0
            lda   #$8000
:t0         sta   sprTmp5
            lda   sprTmp2
            and   #$FFFE
            bit   #$8000
            beq   *+3
            inc
            sta   sprTmp2
            DO    SPRITE_CLIP         ; Top half: min(clip, 8) lines hidden; all of them skips it
            ldal  sprClipTop
            cmp   #8
            bcs   :bot
            sep   #$20
            sta   sprTmp4+1
            rep   #$20
            FIN
            jsr   SprBitmap
:bot        lda   sprTmp1
            clc
            adc   #8*160
            sta   sprTmp1
            lda   sprTmp2
            eor   #$0001
            sta   sprTmp2
            DO    SPRITE_CLIP         ; Bottom half: max(clip - 8, 0) lines hidden
            ldal  sprClipTop
            sec
            sbc   #8
            bcs   *+5
            lda   #0
            sep   #$20
            sta   sprTmp4+1
            rep   #$20
            FIN
            jsr   SprBitmap
            pld
            rtl

; sprTmp1, sprTmp2, sprTmp4, sprTmp5 are set.  DBR = $01, D = the runtime's
SprBitmap
            DO    HAS_CHR_RAM         ; Reconvert the tile if CHR-RAM changed it
            lda   sprTmp2-1
            and   #$FF00
            lsr
            ora   sprTmp5
            tay
            jsr   sprChrCheck
            FIN
            SPR_PALETTE
            lda   sprTmp2+1
            and   #$00E0
            lsr
            lsr
            lsr
            lsr
            tax
            lda   sprTmp2-1
            and   #$FF00
            lsr
            ora   sprTmp5
            pei   sprBankSwap
            plb
            ldy   sprTmp4
            bne   :clip
            jsr   (drawProcs,x)
            bra   :x
:clip       jsr   (drawProcsClipped,x)
:x          plb
            rts

            DO    HAS_CHR_RAM
; If the sprite's tile was rewritten since it was converted, reconvert it.  A = Y = the tile's address in the tiledata bank.
; DBR = $01.  (silky's, from ppu.s.)  Y is preserved
sprChrCheck
            CHR_INDEX
            ldal  ChrRamDirty,x
            bit   #CHRRAM_SPR_DIRTY
            bne   :dirty
            rts
:dirty      sep   #$20                ; (8 bits: the next tile's flags are the NES task's)
            and   #CHRRAM_SPR_DIRTY!$FF
            stal  ChrRamDirty,x
            rep   #$20
            phy
            pei   sprBankSwap
            plb
            tya
            lsr
            lsr
            lsr
            tax
            tya
            jsr   FastROMMaskedTileToLookup
            plb
            ply
            rts

; A = a tile's address in the tiledata bank: reconvert it.  From the engine's page (ChrFresh)
ChrConvertL ENT
            RUNPAGE
            phb
            pha
            lsr
            lsr
            lsr
            tax
            pla
            jsr   FastROMMaskedTileToLookup
            plb
            pld
            rtl
            FIN

            DO    SPR_PIXEL_SHIFT
; A compiled sprite on an odd pixel whose shifted pair is not compiled yet: called by its stub (EmitShiftStubs), which then draws the
; plain variant, a pixel to the left.  Queue the pair, unless this render's quota is used up.  X = the OAM index, and X and Y are
; kept.  Any direct page: the key comes from the OAM entry
SprQueueShift
            phx
            ldal  PPU_MEM+SPR_PEND_CNT
            cmp   #2*SPR_COMPILE_PER_RENDER
            bcs   :full
            pha
            ldal  OAM_COPY+1,x
            and   #$83FF              ; tile, palette and vertical flip
            asl
            adc   #0
            asl
            ora   #$0001              ; and the shift request
            pha
            ldal  _ppuctrl            ; The pattern table
            and   #$0008
            beq   :t0
            lda   #$1000
            ora   1,s
            sta   1,s
:t0         pla
            plx
            stal  PPU_MEM+SPR_PEND,x
            inx
            inx
            txa
            stal  PPU_MEM+SPR_PEND_CNT
:full       plx
            rtl
            FIN

            DO    SPR_PIXEL_SHIFT*SPR_TALL
; The same for a whole 8x16 sprite, called by the stubs in its shifted variants (EmitTallStubs)
SprQueueTall
            phx
            ldal  PPU_MEM+SPR_PEND_CNT
            cmp   #2*SPR_COMPILE_PER_RENDER
            bcs   :full
            pha
            ldal  OAM_COPY+1,x
            and   #$83FF
            asl
            adc   #0
            asl
            ora   #SPR16_KEY+1
            plx
            stal  PPU_MEM+SPR_PEND,x
            inx
            inx
            txa
            stal  PPU_MEM+SPR_PEND_CNT
:full       plx
            rtl
            FIN

; A sprite that missed: A = its key offset.  Queued, unless this render's compile quota is used up
SprMissL    ENT
            phx
            pha
            ldal  PPU_MEM+SPR_PEND_CNT
            cmp   #2*SPR_COMPILE_PER_RENDER
            bcs   :full
            tax
            pla
            stal  PPU_MEM+SPR_PEND,x
            inx
            inx
            txa
            stal  PPU_MEM+SPR_PEND_CNT
            plx
            rtl
:full       pla
            plx
            rtl

; After a frame's sprites: compile what missed
SprServiceL ENT
            RUNPAGE
            jsr   SprCacheService
            pld
            rtl

drawProcs
            dw    drawTileToScreen,drawTileToScreenP,drawTileToScreenH,drawTileToScreenPH
            dw    drawTileToScreenV,drawTileToScreenPV,drawTileToScreenHV,drawTileToScreenPHV
drawProcsClipped
            dw    drawClippedTileToScreen,drawClippedTileToScreenP,drawClippedTileToScreenH,drawClippedTileToScreenPH
            dw    drawClippedTileToScreenV,drawClippedTileToScreenPV,drawClippedTileToScreenHV,drawClippedTileToScreenPHV

            put   ../../ppu/ppu_tile_blitters.s
            put   ../../core/sprites/CompileSprites.s
            DO    HAS_CHR_RAM
            put   ../../ppu/chr_convert.s
            put   ChrTables.s
            FIN

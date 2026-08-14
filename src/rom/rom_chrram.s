; rom_chrram.s - CHR-RAM tile conversion without compiling
;
; For HAS_CHR_RAM games, background tiles are normally converted from raw
; CHR-RAM bytes into a compiled per-tile routine (ConvertROMTile3 in
; rom_tiles.s, which converts *and* compiles). CHR-RAM content can change
; every few frames, so compiling is often wasted work -- the routine gets
; thrown away almost as soon as it's built.
;
; ConvertCHRTileBG below does only the conversion half: it reuses the
; existing ROMTileToBitmap (rom_tiles.s) to decode the NES-interleaved CHR
; bytes into the swizzle-index bitmap format the runtime expects, then copies
; the result directly into the background half of the `tiledata` bank
; (documented in src/MemoryMap.md: 128-byte stride per tile ID, base $8000)
; instead of handing it to CompileTile.
;
; This routine is intentionally not wired into any live PPU code path yet --
; it's a standalone, unit-tested building block. Replacing the compiled-code
; dispatch in DrawPPUTile/RefreshMetatile with something that reads
; `tiledata` directly (so this routine's output actually gets drawn) is
; follow-up work.
            mx    %00

; Convert one CHR-RAM tile into tiledata's background slot, without
; compiling it.
;
; X = CHR-RAM source address (tile_id*16 + PPU_BG_TILE_ADDR)
; Y = destination offset within tiledata (tile_id*128 + $8000)
;
; P = 16-bit A/X/Y on entry (mx %00), matching ROMTileToBitmap's own calling
; convention. Trashes A. X and Y are not preserved -- the destination copy
; loop needs X (absolute-long indexed addressing only supports ,x, not ,y)
; for the tiledata store, so the incoming Y is moved into X after the call.
ConvertCHRTileBG
            phy                      ; Save the destination offset across ROMTileToBitmap
            lda   #TileBuff
            jsr   ROMTileToBitmap    ; X = CHR source address; result (32 bytes) left in TileBuff
            ply
            tyx                      ; X = destination offset within tiledata

            ldy   #0
:cploop
            lda   TileBuff,y
            stal  tiledata,x
            iny
            iny
            inx
            inx
            cpy   #32
            bcc   :cploop
            rts

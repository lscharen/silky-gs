# Memory Allocations

# tiledata

A static bank of memory allocation in core/static/TileData.s.  This memory bank is used to store the converted
tile data from the NES CHR-ROM/CHR-RAM in a format that is more efficient to use when rendering to the IIgs
graphic screen.

Each NES tile is 8x8 pixels, which occupies 32 bytes of memory in this converted format.  However, there is no
efficient way to flip a tile horizontally while drawing, so each processed tile is also stored a second time,
flipped on the horizontal axis.  It _is_ possible to flip a tile vertically while drawing by changing the
loading order, so those tiles do not need to be pre-created.  In addition to the horizontally flipped copy, a
mask must be calculated for tiles that are used as sprites (drawing a background tile always fully overwrites
the destination, so it never needs one).  This results in a total of four regions per tile -- bitmap normal,
mask normal, bitmap flipped, mask flipped -- 128 bytes per tile.  (Background tiles only ever populate the
first of the four 32-byte regions; the other 96 bytes go unused when a slot is only ever read by the
background/compiled-tile path.)

## Indexing: tile ID *and* pattern table, not tile ID alone

A NES tile ID (0-255) is not on its own enough to say which CHR bytes a tile actually is -- the PPU has two 4KB
pattern tables, and the console independently selects which one sprites read from and which one the background
reads from via PPUCTRL bits 3 and 4 (tracked at runtime as `spadr`/`bgadr` in `ppu_regs.s`, and for CHR-RAM
games, changeable by the game at any time -- Zelda does this). So `tiledata` is indexed by the combination of
(tile ID, pattern table), a 512-entry space, not by tile ID alone:

```
index = tile ID | (pattern table == $1000 ? $0100 : $0000)     ; 0-511
slot address = index * 128                                      ; 0-$FFFF, fills the bank exactly
```

This is a single *shared* 512-slot cache -- there is no fixed "first half is sprites, second half is
background" split. Whichever code path (sprite or background) first needs a given (tile ID, pattern table)
pair recompiles that one shared slot; since both paths convert the exact same source CHR bytes into the same
32-byte bitmap layout, it doesn't matter which one got there first, or whether a slot ends up used by both a
sprite and a background tile that happen to reference the same tile ID from the same pattern table. The
sprite path (`FastROMMaskedTileToLookup`, `src/rom/rom_tiles.s`) additionally fills the mask/flip regions;
the background path (`FastROMTileToLookup` + `CompileTile`, or historically `ConvertROMTile3`) only ever
touches the first 32 bytes.

`ChrRamDirty` (CHR-RAM games only, `src/core/CoreData.s`) mirrors this same 512-entry, table-aware indexing --
`PPUDATA_WRITE` (`ppu_regs.s`) marks a byte dirty using the raw CHR-RAM address's own table bit, and every
consumer (`CheckSprTileDirty` in `ppu.s`, `DrawPPUTile` in `ppu_attributes.s`, `CheckBgTileDirty` in
`ppu_metatiles.s`) must fold in the *currently selected* `spadr`/`bgadr` table bit (via the derived
`spadr_lo`/`bgadr_lo` values in `ppu_regs.s`) before checking or clearing it -- checking with the raw tile ID
alone only ever sees pattern table 0's flags and silently never recompiles a tile whose table is $1000.

Each byte holds two independent dirty bits, `CHRRAM_BG_DIRTY` ($01) and `CHRRAM_SPR_DIRTY` ($02) (both defined
in `CoreData.s`), not one shared flag. `PPUDATA_WRITE` sets both on every CHR-RAM write; each consumer tests
and clears only its own bit (via `BIT #mask` / `AND #~mask`), leaving the other bit alone. This matters because
a single tile ID can be drawn as both a background tile and a sprite (e.g. reused for a title-screen sprite and
a level-map tile) -- with one shared flag, whichever consumer ran first cleared it for both, so the other
consumer's compiled form was never generated and a later unconditional jump into it crashed.

## Why this isn't true of the compiled-code banks

The governing rule is: **how the engine reads/tracks CHR-RAM must match what the NES hardware actually does**
(respect whichever pattern table is currently selected, for every tile, always). `tiledata`'s "coincidentally
big enough for all 512 (tile ID, table) combinations in one bank" layout is a convenience that falls out of
that rule, not a second, independent design choice -- but the *compiled-code* destination banks (background:
`patch1-4`'s targets in `ppu_metatiles.s`/`ppu_attributes.s`, written via `CompileTile`; sprites:
`SPR_COMP_TBL`/`CompileSprite`) are genuinely separate, smaller caches, split by sprite vs. background purely
for engine data-management convenience (sprites and background tiles are compiled and dispatched in
completely different ways). The background code field only has room for 256 tile IDs, not 512 -- so unlike
`tiledata`, the destination page passed to `CompileTile` is tile-ID-only and must **not** have the
pattern-table bit folded in. (The compiled sprite cache below *is* indexed by the 512-entry
tile | table index.)

## Compiled sprite cache

The sprite compile bank holds up to `SPR_SLOTS` (127) fixed 512 byte slots, not a packed stream.  A compiled sprite is for
one tile and one *vertical* orientation, and contains two variants: as is and flipped horizontally.  The worst case is
2 x (16 words x 14 bytes + 4 byte return) = 456 bytes.  Slot 0 is unused because `$0000` means "not compiled".  Sprites are
compiled on demand:

- `SPR_COMP_TBL` (2048 words in `PPU_MEM`) is indexed by the key offset
  `(pattern table << 11) | (tile << 3) | (vertical flip << 2) | (horizontal flip << 1)` and holds the address of the
  variant's code, or 0.  A hit jumps straight into the variant; there is no dispatch code in the slot.  The two horizontal
  flips of a key are compiled into one slot, and their entries are set and cleared together.
- The slots are used in turn (`SPR_CURSOR`): a FIFO.  `SPR_OWNER` (indexed by slot address >> 8) has the key that owns
  each slot, whose entries are cleared when the slot is reused.  A cache hit does nothing.
- A sprite that misses is drawn from its bitmap and queued (`SPR_PEND`); `SprCacheService` compiles at most
  `SPR_COMPILE_PER_RENDER` queued keys at the end of each `drawSprites`.
- CHR-RAM: `:blitResolvedSprite` tests the sprite dirty flag inline, and `CheckSprTileDirty` reconverts a dirty tile and calls
  `SprInvalidate` for both of its vertical orientations, which clears their entries and frees their slots (reused when the
  cursor gets to them).  `PPUDATA_WRITE` is unchanged.
- `COMPILED_SPRITE_LIST` only warms the cache at startup (`SprCompileTile`).

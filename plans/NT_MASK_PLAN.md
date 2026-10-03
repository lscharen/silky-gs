# Attribute-Keyed Tile Masks with Double-Buffered CIRAM Shadows (replace `nt_list`)

## Status (2026-10-01): implemented, not committed

- **Verified pixel-identical** to the previous code: frame hash of the `$E1` playfield over 1,500 demo
  frames, BF `$0344C1B5`, DK `$03197CA8` (a throw-away hash build; not in the tree).
- **Builds:** BF, DK, Excitebike, Ice Climber, Lights Out, Wumpus, Zelda. Mario Bros and SMB fail to
  assemble at HEAD too (`mul8` in `ppu.s`, `HORIZONTAL_MIRRORING` in `rom_inject.s`), so they couldn't
  be checked. SMB and Zelda haven't been run.
- **Measured** (`frameCount` 2000→4000, GSSquared):

  | Game | Before (HEAD) | After | Change |
  |---|---|---|---|
  | BF | 115.74M | 116.24M | +0.4% (~250 cycles/frame) |
  | DK | 113.3M | 113.25M | ~0 |

  For these light, scattered updates that is the "about neutral" case in the projections. BF pays a
  small fixed cost per touched attribute group for its single-tile star writes. The freeze is now
  constant-time under `sei`, and the heavy-write gains (full-metatile batching, no per-tile freeze
  copy) apply to SMB/Zelda-style frames, which weren't measured.
- **Write path v2 (review feedback):** NT/AT split right after `ppu2ciram` (`ntmWriteTail` /
  `atmWriteTail`). Tile masks and attribute flags are now double-buffered 256-byte page-aligned arrays in
  the main bank, indexed by the 8-bit `T2IDX` (`lda T2IDX,x / tay`, with B cleared by the caller's
  `lda #0`). A group is queued when the first bit of a mask half is set or its attribute is first
  written, so it can appear up to 3 times (`AT_LIST_LEN` 384); repeat visits are skipped. The tile
  path went from ~118 to ~45 cycles (first touch of a half: ~70), the attribute path from ~75 to ~30.
  Still pixel-identical on BF and DK.
  - BF demo counts (frames 2000→4000): 4.3 nametable PPUDATA writes per frame, of which 1.6 change
    CIRAM; 1.0 group flushed per frame (0.1 repeat visits); 0.03 attribute writes.
  - Measured: BF 116.39M, DK 113.36M. That's the same as v1 within measurement resolution: identical
    code with 256 bytes of padding moved BF by 0.05M, so layout effects are of the same order. At 1.6
    changed writes per frame, the saving is ~100 cycles per frame (~0.2%), below what this benchmark
    resolves.
  - Unchanged writes (2.7 per frame in BF) now pay the split (~13 cycles) before the CIRAM compare.
    Doing the compare first, then testing `T2BIT == 0` for attributes, would avoid that.
- **v3:**
  - The CIRAM compare is back before the split, so unchanged writes cost nothing extra; the single
    tail tells attributes apart with `T2BIT == 0`, which also leaves 6 patch sites.
  - The flush reads each metatile's nibble with 8-bit ops and dispatches partial nibbles through
    `jsr (ntmPartTbl,x)` to 14 per-nibble routines.
  - Tile-only groups load the attribute value only when a whole metatile is redrawn.
  - Pixel-identical on BF and DK. BF 116.25M (v2 116.39M, v1 116.24M, HEAD 115.74M).
- **Where BF's remaining ~250 cycles/frame go (measured, not estimated):** `PPUFlushQueuesAlt` takes
  ~735 cycles on a one-tile frame against ~440 at HEAD. An instruction trace of one call (744 cycles):

  | Part | Cycles |
  |---|---|
  | `tileBitmap` clear (30 `stz`; only the legacy renderer reads it) | 155 |
  | Prologue (buffer pointer, main bank offset) | 49 |
  | Group setup (list load, address / base tables) | 63 |
  | Mask and flag read, skip test, clear | 55 |
  | Tile-only attribute path | 45 |
  | Quadrant scan (3 empty, 1 found) | 44 |
  | Dispatch + `ntmPartN` (copy one tile) | 81 |
  | `DrawPPUTile` + compiled tile | ~170 |
  | Grid `gmtList` entry (moved here from `gridDrawDirty`) | 45 |
  | Loop / exit | 34 |

  HEAD spends ~115 cycles beyond the `tileBitmap` clear and `DrawPPUTile`; v3 spends ~415. The extra
  ~300 is the per-group bookkeeping. The write path and freeze changes are below the benchmark's
  resolution.
- **v4:**
  - `tileBitmap` is removed: its per-frame clear and the flush's row marking are gone, and the legacy
    renderer's `LOAD_OTHERS` no longer ORs it in (it was always zero there, since background changes
    force a full refresh).
  - The group setup tests the flag first. Tile-only groups read the mask straight into `NtmMask` and
    skip the attribute address, value and EOR entirely; a zero mask means a repeat visit.
  - The attribute address is looked up only when it's used.
  - An empty mask byte skips both of its metatiles with one test.
  - Pixel-identical on BF and DK. **BF 115.86M** (HEAD 115.74M; within benchmark noise), **DK 113.01M**
    (HEAD 113.3M, ~0.3% faster).
- **Zelda fix:** the flush built its pointer to the previous buffer with `adc #PPU_MEM+NTM_SB0`. In
  Zelda that 16-bit `EXT+constant` operand resolved to `PPU_MEM+0` (`MERLIN32_OMF_EXT_OFFSET_BUG.md`),
  so it copied CHR-RAM bytes into `TILE_SHADOW` (wrong tiles on the title screen). BF and DK also
  import `PPU_MEM` as EXT but happened to work; why the builds differ isn't known. The pointer is now taken from the write path's relocated long operand
  (`ntmSiteD`), with the buffer bit flipped. BF/DK hashes unchanged.
- **Differences from the plan below:**
  - Masks are one interleaved word per attribute index (`T2IDX` = index * 2 + half), so the flush
    reads and clears them with one 16-bit access.
  - Attribute bytes are recognised by `T2BIT = 0` instead of an address compare.
  - Attribute index → address/base come from two 128-entry tables.
  - Tile-only groups take a fast path that skips the attribute read, EOR and expansion.
  - Partial metatiles add their grid entry inline, and the `tileBitmap` rows are only marked in
    non-grid builds.
  - `T2IDX`/`T2BIT`/`AttrExpand` are static tables in the main bank. The shadow buffers live in
    PPU_MEM at `$C800`/`$E800` (data), `+$0800` (masks) and `+$0900` (flags).
  - DP: `NtmPtr` 84, `NtmTMask` 88, plus the former `RenderPPUAttr` slots and `PPU_CLEAR_ADDR`.

## Goal

Stop tracking nametable tile writes as a list of addresses. The attribute byte becomes the unit of
tracking: every 4x4 tile group (one attribute byte) carries a 16-bit mask of the tiles written since
the last render. Only `at_list` is queued. At render time, palette changes (attribute EOR) and tile
writes are merged into one mask per attribute byte and drawn in a single pass, one metatile (nibble)
at a time.

Every PPUDATA nametable write is also stored into one of two CIRAM shadow buffers, alternating per
render, together with that buffer's per-attribute masks and flags. The freeze, which runs under
`sei`, is then just a buffer flip: no list walking and no copying. The flush reads the buffer that was
active during the period being rendered, outside `sei`, while the ROM writes into the other one.

What goes away:
- `nt_list`: 7,680 bytes in the main code bank, plus the curr/prev pointers and their swap.
- `PPU_VERSION`, `TILE_VERSION0`, `TILE_VERSION1`, the per-frame rolling clear, and the version-stamp
  dedup between the AT and NT passes.
- All copying in `PPUFreezeNametableUpdates`.
- The two-pass flush (AT first, then NT with a skip check).

At most 128 entries are ever queued (64 attribute bytes × 2 CIRAM pages).

## Current design (for reference)

| Step | Where | What |
|---|---|---|
| PPUDATA write | `ppu_regs.s :in_nt` | Converts to a CIRAM address, skips if the value is unchanged, dedups via `TILE_VERSION0 == PPU_VERSION`, then appends to `at_list` (`$3C0`+ slots) or `nt_list` |
| Swap | `scaffold.s NES_RenderFrame` (under `sei`) | Swaps curr/prev for both lists. Non-grid builds force a full refresh if either list is non-empty |
| Freeze | `PPUFreezeNametableUpdates` (under `sei`) | `PPU_CIRAM` → `ATTR_SHADOW` for queued attribute bytes, `PPU_CIRAM` → `TILE_SHADOW` for queued tiles, bumps `PPU_VERSION` |
| Flush | `PPUFlushQueuesAlt` | `RenderPPUAttr` per attribute (EORs against the last applied value in `TILE_SHADOW[attr]`, calls `SyncPPUMetatile` per changed quadrant, stamps `TILE_VERSION1`), then `DrawPPUTile` per `nt_list` entry unless stamped. Marks `tileBitmap` rows |
| Grid | `gridPrepare`, `gridDrawDirty` (list and quad modes) | Counts `prev_nt_list` against `GRID_MAX_BG_TILES`, marks each tile's cell. Metatiles come via `gridRecordMetatile` (called from `RefreshMetatile`) |

`ppu_queues2.s` is an earlier, unfinished stab at the same idea (`ciram_attr_index`/`ciram_attr_bits`).
It doesn't assemble and no game includes it. Delete it as part of this work.

## Mask layout

One 16-bit mask per attribute byte, stored as two independent bytes so the 8-bit write path can set
a bit with a single `ora`/`sta`:

```
mask = HI:LO
LO byte  = attribute quadrants 0,1 (top-left, top-right metatile)    = tile rows 0-1 of the group
HI byte  = attribute quadrants 2,3 (bottom-left, bottom-right)       = tile rows 2-3 of the group

nibble q (q = attribute quadrant, same order as the attribute bits 2q..2q+1) = bits 4q..4q+3
inside a nibble:  bit0 = top-left tile (+0)   bit1 = top-right (+1)
                  bit2 = bottom-left (+32)    bit3 = bottom-right (+33)
```

The nibble order follows the attribute byte, so expanding a palette change is a single table lookup
and the drawing loop shifts the mask right one nibble at a time.

Example: the top-left metatile's palette changes, and two tiles on the group's bottom row (columns 1
and 2) are written:
- palette: quadrant 0 → `$000F`
- column 1, row 3 is the bottom-right tile of quadrant 2 → bit 3 of nibble 2 → `$0800`
- column 2, row 3 is the bottom-left tile of quadrant 3 → bit 2 of nibble 3 → `$4000`
- merged mask = `$480F`

Attribute bytes `$38-$3F` of each page cover rows 28-31. Rows 30-31 are the attribute area itself,
so their HI byte is never set by tile writes, and the flush clears it before drawing (as `:skip_bot`
does today).

## Shadow buffers (PPU_MEM)

Two buffers, `SB0` at `PPU_MEM+$C800` and `SB1` at `PPU_MEM+$D800`, each 4K. They differ only in the
high address byte, so switching buffers changes one byte per instruction operand.

| Offset in buffer | Indexed by | Contents |
|---|---|---|
| `+$0000` | CIRAM address (`$000-$7FF`) | Bytes written during the buffer's period. Only the positions named by its masks/flags are meaningful; the rest is stale and never read |
| `+$0800` | attribute CIRAM address | Mask LO byte |
| `+$1000` | attribute CIRAM address | Mask HI byte |
| `+$1800` | attribute CIRAM address | Flags: bit 7 = queued on `at_list` this period, bit 0 = the attribute byte itself was written |

The data area never needs clearing. The metadata (masks, flags) is cleared by the flush as it
consumes each queued entry, so a buffer is clean again before it becomes current.

Static lookup tables, built once at `PPUStartUp`:

| Table | Location | Indexed by | Contents |
|---|---|---|---|
| `T2MASK` | `PPU_MEM+$E800` (2K words → 4K, or two byte tables) | tile CIRAM address | Offset of the tile's mask byte within a buffer (`$0800+attr` or `$1000+attr`) |
| `T2BIT` | `PPU_MEM+$F800` (2K bytes) | tile CIRAM address | Bit within that mask byte |

The exact table encoding (word table vs split byte tables) gets settled at implementation; both fit
below `$FF00`. Main bank: `AttrExpand`, 256 words: attribute EOR value → `$F` in each quadrant whose 2
bits differ.

## Selecting the current buffer: patched operands, not D

The write path addresses the current buffer with plain long stores whose operand high byte (`$C8` or
`$D8`) is patched at each flip:

```
gcurTile    stal  PPU_MEM+$C800,x          ; patched: $C8 <-> $D8
gcurMaskL   ldal  PPU_MEM+$C800+$0800,x    ; (one pair per table)
...
```

Compared with `txy` + `sta [ciram_shadow],y`, this needs no direct page switch in PPUDATA_WRITE (which
runs with the NES D), costs `stal` (6) instead of `txy`+`sta [dp],y` (2+7), and the flip patches
about 6 bytes once per render. If the patch sites turn out awkward (for example, local-label scope in
the write routine), the fallback is your D-relative pointer form.

## Write path (`ppu_regs.s :in_nt`)

```
CIRAM value unchanged       -> done (as today)
stal PPU_CIRAM,x                                   (as today)
stal SBcur+data,x                                  (new: shadow copy)
attribute address:
    flags |= $01  (SBcur+$1800,x); if it was 0 -> push attr onto at_list, flags |= $80
tile address:
    Y/X = T2MASK[tile];  mask byte |= T2BIT[tile]
    if flags[attr] == 0 -> push attr onto at_list, flags = $80
```

"Queued this period" is the flag byte in the current buffer, so the `TILE_VERSION0`/`PPU_VERSION`
check and the rolling clear are no longer needed. An attribute byte is queued at most once per period,
whether it was written directly, through any of its 16 tiles, or both.

## Freeze (`PPUFreezeNametableUpdates`, under `sei`)

```
swap at_list curr/prev               (already done by NES_RenderFrame)
flip: patch the write path's operand bytes to the other buffer; remember prev buffer = old current
```

That's all. No loops, no copying.

## Flush (`PPUFlushQueuesAlt`, one pass, interrupts enabled)

Reads only the previous buffer (`SBprev`), which the ROM no longer writes. For each `prev` `at_list`
entry (attribute address X):

```
flags = SBprev.flags[X];  mask = SBprev.maskHI:LO[X]
clear SBprev.flags[X], SBprev.mask[X]                   (buffer clean for its next period)

if flags & $01:  attr = SBprev.data[X]                   (attribute written this period)
else:            attr = TILE_SHADOW[X]                   (tile-only entry: no palette change)
diff = attr EOR TILE_SHADOW[X];  TILE_SHADOW[X] = attr   (TILE_SHADOW[attr] = last applied, as today)

for each set bit in mask:  TILE_SHADOW[tile] = SBprev.data[tile]
                           (done per non-zero nibble with the metatile's 4 offsets)

mask |= AttrExpand[diff];  if attribute index >= $38: mask &= $00FF
for q = 0..3 (mask >>= 4 each step):
    n = mask & $F;  if n == 0: next
    base = metatile base q (metatile_corner + 0/2/64/66);  pal = attribute bits of q
    if n == $F:
        diff bits of q != 0 ? SyncPPUMetatile(base, pal) : RefreshMetatile(base, pal)
    else:
        DrawPPUTile for each set bit at base + {0, 1, 32, 33}
        (partial nibbles only come from tile writes; the palette is unchanged and
         DrawPPUTile reads it from ATTR_SHADOW)
    mark tileBitmap rows (top pair -> row(base), bottom pair -> row(base+32))
    grid builds: record (base, n) for exposure
```

Why this is consistent: a buffer's data is valid exactly at the positions written during its period,
and the masks and flags name exactly those positions. Every other tile and attribute value is
unchanged since the previous render, so `TILE_SHADOW` already holds it. A full-metatile redraw after a
palette change therefore reads correct values for all 4 tiles. A tile written again after the flip
goes into the other buffer and is drawn next render.

`ATTR_SHADOW` at attribute addresses (the old frozen attribute copy) is no longer used. At tile
addresses it still holds each tile's palette select.

Single tile writes (BF star twinkle, DK score digits) take the per-bit path. If profiling shows
two-tile nibbles are common, add specialized `n = $3`/`$C` variants later.

## Grid renderer

- `gridRecordMetatile` takes the nibble. `gmtList` entries become (CIRAM base, nibble), and the
  quad/list `gridDrawDirty` marks only the cells of set bits.
- Delete the `prev_nt_list` loops from `gridDrawDirty` (`ppu_grid.s`, `ppu_grid_quads.s`) and the
  `GRID_MAX_BG_TILES` check from `gridPrepare`. The limit becomes `GRID_MAX_METATILES` (raise it from
  32 to 64), with `gmtOverflow` → full render as today.
- The "background tile cells" statistics merge into the metatile counters.

## Scaffold and other edits

- `NES_RenderFrame`: swap only the `at_list` pointers. Non-grid force-refresh checks only `at_list`.
  Drop the `PPU_VERSION` → `_ppuversion` copy.
- Remove the rolling `TILE_VERSION0/1` clear and the `PPU_CLEAR_ADDR` bookkeeping.
- Debug display (`DrawWord` of the four queue sizes): show the `at_list` sizes only.
- `RenderPPUAttr` and its `TILE_VERSION1` stamps are folded into the new flush, then deleted.
  `DrawPPUAttribute`/`_DrawPPUAttribute` aren't used by the queues; leave them alone.
- `PPUResetQueues`: drop the NT pointers. Zero both buffers' metadata and set the write path to `SB0`.
- `CoreImpl.s` startup: drop the `PPU_VERSION` initialisation.
- Delete `ppu_queues2.s`. Update `CLAUDE.md`/plan docs that mention `nt_list`.

Every game includes `ppu_queues.s`, so the change applies everywhere: BF, DK, Excitebike, Ice
Climber, Lights Out, Mario Bros, SMB, Wumpus, Zelda.

## Implementation order

1. Buffers, `T2MASK`/`T2BIT` generation at start-up, `AttrExpand` as static data.
2. Write path with patchable operands, plus the flip in `PPUFreezeNametableUpdates`.
3. Flush rewrite (non-grid behaviour first). Build every game.
4. Grid: nibble-aware `gridRecordMetatile`, removal of the `nt_list` paths. Build BF/DK.
5. Remove the version tables and rolling clear, scaffold cleanup, delete `ppu_queues2.s`, update docs.

## Verification

- Build all games.
- Pixel comparison on the deterministic demos (BF, DK with `NO_INTERRUPTS 1`): reintroduce a frame
  hash of the `$E1` playfield in a throw-away build only (not committed) and compare against the
  current code over the first 1,500 frames. BF covers single-tile writes (stars) and attribute
  changes (cloud flash); DK covers score digits.
- SMB and Zelda: run in the emulator and check scrolling column writes and room transitions (heavy
  nametable writes, up to 128 queued attributes with full masks in one frame).
- Benchmark BF and DK (`frameCount` 2000→4000) before and after.

## Risks

- **Bit-layout bugs** show up as wrong or missing tiles at group edges. The pixel hash catches them
  on BF/DK. SMB/Zelda need a visual pass.
- **Patch sites:** forgetting one store when flipping would split writes across both buffers. Keep
  every patched operand in one labelled block with a single flip routine.
- **Writes outside PPUDATA_WRITE:** code that writes `PPU_CIRAM` directly (nametable init, mirroring
  changes) doesn't touch the buffers. It already relies on a full refresh from `TILE_SHADOW`, as
  today, so nothing changes, but each such site gets audited.
- **Write-path cost:** one extra `stal` plus the mask and flag update per tile write. Offset by
  dropping the `nt_list` append and the version check.

## Projected improvements

These are hand-counted cycle estimates from the current code paths, not measurements. Benchmarks
before and after (step 6 of verification) will replace them.

| Area | Today | Redesign | Expected change |
|---|---|---|---|
| Freeze under `sei` | ~29 cycles per queued tile + ~20 per queued attribute, e.g. ~56k cycles for a full-screen rewrite (1,920 tiles) | Constant: list swap + ~6 operand patches, ~60 cycles | Interrupt-off time no longer grows with the number of writes. Small on BF/DK (a few hundred cycles), large on heavy frames (SMB columns, Zelda rooms, game start) |
| PPUDATA tile write (in NMI) | ~55 cycles after the CIRAM store (version check, list/type test, `nt_list` append) | ~50: shadow store, mask OR, flag test; +~25 the first time an attribute group is touched in a period | About neutral |
| Flush, scattered single tiles | ~50 cycles of bookkeeping per tile (row lookup, version check) around `DrawPPUTile` | ~80 per attribute entry + ~20 per set bit around `DrawPPUTile` | About neutral. Slightly worse when every tile sits in a different 4x4 group, slightly better when tiles share a group |
| Flush, dense writes (full metatiles) | 4 × `DrawPPUTile` per metatile; attribute + tile overlap needs version stamps (4 `stal` per metatile) and a skip check per tile | One batched `RefreshMetatile` per metatile (shared palette/bank setup), no stamps, no skip checks | ~15-25 cycles saved per tile: ~30-45k cycles on a full-screen rewrite |
| Grid exposure of tile writes | `gridCiramToCell` (with its modulo loops, ~100+ cycles) per tile | Once per touched metatile, then constant offsets per set bit | Saves ~100 cycles for each extra tile in the same metatile; same for isolated tiles |
| Per-frame fixed cost | Rolling `TILE_VERSION0/1` clear (~50 cycles), `nt_list` swap | Gone | ~70 cycles per render |
| Main code bank | `nt_list` 7,680 bytes | Gone | 7.5K freed in the tightest bank (the compose experiment ran into the 64K limit) |
| PPU_MEM | `TILE_VERSION0/1` (8K) | Buffers (8K) + lookup tables (~6K) in the free `$C800-$FEFF` range | `$9000-$AFFF` freed for other uses |

Expected overall effect:
- **BF / DK (light, scattered updates):** roughly 1-2k cycles per frame, about 1-3% of the ~57k-cycle
  grid frame. The gains are mainly in interrupt latency and simplicity, not throughput.
- **SMB scrolling, Zelda room transitions, startup and screen changes (heavy writes):** freeze time
  under `sei` drops from O(writes) to O(1), and dense metatile writes are drawn batched. Those frames
  should speed up noticeably (tens of thousands of cycles on full-screen rewrites). SMB's column
  writes produce vertical tile pairs (nibbles `$5`/`$A`), which take the per-bit path at first.
  Specialized pair variants would be the follow-up if those frames matter.
- **Code size and complexity:** one queue instead of two, no version tables, and a flush that is a
  single loop with bit operations.

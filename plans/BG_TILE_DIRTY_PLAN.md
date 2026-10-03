# Grid-Based Dirty Rendering (BG tile updates without full refresh)

**Status (2026-09-30):** Implemented behind `GRID_DIRTY_RENDERING` and enabled for
Donkey Kong and Balloon Fight. Verified visually by the user in both demo loops:
sprites, score, bonus timer, DK's animation, BF's star twinkle and cloud flash all
correct, no garbage left behind. BF sprites wrap around the screen edges with no
visible clipping problems. Attribute updates (v2) are tracked per metatile, so the
only remaining full renders are scroll / refresh / palette dirty bits and the
background being disabled.

## Measurements

All runs are demo loops with `NO_INTERRUPTS 1` (every NES frame is rendered),
emulator at max speed, counters read from the `GRIDSTAT` block. Cycle costs are
per-operation estimates, not measurements.

| | DK | BF, twinkle off | BF, twinkle on | BF, twinkle + AT support |
|---|---|---|---|---|
| Frames | 9,680 | 15,662 | 13,946 | 15,034 |
| Grid-dirty frames | 99.7% | 98.5% | 98.4% | **99.3%** |
| Full renders | 27 | 241 | 223 | **99** |
| ...attribute fallbacks | 0 | 142 | 142 | **0** |
| ...background off | 3 | 11 | 9 | 11 |
| ...scroll / refresh / palette bits | 24 | 88 | 72 | 88 |
| Frames with a visible NT update | (not tracked) | 11 | 10,696 | 11,350 |
| Frames with attribute-driven cells | - | - | - | 77 (616 metatiles) |
| Sprite 8x8 tiles / grid frame | 25.3 | 19.6 | 19.7 | 19.2 |
| Cells erased / exposed / grid frame | 43.5 / 44.4 | 36.4 / 37.7 | 37.3 / 38.7 | 36.6 / 38.0 |
| Sprite cells exposed per sprite tile | 1.75 | 1.92 | 1.92 | ~1.9 |

Takeaways:

- **Sprites alone are roughly break-even with the old block model.** Exposes are
  4-12% fewer than its ~2 shadowed copies per sprite tile (DK 1.75 cells/tile,
  BF 1.92 because its 3-sprite enemies sit at unaligned offsets), but erasing
  from the code field does more copies than save+restore did.
- **The win is background updates.** BF's star twinkle touches a visible tile in
  ~78% of demo frames; the old renderer did a full-screen render for each of them,
  the grid pays about one extra cell per frame. BF's cloud flash rewrites 4
  attribute bytes per frame during the blink; with AT support that is ~8
  metatiles (~32 cells) instead of a full render. The user reported a large,
  visible frame-rate improvement for both.

## Problem

Non-scrolling games (Donkey Kong, Balloon Fight, ...) animate background tiles.
Previously *any* queued NT/AT update set `DIRTY_BIT_BG0_REFRESH` (`scaffold.s`,
after the queue swap) and forced a full-screen render, even when only a handful of
tiles changed and the game was otherwise running in the cheap sprite-only dirty
mode.

## Design summary

Three independent decisions:

1. **Erase from the PEA field, not a save stack.** When the scroll is
   cell-aligned, every 8x8 screen cell maps to exactly one nametable tile, and the
   PEA operands for that tile *are* its final, palette-swizzled pixels. Erasing a
   cell = copying 16 operand words from the code field to `$01` (shadow off).
   - Removes `saveTileFromScreen8/16`, the 4.3KB save stack, `sprBlockAddr`
     sizing, and the LIFO restore order (suspected cause of sprite draw-order
     "fighting").
   - **Background tile updates become free to integrate:** `PPUFlushQueuesAlt`
     has already compiled the new tiles into the field, so a changed tile is just
     "mark this cell for erase+expose". No second tile renderer, no palette or
     CHR-RAM duplication, pixel-exact with the full renderer by construction.
2. **Screen-aligned 8x8 grid for erase/expose bookkeeping.** The primitive is
   the 8x8 copy. A grid collapses "expose old sprite block" + "expose new sprite
   block" into one cell when a sprite is stationary/slow, merges overlapping
   sprites and BG tiles into shared cells, and makes clipping a bounds check at
   mark time (cells are on-screen by construction).
   - Cost: an unaligned 8x8 sprite touches up to 4 cells (16x16: 9 cells vs 4
     blocks). Measured at 1.75-1.92 cells per sprite tile (see Measurements).
3. **Sprites are drawn with shadowing off.** Pixels that overrun the playfield
   (x in [125,127] bytes) only land in the never-exposed `$01` border, so the
   draw needs no clipping; only expose does, and the grid handles that.

There are only two render modes: **full** and **grid-dirty**. DirtyState 1
(line-based erase after a full frame) is no longer needed because PEA erase has
no prior state requirement; it only needs last frame's sprite cell list, which
the full renderer also records.

## Frame pipeline (grid-dirty)

```
mark  prev-frame sprite cells (list S_prev)          -> G/L
mark  changed BG cells (prev_nt_list -> cell)         -> G/L
mark  4 cells per AT-redrawn metatile (gmtList)       -> G/L
shadow off
erase every cell in L from the PEA field
draw  sprites; each marks its cells                   -> G/L and S_cur
shadow on
expose every cell in L
clear G via L; swap S lists; clear gmtList
```

- `G` : 32x25 word grid; bit0 = in L (erase/expose list), bit1 = in S_cur.
- `L` : list of cell indices (x2) touched this frame (max 800, dedup by G).
- `S_cur/S_prev` : double-buffered sprite cell lists.
- `gmtList` : CIRAM addresses of metatiles redrawn by attribute updates this frame
  (max `GRID_MAX_METATILES` = 32).

Invariant after every frame (full or dirty): `$01` playfield = background +
current sprites, and `S_prev` = cells covered by those sprites.

## Eligibility (else full render)

- No `DIRTY_BIT_BG0_X/Y/REFRESH`, `disableDirtyRendering == 0`.
- Background enabled (`CTRL_BKGND_ENABLE`), else the PEA field doesn't match the
  blank screen.
- Cell-aligned scroll: `StartX & 3 == 0` and `(StartY + y_offset) & 7 == 0`.
- NT update count <= `GRID_MAX_BG_TILES` (per game, default 64).
- Attribute updates redrew <= `GRID_MAX_METATILES` (32) metatiles (`gmtOverflow`
  clear). Whole-screen attribute rewrites (e.g. level loads) still fall back.

`scaffold.s` no longer forces `DIRTY_BIT_BG0_REFRESH` for NT/AT updates when the
grid renderer is enabled; `gridPrepare` decides.

## Attribute updates (v2)

`RenderPPUAttr` diffs each queued attribute byte against its shadow and only calls
`SyncPPUMetatile` for the 16x16 quadrants whose palette bits changed. Under
`GRID_DIRTY_RENDERING`, the `RefreshMetatile` entry (which `SyncPPUMetatile` falls
through into) calls `gridRecordMetatile` to append the metatile's top-left CIRAM
address to `gmtList`. `gridDrawDirty` marks the 4 cells (`+0, +1, +32, +33`)
through the same CIRAM -> cell mapping used for NT updates; off-screen and
attribute-row addresses are rejected there. `gridRecordMetatile` preserves A, X,
Y and P, since it runs in the middle of the 8-bit-A metatile code.

## Cell -> PEA mapping

Cell `(cx, cy)` -> screen line `s = 8*cy`, byte `b = 4*cx`.

- virtual line `vl = (s + y_offset + StartY) mod MaxY`
- line byte `hb = (b + StartX) mod (MaxX/2)`
- Horizontal mirroring: `page = vl / 240`, `row = (vl mod 240) / 8`, `col = hb / 4`
- Vertical mirroring: `page = hb / 128`, `row = vl / 8`, `col = (hb mod 128) / 4`
- `ciram = page*$400 + row*32 + col`; PEA location = `TILE_BANK/TILE_ADDR_HI/LO[ciram]`

Within the tile, line n's left word is the operand at `+4 + n*$200` and the right
word at `+1 + n*$200` (see `CompileTile :word_addr`). The table `cellPea/cellBank`
is rebuilt lazily whenever `(StartX, StartY, BltMirrorP)` differs from the cached
key. BG update -> cell is the inverse mapping (`gridCiramToCell`), computed per
queued CIRAM address.

### Code-field patching

The exit BRA patched by `_BltSetupDirty` overwrites one PEA opcode + operand low
byte per line. Grid-dirty frames never execute PEA lines, so they skip
`_BltSetupDirty`/`_RestoreBG0OpcodesLite` entirely and the field is always
unpatched when it is read.

## Primitives

- `gridEraseList` (full cells): DBR = PEA bank, Y = PEA tile address, X = screen
  address; 16x `lda: off,y` / `stal $01xxxx,x`, unrolled inline in the loop. ~12
  cycles/word, no DP pointer setup. (The first version used `sta [ptr_n],y` with
  16 long pointers in `blttmp..tmp15`; switching saved ~900 cycles per BF demo
  frame: frames 2,000 -> 4,000 went from 130.3M to 128.5M cycles, -1.4%.)
- `gridExposeList`: X = screen address; 16x `ldal $01..,x / stal $01..,x` per cell
  with shadow on.
- `gridMarkSprite`: called from `:setupSprite8/16` in `drawSprites` (replaces the
  save-under step); sets its own DBR because `drawSprites` runs with DBR = tiledata.

## Instrumentation

The `GRIDSTAT` signature in the main bank is followed by 32-bit counters, in order:
dirty frames, full frames, cells erased, cells exposed, sprite 8x8 tiles, visible
NT cells, fallbacks (BG off, attribute overflow, too many NT tiles, unaligned
scroll, scroll/refresh bits - not wired yet), frames with NT updates, AT
metatiles, AT cells, frames with AT cells; then four 16-bit "last frame" values
(erased, exposed, sprite tiles, NT cells). Find it with `find_mem` on the bank from
`get_regs` PB (find_mem takes at most 64KB per call).

## Benchmark: renderers compared (2026-10-01)

Cycles over 2,000 consecutive frames (`frameCount` 2,000 -> 4,000, all frames, full
and dirty) of each game's demo loop, `NO_INTERRUPTS 1`, GSSquared. DK is built with
`SHOW_DEBUG_VARS 1`, BF with 0, so compare within a game, not across.

| Renderer | DK cycles | DK / frame | BF cycles | BF / frame |
|---|---|---|---|---|
| Full render every frame (`ENABLE_DIRTY_RENDERING 0`) | 316.8M | 158.4k | - | - |
| Original dirty renderer (save stack, grid off) | **106.4M** | **53.2k** | 253.6M | 126.8k |
| Full-cell grid (`GRID_QUADS 0`) | 127.0M | 63.5k | - | - |
| Quad grid v6 (`GRID_QUADS 1`) | 113.3M | 56.7k | 115.7M | 57.9k |
| Quad grid v7: new sprites drawn with shadowing on (**rejected**) | 106.6M | 53.3k | 108.6M | 54.3k |
| Per-cell compose v5 (`GRID_COMPOSE 1`, see below) | 101.1M | 50.6k | 137.3M | 68.7k |

(Quad v6 on DK was re-measured with `SHOW_DEBUG_VARS 0` on 2026-10-01: 113.3M, unchanged; the
compose row uses the same build settings.)

v7 tried the original renderer's key trick: draw the new sprites with shadowing
on, after the erase, and expose only the erased quadrants. New sprites then no
longer touch the grid (only their records), which removed the expose nibble,
new-sprite marking and the expose of new-only cells; DK came out level with the
original renderer and BF ~6% faster than v6. **It cannot be used:** sprites are
drawn in reverse priority order so the highest-priority one ends up on top, and
with shadowing on a lower-priority sprite is visible before the higher-priority
one covers it. That is the sprite "fighting" the original renderer suffers from,
and the reason the grid renders fully into `$01` before exposing. So the
original renderer's lead on DK is bought with unstable graphics; v6 (render,
then expose) is the stable configuration. Reverted to v6.

- Both dirty renderers cut DK's frame cost by about two thirds versus full renders.
- On BF the quad grid is 54% faster than the original dirty renderer, because the
  star twinkle (NT updates) and cloud flash (attribute updates) force the original
  renderer into a full render on most frames.
- On DK, where background updates are rare, the original dirty renderer is ~6%
  faster than the quad grid in GSSquared. It draws sprites with shadowing on and
  saves/restores exact sprite blocks, which is cheap when shadowed writes cost no
  more than plain ones (as GSSquared appears to model). On hardware, where
  shadowed writes are slower, that comparison should shift toward the grid, which
  draws with shadowing off and exposes ~30% fewer words. Note also that the
  original renderer has known correctness issues (sprite draw-order fighting, the
  SCB-boundary corruption) and has not been visually re-verified since the
  blitter rework.

## Experiment: per-cell masks (`GRID_CELL_MASKS`, off by default)

Idea: a sprite only covers a prefix, a suffix or all of a cell's lines, and at
most 3 of its 4 bytes, so OR a mask into each cell and copy only the touched
lines/words. Implemented as an 8-bit key per cell (4 line-pair bits, 2 prefix-word
bits, 2 suffix-word bits; closed under ORA). The key indexes precomputed entry
points into unrolled 8-line copy sequences (prefix: lines 7..0, suffix: 0..7,
entered at `start + (8 - n) * block`), so decoding is a single table lookup. A
second `sprMask` array carries the sprite-only masks to the next frame's erase.

Measured on the BF demo (`NO_INTERRUPTS 1`, deterministic), cycles from grid
frame 2,000 to 4,000 using a write breakpoint on `gsDirtyFrames`:

| Variant | Cycles | vs full cells |
|---|---|---|
| Full-cell grid | 130.3M | - |
| v1: line bitmap (8 bits), computed decode | 166.5M | +27.7% |
| v2: 8-bit key, table decode | 144.5M | +10.8% |
| v3: v2 + skip marks that add nothing | 145.2M | +11.4% |

Words copied drop ~40% (erase 602 -> 366, expose 624 -> 384 per grid frame with
line precision). Per-phase profile of a busy frame (3,001, ~47 cells) for v2 vs
full cells: erase -12%, expose -1%, `drawSprites` + marking **+33%**, frame
bookkeeping +9%; net +11.5%. The copy savings are real but too small: a whole
8x8 copy is only ~200-270 cycles here, so the per-sprite marking work (byte
offset, row kind, table lookups, two arrays) and per-cell dispatch cost about as
much as they save. GSSquared does not appear to charge extra for shadowed writes
(expose runs ~14 cycles/word including loop overhead); on real hardware shadowed
writes are slower, which favours masks on the expose side, so this is worth
re-measuring on hardware before it is discarded.

### Quadrant masks (`GRID_QUADS`, off by default)

Coarser follow-up aimed at the marking cost: 4 bits per cell, one per quadrant
of 4 lines x 1 word (TL=1, TR=2, BL=4, BR=8). With `b = x & 3` and `k = y & 7`,
bit 1 of `b` and bit 2 of `k` say which half of the first cell a sprite starts
in, and the rest says how far it reaches into the neighbour, so each corner
cell's quadrants come straight from 32-entry tables indexed by `k*8 + b*2`
(`gridQTL/TR/BL/BR`, plus `gridQFL/FR` for the full middle row of 8x16 sprites).
Marking is one table load + one ORA per cell. Erase / expose are 16 unrolled
routines per pass (one per mask), so a cell is one patched `jsr`.

Bookkeeping trick: the flag word holds the union in the low nibble (what erase
and expose use) and the sprite-only quadrants in the high nibble. Tables return
`v * 17` (both nibbles), so one ORA updates both; a zero high nibble before the
ORA de-duplicates the sprite list; the end of the frame shifts the high nibble
into the saved list. No separate `sprMask` array.

| Variant (BF demo, frames 2,000 -> 4,000) | Cycles | vs full cells |
|---|---|---|
| Quads, `(cell, v)` pairs appended without de-dup | 136.1M | +4.4% |
| Quads, nibble de-dup | 134.4M | **+3.1%** |

Busy frame 3,001 (nibble de-dup vs full cells): erase -17%, expose -5%,
`drawSprites` + marking +11%, frame bookkeeping +10%; net +2.9%. Words copied per
grid frame: erase 586 -> 406 (-31%), expose 607 -> 425 (-30%).

#### Quads v2: padded grid, table-driven marking (`ppu_grid_quads.s`)

Rewrite aimed at the marking and bookkeeping costs:

- Padded grid (pitch 33 cells, pad rows above/below): a sprite's cells are always
  `Y`, `Y+2`, `Y+66`, `Y+68` (+1 row for 8x16), no bounds checks; pad cells have
  no SHR address and are skipped by the passes.
- 256-entry tables indexed by the OAM bytes give the cell offset, `k*8` and `b*2`;
  the quadrant tables give each cell's value. Marking a cell is
  `lda grid+OFF,y / bne / ora table,x / sta grid+OFF,y`, with an append to the
  unique cell list only on a cell's first touch. Two per-sprite tests (`b != 0`,
  `k != 0`) skip neighbours the sprite does not reach.
- Cell word: bits 0-3 = to erase, bits 8-11 = to expose. Each sprite also appends
  a record (cell, table index); the next frame replays the records into the erase
  nibble with the same code (no saved masks, no end-of-frame save).
- Erase copies the low nibble and moves it into the expose nibble; expose copies
  the high nibble and zeroes the cell, which is also the end-of-frame clear.

| Variant (BF demo, frames 2,000 -> 4,000) | Cycles | vs full cells (128.5M) |
|---|---|---|
| Records walked directly by erase/expose | 134.8M | +4.9% |
| Records for replay + unique cell list | 128.3M | -0.2% |
| v3: 8-bit coordinate setup, DP list pointer, inlined passes, pre-shifted nibbles | 123.1M | -4.2% |
| v4: v3 + code field bank switched only on change, `jmp` copy dispatch | 120.5M | -6.2% |
| v5: v4 + cell list and sprite records as code arrays | 118.6M | -7.7% |
| **v6: cleanup pass (see below)** | **115.1M** | **-10.5%** |

v6 changes:

- `gridMarkSprite8` / `gridMarkSprite16` entry points (called from
  `:setupSprite8/16`), so the sprite size is baked in: no per-sprite size test,
  `gqH`/`gqRepOp` variables or tall/short dispatch, and the record's call target
  is an immediate. The list-mode implementations get two-line stubs.
- Neighbour tests use short `beq` branches instead of `bne *+5 / brl`.
- No erase-bit test in the erase handler: every entry in the erase range was
  appended by a replay or background mark, so it always has erase bits.
- Expose runs with DBR = `$01`; the expose routines take the SHR address in Y
  (`lda: off,y / sta: off,y`), which frees X for `jmp (gridXQTbl,x)` instead of
  loading and patching the routine address. `gqRunCells` takes the DBR to run with.
- Per-cell erase/expose counters are behind `GRID_CELL_STATS` (default 0, ~7
  cycles per cell per pass); with it off, `gsErased`/`gsExposed` stay 0.

Part of the v6 gain (~0.4%) is the per-cell counters no longer running; the
earlier quad rows included them.

Page-aligning the byte tables read with 8-bit index registers (`gridRowLo/Hi`,
`gridKIdx`, `gridColOff`, `gridBIdx`, and `OAM_COPY` when the grid is enabled)
removes the conditional page-crossing cycle: 115.09M -> 114.93M (-0.14%, ~78
cycles per frame).

v5 ("lists are code"): the cells touched in a frame are an array of
`ldy #cell / jsr gqCellOp` entries, prefilled at startup; a cell's first touch
only stores its index into the next entry's operand (`sta (GridLPtr)`, pointer
+6). A pass patches `gqCellOp` (a single `jmp`) to its handler (erase, expose or
clear), pokes an `rts` over the first unused entry, calls the array and restores
the opcode. The copy routines return straight into the array. Sprite records are
`ldx #index / ldy #cell / jsr gqRep8|gqRep16` entries written when the sprite is
drawn, so replaying the previous frame is a single `jsr` with the 8x8/8x16 choice
already baked into the call. The arrays are sized for the worst case (960 cells,
2 x 65 records), which leaves DK's main segment ending at `$FB19`; shrinking the
cell array to a realistic bound (with a fallback) would recover space if needed.

v4: the erase loop keeps DBR on the code field bank and only reloads it when a
cell's bank differs from the previous cell's (cells change bank only at code field
row 120). Everything else the loop touches uses long addressing or DP scratch
(`tmp2-7`: list offset, end, current bank, cell value, SHR address, count). The
patched `jsr` into the 16 copy routines became a `jmp`, and each routine ends with
`jmp gqELoop` / `jmp gqXLoop`, saving the `jsr`/`rts` pair per cell.

v3 details (same cell counts as v2, only cheaper code):

- `gridMarkSprite` does its coordinate math in 8-bit mode: `lda OAM_COPY,x` /
  `ldy OAM_COPY+3,x` / `tax` index byte tables directly (row offset split into
  low/high bytes and joined with one `adc`; `lda gridKIdx,x / ora gridBIdx,y /
  tax` is the quadrant-table index). No `and #$FF / asl / tay`.
- The quadrant table values double as the "reaches the next column / row" tests
  (`lda gqHTR,x / beq`), so no per-sprite `b`/`k` variables; replay recovers the
  table index from a record with `and #$3E`.
- First-touch append is `sta (GridLPtr) / inc GridLPtr` x2 (`GridLPtr` = DP 82,
  previously unallocated), instead of saving/restoring X around an indexed store.
- Erase and expose are inlined into their loops (no `phx/jsr/rts/plx` per cell),
  walking the list by address with `ldy: $0000,x`.
- Erase nibble at bits 1-4 and expose nibble at bits 9-12, so `and #$1E` /
  `and #$1E00 + xba` give `mask * 2` for the dispatch tables directly.

Walking the records directly was slow: expose visited every old and new record's
4-6 cells (~280 visits for ~48 cells). With the unique list the passes see each
cell once, and the cell counts match the full-cell grid (37.5 erased / 38.8
exposed per frame). This is the first mask variant at parity or better in
GSSquared, while copying ~30% fewer words; on hardware with slower shadowed writes
it should come out ahead.

Assessment of the earlier quadrant version: within ~3% of full cells in GSSquared. About 180 fewer shadowed words are exposed per frame;
if real hardware charges a few extra cycles per shadowed write (GSSquared does
not appear to), that alone is ~1k cycles/frame and would roughly close the gap.
Worth measuring on hardware. Remaining overhead is per-sprite setup in
`gridMarkSprite` (recomputing x/y and the table index, ~3 `jsr`s) and the
end-of-frame nibble save; both are candidates if it is pursued further.

## Experiment: per-cell composition (`GRID_COMPOSE`, off by default)

**Status: reverted (2026-10-01) as too complex for the gain.** The code is not in the tree; these
notes record the design and results. It lived in `src/ppu/ppu_grid_compose.s` (generated by a node
script) and was selected with `GRID_QUADS 0` / `GRID_COMPOSE 1` in `ppu_grid.s`, which also held the
`GRID_VERIFY` frame-hash support described below (also reverted).

Goal: get v7's speed without its sprite fighting. Every damaged 8x8 cell is built in a direct page
buffer -- background words from the code field, then that cell's sprites bottom-most first -- and
written to the screen once with shadowing on, so a cell goes from its old to its final contents in
one step. No staging in `$01`, no separate erase/expose passes.

### Design (v5)

- **Sprite seam (one pass, top-most sprite first).** For every visible sprite: cell + `k*8+b*2`
  index from the 8-bit coordinate tables (as in quads), a damage record for the next frame, the
  pixel cache, and one *item* per cell it covers. This is the single place where per-sprite
  parameters are derived from the OAM bytes.
- **Unchanged-sprite test.** If the sprite's 4 OAM bytes equal the previous frame's in the same slot
  (`gcPrevOAM`), it dirties nothing: its previous cells need no damage and its items only matter if
  something else dirtied the cell. Cells touched only by unchanged sprites are skipped entirely.
  `gcPrevOAM` is refreshed by full renders, invalidated past the sprite count, and reset when the
  sprite pattern table changes.
- **Pixel cache.** Per OAM slot, 4 ways (round-robin) of 64 bytes: per line the swizzled data words
  and the masks, flips applied (D0 D1 M0 M1). Keyed by tile | attributes (unused attribute bits
  masked, so `$FFFF` = empty). Filled with the stack-push trick into a bank 0 staging block, then
  MVN'd into a 64K bank allocated at start-up. Slots are per sprite, so an entry can never be
  replaced by another sprite within a frame (a shared tile cache was tried and broke exactly that
  way: the two BF players use the same tiles with different palettes). BF: ~1 fill per frame.
- **Items are code.** Each sprite owns 4 nine-byte records `ldx #X / ldy #Y / jmp sequence`
  (X = buffer offset, Y = cache address, both pre-biased for vertical clipping; the sequence is
  entered part way through an unrolled 8-line routine). The cell word is `$8000 + items*$800`
  (+ `$4000` when the cell must be recomposed), so `cell + word` addresses the next free item slot
  in the cache bank (`$8000 + i*$800 + cell`) with no other bookkeeping. Up to 7 items per cell;
  the bottom-most extras are dropped and counted in `gcOverflow` (0 on the BF and DK demos).
- **Compose.** Per listed cell: skip if clean; background-only cells copy code field -> screen
  directly; otherwise 16 loads into the buffer, `jmp (gcNDisp,x)` into an unrolled chain that calls
  the cell's items bottom-most first, 16 shadowed stores. Behind-background sprites use a nibble
  zero-mask table.
- Falls back to a full render for 8x16 sprites or more than `GC_MAXSPR` (40) sprites.

### Verification

`GRID_VERIFY 1` hashes the `$E1` playfield after every frame (`gsHash`, plus a per-frame log at
`PPU_MEM+$F000` and per-line hashes of frame `GV_FRAME`), so renderers can be compared on the
deterministic demo. Compose v5 is **pixel-identical to quads v6** on both games over 1,500 frames
(BF `$0344C1B5`, DK `$03197CA8`).

Bugs found this way along the way: `pea #^tiledata / plb / plb` leaves DBR = $00 (the second PLB
pulls the high byte); initial all-zero cache keys matched tile 0 / attribute 0 so a never-filled
slot was used; the item count mask picked up the dirty bit.

### Iterations (BF, frameCount 2000 -> 4000)

| Version | BF cycles | Change |
|---|---|---|
| v1: pool of (routine, X, Y) items, per-slot cache, `jsr` damage marking | 159.3M | |
| v2: one sprite pass, item slots at constant offsets, items as code | 139.7M | front end 58.6M -> 43.5M |
| v3: 4-way per-slot cache in its own bank | 137.9M | fills 11 -> 2 per frame |
| v4: unchanged-sprite test | 136.8M | cells composed 40.3 -> 34.6 per frame |
| v5: 7 items per cell (slots moved to the cache bank) | 137.3M | needed for DK (Kong's sprite block + one more = 5 per cell) |

Baseline with dirty frames doing nothing: 38.3M, so the compose renderer itself costs ~99M on BF
versus ~77M for quads. Profile of v2: front end ~22k cycles/frame (21 sprites), per-cell work
~29k (40 cells, ~725 cycles each).

### Why it wins on DK and loses on BF

- Per affected cell, compose does a full 16-word load + 16-word store plus read-modify-write
  sprite items (22 cycles per word: `lda dp,x / and abs,y / ora abs,y / sta dp,x`). Quads copies
  only the dirty quadrants and draws sprites with **compiled** code, which is much cheaper per word
  (transparent words cost nothing, opaque ones are immediate stores). On BF almost every sprite
  moves every frame, so that per-cell cost dominates: compose is 19% slower.
- On DK most sprites (Kong, Pauline, static items) do not change from frame to frame. The
  unchanged-sprite test skips their cells outright, while quads still erases, redraws and exposes
  them: compose is 11% faster, with the same pixels.

### Possible next steps

- Compile cache entries into item code (per way: BOTH/W0/W1 variants with per-line entry points;
  skip transparent words, immediate stores for opaque ones). Fills are now rare enough (~1 per
  frame) to afford compiling; this attacks the largest remaining cost on BF.
- Track quadrants per cell (as quads does) so only the touched words are loaded/stored.
- The unchanged-sprite test is renderer-independent: quads could use it too (skip erase/redraw/
  expose for sprites whose OAM bytes did not change and whose cells nothing else touched), which
  would likely give quads DK's gain without compose's per-cell cost on BF.
- CHR-RAM games would need cache invalidation on sprite tile writes (DK and BF are CHR-ROM).

## Unchanged-sprite skip in quad mode (`GRID_SPRITE_SKIP`)

Added 2026-10-01 in `ppu_grid_quads.s`; `drawSprites` checks `gqSkip`. 8x8 sprites only (an 8x16 frame,
or the frame after one, doesn't skip).

- A sprite whose 4 OAM bytes match the previous frame's at the same index is **unchanged**. Its record
  from the previous frame is turned into a no-op, so its old position isn't erased.
- **Cascade.** Changed sprites' new positions are marked in the expose nibble, for detection only.
  An unchanged sprite with a quadrant in the erase set, or under a changed sprite's new position, is
  redrawn, and its quadrants join the erase set. This repeats until nothing new joins.
- Unchanged sprites outside the cascade are only recorded (`gridRecordSprite8`); they aren't drawn.
  Every drawn sprite has all of its quadrants erased first, so draw order is preserved.
- Frames where no sprite is unchanged skip the cascade and the flag clear entirely.
- Per-sprite state is packed into one 256-byte array (cell, table index, skip flag); DK's main bank had
  no room for separate arrays.
- **Pixel-identical** to quads without the skip on BF and DK (frame hashes over 1,500 frames).

| frameCount 2000 → 4000 | Without | With |
|---|---|---|
| BF | 115.86M | 117.75M (+1.6%) |
| DK | 113.01M | 85.36M (**−24.5%**) |

The first version also erased changed sprites' new positions and did all the per-sprite work up front:
BF +6%, DK −25%. Moving that work behind the "any unchanged sprite?" test recovered most of BF's loss.
BF's demo has few unchanged sprites, so the cascade marking (~110 cycles per changed sprite) on frames
with only a few skips costs more than it saves.

## Follow-ups

- Wire `gsFbScroll` (split the remaining full renders by X/Y scroll, refresh,
  palette change) to see what is left to attack.
- Remove the legacy DirtyState 1/2 code once all dirty games use the grid.
- Unaligned vertical scroll (cell spans two tile rows; per-line PEA bases).
- Delete `clipBuffer`/`sprTmp4` x-clip for grid games (unneeded with shadow-off
  draws) once verified.
- Other dirty-rendering games (Ice Climber, Mario Bros, Lights Out) still need
  the build migration DK/BF went through before the grid can be tried.

## Fixes made along the way

Build migration (tile conversion moved out of the engine; see `b72d13a`):

- `src/ppu/_module.txt`: `ppu_namestable2.s` typo -> `ppu_nametable2.s`.
- DK and BF: `build.js` (parses `chr.s` -> `tiledata.bin`), local `TileData.s`
  (`putbin tiledata.bin`), `ROM_CompileBackgroundTiles`/`ROM_CompileSpriteTiles`
  after `NES_StartUp`, `PPU_CIRAM`/`PALETTE_RAM` layout in `PPU.s`, local
  `HORIZONTAL/VERTICAL_MIRRORING` equates for `rom_inject.s`, NMI handler
  RTS -> RTL (romxfer now uses JSL), `package.json` scripts.
- BF only: `mput ../../rom` + `misc/io.s`, full P1/P2 config blocks and
  save/pref filenames, ROM filler `$BA00` -> `$B900` (injected code had grown past
  `$C000`), page-aligned swizzle tables, `star_patch` default back to `beq`.

Engine bug:

- `ppu.s :drawSprite8x8` read `spadr_hi/lo` with absolute addressing while DBR is
  the tiledata bank, so it loaded tile bytes instead of the sprite pattern-table
  selection. Harmless in DK (bytes were 0); in BF it produced `sprTmp6 = $FF00`,
  garbled sprites, and a JML through an out-of-range `spr_comp_tbl` entry into
  `$xx:00F4`. Fixed with `ldal`.

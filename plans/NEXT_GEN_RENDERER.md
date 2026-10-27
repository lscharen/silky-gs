# Next-generation renderer: threaded code blocks

## Status (2026-10-27): design study, nothing implemented

This is a design study, written up from a review of the sprite hot path and a series of follow-up ideas. The
first part records what the sprite work found and measured (it is on the `8-by-16-sprite-optimizations`
branch). The second part looks at smaller ideas that were costed and set aside. The third part is the
threaded renderer: a different architecture that would replace both the PEA field blit and the dirty grid
with one mechanism. Nothing in the third part has been built or measured; the numbers there are estimates
from instruction counts and have to be checked (see "What to measure first").

Cycle counts assume a 65816 at 2.8MHz, 16-bit registers unless stated, and a page-aligned direct page.

## Part 1: the sprite hot path (done)

The path from the OAM scan to the compiled sprite was reviewed for Zelda and Contra, which both draw many
8x16 sprites. Before the changes, an 8x16 sprite on the compiled fast path paid about 270 cycles of overhead
around 330-530 cycles of pixel writes:

| Stage | ~cycles |
|---|---|
| `SPRITE_PRE_DRAW` + `sprClipTop` test | 17 |
| `SPR_SETUP` (Mul160 lookup, X to byte, `sprShift`, right clip) | 78 |
| `jsr :drawSprite16` + clip / priority tests | 23 |
| Key build, pair-bit and vertical flip fix-ups | 26 |
| Two lookups, flip / shift ORs, stub check | ~60 |
| `pea sprTramp`, two patches, `jml` | 23 |
| Two returns and the trampoline | 33 |
| Loop step | 11 |

Implemented and measured on the Zelda bench (`scripts/bench-zelda.js --noint`, 3,600 frames; every step
draws the same 7 screens and ends in the same game state as HEAD):

| Build | Cycles | Change |
|---|---|---|
| HEAD 1e1e6a3 | 227,094,262 | |
| Fused 8x16 sprites (`SPR_TALL`) | 222,388,354 | -4.71M (-2.07%) |
| + byte writes in compiled sprites | 220,859,644 | -1.53M (-0.69%) |
| + sprite setup merged into the grid mark routines | 219,186,494 | -1.67M (-0.76%) |
| + faster sprite code emitter | 218,625,738 | -0.56M (-0.26%) |
| + faster pixel shifting in the compiler | 218,558,670 | -0.07M (-0.03%) |
| Total | | -8.54M (-3.76%) |

SMB (attract demo, frames 300-2100, `SPR_TALL 0`): 190,308,083 -> 190,174,271 (-0.07%), 6 screen hashes
identical. SMB is bound by scrolling and NES logic and draws few sprites.

- **Fused 8x16 sprites.** A game with `SPR_TALL equ 1` compiles an 8x16 sprite as one routine keyed by the
  OAM tile byte (`SPR16_COMP_TBL`, PPU_MEM `$9000`; key offsets from `SPR16_KEY`). One lookup and one `jml`
  replace the two half lookups and the trampoline. Slots are twice as big (4KB with `SPR_PIXEL_SHIFT`, 16 per
  bank) so the cache holds as many tiles as before; the shifted variants start as stubs (`EmitTallStubs`,
  `SprQueueTall`). 8x8 and 8x16 keys share the slot ring, so a sprite-size switch needs no flush.
- **Byte writes.** A word with one fully transparent byte is written as the other byte with 8-bit A
  (5-cycle store for an opaque byte, 14-cycle read-mask-write otherwise, against 18 for the word), in one
  `sep`/`rep` section at the end of the routine, when that saves more than the mode switches.
- **Setup in the grid mark.** In dirty builds `gridMarkSprite8/16` set `sprTmp1`/`sprShift`/`sprTmp4`
  themselves, from the coordinates they already load in 8-bit mode with DBR = the engine bank
  (`GQ_SPR_SETUP`, byte tables `gqSprYLo/Hi`, `gqSprXS/XC`). `OAM_COPY` keeps its 4-byte layout:
  precomputing in the OAM scan was rejected because every derived value is used once, so a store and a
  reload would cost more than computing it where it is used.
- **The compiler.** Compiling costs real time: 228 compile calls in the bench took 4.68M cycles (a plain
  8x16 pair ~16K, a shifted pair ~30K). `EmitSpriteWords` now writes with DBR = the compile bank (`sta n,y`
  at fixed offsets, long reads of its tables), decides on byte writes from the short byte list instead of a
  pre-pass, and groups values with the value compared first; `ShiftSpriteWords` shifts values and masks in
  one pass with unaligned loads. Compiling now costs 4.04M (-14%). What is left is mostly the output itself:
  ~12 bytes of code per masked word.

Not yet tested: Contra (its PPU / APU shims are not ported to the new `rom_inject.s` scheme, so it does not
build at HEAD), and Zelda's door-band clipping path (the bench route never enters a dungeon).

## Part 2: ideas costed and set aside

- **Precompute in the OAM scan.** Each per-sprite value is used once per render, and pass 2 of the scan runs
  in the same mode as the consumer (8-bit index, DBR = engine bank), so a store and a reload cost more than
  the computation. Merging the setup into the mark routine was the version that paid.
- **Chain sprites through the stack** (`ply` / `rtl` from a list pushed just before drawing). Draw-phase
  overhead would drop to ~11 cycles a sprite, but most of its gain overlapped the fused 8x16 change and the
  setup merge. Still the cheapest way to run a short, per-frame draw list, because a list built just before
  it runs is not hurt by interrupts writing below S.
- **Turn `at_list` into a code array** (`ldy #idx / jsr`). The list walk costs ~30 cycles per queued group
  against ~15 for the array, but a render queues only a handful of groups and each one costs hundreds to
  thousands of cycles to draw. Estimated 0.1-0.5M on the bench. The per-group body (~35 cycles per written
  tile before it is drawn, with a `sep`/`rep` per tile) is the better target if nametable updates turn out
  to matter.
- **Replace `at_list` with a dirty bitmap** (128 bits). About the same speed for 3-10 groups (~80 cycles to
  scan 8 words + ~25 per set bit, against ~30 per entry), better only when many groups are dirty. Simpler:
  `at_list`, `at_count`, the `ntmSiteL` patch site and `NTM_QUEUED` go away. A low/high range scan instead of
  a bitmap is worse: two distant groups (status bar and play field) cost a scan of the whole range.
- **Move `gqGrid` to bank 0.** In native mode `dp,x` with a 16-bit index reaches anywhere in bank 0 from D,
  so a page-aligned `gqGrid` right after the engine direct page could be read as `lda gq,x` (5 cycles)
  instead of `abs,y` (6) in the mark routines and `ldal ,x` (6) in the erase / expose handlers, whatever
  DBR is. Estimated 0.7-1.2M (0.3-0.5%). Needs ~2.2KB of bank 0, cell numbers offset from D in
  `gridRowLo/Hi`, and the generated mark routines (`scripts/gen-grid-marks.js`) indexed by X.
- **TSB / TRB on the grid.** They have no indexed mode, so D would have to point at each cell: the
  `phd`/`tcd`/`pld` setup (~16 cycles a call) eats most of the saving, even with a "touched" bit that lets
  one `tsb` both test for the first touch and set the bits.
- **Write-through erase** and **segmented sprite lines** were tried earlier and measured slower (see
  `docs/BENCH_ZELDA.md` and `SEGMENTED_SPRITE_LINES_PLAN.md`).

## Part 3: the threaded renderer

### TL;DR

An estimate, not a measurement: **full-screen (scrolling) renders could be about 20-30% faster** than the
PEA field. Full renders are the pain point: the dirty renderer already gets close to 60fps at 2.8MHz and
is limited by the sprite count, while every scrolling frame is a full render.

- **Where the gain comes from.** A background word written directly to the screen through shadowing would
  take about 3.0 us, against about 4.8 us today for a `pea` into bank $01 plus a `pei` in the slam (Technote
  #70's write timing, below): 35-40% less per word. Building the thread, the cells under sprites (composited
  off screen and exposed, as now) and the reloads between differently colored words bring that down to about
  20-30% for a whole render. Scrolling frames also stop paying for the PEA field's exit patching and
  restoring.
- **What it means for a whole run.** In the Oct 20 Zelda profile, split and full renders took about 40M of
  the bench's cycles; 20-30% of that is 8-12M, about 4-5% of the run. Games that scroll more (SMB) would
  gain more.
- **Dirty renders.** Possibly a small gain. They draw the same cells as the grid does now, but a changed cell
  with no sprite on it (a tile update, or a cell a sprite has just left) is drawn once, directly through
  shadowing, instead of being erased from the PEA field into bank $01 and then exposed (two writes per word).
  Cells under sprites cost the same in both designs, so the gain depends on how many changed cells have no
  sprite. Besides speed: simpler tracking (no `at_list`, no NTM masks, one renderer instead of two) and a
  draw order that can follow the scrolling direction to reduce tearing.
- **It all rests on one number.** The direct write cost has to be measured on hardware first (see "What to
  measure first"). GSSquared's cycle counts may not show the slow-side timing at all.

### The idea

The screen is drawn by executing a list of code blocks threaded through the stack. The list lives in bank 0;
each entry is the arguments a block pulls (for example a screen address in X and a second address in Y)
and the address of the next block, reached with `rtl`:

```
tile:   plx                 ; the screen address
        ply                 ; another address (tile data, a clip amount, ...)
        ...                 ; draw: lda #pixels / sta n,x ...
        rtl                 ; to the next block on the list
```

Blocks are not only tiles. The thread can go through any code:

- compiled background tiles, in variants selected by bits of their address (a clip variant for a tile on a
  playfield edge, a masked variant over a sprite that is behind the background)
- compiled sprites
- shadowing on / shadowing off blocks
- expose blocks, which copy a composited cell from bank $01 to the screen
- an interrupt block every N entries, which moves S to a real stack, does `cli` / `sei` and moves S back, as
  the PEA field does today
- a joystick block, for the paddle probes (`src/core/blitter/JoyProbes.s`)

Nametable writes update the cells' state as they happen; tiles load their palette from their attribute, so
there is no metatile versus single-tile tracking.

There is no PEI slam. Cells without sprites are drawn straight to the screen with shadowing on, and only the
cells under sprites are composited in bank $01 with shadowing off and then exposed.

The goal is to unify the full-screen and the dirty-grid renderers. A frame is just a list of blocks:

- scrolling: every visible cell
- a still screen: the cells that changed and the cells under old and new sprite positions
- splits: the cells of each band

Because the order of the list is free, the screen can be drawn in an order chosen per frame: in vertical
strips while scrolling horizontally and horizontal strips while scrolling vertically (the Rastan approach),
which makes tearing much less visible than today's line-by-line blit.

### Interrupts

`pla` / `plx` / `rtl` move S upward, so the entries already executed lie just below S. An interrupt pushes
there, and the IIgs firmware dispatch pushes much more, so with interrupts enabled a thread that is reused
would be corrupted. The fix is the PEA field's: run the thread with I set, and give interrupts a window in an
interrupt block every N entries. With N = 8 tiles the block costs ~30-50 cycles, ~5 cycles a tile, and the
interrupt latency is at most ~1K cycles (~0.4ms at 2.8MHz), well inside the 240Hz audio period (~4.2ms).
No block may `cli` on its own.

### Speed

Today a background word reaches the screen twice: a `pea` into bank $01 with shadowing off (5 cycles), then
a `pei` slam to $E1 (6 cycles, including the slow 1MHz writes). In the threaded design a cell without sprites
writes each word once, with `sta abs,y` / `sta abs,x` through shadowing (~6 cycles including the same slow
writes, plus a share of the loads and ~16 cycles of `plx` / `ply` / `rtl` per tile).

| | Per word | Per frame, besides the words |
|---|---|---|
| PEA field | `pea` 5 + `pei` slam 6 = ~11 | per-line exit patch and restore, entry setup, scrolled-in tiles written into the field |
| Threaded | `sta` ~6-7 + ~1 of dispatch | building the thread |

A scrolling frame also stops paying for the PEA field's patching. For reference, the Oct 20 profile had 376
split renders costing 30.9M, of which 22M was the blit itself, so ~24K per render went to the work around
the blit (patching, setup, sprites, latching). The threaded design should reach at least parity on full
renders and probably beat them, if a shadowed write costs the same inside a `sta abs,y` as inside a `pei`.
That is the number to measure first: GSSquared may not model the slow writes faithfully. Counted in real
time instead of cycles (see "Write timing"), the per-word comparison is about 4.8 us today against 3.0 us
for a direct store.

### Write timing

Writes to the Super Hi-Res screen (and through shadowing into it) go to the 1MHz side of the machine, and
the fast side waits to synchronize with it. Apple IIGS Technical Note #70, "Fast Graphics Hints"
(https://apple2.gs/technotes/tn-iigs-070/), gives the real time per write for a run of writes spaced by the
same number of fast cycles:

| Fast cycles per write (word) | Real time per word |
|---|---|
| 4 to 6 | 3.0 us |
| 7 to 8 | 4.0 us |
| 9 to 11 | 5.0 us |

(For byte writes: 3 to 5 cycles, 2.0 us; 6 to 8, 3.0 us; 9 to 11, 4.0 us.) The technote adds that the first
write of a run takes longer, because the synchronization happens then, and that refresh delays byte writes
more often than word writes, so word writes are preferred.

What follows from it:

- **Instruction cycles stop mattering below 7.** A 5-cycle and a 6-cycle store in a run both take 3.0 us. A
  direct, shadowed `sta abs,y` (6 cycles) costs the same real time as a `pei` (6) or a `pea` (5).
- **The direct write against today's path.** Today a background word costs a `pea` into bank $01 with
  shadowing off (fast RAM, no synchronization: 5 cycles, about 1.8 us at 2.8MHz) plus a `pei` in the slam
  (3.0 us): about 4.8 us. A direct shadowed `sta` costs 3.0 us, about 35-40% less, as long as the stores run
  back to back.
- **Spacing is the constraint.** More than 6 fast cycles between two writes puts the second one in a slower
  bucket. A value change (`lda #` 3 + `sta abs,y` 6 = 9 cycles) costs 5.0 us for that word, so grouping the
  words by value matters more than it does in fast RAM. Background tiles are opaque (NES color 0 is the
  background color), so they need no read-mask-write: only loads and stores. The dispatch between tiles
  (`plx` / `ply` / `rtl`) is a gap before each tile's first write, which pays the synchronization.
- **Direct page stores do not save time on their own.** A 5-cycle `sta dp` falls in the same bucket as the
  6-cycle `sta abs,y`. What D = the screen address would buy is registers: there is no indexed `stx` / `sty`
  for a screen address, but `stx dp` / `sty dp` exist, so X and Y could hold two more pixel values and a tile
  with up to three distinct words would need no reloads between its stores. The cost is the reach:
  non-indexed `sta dp` covers 256 bytes from D, a tile spans 8 lines x 160 bytes, so D has to be re-based
  for every pair of lines (offsets 0-163). A dispatch of `pld` (5) + `rtl` (6) instead of `plx` / `ply` /
  `rtl` (16) gets D from the thread and frees X and Y; with four D values per tile, each `pld` puts a
  10-cycle gap (5.0 us) before the next write, about +6 us on a ~48 us tile, which pays only when the
  reloads it saves are worth more.
- **The composited cells are not affected.** Cells under sprites are drawn with shadowing off, in fast RAM,
  where the instruction cycles are the real cost; their expose copy to the screen is a slow-side run like the
  slam.

These numbers describe the hardware's bus synchronization. GSSquared's cycle counts may not model them, so
the direct write cost has to be measured on hardware (or a cycle-accurate model of the FPI / Mega II
synchronization) before anything is built on it.

### Bookkeeping

**The thread: built each frame, or persistent.**

| | Built each frame | Persistent (nametable-shaped) |
|---|---|---|
| Cell state | a cell table: the block address of each cell; a nametable write is one store | in the thread entries |
| Per-frame cost | ~20-30 cycles an entry: ~16-24K for ~800 cells, proportional to the dirty cells otherwise | skip stubs patched over the unchanged runs (~2 stores a run, restored after); a second copy for the other strip order |
| Interrupt damage | none: the list is discarded after it runs | none while I is set |
| Bank 0 | one ~7-8KB buffer | ~13KB per order (2 nametables x 960 cells x 7 bytes) |

Building each frame is simpler, and it is the only option that makes the draw order a free per-frame
choice. Its cost is about the size of the slam it replaces.

**Nametable writes.** A tile write stores the cell's block address (CIRAM address to cell, tile to block:
two table lookups, ~25-35 cycles, about what today's byte + mask + flag costs) and sets the cell's dirty bit.
An attribute write updates the palette of up to 16 cells (~250 cycles; a full nametable rewrite writes 64 of
them, ~16K). `at_list`, the `NTM` mask / flag double buffers and the metatile cases go away. The dirty bits
need double buffering (or a copy at freeze time) so the NES task's writes do not race the build.

**Scrolling.** Edge cells get their clip variants (~120 patches per scroll change: about 2 columns and 2
rows). Screen addresses come from the build (a built thread computes them; a persistent one would need ~960
rewrites per scroll change or a base added per tile, ~9 cycles). Nametable wrap and mid-screen splits are
just where the build starts and ends each run of cells.

**Sprites.** The cells under old and new sprite positions are the ones the grid marking computes today; they
are drawn with shadowing off, the sprites drawn over them, and the cells exposed. Priority (behind the
background) sprites work as they do now in those cells, as long as the cells are drawn before their sprites.

**Background palettes.** Compiled tiles have their colors as immediates, so each tile needs a variant per
palette it is shown in. All of them would be 512 tiles x 4 palettes x ~128-200 bytes = 256-400KB; the
practical version is a compile cache keyed by (tile, palette), like the sprite cache, with a bitmap fallback
on a miss. CHR-RAM games already compile background tiles on demand.

### Risks

- **The shadowed write cost.** Everything in "Speed" rests on a direct, shadowed `sta` costing about what the
  slam pays per word. Measure on hardware.
- **Visible tearing.** Cells drawn with shadowing on are drawn while the screen is displayed. Cells under
  sprites cannot flicker (composited off screen, then exposed), but background-only cells can tear while
  scrolling; the strip order is the mitigation and needs judging by eye.
- **Bank 0 space.** One built thread is ~7-8KB; the app already keeps its stacks and direct pages there.
- **Debugging.** A corrupted entry or a stray `cli` is an `rtl` into garbage.
- **Code memory.** Background tile variants (palettes, clip, masked) multiply compiled code; a cache bounds
  it but adds misses.

### What to measure first

1. **The direct write cost:** real time for a compiled 8x8 tile written with shadowing on (16 stores grouped
   by value), against `pea` into bank $01 plus a `pei` slam of the same 16 words, on real hardware. Check the
   technote's buckets on the way: a run of `sta abs,y` against a run of `sta dp`, and the cost of one value
   change in a run.
2. **The PEA side's overhead:** profile SMB's scrolling window with breakpoints around `_BltSetupAlt`, the
   exit restore and the blit, to separate patching from pushing.
3. **The thread build:** a column-major thread for a full SMB scrolling frame, against today's full render.
4. **Tearing:** the strip order on hardware.

If (1) comes out as expected, this is a credible replacement: one rendering path instead of two, much less
tracking, and control over the draw order.

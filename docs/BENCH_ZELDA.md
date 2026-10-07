# Zelda benchmark (GSSquared)

A repeatable cycle-count benchmark for the Zelda port, run in GSSquared through the `gs2-mcp` server.  It plays
a fixed, scripted sequence of controller input and reports the 65816 cycles the runtime needs for it.  It was
written to measure the compiled sprite cache (`src/core/sprites/CompileSprites.s`), but it works for any change
to the sprite, PPU or render code.

## How it works

* `BENCH_MODE equ 1` in `src/games/zelda/src/Main.s` reads the controller from a file instead of the keyboard
  (`rom/rom_input.s`): one byte per NES frame in the A-B-Select-Start-Up-Down-Left-Right layout.  `Main.s` loads
  `zelda.bench` (next to the application) into `ROMBase+$0800` before `BenchStart`, and the run ends in a
  `BenchDone` spin loop after `BENCH_MODE_LEN` frames, before `NES_ShutDown`, so nothing is saved.
* The input index advances once per NES frame when `NO_INTERRUPTS equ 1` (`NES_TriggerNMI`), and once per VBL
  otherwise (`schedTask`).  **Use `NO_INTERRUPTS` for cycle counts.**  With interrupts on, a run is a fixed number
  of VBLs, so its length in cycles is fixed by construction (a faster build just idles more) and the game state
  depends on timing.  With `NO_INTERRUPTS` every NES frame is rendered, the run is deterministic, and the same
  input gives the same game state in every build (the final room and Link's position are checked).  Two runs of the
  same build give identical cycle counts.
* The cycles are the `cycle` field of `get_regs`, read at `BenchStart` and `BenchDone` (execute breakpoints).
  The window includes the ROM cold boot and everything the game does for the frames; it excludes the runtime's
  start-up and the GS/OS launch.
* `gs2-bench-run.js --shots a,b,c` hashes the SHR screen at the start of those frames, so two builds can be checked
  for drawing the same pictures (a build that never compiles, `SPR_COMPILE_PER_RENDER equ 0`, is the reference).

## Files

| File | Purpose |
|---|---|
| `scripts/bench-zelda-route.js` | makes `zelda.bench` (the input) and `zelda.wram` (a save with a registered name, the wooden sword and 16 hearts) |
| `scripts/bench-zelda.js` | builds a variant (patching `Main.s` for the build only) and installs it as `SYSTEM/Start` on a GS/OS boot image, with `zelda.bench` and `zelda.wram` next to it |
| `scripts/gs2-bench-run.js` | runs one trial through `gs2-mcp` (stdio MCP) and prints a JSON line |
| `scripts/bench-zelda-sweep.js` | builds and runs a grid of `SPR_SLOTS` x `SPR_COMPILE_PER_RENDER` settings |

## Setup

1. A GS/OS boot image (`.po`, ProDOS order) with a `/<volume>/SYSTEM` folder.  GS/OS starts `SYSTEM/Start`, so the
   benchmark boots straight into the application.  Use a copy; the scripts replace `Start`, `zelda.bench` and
   `zelda.wram` in it.
2. A GSSquared config that boots it at maximum speed, e.g. an IIgs ROM 3 config with `speed = "ludicrous"` and
   `[[storage]] slot = 7, drive = 1, image = "<the .po>"`.
3. `GS2_MCP` / `GS2_BIN` environment variables if `gs2-mcp` and GSSquared are not in the default places
   (see the top of `scripts/gs2-bench-run.js`).
4. The save and input:
   `node scripts/bench-zelda-route.js --wram <a zelda.wram of a game with a name and the sword> --out <dir>`

## Running

```
# one build, one trial
node scripts/bench-zelda.js --noint --slots 127 --quota 2 --image boot.po --wram dir/zelda.wram --input dir/zelda.bench --out info.json
node scripts/gs2-bench-run.js --info info.json --config bench.gs2 --label s127q2 --shots 500,800,1200,1700,2300,2900,3500

# a grid (results are appended to the file, one JSON line each)
node scripts/bench-zelda-sweep.js --image boot.po --config bench.gs2 --wram dir/zelda.wram --input dir/zelda.bench \
     --out results.jsonl --slots 127 --quota 1,2
```

A trial takes about 40 seconds.  `gs2-bench-run.js --rooms` also logs the room changes along the route (the stops
make that run's cycle count meaningless).

To compare with a build that does not have the cache, make a worktree of the other commit, copy the `Main.s`
bench changes and the four scripts into it, and use `bench-zelda-sweep.js --plain` there.

## Scope

Keep the runs small: `SPR_COMPILE_PER_RENDER` 1 or 2 at 127 slots, compared with the non-compiled `main` build and with the
best result so far (the table below).  The tables below come from a wider grid that was run once while the design was
chosen, with hit/miss/eviction counters in the code to explain them.  The counters have been removed again.

## Results: compiled sprite cache, first design (2026-10-06)

This is the first design: 1KB slots, each with all four flip variants, at most 63 slots.

Route: east, north, west, south, east from the start screen (rooms `$77 $78 $68 $58 $57 $56`), 3600 frames,
`NO_INTERRUPTS`.  Baseline is `main` (3bf3515, no compiled sprites) with the same bench hooks: **285,469,485
cycles**.  Every run, in every build, ends in the same game state (play mode, room `$57`, Link at 187,189), and
repeated runs of one build give identical cycle counts.

The route draws 85,194 sprite tiles that can use a compiled sprite and uses about 165 distinct ones.

Cycles, and the hit rate from an instrumented build of the same settings:

| Slots | Quota 1 | Quota 2 | Quota 4 | Hit rate (q1 / q2 / q4) |
|---:|---:|---:|---:|---|
| 63 | 263.28M (-7.8%) | **262.77M (-8.0%)** | 262.85M (-7.9%) | 97.8 / 98.9 / 99.2% |
| 48 | 264.70M (-7.3%) | 265.15M (-7.1%) | 265.40M (-7.0%) | 97.0 / 98.2 / 98.7% |
| 32 | 273.10M (-4.3%) | 275.30M (-3.6%) | 279.03M (-2.3%) | 93.0 / 95.0 / 95.4% |
| 24 | 282.84M (-0.9%) | 292.73M (+2.5%) | 301.77M (+5.7%) | 84.8 / 88.1 / 90.2% |
| 16 | 293.64M (+2.9%) | 313.18M (+9.7%) | 343.85M (+20.4%) | 67.3 / 70.2 / 74.0% |
| 8 | not run (the instrumented build was +12.7% / +25.3% / +39.5%) | | | 34.9 / 35.6 / 41.1% |

* The counters (since removed) cost a constant 2.3% in every configuration.
* A least-squares fit of the instrumented runs (R^2 0.999) gives about **407 cycles saved per compiled-sprite
  hit** and about **9,850 cycles per compile**, so a tile has to be drawn about 24 times before it has paid for
  itself.
* With the working set in the cache (48 or more slots), the cache saves 7-8% of all cycles and the quota hardly
  matters.  Below that, evictions make a higher quota worse: more compiles per render means more recompiles of
  tiles that are about to be evicted.  Quota 1 is the best choice for any cache that does not fully fit.
* The 1KB slots are sized for the worst case, so 63 slots is the maximum.  The size of the cache is the limit,
  not the replacement policy: at 63 slots the hit rate is already 98-99%.

## Results: hybrid cache (512 byte slots: tile + vertical flip, normal and H-flipped code)

Same route and baseline (285,469,485 cycles for `main`).  Cycles without the counters; the last column is the first design at the
same quota (with 63 slots for the first four rows and 32 slots for the last two).

| Slots | Quota | Cycles | vs main | First design |
|---:|---:|---:|---:|---:|
| 127 | 1 | 262.78M | -7.9% | 263.28M (-7.8%) |
| 127 | 2 | **262.38M** | **-8.1%** | 262.77M (-8.0%) |
| 64 | 1 | 263.05M | -7.9% | 263.28M (-7.8%) |
| 64 | 2 | 262.68M | -8.0% | 262.77M (-8.0%) |
| 32 | 1 | 270.31M | -5.3% | 273.10M (-4.3%) |
| 32 | 2 | 271.61M | -4.9% | 275.30M (-3.6%) |

* On this route the working set is small (about 150 compiled keys), so the full-size caches are nearly the same.  The
  hybrid gains where the cache is small: 2.8M and 3.7M fewer cycles at 32 slots, because a compile costs about half as much
  (two variants instead of four) and a slot is half the size, so 32 slots cover the same memory as 16 of the first design.
* 64 slots do as well as 127 here, and as well as the first design's 63 slots, which held a quarter as many variants.
* The pictures are identical to a build that never compiles (`gs2-bench-run.js --shots`, SHR hashes at 7 frames).

## Results: hybrid cache, tightened and FIFO

Two later changes, each checked with `--shots` (7/7 screen hashes identical to the build that never compiles) and the same
final game state:

1. A final pass over the code: tail calls (`jmp (abs,x)` for the second variant), a four word preamble, loops that end on
   `bpl`/`bne` instead of a compare, `dec`/`inc` instead of `sec`/`sbc`/`inx`+`txa`, a cheaper invalidation path.
2. A cache hit no longer touches the list: it is a FIFO (new keys go to the head, the oldest is replaced), not an LRU.
   The list update on a hit cost about 100 cycles, which was most of the 8% it saved.

| Slots | Quota | hybrid LRU | + final pass | + FIFO | vs main (285,469,485) |
|---:|---:|---:|---:|---:|---:|
| 127 | 1 | 262.78M | 262.27M | 254.13M | -11.0% |
| 127 | 2 | 262.38M | 261.87M | **253.60M** | **-11.2%** |
| 32 | 1 | 270.31M | 269.78M | 265.64M | -6.9% |
| 32 | 2 | 271.61M | 271.04M | 270.01M | -5.4% |

Best so far: 127 slots, quota 2, **253,604,794 cycles**.

## Results: lower overhead

Each step checked with `--shots` (7/7 screen hashes identical to the build that never compiles) and the same final game state.

1. The CHR-RAM sprite dirty flag is tested inline in `:blitResolvedSprite`, in 16-bit mode, instead of a `jsr` to
   `CheckSprTileDirty` (and its `sep`/`rep`) for every sprite tile drawn; the routine only runs for a dirty tile.
2. The horizontal flip is in the cache key: each variant has its own `SPR_COMP_TBL` entry, so the 10 byte preamble that
   picked one (and the `lda sprTmp2+1` it needed) is gone.  The table is 4KB.
3. The linked list and free stack are replaced by a ring cursor and an owner table (same FIFO replacement), which is what
   made room for the larger table.

| Step | Quota 1 | Quota 2 | vs main (285,469,485) |
|---|---:|---:|---:|
| Before (FIFO list) | 254.13M | 253.60M | -11.2% |
| 1: inline dirty test | 252.76M | 252.24M | -11.6% |
| 2 + 3: flip key, ring | 252.30M | **251.76M** | **-11.8%** |

Best so far: 127 slots, quota 2, **251,764,983 cycles**.

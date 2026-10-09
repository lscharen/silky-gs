# Pre-shifted compiled sprites: 1-pixel horizontal positioning

## Status (2026-10-08): implemented on per-pixel-sprite-caching, awaiting manual testing (Zelda, SMB, DK)

## Problem

A sprite's IIgs screen address is a byte address, and a byte holds two pixels, so sprites are placed at
2-pixel granularity: `SPR_SETUP` (`src/ppu/ppu.s`) computes `(x + sprXPar) >> 1` and drops the parity.

Zelda now often renders every NES frame (60fps).  An enemy moving vertically at 1px/frame moves on screen
every frame.  When it turns and moves horizontally at 1px/frame, it only moves on screen every other frame,
so it looks like it drops to 30fps.  That change in apparent motion is noticeable.

## Goal

Draw compiled sprites at single-pixel horizontal positions, with no new cost on the dispatch path beyond a
few cycles per sprite.

Out of scope, by design:

* **Priority (behind-background) sprites** keep the 2-pixel bitmap path (`as_bitmap`, `drawProcs`).  They
  are things like SMB's piranha plants, which don't move horizontally and stay locked to the scroll position.
* **Clipped sprites** (right screen edge, `sprTmp4 != 0`, and `sprClipTop`) keep the 2-pixel clipped bitmap
  routines (`drawProcsClipped`).
* **Cache misses** draw from the bitmap at 2-pixel positions until the sprite is compiled, normally a render
  or two.  This is a short hitch the first time a sprite appears, not an ongoing stutter.
* **The legacy dirty renderer** is not supported: every game is moving to the quad grid renderer (see the
  legacy renderer removal).  The full-render-only games (SMB, Excitebike, Wumpus) need nothing extra: they
  never save the screen under sprites.

## Design

### 1. Slots: 2KB, four variants, four banks

Each slot holds the four variants of one key, 512 bytes (2 pages) each:

| Page offset in slot | Variant |
|---|---|
| +0 | normal |
| +2 | horizontally flipped |
| +4 | shifted one pixel right |
| +6 | shifted, horizontally flipped |

512 bytes always fits a variant.  The shifted code has 3 words per line (24 words); its worst case is
24 words * 12 bytes (`lda abs,y / and # / ora # / sta abs,y`) + a 4 byte JML = 292 bytes.  That is more
than the 256 bytes available today (variant at +0 / +$100 of a 512-byte slot), even though most sprites fit
in one page.  The plain variants (at most 196 bytes) waste half their space; the memory is cheap.

The compile memory becomes up to **four 64KB banks** (256KB), 32 slots per bank, **128 slots**.  The banks
do not need to be contiguous: each table entry carries its own bank byte.  Allocate them with
`AllocOneBank2` (`src/core/Memory.s`) one at a time and keep however many succeed (at least 1), so a machine
with less free memory still runs with 32, 64 or 96 slots.  Keep the bank bytes in a small table
(`SprBanks`, 4 bytes) and the slot count in a variable instead of the `SPR_SLOTS` constant.

A cache key still means (pattern table, palette, tile, vertical flip): the shift is not part of the key,
so the number of keys in the working set is unchanged (about 150 on the Zelda bench route).  128 slots
of 4 variants holds the same working set as today's 127 slots of 2 variants.

### 2. Table entries: bank:page

An `SPR_COMP_TBL` entry becomes `bank << 8 | page`, the high two bytes of the slot's 24-bit address.  It is
never 0 (the bank is never 0), so `$0000` still means "not compiled", and slot 0 no longer has to be
skipped.  The JML operand is patched at `csd+2` (page, bank) instead of `csd+1`; `csd+1` stays `$00`.  Same
cycles.

`PPUStartUp` (`src/ppu/ppu_init.s`) no longer patches the bank into `csd+2`: the bank comes from the entry.

### 3. Dispatch (`:blitResolvedSprite`, `src/ppu/ppu.s`)

```asm
        tay
        lda  [sprCompTbl],y     ; bank:page of the slot
        beq  sprCacheMiss
        bcc  *+5
        ora  #$0002             ; horizontally flipped variant (was ora #$0100)
        ora  sprShift           ; $0000, or $0004 for a sprite on an odd pixel   (+4 cycles)
        stal csd+2              ; (was csd+1)
        ldy  sprTmp1
csd     jml  $000000
```

Slots are 8-page aligned, so the `ora`s never carry.

### 4. Setup (`SPR_SETUP`)

Keep the parity of `x + sprXPar` instead of discarding it, and set `sprShift` (a new direct page word, high
byte always 0) to 0 or 4.  The current 8-bit sequence is `lda sprXPar / adcl OAM_COPY+3,x / and #$FE / ror`;
replacing the `and #$FE` with a sequence that moves bit 0 into `sprShift` costs about 8-10 cycles.  Work out
the exact sequence at implementation time.

Right edge: an 8-pixel sprite on an odd pixel spans 5 bytes, so with a shift it must be clipped from byte
column 124 instead of 125 (the `cpy #125` test).  Clipped sprites go to the 2-pixel clipped bitmap routines
(see Goal).

8x16 sprites draw both halves with the same `sprShift`; nothing else changes there.

### 5. Compiler (`src/core/sprites/CompileSprites.s`)

`CompileSprite` emits four variants instead of two.  The shifted variants are derived from the resolved
words of the normal and flipped variants (`cs_val` / `cs_msk`):

* Per line, the 2 words (4 bytes, 8 pixels) become 3 words (6 bytes): shift the pixel stream right one
  nibble.  Mind the byte order: the leftmost pixel is the high nibble of the first byte, and a 16-bit load
  puts the first byte in the low byte of the word.
* The new left nibble and the 3 rightmost nibbles of the third word are transparent (mask `F`).  The third
  word's high byte is always transparent.
* Emit with the same rules as now: fully transparent words are skipped, opaque words are grouped by value,
  the rest are `lda abs,y / and # / [ora #] / sta abs,y`.
* Screen offsets: new `word_addr_shift` / `word_addr_shift_flip` tables (24 entries, `+0/+2/+4` per line).

`SprCompileTile` sets the `[SpriteBank0],y` bank byte to the slot's bank before emitting, and stores
`bank:page` in `SPR_COMP_TBL`.  `SPR_OWNER` is indexed by slot number * 2 (128 words, same size as now) and
`SPR_CURSOR` holds a slot number.  `SprCacheInit` / `SprCacheFlush` loop over the slot count.

Compile cost per miss goes from 2 variants to 4, with the shifted ones about 1.5x the size: roughly 2.5x
today's compile time.  If that shows up as hitches with `SPR_COMPILE_PER_RENDER 2`, two options:

* lower the quota to 1, or
* compile the shifted pair lazily: page bit 0 of an entry is free (slots are 8-page aligned) and could mark
  "shifted variants not compiled yet".  That adds a test to the dispatch path, so only do it if measured.

### 6. Grid marking (`src/ppu/ppu_grid_quads.s`)

The grid is only used when the horizontal scroll is a multiple of 8 (`gqInitTables`), so on grid frames
`sprXPar` is 0 and the sprite's pixel column is just its OAM x.  The marking already indexes its tables by
the raw OAM x (`gridColOff,y` / `gridBIdx,y`), so the change is in the tables only, with no new code on the
marking path:

* `gridBIdx`: the position in the cell in pixels, `(x & 7) * 2` (8 values), instead of the byte
  `((x >> 1) & 3) * 2` (4 values).
* `gqHTL`, `gqHTR`, `gqHBL`, `gqHBR` (and the 8x16 `gqHFL` / `gqHFR`): index `k * 16 + p * 2` instead of
  `k * 8 + b * 2`, so they double in size.  A quadrant is 4 pixels wide.  A sprite at pixel p (0-7) covers
  pixels p to p+7: the left cell's quadrants from `p / 4` to 1, and the right cell's quadrants 0 to
  `(p + 7 - 8) / 4` when p > 0.  5 bytes still span at most 2 cells.
* Change the `gridKIdx` scale from `k * 8` to `k * 16`.
* The quad-mode skip records (`gridRecordSprite8`, `gqRep8` / `gqRep16`) replay the recorded index, so
  they pick up the new tables unchanged.

Even pixels give the same quadrants as today, so 2-pixel-aligned sprites mark exactly what they mark now.

### 7. Things that don't change

* The CHR-RAM drop (`ppu_regs.s`, clears the entries of a tile's keys): it clears entries, whatever their
  format.
* The pending queue and `sprCacheMiss`: they queue keys; the compile makes all four variants.
* The bitmap paths, `sprChrCheck`, `SPRITE_PRE_DRAW` / `sprClipTop`.

## Cost estimate

* Dispatch +4 cycles and setup +8-10 cycles per sprite: about 85K sprite tiles on the Zelda bench route,
  so ~1.2M cycles (0.5%).
* Drawing: a shifted variant has ~50% more stores and its edge words are always masked.  With about half
  the sprites on odd pixels, sprite drawing costs ~25% more: ~3-4M cycles (~1.5%) on the Zelda bench.
* Compiles: ~2.5x per miss; the hit rate should not change (same keys, 128 slots).
* Memory: up to 192KB more than today (4 banks instead of 1).  Main segment: the shifted emitter and the
  bigger `gqH*` tables; the main segment is nearly full in Zelda, so measure it.

## Verification

1. **Plumbing with the shift forced off** (`sprShift` always 0, everything else in place): the screens must
   match HEAD exactly.  Zelda bench `--shots` hashes and the SMB frame-hash window, plus the cycle counts
   to see the cost of 2KB slots, bank:page entries and 4-variant compiles on their own.
2. **Shift on**: the hashes change by design (sprites move by a pixel), so compare by eye at the frames where
   sprites sit on odd pixels.  Check enemies turning horizontal in Zelda, sprites at the right screen edge
   (clipped, 2-pixel), and the first frames of a new sprite (cache miss, 2-pixel).
3. Zelda bench cycles against HEAD (237.08M as of 2026-10-08) and SMB frames 300-2100 (195.13M).
4. `build:all`, then run every grid game: BF, DK, IC, MB, Lights Out.

## Open questions

* Lazy compile of the shifted pair (5): only if the compile hitch is measurable.
* More slots are possible later at no dispatch cost (bank:page entries reach any bank, so it is only more
  banks and a bigger `SPR_OWNER`), but not needed now: the goal is to keep today's 98%+ hit rate, which
  128 slots of the same keys should do.  Revisit only if a game's working set outgrows it.
* Right-edge sprites could get shifted clipped code later (a clip-aware shifted variant), if the 2-pixel
  steps near the edge are noticeable.

# Physical Nametable RAM Model — Investigation & Plan (rev 3)

**Status (2026-09-07):** Investigation re-done after tracing the full
mirror-switch path end to end. Several assumptions in rev 1 were wrong (see
"Corrections to rev 1" below). Scope decided by the user this pass:

- **`ppu_queues2.s` is dead** — an experiment, not a live path. Ignore it.
  The live nametable-write path is `ppu_regs.s` (`PPUDATA_WRITE` /
  `PPUDATA_READ`, with the `:in_nt` handler inline) feeding `nt_list` /
  `at_list`, drained by `ppu_queues.s` (`PPUFreezeNametableUpdates` /
  `PPUFlushQueuesAlt`).
- **Zelda *does* switch mirroring at runtime** — this is a live, reproducible
  bug, not a latent/forward-looking one. Repro is the Zelda underground (see
  `rom_07_fixed.s` `Z07Int_...SetMirroring`: vertical when Link faces
  horizontally, horizontal otherwise; also room-transition / mode-init sites
  that force `#$0F` = horizontal).
- **Only standard horizontal and vertical mirroring need to be supported.**
  No one-screen, no true four-screen. Every place that was going to be
  "physical page = f(mode, addr)" is just a choice between two address bits.
- **The model will be re-strided to physical CIRAM** (decision 2026-09-07).
  Modelling PPU state by indexing shadow RAM with *logical* PPU addresses
  (`$2000-$2FFF`) is a fragile fiction: two mirror modes that must map onto
  the same 2KB of real RAM instead land page B at two different logical
  offsets, and every downstream shadow inherits the inconsistency. The fix
  is to index everything by the **CIRAM address** (`$000-$7FF`, one honest
  2KB space) computed once at the `$2007` boundary — i.e. the rev-1
  "Option B", now the plan, not a follow-up.

## The design principle

There is exactly one physical thing to model: **2KB of CIRAM, two 1KB
pages.** The NES PPU's `$2000-$2FFF` is a *view* onto it, and the cartridge
mirroring wiring (MMC1 control bits 1:0) picks the view. So:

- Convert logical `$2000-$2FFF` → CIRAM `$000-$7FF` **once**, at the
  `PPUDATA`/queue boundary, using the current mode.
- Everything past that point — raw NT bytes, `TILE_SHADOW`, `ATTR_SHADOW`,
  `TILE_ADDR_*`, `TILE_BANK`, `TILE_ROW`, `TILE_COL`, `TILE_VERSION0/1`,
  the `nt_list` / `at_list` entries — is indexed by the CIRAM offset and
  never sees a logical address or a mode.
- A mirroring switch changes only the front-door conversion. The 2KB of
  CIRAM (and its shadows) are physically untouched, exactly as on hardware.
- One canonical primitive — `logical→CIRAM(mode, addr)` — replaces the
  three hand-rolled encodings (`MirrorMask`/`MirrorMaskLong`,
  `MirrorMaskX`/`MirrorMaskY`, the `_Init{H,V}Mirroring` duplication).

## Corrections to rev 1

Tracing `SetMirrorMode` / `ApplyMirrorMode` / `PPUSetMirrorMode` showed the
runtime-switch machinery is **already mostly built**, contrary to rev 1's
framing and to the stale TODO in `src/games/zelda/src/Main.s:71-77`:

| Piece | State |
|---|---|
| `SetMirrorMode` (`core/ControlBits.s`) — stashes requested mode in `PendingMirrorMode` (abs, not DP, callable via `JSL` from NES ROM banks) | **exists** |
| `ApplyMirrorMode` (`core/ControlBits.s`) — picks up `PendingMirrorMode` at render time, calls `PPUSetMirrorMode` | **exists** |
| `ApplyMirrorMode` wired into `PRE_RENDER` | **already wired** — `src/games/zelda/src/Main.s:41` |
| `PPUSetMirrorMode` (`ppu_init.s:55`) — runtime `bit #HORIZONTAL_MIRRORING` dispatch to `_InitHorizontalMirroring` / `_InitVerticalMirroring` + `_InitLiteBlitter{Horz,Vert}` + `_InitPPUTileMapping{Horz,Vert}` | **exists**, already a runtime switch |
| `_InitPPUTileMapping{Horz,Vert}` (`ppu_nametable.s`) — rebuilds the entire per-address PEA mapping (`PPU_MEM+TILE_ADDR_LO/HI/BANK/ROW/COL`) for the new mode | **exists**, runs on every switch |
| Compile-time `DO NAMETABLE_MIRRORING` / `ELSE` branches | **do not exist** — `NAMETABLE_MIRRORING` is only the *power-on* argument to `PPUSetMirrorMode` (`ppu_init.s:34`). The "6 DO/ELSE sites" comment in `Main.s` is inaccurate; correct it as part of this work. |

So rev 1's "second finding" (PEA-field H/V code paths are independently
hand-duplicated and can't unify) still stands as a fact, but it is **not
blocking** — the switch path already re-runs both `_Init*Mirroring`
(CoreImpl.s, scanline-flow SMC) and `_InitPPUTileMapping*` (per-address PEA
map) on every mode change. What that path does *not* currently do correctly
is the RAM side, and it never actually gets exercised because of gap #1.

## The three real gaps

### Gap 1 — MMC1 `$8000` (control register) writes are decoded to nothing

`STA_MMC1_REG0` (`src/rom/rom_inject.s:114`) runs `MMC1_SHIFT` then
`MMC1_RTN`: it serial-shifts the 5 bits into `mmc1_shft` and, when the
register fills, **discards the result**. Only `STA_MMC1_REG3` (bank select)
does anything with a completed shift. So the MMC1 control register — whose
bits 1:0 are the mirroring mode — is ignored, and nothing ever calls
`SetMirrorMode`.

- `mmc1_reg0` storage already exists (`ppu_regs.s:59-63`) but is never
  written.
- The checked-in `SetMMC1Control` / `SetMMC1Control_LocalN` wrappers
  (`rom_07_fixed.s:6017`, `rom_05.s:8428`, and the `_LocalN` aliases used by
  banks 1-6) are the **old** form: 5×`jsr STA_MMC1_REG0` + `RTS`, no
  `SetMirrorMode` call.
- `src/games/zelda/tools/convert.py` (~line 416-447) *already* generates a
  **new** form that reads the pre-LSR accumulator, maps bits 1:0, and
  `JSL SetMirrorMode` with `#$01`/`#$02`. The tree just hasn't been
  regenerated, and `rom_07_fixed.s` is hand-maintained so it wouldn't pick
  it up anyway.

**Fix (preferred): centralize the decode in `STA_MMC1_REG0` itself**, the
same way `STA_MMC1_REG3` centralizes bank-select. When the shift completes:
latch the 5-bit value into `mmc1_reg0`, take bits 1:0, and for `%10` /
`%11` write `VERTICAL_MIRRORING` / `HORIZONTAL_MIRRORING` to
`PendingMirrorMode` (call `SetMirrorMode`, or just `stal PendingMirrorMode`
directly — we're already in engine-ish code here, but `PendingMirrorMode`
is abs-addressable so either works). Bits 1:0 = `%00`/`%01` are one-screen
modes — out of scope, leave the current mode unchanged. This fixes every
bank at once and makes the `convert.py` wrapper change unnecessary (the old
5×shift wrappers become correct again because the shift itself now has the
side effect). MMC1 control bits 2 (PRG bank mode) and 3-4 (CHR bank mode)
stay ignored as they are today.

### Gap 2 — the two mirror masks disagree on where physical page B lives

Unchanged from rev 1, but now the *live* bug:

- `HORIZONTAL_MIRROR_MASK equ $3BFF` clears bit 10 → NT0/NT1 fold to
  `$000-$3FF`, NT2/NT3 to `$800-$BFF`.
- `VERTICAL_MIRROR_MASK equ $37FF` clears bit 11 → NT0/NT2 fold to
  `$000-$3FF`, NT1/NT3 to `$400-$7FF`.

Page A lands at offset `$000` in both modes (good). Page B lands at `$800`
under horizontal but `$400` under vertical. A H→V or V→H switch therefore
orphans everything written to page B under the old mode, and the new mode's
page-B offset reads stale/uninitialized bytes. Real hardware: the 2KB of
physical RAM is untouched by a mirroring change; only the address decode
moves. Our model has to match that.

This offset is also the index into every parallel shadow region
(`TILE_SHADOW`, `ATTR_SHADOW`, `TILE_ADDR_*`, `TILE_BANK`, `TILE_ROW`,
`TILE_COL`, `TILE_VERSION0/1` — `core/Defs.s:258-266`, each at a fixed
`$1000` stride off `PPU_MEM`, added to the un-collapsed `$2xxx` address), so
the disagreement isn't just about the raw NT bytes — it desyncs the whole
shadow set across a switch.

### Gap 3 — pending queue entries and version stamps aren't invalidated on a switch

`nt_list` / `at_list` hold **already-collapsed** offsets captured under the
old mask. `PPU_VERSION` / `TILE_VERSION0/1` stamps are keyed to those
offsets. `_InitPPUTileMapping*` rebuilds `TILE_ADDR/BANK/ROW/COL` for the
new geometry, but the outstanding list entries and version stamps are left
pointing into the old layout. After a switch, `PPUFreezeNametableUpdates` /
`PPUFlushQueuesAlt` would drain stale coordinates into the PEA field.

**Fix:** `ApplyMirrorMode`, after `PPUSetMirrorMode` returns, must
`jsr PPUResetQueues` and force a full-screen redraw for the next frame
(same signal path the engine already uses on a palette-forced full refresh
/ `DIRTY_BIT_BG0_REFRESH`). A mode switch is rare (room transitions, Link
turning in a dungeon) so a one-frame full redraw is fine.

## Physical RAM model (simplified to H/V only)

Canonical primitive — one function, two address bits:

```
; mode ∈ {HORIZONTAL, VERTICAL}
physPage   = (mode == HORIZONTAL) ? ((addr >> 11) & 1)    ; A11 selects page
                                  : ((addr >> 10) & 1)    ; A10 selects page
physOffset = (physPage << 10) | (addr & $3FF)             ; 0 .. $7FF, 2KB
```

Concretely per mode, starting from a 12-bit nametable address:

- **Vertical:** `physOffset = addr & $07FF` — A10 is already in the page-bit
  position; one `AND`.
- **Horizontal:** `physOffset = ((addr >> 1) & $0400) | (addr & $03FF)` —
  A11 has to move down one bit; `AND`/`LSR`/`AND`/`ORA` (≈4 ops) or a
  256-entry table on the high byte.

### Hot-path cost (`$2007` read + write, `ppu_regs.s`)

The `$2007` write path is hot (bulk nametable fills at screen load). The
`cmp #$0800 / bcc / eor #$0C00` sequence in step 1 adds ~2 cycles under
vertical (branch not taken) and ~4-5 under horizontal. Ship that; if a MAME
cycle-count regression on the fill path says it matters, SMC the site from
`PPUSetMirrorMode` — vertical collapses to a bare `and #$07FF` + `nop`
padding, horizontal keeps the full sequence, both in a fixed byte budget.
This matches the engine's existing SMC style (`_Init*Mirroring` already
self-modifies the PEA field). Don't build the SMC path until it's shown to
be needed.

Keep `MirrorMask` / `MirrorMaskLong` as the *active-mode source of truth*
(also read as a mode flag by `HorzLite.s` / `ppu_metatiles.s`);
`MirrorMaskLong` is reused as the first AND in the conversion sequence, so
its value carries the 0-based semantics (`$07FF` / `$0BFF`).

### `MirrorMaskX` / `MirrorMaskY` and the `ppu_metatiles.s` literal

These are a *different* axis — render-surface coordinate wrapping
(`$00FF`/`$01FF`), not RAM addressing — and are consumed as a mode
discriminant in `BlitterLite.s` (lines 217/239/717) and `ppu_metatiles.s:59`
(`lda MirrorMaskX / bit #$0100` → pick `$2400` vs `$2800` as "the other
nametable"). They don't need to change for the RAM fix, but they are a
third hand-rolled encoding of "which bit is the alias-select bit." If the
canonical primitive above is introduced, fold these onto it opportunistically
(low priority, not blocking).

## The plan: re-stride to a physical CIRAM model

One change, landed together (the surgical "fix the masks in place" version
was considered and rejected — it leaves the logical-address fiction and its
wasted 4KB×N shadows in place, and `ppu_nametable.s` would keep its
mode-dependent double-writes).

### 1. Front door — `logical→CIRAM` conversion (Gap 2)

At the two `ppu_regs.s` sites (`PPUDATA_READ` nt-branch ≈ line 263,
`PPUDATA_WRITE` `:in_nt` ≈ line 347) replace `txa / andl MirrorMaskLong /
tax` with:

```
        txa
        andl MirrorMaskLong        ; V = $07FF, H = $0BFF  (0-based: $2000 stripped)
        cmp  #$0800                ; A11 set? only possible under H
        bcc  :nt_mapped
        eor  #$0C00                ; H & A11: clear A11 ($0800), set A10 ($0400)
:nt_mapped
        tax                        ; X = CIRAM offset, $000-$7FF
```

- `HORIZONTAL_MIRROR_MASK` / `VERTICAL_MIRROR_MASK` (`CoreImpl.s:383,481`)
  change from `$3BFF` / `$37FF` to **`$0BFF` / `$07FF`** — same bit-clearing
  as today *plus* stripping the `$2000` logical base so the result is a true
  0-based CIRAM offset. `MirrorMask` (DP) / `MirrorMaskLong` (abs) keep
  their existing dual-write in `_Init{H,V}Mirroring`; they stay the "which
  mode is active" source of truth, and `MirrorMaskLong` doubles as the
  first AND in the sequence above.
- Hot-path cost: 1 extra `cmp` + predicted-not-taken `bcc` under vertical,
  + `eor` half the time under horizontal. If the fill path measures too
  slow, SMC the site from `PPUSetMirrorMode` (vertical collapses to a bare
  `and #$07FF`); default to the branch version until proven necessary.
- The in-between edit currently in the tree at `ppu_regs.s:347-357` is a
  broken draft of exactly this (operates on `A` = the post-increment
  address instead of `X`; `andl MirrorMask` addresses DP-equ `12` as
  `$00000C` instead of the abs copy; then `txa` discards the result and
  falls through to the old path). Replace it wholesale.

### 2. Re-stride the shadow regions (`core/Defs.s:258-266`)

`x` is now `$000-$7FF`, so each region needs `$0800` of space, not `$1000`.
Proposed layout off `PPU_MEM` (CHR stays put at `+$0000`, size `$2000`;
palette stays at its fixed `+$3F00`):

| Region | New base | Size | Old base (`equ` + `$2000` in `x`) |
|---|---|---|---|
| CIRAM raw NT bytes | `+$2000` | `$0800` | was `PPU_MEM+x` → `+$2000` |
| `TILE_SHADOW`  | `+$2800` | `$0800` | `+$4000` |
| `ATTR_SHADOW`  | `+$3000` | `$0800` | `+$5000` |
| *(palette `+$3F00`, 32 B — unchanged, sits in the ATTR_SHADOW slack)* | | | |
| `TILE_BANK`     | `+$4000` | `$0800` | `+$6000` |
| `TILE_ADDR_LO`  | `+$4800` | `$0800` | `+$7000` |
| `TILE_ADDR_HI`  | `+$5000` | `$0800` | `+$8000` |
| `TILE_VERSION0` | `+$5800` | `$0800` | `+$9000` |
| `TILE_VERSION1` | `+$6000` | `$0800` | `+$A000` |
| `TILE_ROW`      | `+$6800` | `$0800` | `+$C000` |
| `TILE_COL`      | `+$7000` | `$0800` | `+$D000` |

Everything from `+$7800` up in the PPU bank becomes free (~34KB reclaimed).
`core/Defs.s` gets the new `equ`s; the `PPU_MEM+CONST,x` idiom is unchanged
in *form* (still `ldal PPU_MEM+TILE_SHADOW,x`) — only `CONST` and the range
of `x` move. Watch items:

- **`PPU_MEM,x` is used for three address ranges** in `ppu_regs.s` /
  `ppu_queues.s`: CHR (`$0000-$1FFF`, raw `x`), nametable (now CIRAM `x`),
  palette (`$3F00+`, raw `x`). Only the nametable accesses move to
  `PPU_MEM+CIRAM_BASE,x` (`CIRAM_BASE = $2000`). The CHR and palette
  accesses keep raw `x` and are untouched — they're already on separate
  branches.
- **Small sub-offsets survive** (`+$00/$01/$20/$21` in `ppu_attributes.s` /
  `ppu_metatiles.s` for 2×2 metatile blocks, `+$20` for next-row): `$21`
  fits inside `$0800` with room to spare, no region-boundary crossing as
  long as `x ≤ $7FF - $21`. True for all real nametable offsets (max tile
  addr is `$03BF` / `$07BF`).
- **`nt_list` / `at_list`** store the post-conversion `x`. `$000-$7FF` fits
  the existing `dw` entries; `NT_LIST_LEN` (1920 = 2 pages × 960) and the
  head/tail bookkeeping are unchanged.

### 3. `ppu_nametable.s` — the double-writes collapse (the simplification)

`_InitPPUTileMappingVert` / `_InitPPUTileMappingHorz` currently write each
mapping entry **twice** — `PPU_MEM+TILE_ADDR_LO+$000,x` *and* `+$800,x`
(vert) / `+$400,x` (horz) — to populate both logical nametables of a mirror
pair. In a CIRAM model those two logical NTs *are the same 1KB page*, so
there is exactly **one** entry per CIRAM byte. Each `_Init*` routine loses
its paired `+$400`/`+$800` stores and iterates the CIRAM offset directly.
This also removes the `Col2CodeOffset+128` fix-up games (H copies `0-63`
into `64-127`; V ORs `$0100`) — that table only existed to service logical
columns `32-63` of the aliased second NT.

### 4. Per-game `PPU.s`

Shrink `PPU_NT` (`ds $2000` → `ds $0800`) in `src/games/*/PPU.s` +
`src/games/zelda/src/PPU.s`, and adjust the trailing `ds $BF00` pad so the
bank still totals `$10000`. (The `CHR_ROM`/`PPU_MEM` `ds $2000` for CHR is
unchanged.)

### 5. Gap 1 and Gap 3 ride along

- **Gap 1** (MMC1 `$8000` decode) and **Gap 3** (`PPUResetQueues` + forced
  full redraw in `ApplyMirrorMode`) are unchanged from the analysis above —
  independent of the re-stride, needed for the switch to work at all.
- Correct the stale `src/games/zelda/src/Main.s:71-77` comment.

## Call sites (consolidated)

- `src/rom/rom_inject.s` — `STA_MMC1_REG0` decode → `PendingMirrorMode`
  (Gap 1).
- `src/ppu/ppu_regs.s` — `PPUDATA_READ` nt-branch (≈264) and `PPUDATA_WRITE`
  `:in_nt` (≈347): the `logical→CIRAM` sequence, and re-base the nametable
  `PPU_MEM,x` accesses to `PPU_MEM+CIRAM_BASE,x`. Leave the CHR (`≈245`,
  `≈271`, `≈313`) and palette (`≈429/431`) `PPU_MEM,x` accesses alone —
  different branches, raw `x`. `PPUCTRL_WRITE`'s `ntaddr` write is
  base-select, not mirroring — unaffected.
- `src/core/CoreImpl.s` — `HORIZONTAL_MIRROR_MASK` / `VERTICAL_MIRROR_MASK`
  `$3BFF`/`$37FF` → `$0BFF`/`$07FF` (`_InitHorizontalMirroring:383`,
  `_InitVerticalMirroring:481`).
- `src/core/Defs.s:258-266` — new `$0800`-strided region `equ`s +
  `CIRAM_BASE equ $2000` (see layout table).
- `src/ppu/ppu_nametable.s` — drop the `+$400`/`+$800` paired stores and the
  `Col2CodeOffset+128` fix-up; iterate CIRAM offset directly.
- `src/ppu/ppu_queues.s` — `PPU_MEM,x` (≈80, 95) → CIRAM-based; shadow
  refs pick up the new `equ`s automatically.
- `src/ppu/ppu_attributes.s`, `src/ppu/ppu_metatiles.s` — pick up new
  `equ`s; verify the `+$00/$01/$20/$21` sub-offsets and the `$2400`/`$2800`
  literals (`ppu_metatiles.s:59-65`) — the latter are logical NES addresses
  and must themselves be run through `logical→CIRAM` now, not used raw as
  shadow indices.
- `src/core/ControlBits.s` — `ApplyMirrorMode` adds `PPUResetQueues` + force
  full redraw (Gap 3).
- `src/ppu/ppu_init.s` — `PPUSetMirrorMode`: optional SMC of the
  `ppu_regs.s` transform site if the branch version is too slow.
- `src/games/*/PPU.s` + `src/games/zelda/src/PPU.s` — `PPU_NT` `$2000` →
  `$0800`, adjust trailing pad.
- `src/games/zelda/src/Main.s:71-77` — correct the stale comment.
- `src/ppu/ppu_queues2.s` — **do not touch** (dead experiment).

## Not doing

- One-screen mirroring (`%00`/`%01` control bits) — leave mode unchanged.
- True four-screen (cart VRAM) — no in-tree game needs it.
- Unifying `_InitHorizontalMirroring` / `_InitVerticalMirroring` scanline
  topology — genuinely different geometry (256×480 stacked vs 512×240
  side-by-side), confirmed rev 1, not worth forcing.
- MMC1 CHR-bank switching (control bits 3-4, `chr_bank` stub) — separate
  future work.

## Open questions

1. ~~Option A first or straight to B?~~ **Resolved: straight to the CIRAM
   re-stride** — the logical-address model is a fiction not worth preserving
   even transiently.
2. Take the `cmp`/`bcc`/`eor` branch version of `logical→CIRAM` first and
   only SMC it (from `PPUSetMirrorMode`) if the nametable-fill path measures
   too slow? (Lean: yes — ship the branch, measure, optimize if needed.)
3. Exact "force full redraw" signal `ApplyMirrorMode` should raise — reuse
   `DIRTY_BIT_BG0_REFRESH` (`ControlBits.s` `EnableBackground` path) or a
   dedicated bit? Confirm it forces a *nametable* full redraw, not just a
   palette/SCB refresh.
4. Does anything need `mmc1_reg0` bit 2 (PRG-bank mode) once Gap 1 latches
   the register? Today PRG banking is entirely `STA_MMC1_REG3`; latching
   `mmc1_reg0` must not imply we now honor bit 2.
5. `_InitLiteBlitter{Horz,Vert}` and `_Init{H,V}Mirroring` (CoreImpl.s) —
   these still build genuinely different scanline topologies and are *not*
   re-strided here. Confirm nothing in them indexes `PPU_MEM` shadows by a
   logical `$2xxx` offset (spot check says no — they work in PEA-field
   space and `BTable*`), so they're unaffected by the `Defs.s` change.
6. `Col2CodeOffset` — after `ppu_nametable.s` stops using the `+128` half,
   is the table still referenced at its base by the blitter? (`BlitterLite.s`
   uses `Col2CodeOffset`.) Keep the base 64 entries; only the H/V fix-up of
   the upper half goes away.
7. One-screen control values (`%00`/`%01`) — confirmed no in-tree game
   selects them; `STA_MMC1_REG0` leaves the mode unchanged for those.

## Suggested implementation order

1. `Defs.s` re-stride + `CIRAM_BASE`, `CoreImpl.s` mask values, `PPU.s`
   `PPU_NT` shrink — the mechanical layout change. Builds should still pass
   with behavior unchanged *if* every `PPU_MEM+CONST,x` site is updated
   consistently and `x` is still logical at this step (i.e. do the layout
   move and the front-door conversion as one atomic change, or the shadows
   desync). Practically: change `Defs.s`/`CoreImpl.s`/`ppu_regs.s`
   front-door together.
2. `ppu_regs.s` `logical→CIRAM` at both sites + nametable `PPU_MEM,x`
   re-base.
3. `ppu_nametable.s` double-write collapse.
4. `ppu_queues.s` / `ppu_attributes.s` / `ppu_metatiles.s` — re-base +
   convert the `$2400`/`$2800` literals.
5. Gap 1 (`STA_MMC1_REG0` decode) + Gap 3 (`ApplyMirrorMode` reset/redraw).
6. `Main.s` comment fix.

## Test plan

1. **Regression first.** H-only games (dk, ic, mb) and V-only games (smb,
   bf, eb, lo, wump) never call `SetMirrorMode`, so the switch path is
   dormant — but they *do* exercise the re-strided shadows and the
   `logical→CIRAM` front door every frame. `npm run build:all` clean +
   smoke-run smb (vertical) and dk (horizontal) in the emulator; the
   playfield must be pixel-identical to a pre-change build.
2. **Zelda underground.** Enter a dungeon room that forces vertical
   mirroring (Link on a horizontally-scrolling corridor,
   `rom_07_fixed.s:1371`); before the fix the runtime never switches (Gap 1)
   so it renders as horizontal-mirrored garbage. After: correct axis, and
   leaving back to a horizontal room round-trips cleanly (page-B CIRAM
   survives the switch because nothing physically moved).
3. `npm run build:zelda` clean, then GSPort/KEGS run — combine with the
   still-pending emulator check for the CHR-RAM sprite fix.
4. **Switch stress:** the underground `SetMirroring` site keys off Link's
   facing, so pacing left↔right against a wall toggles the mode every few
   frames. Confirm no queue corruption / no creeping shadow desync over
   many rapid switches (Gap 3 working).

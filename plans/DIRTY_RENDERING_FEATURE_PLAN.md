# ENABLE_DIRTY_RENDERING Investigation & Fix Plan

**Status (2026-08-24):** Crash fixed, sprites now render correctly, SCB
corruption resolved. Two things queued for next session:

1. **`ppu.s` refactor (user's plan for tomorrow, not started).** The DBR bug
   (finding #1d, bug 4) was hard to find precisely because it's action-at-a-
   distance: `drawSprites` pins DBR to the tiledata bank once, at the top of
   the OAM loop, and everything downstream -- including code in a different
   file (`ppu_tiles.s`) -- silently inherits that assumption with no local
   indication it's even in effect. The user's diagnosis: `ppu.s` is too large
   and its pieces too entangled for this project's goal of a dynamic,
   game-state-responsive rendering pipeline; it needs breaking into smaller,
   independently-testable modules rather than one large file where a bank
   assumption set in one function silently governs unrelated code far away.
   No scope/approach decided yet beyond that diagnosis -- to be planned
   tomorrow.
2. Sprite draw-order "fighting" (see bottom of doc) -- next up after/alongside
   the refactor, priority order TBD tomorrow.

**Status (2026-08-23, superseded above):** Original crash fixed and confirmed by
the user (finding #1, `sprBlockAddr` undersized for 8x16 sprites). A second,
related bug then surfaced once the crash was gone: visible horizontal corruption
in the SCB region (`tests/corrupt_lines.png`). Finding #1b (the
`saveTileFromScreen8` bounds guard, below) fixed *part* of it -- per the user,
the corruption changed from animating to static, but did not go away entirely.

Correction to my own earlier framing (2026-08-23, from the user): the remaining
corruption is **not** spread across some "allowed but off-screen" row range --
it's specifically a single write landing right at the boundary, starting exactly
at the first invalid scanline (the one immediately after the last real on-screen
line) and running 16 bytes deep, consistent with one 8x16-sprite-height block
whose top edge sits precisely at that boundary. Don't reason about this as a
16-row danger *zone*; it's a specific boundary case. (My initial post-mortem
below, connecting it to `max_nes_y - y_height = 16`, was off-base and is kept
only as a record of a ruled-out theory -- see the "ruled out" note inside finding
#1c.)

Separately, the user has also flagged a pre-existing dirty-rendering bug noticed
earlier: **sprite draw-order "fighting"** -- sprites that should be behind
another sometimes draw in front instead, alternating/flickering. Suspected (by
the user, unconfirmed) to relate to `restoreTilesToScreen` popping saved
background blocks in LIFO order, the reverse of the OAM-index order they were
pushed in during `drawSprites`. Not yet investigated further; the user is
debugging both issues directly. Findings #2-4 (below finding #1c) are older,
unrelated follow-ups; none of them block the feature.

## Context

`npm run build:zelda` assembles cleanly with `ENABLE_DIRTY_RENDERING equ 1` (verified
directly — flipped the flag, built, confirmed no assembler errors/warnings, then
reverted it back to `0` so the tree is unchanged from this session). So this is
purely a **runtime** bug, not a missing symbol or macro problem.

### The most important structural fact

`ENABLE_DIRTY_RENDERING` is currently set per-game in each `src/games/<game>/Main.s`:

| Game | `ENABLE_DIRTY_RENDERING` | `HAS_CHR_RAM` |
|---|---|---|
| bf | 1 | 0 |
| dk | 1 | 0 |
| iceclimber | 1 | 0 |
| lightsout | 1 | 0 |
| mb | 1 | 0 |
| excitebike | 0 | 0 |
| smb | 0 | 0 |
| wumpus | 0 | 0 |
| **zelda** | **0 (crashes if set to 1)** | **1 (only CHR-RAM game in the codebase)** |

**Zelda is the only `HAS_CHR_RAM equ 1` game in the entire project**, and dirty
rendering has only ever shipped enabled on `HAS_CHR_RAM equ 0` games. Whether or
not the eventual root cause turns out to literally be a CHR-RAM interaction, the
CHR-RAM + dirty-rendering combination has **never been exercised**, by any game,
until this session. That narrows the search considerably: look first at anything
gated by `DO HAS_CHR_RAM` that the dirty-render path touches, and at anything the
dirty-render path assumes about how backgrounds get invalidated that CHR-RAM's
extra write channel (pattern-table writes, independent of nametable writes)
doesn't obey.

## Findings, ranked by confidence and estimated crash-likelihood

### 1. (Highest confidence / most likely crash cause) `sprBlockAddr` buffer overflow for 8x16 sprites — `src/ppu/ppu_tiles.s`

```asm
sprBlockAddr ds 64*2           ; Maximum of 64 8x8 blocks, each with a 16-bit address
```

This array backs the dirty-render "steady state" (`DirtyState` 2) sprite
erase/expose cycle: `saveTileFromScreen8/16` (called from `drawSprites` while
`DirtyState != 0`) pushes background-backup blocks onto a stack, and
`restoreTilesToScreen` pops them each frame, recording each block's screen
address into `sprBlockAddr,y` (`y` incrementing by 2 per block) for
`exposeTilesToScreen` to blit afterward. There is **no bounds check** on `y`
before the `sta sprBlockAddr,y` write in `restoreTilesToScreen`.

The bug: `saveTileFromScreen16` (used whenever `NES_PPUCTRL_SPRSIZE` selects 8x16
sprite mode) calls `saveTileFromScreen8` for the top half, adjusts X/Y down one
tile row, and **falls through** into `saveTileFromScreen8` again for the bottom
half — i.e. **one 8x16 sprite consumes two `sprBlockAddr` slots**, not one. With
`OAM_END_INDEX equ 64` (Zelda, same as dk/iceclimber), a screen with more than
32 simultaneous 8x16 sprites needs up to 128 slots, but the array only holds 64
(128 bytes). `restoreTilesToScreen` will silently write past the end of
`sprBlockAddr` into whatever follows it in the assembled bank (`outlineColor ds 2`
immediately after, then continuing into subsequent code/data) — a classic
"corrupts adjacent memory, crashes some number of instructions later" bug, which
matches a **fresh, hard-to-explain-from-source crash** far better than a data
error would.

This is **not inherently CHR-RAM-specific** — it would affect `dk`/`iceclimber`
too if they ever had >32 simultaneous 8x16-mode sprites — but Zelda's dungeon
rooms are exactly the kind of content (multiple enemies + projectiles + effects,
all sharing OAM) most likely to hit it, and it's the only concrete bug found here
that plausibly explains an *immediate* crash rather than a rendering glitch.

**CONFIRMED (2026-08-23, by the user):** Zelda uses 8x16 sprites throughout, and
the **title screen alone uses 44 sprites** (decoration + waterfall animation).
44 sprites x 2 blocks/sprite (8x16 mode) = **88 blocks needed against a 64-block
`sprBlockAddr` buffer** — a guaranteed overflow, and on the very first screen the
game shows. This lines up exactly with "crashes immediately": the title screen
doesn't need a rare, sprite-dense dungeon room to trigger it — it overflows on
sight. This is no longer just the highest-ranked guess; it's the confirmed root
cause pending only the actual fix-and-retest. Implemented below.

**Fix shipped:** `sprBlockAddr` widened from 64 to 128 entries (256 bytes),
matching the `SprSaveAddr` stack's own already-correct 8x16 sizing comment a few
lines below it, plus a `brk $67` bounds guard in `restoreTilesToScreen` so any
future overflow fails loudly instead of corrupting adjacent memory. Confirmed by
the user: this fixes the crash.

**Design concern raised by the user (unresolved, not blocking):** `sprBlockAddr`
is conceptually meant to track *sprites* (at most `OAM_END_INDEX` = 64 of them),
not *8x8 blocks* -- doubling it to 128 entries to cover the 8x16 case burns
128 extra bytes for something that's "really" a 64-sprite structure, and the
project is getting tight on space. The leaner fix would be to store one
16-scanline-tall block descriptor per 8x16 sprite instead of two 8-line ones
(halving the array back to 64 entries at the cost of unrolling `exposeTilesToScreen`
into 8-line vs. 16-line copy variants depending on sprite mode) -- but the user
explicitly does not want more unrolled 8x8-vs-8x16 code paths added right now for
the same code-space reason. Left as-is (128-entry array) per the user's own
"probably the best way to go" call; revisit only if space becomes a hard
constraint later.

### 1b. (Follow-on bug, same root cause family) Missing vertical bounds check lets sprite save/restore/expose write past the screen buffer into SCB memory

After #1 fixed the crash, the user reported new visible corruption
(`tests/corrupt_lines.png`): a handful of horizontal streaks with garbled tile
rendering, located at rows extending outside the normal playfield. The user's own
diagnosis (correct): the SCB (Scanline Control Byte) region sits in the 256 bytes
immediately following the 200-line, 32000-byte SHR screen buffer (`$012000`-
`$019CFF` screen, SCB at `$019D00`+ -- see `src/MemoryMap.md`), exactly 16 rows
of corruption strongly suggested an off-by-something write landing just past the
end of screen memory.

**Root cause:** `saveTileFromScreen8`/`saveTileFromScreen16` (`ppu_tiles.s`) take
an `X` register "SHR address" input and unconditionally read/push (or, in
`restoreTilesToScreen`/`exposeTilesToScreen`, pop/write) 8 scanlines at
`$010000+{line*160},x`, with **no bounds check of their own**. The routine's own
header comment says *"Input: Y register is the Clamped SHR address"* -- i.e. it
was written assuming the caller (`:setupSprite` in `ppu.s`) had already clamped
the address to stay on-screen. But that clamp is the exact same dead code
identified while investigating finding #1's crash: `sprAddrMin`/`sprAddrMax` are
computed by `:setupSprite8`/`:setupSprite16` but the compare-and-clamp block that
would consume them in `:setupSprite` is commented out, in every game that
includes `ppu.s` (`bf`, `iceclimber`, `wumpus` all show the identical dead code
in their listings) -- so `saveTileFromScreen8`'s input has never actually been
"the Clamped SHR address" the comment claims. `saveTileFromScreen16` calls into
`saveTileFromScreen8` for its top half and *falls through* into the same code
for its bottom half, so any sprite parked at or past the bottom (or top) screen
edge -- like Zelda's title-screen waterfall animation sprites -- writes straight
past the 200-line screen buffer into SCB memory (or, for sprites parked far
off-screen, further still).

This is a **latent bug that predates dirty rendering** (the dead clamp has been
dead in every game's `ppu.s`), but it was never visibly triggered before: the
normal/full-render sprite path (`:blitResolvedSprite`/`as_bitmap`/
`as_bitmap_clip`, also in `ppu.s`) writes through the PEA-field/compiled-code
indirection rather than raw bank-1 memory, so it apparently has its own
independent protection against this. `ppu_tiles.s`'s dirty-only backing-store
routines are the one place that go straight to raw SHR memory with a fixed,
unconditional 8-line copy and nothing else guarding it -- which is why this only
became visible once dirty rendering (the only caller of these routines) was
switched on.

**Fix shipped:** added a bounds guard at the top of `saveTileFromScreen8` (the
single routine both the 8x8 path and the 8x16 path's two halves funnel through,
so one check covers both without duplicating any code): skip the save (early
`rts`, before the stack gets swapped to the `SprSaveAddr` backing buffer) if `X`
is below `$2000` (above the top of the screen buffer) or above
`$2000+(200-8)*160+159` (the last byte an 8-line block could safely start at and
still fit before line 200). Verified in the listing that the assembled immediate
operands are exactly `$2000` and `$98A0` as intended. Since a skipped save never
gets pushed onto the `SprSaveAddr` stack, `restoreTilesToScreen`/
`exposeTilesToScreen` naturally skip it too on the following frame -- no separate
guard needed there.

**Confirmed by testing:** this fix changed the corruption from animating to
static, but did not eliminate it -- see finding #1c.

**Possible refinement flagged by the user (not yet applied):** `restoreTilesToScreen`
runs inside the `_ShadowOff`/`_ShadowOn` bracket in `drawDirtyScreen`'s
`DirtyState` 2 case, so its writes (and `saveTileFromScreen8`'s reads) don't
reach real SCB/video memory at that point regardless of address -- shadowing is
off. It's specifically `exposeTilesToScreen`'s `ldal`/`stal` round-trip (which
runs *after* `_ShadowOn`, using the addresses `restoreTilesToScreen` recorded
into `sprBlockAddr`) that triggers the real hardware shadow-copy into SCB
memory. The current fix guards earlier than strictly necessary (at the save
step); a narrower/more efficient version would let the harmless shadow-off
save/restore proceed unguarded and only refuse to *expose* an out-of-range
block. Left as-is per the user's "let's see if this works first" -- revisit once
finding #1c is resolved, since both fixes touch the same call chain.

**Not yet done / worth a look if more corruption turns up:** the *upstream*
`:setupSprite` clamp in `ppu.s` is still dead code project-wide. This fix only
protects `ppu_tiles.s`'s dirty-rendering backing store; if some other
consumer ever starts reading `sprTmp1`/`sprTmp3` and writing raw memory the way
`ppu_tiles.s` does, it would need the same treatment (or the `ppu.s` clamp itself
should be revisited -- though note it currently clamps by *relocating* the
address rather than clipping, which would drag off-screen sprites onto the
visible edge rather than hiding them, so it's not a drop-in fix for `ppu.s`
without also changing what it does).

### 1c. (Open, user is debugging directly) Remaining static SCB corruption after finding #1b's fix

After #1b shipped, the user confirmed the corruption changed from animating to
static but did not disappear. **Important correction to my own reasoning, from
the user:** I initially described this as sprites being positioned anywhere
within a "16-row allowance zone" past the screen (reasoning from
`max_nes_y - y_height = (y_offset+y_height) - y_height = y_offset = 16`, i.e.
`scanOAMSprites`' `NO_VERTICAL_CLIP` sprite filter permits tracking sprites down
to row `max_nes_y` = 216, sixteen rows past the real 200-line screen). **That
framing is wrong.** The user confirmed the corruption is not spread across a
range -- it's a single write landing exactly at the boundary (starting at the
first invalid scanline, immediately after the last real on-screen line) and
running 16 bytes deep, consistent with one 8x16-sprite-height block whose top
edge sits precisely at that boundary. Treat my "16-row zone" reasoning below as
a ruled-out theory, kept only for the record -- the real explanation is
narrower and still open.

**Leading (unconfirmed) hypothesis at hand-off:** `DirtyState` 0->1 (the
transitional frame right after a full redraw, in `drawDirtyScreen`'s
`:dirty_state_1` case) calls `clearPreviousSprites` and `drawOtherLines`, both
of which route through `_drawBackground` (`ppu.s`) -> `_BltRangeLite`
(`core/blitter/BlitterLite.s`) using `walk_top`/`walk_bottom` computed by the
`WALK_BITMAP` macro directly from the shadow-sprite bitmaps. I compared the two
blit primitives these dirty-only paths feed into:
- `_PEISlam` (used by `exposeCurrentSprites`, the third WALK_BITMAP-driven
  routine in the same transitional step) has an explicit guard: `cpx #200 / bcc
  *+4 / brk $14` and `cpy #201 / bcc *+4 / brk $15`.
- `_BltRangeLite` (used by `_drawBackground`, i.e. by `clearPreviousSprites`/
  `drawOtherLines`) has **no such guard** -- only a check that the range isn't
  empty/reversed (`sty tmp0 / cpx tmp0 / bcc *+3 / rts`).

That asymmetry, plus this transition running once per full->dirty switch (not
every frame), would fit a single, static, one-time write -- consistent with what
the user is now seeing. **However**, I could not fully verify this is actually
unsafe: `_BltRangeLite` operates in a scroll-relative "virtual line" address
space (`txa / adc StartYMod240 / cmp MaxY / bcc *+4 / sbc MaxY`, then indexes
`BTableLow`/`BTableHigh` with the wrapped result) rather than raw physical
0-199 rows, so an input outside 0-199 might be perfectly safe *by design* if the
table was built to cover the full wraparound space -- or might not be. This
needs either a live breakpoint on `_drawBackground` during a `DirtyState` 0->1
transition (watch whether `walk_top`/`walk_bottom` ever land right at the
boundary described above) or a careful read of however `BTableLow`/`BTableHigh`
get populated, neither of which I've done. **The user is investigating this
directly; no code changes made for this finding yet.**

### 1d. RESOLVED (2026-08-24) -- actual root cause of the SCB corruption, and the real fix

The `_BltRangeLite` hypothesis above (1c) was superseded once the user traced the
corruption live in a debugger to `drawTileToScreen` in
`src/ppu/ppu_tile_blitters.s`: the sprite pixel *blit* routines had no vertical
clipping at all, unlike `ppu_tiles.s`'s save/restore/expose (which 1b already
fixed). A sprite near the top or bottom edge would write scanlines straight past
the screen buffer during the actual draw, independent of the dirty-render
backing store.

**Design (agreed with the user, see conversation):** `:setupSprite`/`:calcVClip`
(`ppu.s`) now compute a signed vertical-clip value once per 8-row half, in raw
NES pixel units (no multiply/divide) -- `0` = fully visible, negative = top-clipped
by `|clip|` lines, positive = bottom-clipped by `clip` lines -- stored in
`sprTmp7` (top/only half) and `sprTmp8` (bottom half of an 8x16 sprite, computed
with `Y+8`). `:blitResolvedSprite` centrally skips the whole draw if `|clip| >= 8`
(fully off-screen), so every downstream draw routine can assume `sprTmp7` is
always `0` or in `-7..7`.

Each blitter routine (`drawTileToScreen` done so far; `drawTileToScreenV`,
`*P`, and the `as_bitmap_clip`/`_copyBufferToScreen*` family still to do) uses a
single unified index `(clip+7)&7` into one 7-entry table -- `line(7-index)` is
simultaneously the right jump target for a top-clip (enter partway through the
unrolled 8 lines, skipping the first `|clip|`) and the right patch target for a
bottom-clip (temporarily overwrite that line's leading opcode with `$60`/RTS,
run from the top, then restore it) -- since the routine has no separate "source
tile bitmap vs. screen address" split the way `ppu_tiles.s` does, it can't just
shift an address arithmetically the way that file's fix could; it genuinely
needs either a jump-into-the-middle or a patched-early-return.

**Bugs hit and fixed while building this (all confirmed via the assembled
listing and/or the user's live testing):**
1. Merlin32 can't resolve a label-difference expression like `{:end-:body}` at
   the point it builds a `dw` table, even though plain label references
   resolve fine -- switched from LUP-generated lines to manually-unrolled ones
   with explicit per-line labels (`:line0`..`:line7`) so the jump/offset tables
   could reference them directly.
2. `DBR` is pinned to the tiledata bank for the entire `drawSprites` OAM loop
   (`ppu.s`'s `phb / pea #^tiledata / plb`), not the code bank these blitter
   routines live in. Plain (non-long) `STA`/`LDA` absolute-indexed and
   DP-indirect addressing silently read/write the wrong bank under this
   condition. Fixed by using long-addressed (`stal`/`ldal label,x`) forms
   throughout the patch/table-read code. (`JMP`/`JSR (addr,x)` were *not*
   affected -- confirmed by the user that those resolve via the program bank
   register, not DBR, so the top-clip jump-table dispatch didn't need this
   treatment.)
3. **The actual crash-reintroducing bug**, found after (2) seemed to fix
   everything but sprites came out corrupted (only ~1 line per half rendering):
   `:body`'s own code uses `X` throughout (alternating between `sprTmp0` and
   `sprTmp1` each line), so the patch-offset held in `X` before `jsr :body`
   does *not* survive the call -- the post-call unpatch (`stal :body,x`) was
   writing `$A6` back to whatever address `:body` happened to leave in `X`,
   not the real patch site. That left the `$60` (RTS) stuck permanently in the
   *shared* `:body` code, silently truncating every subsequent sprite drawn
   through it, clipped or not. Fixed with `phx`/`plx` bracketing the `jsr :body`.
4. A second real DBR bug, found while re-auditing per the user's request after
   (3): `ppu_tiles.s`'s `:vclipShiftXY` (used by `saveTileFromScreen8`'s
   top-clip path, which runs *inside* `drawSprites`' OAM loop, i.e. inside the
   DBR-pinned-to-tiledata window) and `restoreTilesToScreen`'s clipped path
   both read `Mul160Tbl` with plain absolute-indexed addressing. Fixed with
   `ldal` -- which surfaced a genuine 65816 constraint (long-indexed `LDA` only
   supports `,X`, there is no `,Y` form), forcing `restoreTilesToScreen`'s
   version to be restructured to index via `X` (preserving the screen address
   across the lookup with `phx`/`plx`) instead of `Y`. **This fix is what
   resolved the user's final crash report** ("numerous RTS instructions around
   the crash location"), though the exact causal chain from a wrong screen
   address to code-memory corruption was never fully nailed down -- noted
   honestly to the user rather than claimed with more confidence than earned.

**Confirmed by the user (2026-08-24): sprites render correctly and the crash is
gone.** `drawTileToScreen` is the only blitter routine with vertical clipping so
far; the other four (`drawTileToScreenV`/`HV`, `drawTileToScreenP`/`PH`/`PV`/`PHV`,
`_copyBufferToScreen`/`H`, `_copyBufferToScreenP`) still need the same treatment
if a sprite orientation/priority combination other than plain/H-flip ever gets
clipped near an edge -- likely low-probability today but not yet handled. Revisit
if any further edge-of-screen corruption turns up for a flipped or
priority-drawn sprite specifically.

### Sprite draw-order "fighting" (separate bug, flagged by the user, next up)

Sprites that should render behind another sprite sometimes draw in front instead,
producing a visible flicker/alternation ("fighting") between the two. Noticed by
the user before this session, re-surfaced now. The user's own suspicion
(unconfirmed): related to `restoreTilesToScreen` popping saved background blocks
in LIFO order -- the reverse of the OAM-index order `drawSprites` pushes them in
via `saveTileFromScreen8/16` during the same frame. If two sprites' saved 8x8/16
blocks ever overlap the same screen address, restore order won't match the
original draw/OAM-priority order. Not yet traced further -- the user is
debugging this directly alongside #1c.

### 2. `ppu_dirty.s` is dead, incomplete code that contradicts its own documentation

`src/ppu/_module.txt` explicitly excludes it:
```
# ppu_dirty.s -- not ready yet
```
It is **not assembled into any build**. Its one routine, `revealTiles`, references
an undefined `]line` LUP-loop variable (no `]line equ 0` / `lup` wrapper present in
the file) and undefined `tile_head`/`tile_list` state that don't appear to exist
anywhere else in the codebase — this looks like an earlier, abandoned prototype
for dirty rendering that was superseded by the `WALK_BITMAP`-macro-based design
actually in use (`scanline_bitmap.s` + `ppu.s`'s `clearPreviousSprites` /
`exposeCurrentSprites` / `drawOtherLines` + `ppu_tiles.s`'s
`restoreTilesToScreen`/`exposeTilesToScreen`).

This is not itself a crash cause (the file isn't built), but:
- `CLAUDE.md` and `.claude/agents/memory-layout.md` both describe `ppu_dirty.s`
  as *the* dirty-state-tracking file ("Dirty-state tracking for the optimized
  rendering path" / "compact bit-per-tile representation"), which is stale and
  actively misleading for anyone (or any future Claude session) trying to
  understand or fix the real dirty-rendering implementation — they'll go looking
  in the wrong file.
- It's a loose end left over from an earlier, apparently-abandoned attempt at
  this exact feature, which corroborates the "experimental, never fully
  finished" framing directly.

**Fix:** either delete `ppu_dirty.s` (it's excluded from the build and unrelated
to the live implementation), or repurpose/finish it and wire it in — but either
way, update `CLAUDE.md`'s file listing to point at the actual live files
(`ppu.s`, `ppu_tiles.s`, `scanline_bitmap.s`, `ppu_render.s`) instead.

### 3. No invalidation of the compiled-tile cache on CHR-RAM pattern-table writes or pattern-table (bgadr/spadr) switches

Per `src/MemoryMap.md`'s own documentation, the background compiled-code cache
(written by `CompileTile`, read by `DrawPPUTile`) is a 256-entry, **tile-ID-only**
cache — it does not distinguish which pattern table ($0000 vs $1000) a tile ID
was compiled from. `src/MemoryMap.md` explicitly notes: *"the PPU ... independently
selects which [pattern table] sprites read from and which the background reads
from ... and for CHR-RAM games, changeable by the game at any time — **Zelda does
this**."*

Checked `src/ppu/ppu_regs.s`'s PPUCTRL write handler (where `bgadr`/`spadr`
actually change): it updates `bgadr`/`bgadr_hi`/`bgadr_lo` but sets **no**
`DirtyBits` flag and calls no refresh/recompile routine. Separately,
`NES_RenderFrame`'s "force a full update" check (`scaffold.s` ~line 438-449) only
looks at whether the **nametable/attribute** queues (`prev_nt_list`/`prev_at_list`)
are non-empty — it has no visibility into CHR-RAM pattern-table writes
($0000-$1FFF), which are a completely separate write channel from nametable
writes ($2000-$2FFF).

Net effect: if Zelda ever redefines a currently-on-screen tile's CHR-RAM bitmap
(or switches `bgadr`) **without** also writing new nametable bytes for the
positions using it, the compiled PEA-field code for those on-screen positions
goes stale, and — under dirty rendering specifically — nothing forces a
full-screen recompile+redraw to paper over it (`DIRTY_BIT_BG0_REFRESH` never
gets set), so a stale/wrong-table tile can stay wrong indefinitely instead of
self-correcting on the next full-render frame.

**Important caveat:** this gap likely predates dirty rendering and would affect
full-render mode too (full render doesn't force a `DrawPPUTile` recompile pass
either, outside of the nametable-write queue and the palette-change-triggered
`RefreshPPUTiles` call) — so it's plausible this is a **general, pre-existing
CHR-RAM limitation** that simply never got exercised because Zelda is the only
CHR-RAM game and this is the first time anyone compared its behavior against the
dirty-render path specifically. Likely a visual-corruption bug rather than a
crash, but worth fixing as part of this work since it's directly implicated by
"Zelda is the only game exercising both flags."

**Fix:** in the PPUCTRL write handler, `tsb DirtyBits, #DIRTY_BIT_BG0_REFRESH` (or
equivalent) whenever `bgadr` or `spadr` actually changes value (compare
old-vs-new the same way `NES_SetScrollX/Y` already do for scroll). Consider
whether CHR-RAM pattern writes to a tile ID currently visible on-screen should do
the same — that's a larger design question (would need to cross-reference
"which tile IDs are currently on-screen" cheaply) and may be out of scope for
just unblocking dirty rendering; flagging it here so it's a conscious decision
rather than an oversight.

### 4. The dirty-only render path has no equivalent of the full-render path's bounds assertions

`ppu_shadowlist.s`'s `exposeShadowList` (used by the **full**-render `drawScreen`)
has explicit sanity checks:
```asm
cmp  #201
bcc  *+4
brk  $66              ; <- comment: "Bug in BF after running for a long period of time -- hits BRK $66"
```
These `brk $44/$55/$66` checks have already caught at least one real historical
bug (per the inline comment). The dirty-only path (`WALK_BITMAP` macro in
`scanline_bitmap.s`, and its callers `_drawBackground`/`_exposeScreen` in
`ppu.s`) has **no equivalent assertions** on `walk_top`/`walk_bottom` before
they're handed to `_BltRangeLite`/`_PEISlam`. If `WALK_BITMAP`'s bit-scan ever
produces an out-of-range value for some bitmap pattern the tested games never
hit, it will silently blit at a bogus address rather than trip a clean,
diagnosable `brk`.

I traced `WALK_BITMAP`'s use of the `mul8`/`offset`/`invOffset`/`offsetMask`
lookup tables (`ppu_shadowlist.s`) against the same technique in the
already-proven `shadowBitmapToList`, and the generalized macro version is a
faithful reproduction (same rebasing trick, same tables) — I did not find a
correctness bug in the bit-scan logic itself. This finding is about **defense in
depth**, not a confirmed bug: add the same class of assertion so that *if* some
zelda-specific bitmap pattern does trip an edge case, it fails as a clean `brk`
at a known PC instead of a mysterious crash.

**Fix:** add `cmp #200/#201 / bcc *+4 / brk $NN`-style guards around
`walk_top`/`walk_bottom` in `_drawBackground`/`_exposeScreen`, mirroring
`exposeShadowList`'s pattern. Cheap, and turns any future "crashes immediately"
report into an instantly-actionable PC/register dump instead of a guessing game
like this one.

## Ruled out (checked and confirmed OK — don't re-derive these tomorrow)

- **Build/assembly correctness**: `ENABLE_DIRTY_RENDERING equ 1` assembles zelda
  cleanly with Merlin32, no errors or warnings. Confirmed by actually building it.
- **Startup initialization**: `EngineReset` (`core/CoreImpl.s`) unconditionally
  zeroes `DirtyState`/`DebugSCB`/`LastRender` and sets `DirtyBits = $FFFF` ("mark
  as needing a full update") before any frame renders — the first frame is always
  forced through the full-render path regardless of `HAS_CHR_RAM`, so this isn't
  an uninitialized-state-on-boot crash.
- **First-frame-after-nametable-switch staleness**: `NES_RenderFrame` forces a
  full update (`DIRTY_BIT_BG0_REFRESH`) on any frame where the nametable/attribute
  write queues are non-empty, so a `SwitchNameTablesReq`-driven nametable flip (as
  used heavily by Zelda's submenu and split-screen status bar) correctly forces a
  full redraw and a `DirtyState` reset before dirty rendering could resume —
  ruled out as a race between nametable switches and stale dirty-state.
- **`WALK_BITMAP`'s scanline-index arithmetic** (`{mul8-]2},y` rebasing trick):
  confirmed identical to the already-proven `shadowBitmapToList` full-render
  code, just parameterized. Not a bug.
- **`DIRTY_RENDERING_VISUALS`**: a separate, unrelated debug-overlay flag
  (defaults to 0 for all games), not implicated.
- **Missing routines**: `_BltSetupDirty`/`_BltSetupDirtyAlt` (`BlitterLite.s`),
  `drawDirtyScreen` (`ppu_render.s`), and all of `clearPreviousSprites` /
  `exposeCurrentSprites` / `drawOtherLines` (`ppu.s`) / `restoreTilesToScreen` /
  `exposeTilesToScreen` (`ppu_tiles.s`) exist and are substantively implemented,
  not stubs — this is a genuinely-written feature with a real bug in it
  somewhere, not an unfinished skeleton (aside from finding #2's dead file).

## Recommended plan for tomorrow

1. **Fix #1 first** (`sprBlockAddr` sizing) — it's cheap, unambiguous, and the
   single most likely crash cause. Widen the array to 128 entries and add a
   bounds `brk` (folds in finding #4's spirit for this specific site) so if it's
   *not* the cause, that becomes obvious immediately rather than silently
   papered over.
2. **If #1 doesn't fix it, add the debugger session this analysis couldn't do**:
   enable dirty rendering, break on `drawDirtyScreen`, and single-step the first
   few dirty frames. Specifically watch: `DirtyState` transitions, `SprAddrCount`,
   and the stack pointer during `saveTileFromScreen8/16` relative to
   `SprSaveTop`. (8x16 sprite usage is now confirmed by the user, so that part of
   the original watch-list is settled — no need to re-check `_ppuctrl` bit 5.)
   If the crash reproduces before `SprAddrCount` ever gets large, finding #1 is
   ruled out and the debugger trace itself will point at the real site much
   faster than more static reading would.
3. If #1 doesn't explain it, apply finding #4's assertions and re-run — turn the
   unknown crash into a `brk` with a known PC/register state, then work backward
   from there.
4. Independent of the crash: fix #2 (delete or finish `ppu_dirty.s`, correct the
   `CLAUDE.md`/agent-doc references) and consider #3 (bgadr/spadr change
   invalidation) as correctness follow-ups — neither blocks getting dirty
   rendering working, but #3 in particular could cause silent visual corruption
   once the crash is fixed, undermining confidence that the feature "works" even
   after it stops crashing.

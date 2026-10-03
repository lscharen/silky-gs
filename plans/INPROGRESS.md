# In-progress: sprite CHR-RAM recompile fix + drawSprites restructure

## Background / root cause

Sprites aren't appearing for HAS_CHR_RAM games. Root cause: `drawSprites`
(`src/ppu/ppu.s`) does `phb / pea #^tiledata / plb` once at the top of the
OAM loop, forcing DB=`^tiledata` for the whole loop (needed by the compiled
sprite blitters, which read/write the tiledata bank via plain `abs,x`/`abs,y`
addressing that's DBR-relative). `drawSprite8x8` calls `CheckSprTileDirty`
*inside* that DB=`^tiledata` window. When a sprite tile is dirty,
`CheckSprTileDirty` calls `ConvertROMTile2` (`src/rom/rom_tiles.s`), which
decodes into `TileBuff` via `(dp),y`-style *short* indirect addressing --
DBR-relative, not DBR-independent. `TileBuff` lives in the program's own
bank (it's `put` inline into each game's `Main.s`), not the `tiledata` bank.
So while DB is wrongly forced to `^tiledata`, all of `ConvertROMTile2`'s
reads/writes to `TileBuff` silently land at the same offset *inside the
tiledata bank* instead -- corrupting real tile data / producing garbage
sprite tiles. Background tiles don't hit this because nothing forces DB away
from the program bank before `ConvertROMTile3` is called for them.

## Two-part fix (per user's direction)

1. **Stop going through `TileBuff` for sprites at all.** There's already a
   `FastROMTileToLookup` routine (`src/rom/rom_tiles.s`) that writes
   background pixel data directly into the `tiledata` bank via a far/long
   pointer (`TileDataPtr` = `tmp0`, `sta [TileDataPtr],y`), sidestepping DBR
   entirely. Build a sprite-equivalent, `FastROMTileToLookupMasked`, that
   also writes straight into `tiledata` -- no `TileBuff`, no DBR dependency
   -- producing the same full 128-byte layout `ConvertROMTile2` does:
   `[0..31]` bitmap normal, `[32..63]` mask normal, `[64..95]` bitmap
   h-flipped, `[96..127]` mask h-flipped.

2. **Narrow the DB=`^tiledata` window in `drawSprites`.** Two options were
   offered; user leaned toward *lifting the `CheckSprTileDirty` checks into a
   pre-pass that runs before the OAM draw loop* (so the DB switch and the
   dirty-tile recompile are fully decoupled), as opposed to delaying the DB
   switch down into just the `as_bitmap`/compiled-sprite dispatch point
   inside `drawSprite8x8` (harder to do cleanly since `as_bitmap` is entered
   via `jmp`, not `jsr`, so there's no return point inside `drawSprite8x8` to
   restore DB at). Once `CheckSprTileDirty` no longer touches `TileBuff`/DBR
   at all, this becomes an architecture/testability cleanup rather than a
   strict correctness requirement -- but it's still worth doing for the
   separation of concerns (and it was explicitly requested).

## `FastROMTileToLookupMasked` design (verified in JS, see below)

**Chosen approach** (user picked "fully table-driven, no reverse2/reverse4"
for pixel/mask; reverse4 is still reused for the mask's h-flip word, per the
hedge in that option's own description):

1. `pha` (save destination offset) `/ jsr FastROMTileToLookup` (does the
   actual CHR-ROM decode, writes tiledata[dest..dest+31] pixel bitmap,
   trashes A/X/Y) `/ pla`.
2. Re-establish `TileDataPtr` (reuse the same `tmp0`-based pointer
   `FastROMTileToLookup` itself uses -- it's already done with it by the
   time we set it again, so no new DP allocation needed; just reference the
   existing global `TileDataPtr` symbol, don't redeclare it).
3. For each of the 8 rows (`:rowbase` running 0,4,8,...,28):
   - Read back the two stored pixel words (word0 at `rowbase+0`, word1 at
     `rowbase+2`) via `lda [TileDataPtr],y`.
   - **Reconstruct the pre-shift "combined" byte** for each word with a
     single 16-bit `LSR`: a stored word's low byte is always even (it's
     `(combined<<1)&$FF`) and its high byte is only ever 0 or 1 (the
     shifted-out carry = combined's original bit 7). `LSR` of the whole
     16-bit word (`hi*256+lo`) yields `hi*128 + (lo>>1)` -- bit 7 restored
     from `hi`, bits 6-0 restored from `lo`, in one instruction.
   - **Mask** (normal orientation): `MASKLUT_HI[combined]` / `MASKLUT_LO[combined]`
     give the two mask bytes (derived by inverting `DLUT2`, see below), write
     as a word at `rowbase+32` / `rowbase+34`.
   - **H-flip pixel**: `HFLIPLUT[combined1]<<1` -> word0 slot (`rowbase+64`),
     `HFLIPLUT[combined0]<<1` -> word1 slot (`rowbase+66`) (word0/word1 swap
     on flip, same as `ConvertROMTile2`). The `<<1` uses the same
     `asl / lda #0 / rol` carry-extend idiom `FastROMTileToLookup` already
     uses for its own shift-by-1 step.
   - **H-flip mask**: `reverse4(mask1)` -> `rowbase+96`, `reverse4(mask0)` ->
     `rowbase+98` (existing, already-tested routine, word-level nibble+byte
     reverse -- not re-tabled, per the accepted hedge in the chosen design
     option).
4. `:rowbase += 4`, loop 8 times, `rts`.

### New tables to derive/add (256-entry `db` tables in `rom_tiles.s`)

- `MASKLUT_HI[c]` = `MLUT4[invDLUT2[c>>4]]`
- `MASKLUT_LO[c]` = `MLUT4[invDLUT2[c&$0F]]`
- `HFLIPLUT[c]` = `reverse2(c)` (i.e. `DLUT2`'s bit-pair-reversal baked into
  a table)

where `invDLUT2` is `DLUT2`'s inverse (`DLUT2` is a bijection over 0..15,
verified in the derivation script).

**This whole algorithm (including exact table contents) was already derived
and verified** against `scripts/lib/nesTileConvert.js`'s `convertRomTile2()`
ground truth: 20,000/20,000 random tiles matched byte-for-byte (plus
all-zero and all-`$FF` edge cases), using the scratch script at
`C:\Users\lscharen\AppData\Local\Temp\claude\C--checkout-silky-gs-ref\57d7a4e0-4554-49cc-9591-33e377b3abbf\scratchpad\derive_mask_luts2.js`
(this path is a per-session temp dir and may not exist anymore -- the script
is short, self-contained, and reproducible from the description above if
needed; it also prints ready-to-paste `db` table text for all three tables).
That script's output (verbatim, already correct) for the three tables:

```
MASKLUT_HI  db    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
            db    $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0
            db    $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0
            db    $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0
            db    $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

MASKLUT_LO  db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00
            db    $FF,$F0,$F0,$F0,$0F,$00,$00,$00,$0F,$00,$00,$00,$0F,$00,$00,$00

HFLIPLUT    db    $00,$40,$80,$C0,$10,$50,$90,$D0,$20,$60,$A0,$E0,$30,$70,$B0,$F0
            db    $04,$44,$84,$C4,$14,$54,$94,$D4,$24,$64,$A4,$E4,$34,$74,$B4,$F4
            db    $08,$48,$88,$C8,$18,$58,$98,$D8,$28,$68,$A8,$E8,$38,$78,$B8,$F8
            db    $0C,$4C,$8C,$CC,$1C,$5C,$9C,$DC,$2C,$6C,$AC,$EC,$3C,$7C,$BC,$FC
            db    $01,$41,$81,$C1,$11,$51,$91,$D1,$21,$61,$A1,$E1,$31,$71,$B1,$F1
            db    $05,$45,$85,$C5,$15,$55,$95,$D5,$25,$65,$A5,$E5,$35,$75,$B5,$F5
            db    $09,$49,$89,$C9,$19,$59,$99,$D9,$29,$69,$A9,$E9,$39,$79,$B9,$F9
            db    $0D,$4D,$8D,$CD,$1D,$5D,$9D,$DD,$2D,$6D,$AD,$ED,$3D,$7D,$BD,$FD
            db    $02,$42,$82,$C2,$12,$52,$92,$D2,$22,$62,$A2,$E2,$32,$72,$B2,$F2
            db    $06,$46,$86,$C6,$16,$56,$96,$D6,$26,$66,$A6,$E6,$36,$76,$B6,$F6
            db    $0A,$4A,$8A,$CA,$1A,$5A,$9A,$DA,$2A,$6A,$AA,$EA,$3A,$7A,$BA,$FA
            db    $0E,$4E,$8E,$CE,$1E,$5E,$9E,$DE,$2E,$6E,$AE,$EE,$3E,$7E,$BE,$FE
            db    $03,$43,$83,$C3,$13,$53,$93,$D3,$23,$63,$A3,$E3,$33,$73,$B3,$F3
            db    $07,$47,$87,$C7,$17,$57,$97,$D7,$27,$67,$A7,$E7,$37,$77,$B7,$F7
            db    $0B,$4B,$8B,$CB,$1B,$5B,$9B,$DB,$2B,$6B,$AB,$EB,$3B,$7B,$BB,$FB
            db    $0F,$4F,$8F,$CF,$1F,$5F,$9F,$DF,$2F,$6F,$AF,$EF,$3F,$7F,$BF,$FF
```

## DP scratch allocation (avoid colliding with `reverse4`'s internal `tmp0`/`tmp1`)

`reverse2`/`reverse4` (both already in `rom_tiles.s`) hardcode `tmp0`/`tmp1`
as their own scratch. `FastROMTileToLookup` also uses `tmp0` (as
`TileDataPtr`, a 3-byte far pointer: `tmp0`/`tmp0+1` = addr, `tmp0+2` =
bank, which spills into `tmp1`'s low byte) and `tmp3`/`tmp4` internally.
Since `FastROMTileToLookupMasked` calls `FastROMTileToLookup` *first* and
only starts using its own scratch *after* that call returns, it's safe to
reuse `TileDataPtr` (`tmp0`) directly (just re-set it after the call, don't
redeclare the `TileDataPtr equ tmp0` symbol -- it's already a global equ
from `FastROMTileToLookup`, redeclaring it under the same name will error
as a duplicate symbol in Merlin32). For its own row-loop scratch, avoid
`tmp0`/`tmp1` (needed clean for the `reverse4` calls used for mask h-flip)
and pick fresh cells: `tmp2` (`:combined0`), `tmp3` (`:combined1`), `tmp4`
(`:mask0`, word), `tmp5` (`:mask1`, word), `tmp7` (`:rowbase`), `tmp8`
(`:rowcount`). Real DP addresses (`src/core/Defs.s`): `tmp0`=240, `tmp1`=242,
`tmp2`=244, `tmp3`=246, `tmp4`=248, `tmp5`=250, `tmp6`=252, `tmp7`=254,
`tmp8`=224 (different block -- `tmp8`-`tmp15` live at 224-239, not
contiguous with `tmp0`-`tmp7`). `tests/rom/rom_tiles.test.mjs`'s `STUBS`
block currently only defines `tmp0`-`tmp4`; it'll need `tmp5`, `tmp7`, and
`tmp8` added (matching these real addresses) before a test that exercises
`FastROMTileToLookupMasked` will assemble.

## Register-width bookkeeping (worked out, not yet re-verified in the harness)

- Routine entry: `mx %00` (16-bit A/X/Y), matching `FastROMTileToLookup`'s
  own convention.
- `pha` (16-bit, save dest offset) / `jsr FastROMTileToLookup` (returns with
  `rep #$30`, i.e. guaranteed 16-bit) / `pla` (16-bit, matches).
- Row-word reconstruction (`lda [TileDataPtr],y` / `lsr` / `sta :combinedN`):
  16-bit throughout (need the full word for the LSR trick).
- `sep #$20` for the `MASKLUT_HI`/`MASKLUT_LO`/`HFLIPLUT` indexed byte
  loads and their `sta`s (X can stay 16-bit the whole routine -- it's never
  toggled with `sep #$10`/`rep #$10`; `ldx :combinedN` in 16-bit-X mode is
  fine since `:combinedN` is a clean 0-255 value with its high byte
  guaranteed zero after the `lsr`).
- `rep #$20` needed before each `:rowbase`-relative `adc #const` / `tay`
  (16-bit address arithmetic), then back to `sep #$20` for the actual
  byte-by-byte `[TileDataPtr],y` stores (Y's width is untouched by `sep
  #$20`/`rep #$20`, which only gates the M/A flag, so this interleaving is
  safe).
- `rep #$20` before both `reverse4` calls (needs 16-bit A for its internal
  `xba`), and it returns with A's width unchanged by `reverse4` itself (no
  `php`/`plp` in `reverse4`, unlike `reverse2`).
- End of each row iteration (`:rowbase += 4`, `dec :rowcount`, `bne
  :rowloop`): 16-bit, consistent with how `:rowcount` was initialized.

None of this has been typed into `rom_tiles.s` yet -- the last edit attempt
was rejected because the user wants to hand-write `FastROMTileToLookupMasked`
themselves. This file exists so that work (or a restart of it) can pick up
from here without re-deriving the tables or the width bookkeeping.

## Resolution: `FastROMMaskedTileToLookup` (implemented, replaces the plan above)

The routine that shipped is **not** `FastROMTileToLookupMasked` per the
MASKLUT_HI/MASKLUT_LO/HFLIPLUT design above -- the user hand-wrote a
different, more efficient design instead, called `FastROMMaskedTileToLookup`
(`src/rom/rom_tiles.s`). Both approaches solve the same problem (produce the
full 128-byte `ConvertROMTile2` layout without touching `TileBuff`/DBR); the
difference is table shape and per-word vs per-byte processing. The section
above is kept for history/context; this section documents what's actually in
the tree.

**Design.** `FastROMMaskedTileToLookup(A = tileID*128 destination offset in
tiledata, X = CHR-ROM source address)`:
1. `jsr FastROMTileToLookup` -- writes the normal bitmap `[0..31]` exactly
   as before (unchanged).
2. `phb / pea #^tiledata / plb` -- switches DB to the tiledata bank for the
   rest of the routine (3 bytes pushed, 3 `plb`s pop them at the end,
   restoring the caller's original DB).
3. `ldy TileDataPtr` -- `TileDataPtr` (`tmp0`) still holds the destination
   address `FastROMTileToLookup` was just called with; Y becomes the running
   *absolute* row offset for the rest of the routine.
4. Row loop (8 iterations, `y += 4`, terminated by `tya / and #$001F / bne`
   -- relies on the caller's starting address being 32-byte aligned, true
   for every real caller since tiles are always `tileID*128`): for each
   row's two words (`word0` at `y+0`, `word1` at `y+2`), look up
   `TILE_MASK[word]` (mask, normal orientation) and `TILE_REVERSE[word]`
   (bitmap, h-flipped -- written to the *sibling* word's slot, i.e. `word0`'s
   reverse goes to `+66`/`word1`'s flip slot and vice versa, reproducing
   `ConvertROMTile2`'s cross-word swap), then re-looks-up `TILE_MASK` on the
   already-reversed value to get the h-flip mask (avoids needing a separate
   `reverse4`-based path -- see the identity check below).
5. All addressing in the loop is `label+N,y` (e.g. `ldx: 0,y`, `sta: 32,y`)
   -- plain absolute-indexed-by-Y, not indirect-through-a-pointer. This is
   why it's DBR-safe rather than DBR-independent-by-construction like
   `FastROMTileToLookup`: it works because Y itself carries the full
   absolute destination address and DB is pinned to `^tiledata` for the
   duration, not because it avoids caring about DB.

**`TILE_MASK`/`TILE_REVERSE` tables.** Two 512-byte tables indexed directly
by a tiledata pixel word (`word = combined << 1`, always even, so each table
is really 256 addressable 16-bit entries laid out as flat bytes -- `ldal
TABLE,x` with 16-bit A reads `TABLE[x]`/`TABLE[x+1]` as the low/high byte of
one result). Derived and verified in
`C:\Users\lscharen\AppData\Local\Temp\claude\...\scratchpad\derive_tile_mask_reverse.js`
(session-scoped temp path, reproducible from this description): for every
`combined` byte 0-255, `TILE_MASK[combined<<1]` = the two `MLUT4[invDLUT2[nibble]]`
mask bytes ConvertROMTile2 would produce for that word, packed into one
16-bit value; `TILE_REVERSE[combined<<1]` = `reverse2(combined) << 1`. Two
things were checked before committing the tables:
- **Identity**: `TILE_MASK[TILE_REVERSE[w]] == reverse4(TILE_MASK[w])` for
  all 256 combined values (0 failures) -- this is what justifies step 4's
  double-lookup instead of a `reverse4` call for the h-flip mask.
- **End-to-end**: a JS model of the exact row-based algorithm above,
  running on 20,000 random tiles + zero/solid edge cases, matched
  `convertRomTile2()` (the existing verified ground truth) byte-for-byte on
  every one.

**Bugs found and fixed during development** (all in `FastROMMaskedTileToLookup`
itself, not in the tables):
1. *Stack imbalance*: an early draft did `phb / lda #^tiledata / pha / plb`
   while A was 16-bit (left that way by `FastROMTileToLookup`'s trailing
   `rep #$30`), pushing 2 bytes but popping only 1. Fixed by switching to
   `pea #^tiledata` (always pushes exactly 2 bytes) with a matching 2nd
   `plb` at the end.
2. *Missing `,y` index*: the h-flip mask store was briefly `sta
   tiledata+96` instead of `sta tiledata+96,y`, so every row clobbered the
   same 2 bytes instead of filling `[96..127]`.
3. *Missing word0/word1 swap*: an early draft looked up `TILE_REVERSE[word]`
   and stored it back at the *same* word's offset, which just reverses bits
   in place rather than performing a real horizontal flip (which must also
   swap which half of the row each word ends up in). Fixed by writing each
   word's reversed value to its *sibling's* slot, matching
   `ConvertROMTile2`'s `+64`/`+66` swap.
4. *Bank-zero addressing dependency*: the version that indexed via
   `tiledata+0,y` (label-relative, not just `0,y`) only worked when
   `tiledata`'s own link address was `$xx0000` -- true in the real build
   (`TileData.s` reserves a dedicated whole-bank segment) but not something
   to bake into the routine's correctness. Fixed by switching to pure
   `label+N,y`-style absolute-indexed addressing (`ldx: 0,y`, not `ldx:
   tiledata+0,y`) so the routine only ever depends on Y + DB, never on
   where the assembler happened to link the `tiledata` symbol.

**Tests.** `tests/rom/rom_tiles.test.mjs` gained a `FastROMMaskedTileToLookup`
describe block (5 sample tiles including a "staggered" fixture chosen to
exercise every combined-byte value across a tile, a non-zero CHR-ROM offset
case, and a CHR-ROM-not-mutated case), all checked against `convertRomTile2()`.
Getting these green required two more addressing lessons, both specific to
the *test harness* rather than the routine:
- The loop's `and #$001F` termination check needs the harness's `tiledata`
  buffer to start 32-byte aligned, same as real callers -- the assembler's
  default placement (right after the generated harness code) isn't
  guaranteed to be. Fixed by declaring `tiledata` via an inline stub with a
  `ds \,$00` page-boundary pad in front of it (256 is a multiple of 32) and
  reading it back with `captureMemory` instead of `allocMemory`.
- That inline-declared `tiledata` collides (duplicate label) with the
  file's shared 32-byte `tiledata` `allocMemory` stub (needed by the other
  describe blocks, since `FastROMTileToLookup` references `^tiledata`
  unconditionally). Merlin32 doesn't reliably fail loudly on the duplicate
  -- the harness just silently never reaches `AUnit_WriteResults`. Fixed
  with a second, dedicated `cpu65816()`/`jsr` instance (`jsrMasked`) for
  just this describe block, with no shared `tiledata` alloc.

All 29 tests in `tests/rom/rom_tiles.test.mjs` pass.

## `CheckSprTileDirty` updated (`src/ppu/ppu.s`)

`CheckSprTileDirty` now calls `FastROMMaskedTileToLookup` directly instead
of `ConvertROMTile2` + `TileBuff` + the manual `:sprcploop` copy loop. The
tile-ID-derived CHR-RAM source address computation (`X`) is unchanged; the
tile-ID*128 computation that used to become the copy loop's `X` index now
becomes the `A` argument to `FastROMMaskedTileToLookup` instead, and the
copy loop is gone entirely (the routine writes straight into `tiledata`).

**DBR-corruption bug: confirmed fixed, not just worked around.**
`FastROMMaskedTileToLookup` never touches `TileBuff` and never relies on
what DB happens to be when it's called -- point 5 in the Resolution section
above (`label+N,y` addressing) means the only place DB matters is the
routine's own internal `phb/pea/plb` window, which it establishes and tears
down itself. So it's safe to call from inside `drawSprites`' `DB=^tiledata`
window (where `CheckSprTileDirty` is still invoked, per
`drawSprite8x8` line ~507) exactly like the old broken call was, but without
the corruption: there's no more `TileBuff`-via-short-addressing step for a
wrong DB to alias into the tiledata bank.

Verified two ways:
- **Static**: re-read the addressing in both routines end to end (no `(dp),y`
  or bank-relative absolute access to anything outside `tiledata` remains
  anywhere in the call path).
- **Build**: `npm run build:zelda` (Zelda is the only `HAS_CHR_RAM` game in
  this tree -- the other games' builds are currently broken for unrelated,
  pre-existing reasons on this branch) assembles and links cleanly
  end-to-end with the updated `CheckSprTileDirty`, and the output listing
  confirms both `CheckSprTileDirty` and `FastROMMaskedTileToLookup` resolve
  to real addresses in the same segment as before.

**Still open, no longer a correctness requirement**: step 5 from the old
plan (lifting `CheckSprTileDirty` into a pre-pass before `drawSprites`'
`phb/pea/plb` DB switch, so the DB-narrowing and the dirty-tile recompile
are decoupled) was *not* done. It's now purely an architecture/testability
cleanup, not a bug fix, since `FastROMMaskedTileToLookup` no longer cares
what DB is on entry. Worth doing later for separation of concerns, but not
blocking.

## Legacy helper removal assessment

Asked: can `ROMTileToBitmap`, `ConvertROMTile2`, `ROMTileToLookup`,
`ConvertROMTile3`, `TileBuff`, `reverse2`, `reverse4`, `DLUT2`,
`DLUT2_shft`, `DLUT4`, `MLUT4` now be removed from the project, now that
`FastROMMaskedTileToLookup`/`FastROMTileToLookup` exist?

**No -- most of them are still live**, just not from `CheckSprTileDirty`
anymore:

| Symbol | Still used from | Can remove? |
|---|---|---|
| `ConvertROMTile3` | `ppu_attributes.s`, `ppu_metatiles.s` -- background CHR-RAM tile recompile-on-dirty (a *different* code path from the sprite one just fixed; not inside any `DB=^tiledata` window per the original bug analysis, so never had the DBR bug) | No |
| `ROMTileToBitmap` | Internally by `ConvertROMTile3` (live, see above); also by `rom_chrram.s`'s `ConvertCHRTileBG`, which is **not wired into any live PPU path** (explicitly documented as a standalone building block awaiting a future `DrawPPUTile`/`RefreshMetatile` rework) | No (still needed by `ConvertROMTile3`) |
| `ConvertROMTile2` | `rom_helpers.s`'s `ROM_LoadSpriteTiles` -- the **startup-time**, non-CHR-RAM sprite tile loader (converts the whole static sprite CHR-ROM once at boot). Same `TileBuff`+copy-loop pattern `CheckSprTileDirty` used to have, but this call site runs at startup outside `drawSprites`' DB window, so it isn't DBR-buggy -- just unmodernized. `FastROMMaskedTileToLookup` could replace it too (same output, fewer instructions, no `TileBuff` bank hazard) but that's a separate, optional follow-up, not something this task touched | No (still called; migrating it is future work) |
| `ROMTileToLookup` | Internally by `ROMTileToBitmap` and `ConvertROMTile2` (both live, see above) | No |
| `TileBuff` | `ConvertROMTile3`, `ConvertROMTile2`, `ppu_attributes.s`, `ppu_metatiles.s`, `rom_helpers.s` (`ROM_LoadSpriteTiles`), `rom_chrram.s` (`ConvertCHRTileBG`) | No -- still the shared scratch buffer for every remaining legacy call site |
| `reverse2` | Internally by `ROMTileToBitmap` and `ConvertROMTile2` (both live) | No |
| `reverse4` | Internally by `ConvertROMTile2` (live) | No |
| `DLUT2`, `DLUT2_shft`, `MLUT4` | Internally by `ROMTileToLookup`/`ROMTileToBitmap`/`ConvertROMTile2` (all live) | No |
| `DLUT4` | **Nothing** -- grepped the whole tree, only its own declaration and a mention in the file's export-list comments reference it. Looks like it's been dead since before this session's work (not something introduced here) | **Yes** -- safe to delete, unrelated to this task |

**Also worth noting**: `scripts/lib/nesTileConvert.js`'s `romTileToBitmap`/
`convertRomTile2` JS functions back `scripts/convert-chr-rom.js` (an
offline static-table build tool), and their accompanying vitest coverage
exists specifically to prove that JS model matches the real 65816 code
byte-for-byte. So even in a hypothetical future where every ASM call site
above got migrated to the `FastROM*` routines, the ASM originals (and their
tests) would still need to stay in the tree as long as `convert-chr-rom.js`
depends on the JS transliteration being provably correct -- unless that
script is also rewritten against a `FastROM*`-based JS model instead.

**Bottom line**: nothing from the legacy set is removable right now except
the already-dead `DLUT4` table. The rest are all still reachable from real
(if not currently DBR-buggy) call sites; removing any of them is a separate
migration task per call site (`ROM_LoadSpriteTiles`, `ConvertCHRTileBG`,
`ConvertROMTile3`'s two PPU call sites), not a cleanup that falls out of
this fix.

## CHR-RAM dirty-tracking bug: spadr/bgadr weren't being respected

After `CheckSprTileDirty` started calling `FastROMMaskedTileToLookup`,
sprites still weren't drawing for Zelda -- the tiles in `tiledata` came out
blank (`$0000` bitmap, `$FFFF` mask, i.e. never actually written). Root
cause, found while reviewing what changed: a mismatch between how
`PPUDATA_WRITE` (`ppu_regs.s`) marks CHR-RAM tiles dirty and how the
draw-time code was checking for that.

**The governing principle** (write this down so it doesn't get relitigated):
how the engine tracks and reads CHR-RAM has to match what the NES console
itself would do -- CHR-RAM is one physical 8KB space with two 4KB pattern
tables, and the PPU's sprite/background pattern-table-select bits (PPUCTRL
bits 3/4, tracked at runtime as `spadr`/`bgadr` in `ppu_regs.s`) determine
which half is actually in play at any given moment. Every place that reads
raw CHR-RAM bytes or checks/clears a dirty flag for them must respect
whichever table is *currently selected*, full stop. `tiledata` and the
compiled-code banks are the IIgs engine's own internal cache structures --
implementation details, not NES hardware -- and their layouts follow from
convenience, not from the hardware constraint above:
- `tiledata` happens to have room for all 512 (tile ID x pattern table)
  combinations in one 64KB bank (256 tiles x 128 bytes/tile x 2 tables =
  65536), so sprite *and* background CHR-RAM source data both keep their
  table-select bit all the way through to the `tiledata` address -- see
  `FastROMMaskedTileToLookup`'s `X = CHR-RAM source address` and its
  `A = tiledata destination`, both derived from the same `(tileID |
  spadr_lo)`/`(tileID | bgadr_lo)` combined index, no stripping.
- The **compiled-code** destination banks (background: `patch1-4`'s target,
  written via `CompileTile`; sprites: `spr_comp_tbl`/`CompileSprite`) are a
  *separate*, smaller cache split by sprite-vs-background for engine
  data-management reasons (sprites and background tiles are compiled/
  dispatched completely differently), and each only has room for 256 tile
  IDs, not 512. So the destination *page* argument passed to `CompileTile`
  must be tile-ID-only (`combined & $00FF`, scaled by 256) -- unlike
  `tiledata`, this one does NOT get the pattern-table bit folded in. Get
  this wrong and it's not just "wrong tile" -- since the two 256-tile-ID
  pages sit at a fixed stride, adding the table bit before scaling by 256
  overflows 16 bits and wraps into a *different* tile ID's page, corrupting
  unrelated compiled code. (`CheckBgTileDirty`, `ppu_metatiles.s`, exploits
  this overflow deliberately, on purpose, in the *other* direction: it
  computes `combined*128` once for the tiledata/source addresses, then
  reuses that same value with one more `asl` to get `tileID*256` -- the
  table-select bit sitting in bit 15 shifts out into carry and is discarded,
  which is exactly the masking it needs, without a separate `and`.)

**Fixed at three call sites**, all with the same shape (merge in a derived
`spadr_lo`/`bgadr_lo` 0-or-$0100 value before indexing `ChrRamDirty`, since
`PPUDATA_WRITE` marks it dirty across the full 0-511 range spanning both
pattern tables, and reuse that combined index -- not the raw tile ID -- to
derive the CHR-RAM source address too):
- `CheckSprTileDirty` (`ppu.s`) -- sprites. Also restructured along the way
  to index `ChrRamDirty` via `long,X` addressing directly (`ldal
  ChrRamDirty,x` / `stal ChrRamDirty,x`) instead of a direct-page indirect
  pointer, freeing Y and removing the need for a DP pointer to the array at
  all. `SprChrMem` (the old fixed `ChrRamDirty+$100` pointer this replaced)
  is now unreferenced dead code -- still initialized in `scaffold.s` but
  nothing reads it.
- `DrawPPUTile` (`ppu_attributes.s`) -- background, single-tile path.
- `CheckBgTileDirty` (`ppu_metatiles.s`) -- background, metatile path (calls
  `FastROMTileToLookup`+`CompileTile` directly now instead of
  `ConvertROMTile3`+`TileBuff`, same motivation as the sprite-side
  `FastROMMaskedTileToLookup` migration).

New derived state in `ppu_regs.s`, updated on every `PPUCTRL` write
alongside `spadr`/`bgadr` themselves: `spadr_hi`/`bgadr_hi` (`$8000` or
`$0000`) and `spadr_lo`/`bgadr_lo` (`$0100` or `$0000`). Only `spadr_lo`/
`bgadr_lo` ended up used so far (the `_hi` values are folded in implicitly
via the extra `asl`s once the low-bit merge has happened); `spadr_hi`/
`bgadr_hi` are currently unreferenced, kept for symmetry/potential future
use.

`src/MemoryMap.md`'s description of `tiledata` (which implied background
tiles live in a fixed second-half-of-the-bank, tile-ID-only region) predated
this fix and was stale -- now updated to describe the table-aware,
shared-512-slot addressing above, and the sprite/background compiled-code
split's *different* (tile-ID-only) indexing.

Verified with `npm run build:zelda` after each change (clean assemble/link
throughout); not yet verified in the emulator.

## Remaining steps

- Optional: restructure `drawSprites`' DB scope (old step 5 above) for
  separation of concerns -- no longer a correctness fix.
- Optional follow-up: migrate `ROM_LoadSpriteTiles`
  (`rom_helpers.s`) from `ConvertROMTile2`+`TileBuff` to
  `FastROMMaskedTileToLookup`, same motivation as the `CheckSprTileDirty`
  change, lower urgency since it isn't DBR-buggy.
- Not yet done: actually test sprites rendering in the emulator for a
  `HAS_CHR_RAM` game (Zelda) -- `npm run build:zelda` assembles/links
  cleanly, but this session didn't run it in GSPort/KEGS.

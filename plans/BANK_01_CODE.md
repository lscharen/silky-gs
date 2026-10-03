# Bank 1 "Common RAM Code" Block — Banking Bug Report

## Summary

The Zelda conversion has a WRAM-resident code block (originally NES $6000-$7FFF
battery-backed RAM, used so the original cartridge could call these routines from
any currently-switched-in PRG bank) that is now broken by the MMC1 banking rewrite.
The bug is **systemic**, not local: 331 cross-bank call sites assume the block lives
wherever the caller's own bank happens to be, but only one bank's copy is ever
populated at runtime.

This is the same class of bug as the confirmed `_TableJump` regression
(`src/games/zelda/src/rom_07_fixed.s:294`) — code whose correctness depends on which
ROM bank is mapped in when a stored/computed address is dereferenced — but manifests
at ordinary call sites (`JSR`/`JMP`) rather than at a stack-popped return address.

**No fix has been applied for this issue.** `CopyCommonCodeToRam`'s load-side pointer
bug (a separate, narrower issue) has already been fixed directly in
`src/games/zelda/src/rom_01.s:1627` (see "Related, already-fixed issue" below). Everything
in this document is still open.

## The two conflicting "homes" for the block

1. **`src/games/zelda/src/rom_01.s:2776`** — `org $6C90` causes the block to be
   *assembled in place* inside bank 1's own physical 65816 image. Confirmed via
   the build's symbol table (`ZeldaGS_Symbols.txt`): `ZROM01;...;00/6C90;BeginUpdateMode`.
   Bank 1's `$6C90-$7F00` therefore contains a valid, ROM-resident copy of the block
   as a side effect of ordinary assembly — nobody has to copy anything for bank 1
   itself to have working code there.

2. **`CopyCommonCodeToRam`** (`rom_01.s:1627`, called from `rom_07_fixed.s:1265` and
   `:1349`) copies the same bytes from ROM (`CommonCodeBlock_Bank1`, the bank-private
   load address) to RAM at runtime via `STA ($03),Y`. The data bank register (DBR) is
   permanently pinned to `^ROMBase` (bank 0) for the whole run
   (`src/rom/rom_exec.s:43-45`), and all ordinary absolute/`(dp),Y` addressing goes
   through DBR — so **this copy always lands in bank 0's physical `$6C90-$7F00`**,
   never bank 1's or any other bank's.

These two homes disagree, and nothing reconciles them.

## Why this breaks almost every caller

Each of the 7 switchable NES PRG banks (`rom_00.s` … `rom_06.s`) is assembled into
its own distinct, non-aliased 65816 memory bank (consecutive physical banks assigned
by the OMF linker, `KND #$1100` per `Master.s`). The program bank register (PBR/K)
tracks whichever bank `SwitchBank` (`src/rom/rom_inject.s:120-160`) last switched to,
and **stays there** — a plain 16-bit `JSR`/`JMP` never reads or changes it; it always
fetches from the *current* K, using the 16-bit operand as an offset within that bank.

So a short `JSR SomeRamBlockRoutine` only reaches real code if K happens to equal
whichever bank actually has valid bytes at `$6C90` — bank 1 (via its in-place
assembly) or, in principle, bank 0 (via the runtime copy, which per the point above is
actually unreachable by any short call — see Finding 6). Every other bank
(`rom_00.s:49`, `rom_02.s:111`, `rom_03.s:32`, `rom_04.s:176`, `rom_05.s:130`,
`rom_06.s:37`) fills that address range with zero bytes at assembly time (`ds $6000-*`
padding), which is `BRK` when executed.

## Findings

### Finding 1 — `rom_07_fixed.s`: at least 4 confirmed-wrong call sites, ~70 more unresolved

`rom_07_fixed.s` is `put` into every one of the 8 banks and therefore runs at
whatever K happens to be current. It contains 74 short calls into the block. Four are
traced to a *known-wrong* K:

| Call site | Instruction | Target | K at call |
|---|---|---|---|
| `rom_07_fixed.s:2076` | `JMP World_ChangeRupees` | `rom_01.s:2797` | 5 (set at `:2073-2074`, `LDA #$05 / JSR SwitchBank`) |
| `rom_07_fixed.s:749` | `JMP UpdatePositionMarker` | `rom_01.s:4104` | 5 (set at `:743-744`) |
| `rom_07_fixed.s:1248` | `JSR Add1ToInt16At0` | `rom_01.s:4204` | 5 (set at `:1240-1241`) |
| `rom_07_fixed.s:1642` | `JMP BeginUpdateMode` | `rom_01.s:2781` | 5 on the `:1637-1639` path; unconstrained on fallthrough |

All four land in bank 5's zero-filled `$6C90-$7F00`.

The remaining ~70 sites (`:824, :962, :1094, :1101, :1159, :1481, :1595, :1738, :1858,
:1980, :1984, :2042, :2069, :2115, :2363, :2423, :2438, :2649, :2701, :2739, :2800,
:2810, :2818, :2826, :3017, :3058, :3120, :3157, :3327, :3396, :3474, :3505, :3509,
:3543, :3574, :3664, :3714, :3823, :3894, :3907, :3966, :4093, :4158, :4231, :4235,
:4247, :4269, :4278, :4362, :4365, :4463, :4498, :4523, :4543, :4578, :4657, :4690,
:4720, :4724, :4749, :4758, :4765, :4833, :4875, :4884, :4931, :4961, :5052, :5054,
:5820`) are *suspected* rather than confirmed — K is inherited from whatever bank
called into `rom_07_fixed.s`'s shared code, so none of them is guaranteed safe either.

### Finding 2 — `rom_04.s`: 147 short calls, K is provably 4 — Confirmed

Bank 4 code only ever executes when `mapper_bank == 4`, so every one of these is
broken. Representative sites: `rom_04.s:275` (`JSR CheckLinkCollision`), `:292`
(`JMP DrawObjectNotMirrored`), `:695` (`JSR Negate`), `:870` (`JSR BoundByRoom`),
`:1026` (`JSR _CalcDiagonalSpeedIndex`), `:1219` (`JSR CheckMonsterCollisions`, 30
sites for this one target alone), `:8593` (`JSR DealDamage`), `:11400`
(`JSR TryTakeItem`), `:11751`/`:11757` (`JSR BoundDirectionHorizontally`/`Vertically`).

### Finding 3 — `rom_05.s`: 81 short calls, K is provably 5 — Confirmed

Representative: `rom_05.s:192` (`JSR UpdatePlayerPositionMarker`), `:954`/`:1390`/
`:1400`/`:6494` (`BeginUpdateMode`), `:2072` (`JSR FormatStatusBarText`), `:2330`
(`JMP SilenceAllSound`), `:5658` (`JSR UpdateWorldCurtainEffect`), `:7590`
(`JSR CheckMazes`), plus 25 `Add*Int16At*` calls.

### Finding 4 — `rom_02.s`: 29 short calls, K is provably 2 — Confirmed

`rom_02.s:312/3533/3808` (`JSR SilenceAllSound`); `:331,341,352,1903,2414,2435,2540,
2690,2947,3084,3194` (`JSR FetchFileAAddressSet`); `:1026` (`JMP Anim_WriteItemSprites`);
`:2715` (`JSR ResetRoomTileObjInfo`); `:2792` (`JSR FormatHeartsInTextBuf`); `:2816`/
`:4069` (`JSR FormatDecimalByte`); `:3358` (`JMP Person_Draw`); `:3365`
(`JSR UpdateWorldCurtainEffect_Bank2`); `:3540` (`JSR BeginUpdateMode`); `:3626`/
`:2993` (`Anim_SetSpriteDescriptorAttributes`); `:3015`, `:3633`, `:3644`, `:3814`.

### Finding 5 — The block bank-switches out from under itself — Confirmed, highest severity

`rom_01.s:4170` (`UpdateWorldCurtainEffect`), itself running *inside* the RAM block,
does:

```
4180:    LDA #$05
4181:    JSR SwitchBank_Local5
4183:    JSR SetMMC1Control_Local5
4184:    JSR CopyColumnToTileBuf
```

`SwitchBank_Local5` (`rom_05.s:8400`) changes PBR to bank 5 via the
`rom_inject.s:157` `jml` trampoline and then `RTS`es back into bank 5's `$6C90`
region — which is zero fill. Every instruction after line 4181 executes from
uninitialized memory. This does not depend on who called in; it breaks itself.

Related, lower severity: `rom_01.s:4162` (`JMP SwitchBank_Local2`, a tail call — the
block is being left anyway) and `rom_01.s:4658` (`JSR SwitchBank_Local5` with
`LDA #$01`) happens to switch *to* bank 1, whose in-place assembled block image is
valid, so it survives by luck rather than by design.

### Finding 6 — `CopyCommonCodeToRam` populates a bank nobody executes from — Confirmed design mismatch

`rom_07_fixed.s:1265` and `:1349` do `LDA #$01 / JSR SwitchBank / JSR CopyCommonCodeToRam`.
That call sequence itself is fine (K=1 when it happens, and the routine is at a fixed
address reachable from bank 1). But the copy's *destination* resolves via DBR (bank 0),
while every short `JSR` into the block resolves against PBR/K. **The copy's product is
therefore unreachable by any call site found in the tree.** Nothing ever executes the
bank-0 copy this routine produces.

## Self-modifying-code check (this session's specific ask)

The block does **not** exploit RAM's read/write capability. Checked for:

- Any `STA`/`STZ`/`STX`/`STY`/`STAL`/`INC`/`DEC` targeting a label defined inside the
  block (all 164 non-local labels enumerated and grepped against the whole
  `src/games/zelda/src` tree): the **only** hit is `FileBChecksums`
  (`rom_01.s:2964`), a save-file checksum **data table**, written from `rom_02.s:1760,
  1762, 2577, 2580` — ordinary game-state mutation, not code patching.
- Any `stal :patch+N`-style runtime opcode patching (the idiom used elsewhere in this
  codebase, e.g. `src/rom/rom_inject.s:156-157`) inside the block: none found.
- Any absolute `STA $6Cxx`/`STA $7xxx` writes into the block's address range from
  anywhere in the Zelda source tree: none found.

**Conclusion: the block is pure code+read-only-data once assembled.** It never
modifies its own instructions and the one data table it does mutate
(`FileBChecksums`) is ordinary state, not something that needs to live in RAM for
correctness of the *code*. This means the original NES design's only real reason
for this code to live in mutable WRAM was bank-independence (any PRG bank could
call it without a bank switch) — not because the code needs to be writable.

That opens up options that don't require fixing 331 call sites individually, e.g.
treating the block as ordinary read-only, bank-replicated ROM (identically assembled
into every bank, the same way `rom_07_fixed.s`'s fixed $C000-$FFFF region already is)
and deleting `CopyCommonCodeToRam` and the runtime copy altogether — since nothing
needs it to be RAM. That tradeoff (code size × 7 replicas vs. call-site rewrites) is
a decision for a human, not made here.

## Items checked and found clean

- Intra-`rom_01.s` calls into the block (68 sites): run with K=1, where the block is
  assembled in place, so they are self-consistent. Caveat: they read the *assembled*
  image, not `CopyCommonCodeToRam`'s output (which is now known to be moot per
  Finding 6).
- `rom_00.s`, `rom_03.s`, `rom_06.s`, `Main.s`, `rom_active.s`, `helpers.s`: no
  references to any RAM-block label.
- No bank-forcing thunk exists for this block anywhere. The `SwitchBank_LocalN`
  stubs are not such a mechanism — their purpose is the opposite (to be reachable
  from any K for the purpose of *switching away*), and they are missing from banks
  0/3/4/6.

## Related, already-fixed issue (this session)

`CopyCommonCodeToRam`'s **load** side originally used `LDA ($00),Y` — a `(dp),Y`
read, which resolves through DBR (pinned to bank 0), reading from bank 0's own
(zero-filled) copy of `CommonCodeBlock_Bank1`'s address instead of bank 1's real data.
Fixed in `src/games/zelda/src/rom_01.s:1627-1665` to use a 3-byte indirect-long
pointer (`LDA [$00],Y`) with the bank byte set to `^__BANK_01_CODE_LOAD__` (bank 1).
The store side (`STA ($03),Y`) was left as-is, since per Finding 6 above the
destination's bank-independence was never actually the problem — reachability of
that destination by any caller is.

## Suggested next steps (not applied)

1. Decide the block's canonical home given the self-modification finding above:
   either (a) replicate it as read-only ROM in every bank and delete the RAM-copy
   machinery, or (b) keep a single canonical RAM copy and add per-bank
   `JML`-thunk stubs (the existing `SwitchBank_LocalN` idiom, generalized) so short
   `JSR` keeps working from any bank.
2. `rom_01.s:4180-4184` needs standalone treatment regardless of (1) — a routine
   that switches banks mid-body and returns into the block cannot be fixed by
   changing call sites elsewhere.
3. Verify whether bank 1's in-place assembled image and the bank-0 runtime copy are
   byte-identical before deciding; if option (a) above is chosen, `CopyCommonCodeToRam`
   becomes dead code once removed.

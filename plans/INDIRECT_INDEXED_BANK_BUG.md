# Short Indirect-Indexed `(dp),Y` Bank-Addressing Bug Report

## Summary

This is a static audit of every NES 6502 short indirect-indexed instruction —
`LDA (dp),Y` / `STA (dp),Y` (2-byte dp operand; NOT the 3-byte long-indirect
`[dp],Y` form, which carries an explicit bank byte and is a different, unaffected
addressing mode) — across the 8 reassembled PRG-ROM banks of the Zelda port
(`src/games/zelda/src/rom_00.s` … `rom_07_fixed.s`). This is the same architectural
bug class documented in `BANK_01_CODE.md` (K/PBR-vs-DBR bank mismatch), but at a
different instruction site: `(dp),Y` addressing resolves its effective bank via the
**Data Bank Register (DBR/B)**, not the Program Bank Register (PBR/K).

**Mechanism confirmed:** `romxfer` (`src/rom/rom_exec.s:43-45`) pins DBR to bank 0
(`^ROMBase`) once, immediately before transferring control into NES ROM code, and
DBR is not touched again until a control-transfer boundary. Specifically checked and
ruled out as a mid-execution DBR changer: `yield` (`rom_exec.s:~94`, `phk/plb`) —
this only runs when NES code voluntarily calls the yield entry point, i.e. itself a
control-transfer boundary, not a change occurring *during* ordinary NES code
execution between yields. `resume` and `nmiTask` similarly only set DBR at
transfer boundaries. **So the "DBR pinned to bank 0 for the whole NES-code
lifetime, independent of K" premise holds**, with one exception:
`rom_07_fixed.s`'s `_TableJump` routine (line ~303-311) explicitly does
`phb/phk/plb` around its own `(dp),Y` reads to force DBR=K for that instant, then
restores DBR afterward — a deliberate, correct, local workaround for exactly this
bug class (see Finding rom_07 below). This is the only place in the audited code
where DBR is intentionally forced away from bank 0 during NES-code execution.

**Total sites audited: 179** (137 `LDA`, matching count includes both mnemonics).

| Classification | Count |
|---|---|
| **CONFIRMED bug** (switchable-window target, K provably fixed ≠ 0) | **31** |
| **SUSPECTED bug** (switchable-window target, K not statically pinned down / extra indirection) | **3** |
| RAM-pointer, safe (NES internal RAM or WRAM target, not part of this bug class) | 133 |
| Safe by design (switchable-window target, but K provably 0, or DBR explicitly forced to match K) | 9 |
| Dead code (unreachable, not part of any live path) | 2 |
| Out of scope / already documented elsewhere (`BANK_01_CODE.md`) | 1 |
| **Sum** | **179** |

The single most alarming finding: **`rom_06.s` has 6 confirmed bugs, several of
which are on the level-loading / room-transfer hot path** (`CopyBlock` at line 220,
`LevelInfoUWQ2ReplacementAddrs` at line 279, and the `TransferBufAddrs`-driven
tile-transfer reads at 633/636/672/699). `rom_06.s`'s own header comment
(lines 12-16) shows the developers were *aware* of the low-ROM/PBR translation
problem and added `LDA_LONG_*` stubs to fix ROM **table reads** — but never
extended that fix to the **pointer walks** (`(dp),Y`) that consume the addresses
those tables yield. That gap is the mechanical root cause of most of the confirmed
bugs in this report, not just rom_06.s's.

---

## Findings by file

### rom_00.s — 7 sites, all safe (K matches DBR)

| Line | Instruction | Pointer | Target | K | Classification |
|---|---|---|---|---|---|
| 876, 903, 954, 960, 1014, 1045, 1085 | `LDA (SongScriptPtrLo), Y` | `SongScriptPtrLo/Hi`, set at 849/851 from `SongTable+1,Y`/`+2,Y` | Song header hi-bytes span `$8B-$97` — switchable window | **0** — `DriveAudio` is called from `rom_07_fixed.s:520-522`, immediately preceded by `LDA #$00 / JSR SwitchBank`; no `SwitchBank` call anywhere in rom_00.s afterward | **Safe by design**: DBR=0 (pinned) and K=0 (forced) agree, so the access correctly resolves bank 0's data — which is exactly the intended data. |

### rom_01.s — 6 sites: 3 confirmed, 2 safe, 1 out of scope

| Line | Instruction | Pointer | Target | K | Classification |
|---|---|---|---|---|---|
| 668 | `LDA ($00), Y` | `$00/$01` ← `PersonTextAddrs,Y` (via `LDAL_PersonTextAddrs_Y`) | `PersonText` — after `ds $8000-*` pad (line 77) → switchable window | **1** — reached only via intra-rom_01.s dispatch tables (409/415/1246/1300/1401/1561); never through rom_07_fixed.s | **CONFIRMED bug** |
| 685 | `LDA ($00), Y` | same pointer, unmodified since 658 | same | 1 | **CONFIRMED bug** |
| 1735 | `LDA ($00), Y` | `$00/$01` ← `DemoPatternBlockAddrs,X` (via `LDAL_..._X`) → `DemoSpritePatterns`/`DemoBackgroundPatterns` | `putbin`'d at 1766/1769, before the RAM block (2776) and before the rom_07_fixed put (6723) → switchable window | 1 — reached only via `TransferDemoPatterns` (1712), intra-rom_01.s | **CONFIRMED bug** |
| 4328 | `STA ($00), Y` | `$00/$01` ← `GetRoomFlags` (rom_07_fixed.s:799) ← `LevelInfo_WorldFlagsAddr` ($6BAF, WRAM) → `SaveFileAWorldFlags0/1/2` | WRAM | — | RAM-pointer, safe |
| 4340 | `LDA ($08), Y` | `$08/$09`, same source, 2 lines above | WRAM | — | RAM-pointer, safe |
| 1643 | `STA ($03), Y` | `CopyCommonCodeToRam` destination | WRAM ($6C90 block) | — | **Out of scope** — already analyzed in `BANK_01_CODE.md` Finding 6 / "Related, already-fixed issue"; not re-derived here. |

### rom_02.s — 80 sites: 9 confirmed, 71 safe

K is provably 2 for all of rom_02.s's native code (per `BANK_01_CODE.md` Finding 4).
Targets verified against `ZeldaGS_Symbols.txt`'s NES-address column.

| Lines | Routine / pointer source | Target | Classification |
|---|---|---|---|
| 202 | `TransferPatternBlock_Bank2`, `[$00:01]` = `CommonPatternBlockAddrs` entry → `CommonSpritePatterns`/`CommonBackgroundPatterns`/`CommonMiscPatterns` | after `ds $8000-*` pad → switchable window | **CONFIRMED** |
| 799, 808 | Demo text-line copy, `[$00:01]` ← `DemoLineTextAddrs` → `DemoTextFields` | symbol-verified `00/929E` | **CONFIRMED** |
| 1392 | Demo palette copy, `[$00:01]` = `#<DemoPhase0Subphase1Palettes` | symbol-verified `00/996D` | **CONFIRMED** |
| 3476, 3493 | Thanks textbox, `[$00:01]` = `#<ThanksText` | symbol-verified `00/A95D` | **CONFIRMED** |
| 4022, 4028, 4034 | Credits text copy, `[$00:01]` ← `CreditsTextAddrsLo/Hi` → `CreditsTextLines` | symbol-verified `00/AC60` | **CONFIRMED** |
| 335,357,359,367,416,2456,2463,2474,2485,2487,2489,2491,2507,2514,2525,2536-2539,2697,2951,2964,2965,3198-3210,3211,3213,3215,3227,3228,3237,3238 | `FetchFileAAddressSet` pointer set (`$00/02/04/06/08/0A/0C/0E`) | `$60xx-$65xx` WRAM | RAM-pointer, safe |
| 1773,1784,1787,1790,1813,1821,2593-2628,2644-2676,3089,3095,3097,3102,3128,3129,3198-3210 (dest),3237,3238 | `FetchFileBAddressSet` pointer set (`$C0/C2/C4/C6/C8/CA/CC`) | `$68xx-$6Dxx` WRAM (some numerically inside `BANK_01_CODE.md`'s `$6C90-$7F00` range, but ordinary save-data fields, not the shared code block — out of scope for that bug) | RAM-pointer, safe |
| 1910, 3107, 3108, 3307 | `FetchProfileNameAddress`/`StoreSaveSlotHearts`, `[$0C:0D]` | `Names`=$638, `SaveSlotHearts`=$650, both < $0800 | RAM-pointer, safe |
| 4205 | `[$00:01]` ← `WorldFlagBlockAddrs` | `$067F/$06FF/$077F`, all < $0800 | RAM-pointer, safe |

### rom_03.s — 1 site: 1 confirmed

| Line | Instruction | Pointer | Target | K | Classification |
|---|---|---|---|---|---|
| 225 | `LDA ($00), Y` — "Transfer 1 byte from source pattern block in ROM to PPU" | `$00/$01` ← `LevelPatternBlockSrcAddrs,X`/`BossPatternBlockSrcAddrs,X` (via `LDA_LONG_X`) in `TransferPatternBlock_Bank3` | Pattern block data (`PatternBlockUWBG`/`OWBG`/`OWSP`/`UWSP*`) between `ds $8000-*` (line 34) and `ds $BF50-*` (line 285) → switchable window | **3** — `TransferLevelPatternBlocks` called from `rom_07_fixed.s:1346`, immediately preceded by `LDA #$03 / JSR SwitchBank`; no `SwitchBank` call in rom_03.s afterward | **CONFIRMED bug** |

### rom_04.s — 7 sites, all safe

| Lines | Pointer source | Target | Classification |
|---|---|---|---|
| 3834 | `GetRoomFlags` ← `LevelInfo_WorldFlagsAddr` ($6BAF) | WRAM | RAM-pointer, safe |
| 8705,8707,8709,8746,8748,8750 | `Gleeok_FetchNeckAddrs` ← `GleeokNeckXAddrsLo/Hi`, `YAddrsLo/Hi`, `MiscAddrsLo/Hi` | `$0300-$04FF` | RAM-pointer, safe (NES internal RAM) |

### rom_05.s — 61 sites: 12 confirmed, 3 suspected, 46 safe

K is provably 5 for native rom_05.s code (per `BANK_01_CODE.md` Finding 3).

| Lines | Routine / pointer source | Target | Classification |
|---|---|---|---|
| 1813, 1933 | `AssignObjSpawnPositions`/`PlaceList` ← `ObjListAddrs`/`SpawnPosListAddrsLo/Hi` | $8000-$BFFF | **CONFIRMED** |
| 5396, 5408 | `LayoutUWFloor`, `$02/$03` ← `RoomLayoutsUW` | $8000-$BFFF | **CONFIRMED** |
| 5414, 5433, 5443 | same routine, `$04/$05` via `LDAL_ColumnDirectoryUW_X` ← `ColumnHeapUW0..9` | $8000-$BFFF | **CONFIRMED** |
| 5868, 5880 | `LayoutRoomOW`, `$02/$03` ← `RoomLayoutsOWAddr` → `RoomLayoutsOW` | $8000-$BFFF | **CONFIRMED** |
| 4247, 4986 | `WriteDoorFaceTileHorizontally`, `$02/$03` ← `DoorFaceTilesE/W/S/N` | $8000-$BFFF | **CONFIRMED** |
| 4665 | `FillWalls`, `$00/$01` = `WallTileList` (plain `#<`/`#>`) | $8000-$BFFF | **CONFIRMED** |
| 5887, 5900, 5946 | `LayoutRoomOrCaveOW`, `$04/$05` ← `ColumnDirectoryOW,X`/`ColumnDirectoryOW1,X` — labels actually `ENT`'d in **rom_06.s:503**, loaded via plain absolute addressing (a separate cross-bank addressing anomaly, out of scope here) | Likely switchable window by symmetry with the UW case, but extra indirection not fully pinned down | **SUSPECTED bug** |
| 2126,2141,3583,3585,3616,3618,3632,4077,4079,4102,4154,4163,5244,5246,6142,7786,7875,5908 | `GetRoomFlags`/`LevelInfo_WorldFlagsAddr` | WRAM | RAM-pointer, safe |
| 3519,5488-5521(×7),5556,5732,5786,6034-6077(×7),6165 | `FetchTileMapAddr` ($6530, constant) or `PlayAreaColumnAddrs` (fixed-bank table of WRAM addresses) | WRAM | RAM-pointer, safe |
| 4987 | `PlayAreaDoorFaceAddrsLo/Hi` | WRAM | RAM-pointer, safe |
| 4667, 4668, 4678 | wall-tile write dest | WRAM ($6547/$655A) | RAM-pointer, safe |
| 4721, 4722, 4730, 4736 | WRAM-to-WRAM tile rotate copy | WRAM ($6530→$67EF) | RAM-pointer, safe |
| 7497 | `InitSaveRam` | WRAM ($6530-$7FFF) | RAM-pointer, safe |

### rom_06.s — 7 sites: 6 confirmed, 1 safe

K is provably 6 for native rom_06.s code.

| Line | Instruction | Pointer | Target | Classification |
|---|---|---|---|---|
| 220 | `LDA ($00),Y` (`CopyBlock`) | `$00/01` ← `LevelBlockAddrsQ1/Q2`, `LevelInfoAddrs`, `CommonDataBlockAddr_Bank6` (via `LDAL_*`, read correctly) → `LevelBlockOW`($8400), `LevelBlockUW1Q1`($8700), `LevelInfoOW`($9300), `LevelInfoUW1`($93FC), `CommonDataBlock_Bank6`($9CD8) — all symbol-verified `00/8xxx-00/9xxx` | switchable window | **CONFIRMED bug** |
| 221 | `STA ($02),Y` | dest ← `FetchLevelBlockDestInfo`/`FetchLevelInfoDestInfo`/`FetchDestAddrForCommonDataBlock` → `$687E`/`$6B7E`/`$67F0` | WRAM | RAM-pointer, safe |
| 279 | `LDA ($00),Y` | `LevelInfoUWQ2ReplacementAddrs` → `LevelInfoUWQ2Replacements1` at `00/816F` | switchable window | **CONFIRMED bug** |
| 633, 636, 672, 699 | `LDA ($00),Y` | `TransferBufAddrs` (line 537+), indexed by `TileBufSelector` → mostly `Mode1TileTransferBuf`($A100), `EndingPaletteTransferBuf`($A20A), `LifeOrMoneyCostTextTransferBuf`($A2A6), etc. — switchable window for nearly all selector values; one entry (`DynTileBuf`, $302) is NES RAM | switchable window (selector-dependent) | **CONFIRMED bug** for all non-`DynTileBuf` selector values |

The developers' own header comment (rom_06.s:12-16) acknowledges the low-ROM/PBR
translation problem and fixes it for the table *reads* via `LDA_LONG_*` stubs, but
the resulting pointer is then walked with unfixed short `(dp),Y` — the fix is
half-applied.

### rom_07_fixed.s — 10 sites, all clean (no confirmed/suspected bugs)

`rom_07_fixed.s` is `put` into every bank, so K is generically unresolvable for its
code unless a specific site is provably reached only after an explicit
`SwitchBank` — none of the 10 sites here needed that resolution because all either
target WRAM, are dead code, or explicitly force DBR to match K.

| Line | Instruction | Routine | Finding |
|---|---|---|---|
| 307, 310 | `LDA ($00),Y` | `_TableJump` | **Safe by design** — wrapped in `phb/phk/plb` (303-305) before the reads and `plb` after, forcing DBR=K for the duration. Since rom_07_fixed.s is byte-identical in every bank, the jump-table bytes after each `JSR TableJump` call site live in the caller's own bank, so DBR=K is exactly correct. This is the one place in the audited tree that already implements the correct fix for this bug class. |
| 623, 626 | `LDA ($00),Y` | inside `TableJump` body | **Dead code** — `TableJump`'s first instruction (:615) is an unconditional `jmp _TableJump`; nothing branches/falls into :619-629, so these two instructions are unreachable. |
| 659 | `STA ($00),Y` | `ClearRam0300UpTo` | `$00/$01` set inline from caller A/Y params; both call sites (`rom_05.s:1555-1557`, `:7515-7517`) target `$0000-$07FF` | RAM-pointer, safe |
| 789, 805 | `STA`/`LDA ($00),Y` | `MarkRoomVisited`/`GetRoomFlags` | `$00/$01` ← `LevelInfo_WorldFlagsAddr` ($6BAF, WRAM) → `WorldFlags`($067F) or `SaveFileAWorldFlags0/1/2` | RAM-pointer, safe |
| 1247 | `STA ($00),Y` | `FillTileMap` | Reached via confirmed `LDA #$05/JSR SwitchBank` (1240-1242) before `FetchTileMapAddr`, which hardcodes `$00=$30,$01=$65` → `$6530` | RAM-pointer, safe |
| 2262, 2275 | `LDA ($00),Y` | — | `$00/$01` ← `PlayAreaColumnAddrs` (320-328, fixed-bank table of WRAM addresses `$6530-$67DA`) | RAM-pointer, safe |

---

## Items checked and found clean

- **DBR-pinning mechanism** (`romxfer`, `yield`, `resume`, `nmiTask` in
  `src/rom/rom_exec.s`): confirmed DBR is only ever touched at control-transfer
  boundaries (entry to/exit from NES code, or the voluntary yield call), never
  mid-routine within ordinary NES code execution. This validates the audit's core
  premise that DBR==bank 0 is a constant throughout any single stretch of NES code.
- **`rom_00.s`** (7/7 sites): all `SongScriptPtrLo/Hi` reads land in the switchable
  window, but K is independently forced to 0 right before this code path runs, so
  DBR and K agree — safe by design, not by luck.
- **`rom_04.s`** (7/7 sites): all resolve to NES internal RAM ($0300-$04FF) or WRAM
  — outside this bug class entirely.
- **`rom_07_fixed.s`**: the file already contains one deliberate, correct fix for
  this exact bug class (`_TableJump`'s `phb/phk/plb` wrap) — worth using as the
  template idiom if/when the confirmed bugs elsewhere are fixed.
- Sites touching the `BANK_01_CODE.md` `$6C90-$7F00` common-code-block address
  range were checked and are ordinary WRAM save-data fields (numerically adjacent,
  not the code block itself) — correctly out of scope for *this* report, and not
  re-litigated.
- `rom_01.s:1643` (`CopyCommonCodeToRam` store side) is already fully analyzed in
  `BANK_01_CODE.md` and intentionally not re-derived here.

## Suggested next steps

This static audit is a **triage starting point**, not a final verdict — several
classifications (all 31 "CONFIRMED" sites, and especially the "K provably N"
claims) rest on static call-graph reasoning (a `SwitchBank` call immediately
preceding a call chain, or "this file only ever runs at mapper_bank==N") that
could miss a runtime path not visible from source alone (e.g. a computed/indirect
`JSR`, a re-entrant call, or an interrupt landing mid-sequence). The user intends
to run a **dynamic MAME-based trace** to confirm the actual runtime value of
B (DBR) vs. K at each of these instruction addresses. Recommended focus for that
trace, in priority order:

1. **The 31 CONFIRMED sites** — verify B≠K actually occurs at execution time and
   capture what garbage/bank-0 data gets read or written as a result. Priority
   sub-targets: `rom_06.s:220/279/633/636/672/699` (level-loading / tile-transfer
   hot path — most likely to produce visible corruption) and
   `rom_05.s:5396-5946` (room layout — dungeon/overworld tile compositing, also
   high visibility if wrong).
2. **The 3 SUSPECTED sites** (`rom_05.s:5887/5900/5946`) — first resolve the
   `ColumnDirectoryOW`/`ColumnDirectoryOW1` cross-bank absolute-addressing
   question (why are rom_06.s-`ENT`'d labels read from rom_05.s via plain
   absolute addressing rather than an `LDAL_*` stub — is *that* itself already
   broken, independent of this report's bug class?) before trusting a B/K trace
   at those addresses.
3. Confirm whether the 9 `rom_02.s` and 3 `rom_01.s` confirmed sites are actually
   reached in normal play (they're demo-mode, credits, thanks-text, and
   textbox/pattern-transfer routines — lower play-impact than gameplay-critical
   room loading, but easy to trigger for a quick trace validation pass).
4. Given `rom_07_fixed.s:303-311`'s existing `phb/phk/plb` idiom is proven correct
   and already in the codebase, the most direct fix for confirmed sites (once
   trace-confirmed) is likely the same wrap applied locally around each bugged
   `(dp),Y`, rather than a global DBR policy change — but that's a fix decision
   for after the trace, not something this audit applies.

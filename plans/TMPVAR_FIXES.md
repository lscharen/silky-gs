# DP Scratch (tmp-pool) Aliasing Audit

Findings from a codebase-wide sweep for the "leaf-only tmp variable held live across
a nested call" bug class (the same shape as the `RenderPPUAttr` / `CompileTile`
collision fixed in `src/ppu/ppu_attributes.s` + `src/core/Defs.s` -- see
`RenderAttrDiff`/`RenderAttrCopy`/`RenderMtBase*` there for the precedent this
document's suggested fixes follow).

**Scope:** `src/ppu/`, `src/rom/`, `src/core/`, `src/apu/`, `macros/`. ~95
`tmpN`/`pputmp`/`blttmp`-aliased locals audited across 13 files.

**Result:** 0 confirmed *new* violations. 3 latent hazards (not firing today, but
fragile -- one edit away from reproducing the original bug). 2 `Defs.s` bookkeeping
defects that would mislead the next person trying to allocate a "safe" slot. A
handful of incidental defects noticed while tracing, unrelated to aliasing.

Excluded from this list per direction: `ConvertROMTile2` and the `reverse2`/`reverse4`
helpers it depends on (`src/rom/rom_tiles.s`) -- these, along with the rest of the
`ConvertROM*` family, are being deprecated and removed shortly, so their `tmp1`/`tmp2`
collision with `reverse2`/`reverse4` isn't worth fixing.

---

## Latent hazards (Suspected)

### H2 -- `_SetupStack` declares three locals it never writes, on cells the caller holds live

- Declaration: `src/core/blitter/BlitterLite.s:562-567` -- `:virt_start equ tmp10`,
  `:odd_addr equ tmp12`, `:odd_opcode equ tmp13`.
- Caller's live values: `_BltSetupAlt` (`BlitterLite.s:401`) writes `:virt_start`
  (tmp10) at line 431, `:odd_opcode` (tmp13) at line 534, `:odd_addr` (tmp12) at
  line 548 -- then issues `jsr _Apply` with `_SetupStack` as the callback
  (`BlitterLite.s:553`), and re-reads `:virt_start` at line 555, and hands
  `:odd_addr`/`:odd_opcode` to `_SetupPEAFieldLinesOdd`
  (`BlitterLite.s:774,778`) via a second `_Apply` call at line 558.
- Call chain: `_BltSetupAlt -> _Apply -> _ApplyVertMirroring | _ApplyHorzMirroring
  -> (jsr :patch) -> _SetupStack`. `_Apply`'s iterator can invoke the callback up
  to three times per call (`HorzLite.s:178,303,316`), so the exposure window is a
  loop, not a single call.
- Shared physical addresses: DP 228 (`tmp10`), 232 (`tmp12`), 234 (`tmp13`).
- **Severity: Suspected.** `_SetupStack`'s actual body (`BlitterLite.s:569-606`)
  only touches `tmp9`, `tmp11`, `tmp14` -- the three equates above are dead
  declarations, copy-paste residue, not live writes. Not currently a bug, but a
  landmine: any future edit to `_SetupStack` that actually uses `:virt_start`,
  `:odd_addr`, or `:odd_opcode` "for real" would silently corrupt
  `_BltSetupAlt`'s in-flight state.
- **Suggested fix:** delete lines 563, 565, 566 (`:virt_start`, `:odd_addr`,
  `:odd_opcode`) from `_SetupStack` and add a comment:
  `; NOTE: tmp10/tmp12/tmp13 belong to _BltSetupAlt and are LIVE across this
  callback -- do not claim them here. tmp11 is deliberately shared (running stack
  index).`
  No new DP space needed.

### H3 -- `exposeShadowList` holds `tmp3`/`tmp4`/`tmp5` across two renderer calls

- Declaration: `src/ppu/ppu_shadowlist.s:96-98` -- `:last equ tmp3`,
  `:top equ tmp4`, `:bottom equ tmp5`.
- Live-across sites: `:top`/`:bottom` written at lines 109/117, `jsr
  _BltRangeLite` at line 129, then read again after the call at lines 131/132.
  `:last` written at line 133 and read at line 127 of the *next* loop iteration
  and at line 142, spanning `jsr _PEISlam` (line 134) plus a full iteration.
- Call chain checked: `exposeShadowList -> _BltRangeLite` (`BlitterLite.s:11`,
  uses `tmp0`/`tmp1`/`tmp2` only) `-> jml lite_base_1` (blitter templates --
  grepped `Template*.s`, zero `tmp`/`blttmp`/`pputmp` references);
  `exposeShadowList -> _PEISlam` (`PEISlammer.s:14`, uses `tmp0` only, then
  relocates DP entirely via `tcd`/`pld`).
- **Severity: Suspected (currently safe).** What makes it worth flagging: DP
  246/248 (`tmp3`/`tmp4`) are *also* `walk_top`/`walk_bottom`
  (`src/ppu/ppu.s:146-147`), consumed by `_drawBackground`/`_exposeScreen` in the
  same rendering phase (`ppu_render.s`). Two independent consumers of the same
  two cells, both in the frame-render path -- currently non-overlapping in time,
  but that's an invariant nobody is enforcing.
- **Suggested fix:** free space exists at DP 188-191 (see "Actually-free DP
  space" below). Add to `Defs.s`:
  ```
  ; exposeShadowList (ppu_shadowlist.s) locals -- live across jsr _BltRangeLite
  ; and jsr _PEISlam, and tmp3/tmp4 collide with walk_top/walk_bottom in the
  ; same render phase, so keep them out of the shared pool.
  ExposeLast             equ   188
  ExposeTop              equ   190
  ```
  Leave `:bottom` on `tmp5` -- it's consumed one instruction after its last
  write, before any call, so it's genuinely leaf-safe. This fits the 4 free
  bytes exactly.

### H4 -- `_ApplyVertMirroring` / `_ApplyHorzMirroring` hold `tmp1`/`tmp2` across an indirect dispatch

- Declaration: `src/core/blitter/HorzLite.s:40-41` and `143-144` --
  `:virt_line equ tmp1`, `:lines_left equ tmp2`.
- Live-across sites: `HorzLite.s:77`, then `ldx :lines_left` at 80 and `lda
  :lines_left` at 87; `HorzLite.s:117/120/127`; `HorzLite.s:178`,
  `:303/306/309`, `:316/319`.
- The call is `jsr :patch` (`HorzLite.s:133`, `325`) -- a self-modifying
  dispatch patched from the Y register at entry.
- **Severity: Suspected, but resolved clean.** Every callback ever passed in Y
  was enumerated statically: `_SetupStack` (`BlitterLite.s:500,552`),
  `_SetupPEAFieldLinesEven` (`:505`), `_SetupPEAFieldLinesOdd` (`:557`),
  `_SetupPEAFieldLinesDirty` (`:315,332`), `_RestoreBG0OpcodesCallback`
  (`HorzLite.s:352`). **None of the five touches `tmp1` or `tmp2`** -- the pool
  is partitioned deliberately, and this is documented at `BlitterLite.s:403`
  ("tmp1 and tmp2 are used by the _Apply helper methods").
- **Suggested fix:** no functional change needed. Mirror the `BlitterLite.s:403`
  comment onto the declaration sites (`HorzLite.s:39` and `:142`) so the
  reservation is visible where the locals are declared, not only at one of the
  five call sites that happen to respect it.

---

## `Defs.s` bookkeeping defects

Both of these would actively mislead the next person trying to follow the
`RenderAttrDiff` precedent and pick a "safe" free slot:

1. **`Defs.s:133` -- `"; Free space from 160 to 182"` is stale and wrong.** That
   range is fully allocated: `STATE_REG_R0W0` (160) through `CMPL_BANK` (176),
   then `sprTmp5Hi` (178) and `sprTmp6Lo` (180). Zero bytes actually free.
   Allocating there would silently corrupt the blitter's state-register cache or
   8x16 sprite drawing. Fix the comment (or delete it).
2. **`Defs.s:101-104` -- `unused132`/`unused134` are not unused.** They're
   claimed at `src/ppu/ppu.s:267-268` as `sprAddrMin`/`sprAddrMax` (16-bit each,
   so 132-135 is fully consumed under a different name). Rename them in
   `Defs.s` to `sprAddrMin`/`sprAddrMax` (or at minimum annotate the claim) so
   the `unusedNNN` naming convention stays trustworthy.

**Actually-free DP space**, verified by grep against both the `unusedNNN` symbol
name and the raw numeric offset:

| Range | Size | Status |
|---|---|---|
| 28-29 (`unused28`) | 2 bytes | Free -- symbol referenced only at `Defs.s:52` |
| 59 (`unused59`) | 1 byte | Free -- symbol referenced only at `Defs.s:70`; only useful for an 8-bit flag |
| 188-191 | 4 bytes | Free -- unnamed, between `RenderMtBase` (186) and `blttmp` (192); no raw reference found |

7 bytes total, 6 word-usable. H3 above would consume 4 of them. There isn't room
to lift more than one or two more locals out of the pool this way -- for any
future case, prefer deleting a bogus/dead equate (like H2) or recomputing a
value fresh after the call, over hunting for new DP space.

---

## Dead code note (not a violation, but a risk)

`DrawPPUAttribute` / `_DrawPPUAttribute` (`ppu_attributes.s:21-124`) has no
remaining callers -- the `ATQueuePush` macro referenced in its header comment
no longer exists anywhere in the tree. Its locals are inline `ds 2` reservations
(`ppu_attributes.s:37-42`), not pool-based, so it's correctly not a violation.

Still worth flagging: it's a structural twin of `RenderPPUAttr`, holding
`:attr_diff`/`:attr_copy`/`:mt_base*` across four `jsr SyncPPUMetatile` calls
(lines 79, 91, 105, 121). If anyone "modernizes" it later by converting those
`ds` cells to `equ tmpN` for speed, it reproduces the original bug exactly.
Either delete the dead function, or leave a one-line warning above line 37.

---

## Dynamic dispatch sites checked

- `patch0` (`ppu_attributes.s:251`) and `patch1`-`patch4`
  (`ppu_metatiles.s:183,190,195,202`) -- `jsl` into `CompileTile`-generated code.
  Resolved by construction: the emitter (`CompileTile.s:106-139`) only emits
  `ldy #imm` / `lda [ActivePtr],y` / `sta abs,x` / `stz abs,x` / `rtl`. Only DP
  cell touched is `ActivePtr` (DP 38). No tmp exposure.
- `csd` (`ppu.s:598-602`) -- `jml` into compiled-sprite code. Resolved by
  construction: `CompileSprites.s` emits only `ldy #imm` / `lda abs,x` /
  `and #imm` / `ora [ActivePtr],y` / `sta abs,x`, plus a preamble reading
  `sprTmp1`. Reads DP 62 and DP 38, writes neither. No tmp exposure.
- `jmp (drawProcs,x)` / `jmp (drawProcsClipped,x)` (`ppu.s:637,641,657`) -- all
  16 targets fully enumerated in `ppu_tile_blitters.s`; they use `sprTmp0/1/4`
  and `blttmp` only.
- `jsr (PPU_PALETTE_DISPATCH,x)` (`ppu_regs.s:430`) -- per-game palette handler
  table, called from the PPU register hook in interrupt context on the engine
  DP. Can't be resolved generically (each game defines its own table), but every
  `src/games/*/Main.s` was grepped for `tmp` usage in a handler: the only hits
  are commented-out lines (`smb/Main.s:660,673`; `wumpus/Main.s:43`). No live
  game handler touches the tmp pool today. **Highest-leverage place to add a
  guard comment** -- a violation here would be non-deterministic and could
  corrupt an arbitrary foreground routine, since it runs in interrupt context.

---

## Interrupt-context note

`nmiTask` runs on the engine's own DP (`rom_exec.s:154-155`) -> `NES_ReadInput`,
`NES_TriggerNMI` (NES code runs on `DP_NES`, a separate DP), and the PPU write
hooks in `ppu_regs.s`/`ppu_macros.s`. **No tmp/pputmp/blttmp usage anywhere in
the interrupt path today.** This is load-bearing and worth protecting explicitly:
the blitter re-enables interrupts every 16 lines (`_INT_OFFSET`, `Defs.s:225`),
so any future tmp use inside a PPU register hook would alias whatever foreground
routine happened to be interrupted -- a very hard bug to reproduce. Worth an
explicit comment at `rom_exec.s:146` reserving the tmp pool as foreground-only.

---

## Incidental defects noticed while tracing (not aliasing bugs)

- `src/ppu/ppu_attributes.s:155` -- stray backtick after `inx`. Assembles fine
  (Merlin32 treats it as trailing comment text since `inx` takes no operand),
  but is clearly a typo.
- `src/ppu/ppu_attributes.s:133-157` -- `RefreshPPUTiles` loads `#$ff` into the
  `pputmp` loop counter and does `dec`/`bne`, giving 255 x 4 = 1020 tile draws,
  while the comment at line 156 claims "256 * 4 iterations". The last 4 tiles of
  the page are never refreshed. Called from `scaffold.s:775`.

---

## Cross-module pairs traced and cleared

Recorded so the same ground doesn't need re-covering next audit:

| Live local | Call chain traced | Verdict |
|---|---|---|
| `RenderPPUAttr` `RenderAttrDiff`/`RenderAttrCopy`/`RenderMtBase*` (`ppu_attributes.s:267-272`) | `-> SyncPPUMetatile -> RefreshMetatile -> CheckBgTileDirty -> FastROMTileToLookup / CompileTile` | **Fixed, verified** -- dedicated slots 150/154/158/182/184/186 |
| `DrawPPUTile`'s CHR-RAM block, X preserved via `phx`/`plx` (`ppu_attributes.s:188,231`) | `-> FastROMTileToLookup -> CompileTile` | Clean -- caller state is on the stack, not DP |
| `RefreshPPUTiles` loop counter on `pputmp` (`ppu_attributes.s:134,156`) | `-> DrawPPUTile -> FastROMTileToLookup -> CompileTile -> patch0 jsl` | Clean |
| `drawSprites` `:spriteCount`/`:mul160` = `pputmp+10..15` (`ppu.s:275-276`) | `-> :setupSprite8/16 -> saveTileFromScreen8/16`; `-> :drawSprite8x8 -> CheckSprTileDirty -> FastROMMaskedTileToLookup -> FastROMTileToLookup`; `-> jmp (drawProcs,x)` | Clean, exactly fits the 16-byte `pputmp` block |
| `blttmp` double duty: `CompileTile` staging buffer vs sprite clip buffer (`ppu_tile_blitters.s`) | Temporally disjoint call paths -- neither reachable while the other is live | Clean, but undocumented -- worth a note at `Defs.s:155` |
| `NES_BuildPalette` `:bitmask` = tmp0 (`rom_helpers.s:584`) | `-> assign_color -> NES_ColorToIIgs`; `-> add_to_reverse_map`; `-> find_free_slot`; `-> find_closest_match -> color_dist` | Clean -- callees use registers/stack only |
| `NES_PaletteToIIgs` tmp0/tmp1 across `jsr NES_ColorToIIgs` (`rom_helpers.s:244-250`) | `NES_ColorToIIgs` (`rom_color.s:85`) -- register-only | Clean |
| `rom_config.s` draw tree: `:addr`=tmp15, `:count`/`:highlight`=tmp14, `:value`=tmp13, `:palette`=tmp12, `:next`=tmp11 | `_DrawConfigMenu/_DrawRadio/_DrawTab/_DrawCheckbox/... -> ConfigDrawString / ConfigDrawByte -> _blitTileNoMask`; border draws; `_OffsetToAddr`; `_GetMenuItemIndex` | Clean -- pool partitioned by tmp index; recursion in `_DrawRadio`/`_DrawTab` is a tail call (`jmp _DrawControl`) as required |
| `_RestoreBG0OpcodesAltLite` `:exit_addr`=tmp4 (`HorzLite.s:344`) passed through `_Apply` | `_Apply` uses tmp1/tmp2 only | Clean -- intentional cross-call parameter passing |
| `_InitPPUTileMappingVert/Horz` `:row`/`:col`/`:ppuaddr` = tmp3/4/5 across `jsr :setVerticalMirror` (`ppu_nametable.s:66,161`) | Callee is the intended consumer | Clean (intra-routine) |
| `_drawBackground` / `_exposeScreen` reading `walk_top`/`walk_bottom` (`ppu.s:176-178,190-193`) | Read into X/Y before `jsr _BltRangeLite` / `jsr _PEISlam`; `WALK_BITMAP` never re-reads after the callback | Clean |
| `CoreImpl.s` tmp15 loop counters (`:456/469`, `:562/575`, `:613/634`) | Loop bodies are `PATCH_JMP`/`PATCH_VAL` macros -- no `jsr`/`jsl` | Clean |

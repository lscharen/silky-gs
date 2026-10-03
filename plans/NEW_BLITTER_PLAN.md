# Blitter rework: switch mirroring at runtime without re-patching the PEA field

## Context
Zelda (MMC1) can switch between horizontal and vertical mirroring at runtime. Today `PPUSetMirrorMode` → `_InitHorizontalMirroring`/`_InitVerticalMirroring` (`src/core/CoreImpl.s`) and `_InitLiteBlitterHorz/Vert` (`src/ppu/ppu_init.s`) rewrite control flow in all 240 lines × 2 pages of both blitter banks, and rebuild BTable and Col2CodeOffset. That is too expensive to do on every switch.

The new layout (sketched in `src/core/blitter/NewBlitter.s`) maps the PEA field 1:1 onto the hardware:
- **Even page of row r** = CIRAM page 0, row r.
- **Odd page of row r** = CIRAM page 1, row r.

Mirroring then only decides how execution moves inside a row (stay in the page, or cross to the other page) and which page each row enters. Both are chosen at run time from the **V flag**. The **C flag** selects even or odd alignment, and **Y** supplies the odd right-edge byte. No blitter instruction changes C or V, so P is loaded once per block of lines before jumping into the field.

Scope: prove this on Zelda (which uses the CIRAM-model `ppu_nametable2.s`). Other games must still assemble, but they may render wrongly until they are migrated to `ppu_nametable2.s` in a follow-up.

## Setup (before any code changes)
1. On `dirty-tiles-rework`, commit the current WIP source files (tracked modifications plus the untracked sources the Zelda build needs, e.g. `NewBlitter.s`, `ppu_queues2.s`, `zelda/src/pal_transitions.s`). Exclude `.2mg` images, build outputs, `.env`, `.mcp.json` and `config.kegs`. Show the file list before committing.
2. Create a worktree on a new branch `new-blitter` from that commit (via EnterWorktree). All work happens there.
3. Save this plan as `NEW_BLITTER_PLAN.md` at the worktree root.
4. Implement with every edit manually approved (no auto-accept).

## New per-row code layout (both pages share offsets so one BRA table serves both)

The layout is written out once, with the byte offsets below, as the template body shared by both banks.

**Even page P0 (the only entry page):**
| off | code |
|---|---|
| $00–$10 | interrupt-window prologue (unchanged: restore stack, cli/sei, STATE_REG) |
| $11 | `ldx #screen_right` (operand patched by `_SetupStack`) / `txs` |
| $15 | `bcc $1B` |
| $17 | `lda: P0base,y` (operand is **static**, this row's P0 address) / `pha` |
| $1B | `brl entry` (operand **patched per block**; the target may be in P0 or P1) |
| $1E / $21 | `jmp exit_even` / `jmp exit_odd` |
| $24 | 64 × `pea` |
| $E4 | `bvc P1+$24` (V clear = vertical: cross to the other page) / `jmp P0+$24` (V set = horizontal: loop in this page) / 3 pad bytes |
| $EC | `exit_even`: `dfb $F4,lo,hi` (save slot, runs as a PEA) / `jmp next_row_P0+$11` / 1 pad byte (JML room) |
| $F3 | `exit_odd`: `lda: P0+$EE` (static) / `pha` / `jmp next_row_P0+$11` / 1 pad byte |

**Odd page P1:**
| off | code |
|---|---|
| $00–$1D | unused (available for later use) |
| $1E / $21 | `jmp P0+exit_even` / `jmp P0+exit_odd` |
| $24 | 64 × `pea` |
| $E4 | `bvc *+5` / `jmp P1+$24` (horizontal) / `jmp P0+$24` (vertical) |
| $EC / $F3 | `jmp P0+exit_even` / `jmp P0+exit_odd`. These sit at the same offsets as the P0 exit labels, so BRA displacements are identical in both pages. |

Everything above is **static except**: the `ldx` operand (per row), the `brl` operand (per block), the exit BRA and the save slot (per block, in the exit page), and the exit `jmp` operand on the last rendered row (`_BltRangeLite`).

Chaining between rows is always P0 → next row's P0. The last row of bank 1 does `jml` to the bank 2 `$0004` stub, which sets DBR via `STK_SAVE_BANK`; bank 2's last row does the same to bank 1. The `$000C` "NT2" stub is deleted. The every-16-rows interrupt hooks and the even-render line skips only patch exit `jmp` operands. They go into a **one-time** `_InitLiteBlitter` called from `EngineReset`, replacing the stale `_InitPEAFieldEven` that uses `_EXIT_EVEN`.

## Changes by file

### `src/core/blitter/TemplateLiteBank1.s` / `TemplateLiteBank2.s`
- Rewrite them with the layout above.
- Factor the shared 240-row body into a common `put` file (e.g. `TemplateLiteBody.s`). Each bank file keeps only its ENT/EXT names, the `$0000` `jml blt_return_lite`, the `$0004` bank-entry stub, and the last-row `jml` to the other bank.
- Generate static per-row operands with the existing `]page` LUP variable: the `lda: ]page,y` / `lda: ]page+$EE` operands, the next-row `jmp`, and the `bvc`/`jmp` loop targets.
- Delete `NewBlitter.s` once it has been folded in. Its page-1 pad should be `$1E`, not `$1F`, and its page-1 tail is re-ordered as shown above.

### `src/core/Defs.s`
- Replace the offset constants with the new layout: `_ENTRY_OFFSET=$11`, `_ENTRY_PATCH=$1B`, `_PEA_OFFSET=$24`, `_LOOP_OFFSET=$E4`, `_SAVE_OFFSET`, `_E_EXIT_OFFSET`, `_O_EXIT_OFFSET`, `_O_EXIT_LOAD`, …
- Remove `_O_SAVE_EDGE`, `_E_OUT/_O_OUT/_E_WORD/_O_WORD/_O_LOAD_*`, `_BANK_ENTRY_NT2`, `_EXIT_ODD/_EXIT_EVEN`, and `_LINE_SIZE_H`.
- Add P constants: `BLT_P_BASE = $24` (M=1, X=0, I=1), `BLT_P_ODD = $01` (C), `BLT_P_HORZ = $40` (V).
- Add a DP byte `BltMirrorP` (in `unused28`), set to `$40` for horizontal mirroring and `$00` for vertical. Keep `MaxY` (480 for H, 240 for V) as the virtual-row wrap.

### `src/core/CoreImpl.s`
- `_InitHorizontalMirroring` / `_InitVerticalMirroring` keep only the DP writes: MirrorMaskX/Y, MirrorMaskLong, CIRAMRow/ColMask, MaxX/MaxY, `BltMirrorP`. Every `PATCH_*` loop, the Col2CodeOffset rewrite and the `PATCH_*` macros are deleted.
- Add the one-time `_InitLiteBlitter` (interrupt hooks every 16 rows, plus the even-render skip when `CTRL_EVEN_RENDER` is set). This replaces `_InitRenderMode` / `_InitPEAFieldEven`.

### `src/ppu/ppu_init.s`
- Delete `_InitLiteBlitterHorz` / `_InitLiteBlitterVert`.
- Add a one-time `_InitBTable` (called from `PPUStartUp`) that fills a **240-entry** BTable: `lite_base_{1,2} + (r%120)*$200` and the bank byte. It never changes.
- `PPUSetMirrorMode` just calls the slimmed `_Init*Mirroring`, so a mirroring switch now costs a few DP stores.

### `src/core/CoreData.s` (table shrink)
- `BTableLow/High`: 2×2×240 → 2×240 entries. The P1 address is the P0 address + `$0100`.
- `Col2CodeOffset`: 3×64+2 → 64 entries (`3*(63-c)`). The CIRAM page is added separately (+`$100`).
- `CodeFieldEvenBRA/OddBRA`: reduce to 64 entries indexed by the column within the page. Generate them with a LUP expression instead of hand-written `bra` lines, recomputing displacements for the new 8-byte tail (all within ±127).

### `src/core/blitter/HorzLite.s`
- Replace the `_Apply` dispatcher and `_ApplyVertMirroring` / `_ApplyHorzMirroring` (~250 lines) with **one** loop of about 30 lines:
  - Walk virtual rows `[virt, virt+n)` in 120-row segments, wrapping at `MaxY`.
  - For each segment, call the callback with `A` = virt row mod 240, `X` = count, and DP `BltSegPage` = `$0100` when virt ≥ 240 (only possible in H mode), otherwise `0`.
- `_RestoreBG0OpcodesCallback`: the target becomes `rowbase + BltSegPage + exit_addr`. The source is still the P0 save slot.

### `src/core/blitter/BlitterLite.s`
**`_BltSetup` / `_BltSetupAlt` / `_BltSetupDirty*`**
- Merge the even and odd paths. From byte `b` and word `L = b>>1`, compute:
  - Exit offset `colOff(L&63)+_PEA_OFFSET`, plus `$100` if V mode and `L & $40`.
  - Entry target `colOff((L+63)&63)+_PEA_OFFSET`, with the same page rule applied to `L+63`, turned into the BRL operand.
  - The BRA word from `CodeField{Even,Odd}BRA[L&63]`.
  - `P = BLT_P_BASE | BltMirrorP | (b&1)`.
  - `oddY`: in H mode, `_SAVE_OFFSET+1` (the patched word is both edges). In V mode, the operand-low address of word `L+64` in the *other* page, relative to P0.
- The `_SetupPEAFieldLinesOdd :virt_mirroring` `_O_SAVE_EDGE` copy disappears: Y reads the PEA operand directly.
- Per segment, add `BltSegPage` to the entry BRL operand and to the exit/BRA address in H mode.
- Keep the return value (`exit_addr`) and the calling API unchanged, so the `_BltSetupAlt` / `_RestoreBG0OpcodesAltLite` split-screen code in `smb`/`bf`/`excitebike` `Main.s` still works.
- Record each block in a small `BltBlocks` table: max 4 entries of `{first_line, end_line, P, oddY}`. A setup call with first line 0 resets the table. `_BltSetupDirty` records its block the same way.

**`_BltRangeLite`**
- Row = `(line + StartRow) mod 240`, where DP `StartRow` (in `unused132`) is `StartYMod240 mod 240`, computed in `NES_SetScrollY`. The entry and exit pointers always use P0, so the `MaxY` wrap and the 480-entry BTable indexing go away.
- Walk the blocks that intersect `[X,Y)`; the usual case is one. For each sub-range: patch the exit `jmp` → `$0000` on its last row, then load the block's P and Y and enter:
  ```
  sep #$20 ; ldy oddY ; lda blkP ; pha ; plp ; tsx ; stx STK_SAVE ; lda STATE_REG_BLIT ; stal STATE_REG ; jml entry
  ```
  - This replaces `clv`/`clc`/`sei`. `blkP` already has I=1 and M=1.
  - `lda dp`/`pha`/`plp` takes 10 cycles in 8-bit mode, cheaper than `pei`/`pla`/`plp`.
  - Restore the exit on return, as today.

### `src/ppu/ppu_nametable2.s` (Zelda path)
- `:initCIRAMBank1` uses `BTableLow,y` + `$0100` instead of `BTableLow+{240*2},y`, and the 64-entry `Col2CodeOffset`.
- The CIRAM → PEA mapping is now truly static: it is built once and is independent of mirroring.

### Out of scope (follow-up)
- `ppu_nametable.s` and the other games' Main.s: migrate them to `ppu_nametable2.s` later. For now they must only assemble.

## Verification
1. `npm run build:zelda` assembles cleanly, and `npm run build:all` still assembles.
2. Run Zelda with `npm run debug:zelda` or GSSquared via the gs2-mcp tools:
   - The title screen and overworld use horizontal scrolling (vertical mirroring). Check even and odd X scroll, and a scroll that crosses the page boundary: the left edge and right edge bytes must be correct.
   - Dungeon and overworld vertical transitions use horizontal mirroring. Check a vertical scroll whose 200-row window spans CIRAM page 0 → page 1, so the entry page changes per segment.
   - MMC1 mirroring switches happen at run time. Set a breakpoint on `PPUSetMirrorMode` and confirm it only does DP stores (no loops).
   - Status bar plus playfield split: two blocks with different C/Y.
3. Use `read_mem` on a few rows after a render to confirm that the BRA and save slots are restored and that no stray `$0000` exit remains.
4. Check `_BltRangeLite` over a range that straddles bank 1 → bank 2 and row 239 → 0 (DBR switch via the `$0004` stub).

## Implementation notes (where the code differs from the plan above)
- **Shared row template:** it is a macro file, `src/core/blitter/TemplateLite.Macs.s` (`LITE_P0`, `LITE_P1`, `LITE_ROW`, `PEA64`), loaded with `use` from both bank files. It is not a `put` body. Merlin32 cannot nest `LUP`, so the 64 PEAs are a macro. The last row sets `]page` explicitly, because the LUP variable does not carry past the `--^`.
- **`lite_base_1` / `lite_base_2`:** they now label the P0 **page base** of the first row ($0100), not the entry point. BTable holds page bases; the entry is `+_ENTRY_OFFSET`.
- **Direct page:** `StartRow` = DP 12 (was `unused12/13`). `BltSegPage` = DP 188 (free space). DP 132/134 are already used by `ppu.s` (`sprAddrMin/Max`). `BltMirrorP` = DP 28.
- **Offsets in `Defs.s`:** `_E_EXIT_OFFSET`/`_O_EXIT_OFFSET` are the exit labels ($EC/$F3). The next-line JMPs are `_E_JMP_OFFSET`/`_O_JMP_OFFSET` ($EF/$F7).
- **`_InitRenderMode`:** kept as an alias of `_InitLiteBlitter`, which the games call when toggling even-line mode. It rewrites every exit, so it can be called repeatedly.
- **Per-line alignment (replaces the C flag, odd Y and the block table):** the even/odd choice is patched into each line, as in the old blitter, so one `drawScreen` can draw sections set up with different X scroll (the SMB/Balloon Fight/Excitebike status bars) without the shadow list knowing where the splits are. `$15` holds `BRA $1E` (even, `BLT_ALIGN_EVEN`) or an 8-bit `LDA #imm` no-op (odd, `BLT_ALIGN_ODD`). It is followed by `LDX #edge` / `LDA: P0,X` / `PHA`, where the `LDX` operand is the P0-relative offset of the right-edge byte, patched per line for odd sections only. This shifts the BRL to `$1E` and the PEA run to `$27`. P is just `BLT_P_BASE | BltMirrorP`, since mirroring can't change mid-frame. `_BltSetupCommon` computes the patch values; `_SetupPEAFieldLines` writes the alignment word into every line. The `BltBlocks` table and the C-flag/global-Y approach described above were built first, then removed.
- **Scroll state in PPU register form:** `NES_SetScroll` takes A = nametable select (PPUCTRL bits 1:0), X = scroll_x, Y = scroll_y (both 0–255, high byte zero). `NES_SetScrollX` (X), `NES_SetScrollY` (Y) and `NES_SetScrollNT` (A) each set one piece. The raw values live in DP `ScrollX`/`ScrollY`/`ScrollNT`, a small step toward modelling the PPU v/t registers.
  - `_UpdateScrollStart` derives `StartX` (byte offset of the left edge), `StartY` (virtual line of NES scanline 0) and `StartRow`, and sets the dirty bits. The CIRAM page bit comes from `BltMirrorP` (X bit for vertical mirroring, Y bit for horizontal). scroll_y 240–255 is folded to 224–239 with a subtract.
  - `y_offset` is not part of the scroll state. `_BltSetupCommon`, `_BltRangeLite` and `_RestoreBG0OpcodesAltLite` take playfield lines and add `y_offset` when they turn them into PEA rows.
  - `_Init*Mirroring` calls `_UpdateScrollStart` and sets `DIRTY_BIT_BG0_X`, so a mirroring change forces a full code field setup.
  - Removed: `_GetPPUScrollX/Y`, `MirrorMaskX/Y` and the 1KB `NES2Virtual` table. `StartXMod256`/`StartYMod240` were renamed to `StartX`/`StartY`.
- **Possible later optimization:** for odd lines, patch the alignment word from the PEA field itself (copy opcode + low byte, EOR the PEA opcode into `LDA #imm`, followed by `PHA`). That drops the `LDX`/`LDA abs,X`, saving about 5 cycles per odd line, at about 15 cycles of setup per line.
- **BRA tables:** these are literal `dfb $80,rel` pairs (64 each), generated for the new layout. A column's PEA at page offset ≤ $80 branches back to the top JMPs; beyond that, forward to the bottom exits.
- **Build status:** Zelda assembles and the bank layout was verified in the listing. The other games already failed to assemble at the WIP commit (e.g. `ppu_init.s` calls `_InitCIRAMTileMapping` from `ppu_nametable2.s`), which is out of scope until they are migrated.

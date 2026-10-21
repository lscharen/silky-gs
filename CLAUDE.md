# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Silky-GS** is a hardware abstraction layer (HAL) and runtime that ports NES (Nintendo Entertainment System) games to the Apple IIgs. It intercepts NES PPU/APU writes and translates them to IIgs Super Hi-Res graphics and DOC audio output. All core code is written in 65816 Assembly using the Merlin32 assembler.

## Build & Run Commands

```bash
npm run build:mb        # Mario Bros
npm run build:dk        # Donkey Kong
npm run build:ic        # Ice Climber
npm run build:eb        # Excitebike
npm run build:smb       # Super Mario Bros
npm run build:bf        # Balloon Fight
npm run build:lo        # Lights Out
npm run build:wump      # Wumpus
npm run build:zelda     # Zelda
npm run build:bench     # Engine benchmark (src/games/bench: scrolling SMB scene, no game logic)
npm run build:all       # All games

npm run build-image     # Package built binaries into Target.2mg ProDOS disk image
npm run build:dist      # One 800KB disk per game in emu/ (build-single.bat <game>: app at the root, icon in Icons/)
npm run test            # Build image and launch in GSPort emulator
npm run debug:<game>    # Launch Crossrunner debugger (smb, bf, lo, wump, eb, dk, ic, mb)
```

After assembling, every build compacts the load file with `scripts/omf-compact.js` (runs of zeros become OMF DS records and reserved space; PPURAM and CHRDATA are made whole, bank-aligned segments) and prints the segment sizes. ExpressLoad can't load compacted files, so the link files must not use `XPL`, and segments that need a whole bank get it from `--bank` rather than a trailing `ds`.

Every build also runs `scripts/check-xbank.js` on the engine segments (MAIN, ENGINE): a 16-bit reference to another segment's symbol (`jsr`/`jmp`, a 16-bit operand, or `EXT+const`) fails the build. A few symbols that are meant as 16-bit offsets in a bank the code sets itself are allowed by name in the script. `scripts/code-signature.js save|compare <gameDir> <linkFile> <json>` records every routine's instruction stream (opcodes and lengths) and later reports the routines whose instructions changed; use it to show that moving code between segments left the hot paths alone (baselines go in `build/`, which is not committed).

External tools are configured in `package.json` under `config`: Merlin32 assembler, Cadius disk utility, GSPort emulator, Crossrunner debugger, Cyrene/KegsCyrene. There is no automated test suite — testing is done by running in emulators.

## Architecture

### Execution Model

The runtime sets up a dual-context environment: the IIgs runs as host, with a separate direct page and stack allocated for NES code execution. `NES_StartUp` in `src/rom/scaffold.s` initializes everything and then transfers control to the game loop, which alternates between NES code execution and IIgs rendering. Each game's `Main.s` calls it with X = the memory manager user ID and A = the cartridge's power-on nametable mirroring (`HORIZONTAL_MIRRORING` or `VERTICAL_MIRRORING`); mirroring is switched at runtime for mappers like the MMC1.

**This is not a real-time/cycle-accurate emulator — the IIgs is not fast enough for that.** The NES ROM code runs in real time, driven by an emulated 60Hz interrupt, and its PPU/APU register writes are simply *recorded* (queued) as they happen. Separately, and as fast as it is able, the runtime renders the current recorded state of the NES display to the IIgs hardware. Full renders (e.g. scrolling frames) run at roughly 12-15 frames per second; the dirty (quad grid) renderer, which only redraws what changed, may reach up to 60 frames per second (one render per NES frame) when little changes. The NES logic clock and the IIgs render clock are decoupled; several emulated NES "frames" of ROM execution can elapse between two actual IIgs screen redraws, and a redraw always reflects whatever has been queued up by that point, not a 1:1 snapshot of a single NES frame.

**Debugging implication:** never diagnose a rendering bug as a "timing," "one-frame lag," or "race between frame N and frame N+1" problem — that level of fidelity/granularity doesn't exist in this architecture, so explanations built on it are not physically possible and will be wrong. When something renders incorrectly once and then self-corrects, look for state that failed to get *recorded/propagated at all* (e.g. a write that got deduped/skipped, or a shadow/cache value that never got populated) rather than state that arrived "late." See `src/ppu/ppu_queues.s` for the actual mechanism: NES writes go into a queue, which is periodically frozen and flushed into shadow RAM/the PEA code field whenever the IIgs gets around to rendering — there is no guarantee of alignment with any particular NES-side frame boundary.

### Key Layers

**ROM Interface (`src/rom/`)** — Wraps NES game code for execution on IIgs:
- `scaffold.s` — Main harness: memory init, direct page swapping between IIgs/NES contexts, frame loop
- `rom_config.s` — Per-game constants (tile addresses, mirroring mode, OAM ranges, feature flags)
- `rom_exec.s`, `rom_input.s`, `rom_inject.s`, `rom_helpers.s` — Supporting subsystems

**PPU Simulation (`src/ppu/`)** — Intercepts all NES PPU register writes:
- `ppu.s` — ~2600 lines; converts NES tile data to IIgs format, maintains nametables and OAM, handles mirroring
- `ppu_grid.s`, `ppu_grid_quads.s` — The dirty renderer: a screen-aligned 8x8 grid with quadrant masks that erases from the PEA field and redraws only changed cells; `ppu_grid_marks.s` (generated by `scripts/gen-grid-marks.js`, never edit by hand) has the sprite mark routines (8x8 and 8x16), one per quadrant pattern, and the erase / expose copy routines, one per quadrant mask (erase: one set per code field bank, so both passes run with DBR = $01)

**Rendering Pipeline (`src/core/`)** — The performance-critical path:
- `blitter/BlitterLite.s` — Scanline renderer for full renders
- `blitter/TemplateLiteBank1.s` & `TemplateLiteBank2.s` — Two banks of pre-compiled, self-modifying scanline code
- `blitter/PEISlammer.s` — Emits fast PEI instructions for screen writes
- `tiles/CompileTile.s` — Compiles 8×8 NES background tiles to native 65816 code: tile n (0-511, both pattern tables; NROM games compile all 512 at start-up, CHR-RAM games on demand) goes to the 128-byte slot at n × 128 of the compile bank, the same offset as its tiledata. A compiled tile stores 15 of its 16 words and returns word 0's value in A (worst case 126 bytes); callers use `SET_COMPILED_TILE` / `CALL_COMPILED_TILE` (`ppu/ppu_macros.s`), which point the patched `jsl` at the tile and store word 0
- `sprites/CompileSprites.s` — Compiles sprite tiles in 4 variants (normal, H-flip, V-flip, HV-flip) + mask
- `Data.s` — The engine's indexed tables, page-aligned in one place (put first in the engine segment, at offset `$0000`): every table that is a whole number of pages, then the small lookup tables read with 8-bit index registers. Add any new table read with 8-bit index registers here (an `abs,X` read pays a cycle on a page crossing; with 16-bit index registers it always does)
- `static/TileData.s` — Static bank holding compiled tile data (128 bytes/sprite × up to 256 = 32KB)

**APU (`src/apu/apu.s`)** — Emulates NES audio via IIgs DOC chip; interrupt-driven at 240/120/60 Hz.

**Macros (`macros/`)** — Shared Merlin32 macro libraries: `GTE.Macs.s`, `Mem.Macs`, `Util.Macs`, etc.

### Per-Game Structure (`src/games/<game>/`)

Each port has a consistent structure:
- `Master.s` (or `BF.s`, `SMB.s`, `Wump.s`) — Merlin32 build descriptor (segment list). Every game has two code segments: MAIN (`Main.s`: the entry point, scaffold, scheduler, config screen, APU, I/O, the palette pipeline) and ENGINE (`src/Engine.s`, shared by every game and assembled with `ASM ../../Engine.s`: `core/Data.s` at offset `$0000`, then the `ppu/` files, the blitter, `rom_tiles`/`rom_color`, the tile and sprite compilers). Merlin32 finds a `put` file only relative to the source that puts it, so the build (`assembleGame`) stages the game's `Config.s`, `Hooks.s` and `pal_defs.s` (plus any `engineExtra` files, e.g. the bench's `sprites.s`, as `Extra.s`) into `src/game/` for `src/Engine.s`. `src/game/` is gitignored build scratch: edit the game's own files, never the copies (Merlin32 errors and listings name the copies), and build one game at a time. MAIN reaches the engine only through `jsl` to the long entry points (`ppu/ppu_entry.s`, `RenderLatch`/`RenderDraw` in `ppu/ppu_frame.s`) and long addressing; the imports are listed in `src/ImportEngine.s` / `src/ImportMain.s`, the exports are `label ENT` at the definitions. Always write `label ENT` / `label EXT`, never the operand form (`ENT a,b` is applied even inside a skipped `DO` and silently relinks an `EXT` locally; `check-xbank` rejects it)
- `Config.s` — The engine constants only (no code or macros); put by `Main.s` and (staged) by `src/Engine.s`
- `Hooks.s` — The game definition: every callback macro, the flags that enable them, and their code and data, in a `DO SEG_MAIN` fence (event loop, frame hooks, start-up) and a `DO SEG_ENGINE` fence (code the renderer and PPU write shims call: `SPRITE_PRE_DRAW`, the scroll/ctrl locks, the custom render screen, the palette dispatch). `Main.s` and `src/Engine.s` set `SEG_MAIN`/`SEG_ENGINE` and put it (after the entry code in `Main.s`; staged for `src/Engine.s`). State shared across the fences lives on one side (`label ENT`) and is reached from the other with long addressing (`label EXT`). Merlin32 ignores a `put` inside a put file, so the generated `pal_transitions.s` is put by `Main.s` and `pal_defs.s` by both
- Callbacks: `PRE_EVT_LOOP`, `POST_EVT_LOOP`, `EVT_LOOP_BEGIN`/`END`, `PRE_RENDER`, `POST_RENDER`, `CONFIG_APPLY_HOOK`, `CONFIG_GAME_DEFAULTS` (MAIN), and `SPRITE_PRE_DRAW` before each sprite is drawn (ENGINE) — it can set `sprClipTop` to hide the sprite's top lines, which the sprite renderer clips while drawing; Zelda uses it to emulate the NES 8-sprites-per-line limit at its doors; a game whose callback can set `sprClipTop` must also set `SPRITE_CLIP equ 1`, otherwise the clip tests are not assembled. Every game must define every callback macro; an empty macro means no callback
- `rom.s` — Converted NES PRG-ROM code/data
- `chr.s` — NES CHR-ROM tile graphics
- `PPU.s` — NES PPU/OAM memory allocations
- `pal_*.s` — Palette definitions (older ports; Zelda uses the generated palette pipeline below)
- `Stack.s` — Stack allocation

### Palette Pipeline (Zelda; the model for new ports)

The IIgs shows 16 colors at once (one palette of 16 slots); the NES shows up to 25. Palettes are described as data and compiled into the game by a tool — **don't hand-write palette code or copy the older ports' per-address `$3Fxx` handlers.**

- **Source of truth:** `src/games/zelda/palettes/*.txt` (one file per palette the game shows: `BG0:`–`SP3:`, 4 NES colors each) and `palettes/transitions.txt` (INI-style graph: each `[palette]` lists the palettes that can follow it). A `[fixed BG0 BG1 SP0:1 ...]` section lists the palettes that must keep those background groups, or single cells (`group:index`, e.g. a sprite color), in the same slots (Zelda: the status bar's tiles and sprites, since the status bar is not redrawn while the play area is split off, so a slot change would show it in the wrong colors). Sprite slots are otherwise free to move between palettes.
  - `*$xx` — **reserved**: the game changes this color on the fly (color cycling, Link's tunic/rings, per-room enemy palettes in SP3). It gets an IIgs slot of its own and matches any value during detection.
  - `$xx~$yy` — **approximated**: palette RAM holds `$xx` (used for detection) but it is drawn in `$yy`'s slot; used only when a palette can't fit 16 slots otherwise. It never writes the CLUT.
  - `--` — **unused**: the screen doesn't show this cell and palette RAM holds whatever an earlier palette left there (the ROM uploads only part of the palette, e.g. a title screen). It matches any value during detection, takes no slot and is never loaded.
  - Parser: `scripts/palette-transition.js` (`parsePaletteFile`).
- **Generator:** `scripts/generate-palette-transitions.js` (run by `src/games/zelda/build.js`; skipped when its outputs are newer than the palette files and scripts — expect ~20s when it does run; `--report` prints layouts, slot use and the redraw matrix). It gives every palette **one fixed IIgs slot layout**, chosen jointly so the background groups that keep the same slots across the graph's transitions don't need redrawing. Outputs (never edit by hand):
  - `src/palettes.s` — 8 swizzle tables × 512 bytes per palette (PALDATA segment; 4KB per palette, so at most 16 palettes per bank).
  - `src/pal_transitions.s` — `DetectNESPalette`, `UpdatePalette`, `LoadPaletteColors` and their tables (put into MAIN).
  - `src/pal_defs.s` — the `PAL_*` ids and pinned slots (`PAL_SLOT_*`), constants only (put by `Main.s` and, staged, by `src/Engine.s`).
- **Runtime:** color 0 (`$3F00`/`$3F10`) is always IIgs CLUT slot 0 and is written straight to the hardware (`ppu_3F00`); it is never matched or reloaded, and the other color 0s are ignored. Any other palette RAM write (`Z_PalWrite`, Zelda `Main.s`, NES task) only sets `zPalDirty` — no checks, since palette uploads are 32 writes in a row. At the next render, `ApplyPaletteChange` (`PRE_RENDER`, GS task) runs once if the palette is dirty and the background is on (while it's off, the game is rebuilding the screen and the old colors stay). It calls `DetectNESPalette`, which compares colors 1-3 of each group (24 bytes at most, minus reserved cells), trying the current palette, then its successors in the graph, then all (palettes can share colors — e.g. dungeon 1 and the select screen have identical backgrounds). A new palette goes through `UpdatePalette`: it switches the swizzle tables, loads the CLUT from **live** palette RAM through the palette's cell→slot map (`LoadPaletteColors`), and calls `RefreshPPUAttributes` (`src/ppu/ppu_metatiles.s`) to redraw only the background groups whose slots changed. Otherwise (fades, color cycling, an unknown palette) `LoadPaletteColors` just reloads the current layout. Nothing writes the IIgs CLUT outside the render, so colors change together with the tiles and PPUMASK state they belong to.
- **Adding a palette:** add `<name>.txt`, list it in `transitions.txt`, build. If the generator reports a palette needs more than 16 colors, mark a close color with `~`. Pull exact colors from the ROM's palette transfer records (e.g. Zelda's `LevelInfo` blocks) rather than guessing.

### Key Configuration Constants (in `Config.s` per game)

| Constant | Purpose |
|---|---|
| `ENABLE_DIRTY_RENDERING` | Use the quad grid dirty renderer when the background is still (0 = every frame is a full render) |
| `SPR_PIXEL_SHIFT` | Draw sprites on single pixels (shifted compiled variants, bigger cache slots); 0 = even pixels with the scroll half-pixel correction |
| `NO_VERTICAL_CLIP` | Disable vertical sprite clipping |
| `DIRECT_OAM_READ` | OAM access method |

### Memory Layout

| Region | Purpose |
|---|---|
| `$012000–$019FFF` | Shadow screen (IIgs SHR copy) |
| `$019D00–$019EFF` | SCBs (Scanline Control Bytes) |
| `$019E00–$019FFF` | IIgs palettes |
| `$E12000–$E19FFF` | Actual SHR video memory |
| Compile banks | Dynamically generated tile/sprite code |
| Direct page `$00–$FF` | NES zero page (swapped at context switch) |
| `$0100–$01FF` | NES stack |

### Rendering Techniques

- **Code compilation**: Tiles and sprites are compiled to native 65816 sequences at startup, eliminating per-pixel interpretation overhead.
- **PEI slammer**: Uses the `PEI` instruction (push effective indirect) for fast screen writes.
- **Dirty rendering**: The quad grid renderer redraws only the 8x8 cells (quadrants) where tile or sprite content changed.
- **Self-modifying blitter**: Scanline templates in `TemplateLiteBank1/2.s` are patched at runtime for scroll positions.
- **Dual-bank rendering**: Two blitter banks alternate to allow rendering while the other bank is displayed.

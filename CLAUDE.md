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
npm run build:all       # All games

npm run build-image     # Package built binaries into Target.2mg ProDOS disk image
npm run test            # Build image and launch in GSPort emulator
npm run debug:<game>    # Launch Crossrunner debugger (smb, bf, lo, wump, eb, dk, ic, mb)
```

External tools are configured in `package.json` under `config`: Merlin32 assembler, Cadius disk utility, GSPort emulator, Crossrunner debugger, Cyrene/KegsCyrene. There is no automated test suite — testing is done by running in emulators.

## Architecture

### Execution Model

The runtime sets up a dual-context environment: the IIgs runs as host, with a separate direct page and stack allocated for NES code execution. `NES_StartUp` in `src/rom/scaffold.s` initializes everything and then transfers control to the game loop, which alternates between NES code execution and IIgs rendering. Each game's `Main.s` calls it with X = the memory manager user ID and A = the cartridge's power-on nametable mirroring (`HORIZONTAL_MIRRORING` or `VERTICAL_MIRRORING`); mirroring is switched at runtime for mappers like the MMC1.

**This is not a real-time/cycle-accurate emulator — the IIgs is not fast enough for that.** The NES ROM code runs in real time, driven by an emulated 60Hz interrupt, and its PPU/APU register writes are simply *recorded* (queued) as they happen. Separately, and as fast as it is able, the runtime renders the current recorded state of the NES display to the IIgs hardware — typically at only 12-15 frames per second. The NES logic clock and the IIgs render clock are decoupled; many emulated NES "frames" of ROM execution can elapse between two actual IIgs screen redraws, and a redraw always reflects whatever has been queued up by that point, not a 1:1 snapshot of a single NES frame.

**Debugging implication:** never diagnose a rendering bug as a "timing," "one-frame lag," or "race between frame N and frame N+1" problem — that level of fidelity/granularity doesn't exist in this architecture, so explanations built on it are not physically possible and will be wrong. When something renders incorrectly once and then self-corrects, look for state that failed to get *recorded/propagated at all* (e.g. a write that got deduped/skipped, or a shadow/cache value that never got populated) rather than state that arrived "late." See `src/ppu/ppu_queues.s` for the actual mechanism: NES writes go into a queue, which is periodically frozen and flushed into shadow RAM/the PEA code field whenever the IIgs gets around to rendering — there is no guarantee of alignment with any particular NES-side frame boundary.

### Key Layers

**ROM Interface (`src/rom/`)** — Wraps NES game code for execution on IIgs:
- `scaffold.s` — Main harness: memory init, direct page swapping between IIgs/NES contexts, frame loop
- `rom_config.s` — Per-game constants (tile addresses, mirroring mode, OAM ranges, feature flags)
- `rom_exec.s`, `rom_input.s`, `rom_palette.s`, `rom_inject.s`, `rom_helpers.s` — Supporting subsystems

**PPU Simulation (`src/ppu/`)** — Intercepts all NES PPU register writes:
- `ppu.s` — ~2600 lines; converts NES tile data to IIgs format, maintains nametables and OAM, handles mirroring
- `ppu_dirty.s` — Dirty-state tracking for the optimized rendering path

**Rendering Pipeline (`src/core/`)** — The performance-critical path:
- `blitter/BlitterLite.s` — Scanline renderer; supports full and dirty (changed-only) modes
- `blitter/TemplateLiteBank1.s` & `TemplateLiteBank2.s` — Two banks of pre-compiled, self-modifying scanline code
- `blitter/PEISlammer.s` — Emits fast PEI instructions for screen writes
- `tiles/CompileTile.s` — Compiles 8×8 NES background tiles to native 65816 code at load time
- `sprites/CompileSprites.s` — Compiles sprite tiles in 4 variants (normal, H-flip, V-flip, HV-flip) + mask
- `static/TileData.s` — Static bank holding compiled tile data (128 bytes/sprite × up to 256 = 32KB)

**APU (`src/apu/apu.s`)** — Emulates NES audio via IIgs DOC chip; interrupt-driven at 240/120/60 Hz.

**Macros (`macros/`)** — Shared Merlin32 macro libraries: `GTE.Macs.s`, `Mem.Macs`, `Util.Macs`, etc.

### Per-Game Structure (`src/games/<game>/`)

Each port has a consistent structure:
- `Master.s` — Merlin32 build descriptor (segment list)
- `Main.s` — Game-specific config constants and callback hooks (`PRE_EVT_LOOP`, `POST_EVT_LOOP`, `PRE_RENDER`, `POST_RENDER`, `SCAN_OAM_XTRA_FILTER`)
- `rom.s` — Converted NES PRG-ROM code/data
- `chr.s` — NES CHR-ROM tile graphics
- `PPU.s` — NES PPU/OAM memory allocations
- `pal_*.s` — Palette definitions
- `Stack.s` — Stack allocation

### Key Configuration Constants (in `Main.s` per game)

| Constant | Purpose |
|---|---|
| `PPU_BG_TILE_ADDR` | NES address of background CHR tiles |
| `PPU_SPR_TILE_ADDR` | NES address of sprite CHR tiles |
| `ENABLE_DIRTY_RENDERING` | Enable optimized dirty-scanline rendering |
| `NO_VERTICAL_CLIP` | Disable vertical sprite clipping |
| `DIRECT_OAM_READ` | OAM access method |
| `ROM_DRIVER_MODE` | Reset/restart behavior |

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
- **Dirty rendering**: Only re-renders scanlines where tile or sprite content changed.
- **Self-modifying blitter**: Scanline templates in `TemplateLiteBank1/2.s` are patched at runtime for scroll positions.
- **Dual-bank rendering**: Two blitter banks alternate to allow rendering while the other bank is displayed.

# MAME cycle-count benchmarking

A harness for measuring emulated 65816 execution time of a piece of Silky-GS
code, using MAME's `apple2gs` driver scripted via Lua. Runs headless (no
GS/OS Finder, no game engine boot), boots straight into the target code via
a minimal custom floppy, and reports an exact cycle count.

## Usage

```
node scripts/run-bench.js <bench-dir> [options]
```

Options:

- `--entry-offset <hex>` — byte offset added to the entry segment's address
  for the boot stub's `JSL` target only (segment load addresses and bank
  allocation are unaffected). Needed when the ROM's memory-detection
  routine may have left garbage at the very start of the entry bank —
  e.g. `src/games/smb/Main.s` prefixes its `Entry` label with 2 `NOP`s so
  the JSL can target offset 2. Default `0`.
- `--reserve-bank-01` — also reserve `01/0800` size `$B800` in the boot
  stub. Off by default: that range overlaps `$01/2000-9FFF`, the Super
  Hi-Res shadow screen, which real game code allocates itself via GS/OS.
  Only enable for code that does *not* allocate its own shadow screen.
- `--fast <multiplier>` — MAME `-speed` multiplier (default `4.0`). Since
  the harness only cares about the reported cycle count, not real-time
  playability, running faster than 1x shortens firmware boot/POST
  wall-clock time.

```
node scripts/run-bench.js src/games/bench
node scripts/run-bench.js src/games/smb --entry-offset 2
```

`<bench-dir>` is a directory containing a Merlin32 link file named
`Bench.s` (see `src/games/bench/Bench.s` and `src/games/smb/Bench.s`) with
one or more `TYP BIN` / `DSK <name>` / `ORG $BBOOOO` segment blocks, each
producing a same-named raw binary with no file extension. `Bench.s` is the
**only** source of truth for segment names/addresses — the harness does not
scan symbol files or listings, since a bench directory may also contain
unrelated artifacts from the game's normal (non-bench) build target (e.g.
`src/games/smb/` also has `SuperMarioGS*` files from the full GS/OS build).

The first segment listed is the entry point; it's called via `JSL`, so it
must end in `RTL` — no special exit opcode needed in the game code itself
(see "Boot disk" below for why).

MAME's install path and fixed launch flags come from `package.json`'s
`config.mame` / `config.mameArgs`.

## How it works

### 1. Boot disk (`scripts/make-boot-disk.js`)

Real hardware/firmware boot is used to reach the target code — no debugger
register manipulation for entry. Builds a minimal 143360-byte raw 5.25"
floppy image (`.po`) whose boot sector:

1. Starts with a sector-count byte (`$01`) — required for the apple2gs
   ROM03 firmware to accept the sector as a valid boot block before jumping
   to it (a bare "jump-to-code" sector without this is silently rejected —
   "Check Startup Device").
2. Does `CLC`/`XCE` to enter native mode, `REP #$30` for 16-bit `A`/`X`/`Y`,
   then sets `S`/`D` via `TCS`/`TCD` — all via real 65816 instructions, not
   emulator register pokes (found to conflict with firmware's own
   mode/state assumptions if set before the CPU runs its own reset
   sequence).
3. Stages the `JSL`+`EXIT`/`FAIL` loops (see step 6) as data and copies
   them to `$2000` immediately, before any toolbox call that could fail.
   This has to happen early, and at an address other than `$0800`, because
   `$0800` is also the *application's* direct page (`D` register, set in
   step 2) — once the benchmark code starts running and touches its own
   direct-page variables, it can physically overwrite the boot stub
   sitting at `$0800-$08FF`, corrupting the very loops the harness
   breakpoints on. `$2000` (the ProDOS SYSTEM load address) is unused this
   early.
4. Cold-starts the toolbox and satisfies Apple IIgs Technote #27 (a
   real-hardware requirement, not a MAME quirk): `_TLBootInit` →
   `_TLStartUp` → `_GetNewID` (a temporary bootstrap ID; requires the
   correct `idTag` — top 4 bits = type, `$1` = Application) → `_NewHandle`
   for the fixed memory blocks ProDOS 8/GS/OS would normally have reserved
   (`00/0800` $B800, optionally `01/0800` $B800 behind
   `--reserve-bank-01`, `E0/2000` $4000, `E1/2000` $8000) plus one
   multi-bank allocation covering wherever the benchmark's own segments
   are loaded (see `--banks`, computed by `run-bench.js`) → `_MMStartUp`,
   which pulls the Memory Manager's Master User ID into `A` (real game
   code, via `InitMemory`, expects this on entry — it's what GS/OS
   normally passes to a launched program). All 6+ toolbox calls go through
   one shared subroutine (parameters passed via a block pointed to by `X`)
   to fit in the 256-byte sector, and each checks the carry flag
   (clear=success, set=failure — the standard toolbox convention),
   jumping to the relocated `FAIL` loop on any failure.
5. Zeros `X`/`Y` (leaving `A` = Master User ID) and `JMP`s to `$2000`.
6. At `$2000`: `JSL`s (not `JML`) to the benchmark binary's start address,
   so a plain `RTL` in the benchmark code returns control here; then spins
   forever on a fixed `WDM $01`/`BRA` pair (success) or, from any earlier
   toolbox failure, `WDM $02`/`BRA` (failure) — two distinct, deterministic
   completion signals independent of the benchmark binary's own contents.

The boot sector content is written redundantly into all 16 sector-sized
slots of track 0, since a raw physical boot-sector read isn't guaranteed to
land at file offset 0 (DOS-order vs ProDOS-order sector skew) — writing
every slot sidesteps having to know or guess that mapping.

`make-boot-disk.js` also writes a `<disk>.json` sidecar with the three
addresses the harness needs to breakpoint: `jslAddr`, `exitAddr`, `failAddr`
(all at `$2000`+).

### 2. MAME driver (`scripts/mame_bench.lua`)

Passed via `-autoboot_script`. Reads a JSON segment manifest
(`BENCH_SEGMENTS`, written by `run-bench.js`) and arms three breakpoints,
dispatching on which fires:

- **`jslAddr` hit** → load every segment into memory (via
  `cpu.spaces["program"]:write_u8`), read `totalcycles` as the start count,
  resume.
- **`exitAddr` hit** → read `totalcycles` again, write the delta to the
  result file, exit MAME.
- **`failAddr` hit** → report that a boot-time toolbox call failed (no
  result produced) and exit.

Segments are deliberately **not** preloaded until the `jslAddr` breakpoint
fires (i.e. after the firmware's own POST/RAM-sizing self-test has already
run) — preloading any earlier gets silently clobbered by that self-test.

Breakpoint hits are detected by polling `manager.machine.debugger.consolelog`
(MAME's own debugger log, exposed as an indexable Lua table) for a
`"Stopped at ..."` line, via `emu.register_periodic`. This is the only
reliable signal found for this purpose — see "Debugging notes" below.

### 3. Orchestration (`scripts/run-bench.js`)

Ties it together: parse `Bench.s` for segments → derive the bank span and
check it's contiguous starting at the entry bank → build the boot disk
(`make-boot-disk.js`) → write the segment manifest (`segments.json`) →
launch `mame.exe apple2gs -speed <fast> -debug -debugger none -flop1 <disk>
-autoboot_script mame_bench.lua` with `BENCH_SEGMENTS`/`BENCH_JSL`/
`BENCH_EXIT`/`BENCH_FAIL`/`BENCH_RESULT` env vars → read back
`bench_result.txt`.

## Result format

`bench_result.txt` (also echoed to stdout):

```
cycles=18
```

`cycles` is an exact per-instruction 65816 cycle count (`totalcycles` delta
between the two breakpoints — see below), verified against hand-counted
cycle costs (`JSL`=8, `NOP`=2, `RTL`=6 → 18 for a two-`NOP` benchmark body).

If a boot-time toolbox call fails, no result is produced; check stdout for
the failure message.

## Debugging notes (MAME 0.288 / apple2gs, for future reference)

A number of plausible-looking approaches turned out not to work, or hit
real hardware-accuracy requirements neither obvious nor MAME-specific;
noted here so they aren't rediscovered the hard way.

**MAME/Lua specifics:**

- **`-debug` alone** fully halts the emulation thread on a breakpoint in a
  way invisible to every Lua notifier tried (`add_machine_frame_notifier`,
  `add_machine_pause_notifier`, `emu.register_periodic` + `manager.machine.
  paused`, `manager.machine.debugger.execution_state` — the last of which
  outright **crashed MAME** with a native access violation). **`-debugger
  none`** keeps the emulation thread running instead, and breakpoint hits
  become visible by polling `consolelog` for a `"Stopped at ..."` line.
- Writing `cpu.state["PC"]`/`["PB"]` directly to redirect execution mid-boot
  does not reliably work — `PB` writes don't stick, and even same-bank `PC`
  writes race against continued background execution under `-debugger
  none`. Real instruction execution (a boot sequence ending in `JSL`) is the
  reliable way to redirect the CPU.
- `$00/C600` (the classic slot-6 boot ROM entry point) is genuine read-only
  ROM on ROM03 firmware and cannot be patched via `space:write_u8` or the
  debugger `fill` command.
- ROM03's 5.25" boot routine **validates** the boot sector (checks the
  sector-count byte) before jumping to it, unlike the classic "blind
  jump-to-$0801" Disk II PROM behavior on earlier Apple II ROMs.
- `-flop1`/`-flop2` are the 5.25" drives (extensions `.dsk`/`.do`/`.po`/
  `.woz`/`.nib`) on this driver; `-flop3`/`-flop4` are 3.5" (`.2mg`/`.moof`/
  etc.) and will reject a raw 143K image outright.
- There's no direct Lua API for a true per-CPU cycle counter in this build
  (`cpu.debug.evaluate`, `cpu.debug.symbols`, `cpu.execute`, and
  `cpu.state["totalcycles"]` are all nil/missing). But the debugger
  **console** recognizes `totalcycles` as a valid expression:
  `dbg:command("print totalcycles")` appends its value — in hex, with no
  `0x` prefix — as the next `consolelog` line, parseable with
  `tonumber(line, 16)`. This is exact, not an estimate.
- `space:write_u8` in a byte-by-byte loop measured ~65536 writes/0.09 sec —
  fast enough that even several near-64KB segments load in well under a
  second; no bulk-write API (`space:write_block`) exists in this build, but
  none is needed at this size.

**Real IIgs hardware/toolbox requirements (Technote #27), not MAME quirks:**

- `MMStartUp` fails (Master ID comes back `0`, not a real ID) if called
  from memory that hasn't been allocated through the Memory Manager — true
  for any code that bypasses ProDOS 8/GS/OS's own allocation of the memory
  it occupies, which this harness does by design. Fix: `GetNewID` for a
  temporary ID, `NewHandle` the fixed blocks GS/OS would normally reserve
  plus the benchmark's own code banks, *then* `MMStartUp`.
- `GetNewID` needs a nonzero `idTag` parameter (top 4 bits = type, `$1` =
  Application) — omitting it silently produces a bogus ID that later
  `NewHandle` calls accept but `MMStartUp` rejects.
- `PushLong`'s real convention pushes the **bank-word before the low-word**
  (confirmed by how `PullLong` reconstructs a value: first pull → low
  address, second pull → low+2, and pulls happen in reverse push order).
  Getting this backwards in a hand-rolled parameter block produces
  plausible-looking-but-wrong values that `NewHandle` may partially accept
  yet still misbehave on.
- `NewHandle`'s fixed-location attribute word's bit 4 (`$0010`,
  `attrNoCross`) forbids a block from crossing a bank boundary — fine for
  the single-bank OS-reserved blocks, but must be cleared for a
  multi-bank code-region allocation (error `$0201`, "unable to allocate
  block", otherwise).
- `01/0800` size `$B800` (one of the Technote #27 fixed blocks) overlaps
  `$01/2000-9FFF`, the Super Hi-Res shadow screen. Real game code that
  allocates its own shadow screen via GS/OS will fail to do so if this
  harness's boot stub already claimed that range — hence
  `--reserve-bank-01` defaulting to off.
- The application's direct page (`D` register, `$0800` here) physically
  overlaps whatever the boot stub itself occupies at `$0800-$08FF` — any
  code that uses direct-page addressing for its own variables can silently
  overwrite the boot stub once it starts running. Anything that needs to
  survive past that point (the `JSL`/`EXIT`/`FAIL` loops) must be relocated
  elsewhere first (`$2000` here) — before, not after, entering the
  benchmark code.

# FME-7 register state

`src/rom/rom_fme7.s` provides the banking and mirroring register state for the
Sunsoft FME-7 (NES mapper 69). It is an optional foundation for a port's mapper
adapter. It does not dispatch native game code, resolve memory reads, select or
recompile CHR tiles, or change the PPU's mirroring configuration.

The module was adapted from the register shim developed for Bryan Basil's
Gimmick IIgs port. It contains no cartridge code, graphics, or other game assets.
The register reference is [Sunsoft FME-7 on NESdev](https://www.nesdev.org/wiki/Sunsoft_FME-7).

## Including the module

Put the file once in the game's MAIN segment, alongside the game's adapter code.
For a `Main.s` in `src/games/<game>/`:

```asm
            put   ../../rom/rom_fme7.s
```

Adjust the path for the game's source directory. This file is not in the shared
runtime include list, so existing ports do not assemble it automatically. Do not
replicate it in every PRG segment: the mapper has one shared command latch and
one register set.

All public labels are exported with `label ENT`. Converted ROM segments that
call the entries or read the state must declare the corresponding `label EXT`.
For example:

```asm
FME7_Select EXT
FME7_Write  EXT
FME7_PRG    EXT
```

Use `jsl` for the entry points and long addressing for state in another segment.
The module sets its own data bank internally; the caller's DBR need not match
the module's program bank. It does not use the caller's direct page as scratch.

## Calling convention

All three entry points require native mode with 8-bit A, X, and Y (`M = X = 1`).
They return with `rtl` and preserve A, including its hidden high byte, X, Y, P,
DBR, D, and the caller's stack balance. The caller supplies the NES write value
in A for Select and Write.

| Entry | Operation |
|---|---|
| `FME7_Reset` | Set the fixed `$E000` PRG bank to `A & $3F`; clear the command latch, eight CHR banks, three switchable PRG banks, `$6000` control, and mirroring state. |
| `FME7_Select` | Select command `A & $0F`. |
| `FME7_Write` | Update the selected register using A as described below. Commands `$D`–`$F` have no effect. |

Reset is a deterministic software startup convention, not a claim about the
hardware's unspecified power-on register contents. Call it before entering NES
code. Supply the cartridge's final 8 KiB PRG bank on every reset; it replaces the
previous fixed bank as well as clearing the switchable registers.

For example, a cartridge with 32 PRG banks can initialize the module and select
bank 4 for the `$8000` window as follows:

```asm
            mx    %11
            lda   #31
            jsl   FME7_Reset

            lda   #$09
            jsl   FME7_Select
            lda   #4
            jsl   FME7_Write
```

The `mx` directive describes the assembler's immediate operand widths; the caller
must also have established the required processor mode at runtime.

## Exposed state

Treat the public state labels as read-only inputs to the port's adapter. Update
them through Reset, Select, and Write.

| Label | Size | Meaning |
|---|---|---|
| `FME7_Command` | 1 byte | Current command, `$0`–`$F`. |
| `FME7_CHR` | 8 bytes | Commands `$0`–`$7`: 1 KiB CHR bank numbers for PPU `$0000`, `$0400`, …, `$1C00`. All eight value bits are retained. |
| `FME7_PRG6000` | 1 byte | Command `$8`: six PRG bank bits plus RAM-select and RAM-enable control. All eight value bits are retained. |
| `FME7_PRG` | 4 bytes | Commands `$9`–`$B` select the first three 8 KiB banks at CPU `$8000`, `$A000`, and `$C000`, masked to `$3F`. The fourth byte is the fixed `$E000` bank supplied to Reset; Write never changes it. |
| `FME7_Mirror` | 1 byte | Command `$C`, masked to `$03`: 0 = vertical, 1 = horizontal, 2 = single-screen lower, 3 = single-screen upper. |

For `FME7_PRG6000`, bit 6 clear selects PRG ROM using bits 0–5. With bit 6 set,
bit 7 enables RAM when set and leaves the window disabled when clear. The adapter
must implement those RAM/disabled-window semantics; the module does not read or
write that memory and does not supply an open-bus value.

Register widths describe the mapper, not a particular cartridge's installed
memory. Apply any cartridge-specific address-line masks when consuming a bank
number. In particular, the original Gimmick shim's five-bit PRG and seven-bit CHR
masks are not imposed here.

## Adapter responsibilities

Route CPU **writes** in `$8000`–`$9FFF` to Select and `$A000`–`$BFFF` to Write.
Reads in those ranges still address PRG ROM and require the port's own mapping.
The module takes only a write value; it does not decode the CPU address itself.

Commands `$D`–`$F` are IRQ registers and are ignored by Write. An adapter that
implements them must inspect `FME7_Command` and forward the original NES write
value to its IRQ implementation. Preserve that value while examining the
command latch. Sound writes in `$C000`–`$FFFF` belong to a separate Sunsoft 5B
sound adapter. This module implements neither an IRQ counter nor expansion
audio.

The four PRG windows must be resolved independently. SilkyGS's existing MMC1 and
UxROM shims change a single 16 KiB native program bank; reusing that trampoline
does not implement FME-7's three independently switchable 8 KiB windows. A port
must adapt its code transfers, returns, absolute reads, and indirect reads to its
chosen native layout.

CHR writes only change register state. Selecting the correct tile source and
invalidating any compiled tile or sprite caches remain the adapter's work.

Likewise, all four mirroring selections are recorded, but recording them does
not enable those modes in the renderer. The shared PPU currently supports
horizontal and vertical mirroring. An adapter applying either mode must update
the nametable-write mapping immediately and arrange the renderer's deferred
configuration work, following the existing mapper integration. Single-screen
rendering requires additional PPU support.

These boundaries make this a reusable register module, not a complete mapper 69
port or a cycle-accurate mapper implementation. Native unit tests validate its
register and calling-convention behavior; they do not establish that a full
FME-7 game builds or runs through the shared renderer.

## Tests

`tests/rom/rom_fme7.test.mjs` assembles this file directly with Merlin32 and runs
the entries through the existing `iigs-unit` harness. As with the other native
tests, install `iigs-unit` in the sibling directory expected by `package.json`,
install the npm dependencies, and set `MERLIN32_EXE` and `IIX_EXE` to the Merlin32
and GoldenGate executables. Then run:

```sh
npm test -- tests/rom/rom_fme7.test.mjs
```

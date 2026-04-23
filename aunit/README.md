# AUnit — Assembly Unit Testing for Silky-GS

AUnit is a lightweight unit-testing framework for 65816 assembly code running on the Apple IIgs. Tests are executed under GoldenGate (`iix.exe`) and assertions are made in JavaScript using Vitest. Both **ORCA/M** and **Merlin32** assembly syntax are supported.

## How It Works

**ORCA/M path** (default):
```
Main.s  ──iix assemble──▶  Main.ROOT + Main.A  (OMF object files)
                ──iix link──▶  Main.aunit           (OMF executable)
                ──iix run──▶   out.dat               (AUNT binary packet)
                ──vitest──▶    pass / fail
```

**Merlin32 path** (`assembler: 'merlin32'`):
```
Main.s  ──Merlin32──▶  Main.aunit  (OMF executable, assemble+link in one step)
                ──iix run──▶  out.dat   (AUNT binary packet)
                ──vitest──▶   pass / fail
```

1. The assembly harness calls `AUnit_Init`, exercises the function under test, records results with `AUnit_CaptureRegs` / `AUnit_AppendValue` / `AUnit_AppendMem`, then calls `AUnit_WriteResults` to flush an `out.dat` file via GS/OS.
2. The JS test calls `cpu65816(sharedConfig)` to get a bound `jsl`/`jsr` caller, or `runAssemblyTest(path)` for hand-written harnesses.
3. Vitest assertions check the returned result object.

## Running the Tests

```bash
npm run test:unit        # run once
npm run test:unit:watch  # re-run on file change
```

Tests live in `tests/**/*.test.mjs` and are discovered automatically by Vitest.

---

## The AUNT Data Packet (`out.dat`)

`AUnit_WriteResults` writes a binary packet to `out.dat` in the current GS/OS prefix (the directory containing the executable). The format is:

### File Header (8 bytes)

| Offset | Size | Value | Description |
|--------|------|-------|-------------|
| 0..3   | 4    | `AUNT` | Magic bytes (ASCII) |
| 4      | 1    | `1`   | Format version |
| 5      | 1    | `0`   | Status: `0` = success, non-zero = harness error code |
| 6..7   | 2    | N     | Record count (little-endian 16-bit) |

### Records

Each record immediately follows the header (or the previous record):

```
tag(1)  payloadLen(2-LE16)  payload[payloadLen]
```

Three record types are defined:

#### `R` — Register Snapshot (payload = 16 bytes)

Captures the CPU register state as it existed when the function under test returned. The caller must execute `PHP` *immediately* after the tested function's `RTL`, before any other instruction that could alter registers.

| Field | Size | Description |
|-------|------|-------------|
| A     | 2    | Accumulator |
| X     | 2    | X index |
| Y     | 2    | Y index |
| P     | 2    | Processor status (low byte = real P, high byte = 0) |
| DP    | 2    | Direct page register |
| SP    | 2    | Stack pointer (as it was before the `PHP`) |
| DBR   | 2    | Data bank register (low byte = real DBR, high byte = 0) |
| K     | 2    | Program bank register (low byte = real K, high byte = 0) |

All fields are 16-bit little-endian. The low byte of P, DBR, and K holds the actual 8-bit register value.

#### `M` — Memory Snapshot (payload = 5 + N bytes)

Captures a contiguous range of memory.

| Field  | Size | Description |
|--------|------|-------------|
| bank   | 1    | Source bank byte |
| addrLo | 2    | Source address low word (little-endian) |
| length | 2    | Byte count (little-endian) |
| data   | N    | Raw bytes |

#### `V` — Named 16-bit Value (payload = 1 + nameLen + 2 bytes)

Associates a name string with a 16-bit value for convenient assertion in JS.

| Field   | Size    | Description |
|---------|---------|-------------|
| nameLen | 1       | Length of name string in bytes |
| name    | nameLen | Name bytes (not null-terminated, not length-prefixed) |
| value   | 2       | 16-bit value (little-endian) |

---

## `cpu65816` — Primary API for Generated Tests

`cpu65816` is the recommended entry point for parametric tests. It captures shared configuration once and returns `jsl` and `jsr` caller functions. Each call generates a complete test harness in an OS temp directory, assembles it, runs it, and returns a result object.

```javascript
import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'aunit';

const SRC = join(process.env.SRC_ROOT, 'misc/App.Msg.s');

describe('ByteToString', () => {
  const { jsr } = cpu65816({
    includes:  [SRC],
    assembler: 'merlin32',
  });

  test('converts 0x00 to "00"', async () => {
    const r = await jsr('ByteToString', {
      A: 0,
      Y: 'buf',
      allocMemory: [{ label: 'buf', length: 2 }],
    });
    expect(r.memory.buf.toString()).toBe('00');
  });

  test('converts 0xAB to "AB"', async () => {
    const r = await jsr('ByteToString', {
      A: 0xAB,
      Y: 'buf',
      allocMemory: [{ label: 'buf', length: 2 }],
    });
    expect(r.memory.buf.toString()).toBe('AB');
  });
});
```

### `cpu65816` shared config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `assembler` | string | `'orca'` | `'orca'` or `'merlin32'`. |
| `includes` | string[] | `[]` | Absolute paths to `.s` files containing the function(s) under test. |
| `testDir` | string | `process.cwd()` | Base directory for resolving any relative include paths. Omit when all includes are absolute. |
| `keepArtifacts` | boolean | `false` | Keep the temp directory after the run (logs its path). |
| `trace` | boolean | `false` | Pass `--trace-gsos` to iix. |

### Per-call config (`jsl` / `jsr`)

```javascript
const r = await jsl('MyFunc', {
  // --- register inputs ---
  A:   0x1234,      // 16-bit accumulator
  X:   0xABCD,      // 16-bit X
  Y:   'myBuf',     // string → load address-of-label (ldy #myBuf)
  DP:  0x0200,      // direct page
  SP:  0x01FF,      // stack pointer
  DBR: 0x02,        // data bank register (8-bit)
  P:   0x30,        // processor status (8-bit)

  // --- memory to write before the call ---
  memory: [
    { label: 'NESPalette', data: [0x00, 0x08, 0x88] },
    { label: 'NESPalette', offset: 4, data: Buffer.from([0xFF]) },
  ],

  // --- memory to snapshot after the call ---
  captureMemory: [
    { label: 'NESPalette', length: 8 },           // → raw Buffer
    { label: 'counter',    as: 'word' },           // → number
    { label: 'table',      as: 'byte', count: 4 }, // → number[]
  ],

  // --- allocate labeled storage in the harness (auto-captured) ---
  allocMemory: [
    { label: 'outBuf', length: 16 },   // → raw Buffer (supports .toString())
    { label: 'result', as: 'word' },   // → number
  ],
});
```

**Registers.** Only registers whose value is explicitly provided are initialised; unspecified registers retain whatever state `AUnit_Init` leaves them in. A **string** value is treated as an assembly label — the harness emits `lda #label` (loads the 16-bit address of the label).

**`memory`.** Each entry copies bytes into the named address via MVN before the call. `data` may be a `Buffer`, a `number[]` of byte values, or a value built with the `mem` helper (see below).

**`captureMemory`.** Each entry snapshots a memory region after the call. Provide either `length` (raw `Buffer` returned) or `as` + optional `count` (typed JS number or `number[]` returned). Captured results are in `r.memory` keyed by label.

**`allocMemory`.** Declares a `ds N` label in the generated harness (zeroed storage), which the function under test can write to. Each entry is automatically appended to the capture list, so results appear in `r.memory` keyed by label alongside any `captureMemory` entries. The same `as`/`count` vs `length` rules apply.

### `cpu65816` result object

```javascript
const r = await jsl('MyFunc', { A: 0x10 });

r.A        // number — accumulator after return
r.X        // number — X after return
r.Y        // number — Y after return
r.P        // number — processor status (low byte)
r.DP       // number — direct page register
r.SP       // number — stack pointer
r.DBR      // number — data bank register (low byte)
r.K        // number — program bank register (low byte)

r.memory   // object — { label: value } for captureMemory + allocMemory
           //   value is Buffer when no 'as', number when as+count===1,
           //   number[] when as+count>1

r.values   // object — { name: value } from V records written by the assembly

r.raw      // Buffer — the complete out.dat binary
```

If the harness exits with a non-zero status byte, `jsl`/`jsr` throws an `AssemblyError`. Check `r.ok` is not available on the `cpu65816` result — use the thrown error instead.

---

## `mem` — Typed Memory Fixture Builder

`aunit/mem` provides assembler-directive-style helpers for building `memory` fixtures with correct endianness:

```javascript
import { mem } from 'aunit/mem';

const r = await jsl('MyFunc', {
  memory: [{
    label: 'palette',
    data: Buffer.concat([
      mem.db(0x01),        // 1 byte
      mem.dw(0x0888),      // 16-bit little-endian
      mem.dl(0x7E0000),    // 24-bit little-endian (bank pointer)
      mem.asc('hello'),    // ASCII string
    ]),
  }],
});
```

| Method | Width | Endian | Notes |
|--------|-------|--------|-------|
| `mem.db(v, ...)` | 8-bit | — | One byte per value |
| `mem.dw(v, ...)` | 16-bit | LE | |
| `mem.dl(v, ...)` | 24-bit | LE | 65816 bank pointer format |
| `mem.dd(v, ...)` | 32-bit | LE | |
| `mem.asc(str)` | — | ASCII | No length prefix |
| `mem.asciiz(str)` | — | ASCII | NUL-terminated |

All methods accept a single value, variadic values, or an array, and return a `Buffer`.

---

## `runGeneratedTest` — Lower-level API

`cpu65816` is built on top of `runGeneratedTest`, which you can call directly when you need the raw `result` object (with `result.registers`, `result.memory[]`, etc.) rather than the flattened `cpu65816` shape.

```javascript
import { runGeneratedTest } from 'aunit';

const result = await runGeneratedTest({
  assembler:     'merlin32',
  call:          'MyFunction',
  includes:      ['/absolute/path/to/MyFunction.s'],
  registers:     { A: 0x0016 },
  captureMemory: [{ label: 'output', length: 4 }],
});

expect(result.ok).toBe(true);
expect(result.registers.A).toBe(0x0F00);
expect(result.memory[0].data).toEqual(Buffer.from([...]));
```

### Config reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `assembler` | string | `'orca'` | `'orca'` or `'merlin32'`. |
| `call` | string | required | Assembly label of the function under test. |
| `includes` | string[] | `[]` | Absolute (or `testDir`-relative) paths to source files. |
| `testDir` | string | `process.cwd()` | Base for resolving relative include paths. |
| `callMode` | string | `'jsl'` | `'jsl'` or `'jsr'`. |
| `registers` | object | `{}` | Initial register values — any subset of `{ A, X, Y, DP, SP, DBR, P }`. Unspecified registers are not initialised. String values load the label address. |
| `memory` | object[] | `[]` | Regions to pre-populate before the call. |
| `captureMemory` | object[] | `[]` | Regions to snapshot after the call. Each entry needs `label` + either `length` or `as`/`count`. |
| `allocMemory` | object[] | `[]` | Labels to allocate (`ds N`) in the harness. Auto-appended to captureMemory. |

### `runGeneratedTest` result object

```javascript
result.ok          // boolean — true if status byte is 0
result.status      // number  — raw status byte
result.registers   // object  — { A, X, Y, P, DP, SP, DBR, K }
result.memory      // array   — [{ bank, address, data: Buffer }, ...]
result.values      // object  — { name: value } from V records
result.raw         // Buffer  — complete out.dat binary
```

### How the generated harness works

#### ORCA/M skeleton

```asm
* Auto-generated AUnit harness — do not edit
        org    $020000
Main    start

        clc
        xce                    ; native mode
        rep    #$30            ; 16-bit A and X/Y
        phk
        plb                    ; DBR = program bank ($02)
        jsl    AUnit_Init

* --- register setup ---
        lda    #$0016          ; (only registers with explicit values appear)
        ldy    #myBuf          ; string value → address of label

* --- call ---
        jsl    MyFunction

* --- capture registers ---
        php
        phk
        plb
        rep    #$30
        jsl    AUnit_CaptureRegs

* --- capture memory 0: output (4 bytes) ---
        lda    #output
        ldx    #4
        jsl    AUnit_AppendMem

        jsl    AUnit_WriteResults
        rtl

myBuf   ds     16              ; allocMemory label

        end

        copy   C:/absolute/path/to/MyFunction.s
        copy   C:/absolute/path/to/aunit/lib/aunit.s
        copy   C:/absolute/path/to/aunit/lib/io.s
```

#### Merlin32 skeleton

```asm
* Auto-generated AUnit harness — do not edit
            rel                      ; relocatable OMF segment
            mx    %00                ; 16-bit A and X/Y

Main
            clc
            xce                      ; native mode
            rep   #$30
            phk
            plb                      ; DBR = program bank ($02)
            jsl   AUnit_Init

* --- register setup ---
            lda   #$0016
            ldy   #myBuf

* --- call ---
            jsl   MyFunction

* --- capture registers ---
            php
            phk
            plb
            rep   #$30
            jsl   AUnit_CaptureRegs

* --- capture memory 0: output (4 bytes) ---
            lda   #output
            ldx   #4
            jsl   AUnit_AppendMem

            jsl   AUnit_WriteResults
            rtl

myBuf       ds    16                 ; allocMemory label

            put   ../../path/to/MyFunction.s
            put   ../../path/to/aunit/lib/aunit.merlin.s
            put   ../../path/to/aunit/lib/io.merlin.s
```

`put` paths are forward-slash relative paths from the temp directory. Absolute Windows paths cannot be used because Merlin32 runs under GoldenGate's ProDOS path layer, which treats drive letters as plain directory names. See `docs/adr-003-merlin32-path-handling.md` and `docs/adr-004-include-path-normalization.md` for the full rationale.

#### Common points (both assemblers)

- Only registers that have explicit values in the config are initialised; the rest are untouched.
- `PHP` immediately after `JSL MyFunction` captures P before any other instruction can alter it. `PHK; PLB` restores DBR=$02 without touching P on the stack.
- `allocMemory` labels (`ds N`) are emitted in the data area after `RTL`, inside the segment, so their addresses are visible throughout the harness.
- All artifacts are written to a single OS temp directory (`mkdtemp` prefix `au`) and deleted on completion.

---

## `runAssemblyTest` — Hand-Written Harnesses

For tests that need full control over the assembly harness:

```javascript
import { runAssemblyTest } from 'aunit';
import { join, dirname }   from 'node:path';
import { fileURLToPath }   from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HARNESS   = join(__dirname, 'Main.s');

const result = await runAssemblyTest(HARNESS, { assembler: 'merlin32' });
expect(result.ok).toBe(true);
expect(result.registers.A).toBe(0xABCD);
```

Options: `assembler` (`'orca'` | `'merlin32'`), `keepArtifacts`, `trace`, `outFile`.

The result object has the same shape as `runGeneratedTest` (`result.ok`, `result.registers`, `result.memory[]`, `result.values`, `result.raw`).

---

## Writing an ORCA/M Test Harness

### File Layout

```asm
*--------------------------------------------------------------
* tests/my_subsystem/my_test/Main.s
*--------------------------------------------------------------

        org    $020000          ; GoldenGate loads OMF at bank $02
Main    start

        clc
        xce                    ; switch to 65816 native mode
        rep   #$30             ; 16-bit A and X/Y

        phk
        plb                    ; DBR = program bank ($02)

        jsl   AUnit_Init       ; stamp header, reset write index

* Set up inputs and call the function under test.
        lda   #$1234           ; <-- YOUR inputs
        jsl   MyFunction       ; <-- YOUR function under test

* Capture registers IMMEDIATELY after return.
        php
        rep   #$30
        jsl   AUnit_CaptureRegs   ; appends 'R' record; restores A/X/Y

* Optionally record named values.
        ldx   #ResultName      ; address of name string (in program bank)
        ldy   #ResultNameLen   ; length in bytes
        jsl   AUnit_AppendValue   ; appends 'V' record; A = value to record

* Optionally snapshot a memory range.
*       lda   #MyBuffer        ; low word of source address (program bank)
*       ldx   #BufferSize      ; byte count
*       jsl   AUnit_AppendMem  ; appends 'M' record

        jsl   AUnit_WriteResults  ; write out.dat

        rtl

ResultName    dc    c'myResult'
ResultNameLen equ   *-ResultName

        end

        copy  ../../../../aunit/lib/aunit.s
        copy  ../../../../aunit/lib/io.s
```

### Rules for the ORCA/M Harness

**`PHP` placement.** Capture P immediately after the tested function's `RTL`, with no intervening instructions:

```asm
        jsl   MyFunction   ; function returns here
        php                ; save P — MUST be the very next instruction
        rep   #$30         ; expand to 16-bit before JSL
        jsl   AUnit_CaptureRegs
```

**`AUnit_AppendValue` calling convention** (16-bit mode, DBR = program bank):
- A = the 16-bit value to record
- X = address of name string
- Y = name length in bytes

**`AUnit_AppendMem` calling convention** (16-bit mode, DBR = program bank):
- A = low word of source address (data must be in the program bank, $02)
- X = byte count

**`AUnit_Fail`** — call instead of `AUnit_WriteResults` when the harness detects a setup error. Pass the error code in A (1–255).

---

## Writing a Merlin32 Test Harness

A Merlin32 harness is a **master source file** that uses `put` to include the function under test and the AUnit library. The link file is generated automatically by the runner.

```asm
*--------------------------------------------------------------
* tests/my_subsystem/my_test/Main.s  (Merlin32 master source)
*--------------------------------------------------------------

            rel                      ; relocatable OMF segment
            mx    %00                ; 16-bit A and X/Y

Main
            clc
            xce                      ; 65816 native mode
            rep   #$30

            phk
            plb                      ; DBR = program bank ($02)

            jsl   AUnit_Init

            lda   #$1234             ; <-- YOUR inputs
            jsl   MyFunction         ; <-- YOUR function

            php
            rep   #$30
            jsl   AUnit_CaptureRegs

            jsl   AUnit_WriteResults
            rtl

*--------------------------------------------------------------
* Included files — function under test, then AUnit library.
* Use paths relative to this file's directory.
*--------------------------------------------------------------
            put   ../../../../MyFunction.s
            put   ../../../../aunit/lib/aunit.merlin.s
            put   ../../../../aunit/lib/io.merlin.s
```

Key structural rules:
- `rel` appears once, at the top of the master source file. Do **not** put `rel` in included files.
- Labels do not need `entry` declarations (there is only one segment).
- Use `put` for source includes; use `use` for Merlin32 macro files (`.Macs.s`).

---

## Merlin32 Assembler Notes

### 1. `mvn` encodes correctly — no workaround needed

Merlin32 correctly encodes both bank-byte operands of `MVN`:

```asm
            mvn   $02,$02    ; copies bank $02 → bank $02
```

No `dc h'540202'` escape is needed (that is an ORCA/M-only fix).

### 2. No `start` / `end` / `entry` wrappers

Files included via `put` are raw code with no segment markers. `entry` and `extern` are for multi-segment programs; a single-segment test harness never needs them.

### 3. Bare labels are valid

```asm
MyBranchTarget                 ; valid — no anop needed
              lda   #$00
```

### 4. Data directives differ from ORCA/M

| ORCA/M | Merlin32 | Notes |
|--------|----------|-------|
| `dc h'AABBCC'` | `hex AABBCC` | raw hex bytes |
| `dc i2'$1234'` | `dw $1234` | 16-bit little-endian word |
| `dc i4'label'` | `adrl label` | 4-byte little-endian address |
| `dc c'text'`   | `asc 'text'` | ASCII string, no length prefix |
| `ds N`         | `ds N`       | N bytes of zeroed storage |

### 5. GS/OS inline calls use `dw` + `adrl`

```asm
            jsl   $E100A8          ; GS/OS dispatcher
            dw    $2010            ; function code (2 bytes)
            adrl  myParamBlock     ; parameter block pointer (4 bytes)
```

### 6. ProDOS path constraints (generated harnesses only)

Merlin32 runs under GoldenGate's ProDOS path layer, which does not recognise Windows drive letters as absolute path roots. The runner works around this by using forward-slash relative paths from the temp directory for all `put` directives. Hand-written harnesses are unaffected — write `put` paths relative to the master source file's directory as usual. See `docs/adr-003-merlin32-path-handling.md` for details.

---

## ORCA/M Assembler Gotchas

### 1. Stay in REP #$30 — SEP is not tracked for immediate operands

ORCA does **not** update its mode assumption when it encounters a `SEP` instruction. After `rep #$30`, all immediate operands are assembled as 16-bit regardless of any intervening `sep #$20`. A `sep #$20` followed by `lda #'R'` encodes as `A9 52 00`; at runtime the CPU (in 8-bit mode) executes `lda #$52` and then falls through to the `$00` byte as `BRK`. Crash.

**Rule:** Write all `lda #`, `ldx #`, `ldy #` immediates in 16-bit mode. Load 8-bit values into the low byte of a 16-bit word; use `sep #$20` only when there are no immediate loads in the 8-bit section.

### 2. MVN bank operands always encode as `$00,$00`

ORCA ignores the explicit bank bytes in `mvn src,dst` and emits `54 00 00` regardless.

**Fix:**
```asm
dc    h'540202'    ; mvn $02,$02 — ORCA ignores mvn operands
```

### 3. GoldenGate loads OMF at bank `$02`, not `$03`

Use `phk; plb` (not a hardcoded bank constant) to set DBR at harness startup.

### 4. Full-line comments require `*` in column 1

ORCA/M only allows `;` for end-of-line comments. Use `*` as the first character for standalone comment lines.

### 5. Every labeled line must have an operation

Use `anop` for label-only lines:

```asm
MyLabel   anop
```

To export a label as a linkable entry point:

```asm
MyFunction   entry
             rep   #$30
             rtl
```

### 6. GoldenGate exits with `0xFFFFFFFE` on normal program end

When a program terminates by `RTL`ing into GoldenGate's launcher, iix exits with code `4294967294` (`0xFFFFFFFE`). The runner treats this as a successful run and checks for `out.dat`.

---

## Directory Layout

```
aunit/
  lib/
    aunit.s          ORCA/M: AUnit runtime (Init, CaptureRegs, AppendMem,
                     AppendValue, WriteResults, Fail)
    io.s             ORCA/M: GS/OS loaddata / savedata helpers
    aunit.merlin.s   Merlin32: AUnit runtime (same API, Merlin32 syntax)
    io.merlin.s      Merlin32: GS/OS loaddata / savedata helpers
  docs/
    adr-001-cpu65816-builder-pattern.md
    adr-002-mem-typed-buffer-builder.md
    adr-003-merlin32-path-handling.md
    adr-004-include-path-normalization.md
  runner.mjs         Node.js: assemble → run → parse out.dat
                     Exports: runAssemblyTest, runGeneratedTest, cpu65816
  parser.mjs         Parse AUNT binary packet into JS result object
  mem.mjs            Typed memory fixture builder (db, dw, dl, dd, asc, asciiz)
  shr2png.mjs        Convert 32 KB SHR screen dump to PNG (optional helper)
  vitest.config.mjs  Vitest configuration (sequential forks, 60 s timeout)

tests/
  misc/
    App.Msg.test.mjs  cpu65816 parametric test (Merlin32, allocMemory)
```

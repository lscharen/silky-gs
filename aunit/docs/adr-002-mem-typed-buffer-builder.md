# ADR-002: `mem` Typed Buffer Builder for Memory Fixtures

**Date:** 2026-04-22  
**Status:** Accepted

## Context

The `memory` and `captureMemory` config fields accepted by `runGeneratedTest` and `cpu65816` use raw `Buffer` / `number[]` for write fixtures and a bare integer `length` for capture specs:

```js
memory: [{ label: 'palette', data: [0x00, 0x08, 0x88, 0x00] }]
captureMemory: [{ label: 'output', length: 8 }]
```

This representation has three ambiguities that become painful when testing assembly code:

1. **Width.** `[0, 256]` — is this two bytes, one word, or something else?
2. **Endianness.** Multi-byte values must be manually byte-swapped to little-endian before putting them in the array.
3. **Capture symmetry.** A `length` of 8 says nothing about how to interpret the bytes read back. The caller must manually slice and decode the raw `Buffer` from `result.memory[i].data`.

65816 assembly programmers already have a vocabulary for this: the assembler pseudo-opcodes `DB`, `DW`, `DL`, `DD`, `ASC`, `ASCIIZ`. Using those names keeps the mental model consistent between test code and the assembly under test.

## Decision

### Write side — `mem` builder (`aunit/mem.mjs`)

A small module that mirrors the standard 65816 assembler data-definition directives. All methods return a plain `Buffer` and accept a single value, variadic values, or an array:

| Method | Directive | Width | Endian |
|---|---|---|---|
| `mem.db(v, ...)` | `DB` | 8-bit | — |
| `mem.dw(v, ...)` | `DW` | 16-bit | LE |
| `mem.dl(v, ...)` | `DL` | 24-bit | LE |
| `mem.dd(v, ...)` | `DD` | 32-bit | LE |
| `mem.asc(str)` | `ASC` | — | ASCII |
| `mem.asciiz(str)` | `ASCIIZ` | — | ASCII + NUL |

`dl` (24-bit) is deliberately included as a first-class citizen — it directly maps to the 65816 bank:address pointer format that appears constantly in IIgs code.

Because all methods return `Buffer`, complex structures compose naturally:

```js
data: Buffer.concat([
  mem.db(0x01),        // type tag
  mem.db(4),           // length
  mem.dl(0x7E0000),    // 24-bit pointer
])
```

### Capture side — `as` + `count` in `captureMemory`

`cpu65816` `captureMemory` entries now accept `as` and `count` in place of `length`:

```js
captureMemory: [
  { label: 'palette',   as: 'word', count: 4 },  // reads 8 bytes
  { label: 'flag_byte', as: 'byte'            },  // reads 1 byte
]
```

`cpu65816` derives `length = sizeof(as) × (count ?? 1)` before passing the entry to `runGeneratedTest`, which is unchanged. After the run, captured bytes are decoded back into typed JS numbers and returned in `r.memory` keyed by label:

```js
expect(r.memory.palette).toEqual([0x0100, 0x0200, 0x0300, 0x0400]);
expect(r.memory.flag_byte).toBe(1);
```

- `count === 1` (or absent) → single `number`
- `count > 1` → `number[]`
- No `as` → raw `Buffer` (backwards-compatible with entries that already specify `length`)

Supported type names accept both assembler-directive and descriptive forms:

| `as` value | Bytes | Read as |
|---|---|---|
| `'byte'`, `'db'` | 1 | `uint8` |
| `'word'`, `'words'`, `'dw'` | 2 | `uint16LE` |
| `'long'`, `'longs'`, `'dl'` | 3 | `uint24LE` |
| `'dd'` | 4 | `uint32LE` |

### Scope boundary

`mem` and the `as`/`count` decoding live entirely in JS. The generated assembly harness and the `runGeneratedTest` core are unmodified — `captureMemory` normalization happens in `cpu65816._call` before the call, and decoding happens after.

## Consequences

**Good:**
- Width and endianness are explicit and self-documenting at the call site.
- Write and capture sides are symmetric: `mem.dw(...)` to write, `as: 'word'` to read back.
- `dl` directly expresses 65816 bank pointers without manual bit manipulation.
- `runGeneratedTest` is unaffected; the new capability is additive.

**Trade-offs:**
- `r.memory` in `cpu65816` is now an object keyed by label rather than the raw `result.memory` array from the parser. Tests that previously accessed `result.memory[i].data` directly must use `r.raw` or `runGeneratedTest` instead.
- Signed integers are not supported — all values are treated as unsigned. Assembly tests that need to assert on negative return values should check the raw bits (e.g., `r.A & 0x8000`) rather than relying on JS signed arithmetic.

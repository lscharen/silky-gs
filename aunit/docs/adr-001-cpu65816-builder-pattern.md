# ADR-001: cpu65816 Builder Pattern for Generated Tests

**Date:** 2026-04-22  
**Status:** Accepted

## Context

The original `runGeneratedTest` API requires callers to repeat shared configuration — `testDir`, `includes`, and `assembler` — on every invocation. A typical test file testing multiple inputs against the same function looks like this:

```js
const r = await runGeneratedTest({
  testDir:  __dirname,
  call:     'SwizzleColor',
  includes: [SWIZZLE_SRC],
  registers: { A: nes },
});
expect(r.ok).toBe(true);
expect(r.registers.A).toBe(expected);
```

Three problems with this pattern at scale:

1. **Repetition.** `testDir` and `includes` are identical for every call in a describe block. Adding a new include file means editing every test.
2. **Verbose result access.** Registers live under `result.registers.A` rather than `result.A`, adding noise to assertions.
3. **Manual ok-checking.** `result.ok` is a flag the caller must explicitly assert. A harness crash produces a misleading test failure rather than a thrown error pointing at the real problem.
4. **No calling-convention signal.** `runGeneratedTest` always emits a `jsl` instruction. There is no way to test a function that returns via `rts` without writing a hand-rolled harness.

## Decision

Add a `cpu65816(sharedConfig)` factory function to `runner.mjs` that captures shared config once and returns two bound caller functions:

```js
const { jsl, jsr } = cpu65816({
  includes: [SWIZZLE_SRC],
  testDir:  __dirname,
  assembler: 'orca',       // optional, default 'orca'
});

const r = await jsl('SwizzleColor', { A: 0x0016 });
expect(r.A).toBe(0x0F00);
```

**`jsl(label, callConfig)`** — generates a harness that calls `label` via `jsl` (function returns via `rtl`).  
**`jsr(label, callConfig)`** — generates a harness that calls `label` via `jsr` (function returns via `rts`).

The per-call `callConfig` accepts:

| Field | Default | Purpose |
|---|---|---|
| `A`, `X`, `Y` | `0` | Initial register values |
| `memory` | `[]` | Memory regions to pre-populate |
| `captureMemory` | `[]` | Memory regions to snapshot after the call |
| `keepArtifacts` | `false` | Retain temp dir for debugging |
| `trace` | `false` | Pass `--trace-gsos` to iix |

The return value spreads `registers` to the top level and omits the `ok` field:

```js
{ A, X, Y, P, DP, SP, DBR, K, memory, values, raw }
```

If the harness fails (`status !== 0`), `jsl`/`jsr` throw `AssemblyError` rather than returning `ok: false`. This causes the Vitest test to fail with a meaningful error immediately, rather than requiring an explicit `expect(r.ok).toBe(true)` guard.

### Implementation

`callMode` ('jsl' | 'jsr') is threaded through `runGeneratedTest` into both `_runGeneratedOrca` and `_runGeneratedMerlin32`, replacing the previously hard-coded `jsl` instruction in the generated harness. `cpu65816` is a thin wrapper around `runGeneratedTest` and adds no new assembly generation logic.

## Consequences

**Good:**
- Shared config is declared once per describe block, not per test.
- Register assertions read naturally: `r.A`, `r.P`, not `r.registers.A`.
- Harness failures throw immediately and fail the test at the point of the `await`, not silently.
- `jsr` makes it possible to test near-call (`rts`) functions without hand-writing a harness.
- `runGeneratedTest` is unchanged; both APIs coexist.

**Trade-offs:**
- `cpu65816` always throws on harness failure. A test that deliberately expects a non-zero status must still use `runGeneratedTest` directly.
- The flat return value does not include `ok` or `status` on success (they are always `true`/`0`). Access via `result.raw` if the raw packet bytes are needed for header assertions.

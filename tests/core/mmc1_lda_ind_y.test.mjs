/**
 * tests/core/mmc1_lda_ind_y.test.mjs
 *
 * Unit tests for the MMC1_LDA_IND_Y macro in src/rom/rom_inject.s.
 *
 * This macro is the bank-safe replacement for a plain `LDA (dp),Y` used
 * throughout the zelda port's converted NES bank-switched code (see
 * `LDA_00_Y MMC1_LDA_IND_Y $00` instantiations in rom_01/02/03/05/06.s).
 * DBR is pinned to a fixed bank for the whole NES-code lifetime, but K
 * (the program bank register) varies per rom_0N.s bank, so a plain
 * `(dp),Y` silently reads garbage from the wrong physical bank whenever
 * the pointer targets the switchable ROM window ($8000-$BFFF). The macro
 * inspects the high byte of the pointer at runtime and picks one of four
 * strategies:
 *
 *   $00-$01 (zero page / NES stack page): treat [ptr]+Y as a direct-page
 *     offset and read via `LDA $00,X` -- always bank 0, DP-relative.
 *   $02-$1F, $60-$7F (below I/O space, WRAM): read via plain `LDA (dp),Y`
 *     -- whatever DBR currently is, is assumed correct as-is.
 *   $20-$5F (PPU/APU I/O + expansion space): don't actually read memory;
 *     return the pointer's own high byte (floating-bus-style read).
 *   $80-$BF (switchable PRG ROM window): force DBR = K (PHB/PHK/PLB)
 *     before the indirect read, then restore DBR -- this is the actual
 *     bank-safety fix.
 *   $C0-$FF (fixed PRG ROM bank, always mapped): plain `(dp),Y` is
 *     correct as-is, same as the low/WRAM case.
 *
 * Each routing test places a distinct sentinel byte at the *correct*
 * source bank and, where the routing choice matters (DBR vs K), a
 * different decoy byte at the bank the macro must NOT read from -- so a
 * regression that reads the wrong bank fails the assertion rather than
 * merely reading "a" plausible-looking byte.
 *
 * All memory setup is done with `stal` (absolute-long store) in an
 * `.inline()` step rather than iigs-unit's `memory:` config, because that
 * config only supports writing to labels assembled into the harness's own
 * bank ($02) -- there is no way to address an arbitrary bank (e.g. the
 * "wrong" bank $05 used below) through it. `stal` encodes the full 24-bit
 * address directly, independent of the ambient DBR/PBR, so it can place
 * bytes in any bank regardless of where the harness itself is assembled.
 *
 * Also covers two bugs fixed in this macro (see
 * project_indirect_bank_bug_fixes memory, Follow-up 5):
 *   - the internal CMP-based dispatch chain must not clobber the
 *     caller's carry flag (a plain `LDA (dp),Y` never touches C).
 *   - the zero-page/stack path's internal 16-bit LDA must not leak the
 *     neighboring byte into the accumulator's hidden high byte when
 *     dropping back to 8-bit mode.
 *
 * Calling convention exercised here:
 *   Direct page $00/$01 (with DP=0x800, i.e. physical bank 0 $0800/$0801)
 *   holds the 16-bit pointer. Y is the index. The routine is called via
 *   JSR (it ends in RTS) in 8-bit A/X/Y mode (mx=3), matching every real
 *   call site in the zelda port.
 *
 * rom_inject.s cannot be `include`d wholesale here: it declares ~30 other
 * labels `EXT` (PPU/APU register shims, MMC1 bank-switch state) that this
 * macro never touches, but Merlin32's EXT/ENT linkage requires those to be
 * resolved from a genuinely separate segment -- a same-segment stub label
 * with the same name (the `mocks`/stub approach used elsewhere in this
 * test suite) does not satisfy it, and this harness only ever assembles
 * two segments (the code under test, and the fixed AUnit library). Rather
 * than duplicate the macro body into this file (which would silently stop
 * testing the real implementation the moment rom_inject.s changes), the
 * macro's source text is sliced out of the real file at test-run time and
 * fed to the harness as `inline` source -- self-contained, EXT-free, and
 * always in sync with whatever the macro currently says.
 *
 * The extracted text is immediately preceded by an explicit `mx %11`
 * directive before its `TestLoad` instantiation. This is required, not
 * cosmetic: iigs-unit's generated sequence harness `put`s inline source at
 * the *bottom* of the file (after the RTL and register-capture code), so
 * by the time Merlin32 assembles the macro's body, the mx state in effect
 * is whatever the *textually preceding* code left it in (16-bit, from the
 * register-capture block's `mx %00`) -- not the 8-bit mode the `jsr
 * TestLoad` actually runs in at runtime. Merlin32's `mx` directive is
 * purely lexical/file-order; it does not simulate control flow. Without
 * this directive, immediate operands inside the macro (e.g. `cmp #$02`)
 * silently assemble one byte too wide, shifting every following opcode by
 * a byte and corrupting the branch instructions after it -- confirmed via
 * `iix --trace-cpu`, which showed the assembled `bcc zpage` opcode
 * replaced by a stray `$00` (BRK) at runtime.
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { readFileSync }           from 'node:fs';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT   = process.env.SRC_ROOT;
const ROM_INJECT = join(SRC_ROOT, 'rom/rom_inject.s');

// Slice the macro definition -- and only the macro definition -- out of
// the real rom_inject.s source. The body itself makes no external calls
// and references no EXT'd data label, so this snippet assembles standalone.
function extractMacro(sourcePath, macroName) {
  const source = readFileSync(sourcePath, 'utf8');
  // Note: rom_inject.s has no trailing newline after the final macro's
  // closing "<<<" (it's the last line in the file), so the terminator
  // must not require one.
  const re = new RegExp(`^${macroName}\\s+mac[\\s\\S]*?\\r?\\n\\s*<<<`, 'm');
  const match = source.match(re);
  if (!match) {
    throw new Error(
      `Could not find macro '${macroName}' in ${sourcePath} -- has it been ` +
      `renamed, moved, or restructured? Update the extraction regex in ` +
      `tests/core/mmc1_lda_ind_y.test.mjs to match.`
    );
  }
  return match[0];
}

const MACRO_SRC = extractMacro(ROM_INJECT, 'MMC1_LDA_IND_Y');

// Instantiate the macro under test with pointer $00, matching the
// convention used at every real call site in the zelda port (e.g.
// rom_02.s: LDA_00_Y MMC1_LDA_IND_Y $00). The `mx %11` is required --
// see the file header comment above.
const TEST_SRC = `
${MACRO_SRC}
          mx    %11
TestLoad  MMC1_LDA_IND_Y $00
`;

// Set the direct page a stack to different locations than emulation mode
const default_regs = { DP: 0x800, SP: 0x9FF };

const { sequence } = cpu65816({
  assembler: 'merlin32',
  inline: [TEST_SRC],
});

const Bank00 = 0x00; // NES zero page / stack page -- always physical bank 0, regardless of DBR.
const PBR    = 0x02; // GoldenGate always loads the OMF harness at bank $02.
const DBR    = 0x05; // The caller's Data Bank Register for these tests -- deliberately
                      // different from PBR, so a DBR/K mixup in the macro reads a decoy
                      // byte and fails loudly instead of accidentally reading the right one.

// Builds an .inline() snippet that pokes each {addr, value} pair via
// `stal` (absolute-long store), so the bytes land at the exact 24-bit
// address regardless of the ambient DBR/PBR. Leaves A in 8-bit mode.
function poke(...entries) {
  const hex2 = (n) => `$${(n & 0xFF).toString(16).padStart(2, '0').toUpperCase()}`;
  const hex6 = (n) => `$${(n >>> 0).toString(16).padStart(6, '0').toUpperCase()}`;
  const lines = [];
  for (const { addr, value } of entries) {
    lines.push(`            lda   #${hex2(value)}`, `            stal  ${hex6(addr)}`);
  }
  return lines.join('\n');
}

const addr24 = (bank, a16) => ((bank & 0xFF) << 16) | (a16 & 0xFFFF);

// Direct page $00/$01 holds the 16-bit pointer, dereferenced via
// DP-relative addressing (`LDA ]1+1` / `LDA (]1),Y` / `LDA $00,X`), so its
// physical location tracks default_regs.DP, not a fixed bank-0 address.
// Every test below pokes it the same way: pointer low byte at
// DP+$00, high byte at DP+$01.

describe('MMC1_LDA_IND_Y — bank routing by pointer high byte', () => {
  test('$00xx (zero page): reads bank 0 at DP + ptr + Y, ignoring DBR', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x50 }, // pointer low byte -> ptr=$0050
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x00 }, // pointer high byte
        { addr: addr24(Bank00, default_regs.DP + 0x55), value: 0xAB }, // expected: bank0[DP + $0050 + $05]
        { addr: addr24(DBR, default_regs.DP + 0x55), value: 0x99 }, // decoy: would be read if DBR were used instead
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0xAB);
  });

  test('$01xx (NES stack page): also routed to the zero-page handler', async () => {
    // Regression coverage for Bug 3 (Follow-up 5): a $01xx pointer used
    // to fall through to the plain (dp),Y branch instead of the
    // zero-page handler.
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x50 }, // pointer low byte -> ptr=$0150
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x01 }, // pointer high byte
        { addr: addr24(Bank00, default_regs.DP + 0x155), value: 0xCD }, // expected: bank0[DP + $0150 + $05]
        { addr: addr24(DBR, default_regs.DP + 0x155), value: 0x99 }, // decoy: would be read if DBR were used instead
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0xCD);
  });

  test('$02xx-$1Fxx (below I/O space): plain (dp),Y using whatever DBR currently is', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$1000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x10 }, // pointer high byte
        { addr: addr24(DBR, 0x1005), value: 0x11 }, // expected: DBR-relative (not DP-relative -- ptr+Y is an absolute address)
        { addr: addr24(PBR, 0x1005), value: 0x99 },  // decoy: K/PBR bank, must not be read
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0x11);
  });

  test('$20xx-$5Fxx (I/O + expansion space): floating-bus read returns the pointer\'s own high byte', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$3000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x30 }, // pointer high byte
        { addr: addr24(DBR, 0x3005), value: 0x99 }, // decoy: real memory must NOT be read here
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0x30);
  });

  test('$60xx-$7Fxx (WRAM): plain (dp),Y using whatever DBR currently is', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$6000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x60 }, // pointer high byte
        { addr: addr24(DBR, 0x6005), value: 0x22 }, // expected: DBR-relative
        { addr: addr24(PBR, 0x6005), value: 0x99 },  // decoy: K/PBR bank, must not be read
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0x22);
  });

  test('$80xx-$BFxx (switchable PRG window): forces DBR = K before reading', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$9000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x90 }, // pointer high byte
        { addr: addr24(PBR, 0x9005), value: 0xEF }, // expected: read from K (program bank), not DBR
        { addr: addr24(DBR, 0x9005), value: 0x11 }, // decoy: caller's DBR, must not be read
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0xEF);
  });

  test('$C0xx-$FFxx (fixed PRG bank): plain (dp),Y using whatever DBR currently is (NOT forced to K)', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$C000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0xC0 }, // pointer high byte
        { addr: addr24(DBR, 0xC005), value: 0x33 }, // expected: DBR-relative, unlike the $80-$BF case
        { addr: addr24(PBR, 0xC005), value: 0x44 },  // decoy: K/PBR bank, must not be read
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0x33);
  });
});

describe('MMC1_LDA_IND_Y — caller flags are preserved (Bug 1 regression)', () => {
  // A plain `LDA (dp),Y` never touches the carry flag; the macro's
  // internal CMP-based dispatch chain must not leak through to the caller.
  test('carry set before the call is still set after', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$1000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x10 }, // pointer high byte
        { addr: addr24(PBR, 0x1000), value: 0x00 },
      ), { mx: 2 })
      // P's M/X bits (0x30) must be set too, matching mx=3 (8-bit A/X/Y) --
      // when P is given, it fully determines the mode (overriding `mx`),
      // and this macro's assembled immediates are only correct in 8-bit mode.
      .jsr('TestLoad', { Y: 0x00, DBR: PBR, P: 0x31, ...default_regs }) // 8-bit mode, carry set
      .run();
    expect(r.P & 0x01).toBe(0x01);
  });

  test('carry clear before the call is still clear after', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$1000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x10 }, // pointer high byte
        { addr: addr24(PBR, 0x1000), value: 0x00 },
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x00, DBR: PBR, P: 0x30, ...default_regs }) // 8-bit mode, carry clear
      .run();
    expect(r.P & 0x01).toBe(0x00);
  });
});

describe('MMC1_LDA_IND_Y — zero-page path clears the hidden accumulator high byte (Bug 2 regression)', () => {
  // The zero-page/stack handler does its lookup with a 16-bit LDA (it is
  // briefly in rep #$31 mode internally), which naturally reads the byte
  // *after* the target too. Bug 2 was failing to mask that stray byte
  // out of A's hidden high byte (the "B" half) before dropping back to
  // 8-bit mode with SEP #$30. Placing a distinctive "poison" byte right
  // after the target address turns a reintroduction of that bug into a
  // failing high byte here.
  test('A is exactly $00AB, not poisoned by the following byte in memory', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x50 }, // pointer low byte -> ptr=$0050
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x00 }, // pointer high byte
        { addr: addr24(Bank00, default_regs.DP + 0x55), value: 0xAB }, // target byte: bank0[DP + $0050 + $05]
        { addr: addr24(Bank00, default_regs.DP + 0x56), value: 0x77 }, // poison: the following byte
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR: PBR, mx: 3, ...default_regs })
      .run();
    expect(r.A).toBe(0x00AB);
  });
});

describe('MMC1_LDA_IND_Y — X and Y (visible byte) are preserved across the call', () => {
  // Neither register is part of the calling convention's output -- X isn't
  // touched by the "ok"/"hi" branches at all, and where it is touched (the
  // zero-page branch's phx/plx pair) it's meant to come back unchanged.
  test('X is unchanged', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$1000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x10 }, // pointer high byte
        { addr: addr24(DBR, 0x1005), value: 0x42 }, // target byte -- value is irrelevant to this test
      ), { mx: 2 })
      .jsr('TestLoad', { X: 0x99, Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.X & 0xFF).toBe(0x99);
  });

  test('Y is unchanged', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$1000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x10 }, // pointer high byte
        { addr: addr24(DBR, 0x1005), value: 0x42 }, // target byte -- value is irrelevant to this test
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.Y & 0xFF).toBe(0x05);
  });
});

describe('MMC1_LDA_IND_Y — N and Z flags reflect the loaded byte', () => {
  // All three branches (ok/hi/zpage) funnel into the shared "tail" label,
  // which does `plp; pha; pla` specifically to re-derive N/Z from the
  // loaded value after `plp` may have clobbered them with the caller's
  // pre-call flags. One branch is enough to exercise that shared code.
  test('a value with bit 7 set -> N set, Z clear', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$1000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x10 }, // pointer high byte
        { addr: addr24(DBR, 0x1005), value: 0x80 }, // negative, non-zero
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0x80);
    expect(r.P & 0x80).toBe(0x80); // N set
    expect(r.P & 0x02).toBe(0x00); // Z clear
  });

  test('a positive non-zero value -> N clear, Z clear', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$1000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x10 }, // pointer high byte
        { addr: addr24(DBR, 0x1005), value: 0x01 }, // positive, non-zero
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0x01);
    expect(r.P & 0x80).toBe(0x00); // N clear
    expect(r.P & 0x02).toBe(0x00); // Z clear
  });

  test('a zero value -> N clear, Z set', async () => {
    const r = await sequence()
      .inline(poke(
        { addr: addr24(Bank00, default_regs.DP + 0x00), value: 0x00 }, // pointer low byte -> ptr=$1000
        { addr: addr24(Bank00, default_regs.DP + 0x01), value: 0x10 }, // pointer high byte
        { addr: addr24(DBR, 0x1005), value: 0x00 }, // zero
      ), { mx: 2 })
      .jsr('TestLoad', { Y: 0x05, DBR, mx: 3, ...default_regs })
      .run();
    expect(r.A & 0xFF).toBe(0x00);
    expect(r.P & 0x80).toBe(0x00); // N clear
    expect(r.P & 0x02).toBe(0x02); // Z set
  });
});

// NOTE: an X/Y "hidden high byte survives an 8-bit-index call" test was
// deliberately NOT added here. Unlike the accumulator's B half (which does
// survive an M-width switch, per the Bug 2 coverage above), the 65816
// unconditionally zeroes XH/YH the instant the X flag is set (SEP #$10) --
// confirmed empirically with a trivial RTS-only stub called the same way
// (X loaded as $0142, mx transitioned to 3, X came back $0042 with zero
// macro code involved). Every real call site for this macro runs with
// mx=3 (8-bit A/X/Y, per each rom_0N.s's `mx %11`), so there is no "hidden"
// X/Y high byte for it to preserve or clobber. The actual NES-stack-page
// protection this codebase relies on (`src/rom/rom_exec.s:35-36`,
// `ldx yield_s / txs`) is a deliberate reload-and-TXS done in wide mode
// immediately before yielding to NES code, not a value expected to survive
// through an arbitrary 8-bit-mode subroutine call.

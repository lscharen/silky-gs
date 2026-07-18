/**
 * tests/ppu/ppuctrl_write.test.mjs
 *
 * Unit tests for PPUCTRL_WRITE ($2000 W) in src/ppu/ppu_regs.s.
 *
 * This handler emulates "sta $2000" — a NES PPU control register write.
 * It must decode bit fields from the written byte into four state variables:
 *
 *   ntaddr  (bits 0-1) — nametable base: $2000/$2400/$2800/$2C00
 *   ppuincr (bit 2)    — VRAM address increment: 1 or 32
 *   spadr   (bit 3)    — sprite pattern table: $0000 or $1000
 *   bgadr   (bit 4)    — background pattern table: $0000 or $1000
 *
 * It must also preserve A, X, Y, and P on return (no visible side effects).
 *
 * All tests call PPUCTRL_WRITE with mx:3 (sep #$30 before JSL) to match the
 * 8-bit mode the NES ROM uses when executing "sta $2000".
 */

import { describe, test, expect } from 'vitest';
import { cpu65816 }               from 'iigs-unit';
import sharedConfig               from './ppu_config'

/**
 * Call PPUCTRL_WRITE with the given byte value in A, then capture all four
 * PPU state variables.  Returns the full sequence result (registers + memory).
 *
 * @param {object} runner  - cpu65816 runner returned by cpu65816()
 * @param {number} value   - 8-bit value to write (A register on entry)
 * @param {object} [extra] - additional per-call options (e.g. X, Y, P)
 */
function writeCtrl(runner, value, extra = {}) {
  return runner.sequence()
    .jsl('PPUCTRL_WRITE', { A: value, mx: 3, ...extra })
    .captureMemory({ label: 'ntaddr',  as: 'word' })
    .captureMemory({ label: 'ppuincr', as: 'word' })
    .captureMemory({ label: 'spadr',   as: 'word' })
    .captureMemory({ label: 'bgadr',   as: 'word' })
    .run();
}

// ---------------------------------------------------------------------------
// ntaddr — bits 0-1 select the nametable base address
// ---------------------------------------------------------------------------
describe('PPUCTRL_WRITE — ntaddr (bits 0-1)', () => {
  const runner = cpu65816(sharedConfig);

  test('bits 0-1 = 00 → ntaddr $2000', async () => {
    const r = await writeCtrl(runner, 0x00);
    expect(r.memory.ntaddr).toBe(0x2000);
  });

  test('bits 0-1 = 01 → ntaddr $2400', async () => {
    const r = await writeCtrl(runner, 0x01);
    expect(r.memory.ntaddr).toBe(0x2400);
  });

  test('bits 0-1 = 10 → ntaddr $2800', async () => {
    const r = await writeCtrl(runner, 0x02);
    expect(r.memory.ntaddr).toBe(0x2800);
  });

  test('bits 0-1 = 11 → ntaddr $2C00', async () => {
    const r = await writeCtrl(runner, 0x03);
    expect(r.memory.ntaddr).toBe(0x2C00);
  });

  test('upper bits ignored when selecting nametable (0xFF → $2C00)', async () => {
    const r = await writeCtrl(runner, 0xFF);
    expect(r.memory.ntaddr).toBe(0x2C00);
  });
});

// ---------------------------------------------------------------------------
// ppuincr — bit 2 selects the VRAM address increment (1 or 32)
// ---------------------------------------------------------------------------
describe('PPUCTRL_WRITE — ppuincr (bit 2)', () => {
  const runner = cpu65816(sharedConfig);

  test('bit 2 clear → ppuincr = 1', async () => {
    const r = await writeCtrl(runner, 0x00);
    expect(r.memory.ppuincr).toBe(1);
  });

  test('bit 2 set → ppuincr = 32', async () => {
    const r = await writeCtrl(runner, 0x04);
    expect(r.memory.ppuincr).toBe(32);
  });

  test('bit 2 clear with bit 0 set → ppuincr = 1', async () => {
    // A = 0x01: bit 2 clear, bit 0 set.  The eor #$01 trick only works if A
    // is masked to $00 before the XOR (i.e. "and #$04", not "bit #$04").
    // With "bit #$04", A is unchanged so $01 ^ $01 = $00 instead of $01.
    const r = await writeCtrl(runner, 0x01);
    expect(r.memory.ppuincr).toBe(1);
  });

  test('bit 2 clear with NMI+NT bits set → ppuincr = 1', async () => {
    // A = 0x81: NMI enable + nametable 1, bit 2 clear.
    // With "bit #$04", $81 ^ $01 = $80 instead of $01.
    const r = await writeCtrl(runner, 0x81);
    expect(r.memory.ppuincr).toBe(1);
  });

  test('ppuincr reverts to 1 when bit 2 cleared by a second write', async () => {
    const r = await runner.sequence()
      .jsl('PPUCTRL_WRITE', { A: 0x04, mx: 3 })  // set ppuincr = 32
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })  // clear bit 2 → ppuincr = 1
      .captureMemory({ label: 'ppuincr', as: 'word' })
      .run();
    expect(r.memory.ppuincr).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// spadr — bit 3 selects the sprite pattern table ($0000 or $1000)
// ---------------------------------------------------------------------------
describe('PPUCTRL_WRITE — spadr (bit 3)', () => {
  const runner = cpu65816(sharedConfig);

  test('bit 3 clear → spadr = $0000', async () => {
    const r = await writeCtrl(runner, 0x00);
    expect(r.memory.spadr).toBe(0x0000);
  });

  test('bit 3 set → spadr = $1000', async () => {
    const r = await writeCtrl(runner, 0x08);
    expect(r.memory.spadr).toBe(0x1000);
  });

  test('spadr reverts to $0000 when bit 3 cleared by a second write', async () => {
    const r = await runner.sequence()
      .jsl('PPUCTRL_WRITE', { A: 0x08, mx: 3 })  // set spadr = $1000
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })  // clear bit 3 → spadr = $0000
      .captureMemory({ label: 'spadr', as: 'word' })
      .run();
    expect(r.memory.spadr).toBe(0x0000);
  });
});

// ---------------------------------------------------------------------------
// bgadr — bit 4 selects the background pattern table ($0000 or $1000)
// ---------------------------------------------------------------------------
describe('PPUCTRL_WRITE — bgadr (bit 4)', () => {
  const runner = cpu65816(sharedConfig);

  test('bit 4 clear → bgadr = $0000', async () => {
    const r = await writeCtrl(runner, 0x00);
    expect(r.memory.bgadr).toBe(0x0000);
  });

  test('bit 4 set → bgadr = $1000', async () => {
    const r = await writeCtrl(runner, 0x10);
    expect(r.memory.bgadr).toBe(0x1000);
  });

  test('bgadr reverts to $0000 when bit 4 cleared by a second write', async () => {
    const r = await runner.sequence()
      .jsl('PPUCTRL_WRITE', { A: 0x10, mx: 3 })  // set bgadr = $1000
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })  // clear bit 4 → bgadr = $0000
      .captureMemory({ label: 'bgadr', as: 'word' })
      .run();
    expect(r.memory.bgadr).toBe(0x0000);
  });
});

// ---------------------------------------------------------------------------
// All bits simultaneously — one write sets all four fields at once
// ---------------------------------------------------------------------------
describe('PPUCTRL_WRITE — all fields in a single write', () => {
  const runner = cpu65816(sharedConfig);

  test('0x1F sets ntaddr=$2C00, ppuincr=32, spadr=$1000, bgadr=$1000', async () => {
    const r = await writeCtrl(runner, 0x1F);
    expect(r.memory.ntaddr).toBe(0x2C00);
    expect(r.memory.ppuincr).toBe(32);
    expect(r.memory.spadr).toBe(0x1000);
    expect(r.memory.bgadr).toBe(0x1000);
  });

  test('0x00 resets all fields to defaults', async () => {
    const r = await runner.sequence()
      .jsl('PPUCTRL_WRITE', { A: 0x1F, mx: 3 })  // set everything
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })  // clear everything
      .captureMemory({ label: 'ntaddr',  as: 'word' })
      .captureMemory({ label: 'ppuincr', as: 'word' })
      .captureMemory({ label: 'spadr',   as: 'word' })
      .captureMemory({ label: 'bgadr',   as: 'word' })
      .run();
    expect(r.memory.ntaddr).toBe(0x2000);
    expect(r.memory.ppuincr).toBe(1);
    expect(r.memory.spadr).toBe(0x0000);
    expect(r.memory.bgadr).toBe(0x0000);
  });
});

// ---------------------------------------------------------------------------
// Register preservation — A, X, Y, P must be identical on entry and return
// ---------------------------------------------------------------------------
describe('PPUCTRL_WRITE — register preservation', () => {
  const runner = cpu65816(sharedConfig);

  test('A is unchanged on return', async () => {
    const r = await writeCtrl(runner, 0x42);
    expect(r.A).toBe(0x42);
  });

  test('X is unchanged on return', async () => {
    const r = await writeCtrl(runner, 0x00, { X: 0xAB });
    expect(r.X).toBe(0xAB);
  });

  test('Y is unchanged on return', async () => {
    const r = await writeCtrl(runner, 0x00, { Y: 0xCD });
    expect(r.Y).toBe(0xCD);
  });

  test('P is unchanged on return (php/plp round-trip)', async () => {
    // P = $31: M=1 (8-bit A), X=1 (8-bit X/Y), C=1 — distinctive carry bit.
    // The M and X bits must remain 1 (8-bit mode), and C must survive.
    const r = await writeCtrl(runner, 0x00, { P: 0x31 });
    expect(r.P).toBe(0x31);
  });

  test('all registers preserved simultaneously', async () => {
    // Use non-zero, non-trivial values so any clobber is detectable.
    const r = await writeCtrl(runner, 0x1E, { X: 0x55, Y: 0xAA, P: 0x31 });
    expect(r.A).toBe(0x1E);
    expect(r.X).toBe(0x55);
    expect(r.Y).toBe(0xAA);
    expect(r.P).toBe(0x31);
  });
});

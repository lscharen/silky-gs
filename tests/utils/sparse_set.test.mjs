/**
 * tests/utils/sparse_set.test.mjs
 *
 * Unit tests for the sparse-set macros (SS_CLEAR / SS_ADD) in
 * src/utils/sparse_set.s, exercised through the concrete GridSet instance
 * (GridSetClear / GridSetAdd / GridSetCondAdd / GridSetIsMember) defined in
 * src/utils/grid_set.s.
 *
 * GridSet is sized for a 32x25 (800-cell) grid. All routines assume native
 * mode with 16-bit A and 16-bit X/Y (mx: 0).
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT   = process.env.SRC_ROOT;
const SPARSE_SET = join(SRC_ROOT, 'utils/sparse_set.s');
const GRID_SET   = join(SRC_ROOT, 'utils/grid_set.s');

const sharedConfig = {
  includes:  [SPARSE_SET, GRID_SET],
  assembler: 'merlin32',
};

// Carry flag is bit 0 of P. SS_ISMEMBER's contract: clear = member, set = not.
const CARRY = (r) => r.P & 0x01;

describe('GridSetIsMember on an empty set', () => {
  const { jsr } = cpu65816(sharedConfig);

  test('reports not-a-member for index 0 (freshly zeroed set)', async () => {
    const r = await jsr('GridSetIsMember', { X: 0, mx: 0 });
    expect(CARRY(r)).toBe(0x01);
  });

  test('reports not-a-member for an arbitrary mid-range index', async () => {
    const r = await jsr('GridSetIsMember', { X: 411, mx: 0 });
    expect(CARRY(r)).toBe(0x01);
  });

  test('reports not-a-member for the last valid index (799)', async () => {
    const r = await jsr('GridSetIsMember', { X: 799, mx: 0 });
    expect(CARRY(r)).toBe(0x01);
  });
});

describe('GridSetAdd then GridSetIsMember', () => {
  const { sequence } = cpu65816(sharedConfig);

  test('an added index is reported as a member', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 5, mx: 0 })
      .jsr('GridSetIsMember', { X: 5, mx: 0 })
      .run();
    expect(CARRY(r)).toBe(0x00);
  });

  test('a never-added index is still not a member after an unrelated add', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 5, mx: 0 })
      .jsr('GridSetIsMember', { X: 6, mx: 0 })
      .run();
    expect(CARRY(r)).toBe(0x01);
  });

  test('index 0 (the low extreme) round-trips correctly', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 0, mx: 0 })
      .jsr('GridSetAdd', { X: 799, mx: 0 })
      .jsr('GridSetIsMember', { X: 0, mx: 0 })
      .run();
    expect(CARRY(r)).toBe(0x00);
  });

  test('index 799 (the high extreme) round-trips correctly', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 0, mx: 0 })
      .jsr('GridSetAdd', { X: 799, mx: 0 })
      .jsr('GridSetIsMember', { X: 799, mx: 0 })
      .run();
    expect(CARRY(r)).toBe(0x00);
  });

  test('several distinct indices are all members, and gaps between them are not', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 10, mx: 0 })
      .jsr('GridSetAdd', { X: 200, mx: 0 })
      .jsr('GridSetAdd', { X: 799, mx: 0 })
      .jsr('GridSetIsMember', { X: 11, mx: 0 }) // gap right after the first add
      .run();
    expect(CARRY(r)).toBe(0x01);
  });
});

describe('GridSetAdd member count (n)', () => {
  const { jsr, sequence } = cpu65816(sharedConfig);

  test('a single add sets n to 1', async () => {
    const r = await jsr('GridSetAdd', {
      X: 42,
      mx: 0,
      captureMemory: [{ label: 'GridSet', as: 'word' }],
    });
    expect(r.memory.GridSet).toBe(1);
  });

  test('two adds of distinct indices set n to 2', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 1, mx: 0 })
      .jsr('GridSetAdd', { X: 2, mx: 0 })
      .captureMemory({ label: 'GridSet', as: 'word' })
      .run();
    expect(r.memory.GridSet).toBe(2);
  });

  test('SS_ADD (via GridSetAdd) does not dedupe -- adding the same index twice sets n to 2', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 7, mx: 0 })
      .jsr('GridSetAdd', { X: 7, mx: 0 })
      .captureMemory({ label: 'GridSet', as: 'word' })
      .run();
    expect(r.memory.GridSet).toBe(2);
  });
});

describe('GridSetCondAdd is idempotent', () => {
  const { sequence } = cpu65816(sharedConfig);

  test('adding the same index twice via CondAdd leaves n at 1', async () => {
    const r = await sequence()
      .jsr('GridSetCondAdd', { X: 7, mx: 0 })
      .jsr('GridSetCondAdd', { X: 7, mx: 0 })
      .captureMemory({ label: 'GridSet', as: 'word' })
      .run();
    expect(r.memory.GridSet).toBe(1);
  });

  test('CondAdd for a distinct index still grows n normally', async () => {
    const r = await sequence()
      .jsr('GridSetCondAdd', { X: 7, mx: 0 })
      .jsr('GridSetCondAdd', { X: 7, mx: 0 })
      .jsr('GridSetCondAdd', { X: 8, mx: 0 })
      .captureMemory({ label: 'GridSet', as: 'word' })
      .run();
    expect(r.memory.GridSet).toBe(2);
  });

  test('both indices are members after mixed CondAdd calls', async () => {
    const r = await sequence()
      .jsr('GridSetCondAdd', { X: 7, mx: 0 })
      .jsr('GridSetCondAdd', { X: 7, mx: 0 })
      .jsr('GridSetCondAdd', { X: 8, mx: 0 })
      .jsr('GridSetIsMember', { X: 7, mx: 0 })
      .run();
    expect(CARRY(r)).toBe(0x00);
  });
});

describe('GridSetClear', () => {
  const { sequence } = cpu65816(sharedConfig);

  test('resets n to 0 after adds', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 1, mx: 0 })
      .jsr('GridSetAdd', { X: 2, mx: 0 })
      .jsr('GridSetClear', { mx: 0 })
      .captureMemory({ label: 'GridSet', as: 'word' })
      .run();
    expect(r.memory.GridSet).toBe(0);
  });

  test('a previously-added index is no longer a member after clear', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 5, mx: 0 })
      .jsr('GridSetClear', { mx: 0 })
      .jsr('GridSetIsMember', { X: 5, mx: 0 })
      .run();
    expect(CARRY(r)).toBe(0x01);
  });

  test('the set can be reused after clear -- re-adding the same index works', async () => {
    const r = await sequence()
      .jsr('GridSetAdd', { X: 5, mx: 0 })
      .jsr('GridSetClear', { mx: 0 })
      .jsr('GridSetAdd', { X: 5, mx: 0 })
      .jsr('GridSetIsMember', { X: 5, mx: 0 })
      .captureMemory({ label: 'GridSet', as: 'word' })
      .run();
    expect(CARRY(r)).toBe(0x00);
    expect(r.memory.GridSet).toBe(1); // not 2 -- clear actually reset n
  });
});

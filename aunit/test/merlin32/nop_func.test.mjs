/**
 * aunit/test/merlin32/nop_func.test.mjs
 *
 * Tests a trivial RTL function via the Merlin32 assembler.
 * Verifies that the Merlin32 code-generation path (rel / PUT includes)
 * round-trips A, X, Y correctly.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { cpu65816 }               from 'aunit';
import { hasMerlin }              from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasMerlin)('NopFunc — Merlin32', () => {
  const { jsl } = cpu65816({
    includes:  [join(__dirname, 'nop_func.s')],
    testDir:   __dirname,
    assembler: 'merlin32',
  });

  test('default call returns A=0', async () => {
    const r = await jsl('NopFunc');
    expect(r.A).toBe(0);
  });

  test('preserves A', async () => {
    const r = await jsl('NopFunc', { A: 0x1234 });
    expect(r.A).toBe(0x1234);
  });

  test('preserves X', async () => {
    const r = await jsl('NopFunc', { X: 0xABCD });
    expect(r.X).toBe(0xABCD);
  });

  test('preserves Y', async () => {
    const r = await jsl('NopFunc', { Y: 0x5678 });
    expect(r.Y).toBe(0x5678);
  });

  test('preserves all three registers simultaneously', async () => {
    const r = await jsl('NopFunc', { A: 0x0001, X: 0x0002, Y: 0x0003 });
    expect(r.A).toBe(0x0001);
    expect(r.X).toBe(0x0002);
    expect(r.Y).toBe(0x0003);
  });

  test('result includes valid AUNT packet', async () => {
    const r = await jsl('NopFunc');
    expect(r.raw.slice(0, 4).toString('ascii')).toBe('AUNT');
  });
});

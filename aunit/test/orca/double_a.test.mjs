/**
 * aunit/test/orca/double_a.test.mjs
 *
 * Tests a function that doubles A (ASL A, RTL).
 * Verifies arithmetic results and P-flag capture (carry, zero, negative).
 * Assembler: ORCA/M.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { cpu65816 }               from 'aunit';
import { hasIix }                 from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasIix)('DoubleA — ORCA/M', () => {
  const { jsl } = cpu65816({
    includes: [join(__dirname, 'double_a.s')],
    testDir:  __dirname,
  });

  test('doubles a non-zero value', async () => {
    const r = await jsl('DoubleA', { A: 0x0010 });
    expect(r.A).toBe(0x0020);
  });

  test('doubles zero gives zero', async () => {
    const r = await jsl('DoubleA', { A: 0x0000 });
    expect(r.A).toBe(0x0000);
  });

  test('zero flag set when result is zero', async () => {
    const r = await jsl('DoubleA', { A: 0x0000 });
    expect(r.P & 0x02).toBe(0x02);
  });

  test('overflow into high bit sets negative flag', async () => {
    const r = await jsl('DoubleA', { A: 0x4000 });
    expect(r.A).toBe(0x8000);
    expect(r.P & 0x80).toBe(0x80);
  });

  test('MSB shift sets carry flag', async () => {
    const r = await jsl('DoubleA', { A: 0x8000 });
    expect(r.A).toBe(0x0000);
    expect(r.P & 0x01).toBe(0x01);
  });

  test('does not affect X or Y', async () => {
    const r = await jsl('DoubleA', { A: 0x0001, X: 0x1111, Y: 0x2222 });
    expect(r.X).toBe(0x1111);
    expect(r.Y).toBe(0x2222);
  });
});

/**
 * aunit/test/orca/return_x_in_a.test.mjs
 *
 * Tests a function that transfers X into A (TXA, RTL).
 * Verifies that the X input register is correctly passed to the
 * function and that the result appears in A.
 * Assembler: ORCA/M.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { cpu65816 }               from 'aunit';
import { hasIix }                 from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasIix)('ReturnXInA — ORCA/M', () => {
  const { jsl } = cpu65816({
    includes: [join(__dirname, 'return_x_in_a.s')],
    testDir:  __dirname,
  });

  test('returns X value in A', async () => {
    const r = await jsl('ReturnXInA', { X: 0x1234 });
    expect(r.A).toBe(0x1234);
  });

  test('returns X=0 in A', async () => {
    const r = await jsl('ReturnXInA', { X: 0x0000 });
    expect(r.A).toBe(0x0000);
  });

  test('returns X=0xFFFF in A', async () => {
    const r = await jsl('ReturnXInA', { X: 0xFFFF });
    expect(r.A).toBe(0xFFFF);
  });

  test('TXA does not modify X', async () => {
    const r = await jsl('ReturnXInA', { X: 0xBEEF });
    expect(r.A).toBe(0xBEEF);
    expect(r.X).toBe(0xBEEF);
  });

  test('zero flag set when X=0', async () => {
    const r = await jsl('ReturnXInA', { X: 0x0000 });
    expect(r.P & 0x02).toBe(0x02);
  });

  test('negative flag set when X MSB is set', async () => {
    const r = await jsl('ReturnXInA', { X: 0x8000 });
    expect(r.P & 0x80).toBe(0x80);
  });
});

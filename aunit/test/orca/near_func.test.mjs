/**
 * aunit/test/orca/near_func.test.mjs
 *
 * Tests the jsr calling convention: the generated harness emits JSR (near
 * call, 16-bit return address) instead of JSL (far call, 24-bit return
 * address).  The function under test must use RTS to return.
 * Assembler: ORCA/M.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { cpu65816 }               from 'aunit';
import { hasIix }                 from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasIix)('NearFunc — ORCA/M jsr convention', () => {
  const { jsr } = cpu65816({
    includes: [join(__dirname, 'near_func.s')],
    testDir:  __dirname,
  });

  test('doubles A via jsr/rts', async () => {
    const r = await jsr('NearFunc', { A: 0x0010 });
    expect(r.A).toBe(0x0020);
  });

  test('doubles A=1 to 2', async () => {
    const r = await jsr('NearFunc', { A: 0x0001 });
    expect(r.A).toBe(0x0002);
  });

  test('carry set when MSB overflows', async () => {
    const r = await jsr('NearFunc', { A: 0x8000 });
    expect(r.A).toBe(0x0000);
    expect(r.P & 0x01).toBe(0x01);
  });

  test('zero flag set when result is zero', async () => {
    const r = await jsr('NearFunc', { A: 0x0000 });
    expect(r.P & 0x02).toBe(0x02);
  });
});

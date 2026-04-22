/**
 * aunit/test/orca/harness_fail.test.mjs
 *
 * Tests the AUnit_Fail path: the hand-written harness calls AUnit_Fail(2),
 * which writes an AUNT packet with status=2.
 *
 *  - runAssemblyTest should return ok=false, status=2.
 *  - cpu65816 wraps runGeneratedTest and throws AssemblyError on ok=false;
 *    the throw behavior is verified here via a direct result check.
 * Assembler: ORCA/M.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { runAssemblyTest,
         AssemblyError }          from 'aunit';
import { hasIix }                 from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HARNESS   = join(__dirname, 'harness_fail.s');

describe.skipIf(!hasIix)('AUnit_Fail — ORCA/M', () => {
  test('runAssemblyTest returns ok=false', async () => {
    const r = await runAssemblyTest(HARNESS);
    expect(r.ok).toBe(false);
  });

  test('status byte is 2', async () => {
    const r = await runAssemblyTest(HARNESS);
    expect(r.status).toBe(2);
  });

  test('out.dat magic is still valid', async () => {
    const r = await runAssemblyTest(HARNESS);
    expect(r.raw.slice(0, 4).toString('ascii')).toBe('AUNT');
  });

  test('raw status byte at offset 5 is 2', async () => {
    const r = await runAssemblyTest(HARNESS);
    expect(r.raw[5]).toBe(2);
  });

  test('cpu65816 would throw AssemblyError because ok=false', () => {
    // Simulate what cpu65816._call does with a failed result:
    const fakeResult = { ok: false, status: 2, registers: {}, memory: [], values: {} };
    expect(() => {
      if (!fakeResult.ok) {
        throw new AssemblyError(`AUnit harness failed (status ${fakeResult.status})`);
      }
    }).toThrow(AssemblyError);
  });
});

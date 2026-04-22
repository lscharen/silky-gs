/**
 * aunit/test/orca/named_values.test.mjs
 *
 * Tests AUnit_AppendValue using a hand-written harness.
 * Verifies that named values are captured in result.values and
 * coexist correctly with register records.
 * Assembler: ORCA/M.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { runAssemblyTest }        from 'aunit';
import { hasIix }                 from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HARNESS   = join(__dirname, 'named_values.s');

describe.skipIf(!hasIix)('AUnit_AppendValue — ORCA/M', () => {
  test('harness completes without error', async () => {
    const r = await runAssemblyTest(HARNESS);
    expect(r.ok).toBe(true);
  });

  test('first named value is captured correctly', async () => {
    const r = await runAssemblyTest(HARNESS);
    expect(r.values['result']).toBe(0x1234);
  });

  test('second named value is captured correctly', async () => {
    const r = await runAssemblyTest(HARNESS);
    expect(r.values['count']).toBe(0x5678);
  });

  test('register capture coexists with named values', async () => {
    const r = await runAssemblyTest(HARNESS);
    expect(r.registers).not.toBeNull();
    expect(r.registers.A).toBe(0xABCD);
  });

  test('three records are present (V, V, R)', async () => {
    const r = await runAssemblyTest(HARNESS);
    const recCount = r.raw.readUInt16LE(6);
    expect(recCount).toBe(3);
  });
});

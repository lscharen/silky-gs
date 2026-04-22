/**
 * aunit/test/merlin32/named_values.test.mjs
 *
 * Tests AUnit_AppendValue via a hand-written Merlin32 harness.
 * Mirrors the ORCA named_values tests to confirm identical behavior
 * across assemblers.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { runAssemblyTest }        from 'aunit';
import { hasMerlin }              from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HARNESS   = join(__dirname, 'named_values.s');

describe.skipIf(!hasMerlin)('AUnit_AppendValue — Merlin32', () => {
  test('harness completes without error', async () => {
    const r = await runAssemblyTest(HARNESS, { assembler: 'merlin32' });
    expect(r.ok).toBe(true);
  });

  test('first named value is captured correctly', async () => {
    const r = await runAssemblyTest(HARNESS, { assembler: 'merlin32' });
    expect(r.values['result']).toBe(0x1234);
  });

  test('second named value is captured correctly', async () => {
    const r = await runAssemblyTest(HARNESS, { assembler: 'merlin32' });
    expect(r.values['count']).toBe(0x5678);
  });

  test('register capture coexists with named values', async () => {
    const r = await runAssemblyTest(HARNESS, { assembler: 'merlin32' });
    expect(r.registers).not.toBeNull();
    expect(r.registers.A).toBe(0xABCD);
  });
});

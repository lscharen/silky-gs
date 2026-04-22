/**
 * aunit/test/merlin32/harness_fail.test.mjs
 *
 * Tests the AUnit_Fail path via the Merlin32 assembler.
 * Mirrors the ORCA harness_fail tests to confirm identical behavior
 * across assembler paths.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { runAssemblyTest }        from 'aunit';
import { hasMerlin }              from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HARNESS   = join(__dirname, 'harness_fail.s');

describe.skipIf(!hasMerlin)('AUnit_Fail — Merlin32', () => {
  test('runAssemblyTest returns ok=false', async () => {
    const r = await runAssemblyTest(HARNESS, { assembler: 'merlin32' });
    expect(r.ok).toBe(false);
  });

  test('status byte is 2', async () => {
    const r = await runAssemblyTest(HARNESS, { assembler: 'merlin32' });
    expect(r.status).toBe(2);
  });

  test('raw status byte at offset 5 is 2', async () => {
    const r = await runAssemblyTest(HARNESS, { assembler: 'merlin32' });
    expect(r.raw[5]).toBe(2);
  });
});

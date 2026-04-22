/**
 * aunit/test/orca/no_results.test.mjs
 *
 * Verifies that a harness which exits without calling AUnit_WriteResults
 * causes runAssemblyTest to throw AssemblyError mentioning "out.dat".
 * iix exits normally (0xFFFFFFFE) — the error is detected by the runner
 * when it tries to read the missing output file.
 * Assembler: ORCA/M.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { runAssemblyTest,
         AssemblyError }          from 'aunit';
import { hasIix }                 from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasIix)('Missing out.dat — ORCA/M', () => {
  test('throws AssemblyError when harness never writes out.dat', async () => {
    await expect(
      runAssemblyTest(join(__dirname, 'no_results.s'))
    ).rejects.toBeInstanceOf(AssemblyError);
  });

  test('error message mentions out.dat', async () => {
    await expect(
      runAssemblyTest(join(__dirname, 'no_results.s'))
    ).rejects.toThrow(/out\.dat/i);
  });
});

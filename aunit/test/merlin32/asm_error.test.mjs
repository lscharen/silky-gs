/**
 * aunit/test/merlin32/asm_error.test.mjs
 *
 * Verifies that a broken Merlin32 source causes runAssemblyTest and
 * runGeneratedTest to throw AssemblyError.  Merlin32 assembles and
 * links in one step, so an undefined label fails during that step.
 */

import { describe, test, expect }              from 'vitest';
import { join, dirname }                        from 'node:path';
import { fileURLToPath }                        from 'node:url';
import { runAssemblyTest, runGeneratedTest,
         AssemblyError }                        from 'aunit';
import { hasMerlin }                            from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasMerlin)('Assembly error — Merlin32', () => {
  test('runAssemblyTest throws AssemblyError', async () => {
    await expect(
      runAssemblyTest(join(__dirname, 'asm_error.s'), { assembler: 'merlin32' })
    ).rejects.toBeInstanceOf(AssemblyError);
  });

  test('AssemblyError message mentions merlin32 assemble step', async () => {
    await expect(
      runAssemblyTest(join(__dirname, 'asm_error.s'), { assembler: 'merlin32' })
    ).rejects.toThrow(/merlin32 assemble/i);
  });

  test('runGeneratedTest throws AssemblyError for bad include', async () => {
    await expect(
      runGeneratedTest({
        testDir:   __dirname,
        assembler: 'merlin32',
        call:      'Main',
        includes:  [join(__dirname, 'asm_error.s')],
      })
    ).rejects.toBeInstanceOf(AssemblyError);
  });
});

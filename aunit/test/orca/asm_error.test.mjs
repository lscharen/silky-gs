/**
 * aunit/test/orca/asm_error.test.mjs
 *
 * Verifies that a broken source file causes runAssemblyTest and
 * runGeneratedTest to throw AssemblyError at the assemble step.
 * Assembler: ORCA/M.
 */

import { describe, test, expect }              from 'vitest';
import { join, dirname }                        from 'node:path';
import { fileURLToPath }                        from 'node:url';
import { runAssemblyTest, runGeneratedTest,
         AssemblyError }                        from 'aunit';
import { hasIix }                               from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasIix)('Assembler error — ORCA/M', () => {
  test('runAssemblyTest throws AssemblyError', async () => {
    await expect(
      runAssemblyTest(join(__dirname, 'asm_error.s'))
    ).rejects.toBeInstanceOf(AssemblyError);
  });

  test('AssemblyError message mentions assemble step', async () => {
    await expect(
      runAssemblyTest(join(__dirname, 'asm_error.s'))
    ).rejects.toThrow(/assemble/i);
  });

  test('runGeneratedTest throws AssemblyError when include has bad syntax', async () => {
    await expect(
      runGeneratedTest({
        testDir:  __dirname,
        call:     'AsmError',
        includes: [join(__dirname, 'asm_error.s')],
      })
    ).rejects.toBeInstanceOf(AssemblyError);
  });
});

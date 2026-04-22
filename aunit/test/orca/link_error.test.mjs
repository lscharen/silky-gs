/**
 * aunit/test/orca/link_error.test.mjs
 *
 * Verifies that an undefined symbol causes runAssemblyTest to throw
 * AssemblyError.  The error may be raised at either the assemble
 * or link step depending on ORCA/M's symbol resolution strategy.
 * Assembler: ORCA/M.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { runAssemblyTest,
         AssemblyError }          from 'aunit';
import { hasIix }                 from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasIix)('Linker error — ORCA/M', () => {
  test('throws AssemblyError for undefined external symbol', async () => {
    await expect(
      runAssemblyTest(join(__dirname, 'link_error.s'))
    ).rejects.toBeInstanceOf(AssemblyError);
  });
});

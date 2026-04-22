/**
 * aunit/test/merlin32/near_func.test.mjs
 *
 * Tests the jsr calling convention via Merlin32.
 * Confirms that the Merlin32 generated harness emits JSR instead of JSL
 * and that the function correctly returns with RTS.
 */

import { describe, test, expect } from 'vitest';
import { join, dirname }          from 'node:path';
import { fileURLToPath }          from 'node:url';
import { cpu65816 }               from 'aunit';
import { hasMerlin }              from '../helpers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe.skipIf(!hasMerlin)('NearFunc — Merlin32 jsr convention', () => {
  const { jsr } = cpu65816({
    includes:  [join(__dirname, 'near_func.s')],
    testDir:   __dirname,
    assembler: 'merlin32',
  });

  test('doubles A via jsr/rts', async () => {
    const r = await jsr('NearFunc', { A: 0x0010 });
    expect(r.A).toBe(0x0020);
  });

  test('carry set when MSB overflows', async () => {
    const r = await jsr('NearFunc', { A: 0x8000 });
    expect(r.A).toBe(0x0000);
    expect(r.P & 0x01).toBe(0x01);
  });
});

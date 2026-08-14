/**
 * tests/rom/rom_chrram.test.mjs
 *
 * Tests for ConvertCHRTileBG in src/rom/rom_chrram.s.
 *
 * ConvertCHRTileBG's own job is narrow: call the existing ROMTileToBitmap
 * (rom_tiles.s, unmodified) to decode CHR bytes into TileBuff, then copy
 * the resulting 32-byte swizzle-index bitmap to a caller-supplied tiledata
 * destination -- without compiling it. ROMTileToBitmap's own conversion
 * correctness is covered directly in tests/rom/rom_tiles.test.mjs, so it's
 * mocked out here rather than re-verified: these tests only need to prove
 * that ConvertCHRTileBG (a) calls it with the CHR source address it was
 * given, and (b) copies whatever ends up in TileBuff to the correct
 * tiledata offset.
 *
 * Calling convention:
 *   X (16-bit) = CHR-RAM source address (tile_id*16 + PPU_BG_TILE_ADDR)
 *   Y (16-bit) = destination offset within tiledata (tile_id*128 + $8000
 *                in production; the routine itself is offset-agnostic, so
 *                these tests use small offsets for readability)
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT   = process.env.SRC_ROOT;
const ROM_CHRRAM = join(SRC_ROOT, 'rom/rom_chrram.s');

const TEST_BITMAP = [
  0x00, 0x02, 0x04, 0x06, 0x08, 0x0A, 0x0C, 0x0E,
  0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x1C, 0x1E,
  0x20, 0x22, 0x24, 0x26, 0x28, 0x2A, 0x2C, 0x2E,
  0x30, 0x32, 0x34, 0x36, 0x38, 0x3A, 0x3C, 0x3E,
];

const { jsr } = cpu65816({
  includes:  [ROM_CHRRAM],
  assembler: 'merlin32',
  mocks: {
    ROMTileToBitmap: { callType: 'jsr' }, // real conversion is out of scope; see file header
  },
});

describe('ConvertCHRTileBG', () => {
  test('copies TileBuff into tiledata at the caller-supplied offset', async () => {
    const r = await jsr('ConvertCHRTileBG', {
      X: 0x1234, // CHR source address -- passed through to the (mocked) ROMTileToBitmap
      Y: 0,
      mx: 0,
      allocMemory: [
        { label: 'TileBuff', data: TEST_BITMAP },
        { label: 'tiledata', as: 'byte', count: 32 },
      ],
    });

    expect(r.memory.tiledata).toEqual(TEST_BITMAP);
  });

  test('destination offset (Y) is honored -- writes land at tiledata+Y, not tiledata+0', async () => {
    const r = await jsr('ConvertCHRTileBG', {
      X: 0x1234,
      Y: 32, // second tile slot
      mx: 0,
      allocMemory: [
        { label: 'TileBuff', data: TEST_BITMAP },
        { label: 'tiledata', as: 'byte', count: 64 },
      ],
    });

    expect(r.memory.tiledata.slice(0, 32)).toEqual(new Array(32).fill(0));
    expect(r.memory.tiledata.slice(32, 64)).toEqual(TEST_BITMAP);
  });

  test('calls ROMTileToBitmap with X set to the CHR source address it was given', async () => {
    const { jsr: jsrRecording } = cpu65816({
      includes:  [ROM_CHRRAM],
      assembler: 'merlin32',
      mocks: {
        ROMTileToBitmap: { callType: 'jsr', record: true },
      },
    });

    const r = await jsrRecording('ConvertCHRTileBG', {
      X: 0x5678,
      Y: 0,
      mx: 0,
      allocMemory: [
        { label: 'TileBuff', data: TEST_BITMAP },
        { label: 'tiledata', as: 'byte', count: 32 },
      ],
    });

    expect(r.mocks.ROMTileToBitmap).toHaveLength(1);
    expect(r.mocks.ROMTileToBitmap[0].X).toBe(0x5678);
  });

  test('leaves TileBuff untouched by the copy (sanity check on source, not just destination)', async () => {
    const r = await jsr('ConvertCHRTileBG', {
      X: 0x1234,
      Y: 0,
      mx: 0,
      allocMemory: [
        { label: 'TileBuff', data: TEST_BITMAP },
        { label: 'tiledata', as: 'byte', count: 32 },
      ],
    });

    expect(r.memory.TileBuff).toEqual(Buffer.from(TEST_BITMAP));
  });
});

/**
 * tests/rom/rom_tiles.test.mjs
 *
 * Unit tests for ROMTileToLookup, ROMTileToBitmap, ConvertROMTile2, and
 * FastROMTileToLookup in src/rom/rom_tiles.s -- the routines that actually
 * decode NES CHR-ROM tile bytes into the runtime's internal formats.
 *
 * rom_tiles.s was split out of rom_helpers.s specifically so this low-level
 * conversion code could be assembled (and unit tested) on its own, without
 * the per-game tile-loading/sprite-compilation machinery (tile bank
 * addresses, CompileSprite, the AUTOMATIC_PALETTE_MAPPING engine, etc.)
 * that rom_helpers.s needs. The only symbols it still expects from its
 * assembly context are tmp0-tmp4 (direct-page scratch, normally defined in
 * src/core/Defs.s), CompileTile (only reachable through ConvertROMTile3,
 * which isn't under test here), and tiledata (FastROMTileToLookup writes
 * into it via a long pointer -- TileDataPtr is its own internal DP alias
 * for tmp0, not something callers provide). STUBS below supplies the first
 * two; tiledata is allocated per-test in the FastROMTileToLookup describe
 * block since its content is what's under test.
 *
 * ROMTileToLookup/ROMTileToBitmap/ConvertROMTile2's expected outputs are
 * computed by scripts/lib/nesTileConvert.js, a byte-for-byte JS
 * transliteration of those three routines (see that file's header comment).
 * These tests prove the transliteration is faithful to the real 65816 code;
 * scripts/convert-chr-rom.js then relies on that proof to generate static
 * conversion tables without needing the IIgs runtime. FastROMTileToLookup is
 * checked directly against ROMTileToBitmap's output instead (same algorithm,
 * different destination-addressing strategy -- see its describe block).
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';
import nesTileConvert             from '../../scripts/lib/nesTileConvert.js';

const { romTileToLookup, romTileToBitmap, convertRomTile2 } = nesTileConvert;

// Extra tile fixtures for FastROMMaskedTileToLookup, chosen so every 2-bit
// pixel field within a row (and therefore every combined byte the row-based
// swap logic exercises) sees both zero and non-zero values across the tile.
const TILE_STAGGERED = [
  0x55, 0xAA, 0x33, 0xCC, 0x0F, 0xF0, 0x69, 0x96,
  0x0F, 0xF0, 0x55, 0xAA, 0x96, 0x69, 0xCC, 0x33,
];

const SRC_ROOT   = process.env.SRC_ROOT;
const ROM_TILES  = join(SRC_ROOT, 'rom/rom_tiles.s');

// Stubs for symbols rom_tiles.s expects a per-game Main.s to provide.
// See file header for what each one is standing in for.
const STUBS = `\
CompileTile equ $000000

; Direct-page scratch -- same offsets as src/core/Defs.s
tmp0 equ 240
tmp1 equ 242
tmp2 equ 244
tmp3 equ 246
tmp4 equ 248
`;

const { jsr } = cpu65816({
  includes: [ROM_TILES],
  assembler: 'merlin32',
  inline: [STUBS],
  // FastROMTileToLookup references `tiledata` unconditionally (`lda #^tiledata`),
  // so every test that assembles rom_tiles.s needs the symbol defined, not
  // just the FastROMTileToLookup tests -- shared here so the others don't
  // each need a throwaway allocation just to satisfy the assembler.
  allocMemory: [
    { label: 'tiledata', length: 32 },
  ],
});

// Separate cpu65816 instance for FastROMMaskedTileToLookup: that suite needs
// to declare 'tiledata' itself (via inline, with page-alignment padding in
// front of it -- see its describe block), which would collide with the
// shared 32-byte 'tiledata' allocMemory default above (both declare the same
// label, and merlin32 doesn't reliably fail loudly on the duplicate -- it
// just silently produces a harness that never reaches AUnit_WriteResults).
const { jsr: jsrMasked } = cpu65816({
  includes: [ROM_TILES],
  assembler: 'merlin32',
  inline: [STUBS],
});

// ─── sample tiles ──────────────────────────────────────────────────────────

// All bits clear on both bit planes.
const TILE_ZERO = new Array(16).fill(0x00);

// All bits set on both bit planes -- every pixel is color 3.
const TILE_SOLID = new Array(16).fill(0xFF);

// Worked example from the rom_tiles.s ROMTileToLookup header comment.
const TILE_EXAMPLE = [
  0x03, 0x0F, 0x1F, 0x1F, 0x1C, 0x24, 0x26, 0x66,
  0x00, 0x00, 0x00, 0x00, 0x1F, 0x3F, 0x3F, 0x7F,
];

// Distinct, non-symmetric bit patterns on each plane so every DLUT2/DLUT2_shft/
// MLUT4 table entry (0-15) is exercised across the 8 rows.
const TILE_MIXED = [
  0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
  0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88,
];

const SAMPLE_TILES = {
  zero: TILE_ZERO,
  solid: TILE_SOLID,
  example: TILE_EXAMPLE,
  mixed: TILE_MIXED,
};

// ─── ROMTileToLookup ────────────────────────────────────────────────────────

describe('ROMTileToLookup', () => {
  for (const [name, tile] of Object.entries(SAMPLE_TILES)) {
    test(`tile "${name}" matches the JS reference model`, async () => {
      const expected = Array.from(romTileToLookup(tile, 0));

      const r = await jsr('ROMTileToLookup', {
        A: 'dest',
        X: 0,
        mx: 0,
        allocMemory: [
          { label: 'CHR_ROM', data: tile },
          { label: 'dest', length: 32 },
        ],
      });

      expect(Array.from(r.memory.dest)).toEqual(expected);
    });
  }

  test('honors a non-zero tile offset (X) into CHR_ROM', async () => {
    const chr = [...TILE_ZERO, ...TILE_MIXED]; // tile 1 starts at offset 16
    const expected = Array.from(romTileToLookup(chr, 16));

    const r = await jsr('ROMTileToLookup', {
      A: 'dest',
      X: 16,
      mx: 0,
      allocMemory: [
        { label: 'CHR_ROM', data: chr },
        { label: 'dest', length: 32 },
      ],
    });

    expect(Array.from(r.memory.dest)).toEqual(expected);
  });

  test('leaves CHR_ROM untouched (read-only source)', async () => {
    const r = await jsr('ROMTileToLookup', {
      A: 'dest',
      X: 0,
      mx: 0,
      allocMemory: [
        { label: 'CHR_ROM', data: TILE_MIXED },
        { label: 'dest', length: 32 },
      ],
    });

    expect(Array.from(r.memory.CHR_ROM)).toEqual(TILE_MIXED);
  });
});

// ─── ROMTileToBitmap ────────────────────────────────────────────────────────

describe('ROMTileToBitmap', () => {
  for (const [name, tile] of Object.entries(SAMPLE_TILES)) {
    test(`tile "${name}" matches the JS reference model`, async () => {
      const expected = Array.from(romTileToBitmap(tile, 0));

      const r = await jsr('ROMTileToBitmap', {
        A: 'dest',
        X: 0,
        mx: 0,
        allocMemory: [
          { label: 'CHR_ROM', data: tile },
          { label: 'dest', length: 32 },
        ],
      });

      expect(Array.from(r.memory.dest)).toEqual(expected);
    });
  }
});

// ─── FastROMTileToLookup ────────────────────────────────────────────────────
//
// Converts straight from CHR_ROM into tiledata: A = destination *offset
// within* tiledata (not a full pointer -- the routine derives the bank
// byte itself from ^tiledata and builds its own internal 24-bit pointer,
// TileDataPtr, aliased to tmp0). X = CHR-ROM offset, same convention as
// ROMTileToLookup. So unlike that stub-provided-pointer approach tried
// earlier, 'tiledata' just needs to exist as an ordinary allocMemory label
// here -- no address needs to be pinned or poked in by hand.

describe('FastROMTileToLookup', () => {
  for (const [name, tile] of Object.entries(SAMPLE_TILES)) {
    test(`tile "${name}" matches the JS reference model`, async () => {
      const expected = Array.from(romTileToBitmap(tile, 0));

      const r = await jsr('FastROMTileToLookup', {
        A: 'tiledata',
        X: 0,
        mx: 0,
        allocMemory: [
          { label: 'CHR_ROM', data: tile },
          { label: 'tiledata', length: 32 },
        ],
      });

      expect(Array.from(r.memory.tiledata)).toEqual(expected);
    });
  }

  test('honors a non-zero tile offset (X) into CHR_ROM', async () => {
    const chr = [...TILE_ZERO, ...TILE_MIXED]; // tile 1 starts at offset 16
    const expected = Array.from(romTileToBitmap(chr, 16));

    const r = await jsr('FastROMTileToLookup', {
      A: 'tiledata',
      X: 16,
      mx: 0,
      allocMemory: [
        { label: 'CHR_ROM', data: chr },
        { label: 'tiledata', length: 32 },
      ],
    });

    expect(Array.from(r.memory.tiledata)).toEqual(expected);
  });

  test('leaves CHR_ROM untouched (read-only source)', async () => {
    const r = await jsr('FastROMTileToLookup', {
      A: 'tiledata',
      X: 0,
      mx: 0,
      allocMemory: [
        { label: 'CHR_ROM', data: TILE_MIXED },
        { label: 'tiledata', length: 32 },
      ],
    });

    expect(Array.from(r.memory.CHR_ROM)).toEqual(TILE_MIXED);
  });
});

// ─── ConvertROMTile2 ────────────────────────────────────────────────────────

describe('ConvertROMTile2', () => {
  for (const [name, tile] of Object.entries(SAMPLE_TILES)) {
    test(`tile "${name}" matches the JS reference model (full 128-byte layout)`, async () => {
      const expected = Array.from(convertRomTile2(tile, 0));

      const r = await jsr('ConvertROMTile2', {
        A: 'dest',
        X: 0,
        mx: 0,
        allocMemory: [
          { label: 'CHR_ROM', data: tile },
          { label: 'dest', length: 128 },
        ],
      });

      expect(Array.from(r.memory.dest)).toEqual(expected);
    });
  }

  test('bitmap region [0..31] and mask region [32..63] both come out correctly for TILE_MIXED', async () => {
    const expected = convertRomTile2(TILE_MIXED, 0);

    const r = await jsr('ConvertROMTile2', {
      A: 'dest',
      X: 0,
      mx: 0,
      allocMemory: [
        { label: 'CHR_ROM', data: TILE_MIXED },
        { label: 'dest', length: 128 },
      ],
    });

    expect(Array.from(r.memory.dest).slice(0, 32)).toEqual(Array.from(expected).slice(0, 32));
    expect(Array.from(r.memory.dest).slice(32, 64)).toEqual(Array.from(expected).slice(32, 64));
  });

  test('mirrored bitmap/mask region [64..127] comes out correctly for TILE_MIXED', async () => {
    const expected = convertRomTile2(TILE_MIXED, 0);

    const r = await jsr('ConvertROMTile2', {
      A: 'dest',
      X: 0,
      mx: 0,
      allocMemory: [
        { label: 'CHR_ROM', data: TILE_MIXED },
        { label: 'dest', length: 128 },
      ],
    });

    expect(Array.from(r.memory.dest).slice(64, 128)).toEqual(Array.from(expected).slice(64, 128));
  });
});

// ─── FastROMMaskedTileToLookup ──────────────────────────────────────────────
//
// Sprite-tile conversion that writes straight into the tiledata bank (no
// TileBuff, no DBR dependency -- see INPROGRESS.md). Like FastROMTileToLookup,
// A = destination *offset within* tiledata (must be 32-byte aligned -- real
// callers always pass tileID*128) and X = CHR-ROM offset. Unlike
// FastROMTileToLookup, it produces the full 128-byte ConvertROMTile2 layout
// (bitmap/mask, normal + h-flipped) via the TILE_MASK/TILE_REVERSE tables,
// so it's checked against convertRomTile2() directly, the same ground truth
// ConvertROMTile2 itself is checked against above.
//
// The loop's termination check (`tya / and #$001F / bne`) only ever reaches
// zero if the *starting* Y (== the destination address the caller passed in
// A) is itself 32-byte aligned -- true for every real caller (tileID*128),
// but not guaranteed for a label the assembler places automatically after
// the generated harness code. So 'tiledata' is declared here (not via
// allocMemory) with an explicit `ds \,$00` page-boundary pad in front of it,
// and read back via captureMemory instead of the usual allocMemory
// auto-capture.
const TILEDATA_STUB = `
            ds    \\,$00
tiledata    ds    128
`;

describe('FastROMMaskedTileToLookup', () => {
  const TILES = { ...SAMPLE_TILES, staggered: TILE_STAGGERED };

  for (const [name, tile] of Object.entries(TILES)) {
    test(`tile "${name}" matches the JS reference model (full 128-byte layout)`, async () => {
      const expected = Array.from(convertRomTile2(tile, 0));

      const r = await jsrMasked('FastROMMaskedTileToLookup', {
        A: 'tiledata',
        X: 0,
        mx: 0,
        inline: [TILEDATA_STUB],
        allocMemory: [
          { label: 'CHR_ROM', data: tile },
        ],
        captureMemory: [
          { label: 'tiledata', length: 128 },
        ],
      });

      expect(Array.from(r.memory.tiledata)).toEqual(expected);
    });
  }

  test('honors a non-zero tile offset (X) into CHR_ROM', async () => {
    const chr = [...TILE_ZERO, ...TILE_STAGGERED]; // tile 1 starts at offset 16
    const expected = Array.from(convertRomTile2(chr, 16));

    const r = await jsrMasked('FastROMMaskedTileToLookup', {
      A: 'tiledata',
      X: 16,
      mx: 0,
      inline: [TILEDATA_STUB],
      allocMemory: [
        { label: 'CHR_ROM', data: chr },
      ],
      captureMemory: [
        { label: 'tiledata', length: 128 },
      ],
    });

    expect(Array.from(r.memory.tiledata)).toEqual(expected);
  });

  test('leaves CHR_ROM untouched (read-only source)', async () => {
    const r = await jsrMasked('FastROMMaskedTileToLookup', {
      A: 'tiledata',
      X: 0,
      mx: 0,
      inline: [TILEDATA_STUB],
      allocMemory: [
        { label: 'CHR_ROM', data: TILE_MIXED },
      ],
      captureMemory: [
        { label: 'tiledata', length: 128 },
      ],
    });

    expect(Array.from(r.memory.CHR_ROM)).toEqual(TILE_MIXED);
  });
});

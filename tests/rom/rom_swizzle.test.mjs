/**
 * tests/rom/rom_swizzle.test.mjs
 *
 * Tests for _fillSwizzleTable, _fillSetup, and _fillSwizzleBlock in
 * src/rom/rom_palette.s.
 *
 * Tile data format: 16-bit word `0000000w wxxyyzz0`
 *   The word is used directly as a byte offset into the 512-byte table.
 *   LSB is always 0; pixel bits occupy bits[8:1].
 *
 *   Bit fields (within the 16-bit tile word):
 *     ww = bits[8:7]  → W pixel color (0–3)
 *     xx = bits[6:5]  → X pixel color
 *     yy = bits[4:3]  → Y pixel color
 *     zz = bits[2:1]  → Z pixel color
 *
 *   Output nibbles of the looked-up 16-bit word:
 *     pal_y[yy] → nibble 3 (bits 15-12)
 *     pal_z[zz] → nibble 2 (bits 11-8)
 *     pal_w[ww] → nibble 1 (bits  7-4)
 *     pal_x[xx] → nibble 0 (bits  3-0)
 *
 * _fillSwizzleTable calling convention:
 *   X (16-bit) = palIdx0 (low byte) | palIdx1 (high byte)
 *   Y (16-bit) = palIdx2 (low byte) | palIdx3 (high byte)
 *   Where palIdx0..3 are IIgs palette indices for NES colors 0..3.
 *
 * Results are written to the fixed _swizzleTbl label in the source.
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT    = process.env.SRC_ROOT;
const ROM_PALETTE = join(SRC_ROOT, 'rom/rom_palette.s');

// Reference table for palette [0, 2, 3, 4]: NES colors 0→0, 1→2, 2→3, 3→4.
// Low byte  of each word = nibble1(w) | nibble0(x)
// High byte of each word = nibble3(y) | nibble2(z)
const SAMPLE_SWIZZLE_TABLE_WORDS = [
   // z:0    z:1    z:2    z:3     z:0    z:1    z:2    z:3     z:0    z:1    z:2    z:3     z:0    z:1    z:2    z:3
   // y:0                          y:1                          y:2                          y:3
   0x0000,0x0200,0x0300,0x0400, 0x2000,0x2200,0x2300,0x2400, 0x3000,0x3200,0x3300,0x3400, 0x4000,0x4200,0x4300,0x4400,  // x:0  w:0
   0x0002,0x0202,0x0302,0x0402, 0x2002,0x2202,0x2302,0x2402, 0x3002,0x3202,0x3302,0x3402, 0x4002,0x4202,0x4302,0x4402,  // x:1
   0x0003,0x0203,0x0303,0x0403, 0x2003,0x2203,0x2303,0x2403, 0x3003,0x3203,0x3303,0x3403, 0x4003,0x4203,0x4303,0x4403,  // x:2
   0x0004,0x0204,0x0304,0x0404, 0x2004,0x2204,0x2304,0x2404, 0x3004,0x3204,0x3304,0x3404, 0x4004,0x4204,0x4304,0x4404,  // x:3

   0x0020,0x0220,0x0320,0x0420, 0x2020,0x2220,0x2320,0x2420, 0x3020,0x3220,0x3320,0x3420, 0x4020,0x4220,0x4320,0x4420,  // x:0  w:1
   0x0022,0x0222,0x0322,0x0422, 0x2022,0x2222,0x2322,0x2422, 0x3022,0x3222,0x3322,0x3422, 0x4022,0x4222,0x4322,0x4422,  // x:1
   0x0023,0x0223,0x0323,0x0423, 0x2023,0x2223,0x2323,0x2423, 0x3023,0x3223,0x3323,0x3423, 0x4023,0x4223,0x4323,0x4423,  // x:2
   0x0024,0x0224,0x0324,0x0424, 0x2024,0x2224,0x2324,0x2424, 0x3024,0x3224,0x3324,0x3424, 0x4024,0x4224,0x4324,0x4424,  // x:3

   0x0030,0x0230,0x0330,0x0430, 0x2030,0x2230,0x2330,0x2430, 0x3030,0x3230,0x3330,0x3430, 0x4030,0x4230,0x4330,0x4430,  // x:0  w:2
   0x0032,0x0232,0x0332,0x0432, 0x2032,0x2232,0x2332,0x2432, 0x3032,0x3232,0x3332,0x3432, 0x4032,0x4232,0x4332,0x4432,  // x:1
   0x0033,0x0233,0x0333,0x0433, 0x2033,0x2233,0x2333,0x2433, 0x3033,0x3233,0x3333,0x3433, 0x4033,0x4233,0x4333,0x4433,  // x:2
   0x0034,0x0234,0x0334,0x0434, 0x2034,0x2234,0x2334,0x2434, 0x3034,0x3234,0x3334,0x3434, 0x4034,0x4234,0x4334,0x4434,  // x:3

   0x0040,0x0240,0x0340,0x0440, 0x2040,0x2240,0x2340,0x2440, 0x3040,0x3240,0x3340,0x3440, 0x4040,0x4240,0x4340,0x4440,  // x:0  w:3
   0x0042,0x0242,0x0342,0x0442, 0x2042,0x2242,0x2342,0x2442, 0x3042,0x3242,0x3342,0x3442, 0x4042,0x4242,0x4342,0x4442,  // x:1
   0x0043,0x0243,0x0343,0x0443, 0x2043,0x2243,0x2343,0x2443, 0x3043,0x3243,0x3343,0x3443, 0x4043,0x4243,0x4343,0x4443,  // x:2
   0x0044,0x0244,0x0344,0x0444, 0x2044,0x2244,0x2344,0x2444, 0x3044,0x3244,0x3344,0x3444, 0x4044,0x4244,0x4344,0x4444   // x:3
];

const STUBS = `\
FIRST_OPEN_INDEX equ 1
bg0_changed ds    2
bg1_changed ds    2
nes_palette
bg0_palette ds    8
bg1_palette ds    8
bg2_palette ds    8
bg3_palette ds    8
sp0_palette ds    8
sp1_palette ds    8
sp2_palette ds    8
sp3_palette ds    8
current     dw    0,-1,-1,-1
NESPalIndices
BG0_PAL_IDX dw    2, 4, 6
BG1_PAL_IDX dw   10,12,14
BG2_PAL_IDX dw   18,20,22
BG3_PAL_IDX dw   26,28,30
SP0_PAL_IDX dw   34,36,38
SP1_PAL_IDX dw   42,44,46
SP2_PAL_IDX dw   50,52,54
SP3_PAL_IDX dw   58,60,62
ReverseMap  ds   128
tmp0        ds   12
`;

// ─── helpers ─────────────────────────────────────────────────────────────────

// Extract the four 2-bit pixel color indices from a tile word `0000000w wxxyyzz0`.
function pixelsFromTileWord(tw) {
  return {
    ww: (tw >> 7) & 3,
    xx: (tw >> 5) & 3,
    yy: (tw >> 3) & 3,
    zz: (tw >> 1) & 3,
  };
}

// Compute the expected 16-bit output for a tile word under a given colorMap.
// colorMap[i] = IIgs palette index for NES color i (0–3).
function expectedOutput(tileWord, colorMap) {
  const { ww, xx, yy, zz } = pixelsFromTileWord(tileWord);
  return ((colorMap[yy] << 12) |
          (colorMap[zz] <<  8) |
          (colorMap[ww] <<  4) |
           colorMap[xx]       ) & 0xFFFF;
}

// Unpack the A-register palette encoding: bits[3:0]=color0, [7:4]=color1, etc.
function unpackColorMap(aVal) {
  return [
    (aVal      ) & 0xF,
    (aVal >>  4) & 0xF,
    (aVal >>  8) & 0xF,
    (aVal >> 12) & 0xF,
  ];
}

// ─── shared cpu65816 factory ──────────────────────────────────────────────────

const { sequence } = cpu65816({
  includes:  [ROM_PALETTE],
  assembler: 'merlin32',
  inline: [
    { src: STUBS, placement: 'after' },
  ],
});

// ─── _fillSwizzleTable helper ─────────────────────────────────────────────────
//
// Calls _fillSwizzleTable with the given four IIgs palette indices, then reads
// back the 512-byte result from _swizzleTbl as 256 little-endian words.
//
// Calling convention:
//   X = colorMap[0] | (colorMap[1] << 8)
//   Y = colorMap[2] | (colorMap[3] << 8)

function fillSwizzleTable(seq, colorMap) {
  const [p0, p1, p2, p3] = colorMap;
  const xVal = (p0 & 0xF) | ((p1 & 0xF) << 8);
  const yVal = (p2 & 0xF) | ((p3 & 0xF) << 8);

  return seq
    .inline(`\
      ldx  #${xVal}
      ldy  #${yVal}
      `, { mx: 0 })
    .jsr('_fillSwizzleTable');
}

// ─── _fillSwizzleTable — palette [0, 2, 3, 4] ────────────────────────────────

describe('_fillSwizzleTable — palette [0, 2, 3, 4]', () => {
  const COLOR_MAP = [0, 2, 3, 4];

  test('all 256 tile words match SAMPLE_SWIZZLE_TABLE_WORDS', async () => {

    const result = await sequence()
      .step(s => fillSwizzleTable(s, COLOR_MAP))
      .captureMemory({ label: '_swizzleTbl', count: 256, as: 'word' })
      .run();

    const buf = result.memory['_swizzleTbl'];

    expect(buf.length).toBe(256);
    for (let i = 0; i < 256; i++) {
      expect(buf[i], `word index ${i}`).toBe(SAMPLE_SWIZZLE_TABLE_WORDS[i]);
    }
  });
/*
// ─── _fillSwizzleTable — palette $F4C2 (0→2, 1→C, 2→4, 3→F) ─────────────────

describe('_fillSwizzleTable — palette $F4C2 (0→2, 1→C, 2→4, 3→F)', () => {
  const COLOR_MAP = unpackColorMap(0xF4C2);   // [2, 0xC, 4, 0xF]

  test('all 256 tile words produce correct output', async () => {
    const buf = await buildSwizzleTable(COLOR_MAP);
    for (let tw = 0x0000; tw <= 0x01FE; tw += 2) {
      const got  = buf.readUInt16LE(tw);
      const want = expectedOutput(tw, COLOR_MAP);
      expect(got, `tile word $${tw.toString(16).padStart(4,'0')}`).toBe(want);
    }
  });

  test('tile word $00F0 → $42CF', async () => {
    // ww=01→C nibble1, xx=11→F nibble0, yy=10→4 nibble3, zz=00→2 nibble2
    const buf = await buildSwizzleTable(COLOR_MAP);
    expect(buf.readUInt16LE(0x00F0)).toBe(0x42CF);
  });

  test('tile word $0000 (all color 0) → $2222', async () => {
    const buf = await buildSwizzleTable(COLOR_MAP);
    expect(buf.readUInt16LE(0x0000)).toBe(0x2222);
  });

  test('tile word $01FE (all color 3) → $FFFF', async () => {
    const buf = await buildSwizzleTable(COLOR_MAP);
    expect(buf.readUInt16LE(0x01FE)).toBe(0xFFFF);
  });
});

// ─── _fillSwizzleTable — identity palette [0, 1, 2, 3] ───────────────────────

describe('_fillSwizzleTable — identity palette [0, 1, 2, 3]', () => {
  const COLOR_MAP = [0, 1, 2, 3];

  test('all 256 tile words: nibble N contains N-bit pixel value', async () => {
    const buf = await buildSwizzleTable(COLOR_MAP);
    for (let tw = 0x0000; tw <= 0x01FE; tw += 2) {
      const got  = buf.readUInt16LE(tw);
      const want = expectedOutput(tw, COLOR_MAP);
      expect(got, `tile word $${tw.toString(16).padStart(4,'0')}`).toBe(want);
    }
  });

  test('tile word $01FE (all color 3) → $3333', async () => {
    const buf = await buildSwizzleTable(COLOR_MAP);
    expect(buf.readUInt16LE(0x01FE)).toBe(0x3333);
  });
  */
});

// ─── _fillSwizzleTable — repeated calls overwrite table correctly ──────────────

describe('_fillSwizzleTable — successive fills', () => {
  test('second call with different palette overwrites entire table', async () => {
    const COLOR_MAP_1 = unpackColorMap(0x4320); // [0x0, 0x2, 0x3, 0x4];
    const COLOR_MAP_2 = unpackColorMap(0xF4C2); // [0x2, 0xC, 0x4, 0xF]

    const r = await sequence()
      .step((seq) => fillSwizzleTable(seq, COLOR_MAP_1))
      .step((seq) => fillSwizzleTable(seq, COLOR_MAP_2))
      .captureMemory({ label: '_swizzleTbl', count: 256, as: 'word' })
      .run();

    const buf = Buffer.from(r.memory['_swizzleTbl'].flatMap(w => [w & 0xFF, (w >> 8) & 0xFF]));
    for (let tw = 0x0000; tw <= 0x01FE; tw += 2) {
      const got  = buf.readUInt16LE(tw);
      const want = expectedOutput(tw, COLOR_MAP_2);
      expect(got, `tile word $${tw.toString(16).padStart(4,'0')}`).toBe(want);
    }
  });
});

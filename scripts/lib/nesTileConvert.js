'use strict';

/**
 * nesTileConvert — JS port of the NES CHR-ROM tile conversion routines in
 * src/rom/rom_helpers.s (ROMTileToLookup, ROMTileToBitmap, ConvertROMTile2).
 *
 * This is a byte-for-byte mechanical transliteration of the 65816 code, not
 * an independent re-derivation of "what it means" -- each function below
 * mirrors the instruction sequence of its asm counterpart (same tables, same
 * intermediate buffer layout, same load/store order) so that its output is
 * provably identical to the hardware routine. It exists for two consumers:
 *
 *   1. tests/rom/rom_helpers.test.mjs, which runs the *actual* asm under
 *      iigs-unit and asserts the result matches this reference.
 *   2. scripts/convert-chr-rom.js, which uses it to precompute static
 *      conversion tables for a CHR-ROM without needing the IIgs runtime.
 *
 * A single NES tile is 16 bytes: 8 bytes of "plane 0" (low bit of each
 * pixel's 2-bit color) followed by 8 bytes of "plane 1" (high bit).
 */

// Look up the 2-bit indexes for the data words (see rom_helpers.s DLUT2)
const DLUT2 = [
  0x00, 0x01, 0x04, 0x05,
  0x02, 0x03, 0x06, 0x07,
  0x08, 0x09, 0x0C, 0x0D,
  0x0A, 0x0B, 0x0E, 0x0F,
];

// Shifted version of DLUT2 (see rom_helpers.s DLUT2_shft)
const DLUT2_SHFT = [
  0x00, 0x10, 0x40, 0x50,
  0x20, 0x30, 0x60, 0x70,
  0x80, 0x90, 0xC0, 0xD0,
  0xA0, 0xB0, 0xE0, 0xF0,
];

// Mask lookup (see rom_helpers.s MLUT4)
const MLUT4 = [
  0xFF, 0xF0, 0x0F, 0x00,
  0xF0, 0xF0, 0x00, 0x00,
  0x0F, 0x00, 0x0F, 0x00,
  0x00, 0x00, 0x00, 0x00,
];

function readWord(buf, off) {
  return buf[off] | (buf[off + 1] << 8);
}

function writeWord(buf, off, val) {
  buf[off] = val & 0xFF;
  buf[off + 1] = (val >> 8) & 0xFF;
}

// reverse2 — reverse the four 2-bit fields of a byte (rom_helpers.s reverse2)
function reverse2(v) {
  return (
    ((v & 0x03) << 6) |
    ((v & 0x0C) << 2) |
    ((v & 0x30) >> 2) |
    ((v & 0xC0) >> 6)
  ) & 0xFF;
}

// reverse4 — reverse the two nibbles of each byte in a 16-bit word
// (rom_helpers.s reverse4: xba; and #$0F0F; asl x4; ...; and #$F0F0; lsr x4; ora)
function reverse4(word) {
  const lo = word & 0xFF;
  const hi = (word >> 8) & 0xFF;
  const swapped = (lo << 8) | hi; // xba
  const tmp1 = ((swapped & 0x0F0F) << 4) & 0xFFFF;
  const hiNibbles = (swapped & 0xF0F0) >>> 4;
  return (hiNibbles | tmp1) & 0xFFFF;
}

/**
 * ROMTileToLookup — build the 32-byte lookup-index buffer for one tile.
 *
 * chr:        Uint8Array (or number[]) containing CHR-ROM data
 * tileOffset: byte offset of the tile's plane-0 data within chr
 *             (plane-1 data is read from tileOffset + 8)
 *
 * Returns a 32-entry Uint8Array of 4-bit lookup indices (0-15).
 */
function romTileToLookup(chr, tileOffset) {
  const out = new Uint8Array(32);
  let y = 0;
  for (let row = 0; row < 8; row++) {
    const lo = chr[tileOffset + row];
    const hi = chr[tileOffset + row + 8];
    for (let p = 0; p < 4; p++) {
      const shift = 6 - 2 * p;
      const lowP = (lo >> shift) & 3;
      const hiP = (hi >> shift) & 3;
      out[y++] = (hiP << 2) | lowP;
    }
  }
  return out;
}

/**
 * ROMTileToBitmap — background-tile conversion (rom_helpers.s ROMTileToBitmap).
 *
 * Returns a 32-byte Uint8Array: 16 little-endian words, each a pre-shifted
 * "0000000w wxxyyzz0"-style swizzle index for a pair of source pixels.
 */
function romTileToBitmap(chr, tileOffset) {
  const lookup = romTileToLookup(chr, tileOffset);
  const out = new Uint8Array(32);
  for (let y = 0; y < 32; y += 2) {
    const Lw = lookup[y];
    const Lx = lookup[y + 1];
    const combined = (DLUT2_SHFT[Lw] | DLUT2[Lx]) & 0xFF;
    const word = (combined << 1) & 0x1FF;
    out[y] = word & 0xFF;
    out[y + 1] = (word >> 8) & 0xFF;
  }
  return out;
}

/**
 * ConvertROMTile2 — sprite-tile conversion (rom_helpers.s ConvertROMTile2).
 *
 * Produces the full 128-byte TileBuff layout used for compiled sprites:
 *   [0..31]   bitmap, normal orientation      (pre-shifted, doubled in place)
 *   [32..63]  mask, normal orientation
 *   [64..95]  bitmap, horizontally + vertically mirrored variants
 *   [96..127] mask, horizontally + vertically mirrored variants
 *
 * Returns a 128-byte Uint8Array.
 */
function convertRomTile2(chr, tileOffset) {
  const lookup = romTileToLookup(chr, tileOffset);
  const buf = new Uint8Array(128);

  for (let y = 0; y < 32; y += 2) {
    const Lw = lookup[y];
    const Lx = lookup[y + 1];

    buf[32 + y] = MLUT4[Lw];
    const combined = ((DLUT2[Lw] << 4) | DLUT2[Lx]) & 0xFF;
    buf[y] = combined;
    buf[y + 1] = 0;
    buf[32 + y + 1] = MLUT4[Lx];
  }

  for (let x = 0; x < 32; x += 4) {
    const wordA = readWord(buf, x);
    const shiftedA = (reverse2(wordA & 0xFF) << 1) & 0xFFFF;
    writeWord(buf, 66 + x, shiftedA);
    writeWord(buf, x, (wordA << 1) & 0xFFFF);

    const wordB = readWord(buf, x + 2);
    const shiftedB = (reverse2(wordB & 0xFF) << 1) & 0xFFFF;
    writeWord(buf, 64 + x, shiftedB);
    writeWord(buf, x + 2, (wordB << 1) & 0xFFFF);

    const maskWordA = readWord(buf, 32 + x);
    writeWord(buf, 98 + x, reverse4(maskWordA));

    const maskWordB = readWord(buf, 34 + x);
    writeWord(buf, 96 + x, reverse4(maskWordB));
  }

  return buf;
}

module.exports = {
  DLUT2,
  DLUT2_SHFT,
  MLUT4,
  reverse2,
  reverse4,
  romTileToLookup,
  romTileToBitmap,
  convertRomTile2,
};

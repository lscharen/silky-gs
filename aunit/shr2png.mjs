/**
 * aunit/shr2png.mjs  -  Apple IIgs SHR screen → PNG converter
 *
 * The IIgs Super Hi-Res screen occupies 32768 bytes ($8000):
 *   $0000..$7DFF  (32256 bytes)  pixel data  — 200 scanlines × 160 bytes
 *   $7E00..$7EFF  (256 bytes)    SCBs         — one byte per scanline
 *   $7F00..$7FFF  (512 bytes)    palettes     — 16 palettes × 32 bytes each
 *
 * Each palette entry is a 16-bit IIgs color word (little-endian):
 *   bits 11:8  = blue  (0–15)
 *   bits  7:4  = green (0–15)
 *   bits  3:0  = red   (0–15)
 *   bit    15  = unused (IIgs ignores it; Silky-GS sometimes uses for swizzle)
 *
 * Each pixel byte encodes two 4-bit pixels (high nibble = left pixel).
 *
 * SCB (Scanline Control Byte) bits:
 *   bits 3:0 = palette index (0–15)
 *   bit  5   = 1→ 640-mode (ignore pixels), 0→ 320-mode (standard)
 *   We only support 320-mode here.
 *
 * Usage:
 *   import { shrBufToPng, shrFileToPng } from './aunit/shr2png.mjs';
 *
 *   // from a 32768-byte Buffer captured by AUnit_AppendMem:
 *   const png = await shrBufToPng(memRecord.data);
 *   await writeFile('screen.png', png);
 *
 *   // or directly from a dump file:
 *   await shrFileToPng('screen.bin', 'screen.png');
 */

import { readFile, writeFile } from 'node:fs/promises';
import { PNG } from 'pngjs';

const SCANLINES     = 200;
const BYTES_PER_ROW = 160;
const SCB_OFFSET    = 0x7E00;
const PAL_OFFSET    = 0x7F00;
const PALETTE_COUNT = 16;
const COLORS_PER_PAL = 16;

/**
 * Convert a 32768-byte SHR buffer to a PNG Buffer.
 * @param {Buffer} shrBuf  32768-byte SHR memory dump
 * @returns {Promise<Buffer>} PNG file contents
 */
export function shrBufToPng(shrBuf) {
  if (shrBuf.length < 0x8000) {
    throw new RangeError(`SHR buffer must be at least 32768 bytes, got ${shrBuf.length}`);
  }

  const width  = 320;
  const height = SCANLINES;
  const png    = new PNG({ width, height });

  // parse all 16 palettes into RGBA lookup tables
  // palettes[p][c] = { r, g, b } each 0–255
  const palettes = [];
  for (let p = 0; p < PALETTE_COUNT; p++) {
    const pal = [];
    for (let c = 0; c < COLORS_PER_PAL; c++) {
      const off  = PAL_OFFSET + p * 32 + c * 2;
      const word = shrBuf.readUInt16LE(off);
      // IIgs color: bits 11:8=blue 7:4=green 3:0=red (4-bit each)
      const r4   = (word >> 0) & 0xF;
      const g4   = (word >> 4) & 0xF;
      const b4   = (word >> 8) & 0xF;
      // Expand 4-bit to 8-bit by replicating the nibble: val * 17
      pal.push({ r: r4 * 17, g: g4 * 17, b: b4 * 17 });
    }
    palettes.push(pal);
  }

  for (let scanline = 0; scanline < SCANLINES; scanline++) {
    const scb     = shrBuf.readUInt8(SCB_OFFSET + scanline);
    const palIdx  = scb & 0x0F;
    const palette = palettes[palIdx];

    const rowOffset = scanline * BYTES_PER_ROW;

    for (let byteIdx = 0; byteIdx < BYTES_PER_ROW; byteIdx++) {
      const byte   = shrBuf.readUInt8(rowOffset + byteIdx);
      const left   = (byte >> 4) & 0xF;   // high nibble = left pixel
      const right  = (byte >> 0) & 0xF;   // low nibble  = right pixel

      for (let pix = 0; pix < 2; pix++) {
        const colorIdx = pix === 0 ? left : right;
        const { r, g, b } = palette[colorIdx];
        const x = byteIdx * 2 + pix;
        const i = (scanline * width + x) * 4;
        png.data[i + 0] = r;
        png.data[i + 1] = g;
        png.data[i + 2] = b;
        png.data[i + 3] = 255;
      }
    }
  }

  return new Promise((res, rej) => {
    const chunks = [];
    const stream = png.pack();
    stream.on('data', c => chunks.push(c));
    stream.on('end',  () => res(Buffer.concat(chunks)));
    stream.on('error', rej);
  });
}

/**
 * Read a SHR dump file, convert to PNG, write output file.
 * @param {string} inputPath   path to 32768-byte binary dump
 * @param {string} outputPath  path to write .png
 */
export async function shrFileToPng(inputPath, outputPath) {
  const buf = await readFile(inputPath);
  const png = await shrBufToPng(buf);
  await writeFile(outputPath, png);
}

/**
 * Extract the SHR palette as an array of 16 hex color strings.
 * Useful for assertions in tests.
 * @param {Buffer} shrBuf
 * @param {number} paletteIndex  0–15
 * @returns {string[]} 16 strings like '#RRGGBB'
 */
export function extractPalette(shrBuf, paletteIndex = 0) {
  const colors = [];
  for (let c = 0; c < COLORS_PER_PAL; c++) {
    const off  = PAL_OFFSET + paletteIndex * 32 + c * 2;
    const word = shrBuf.readUInt16LE(off);
    const r    = ((word >> 0) & 0xF) * 17;
    const g    = ((word >> 4) & 0xF) * 17;
    const b    = ((word >> 8) & 0xF) * 17;
    colors.push(`#${r.toString(16).padStart(2,'0')}${g.toString(16).padStart(2,'0')}${b.toString(16).padStart(2,'0')}`);
  }
  return colors;
}

#!/usr/bin/env node
'use strict';

/**
 * verify.js -- check the assembled Tetris ROM against the original PRG-ROM
 *
 *   node tools/verify.js
 *
 * Reads the ROM segment (TGROM) out of the load file (TetrisGS) and compares its $8000-$FFFF with
 * prg.bin, the original PRG-ROM tools/convert.js rebuilt from the disassembly.  Every byte must be the
 * original's, except in the ranges the converter changed (tools/shims.json: the register and abs,Y
 * shims and the hand patches).  A shim is a JSR into the support area, so its first byte must be $20
 * (or the patch's own code).  Run by build.js after every build.
 */

const fs = require('fs');
const path = require('path');

const GAME_DIR = path.resolve(__dirname, '..');

function segmentName(b, off) {
  const lablen = b[off + 13];
  const p = off + b.readUInt16LE(off + 40) + 10;
  return lablen === 0 ? b.slice(p + 1, p + 1 + b[p]).toString('latin1') : b.slice(p, p + lablen).toString('latin1').trim();
}

/** The data of a segment of an OMF load file (its LCONST and DS records) */
function segmentData(file, name) {
  const b = fs.readFileSync(file);
  for (let off = 0; off < b.length;) {
    const bytecnt = b.readUInt32LE(off);
    if (segmentName(b, off) === name) {
      const parts = [];
      for (let r = off + b.readUInt16LE(off + 42); ;) {
        if (b[r] === 0xF2) {
          const len = b.readUInt32LE(r + 1);
          parts.push(b.slice(r + 5, r + 5 + len));
          r += 5 + len;
        } else if (b[r] === 0xF1) {
          parts.push(Buffer.alloc(b.readUInt32LE(r + 1)));
          r += 5;
        } else break;
      }
      const data = Buffer.concat(parts);
      const length = b.readUInt32LE(off + 8);                 // the rest is reserved space (zeros)
      return Buffer.concat([data, Buffer.alloc(Math.max(0, length - data.length))]);
    }
    off += bytecnt;
  }
  throw new Error(`${file}: no segment ${name}`);
}

function verifyRom(gameDir = GAME_DIR) {
  const rom = segmentData(path.join(gameDir, 'TetrisGS'), 'TGROM');
  const prg = fs.readFileSync(path.join(gameDir, 'prg.bin'));
  const shims = JSON.parse(fs.readFileSync(path.join(gameDir, 'tools', 'shims.json'), 'utf8'));
  if (rom.length < 0x10000) {
    console.error(`verify: the ROM segment is $${rom.length.toString(16)} bytes, not $10000`);
    return false;
  }

  const changed = new Uint8Array(0x8000);
  for (const s of shims) {
    const a = parseInt(s.addr.slice(1), 16) - 0x8000;
    for (let k = 0; k < s.len; k++) changed[a + k] = 1;
  }

  const bad = [];
  for (let a = 0; a < 0x8000; a++) {
    if (!changed[a] && rom[0x8000 + a] !== prg[a]) bad.push(a + 0x8000);
  }
  const shimErrors = shims.filter((s) => s.len === 3 && /-> jsr/.test(s.what) && rom[parseInt(s.addr.slice(1), 16)] !== 0x20);

  if (bad.length || shimErrors.length) {
    for (const a of bad.slice(0, 20)) {
      console.error(`verify: $${a.toString(16).toUpperCase()}: $${rom[a].toString(16)}, the original has $${prg[a - 0x8000].toString(16)}`);
    }
    if (bad.length > 20) console.error(`verify: ... ${bad.length} bytes differ`);
    for (const s of shimErrors) console.error(`verify: ${s.addr}: not a JSR (${s.what})`);
    return false;
  }
  const n = changed.reduce((t, v) => t + v, 0);
  console.log(`verify: the ROM matches the original PRG-ROM except the ${shims.length} shims and patches (${n} bytes)`);
  return true;
}

module.exports = { verifyRom };

if (require.main === module) process.exit(verifyRom() ? 0 : 1);

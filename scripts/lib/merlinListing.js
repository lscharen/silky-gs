'use strict';

/**
 * merlinListing.js — read Merlin32 link files and the listings ("_Output.txt") it writes for them.
 *
 * Merlin32 writes one listing per segment, named <DSK>_S<NN>_<...>Output.txt, NN being the segment's
 * position in the link file (1-based, hex, counted over the whole link file).  Each listing line is
 * a table row:
 *
 *   Line | # File Line | Line Type | MX | Reloc | Size | Address : Object Code | Source Code
 *
 * Reloc holds the relocation: "2" / "3" (a 16 / 24-bit address in this segment), "E 2" / "E 3" (an
 * address in another segment, imported with EXT), with ">>16" etc. when only a shifted part is used.
 */

const fs = require('fs');
const path = require('path');

/**
 * The segments of a link file, in order: [{ index, name, asm, dsk }].
 */
function parseLinkFile(linkPath) {
  const segs = [];
  let dsk = null;
  let cur = null;
  for (const raw of fs.readFileSync(linkPath, 'utf8').split(/\r?\n/)) {
    const line = raw.replace(/;.*$/, '');
    const m = line.match(/^\s+(\w+)\s+(\S+)/);
    if (!m) continue;
    const op = m[1].toUpperCase();
    if (op === 'DSK') dsk = m[2];
    else if (op === 'ASM') { cur = { index: segs.length + 1, name: null, asm: m[2], dsk }; segs.push(cur); }
    else if (op === 'SNA' && cur) cur.name = m[2];
  }
  return segs;
}

/**
 * The listing file of every segment of a link file: [{ index, name, asm, file }] (file is null when
 * the listing is missing).
 */
function listingFiles(gameDir, linkFile) {
  const linkPath = path.join(gameDir, linkFile);
  const dir = path.dirname(linkPath);
  const names = fs.readdirSync(dir);
  return parseLinkFile(linkPath).map((s) => {
    const nn = s.index.toString(16).toUpperCase().padStart(2, '0');
    const prefix = `${s.dsk}_S${nn}_`;
    const hit = names.find((n) => n.startsWith(prefix) && n.endsWith('Output.txt'));
    return { ...s, file: hit ? path.join(dir, hit) : null };
  });
}

/**
 * The rows of a listing: [{ file, path, line, type, mx, reloc, size, addr, bytes, label, op, operand, src }].
 * file is the source file's base name, path its full path; bytes are the object code bytes shown (at most 4).
 */
function parseListing(listingPath) {
  const rows = [];
  for (const l of fs.readFileSync(listingPath, 'latin1').split(/\r?\n/)) {
    const f = l.split('|');
    if (f.length < 8) continue;
    const m = f[1].match(/^\s*\d+\s+(\S+)\s+(\d+)\s*$/);
    if (!m) continue;
    const src = f.slice(7).join('|');
    const obj = f[6];
    const colon = obj.indexOf(':');
    const bytes = colon < 0 ? [] : obj.slice(colon + 1).trim().split(/\s+/).filter(Boolean).map((b) => parseInt(b, 16));
    // The source column starts with a space; a label starts right after it.
    const toks = src.replace(/\s;.*$/, '').trim().split(/\s+/).filter(Boolean);
    const hasLabel = src.length > 1 && src[1] !== ' ' && src[1] !== ';';
    const label = hasLabel ? toks.shift() : '';
    rows.push({
      file: path.basename(m[1]),
      path: path.resolve(path.dirname(listingPath), m[1]),
      line: +m[2],
      type: f[2].trim(),
      mx: f[3].trim(),
      reloc: f[4].trim(),
      size: parseInt(f[5], 10) || 0,
      addr: obj.trim().slice(0, 7),
      bytes,
      label,
      op: (toks[0] || '').toLowerCase(),
      operand: toks[1] || '',
      src: src.trim(),
    });
  }
  return rows;
}

module.exports = { parseLinkFile, listingFiles, parseListing };

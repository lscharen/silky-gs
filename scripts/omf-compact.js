#!/usr/bin/env node
'use strict';

/**
 * omf-compact -- Take the zeros out of an OMF load file that Merlin32 linked.
 *
 * Merlin32 writes every byte of a segment, ds included, as one LCONST record, and it has no way to set a
 * segment's reserved space (RESSPACE) or alignment (its ALI BANK writes an invalid ALIGN of 2).  This
 * rewrites each segment's LCONST:
 *
 *   - a run of at least MIN_RUN zeros inside the data becomes a DS record (the loader fills it with zeros)
 *   - the zeros at the end become RESSPACE (no record at all)
 *   - the segments named with --bank are extended to a whole 64KB bank: LENGTH = $10000 (the rest is
 *     RESSPACE) and ALIGN = $10000, so their source does not need a trailing ds and the loader gives them
 *     a bank of their own, starting at $0000
 *
 * The relocation records are kept as they are (their offsets are within the segment, not the file).
 *
 * ExpressLoad can't load any of this: its segment table has no RESSPACE and it reads each segment's data
 * as one block, so a link file with XPL is refused.
 *
 *   node scripts/omf-compact.js <file> [--bank SEG,SEG] [--out <file>]
 */

const fs = require('fs');

const MIN_RUN = 32;                  // A DS record and the LCONST header after it cost 10 bytes

function segmentName(b, off) {
    const lablen = b[off + 13];
    const p = off + b.readUInt16LE(off + 40) + 10;
    return lablen === 0 ? b.slice(p + 1, p + 1 + b[p]).toString('latin1') : b.slice(p, p + lablen).toString('latin1').trim();
}

function lconst(data) {
    const h = Buffer.alloc(5);
    h[0] = 0xF2;
    h.writeUInt32LE(data.length, 1);
    return [h, data];
}

function ds(n) {
    const h = Buffer.alloc(5);
    h[0] = 0xF1;
    h.writeUInt32LE(n, 1);
    return [h];
}

function compactSegment(b, off, toBank) {
    const name = segmentName(b, off);
    const bytecnt = b.readUInt32LE(off);
    const dispdata = b.readUInt16LE(off + 42);
    const r = off + dispdata;
    if (b[r] !== 0xF2) return { name, seg: b.slice(off, off + bytecnt), note: 'no LCONST, kept' };

    const len = b.readUInt32LE(r + 1);
    const data = b.slice(r + 5, r + 5 + len);
    const rest = b.slice(r + 5 + len, off + bytecnt);              // relocation records and END

    let end = len;                                                  // trailing zeros -> RESSPACE
    while (end > 0 && data[end - 1] === 0) end--;

    const parts = [];
    let start = 0, i = 0;
    while (i < end) {
        if (data[i] !== 0) { i++; continue; }
        let j = i;
        while (j < end && data[j] === 0) j++;
        if (j - i >= MIN_RUN) {
            if (i > start) parts.push(...lconst(data.slice(start, i)));
            parts.push(...ds(j - i));
            start = j;
        }
        i = j;
    }
    if (end > start) parts.push(...lconst(data.slice(start, end)));

    const head = Buffer.from(b.slice(off, r));
    let resspace = head.readUInt32LE(4) + (len - end);
    let length = head.readUInt32LE(8);
    if (toBank) {
        if (length > 0x10000) throw new Error(`${name}: ${length} bytes is more than a bank`);
        resspace += 0x10000 - length;
        length = 0x10000;
        head.writeUInt32LE(0x10000, 28);                            // ALIGN
    }
    head.writeUInt32LE(resspace, 4);
    head.writeUInt32LE(length, 8);
    const seg = Buffer.concat([head, ...parts, rest]);
    seg.writeUInt32LE(seg.length, 0);                               // BYTECNT
    return { name, seg, note: `${bytecnt} -> ${seg.length} bytes, RESSPACE $${resspace.toString(16)}, LENGTH $${length.toString(16)}` };
}

function compactFile(file, outFile, bankSegments) {
    const b = fs.readFileSync(file);
    const banks = new Set(bankSegments);
    const segs = [];
    for (let off = 0; off < b.length;) {
        const bytecnt = b.readUInt32LE(off);
        if (bytecnt === 0) throw new Error(`${file}: a segment with a BYTECNT of 0 at ${off}`);
        if (segmentName(b, off) === '~ExpressLoad') {
            throw new Error(`${file}: has an ~ExpressLoad segment (XPL); ExpressLoad can't load reserved space, remove XPL from the link file`);
        }
        const s = compactSegment(b, off, banks.has(segmentName(b, off)));
        banks.delete(s.name);
        segs.push(s);
        off += bytecnt;
    }
    if (banks.size) throw new Error(`${file}: no segment named ${[...banks].join(', ')}`);
    const out = Buffer.concat(segs.map(s => s.seg));
    fs.writeFileSync(outFile, out);
    for (const s of segs) console.log(`  ${s.name.padEnd(12)} ${s.note}`);
    console.log(`  ${file}: ${b.length} -> ${out.length} bytes`);
}

module.exports = { compactFile };

if (require.main === module) {
    const argv = process.argv.slice(2);
    let file = null, out = null, bank = [];
    for (let i = 0; i < argv.length; i++) {
        if (argv[i] === '--bank') bank = argv[++i].split(',');
        else if (argv[i] === '--out') out = argv[++i];
        else file = argv[i];
    }
    if (!file) {
        console.error('usage: omf-compact.js <file> [--bank SEG,SEG] [--out <file>]');
        process.exit(1);
    }
    compactFile(file, out || file, bank);
}

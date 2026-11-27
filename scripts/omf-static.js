#!/usr/bin/env node
'use strict';

/**
 * omf-static -- Link an OMF load file to fixed banks, for the ProDOS 8 self-booting disks.
 *
 * GS/OS's loader puts each segment of a game wherever the Memory Manager has room and patches the
 * relocation records.  This does the same once, at build time: every segment gets a whole bank of its
 * own, starting at $0000 (so the bank-aligned segments, and the page-aligned tables at the start of a
 * segment, are where they need to be), the relocation records are applied, and the result is written as
 * one flat image that the P8 loader (scripts/p8boot/Loader.s) reads straight into memory.
 *
 * Image layout (all little-endian):
 *
 *   $00  'SGS8'            magic
 *   $04  1                 version
 *   $05  N                 number of segments
 *   $06  entry offset (2)  in the first segment (its ENTRY)
 *   $08  entry bank (1)    the first segment's bank
 *   $10  N entries of 8 bytes: bank (1), 0 (1), data length (4: the segment's bytes up to its last
 *        non-zero byte), 0 (2)
 *   $100 the segments' data, in order.  The loader zeroes each bank first, so the rest of a segment (its
 *        trailing zeros and RESSPACE) is not stored.
 *
 * Record types handled: LCONST ($F2), DS ($F1), CONST ($01-$DF), cRELOC ($F5), cINTERSEG ($F6), RELOC ($E2),
 * INTERSEG ($E3) and SUPER ($F7: RELOC2, RELOC3, INTERSEG1, INTERSEG13-36).  Anything else is an error.
 *
 *   node scripts/omf-static.js <OMF file> --out <image> [--first-bank 2] [--map]
 */

const fs = require('fs');

function parseSegments(b) {
    const segs = [];
    for (let off = 0; off < b.length;) {
        const bytecnt = b.readUInt32LE(off);
        if (bytecnt === 0) break;
        const lablen = b[off + 13];
        const numlen = b[off + 14];
        if (numlen !== 4) throw new Error(`segment at ${off}: NUMLEN ${numlen} (only 4 is supported)`);
        const dispname = b.readUInt16LE(off + 40);
        const dispdata = b.readUInt16LE(off + 42);
        const nameOff = off + dispname + 10;                         // (after LOADNAME)
        const name = lablen
            ? b.slice(nameOff, nameOff + lablen).toString('latin1').trim()
            : b.slice(nameOff + 1, nameOff + 1 + b[nameOff]).toString('latin1');
        segs.push({
            off, bytecnt, name,
            resspace: b.readUInt32LE(off + 4),
            length: b.readUInt32LE(off + 8),
            kind: b.readUInt16LE(off + 20),
            align: b.readUInt32LE(off + 28),
            segnum: b.readUInt16LE(off + 34),
            entry: b.readUInt32LE(off + 36),
            body: off + dispdata,
            end: off + bytecnt,
        });
        off += bytecnt;
    }
    return segs;
}

// Write `value` (shifted) into `mem` at `at`, `size` bytes, little-endian
function patch(mem, at, size, value, shift) {
    if (shift >= 128) shift -= 256;                                  // (signed)
    let v = shift >= 0 ? value * Math.pow(2, shift) : Math.floor(value / Math.pow(2, -shift));
    for (let i = 0; i < size; i++) {
        if (at + i >= mem.length) throw new Error(`patch at $${(at + i).toString(16)} is outside the segment`);
        mem[at + i] = v & 0xFF;
        v = Math.floor(v / 256);
    }
}

function readLE(mem, at, size) {
    let v = 0;
    for (let i = size - 1; i >= 0; i--) v = v * 256 + mem[at + i];
    return v;
}

function linkSegment(b, seg, bases) {
    const base = bases.get(seg.segnum);
    const mem = Buffer.alloc(seg.length);
    let pc = 0;
    let r = seg.body;
    const relocs = { sites: 0 };

    // The SUPER patch sites: a list of page counts / offsets (see the GS/OS Reference, Appendix F)
    function superSites(start, len, fn) {
        let page = 0;
        let p = start;
        const end = start + len;
        while (p < end) {
            const c = b[p++];
            if (c & 0x80) { page += c & 0x7F; continue; }
            for (let i = 0; i <= c; i++) fn(page * 256 + b[p++]);
            page++;
        }
    }

    for (;;) {
        const op = b[r];
        if (op === 0x00) break;                                      // END
        if (op <= 0xDF) {                                            // CONST
            b.copy(mem, pc, r + 1, r + 1 + op); pc += op; r += 1 + op;
        } else if (op === 0xF2) {                                    // LCONST
            const n = b.readUInt32LE(r + 1);
            b.copy(mem, pc, r + 5, r + 5 + n); pc += n; r += 5 + n;
        } else if (op === 0xF1) {                                    // DS
            pc += b.readUInt32LE(r + 1); r += 5;
        } else if (op === 0xF5) {                                    // cRELOC
            const size = b[r + 1], shift = b[r + 2], at = b.readUInt16LE(r + 3), value = b.readUInt16LE(r + 5);
            patch(mem, at, size, base + value, shift); relocs.sites++; r += 7;
        } else if (op === 0xF6) {                                    // cINTERSEG
            const size = b[r + 1], shift = b[r + 2], at = b.readUInt16LE(r + 3), sn = b[r + 5], value = b.readUInt16LE(r + 6);
            patch(mem, at, size, target(sn) + value, shift); relocs.sites++; r += 8;
        } else if (op === 0xE2) {                                    // RELOC
            const size = b[r + 1], shift = b[r + 2], at = b.readUInt32LE(r + 3), value = b.readUInt32LE(r + 7);
            patch(mem, at, size, base + value, shift); relocs.sites++; r += 11;
        } else if (op === 0xE3) {                                    // INTERSEG
            const size = b[r + 1], shift = b[r + 2], at = b.readUInt32LE(r + 3);
            const file = b.readUInt16LE(r + 7), sn = b.readUInt16LE(r + 9), value = b.readUInt32LE(r + 11);
            if (file !== 1) throw new Error(`${seg.name}: INTERSEG to file ${file}`);
            patch(mem, at, size, target(sn) + value, shift); relocs.sites++; r += 15;
        } else if (op === 0xF7) {                                    // SUPER
            const len = b.readUInt32LE(r + 1);
            const type = b[r + 5];
            const start = r + 6, n = len - 1;
            if (type === 0) {                                        // RELOC2: 2 bytes, this segment
                superSites(start, n, at => { patch(mem, at, 2, base + readLE(mem, at, 2), 0); relocs.sites++; });
            } else if (type === 1) {                                 // RELOC3: 3 bytes, this segment
                superSites(start, n, at => { patch(mem, at, 3, base + readLE(mem, at, 3), 0); relocs.sites++; });
            } else if (type === 2) {                                 // INTERSEG1: 3 bytes, segment in the third byte
                superSites(start, n, at => {
                    const sn = mem[at + 2];
                    patch(mem, at, 3, target(sn) + readLE(mem, at, 2), 0); relocs.sites++;
                });
            } else if (type >= 14 && type <= 25) {                   // INTERSEG13-24: 2 bytes, segment type - 13
                const sn = type - 13;
                superSites(start, n, at => { patch(mem, at, 2, target(sn) + readLE(mem, at, 2), 0); relocs.sites++; });
            } else if (type >= 26 && type <= 37) {                   // INTERSEG25-36: 2 bytes, the bank, segment type - 25
                const sn = type - 25;
                superSites(start, n, at => { patch(mem, at, 2, target(sn) + readLE(mem, at, 2), -16 & 0xFF); relocs.sites++; });
            } else {
                throw new Error(`${seg.name}: SUPER type ${type} is not supported`);
            }
            r += 5 + len;
        } else {
            throw new Error(`${seg.name}: record $${op.toString(16)} at file offset ${r} is not supported`);
        }
        if (pc > seg.length) throw new Error(`${seg.name}: data runs past LENGTH ($${seg.length.toString(16)})`);
    }
    return { mem, relocs };

    function target(sn) {
        if (!bases.has(sn)) throw new Error(`${seg.name}: reference to segment ${sn}, which is not in the file`);
        return bases.get(sn);
    }
}

function linkStatic(file, outFile, firstBank = 2, showMap = false) {
    const b = fs.readFileSync(file);
    const segs = parseSegments(b);
    if (segs.length > 30) throw new Error(`${file}: ${segs.length} segments (at most 30)`);
    const bases = new Map();
    segs.forEach((s, i) => {
        if (s.length > 0x10000) throw new Error(`${s.name}: $${s.length.toString(16)} bytes is more than a bank`);
        s.bank = firstBank + i;
        bases.set(s.segnum, s.bank * 0x10000);
    });

    const header = Buffer.alloc(0x100);
    header.write('SGS8', 0, 'latin1');
    header[4] = 1;
    header[5] = segs.length;
    header.writeUInt16LE(segs[0].entry, 6);
    header[8] = segs[0].bank;

    const datas = [];
    segs.forEach((s, i) => {
        const { mem, relocs } = linkSegment(b, s, bases);
        let end = mem.length;
        while (end > 0 && mem[end - 1] === 0) end--;
        const e = 0x10 + i * 8;
        header[e] = s.bank;
        header.writeUInt32LE(end, e + 2);
        datas.push(mem.slice(0, end));
        if (showMap) {
            console.log(`  $${s.bank.toString(16).padStart(2, '0')}  ${s.name.padEnd(10)} LENGTH $${s.length.toString(16).padStart(5, '0')}  stored $${end.toString(16).padStart(5, '0')}  ${relocs.sites} relocations`);
        }
    });
    const out = Buffer.concat([header, ...datas]);
    fs.writeFileSync(outFile, out);
    console.log(`  ${outFile}: ${segs.length} segments in banks $${firstBank.toString(16)}-$${(firstBank + segs.length - 1).toString(16)}, ${out.length} bytes`);
    return segs.map(s => ({ name: s.name, bank: s.bank }));
}

module.exports = { linkStatic };

if (require.main === module) {
    const argv = process.argv.slice(2);
    let file = null, out = null, first = 2, map = false;
    for (let i = 0; i < argv.length; i++) {
        if (argv[i] === '--out') out = argv[++i];
        else if (argv[i] === '--first-bank') first = parseInt(argv[++i]);
        else if (argv[i] === '--map') map = true;
        else file = argv[i];
    }
    if (!file || !out) {
        console.error('usage: omf-static.js <OMF file> --out <image> [--first-bank 2] [--map]');
        process.exit(1);
    }
    linkStatic(file, out, first, map);
}

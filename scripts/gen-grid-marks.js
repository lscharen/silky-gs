#!/usr/bin/env node
'use strict';

/**
 * gen-grid-marks -- writes src/ppu/ppu_grid_marks.s, the grid renderer's sprite mark routines and its
 * quadrant copy routines (see the end of this file)
 *
 * A sprite at line k (0-7) and pixel p (0-7) of its top-left cell covers 2 x 2 cells (8x8) or 3 x 2 cells
 * (8x16: top, middle and bottom rows; the cell it starts in and the one to its right).  The quadrants it
 * covers in each cell depend only on the classes of k and p: {0}, {1-3}, {4}, {5-7}, so there are 16
 * patterns (pattern n = k class * 4 + p class; gridKCls[y] | gridPCls[x] = n * 2).  For each one this writes
 * routines with the masks as immediates and the cells the sprite doesn't reach left out:
 *
 *   gqR8_n / gqR16_n   replay (erase byte), called from a record: Y = cell, X = the list write pointer
 *                      (in and out), DBR = K
 *   gqR8L_n            gqR8_n that loads X from GridLPtr first (the skip cascade; the caller stores X back)
 *   gqM8_n / gqM16_n   new sprite (expose byte), entered with a jmp from gridMarkSprite8/16 after their
 *                      phx / phb, which they undo
 *   gqH8_n             gqM8_n that returns with rts (the skip cascade)
 *
 * and their dispatch tables, indexed by n * 2, plus gqX8TL/TR/BL/BR: the 8x8 masks in both nibbles, for the
 * skip cascade's test.  Then the copy routines of the erase pass (one set per code field bank) and the
 * expose pass, one per quadrant mask, and their dispatch tables gridEQTbl / gridXQTbl.
 *
 * Usage: node scripts/gen-grid-marks.js [--check]   (--check: exit 1 if the file is out of date)
 */

const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'src', 'ppu', 'ppu_grid_marks.s');
const REP = [0, 1, 4, 5];                         // a k / p value of each class
const cls = (v) => (v === 0 ? 0 : v < 4 ? 1 : v === 4 ? 2 : 3);

// Quadrants of a cell covered by a sprite h lines tall (bits: TL = 1, TR = 2, BL = 4, BR = 8).  Cell row r
// covers sprite-relative lines 8r - k .. 8r - k + 7, cell column c the pixels 8c - p .. 8c - p + 7.
function quads(h, k, p, r, c) {
    const lines = (top) => { const a = 8 * r + top - k; return a + 3 >= 0 && a <= h - 1; };
    const pixels = (left) => { const a = 8 * c + left - p; return a + 3 >= 0 && a <= 7; };
    let m = 0;
    if (lines(0) && pixels(0)) m |= 1;
    if (lines(0) && pixels(4)) m |= 2;
    if (lines(4) && pixels(0)) m |= 4;
    if (lines(4) && pixels(4)) m |= 8;
    return m;
}

// Every k and p of a class must give the same masks
for (const h of [8, 16]) {
    for (let k = 0; k < 8; k++) {
        for (let p = 0; p < 8; p++) {
            for (let r = 0; r < h / 8 + 1; r++) {
                for (let c = 0; c < 2; c++) {
                    if (quads(h, k, p, r, c) !== quads(h, REP[cls(k)], REP[cls(p)], r, c)) {
                        throw new Error(`class mismatch: ${h} lines, k=${k} p=${p} cell ${r},${c}`);
                    }
                }
            }
        }
    }
}

const OFFS = ['0', '2', 'GQ_PITCH2', 'GQ_PITCH2+2', 'GQ_PITCH2X2', 'GQ_PITCH2X2+2'];
const hex4 = (v) => '$' + v.toString(16).toUpperCase().padStart(4, '0');
const pad = (s, n) => s + ' '.repeat(Math.max(1, n - s.length));
const ins = (op, arg, cmt) => {
    let s = '            ' + pad(op, 6) + (arg || '');
    if (cmt) s = pad(s, 42) + '; ' + cmt;
    return s;
};
const lbl = (l, op, arg) => pad(l, 12) + pad(op, 6) + (arg || '');
const grid = (off) => (off === '0' ? 'gqGrid' : `gqGrid+${off}`);

function cells(h, n) {
    const k = REP[n >> 2], p = REP[n & 3];
    const out = [];
    for (let r = 0; r < h / 8 + 1; r++) {
        for (let c = 0; c < 2; c++) {
            const m = quads(h, k, p, r, c);
            if (m) out.push({ off: OFFS[r * 2 + c], m });
        }
    }
    return out;
}

const L = [];

// Replay: first touches are common, so they fall through; X = list write pointer
function replay(cs) {
    cs.forEach((c, i) => {
        const g = grid(c.off);
        L.push(ins('lda', `${g},y`));
        L.push(ins('bne', `:h${i}`));
        L.push(ins('tya', '', 'First touch: append "ldy #cell"'));
        if (c.off !== '0') {
            L.push(ins('clc'));
            L.push(ins('adc', `#${c.off}`));
        }
        L.push(ins('sta:', '$0000,x'));
        L.push(ins('txa'));
        L.push(ins('clc'));
        L.push(ins('adc', '#GQ_ENTRY'));
        L.push(ins('tax'));
        L.push(ins('lda', '#0'));
        L.push(lbl(`:h${i}`, 'ora', `#${hex4(c.m * 2)}`));
        L.push(ins('sta', `${g},y`));
    });
    L.push(ins('rts'));
}

// New sprite: the cells are mostly listed already (the replay), so the first touch is out of line
function mark(cs, epilogue) {
    cs.forEach((c, i) => {
        const g = grid(c.off);
        L.push(ins('lda', `${g},y`));
        L.push(ins('beq', `:n${i}`, 'First touch (out of line)'));
        L.push(ins('ora', `#${hex4((c.m * 2) << 8)}`));
        L.push(ins('sta', `${g},y`));
        L.push(`:d${i}`);
    });
    epilogue.forEach((op) => L.push(ins(op)));
    cs.forEach((c, i) => {
        const g = grid(c.off);
        L.push(lbl(`:n${i}`, 'tya'));
        if (c.off !== '0') {
            L.push(ins('clc'));
            L.push(ins('adc', `#${c.off}`));
        }
        L.push(ins('sta', '(GridLPtr)'));
        L.push(ins('lda', 'GridLPtr'));
        L.push(ins('clc'));
        L.push(ins('adc', '#GQ_ENTRY'));
        L.push(ins('sta', 'GridLPtr'));
        L.push(ins('lda', `#${hex4((c.m * 2) << 8)}`));
        L.push(ins('sta', `${g},y`));
        L.push(ins('jmp', `:d${i}`));
    });
}

L.push('; ppu_grid_marks.s - sprite mark routines of the grid dirty renderer, one per quadrant pattern, and its');
L.push('; quadrant copy routines, one per mask');
L.push(';');
L.push('; GENERATED by scripts/gen-grid-marks.js -- do not edit.  See the script for the patterns and the');
L.push('; register use.');
L.push('');
L.push('            DO    ENABLE_DIRTY_RENDERING');
L.push('');

for (let n = 0; n < 16; n++) {
    const c8 = cells(8, n), c16 = cells(16, n);
    L.push(`; pattern ${n}: k class ${n >> 2}, p class ${n & 3}`);
    L.push('            mx    %00');
    L.push(`gqR8L_${n}`);
    L.push(ins('ldx', 'GridLPtr'));
    L.push(`gqR8_${n}`);
    replay(c8);
    L.push('            mx    %00');
    L.push(`gqM8_${n}`);
    mark(c8, ['plb', 'plx', 'rts']);
    L.push('            mx    %00');
    L.push(`gqH8_${n}`);
    mark(c8, ['rts']);
    L.push('            mx    %00');
    L.push(`gqR16_${n}`);
    replay(c16);
    L.push('            mx    %00');
    L.push(`gqM16_${n}`);
    mark(c16, ['plb', 'plx', 'rts']);
    L.push('');
}

const tbl = (name, f) => L.push(pad(name, 12) + 'dw    ' + [...Array(16).keys()].map(f).join(','));
tbl('gqR8Tbl', (n) => `gqR8_${n}`);
tbl('gqR8LTbl', (n) => `gqR8L_${n}`);
tbl('gqM8Tbl', (n) => `gqM8_${n}`);
tbl('gqH8Tbl', (n) => `gqH8_${n}`);
tbl('gqR16Tbl', (n) => `gqR16_${n}`);
tbl('gqM16Tbl', (n) => `gqM16_${n}`);
L.push('; An 8x8 sprite\'s quadrants in either nibble, per cell (the skip cascade\'s test)');
['TL', 'TR', 'BL', 'BR'].forEach((name, i) => {
    tbl(`gqX8${name}`, (n) => {
        const m = quads(8, REP[n >> 2], REP[n & 3], i >> 1, i & 1) * 2;
        return hex4(m | (m << 8));
    });
});
L.push('');

// Copy routines, one per quadrant mask.  A mask's routine copies its highest quadrant, then continues with
// the routine of the remaining quadrants: inline the first time, with a jmp after that, so the routines
// share their tails.  A quadrant is 4 lines of one word: the right word of the cell (TR / BR) is at +2 in
// the SHR line and +1 in the PEA code (the operand of the first PEA), the left word at +0 and +4.
//
//   erase (one set per code field bank): ldal <bank>:line,x / sta shr,y   X = code field address, Y = SHR
//                                        address, DBR = $01 (the shadow screen, shadowing off)
//   expose:                              lda shr,y / sta shr,y             Y = SHR address, DBR = $01
//                                        (shadowing on: the write goes through to the screen)
//
// The erase operands are plain offsets with bank $00: gqInitTables stores the code field banks (^lite_base_1,
// ^lite_base_2) into their bank bytes, listed in gqEBSites1 / gqEBSites2.  (An EXT label + a constant
// doesn't relocate reliably.)
const QUAD = { 1: { top: 0, pea: 4, shr: 0 }, 2: { top: 0, pea: 1, shr: 2 }, 4: { top: 4, pea: 4, shr: 0 },
               8: { top: 4, pea: 1, shr: 2 } };
function copySet(name, block) {
    const done = new Set([0]);
    L.push(`${name}0`);
    L.push(ins('rts'));
    for (let m = 15; m > 0; m--) {
        if (done.has(m)) continue;
        let cur = m;
        while (!done.has(cur)) {
            L.push(`${name}${cur}`);
            done.add(cur);
            const hi = 1 << (31 - Math.clz32(cur));
            for (let l = 0; l < 4; l++) block(QUAD[hi], QUAD[hi].top + l);
            cur &= ~hi;
        }
        L.push(cur === 0 ? ins('rts') : ins('jmp', `${name}${cur}`));
    }
}
const shrOp = (q, l) => `{${l}*SHR_LINE_WIDTH}${q.shr ? '+' + q.shr : ''},y`;
const sites = { 1: [], 2: [] };
[1, 2].forEach((b) => {
    L.push(`; Erase, code field bank ${b}`);
    L.push('            mx    %00');
    copySet(`gridQE${b}_`, (q, l) => {
        const site = `gqEB${b}_${sites[b].length}`;
        sites[b].push(site);
        L.push(lbl(site, 'ldal', `{${l}*_LINE_SPAN}+${q.pea},x`));
        L.push(ins('sta:', shrOp(q, l)));
    });
});
L.push('; Expose');
L.push('            mx    %00');
copySet('gridQX', (q, l) => {
    L.push(ins('lda:', shrOp(q, l)));
    L.push(ins('sta:', shrOp(q, l)));
});
L.push('; Erase dispatch: GRID_CELL_EQ (0 = bank 1, 32 = bank 2, 64 = pad cell: nothing to copy) | mask * 2');
const masks = [...Array(16).keys()];
L.push(pad('gridEQTbl', 12) + 'dw    ' + masks.map((m) => `gridQE1_${m}`).join(','));
L.push(pad('', 12) + 'dw    ' + masks.map((m) => `gridQE2_${m}`).join(','));
L.push(pad('', 12) + 'dw    ' + masks.map(() => 'gridQE1_0').join(','));
tbl('gridXQTbl', (m) => `gridQX${m}`);
L.push('; The erase routines\' bank bytes, per code field bank (gqInitTables)');
L.push(`GQ_EBSITES  equ   ${sites[1].length}`);
[1, 2].forEach((b) => {
    for (let i = 0; i < sites[b].length; i += 8) {
        L.push(pad(i === 0 ? `gqEBSites${b}` : '', 12) + 'dw    ' + sites[b].slice(i, i + 8).map((x) => `${x}+3`).join(','));
    }
});
L.push('');
L.push('            FIN');
L.push('');

const text = L.join('\n');
if (process.argv.includes('--check')) {
    const cur = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
    if (cur !== text) { console.error('ppu_grid_marks.s is out of date'); process.exit(1); }
    process.exit(0);
}
fs.writeFileSync(OUT, text);
console.log(`wrote ${OUT}`);

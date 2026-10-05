#!/usr/bin/env node
'use strict';

/**
 * generate-palette-transitions — build a game's palette management from its palette files.
 *
 * Input: a directory of NES palette files (one per palette the game shows, see
 * palette-transition.js for the format, including the *reserved and ~approximated colors) and an
 * INI-style transitions file, where each [section] names a palette and lists the palettes that can
 * follow it (see src/games/zelda/palettes/transitions.txt).
 *
 * Output (Merlin32 source):
 *   palettes.s         The swizzle tables of every palette, 8 x 512 bytes (BG0-BG3, SP0-SP3) each,
 *                      for the game's PALDATA segment.
 *   pal_transitions.s  The palette ids, UpdatePalette / SetPaletteColor / DetectNESPalette and their
 *                      tables, for the main segment.
 *
 * The IIgs shows 16 colors (one palette of 16 slots) and the NES up to 25, so every palette gets one
 * fixed IIgs slot layout: the slot that each of its 32 palette RAM entries is shown in.  Swizzle
 * tables resolve a background tile's colors to slots when the tile is compiled into the code field,
 * so changing a slot's color is free, but a background group (BG0-BG3) whose slots change between
 * two palettes has its tiles redrawn.  The layouts are chosen together (search below) so that the
 * groups that keep the same slots across the transitions keep the redraws down; the sprites are
 * looked up through the swizzle tables every frame, so their slots are free.
 *
 * Within a layout, cells with the same color share a slot, except reserved colors (*$xx: changed on
 * the fly by the game), which get a slot of their own, and approximated colors ($xx~$yy), which are
 * shown in the slot of $yy.  Slot 0 is the universal background color ($3F00).
 *
 * Usage:
 *   node scripts/generate-palette-transitions.js <transitions-file> <palettes-dir> [options]
 *
 * Options:
 *   -o, --out-dir <dir>   Write palettes.s and pal_transitions.s to <dir> (default: <palettes-dir>)
 *   --report              Print the layouts, slot use and redraw masks
 *   --force               Regenerate even if the outputs are newer than the inputs
 *   -h, --help            Show this help message
 */

const fs = require('fs');
const path = require('path');
const { parsePaletteFile, ALL_GROUPS, BG_GROUPS, MAX_SLOTS } = require('./palette-transition.js');

const USAGE = `\
Usage: generate-palette-transitions <transitions-file> <palettes-dir> [options]

Options:
  -o, --out-dir <dir>   Write palettes.s and pal_transitions.s to <dir> (default: <palettes-dir>)
  --report              Print the layouts, slot use and redraw masks
  --force               Regenerate even if the outputs are newer than the inputs
  -h, --help            Show this help message
`;

const OUT_SWIZZLE = 'palettes.s';
const OUT_TRANSITIONS = 'pal_transitions.s';
const RESTARTS = 40;

class PaletteError extends Error {}
function fail(message) { throw new PaletteError(message); }

function popcount(x) { let n = 0; while (x) { n += x & 1; x >>= 1; } return n; }

// ---------------------------------------------------------------------------------------------
// Inputs

// Parse the transitions file into [{ from, tos: [...] }] in file order.  Blank lines and lines
// starting with ';' or '#' are ignored.
function parseTransitions(filePath) {
  const sections = [];
  let current = null;
  for (const rawLine of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line === '' || line.startsWith(';') || line.startsWith('#')) continue;
    const header = line.match(/^\[([A-Za-z0-9_]+)\]$/);
    if (header) { current = { from: header[1], tos: [] }; sections.push(current); continue; }
    const target = line.match(/^([A-Za-z0-9_]+)$/);
    if (!target) fail(`${filePath}: could not parse line: "${rawLine}"`);
    if (!current) fail(`${filePath}: "${line}" appears before any [section] header`);
    current.tos.push(target[1]);
  }
  return sections;
}

// The palettes (names with a file, in order of first appearance), the undirected edges (for the
// redraw cost) and each palette's successors (for the detection order).  Names without a file are
// skipped: quietly for a section of its own (a pseudo-state like "init"), with a warning when it is
// listed as a transition target (likely a typo or a missing file).
function loadGraph(transitionsFile, palettesDir, warnings) {
  const sections = parseTransitions(transitionsFile);
  const names = [];
  const consider = (n, isTarget) => {
    if (names.includes(n)) return;
    if (fs.existsSync(path.join(palettesDir, n + '.txt'))) names.push(n);
    else if (isTarget && !warnings.some(w => w.includes(`"${n}"`))) warnings.push(`skipping "${n}": no palette file`);
  };
  for (const s of sections) { consider(s.from, false); s.tos.forEach(t => consider(t, true)); }

  const edges = [];
  const succ = names.map(() => []);
  for (const s of sections) for (const t of s.tos) {
    const a = names.indexOf(s.from), b = names.indexOf(t);
    if (a < 0 || b < 0) continue;
    if (!succ[a].includes(b)) succ[a].push(b);
    const lo = Math.min(a, b), hi = Math.max(a, b);
    if (!edges.some(e => e.a === lo && e.b === hi)) edges.push({ a: lo, b: hi });
  }
  const pals = names.map(n => parsePaletteFile(path.join(palettesDir, n + '.txt')));
  return { names, edges, succ, pals };
}

// ---------------------------------------------------------------------------------------------
// Layouts

const tuple = (L, G) => [0, 1, 2, 3].map(i => L.cellSlot[G + ':' + i]).join(',');

// The background groups whose slots differ between two layouts (bit 0 = BG0 .. bit 3 = BG3)
function maskOf(La, Lb) {
  let m = 0;
  BG_GROUPS.forEach((G, g) => { if (tuple(La, G) !== tuple(Lb, G)) m |= 1 << g; });
  return m;
}

function makeSolver({ pals }) {
  const NP = pals.length;
  const univ = pals.map(p => p.BG0[0]);
  const res = (p, G, i) => pals[p].reserved.has(G + ':' + i);
  const shown = (p, G, i) => pals[p].approx.get(G + ':' + i) || pals[p][G][i];
  const col = (p, g, i) => shown(p, BG_GROUPS[g], i);
  const cells = [];                    // the background cells that can be canonical
  for (let g = 0; g < 4; g++) for (let i = 1; i < 4; i++) cells.push({ g, i });

  // K[p] = the background groups (bitmask) that palette p keeps "canonical": in the same slots as
  // every other palette that keeps that group canonical.  Returns the layouts, or how many colors
  // don't fit.
  return function solve(K) {
    const inP = (p, g) => (K[p] >> g) & 1;

    // Give the canonical cells global slots, sharing a slot when every palette that keeps both
    // shows the same (unreserved) color in them
    const slotOf = new Array(cells.length);
    const members = [];
    for (let c = 0; c < cells.length; c++) {
      const { g, i } = cells[c];
      let ok0 = true;
      for (let p = 0; p < NP; p++) {
        if (inP(p, g) && (col(p, g, i) !== univ[p] || res(p, BG_GROUPS[g], i))) { ok0 = false; break; }
      }
      if (ok0) { slotOf[c] = 0; continue; }
      let placed = false;
      for (let s = 0; s < members.length && !placed; s++) {
        let ok = true;
        for (const d of members[s]) {
          const { g: h, i: j } = cells[d];
          for (let p = 0; p < NP; p++) {
            if (!inP(p, g) || !inP(p, h)) continue;
            if (col(p, g, i) !== col(p, h, j) || res(p, BG_GROUPS[g], i) || res(p, BG_GROUPS[h], j)) { ok = false; break; }
          }
          if (!ok) break;
        }
        if (ok) { members[s].push(c); slotOf[c] = s + 1; placed = true; }
      }
      if (!placed) { members.push([c]); slotOf[c] = members.length; }
    }
    if (members.length > MAX_SLOTS - 1) return { ok: false, overflow: 100 * (members.length - MAX_SLOTS + 1) };

    // Complete each palette's layout around its canonical cells
    const layouts = [];
    let total = 0, overflow = 0;
    for (let p = 0; p < NP; p++) {
      let over = 0;
      const clut = new Array(MAX_SLOTS).fill(null);
      clut[0] = univ[p];
      const cellSlot = {};
      const locked = new Set();          // slots of reserved colors: never shared
      for (let c = 0; c < cells.length; c++) {
        const { g, i } = cells[c];
        if (!inP(p, g)) continue;
        const s = slotOf[c];
        clut[s] = col(p, g, i);
        cellSlot[BG_GROUPS[g] + ':' + i] = s;
        if (res(p, BG_GROUPS[g], i)) locked.add(s);
      }
      const alloc = (color, reserved) => {
        let s = reserved ? -1 : clut.findIndex((c, k) => c === color && !locked.has(k));
        if (s >= 0) return s;
        s = clut.indexOf(null);
        if (s < 0) { over++; return -1; }
        clut[s] = color;
        if (reserved) locked.add(s);
        return s;
      };
      for (const G of ALL_GROUPS) {
        cellSlot[G + ':0'] = 0;
        for (let i = 1; i < 4; i++) {
          if (cellSlot[G + ':' + i] === undefined) cellSlot[G + ':' + i] = alloc(shown(p, G, i), res(p, G, i));
        }
      }
      const used = clut.filter(c => c !== null).length + over;
      total += used;
      overflow += over;
      layouts.push({ clut, cellSlot, used });
    }
    return { ok: overflow === 0, overflow, total, layouts };
  };
}

// Local search: start with every palette keeping the most canonical groups it can manage on its
// own; while a palette overflows, drop the (palette, group) that helps the most; then add groups
// back (or swap one for another) while that lowers the redraws on the transitions.  Restarts with
// different (deterministic) tie-breaks and keeps the best.
function chooseLayouts(graph) {
  const { names, edges } = graph;
  const NP = names.length;
  const solveK = makeSolver(graph);
  const memo = new Map();             // the restarts revisit the same choices a lot
  const solve = K => {
    const key = K.join(',');
    let r = memo.get(key);
    if (!r) { r = solveK(K); memo.set(key, r); }
    return r;
  };
  const costOf = r => edges.reduce((t, e) => t + popcount(maskOf(r.layouts[e.a], r.layouts[e.b])), 0);

  // A palette that can't fit even on its own needs fewer colors (or more ~ approximations)
  const alone = solve(new Array(NP).fill(0));
  alone.layouts.forEach((L, p) => {
    if (L.used > MAX_SLOTS) {
      fail(`${names[p]}: needs ${L.used} IIgs colors, more than ${MAX_SLOTS} -- approximate ` +
        'some colors ($xx~$yy) or reserve fewer');
    }
  });

  const K0 = names.map((n, p) => {
    let best = 0;
    for (let k = 15; k > 0; k--) {
      const K = new Array(NP).fill(0);
      K[p] = k;
      if (solve(K).ok && popcount(k) > popcount(best)) best = k;
    }
    return best;
  });

  let seed = 12345;
  const rand = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x80000000);
  const moves = [];
  for (let p = 0; p < NP; p++) for (let g = 0; g < 4; g++) moves.push([p, g]);
  const shuffled = () => moves.map(m => [rand(), m]).sort((x, y) => x[0] - y[0]).map(x => x[1]);

  function descend(K) {
    let r = solve(K);
    while (!r.ok) {
      let pick = null;
      for (const [p, g] of shuffled()) {
        if (!((K[p] >> g) & 1)) continue;
        K[p] ^= 1 << g;
        const t = solve(K);
        const score = t.overflow * 1000 + (t.ok ? costOf(t) : 0);
        if (!pick || score < pick.score) pick = { p, g, score };
        K[p] ^= 1 << g;
      }
      K[pick.p] ^= 1 << pick.g;
      r = solve(K);
    }
    let cost = costOf(r);
    for (let improved = true; improved;) {
      improved = false;
      for (const [p, g] of shuffled()) {
        if ((K[p] >> g) & 1) continue;
        K[p] ^= 1 << g;
        const t = solve(K);
        if (t.ok && costOf(t) < cost) { r = t; cost = costOf(t); improved = true; continue; }
        let swapped = false;
        for (const [q, h] of shuffled()) {
          if (!((K[q] >> h) & 1) || (q === p && h === g)) continue;
          K[q] ^= 1 << h;
          const u = solve(K);
          if (u.ok && costOf(u) < cost) { r = u; cost = costOf(u); improved = swapped = true; break; }
          K[q] ^= 1 << h;
        }
        if (!swapped) K[p] ^= 1 << g;
      }
    }
    return { r, cost, K: K.slice() };
  }

  let found = null;
  for (let run = 0; run < RESTARTS; run++) {
    const d = descend(K0.slice());
    if (!found || d.cost < found.cost || (d.cost === found.cost && d.r.total < found.r.total)) found = d;
  }
  return { cost: found.cost, K: found.K, layouts: found.r.layouts };
}

// ---------------------------------------------------------------------------------------------
// Output

const U = n => n.toUpperCase();
const hex2 = v => '$' + v.toString(16).toUpperCase().padStart(2, '0');
const hex4 = v => '$' + v.toString(16).toUpperCase().padStart(4, '0');
const slotsOf = (L, G) => [0, 1, 2, 3].map(i => L.cellSlot[G + ':' + i]);
const markColor = (pal, G, i) => (pal.reserved.has(G + ':' + i) ? '*' : '') + pal[G][i] +
  (pal.approx.has(G + ':' + i) ? '~' + pal.approx.get(G + ':' + i) : '');

function swizzleSource(graph, best, source) {
  const { names, pals } = graph;
  const P = [];
  P.push(`; Auto-generated by scripts/generate-palette-transitions.js from ${source}.`);
  P.push('; Do not edit by hand -- regenerate instead.');
  P.push(';');
  P.push('; IIgs swizzle tables for each palette, 8 x 512 bytes per palette (BG0-BG3, then SP0-SP3).');
  P.push("; NES_SetPaletteMap takes the address of a palette's first table.  Each entry maps a byte of");
  P.push('; 2bpp NES pixels to 4 IIgs pixels: entry [r][c] = slot(c>>2) slot(c&3) slot(r>>2) slot(r&3),');
  P.push("; with the IIgs slot of each NES color index given by the palette's layout (pal_transitions.s).");
  P.push('');
  names.forEach((n, p) => {
    const L = best.layouts[p];
    P.push(`; ${n}`);
    P.push(`PAL_${U(n)}_SWIZZLE ENT`);
    for (const G of ALL_GROUPS) {
      const m = slotsOf(L, G);
      P.push(`; ${G} ${pals[p][G].join(' ')} -> slots ${m.join(',')}`);
      for (let r = 0; r < 16; r++) {
        const row = [];
        for (let c = 0; c < 16; c++) row.push(hex4((m[c >> 2] << 12) | (m[c & 3] << 8) | (m[r >> 2] << 4) | m[r & 3]));
        P.push('     dw  ' + row.join(','));
      }
    }
    P.push('');
  });
  return P.join('\n') + '\n';
}

function transitionsSource(graph, best, source, warnings) {
  const { names, succ, pals } = graph;
  const T = [];
  if (warnings.length) {
    T.push('; Warnings from generation:');
    warnings.forEach(w => T.push(`; WARNING: ${w}`));
    T.push('');
  }
  T.push(`; Auto-generated by scripts/generate-palette-transitions.js from ${source}.`);
  T.push('; Do not edit by hand -- regenerate instead.');
  T.push(';');
  T.push('; Every palette has one fixed IIgs slot layout: the IIgs palette 0 slot that each of the 32 NES');
  T.push('; palette RAM entries ($3F00-$3F1F) is shown in.  The layouts are chosen together, so that the');
  T.push("; background groups that keep the same slots across the transitions don't need their tiles");
  T.push('; redrawn (a group whose slots change has to be recompiled with the new swizzle table).');
  T.push(';');
  T.push('; Requires: NES_ColorToIIgs_X, NES_SetPaletteMap, RefreshPPUAttributes, PPU_MEM, SHR_PALETTES');
  T.push('');
  T.push(`; Swizzle tables, in the PALDATA segment (${OUT_SWIZZLE})`);
  names.forEach(n => T.push(`PAL_${U(n)}_SWIZZLE EXT`));
  T.push('');
  T.push('; Palette ids, word-aligned so they index the tables below directly.  0 = no palette.');
  names.forEach((n, p) => T.push(`PAL_${U(n)} equ ${2 * (p + 1)}`));
  T.push('');
  T.push('; Layouts (NES color -> [slots] per group; *reserved, ~shown as):');
  names.forEach((n, p) => {
    T.push(`;   ${n}`);
    for (const G of ALL_GROUPS) {
      T.push(`;     ${G} ${pals[p][G].map((c, i) => markColor(pals[p], G, i)).join(' ')} -> [${tuple(best.layouts[p], G)}]`);
    }
  });
  T.push('');
  T.push(`            mx    %00

; UpdatePalette
;
; X = from palette id (PAL_*, or 0 for none), Y = to palette id
;
; Switches the swizzle tables to the new palette, loads its colors into IIgs palette 0 from the
; current NES palette RAM (so colors the game changes on the fly are kept), then redraws the
; background groups whose slots changed.  Call from the GS task (it redraws tiles).
UpdatePalette
            lda   BG_UPDATE_MASKS,x
            pha
            lda   (1,s),y
            sta   1,s                 ; 1,s = groups to redraw

            phy
            ldx   PAL_SWIZZLE_LO,y
            lda   PAL_SWIZZLE_HI,y
            jsr   NES_SetPaletteMap
            ply

            lda   PAL_CELLS,y
            pha                       ; 1,s = slot map, 3,s = groups to redraw
            ldy   #31                 ; Backwards, so the BG colors win a shared slot and $3F00 is last
:loop       lda   (1,s),y
            and   #$00FF
            cmp   #$00FF
            beq   :next               ; not shown
            pha                       ; 1,s = slot * 2
            tyx
            ldal  PPU_MEM+$3F00,x
            jsr   NES_ColorToIIgs_X
            plx
            stal  SHR_PALETTES,x
:next       dey
            bpl   :loop
            pla
            pla
            jmp   RefreshPPUAttributes

; SetPaletteColor
;
; A = NES color, Y = NES palette RAM offset (0-31), X = palette id.  Shows one changed color in
; palette X's layout.  Colors that aren't shown are ignored.
SetPaletteColor
            pha
            lda   PAL_CELLS,x
            pha                       ; 1,s = slot map, 3,s = color
            lda   (1,s),y
            and   #$00FF
            cmp   #$00FF
            beq   :skip
            sta   1,s                 ; 1,s = slot * 2
            lda   3,s
            jsr   NES_ColorToIIgs_X
            plx
            stal  SHR_PALETTES,x
            pla
            rts
:skip       pla
            pla
            rts

; DetectNESPalette
;
; X = the current palette id (0 = none).  Returns A = Y = the PAL_* id of the palette whose
; colors are all in palette RAM ($3F00-$3F1F, other than the reserved ones and the unused
; color 0s), or 0 if there is none (e.g. a step of a fade).  The current palette is tried first,
; then the palettes that follow it in the transitions, then the rest.
DetectNESPalette
            php
            rep   #$30
            stx   :from
            txa
            beq   :all
            jsr   :match              ; still the current palette?
            bcs   :found
            ldx   :from
            lda   PAL_SUCC,x          ; its successors, a 0-terminated list of ids
:snext      sta   :ptr
            tax
            lda:  0,x
            beq   :all
            tax
            jsr   :match
            bcs   :found
            lda   :ptr
            inc
            inc
            bra   :snext
:all        ldx   #2
:anext      jsr   :match
            bcs   :found
            inx
            inx
            cpx   #${2 * names.length + 2}
            bcc   :anext
            ldx   #0
:found      txy
            plp
            tya
            rts

; X = palette id.  Carry set if its colors are in palette RAM.  X is kept.
:match      phx
            lda   PAL_MATCH,x
            clc
            adc   #31
            tay                       ; Y -> the palette's bytes, from the last
            ldx   #31                 ; X = palette RAM offset
            sep   #$20
            mx    %10
:mbyte      lda:  0,y
            cmp   #$FF                ; any value
            beq   :mnext
            cmpl  PPU_MEM+$3F00,x
            bne   :mfail
:mnext      dey
            dex
            bpl   :mbyte
            rep   #$20
            mx    %00
            plx
            sec
            rts
:mfail      rep   #$20
            plx
            clc
            rts

:from       ds    2
:ptr        ds    2
`);

  T.push('; id -> palette RAM bytes to match ($3F00-$3F1F; $FF = any value: not shown, or reserved)');
  T.push('PAL_MATCH');
  T.push('            dw    0');
  names.forEach(n => T.push(`            dw    PAL_${U(n)}_MATCH`));
  names.forEach((n, p) => {
    const bytes = ALL_GROUPS.flatMap((G, gi) => [0, 1, 2, 3].map(i => {
      if (i === 0 && gi > 0) return '$FF';                   // only $3F00 of the color 0s is shown
      if (pals[p].reserved.has(G + ':' + i)) return '$FF';
      return pals[p][G][i];
    }));
    T.push(`PAL_${U(n)}_MATCH`);
    T.push('            db    ' + bytes.slice(0, 16).join(',') + '   ; BG0-BG3');
    T.push('            db    ' + bytes.slice(16).join(',') + '   ; SP0-SP3');
  });
  T.push('');

  T.push('; id -> the ids of the palettes that can follow it (transitions), 0-terminated');
  T.push('PAL_SUCC');
  T.push('            dw    PAL_NONE_SUCC');
  names.forEach(n => T.push(`            dw    PAL_${U(n)}_SUCC`));
  T.push('PAL_NONE_SUCC');
  T.push('            dw    0');
  names.forEach((n, p) => {
    T.push(`PAL_${U(n)}_SUCC`);
    T.push('            dw    ' + [...succ[p].map(q => `PAL_${U(names[q])}`), '0'].join(','));
  });
  T.push('');

  T.push(`; id -> swizzle tables (PALDATA segment, ${OUT_SWIZZLE})`);
  T.push('PAL_SWIZZLE_LO');
  T.push('            dw    0');
  names.forEach(n => T.push(`            dw    PAL_${U(n)}_SWIZZLE`));
  T.push('PAL_SWIZZLE_HI');
  T.push('            dw    0');
  names.forEach(n => T.push(`            dw    ^PAL_${U(n)}_SWIZZLE`));
  T.push('');

  T.push("; id -> slot map: for each NES palette RAM entry, the IIgs slot * 2, or $FF if it isn't shown");
  T.push('; (color 0 of the groups other than BG0, colors that share slot 0 with $3F00, and approximated');
  T.push("; colors, which are shown in another color's slot)");
  T.push('PAL_CELLS');
  T.push('            dw    0');
  names.forEach(n => T.push(`            dw    PAL_${U(n)}_CELLS`));
  names.forEach((n, p) => {
    const L = best.layouts[p];
    const bytes = [];
    ALL_GROUPS.forEach((G, gi) => [0, 1, 2, 3].forEach(i => {
      const slot = L.cellSlot[G + ':' + i];
      if ((slot === 0 && !(gi === 0 && i === 0)) || pals[p].approx.has(G + ':' + i)) bytes.push('$FF');
      else bytes.push(hex2(2 * slot));
    }));
    // Every slot a color is shown in needs a cell that writes it
    const written = new Set(bytes.filter(b => b !== '$FF'));
    ALL_GROUPS.forEach(G => [1, 2, 3].forEach(i => {
      const slot = L.cellSlot[G + ':' + i];
      if (slot !== 0 && !written.has(hex2(2 * slot))) {
        fail(`${n}: the slot that ${G}[${i}] is shown in is never loaded -- approximate with a color the palette shows`);
      }
    }));
    T.push(`PAL_${U(n)}_CELLS`);
    T.push('            db    ' + bytes.slice(0, 16).join(',') + '   ; BG0-BG3');
    T.push('            db    ' + bytes.slice(16).join(',') + '   ; SP0-SP3');
  });
  T.push('');

  T.push('; from id -> its row of to id -> background groups to redraw (bit 0 = BG0 .. bit 3 = BG3).');
  T.push('; From no palette (0), everything is redrawn.');
  T.push('BG_UPDATE_MASKS');
  T.push('            dw    BG_UPDATE_MASKS_NONE');
  names.forEach(n => T.push(`            dw    BG_UPDATE_MASKS_${U(n)}`));
  T.push('BG_UPDATE_MASKS_NONE');
  T.push('            dw    $0000' + names.map(() => ',%1111').join(''));
  names.forEach((a, p) => {
    T.push(`BG_UPDATE_MASKS_${U(a)}`);
    T.push('            dw    $0000');
    names.forEach((b, q) => T.push(`            dw    %${maskOf(best.layouts[p], best.layouts[q]).toString(2).padStart(4, '0')}   ; to ${b}`));
  });
  return T.join('\n') + '\n';
}

function report(graph, best) {
  const { names, edges, succ, pals } = graph;
  const out = [];
  out.push(`palettes: ${names.join(', ')}`);
  out.push(`transition redraws: ${best.cost} (background groups, over ${edges.length} transitions)`);
  out.push(`slots used: ${best.layouts.map(l => l.used).join('/')}`);
  names.forEach((n, p) => {
    const L = best.layouts[p];
    out.push(`${n}: followed by ${succ[p].map(q => names[q]).join(' ') || '-'}; ` +
      `canonical ${BG_GROUPS.filter((G, g) => (best.K[p] >> g) & 1).join(' ') || '-'}`);
    for (const G of ALL_GROUPS) out.push(`   ${G} ${pals[p][G].map((c, i) => markColor(pals[p], G, i)).join(' ')} -> [${tuple(L, G)}]`);
    out.push(`   CLUT ${L.clut.map(c => c || '--').join(' ')}`);
  });
  out.push('redraw masks (from \\ to, BG3..BG0):');
  names.forEach((a, p) => out.push(`   ${a.padEnd(14)} ` +
    names.map((b, q) => maskOf(best.layouts[p], best.layouts[q]).toString(2).padStart(4, '0')).join(' ')));
  return out.join('\n') + '\n';
}

// ---------------------------------------------------------------------------------------------

// Generate <outDir>/palettes.s and <outDir>/pal_transitions.s.  Skipped when both are newer than
// every input (the palette files, the transitions file and these scripts), unless force is set.
// Returns true if the files were (re)generated.
function generatePalettes({ transitionsFile, palettesDir, outDir = palettesDir, force = false, printReport = false, log = console.log }) {
  if (!fs.existsSync(transitionsFile)) fail(`transitions file not found: ${transitionsFile}`);
  if (!fs.existsSync(palettesDir) || !fs.statSync(palettesDir).isDirectory()) fail(`palettes directory not found: ${palettesDir}`);

  const outputs = [OUT_SWIZZLE, OUT_TRANSITIONS].map(f => path.join(outDir, f));
  const inputs = [transitionsFile, __filename, require.resolve('./palette-transition.js'),
    ...fs.readdirSync(palettesDir).filter(f => f.endsWith('.txt')).map(f => path.join(palettesDir, f))];
  if (!force && !printReport && outputs.every(f => fs.existsSync(f))) {
    const oldestOut = Math.min(...outputs.map(f => fs.statSync(f).mtimeMs));
    if (inputs.every(f => fs.statSync(f).mtimeMs <= oldestOut)) return false;
  }

  const warnings = [];
  const graph = loadGraph(transitionsFile, palettesDir, warnings);
  if (graph.names.length === 0) fail('no palettes: none of the names in the transitions file has a palette file');
  const best = chooseLayouts(graph);

  const source = path.relative(process.cwd(), palettesDir).replace(/\\/g, '/') + '/';
  fs.writeFileSync(outputs[0], swizzleSource(graph, best, source));
  fs.writeFileSync(outputs[1], transitionsSource(graph, best, source, warnings));
  warnings.forEach(w => log(`generate-palette-transitions: warning: ${w}`));
  log(`generate-palette-transitions: ${graph.names.length} palettes, ${best.cost} transition redraws -> ` +
    outputs.map(f => path.relative(process.cwd(), f)).join(', '));
  if (printReport) log(report(graph, best));
  return true;
}

function main() {
  const args = process.argv.slice(2);
  const positional = [];
  const opts = { force: false, printReport: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '-h' || a === '--help') { process.stdout.write(USAGE); return; }
    else if (a === '-o' || a === '--out-dir') opts.outDir = args[++i];
    else if (a === '--report') opts.printReport = true;
    else if (a === '--force') opts.force = true;
    else if (a.startsWith('-')) { process.stderr.write(`Error: unknown option: ${a}\n${USAGE}`); process.exit(1); }
    else positional.push(a);
  }
  if (positional.length !== 2) { process.stderr.write(USAGE); process.exit(1); }
  [opts.transitionsFile, opts.palettesDir] = positional;
  try {
    if (!generatePalettes(opts)) console.log('generate-palette-transitions: up to date');
  } catch (e) {
    if (!(e instanceof PaletteError)) throw e;
    process.stderr.write(`Error: ${e.message}\n`);
    process.exit(1);
  }
}

if (require.main === module) main();

module.exports = { generatePalettes, PaletteError };

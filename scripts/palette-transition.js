#!/usr/bin/env node
'use strict';

/**
 * palette-transition — compute a minimal-disruption IIgs CLUT slot assignment
 * for a NES palette transition.
 *
 * Background: the engine's swizzle tables resolve (attribute-select,
 * pixel-value) pairs to a fixed IIgs palette slot (0-15) once, when a tile is
 * compiled into the PEA field (see SyncPPUMetatile/RefreshMetatile,
 * src/ppu/ppu_metatiles.s). Recoloring a slot (updating the IIgs hardware
 * palette register) is free, but changing *which slot* a background
 * palette's colors occupy requires every tile using that palette to be
 * recompiled/redrawn -- expensive. Sprites read through SwizzlePtr fresh
 * every frame, so reassigning a sprite palette's slots costs nothing.
 *
 * Model: this does NOT assume the old assignment is fixed by history (e.g.
 * the engine's simple cold-load greedy-by-color-value scan). Both the old
 * and new IIgs slot assignments are jointly designed from scratch, subject
 * only to physical constraints:
 *   - At any single moment (old-time or new-time), one IIgs slot holds one
 *     color -- so two cells (a BG/SP group's color at a given pixel
 *     position) can only share a slot AT THAT MOMENT if they have the same
 *     color at that moment.
 *   - A cell's OLD color and NEW color do not need to be the same value --
 *     recoloring a slot between old-time and new-time is free.
 *   - A background group's tiles avoid a redraw only if the group's full
 *     4-color slot tuple is IDENTICAL between old-time and new-time (same
 *     slot numbers, content notwithstanding).
 *   - Sprite groups never need old-time/new-time slot alignment (redrawing
 *     them costs nothing), but still need a valid slot at each moment.
 *   - At most 16 total slots may be in use at old-time, and likewise at
 *     new-time (independently -- a slot number can be used for unrelated
 *     purposes at the two different moments).
 *
 * Because two cells can only share a slot when they agree on BOTH their old
 * AND new color, the unit of "must share a slot" for cells we want a
 * background group to keep unchanged is the (oldColor, newColor) PAIR, not
 * the color value alone. This is a strictly more flexible model than
 * per-color-value dedup: two cells with the identical old color but
 * DIFFERENT new colors no longer need to fight over one slot, as long as
 * there's spare slot budget (fewer than 16 distinct colors in use) to give
 * them independent slots instead.
 *
 * The search: try every subset of {BG0,BG1,BG2,BG3} (16 subsets, largest
 * first) as "the groups we require to stay unchanged"; for each, construct
 * a concrete old-time/new-time slot assignment (deterministic, see
 * buildForSubset) and check it fits within 16 slots at both moments. The
 * first (largest) subset with a feasible construction is optimal, since a
 * larger required-unchanged set can never make the remaining budget problem
 * easier. Ties within a size tier are broken by fewest total slots used
 * (leaves the most room for a future transition).
 *
 * Input format (see scripts/palettes/zpal1.txt / zpal2.txt for examples):
 *   BG0: $0F $30 $00 $12
 *   BG1: $0F $16 $27 $36
 *   BG2: $0F $1A $37 $12
 *   BG3: $0F $17 $37 $12
 *   SP0: $0F $29 $27 $17
 *   SP1: $0F $02 $22 $30
 *   SP2: $0F $16 $27 $30
 *   SP3: $0F $0F $1C $16
 * All 8 groups (BG0-BG3, SP0-SP3) must be present, each with exactly 4 NES
 * color codes ($00-$3F). Color 0 of every BG/SP group is expected to be the
 * same value (the NES hardware-mirrored universal background color) in each
 * file; a mismatch is reported as a warning, not an error. That shared
 * color is always pinned to slot 0 at both old-time and new-time.
 *
 * Usage:
 *   node scripts/palette-transition.js <old-file> <new-file> [options]
 *
 * Options:
 *   --format <text|json>   Output format (default: text)
 *   -o, --output <file>    Write to <file> instead of stdout
 *   -h, --help             Show this help message
 */

const fs = require('fs');

const USAGE = `\
Usage: palette-transition <old-file> <new-file> [options]

Jointly design old-time/new-time IIgs CLUT slot assignments for a NES
palette transition that minimize how many of the 4 background palettes
need their tiles redrawn (sprite palette reassignment is free).

Options:
  --format <text|json>   Output format (default: text)
  -o, --output <file>    Write to <file> instead of stdout
  -h, --help             Show this help message
`;

const BG_GROUPS = ['BG0', 'BG1', 'BG2', 'BG3'];
const SP_GROUPS = ['SP0', 'SP1', 'SP2', 'SP3'];
const ALL_GROUPS = [...BG_GROUPS, ...SP_GROUPS];
const MAX_SLOTS = 16;

function parseArgs(argv) {
  const opts = { oldFile: null, newFile: null, format: 'text', output: null };
  const positional = [];

  let i = 0;
  while (i < argv.length) {
    const arg = argv[i];
    switch (arg) {
      case '-h': case '--help':
        process.stdout.write(USAGE);
        process.exit(0);
        break;
      case '--format':
        opts.format = argv[++i];
        if (opts.format !== 'text' && opts.format !== 'json') {
          fail(`--format must be "text" or "json", got "${opts.format}"`);
        }
        break;
      case '-o': case '--output':
        opts.output = argv[++i];
        break;
      default:
        if (arg.startsWith('-')) fail(`Unknown option: ${arg}`);
        positional.push(arg);
    }
    i++;
  }

  if (positional.length !== 2) {
    process.stderr.write(USAGE);
    fail('Expected exactly two file arguments: <old-file> <new-file>');
  }
  [opts.oldFile, opts.newFile] = positional;
  return opts;
}

function fail(message) {
  process.stderr.write(`Error: ${message}\n`);
  process.exit(1);
}

// Parse a palette description file into { BG0: ['$0F','$30','$00','$12'], ... }
function parsePaletteFile(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const groups = {};

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line === '' || line.startsWith(';') || line.startsWith('#')) continue;

    const m = line.match(/^([A-Za-z0-9_]+):\s*(.+)$/);
    if (!m) fail(`${filePath}: could not parse line: "${rawLine}"`);
    const [, label, rest] = m;

    const colors = rest.trim().split(/\s+/).map(tok => {
      const cm = tok.match(/^\$([0-9A-Fa-f]{1,2})$/);
      if (!cm) fail(`${filePath}: bad color token "${tok}" on line: "${rawLine}"`);
      return '$' + cm[1].toUpperCase().padStart(2, '0');
    });

    if (groups[label] !== undefined) fail(`${filePath}: duplicate group "${label}"`);
    groups[label] = colors;
  }

  for (const g of ALL_GROUPS) {
    if (!groups[g]) fail(`${filePath}: missing required group "${g}"`);
    if (groups[g].length !== 4) {
      fail(`${filePath}: group "${g}" has ${groups[g].length} colors, expected 4`);
    }
  }

  return groups;
}

// Warn (not error) if BG0-3/SP0-3's shared/mirrored color-0 entries disagree.
function checkSharedColorConsistency(groups, label, warnings) {
  const shared = groups.BG0[0];
  for (const g of ALL_GROUPS) {
    if (groups[g][0] !== shared) {
      warnings.push(
        `${label}: ${g}[0] = ${groups[g][0]} does not match BG0[0] = ${shared} ` +
        `(expected the universal/mirrored background color to be identical across all groups)`
      );
    }
  }
  return shared;
}

function cellKey(group, i) { return `${group}:${i}`; }

// Enumerate all subsets of a 4-element array as arrays of indices, grouped
// by size descending: [ [[0,1,2,3]], [[0,1,2],[0,1,3],...], ..., [[]] ]
function subsetsBySizeDescending(n) {
  const bySize = Array.from({ length: n + 1 }, () => []);
  for (let mask = 0; mask < (1 << n); mask++) {
    const idxs = [];
    for (let b = 0; b < n; b++) if (mask & (1 << b)) idxs.push(b);
    bySize[idxs.length].push(idxs);
  }
  return bySize.slice().reverse(); // size n, n-1, ..., 0
}

function nextFreeSlot(used) {
  for (let s = 0; s < MAX_SLOTS; s++) if (!used.has(s)) return s;
  return null;
}

/**
 * Construct a concrete old-time/new-time slot assignment that forces every
 * cell in `subset` (an array of BG group names) to have oldSlot === newSlot
 * for all 4 positions, and fills in every other cell (remaining BG groups +
 * all SP groups) independently at old-time and new-time. Returns null if
 * the construction overflows MAX_SLOTS at either moment.
 */
function buildForSubset(subset, oldGroups, newGroups, sharedOld, sharedNew) {
  const oldUsed = new Set();
  const newUsed = new Set();
  const oldValueSlot = new Map(); // old color -> slot (old-time dedup)
  const newValueSlot = new Map(); // new color -> slot (new-time dedup)
  const unifiedPairSlot = new Map(); // "old|new" -> slot (subset dedup)
  const cellOldSlot = {};
  const cellNewSlot = {};

  function claimUnified(slot, oldVal, newVal) {
    oldUsed.add(slot);
    newUsed.add(slot);
    if (!oldValueSlot.has(oldVal)) oldValueSlot.set(oldVal, slot);
    if (!newValueSlot.has(newVal)) newValueSlot.set(newVal, slot);
  }

  function nextFreeBoth() {
    for (let s = 0; s < MAX_SLOTS; s++) if (!oldUsed.has(s) && !newUsed.has(s)) return s;
    return null;
  }

  function placeUnified(group, i, oldVal, newVal) {
    const key = oldVal + '|' + newVal;
    let slot = unifiedPairSlot.get(key);
    if (slot === undefined) {
      slot = nextFreeBoth();
      if (slot === null) return false;
      unifiedPairSlot.set(key, slot);
      claimUnified(slot, oldVal, newVal);
    }
    cellOldSlot[cellKey(group, i)] = slot;
    cellNewSlot[cellKey(group, i)] = slot;
    return true;
  }

  // The universal background color is unconditionally pinned to slot 0 at
  // both old-time and new-time, regardless of which BG groups we're forcing
  // to stay unchanged.
  const sharedKey = sharedOld + '|' + sharedNew;
  unifiedPairSlot.set(sharedKey, 0);
  claimUnified(0, sharedOld, sharedNew);
  for (const g of BG_GROUPS) {
    cellOldSlot[cellKey(g, 0)] = 0;
    cellNewSlot[cellKey(g, 0)] = 0;
  }

  // Force every cell of the requested subset to a shared old/new slot.
  for (const g of subset) {
    for (let i = 1; i < 4; i++) {
      if (!placeUnified(g, i, oldGroups[g][i], newGroups[g][i])) return null;
    }
  }

  // Independently complete every remaining cell's old-time and new-time
  // slot (BG groups not in the subset, plus all SP groups; SP0-3's
  // position 0 also needs placing since it wasn't forced above).
  function placeOldOnly(group, i) {
    const key = cellKey(group, i);
    if (cellOldSlot[key] !== undefined) return true;
    const val = oldGroups[group][i];
    let slot = oldValueSlot.get(val);
    if (slot === undefined) {
      slot = nextFreeSlot(oldUsed);
      if (slot === null) return false;
      oldUsed.add(slot);
      oldValueSlot.set(val, slot);
    }
    cellOldSlot[key] = slot;
    return true;
  }
  function placeNewOnly(group, i) {
    const key = cellKey(group, i);
    if (cellNewSlot[key] !== undefined) return true;
    const val = newGroups[group][i];
    let slot = newValueSlot.get(val);
    if (slot === undefined) {
      slot = nextFreeSlot(newUsed);
      if (slot === null) return false;
      newUsed.add(slot);
      newValueSlot.set(val, slot);
    }
    cellNewSlot[key] = slot;
    return true;
  }

  for (const g of ALL_GROUPS) {
    for (let i = 0; i < 4; i++) {
      if (!placeOldOnly(g, i)) return null;
      if (!placeNewOnly(g, i)) return null;
    }
  }

  return { cellOldSlot, cellNewSlot, oldTotal: oldUsed.size, newTotal: newUsed.size };
}

/**
 * Search subsets of BG_GROUPS from largest to smallest; within a size tier,
 * try every subset and keep the feasible one using fewest total slots.
 * Returns the first (largest) tier with a feasible construction.
 */
function optimize(oldGroups, newGroups, sharedOld, sharedNew) {
  const sizeTiers = subsetsBySizeDescending(BG_GROUPS.length);

  for (const tier of sizeTiers) {
    let best = null;

    for (const idxs of tier) {
      const subset = idxs.map(i => BG_GROUPS[i]);
      const built = buildForSubset(subset, oldGroups, newGroups, sharedOld, sharedNew);
      if (!built) continue;

      const totalSlots = built.oldTotal + built.newTotal;
      if (!best || totalSlots < best.totalSlots) {
        best = { ...built, subset, totalSlots };
      }
    }

    if (best) return { ...best, feasible: true };
  }

  return { feasible: false };
}

function buildReport(oldGroups, newGroups, result, warnings) {
  const groupChanged = {};
  for (const g of BG_GROUPS) {
    let changed = false;
    for (let i = 0; i < 4; i++) {
      if (result.cellOldSlot[cellKey(g, i)] !== result.cellNewSlot[cellKey(g, i)]) { changed = true; break; }
    }
    groupChanged[g] = changed;
  }
  const changedGroups = BG_GROUPS.filter(g => groupChanged[g]);

  const oldSlotTable = Array(MAX_SLOTS).fill(null);
  const newSlotTable = Array(MAX_SLOTS).fill(null);
  for (const g of ALL_GROUPS) {
    for (let i = 0; i < 4; i++) {
      oldSlotTable[result.cellOldSlot[cellKey(g, i)]] = oldGroups[g][i];
      newSlotTable[result.cellNewSlot[cellKey(g, i)]] = newGroups[g][i];
    }
  }

  return {
    warnings,
    requiredUnchangedSubset: result.subset,
    oldSlotsUsed: result.oldTotal,
    newSlotsUsed: result.newTotal,
    maxSlots: MAX_SLOTS,
    backgroundPalettesChanged: changedGroups.length,
    backgroundPalettesTotal: BG_GROUPS.length,
    groups: ALL_GROUPS.map(g => ({
      group: g,
      isBackground: BG_GROUPS.includes(g),
      changed: BG_GROUPS.includes(g) ? groupChanged[g] : null, // null = N/A (cost-free) for sprites
      oldColors: oldGroups[g],
      newColors: newGroups[g],
      oldSlots: [0, 1, 2, 3].map(i => result.cellOldSlot[cellKey(g, i)]),
      newSlots: [0, 1, 2, 3].map(i => result.cellNewSlot[cellKey(g, i)]),
    })),
    oldSlotTable, // index = IIgs slot, value = NES color at old-time (or null if unused)
    newSlotTable, // index = IIgs slot, value = NES color at new-time (or null if unused)
  };
}

function formatText(report) {
  const lines = [];
  lines.push('=== Palette Transition Analysis ===');
  lines.push('');
  if (report.warnings.length) {
    lines.push('Warnings:');
    for (const w of report.warnings) lines.push(`  - ${w}`);
    lines.push('');
  }
  lines.push(`Old-time slots used: ${report.oldSlotsUsed} (of ${report.maxSlots} max)`);
  lines.push(`New-time slots used: ${report.newSlotsUsed} (of ${report.maxSlots} max)`);
  lines.push('');
  lines.push(
    `Background palette redraws required: ${report.backgroundPalettesChanged} of ${report.backgroundPalettesTotal}`
  );
  lines.push('');

  for (const g of report.groups) {
    if (g.isBackground) {
      const status = g.changed ? 'REDRAW NEEDED' : 'unchanged';
      lines.push(`${g.group} [${status}]`);
    } else {
      lines.push(`${g.group} [sprite -- reassignment is free]`);
    }
    lines.push(`  old: ${g.oldColors.join(' ')}   slots: [${g.oldSlots.join(',')}]`);
    lines.push(`  new: ${g.newColors.join(' ')}   slots: [${g.newSlots.join(',')}]`);
    lines.push('');
  }

  lines.push('Old-time IIgs palette slot table:');
  for (let slot = 0; slot < report.oldSlotTable.length; slot++) {
    const color = report.oldSlotTable[slot];
    lines.push(`  slot ${String(slot).padStart(2, ' ')}: ${color === null ? '(unused)' : color}`);
  }
  lines.push('');

  lines.push('New-time IIgs palette slot table:');
  for (let slot = 0; slot < report.newSlotTable.length; slot++) {
    const color = report.newSlotTable[slot];
    lines.push(`  slot ${String(slot).padStart(2, ' ')}: ${color === null ? '(unused)' : color}`);
  }

  return lines.join('\n') + '\n';
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const warnings = [];

  const oldGroups = parsePaletteFile(opts.oldFile);
  const newGroups = parsePaletteFile(opts.newFile);

  checkSharedColorConsistency(oldGroups, 'old', warnings);
  checkSharedColorConsistency(newGroups, 'new', warnings);
  const sharedOld = oldGroups.BG0[0];
  const sharedNew = newGroups.BG0[0];

  const result = optimize(oldGroups, newGroups, sharedOld, sharedNew);
  if (!result.feasible) {
    const oldDistinct = new Set(ALL_GROUPS.flatMap(g => oldGroups[g])).size;
    const newDistinct = new Set(ALL_GROUPS.flatMap(g => newGroups[g])).size;
    fail(
      `No valid slot assignment found even with no background groups required to stay unchanged. ` +
      `Old palette set needs ${oldDistinct} distinct colors, new palette set needs ${newDistinct} ` +
      `distinct colors -- one of these exceeds the ${MAX_SLOTS}-slot IIgs CLUT budget.`
    );
  }

  const report = buildReport(oldGroups, newGroups, result, warnings);

  const output = opts.format === 'json'
    ? JSON.stringify(report, null, 2) + '\n'
    : formatText(report);

  if (opts.output) {
    fs.writeFileSync(opts.output, output);
  } else {
    process.stdout.write(output);
  }
}

if (require.main === module) main();

module.exports = {
  parsePaletteFile, ALL_GROUPS, BG_GROUPS, SP_GROUPS, MAX_SLOTS,
  optimize, buildReport,
};

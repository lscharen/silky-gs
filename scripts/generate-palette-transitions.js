#!/usr/bin/env node
'use strict';

/**
 * generate-palette-transitions — turn an INI-style palette graph into a
 * Merlin32 source file that can load any of the named palettes into IIgs
 * palette 0 by id.
 *
 * Input: an INI file where each section header names a palette and each
 * non-comment line under it names another palette reachable from it, e.g.
 * (see src/games/zelda/palettes/transitions.txt):
 *
 *   [title_screen]
 *   intro
 *   select_screen
 *
 * Every palette name mentioned (as a section or a target) gets a numeric id
 * (a PAL_* equate, in order of first appearance) and a 16-slot IIgs CLUT
 * color table, built by de-duplicating the palette's 8 groups' (BG0-3,
 * SP0-3) 4 colors each down to at most 16 distinct NES color values -- the
 * shared/universal color (BG0's color 0) is always pinned to slot 0, since
 * the engine hardwires NES $3F00 to IIgs CLUT slot 0. A palette needing more
 * than 16 distinct colors is an error.
 *
 * A name with no matching palette file (e.g. a bootstrap pseudo-state like
 * "init") cannot be built into a table -- it is skipped with a warning and
 * does not get a numeric id. The graph's edges themselves are not encoded in
 * the output: UpdatePalette loads whichever palette Y names regardless of X,
 * so reachability is purely documentation at this point.
 *
 * Usage:
 *   node scripts/generate-palette-transitions.js <transitions-file> <palettes-dir> [options]
 *
 * Options:
 *   -o, --output <file>   Write Merlin32 source to <file> instead of stdout
 *   -h, --help            Show this help message
 */

const fs = require('fs');
const path = require('path');
const { parsePaletteFile, ALL_GROUPS, BG_GROUPS, MAX_SLOTS, optimize, buildReport } = require('./palette-transition.js');

const USAGE = `\
Usage: generate-palette-transitions <transitions-file> <palettes-dir> [options]

Options:
  -o, --output <file>   Write Merlin32 source to <file> instead of stdout
  -h, --help             Show this help message
`;

function fail(message) {
  process.stderr.write(`Error: ${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const opts = { transitionsFile: null, palettesDir: null, output: null };
  const positional = [];

  let i = 0;
  while (i < argv.length) {
    const arg = argv[i];
    switch (arg) {
      case '-h': case '--help':
        process.stdout.write(USAGE);
        process.exit(0);
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
    fail('Expected exactly two arguments: <transitions-file> <palettes-dir>');
  }
  [opts.transitionsFile, opts.palettesDir] = positional;
  return opts;
}

// Parse the INI-style transitions file into an ordered list of
// { from, tos: [to, ...] } entries, preserving file order. Blank lines and
// lines starting with ';' or '#' are ignored, same as palette-transition.js.
function parseTransitions(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const sections = [];
  let current = null;

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line === '' || line.startsWith(';') || line.startsWith('#')) continue;

    const header = line.match(/^\[([A-Za-z0-9_]+)\]$/);
    if (header) {
      current = { from: header[1], tos: [] };
      sections.push(current);
      continue;
    }

    const target = line.match(/^([A-Za-z0-9_]+)$/);
    if (!target) fail(`${filePath}: could not parse line: "${rawLine}"`);
    if (!current) fail(`${filePath}: target "${line}" appears before any [section] header`);
    current.tos.push(target[1]);
  }

  return sections;
}

function paletteFile(palettesDir, name) {
  return path.join(palettesDir, `${name}.txt`);
}

// Assign sequential, word-aligned ids (2, 4, 6, ...) to every palette name
// that has a backing file, in order of first appearance in the transitions
// file, so a palette's id can be used directly as a byte offset into
// PAL_ADDRS. Names without a file are reported via `warnings` and skipped.
function assignPaletteIds(sections, palettesDir, warnings) {
  const ids = new Map();
  let next = 2;

  function consider(name) {
    if (ids.has(name)) return;
    const file = paletteFile(palettesDir, name);
    if (!fs.existsSync(file)) {
      warnings.push(`skipping "${name}": no palette file (${file})`);
      return;
    }
    ids.set(name, next);
    next += 2;
  }

  for (const { from, tos } of sections) {
    consider(from);
    for (const to of tos) consider(to);
  }

  return ids;
}

// Build the 16-entry (slot -> NES color) table for one palette: the shared
// color pinned to slot 0, then every other distinct color across all 8
// groups in first-seen order, padded with $00 out to 16 entries.
function buildColorTable(name, groups, warnings) {
  const shared = groups.BG0[0];
  for (const g of ALL_GROUPS) {
    if (groups[g][0] !== shared) {
      warnings.push(
        `${name}: ${g}[0] = ${groups[g][0]} does not match BG0[0] = ${shared} ` +
        `(expected the universal/mirrored background color to be identical across all groups)`
      );
    }
  }

  const colors = [shared];
  for (const g of ALL_GROUPS) {
    for (let i = 1; i < 4; i++) {
      if (!colors.includes(groups[g][i])) colors.push(groups[g][i]);
    }
  }

  if (colors.length > MAX_SLOTS) {
    fail(`${name}: needs ${colors.length} distinct colors, exceeds the ${MAX_SLOTS}-slot IIgs CLUT budget`);
  }
  while (colors.length < MAX_SLOTS) colors.push('$00');

  return colors;
}

// The BG0-BG3 redraw bitmap (bit0=BG0 .. bit3=BG3) for a from -> to move,
// using palette-transition.js's joint old/new slot-assignment search so a
// BG palette is only flagged when its 4-color slot tuple actually differs.
function computeBgUpdateMask(fromGroups, toGroups) {
  const sharedOld = fromGroups.BG0[0];
  const sharedNew = toGroups.BG0[0];
  const result = optimize(fromGroups, toGroups, sharedOld, sharedNew);
  if (!result.feasible) {
    fail('no valid slot assignment found for a BG update mask computation -- this should not happen ' +
      'given each palette already fits within the CLUT budget on its own');
  }
  const report = buildReport(fromGroups, toGroups, result, []);

  let bits = 0;
  for (const g of report.groups) {
    if (!g.isBackground || !g.changed) continue;
    bits |= (1 << BG_GROUPS.indexOf(g.group));
  }
  return bits;
}

function maskLiteral(bits) {
  const padded = bits.toString(2).padStart(8, '0');
  return '%' + padded.slice(0, 4) + '_' + padded.slice(4);
}

function tableLabel(name) { return `PAL_${name.toUpperCase()}_TABLE`; }
function maskRowLabel(name) { return `BG_UPDATE_MASKS_${name.toUpperCase()}`; }

// The 32 NES palette RAM bytes ($3F00-$3F1F) for a palette, in hardware
// layout order: BG0-BG3 (4 colors each) then SP0-SP3 (4 colors each) --
// this is exactly ALL_GROUPS flattened, since that's the same group order.
function paletteRamBytes(groups) {
  return ALL_GROUPS.flatMap(g => groups[g]);
}

function* combinations(n, k, start = 0, combo = []) {
  if (combo.length === k) { yield combo.slice(); return; }
  for (let i = start; i <= n - (k - combo.length); i++) {
    combo.push(i);
    yield* combinations(n, k, i + 1, combo);
    combo.pop();
  }
}

function isDistinguishing(names, rows, offsets) {
  const seen = new Set();
  for (const name of names) {
    const key = offsets.map(o => rows.get(name)[o]).join(',');
    if (seen.has(key)) return false;
    seen.add(key);
  }
  return true;
}

// Greedy fallback for when brute force is capped out: repeatedly add the
// offset that splits the most still-ambiguous palettes apart, until every
// palette has a unique signature. Not guaranteed minimal, but always
// terminates (given no two palettes are byte-identical).
function greedySelect(names, rows) {
  let groups = [names.slice()];
  const selected = [];
  const used = new Set();

  while (groups.some(g => g.length > 1)) {
    let bestOffset = -1;
    let bestScore = -1;
    for (let o = 0; o < 32; o++) {
      if (used.has(o)) continue;
      let score = 0;
      for (const g of groups) {
        score += g.length <= 1 ? 1 : new Set(g.map(name => rows.get(name)[o])).size;
      }
      if (score > bestScore) { bestScore = score; bestOffset = o; }
    }
    selected.push(bestOffset);
    used.add(bestOffset);

    const next = [];
    for (const g of groups) {
      if (g.length <= 1) { next.push(g); continue; }
      const buckets = new Map();
      for (const name of g) {
        const v = rows.get(name)[bestOffset];
        if (!buckets.has(v)) buckets.set(v, []);
        buckets.get(v).push(name);
      }
      next.push(...buckets.values());
    }
    groups = next;
  }

  return selected.sort((a, b) => a - b);
}

const BRUTE_FORCE_MAX_K = 6;

// Find the smallest set of NES palette RAM offsets (0-31) whose values
// uniquely identify each palette. Exhaustively tries every offset count up
// to BRUTE_FORCE_MAX_K (guaranteeing a true minimum in the common case);
// falls back to a greedy (not necessarily minimal) selection beyond that.
function findMinimalOffsets(names, rows) {
  for (let i = 0; i < names.length; i++) {
    for (let j = i + 1; j < names.length; j++) {
      if (rows.get(names[i]).every((v, idx) => v === rows.get(names[j])[idx])) {
        fail(`palettes "${names[i]}" and "${names[j]}" have byte-identical NES palette RAM ` +
          '-- DetectNESPalette can never tell them apart');
      }
    }
  }

  for (let k = 1; k <= Math.min(32, BRUTE_FORCE_MAX_K); k++) {
    for (const combo of combinations(32, k)) {
      if (isDistinguishing(names, rows, combo)) return { offsets: combo, exact: true };
    }
  }

  return { offsets: greedySelect(names, rows), exact: false };
}

function ramAddr(offset) { return `PPU_MEM+$${(0x3F00 + offset).toString(16).toUpperCase()}`; }

function generateDetect(names, rows, warnings) {
  const { offsets, exact } = findMinimalOffsets(names, rows);
  if (!exact) {
    warnings.push(`DetectNESPalette: brute-force search capped at ${BRUTE_FORCE_MAX_K} bytes; used a greedy ` +
      `${offsets.length}-byte selection instead, which may not be the true minimum`);
  }

  const lines = [];
  lines.push('; DetectNESPalette');
  lines.push(`; Identifies the currently active NES palette from ${offsets.length} byte` +
    `${offsets.length === 1 ? '' : 's'} of NES palette RAM ($3F00-$3F1F) -- the`);
  lines.push(`; ${exact ? 'minimum' : 'fewest found'} needed to tell every known palette apart ` +
    '(see scripts/generate-palette-transitions.js).');
  lines.push('; Returns A = Y = PAL_* id, or 0 if the current palette RAM matches no known palette.');
  lines.push('; Y is left holding the id so it can be passed straight through as UpdatePalette\'s "to".');
  lines.push('            mx    %10');
  lines.push('DetectNESPalette');
  lines.push('            php');
  lines.push('            sep   #$20');

  // With a single discriminating offset, every palette's check re-tests the
  // same byte: load it once up front and just re-compare on each retry --
  // a failed compare falls through to the next palette's check with that
  // byte still in A. (With multiple offsets a failing compare can jump in
  // from a middle offset, leaving a *different* byte in A, so each offset
  // there is reloaded fresh; still correct, just not redundancy-free.)
  if (offsets.length === 1) lines.push(`            ldal  ${ramAddr(offsets[0])}`);

  for (let i = 0; i < names.length; i++) {
    const name = names[i];
    const nextLabel = i + 1 < names.length ? `:try_${names[i + 1]}` : ':notfound';
    if (i > 0) lines.push(`:try_${name}`);
    for (const offset of offsets) {
      if (offsets.length > 1) lines.push(`            ldal  ${ramAddr(offset)}`);
      lines.push(`            cmp   #${rows.get(name)[offset]}`);
      lines.push(`            bne   ${nextLabel}`);
    }
    lines.push(`            ldy   #PAL_${name.toUpperCase()}`);
    lines.push('            bra   :found');
  }

  lines.push(':notfound');
  lines.push('            ldy   #0');
  lines.push(':found');
  lines.push('            plp');
  lines.push('            tya');
  lines.push('            rts');
  lines.push('');
  lines.push('            mx    %00');
  lines.push('');

  return lines;
}

function generateSource(palettesDir, paletteIds, transitionsFilePath, warnings) {
  const relTransitions = path.relative(process.cwd(), transitionsFilePath).replace(/\\/g, '/');

  const lines = [];
  lines.push(`; Auto-generated by scripts/generate-palette-transitions.js from ${relTransitions}.`);
  lines.push(`; Do not edit by hand -- regenerate instead.`);
  lines.push(';');
  lines.push('; Requires (already implemented, see src/rom/rom_color.s):');
  lines.push(';   NES_ColorToIIgs -- A = NES color index -> A = IIgs 12-bit RGB');
  lines.push('; Targets IIgs palette 0 (SHR_PALETTES, see src/core/Defs.s).');
  lines.push('');

  lines.push('; Palette ids (first appearance order in the transitions file). Ids are');
  lines.push('; word-aligned so they can be used directly as a PAL_ADDRS byte offset.');
  for (const [name, id] of paletteIds) {
    lines.push(`PAL_${name.toUpperCase()} equ ${id}`);
  }
  lines.push('');

  const names = [...paletteIds.keys()];
  const groupsByName = new Map(names.map(name => [name, parsePaletteFile(paletteFile(palettesDir, name))]));
  const ramBytesByName = new Map(names.map(name => [name, paletteRamBytes(groupsByName.get(name))]));

  lines.push('            mx    %00');
  lines.push('');
  lines.push('; UpdatePalette');
  lines.push('; X = from palette id (PAL_*), Y = to palette id (PAL_*)');
  lines.push('; Loads all 16 IIgs CLUT slots of palette 0 from the target palette\'s table,');
  lines.push('; then tail-calls RefreshPPUAttributes with the from->to BG0-BG3 redraw bitmap.');
  lines.push('UpdatePalette');
  lines.push('            lda   BG_UPDATE_MASKS,x');
  lines.push('            pha');
  lines.push('            lda   (1,s),y');
  lines.push('            sta   1,s               ; stash the redraw mask, safe from X/Y reuse below');
  lines.push('            lda   PAL_ADDRS,y');
  lines.push('            pha');
  lines.push('            ldy   #0');
  lines.push(':loop       lda   (1,s),y');
  lines.push('            jsr   NES_ColorToIIgs');
  lines.push('            tyx');
  lines.push('            stal  SHR_PALETTES,x');
  lines.push('            iny');
  lines.push('            iny');
  lines.push(`            cpy   #${MAX_SLOTS * 2}      ; ${MAX_SLOTS} slots, 2 bytes/slot`);
  lines.push('            bcc   :loop');
  lines.push('            pla                     ; discard the color table pointer');
  lines.push('            pla                     ; A = redraw mask');
  lines.push('            jmp   RefreshPPUAttributes  ; tail call');
  lines.push('');

  lines.push(...generateDetect(names, ramBytesByName, warnings));

  lines.push('; id -> palette color table address. Entry 0 is unused (no palette has id 0).');
  lines.push('PAL_ADDRS');
  lines.push('            dw    $0000');
  for (const name of paletteIds.keys()) {
    lines.push(`            dw    ${tableLabel(name)}`);
  }
  lines.push('');

  lines.push('; from-id -> that palette\'s BG_UPDATE_MASKS_<name> row. Entry 0 is unused.');
  lines.push('BG_UPDATE_MASKS');
  lines.push('            dw    $0000');
  for (const name of paletteIds.keys()) {
    lines.push(`            dw    ${maskRowLabel(name)}`);
  }
  lines.push('');

  for (const name of names) {
    const colors = buildColorTable(name, groupsByName.get(name), warnings);
    lines.push(`; ${name}`);
    lines.push(tableLabel(name));
    lines.push(`            dw    ${colors.join(',')}`);
    lines.push('');
  }

  lines.push('; BG0-BG3 redraw bitmap for each from -> to move (bit0=BG0 .. bit3=BG3).');
  lines.push('; Entry 0 in each row is unused; a from -> from move is always $0000.');
  for (const from of names) {
    lines.push(`; from ${from}`);
    lines.push(maskRowLabel(from));
    lines.push('            dw    $0000');
    for (const to of names) {
      const bits = from === to ? 0 : computeBgUpdateMask(groupsByName.get(from), groupsByName.get(to));
      lines.push(`            dw    ${maskLiteral(bits)}   ; to ${to}`);
    }
    lines.push('');
  }

  if (warnings.length) {
    lines.unshift('');
    lines.unshift(...warnings.map(w => `; WARNING: ${w}`));
    lines.unshift('; Warnings from generation:');
  }

  return lines.join('\n') + '\n';
}

function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (!fs.existsSync(opts.transitionsFile)) fail(`transitions file not found: ${opts.transitionsFile}`);
  if (!fs.existsSync(opts.palettesDir) || !fs.statSync(opts.palettesDir).isDirectory()) {
    fail(`palettes directory not found: ${opts.palettesDir}`);
  }

  const sections = parseTransitions(opts.transitionsFile);
  const warnings = [];
  const paletteIds = assignPaletteIds(sections, opts.palettesDir, warnings);
  const output = generateSource(opts.palettesDir, paletteIds, opts.transitionsFile, warnings);

  if (opts.output) {
    fs.writeFileSync(opts.output, output);
  } else {
    process.stdout.write(output);
  }
}

main();

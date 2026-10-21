#!/usr/bin/env node
'use strict';

/**
 * code-signature.js — prove that moving code between segments left the instructions alone.
 *
 * Moving a routine to another bank changes the addresses in its operands, but it must not change its
 * instructions: the same opcodes (so the same addressing modes and register widths) give the same
 * cycle counts, page crossings by indexed reads aside.  This saves, for every routine of a build, its
 * instruction stream (opcode and length of each instruction), and compares a later build with it.
 *
 * Routines are the code between global labels (Merlin32's generated ozunid_ labels are not
 * boundaries), named file:label, so a routine is found again in whichever segment it moved to.  A
 * label that occurs more than once (a file put into several segments) gets #2, #3 ... in listing
 * order.
 *
 * Usage:
 *   node scripts/code-signature.js save    <gameDir> <linkFile> <out.json>      [--segments MAIN,ENGINE]
 *   node scripts/code-signature.js compare <gameDir> <linkFile> <baseline.json> [--segments MAIN,ENGINE] [--legacy]
 *
 * compare lists the routines whose instructions changed (with a diff), and the ones added or removed.
 * The default segments are the engine's (MAIN, ENGINE); --segments all takes every segment.
 */

const fs = require('fs');
const path = require('path');
const { listingFiles, parseListing } = require('./lib/merlinListing.js');

const DEFAULT_SEGMENTS = ['MAIN', 'ENGINE'];
const MAX_DIFF_LINES = 24;

// A label declared with ENT (type Global) is a boundary too, except in legacy mode (for the baselines
// saved before ENT labels were boundaries), where it is one only in a file the baseline doesn't have.
function isBoundary(r, legacyFiles) {
  if (!r.label || /^[:\]]/.test(r.label) || /^ozunid_/.test(r.label)) return false;
  if (r.type === 'Global') return !legacyFiles || !legacyFiles.has(r.file);
  return r.type === 'Code' || r.type === 'Empty' || r.type === 'Data';
}

/**
 * { key: { segment, file, label, ins: ['AD/3', ...], src: ['lda foo', ...] } } for the routines that
 * have code.
 */
function collect(gameDir, linkFile, segments, legacyFiles) {
  const routines = {};
  const seen = {};
  for (const seg of listingFiles(gameDir, linkFile)) {
    if (segments !== 'all' && !segments.includes(seg.name)) continue;
    if (!seg.file) throw new Error(`${linkFile}: no listing for segment ${seg.name}`);
    let cur = null;
    for (const r of parseListing(seg.file)) {
      if (isBoundary(r, legacyFiles)) {
        const base = `${r.file}:${r.label}`;
        seen[base] = (seen[base] || 0) + 1;
        const key = seen[base] > 1 ? `${base}#${seen[base]}` : base;
        cur = { segment: seg.name, file: r.file, label: r.label, ins: [], src: [] };
        routines[key] = cur;
      }
      if (cur && r.type === 'Code' && r.size > 0 && r.bytes.length) {
        cur.ins.push(`${r.bytes[0].toString(16).toUpperCase().padStart(2, '0')}/${r.size}`);
        cur.src.push(`${r.op} ${r.operand}`.trim());
      }
    }
  }
  for (const k of Object.keys(routines)) if (!routines[k].ins.length) delete routines[k];
  return routines;
}

// Merlin32 lists a local label (:name) as _name when the name is unique in its segment, and as an
// ozunid_ label when it isn't, so whether one shows up as a label depends on the rest of the segment.
// Local labels are not boundaries: a routine listed under one is folded into the routine before it
// (keys are in listing order).  A label _name is local when a source file defines :name and none
// defines _name (code moves between files).  The sources: the game's directory, then src/.
function sourceIndex(gameDir) {
  const index = {};
  const walk = (dir, skipGames) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) { if (!(skipGames && e.name === 'games') && e.name !== 'node_modules') walk(p, false); }
      else if (/\.s$/i.test(e.name) && !index[e.name]) index[e.name] = p;
    }
  };
  walk(gameDir, false);
  walk(path.join(__dirname, '..', 'src'), true);
  return index;
}

function foldLocals(routines, index) {
  if (!index.locals) {
    const locals = new Set(), globals = new Set();
    for (const p of Object.values(index)) {
      for (const l of fs.readFileSync(p, 'latin1').split(/\r?\n/)) {
        const m = l.match(/^([:A-Za-z_][A-Za-z0-9_]*)/);
        if (m) (m[1][0] === ':' ? locals : globals).add(m[1][0] === ':' ? '_' + m[1].slice(1) : m[1]);
      }
    }
    Object.defineProperty(index, 'locals', { value: new Set([...locals].filter((l) => !globals.has(l))) });
  }
  const isLocal = (r) => index.locals.has(r.label);
  const out = {};
  let prev = null;
  for (const [k, r] of Object.entries(routines)) {
    if (prev && prev.file === r.file && prev.segment === r.segment && isLocal(r)) {
      prev.ins = prev.ins.concat(r.ins);
      prev.src = prev.src.concat(r.src);
      continue;
    }
    prev = out[k] = { ...r };
  }
  return out;
}

// Line diff of two instruction lists (LCS); returns lines prefixed with ' ', '-' or '+'.
function diff(a, b, aSrc, bSrc) {
  const n = a.length, m = b.length;
  const dp = Array.from({ length: n + 1 }, () => new Uint32Array(m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  const out = [];
  let i = 0, j = 0;
  while (i < n || j < m) {
    if (i < n && j < m && a[i] === b[j]) { out.push(`  ${a[i].padEnd(5)} ${bSrc[j]}`); i++; j++; }
    else if (j < m && (i >= n || dp[i][j + 1] >= dp[i + 1][j])) { out.push(`+ ${b[j].padEnd(5)} ${bSrc[j]}`); j++; }
    else { out.push(`- ${a[i].padEnd(5)} ${aSrc[i]}`); i++; }
  }
  // Keep the changed lines with one line of context around them.
  const keep = out.map((l, k) => l[0] !== ' ' || (out[k - 1] && out[k - 1][0] !== ' ') || (out[k + 1] && out[k + 1][0] !== ' '));
  return out.filter((_, k) => keep[k]);
}

// A routine whose file changed (moved to another source file) is matched by its label, when exactly
// one unmatched routine on each side has it.
function matchMovedFiles(base, cur) {
  const pairs = {};
  const byLabel = (obj, keys) => {
    const m = {};
    for (const k of keys) (m[obj[k].label] = m[obj[k].label] || []).push(k);
    return m;
  };
  const gone = byLabel(base, Object.keys(base).filter((k) => !cur[k]));
  const fresh = byLabel(cur, Object.keys(cur).filter((k) => !base[k]));
  for (const [label, ks] of Object.entries(gone)) {
    if (ks.length === 1 && fresh[label] && fresh[label].length === 1) pairs[ks[0]] = fresh[label][0];
  }
  return pairs;
}

function compare(base, cur) {
  const changed = [], moved = [], refiled = [];
  let same = 0;
  const pairs = matchMovedFiles(base, cur);
  const matched = new Set(Object.values(pairs));
  for (const [k, b] of Object.entries(base)) {
    const ck = cur[k] ? k : pairs[k];
    if (!ck) continue;
    const c = cur[ck];
    if (ck !== k) refiled.push(`${k} -> ${ck}`);
    if (b.ins.join() === c.ins.join()) same++;
    else changed.push([k, ck]);
    if (b.segment !== c.segment) moved.push(`${k} (${b.segment} -> ${c.segment})`);
  }
  const removed = Object.keys(base).filter((k) => !cur[k] && !pairs[k]);
  const added = Object.keys(cur).filter((k) => !base[k] && !matched.has(k));

  for (const [k, ck] of changed) {
    console.log(`\nchanged: ${ck} [${cur[ck].segment}]`);
    const d = diff(base[k].ins, cur[ck].ins, base[k].src, cur[ck].src);
    for (const l of d.slice(0, MAX_DIFF_LINES)) console.log(`    ${l}`);
    if (d.length > MAX_DIFF_LINES) console.log(`    ... ${d.length - MAX_DIFF_LINES} more`);
  }
  if (removed.length) console.log(`\nremoved (${removed.length}): ${removed.join(', ')}`);
  if (added.length) console.log(`\nadded (${added.length}): ${added.join(', ')}`);
  if (refiled.length) console.log(`\nmoved to another file (${refiled.length}): ${refiled.join(', ')}`);
  if (moved.length) console.log(`\nmoved to another segment (${moved.length}): ${moved.join(', ')}`);
  console.log(`\n${same} routine(s) identical, ${changed.length} changed, ${removed.length} removed, ${added.length} added`);
  return changed.length + removed.length + added.length;
}

if (require.main === module) {
  const args = process.argv.slice(2);
  let segments = DEFAULT_SEGMENTS;
  const li = args.indexOf('--legacy');
  const legacy = li >= 0;
  if (legacy) args.splice(li, 1);
  const i = args.indexOf('--segments');
  if (i >= 0) { segments = args[i + 1] === 'all' ? 'all' : args[i + 1].split(','); args.splice(i, 2); }
  const [cmd, gameDir, linkFile, file] = args;
  if (!['save', 'compare'].includes(cmd) || !file) {
    console.error('Usage: code-signature save|compare <gameDir> <linkFile> <json> [--segments MAIN,ENGINE|all]');
    process.exit(2);
  }
  const base = cmd === 'compare' ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
  const legacyFiles = legacy && base ? new Set(Object.values(base).map((r) => r.file)) : null;
  const routines = collect(path.resolve(gameDir), linkFile, segments, legacyFiles);
  if (cmd === 'save') {
    fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(routines));
    const n = Object.values(routines).reduce((s, r) => s + r.ins.length, 0);
    console.log(`saved ${Object.keys(routines).length} routines (${n} instructions) to ${file}`);
  } else {
    const index = sourceIndex(path.resolve(gameDir));
    const diffs = compare(foldLocals(base, index), foldLocals(routines, index));
    process.exit(diffs ? 1 : 0);
  }
}

module.exports = { collect, compare };

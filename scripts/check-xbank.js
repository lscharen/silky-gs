#!/usr/bin/env node
'use strict';

/**
 * check-xbank.js — find 16-bit references into another segment (another bank) in the engine segments.
 *
 * Every segment is loaded into a bank of its own, so a reference to a symbol of another segment
 * (imported with EXT) is only right when it is long: jsl / jml, ldal / stal ..., or a bank byte (^).
 * Merlin32 and the linker take a 16-bit one without complaint, and it silently addresses the wrong
 * bank.  An address plus a constant in a 16-bit operand is worse: the OMF loader has been seen to drop
 * the constant (see MERLIN32_OMF_EXT_OFFSET_BUG.md).
 *
 * The listing marks those references "E 2" in its Reloc column.  This reports them all as errors:
 *
 *   - jsr / jmp to another segment (use jsl / jml, through a long entry point that ends with rtl)
 *   - any other 16-bit reference, unless the symbol is in ALLOWED below
 *   - a 16-bit reference to an ALLOWED symbol plus or minus a constant
 *   - a symbol both imported (EXT) and exported (ENT) by one segment (see below)
 *   - ENT / EXT in the operand form ("ENT a,b"): only "label ENT" / "label EXT" is reliable
 *
 * Only the engine segments are checked (MAIN and ENGINE): the converted NES ROM banks address each
 * other's tables with 16-bit addresses by design.
 *
 * Usage:
 *   node scripts/check-xbank.js <gameDir> <linkFile> [--segments MAIN,ENGINE]
 *
 * assembleGame (scripts/lib/nromBuild.js) runs it after every build.
 */

const fs = require('fs');
const path = require('path');
const { listingFiles, parseListing } = require('./lib/merlinListing.js');

const DEFAULT_SEGMENTS = ['MAIN', 'ENGINE'];

// Symbols of other segments that are meant to be used as 16-bit addresses: the code sets the bank
// itself.
const ALLOWED = [
  { re: /^lite_base_[12]$/, why: 'an offset in a blitter bank; the code supplies the bank' },
  { re: /^(y|tile)_exclude$/, why: 'read by the OAM scan with DBR = the ROM bank that holds it' },
  { re: /_SWIZZLE$/, why: 'an offset in the PALDATA bank; the code supplies the bank' },
];

// jsr abs, jmp abs, jmp (abs), jmp (abs,x), jsr (abs,x)
const JUMPS = new Set([0x20, 0x4c, 0x6c, 0x7c, 0xfc]);

function isAllowed(sym) {
  return ALLOWED.some((a) => a.re.test(sym));
}

/**
 * Check the listings of a build.  Returns { errors: [{ segment, file, line, src, why }], checked }.
 */
function checkXBank(gameDir, linkFile, { segments = DEFAULT_SEGMENTS } = {}) {
  const errors = [];
  const checked = [];
  for (const seg of listingFiles(gameDir, linkFile)) {
    if (!segments.includes(seg.name)) continue;
    if (!seg.file) throw new Error(`${linkFile}: no listing for segment ${seg.name}`);
    checked.push(seg.name);
    const rows = parseListing(seg.file);
    const ext = new Set(rows.filter((r) => r.type === 'External').map((r) => r.label));

    // ENT and EXT must be written "label ENT" / "label EXT".  The operand form (ENT a,b) isn't
    // handled reliably: an ENT list is applied even inside a skipped DO block, and so on.
    const srcCache = {};
    const srcLine = (r) => {
      if (!srcCache[r.path]) srcCache[r.path] = fs.existsSync(r.path) ? fs.readFileSync(r.path, 'latin1').split(/\r?\n/) : [];
      return srcCache[r.path][r.line - 1] || '';
    };
    const flagged = new Set();
    for (const r of rows) {
      if (r.type !== 'Global' && r.type !== 'External' && r.type !== 'Empty') continue;  // (an operand-form ENT line is listed as Empty)
      const key = `${r.path}:${r.line}`;
      if (flagged.has(key) || !/^\s+(ENT|EXT)\b/i.test(srcLine(r))) continue;
      flagged.add(key);
      errors.push({ segment: seg.name, file: r.file, line: r.line, src: srcLine(r).trim(),
        why: 'ENT / EXT in the operand form: write "label ENT" at the definition, "label EXT" on a line of its own' });
    }

    // An ENT operand list (ENT a,b) is applied even inside a skipped DO block, and an EXT of a name
    // the same source ENTs that way becomes a label of this segment: the references link locally,
    // with no error.  The listing then shows the name as both Global and External.
    // (It lists such an EXT as a Global row, named, then an unnamed External row from the same line.)
    rows.forEach((r, i) => {
      const next = rows[i + 1];
      const pair = next && next.type === 'External' && !next.label && next.line === r.line && next.file === r.file;
      if (r.type === 'Global' && (ext.has(r.label) || pair)) {
        errors.push({ segment: seg.name, file: r.file, line: r.line, src: r.src.replace(/\s+/g, ' '),
          why: `${r.label} is imported (EXT) and exported (ENT) by this segment: an ENT operand list naming it, even in a skipped DO block, makes it local (use the label form, "${r.label} ENT", at its definition)` });
      }
    });

    for (const r of rows) {
      if (!/^E 2$/.test(r.reloc)) continue; // (shifted parts, e.g. "E 1 >>16", are bank bytes)
      const syms = r.operand.split(/[^A-Za-z0-9_]+/).filter((t) => ext.has(t));
      const where = { segment: seg.name, file: r.file, line: r.line, src: r.src.replace(/\s+/g, ' ') };
      if (r.type === 'Code' && JUMPS.has(r.bytes[0])) {
        errors.push({ ...where, why: `16-bit ${r.op} into another segment (use jsl / jml)` });
      } else if (syms.length === 0 || !syms.every(isAllowed)) {
        errors.push({ ...where, why: `16-bit reference to ${syms.join(', ') || 'a symbol'} in another segment (use a long operand)` });
      } else if (/[-+]/.test(r.operand.replace(/^#/, ''))) {
        errors.push({ ...where, why: 'a 16-bit address in another segment plus a constant (the loader can drop the constant)' });
      }
    }
  }
  return { errors, checked };
}

function report({ errors, checked }, label) {
  for (const e of errors) console.error(`  ${e.segment} ${e.file}:${e.line}: ${e.why}\n      ${e.src}`);
  console.log(`check-xbank ${label}: ${checked.join(', ') || 'no segments'} -- ${errors.length} error(s)`);
}

if (require.main === module) {
  const args = process.argv.slice(2);
  let segments = DEFAULT_SEGMENTS;
  const i = args.indexOf('--segments');
  if (i >= 0) { segments = args[i + 1].split(','); args.splice(i, 2); }
  if (args.length !== 2) {
    console.error('Usage: check-xbank <gameDir> <linkFile> [--segments MAIN,ENGINE]');
    process.exit(2);
  }
  const result = checkXBank(path.resolve(args[0]), args[1], { segments });
  report(result, args[1]);
  process.exit(result.errors.length ? 1 : 0);
}

module.exports = { checkXBank, report };

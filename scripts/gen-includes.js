#!/usr/bin/env node
'use strict';

/**
 * gen-includes.js — Merlin32 AUTOINCLUDE block manager
 *
 * Merlin32 only allows PUT directives in the top-level source file.  This
 * script lets you write a marker comment instead of listing every file by
 * hand.  It then fills in (and keeps up-to-date) the PUT lines between the
 * markers.
 *
 * Syntax in a Main.s / Master.s file:
 *
 *   ; AUTOINCLUDE:BEGIN ../../ppu
 *               put   ../../ppu/ppu_macros.s
 *               put   ../../ppu/ppu_regs.s
 *               ... (managed – do not edit by hand)
 *   ; AUTOINCLUDE:END
 *
 * File ordering / directives:
 *   By default the directory is scanned for *.s and *.bin files (alphabetical
 *   order).  *.s files emit PUT; *.bin files emit PUTBIN.
 *
 *   To take full control, add a plain-text file named "_module.txt".  When
 *   present it is the complete and exclusive list — no other files are added.
 *   Each non-blank, non-comment line is either:
 *     filename.s          — emits PUT   (extension-based default)
 *     filename.bin        — emits PUTBIN (extension-based default)
 *     putbin:filename     — emits PUTBIN regardless of extension
 *     put:filename        — emits PUT   regardless of extension
 *
 * Usage:
 *   node scripts/gen-includes.js              # update all Main.s / Master.s
 *   node scripts/gen-includes.js path/to/Main.s ...
 */

const fs   = require('fs');
const path = require('path');

const BEGIN_RE = /^(\s*); AUTOINCLUDE:BEGIN\s+(\S+)\s*$/;
const END_RE   = /^(\s*); AUTOINCLUDE:END\s*$/;

// ---------------------------------------------------------------------------
// Build the ordered list of .s files for a directory
// ---------------------------------------------------------------------------
function filesForDir(absDir, relDir) {
    if (!fs.existsSync(absDir)) {
        throw new Error(`AUTOINCLUDE directory not found: ${absDir}`);
    }

    // Resolve a filename + optional directive prefix to a { file, directive } pair
    function resolve(entry) {
        if (entry.startsWith('putbin:')) return { file: entry.slice(7), directive: 'putbin' };
        if (entry.startsWith('put:'))    return { file: entry.slice(4),  directive: 'put'   };
        return { file: entry, directive: entry.endsWith('.s') ? 'put' : 'putbin' };
    }

    const moduleFile = path.join(absDir, '_module.txt');
    let entries;
    if (fs.existsSync(moduleFile)) {
        entries = fs.readFileSync(moduleFile, 'utf8')
            .split(/\r?\n/)
            .map(l => l.trim())
            .filter(l => l && !l.startsWith('#'))
            .map(resolve);
    } else {
        entries = fs.readdirSync(absDir)
            .filter(f => !f.startsWith('_') && (f.endsWith('.s') || f.endsWith('.bin')))
            .sort()
            .map(resolve);
    }

    return entries.map(({ file, directive }) => {
        const pad = directive === 'putbin' ? 'putbin' : 'put   ';
        return `            ${pad} ${relDir}/${file}`;
    });
}

// ---------------------------------------------------------------------------
// Process a single assembly file
// ---------------------------------------------------------------------------
function processFile(filePath) {
    const raw = fs.readFileSync(filePath, 'utf8');
    const lineEnding = raw.includes('\r\n') ? '\r\n' : '\n';
    const lines = raw.split(/\r?\n/);
    const fileDir = path.dirname(path.resolve(filePath));

    const output = [];
    let changed = false;
    let i = 0;

    while (i < lines.length) {
        const line = lines[i];
        const beginMatch = line.match(BEGIN_RE);

        if (beginMatch) {
            output.push(line);                      // keep BEGIN marker
            const relDir  = beginMatch[2];
            const absDir  = path.resolve(fileDir, relDir);
            const newPuts = filesForDir(absDir, relDir);

            // Consume old puts up to END marker
            i++;
            const oldPuts = [];
            while (i < lines.length && !lines[i].match(END_RE)) {
                oldPuts.push(lines[i]);
                i++;
            }

            output.push(...newPuts);

            if (oldPuts.join('\n') !== newPuts.join('\n')) {
                changed = true;
            }

            if (i < lines.length) {
                output.push(lines[i]);              // keep END marker
            }
        } else {
            output.push(line);
        }
        i++;
    }

    if (changed) {
        fs.writeFileSync(filePath, output.join(lineEnding));
        console.log(`  updated  ${filePath}`);
    } else {
        console.log(`  no change ${filePath}`);
    }

    return changed;
}

// ---------------------------------------------------------------------------
// Auto-discover all Main.s / Master.s files under src/games/
// ---------------------------------------------------------------------------
function findAssemblyMains(dir) {
    const results = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            results.push(...findAssemblyMains(full));
        } else if (/^(Main|Master)\.s$/.test(entry.name)) {
            results.push(full);
        }
    }
    return results;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
const root = path.join(__dirname, '..');
let targets = process.argv.slice(2);

if (targets.length === 0) {
    targets = findAssemblyMains(path.join(root, 'src', 'games'));
}

if (targets.length === 0) {
    console.error('No assembly files found.');
    process.exit(1);
}

console.log(`Processing ${targets.length} file(s)…`);
let anyChanged = false;
for (const f of targets) {
    try {
        anyChanged = processFile(f) || anyChanged;
    } catch (err) {
        console.error(`  ERROR in ${f}: ${err.message}`);
        process.exit(1);
    }
}
console.log(anyChanged ? 'Done — files were updated.' : 'Done — nothing changed.');

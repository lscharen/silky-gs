#!/usr/bin/env node
'use strict';

/**
 * gen-includes — Merlin32 mput block manager
 *
 * An `mput` macro call in an assembly file tells this script to expand a
 * directory (or single file) into a flat list of PUT/PUTBIN directives and
 * inject that list immediately after the marker, surrounded by AUTOINC guards.
 *
 * Syntax in any assembly file:
 *
 *             mput ../../ppu
 * ; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
 *             put   ../../ppu/ppu_macros.s
 *             put   ../../ppu/ppu_regs.s
 *             ...
 * ; AUTOINC:END
 *
 * The given master/link file is the ONLY file that is ever written.  Files
 * referenced through put or mput directives are read for traversal only and
 * are never modified.
 *
 * Recursion within a mput expansion: when expanding directory D, each .s
 * file found in D is scanned for nested mput markers.  Any paths those
 * markers reference are also expanded and appended to the parent's generated
 * block — those child files are read-only and never written.
 *
 * File ordering:
 *   By default the directory is scanned for *.s and *.bin files, sorted
 *   alphabetically.  *.s files emit PUT; *.bin files emit PUTBIN.
 *
 *   To take full control of ordering, add a plain-text file named
 *   "_module.txt" in the directory.  When present it is the complete and
 *   exclusive list — no other files are added.  Each non-blank,
 *   non-comment (#) line is either:
 *     filename.s          — emits PUT   (extension-based default)
 *     filename.bin        — emits PUTBIN (extension-based default)
 *     putbin:filename     — emits PUTBIN regardless of extension
 *     put:filename        — emits PUT   regardless of extension
 */

const fs   = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const MPUT_RE          = /^\s*mput\s+(\S+)\s*$/;
const AUTOINC_BEGIN_RE = /^; AUTOINC:BEGIN/;
const AUTOINC_END_RE   = /^; AUTOINC:END/;
const PUT_LINE_RE      = /^\s*put(?:bin)?\s+(\S+)\s*$/i;

const BEGIN_GUARD = '; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)';
const END_GUARD   = '; AUTOINC:END';

// ---------------------------------------------------------------------------
// Runtime options (populated from CLI args before any processing begins)
// ---------------------------------------------------------------------------
const opts = {
    verbose: false,
    dryRun:  false,
    output:  null,   // output file path for the primary target, or null
};

function verbose(msg) {
    if (opts.verbose) console.log(`  [verbose] ${msg}`);
}

// ---------------------------------------------------------------------------
// Help text
// ---------------------------------------------------------------------------
const USAGE = `\
Usage: gen-includes [options] <master-file> [master-file ...]

Update AUTOINC blocks managed by mput markers in Merlin32 assembly files.
The master/link file is the ONLY file ever written.  Files referenced through
put or mput directives are read for content collection only and never modified.

Arguments:
  master-file          Merlin32 Master or Link .s file to process (required).
                       Multiple files may be listed to process them in sequence.

Options:
  -h, --help           Show this help message and exit.
  -v, --verbose        Log every action: file opens, paths resolved,
                       cache hits, writes, etc.
  -n, --dry-run        Compute what would change but do not write any files.
                       Exits with code 1 if any file would be updated.
  -o, --output <file>  Write the modified content to <file> instead of
                       updating the source file in place.  Cannot be used
                       with multiple target files.

Examples:
  gen-includes src/games/smb/Main.s
  gen-includes --dry-run src/games/smb/Main.s
  gen-includes --verbose --output /tmp/Main.out.s src/games/smb/Main.s
  gen-includes src/games/smb/Main.s src/games/dk/Main.s
`;

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------
function parseArgs(argv) {
    const files = [];
    let i = 0;
    while (i < argv.length) {
        const arg = argv[i];
        switch (arg) {
            case '-h': case '--help':
                console.log(USAGE);
                process.exit(0);
                break;
            case '-v': case '--verbose':
                opts.verbose = true;
                break;
            case '-n': case '--dry-run':
                opts.dryRun = true;
                break;
            case '-o': case '--output':
                i++;
                if (i >= argv.length) {
                    console.error('error: --output requires a file argument');
                    process.exit(1);
                }
                opts.output = argv[i];
                break;
            default:
                if (arg.startsWith('--output=')) {
                    opts.output = arg.slice('--output='.length);
                } else if (arg.startsWith('-')) {
                    console.error(`error: unknown option: ${arg}`);
                    console.error('Run with --help for usage.');
                    process.exit(1);
                } else {
                    files.push(arg);
                }
        }
        i++;
    }
    return files;
}

// ---------------------------------------------------------------------------
// Build the ordered list of { line, absPath } for a single directory
// ---------------------------------------------------------------------------
function filesForDir(absDir, relDir) {
    if (!fs.existsSync(absDir)) {
        throw new Error(`mput target not found: ${absDir}`);
    }

    function resolve(entry) {
        if (entry.startsWith('putbin:')) return { file: entry.slice(7), directive: 'putbin' };
        if (entry.startsWith('put:'))    return { file: entry.slice(4),  directive: 'put'   };
        return { file: entry, directive: entry.endsWith('.s') ? 'put' : 'putbin' };
    }

    const moduleFile = path.join(absDir, '_module.txt');
    let entries;
    if (fs.existsSync(moduleFile)) {
        verbose(`reading order from ${moduleFile}`);
        entries = fs.readFileSync(moduleFile, 'utf8')
            .split(/\r?\n/)
            .map(l => l.trim())
            .filter(l => l && !l.startsWith('#'))
            .map(resolve);
    } else {
        verbose(`no _module.txt in ${absDir}, using alphabetical order`);
        entries = fs.readdirSync(absDir)
            .filter(f => !f.startsWith('_') && (f.endsWith('.s') || f.endsWith('.bin')))
            .sort()
            .map(resolve);
    }

    return entries.map(({ file, directive }) => {
        const pad = directive === 'putbin' ? 'putbin' : 'put   ';
        const ref = relDir ? `${relDir}/${file}` : file;
        verbose(`  found: ${ref}`);
        return {
            line:    `            ${pad} ${ref}`,
            absPath: path.join(absDir, file),
        };
    });
}

// ---------------------------------------------------------------------------
// Recursively collect all put lines for a mput expansion.
//
// absTarget     — the directory or file path from the mput argument
// containingDir — directory of the file that owns the mput marker;
//                 used to build relative paths in the generated put lines
// seen          — Set of resolved absolute paths already visited (cycle guard)
//
// Single-file target: returns a one-element list.
// Directory target: lists all files (respecting _module.txt), then scans each
//   child .s file for nested mput markers and recursively expands them,
//   appending the results.  Child files themselves are NOT modified.
// ---------------------------------------------------------------------------
function filesForDirRecursive(absTarget, containingDir, seen) {
    if (!seen) seen = new Set();

    const key = path.resolve(absTarget);
    if (seen.has(key)) {
        verbose(`already visited ${absTarget}, skipping`);
        return [];
    }
    seen.add(key);

    // Single-file case
    const stat = fs.existsSync(absTarget) ? fs.statSync(absTarget) : null;
    if (stat && stat.isFile()) {
        const relPath  = path.relative(containingDir, absTarget).replace(/\\/g, '/');
        const pad      = absTarget.endsWith('.s') ? 'put   ' : 'putbin';
        verbose(`mput resolved to single file: ${relPath}`);
        return [`            ${pad} ${relPath}`];
    }

    verbose(`expanding directory: ${absTarget}`);
    const relDir = path.relative(containingDir, absTarget).replace(/\\/g, '/');
    const entries = filesForDir(absTarget, relDir);

    const result    = [];
    const seenLines = new Set();   // deduplication within this expansion

    for (const { line, absPath } of entries) {
        if (!seenLines.has(line)) {
            result.push(line);
            seenLines.add(line);
        } else {
            verbose(`  duplicate line, skipping: ${line.trim()}`);
        }

        // Scan child .s files for nested mput markers without modifying them
        if (absPath.endsWith('.s') && fs.existsSync(absPath)) {
            verbose(`  scanning child for nested mput: ${absPath}`);
            const childLines = fs.readFileSync(absPath, 'utf8').split(/\r?\n/);
            for (const childLine of childLines) {
                const m = childLine.match(MPUT_RE);
                if (m) {
                    verbose(`  found nested mput ${m[1]} in ${path.basename(absPath)}`);
                    const nestedAbsTarget = path.resolve(path.dirname(absPath), m[1]);
                    const nestedEntries   = filesForDirRecursive(nestedAbsTarget, containingDir, seen);
                    for (const nl of nestedEntries) {
                        if (!seenLines.has(nl)) {
                            result.push(nl);
                            seenLines.add(nl);
                        } else {
                            verbose(`  nested duplicate, skipping: ${nl.trim()}`);
                        }
                    }
                }
            }
        }
    }

    return result;
}

// ---------------------------------------------------------------------------
// Process a single assembly file: expand all mput blocks in that file and
// write the result.  This is the ONLY file that is ever written — the script
// never modifies files discovered through put or mput directives.
//
// outputPath — when set, write modified content to outputPath instead of
//              updating the source file in place.
// ---------------------------------------------------------------------------
function processFile(filePath, outputPath) {
    const absPath = path.resolve(filePath);

    if (!fs.existsSync(absPath)) {
        verbose(`file not found, skipping: ${absPath}`);
        return false;
    }

    verbose(`opening: ${absPath}`);
    const raw        = fs.readFileSync(absPath, 'utf8');
    const lineEnding = raw.includes('\r\n') ? '\r\n' : '\n';
    const lines      = raw.split(/\r?\n/);
    const fileDir    = path.dirname(absPath);

    const output = [];
    let changed  = false;
    let i        = 0;

    while (i < lines.length) {
        const line      = lines[i];
        const mputMatch = line.match(MPUT_RE);

        if (mputMatch) {
            output.push(line);

            const absTarget = path.resolve(fileDir, mputMatch[1]);
            verbose(`found mput ${mputMatch[1]} → ${absTarget}`);
            const newPuts = filesForDirRecursive(absTarget, fileDir);

            // Consume any existing AUTOINC block immediately following
            const oldPuts = [];
            let nextI     = i + 1;
            if (nextI < lines.length && lines[nextI].match(AUTOINC_BEGIN_RE)) {
                nextI++;
                while (nextI < lines.length && !lines[nextI].match(AUTOINC_END_RE)) {
                    oldPuts.push(lines[nextI]);
                    nextI++;
                }
                if (nextI < lines.length) nextI++;
            }

            output.push(BEGIN_GUARD);
            output.push(...newPuts);
            output.push(END_GUARD);

            if (oldPuts.join('\n') !== newPuts.join('\n')) {
                verbose(`mput block changed (${oldPuts.length} → ${newPuts.length} lines)`);
                changed = true;
            } else {
                verbose(`mput block unchanged (${newPuts.length} lines)`);
            }

            i = nextI;
        } else {
            output.push(line);
            i++;
        }
    }

    const dest = outputPath || absPath;

    if (changed) {
        if (opts.dryRun) {
            console.log(`  would update  ${filePath}`);
        } else if (outputPath) {
            verbose(`writing output to: ${outputPath}`);
            fs.writeFileSync(dest, output.join(lineEnding));
            console.log(`  wrote output  ${filePath} → ${outputPath}`);
        } else {
            verbose(`writing in place: ${absPath}`);
            fs.writeFileSync(dest, output.join(lineEnding));
            console.log(`  updated       ${filePath}`);
        }
    } else {
        console.log(`  no change     ${filePath}`);
    }

    return changed;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
const targets = parseArgs(process.argv.slice(2));

if (targets.length === 0) {
    console.error('error: a master/link file is required');
    console.error('Run with --help for usage.');
    process.exit(1);
}

if (opts.output !== null && targets.length > 1) {
    console.error('error: --output cannot be used with multiple target files');
    process.exit(1);
}

if (opts.dryRun) console.log('[dry-run] no files will be written');

console.log(`Processing ${targets.length} file(s)…`);

let anyChanged = false;
for (const f of targets) {
    try {
        const out = opts.output || null;
        anyChanged = processFile(f, out) || anyChanged;
    } catch (err) {
        console.error(`error in ${f}: ${err.message}`);
        if (opts.verbose) console.error(err.stack);
        process.exit(1);
    }
}

if (opts.dryRun && anyChanged) {
    console.log('Done — changes detected (dry-run, nothing written).');
    process.exit(1);
}
console.log(anyChanged ? 'Done — files were updated.' : 'Done — nothing changed.');

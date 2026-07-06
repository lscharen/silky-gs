#!/usr/bin/env node
'use strict';

/**
 * run-bench — Drive the MAME benchmark harness for a single bench build
 * directory (e.g. src/games/bench, src/games/smb).
 *
 * A bench directory is a Merlin32 link file named "Bench.s" that assembles
 * one or more fixed-address segments (TYP BIN / DSK <name> / ORG $BBOOOO
 * blocks), each producing a same-named raw binary with no file extension.
 * Bench.s is the single source of truth for segment names and addresses --
 * the harness does NOT scan symbol files or listings, since a bench
 * directory may contain many unrelated build artifacts from the game's
 * normal (non-bench) build target (e.g. src/games/smb/ also has
 * SuperMarioGS* files from the full GS/OS build alongside the bench
 * segments).
 *
 * This:
 *   1. Parses Bench.s for the ordered list of {name, address} segments.
 *   2. Builds a minimal bootable disk (scripts/make-boot-disk.js) whose
 *      boot sector JSLs to the FIRST segment's address (the entry point)
 *      and spins on a fixed WDM/BRA exit signal once that code RTLs back.
 *   3. Writes a segment manifest (segments.json) next to the disk image.
 *   4. Launches MAME with scripts/mame_bench.lua as the autoboot script,
 *      which loads every segment into memory before jumping in.
 *
 * Usage:
 *   node scripts/run-bench.js <bench-dir>
 *
 * MAME's install path and fixed launch args are read from package.json's
 * "config" block ("mame" / "mameArgs").
 */

const fs            = require('fs');
const path          = require('path');
const { execFileSync, spawnSync } = require('child_process');

const USAGE = `\
Usage: run-bench <bench-dir> [--entry-offset <hex>]

Run the MAME cycle-count benchmark harness against a directory containing
a Merlin32 "Bench.s" fixed-address link file (e.g. src/games/bench,
src/games/smb).

Options:
  --entry-offset <hex>  Byte offset added to the entry segment's address
                         for the boot stub's JSL target only (segment load
                         addresses and bank allocation are unaffected).
                         Useful when the first bytes of the entry segment
                         must be skipped -- e.g. src/games/smb/Main.s
                         prefixes its Entry label with 2 NOPs so the JSL
                         can target offset 2, avoiding whatever the ROM's
                         memory-detection routine may have left at offset
                         0 in that bank before the segment is loaded.
                         (default: 0)
  --reserve-bank-01     Passed through to make-boot-disk.js -- also
                         reserve 01/0800 ($B800) in the boot stub. Off by
                         default since it overlaps the Super Hi-Res shadow
                         screen ($01/2000-9FFF), which real game code
                         allocates itself via GS/OS.
  --fast <multiplier>   Run MAME at this speed multiplier relative to
                         realtime (passed through as MAME's "-speed"
                         option). Since this harness runs headless and
                         only cares about the reported cycle count, not
                         real-time playability, running faster than 1x
                         shortens firmware boot/POST wall-clock time.
                         (default: 4.0)

Example:
  node scripts/run-bench.js src/games/bench
  node scripts/run-bench.js src/games/smb --entry-offset 2
  node scripts/run-bench.js src/games/smb --entry-offset 2 --fast 8
`;

function fail(msg) {
    console.error(`error: ${msg}`);
    process.exit(1);
}

function parseArgs(argv) {
    const opts = { dir: null, entryOffset: 0, reserveBank01: false, fast: '4.0' };
    let i = 0;
    while (i < argv.length) {
        const arg = argv[i];
        if (arg === '--fast') {
            i++;
            opts.fast = argv[i];
        } else if (arg === '--entry-offset') {
            i++;
            opts.entryOffset = parseInt(argv[i], 16);
        } else if (arg === '--reserve-bank-01') {
            opts.reserveBank01 = true;
        } else if (!opts.dir) {
            opts.dir = arg;
        } else {
            fail(`unknown argument: ${arg}`);
        }
        i++;
    }
    return opts;
}

// Add a byte offset to a "BB/OOOO" address, staying within the same bank.
function offsetAddr(addrStr, delta) {
    const bank = parseInt(addrStr.slice(0, 2), 16);
    const offset = (parseInt(addrStr.slice(3), 16) + delta) & 0xFFFF;
    return `${bank.toString(16).padStart(2, '0').toUpperCase()}/${offset.toString(16).padStart(4, '0').toUpperCase()}`;
}

const SCRIPTS_DIR  = __dirname;
const PROJECT_ROOT = path.resolve(SCRIPTS_DIR, '..');
const PACKAGE_JSON = require(path.join(PROJECT_ROOT, 'package.json'));

// Parse a Merlin32 "Bench.s" link file for its ordered list of segments.
// Each segment is a block containing a "DSK <name>" line followed (with
// no intervening DSK) by an "ORG $BBOOOO" line.
function parseSegments(benchFile) {
    const raw = fs.readFileSync(benchFile, 'utf8');

    const segments = [];
    const re = /DSK\s+(\S+)[\s\S]*?ORG\s+\$([0-9A-Fa-f]+)/gi;
    let m;
    while ((m = re.exec(raw)) !== null) {
        const name = m[1];
        const flat = parseInt(m[2], 16);
        const bank = (flat >> 16) & 0xFF;
        const offset = flat & 0xFFFF;
        const addr = `${bank.toString(16).padStart(2, '0').toUpperCase()}/${offset.toString(16).padStart(4, '0').toUpperCase()}`;
        segments.push({ name, addr });
    }

    if (segments.length === 0) fail(`no "DSK <name> ... ORG $XXXXXX" segment blocks found in ${benchFile}`);
    return segments;
}

function main() {
    const opts = parseArgs(process.argv.slice(2));
    if (!opts.dir) {
        console.log(USAGE);
        process.exit(1);
    }

    const absDir = path.resolve(opts.dir);
    if (!fs.existsSync(absDir) || !fs.statSync(absDir).isDirectory()) {
        fail(`bench directory not found: ${opts.dir}`);
    }

    const benchFile = path.join(absDir, 'Bench.s');
    if (!fs.existsSync(benchFile)) fail(`no Bench.s link file found in ${opts.dir}`);

    const segments = parseSegments(benchFile);

    for (const seg of segments) {
        const segPath = path.join(absDir, seg.name);
        if (!fs.existsSync(segPath)) fail(`segment binary not found: ${segPath} (declared in Bench.s as DSK ${seg.name})`);
        seg.file = segPath;
        seg.size = fs.statSync(segPath).size;
    }

    const startAddr = segments[0].addr;
    const jslTargetAddr = opts.entryOffset ? offsetAddr(startAddr, opts.entryOffset) : startAddr;

    // The boot stub allocates one contiguous chunk of 64KB banks, starting
    // at the entry segment's bank, to cover all segment memory (see
    // make-boot-disk.js -- MMStartUp fails if any memory the application
    // occupies is unallocated). This assumes segments are packed one per
    // bank starting at the entry bank with no gaps -- true for the
    // fixed-address builds this harness targets, checked explicitly here.
    const banksUsed = segments.map(s => parseInt(s.addr.slice(0, 2), 16));
    const minBank = Math.min(...banksUsed);
    const maxBank = Math.max(...banksUsed);
    const entryBank = parseInt(startAddr.slice(0, 2), 16);
    if (minBank !== entryBank) {
        fail(`entry segment's bank (${startAddr}) is not the lowest segment bank (${minBank.toString(16).toUpperCase()}) -- ` +
             `boot stub memory allocation assumes segments are packed starting at the entry bank`);
    }
    const bankCount = maxBank - minBank + 1;

    const resultFile   = path.join(absDir, 'bench_result.txt');
    const bootDisk      = path.join(absDir, 'boot.po');
    const bootSidecar   = `${bootDisk}.json`;
    const segmentsFile  = path.join(absDir, 'segments.json');

    console.log(`[run-bench] segments (entry @ ${startAddr}${opts.entryOffset ? `, JSL target @ ${jslTargetAddr}` : ''}, ${bankCount} bank(s) allocated):`);
    for (const seg of segments) {
        console.log(`  ${seg.name.padEnd(12)} @ ${seg.addr}  (${seg.size} bytes)`);
    }

    fs.writeFileSync(segmentsFile, JSON.stringify(segments.map(({ name, addr, file, size }) => ({ name, addr, file, size })), null, 2));

    console.log(`[run-bench] building boot disk (JSL to ${jslTargetAddr})...`);
    execFileSync(process.execPath, [
        path.join(SCRIPTS_DIR, 'make-boot-disk.js'),
        '--start', jslTargetAddr,
        '--banks', String(bankCount),
        ...(opts.reserveBank01 ? ['--reserve-bank-01'] : []),
        '-o', bootDisk,
    ], { stdio: 'inherit' });

    const { exitAddr, failAddr, jslAddr } = JSON.parse(fs.readFileSync(bootSidecar, 'utf8'));

    const mamePath = PACKAGE_JSON.config && PACKAGE_JSON.config.mame;
    if (!mamePath) fail(`no "mame" path configured in package.json config`);

    const fixedArgs = (PACKAGE_JSON.config.mameArgs || 'apple2gs -window -nomax -skip_gameinfo -nofilter -snapsize 704x462')
        .split(/\s+/);

    const luaScript = path.join(SCRIPTS_DIR, 'mame_bench.lua');

    const args = [
        ...fixedArgs,
        '-speed', opts.fast,
        '-debug', '-debugger', 'none',
        '-flop1', bootDisk,
        '-autoboot_script', luaScript,
    ];

    console.log(`[run-bench] segments=${segmentsFile}`);
    console.log(`[run-bench] boot=${bootDisk} jsl=${jslAddr} exit=${exitAddr} fail=${failAddr}`);
    console.log(`[run-bench] launching MAME: ${mamePath} ${args.join(' ')}`);

    const result = spawnSync(mamePath, args, {
        cwd: path.dirname(mamePath),
        stdio: 'inherit',
        env: {
            ...process.env,
            BENCH_SEGMENTS: segmentsFile,
            BENCH_JSL:      jslAddr,
            BENCH_EXIT:     exitAddr,
            BENCH_FAIL:     failAddr,
            BENCH_RESULT:   resultFile,
        },
    });

    if (result.status !== 0) {
        fail(`MAME exited with status ${result.status}`);
    }

    if (fs.existsSync(resultFile)) {
        console.log(`[run-bench] result:\n${fs.readFileSync(resultFile, 'utf8')}`);
    } else {
        console.warn(`[run-bench] warning: no result file produced at ${resultFile}`);
    }
}

main();

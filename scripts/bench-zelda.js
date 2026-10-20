#!/usr/bin/env node
'use strict';

/**
 * bench-zelda -- Build a Zelda BENCH_MODE variant and install it on a GS/OS boot image as
 * SYSTEM/Start, so GSSquared boots straight into it (the run itself is driven through the gs2-mcp
 * server: see docs/BENCH_ZELDA.md).
 *
 *   node scripts/bench-zelda.js --image <boot.po> [options]
 *
 * Options (each one patches the constant of the same name in src/games/zelda/src/Main.s, or
 * src/core/Defs.s, for the build; the files are put back afterwards):
 *   --image <file>     the GS/OS boot image to install into (a ProDOS .po; must have /<volume>/SYSTEM)
 *   --volume <name>    ProDOS volume name of the image (default LIVE.INSTALL)
 *   --input <file>     the canned controller input (zelda.bench), one byte per NES frame; installed next to Start
 *   --wram <file>      a zelda.wram (battery-backed save RAM) with a registered name, installed next
 *                      to Start (the game loads 1/zelda.wram), so the run skips the registration screens
 *   --noint            NO_INTERRUPTS = 1: the event loop drives the frames, so the cycles between
 *                      BenchStart and BenchDone measure the work done (default: interrupts on)
 *   --banks <n>        SPR_MAX_BANKS in src/core/Defs.s, 32 slots each (default: as it is there)
 *   --stats            SPR_CACHE_STATS = 1: count the sprite cache's hits, misses, compiles and evictions
 *                      (gs2-bench-run.js --stats reads them; the counters cost cycles)
 *   --quota <n>        SPR_COMPILE_PER_RENDER in src/core/Defs.s (default: as it is there)
 *   --len <n>          BENCH_MODE_LEN, frames (default 3600; at most 3840)
 *   --no-build         don't build: install the ZeldaGS that is there (e.g. to change the input or save file)
 *   --no-bench         build with BENCH_MODE = 0 (a normal build, e.g. for a size check)
 *   --out <file>       write the symbol addresses the harness needs to this JSON file
 *
 * The cache-less comparison build is made the same way from a checkout of main, with the same
 * Main.s bench changes.
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const PKG = require(path.join(ROOT, 'package.json'));
const ZELDA = path.join(ROOT, 'src', 'games', 'zelda');
const MAIN = path.join(ZELDA, 'src', 'Main.s');
const DEFS = path.join(ROOT, 'src', 'core', 'Defs.s');
const APP = path.join(ZELDA, 'src', 'ZeldaGS');
const SYMBOLS = path.join(ZELDA, 'src', 'ZeldaGS_Symbols.txt');

function parseArgs(argv) {
    const o = { volume: 'LIVE.INSTALL', noint: false, banks: null, stats: false, quota: null,
                len: null, bench: true, image: null, out: null, wram: null, input: null, build: true };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === '--image') o.image = argv[++i];
        else if (a === '--volume') o.volume = argv[++i];
        else if (a === '--noint') o.noint = true;
        else if (a === '--banks') o.banks = parseInt(argv[++i], 10);
        else if (a === '--stats') o.stats = true;
        else if (a === '--quota') o.quota = parseInt(argv[++i], 10);
        else if (a === '--len') o.len = parseInt(argv[++i], 10);
        else if (a === '--no-bench') o.bench = false;
        else if (a === '--no-build') o.build = false;
        else if (a === '--out') o.out = argv[++i];
        else if (a === '--wram') o.wram = argv[++i];
        else if (a === '--input') o.input = argv[++i];
        else throw new Error(`unknown argument ${a}`);
    }
    return o;
}

function setConst(text, name, value) {
    const re = new RegExp(`^(${name}\\s+equ\\s+)\\S+`, 'm');
    if (!re.test(text)) throw new Error(`${name} not found`);
    return text.replace(re, `$1${value}`);
}

function main() {
    const o = parseArgs(process.argv.slice(2));
    const original = fs.readFileSync(MAIN, 'utf8');
    let t = original;
    t = setConst(t, 'BENCH_MODE', o.bench ? 1 : 0);
    t = setConst(t, 'NO_INTERRUPTS', o.noint ? 1 : 0);
    if (o.len !== null) t = setConst(t, 'BENCH_MODE_LEN', o.len);
    const originalDefs = fs.readFileSync(DEFS, 'utf8');
    let d = originalDefs;
    if (o.banks !== null) d = setConst(d, 'SPR_MAX_BANKS', o.banks);
    if (o.stats) d = setConst(d, 'SPR_CACHE_STATS', 1);
    if (o.quota !== null) d = setConst(d, 'SPR_COMPILE_PER_RENDER', o.quota);

    if (o.build) try {
        fs.writeFileSync(MAIN, t);
        fs.writeFileSync(DEFS, d);
        fs.rmSync(APP, { force: true });                        // so a failed build can't leave a stale binary
        execFileSync(process.execPath, [path.join(ZELDA, 'build.js')], { stdio: 'inherit' });
    } finally {
        fs.writeFileSync(MAIN, original);
        fs.writeFileSync(DEFS, originalDefs);
    }
    if (!fs.existsSync(APP)) throw new Error('the build did not produce ZeldaGS');

    // The symbols the harness needs: "SEG;n;file;line;BB/OOOO;name;type;..."
    const want = ['BenchStart', 'BenchDone', 'SprCacheInit', 'SprCompileTile', 'drawSprites', 'NES_RenderFrame',
                  'BenchInputIndex', 'DP_NES', 'csd', 'draw_rtn2',
                  'drawScreen', 'gridDrawDirty', 'zExposePlayArea', 'RenderScreen', '_RenderScreen'];
    const syms = {};
    for (const line of fs.readFileSync(SYMBOLS, 'utf8').split(/\r?\n/)) {
        const f = line.split(';');
        if (f.length > 5 && want.includes(f[5])) syms[f[5]] = { segment: f[0], address: f[4] };
    }

    if (o.image) {
        const stage = path.join(path.dirname(o.image), 'stage');
        fs.mkdirSync(stage, { recursive: true });
        fs.copyFileSync(APP, path.join(stage, 'Start'));
        const folderInfo = 'FolderInfo1(000000000000000000000000000000000000),FolderInfo2(000000000000000000000000000000000000)';
        fs.writeFileSync(path.join(stage, '_FileInformation.txt'),
            `Start=Type(B3),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3),${folderInfo}\n` +
            `zelda.bench=Type(06),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3),${folderInfo}
` +
            `zelda.wram=Type(06),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3),${folderInfo}\n`);
        const cadius = PKG.config.cadius;
        const folder = `/${o.volume}/SYSTEM`;
        const env = { ...process.env, MSYS_NO_PATHCONV: '1' };
        try { execFileSync(cadius, ['DELETEFILE', o.image, `${folder}/Start`], { env, stdio: 'pipe' }); } catch (e) { /* not there yet */ }
        const out = execFileSync(cadius, ['ADDFILE', o.image, folder, path.join(stage, 'Start')], { env }).toString();
        if (/error|unable/i.test(out)) throw new Error(`Cadius: ${out}`);
        if (o.wram) {
            fs.copyFileSync(o.wram, path.join(stage, 'zelda.wram'));
            try { execFileSync(cadius, ['DELETEFILE', o.image, `${folder}/zelda.wram`], { env, stdio: 'pipe' }); } catch (e) { /* not there yet */ }
            execFileSync(cadius, ['ADDFILE', o.image, folder, path.join(stage, 'zelda.wram')], { env });
        }
        if (o.input) {
            fs.copyFileSync(o.input, path.join(stage, 'zelda.bench'));
            try { execFileSync(cadius, ['DELETEFILE', o.image, `${folder}/zelda.bench`], { env, stdio: 'pipe' }); } catch (e) { /* not there yet */ }
            execFileSync(cadius, ['ADDFILE', o.image, folder, path.join(stage, 'zelda.bench')], { env });
        }
        console.log(`[bench-zelda] installed ${folder}/Start (${fs.statSync(APP).size} bytes) in ${o.image}`);
    }

    const info = { options: o, size: fs.statSync(APP).size, symbols: syms };
    if (o.out) fs.writeFileSync(o.out, JSON.stringify(info, null, 2));
    console.log(JSON.stringify(info.symbols));
}

main();

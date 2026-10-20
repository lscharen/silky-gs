#!/usr/bin/env node
'use strict';

/**
 * bench-zelda -- Build a Zelda benchmark variant and install it on a GS/OS boot image as
 * SYSTEM/Start, so GSSquared boots straight into it (the run itself is driven through the gs2-mcp
 * server: see docs/BENCH_ZELDA.md).
 *
 *   node scripts/bench-zelda.js --image <boot.po> [options]
 *
 * The harness (canned input, BenchStart / BenchDone, the frame count) is not in the source: harnessEdits()
 * patches it into Main.s, rom_input.s, rom_exec.s and scaffold.s for the build, and every patched file is put
 * back afterwards, as are the constants the options below set (Config.s, core/Defs.s, the ppu_grid files).
 * Options:
 *   --image <file>     the GS/OS boot image to install into (a ProDOS .po; must have /<volume>/SYSTEM)
 *   --volume <name>    ProDOS volume name of the image (default LIVE.INSTALL)
 *   --input <file>     the canned controller input (zelda.bench), one byte per NES frame; installed next to Start
 *   --wram <file>      a zelda.wram (battery-backed save RAM) with a registered name, installed next
 *                      to Start (the game loads 1/zelda.wram), so the run skips the registration screens
 *   --noint            NO_INTERRUPTS = 1: the event loop drives the frames, so the cycles between
 *                      BenchStart and BenchDone measure the work done.  Required: the harness only
 *                      advances the input in NES_TriggerNMI
 *   --banks <n>        SPR_MAX_BANKS in src/core/Defs.s, 32 slots each (default: as it is there)
 *   --stats            SPR_CACHE_STATS = 1: count the sprite cache's hits, misses, compiles and evictions
 *                      (gs2-bench-run.js --stats reads them; the counters cost cycles)
 *   --gridstats        GRID_STATS = GRID_CELL_STATS = 1: the grid renderer's frame, cell and word counters
 *                      (gs2-bench-run.js --gridstats reads them; the counters cost cycles)
 *   --quota <n>        SPR_COMPILE_PER_RENDER in src/core/Defs.s (default: as it is there)
 *   --len <n>          BENCH_MODE_LEN, frames (default 3600; at most 3840)
 *   --no-build         don't build: install the ZeldaGS that is there (e.g. to change the input or save file)
 *   --no-bench         build without the harness (a normal build, e.g. for a size check)
 *   --out <file>       write the symbol addresses the harness needs to this JSON file
 *
 * To compare with another commit, run this script (and gs2-bench-run.js) from the working tree on a
 * worktree of it: the anchors harnessEdits() patches must still be there.
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
const SRC = path.join(ROOT, 'src');

function parseArgs(argv) {
    const o = { volume: 'LIVE.INSTALL', noint: false, banks: null, stats: false, quota: null,
                len: null, bench: true, image: null, out: null, wram: null, input: null, build: true,
                gridstats: false };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === '--image') o.image = argv[++i];
        else if (a === '--volume') o.volume = argv[++i];
        else if (a === '--noint') o.noint = true;
        else if (a === '--banks') o.banks = parseInt(argv[++i], 10);
        else if (a === '--stats') o.stats = true;
        else if (a === '--gridstats') o.gridstats = true;
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

// Replace the first occurrence of `anchor` in `text` (it must be there): the harness is patched into the
// source for the build only, so the committed source has no benchmark code
function patch(text, anchor, replacement, what) {
    if (!text.includes(anchor)) throw new Error(`bench patch: ${what}: anchor not found`);
    return text.replace(anchor, replacement);
}

// The benchmark harness, as edits to the source (file -> text -> text).  The controller input is read from
// BenchInputData, one byte per NES frame, and the run ends after BENCH_MODE_LEN frames at BenchDone, which
// is before NES_ShutDown, so the save file is read but never written.  With NO_INTERRUPTS the input index
// advances once per NES frame (NES_TriggerNMI) and the cycles between BenchStart and BenchDone measure the
// work done for those frames.  Frame k reads input byte k-1, as the original harness did (it latched the
// input after the NMI), so the recorded routes still play the same.
function harnessEdits(o) {
    const len = o.len !== null ? o.len : 3600;
    const edits = {};
    edits[path.join(ZELDA, 'src', 'Config.s')] = (t) => {
        t = setConst(t, 'NO_INTERRUPTS', o.noint ? 1 : 0);
        return t;
    };
    if (o.gridstats) {
        edits[path.join(SRC, 'ppu', 'ppu_grid.s')] = (t) => setConst(t, 'GRID_STATS', 1);
        edits[path.join(SRC, 'ppu', 'ppu_grid_quads.s')] = (t) => setConst(t, 'GRID_CELL_STATS', 1);
    }
    if (!o.bench) return edits;
    edits[MAIN] = (t) => {
        t = patch(t, `            jsr   NES_ColdBoot\n`,
`            lda   #BENCH_MODE_LEN         ; Load the canned input, one byte per frame
            ldx   #BENCH_INPUT_ADDR
            ldy   #benchCreateRec
            jsr   LoadROMFile
BenchStart                                ; The harness starts counting cycles here
            jsr   NES_ColdBoot\n`, 'Main.s NES_ColdBoot');
        t = patch(t, `\nquit\n`, `\nquit\nBenchDone   bra   BenchDone               ; The harness reads the cycle count here\n`, 'Main.s quit');
        t = patch(t, `WRAM_FILENAME strl`,
`BENCH_MODE_LEN  equ ${len}
BENCH_INPUT_ADDR equ $0800
BenchInputIndex dw  0
BenchInputData  equ ROMBase+BENCH_INPUT_ADDR
BENCH_FILENAME  strl '1/zelda.bench'
benchCreateRec  dw  4
                adrl BENCH_FILENAME
                dw  $00C3
                dw  $0006
                dw  $0000,$0000

WRAM_FILENAME strl`, 'Main.s WRAM_FILENAME');
        return t;
    };
    edits[path.join(SRC, 'rom', 'rom_input.s')] = (t) => patch(t,
`NES_PollInput
            php
            sei
`,
`NES_PollInput
            php
            sei
            ldal  BenchInputIndex         ; (bench) the canned input for this frame: byte index-1
            tax
            sep   #$20
            lda   #0
            cpx   #0
            beq   *+6
            ldal  BenchInputData-1,x
            sta   native_joy
            stz   native_joy+1
            rep   #$20
            stz   LastRead
            plp
            rts
`, 'rom_input.s NES_PollInput');
    edits[path.join(SRC, 'rom', 'rom_exec.s')] = (t) => patch(t,
`NES_TriggerNMI
`,
`NES_TriggerNMI
            ldal  BenchInputIndex         ; (bench) one input byte per NES frame
            inc
            stal  BenchInputIndex
`, 'rom_exec.s NES_TriggerNMI');
    edits[path.join(SRC, 'rom', 'scaffold.s')] = (t) => patch(t,
`            jsr   NES_RenderFrame
`,
`            jsr   NES_RenderFrame
            ldal  BenchInputIndex         ; (bench) the input is used up: stop
            cmp   #BENCH_MODE_LEN-1
            bcc   *+5
            jmp   BenchDone
`, 'scaffold.s NES_RenderFrame');
    return edits;
}

function main() {
    const o = parseArgs(process.argv.slice(2));
    if (o.bench && !o.noint) throw new Error('the harness needs --noint (the input advances in NES_TriggerNMI)');
    const edits = harnessEdits(o);
    edits[DEFS] = (d) => {
        if (o.banks !== null) d = setConst(d, 'SPR_MAX_BANKS', o.banks);
        if (o.stats) d = setConst(d, 'SPR_CACHE_STATS', 1);
        if (o.quota !== null) d = setConst(d, 'SPR_COMPILE_PER_RENDER', o.quota);
        return d;
    };
    const originals = {};
    for (const file of Object.keys(edits)) originals[file] = fs.readFileSync(file, 'utf8');

    if (o.build) try {
        for (const [file, edit] of Object.entries(edits)) fs.writeFileSync(file, edit(originals[file]));
        fs.rmSync(APP, { force: true });                        // so a failed build can't leave a stale binary
        execFileSync(process.execPath, [path.join(ZELDA, 'build.js')], { stdio: 'inherit' });
    } finally {
        for (const [file, text] of Object.entries(originals)) fs.writeFileSync(file, text);
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

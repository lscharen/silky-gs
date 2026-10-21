#!/usr/bin/env node
'use strict';

/**
 * bench-zelda-sweep -- Build, install and run Zelda BENCH_MODE trials for a list of cache settings
 * (scripts/bench-zelda.js, then scripts/gs2-bench-run.js for each), appending one JSON line per trial
 * to a results file.  See docs/BENCH_ZELDA.md.
 *
 *   node scripts/bench-zelda-sweep.js --image <boot.po> --config <.gs2> --wram <zelda.wram> --input <zelda.bench>
 *        --out <results.jsonl> [--slots 63,32,16] [--quota 1,2,4] [--repeat n] [--plain]
 *
 *   --slots / --quota  the grid to run (every combination).  Default: the Main.s values, one trial
 *   --plain            the build does not have the cache settings at all (a checkout of main): no
 *                      --slots/--quota are passed to bench-zelda.js
 *   --repeat <n>       run each trial n times (the runs are deterministic apart from GS/OS timing)
 *
 * All trials use NO_INTERRUPTS = 1, so the frames are driven by the event loop and the cycles between
 * BenchStart and BenchDone are the work done for the same BENCH_MODE_LEN frames of input.
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const HERE = __dirname;

function parseArgs(argv) {
    const o = { slots: [null], quota: [null], plain: false, repeat: 1, noint: true };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        const list = () => argv[++i].split(',').map(x => parseInt(x, 10));
        if (a === '--image') o.image = argv[++i];
        else if (a === '--config') o.config = argv[++i];
        else if (a === '--wram') o.wram = argv[++i];
        else if (a === '--input') o.input = argv[++i];
        else if (a === '--out') o.out = argv[++i];
        else if (a === '--slots') o.slots = list();
        else if (a === '--quota') o.quota = list();
        else if (a === '--plain') o.plain = true;
        else if (a === '--repeat') o.repeat = parseInt(argv[++i], 10);
        else if (a === '--interrupts') o.noint = false;
        else throw new Error(`unknown argument ${a}`);
    }
    for (const k of ['image', 'config', 'wram', 'input', 'out']) if (!o[k]) throw new Error(`--${k} is required`);
    return o;
}

function main() {
    const o = parseArgs(process.argv.slice(2));
    const tmp = path.join(path.dirname(o.out), 'sweep-info.json');
    for (const slots of o.slots) {
        for (const quota of o.quota) {
            const tag = o.plain ? 'main' : `s${slots === null ? 'D' : slots}-q${quota === null ? 'D' : quota}`;
            const args = [path.join(HERE, 'bench-zelda.js'), '--image', o.image, '--wram', o.wram, '--input', o.input, '--out', tmp];
            if (o.noint) args.push('--noint');
            if (!o.plain) {
                if (slots !== null) args.push('--slots', String(slots));
                if (quota !== null) args.push('--quota', String(quota));
            }
            console.error(`[sweep] building ${tag}`);
            execFileSync(process.execPath, args, { stdio: ['ignore', 'ignore', 'inherit'] });
            for (let r = 0; r < o.repeat; r++) {
                console.error(`[sweep] running ${tag} (${r + 1}/${o.repeat})`);
                const out = execFileSync(process.execPath, [path.join(HERE, 'gs2-bench-run.js'), '--info', tmp, '--config', o.config, '--label', tag],
                                         { stdio: ['ignore', 'pipe', 'inherit'], maxBuffer: 1 << 24 }).toString();
                const result = JSON.parse(out.trim().split('\n').pop());
                delete result.options.image; delete result.options.out; delete result.options.wram; delete result.options.input;
                result.tag = tag; result.slots = slots; result.quota = quota; result.run = r;
                fs.appendFileSync(o.out, JSON.stringify(result) + '\n');
                console.error(`[sweep] ${tag}: ${result.cycles} cycles`);
            }
        }
    }
}

main();

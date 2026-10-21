#!/usr/bin/env node
'use strict';

/**
 * bench-zelda-route -- Make the two data files of the Zelda benchmark (docs/BENCH_ZELDA.md):
 *
 *   zelda.bench  the controller input, one byte per NES frame (A-B-Select-Start-Up-Down-Left-Right,
 *                MSB first), read by BENCH_MODE builds (rom/rom_input.s)
 *   zelda.wram   the battery-backed save RAM, so the run does not go through the registration screens
 *
 *   node scripts/bench-zelda-route.js --wram <a zelda.wram with a registered name and the wooden sword>
 *                                     --out <directory> [--route "R:700,U:600,..."] [--frames 3600]
 *
 * The route:
 *   frame   0-149   idle: the title screen
 *   frame 150       Start: to the file select screen (slot 1 is the registered name)
 *   frame 303       Start: starts the game, Link at the start of the overworld (room $77)
 *   frame 400-      the legs of --route, each U/D/L/R:frames.  Link swings the sword (A, 2 frames) every 22
 *                   frames while walking, so there are enemies dying, drops and sword beams.  The default route
 *                   goes east, north, west, south and east again (rooms $77, $78, $68, $58, $57, $56)
 *
 * The save is patched to have 16 heart containers (all full, so the sword fires beams), so Link doesn't die in
 * the middle of the run: HeartValues is at file offset $32 (Items[$18]) and the file's checksum, a 16-bit sum
 * stored high byte first at $524, is adjusted by the same amount.
 */

const fs = require('fs');
const path = require('path');

const DEFAULT_ROUTE = 'R:700,U:600,L:700,D:600,R:400';
const BUTTON = { U: 0x08, D: 0x04, L: 0x02, R: 0x01, W: 0x00 };
const A = 0x80, START = 0x10;

function makeInput(route, frames) {
    const out = [];
    const push = (v, n) => { for (let i = 0; i < n; i++) out.push(v); };
    push(0, 150); push(START, 3); push(0, 147); push(START, 3); push(0, 97);
    for (const leg of route.split(',')) {
        const [d, n] = leg.split(':');
        if (!(d in BUTTON)) throw new Error(`bad leg ${leg}`);
        let left = parseInt(n, 10);
        while (left > 0) {
            const w = Math.min(left, 22);
            push(BUTTON[d], w);
            left -= w;
            if (left > 0 && d !== 'W') { push(A, 2); left -= 2; }
        }
    }
    if (out.length > frames) console.error(`warning: the route is ${out.length} frames, cut to ${frames}`);
    while (out.length < frames) out.push(0);
    return Buffer.from(out.slice(0, frames));
}

function patchWram(wram) {
    const b = Buffer.from(wram);
    if (b.length !== 8192) throw new Error('a zelda.wram is 8192 bytes');
    if (b[0x51E] !== 0x5A || b[0x521] !== 0xA5) throw new Error('not a formatted Zelda save file');
    if (b[0x1A] === 0) throw new Error('the save has no sword (Items[0])');
    const delta = 0xFF - b[0x32];
    b[0x32] = 0xFF;                                   // HeartValues: 16 containers, all full
    const sum = (((b[0x524] << 8) | b[0x525]) + delta) & 0xFFFF;
    b[0x524] = sum >> 8;
    b[0x525] = sum & 0xFF;
    return b;
}

function main() {
    const argv = process.argv.slice(2);
    const o = { route: DEFAULT_ROUTE, frames: 3600, wram: null, out: null };
    for (let i = 0; i < argv.length; i++) {
        if (argv[i] === '--route') o.route = argv[++i];
        else if (argv[i] === '--frames') o.frames = parseInt(argv[++i], 10);
        else if (argv[i] === '--wram') o.wram = argv[++i];
        else if (argv[i] === '--out') o.out = argv[++i];
        else throw new Error(`unknown argument ${argv[i]}`);
    }
    if (!o.wram || !o.out) throw new Error('--wram and --out are required');
    fs.mkdirSync(o.out, { recursive: true });
    fs.writeFileSync(path.join(o.out, 'zelda.bench'), makeInput(o.route, o.frames));
    fs.writeFileSync(path.join(o.out, 'zelda.wram'), patchWram(fs.readFileSync(o.wram)));
    console.log(`wrote zelda.bench (${o.frames} frames) and zelda.wram to ${o.out}`);
}

main();

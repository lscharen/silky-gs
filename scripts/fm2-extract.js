#!/usr/bin/env node
'use strict';

/**
 * fm2-extract — Extract NES controller input frames from an FCEUX .fm2
 * movie file and save them as raw 1-byte-per-frame binary, matching the
 * joypad bit layout used by src/rom/rom_input.s (MSB-first order despite
 * the comment there reading left-to-right as A-B-Select-Start-...):
 *
 *   bit7=A  bit6=B  bit5=Select  bit4=Start  bit3=Up  bit2=Down  bit1=Left  bit0=Right
 *
 * This is MSB-first, not the bit0=A/LSB-first order the byte's comment in
 * rom_input.s might suggest at a glance. bit0=A would be the natural
 * choice if this byte were built by shifting real controller reads out
 * one bit at a time (the actual NES hardware reads A first, so it would
 * land in the first-shifted-out bit). But this engine's native_joy is
 * just a byte read directly, not a simulated shift register, so its bit
 * order matches whatever the translated ROM's own convention happens to
 * be -- confirmed empirically: a lone Start press ("....T...") must
 * produce $10 (bit4), not $08 (bit3, which is Up).
 *
 * .fm2 input lines look like:
 *   |0|RLDUTSBA...|........|........|
 * The commands field is followed by one 8-character field per controller
 * port, in fixed column order R L D U T S B A (a non-'.' / non-blank
 * character means the button is held).
 */

const fs   = require('fs');
const path = require('path');

const USAGE = `\
Usage: fm2-extract [options] <input.fm2>

Extract controller-1 input frames from an FCEUX .fm2 movie and write them
as a raw binary file, one byte per frame, in the bit layout expected by
src/rom/rom_input.s (bit7=A bit6=B bit5=Select bit4=Start bit3=Up bit2=Down
bit1=Left bit0=Right).

Options:
  -n, --frames <count>   Number of frames to extract, starting at --start.
                          Defaults to all remaining input frames.
  -s, --start <index>    0-based index of the first input frame to extract.
                          Defaults to 0.
  -p, --port <1|2>       Controller port to extract. Defaults to 1.
  -o, --output <file>    Output file path. Defaults to <input>.bin.
  -h, --help             Show this help message and exit.

Examples:
  fm2-extract -n 1000 replay.fm2
  fm2-extract --start 500 --frames 200 -o tas_input.bin replay.fm2
`;

// FM2 controller field column order.
const FM2_COLUMNS = ['R', 'L', 'D', 'U', 'T', 'S', 'B', 'A'];

// Bit position for each button in the output byte (matches rom_input.s;
// MSB-first, confirmed against actual output -- see header note).
const BIT = { A: 7, B: 6, S: 5, T: 4, U: 3, D: 2, L: 1, R: 0 };

function parseArgs(argv) {
    const opts = {
        frames: null,
        start:  0,
        port:   1,
        output: null,
        input:  null,
    };

    let i = 0;
    while (i < argv.length) {
        const arg = argv[i];
        switch (arg) {
            case '-h': case '--help':
                console.log(USAGE);
                process.exit(0);
                break;
            case '-n': case '--frames':
                i++;
                opts.frames = parseInt(argv[i], 10);
                break;
            case '-s': case '--start':
                i++;
                opts.start = parseInt(argv[i], 10);
                break;
            case '-p': case '--port':
                i++;
                opts.port = parseInt(argv[i], 10);
                break;
            case '-o': case '--output':
                i++;
                opts.output = argv[i];
                break;
            default:
                if (arg.startsWith('-')) {
                    console.error(`error: unknown option: ${arg}`);
                    console.error('Run with --help for usage.');
                    process.exit(1);
                } else {
                    opts.input = arg;
                }
        }
        i++;
    }

    if (!opts.input) {
        console.error('error: an input .fm2 file is required');
        console.error('Run with --help for usage.');
        process.exit(1);
    }
    if (opts.port !== 1 && opts.port !== 2) {
        console.error('error: --port must be 1 or 2');
        process.exit(1);
    }
    if (Number.isNaN(opts.start) || opts.start < 0) {
        console.error('error: --start must be a non-negative integer');
        process.exit(1);
    }
    if (opts.frames !== null && (Number.isNaN(opts.frames) || opts.frames < 0)) {
        console.error('error: --frames must be a non-negative integer');
        process.exit(1);
    }

    return opts;
}

// Parse a single fm2 input line into a joypad byte for the requested port,
// or null if the line is not an input record (comments/header/subtitles).
function parseInputLine(line, port) {
    if (!line.startsWith('|')) return null;

    const fields = line.split('|');
    // fields[0] is '' (before the leading |), fields[1] is the command byte,
    // fields[2] is port1, fields[3] is port2, fields[4] is port3, ...
    if (fields.length < 3) return null;

    const portField = fields[1 + port];
    if (portField === undefined || portField.length < FM2_COLUMNS.length) return null;

    let value = 0;
    for (let col = 0; col < FM2_COLUMNS.length; col++) {
        const ch = portField[col];
        if (ch !== '.' && ch !== ' ' && ch !== '') {
            const button = FM2_COLUMNS[col];
            value |= (1 << BIT[button]);
        }
    }
    return value;
}

function main() {
    const opts = parseArgs(process.argv.slice(2));

    const absInput = path.resolve(opts.input);
    if (!fs.existsSync(absInput)) {
        console.error(`error: input file not found: ${opts.input}`);
        process.exit(1);
    }

    const raw   = fs.readFileSync(absInput, 'utf8');
    const lines = raw.split(/\r?\n/);

    const allFrames = [];
    for (const line of lines) {
        const value = parseInputLine(line, opts.port);
        if (value !== null) allFrames.push(value);
    }

    if (opts.start >= allFrames.length) {
        console.error(`error: --start ${opts.start} is past the end of the movie (${allFrames.length} input frames found)`);
        process.exit(1);
    }

    const end = opts.frames === null
        ? allFrames.length
        : Math.min(allFrames.length, opts.start + opts.frames);

    const selected = allFrames.slice(opts.start, end);

    if (opts.frames !== null && selected.length < opts.frames) {
        console.warn(`warning: requested ${opts.frames} frames but only ${selected.length} available from start=${opts.start}`);
    }

    const outPath = opts.output || `${absInput.replace(/\.fm2$/i, '')}.bin`;
    fs.writeFileSync(outPath, Buffer.from(selected));

    console.log(`Extracted ${selected.length} frame(s) from port ${opts.port} (frames ${opts.start}-${opts.start + selected.length - 1}) → ${outPath}`);
}

main();

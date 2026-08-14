#!/usr/bin/env node
'use strict';

/**
 * dump-chr — Extract the CHR-ROM from an iNES (.nes) ROM file and save it
 * as a raw binary, byte-for-byte as it appears in the .nes file (no iNES
 * header, no conversion) -- the input format scripts/convert-chr-rom.js and
 * the per-game build.js scripts (e.g. src/games/smb/build.js) expect.
 *
 * iNES file layout:
 *   [0..15]   16-byte header ("NES\x1A", PRG size, CHR size, flags...)
 *   [16..]    512-byte trainer, only present if header flags 6 bit 2 is set
 *   [..]      PRG-ROM  (header byte 4 x 16384 bytes)
 *   [..]      CHR-ROM  (header byte 5 x 8192 bytes)
 *   [..]      (PlayChoice INST-ROM / PROM, title -- not needed here)
 *
 * By default this dumps the first 8KB CHR-ROM bank; use --bank for ROMs
 * with more than one.
 */

const fs   = require('fs');
const path = require('path');

const USAGE = `\
Usage: dump-chr [options] <input.nes>

Extract an 8KB CHR-ROM bank from an iNES ROM file and write it as a raw
binary, exactly as stored in the .nes file.

Options:
  -b, --bank <n>        0-based index of the 8KB CHR-ROM bank to extract.
                          Defaults to 0 (the first bank).
  -o, --output <file>    Output file path. Defaults to <input>.chr.bin.
  -h, --help             Show this help message and exit.

Examples:
  dump-chr smb.nes
  dump-chr --bank 1 -o chr_bank1.bin smb.nes
`;

const INES_HEADER_SIZE = 16;
const TRAINER_SIZE     = 512;
const PRG_BANK_SIZE    = 16384;
const CHR_BANK_SIZE    = 8192;
const INES_MAGIC       = Buffer.from([0x4E, 0x45, 0x53, 0x1A]); // "NES\x1A"

function parseArgs(argv) {
  const opts = {
    bank:   0,
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
      case '-b': case '--bank':
        i++;
        opts.bank = parseInt(argv[i], 10);
        break;
      case '-o': case '--output':
        i++;
        opts.output = argv[i];
        break;
      default:
        if (arg.startsWith('-')) {
          console.error(`error: unknown option: ${arg}`);
          process.exit(1);
        }
        if (opts.input) {
          console.error('error: only one input .nes file may be given');
          process.exit(1);
        }
        opts.input = arg;
    }
    i++;
  }

  if (!opts.input) {
    console.error('error: an input .nes file is required');
    console.error(USAGE);
    process.exit(1);
  }
  if (!Number.isInteger(opts.bank) || opts.bank < 0) {
    console.error(`error: --bank must be a non-negative integer, got "${argv[argv.indexOf('--bank') + 1] || argv[argv.indexOf('-b') + 1]}"`);
    process.exit(1);
  }
  if (!opts.output) {
    const ext = path.extname(opts.input);
    opts.output = path.join(
      path.dirname(opts.input),
      path.basename(opts.input, ext) + '.chr.bin'
    );
  }

  return opts;
}

function extractChr(rom, bank) {
  if (rom.length < INES_HEADER_SIZE || !rom.subarray(0, 4).equals(INES_MAGIC)) {
    throw new Error('not an iNES file (missing "NES\\x1A" magic in the first 4 bytes)');
  }

  const prgBanks = rom[4];
  const chrBanks = rom[5];
  const flags6   = rom[6];
  const hasTrainer = (flags6 & 0x04) !== 0;

  if (chrBanks === 0) {
    throw new Error('this ROM has no CHR-ROM (header byte 5 is 0 -- it uses CHR-RAM instead)');
  }
  if (bank >= chrBanks) {
    throw new Error(`--bank ${bank} out of range: this ROM only has ${chrBanks} 8KB CHR-ROM bank(s) (0..${chrBanks - 1})`);
  }

  const chrStart = INES_HEADER_SIZE
    + (hasTrainer ? TRAINER_SIZE : 0)
    + prgBanks * PRG_BANK_SIZE
    + bank * CHR_BANK_SIZE;
  const chrEnd = chrStart + CHR_BANK_SIZE;

  if (rom.length < chrEnd) {
    throw new Error(
      `file is truncated: expected CHR-ROM bank ${bank} at offset ${chrStart}..${chrEnd}, ` +
      `but the file is only ${rom.length} bytes`
    );
  }

  return rom.subarray(chrStart, chrEnd);
}

function main() {
  const opts = parseArgs(process.argv.slice(2));

  const rom = fs.readFileSync(opts.input);
  let chr;
  try {
    chr = extractChr(rom, opts.bank);
  } catch (err) {
    console.error(`error: ${err.message}`);
    process.exit(1);
  }

  fs.writeFileSync(opts.output, chr);
  console.error(`wrote ${chr.length} bytes (CHR-ROM bank ${opts.bank}) -> ${opts.output}`);
}

main();

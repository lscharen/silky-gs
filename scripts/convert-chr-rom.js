#!/usr/bin/env node
'use strict';

/**
 * convert-chr-rom — precompute static tile-conversion tables from a NES
 * CHR-ROM, using the same conversion algorithm as ROMTileToBitmap and
 * ConvertROMTile2 in src/rom/rom_helpers.s (see scripts/lib/nesTileConvert.js
 * and tests/rom/rom_helpers.test.mjs, which prove the two stay in sync).
 *
 * For simple games whose CHR data never changes at runtime, this lets the
 * conversion happen once, offline, instead of on every ROM load: the output
 * tables can be assembled directly into a game's data segment in place of
 * calling ROM_LoadBackgroundTiles/ROM_LoadSpriteTiles at startup.
 *
 * Usage:
 *   node scripts/convert-chr-rom.js <chr-rom-file> [options]
 *
 * Options:
 *   --mode <bitmap|sprite>  Conversion routine to apply (default: bitmap)
 *                             bitmap = ROMTileToBitmap  (32 bytes/tile)
 *                             sprite = ConvertROMTile2   (128 bytes/tile)
 *   --format <bin|merlin>   Output format (default: merlin)
 *   --label <name>          Merlin32 label for the emitted table (default: derived from filename)
 *   --offset <n>             Byte offset into the file to start reading tiles at (default: 0)
 *   --count <n>              Number of tiles to convert (default: as many 16-byte tiles as fit)
 *   -o, --output <file>      Write to <file> instead of stdout
 */

const fs   = require('fs');
const path = require('path');
const { romTileToBitmap, convertRomTile2 } = require('./lib/nesTileConvert.js');

const TILE_SIZE = 16;

const USAGE = `\
Usage: convert-chr-rom <chr-rom-file> [options]

Precompute static NES-CHR-ROM tile conversion tables, using the same
algorithm as ROMTileToBitmap / ConvertROMTile2 in src/rom/rom_helpers.s.

Options:
  --mode <bitmap|sprite>  Conversion routine to apply (default: bitmap)
  --format <bin|merlin>   Output format (default: merlin)
  --label <name>          Merlin32 label for the emitted table
  --offset <n>            Byte offset into the file to start at (default: 0)
  --count <n>             Number of tiles to convert (default: all that fit)
  -o, --output <file>     Write to <file> instead of stdout
  -h, --help              Show this help message
`;

function parseArgs(argv) {
  const opts = {
    file: null,
    mode: 'bitmap',
    format: 'merlin',
    label: null,
    offset: 0,
    count: null,
    output: null,
  };

  let i = 0;
  while (i < argv.length) {
    const arg = argv[i];
    switch (arg) {
      case '-h': case '--help':
        process.stdout.write(USAGE);
        process.exit(0);
        break;
      case '--mode':
        opts.mode = argv[++i];
        break;
      case '--format':
        opts.format = argv[++i];
        break;
      case '--label':
        opts.label = argv[++i];
        break;
      case '--offset':
        opts.offset = Number(argv[++i]);
        break;
      case '--count':
        opts.count = Number(argv[++i]);
        break;
      case '-o': case '--output':
        opts.output = argv[++i];
        break;
      default:
        if (arg.startsWith('-')) {
          console.error(`error: unknown option: ${arg}`);
          process.exit(1);
        }
        if (opts.file) {
          console.error('error: only one CHR-ROM file may be given');
          process.exit(1);
        }
        opts.file = arg;
    }
    i++;
  }

  if (!opts.file) {
    console.error('error: a CHR-ROM file is required');
    console.error(USAGE);
    process.exit(1);
  }
  if (opts.mode !== 'bitmap' && opts.mode !== 'sprite') {
    console.error(`error: --mode must be "bitmap" or "sprite", got "${opts.mode}"`);
    process.exit(1);
  }
  if (opts.format !== 'bin' && opts.format !== 'merlin') {
    console.error(`error: --format must be "bin" or "merlin", got "${opts.format}"`);
    process.exit(1);
  }
  if (!opts.label) {
    opts.label = path.basename(opts.file, path.extname(opts.file))
      .replace(/[^A-Za-z0-9_]/g, '_')
      .replace(/^([0-9])/, '_$1') + '_tiles';
  }

  return opts;
}

function convertAllTiles(chr, mode, offset, count) {
  const convert = mode === 'sprite' ? convertRomTile2 : romTileToBitmap;
  const bytesPerTile = mode === 'sprite' ? 128 : 32;

  const available = Math.floor((chr.length - offset) / TILE_SIZE);
  const tileCount = count == null ? available : count;

  if (tileCount < 0 || offset + tileCount * TILE_SIZE > chr.length) {
    throw new Error(
      `requested ${tileCount} tile(s) at offset ${offset}, but the file only has ${available} tile(s) available`
    );
  }

  const out = Buffer.alloc(tileCount * bytesPerTile);
  for (let i = 0; i < tileCount; i++) {
    const tileData = convert(chr, offset + i * TILE_SIZE);
    Buffer.from(tileData).copy(out, i * bytesPerTile);
  }
  return out;
}

function toMerlinSource(label, data, bytesPerTile) {
  const lines = [label];
  for (let i = 0; i < data.length; i += 8) {
    const chunk = data.subarray(i, Math.min(i + 8, data.length));
    const bytes = Array.from(chunk).map(b => '$' + b.toString(16).padStart(2, '0').toUpperCase());
    const tileNum = Math.floor(i / bytesPerTile);
    const comment = (i % bytesPerTile === 0) ? `  ; tile ${tileNum}` : '';
    lines.push(`            db    ${bytes.join(',')}${comment}`);
  }
  return lines.join('\n') + '\n';
}

function main() {
  const opts = parseArgs(process.argv.slice(2));

  const chr = fs.readFileSync(opts.file);
  const bytesPerTile = opts.mode === 'sprite' ? 128 : 32;
  const data = convertAllTiles(chr, opts.mode, opts.offset, opts.count);

  const output = opts.format === 'bin'
    ? data
    : Buffer.from(toMerlinSource(opts.label, data, bytesPerTile), 'utf8');

  if (opts.output) {
    fs.writeFileSync(opts.output, output);
    console.error(`wrote ${data.length} bytes (${data.length / bytesPerTile} tiles) -> ${opts.output}`);
  } else {
    process.stdout.write(output);
  }
}

main();

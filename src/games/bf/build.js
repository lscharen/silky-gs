#!/usr/bin/env node
'use strict';

/**
 * build.js — Balloon Fight build script
 *
 * Adapted from src/games/dk/build.js (itself from src/games/smb/build.js).  Tile conversion is no longer done by
 * the engine at startup, so the CHR-ROM is pre-processed here into the 64KB
 * tiledata bank (bitmap + mask + mirrored variants for every tile, the same
 * layout ConvertROMTile2 in src/rom/rom_tiles.s produces) and assembled
 * directly into the CHRDATA segment via TileData.s.  Main.s then compiles the
 * background and sprite tiles from that bank after NES_StartUp.
 *
 * BF's CHR-ROM lives in chr.s as `db` lines (it is also assembled into the
 * PPU bank as CHR_ROM), so it is parsed from there rather than requiring a
 * separate chr.bin.  If a chr.bin is present, it takes precedence.
 */

const fs   = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { convertRomTile2 } = require('../../../scripts/lib/nesTileConvert.js');

const GAME_DIR      = __dirname;
const PROJECT_ROOT  = path.resolve(GAME_DIR, '..', '..', '..');
const PACKAGE_JSON  = require(path.join(PROJECT_ROOT, 'package.json'));

const MERLIN32 = PACKAGE_JSON.config.merlin32;
const MACROS   = PACKAGE_JSON.config.macros;

const CHR_BIN   = path.join(GAME_DIR, 'chr.bin');
const CHR_SRC   = path.join(GAME_DIR, 'chr.s');
const TILE_SIZE = 16;

// The 8KB CHR-ROM holds both pattern tables back to back (512 tiles, 16 bytes
// each) -- see Main.s: PPU_SPR_TILE_ADDR=$0000, PPU_BG_TILE_ADDR=$1000.
const TILE_COUNT = 512;
const CHR_SIZE   = TILE_COUNT * TILE_SIZE;
const OUT_FILE   = path.join(GAME_DIR, 'tiledata.bin');

// Extract the bytes from the `db $xx,$xx,...` lines of a Merlin32 source file
function parseChrSource(file) {
  const bytes = [];
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const code = line.split(';')[0];
    const m = code.match(/^\s*db\s+(.*)$/i);
    if (!m) continue;
    for (const tok of m[1].split(',')) {
      const t = tok.trim();
      if (!/^\$[0-9a-f]{1,2}$/i.test(t)) {
        throw new Error(`${path.basename(file)}: unexpected db operand '${t}'`);
      }
      bytes.push(parseInt(t.slice(1), 16));
    }
  }
  return Buffer.from(bytes);
}

function loadChr() {
  if (fs.existsSync(CHR_BIN)) {
    console.log('Reading CHR-ROM from chr.bin');
    return fs.readFileSync(CHR_BIN);
  }
  console.log('Reading CHR-ROM from chr.s');
  return parseChrSource(CHR_SRC);
}

function generateChrTables() {
  const chr = loadChr();
  if (chr.length !== CHR_SIZE) {
    throw new Error(`CHR-ROM is ${chr.length} bytes, expected ${CHR_SIZE}`);
  }

  console.log('Generating precomputed CHR-ROM tile data...');
  const out = Buffer.alloc(TILE_COUNT * 128);
  for (let i = 0; i < TILE_COUNT; i++) {
    Buffer.from(convertRomTile2(chr, i * TILE_SIZE)).copy(out, i * 128);
  }
  fs.writeFileSync(OUT_FILE, out);
  console.log(`  wrote ${path.basename(OUT_FILE)} (${TILE_COUNT} tiles, ${out.length} bytes)`);
}

function run(cmd, args) {
  console.log(`> ${cmd} ${args.join(' ')}`);
  execFileSync(cmd, args, { stdio: 'inherit', cwd: PROJECT_ROOT });
}

function main() {
  generateChrTables();

  run(process.execPath, [path.join(PROJECT_ROOT, 'scripts', 'gen-includes.js'), path.join(GAME_DIR, 'Main.s')]);
  run(MERLIN32, ['-V', MACROS, path.join(GAME_DIR, 'BF.s')]);
}

main();

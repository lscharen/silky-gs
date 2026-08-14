#!/usr/bin/env node
'use strict';

/**
 * build.js — SMB build script
 *
 * Replaces the old top-level "build:smb" npm script, which hardcoded a
 * gen-includes + merlin32 invocation directly in package.json. Deferring
 * to a per-game script keeps package.json from having to grow a new
 * ad-hoc command every time a game's build needs an extra step.
 *
 * Also runs the CHR-ROM pre-processing step: converts the raw CHR-ROM
 * binary (chr.bin) into the same static bitmap/sprite conversion tables
 * ROMTileToBitmap/ConvertROMTile2 (src/rom/rom_tiles.s) compute at runtime
 * -- see scripts/lib/nesTileConvert.js, the proven-faithful JS transliteration
 * those routines are checked against. SMB's CHR data never changes at
 * runtime (HAS_CHR_RAM equ 0), so there is no reason to pay that conversion
 * cost on every boot; the tables generated here can be assembled directly
 * into the ROM image instead.
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

// Raw CHR-ROM binary (one byte per pattern-table byte, iNES-header-free --
// same shape scripts/convert-chr-rom.js expects). Not committed yet; will be
// added alongside this script.
const CHR_FILE  = path.join(GAME_DIR, 'chr.bin');
const TILE_SIZE = 16;

// The 8KB CHR-ROM binary holds both pattern tables back to back (512 tiles
// total, 16 bytes each) -- see src/games/smb/Main.s: PPU_SPR_TILE_ADDR=$0000,
// PPU_BG_TILE_ADDR=$1000.
const TILE_COUNT  = 512;
const OUT_FILE    = path.join(GAME_DIR, 'tiledata.bin');

function generateChrTables() {
  if (!fs.existsSync(CHR_FILE)) {
    console.log(`CHR-ROM binary not found at ${CHR_FILE} -- skipping precompute step.`);
    return;
  }

  console.log('Generating precomputed CHR-ROM tile data from chr.bin...');
  const chr = fs.readFileSync(CHR_FILE);

  // Every tile uses the full 128-byte layout (bitmap + mask + mirrored
  // variants, same as ConvertROMTile2), regardless of whether it's used as a
  // sprite or background tile -- this is an offline, one-time conversion of
  // the whole 8KB CHR-ROM into the full 64KB bank the runtime expects, so
  // there's no reason to special-case either range down to a smaller layout.
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
  run(MERLIN32, ['-V', MACROS, path.join(GAME_DIR, 'SMB.s')]);
}

main();

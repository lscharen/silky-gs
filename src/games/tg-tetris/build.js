#!/usr/bin/env node
'use strict';

/**
 * build.js -- Tengen Tetris build script
 *
 * The ROM source (rom_code.s, ram.s, abs_y.s) and the CHR-ROM banks (chr0.bin, chr1.bin) come from the
 * ca65 disassembly through tools/convert.js; run it again after changing the converter's patches.
 *
 * 1. Generate the palette management (palettes.s, pal_transitions.s, pal_defs.s) from palettes/ --
 *    see scripts/generate-palette-transitions.js.  Skipped when the generated files are newer than
 *    the palette files.
 * 2. Convert the CHR-ROM (bank 0, which PPU.s holds at power on) into the tiledata bank and assemble
 *    the game (scripts/lib/nromBuild.js).  Both CHR-ROM banks are in the ROM segment (rom.s); the game
 *    loads the one the ROM selects at run time (CheckCHRBank, Main.s).
 * 3. Check that the assembled ROM is the original everywhere the patches don't change it
 *    (tools/verify.js).
 */

const path = require('path');
const { generatePalettes, PaletteError } = require('../../../scripts/generate-palette-transitions.js');
const { buildNromGame } = require('../../../scripts/lib/nromBuild.js');
const { verifyRom } = require('./tools/verify.js');

const palettesDir = path.join(__dirname, 'palettes');
try {
  generatePalettes({
    transitionsFile: path.join(palettesDir, 'transitions.txt'),
    palettesDir,
    outDir: __dirname,
  });
} catch (e) {
  if (!(e instanceof PaletteError)) throw e;
  console.error(`Error: ${e.message}`);
  process.exit(1);
}

buildNromGame(__dirname, 'Master.s');

if (!verifyRom(__dirname)) process.exit(1);

#!/usr/bin/env node
'use strict';

/**
 * build.js — The Legend of Zelda build script
 *
 * Zelda is an MMC1 game with CHR-RAM: its tile data is uploaded by the ROM at
 * runtime through PPUDATA writes, so there is no CHR-ROM to pre-convert into a
 * tiledata bank (the NROM games' generateTileData step).
 *
 * 1. Generate the palette management (src/palettes.s for the PALDATA segment and
 *    src/pal_transitions.s for the main segment) from the palette files in
 *    palettes/ -- see scripts/generate-palette-transitions.js.  This is skipped
 *    when the generated files are newer than the palette files.
 * 2. The shared assemble step: expand the mput blocks in src/Main.s and assemble
 *    the src/Master.s link file.  See scripts/lib/nromBuild.js.
 * 3. Take the zeros out of the load file (scripts/omf-compact.js), and make the PPU
 *    memory and tiledata segments whole banks, so they start at $0000.
 */

const path = require('path');
const { generatePalettes, PaletteError } = require('../../../scripts/generate-palette-transitions.js');
const { assembleGame } = require('../../../scripts/lib/nromBuild.js');
const { compactFile } = require('../../../scripts/omf-compact.js');

const palettesDir = path.join(__dirname, 'palettes');
try {
  generatePalettes({
    transitionsFile: path.join(palettesDir, 'transitions.txt'),
    palettesDir,
    outDir: path.join(__dirname, 'src'),
  });
} catch (e) {
  if (!(e instanceof PaletteError)) throw e;
  console.error(`Error: ${e.message}`);
  process.exit(1);
}

assembleGame(path.join(__dirname, 'src'), 'Master.s');

const app = path.join(__dirname, 'src', 'ZeldaGS');
console.log('Compacting ZeldaGS');
compactFile(app, app, ['PPURAM', 'CHRDATA']);

#!/usr/bin/env node
'use strict';

/**
 * build.js — engine benchmark build script
 *
 * 1. Generate the scene (scene.s for the ROM segment, sprites.s for the main segment) from Super
 *    Mario Bros. data -- see make-scene.js.
 * 2. Generate the palette management (palettes.s for the PALDATA segment and pal_transitions.s for
 *    the main segment) from the palette files in palettes/ -- see
 *    scripts/generate-palette-transitions.js.  This is skipped when the generated files are newer
 *    than the palette files.
 * 3. Convert the CHR-ROM (SMB's, as assembled by PPU.s) into the 64KB tiledata bank (tiledata.bin,
 *    assembled by TileData.s into the CHRDATA segment) and assemble the game.  Main.s compiles
 *    tiles from that bank after NES_StartUp.  See scripts/lib/nromBuild.js.
 */

const path = require('path');
const { makeScene } = require('./make-scene.js');
const { generatePalettes, PaletteError } = require('../../../scripts/generate-palette-transitions.js');
const { buildNromGame } = require('../../../scripts/lib/nromBuild.js');

makeScene(__dirname);

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

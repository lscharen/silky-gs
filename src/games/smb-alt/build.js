#!/usr/bin/env node
'use strict';

/**
 * build.js -- Super Mario Bros. on the tile engine (the example of a game built against src/engines/tile)
 *
 * The game is SMB's (../smb): the same ROM, CHR, palettes and Main.s; only the engine and what it needs differ.
 * 1. Generate the palette management from ../smb/palettes into this folder (pal_defs.s, pal_transitions.s, palettes.s).
 * 2. Convert SMB's CHR-ROM into ../smb/tiledata.bin (the CHRDATA bank, as SMB's own build does).
 * 3. Assemble SMBAlt.s.  assembleGame finds the engine in the link file and runs its generator, src/engines/tile/gen.js, which
 *    reads TileGame.js.  Then compact the load file.
 */

const path = require('path');
const { generatePalettes, PaletteError } = require('../../../scripts/generate-palette-transitions.js');
const { assembleGame, compactGame, generateTileData } = require('../../../scripts/lib/nromBuild.js');

const SMB = path.join(__dirname, '..', 'smb');
try {
  generatePalettes({
    transitionsFile: path.join(SMB, 'palettes', 'transitions.txt'),
    palettesDir: path.join(SMB, 'palettes'),
    outDir: __dirname,
  });
} catch (e) {
  if (!(e instanceof PaletteError)) throw e;
  console.error(`Error: ${e.message}`);
  process.exit(1);
}

generateTileData(SMB);
assembleGame(__dirname, 'SMBAlt.s');
compactGame(__dirname, 'SMBAlt.s', ['PPURAM', 'CHRDATA']);

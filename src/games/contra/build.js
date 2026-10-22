#!/usr/bin/env node
'use strict';

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

const app = path.join(__dirname, 'src', 'ContraGS');
console.log('Compacting ContraGS');
compactFile(app, app, ['PPURAM', 'CHRDATA']);

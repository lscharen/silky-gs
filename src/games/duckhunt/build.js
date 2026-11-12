#!/usr/bin/env node
'use strict';

/**
 * build.js -- Duck Hunt build script
 *
 * The ROM source (rom_code.s, ram.s, abs_y.s) and the CHR-ROM (chr.bin) come from the ca65 disassembly in
 * src/ through tools/convert.js; run it again after changing the converter's patches.
 *
 * 1. Check the conversion: the disassembly without the shims must assemble to the original PRG-ROM
 *    (tools/plain.js).
 * 2. Generate the palette management (palettes.s, pal_transitions.s, pal_defs.s) from palettes/ --
 *    see scripts/generate-palette-transitions.js.  Skipped when the generated files are newer than
 *    the palette files.
 * 3. Convert the CHR-ROM into the tiledata bank and assemble the game (scripts/lib/nromBuild.js).
 * 4. Check the assembled ROM against the original, but for the shims (tools/verify.js).
 */

const path = require('path');
const { generatePalettes, PaletteError } = require('../../../scripts/generate-palette-transitions.js');
const { buildNromGame } = require('../../../scripts/lib/nromBuild.js');
const { plainBuild } = require('./tools/plain.js');
const { verifyRom } = require('./tools/verify.js');

if (!plainBuild()) process.exit(1);

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

if (!verifyRom()) process.exit(1);

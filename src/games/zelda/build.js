#!/usr/bin/env node
'use strict';

/**
 * build.js — The Legend of Zelda build script
 *
 * Zelda is an MMC1 game with CHR-RAM: its tile data is uploaded by the ROM at
 * runtime through PPUDATA writes, so there is no CHR-ROM to pre-convert into a
 * tiledata bank (the NROM games' generateTileData step).  The build is just
 * the shared assemble step: expand the mput blocks in src/Main.s and assemble
 * the src/Master.s link file.  See scripts/lib/nromBuild.js.
 */

const path = require('path');
const { assembleGame } = require('../../../scripts/lib/nromBuild.js');

assembleGame(path.join(__dirname, 'src'), 'Master.s');

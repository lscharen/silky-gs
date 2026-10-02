#!/usr/bin/env node
'use strict';

/**
 * build.js — Excitebike build script
 *
 * Converts the CHR-ROM (as assembled by PPU.s) into the 64KB tiledata bank
 * (tiledata.bin, assembled by TileData.s into the CHRDATA segment) and then
 * assembles the game.  Main.s compiles tiles from that bank after NES_StartUp.
 * See scripts/lib/nromBuild.js.
 */

const { buildNromGame } = require('../../../scripts/lib/nromBuild.js');

buildNromGame(__dirname, 'Master.s');

'use strict';
// TileGame.js -- what the tile engine needs to know about this game (src/engines/tile/gen.js reads it when the game is built).
// A game on the PEA engine doesn't have this file.
//
//   solidTile    The background tile (a nametable byte) that is all color 0 in the background pattern table: cells holding it are
//                skipped on frames that don't change them.  Required.
//   solidCheck   false: trust solidTile without reading the CHR at run time (a CHR-RAM game that knows better).  Default true.
//   stillFrames  What a frame that doesn't scroll draws: 'all' (every cell but the solid tile's) or 'changes' (only what changed).
//                Dynamic tiles need 'all'.  Default 'all'.
//   dynart       Optional: () => { tiles, frames } -- background tiles the engine animates by itself (frames[page][i] is a 16-byte NES
//                tile for tiles[i]), from nesFrameCount.
const fs = require('fs');
const path = require('path');
module.exports = {
    solidTile: 0x24,                    // The sky: all color 0 in the background table, $1000
    stillFrames: 'all',                 // Draw every cell but the sky's on every frame: the dynamic tiles need it
    dynart: () => require('./dynart.js').build(fs.readFileSync(path.join(__dirname, '..', 'smb', 'chr.bin'))),   // The ? block's glyph
};

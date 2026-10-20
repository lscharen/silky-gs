'use strict';

/**
 * make-scene.js — generate the bench's scene from Super Mario Bros. data
 *
 *   scene.s    (ROM segment, bench_rom.s)  BenchPalette: the World 1-1 palette (palette RAM $3F00-$3F1F)
 *                                          BenchNametables: two nametables ($2000, $2400) of a 1-1 style
 *                                          level, 32 metatiles wide, that wraps around
 *   sprites.s  (main segment, Main.s)      BenchOAMInit: the OAM entries (position, tile, attributes)
 *                                          BenchOAMAnim: the tile and attribute bytes of every entry
 *                                          for each step of the walk animation
 *
 * The metatiles, the background scenery and the sprite tiles are SMB's own (src/games/smb/rom.s:
 * Palette0_MTiles .. Palette3_MTiles, BackSceneryData / BackSceneryMetatiles, PlayerGraphicsTable and
 * EnemyGraphicsTable), so the CHR-ROM is SMB's (chr.bin).
 */

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------------------------
// Background

// SMB metatiles: the byte is palette << 6 | index, the tiles are top-left, bottom-left, top-right,
// bottom-right
const METATILES = {
  0x00: [0x24, 0x24, 0x24, 0x24],   // blank
  0x02: [0x24, 0x24, 0x24, 0x35],   // bush left
  0x03: [0x36, 0x25, 0x37, 0x25],   // bush middle
  0x04: [0x24, 0x38, 0x24, 0x24],   // bush right
  0x05: [0x24, 0x30, 0x30, 0x26],   // mountain left
  0x06: [0x26, 0x26, 0x34, 0x26],   // mountain left bottom / middle center
  0x07: [0x24, 0x31, 0x24, 0x32],   // mountain middle top
  0x08: [0x33, 0x26, 0x24, 0x33],   // mountain right
  0x09: [0x34, 0x26, 0x26, 0x26],   // mountain right bottom
  0x0a: [0x26, 0x26, 0x26, 0x26],   // mountain middle bottom
  0x51: [0x45, 0x47, 0x45, 0x47],   // breakable brick with line
  0x54: [0xb4, 0xb6, 0xb5, 0xb7],   // ground (cracked rock terrain)
  0x80: [0x24, 0x24, 0x24, 0x35],   // cloud left
  0x81: [0x36, 0x25, 0x37, 0x25],   // cloud middle
  0x82: [0x24, 0x38, 0x24, 0x24],   // cloud right
  0x83: [0x24, 0x24, 0x39, 0x24],   // cloud bottom left
  0x84: [0x3a, 0x24, 0x3b, 0x24],   // cloud bottom middle
  0x85: [0x3c, 0x24, 0x24, 0x24],   // cloud bottom right
  0xc0: [0x53, 0x55, 0x54, 0x56],   // question block
};

// BackSceneryMetatiles: a column of 3 metatiles for each scenery index (1-9)
const SCENERY_COLUMNS = [
  [0x80, 0x83, 0x00], [0x81, 0x84, 0x00], [0x82, 0x85, 0x00],   // cloud left, middle, right
  [0x02, 0x00, 0x00], [0x03, 0x00, 0x00], [0x04, 0x00, 0x00],   // bush left, middle, right
  [0x00, 0x05, 0x06], [0x07, 0x06, 0x0a], [0x00, 0x08, 0x09],   // mountain left, middle, right
];

// The first two screens of BackSceneryData's "mountains and bushes" (World 1-1).  High nibble = the
// row, low nibble = the scenery index (0 = none).  The second screen ends with a cloud in its last
// column and the first one starts with the big hill, so the two screens wrap around cleanly.
const SCENERY = [
  0x97, 0x87, 0x88, 0x89, 0x99, 0x00, 0x00, 0x00, 0x11, 0x12, 0x13, 0xa4, 0xa5, 0xa5, 0xa5, 0xa6,
  0x97, 0x98, 0x99, 0x01, 0x02, 0x03, 0x00, 0xa4, 0xa5, 0xa6, 0x00, 0x11, 0x12, 0x12, 0x12, 0x13,
];

const COLUMNS = 32;            // metatile columns (two nametables)
const BUFFER_ROWS = 13;        // SMB's metatile buffer: rows 0-12 are metatile rows 2-14 (y = 32 - 239)
const GROUND = 0x54;

// The blocks of World 1-1's first screen (column, buffer row, metatile), no pipes
const BLOCKS = [
  [16, 7, 0xc0],
  [20, 7, 0x51], [21, 7, 0xc0], [22, 7, 0x51], [23, 7, 0xc0], [24, 7, 0x51],
  [22, 3, 0xc0],
];

function buildLevel() {
  const level = [];             // level[col][buffer row] = metatile
  for (let col = 0; col < COLUMNS; col++) {
    const column = new Array(BUFFER_ROWS).fill(0);

    // Background scenery (RenderSceneryTerrain): a column of up to 3 metatiles, stopping at the floor
    const b = SCENERY[col];
    if (b) {
      let row = b >> 4;
      for (const mt of SCENERY_COLUMNS[(b & 0x0f) - 1]) {
        column[row++] = mt;
        if (row === 11) break;
      }
    }

    // A two-row floor (TerrainRenderBits "floor 2"), no gaps
    column[11] = GROUND;
    column[12] = GROUND;
    level.push(column);
  }
  for (const [col, row, mt] of BLOCKS) level[col][row] = mt;
  return level;
}

// Two 1KB nametables: 30 rows of 32 tiles, then the 64 attribute bytes
function buildNametables(level) {
  const nt = Buffer.alloc(2048, 0);
  for (let col = 0; col < COLUMNS; col++) {
    const base = (col >> 4) * 1024;
    const mx = col & 15;
    for (let my = 0; my < 15; my++) {
      const row = my - 2;
      const mt = row >= 0 ? level[col][row] : 0;
      const tiles = METATILES[mt];
      if (!tiles) throw new Error(`no tiles for metatile $${mt.toString(16)}`);
      const tx = mx * 2, ty = my * 2;
      nt[base + ty * 32 + tx] = tiles[0];
      nt[base + (ty + 1) * 32 + tx] = tiles[1];
      nt[base + ty * 32 + tx + 1] = tiles[2];
      nt[base + (ty + 1) * 32 + tx + 1] = tiles[3];

      const pal = mt >> 6;
      const shift = ((my & 1) << 2) | ((mx & 1) << 1);
      nt[base + 960 + (my >> 1) * 8 + (mx >> 1)] |= pal << shift;
    }
  }
  return nt;
}

// SMB's GroundPaletteData (palettes/ground.txt).  Color 0 is the sky.
const PALETTE = [
  0x22, 0x29, 0x1a, 0x0f,  0x22, 0x36, 0x17, 0x0f,  0x22, 0x30, 0x21, 0x0f,  0x22, 0x27, 0x17, 0x0f,
  0x22, 0x16, 0x27, 0x18,  0x22, 0x1a, 0x30, 0x27,  0x22, 0x16, 0x30, 0x27,  0x22, 0x0f, 0x36, 0x17,
];

// ---------------------------------------------------------------------------------------------
// Sprites
//
// Four figures stand still on the ground (y = 208) while the level scrolls under them: big Mario in
// the middle, then Bowser, a Koopa Troopa and a Goomba behind him.  All of them face right.  A figure
// is a grid of 8x8 sprites (rows of [left, right] tiles, null = no sprite); a frame lists the grid's
// tiles and the OAM attributes.  Bowser is two of SMB's enemy objects: the front half is 8 pixels
// higher than the rear half.

const BLANK = null;
const H_FLIP = 0x40;

const FIGURES = [
  {
    name: 'Mario', x: 120, y: 208 - 32, cols: 2,
    // PlayerGraphicsTable, big player walking frames 1-3 (palette 0)
    frames: [
      { attr: 0, tiles: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07] },
      { attr: 0, tiles: [0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f] },
      { attr: 0, tiles: [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17] },
    ],
  },
  {
    // EnemyGraphicsTable: bowser front.  The table has Bowser's tiles in the order that faces right
    // when they are not flipped (SMB draws him flipped, facing left).  Palette 1.
    name: 'Bowser front', x: 92, y: 208 - 32, cols: 2,
    frames: [
      { attr: 1, tiles: [0xbf, 0xbe, 0xc1, 0xc0, 0xc2, BLANK] },
      { attr: 1, tiles: [0xbf, 0xbe, 0xca, 0xc9, 0xc2, BLANK] },
    ],
  },
  {
    name: 'Bowser rear', x: 76, y: 208 - 24, cols: 2,
    frames: [
      { attr: 1, tiles: [0xc4, 0xc3, 0xc6, 0xc5, 0xc8, 0xc7] },
      { attr: 1, tiles: [0xc4, 0xc3, 0xc6, 0xc5, 0xcc, 0xcb] },
    ],
  },
  {
    // Koopa troopa frames 1 and 2 (palette 1)
    name: 'Koopa', x: 48, y: 208 - 24, cols: 2,
    frames: [
      { attr: 1, tiles: [BLANK, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9] },
      { attr: 1, tiles: [BLANK, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4] },
    ],
  },
  {
    // The goomba has one picture: it walks by flipping it (palette 3)
    name: 'Goomba', x: 20, y: 208 - 16, cols: 2,
    frames: [
      { attr: 3, tiles: [0x70, 0x71, 0x72, 0x73] },
      { attr: 3 | H_FLIP, tiles: [0x71, 0x70, 0x73, 0x72] },
    ],
  },
];

// The walk animation steps: Mario has 3 frames and the others 2, so 6 steps go through all of them,
// and every figure changes its frame on every step
const ANIM_STEPS = 6;

function buildSprites() {
  const oam = [];               // { name, x, y, tile[step], attr[step] }
  for (const fig of FIGURES) {
    const cells = fig.frames[0].tiles.length;
    for (let k = 0; k < cells; k++) {
      if (fig.frames.some(f => f.tiles[k] === BLANK) && !fig.frames.every(f => f.tiles[k] === BLANK)) {
        throw new Error(`${fig.name}: cell ${k} is blank in some frames only`);
      }
      if (fig.frames[0].tiles[k] === BLANK) continue;
      const entry = {
        name: fig.name,
        x: fig.x + (k % fig.cols) * 8,
        y: fig.y + Math.floor(k / fig.cols) * 8 - 1,      // the PPU draws a sprite one line below its OAM Y
        tile: [], attr: [],
      };
      for (let step = 0; step < ANIM_STEPS; step++) {
        const f = fig.frames[step % fig.frames.length];
        entry.tile.push(f.tiles[k]);
        entry.attr.push(f.attr);
      }
      oam.push(entry);
    }
  }
  if (oam.length % 4) throw new Error(`${oam.length} sprites: OAM_END_INDEX needs a multiple of 4`);
  return oam;
}

// ---------------------------------------------------------------------------------------------
// Output

const hex = v => '$' + v.toString(16).toUpperCase().padStart(2, '0');

function hexLines(buf, perLine = 32) {
  const out = [];
  for (let i = 0; i < buf.length; i += perLine) {
    out.push('            hex   ' + [...buf.subarray(i, i + perLine)].map(b => b.toString(16).toUpperCase().padStart(2, '0')).join(''));
  }
  return out.join('\n');
}

function makeScene(dir) {
  const header = '; Generated by make-scene.js (build.js) -- do not edit\n';

  const nt = buildNametables(buildLevel());
  const scene = [
    header,
    '; The World 1-1 palette (palette RAM $3F00 - $3F1F)',
    'BenchPalette',
    hexLines(Buffer.from(PALETTE), 16),
    '',
    '; Nametables $2000 and $2400: a 1-1 style level, two screens that wrap around',
    'BenchNametables',
    hexLines(nt.subarray(0, 1024)),
    hexLines(nt.subarray(1024)),
    '',
  ].join('\n');

  const oam = buildSprites();
  const sprites = [
    header,
    `BENCH_SPRITES   equ ${oam.length}               ; OAM entries used (OAM_END_INDEX)`,
    `BENCH_ANIM_STEPS equ ${ANIM_STEPS}               ; walk animation steps`,
    '',
    '; The OAM entries at the start: Y, tile, attributes, X',
    'BenchOAMInit',
    ...oam.map(e => `            db    ${hex(e.y)},${hex(e.tile[0])},${hex(e.attr[0])},${hex(e.x)}     ; ${e.name}`),
    '',
    '; The tile (low byte) and attributes (high byte) of each OAM entry, for each animation step',
    'BenchOAMAnim',
  ];
  for (let step = 0; step < ANIM_STEPS; step++) {
    sprites.push(`; step ${step}`);
    for (let i = 0; i < oam.length; i += 4) {
      const words = oam.slice(i, i + 4).map(e => '$' + (e.attr[step] << 8 | e.tile[step]).toString(16).toUpperCase().padStart(4, '0'));
      sprites.push(`            dw    ${words.join(',')}`);
    }
  }
  sprites.push('');

  fs.writeFileSync(path.join(dir, 'scene.s'), scene);
  fs.writeFileSync(path.join(dir, 'sprites.s'), sprites.join('\n'));
  console.log(`  wrote scene.s (palette, 2 nametables) and sprites.s (${oam.length} sprites, ${ANIM_STEPS} animation steps)`);
}

module.exports = { makeScene, buildLevel, buildNametables, buildSprites };

if (require.main === module) makeScene(__dirname);

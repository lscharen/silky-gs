'use strict';
// The dynamic tiles' art: SMB's ? block with its glyph sliding left and wrapping around from the right.  frames[page][id] is a 16-byte NES tile, so
// the tile engine's gen.js reads it through TileGame.js.  The block's rim and rivets stay; only the glyph moves.
const TILES = [0x53, 0x54, 0x55, 0x56];     // Top left, top right, bottom left, bottom right
const BG_TABLE = 256;
const GLYPH = { x0: 4, x1: 11, y0: 3, y1: 13 }, FACE = 1;
const INSIDE = { x0: 1, x1: 14 };       // Inside the rim: the glyph wraps here
const SHIFTS = [0, 4, 7, 11];           // Per page, to the left: 14 pixels in 4 steps
function build(chr) {
    const px = (t, x, y) => { const o = (BG_TABLE + TILES[t]) * 16; return ((chr[o + y] >> (7 - x)) & 1) | (((chr[o + 8 + y] >> (7 - x)) & 1) << 1); };
    const block = (x, y) => px((y >> 3) * 2 + (x >> 3), x & 7, y & 7);
    const wide = INSIDE.x1 - INSIDE.x0 + 1;
    const isRivet = (x, y) => (x === 2 || x === 13) && (y === 2 || y === 13);
    const frames = SHIFTS.map(shift => {
        const g = Array.from({ length: 16 }, (_, y) => Array.from({ length: 16 }, (_, x) => block(x, y)));
        for (let y = GLYPH.y0; y <= GLYPH.y1; y++) for (let x = GLYPH.x0; x <= GLYPH.x1; x++) g[y][x] = FACE;
        for (let y = GLYPH.y0; y <= GLYPH.y1; y++) for (let x = GLYPH.x0; x <= GLYPH.x1; x++) {
            const v = block(x, y);
            if (v === FACE) continue;
            const to = INSIDE.x0 + (x - shift - INSIDE.x0 + wide) % wide;
            if (!isRivet(to, y)) g[y][to] = v;       // The rivets stay on top
        }
        return [0, 1, 2, 3].map(t => {
            const out = Buffer.alloc(16);
            for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) {
                const v = g[y + (t >> 1) * 8][x + (t & 1) * 8];
                out[y] |= (v & 1) << (7 - x);
                out[y + 8] |= (v >> 1) << (7 - x);
            }
            return out;
        });
    });
    return { tiles: TILES, frames };
}
module.exports = { build, TILES };
if (require.main === module) {               // node dynart.js: the frames, as text
    const { frames } = build(require('fs').readFileSync(require('path').join(__dirname, '..', 'smb', 'chr.bin')));
    const rows = Array.from({ length: 16 }, () => []);
    for (const f of frames) for (let y = 0; y < 16; y++) {
        let s = '';
        for (let x = 0; x < 16; x++) { const t = f[(y >> 3) * 2 + (x >> 3)], k = 7 - (x & 7), r = y & 7; s += ' .#o'[((t[r] >> k) & 1) | (((t[r + 8] >> k) & 1) << 1)]; }
        rows[y].push(s);
    }
    console.log(rows.map(r => r.join('   ')).join('\n'));
}

/**
 * tests/rom/rom_palette.test.mjs
 *
 * Unit tests for _ClearBlock, _UpdateBlock, and _UpdateDiagonalBlock in
 * src/rom/rom_palette.s.
 *
 * Swizzle table encoding:
 *   output word = pal_y[y] | pal_z[z] | pal_w[w] | pal_x[x]
 *   pal_y → nibble 3 (bits 15-12)
 *   pal_z → nibble 2 (bits 11-8)
 *   pal_w → nibble 1 (bits  7-4)
 *   pal_x → nibble 0 (bits  3-0)
 *
 * Block geometry:
 *   entry[Z=r, X=c] is at byte offset r*ROW_WIDTH + c*COL_WIDTH from block base.
 *   ROW_WIDTH=2, COL_WIDTH=32 → max span = 3*32 + 3*2 = 102; buffer needs 104 bytes.
 *
 * Test palette: NES indices 0..3 → IIgs indices 0, 5, A, F
 *   pal_y = [$0000, $5000, $A000, $F000]
 *   pal_z = [$0000, $0500, $0A00, $0F00]
 *   pal_w = [$0000, $0050, $00A0, $00F0]
 *   pal_x = [$0000, $0005, $000A, $000F]
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT    = process.env.SRC_ROOT;
const ROM_PALETTE = join(SRC_ROOT, 'rom/rom_palette.s');

// Constants the source file depends on via {N*ROW_WIDTH} / {N*COL_WIDTH} expressions.
const CONSTANTS = `\
ROW_WIDTH   equ  2
COL_WIDTH   equ  32
`;

// Stubs for symbols defined in rom_helpers.s that rom_palette.s references.
// These only need to exist (correct sizes/layout); their values don't affect
// _ClearBlock, _UpdateBlock, or _UpdateDiagonalBlock.
const STUBS = `\
FIRST_OPEN_INDEX equ 1
bg0_changed ds    2
bg1_changed ds    2
nes_palette
bg0_palette ds    8
bg1_palette ds    8
bg2_palette ds    8
bg3_palette ds    8
sp0_palette ds    8
sp1_palette ds    8
sp2_palette ds    8
sp3_palette ds    8
current     dw    0,-1,-1,-1
NESPalIndices
BG0_PAL_IDX dw    2, 4, 6
BG1_PAL_IDX dw   10,12,14
BG2_PAL_IDX dw   18,20,22
BG3_PAL_IDX dw   26,28,30
SP0_PAL_IDX dw   34,36,38
SP1_PAL_IDX dw   42,44,46
SP2_PAL_IDX dw   50,52,54
SP3_PAL_IDX dw   58,60,62
ReverseMap  ds   128
`;

// Palette tables for NES→IIgs mapping 0→0, 1→5, 2→A, 3→F.
// Each entry is a 16-bit word with the IIgs index in the appropriate nibble.
const PAL_TABLES = `\
pal_y       dw   $0000,$5000,$A000,$F000
pal_z       dw   $0000,$0500,$0A00,$0F00
pal_w       dw   $0000,$0050,$00A0,$00F0
pal_x       dw   $0000,$0005,$000A,$000F
`;

// blockAt: read the 16-bit little-endian entry at position [z, x] within a Buffer.
function blockAt(buf, z, x) {
  return buf.readUInt16LE(x * 32 + z * 2);
}

// expectedEntry: compute the expected swizzle word for given w, y, z, x palette indices.
function expectedEntry(w, y, z, x) {
  const PAL_Y = [0x0000, 0x5000, 0xA000, 0xF000];
  const PAL_Z = [0x0000, 0x0500, 0x0A00, 0x0F00];
  const PAL_W = [0x0000, 0x0050, 0x00A0, 0x00F0];
  const PAL_X = [0x0000, 0x0005, 0x000A, 0x000F];
  return (PAL_Y[y] | PAL_Z[z] | PAL_W[w] | PAL_X[x]) & 0xFFFF;
}

// ─── shared cpu65816 factory ──────────────────────────────────────────────────

const { sequence } = cpu65816({
  includes:  [ROM_PALETTE],
  assembler: 'merlin32',
  inline: [
    { src: CONSTANTS, placement: 'before' },
    { src: STUBS,     placement: 'after'  },
    { src: PAL_TABLES, placement: 'after' },
  ],
});

// ─── _ClearBlock ──────────────────────────────────────────────────────────────

describe('_ClearBlock', () => {
  test('zeros all 16 entries of a block', async () => {
    const r = await sequence({
      allocMemory: [{ label: 'block', as: 'word', count: 52 }],  // 104 bytes covers max offset
    })
      // Fill block with $FFFF so we can detect partial clears
      .inline(`\
            lda  #$FFFF
            ldx  #102
:loop       sta  block,x
            dex
            dex
            bpl  :loop`, { mx: 0 })
      // Call _ClearBlock with X = block base offset (0)
      .inline('            ldx  #block', { mx: 0 })
      .jsr('_ClearBlock', { mx: 0 })
      .captureMemory({ label: 'block', count: 52, as: 'word' })
      .run();

    const buf = Buffer.from(r.memory['block'].flatMap(w => [w & 0xFF, (w >> 8) & 0xFF]));
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(0x0000);
      }
    }
  });
});

// ─── _UpdateBlock helpers ─────────────────────────────────────────────────────

// Run _UpdateBlock with given constant (w, y) indices and verify all 16 entries.
async function runUpdateBlock(w, y) {
  const A_val = (expectedEntry(w, y, 0, 0)) & 0xFFFF;

  const r = await sequence({
    allocMemory: [{ label: 'block', as: 'word', count: 52 }],
  })
    .inline('            ldx  #block', { mx: 0 })
    .jsr('_ClearBlock', { mx: 0 })
    .inline(`            lda  #${A_val}`, { mx: 0 })
    .inline('            ldx  #block', { mx: 0 })
    .jsr('_UpdateBlock', { mx: 0 })
    .captureMemory({ label: 'block', count: 52, as: 'word' })
    .run();

  const buf = Buffer.from(r.memory['block'].flatMap(v => [v & 0xFF, (v >> 8) & 0xFF]));
  return buf;
}

// ─── _UpdateBlock — single non-zero dimension ─────────────────────────────────

describe('_UpdateBlock — single non-zero dimension', () => {
  test('only W=1, Y=0: A encodes pal_w[1], pal_y[0]', async () => {
    const buf = await runUpdateBlock(1, 0);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(1, 0, z, x));
      }
    }
  });

  test('only Y=1, W=0: A encodes pal_y[1], pal_w[0]', async () => {
    const buf = await runUpdateBlock(0, 1);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(0, 1, z, x));
      }
    }
  });

  test('only Z=1, W=0, Y=0: rows vary by pal_z', async () => {
    // W=0, Y=0 → A=0; Z=1 effect comes from pal_z table, not A
    const buf = await runUpdateBlock(0, 0);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(0, 0, z, x));
      }
    }
  });

  test('only X=1, W=0, Y=0: columns vary by pal_x', async () => {
    // Same as Z test — X/Z variation always present since the tables are always loaded
    const buf = await runUpdateBlock(0, 0);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(0, 0, z, x));
      }
    }
  });
});

// ─── _UpdateBlock — pairs ────────────────────────────────────────────────────

describe('_UpdateBlock — pairs', () => {
  test('W=1, Y=1 (off-diagonal: different constants)', async () => {
    const buf = await runUpdateBlock(1, 1);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(1, 1, z, x));
      }
    }
  });

  test('W=2, Y=1', async () => {
    const buf = await runUpdateBlock(2, 1);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(2, 1, z, x));
      }
    }
  });

  test('W=1, Y=3', async () => {
    const buf = await runUpdateBlock(1, 3);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(1, 3, z, x));
      }
    }
  });

  test('W=3, Y=2', async () => {
    const buf = await runUpdateBlock(3, 2);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(3, 2, z, x));
      }
    }
  });
});

// ─── _UpdateBlock — triples ───────────────────────────────────────────────────

describe('_UpdateBlock — triples', () => {
  test('W=1, Y=2, Z varying (implicit), X=0: first 4 rows only', async () => {
    const buf = await runUpdateBlock(1, 2);
    // All 4 Z rows are exercised (Z always varies); X varies too
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(1, 2, z, x));
      }
    }
  });

  test('W=3, Y=1, all Z and X active', async () => {
    const buf = await runUpdateBlock(3, 1);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(3, 1, z, x));
      }
    }
  });
});

// ─── _UpdateBlock — all four non-zero ────────────────────────────────────────

describe('_UpdateBlock — all four non-zero (W≠X≠Y≠Z)', () => {
  test('W=1, Y=2, Z implicit, X implicit — all 16 entries unique', async () => {
    // W=1 ($0050), Y=2 ($A000), Z sweeps ($0000,$0500,$0A00,$0F00), X sweeps ($0000,$0005,$000A,$000F)
    const buf = await runUpdateBlock(1, 2);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        const got  = blockAt(buf, z, x);
        const want = expectedEntry(1, 2, z, x);
        expect(got, `[Z=${z}, X=${x}]`).toBe(want);
      }
    }
  });

  test('W=3, Y=1, all 16 entries distinct across Z×X grid', async () => {
    const buf = await runUpdateBlock(3, 1);
    const seen = new Set();
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        const got = blockAt(buf, z, x);
        expect(got, `[Z=${z}, X=${x}]`).toBe(expectedEntry(3, 1, z, x));
        seen.add(got);
      }
    }
    // 4 distinct W values × 4 distinct Y values → all 16 nibble combos should be unique
    expect(seen.size).toBe(16);
  });
});

// ─── _UpdateDiagonalBlock ────────────────────────────────────────────────────
//
// _UpdateDiagonalBlock is called when W == Y (same NES palette index for the W
// and Y dimensions). The XBA anti-symmetry means entry[Z=i, X=j] is the byte-
// swap of entry[Z=j, X=i].  Only 10 entries (diagonal + upper triangle) are
// explicitly computed; the other 6 mirror them.

async function runUpdateDiagonalBlock(wy) {
  // For diagonal block W == Y == wy.  A = pal_y[wy] | pal_w[wy].
  const A_val = expectedEntry(wy, wy, 0, 0) & 0xFFFF;

  const r = await sequence({
    allocMemory: [{ label: 'block', as: 'word', count: 52 }],
  })
    .inline('            ldx  #block', { mx: 0 })
    .jsr('_ClearBlock', { mx: 0 })
    .inline(`            lda  #${A_val}`, { mx: 0 })
    .inline('            ldx  #block', { mx: 0 })
    .jsr('_UpdateDiagonalBlock', { mx: 0 })
    .captureMemory({ label: 'block', count: 52, as: 'word' })
    .run();

  return Buffer.from(r.memory['block'].flatMap(v => [v & 0xFF, (v >> 8) & 0xFF]));
}

describe('_UpdateDiagonalBlock — single non-zero W=Y', () => {
  test('W=Y=0: all entries match expectedEntry(0,0,z,x)', async () => {
    const buf = await runUpdateDiagonalBlock(0);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(0, 0, z, x));
      }
    }
  });

  test('W=Y=1: diagonal entries match expected; off-diagonal are byte-swapped', async () => {
    const buf = await runUpdateDiagonalBlock(1);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        const got  = blockAt(buf, z, x);
        const want = expectedEntry(1, 1, z, x);
        expect(got, `[Z=${z}, X=${x}]`).toBe(want);
      }
    }
  });

  test('W=Y=2: all 16 entries correct', async () => {
    const buf = await runUpdateDiagonalBlock(2);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(2, 2, z, x));
      }
    }
  });

  test('W=Y=3: all 16 entries correct', async () => {
    const buf = await runUpdateDiagonalBlock(3);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(buf, z, x), `[Z=${z}, X=${x}]`).toBe(expectedEntry(3, 3, z, x));
      }
    }
  });
});

describe('_UpdateDiagonalBlock — XBA symmetry', () => {
  test('W=Y=1: entry[Z=i,X=j] == byteswap(entry[Z=j,X=i])', async () => {
    const buf = await runUpdateDiagonalBlock(1);
    for (let i = 0; i < 4; i++) {
      for (let j = i + 1; j < 4; j++) {
        const upper = blockAt(buf, i, j);
        const lower = blockAt(buf, j, i);
        const swapped = ((upper & 0xFF) << 8) | ((upper >> 8) & 0xFF);
        expect(lower, `[Z=${j},X=${i}] should be byteswap of [Z=${i},X=${j}]`).toBe(swapped);
      }
    }
  });

  test('W=Y=3: entry[Z=i,X=j] == byteswap(entry[Z=j,X=i])', async () => {
    const buf = await runUpdateDiagonalBlock(3);
    for (let i = 0; i < 4; i++) {
      for (let j = i + 1; j < 4; j++) {
        const upper = blockAt(buf, i, j);
        const lower = blockAt(buf, j, i);
        const swapped = ((upper & 0xFF) << 8) | ((upper >> 8) & 0xFF);
        expect(lower, `[Z=${j},X=${i}] should be byteswap of [Z=${i},X=${j}]`).toBe(swapped);
      }
    }
  });
});

describe('_UpdateDiagonalBlock — pairs and full', () => {
  test('W=Y=1 and W=Y=2 agree with _UpdateBlock for same w==y indices', async () => {
    const diagBuf1 = await runUpdateDiagonalBlock(1);
    const normBuf1 = await runUpdateBlock(1, 1);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(diagBuf1, z, x), `diag[Z=${z},X=${x}] w=y=1`).toBe(blockAt(normBuf1, z, x));
      }
    }

    const diagBuf2 = await runUpdateDiagonalBlock(2);
    const normBuf2 = await runUpdateBlock(2, 2);
    for (let z = 0; z < 4; z++) {
      for (let x = 0; x < 4; x++) {
        expect(blockAt(diagBuf2, z, x), `diag[Z=${z},X=${x}] w=y=2`).toBe(blockAt(normBuf2, z, x));
      }
    }
  });
});

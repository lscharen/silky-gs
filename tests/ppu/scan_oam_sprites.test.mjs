/**
 * tests/ppu/scan_oam_sprites.test.mjs
 *
 * Unit tests for scanOAMSprites in src/ppu/ppu_sprites.s.
 *
 * scanOAMSprites converts NES OAM data into OAM_COPY (IIgs format) and
 * updates the shadow bitmap.  It reads sprites from the direct-page OAM
 * block (DP_OAM), increments each y coordinate by 1 (NES PPU delay),
 * applies the per-game SCAN_OAM_XTRA_FILTER, clips sprites outside the
 * visible window, and sets bits in shadowBitmap0/1 for accepted sprites.
 *
 * NES OAM layout (4 bytes per sprite, stored as two 16-bit words):
 *   lo word (bytes 0-1): tile << 8 | y    (y in low byte, tile in high byte)
 *   hi word (bytes 2-3): x << 8   | attrs (attrs in low byte, x in high byte)
 *
 * After scanOAMSprites:
 *   OAM_COPY contains the same layout with y incremented by 1.
 *   spriteCount = number_of_accepted_sprites × 4 (the Y register value).
 *   shadowBitmap0 has bits set for each scanline row covered by an accepted sprite.
 *
 * Clipping (NO_VERTICAL_CLIP=0):
 *   sprite is accepted when y_offset <= y_val < (max_nes_y-8+1)
 *   i.e.  16 <= (oam_y+1) < 209
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT    = process.env.SRC_ROOT;
const PPU_MACROS  = join(SRC_ROOT, 'ppu/ppu_macros.s');
const PPU_SPRITES = join(SRC_ROOT, 'ppu/ppu_sprites.s');

// ---- assembler constants (placed before includes) ----------------------------

const CONSTANTS = `\
DIRECT_OAM_READ      equ 0
NO_VERTICAL_CLIP     equ 0
OAM_START_INDEX      equ 0
OAM_END_INDEX        equ 64
y_offset             equ 16
max_nes_y            equ 216
NES_PPUCTRL_SPRSIZE  equ $20
CTRL_SPRITE_ENABLE   equ $0001
ControlBits          equ 26
CurrShadowBitmap     equ 46
PPU_OAM              equ 0
`;

// ---- stubs required by ppu_sprites.s but not defined in the tested file ------
// _ppuctrl: PPU control register mirror (defined in ppu.s; stubbed here).
// DP_OAM:   16-bit address of the direct-page OAM memory block.
//   Unwritten entries default to 0: y=0 → after +1=1 < y_offset(16) → skipped.
const DP_OAM = 0x2000;
const STUBS = `\
_ppuctrl  ds   2
DP_OAM    dw   $2000        ; Bank 00 address of the direct page memory for copying OAM
`;

// ---- filter macro variants ---------------------------------------------------

// Accept every sprite (carry set = not skipped).
const FILTER_ACCEPT_ALL = `\
SCAN_OAM_XTRA_FILTER mac
                     sec
                     <<<
`;

// Reject sprites whose tile byte is $FC (mirrors the SMB filter).
// After `inc`, A = (tile << 8) | (y+1).  XOR tile with $FC; if tile was $FC
// the high byte becomes $00 and cmp #$0100 clears carry → sprite skipped.
const FILTER_REJECT_FC = `\
SCAN_OAM_XTRA_FILTER mac
                     eor  #$FC00
                     cmp  #$0100
                     <<<
`;

// ---- runner factories --------------------------------------------------------

function makeRunner(filterMacro) {
  return cpu65816({
    includes:  [PPU_MACROS, PPU_SPRITES],
    assembler: 'merlin32',
    inline: [
      { src: CONSTANTS + filterMacro, placement: 'before' },
      { src: STUBS,                   placement: 'after'  },
    ],
  });
}

// ---- state setup helper ------------------------------------------------------
//
// Writes into the test's direct page and oam_block before calling scanOAMSprites.
//
// sprites: array of { y, tile, attrs, x } — NES OAM byte values for entries
//   starting at OAM index 0.  y is the raw byte (scanOAMSprites adds 1).
//   Unused entries stay as 0, which are skipped (y+1=1 < y_offset=16).
// spriteEnable: whether CTRL_SPRITE_ENABLE is set in ControlBits.
// ppuctrl: value for _ppuctrl (bit 5 = NES_PPUCTRL_SPRSIZE for 8x16 mode).

function setupState(seq, { sprites = [], spriteEnable = true, ppuctrl = 0 } = {}) {
  const h4 = n => `$${(n & 0xFFFF).toString(16).padStart(4, '0').toUpperCase()}`;

  const lines = [
    '            rep  #$30',
    '            mx   %00',
    `            lda  #${spriteEnable ? '$0001' : '$0000'}`,
    '            sta  ControlBits',
    '            lda  #shadowBitmap0',
    '            sta  CurrShadowBitmap',
    `            lda  #${h4(ppuctrl)}`,
    '            stal _ppuctrl',
  ];

  for (const [i, sp] of sprites.entries()) {
    const loWord = ((sp.tile & 0xFF) << 8) | (sp.y   & 0xFF);
    const hiWord = ((sp.x    & 0xFF) << 8) | (sp.attrs & 0xFF);
    lines.push(`            lda  #${h4(loWord)}`);
    lines.push(`            stal ${h4(DP_OAM)}+${i * 4}`);
    lines.push(`            lda  #${h4(hiWord)}`);
    lines.push(`            stal ${h4(DP_OAM)}+${i * 4 + 2}`);
  }

  return seq.inline(lines.join('\n'), { mx: 0 });
}

// ===========================================================================
// Tests — FILTER_ACCEPT_ALL (sec): no extra filtering
// ===========================================================================

describe('scanOAMSprites — basic 8x8 mode', () => {
  const { sequence } = makeRunner(FILTER_ACCEPT_ALL);

  // -------------------------------------------------------------------------
  // spriteCount and OAM_COPY values
  // -------------------------------------------------------------------------

  test('one visible sprite: spriteCount=4 and OAM_COPY holds incremented entry', async () => {
    // OAM byte y=15 → after +1 = 16 = y_offset (lower clip boundary, inclusive).
    // tile=$05, attrs=$02, x=$20.
    // lo word into oam_block: (tile<<8)|y = $050F
    // hi word into oam_block: (x<<8)|attrs = $2002
    // After scanOAMSprites: OAM_COPY lo word = $0510 (y incremented to $10=16)
    //                       OAM_COPY hi word = $2002 (unchanged)
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [{ y: 0x0F, tile: 0x05, attrs: 0x02, x: 0x20 }],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .captureMemory({ label: 'OAM_COPY', count: 2, as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(4);
    expect(r.memory.OAM_COPY[0]).toBe(0x0510);  // y=16, tile=$05
    expect(r.memory.OAM_COPY[1]).toBe(0x2002);  // attrs=$02, x=$20
  });

  test('three visible sprites: spriteCount=12', async () => {
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [
          { y: 0x0F, tile: 0x01, attrs: 0x00, x: 0x08 },  // y_val=16 accepted
          { y: 0x20, tile: 0x02, attrs: 0x00, x: 0x10 },  // y_val=33 accepted
          { y: 0x40, tile: 0x03, attrs: 0x00, x: 0x18 },  // y_val=65 accepted
        ],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(12);
  });

  // -------------------------------------------------------------------------
  // CTRL_SPRITE_ENABLE flag
  // -------------------------------------------------------------------------

  test('sprites disabled: spriteCount=0 regardless of OAM content', async () => {
    const r = await sequence()
      .step(s => setupState(s, {
        sprites:       [{ y: 0x0F, tile: 0x01, attrs: 0x00, x: 0x10 }],
        spriteEnable:  false,
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(0);
  });

  // -------------------------------------------------------------------------
  // y-coordinate clipping
  // -------------------------------------------------------------------------

  test('sprite just below y_offset is clipped: y_val=15 < 16 → skipped', async () => {
    // oam y byte = 14 → after +1 = 15 < y_offset(16)
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [{ y: 0x0E, tile: 0x01, attrs: 0x00, x: 0x10 }],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(0);
  });

  test('sprite at upper clip boundary is clipped: y_val=209 >= (max_nes_y-8+1) → skipped', async () => {
    // max_nes_y=216, clip threshold = 216-8+1 = 209
    // oam y byte = 208 → after +1 = 209 → skipped
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [{ y: 0xD0, tile: 0x01, attrs: 0x00, x: 0x10 }],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(0);
  });

  test('sprite just inside upper clip: y_val=208 < 209 → accepted', async () => {
    // oam y byte = 207 → after +1 = 208 < 209 → accepted
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [{ y: 0xCF, tile: 0x01, attrs: 0x00, x: 0x10 }],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(4);
  });

  // -------------------------------------------------------------------------
  // Shadow bitmap bit patterns
  //
  // y2idx maps (y_val*2) → 16-bit byte offset within the 32-byte shadow bitmap.
  // y2bits maps (y_val*2) → 16-bit OR pattern to apply at that offset.
  //
  // Table layout (both are word arrays indexed by y_val*2):
  //   y2idx  byte offsets  0..15 → $0000,  16..31 → $0001,  32..47 → $0002, ...
  //   y2bits byte offsets  0..15 → $00FF,  16..31 → $807F,  32..47 → $C03F, ...
  //   (y2bits pattern repeats every 128 bytes = 64 entries = 32 distinct y values)
  // -------------------------------------------------------------------------

  test('shadow bitmap: accepted sprite at y_val=16 sets correct bits', async () => {
    // y_val=16:
    // → shadowBitmap0 word[1] = $00FF; all other words = 0.
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [{ y: 0x0F, tile: 0x01, attrs: 0x00, x: 0x10 }],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'shadowBitmap0', count: 16, as: 'word' })
      .run();

    const bm = r.memory.shadowBitmap0;
    expect(bm[0]).toBe(0x0000);
    expect(bm[1]).toBe(0x00FF);
    for (let i = 2; i < 16; i++) {
      expect(bm[i], `bitmap word ${i}`).toBe(0);
    }
  });

  test('shadow bitmap: two sprites at different y rows set independent bits', async () => {
    // sprite 0: y_val=16
    // sprite 1: y_val=32
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [
          { y: 0x0F, tile: 0x01, attrs: 0x00, x: 0x08 },  // y_val=16
          { y: 0x1F, tile: 0x02, attrs: 0x00, x: 0x18 },  // y_val=32
        ],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'shadowBitmap0', count: 16, as: 'word' })
      .run();

    const bm = r.memory.shadowBitmap0;
    expect(bm[1]).toBe(0x00FF);   // y_val=16
    expect(bm[2]).toBe(0x00FF);   // y_val=32
  });

  test('shadow bitmap: two sprites at overlapping y rows set merged bits', async () => {
    // sprite 0: y_val=17
    // sprite 1: y_val=20
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [
          { y: 0x10, tile: 0x01, attrs: 0x00, x: 0x08 },  // y_val=16
          { y: 0x13, tile: 0x02, attrs: 0x00, x: 0x18 },  // y_val=32
        ],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'shadowBitmap0', count: 16, as: 'word' })
      .run();

    const bm = r.memory.shadowBitmap0;
    expect(bm[1]).toBe(0xF07F);   // y_val=16, 19 -> 0111 1111 1111 0000
  });

  test('shadow bitmap: skipped sprite leaves bitmap zero', async () => {
    const r = await sequence()
      .step(s => setupState(s, { sprites: [{ y: 0x00, tile: 0x01, attrs: 0x00, x: 0x10 }] }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'shadowBitmap0', count: 16, as: 'word' })
      .run();

    for (let i = 0; i < 16; i++) {
      expect(r.memory.shadowBitmap0[i], `bitmap word ${i}`).toBe(0);
    }
  });
});

// ===========================================================================
// Tests — FILTER_REJECT_FC: skip sprites whose tile byte is $FC
// ===========================================================================

describe('scanOAMSprites — SCAN_OAM_XTRA_FILTER (tile $FC rejected)', () => {
  const { sequence } = makeRunner(FILTER_REJECT_FC);

  test('sprite with tile=$FC is filtered out → spriteCount=0', async () => {
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [{ y: 0x0F, tile: 0xFC, attrs: 0x00, x: 0x10 }],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(0);
  });

  test('sprite with tile!=$FC passes filter; tile=$FC is rejected', async () => {
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [
          { y: 0x0F, tile: 0xFC, attrs: 0x00, x: 0x08 },  // filtered
          { y: 0x20, tile: 0x05, attrs: 0x00, x: 0x10 },  // accepted
        ],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .captureMemory({ label: 'OAM_COPY',    count: 2, as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(4);  // only one sprite accepted
    // OAM_COPY holds the second sprite (tile=$05, y=$20+1=$21)
    expect(r.memory.OAM_COPY[0]).toBe(0x0521);  // y=$21, tile=$05
  });

  test('all non-FC sprites accepted', async () => {
    const r = await sequence()
      .step(s => setupState(s, {
        sprites: [
          { y: 0x0F, tile: 0x01, attrs: 0x00, x: 0x08 },
          { y: 0x20, tile: 0x02, attrs: 0x00, x: 0x10 },
        ],
      }))
      .jsr('scanOAMSprites')
      .captureMemory({ label: 'spriteCount', as: 'word' })
      .run();

    expect(r.memory.spriteCount).toBe(8);
  });
});

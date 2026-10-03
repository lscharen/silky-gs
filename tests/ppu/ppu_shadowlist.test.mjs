/**
 * tests/ppu/shadow_bitmap_to_list.test.mjs
 *
 * Unit tests for shadowBitmapToList in src/ppu/ppu_shadowlist.s.
 *
 * shadowBitmapToList scans a byte array (accessed through the CurrShadowBitmap
 * direct-page pointer) and converts contiguous runs of set bits into a compact
 * list of half-open [top, bottom) scanline pairs stored in shadowListTop /
 * shadowListBot.  Each byte covers 8 scanlines; bit 7 is the first scanline
 * of the byte (MSB-first ordering).
 *
 * The tests use y_offset_rows=0 and y_height_rows=3 so that 3 bytes map
 * directly to scanlines 0–23 without any leading-byte offset arithmetic.
 *
 * Lookup-table semantics:
 *   offset[b]     = leading zeros from MSB  (first set-bit scanline within byte)
 *   invOffset[b]  = leading ones  from MSB  (first clear-bit scanline within byte)
 *   offsetMask[b] = mask that keeps only bits below the first leading-one run
 *
 * Example traces (each byte = 8 scanlines, byte 0 → scanlines 0-7):
 *
 *   $03 $FF $C0  →  one pair  [6, 18)
 *     byte 0 $03=00000011: offset[3]=6  → top=0+6=6
 *     byte 1 $FF: all set, continue
 *     byte 2 $C0=11000000: invOffset[C0]=2 → bot=16+2=18; offsetMask[C0]=$3F; $C0&$3F=0 (done)
 *
 *   $03 $81 $C0  →  two pairs [6, 9) and [15, 18)
 *     byte 0 $03: top=6
 *     byte 1 $81=10000001: invOffset[81]=1 → bot=8+1=9; mask=$7F; $81&$7F=$01 → new top: 8+offset[1]=8+7=15
 *     byte 2 $C0: invOffset[C0]=2 → bot=16+2=18 (done)
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT      = process.env.SRC_ROOT;
const DEFS = join(SRC_ROOT, 'core/Defs.s');
const PPU_SHADOWLIST = join(SRC_ROOT, 'ppu/ppu_shadowlist.s');

// Use a 3-byte window (scanlines 0–23) with no leading-byte offset for clarity.
const CONSTANTS = `\
y_offset_rows   equ  0
y_height_rows   equ  25
y_offset        equ  0
y_height        equ  200
`;

const sharedConfig = {
  includes:  [PPU_SHADOWLIST, DEFS],
  assembler: 'merlin32',
  allocMemory: [
    { label: 'test_bitmap', as: 'byte', count: 32 }
  ],
  mocks: {
    '_BltRangeLite': { record: true, callType: 'jsr' },
    '_PEISlam':      { record: true, callType: 'jsr' }
  },
  inline: [
    { src: CONSTANTS, placement: 'before' },
  ],
};

// ---------------------------------------------------------------------------
// Helper: inline assembly that points CurrShadowBitmap at test_bitmap and
// writes `bytes` into the first N byte positions of the bitmap.
// ---------------------------------------------------------------------------
function setupBitmap(seq, bytes) {
  if (Array.isArray(bytes) && bytes.length > 32) {
    throw new Error('Test bitmap is limited to 32 bytes');
  }

  seq = seq
    .inline('            lda  #test_bitmap', { mx: 0})
    .inline('            sta  CurrShadowBitmap')

  // If passing a single byte, fill it all with that value, otherwise copy the array
  if (typeof bytes === 'number') {
    bytes = Array(32).fill(bytes);
  }

  seq.inline('', { mx: 2 });
  bytes.forEach((b, i) => {
    seq = seq
      .inline(`            lda  #$${b.toString(16).padStart(2, '0').toUpperCase()}`)
      .inline(`            sta  test_bitmap+${i}`);
  });
  return seq;
}

// ---------------------------------------------------------------------------
// Helper: inline assembly that writes count/tops/bots directly into the
// shadowList arrays, bypassing shadowBitmapToList.
// ---------------------------------------------------------------------------
function setupShadowList(seq, { count, tops = [], bots = [] }) {
  seq = seq
    .inline(`            lda  #${count}`, { mx: 0 })
    .inline(`            sta  shadowListCount`);

  seq.inline('', { mx: 2 });
  tops.forEach((v, i) => {
    seq = seq
      .inline(`            lda  #$${v.toString(16).padStart(2, '0').toUpperCase()}`)
      .inline(`            sta  shadowListTop+${i}`);
  });
  bots.forEach((v, i) => {
    seq = seq
      .inline(`            lda  #$${v.toString(16).padStart(2, '0').toUpperCase()}`)
      .inline(`            sta  shadowListBot+${i}`);
  });
  return seq;
}

describe('shadowBitmapToList', () => {
  const runner = cpu65816(sharedConfig);

  // ---------------------------------------------------------------------------
  // Test 1 — all-zero bitmap: no ranges
  // ---------------------------------------------------------------------------
  test('shadowListCount is 0 when bitmap is all zeros', async () => {
    let seq = runner.sequence();
    seq = setupBitmap(seq, 0x00);
    const r = await seq
      .jsr('shadowBitmapToList', { mx: 2 })
      .captureMemory({ label: 'shadowListCount', as: 'word' })
      .run();

    expect(r.memory['shadowListCount']).toBe(0);
  });

  // ---------------------------------------------------------------------------
  // Test 2 — single contiguous run spanning byte boundaries: [6, 18)
  //   $03 $FF $C0
  // ---------------------------------------------------------------------------
  test('$03 $FF $C0 produces one pair [6, 18)', async () => {
    let seq = runner.sequence();
    seq = setupBitmap(seq, [0x03, 0xFF, 0xC0]);
    const r = await seq
      .jsr('shadowBitmapToList', { mx: 2 })
      .captureMemory({ label: 'shadowListCount', as: 'word' })
      .captureMemory({ label: 'shadowListTop',   count: 2, as: 'byte' })
      .captureMemory({ label: 'shadowListBot',   count: 2, as: 'byte' })
      .run();

    expect(r.memory['shadowListCount']).toBe(1);
    expect(r.memory['shadowListTop'][0]).toBe(6);
    expect(r.memory['shadowListBot'][0]).toBe(18);
  });

  // ---------------------------------------------------------------------------
  // Test 3 — two separated runs: [6, 9) and [15, 18)
  //   $03 $81 $C0
  // ---------------------------------------------------------------------------
  test('$03 $81 $C0 produces two pairs [6,9) and [15,18)', async () => {
    let seq = runner.sequence();
    seq = setupBitmap(seq, [0x03, 0x81, 0xC0]);
    const r = await seq
      .jsr('shadowBitmapToList', { mx: 2 })
      .captureMemory({ label: 'shadowListCount', as: 'word' })
      .captureMemory({ label: 'shadowListTop',   count: 2, as: 'byte' })
      .captureMemory({ label: 'shadowListBot',   count: 2, as: 'byte' })
      .run();

    expect(r.memory['shadowListCount']).toBe(2);
    expect(r.memory['shadowListTop'][0]).toBe(6);
    expect(r.memory['shadowListBot'][0]).toBe(9);
    expect(r.memory['shadowListTop'][1]).toBe(15);
    expect(r.memory['shadowListBot'][1]).toBe(18);
  });

  
  // ---------------------------------------------------------------------------
  // Test 4 — all-ones bitmap: single run (= y_height)
  // ---------------------------------------------------------------------------
  test('all-ones bitmap produces one pair [0, y_height)', async () => {
    let seq = runner.sequence();
    seq = setupBitmap(seq, 0xFF);
    const r = await seq
      .jsr('shadowBitmapToList', { mx: 2 })
      .captureMemory({ label: 'shadowListCount', as: 'word' })
      .captureMemory({ label: 'shadowListTop',   count: 2, as: 'byte' })
      .captureMemory({ label: 'shadowListBot',   count: 2, as: 'byte' })
      .run();

    expect(r.memory['shadowListCount']).toBe(1);
    expect(r.memory['shadowListTop'][0]).toBe(0);
    expect(r.memory['shadowListBot'][0]).toBe(200);  // y_height
  });

  // ---------------------------------------------------------------------------
  // Test 5 — run that starts mid-bitmap and extends to the end: [8, 24)
  //   $00 $FF $FF
  // ---------------------------------------------------------------------------
  test('$00 $FF $FF produces one pair [8, y_height)', async () => {
    let seq = runner.sequence();
    seq = setupBitmap(seq, [0x00, 0xFF, 0xFF]);
    const r = await seq
      .jsr('shadowBitmapToList', { mx: 2 })
      .captureMemory({ label: 'shadowListCount', as: 'word' })
      .captureMemory({ label: 'shadowListTop',   count: 2, as: 'byte' })
      .captureMemory({ label: 'shadowListBot',   count: 2, as: 'byte' })
      .run();

    expect(r.memory['shadowListCount']).toBe(1);
    expect(r.memory['shadowListTop'][0]).toBe(8);
    expect(r.memory['shadowListBot'][0]).toBe(24);
  });
});


// ===========================================================================
// drawShadowList — calls _BltRangeLite once per shadow-list entry
// ===========================================================================
describe('drawShadowList', () => {
  const runner = cpu65816(sharedConfig);

  // ---------------------------------------------------------------------------
  // Test 6 — empty shadow list: no _BltRangeLite calls
  // ---------------------------------------------------------------------------
  test('_BltRangeLite and _PEISlam not called when shadowListCount=0', async () => {
    let seq = runner.sequence();
    seq = setupShadowList(seq, { count: 0 });
    const r = await seq
      .jsr('drawShadowList', { mx: 0 })
      .run();

    expect(r.mocks['_BltRangeLite']).toHaveLength(0);
    expect(r.mocks['_PEISlam']).toHaveLength(0);
  });

  // ---------------------------------------------------------------------------
  // Test 7 — one segment [6, 18): _BltRangeLite called once with X=6, Y=18
  // ---------------------------------------------------------------------------
  test('one segment [6, 18)', async () => {
    let seq = runner.sequence();
    seq = setupShadowList(seq, { count: 1, tops: [6], bots: [18] });
    const r = await seq
      .jsr('drawShadowList', { mx: 0 })
      .run();

    expect(r.mocks['_BltRangeLite']).toHaveLength(1);
    expect(r.mocks['_BltRangeLite'][0].X).toBe(6);
    expect(r.mocks['_BltRangeLite'][0].Y).toBe(18);
    expect(r.mocks['_PEISlam']).toHaveLength(0);
  });

  // ---------------------------------------------------------------------------
  // Test 8 — two segments [6, 9) and [15, 18)
  // ---------------------------------------------------------------------------
  test('two segments [6,9) and [15,18)', async () => {
    let seq = runner.sequence();
    seq = setupShadowList(seq, { count: 2, tops: [6, 15], bots: [9, 18] });
    const r = await seq
      .jsr('drawShadowList', { mx: 0 })
      .run();

    expect(r.mocks['_BltRangeLite']).toHaveLength(2);
    expect(r.mocks['_BltRangeLite'][0].X).toBe(6);
    expect(r.mocks['_BltRangeLite'][0].Y).toBe(9);
    expect(r.mocks['_BltRangeLite'][1].X).toBe(15);
    expect(r.mocks['_BltRangeLite'][1].Y).toBe(18);
    expect(r.mocks['_PEISlam']).toHaveLength(0);
  });
});

// ===========================================================================
// exposeShadowList — interleaves _BltRangeLite (background gaps) and
// _PEISlam (sprite ranges), with a final _BltRangeLite(last, y_height)
// ===========================================================================
describe('exposeShadowList', () => {
  const runner = cpu65816(sharedConfig);

  // ---------------------------------------------------------------------------
  // Test 9 — empty shadow list: one final _BltRangeLite(0, y_height)
  // ---------------------------------------------------------------------------
  test('empty list: one background call', async () => {
    let seq = runner.sequence();
    seq = setupShadowList(seq, { count: 0 });
    const r = await seq
      .jsr('exposeShadowList', { mx: 0 })
      .run();

    expect(r.mocks['_BltRangeLite']).toHaveLength(1);
    expect(r.mocks['_BltRangeLite'][0].X).toBe(0);
    expect(r.mocks['_BltRangeLite'][0].Y).toBe(200);
    expect(r.mocks['_PEISlam']).toHaveLength(0);
  });

  // ---------------------------------------------------------------------------
  // Test 10 — one segment [6, 18):
  //   _BltRangeLite(0,6), _PEISlam(6,18), _BltRangeLite(18,200)
  // ---------------------------------------------------------------------------
  test('one segment [6, 18)', async () => {
    let seq = runner.sequence();
    seq = setupShadowList(seq, { count: 1, tops: [6], bots: [18] });
    const r = await seq
      .jsr('exposeShadowList', { mx: 0 })
      .run();

    expect(r.mocks['_BltRangeLite']).toHaveLength(2);
    expect(r.mocks['_BltRangeLite'][0].X).toBe(0);
    expect(r.mocks['_BltRangeLite'][0].Y).toBe(6);
    expect(r.mocks['_BltRangeLite'][1].X).toBe(18);
    expect(r.mocks['_BltRangeLite'][1].Y).toBe(200);

    expect(r.mocks['_PEISlam']).toHaveLength(1);
    expect(r.mocks['_PEISlam'][0].X).toBe(6);
    expect(r.mocks['_PEISlam'][0].Y).toBe(18);
  });

  // ---------------------------------------------------------------------------
  // Test 11 — two segments [6,9) and [15,18):
  //   _BltRangeLite(0,6), _PEISlam(6,9),
  //   _BltRangeLite(9,15), _PEISlam(15,18),
  //   _BltRangeLite(18,200)
  // ---------------------------------------------------------------------------
  test('two segments [6,9) and [15,18)', async () => {
    let seq = runner.sequence();
    seq = setupShadowList(seq, { count: 2, tops: [6, 15], bots: [9, 18] });
    const r = await seq
      .jsr('exposeShadowList', { mx: 0 })
      .run();

    expect(r.mocks['_BltRangeLite']).toHaveLength(3);
    expect(r.mocks['_BltRangeLite'][0].X).toBe(0);
    expect(r.mocks['_BltRangeLite'][0].Y).toBe(6);
    expect(r.mocks['_BltRangeLite'][1].X).toBe(9);
    expect(r.mocks['_BltRangeLite'][1].Y).toBe(15);
    expect(r.mocks['_BltRangeLite'][2].X).toBe(18);
    expect(r.mocks['_BltRangeLite'][2].Y).toBe(200);

    expect(r.mocks['_PEISlam']).toHaveLength(2);
    expect(r.mocks['_PEISlam'][0].X).toBe(6);
    expect(r.mocks['_PEISlam'][0].Y).toBe(9);
    expect(r.mocks['_PEISlam'][1].X).toBe(15);
    expect(r.mocks['_PEISlam'][1].Y).toBe(18);
  });
});

// ===========================================================================
// Draw-then-reveal sequence
//
// drawShadowList renders dirty scanlines into the shadow screen (writes the
// background tile data for those rows).  exposeShadowList then fills the
// background gaps via _BltRangeLite and exposes the already-drawn sprite
// rows via _PEISlam.  Running both in order verifies that the segment is
// drawn before it is revealed.
// ===========================================================================

// ---------------------------------------------------------------------------
// Test 12 — drawShadowList then exposeShadowList with one segment [15, 33)
//
//   drawShadowList:    _BltRangeLite(15, 33)          ← draws the segment
//   exposeShadowList:  _BltRangeLite(0,  15)          ← background before
//                      _PEISlam(15, 33)               ← reveals the segment
//                      _BltRangeLite(33, 200)          ← background after
// ---------------------------------------------------------------------------
describe('draw-then-reveal: drawShadowList then exposeShadowList with [15, 33)', () => {
  const runner = cpu65816(sharedConfig);

  test('segment drawn via _BltRangeLite then revealed via _PEISlam', async () => {
    let seq = runner.sequence();
    seq = setupShadowList(seq, { count: 1, tops: [15], bots: [33] });
    const r = await seq
      .jsr('drawShadowList',   { mx: 0 })
      .jsr('exposeShadowList', { mx: 0 })
      .run();

    // drawShadowList: segment [15, 33) drawn into shadow screen
    expect(r.mocks['_BltRangeLite'][0].X).toBe(15);
    expect(r.mocks['_BltRangeLite'][0].Y).toBe(33);

    // exposeShadowList: background gap before the segment
    expect(r.mocks['_BltRangeLite'][1].X).toBe(0);
    expect(r.mocks['_BltRangeLite'][1].Y).toBe(15);

    // exposeShadowList: segment [15, 33) revealed — must follow the draw above
    expect(r.mocks['_PEISlam']).toHaveLength(1);
    expect(r.mocks['_PEISlam'][0].X).toBe(15);
    expect(r.mocks['_PEISlam'][0].Y).toBe(33);

    // exposeShadowList: background gap after the segment
    expect(r.mocks['_BltRangeLite'][2].X).toBe(33);
    expect(r.mocks['_BltRangeLite'][2].Y).toBe(200);

    expect(r.mocks['_BltRangeLite']).toHaveLength(3);
  });
});

/**
 * tests/ppu/ppudata_write.test.mjs
 *
 * Unit tests for PPUDATA_WRITE ($2007 W) in src/ppu/ppu_regs.s.
 *
 * Each test uses PPUCTRL_WRITE to configure the VRAM address increment, then
 * sets the VRAM address via two PPUADDR_WRITE calls ($20/$00 → $2000), and
 * finally writes bytes through PPUDATA_WRITE.  After each write the internal
 * ppuaddr is advanced by ppuincr, so the destination of successive writes
 * depends on the increment value:
 *
 *   ppuincr = 1  → consecutive bytes land at $2000, $2001, …
 *   ppuincr = 32 → every write skips a row: $2000, $2020, …
 *
 * The nt_list / at_list tests also verify the dirty-queue routing logic.
 * Two conditions must both be true for a write to enqueue an address:
 *
 *   1. The written value differs from the current PPU_MEM byte (change detect).
 *   2. PPU_VERSION differs from the per-tile version shadow at PPU_MEM+TILE_VERSION0
 *      (dedup check).  Both start at 0, so the tests prime PPU_VERSION = 1 via
 *      inline assembly before the first PPUDATA_WRITE.
 *
 * Routing: (addr & $03C0) == $03C0 → at_list (attribute data), else → nt_list
 * (tile data).  Tile data lives at $2000–$23BF; attribute data at $23C0–$23FF.
 */

import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT   = process.env.SRC_ROOT;
const PPU_MACROS = join(SRC_ROOT, 'ppu/ppu_macros.s');
const PPU_REGS   = join(SRC_ROOT, 'ppu/ppu_regs.s');

const CONSTANTS = `\
NAMETABLE_MIRRORING   equ 0
HORIZONTAL_MIRRORING  equ 1
DIRECT_OAM_READ       equ 1
TILE_VERSION0         equ $4000
`;

const STUBS = `\
PPU_MEM              ds    $8000
curr_at_list_end     ds    2
curr_nt_list_end     ds    2
at_list              ds    512
nt_list              ds    512
`;

const PAL_DISPATCH = `\
pal_stub             rts
PPU_PALETTE_DISPATCH dw    pal_stub,pal_stub,pal_stub,pal_stub
                     dw    pal_stub,pal_stub,pal_stub,pal_stub
                     dw    pal_stub,pal_stub,pal_stub,pal_stub
                     dw    pal_stub,pal_stub,pal_stub,pal_stub
                     dw    pal_stub,pal_stub,pal_stub,pal_stub
                     dw    pal_stub,pal_stub,pal_stub,pal_stub
                     dw    pal_stub,pal_stub,pal_stub,pal_stub
                     dw    pal_stub,pal_stub,pal_stub,pal_stub
`;

const sharedConfig = {
  includes:  [PPU_MACROS, PPU_REGS],
  assembler: 'merlin32',
  inline: [
    { src: CONSTANTS,    placement: 'before' },
    { src: STUBS,        placement: 'after'  },
    { src: PAL_DISPATCH, placement: 'after'  },
  ],
};

describe('PPUDATA_WRITE — ppuincr = 1 (bit 2 of PPUCTRL clear)', () => {
  const runner = cpu65816(sharedConfig);

  test('two writes land at PPU_ADDR[$2000] and PPU_ADDR[$2001]', async () => {
    const r = await runner.sequence()
      // bit 2 clear → ppuincr = 1
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })
      // set ppuaddr = $2000 (high byte first, then low byte)
      .jsl('PPUADDR_WRITE', { A: 0x20, mx: 3 })
      .jsl('PPUADDR_WRITE', { A: 0x00, mx: 3 })
      // write two bytes; each write advances ppuaddr by 1
      .jsl('PPUDATA_WRITE', { A: 0xAA, mx: 3 })
      .jsl('PPUDATA_WRITE', { A: 0xBB, mx: 3 })
      // capture PPU_MEM[$2000] and PPU_MEM[$2001]
      .captureMemory({ label: 'PPU_MEM', offset: 0x2000, count: 2, as: 'byte' })
      .run();

    expect(r.memory['PPU_MEM']).toEqual([0xAA, 0xBB]);
  });
});

describe('PPUDATA_WRITE — ppuincr = 32 (bit 2 of PPUCTRL set)', () => {
  const runner = cpu65816(sharedConfig);

  test('two writes land at PPU_ADDR[$2000] and PPU_ADDR[$2020]', async () => {
    const r = await runner.sequence()
      // bit 2 set → ppuincr = 32
      .jsl('PPUCTRL_WRITE', { A: 0x04, mx: 3 })
      // set ppuaddr = $2000
      .jsl('PPUADDR_WRITE', { A: 0x20, mx: 3 })
      .jsl('PPUADDR_WRITE', { A: 0x00, mx: 3 })
      // write two bytes; each write advances ppuaddr by 32 ($20)
      .jsl('PPUDATA_WRITE', { A: 0xAA, mx: 3 })
      .jsl('PPUDATA_WRITE', { A: 0xBB, mx: 3 })
      // capture 33 bytes starting at PPU_MEM[$2000] to include both $2000 and $2020
      .captureMemory({ label: 'PPU_MEM', offset: 0x2000, count: 0x21, as: 'byte' })
      .run();

    expect(r.memory['PPU_MEM'][0x00]).toBe(0xAA);   // PPU_ADDR[$2000]
    expect(r.memory['PPU_MEM'][0x20]).toBe(0xBB);   // PPU_ADDR[$2020]
  });
});

// ---------------------------------------------------------------------------
// Dedup: write to already-queued address — PPU_MEM updated, lists untouched
//
// If PPU_VERSION == PPU_MEM+TILE_VERSION0[addr] the address was already
// enqueued this frame.  PPUDATA_WRITE still writes to PPU_MEM (the change
// is real) but skips the list append to avoid duplicate work.
// ---------------------------------------------------------------------------
describe('PPUDATA_WRITE — write to already-queued address', () => {
  const runner = cpu65816(sharedConfig);

  test('PPU_MEM[$2000] updated but neither list touched when tile version matches PPU_VERSION', async () => {
    const r = await runner.sequence()
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })
      // Set PPU_VERSION = 1 and pre-mark the tile shadow for $2000 with the same
      // value so the dedup check (PPU_VERSION == tile_shadow) fires on the write.
      // A is 8-bit here (PPUCTRL_WRITE restored P via plp).
      .inline('            lda   #$01')
      .inline('            sta   PPU_VERSION')
      .inline('            sta   PPU_MEM+TILE_VERSION0+$2000')
      // Set ppuaddr = $2000
      .jsl('PPUADDR_WRITE', { A: 0x20, mx: 3 })
      .jsl('PPUADDR_WRITE', { A: 0x00, mx: 3 })
      // $BB != PPU_MEM[$2000] (= 0), so change detection passes and the value
      // is written; but PPU_VERSION == tile_shadow so no list append happens.
      .jsl('PPUDATA_WRITE', { A: 0xBB, mx: 3 })
      .captureMemory({ label: 'PPU_MEM',          offset: 0x2000, count: 2, as: 'byte' })
      .captureMemory({ label: 'curr_nt_list_end', as: 'word' })
      .captureMemory({ label: 'curr_at_list_end', as: 'word' })
      .run();

    expect(r.memory['PPU_MEM'][0]).toBe(0xBB);   // value was written to PPU_MEM
    expect(r.memory['curr_nt_list_end']).toBe(0); // nt_list untouched
    expect(r.memory['curr_at_list_end']).toBe(0); // at_list untouched
  });
});

// ---------------------------------------------------------------------------
// Dedup: two writes to the same address — only one nt_list entry
//
// The first write enqueues the address and stamps the tile shadow with
// PPU_VERSION.  The second write (different value) updates PPU_MEM again
// but the dedup check now sees PPU_VERSION == tile_shadow and skips the
// second enqueue, keeping exactly one entry in nt_list.
// ---------------------------------------------------------------------------
describe('PPUDATA_WRITE — two writes to the same address produce one nt_list entry', () => {
  const runner = cpu65816(sharedConfig);

  test('second write to $2000 updates PPU_MEM but does not add a duplicate nt_list entry', async () => {
    const r = await runner.sequence()
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })
      // Prime PPU_VERSION = 1 so the first write passes the dedup check.
      .inline('            lda   #$01')
      .inline('            sta   PPU_VERSION')
      // First write: $2000 ← $AA
      //   change detect: 0 → $AA (passes)
      //   dedup: PPU_VERSION(1) != tile_shadow(0) → enqueues, stamps tile_shadow = 1
      .jsl('PPUADDR_WRITE', { A: 0x20, mx: 3 })
      .jsl('PPUADDR_WRITE', { A: 0x00, mx: 3 })
      .jsl('PPUDATA_WRITE', { A: 0xAA, mx: 3 })
      // Reset ppuaddr to $2000 (the first write advanced it to $2001)
      .jsl('PPUADDR_WRITE', { A: 0x20, mx: 3 })
      .jsl('PPUADDR_WRITE', { A: 0x00, mx: 3 })
      // Second write: $2000 ← $BB
      //   change detect: $AA → $BB (passes)
      //   dedup: PPU_VERSION(1) == tile_shadow(1) → skips enqueue
      .jsl('PPUDATA_WRITE', { A: 0xBB, mx: 3 })
      .captureMemory({ label: 'PPU_MEM',          offset: 0x2000, count: 2, as: 'byte' })
      .captureMemory({ label: 'curr_nt_list_end', as: 'word' })
      .captureMemory({ label: 'nt_list',          as: 'word' })
      .run();

    expect(r.memory['PPU_MEM'][0]).toBe(0xBB);       // second write's value sticks
    expect(r.memory['curr_nt_list_end']).toBe(2);     // exactly one entry (2 bytes)
    expect(r.memory['nt_list']).toBe(0x2000);         // the enqueued address
  });
});

// ---------------------------------------------------------------------------
// nt_list routing — tile data writes ($2000–$23BF) must enqueue in nt_list
// ---------------------------------------------------------------------------
describe('PPUDATA_WRITE — nametable tile write enqueues address in nt_list', () => {
  const runner = cpu65816(sharedConfig);

  test('write to $2000 adds $2000 to nt_list and leaves at_list empty', async () => {
    const r = await runner.sequence()
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })
      // Prime PPU_VERSION = 1 so the dedup check (PPU_VERSION != tile shadow) passes.
      // After PPUCTRL_WRITE, P is restored by plp, so A is 8-bit here.
      .inline('            lda   #$01')
      .inline('            sta   PPU_VERSION')
      // Set ppuaddr = $2000
      .jsl('PPUADDR_WRITE', { A: 0x20, mx: 3 })
      .jsl('PPUADDR_WRITE', { A: 0x00, mx: 3 })
      // $AA is non-zero, so it differs from the zeroed PPU_MEM and passes change detection
      .jsl('PPUDATA_WRITE', { A: 0xAA, mx: 3 })
      .captureMemory({ label: 'curr_nt_list_end', as: 'word' })
      .captureMemory({ label: 'nt_list',          as: 'word' })
      .captureMemory({ label: 'curr_at_list_end', as: 'word' })
      .captureMemory({ label: 'at_list',          as: 'word' })
      .run();

    // One word was appended to nt_list, so the end pointer advanced by 2.
    expect(r.memory['curr_nt_list_end']).toBe(2);
    // The stored entry is the (possibly mirrored) PPU address of the write.
    expect(r.memory['nt_list']).toBe(0x2000);
    // at_list must be completely untouched.
    expect(r.memory['curr_at_list_end']).toBe(0);
    expect(r.memory['at_list']).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// at_list routing — attribute writes ($23C0–$23FF) must enqueue in at_list
// ---------------------------------------------------------------------------
describe('PPUDATA_WRITE — attribute write enqueues address in at_list', () => {
  const runner = cpu65816(sharedConfig);

  test('write to $23C0 adds $23C0 to at_list and leaves nt_list empty', async () => {
    const r = await runner.sequence()
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })
      // Prime PPU_VERSION = 1 so the dedup check passes.
      .inline('            lda   #$01')
      .inline('            sta   PPU_VERSION')
      // Set ppuaddr = $23C0 (high byte $23, low byte $C0)
      .jsl('PPUADDR_WRITE', { A: 0x23, mx: 3 })
      .jsl('PPUADDR_WRITE', { A: 0xC0, mx: 3 })
      .jsl('PPUDATA_WRITE', { A: 0xAA, mx: 3 })
      .captureMemory({ label: 'curr_at_list_end', as: 'word' })
      .captureMemory({ label: 'at_list',          as: 'word' })
      .captureMemory({ label: 'curr_nt_list_end', as: 'word' })
      .captureMemory({ label: 'nt_list',          as: 'word' })
      .run();

    // One word was appended to at_list, so the end pointer advanced by 2.
    expect(r.memory['curr_at_list_end']).toBe(2);
    // The stored entry is the (possibly mirrored) PPU address of the write.
    expect(r.memory['at_list']).toBe(0x23C0);
    // nt_list must be completely untouched.
    expect(r.memory['curr_nt_list_end']).toBe(0);
    expect(r.memory['nt_list']).toBe(0);
  });
});

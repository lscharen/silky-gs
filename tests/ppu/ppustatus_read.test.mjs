/**
 * tests/ppu/ppustatus_read.test.mjs
 *
 * Unit tests for PPUSTATUS_READ ($2002 R) in src/ppu/ppu_regs.s.
 *
 * This handler emulates "lda $2002" — a NES PPU status register read.
 * Every call has two mandatory side effects:
 *
 *   1. w_bit is unconditionally set to 1, resetting the PPUADDR/PPUSCROLL
 *      two-write address latch.
 *
 *   2. Bit 7 (VBL flag) is cleared in the stored ppustatus variable.
 *
 * The value returned in A is the *original* ppustatus (including bit 7 if
 * it was set) — the clear happens only to the stored copy, not the return
 * value.  This matches NES hardware behaviour.
 *
 * Note: PPUSTATUS_READ has no php/plp, so it does not preserve P.  The
 * only flags set on return are N and Z, driven by the final pla.
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

/**
 * Return [src, opts] for an inline block that writes ppustatusVal into
 * ppustatus and wBitVal into w_bit before the next JSL step.
 * Uses long (stal) addressing so DBR state does not matter.
 * Ends in 16-bit mode (mx=0) so the sequence runner's state is consistent.
 */
function setupState(ppustatusVal, wBitVal = 0) {
  const hex = n => `$${(n & 0xFF).toString(16).padStart(2, '0').toUpperCase()}`;
  const src = [
    '            sep  #$20',
    '            mx   %10',
    `            lda  #${hex(ppustatusVal)}`,
    '            stal ppustatus',
    `            lda  #${hex(wBitVal)}`,
    '            stal w_bit',
    '            rep  #$20',
    '            mx   %00',
    // Explicitly zero the full 16-bit accumulator (both A and B) so that when
    // PPUSTATUS_READ is called in 8-bit mode the captured r.A is only the
    // low byte.  Without this, B retains whatever the harness left in it and
    // r.A comes back as B<<8 | ppustatus_byte, which can be > 255.
    '            lda  #$0000',
  ].join('\n');
  return [src, { mx: 0 }];
}

// ---------------------------------------------------------------------------
// w_bit reset — must always be 1 after a read, regardless of prior value
// ---------------------------------------------------------------------------
describe('PPUSTATUS_READ — w_bit reset', () => {
  const runner = cpu65816(sharedConfig);

  test('w_bit is set to 1 when it was 0', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0x00, 0))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'w_bit', as: 'byte' })
      .run();
    expect(r.memory.w_bit).toBe(1);
  });

  test('w_bit remains 1 when it was already 1', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0x00, 1))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'w_bit', as: 'byte' })
      .run();
    expect(r.memory.w_bit).toBe(1);
  });

  test('w_bit is reset even when VBL flag is also set', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0x80, 0))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'w_bit', as: 'byte' })
      .run();
    expect(r.memory.w_bit).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// VBL flag clear — bit 7 is cleared in the stored ppustatus after every read
// ---------------------------------------------------------------------------
describe('PPUSTATUS_READ — VBL flag cleared in ppustatus', () => {
  const runner = cpu65816(sharedConfig);

  test('VBL flag ($80) is cleared when it was set', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0x80))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'ppustatus', as: 'byte' })
      .run();
    expect(r.memory.ppustatus).toBe(0x00);
  });

  test('only bit 7 is cleared; lower bits are preserved', async () => {
    // $E0 = VBL ($80) + sprite-0 hit ($40) + sprite overflow ($20)
    const r = await runner.sequence()
      .inline(...setupState(0xE0))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'ppustatus', as: 'byte' })
      .run();
    expect(r.memory.ppustatus).toBe(0x60);  // bit 7 gone, bits 6+5 intact
  });

  test('ppustatus with no VBL flag is unchanged', async () => {
    // $60 = sprite-0 hit + sprite overflow, VBL already clear
    const r = await runner.sequence()
      .inline(...setupState(0x60))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'ppustatus', as: 'byte' })
      .run();
    expect(r.memory.ppustatus).toBe(0x60);
  });

  test('ppustatus $00 stays $00', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0x00))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'ppustatus', as: 'byte' })
      .run();
    expect(r.memory.ppustatus).toBe(0x00);
  });
});

// ---------------------------------------------------------------------------
// Return value — A contains the original ppustatus (before bit 7 is cleared)
// ---------------------------------------------------------------------------
describe('PPUSTATUS_READ — return value in A', () => {
  const runner = cpu65816(sharedConfig);

  test('returns $80 when VBL was set, even though stored copy is cleared', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0x80))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'ppustatus', as: 'byte' })
      .run();
    expect(r.A).toBe(0x80);             // returned: original with VBL
    expect(r.memory.ppustatus).toBe(0); // stored:   VBL cleared
  });

  test('returns all status bits set in original ppustatus', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0xE0))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .run();
    expect(r.A).toBe(0xE0);
  });

  test('returns $00 when ppustatus is $00', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0x00))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .run();
    expect(r.A).toBe(0x00);
  });

  test('consecutive reads: second read returns value with VBL already clear', async () => {
    // The first read clears bit 7 from stored ppustatus.  The second read
    // therefore returns the already-cleared value — VBL is a one-shot flag.
    const r = await runner.sequence()
      .inline(...setupState(0x80))
      .jsl('PPUSTATUS_READ', { mx: 3 })  // first read — returns $80, clears stored VBL
      .jsl('PPUSTATUS_READ', { mx: 3 })  // second read — stored ppustatus is now $00
      .run();
    expect(r.A).toBe(0x00);
  });
});

// ---------------------------------------------------------------------------
// Combined — both side effects occur in every single read
// ---------------------------------------------------------------------------
describe('PPUSTATUS_READ — both side effects together', () => {
  const runner = cpu65816(sharedConfig);

  test('w_bit reset and VBL clear both occur in one call', async () => {
    const r = await runner.sequence()
      .inline(...setupState(0x80, 0))
      .jsl('PPUSTATUS_READ', { mx: 3 })
      .captureMemory({ label: 'ppustatus', as: 'byte' })
      .captureMemory({ label: 'w_bit',     as: 'byte' })
      .run();
    expect(r.A).toBe(0x80);
    expect(r.memory.ppustatus).toBe(0x00);
    expect(r.memory.w_bit).toBe(1);
  });
});

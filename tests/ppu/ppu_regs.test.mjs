/**
 * tests/ppu/ppu_regs.test.mjs
 *
 * Verifies the PPUDATA write/read cycle in ppu_regs.s:
 *   - PPUCTRL_WRITE sets the VRAM address increment
 *   - PPUADDR_WRITE (two writes) sets the VRAM address
 *   - PPUDATA_WRITE stores bytes in PPU_MEM
 *   - PPUDATA_READ returns the *previous* buffer value (one-read delay for
 *     nametable addresses), so 5 reads are needed to retrieve 4 written bytes
 */
import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC_ROOT   = process.env.SRC_ROOT;
const PPU_MACROS = join(SRC_ROOT, 'ppu/ppu_macros.s');
const PPU_REGS   = join(SRC_ROOT, 'ppu/ppu_regs.s');

// Assembly-time constants required by conditional directives in ppu_regs.s.
// Must appear before ppu_regs.s is assembled.
const CONSTANTS = `\
NAMETABLE_MIRRORING   equ 0
HORIZONTAL_MIRRORING  equ 1
DIRECT_OAM_READ       equ 1
TILE_VERSION0         equ $4000
`;

// Stub allocations referenced by ppu_regs.s at runtime.
// 32KB covers 16KB VRAM ($0000-$3FFF) + 16KB tile-version tracking ($4000-$7FFF).
const STUBS = `\
PPU_MEM              ds    $8000
curr_at_list_end     ds    2
curr_nt_list_end     ds    2
at_list              ds    512
nt_list              ds    512
`;

// PPU_PALETTE_DISPATCH is a jsr() dispatch table (32 two-byte entries).
// Only reached for palette writes ($3F00+); all entries point to a no-op stub.
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

describe('ppu_regs PPUDATA write/read', () => {
  const { sequence } = cpu65816({
    includes:      [PPU_MACROS, PPU_REGS],
    assembler:     'merlin32',
    keepArtifacts: true,
    inline: [
      { src: CONSTANTS,    placement: 'before' },
      { src: STUBS,        placement: 'after'  },
      { src: PAL_DISPATCH, placement: 'after'  },
    ],
  });

  test('writes $01-$04 to nametable $2000 and reads them back with one-read delay', async () => {
    const r = await sequence({
      allocMemory: [
        { label: 'read_results', as: 'byte', count: 5 },
      ],
    })
      // Set ppuincr = 1 (bit 2 of PPUCTRL clear); mx:3 = sep #$30 before this call
      .jsl('PPUCTRL_WRITE', { A: 0x00, mx: 3 })
      // Set ppuaddr = $2000 (two writes: high byte $20, low byte $00)
      .jsl('PPUADDR_WRITE', { A: 0x20 })
      .jsl('PPUADDR_WRITE', { A: 0x00 })
      // Write $01-$04 to PPU_MEM[$2000..$2003]
      .jsl('PPUDATA_WRITE', { A: 0x01 })
      .jsl('PPUDATA_WRITE', { A: 0x02 })
      .jsl('PPUDATA_WRITE', { A: 0x03 })
      .jsl('PPUDATA_WRITE', { A: 0x04 })
      // Reset ppuaddr to $2000 for reads
      .jsl('PPUADDR_WRITE', { A: 0x20 })
      .jsl('PPUADDR_WRITE', { A: 0x00 })
      // PPUDATA_READ is buffered: read N returns the value written to N-1.
      // Five reads produce [0, $01, $02, $03, $04].
      .jsl('PPUDATA_READ')
      .inline('            sta   read_results')
      .jsl('PPUDATA_READ')
      .inline('            sta   read_results+1')
      .jsl('PPUDATA_READ')
      .inline('            sta   read_results+2')
      .jsl('PPUDATA_READ')
      .inline('            sta   read_results+3')
      .jsl('PPUDATA_READ')
      .inline('            sta   read_results+4')
      // Capture 4 bytes from PPU_MEM at nametable offset $2000
      .captureMemory({ label: 'PPU_MEM', offset: 0x2000, count: 4, as: 'byte' })
      .run();

    // VRAM write verification: PPU_MEM[$2000..$2003] = [$01, $02, $03, $04]
    expect(r.memory['PPU_MEM']).toEqual([0x01, 0x02, 0x03, 0x04]);

    // Read verification: buffered one-read delay produces [0, $01, $02, $03, $04]
    expect(r.memory['read_results']).toEqual([0x00, 0x01, 0x02, 0x03, 0x04]);
  });
});

import { join } from 'node:path';

const SRC_ROOT   = process.env.SRC_ROOT;
const DEFS       = join(SRC_ROOT, 'core/Defs.s');
const PPU_MACROS = join(SRC_ROOT, 'ppu/ppu_macros.s');
const PPU_REGS   = join(SRC_ROOT, 'ppu/ppu_regs.s');

// Assembly-time constants required by conditional directives in ppu_regs.s.
// Must appear before ppu_regs.s is assembled.
const CONSTANTS = `\
NAMETABLE_MIRRORING   equ HORIZONTAL_MIRRORING
DIRECT_OAM_READ       equ 1
HAS_CHR_RAM           equ 0
`;

// Stub allocations referenced by ppu_regs.s at runtime.
// 32KB covers 16KB VRAM ($0000-$3FFF) + 16KB tile-version tracking ($4000-$7FFF).
const STUBS = `\
PPU_MEM              ds    $8000
curr_at_list_end     ds    2
curr_nt_list_end     ds    2
at_list              ds    512
nt_list              ds    512
MirrorMaskLong       dw    HORIZONTAL_MIRROR_MASK
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

export default {
  includes:  [DEFS, PPU_MACROS, PPU_REGS],
  assembler: 'merlin32',
  inline: [
    { src: CONSTANTS,    placement: 'before' },
    { src: STUBS,        placement: 'after'  },
    { src: PAL_DISPATCH, placement: 'after'  },
  ],
};
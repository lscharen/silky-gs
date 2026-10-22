; Contra NES PRG bank 7
            mx    %11
C07_EMBED_BANK equ 7
ROMBase EXT
            put   ../../../core/Defs.s
            use   equates.inc
            ds    $5000-*
            put   ../../../rom/rom_inject.s
            put   helpers.s
            ds    $8000-*
            ds    $C000-*,$FF
            put   rom_07_fixed.s

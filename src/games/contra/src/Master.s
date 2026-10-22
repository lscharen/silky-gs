; Contra (US) on the Apple IIgs.  Eight UxROM banks, each a full 32KB image:
; the bank's own $8000-$BFFF plus the fixed $C000-$FFFF (rom_07_fixed.s).
; ROM_00-ROM_07 stay contiguous so mapper_bank = ^ROMBase + bank number.

            TYP   $B3
            DSK   ContraGS

            ASM   Main.s
            KND   #$1100
            SNA   MAIN

            ASM   Stack.s
            KND   $0012
            SNA   STKDP

            ASM   ../../../Engine.s
            KND   #$1100
            SNA   ENGINE

            ASM   ../../../core/blitter/TemplateLiteBank1.s
            KND   #$1100
            SNA   PPU1

            ASM   ../../../core/blitter/TemplateLiteBank2.s
            KND   #$1100
            SNA   PPU2

            ASM   ../../../core/static/TileData.s
            KND   #$1100
            SNA   CHRDATA

            ASM   rom_00.s
            KND   #$1100
            SNA   CROM00

            ASM   rom_01.s
            KND   #$1100
            SNA   CROM01

            ASM   rom_02.s
            KND   #$1100
            SNA   CROM02

            ASM   rom_03.s
            KND   #$1100
            SNA   CROM03

            ASM   rom_04.s
            KND   #$1100
            SNA   CROM04

            ASM   rom_05.s
            KND   #$1100
            SNA   CROM05

            ASM   rom_06.s
            KND   #$1100
            SNA   CROM06

            ASM   rom_07.s
            KND   #$1100
            SNA   CROM07

            ASM   PPU.s
            KND   #$1100
            SNA   PPURAM

            ASM   palettes.s
            KND   #$1100
            SNA   PALDATA

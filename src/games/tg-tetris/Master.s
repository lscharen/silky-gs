; Tengen Tetris (CNROM: 32KB PRG-ROM, 16KB CHR-ROM) on the Apple IIgs

            TYP   $B3         ; S16 file
            DSK   TetrisGS

; No XPL: build.js takes the zeros out of the file (scripts/omf-compact.js: DS records and reserved
; space), and ExpressLoad can't load those.

; Segment #1 -- Main execution block

            ASM   Main.s
            KND   #$1100
            SNA   MAIN

            ASM   Stack.s
            KND   $0012
            SNA   STKDP

; The engine (PPU simulation, renderers, blitter, tile / sprite compilers)

            ASM   ../../engines/pea/Engine.s
            KND   #$1100
            SNA   ENGINE

; PPU blitter

            ASM   ../../engines/pea/blitter/TemplateLiteBank1.s
            KND   #$1100
            SNA   PPU1

            ASM   ../../engines/pea/blitter/TemplateLiteBank2.s
            KND   #$1100
            SNA   PPU2

; Converted Tile Storage

            ASM   TileData.s
            KND   #$1100
            SNA   CHRDATA

; ROM

            ASM   rom.s
            KND   #$1100
            SNA   TGROM

; PPU memory and PPU shadow storage

            ASM   PPU.s
            KND   #$1100
            SNA   PPURAM

; Palette swizzle tables (long-addressed data, kept out of the main segment)

            ASM   palettes.s
            KND   #$1100
            SNA   PALDATA

; IIgs Game Engine

            TYP   $B3         ; S16 file
            DSK   BalloonFgtGS
            XPL

; Segment #1 -- Main execution block

            ASM   Main.s
            KND   #$1100
            SNA   MAIN

            ASM   Stack.s
            KND   $0012
            SNA   STKDP

; Segment #2 & #3 -- PPU blitter

            ASM   ../../core/blitter/TemplateLiteBank1.s
            KND   #$1100
            SNA   PPU1

            ASM   ../../core/blitter/TemplateLiteBank2.s
            KND   #$1100
            SNA   PPU2

; Segment #4 -- Converted Tile Storage

            ASM   ../../core/static/TileData.s
            KND   #$1100
            SNA   CHRDATA

; Segment #5 -- ROM

            ASM   rom.s
            KND   #$1100
            SNA   BFROM

; Segment #6 -- PPU memory and PPU shadow storage

            ASM   PPU.s
            KND   #$1100
            SNA   PPURAM
















































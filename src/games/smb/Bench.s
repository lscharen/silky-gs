; IIgs Game Engine

; Segment #1 -- Main execution block

            TYP   $06         ; BIN file, fixed address
            DSK   Main
            ORG   $030000
            ASM   Main.s
            SNA   MAIN

; Segment #2 & #3 -- PPU blitter

            TYP   $06
            DSK   PPU1
            ORG   $040000
            ASM   ../../core/blitter/TemplateLiteBank1.s
            SNA   PPU1

            TYP   $06
            DSK   PPU2
            ORG   $050000
            ASM   ../../core/blitter/TemplateLiteBank2.s
            SNA   PPU2

; Segment #4 -- Converted Tile Storage

            TYP   $06
            DSK   CHRDATA
            ORG   $060000
            ASM   ../../core/static/TileData.s
            SNA   CHRDATA

; Segment #5 -- ROM

            TYP   $06
            DSK   SMBROM
            ORG   $070000
            ASM   rom.s
            SNA   SMBROM

; Segment #6 -- PPU memory and PPU shadow storage

            TYP   $06
            DSK   PPURAM
            ORG   $080000
            ASM   PPU.s
            SNA   PPURAM






























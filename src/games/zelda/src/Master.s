; IIgs Game Engine -- The Legend of Zelda
;
; Real multi-bank Master.s: Zelda's 7 switchable NES PRG banks (00-06) are
; each their own Merlin32 bank-relative segment (KND #$1100). Bank 07 (the
; MMC1-fixed NES $C000-$FFFF window) is NOT its own segment -- it has no
; unique content of its own on real hardware either (Z.cfg: ROM_07 starts at
; $C000), so rom_07_fixed.s is `put` into every one of banks 00-06 instead,
; making each of those 7 physical 65816 banks a full 32KB (NES $8000-$FFFF)
; image: that bank's own $8000-$BFFF content, plus the common $C000-$FFFF
; content, exactly like the original hardware's memory map.
;
; ROM_00-ROM_06 MUST stay contiguous (no other segment interspersed) so the
; OMF loader assigns them consecutive physical banks -- SwitchBank's runtime
; dispatch computes target bank = ROMBase's bank + logical bank number.
;
; CHR-RAM tile upload and runtime nametable-mirroring switching are not yet
; implemented (see Main.s TODO-DEFERRED comments / project_zelda_conversion
; memory notes) -- this build links and boots but will not render correctly.

            TYP   $B3         ; S16 file
            DSK   ZeldaGS
            XPL

; Segment #1 -- Main execution block

            ASM   Main.s
            KND   #$1100
            SNA   MAIN

            ASM   Stack.s
            KND   $0012
            SNA   STKDP

; Segment #2 & #3 -- PPU blitter

            ASM   ../../../core/blitter/TemplateLiteBank1.s
            KND   #$1100
            SNA   PPU1

            ASM   ../../../core/blitter/TemplateLiteBank2.s
            KND   #$1100
            SNA   PPU2

; Segment #4 -- Converted Tile Storage

            ASM   ../../../core/static/TileData.s
            KND   #$1100
            SNA   CHRDATA

            ASM   rom_active.s
            KND   #$1100
            SNA   ZROMXX

; Segment #5 -- ROM banks 00-07 (switchable NES $8000-$BFFF window).
; ROMBase is ENT'd only in rom_00.s; every other bank imports it EXT to
; compute its own bank-dispatch target.

            ASM   rom_00.s
            KND   #$1100
            SNA   ZROM00

            ASM   rom_01.s
            KND   #$1100
            SNA   ZROM01

            ASM   rom_02.s
            KND   #$1100
            SNA   ZROM02

            ASM   rom_03.s
            KND   #$1100
            SNA   ZROM03

            ASM   rom_04.s
            KND   #$1100
            SNA   ZROM04

            ASM   rom_05.s
            KND   #$1100
            SNA   ZROM05

            ASM   rom_06.s
            KND   #$1100
            SNA   ZROM06

            ASM   rom_07.s
            KND   #$1100
            SNA   ZROM07

; Segment #7 -- PPU memory and PPU shadow storage

            ASM   PPU.s
            KND   #$1100
            SNA   PPURAM

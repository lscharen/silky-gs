; Super Mario Bros. on the tile engine (src/engines/tile): the link file.  A game picks its engine here, with the engine's
; Engine.s as the ENGINE segment (the build reads that line); the tile engine adds two segments of its own, SPRITE and SPRLIB.
; The ROM, CHR and tile data are SMB's own (../smb).

            TYP   $B3         ; S16 file
            DSK   SuperMarioTile

; No XPL: build.js takes the zeros out of the file (scripts/omf-compact.js: DS records and reserved
; space), and ExpressLoad can't load those.

            ASM   Main.s
            KND   #$1100
            SNA   MAIN

; The engine: the cells, the background tiles and the renders
            ASM   ../../engines/tile/Engine.s
            KND   #$1100
            SNA   ENGINE

; The sprites' cell tracking and the expose code
            ASM   ../../engines/tile/Sprite.s
            KND   #$1100
            SNA   SPRITE

; silky's sprite cache and bitmap draws
            ASM   ../../engines/tile/SprLib.s
            KND   #$1100
            SNA   SPRLIB

; Converted tile storage (a whole bank: compactGame)
            ASM   ../smb/TileData.s
            KND   #$1100
            SNA   CHRDATA

            ASM   ../smb/rom.s
            KND   #$1100
            SNA   SMBROM

; PPU memory (a whole bank: compactGame): CHR and CIRAM
            ASM   ../smb/PPU.s
            KND   #$1100
            SNA   PPURAM

; Palette swizzle tables (generated here from ../smb/palettes)
            ASM   palettes.s
            KND   #$1100
            SNA   PALDATA

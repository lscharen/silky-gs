; TODO-DEFERRED: provisional Y-exclusion table (off-screen scanline mask),
; copied from src/games/wumpus/src/neswumpus.s -- matches this port's
; y_offset_rows/y_height_rows config in Main.s closely enough to link;
; revisit once real rendering is verified.
y_exclude ENT
        ds 24,$01
        ds 200,$00
        ds 32,$01

; Bank of memory that holds the NES PPU RAM from $0000 - $3FFF and shadow data for the runtime in the other memory
PPU_MEM     ENT
CHR_ROM     ENT
; TODO-DEFERRED: Zelda uses CHR-RAM (tiles uploaded dynamically via PPUDATA
; writes), not a fixed CHR-ROM image -- reserve the same $2000-byte window
; other games fill from chr.s, left zeroed until CHR-RAM upload handling is
; built (see project_zelda_conversion memory notes).
            ds    $2000
PPU_NT      ENT
            ds    $2000          ; Nametable memory from $2000 - $3000, $3F00 - $3F14 is palette RAM

; End of normal PPU RAM, the rest is used for various shadow RAM leveraged by the runtime.  The only
; data that needs to be shadowed is the 4kb of Nametable memory.
;
; Sized $100 smaller than the usual $C000 to leave room for the y_exclude
; table above without exceeding the 64KB bank limit.

            ds    $BF00

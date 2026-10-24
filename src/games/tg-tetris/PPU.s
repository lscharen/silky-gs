; Bank of memory that holds the NES PPU RAM from $0000 - $3FFF and shadow data for the runtime in the other memory
;
; The cartridge has 16KB of CHR-ROM in two 8KB banks (CNROM): bank 0 (chr0.bin) for the menus and the
; game, bank 1 (chr1.bin) for the title screen and the leaderboard.  CHR_ROM starts with bank 0 (build.js
; converts it into the tiledata bank); both banks are in the ROM segment (rom.s), and the game's
; PRE_RENDER copies the one the ROM selects here (CheckCHRBank, Main.s).
PPU_MEM     ENT
CHR_ROM     ENT
            putbin chr0.bin       ; 8K of CHR-ROM at PPU memory $0000 - $2000: bank 0, at power on
PPU_CIRAM   ENT
            ds    $800            ; CIRAM buffer, not mapped directly to a PPU address

            ds    $1700           ; Padding
PALETTE_RAM ds    $100            ; $3F00 - $3F14 is palette RAM

; End of normal PPU RAM, the rest is used for various shadow RAM leveraged by the runtime.  The only
; data that needs to be shadowed is the 4kb of Nametable memory.  There is no ds for it: build.js makes
; this segment a whole bank (omf-compact.js --bank PPURAM), so PPU_MEM is at $0000 and the bank is
; all ours.

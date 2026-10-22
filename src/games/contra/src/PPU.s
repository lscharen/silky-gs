; CHR-RAM: the ROM uploads tiles through PPUDATA.  This buffer starts empty.
PPU_MEM     ENT
CHR_ROM     ENT
            ds    $2000
PPU_CIRAM   ENT
            ds    $800

            ds    $1700
PALETTE_RAM ds    $100

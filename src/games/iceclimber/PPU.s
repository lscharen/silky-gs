; Bank of memory that holds the NES PPU RAM from $0000 - $3FFF and shadow data for the runtime in the other memory
PPU_MEM     ENT
CHR_ROM     ENT
            putbin   CHR_ROM_1.chr          ; $0000 - $10A0

;            ds       $260                   ; Put PPU_bg here
            put      PPU_bg.s

            putbin   CHR_ROM_2.chr          ; $1300 - $2000
PPU_CIRAM   ENT
            ds    $800            ; CIRAM buffer, not mapped directly to a PPU address

            ds    $1700           ; Padding
PALETTE_RAM ds    $100            ; $3F00 - $3F14 is palette RAM

; End of normal PPU RAM, the rest is used for various shadow RAM leveraged by the runtime.  The only
; data that needs to be shadowed is the 4kb of Nametable memory.

            ds    $C000


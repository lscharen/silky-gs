; Bank of memory that holds the NES PPU RAM from $0000 - $3FFF and shadow data for the runtime in the other memory
PPU_MEM     ENT
CHR_ROM     ENT
            put   chr.s          ; 8K of CHR-ROM at PPU memory $0000 - $2000
PPU_NT      ENT
            ds    $2000          ; Nametable memory from $2000 - $3000, $3F00 - $3F14 is palette RAM

; End of normal PPU RAM, the rest is used for various shadow RAM leverage by the runtime.  The only
; data that needs to be shadowed is the 4kb of Nametable memory.

            ds    $BF00

; Stash the PPU_OAM RAM at the end -- this isn't used very often
;PPU_OAM     ENT 
;            ds    256            ; 256 bytes of separate OAM RAM


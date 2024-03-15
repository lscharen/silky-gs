SMBStart             EXT   ; Base address of the ROM.  Should be XX/8000 in the bank the ROM is loaded into
NonMaskableInterrupt EXT   ; Called every VBL
ExtIn                EXT
ROMBase              EXT

; Addresses in the blitter banks
lite_base            EXT
lite_base_2          EXT

; Addresses in the other static memory banks
tiledata             EXT
PPU_MEM              EXT
CHR_ROM              EXT

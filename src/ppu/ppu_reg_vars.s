; ppu_reg_vars.s
;
; This file contains:
;
;   PPU State Variables
;   -------------------
;   The internal state of the NES PPU registers.  ppuaddr (ENT) is the
;   current VRAM address pointer; w_bit tracks the high/low byte write
;   toggle for PPUADDR and PPUSCROLL writes, etc.
;
;   This file is included one time in the base ROM bank of the NES 
;   memory map.  Because all NES code runs with the Data Bank
;   register set to this bank, any code in any NES bank can access
;   these variables via absolute addressing.
;
;   We take advantage of this memory map by replicating the ppu_regs.s
;   shims into every NES ROM bank so when they access these PPU
;   state variables, they are always accessing the same physical memory.
;
;   The resons for this arrangement is that is allows the PPU/APU
;   shims to stay in the same bank as their callers and replace a
;   double dispatch of jsr/jsl/rtl/rts with a single jsr/rts pair
;   saving 14 cycles per call, in addition to the cycles saved from
;   switching from long to absolute addressing and allowing more flexible
;   register use.
;
;   Since the NES logic is executed at 60fps and makes a few dozen shim
;   calls on each frame, we expect to save around 1% of the total CPU
;   time (~25,000 cycles/sec)

ppuaddr     ENT
            ds 2     ; 16-bit ppu address
w_bit       ENT
            dw 1     ; currently writing to high or low to the address latch
vram_buff   ENT
            dw 0     ; latched data when reading VRAM ($0000 - $3EFF)

ppuincr     ENT
            dw 1     ; 1 or 32 depending on bit 2 of PPUCTRL
ppuctrl     ENT
            dw 0     ; Copy of the ppu ctrl byte
ppumask     ENT
            dw 0     ; Copy of the ppu mask byte
ppustatus   ENT
            dw 0
oamaddr     ENT
            dw 0     ; Typically this will always be 0
ppuscroll   ENT
            dw 0     ; Y X coordinates

; MMC1 registers
mmc1_shft   ENT
            ds    1

mmc1_regs   ENT
mmc1_reg0   ds    1
mmc1_reg1   ds    1
mmc1_reg2   ds    1
mmc1_reg3   ds    1

; mapper state
mapper_bank ENT
            ds    2                       ; 64kb IIgs bank that holds the current active NES bank. 2 bytes for convenience.

; CHR-ROM bank switching (CNROM): the 8KB CHR-ROM bank the ROM selected, and a flag set when it changes.
; The ROM's bank write sets both; the game's PRE_RENDER loads the bank into CHR_ROM (PPU_ReloadCHR).
ppu_bank    ENT
            ds    2
ppu_bank_changed ENT
            ds    2

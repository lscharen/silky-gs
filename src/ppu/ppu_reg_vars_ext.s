; ppu_reg_vars_ext.s
;
; The PPU state variables (ppu/ppu_reg_vars.s) for the ROM banks that do not hold them.  A multi-bank
; game puts ppu_reg_vars.s in its base ROM bank and this file in every other bank, before rom_inject.s.
; The NES code always runs with DBR = the base ROM bank, so the shims' absolute addresses reach them
; from every bank.

ppuaddr     EXT
w_bit       EXT
vram_buff   EXT
ppuincr     EXT
ppuctrl     EXT
ppumask     EXT
ppustatus   EXT
oamaddr     EXT
ppuscroll   EXT

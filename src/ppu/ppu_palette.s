; ppu_palette.s - Default NES Palette Handlers
;
; This file contains the default dispatch handler stubs for NES PPU palette RAM
; writes ($3F00-$3F1F).  These are the RUNTIME DEFAULTS; each game overrides the
; PPU_PALETTE_DISPATCH table in its Main.s with game-specific handlers.
;
; NES palette RAM layout:
;   $3F00        - Universal background color
;   $3F01-$3F03  - Background palette 0, colors 1-3
;   $3F04-$3F07  - Background palette 1
;   $3F08-$3F0B  - Background palette 2
;   $3F0C-$3F0F  - Background palette 3
;   $3F10        - Mirror of $3F00 (background color again)
;   $3F11-$3F1F  - Sprite palettes
;
; Only $3F00 and $3F10 do anything in the default implementation: they map the
; NES background color to IIgs SHR palette index 0.  All other entries fall
; through to the nearest `rts` stub.
;
; The dispatch table itself (PPU_PALETTE_DISPATCH) is defined by the game in
; Main.s and typically points either here or to game-specific handlers.

        mx   %00
; Background color
ppu_3F00  ldal PPU_MEM+$3F00
          jsr  NES_ColorToIIgs
          stal $E19E00
          rts

ppu_3F01
ppu_3F02
ppu_3F03

ppu_3F04
ppu_3F05
ppu_3F06
ppu_3F07

ppu_3F08
ppu_3F09
ppu_3F0A
ppu_3F0B

ppu_3F0C
ppu_3F0D
ppu_3F0E
ppu_3F0F  rts

ppu_3F10  ldal PPU_MEM+$3F10
          jsr  NES_ColorToIIgs
          stal $E19E00
          rts
ppu_3F11
ppu_3F12
ppu_3F13

ppu_3F14
ppu_3F15
ppu_3F16
ppu_3F17

ppu_3F18
ppu_3F19
ppu_3F1A
ppu_3F1B

ppu_3F1C
ppu_3F1D
ppu_3F1E
ppu_3F1F rts

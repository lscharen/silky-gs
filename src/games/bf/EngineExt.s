; Balloon Fight -- the code the engine calls in its own bank
;
; The build stages this file into src/game/ and src/Engine.s puts it in the ENGINE segment: the code
; and data the renderer or the PPU write shims call with jsr or read with 16-bit addresses (a game's own
; palette dispatch table, SPRITE_PRE_DRAW's code), or that works on the engine's internals.  Main.s is in another bank: its symbols are reached with long addressing ("label EXT" here,
; "label ENT" at the definition) and so are this file's from there.

            mx    %00

; The game's palette RAM write handlers (CUSTOM_PPU_PALETTE_DISPATCH, PPU_PALETTE_DISPATCH in Hooks.s).
; Each sets the slots its color is shown in, in IIgs palettes 0 - 2.

; When the NES ROM code tried to write to the PPU palette space, intercept here.
BF_PALETTE_DISPATCH
        dw   BF_3F00,BF_3F01,BF_3F02,BF_3F03
        dw   ppu_3F04,BF_3F05,BF_3F06,BF_3F07
        dw   ppu_3F08,BF_3F09,BF_3F0A,BF_3F0B
        dw   ppu_3F0C,BF_3F0D,BF_3F0E,BF_3F0F

        dw   BF_3F10,BF_3F11,BF_3F12,BF_3F13
        dw   ppu_3F14,ppu_3F15,ppu_3F16,ppu_3F17
        dw   ppu_3F18,BF_3F19,BF_3F1A,BF_3F1B
        dw   ppu_3F1C,BF_3F1D,BF_3F1E,BF_3F1F

; Background color (A = the NES color), in all three IIgs palettes.  $3F00 and $3F10 are the
; same entry, so store it in both (see ppu_palette.s)
BF_3F00
BF_3F10 sep  #$20
        stal PPU_MEM+$3F00
        stal PPU_MEM+$3F10
        rep  #$20
        jsr  NES_ColorToIIgs
        stal $E19E00
        stal $E19E20
        stal $E19E40
        rts

; Tile palette 1, color 1
BF_3F01 ldal PPU_MEM+$3F01
        jsr  NES_ColorToIIgs
;        stal $E19E02
        stal $E19E22
        stal $E19E42
        rts

; Tile palette 1, color 2
BF_3F02 ldal PPU_MEM+$3F02
        jsr  NES_ColorToIIgs
;        stal $E19E04
        stal $E19E24
        stal $E19E44
        rts

; Tile palette 1, color 3
BF_3F03 ldal PPU_MEM+$3F03
        jsr  NES_ColorToIIgs
;        stal $E19E06
        stal $E19E26
        stal $E19E46
        rts

; Tile palette 2, color 1
BF_3F05 ldal PPU_MEM+$3F05
        jsr  NES_ColorToIIgs
        stal $E19E08
        stal $E19E02
        rts

; Tile palette 2, color 2
BF_3F06 ldal PPU_MEM+$3F06
        jsr  NES_ColorToIIgs
        stal $E19E0A
        stal $E19E04
        rts

; Tile palette 2, color 3
BF_3F07 ldal PPU_MEM+$3F07
        jsr  NES_ColorToIIgs
        stal $E19E0C
        stal $E19E06
        rts

; Tile palette 3, color 1
BF_3F09 ldal PPU_MEM+$3F09
        jsr  NES_ColorToIIgs
        stal $E19E28
        rts

; Tile palette 3, color 2
BF_3F0A ldal PPU_MEM+$3F0A
        jsr  NES_ColorToIIgs
        stal $E19E2A
        rts

; Tile palette 3, color 3
BF_3F0B ldal PPU_MEM+$3F0B
        jsr  NES_ColorToIIgs
        stal $E19E2C
        rts

; Tile palette 4, color 1
BF_3F0D ldal PPU_MEM+$3F0D
        jsr  NES_ColorToIIgs
        stal $E19E48
        rts

; Tile palette 4, color 2
BF_3F0E ldal PPU_MEM+$3F0E
        jsr  NES_ColorToIIgs
        stal $E19E4A
        rts

; Tile palette 4, color 3
BF_3F0F ldal PPU_MEM+$3F0F
        jsr  NES_ColorToIIgs
        stal $E19E4C
        rts

; Sprite palette 1, color 1
BF_3F11 ldal PPU_MEM+$3F11
        jsr  NES_ColorToIIgs
        stal $E19E0E
        stal $E19E2E
        stal $E19E4E
        rts

; Sprite palette 1, color 2
BF_3F12 ldal PPU_MEM+$3F12
        jsr  NES_ColorToIIgs
        stal $E19E10
        stal $E19E30
        stal $E19E50
        rts

; Sprite palette 1, color 3
BF_3F13 ldal PPU_MEM+$3F13
        jsr  NES_ColorToIIgs
        stal $E19E12
        stal $E19E32
        stal $E19E52
        rts

; Sprite palette 2 is mapped to palette 1 colors

; Sprite palette 3, color 1
BF_3F19 ldal PPU_MEM+$3F19
        jsr  NES_ColorToIIgs
        stal $E19E14
        stal $E19E34
        stal $E19E54
        rts

; Sprite palette 3, color 2
BF_3F1A ldal PPU_MEM+$3F1A
        jsr  NES_ColorToIIgs
        stal $E19E16
        stal $E19E36
        stal $E19E56
        rts

; Sprite palette 3, color 3
BF_3F1B ldal PPU_MEM+$3F1B
        jsr  NES_ColorToIIgs
        stal $E19E18
        stal $E19E38
        stal $E19E58
        rts

; Sprite palette 4, color 1
BF_3F1D ldal PPU_MEM+$3F1D
        jsr  NES_ColorToIIgs
        stal $E19E1A
        stal $E19E3A
        stal $E19E5A
        rts

; Sprite palette 4, color 2
BF_3F1E ldal PPU_MEM+$3F1E
        jsr  NES_ColorToIIgs
        stal $E19E1C
        stal $E19E3C
        stal $E19E5C
        rts

; Sprite palette 4, color 3
BF_3F1F ldal PPU_MEM+$3F1F
        jsr  NES_ColorToIIgs
        stal $E19E1E
        stal $E19E3E
        stal $E19E5E
        rts

            mx    %00

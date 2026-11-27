; Super Mario Bros. -- the game's code in the engine's bank (src/Engine.s puts it, staged as game/EngineExt.s)
;
; VOC two-plane spike: the background is drawn into bank $01 and shadowed to $E1 as usual, the sprites
; are drawn straight into bank $E0, which the Video Overlay Card shows over it with its own palette.  So
; each plane has 16 colors and the NES palette RAM maps 1:1 onto the IIgs palettes (identity swizzle
; tables, pal_voc.s):
;
;   $3F00-$3F0F (background) -> $E1/9E00 + entry * 2
;   $3F10-$3F1F (sprites)    -> $E0/9E00 + (entry - 16) * 2
;
; Color 0 of each group is the universal background color, IIgs slot 0 of $E1; slot 0 of $E0 is the VOC
; chroma key (ChromaKeyRGB, set by SetupVOC) and is never written here.

; The palette RAM write handlers (CUSTOM_PPU_PALETTE_DISPATCH, PPU_PALETTE_DISPATCH in Hooks.s).
; A = the NES color, X = the entry * 2, DBR = the engine's bank, 16-bit registers.  Y may be trashed.
VOC_PALETTE_DISPATCH
        dw   ppu_3F00,voc_BG,voc_BG,voc_BG
        dw   ppu_PalNone,voc_BG,voc_BG,voc_BG
        dw   ppu_PalNone,voc_BG,voc_BG,voc_BG
        dw   ppu_PalNone,voc_BG,voc_BG,voc_BG
        dw   ppu_3F10,voc_SP,voc_SP,voc_SP
        dw   ppu_PalNone,voc_SP,voc_SP,voc_SP
        dw   ppu_PalNone,voc_SP,voc_SP,voc_SP
        dw   ppu_PalNone,voc_SP,voc_SP,voc_SP

        mx   %00
voc_BG
        jsr  NES_ColorToIIgs            ; (Y)
        stal $E19E00,x
        rts

voc_SP
        jsr  NES_ColorToIIgs
        stal $E09E00-$20,x
        rts

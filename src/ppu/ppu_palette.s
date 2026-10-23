; ppu_palette.s - NES palette RAM writes
;
; PPUDATA writes to palette RAM ($3F00-$3F1F) that change a value go through a dispatch table, one
; handler per entry (ppu_regs.s), with the palette RAM already updated.  The engine's table
; (ppuPaletteDispatch) is the one for the games with generated palettes (scripts/
; generate-palette-transitions.js):
;
;   - color 0 ($3F00 / $3F10) is IIgs slot 0, written straight away (ppu_3F00); the other color 0s
;     aren't shown
;   - any other entry either marks the palette dirty (ppuPalDirty: the generated ApplyPaletteChange
;     identifies the palette at the next render), or, for a cell the current palette has a [direct]
;     section for, goes straight to its IIgs slot.  ppuPalWrites says which, per entry; the generated
;     code sets it for each palette (PPU_SetPaletteWrites).
;
; A game with handlers of its own sets CUSTOM_PPU_PALETTE_DISPATCH equ 1 and PPU_PALETTE_DISPATCH equ
; its table in Hooks.s, and defines the table in its EngineExt.s (it is read with 16-bit addresses in
; this bank).  The ppu_3Fxx stubs below are there for such tables.
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
; through to the nearest `rts` stub (for a game's own dispatch table).
;
; $3F10 is a hardware mirror of $3F00, so a write to either one is stored in both.
; PPUDATA writes only reach a handler when the value at their own address changes;
; without the mirroring, $3F00 = A, $3F10 = B, $3F00 = A would skip the last write
; and leave the background B.
;

; Background color.  A = the NES color.
        mx   %00
ppu_3F00
ppu_3F10  sep  #$20
          stal PPU_MEM+$3F00            ; $3F00 and $3F10 are the same entry
          stal PPU_MEM+$3F10
          rep  #$20
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

; The engine's dispatch table (games with generated palettes; see the top of the file)
ppuPaletteDispatch
        dw   ppu_3F00,ppu_PalWrite,ppu_PalWrite,ppu_PalWrite
        dw   ppu_PalNone,ppu_PalWrite,ppu_PalWrite,ppu_PalWrite
        dw   ppu_PalNone,ppu_PalWrite,ppu_PalWrite,ppu_PalWrite
        dw   ppu_PalNone,ppu_PalWrite,ppu_PalWrite,ppu_PalWrite
        dw   ppu_3F10,ppu_PalWrite,ppu_PalWrite,ppu_PalWrite
        dw   ppu_PalNone,ppu_PalWrite,ppu_PalWrite,ppu_PalWrite
        dw   ppu_PalNone,ppu_PalWrite,ppu_PalWrite,ppu_PalWrite
        dw   ppu_PalNone,ppu_PalWrite,ppu_PalWrite,ppu_PalWrite

; A palette RAM write, on the NES task.  A = the NES color, X = the entry * 2, DBR = this bank, 16-bit
; registers; Y is the caller's to keep (ppu_regs.s saves it).
        mx   %00
ppu_PalWrite
        ldy  ppuPalWrites,x
        bpl  :direct
        lda  #1                         ; Note the change: the palette is identified at the next render
        sta  ppuPalDirty
        rts
:direct jsr  NES_ColorToIIgs_X          ; A [direct] cell of the current palette: straight to its slot
        tyx
        stal SHR_PALETTES,x
ppu_PalNone
        rts

ppuPalDirty ENT
        dw   0                          ; palette RAM changed since the last render (ApplyPaletteChange)

; Per palette RAM entry: the IIgs slot * 2 to write it to straight away, or $FFFF to mark the palette
; dirty.  Set by the generated palette code for the palette on screen (PPU_SetPaletteWrites).
ppuPalWrites
        lup  32
        dw   $FFFF
        --^

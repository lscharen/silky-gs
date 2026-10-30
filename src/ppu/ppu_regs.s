; ppu_regs.s - The engine side of the NES PPU register interface
;
; The register shims ($2000-$2007) are in rom/rom_inject.s, in the ROM bank next to the state they use
; (ppu/ppu_reg_vars.s), so the ROM reaches them with jsr / rts.  This file has what they hand off to
; the engine with jsl, and the long entry points other code still calls:
;
;     PPUSTATUS_READ    ($2002 R) - VBL flag, clears address latch (tg-tetris support.s)
;     PPUDATA_WRITE_CHR ($2007 W) - CHR-RAM write: mark the tile dirty (HAS_CHR_RAM)
;     PPUDATA_WRITE_PAL ($2007 W) - palette RAM write: palette dispatch
;     PPUDMA_WRITE      ($4014 W) - Sprite DMA transfer

; $2002 - PPUSTATUS For "lda ppustatus"
; MUST NOT change any P flags not set by the PLA before the return.
        mx    %11
PPUSTATUS_READ ENT
        lda  #1
        stal w_bit           ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        bpl  :out
        and  #$7F            ; Clear the VBL flag
        stal ppustatus
        ora  #$80            ; Restore negative value
:out
        rtl


        DO   HAS_CHR_RAM
; The first write since the sprite form was converted (PPUDATA_WRITE): drop the tile's compiled sprites
; (every palette and vertical orientation), so a compiled-sprite hit never needs to check the dirty flag.  A tile with its sprite
; flag set never has a compiled sprite (SprCompileTile), so the other writes have nothing to drop.  The
; flag is set first: the GS task may compile in between, and it does not keep a sprite whose flag is set.

; X = the tile index (pattern table << 8 | tile).  Returns with 16-bit registers.
        mx   %10
DropTileSprites
        rep  #$30
        DO   SPR_TALL
        phx                                       ; (for the 8x16 pair, below)
        FIN
        txa
        and  #$00FF
        asl
        asl                                       ; tile << 2
        cpx  #$0100
        bcc  *+5
        ora  #$1000                               ; pattern table << 12
        tax                                       ; key offset of the tile, palette 0, not flipped vertically
        lda  #0
]pal    =    0
        lup  4                                    ; every palette, both vertical orientations
        stal PPU_MEM+SPR_COMP_TBL+{]pal*$400},x
        stal PPU_MEM+SPR_COMP_TBL+{]pal*$400}+2,x
]pal    =    ]pal+1
        --^

        DO   SPR_TALL                             ; The whole 8x16 sprites of the tile's pair (SPR16_COMP_TBL)
        pla
        tax
        and  #$00FE                               ; the pair's OAM tile ID: bit 0 = the pattern table
        cpx  #$0100
        bcc  *+3
        inc
        asl
        asl
        tax
        lda  #0
]pal    =    0
        lup  4
        stal PPU_MEM+SPR16_COMP_TBL+{]pal*$400},x
        stal PPU_MEM+SPR16_COMP_TBL+{]pal*$400}+2,x
]pal    =    ]pal+1
        --^
        FIN
        rts
        FIN

; PPUDATA_WRITE_CHR
;
; Called (jsl) by STA_2007 (rom_inject.s) after it stored a byte of CHR-RAM ($0000-$1FFF) at PPU_MEM.
; X = the CHR address (16-bit), 8-bit A.  Marks the tile dirty for on-demand recompilation at draw time
; (DrawPPUTile / sprChrCheck), instead of pre-compiling everything up front like a fixed CHR-ROM game.
        DO   HAS_CHR_RAM
        mx   %10
PPUDATA_WRITE_CHR ENT
        rep  #$30
        txa                    ; X is in the range $0000 - $1FFF
        lsr                    ; Convert to tile index
        lsr
        lsr
        lsr
        tax
        sep  #$20
        ldal ChrRamDirty,x
        pha                                       ; (was the sprite form already dirty?)
        lda  #{CHRRAM_BG_DIRTY+CHRRAM_SPR_DIRTY}  ; both forms need recompiling -- see CHRRAM_BG_DIRTY/
                                                  ; CHRRAM_SPR_DIRTY (CoreData.s) for why these are two
                                                  ; independent bits, not one shared flag
        stal ChrRamDirty,x
        pla
        bit  #CHRRAM_SPR_DIRTY
        bne  :done
        jsr  DropTileSprites
:done   rtl
        FIN

; Do some extra work to keep palette data in sync. Because the IIgs palette is not
; large enough to accomodate all of the possible on-screen colors (16 colors vs 25 colors),
; palette handling is always a per-game issue.
;
; The only default behavior is writing the background color, which is always mapped to
; palette index 0 for convenience.

        mx   %00
; Called (jsl) by STA_2007 with the byte in PPU_MEM already updated; X = the palette address, 8-bit A,
; the ROM's P / A / X on the stack below the return address.  DBR is the ROM's bank, not ours.
PPUDATA_WRITE_PAL ENT
        phb
        phk
        plb
        rep  #$20

        txa
        and  #$001F
        asl
        tax

        lda  6,s                        ; (B, the return address, X, then the ROM's A)
        and  #$003F                     ; Pass in the NES color in the accumulator

        phy                             ; Palette handlers might overwrite any register, so preserve Y
        DO   CUSTOM_PPU_PALETTE_DISPATCH
        jsr  (PPU_PALETTE_DISPATCH,x)   ; The game's table (Hooks.s, EngineExt.s)
        FIN
        DO   1-CUSTOM_PPU_PALETTE_DISPATCH
        jsr  (ppuPaletteDispatch,x)     ; The engine's (ppu_palette.s)
        FIN
        ply

        plb
        rtl

        mx   %11
; Trigger a copy from a page of memory to OAM.  Since this is a DMA operation, we can cheat a little and do a 16-bit copy
PPU_OAM equ 0                       ; direct page base address

        DO MOUSE_ZAPPER
Mouse_OamDma EXT                    ; rom/rom_mouse.s (MAIN)
        FIN

        mx    %11
PPUDMA_WRITE ENT
        DO DIRECT_OAM_READ
        DO MOUSE_ZAPPER
        jml   Mouse_OamDma          ; The Zapper's light sense keeps the page the NES shows (rom/rom_mouse.s)
        FIN
        rtl                         ; Cheat a lot and pretend it didn't happen.  Read from NES RAM directly when we render
        ELSE

        php                         ; Otherwise copy into a direct page buffer
        pha

        rep   #$30
        phd
        ldal  DP_OAM
        tcd

]n      equ   {OAM_START_INDEX}
        lup   {OAM_END_INDEX-OAM_START_INDEX}
        lda   ROMBase+$200+{]n*4}                ; This is not actually correct, but most games use $0200 for DMA buffer
        sta   PPU_OAM+{]n*4}
        lda   ROMBase+$202+{]n*4}
        sta   PPU_OAM+2+{]n*4}
]n      =     ]n+1
        --^

        pld
        sep   #$30

        pla
        plp
        rtl
        FIN
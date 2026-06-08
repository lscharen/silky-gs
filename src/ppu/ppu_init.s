; ppu_init.s - PPU Subsystem Initialization
;
; One-time startup routine for the PPU simulator.  Called from NES_StartUp
; (scaffold.s) after the tile-compilation banks have been allocated.
;
;   PPUStartUp  - Patches the compile-bank addresses into the jsl dispatch
;                 stubs (patch0-4, csd), initialises the nametable-to-PEA
;                 mapping tables, and fills the palette shadow with
;                 out-of-range sentinel values so the first real palette
;                 write is never skipped.  Returns carry clear on success.

        mx   %00

; Initialize any data structure and internal state for emulating the NES PPU
;
; Must return carry clear on success
PPUStartUp
        lda   CompileBank0+1            ; Patch some dispatch addresses with the tile compilation bank
        sta   patch0+2
        sta   patch1+2
        sta   patch2+2
        sta   patch3+2
        sta   patch4+2

        lda   SpriteBank0+1             ; Patch some dispatch addresses with the sprite compilation bank
        sta   csd+2

        DO    NAMETABLE_MIRRORING&HORIZONTAL_MIRRORING
        jsr   _InitPPUTileMappingHorz       ; Set up the lookup tables in the PPU shadow RAM
        ELSE
        jsr   _InitPPUTileMappingVert       ; Set up the lookup tables in the PPU shadow RAM
        FIN

        lda   #$FFFF                    ; Set initial palette values to out-of-range values
        ldx   #0
:loop
        stal  PPU_MEM+$3F00,x
        inx
        inx
        cpx   #$20
        bcc   :loop

        clc
        rts

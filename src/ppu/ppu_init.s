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

; Initialize any data structure and internal state for emulating the NES PPU
;
; Must return carry clear on success
        mx   %00
PPUStartUp
        lda   CompileBank0+1            ; Patch some dispatch addresses with the tile compilation bank
        sta   patch0+2
        sta   patch1+2
        sta   patch2+2
        sta   patch3+2
        sta   patch4+2

        lda   SpriteBank0+1             ; Patch some dispatch addresses with the sprite compilation bank
        sta   csd+2

; Clear / initialize any of the tracking queues

        jsr   PPUResetQueues

        jsr   _InitBTable               ; The static PEA row address table

; This is not fixed, but games can define the mirroring mode that the cart
; is configured with at power on

        lda   #NAMETABLE_MIRRORING
        jsr   PPUSetMirrorMode

; Initialize the CIRAM-to-PEA_Field mappings. This is invarient to the choice of mirroring
; but needs to happen after other tables are filled in.

        jsr   _InitCIRAMTileMapping

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

; Reconfigure the engine for mirroring.  This function can be called while the
; engine is running to respond to dynamic mirroring changes supported by mappers
; like the MMC1.  It only updates a few direct page values; the PEA field itself
; does not depend on the mirroring mode.
;
; A = mirror mode ($01 = Horizontal, $02 = Vertical)
        mx   %00
PPUSetMirrorMode
        bit  #HORIZONTAL_MIRRORING
        beq  :not_horz
        jmp  _InitHorizontalMirroring

:not_horz
        bit  #VERTICAL_MIRRORING
        beq  :not_vert
        jmp  _InitVerticalMirroring

; Some unsupported configuration.  Do nothing
:not_vert
        rts

; Fill in the BTable with the address of the even page (CIRAM page 0) of each of the 240
; PEA rows.  Rows 0 - 119 are in the first blitter bank and rows 120 - 239 in the second.
; The table does not depend on the mirroring mode, so this only needs to be done once.
               mx        %00
_InitBTable
               ldx       #0
               ldy       #lite_base_1
:loop1
               tya
               sta       BTableLow,x
               clc
               adc       #_LINE_SPAN
               tay

               lda       #^lite_base_1
               sta       BTableHigh,x

               inx
               inx
               cpx       #_LINES_PER_BANK*2
               bcc       :loop1

               ldy       #lite_base_2
:loop2
               tya
               sta       BTableLow,x
               clc
               adc       #_LINE_SPAN
               tay

               lda       #^lite_base_2
               sta       BTableHigh,x

               inx
               inx
               cpx       #_LINES_PER_BANK*2*2
               bcc       :loop2

               rts

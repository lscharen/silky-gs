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

; This is not fixed, but games can define the mirroring mode that the cart
; is configured with at power on

        lda   #NAMETABLE_MIRRORING
        jsr   PPUSetMirrorMode

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
; like the MMC1.
;
; A = mirror mode ($01 = Horizontal, $02 = Vertical)
        mx   %00
PPUSetMirrorMode
        bit  #HORIZONTAL_MIRRORING
        beq  :not_horz

        jsr   _InitHorizontalMirroring
        jsr   _InitLiteBlitterHorz
        jmp   _InitPPUTileMappingHorz 

:not_horz
        bit  #VERTICAL_MIRRORING
        beq  :not_vert

        jsr   _InitVerticalMirroring
        jsr   _InitLiteBlitterVert
        jmp   _InitPPUTileMappingVert 

; Some unsupported configuration.  Do nothing
:not_vert
        rts

; Set up the data tables for horizontal mirroring
               mx        %00
_InitLiteBlitterHorz
               ldx       #0
               ldy       #lite_base_1
:loop1a
               tya
               sta       BTableLow,x
               clc
               adc       #_LINE_SIZE_H                ; The screen wraps vertically
               sta       BTableLow+{240*2},x
               adc       #_LINE_SIZE_H
               tay

               lda       #^lite_base_1
               sta       BTableHigh,x
               sta       BTableHigh+{240*2},x

               inx
               inx
               cpx       #_LINES_PER_BANK*2
               bcc       :loop1a

               ldy       #lite_base_2
:loop1b
               tya
               sta       BTableLow,x
               clc
               adc       #_LINE_SIZE_H
               sta       BTableLow+{240*2},x
               adc       #_LINE_SIZE_H
               tay

               lda       #^lite_base_2
               sta       BTableHigh,x
               sta       BTableHigh+{240*2},x

               inx
               inx
               cpx       #_LINES_PER_BANK*2*2
               bcc       :loop1b

               rts

; Set up the data tables for vertical mirroring
               mx        %00
_InitLiteBlitterVert

; Fill in the BTable and BRowTable values.  There are 120 lines in each bank and each line covers two of
; the 256-pixel wide NES nametables.  The table pointers are the address of the start of each wide
; nametable row

               ldx       #0
               ldy       #lite_base_1

:loop1a
               tya
               sta       BTableLow,x
               sta       BTableLow+{240*2},x
               clc
               adc       #_LINE_SIZE_V
               tay

               lda       #^lite_base_1
               sta       BTableHigh,x
               sta       BTableHigh+{240*2},x

               inx
               inx
               cpx       #_LINES_PER_BANK*2
               bcc       :loop1a

               ldy       #lite_base_2
:loop1b
               tya
               sta       BTableLow,x
               sta       BTableLow+{240*2},x
               clc
               adc       #_LINE_SIZE_V
               tay

               lda       #^lite_base_2
               sta       BTableHigh,x
               sta       BTableHigh+{240*2},x

               inx
               inx
               cpx       #_LINES_PER_BANK*2*2
               bcc       :loop1b

               rts

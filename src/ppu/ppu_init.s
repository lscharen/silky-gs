; ppu_init.s - PPU Subsystem Initialization
;
; One-time startup routine for the PPU simulator.  Called from NES_StartUp
; (scaffold.s) after the tile-compilation banks have been allocated.
;
;   PPUStartUp  - Patches the compile-bank addresses into the jsl dispatch
;                 stubs (patch0-4), initialises the nametable-to-PEA
;                 mapping tables, and fills the palette shadow with
;                 out-of-range sentinel values so the first real palette
;                 write is never skipped.  Returns carry clear on success.

; Initialize any data structure and internal state for emulating the NES PPU
;
; Must return carry clear on success
        mx   %00
PPUStartUp

; Put the compile bank into the CALL_COMPILED_TILE jsls (the bank byte, at +3; this also clears the
; address' high byte, which SET_COMPILED_TILE sets before each call)
        lda   CompileBank0+1
        sta   patch0+2
        sta   patch1+2
        sta   patch2+2
        sta   patch3+2
        sta   patch4+2

        jsr   SprCacheInit              ; Empty compiled sprite cache; all of the slots are free (the
                                        ; dispatch, csd, takes each slot's bank from its entry)

; Clear / initialize any of the tracking queues

        jsr   PPUResetQueues

        jsr   _InitBTable               ; The static PEA row address table

; Set the mirroring mode that the cartridge is configured with at power on.  NES_StartUp
; leaves it in PendingMirrorMode.

        lda   PendingMirrorMode
        jsr   PPUSetMirrorMode
        stz   PendingMirrorMode

; Initialize the CIRAM-to-PEA_Field mappings. This is invarient to the choice of mirroring
; but needs to happen after other tables are filled in.

        jsr   _InitCIRAMTileMapping

        DO    ENABLE_DIRTY_RENDERING
        jsr   gridStartUp               ; Static tables for the grid dirty renderer
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

; Reconfigure the engine for mirroring.  This function can be called while the
; engine is running to respond to dynamic mirroring changes supported by mappers
; like the MMC1.  It only updates a few direct page values; the PEA field itself
; does not depend on the mirroring mode.
;
; A = mirror mode ($01 = Horizontal, $02 = Vertical).  If neither bit is set, the
;     engine defaults to horizontal mirroring so that the mirroring state is always
;     initialized.
        mx   %00
PPUSetMirrorMode
        bit  #VERTICAL_MIRRORING
        beq  :horz
        bit  #HORIZONTAL_MIRRORING
        bne  :horz
        jmp  _InitVerticalMirroring

:horz   jmp  _InitHorizontalMirroring

        mx   %00
; Mirroring
;
; The PEA field rows map 1:1 onto the CIRAM pages, so a mirroring change only needs to update the
; address masks and the V flag that is used to enter the blitter.  Nothing in the code field is
; patched, so these are cheap enough to call whenever a mapper changes the mirroring mode.
;
; The scroll values derived by _UpdateScrollStart and the entry and exit points in the code field
; depend on the mirroring mode, so a change updates them and forces a full setup of the code field
; on the next render.
;
; With horizontal mirroring each line stays within one CIRAM page, which creates a virtual 256x480
; rendering surface.
_InitHorizontalMirroring
                  lda       #HORIZONTAL_MIRROR_MASK
                  sta       MirrorMaskLong
                  lda       #$07E0
                  sta       CIRAMRowMask         ; V = 0x3E0, H = 0x7E0
                  lda       #$001F
                  sta       CIRAMColMask         ; V = $041F, H = $001F

                  lda       #480
                  sta       MaxY
                  lda       #256
                  sta       MaxX

                  lda       #BLT_P_HORZ          ; V = 1: lines loop within their CIRAM page
                  sta       BltMirrorP

                  jsr       _UpdateScrollStart   ; The scroll values depend on the mirroring
                  lda       #DIRTY_BIT_BG0_X
                  tsb       DirtyBits
                  rts

; With vertical mirroring each line spans both CIRAM pages, which creates a virtual 512x240
; rendering surface.
_InitVerticalMirroring
                  lda       #VERTICAL_MIRROR_MASK
                  sta       MirrorMaskLong
                  lda       #$03E0
                  sta       CIRAMRowMask         ; V = 0x3E0, H = 0x7E0
                  lda       #$041F
                  sta       CIRAMColMask         ; V = $041F, H = $001F

                  lda       #240
                  sta       MaxY
                  lda       #512
                  sta       MaxX

                  stz       BltMirrorP           ; V = 0: lines continue into the other CIRAM page

                  jsr       _UpdateScrollStart   ; The scroll values depend on the mirroring
                  lda       #DIRTY_BIT_BG0_X
                  tsb       DirtyBits
                  rts

; Runtime nametable-mirroring mask, set by SetMirrorMode (ControlBits.s).
; Duplicates the DP MirrorMask (Defs.s) for use from contexts where the
; engine's own direct page isn't active (e.g. ppu_regs.s's PPU write
; handlers, entered from NES ROM code with the NES's own direct page) --
; those sites access this copy with long addressing (andl MirrorMaskLong)
; instead.
MirrorMaskLong ENT
             dw  0

; Corresponding mask for calculating the CIRAM location for a PPU
; nametable address
CIRAMRowMask ENT
             dw  0
CIRAMColMask ENT
             dw  0

; 0 = no mirroring-mode change pending; else HORIZONTAL_MIRRORING/
; VERTICAL_MIRRORING, the target mode ApplyMirrorMode should switch to at
; the next render (see core/ControlBits.s SetMirrorMode/ApplyMirrorMode).
; Absolute, not DP, for the same reason as MirrorMaskLong above --
; SetMirrorMode writes it via long addressing from NES ROM code.
;
; Note that the actual mask values have to be update dimmediately.  This
; flag is purly for deferred work that needs to happen before the next
; *render*
PendingMirrorMode ENT
            dw  0

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

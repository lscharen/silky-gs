; ppu_regs.s - NES PPU Register Interface ($2000-$2007 + OAM DMA)
;
; This file contains:
;
;   PPU State Variables
;   -------------------
;   The internal state of the NES PPU registers.  ppuaddr (ENT) is the
;   current VRAM address pointer; w_bit tracks the high/low byte write
;   toggle for PPUADDR and PPUSCROLL writes.
;
;   Register Entry Points (ENT)
;   ---------------------------
;   Each NES PPU register write/read is intercepted by the ROM injection
;   layer (rom_inject.s) and routed to the corresponding ENT label here:
;
;     PPUCTRL_WRITE   ($2000 W) - nametable base, increment, sprite/bg table
;     PPUMASK_WRITE   ($2001 W) - rendering enable flags
;     PPUSTATUS_READ  ($2002 R) - VBL flag, clears address latch
;     PPUSTATUS_READ_X          - variant for "ldx ppustatus" pattern
;     OAMADDR_WRITE   ($2003 W) - OAM byte address
;     PPUSCROLL_WRITE ($2005 W) - scroll position (written twice)
;     PPUADDR_WRITE   ($2006 W) - VRAM address (written twice)
;     PPUDATA_READ    ($2007 R) - VRAM read with buffering
;     PPUDATA_WRITE   ($2007 W) - VRAM write; routes to NT/AT queues or
;                                 palette dispatch
;     PPUDMA_WRITE    ($4014 W) - Sprite DMA transfer
          mx    %11
          dw $a5a5 ; marker to find in memory
ppuaddr   ENT
          ds 2     ; 16-bit ppu address
w_bit     dw 1     ; currently writing to high or low to the address latch
vram_buff dw 0     ; latched data when reading VRAM ($0000 - $3EFF)

ppuincr   dw 1     ; 1 or 32 depending on bit 2 of PPUCTRL
spadr     dw PPU_SPR_TILE_ADDR ; Sprite pattern table ($0000 or $1000) depending on bit 3 of PPUCTRL
ntaddr    dw $2000 ; Base nametable address ($2000, $2400, $2800, $2C00), bits 0 and 1 of PPUCTRL
bgadr     dw PPU_BG_TILE_ADDR ; Background pattern table address
ppuctrl   dw 0     ; Copy of the ppu ctrl byte
ppumask   dw 0     ; Copy of the ppu mask byte
ppustatus dw 0
oamaddr   dw 0     ; Typically this will always be 0
ppuscroll dw 0     ; Y X coordinates

PPU_VERSION ds 2   ; Something to track a version counter

; Value to mask with ppumask to allow the runtime to override some bits
ppumask_override dw $FFFF

; MMC1 registers
mmc1_shft   ENT
            ds    1
mmc1_regs   ENT
mmc1_reg0   ds    1
mmc1_reg1   ds    1
mmc1_reg2   ds    1
mmc1_reg3   ds    1

; Currently-selected CHR bank. Stub for future MMC1 CHR-bank-switching
; support -- always zero today and not yet read anywhere. 16-bit so it can
; be loaded in either 8- or 16-bit mode by future code without a width
; mismatch.
chr_bank    ENT
            ds    2

; ntbase    db $20,$24,$28,$2c


; $2000 - PPUCTRL (Write only) (optimized, if we can defer resolving ntaddr, spadr and bgadr, this can be simplified further))
        mx    %11
PPUCTRL_WRITE ENT
        php

; Save the control byte
        stal ppuctrl
        phx

; Cache the value
        tax

; Set the pattern table base address
        and  #$03
        asl
        asl
        ora  #$20
        stal ntaddr+1

; Set the vram increment
        txa
        and  #$04
        beq  :v1
        lda  #$21
:v1     eor  #$01
        stal ppuincr

; Set the sprite table address
        txa
        and  #$08
        asl
        stal spadr+1

; Set the background table address
        txa
        and  #$10
        stal bgadr+1

        txa
        plx
        plp
        rtl

; $2001 - PPUMASK (Write only)
        mx    %11
PPUMASK_WRITE ENT
        stal ppumask
        rtl


; $2002 - PPUSTATUS For "ldx ppustatus"
        mx    %11
PPUSTATUS_READ_X ENT
        pha

        lda  #1
        stal w_bit             ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        tax
        and  #$7F              ; Clear the VBL flag
        stal ppustatus

        pla                    ; Restore the accumulator (return value in X)
        phx                    ; re-read x to set any relevant flags
        plx

        rtl


; $2002 - PPUSTATUS For "lda ppustatus"
; MUST NOT change any P flags not set by the PLA before the return.
        mx    %11
PPUSTATUS_READ ENT
        lda  #1
        stal w_bit           ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        pha
        and  #$7F            ; Clear the VBL flag
        stal ppustatus

        pla                  ; re-read accumulator to set any relevant flags
        rtl


; $2003
        mx    %11
OAMADDR_WRITE ENT
        stal oamaddr
        rtl

; $2005 - PPU SCROLL
        mx    %11
PPUSCROLL_WRITE ENT
        php
        phx
        pha

        ldal w_bit
        tax
        eor  #$01
        stal w_bit

        pla
        stal ppuscroll,x

        plx
        plp
        rtl

; $2006 - PPUADDR
        mx    %11
PPUADDR_WRITE ENT
        php
        phx
        pha

        ldal w_bit
        tax
        eor  #$01
        stal w_bit

        pla
        stal ppuaddr,x

        plx
        plp
        rtl

        mx    %11
PPUDATA_READ ENT
        pha             ; space for return result
        phx

        rep  #$31
        ldal ppuaddr    ; Load and update the ppu address (guaranteed to be in the range $0000 - $3FFF)
        tax
        adcl ppuincr
        stal ppuaddr

        cpx  #$3F00     ; If we're reading palette RAM, return the value immediately
        bcc  :buff_read

        ldal PPU_MEM,x  ; do a 16-bit read, but we'll ignore the top byte
        sep  #$30
        sta  2,s

        plx
        pla
        rtl

        mx   %00
:buff_read
        cpx  #$2000
        bcc  :not_in_nt   ; If we are not in the nametable space, just read the PPU memory and return

; apply mirroring
;
; HMIRROR_ADDR = PPU_ADDR & $FBFF
; VMIRROR_ADDR = PPU_ADDR & $FDFF

        txa
        andl MirrorMaskLong   ; runtime nametable-mirroring mask (see SetMirrorMode, ControlBits.s)
        tax

:not_in_nt
        sep  #$20       ; 8-bit acc/16-bit regs
        ldal vram_buff
        sta  2,s
        ldal PPU_MEM,x
        stal vram_buff
        sep  #$30

        plx
;        plb
;        plp
;        pha
        pla
        rtl

        mx  %11
PPUDATA_WRITE ENT
        php
        phb
        phk
        plb
        pha
        phx

        rep  #$31
        lda  ppuaddr                  ; Load and update the ppu address (guaranteed to be in the range $0000 - $3FFF)
        tax
        adc  ppuincr
        sta  ppuaddr

; 1. In the range $2{x}00 to $2{x+3}BF -- this is tile data, so it should be queued for an update
; 2. In the range $2{x+3}C0 to $2{x+3}FF -- this is tile attribute data and should be put on a separate queue
; 3. In the range $3F00-$3FFF -- this is the palette range and executes a callback function to take a game-specific action

        cpx  #$2000
        DO   HAS_CHR_RAM
        bcs  :not_chr

; Write into CHR-RAM ($0000-$1FFF). Store the byte where the tile-conversion
; routines will read it from (mirrors the nametable-write pattern below),
; then mark the affected tile ID dirty for on-demand recompilation at draw
; time (DrawPPUTile / CheckSprTileDirty), instead of pre-compiling everything
; up front like a fixed CHR-ROM game does.

        sep  #$20
        lda  2,s
        stal PPU_MEM,x

        rep  #$30
        txa                    ; X is in the range $0000 - $1FFF
        lsr                    ; Convert to tile index
        lsr
        lsr
        lsr
        tax
        sep  #$20
        lda  #$80              ; neither BG nor sprite form ready (see ChrRamDirty tri-state, ppu_regs.s PPUCTRL_WRITE)
        stal ChrRamDirty,x
        bra  :done
:not_chr
        ELSE
        bcc  :done
        FIN

        cpx  #$3000
        bcc  :in_nt                  ; If the high byte is $20 or $30, then we are in the nametable space

        cpx  #$3F00
        bcs  :extra
        bra  :done

; The PPU wrote to some location in the Nametable RAM ($2000 - $2FFF).  Now we need to determine if it
; wrote to the nametable tile data area or the tile attribute area.  There are separate queues for each
; of these pieces of memory since each attribute byte afftect 16 tiles, it's important to process the
; attribute changes first to avoid having to redraw tiles since the IIgs does not have enough colors
; to directly support the palette indexes and has to redraw tiles when their palette assignment changes.
:in_nt

        txa
        andl MirrorMaskLong   ; runtime nametable-mirroring mask (see SetMirrorMode, ControlBits.s)
        tax

; Switch to 8-bit accumulator with 16-bit registers to compare the accumulator value that was passed
; into the function

        sep  #$20

; Check to see if the tile passed in is different that the one that is currently in the PPU memory. If
; there is no change, then no need to update the IIgs graphics.

        lda  2,s
        cmpl PPU_MEM,x
        beq  :done
        stal PPU_MEM,x

; Check if this location has already been marked for an update.  If it has, then do not add it to the update
; list again.

        lda  PPU_VERSION              ; Get the current frame version
        cmpl PPU_MEM+TILE_VERSION0,x  ; Check if this location is marked for an update
        beq  :done                    ; It's already been marked
        stal PPU_MEM+TILE_VERSION0,x  ; Mark this memory location as scheduled for an update

        rep  #$20

        txa                          ; Determine if we add to the AT or NT list
        and  #$03C0                  ; Is this in the tile attribute space?
        cmp  #$03C0
        bcc  :is_nt

; TODO: Add a limit flag here to skip adding more entries if the list is getting too full.  Once a certain number
; of entries are in the list, it's probably faster to just redraw the entire screen without processing the changes
; one by one, e.g. on game startup with the whole PPU Nametable RAM is initialized.

        txa
        ldx  curr_at_list_end
        sta  at_list,x
        inx
        inx
        stx  curr_at_list_end
        bra  :done

:is_nt
        txa
        ldx  curr_nt_list_end
        sta  nt_list,x
        inx
        inx
        stx  curr_nt_list_end

:done
        sep  #$30
        plx
        pla
        plb
        plp
        rtl

; Do some extra work to keep palette data in sync. Because the IIgs palette is not
; large enough to accomodate all of the possible on-screen colors (16 colors vs 25 colors),
; palette handling is always a per-game issue.
;
; The only default behavior is writing the background color, which is always mapped to
; palette index 0 for convenience.

        mx   %00
:extra
        sep  #$20
        lda  2,s
        cmpl PPU_MEM,x
        beq  :done                      ; Palette updates can be *very* expensive, so skip if no change
        stal PPU_MEM,x
        rep  #$20

        txa
        and  #$001F
        asl
        tax

        lda  2,s
        and  #$003F                     ; Pass in the NES color in the accumulator

        phy
        jsr  (PPU_PALETTE_DISPATCH,x)   ; Palette handlers might overwrite any register, so preserve Y
        ply

        sep  #$30
        plx
        pla
        plb
        plp
        rtl

        mx   %11
; Trigger a copy from a page of memory to OAM.  Since this is a DMA operation, we can cheat a little and do a 16-bit copy
PPU_OAM equ 0                       ; direct page base address

        mx    %11
PPUDMA_WRITE ENT
        DO DIRECT_OAM_READ
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
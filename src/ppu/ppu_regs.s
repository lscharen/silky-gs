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
ppuctrl ENT
          dw 0     ; Copy of the ppu ctrl byte
ppumask   dw 0     ; Copy of the ppu mask byte
ppustatus ENT
          dw 0
oamaddr   dw 0     ; Typically this will always be 0
ppuscroll dw 0     ; Y X coordinates


; The pattern tables PPUCTRL selects, as the offset of the table's tiles in the tiledata and compile
; banks (512 tiles of 128 bytes): $8000 for the table at $1000, else $0000.  Both start at $0000, like
; PPUCTRL at power on.  Set by PPUCtrlDecode, for each render.
spadr_hi  dw $0000 ; Sprites: PPUCTRL bit 3
bgadr_hi  dw $0000 ; Background: PPUCTRL bit 4

; Value to mask with ppumask to allow the runtime to override some bits
ppumask_override ENT
                 dw $FFFF

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


; $2000 - PPUCTRL (Write only)
;
; Only the VRAM increment is resolved here, because the next $2007 access (NES task) needs it right away.
; The values only the render reads (ntaddr, spadr, bgadr and the derived _hi/_lo values) are resolved
; from ppuctrl by PPUCtrlDecode when NES_RenderFrame latches the registers.
        mx    %11
PPUCTRL_WRITE ENT
        php
        cmpl ppuctrl
        beq  :fast_exit

        stal ppuctrl
        pha
        and  #$04             ; Set the vram increment
        beq  :v1
        lda  #$21
:v1     eor  #$01
        stal ppuincr
        pla

:fast_exit
        plp
        rtl

; PPUCtrlDecode
;
; Resolve the render's pattern tables from the last PPUCTRL write (spadr_hi, bgadr_hi).  A change of
; the background table makes every tile in the PEA field stale, so it also asks for every tile to be
; redrawn (DIRTY_BIT_TILE_REDRAW, done by RenderDraw).  Called by RenderLatch, with interrupts off,
; before anything in the render reads them.  Only A is changed.  DBR = K.
        mx    %00
PPUCtrlDecode
        lda  ppuctrl          ; (only the low byte is ever written, so the high byte is 0)
        and  #$0008           ; Sprite pattern table
        beq  :sp
        lda  #$8000
:sp     sta  spadr_hi

        lda  ppuctrl
        and  #$0010           ; Background pattern table
        beq  :bg
        lda  #$8000
:bg     cmp  bgadr_hi
        beq  :same
        sta  bgadr_hi
        lda  #DIRTY_BIT_TILE_REDRAW
        tsb  DirtyBits
:same   rts

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
        inx                    ; reset x to set any relevant flags
        dex

        rtl


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

        DO   HAS_CHR_RAM
; The first write since the sprite form was converted (PPUDATA_WRITE): drop the tile's compiled sprites
; (every palette and vertical orientation), so a compiled-sprite hit never needs to check the dirty flag.  A tile with its sprite
; flag set never has a compiled sprite (SprCompileTile), so the other writes have nothing to drop.  The
; flag is set first: the GS task may compile in between, and it does not keep a sprite whose flag is set.

; X = the tile index (pattern table << 8 | tile).  Returns with 16-bit registers.
        mx   %10
DropTileSprites
        rep  #$30
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
        rts
        FIN

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
        bcc  :chr_read    ; Pattern table ($0000 - $1FFF): read CHR memory, not CIRAM

        txa
        ppu2ciram             ; map address to CIRAM address range ($000 - $7FF)
        tax

        sep  #$20       ; 8-bit acc/16-bit regs
        ldal vram_buff
        sta  2,s
        ldal PPU_CIRAM,x
        stal vram_buff
        sep  #$30

        plx
        pla
        rtl

; CHR-ROM / CHR-RAM lives at PPU_MEM $0000 - $1FFF (CHR-RAM writes in PPUDATA_WRITE store there too).
; SMB's title screen and Ice Climber's title / score screens are loaded by reading data stored in CHR.
        mx   %00
:chr_read
        sep  #$20       ; 8-bit acc/16-bit regs
        ldal vram_buff
        sta  2,s
        ldal PPU_MEM,x
        stal vram_buff
        sep  #$30

        plx
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
; time (DrawPPUTile / sprChrCheck), instead of pre-compiling everything
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
        bra  :done
:not_chr
        ELSE
        bcc  :done
        FIN

        cpx  #$3000
        bcc  :in_nt                  ; If the high byte is $2x, then we are in the nametable space

        cpx  #$3F00
        bcs  :extra
        bra  :done

; The PPU wrote to some location in the Nametable RAM ($2000 - $2FFF).  Changed bytes are tracked per
; attribute byte: once a changed byte is stored, ntmWriteTail (ppu_queues.s) keeps a copy in the current
; shadow buffer, sets the tile's bit in its 4x4 group's mask (or flags an attribute write) and queues
; the group for the next render.
        mx  %00
:in_nt
; There are two 1kb physical pages of Console Internal RAM (CIRAM) that back the four nametables. We need
; to convert the logical PPU address that's in the range $2000 - $2FFF into the internal RAM address.
;
; If VERTICAL mirroring, then CIRAM A10 == PPU A10:  ciram_addr = ppu_arr & 0x07FF
; If HORIZONTAL mirroring, then CIRAM A10 = PPU A11: ciram_addr = ((ppu_addr & 0x0800) >> 1) | (ppu_addr & 0x03FF)

        txa
        ppu2ciram
        tax
        sep  #$20

; Unchanged bytes need no work at all
        lda  2,s
        cmpl PPU_CIRAM,x
        beq  :done
        stal PPU_CIRAM,x
        jmp  ntmWriteTail             ; Shadow copy, tile mask / attribute flag, queue (ppu_queues.s)

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
        cmpl PPU_MEM,x                  ; x is the logical PPU address here (>= $3F00)
        beq  :done                      ; Palette updates can be *very* expensive, so skip if no change
        stal PPU_MEM,x
        rep  #$20

        txa
        and  #$001F
        asl
        tax

        lda  2,s
        and  #$003F                     ; Pass in the NES color in the accumulator

        phy                             ; Palette handlers might overwrite any register, so preserve Y
        DO   CUSTOM_PPU_PALETTE_DISPATCH
        jsr  (PPU_PALETTE_DISPATCH,x)   ; The game's table (Hooks.s, EngineExt.s)
        FIN
        DO   1-CUSTOM_PPU_PALETTE_DISPATCH
        jsr  (ppuPaletteDispatch,x)     ; The engine's (ppu_palette.s)
        FIN
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
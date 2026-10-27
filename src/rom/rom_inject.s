; This is a file that is meant to be included into a NES ROM code anywhere
; between the mapped RAM end address ($7FF) and the start of ROM code ($8000).
;
; Because we are emulating the NES memory in an actual 65816 RAM bank, there is
; actual RAM in the range $800 - $7FFF which we utilize to support the runtime.
; External wrapper is responsible for setting the stack

; These are external labels that implement the PPU function found in ppu/ppu.s
PPUSTATUS_READ        EXT
PPUDMA_WRITE          EXT
PPUDATA_WRITE_CHR     EXT
PPUDATA_WRITE_PAL     EXT
ntmWriteTail          EXT       ; ppu/ppu_queues.s: queue a changed nametable byte

; These are external labels that implement the PPU function found in apu/apu.s
APU_PULSE1_REG1_WRITE   EXT
APU_PULSE1_REG2_WRITE   EXT
APU_PULSE1_REG3_WRITE   EXT
APU_PULSE1_REG4_WRITE   EXT
APU_PULSE2_REG1_WRITE   EXT
APU_PULSE2_REG2_WRITE   EXT
APU_PULSE2_REG3_WRITE   EXT
APU_PULSE2_REG4_WRITE   EXT
APU_TRIANGLE_REG1_WRITE EXT
;APU_TRIANGLE_REG2_WRITE EXT
APU_TRIANGLE_REG3_WRITE EXT
APU_TRIANGLE_REG4_WRITE EXT
APU_NOISE_REG1_WRITE    EXT
APU_NOISE_REG2_WRITE    EXT
APU_NOISE_REG3_WRITE    EXT
APU_NOISE_REG4_WRITE    EXT

APU_DMC_REG1_WRITE      EXT
APU_DMC_REG2_WRITE      EXT
APU_DMC_REG3_WRITE      EXT
APU_DMC_REG4_WRITE      EXT
APU_STATUS_WRITE        EXT
APU_STATUS_READ         EXT

; Cooperative multitasking return vector.  Allows the non-interrupt ROM code to yield
; control back to the IIgs runtime.  Control will be returned the the caller of the
; yield at a later point with all registers intact.
yield EXT

; Byte that holds the currently selceted mapper bank
ROMBase     EXT
mapper_bank EXT
mmc1_shft   EXT
mmc1_regs   EXT

PPU_MEM     EXT                          ; The PPU memory bank (palette RAM reads)
PPU_CIRAM   EXT                          ; The nametable RAM (unchanged-byte check)

; Mirror control variables
PendingMirrorMode EXT
MirrorMaskLong    EXT
CIRAMRowMask      EXT
CIRAMColMask      EXT

; Table of routines used when reading from the APU registers ($4000 - $4017).
; Assumed reading in the accumulator
;apu_read_tbl
;            dw   APU_PULSE1_REG1,APU_PULSE1_REG2,APU_PULSE1_REG3,APU_PULSE1_REG4
;            dw   APU_PULSE2_REG1,APU_PULSE2_REG2,APU_PULSE2_REG3,APU_PULSE2_REG4
;            dw   APU_TRIANGLE_REG1,NO_OP,APU_TRIANGLE_REG3,APU_TRIANGLE_REG4
;            dw   APU_NOISE_REG1,NO_OP,APU_NOISE_REG3,APU_NOISE_REG4
;            dw   APU_DMC_REG1,APU_DMC_REG2,APU_DMC_REG3,APU_DMC_REG4
;            dw   NO_OP,APU_STATUS,NO_OP,LDA_4017

; Table of routines used when writing to the APU registers ($4000 - $4017)
; Assumed writing the accumulator
apu_write_tbl
            dw   STA_4000, STA_4001, STA_4002, STA_4003
            dw   STA_4004, STA_4005, STA_4006, STA_4007
            dw   STA_4008, NO_OP,    STA_400a, STA_400b
            dw   STA_400c, NO_OP,    STA_400e, STA_400f
            dw   STA_4010, STA_4011, STA_4012, STA_4013
            dw   NO_OP,    STA_4015, NO_OP,    STA_4017

; These functions are expected to be called in 8-bit mode from the ROM code
            mx    %11

MMC1_SHIFT  mac
            php
            pha
            bit   #$80         ; high-bit set --> register reset
            beq   shft
            lda   #$10
            sta   mmc1_shft    ; "reset" == set the detection bit in bit 4
            pla
            plp
            rts
shft
            and   #$01         ; isolate the bottom bit
            beq   zero
            lda   #$20         ; inject bit
            ora   mmc1_shft
            sta   mmc1_shft

zero
            lda   mmc1_shft    ; serial shift
            lsr
            sta   mmc1_shft
            bcs   done         ; is the shift register full?

            pla                ; no, return
            plp
            rts

done
            <<<

MMC1_RTN    mac
            lda   #$10         ; reset the shift register automatically (as documented)
            sta   mmc1_shft

            pla
            plp
            rts
            <<<

STA_MMC1_REG0
            MMC1_SHIFT

; If the ROM changes the mirroring mode, then the MirrorMaskLong value that is used to convert a logical
; PPU address to a physical CIRAM address in the PPUDATA_WRITE hook must be updated *immediately* so that
; any PPU writes go to the correct RAM location.
;
; Defered work that can wait until the next frame is triggered by setting the PendingMirrorMode value

            and  #$01                    ; Bit 0:1 select mirror mode; we only support H/V so just discriminate 2 vs 3.
            beq  :vert
            lda  #HORIZONTAL_MIRRORING
            stal PendingMirrorMode       ; This is a wide 8-bit variable, so 8- or 16-bit writes are ok
            lda  #$0B                    ; High byte of the $0BFF mask value
            stal MirrorMaskLong+1
            lda  #$07                    ; High byte of the $07E0 mask value
            stal CIRAMRowMask+1
            lda  #$00
            stal CIRAMColMask+1          ; High byte of the $001F mask value

            bra  :cont
:vert       lda  #VERTICAL_MIRRORING
            stal PendingMirrorMode
            lda  #$07                    ; High byte of the $07FF mask value
            stal MirrorMaskLong+1
            lda  #$03                    ; High byte of the $03E0 mask value
            stal CIRAMRowMask+1
            lda  #$04
            stal CIRAMColMask+1          ; High byte of the $041F mask value
:cont
            MMC1_RTN

STA_MMC1_REG1
STA_MMC1_REG2
            MMC1_SHIFT
            MMC1_RTN

STA_MMC1_REG3
            MMC1_SHIFT

; Commit changes -- what we care about here are bits 0 - 3 to select the bank
;
; The strategy for bank switching is built around the constraint that the IIgs memory
; system does not provide any sort of mirroring support that could be used to match
; the behavior of the NES mepper.
;
; Also, we simply do not have the CPU capacity to copy the NES RAM space (12kb) or the NES ROM
; space (16kb) into a shared area when bank switching occurs, which happens several times per
; frame.
;
; Instead, we opt for a hybrid approach where each bank of NES ROM lives in its own IIgs
; memory bank and any absolute memory references to that banks ROM space ($8000 - $BFFF)
; are manually patched out in the same manner as the PPU and APU register access.
;
; This is actually reasonable because the vast majority of reads and write are to NES RAM
; space (which makes sense, since that's where game state is maintained), or into the common
; routines in the shared Bank 7 ROM space.
;
; Since bank 0 can be put into the working bank, only Banks 1 through 7 need to be updated.
; For Zelda, this is just under 350 instructions, which is a manageable number.
            and   #$07
            clc
            adc   #^ROMBase
            sta   mapper_bank       ; This is the IIgs memory bank, not the NES data bank

; Trampoline to pass control to the other bank.  This rom_inject file must be replicated in
; every bank at the same address so that a long jump into the new mapper_bank will still
; hit the same code.

            stal  :patch+3          ; needs to actually write to the executing bank (K), not the NES data bank.
:patch      jml   :done

:done
            MMC1_RTN

; Optimized MMC1 bank switch if the accumulator has the bank
SET_MMC1_REG3
            php
            pha

            and   #$07
            clc
            adc   #^ROMBase
            sta   mapper_bank
            stal  :patch+3
:patch      jml   :done
:done
            pla
            plp
            rts

; Optimized MMC1 bank switch if the accumulator has the bank. Does not
; preserve P or A registers
SET_MMC1_REG3_FAST
            and   #$07
            clc
            adc   #^ROMBase
            sta   mapper_bank
            stal  :patch+3
:patch      jml   :done
:done
            rts

; UxROM (mapper 2) bank select.  A holds the bank number written to $8000-$FFFF.
; Low 3 bits select the 16KB bank at $8000 (Contra has 8).  The fixed bank stays
; at $C000 in every IIgs bank, so this only changes the program bank.  The shadow
; byte at $07EE is what `lda BANK_NUMBER` reads: a data read of $8000 would hit
; bank 0, because DBR stays on ROMBase.
;
; This code is copied into every PRG bank at the same address.  The jml lands on
; :uxdone in the new bank, and rts returns to the caller there.
STA_UXROM_BANK
            sta   $07EE
            jmp   SET_MMC1_REG3

APU_PULSE1  EXT
ORA_4000    oral APU_PULSE1+0
            rts
LDA_4000    ldal APU_PULSE1+0
            rts

STA_4000    jsl  APU_PULSE1_REG1_WRITE
NO_OP       rts

STX_4000    php
            phx
            pha
            txa
            jsl  APU_PULSE1_REG1_WRITE
            pla
            plx
            plp
            rts

STA_4000_Y
            php
            phx
            pea  :rtn-1
            pha
            tya
            asl
            tax
            pla
            jmp  (apu_write_tbl,x)
:rtn        plx
            plp
            rts

STA_4000_X
            php
            phx
            pea  :xrtn-1
            pha
            txa
            asl
            tax
            pla
            jmp  (apu_write_tbl,x)
:xrtn       plx
            plp
            rts


STA_4001    jsl  APU_PULSE1_REG2_WRITE
            rts

STX_4001    php
            pha
            txa
            jsl  APU_PULSE1_REG2_WRITE
            pla
            plp
            rts

STA_4001_X
            php
            phx
            pea  :xrtn-1
            pha
            txa
            asl
            tax
            pla
            jmp  (apu_write_tbl+2,x)
:xrtn       plx
            plp
            rts

STY_4001    php
            phy
            pha
            tya
            jsl  APU_PULSE1_REG2_WRITE
            pla
            ply
            plp
            rts


STA_4002    jsl  APU_PULSE1_REG3_WRITE
            rts

STA_4002_X
            php
            phx
            pea  :rtn-1
            pha
            txa
            asl
            tax
            pla
            jmp  (apu_write_tbl+4,x)
:rtn        plx
            plp
            rts

STA_4002_Y
            php
            phx
            pea  :yrtn-1
            pha
            tya
            asl
            tax
            pla
            jmp  (apu_write_tbl+4,x)
:yrtn       plx
            plp
            rts

STY_4002    php
            phy
            pha
            tya
            jsl  APU_PULSE1_REG3_WRITE
            pla
            ply
            plp
            rts

STA_4003    jsl  APU_PULSE1_REG4_WRITE
            rts

STA_4003_X
            php
            phx
            pea  :rtn-1
            pha
            txa
            asl
            tax
            pla
            jmp  (apu_write_tbl+6,x)
:rtn        plx
            plp
            rts

STA_4003_Y
            php
            phx
            pea  :yrtn-1
            pha
            tya
            asl
            tax
            pla
            jmp  (apu_write_tbl+6,x)
:yrtn       plx
            plp
            rts

STY_4003    php
            phy
            pha
            tya
            jsl  APU_PULSE1_REG4_WRITE
            pla
            ply
            plp
            rts

APU_PULSE2  EXT
ORA_4004    oral APU_PULSE2+0
            rts
LDA_4004    ldal APU_PULSE2+0
            rts

STA_4004    jsl  APU_PULSE2_REG1_WRITE
            rts

STX_4004    php
            phx
            pha
            txa
            jsl  APU_PULSE2_REG1_WRITE
            pla
            plx
            plp
            rts

STY_4004    php
            phy
            pha
            tya
            jsl  APU_PULSE2_REG1_WRITE
            pla
            ply
            plp
            rts
    
STA_4005    jsl  APU_PULSE2_REG2_WRITE
            rts

STY_4005    php
            phy
            pha
            tya
            jsl  APU_PULSE2_REG2_WRITE
            pla
            ply
            plp
            rts

STX_4005    php
            phx
            pha
            txa
            jsl  APU_PULSE2_REG2_WRITE
            pla
            plx
            plp
            rts

STA_4006    jsl  APU_PULSE2_REG3_WRITE
            rts

STA_4007    jsl  APU_PULSE2_REG4_WRITE
            rts

STA_4008    jsl  APU_TRIANGLE_REG1_WRITE
            rts

STY_4008    php
            phy
            pha
            tya
            jsl  APU_TRIANGLE_REG1_WRITE
            pla
            ply
            plp
            rts

STA_400A
STA_400a    jsl  APU_TRIANGLE_REG3_WRITE
            rts

STA_400B
STA_400b    jsl  APU_TRIANGLE_REG4_WRITE
            rts

STY_400B
STY_400b    php
            phy
            pha
            tya
            jsl  APU_TRIANGLE_REG4_WRITE
            pla
            ply
            plp
            rts

STA_400C
STA_400c    jsl  APU_NOISE_REG1_WRITE
            rts

STA_400E
STA_400e    jsl  APU_NOISE_REG3_WRITE
            rts

STX_400E
STX_400e    php
            phx
            pha
            txa
            jsl  APU_NOISE_REG3_WRITE
            pla
            plx
            plp
            rts

STA_400F
STA_400f    jsl  APU_NOISE_REG4_WRITE
            rts

STX_400F
STX_400f    php
            phx
            pha
            txa
            jsl  APU_NOISE_REG4_WRITE
            pla
            plx
            plp
            rts

STY_400F
STY_400f    php
            phy
            pha
            tya
            jsl  APU_NOISE_REG4_WRITE
            pla
            ply
            plp
            rts

STA_4010    jsl  APU_DMC_REG1_WRITE
            rts

STX_4010    php
            pha
            txa
            jsl  APU_DMC_REG1_WRITE
            pla
            plp
            rts

STY_4010    php
            pha
            tya
            jsl  APU_DMC_REG1_WRITE
            pla
            plp
            rts

STA_4012    jsl  APU_DMC_REG3_WRITE
            rts

STX_4012    php
            pha
            txa
            jsl  APU_DMC_REG3_WRITE
            pla
            plp
            rts

STY_4012    php
            pha
            tya
            jsl  APU_DMC_REG3_WRITE
            pla
            plp
            rts

STA_4013    jsl  APU_DMC_REG4_WRITE
            rts

STX_4013    php
            pha
            txa
            jsl  APU_DMC_REG4_WRITE
            pla
            plp
            rts

STY_4013    php
            pha
            tya
            jsl  APU_DMC_REG4_WRITE
            pla
            plp
            rts

; $4011 (DMC direct load) only sets the starting level for the next decoded sample
STA_4011    jsl  APU_DMC_REG2_WRITE
            rts

STX_4011    php
            pha
            txa
            jsl  APU_DMC_REG2_WRITE
            pla
            plp
            rts

STY_4011    php
            pha
            tya
            jsl  APU_DMC_REG2_WRITE
            pla
            plp
            rts

LDA_4015    jsl   APU_STATUS_READ
            rts

STA_4015    jsl   APU_STATUS_WRITE
            rts

STX_4015    php
            phx
            pha
            txa
            jsl   APU_STATUS_WRITE
            pla
            plx
            plp
            rts

; Joystick port (unsupported)
STX_4016
STA_4016    rts

LDA_4016
LDA_4016_X
        lda #0                ; no input
        rts

; $2000 - PPUCTRL (Write only)
;
; Only the VRAM increment is resolved here, because the next $2007 access (NES task) needs it right away.
STA_2000
        php
        cmp  ppuctrl
        beq  :fast_exit

        sta  ppuctrl
        pha
        and  #$04             ; Set the vram increment
        beq  :v1
        lda  #$21
:v1     eor  #$01
        sta  ppuincr          ; just the low byte
        pla

:fast_exit
        plp
        rts

STX_2000
        php
        cpx  ppuctrl
        beq  :fast_exit

        stx  ppuctrl
        pha
        txa
        and  #$04             ; Set the vram increment
        beq  :v1
        lda  #$21
:v1     eor  #$01
        sta  ppuincr          ; just the low byte
        pla

:fast_exit
        plp
        rts

; $2001 - PPUMASK (Write only)

STA_2001
        sta  ppumask
        rts


        mx    %11
STX_2001
        stx  ppumask
        rts

; $2002 - PPUSTATUS For "lda ppustatus"
        mx    %11
LDA_2002
        lda  #1
        sta  w_bit

        lda  ppustatus
        bpl  :out
        and  #$7F            ; Clear the VBL flag
        sta  ppustatus
        ora  #$80            ; Restore negative value
:out
        rts

        mx    %11
LDX_2002
        ldx  #1
        stx  w_bit

        ldx  ppustatus
        bpl  :out

        rol  ppustatus      ; Clear the VBL flag without A: bit 0 = C, C = 1 (the VBL bit)
        clc
        ror  ppustatus      ; bit 7 = 0, C = bit 0 = the caller's carry

        inx                 ; reset the status flags
        dex

:out
        rts

; $2003 - OAM ADDR
        mx    %11
STA_2003
        sta  oamaddr
        rts

; $2005 - PPU SCROLL
        mx    %11
STA_2005
        php
        phx

        ldx  w_bit
        sta  ppuscroll,x

        dex
        bpl  :ok
        ldx  #1
:ok     stx  w_bit

        plx
        plp
        rts

; $2006 - PPUADDR
        mx    %11
STA_2006
        php
        phx

        ldx  w_bit
        sta  ppuaddr,x

        dex
        bpl  :ok
        ldx  #1
:ok     stx  w_bit

        plx
        plp
        rts

        mx    %11
STY_2006
        php
        phy
        pha

        tya
        ldy  w_bit
        sta  ppuaddr,y

        dey
        bpl  :ok
        ldy  #1
:ok     sty  w_bit

        pla
        ply
        plp
        rts

        mx    %11
STX_2006
        php
        phx
        pha

        txa
        ldx  w_bit
        sta  ppuaddr,x

        dex
        bpl  :ok
        ldx  #1
:ok     stx  w_bit

        pla
        plx
        plp
        rts

        mx    %11
LDA_2007
        phx

        rep  #$31
        lda  ppuaddr    ; Load and update the ppu address (guaranteed to be in the range $0000 - $3FFF)
        tax
        adc  ppuincr
        sta  ppuaddr

        cpx  #$3F00     ; If we're reading palette RAM, return the value immediately
        bcc  :buff_read

        sep  #$20
        ldal PPU_MEM,x
        sep  #$10
        plx
        ora  #0         ; N / Z from the value, like lda (C and V unchanged)
        rts

        mx   %00
:buff_read
        cpx  #$2000
        bcc  :chr_read    ; Pattern table ($0000 - $1FFF): read CHR memory, not CIRAM

        txa

        andl MirrorMaskLong           ; ppu2ciram (macros are not loaded in the ROM segment)
        cmp  #$0800
        bcc  *+5
        eor  #$0C00

        tax

        sep  #$20       ; 8-bit acc/16-bit regs
        lda  vram_buff
        stal :p2+1      ; (long: the copy of this code in the bank being executed, not the data bank's)
        ldal PPU_CIRAM,x
        sta  vram_buff
        sep  #$30

        plx
:p2     lda  #0
        rts

; CHR-ROM / CHR-RAM lives at PPU_MEM $0000 - $1FFF (CHR-RAM writes in PPUDATA_WRITE store there too).
; SMB's title screen and Ice Climber's title / score screens are loaded by reading data stored in CHR.
        mx   %00
:chr_read
        sep  #$20       ; 8-bit acc/16-bit regs
        lda  vram_buff
        stal :p3+1
        ldal PPU_MEM,x
        sta  vram_buff
        sep  #$30

        plx
:p3     lda  #0
        rts

        mx    %11
; PPUDATA_WRITE - Keep the fast path in the bank
STA_2007
        php
        pha
        phx

        rep  #$31
        lda  ppuaddr                  ; Load and update the ppu address (guaranteed to be in the range $0000 - $3FFF)
        tax
        adc  ppuincr
        sta  ppuaddr

        cpx  #$2000
        DO   HAS_CHR_RAM
        bcs  :not_chr
        sep  #$20
        lda  2,s
        cmpl PPU_MEM,x
        beq  :done
        stal PPU_MEM,x
        jsl  PPUDATA_WRITE_CHR
        bra  :done
:not_chr
        ELSE
        bcc  :done
        FIN

        cpx  #$3000
        bcc  :in_nt

        cpx  #$3F00
        bcs  :pal

:done
        sep  #$30
        plx
        pla
        plp
        rts

        mx  %00
:in_nt  txa
        andl MirrorMaskLong           ; ppu2ciram (macros are not loaded in the ROM segment)
        cmp  #$0800
        bcc  *+5
        eor  #$0C00
        tax

        sep  #$20
        lda  2,s
        cmpl PPU_CIRAM,x
        beq  :done
        stal PPU_CIRAM,x

        jsl  ntmWriteTail
        bra  :done

        mx   %00
:pal    txa
        and  #$3F1F                ; clamp to the palette mirroring range
        tax

        sep  #$20
        lda  2,s
        cmpl PPU_MEM,x                  ; x is the logical PPU address here (>= $3F00)
        beq  :done                      ; Palette updates can be *very* expensive, so skip if no change
        stal PPU_MEM,x
        
        jsl  PPUDATA_WRITE_PAL
        bra  :done

        mx    %11
STX_2007
        php             ; (STA_2007 preserves X)
        pha
        txa
        jsr  STA_2007
        pla
        plp
        rts

STA_4014
            jsl  PPUDMA_WRITE
            rts
STY_4014
            php
            phy
            pha
            tya
            jsl  PPUDMA_WRITE
            pla
            ply
            plp
            rts

LDA_4017
STA_4017
STX_4017
            rts


; Include a bunch of routines to patch out the use of abs,y addressing modes and convert to load
; from the actual direct page
;
; For multi-bank, the patches have to be done using long addressing

LDA_LONG_Y  mac
            phx
            tyx
            ldal ]1,x
            plx
            ora  #$00
;            pha
;            pla
            rts
            <<<

ADC_LONG_Y  mac
            phx
            tyx
            adcl ]1,x
            plx
            ora  #$00       ; N/Z from the sum (plx clobbered them); C/V are untouched
            rts
            <<<

CMP_LONG_Y  mac
            pha
            phx
            tyx
            ldal ]1,x
            stal cly_patch+1
            plx
            pla
cly_patch   cmp  #0
            rts
            <<<

AND_LONG_Y  mac
            phx
            tyx
            andl ]1,x
            plx
            ora  #$00       ; refresh accumulator
;            pha
;            pla
            rts
            <<<

LDX_LONG_Y  mac
            pha
            tyx
            ldal ]1,x
            tax
            pla
            inx
            dex
;            phx
;            plx
            rts
            <<<

LDY_LONG_X  mac
            pha
            ldal ]1,x
            tay
            pla
            iny
            dey
;            phy
;            ply
            rts
            <<<

LDX_LONG    mac
            pha
            ldal ]1
            tax
            pla
            inx
            dex
;            phx
;            plx
           rts
            <<<

LDA_LONG    mac
            ldal ]1
            rts
            <<<
CMP_LONG    mac
            cmpl ]1
            rts
            <<<

LDA_LONG_X  mac
            ldal ]1,x
            rts
            <<<
CMP_LONG_X  mac
            cmpl ]1,x
            rts
            <<<
AND_LONG_X  mac
            andl ]1,x
            rts
            <<<
ORA_LONG_X  mac
            oral ]1,x
            rts
            <<<
ADC_LONG_X  mac
            adcl ]1,x
            rts
            <<<

LDA_ABS_Y   mac
            phx
            tyx
            lda  ]1,x
            plx
            ora  #$00
;            pha
;            pla              ; required reload to make sure Z,N flags are set correctly.
            rts
            <<<

STA_ABS_Y   mac
            php
            phx
            tyx
            sta  ]1,x
            plx
            plp
            rts
            <<<

ORA_ABS_Y   mac
            phx
            tyx
            ora  ]1,x
            plx
            ora  #$00       ; N/Z from the result (plx clobbered them); C/V are untouched
            rts
            <<<

CMP_ABS_Y   mac
;            php
            pha
            phx
            tyx
            lda  ]1,x
            stal cay_patch+1
            plx
            pla
;            plp
cay_patch   cmp  #0
            rts
            <<<

SBC_ABS_Y   mac
            phx
            tyx
            sbc  ]1,x
            plx
            ora  #$00       ; N/Z from the result (plx clobbered them); C/V are untouched
            rts
            <<<

ADC_ABS_Y   mac
            phx
            tyx
            adc  ]1,x
            plx
            ora  #$00       ; N/Z from the result (plx clobbered them); C/V are untouched
            rts
            <<<

; abs,X (unlike abs,Y) is a valid native dp,X addressing mode, so these don't
; need the register-shuffle trick the _ABS_Y macros use -- they just need to
; run from a JSR'd helper because a Zelda-style multi-bank port can't inline
; a plain "LDA Symbol,X" and have it correctly reach the shared NES zero-page
; bank from every program bank. See project_zelda_conversion memory notes.
LDA_ABS_X   mac
            lda  ]1,x
            rts
            <<<

STA_ABS_X   mac
            sta  ]1,x
            rts
            <<<

LDY_ABS_X   mac
            ldy  ]1,x
            rts
            <<<

JMP_ABS_IND mac
            php
            pha
            lda  ]1
            stal jai_patch+1
            lda  ]1+1
            stal jai_patch+2
            pla
            plp
jai_patch   jmp  $0000
            <<<

; Helpers for handling LDA (dp),y and STA (dp),y when the target value can also be on the zero page.  Since
; this is a 2-byte instruction, more work has to be done where the value is patched in
LDA_IND_Y   mac
            lda  ]1+1
            beq  zp
            lda  (]1),y
            rts
zp          phx
            tya
            clc
            adc  ]1
            tax
            lda  ]1,x
            plx
            ora  #$00
;            pha
;            pla
            rts
            <<<

STA_IND_Y   mac
            php
            lda  ]1+1
            beq  zp
            sta  (]1),y
            plp
            rts
zp          phx
            tya
            clc
            adc  ]1
            tax
            sta  ]1,x
            plx
            plp
            rts
            <<<

; Special routine. This is a generic handler for lda (xx),y instructions that automatically does the
; right thing, regardless of whether it is accessing zero page, the data bank, or the program bank
; and is intended to support MMC1 code. NROM games should used the simpler macros
;
; Branch order is tuned for the common cases: nearly every real call site targets either the
; switchable PRG window ($80-$BF, e.g. the per-byte TransferPatternBlock_Bank1 loop) or the
; fixed PRG bank ($C0-$FF), but the code is set up to trap zero-page and PPU/APU register accesses
; also.  Register traps are currently unimplemented until anactual use case is discovered.
MMC1_LDA_IND_Y mac
        lda  ]1+1       ; load the high address byte
        bmi  hi         ; HB >= $80 means we are in the upper half of memory, $8000 - $FFFF
        bit  #$FE       ; zero page AND the NES stack page ($0000-$01FF) are a special case
        beq  zpage
        bit  #$E0       ; $02-$1F: NES RAM, the bank register is fine
        beq  ok
        bit  #$40       ; $20-$3F: I/O -- floating bus
        beq  tail
        bit  #$20       ; $40-$5F: I/O -- floating bus; $60-$7F: WRAM falls through to ok
        beq  tail
ok      lda  (]1),y    ; it's ok to just execute the instruction as-is
        rts

hi      bit  #$40       ; $C0-$FF: fixed bank, ok as-is
        bne  ok

        phb             ; $80-$BF: switchable ROM window
        phk
        plb
        lda  (]1),y
        plb             ; this affects flags, but tail's ora below fixes them up
tail    ora  #$00
        rts

zpage
        php            ; only path that affects the carry bit
        phx
        rep  #$31      ; use 16-bit index registers for a quick add (and clear the carry)
        tya
        and  #$00FF    ; defensively clear the high byte
        adc  ]1        ; add Y to the address
        tax            ; X now indexes the NES zero page/stack pages ($0000-$01FF) together
        lda  $00,x     ; the direct page and stack for the NES are in adjacent pages, so this is valid
        and  #$00FF    ; clear the high byte before dropping back to 8-bit A (it's still garbage
                       ; from the 16-bit load above, since A's low byte is the only part that's real)
        sep  #$30      ; back to 8-bit
        plx            ; restore x
        plp
        bra  tail
        <<<

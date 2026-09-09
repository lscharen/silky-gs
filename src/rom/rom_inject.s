; This is a file that is meant to be included into a NES ROM code anywhere
; between the mapped RAM end address ($7FF) and the start of ROM code ($8000).
;
; Because we are emulating the NES memory in an actual 65816 RAM bank, there is
; actual RAM in the range $800 - $7FFF which we utilize to support the runtime.
; External wrapper is responsible for setting the stack

; These are external labels that implement the PPU function found in ppu/ppu.s
PPUCTRL_WRITE         EXT
PPUMASK_WRITE         EXT
PPUSTATUS_READ        EXT
PPUSTATUS_READ_X      EXT
OAMADDR_WRITE         EXT
PPUSCROLL_WRITE       EXT
PPUADDR_WRITE         EXT
PPUDATA_READ          EXT
PPUDATA_WRITE         EXT
PPUDMA_WRITE          EXT

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
            stal  mmc1_shft    ; "reset" == set the detection bit in bit 4
            pla
            plp
            rts
shft
            and   #$01         ; isolate the bottom bit
            beq   zero
            lda   #$20         ; inject bit
            oral  mmc1_shft
            stal  mmc1_shft

zero
            ldal  mmc1_shft    ; serial shift
            lsr
            stal  mmc1_shft
            bcs   done         ; is the shift register full?

            pla                ; no, return
            plp
            rts

done
            <<<

MMC1_RTN    mac
            lda   #$10         ; reset the shift register automatically (as documented)
            stal  mmc1_shft

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
            stal  mapper_bank       ; This is the IIgs memory bank, not the NES data bank

; Trampoline to pass control to the other bank.  This rom_inject file must be replicated in
; every bank at the same address so that a long jump into the new mapper_bank will still
; hit the same code.

            stal  :patch+3          ; needs to actually write to the executing bank (K), not the NES data bank.
:patch      jml   :done

:done
            MMC1_RTN

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


STA_4001    jsl  APU_PULSE1_REG2_WRITE
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

STY_4002    phy
            pha
            tya
            jsl  APU_PULSE1_REG3_WRITE
            pla
            ply
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

STA_4010
STA_4011
STA_4012
STA_4013
STX_4010
STX_4011
STX_4012
STX_4013
STY_4010
STY_4011
STY_4012
STY_4013
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
            lda #0          ; no input
            rts

; Hooks to call back to the harness for PPU memory-mapped accesses
STA_2000
            jsl  PPUCTRL_WRITE
            rts
STX_2000
            php
            phx
            pha
            txa
            jsl  PPUCTRL_WRITE
            pla
            plx
            plp
            rts


STA_2001
            jsl  PPUMASK_WRITE
            rts
STX_2001
            php
            phx
            pha
            txa
            jsl  PPUMASK_WRITE
            pla
            plx
            plp
            rts



LDA_2002
            jsl  PPUSTATUS_READ
            rts
LDX_2002
            pha                   ; space
            php
            pha                   ; save
            jsl  PPUSTATUS_READ
            sta  3,s
            pla
            plp
            plx
            rts

STA_2003
            jsl  OAMADDR_WRITE
            rts
STA_2005
            jsl  PPUSCROLL_WRITE
            rts
STA_2006
            jsl  PPUADDR_WRITE
            rts
STY_2006
            php
            phy
            pha
            tya
            jsl  PPUADDR_WRITE
            pla
            ply
            plp
            rts
STX_2006
            php
            phx
            pha
            txa
            jsl  PPUADDR_WRITE
            pla
            plx
            plp
            rts

LDA_2007
            jsl  PPUDATA_READ
            rts
STA_2007
            jsl  PPUDATA_WRITE
            rts
STX_2007
            php
            phx
            pha
            txa
            jsl  PPUDATA_WRITE
            pla
            plx
            plp
            rts
STA_4014
            jsl  PPUDMA_WRITE
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
            pha
            pla
            rts
            <<<

ADC_LONG_Y  mac
            pha
            phx
            tyx
            ldal ]1,x
            stal aly_patch+1
            plx
            pla
aly_patch   adc  #0
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
            pha
            pla
            rts
            <<<

LDX_LONG_Y  mac
            pha
            tyx
            ldal ]1,x
            tax
            pla
            phx
            plx
            rts
            <<<

LDY_LONG_X  mac
            pha
            ldal ]1,x
            tay
            pla
            phy
            ply
            rts
            <<<

LDX_LONG    mac
            pha
            ldal ]1
            tax
            pla
            phx
            plx
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
            pha
            pla              ; required reload to make sure Z,N flags are set correctly.
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
;            php
            pha
            phx
            tyx
            lda  ]1,x
            stal oay_patch+1
            plx
            pla
;            plp
oay_patch   ora  #0
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
;            php
            pha                ; make sure none of these instructions disturbs the carry flag
            phx
            tyx
            lda  ]1,x
            stal say_patch+1
            plx
            pla
;            plp
say_patch   sbc  #0
            rts
            <<<

ADC_ABS_Y   mac
;            php
            pha                ; make sure none of these instructions disturbs the carry flag
            phx
            tyx
            lda  ]1,x
            stal aay_patch+1
            plx
            pla
;            plp
aay_patch   adc  #0
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
            pha
            pla
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
        php            ; preserve caller's flags (esp. carry) across our internal cmps -- a
                       ; plain LDA (dp),Y never touches C, so callers may depend on it surviving
        lda ]1+1       ; load the high address byte
        bmi hi        ; HB >= $80 means we are in the upper half of memory, $8000 - $FFFF
        cmp #$02       ; zero page AND the NES stack page ($0000-$01FF) are a special case
        bcc zpage
        cmp #$20       ; is it below the I.O space? If so, then the bank register is fine
        bcc ok
        cmp #$60       ; is it in the WRAM space? Is so, then the bank register is fine
        bcc tail       ; if it's between $2000 and $5FFF, just ignore it for now and return the high byte which is like a floating bus read

ok      lda  (]1),y   ; it's ok to just execute the instruction as-is
tail    plp            ; restore caller's carry (and other flags)
        pha            ; refresh N/Z to match the loaded byte in A (plp above may have
        pla            ; clobbered them with the caller's pre-call flags)
        rts

hi      cmp #$C0
        bcs ok        ; $C0-$FF: fixed ROM bank -- ok as-is

        phb            ; $80-$BF: switchable ROM window
        phk
        plb
        lda  (]1),y
        plb            ; this affects flags, but tail's plp/pha/pla below fixes them up
        bra  tail

zpage
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
        bra  tail
        <<<

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

; These function are expected to be called in 8-bit mode from the ROM code
            mx    %11

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

STY_4003    phy
            pha
            tya
            jsl  APU_PULSE1_REG4_WRITE
            pla
            ply
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

STY_4004    phy
            pha
            tya
            jsl  APU_PULSE2_REG1_WRITE
            pla
            ply
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

STY_4008    phy
            pha
            tya
            jsl  APU_TRIANGLE_REG1_WRITE
            pla
            ply
            rts

STA_400A
STA_400a    jsl  APU_TRIANGLE_REG3_WRITE
            rts

STA_400B
STA_400b    jsl  APU_TRIANGLE_REG4_WRITE
            rts

STY_400B
STY_400b    phy
            pha
            tya
            jsl  APU_TRIANGLE_REG4_WRITE
            pla
            ply
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
STA_4016
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
            pha
            pha
            jsl  PPUSTATUS_READ
            sta  2,s
            pla
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

LDA_ABS_Y   mac
            php
            phx
            tyx
            lda  ]1,x
            sta  lay_patch+1
            plx
            plp
lay_patch   lda  #0
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

CMP_ABS_Y   mac
            php
            pha
            phx
            tyx
            lda  ]1,x
            stal cay_patch+1
            plx
            pla
            plp
cay_patch   cmp  #0
            rts
            <<<

SBC_ABS_Y   mac
            php
            pha                ; make sure none of these instructions disturbs the carry flag
            phx
            tyx
            lda  ]1,x
            sta  say_patch+1
            plx
            pla
            plp
say_patch   sbc  #0
            rts
            <<<

ADC_ABS_Y   mac
            php
            pha                ; make sure none of these instructions disturbs the carry flag
            phx
            tyx
            lda  ]1,x
            sta  aay_patch+1
            plx
            pla
            plp
aay_patch   adc  #0
            rts
            <<<

JMP_ABS_IND mac
            php
            pha
            lda  ]1
            sta  jai_patch+1
            lda  ]1+1
            sta  jai_patch+2
            pla
            plp
jai_patch   jmp  $0000
            <<<


; Enter via a JML. X = target address, Stack and Direct page set up properly. B = ROM bank. Called in 16-bit native mode
            mx    %00

ExtRtn      EXT
ExtIn       ENT
            txa
            stal :patch+1
            sep  #$30
:patch      jsr  $0000
            rep  #$30
            jml  ExtRtn

            mx   %11
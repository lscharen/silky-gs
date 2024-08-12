;.segment "BANK_FF"
;.include "copy_bank_ram.inc"
;.include "copy_bank_val.inc"
;.org $C000  ; for listing file
; 0x000010-0x00400F

        use  bank_ram.inc
        use  bank_val.inc
ROMBase ENT
        ds   $BD00
        put  ../../rom/rom_inject.s

STA_ram_00A4_obj_s1_Y STA_ABS_Y {ram_00A4_obj-1}
STA_ram_0080_obj_a1_Y STA_ABS_Y {ram_0080_obj+1}
STA_ram_0098_obj_Y STA_ABS_Y ram_0098_obj
STA_ram_0002_Y STA_ABS_Y ram_0002

LDA_ram_0084_obj_Y LDA_ABS_Y ram_0084_obj
LDA_ram_0070_obj_Y LDA_ABS_Y ram_0070_obj
LDA_ram_0080_obj_Y LDA_ABS_Y ram_0080_obj
LDA_ram_0088_obj_Y LDA_ABS_Y ram_0088
LDA_ram_008C_obj_Y LDA_ABS_Y ram_008C
LDA_ram_0098_obj_Y LDA_ABS_Y ram_0098_obj
LDA_ram_00B0_obj_Y LDA_ABS_Y ram_00B0_obj
LDA_ram_00A8_obj_Y LDA_ABS_Y ram_00A8_obj

CMP_ram_0070_obj_Y CMP_ABS_Y ram_0070_obj
CMP_ram_0080_obj_Y CMP_ABS_Y ram_0080_obj
CMP_ram_008C_obj_Y CMP_ABS_Y ram_008C

SBC_ram_008C_Y SBC_ABS_Y ram_008C

JMP_IND_00 JMP_ABS_IND $00

IIgs_memclear
        phx
        ldx #0
        lda #0
:loop
        sta 0,x
        inx
        bne :loop
        plx
        rts

        ds   \,$00

tbl_C000
  dw ofs_000_C346_00
  dw ofs_000_C395_01
  dw ofs_000_C99A_02
  dw ofs_000_CB2C_03
  dw ofs_000_C465_04
  dw ofs_000_C99A_05
  dw ofs_000_CB2C_06
  dw ofs_000_C465_07
  dw ofs_000_C3BD_08
  dw ofs_000_C97C_09
  dw ofs_000_C99A_0A
  dw ofs_000_CB2C_0B
  dw ofs_000_C43D_0C
  dw ofs_000_C41C_0D



tbl_C01C_index
; for 2 tables below
  db $00   ; 00 
  db $01   ; 01 
  db $02   ; 02 
  db $03   ; 03 
  db $04   ; 04 
  db $02   ; 05 
  db $03   ; 06 
  db $04   ; 07 
  db $06   ; 08 
  db $05   ; 09 
  db $02   ; 0A 
  db $03   ; 0B 
  db $07   ; 0C 
  db $08   ; 0D 



tbl_C02A_lo
  db < off_C03C_00   ; 
  db < off_C040_01   ; 
  db < off_C046_02   ; 
  db < off_C052_03   ; 
  db < off_C05C_04   ; 
  db < off_C064_05   ; 
  db < off_C070_06   ; 
  db < off_C07A_07   ; 
  db < off_C076_08   ; 



tbl_C033_hi
  db > off_C03C_00   ; 
  db > off_C040_01   ; 
  db > off_C046_02   ; 
  db > off_C052_03   ; 
  db > off_C05C_04   ; 
  db > off_C064_05   ; 
  db > off_C070_06   ; 
  db > off_C07A_07   ; 
  db > off_C076_08   ; 



off_C03C_00
  dw ofs_001_C2BD_00_01
  dw ofs_001_C514_00_02



off_C040_01
  dw ofs_001_C55E_01_01
  dw ofs_001_C3F3_01_02
  dw ofs_001_C514_01_03



off_C046_02
  dw ofs_001_C551_02_01
  dw ofs_001_C869_02_02
  dw ofs_001_C820_02_03
  dw ofs_001_C5A3_02_04
  dw ofs_001_C566_02_05
  dw ofs_001_C875_02_06



off_C052_03
  dw ofs_001_C55E_03_01
  dw ofs_001_C56A_03_02
  dw ofs_001_C455_03_03
  dw ofs_001_C5A7_03_04
  dw ofs_001_C485_03_05



off_C05C_04
  dw ofs_001_C55E_04_01
  dw ofs_001_C571_04_02
  dw ofs_001_C5AC_04_03
  dw ofs_001_C514_04_04



off_C064_05
  dw ofs_001_C551_05_01
  dw ofs_001_C869_05_02
  dw ofs_001_C820_05_03
  dw ofs_001_C5A3_05_04
  dw ofs_001_C562_05_05
  dw ofs_001_C5C2_05_06



off_C070_06
  dw ofs_001_C55E_06_01
  dw ofs_001_C575_06_02
  dw ofs_001_C514_06_03



off_C076_08
  dw ofs_001_C582_08_01
  dw ofs_001_C518_08_02



off_C07A_07
  dw ofs_001_C869_07_01
  dw ofs_001_C586_07_02
  dw ofs_001_C518_07_03



tbl_C080_spr_Y
  db $80   ; 00 
  db $90   ; 01 
  db $A0   ; 02 



tbl_C083_spr_X
  db $48   ; 00 
  db $60   ; 01 
  db $78   ; 02 
  db $90   ; 03 
  db $A8   ; 04 



tbl_C088_spr_X
  db $50   ; 00 
  db $48   ; 01 
  db $4C   ; 02 



tbl_C08B_spr_Y
  db $30   ; 00 
  db $48   ; 01 
  db $78   ; 02 
  db $90   ; 03 
  db $A8   ; 04 
  db $C0   ; 05 



tbl_C091
;         +--------------- 
;         |    +---------- 
;         |    |    +----- 
;         |    |    |
  db $01, $10, $00   ; 00 
  db $01, $10, $00   ; 01 
  db $01, $10, $00   ; 02 
  db $01, $0C, $00   ; 03 
  db $01, $06, $00   ; 04 
  db $00, $01, $18   ; 05 
  db $00, $01, $16   ; 06 
  db $00, $01, $0A   ; 07 
  db $00, $01, $14   ; 08 
  db $00, $01, $06   ; 09 
  db $00   ; 0A 
; bzk bug? sharing 2 bytes with 0x0000C0



tbl_C0B0
  db $09   ; 00 
  db $0B   ; 01 
  db $0D   ; 02 
  db $0F   ; 03 



tbl_C0B4_default_position
; at the start of the race
  db $0E   ; 00 
  db $1A   ; 01 
  db $26   ; 02 
  db $32   ; 03 



tbl_C0B8
  db $38   ; 00 
  db $48   ; 01 
  db $58   ; 02 
  db $68   ; 03 



tbl_C0BC
  db $18   ; 00 
  db $3F   ; 01 
  db $28   ; 02 
  db $20   ; 03 
  db $28   ; 04 



tbl_C0C1
  db $38   ; 00 
  db $0C   ; 01 
  db $00   ; 02 
  db $3C   ; 03 
  db $1C   ; 04 
  db $C0   ; 05 
  db $7F   ; 06 



tbl_C0C8
  db $06   ; 00 
  db $02   ; 02 



tbl_C0CA
  db $0A   ; 00 
  db $0B   ; 02 



tbl_C0CC
  db $01   ; 00 
  db $B0   ; 02 



tbl_C0CE
tbl__C0CE_20   ; for BIT instruction
  db $20   ; 00 
  db $40   ; 01 
  db $7F   ; 02 



tbl_C0D1
  db $03   ; 00 
  db $03   ; 01 
  db $01   ; 02 



tbl_C0D4
  db $06   ; 00 
  db $04   ; 02 



tbl_C0D6
; 00 
  db $40   ; 
  db $58   ; 
; 02 
  db $48   ; 
  db $48   ; 



tbl_C0DA
  db $78   ; 00 
  db $70   ; 01 
  db $80   ; 02 
  db $B0   ; 03 



tbl_C0DE
  db $37   ; 00 
  db $3F   ; 01 
  db $3F   ; 02 
  db $47   ; 03 



tbl_C0E2
  db $B7   ; 00 
  db $B9   ; 01 
  db $B9   ; 02 



tbl_C0E5
  db $01   ; 00 
  db $01   ; 01 
  db $41   ; 02 



tbl_C0E8
  db $04   ; 00 
  db $0C   ; 01 
  db $14   ; 02 
  db $1C   ; 03 



tbl_C0EC
  ddb $21F2 ; 00 
  ddb $2343 ; 02 
  ddb $2232 ; 04 
  ddb $228C ; 06 
  ddb $24CF ; 08 



tbl_C0F6_lo
; see con_0045
  db < ram_0301   ;  00
  db < _off_000_D470_01   ; 
  db < _off_000_D64B_02   ; 
  db < _off_000_D6D4_03   ; 
  db < _off_000_D717_04   ; 
  db < _off_000_D84A_05   ; 
  db < _off_000_D63A_06   ; 
  db < _off_000_D59E_07   ; 
  db < _off_000_D5B4_08   ; 
  db < _off_000_D796_09   ; 
  db < _off_000_D5C8_0A   ; 
  db < _off_000_D5DE_0B   ; 
  db < _off_000_D5EF_0C   ; 
  db < _off_000_D605_0D   ; 
  db < _off_000_D524_0E   ; 
  db < _off_000_D7FA_0F   ; 
  db < _off_000_D623_10   ; 
  db < _off_000_D614_11   ; 
  db < _off_000_D3D6_12   ; 
  db < _off_000_D3E9_13   ; 
  db < _off_000_D3FC_14   ; 
  db < _off_000_D40F_15   ; 
  db < _off_000_D422_16   ; 
  db < _off_000_D435_17   ; 
  db < _off_000_D450_18   ; 
  db < _off_000_D631_19   ; 
  db < {ram_00A0_obj + $01}   ;  1A



tbl_C111_hi
; see con_0045
  db > ram_0301   ;  00
  db > _off_000_D470_01   ; 
  db > _off_000_D64B_02   ; 
  db > _off_000_D6D4_03   ; 
  db > _off_000_D717_04   ; 
  db > _off_000_D84A_05   ; 
  db > _off_000_D63A_06   ; 
  db > _off_000_D59E_07   ; 
  db > _off_000_D5B4_08   ; 
  db > _off_000_D796_09   ; 
  db > _off_000_D5C8_0A   ; 
  db > _off_000_D5DE_0B   ; 
  db > _off_000_D5EF_0C   ; 
  db > _off_000_D605_0D   ; 
  db > _off_000_D524_0E   ; 
  db > _off_000_D7FA_0F   ; 
  db > _off_000_D623_10   ; 
  db > _off_000_D614_11   ; 
  db > _off_000_D3D6_12   ; 
  db > _off_000_D3E9_13   ; 
  db > _off_000_D3FC_14   ; 
  db > _off_000_D40F_15   ; 
  db > _off_000_D422_16   ; 
  db > _off_000_D435_17   ; 
  db > _off_000_D450_18   ; 
  db > _off_000_D631_19   ; 
  db > {ram_00A0_obj + $01}   ;  1A



tbl_C12C_lo
  db < ofs_CB3B_00   ; 
  db < ofs_CB77_01   ; 
  db < ofs_CBA4_02   ; 
  db < ofs_CC6B_03   ; 



tbl_C130_hi
  db > ofs_CB3B_00   ; 
  db > ofs_CB77_01   ; 
  db > ofs_CBA4_02   ; 
  db > ofs_CC6B_03   ; 



tbl_C134
  db $00   ; close buffer
  db $FC, $FC, $FC, $79   ; tiles
  db $04   ; counter
  dw $2272 ; ppu address



tbl_C13C
  db $04   ; 
  ddb $216F ; ppu address
  db $01   ; counter
  db $00   ; tiles
  db $00   ; close buffer


; bzk garbage
  db $60   ; 
  db $9F   ; 
  db $00   ; 
  db $17   ; 
  db $04   ; 



tbl_C147_spr_T
  db $DE   ; 00 
  db $DC   ; 01 
  db $E1   ; 02 
  db $F8   ; 03 
  db $FC   ; 04 
  db $EF   ; 05 
  db $E1   ; 06 
  db $EE   ; 07 
  db $C9   ; 08 



tbl_C150_spr_data
  db $44, $C9, $00, $84   ; 
  db $44, $F9, $00, $74   ; 



tbl_C158
  db $07   ; 
  ddb $2378 ; ppu address
  db $04   ; counter
  db $1D, $F8, $FE, $FE   ; tiles



tbl_C160
  db $29   ; 
  db $01   ; 
  db $02   ; 
  db $00   ; 
  db $02   ; 
  db $29   ; 



tbl_C166
  db $30   ; 
  db $35   ; 
  db $25   ; 
  db $35   ; 



tbl_C16A
  db $22   ; 
  db $26   ; 
  db $1C   ; 
  db $22   ; 
  db $22   ; 
  db $22   ; 



tbl_C170
  db $26   ; 
  db $06   ; 
  db $36   ; 
  db $26   ; 
  db $01   ; 
  db $40   ; 
  db $7F   ; 
  db $09   ; 



tbl_C178
  db $C7   ; 
  db $DB   ; 
  db $00   ; 
  db $E0   ; 
  db $C7   ; 
  db $DD   ; 
  db $00   ; 
  db $E8   ; 



tbl_C180
  db $17   ; 00 
  db $01   ; 01 
  db $00   ; 02 
  db $01   ; 03 



vec_C184_RESET
;  SEI
;  CLD
  LDA #$00
  JSR STA_2000
  LDX #$FF
;  TXS
  NOP
;bra_C18E_infinite_loop
;  JSR LDA_2002
;  AND #$80
;  BEQ bra_C18E_infinite_loop
;bra_C195_infinite_loop
;  JSR LDA_2002
;  AND #$80
;  BEQ bra_C195_infinite_loop
  bra :skip
  ds  7                       ; use the same amount of space
:skip
  jsr IIgs_memclear

  LDY #$07
  LDA ram_reset_check_1
  CMP #$A5
  BNE bra_C1AE
  LDA ram_reset_check_2
  CMP #$5A
  BNE bra_C1AE
  LDY #$04
bra_C1AE
  STY ram_0001
  LDY #$00
  STY ram_0000
  TYA
bra_C1B5_loop
  STA (ram_0000),Y
  DEY
  BNE bra_C1B5_loop
  DEC ram_0001
  BPL bra_C1B5_loop
  LDA ram_reset_check_1
  BNE bra_C1C6
  JSR sub_C1FD
bra_C1C6
  JSR STA_4011
  LDA #$06
  JSR STA_2001
  STA ram_0018
  JSR sub_C318
  LDA #$90
  JSR sub_C333
loc_C1D8_loop
bra_C1D8_loop
  jsl yield
  JSR sub_D326
  LDA ram_0048
  BMI bra_C1D8_loop
  BEQ bra_C1D8_loop
  JSR sub_C32F
  LDA ram_0048
  CMP #$01
  BNE bra_C1F7
  JSR sub_C6C8
loc_C1ED_loop
  LDA #$FF
  STA ram_0048
  JSR sub_C339
  JMP loc_C1D8_loop
bra_C1F7
  JSR sub_C739
  JMP loc_C1ED_loop



sub_C1FD
  LDX #$1E
bra_C1FF_loop
  LDA tbl_C091,X
  STA ram_0580,X
  STA ram_05A3,X
  DEX
  BPL bra_C1FF_loop
  LDX #$01
  STX ram_06E0
bra_C210_loop
  LDA #$40
  STA ram_06E0,X
  INX
  CPX #$CF
  BCC bra_C210_loop
  LDA #$09
  STA ram_06E0,X
  LDA #$A5
  STA ram_reset_check_1
  LDA #$5A
  STA ram_reset_check_2
sub_C229
  LDX #$00
  LDA #$0A
bra_C22D_loop
  STA ram_05A0,X
  STA ram_05C3,X
  LDA #$00
  INX
  CPX #$03
  BCC bra_C22D_loop
  RTS



vec_C23B_NMI
  JSR sub_C32F
  LDA ram_0045
  BNE bra_C24B
  LDA ram_for_2001
  ORA #$1A
  JSR STA_2001
  STA ram_for_2001
bra_C24B
  LDA #< ram_oam
  JSR STA_2003
  LDA #> ram_oam
  JSR STA_4014
  JSR sub_C27F ; set scroll to 0,0
  LDA ram_0047 ; title screen or playfield
  BEQ bra_C262
  JSR sub_D0AB ; delay loop?
  JSR sub_D14E ; wait for sprite0 and set scroll
bra_C262
  LDA ram_pause_flag
  ORA ram_pause_timer
  BNE bra_C26F
  INC ram_003F
  JSR sub_D310_decrease_all_timers
bra_C26F
  JSR sub_D347_read_joy_regs
  JSR sub_F844 ; channel 1
  JSR sub_C2A9 ; channel 2
  JSR LDA_2002 ; channel 3
  JSR sub_C339 ; channel 4
;  RTI
  RTS



sub_C27F
; see con_0045
  LDX ram_0045
  LDA tbl_C0F6_lo,X
  STA ram_0000
  LDA tbl_C111_hi,X
loc_C289
  STA ram_0001
  JSR sub_D3C1   ; sets scroll to 0,0
  LDA #$00
  STA ram_0300
  STA ram_0301
  STA ram_0045
  LDA #> $3F00
  JSR STA_2006
  LDA #< $3F00
  JSR STA_2006
; A = 00
  JSR STA_2006
  JSR STA_2006
  RTS



sub_C2A9
  LDX ram_0040
  BEQ bra_C2ED
  LDA ram_0041
  ASL
  TAY
  LDA tbl_C000,Y
  STA ram_0000
  INY
  LDA tbl_C000,Y
  JMP loc_CB36_indirect_jump



ofs_001_C2BD_00_01
  LDA #$04
  STA ram_03F8
  LSR ; con_0045_02
  STA ram_0045
  LDY #$00
  JSR sub_C409
  LDX ram_03F0
  BNE bra_C2D3
  LDA #$01
  STA ram_00FB
bra_C2D3
  CPX #$02
  BMI bra_C2D9
  LDX #$FF
bra_C2D9
  INX
  STX ram_03F0
  LDA #$38
  STA ram_0031_timer
  LDA #$0F
  JSR STA_4015
  LDA tbl_C080_spr_Y
  STA ram_spr_Y
bra_C2EC_RTS
  RTS



bra_C2ED
  JSR sub_D24F_disable_rendering
  LDA ram_0030_timer
  BNE bra_C2EC_RTS
  LDX ram_0041
  LDA tbl_C01C_index,X
  TAX
  LDA tbl_C02A_lo,X
  STA ram_0002
  LDA tbl_C033_hi,X
  STA ram_0003
  LDY ram_0044
  INC ram_0044
  DEY
  BMI bra_C318
  TYA
  ASL
  TAY
  LDA (ram_0002),Y
  STA ram_0000
  INY
  LDA (ram_0002),Y
  JMP loc_CB36_indirect_jump
bra_C318
sub_C318
  JSR sub_D255_hide_all_sprites
  JSR sub_D23B
  JSR sub_D1A9
  STA ram_scroll_X
  STA ram_0050_scroll_X
  STA ram_scroll_Y
  STA ram_0051_scroll_Y
  STA ram_00FC
  LDA #$10
  BNE bra_C333    ; jmp



sub_C32F
  LDA ram_for_2000
  AND #$7F
bra_C333
sub_C333
  JSR STA_2000
  STA ram_for_2000
  RTS



sub_C339
bra_C339_infinite_loop
  JSR LDA_2002
  AND #$80
;  BNE bra_C339_infinite_loop
  NOP
  NOP
  LDA ram_for_2000
  ORA #$80
  BNE bra_C333    ; jmp



ofs_000_C346_00
  LDA ram_0031_timer
  BNE bra_C359
  STA ram_0043
  STA ram_004A
  LDA #$0F
  STA ram_03F7
  LDA #$02
  STA ram_0041
  BNE bra_C389    ; jmp
bra_C359
  LDA #$03
  JSR sub_C7DE
  TXA
  BNE bra_C36A
  STA ram_03F2
  LDA tbl_C080_spr_Y,Y
  JMP loc_C3EF
bra_C36A
loc_C36A
  LDY ram_0042
  LDX #$00
  STX ram_03F7
  STX ram_0043
  STX ram_0042
  INX
  STX ram_03F3
  STX ram_004A
  STX ram_03F0
  CPY #$02
  BNE bra_C384
  LDX #$08
bra_C384
  STX ram_0041
  STY ram_03F2
bra_C389
  JSR sub_C3B1
  LDA ram_03F7
  EOR #$0F
  JSR STA_4015
  RTS



ofs_000_C395_01
  LDA ram_btn_press
  AND #con_btns_ABSS + con_btns_LR
  STA ram_btn_press
  AND #con_btns_LR    ; bzk optimize, seems useless
  ASL
  ASL
  ORA ram_btn_press
  STA ram_btn_press
  LDA #$05
  JSR sub_C7DE
  TXA
  BEQ bra_C3B8
  LDA ram_0042
  STA ram_0043
loc_C3AF
sub_C3AF
  INC ram_0041
bra_C3B1
sub_C3B1
  LDA #$00
  STA ram_0040
  STA ram_0044
  RTS
bra_C3B8
  LDA tbl_C083_spr_X,Y
  BNE bra_C411    ; jmp



ofs_000_C3BD_08
  LDA #$06
  JSR sub_C7DE
  TXA
  BEQ bra_C3EA
  LDA ram_0042
  CMP #$02
  BEQ bra_C3D2
  BCS bra_C3D5
  STA ram_03F2
  INC ram_0041
bra_C3D2
  JMP loc_C3AF
bra_C3D5
  CMP #$05
  BEQ bra_C3E4
  CLC
  ADC #$09
  STA ram_0041
  LDA #$00
  STA ram_0042
  BEQ bra_C3B1    ; jmp
bra_C3E4
  LSR
  STA ram_0042
  JMP loc_CA85
bra_C3EA
  LDY ram_0042
  LDA tbl_C08B_spr_Y,Y
bra_C3EF
loc_C3EF
  STA ram_spr_Y
  RTS



ofs_001_C3F3_01_02
  LDX #$04
  STX ram_00FB
  DEX ; con_0045_03
  STX ram_0045
  LDY #$01
  JSR sub_C409
  STA ram_0042
  LDA #$2D
  STA ram_0034_timer
  LDA #$B0
  BNE bra_C3EF    ; jmp



sub_C409
; in
;    ; Y = table index (00-02)
  LDA #$FA
  STA ram_spr_T
  LDA tbl_C088_spr_X,Y
bra_C411
  STA ram_spr_X
  LDA #$00
  STA ram_spr_A
  STA ram_0046_flag
  RTS



ofs_000_C41C_0D
  LDA #$02
  LDX ram_0044
  BEQ bra_C450
  LDA ram_0048
  CMP #$FF
  BNE bra_C454_RTS
  LDX #$02
bra_C42A_loop
  LDA ram_0064 + $01,X
  STA ram_05A0,X
  LDA ram_0068,X
  STA ram_05C3,X
  DEX
  BPL bra_C42A_loop
  JSR sub_EC3B
  JMP loc_C447



ofs_000_C43D_0C
  LDA ram_0044
  BEQ bra_C44E
  LDA ram_0048
  CMP #$FF
  BNE bra_C454_RTS
loc_C447
  LDA #$40
  STA ram_00FB
  JMP loc_CC6B
bra_C44E
  LDA #$01
bra_C450
  STA ram_0048
  STA ram_0044
bra_C454_RTS
  RTS



ofs_001_C455_03_03
  LDY #con_0045_08
  LDA ram_0041
  CMP #$08
  BCS bra_C462
  LDA ram_0046_flag
  BEQ bra_C464_RTS
  DEY ; con_0045_07
bra_C462
  STY ram_0045
bra_C464_RTS
  RTS



ofs_000_C465_04
ofs_000_C465_07
  LDA ram_0034_timer
  BEQ bra_C477
  LDA #$06
  JSR sub_C92C
  LDA ram_003F
  AND #$10
  BNE bra_C464_RTS
  JMP loc_CAFA
bra_C477
  JSR sub_C3AF
  LDA ram_0041
  CMP #$08
  BCC bra_C482
  LDA #$02
bra_C482
  STA ram_0041
  RTS



ofs_001_C485_03_05
  JSR sub_C53A
  LDA ram_0005
  CMP ram_0068
  BNE bra_C49A
  LDA ram_0006
  CMP ram_0069
  BNE bra_C49A
  LDA ram_0007
  CMP ram_006A
  BEQ bra_C4A9
bra_C49A
  BCC bra_C4AD
  LDX #$00
bra_C49E_loop
  LDA ram_0068,X
  STA ram_0580,Y
  INX
  INY
  CPX #$03
  BMI bra_C49E_loop
bra_C4A9
  LDA #$01
  BNE bra_C512    ; jmp
bra_C4AD
  LDA ram_0041
  CMP #$08
  BCS bra_C4CC
  JSR sub_C522
  LDA ram_0005
  CMP ram_0068
  BNE bra_C4C6
  LDA ram_0006
  CMP ram_0069
  BNE bra_C4C6
  LDA ram_0007
  CMP ram_006A
bra_C4C6
  BCC bra_C4CC
  LDA #$02
  BNE bra_C512    ; jmp
bra_C4CC
  LDA ram_03F8
  STA ram_000A
  ASL
  STA ram_0009
  LDA ram_0068
  SEC
  SBC ram_0005
  TAY
  LDA #$00
bra_C4DC_loop
  DEY
  BMI bra_C4E8
  CLC
  ADC #$3C
  BCC bra_C4DC_loop
bra_C4E4
; breakpoint triggers here if time up
  LDA #$FF
  BNE bra_C50B    ; jmp
bra_C4E8
  STA ram_0008
  LDA ram_0069
  SEC
  SBC ram_0006
  BCS bra_C4F7
  CLC
  ADC ram_0008
  JMP loc_C4FC
bra_C4F7
  CLC
  ADC ram_0008
  BCS bra_C4E4
loc_C4FC
  CMP ram_0009
  BCS bra_C50B
  CLC
  ADC ram_0009
loc_C503_loop
  LSR ram_000A
  BEQ bra_C512
  LSR
  JMP loc_C503_loop
bra_C50B
  SEC
  SBC ram_0009
  LSR
  CLC
  ADC #$04
bra_C512
  STA ram_0053
ofs_001_C514_00_02
ofs_001_C514_01_03
ofs_001_C514_04_04
ofs_001_C514_06_03
  LDA #con_0045_18
  STA ram_0045
ofs_001_C518_07_03
ofs_001_C518_08_02
  LDA #$01
  STA ram_0049
  STA ram_0040
  LSR ; 00
  STA ram_0044
  RTS



sub_C522
  LDA ram_0043
  STA ram_0002
  JSR sub_CB13
  TAY
  LDA tbl_C091,Y
  STA ram_0005
  LDA tbl_C091 + $01,Y
  STA ram_0006
  LDA tbl_C091 + $02,Y
  STA ram_0007
  RTS



sub_C53A
  LDA ram_0043
  STA ram_0002
sub_C53E
  JSR sub_CB06
  LDA ram_0580,Y
  STA ram_0005
  LDA ram_0581,Y
  STA ram_0006
  LDA ram_0582,Y
  STA ram_0007
  RTS



ofs_001_C551_02_01
ofs_001_C551_05_01
  LDA #con_0045_12
  LDX ram_0041
  CPX #$08
  BCS bra_C56E
; bzk optimize, C = 0, no need for CLC
  CLC
  ADC ram_0043
; con_0045_12
; con_0045_13
; con_0045_14
; con_0045_15
; con_0045_16
  BNE bra_C56E    ; jmp



ofs_001_C55E_01_01
ofs_001_C55E_03_01
ofs_001_C55E_04_01
ofs_001_C55E_06_01
  LDA #con_0045_06
  BNE bra_C56E    ; jmp



ofs_001_C562_05_05
  LDA #con_0045_05
  BNE bra_C56E    ; jmp



ofs_001_C566_02_05
  LDA #con_0045_0E
  BNE bra_C56E    ; jmp



ofs_001_C56A_03_02
  LDA #$04    ; con_0045_04
  STA ram_0033_timer
bra_C56E
  STA ram_0045
  RTS



ofs_001_C571_04_02
  LDA #con_0045_09
  BNE bra_C56E    ; jmp



ofs_001_C575_06_02
  LDA #$05
  STA ram_0043
  LDY #$02
  JSR sub_C409
  LDA #con_0045_0F
  BNE bra_C56E    ; jmp



ofs_001_C582_08_01
  LDA #con_0045_11
  BNE bra_C56E    ; jmp



ofs_001_C586_07_02
  LDX #$03
  BNE bra_C594    ; jmp



bra_C58A_loop
  LDA ram_05A0,X
  STA ram_0064 + $01,X
  LDA ram_05C3,X
  STA ram_0068,X
bra_C594
  LDA tbl_C180,X
  STA ram_0060 + $01,X
  DEX
  BPL bra_C58A_loop
  JSR sub_C621
  LDA #con_0045_10
  BNE bra_C56E    ; jmp



ofs_001_C5A3_02_04
ofs_001_C5A3_05_04
  LDA #con_0045_17
  BNE bra_C56E    ; jmp



ofs_001_C5A7_03_04
  LDA #$00
  JMP loc_C92C



ofs_001_C5AC_04_03
  LDA #$12
  STA ram_0034_timer
  LDX #$05
bra_C5B2_loop
  LDA tbl_C13C,X
  STA ram_0300,X
  DEX
  BPL bra_C5B2_loop
  LDX ram_0043
  INX
  STX ram_0304
  RTS



ofs_001_C5C2_05_06
  LDX #$01
  STX ram_00B4_obj + $03
  JSR sub_C621
  STX ram_00BC_obj + $01
  STX ram_00BC_obj + $02
  STX ram_00C4_obj
  STX ram_00C0_obj
  STX ram_0049
  STX ram_00C0_obj + $02
  INX
  STX ram_05E0
  LDA #$06
  STA ram_00AC_obj
  LDA #$A0
  STA ram_008C
  LDA #$10
  STA ram_0080_obj
  LDA #$04
  STA ram_0004
  LDX #$00
  STX ram_000B
  JSR sub_E1A3
  LDX #$07
bra_C5F2_loop
  LDA tbl_C178,X
  STA ram_oam + $28,X
  DEX
  BPL bra_C5F2_loop
  LDA #$05
  STA ram_00B0_obj + $01
  STA ram_00B0_obj + $02
  LDA #$21
  STA ram_00B0_obj
  LDA #$03
  STA ram_00B0_obj + $03
  LDA #$08
  STA ram_0064
  STA ram_00E0_obj
  INC ram_00E0_obj
  LDA #$7A
  STA ram_00B4_obj
  INC ram_0040
  INC ram_0047
  LDA #$D0
  JSR sub_EC25
  JMP loc_EC47



sub_C621
  LDX #$00
bra_C623_loop
  LDA ram_06E0,X
  STA ram_05E0,X
  DEX
  BNE bra_C623_loop
  RTS



sub_C62D
  LDA #$05
  JSR STA_4016
; bzk optimize, useless (probably) code up to C637
  PHA
  PLA
  PHA
  PLA
  PHA
  PLA
  RTS



sub_C639
bra_C639_loop
  JSR sub_C62D
  JSR LDA_4016
  AND #$02
  BEQ bra_C639_loop
bra_C643_loop
  JSR sub_C62D
  JSR LDA_4016
  AND #$02
  BNE bra_C643_loop
  RTS



sub_C64E
  PHA
  LDA #$34
  BNE bra_C656    ; jmp



sub_C653
loc_C653
  PHA
  LDA #$6A
bra_C656
  STA ram_0007
  STA ram_000C
  LDA #$04
  JSR STA_4016
bra_C65F_loop
  DEC ram_0007
  BNE bra_C65F_loop
  LDA #$FF
  JSR STA_4016
bra_C668_loop
  DEC ram_000C
  BNE bra_C668_loop
  PLA
  RTS



sub_C66E
  JSR sub_C653
  LDX #$08
bra_C673_loop
  STA ram_0000
  CLC
  ADC ram_0000
  BCS bra_C681
  JSR sub_C64E
loc_C67D
  DEX
  BNE bra_C673_loop
  RTS
bra_C681
  JSR sub_C653
  JSR sub_C68A
  JMP loc_C67D



sub_C68A
  INC ram_0008
  BNE bra_C690_RTS
  INC ram_0009
bra_C690_RTS
  RTS



sub_C691
  JSR sub_C639
  LDA #$4E
  STA ram_0001
bra_C698_garbage_loop
  DEC ram_0001
  BNE bra_C698_garbage_loop
  JSR sub_C62D
  JSR LDA_4016
  AND #$02
  RTS



sub_C6A5
  LDA #$08
  STA ram_0003
  LDA #$00
  STA ram_0004
bra_C6AD_loop
  LDA ram_0004
  CLC
  ADC ram_0004
  STA ram_0004
  JSR sub_C691
  BNE bra_C6BE
  JSR sub_C68A
  INC ram_0004
bra_C6BE
  DEC ram_0003
  BNE bra_C6AD_loop
  JSR sub_C639
  LDA ram_0004
  RTS



sub_C6C8
  JSR sub_C716
  JSR sub_C6D1
  JSR sub_C726
sub_C6D1
  LDA #$20
  STA ram_000A
  LDA #$4E
  STA ram_000B
bra_C6D9_loop
  JSR sub_C64E
  DEC ram_000A
  BNE bra_C6D9_loop
  DEC ram_000B
  BNE bra_C6D9_loop
bra_C6E4_loop
  JSR sub_C653
  DEC ram_0005
  BNE bra_C6E4_loop
bra_C6EB_loop
  JSR sub_C64E
  DEC ram_0006
  BNE bra_C6EB_loop
  JSR sub_C653
  LDA #$00
  STA ram_0008
  STA ram_0009
  LDY #$00
bra_C6FD_loop
  LDA (ram_000E),Y
  JSR sub_C66E
  INY
  CPY ram_000D
  BNE bra_C6FD_loop
  LDA ram_0009
  PHA
  LDA ram_0008
  JSR sub_C66E
  PLA
  JSR sub_C66E
  JMP loc_C653



sub_C716
  LDA #$40
  STA ram_000D
  LDA #$60
  STA ram_000E
  LDA #$00
  STA ram_000F
  LDA #$28
  BNE bra_C734    ; jmp



sub_C726
  LDA #$00
  STA ram_000D
  LDA #$E0
  STA ram_000E
  LDA #$05
  STA ram_000F
  LDA #$14
bra_C734
  STA ram_0005
  STA ram_0006
  RTS



sub_C739
bra_C739_loop
  JSR sub_C32F
  JSR sub_C716
  JSR sub_C792
  BCC bra_C751
bra_C744_loop
  LDA #con_0045_19
  STA ram_0045
bra_C748
  JSR sub_C339
bra_C74B_loop
  LDA ram_0045
  BNE bra_C74B_loop
  BEQ bra_C739_loop    ; jmp
bra_C751
  LDX #$00
  STX ram_00A8_obj
  LDY #$01
bra_C757_loop
  LDA (ram_000E),Y
;  STA ram_00A4_obj - $01,Y
  JSR STA_ram_00A4_obj_s1_Y
  CMP tbl_C180 - $01,Y
  BEQ bra_C762
  INX
bra_C762
  INY
  CPY #$05
  BNE bra_C757_loop
  LDA #$07
  STA ram_00A0_obj
  LDA #$22
  STA ram_00A0_obj + $01
  LDA #$4F
  STA ram_00A0_obj + $02
  LDA #$04
  STA ram_00A0_obj + $03
  LDA #con_0045_1A
  STA ram_0045
  CPX #$00
  BNE bra_C748
  JSR sub_C339
bra_C782_infinite_loop
  LDA ram_0045
  BNE bra_C782_infinite_loop
  JSR sub_C32F
  JSR sub_C726
  JSR sub_C792
  BCS bra_C744_loop
  RTS



sub_C792
bra_C792_loop
  LDA ram_0005
  STA ram_0000
bra_C796_loop
  JSR sub_C691
  BNE bra_C792_loop
  DEC ram_0000
  BNE bra_C796_loop
  LDA ram_0006
  STA ram_0000
bra_C7A3_loop
  JSR sub_C691
  BEQ bra_C792_loop
  DEC ram_0000
  BNE bra_C7A3_loop
  LDA #$00
  STA ram_0008
  STA ram_0009
  JSR sub_C639
  JSR sub_C639
  LDY #$00
bra_C7BA_loop
  JSR sub_C6A5
  STA (ram_000E),Y
  INY
  CPY ram_000D
  BNE bra_C7BA_loop
  LDA ram_0008
  STA ram_000A
  LDA ram_0009
  STA ram_000B
  JSR sub_C6A5
  CMP ram_000A
  BNE bra_C7DA
  JSR sub_C6A5
  CMP ram_000B
  BEQ bra_C7DC
bra_C7DA
  SEC
  RTS
bra_C7DC
  CLC
  RTS



sub_C7DE
  STA ram_0000
  LDY ram_0042
  LDX #$00
  LDA ram_btn_press
  AND #con_btns_SS + con_btns_UD
  BNE bra_C7ED
  STA ram_0049
bra_C7EC_RTS
  RTS
bra_C7ED
  LDA #$5D
  STA ram_0031_timer
  LDA ram_0049
  BNE bra_C7EC_RTS
  LDA ram_btn_press
; con_btn_Select
  BIT tbl__C0CE_20
  BNE bra_C80A
  LSR
  LSR
  LSR
  BCS bra_C80A
  LSR
  BCS bra_C811
  LDX #$04
  STX ram_0030_timer
  BNE bra_C81B    ; jmp
bra_C80A
  INY
  CPY ram_0000
  BCC bra_C817
  LDY #$01
bra_C811
  DEY
  BPL bra_C817
  LDY ram_0000
  DEY
bra_C817
  LDA #$01
  STA ram_00FF
bra_C81B
  STY ram_0042
  INC ram_0049
  RTS



ofs_001_C820_02_03
ofs_001_C820_05_03
  JSR sub_D13F
  LDA #$03
  STA ram_0001
  LSR ; con_0045_01
  STA ram_0045
  LSR ; 00
  STA ram_0000
  STA ram_004B
  LDY #$EF
bra_C831_loop
; clear 0340-03EF
  STA (ram_0000),Y
  DEY
  CPY #$40
  BCS bra_C831_loop
  LDX #$7F
bra_C83A_loop
  LDA #$3B
  STA ram_0400,X
  LDA #$3D
  STA ram_0480,X
  STA ram_0500,X
  DEX
  BPL bra_C83A_loop
  LDA #$BF
  STA ram_spr_Y
  LDA #$F7
  STA ram_spr_X
  LDA #$FF
  STA ram_spr_T
  LDA #$3F
  STA ram_00E8
  LSR ; 1F
  STA ram_00E9
  LDA #$0A
  STA ram_00EB
  LDA #$25
  STA ram_00EA
  RTS



ofs_001_C869_02_02
ofs_001_C869_07_01
ofs_001_C869_05_02
; clear 004D-00EF
; bzk optimize
  LDA #$00
  LDX #$EF
bra_C86D_loop
  STA ram_0000,X
  DEX
  CPX #$4C
  BNE bra_C86D_loop
  RTS



ofs_001_C875_02_06
  INC ram_0047
  INC ram_0040
  LDA ram_0034_timer
  BNE bra_C87F
  LDA #$05
bra_C87F
  STA ram_0034_timer
  LDA #$34
  STA ram_00E8
  LDA #$14
  STA ram_00E9
  LDA #$A0
  STA ram_03F1
  LDA #$80
  STA ram_03B4
  STA ram_03B0
  LDA #$FF
  STA ram_03BD
  LDX #$01
  STX ram_0370_obj
  INX ; 02
  STX ram_03BE
  INX ; 03
  LDA ram_03F2
  BNE bra_C8AC
  LDX #$00
bra_C8AC
bra_C8AC_loop
  LDA tbl_C0B4_default_position,X
  STA ram_obj_pos_Y_lo,X
  LDA #$08
  STA ram_0064,X
  LDA tbl_C0B0,X
  STA ram_00E0_obj,X
  LDA tbl_C0B8,X
  STA ram_0080_obj,X
  LDA #$06
  STA ram_00AC_obj,X
  STA ram_0078,X
  LDA #$01
  STA ram_0084_obj,X
  STA ram_00A8_obj,X
  LDA ram_0019,X
  LSR
  STA ram_0074,X
  DEX
  BPL bra_C8AC_loop
  LDA ram_0019,X
  AND #$03
  BNE bra_C8DB
  LDA #$02
bra_C8DB
  TAX
  LSR ram_0078,X
  LDA ram_0046_flag
  BEQ bra_C902
  LDA ram_0043
  CMP #$04
  BNE bra_C902
  LDX #$07
bra_C8EA_loop
  LDA tbl_C158,X
  STA ram_0300,X
  DEX
  BPL bra_C8EA_loop
  LDA ram_03F3
  JSR sub_DFA2
  STA ram_0307
  TXA
  BEQ bra_C902
  STA ram_0306
bra_C902
  JSR sub_C522
  LDA ram_0041
  CMP #$08
  BCC bra_C90E
  JSR sub_C53A
bra_C90E
  LDA ram_03F8
  ASL
  CLC
  ADC ram_0006
  CMP #$3C
  BCC bra_C91D
  SBC #$3C
  INC ram_0005
bra_C91D
  STA ram_0006
  LDA #$00
  STA ram_0007
  LDA #$02
  STA ram_0003
  JSR sub_C935
  LDA #$08
sub_C92C
loc_C92C
  LDY ram_0043
  STY ram_0002
  STA ram_0003
  JSR sub_C53E
sub_C935
  LDX #$05
  JSR sub_DF7F
  LDX ram_0300
  LDY #$00
bra_C93F_loop
  LDA ram_03D1,Y
  STA ram_0304,X
  INX
  INY
  CPY #$07
  BCC bra_C93F_loop
sub_C94B
  LDA #$0A
  JSR sub_C971
  LDY ram_0003
  LDA tbl_C0EC,Y
  STA ram_0301,X
  LDA tbl_C0EC + $01,Y
  STA ram_0302,X
  LDA #$FB
  STA ram_0305,X
  STA ram_0308,X
  LDA #$07
  STA ram_0303,X
  LDA #$00
  STA ram_030B,X
  RTS



sub_C971
  LDX ram_0300
  CLC
  ADC ram_0300
  STA ram_0300
  RTS



ofs_000_C97C_09
  JSR sub_CA1B
  JSR sub_EB17
  JSR sub_DA6A
  JSR sub_DBFE
  JSR sub_E70B
  JSR sub_F4FF
  JSR sub_F68D
  JSR sub_F755
  JSR sub_C229
bra_C997
  JMP loc_D19B



ofs_000_C99A_02
ofs_000_C99A_05
ofs_000_C99A_0A
  JSR sub_CA08
  LDA ram_pause_flag
  ORA ram_pause_timer
  BNE bra_C997
  JSR sub_D918
  JSR sub_DD8D
  JSR sub_E733
  JSR sub_E927
  LDA ram_0052_track_finished_flag
  BEQ bra_C9BB
  JSR sub_CA9B
  JMP loc_C9D5
bra_C9BB
  LDA ram_03F2
  BEQ bra_C9C9
  JSR sub_DA9F
  JSR sub_DBC4
  JSR sub_DEBB
bra_C9C9
  JSR sub_DF30
  JSR sub_EAC5
  JSR sub_DFD5
  JSR sub_E09F
loc_C9D5
  JSR sub_DDD1
  JSR sub_CD1F
  JSR sub_E96C
  JSR sub_DE31
  JSR sub_E836
  JSR sub_EA44
  JSR sub_F4FF

  JSR sub_E4C8 ; swap ?? 
  JSR sub_DEE2 ; from rom this is out of order?

  JSR sub_E359_display_temperature_meter_with_sprites
  JSR sub_E17F
  JSR sub_E456
  JSR sub_DA26
  JSR sub_E70B
  JSR sub_D19B

;  JSR sub_E4C8 ; move to here
;  JSR sub_DEE2 ; from rom this is out of order?

  JSR sub_CED0
  JMP loc_E42B



sub_CA08
  LDX #$03
bra_CA0A_loop
  JSR sub_DCA0
  JSR sub_DFB2
  DEX
  BPL bra_CA0A_loop
  LDA ram_03F7
  BNE bra_CA20
  JSR sub_CA38_pause_and_unpause
sub_CA1B
  LDA ram_btn_hold
  STA ram_005C_obj
  RTS
bra_CA20
  LDA ram_03F7
  BEQ bra_CA84_RTS
  LDA ram_btn_press
  ASL
  ASL
  ASL
  BCS bra_CA85
  ASL
  BCC bra_CA84_RTS
  LDA #$00
  STA ram_0042
  STA ram_0047
  JMP loc_C36A



sub_CA38_pause_and_unpause
  LDA ram_pause_timer
  BNE bra_CA63
  LDA ram_btn_press
  AND #con_btn_Start
  BEQ bra_CA67
  LDA ram_03B0
  BNE bra_CA67
  LDA #$80
  STA ram_00FB
  STA ram_03B0
  ASL
  STA ram_00FC
  LDA ram_pause_flag
  EOR #$01
  STA ram_pause_flag
  BNE bra_CA7F
  LDA #$0F
  JSR STA_4015
  BNE bra_CA7F    ; jmp
bra_CA63
  DEC ram_pause_timer
  RTS
bra_CA67
  STA ram_03B0
  LDA ram_pause_flag
  BEQ bra_CA84_RTS
  LDA #$00
  JSR STA_4015
  LDA ram_btn_press
  AND #con_btns_Dpad
  BEQ bra_CA84_RTS
  LDA ram_pause_timer
  BNE bra_CA84_RTS
bra_CA7F
  LDA #$28
  STA ram_pause_timer
bra_CA84_RTS
  RTS



bra_CA85
loc_CA85
  LDA ram_0042
  PHA
  LDX #$FF
  LDA #$00
bra_CA8C_loop
  STA ram_0000,X
  DEX
  CPX #$20
  BNE bra_CA8C_loop
  STA ram_00FC
  INC ram_0049
  PLA
  STA ram_0042
  RTS



sub_CA9B
  LDA ram_0032_timer
  BNE bra_CAAA
  JSR sub_C3AF
  LDA ram_03F7
  BNE bra_CA85
  STA ram_0047
bra_CAA9_RTS
  RTS
bra_CAAA
  LDA #$00
  STA ram_00FC
  STA ram_03A9
  STA ram_03E0_obj
  STA ram_003C_timer
  LDX ram_0052_track_finished_flag
  DEX
  BNE bra_CAA9_RTS
  LDA ram_003F
  LSR
  BCS bra_CAF3
  LSR
  BCS bra_CAF3
  AND #$03
  TAY
  LDA #$3F
  STA ram_0312
  LDA #$00
  STA ram_0313
  STA ram_0319
  LDA #$04
  STA ram_0314
  LDA tbl_C166,Y
  STA ram_0316
  LDA tbl_C170,Y
  STA ram_0318
  LDY ram_0043
  LDA tbl_C160,Y
  STA ram_0315
  LDA tbl_C16A,Y
  STA ram_0317
  RTS
bra_CAF3
  LDX #$11
  LDA ram_0032_timer
  LSR
  BCS bra_CB05_RTS
loc_CAFA
  LDY #$06
  LDA #$FE
bra_CAFE_loop
  STA ram_0304,X
  INX
  DEY
  BPL bra_CAFE_loop
bra_CB05_RTS
  RTS



sub_CB06
  JSR sub_CB13
  LDY ram_03F2
  BEQ bra_CB11
  CLC
  ADC #$23
bra_CB11
  TAY
  RTS



sub_CB13
  LDA #$20
  LDY ram_0002
  CPY #$05
  BEQ bra_CB2B_RTS
  LDA #$00
bra_CB1D_loop
  DEY
  BMI bra_CB25
  CLC
  ADC #$03
  BNE bra_CB1D_loop   ; jmp
bra_CB25
  LDY ram_0046_flag
  BEQ bra_CB2B_RTS
  ORA #$10
bra_CB2B_RTS
  RTS



ofs_000_CB2C_03
ofs_000_CB2C_06
ofs_000_CB2C_0B
  LDY ram_0044
  LDA tbl_C12C_lo,Y
  STA ram_0000
  LDA tbl_C130_hi,Y
loc_CB36_indirect_jump
  STA ram_0001
;  JMP (ram_0000)
  JMP JMP_IND_00



ofs_CB3B_00
  LDA ram_0041
  CMP #$08
  BCS bra_CB73
  LDA ram_03F2
  STA ram_0042
  LDA ram_0053
  CMP #$04
  BCS bra_CB73
  LDA ram_0046_flag
  BEQ bra_CB6D
  LDA ram_0043
  CMP #$04
  BNE bra_CB69
  INC ram_03F3
  LDA ram_03F3
  LSR
  BCS bra_CB6D
  LDA ram_03F8
  LSR
  BEQ bra_CB6D
  STA ram_03F8
  SEC
bra_CB69
  BCS bra_CB6D
  INC ram_0043
bra_CB6D
  LDA #$01
  STA ram_0046_flag
  STA ram_004B
bra_CB73
  LDA #$04
  BNE bra_CB9F    ; jmp



ofs_CB77_01
  LDY ram_0033_timer
  BNE bra_CBA3_RTS
  LDA #$04
  STA ram_0003
  LDX ram_0300
bra_CB82_loop
  LDA ram_03D9,Y
  STA ram_0304,X
  INX
  INY
  CPY #$07
  BNE bra_CB82_loop
  JSR sub_C94B
  LDA #$20
  LDX ram_004B
  BNE bra_CB99
  LDA #$31
bra_CB99
  STA ram_03AD
  CLC
  ADC #$03
bra_CB9F
  STA ram_0033_timer
  INC ram_0044
bra_CBA3_RTS
  RTS



ofs_CBA4_02
  LDA ram_0033_timer
; bzk optimize, branch to 0x000BB1
  BEQ bra_CB9F
  CMP ram_03AD
  BEQ bra_CBC9
  BCS bra_CBA3_RTS
  LDA ram_004B
  BNE bra_CBB9
  LDA ram_btn_hold
  AND #con_btns_ABSS
  BNE bra_CBBF
bra_CBB9
  JSR sub_CC15
  JMP loc_CC7D
bra_CBBF
  JSR sub_CC6B
  LDA ram_0041
  BNE bra_CBA3_RTS
  JMP loc_C3AF
bra_CBC9
  LDA ram_0020_0A_frm_timer
  BNE bra_CBA3_RTS
; if 10d frames passed
  LDX #$03
  STX ram_002F_timer
  STX ram_000D
  DEX
bra_CBD4_loop
  LDA tbl_C0DE,X
  STA ram_0001
  LDA tbl_C0E2,X
  STA ram_0002
  LDA tbl_C0E5,X
  STA ram_000B
  JSR sub_CCCA
  DEX
  BPL bra_CBD4_loop
  LDA #$01
  LDX ram_0053
  DEX
  STX ram_0000
  CPX #$03
  BCS bra_CBF8
  STX ram_000D
  LDA #$02
bra_CBF8
  STA ram_00FB
  EOR #$02
  STA ram_0056
  LDX ram_000D
  LDA tbl_C0DA,X
  STA ram_0054_useless
  LDA tbl_C0DE,X
  STA ram_0055
  STA ram_03F1
  LDA ram_0000
  BNE bra_CC6A_RTS
  LDA #con_0045_0A
  BNE bra_CC2F    ; jmp



sub_CC15
  LDA ram_03AD
  SEC
  SBC #$10
  CMP ram_0033_timer
  BNE bra_CC32
  LDA ram_0020_0A_frm_timer
  BNE bra_CC32
; if 10d frames passed
  LDA #con_0045_0D
  LDY ram_0052_track_finished_flag
  DEY
  BNE bra_CC2F
  LDA ram_004B
  CLC
; con_0045_0B
; con_0045_0C
  ADC #$0B
bra_CC2F
  STA ram_0045
  RTS
bra_CC32
  LDA #$07
  TAY
  JSR sub_C971
  STX ram_0005
bra_CC3A_loop
  LDA tbl_C134,Y
  STA ram_0301,X
  INX
  DEY
  BPL bra_CC3A_loop
  LDA ram_003F
  AND #$10
  BNE bra_CC6A_RTS
  LDY ram_0005
  LDA ram_0053
  JSR sub_DFA2
  STA ram_0307,Y
  TXA
  JSR sub_DFA2
  STA ram_0000
  TXA
  BNE bra_CC62
  LDA ram_0000
  BNE bra_CC65
  RTS
bra_CC62
; breakpoint triggers here if time up
  STA ram_0305,Y
bra_CC65
  LDA ram_0000
  STA ram_0306,Y
bra_CC6A_RTS
  RTS



loc_CC6B
sub_CC6B
ofs_CC6B_03
  JSR sub_C3AF
  LDA ram_004B
  BNE bra_CC7C_RTS
  LDY ram_0041
  CPY #$09
  BCC bra_CC7A
  LDA #$08
bra_CC7A
  STA ram_0041
bra_CC7C_RTS
  RTS



loc_CC7D
  LDA ram_0055
  STA ram_0001
  LDA ram_0056
  BNE bra_CCB9
  LDA ram_002F_timer
  BEQ bra_CCA3
  LDA #$1F
  STA ram_0380_obj
  STA ram_038C_obj
  LDA #$AF
  STA ram_0378_obj
  LDA #$01
  STA ram_037C_obj
  LSR ; 00
  STA ram_0384_obj
  LDY #$BD
  BNE bra_CCBB    ; jmp
bra_CCA3
  LDX #$00
  JSR sub_DD6F
  STA ram_0055
  STA ram_0001
  LDA ram_03F1
  CMP ram_0055
  BCS bra_CCB9
  STA ram_0055
  LDA #$0A
  STA ram_002F_timer
bra_CCB9
  LDY #$BB
bra_CCBB
  STY ram_0002
  LDX ram_0053
  DEX
  CPX #$03
  BCC bra_CCC6
  LDX #$03
bra_CCC6
  LDA #$02
  STA ram_000B
sub_CCCA
  LDA tbl_C0DA,X
  STA ram_0000
  LDA #$21
  STA ram_0003
  LDA tbl_C0E8,X
  STA ram_0004
  LDA #$00
  JMP loc_D1C7



loc_CCDD
  LDA ram_003C_timer
  LSR
  BCC bra_CD12_RTS
  LDA #$40
  STA ram_00FB
  LDA #$58
  STA ram_0000
  LDX #$08
bra_CCEC_loop
  TXA
  ASL
  ASL
  TAY
  LDA #$44
  STA ram_spr_Y + $C0,Y
  LDA tbl_C147_spr_T,X
  STA ram_spr_T + $C0,Y
  LDA #$00
  STA ram_spr_A + $C0,Y
  LDA ram_0000
  STA ram_spr_X + $C0,Y
  CLC
  ADC #$0A
  STA ram_0000
  DEX
  BPL bra_CCEC_loop
  LDA #$F8
  STA ram_spr_Y + $D0
bra_CD12_RTS
  RTS



loc_CD13
  LDX #$07
bra_CD15_loop
  LDA tbl_C150_spr_data,X
  STA ram_oam + $C0,X
  DEX
  BPL bra_CD15_loop
  RTS



sub_CD1F
  LDA ram_004F_race_started_flag
  BEQ bra_CD40
  LDX #$03
bra_CD25_loop
  LDA ram_00A8_obj,X
  BEQ bra_CD3D
  LDA ram_009C_obj,X
  CMP #$05
  BEQ bra_CD3A
  ORA ram_0098_obj,X
  ORA ram_03E0_obj,X
  BEQ bra_CD3A
  LDA #$00
  STA ram_005C_obj,X
bra_CD3A
  JSR sub_CD59
bra_CD3D
  DEX
  BPL bra_CD25_loop
bra_CD40
  LDA ram_0034_timer
  BNE bra_CD58_RTS
  LDA ram_005C_obj
  AND #$C0
  BEQ bra_CD58_RTS
  LDA ram_03A9
  ORA ram_0052_track_finished_flag
  BNE bra_CD58_RTS
  LDA #$01
  STA ram_03A9
  STA ram_00FE_flag
bra_CD58_RTS
  RTS



sub_CD59
  LDA ram_005C_obj,X
  AND #$03
  STA ram_000A
  LDY #$00
  LDA ram_0374_obj,X
  ORA ram_0098_obj,X
  BNE bra_CDBA
  LDA ram_009C_obj,X
  BEQ bra_CD70
  CMP #$05
  BNE bra_CDBA
bra_CD70
  TXA
  BNE bra_CD7B
  LDY #$02
  LDA ram_0052_track_finished_flag
  BNE bra_CD9A
  LDY #$00
bra_CD7B
  LDA ram_00B0_obj,X
  BNE bra_CDB2
  LDA ram_005C_obj,X
  AND #$C0
  BEQ bra_CDBA
  STX ram_0000
  ASL
  BCS bra_CD8C
  INC ram_0000
bra_CD8C
  JSR sub_CDEE
  BEQ bra_CD95
  LDA ram_0094_obj,X
  BNE bra_CDBA
bra_CD95
  LDY ram_0000
  TXA
  BNE bra_CDAC
bra_CD9A
  LDA ram_0094_obj,X
  CMP tbl_C0D1,Y
  BCC bra_CDAC
  BNE bra_CDB9
  LDA ram_0090_obj,X
  CMP tbl_C0CE,Y
  BEQ bra_CDBD
  BCS bra_CDB9
bra_CDAC
  JSR sub_CE29
  JMP loc_CDBD
bra_CDB2
  LDY #$04
  LDA ram_000A
  BEQ bra_CDBA
  TAY
bra_CDB9
  INY
bra_CDBA
  JSR sub_CE58
bra_CDBD
loc_CDBD
  LDA ram_0098_obj,X
  BNE bra_CE1C_RTS
  LDA ram_00B0_obj,X
  BNE bra_CDD5
  LDA ram_0058_obj,X
  ORA ram_0052_track_finished_flag
  BNE bra_CDDE
  LDA ram_0094_obj,X
  BNE bra_CDD5
  LDA ram_0090_obj,X
  CMP #$A0
  BCC bra_CDDE
bra_CDD5
  LDA ram_000A
  BEQ bra_CDDE
  STA ram_0000
  JMP loc_CE83
bra_CDDE
  LDA ram_00B0_obj,X
  BNE bra_CE1C_RTS
  LDA ram_0368_obj,X
  CMP ram_00AC_obj,X
  BEQ bra_CE1C_RTS
  LDY #$05
  JMP loc_DCC7



sub_CDEE
  LDA ram_00C0_obj,X
  CMP #$E4
  BEQ bra_CE0A
  LDA #$03
  CMP ram_00A4_obj,X
  BNE bra_CE00
  LDA ram_0070_obj,X
  CMP #$03
  BCS bra_CE0A
bra_CE00
  LDA ram_obj_pos_Y_lo,X
  CMP #$38
  BCS bra_CE0A
  CMP #$08
  BCS bra_CE1D
bra_CE0A
  LDA #$01
  CMP ram_036C_obj,X
  BEQ bra_CE15
  ASL
  STA ram_036C_obj,X
bra_CE15
  TXA
  BNE bra_CE28_RTS
  LDA #$04
  STA ram_00FD
bra_CE1C_RTS
  RTS
bra_CE1D
  LDA #$01
  CMP ram_036C_obj,X
  BEQ bra_CE28_RTS
  LSR ; 00
  STA ram_036C_obj,X
bra_CE28_RTS
  RTS



sub_CE29
  CPX ram_004C
  BNE bra_CE45_RTS
  LDA tbl_C0BC,Y
  CLC
  ADC ram_0090_obj,X
  STA ram_0090_obj,X
  BCC bra_CE39
  INC ram_0094_obj,X
bra_CE39
  TXA
  BNE bra_CE45_RTS
  LDA ram_0094_obj,X
  CMP tbl_C0D1,Y
  BEQ bra_CE46
  BCS bra_CE4D
bra_CE45_RTS
  RTS
bra_CE46
  LDA ram_0090_obj,X
  CMP tbl_C0CE,Y
  BCC bra_CE45_RTS
bra_CE4D
  LDA tbl_C0CE,Y
  STA ram_0090_obj,X
  LDA tbl_C0D1,Y
  STA ram_0094_obj,X
  RTS



sub_CE58
  CPX ram_004C
  BNE bra_CE82_RTS
sub_CE5C
  STY ram_0000
  LDA ram_0094_obj,X
  BNE bra_CE6D
  LDA ram_00B0_obj,X
  LSR
  TAY
  LDA ram_0090_obj,X
  CMP tbl_C0CC,Y
  BCC bra_CE82_RTS
bra_CE6D
  LDY ram_0000
  LDA ram_0090_obj,X
  SEC
  SBC tbl_C0C1,Y
  STA ram_0090_obj,X
  BCS bra_CE82_RTS
  LDA ram_0094_obj,X
  BEQ bra_CE80
  DEC ram_0094_obj,X
  RTS
bra_CE80
  STA ram_0090_obj,X
bra_CE82_RTS
  RTS



loc_CE83
  LDA ram_0026_timer,X
  BNE bra_CE9F_RTS
  LDA ram_00B0_obj,X
  LSR
  TAY
  LDA tbl_C0D4,Y
  STA ram_0026_timer,X
  LSR ram_0000
  BCC bra_CEA0
  LDA ram_00AC_obj,X
  CMP tbl_C0C8,Y
  BEQ bra_CE9F_RTS
  BCC bra_CEAF
  DEC ram_00AC_obj,X
bra_CE9F_RTS
  RTS
bra_CEA0
  LDA ram_0388_obj,X
  AND #$02
  STA ram_0388_obj,X
  LDA ram_00AC_obj,X
  CMP tbl_C0CA,Y
  BCS bra_CEB2
bra_CEAF
  INC ram_00AC_obj,X
  RTS
bra_CEB2
  LDA ram_005C_obj,X
  AND #$C0
  BEQ bra_CECF_RTS
  LDA ram_00B0_obj,X
  BNE bra_CECF_RTS
  INC ram_00AC_obj,X
  LDA #$0D
  STA ram_0026_timer,X
  LDA ram_00AC_obj,X
  CMP #$0D
  BCC bra_CECF_RTS
  LDA #$01
  STA ram_0098_obj,X
  ASL
  STA ram_0026_timer,X
bra_CECF_RTS
  RTS



sub_CED0
  LDX ram_004A
bra_CED2_loop
  STX ram_000F
  LDA ram_00A8_obj,X
  BEQ bra_CF04
  LDA ram_0098_obj,X
  ORA ram_009C_obj,X
  BNE bra_CF04
  JSR sub_CFEA
  LDA ram_00B0_obj,X
  BNE bra_CEFF
  JSR sub_CFCB
  JSR sub_D018
  BNE bra_CF04
  LDA ram_03A6_flag
  BEQ bra_CF04
  JSR sub_D000
  LDA ram_0052_track_finished_flag
  BNE bra_CF04
  JSR sub_CF0C
  JMP loc_CF04
bra_CEFF
  LDA ram_0368_obj,X
  STA ram_007C_obj,X
bra_CF04
loc_CF04
  LDX ram_000F
  INX
  CPX #$04
  BCC bra_CED2_loop
bra_CF0B_RTS
  RTS



sub_CF0C
  LDA ram_0084_obj,X
  LSR
  BCC bra_CF0B_RTS
  LDA ram_0070_obj,X
  STA ram_0002
  LDY #$02
  JSR sub_CF96
  BCC bra_CF2B
  JSR sub_CFDB
  LDA ram_0080_obj,X
  ASL
  BCC bra_CF0B_RTS
  LDA ram_0018,X
  LSR
  BCS bra_CF64
  BCC bra_CF47_loop    ; jmp
bra_CF2B
  LDA ram_00DC_obj,X
  BNE bra_CF87_RTS
  LDA ram_0084_obj,X
  LSR
  BCC bra_CF87_RTS
  LDA ram_0080_obj,X
  CMP #$F0
  BCS bra_CF87_RTS
  ASL
  BCC bra_CF87_RTS
  LDA ram_0019,X
  CMP #$E0
  BCC bra_CF87_RTS
  CMP #$F8
  BCC bra_CF64
bra_CF47_loop
sub_CF47
  LDY ram_0360_obj,X
  DEY
  CPY #$01
  BMI bra_CF6A
  JSR sub_CF88
  BCS bra_CF87_RTS
  LDY ram_0070_obj,X
  INY
  STY ram_0002
  LDY #$00
  JSR sub_CF96
  BCS bra_CF87_RTS
  LDA #$01
  BNE bra_CF85    ; jmp
bra_CF64
  LDA ram_00C0_obj,X
  CMP #$E6
  BEQ bra_CF47_loop
bra_CF6A
sub_CF6A
  LDY ram_0360_obj,X
  INY
  CPY #$05
  BPL bra_CF47_loop
  JSR sub_CF88
  BCS bra_CF87_RTS
  LDY ram_0070_obj,X
  DEY
  STY ram_0002
  LDY #$00
  JSR sub_CF96
  BCS bra_CF87_RTS
  LDA #$FF
bra_CF85
  STA ram_00DC_obj,X
bra_CF87_RTS
  RTS



sub_CF88
  JSR sub_E7FF
sub_CF8B
  CMP #$3B
  BCC bra_CF94
  CMP #$3E
  BCS bra_CF94
  RTS
bra_CF94
  SEC
  RTS



sub_CF96
  LDA ram_0080_obj,X
  CLC
  ADC tbl_C0D6,Y
  STA ram_0000
  SEC
  SBC tbl_C0D6 + $01,Y
  STA ram_0001
  LDY ram_004A
bra_CFA6_loop
  CPY ram_000F
  BEQ bra_CFC4
;  LDA ram_0084_obj,Y
  JSR LDA_ram_0084_obj_Y
  LSR
  BCC bra_CFC4
;  LDA ram_0070_obj,Y
  JSR LDA_ram_0070_obj_Y
  BEQ bra_CFC4
  CMP ram_0002
  BNE bra_CFC4
;  LDA ram_0080_obj,Y
  JSR LDA_ram_0080_obj_Y
  CMP ram_0000
  BCS bra_CFC4
  CMP ram_0001
  BCS bra_CFCA_RTS
bra_CFC4
  INY
  CPY #$04
  BCC bra_CFA6_loop
  CLC
bra_CFCA_RTS
  RTS



sub_CFCB
  LDY #$80
  LDA ram_0094_obj,X
  CMP ram_0078,X
  BCC bra_CFFA
  BNE bra_CFDB
  LDA ram_0090_obj,X
  CMP ram_0074,X
  BCC bra_CFFA
bra_CFDB
sub_CFDB
  LDA ram_0094_obj,X
  BEQ bra_CFE9_RTS
  LDA #$0F
  BNE bra_CFE5    ; jmp



sub_CFE3
  LDA #$F0
bra_CFE5
  AND ram_005C_obj,X
  STA ram_005C_obj,X
bra_CFE9_RTS
  RTS



sub_CFEA
  JSR sub_CFE3
  LDY #$01
  LDA ram_007C_obj,X
  BEQ bra_CFFF_RTS
  CMP ram_00AC_obj,X
  BEQ bra_CFFF_RTS
  BCC bra_CFFA
  INY
bra_CFFA
  TYA
  ORA ram_005C_obj,X
  STA ram_005C_obj,X
bra_CFFF_RTS
  RTS



sub_D000
  LDY #$00
  CPX #$03
  BEQ bra_D015
  LDA ram_0080_obj,X
  AND #$10
  BEQ bra_CFFF_RTS
  LDA ram_001A,X
  CMP #$C0
  BCC bra_CFFF_RTS
  BNE bra_D015
  INY
bra_D015
  JMP loc_DB50



sub_D018
  LDA #$00
  STA ram_0009
  STA ram_000D
  TXA
  ASL
  ASL
  STA ram_000A
  LDY #$03
bra_D025_loop
  STY ram_000B
  LDY ram_000A
  LDA ram_03C0,Y
  CMP #$C0
  BEQ bra_D058
  CMP #$C1
  BEQ bra_D058
  CMP #$70
  BCC bra_D03C
  CMP #$74
  BCC bra_D058
bra_D03C
  CMP #$48
  BCC bra_D044
  CMP #$4B
  BCC bra_D0A4
bra_D044
  INC ram_000A
  LDY ram_000B
  DEY
  BPL bra_D025_loop
bra_D04B
loc_D04B
  LDY #$00
  LDA ram_0058_obj,X
  BNE bra_D054
  LDY ram_0368_obj,X
bra_D054
  TYA
  JMP loc_D0A6
bra_D058
  INC ram_000D
  LDA ram_000A
  AND #$03
  TAY
  INY
  TYA
  CLC
  ADC ram_00E0_obj,X
  AND #$3F
  STA ram_0008
  LDA #$40
  STA ram_0009
  LDY ram_0360_obj,X
bra_D06F_loop
  DEY
  CPY #$01
  BMI bra_D088
  JSR sub_E803
  LDY ram_0007
  CMP #$FA
  BEQ bra_D088
  JSR sub_CF8B
  BCS bra_D06F_loop
  JSR sub_CF47
  JMP loc_D04B
bra_D088
  LDY ram_0360_obj,X
bra_D08B_loop
  INY
  CPY #$06
  BPL bra_D04B
  JSR sub_E803
  LDY ram_0007
  CMP #$E4
  BEQ bra_D04B
  JSR sub_CF8B
  BCS bra_D08B_loop
  JSR sub_CF6A
  JMP loc_D04B
bra_D0A4
  LDA #$09
loc_D0A6
  STA ram_007C_obj,X
  LDA ram_000D
  RTS



sub_D0AB
  LDX #$03
bra_D0AD_loop
  LDY #$05
  LDA ram_obj_pos_Y_lo,X
  SEC
  SBC #$10
  BMI bra_D0BE
bra_D0B6_loop
  DEY
  BEQ bra_D0BE
  SEC
  SBC #$08
  BPL bra_D0B6_loop
bra_D0BE
  TYA
  STA ram_0360_obj,X
  DEX
  BPL bra_D0AD_loop
  RTS



sub_D0C6
  LDX #$03
bra_D0C8_loop
  TXA
  ASL
  ASL
  STA ram_000C
  LDA #$04
  STA ram_000B
  JSR sub_E7FC
  STA ram_00C0_obj,X
  JMP loc_D0DD
bra_D0D9_loop
  LDY ram_0008
  LDA (ram_0003),Y
loc_D0DD
  PHA
  INY
  TYA
  AND #$3F
  STA ram_0008
  LDY ram_000C
  PLA
  STA ram_03C0,Y
  INC ram_000C
  DEC ram_000B
  BNE bra_D0D9_loop
  DEX
  BPL bra_D0C8_loop
  RTS



sub_D0F4
  LDX #$06
bra_D0F6_loop
  LDA ram_03D9,X
  STA ram_03D1,X
  DEX
  BPL bra_D0F6_loop
  LDA #$56
  STA ram_0000
  LDA #$23
  STA ram_0001
  LDA #$17
  STA ram_03D0
  LDA #$D0
  STA ram_0002
  LDA #$03
  STA ram_0003
  LDA #$FB
  STA ram_03D2
  STA ram_03D5
  JMP loc_D2A3



sub_D11F
  LDA #$11
  STA ram_0300
  LDA #$23
  STA ram_0301
  LDA #$A0
  STA ram_0302
  LDX #$0E
  STX ram_0303
  LDA #$FE
bra_D135_loop
  STA ram_0303,X
  DEX
  BNE bra_D135_loop
; X = 00
  STX ram_0312
  RTS



sub_D13F
  LDX #$00
  JSR sub_ECE4
  LDX #$04
  JSR sub_ECE4
  LDX #$08
  JMP loc_ECE4



sub_D14E
bra_D14E_infinite_loop
  JSR LDA_2002
  AND #$40
;  BNE bra_D14E_infinite_loop
  NOP
  NOP
  JSR sub_D1B3 ; set scroll here
  LDA ram_003F
  AND #$03
  STA ram_004C
  JSR sub_D11F
  LDX #$43
  LDA ram_0041
  CMP #$09
  BEQ bra_D17E
  LDA #$F8
  LDY #$EC
bra_D16D_loop
  STA ram_spr_Y,Y
  DEY
  DEY
  DEY
  DEY
  BNE bra_D16D_loop
  JSR sub_D0C6
  JSR sub_D0F4
  LDX #$28
bra_D17E
bra_D17E_garbage_loop
  LDY #$12
bra_D180_garbage_loop
  DEY
  BNE bra_D180_garbage_loop
  DEX
  BNE bra_D17E_garbage_loop
  LDA ram_for_2000
  ORA ram_004D_base_nametable
  JSR STA_2000
  JSR LDA_2002
  LDA ram_scroll_X
  JSR STA_2005
  LDA ram_scroll_Y
bra_D197
loc_D197
  JSR STA_2005
  RTS



loc_D19B
sub_D19B
bra_D19B_infinite_loop
  JSR LDA_2002                     ; IIgs - Skip Sprite 0 hit detection
  AND #$40
;  BEQ bra_D19B_infinite_loop
  nop
  nop

  LDA ram_for_2000
  AND #$F0
  JSR sub_C333
sub_D1A9
  JSR LDA_2002
  LDA #$00
  JSR STA_2005
  BEQ bra_D197    ; jmp



sub_D1B3
  LDA ram_for_2000
  ORA ram_004E_base_nametable
  JSR STA_2000
  JSR LDA_2002
  LDA ram_0050_scroll_X
  JSR STA_2005
  LDA ram_0051_scroll_Y
  JMP loc_D197



loc_D1C7
sub_D1C7
  STA ram_000A
  TXA
  PHA
  TYA
  PHA
  LDA #$02
  STA ram_0005
  LDA #$0F
  AND ram_0003
  STA ram_0007
  LDA ram_0003
  LSR
  LSR
  LSR
  LSR
  STA ram_0006
  TAX
  LDA #$00
  CLC
bra_D1E3_loop
  ADC ram_0007
  DEX
  BNE bra_D1E3_loop
  STA ram_0008
  LDA ram_0002
  LDY #$01
bra_D1EE_loop
  TXA
  LSR
  BCS bra_D1FC
  LSR ram_000A
  BCC bra_D1FC
  LDA #$FC
  STA (ram_0004),Y
  BNE bra_D202    ; jmp
bra_D1FC
  LDA ram_0002
  STA (ram_0004),Y
  INC ram_0002
bra_D202
  INY
  LDA ram_000B
  STA (ram_0004),Y
  INY
  INY
  INY
  INX
  CPX ram_0008
  BNE bra_D1EE_loop
  LDY #$00
bra_D211_loop
  LDX ram_0006
  LDA ram_0001
  STA ram_0009
bra_D217_loop
  LDA ram_0009
  STA (ram_0004),Y     ; This stores the player sprite into $200
  CLC
  ADC #$08
  STA ram_0009
  INY
  INY
  INY
  LDA ram_0000
  STA (ram_0004),Y
  INY
  DEX
  BNE bra_D217_loop
  LDA ram_0000
  CLC
  ADC #$08
  STA ram_0000
  DEC ram_0007
  BNE bra_D211_loop
  PLA
  TAY
  PLA
  TAX
  RTS



sub_D23B
  LDX #$01
bra_D23D_loop
  TXA
  PHA
  STA ram_0001
  JSR sub_D24F_disable_rendering
  JSR sub_D260
  PLA
  TAX
  INX
  CPX #$03
  BCC bra_D23D_loop
  RTS



sub_D24F_disable_rendering
  LDA #$00
  JSR STA_2001
  RTS



sub_D255_hide_all_sprites
  LDA #$F8
  LDY #$00
bra_D259_loop
  STA ram_oam,Y
  DEY
  BNE bra_D259_loop
  RTS



sub_D260
  JSR LDA_2002
  LDA ram_for_2000
  AND #$FB
  JSR sub_C333
  LDA #$1C
  CLC
bra_D26D_loop
  ADC #$04
  DEC ram_0001
  BNE bra_D26D_loop
  STA ram_0002
  JSR STA_2006
  LDA #$00
  JSR STA_2006
  LDX #$04
  LDY #$00
  LDA #$FC
bra_D283_loop
  JSR STA_2007
  DEY
  BNE bra_D283_loop
  DEX
  BNE bra_D283_loop
  LDA ram_0002
  ADC #$03
  JSR STA_2006
  LDA #$C0
  JSR STA_2006
  LDY #$40
  LDA #$00
bra_D29C_loop
  JSR STA_2007
  DEY
  BNE bra_D29C_loop
  RTS



loc_D2A3
  TXA
  PHA
  TYA
  PHA
  LDY #$00
  LDA (ram_0002),Y
  AND #$0F
  STA ram_0005
  LDA (ram_0002),Y
  LSR
  LSR
  LSR
  LSR
  STA ram_0004
  LDX ram_0300
bra_D2BA_loop
  LDA ram_0001
  STA ram_0301,X
  JSR sub_D2FF
  LDA ram_0000
  STA ram_0301,X
  JSR sub_D2FF
  LDA ram_0005
  STA ram_0006
  STA ram_0301,X
bra_D2D1_loop
  JSR sub_D2FF
  INY
  LDA (ram_0002),Y
  STA ram_0301,X
  DEC ram_0006
  BNE bra_D2D1_loop
  JSR sub_D2FF
  STX ram_0300
  CLC
  LDA #$20
  ADC ram_0000
  STA ram_0000
  LDA #$00
  ADC ram_0001
  STA ram_0001
  DEC ram_0004
  BNE bra_D2BA_loop
  LDA #$00
  STA ram_0301,X
  PLA
  TAY
  PLA
  TAX
  RTS



sub_D2FF
  INX
  TXA
  CMP #$3F
  BCC bra_D30F_RTS
  LDX ram_0300
  LDA #$00
  STA ram_0301,X
  PLA
  PLA
bra_D30F_RTS
  RTS



sub_D310_decrease_all_timers
  LDX #$0E    ; timers 0021-002F
  DEC ram_0020_0A_frm_timer
  BPL bra_D31C
; decrease other timers each 0A (10d) frames
  LDA #$0A
  STA ram_0020_0A_frm_timer
  LDX #$1C    ; timers 0021-003D
bra_D31C
bra_D31C_loop
  LDA ram_all_timers,X
  BEQ bra_D322
  DEC ram_all_timers,X
bra_D322
  DEX
  BPL bra_D31C_loop
  RTS



sub_D326
  LDA ram_0018
  AND #$02
  STA ram_0000
  LDA ram_0019
  AND #$02
  EOR ram_0000
  CLC
  BEQ bra_D336
  SEC
bra_D336
  ROR ram_0018
  ROR ram_0019
  ROR ram_001A
  ROR ram_001B
  ROR ram_001C
  ROR ram_001D
  ROR ram_001E
  ROR ram_001F
  RTS



sub_D347_read_joy_regs
  LDA #$01
  JSR STA_4016
  LDX #$00
  LDA #$00
  JSR STA_4016
  JSR sub_D35B
  INX
  JSR sub_D35B
  RTS


native_joy EXT
sub_D35B
;  LDY #$08
  LDY #$00
bra_D35D_loop
;  PHA
;  JSR LDA_4016_X
  ldal native_joy,x
  bra  :native_done

  STA ram_0000
  LSR
  ORA ram_0000
  LSR
  PLA
  ROL
  DEY
;  BNE bra_D35D_loop
:native_done

  STX ram_0000
  ASL ram_0000
  LDX ram_0000
  LDY ram_btn_hold,X
  STY ram_0000
  STA ram_btn_hold,X
  STA ram_btn_press,X
  AND #$FF
  BPL bra_D386_RTS
  BIT ram_0000
  BPL bra_D386_RTS
  AND #con_btn_A!$FF
  STA ram_btn_press,X
bra_D386_RTS
  RTS



bra_D387_loop
  JSR STA_2006
  INY
  LDA (ram_0000),Y
  JSR STA_2006
  INY
  LDA (ram_0000),Y
  ASL
  PHA
  LDA ram_for_2000
  ORA #$04
  BCS bra_D39D
  AND #$FB
bra_D39D
  JSR sub_C333
  PLA
  ASL
  BCC bra_D3A7
  ORA #$02
  INY
bra_D3A7
  LSR
  LSR
  TAX
bra_D3AA_loop
  BCS bra_D3AD
  INY
bra_D3AD
  LDA (ram_0000),Y
  JSR STA_2007
  DEX
  BNE bra_D3AA_loop
  SEC
  TYA
  ADC ram_0000
  STA ram_0000
  LDA #$00
  ADC ram_0001
  STA ram_0001
sub_D3C1
  JSR LDX_2002
  LDY #$00
  LDA (ram_0000),Y
  BNE bra_D387_loop
  JSR LDA_2002
  LDA #$00
  JSR STA_2005
  JSR STA_2005
  RTS



con_40                                  = $40 ; 
con_80                                  = $80 ; 
con_C0                                  = $C0 ; 



_off_000_D3D6_12
  ddb $3F00 ; ppu address
  db $08   ; counter
  db $29, $27, $22, $30   ; 
  db $29, $27, $18, $36   ; 

  ddb $3F10 ; ppu address
  db $04   ; counter
  db $29, $20, $16, $0F   ; 

  db $00   ; end token



_off_000_D3E9_13
  ddb $3F00 ; ppu address
  db $08   ; counter
  db $01, $1A, $26, $33   ; 
  db $01, $11, $0C, $2C   ; 

  ddb $3F10 ; ppu address
  db $04   ; counter
  db $01, $20, $16, $0F   ; 

  db $00   ; end token



_off_000_D3FC_14
  ddb $3F00 ; ppu address
  db $08   ; counter
  db $02, $26, $1C, $30   ; 
  db $02, $29, $19, $39   ; 

  ddb $3F10 ; ppu address
  db $04   ; counter
  db $02, $20, $16, $0F   ; 

  db $00   ; end token



_off_000_D40F_15
  ddb $3F00 ; ppu address
  db $08   ; counter
  db $00, $26, $22, $30   ; 
  db $00, $27, $18, $37   ; 

  ddb $3F10 ; ppu address
  db $04   ; counter
  db $00, $20, $16, $0F   ; 

  db $00   ; end token


_off_000_D422_16
  ddb $3F00 ; ppu address
  db $08   ; counter
  db $02, $19, $22, $30   ; 
  db $02, $00, $2D, $10   ; 

  ddb $3F10 ; ppu address
  db $04   ; counter
  db $02, $20, $16, $0F   ; 

  db $00   ; end token



_off_000_D435_17
  ddb $3F08 ; ppu address
  db $08   ; counter
  db $29, $22, $0F, $20   ; 
  db $29, $22, $0F, $16   ; 

  ddb $3F14 ; ppu address
  db $0C   ; counter
  db $29, $13, $20, $0F   ; 
  db $29, $31, $1C, $0F   ; 
  db $29, $20, $19, $0F   ; 

  db $00   ; end token



_off_000_D450_18
  ddb $3F00 ; ppu address
  db $1C   ; counter
  db $02, $0F, $30, $21   ; 
  db $02, $15, $02, $2A   ; 
  db $02, $3C, $02, $30   ; 
  db $02, $30, $02, $27   ; 

  db $02, $20, $16, $0F   ; 
  db $02, $27, $13, $3C   ; 
  db $02, $27, $16, $30   ; 

  db $00   ; end token



_off_000_D470_01
  ddb $23D0 ; ppu address
  db $20 + con_40   ; counter
  db $55   ; 

  ddb $23F0 ; ppu address
  db $10 + con_40   ; counter
  db $AA   ; 

  ddb $27D0 ; ppu address
  db $20 + con_40   ; counter
  db $55   ; 

  ddb $27F0 ; ppu address
  db $10 + con_40   ; counter
  db $AA   ; 

  ddb $2000 ; ppu address
  db $20 + con_40   ; counter
  db $3F   ; 

  ddb $2020 ; ppu address
  db $20 + con_40   ; counter
  db $3E   ; 

  ddb $2040 ; ppu address
  db $20 + con_40   ; counter
  db $3F   ; 

  ddb $2060 ; ppu address
  db $20 + con_40   ; counter
  db $3E   ; 

  ddb $2080 ; ppu address
  db $20 + con_40   ; counter
  db $3F   ; 

  ddb $2400 ; ppu address
  db $20 + con_40   ; counter
  db $3F   ; 

  ddb $2420 ; ppu address
  db $20 + con_40   ; counter
  db $3E   ; 

  ddb $2440 ; ppu address
  db $20 + con_40   ; counter
  db $3F   ; 

  ddb $2460 ; ppu address
  db $20 + con_40   ; counter
  db $3E   ; 

  ddb $2480 ; ppu address
  db $20 + con_40   ; counter
  db $3F   ; 

  ddb $20A0 ; ppu address
  db $20 + con_40   ; counter
  db $30   ; 

  ddb $20C0 ; ppu address
  db $20 + con_40   ; counter
  db $FE   ; 

  ddb $20E0 ; ppu address
  db $20 + con_40   ; counter
  db $FE   ; 

  ddb $24A0 ; ppu address
  db $20 + con_40   ; counter
  db $30   ; 

  ddb $24C0 ; ppu address
  db $20 + con_40   ; counter
  db $FE   ; 

  ddb $24E0 ; ppu address
  db $20 + con_40   ; counter
  db $FE   ; 

  ddb $20AB ; ppu address
  db $03 + con_80   ; counter
  db $31, $34, $37   ; 

  ddb $20B4 ; ppu address
  db $03 + con_80   ; counter
  db $33, $36, $39   ; 

  ddb $20AC ; ppu address
  db $08 + con_40   ; counter
  db $32   ; 

  ddb $20EC ; ppu address
  db $08 + con_40   ; counter
  db $38   ; 

  ddb $20CC ; ppu address
  db $08   ; counter
  db $17, $12, $17, $1D, $0E, $17, $0D, $18   ; 

  ddb $2200 ; ppu address
  db $20 + con_40   ; counter
  db $3B   ; 

  ddb $2220 ; ppu address
  db $20 + con_40   ; counter
  db $3C   ; 

  ddb $2240 ; ppu address
  db $20 + con_40   ; counter
  db $3D   ; 

  ddb $2260 ; ppu address
  db $20 + con_40   ; counter
  db $3B   ; 

  ddb $2280 ; ppu address
  db $20 + con_40   ; counter
  db $3C   ; 

  ddb $22A0 ; ppu address
  db $20 + con_40   ; counter
  db $3D   ; 

  ddb $2600 ; ppu address
  db $20 + con_40   ; counter
  db $3B   ; 

  ddb $2620 ; ppu address
  db $20 + con_40   ; counter
  db $3C   ; 

  ddb $2640 ; ppu address
  db $20 + con_40   ; counter
  db $3D   ; 

  ddb $2660 ; ppu address
  db $20 + con_40   ; counter
  db $3B   ; 

  ddb $2680 ; ppu address
  db $20 + con_40   ; counter
  db $3C   ; 

  ddb $26A0 ; ppu address
  db $20 + con_40   ; counter
  db $3D   ; 

  ddb $2300 ; ppu address
  db $3F + con_40   ; counter
  db $FE   ; 

  ddb $233F ; ppu address
  db $3F + con_40   ; counter
  db $FE   ; 

  ddb $237E ; ppu address
  db $3F + con_40   ; counter
  db $FE   ; 

  ddb $239D ; ppu address
  db $23 + con_40   ; counter
  db $FE   ; 

  ddb $2700 ; ppu address
  db $3F + con_40   ; counter
  db $FE   ; 

  db $00   ; end token



_off_000_D524_0E
  ddb $24AB ; ppu address
  db $0A + con_40   ; counter
  db $F2   ; 

  ddb $24AA ; ppu address
  db $01   ; counter
  db $96   ; 

  ddb $24B5 ; ppu address
  db $01   ; counter
  db $97   ; 

  ddb $24CB ; ppu address
  db $03   ; counter
  db $93, $94, $95   ; 

  ddb $23F1 ; ppu address
  db $06   ; counter
  db $AF, $AA, $AE, $AB, $AA, $AF   ; 

  ddb $2323 ; ppu address
  db $07   ; counter
  db $B7, $B7, $03, $1B, $0D, $B7, $B7   ; 

  ddb $2322 ; ppu address
  db $03 + con_80   ; counter
  db $B5, $B0, $B2   ; 

  ddb $232A ; ppu address
  db $03 + con_80   ; counter
  db $B6, $B1, $B4   ; 

  ddb $2363 ; ppu address
  db $07 + con_40   ; counter
  db $B3   ; 

  ddb $2336 ; ppu address
  db $07   ; counter
  db $B7, $B7, $1D, $12, $16, $0E, $B7   ; 

  ddb $2335 ; ppu address
  db $03 + con_80   ; counter
  db $B5, $B0, $B2   ; 

  ddb $233D ; ppu address
  db $03 + con_80   ; counter
  db $B6, $B1, $B4   ; 

  ddb $2376 ; ppu address
  db $07 + con_40   ; counter
  db $B3   ; 

  ddb $232C ; ppu address
  db $08   ; counter
  db $4C, $5A, $1D, $0E, $16, $19, $7A, $8B   ; 

  ddb $234B ; ppu address
  db $0A   ; counter
  db $4B, $4D, $5B, $FC, $FC, $FC, $FC, $7B, $4D, $8C   ; 

  ddb $236D ; ppu address
  db $06   ; counter
  db $5C, $6A, $6A, $6A, $6A, $7C   ; 

  ddb $238D ; ppu address
  db $06   ; counter
  db $5D, $6B, $6C, $6B, $6C, $8A   ; 

  db $00   ; end token



_off_000_D59E_07
  ddb $2089 ; ppu address
  db $0E + con_40   ; counter
  db $FC   ; 

  ddb $20A9 ; ppu address
  db $0E   ; counter
  db $FC, $FC, $0E, $21, $0C, $12, $1D, $0E, $0B, $12, $14, $0E, $FC, $FC   ; 

  db $00   ; end token



_off_000_D5B4_08
  ddb $2089 ; ppu address
  db $0E + con_40   ; counter
  db $FC   ; 

  ddb $20AA ; ppu address
  db $0C   ; counter
  db $0D, $0E, $1C, $12, $10, $17, $FC, $1D, $1B, $0A, $0C, $14   ; 

  db $00   ; end token



_off_000_D5C8_0A
  ddb $22E7 ; ppu address
  db $12   ; counter
  db $12, $1D, $F9, $1C, $FC, $0A, $FC, $17, $0E, $20, $FC, $1B, $0E, $0C, $18   ; 
  db $1B, $0D, $FA   ; 

  db $00   ; end token



_off_000_D5DE_0B
  ddb $22E5 ; ppu address
  db $16 + con_40   ; counter
  db $FC   ; 

  ddb $22EB ; ppu address
  db $09   ; counter
  db $10, $0A, $16, $0E, $FC, $18, $1F, $0E, $1B   ; 

  db $00   ; end token



_off_000_D5EF_0C
  ddb $22E7 ; ppu address
  db $12   ; counter
  db $1D, $1B, $22, $FC, $1D, $11, $0E, $FC, $17, $0E, $21, $1D, $FC, $1D, $1B   ; 
  db $0A, $0C, $14   ; 

  db $00   ; end token



_off_000_D605_0D
  ddb $22E5 ; ppu address
  db $16 + con_40   ; counter
  db $FC   ; 

  ddb $22EC ; ppu address
  db $07   ; counter
  db $1D, $12, $16, $0E, $FC, $1E, $19   ; 

  db $00   ; end token



_off_000_D614_11
  ddb $23E0 ; ppu address
  db $10 + con_40   ; counter
  db $FF   ; 

  ddb $220D ; ppu address
  db $07   ; counter
  db $15, $18, $0A, $0D, $12, $17, $10   ; 

  db $00   ; end token



_off_000_D623_10
  ddb $23E0 ; ppu address
  db $10 + con_40   ; counter
  db $FF   ; 

  ddb $220D ; ppu address
  db $06   ; counter
  db $1C, $0A, $1F, $12, $17, $10   ; 

  db $00   ; end token



_off_000_D631_19
  ddb $228E ; ppu address
  db $05   ; counter
  db $0E, $1B, $1B, $18, $1B   ; 

  db $00   ; end token



_off_000_D63A_06
  ddb $2184 ; ppu address
  db $18 + con_40   ; counter
  db $27   ; 

  ddb $2344 ; ppu address
  db $18 + con_40   ; counter
  db $27   ; 

  ddb $21A4 ; ppu address
  db $0D + con_C0   ; counter
  db $27   ; 

  ddb $21BB ; ppu address
  db $0D + con_C0   ; counter
  db $27   ; 

  db $00   ; end token



_off_000_D64B_02
  ddb $23E3 ; ppu address
  db $0B + con_40   ; counter
  db $AA   ; 

  ddb $23F2 ; ppu address
  db $04 + con_40   ; counter
  db $FF   ; 

  ddb $2083 ; ppu address
  db $1A + con_40   ; counter
  db $27   ; 

  ddb $20A3 ; ppu address
  db $1A + con_40   ; counter
  db $27   ; 

  ddb $2183 ; ppu address
  db $1A + con_40   ; counter
  db $27   ; 

  ddb $21A3 ; ppu address
  db $1A + con_40   ; counter
  db $27   ; 

  ddb $20C3 ; ppu address
  db $06 + con_C0   ; counter
  db $27   ; 

  ddb $20C4 ; ppu address
  db $06 + con_C0   ; counter
  db $27   ; 

  ddb $20DB ; ppu address
  db $06 + con_C0   ; counter
  db $27   ; 

  ddb $20DC ; ppu address
  db $06 + con_C0   ; counter
  db $27   ; 

  ddb $2107 ; ppu address
  db $12   ; counter
  db $98, $9A, $9C, $9E, $A0, $A2, $A4, $A6, $A8, $98, $9A, $98, $AA, $A4, $AC   ; 
  db $AE, $98, $9A   ; 

  ddb $2127 ; ppu address
  db $12   ; counter
  db $99, $9B, $9D, $9F, $A1, $A3, $A5, $A7, $A9, $99, $9B, $99, $AB, $A5, $AD   ; 
  db $AF, $99, $9B   ; 

  ddb $220C ; ppu address
  db $0B   ; counter
  db $1C, $0E, $15, $0E, $0C, $1D, $12, $18, $17, $FC, $0A   ; 

  ddb $224C ; ppu address
  db $0B   ; counter
  db $1C, $0E, $15, $0E, $0C, $1D, $12, $18, $17, $FC, $0B   ; 

  ddb $228C ; ppu address
  db $06   ; counter
  db $0D, $0E, $1C, $12, $10, $17   ; 

  ddb $2309 ; ppu address
  db $0E   ; counter
  db $3A, $01, $09, $08, $04, $FC, $17, $12, $17, $1D, $0E, $17, $0D, $18   ; 

  db $00   ; end token



_off_000_D6D4_03
  ddb $23CA ; ppu address
  db $03   ; counter
  db $40, $50, $50   ; 

  ddb $23D3 ; ppu address
  db $02 + con_40   ; counter
  db $55   ; 

  ddb $23E2 ; ppu address
  db $04 + con_40   ; counter
  db $AA   ; 

  ddb $20E6 ; ppu address
  db $03 + con_40   ; counter
  db $26   ; 

  ddb $20F7 ; ppu address
  db $03 + con_40   ; counter
  db $26   ; 

  ddb $20EB ; ppu address
  db $09   ; counter
  db $0C, $11, $0A, $15, $15, $0E, $17, $10, $0E   ; 

  ddb $210D ; ppu address
  db $04   ; counter
  db $1B, $0A, $0C, $0E   ; 

  ddb $220D ; ppu address
  db $06   ; counter
  db $1D, $1B, $0A, $0C, $14, $79   ; 

  ddb $2269 ; ppu address
  db $0D   ; counter
  db $01, $FC, $FC, $02, $FC, $FC, $03, $FC, $FC, $04, $FC, $FC, $05   ; 

  db $00   ; end token



_off_000_D717_04
  ddb $23C9 ; ppu address
  db $06   ; counter
  db $0C, $07, $55, $55, $0D, $03   ; 

  ddb $23DA ; ppu address
  db $04 + con_40   ; counter
  db $50   ; 

  ddb $23DE ; ppu address
  db $01   ; counter
  db $10   ; 

  ddb $23E2 ; ppu address
  db $05   ; counter
  db $55, $55, $99, $AA, $22   ; 

  ddb $23E9 ; ppu address
  db $01   ; counter
  db $C0   ; 

  ddb $23EA ; ppu address
  db $04 + con_40   ; counter
  db $F0   ; 

  ddb $23EE ; ppu address
  db $01   ; counter
  db $30   ; 

  ddb $2087 ; ppu address
  db $02   ; counter
  db $52, $54   ; 

  ddb $2097 ; ppu address
  db $02   ; counter
  db $52, $54   ; 

  ddb $20A4 ; ppu address
  db $05   ; counter
  db $26, $26, $FC, $53, $55   ; 

  ddb $20B7 ; ppu address
  db $05   ; counter
  db $53, $55, $FC, $26, $26   ; 

  ddb $208B ; ppu address
  db $09   ; counter
  db $0C, $11, $0A, $15, $15, $0E, $17, $10, $0E   ; 

  ddb $20AE ; ppu address
  db $04   ; counter
  db $1B, $0A, $0C, $0E   ; 

  ddb $21E8 ; ppu address
  db $09   ; counter
  db $0B, $0E, $1C, $1D, $FC, $1D, $12, $16, $0E   ; 

  ddb $2228 ; ppu address
  db $09   ; counter
  db $22, $18, $1E, $1B, $FC, $1D, $12, $16, $0E   ; 

  ddb $2268 ; ppu address
  db $07   ; counter
  db $1B, $0A, $17, $14, $12, $17, $10   ; 

  ddb $212F ; ppu address
  db $01   ; counter
  db $42   ; 

  ddb $214E ; ppu address
  db $03   ; counter
  db $43, $44, $45   ; 

  db $00   ; end token



_off_000_D796_09
  ddb $23CA ; ppu address
  db $04   ; counter
  db $40, $50, $50, $10   ; 

  ddb $23D3 ; ppu address
  db $02 + con_40   ; counter
  db $AA   ; 

  ddb $23DB ; ppu address
  db $02   ; counter
  db $AA, $22   ; 

  ddb $23E2 ; ppu address
  db $03 + con_40   ; counter
  db $55   ; 

  ddb $23EA ; ppu address
  db $03 + con_40   ; counter
  db $55   ; 

  ddb $20E6 ; ppu address
  db $03 + con_40   ; counter
  db $26   ; 

  ddb $20F7 ; ppu address
  db $03 + con_40   ; counter
  db $26   ; 

  ddb $20EB ; ppu address
  db $0A   ; counter
  db $0E, $21, $0C, $12, $1D, $0E, $0B, $12, $14, $0E   ; 

  ddb $218C ; ppu address
  db $07   ; counter
  db $FC, $1D, $1B, $0A, $0C, $14, $FC   ; 

  ddb $216E ; ppu address
  db $03   ; counter
  db $ED, $FC, $F0   ; 

  ddb $21AE ; ppu address
  db $03   ; counter
  db $EE, $EF, $F1   ; 

  ddb $222B ; ppu address
  db $09   ; counter
  db $0B, $0E, $1C, $1D, $FC, $1D, $12, $16, $0E   ; 

  ddb $226B ; ppu address
  db $03 + con_80   ; counter
  db $B5, $B0, $B2   ; 

  ddb $2273 ; ppu address
  db $03 + con_80   ; counter
  db $B6, $B1, $B4   ; 

  ddb $226C ; ppu address
  db $07 + con_40   ; counter
  db $B7   ; 

  ddb $22AC ; ppu address
  db $07 + con_40   ; counter
  db $B3   ; 

  db $00   ; end token



_off_000_D7FA_0F
  ddb $23CB ; ppu address
  db $0B + con_40   ; counter
  db $55   ; 

  ddb $23DB ; ppu address
  db $02 + con_40   ; counter
  db $F0   ; 

  ddb $23E3 ; ppu address
  db $01   ; counter
  db $FF   ; 

  ddb $23EB ; ppu address
  db $01   ; counter
  db $FF   ; 

  ddb $23F3 ; ppu address
  db $02 + con_40   ; counter
  db $0F   ; 

  ddb $20CC ; ppu address
  db $0B   ; counter
  db $19, $15, $0A, $22, $FC, $16, $18, $0D, $0E, $FC, $0A   ; 

  ddb $212C ; ppu address
  db $0B   ; counter
  db $19, $15, $0A, $22, $FC, $16, $18, $0D, $0E, $FC, $0B   ; 

  ddb $21EC ; ppu address
  db $06   ; counter
  db $0D, $0E, $1C, $12, $10, $17   ; 

  ddb $224C ; ppu address
  db $04   ; counter
  db $1C, $0A, $1F, $0E   ; 

  ddb $22AC ; ppu address
  db $04   ; counter
  db $15, $18, $0A, $0D   ; 

  ddb $230C ; ppu address
  db $05   ; counter
  db $1B, $0E, $1C, $0E, $1D   ; 

  db $00   ; end token



_off_000_D84A_05
  ddb $2323 ; ppu address
  db $18   ; counter
  db $0A, $0B, $0C, $0D, $0E, $0F, $10, $11, $12, $13, $14, $15, $16, $17, $18   ; 
  db $19, $1A, $1B, $1C, $FE, $B8, $FE, $24, $25   ; 

  db $00   ; end token


; bzk garbage
  db $FF   ; 
  db $FF   ; 



tbl_D868
  db $34   ; 00 
  db $34   ; 01 
  db $18   ; 02 
  db $34   ; 03 



tbl_D86C
; 00 
  db $03   ; 00 
  db $02   ; 01 
  db $03   ; 02 
  db $02   ; 03 
  db $09   ; 04 
  db $06   ; 05 
  db $08   ; 06 
  db $0F   ; 07 
; 08 
  db $03   ; 00 
  db $02   ; 01 
  db $02   ; 02 
  db $02   ; 03 
  db $08   ; 04 
  db $05   ; 05 
  db $07   ; 06 
  db $0F   ; 07 



tbl_D87C
; 00 
  db $0C   ; 00 
  db $09   ; 01 
  db $0A   ; 02 
  db $07   ; 03 
  db $0C   ; 04 
  db $0C   ; 05 
  db $0C   ; 06 
  db $00   ; 07 
; 08 
  db $0C   ; 00 
  db $0A   ; 01 
  db $0B   ; 02 
  db $08   ; 03 
  db $0C   ; 04 
  db $0C   ; 05 
  db $0C   ; 06 



tbl_D88B
  db $06   ; 00 
  db $03   ; 01 
  db $04   ; 02 
  db $02   ; 03 
  db $0B   ; 04 
  db $08   ; 05 
  db $09   ; 06 




tbl_D892
  db $58   ; 00 
  db $60   ; 01 
  db $69   ; 02 
  db $71   ; 03 
  db $79   ; 04 
  db $80   ; 05 
  db $0A   ; 06 
  db $18   ; 07 
  db $20   ; 08 
  db $28   ; 09 
  db $30   ; 0A 
  db $38   ; 0B 
  db $40   ; 0C 
  db $48   ; 0D 
  db $50   ; 0E 
  db $50   ; 0F 
  db $97   ; 10 
  db $90   ; 11 
  db $89   ; 12 
  db $11   ; 13 
  db $A6   ; 14 
  db $9F   ; 15 
  db $B3   ; 16 



tbl_D8A9
  db $01   ; 00 
  db $00   ; 01 
  db $02   ; 02 
  db $02   ; 03 
  db $03   ; 04 
  db $00   ; 05 
  db $09   ; 06 
  db $08   ; 07 
  db $08   ; 08 
  db $10   ; 09 
  db $10   ; 0A 
  db $10   ; 0B 
  db $02   ; 0C 
  db $10   ; 0D 
  db $10   ; 0E 
  db $10   ; 0F 
  db $01   ; 10 
  db $09   ; 11 
  db $09   ; 12 
  db $09   ; 13 
  db $01   ; 14 
  db $09   ; 15 
  db $03   ; 16 



tbl_D8C0
  db $04   ; 
  db $28   ; 
  db $4C   ; 
  db $70   ; 



tbl_D8C4
  db $39   ; 00 
  db $01   ; 01 
  db $01   ; 02 
  db $01   ; 03 
  db $07   ; 04 



tbl_D8C9
  db $00   ; 
  db $01   ; 
  db $01   ; 
  db $02   ; 



tbl_D8CD
  db $00   ; 00 
  db $11   ; 01 
  db $22   ; 02 
  db $33   ; 03 
  db $44   ; 04 
  db $66   ; 05 
  db $88   ; 06 
  db $AA   ; 07 



tbl_D8D5
  db $02   ; 00 
  db $01   ; 01 
  db $01   ; 02 



tbl_D8D8
  db $0E   ; 01 
  db $1A   ; 02 
  db $26   ; 03 
  db $32   ; 04 



tbl_D8DC_spr_index
  db $00   ; 00 
  db $0C   ; 01 
  db $18   ; 02 



tbl_D8DF
  db $A0   ; 00 
  db $40   ; 01 
  db $40   ; 02 



tbl_D8E2
  db $ED   ; 00 
  db $21   ; 01 
  db $21   ; 02 



tbl_D8E5
  db $E2   ; 00 
  db $E8   ; 01 



tbl_D8E7
  db $9E   ; 00 
  db $A6   ; 01 
  db $92   ; 02 
  db $9A   ; 03 
  db $86   ; 04 
  db $8E   ; 05 
  db $7A   ; 06 
  db $82   ; 07 



tbl_D8EF_lo
  db < ofs_004_E0E6_00   ; 
  db < ofs_004_E2AF_01   ; 



tbl_D8F1_hi
  db > ofs_004_E0E6_00   ; 
  db > ofs_004_E2AF_01   ; 



tbl_D8F3
  db $CF   ; 
  db $D3   ; 
  db $D7   ; 
  db $CF   ; 



tbl_D8F7
  db $3F   ; 
  db $0F   ; 
  db $07   ; 
  db $07   ; 



tbl_D8FB
  db $08   ; 
  db $20   ; 
  db $11   ; 
  db $11   ; 



tbl_D8FF_lo
  db < ofs_003_D923_00_RTS   ; 
  db < ofs_003_D933_01   ; 
  db < ofs_003_D953_02   ; 
  db < ofs_003_D983_03   ; 
  db < ofs_003_D9D3_04   ; 
  db < ofs_003_D9F6_05   ; 



tbl_D905_hi
  db > ofs_003_D923_00_RTS   ; 
  db > ofs_003_D933_01   ; 
  db > ofs_003_D953_02   ; 
  db > ofs_003_D983_03   ; 
  db > ofs_003_D9D3_04   ; 
  db > ofs_003_D9F6_05   ; 



tbl_D90B
  db $BF   ; 
  db $C3   ; 
  db $C6   ; 



tbl_D90E
  db $08   ; 
  db $0A   ; 
  db $0F   ; 
  db $14   ; 
  db $18   ; 



tbl_D913
  db $08   ; 
  db $14   ; 
  db $20   ; 
  db $2C   ; 
  db $38   ; 



sub_D918
  LDX #$03
bra_D91A_loop
  JSR sub_D924
  JSR sub_DA15
  DEX
  BPL bra_D91A_loop
ofs_003_D923_00_RTS
  RTS



sub_D924
  LDY ram_009C_obj,X
  LDA tbl_D8FF_lo,Y
  STA ram_0000
  LDA tbl_D905_hi,Y
  STA ram_0001
;  JMP (ram_0000)
  JMP JMP_IND_00



ofs_003_D933_01
  LDA ram_0370_obj,X
  BEQ bra_D94E
  LDA ram_003F
  LSR
  BCS bra_D952_RTS
  INC ram_0390_obj,X
  LDY ram_03E4_obj,X
  LDA ram_0080_obj,X
  CLC
  ADC tbl_D90E,Y
  CMP ram_0390_obj,X
  BCS bra_D952_RTS
bra_D94E
  INC ram_009C_obj,X
  BNE bra_D97E
bra_D952_RTS
  RTS



ofs_003_D953_02
  TXA
  TAY
  BEQ bra_D95D
  LDA ram_00BC_obj,X
  BEQ bra_D95D
  LDY #$04
bra_D95D
  LDA ram_obj_pos_Y_lo,X
  CMP tbl_D8C4,Y
  BEQ bra_D96E
  LDY #$01
  BCC bra_D96A
  LDY #$FF
bra_D96A
  TYA
  STA ram_00DC_obj,X
  RTS
bra_D96E
  LDA #$00
  STA ram_0398_obj,X
  STA ram_00DC_obj,X
  INC ram_009C_obj,X
  TXA
  BNE bra_D97E
  LDA #$02
  STA ram_00FD
bra_D97E
  LDA #$08
  STA ram_002A_timer,X
  RTS



ofs_003_D983_03
  LDA ram_0370_obj,X
  BEQ bra_D9C0
  LDA ram_002A_timer,X
  BNE bra_D9D2_RTS
  TXA
  ORA ram_03F7
  BNE bra_D9A1
  LDY ram_0049
  LDA ram_btn_hold
  AND #con_btns_AB
  BEQ bra_D99F
  STA ram_0049
  TYA
  BEQ bra_D9A7
bra_D99F
  STA ram_0049
bra_D9A1
  LDA ram_003F
  AND #$0F
  BNE bra_D9AA
bra_D9A7
  DEC ram_0390_obj,X
bra_D9AA
  AND #$07
  BNE bra_D9B6
  LDA ram_0398_obj,X
  EOR #$01
  STA ram_0398_obj,X
bra_D9B6
  LDA ram_0390_obj,X
  SEC
  SBC #$08
  CMP ram_0080_obj,X
  BCS bra_D9D2_RTS
bra_D9C0
  LDA #$03
  STA ram_0036_timer,X
  INC ram_009C_obj,X
  LDA #$00
  CPX #$03
  BNE bra_D9D2_RTS
  STA ram_03A8
  STA ram_0370_obj + $03
bra_D9D2_RTS
  RTS



ofs_003_D9D3_04
  LDA ram_0036_timer,X
  BNE bra_D9F5_RTS
  TXA
  BNE bra_D9E7
  LDA ram_03E0_obj
  BNE bra_DA10
  LDA ram_03F7
  BEQ bra_D9F3
  JMP loc_CA85
bra_D9E7
  LDA ram_0022_timer
  BNE bra_D9F5_RTS
  LDA #$01
  STA ram_00DC_obj,X
  LDA #$18
  STA ram_0022_timer
bra_D9F3
  INC ram_009C_obj,X
bra_D9F5_RTS
  RTS



ofs_003_D9F6_05
  LDA ram_0094_obj,X
  ORA ram_00DC_obj,X
  BNE bra_DA03
  LDA ram_obj_pos_Y_lo,X
  CMP tbl_D8C4,X
  BEQ bra_DA14_RTS
bra_DA03
  LDA #$01
  STA ram_00DC_obj,X
  TXA
  BEQ bra_DA10
  LDA ram_obj_pos_Y_lo,X
  CMP #$08
  BCC bra_DA14_RTS
bra_DA10
  LDA #$00
  STA ram_009C_obj,X
bra_DA14_RTS
  RTS



sub_DA15
  LDA ram_0390_obj,X
  SEC
  SBC ram_0080_obj,X
  SBC #$08
  ASL
  CLC
  ADC ram_obj_pos_Y_lo,X
  ADC #$04
  STA ram_006C_obj,X
  RTS



sub_DA26
  LDA ram_004F_race_started_flag
  BEQ bra_DA69_RTS
  LDX #$03
bra_DA2C_loop
  JSR sub_DA58
  JSR sub_DC1A
  JSR sub_DCF2
  JSR sub_DCDE
  DEX
  BPL bra_DA2C_loop
  JSR sub_DA6A
  JSR sub_DA7A
  JSR sub_DBFE
  LDA ram_003C_timer
  BNE bra_DA69_RTS
  LDY ram_03BC
  LDA tbl_D8EF_lo,Y
  STA ram_0000
  LDA tbl_D8F1_hi,Y
  STA ram_0001
;  JMP (ram_0000)
  JMP JMP_IND_00


sub_DA58
  LDA ram_0094_obj,X
  STA ram_0060,X
  LDA ram_0090_obj,X
  CLC
  ADC ram_0394_obj,X
  STA ram_0394_obj,X
  BCC bra_DA69_RTS
  INC ram_0060,X
bra_DA69_RTS
  RTS



sub_DA6A
  LDA ram_scroll_X
  CLC
  ADC ram_0060
  STA ram_scroll_X
  BCC bra_DA79_RTS
  LDA ram_004D_base_nametable
  EOR #$01
  STA ram_004D_base_nametable
bra_DA79_RTS
  RTS



sub_DA7A
  LDX #$03
bra_DA7C_loop
  LDA ram_00A8_obj,X
  BEQ bra_DA9B
  LDA ram_0060,X
  CLC
  ADC ram_0080_obj,X
  BCC bra_DA89
  INC ram_0084_obj,X
bra_DA89
  SEC
  SBC ram_0060
  STA ram_0080_obj,X
  BCS bra_DA92
  DEC ram_0084_obj,X
bra_DA92
  LDA ram_0390_obj,X
  SEC
  SBC ram_0060
  STA ram_0390_obj,X
bra_DA9B
  DEX
  BNE bra_DA7C_loop
  RTS



sub_DA9F
  LDX #$03
  LDA ram_003B_timer
  BNE bra_DADF
bra_DAA5_loop
  TXA
  EOR ram_004C
  ORA ram_00A8_obj,X
  ORA ram_0023_timer
  ORA ram_0370_obj + $03
  ORA ram_03A8
  BNE bra_DADF
  LDA ram_0018,X
  CMP #$A0
  BCC bra_DADF
  STX ram_0000
  AND #$03
  TAY
  INY
  LDA ram_0094_obj
  AND #$02
  STA ram_0084_obj,X
  LDX #$03
bra_DAC8_loop
  STY ram_0001
  LDA ram_0070_obj,X
  CMP ram_0001
  BNE bra_DAD7
  INY
  CPY #$05
  BCC bra_DAD7
  LDY #$01
bra_DAD7
  DEX
  BNE bra_DAC8_loop
  LDX ram_0000
  JSR sub_DAE3
bra_DADF
  DEX
  BNE bra_DAA5_loop
  RTS



sub_DAE3
; in
;    ; X = object index (01, 02, 03)
; out
;    ; Z
;        ; 0 = 
;        ; 1 = 
  JSR sub_DB95_clear_opponent_bike_data
  DEY
  LDA tbl_D8D8,Y
  STA ram_obj_pos_Y_lo,X
  LDY ram_0084_obj,X
  LDA tbl_D8DF,Y
  STA ram_0080_obj,X
  LDA #$06
  STA ram_00AC_obj,X
  LDA ram_00E0_obj
  CLC
  ADC tbl_D8E2,Y
  AND #$3F
  STA ram_00E0_obj,X
  LDA ram_0064
  STA ram_0064,X
  TYA
  BEQ bra_DB34
  LDY #$05
  JSR sub_E7FF
  CMP #$E4
  BEQ bra_DB34
  CMP #$3B
  BCC bra_DB4D
  CMP #$93
  BCS bra_DB4D
  LDY #$02
  JSR sub_E7FF
  CMP #$E6
  BNE bra_DB34
  LDA ram_obj_pos_Y_lo,X
  CMP #$20
  BCC bra_DB30
  LDA #$30
  STA ram_00BC_obj,X
  LDA #$01
  BNE bra_DB32    ; jmp
bra_DB30
  LDA #$03
bra_DB32
  STA ram_00A4_obj,X
bra_DB34
  LDY ram_0084_obj,X
  JSR sub_DB50
  LDA ram_0084_obj,X
  EOR #$02
  ASL
  STA ram_0094_obj,X
  LDA #$20
  STA ram_039C_obj - $01,X  ; $039C $039D $039E
  LSR ; 10
  STA ram_0023_timer
  LDA #$01
  STA ram_00A8_obj,X
  RTS
bra_DB4D
  LDA #$00
  RTS



loc_DB50
sub_DB50
  LDA ram_0052_track_finished_flag
  BEQ bra_DB58
  LDA #$03
  BNE bra_DB5F    ; jmp
bra_DB58
  CPX #$03
  BEQ bra_DB6C
bra_DB5C
  LDA tbl_D8D5,Y
bra_DB5F
  STA ram_0078,X
  LDA ram_001B,X
  AND #$0F
  TAY
  LDA tbl_D8CD,Y
  STA ram_0074,X
  RTS
bra_DB6C
  LDA ram_0084_obj,X
  LSR
  LSR
  BCS bra_DB5C
  LDA ram_0094_obj
  BEQ bra_DB5C
  STA ram_0078,X
  LDA ram_0090_obj
  STA ram_0074,X
  LDA ram_0084_obj,X
  BEQ bra_DB8C
  LDA ram_0080_obj,X
  CMP #$40
  BCS bra_DB5C
  LDA ram_0070_obj
  CMP ram_0070_obj + $03
  BEQ bra_DB94_RTS
bra_DB8C
  LDA ram_0078,X
  CMP #$04
  BCS bra_DB94_RTS
  INC ram_0078,X
bra_DB94_RTS
  RTS



sub_DB95_clear_opponent_bike_data
loc_DB95_clear_opponent_bike_data
; X = 01 02 03 
  LDA #$00
  STA ram_00A8_obj,X
  STA ram_obj_pos_Y_lo,X
  STA ram_00BC_obj,X
  STA ram_00A0_obj,X
  STA ram_00A4_obj,X
  STA ram_0058_obj,X
  STA ram_00CC_obj,X
  STA ram_036C_obj,X
  STA ram_0090_obj,X
  STA ram_0094_obj,X
  STA ram_0098_obj,X
  STA ram_009C_obj,X
  STA ram_00B0_obj,X
  STA ram_00D4_obj,X
  STA ram_0388_obj,X
  STA ram_00C0_obj,X
  STA ram_039C_obj,X
  STA ram_00DC_obj,X
  STA ram_0070_obj,X
  STA ram_0370_obj,X
bra_DBC3_RTS
  RTS



sub_DBC4
  LDA ram_03A8
  BEQ bra_DBC3_RTS
  LDA ram_00A8_obj + $03
  BEQ bra_DBE0
  LDX #$03
  LDA ram_0084_obj,X
  LSR
  BCS bra_DBC3_RTS
  LSR
  BCS bra_DBDD
  LDA ram_0080_obj,X
  CMP #$EA
  BCS bra_DBC3_RTS
bra_DBDD
  JMP loc_DB95_clear_opponent_bike_data
bra_DBE0
  LDY #$00
  STY ram_03A8
  INY ; 01
  LDX #$02
  STX ram_0084_obj + $03
  INX ; 03
  JSR sub_DAE3
  BEQ bra_DBC3_RTS
  LDA #$00
  STA ram_0094_obj + $03
  LDA #$92
  STA ram_008C + $03
  STA ram_0370_obj + $03
  JMP loc_DC69



sub_DBFE
  LDA ram_0060
  LSR
  ROR
  ROR
  ROR
  CLC
  ADC ram_03BF
  STA ram_03BF
  LDA ram_0060
  ADC ram_0050_scroll_X
  STA ram_0050_scroll_X
  BCC bra_DC19_RTS
  LDA ram_004E_base_nametable
  EOR #$01
  STA ram_004E_base_nametable
bra_DC19_RTS
  RTS



sub_DC1A
  LDA ram_00B0_obj,X
  BEQ bra_DC19_RTS
  JSR sub_DC97
  STA ram_0001
  CMP ram_008C,X
  BCS bra_DC19_RTS
  LDA ram_008C,X
  CMP #$A8
  BCS bra_DC19_RTS
  LDA ram_0364_obj,X
  BEQ bra_DC19_RTS
  TXA
  BNE bra_DC39
  LDA #$02
  STA ram_00FF
bra_DC39
  LDA #$00
  STA ram_00B0_obj,X
  STA ram_0364_obj,X
  LDA ram_0098_obj,X
  BNE bra_DC87
  LDA ram_0052_track_finished_flag
  BNE bra_DC8E
  LDY ram_0388_obj,X
  STA ram_0388_obj,X
  TYA
  BNE bra_DC87
  LDA ram_00D4_obj,X
  LDY ram_0094_obj,X
  CPY #$02
  BPL bra_DC5C
  CLC
  ADC #$08
bra_DC5C
  TAY
  LDA ram_00AC_obj,X
  CMP tbl_D86C,Y
  BCC bra_DC69
  CMP tbl_D87C,Y
  BCC bra_DC6E
bra_DC69
loc_DC69
  LDA #$FF
  STA ram_0098_obj,X
  RTS
bra_DC6E
  LDA ram_0368_obj,X
  CMP ram_00AC_obj,X
  BEQ bra_DC87
  LDA ram_00D4_obj,X
  ORA ram_00CC_obj,X
  BNE bra_DC87
  LDA #$04
  STA ram_0374_obj,X
  LSR ; 02
  STA ram_0388_obj,X
  LSR ; 01
  STA ram_00B0_obj,X
bra_DC87
  DEC ram_0001
  LDA ram_0001
  STA ram_008C,X
bra_DC8D_RTS
  RTS
bra_DC8E
  LDA ram_00D4_obj,X
  BNE bra_DC8D_RTS
  LDA #$06
  STA ram_00AC_obj,X
  RTS



sub_DC97
  LDA ram_03F1
sub_DC9A
  SEC
  SBC ram_00BC_obj,X
  SBC ram_obj_pos_Y_lo,X
  RTS



sub_DCA0
  LDY ram_00D4_obj,X
  LDA ram_0052_track_finished_flag
  CMP #$01
  BNE bra_DCB5
  TXA
  ORA ram_0098_obj
  ORA ram_009C_obj
  ORA ram_0058_obj
  BNE bra_DCB5
  LDA #$0A
  BNE bra_DCB8    ; jmp
bra_DCB5
  LDA tbl_D88B,Y
bra_DCB8
  STA ram_0368_obj,X
  LDA ram_00A4_obj,X
  CMP #$01
  BNE bra_DCC6_RTS
  LDA #$06
  STA ram_0368_obj,X
bra_DCC6_RTS
  RTS



loc_DCC7
  STA ram_0000
  LDA ram_002A_timer,X
  BNE bra_DCDD_RTS
  STY ram_002A_timer,X
  LDA ram_00AC_obj,X
  CMP ram_0000
  BEQ bra_DCDD_RTS
  BCC bra_DCDB
  DEC ram_00AC_obj,X
  DEC ram_00AC_obj,X
bra_DCDB
  INC ram_00AC_obj,X
bra_DCDD_RTS
  RTS



sub_DCDE
  LDA ram_0374_obj,X
  BEQ bra_DCF1_RTS
  DEC ram_0374_obj,X
  LDA ram_005C_obj,X
  AND #$C0
  BEQ bra_DCF1_RTS
  LDA #$00
  STA ram_0374_obj,X
bra_DCF1_RTS
  RTS



sub_DCF2
  LDA ram_00B0_obj,X
  BEQ bra_DD37_RTS
  CMP #$02
  BEQ bra_DD11
bra_DCFA
loc_DCFA
  LDA #$00
  BEQ bra_DD08    ; jmp



loc_DCFE
  LDA ram_0098_obj,X
  BNE bra_DCFA
  INC ram_0094_obj,X
  BNE bra_DCFA    ; jmp?



loc_DD06
sub_DD06
  LDA ram_0094_obj,X
bra_DD08
  STA ram_0384_obj,X
  JSR sub_DD38
  JMP loc_DD1A
bra_DD11
  LDA ram_005C_obj,X
  LSR
  BCC bra_DD1A
  LDA ram_004C
  BEQ bra_DD37_RTS
bra_DD1A
loc_DD1A
  LDA ram_005C_obj,X
  AND #$03
  TAY
  LDA tbl_D868,Y
  STA ram_038C_obj,X
  LDA ram_008C,X
  STA ram_0001
  JSR sub_DD6F
  STA ram_008C,X
  LDA ram_00CC_obj,X
  BNE bra_DD37_RTS
  LDA #$01
  STA ram_0364_obj,X
bra_DD37_RTS
  RTS



sub_DD38
  LDA #$02
  STA ram_00B0_obj,X
  LDA #$0F
  STA ram_0380_obj,X
  LDA ram_0090_obj,X
  CLC
  ADC #< $00AF
  STA ram_0378_obj,X
  LDA ram_0094_obj,X
  ADC #> $00AF
  STA ram_037C_obj,X
  LDA ram_0388_obj,X
  CMP #$02
  BNE bra_DD5D
  LSR ram_037C_obj,X
  ROR ram_0378_obj,X
bra_DD5D
  TXA
  BNE bra_DD6E_RTS
  LDA ram_0094_obj,X
  ASL
  ASL
  ASL
  ASL
  EOR #$30
  BNE bra_DD6C
  LDA #$08
bra_DD6C
  STA ram_00FF
bra_DD6E_RTS
  RTS



sub_DD6F
  LDA ram_0380_obj,X
  ADC ram_038C_obj,X
  STA ram_0380_obj,X
  LDA ram_0384_obj,X
  ADC #$00
  STA ram_0384_obj,X
  LDA ram_0001
  SBC ram_037C_obj,X
  STA ram_0001
  LDA ram_0001
  ADC ram_0384_obj,X
bra_DD8C_RTS
  RTS



sub_DD8D
  LDA ram_003C_timer
  ORA ram_03E0_obj
  BEQ bra_DD8C_RTS
  LDA ram_003C_timer
  CMP #$08
  BEQ bra_DDBF
  BCC bra_DDCE
  LDA ram_0094_obj
  ORA ram_0098_obj
  ORA ram_009C_obj
  BNE bra_DDBC
  LDA ram_0058_obj
  BEQ bra_DDAE
  LDA #$C0
  STA ram_0090_obj
  BNE bra_DDBC    ; jmp
bra_DDAE
  STA ram_0090_obj
  LDX #$01
  LDA ram_obj_pos_Y_lo
  CMP tbl_D8C4
  BNE bra_DDBA
  DEX
bra_DDBA
  STX ram_00DC_obj
bra_DDBC
  JMP loc_CCDD
bra_DDBF
  LDA #$00
  STA ram_03E0_obj
  LDA #$05
  STA ram_03B6
  STA ram_009C_obj
  STA ram_0374_obj
bra_DDCE
  JMP loc_CD13



sub_DDD1
  LDX #$03
bra_DDD3_loop
  LDA ram_0098_obj,X
  BEQ bra_DE2D
  LDY #$04
  TXA
  BNE bra_DDEE
  STA ram_03A9
  STA ram_00FC
  LDA ram_004C
  BNE bra_DDE9
  LDA #$01
  STA ram_00FD
bra_DDE9
  LDA ram_001B
  AND #$03
  TAY
bra_DDEE
  TYA
  STA ram_03E4_obj,X
  LDA ram_004C
  LSR
  BCS bra_DE2D
  LDA ram_0094_obj,X
  BNE bra_DE24
  LDA ram_00B0_obj,X
  ORA ram_0058_obj,X
  BNE bra_DE20
  STA ram_0090_obj,X
  STA ram_0060,X
  STA ram_0098_obj,X
  LDA #$06
  STA ram_00AC_obj,X
  LDA ram_0080_obj,X
  CLC
  ADC #$08
  STA ram_0390_obj,X
  JSR sub_DA15
  LDA #$02
  STA ram_0398_obj,X
  LSR ; 01
  STA ram_009C_obj,X
  BNE bra_DE2D
bra_DE20
  LDA #$88
  STA ram_0090_obj,X
bra_DE24
  LDA ram_00AC_obj,X
  CLC
  ADC ram_0098_obj,X
  AND #$0F
  STA ram_00AC_obj,X
bra_DE2D
  DEX
  BPL bra_DDD3_loop
  RTS



sub_DE31
  LDA ram_0024_timer
  CMP #$01
  BEQ bra_DEA6
  LDY ram_004F_race_started_flag
  BNE bra_DEA5_RTS
  CMP #$60
  BCS bra_DE4E
  LDA ram_03A9
  BEQ bra_DE4E
  LDA ram_005C_obj
  AND #$C0
  BEQ bra_DE4E
  LDA #$01
  STA ram_00FE_flag
bra_DE4E
  LDY #$F0
  LDA ram_0024_timer
  CMP #$10
  BCS bra_DE5E
  LDY #$F2
  CMP #$08
  BCS bra_DE5E
  LDY #$F4
bra_DE5E
  CMP #$72
  BNE bra_DE66
  LDA #$20
  STA ram_00FB
bra_DE66
  STY ram_0000
  LDA ram_03B4
  STA ram_0001
  LDY #$07
bra_DE6F_loop
  TYA
  ASL
  ASL
  TAX
  LDA tbl_D8E7,Y
  STA ram_spr_Y + $C0,X
  LDA ram_0000
  STA ram_spr_T + $C0,X
  LDA #$00
  STA ram_spr_A + $C0,X
  LDA ram_0001
  STA ram_spr_X + $C0,X
  TYA
  LSR
  BCC bra_DE91
  INC ram_spr_T + $C0,X
  BNE bra_DE9A
bra_DE91
  LDA ram_0001
  SEC
  SBC #$10
  STA ram_0001
  BCC bra_DE9D
bra_DE9A
  DEY
  BPL bra_DE6F_loop
bra_DE9D
  LDA ram_0034_timer
  BEQ bra_DEA5_RTS
  LDA #$88
  STA ram_0024_timer
bra_DEA5_RTS
  RTS
bra_DEA6
  LDA #$01
  STA ram_004F_race_started_flag
  LDA ram_03B4
  SEC
  SBC ram_0060
  STA ram_03B4
  BCC bra_DEA5_RTS
  LDA #$02
  STA ram_0024_timer
  BNE bra_DE4E    ; jmp



sub_DEBB
  LDX #$03
bra_DEBD_loop
  LDA ram_0084_obj,X
  LSR
  BCC bra_DEDE
  LDA ram_0080_obj,X
  CMP #$30
  BCC bra_DECC
  CMP #$40
  BCC bra_DED9
bra_DECC
  LDA ram_03AA_obj - $01,X
  BEQ bra_DEDE
  LDA #$40
  STA ram_00FF
  LDA #$00
  BEQ bra_DEDB    ; jmp
bra_DED9
  LDA #$01
bra_DEDB
  STA ram_03AA_obj - $01,X
bra_DEDE
  DEX
  BNE bra_DEBD_loop
  RTS



sub_DEE2
  LDX #$00
  LDA ram_03A9
  BEQ bra_DF2D
  LDA ram_004C
  LSR
  BCS bra_DEA5_RTS
  LDX #$02
  LDA ram_0094_obj
  STA ram_0000
  LDA ram_0090_obj
  STA ram_0001
bra_DEF8_loop
  LSR ram_0000
  ROR ram_0001
  DEX
  BPL bra_DEF8_loop
  LDA #$02
  LDY ram_00B0_obj
  BEQ bra_DF07
  LDA #$04
bra_DF07
  TAX
  LDA ram_0001
  SEC
  SBC #$02
  BMI bra_DF15
  JSR sub_DFA4
  TXA
  BNE bra_DF17
bra_DF15
  LDX #$01
bra_DF17
  CPX #$2F
  BCC bra_DF24
  LDX #$2F
  LDA ram_003F
  AND #$08
  BNE bra_DF24
  DEX
bra_DF24
  LDA ram_005C_obj
  ASL
  BCS bra_DF2D
  TXA
  ORA #$80
  TAX
bra_DF2D
  STX ram_00FC
  RTS



sub_DF30
  LDA ram_004F_race_started_flag
  BEQ bra_DF51_RTS
  LDA ram_006B
  CLC
  ADC #$10
  STA ram_006B
bra_DF3B_loop
  LDA ram_006B
  CMP #$0A
  BCS bra_DF52
bra_DF41
  LDX #$68
  JSR sub_DF7F
  LDX #$06
bra_DF48_loop
  LDA ram_03D1,X
  STA ram_03D9,X
  DEX
  BPL bra_DF48_loop
bra_DF51_RTS
  RTS
bra_DF52
  LDA ram_006B
  SEC
  SBC #$0A
  STA ram_006B
  INC ram_006A
  LDA ram_006A
  CMP #$64
  BCC bra_DF3B_loop
  LDA #$00
  STA ram_006A
  INC ram_0069
  LDA ram_0069
  CMP #$3C
  BCC bra_DF3B_loop
  LDA #$00
  STA ram_0069
  INC ram_0068
  LDA ram_0068
  CMP #$09
  BCC bra_DF3B_loop
; time up (9 minutes)
  LDA #$02
  STA ram_0052_track_finished_flag
  BNE bra_DF41    ; jmp



sub_DF7F
  LDA ram_0000,X
  PHA
  LDA ram_0001,X
  PHA
  LDA ram_0002,X
  JSR sub_DFA2
  STX ram_03D6
  STA ram_03D7
  PLA
  JSR sub_DFA2
  STX ram_03D3
  STA ram_03D4
  PLA
  JSR sub_DFA2
  STA ram_03D1
  RTS



sub_DFA2
  LDX #$0A
sub_DFA4
  STX ram_000F
  LDX #$00
bra_DFA8_loop
  INX
  SEC
  SBC ram_000F
  BPL bra_DFA8_loop
  DEX
  ADC ram_000F
  RTS



sub_DFB2
  LDY #$00
  LDA ram_009C_obj,X
  BNE bra_DFD1
  LDA ram_obj_pos_Y_lo,X
bra_DFBA_loop
  CMP tbl_D913,Y
  BMI bra_DFC6
  INY
  CPY #$05
  BMI bra_DFBA_loop
  LDY #$00
bra_DFC6
  TYA
  BEQ bra_DFD1
  LDA #$01
  CMP ram_00A4_obj,X
  BNE bra_DFD1
  INY
  INY
bra_DFD1
  TYA
  STA ram_0070_obj,X
  RTS



sub_DFD5
  LDX #$00
  LDY #$01
loc_DFD9
  LDA ram_00A8_obj,X
  BNE bra_DFE0
bra_DFDD
  JMP loc_E086
bra_DFE0
loc_DFE0
;  LDA ram_00A8_obj,Y
  JSR LDA_ram_00A8_obj_Y
  BEQ bra_E01D
  LDA ram_0084_obj,X
  LSR
  BCC bra_DFDD
;  LDA ram_0084_obj,Y
  JSR LDA_ram_0084_obj_Y
  LSR
  BCC bra_E01D
  LDA ram_0070_obj,X
  BEQ bra_DFDD
;  CMP ram_0070_obj,Y
  JSR CMP_ram_0070_obj_Y
  BNE bra_E01D
  LDA ram_0098_obj,X
  ORA ram_03E0_obj,X
  BNE bra_DFDD
;  LDA ram_0098_obj,Y
  JSR LDA_ram_0098_obj_Y
  BNE bra_E07E
  LDA ram_00B0_obj,X
  BNE bra_E00E
;  LDA ram_00B0_obj,Y
  JSR LDA_ram_00B0_obj_Y
  BEQ bra_E02A
bra_E00E
  LDA ram_008C,X
;  CMP ram_008C,Y
  JSR CMP_ram_008C_obj_Y
  BCS bra_E020
  JSR sub_E091
;  CMP ram_008C,Y
  JSR CMP_ram_008C_obj_Y
  BCS bra_E02A
bra_E01D
  JMP loc_E07E
bra_E020
;  LDA ram_008C,Y
  JSR LDA_ram_008C_obj_Y
  JSR sub_E091
  CMP ram_008C,X
  BCC bra_E07E
bra_E02A
  LDA ram_0080_obj,X
;  CMP ram_0080_obj,Y
  JSR CMP_ram_0080_obj_Y
  BCS bra_E045
  JSR sub_E098
;  CMP ram_0080_obj,Y
  JSR CMP_ram_0080_obj_Y
  BCS bra_E061
  LDA ram_0080_obj,X
  JSR sub_E091
;  CMP ram_0080_obj,Y
  JSR CMP_ram_0080_obj_Y
  BCS bra_E05B
  BCC bra_E07E    ; jmp
bra_E045
;  LDA ram_0080_obj,Y
  JSR LDA_ram_0080_obj_Y
  JSR sub_E098
  CMP ram_0080_obj,X
  BCS bra_E061
;  LDA ram_0080_obj,Y
  JSR LDA_ram_0080_obj_Y
  JSR sub_E091
  CMP ram_0080_obj,X
  BCS bra_E065
  BCC bra_E07E    ; jmp
bra_E05B
  LDA #$FF
  STA ram_0098_obj,X
  BNE bra_E076    ; jmp
bra_E061
  LDA #$FF
  STA ram_0098_obj,X
bra_E065
  CPX #$00
  BNE bra_E071
  CPY #$03
  BNE bra_E071
  LDA #$10
  STA ram_003B_timer
bra_E071
  LDA #$FF
;  STA ram_0098_obj,Y
  JSR STA_ram_0098_obj_Y
bra_E076
  CPX #$00
  BNE bra_E07E
  LDA #$01
  STA ram_00FD
bra_E07E
loc_E07E
  INY
  CPY #$04
  BEQ bra_E086
  JMP loc_DFE0
bra_E086
loc_E086
  INX
  TXA
  TAY
  INY
  CPX #$03
  BEQ bra_E097_RTS
  JMP loc_DFD9



sub_E091
  CMP #$E7
  BCS bra_E097_RTS
  ADC #$0C
bra_E097_RTS
  RTS



sub_E098
  CMP #$E7
  BCS bra_E09E_RTS
  ADC #$02
bra_E09E_RTS
  RTS



sub_E09F
  LDA ram_009C_obj
  BNE bra_E0E5_RTS
  TAX
  LDA ram_0084_obj + $03
  LSR
  BCC bra_E0E5_RTS
  LDA ram_0370_obj + $03
  BEQ bra_E0E5_RTS
  LDA ram_obj_pos_Y_lo
  SEC
  SBC #$03
  CMP ram_006C_obj + $03
  BCS bra_E0E5_RTS
  ADC #$07
  CMP ram_006C_obj + $03
  BCC bra_E0E5_RTS
  LDA ram_0080_obj
  CMP ram_0390_obj + $03
  BCS bra_E0E5_RTS
  ADC #$12
  CMP ram_0390_obj + $03
  BCC bra_E0E5_RTS
  JSR sub_DC97
  SEC
  SBC #$08
  CMP ram_008C
  BCS bra_E0E5_RTS
  LDY #$FF
  STY ram_0098_obj
  INY ; 00
  STY ram_00DC_obj + $03
  INY ; 01
  STY ram_009C_obj + $03
  STY ram_00FD
  INY ; 02
  STY ram_0398_obj + $03
bra_E0E5_RTS
  RTS



ofs_004_E0E6_00
  LDA ram_003A_timer
  ORA ram_0052_track_finished_flag
  ORA ram_0024_timer
  BNE bra_E09E_RTS
  LDA ram_03A0
  BNE bra_E10A
  LDA ram_002E_timer
  BNE bra_E09E_RTS
  LDA ram_0018
  AND #$03
  TAX
  LDA tbl_D8F3,X
  STA ram_03A1
  LDA #$F8
  STA ram_03B9
  STA ram_03A0
bra_E10A
  LDA #$50
  STA ram_0001
  LDA ram_03B9
  SEC
  SBC ram_0060
  STA ram_03B9
  LDA ram_0060
  BEQ bra_E124
  LDA ram_003F
  AND #$0F
  BNE bra_E124
  DEC ram_03B9
bra_E124
  LDA ram_03B9
  STA ram_0000
  CMP #$FC
  BCC bra_E139
  LDA ram_0018
  AND #$A0
  STA ram_002E_timer
  LDA #$00
  STA ram_03A0
  RTS
bra_E139
  LDA ram_03A1
  STA ram_0002
  LDA #$22
  STA ram_0003
  LDA #$C0
  STA ram_0004
  LDA #$20
  STA ram_000B
  JSR sub_D1C7
  LDA ram_03B9
  CMP #$60
  BCS bra_E17E_RTS
  LDX ram_03A1
  INX
  INX
  INX
  STX ram_0000
  JSR sub_E16C
  LDX ram_03A1
  INX
  STX ram_0000
  LDA ram_0004
  CLC
  ADC #$08
  STA ram_0004
sub_E16C
  LDY #$06
bra_E16E_loop
  LDA #$60
  STA (ram_0004),Y
  DEY
  LDA ram_0000
  STA (ram_0004),Y
  DEC ram_0000
  DEY
  DEY
  DEY
  BPL bra_E16E_loop
bra_E17E_RTS
  RTS



sub_E17F
  JSR sub_E3F4
  LDX #$03
bra_E184_loop
  STX ram_000D
  LDA tbl_D8C0,X
  STA ram_0004
  LDA ram_0088,X
  TAX
  LDA ram_00A8_obj,X
  BEQ bra_E19D
  LDA tbl_D8C9,X
  STA ram_000B
  JSR sub_E1A3
  JSR sub_E26A
bra_E19D
  LDX ram_000D
  DEX
  BPL bra_E184_loop
  RTS



sub_E1A3
  LDA ram_0080_obj,X
  STA ram_0000
  LDA ram_008C,X
  STA ram_0001
  JSR sub_E1F9
  TAY
  LDA tbl_D892,Y
  STA ram_0002
  LDA #$33
  STA ram_0003
  CPY #$16
  BNE bra_E1D1
  LDA ram_0004
  STA ram_039C_obj + $03
  CLC
  ADC #$0C
  STA ram_0004
  LDA ram_0001
  CLC
  ADC #$08
  STA ram_0001
  LDA #$23
  STA ram_0003
bra_E1D1
  LDA tbl_D8A9,Y
  JSR sub_D1C7
  LDA ram_000E
  BEQ bra_E1F8_RTS
  LSR
  BCS bra_E1F2
  LDY #$11
  LDA #$B2
bra_E1E2_loop
  CPY #$09
  BEQ bra_E1EB
  STA (ram_0004),Y
  SEC
  SBC #$01
bra_E1EB
  DEY
  DEY
  DEY
  DEY
  BPL bra_E1E2_loop
  RTS
bra_E1F2
  LDY #$15
  LDA #$AE
  STA (ram_0004),Y
bra_E1F8_RTS
  RTS



sub_E1F9
  LDA #$00
  STA ram_000E
  STA ram_039C_obj + $03
  LDA ram_009C_obj,X
  BEQ bra_E21F
  CMP #$05
  BEQ bra_E21F
  LDY #$06
  LDA ram_00BC_obj,X
  BNE bra_E213
  LDA ram_0370_obj,X
  BNE bra_E215
bra_E213
  LDY #$02
bra_E215
  TYA
  LDY ram_0036_timer,X
  BEQ bra_E21C
  DEY
  TYA
bra_E21C
  ORA #$10
  RTS
bra_E21F
  LDY ram_0052_track_finished_flag
  DEY
  BNE bra_E22F
  LDA ram_00AC_obj,X
  CMP #$0A
  BNE bra_E22F
  LDY #$02
  STY ram_000E
  RTS
bra_E22F
  LDA ram_0098_obj,X
  ORA ram_00B0_obj,X
  BNE bra_E267
  LDA ram_0058_obj,X
  BEQ bra_E243
  CMP #$0D
  BNE bra_E267
  LDA ram_obj_pos_Y_lo,X
  CMP #$20
  BCC bra_E267
bra_E243
  LDA ram_0090_obj,X
  ORA ram_0094_obj,X
  BNE bra_E24D
  INC ram_000E
  BNE bra_E267
bra_E24D
  LDA ram_00AC_obj,X
  CMP #$06
  BNE bra_E267
  LDY #$14
  LDA ram_00DC_obj,X
  BEQ bra_E25E
  BPL bra_E25C
  INY
bra_E25C
  TYA
  RTS
bra_E25E
  LDA ram_003F
  AND #$02
  BEQ bra_E267
  LDA #$13
  RTS
bra_E267
  LDA ram_00AC_obj,X
bra_E269_RTS
  RTS



sub_E26A
  LDA ram_039C_obj + $03
  BEQ bra_E269_RTS
  LDA ram_0084_obj,X
  CMP #$02
  BEQ bra_E269_RTS
  LDA ram_0390_obj,X
  CMP #$F8
  BCS bra_E269_RTS
  CMP ram_0080_obj,X
  BCC bra_E269_RTS
  LDA ram_0390_obj,X
  STA ram_0000
  LDA #$A8
  SEC
  SBC ram_006C_obj,X
  STA ram_0001
  LDA #$22
  STA ram_0003
  LDA ram_039C_obj + $03
  STA ram_0004
  LDA ram_00A4_obj,X
  BEQ bra_E29B
  LDA #$20
bra_E29B
  ORA ram_000B
  STA ram_000B
  LDY ram_0398_obj,X
  LDA tbl_D90B,Y
  STA ram_0002
  TYA
  BEQ bra_E2AC
  EOR #$03
bra_E2AC
  JMP loc_D1C7



ofs_004_E2AF_01
  LDA ram_03BD
  SEC
  SBC ram_0060
  STA ram_03BD
  BCS bra_E2BD
  DEC ram_03BE
bra_E2BD
  LDY ram_0052_track_finished_flag
  BEQ bra_E2D0
  DEY
  BNE bra_E269_RTS
  LDA ram_0020_0A_frm_timer
  BNE bra_E2D0
; if 10d frames passed
  LDA ram_03BB
  EOR #$01
  STA ram_03BB
bra_E2D0
  LDY ram_03BE
  DEY
  BNE bra_E303
  LDA ram_03BD
  STA ram_0000
  LDA #$50
  STA ram_0001
  LDY ram_03BB
  LDA tbl_D8E5,Y
  STA ram_0002
  LDA #$32
  STA ram_0003
  LDA #$C0
  STA ram_0004
  LDA #$00
  STA ram_000B
  JMP loc_D1C7



sub_E2F6
  LDA ram_036C_obj,X
  BEQ bra_E358_RTS
  LDA ram_0094_obj,X
  ORA ram_0090_obj,X
  BEQ bra_E358_RTS
  LDA ram_00BC_obj,X
bra_E303
  BNE bra_E358_RTS
  LDA ram_0084_obj,X
  LSR
  BCC bra_E358_RTS
  LDA ram_0080_obj,X
  CMP #$10
  BCC bra_E358_RTS
  CLC
  ADC #$F9
  STA ram_spr_X + $94,Y
  CLC
  ADC #$F8
  STA ram_spr_X + $98,Y
  LDA ram_008C,X
  CLC
  ADC #$08
  STA ram_spr_Y + $98,Y
  CLC
  ADC #$08
  STA ram_spr_Y + $94,Y
  LDA #$F6
  STA ram_spr_T + $94,Y
  LDA #$F7
  STA ram_spr_T + $98,Y
  LDA ram_003F
  AND #$04
  BEQ bra_E344
  LDA #$F7
  STA ram_spr_T + $94,Y
  LDA #$F6
  STA ram_spr_T + $98,Y
bra_E344
  LDA ram_036C_obj,X
  AND #$02
  STA ram_spr_A + $94,Y
  STA ram_spr_A + $98,Y
  LDA ram_0094_obj,X
  BNE bra_E358_RTS
  LDA #$F8
  STA ram_spr_Y + $98,Y
bra_E358_RTS
  RTS



sub_E359_display_temperature_meter_with_sprites
; if you disable background in your emulator,
; you will see that temperature bar is always
; full size, it's just moving left/right behind
; HUD background to be partially visible
  LDA ram_0052_track_finished_flag
  BNE bra_E3C6
  LDA ram_03E0_obj
  BEQ bra_E36B
  LDA ram_003C_timer
  LSR
  BCS bra_E3C6
  LDA #$FC
  BNE bra_E3C8    ; jmp
bra_E36B
  LDA ram_005C_obj
  AND #$C0
  BEQ bra_E37A
  LDY ram_004F_race_started_flag
  BNE bra_E377
  LDA #$80
bra_E377
  ASL
  ROL
  ROL
bra_E37A
  TAY
  LDA ram_03B6
  CMP tbl_D8FB,Y
  BCC bra_E39B
  BEQ bra_E3AA
  LDA ram_03B5
  SEC
  SBC #$0B
  STA ram_03B5
  BCS bra_E3AA
  LDA ram_03B6
  BEQ bra_E3AA
  DEC ram_03B6
  JMP loc_E3AA
bra_E39B
  LDA ram_03B5
  CLC
  ADC tbl_D8F7,Y
  STA ram_03B5
  BCC bra_E3AA
  INC ram_03B6
bra_E3AA
loc_E3AA
  LDX #$00
  LDA ram_03B6
  CMP #$20
  BCC bra_E3B8
  STA ram_003C_timer
  STA ram_03E0_obj
bra_E3B8
  CMP #$1A
  BCC bra_E3C1
  DEY
  BNE bra_E3C1
; breakpoint triggers here if overheat danger while holding B
  LDX #$B0
bra_E3C1
  TXA
  ORA ram_00FC
  STA ram_00FC
bra_E3C6
  LDA #$FE
bra_E3C8
  STA ram_0001
  LDA ram_03B6
  CLC
  ADC #$50
  STA ram_0000
  LDX #$0C
bra_E3D4_loop
  LDA #$CF
  STA ram_spr_Y + $F0,X
  LDA ram_0001
  STA ram_spr_T + $F0,X
  LDA #$20
  STA ram_spr_A + $F0,X
  LDA ram_0000
  STA ram_spr_X + $F0,X
  CLC
  ADC #$08
  STA ram_0000
  DEX
  DEX
  DEX
  DEX
  BPL bra_E3D4_loop
  RTS



sub_E3F4
  LDX #$03
bra_E3F6_loop
  TXA
  STA ram_0088,X
  LDA ram_obj_pos_Y_lo,X
  STA ram_0000,X
  DEX
  BPL bra_E3F6_loop
  LDA ram_0370_obj + $03
  BEQ bra_E409
  LDA ram_006C_obj + $03
  STA ram_0003
bra_E409
  LDX #$03
  STX ram_000D
bra_E40D_loop
  LDY #$00
bra_E40F_loop
  LDX ram_0088,Y
  LDA ram_0000,X
  LDX ram_0088 + $01,Y
  CMP ram_0000,X
  BCC bra_E421
;  LDA ram_0088,Y
  JSR LDA_ram_0088_obj_Y
;  STA ram_0088 + $01,Y
  JSR STA_ram_0080_obj_a1_Y
  STX ram_0088,Y
bra_E421
  INY
  CPY ram_000D
  BNE bra_E40F_loop
  DEC ram_000D
  BNE bra_E40D_loop
  RTS



loc_E42B
  LDA ram_03A3_flag
  BEQ bra_E455_RTS
  LDX #$03
bra_E432_loop
  LDA ram_0088,X
  BEQ bra_E44A
  CMP #$03
  BNE bra_E43F
  LDA ram_0370_obj + $03
  BNE bra_E44A
bra_E43F
  LDA tbl_D8C0,X
  STA ram_0007
  LDY ram_03B3
  JSR sub_E4AD_hide_4_sprites
bra_E44A
  DEX
  BPL bra_E432_loop
  LDA ram_03B3
  EOR #$02
  STA ram_03B3
bra_E455_RTS
  RTS



sub_E456
  LDY #$03
bra_E458_loop
  STY ram_0005
  LDA tbl_D8C0,Y
  STA ram_0007
;  LDA ram_0088,Y
  JSR LDA_ram_0088_obj_Y
  BEQ bra_E495
  TAX
  LDA ram_0084_obj,X
  STA ram_0002
  STA ram_0003
  STA ram_0004
  LSR
  BCS bra_E484
  LDA ram_0080_obj,X
  CMP #$70
  BCC bra_E484
  CMP #$90
  BCS bra_E484
  JSR sub_DB95_clear_opponent_bike_data
  LDA #$01
  STA ram_03A6_flag
  BNE bra_E492    ; jmp
bra_E484
  LDA ram_0080_obj,X
  CMP #$F8
  BCC bra_E48C
  INC ram_0003
bra_E48C
  CMP #$F0
  BCC bra_E492
  INC ram_0004
bra_E492
  JSR sub_E49B_hide_12_sprites
bra_E495
  LDY ram_0005
  DEY
  BPL bra_E458_loop
  RTS



sub_E49B_hide_12_sprites
; 12d sprites
; bzk optimize, use LDX 02 from the beginning, replace with DEX + BPL at the end
  LDX #$00
bra_E49D_loop
  LDA ram_0002,X
  LSR
  BCS bra_E4A7
  TXA
  TAY
  JSR sub_E4AD_hide_4_sprites
bra_E4A7
  INX
  CPX #$03
  BCC bra_E49D_loop
  RTS



sub_E4AD_hide_4_sprites
  LDA #> ram_oam
  STA ram_0001
  LDA ram_0007
  CLC
; bzk optimize, use X for table indexing, delete TXA + TAY at 0x0024B2
  ADC tbl_D8DC_spr_index,Y
  STA ram_0000
  LDY #$00
  LDA #$F8
bra_E4BD_loop
  STA (ram_0000),Y
  INY
  INY
  INY
  INY
  CPY #$0C
  BCC bra_E4BD_loop
  RTS



sub_E4C8
  LDX #$01
bra_E4CA_loop
  STX ram_000C
  LDA ram_0084_obj,X
  LSR
  BCS bra_E4D9
  BNE bra_E50A
  LDA ram_0080_obj,X
  CMP #$F8
  BCC bra_E50A
bra_E4D9
  LDA #$00
  STA ram_000A
  TXA
  TAY
  INY
bra_E4E0_loop
  STY ram_0005
;  LDA ram_0084_obj,Y
  JSR LDA_ram_0084_obj_Y
  LSR
  BCS bra_E4F0
  BNE bra_E4FF
  LDA ram_0080_obj,X
  CMP #$F8
  BCC bra_E4FF
bra_E4F0
  JSR sub_E52C
  BEQ bra_E4FF
  INC ram_000A
  LDA ram_000B
  ASL
  ASL
  ORA ram_0005
  STA ram_000B
bra_E4FF
  INY
  CPY #$04
  BCC bra_E4E0_loop
  LDA ram_000A
  CMP #$02
  BCS bra_E513
bra_E50A
  LDX ram_000C
  DEX
  BPL bra_E4CA_loop
  LDA #$00
  BEQ bra_E528    ; jmp
bra_E513
  BNE bra_E526
  LDA ram_000B
  PHA
  AND #$03
  TAY
  PLA
  LSR
  LSR
  AND #$03
  TAX
  JSR sub_E52C
  BEQ bra_E50A
bra_E526
  LDA #$01
bra_E528
  STA ram_03A3_flag
  RTS



sub_E52C
  LDA ram_008C,X
  SEC
;  SBC ram_008C,Y
  JSR SBC_ram_008C_Y
  CMP #$EC
  BCS bra_E53C_RTS
  CMP #$12
  BCC bra_E53C_RTS
  LDA #$00
bra_E53C_RTS
  RTS



tbl_E53D
  db $0E   ; 
  db $1A   ; 
  db $26   ; 



tbl_E540_spr_T
  db $32   ; 
  db $DD   ; 
  db $DC   ; 



tbl_E543_spr_X
  db $DB   ; 
  db $7C   ; 
  db $74   ; 
  db $6C   ; 



tbl_E547_spr_X
  db $90   ; 
  db $88   ; 
  db $80   ; 
  db $78   ; 
  db $70   ; 
  db $68   ; 
  db $60   ; 



tbl_E54E_lo
  db < ram_0400   ; 
  db < ram_0440   ; 
  db < ram_0480   ; 
  db < ram_04C0   ; 
  db < ram_0500   ; 
  db < ram_0540   ; 



tbl_E554_hi
  db > ram_0400   ; 
  db > ram_0440   ; 
  db > ram_0480   ; 
  db > ram_04C0   ; 
  db > ram_0500   ; 
  db > ram_0540   ; 



tbl_E55A_lo
  db < _off_002_E584_00   ; 
  db < _off_002_E599_01   ; 
  db < _off_002_E599_02   ; 
  db < _off_002_E5A6_03   ; 
  db < _off_002_E5BB_04   ; 
  db < _off_002_E5D0_05   ; 
  db < _off_002_E5E5_06   ; 
  db < _off_002_E5F8_07   ; 
  db < _off_002_E60B_08   ; 
  db < _off_002_E61E_09   ; 
  db < _off_002_E631_0A   ; 
  db < _off_002_E63E_0B   ; 
  db < _off_002_E649_0C   ; 
  db < _off_002_E652_0D   ; 
  db < _off_002_E667_0E   ; 
  db < _off_002_E684_0F   ; 
  db < _off_002_E686_10   ; 
  db < _off_002_E689_11   ; 
  db < _off_002_E689_12   ; 
  db < _off_002_E68C_13   ; 
  db < _off_002_E697_14   ; 



tbl_E56F_hi
  db > _off_002_E584_00   ; 
  db > _off_002_E599_01   ; 
  db > _off_002_E599_02   ; 
  db > _off_002_E5A6_03   ; 
  db > _off_002_E5BB_04   ; 
  db > _off_002_E5D0_05   ; 
  db > _off_002_E5E5_06   ; 
  db > _off_002_E5F8_07   ; 
  db > _off_002_E60B_08   ; 
  db > _off_002_E61E_09   ; 
  db > _off_002_E631_0A   ; 
  db > _off_002_E63E_0B   ; 
  db > _off_002_E649_0C   ; 
  db > _off_002_E652_0D   ; 
  db > _off_002_E667_0E   ; 
  db > _off_002_E684_0F   ; 
  db > _off_002_E686_10   ; 
  db > _off_002_E689_11   ; 
  db > _off_002_E689_12   ; 
  db > _off_002_E68C_13   ; 
  db > _off_002_E697_14   ; 



_off_002_E584_00
  db $04   ; 
  db $87   ; 
  db $08   ; 
  db $88   ; 
  db $08   ; 
  db $44   ; 
  db $29   ; 
  db $06   ; 
  db $29   ; 
  db $00   ; 
  db $31   ; 
  db $85   ; 
  db $35   ; 
  db $84   ; 
  db $35   ; 
  db $45   ; 
  db $51   ; 
  db $00   ; 
  db $52   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E599_01
_off_002_E599_02
  db $04   ; 
  db $07   ; 
  db $04   ; 
  db $88   ; 
  db $0C   ; 
  db $86   ; 
  db $10   ; 
  db $83   ; 
  db $14   ; 
  db $85   ; 
  db $16   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E5A6_03
  db $04   ; 
  db $88   ; 
  db $0A   ; 
  db $89   ; 
  db $0A   ; 
  db $42   ; 
  db $20   ; 
  db $06   ; 
  db $22   ; 
  db $00   ; 
  db $30   ; 
  db $08   ; 
  db $50   ; 
  db $84   ; 
  db $52   ; 
  db $83   ; 
  db $54   ; 
  db $43   ; 
  db $6C   ; 
  db $00   ; 
  db $FF   ; 



_off_002_E5BB_04
  db $04   ; 
  db $88   ; 
  db $0A   ; 
  db $89   ; 
  db $0A   ; 
  db $42   ; 
  db $23   ; 
  db $06   ; 
  db $2A   ; 
  db $00   ; 
  db $2F   ; 
  db $84   ; 
  db $33   ; 
  db $83   ; 
  db $34   ; 
  db $43   ; 
  db $53   ; 
  db $00   ; 
  db $55   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E5D0_05
  db $04   ; 
  db $88   ; 
  db $0A   ; 
  db $89   ; 
  db $0A   ; 
  db $42   ; 
  db $17   ; 
  db $06   ; 
  db $1A   ; 
  db $00   ; 
  db $1F   ; 
  db $84   ; 
  db $23   ; 
  db $83   ; 
  db $23   ; 
  db $43   ; 
  db $35   ; 
  db $00   ; 
  db $37   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E5E5_06
  db $04   ; 
  db $88   ; 
  db $0A   ; 
  db $89   ; 
  db $0A   ; 
  db $42   ; 
  db $12   ; 
  db $06   ; 
  db $12   ; 
  db $00   ; 
  db $1A   ; 
  db $83   ; 
  db $1B   ; 
  db $43   ; 
  db $24   ; 
  db $00   ; 
  db $26   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E5F8_07
  db $04   ; 
  db $88   ; 
  db $0A   ; 
  db $89   ; 
  db $0A   ; 
  db $42   ; 
  db $22   ; 
  db $06   ; 
  db $22   ; 
  db $00   ; 
  db $2A   ; 
  db $82   ; 
  db $2B   ; 
  db $4A   ; 
  db $38   ; 
  db $00   ; 
  db $3A   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E60B_08
  db $04   ; 
  db $88   ; 
  db $0A   ; 
  db $8B   ; 
  db $0B   ; 
  db $49   ; 
  db $17   ; 
  db $06   ; 
  db $17   ; 
  db $00   ; 
  db $25   ; 
  db $83   ; 
  db $26   ; 
  db $43   ; 
  db $3B   ; 
  db $00   ; 
  db $3D   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E61E_09
  db $04   ; 
  db $8B   ; 
  db $08   ; 
  db $49   ; 
  db $18   ; 
  db $06   ; 
  db $18   ; 
  db $00   ; 
  db $1F   ; 
  db $84   ; 
  db $20   ; 
  db $82   ; 
  db $25   ; 
  db $4A   ; 
  db $35   ; 
  db $00   ; 
  db $37   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E631_0A
  db $02   ; 
  db $01   ; 
  db $04   ; 
  db $88   ; 
  db $0A   ; 
  db $89   ; 
  db $0A   ; 
  db $42   ; 
  db $1A   ; 
  db $06   ; 
  db $1A   ; 
  db $00   ; 
  db $FF   ; 



_off_002_E63E_0B
  db $04   ; 
  db $8B   ; 
  db $08   ; 
  db $49   ; 
  db $18   ; 
  db $06   ; 
  db $1A   ; 
  db $00   ; 
  db $1F   ; 
  db $0B   ; 
  db $FF   ; 



_off_002_E649_0C
  db $0D   ; 
  db $0C   ; 
  db $17   ; 
  db $0C   ; 
  db $28   ; 
  db $0C   ; 
  db $2B   ; 
  db $0C   ; 
  db $FF   ; 



_off_002_E652_0D
  db $04   ; 
  db $8B   ; 
  db $08   ; 
  db $49   ; 
  db $22   ; 
  db $06   ; 
  db $22   ; 
  db $00   ; 
  db $22   ; 
  db $14   ; 
  db $30   ; 
  db $0F   ; 
  db $31   ; 
  db $83   ; 
  db $32   ; 
  db $82   ; 
  db $33   ; 
  db $4A   ; 
  db $4B   ; 
  db $00   ; 
  db $FF   ; 



_off_002_E667_0E
  db $00   ; 
  db $0B   ; 
  db $18   ; 
  db $06   ; 
  db $18   ; 
  db $84   ; 
  db $1A   ; 
  db $83   ; 
  db $1A   ; 
  db $43   ; 
  db $3B   ; 
  db $00   ; 
  db $42   ; 
  db $10   ; 
  db $43   ; 
  db $85   ; 
  db $48   ; 
  db $84   ; 
  db $4A   ; 
  db $83   ; 
  db $4A   ; 
  db $43   ; 
  db $5A   ; 
  db $00   ; 
  db $5A   ; 
  db $0E   ; 
  db $5C   ; 
  db $86   ; 
  db $FF   ; 



_off_002_E684_0F
  db $0E   ; 
  db $0D   ; 



_off_002_E686_10
  db $0F   ; 
  db $0E   ; 
  db $FF   ; 



_off_002_E689_11
_off_002_E689_12
  db $00   ; 
  db $12   ; 
  db $FF   ; 



_off_002_E68C_13
  db $04   ; 
  db $88   ; 
  db $0A   ; 
  db $89   ; 
  db $0A   ; 
  db $42   ; 
  db $1A   ; 
  db $13   ; 
  db $1A   ; 
  db $00   ; 
  db $FF   ; 



_off_002_E697_14
  db $1E   ; 
  db $86   ; 
  db $FF   ; 



tbl_E69A
  db $CB   ; 
  db $CD   ; 
  db $CC   ; 
  db $CE   ; 
  db $CB   ; 
  db $CB   ; 
  db $CB   ; 



tbl_E6A1
  db $22   ; 
  db $64   ; 
  db $62   ; 
  db $C0   ; 
  db $22   ; 
  db $74   ; 
  db $63   ; 
  db $E0   ; 
  db $21   ; 
  db $83   ; 
  db $FC   ; 
  db $C0   ; 



tbl_E6AD
  db $03   ; 
  db $01   ; 
  db $02   ; 
  db $02   ; 
  db $00   ; 
  db $05   ; 
  db $05   ; 
  db $06   ; 
  db $04   ; 
  db $04   ; 



tbl_E6B7
ofs_002_E6B7_11
  dw ofs_002_E963_00
  dw ofs_002_E8E3_01
  dw ofs_002_E85D_02
  dw ofs_002_E86A_03
  dw ofs_002_E845_04
  dw ofs_002_E854_05
  dw ofs_002_E934_06
  dw ofs_002_E818_07
  dw ofs_002_EA8F_08
  dw ofs_002_E879_09
  dw ofs_002_E89D_0A
  dw ofs_002_E8EE_0B
  dw ofs_002_E8FF_0C
  dw ofs_002_E956_0D
  dw ofs_002_E8BF_0E
  dw ofs_002_E8C6_0F
  dw ofs_002_E8FA_10
  dw ofs_002_E6B7_11   ; unused
  dw ofs_002_E8D3_12
  dw ofs_002_E8E7_13
  dw ofs_002_E8F5_14



tbl_E6E1
  db $08   ; 00 
  db $07   ; 01 
  db $05   ; 02 
  db $01   ; 03 
  db $0B   ; 04 
  db $06   ; 05 
  db $0A   ; 06 
  db $0E   ; 07 
  db $03   ; 08 
  db $04   ; 09 
  db $0C   ; 0A 
  db $0D   ; 0B 
  db $0F   ; 0C 
  db $10   ; 0D 
  db $12   ; 0E 
  db $13   ; 0F 
  db $11   ; 00 
  db $15   ; 01 
  db $14   ; 02 
  db $00   ; 03 
  db $09   ; 04 



tbl_E6F6_spr_X
  db $18   ; 00 
  db $20   ; 01 
  db $28   ; 02 
  db $30   ; 03 
  db $38   ; 04 
tbl_E6FB_40    ; for BIT instruction
  db $40   ; 05 
  db $48   ; 06 
  db $50   ; 07 
  db $58   ; 08 
  db $60   ; 09 
  db $68   ; 0A 
  db $70   ; 0B 
  db $78   ; 0C 
tbl_E703_80    ; for BIT instruction
  db $80   ; 0D 
  db $88   ; 0E 
  db $90   ; 0F 
  db $98   ; 10 
  db $A0   ; 11 
  db $A8   ; 12 
  db $B8   ; 13 
  db $CC   ; 14 



sub_E70B
  LDX #$03
bra_E70D_loop
  LDA ram_0060,X
  BEQ bra_E72B
  LDA ram_0064,X
  SEC
  SBC ram_0060,X
  BEQ bra_E71E
  BMI bra_E71E
  STA ram_0064,X
  BNE bra_E72B    ; jmp
bra_E71E
  CLC
  ADC #$08
  STA ram_0064,X
  INC ram_00E0_obj,X
  LDA ram_00E0_obj,X
  AND #$3F
  STA ram_00E0_obj,X
bra_E72B
; bzk optimize, start loop at E72D
  LDA #$00
  STA ram_00D8,X
  DEX
  BPL bra_E70D_loop
  RTS



sub_E733
  LDX #$03
bra_E735_loop
  JSR sub_E73B
  DEX
  BNE bra_E735_loop
sub_E73B
  LDA ram_0060,X
  CLC
  ADC ram_obj_pos_X_lo,X
  STA ram_obj_pos_X_lo,X
  LDA ram_0058_obj,X
  BNE bra_E762_loop
  LDA ram_00C0_obj,X
  SEC
  SBC #$40
  BMI bra_E753_RTS
  LSR
  LSR
  CMP #$16
  BCC bra_E754
bra_E753_RTS
  RTS
bra_E754
  STA ram_0058_obj,X
  INC ram_0058_obj,X
  LDA #$00
  STA ram_00C4_obj,X
  LDA ram_0064,X
  STA ram_obj_pos_X_lo,X
  DEC ram_obj_pos_X_lo,X
bra_E762_loop
  LDY ram_0058_obj,X
  LDA tbl_E55A_lo - $01,Y
  STA ram_000A
  LDA tbl_E56F_hi - $01,Y
  STA ram_000B
  LDY ram_00C4_obj,X
  LDA (ram_000A),Y
  CMP #$FF
  BEQ bra_E7D0
  STA ram_000F
  CMP ram_obj_pos_X_lo,X
  BEQ bra_E77E
  BCS bra_E753_RTS
bra_E77E
  INY
  LDA (ram_000A),Y
  BIT tbl_E703_80
  BNE bra_E7A3
  BIT tbl_E6FB_40
  BNE bra_E7F2
  JSR sub_E794
  INC ram_00C4_obj,X
  INC ram_00C4_obj,X
  BNE bra_E762_loop   ; jmp



sub_E794
  ASL
  TAY
  LDA tbl_E6B7,Y
  STA ram_0000
  LDA tbl_E6B7 + $01,Y
  STA ram_0001
;  JMP (ram_0000)
  JMP JMP_IND_00



bra_E7A3
  LDA ram_00B0_obj,X
  ORA ram_0098_obj,X
  BNE bra_E7CA
  LDA (ram_000A),Y
  AND #$0F
  STA ram_0000
  LDA ram_00A4_obj,X
  CMP #$01
  BEQ bra_E7CA
  LDA ram_0000
  STA ram_00AC_obj,X
  LDA ram_0058_obj,X
  CMP #$03
  BEQ bra_E7CA
  LDA ram_00AC_obj,X
  SEC
  SBC #$02
  TAY
  LDA tbl_E6AD,Y
  STA ram_00D4_obj,X
bra_E7CA
  INC ram_00C4_obj,X
  INC ram_00C4_obj,X
  BNE bra_E762_loop   ; jmp?



bra_E7D0
  LDA #$00
  STA ram_0058_obj,X
  STA ram_00D4_obj,X
  LDA ram_00A0_obj,X
  BNE bra_E7EC
  LDA ram_00A4_obj,X
  CMP #$01
  BEQ bra_E7EC
  LDA #$00
  STA ram_00BC_obj,X
  LDA ram_00A4_obj,X
  CMP #$02
  BNE bra_E7EC
  INC ram_00A4_obj,X
bra_E7EC
  LDA #$00
  STA ram_036C_obj,X
  RTS
bra_E7F2
  AND #$0F
  STA ram_00CC_obj,X
  LDA ram_000F
  STA ram_00D0_obj,X
  BPL bra_E7CA    ; jmp?



sub_E7FC
  LDY ram_0360_obj,X
sub_E7FF
  LDA ram_00E0_obj,X
  STA ram_0008
sub_E803
  JSR sub_E80D
  STY ram_0007
  LDY ram_0008
  LDA (ram_0003),Y
  RTS



sub_E80D
  LDA tbl_E54E_lo,Y
  STA ram_0003
  LDA tbl_E554_hi,Y
  STA ram_0004
  RTS



ofs_002_E818_07
  LDA ram_00B0_obj,X
  BNE bra_E835_RTS
  LDA ram_00AC_obj,X
  CMP #$07
  BPL bra_E835_RTS
  LDA ram_0094_obj,X
  CMP #$03
  BCS bra_E831
  CMP #$02
  BNE bra_E835_RTS
  LDA ram_0090_obj,X
  ASL
  BCC bra_E835_RTS
bra_E831
  LDA #$FF
  STA ram_0098_obj,X
bra_E835_RTS
  RTS



sub_E836
  LDX #$03
bra_E838_loop
  LDA ram_00B0_obj,X
  BNE bra_E841
  JSR sub_DC97
  STA ram_008C,X
bra_E841
  DEX
  BPL bra_E838_loop
  RTS



ofs_002_E845_04
  LDA #$80
  STA ram_00D8,X
  LDA #$05
  JSR sub_E893
  LSR
sub_E84F
loc_E84F
  STA ram_00BC_obj,X
  STA ram_00E4_obj,X
  RTS



ofs_002_E854_05
  LDA #$02
  JSR sub_E893
  LSR
  JMP loc_E86F



ofs_002_E85D_02
  LDA #$06
  JSR sub_E893
  JSR sub_E84F
  LDA #$60
  STA ram_00D8,X
  RTS



ofs_002_E86A_03
  LDA #$01
  JSR sub_E893
loc_E86F
sub_E86F
  STA ram_0000
  LDA ram_00E4_obj,X
  SEC
  SBC ram_0000
  STA ram_00BC_obj,X
  RTS



ofs_002_E879_09
  LDA #$04
  JSR sub_E893
  ASL
  JSR sub_E84F
  LDA ram_00A0_obj,X
  BEQ bra_E88E
  LDA ram_00BC_obj,X
  CLC
  ADC #$10
  JSR sub_E84F
bra_E88E
  LDA #$40
  STA ram_00D8,X
  RTS



sub_E893
; in
;    ; A = 
  STA ram_00D4_obj,X
  STA ram_00B4_obj,X
  LDA ram_obj_pos_X_lo,X
  SEC
  SBC ram_00D0_obj,X
  RTS



ofs_002_E89D_0A
  LDA ram_00A4_obj,X
  BEQ bra_E8A5
  CMP #$01
  BEQ bra_E8BE_RTS
bra_E8A5
  LDA #$03
  JSR sub_E893
  ASL
  JSR sub_E86F
  LDA ram_00A4_obj,X
  CMP #$04
  BNE bra_E8BE_RTS
  JSR sub_DD06
  LDA #$02
  STA ram_00A4_obj,X
  STA ram_0364_obj,X
bra_E8BE_RTS
  RTS



ofs_002_E8BF_0E
  LDA #$00
  STA ram_00A4_obj,X
bra_E8C3
  STA ram_00A0_obj,X
  RTS



ofs_002_E8C6_0F
  LDA #$01
  STA ram_00A4_obj,X
  LDA ram_obj_pos_Y_lo,X
  CMP #$20
  BCS bra_E8D2_RTS
  INC ram_00A4_obj,X
bra_E8D2_RTS
  RTS



ofs_002_E8D3_12
  TXA
  ORA ram_00B0_obj,X
  ORA ram_03E0_obj
  ORA ram_003C_timer
  BNE bra_E8E2_RTS
  LDA #$08
  STA ram_03B6
bra_E8E2_RTS
  RTS



ofs_002_E8E3_01
  LDA #$01
  BNE bra_E8C3    ; jmp



ofs_002_E8E7_13
  LDA ram_00B0_obj,X
  BNE bra_E8E2_RTS
  JMP loc_DCFE



ofs_002_E8EE_0B
  LDA #$02
  STA ram_00A0_obj,X
  LSR ; 01
  STA ram_00D8,X
ofs_002_E8F5_14
  LDA #$30
  JMP loc_E84F



ofs_002_E8FA_10
  LDA #$10
  JMP loc_E84F



ofs_002_E8FF_0C
  LDA ram_00B0_obj,X
  BNE bra_E926_RTS
  LDA ram_00A4_obj,X
  BEQ bra_E90B
  LSR
  LSR
  BCC bra_E926_RTS
bra_E90B
  STY ram_0001
  LDA ram_0094_obj,X
  BEQ bra_E924
  LDY #$04
  LDA ram_005C_obj,X
  ASL
  ASL
  BCC bra_E91A
  DEY
bra_E91A
  LDA #$01
  STA ram_036C_obj,X
  INY
  INY
  JSR sub_CE5C
bra_E924
  LDY ram_0001
bra_E926_RTS
  RTS



sub_E927
  LDX #$03
bra_E929_loop
  LDA ram_00CC_obj,X
  BEQ bra_E930
  JSR sub_E794
bra_E930
  DEX
  BPL bra_E929_loop
bra_E933_RTS
  RTS



ofs_002_E934_06
  LDA ram_00B0_obj,X
  BNE bra_E933_RTS
  LDY #$00
  LDA ram_0094_obj,X
  BEQ bra_E933_RTS
  CMP #$02
  BCS bra_E949
  LDA ram_0090_obj,X
  CMP ram_00D8,X
  BCS bra_E949
  INY
bra_E949
  TYA
  STA ram_0388_obj,X
  LDA ram_00A0_obj,X
  CMP #$02
  BEQ bra_E960
  JMP loc_DCFA



ofs_002_E956_0D
  LDA ram_00A4_obj,X
  CMP #$01
  BNE bra_E933_RTS
  LDA #$00
  STA ram_00BC_obj,X
bra_E960
  JMP loc_DD06



ofs_002_E963_00
  LDA #$00
  STA ram_00CC_obj,X
  STA ram_00D4_obj,X
  STA ram_00B4_obj,X
  RTS



sub_E96C
  LDX #$03
loc_E96E_loop
  LDA ram_0058_obj,X
  CMP #$15
  BEQ bra_E97F
  CMP #$14
  BEQ bra_E97F
  LDA ram_obj_pos_Y_lo,X
  CLC
  ADC ram_00DC_obj,X
  STA ram_obj_pos_Y_lo,X
bra_E97F
  LDY #$03
bra_E981_loop
  LDA ram_obj_pos_Y_lo,X
  CMP tbl_E53D,Y
  BEQ bra_EA01
  DEY
  BPL bra_E981_loop
  LDA ram_00A4_obj,X
  BEQ bra_E9C4
  CMP #$01
  BNE bra_E9B8
  LDA ram_obj_pos_Y_lo,X
  CMP #$20
  BCS bra_E9C4
  LDA #$04
  STA ram_00A4_obj,X
  LDA ram_0058_obj,X
  BEQ bra_E9AD
  CMP #$12
  BEQ bra_E9AD
  CMP #$10
  BEQ bra_E9AD
  CMP #$0D
  BNE bra_E9E3
bra_E9AD
  LDA #$00
  STA ram_00BC_obj,X
  JSR sub_DD06
  DEC ram_00A4_obj,X
  BNE bra_E9E3
bra_E9B8
  CMP #$03
  BEQ bra_E9C4
  LDA ram_obj_pos_Y_lo,X
  CMP #$20
  BCC bra_E9C4
  DEC ram_obj_pos_Y_lo,X
bra_E9C4
  LDA ram_obj_pos_Y_lo,X
  CMP #$08
  BCC bra_E9E9
  CMP #$3A
  BCC bra_E9E3
  LDA #$39
  STA ram_obj_pos_Y_lo,X
bra_E9D2
  LDA ram_009C_obj,X
  ORA ram_03E0_obj,X
  BNE bra_E9E3
bra_E9D9
  LDA ram_00DC_obj,X
  BNE bra_E9DF
  LDA #$FF
bra_E9DF
  EOR #$FE
  STA ram_00DC_obj,X
bra_E9E3
  DEX
  BMI bra_EA07
  JMP loc_E96E_loop
bra_E9E9
  LDA ram_009C_obj,X
  BNE bra_E9F1
  LDA #$07
  BNE bra_E9F9    ; jmp
bra_E9F1
  LDA ram_obj_pos_Y_lo,X
  CMP #$02
  BCS bra_E9F9
  LDA #$01
bra_E9F9
  STA ram_obj_pos_Y_lo,X
  CPX #$00
  BEQ bra_E9D9
  BNE bra_E9D2    ; jmp
bra_EA01
  LDA #$00
  STA ram_00DC_obj,X
  BEQ bra_E9E3    ; jmp
bra_EA07
  LDA ram_004F_race_started_flag
  BEQ bra_EA43_RTS
  LDA ram_0098_obj
  ORA ram_03E0_obj
  ORA ram_03F7
  BNE bra_EA43_RTS
  LDA ram_00B0_obj
  BEQ bra_EA23
  LDA ram_0388_obj
  CMP #$02
  BNE bra_EA43_RTS
  INC ram_0388_obj
bra_EA23
  LDA ram_009C_obj
  BEQ bra_EA2B
  CMP #$05
  BNE bra_EA43_RTS
bra_EA2B
  LDA ram_btn_hold
  AND #con_btns_UD
  BEQ bra_EA43_RTS
  AND #con_btn_Down
  BNE bra_EA39
  LDA #$01
  BNE bra_EA3B    ; jmp
bra_EA39
  LDA #$FF
bra_EA3B
  STA ram_00DC_obj
  LDA #$04
  ORA ram_00FD
  STA ram_00FD
bra_EA43_RTS
  RTS



sub_EA44
  LDX #$03
bra_EA46_loop
  TXA
  ASL
  ASL
  ASL
  TAY
  LDA ram_0084_obj,X
  LSR
  BCC bra_EA58
  LDA ram_0080_obj,X
  CMP #$F4
  BCC bra_EA61
  BCS bra_EA88    ; jmp
bra_EA58
  LSR
  BCS bra_EA88
  LDA ram_0080_obj,X
  CMP #$F6
  BCC bra_EA88
bra_EA61
  LDA ram_00B0_obj,X
  BEQ bra_EA88
  LDA #$B6
  JSR sub_DC9A
  STA ram_spr_Y + $94,Y
  LDA ram_0080_obj,X
  CLC
  ADC #$0A
  STA ram_spr_X + $94,Y
  STY ram_0001
  LDY ram_00B4_obj,X
  LDA tbl_E69A,Y
  LDY ram_0001
  STA ram_spr_T + $94,Y
  LDA #$00
  STA ram_spr_A + $94,Y
  BEQ bra_EA8B    ; jmp
bra_EA88
  JSR sub_E2F6
bra_EA8B
  DEX
  BPL bra_EA46_loop
  RTS



ofs_002_EA8F_08
  CPX #$00
  BNE bra_EAC4_RTS
  LDA #$1D
  STA ram_003A_timer
  LDA ram_0057
  BEQ bra_EAB5
  LDA ram_003C_timer
  BNE bra_EAC0
  STX ram_000D
  LDX #$06
  LDY #$19
bra_EAA5_loop
  LDA ram_03D9,X
  STA ram_spr_Y + $C0,Y
  DEY
  DEY
  DEY
  DEY
  DEX
  BPL bra_EAA5_loop
  LDX ram_000D
  RTS
bra_EAB5
  LDA #$10
  STA ram_0032_timer
  LDA #$02
  STA ram_00FD
  LSR ; 01
  STA ram_0052_track_finished_flag
bra_EAC0
  LDA #$00
  STA ram_003A_timer
bra_EAC4_RTS
  RTS



sub_EAC5
  LDA ram_0052_track_finished_flag
  ORA ram_003C_timer
  BNE bra_EAC0
  LDA ram_003A_timer
  BEQ bra_EAC4_RTS
  LDX #$00
  LDY #$03
  LDA ram_003A_timer
  CMP #$0D
  BCC bra_EAE0
  LSR
  BCC bra_EB16_RTS
  LDA #$40
  STA ram_00FB
bra_EAE0
bra_EAE0_loop
  LDA #$42
  STA ram_spr_Y + $B4,X
  INX
  LDA tbl_E540_spr_T,Y
  STA ram_spr_T + $B4 - $01,X
  INX
  LDA #$00
  STA ram_spr_A + $B4 - $02,X
  INX
  LDA tbl_E543_spr_X,Y
  STA ram_spr_X + $B4 - $03,X
  INX
  DEY
  BNE bra_EAE0_loop
  LDX #$06
bra_EAFF_loop
  LDA #$4A
  STA ram_spr_Y + $C0,Y
  INY
  INY
  LDA #$00
  STA ram_spr_A + $C0 - $02,Y
  INY
  LDA tbl_E547_spr_X,X
  STA ram_spr_X + $C0 - $03,Y
  INY
  DEX
  BPL bra_EAFF_loop
bra_EB16_RTS
  RTS



sub_EB17
  LDA ram_00BC_obj + $02
  BNE bra_EB7E_RTS
  LDA ram_00B4_obj
  BEQ bra_EB23
  DEC ram_00B4_obj
  BNE bra_EB5E
bra_EB23
  LDA ram_00BC_obj + $01
  ORA ram_obj_pos_Y_lo + $01
  BNE bra_EB5E
  STA ram_0060
  STA ram_00C0_obj
  LDA ram_00BC_obj + $03
  BEQ bra_EB35
  CMP #$01
  BNE bra_EB9E
bra_EB35
  LDA ram_00C0_obj + $01
  CMP #$02
  BEQ bra_EB5E
  LDA ram_00C0_obj + $01
  BEQ bra_EB49
  LDA #$09
  STA ram_obj_pos_Y_lo
bra_EB43
  LDA #$02
  STA ram_00C0_obj + $01
  BNE bra_EB93    ; jmp
bra_EB49
  LDA ram_00BC_obj + $03
  BNE bra_EB5E
  LDA ram_005C_obj
  ASL
  BCC bra_EB7F
  LDA #$00
  STA ram_0049
  LDA ram_002A_timer + $01
  BNE bra_EB9D_RTS
  LDA #$05
  STA ram_002A_timer + $01
bra_EB5E
  LDA #$04
  STA ram_0060
  JSR sub_EC99
  LDY ram_00B0_obj + $03
  LDA #$00
  STA ram_00BC_obj + $01
  JSR sub_ECC9
  BNE bra_EB7C
  INY
  CPY #$40
  BNE bra_EB77
  LDY #$00
bra_EB77
  JSR sub_ECC9
  BEQ bra_EB9D_RTS
bra_EB7C
  INC ram_00BC_obj + $01
bra_EB7E_RTS
  RTS
bra_EB7F
  ASL
  BCC bra_EBF6
  LDA ram_0049
  BNE bra_EB9D_RTS
  JSR sub_EC75
  LDA ram_obj_pos_Y_lo
  CMP #$FF
  BEQ bra_EB9D_RTS
  CMP #$09
  BEQ bra_EB43
bra_EB93
  LDA #$01
  STA ram_00BC_obj + $02
  STA ram_0049
  LDA #$40
  STA ram_00FB
bra_EB9D_RTS
  RTS
bra_EB9E
  LDA ram_0049
  BNE bra_EBB6
  LDA ram_005C_obj
  ASL
  ASL
  BCC bra_EBBD
  JSR sub_C3B1
  JSR sub_EC3B
  STX ram_0047
  STX ram_0042
  LDA #$08
  STA ram_0041
bra_EBB6
  LDA ram_005C_obj
  BNE bra_EBBC_RTS
  STA ram_0049
bra_EBBC_RTS
  RTS
bra_EBBD
  JSR sub_EC5D
  LDA ram_003A_timer
  BNE bra_EBBC_RTS
  INC ram_003A_timer
  LDA ram_005C_obj
  CMP #$80
  BEQ bra_EBD0
  CMP #$08
  BNE bra_EBE9
bra_EBD0
  INC ram_05E0
  LDA ram_05E0
  CMP #$0A
  BMI bra_EBDF
  LDA #$01
bra_EBDC
  STA ram_05E0
bra_EBDF
  LDA #$01
  STA ram_00FF
  LSR ; 00
  STA ram_0049
  JMP loc_EC47
bra_EBE9
  CMP #$04
  BNE bra_EBB6
  DEC ram_05E0
  BNE bra_EBDF
  LDA #$09
  BNE bra_EBDC    ; jmp
bra_EBF6
  LDA ram_002A_timer + $02
  BNE bra_EC3A_RTS
  LDA #$08
  STA ram_002A_timer + $02
  LDA ram_005C_obj
  LSR
  BCS bra_EC10
  LSR
  BCC bra_EC3A_RTS
  DEC ram_00C0_obj + $02
  LDA ram_00C0_obj + $02
  BPL bra_EC1C
  LDA #$14
  BNE bra_EC1A    ; jmp
bra_EC10
  INC ram_00C0_obj + $02
  LDA ram_00C0_obj + $02
  CMP #$15
  BCC bra_EC1C
  LDA #$00
bra_EC1A
  STA ram_00C0_obj + $02
bra_EC1C
  LDA #$01
  STA ram_00FF
  LSR ; 00
  STA ram_0049
  LDA #$D0
sub_EC25
  STA ram_spr_Y + $30
  LDA #$CA
  STA ram_spr_T + $30
  LDA #$00
  STA ram_spr_A + $30
  LDX ram_00C0_obj + $02
  LDA tbl_E6F6_spr_X,X
  STA ram_spr_X + $30
bra_EC3A_RTS
  RTS



sub_EC3B
  LDX #$00
bra_EC3D_loop
  LDA ram_05E0,X
  STA ram_06E0,X
  DEX
  BNE bra_EC3D_loop
  RTS



loc_EC47
  LDA #$CF
  STA ram_spr_Y + $34
  LDA ram_05E0
  STA ram_spr_T + $34
  LDA #$00
  STA ram_spr_A + $34
  LDA #$E4
  STA ram_spr_X + $34
  RTS



sub_EC5D
  LDA #$F8
  JSR sub_EC25
  LDA ram_003F
  AND #$10
  BEQ bra_EC6C
  LDA #$F8
  BNE bra_EC6E    ; jmp
bra_EC6C
  LDA #$C7
bra_EC6E
  STA ram_spr_Y + $28
  STA ram_spr_Y + $2C
  RTS



sub_EC75
  LDA #$00
  STA ram_obj_pos_X_lo + $02
  STA ram_obj_pos_X_lo
  STA ram_obj_pos_X_lo + $01
  LDA ram_00B0_obj + $02
  STA ram_obj_pos_Y_lo + $02
  LDA ram_00B0_obj
  STA ram_obj_pos_Y_lo + $03
  LDA ram_00B0_obj + $01
  STA ram_00BC_obj
  LDY ram_00C0_obj + $02
  LDA tbl_E6E1,Y
  STA ram_obj_pos_Y_lo
  CMP #$11
  BCC bra_EC98_RTS
  AND #$0F
  STA ram_obj_pos_X_lo
bra_EC98_RTS
  RTS



sub_EC99
  LDA ram_0060
  BEQ bra_EC98_RTS
  CLC
  ADC ram_obj_pos_Y_lo + $01
  STA ram_obj_pos_Y_lo + $01
  CMP #$08
  BNE bra_EC98_RTS
  LDA #$01
  STA ram_00C0_obj
  LSR ; 00
  STA ram_obj_pos_Y_lo + $01
  JSR sub_F6FB
  LDA ram_00B0_obj + $02
  JSR sub_ECBF
  STA ram_00B0_obj + $02
  LDA ram_00B0_obj + $03
  JSR sub_ECBF
  STA ram_00B0_obj + $03
  RTS



sub_ECBF
  CLC
  ADC #$01
  CMP #$40
  BNE bra_ECC8_RTS
bra_ECC6
  LDA #$00
bra_ECC8_RTS
  RTS



sub_ECC9
  LDA #$3D
  CMP ram_0540,Y
  BNE bra_ECE1
  CMP ram_0480,Y
  BNE bra_ECE1
  LDA #$3B
  CMP ram_0400,Y
  BNE bra_ECE1
  CMP ram_04C0,Y
  BEQ bra_ECC6
bra_ECE1
  LDA #$01
  RTS



sub_ECE4
loc_ECE4
  LDY #$03
bra_ECE6_loop
  LDA tbl_E6A1,X
  INX
;  STA ram_0002,Y
  JSR STA_ram_0002_Y
  DEY
  BPL bra_ECE6_loop
  LDA ram_0005
  STA ram_0400
  LDA ram_0002
  STA ram_0401
  LDX #$20
  STX ram_0402
bra_ECFF_loop
  LDA ram_0003
  STA ram_0403,X
  DEX
  LDA ram_0004
; bzk bug? this refers to 0502 if X = FF
  STA ram_0403,X
  DEX
  BPL bra_ECFF_loop
  LDA ram_0005
  EOR #$04
  STA ram_0423
  LDA ram_0002
  STA ram_0424
  LDX #$20
  STX ram_0425
bra_ED1E_loop
  LDA ram_0003
  STA ram_0426,X
  DEX
  LDA ram_0004
; bzk bug? this refers to 0525 if X = FF
  STA ram_0426,X
  DEX
  BPL bra_ED1E_loop
  LDA #$00
  STA ram_0446
  LDA #< ram_0400
  STA ram_0000
  LDA #> ram_0400
  JMP loc_C289



tbl_ED3A_lo
  db < _off_003_ED46_00   ; 
  db < _off_003_EE59_01   ; 
  db < _off_003_EDC8_02   ; 
  db < _off_003_EED2_03   ; 
  db < _off_003_EFA7_04   ; 
  db < ram_06E0   ; 



tbl_ED40_hi
  db > _off_003_ED46_00   ; 
  db > _off_003_EE59_01   ; 
  db > _off_003_EDC8_02   ; 
  db > _off_003_EED2_03   ; 
  db > _off_003_EFA7_04   ; 
  db > ram_06E0   ; 



_off_003_ED46_00
  db $02   ; 
  db $40   ; 
  db $10   ; 
  db $30   ; 
  db $40   ; 
  db $36   ; 
  db $0D   ; 
  db $31   ; 
  db $40   ; 
  db $07   ; 
  db $05   ; 
  db $40   ; 
  db $02   ; 
  db $88   ; 
  db $40   ; 
  db $02   ; 
  db $88   ; 
  db $40   ; 
  db $1C   ; 
  db $07   ; 
  db $40   ; 
  db $25   ; 
  db $10   ; 
  db $40   ; 
  db $0A   ; 
  db $07   ; 
  db $40   ; 
  db $02   ; 
  db $07   ; 
  db $40   ; 
  db $02   ; 
  db $8D   ; 
  db $40   ; 
  db $39   ; 
  db $07   ; 
  db $40   ; 
  db $02   ; 
  db $07   ; 
  db $40   ; 
  db $02   ; 
  db $07   ; 
  db $40   ; 
  db $0E   ; 
  db $0F   ; 
  db $40   ; 
  db $10   ; 
  db $0C   ; 
  db $40   ; 
  db $10   ; 
  db $06   ; 
  db $40   ; 
  db $05   ; 
  db $0A   ; 
  db $40   ; 
  db $2B   ; 
  db $0E   ; 
  db $40   ; 
  db $1E   ; 
  db $0F   ; 
  db $40   ; 
  db $02   ; 
  db $0E   ; 
  db $40   ; 
  db $26   ; 
  db $0E   ; 
  db $40   ; 
  db $02   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $88   ; 
  db $40   ; 
  db $12   ; 
  db $06   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $0A   ; 
  db $17   ; 
  db $40   ; 
  db $14   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $81   ; 
  db $40   ; 
  db $02   ; 
  db $81   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $11   ; 
  db $30   ; 
  db $8D   ; 
  db $40   ; 
  db $0A   ; 
  db $0C   ; 
  db $40   ; 
  db $0B   ; 
  db $0D   ; 
  db $40   ; 
  db $03   ; 
  db $8D   ; 
  db $40   ; 
  db $09   ; 
  db $8C   ; 
  db $40   ; 
  db $02   ; 
  db $0C   ; 
  db $40   ; 
  db $0E   ; 
  db $31   ; 
  db $09   ; 



_off_003_EDC8_02
  db $02   ; 
  db $40   ; 
  db $0F   ; 
  db $30   ; 
  db $40   ; 
  db $34   ; 
  db $03   ; 
  db $40   ; 
  db $07   ; 
  db $04   ; 
  db $40   ; 
  db $0C   ; 
  db $03   ; 
  db $40   ; 
  db $0A   ; 
  db $04   ; 
  db $40   ; 
  db $0E   ; 
  db $03   ; 
  db $40   ; 
  db $06   ; 
  db $83   ; 
  db $40   ; 
  db $09   ; 
  db $04   ; 
  db $40   ; 
  db $06   ; 
  db $84   ; 
  db $40   ; 
  db $0A   ; 
  db $31   ; 
  db $07   ; 
  db $40   ; 
  db $04   ; 
  db $07   ; 
  db $40   ; 
  db $05   ; 
  db $8B   ; 
  db $40   ; 
  db $0E   ; 
  db $06   ; 
  db $40   ; 
  db $09   ; 
  db $0A   ; 
  db $40   ; 
  db $07   ; 
  db $0F   ; 
  db $40   ; 
  db $02   ; 
  db $10   ; 
  db $40   ; 
  db $07   ; 
  db $06   ; 
  db $40   ; 
  db $02   ; 
  db $0B   ; 
  db $40   ; 
  db $02   ; 
  db $0A   ; 
  db $40   ; 
  db $0B   ; 
  db $84   ; 
  db $40   ; 
  db $0B   ; 
  db $13   ; 
  db $43   ; 
  db $37   ; 
  db $1B   ; 
  db $40   ; 
  db $18   ; 
  db $83   ; 
  db $40   ; 
  db $0A   ; 
  db $0E   ; 
  db $40   ; 
  db $09   ; 
  db $07   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $16   ; 
  db $17   ; 
  db $40   ; 
  db $0F   ; 
  db $0E   ; 
  db $40   ; 
  db $0B   ; 
  db $05   ; 
  db $40   ; 
  db $05   ; 
  db $87   ; 
  db $40   ; 
  db $09   ; 
  db $03   ; 
  db $40   ; 
  db $0E   ; 
  db $05   ; 
  db $40   ; 
  db $06   ; 
  db $0A   ; 
  db $40   ; 
  db $06   ; 
  db $06   ; 
  db $40   ; 
  db $05   ; 
  db $05   ; 
  db $40   ; 
  db $0F   ; 
  db $0F   ; 
  db $40   ; 
  db $0B   ; 
  db $30   ; 
  db $13   ; 
  db $43   ; 
  db $37   ; 
  db $1B   ; 
  db $40   ; 
  db $0D   ; 
  db $12   ; 
  db $42   ; 
  db $2A   ; 
  db $19   ; 
  db $40   ; 
  db $11   ; 
  db $04   ; 
  db $40   ; 
  db $02   ; 
  db $8C   ; 
  db $40   ; 
  db $06   ; 
  db $0D   ; 
  db $40   ; 
  db $05   ; 
  db $0C   ; 
  db $40   ; 
  db $05   ; 
  db $03   ; 
  db $40   ; 
  db $02   ; 
  db $8D   ; 
  db $40   ; 
  db $15   ; 
  db $31   ; 
  db $09   ; 



_off_003_EE59_01
  db $02   ; 
  db $40   ; 
  db $0F   ; 
  db $30   ; 
  db $40   ; 
  db $33   ; 
  db $31   ; 
  db $15   ; 
  db $41   ; 
  db $06   ; 
  db $21   ; 
  db $45   ; 
  db $06   ; 
  db $23   ; 
  db $40   ; 
  db $0A   ; 
  db $07   ; 
  db $40   ; 
  db $06   ; 
  db $87   ; 
  db $40   ; 
  db $08   ; 
  db $0C   ; 
  db $40   ; 
  db $0B   ; 
  db $15   ; 
  db $41   ; 
  db $06   ; 
  db $21   ; 
  db $45   ; 
  db $06   ; 
  db $23   ; 
  db $40   ; 
  db $03   ; 
  db $87   ; 
  db $40   ; 
  db $0C   ; 
  db $0F   ; 
  db $40   ; 
  db $02   ; 
  db $10   ; 
  db $40   ; 
  db $0F   ; 
  db $07   ; 
  db $40   ; 
  db $0B   ; 
  db $07   ; 
  db $40   ; 
  db $26   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $0B   ; 
  db $40   ; 
  db $02   ; 
  db $88   ; 
  db $40   ; 
  db $24   ; 
  db $0E   ; 
  db $40   ; 
  db $02   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $0A   ; 
  db $17   ; 
  db $40   ; 
  db $02   ; 
  db $0E   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $0E   ; 
  db $17   ; 
  db $40   ; 
  db $15   ; 
  db $10   ; 
  db $40   ; 
  db $06   ; 
  db $81   ; 
  db $40   ; 
  db $02   ; 
  db $81   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $17   ; 
  db $30   ; 
  db $13   ; 
  db $43   ; 
  db $37   ; 
  db $1B   ; 
  db $40   ; 
  db $1F   ; 
  db $0C   ; 
  db $40   ; 
  db $0E   ; 
  db $0D   ; 
  db $40   ; 
  db $04   ; 
  db $8D   ; 
  db $40   ; 
  db $05   ; 
  db $0C   ; 
  db $40   ; 
  db $1B   ; 
  db $31   ; 
  db $09   ; 



_off_003_EED2_03
  db $02   ; 
  db $40   ; 
  db $10   ; 
  db $30   ; 
  db $40   ; 
  db $50   ; 
  db $31   ; 
  db $14   ; 
  db $44   ; 
  db $03   ; 
  db $1E   ; 
  db $44   ; 
  db $04   ; 
  db $1E   ; 
  db $44   ; 
  db $04   ; 
  db $1F   ; 
  db $1B   ; 
  db $40   ; 
  db $0F   ; 
  db $0D   ; 
  db $40   ; 
  db $05   ; 
  db $83   ; 
  db $40   ; 
  db $03   ; 
  db $0C   ; 
  db $40   ; 
  db $09   ; 
  db $14   ; 
  db $44   ; 
  db $03   ; 
  db $1E   ; 
  db $44   ; 
  db $04   ; 
  db $1E   ; 
  db $44   ; 
  db $04   ; 
  db $1F   ; 
  db $1B   ; 
  db $40   ; 
  db $04   ; 
  db $07   ; 
  db $40   ; 
  db $02   ; 
  db $87   ; 
  db $40   ; 
  db $02   ; 
  db $87   ; 
  db $40   ; 
  db $09   ; 
  db $03   ; 
  db $40   ; 
  db $04   ; 
  db $84   ; 
  db $40   ; 
  db $05   ; 
  db $04   ; 
  db $40   ; 
  db $07   ; 
  db $83   ; 
  db $40   ; 
  db $05   ; 
  db $10   ; 
  db $40   ; 
  db $0C   ; 
  db $8A   ; 
  db $40   ; 
  db $0C   ; 
  db $07   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $0A   ; 
  db $17   ; 
  db $40   ; 
  db $19   ; 
  db $0E   ; 
  db $40   ; 
  db $0D   ; 
  db $0E   ; 
  db $40   ; 
  db $04   ; 
  db $0B   ; 
  db $40   ; 
  db $04   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $88   ; 
  db $40   ; 
  db $1A   ; 
  db $03   ; 
  db $40   ; 
  db $06   ; 
  db $83   ; 
  db $40   ; 
  db $03   ; 
  db $04   ; 
  db $40   ; 
  db $08   ; 
  db $0E   ; 
  db $40   ; 
  db $04   ; 
  db $0B   ; 
  db $40   ; 
  db $02   ; 
  db $0B   ; 
  db $40   ; 
  db $02   ; 
  db $0B   ; 
  db $40   ; 
  db $02   ; 
  db $8B   ; 
  db $40   ; 
  db $02   ; 
  db $8B   ; 
  db $40   ; 
  db $21   ; 
  db $0F   ; 
  db $40   ; 
  db $0C   ; 
  db $0D   ; 
  db $40   ; 
  db $02   ; 
  db $88   ; 
  db $40   ; 
  db $02   ; 
  db $13   ; 
  db $43   ; 
  db $17   ; 
  db $1B   ; 
  db $40   ; 
  db $06   ; 
  db $12   ; 
  db $42   ; 
  db $17   ; 
  db $19   ; 
  db $40   ; 
  db $03   ; 
  db $03   ; 
  db $40   ; 
  db $08   ; 
  db $05   ; 
  db $40   ; 
  db $02   ; 
  db $05   ; 
  db $40   ; 
  db $02   ; 
  db $05   ; 
  db $40   ; 
  db $02   ; 
  db $05   ; 
  db $40   ; 
  db $02   ; 
  db $05   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $0A   ; 
  db $30   ; 
  db $17   ; 
  db $40   ; 
  db $11   ; 
  db $10   ; 
  db $40   ; 
  db $0E   ; 
  db $0C   ; 
  db $40   ; 
  db $06   ; 
  db $8C   ; 
  db $40   ; 
  db $09   ; 
  db $0D   ; 
  db $40   ; 
  db $02   ; 
  db $8D   ; 
  db $40   ; 
  db $0C   ; 
  db $0C   ; 
  db $40   ; 
  db $05   ; 
  db $0D   ; 
  db $40   ; 
  db $06   ; 
  db $8C   ; 
  db $40   ; 
  db $02   ; 
  db $0C   ; 
  db $40   ; 
  db $07   ; 
  db $8D   ; 
  db $40   ; 
  db $05   ; 
  db $0C   ; 
  db $40   ; 
  db $04   ; 
  db $0D   ; 
  db $40   ; 
  db $07   ; 
  db $8C   ; 
  db $40   ; 
  db $02   ; 
  db $31   ; 
  db $0E   ; 
  db $40   ; 
  db $05   ; 
  db $09   ; 



_off_003_EFA7_04
  db $02   ; 
  db $40   ; 
  db $10   ; 
  db $30   ; 
  db $40   ; 
  db $32   ; 
  db $0F   ; 
  db $40   ; 
  db $0F   ; 
  db $0C   ; 
  db $40   ; 
  db $08   ; 
  db $31   ; 
  db $0E   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $0E   ; 
  db $17   ; 
  db $40   ; 
  db $02   ; 
  db $0A   ; 
  db $40   ; 
  db $06   ; 
  db $15   ; 
  db $41   ; 
  db $06   ; 
  db $21   ; 
  db $45   ; 
  db $06   ; 
  db $23   ; 
  db $40   ; 
  db $02   ; 
  db $08   ; 
  db $40   ; 
  db $03   ; 
  db $08   ; 
  db $40   ; 
  db $03   ; 
  db $08   ; 
  db $40   ; 
  db $03   ; 
  db $88   ; 
  db $40   ; 
  db $03   ; 
  db $88   ; 
  db $40   ; 
  db $09   ; 
  db $83   ; 
  db $40   ; 
  db $05   ; 
  db $04   ; 
  db $40   ; 
  db $08   ; 
  db $10   ; 
  db $40   ; 
  db $11   ; 
  db $0D   ; 
  db $40   ; 
  db $13   ; 
  db $0C   ; 
  db $40   ; 
  db $14   ; 
  db $0E   ; 
  db $40   ; 
  db $13   ; 
  db $05   ; 
  db $40   ; 
  db $04   ; 
  db $05   ; 
  db $40   ; 
  db $05   ; 
  db $05   ; 
  db $40   ; 
  db $04   ; 
  db $06   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $0A   ; 
  db $17   ; 
  db $40   ; 
  db $05   ; 
  db $0C   ; 
  db $40   ; 
  db $03   ; 
  db $14   ; 
  db $44   ; 
  db $03   ; 
  db $1E   ; 
  db $44   ; 
  db $04   ; 
  db $1E   ; 
  db $44   ; 
  db $04   ; 
  db $1F   ; 
  db $1B   ; 
  db $40   ; 
  db $06   ; 
  db $07   ; 
  db $40   ; 
  db $03   ; 
  db $83   ; 
  db $40   ; 
  db $04   ; 
  db $0E   ; 
  db $40   ; 
  db $17   ; 
  db $8A   ; 
  db $40   ; 
  db $03   ; 
  db $0E   ; 
  db $40   ; 
  db $02   ; 
  db $11   ; 
  db $46   ; 
  db $05   ; 
  db $17   ; 
  db $40   ; 
  db $02   ; 
  db $0B   ; 
  db $40   ; 
  db $06   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $08   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $01   ; 
  db $40   ; 
  db $02   ; 
  db $05   ; 
  db $40   ; 
  db $21   ; 
  db $30   ; 
  db $0C   ; 
  db $40   ; 
  db $04   ; 
  db $83   ; 
  db $40   ; 
  db $04   ; 
  db $0D   ; 
  db $40   ; 
  db $04   ; 
  db $04   ; 
  db $40   ; 
  db $08   ; 
  db $8C   ; 
  db $40   ; 
  db $02   ; 
  db $03   ; 
  db $40   ; 
  db $05   ; 
  db $8D   ; 
  db $40   ; 
  db $02   ; 
  db $0D   ; 
  db $40   ; 
  db $06   ; 
  db $0C   ; 
  db $40   ; 
  db $03   ; 
  db $8C   ; 
  db $40   ; 
  db $05   ; 
  db $0D   ; 
  db $40   ; 
  db $06   ; 
  db $04   ; 
  db $40   ; 
  db $05   ; 
  db $31   ; 
  db $09   ; 



tbl_F063_lo
  db < _off_004_F0AB_00   ; 
  db < _off_004_F0B3_01   ; 
  db < _off_004_F101_02   ; 
  db < _off_004_F101_03   ; 
  db < _off_004_F10A_04   ; 
  db < _off_004_F112_05   ; 
  db < _off_004_F16B_06   ; 
  db < _off_004_F1A4_07   ; 
  db < _off_004_F1D1_08   ; 
  db < _off_004_F1EB_09   ; 
  db < _off_004_F25E_0A   ; 
  db < _off_004_F297_0B   ; 
  db < _off_004_F2E2_0C   ; 
  db < _off_004_F2CC_0D   ; 
  db < _off_004_F4B4_0E   ; 
  db < _off_004_F496_0F   ; 
  db < _off_004_F4A5_10   ; 
  db < _off_004_F456_11   ; 
  db < _off_004_F32D_12   ; 
  db < _off_004_F335_13   ; 
  db < _off_004_F35D_14   ; 
  db < _off_004_F2F8_15   ; 
  db < _off_004_F45E_16   ; 
  db < _off_004_F466_17   ; 
  db < _off_004_F34D_18   ; 
  db < _off_004_F33D_19   ; 
  db < _off_004_F355_1A   ; 
  db < _off_004_F345_1B   ; 
  db < _off_004_F3C0_1C   ; 
  db < _off_004_F46E_1D   ; 
  db < _off_004_F46E_1E   ; 
  db < _off_004_F3CE_1F   ; 
  db < _off_004_F30A_20   ; 
  db < _off_004_F314_21   ; 
  db < _off_004_F3DC_22   ; 
  db < _off_004_F3EA_23   ; 



tbl_F087_hi
  db > _off_004_F0AB_00   ; 
  db > _off_004_F0B3_01   ; 
  db > _off_004_F101_02   ; 
  db > _off_004_F101_03   ; 
  db > _off_004_F10A_04   ; 
  db > _off_004_F112_05   ; 
  db > _off_004_F16B_06   ; 
  db > _off_004_F1A4_07   ; 
  db > _off_004_F1D1_08   ; 
  db > _off_004_F1EB_09   ; 
  db > _off_004_F25E_0A   ; 
  db > _off_004_F297_0B   ; 
  db > _off_004_F2E2_0C   ; 
  db > _off_004_F2CC_0D   ; 
  db > _off_004_F4B4_0E   ; 
  db > _off_004_F496_0F   ; 
  db > _off_004_F4A5_10   ; 
  db > _off_004_F456_11   ; 
  db > _off_004_F32D_12   ; 
  db > _off_004_F335_13   ; 
  db > _off_004_F35D_14   ; 
  db > _off_004_F2F8_15   ; 
  db > _off_004_F45E_16   ; 
  db > _off_004_F466_17   ; 
  db > _off_004_F34D_18   ; 
  db > _off_004_F33D_19   ; 
  db > _off_004_F355_1A   ; 
  db > _off_004_F345_1B   ; 
  db > _off_004_F3C0_1C   ; 
  db > _off_004_F46E_1D   ; 
  db > _off_004_F46E_1E   ; 
  db > _off_004_F3CE_1F   ; 
  db > _off_004_F30A_20   ; 
  db > _off_004_F314_21   ; 
  db > _off_004_F3DC_22   ; 
  db > _off_004_F3EA_23   ; 



_off_004_F0AB_00
  db $09   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $00   ; 



_off_004_F0B3_01
  db $08   ; 
  db $D7   ; 
tbl_F0B5_40    ; for BIT instruction, bzk optimize, same as 0x00270B
  db $40   ; 
  db $40   ; 
  db $40   ; 
  db $40   ; 
  db $40   ; 
  db $41   ; 
  db $08   ; 
  db $D6   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $D8   ; 
  db $07   ; 
  db $D7   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $D9   ; 
  db $FE   ; 
  db $07   ; 
  db $D6   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $D8   ; 
  db $FE   ; 
  db $07   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $DA   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $DC   ; 
  db $FE   ; 
  db $07   ; 
  db $DB   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $DD   ; 
  db $FE   ; 
  db $08   ; 
  db $DA   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $DC   ; 
  db $08   ; 
  db $DB   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $DD   ; 
  db $00   ; 



_off_004_F101_02
_off_004_F101_03
  db $08   ; 
  db $E0   ; 
  db $48   ; 
  db $49   ; 
  db $4A   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $00   ; 



_off_004_F10A_04
  db $09   ; 
  db $3B   ; 
  db $3C   ; 
  db $E1   ; 
  db $48   ; 
  db $49   ; 
  db $4A   ; 
  db $00   ; 



_off_004_F112_05
  db $08   ; 
  db $C5   ; 
  db $50   ; 
  db $50   ; 
  db $50   ; 
  db $50   ; 
  db $50   ; 
  db $51   ; 
  db $07   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $06   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $FE   ; 
  db $05   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $04   ; 
  db $2F   ; 
  db $2E   ; 
  db $2B   ; 
  db $2D   ; 
  db $2C   ; 
  db $2B   ; 
  db $2A   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $05   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $06   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $08   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $00   ; 



_off_004_F16B_06
  db $08   ; 
  db $C5   ; 
  db $5E   ; 
  db $5E   ; 
  db $5E   ; 
  db $5E   ; 
  db $5E   ; 
  db $5F   ; 
  db $07   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $06   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $FE   ; 
  db $05   ; 
  db $2F   ; 
  db $2E   ; 
  db $2B   ; 
  db $2D   ; 
  db $2C   ; 
  db $2B   ; 
  db $2A   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $06   ; 
  db $D1   ; 
  db $D2   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $D3   ; 
  db $D4   ; 
  db $FE   ; 
  db $08   ; 
  db $D1   ; 
  db $D0   ; 
  db $D0   ; 
  db $D0   ; 
  db $D0   ; 
  db $D0   ; 
  db $D5   ; 
  db $00   ; 



_off_004_F1A4_07
  db $08   ; 
  db $C5   ; 
  db $56   ; 
  db $56   ; 
  db $56   ; 
  db $56   ; 
  db $56   ; 
  db $57   ; 
  db $07   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $06   ; 
  db $2F   ; 
  db $2E   ; 
  db $2B   ; 
  db $2D   ; 
  db $2E   ; 
  db $2B   ; 
  db $2A   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $08   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $00   ; 



_off_004_F1D1_08
  db $08   ; 
  db $C5   ; 
  db $58   ; 
  db $58   ; 
  db $58   ; 
  db $58   ; 
  db $58   ; 
  db $59   ; 
  db $07   ; 
  db $2F   ; 
  db $2E   ; 
  db $2B   ; 
  db $2D   ; 
  db $2C   ; 
  db $2B   ; 
  db $2A   ; 
  db $FE   ; 
  db $08   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $00   ; 



_off_004_F1EB_09
  db $08   ; 
  db $C5   ; 
  db $4E   ; 
  db $4E   ; 
  db $4E   ; 
  db $4E   ; 
  db $4E   ; 
  db $4F   ; 
  db $07   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $06   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $FE   ; 
  db $06   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $0F   ; 
  db $FE   ; 
  db $06   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $12   ; 
  db $FE   ; 
  db $06   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $17   ; 
  db $FE   ; 
  db $06   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $12   ; 
  db $FE   ; 
  db $06   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $1C   ; 
  db $FE   ; 
  db $06   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $11   ; 
  db $FE   ; 
  db $06   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $08   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $00   ; 



_off_004_F25E_0A
  db $08   ; 
  db $CC   ; 
  db $60   ; 
  db $60   ; 
  db $60   ; 
  db $60   ; 
  db $60   ; 
  db $61   ; 
  db $06   ; 
  db $CC   ; 
  db $CD   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $CE   ; 
  db $CF   ; 
  db $FE   ; 
  db $05   ; 
  db $2F   ; 
  db $2E   ; 
  db $2B   ; 
  db $2D   ; 
  db $2C   ; 
  db $2B   ; 
  db $2A   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $06   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $08   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $00   ; 



_off_004_F297_0B
  db $07   ; 
  db $CC   ; 
  db $CD   ; 
  db $65   ; 
  db $65   ; 
  db $65   ; 
  db $65   ; 
  db $66   ; 
  db $67   ; 
  db $05   ; 
  db $CC   ; 
  db $CD   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $CE   ; 
  db $CF   ; 
  db $FE   ; 
  db $FE   ; 
  db $04   ; 
  db $2F   ; 
  db $2E   ; 
  db $2B   ; 
  db $2D   ; 
  db $2C   ; 
  db $2B   ; 
  db $2A   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $05   ; 
  db $D1   ; 
  db $D2   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $D3   ; 
  db $D4   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $D1   ; 
  db $D2   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $FF   ; 
  db $D3   ; 
  db $D4   ; 
  db $00   ; 



_off_004_F2CC_0D
  db $09   ; 
  db $3B   ; 
  db $E7   ; 
  db $72   ; 
  db $3B   ; 
  db $E7   ; 
  db $72   ; 
  db $09   ; 
  db $3B   ; 
  db $E8   ; 
  db $BB   ; 
  db $3B   ; 
  db $E8   ; 
  db $BB   ; 
  db $09   ; 
  db $3B   ; 
  db $E9   ; 
  db $BE   ; 
  db $3B   ; 
  db $E9   ; 
  db $BB   ; 
  db $00   ; 



_off_004_F2E2_0C
  db $09   ; 
  db $70   ; 
  db $EA   ; 
  db $3D   ; 
  db $70   ; 
  db $EA   ; 
  db $3D   ; 
  db $09   ; 
  db $B9   ; 
  db $EB   ; 
  db $3D   ; 
  db $B9   ; 
  db $EB   ; 
  db $3D   ; 
  db $09   ; 
  db $BC   ; 
  db $EC   ; 
  db $3D   ; 
  db $BC   ; 
  db $EC   ; 
  db $3D   ; 
  db $00   ; 



_off_004_F2F8_15
  db $08   ; 
  db $C5   ; 
  db $68   ; 
  db $68   ; 
  db $68   ; 
  db $68   ; 
  db $68   ; 
  db $69   ; 
  db $07   ; 
  db $C5   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $C6   ; 
  db $FE   ; 
  db $00   ; 



_off_004_F30A_20
  db $07   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $FE   ; 
  db $00   ; 



_off_004_F314_21
  db $05   ; 
  db $CC   ; 
  db $CD   ; 
  db $FE   ; 
  db $FE   ; 
  db $6D   ; 
  db $6D   ; 
  db $6E   ; 
  db $6F   ; 
  db $6D   ; 
  db $6D   ; 
  db $03   ; 
  db $CC   ; 
  db $CD   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $CE   ; 
  db $CF   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $00   ; 



_off_004_F32D_12
  db $09   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $C0   ; 
  db $C0   ; 
  db $C0   ; 
  db $00   ; 



_off_004_F335_13
  db $09   ; 
  db $C0   ; 
  db $C0   ; 
  db $C0   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $00   ; 



_off_004_F33D_19
  db $09   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $C3   ; 
  db $C3   ; 
  db $C3   ; 
  db $00   ; 



_off_004_F345_1B
  db $09   ; 
  db $C3   ; 
  db $C3   ; 
  db $C3   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $00   ; 



_off_004_F34D_18
  db $09   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $E4   ; 
  db $E4   ; 
  db $E4   ; 
  db $00   ; 



_off_004_F355_1A
  db $09   ; 
  db $E4   ; 
  db $E4   ; 
  db $E4   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $00   ; 



_off_004_F35D_14
  db $07   ; 
  db $CC   ; 
  db $CD   ; 
  db $75   ; 
  db $75   ; 
  db $75   ; 
  db $75   ; 
  db $76   ; 
  db $77   ; 
  db $05   ; 
  db $CC   ; 
  db $CD   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $CE   ; 
  db $CF   ; 
  db $FE   ; 
  db $FE   ; 
  db $03   ; 
  db $CC   ; 
  db $CD   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $CE   ; 
  db $CF   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $E5   ; 
  db $D2   ; 
  db $FF   ; 
  db $D3   ; 
  db $D4   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $E6   ; 
  db $FC   ; 
  db $D1   ; 
  db $D2   ; 
  db $FF   ; 
  db $D3   ; 
  db $D4   ; 
  db $FE   ; 
  db $FE   ; 
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $E6   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $D1   ; 
  db $D2   ; 
  db $FF   ; 
  db $D3   ; 
  db $D4   ; 
  db $00   ; 



_off_004_F3C0_1C
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $E6   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $00   ; 



_off_004_F3CE_1F
  db $03   ; 
  db $BF   ; 
  db $7D   ; 
  db $7E   ; 
  db $7F   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
tbl_F3D8_80    ; for BIT instruction, bzk optimize, same as 0x002713
  db $80   ; 
  db $81   ; 
  db $82   ; 
  db $00   ; 



_off_004_F3DC_22
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $00   ; 



_off_004_F3EA_23
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $78   ; 
  db $78   ; 
  db $78   ; 
  db $78   ; 
  db $78   ; 
  db $78   ; 
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $03   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $04   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $05   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $FE   ; 
  db $FE   ; 
  db $06   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $FE   ; 
  db $FE   ; 
  db $07   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $FE   ; 
  db $08   ; 
  db $C7   ; 
  db $C8   ; 
  db $C9   ; 
  db $CA   ; 
  db $C8   ; 
  db $C9   ; 
  db $CB   ; 
  db $00   ; 



_off_004_F456_11
  db $09   ; 
  db $C0   ; 
  db $C0   ; 
  db $C0   ; 
  db $C0   ; 
  db $C0   ; 
  db $C0   ; 
  db $00   ; 



_off_004_F45E_16
  db $09   ; 
  db $E4   ; 
  db $E4   ; 
  db $E4   ; 
  db $E4   ; 
  db $E4   ; 
  db $E4   ; 
  db $00   ; 



_off_004_F466_17
  db $09   ; 
  db $C3   ; 
  db $C3   ; 
  db $C3   ; 
  db $C3   ; 
  db $C3   ; 
  db $C3   ; 
  db $00   ; 



_off_004_F46E_1D
_off_004_F46E_1E
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $E6   ; 
  db $28   ; 
  db $29   ; 
  db $73   ; 
  db $73   ; 
  db $73   ; 
  db $70   ; 
  db $71   ; 
  db $72   ; 
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $E6   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $B9   ; 
  db $BA   ; 
  db $BB   ; 
  db $03   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $E6   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $FC   ; 
  db $BC   ; 
  db $BD   ; 
  db $BE   ; 
  db $00   ; 



_off_004_F496_0F
  db $09   ; 
  db $88   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $09   ; 
  db $89   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $00   ; 



_off_004_F4A5_10
  db $09   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $88   ; 
  db $09   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3B   ; 
  db $3C   ; 
  db $89   ; 
  db $00   ; 



_off_004_F4B4_0E
  db $08   ; 
  db $E2   ; 
  db $8D   ; 
  db $8E   ; 
  db $8F   ; 
  db $90   ; 
  db $91   ; 
  db $92   ; 
  db $07   ; 
  db $E2   ; 
  db $DE   ; 
  db $DF   ; 
  db $E3   ; 
  db $FE   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $00   ; 



tbl_F4C6
  db $00   ; 
  db $20   ; 
  db $18   ; 
  db $1A   ; 
  db $1C   ; 
  db $22   ; 
  db $16   ; 



tbl_F4CD
  db $15   ; 00 
  db $0A   ; 01 
  db $19   ; 02 
  db $FE   ; 03 
  db $FE   ; 04 



_off_005_F4D2_01
; bzk missing flag I indicates that this byte is probably a part of F4CD table
  db $12   ; 
  db $42   ; 
  db $17   ; 
  db $19   ; 
  db $00   ; 



_off_005_F4D7_02
  db $13   ; 
  db $43   ; 
  db $17   ; 
  db $1B   ; 
  db $00   ; 



_off_005_F4DC_00
  db $11   ; 
  db $46   ; 
  db $0A   ; 
  db $17   ; 
  db $00   ; 



_off_005_F4E1_03
  db $14   ; 
  db $44   ; 
  db $03   ; 
  db $1E   ; 
  db $44   ; 
  db $04   ; 
  db $1E   ; 
  db $44   ; 
  db $04   ; 
  db $1F   ; 
  db $1B   ; 
  db $00   ; 



_off_005_F4ED_04
  db $15   ; 
  db $41   ; 
  db $06   ; 
  db $21   ; 
  db $45   ; 
  db $06   ; 
  db $23   ; 
  db $00   ; 



tbl_F4F5_lo
  db < _off_005_F4DC_00   ; 
  db < _off_005_F4D2_01   ; 
  db < _off_005_F4D7_02   ; 
  db < _off_005_F4E1_03   ; 
  db < _off_005_F4ED_04   ; 



tbl_F4FA_hi
  db > _off_005_F4DC_00   ; 
  db > _off_005_F4D2_01   ; 
  db > _off_005_F4D7_02   ; 
  db > _off_005_F4E1_03   ; 
  db > _off_005_F4ED_04   ; 



sub_F4FF
  LDX ram_0043
  LDA tbl_ED3A_lo,X
  STA ram_0007
  LDA tbl_ED40_hi,X
  STA ram_0008
  LDA ram_00EB
  CMP ram_00E0_obj
  BEQ bra_F512
bra_F511_RTS
  RTS
bra_F512
  LDA ram_00EC
  BNE bra_F591
  LDA ram_00EF
  BNE bra_F597
bra_F51A_loop
loc_F51A
  LDY ram_00ED
  BNE bra_F525
  LDA (ram_0007),Y
  STA ram_0057
  INC ram_03A4
bra_F525
loc_F525
  LDA ram_0041
  CMP #$09
  BNE bra_F53A
  LDA ram_03BC
  BEQ bra_F53A
  LDA #$00
  STA ram_00EE
  STA ram_00ED
  LDA #$7F
  BNE bra_F58D    ; jmp
bra_F53A
  INC ram_00ED
  LDY ram_00ED
  LDA (ram_0007),Y
  BEQ bra_F511_RTS
  BIT tbl_F3D8_80
  BEQ bra_F54B
  LDA ram_0046_flag
  BEQ bra_F51A_loop
bra_F54B
  LDA (ram_0007),Y
  BIT tbl_F0B5_40
  BEQ bra_F576
  AND #$0F
  TAX
  LDA tbl_F4C6,X
  STA ram_00EE
  INC ram_00ED
  INY
  LDA ram_0041
  CMP #$09
  BNE bra_F572
  CPY #$02
  BNE bra_F572
  LDA #$01
  STA ram_0057
  LDA (ram_0007),Y
  SEC
  SBC #$3D
  BNE bra_F58D
bra_F572
  LDA (ram_0007),Y
  BNE bra_F58D
bra_F576
  LDX #$01
  AND #$3F
  STA ram_00EE
  CMP #$30
  BCC bra_F597
  BNE bra_F587
  LDA ram_03BC
  BEQ bra_F588
bra_F587
  DEX
bra_F588
  STX ram_03A8
  BPL bra_F51A_loop
bra_F58D
  AND #$7F
  STA ram_00EC
bra_F591
  LDA #$00
  STA ram_00EF
  DEC ram_00EC
bra_F597
  LDX ram_00EE
  JSR sub_F82E
  LDY ram_00EF
  LDA (ram_0005),Y
  BNE bra_F5A5
  JMP loc_F62D
bra_F5A5
  JSR sub_F676
  LDA (ram_0005),Y
  TAX
  JSR sub_F681
  LDA ram_00EE
  BEQ bra_F5BA
  CMP #$18
  BEQ bra_F5BA
  CMP #$1A
  BNE bra_F5C9
bra_F5BA
  LDA ram_03A2_useless
  EOR #$01
  STA ram_03A2_useless
  BNE bra_F5C9
  LDA #$83
  STA ram_030A
bra_F5C9
  INY
  STY ram_00EF
  LDA ram_00EE
  CMP #$09
  BNE bra_F5F6
  LDA ram_0057
  CMP #$01
  BEQ bra_F5F6
  CPY #$25
  BCC bra_F5F6
  CPY #$58
  BCS bra_F5F6
  LDX ram_03A5
  LDA tbl_F4CD,X
  STA ram_0310
  INC ram_03A5
  CPX #$05
  BNE bra_F5F6
  LDA ram_03A4
  STA ram_0310
bra_F5F6
  LDA #$8E
  STA ram_0303
  LDA ram_00EA
  STA ram_0301
  LDA ram_00E9
  STA ram_0302
  LDA ram_00E8
  STA ram_000F
  JSR sub_F64E
  LDA ram_00E8
  JSR sub_ECBF
  STA ram_00E8
  INC ram_00E9
  LDA ram_00E9
  CMP #$20
  BNE bra_F625
  LDA #$00
  STA ram_00E9
  LDA ram_00EA
  EOR #$04
  STA ram_00EA
bra_F625
  LDA ram_00E0_obj
  JSR sub_ECBF
  STA ram_00EB
  RTS



loc_F62D
  STA ram_00EF
  LDA ram_00EE
  CMP #$09
  BEQ bra_F638
  JMP loc_F51A
bra_F638
  INC ram_03A4
  DEC ram_0057
  BNE bra_F644
  LDA #$01
  STA ram_03BC
bra_F644
  LDA #$00
  STA ram_00ED
  STA ram_03A5
  JMP loc_F525



sub_F64E
  LDX #$05
  LDA #$0D
  STA ram_000C
bra_F654_loop
  TXA
  TAY
  JSR sub_E80D
  STX ram_000A
bra_F65B_loop
  LDX ram_000C
  LDA ram_0304,X
  CMP #$FC
  BNE bra_F66A
  DEC ram_000C
  LDA ram_000C
  BPL bra_F65B_loop
bra_F66A
  LDY ram_000F
  STA (ram_0003),Y
  DEC ram_000C
  LDX ram_000A
  DEX
  BPL bra_F654_loop
  RTS



sub_F676
  LDX #$0A
  LDA #$FC
bra_F67A_loop
  STA ram_0304 - $01,X
  DEX
  BNE bra_F67A_loop
  RTS



sub_F681
bra_F681_loop
  INY
  LDA (ram_0005),Y
  STA ram_0303,X
  INX
  CPX #$0F
  BNE bra_F681_loop
bra_F68C_RTS
  RTS



sub_F68D
  LDA ram_00BC_obj + $02
  BEQ bra_F68C_RTS
  LDA ram_obj_pos_X_lo + $02
  BNE bra_F6C7
  LDA ram_00C0_obj + $03
  BNE bra_F6C7
  LDX ram_obj_pos_X_lo
  TXA
  BEQ bra_F6C7
  DEX
  JSR sub_F839
  LDY ram_obj_pos_X_lo + $01
  LDA (ram_0007),Y
  BNE bra_F6AB
  JMP loc_F71E
bra_F6AB
  BIT tbl_F0B5_40
  BEQ bra_F6C2
  AND #$0F
  TAX
  LDA tbl_F4C6,X
  STA ram_obj_pos_Y_lo
  INY
  LDA (ram_0007),Y
  STA ram_obj_pos_X_lo + $02
  INY
  STY ram_obj_pos_X_lo + $01
  BNE bra_F6C7
bra_F6C2
  STA ram_obj_pos_Y_lo
  INY
  STY ram_obj_pos_X_lo + $01
bra_F6C7
  LDX ram_obj_pos_Y_lo
  JSR sub_F82E
  LDY ram_00C0_obj + $03
  LDA (ram_0005),Y
  BEQ bra_F70E
  JSR sub_F676
  LDA (ram_0005),Y
  TAX
  JSR sub_F681
  INY
  STY ram_00C0_obj + $03
  LDA #$8E
  STA ram_0303
  LDA ram_00B0_obj
  STA ram_0301
  LDA ram_00B0_obj + $01
  STA ram_0302
  LDA ram_00B0_obj + $02
  STA ram_000F
  JSR sub_F64E
  LDA ram_00B0_obj + $02
  JSR sub_ECBF
  STA ram_00B0_obj + $02
sub_F6FB
  INC ram_00B0_obj + $01
  LDA ram_00B0_obj + $01
  CMP #$20
  BNE bra_F70D_RTS
  LDA #$00
  STA ram_00B0_obj + $01
  LDA ram_00B0_obj
  EOR #$04
  STA ram_00B0_obj
bra_F70D_RTS
  RTS
bra_F70E
  LDA ram_obj_pos_X_lo
  BEQ bra_F71E
  LDA #$00
  STA ram_00C0_obj + $03
  LDA ram_obj_pos_X_lo + $02
  BEQ bra_F739
  DEC ram_obj_pos_X_lo + $02
  BPL bra_F739
bra_F71E
loc_F71E
  LDY ram_00B0_obj + $02
  JSR sub_ECC9
  BNE bra_F731
  INY
  CPY #$40
  BNE bra_F72C
  LDY #$00
bra_F72C
  JSR sub_ECC9
  BEQ bra_F73E
bra_F731
  LDA #$00
  STA ram_obj_pos_Y_lo
  STA ram_00C0_obj + $03
  STA ram_obj_pos_X_lo
bra_F739
  LDA #$01
  STA ram_00BC_obj + $02
  RTS
bra_F73E
  LDA #$00
  STA ram_00C0_obj + $03
  STA ram_00BC_obj + $02
  STA ram_00BC_obj + $01
  STA ram_obj_pos_X_lo
  LDA ram_obj_pos_Y_lo + $02
  STA ram_00B0_obj + $02
  LDA ram_obj_pos_Y_lo + $03
  STA ram_00B0_obj
  LDA ram_00BC_obj
  STA ram_00B0_obj + $01
  RTS



sub_F755
  LDA ram_00B4_obj
  BNE bra_F798_RTS
  LDA ram_00C0_obj
  BEQ bra_F798_RTS
  LDX #$15
bra_F75F_loop
  JSR sub_F82E
  LDY #$00
  LDA (ram_0005),Y
  STA ram_0003
  LDA #$0F
  SEC
  SBC ram_0003
  TAY
  STX ram_0004
  LDX ram_00B0_obj + $03
  LDA (ram_0005),Y
  CMP ram_0540,X
  BNE bra_F792
  DEY
  DEY
  DEY
  LDA (ram_0005),Y
  CMP ram_0480,X
  BNE bra_F792
  DEY
  DEY
  LDA (ram_0005),Y
  CMP ram_0400,X
  BNE bra_F792
  LDA ram_0004
  STA ram_00C4_obj + $03
  BPL bra_F799
bra_F792
  DEC ram_0004
  LDX ram_0004
  BPL bra_F75F_loop
bra_F798_RTS
  RTS
bra_F799
  LDA ram_00C4_obj
  BNE bra_F7AC
  LDA ram_00C4_obj + $03
  STA ram_00C4_obj + $02
  LDX ram_00B4_obj + $03
  JSR sub_F821
  LDA #$3D
  STA ram_00C4_obj + $01
  INC ram_00C4_obj
bra_F7AC
  LDA ram_00C4_obj + $03
  CMP ram_00C4_obj + $02
  BNE bra_F7C9
  LDA ram_00C4_obj + $02
  BNE bra_F798_RTS
  INC ram_00C4_obj + $01
  LDA ram_00C4_obj + $01
  CMP #$7F
  BCC bra_F7FA
  LDX ram_00B4_obj + $03
  STA ram_05E0,X
  INX
  JSR sub_F821
  BEQ bra_F7FA
bra_F7C9
  LDA ram_00C4_obj + $02
  BNE bra_F7E7
  LDX ram_00B4_obj + $03
  LDA ram_00C4_obj + $01
  STA ram_05E0,X
  INX
  STX ram_00B4_obj + $03
  LDA ram_00C4_obj + $03
  CMP #$11
  BCS bra_F809
  LDA ram_00C4_obj + $03
  STA ram_05E0,X
  JSR sub_F826
  BEQ bra_F7EC    ; jmp
bra_F7E7
  LDX ram_00B4_obj + $03
  JSR sub_F821
bra_F7EC
  LDA ram_00C4_obj + $03
  STA ram_00C4_obj + $02
  CMP #$09
  BNE bra_F7FA
  LDA #$02
  STA ram_00BC_obj + $03
  STA ram_0049
bra_F7FA
  LDA ram_00B4_obj + $03
  CMP #$ED
  BCC bra_F808_RTS
  LDA ram_00C0_obj + $01
  BNE bra_F808_RTS
  LDA #$01
  STA ram_00C0_obj + $01
bra_F808_RTS
  RTS
bra_F809
  AND #$0F
  TAX
  DEX
  JSR sub_F839
  LDY #$00
bra_F812_loop
  LDX ram_00B4_obj + $03
  LDA (ram_0007),Y
  BEQ bra_F7EC
  STA ram_05E0,X
  INX
  STX ram_00B4_obj + $03
  INY
  BNE bra_F812_loop
sub_F821
  LDA #$40
  STA ram_05E0,X
sub_F826
  INX
  STX ram_00B4_obj + $03
  LDA #$00
  STA ram_00C4_obj + $01
; Z = 1
  RTS



sub_F82E
  LDA tbl_F063_lo,X
  STA ram_0005
  LDA tbl_F087_hi,X
  STA ram_0006
  RTS



sub_F839
  LDA tbl_F4F5_lo,X
  STA ram_0007
  LDA tbl_F4FA_hi,X
  STA ram_0008
  RTS



sub_F844
  LDA #$C0
  JSR STA_4017
  JSR sub_F8D4
  JSR sub_FA74
  JSR sub_FC3D
  JSR sub_FC8D
  LDA #$00
  STA ram_00FF
  STA ram_00FE_flag
  STA ram_00FD
  STA ram_00FB
  LDA ram_07FF
  BEQ bra_F86A_RTS
  JSR STA_4011
  DEC ram_07FF
bra_F86A_RTS
  RTS



loc_F86B
sub_F86B
  JSR STX_4000
  JSR STY_4001
sub_F871
  LDX #$00
bra_F873
  TAY
  LDA tbl_FF00 + $01,Y
  BEQ bra_F884_RTS
  JSR STA_4002_X
  LDA tbl_FF00,Y
  ORA #$08
  JSR STA_4003_X
bra_F884_RTS
  RTS



sub_F885
  LDX #$04
  BNE bra_F873    ; jmp



sub_F889
  LDX #$08
  BNE bra_F873    ; jmp



bra_F88D
  STY ram_00F0
  LDA #$01
  STA ram_00F5
  LDX #$80
  LDY #$9C
  LDA #$04
  JMP loc_F86B
bra_F89C
  STY ram_00F0
  LDA #$10
  STA ram_00F5
  LDX #$85
  LDY #$85
  LDA #$30
  JSR sub_F86B
bra_F8AB
  JMP loc_F93A
bra_F8AE
  STY ram_00F0
  LDA #$09
  STA ram_00F5
  LDA #$04
  JSR sub_F871
bra_F8B9
  LDA ram_00F5
  CMP #$04
  BNE bra_F8C2
  JMP loc_F93E
bra_F8C2
  LDY #$84
  CMP #$07
  BCS bra_F8CA
  LDY #$8B
bra_F8CA
  JSR STY_4001
  ORA #$90
  JSR STA_4000
  BNE bra_F93A    ; jmp



sub_F8D4
  LDY ram_00F4
  BNE bra_F90D_RTS
  LDY ram_00FF
  LDA ram_00F0
  LSR ram_00FF
  BCS bra_F88D
  LSR
  BCS bra_F93A
  LSR ram_00FF
  BCS bra_F89C
  LSR
  BCS bra_F8AB
  LSR
  BCS bra_F8B9
  LSR ram_00FF
  BCS bra_F8AE
  LSR ram_00FF
  BCS bra_F90E
  LSR
  BCS bra_F921
  LSR ram_00FF
  BCS bra_F948
  LSR
  BCS bra_F95B
  LSR ram_00FF
  BCS bra_F96D
  LSR
  BCS bra_F975
  LSR ram_00FF
  BCS bra_F97D
  LSR
  BCS bra_F98A
bra_F90D_RTS
  RTS
bra_F90E
  STY ram_00F0
  LDA #$06
  STA ram_00F5
  LDX #$9C
  LDA #$3C
  JSR sub_F86B
  LDA #$03
  STA ram_00F6
  BNE bra_F92B    ; jmp
bra_F921
  DEC ram_00F6
  BEQ bra_F931
  LDA ram_00F6
  CMP #$03
  BNE bra_F90D_RTS
bra_F92B
  LDA #$9A
bra_F92D
  JSR STA_4001
  RTS
bra_F931
  LDA #$93
bra_F933
  JSR STA_4001
  LDA #$06
  STA ram_00F6
bra_F93A
loc_F93A
  DEC ram_00F5
  BNE bra_F947_RTS
loc_F93E
  LDA #$00
  STA ram_00F0
loc_F942
  LDA #$90
  JSR STA_4000
bra_F947_RTS
  RTS
bra_F948
  STY ram_00F0
  LDA #$03
  STA ram_00F5
bra_F94E
  LDX #$9C
  LDA #$00
  JSR sub_F86B
  LDA #$04
  STA ram_00F6
  BNE bra_F965    ; jmp
bra_F95B
  DEC ram_00F6
  BEQ bra_F969
bra_F95F
  LDA ram_00F6
  CMP #$04
  BNE bra_F90D_RTS
bra_F965
  LDA #$9A
  BNE bra_F92D    ; jmp
bra_F969
  LDA #$93
  BNE bra_F933    ; jmp
bra_F96D
  STY ram_00F0
  LDA #$02
  STA ram_00F5
  BNE bra_F94E    ; jmp
bra_F975
  DEC ram_00F6
  BNE bra_F95F
  LDA #$94
  BNE bra_F933    ; jmp
bra_F97D
  STY ram_00F0
  LDA #$21
  STA ram_00F5
  LDY #$BC
  LDA #$30
  JSR sub_F86B
bra_F98A
  LDA ram_00F5
  CMP #$15
  BNE bra_F995
  LDY #$7F
  JSR STY_4001
bra_F995
  LSR
  TAY
  LDA tbl_F9A3 - $01,Y
  BCS bra_F99E
  LDA #$13
bra_F99E
  JSR STA_4000
  BNE bra_F93A    ; jmp



tbl_F9A3
  db $91   ; 
  db $92   ; 
  db $93   ; 
  db $94   ; 
  db $95   ; 
  db $96   ; 
  db $97   ; 
  db $98   ; 
  db $9A   ; 
  db $9C   ; 
  db $9F   ; 
  db $9C   ; 
  db $9A   ; 
  db $98   ; 
  db $96   ; 
  db $94   ; 



tbl_F9B3
  db $00   ; 
  db $02   ; 
  db $04   ; 
  db $02   ; 
  db $00   ; 
  db $FE   ; 



tbl_F9B9
  db $94   ; 
  db $96   ; 
  db $94   ; 
  db $93   ; 
  db $92   ; 
  db $91   ; 



tbl_F9BF
  db $1C   ; 
  db $54   ; 
  db $16   ; 
  db $52   ; 
  db $12   ; 



tbl_F9C4
  db $18   ; 
  db $18   ; 
  db $20   ; 
  db $28   ; 
  db $30   ; 
  db $32   ; 
  db $34   ; 
  db $36   ; 
  db $38   ; 
  db $39   ; 
  db $3A   ; 
  db $3B   ; 
  db $3C   ; 
  db $3D   ; 
  db $3E   ; 
  db $3F   ; 
  db $40   ; 
  db $41   ; 
  db $42   ; 
  db $43   ; 
  db $44   ; 
  db $45   ; 
  db $46   ; 
  db $47   ; 
  db $48   ; 
  db $49   ; 
  db $4A   ; 
  db $4B   ; 
  db $4C   ; 
  db $4D   ; 
  db $4E   ; 
  db $4F   ; 
  db $50   ; 
  db $51   ; 
  db $52   ; 
  db $53   ; 
  db $54   ; 
  db $55   ; 
  db $56   ; 
  db $57   ; 
  db $58   ; 
  db $59   ; 
  db $5A   ; 
  db $5B   ; 
  db $5C   ; 
  db $5D   ; 
  db $5E   ; 
  db $5F   ; 



tbl_F9F4
  db $70   ; 
  db $05   ; 
  db $04   ; 
  db $03   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $02   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 
  db $01   ; 



tbl_FA24
  db $00   ; 
  db $94   ; 
  db $96   ; 
  db $98   ; 
  db $9C   ; 
  db $80   ; 
  db $80   ; 
  db $80   ; 
  db $80   ; 
  db $80   ; 
  db $9E   ; 
  db $9D   ; 
  db $9C   ; 
  db $9B   ; 
  db $9A   ; 
  db $99   ; 
  db $98   ; 
  db $97   ; 
  db $96   ; 
  db $95   ; 
  db $95   ; 



tbl_FA39
  db $94   ; 
  db $30   ; 
  db $38   ; 
  db $40   ; 
  db $48   ; 
  db $50   ; 
  db $54   ; 
  db $58   ; 
  db $50   ; 
  db $4C   ; 
  db $48   ; 
  db $44   ; 
  db $40   ; 
  db $3C   ; 
  db $38   ; 
  db $34   ; 
  db $30   ; 
  db $2C   ; 
  db $2A   ; 
  db $28   ; 
  db $26   ; 
  db $24   ; 



bra_FA4F
  LDY #$15
  STY ram_00F1
  BNE bra_FA5E    ; jmp



bra_FA55
  DEC ram_07F3
  BNE bra_FA8F
  DEC ram_00F1
  BEQ bra_FA8F
bra_FA5E
  LDX tbl_FA24,Y
  LDA #$01
  CPX #$80
  BNE bra_FA69
  LDA #$02
bra_FA69
  STA ram_07F3
  LDA tbl_FA39,Y
  LDY #$7F
  JMP loc_FAF7



sub_FA74
  LDY ram_00FE_flag
  BNE bra_FA4F
  LDY ram_00F1
  BNE bra_FA55
  LDA ram_00FC
  AND #$7F
  BNE bra_FA95
  LDA ram_00F3_bike_speed_sound
  BEQ bra_FA94_RTS
  LDA #$00
  STA ram_00F3_bike_speed_sound
  STA ram_00F7
  STA ram_07F8
bra_FA8F
  LDA #$90
  JSR STA_4004
bra_FA94_RTS
  RTS
bra_FA95
  LDY ram_00F7
  INC ram_00F7
  CPY ram_07F8
  BNE bra_FACF
  CMP #$30
  BCS bra_FABF_overheat_danger_noise
  SEC
  SBC ram_00F3_bike_speed_sound
  BEQ bra_FAC3
  BCS bra_FAB3
  DEC ram_00F3_bike_speed_sound
  CMP #$F8
  BCS bra_FABB
  DEC ram_00F3_bike_speed_sound
  BNE bra_FABB
bra_FAB3
  INC ram_00F3_bike_speed_sound
  CMP #$08
  BCC bra_FABB
  INC ram_00F3_bike_speed_sound
bra_FABB
  LDA #$01
  BNE bra_FAC8    ; jmp
bra_FABF_overheat_danger_noise
  LDA #$30
  STA ram_00F3_bike_speed_sound
bra_FAC3
  LDY ram_00F3_bike_speed_sound
  LDA tbl_F9F4,Y
bra_FAC8
  STA ram_07F8
  LDA #$00
  STA ram_00F7
bra_FACF
  LDA ram_07FF
  CLC
  ADC #$04
  CMP #$40
  BCS bra_FADC
  STA ram_07FF
bra_FADC
  LDY ram_00F3_bike_speed_sound
  LDA tbl_F9C4,Y
  LDY ram_00F7
  CLC
  ADC tbl_F9B3,Y
  LDX ram_00FC
  BPL bra_FAF2
  LDX tbl_F9BF,Y
  LDY #$89
  BNE bra_FAF7    ; jmp
bra_FAF2
  LDX tbl_F9B9,Y
  LDY #$7F
bra_FAF7
loc_FAF7
  JSR STX_4004
  JSR STY_4005
  STA ram_07F9
  LDY #$07
  STY ram_0000
  LDY #$FF
  STY ram_0001
  LSR
  LSR
  LSR
  LSR
  LSR
  TAY
  BEQ bra_FB17
bra_FB10_loop
  LSR ram_0000
  ROR ram_0001
  DEY
  BNE bra_FB10_loop
bra_FB17
  LDA ram_0000
  LSR
  TAX
  LDA ram_0001
  ROR
  TAY
  ASL ram_07F9
  ASL ram_07F9
  ASL ram_07F9
bra_FB28_loop
  TXA
  LSR
  TAX
  TYA
  ROR
  TAY
  ASL ram_07F9
  BCC bra_FB41
  SEC
  EOR #$FF
  ADC ram_0001
  STA ram_0001
  TXA
  EOR #$FF
  ADC ram_0000
  STA ram_0000
bra_FB41
  LDA ram_07F9
  BNE bra_FB28_loop
  LDA ram_0001
  JSR STA_4006
  LDA ram_0000
  JSR STA_4007
  LDA ram_00F1
  BNE bra_FB5A
  LDA ram_00F7
  ORA ram_00FA
  BNE bra_FB76_RTS
bra_FB5A
  LSR ram_0000
  ROR ram_0001
  LDA ram_0000
  LSR
  TAY
  LDA ram_0001
  ROR
  CLC
  ADC ram_0001
  JSR STA_400A
  TYA
  ADC ram_0000
  JSR STA_400B
  LDA #$04
  JSR STA_4008
bra_FB76_RTS
  RTS



tbl_FB77
  db $10   ; 
  db $11   ; 
  db $12   ; 
  db $12   ; 
  db $12   ; 
  db $13   ; 
  db $13   ; 
  db $14   ; 
  db $15   ; 
  db $16   ; 
  db $17   ; 
  db $18   ; 
  db $19   ; 
  db $1A   ; 
  db $1B   ; 
  db $1C   ; 
  db $1D   ; 
  db $1E   ; 
  db $1F   ; 
  db $1C   ; 
  db $1F   ; 
  db $1F   ; 
  db $1F   ; 
  db $1F   ; 
  db $1F   ; 
  db $18   ; 
  db $1F   ; 
  db $1F   ; 
  db $1F   ; 
  db $1F   ; 
  db $18   ; 
  db $1C   ; 
  db $1F   ; 
  db $1F   ; 
  db $18   ; 
  db $1F   ; 
  db $1F   ; 
  db $1F   ; 
  db $14   ; 
  db $1F   ; 
  db $1C   ; 
  db $1F   ; 
  db $1F   ; 
  db $1C   ; 
  db $18   ; 
  db $16   ; 



tbl_FBA5
  db $0E   ; 
  db $0C   ; 
  db $0E   ; 
  db $0E   ; 
  db $0A   ; 
  db $0C   ; 
  db $0E   ; 
  db $0E   ; 
  db $0C   ; 
  db $0A   ; 
  db $0E   ; 
  db $0D   ; 
  db $0E   ; 
  db $0E   ; 
  db $0E   ; 
  db $0E   ; 
  db $0C   ; 
  db $0E   ; 
  db $0A   ; 
  db $0E   ; 
  db $0C   ; 
  db $0C   ; 
  db $0E   ; 
  db $0D   ; 
  db $0C   ; 
  db $0D   ; 
  db $0D   ; 
  db $0E   ; 
  db $0E   ; 
  db $0D   ; 
  db $0D   ; 
  db $0E   ; 
  db $0B   ; 
  db $0E   ; 
  db $0E   ; 
  db $0D   ; 
  db $0E   ; 
  db $0E   ; 
  db $0C   ; 
  db $0D   ; 
  db $0E   ; 
  db $0B   ; 
  db $0D   ; 
  db $0E   ; 
  db $0E   ; 
  db $0D   ; 



tbl_FBD3
  db $30   ; 
  db $31   ; 
  db $32   ; 
  db $32   ; 
  db $33   ; 
  db $33   ; 
  db $34   ; 
  db $35   ; 
  db $36   ; 
  db $37   ; 
  db $38   ; 
  db $37   ; 
  db $38   ; 
  db $37   ; 
  db $36   ; 
  db $35   ; 
  db $34   ; 
  db $34   ; 
  db $34   ; 
  db $35   ; 
  db $36   ; 
  db $37   ; 
  db $38   ; 
  db $39   ; 
  db $3A   ; 
  db $3B   ; 
  db $3C   ; 
  db $3A   ; 
  db $38   ; 
  db $36   ; 
  db $35   ; 



tbl_FBF2
  db $34   ; 
  db $10   ; 
  db $11   ; 
  db $12   ; 
  db $14   ; 
  db $16   ; 
  db $18   ; 
  db $1C   ; 
  db $1F   ; 
  db $1C   ; 
  db $18   ; 
  db $16   ; 
  db $14   ; 



bra_FBFF
  STY ram_00F2
  LDA #$2E
  STA ram_07F6
bra_FC06
  TYA
  BEQ bra_FC0E
  AND #$02
  STA ram_07F7
bra_FC0E
  LDY ram_07F6
  LDA tbl_FB77 - $01,Y
  JSR STA_400C
  LDA tbl_FBA5 - $01,Y
  JSR STA_400E
  BNE bra_FC75    ; jmp
bra_FC1F
  STY ram_00F2
  LDA #$00
  STA ram_07F6
  STA ram_07F7
  LDA #$0E
  JSR STA_400E
bra_FC2E
  LDA ram_07F6
  LSR
  LSR
  LSR
  TAY
  LDA tbl_FBD3,Y
  JSR STA_400C
  BNE bra_FC75    ; jmp



sub_FC3D
  LDY ram_00FD
  LDA ram_00F2
  LSR ram_00FD
  BCS bra_FBFF
  LSR
  BCS bra_FC06
  LSR ram_00FD
  BCS bra_FC1F
  LSR
  BCS bra_FC2E
  LSR
  BCS bra_FC63
  LSR ram_00FD
  BCS bra_FC57
bra_FC56_RTS
  RTS
bra_FC57
  STY ram_00F2
  LDA #$0C
  STA ram_07F6
  LDA #$0D
  JSR STA_400E
bra_FC63
  LDY ram_07F6
  LDA tbl_FBF2,Y
  JSR STA_400C
  CPY #$08
  BNE bra_FC75
  LDA #$0E
  JSR STA_400E
bra_FC75
  LDA #$08
  JSR STA_400F
  DEC ram_07F6
  BNE bra_FC56_RTS
  LDY ram_07F7
  BNE bra_FC1F
  LDA #$00
  STA ram_00F2
  RTS



tbl_FC89_for_4001
  db $7F   ; 00 
  db $8E   ; 01 
  db $86   ; 02 
  db $8F   ; 03 



sub_FC8D
  LDA ram_00FB
  BNE bra_FC96
  LDA ram_00F4
  BNE bra_FCD9
  RTS
bra_FC96
  STA ram_00F4
  LDY #$00
bra_FC9A_loop
  INY
  LSR
  BCC bra_FC9A_loop
  LDA tbl_FDD3_index - $01,Y
  TAY
  LDA tbl_FDDB - $08,Y
  STA ram_07F0
  LDA tbl_FDDB - $08 + $01,Y
  STA ram_00F8
  LDA tbl_FDDB - $08 + $02,Y
  STA ram_00F9
  LDA tbl_FDDB - $08 + $03,Y
  STA ram_07E0
  LDA tbl_FDDB - $08 + $04,Y
  STA ram_00FA
  LDA tbl_FDDB - $08 + $05,Y
  STA ram_07EC
  LDA #$01
  STA ram_07E5
  STA ram_07E1
  STA ram_07E9
  STA ram_07ED
  LDY #$00
  STY ram_07E4
  INC ram_07FB
bra_FCD9
  LDY ram_07E0
  BEQ bra_FD1A
  DEC ram_07E1
  BNE bra_FD1A
  INC ram_07E0
  LDA (ram_00F8),Y
  JSR sub_FF53
  STA ram_07E1
  TXA
  AND #$3E
  JSR sub_F871
  BNE bra_FCFA
  LDX #$10
  BNE bra_FD04    ; jmp
bra_FCFA
  LDX #$4F
  LDA ram_00F4
  AND #$60
  BNE bra_FD04
  LDX #$05
bra_FD04
  JSR STX_4000
  LDY #$7F
  LDA ram_00F4
  LSR
  BCC bra_FD17
  LDA ram_07FB
  AND #$03
  TAX
  LDY tbl_FC89_for_4001,X
bra_FD17
  JSR STY_4001
bra_FD1A
  DEC ram_07E5
  BNE bra_FD63
  LDY ram_07E4
  INC ram_07E4
  LDA (ram_00F8),Y
  BNE bra_FD32
  LDA #$00
  STA ram_00FA
  STA ram_00F4
  JMP loc_F942
bra_FD32
  JSR sub_FF53
  STA ram_07E5
  LDA ram_00F4
  AND #$60
  BNE bra_FD63
  TXA
  AND #$3E
  JSR sub_F885
  BNE bra_FD4A
  LDX #$10
  BNE bra_FD5B    ; jmp
bra_FD4A
  LDX #$87
  LDA ram_07E5
  CMP #$10
  BCS bra_FD5B
  LDX #$84
  CMP #$08
  BCS bra_FD5B
  LDX #$82
bra_FD5B
  JSR STX_4004
  LDA #$7F
  JSR STA_4005
bra_FD63
  LDY ram_00FA
  BEQ bra_FD99
  DEC ram_07E9
  BNE bra_FD99
  INC ram_00FA
  LDA (ram_00F8),Y
  JSR sub_FF53
  STA ram_07E9
  CLC
  ADC #$FF
  CMP #$0C
  BCC bra_FD7F
  LDA #$0C
bra_FD7F
  ASL
  ASL
  LDY ram_00F4
  CPY #$20
  BNE bra_FD89
  LDA #$81
bra_FD89
  JSR STA_4008
  TXA
  AND #$3E
  JSR sub_F889
  BNE bra_FD99
  LDA #$00
  JSR STA_4008
bra_FD99
  LDA ram_00F4
  AND #$1B
  BEQ bra_FDD2_RTS
  DEC ram_07ED
  BNE bra_FDD2_RTS
  LDY ram_07EC
  INC ram_07EC
  LDA (ram_00F8),Y
  JSR sub_FF53
  STA ram_07ED
  TXA
  AND #$3E
  BEQ bra_FDD2_RTS
  CMP #$20
  BEQ bra_FDC3
  LDA #$00
  LDX #$00
  LDY #$08
  BNE bra_FDC9    ; jmp
bra_FDC3
  LDA #$00
  LDX #$02
  LDY #$08
bra_FDC9
  JSR STA_400C
  JSR STX_400E
  JSR STY_400F
bra_FDD2_RTS
  RTS



tbl_FDD3_index
tbl__FDD3
  db off_FDDB_00 - tbl__FDD3   ; 00 
  db off_FDE1_01 - tbl__FDD3   ; 01 
  db off_FDE7_02 - tbl__FDD3   ; 02 
  db off_FDE1_03 - tbl__FDD3   ; 03 
  db off_FDE1_04 - tbl__FDD3   ; 04 
  db off_FDEC_05 - tbl__FDD3   ; 05 
  db off_FDF1_06 - tbl__FDD3   ; 06 
  db off_FDF6_07 - tbl__FDD3   ; 07 



tbl_FDDB
off_FDDB_00
  db $00   ; 
  dw _off_001_FF64_00
  db $2D   ; 
  db $59   ; 
  db $74   ; 



off_FDE1_01
off_FDE1_03
off_FDE1_04
  db $0F   ; 
  dw _off_001_FDFB_01
  db $31   ; 
  db $56   ; 
  db $7B   ; 



off_FDE7_02
  db $08   ; 
  dw _off_001_FE87_02
  db $27   ; 
  db $41   ; 



off_FDEC_05
  db $0F   ; sharing with 0x003DF7 ?
  dw _off_001_FEF3_05
  db $03   ; 
  db $00   ; 



off_FDF1_06
  db $08   ; sharing with 0x003DFC ?
  dw _off_001_FEFD_06
  db $02   ; 
  db $00   ; 



off_FDF6_07
  db $08   ; sharing with 0x003E01 ?
  dw _off_001_FFF0_07
  db $02   ; 
  db $00   ; 



_off_001_FDFB_01
  db $02   ; sharing with 0x003E06 ?
  db $20   ; 
  db $26   ; 
  db $02   ; 
  db $4A   ; 
  db $02   ; 
  db $06   ; 
  db $02   ; 
  db $20   ; 
  db $26   ; 
  db $02   ; 
  db $4A   ; 
  db $02   ; 
  db $06   ; 
  db $02   ; 
  db $20   ; 
  db $26   ; 
  db $02   ; 
  db $2E   ; 
  db $02   ; 
  db $2E   ; 
  db $02   ; 
  db $2E   ; 
  db $46   ; 
  db $AE   ; 
  db $02   ; 
  db $42   ; 
  db $6E   ; 
  db $6A   ; 
  db $22   ; 
  db $1C   ; 
  db $2A   ; 
  db $22   ; 
  db $1C   ; 
  db $2A   ; 
  db $6E   ; 
  db $22   ; 
  db $1C   ; 
  db $2E   ; 
  db $22   ; 
  db $1C   ; 
  db $2E   ; 
  db $1C   ; 
  db $60   ; 
  db $62   ; 
  db $64   ; 
  db $26   ; 
  db $86   ; 
  db $00   ; 
  db $82   ; 
  db $60   ; 
  db $58   ; 
  db $42   ; 
  db $58   ; 
  db $60   ; 
  db $58   ; 
  db $42   ; 
  db $58   ; 
  db $60   ; 
  db $5C   ; 
  db $60   ; 
  db $5C   ; 
  db $60   ; 
  db $5C   ; 
  db $60   ; 
  db $5C   ; 
  db $62   ; 
  db $18   ; 
  db $36   ; 
  db $22   ; 
  db $18   ; 
  db $36   ; 
  db $22   ; 
  db $66   ; 
  db $3A   ; 
  db $3A   ; 
  db $26   ; 
  db $3A   ; 
  db $3A   ; 
  db $26   ; 
  db $36   ; 
  db $7A   ; 
  db $58   ; 
  db $5C   ; 
  db $22   ; 
  db $A6   ; 
  db $82   ; 
  db $58   ; 
  db $66   ; 
  db $58   ; 
  db $66   ; 
  db $58   ; 
  db $66   ; 
  db $58   ; 
  db $66   ; 
  db $60   ; 
  db $68   ; 
  db $60   ; 
  db $68   ; 
  db $60   ; 
  db $68   ; 
  db $60   ; 
  db $68   ; 
  db $46   ; 
  db $2A   ; 
  db $22   ; 
  db $06   ; 
  db $2A   ; 
  db $22   ; 
  db $06   ; 
  db $50   ; 
  db $26   ; 
  db $26   ; 
  db $10   ; 
  db $10   ; 
  db $26   ; 
  db $26   ; 
  db $22   ; 
  db $66   ; 
  db $6A   ; 
  db $6A   ; 
  db $0A   ; 
  db $8E   ; 
  db $41   ; 
  db $A0   ; 
  db $A0   ; 
  db $A0   ; 
  db $A0   ; 
  db $A0   ; 
  db $A0   ; 
  db $A0   ; 
  db $60   ; 
  db $E0   ; 
  db $E0   ; 
  db $20   ; 
  db $60   ; 
  db $60   ; 
  db $60   ; 
  db $20   ; 
  db $A0   ; 



_off_001_FE87_02
  db $22   ; 
  db $26   ; 
  db $22   ; 
  db $26   ; 
  db $22   ; 
  db $26   ; 
  db $26   ; 
  db $2A   ; 
  db $26   ; 
  db $2A   ; 
  db $26   ; 
  db $2A   ; 
  db $2A   ; 
  db $2C   ; 
  db $2A   ; 
  db $2C   ; 
  db $2A   ; 
  db $2C   ; 
  db $46   ; 
  db $6E   ; 
  db $66   ; 
  db $6B   ; 
  db $6F   ; 
  db $46   ; 
  db $4A   ; 
  db $4E   ; 
  db $47   ; 
  db $6E   ; 
  db $46   ; 
  db $4A   ; 
  db $6D   ; 
  db $67   ; 
  db $62   ; 
  db $62   ; 
  db $62   ; 
  db $67   ; 
  db $67   ; 
  db $6B   ; 
  db $00   ; 
  db $6D   ; 
  db $47   ; 
  db $4B   ; 
  db $50   ; 
  db $4E   ; 
  db $46   ; 
  db $4B   ; 
  db $55   ; 
  db $50   ; 
  db $54   ; 
  db $56   ; 
  db $51   ; 
  db $4E   ; 
  db $50   ; 
  db $54   ; 
  db $4B   ; 
  db $4F   ; 
  db $34   ; 
  db $18   ; 
  db $34   ; 
  db $18   ; 
  db $34   ; 
  db $18   ; 
  db $59   ; 
  db $59   ; 
  db $5D   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $66   ; 
  db $6A   ; 
  db $6C   ; 
  db $67   ; 
  db $6C   ; 
  db $6C   ; 
  db $6C   ; 
  db $66   ; 
  db $66   ; 
  db $66   ; 
  db $66   ; 
  db $66   ; 
  db $66   ; 
  db $6A   ; 
  db $6A   ; 
  db $6A   ; 



_off_001_FEF3_05
  db $03   ; 
  db $03   ; 
  db $00   ; 
  db $76   ; 
  db $82   ; 
  db $76   ; 
  db $82   ; 
  db $76   ; 
  db $82   ; 
  db $2B   ; 



_off_001_FEFD_06
  db $42   ; 
  db $00   ; 
  db $44   ; 



tbl_FF00
  db $06, $AE   ; 
  db $00, $00   ; 
  db $00, $69   ; 
  db $00, $D4   ; 
  db $00, $C8   ; 
  db $00, $BD   ; 
  db $00, $B2   ; 
  db $00, $A8   ; 
  db $00, $9F   ; 
  db $00, $96   ; 
  db $00, $8D   ; 
  db $00, $7E   ; 
  db $01, $AB   ; 
  db $01, $93   ; 
  db $01, $7C   ; 
  db $01, $67   ; 
  db $01, $52   ; 
  db $01, $3F   ; 
  db $01, $2D   ; 
  db $01, $1C   ; 
  db $01, $0C   ; 
  db $00, $FD   ; 
  db $00, $EE   ; 
  db $00, $E1   ; 
  db $03, $57   ; 
  db $02, $3A   ; 
  db $02, $1A   ; 
  db $01, $FC   ; 
  db $01, $DF   ; 
  db $01, $C4   ; 
  db $07, $FA   ; 



tbl_FF3E
  db $04   ; 
  db $08   ; 
  db $10   ; 
  db $20   ; 
  db $05   ; 
  db $18   ; 
  db $0A   ; 
  db $06   ; 
  db $05   ; 
  db $0A   ; 
  db $14   ; 
  db $28   ; 
  db $50   ; 
  db $1E   ; 
  db $3C   ; 
  db $07   ; 
  db $0E   ; 
  db $1C   ; 
  db $38   ; 
  db $70   ; 
  db $2A   ; 



sub_FF53
  TAX
  ROR
  TXA
  ROL
  ROL
  ROL
  AND #$07
  CLC
  ADC ram_07F0
  TAY
  LDA tbl_FF3E,Y
  RTS



_off_001_FF64_00
  db $82   ; 
  db $60   ; 
  db $42   ; 
  db $66   ; 
  db $42   ; 
  db $46   ; 
  db $42   ; 
  db $60   ; 
  db $66   ; 
  db $42   ; 
  db $47   ; 
  db $C2   ; 
  db $68   ; 
  db $42   ; 
  db $6E   ; 
  db $42   ; 
  db $4E   ; 
  db $42   ; 
  db $68   ; 
  db $6E   ; 
  db $42   ; 
  db $4F   ; 
  db $C2   ; 
  db $0B   ; 
  db $03   ; 
  db $C7   ; 
  db $0B   ; 
  db $03   ; 
  db $C7   ; 
  db $2B   ; 
  db $03   ; 
  db $E7   ; 
  db $A2   ; 
  db $23   ; 
  db $03   ; 
  db $E1   ; 
  db $5E   ; 
  db $5D   ; 
  db $58   ; 
  db $A0   ; 
  db $A2   ; 
  db $A4   ; 
  db $66   ; 
  db $C6   ; 
  db $00   ; 
  db $82   ; 
  db $58   ; 
  db $42   ; 
  db $60   ; 
  db $42   ; 
  db $66   ; 
  db $42   ; 
  db $58   ; 
  db $60   ; 
  db $42   ; 
  db $67   ; 
  db $C2   ; 
  db $60   ; 
  db $42   ; 
  db $68   ; 
  db $42   ; 
  db $6E   ; 
  db $42   ; 
  db $60   ; 
  db $68   ; 
  db $42   ; 
  db $6F   ; 
  db $C2   ; 
  db $2B   ; 
  db $03   ; 
  db $EB   ; 
  db $2B   ; 
  db $03   ; 
  db $EB   ; 
  db $23   ; 
  db $03   ; 
  db $E3   ; 
  db $9C   ; 
  db $1D   ; 
  db $03   ; 
  db $D9   ; 
  db $78   ; 
  db $7B   ; 
  db $72   ; 
  db $98   ; 
  db $98   ; 
  db $9C   ; 
  db $62   ; 
  db $E0   ; 
  db $98   ; 
  db $A6   ; 
  db $98   ; 
  db $A6   ; 
  db $98   ; 
  db $A6   ; 
  db $98   ; 
  db $A6   ; 
  db $A0   ; 
  db $AE   ; 
  db $A0   ; 
  db $AE   ; 
  db $A0   ; 
  db $AE   ; 
  db $A0   ; 
  db $AE   ; 
  db $9C   ; 
  db $EA   ; 
  db $9C   ; 
  db $E6   ; 
  db $E2   ; 
  db $60   ; 
  db $A6   ; 
  db $AA   ; 
  db $AA   ; 
  db $4A   ; 
  db $E6   ; 
  db $80   ; 
  db $E0   ; 
  db $E0   ; 
  db $E0   ; 
  db $E0   ; 
  db $E0   ; 
  db $E0   ; 
  db $E0   ; 
  db $A0   ; 
  db $A0   ; 
  db $C0   ; 
  db $A0   ; 
  db $E0   ; 
  db $50   ; 
  db $E0   ; 
  db $A0   ; 
  db $A0   ; 
  db $A0   ; 
  db $60   ; 
  db $10   ; 
  db $10   ; 
  db $10   ; 
  db $10   ; 
  db $A0   ; 



vec_FFF0_IRQ
_off_001_FFF0_07
  db $83   ; 
  db $00   ; 
  db $04   ; 
  db $14   ; 
  db $04   ; 
  db $14   ; 
  db $04   ; 
  db $14   ; 
  db $04   ; 
  db $D4   ; 



;.out .sprintf("Free bytes in bank FF 0x%04X [%d]", ($FFFA - *), ($FFFA - *))



;.segment "VECTORS"
  dw vec_C23B_NMI
  dw vec_C184_RESET
  dw vec_FFF0_IRQ

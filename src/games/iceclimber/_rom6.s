;.segment "BANK_FF"
;.include "copy_bank_ram.inc"
;.include "copy_bank_val.inc"
;.org $C000  ; for listing file
; 0x000010-0x00400F



tbl_C000_lo
  db < ram_ppu_buffer ;   00 ; logo screen, mountain counter
  db < (ram_0500_data + $4C) ;   01 ; logo screen palette
  db < _off000_C6B8_02 ; 
  db < _off000_C6E3_03 ; 
  db < _off000_C694_04 ; 
  db < ram_0400_data ;   05 ; logo screen bg data
  db < _off000_C6ED_06 ; 
  db < (ram_0400_data + $DF) ;   07 ; score counting screen palette, see 0x005295
  db < (ram_0400_data + $81) ;   08 ; score counting screen bg data (additional data for 2nd player)
  db < ram_0600_data ;   09 ; 



tbl_C00A_hi
  db > ram_ppu_buffer ;   00 ; 
  db > (ram_0500_data + $4C) ;   01 ; 
  db > _off000_C6B8_02 ; 
  db > _off000_C6E3_03 ; 
  db > _off000_C694_04 ; 
  db > ram_0400_data ;   04 ; 
  db > _off000_C6ED_06 ; 
  db > (ram_0400_data + $DF) ;   06 ; 
  db > (ram_0400_data + $81) ;   07 ; 
  db > ram_0600_data ;   08 ; 



vec_C014_RESET
  SEI
  CLD
  LDA #$10
  STA $2000
  LDX #$FF
  TXS
; bzk optimize, BIT + BPL
bra_C01E_infinite_loop
  LDA $2002
  ASL
  BCC bra_C01E_infinite_loop
bra_C024_infinite_loop
  LDA $2002
  ASL
  BCC bra_C024_infinite_loop
  LDY #$07
  STY ram_0001
  LDY #$00
  STY ram_0000
  TYA ; 00
  LDX #$5A
  CPX ram_reset_check
  BNE bra_C041_it_is_first_launch
  CPX ram_reset_check + $01
  BNE bra_C041_it_is_first_launch
; if it is a manual reset, it means the game was already loaded once
; clear 0000-07EC and keep score
  LDY #$EC
; clear 0000-07FF
bra_C041_it_is_first_launch
bra_C041_loop
  STA (ram_0000),Y
  DEY
  BNE bra_C041_loop
  DEC ram_0001
  BPL bra_C041_loop
  LDA #$5A
  STA ram_reset_check
  STA ram_reset_check + $01
  JSR sub_C05E
  JSR sub_C141_enable_nmi
loc_C058_infinite_loop
  JSR sub_CACE_generate_random
  JMP loc_C058_infinite_loop



sub_C05E
  LDA #$00
  STA $4011
  LDA #$0F
  STA $4015
  LDA #$06
  STA $2001
sub_C06D
  JSR sub_C883
sub_C070
  JSR sub_C89A
  JMP loc_C81D_hide_all_sprites



vec_C076_NMI
  PHA
  TXA
  PHA
  TYA
  PHA
  LDA ram_for_2000
  LDX ram_00DE_flag
  BEQ bra_C083
  EOR #$02
bra_C083
  AND #$7F
  JSR sub_C148_set_2000
  LDA ram_buffer_offset
  BNE bra_C095
  LDA ram_for_2001
  ORA #$1E
  STA $2001
  STA ram_for_2001
bra_C095
  LDA #< ram_oam
  STA $2003
  LDA #> ram_oam
  STA $4014
  LDX ram_buffer_offset
  JSR sub_C150
; A = 00
  STA ram_buffer_offset
  STA ram_00DE_flag
  LDA #> $3F00
  STA $2006
  LDA #< $3F00
  STA $2006
; A = 00
  STA $2006
  STA $2006
  LDA $2002
  JSR sub_CB81_set_scroll
  LDA ram_for_2000
  STA $2000
  JSR sub_CAED_read_joy_regs
  JSR sub_F91E_update_sound_engine
  LDA ram_0053_flag
  BEQ bra_C0D3
  JSR sub_C620
  JMP loc_C126
bra_C0D3
  LDA ram_0051
  BEQ bra_C126
  LDX ram_034C
  BEQ bra_C11A_00
  DEX
  BEQ bra_C103_01
  DEX
  BNE bra_C100_03_04
; 02
  LDA ram_for_2001
  AND #$EF
  STA $2001
  STA ram_for_2001
  LDA ram_btn_press
  AND #con_btn_Start
  BEQ bra_C138_exit_nmi
; if pause was set
  LDY #con_music_unpause
bra_C0F3
  STY ram_music_1
  LDA #$40
  STA ram_034D_pause_timer
bra_C0FA
  INC ram_034C
  JMP loc_C138_exit_nmi
bra_C100_03_04
  DEX
  BNE bra_C10A_04
; 03
bra_C103_01
  DEC ram_034D_pause_timer
  BEQ bra_C0FA
  BNE bra_C138_exit_nmi    ; jmp
bra_C10A_04
  LDA ram_for_2001
  ORA #$10
  STA $2001
  STA ram_for_2001
  LDA #$00
  STA ram_034C
  BEQ bra_C138_exit_nmi    ; jmp
bra_C11A_00
  LDY #con_music_pause
  LDA ram_btn_press
  AND #con_btn_Start
  BEQ bra_C126
  LDA ram_0055
  BNE bra_C0F3
bra_C126
loc_C126
  JSR sub_CB9D_decrease_all_timers
  INC ram_frm_cnt
  LDA ram_0051
  BNE bra_C135
  JSR sub_C437
  JMP loc_C138_exit_nmi
bra_C135
  JSR sub_C44A
bra_C138_exit_nmi
loc_C138_exit_nmi
  JSR sub_C141_enable_nmi
  PLA
  TAY
  PLA
  TAX
  PLA
  RTI



sub_C141_enable_nmi
  LDA $2002
  LDA ram_for_2000
  ORA #$80
sub_C148_set_2000
  STA ram_for_2000
  STA $2000
  RTS



sub_C14E
loc_C14E
  LDX #$00
sub_C150
  LDA tbl_C000_lo,X
  STA ram_0000
  LDA tbl_C00A_hi,X
  STA ram_0001
  JSR sub_CB78
sub_C15D
  LDA #$00
  STA ram_buffer_index
  STA ram_ppu_buffer
  RTS



ofs_000_C166_00
  LDA ram_0043_timer
  BNE bra_C1D6_RTS
  JSR sub_C891_write_00_to_2001
  LDX ram_0057_script
  BNE bra_C182
  LDA #con_music_off
  STA ram_music_1
  JSR sub_C06D
  LDX #$00    ; logo screen bg data
  JSR sub_C6FB_copy_data_from_ppu
  LDA #$01
bra_C17F_loop
  JMP loc_C218
bra_C182
  DEX
  BNE bra_C189
  LDA #$05
  BNE bra_C17F_loop    ; jmp
bra_C189
  DEX
  BNE bra_C19B
  LDA #$F9
  STA ram_0000
  JSR sub_CA4C
  LDA #$F1
  JSR sub_C8E0
  JMP loc_C21A
bra_C19B
  LDA #$00
  STA ram_mountain_completed
  STA ram_0057_script
  STA ram_03FA
  STA ram_03FB
  STA ram_scroll_Y
  STA ram_0022_plr
  STA ram_0022_plr + $01
  LDX #$09
bra_C1AF_loop
  STA ram_plr_counters,X
  DEX
  BPL bra_C1AF_loop
  STA ram_004D_timer
  JSR sub_C8E0
  JSR sub_C4C0_update_game_mode_cursor
  LDA ram_0054_timer
  BNE bra_C1D0
  LDA #$03
  STA ram_0054_timer
  LDA #$58
  STA ram_004D_timer
  LDA #$09
  STA ram_main_timer
  LSR ; 04 con_music_logo
  STA ram_music_1
bra_C1D0
  LDA #$80
  STA ram_spawn_timer_lo_bird
  INC ram_0051
bra_C1D6_RTS
  RTS



sub_C1D7
ofs_000_C1D7_01
  JSR sub_C891_write_00_to_2001
  LDA ram_0057_script
  BNE bra_C1F0
  JSR sub_C070
  LDA ram_for_2000
  AND #$FD
  STA ram_for_2000
  LDA #$9F
  STA ram_scroll_Y
  LDA #$04
  JMP loc_C218
bra_C1F0
  CMP #$01
  BEQ bra_C21A
  CMP #$02
  BNE bra_C21D
  LDA #$00
  STA ram_007C
  LDX #$77
bra_C1FE_loop
; 0078-00EF
  STA ram_range_0078_00EF,X
  CPX #$01
  BCC bra_C207
; X = 01-77
; 0381-03F7
  STA ram_range_0381_03F7 - $01,X
bra_C207
  DEX
  BPL bra_C1FE_loop
  JSR sub_C5A7_generate_map
  LDA #$01
  STA ram_00DA_plr
  LDA #$04
  STA ram_0090
  LSR ; 02
  STA ram_00DA_plr + $01
loc_C218
  STA ram_buffer_offset
bra_C21A
loc_C21A
  INC ram_0057_script
  RTS
bra_C21D
  CMP #$03
  BNE bra_C23B
  JSR sub_E79D
  JSR sub_E4C2
  JSR sub_C542_generate_map
  JSR sub_C4D7
  JSR sub_DFAB
  JSR sub_DD16
  JSR sub_DD1D
  INC ram_0057_script
  JMP loc_E05E
bra_C23B
  LDA #$00
  LDY #$90
bra_C23F_loop
; 0060-00EF
  STA ram_0060_plr - $01,Y
  DEY
  BNE bra_C23F_loop
  LDA #$04
  STA ram_0090
  LDA #$38
  STA ram_plr_pos_X
  LDA #$B8
  STA ram_plr_pos_X + $01
  LDX #$01
bra_C253_loop
  LDA #$00
  STA ram_005A_plr,X
  STA ram_plr_handler,X
  LDA ram_plr_lives,X
  BMI bra_C274
  LDA #$01
  STA ram_037A_useless
  STA ram_0062_plr
  STA ram_005A_plr,X
  STA ram_plr_handler,X
  LSR ; 00
  STA ram_002F_plr,X
  STA ram_0600_data + $3F
  STA ram_002D_plr,X
  LDA #$C0
  STA ram_plr_pos_Y,X
bra_C274
  DEX
  BPL bra_C253_loop
  LDX #$02
bra_C279_loop
  JSR sub_F19E
  DEX
  BPL bra_C279_loop
  LDA #$05
  STA ram_008B
  LDA #$80
  STA ram_spawn_timer_lo_bear
  LDA #$01
  STA ram_spawn_timer_hi_bear
  LDA #$1A
  STA ram_004A_plr_timer
  LDA #$21
  STA ram_004A_plr_timer + $01
  LDA #$22
  STA ram_0039_useless_timer
  JSR sub_F80C
  LDX ram_0055
  CPX #$01
  BNE bra_C2AB
  LDA #con_music_background
  STA ram_music_1
  JSR sub_E002
loc_C2A7
  LDA #$01
  STA ram_008D
bra_C2AB
loc_C2AB
  INC ram_0057_script
ofs_000_C2AD_03
  INC ram_0051
  RTS



ofs_000_C2B0_04
  JSR sub_C891_write_00_to_2001
  LDX ram_0057_script
  BNE bra_C2C4
  JSR sub_C06D
  LDX #$01    ; score cointing screen bg data
  JSR sub_C6FB_copy_data_from_ppu
  LDA #$07
bra_C2C1
  JMP loc_C218
bra_C2C4
  DEX
  BNE bra_C2CE
  JSR sub_F524
  LDA #$05
  BNE bra_C2C1    ; jmp
bra_C2CE
  DEX
  BNE bra_C2D9
  LDA ram_game_mode
  BEQ bra_C2D9    ; if 1p
; if 2p
  LDA #$08
  BNE bra_C2C1    ; jmp
bra_C2D9
  JSR sub_F586
  LDA #$00
  STA ram_0084_plr
  LDA #$10
  STA ram_0037_plr_timer
  STA ram_0037_plr_timer + $01
  LDA #$68
  STA ram_0034_timer
  JMP loc_C2AB



ofs_000_C2ED_02
  LDX ram_0057_script
  BNE bra_C324
  JSR sub_C81D_hide_all_sprites
  LDA #$01
  STA ram_0027_flag
  LSR ; 00
  STA ram_05FB
  LDX #$07
; 07F8-07FF
bra_C2FE_loop
  STA ram_07F8,X ; 07F8 07F9 07FA 07FB 07FC 07FD 07FE 07FF 
  DEX
  BPL bra_C2FE_loop
  LDA #$40
  STA ram_07FA
  STA ram_07FE
  LDX ram_game_mode
bra_C30E_loop
  LDA ram_plr_handler,X
  CMP #$07
  BNE bra_C31A
  LDA ram_005A_plr,X
  BEQ bra_C31A
  DEC ram_plr_lives,X
bra_C31A
  DEX
  BPL bra_C30E_loop
  LDA #$06
  STA ram_007A
  JMP loc_C218
bra_C324
  DEX
  BNE bra_C349
  DEC ram_scroll_Y
  DEC ram_scroll_Y
  LDX ram_0026_flag
  CPX #$02
  BNE bra_C338
  LDX #$00
  JSR sub_C38D
  LDX #$01
bra_C338
  JSR sub_C38D
  JSR sub_ECBF
  LDA ram_scroll_Y
  CMP #$20
  BCS bra_C38C_RTS
  LDA #$03
  JMP loc_C218
bra_C349
  DEX
  BNE bra_C353
  INC ram_0057_script
  LDX #$0A
  JMP loc_F691
bra_C353
  LDA #$00
  STA ram_plr_handler
  STA ram_plr_handler + $01
  STA ram_005A_plr
  STA ram_005A_plr + $01
  STA ram_0352_plr
  STA ram_0352_plr + $01
  LDX ram_0026_flag
  CPX #$02
  BNE bra_C370
  LDX #$00
  JSR sub_C399
  LDX #$01
bra_C370
  JSR sub_C399
  LDA #$15
  STA ram_giant_bird_Y_pos
  LDA #$00
  STA ram_00D4 + $01
  STA ram_00D4
  JSR sub_F60F
  JSR sub_F6F2
  JSR sub_E562
  LDA #con_music_logo
  STA ram_music_1
  INC ram_0051
bra_C38C_RTS
  RTS



sub_C38D
  INC ram_plr_pos_Y,X
  INC ram_plr_pos_Y,X
  LDA #$00
  STA ram_0070_plr,X
  STA ram_006C_plr,X
  BEQ bra_C39F    ; jmp



sub_C399
  LDA #$01
  STA ram_plr_handler,X
  STA ram_005A_plr,X
bra_C39F
  STX ram_plr_index
  JMP loc_CDFF



ofs_000_C3A4_05
  LDA ram_0057_script
  CMP #$06
  BEQ bra_C3CC
  JSR sub_C1D7
  LDA ram_0057_script
  CMP #$05
  BNE bra_C3CB_RTS
  LDA ram_0053_flag
  BNE bra_C3C1
  LDA #$00
  LDX #$0E
; 07F0-07FE
bra_C3BB_loop
  STA ram_07F0,X
  DEX
  BPL bra_C3BB_loop
bra_C3C1
  JSR sub_C81D_hide_all_sprites
  JSR sub_F60F
  INC ram_0057_script
  DEC ram_0051
bra_C3CB_RTS
  RTS
bra_C3CC
  LDX #$0A
  JSR sub_F691
  LDA #$70
  STA ram_giant_bird_X_pos
  ASL ; E0
  STA ram_giant_bird_Y_pos
  LDA #$00
  STA ram_00D4
  STA ram_00D4 + $01
  LDA #$04
  STA ram_001F_timer
  LSR ; 02
  STA ram_007A
  JMP loc_C2A7



ofs_001_C3E8_05
  LDA ram_giant_bird_Y_pos
  CMP #$1D
  BCC bra_C423
  CMP #$80
  BNE bra_C419
  DEC ram_scroll_Y
  DEC ram_scroll_Y
  JSR sub_D8EA
  LDA ram_scroll_Y
  CMP #$02
  BCS bra_C40B
  LDX ram_007A
  BEQ bra_C419
  LDA #$03
  DEX
  BEQ bra_C409
  ASL ; 06
bra_C409
  STA ram_buffer_offset
bra_C40B
  DEC ram_001F_timer
  BNE bra_C416
  LDA #$04
  STA ram_001F_timer
  JSR sub_F2EC
bra_C416
  JMP loc_C41D
bra_C419
  DEC ram_giant_bird_Y_pos
  DEC ram_giant_bird_Y_pos
loc_C41D
  JSR sub_F737
  JMP loc_F67E
bra_C423
  LDA ram_0046_timer
  BNE bra_C42B
  LDA #$10
  STA ram_0046_timer
bra_C42B
  CMP #$01
  BNE bra_C436_RTS
  LDA #$01
  JSR sub_D4F5
  DEC ram_0054_timer
bra_C436_RTS
  RTS



sub_C437
  LDA ram_0034_timer
  BNE bra_C436_RTS
  JSR sub_C726_jump_to_pointers_after_jsr___0055
  dw ofs_000_C166_00
  dw ofs_000_C1D7_01
  dw ofs_000_C2ED_02
  dw ofs_000_C2AD_03
  dw ofs_000_C2B0_04
  dw ofs_000_C3A4_05



sub_C44A
  LDA #$00
  STA ram_0057_script
  JSR sub_C726_jump_to_pointers_after_jsr___0055
  dw ofs_001_C460_00
  dw ofs_001_CBFB_01
  dw ofs_001_CC9E_02
  dw ofs_001_CC67_03
  dw ofs_001_CC6C_04
  dw ofs_001_C3E8_05



tbl_C45D_game_mode_cursor
  db $6F   ; spr_T
  db $00   ; spr_A
  db $38   ; spr_X



ofs_001_C460_00
  LDA ram_mountain_current
  AND #$1F
  STA ram_mountain_current
  JSR sub_F53E
  LDA ram_spawn_timer_lo_bird
  BNE bra_C484_not_demo_yet
; A = 00
  STA $4015
  STA ram_game_mode
  LDA ram_mountain_current
  STA ram_03FE
  LDA ram_03FD
  AND #$03
  STA ram_mountain_current
  LDA #$01
  STA ram_0053_flag
  BNE bra_C4A4    ; jmp
bra_C484_not_demo_yet
  LDA ram_004D_timer
  CMP #$01
  BNE bra_C490_logo_music_still_plays
; A = 01
  LSR ; 00
  STA ram_004D_timer
  ROR ; con_music_off
  STA ram_music_1
bra_C490_logo_music_still_plays
  LDA ram_btn_press
  AND #con_btn_Select
  BEQ bra_C49E
  JSR sub_C4BA_toggle_game_mode_and_update_cursor
  LDA #$80
  STA ram_spawn_timer_lo_bird
  RTS
bra_C49E
  LDA ram_btn_press
  AND #con_btn_Start
  BEQ bra_C4B9_RTS
bra_C4A4
  LDA #$05
  JSR sub_D4F5
  LDA #con_music_mountain_preview
  STA ram_music_1
  LDA #$03
  STA ram_plr_lives
  LDY ram_game_mode
  BNE bra_C4B7    ; if 2p
; if 1p, disable lives for 2p
  LDA #$FC
bra_C4B7
  STA ram_plr_lives + $01
bra_C4B9_RTS
  RTS



sub_C4BA_toggle_game_mode_and_update_cursor
  LDA ram_game_mode
  EOR #$01
  STA ram_game_mode
sub_C4C0_update_game_mode_cursor
  LDA #$7F
  LDY ram_game_mode
  BEQ bra_C4C8    ; if 1p
; if 2p
  LDA #$8F
bra_C4C8
  STA ram_spr_Y
  LDX #$02
bra_C4CD_loop
  LDA tbl_C45D_game_mode_cursor,X
  STA ram_oam + $01,X
  DEX
  BPL bra_C4CD_loop
  RTS



sub_C4D7
  LDY #$17
bra_C4D9_loop
  LDA #$00
  STA ram_0400_data + $C0,Y
  LDA #$FF
  STA ram_0500_data + $C0,Y
  DEY
  BPL bra_C4D9_loop
  LDY #$01
bra_C4E8_loop
  STA ram_0400_data + $C3,Y
  STA ram_0400_data + $CB,Y
  STA ram_0400_data + $D3,Y
  DEY
  BPL bra_C4E8_loop
  LDX #$00
bra_C4F6_loop
  LDA #$00
  STA ram_0400_data + $30,X ; 0430 0448 0460 0478 0490 04A8 
  STA ram_0400_data + $47,X ; 0447 045F 0477 048F 04A7 04BF 
  CPX #$48
  BCC bra_C508
  STA ram_0400_data + $31,X ; 0479 0491 04A9 
  STA ram_0400_data + $46,X ; 048E 04A6 04BE 
bra_C508
  TXA
  CLC
  ADC #$18
  TAX
  CPX #$90
  BCC bra_C4F6_loop
  RTS



tbl_C512
  db $00, $00, $00   ; 00 
  db $FF, $FF, $FF   ; 01 
  db $F3, $E7, $CF   ; 02 
  db $33, $33, $33   ; 03 
  db $0F, $0F, $0F   ; 04 
  db $33, $00, $CC   ; 05 
  db $FF, $0F, $FF   ; 06 
  db $C3, $FC, $3F   ; 07 
  db $F0, $F0, $F0   ; 08 
  db $F0, $00, $0F   ; 09 
  db $CF, $CF, $3F   ; 0A 
  db $F0, $00, $FF   ; 0B 
  db $CC, $CC, $CC   ; 0C 
  db $F3, $33, $00   ; 0D 
  db $FC, $FC, $FF   ; 0E 
  db $FC, $00, $3F   ; 0F 



sub_C542_generate_map
  JSR sub_E72B
  LDA #$BF    ; max address offset?
  STA ram_000C
  LDA #< ram_0400_data
  STA ram_000D
  LDA #> ram_0400_data
  STA ram_000E
  LDX #$07
bra_C553_loop
  LDA ram_0004,X
  ASL
  CLC
  ADC ram_0004,X
  TAY
  LDA tbl_C512,Y
  STA ram_0000
  LDA tbl_C512 + $01,Y
  STA ram_0001
  LDA tbl_C512 + $02,Y
  STA ram_0002
  LDY ram_000C
  LDA #$01
  STA ram_001F_timer
  JSR sub_C5D3_generate_map
  STY ram_000C
  DEX
  BPL bra_C553_loop
  LDX #$C0
bra_C579_loop
  LDA #$00
  ASL ram_0785
  BCS bra_C582
  LDA #$01
bra_C582
  STA ram_0000
  LDY #$18
bra_C586_loop
; 0400-04BF
  LDA ram_0400_data - $01,X
  BMI bra_C592
  LDA ram_0000
  STA ram_0400_data - $01,X
  BNE bra_C597
bra_C592
  LDA #$FF
; 0518-05BF
  STA ram_0500_data - $01,X
bra_C597
  DEX
  BEQ bra_C5D2_RTS
  DEY
  BNE bra_C586_loop
  BEQ bra_C579_loop   ; jmp



tbl_C59F
  db $F0   ; 00 
  db $0F   ; 01 
  db $E7   ; 02 
  db $3C   ; 03 
  db $FC   ; 04 
  db $3F   ; 05 
  db $CF   ; 06 
  db $E3   ; 07 



sub_C5A7_generate_map
  LDY #$D7
bra_C5A9_loop
  TYA
  PHA
  JSR sub_CACE_generate_random
  LDX #$02
bra_C5B0_loop
  LDA ram_random,X
  AND #$07
  TAY
  LDA tbl_C59F,Y
  STA ram_0000,X
  DEX
  BPL bra_C5B0_loop
  PLA
  TAY
  LDA #< ram_0500_data
  STA ram_000D
  LDA #> ram_0500_data
  STA ram_000E
  LDA #$00
  STA ram_001F_timer
  JSR sub_C5D3_generate_map
  CPY #$FF
  BNE bra_C5A9_loop
bra_C5D2_RTS
  RTS



sub_C5D3_generate_map
  LDA #$00
  STA ram_000F
  LDA #$18
  STA ram_0003    ; loop counter
bra_C5DB_loop
  LSR ram_0000
  ROR ram_0001
  ROR ram_0002
  PHP
  LDA ram_001F_timer
  BNE bra_C5ED
  LDA ram_000F
  BEQ bra_C5EF
  LDA #$01
  db $2C   ; BIT opcode
bra_C5ED
  LDA #$00
bra_C5EF
  ROL
  BEQ bra_C5FC
  CMP #$03
  BCS bra_C5F9
  LDA #$02
  db $2C   ; BIT opcode
bra_C5F9
  LDA #$01
  db $2C   ; BIT opcode
bra_C5FC
  LDA #$FF
; 0400-04BF, 0500-05D7
  STA (ram_000D),Y
  PLP
  BCS bra_C608
  LDA #$00
  STA ram_000F
  db $2C   ; BIT opcode
bra_C608
  INC ram_000F
  DEY
  DEC ram_0003    ; loop counter
  BNE bra_C5DB_loop
bra_C60F_RTS
  RTS



tbl_C610
  db $11   ; 00 
  db $22   ; 01 
  db $11   ; 02 
  db $38   ; 03 
  db $29   ; 04 
  db $28   ; 05 
  db $19   ; 06 
  db $21   ; 07 
  db $1A   ; 08 
  db $28   ; 09 
  db $2A   ; 0A 
  db $12   ; 0B 
  db $2A   ; 0C 
  db $22   ; 0D 
  db $14   ; 0E 
  db $12   ; 0F 



sub_C620
  LDA ram_btn_hold
  AND #con_btns_SS
  BEQ bra_C63A
bra_C626
  LDA ram_03FE
  STA ram_mountain_current
  LDA #$0F
  STA $4015
  LDA #$00
  STA ram_0053_flag
  INC ram_03FD
  JMP loc_D4F5
bra_C63A
  LDA ram_0055
  CMP #$01
  BNE bra_C60F_RTS
  LDA ram_0051
  BEQ bra_C60F_RTS
  LDA ram_plr_pos_Y
  CMP #$D4
  BCS bra_C626
  LDA ram_03FA
  AND #$0F
  TAX
  LDA tbl_C610,X
  LDY tbl_C610 - $01,X
  LDX ram_03FB
  BNE bra_C664
  TAY
  AND #$F0
  STA ram_03FB
  INC ram_03FA
bra_C664
  TYA
  AND #con_btns_Dpad
  STA ram_btn_hold
  TYA
  ASL
  ASL
  ASL
  ASL
  ORA ram_btn_hold
  AND #con_btns_AB + con_btns_LR
  STA ram_btn_hold
  STA ram_btn_press
  LDA ram_frm_cnt
  AND #$01
  BNE bra_C67F_RTS
  DEC ram_03FB
bra_C67F_RTS
  RTS



tbl_C680
; 00 
  ddb $22CD ; 
  db $05   ; 
  db $00   ; placeholder
; 01 
  ddb $2306 ; 
  db $05   ; 
  db $00   ; placeholder
; 02 
  ddb $2314 ; 
  db $05   ; 
  db $00   ; placeholder
; 03 
  ddb $28C3 ; 
  db $04   ; 
  db $00   ; placeholder
; 04 
  ddb $20C3 ; 
  db $04   ; 
  db $00   ; placeholder



; for _off000_
con_00                                  = $00 ; horisontally write ?? tiles
con_40                                  = $40 ; horisontally write a tile ?? times
con_80                                  = $80 ; vertically write ?? tiles
con_C0                                  = $C0 ; vertically write a tile ?? times



_off000_C694_04
  ddb $3F00 ; 
  db con_00 + $20   ; 
  db $0F, $30, $21, $01   ; 
  db $0F, $26, $2A, $30   ; 
  db $0F, $38, $29, $0A   ; 
  db $0F, $27, $17, $07   ; 

  db $0F, $30, $11, $26   ; 
  db $0F, $30, $15, $26   ; 
  db $0F, $30, $21, $12   ; 
  db $0F, $38, $29, $0A   ; 

  db $00   ; end token



_off000_C6B8_02
  ddb $23E8 ; 
  db con_40 + $18   ; 
  db $FF   ; 

  ddb $23E0 ; 
  db con_00 + $02   ; 
  db $F0, $30   ; 

  ddb $23E6 ; 
  db con_00 + $02   ; 
  db $C0, $F0   ; 

  ddb $2BC0 ; 
  db con_40 + $08   ; 
  db $FF   ; 

  ddb $2BC8 ; 
  db con_40 + $08   ; 
  db $AF   ; 

  ddb $2BD0 ; 
  db con_40 + $10   ; 
  db $AA   ; 

  ddb $2BE0 ; 
  db con_40 + $08   ; 
  db $0A   ; 

  ddb $2BC9 ; 
  db con_40 + $06   ; 
  db $FF   ; 

  ddb $2A40 ; 
  db con_40 + $20   ; 
  db $31   ; 

  ddb $2A60 ; 
  db con_40 + $3F   ; 
  db $32   ; 

  db $00   ; end token



_off000_C6E3_03
  ddb $23E0 ; 
  db con_40 + $20   ; 
  db $00   ; 

  ddb $23C8 ; 
  db con_00 + $02   ; 
  db $44, $55   ; 

  db $00   ; end token



_off000_C6ED_06
  ddb $2BC0 ; 
  db con_40 + $31   ; 
  db $00   ; 

  ddb $2BC8 ; 
  db con_00 + $02   ; 
  db $44, $55   ; 

  db $00   ; end token



tbl_C6F7_ppu_lo
  db < _off000_0x0050B0_05_00   ; 00 
  db < _off000_0x005214_05_01   ; 01 



tbl_C6F9_ppu_hi
  db > _off000_0x0050B0_05_00   ; 00 
  db > _off000_0x005214_05_01   ; 01 



sub_C6FB_copy_data_from_ppu
  JSR sub_C891_write_00_to_2001
  LDA tbl_C6F9_ppu_hi,X
  STA $2006
  LDA tbl_C6F7_ppu_lo,X
  STA $2006
  LDA $2007   ; dummy read
  LDA #< ram_0400_data
  STA ram_0000
  TAY ; 00
  LDA #> ram_0400_data
  STA ram_0001
  LDX #$02
bra_C718_loop
; 0400-05FF
  LDA $2007   ; actual read
  STA (ram_0000),Y
  INY
  BNE bra_C718_loop
  INC ram_0001
  DEX
  BNE bra_C718_loop
  RTS



sub_C726_jump_to_pointers_after_jsr___0055
  LDA ram_0055
sub_C728_jump_to_pointers_after_jsr
  ASL
  TAY
  PLA
  STA ram_0000
  PLA
  STA ram_0001
  INY
  LDA (ram_0000),Y
  STA ram_0002
  INY
  LDA (ram_0000),Y
  STA ram_0003
  JMP (ram_0002)



loc_C73D
  STA ram_0003
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
bra_C759_loop
  ADC ram_0007
  DEX
  BNE bra_C759_loop
  STA ram_0008
  TAX
  LDA ram_000E
  BEQ bra_C76F
  JSR sub_C777
  LDA ram_000F
  BEQ bra_C76F
  JSR sub_C7C1
bra_C76F
  JSR sub_C7F5
  PLA
  TAY
  PLA
  TAX
  RTS



sub_C777
  LDA ram_0002
  LDY #$01
bra_C77B_loop
  STA (ram_0004),Y
  CLC
  ADC #$01
  INY
  PHA
  LDA (ram_0004),Y
  AND #$3F
  STA (ram_0004),Y
  TXA
  PHA
  LDA ram_000D
  AND #$03
  LDX ram_0009
  CPX #$03
  BMI bra_C7A5
  CPX #$18
  BCS bra_C7A5
  LDX ram_0055
  DEX
  BNE bra_C7A5
  LDX ram_0009
  CPX #$03
  BEQ bra_C7A5
  ORA #$20
bra_C7A5
  STA (ram_0004),Y
  PLA
  TAX
  LSR ram_000A
  ROR ram_000B
  ROR ram_000C
  ROR ram_000D
  LSR ram_000A
  ROR ram_000B
  ROR ram_000C
  ROR ram_000D
  PLA
  INY
  INY
  INY
  DEX
  BNE bra_C77B_loop
  RTS



sub_C7C1
  LDY #$01
  STY ram_000A
  LDA ram_0008
  SEC
  SBC ram_0006
bra_C7CA_loop
  TAY
  STA ram_000B
  LDX ram_0006
bra_C7CF_loop
  TYA
  PHA
  CLC
  TYA
  ADC ram_0002
  LDY ram_000A
  STA (ram_0004),Y
  INY
  LDA (ram_0004),Y
  AND #$3F
  EOR #$40
  STA (ram_0004),Y
  INY
  INY
  INY
  STY ram_000A
  PLA
  TAY
  INY
  DEX
  BNE bra_C7CF_loop
  LDA ram_000B
  SEC
  SBC ram_0006
  BPL bra_C7CA_loop
  RTS



sub_C7F5
  LDY #$00
bra_C7F7_loop
  LDX ram_0006
  LDA ram_0001
  STA ram_0009
bra_C7FD_loop
  LDA ram_0009
  STA (ram_0004),Y
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
  BNE bra_C7FD_loop
  LDA ram_0000
  CLC
  ADC #$08
  STA ram_0000
  DEC ram_0007
  BNE bra_C7F7_loop
  RTS



loc_C81D_hide_all_sprites
sub_C81D_hide_all_sprites
  LDX #$40
  LDA #$00
sub_C821_hide_sprites_starting_from_A
loc_C821_hide_sprites_starting_from_A
  STA ram_0004
  LDA #> ram_oam
  STA ram_0005
  LDY #$00
bra_C829_loop
  LDA #$F8
  STA (ram_0004),Y
  INY
  INY
  LDA #$00
  STA (ram_0004),Y
  INY
  INY
  DEX
  BNE bra_C829_loop
  RTS



tbl_C839_lo
  db $22   ; 00 
  db $17   ; 01 
  db $22   ; 02 
  db $27   ; 03 



sub_C83D
  STX ram_000F
  TAX
  LDA ram_00E0_plr,X
  BNE bra_C853
  STA ram_00E6_plr,X
  LDA #$08
  STA ram_00E8_plr,X
  LDA #$F0
  STA ram_00EA_plr,X
  INC ram_00E0_plr,X
  JMP loc_C868
bra_C853
  LDA ram_00E6_plr,X
  CMP #$08
  BCS bra_C868
  LDY ram_002F_plr,X
  LDA ram_00E8_plr,X
  ADC tbl_C839_lo,Y
  STA ram_00E8_plr,X
  LDA ram_00E6_plr,X
  ADC #$00
  STA ram_00E6_plr,X
bra_C868
loc_C868
  LDA ram_00EA_plr,X
  SEC
  SBC ram_00E2_plr,X
  STA ram_00EA_plr,X
  LDA ram_0001
  SBC ram_00E4_plr,X
  PHA
  CLC
  LDA ram_00EA_plr,X
  ADC ram_00E8_plr,X
  STA ram_00EA_plr,X
  PLA
  ADC ram_00E6_plr,X
  STA ram_0001
  LDX ram_000F
  RTS



sub_C883
  LDA #$10
  JSR sub_C148_set_2000
  LDA #$00
  STA ram_scroll_X
  STA ram_scroll_Y
  JMP loc_CB81_set_scroll



sub_C891_write_00_to_2001
  LDA #$00
  STA $2001
  RTS


; bzk garbage
  JSR sub_C15D



sub_C89A
  JSR sub_C891_write_00_to_2001
  LDA #$20
  JSR sub_C8A4
  LDA #$28
sub_C8A4
  STA ram_0000
  LDA $2002
  LDA ram_for_2000
  AND #$FB
  STA $2000
  LDA ram_0000
  STA $2006
  LDA #$00
  STA $2006
  TAY ; 00
  LDX #$04
  LDA #$38
bra_C8BF_loop
  STA $2007
  DEY
  BNE bra_C8BF_loop
  DEX
  BNE bra_C8BF_loop
  LDA ram_0000
  CLC
  ADC #$03
  STA $2006
  LDA #$C0
  STA $2006
  LDY #$40
  LDA #$00
bra_C8D9_loop
  STA $2007
  DEY
  BNE bra_C8D9_loop
  RTS



sub_C8E0
loc_C8E0
  STA ram_0000
  LDX ram_0000
  JSR sub_C8EE
  LDA ram_0000
  LSR
  LSR
  LSR
  LSR
  TAX
sub_C8EE
  INX
  TXA
  AND #$0F
  CMP #$09
  BCS bra_C94A_RTS
  ASL
  ASL
  TAY
  LDX ram_buffer_index
  LDA tbl_C680,Y
  STA ram_ppu_buffer,X
  JSR sub_CB8C
  INY
  LDA tbl_C680,Y
  STA ram_ppu_buffer,X
  JSR sub_CB8C
  INY
  LDA tbl_C680,Y
  AND #$07
  STA ram_ppu_buffer,X
  STA ram_0001
  TXA
  SEC
  ADC ram_0001
  JSR sub_CB8E
  TAX
  STX ram_buffer_index
  LDA #$00
  STA ram_ppu_buffer,X
  INY
bra_C92B_loop
  DEX
  LDA ram_07EC,Y
  AND #$0F
  STA ram_ppu_buffer,X
  DEC ram_0001
  BEQ bra_C94A_RTS
  DEX
  LDA ram_07EC,Y
  AND #$F0
  LSR
  LSR
  LSR
  LSR
  STA ram_ppu_buffer,X
  DEY
  DEC ram_0001
  BNE bra_C92B_loop
bra_C94A_RTS
  RTS



sub_C94B
  LDX #$FF
  db $2C   ; BIT opcode
sub_C94E
  LDX #$00
  STA ram_0000
  STX ram_0004
  LDX #$00
  STX ram_0005
  STX ram_0006
  STX ram_0007
  LDA ram_0001
  AND #$08
  BNE bra_C963
  INX
bra_C963
  LDA ram_0000
  STA ram_0006,X
  LDA ram_0001
  AND #$07
  ASL
  ASL
  TAX
  LDA ram_0004
  BEQ bra_C995
  LDA ram_07F0,X
  BEQ bra_C99A
bra_C977
  CLC
  JSR sub_CA44
  JSR sub_C9D7
  JSR sub_CA2C
  STA ram_0003
  LDA ram_0006
  JSR sub_C9D7
  JSR sub_CA36
  STA ram_0003
  LDA ram_0005
  JSR sub_C9D7
  JMP loc_CA40
bra_C995
  LDA ram_07F0,X
  BEQ bra_C977
bra_C99A
  SEC
  JSR sub_CA44
  JSR sub_CA29
  STA ram_0003
  LDA ram_0006
  JSR sub_CA33
  STA ram_0003
  LDA ram_0005
  JSR sub_CA3D
  BNE bra_C9BB
  LDA ram_07F2,X
  BNE bra_C9BB
  LDA ram_07F3,X
  BEQ bra_C9C2
bra_C9BB
  BCS bra_C9D6_RTS
  LDA ram_07F0,X
  EOR #$FF
bra_C9C2
  STA ram_07F0,X
  SEC
  LDA #$00
  STA ram_0003
  LDA ram_07F3,X
  JSR sub_CA29
  JSR sub_CA33
  JSR sub_CA3D
bra_C9D6_RTS
  RTS



sub_C9D7
  JSR sub_CA1A
  ADC ram_0001
  CMP #$0A
  BCC bra_C9E2
  ADC #$05
bra_C9E2
  CLC
  ADC ram_0002
  STA ram_0002
  LDA ram_0003
  AND #$F0
  ADC ram_0002
  BCC bra_C9F3
bra_C9EF
  ADC #$5F
  SEC
  RTS
bra_C9F3
  CMP #$A0
  BCS bra_C9EF
  RTS



sub_C9F8
  JSR sub_CA1A
  SBC ram_0001
  STA ram_0001
  BCS bra_CA0B
  ADC #$0A
  STA ram_0001
  LDA ram_0002
  ADC #$0F
  STA ram_0002
bra_CA0B
  LDA ram_0003
  AND #$F0
  SEC
  SBC ram_0002
  BCS bra_CA17
  ADC #$A0
  CLC
bra_CA17
  ORA ram_0001
  RTS



sub_CA1A
  PHA
  AND #$0F
  STA ram_0001
  PLA
  AND #$F0
  STA ram_0002
  LDA ram_0003
  AND #$0F
  RTS



sub_CA29
  JSR sub_C9F8
sub_CA2C
  STA ram_07F3,X
  LDA ram_07F2,X
  RTS



sub_CA33
  JSR sub_C9F8
sub_CA36
  STA ram_07F2,X
  LDA ram_07F1,X
  RTS



sub_CA3D
  JSR sub_C9F8
loc_CA40
  STA ram_07F1,X
  RTS



sub_CA44
  LDA ram_07F3,X
  STA ram_0003
  LDA ram_0007
  RTS



sub_CA4C
  LDA #$00
  STA ram_0004
  CLC
  LDA ram_0000
  ADC #$10
  AND #$F0
  LSR
  LSR
  TAY
  LDA ram_0000
  AND #$07
  ASL
  ASL
  TAX
bra_CA61_loop
  LDA ram_07EC,Y
  BEQ bra_CAC1
  LDA ram_07F0,X
  BEQ bra_CA94
bra_CA6B
  SEC
  LDA ram_07EF,Y
  STA ram_0003
  LDA ram_07F3,X
  JSR sub_C9F8
  LDA ram_07EE,Y
  STA ram_0003
  LDA ram_07F2,X
  JSR sub_C9F8
  LDA ram_07ED,Y
  STA ram_0003
  LDA ram_07F1,X
  JSR sub_C9F8
  BCS bra_CAC6
  LDA ram_07EC,Y
  BNE bra_CACB
bra_CA94
  LDA #$FF
  STA ram_0004
  SEC
bra_CA99
  TYA
  BNE bra_CAC0_RTS
  BCC bra_CAB4
  TXA
  PHA
  TYA
  PHA
  LDY #$00
bra_CAA4_loop
  LDA ram_07F0,X
  STA ram_07EC,Y
  INX
  INY
  CPY #$04
  BCC bra_CAA4_loop
  PLA
  TAY
  PLA
  TAX
bra_CAB4
  LDA ram_0000
  AND #$08
  BEQ bra_CAC0_RTS
  DEX
  DEX
  DEX
  DEX
  BPL bra_CA61_loop
bra_CAC0_RTS
  RTS
bra_CAC1
  LDA ram_07F0,X
  BEQ bra_CA6B
bra_CAC6
  LDA ram_07EC,Y
  BNE bra_CA94
bra_CACB
  CLC
  BCC bra_CA99    ; jmp



sub_CACE_generate_random
  LDX #$00
  LDY #$05
  LDA ram_random
  BNE bra_CAD8
  LDA #$37
bra_CAD8
  AND #$02
  STA ram_0000
  LDA ram_random + $01
  AND #$02
  EOR ram_0000
  CLC
  BEQ bra_CAE6
  SEC
bra_CAE6
bra_CAE6_loop
  ROR ram_random,X
  INX
  DEY
  BNE bra_CAE6_loop
  RTS



sub_CAED_read_joy_regs
  JSR sub_CB35
  LDA #$01
  STA $4016
  LDX #$00
  LDA #$00
  STA $4016
  JSR sub_CB00
  INX
sub_CB00
  LDY #$08
bra_CB02_loop
  PHA
  LDA $4016,X
  STA ram_0000
  LSR
  ORA ram_0000
  LSR
  PLA
  ROL
  DEY
  BNE bra_CB02_loop
  STX ram_0000
  ASL ram_0000
  LDX ram_0000
  LDY ram_btn_hold,X
  STY ram_0000
  STA ram_btn_hold,X
  STA ram_btn_press,X
  LDY #$04
bra_CB21_loop
  LDA ram_0002
  BIT ram_0000
  BEQ bra_CB2D
  LDA ram_btn_press,X
  AND ram_0001
  STA ram_btn_press,X
bra_CB2D
  SEC
  ROR ram_0001
  LSR ram_0002
  DEY
  BNE bra_CB21_loop
sub_CB35
  LDA #$7F
  STA ram_0001
  LDA #$80
  STA ram_0002
  RTS



bra_CB3E_loop
  STA $2006
  INY
  LDA (ram_0000),Y
  STA $2006
  INY
  LDA (ram_0000),Y
  ASL
  PHA
  LDA ram_for_2000
  ORA #$04
  BCS bra_CB54
  AND #$FB
bra_CB54
  JSR sub_C148_set_2000
  PLA
  ASL
  BCC bra_CB5E
  ORA #$02
  INY
bra_CB5E
  LSR
  LSR
  TAX
bra_CB61_loop
  BCS bra_CB64
  INY
bra_CB64
  LDA (ram_0000),Y
  STA $2007
  DEX
  BNE bra_CB61_loop
  SEC
  TYA
  ADC ram_0000
  STA ram_0000
  LDA #$00
  ADC ram_0001
  STA ram_0001
sub_CB78
  LDX $2002
  LDY #$00
  LDA (ram_0000),Y
  BNE bra_CB3E_loop
; if buffer is closed
sub_CB81_set_scroll
loc_CB81_set_scroll
  LDA ram_scroll_X
  STA $2005
  LDA ram_scroll_Y
  STA $2005
  RTS



sub_CB8C
  INX
  TXA
sub_CB8E
  CMP #$3F
  BCC bra_CB9C_RTS
  LDX ram_buffer_index
  LDA #$00
  STA ram_ppu_buffer,X
  PLA
  PLA
bra_CB9C_RTS
  RTS



sub_CB9D_decrease_all_timers
  LDX #$09    ; 0032-003B
  DEC ram_main_timer
  BPL bra_CBA9
  LDA #$0A
  STA ram_main_timer
  LDX #$1D    ; 0032-004F
bra_CBA9
bra_CBA9_loop
  LDA ram_timers,X
  BEQ bra_CBAF
; if timer is still ticking
  DEC ram_timers,X
bra_CBAF
  DEX
  BPL bra_CBA9_loop
  RTS



tbl_CBB3
  db $5C   ; 00 
  db $62   ; 01 
  db $5C   ; 02 
  db $56   ; 03 
  db $6E   ; 04 
  db $74   ; 05 
  db $8C   ; 06 
  db $92   ; 07 
  db $7A   ; 08 
  db $80   ; 09 
  db $86   ; 0A 
  db $00   ; 0B 



tbl_CBBF_oam_lo
  db < (ram_spr_Y + $00)   ; 00 
  db < (ram_spr_Y + $24)   ; 01 



tbl_CBC1
  db $D6   ; 00 
  db $17   ; 01 
  db $6E   ; 02 
  db $6F   ; 03 
  db $16   ; 04 



tbl_CBC6
; 00 
  db $10, $08   ; 
  db $F8, $08   ; 
; 01 
  db $08, $F8   ; 
  db $00, $F8   ; 
; 02 
  db $08, $F8   ; 
  db $00, $F8   ; 
; 03 
  db $F8, $00   ; 
  db $10, $00   ; 
; 04 
  db $F8, $10   ; 
  db $10, $10   ; 



tbl_CBDA
  db $FF   ; 00 
  db $01   ; 01 



tbl_CBDC
  db $F2, $F0   ; 00 
  db $49, $50   ; 01 
  db $79, $80   ; 02 
  db $A9, $B0   ; 03 
  db $D9, $E2   ; 04 
  db $F1, $FA   ; 05 



tbl_CBE8
  db $4A   ; 00 
  db $7A   ; 01 
  db $AA   ; 02 
  db $DA   ; 03 
  db $F5   ; 04 



tbl_CBED
  db $80   ; 00 
  db $40   ; 01 
  db $20   ; 02 
  db $10   ; 03 
  db $08   ; 04 
  db $04   ; 05 
  db $02   ; 06 
  db $01   ; 07 



tbl_CBF5
  db $00   ; 00 
  db $04   ; 01 
  db $08   ; 02 



tbl_CBF8
  db $04   ; 00 
  db $02   ; 01 
  db $FE   ; 02 



ofs_001_CBFB_01
  LDA ram_008C_flag
  BNE bra_CC5E
  LDA ram_btn_press
  STA ram_0070_plr
  LDX #$00
  JSR sub_CD13
  LDX #$00
  JSR sub_DA99
  LDA ram_game_mode
  BEQ bra_CC1F    ; if 1p
; if 2p
  LDA ram_btn_press + $02
  STA ram_0070_plr + $01
  LDX #$01
  JSR sub_CD13
  LDX #$01
  JSR sub_DA99
bra_CC1F
  JSR sub_EFEC
  JSR sub_E189
  JSR sub_DC6A
  JSR sub_D1E5
  JSR sub_DE22
  JSR sub_EE0D
  JSR sub_EF9A
  JSR sub_F10B
  JSR sub_D3AC
  JSR sub_D212
  JSR sub_D301
  JSR sub_EB7F
  JSR sub_EC23
  JSR sub_F838
  JSR sub_D493
  JSR sub_E29A
  JSR sub_E0B9
  JSR sub_D9CC
  JSR sub_DA4B
  JSR sub_EB2E
  JSR sub_ECBF
bra_CC5E
  JSR sub_D463
  JSR sub_D82F
  JMP loc_D7DE



ofs_001_CC67_03
  LDA #$04
  JMP loc_D4F5



ofs_001_CC6C_04
  JSR sub_F471
  JSR sub_E88F
  LDA ram_0045_timer
  BEQ bra_CC7B
  CMP #$01
  BEQ bra_CC7E
  RTS
bra_CC7B
  JMP loc_E8F2
bra_CC7E
  LDA ram_plr_lives
  CMP #$80
  BEQ bra_CC97
  INC ram_mountain_current
  LDA ram_mountain_current
  CMP #$63
  BCC bra_CC90_not_overflow
  LDA #$00
  STA ram_mountain_current
bra_CC90_not_overflow
  INC ram_mountain_completed
  LDA #$01
  JMP loc_D4F5
bra_CC97
  LDA #$00
  STA ram_0051
  STA ram_0055
  RTS



ofs_001_CC9E_02
  LDA #$06
  CMP ram_plr_handler
  BEQ bra_CCED
  CMP ram_plr_handler + $01
  BEQ bra_CCED
  LDA ram_008C_flag
  BNE bra_CCE4
  LDX ram_0026_flag
  CPX #$02
  BNE bra_CCB9
  LDX #$00
  JSR sub_CCF6
  LDX #$01
bra_CCB9
  JSR sub_CCF6
  JSR sub_D212
  JSR sub_F78B
  JSR sub_D301
  JSR sub_F6A4
  JSR sub_F71D
  JSR sub_EB2E
  JSR sub_E277
  JSR sub_E33C
  JSR sub_ECBF
  LDA ram_008D
  CMP #$2F
  BMI bra_CCE1
  LDA ram_0027_flag
  BNE bra_CCE4
bra_CCE1
  JSR sub_F2EC
bra_CCE4
  JSR sub_D724
  JSR sub_D8AF
  JMP loc_D890
bra_CCED
  LDA ram_004D_timer
  BNE bra_CD12_RTS
  LDA #$03
  JMP loc_D4F5



sub_CCF6
  STX ram_plr_index
  TXA
  ASL
  TAY
  LDA ram_btn_press,Y
  STA ram_0070_plr,X
  JSR sub_D552
  LDA ram_0352_plr,X
  BNE bra_CD0D
  LDX ram_plr_index
  JSR sub_D59C
bra_CD0D
  LDX ram_plr_index
  JSR sub_D507
bra_CD12_RTS
  RTS



sub_CD13
  STX ram_plr_index
  LDA ram_005A_plr,X
  BEQ bra_CD61_RTS
  LDY ram_plr_handler,X
  DEY
  TYA
  JSR sub_C728_jump_to_pointers_after_jsr
  dw ofs_002_CD32_01
  dw ofs_002_CE5D_02
  dw ofs_002_CD38_03
  dw ofs_002_D008_04
  dw ofs_002_D05D_05
  dw ofs_002_D008_06
  dw ofs_002_D0AA_07
  dw ofs_002_D008_08
  dw ofs_002_D500_09_RTS



ofs_002_CD32_01
  JSR sub_CDB0
  JMP loc_CD3B



ofs_002_CD38_03
  JSR sub_CFC6
loc_CD3B
  JSR sub_CD62
  BCS bra_CD61_RTS
  LDA #$05
  STA ram_00E8_plr,X
  STA ram_006E_plr,X
  LDA #$04
  STA ram_00E6_plr,X
  LSR ; 02
  STA ram_plr_handler,X
  LSR ; 01
  STA ram_00E0_plr,X
  STA ram_0086_plr,X
  LSR ; 00
  STA ram_0088_plr,X
  LDY ram_0068_plr,X
  BEQ bra_CD61_RTS
  LDA tbl_CBF8,Y
  CLC
  ADC ram_plr_pos_X,X
  STA ram_plr_pos_X,X
bra_CD61_RTS
  RTS



sub_CD62
  LDA #$00
  STA ram_0082_plr,X
  LDA #$06
bra_CD68_loop
  STA ram_0001
  LDA ram_plr_pos_X,X
  CLC
  ADC ram_0001
  JSR sub_DBB4
  BMI bra_CD83
  CMP #$04
  BNE bra_CD8B
  INY
  LDA (ram_0003),Y
  BPL bra_CD8B
  DEY
  DEY
  LDA (ram_0003),Y
  BPL bra_CD8B
bra_CD83
  LDA #$09
  CMP ram_0001
  BNE bra_CD68_loop
  CLC
  RTS
bra_CD8B
  SEC
  RTS



tbl_CD8D
  db $02   ; 00 
  db $09   ; 01 
  db $06   ; 02 
  db $04   ; 03 



tbl_CD91
  db $04   ; 00 
  db $02   ; 01 
  db $02   ; 02 
  db $04   ; 03 



sub_CD95
  INC ram_0060_plr,X
  LDA ram_0060_plr,X
  CMP tbl_CD8D,Y
  BCC bra_CDAF_RTS
  LDA #$00
  STA ram_0060_plr,X
  INC ram_006C_plr,X
  LDA ram_006C_plr,X
  CMP tbl_CD91,Y
  BCC bra_CDAF_RTS
  LDA #$00
  STA ram_006C_plr,X
bra_CDAF_RTS
  RTS



sub_CDB0
loc_CDB0
  LDA ram_0055
  CMP #$01
  BNE bra_CDC4
  TXA
  ASL
  TAY
  LDA ram_btn_hold,Y
  AND #con_btn_B
  BEQ bra_CDC4
  LDA #$05
  BNE bra_CDDB    ; jmp
bra_CDC4
  LDA ram_0070_plr,X
  AND #$01
  BNE bra_CDDF
  LDA ram_0070_plr,X
  AND #$02
  BNE bra_CDE9
bra_CDD0
  LDA ram_0068_plr,X
  BEQ bra_CDFF
  LDA ram_006E_plr,X
  LSR
  STA ram_0032_plr_timer,X
  LDA #$03
bra_CDDB
  STA ram_plr_handler,X
  BNE bra_CDFF    ; jmp
bra_CDDF
  LDA #$01
  LDY ram_0068_plr,X
  CPY #$02
  BEQ bra_CDD0
  BNE bra_CDF1    ; jmp
bra_CDE9
  LDA #$02
  LDY ram_0068_plr,X
  CPY #$01
  BEQ bra_CDD0
bra_CDF1
  STA ram_0068_plr,X
  AND #$01
  STA ram_0062_plr,X
  JSR sub_D143
  LDY #$00
  JSR sub_CD95
bra_CDFF
loc_CDFF
  LDY ram_006C_plr,X
  JSR sub_D17C
  LDY #$D9
  LDA ram_0055
  CMP #$01
  BEQ bra_CE29
  LDY tbl_CBBF_oam_lo,X
  LDX #$00
bra_CE11_loop
  TYA
  CLC
  ADC tbl_CBF5,X
  TAY
  LDA ram_spr_T + $04,Y
  CLC
  ADC #$77
  STA ram_spr_T + $04,Y
  INX
  CPX #$04
  BCC bra_CE11_loop
  LDY #$DF
  LDX ram_plr_index
bra_CE29
  LDA ram_0070_plr,X
  AND #$03
  BNE bra_CE43
  TYA
  PHA
  LDY tbl_CBBF_oam_lo,X
  LDA ram_0062_plr,X
  BNE bra_CE3F
  PLA
  STA ram_spr_T + $08,Y
  JMP loc_CE43
bra_CE3F
  PLA
  STA ram_spr_T + $14,Y
bra_CE43
loc_CE43
sub_CE43
  LDA ram_0070_plr,X
  AND #$80
  BEQ bra_CE5C_RTS
  LDA ram_0055
  CMP #$01
  BEQ bra_CE54
  DEC ram_plr_pos_Y,X
  LDA #$02
  db $2C   ; BIT opcode
bra_CE54
  LDA #$04
  STA ram_plr_handler,X
  LDA #con_sfx_3_plr_jump
  STA ram_sfx_3
bra_CE5C_RTS
  RTS



sub_CE5D
ofs_002_CE5D_02
  LDA #$A8
  STA ram_00E2_plr,X
  LDA #$03
  STA ram_00E4_plr,X
  LDA ram_0068_plr,X
  BNE bra_CE93
  LDA ram_00E6_plr,X
  CMP #$03
  BCC bra_CE93
  LDA ram_0070_plr,X
  AND #$03
  BEQ bra_CE93
  STA ram_0068_plr,X
  CMP #$01
  BEQ bra_CE7E
  LDA #$00
  db $2C   ; BIT opcode
bra_CE7E
  LDA #$01
  STA ram_0062_plr,X
  LDA #$0F
  STA ram_006E_plr,X
  BNE bra_CE93    ; jmp
sub_CE88
  LDA #$F0
  db $2C   ; BIT opcode
sub_CE8B
  LDA #$B0
  STA ram_00E2_plr,X
  LDA #$00
  STA ram_00E4_plr,X
bra_CE93
  LDA ram_0068_plr,X
  BEQ bra_CE9A
  JSR sub_D160
bra_CE9A
  JSR sub_D133
  JSR sub_CEEF
  JSR sub_CF1A
  BCC bra_CED0
  LDA ram_000E
  SEC
  SBC #$19
  STA ram_plr_pos_Y,X
  LDA #$00
  STA ram_00E0_plr,X
  STA ram_0086_plr,X
  STA ram_0088_plr,X
  STA ram_0060_plr,X
  LDX ram_plr_index
  LDA #$01
  STA ram_plr_handler,X
  LDA ram_0068_plr,X
  BEQ bra_CEEE_RTS
  LDA #$03
  STA ram_plr_handler,X
  LDA ram_006E_plr,X
  LDY ram_005A_plr,X
  CPY #$08
  BCS bra_CECD
  LSR
bra_CECD
  LSR
  STA ram_0032_plr_timer,X
bra_CED0
  LDA ram_plr_handler,X
  CMP #$04
  BCS bra_CEEE_RTS
  LDY #$07
  JMP loc_D17C



sub_CEDB
  LDY #$00
bra_CEDD_loop
  CMP tbl_CBDC,Y
  BCC bra_CEE7
  CMP tbl_CBDC + $01,Y
  BCC bra_CEEE_RTS
bra_CEE7
  INY
  INY
  CPY #$0C
  BNE bra_CEDD_loop
  SEC
bra_CEEE_RTS
  RTS



sub_CEEF
  LDA ram_0086_plr,X
  BNE bra_CF19_RTS
  LDA ram_plr_pos_Y,X
  CLC
  ADC #$FA
  JSR sub_CEDB
  BCS bra_CF19_RTS
  JSR sub_CF5B
  STA ram_000B
  LDA ram_plr_pos_X,X
  CLC
  ADC #$08
  JSR sub_DBB0
  BPL bra_CF12
  LDY ram_000B
  BEQ bra_CF19_RTS
  BNE bra_CF15    ; jmp
bra_CF12
  LDA #$08
  db $2C   ; BIT opcode
bra_CF15
  LDA #$06
  STA ram_plr_handler,X
bra_CF19_RTS
  RTS



sub_CF1A
  LDA ram_plr_pos_Y,X
  CLC
  ADC #$18
  JSR sub_CEDB
  BCS bra_CF51
  TYA
  STY ram_0007
  CMP ram_0088_plr,X
  BEQ bra_CF55
  LDA tbl_CBDC,Y
  STA ram_000E
  LDA ram_00E6_plr,X
  CMP #$03
  BCS bra_CF46
  CMP #$02
  BCC bra_CF55
  LDA ram_plr_handler,X
  CMP #$08
  BEQ bra_CF46
  LDA ram_00E8_plr,X
  CMP #$C0
  BCC bra_CF55
bra_CF46
  LDY ram_0007
  STY ram_0088_plr,X
  JSR sub_CD62
  BCC bra_CF55
  SEC
  RTS
bra_CF51
  LDA #$00
  STA ram_0088_plr,X
bra_CF55
  CLC
  RTS



tbl_CF57
  db $01   ; 00 
  db $80   ; 01 



tbl_CF59
  db $03   ; 00 
  db $0D   ; 01 



sub_CF5B
  LDA #$01
  STA ram_0082_plr,X
  LSR ; 00
  STA ram_000A
  LDA #$08
  JSR sub_CFC0
  BMI bra_CF6D
  LDA #$FF
  BNE bra_CFA7    ; jmp
bra_CF6D
  LDA ram_0068_plr,X
  BNE bra_CF89
  LDA #$06
  JSR sub_CFC0
  BMI bra_CF7C
  LDA #$E0
  STA ram_000A
bra_CF7C
  LDA #$0A
  JSR sub_CFC0
  BMI bra_CFA9
  LDA ram_000A
  ORA #$07
  BNE bra_CFA7    ; jmp
bra_CF89
  LDA #$01
  STA ram_000C
  LDY ram_0062_plr,X
  LDA tbl_CF59,Y
  JSR sub_CFC0
  BPL bra_CF99
  DEC ram_000C
bra_CF99
  LDY ram_0068_plr,X
  DEY
  LDA ram_000C
  BNE bra_CFA4
  LDA #$00
  BEQ bra_CFA7    ; jmp
bra_CFA4
  LDA tbl_CF57,Y
bra_CFA7
  STA ram_000A
bra_CFA9
  LDA ram_plr_pos_X,X
  CLC
  ADC #$08
  AND #$07
  TAY
  LDA tbl_CBED,Y
  ORA ram_000A
  CMP ram_000A
  BNE bra_CFBD
  LDA #$01
  RTS
bra_CFBD
  LDA #$00
  RTS



sub_CFC0
  CLC
  ADC ram_plr_pos_X,X
  JMP loc_DBB4



sub_CFC6
loc_CFC6
  LDA ram_0068_plr,X
  BEQ bra_CFD3
  CMP #$01
  BEQ bra_CFD1
  DEC ram_plr_pos_X,X
  db $2C   ; BIT opcode
bra_CFD1
  INC ram_plr_pos_X,X
bra_CFD3
  LDY #$05
  JSR sub_D17C
  LDA ram_0032_plr_timer,X
  BEQ bra_CFEB
  LDA ram_005A_plr,X
  CMP #$06
  BCC bra_CFEB
  LDA ram_0070_plr,X
  AND #$40
  BEQ bra_CFFC
  LDA #$05
  db $2C   ; BIT opcode
bra_CFEB
sub_CFEB
  LDA #$01
  STA ram_plr_handler,X
loc_CFEF
  LDA #$00
  STA ram_0032_plr_timer,X
  STA ram_0068_plr,X
  STA ram_0060_plr,X
  STA ram_006C_plr,X
  STA ram_006E_plr,X
bra_CFFB_RTS
  RTS
bra_CFFC
  LDA ram_0070_plr,X
  AND #$80
  BEQ bra_CFFB_RTS
  JSR sub_CE43
  JMP loc_CFEF



ofs_002_D008_04
ofs_002_D008_06
ofs_002_D008_08
  LDA ram_plr_handler,X
  CMP #$06
  BEQ bra_D018
  CMP #$08
  BEQ bra_D01E
  JSR sub_CE5D
  JMP loc_D021
bra_D018
  JSR sub_CE88
  JMP loc_D021
bra_D01E
  JSR sub_CE8B
loc_D021
  LDA ram_00E0_plr,X
  BEQ bra_CFFB_RTS
  LDX ram_plr_index
  LDA ram_0086_plr,X
  BNE bra_D04F
  LDA ram_plr_handler,X
  CMP #$04
  BEQ bra_D04F
  LDA ram_plr_index
  ASL
  ASL
  TAY
  LDA ram_spr_Y + $1C,Y
  SEC
  SBC #$01
  JSR sub_CEDB
  BCS bra_D04F
  LDA ram_00E6_plr,X
  CMP #$03
  BCS bra_D04F
  LDA #$01
  STA ram_0080_plr,X
  STA ram_0086_plr,X
  STA ram_0082_plr,X
bra_D04F
  LDY #$07
  LDA ram_0060_plr,X
  CMP #$0B
  BCS bra_D05A
  INC ram_0060_plr,X
  DEY
bra_D05A
  JMP loc_D17C



ofs_002_D05D_05
  INC ram_0060_plr,X
  LDA ram_0060_plr,X
  CMP #$14
  BCS bra_D07C
  CMP #$01
  BCC bra_CFFB_RTS
  LDY #$0A
  CMP #$0B
  BCS bra_D079
  CMP #$07
  BCS bra_D077
  LDY #$07
  BNE bra_D079    ; jmp
bra_D077
  LDY #$09
bra_D079
  JMP loc_D17C
bra_D07C
loc_D07C
  LDA #$01
  STA ram_plr_handler,X
  LSR ; 00
  STA ram_0060_plr,X
  TAY ; 00
  BEQ bra_D079    ; jmp



tbl_D086_spr_T
  dw off_D08E_00
  dw off_D094_01
  dw off_D09A_02
  dw off_D0A0_03



off_D08E_00
  db $68, $69, $6A, $6B, $6C, $6D   ; 

off_D094_01
  db $6A, $69, $68, $6D, $6C, $6B   ; 

off_D09A_02
  db $6D, $6C, $6B, $6A, $69, $68   ; 

off_D0A0_03
  db $6B, $6C, $6D, $68, $69, $6A   ; 



tbl_D0A6
  db $00   ; 00 
  db $80   ; 01 
  db $C0   ; 02 
  db $40   ; 03 



ofs_002_D0AA_07
  LDA ram_0032_plr_timer,X
  BEQ bra_D0CA
  CMP #$10
  BEQ bra_D0B8
  BCS bra_D0C0
  LDY #$0B
  BNE bra_D0C7    ; jmp
bra_D0B8
sub_D0B8
  TXA
  CLC
  ADC #$0B
  TAX
  JMP loc_F691
bra_D0C0
  LDA #$00
  STA ram_00E0_plr,X
  RTS



sub_D0C5
  LDY #$00
bra_D0C7
  JMP loc_D17C
bra_D0CA
  LDX ram_plr_index
  JSR sub_D127
  JSR sub_D0C5
  LDY #$03
  JSR sub_CD95
  LDA ram_006C_plr,X
  ASL
  TAY
  LDA tbl_D086_spr_T,Y
  STA ram_0000
  LDA tbl_D086_spr_T + $01,Y
  STA ram_0001
  LDY ram_006C_plr,X
  LDA tbl_D0A6,Y
  STA ram_0002
  LDA #$01
  CPX #$00
  BEQ bra_D0F4
  LDA #$25
bra_D0F4
  TAX
  LDY #$00
bra_D0F7_loop
  LDA (ram_0000),Y
  STA ram_spr_T - $01,X
  INX
  LDA ram_spr_A - $02,X
  AND #$03
  ORA ram_0002
  STA ram_spr_A - $02,X
  INX
  INX
  INX
  INY
  CPY #$06
  BCC bra_D0F7_loop
  LDX ram_plr_index
sub_D111
  LDA ram_0032_plr_timer,X
  BNE bra_D126_RTS
  LDY #$0B
bra_D117_loop
  LDA ram_0091_obj - $01,Y
  CMP #$20
  BNE bra_D123
  LDA #$FF
  STA ram_0091_obj - $01,Y
bra_D123
  DEY
  BNE bra_D117_loop
bra_D126_RTS
  RTS



sub_D127
  LDA #$01
  STA ram_00E4_plr,X
  LDA #$80
  STA ram_00E2_plr,X
  LDA #$01
  STA ram_002F_plr,X
sub_D133
  LDA ram_plr_pos_Y,X
  STA ram_0001
  LDA ram_plr_index
  JSR sub_C83D
  LDX ram_plr_index
  LDA ram_0001
  STA ram_plr_pos_Y,X
  RTS



sub_D143
  LDY ram_plr_handler,X
  CPY #$01
  BNE bra_D160
  LDA ram_006E_plr,X
  CMP #$18
  BCS bra_D151
  INC ram_006E_plr,X
bra_D151
  LDA ram_0076_plr,X
  CLC
  ADC #$20
  STA ram_0076_plr,X
  BCC bra_D171
  JSR sub_D171
  JMP loc_D171
bra_D160
sub_D160
  LDA #$90
  LDY ram_006E_plr,X
  CPY #$0C
  BCS bra_D16A
  LDA #$45
bra_D16A
  CLC
  ADC ram_0072_plr,X
  STA ram_0072_plr,X
  BCC bra_D17B_RTS
bra_D171
sub_D171
loc_D171
  LDY ram_0062_plr,X
  LDA tbl_CBDA,Y
  CLC
  ADC ram_plr_pos_X,X
  STA ram_plr_pos_X,X
bra_D17B_RTS
  RTS



sub_D17C
loc_D17C
  LDA tbl_CBB3,Y
  STA ram_0002
  TYA
  PHA
  LDX ram_plr_index
  LDA ram_plr_pos_X,X
  STA ram_0000
  LDA ram_plr_pos_Y,X
  CPY #$0A
  BNE bra_D192
  SEC
  SBC #$08
bra_D192
  STA ram_0001
  LDA ram_0062_plr,X
  STA ram_000F
  TXA
  TAY
  INY
  JSR sub_D1DB
  PLA
  CMP #$0B
  BEQ bra_D1A7
  CMP #$06
  BCS bra_D1AB
bra_D1A7
  LDA #$F8
  BNE bra_D1D2    ; jmp
bra_D1AB
  SEC
  SBC #$06
  STA ram_0007
  LDY ram_0007
  LDA tbl_CBC1,Y
  STA ram_0002
  LDA ram_0007
  ASL
  ASL
  TAY
  LDX ram_plr_index
  LDA ram_0062_plr,X
  BEQ bra_D1C4
  INY
  INY
bra_D1C4
  LDA tbl_CBC6,Y
  CLC
  ADC ram_plr_pos_X,X
  STA ram_0000
  LDA tbl_CBC6 + $01,Y
  CLC
  ADC ram_plr_pos_Y,X
bra_D1D2
  STA ram_0001
  LDY #$0B
  CPX #$00
  BEQ bra_D1DB
  INY
bra_D1DB
sub_D1DB
  LDA #$01
  STA ram_000E
  JSR sub_EAFC
  LDX ram_plr_index
  RTS



sub_D1E5
  LDX #$01
bra_D1E7_loop
  LDA ram_005A_plr,X
  BEQ bra_D1F5
  LDA ram_plr_pos_Y,X
  CLC
  ADC #$18
  JSR sub_D1F9
  STA ram_005A_plr,X
bra_D1F5
  DEX
  BPL bra_D1E7_loop
  RTS



sub_D1F9
  LDY #$00
bra_D1FB_loop
  CMP tbl_CBE8,Y
  BCC bra_D206
  INY
  CPY #$05
  BNE bra_D1FB_loop
  DEY
bra_D206
  STY ram_000A
  LDA ram_0090
  SEC
  SBC ram_000A
  BNE bra_D211_RTS
  LDA #$01
bra_D211_RTS
  RTS



sub_D212
  LDA ram_005A_plr
  AND ram_005A_plr + $01
  BEQ bra_D211_RTS
  LDA ram_002D_plr
  ORA ram_002D_plr + $01
  BNE bra_D211_RTS
  LDA #$07
  CMP ram_plr_handler
  BEQ bra_D211_RTS
  CMP ram_plr_handler + $01
  BEQ bra_D211_RTS
  JSR sub_D2D9
  BCS bra_D211_RTS
  LDA #$00
  STA ram_0002
  LDA ram_plr_handler
  LSR
  BCS bra_D25A
  LDA ram_0000
  CMP #$09
  BCS bra_D25A
  LDA ram_plr_pos_Y
  CMP ram_plr_pos_Y + $01
  BCS bra_D249
  CMP #$C3
  BCS bra_D24B
  DEC ram_plr_pos_Y
  db $2C   ; BIT opcode
bra_D249
  INC ram_plr_pos_Y
bra_D24B
  LDA ram_0062_plr
  BEQ bra_D252
  INC ram_plr_pos_X
  db $2C   ; BIT opcode
bra_D252
  DEC ram_plr_pos_X
  LDA #$01
  STA ram_0002
  BNE bra_D269    ; jmp
bra_D25A
  LDX #$00
  LDA ram_0003
  BPL bra_D264
  LDA #$00
  BEQ bra_D266    ; jmp
bra_D264
  LDA #$01
bra_D266
  JSR sub_D2BC
bra_D269
  LDA ram_plr_handler + $01
  AND #$01
  BNE bra_D2B6
  LDA ram_0000
  CMP #$09
  BCS bra_D2B6
  LDA ram_plr_pos_Y + $01
  CMP ram_plr_pos_Y
  BCS bra_D282
  CMP #$C3
  BCS bra_D284
  DEC ram_plr_pos_Y + $01
  db $2C   ; BIT opcode
bra_D282
  INC ram_plr_pos_Y + $01
bra_D284
  LDA ram_0002
  BEQ bra_D2B5_RTS
  LDA ram_00E6_plr
  PHA
  LDA ram_00E6_plr + $01
  STA ram_00E6_plr
  PLA
  STA ram_00E6_plr + $01
  LDA ram_00E8_plr
  PHA
  LDA ram_00E8_plr + $01
  STA ram_00E8_plr
  PLA
  STA ram_00E8_plr + $01
  LDX #$01
bra_D29E_loop
  LDA ram_00E6_plr,X
  CMP #$06
  BCC bra_D2A8
  LDA #$05
  STA ram_00E6_plr,X
bra_D2A8
  DEX
  BPL bra_D29E_loop
  LDA #$00
  STA ram_0086_plr
  STA ram_0086_plr + $01
  STA ram_0088_plr
  STA ram_0088_plr + $01
bra_D2B5_RTS
  RTS
bra_D2B6
  LDX #$01
  LDA ram_0062_plr
  EOR #$01
sub_D2BC   ; X = 00
  STA ram_0062_plr,X
  BEQ bra_D2C7
  INC ram_plr_pos_X,X
  INC ram_plr_pos_X,X
  JMP loc_D2CB
bra_D2C7
  DEC ram_plr_pos_X,X
  DEC ram_plr_pos_X,X
loc_D2CB
  LDA ram_0068_plr,X
  LSR
  BCC bra_D2D2
  LDA #$02
bra_D2D2
  STA ram_0068_plr,X
  LDA #$18
  STA ram_006E_plr,X
  RTS



sub_D2D9
  LDA ram_plr_pos_X
  SEC
  SBC ram_plr_pos_X + $01
  STA ram_0003
  JSR sub_D2F9_EOR_if_negative
  STA ram_0000
  CMP #$0A
  BCS bra_D2F8_RTS
  LDA ram_plr_pos_Y
  SEC
  SBC ram_plr_pos_Y + $01
  JSR sub_D2F9_EOR_if_negative
  STA ram_0001
  CMP #$15
  BCC bra_D2F8_RTS
  SEC
bra_D2F8_RTS
  RTS



sub_D2F9_EOR_if_negative
  BPL bra_D300_RTS
sub_D2FB_EOR
  EOR #$FF
  CLC
  ADC #$01
bra_D300_RTS
  RTS



sub_D301
  LDX #$00
  JSR sub_D308
  LDX #$01
sub_D308
  LDA ram_005A_plr,X
  BEQ bra_D371_RTS
  LDA ram_plr_handler,X
  BEQ bra_D371_RTS
  CMP #$07
  BEQ bra_D371_RTS
  CMP #$09
  BEQ bra_D371_RTS
  LDA ram_002D_plr,X
  BNE bra_D371_RTS
  LDA ram_plr_pos_X,X
  CLC
  ADC #$08
  STA ram_000A
  LDA ram_plr_pos_Y,X
  CLC
  ADC #$0C
  STA ram_000B
  TXA
  PHA
  LDY #$00
bra_D32E_loop
  LDA #$01
  JSR sub_DB1D
  BCS bra_D33C
  INY
  CPY #$0B
  BCC bra_D32E_loop
  PLA
  RTS
bra_D33C
  PLA
  TAX
  LDA ram_0055
  CMP #$02
  BEQ bra_D393
  CPY #$01
  BEQ bra_D372
  JSR sub_D446
; triggers when an enemy touches you
  LDA #$20
  STA ram_0091_obj,Y ; 0091 0093 
  CPY #$02
  BCC bra_D371_RTS
; 02+
  CPY #$08
  BCS bra_D371_RTS
; 02-07
  CPY #$05
  BCS bra_D367_05_07
; 02-04
  LDA ram_0091_obj + $03,Y ; 0096 
  BPL bra_D371_RTS
  LDA #$20
  STA ram_0091_obj + $03,Y
  RTS
bra_D367_05_07
  LDA ram_0091_obj - $03,Y
  BPL bra_D371_RTS
  LDA #$20
  STA ram_0091_obj - $03,Y
bra_D371_RTS
  RTS
bra_D372
  LDY #$01
  LDA ram_0000
  BMI bra_D37F
  DEC ram_plr_pos_X,X
  DEC ram_plr_pos_X,X
  INY
  BNE bra_D383
bra_D37F
  INC ram_plr_pos_X,X
  INC ram_plr_pos_X,X
bra_D383
  LDA ram_plr_handler,X
  AND #$01
  BEQ bra_D390_RTS
  STY ram_0068_plr,X
  TYA
  AND #$01
  STA ram_0062_plr,X
bra_D390_RTS
  RTS



tbl_D391_plr_counters_start_address
  db $00   ; 00 1p
  db $05   ; 01 2p



bra_D393
  CPY #$03
  BCC bra_D3AB_RTS
  CPY #$09
  BCS bra_D3AB_RTS
  LDA #$01
  STA ram_0091_obj,Y
  LDA tbl_D391_plr_counters_start_address,X
  TAX
  INC ram_plr_counter_fruits,X
  LDA #con_sfx_2_collect_fruit
  STA ram_sfx_2
bra_D3AB_RTS
  RTS



sub_D3AC
  LDX #$00
  JSR sub_D3B3
  LDX #$01
sub_D3B3
  LDA ram_005A_plr,X
  BEQ bra_D3F5_RTS
  TXA
  ASL
  ASL
  TAY
  LDA ram_spr_Y + $1C,Y
  CLC
  ADC #$0A
  STA ram_000B
  LDA ram_spr_X + $1C,Y
  CLC
  ADC #$04
  STA ram_000A
  STX ram_0009
  LDY #$0A
bra_D3CF_loop
  LDX ram_0009
  CPY #$00
  BEQ bra_D3D9
  CPY #$08
  BCC bra_D3DF
bra_D3D9
  LDA ram_plr_handler,X
  CMP #$04
  BEQ bra_D3EB
bra_D3DF
  LDA ram_plr_handler,X
  CMP #$05
  BNE bra_D3F2
  LDA ram_0060_plr,X
  CMP #$09
  BNE bra_D3F2
bra_D3EB
  LDA #$00
  JSR sub_DB1D
  BCS bra_D3F6
bra_D3F2
  DEY
  BPL bra_D3CF_loop
bra_D3F5_RTS
  RTS
bra_D3F6
  LDX ram_0009
; triggers when you hit an object (enemy, ice block carried by a seal) with a hammer
  LDA #$01
  CPY #$01
  BNE bra_D400
  LDA #$05
bra_D400
  STA ram_0091_obj,Y
  LDA #$00
  STA ram_03B1_obj,Y
  LDA #$FF
  STA ram_03D2_obj,Y
  TXA
  PHA
  JSR sub_D421
  PLA
  TAX
  CPY #$00
  BEQ bra_D3F5_RTS
  CPY #$08
  BCS bra_D3F5_RTS
  STX ram_plr_index
  JMP loc_D07C



sub_D421
  LDA tbl_D391_plr_counters_start_address,X
  TAX
  CPY #$00
  BNE bra_D431
  INC ram_plr_counter_birds,X
  LDA #con_sfx_2_kill_bird
  STA ram_sfx_2
  RTS
bra_D431
  CPY #$05
  BCC bra_D43C
  CPY #$08
  BCS bra_D441
  INC ram_plr_counter_ice,X
bra_D43C
  LDA #con_sfx_3_kill_seal_or_ice
  STA ram_sfx_3
  RTS
bra_D441
  LDA #con_sfx_1_block_placed_or_destroyed
  STA ram_sfx_1
  RTS



sub_D446
  LDA #$07
  STA ram_plr_handler,X
  LDA ram_005A_plr,X
  STA ram_0382_obj,X
  TXA
  PHA
  CLC
  ADC #$0D
  TAX
  JSR sub_F691
  PLA
  TAX
  LDA #$40
  STA ram_0032_plr_timer,X
  LDA #con_sfx_3_plr_deadh
  STA ram_sfx_3
  RTS



sub_D463
  LDX #$00
bra_D465_loop
  LDA ram_005A_plr,X
  BEQ bra_D487
  LDA ram_plr_pos_Y,X
  CLC
  ADC #$19
  JSR sub_CEDB
  BCS bra_D487
  CPY #$0A
  BNE bra_D487
  LDA #$00
  STA ram_005A_plr,X
  STA ram_00E0_plr,X
  LDA ram_002D_plr,X
  BNE bra_D483
  DEC ram_plr_lives,X
bra_D483
  LDA #$08
  STA ram_003F_plr_timer,X
bra_D487
  INX
  CPX #$02
  BNE bra_D465_loop
bra_D48C_RTS
  RTS



tbl_D48D
  db $2C   ; 00 
  db $64   ; 01 
  db $AC   ; 02 



tbl_D490
  db $4C   ; 00 
  db $94   ; 01 
  db $CC   ; 02 



sub_D493
  LDX #$01
bra_D495_loop
  LDA ram_005A_plr,X
  CMP #$09
  BNE bra_D4CE
  LDY #$02
bra_D49D_loop
  LDA ram_plr_pos_X,X
  CMP tbl_D48D,Y
  BCC bra_D4A9
  CMP tbl_D490,Y
  BCC bra_D4AE
bra_D4A9
  DEY
  BPL bra_D49D_loop
  BMI bra_D4CE    ; jmp
bra_D4AE
  LDA ram_00E6_plr,X
  CMP #$03
  BCC bra_D4C0
  LDA ram_plr_pos_Y,X
  CMP #$14
  BCS bra_D4CE
  CMP #$10
  BCS bra_D4D2
  BCC bra_D4CE    ; jmp
bra_D4C0
  LDA ram_plr_pos_Y,X
  CMP #$2C
  BCS bra_D4CE
  CMP #$28
  BCC bra_D4CE
  LDA #$03
  STA ram_00E6_plr,X
bra_D4CE
  DEX
  BPL bra_D495_loop
  RTS
bra_D4D2
  LDA #$10
  STA ram_plr_pos_Y,X
  LDA #$09
  CMP ram_005A_plr
  BEQ bra_D4E4
  CMP ram_005A_plr + $01
  BNE bra_D48C_RTS
  LDA #$01
  BNE bra_D4EE    ; jmp
bra_D4E4
  LDA #$00
  LDY ram_005A_plr + $01
  CPY #$09
  BNE bra_D4EE
  LDA #$02
bra_D4EE
  STA ram_0026_flag
  LDA #$02
  db $2C   ; BIT opcode
  LDA #$01
sub_D4F5
loc_D4F5
  STA ram_0055
  LDA #con_music_off
  STA ram_music_1
  ASL ; 00
  STA ram_0034_timer
  STA ram_0051
ofs_002_D500_09_RTS
  RTS



tbl_D501
  db $01   ; 00 
  db $02   ; 01 
  db $04   ; 02 
  db $04   ; 03  



tbl_D505
  db $0A   ; 00 
  db $05   ; 01 



sub_D507
  LDA ram_scroll_Y
  BNE bra_D547
  LDA ram_plr_pos_Y,X
  CMP #$26
  BCS bra_D547
  LDA ram_plr_counter_fruits
  ADC ram_plr_counter_fruits + $05
  LSR
  AND #$03
  TAY
  LDA tbl_D501,Y
  STA ram_0001
  LDY ram_00D4 + $01
  LDA tbl_D505,Y
  CLC
  ADC ram_giant_bird_X_pos
  STA ram_0000
  CMP ram_plr_pos_X,X
  BCS bra_D547
  ADC ram_0001
  CMP ram_plr_pos_X,X
  BCC bra_D547
  LDA ram_0000
  STA ram_plr_pos_X,X
  INX
  STX ram_001E
  DEX
  LDA #$06
  STA ram_plr_handler,X
  LDA #con_music_mountain_complete
  STA ram_music_1
  ASL ; 20
  STA ram_004D_timer
bra_D547
  LDA ram_plr_index
  ASL
  ASL
  TAY
  LDA #$F8
  STA ram_spr_Y + $1C,Y
  RTS



sub_D552
  LDA ram_plr_handler,X
  CMP #$01
  BEQ bra_D561
  CMP #$02
  BEQ bra_D567
  CMP #$03
  BEQ bra_D564
  RTS
bra_D561
  JMP loc_CDB0
bra_D564
  JMP loc_CFC6
bra_D567
  LDA #$A8
  STA ram_00E2_plr,X
  LDA #$03
  STA ram_00E4_plr,X
  LDA ram_0068_plr,X
  BNE bra_D58D
  LDA ram_00E6_plr,X
  CMP #$03
  BCC bra_D58D
  LDA ram_0070_plr,X
  AND #$03
  BEQ bra_D58D
  STA ram_0068_plr,X
  CMP #$01
  BEQ bra_D587
  LDA #$00
bra_D587
  STA ram_0062_plr,X
  LDA #$0F
  STA ram_006E_plr,X
bra_D58D
  LDA ram_0068_plr,X
  BEQ bra_D594
  JSR sub_D160
bra_D594
  JSR sub_D133
  LDY #$07
  JMP loc_D17C



sub_D59C
  LDA #$00
  STA ram_002A_plr,X
  LDA ram_scroll_Y
  CLC
  ADC ram_plr_pos_Y,X
  BCS bra_D5B0
  STA ram_0028_plr,X
  LDY ram_0027_flag
  BEQ bra_D5B4
  SEC
  SBC #$10
bra_D5B0
  STA ram_0028_plr,X
  INC ram_002A_plr,X
bra_D5B4
  LDA ram_002A_plr,X
  STA ram_0009
  LDA ram_0028_plr,X
  STA ram_000B
  CLC
  ADC #$18
  STA ram_000A
  BCC bra_D5C5_not_overflow
  INC ram_0009
bra_D5C5_not_overflow
  LDA ram_plr_pos_X,X
  STA ram_000D
  CLC
  ADC #$10
  STA ram_000C
  LDA ram_0352_plr,X
  BNE bra_D648
  LDY #$00
bra_D5D5_loop
  LDA ram_06E0_bouns_stage_data,Y
  BMI bra_D603
  CMP ram_0009
  BNE bra_D603
  LDA ram_0668_data,Y
  SBC #$08
  CMP ram_plr_pos_X,X
  BCS bra_D603
  LDA ram_0686_data,Y
  SEC
  SBC #$08
  CMP ram_plr_pos_X,X
  BCC bra_D603
  LDA ram_000A
  SBC #$03
  CMP ram_06A4,Y
  BEQ bra_D617
  BCS bra_D603
  ADC #$04
  CMP ram_06A4,Y
  BCS bra_D617
bra_D603
  INY
  CPY #$1E
  BNE bra_D5D5_loop
  LDA #$02
  CMP ram_plr_handler,X
  BEQ bra_D63B
  STA ram_plr_handler,X
  LDA #$03
  STA ram_00E6_plr,X
  LSR ; 01
  BNE bra_D639
bra_D617
  TYA
  STA ram_0783_plr,X
  LDA ram_plr_handler,X
  CMP #$01
  BEQ bra_D62F
  CMP #$03
  BEQ bra_D63B
  LDA ram_00E6_plr,X
  CMP #$03
  BCC bra_D63B
  LDA #$03
  STA ram_plr_handler,X
bra_D62F
  LDA ram_06A4,Y
  SEC
  SBC #$19
  STA ram_0028_plr,X
  LDA #$00
bra_D639
  STA ram_00E0_plr,X
bra_D63B
  JSR sub_D6E0
  LDA ram_0028_plr,X
  SEC
  SBC ram_000B
  CLC
  ADC ram_plr_pos_Y,X
  STA ram_plr_pos_Y,X
bra_D648
  LDX ram_plr_index
  LDA #$00
  STA ram_0352_plr,X
  LDA ram_plr_handler,X
  BEQ bra_D6CB_RTS
  LDA ram_scroll_Y
  ORA ram_002A_plr,X
  BNE bra_D669
  LDA ram_plr_pos_X,X
  CMP #$2B
  BCC bra_D6CC
  CMP #$C6
  BCS bra_D6CC
  LDA ram_0028_plr,X
  CMP #$58
  BCC bra_D6CB_RTS
bra_D669
  LDA #$00
  STA ram_0009
  LDA ram_0028_plr,X
  SEC
  SBC #$57
  BCC bra_D680
  LDY ram_002A_plr,X
  STY ram_0009
  BEQ bra_D684
  CLC
  ADC #$20
  JMP loc_D684
bra_D680
  LDY ram_002A_plr,X
  BEQ bra_D697
bra_D684
loc_D684
  LDY #$00
bra_D686_loop
  CMP #$38
  BCC bra_D68F
  SBC #$38
  INY
  BNE bra_D686_loop
bra_D68F
  LDA ram_0009
  BEQ bra_D697
  INY
  INY
  INY
  INY
bra_D697
  LDA #$A8
bra_D699_loop
  CPY #$00
  BEQ bra_D6A3
  CLC
  ADC #$08
  DEY
  BNE bra_D699_loop
bra_D6A3
  STA ram_000A
  SEC
  SBC #$A8
  STA ram_0009
  LDA #$48
  SEC
  SBC ram_0009
  STA ram_000B
  LDA ram_plr_pos_X,X
  CMP ram_000A
  BCC bra_D6BF
  LDA ram_000A
  STA ram_plr_pos_X,X
  LDA #$00
  BEQ bra_D6C9    ; jmp
bra_D6BF
  CMP ram_000B
  BCS bra_D6CB_RTS
  LDA ram_000B
  STA ram_plr_pos_X,X
  LDA #$01
bra_D6C9
  STA ram_0062_plr,X
bra_D6CB_RTS
  RTS
bra_D6CC
  LDA #$02
  CMP ram_plr_handler,X
  BEQ bra_D6DC
  STA ram_plr_handler,X
  LDA #$03
  STA ram_00E6_plr,X
  LDA #$01
  STA ram_00E0_plr,X
bra_D6DC
  INC ram_0352_plr,X
  RTS



sub_D6E0
  LDA ram_00E6_plr,X
  CMP #$04
  BCS bra_D71A_RTS
  LDY #$00
bra_D6E8_loop
  LDA ram_06E0_bouns_stage_data,Y
  BMI bra_D715
  CMP ram_002A_plr,X
  BNE bra_D715
  LDA ram_000B
  SEC
  SBC #$02
  CMP ram_06C2_data,Y
  BCS bra_D715
  ADC #$04
  CMP ram_06C2_data,Y
  BCC bra_D715
  LDA ram_0668_data,Y
  SBC #$0A
  CMP ram_plr_pos_X,X
  BCS bra_D715
  LDA ram_0686_data,Y
  SEC
  SBC #$06
  CMP ram_plr_pos_X,X
  BCS bra_D71B
bra_D715
  INY
  CPY #$1E
  BNE bra_D6E8_loop
bra_D71A_RTS
  RTS
bra_D71B
  LDA #$04
  STA ram_00E6_plr,X
  LDA #$20
  STA ram_00E8_plr,X
bra_D723_RTS
  RTS



sub_D724
  LDX #$01
bra_D726_loop
  LDA ram_plr_handler,X
  CMP #$06
  BEQ bra_D74C
  LDA ram_plr_pos_Y,X
  CMP #$D4
  BCC bra_D74C
  LDA #$F8
  STA ram_plr_pos_Y,X
  LDA #$00
  STA ram_plr_handler,X
  STA ram_005A_plr,X
  LDA ram_plr_lives,X
  BMI bra_D74C
  TXA
  PHA
  LDA tbl_CBBF_oam_lo,X
  LDX #$06
  JSR sub_C821_hide_sprites_starting_from_A
  PLA
  TAX
bra_D74C
  DEX
  BPL bra_D726_loop
  LDA ram_plr_handler
  BNE bra_D723_RTS
  LDA ram_plr_handler + $01
  BNE bra_D723_RTS
  STA ram_001E
  LDA #$03
  JMP loc_D4F5



tbl_D75E
  db $80   ; 00 
  db $5D   ; 01 
  db $3E   ; 02 
  db $1F   ; 03 



tbl_D762
  db < (ram_0500_data + $02)   ; 00 
  db < (ram_0500_data + $00)   ; 01 
  db < (ram_0500_data + $18)   ; 02 
  db < (ram_0500_data + $30)   ; 03 
  db < (ram_0500_data + $48)   ; 04 
  db < (ram_0500_data + $60)   ; 05 
  db < (ram_0500_data + $78)   ; 06 
  db < (ram_0500_data + $90)   ; 07 
  db < (ram_0500_data + $A8)   ; 08 
  db < (ram_0500_data + $C0)   ; 09 
  db < (ram_0500_data + $D8)   ; 0A 



tbl_D76D_ppu_hi
  db > $2A20   ; 00 
  db > $2960   ; 01 
  db > $28A0   ; 02 
  db > $23A0   ; 03 
  db > $22E0   ; 04 
  db > $2220   ; 05 
  db > $2160   ; 06 
  db > $20A0   ; 07 
  db > $2BA0   ; 08 



tbl_D776_ppu_lo
  db < $2A20   ; 00 
  db < $2960   ; 01 
  db < $28A0   ; 02 
  db < $23A0   ; 03 
  db < $22E0   ; 04 
  db < $2220   ; 05 
  db < $2160   ; 06 
  db < $20A0   ; 07 
  db < $2BA0   ; 08 



tbl_D77F_match
  db $00   ; 00 
  db $01   ; 01 
  db $02   ; 02 
  db $03   ; 03 
  db $04   ; 04 
  db $FF   ; 05 



tbl_D785_replace
  db $EB   ; 00 
  db $90   ; 01 
  db $91   ; 02 
  db $EB   ; 03 
  db $EB   ; 04 
  db $38   ; 05 



tbl_D78B_ppu_hi
  db > $2A40   ; 00 
  db > $2980   ; 01 
  db > $28C0   ; 02 
  db > $2800   ; 03 
  db > $2300   ; 04 
  db > $2240   ; 05 
  db > $2180   ; 06 
  db > $20C0   ; 07 
  db > $2000   ; 08 



tbl_D794_ppu_lo
  db < $2A40   ; 00 
  db < $2980   ; 01 
  db < $28C0   ; 02 
  db < $2800   ; 03 
  db < $2300   ; 04 
  db < $2240   ; 05 
  db < $2180   ; 06 
  db < $20C0   ; 07 
  db < $2000   ; 08 



tbl_D79D_replace
  db $EB   ; 00 
  db $90   ; 01 
  db $92   ; 02 
  db $EB   ; 03 
  db $EB   ; 04 
  db $38   ; 05 



tbl_D7A3_pos_X
  db $20   ; 00 
  db $20   ; 01 
  db $20   ; 02 
  db $28   ; 03 
  db $28   ; 04 
  db $28   ; 05 
  db $30   ; 06 
  db $30   ; 07 
  db $30   ; 08 
  db $30   ; 09 



tbl_D7AD_pos_X
  db $E0   ; 00 
  db $E0   ; 01 
  db $E0   ; 02 
  db $D8   ; 03 
  db $D8   ; 04 
  db $D8   ; 05 
  db $D0   ; 06 
  db $D0   ; 07 
  db $D0   ; 08 
  db $D0   ; 09 



tbl_D7B7_pos_Y
  db $0C   ; 00 
  db $08   ; 01 
  db $0C   ; 02 
  db $0C   ; 03 
  db $0C   ; 04 
  db $08   ; 05 



tbl_D7BD_pos_X
  db $08   ; 00 
  db $08   ; 01 
  db $08   ; 02 
  db $08   ; 03 
  db $08   ; 04 
  db $04   ; 05 
  db $04   ; 06 
  db $04   ; 07 
  db $04   ; 08 
  db $04   ; 09 
  db $04   ; 0A 



tbl_D7C8
  db $0B   ; 00 
  db $10   ; 01 
  db $0B   ; 02 
  db $0B   ; 03 
  db $0B   ; 04 
  db $08   ; 05 
  db $08   ; 06 
  db $08   ; 07 
  db $08   ; 08 
  db $08   ; 09 
  db $08   ; 0A 



tbl_D7D3
  db $08   ; 00 
  db $0C   ; 01 
  db $08   ; 02 
  db $08   ; 03 
  db $08   ; 04 
  db $08   ; 05 
  db $08   ; 06 
  db $08   ; 07 
  db $06   ; 08 
  db $06   ; 09 
  db $06   ; 0A 



loc_D7DE
  LDA ram_008C_flag
  BNE bra_D82E_RTS
  LDA ram_spawn_timer_lo_bear
  BNE bra_D7FC
  LDA ram_spawn_timer_hi_bear
  BEQ bra_D7F1
  DEC ram_spawn_timer_hi_bear
  LDA #$FF
  STA ram_spawn_timer_lo_bear
  RTS
bra_D7F1
  LDA ram_007C
  BNE bra_D7F8
  INC ram_007C
  RTS
bra_D7F8
  CMP #$80
  BEQ bra_D816
bra_D7FC
  LDX #$01
bra_D7FE_loop
  LDA ram_plr_handler,X
  CMP #$01
  BNE bra_D80A
  LDA ram_0090
  CMP ram_005A_plr,X
  BEQ bra_D80F
bra_D80A
  DEX
  BPL bra_D7FE_loop
  BMI bra_D82E_RTS    ; jmp
bra_D80F
  LDA #$01
  STA ram_0376_flag
  BNE bra_D819    ; jmp
bra_D816
  JSR sub_E215
bra_D819
  LDA ram_0090
  CMP #$09
  BEQ bra_D82E_RTS
loc_D81F
  LDA #$0C
  STA ram_008B
  STA ram_008C_flag
  INC ram_0090
  LDA ram_008A
  CLC
  ADC #$06
  STA ram_008A
bra_D82E_RTS
  RTS



sub_D82F
  LDA ram_008C_flag
  BEQ bra_D887_RTS
  JSR sub_E27A
  JSR sub_E002
  JSR sub_EC51
  JSR sub_D90F
  LDX #$00
  JSR sub_D111
  LDX #$01
  JSR sub_D111
  LDA ram_scroll_Y
  SEC
  SBC #$04
  STA ram_scroll_Y
  JSR sub_D8EA
  DEC ram_008B
  BNE bra_D887_RTS
  LDA #$00
  STA ram_008C_flag
  JSR sub_D8FD_reset_bear_spawn_timer
  JSR sub_E63D
  LDX #$07
bra_D863_loop
  CPX #$00
  BEQ bra_D884
  LDA ram_0091_obj,X
  BEQ bra_D884
  LDA ram_0090
  SEC
  SBC ram_00B2_obj,X
  CMP #$04
  BCC bra_D884
  JSR sub_D888
  CPX #$02
  BCC bra_D884
  CPX #$05
  BCS bra_D884
  LDA #$00
  STA ram_0382_obj,X
bra_D884
  DEX
  BPL bra_D863_loop
bra_D887_RTS
  RTS



sub_D888
loc_D888
  TXA
  CLC
  ADC #$83
  STA ram_03E8_obj,X
  RTS



loc_D890
  LDA ram_008C_flag
  BNE bra_D8A5_RTS
  LDX #$01
bra_D896_loop
  LDA ram_plr_handler,X
  CMP #$01
  BNE bra_D8A2
  LDA ram_plr_pos_Y,X
  CMP #$60
  BCC bra_D8A6
bra_D8A2
  DEX
  BPL bra_D896_loop
bra_D8A5_RTS
  RTS
bra_D8A6
  LDA ram_scroll_Y
  ORA ram_0027_flag
  BEQ bra_D8A5_RTS
  JMP loc_D81F



sub_D8AF
  LDA ram_008C_flag
  BEQ bra_D8A5_RTS
  LDA ram_scroll_Y
  SEC
  SBC #$04
  STA ram_scroll_Y
  CMP #$F0
  BCC bra_D8C8
  LDA ram_0027_flag
  BNE bra_D8C6
; A = 00
  STA ram_scroll_Y
  BEQ bra_D8C8    ; jmp
bra_D8C6
  DEC ram_0027_flag
bra_D8C8
  JSR sub_D8EA
  JSR sub_E277
  JSR sub_EC51
  JSR sub_D90F
  LDA ram_scroll_Y
  BEQ bra_D8DC
  DEC ram_008B
  BNE bra_D8A5_RTS
bra_D8DC
  LDA #$00
  STA ram_008C_flag
  LDA ram_0024
  CLC
  ADC #$06
  STA ram_0024
  JMP loc_E573



sub_D8EA
  LDA ram_scroll_Y
  AND #$F0
  CMP #$F0
  BNE bra_D8FC_RTS
  LDA ram_scroll_Y
  AND #$EF
  STA ram_scroll_Y
  INC ram_00DE_flag
  DEC ram_007A
bra_D8FC_RTS
  RTS



sub_D8FD_reset_bear_spawn_timer
loc_D8FD_reset_bear_spawn_timer
  LDY ram_mountain_completed
  CPY #$04
  BCC bra_D905_not_overflow
  LDY #$04
bra_D905_not_overflow
  LDA tbl_D75E,Y
  STA ram_spawn_timer_lo_bear
  LDA #$01
  STA ram_spawn_timer_hi_bear
bra_D90E_RTS
  RTS



sub_D90F
  LDA ram_008D
  CMP ram_008A
  BCS bra_D90E_RTS
  JMP loc_F2EC



tbl_D918
  db $F8   ; 00 
  db $08   ; 01 



tbl_D91A
  db $00   ; 00 
  db $05   ; 01 



sub_D91C
  TXA
  PHA
  TYA
  PHA
  TXA
  ASL
  ASL
  TAY
  LDA ram_spr_Y + $1C,Y
  STA ram_000B
  LDA ram_spr_X + $1C,Y
  STA ram_000A
  LDA ram_0062_plr,X
  STA ram_000C
  TXA
  PHA
  LDA tbl_D91A,X
  TAX
  LDA ram_plr_counter_blocks,X
  CMP #$63
  BCS bra_D942_not_overflow
  INC ram_plr_counter_blocks,X
bra_D942_not_overflow
  PLA
  TAX
  LDY #$00
bra_D946_loop
  LDA ram_spr_Y + $D0,Y
  CMP #$F8
  BEQ bra_D957
  INY
  INY
  INY
  INY
  CPY #$18
  BCC bra_D946_loop
  BCS bra_D9A8    ; jmp
bra_D957
; ram_giant_bird_Y_pos
  LDA ram_00D7,X ; 00D7 00D8 
  CMP #$06
  BCS bra_D967
  CMP #$03
  BCC bra_D964
  JSR sub_D9AD
bra_D964
  LDA #$03
  db $2C   ; BIT opcode
bra_D967
  LDA #$02
  STA ram_spr_A + $D0,Y
  LDX ram_000C
  LDA tbl_D918,X
  CLC
  ADC ram_000A
  STA ram_spr_X + $D0,Y
  LDA ram_000B
  SEC
  SBC #$08
  STA ram_spr_Y + $D0,Y
  LDA #$0B
  LDX ram_0600_data + $3E
  BNE bra_D988
  LDA #$0A
bra_D988
  STA ram_spr_T + $D0,Y
  TYA
  LSR
  LSR
  TAY
  LDA #$00
  STA ram_0600_data + $50,Y
  STA ram_0600_data + $40,Y
  STA ram_0600_data + $60,Y
  LDA #$FE
  STA ram_0600_data + $48,Y
  LDA ram_000C
  BNE bra_D9A5
  LDA #$FF
bra_D9A5
  STA ram_0600_data + $58,Y
bra_D9A8
  PLA
  TAY
  PLA
  TAX
  RTS



sub_D9AD
  LDA ram_0600_data + $3F
  ORA ram_ppu_buffer
  BNE bra_D9C3_RTS
  TXA
  PHA
  LDX #$0F
  JSR sub_F691
  LDA #$01
  STA ram_0600_data + $3F
  PLA
  TAX
bra_D9C3_RTS
  RTS



tbl_D9C4
; 01 
  db $00   ; 00 
  db $40   ; 01 
  db $C0   ; 02 
  db $80   ; 03 
; 02 
  db $40   ; 00 
  db $00   ; 01 
  db $80   ; 02 
  db $C0   ; 03 



sub_D9CC
  LDY #$14
bra_D9CE_loop
  LDA ram_spr_Y + $D0,Y
  CMP #$F8
  BEQ bra_DA44
  TYA
  LSR
  LSR
  TAX
  LDA ram_0600_data + $50,X
  CLC
  ADC ram_0600_data + $40,X
  STA ram_0600_data + $40,X
  LDA ram_spr_Y + $D0,Y
  ADC ram_0600_data + $48,X
  STA ram_spr_Y + $D0,Y
  CMP #$F4
  BCS bra_DA3A
  LDA ram_0600_data + $58,X
  STA ram_0003
  ADC ram_spr_X + $D0,Y
  STA ram_spr_X + $D0,Y
  INC ram_0600_data + $60,X
  TXA
  PHA
  LDA ram_0600_data + $60,X
  AND #$30
  LSR
  LSR
  LSR
  LSR
  LDX ram_0003
  DEX
  BEQ bra_DA11
  CLC
  ADC #$04
bra_DA11
  TAX
  LDA ram_spr_A + $D0,Y
  AND #$03
  ORA tbl_D9C4,X
  STA ram_spr_A + $D0,Y
  PLA
  TAX
  LDA ram_0600_data + $48,X
  CMP #$05
  BPL bra_DA44
  LDA ram_0600_data + $50,X
  CLC
  ADC #< $0040
  STA ram_0600_data + $50,X
  LDA ram_0600_data + $48,X
  ADC #> $0040
  STA ram_0600_data + $48,X
  JMP loc_DA44
bra_DA3A
  LDA #$F8
  STA ram_spr_Y + $D0,Y
  LDA #$00
  STA ram_spr_X + $D0,Y
bra_DA44
loc_DA44
  DEY
  DEY
  DEY
  DEY
  BPL bra_D9CE_loop
  RTS



sub_DA4B
  LDX #$01
bra_DA4D_loop
  LDA ram_plr_pos_Y,X
  CLC
  ADC #$0C
  JSR sub_D1F9
  TAY
  CPY #$09
  BEQ bra_DA93
  CPY ram_0786
  BEQ bra_DA64
  CPY ram_0787
  BNE bra_DA93
bra_DA64
  LDA ram_0600_data + $2F,Y
  CMP #$01
  BNE bra_DA93
  LDA ram_plr_pos_X,X
  SEC
  SBC #$02
  CMP tbl_D7A3_pos_X,Y
  BCC bra_DA87
  CLC
  ADC #$12
  CMP tbl_D7AD_pos_X,Y
  BCC bra_DA93
  LDA tbl_D7AD_pos_X,Y
  SEC
  SBC #$10
  LDY #$00
  BEQ bra_DA8F    ; jmp
bra_DA87
  LDA tbl_D7A3_pos_X,Y
  SEC
  SBC #$FE
  LDY #$01
bra_DA8F
  STA ram_plr_pos_X,X
  STY ram_0062_plr,X
bra_DA93
  DEX
  BPL bra_DA4D_loop
  RTS



tbl_DA97
  db $FC   ; 00 
  db $0C   ; 01 



sub_DA99
  JSR sub_DDC9
  BCC bra_DAD3
  LDA #$00
  STA ram_0080_plr,X
  LDA #$04
  STA ram_0000
  JSR sub_DAB2
  BCC bra_DAD4_RTS
  LDY ram_0062_plr,X
  LDA tbl_DA97,Y
  STA ram_0000
sub_DAB2
  JSR sub_DAD5
  BCS bra_DABC
bra_DAB7
  LDA #con_sfx_1_04
  STA ram_sfx_1
  RTS
bra_DABC
  JSR sub_DBB4
  STY ram_005C_plr,X
  LDA ram_0003
  STA ram_007D_plr,X
  JSR sub_DAF2
  BCS bra_DAB7
  JSR sub_D91C
  LDA ram_0084_plr,X
  ORA #$01
  STA ram_0084_plr,X
bra_DAD3
  CLC
bra_DAD4_RTS
  RTS



sub_DAD5
  TXA
  ASL
  ASL
  TAY
  LDA ram_spr_X + $1C,Y
  CLC
  ADC ram_0000
  LDY ram_005A_plr,X
  INY
  CPY #$0A
  BCS bra_DAD3
  CMP tbl_D7A3_pos_X,Y
  BCC bra_DAD3
  CMP tbl_D7AD_pos_X,Y
  BCS bra_DAD3
bra_DAF0
  SEC
  RTS



sub_DAF2
  LDA #$00
  STA ram_0600_data + $3E
  LDA (ram_0003),Y
  BEQ bra_DAF0
  CMP #$03
  BPL bra_DAF0
  CMP #$FF
  BEQ bra_DAF0
  CMP #$02
  BNE bra_DB0E
  PHA
  LDA #$01
  STA ram_0600_data + $3E
  PLA
bra_DB0E
  CLC
  ADC ram_0002
  STA (ram_0003),Y
  CMP #$03
  BMI bra_DB1B
  LDA #$FF
  STA (ram_0003),Y
bra_DB1B
  CLC
  RTS



sub_DB1D
  STA ram_0008
  BNE bra_DB2C
  CPY #$08
  BCC bra_DB2C
  LDA ram_0091_obj,Y ; 0099 009A 009B 
  CMP #$02
  BEQ bra_DB31
bra_DB2C
  LDA ram_0091_obj,Y ; 0091 0092 0093 0094 0095 0096 0097 0098 0099 009A 009B 
  BPL bra_DBA4
bra_DB31
  LDA ram_0055
  BEQ bra_DB65
  CMP #$02
  BEQ bra_DB65
  CPY #$08
  BCS bra_DB65
  LDX ram_00B2_obj,Y
  LDA ram_0008
  BNE bra_DB54
  LDA ram_009C_obj_pos_X,Y
  BMI bra_DB4B
  LDA #$10
  db $2C   ; BIT opcode
bra_DB4B
  LDA #$F8
  CLC
  ADC ram_009C_obj_pos_X,Y
  JMP loc_DB57
bra_DB54
  LDA ram_009C_obj_pos_X,Y
loc_DB57
  CLC
  ADC tbl_D7BD_pos_X,Y
; bzk bug, this refs to 0x0018B2 when X = FF
  CMP tbl_D7A3_pos_X,X
  BCC bra_DBA4
; bzk bug, this refs to 0x0018BC when X = FF
  CMP tbl_D7AD_pos_X,X
  BCS bra_DBA4
bra_DB65
  LDA ram_009C_obj_pos_X,Y
  CLC
  ADC tbl_D7BD_pos_X,Y
  SEC
  SBC ram_000A
  STA ram_0000
  JSR sub_D2F9_EOR_if_negative
  PHA
  LDA ram_0008
  BEQ bra_DB81
  PLA
  CMP tbl_D7D3,Y
  BCS bra_DBA4
  BCC bra_DB86    ; jmp
bra_DB81
  PLA
  CMP #$0C
  BCS bra_DBA4
bra_DB86
  LDA ram_00A7_obj_pos_Y,Y
  CLC
  ADC tbl_D7B7_pos_Y,Y
  SEC
  SBC ram_000B
  JSR sub_D2F9_EOR_if_negative
  PHA
  CPY #$00
  BNE bra_DB9C
  LDA ram_0008
  BEQ bra_DBA6
bra_DB9C
  PLA
  CMP tbl_D7C8,Y
  BCS bra_DBA4
bra_DBA2
  SEC
  RTS
bra_DBA4
  CLC
  RTS
bra_DBA6
  PLA
  CMP #$10
  BCS bra_DBA4
  BCC bra_DBA2    ; jmp
bra_DBAD
  LDA #$FF
  RTS



sub_DBB0
  LDY #$05
  BNE bra_DBB6    ; jmp



sub_DBB4
loc_DBB4
  LDY #$04
bra_DBB6
  STY ram_0004
  STA ram_0000
  LDA #$FF
  STA ram_0783_plr,X
  LDA #$00
  STA ram_0343_plr,X
  LDY ram_005A_plr,X
  LDA ram_0082_plr,X
  BEQ bra_DBCB
  INY
bra_DBCB
; ram_giant_bird_Y_pos
  STY ram_00D7,X ; 00D7 00D8 
  CPY #$0A
  BCS bra_DBAD
  LDA ram_0000
  CMP tbl_D7A3_pos_X,Y
  BCC bra_DC56
  CMP tbl_D7AD_pos_X,Y
  BCS bra_DC56
  LDA #$02
  STA ram_0002
  LDA ram_0000
  JSR sub_EDBF
  STA ram_00D4,X
; ram_giant_bird_Y_pos
  LDY ram_00D7,X ; 00D7 00D8 
  LDA tbl_D762,Y
  STA ram_0003
  LDA ram_00D4,X
  SEC
  SBC #$04
  PHA
  TAY
  LDA (ram_0003),Y
  BPL bra_DBFD
  INC ram_0343_plr,X
bra_DBFD
; ram_giant_bird_Y_pos
  LDA ram_00D7,X ; 00D7 00D8 
  LDY #$00
  CMP ram_0786
  BEQ bra_DC0C
  INY
  CMP ram_0787
  BNE bra_DC4D
bra_DC0C
  STY ram_0000
  LDA ram_plr_handler,X
  CMP #$04
  BEQ bra_DC18
  CMP #$02
  BNE bra_DC34
bra_DC18
  LDA ram_0068_plr,X
  BEQ bra_DC34
  LDA ram_07D0_obj + $07,Y ; 07D7 07D8 
  BEQ bra_DC2B
  LDA ram_0068_plr,X
  CMP #$01
  BNE bra_DC34
  LDA #$14
  BNE bra_DC36    ; jmp
bra_DC2B
  LDA ram_0068_plr,X
  CMP #$02
  BNE bra_DC34
  LDA #$04
  db $2C   ; BIT opcode
bra_DC34
  LDA #$09
bra_DC36
  CLC
  ADC ram_plr_pos_X,X
  CMP ram_0788,Y
  BCC bra_DC43
  CMP ram_078A,Y
  BCC bra_DC59
bra_DC43
  CMP ram_078C,Y
  BCC bra_DC4D
  CMP ram_078E,Y
  BCC bra_DC59
bra_DC4D
  LDA ram_002D_plr,X
  BNE bra_DC5E
  PLA
  TAY
bra_DC53
  LDA (ram_0003),Y
  RTS
bra_DC56
  LDA #$00
bra_DC58_RTS
  RTS
bra_DC59
  LDA ram_0000
  STA ram_0783_plr,X
bra_DC5E
  PLA
  TAY
  LDA (ram_0003),Y
  BMI bra_DC56
  CMP #$04
  BEQ bra_DC56
  BNE bra_DC53    ; jmp



sub_DC6A
  LDA ram_ppu_buffer
  BNE bra_DC58_RTS
  STA ram_buffer_index
  LDA ram_0084_plr
  BEQ bra_DC80
  LDX #$00
  LDY #$00
  JSR sub_DC97
  JSR sub_DDA9
bra_DC80
  LDA ram_0084_plr + $01
  BEQ bra_DC58_RTS
  LDX #$01
  LDY ram_buffer_index
  JSR sub_DC97
  JMP loc_DDA9



tbl_DC8F
; 03 
  dw tbl_D76D_ppu_hi - $01
  dw tbl_D776_ppu_lo - $01
; 07 
  dw tbl_D78B_ppu_hi - $01
  dw tbl_D794_ppu_lo - $01



sub_DC97
  LDA ram_0084_plr,X
  AND #$01
  BNE bra_DCA4
  LDA ram_0084_plr,X
  AND #$02
  BNE bra_DCAD
  RTS
bra_DCA4
  JSR sub_DDB6
  JSR sub_DCF0
  JMP loc_DCB3
bra_DCAD
  JSR sub_DDB6
  JSR sub_DCF6
loc_DCB3
sub_DCB3   ; X = 02
; ram_giant_bird_Y_pos
; also ram_00D9
  LDA ram_00D7,X ; 00D7 00D8 00D9 
  PHA
  TAY
  LDA (ram_0005),Y
  JSR sub_DCEA_write_A_to_ppu_buffer
  INY
  STY ram_0000
  PLA
  TAY
; also ram_giant_bird_X_pos
  LDA ram_00D4,X ; 00D4 00D5 00D6 
  CLC
  ADC (ram_0007),Y
  JSR sub_DCEA_write_A_to_ppu_buffer
  INY
  LDA #$01
  STA ram_ppu_buffer,Y
  INY
  STY ram_0000
; also ram_007F
  LDA ram_007D_plr,X ; 007D 007E 007F 
  STA ram_0003
; also ram_005E
  LDY ram_005C_plr,X ; 005C 005D 005E 
  JSR sub_DE12_convert_byte
  JSR sub_DCEA_write_A_to_ppu_buffer
  LDA #$00
  STA ram_ppu_buffer + $01,Y
  INY
  STY ram_buffer_index
  LDX ram_000F
  RTS



sub_DCEA_write_A_to_ppu_buffer
  LDY ram_0000
  STA ram_ppu_buffer,Y
  RTS



sub_DCF0
  LDA #$04
  LDY #$03
  BNE bra_DCFA    ; jmp



sub_DCF6
  LDA #$05
  LDY #$07
bra_DCFA
  STA ram_0004
  LDX #$03
; 0005-0008
bra_DCFE_loop
  LDA tbl_DC8F,Y
  STA ram_0005,X
  DEY
  DEX
  BPL bra_DCFE_loop
  LDY ram_0000
  LDX ram_000F
bra_DD0B_RTS
  RTS



tbl_DD0C
  db $18   ; 00 
  db $18   ; 01 
  db $18   ; 02 
  db $16   ; 03 
  db $16   ; 04 
  db $16   ; 05 
  db $14   ; 06 
  db $14   ; 07 
  db $14   ; 08 
  db $14   ; 09 



sub_DD16
  JSR sub_DCF6
  LDX #$01
  BNE bra_DD22    ; jmp



sub_DD1D
  JSR sub_DCF0
  LDX #$00
bra_DD22
  STX ram_000B
loc_DD24_loop
  LDA ram_00DA_plr,X
  CMP #$0A
  BEQ bra_DD0B_RTS
  TAY
  TAX
  JSR sub_DDA1
  CLC
  ADC tbl_D762,X
  STA ram_0003
  JSR sub_DDA1
  CLC
  ADC #$04
  CLC
; Y is always >= 01 here
  ADC (ram_0007),Y
  STA ram_ppu_buffer + $01
  LDA tbl_DD0C,X
  STA ram_ppu_buffer + $02
  LDA (ram_0005),Y
  STA ram_ppu_buffer
  LDY #$00
  STY ram_0002
bra_DD50_loop
  JSR sub_DE12_convert_byte
  LDY ram_0002
  STA ram_ppu_buffer + $03,Y
  INY
  STY ram_0002
  TYA
  CMP tbl_DD0C,X
  BCC bra_DD50_loop
  LDA #$00
  STA ram_ppu_buffer + $03,Y
  LDX ram_000B
  BNE bra_DD97
  LDY ram_00DA_plr,X
  LDA ram_0600_data + $2F,Y
  BPL bra_DD97
  STA ram_0000
  LDY #$03
bra_DD75_loop
  LDA ram_0000
  LDX ram_ppu_buffer,Y
  BEQ bra_DD97
  CPX #$38
  BEQ bra_DD94
  CPX #$EB
  BNE bra_DD91
  CMP #$90
  BCC bra_DD91
  CMP #$D3
  BEQ bra_DD8F
  LDA #$8F
  db $2C   ; BIT opcode
bra_DD8F
  LDA #$8C
bra_DD91
  STA ram_ppu_buffer,Y
bra_DD94
  INY
  BNE bra_DD75_loop
bra_DD97
  JSR sub_C14E
  LDX ram_000B
  INC ram_00DA_plr,X
  JMP loc_DD24_loop



sub_DDA1
  LDA #$18
  SEC
  SBC tbl_DD0C,X
  LSR
  RTS



sub_DDA9
loc_DDA9
  LDA #con_sfx_1_block_placed_or_destroyed
  STA ram_sfx_1
  LDA ram_000E
  EOR #$FF
  AND ram_0084_plr,X
  STA ram_0084_plr,X
  RTS



sub_DDB6
  STA ram_000E
  STX ram_000F
  STY ram_0000
  RTS



loc_DDBD_convert_byte
  LDY #$06
bra_DDBF_loop
  DEY
  CMP tbl_D77F_match,Y
  BNE bra_DDBF_loop
  LDA tbl_D785_replace,Y
  RTS



sub_DDC9
  LDA ram_0080_plr,X
  BEQ bra_DE10
  LDA #$00
  STA ram_0080_plr,X
  LDA #$04
  STA ram_0000
  JSR sub_DDE1
  BCC bra_DE11_RTS
  LDY ram_0062_plr,X
  LDA tbl_DA97,Y
  STA ram_0000
sub_DDE1
  JSR sub_DAD5
  BCS bra_DDEC
  LDA #con_sfx_1_04
  STA ram_sfx_1
  CLC
  RTS
bra_DDEC
  JSR sub_DBB0
  LDA ram_0090
  SEC
; ram_giant_bird_Y_pos
  SBC ram_00D7,X ; 00D7 00D8 
  CMP #$03
  BCS bra_DE10
  STY ram_005C_plr,X
  LDA ram_0003
  STA ram_007D_plr,X ; 007D 007E 
  JSR sub_DAF2
  BCC bra_DE07
  LDA ram_0082_plr,X
  BNE bra_DE11_RTS
bra_DE07
  JSR sub_D91C
  LDA ram_0084_plr,X
  ORA #$02
  STA ram_0084_plr,X
bra_DE10
  CLC
bra_DE11_RTS
  RTS



sub_DE12_convert_byte
; out
;    ; A = converted byte
  LDA ram_0004
  CMP #$05
  BEQ bra_DE1D    ; if indirect 0500+
; if indirect 0400+
  LDA (ram_0003),Y
  JMP loc_DDBD_convert_byte
bra_DE1D
  LDA (ram_0003),Y
  JMP loc_DEEA_convert_byte



sub_DE22
  LDA ram_ppu_buffer
  BNE bra_DE11_RTS
  STA ram_buffer_index
  LDA #$05
  STA ram_000F
bra_DE2E_loop
  TAX
  LDA ram_0091_obj,X ; 0096 0097 0098 
  BPL bra_DE9C
  LDA ram_00B2_obj,X ; 00B7 00B8 
  BEQ bra_DE9C
  STA ram_00D9
  LDA ram_009C_obj_pos_X,X ; 00A1 00A2 
  CLC
  ADC #$08
  STA ram_000E
  LDA #$00
  STA ram_000D
loc_DE44
  JSR sub_DEB2
  BPL bra_DEA5
  LDA #$01
  STA (ram_0003),Y
  LDX #$02
; bzk optimize, X = 2
  STY ram_005E - $02,X
  LDA ram_0003
; bzk optimize, X = 2
  STA ram_007F - $02,X
  LDA ram_000E
  JSR sub_EDBF
  STA ram_giant_bird_X_pos
  JSR sub_DCF0
  LDY ram_buffer_index
  STY ram_0000
  LDX #$02
  JSR sub_DCB3
  LDY ram_00D9
  LDA ram_0600_data + $2F,Y
  BPL bra_DE83
  CMP #$90
  BCS bra_DE7D
  CMP #$8C
  BEQ bra_DE7B
  LDA #$CD
  db $2C   ; BIT opcode
bra_DE7B
  LDA #$D3
bra_DE7D
  LDY ram_buffer_index
  STA ram_ppu_buffer - $01,Y
bra_DE83
  LDA ram_000D
  BNE bra_DEA9
  LDX ram_000F
  LDA ram_00BD_obj,X
  BMI bra_DE90
  LDA #$08
  db $2C   ; BIT opcode
bra_DE90
  LDA #$F8
  STA ram_000D
  CLC
  ADC ram_000E
  STA ram_000E
  JMP loc_DE44
bra_DE9C
  INC ram_000F
  LDA ram_000F
  CMP #$08
  BCC bra_DE2E_loop
  RTS
bra_DEA5
  LDA ram_000D
  BEQ bra_DE9C
bra_DEA9
  LDA #con_sfx_1_block_placed_or_destroyed
  STA ram_sfx_1
  LDX ram_000F
  JMP loc_D888



sub_DEB2
loc_DEB2
  LDX ram_000F
  LDA ram_00B2_obj,X ; 00B3 00B4 00B5 00B7 00B8 
  AND #$0F
  db $2C   ; BIT opcode
sub_DEB9
  LDA ram_000F
  PHA
  LDA ram_000E
  CMP #$20
  BCC bra_DEE4
  CMP #$E0
  BCS bra_DEE4
  JSR sub_EDBF
  SEC
  SBC #$04
  STA ram_0002
  PLA
  TAY
  LDA tbl_D762,Y
  STA ram_0003
  LDA #$05
  STA ram_0004
  LDY ram_0002
  LDA (ram_0003),Y
  STA ram_0002
  DEC ram_0004
  LDA (ram_0003),Y
  RTS
bra_DEE4
  PLA
  LDA #$01
  STA ram_0002
  RTS



loc_DEEA_convert_byte
  LDY #$06
bra_DEEC_loop
  DEY
  CMP tbl_D77F_match,Y
  BNE bra_DEEC_loop
  LDA tbl_D79D_replace,Y
  RTS



tbl_DEF6
  db $50   ; 00 
  db $80   ; 01 
  db $B0   ; 02 
  db $E0   ; 03 



tbl_DEFA
  db $00   ; 00 
  db $00   ; 01 
  db $00   ; 02 
  db $02   ; 03 
  db $04   ; 04 
  db $07   ; 05 
  db $08   ; 06 
  db $0C   ; 07 
  db $0E   ; 08 
  db $12   ; 09 
  db $12   ; 0A 
  db $15   ; 0B 
  db $17   ; 0C 
  db $17   ; 0D 
  db $18   ; 0E 
  db $23   ; 0F 
  db $23   ; 10 
  db $26   ; 11 
  db $2D   ; 12 
  db $30   ; 13 
  db $39   ; 14 
  db $44   ; 15 
  db $4E   ; 16 
  db $53   ; 17 
  db $5A   ; 18 
  db $60   ; 19 
  db $6A   ; 1A 
  db $6E   ; 1B 
  db $6F   ; 1C 
  db $73   ; 1D 
  db $78   ; 1E 
  db $81   ; 1F 
  db $89   ; 20 



tbl_DF1B
;               +----------- 
;               |     +----- 
;               |     |
  db $20 * $04 + $09   ; 00 
  db $20 * $04 + $05   ; 01 
  db $20 * $05 + $12   ; 02 
  db $20 * $04 + $11   ; 03 
  db $20 * $05 + $0B   ; 04 
  db $20 * $01 + $07   ; 05 
  db $20 * $03 + $07   ; 06 
  db $20 * $03 + $0C   ; 07 
  db $20 * $04 + $13   ; 08 
  db $20 * $01 + $07   ; 09 
  db $20 * $03 + $05   ; 0A 
  db $20 * $04 + $01   ; 0B 
  db $20 * $04 + $0D   ; 0C 
  db $20 * $06 + $0B   ; 0D 
  db $20 * $07 + $12   ; 0E 
  db $20 * $01 + $02   ; 0F 
  db $20 * $05 + $02   ; 10 
  db $20 * $05 + $0E   ; 11 
  db $20 * $06 + $08   ; 12 
  db $20 * $01 + $07   ; 13 
  db $20 * $06 + $07   ; 14 
  db $20 * $06 + $10   ; 15 
  db $20 * $06 + $04   ; 16 
  db $20 * $06 + $12   ; 17 
  db $20 * $04 + $01   ; 18 
  db $20 * $02 + $0A   ; 19 
  db $20 * $04 + $04   ; 1A 
  db $20 * $04 + $0C   ; 1B 
  db $20 * $04 + $14   ; 1C 
  db $20 * $05 + $08   ; 1D 
  db $20 * $06 + $02   ; 1E 
  db $20 * $02 + $04   ; 1F 
  db $20 * $02 + $0A   ; 20 
  db $20 * $02 + $10   ; 21 
  db $20 * $06 + $0A   ; 22 
  db $20 * $06 + $11   ; 23 
  db $20 * $02 + $08   ; 24 
  db $20 * $03 + $10   ; 25 
  db $20 * $04 + $04   ; 26 
  db $20 * $01 + $06   ; 27 
  db $20 * $01 + $0E   ; 28 
  db $20 * $03 + $04   ; 29 
  db $20 * $03 + $10   ; 2A 
  db $20 * $06 + $07   ; 2B 
  db $20 * $06 + $0D   ; 2C 
  db $20 * $06 + $13   ; 2D 
  db $20 * $05 + $02   ; 2E 
  db $20 * $05 + $0B   ; 2F 
  db $20 * $05 + $11   ; 30 
  db $20 * $01 + $0C   ; 31 
  db $20 * $04 + $05   ; 32 
  db $20 * $04 + $0B   ; 33 
  db $20 * $04 + $11   ; 34 
  db $20 * $04 + $16   ; 35 
  db $20 * $05 + $07   ; 36 
  db $20 * $05 + $0E   ; 37 
  db $20 * $06 + $0F   ; 38 
  db $20 * $06 + $14   ; 39 
  db $20 * $01 + $07   ; 3A 
  db $20 * $02 + $04   ; 3B 
  db $20 * $02 + $10   ; 3C 
  db $20 * $03 + $03   ; 3D 
  db $20 * $03 + $0D   ; 3E 
  db $20 * $04 + $06   ; 3F 
  db $20 * $04 + $10   ; 40 
  db $20 * $05 + $03   ; 41 
  db $20 * $05 + $09   ; 42 
  db $20 * $05 + $0F   ; 43 
  db $20 * $07 + $03   ; 44 
  db $20 * $07 + $05   ; 45 
  db $20 * $07 + $0D   ; 46 
  db $20 * $07 + $14   ; 47 
  db $20 * $02 + $08   ; 48 
  db $20 * $02 + $0F   ; 49 
  db $20 * $05 + $03   ; 4A 
  db $20 * $05 + $0B   ; 4B 
  db $20 * $05 + $13   ; 4C 
  db $20 * $06 + $03   ; 4D 
  db $20 * $06 + $0B   ; 4E 
  db $20 * $03 + $0D   ; 4F 
  db $20 * $04 + $12   ; 50 
  db $20 * $05 + $05   ; 51 
  db $20 * $05 + $0F   ; 52 
  db $20 * $07 + $0B   ; 53 
  db $20 * $03 + $04   ; 54 
  db $20 * $04 + $08   ; 55 
  db $20 * $04 + $0E   ; 56 
  db $20 * $04 + $14   ; 57 
  db $20 * $05 + $0C   ; 58 
  db $20 * $07 + $0C   ; 59 
  db $20 * $07 + $12   ; 5A 
  db $20 * $05 + $07   ; 5B 
  db $20 * $05 + $0E   ; 5C 
  db $20 * $06 + $04   ; 5D 
  db $20 * $06 + $07   ; 5E 
  db $20 * $06 + $13   ; 5F 
  db $20 * $06 + $0E   ; 60 
  db $20 * $01 + $03   ; 61 
  db $20 * $03 + $04   ; 62 
  db $20 * $04 + $0E   ; 63 
  db $20 * $05 + $09   ; 64 
  db $20 * $06 + $10   ; 65 
  db $20 * $07 + $04   ; 66 
  db $20 * $07 + $09   ; 67 
  db $20 * $06 + $08   ; 68 
  db $20 * $06 + $10   ; 69 
  db $20 * $06 + $14   ; 6A 
  db $20 * $04 + $0B   ; 6B 
  db $20 * $06 + $09   ; 6C 
  db $20 * $06 + $14   ; 6D 
  db $20 * $06 + $0F   ; 6E 
  db $20 * $06 + $0B   ; 6F 
  db $20 * $04 + $08   ; 70 
  db $20 * $04 + $10   ; 71 
  db $20 * $05 + $04   ; 72 
  db $20 * $06 + $14   ; 73 
  db $20 * $06 + $07   ; 74 
  db $20 * $06 + $10   ; 75 
  db $20 * $07 + $02   ; 76 
  db $20 * $07 + $09   ; 77 
  db $20 * $07 + $11   ; 78 
  db $20 * $01 + $0B   ; 79 
  db $20 * $02 + $10   ; 7A 
  db $20 * $03 + $07   ; 7B 
  db $20 * $03 + $10   ; 7C 
  db $20 * $04 + $02   ; 7D 
  db $20 * $04 + $0B   ; 7E 
  db $20 * $06 + $02   ; 7F 
  db $20 * $06 + $09   ; 80 
  db $20 * $06 + $11   ; 81 
  db $20 * $02 + $08   ; 82 
  db $20 * $02 + $11   ; 83 
  db $20 * $04 + $07   ; 84 
  db $20 * $04 + $15   ; 85 
  db $20 * $05 + $10   ; 86 
  db $20 * $07 + $04   ; 87 
  db $20 * $07 + $0D   ; 88 
  db $20 * $07 + $15   ; 89 



sub_DFA5
  LDA ram_mountain_current
  AND #$1F
  TAY
  RTS



sub_DFAB
  JSR sub_DFEA
  BEQ bra_DFE9_RTS
  TAX
bra_DFB1_loop
  LDA #$04
  STA ram_0004
  STA ram_0006
  JSR sub_DFF8
  LDA tbl_DF1B,X
  AND #$1F
  CLC
  ADC tbl_D762,Y
  SEC
  SBC #$01
  STA ram_0003
  CLC
  ADC #$18
  STA ram_0005
  LDY #$02
bra_DFCF_loop
  LDA #$03
  STA (ram_0003),Y
  CPY #$01
  BNE bra_DFE1
  LDA #$04
  STA (ram_0005),Y
  INC ram_0006
  STA (ram_0005),Y
  DEC ram_0006
bra_DFE1
  DEY
  BPL bra_DFCF_loop
  DEX
  CPX ram_000A
  BNE bra_DFB1_loop
bra_DFE9_RTS
  RTS



sub_DFEA
  JSR sub_DFA5
  LDA tbl_DEFA,Y
  STA ram_000A
  LDA tbl_DEFA + $01,Y
  CMP ram_000A
  RTS



sub_DFF8
  LDA tbl_DF1B,X
; / 20
  LSR
  LSR
  LSR
  LSR
  LSR
  TAY
  RTS



sub_E002
  LDX #$0B
bra_E004_loop
  LDA #$00
  STA ram_0600_data,X
  STA ram_0600_data + $10,X
  STA ram_0600_data + $20,X
  DEX
  BPL bra_E004_loop
  JSR sub_DFEA
  BEQ bra_E05D_RTS
  STA ram_000B
  LDX #$00
bra_E01B_loop
  LDY ram_000B
; bzk optimize, JSR to 0x002008
  LDA tbl_DF1B,Y
; / 20
  LSR
  LSR
  LSR
  LSR
  LSR
  STA ram_0000
  LDA ram_0090
  SEC
  SBC ram_0000
  CMP #$04
  BCS bra_E054
  TAY
  LDA tbl_DEF6,Y
  STA ram_0600_data + $10,X
  LDY ram_000B
  LDA tbl_DF1B,Y
  AND #$1F
  ADC #$04
  ASL
  ASL
  ASL
  STA ram_0600_data,X
  LDA tbl_DF1B,Y
  AND #$1F
  CLC
  ADC #$05
  ASL
  ASL
  ASL
  STA ram_0600_data + $20,X
bra_E054
  INX
  DEC ram_000B
  LDA ram_000B
  CMP ram_000A
  BNE bra_E01B_loop
bra_E05D_RTS
  RTS



loc_E05E
  JSR sub_DFEA
  BEQ bra_E05D_RTS
  STA ram_0001
  LDA #$00
  STA ram_0000
bra_E069_loop
  LDX ram_0001
  JSR sub_DFF8
  LDA tbl_D794_ppu_lo,Y
  STA ram_0002
  LDA tbl_D78B_ppu_hi,Y
  JSR sub_E0A7
  JSR sub_E097
  LDA ram_0000
  CLC
  ADC #$04
  STA ram_0000
  CMP #$38
  BCS bra_E08F
  DEC ram_0001
  LDA ram_0001
  CMP ram_000A
  BNE bra_E069_loop
bra_E08F
  LDY ram_0000
  STY ram_buffer_index
  JMP loc_C14E



sub_E097
  LDA #$C5
  STA ram_ppu_buffer + $02,Y
  LDA #$EB
  STA ram_ppu_buffer + $03,Y
  LDA #$00
  STA ram_ppu_buffer + $04,Y
  RTS



sub_E0A7
  JSR sub_DCEA_write_A_to_ppu_buffer
  LDA tbl_DF1B,X
  AND #$1F
  CLC
  ADC #$04
  CLC
  ADC ram_0002
  STA ram_ppu_buffer + $01,Y
  RTS



sub_E0B9
  LDX #$00
  JSR sub_E0C0
  LDX #$01
sub_E0C0
  LDA ram_003A_plr_timer,X
  BNE bra_E11B
  LDA ram_005A_plr,X
  BEQ bra_E11A_RTS
  LDA ram_plr_handler,X
  CMP #$07
  BEQ bra_E11A_RTS
  LDA ram_002D_plr,X
  BNE bra_E11A_RTS
  LDA ram_plr_pos_X,X
  CLC
  ADC #$08
  STA ram_000A
  LDA ram_plr_pos_Y,X
  CLC
  ADC #$0C
  STA ram_000B
  LDY #$00
bra_E0E2_loop
  LDA ram_0600_data,Y
  BEQ bra_E115
  CLC
  ADC #$04
  SEC
  SBC ram_000A
  STA ram_0000
  JSR sub_D2F9_EOR_if_negative
  CMP #$0C
  BCS bra_E115
  LDA ram_0600_data + $10,Y
  SEC
  SBC #$1C
  SEC
  SBC ram_000B
  JSR sub_D2F9_EOR_if_negative
  PHA
  LDA ram_00E6_plr,X
  CMP #$02
  BCS bra_E110
  PLA
  CMP #$1C
  BCC bra_E12F
  BCS bra_E115    ; jmp
bra_E110
  PLA
  CMP #$24
  BCC bra_E12F
bra_E115
  INY
  CPY #$0B
  BCC bra_E0E2_loop
bra_E11A_RTS
  RTS
bra_E11B
  LDA ram_frm_cnt
  AND #$01
  BEQ bra_E12E_RTS
  LDA ram_0068_plr,X
  BEQ bra_E12E_RTS
  CMP #$02
  BEQ bra_E12C
  INC ram_plr_pos_X,X
  db $2C   ; BIT opcode
bra_E12C
  DEC ram_plr_pos_X,X
bra_E12E_RTS
  RTS
bra_E12F
  PHA
  LDA ram_00E6_plr,X
  CMP #$02
  BCS bra_E13D
  PLA
  CMP #$18
  BCC bra_E158
  BCS bra_E142    ; jmp
bra_E13D
  PLA
  CMP #$23
  BCC bra_E158
bra_E142
  LDA ram_0068_plr,X
  BEQ bra_E158
  LDA ram_0000
  CMP #$03
  BCC bra_E153
  CMP #$FD
  BCS bra_E153
  JSR sub_E176
bra_E153
  LDA #$08
  STA ram_003A_plr_timer,X
  RTS
bra_E158
  LDA ram_0000
  BMI bra_E165
  LDA ram_0600_data,Y
  SEC
  SBC #$10
  JMP loc_E16B
bra_E165
  LDA ram_0600_data,Y
  CLC
  ADC #$07
loc_E16B
  STA ram_plr_pos_X,X
  LDA ram_plr_handler,X
  AND #$01
  BNE bra_E184_RTS
  JMP loc_E176



sub_E176
loc_E176
  LDA ram_0000
  ASL
  LDA #$01
  BCS bra_E17E
  ASL ; 02
bra_E17E
  STA ram_0068_plr,X
  AND #$01
  STA ram_0062_plr,X
bra_E184_RTS
  RTS



tbl_E185_pos_Y
  db $28   ; 00 
  db $58   ; 01 
  db $88   ; 02 
  db $B8   ; 03 



sub_E189
  LDX ram_0090
  CPX #$09
  BEQ bra_E1E0_RTS
  LDX ram_007C
  DEX
  BNE bra_E1E1
  LDX #$02
bra_E196_loop
  LDA ram_0091_obj + $08,X ; 0099 009A 009B 
  BNE bra_E1E0_RTS
  DEX
  BPL bra_E196_loop
  LDY ram_0091_obj + $01
  BNE bra_E1E0_RTS
; Y = 00
  TXA
  JSR sub_E23E
  STA ram_0091_obj + $01
  STA ram_03D2_obj + $01
  STY ram_0376_flag
  STY ram_03B1_obj + $01
  STY ram_03C7_obj + $01
  LDA #$40
  STA ram_03BC_obj + $01
  ASL ; 80
  STA ram_03A6_obj + $01
  INY ; 01
  STY ram_00BD_obj + $01
  LDA #$04
  STA ram_009C_obj_pos_X + $01
  LDX ram_0090
  INX
bra_E1C6_loop
  DEX
  CPX ram_0786
  BEQ bra_E1C6_loop
  CPX ram_0787
  BEQ bra_E1C6_loop
  STX ram_00B2_obj + $01
  LDA ram_0090
  SEC
  SBC ram_00B2_obj + $01
  TAX
  LDA tbl_E185_pos_Y,X
  STA ram_00A7_obj_pos_Y + $01
  INC ram_007C
bra_E1E0_RTS
  RTS
bra_E1E1
  DEX
  BNE bra_E1EE
bra_E1E4
  LDA ram_0376_flag
  BNE bra_E215
  DEC ram_00DF_counter
  BEQ bra_E202
  RTS
bra_E1EE
  DEX
  BNE bra_E21A
  LDA ram_0376_flag
  BNE bra_E215
  LDA ram_00A7_obj_pos_Y + $01
  CMP #$17
  BNE bra_E1E4
  LDA ram_009C_obj_pos_X + $01
  CMP #$78
  BNE bra_E1E4
bra_E202
  LDA #$04
  STA ram_007C
  LDA #$0C
  STA ram_00DF_counter
  LDA ram_0091_obj + $01
  CMP #$FF
  BNE bra_E214_RTS
  LDA #$04
  STA ram_0091_obj + $01
bra_E214_RTS
  RTS
bra_E215
sub_E215
  LDA #$00
  STA ram_007C
  RTS
bra_E21A
  DEX
  BNE bra_E235
  DEC ram_00DF_counter
  BPL bra_E225
  LDA #$03
  BNE bra_E23E    ; jmp
bra_E225
  BEQ bra_E214_RTS
  LDA ram_0091_obj + $01
  CMP #$04
  BNE bra_E234_RTS
  LDA ram_00A7_obj_pos_Y + $01
  SEC
  SBC #$01
  STA ram_00A7_obj_pos_Y + $01
bra_E234_RTS
  RTS
bra_E235
  DEX
  BNE bra_E251
  DEC ram_00DF_counter
  BNE bra_E243
  LDA #$10
bra_E23E
sub_E23E
  STA ram_00DF_counter
  INC ram_007C
  RTS
bra_E243
  LDA ram_0091_obj + $01
  CMP #$04
  BNE bra_E250_RTS
  LDA #$05
  CLC
  ADC ram_00A7_obj_pos_Y + $01
  STA ram_00A7_obj_pos_Y + $01
bra_E250_RTS
  RTS
bra_E251
  DEX
  BNE bra_E250_RTS
  DEC ram_00DF_counter
  BNE bra_E250_RTS
  LDA ram_0091_obj + $01
  CMP #$04
  BNE bra_E265
  LDA #$FF
  STA ram_0091_obj + $01
  STA ram_03D2_obj + $01
bra_E265
  LDA ram_0376_flag
  BNE bra_E215
  LDA #$80
  STA ram_007C
  LDA #con_sfx_3_bear_jump
  STA ram_sfx_3
  RTS



tbl_E273
  db $00   ; 00 
  db $18   ; 01 
  db $30   ; 02 
  db $48   ; 03 



sub_E277
  LDX #$03
  db $2C   ; BIT opcode



sub_E27A
  LDX #$01
bra_E27C_loop
  LDA tbl_E273,X
  TAY
  LDA ram_0786,X ; 0786 0787 0788 0789 
  BEQ bra_E296
  LDA ram_spr_Y + $A0,Y
  CMP #$EC
  BCC bra_E296
  LDA #$00
  STA ram_0786,X ; 0786 0787 0788 0789 
  LDA #$FF
  STA ram_06E0_bouns_stage_data + $15,X ; 06F5 06F6 06F7 06F8 
bra_E296
  DEX
  BPL bra_E27C_loop
  RTS



sub_E29A
  LDX #$08
  JSR sub_E303
  LDY #$2C
  LDX #$01
bra_E2A3_loop
  LDA ram_0786,X
  BEQ bra_E2BE
  JSR sub_E321
  TXA
  CLC
  ADC #$06
  TAY
bra_E2B0_loop
  LDA ram_07B0_obj + $07,X
  CLC
  ADC ram_0788,Y
  STA ram_0788,Y
  DEY
  DEY
  BPL bra_E2B0_loop
bra_E2BE
  LDY #$14
  DEX
  BPL bra_E2A3_loop
  LDY #$01
bra_E2C5_loop
  LDA ram_plr_handler,Y
  CMP #$01
  BEQ bra_E2D0
  CMP #$03
  BNE bra_E2F4
bra_E2D0
  LDX ram_005A_plr,Y
  BEQ bra_E2F4
  CPX #$02
  BMI bra_E2F4
  CPX #$09
  BEQ bra_E2F4
  LDA ram_002D_plr,Y
  BNE bra_E2E6
  LDA ram_0343_plr,Y
  BNE bra_E2EC
bra_E2E6
  LDA ram_07B0_obj - $02,X ; 07B0 07B1 07B2 07B3 07B4 07B5 07B6 
  JSR sub_E2FB
bra_E2EC
  LDX ram_0783_plr,Y
  BMI bra_E2F4
  JSR sub_E2F8
bra_E2F4
  DEY
  BPL bra_E2C5_loop
  RTS



sub_E2F8
  LDA ram_07B0_obj + $07,X
sub_E2FB
  CLC
  ADC ram_plr_pos_X,Y
  STA ram_plr_pos_X,Y
  RTS



sub_E303
bra_E303_loop
  LDA ram_07C0_obj,X ; 07C0 07C1 07C2 07C3 07C4 07C5 07C6 07C7 07C8 07C9 07CA 
  CLC
  ADC ram_07A0_obj,X ; 07A0 07A1 07A2 07A3 07A4 07A5 07A6 07A7 07A8 07A9 07AA 
  STA ram_07C0_obj,X ; 07C0 07C1 07C2 07C3 07C4 07C5 07C6 07C7 07C8 07C9 07CA 
  LDA #$00
  ADC ram_0790_obj,X ; 0790 0791 0792 0793 0794 0795 0796 0797 0798 0799 079A 
  LDY ram_07D0_obj,X ; 07D0 07D1 07D2 07D3 07D4 07D5 07D6 07D7 07D8 07D9 07DA 
  BEQ bra_E31A
  JSR sub_D2FB_EOR
bra_E31A
  STA ram_07B0_obj,X ; 07B0 07B1 07B2 07B3 07B4 07B5 07B6 07B7 07B8 07B9 07BA 
  DEX
  BPL bra_E303_loop
  RTS



sub_E321
  LDA #$05
  STA ram_0001
bra_E325_loop
  LDA ram_07B0_obj + $07,X ; 07B7 07B8 07B9 07BA 
  CLC
  ADC ram_spr_X + $A0,Y
  STA ram_spr_X + $A0,Y
  DEY
  DEY
  DEY
  DEY
  DEC ram_0001
  BPL bra_E325_loop
  RTS



tbl_E338
  db $14   ; 00 
  db $2C   ; 01 
  db $44   ; 02 
  db $5C   ; 03 



sub_E33C
  LDX #$0A
  JSR sub_E303
  LDX #$03
bra_E343_loop
  LDA ram_0786,X ; 0786 0787 0788 0789 
  BEQ bra_E362
  LDA tbl_E338,X
  TAY
  JSR sub_E321
  LDA ram_07B0_obj + $07,X ; 07B7 07B8 07B9 07BA 
  PHA
  CLC
  ADC ram_0668_data + $1A,X ; 0682 0683 0684 0685 
  STA ram_0668_data + $1A,X ; 0682 0683 0684 0685 
  PLA
  CLC
  ADC ram_0686_data + $1A,X ; 06A0 06A1 06A2 06A3 
  STA ram_0686_data + $1A,X ; 06A0 06A1 06A2 06A3 
bra_E362
  DEX
  BPL bra_E343_loop
  LDY #$01
bra_E367_loop
  LDA ram_plr_handler,Y
  CMP #$01
  BEQ bra_E372
  CMP #$03
  BNE bra_E37E
bra_E372
  LDA ram_0783_plr,Y
  SEC
  SBC #$1A
  BMI bra_E37E
  TAX
  JSR sub_E2F8
bra_E37E
  DEY
  BPL bra_E367_loop
  RTS



tbl_E382
;         00   01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F
  db $00, $00, $00, $00, $00, $00, $00, $00, $00, $A1, $00, $00, $00, $00, $B0, $00   ; 00 
  db $30, $00, $00, $B1, $00, $08, $A1, $00, $30, $00, $B0, $A3, $F0, $00, $00, $C5   ; 10 
  db $00, $B3, $32, $A0, $D4, $00, $23, $08, $B6, $00, $C3, $31, $00, $08, $08, $B1   ; 20 
  db $23, $00, $E6, $24, $A5, $00, $32, $D5, $00, $C4, $B7, $30, $23, $3C, $F3, $D7   ; 30 
  db $00, $86, $00, $2B, $33, $D7, $34, $00, $B6, $08, $00, $08, $76, $2A, $23, $00   ; 40 
  db $B2, $33, $A6, $34, $E6, $33, $75, $00, $20, $A6, $00, $C6, $D5, $00, $3A, $00   ; 50 
  db $E4, $F7, $00, $D6, $00, $22, $00, $A6, $D7, $D7, $00, $C6, $00, $00, $33, $F6   ; 60 
  db $20, $31, $22, $33, $A4, $B6, $24, $75, $A4, $00, $38, $34, $A5, $34, $38, $F4   ; 70 
  db $A4, $00, $00, $D6, $2B, $C4, $00, $32, $24, $00, $B5, $D3, $29, $22, $34, $24   ; 80 
  db $F2, $B6, $00, $94, $08, $A5, $00, $00, $D6, $00, $00, $00, $00, $24, $00, $C5   ; 90 
  db $00, $00, $76, $65, $23, $34, $34, $D6, $00, $C6, $B5, $22, $32, $34, $E7, $00   ; A0 
  db $66, $76, $A6, $00, $24, $C7, $E5, $00, $F5, $2B, $00, $20, $C7, $F6, $00, $33   ; B0 
  db $E5, $00, $F6, $34, $33, $D6, $20, $00, $33, $A6, $00, $67, $D6, $23, $3B, $00   ; C0 
  db $7D, $E6, $00, $FD, $23, $76, $24, $33, $C7, $23, $E7, $9E, $00, $3B, $2E, $D7   ; D0 



tbl_E462
  db $00   ; 00 
  db $40   ; 01 
  db $40   ; 02 
  db $00   ; 03 
  db $40   ; 04 
  db $6D   ; 05 
  db $74   ; 06 
  db $20   ; 07 
  db $00   ; 08 
  db $10   ; 09 
  db $2A   ; 0A 
  db $01   ; 0B 
  db $41   ; 0C 
  db $0A   ; 0D 
  db $48   ; 0E 
  db $00   ; 0F 



tbl_E472
  db $00   ; 00 
  db $48   ; 01 
  db $00   ; 02 
  db $00   ; 03 
  db $69   ; 04 
  db $24   ; 05 
  db $24   ; 06 
  db $00   ; 07 
  db $00   ; 08 
  db $44   ; 09 
  db $21   ; 0A 
  db $61   ; 0B 
  db $04   ; 0C 
  db $08   ; 0D 
  db $12   ; 0E 
  db $10   ; 0F 



tbl_E482
  db $00   ; 00 
  db $40   ; 01 
  db $09   ; 02 
  db $40   ; 03 
  db $68   ; 04 
  db $04   ; 05 
  db $48   ; 06 
  db $00   ; 07 
  db $02   ; 08 
  db $6C   ; 09 
  db $08   ; 0A 
  db $04   ; 0B 
  db $10   ; 0C 
  db $48   ; 0D 
  db $00   ; 0E 
  db $66   ; 0F 



tbl_E492
  db $FF   ; 00 
  db $F7   ; 01 
  db $B7   ; 02 
  db $FF   ; 03 
  db $9E   ; 04 
  db $D6   ; 05 
  db $FB   ; 06 
  db $DF   ; 07 
  db $FF   ; 08 
  db $AF   ; 09 
  db $D6   ; 0A 
  db $FE   ; 0B 
  db $BB   ; 0C 
  db $F5   ; 0D 
  db $E5   ; 0E 
  db $EF   ; 0F 



tbl_E4A2
  db $00, $80   ; 00 
  db $00, $A0   ; 01 
  db $00, $C0   ; 02 
  db $00, $E0   ; 03 
  db $01, $00   ; 04 
  db $01, $40   ; 05 
  db $01, $80   ; 06 
  db $02, $00   ; 07 



tbl_E4B2
  db $E8   ; 00 
  db $02   ; 01 
  db $00   ; 02 
  db $1C   ; 03 
  db $00   ; 04 
tbl_E4B7   ; bzk bug probably, both tables share 0x0024C8 byte
  db $18   ; 00 (05) 
  db $48   ; 01 
  db $78   ; 02 
  db $A8   ; 03 



tbl_E4BB
  db $D8   ; 00 
  db $FE   ; 01 
  db $FF   ; 02 
  db $DC   ; 03 
  db $FE   ; 04 
  db $FF   ; 05 
  db $DC   ; 06 



sub_E4C2
  JSR sub_E523
  JSR sub_E719
  STA ram_0000
  LDY #$00
bra_E4CC_loop
  LDX ram_0000
  LDA tbl_E382,X
  STA ram_0001
  AND #$E0
  BEQ bra_E502
  CMP #$61
  BCS bra_E502
  PHA
  LDA ram_0001
  AND #$07
  TAX
  PLA
  CMP #$60
  BNE bra_E4EC
  DEX
  DEX
  BPL bra_E4EC
  LDX #$06
bra_E4EC
  TXA
  ASL
  TAX
  LDA tbl_E4A2,X
  STA ram_0790_obj,Y ; 0790 0791 0792 0793 0794 0795 0796 
  LDA tbl_E4A2 + $01,X
  STA ram_07A0_obj,Y ; 07A0 07A1 07A2 07A3 07A4 07A5 07A6 
  LDA ram_0001
  AND #$10
  STA ram_07D0_obj,Y ; 07D0 07D1 07D2 07D3 07D4 07D5 07D6 
bra_E502
  LDA ram_0001
  LSR
  LSR
  LSR
  LSR
  ROR ram_0785
  INC ram_0000
  INY
  CPY #$07
  BNE bra_E4CC_loop
  LDY #$05
  STY ram_0782
bra_E517_loop
  LDY ram_0782
  JSR sub_E640
  DEC ram_0782
  BNE bra_E517_loop
  RTS



sub_E523
  LDA #$00
  LDX #$2D
bra_E527_loop
; 0790-07BD
  STA ram_range_0790_07BD,X
  DEX
  BPL bra_E527_loop
  LDX #$03
bra_E52F_loop
  STA ram_0786,X
  DEX
  BPL bra_E52F_loop
  STA ram_0785
  RTS



tbl_E539
  db $CB   ; 00 
  db $1B   ; 01 
  db $FF   ; 02 
  db $4A   ; 03 
  db $92   ; 04 
  db $1B   ; 05 
  db $A4   ; 06 
  db $FF   ; 07 
  db $0B   ; 08 
  db $50   ; 09 
  db $95   ; 0A 
  db $DA   ; 0B 
  db $E9   ; 0C 
  db $FF   ; 0D 
  db $CB   ; 0E 
  db $A1   ; 0F 
  db $65   ; 10 
  db $FF   ; 11 
  db $9B   ; 12 
  db $DE   ; 13 
  db $FF   ; 14 
  db $8B   ; 15 
  db $55   ; 16 
  db $A0   ; 17 
  db $64   ; 18 
  db $FF   ; 19 
  db $D5   ; 1A 
  db $FF   ; 1B 
  db $52   ; 1C 
  db $96   ; 1D 
  db $5A   ; 1E 
  db $E8   ; 1F 
  db $FF   ; 20 



tbl_E55A
  db $00   ; 00 
  db $03   ; 01 
  db $08   ; 02 
  db $0E   ; 03 
  db $12   ; 04 
  db $15   ; 05 
  db $1A   ; 06 
  db $1C   ; 07 



sub_E562
  JSR sub_E523
  LDA #$19
  STA ram_0024
  LDA ram_mountain_current
  AND #$07
  TAX
  LDA tbl_E55A,X
  STA ram_0025
loc_E573
  LDX ram_0025
  LDA tbl_E539,X
  PHA
  AND #$3F
  CMP ram_0024
  BEQ bra_E583
  BCC bra_E583
  PLA
  RTS
bra_E583
  INC ram_0025
  LDY #$03
bra_E587_loop
  LDA ram_0786,Y
  BEQ bra_E58F
  DEY
  BPL bra_E587_loop
bra_E58F
  PLA
  STA ram_0786,Y
  PHA
  LDX #$00
  AND #$40
  BNE bra_E59B
  DEX
bra_E59B
  TXA
  STA ram_07D0_obj + $07,Y ; 07D7 07D8 07D9 07DA 
  PLA
  PHA
  LDX #$C0
  AND #$80
  BNE bra_E5A9
  LDX #$80
bra_E5A9
  TXA
  STA ram_07A0_obj + $07,Y ; 07A7 07A8 07A9 07AA 
  LDA #$00
  STA ram_0790_obj + $07,Y ; 0797 0798 0799 079A 
  LDX #$06
  LDA ram_mountain_current
  AND #$04
  BEQ bra_E5BB
  TAX
bra_E5BB
  STX ram_0003
  PLA
  AND #$3F
  PHA
  CMP #$1E
  BMI bra_E5C8
  LDX #$00
  db $2C   ; BIT opcode
bra_E5C8
  LDX #$01
  TXA
  STA ram_06E0_bouns_stage_data + $1A,Y ; 06FA 06FB 06FC 06FD 
  PLA
  TAX
  LDA #$DE
bra_E5D2_loop
  SEC
  SBC #$08
  DEX
  BNE bra_E5D2_loop
  STA ram_0008
  STA ram_06BE,Y ; 06BE 06BF 06C0 06C1 
  CLC
  ADC #$05
  STA ram_06C2_data + $1A,Y ; 06DC 06DD 06DE 06DF 
  LDA #$E8
  STA ram_0668_data + $1A,Y ; 0682 0683 0684 0685 
  LDA #$18
  LDX ram_0003
  CPX #$04
  BNE bra_E5F2
  LDA #$08
bra_E5F2
  STA ram_0686_data + $1A,Y ; 06A0 06A1 06A2 06A3 
  LDA ram_0027_flag
  BEQ bra_E5FF
  LDA ram_0008
  CLC
  ADC #$10
  db $2C   ; BIT opcode
bra_E5FF
  LDA ram_0008
  SEC
  SBC ram_scroll_Y
  STA ram_0005
  DEC ram_0005
  LDA #$DC
  STA ram_0007
  LDA #$E8
  STA ram_0001
  LDA tbl_E273,Y
  TAY
loc_E614
  LDA #$00
  STA ram_spr_A + $A0,Y
  LDA ram_0005
  STA ram_spr_Y + $A0,Y
  JSR sub_E881
  LDA ram_0007
  STA ram_spr_T + $A0,Y
  LDA #$FF
  STA ram_0007
  DEC ram_0003
  BEQ bra_E635
  INY
  INY
  INY
  INY
  JMP loc_E614
bra_E635
  LDA #$FE
  STA ram_spr_T + $A0,Y
  JMP loc_E573



sub_E63D
  LDY ram_0090
  INY
sub_E640
  CPY #$09
  BPL bra_E64D_RTS
  CPY #$01
  BEQ bra_E64D_RTS
  JSR sub_E64E
  BCS bra_E662
bra_E64D_RTS
  RTS



sub_E64E
  JSR sub_E719
  STA ram_000C
  TYA
  CLC
  ADC ram_000C
  TAX
  LDA tbl_E382 - $02,X
  STA ram_000C
  AND #$E0
  CMP #$60
  RTS



bra_E662
  STA ram_000E
  STY ram_0000
  LDX #$05
bra_E668_loop
  LDA tbl_E4B2,X
  STA ram_0001,X
  DEX
  BPL bra_E668_loop
  LDA ram_000C
  AND #$10
  BNE bra_E678
  INC ram_0005
bra_E678
  LDA ram_000C
  AND #$07
  ASL
  TAX
  LDA tbl_E4A2,X
  STA ram_0006
  LDA tbl_E4A2 + $01,X
  STA ram_0007
  LDA ram_random + $01
  AND #$1F
  CLC
  ADC #$80
  LDX ram_000E
  CPX #$E0
  BEQ bra_E69B
  CPX #$C0
  BNE bra_E6A5
  LDA #$F0
bra_E69B
  CLC
  ADC ram_0003
  STA ram_0003
  CLC
  ADC #$1B
  STA ram_0004
bra_E6A5
  LDX #$00
  LDA ram_0786
  BEQ bra_E6AD
  INX ; 01
bra_E6AD
  LDA ram_0005
  STA ram_07D0_obj + $07,X ; 07D7 07D8 
  LDA ram_0006
  STA ram_0790_obj + $07,X ; 0797 0798 
  LDA ram_0007
  STA ram_07A0_obj + $07,X ; 07A7 07A8 
  LDY #$00
bra_E6BE_loop
  LDA ram_0000,Y ; 0000 0001 0002 0003 0004 
  STA ram_0786,X ; 0786 0787 0788 0789 078A 078B 078C 078D 078E 078F 
  INX
  INX
  INY
  CPY #$05
  BNE bra_E6BE_loop
  LDY #$00
  CPX #$0A
  BEQ bra_E6D3
  LDY #$18
bra_E6D3
  LDX #$06
  STX ram_000A
loc_E6D7
bra_E6D7_loop
  LDA #$22
  STA ram_spr_A + $A0,Y
  LDX ram_000A
  LDA tbl_E4BB,X
  CPX #$03
  BEQ bra_E6E9
  CPX #$04
  BNE bra_E6F1
bra_E6E9
  LDX ram_000E
  CPX #$E0
  BEQ bra_E6F1
  LDA #$FF
bra_E6F1
  STA ram_spr_T + $A0,Y
  JSR sub_E881
  LDA ram_0090
  SEC
  SBC ram_0000
  TAX
  INX
  LDA tbl_E4B7,X
  STA ram_spr_Y + $A0,Y
  INY
  INY
  INY
  INY
  DEC ram_000A
  BEQ bra_E726_RTS
  LDA ram_000A
  CMP #$03
  BNE bra_E6D7_loop
  LDA ram_0003
  STA ram_0001
  JMP loc_E6D7



sub_E719
  LDA ram_mountain_current
  AND #$1F
  TAX
  LDA #$F9
bra_E720_loop
  CLC
  ADC #$07
  DEX
  BPL bra_E720_loop
bra_E726_RTS
  RTS



tbl_E727
  db $D3   ; 00 
  db $8C   ; 08 
  db $CD   ; 10 
  db $8F   ; 18 



sub_E72B
  LDA ram_mountain_current
  TAX
  AND #$0F
  TAY
  LDA tbl_E492,Y
  STA ram_0000
  LDA tbl_E482,Y
  STA ram_0001
  LDA tbl_E472,Y
  STA ram_0002
  LDA tbl_E462,Y
  STA ram_0003
  LDY #$07
bra_E747_loop
  LDA #$00
  LDX #$03
bra_E74B_loop
  LSR ram_0000,X
  ROL
  DEX
  BPL bra_E74B_loop
  PHA
  INY
  JSR sub_E64E
  DEY
  CMP #$A0
  PLA
  BCC bra_E75E
  LDA #$00
bra_E75E
  STA ram_0004,Y
  LDA ram_000C
  TAX
  AND #$E0
  CMP #$A0
  BCS bra_E77C
  AND #$70
  BEQ bra_E779
  TXA
  LSR
  LSR
  LSR
  AND #$03
  TAX
  LDA tbl_E727,X
  db $2C   ; BIT opcode
bra_E779
  LDA #$00
  db $2C   ; BIT opcode
bra_E77C
  LDA #$01
  STA ram_0600_data + $30,Y
  DEY
  BNE bra_E747_loop
  LDA #$01
  STA ram_0004
  LSR ; 00
  STA ram_0600_data + $30,Y
  RTS



tbl_E78D
  db $21   ; 00 
  db $4E   ; 01 
  db $20   ; 02 
  db $4D   ; 03 



tbl_E791
  db $42   ; 01 
  db $42   ; 02 
  db $42   ; 03 
  db $42   ; 04 
  db $42   ; 05 
  db $48   ; 06 
  db $4E   ; 07 
  db $9D   ; 08 
  db $9D   ; 09 
  db $9D   ; 0A 
  db $9D   ; 0B 
  db $9D   ; 0C 



sub_E79D
  LDA #$08
  STA ram_000F
loc_E7A1
  LDY ram_000F
  CPY #$01
  BEQ bra_E7B2
  JSR sub_E64E
  CMP #$81
  BCC bra_E7B2
  LDA #$01
  BNE bra_E7B8    ; jmp
bra_E7B2
  LDA #$A4
  STA ram_0004
  LDA #$00
bra_E7B8
  STA ram_000D
  LDX ram_000F
  LDA tbl_D78B_ppu_hi,X
  STA ram_0001
  LDA tbl_D794_ppu_lo,X
  STA ram_0000
  LDY #$00
  STY ram_0668_data + $04
bra_E7CB
  LDA #$86
  STA ram_0600_data + $02,Y
  LDA ram_0000
  STA ram_0600_data + $01,Y
  LDA ram_0001
  STA ram_0600_data,Y
  INC ram_0000
  LDX ram_000D
  BEQ bra_E7E7
  LDA tbl_E791 - $01,X
  STA ram_0004
  INC ram_000D
bra_E7E7
  LDX #$06
  INY
  INY
  INY
  CPY #$30
  BNE bra_E7F7
  LDA ram_0000
  CLC
  ADC #$14
  STA ram_0000
bra_E7F7
bra_E7F7_loop
  LDA ram_0004
  STA ram_0600_data,Y
  INC ram_0004
  INY
  CPY #$6C
  BEQ bra_E80D
  DEX
  BNE bra_E7F7_loop
  LDA #$EB
  STA ram_0600_data - $01,Y
  BNE bra_E7CB    ; jmp
bra_E80D
  LDA ram_000F
  ASL
  CLC
  ADC #$EA
  LDY #$03
bra_E815_loop
  CPY #$01
  BNE bra_E81C
  CLC
  ADC #$01
bra_E81C
  LDX tbl_E78D,Y
  STA ram_0600_data,X
  DEY
  BPL bra_E815_loop
  LDA ram_000F
  CMP #$06
  BPL bra_E875
  LDY #$08
  CMP #$03
  BPL bra_E833
  LDY #$10
bra_E833
  STY ram_000A
  LDX #$05
bra_E837_loop
  LDY ram_000A
  LDA #$38
  STA ram_0006
  STA ram_0007
  STA ram_0008
  STA ram_0009
bra_E843_loop
  ROR ram_0006
  ROR ram_0007
  ROR ram_0600_data + $39,X
  ROR ram_0600_data + $42,X
  ROR ram_0600_data + $4B,X
  ROR ram_0600_data + $54,X
  ROR ram_0600_data + $5D,X
  ROR ram_0600_data + $66,X
  ROL ram_0008
  ROL ram_0009
  ROL ram_0600_data + $30,X
  ROL ram_0600_data + $27,X
  ROL ram_0600_data + $1E,X
  ROL ram_0600_data + $15,X
  ROL ram_0600_data + $0C,X
  ROL ram_0600_data + $03,X
  DEY
  BNE bra_E843_loop
  DEX
  BPL bra_E837_loop
bra_E875
  LDX #$09
  JSR sub_C150
  DEC ram_000F
  BEQ bra_E88B_RTS
  JMP loc_E7A1



sub_E881
  LDA ram_0001
  STA ram_spr_X + $A0,Y
  CLC
  ADC #$08
  STA ram_0001
bra_E88B_RTS
  RTS


; bzk garbage?
  db $FF   ; 



tbl_E88D
  db $00   ; 00 
  db $05   ; 01 



sub_E88F
  LDX #$01
bra_E891_loop
  LDA ram_0022_plr,X
  BNE bra_E8AB
  LDA ram_plr_lives,X
  BMI bra_E8AB
  LDY tbl_E88D,X
  LDA ram_plr_counter_fruits,Y
  BEQ bra_E8AB
  LDA ram_mountain_completed
  CMP #$04
  BNE bra_E8AB
  STA ram_0022_plr,X
  INC ram_plr_lives,X
bra_E8AB
  DEX
  BPL bra_E891_loop
  RTS



tbl_E8AF
  db $21   ; 01 
  db $67   ; 02 
  db $07   ; 03 
  db $38   ; 04 
  db $38   ; 05 
  db $00   ; 06 
  db $00   ; 07 
  db $5C   ; 08 
  db $38   ; 09 
  db $00   ; 0A 
  db $21   ; 0B 
  db $75   ; 0C 
  db $07   ; 0D 
  db $38   ; 0E 
  db $38   ; 0F 
  db $00   ; 10 
  db $00   ; 11 
  db $5C   ; 12 
  db $38   ; 13 
  db $00   ; 14 
  db $00   ; 15 



tbl_E8C4
  db $24   ; 01 
  db $27   ; 02 
  db $24   ; 03 
  db $27   ; 04 



tbl_E8C8
  db $60   ; 01 
  db $6E   ; 02 
  db $81   ; 03 
  db $97   ; 04 



tbl_E8CC
  db $52   ; 01 
  db $AC   ; 02 
  db $E0   ; 03 
  db $0A   ; 04 



tbl_E8D0
  db $13   ; 01 
  db $08   ; 02 
  db $15   ; 03 
  db $1B   ; 04 



tbl_E8D4
  db $01   ; 00 
  db $00   ; 01 
tbl_E8D6
  db $28   ; 00 (02) 
  db $50   ; 01 (03) 
  db $04   ; 02 (04) 
tbl_E8D9
  db $08   ; 00 (03) 
  db $00   ; 01 
  db $00   ; 02 
  db $00   ; 03 
  db $00   ; 04 



tbl_E8DE
  db $03   ; 00 
  db $05   ; 01 
  db $06   ; 02 
  db $07   ; 03 
  db $08   ; 04 
  db $0A   ; 05 
  db $14   ; 06 
  db $1E   ; 07 
  db $28   ; 08 
  db $32   ; 09 



tbl_E8E8
  db $1E   ; 00 
  db $32   ; 01 
  db $3C   ; 02 
  db $46   ; 03 
  db $50   ; 04 
  db $01   ; 05 
  db $02   ; 06 
  db $03   ; 07 
  db $04   ; 08 
  db $05   ; 09 



loc_E8F2
  LDA ram_0034_timer
  BNE bra_E903
  LDY ram_03A3
  BEQ bra_E900
  LDA ram_frm_cnt
  LSR
  BCC bra_E91A
bra_E900
  JMP loc_E9CE
bra_E903
  LDY ram_03A3
  BEQ bra_E90C
  CMP #$31
  BEQ bra_E90F
bra_E90C
  JMP loc_EA35
bra_E90F
  LDX #$09
bra_E911_loop
  LDA ram_plr_counters,X
  STA ram_038F,X
  DEX
  BPL bra_E911_loop
bra_E91A
  LDX #$15
bra_E91C_loop
  LDA tbl_E8AF - $01,X
  STA ram_ppu_buffer - $01,X
  DEX
  BNE bra_E91C_loop
bra_E925_loop
  LDY ram_03A3
bra_E928_loop
  BEQ bra_E947
  LDA ram_ppu_buffer + $01,X
  CLC
  ADC #< $0040
  STA ram_ppu_buffer + $01,X
  LDA ram_ppu_buffer,X
  ADC #> $0040
  STA ram_ppu_buffer,X
  DEY
  BNE bra_E928_loop
  TXA
  CLC
  ADC #$0A
  TAX
  CPX #$0B
  BCC bra_E925_loop
bra_E947
  LDY ram_03A3
  LDX #$00
bra_E94C_loop
  TYA
  PHA
  LDA ram_0399,Y
  JSR sub_EA4A_get_tens
  STA ram_ppu_buffer + $09,X
  TYA
  STA ram_ppu_buffer + $08,X
  JSR sub_EA5C
  PLA
  TAY
  LDA ram_0399,Y
  CMP ram_038F,Y
  BEQ bra_E974
  CMP #$63
  BCS bra_E974    ; if overflow
  LDA ram_0399,Y
  ADC #$01
  STA ram_0399,Y
bra_E974
  INY
  INY
  INY
  INY
  INY
  TXA
  CLC
  ADC #$0A
  TAX
  CPX #$0B
  BCC bra_E94C_loop
  LDX ram_game_mode
  BNE bra_E989    ; if 2p
; if 1p
; X = 00
  STX ram_ppu_buffer + $0A
bra_E989
  LDY ram_03A3
  DEY
  BNE bra_E999
  LDA ram_plr_lives
  CMP #$80
  BNE bra_E999
  STY ram_ppu_buffer
  RTS
bra_E999
bra_E999_loop
  TXA
  STX ram_0006
  PHA
  LDX ram_03A3
  LDA tbl_E8CC - $01,X
  CPX #$01
  BNE bra_E9AA
  LDA ram_05FE
bra_E9AA
  STA ram_0002
  LDA tbl_E8C8 - $01,X
  STA ram_0001
  STA ram_000E
  LDA tbl_E8D0 - $01,X
  CLC
  ADC ram_0006
  TAY
  LDA tbl_E8C4 - $01,X
  LDX ram_0006
  BEQ bra_E9C3
  ADC #$70
bra_E9C3
  STA ram_0000
  JSR sub_EAFC
  PLA
  TAX
  DEX
  BPL bra_E999_loop
  RTS



loc_E9CE
  LDA ram_plr_counter_stage_bonus,Y
  ORA ram_plr_counter_stage_bonus + $05,Y
  BEQ bra_EA3A
  LDA ram_game_mode
  STA ram_000E
  TYA
bra_E9DB_loop
  TAX
  PHA
  LDA ram_plr_counter_stage_bonus,X
  BEQ bra_EA26
  DEC ram_plr_counter_stage_bonus,X
  LDA tbl_E8D9,Y
  CPY #$01
  BNE bra_E9F5
  JSR sub_EA8E
  CPY #$05
  BCC bra_E9F5
  LDA #$08
bra_E9F5
  CPX #$05
  ADC #$00
  STA ram_0001
  LDY ram_03A3
  LDA tbl_E8D4,Y
  LDX ram_03A3
  CPX #$04
  BEQ bra_EA14
  CPX #$01
  BNE bra_EA17
  JSR sub_EA8E
  LDA tbl_E8E8,Y
  BNE bra_EA17
bra_EA14
  JSR sub_EA97_check_mountain_limit
bra_EA17
  JSR sub_EA4A_get_tens
  STA ram_0000
  TYA
  ASL
  ASL
  ASL
  ASL
  ADC ram_0000
  JSR sub_C94E
bra_EA26
  LDY ram_03A3
  PLA
  CLC
  ADC #$05
  DEC ram_000E
  BPL bra_E9DB_loop
  LDA #con_sfx_2_08
  STA ram_sfx_2
loc_EA35
  LDA ram_game_mode
  JMP loc_C8E0
bra_EA3A
  CPY #$04
  BCC bra_EA42
  LDX #$10
  STX ram_0045_timer
bra_EA42
  INC ram_03A3
  LDA #$40
  STA ram_0034_timer
bra_EA49_RTS
  RTS



sub_EA4A_get_tens
; in
;    ; A = hex number
; out
;    ; Y = decimal tens
  LDY #$00
bra_EA4C_loop
  CMP #$0A
  BCC bra_EA49_RTS
  SBC #$0A
  INY
  BNE bra_EA4C_loop    ; jmp



sub_EA55
  JSR sub_EA8E
  LDA tbl_E8DE,Y
  RTS



sub_EA5C
  LDY ram_03A3
  CPY #$01
  BEQ bra_EA6E
  CPY #$04
  BEQ bra_EA7E
; if Y = 02 or 03
  LDA tbl_E8D6,Y
  STA ram_ppu_buffer + $04,X
  RTS
bra_EA6E
  JSR sub_EA55
  JSR sub_EA4A_get_tens
  STA ram_ppu_buffer + $04,X
  TYA
  BEQ bra_EA7D_RTS
  STA ram_ppu_buffer + $03,X
bra_EA7D_RTS
  RTS
bra_EA7E
  JSR sub_EA97_check_mountain_limit
  JSR sub_EA4A_get_tens
  STA ram_ppu_buffer + $05,X
  TYA
  BEQ bra_EA8D_RTS
  STA ram_ppu_buffer + $04,X
bra_EA8D_RTS
  RTS



sub_EA8E
  LDY ram_mountain_completed
  CPY #$0A
  BCC bra_EA96_RTS
  LDY #$09
bra_EA96_RTS
  RTS



sub_EA97_check_mountain_limit
  LDY ram_mountain_current
  INY
  TYA
  CMP #$21
  BCC bra_EAA1_RTS    ; if not overflow
; make mountain 0
  SBC #$20
bra_EAA1_RTS
  RTS



tbl_EAA2_oam_lo
  db < (ram_spr_Y + $00)   ; 01 
  db < (ram_spr_Y + $24)   ; 02 
  db < (ram_spr_Y + $60)   ; 03 
  db < (ram_spr_Y + $40)   ; 04 
  db < (ram_spr_Y + $70)   ; 05 
  db < (ram_spr_Y + $88)   ; 06 
  db < (ram_spr_Y + $A0)   ; 07 
  db < (ram_spr_Y + $80)   ; 08 
  db < (ram_spr_Y + $98)   ; 09 
  db < (ram_spr_Y + $B0)   ; 0A 
  db < (ram_spr_Y + $1C)   ; 0B 
  db < (ram_spr_Y + $20)   ; 0C 
  db < (ram_spr_Y + $E0)   ; 0D 
  db < (ram_spr_Y + $40)   ; 0E 
  db < (ram_spr_Y + $60)   ; 0F 
  db < (ram_spr_Y + $70)   ; 10 
  db < (ram_spr_Y + $80)   ; 11 
  db < (ram_spr_Y + $90)   ; 12 
  db < (ram_spr_Y + $A0)   ; 13 
  db < (ram_spr_Y + $B0)   ; 14 
  db < (ram_spr_Y + $5C)   ; 15 
  db < (ram_spr_Y + $6C)   ; 16 
  db < (ram_spr_Y + $7C)   ; 17 
  db < (ram_spr_Y + $40)   ; 18 
  db < (ram_spr_Y + $48)   ; 19 
  db < (ram_spr_Y + $50)   ; 1A 
  db < (ram_spr_Y + $1C)   ; 1B 
  db < (ram_spr_Y + $20)   ; 1C 
  db < (ram_spr_Y + $00)   ; 1D 
  db < (ram_spr_Y + $20)   ; 1E 



tbl_EAC0_attributes
  db $00   ; 01 
  db $55   ; 02 
  db $55   ; 03 
  db $55   ; 04 
  db $00   ; 05 
  db $00   ; 06 
  db $00   ; 07 
  db $AA   ; 08 
  db $AA   ; 09 
  db $AA   ; 0A 
  db $00   ; 0B 
  db $55   ; 0C 
  db $FF   ; 0D 
  db $AA   ; 0E 
  db $FF   ; 0F 
  db $FF   ; 10 
  db $FF   ; 11 
  db $FF   ; 12 
  db $FF   ; 13 
  db $FF   ; 14 
  db $55   ; 15 
  db $55   ; 16 
  db $55   ; 17 
  db $AA   ; 18 
  db $AA   ; 19 
  db $AA   ; 1A 
  db $AA   ; 1B 
  db $AA   ; 1C 
  db $00   ; 1D 
  db $55   ; 1E 



tbl_EADE
  db $32   ; 01 
  db $32   ; 02 
  db $22   ; 03 
  db $42   ; 04 
  db $22   ; 05 
  db $22   ; 06 
  db $22   ; 07 
  db $21   ; 08 
  db $21   ; 09 
  db $21   ; 0A 
  db $11   ; 0B 
  db $11   ; 0C 
  db $22   ; 0D 
  db $24   ; 0E 
  db $22   ; 0F 
  db $22   ; 10 
  db $22   ; 11 
  db $22   ; 12 
  db $22   ; 13 
  db $22   ; 14 
  db $22   ; 15 
  db $22   ; 16 
  db $22   ; 17 
  db $21   ; 18 
  db $21   ; 19 
  db $21   ; 1A 
  db $11   ; 1B 
  db $11   ; 1C 
  db $24   ; 1D 
  db $24   ; 1E 



sub_EAFC
loc_EAFC
  STY ram_0009
  LDA tbl_EAA2_oam_lo - $01,Y
  STA ram_0004
  LDA tbl_EAC0_attributes - $01,Y
  STA ram_000A
  STA ram_000B
  STA ram_000C
  STA ram_000D
  LDA tbl_EADE - $01,Y
  JMP loc_C73D



tbl_EB14
  db $06   ; 01 
  db $06   ; 02 
  db $04   ; 03 
  db $08   ; 04 
  db $04   ; 05 
  db $04   ; 06 
  db $04   ; 07 
  db $02   ; 08 
  db $02   ; 09 
  db $02   ; 0A 
  db $01   ; 0B 
  db $01   ; 0C 
  db $04   ; 0D 
  db $06   ; 0E 
  db $04   ; 0F 
  db $04   ; 10 
  db $04   ; 11 
  db $04   ; 12 
  db $04   ; 13 
  db $04   ; 14 
  db $04   ; 15 
  db $04   ; 16 
  db $04   ; 17 
  db $02   ; 18 
  db $02   ; 19 
  db $02   ; 1A 



sub_EB2E
  LDX #$0A
bra_EB30_loop
  LDA ram_03E8_obj,X ; 03E8 03E9 03EA 03EB 03EC 03ED 03EE 03EF 03F0 03F1 03F2 
  BEQ bra_EB68
  PHA
  AND #$1F
  BEQ bra_EB62
  TAY
  PLA
  BMI bra_EB6C
  AND #$40
  STA ram_000E
  LDA ram_009C_obj_pos_X,X ; 009C 009D 009E 009F 00A0 00A1 00A2 00A4 00A5 00A6 
  STA ram_0000
  LDA ram_00A7_obj_pos_Y,X ; 00A7 00A8 00A9 00AA 00AB 00AC 00AD 00AF 00B0 00B1 
  STA ram_0001
  LDA ram_03DD_obj,X ; 03DD 03DE 03DF 03E0 03E1 03E2 03E3 03E5 03E6 03E7 
  STA ram_0002
  LDA ram_00BD_obj,X ; 00BD 00BE 00BF 00C0 00C1 00C2 00C3 00C5 00C6 00C7 
  BPL bra_EB56
  LDA #$00
  db $2C   ; BIT opcode
bra_EB56
  LDA #$01
  STA ram_000F
  TXA
  PHA
  JSR sub_EAFC
loc_EB5F
  PLA
  TAX
  db $24   ; BIT opcode
bra_EB62
  PLA
  LDA #$00
  STA ram_03E8_obj,X ; 03E8 03E9 03EA 03EB 03EC 03ED 03EE 03F0 03F1 03F2 
bra_EB68
  DEX
  BPL bra_EB30_loop
bra_EB6B_RTS
  RTS
bra_EB6C
; triggers when a seal puts ice to cover a hole
  LDA #$00
  STA ram_0091_obj,X ; 0091 0092 0093 0094 0095 0096 0097 0099 009A 
  TXA
  PHA
  LDA tbl_EB14 - $01,Y
  TAX
  LDA tbl_EAA2_oam_lo - $01,Y
  JSR sub_C821_hide_sprites_starting_from_A
  JMP loc_EB5F



sub_EB7F
  LDX #$00
  JSR sub_EB8A
  LDA ram_game_mode
  BEQ bra_EB6B_RTS    ; if 1p
; if 2p
  LDX #$01
sub_EB8A
  LDA ram_005A_plr,X
  BNE bra_EB6B_RTS
  LDA ram_plr_lives,X
  BMI bra_EB6B_RTS
  TXA
  PHA
  ASL
  ASL
  TAY
  LDA #$F8
  STA ram_spr_Y + $1C,Y
  LDA tbl_EAA2_oam_lo,X
  LDX #$06
  JSR sub_C821_hide_sprites_starting_from_A
  PLA
  TAX
  LDA ram_003F_plr_timer,X
  BNE bra_EB6B_RTS
  JSR sub_CFEB
  STA ram_00E0_plr,X
  STA ram_0080_plr,X
  STA ram_0086_plr,X
  LDA #$00
  STA ram_002F_plr,X
  LDA ram_0090
  SEC
  SBC #$03
  STA ram_0000
  LDA ram_0382_obj,X
  CMP ram_0090
  BCS bra_EBCE
  CMP ram_0000
  BCS bra_EBD3
  LDA ram_0000
  JMP loc_EBD3
bra_EBCE
  LDA ram_0000
  CLC
  ADC #$02
loc_EBD3
bra_EBD3
bra_EBD3_loop
  CMP ram_0786
  BEQ bra_EBDD
  CMP ram_0787
  BNE bra_EBE9
bra_EBDD
  SEC
  SBC #$01
  CMP ram_0000
  BCS bra_EBD3_loop
  ADC #$03
  JMP loc_EBD3
bra_EBE9
  STA ram_005A_plr,X
  JSR sub_EDD5
  SEC
  SBC #$08
  STA ram_plr_pos_Y,X
  LDA ram_005A_plr,X
  STA ram_000F
  LDA ram_plr_pos_X,X
  CLC
  ADC #$08
  STA ram_000E
bra_EBFE_loop
  JSR sub_DEB9
  BMI bra_EC07
  CMP #$03
  BNE bra_EC12
bra_EC07
  LDA ram_000E
  CLC
  ADC #$08
  STA ram_000E
  CMP #$E0
  BCC bra_EBFE_loop
bra_EC12
  LDA ram_000E
  SEC
  SBC #$08
  STA ram_plr_pos_X,X
  LDA #$01
  STA ram_002D_plr,X
  JSR sub_D0B8
  JMP loc_D8FD_reset_bear_spawn_timer



sub_EC23
  LDX #$00
  JSR sub_EC2A
  LDX #$01
sub_EC2A
  LDA ram_002D_plr,X
  BEQ bra_EC50_RTS
  LDA ram_plr_lives,X
  BMI bra_EC50_RTS
  TXA
  ASL
  TAY
  LDA ram_btn_hold,Y
  ORA ram_0070_plr,X
  AND #con_btns_SS ^ $FF
  BEQ bra_EC42
  LDA #$00
  STA ram_002D_plr,X
bra_EC42
  LDA ram_frm_cnt
  AND #$01
  BEQ bra_EC50_RTS
  LDA tbl_EAA2_oam_lo,X
  LDX #$06
  JMP loc_C821_hide_sprites_starting_from_A
bra_EC50_RTS
  RTS



sub_EC51
  LDX #$07
bra_EC53_loop
  LDA ram_0091_obj,X ; 0091 0092 0093 0094 0095 0096 0097 0098 
  BEQ bra_EC74
  LDA ram_00A7_obj_pos_Y,X
  CPX #$00
  BNE bra_EC63
  CMP #$F0
  BCC bra_EC63
  LDA #$EC
bra_EC63
  CLC
  ADC #$04
  STA ram_00A7_obj_pos_Y,X
  CPX #$00
  BEQ bra_EC74
  CMP #$F8
  BCC bra_EC74
  LDA #$00
  STA ram_0091_obj,X ; 0093 0094 0095 0096 0097 
bra_EC74
  CPX #$02
  BCS bra_EC82
  LDA ram_005A_plr,X
  BEQ bra_EC82
  LDA ram_plr_pos_Y,X
  ADC #$04
  STA ram_plr_pos_Y,X
bra_EC82
  CPX #$03
  BCS bra_EC92
  LDA ram_00A7_obj_pos_Y + $08,X ; 00AF 00B0 00B1 
  BEQ bra_EC92
  CMP #$F0
  BCS bra_EC92
  ADC #$04
  STA ram_00A7_obj_pos_Y + $08,X ; 00AF 00B0 
bra_EC92
  DEX
  BPL bra_EC53_loop
  LDX #$E4
  LDA ram_0055
  CMP #$02
  BNE bra_EC9F
  LDX #$FC
bra_EC9F
bra_EC9F_loop
  LDA ram_spr_Y,X
  CMP #$F2
  BCC bra_ECA8
  LDA #$F4
bra_ECA8
  CLC
  ADC #$04
  STA ram_spr_Y,X
  DEX
  DEX
  DEX
  DEX
  CPX #$FC
  BNE bra_EC9F_loop
  RTS



tbl_ECB7
; 00 
  db $20   ; 00 
  db $F0   ; 01 
  db $30   ; 02 
  db $1D   ; 03 
; 01 
  db $C0   ; 00 
  db $F0   ; 01 
  db $30   ; 02 
  db $1E   ; 03 



sub_ECBF
  LDX ram_game_mode
bra_ECC1_loop
  LDA ram_plr_lives,X
  BMI bra_ECC7
  LDA #$FB
bra_ECC7
  EOR #$FF
  JSR sub_ECF0
  DEX
  BPL bra_ECC1_loop
  LDA #$FC
  CMP ram_plr_lives
  BNE bra_ED08_RTS
  LDY ram_game_mode
  BEQ bra_ECDD    ; if 1p
; if 2p
  CMP ram_plr_lives + $01
  BNE bra_ED08_RTS
bra_ECDD
  LDY ram_0043_timer
  BEQ bra_ED08_RTS
  DEY
  BNE bra_ED08_RTS
  LDA #$80
  STA ram_plr_lives
  ASL ; 00
  STA ram_001E
  LDA #$04
  JMP loc_D4F5



sub_ECF0
  JSR sub_C728_jump_to_pointers_after_jsr
  dw ofs_003_ED10_00
  dw ofs_003_ECFD_01
  dw ofs_003_ED09_02
  dw ofs_003_ED08_03_RTS
  dw ofs_003_ED70_04



ofs_003_ECFD_01
  JSR sub_ED51
  BCS bra_ED08_RTS
  LDA #$10
  STA ram_0043_timer
  DEC ram_plr_lives,X
bra_ED08_RTS
ofs_003_ED08_03_RTS
  RTS



ofs_003_ED09_02
  LDY ram_0043_timer
  DEY
  BNE bra_ED08_RTS
  BEQ bra_ED14    ; jmp
ofs_003_ED10_00
  LDA #con_sfx_1_plr_game_over
  STA ram_sfx_1
bra_ED14
  DEC ram_plr_lives,X
  JSR sub_ED63_TXA_ASL_ASL_TAY
bra_ED19_loop
  LDA tbl_ECB7,Y
  STA ram_0358,Y
  INY
  TYA
  AND #$03
  BNE bra_ED19_loop
sub_ED25
  TXA
  PHA
  JSR sub_ED63_TXA_ASL_ASL_TAY
  LDX #$00
bra_ED2C_loop
  LDA ram_0358,Y
  STA ram_0000,X
  INY
  INX
  CPX #$04
  BNE bra_ED2C_loop
  LDY #$01
  STY ram_000E
  DEY
  STY ram_000F
  LDY ram_0003
  JSR sub_EAFC
  LDY #$00
  PLA
  TAX
  BEQ bra_ED4B
  LDY #$20
bra_ED4B
  LDA #$35
  STA ram_spr_T + $18,Y
  RTS



sub_ED51
  JSR sub_ED25
  JSR sub_ED63_TXA_ASL_ASL_TAY
  LDA ram_0358 + $01,Y ; 0359 035D 
  SEC
  SBC #$02
  STA ram_0358 + $01,Y ; 0359 035D 
  CMP #$30
  RTS



sub_ED63_TXA_ASL_ASL_TAY
  TXA
  ASL
  ASL
  TAY
  RTS



tbl_ED68_oam_lo
  db < (ram_spr_Y + $E8)   ; 00 
  db < (ram_spr_Y + $F4)   ; 01 



tbl_ED6A
  db $00   ; 00 
  db $01   ; 01 



tbl_ED6C
  db $38   ; 00 
  db $B0   ; 01 



tbl_ED6E
  db $00   ; 00 
  db $0C   ; 01 



ofs_003_ED70_04
  LDA ram_0055
  CMP #$02
  BEQ bra_EDBE_RTS
  TXA
  PHA
  LDA tbl_ED68_oam_lo,X
  LDX #$03
  JSR sub_C821_hide_sprites_starting_from_A
  PLA
  PHA
  TAX
  LDY ram_plr_lives,X
  DEY
  BMI bra_EDBC
  CPY #$03
  BCC bra_ED8E_not_overflow
  LDY #$02
bra_ED8E_not_overflow
  LDA tbl_ED6A,X
  STA ram_0002
  LDA tbl_ED6C,X
  STA ram_0003
  LDA tbl_ED6E,X
  TAX
bra_ED9C_loop
  LDA #$21
  STA ram_spr_Y + $E8,X
  LDA #$36
  STA ram_spr_T + $E8,X
  LDA ram_0002
  STA ram_spr_A + $E8,X
  LDA ram_0003
  STA ram_spr_X + $E8,X
  INX
  INX
  INX
  INX
  CLC
  ADC #$08
  STA ram_0003
  DEY
  BPL bra_ED9C_loop
bra_EDBC
  PLA
  TAX
bra_EDBE_RTS
  RTS



sub_EDBF
  PHA
  AND #$80
  LSR
  LSR
  LSR
  STA ram_0000
  PLA
  AND #$78
  LSR
  LSR
  LSR
  ADC ram_0000
  RTS


; bzk garbage
  LDA ram_005A_plr
  db $2C   ; BIT opcode
  LDA ram_005A_plr + $01



sub_EDD5
  STA ram_0000
  LDA ram_0090
  SEC
  SBC ram_0000
  TAY
  LDA #$08
bra_EDDF_loop
  CLC
  ADC #$30
  DEY
  BPL bra_EDDF_loop
  RTS



tbl_EDE6_offset
  db $00   ; 01 
  db $05   ; 02 
  db $05   ; 03 
  db $05   ; 04 
  db $0A   ; 05 
  db $0A   ; 06 
  db $0A   ; 07 



tbl_EDED_pos_Y
  db $68   ; 
  db $98   ; 
  db $C8   ; 
  db $F0   ; 



tbl_EDF1
; 00 
  db $18   ; 00 
  db $20   ; 01 
  db $28   ; 02 
  db $20   ; 03 
  db $FF   ; 04 
; 05 
  db $A0   ; 00 
  db $A4   ; 01 
  db $A8   ; 02 
  db $A4   ; 03 
  db $FF   ; 04 
; 0A 
  db $AC   ; 00 
  db $FF   ; 01 



tbl_EDFD
  db $12   ; 00 
  db $14   ; 01 
  db $FF   ; 02 



tbl_EE00_pos_Y
  db $FE   ; 00 
  db $00   ; 01 
  db $FF   ; 02 
  db $00   ; 03 
  db $FF   ; 04 
  db $00   ; 05 
  db $00   ; 06 
  db $00   ; 07 
  db $01   ; 08 
  db $00   ; 09 
  db $01   ; 0A 
  db $00   ; 0B 
  db $02   ; 0C 



sub_EE0D
  LDX #$07
bra_EE0F_loop
  CPX #$00
  BEQ bra_EE54
  LDA ram_03E8_obj,X ; 03E9 03EA 03EB 03EC 03ED 03EE 03EF 
  BMI bra_EE54
  LDA ram_0091_obj,X ; 0092 0093 0094 0095 0096 0097 0098 
  BEQ bra_EE54
  BPL bra_EE58
  JSR sub_EF70
  BCC bra_EE26
  JSR sub_EF7B
bra_EE26
  JSR sub_EF56
  CPX #$01
  BNE bra_EE31
  LDA ram_spawn_timer_lo_bear
  BEQ bra_EE38
bra_EE31
  LDA ram_009C_obj_pos_X,X
  BNE bra_EE38
  JMP loc_EEBD
bra_EE38
  JSR sub_EF8E
  CMP #$FF
  BNE bra_EE44
  LDA #$00
  STA ram_03B1_obj,X
bra_EE44
  JSR sub_EF8E
  STA ram_03DD_obj,X
bra_EE4A
loc_EE4A
  TXA
  CLC
  ADC #$03
  ORA ram_03E8_obj,X
  STA ram_03E8_obj,X
bra_EE54
  DEX
  BPL bra_EE0F_loop
  RTS
bra_EE58
  CPX #$01
  BEQ bra_EEA7
  CMP #$01
  BNE bra_EEC5
  CPX #$05
  BCS bra_EEAA
  LDA #$00
  STA ram_0382_obj,X
  INC ram_03D2_obj,X
  LDA ram_03D2_obj,X
  AND #$07
  BNE bra_EE82
  JSR sub_EF4E
  TAY
  LDA ram_03D2_obj,X
  AND #$0F
  BNE bra_EE82
  TYA
  STA ram_03B1_obj,X
bra_EE82
  JSR sub_EF70
  BCC bra_EE8D
  LDA ram_03B1_obj,X
  JSR sub_EF7D
bra_EE8D
  LDA ram_009C_obj_pos_X,X
  BEQ bra_EEBD
  JSR sub_EF42
  BPL bra_EE9D
  INC ram_0091_obj,X ; 0093 0094 
  LDA #$00
  STA ram_03B1_obj,X ; 03B3 03B4 
bra_EE9D
loc_EE9D
  LDA #$06
  STA ram_03DD_obj,X ; 03DF 03E0 
loc_EEA2
  JSR sub_EF6A
  BNE bra_EE4A
bra_EEA7
  JMP loc_EF06
bra_EEAA
  LDA #$10
  STA ram_03BC_obj,X ; 03C1 03C2 
  JSR sub_EF56
  LDY ram_03B1_obj,X ; 03B6 03B7 
  LDA tbl_EDFD,Y
  STA ram_03DD_obj,X ; 03E2 03E3 
  BPL bra_EEC2
bra_EEBD
loc_EEBD
  LDA #$80
  STA ram_03E8_obj,X ; 03E9 03EA 03EB 03ED 03EE 
bra_EEC2
  JMP loc_EE4A
bra_EEC5
  CMP #$02
  BNE bra_EEC2
  INC ram_00A7_obj_pos_Y,X
  JSR sub_EF70
  BCC bra_EF03
  JSR sub_EF6A
  INC ram_00A7_obj_pos_Y,X
  LDA ram_0090
  SEC
  SBC ram_00B2_obj,X ; 00B4 00B5 
  STA ram_0005
  TAY
  LDA tbl_EDED_pos_Y,Y
  CMP ram_00A7_obj_pos_Y,X ; 00A9 00AA 
  BCS bra_EF03
  STA ram_00A7_obj_pos_Y,X ; 00A9 00AA 
  LDA ram_0005
  CMP #$03
  BCS bra_EEBD
  DEC ram_00B2_obj,X ; 00B4 00B5 
  JSR sub_EF42
  BMI bra_EF03
  LDA #$01
  STA ram_0091_obj,X ; 0093 0094 
  LSR ; 00
  STA ram_03B1_obj,X ; 03B3 03B4 
  LDA #$FF
  STA ram_03D2_obj,X ; 03D4 03D5 
  JSR sub_EF6A
bra_EF03
  JMP loc_EE9D
loc_EF06
  CMP #$04
  BEQ bra_EEC2
  CMP #$05
  BNE bra_EEC2
  JSR sub_EF70
  BCC bra_EF19
  JSR sub_EF6A
  JSR sub_EF7B
bra_EF19
  LDA ram_009C_obj_pos_X,X ; 009D 
  BEQ bra_EEBD
  JSR sub_EF83
  BCC bra_EF3A
  LDA ram_03B1_obj,X
  TAY
  LDA tbl_EE00_pos_Y,Y
  CLC
  ADC ram_00A7_obj_pos_Y,X ; 00A8 
  STA ram_00A7_obj_pos_Y,X ; 00A8 
  INC ram_03B1_obj,X ; 03B2 
  CPY #$0C
  BNE bra_EF3A
  LDA #$00
  STA ram_03B1_obj,X ; 03B2 
bra_EF3A
  LDA #$98
  STA ram_03DD_obj,X ; 03DE 
  JMP loc_EEA2



sub_EF42
  LDA ram_009C_obj_pos_X,X ; 009E 009F 
  CLC
  ADC #$08
sub_EF47
  STA ram_000E
  STX ram_000F
  JMP loc_DEB2



sub_EF4E
  LDA ram_00BD_obj,X
  JSR sub_D2FB_EOR
  STA ram_00BD_obj,X
  RTS



sub_EF56
  LDA ram_03D2_obj,X
  CMP #$FF
  BNE bra_EF62
  INC ram_03D2_obj,X
  BEQ bra_EF6A
bra_EF62
  JSR sub_EF83
  BCC bra_EF6F_RTS
  INC ram_03B1_obj,X
bra_EF6A
sub_EF6A
  LDA #$40
  STA ram_03E8_obj,X
bra_EF6F_RTS
  RTS



sub_EF70
  LDA ram_03A6_obj,X ; 03A6 03A7 03A8 03A9 03AB 03AC 
  CLC
  ADC ram_03C7_obj,X ; 03C7 03C8 03C9 03CA 03CC 03CD 
  STA ram_03C7_obj,X ; 03C7 03C8 03C9 03CA 03CC 03CD 
  RTS



sub_EF7B
  LDA ram_00BD_obj,X
sub_EF7D
loc_EF7D
  CLC
  ADC ram_009C_obj_pos_X,X
  STA ram_009C_obj_pos_X,X
  RTS



sub_EF83
  LDA ram_03BC_obj,X
  CLC
  ADC ram_03D2_obj,X
  STA ram_03D2_obj,X
  RTS



sub_EF8E
  LDA ram_03B1_obj,X
  CLC
  ADC tbl_EDE6_offset - $01,X
  TAY
  LDA tbl_EDF1,Y
  RTS



sub_EF9A
  LDY ram_00DC
  DEY
  DEY
  BMI bra_EFB7
  BNE bra_EFA8
  LDA #$18
  STA ram_00DD_temp
  INC ram_00DC
bra_EFA8
  INC ram_00A7_obj_pos_Y + $01
  INC ram_00A7_obj_pos_Y + $01
  DEC ram_00DD_temp
  BNE bra_EFB6_RTS
  LDA #$00
  STA ram_00DC
  DEC ram_00B2_obj + $01
bra_EFB6_RTS
  RTS
bra_EFB7
  LDX #$01
; bzk optimize, X = 1
  LDA ram_0091_obj,X
  BEQ bra_EFE1_RTS
  LDA ram_0090
  SEC
; bzk optimize, X = 1
  SBC ram_00B2_obj,X
  CMP #$04
  BCC bra_EFCB
  LDA #$84
  STA ram_03E8_obj,X ; 03E9 
bra_EFCB
; bzk optimize, X = 1
  LDA ram_009C_obj_pos_X,X ; 009D 
; bzk optimize, X = 1
  LDY ram_00BD_obj,X ; 00BE 
  BMI bra_EFD3
  ADC #$08
bra_EFD3
  JSR sub_EF47
  BPL bra_EFE1_RTS
  LDA ram_00DC
  BNE bra_EFDF
  JSR sub_EF4E
bra_EFDF
  INC ram_00DC
bra_EFE1_RTS
  RTS



tbl_EFE2
  db $18   ; 02 
  db $30   ; 03 



tbl_EFE4
  db $40   ; 00 
  db $40   ; 01 
  db $50   ; 02 
  db $60   ; 03 
  db $70   ; 04 
  db $80   ; 05 
  db $90   ; 06 
  db $98   ; 07 



sub_EFEC
  LDX #$02
  JSR sub_EFF3
  LDX #$03
sub_EFF3
; X = 02 03
  LDA ram_0091_obj,X ; 0093 0094 
  BEQ bra_F03B
  BPL bra_F014_RTS
  JSR sub_EF42
  BPL bra_F014_RTS
  LDA ram_03A6_obj,X ; 03A8 03A9 
  CMP #$C0
  BNE bra_F015
  LDA #con_sfx_2_04
  STA ram_sfx_2
  LSR ; 02
  STA ram_0091_obj,X ; 0093 0094 
  LDA #$00
  STA ram_03D2_obj,X ; 03D4 03D5 
  STA ram_0382_obj,X ; 0384 0385 
bra_F014_RTS
  RTS
bra_F015
  LDA ram_00B2_obj,X ; 00B4 00B5 
  STA ram_0382_obj + $04,X ; 0388 0389 
  LDA ram_00BD_obj,X ; 00BF 00C0 
  STA ram_0382_obj,X ; 0384 0385 
  LDA #$C0
  STA ram_03A6_obj,X ; 03A8 03A9 
  LDA tbl_EFE2 - $02,X
  STA ram_004A_plr_timer - $02,X ; 004A 004B 
  JSR sub_EF4E
  JMP loc_EF7D



tbl_F02F
  db $01   ; 00 
  db $03   ; 01 
  db $05   ; 02 
  db $03   ; 03 
  db $05   ; 04 
  db $03   ; 05 
  db $05   ; 06 
  db $07   ; 07 
  db $05   ; 08 
  db $07   ; 09 
  db $06   ; 0A 
  db $07   ; 0B 



bra_F03B
  LDA ram_0382_obj,X ; 0384 0385 
  BEQ bra_F043
  JMP loc_F0C9
bra_F043
  LDA ram_004A_plr_timer - $02,X
  BNE bra_F014_RTS
  LDA ram_random - $02,X
  AND #$01
  BNE bra_F04F
  LDA #$FF
bra_F04F
  STA ram_00BD_obj,X ; 00BF 00C0 
  STA ram_009C_obj_pos_X,X ; 009E 009F 
  TXA
  SEC
  SBC #$02
  STA ram_0000
  LDA ram_0090
  SEC
  SBC #$04
  ASL
  CLC
  ADC ram_0000
  TAY
  LDA tbl_F02F,Y
  CPY #$0B
  BNE bra_F075
  CMP #$07
  BNE bra_F075
  LDA ram_random + $01
  AND #$01
  CLC
  ADC #$07
bra_F075
sub_F075
  CMP ram_0786
  BEQ bra_F07F
  CMP ram_0787
  BNE bra_F092
bra_F07F
  CLC
  ADC #$01
  CMP ram_0786
  BEQ bra_F0C8_RTS
  CMP ram_0787
  BEQ bra_F0C8_RTS
  CMP ram_0090
  BEQ bra_F092
  BCS bra_F0C8_RTS
bra_F092
  CMP #$09
  BCS bra_F0C8_RTS
  STA ram_0000
  LDA ram_0090
  SEC
  SBC #$04
  CMP ram_0000
  BCS bra_F0C8_RTS
  LDA ram_0000
  STA ram_00B2_obj,X
  LDA #$FF
  STA ram_0091_obj,X
  STA ram_03D2_obj,X
  LDA ram_mountain_completed
  AND #$07
  TAY
  LDA tbl_EFE4,Y
  STA ram_03A6_obj,X ; 03A8 03A9 
  LDA #$40
  STA ram_03BC_obj,X ; 03BE 03BF 
  LDA ram_00B2_obj,X ; 00B4 00B5 
  JSR sub_EDD5
  STA ram_00A7_obj_pos_Y,X
  LDA tbl_EFE2 - $02,X
  STA ram_004A_plr_timer - $02,X
bra_F0C8_RTS
  RTS



loc_F0C9
; X = 02 03
  STA ram_00BD_obj,X ; 00BF 00C0 
  STA ram_009C_obj_pos_X,X ; 009E 009F 
  LDA #$00
  STA ram_0382_obj,X ; 0384 0385 
  STA ram_0000
  LDA ram_0382_obj + $04,X ; 0388 0389 
  JSR sub_F075
; triggers when a seal respawns carrying an ice block,
; or when he realises that he needs an ice block and starts running back
  TXA
  PHA
bra_F0DC_loop
  LDA ram_0091_obj,X ; 0093 0094 009E 009F 00A9 00AA 00B4 00B5 00BF 00C0 
  STA ram_0091_obj + $03,X ; 0096 0097 00A1 00A2 00AC 00AD 00B7 00B8 00C2 00C3 
  LDA ram_03A6_obj,X ; 03A8 03A9 03B3 03B4 03BE 03BF 03C9 03CA 03D4 03D5 
  STA ram_03A6_obj + $03,X ; 03AB 03AC 03B6 03B7 03C1 03C2 03CC 03CD 03D7 03D8 
  TXA
  CLC
  ADC #$0B
  TAX
  CPX #$37
  BCC bra_F0DC_loop
  PLA
  TAX
  LDA #$0E
  LDY ram_00BD_obj,X ; 00BF 00C0 
  BPL bra_F0F9
  LDA #$FA
bra_F0F9
  CLC
  ADC ram_009C_obj_pos_X,X ; 009E 009F 
  STA ram_009C_obj_pos_X + $03,X ; 00A1 00A2 
  LDA #$00            
  STA ram_03B1_obj + $03,X ; 03B6 03B7 
  STA ram_03BC_obj + $03,X ; 03C1 03C2 
  RTS



tbl_F107
  db $10   ; 00 
  db $0E   ; 01 
  db $0C   ; 02 
  db $0C   ; 03 



sub_F10B
  LDX #$02
  LDA ram_mountain_current
  CMP #$20
  BCS bra_F11C
  LDX ram_mountain_completed
  BEQ bra_F13A_RTS
  DEX
  BEQ bra_F11C
  LDX #$01
bra_F11C
bra_F11C_loop
  TXA
  CLC
  ADC #$18
  ORA #$40
  STA ram_03E8_obj + $08,X ; 03F0 03F1 03F2 
  LDA ram_00BD_obj + $08,X ; 00C5 00C6 00C7 
  ADC #$60
  STA ram_00BD_obj + $08,X ; 00C5 00C6 00C7 
  LDA ram_0091_obj + $08,X ; 0099 009A 009B 
  CMP #$20
  BEQ bra_F137
  CLC
  ADC #$01
  JSR sub_F13B
bra_F137
  DEX
  BPL bra_F11C_loop
bra_F13A_RTS
  RTS



sub_F13B
  JSR sub_C728_jump_to_pointers_after_jsr
  dw ofs_004_F18D_FF
  dw ofs_004_F148_00
  dw ofs_004_F196_01
  dw ofs_004_F156_02
  dw ofs_004_F150_03



ofs_004_F148_00
  DEC ram_03C7_obj + $08,X ; 03CF 03D0 03D1 
  BNE bra_F150
  JSR sub_F1AE
bra_F150
ofs_004_F150_03
  LDA #$00
  STA ram_03E8_obj + $08,X ; 03F0 03F1 03F2 
  RTS



ofs_004_F156_02
  DEC ram_03D2_obj + $08,X ; 03DA 03DB 03DC 
  BNE bra_F163
  LDA #con_sfx_2_02
  STA ram_sfx_2
  LDA #$FF
  STA ram_0091_obj + $08,X ; 0099 009A 
bra_F163
  JSR sub_F222
  BMI bra_F174
  TXA
  ASL
  ASL
  ASL
  CLC
  ADC #$08
  ADC ram_0788,Y ; 0788 0789 
  STA ram_009C_obj_pos_X + $08,X ; 00A4 00A5 
bra_F174
  LDA ram_03D2_obj + $08,X ; 03DA 03DB 03DC 
  ASL
  ROL
  ROL
  AND #$03
  TAY
  LDA tbl_F107,Y
  STA ram_03DD_obj + $08,X ; 03E5 03E6 03E7 
  LDA ram_00A7_obj_pos_Y + $08,X ; 00AF 00B0 00B1 
  AND #$F8
  STA ram_00A7_obj_pos_Y + $08,X ; 00AF 00B0 00B1 
  JSR sub_F1F3
bra_F18C_RTS
  RTS



ofs_004_F18D_FF
  LDA #$02
  JSR sub_F215_add_to_falling_ice_pos_Y
  CMP #$F0
  BCC bra_F18C_RTS
bra_F196
ofs_004_F196_01
  LDA ram_03E8_obj + $08,X ; 03F0 03F1 
  ORA #$80
  STA ram_03E8_obj + $08,X ; 03F0 03F1 
sub_F19E
  JSR sub_F7AB_get_random_value
  ASL
  ASL
  STA ram_03C7_obj + $08,X ; 03CF 03D0 03D1 
  LDA #$00
  STA ram_03D2_obj + $08,X ; 03DA 03DB 03DC 
  RTS



tbl_F1AC_falling_ice_pos_Y_offset
  db $07   ; 01 
  db $03   ; 02 



sub_F1AE
  LDA ram_0091_obj + $01
  ORA ram_007C
  BNE bra_F196
  LDA ram_random,X
  AND #$F8
  CMP #$38
  BCC bra_F1C3
  CMP #$C9
  BCC bra_F1C5
  SBC #$38
  db $2C   ; BIT opcode
bra_F1C3
  ADC #$38
bra_F1C5
  CMP ram_009C_obj_pos_X + $08
  BEQ bra_F21D
  CMP ram_009C_obj_pos_X + $09
  BEQ bra_F21D
  CMP ram_009C_obj_pos_X + $0A
  BEQ bra_F21D
  STA ram_009C_obj_pos_X + $08,X ; 00A4 00A5 00A6 
  LDA ram_0090
  TAY
  DEY
  DEY
  SEC
  SBC #$08
  BEQ bra_F1E3
  BPL bra_F1E7
  LDA #$20    ; falling ice position
  INY
  db $2C   ; BIT opcode
bra_F1E3
  LDA #$50
  INY
  db $2C   ; BIT opcode
bra_F1E7
  LDA #$80
  STA ram_00A7_obj_pos_Y + $08,X ; 00AF 00B0 00B1 
  INY
  TYA
  STA ram_00B2_obj + $08,X ; 00BA 00BB 00BC 
  LDA #$02
  STA ram_0091_obj + $08,X ; 0099 009A 009B 
sub_F1F3
  JSR sub_F222
  BPL bra_F221_RTS
  TXA
  PHA
  LDA ram_009C_obj_pos_X + $08,X ; 00A4 00A5 00A6 
  STA ram_000E
  LDA ram_00B2_obj + $08,X ; 00BA 00BB 00BC 
  STA ram_000F
  JSR sub_DEB9
  TAY
  BMI bra_F21B
  PLA
  TAX
  LDY ram_0002
  BMI bra_F221_RTS
  CPY #$04
  BEQ bra_F21D
  LDA tbl_F1AC_falling_ice_pos_Y_offset - $01,Y
sub_F215_add_to_falling_ice_pos_Y
  CLC
  ADC ram_00A7_obj_pos_Y + $08,X ; 00AF 00B0 00B1 
  STA ram_00A7_obj_pos_Y + $08,X ; 00AF 00B0 00B1 
  RTS
bra_F21B
  PLA
  TAX
bra_F21D
  LDA #$01
  STA ram_0091_obj + $08,X ; 0099 009A 
bra_F221_RTS
  RTS



sub_F222
  LDY #$01
  LDA ram_00B2_obj + $08,X ; 00BA 00BB 00BC 
bra_F226_loop
  CMP ram_0786,Y ; 0786 0787 
  BEQ bra_F22E_RTS
  DEY
  BPL bra_F226_loop
bra_F22E_RTS
  RTS



tbl_F22F
  db $0E   ; 00 
  db $39   ; 01 
  db $38   ; 02 
  db $37   ; 03 
  db $36   ; 04 
  db $1B   ; 05 
  db $1A   ; 06 
  db $19   ; 07 
  db $18   ; 08 
  db $38   ; 09 
  db $34   ; 0A 
  db $5B   ; 0B 
  db $5A   ; 0C 
  db $93   ; 0D 
  db $91   ; 0E 
  db $38   ; 0F 
  db $38   ; 10 



tbl_F240
; 0D 
  db $91   ; 00 
  db $3A   ; 01 
  db $33   ; 02 
  db $36   ; 03 
  db $3D   ; 04 
  db $38   ; 05 
; 13 
  db $4D   ; 00 
  db $53   ; 01 
  db $53   ; 02 
  db $53   ; 03 
  db $53   ; 04 
  db $A9   ; 05 
; 19 
  db $AF   ; 00 
  db $3A   ; 01 
  db $3B   ; 02 
  db $3C   ; 03 
  db $3D   ; 04 
  db $B5   ; 05 
; 1F 
  db $AF   ; 00 
  db $04   ; 01 
  db $00   ; 02 
  db $5D   ; 03 
  db $00   ; 04 
  db $B5   ; 05 
; 25 
  db $BB   ; 00 
  db $C1   ; 01 
  db $C1   ; 02 
  db $C1   ; 03 
  db $C1   ; 04 
  db $C7   ; 05 



tbl_F25E_offset
  db $0D   ; 00 
  db $13   ; 01 
  db $19   ; 02 
  db $1F   ; 03 
  db $25   ; 04 
  db $13   ; 05 
  db $19   ; 06 
  db $1F   ; 07 
  db $25   ; 08 



tbl_F267
  db $01   ; 00 
  db $01   ; 01 
  db $01   ; 02 
  db $01   ; 03 
  db $05   ; 04 
  db $05   ; 05 
  db $05   ; 06 
  db $09   ; 07 
  db $0B   ; 08 
  db $0C   ; 09 
  db $0F   ; 0A 
  db $10   ; 0B 
  db $11   ; 0C 
  db $13   ; 0D 
  db $15   ; 0E 
  db $16   ; 0F 
  db $1A   ; 10 
  db $1A   ; 11 
  db $1A   ; 12 
  db $1A   ; 13 
  db $1A   ; 14 
  db $1A   ; 15 
  db $1B   ; 16 
  db $1B   ; 17 
  db $1E   ; 18 
  db $1F   ; 19 
  db $1F   ; 1A 
  db $20   ; 1B 
  db $21   ; 1C 
  db $21   ; 1D 
  db $24   ; 1E 
  db $24   ; 1F 
  db $24   ; 20 
  db $24   ; 21 
  db $26   ; 22 
  db $29   ; 23 
  db $2A   ; 24 
  db $2E   ; 25 
  db $2E   ; 26 
  db $2E   ; 27 
  db $2E   ; 28 
  db $00   ; 29 



tbl_F291
  db $A1   ; 00 
  db $A9   ; 01 
  db $B1   ; 02 
  db $D9   ; 03 
  db $66   ; 04 
  db $AD   ; 05 
  db $76   ; 06 
  db $74   ; 07 
  db $6A   ; 08 
  db $6A   ; 09 
  db $72   ; 0A 
  db $72   ; 0B 
  db $C5   ; 0C 
  db $74   ; 0D 
  db $55   ; 0E 
  db $AC   ; 0F 
  db $AA   ; 10 
  db $B0   ; 11 
  db $67   ; 12 
  db $4D   ; 13 
  db $52   ; 14 
  db $77   ; 15 
  db $66   ; 16 
  db $F2   ; 17 
  db $8C   ; 18 
  db $69   ; 19 
  db $6F   ; 1A 
  db $70   ; 1B 
  db $6E   ; 1C 
  db $48   ; 1D 
  db $48   ; 1E 
  db $4A   ; 1F 
  db $71   ; 20 
  db $53   ; 21 
  db $4C   ; 22 
  db $6E   ; 23 
  db $AD   ; 24 
  db $0C   ; 25 
  db $51   ; 26 
  db $A6   ; 27 
  db $B4   ; 28 



tbl_F2BA
  db $FF   ; 00 
  db $FF   ; 01 
  db $FF   ; 02 
  db $FF   ; 03 
  db $FF   ; 04 
  db $FF   ; 05 
  db $FF   ; 06 
  db $1B   ; 07 
  db $0A   ; 08 
  db $41   ; 09 
  db $0B   ; 0A 
  db $D4   ; 0B 
  db $9E   ; 0C 
  db $02   ; 0D 
  db $88   ; 0E 
  db $D8   ; 0F 
  db $02   ; 10 
  db $02   ; 11 
  db $04   ; 12 
  db $04   ; 13 
  db $04   ; 14 
  db $04   ; 15 
  db $10   ; 16 
  db $10   ; 17 
  db $01   ; 18 
  db $40   ; 19 
  db $60   ; 1A 
  db $80   ; 1B 
  db $02   ; 1C 
  db $80   ; 1D 
  db $20   ; 1E 
  db $2B   ; 1F 
  db $09   ; 20 
  db $A2   ; 21 
  db $80   ; 22 
  db $98   ; 23 
  db $46   ; 24 
  db $A8   ; 25 
  db $28   ; 26 
  db $FF   ; 27 
  db $FF   ; 28 
  db $FF   ; 29 



tbl_F2E4
  db $E5   ; 00 
  db $38   ; 01 
  db $38   ; 02 
  db $D9   ; 03 
  db $38   ; 04 
  db $38   ; 05 
  db $DF   ; 06 
  db $38   ; 07 



sub_F2EC
loc_F2EC
  LDA ram_buffer_offset
  ORA ram_buffer_index
  BNE bra_F35A_RTS
  LDA ram_008D
  TAY
  BEQ bra_F35A_RTS
  CMP #$01
  BEQ bra_F305
  CMP #$3E
  BCC bra_F32E
  LDA #$00
  STA ram_008D
  RTS
bra_F305
  LDA #$FF
  LDX #$77
bra_F309_loop
  STA ram_0668_data,X
  DEX
  BPL bra_F309_loop
  LDA #$00
  STA ram_0346
  STA ram_0347
  LDA #$D8
  STA ram_034A
  JSR sub_F45B
  LDA ram_mountain_current
  AND #$07
  TAX
  LDA #$00
  SEC
bra_F327_loop
  ROR
  DEX
  BPL bra_F327_loop
  STA ram_0345
bra_F32E
  JSR sub_F35B
  JSR sub_F3D2
  INC ram_008D
  LDA ram_008D
  LDX #$08
bra_F33A_loop
  CMP tbl_F22F,X
  BEQ bra_F343
  DEX
  BPL bra_F33A_loop
  RTS
bra_F343
  LDY #$15
  TXA
  BEQ bra_F34A
  LDY #$06
bra_F34A
  LDA tbl_F25E_offset,X
  TAX
bra_F34E_loop
  LDA tbl_F240 - 8,X
  STA ram_ppu_buffer + $04,Y
  DEX
  BMI bra_F35A_RTS
  DEY
  BNE bra_F34E_loop
bra_F35A_RTS
  RTS



sub_F35B
  LDA #$38
  db $2C   ; BIT opcode
  LDA #$90
  LDY #$1F
bra_F362_loop
  STA ram_ppu_buffer + $03,Y
  DEY
  BPL bra_F362_loop
  LDA #$23
  STA ram_buffer_index
  LDA ram_0349_ppu_hi
  STA ram_ppu_buffer
  LDA ram_0348_ppu_lo
  STA ram_ppu_buffer + $01
  LDA #$20
  STA ram_ppu_buffer + $02
  LDA #$00
  STA ram_ppu_buffer + $23
  LDY ram_008D
  CPY #$2E
  BCS bra_F3D1_RTS
  DEY
  TYA
  LDY #$00
bra_F38D_loop
  SEC
  SBC #$07
  BCC bra_F395
  INY
  BCS bra_F38D_loop    ; jmp
bra_F395
  TYA
  STA ram_0000
  EOR #$FF
  SEC
  ADC #$1D
  PHA
  TAY
bra_F39F_loop
  LDX #$04
bra_F3A1_loop
; 0019-001D
  ROL ram_random + $01,X
  DEX
  BPL bra_F3A1_loop
  LDA ram_random + $01
  AND #$07
  TAX
  LDA tbl_F2E4,X
  STA ram_ppu_buffer + $03,Y
  DEY
  CPY ram_0000
  BNE bra_F39F_loop
  PLA
  TAY
  JSR sub_F3BD
  LDY ram_0000
sub_F3BD
  LDA ram_008D
  AND #$01
  BNE bra_F3C6
  LDA #$55
  db $2C   ; BIT opcode
bra_F3C6
  LDA #$58
  STA ram_ppu_buffer + $03,Y
  STA ram_ppu_buffer + $04,Y
  STA ram_ppu_buffer + $05,Y
bra_F3D1_RTS
  RTS



sub_F3D2
loc_F3D2
  LDY ram_0346
  LDA tbl_F2BA,Y
  AND ram_0345
  BEQ bra_F430
  LDA tbl_F267,Y
  CMP ram_008D
  BNE bra_F436
  LDA tbl_F291,Y
  PHA
  AND #$1F
  TAY
  PLA
  LSR
  LSR
  LSR
  LSR
  LSR
  TAX
  STY ram_0000
  STX ram_0001
  LDA #$EB
bra_F3F8_loop
  STA ram_ppu_buffer + $03,Y
  INY
  DEX
  BPL bra_F3F8_loop
  LDY ram_0347
  LDA ram_0000
  PHA
  ASL
  ASL
  ASL
  STA ram_0668_data,Y
  PLA
  SEC
  ADC ram_0001
  ASL
  ASL
  ASL
  STA ram_0686_data,Y
  LDA ram_034A
  STA ram_06A4,Y
  CLC
  ADC #$03
  STA ram_06C2_data,Y
  LDA #$00
  LDX #$1D
  CPX ram_008D
  BCC bra_F42A
  ROL
bra_F42A
  STA ram_06E0_bouns_stage_data,Y
  INC ram_0347
bra_F430
  INC ram_0346
  JMP loc_F3D2
bra_F436
  LDA ram_034A
  SEC
  SBC #$08
  STA ram_034A
  LDA ram_0348_ppu_lo
  SEC
  SBC #< $0020
  STA ram_0348_ppu_lo
  LDA ram_0349_ppu_hi
  SBC #> $0020
  STA ram_0349_ppu_hi
  CMP #$1F
  BEQ bra_F45B
  CMP #$27
  BNE bra_F465_RTS
  LDA #$23    ; > $23A0
  db $2C   ; BIT opcode
bra_F45B
sub_F45B
  LDA #$2B    ; > $2BA0
  STA ram_0349_ppu_hi
  LDA #$A0    ; < $23A0 or < $2BA0
  STA ram_0348_ppu_lo
bra_F465_RTS
  RTS



tbl_F466
  db $EE   ; 00 
  db $F4   ; 01 
  db $38   ; 02 
  db $E8   ; 03 



tbl_F46A
  db $20   ; 00 
  db $90   ; 01 



tbl_F46C
  db $1E   ; 00 
  db $00   ; 01 
  db $10   ; 02 



tbl_F46F
  db $00   ; 00 
  db $24   ; 01 



sub_F471
  LDX ram_game_mode
  LDA ram_0084_plr
  BNE bra_F499_loop
bra_F477_loop
  LDY #$00
  STY ram_006C_plr,X
  INY ; 01
  STY ram_00E4_plr,X
  INY ; 02
  STY ram_plr_handler,X
  LDA #$F0
  STA ram_00E2_plr,X
  LDA #$3F
  STA ram_plr_pos_Y,X
  DEX
  BPL bra_F477_loop
  LDX ram_001E
  BEQ bra_F494
  LDA #$00
  STA ram_plr_handler - $01,X
bra_F494
  INC ram_0084_plr
  JMP loc_F63B
bra_F499_loop
  LDA ram_0037_plr_timer,X
  BNE bra_F4A0
  JSR sub_F504
bra_F4A0
  LDA ram_plr_pos_Y,X
  STA ram_0001
  LDA ram_plr_handler,X
  ORA ram_006C_plr,X
  PHA
  CMP #$01
  BNE bra_F4C9
  LDA ram_0001
  CMP #$3F
  BNE bra_F4B7
  LDA #con_sfx_3_plr_jump
  STA ram_sfx_3
bra_F4B7
  LDA #$00
  STA ram_002F_plr,X
  TXA
  JSR sub_C83D
  LDA ram_0001
  CMP #$3F
  BCC bra_F4C7_not_overflow
  LDA #$3F
bra_F4C7_not_overflow
  STA ram_plr_pos_Y,X
bra_F4C9
  PLA
  PHA
  TAY
  LDA tbl_F466,Y
  STA ram_0002
  LDA tbl_F46A,X
  STA ram_0000
  STA ram_000E
  LDA #$00
  STA ram_000F
  TXA
  PHA
  TAY
  INY
  JSR sub_EAFC
  PLA
  TAX
  PLA
  CMP #$01
  BNE bra_F500
  LDA tbl_F46F,X
  TAY
  LDA ram_spr_X,Y
  CLC
  ADC #$08
  STA ram_spr_X,Y
  LDA ram_spr_X + $0C,Y
  CLC
  ADC #$08
  STA ram_spr_X + $0C,Y
bra_F500
  DEX
  BPL bra_F499_loop
  RTS



sub_F504
  LDY ram_plr_handler,X
  LDA tbl_F46C,Y
  STA ram_0037_plr_timer,X
  LDA ram_006C_plr,X
  EOR #$01
  STA ram_006C_plr,X
  BNE bra_F517
  LDA #con_sfx_3_kill_seal_or_ice
  STA ram_sfx_3
bra_F517
  LDA #$00
  STA ram_00E0_plr,X
  RTS



tbl_F51C_start_index
  db $20   ; 01 041B-0420
  db $89   ; 02 0484-0489



tbl_F51E
  db $94   ; 00 
  db $3B   ; 01 
  db $5A   ; 02 
  db $5A   ; 03 
  db $3D   ; 04 
  db $8E   ; 05 



sub_F524
  LDX ram_001E
  BEQ bra_F537_RTS
  LDY tbl_F51C_start_index - $01,X
  LDX #$05
bra_F52D_loop
  LDA tbl_F51E,X
  STA ram_0400_data,Y
  DEY
  DEX
  BPL bra_F52D_loop
bra_F537_RTS
  RTS



tbl_F538
; 02 
  db $22   ; 00 
  db $93   ; 01 
  db $02   ; 02 
; 05 
  db $20   ; 00 
  db $73   ; 01 
  db $02   ; 02 



sub_F53E
  LDY ram_mountain_current
  DEY
  LDA ram_btn_hold
  AND #con_btns_Dpad
  BEQ bra_F560
  AND #con_btn_Down + con_btn_Right
  BEQ bra_F54D
  INY
  INY
bra_F54D
  TYA
  AND #$1F
  LDY ram_0037_plr_timer
  BNE bra_F562
  STA ram_mountain_current
  LDA #$80
  STA ram_spawn_timer_lo_bird
  LDA #con_sfx_2_08
  STA ram_sfx_2
  LDA #$0F
bra_F560
  STA ram_0037_plr_timer
bra_F562
  LDY #$02
loc_F564
  LDX #$02
bra_F566_loop
  LDA tbl_F538,Y
  STA ram_ppu_buffer,X
  DEY
  DEX
  BPL bra_F566_loop
  INX
  STX ram_ppu_buffer + $05
  LDY ram_mountain_current
  INY
  TYA
  JSR sub_EA4A_get_tens
  STY ram_ppu_buffer + $03
  STA ram_ppu_buffer + $04
  RTS



tbl_F582
  db $00   ; 01 
  db $05   ; 02 



tbl_F584
  db $00   ; 01 
  db $0E   ; 02 



sub_F586
  LDX ram_001E
  BEQ bra_F5C4
  LDA #$21
  STA ram_ppu_buffer
  LDA #$48
  CLC
  ADC tbl_F584 - $01,X
  STA ram_ppu_buffer + $01
  LDA #$05
  STA ram_ppu_buffer + $02
  JSR sub_EA55
  LDX ram_001E
  LDY tbl_F582 - $01,X
  STA ram_plr_counter_stage_bonus,Y
  JSR sub_EA4A_get_tens
  CPY #$00
  BNE bra_F5B1
  LDY #$38
bra_F5B1
  STY ram_ppu_buffer + $03
  STA ram_ppu_buffer + $04
  LDX #$03
  LDA #$00
bra_F5BB_loop
  STA ram_ppu_buffer + $05,X
  DEX
  BPL bra_F5BB_loop
  JSR sub_C14E
bra_F5C4
  LDY #$05
  JMP loc_F564



tbl_F5C9
  db $52   ; 00 
  db $70   ; 01 
  db $AE   ; 02 
  db $B6   ; 03 
  db $BA   ; 04 
  db $C2   ; 05 
  db $C6   ; 06 
  db $CA   ; 07 
  db $BE   ; 08 
  db $FA   ; 09 



tbl_F5D3
  db $30   ; 00 
  db $13   ; 01 
  db $01   ; 02 
  db $30   ; 03 
  db $16   ; 04 
  db $19   ; 05 
  db $30   ; 06 
  db $39   ; 07 
  db $29   ; 08 
  db $30   ; 09 
  db $3A   ; 0A 
  db $1A   ; 0B 
  db $29   ; 0C 
  db $26   ; 0D 
  db $07   ; 0E 
  db $30   ; 0F 
  db $16   ; 10 
  db $19   ; 11 
  db $30   ; 12 
  db $16   ; 13 
  db $26   ; 14 
  db $30   ; 15 
  db $17   ; 16 
  db $29   ; 17 
  db $30   ; 18 
  db $17   ; 19 
  db $06   ; 1A 
  db $30   ; 1B 
  db $17   ; 1C 
  db $06   ; 1D 
  db $30   ; 1E 
  db $16   ; 1F 
  db $27   ; 20 
  db $30   ; 21 
  db $11   ; 22 
  db $26   ; 23 
  db $30   ; 24 
  db $15   ; 25 



tbl_F5F9
  db $26   ; 00 
  db $30   ; 01 
  db $21   ; 02 
  db $26   ; 03 
  db $30   ; 04 
  db $25   ; 05 
  db $26   ; 06 
  db $27   ; 07 
  db $17   ; 08 
  db $07   ; 09 
  db $18   ; 0A 
  db $10   ; 0B 
  db $14   ; 0C 
  db $10   ; 0D 
  db $14   ; 0E 
  db $1C   ; 0F 



tbl_F609
  db $3F   ; 00 
  db $1C   ; 01 
  db $04   ; 02 
  db $0F   ; 03 



tbl_F60D   ; bzk optimize, same bytes
  db $F0   ; 00 
  db $F0   ; 01 



sub_F60F
  JSR sub_F63B
  LDA ram_0055
  AND #$01
  EOR ram_0051
  TAX
  LDA tbl_F60D,X
  STA ram_05FD
  LDA #$78
  STA ram_05FC
loc_F624
  LDX #$02
bra_F626_loop
  LDA ram_05FC,X
  STA ram_0000,X
  DEX
  BPL bra_F626_loop
  LDY #$0D
sub_F630
  LDA ram_00D4 + $01
  STA ram_000F
  LDA #$01
  STA ram_000E
  JMP loc_EAFC



loc_F63B
sub_F63B
  LDA ram_mountain_completed
bra_F63D_loop
  CMP #$0A
  BCC bra_F645
  SBC #$0A
  BCS bra_F63D_loop
bra_F645
  TAX
  LDA tbl_F5C9,X
  STA ram_05FE
sub_F64C
  STX ram_000F
  TXA
  ASL
  CLC
  ADC ram_000F
  TAY
  LDX ram_buffer_index
  LDA #$00
  STA ram_ppu_buffer + $07,X
  LDA #$03
  STA ram_0000
bra_F660_loop
  LDA tbl_F5D3,Y
  STA ram_ppu_buffer + $04,X
  INY
  INX
  DEC ram_0000
  BNE bra_F660_loop
  LDX ram_buffer_index
  LDY #$00
bra_F671_loop
  LDA tbl_F609,Y
  STA ram_ppu_buffer,X
  INX
  INY
  CPY #$04
  BNE bra_F671_loop
  RTS



loc_F67E
  LDA ram_giant_bird_X_pos
  CLC
  ADC #$0A
  STA ram_05FC
  LDA ram_giant_bird_Y_pos
  CLC
  ADC #$0E
  STA ram_05FD
  JMP loc_F624



loc_F691
sub_F691
  TYA
  PHA
  LDA tbl_F5F9,X
  PHA
  JSR sub_F64C
  PLA
  LDY ram_buffer_index
  STA ram_ppu_buffer + $01,Y
  PLA
  TAY
  RTS



sub_F6A4
  LDA ram_003A_plr_timer + $01
  BNE bra_F6DA_RTS
  LDA ram_07FA
  ORA ram_07FB
  BEQ bra_F6DB
  LDA #$02
  STA ram_0001
  LDA #$01
  LDY ram_07FB
  BEQ bra_F6BD
  LDA #$11
bra_F6BD
  PHA
  JSR sub_C94B
  LDA #$03
  STA ram_0001
  PLA
  JSR sub_C94B
  LDA #$23
  JSR sub_C8E0
  LDA #$5D
  STA ram_ppu_buffer + $05
  STA ram_ppu_buffer + $0C
  LDA #$06
  STA ram_003A_plr_timer + $01
bra_F6DA_RTS
  RTS
bra_F6DB
  STA ram_001E
  LDA #$06
  STA ram_plr_handler
  LDA #$0A
  STA ram_004D_timer
  LDA #con_music_off
  STA ram_music_1
  RTS



tbl_F6EA_fruit_pos_Y
; at bonus stages
  db $10   ; 00 
  db $40   ; 01 
  db $98   ; 02 
  db $98   ; 03 



tbl_F6EE_fruit_pos_X
; at bonus stages
  db $60   ; 00 
  db $A0   ; 01 
  db $30   ; 02 
  db $C0   ; 03 



sub_F6F2
  LDX #$0A
bra_F6F4_loop
  LDA #$00
  STA ram_0091_obj,X ; 0091 0092 0093 0094 0095 0096 0097 0098 0099 009A 009B 
  CPX #$04
  BCS bra_F719
; X = 00-03
  LDA tbl_F6EE_fruit_pos_X,X
  STA ram_009C_obj_pos_X + $03,X ; 009F 00A0 00A1 00A2 
  LDA tbl_F6EA_fruit_pos_Y,X
  STA ram_00A7_obj_pos_Y + $03,X ; 00AA 00AB 00AC 00AD 
  LDA #$FF
  STA ram_0091_obj + $03,X ; 0094 0095 0096 0097 
  STA ram_00BD_obj + $03,X ; 00C0 00C1 00C2 00C3 
  LDA ram_05FE
  STA ram_03DD_obj + $03,X ; 03E0 03E1 03E2 03E3 
  TXA
  CLC
  ADC #$4F
  STA ram_03E8_obj + $03,X ; 03EB 03EC 03ED 03EE 
bra_F719
  DEX
  BPL bra_F6F4_loop
  RTS



sub_F71D
  LDX #$03
bra_F71F_loop
  LDA ram_0091_obj + $03,X
  CMP #$01
  BNE bra_F72C
  TXA
  CLC
  ADC #$8F
  STA ram_03E8_obj + $03,X
bra_F72C
  DEX
  BPL bra_F71F_loop
  RTS



tbl_F730
  db $3E   ; 00 
  db $46   ; 01 
  db $46   ; 02 



tbl_F733
  db $50   ; 00 
  db $51   ; 01 
  db $4E   ; 02 
  db $4F   ; 03 



sub_F737
loc_F737
  INC ram_00D3
  LDA ram_00D3
  CMP #$08
  BCC bra_F74F
  LDA #$00
  STA ram_00D3
  INC ram_00D4
  LDA ram_00D4
  CMP #$03
  BCC bra_F74F
  LDA #$00
  STA ram_00D4
bra_F74F
  LDY ram_00D4
  LDA tbl_F730,Y
  STA ram_0002
  LDY #$0E
  LDA ram_giant_bird_X_pos
  STA ram_0000
  LDA ram_giant_bird_Y_pos
  STA ram_0001
  JSR sub_F630
  LDA ram_00D4
  CMP #$02
  BNE bra_F78A_RTS
  LDY #$0C
  LDX #$03
  LDA ram_00D4 + $01
  BNE bra_F773
  LDX #$51
bra_F773
bra_F773_loop
  LDA ram_00D4 + $01
  BNE bra_F77D
  TXA
  STA ram_spr_T + $50,Y
  BNE bra_F783
bra_F77D
  LDA tbl_F733,X
  STA ram_spr_T + $40,Y
bra_F783
  DEX
  DEY
  DEY
  DEY
  DEY
  BPL bra_F773_loop
bra_F78A_RTS
  RTS



sub_F78B
  LDA #$FF
  LDX ram_00D4 + $01
  BEQ bra_F793
  LDA #$01
bra_F793
  CLC
  ADC ram_giant_bird_X_pos
  STA ram_giant_bird_X_pos
  CMP #$60
  BNE bra_F7A2
  LDA ram_random + $01
  AND #$01
  STA ram_00D4 + $01
bra_F7A2
  LDA ram_scroll_Y
  ORA ram_0027_flag
  BNE bra_F78A_RTS
  JMP loc_F737



sub_F7AB_get_random_value
; X = 00-02
  LDA ram_mountain_completed
  AND #$3C
  EOR #$3C
  ASL
  ASL
  ORA #$0F
  AND ram_random,X
  RTS



tbl_F7B8
  db $FF   ; 00 
  db $08   ; 01 
  db $11   ; 02 
  db $1E   ; 03 



tbl_F7BC
  db $04   ; 00 
  db $00   ; 01 
  db $06   ; 02 
  db $03   ; 03 
  db $05   ; 04 
  db $00   ; 05 
  db $06   ; 06 
  db $02   ; 07 
  db $FF   ; 08 
  db $05   ; 09 
  db $01   ; 0A 
  db $07   ; 0B 
  db $02   ; 0C 
  db $04   ; 0D 
  db $01   ; 0E 
  db $07   ; 0F 
  db $03   ; 00 
  db $FF   ; 11 
  db $04   ; 12 
  db $00   ; 13 
  db $06   ; 14 
  db $03   ; 15 
  db $05   ; 16 
  db $00   ; 17 
  db $04   ; 18 
  db $01   ; 19 
  db $07   ; 1A 
  db $02   ; 1B 
  db $04   ; 1C 
  db $00   ; 1D 
  db $FF   ; 1E 
  db $05   ; 1F 
  db $01   ; 20 
  db $07   ; 21 
  db $02   ; 22 
  db $04   ; 23 
  db $01   ; 24 
  db $05   ; 25 
  db $00   ; 26 
  db $06   ; 27 
  db $03   ; 28 
  db $05   ; 29 
  db $01   ; 2A 
  db $FF   ; 2B 



tbl_F7E8_pos_X
  db $10   ; 00 
  db $F0   ; 01 
  db $10   ; 02 
  db $F0   ; 03 



tbl_F7EC
  db $00   ; 00 
  db $00   ; 01 
  db $00   ; 02 
  db $00   ; 03 
  db $01   ; 04 
  db $00   ; 05 
  db $01   ; 06 
  db $01   ; 07 
  db $01   ; 08 
  db $01   ; 09 
  db $01   ; 0A 
  db $02   ; 0B 
  db $01   ; 0C 
  db $02   ; 0D 
  db $02   ; 0E 
  db $02   ; 0F 
  db $02   ; 10 
  db $02   ; 11 
  db $02   ; 12 
  db $02   ; 13 
  db $03   ; 14 
  db $02   ; 15 
  db $03   ; 16 
  db $03   ; 17 
  db $03   ; 18 
  db $03   ; 19 
  db $03   ; 1A 
  db $04   ; 1B 
  db $03   ; 1C 
  db $04   ; 1D 
  db $04   ; 1E 
  db $04   ; 1F 



sub_F80C
  LDA ram_random
  AND #$03
  TAY
  LDA #$20
  STA ram_00A7_obj_pos_Y
  LDA tbl_F7E8_pos_X,Y
  STA ram_009C_obj_pos_X
  LDA tbl_F7B8,Y
  STA ram_03BC_obj
  LDA #$00
  STA ram_03B1_obj
  STA ram_0091_obj
  LDA ram_mountain_completed
  CMP #$3D
  BCC bra_F82F_not_overflow
  LDA #$3D
bra_F82F_not_overflow
  ASL
  ASL
  CLC
  ADC #$2F
  STA ram_03A6_obj
  RTS



sub_F838
  LDA #$03
  STA ram_03E8_obj
  LDA ram_0091_obj
  BEQ bra_F877
  CMP #$20
  BEQ bra_F898_RTS
  CMP #$01
  BEQ bra_F899
  CMP #$02
  BEQ bra_F87C
  LDX #$00
  JSR sub_EF70
  BCC bra_F85C
  JSR sub_F8DB
  BMI bra_F85C
  JSR sub_F8AC
bra_F85C
  LDA ram_00B2_obj
  LSR
  ROR
  EOR #$80
  STA ram_00BD_obj
  LDA ram_frm_cnt
  AND #$08
  LSR
  ORA #$E0
bra_F86B
  STA ram_03DD_obj
  LDA ram_03E8_obj
  ORA #$40
  STA ram_03E8_obj
  RTS
bra_F877   ; A = 00
  STA ram_03E8_obj
  BEQ bra_F889    ; jmp
bra_F87C
  JSR sub_F7AB_get_random_value
  STA ram_spawn_timer_lo_bird
  LDA ram_03E8_obj
  ORA #$80
  STA ram_03E8_obj
bra_F889
  LDA ram_spawn_timer_lo_bird
  BNE bra_F898_RTS
  LDA ram_0091_obj
  BMI bra_F898_RTS
  JSR sub_F80C
  LDA #$FF
  STA ram_0091_obj
bra_F898_RTS
  RTS
bra_F899
  LDA ram_00A7_obj_pos_Y
  CLC
  ADC #$02
  STA ram_00A7_obj_pos_Y
  CMP #$F0
  BCC bra_F8A8
  LDA #$02
  STA ram_0091_obj
bra_F8A8
  LDA #$B2
  BNE bra_F86B    ; jmp



sub_F8AC
  LDY ram_03B1_obj
  LDA tbl_F7EC,Y
  PHA
  LDA ram_00B2_obj
  AND #$01
  BEQ bra_F8BE
  PLA
  JSR sub_D2FB_EOR
  PHA
bra_F8BE
  PLA
  JSR sub_EF7D
  LDA ram_00B2_obj
  AND #$02
  BEQ bra_F8CB
  DEC ram_00A7_obj_pos_Y
  db $2C   ; BIT opcode
bra_F8CB
  INC ram_00A7_obj_pos_Y
  LDA ram_00B2_obj
  AND #$04
  BNE bra_F8D7
  INC ram_03B1_obj
  RTS
bra_F8D7
  DEC ram_03B1_obj
  RTS



sub_F8DB
  LDA ram_03B1_obj
  AND #$1F
  BNE bra_F8F4
bra_F8E2_loop
  INC ram_03BC_obj
  LDY ram_03BC_obj
  LDA tbl_F7BC,Y
  AND #$04
  BEQ bra_F8F1
  LDA #$1F
bra_F8F1
  STA ram_03B1_obj
bra_F8F4
  LDA ram_009C_obj_pos_X
  CMP #$0F
  BCC bra_F911
  CMP #$F1
  BCS bra_F911
  LDA ram_00A7_obj_pos_Y
  CMP #$F0
  BCS bra_F911
  LDY ram_03BC_obj
  BMI bra_F8E2_loop
  LDA tbl_F7BC,Y
  CMP #$FF
  BNE bra_F919
  db $2C   ; BIT opcode
bra_F911
  LDA #$FF
  PHA
  LDA #$02
  STA ram_0091_obj
  PLA
bra_F919
  STA ram_00B2_obj
  RTS


; bzk garbage
  db $FF   ; 
  db $FF   ; 



sub_F91E_update_sound_engine
  LDA #$FF
  STA $4017
  JSR sub_F9EB_play_sfx_3
  JSR sub_FAC4_play_sfx_2
  JSR sub_FBA1_play_sfx_1
  JSR sub_FBFC_initialize_music
  LDA #$00
  STA ram_sfx_3    ; con_sfx_3_00
  STA ram_sfx_2    ; con_sfx_2_00
  STA ram_sfx_1    ; con_sfx_1_00
  STA ram_music_1    ; con_music_00
  LDY ram_0711_se
  LDA ram_music_2
  AND #$0C
  BEQ bra_F949
  INC ram_0711_se
  CPY #$30
  BCC bra_F94F
bra_F949
  TYA
  BEQ bra_F94F
  DEC ram_0711_se
bra_F94F
  STY $4011
  RTS



sub_F953_set_4000_4001
  STX $4000
  STY $4001
  RTS



sub_F95A_set_4004_4005
  STX $4004
  STY $4005
  RTS



sub_F961_set_4000_4001_4002x_4003x
  JSR sub_F953_set_4000_4001
sub_F964_set_4002x_4003x
  LDX #$00
bra_F966
  TAY
  LDA tbl_FF01,Y
  BEQ bra_F977_RTS
; 4002 4006 400A
  STA $4002,X
  LDA tbl_FF00,Y
  ORA #$08
; 4003 4007 400B
  STA $4003,X
bra_F977_RTS
  RTS



sub_F978_set_4004_4005_4006_4007
  JSR sub_F95A_set_4004_4005
sub_F97B_set_4006_4007
  LDX #$04
  BNE bra_F966    ; jmp



sub_F97F_set_400A_400B
  LDX #$08
  BNE bra_F966    ; jmp



sub_F983
  TAX
  ROR
  TXA
  ROL
  ROL
  ROL
  AND #$07
  CLC
  ADC ram_00F5_se
  TAY
  LDA tbl_FF40,Y
  RTS



tbl_F993
  db $98   ; 00 
  db $5A   ; 01 
  db $99   ; 02 
  db $9B   ; 03 
  db $5A   ; 04 
  db $5C   ; 05 
  db $9B   ; 06 
  db $5D   ; 07 
  db $9C   ; 08 
  db $9E   ; 09 
  db $5D   ; 0A 
  db $5F   ; 0B 



tbl_F99F
  db $BF   ; 00 
  db $BE   ; 01 
  db $AA   ; 02 
  db $A9   ; 03 
  db $98   ; 04 
  db $97   ; 05 
  db $87   ; 06 
  db $86   ; 07 
  db $78   ; 08 
  db $77   ; 09 
  db $6B   ; 0A 
  db $6A   ; 0B 



bra_F9AB_FF_01
  STY ram_copy_sfx_3
  LDA #$2F
  STA ram_00F4
bra_F9B1_F0_01
  LDA ram_00F4
  LSR
  LSR
  TAY
  LDA tbl_F99F,Y
  STA $4002
  LDA #$08
  STA $4003
  LDX tbl_F993,Y
  LDY #$81
  BNE bra_FA2F    ; jmp
bra_F9C8_FF_02
  STY ram_copy_sfx_3
  LDA #$20
  STA ram_00F4
  BNE bra_F9D6    ; jmp
bra_F9D0_F0_02
  LDA ram_00F4
  CMP #$1B
  BNE bra_FA32
bra_F9D6
  LDX #$88    ; 4000
  LDY #$D3    ; 4001
  LDA #$00
  JSR sub_F961_set_4000_4001_4002x_4003x
  LDA #$20
  JSR sub_F97F_set_400A_400B
  LDA #$1C
  STA $4008
  BNE bra_FA32    ; jmp



sub_F9EB_play_sfx_3
  LDY ram_sfx_3
  LDA ram_copy_sfx_3
  LSR ram_sfx_3
  BCS bra_F9AB_FF_01
  LSR
  BCS bra_F9B1_F0_01
  LSR ram_sfx_3
  BCS bra_F9C8_FF_02
  LSR
  BCS bra_F9D0_F0_02
  LSR ram_sfx_3
  BCS bra_FA0C_FF_04
  LSR
  BCS bra_FA1B_F0_04
  LSR ram_sfx_3
  BCS bra_FA40_FF_08
  LSR
  BCS bra_FA4A_F0_08
  RTS
bra_FA0C_FF_04
  STY ram_copy_sfx_3
  LDA #$28
  STA ram_00F4
  LDX #$9A    ; 4000
  LDY #$A7    ; 4001
  LDA #$36
  JSR sub_F961_set_4000_4001_4002x_4003x
bra_FA1B_F0_04
  LDA ram_00F4
  CMP #$25
  BNE bra_FA27
  LDX #$47
  LDY #$F6
  BNE bra_FA2F    ; jmp
bra_FA27
  CMP #$20
  BNE bra_FA32
  LDY #$BC
  LDX #$4C
bra_FA2F
  JSR sub_F953_set_4000_4001
bra_FA32
  DEC ram_00F4
  BNE bra_FA3F_RTS
sub_FA36
  LDA #$00
  STA ram_copy_sfx_3
sub_FA3A
  LDA #$90
  STA $4000
bra_FA3F_RTS
  RTS
bra_FA40_FF_08
  STY ram_copy_sfx_3
  LDA #$0B
  STA ram_00F4
  LDA #$57
  BNE bra_FA52    ; jmp
bra_FA4A_F0_08
  LDA ram_00F4
  CMP #$07
  BNE bra_FA32
  LDA #$02
bra_FA52
  STA $4002
  LDA #$3B
  STA $4003
  LDX #$BD
  LDY #$8A
  BNE bra_FA2F    ; jmp



tbl_FA60
  db $20   ; 01 
  db $1E   ; 02 
  db $1C   ; 03 
  db $1A   ; 04 



bra_FA64_FE_01
  STY ram_copy_sfx_2
  LDA #$30
  STA ram_0712_se
bra_FA6B_F1_01
  LDA ram_0712_se
  LDX #$03
bra_FA70_loop
  LSR
  BCS bra_FAB5
  DEX
  BNE bra_FA70_loop
  TAY
; bzk bug, this refs to 0x003A74/0x003A75 when Y = 05/06
  LDA tbl_FA60 - $01,Y
  LDY #$8B
bra_FA7C
  LDX #$B8
  JSR sub_F978_set_4004_4005_4006_4007
  BNE bra_FAB5
bra_FA83_FE_02
  STY ram_copy_sfx_2
  LDA #$5E
  STA ram_0712_se
  LDA #$91
  STA ram_0709_se
  LDA #$3C
  JSR sub_F97B_set_4006_4007
bra_FA94_F1_02
  LDA ram_0709_se
  STA $4004
  CMP #$95
  BEQ bra_FAA1
  INC ram_0709_se
bra_FAA1
  LDA ram_0712_se
  AND #$07
  BNE bra_FAAC
  LDA #$9F
  BNE bra_FAB2    ; jmp
bra_FAAC
  CMP #$06
  BNE bra_FAB5
  LDA #$A3
bra_FAB2
  STA $4005
bra_FAB5
bra_FAB5_F1_04
bra_FAB5_F1_10
loc_FAB5
  DEC ram_0712_se
  BNE bra_FAC3_RTS
  LDA #$00
  STA ram_copy_sfx_2
  LDA #$90
  STA $4004
bra_FAC3_RTS
  RTS



sub_FAC4_play_sfx_2
  LDY ram_sfx_2
  LDA ram_copy_sfx_2
  LSR ram_sfx_2
  BCS bra_FA64_FE_01
  LSR
  BCS bra_FA6B_F1_01
  LSR ram_sfx_2
  BCS bra_FA83_FE_02
  LSR
  BCS bra_FA94_F1_02
  LSR ram_sfx_2
  BCS bra_FAEC_FE_04
  LSR
  BCS bra_FAB5_F1_04
  LSR
  BCS bra_FB09_F1_08
  LSR ram_sfx_2
  BCS bra_FAF9_FE_08
  LSR ram_sfx_2
  BCS bra_FB17_FE_10
  LSR
  BCS bra_FAB5_F1_10
  RTS
bra_FAEC_FE_04
  STY ram_copy_sfx_2
  LDA #$20
  STA ram_0712_se
  LDA #$18
  LDY #$B3
  BNE bra_FA7C    ; jmp
bra_FAF9_FE_08
  STY ram_copy_sfx_2
  LDA #$08
  STA ram_0712_se
  LDX #$1F
  LDY #$7F
  LDA #$04
  JSR sub_F978_set_4004_4005_4006_4007
bra_FB09_F1_08
  LDA ram_0712_se
  CMP #$04
  BNE bra_FAB5
  LDA #$A9
  STA $4006
  BNE bra_FAB5    ; jmp
bra_FB17_FE_10
  STY ram_copy_sfx_2
  LDA #$18
  STA ram_0712_se
  LDX #$1F
  LDY #$92
  LDA #$3E
  JSR sub_F978_set_4004_4005_4006_4007
  LDA #$08
  STA $4007
  LDA ram_0712_se
  CMP #$10
  BNE bra_FB38
  LDA #$32
  STA $4006
bra_FB38
  JMP loc_FAB5



tbl_FB3B
  db $16   ; 00 
  db $10   ; 01 
  db $17   ; 02 
  db $18   ; 03 
  db $19   ; 04 
  db $1A   ; 05 
  db $1B   ; 06 
  db $1F   ; 07 
  db $1F   ; 08 
  db $1F   ; 09 
  db $1F   ; 0A 
  db $1C   ; 0B 
  db $1A   ; 0C 
  db $17   ; 0D 
  db $15   ; 0E 
  db $14   ; 0F 



tbl_FB4B
  db $02   ; 00 
  db $04   ; 10 
  db $06   ; 20 
  db $08   ; 30 
  db $0A   ; 40 
  db $0B   ; 50 
  db $0C   ; 60 



tbl_FB52
  db $0D   ; 00 
  db $10   ; 01 
  db $14   ; 02 
  db $19   ; 03 
  db $1B   ; 04 
  db $1D   ; 05 
  db $1F   ; 06 
  db $1F   ; 07 
  db $13   ; 08 
  db $15   ; 09 
  db $1A   ; 0A 
  db $1C   ; 0B 
  db $1E   ; 0C 
  db $1F   ; 0D 
  db $1F   ; 0E 
  db $1F   ; 0F 



tbl_FB62
  db $1F   ; 00 
  db $06   ; 01 
  db $0A   ; 02 
  db $0B   ; 03 
  db $09   ; 04 
  db $0C   ; 05 
  db $0F   ; 06 
  db $0E   ; 07 



tbl_FB6A
  db $0F   ; 00 
  db $10   ; 01 
  db $1F   ; 02 
  db $1F   ; 03 



tbl_FB6E
  db $1F   ; 00 
  db $09   ; 01 
  db $0B   ; 02 



bra_FB71_FC_01
  STY ram_copy_sfx_1
  LDA #$7F
  STA ram_070E_se
bra_FB78_F2_01
  LDA ram_070E_se
  LSR
  LSR
  LSR
  LSR
  TAY
  LDX tbl_FB4B,Y
  LDA ram_070E_se
  AND #$0F
  TAY
  LDA tbl_FB3B,Y
bra_FB8C
loc_FB8C
  STA $400C
  STX $400E
  LDA #$08
  STA $400F
  DEC ram_070E_se
  BNE bra_FBA0_RTS
  LDA #$00
  STA ram_copy_sfx_1
bra_FBA0_RTS
  RTS



sub_FBA1_play_sfx_1
  LDY ram_sfx_1
  LDA ram_copy_sfx_1
  LSR ram_sfx_1
  BCS bra_FB71_FC_01
  LSR
  BCS bra_FB78_F2_01
  LSR ram_sfx_1
  BCS bra_FBBB_FC_02
  LSR
  BCS bra_FBCB_FF_02
  LSR ram_sfx_1
  BCS bra_FBDB_FC_04
  LSR
  BCS bra_FBEB_FF_04
  RTS
bra_FBBB_FC_02
  STY ram_copy_sfx_1
  LDA #$10
  STA ram_070E_se
  LDA ram_copy_sfx_3
  CMP #$04
  BNE bra_FBCB
  JSR sub_FA36
bra_FBCB_FF_02
bra_FBCB
  LDA ram_070E_se
  LSR
  TAY
  LDX tbl_FB62,Y
  LDY ram_070E_se
  LDA tbl_FB52,Y
  BNE bra_FB8C    ; jmp
bra_FBDB_FC_04
  STY ram_copy_sfx_1
  LDA #$04
  STA ram_070E_se
  LDA ram_copy_sfx_3
  CMP #$04
  BNE bra_FBEB
  JSR sub_FA36
bra_FBEB_FF_04
bra_FBEB
  LDA ram_070E_se
  LSR
  TAY
  LDX tbl_FB6E,Y
  LDY ram_070E_se
  LDA tbl_FB6A,Y
  JMP loc_FB8C



sub_FBFC_initialize_music
  LDA ram_music_1
  BNE bra_FC05
  LDA ram_music_2
  BNE bra_FC51
  RTS
bra_FC05
  CMP #con_music_pause
  BNE bra_FC11
  LDA ram_music_2
  AND #$0E
  STA ram_00FD_music
  LDA ram_music_1
bra_FC11
  STA ram_music_2
  LDY #$00
  STY ram_00F8_se
bra_FC17_loop
  INY
  LSR
  BCC bra_FC17_loop
  LDA tbl_FD22_offset - $01,Y
  TAY
  LDA tbl_FD2A - $08,Y
  STA ram_00F5_se
  LDA tbl_FD2A - $07,Y
  STA ram_00F6_se_data
  LDA tbl_FD2A - $06,Y
  STA ram_00F6_se_data + $01
  LDA tbl_FD2A - $05,Y
  STA ram_00FA_se
  LDA tbl_FD2A - $04,Y
  STA ram_00F9_se
  LDA tbl_FD2A - $03,Y
  STA ram_0705_useless
  LDA #$01
  STA ram_0701_se
  STA ram_0703_se
  STA ram_0704_se
  STA ram_0706_useless
  LDA #$7F
  STA ram_0700_se
bra_FC51
  DEC ram_0701_se
  BNE bra_FCAC
  LDY ram_00F8_se
  INC ram_00F8_se
  LDA (ram_00F6_se_data),Y
  BNE bra_FC84
  LDA ram_music_2
  CMP #con_music_unpause
  BNE bra_FC68
  LDA ram_00FD_music
  BNE bra_FC11
bra_FC68
  CMP #con_music_background
  BEQ bra_FC11
  AND #$0C
  BEQ bra_FC79
  LSR
  CMP #$04
  BEQ bra_FC11
  LDA #con_music_08
  BNE bra_FC11    ; jmp
bra_FC79
  LDA #con_music_00
  STA ram_music_2
  JSR sub_FA3A
  STA $4004
  RTS
bra_FC84
  JSR sub_F983
  STA ram_0701_se
  LDA ram_copy_sfx_2
  BNE bra_FCC4
  TXA
  AND #$3E
  JSR sub_F97B_set_4006_4007
  TAY
  BEQ bra_FC99
  LDY #$1F
bra_FC99
  STY ram_0702_se
  LDX #$84
  LDA ram_0701_se
  CMP #$10
  BCS bra_FCA7
  LDX #$82
bra_FCA7
  LDY #$7F
  JSR sub_F95A_set_4004_4005
bra_FCAC
  LDA ram_copy_sfx_2
  BNE bra_FCC4
  LDA ram_music_2
  AND #$0C
  BEQ bra_FCC4
  LDY ram_0702_se
  BEQ bra_FCBE
  DEC ram_0702_se
bra_FCBE
  LDA tbl_FFD9,Y
  STA $4004
bra_FCC4
  LDY ram_00F9_se
  BEQ bra_FCFA
  DEC ram_0703_se
  BNE bra_FCFA
bra_FCCD_loop
  LDY ram_00F9_se
  INC ram_00F9_se
  LDA (ram_00F6_se_data),Y
  BNE bra_FCE0
  LDY ram_00F9_se
  INC ram_00F9_se
  LDA (ram_00F6_se_data),Y
  STA ram_0700_se
  BNE bra_FCCD_loop
bra_FCE0
  JSR sub_F983
  STA ram_0703_se
  TXA
  AND #$3E
  JSR sub_F964_set_4002x_4003x
  BNE bra_FCF2
  LDX #$10
  BNE bra_FCF4    ; jmp
bra_FCF2
  LDX #$06
bra_FCF4
  LDY ram_0700_se
  JSR sub_F953_set_4000_4001
bra_FCFA
  LDY ram_00FA_se
  BEQ bra_FD21_RTS
  DEC ram_0704_se
  BNE bra_FD21_RTS
  INC ram_00FA_se
  LDA (ram_00F6_se_data),Y
  JSR sub_F983
  STA ram_0704_se
  CLC
  ADC #$FE
  CMP #$0E
  BCC bra_FD16_not_overflow
  LDA #$0E
bra_FD16_not_overflow
  ASL
  ASL
  STA $4008
  TXA
  AND #$3E
  JSR sub_F97F_set_400A_400B
bra_FD21_RTS
  RTS



tbl_FD22_offset
  db $21   ; 01 
  db $08   ; 02 
  db $0D   ; 04 
  db $12   ; 08 
  db $26   ; 10 
  db $17   ; 20 
  db $17   ; 40 
  db $1C   ; 80 



tbl_FD2A
; 08
  db $06   ; 
  dw _off002_FE4A_02
  db off_FE53_02_1 - _off002_FE4A_02
  db off_FE4A_02_2 - _off002_FE4A_02
; 0D
  db $06   ; 
  dw _off002_FD4D_04
  db off_FDCF_04_1 - _off002_FD4D_04
  db off_FD8F_04_2 - _off002_FD4D_04
; 12
  db $06   ; 
  dw _off002_FDEF_08
  db off_FE38_08_1 - _off002_FDEF_08
  db off_FE14_08_2 - _off002_FDEF_08
; 17
  db $00   ; 
  dw _off002_FFD2_20_40
  db off_FFD2_20_40_1 - _off002_FFD2_20_40
  db off_FFD2_20_40_2 - _off002_FFD2_20_40
; 1C
  db $00   ; 
  dw _off002_FFD8_80
  db off_FFD8_80_1 - _off002_FFD8_80
  db off_FFD8_80_2 - _off002_FFD8_80
; 21
  db $06   ; 
  dw _off002_FEB9_01
  db off_FF4E_01_1 - _off002_FEB9_01
  db off_FEDD_01_2 - _off002_FEB9_01
; 26
  db $06   ; 
  dw _off002_FF71_10
  db off_FFB1_10_1 - _off002_FF71_10
  db off_FF99_10_2 - _off002_FF71_10



_off002_FD4D_04
  db $42   ; 
  db $02   ; 
  db $04   ; 
  db $82   ; 
  db $04   ; 
  db $30   ; 
  db $04   ; 
  db $30   ; 
  db $44   ; 
  db $02   ; 
  db $04   ; 
  db $4B   ; 
  db $84   ; 
  db $02   ; 
  db $28   ; 
  db $AF   ; 
  db $E9   ; 
  db $EF   ; 
  db $42   ; 
  db $02   ; 
  db $04   ; 
  db $82   ; 
  db $84   ; 
  db $44   ; 
  db $02   ; 
  db $04   ; 
  db $4B   ; 
  db $84   ; 
  db $02   ; 
  db $28   ; 
  db $AF   ; 
  db $E9   ; 
  db $EF   ; 
  db $82   ; 
  db $45   ; 
  db $6D   ; 
  db $8A   ; 
  db $48   ; 
  db $02   ; 
  db $04   ; 
  db $6E   ; 
  db $02   ; 
  db $28   ; 
  db $66   ; 
  db $02   ; 
  db $24   ; 
  db $60   ; 
  db $02   ; 
  db $E2   ; 
  db $28   ; 
  db $AB   ; 
  db $ED   ; 
  db $C5   ; 
  db $91   ; 
  db $CF   ; 
  db $CB   ; 
  db $85   ; 
  db $EF   ; 
  db $E9   ; 
  db $A7   ; 
  db $E5   ; 
  db $E1   ; 
  db $9B   ; 
  db $E1   ; 
  db $E5   ; 
  db $00   ; 



off_FD8F_04_2
  db $42   ; 
  db $02   ; 
  db $22   ; 
  db $82   ; 
  db $A2   ; 
  db $62   ; 
  db $02   ; 
  db $22   ; 
  db $63   ; 
  db $A2   ; 
  db $02   ; 
  db $1E   ; 
  db $A5   ; 
  db $DF   ; 
  db $E5   ; 
  db $42   ; 
  db $02   ; 
  db $22   ; 
  db $82   ; 
  db $A2   ; 
  db $62   ; 
  db $02   ; 
  db $22   ; 
  db $63   ; 
  db $A2   ; 
  db $02   ; 
  db $1E   ; 
  db $A5   ; 
  db $DF   ; 
  db $E5   ; 
  db $82   ; 
  db $61   ; 
  db $61   ; 
  db $AC   ; 
  db $6C   ; 
  db $02   ; 
  db $2C   ; 
  db $68   ; 
  db $02   ; 
  db $24   ; 
  db $60   ; 
  db $02   ; 
  db $1E   ; 
  db $5A   ; 
  db $02   ; 
  db $1A   ; 
  db $43   ; 
  db $02   ; 
  db $24   ; 
  db $A5   ; 
  db $E7   ; 
  db $ED   ; 
  db $8B   ; 
  db $C9   ; 
  db $C5   ; 
  db $AD   ; 
  db $E9   ; 
  db $E1   ; 
  db $A1   ; 
  db $DF   ; 
  db $DB   ; 
  db $B3   ; 
  db $DB   ; 
  db $DF   ; 



off_FDCF_04_1
  db $9A   ; 
  db $A2   ; 
  db $A8   ; 
  db $AC   ; 
  db $AE   ; 
  db $AC   ; 
  db $A8   ; 
  db $A2   ; 
  db $9A   ; 
  db $A2   ; 
  db $A8   ; 
  db $AC   ; 
  db $AE   ; 
  db $AC   ; 
  db $A8   ; 
  db $A2   ; 
  db $A4   ; 
  db $AC   ; 
  db $84   ; 
  db $88   ; 
  db $8A   ; 
  db $88   ; 
  db $84   ; 
  db $AC   ; 
  db $9A   ; 
  db $A2   ; 
  db $A8   ; 
  db $AC   ; 
  db $AE   ; 
  db $AC   ; 
  db $A8   ; 
  db $A2   ; 



_off002_FDEF_08
  db $A7   ; 
  db $E9   ; 
  db $E9   ; 
  db $A7   ; 
  db $E9   ; 
  db $E9   ; 
  db $87   ; 
  db $C9   ; 
  db $C9   ; 
  db $87   ; 
  db $C9   ; 
  db $C9   ; 
  db $92   ; 
  db $8E   ; 
  db $4A   ; 
  db $02   ; 
  db $84   ; 
  db $04   ; 
  db $44   ; 
  db $02   ; 
  db $A2   ; 
  db $02   ; 
  db $A4   ; 
  db $A6   ; 
  db $A9   ; 
  db $E7   ; 
  db $E9   ; 
  db $AB   ; 
  db $E9   ; 
  db $EB   ; 
  db $AD   ; 
  db $EB   ; 
  db $ED   ; 
  db $B1   ; 
  db $ED   ; 
  db $F1   ; 
  db $00   ; 



off_FE14_08_2
  db $9F   ; 
  db $DF   ; 
  db $DF   ; 
  db $9F   ; 
  db $DF   ; 
  db $DF   ; 
  db $A7   ; 
  db $E7   ; 
  db $E7   ; 
  db $AD   ; 
  db $ED   ; 
  db $ED   ; 
  db $88   ; 
  db $88   ; 
  db $44   ; 
  db $02   ; 
  db $AC   ; 
  db $2C   ; 
  db $68   ; 
  db $02   ; 
  db $9A   ; 
  db $02   ; 
  db $9E   ; 
  db $A0   ; 
  db $BB   ; 
  db $F9   ; 
  db $FB   ; 
  db $9B   ; 
  db $FB   ; 
  db $DB   ; 
  db $9D   ; 
  db $DB   ; 
  db $DD   ; 
  db $A9   ; 
  db $E5   ; 
  db $E9   ; 



off_FE38_08_1
  db $A8   ; 
  db $B0   ; 
  db $88   ; 
  db $90   ; 
  db $98   ; 
  db $98   ; 
  db $54   ; 
  db $02   ; 
  db $8E   ; 
  db $0E   ; 
  db $9A   ; 
  db $A2   ; 
  db $A4   ; 
  db $A6   ; 
  db $A8   ; 
  db $AA   ; 
  db $AC   ; 
  db $B0   ; 



_off002_FE4A_02
off_FE4A_02_2
  db $03   ; 
  db $03   ; 
  db $03   ; 
  db $03   ; 
  db $03   ; 
  db $03   ; 
  db $03   ; 
  db $03   ; 
  db $00   ; 



off_FE53_02_1
  db $68   ; 
  db $02   ; 
  db $22   ; 
  db $64   ; 
  db $02   ; 
  db $28   ; 
  db $42   ; 
  db $02   ; 
  db $04   ; 
  db $30   ; 
  db $04   ; 
  db $30   ; 
  db $04   ; 
  db $68   ; 
  db $02   ; 
  db $22   ; 
  db $64   ; 
  db $02   ; 
  db $28   ; 
  db $42   ; 
  db $02   ; 
  db $04   ; 
  db $30   ; 
  db $04   ; 
  db $30   ; 
  db $04   ; 
  db $6C   ; 
  db $02   ; 
  db $24   ; 
  db $68   ; 
  db $02   ; 
  db $2C   ; 
  db $42   ; 
  db $02   ; 
  db $08   ; 
  db $06   ; 
  db $08   ; 
  db $06   ; 
  db $08   ; 
  db $6C   ; 
  db $02   ; 
  db $24   ; 
  db $68   ; 
  db $02   ; 
  db $2C   ; 
  db $42   ; 
  db $02   ; 
  db $08   ; 
  db $06   ; 
  db $08   ; 
  db $06   ; 
  db $08   ; 
  db $70   ; 
  db $02   ; 
  db $28   ; 
  db $6C   ; 
  db $02   ; 
  db $30   ; 
  db $42   ; 
  db $02   ; 
  db $0E   ; 
  db $0C   ; 
  db $0E   ; 
  db $0C   ; 
  db $0E   ; 
  db $70   ; 
  db $02   ; 
  db $28   ; 
  db $6C   ; 
  db $02   ; 
  db $30   ; 
  db $42   ; 
  db $02   ; 
  db $0E   ; 
  db $0C   ; 
  db $0E   ; 
  db $0C   ; 
  db $0E   ; 
  db $8D   ; 
  db $C5   ; 
  db $E9   ; 
  db $8D   ; 
  db $C5   ; 
  db $E9   ; 
  db $8F   ; 
  db $C9   ; 
  db $ED   ; 
  db $8F   ; 
  db $C9   ; 
  db $ED   ; 
  db $91   ; 
  db $C9   ; 
  db $C5   ; 
  db $91   ; 
  db $C9   ; 
  db $C5   ; 
  db $93   ; 
  db $CF   ; 
  db $C9   ; 
  db $B1   ; 
  db $EF   ; 
  db $ED   ; 



_off002_FEB9_01
  db $5A   ; 
  db $5C   ; 
  db $5E   ; 
  db $60   ; 
  db $A2   ; 
  db $69   ; 
  db $67   ; 
  db $6B   ; 
  db $A8   ; 
  db $84   ; 
  db $68   ; 
  db $66   ; 
  db $02   ; 
  db $24   ; 
  db $60   ; 
  db $02   ; 
  db $9A   ; 
  db $1A   ; 
  db $9D   ; 
  db $DF   ; 
  db $E1   ; 
  db $A3   ; 
  db $E5   ; 
  db $E7   ; 
  db $A9   ; 
  db $EB   ; 
  db $ED   ; 
  db $F0   ; 
  db $42   ; 
  db $02   ; 
  db $04   ; 
  db $4A   ; 
  db $02   ; 
  db $CC   ; 
  db $02   ; 
  db $00   ; 



off_FEDD_01_2
  db $72   ; 
  db $74   ; 
  db $76   ; 
  db $78   ; 
  db $BA   ; 
  db $5F   ; 
  db $5D   ; 
  db $61   ; 
  db $9E   ; 
  db $A8   ; 
  db $5E   ; 
  db $5C   ; 
  db $02   ; 
  db $1A   ; 
  db $78   ; 
  db $02   ; 
  db $B2   ; 
  db $38   ; 
  db $B1   ; 
  db $DB   ; 
  db $DD   ; 
  db $9F   ; 
  db $E1   ; 
  db $E3   ; 
  db $A5   ; 
  db $E7   ; 
  db $E9   ; 
  db $EC   ; 
  db $42   ; 
  db $02   ; 
  db $28   ; 
  db $6E   ; 
  db $02   ; 
  db $F0   ; 
  db $02   ; 



tbl_FF00
  db $03   ; 
tbl_FF01
  db $57   ; 
  db $00   ; 
  db $00   ; 
  db $00   ; 
  db $D4   ; 
  db $00   ; 
  db $C8   ; 
  db $00   ; 
  db $BD   ; 
  db $00   ; 
  db $B2   ; 
  db $00   ; 
  db $A8   ; 
  db $00   ; 
  db $9F   ; 
  db $00   ; 
  db $96   ; 
  db $00   ; 
  db $8D   ; 
  db $00   ; 
  db $7E   ; 
  db $00   ; 
  db $76   ; 
  db $00   ; 
  db $70   ; 
  db $01   ; 
  db $AB   ; 
  db $01   ; 
  db $93   ; 
  db $01   ; 
  db $7C   ; 
  db $01   ; 
  db $67   ; 
  db $01   ; 
  db $52   ; 
  db $01   ; 
  db $3F   ; 
  db $01   ; 
  db $2D   ; 
  db $01   ; 
  db $1C   ; 
  db $01   ; 
  db $0C   ; 
  db $00   ; 
  db $FD   ; 
  db $00   ; 
  db $EE   ; 
  db $00   ; 
  db $E1   ; 
  db $02   ; 
  db $3A   ; 
  db $02   ; 
  db $1A   ; 
  db $01   ; 
  db $FC   ; 
  db $01   ; 
  db $DF   ; 
  db $01   ; 
  db $C4   ; 
  db $00   ; 
  db $0E   ; 
  db $04   ; 
  db $75   ; 



tbl_FF40
; 00 
  db $05   ; 00 
  db $0A   ; 01 
  db $14   ; 02 
  db $28   ; 03 
  db $50   ; 04 
  db $1E   ; 05 
; 06 
  db $05   ; 00 
  db $0A   ; 01 
  db $14   ; 02 
  db $28   ; 03 
  db $50   ; 04 
  db $1E   ; 05 
  db $06   ; 06 
  db $07   ; 07 



off_FF4E_01_1
  db $5A   ; 
  db $5C   ; 
  db $5E   ; 
  db $60   ; 
  db $A2   ; 
  db $69   ; 
  db $67   ; 
  db $6B   ; 
  db $A8   ; 
  db $84   ; 
  db $68   ; 
  db $66   ; 
  db $02   ; 
  db $24   ; 
  db $60   ; 
  db $02   ; 
  db $9A   ; 
  db $28   ; 
  db $AB   ; 
  db $ED   ; 
  db $EF   ; 
  db $B1   ; 
  db $C5   ; 
  db $C7   ; 
  db $89   ; 
  db $CB   ; 
  db $CD   ; 
  db $D0   ; 
  db $42   ; 
  db $02   ; 
  db $04   ; 
  db $4A   ; 
  db $02   ; 
  db $CC   ; 
  db $02   ; 



_off002_FF71_10
  db $A3   ; 
  db $E3   ; 
  db $E3   ; 
  db $64   ; 
  db $02   ; 
  db $A6   ; 
  db $28   ; 
  db $2A   ; 
  db $28   ; 
  db $2A   ; 
  db $28   ; 
  db $A7   ; 
  db $E9   ; 
  db $C5   ; 
  db $4A   ; 
  db $02   ; 
  db $84   ; 
  db $2E   ; 
  db $A9   ; 
  db $E7   ; 
  db $E5   ; 
  db $A3   ; 
  db $E3   ; 
  db $E3   ; 
  db $64   ; 
  db $02   ; 
  db $A6   ; 
  db $28   ; 
  db $2A   ; 
  db $28   ; 
  db $2A   ; 
  db $28   ; 
  db $52   ; 
  db $02   ; 
  db $0E   ; 
  db $4A   ; 
  db $02   ; 
  db $C4   ; 
  db $02   ; 
  db $00   ; 



off_FF99_10_2
  db $9B   ; 
  db $DB   ; 
  db $DB   ; 
  db $5E   ; 
  db $02   ; 
  db $9A   ; 
  db $9E   ; 
  db $02   ; 
  db $03   ; 
  db $9B   ; 
  db $DB   ; 
  db $DB   ; 
  db $5E   ; 
  db $02   ; 
  db $9A   ; 
  db $9E   ; 
  db $02   ; 
  db $48   ; 
  db $02   ; 
  db $08   ; 
  db $44   ; 
  db $02   ; 
  db $E8   ; 
  db $02   ; 



off_FFB1_10_1
  db $A9   ; 
  db $E9   ; 
  db $E9   ; 
  db $6C   ; 
  db $02   ; 
  db $AA   ; 
  db $B0   ; 
  db $02   ; 
  db $A7   ; 
  db $E9   ; 
  db $C5   ; 
  db $4A   ; 
  db $02   ; 
  db $84   ; 
  db $2E   ; 
  db $A9   ; 
  db $E7   ; 
  db $E5   ; 
  db $A9   ; 
  db $E9   ; 
  db $E9   ; 
  db $6C   ; 
  db $02   ; 
  db $AA   ; 
  db $B0   ; 
  db $02   ; 
  db $58   ; 
  db $02   ; 
  db $18   ; 
  db $54   ; 
  db $02   ; 
  db $CC   ; 
  db $02   ; 



_off002_FFD2_20_40
off_FFD2_20_40_1
off_FFD2_20_40_2
  db $28   ; 
  db $26   ; 
  db $28   ; 
  db $26   ; 
  db $E8   ; 
  db $00   ; 



_off002_FFD8_80
off_FFD8_80_1
off_FFD8_80_2
  db $00   ; 



tbl_FFD9
  db $50   ; 00 
  db $51   ; 01 
  db $51   ; 02 
  db $51   ; 03 
  db $51   ; 04 
  db $51   ; 05 
  db $51   ; 06 
  db $51   ; 07 
  db $51   ; 08 
  db $52   ; 09 
  db $52   ; 0A 
  db $52   ; 0B 
  db $52   ; 0C 
  db $52   ; 0D 
  db $52   ; 0E 
  db $53   ; 0F 
  db $53   ; 10 
  db $53   ; 11 
  db $53   ; 12 
  db $53   ; 13 
  db $54   ; 14 
  db $54   ; 15 
  db $54   ; 16 
vec_FFF0_IRQ
  db $54   ; 17 
  db $55   ; 18 
  db $55   ; 19 
  db $55   ; 1A 
  db $56   ; 1B 
  db $56   ; 1C 
  db $56   ; 1D 
  db $56   ; 1E 
  db $57   ; 1F 


; bzk garbage?
  db $FF   ; 



;.out .sprintf("Free bytes in bank FF 0x%04X [%d]", ($FFFA - *), ($FFFA - *))



;.segment "VECTORS"
  dw vec_C076_NMI
  dw vec_C014_RESET
  dw vec_FFF0_IRQ

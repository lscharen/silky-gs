; Contra NES PRG bank 2
            mx    %11
C07_EMBED_BANK equ 2
ROMBase EXT
            put   ../../../core/Defs.s
            use   equates.inc
            ds    $5000-*
            put   Config.s
            put   ../../../ppu/ppu_reg_vars_ext.s
            put   ../../../rom/rom_inject.s
            put   helpers.s
            ds    $8000-*
; Contra US Disassembly - v1.4
; https://github.com/vermiceli/nes-contra-us
; Bank 2 starts with RLE-encoded level data (graphic super-tiles for the level
; screens).  It then contains compressed tile data and alternate tile data and
; occasional attribute table data.  Then, bank 2 contains logic for setting the
; players' sprite based on player state.  Next, bank 2 contains the level
; headers, which define specifics about each level. Bank 2 then has the data
; that specifies which enemies are on which screen and their attributes.  Bank
; 2 also contains the soldier enemy generation code.



; import labels from bank 7

; import labels from bank 3


; export labels for bank 7

; Every PRG ROM bank starts with a single byte specifying which number it is
            db    $02    ; The PRG ROM bank number (2)

; pointer table for level 1 super tile data (#$0e * #$02 = #$1c bytes)
; each entry is a screen (256 pixels wide) worth of super-tile indexes
; CPU address $8001
level_1_supertiles_screen_ptr_table ENT
            dw    level_1_supertiles_screen_00    ; CPU address $801d
            dw    level_1_supertiles_screen_01    ; CPU address $8048
            dw    level_1_supertiles_screen_02    ; CPU address $8079
            dw    level_1_supertiles_screen_03    ; CPU address $80a7
            dw    level_1_supertiles_screen_04    ; CPU address $80cf
            dw    level_1_supertiles_screen_05    ; CPU address $80fc
            dw    level_1_supertiles_screen_06    ; CPU address $8118
            dw    level_1_supertiles_screen_07    ; CPU address $8132
            dw    level_1_supertiles_screen_08    ; CPU address $8149
            dw    level_1_supertiles_screen_09    ; CPU address $8169
            dw    level_1_supertiles_screen_0a    ; CPU address $8191
            dw    level_1_supertiles_screen_0b    ; CPU address $81b0
            dw    level_1_supertiles_screen_0c    ; CPU address $81d6
            dw    level_1_supertiles_screen_00    ; CPU address $801d

; beginning of level 1 data table
; each label is a screen of the level
; each byte is a super-tile block number (a block of 4x4 tiles)
; if bit 7 is set, the next byte is repeated using bits 0-6 as the repeat count
; each label expands to #$38 bytes for horizontal levels
; each label expands to #$40 bytes for vertical levels
; 8x = make x consecutive units of the following byte
; ef = make 6f consecutive units (max)
level_1_supertiles_screen_00 ENT
            db    $21,$20,$21,$2b,$23,$22,$23,$2a,$20,$54,$54,$2f,$27,$26,$27,$2e
            db    $54,$1c,$1d,$1e,$1c,$1e,$1c,$1c,$54,$87,$00,$0c,$84,$51,$83,$00
            db    $0d,$83,$09,$0a,$83,$51,$84,$10,$11,$83,$12

level_1_supertiles_screen_01 ENT
            db    $21,$20,$2b,$23,$22,$23,$22,$23,$54,$54,$2f,$27,$26,$27,$26,$27
            db    $83,$1d,$1e,$1c,$1d,$1d,$1e,$88,$00,$51,$51,$3b,$51,$51,$00,$00
            db    $51,$00,$51,$51,$00,$0b,$51,$51,$08,$17,$39,$39,$16,$14,$12,$12
            db    $13

level_1_supertiles_screen_02 ENT
            db    $22,$23,$22,$23,$2a,$54,$21,$54,$26,$27,$26,$27,$2e,$21,$20,$54
            db    $1e,$1c,$1d,$1d,$1c,$1d,$1d,$1e,$88,$00,$84,$51,$83,$04,$51,$09
            db    $0a,$51,$51,$83,$07,$08,$10,$11,$17,$39,$39,$16,$12,$13

level_1_supertiles_screen_03 ENT
            db    $21,$20,$54,$21,$20,$20,$54,$21,$54,$54,$21,$20,$21,$21,$83,$54
            db    $20,$54,$54,$1c,$83,$1d,$03,$29,$29,$37,$84,$00,$84,$0c,$84,$51
            db    $0e,$0c,$0c,$0d,$84,$09,$88,$10

level_1_supertiles_screen_04 ENT
            db    $83,$54,$20,$21,$54,$20,$2b,$20,$20,$54,$21,$83,$54,$2f,$1e,$84
            db    $54,$1c,$1d,$1d,$00,$03,$29,$29,$37,$83,$00,$51,$84,$0c,$51,$51
            db    $3e,$09,$0e,$0c,$0c,$0d,$09,$0a,$51,$86,$10,$11,$12

level_1_supertiles_screen_05 ENT
            db    $23,$2a,$20,$2d,$84,$2c,$27,$2e,$21,$85,$52,$1d,$1d,$1e,$8a,$00
            db    $8a,$51,$04,$87,$51,$07,$83,$12,$17,$83,$39,$16

level_1_supertiles_screen_06 ENT
            db    $88,$2c,$88,$52,$88,$00,$83,$51,$3e,$84,$51,$04,$3b,$86,$00,$07
            db    $0b,$86,$51,$12,$14,$83,$12,$17,$39,$18

level_1_supertiles_screen_07 ENT
            db    $88,$2c,$83,$52,$85,$28,$83,$00,$85,$52,$51,$3e,$87,$00,$8b,$51
            db    $00,$00,$51,$85,$00,$84,$51

level_1_supertiles_screen_08 ENT
            db    $88,$2c,$85,$52,$83,$28,$85,$00,$28,$52,$52,$00,$84,$51,$52,$00
            db    $00,$51,$51,$04,$51,$83,$00,$51,$00,$51,$07,$84,$51,$3b,$88,$51

level_1_supertiles_screen_09 ENT
            db    $88,$2c,$86,$28,$52,$52,$85,$28,$52,$00,$00,$28,$52,$52,$28,$28
            db    $00,$00,$51,$28,$00,$00,$52,$52,$51,$51,$04,$28,$51,$83,$00,$51
            db    $51,$07,$28,$00,$84,$51,$00,$51

level_1_supertiles_screen_0a ENT
            db    $2c,$87,$24,$28,$38,$86,$2c,$28,$52,$52,$86,$28,$00,$00,$84,$52
            db    $28,$28,$51,$85,$00,$28,$28,$86,$51,$52,$28,$84,$51,$83,$00

level_1_supertiles_screen_0b ENT
            db    $88,$24,$88,$2c,$86,$28,$52,$52,$84,$28,$52,$52,$00,$00,$28,$52
            db    $52,$28,$00,$00,$51,$04,$28,$00,$00,$28,$51,$3e,$51,$07,$28,$51
            db    $51,$28,$51,$51,$00,$00

level_1_supertiles_screen_0c ENT
            db    $83,$24,$25,$84,$54,$84,$2c,$19,$1a,$02,$1b,$52,$52,$28,$28,$01
            db    $05,$06,$32,$00,$00,$52,$28,$61,$64,$06,$32,$04,$04,$00,$52,$30
            db    $31,$33,$36,$07,$3e,$51,$00,$34,$35,$06,$32,$85,$00,$15,$3a,$32

; pointer table for level 2 (#$18 * #$02 = #$30 bytes)
level_2_supertiles_screen_ptr_table ENT
            dw    level_2_supertiles_screen_00    ; CPU address $8276 (0) Normal Room
            dw    level_2_supertiles_screen_01    ; CPU address $8300 (1)
            dw    level_2_supertiles_screen_02    ; CPU address $832e (2)
            dw    level_2_supertiles_screen_03    ; CPU address $835c (3)

            dw    level_2_supertiles_screen_00    ; CPU address $8276 (0) Normal Room
            dw    level_2_supertiles_screen_01    ; CPU address $8300 (1)
            dw    level_2_supertiles_screen_02    ; CPU address $832e (2)
            dw    level_2_supertiles_screen_03    ; CPU address $835c (3)

            dw    level_2_supertiles_screen_00    ; CPU address $8276 (0) Normal Room
            dw    level_2_supertiles_screen_01    ; CPU address $8300 (1)
            dw    level_2_supertiles_screen_02    ; CPU address $832e (2)
            dw    level_2_supertiles_screen_03    ; CPU address $835c (3)

            dw    level_2_supertiles_screen_04    ; CPU address $82d2 (4) Room with Holes for Roller Rows
            dw    level_2_supertiles_screen_01    ; CPU address $8300 (1)
            dw    level_2_supertiles_screen_02    ; CPU address $832e (2)
            dw    level_2_supertiles_screen_03    ; CPU address $835c (3)

            dw    level_2_supertiles_screen_05    ; CPU address $82a4 (5) Room with Big Core
            dw    level_2_supertiles_screen_01    ; CPU address $8300 (1)
            dw    level_2_supertiles_screen_02    ; CPU address $832e (2)
            dw    level_2_supertiles_screen_03    ; CPU address $835c (3)

            dw    level_2_supertiles_screen_00    ; CPU address $8276 (0) First Room again
            dw    level_2_supertiles_screen_01    ; CPU address $8300 (1)
            dw    level_2_supertiles_screen_02    ; CPU address $832e (2)
            dw    level_2_supertiles_screen_03    ; CPU address $835c (3)

; pointer table for level 4 (#$20 * #$02 = #$40 bytes)
level_4_supertiles_screen_ptr_table ENT
            dw    level_4_supertiles_screen_00    ; CPU address $838a (0)
            dw    level_4_supertiles_screen_01    ; CPU address $842c (1)
            dw    level_4_supertiles_screen_02    ; CPU address $8462 (2)
            dw    level_4_supertiles_screen_03    ; CPU address $8498 (3)

            dw    level_4_supertiles_screen_00    ; CPU address $838a (0)
            dw    level_4_supertiles_screen_01    ; CPU address $842c (1)
            dw    level_4_supertiles_screen_02    ; CPU address $8462 (2)
            dw    level_4_supertiles_screen_03    ; CPU address $8498 (3)

            dw    level_4_supertiles_screen_00    ; CPU address $838a (0)
            dw    level_4_supertiles_screen_01    ; CPU address $842c (1)
            dw    level_4_supertiles_screen_02    ; CPU address $8462 (2)
            dw    level_4_supertiles_screen_03    ; CPU address $8498 (3)

            dw    level_4_supertiles_screen_00    ; CPU address $838a (0)
            dw    level_4_supertiles_screen_01    ; CPU address $842c (1)
            dw    level_4_supertiles_screen_02    ; CPU address $8462 (2)
            dw    level_4_supertiles_screen_03    ; CPU address $8498 (3)

            dw    level_4_supertiles_screen_00    ; CPU address $838a (0)
            dw    level_4_supertiles_screen_01    ; CPU address $842c (1)
            dw    level_4_supertiles_screen_02    ; CPU address $8462 (2)
            dw    level_4_supertiles_screen_03    ; CPU address $8498 (3)

            dw    level_4_supertiles_screen_04    ; CPU address $83f6 (4)
            dw    level_4_supertiles_screen_01    ; CPU address $842c (1)
            dw    level_4_supertiles_screen_02    ; CPU address $8462 (2)
            dw    level_4_supertiles_screen_03    ; CPU address $8498 (3)

            dw    level_4_supertiles_screen_00    ; CPU address $838a (0)
            dw    level_4_supertiles_screen_01    ; CPU address $842c (1)
            dw    level_4_supertiles_screen_02    ; CPU address $8462 (2)
            dw    level_4_supertiles_screen_03    ; CPU address $8498 (3)

            dw    level_4_supertiles_screen_05    ; CPU address $83c0 (5)
            dw    level_4_supertiles_screen_01    ; CPU address $842c (1)
            dw    level_4_supertiles_screen_02    ; CPU address $8462 (2)
            dw    level_4_supertiles_screen_03    ; CPU address $8498 (3)

level_2_supertiles_screen_00 ENT
            db    $62,$86,$61,$63,$60,$04,$05,$06,$07,$01,$02,$5e,$60,$08,$09,$69
            db    $0c,$0b,$03,$5e,$60,$10,$0d,$6a,$6f,$0f,$10,$5e,$60,$15,$16,$14
            db    $14,$12,$13,$5e,$60,$18,$84,$11,$17,$5e,$5d,$86,$5f,$5d

level_2_supertiles_screen_05 ENT
            db    $62,$86,$61,$63,$60,$04,$05,$06,$07,$01,$02,$5e,$60,$08,$09,$6b
            db    $6e,$0b,$03,$5e,$60,$10,$0d,$6c,$6d,$0f,$10,$5e,$60,$15,$16,$14
            db    $14,$12,$13,$5e,$60,$18,$84,$11,$17,$5e,$5d,$86,$5f,$5d

level_2_supertiles_screen_04 ENT
            db    $62,$86,$61,$63,$60,$04,$05,$06,$07,$01,$02,$5e,$60,$08,$09,$69
            db    $0c,$0b,$03,$5e,$60,$10,$0d,$70,$71,$0f,$10,$5e,$60,$15,$16,$14
            db    $14,$12,$13,$5e,$60,$18,$84,$11,$17,$5e,$5d,$86,$5f,$5d

level_2_supertiles_screen_01 ENT
            db    $62,$86,$61,$63,$60,$5c,$1d,$1e,$1f,$20,$5b,$5e,$60,$08,$21,$22
            db    $22,$24,$03,$5e,$60,$10,$25,$26,$26,$27,$10,$5e,$60,$28,$29,$2a
            db    $2a,$2b,$2c,$5e,$60,$2d,$84,$2e,$23,$5e,$5d,$86,$5f,$5d

level_2_supertiles_screen_02 ENT
            db    $62,$86,$61,$63,$60,$2f,$30,$31,$32,$33,$34,$5e,$60,$35,$36,$37
            db    $38,$39,$3a,$5e,$60,$3b,$3c,$3d,$3e,$3f,$40,$5e,$60,$41,$42,$43
            db    $43,$44,$45,$5e,$60,$46,$84,$11,$47,$5e,$5d,$86,$5f,$5d

level_2_supertiles_screen_03 ENT
            db    $62,$86,$61,$63,$60,$48,$58,$49,$4a,$59,$5a,$5e,$60,$4b,$4c,$4d
            db    $4e,$4f,$50,$5e,$60,$4b,$4c,$51,$52,$4f,$50,$5e,$60,$53,$54,$55
            db    $55,$56,$57,$5e,$60,$46,$84,$11,$47,$5e,$5d,$86,$5f,$5d

level_4_supertiles_screen_00 ENT
            db    $64,$65,$66,$65,$66,$65,$66,$64,$67,$04,$05,$06,$07,$01,$02,$74
            db    $68,$08,$09,$69,$0c,$0b,$03,$75,$67,$10,$0d,$6a,$6f,$0f,$10,$74
            db    $68,$15,$16,$14,$14,$12,$13,$75,$67,$18,$84,$11,$17,$74,$64,$72
            db    $73,$72,$73,$72,$73,$64

level_4_supertiles_screen_05 ENT
            db    $64,$65,$66,$65,$66,$65,$66,$64,$67,$04,$05,$06,$07,$01,$02,$74
            db    $68,$08,$09,$6b,$6e,$0b,$03,$75,$67,$10,$0d,$6c,$6d,$0f,$10,$74
            db    $68,$15,$16,$14,$14,$12,$13,$75,$67,$18,$84,$11,$17,$74,$64,$72
            db    $73,$72,$73,$72,$73,$64

level_4_supertiles_screen_04 ENT
            db    $64,$65,$66,$65,$66,$65,$66,$64,$67,$04,$05,$06,$07,$01,$02,$74
            db    $68,$08,$09,$69,$0c,$0b,$03,$75,$67,$10,$0d,$70,$71,$0f,$10,$74
            db    $68,$15,$16,$14,$14,$12,$13,$75,$67,$18,$84,$11,$17,$74,$64,$72
            db    $73,$72,$73,$72,$73,$64

level_4_supertiles_screen_01 ENT
            db    $64,$65,$66,$65,$66,$65,$66,$64,$67,$5c,$1d,$1e,$1f,$20,$5b,$74
            db    $68,$08,$21,$22,$22,$24,$03,$75,$67,$10,$25,$26,$26,$27,$10,$74
            db    $68,$28,$29,$2a,$2a,$2b,$2c,$75,$67,$2d,$84,$2e,$23,$74,$64,$72
            db    $73,$72,$73,$72,$73,$64

level_4_supertiles_screen_02 ENT
            db    $64,$65,$66,$65,$66,$65,$66,$64,$67,$2f,$30,$31,$32,$33,$34,$74
            db    $68,$35,$36,$37,$38,$39,$3a,$75,$67,$3b,$3c,$3d,$3e,$3f,$40,$74
            db    $68,$41,$42,$43,$43,$44,$45,$75,$67,$46,$84,$11,$47,$74,$64,$72
            db    $73,$72,$73,$72,$73,$64

level_4_supertiles_screen_03 ENT
            db    $64,$65,$66,$65,$66,$65,$66,$64,$67,$48,$58,$49,$4a,$59,$5a,$74
            db    $68,$4b,$4c,$4d,$4e,$4f,$50,$75,$67,$4b,$4c,$51,$52,$4f,$50,$74
            db    $68,$53,$54,$55,$55,$56,$57,$75,$67,$46,$84,$11,$47,$74,$64,$72
            db    $73,$72,$73,$72,$73,$64

; pointer table for level 3 (#$0a * #$02 = #$14 bytes)
level_3_supertiles_screen_ptr_table ENT
            dw    level_3_supertiles_screen_00    ; CPU address $8667
            dw    level_3_supertiles_screen_01    ; CPU address $8635
            dw    level_3_supertiles_screen_02    ; CPU address $860d
            dw    level_3_supertiles_screen_03    ; CPU address $85d2
            dw    level_3_supertiles_screen_04    ; CPU address $8599
            dw    level_3_supertiles_screen_05    ; CPU address $855c
            dw    level_3_supertiles_screen_06    ; CPU address $8531
            dw    level_3_supertiles_screen_07    ; CPU address $8515
            dw    level_3_supertiles_screen_08    ; CPU address $84e4
            dw    level_3_supertiles_screen_09    ; CPU address $84e2

; level data blocks are stored in reverse order
; first pointer for top screen
level_3_supertiles_screen_09 ENT
            db    $c0,$60

level_3_supertiles_screen_08 ENT
            db    $60,$60,$35,$36,$37,$38,$84,$60,$39,$3a,$3b,$3c,$83,$60,$3d,$3e
            db    $70,$71,$41,$42,$60,$43,$44,$45,$46,$22,$10,$02,$03,$40,$40,$30
            db    $31,$32,$33,$40,$40,$3f,$3f,$30,$34,$6f,$33,$3f,$3f,$88,$04,$88
            db    $06

level_3_supertiles_screen_07 ENT
            db    $88,$04,$84,$06,$84,$05,$06,$05,$05,$8a,$06,$83,$05,$84,$04,$87
            db    $06,$83,$04,$06,$06,$83,$04,$06,$84,$05,$88,$06

level_3_supertiles_screen_06 ENT
            db    $87,$04,$83,$06,$1e,$20,$1f,$83,$04,$1e,$20,$84,$60,$23,$04,$87
            db    $60,$1f,$83,$1d,$24,$84,$1b,$5d,$4a,$18,$2a,$84,$5e,$47,$83,$00
            db    $25,$83,$12,$5d,$5b,$18,$0b,$0e,$5b,$01,$5b

level_3_supertiles_screen_05 ENT
            db    $4a,$0b,$0c,$5e,$5e,$0d,$00,$5d,$18,$0e,$83,$00,$27,$00,$00,$2e
            db    $19,$01,$21,$0b,$5e,$0d,$4a,$28,$16,$01,$21,$11,$12,$12,$15,$5e
            db    $26,$83,$5d,$47,$18,$2a,$5e,$28,$16,$5d,$00,$00,$2f,$5e,$00,$27
            db    $83,$00,$18,$2a,$5e,$5b,$0f,$0d,$5b,$5b,$00,$00,$0f

level_3_supertiles_screen_04 ENT
            db    $5d,$0f,$28,$16,$01,$01,$5d,$0f,$4a,$0f,$5e,$2d,$16,$5d,$18,$2a
            db    $18,$2a,$5e,$5e,$26,$00,$2f,$5e,$2e,$84,$5e,$0c,$5e,$5e,$83,$00
            db    $0f,$84,$5e,$16,$83,$00,$27,$83,$00,$26,$5d,$18,$0c,$28,$16,$01
            db    $21,$00,$00,$2f,$5c,$5c,$2d,$16,$5b

level_3_supertiles_screen_03 ENT
            db    $4a,$01,$11,$1a,$5e,$5e,$0c,$0c,$01,$01,$18,$17,$83,$00,$0f,$16
            db    $18,$2e,$28,$16,$83,$00,$2d,$2e,$5e,$5e,$2d,$16,$84,$00,$07,$08
            db    $08,$09,$00,$00,$01,$21,$0f,$5e,$5e,$28,$16,$4a,$5d,$21,$11,$12
            db    $1a,$5e,$2d,$16,$83,$5b,$18,$0f,$5c,$5c,$2d

level_3_supertiles_screen_02 ENT
            db    $84,$5d,$84,$00,$16,$00,$00,$18,$84,$0c,$2d,$16,$8a,$00,$18,$16
            db    $18,$16,$01,$21,$0b,$0c,$2e,$2d,$2e,$2d,$5d,$5d,$14,$85,$13,$88
            db    $00,$5b,$5b,$01,$01,$5b,$83,$00

level_3_supertiles_screen_01 ENT
            db    $84,$00,$0a,$83,$5d,$16,$00,$00,$5d,$47,$18,$16,$18,$26,$00,$0a
            db    $5d,$84,$00,$19,$01,$83,$5d,$0a,$01,$21,$5d,$85,$01,$0a,$18,$84
            db    $01,$47,$5d,$5d,$2f,$16,$0a,$83,$01,$5d,$18,$2a,$26,$16,$84,$5d
            db    $00,$00

level_3_supertiles_screen_00 ENT
            db    $00,$00,$5d,$5d,$83,$01,$21,$5d,$00,$00,$5d,$5d,$18,$16,$5d,$84
            db    $00,$5d,$83,$00,$16,$5d,$5d,$84,$00,$5d,$26,$83,$5d,$83,$00,$18
            db    $28,$16,$83,$5d,$8b,$00,$88,$5d

; pointer table for level 5 (#$16 * #$02 = #$2c bytes)
level_5_supertiles_screen_ptr_table ENT
            dw    level_5_supertiles_screen_00    ; CPU address $86bb
            dw    level_5_supertiles_screen_01    ; CPU address $86e1
            dw    level_5_supertiles_screen_02    ; CPU address $8700
            dw    level_5_supertiles_screen_03    ; CPU address $8733
            dw    level_5_supertiles_screen_04    ; CPU address $8763
            dw    level_5_supertiles_screen_05    ; CPU address $8792
            dw    level_5_supertiles_screen_06    ; CPU address $87c6
            dw    level_5_supertiles_screen_07    ; CPU address $87fa
            dw    level_5_supertiles_screen_08    ; CPU address $882a
            dw    level_5_supertiles_screen_09    ; CPU address $8851
            dw    level_5_supertiles_screen_0a    ; CPU address $8855
            dw    level_5_supertiles_screen_09    ; CPU address $8851
            dw    level_5_supertiles_screen_0b    ; CPU address $8863
            dw    level_5_supertiles_screen_09    ; CPU address $8851
            dw    level_5_supertiles_screen_0a    ; CPU address $8855
            dw    level_5_supertiles_screen_09    ; CPU address $8851
            dw    level_5_supertiles_screen_0c    ; CPU address $8890
            dw    level_5_supertiles_screen_0d    ; CPU address $88c4
            dw    level_5_supertiles_screen_0e    ; CPU address $88eb
            dw    level_5_supertiles_screen_09    ; CPU address $8851
            dw    level_5_supertiles_screen_0f    ; CPU address $890e
            dw    level_5_supertiles_screen_00    ; CPU address $86bb

level_5_supertiles_screen_00 ENT
            db    $00,$00,$3c,$00,$3b,$3c,$83,$00,$3c,$00,$83,$3c,$3b,$00,$00,$3c
            db    $83,$3b,$3c,$85,$00,$3c,$00,$00,$3c,$00,$01,$02,$01,$02,$01,$02
            db    $01,$02,$88,$23,$88,$38

level_5_supertiles_screen_01 ENT
            db    $00,$3c,$3b,$3c,$00,$3b,$00,$00,$05,$86,$18,$44,$06,$86,$19,$45
            db    $87,$07,$43,$01,$02,$01,$02,$01,$02,$01,$02,$88,$23,$88,$38

level_5_supertiles_screen_02 ENT
            db    $00,$00,$3b,$00,$00,$3c,$3b,$84,$00,$3c,$3b,$3b,$3c,$00,$00,$3c
            db    $3b,$83,$00,$3c,$83,$00,$28,$01,$01,$0f,$00,$00,$01,$3e,$2a,$51
            db    $03,$14,$00,$22,$23,$24,$0c,$04,$04,$13,$30,$46,$38,$42,$29,$83
            db    $16,$11,$08

level_5_supertiles_screen_03 ENT
            db    $00,$3b,$3c,$3c,$00,$3b,$3c,$83,$00,$83,$3c,$84,$00,$3b,$00,$3b
            db    $00,$00,$2f,$09,$86,$00,$29,$16,$01,$01,$2b,$00,$00,$28,$01,$01
            db    $23,$2c,$2e,$09,$09,$0c,$25,$23,$38,$50,$29,$16,$16,$11,$41,$38

level_5_supertiles_screen_04 ENT
            db    $00,$3b,$3c,$3b,$3c,$00,$05,$44,$00,$3c,$00,$3b,$00,$00,$06,$45
            db    $09,$30,$00,$00,$17,$09,$0e,$47,$16,$0a,$00,$00,$12,$16,$0d,$0d
            db    $02,$01,$02,$01,$02,$3e,$25,$2c,$85,$23,$2c,$00,$00,$88,$38

level_5_supertiles_screen_05 ENT
            db    $3c,$00,$3b,$05,$18,$44,$00,$00,$3b,$3c,$00,$06,$19,$45,$00,$00
            db    $30,$00,$2f,$0e,$0e,$47,$30,$00,$0a,$00,$29,$83,$16,$0a,$00,$22
            db    $02,$01,$02,$01,$02,$3e,$00,$25,$83,$23,$24,$2a,$3d,$00,$84,$38
            db    $42,$25,$24,$22

level_5_supertiles_screen_06 ENT
            db    $00,$3b,$3c,$00,$00,$3c,$3b,$00,$00,$3c,$00,$00,$3b,$3b,$3c,$00
            db    $00,$2f,$09,$09,$30,$84,$00,$2a,$51,$0d,$33,$2f,$30,$22,$00,$25
            db    $23,$23,$0a,$29,$11,$46,$00,$22,$02,$01,$02,$01,$3e,$46,$3e,$46
            db    $84,$03,$3d,$46

level_5_supertiles_screen_07 ENT
            db    $00,$00,$3b,$3c,$00,$3b,$00,$3c,$00,$3b,$3c,$3c,$00,$3c,$3b,$3c
            db    $00,$3c,$86,$00,$3e,$86,$00,$22,$3d,$00,$22,$3e,$00,$40,$00,$46
            db    $3d,$36,$46,$3d,$36,$46,$36,$46,$3d,$3f,$37,$37,$3a,$37,$3f,$37

level_5_supertiles_screen_08 ENT
            db    $85,$00,$3c,$83,$00,$3c,$00,$00,$3c,$87,$00,$3c,$83,$00,$3e,$87
            db    $00,$3d,$00,$22,$02,$01,$02,$3e,$00,$3d,$36,$46,$83,$03,$3d,$1a
            db    $37,$3a,$46,$83,$34,$3d,$1a

level_5_supertiles_screen_09 ENT
            db    $a8,$00,$90,$1a

level_5_supertiles_screen_0a ENT
            db    $98,$00,$60,$1c,$1d,$85,$00,$1e,$61,$62,$85,$00,$90,$1a

level_5_supertiles_screen_0b ENT
            db    $84,$00,$3c,$00,$3b,$83,$00,$3b,$00,$3c,$00,$3c,$00,$00,$3b,$3c
            db    $00,$3b,$85,$00,$2f,$09,$30,$85,$00,$29,$16,$11,$00,$22,$3e,$22
            db    $02,$01,$02,$01,$3e,$46,$3d,$25,$84,$23,$2c,$46,$3d

level_5_supertiles_screen_0c ENT
            db    $3c,$00,$3c,$3b,$00,$3b,$3c,$00,$00,$3b,$05,$83,$18,$44,$3c,$00
            db    $3c,$06,$83,$19,$45,$00,$3b,$00,$84,$07,$43,$00,$00,$28,$02,$01
            db    $02,$01,$2b,$00,$1a,$0c,$0b,$21,$23,$23,$2c,$2f,$1a,$46,$26,$10
            db    $38,$38,$50,$27

level_5_supertiles_screen_0d ENT
            db    $83,$00,$3b,$3c,$00,$3c,$00,$3b,$00,$3b,$3c,$89,$00,$3b,$00,$00
            db    $28,$01,$02,$01,$02,$01,$2b,$00,$2a,$03,$51,$83,$03,$2d,$22,$0c
            db    $85,$04,$32,$46,$87,$11,$08

level_5_supertiles_screen_0e ENT
            db    $00,$3b,$3c,$84,$00,$3c,$83,$00,$3b,$00,$3b,$84,$00,$3b,$00,$3c
            db    $3c,$8a,$00,$02,$01,$02,$01,$02,$01,$3e,$00,$86,$23,$2c,$1a,$86
            db    $38,$50,$1a

level_5_supertiles_screen_0f ENT
            db    $95,$00,$4d,$4e,$4f,$85,$00,$4a,$4b
            db    $4c,$85,$00,$31,$48,$49,$84,$1a,$15,$1b,$1f,$20,$88,$1a

; pointer table for level 6 (#$0e * #$02 = #$1c bytes)
level_6_supertiles_screen_ptr_table ENT
            dw    level_6_supertiles_screen_00    ; CPU address $8941
            dw    level_6_supertiles_screen_01    ; CPU address $8973
            dw    level_6_supertiles_screen_02    ; CPU address $89a3
            dw    level_6_supertiles_screen_03    ; CPU address $89d5
            dw    level_6_supertiles_screen_04    ; CPU address $8a07
            dw    level_6_supertiles_screen_05    ; CPU address $8a3d
            dw    level_6_supertiles_screen_06    ; CPU address $8a71
            dw    level_6_supertiles_screen_07    ; CPU address $8aa7
            dw    level_6_supertiles_screen_08    ; CPU address $8ada
            dw    level_6_supertiles_screen_09    ; CPU address $8b0e
            dw    level_6_supertiles_screen_0a    ; CPU address $8b40
            dw    level_6_supertiles_screen_0b    ; CPU address $8b64
            dw    level_6_supertiles_screen_0c    ; CPU address $8b6a
            dw    level_6_supertiles_screen_00    ; CPU address $8941

level_6_supertiles_screen_00 ENT
            db    $1d,$30,$31,$1d,$30,$31,$1d,$30,$3f,$31,$49,$3f,$31,$49,$3f,$31
            db    $60,$32,$4d,$40,$32,$4d,$40,$32,$57,$3e,$3f,$57,$3e,$3f,$60,$3e
            db    $57,$60,$60,$00,$60,$00,$57,$00,$00,$57,$00,$60,$00,$57,$00,$00
            db    $88,$01

level_6_supertiles_screen_01 ENT
            db    $31,$1d,$30,$31,$1d,$30,$31,$1d,$49,$3f,$4d,$40,$3f,$4d,$40,$3f
            db    $4d,$40,$3f,$57,$00,$3d,$60,$57,$30,$28,$02,$85,$03,$32,$02,$06
            db    $4c,$61,$69,$63,$4c,$02,$06,$4c,$4c,$65,$62,$64,$4c,$14,$87,$22

level_6_supertiles_screen_02 ENT
            db    $30,$31,$1d,$3f,$40,$1d,$3f,$4d,$31,$40,$3f,$60,$40,$3f,$57,$3e
            db    $00,$57,$00,$00,$57,$00,$00,$60,$0b,$08,$0c,$51,$83,$58,$59,$05
            db    $57,$15,$0e,$57,$12,$10,$53,$05,$00,$60,$00,$00,$09,$17,$13,$24
            db    $87,$01

level_6_supertiles_screen_03 ENT
            db    $1d,$3f,$40,$1d,$4d,$3f,$4a,$4a,$3f,$60,$57,$3e,$3f,$57,$3e,$3f
            db    $00,$60,$60,$57,$00,$60,$00,$57,$38,$57,$08,$0c,$51,$58,$58,$59
            db    $54,$33,$12,$53,$54,$10,$33,$15,$17,$23,$09,$17,$13,$17,$23,$28
            db    $88,$01

level_6_supertiles_screen_04 ENT
            db    $4a,$4b,$4a,$29,$4a,$4b,$4a,$29,$32,$00,$57,$3e,$3f,$00,$3e,$3f
            db    $57,$00,$60,$60,$57,$00,$57,$60,$38,$00,$0f,$03,$04,$34,$34,$03
            db    $0e,$69,$00,$11,$52,$12,$10,$18,$28,$3f,$60,$00,$57,$09,$17,$17
            db    $01,$68,$00,$50,$84,$01

level_6_supertiles_screen_05 ENT
            db    $4b,$4a,$43,$66,$4a,$29,$4a,$43,$00,$3d,$67,$2d,$0a,$0a,$3c,$1b
            db    $00,$60,$1b,$4e,$00,$20,$66,$1b,$47,$57,$67,$2d,$1c,$1a,$4e,$2f
            db    $46,$60,$2f,$2e,$0a,$1f,$2d,$00,$23,$60,$83,$00,$20,$4e,$00,$85
            db    $01,$1e,$42,$01

level_6_supertiles_screen_06 ENT
            db    $66,$29,$4a,$29,$4b,$29,$4a,$29,$4e,$3e,$3f,$3d,$00,$21,$0a,$0a
            db    $2d,$1c,$0d,$4f,$83,$00,$1b,$2e,$0a,$1f,$4e,$00,$00,$2b,$5d,$00
            db    $00,$20,$2d,$69,$00,$21,$1f,$00,$02,$2c,$4e,$41,$00,$00,$5e,$01
            db    $14,$25,$42,$83,$01,$1e

level_6_supertiles_screen_07 ENT
            db    $29,$4a,$43,$66,$2a,$29,$4a,$29,$3c,$00,$20,$4e,$39,$3e,$3d,$3e
            db    $66,$1c,$1a,$2d,$44,$83,$00,$4e,$0a,$1f,$2e,$39,$00,$0f,$03,$2d
            db    $83,$00,$39,$12,$10,$18,$4e,$03,$0b,$00,$39,$09,$17,$17,$42,$25
            db    $24,$85,$01

level_6_supertiles_screen_08 ENT
            db    $4a,$2a,$4b,$29,$2a,$29,$4b,$29,$3f,$36,$00,$3e,$36,$3d,$00,$3d
            db    $00,$39,$00,$00,$39,$83,$00,$04,$84,$34,$03,$47,$08,$46,$45,$00
            db    $00,$39,$11,$52,$12,$23,$39,$00,$00,$44,$00,$00,$09,$01,$01,$68
            db    $00,$50,$83,$01

level_6_supertiles_screen_09 ENT
            db    $4a,$29,$2a,$29,$4a,$29,$2a,$29,$3e,$3f,$39,$3e,$3f,$00,$39,$3e
            db    $00,$00,$44,$83,$00,$44,$00,$0c,$51,$59,$38,$00,$0f,$03,$34,$53
            db    $54,$37,$54,$10,$10,$18,$10,$17,$13,$48,$83,$35,$3b,$17,$86,$01
            db    $16,$00

level_6_supertiles_screen_0a ENT
            db    $4a,$29,$4b,$29,$4a,$83,$00,$3f,$3d,$00,$3e,$3f,$8b,$00,$34,$03
            db    $47,$85,$00,$33,$11,$52,$85,$00,$23,$00,$00,$02,$84,$03,$00,$50
            db    $01,$14,$84,$22

level_6_supertiles_screen_0b ENT
            db    $a8,$00,$88,$03,$88,$22

level_6_supertiles_screen_0c ENT
            db    $8e,$00,$19,$27,$86,$00,$3a,$55,$86,$00,$56,$5b,$86,$00,$56,$5a
            db    $86,$03,$5f,$5a,$87,$22,$5c

; pointer table for level 7 (10 * 2 = 20 bytes)
level_7_supertiles_screen_ptr_table ENT
            dw    level_7_supertiles_screen_00    ; CPU address $8ba1
            dw    level_7_supertiles_screen_01    ; CPU address $8bd2
            dw    level_7_supertiles_screen_02    ; CPU address $8bf8
            dw    level_7_supertiles_screen_03    ; CPU address $8c27
            dw    level_7_supertiles_screen_04    ; CPU address $8c58
            dw    level_7_supertiles_screen_05    ; CPU address $8c8a
            dw    level_7_supertiles_screen_06    ; CPU address $8ca7
            dw    level_7_supertiles_screen_07    ; CPU address $8cd7
            dw    level_7_supertiles_screen_08    ; CPU address $8d03
            dw    level_7_supertiles_screen_09    ; CPU address $8d2a
            dw    level_7_supertiles_screen_0a    ; CPU address $8d58
            dw    level_7_supertiles_screen_0b    ; CPU address $8d82
            dw    level_7_supertiles_screen_0c    ; CPU address $8db6
            dw    level_7_supertiles_screen_0d    ; CPU address $8dea
            dw    level_7_supertiles_screen_0e    ; CPU address $8e10
            dw    level_7_supertiles_screen_00    ; CPU address $8ba1

level_7_supertiles_screen_00 ENT
            db    $05,$05,$43,$43,$09,$17,$0e,$0e,$05,$43,$05,$3f,$09,$1b,$23,$23
            db    $3f,$43,$3f,$3f,$30,$30,$6d,$6d,$6e,$38,$6f,$6f,$34,$34,$6d,$6d
            db    $84,$11,$13,$13,$11,$47,$87,$45,$37,$49,$4a,$49,$4a,$49,$4a,$49
            db    $32

level_7_supertiles_screen_01 ENT
            db    $83,$0e,$02,$84,$0e,$83,$23,$0d,$0f,$0f,$23,$23,$83,$6d,$4d,$6f
            db    $6f,$54,$6d,$10,$11,$11,$13,$11,$11,$12,$6d,$3e,$85,$3d,$2c,$6d
            db    $87,$6f,$40,$87,$20,$48

level_7_supertiles_screen_02 ENT
            db    $0e,$02,$85,$0e,$02,$23,$09,$23,$22,$0f,$22,$23,$0d,$6d,$30,$6d
            db    $6d,$6e,$6d,$3c,$4d,$6d,$34,$6d,$3c,$6f,$54,$10,$13,$6d,$34,$6d
            db    $10,$11,$12,$3e,$0f,$11,$13,$47,$85,$6f,$45,$45,$32,$85,$20

level_7_supertiles_screen_03 ENT
            db    $87,$0e,$1d,$05,$05,$3f,$05,$43,$05,$05,$50,$39,$3f,$05,$43,$3f
            db    $3f,$43,$50,$12,$3f,$6e,$6e,$3f,$38,$6f,$3b,$2c,$38,$83,$6f,$40
            db    $11,$3a,$6f,$40,$83,$11,$31,$45,$45,$20,$48,$49,$4a,$49,$4a,$49
            db    $4a

level_7_supertiles_screen_04 ENT
            db    $0e,$1d,$0e,$1d,$84,$0e,$43,$50,$05,$50,$83,$23,$6e,$05,$50,$3f
            db    $50,$6d,$6d,$3c,$6f,$6f,$3b,$6f,$3b,$33,$54,$10,$11,$11,$3a,$11
            db    $3a,$11,$47,$3e,$3d,$85,$45,$37,$6f,$6f,$49,$4a,$49,$4a,$49,$32
            db    $20,$20

level_7_supertiles_screen_05 ENT
            db    $88,$0e,$83,$3d,$6e,$84,$23,$84,$6f,$54,$83,$6d,$84,$11,$12,$83
            db    $6d,$84,$3d,$2c,$6d,$6d,$10,$85,$6f,$83,$33,$88,$20

level_7_supertiles_screen_06 ENT
            db    $0e,$02,$86,$0e,$23,$35,$83,$23,$3d,$3d,$23,$64,$09,$83,$6d,$6e
            db    $6e,$24,$10,$1c,$83,$6d,$38,$6f,$41,$0c,$30,$6d,$3c,$33,$40,$11
            db    $47,$33,$36,$33,$40,$11,$31,$45,$37,$83,$20,$48,$49,$4a,$49,$32

level_7_supertiles_screen_07 ENT
            db    $83,$0e,$02,$84,$0e,$83,$23,$35,$84,$23,$25,$25,$26,$09,$24,$25
            db    $25,$26,$29,$29,$2a,$09,$28,$29,$29,$2a,$27,$2b,$6d,$1f,$27,$2b
            db    $27,$2b,$2e,$2f,$6d,$34,$2e,$2f,$2e,$2f,$88,$20

level_7_supertiles_screen_08 ENT
            db    $0e,$02,$86,$0e,$23,$35,$84,$23,$21,$2d,$6d,$09,$6d,$27,$2b,$6d
            db    $2e,$2f,$6d,$09,$6d,$2e,$2f,$6d,$10,$11,$6d,$1f,$6d,$10,$11,$0c
            db    $83,$6d,$34,$86,$6d,$88,$20

level_7_supertiles_screen_09 ENT
            db    $83,$0e,$1d,$0e,$1d,$0e,$1d,$23,$23,$04,$50,$6e,$50,$6e,$50,$6d
            db    $6d,$38,$3b,$6f,$3b,$6f,$3b,$0c,$6d,$10,$3a,$11,$3a,$11,$3a,$6d
            db    $6d,$3e,$85,$3d,$6d,$6d,$38,$85,$6f,$00,$6d,$1e,$85,$20

level_7_supertiles_screen_0a ENT
            db    $88,$0e,$84,$23,$83,$04,$23,$54,$83,$6d,$83,$6e,$6d,$12,$6d,$6d
            db    $3c,$83,$6f,$54,$2c,$3c,$33,$40,$83,$11,$47,$6f,$40,$11,$31,$83
            db    $45,$37,$20,$48,$49,$4a,$49,$4a,$49,$32

level_7_supertiles_screen_0b ENT
            db    $0e,$0e,$02,$01,$84,$03,$23,$23,$35,$17,$44,$06,$07,$14,$6d,$6d
            db    $09,$1b,$08,$0a,$0b,$18,$6d,$6d,$09,$09,$6d,$6d,$4f,$4f,$6d,$6d
            db    $30,$30,$6d,$6d,$6e,$6e,$33,$33,$36,$36,$33,$33,$6f,$6f,$11,$11
            db    $13,$13,$84,$11

level_7_supertiles_screen_0c ENT
            db    $83,$03,$01,$01,$05,$43,$43,$15,$16,$44,$17,$17,$3f,$05,$43,$19
            db    $1a,$08,$1b,$1b,$05,$43,$43,$4f,$6d,$6d,$09,$09,$3f,$43,$3f,$6e
            db    $6e,$6d,$30,$0d,$43,$3f,$43,$6f,$6f,$33,$36,$4d,$83,$6f,$83,$11
            db    $13,$13,$83,$11

level_7_supertiles_screen_0d ENT
            db    $43,$3f,$3f,$6e,$83,$3f,$6e,$86,$3f,$43,$3f,$6e,$84,$3f,$6e,$83
            db    $3f,$6e,$3f,$6e,$3f,$6e,$6e,$3f,$3f,$38,$87,$6f,$40,$87,$11,$31
            db    $4a,$49,$4a,$49,$4a,$49

level_7_supertiles_screen_0e ENT
            db    $43,$6e,$3f,$3f,$6e,$51,$52,$53,$6e,$3f,$3f,$6e,$3f,$55,$56,$57
            db    $3f,$6e,$3f,$3f,$58,$59,$5a,$5b,$6e,$3f,$6e,$6e,$5c,$5d,$5e,$5f
            db    $83,$6f,$39,$4e,$60,$67,$61,$11,$11,$42,$46,$42,$46,$76,$62,$4a
            db    $49,$4c,$4b,$4c,$4b,$4a,$63

; pointer table for level 8 (#$0c * #$02 = #$18 bytes)
level_8_supertiles_screen_ptr_table ENT
            dw    level_8_supertiles_screen_00    ; CPU address $8e5f
            dw    level_8_supertiles_screen_01    ; CPU address $8e8e
            dw    level_8_supertiles_screen_02    ; CPU address $8eb4
            dw    level_8_supertiles_screen_03    ; CPU address $8ee7
            dw    level_8_supertiles_screen_04    ; CPU address $8f0b
            dw    level_8_supertiles_screen_05    ; CPU address $8f31
            dw    level_8_supertiles_screen_06    ; CPU address $8f59
            dw    level_8_supertiles_screen_07    ; CPU address $8f88
            dw    level_8_supertiles_screen_08    ; CPU address $8fac
            dw    level_8_supertiles_screen_09    ; CPU address $8fd9
            dw    level_8_supertiles_screen_0a    ; CPU address $8fef
            dw    level_8_supertiles_screen_00    ; CPU address $8e5f

level_8_supertiles_screen_00 ENT
            db    $83,$4c,$2b,$84,$27,$4c,$4c,$2b,$85,$26,$4c,$4c,$3e,$26,$26,$23
            db    $32,$32,$4c,$4c,$3e,$26,$26,$43,$00,$02,$4c,$4c,$3e,$2e,$04,$35
            db    $12,$15,$4c,$4c,$47,$43,$24,$83,$11,$83,$01,$02,$24,$83,$11

level_8_supertiles_screen_01 ENT
            db    $88,$27,$88,$26,$42,$44,$85,$32,$42,$3e,$08,$84,$01,$02,$3e,$47
            db    $0c,$83,$10,$13,$12,$05,$4c,$07,$47,$0a,$0b,$0e,$11,$24,$3a,$11
            db    $3a,$37,$36,$37,$11,$11

level_8_supertiles_screen_02 ENT
            db    $27,$27,$2c,$4c,$61,$62,$63,$64,$26,$26,$2e,$4c,$65,$66,$67,$68
            db    $26,$26,$2e,$4c,$5a,$59,$69,$2b,$26,$26,$2f,$41,$3d,$4c,$2b,$26
            db    $06,$47,$2e,$40,$3c,$4c,$3e,$26,$24,$72,$35,$3f,$3c,$35,$05,$05
            db    $24,$87,$11

level_8_supertiles_screen_03 ENT
            db    $88,$11,$2b,$27,$1c,$1b,$20,$49,$49,$11,$26,$26,$2f,$1f,$2b,$27
            db    $2c,$20,$83,$26,$2a,$83,$26,$29,$88,$26,$06,$42,$44,$85,$32,$11
            db    $3a,$39,$85,$01

level_8_supertiles_screen_04 ENT
            db    $90,$11,$49,$49,$84,$11,$49,$49,$83,$27,$2c,$1f,$31,$2b,$27,$26
            db    $26,$44,$32,$2a,$83,$26,$43,$07,$4c,$03,$47,$0a,$05,$06,$02,$24
            db    $3a,$11,$3a,$37,$11,$24

level_8_supertiles_screen_05 ENT
            db    $8b,$11,$21,$31,$30,$1b,$33,$21,$31,$1f,$2b,$26,$2f,$1f,$2b,$28
            db    $32,$45,$83,$32,$45,$42,$08,$85,$01,$02,$3e,$2d,$84,$48,$14,$12
            db    $05,$00,$83,$01,$02,$24,$49,$49

level_8_supertiles_screen_06 ENT
            db    $88,$11,$2b,$1c,$1f,$2b,$84,$27,$26,$29,$2a,$2e,$04,$05,$05,$06
            db    $26,$44,$32,$43,$11,$11,$49,$49,$26,$08,$83,$01,$02,$2b,$27,$05
            db    $16,$12,$15,$48,$48,$47,$32,$49,$11,$11,$24,$00,$01,$01,$02

level_8_supertiles_screen_07 ENT
            db    $88,$11,$88,$27,$42,$0a,$86,$05,$3e,$0e,$85,$11,$49,$46,$29,$27
            db    $27,$30,$1f,$31,$2b,$43,$04,$83,$05,$34,$44,$32,$3a,$11,$11,$49
            db    $49,$36,$3a,$00

level_8_supertiles_screen_08 ENT
            db    $88,$11,$27,$27,$2c,$20,$84,$11,$05,$06,$42,$2c,$20,$83,$11,$49
            db    $22,$3e,$26,$29,$1c,$1f,$4c,$27,$27,$46,$83,$26,$29,$30,$32,$32
            db    $43,$04,$83,$05,$35,$01,$38,$3a,$11,$11,$49,$49,$11

level_8_supertiles_screen_09 ENT
            db    $87,$11,$22,$84,$11,$25,$4c,$33,$1b,$11,$49,$49,$25,$83,$4c,$1f
            db    $90,$4c,$88,$35,$88,$11

level_8_supertiles_screen_0a ENT
            db    $88,$18,$33,$83,$4c,$19,$6a,$6a,$18,$84,$4c,$1d,$4e,$4d,$18,$85
            db    $4c,$50,$4f,$18,$84,$4c,$1a,$17,$17,$18,$84,$35,$1e,$6e,$6e,$18
            db    $18,$49,$86,$18

; pointer table for indoor levels boss rooms (#$02 * #$02 = #$04 bytes)
level_2_4_boss_supertiles_screen_ptr_table ENT
            dw    level_2_4_boss_supertiles_screen_00    ; CPU address $9017
            dw    level_2_4_boss_supertiles_screen_01    ; CPU address $9057

; table for level 2 boss room (#$40 bytes)
; indexes into level_2_4_boss_supertile_data
level_2_4_boss_supertiles_screen_00 ENT
            db    $01,$02,$03,$09,$0e,$0f,$10,$11,$04,$05,$06,$00,$00,$12,$0b,$13
            db    $07,$08,$4a,$53,$56,$4a,$0d,$0c,$07,$05,$59,$71,$65,$59,$0b,$0a
            db    $07,$14,$5c,$6e,$6b,$5c,$1d,$0a,$16,$15,$17,$19,$1c,$18,$1e,$1f
            db    $1a,$1b,$21,$22,$23,$24,$1b,$20,$00,$00,$00,$00,$00,$00,$00,$00

; table for level 4 boss room (#$40 bytes)
; indexes into level_2_4_boss_supertile_data
level_2_4_boss_supertiles_screen_01 ENT
            db    $2c,$2d,$2e,$2f,$3b,$3c,$3d,$3e,$30,$31,$32,$62,$5f,$40,$41,$42
            db    $30,$34,$35,$50,$68,$35,$44,$42,$37,$38,$4a,$53,$56,$4a,$46,$47
            db    $30,$48,$49,$28,$39,$39,$3a,$42,$29,$2a,$2b,$45,$36,$33,$27,$26
            db    $43,$3f,$3f,$3f,$3f,$3f,$3f,$25,$00,$00,$00,$00,$00,$00,$00,$00

; intro screen nametable layout (#$1bb bytes)
; nametable entries point to pattern table data in graphic_data_01
; CPU address $9097
; nametable and attribute table used for intro screen
; nametable data - writes addresses [$2000-$2400)
; "1 PLAYER"
; "2 PLAYERS"
; "TM AND © 1988"
; "KONAMI INDUSTRY"
; "CO.,LTD"
; "LICENSED BY"
; "NINTENDO OF"
; "AMERICA INC"
graphic_data_02 ENT
            db    $00,$20,$6d,$00,$8b,$0e,$0f,$5b,$5c,$5d,$5e,$5f,$ac,$ad,$ae,$af
            db    $14,$00,$8c,$01,$8b,$1f,$c0,$c1,$c2,$aa,$ab,$bc,$bd,$be,$bf,$14
            db    $00,$82,$10,$9b,$18,$00,$86,$02,$03,$04,$05,$06,$07,$19,$00,$89
            db    $11,$12,$13,$14,$15,$16,$17,$18,$19,$16,$00,$8a,$20,$21,$22,$23
            db    $24,$25,$26,$27,$28,$29,$16,$00,$83,$60,$61,$62,$04,$00,$82,$08
            db    $09,$17,$00,$96,$70,$71,$72,$00,$00,$63,$64,$65,$66,$67,$68,$69
            db    $6a,$6b,$6c,$6d,$6e,$6f,$0a,$0b,$0c,$0d,$0a,$00,$97,$80,$81,$82
            db    $00,$00,$73,$74,$75,$76,$77,$78,$79,$7a,$7b,$7c,$7d,$7e,$7f,$1a
            db    $1b,$1c,$1d,$1e,$09,$00,$98,$90,$91,$92,$00,$00,$83,$84,$85,$86
            db    $87,$88,$89,$8a,$00,$8c,$8d,$8e,$8f,$2a,$2b,$2c,$2d,$2e,$2f,$08
            db    $00,$98,$a0,$a1,$a2,$a3,$00,$93,$94,$95,$96,$97,$98,$99,$9a,$00
            db    $9c,$9d,$9e,$9f,$3a,$3b,$3c,$3d,$3e,$3f,$09,$00,$8b,$b1,$b2,$b3
            db    $b4,$b5,$b6,$b7,$b8,$b9,$ba,$bb,$17,$00,$86,$a4,$a5,$a6,$a7,$a8
            db    $a9,$27,$00,$85,$c4,$00,$d0,$d1,$d2,$1a,$00,$87,$d3,$d4,$d5,$e0
            db    $e1,$e2,$e3,$0b,$00,$8b,$50,$4c,$41,$59,$00,$53,$45,$4c,$45,$43
            db    $54,$04,$00,$85,$e4,$e5,$f0,$f1,$f2,$1a,$00,$88,$f3,$f4,$f5,$c5
            db    $c6,$c7,$c8,$c9,$0c,$00,$88,$31,$00,$50,$4c,$41,$59,$45,$52,$03
            db    $00,$85,$ca,$cb,$cc,$cd,$ce,$03,$00,$82,$ef,$d6,$15,$00,$86,$d9
            db    $da,$db,$dc,$dd,$de,$04,$00,$81,$e6,$0b,$00,$90,$32,$00,$50,$4c
            db    $41,$59,$45,$52,$53,$00,$e9,$ea,$eb,$ec,$ed,$ee,$04,$00,$81,$f6
            db    $17,$00,$84,$d7,$d8,$e7,$e8,$13,$00,$8d,$54,$4d,$00,$41,$4e,$44
            db    $00,$c3,$00,$31,$39,$38,$38,$0e,$00,$97,$4b,$4f,$4e,$41,$4d,$49
            db    $00,$49,$4e,$44,$55,$53,$54,$52,$59,$00,$43,$4f,$40,$b0,$4c,$54
            db    $44,$10,$00,$8b,$4c,$49,$43,$45,$4e,$53,$45,$44,$00,$42,$59,$0e
            db    $00,$97,$4e,$49,$4e,$54,$45,$4e,$44,$4f,$00,$4f,$46,$00,$41,$4d
            db    $45,$52,$49,$43,$41,$00,$49,$4e,$43,$4d,$00,$83,$a0,$a0,$20,$06
            db    $00,$82,$58,$52,$03,$50,$83,$00,$00,$20,$05,$05,$05,$00,$83,$cc
            db    $ff,$f3,$05,$00,$83,$ff,$ff,$cc,$11,$00,$ff

; compressed alternate graphics data for level 1 (#$580 bytes)
; CPU address $9252
alt_graphic_data_00 ENT
            db    $ed,$ed,$ed,$ff,$ff,$ff,$ff,$ff,$ed,$80,$80,$92,$80,$80,$80,$80
            db    $e0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$e0,$10,$10,$10,$10,$10,$10,$10
            db    $50,$57,$57,$57,$55,$57,$57,$57,$60,$60,$60,$60,$60,$62,$60,$60
            db    $03,$06,$0d,$1b,$24,$37,$37,$37,$01,$02,$04,$09,$17,$37,$37,$37
            db    $7e,$c4,$f9,$f3,$04,$e7,$e7,$e9,$3f,$46,$fc,$f9,$f7,$f3,$f3,$e9
            db    $7e,$c4,$f8,$f0,$07,$e7,$e0,$e0,$3f,$46,$fc,$f8,$f7,$f0,$f0,$f0
            db    $4f,$b7,$47,$b3,$40,$b3,$43,$b3,$c7,$a3,$c3,$a0,$c0,$a2,$c2,$a2
            db    $f7,$f7,$ff,$c0,$33,$33,$33,$33,$fc,$ff,$c0,$00,$26,$66,$66,$66
            db    $80,$00,$7f,$7f,$3f,$5f,$0f,$17,$80,$7f,$7f,$7f,$3f,$1f,$0f,$47
            db    $09,$00,$60,$07,$67,$07,$67,$07,$09,$00,$0f,$0f,$0f,$0f,$0f,$0f
            db    $c9,$01,$02,$f0,$e8,$c0,$a6,$06,$d9,$01,$fe,$f0,$e0,$c0,$8e,$1e
            db    $fc,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$86,$86,$86,$86,$86,$86,$86,$86
            db    $be,$fe,$f2,$c2,$c2,$ce,$de,$ca,$ff,$73,$43,$43,$4f,$7f,$53,$43
            db    $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$80,$80,$80,$80,$80,$80,$80
            db    $06,$f6,$06,$f0,$06,$f6,$06,$f0,$00,$f6,$00,$f0,$00,$f6,$00,$f0
            db    $a5,$0a,$a5,$0a,$a5,$0a,$a5,$0a,$b5,$46,$b5,$46,$b5,$46,$b5,$46
            db    $ff,$f0,$ef,$d0,$df,$cf,$e0,$f0,$80,$80,$8f,$9f,$8f,$80,$80,$80
            db    $00,$3f,$40,$5f,$50,$55,$52,$55,$00,$3f,$7f,$60,$60,$67,$60,$67
            db    $00,$00,$00,$00,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$ff,$80,$80,$80
            db    $37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37
            db    $cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$d9,$d9,$d9,$d9,$d9,$d9,$d9,$d9
            db    $e7,$e7,$e0,$e0,$e7,$e7,$e0,$e0,$f7,$f0,$f0,$f0,$f7,$f0,$f0,$f0
            db    $43,$b3,$43,$b3,$43,$b0,$43,$b3,$c2,$a2,$c2,$a2,$c0,$a0,$c2,$a2
            db    $33,$33,$33,$37,$70,$03,$33,$33,$66,$66,$66,$60,$00,$06,$66,$66
            db    $43,$64,$71,$7a,$ba,$d4,$d5,$d5,$63,$70,$79,$7a,$ba,$d4,$d4,$d4
            db    $66,$04,$12,$68,$e9,$f5,$f5,$f5,$0e,$0c,$f0,$39,$19,$1d,$1d,$1d
            db    $94,$36,$74,$f6,$e0,$cc,$84,$84,$3c,$7e,$fc,$fe,$fe,$ec,$cc,$cc
            db    $f0,$fe,$fe,$fe,$fe,$fc,$f0,$88,$00,$0e,$00,$00,$00,$02,$1a,$da
            db    $c2,$ce,$de,$ca,$c2,$ce,$de,$ca,$4f,$7f,$53,$43,$4f,$7f,$53,$43
            db    $c2,$ce,$de,$ca,$ce,$fe,$f1,$8f,$4f,$7f,$53,$43,$4f,$7f,$7f,$ff
            db    $fa,$fa,$fa,$fa,$fa,$fa,$7a,$7e,$86,$86,$86,$86,$86,$86,$c6,$c4
            db    $00,$4f,$70,$3d,$0d,$0d,$3d,$0d,$00,$7f,$3f,$0f,$07,$06,$36,$06
            db    $00,$ff,$00,$ff,$ff,$00,$ff,$ff,$00,$ff,$ff,$ff,$ff,$00,$00,$00
            db    $52,$55,$52,$55,$52,$55,$52,$55,$60,$67,$60,$67,$60,$67,$60,$67
            db    $00,$00,$00,$00,$e0,$f0,$f0,$f0,$00,$00,$00,$00,$e0,$10,$10,$10
            db    $00,$0e,$13,$10,$13,$17,$0e,$00,$00,$08,$17,$17,$17,$17,$08,$00
            db    $00,$be,$4e,$00,$4e,$5e,$be,$00,$00,$00,$5e,$5e,$5e,$1e,$00,$00
            db    $00,$3a,$4d,$40,$4d,$5d,$3a,$00,$00,$20,$5d,$5d,$5d,$5c,$20,$00
            db    $00,$fd,$3d,$02,$3a,$75,$f5,$03,$00,$01,$7d,$7b,$7b,$77,$07,$07
            db    $80,$7f,$79,$f9,$ff,$f9,$f9,$ff,$ff,$ff,$f9,$ff,$ff,$f9,$ff,$ff
            db    $d5,$b5,$74,$7a,$7a,$79,$74,$61,$d4,$b4,$74,$7a,$7a,$79,$70,$63
            db    $f5,$f5,$f5,$e9,$69,$d2,$00,$66,$1d,$1d,$1d,$19,$39,$f0,$0c,$0e
            db    $84,$84,$cc,$e0,$f6,$f4,$76,$b4,$cc,$cc,$ec,$fe,$fe,$fc,$7e,$3c
            db    $48,$48,$48,$48,$48,$48,$48,$48,$da,$da,$da,$da,$da,$da,$da,$da
            db    $c2,$ce,$de,$ca,$ce,$fe,$f0,$8e,$4f,$7f,$53,$43,$4f,$7f,$7f,$ff
            db    $7f,$7f,$3f,$3f,$1f,$0f,$0f,$07,$3f,$3f,$1f,$1f,$0f,$07,$07,$00
            db    $b8,$be,$de,$ee,$ee,$f6,$fe,$e0,$e0,$e0,$f0,$f8,$f8,$fe,$c0,$00
            db    $3d,$0d,$3d,$0d,$3d,$0d,$3d,$0d,$36,$06,$36,$06,$36,$06,$36,$06
            db    $ff,$ff,$ff,$81,$7f,$7f,$7f,$7f,$00,$00,$00,$00,$01,$01,$01,$01
            db    $52,$55,$52,$50,$5f,$40,$3f,$00,$60,$67,$60,$60,$7f,$7f,$00,$00
            db    $00,$04,$12,$4e,$be,$fe,$f2,$c2,$00,$03,$0f,$3f,$ff,$73,$43,$43
            db    $10,$1e,$00,$3e,$7e,$fc,$fc,$00,$0e,$0e,$00,$1e,$3e,$7e,$7e,$00
            db    $00,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$7f,$7f,$7f,$7f,$7f,$7f,$00
            db    $00,$7e,$7e,$7e,$7d,$7b,$7b,$00,$00,$c0,$c0,$c0,$c0,$c1,$c1,$00
            db    $43,$7d,$00,$fc,$fb,$f7,$f7,$00,$3f,$3f,$00,$7f,$ff,$ff,$ff,$00
            db    $ff,$ff,$00,$00,$ff,$ff,$ff,$7f,$ff,$ff,$00,$ff,$ff,$ff,$ff,$00
            db    $53,$07,$4f,$03,$80,$d0,$c8,$c9,$47,$0f,$1f,$3f,$83,$d0,$d8,$d9
            db    $07,$67,$07,$67,$00,$00,$10,$c8,$0f,$0f,$0f,$0f,$0f,$00,$10,$d8
            db    $16,$a6,$c0,$e8,$f0,$0e,$01,$11,$1e,$8e,$c0,$e0,$f0,$fe,$01,$11
            db    $48,$49,$49,$49,$4b,$58,$c1,$0a,$da,$db,$db,$db,$da,$d0,$81,$06
            db    $ff,$7f,$7f,$3f,$3f,$1f,$5f,$af,$7f,$3f,$3f,$1f,$1f,$0f,$cf,$a7
            db    $7f,$7f,$bf,$bf,$df,$df,$ef,$ef,$c0,$c0,$e0,$e0,$f0,$f0,$f8,$f8
            db    $02,$32,$32,$32,$32,$32,$36,$70,$06,$66,$66,$66,$66,$66,$60,$00
            db    $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00
            db    $7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$01,$01,$01,$01,$01,$01,$01,$01
            db    $37,$37,$37,$37,$37,$00,$00,$00,$37,$37,$37,$37,$00,$00,$00,$00
            db    $cd,$cd,$dd,$e9,$e3,$f7,$00,$00,$d9,$d9,$d9,$e1,$f3,$10,$00,$00
            db    $cd,$cd,$cd,$dd,$e9,$e3,$f7,$00,$d9,$d9,$d9,$d9,$e1,$f3,$10,$00
            db    $cd,$cd,$cd,$cd,$dd,$e9,$e3,$f7,$d9,$d9,$d9,$d9,$d9,$e1,$f3,$10
            db    $00,$03,$04,$04,$04,$05,$03,$00,$00,$02,$05,$05,$05,$05,$02,$00
            db    $00,$ae,$d2,$00,$d2,$d6,$ae,$00,$00,$00,$d6,$d6,$d6,$c6,$00,$00
            db    $00,$bd,$4d,$02,$4a,$55,$b5,$03,$00,$01,$5d,$5b,$5b,$17,$07,$07
            db    $00,$00,$00,$04,$06,$0e,$06,$00,$00,$00,$04,$06,$10,$0a,$00,$00
            db    $00,$01,$24,$0a,$3a,$11,$01,$02,$00,$01,$24,$1a,$19,$02,$01,$07
            db    $00,$00,$51,$69,$bb,$9f,$4e,$fd,$00,$90,$58,$3b,$af,$4e,$ac,$fd
            db    $36,$37,$32,$31,$2c,$10,$14,$20,$32,$12,$12,$00,$00,$00,$00,$00
            db    $cd,$49,$8b,$d4,$aa,$35,$6c,$24,$59,$59,$99,$d0,$00,$00,$00,$00
            db    $4d,$cc,$6a,$d6,$b9,$00,$00,$00,$59,$98,$08,$00,$00,$00,$00,$00
            db    $4d,$4d,$cc,$4d,$cb,$aa,$25,$08,$59,$59,$18,$18,$18,$08,$00,$00
            db    $e0,$e7,$66,$f2,$f6,$52,$42,$90,$f0,$f0,$70,$60,$c0,$00,$00,$00
            db    $ff,$f7,$7f,$dd,$d8,$82,$01,$10,$00,$00,$00,$00,$00,$00,$00,$00
            db    $10,$04,$00,$02,$90,$40,$11,$02,$00,$00,$00,$00,$00,$00,$00,$00
            db    $20,$0a,$15,$06,$35,$35,$37,$37,$00,$00,$10,$00,$11,$11,$13,$33
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $98,$49,$34,$6a,$5c,$14,$95,$cd,$00,$00,$00,$08,$08,$99,$d9,$d9
            db    $30,$02,$50,$a4,$32,$57,$66,$e0,$00,$00,$00,$00,$40,$40,$c0,$e0
            db    $28,$6a,$4c,$ba,$6b,$dd,$6e,$77,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$01,$04,$12,$4e,$00,$00,$00,$00,$00,$03,$0f,$3f

; CPU address $97d2
alt_graphic_data_01 ENT
            db    $1a,$c7,$61,$24,$26,$97,$b5,$7a,$1d,$c4,$e0,$ec,$ee,$73,$73,$b9
            db    $93,$48,$95,$87,$c7,$4a,$6b,$a5,$af,$d7,$5a,$48,$a8,$2d,$4c,$b6
            db    $f1,$06,$05,$12,$03,$1b,$09,$14,$ff,$ff,$f5,$f3,$e3,$c3,$c1,$80
            db    $f3,$fc,$9e,$ff,$87,$30,$ff,$0f,$f3,$fd,$fe,$ff,$ff,$ff,$ff,$ff
            db    $80,$60,$18,$83,$f1,$3e,$c7,$1f,$80,$e0,$78,$8f,$f1,$fe,$ff,$ff
            db    $00,$00,$00,$00,$c0,$00,$c0,$fc,$00,$00,$00,$00,$c0,$00,$c0,$fc
            db    $00,$00,$00,$00,$00,$00,$00,$00,$f8,$f8,$f8,$f8,$f8,$fc,$fc,$fc
            db    $80,$80,$80,$c0,$c0,$e0,$f0,$f8,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
            db    $01,$01,$01,$03,$03,$07,$0f,$1f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
            db    $00,$00,$00,$00,$00,$00,$00,$00,$1f,$1f,$1f,$1f,$1f,$3f,$3f,$3f
            db    $60,$3c,$07,$00,$00,$00,$00,$00,$7f,$3f,$07,$00,$00,$00,$00,$00
            db    $cf,$3f,$79,$ff,$e1,$0f,$ff,$f3,$cf,$bf,$7f,$ff,$ff,$ff,$ff,$ff
            db    $c1,$03,$0f,$fe,$c0,$03,$40,$78,$ff,$ff,$ff,$fe,$c0,$03,$40,$78
            db    $35,$2a,$35,$2a,$15,$8e,$e0,$1c,$01,$00,$00,$00,$00,$80,$e0,$1c
            db    $6d,$c8,$14,$61,$5b,$f6,$22,$c5,$ed,$cd,$1c,$79,$6b,$d7,$63,$c5
            db    $5b,$32,$cc,$96,$48,$a6,$17,$df,$9c,$3d,$cf,$f7,$bf,$79,$e8,$e0
            db    $9d,$b5,$00,$67,$9f,$a3,$e1,$38,$7c,$7c,$f8,$e7,$7f,$5f,$1f,$c7
            db    $b3,$d0,$5a,$0e,$86,$a3,$60,$f0,$b3,$d8,$de,$0e,$86,$a3,$60,$f0
            db    $ac,$54,$ac,$54,$a8,$71,$07,$1e,$80,$00,$00,$00,$00,$01,$07,$1e
            db    $c0,$ce,$f1,$7f,$03,$80,$07,$7e,$ff,$ff,$ff,$7f,$03,$80,$07,$7e
            db    $3f,$01,$83,$ff,$ff,$3f,$00,$00,$ff,$ff,$ff,$ff,$ff,$3f,$00,$00
            db    $ff,$7f,$ff,$fc,$f8,$c0,$00,$00,$ff,$ff,$ff,$fc,$f8,$c0,$00,$00
            db    $e8,$18,$f4,$4c,$9e,$2e,$dc,$e0,$e8,$18,$f4,$cc,$9e,$3e,$fc,$e0
            db    $00,$00,$07,$18,$00,$74,$18,$00,$00,$00,$80,$07,$7e,$7e,$18,$00
            db    $00,$00,$e0,$18,$12,$30,$68,$42,$00,$00,$01,$e0,$f0,$fb,$e9,$42
            db    $20,$20,$00,$30,$08,$a0,$b0,$40,$c3,$c3,$71,$31,$30,$b8,$bc,$4c
            db    $00,$00,$3c,$73,$62,$21,$0c,$03,$00,$00,$3c,$4f,$5d,$3e,$0f,$03
            db    $00,$00,$00,$00,$c0,$b0,$48,$34,$00,$00,$00,$00,$c0,$70,$b8,$cc
            db    $00,$10,$18,$10,$18,$10,$42,$3c,$c3,$ad,$99,$ad,$99,$ad,$81,$c3
            db    $81,$e3,$80,$10,$21,$e1,$c8,$9e,$81,$e3,$80,$10,$21,$e1,$c8,$9e
            db    $8c,$3a,$f5,$89,$72,$45,$a6,$4a,$8e,$3f,$fe,$fe,$95,$ab,$ea,$56
            db    $38,$c3,$1c,$60,$80,$06,$47,$a9,$47,$3f,$fc,$e0,$80,$06,$47,$ef
            db    $04,$e2,$18,$06,$01,$20,$71,$49,$fb,$fd,$1f,$07,$01,$20,$71,$79
            db    $31,$dc,$13,$0d,$4f,$a6,$6b,$18,$f1,$fc,$df,$eb,$ad,$d7,$5b,$28
            db    $04,$04,$08,$08,$10,$00,$20,$00,$c3,$c3,$87,$87,$0f,$1f,$1f,$3f
            db    $00,$81,$ff,$ff,$7e,$00,$00,$00,$00,$81,$ff,$ff,$ff,$ff,$ff,$ff
            db    $3f,$e0,$df,$20,$80,$00,$07,$a9,$40,$1f,$3f,$e0,$80,$00,$07,$ef
            db    $e4,$1e,$e3,$38,$07,$00,$71,$49,$1b,$e1,$fc,$3f,$07,$00,$71,$79
            db    $00,$00,$00,$00,$44,$51,$52,$52,$00,$00,$00,$00,$4c,$7d,$6e,$6e
            db    $a4,$47,$a4,$69,$63,$c1,$ac,$a9,$64,$c7,$a7,$6e,$74,$f6,$cf,$ce
            db    $e7,$73,$5c,$ae,$43,$f0,$0f,$e7,$e7,$f3,$3c,$9e,$4f,$f0,$ff,$ff
            db    $80,$c0,$e0,$70,$50,$6c,$1e,$e0,$80,$c0,$e0,$70,$70,$7c,$1e,$e0
            db    $c3,$bd,$66,$52,$2c,$52,$52,$52,$c3,$bd,$7e,$6e,$3c,$6e,$6e,$6e
            db    $9a,$4d,$64,$32,$19,$0d,$0e,$06,$e6,$73,$7b,$3d,$1e,$0e,$0f,$07
            db    $00,$07,$08,$0b,$0a,$0a,$0a,$0a,$ff,$f8,$f7,$f7,$f6,$f6,$f6,$f6
            db    $00,$03,$05,$0b,$0e,$15,$17,$1b,$00,$03,$06,$0c,$09,$1b,$1b,$17
            db    $08,$29,$29,$2a,$a3,$a3,$d3,$5b,$14,$31,$31,$32,$ba,$ba,$da,$da
            db    $6f,$7e,$77,$77,$37,$33,$81,$cf,$a9,$b9,$98,$98,$58,$5c,$ee,$5b
            db    $6b,$bd,$fb,$7f,$6f,$6d,$c3,$60,$5b,$cf,$8d,$89,$99,$9b,$af,$32
            db    $98,$c8,$4c,$4c,$4c,$1c,$08,$08,$a8,$d8,$dc,$dc,$dc,$dc,$d8,$d8
            db    $d1,$d1,$d0,$50,$50,$50,$50,$10,$da,$da,$d9,$58,$58,$58,$58,$18
            db    $00,$e0,$10,$d0,$50,$50,$50,$50,$ff,$1f,$ef,$ef,$6f,$6f,$6f,$6f
            db    $6f,$7e,$77,$77,$37,$20,$80,$00,$a9,$b9,$98,$98,$58,$47,$e0,$40
            db    $6b,$bd,$fb,$7f,$6f,$17,$03,$00,$5b,$cf,$8d,$89,$99,$71,$05,$01
            db    $00,$00,$00,$00,$03,$0d,$12,$2c,$00,$00,$00,$00,$03,$0e,$1d,$33
            db    $00,$00,$3c,$c6,$66,$9c,$30,$c0,$00,$00,$3c,$fe,$9e,$7c,$f0,$c0
            db    $c9,$8b,$0a,$0a,$0a,$08,$08,$08,$19,$5b,$9a,$1a,$1a,$18,$18,$18
            db    $1a,$61,$30,$1f,$46,$e1,$32,$0c,$26,$7f,$3f,$1f,$46,$e3,$35,$0b
            db    $00,$00,$80,$c0,$60,$30,$98,$cc,$00,$00,$80,$c0,$e0,$f0,$78,$3c
            db    $06,$03,$00,$03,$00,$01,$00,$00,$07,$03,$01,$02,$00,$01,$00,$00
            db    $0a,$0a,$0a,$0a,$0a,$0a,$ca,$f4,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$fc
            db    $18,$1e,$14,$13,$0b,$09,$04,$01,$14,$16,$1c,$1f,$0f,$0f,$07,$01
            db    $d1,$51,$51,$11,$14,$14,$16,$12,$d8,$5a,$5d,$1d,$18,$18,$18,$1c
            db    $d7,$b6,$c7,$75,$70,$d8,$5e,$0e,$6d,$49,$79,$fb,$fe,$de,$5e,$0e
            db    $e8,$ef,$cb,$9a,$9c,$b7,$73,$60,$57,$18,$3c,$fd,$ff,$f7,$73,$60
            db    $88,$18,$88,$88,$28,$28,$68,$48,$98,$98,$b8,$b8,$18,$18,$18,$38
            db    $11,$15,$15,$15,$90,$52,$52,$db,$1b,$1b,$19,$19,$9c,$dc,$dc,$dc
            db    $50,$50,$50,$50,$50,$50,$53,$2f,$6f,$6f,$6f,$6f,$6f,$6f,$6f,$3f
            db    $80,$00,$40,$6a,$bd,$4f,$55,$19,$80,$c0,$a8,$b6,$e3,$51,$5b,$17
            db    $00,$00,$01,$03,$06,$0d,$1b,$32,$00,$00,$01,$03,$07,$0e,$1c,$3d
            db    $59,$b2,$26,$4c,$98,$30,$70,$60,$67,$ce,$de,$bc,$78,$f0,$f0,$e0
            db    $00,$07,$c7,$6c,$f8,$ea,$ce,$f4,$01,$05,$a9,$9a,$0e,$1e,$3e,$34
            db    $28,$28,$28,$a8,$89,$59,$59,$13,$98,$98,$98,$98,$b9,$39,$39,$73
            db    $00,$04,$08,$08,$10,$04,$2b,$04,$c1,$c0,$86,$86,$0e,$1f,$1b,$3c
            db    $66,$33,$1b,$0d,$86,$43,$81,$50,$9e,$cf,$67,$b3,$d9,$ac,$96,$6b
            db    $00,$00,$00,$00,$03,$00,$ff,$c7,$00,$00,$00,$00,$03,$00,$ff,$ff
            db    $f4,$f4,$f4,$f4,$f4,$f4,$74,$14,$fc,$fc,$fc,$fc,$fc,$fc,$7c,$1c
            db    $89,$31,$b9,$66,$f6,$d4,$52,$15,$f4,$ca,$4a,$95,$15,$36,$b6,$f5
            db    $09,$0c,$04,$03,$88,$52,$48,$d4,$0e,$0f,$07,$03,$88,$de,$ce,$d4
            db    $c0,$3f,$04,$fb,$1f,$00,$f0,$08,$00,$c0,$fb,$ff,$1f,$00,$f0,$f8
            db    $03,$fc,$04,$ff,$f8,$00,$0f,$30,$00,$03,$fb,$ff,$f8,$00,$0f,$3f
            db    $90,$30,$20,$c0,$01,$4a,$12,$2b,$70,$f0,$e0,$c0,$11,$7b,$73,$2b
            db    $1c,$e0,$0e,$7e,$0e,$7c,$80,$e0,$fc,$e0,$0e,$fe,$fe,$7c,$80,$e0
            db    $2f,$2f,$2f,$2f,$2f,$2f,$2e,$28,$3f,$3f,$3f,$3f,$3f,$3f,$3e,$38
            db    $01,$06,$18,$e1,$8f,$7d,$f9,$f3,$01,$07,$1e,$f1,$8f,$7f,$ff,$ff
            db    $64,$c9,$92,$25,$ca,$95,$29,$52,$7b,$f7,$ee,$dd,$3a,$77,$e9,$de
            db    $c0,$60,$80,$40,$00,$80,$00,$00,$c0,$60,$80,$c0,$00,$80,$00,$00
            db    $89,$ac,$ae,$d7,$5b,$24,$98,$47,$8e,$af,$af,$d7,$db,$e4,$78,$bf
            db    $0e,$c2,$70,$1f,$83,$c0,$3f,$00,$8e,$02,$80,$e0,$fc,$ff,$3f,$00
            db    $00,$00,$00,$1c,$00,$00,$00,$1c,$1f,$1f,$03,$03,$1f,$1f,$03,$03
            db    $00,$28,$04,$08,$03,$01,$00,$00,$0d,$32,$02,$0d,$03,$01,$00,$00
            db    $43,$90,$04,$80,$00,$20,$54,$00,$bf,$ef,$bb,$4e,$b2,$4c,$58,$00
            db    $ec,$16,$6b,$b6,$52,$a4,$da,$62,$ec,$da,$ed,$b7,$53,$e7,$bb,$7f
            db    $14,$eb,$3e,$52,$d6,$a9,$dc,$ee,$1b,$ef,$ff,$b5,$35,$6a,$5d,$6e
            db    $b9,$b1,$a6,$cd,$5b,$27,$98,$47,$b9,$bd,$ba,$d3,$d7,$e7,$78,$bf
            db    $a4,$64,$b2,$da,$48,$ad,$15,$cd,$dc,$dc,$ce,$e6,$76,$b3,$1b,$cb
            db    $2d,$5d,$51,$f6,$e6,$ec,$08,$11,$33,$63,$6f,$ce,$de,$dc,$78,$71
            db    $9d,$8d,$25,$2a,$7a,$24,$99,$e2,$9d,$9d,$3d,$3b,$7b,$27,$9e,$fd
            db    $28,$d7,$6c,$0a,$6b,$85,$23,$67,$d8,$f7,$ef,$ed,$ac,$46,$a2,$66
            db    $77,$d0,$a0,$42,$45,$49,$7b,$46,$77,$b1,$e0,$c2,$c7,$cf,$ff,$fe
            db    $d9,$f2,$1d,$72,$4d,$32,$2a,$40,$e7,$0e,$fd,$73,$4d,$36,$3a,$40
            db    $a0,$4c,$00,$b0,$80,$00,$00,$00,$b0,$5c,$60,$b0,$80,$00,$00,$00
            db    $10,$10,$10,$10,$10,$10,$91,$d1,$18,$18,$18,$18,$19,$19,$9a,$da
            db    $f0,$e1,$0e,$f8,$e1,$07,$fc,$00,$70,$e0,$01,$07,$1f,$ff,$fc,$00
            db    $b1,$31,$61,$e2,$c2,$84,$19,$e2,$71,$f1,$e1,$e3,$c3,$87,$1e,$fd
            db    $e0,$84,$99,$c3,$8e,$8e,$24,$be,$e0,$db,$e7,$ff,$fe,$fe,$3c,$be
            db    $e3,$8e,$ff,$83,$3c,$e7,$35,$80,$ff,$f1,$00,$7c,$ff,$e7,$35,$80
            db    $2a,$c4,$a2,$a1,$fb,$64,$34,$ab,$26,$dc,$61,$67,$1b,$9c,$cc,$d7
            db    $53,$ad,$ec,$cd,$99,$b5,$64,$0a,$6f,$dd,$9c,$bd,$f9,$fd,$7c,$16
            db    $34,$64,$68,$68,$68,$48,$d0,$d0,$3b,$7b,$77,$77,$77,$77,$ee,$ee
            db    $33,$0d,$ad,$93,$7d,$1d,$c0,$73,$4e,$92,$6e,$72,$fc,$1c,$c1,$f3
            db    $d5,$75,$b5,$51,$95,$65,$25,$25,$db,$fb,$7b,$bf,$fb,$7b,$3b,$3b
            db    $39,$39,$32,$32,$33,$28,$08,$88,$59,$59,$53,$53,$53,$58,$78,$f8
            db    $2c,$91,$32,$ce,$1f,$08,$03,$0e,$f2,$69,$f3,$cf,$1f,$08,$03,$0f
            db    $00,$00,$00,$38,$00,$00,$00,$38,$f8,$f8,$c0,$c0,$f8,$f8,$c0,$c0
            db    $ca,$ad,$27,$27,$19,$2f,$66,$50,$f6,$b3,$39,$39,$1f,$3f,$7e,$68
            db    $01,$a0,$13,$8d,$5f,$26,$0c,$d5,$31,$b9,$d0,$ce,$58,$39,$33,$eb
            db    $00,$c0,$a0,$d0,$70,$a8,$e8,$98,$00,$c0,$60,$30,$90,$d8,$d8,$a8
            db    $10,$2f,$e0,$0f,$78,$c0,$02,$c5,$6f,$d0,$1f,$ff,$f8,$c0,$02,$c7
            db    $e4,$de,$03,$e0,$1c,$03,$20,$51,$1b,$21,$fc,$ff,$1f,$03,$20,$71
            db    $00,$10,$4a,$2a,$28,$05,$55,$55,$10,$4a,$66,$36,$30,$03,$5b,$5b
            db    $08,$08,$08,$08,$08,$08,$89,$89,$18,$18,$18,$18,$38,$b8,$39,$39
            db    $e1,$00,$62,$8b,$19,$d1,$7e,$02,$e1,$00,$62,$8b,$19,$d1,$ff,$fd
            db    $af,$aa,$a7,$bf,$fe,$f1,$f7,$8e,$d1,$d5,$df,$df,$9e,$31,$77,$8f
            db    $8b,$c5,$f2,$f1,$00,$80,$d8,$bd,$87,$cb,$f5,$f2,$01,$80,$d8,$bd
            db    $55,$55,$55,$fd,$55,$55,$55,$fd,$56,$56,$fe,$fe,$56,$56,$fe,$fe
            db    $d4,$af,$84,$d3,$8c,$f0,$8e,$eb,$3b,$70,$1b,$5f,$0c,$70,$fe,$9f
            db    $8f,$18,$34,$69,$82,$0c,$ff,$f0,$cf,$9f,$3a,$75,$f3,$0c,$ff,$ff
            db    $aa,$aa,$aa,$bf,$aa,$aa,$aa,$bf,$6a,$6a,$7f,$7f,$6a,$6a,$7f,$7f
            db    $8b,$64,$20,$c8,$68,$1f,$62,$d0,$fc,$9f,$d8,$f8,$78,$1f,$7d,$ff
            db    $01,$03,$06,$0c,$08,$38,$60,$07,$01,$03,$07,$0e,$0e,$3e,$78,$07
            db    $d0,$a1,$43,$80,$00,$0a,$1d,$bd,$e0,$d1,$a3,$40,$80,$0a,$1d,$bd
            db    $f5,$55,$e5,$c5,$7b,$8d,$ee,$71,$8b,$ab,$fb,$fb,$7d,$8e,$ef,$f1
            db    $18,$78,$28,$48,$d0,$90,$20,$80,$28,$68,$38,$78,$f0,$f0,$e0,$80
            db    $09,$0c,$c4,$a7,$73,$18,$e0,$78,$4e,$8f,$47,$67,$f3,$18,$e0,$f8
            db    $8f,$00,$20,$40,$80,$58,$92,$a8,$ff,$ff,$bf,$cf,$c7,$c3,$83,$81
            db    $80,$15,$15,$c5,$a8,$2a,$0a,$50,$c0,$5b,$9b,$c3,$b0,$36,$06,$60
            db    $90,$31,$21,$e2,$83,$00,$07,$1e,$70,$f1,$e1,$e3,$83,$00,$07,$1f
            db    $c0,$e0,$6d,$5d,$95,$25,$25,$b6,$c0,$e0,$ed,$dd,$9d,$3d,$3d,$be
            db    $6c,$e8,$aa,$2a,$eb,$4c,$f7,$b9,$6f,$ef,$ed,$ed,$2c,$af,$97,$c9
            db    $a5,$bc,$a1,$95,$4d,$20,$f8,$c0,$bd,$a5,$bd,$9d,$cd,$e0,$f8,$c0
            db    $61,$b4,$2f,$d1,$22,$78,$23,$01,$e1,$74,$ef,$df,$3e,$78,$23,$01
            db    $95,$ea,$0c,$82,$11,$f8,$19,$f0,$eb,$fd,$0f,$83,$11,$f8,$f9,$f0
            db    $00,$00,$01,$05,$0d,$1d,$3d,$b6,$00,$00,$01,$05,$0d,$1d,$3d,$be
            db    $00,$00,$80,$d0,$98,$bc,$bc,$7e,$00,$00,$80,$d0,$98,$bc,$bc,$7e
            db    $0d,$ff,$f0,$01,$08,$1f,$19,$0d,$7f,$ff,$f0,$01,$08,$1f,$1f,$0f
            db    $82,$26,$73,$e9,$4c,$18,$c0,$80,$83,$27,$73,$f9,$7c,$18,$c0,$80
            db    $2c,$26,$16,$16,$16,$12,$0b,$0b,$dc,$de,$ee,$ee,$ee,$ee,$77,$77
            db    $74,$17,$55,$d4,$d6,$32,$ee,$1d,$f4,$f7,$b7,$37,$35,$f5,$e9,$1b
            db    $01,$85,$d4,$db,$9c,$be,$b6,$66,$01,$87,$d7,$db,$9c,$be,$be,$7e
            db    $52,$52,$52,$2c,$52,$52,$52,$52,$6e,$6e,$6e,$3c,$6e,$6e,$6e,$6e
            db    $0a,$2a,$68,$55,$04,$4a,$e0,$aa,$0d,$2c,$69,$76,$37,$5a,$c0,$9b
            db    $94,$04,$88,$29,$42,$0b,$95,$4a,$8c,$24,$98,$a9,$23,$db,$a5,$66
            db    $1c,$59,$86,$21,$4e,$92,$42,$80,$1c,$47,$da,$4f,$2d,$30,$c0,$82
            db    $a7,$af,$56,$48,$f1,$cc,$c1,$4c,$bb,$b1,$59,$4f,$f1,$fc,$ff,$73
            db    $6e,$1f,$c2,$7c,$f8,$04,$fc,$70,$7e,$1f,$c2,$fc,$f8,$04,$fc,$f0
            db    $00,$01,$07,$0e,$1c,$19,$3a,$32,$00,$01,$07,$0f,$1f,$1e,$3d,$3d
            db    $f0,$c0,$18,$60,$80,$00,$01,$02,$f0,$f0,$e3,$9f,$7c,$f8,$f0,$e1
            db    $00,$00,$07,$18,$60,$80,$00,$00,$00,$00,$80,$07,$1f,$7f,$ff,$ff
            db    $00,$f0,$10,$10,$08,$48,$04,$03,$00,$00,$e0,$e0,$b0,$b0,$f8,$fc
            db    $00,$0f,$08,$08,$10,$12,$20,$c0,$00,$00,$07,$07,$0d,$0d,$1f,$3f
            db    $00,$00,$e0,$18,$06,$01,$00,$00,$00,$00,$01,$e0,$f8,$fe,$ff,$ff
            db    $0f,$03,$18,$06,$01,$00,$80,$40,$0f,$0f,$c7,$f9,$3e,$1f,$0f,$87
            db    $00,$80,$e0,$70,$38,$98,$5c,$4c,$00,$80,$e0,$f0,$f8,$78,$bc,$bc
            db    $72,$fd,$03,$3c,$0f,$00,$0f,$06,$7e,$fd,$03,$3f,$0f,$00,$0f,$07
            db    $9c,$cc,$58,$52,$8f,$3f,$8f,$46,$fc,$bc,$b8,$b2,$8f,$3f,$ff,$be
            db    $22,$55,$7d,$24,$88,$52,$48,$d4,$26,$5d,$7d,$24,$88,$de,$ce,$d4
            db    $8a,$50,$52,$01,$21,$00,$f0,$08,$cb,$b0,$b3,$01,$61,$00,$f0,$f8
            db    $04,$41,$52,$08,$25,$a0,$4f,$30,$18,$c3,$dc,$89,$67,$e0,$4f,$3f
            db    $00,$00,$00,$80,$01,$4a,$12,$2b,$00,$00,$00,$80,$11,$7b,$73,$2b
            db    $31,$47,$70,$4e,$60,$3e,$01,$07,$3f,$47,$70,$7f,$7f,$3e,$01,$07
            db    $03,$07,$3f,$1f,$ce,$e6,$f2,$f8,$03,$07,$3f,$7f,$ff,$ff,$ff,$ff
            db    $90,$a0,$20,$40,$40,$80,$80,$80,$ee,$de,$dc,$bc,$bc,$7c,$7c,$7c
            db    $00,$00,$00,$00,$00,$00,$00,$00,$3f,$3f,$3f,$7f,$7f,$7f,$7f,$7f
            db    $00,$00,$00,$03,$0f,$3c,$78,$c3,$00,$00,$00,$03,$0f,$3e,$78,$e3
            db    $00,$0e,$39,$d7,$0e,$18,$bb,$b4,$00,$0e,$39,$f7,$cf,$1f,$bc,$bb
            db    $20,$20,$10,$10,$08,$00,$04,$00,$c3,$c3,$e1,$e1,$f0,$f8,$f8,$fc
            db    $00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
            db    $00,$e0,$98,$ee,$33,$39,$8c,$c5,$00,$e0,$98,$ee,$f3,$f9,$fc,$fd
            db    $00,$00,$00,$00,$80,$e0,$38,$0e,$00,$00,$00,$00,$80,$e0,$38,$0e
            db    $00,$00,$00,$00,$00,$00,$00,$00,$fc,$fc,$fe,$fe,$fe,$fe,$fe,$fe
            db    $09,$05,$04,$02,$02,$01,$01,$01,$77,$7b,$3b,$3d,$3d,$3e,$3e,$3e
            db    $c0,$e0,$fc,$f8,$73,$67,$4f,$1f,$c0,$e0,$fc,$fe,$ff,$ff,$ff,$ff
            db    $00,$00,$00,$c0,$f0,$f0,$f8,$30,$00,$00,$00,$c0,$f0,$f0,$f8,$30
            db    $00,$00,$00,$00,$00,$00,$7c,$ff,$00,$00,$00,$00,$00,$00,$7c,$c7
            db    $02,$00,$27,$12,$19,$14,$0b,$07,$03,$00,$27,$13,$19,$1c,$0f,$07

; CPU address $a372
alt_graphic_data_02 ENT
            db    $00,$00,$00,$06,$1a,$51,$a8,$d1,$00,$00,$01,$01,$07,$7f,$3b,$1d
            db    $00,$0b,$da,$a4,$98,$42,$08,$ab,$00,$14,$3f,$fd,$ff,$d6,$ab,$bf
            db    $00,$d0,$5b,$25,$19,$42,$10,$d5,$00,$28,$fc,$bf,$ff,$6b,$d5,$fd
            db    $00,$00,$00,$60,$58,$8a,$15,$8b,$00,$00,$80,$80,$e0,$fe,$dc,$b8
            db    $04,$0e,$13,$24,$5a,$2b,$97,$fd,$07,$09,$18,$3c,$7f,$7f,$ff,$ff
            db    $62,$33,$9a,$ed,$36,$cb,$f1,$f8,$06,$87,$42,$01,$00,$c1,$f1,$f8
            db    $76,$a0,$80,$1f,$3f,$7b,$7f,$df,$f6,$a0,$9f,$3f,$7b,$fb,$df,$5f
            db    $6e,$05,$01,$f8,$fc,$de,$fe,$fb,$6f,$05,$f9,$fc,$de,$df,$fb,$fa
            db    $46,$cc,$59,$b7,$6c,$d3,$8f,$1f,$60,$e1,$42,$80,$00,$83,$8f,$1f
            db    $20,$70,$c8,$24,$5a,$d4,$e9,$bf,$e0,$90,$18,$3c,$fe,$fe,$ff,$ff
            db    $01,$00,$01,$01,$03,$03,$00,$03,$01,$00,$01,$00,$03,$03,$00,$01
            db    $ef,$da,$0d,$81,$60,$f9,$b7,$db,$ef,$da,$6d,$99,$66,$f9,$b7,$db
            db    $a4,$50,$a9,$52,$80,$a1,$00,$00,$a4,$50,$a9,$52,$80,$a1,$00,$00
            db    $f8,$81,$73,$f1,$f0,$f4,$f2,$f8,$78,$80,$22,$71,$70,$76,$73,$78
            db    $1f,$81,$ce,$8f,$0f,$2f,$4f,$1f,$1e,$01,$44,$8e,$0e,$6e,$ce,$1e
            db    $f7,$5b,$b0,$81,$06,$9f,$ed,$db,$f7,$5b,$b6,$99,$66,$9f,$ed,$db
            db    $80,$00,$80,$80,$c0,$c0,$00,$c0,$80,$00,$80,$00,$c0,$c0,$00,$80
            db    $80,$00,$81,$50,$26,$ff,$00,$6d,$80,$7e,$81,$50,$26,$eb,$00,$6d
            db    $00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$43,$00,$93
            db    $00,$00,$00,$00,$03,$0f,$1c,$00,$00,$00,$00,$00,$03,$0e,$00,$00
            db    $00,$10,$00,$ff,$ff,$00,$00,$00,$00,$aa,$00,$ff,$91,$00,$aa,$00
            db    $00,$ff,$3c,$ff,$00,$00,$00,$00,$00,$db,$3c,$42,$00,$aa,$aa,$00
            db    $00,$00,$00,$00,$c0,$f0,$38,$00,$00,$00,$00,$00,$c0,$70,$00,$00
            db    $ba,$38,$82,$b8,$82,$b8,$02,$3a,$aa,$28,$82,$a8,$82,$a8,$02,$3a
            db    $7a,$7a,$7a,$7a,$7a,$7a,$00,$7a,$6a,$6a,$6a,$6a,$6a,$6a,$00,$6a
            db    $3d,$7d,$e0,$df,$bf,$00,$7f,$00,$3c,$60,$c0,$90,$3f,$00,$68,$00
            db    $bc,$be,$07,$fb,$fd,$00,$fe,$00,$3c,$06,$03,$09,$fc,$00,$16,$00
            db    $3a,$02,$12,$10,$10,$10,$10,$00,$3a,$02,$12,$00,$10,$00,$00,$00
            db    $00,$7a,$00,$38,$10,$10,$00,$00,$00,$6a,$00,$46,$6c,$6c,$3c,$18
            db    $7f,$3b,$00,$47,$43,$43,$41,$01,$74,$3b,$08,$58,$5c,$5c,$0e,$0e
            db    $fe,$dc,$00,$e2,$c2,$c2,$82,$80,$2e,$dc,$10,$1a,$3a,$3a,$70,$70
            db    $41,$40,$40,$40,$40,$40,$40,$40,$4e,$07,$47,$03,$01,$01,$00,$00
            db    $82,$02,$02,$02,$02,$02,$02,$02,$72,$e0,$e2,$c0,$80,$80,$00,$00
            db    $01,$01,$03,$01,$00,$00,$00,$00,$01,$01,$03,$01,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$03,$00,$03,$00,$00,$00,$00,$00,$03,$00,$01
            db    $ef,$da,$0d,$81,$60,$39,$0f,$03,$ef,$da,$6d,$99,$66,$39,$0f,$03
            db    $00,$00,$00,$00,$00,$ff,$00,$6d,$00,$00,$00,$00,$00,$eb,$00,$6d
            db    $c0,$30,$0c,$02,$00,$ff,$00,$ff,$c0,$30,$0c,$02,$00,$43,$00,$93
            db    $3f,$1a,$0d,$07,$02,$01,$00,$00,$3f,$1a,$0d,$07,$02,$01,$00,$00
            db    $20,$10,$00,$04,$00,$ff,$00,$ff,$20,$10,$00,$04,$00,$43,$00,$93
            db    $04,$06,$03,$02,$01,$01,$00,$00,$07,$05,$02,$02,$01,$01,$00,$00
            db    $64,$50,$28,$20,$10,$10,$00,$08,$64,$50,$28,$20,$10,$10,$00,$08
            db    $00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$43,$00,$93
            db    $80,$80,$c0,$80,$00,$00,$00,$00,$80,$80,$c0,$80,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$c0,$00,$c0,$00,$00,$00,$00,$00,$c0,$00,$80
            db    $f7,$5b,$b0,$81,$06,$9c,$f0,$c0,$f7,$5b,$b6,$99,$66,$9c,$f0,$c0
            db    $00,$00,$00,$00,$00,$ff,$00,$b6,$00,$00,$00,$00,$00,$d7,$00,$b6
            db    $03,$0c,$30,$40,$00,$ff,$00,$ff,$03,$0c,$30,$40,$00,$c2,$00,$c9
            db    $fc,$58,$b0,$e0,$40,$80,$00,$00,$fc,$58,$b0,$e0,$40,$80,$00,$00
            db    $04,$08,$00,$20,$00,$ff,$00,$ff,$04,$08,$00,$20,$00,$c2,$00,$c9
            db    $20,$60,$c0,$40,$80,$80,$00,$00,$e0,$a0,$40,$40,$80,$80,$00,$00
            db    $26,$0a,$14,$04,$08,$08,$00,$10,$26,$0a,$14,$04,$08,$08,$00,$10
            db    $00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$c2,$00,$c9
            db    $00,$7a,$00,$10,$00,$00,$00,$00,$00,$6a,$00,$6c,$7c,$3c,$18,$10
            db    $7f,$3b,$00,$43,$41,$41,$40,$00,$74,$3b,$08,$5c,$5e,$4e,$0f,$07
            db    $fe,$dc,$00,$c2,$82,$42,$82,$00,$2e,$dc,$10,$3a,$72,$b2,$70,$e0
            db    $40,$40,$40,$40,$40,$40,$40,$40,$47,$03,$41,$01,$00,$00,$00,$00
            db    $02,$02,$02,$02,$02,$02,$02,$02,$e2,$c0,$c2,$80,$00,$00,$00,$00

; CPU address $a712
alt_graphic_data_03 ENT
            db    $00,$06,$01,$76,$7f,$7f,$37,$17,$0f,$7f,$7f,$ff,$df,$df,$ef,$7f
            db    $03,$00,$00,$00,$01,$01,$00,$00,$7f,$1e,$00,$01,$00,$00,$00,$00
            db    $00,$00,$80,$c0,$40,$00,$90,$80,$00,$c0,$e0,$e0,$f0,$f0,$f8,$fc
            db    $80,$00,$40,$80,$08,$08,$10,$00,$ce,$1e,$be,$7e,$fc,$fc,$7c,$38
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$03,$02,$07,$07,$00,$01,$01,$01,$00,$02,$05,$00
            db    $00,$03,$03,$03,$01,$00,$00,$00,$00,$1a,$3b,$3b,$7d,$7c,$ff,$ff
            db    $00,$00,$00,$00,$00,$80,$00,$80,$ff,$ff,$fe,$ff,$ff,$7f,$3e,$bc
            db    $00,$e0,$e0,$e0,$c0,$00,$00,$00,$00,$20,$ef,$ef,$cf,$1f,$1f,$df
            db    $00,$00,$00,$00,$00,$00,$00,$00,$df,$1f,$df,$df,$9f,$1f,$0f,$0f
            db    $00,$04,$0c,$00,$04,$1c,$00,$00,$06,$f7,$f3,$f7,$f7,$e6,$f6,$f4
            db    $1c,$00,$00,$30,$00,$00,$00,$00,$e6,$f6,$e6,$dc,$ec,$ec,$d8,$f7
            db    $38,$70,$4c,$8e,$02,$00,$00,$00,$01,$fe,$cb,$8d,$3c,$70,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $03,$01,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $07,$02,$01,$00,$01,$01,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00
            db    $01,$00,$00,$01,$03,$0e,$71,$00,$00,$00,$00,$00,$01,$01,$1e,$ff
            db    $00,$d0,$c0,$10,$c0,$c0,$20,$80,$3e,$d6,$78,$16,$da,$7c,$2c,$b0
            db    $80,$00,$00,$8c,$5e,$26,$12,$90,$f8,$38,$38,$f4,$a2,$9a,$ce,$0e
            db    $00,$03,$00,$07,$07,$03,$00,$00,$0c,$08,$00,$04,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$80,$41,$98,$dc,$bd,$0b,$00,$7e,$be,$47,$99,$44,$01,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$20,$80,$c0,$d8,$c0,$e0,$e0,$d8,$7c,$9a,$47,$18
            db    $1b,$03,$01,$01,$03,$02,$0c,$00,$03,$00,$00,$00,$00,$01,$03,$3f
            db    $00,$00,$00,$00,$00,$00,$e0,$10,$00,$00,$00,$00,$00,$00,$a0,$f0
            db    $00,$e0,$10,$00,$80,$40,$00,$00,$f0,$30,$e0,$e0,$60,$a0,$e0,$c0
            db    $00,$40,$30,$18,$1e,$27,$02,$02,$00,$80,$c0,$e0,$e0,$54,$14,$0d
            db    $04,$00,$01,$01,$00,$00,$00,$00,$03,$03,$01,$00,$00,$00,$00,$00
            db    $01,$04,$0c,$10,$14,$c0,$00,$00,$00,$00,$05,$03,$14,$03,$ff,$f8
            db    $00,$40,$c0,$80,$00,$00,$00,$00,$e0,$80,$40,$80,$00,$00,$00,$00
            db    $80,$00,$80,$00,$00,$00,$00,$00,$a7,$6b,$9c,$6e,$f4,$70,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$03
            db    $00,$30,$74,$68,$10,$e0,$40,$90,$03,$05,$11,$63,$03,$c7,$4f,$3f
            db    $00,$01,$01,$01,$00,$00,$00,$00,$00,$0c,$3d,$7d,$fc,$fe,$fe,$ff
            db    $00,$00,$00,$00,$00,$00,$00,$00,$fe,$fe,$fd,$f3,$ce,$fc,$f0,$80
            db    $00,$e0,$e0,$e0,$e0,$00,$00,$00,$00,$0f,$ef,$ef,$ef,$1f,$1f,$1f
            db    $00,$00,$00,$00,$00,$00,$00,$00,$1f,$df,$9f,$8f,$0f,$0f,$07,$02
            db    $1c,$00,$1c,$00,$38,$00,$30,$00,$e7,$f3,$e7,$e6,$ce,$ee,$dc,$e9
            db    $00,$00,$00,$00,$00,$01,$78,$86,$eb,$f7,$f7,$f7,$fe,$83,$19,$02
            db    $78,$fc,$78,$00,$00,$00,$00,$00,$78,$8c,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $07,$0e,$09,$11,$00,$00,$00,$01,$00,$0f,$19,$11,$07,$0e,$00,$3f
            db    $00,$02,$02,$18,$48,$10,$60,$40,$df,$6f,$ac,$b8,$e0,$d0,$c0,$80
            db    $00,$00,$80,$c0,$40,$00,$40,$38,$20,$c0,$60,$a0,$80,$00,$f0,$c0
            db    $c0,$8c,$50,$30,$08,$08,$04,$04,$30,$70,$2c,$2e,$06,$06,$02,$02
            db    $00,$00,$00,$01,$01,$00,$00,$00,$00,$00,$00,$0d,$0d,$0e,$0f,$0f
            db    $00,$00,$00,$00,$00,$00,$00,$02,$0f,$0f,$07,$06,$06,$06,$04,$02
            db    $00,$00,$00,$f0,$f0,$e0,$00,$00,$00,$00,$01,$17,$ff,$ef,$0f,$df
            db    $00,$00,$00,$78,$84,$72,$fa,$fc,$df,$3f,$7f,$4f,$b7,$7b,$8b,$05
            db    $00,$00,$00,$01,$10,$09,$04,$01,$00,$00,$00,$01,$00,$04,$08,$04
            db    $00,$39,$60,$80,$81,$82,$be,$42,$00,$21,$56,$ee,$df,$be,$be,$42
            db    $00,$00,$ff,$fb,$0f,$e0,$2f,$e0,$00,$00,$ff,$fc,$0f,$07,$0f,$00
            db    $0f,$f0,$e0,$10,$60,$40,$fa,$83,$0f,$f0,$ef,$1e,$7d,$7d,$fb,$83
            db    $00,$00,$00,$80,$80,$00,$80,$00,$00,$00,$00,$80,$80,$80,$80,$00
            db    $00,$19,$00,$14,$0f,$00,$01,$ce,$41,$82,$3b,$e8,$f0,$ff,$ff,$fe
            db    $00,$00,$00,$00,$00,$10,$20,$40,$00,$00,$00,$00,$00,$00,$40,$a0
            db    $80,$80,$00,$00,$00,$70,$c0,$00,$40,$40,$80,$40,$e0,$f0,$c0,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $01,$00,$00,$0c,$02,$30,$22,$12,$02,$03,$07,$13,$3d,$7b,$7b,$3b
            db    $00,$00,$88,$18,$0a,$0b,$19,$00,$3c,$7d,$f5,$63,$73,$3b,$19,$00
            db    $00,$04,$0c,$00,$0e,$0c,$0c,$00,$00,$04,$0c,$00,$01,$07,$07,$0f
            db    $00,$00,$00,$42,$fc,$74,$f0,$01,$78,$fe,$ff,$bd,$03,$8c,$f0,$01
            db    $00,$f3,$f9,$78,$00,$38,$20,$00,$00,$f3,$f9,$78,$00,$04,$1c,$3c
            db    $00,$00,$00,$08,$00,$38,$20,$f8,$00,$00,$a0,$c8,$00,$38,$20,$f8
            db    $90,$f8,$f0,$00,$06,$c0,$00,$00,$90,$f8,$f0,$00,$00,$26,$e0,$00

; CPU address $ab52
alt_graphic_data_04 ENT
            db    $00,$d0,$34,$a9,$f2,$f7,$fd,$ff,$c0,$f8,$ff,$ff,$ef,$bf,$1f,$19
            db    $2f,$05,$0a,$07,$00,$00,$02,$05,$38,$1e,$0f,$07,$01,$00,$03,$06
            db    $08,$0e,$03,$00,$00,$00,$00,$00,$0f,$0f,$07,$03,$01,$00,$00,$00
            db    $2f,$15,$14,$0e,$03,$00,$00,$00,$3c,$1e,$1f,$0f,$07,$01,$00,$00
            db    $df,$ef,$af,$69,$2b,$31,$c5,$14,$f8,$94,$dd,$fe,$fc,$3e,$c6,$f7
            db    $12,$e0,$f8,$fa,$fd,$fe,$ff,$ff,$ff,$5f,$8f,$3f,$13,$8d,$42,$1c
            db    $1c,$aa,$6e,$4a,$9c,$3d,$3e,$fc,$fe,$fe,$fe,$f6,$e7,$f2,$cb,$8e
            db    $03,$1d,$30,$60,$81,$1b,$01,$69,$0c,$33,$68,$a0,$41,$9f,$3f,$7f
            db    $7f,$ce,$0b,$01,$40,$e0,$14,$88,$fc,$ff,$1f,$07,$e1,$f8,$fc,$fe
            db    $ea,$e6,$f1,$fc,$1f,$dd,$66,$09,$7f,$3f,$1f,$e3,$e2,$ff,$7f,$0f
            db    $10,$60,$82,$06,$18,$1c,$4f,$2f,$f1,$e0,$c6,$8f,$1f,$7b,$fb,$7c
            db    $de,$09,$06,$00,$00,$00,$00,$f0,$f7,$3f,$07,$00,$80,$c0,$e0,$f8
            db    $0f,$03,$02,$01,$00,$04,$05,$0e,$1c,$0e,$07,$01,$00,$06,$0f,$19
            db    $ef,$d6,$ee,$7f,$7f,$3f,$97,$57,$f9,$39,$d5,$8d,$49,$3c,$98,$db
            db    $ff,$7f,$1a,$c9,$ae,$31,$00,$00,$48,$e6,$ff,$ff,$ff,$7f,$00,$00
            db    $d1,$4b,$60,$36,$41,$00,$00,$00,$f9,$fb,$f3,$f7,$c3,$80,$00,$00
            db    $e6,$1b,$d0,$c8,$20,$03,$00,$00,$5f,$ff,$fe,$f8,$e1,$0f,$01,$00
            db    $00,$18,$24,$74,$f8,$3c,$af,$2f,$91,$18,$1e,$1f,$e7,$f3,$fb,$7c
            db    $4f,$f9,$2e,$03,$82,$00,$80,$60,$f0,$fe,$7f,$0f,$83,$c0,$e0,$e0
            db    $b0,$c3,$b1,$05,$e7,$41,$46,$81,$f1,$73,$f3,$e6,$e6,$e6,$cf,$c3
            db    $1f,$3a,$e2,$96,$14,$04,$00,$00,$13,$2e,$b2,$d6,$54,$04,$00,$00
            db    $01,$05,$0f,$1f,$33,$27,$4f,$9b,$07,$1f,$37,$3d,$70,$69,$57,$ad
            db    $80,$30,$e0,$ec,$74,$b8,$5f,$0e,$c0,$f0,$f8,$5c,$cc,$e6,$73,$1d
            db    $02,$05,$3b,$01,$00,$07,$01,$21,$13,$09,$3d,$02,$25,$1f,$03,$21
            db    $00,$00,$00,$00,$03,$19,$0f,$3e,$00,$00,$00,$03,$0f,$1e,$38,$f5
            db    $00,$0b,$3e,$9f,$7f,$f6,$60,$c0,$0f,$3f,$ff,$e9,$91,$bf,$fc,$e0
            db    $00,$02,$06,$0d,$0e,$0f,$01,$05,$01,$07,$0b,$1b,$17,$0b,$0f,$03
            db    $0e,$0e,$04,$0a,$04,$05,$07,$03,$0b,$08,$0c,$0b,$07,$0f,$1d,$1f
            db    $1a,$10,$00,$08,$08,$11,$51,$a1,$1f,$38,$23,$4f,$1f,$3f,$7f,$ff
            db    $4d,$8d,$82,$71,$dc,$96,$08,$0d,$cf,$ef,$e7,$f3,$fc,$fe,$ff,$ff
            db    $fe,$e8,$70,$83,$0f,$07,$c4,$60,$0e,$9c,$f9,$e2,$1a,$3f,$c7,$e0
            db    $f8,$f1,$f9,$c7,$a5,$28,$d9,$24,$dc,$ad,$9b,$77,$77,$ef,$df,$3f
            db    $a8,$44,$20,$73,$9c,$92,$23,$2f,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$f8
            db    $e6,$b1,$9a,$3a,$bd,$fd,$fa,$f9,$fe,$ff,$f7,$d7,$df,$97,$37,$67
            db    $40,$60,$90,$20,$b0,$48,$20,$e0,$f0,$f0,$f0,$f8,$f8,$f8,$f8,$79
            db    $04,$0a,$10,$39,$3a,$7e,$0f,$0f,$07,$1f,$3c,$4f,$77,$6b,$3e,$13
            db    $80,$c0,$dc,$7e,$15,$02,$60,$c4,$e0,$7c,$ee,$72,$9f,$c2,$f0,$fc
            db    $66,$1e,$33,$75,$4e,$08,$08,$00,$0f,$5f,$3b,$63,$47,$0f,$04,$08
            db    $01,$18,$82,$c1,$f8,$f4,$78,$3c,$06,$99,$46,$f3,$b9,$8c,$5c,$66
            db    $a1,$79,$3f,$9f,$fc,$19,$b0,$00,$7f,$b6,$58,$eb,$6f,$ff,$f8,$00
            db    $be,$fe,$f0,$f0,$c0,$00,$00,$68,$c3,$ce,$5c,$f8,$e0,$80,$00,$fc
            db    $40,$68,$26,$55,$11,$09,$1f,$2f,$44,$ea,$66,$37,$1d,$4f,$2b,$3c
            db    $07,$6e,$2e,$9c,$5c,$de,$27,$23,$1b,$7f,$73,$f6,$ee,$f3,$7b,$3d
            db    $0f,$37,$17,$17,$27,$37,$0d,$15,$1a,$3c,$39,$3a,$3e,$3d,$1e,$1e
            db    $f2,$5f,$9f,$bf,$7f,$3f,$7f,$1f,$ef,$e8,$f1,$d2,$56,$6d,$68,$38
            db    $21,$80,$58,$23,$f8,$ff,$eb,$ed,$e3,$81,$78,$ff,$ff,$96,$5c,$7f
            db    $fa,$c8,$a5,$01,$a0,$38,$cc,$f1,$8e,$f9,$e6,$07,$e0,$f8,$7d,$5d
            db    $f8,$c1,$43,$45,$19,$a8,$45,$44,$98,$f9,$e3,$c7,$1f,$ff,$ff,$ff
            db    $0f,$3f,$7f,$ff,$ff,$ff,$ff,$ff,$f7,$cc,$91,$07,$cd,$b9,$64,$86
            db    $fa,$f0,$f2,$f4,$e8,$c8,$c1,$31,$86,$6e,$ae,$1c,$1c,$b9,$7b,$f3
            db    $00,$48,$27,$68,$10,$73,$7c,$7f,$60,$7c,$7f,$ff,$ff,$9f,$b7,$c8
            db    $57,$bd,$e0,$68,$78,$bc,$1a,$1f,$6d,$cf,$99,$d8,$fc,$ee,$67,$33
            db    $f4,$fd,$f0,$18,$00,$01,$05,$af,$5f,$2f,$fe,$78,$11,$03,$8e,$fc
            db    $9c,$02,$00,$3d,$e3,$cf,$3c,$71,$df,$86,$00,$7f,$ff,$7c,$f3,$ed
            db    $5e,$5a,$5e,$b4,$cc,$38,$70,$9c,$66,$66,$e6,$ce,$3c,$fc,$6c,$f4
            db    $02,$11,$4e,$d3,$bf,$7f,$b8,$60,$0f,$3f,$ff,$fc,$f8,$e7,$d8,$63
            db    $89,$2d,$ff,$ff,$1f,$b3,$7f,$ff,$ff,$ff,$c7,$7d,$f0,$fd,$e1,$03
            db    $20,$60,$88,$90,$a0,$c1,$01,$39,$27,$73,$f1,$e0,$c0,$c0,$00,$c0
            db    $7c,$3e,$1c,$04,$00,$07,$1f,$38,$7e,$3e,$1c,$04,$00,$07,$1f,$3e
            db    $01,$05,$0c,$88,$db,$cb,$e9,$e8,$01,$05,$0e,$8f,$dc,$cc,$ee,$ee
            db    $fe,$79,$27,$1f,$bc,$b8,$60,$66,$fe,$79,$27,$1f,$bf,$bf,$7f,$79
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$01,$03,$06,$06,$04,$00,$00,$00,$00,$00,$01,$01,$0a
            db    $00,$23,$01,$01,$83,$00,$07,$1f,$06,$0c,$02,$02,$04,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$02,$05,$03,$03
            db    $00,$0d,$5d,$69,$21,$24,$4c,$12,$00,$0d,$5d,$6d,$6d,$6a,$6a,$36
            db    $a0,$c8,$54,$0e,$27,$52,$39,$9c,$e0,$c8,$5c,$0a,$65,$73,$29,$94
            db    $07,$3f,$7c,$60,$23,$91,$6c,$57,$07,$3f,$7f,$7f,$3c,$9e,$ef,$b7
            db    $00,$f0,$0c,$42,$d1,$2d,$14,$4d,$00,$f0,$fc,$be,$ef,$33,$1b,$4f
            db    $00,$30,$30,$30,$30,$60,$e0,$80,$62,$f3,$b2,$34,$38,$68,$e8,$90
            db    $00,$01,$07,$1f,$3c,$38,$60,$66,$00,$01,$07,$1f,$3f,$3f,$7f,$79
            db    $f8,$f2,$d4,$b8,$24,$50,$c8,$00,$1f,$1e,$3e,$7c,$fd,$f9,$f8,$c0
            db    $ff,$7f,$7f,$ff,$bf,$84,$6d,$12,$48,$c6,$82,$e1,$fe,$ff,$ff,$3f
            db    $ff,$fe,$f9,$f1,$0e,$08,$30,$c0,$49,$47,$a7,$1f,$ff,$fc,$f0,$e0

; ensure player sprite attributes continue to animate while paused
set_players_paused_sprite_attr ENT
            ldx #$01    ; x = #$01

:loop
            jsr set_player_paused_sprite_attr
            dex
            bpl :loop
            rts

; set player sprite based on player state, level, and animation sequence
; input
;  * x - current player
set_player_sprite_and_attrs ENT
            jsr set_player_sprite

; ensure player sprite attributes continue to animate while paused
set_player_paused_sprite_attr ENT
            lda PLAYER_HIDDEN,x    ; 0 - visible; #$01/#$ff = invisible (any non-zero)
            bne :continue    ; branch if player is hidden
            ldy PLAYER_SPRITE_CODE,x    ; player not hidden, load the player's sprite code
            lda NEW_LIFE_INVINCIBILITY_TIMER,x    ; load timer for invincibility after dying
            beq :set_y_to_player_sprite    ; branch if timer is #$00
            lda FRAME_COUNTER    ; load frame counter
            lsr
            bcc :set_y_to_player_sprite    ; branch if even frame

:continue
            ldy #$00    ; init player sprite attr to #$00 (player is either hidden, or odd frame flashing having just spawned)

:set_y_to_player_sprite
            tya    ; move player sprite code to a register
            sta PLAYER_SPRITES,x    ; update PLAYER_SPRITES with sprite from PLAYER_SPRITE_CODE
            jsr   _R2_000    ; load sprite palette based on player index
            ldy ELECTROCUTED_TIMER,x    ; counter for being electrocuted
            beq :invincibility_check    ; jump if not being electrocuted
            lda #$02    ; set sprite attr bit for player being electrocuted
            bne :continue2    ; always jump

:invincibility_check
            ldy INVINCIBILITY_TIMER,x
            beq :set_player_recoil_and_bg_priority    ; jump if not invincible
            lda #$04    ; a = #$04 (sprite code palette override bit)

:continue2
            sta $00    ; store sprite code for player in $00
            lda FRAME_COUNTER    ; load frame counter
            jsr   _R2_001
            ldy #$04    ; sprite palette #$00 (red and blue)
            and $00    ; see if sprite code palette override is set
            beq :continue3    ; branch if sprite attribute is still #$00
            ldy #$05    ; y = #$05 (override sprite code palette with palette 1)

:continue3
            tya    ; transfer sprite attribute to a

:set_player_recoil_and_bg_priority
            ldy PLAYER_BG_FLAG_EDGE_DETECT,x    ; determine if player's sprite should be behind the background
            bpl :check_sprite_recoil    ; branch if sprite is front of background
            ora #$20    ; set bit 5, the SPRITE_ATTR for background priority

:check_sprite_recoil
            ldy PLAYER_RECOIL_TIMER,x    ; see if there is any recoil effect
            beq :set_player_sprite_attr    ; skip if no recoil
            cpy #$0c    ; weapon still out/still handing recoil compare time left to #$0c
            bcc :set_player_sprite_attr    ; branch if PLAYER_RECOIL_TIMER,x < #$0c
            ora #$08    ; set bit 3, this moves the player torso down 1 pixel to simulate recoil (see SPRITE_ATTR documentation)

:set_player_sprite_attr
            sta $00
            lda PLAYER_SPRITE_FLIP,x    ; load player sprite horizontal and vertical flip flags
            and #$c8    ; keep bits xx.. x...
            ora $00
            sta SPRITE_ATTR,x    ; set the sprite modifier for player (if invincible or have electrocution effect, blink)
            rts

; determine sprite palette based on player index
; first byte is player 1
; second byte is player 2
sprite_attr_start_tbl ENT
            db    $00,$05

; first byte is player 1 effect xor value
; second byte is player 2 effect xor value
player_effect_xor_tbl ENT
            db    $00,$ff


set_player_sprite ENT
            lda PLAYER_WATER_STATE,x
            beq :set_out_of_water_sprite
            jmp set_player_water_sprite_and_state

:set_out_of_water_sprite
            lda EDGE_FALL_CODE,x
            beq :set_non_falling_player_sprite    ; branch if player isn't falling through floor or walking off ledge
            jmp set_player_sprite_05    ; sprite_05 (player falling through floor, or walk off ledge)

:set_non_falling_player_sprite
            lda PLAYER_JUMP_STATUS,x    ; low nibble 1 = jumping, 0 not jumping; high nibble = facing direction
            beq :set_sprite_for_sequence    ; set sprite when player isn't jumping
            jmp set_player_jump_sprite    ; player jumping, set appropriate sprite

:set_sprite_for_sequence
            lda LEVEL_LOCATION_TYPE    ; 0 = outdoor; 1 = indoor
            beq :set_outdoor_player_sprite_for_sequence    ; branch for outdoor level
            bmi :indoor_boss_set_player_sprite    ; branch if indoor boss screen
            jmp set_indoor_player_sprite_for_sequence    ; indoor level, set the player sprite
; based on PLAYER_SPRITE_SEQUENCE and which frame for indoor levels

:indoor_boss_set_player_sprite
            jmp indoor_boss_set_player_sprite

:set_outdoor_player_sprite_for_sequence
            ldy PLAYER_SPRITE_SEQUENCE,x    ; player animation frame
            cpy #$03
            bcs big_seq_sprite    ; branch if PLAYER_SPRITE_SEQUENCE >= #$03
            jsr   _R2_002    ; player sprite sequence is (#$00-#$03) load sprite
            jmp set_player_sprite_to_a

; sprite_0f - player walking holding weapon out
; sprite_16 - player aiming straight up
; sprite_17 - player prone
player_small_seq_sprite_tbl ENT
            db    $0f,$16,$17

big_seq_sprite ENT
            bne set_outdoor_player_death_sprite    ; branch if PLAYER_SPRITE_SEQUENCE > #$03

set_player_frame_sprite ENT
            ldy PLAYER_AIM_DIR,x    ; which direction the player is aiming/looking
            jsr   _R2_003
            bne set_player_frame_sprite_from_a
            ldy PLAYER_RECOIL_TIMER,x    ; player_frame_sprite_type_tbl was #$00, see if player has recoil still
            beq set_player_frame_sprite_from_a    ; branch if no recoil
            lda #$01    ; player has recoil, use player_frame_sprite_tbl_01

; sets the player sprite based on walking direction and aim direction
; input
;  * a - which player sprite animation to use (see player_frame_sprite_ptr_tbl)
set_player_frame_sprite_from_a ENT
            asl
            tay
            jsr   _R2_004
            sta $01
            jsr   _R2_005
            sta $02
            lda PLAYER_ANIMATION_FRAME_INDEX,x
            tay
            jsr   _I2_00
            sta PLAYER_SPRITE_CODE,x
            inc PLAYER_ANIM_FRAME_TIMER,x    ; increment #$08 player moving frame delay before moving to next animation frame
            lda PLAYER_ANIM_FRAME_TIMER,x    ; load delay between frames
            and #$07    ; see if #$08 frames have elapsed
            bne :set_player_horizontal_flip    ; branch if #$08 frames haven't elapsed
; to set PLAYER_SPRITE_FLIP bit 6 (horizontal flip) if facing left
            inc PLAYER_ANIMATION_FRAME_INDEX,x    ; #$08 frames have elapsed move to next player animation sprite
            lda PLAYER_ANIMATION_FRAME_INDEX,x    ; load player animation sprite index
            cmp #$06    ; see if past last sprite in animation
            bcc :set_player_horizontal_flip    ; branch if not past last sprite to continue
            lda #$00    ; reset player sprite index
            sta PLAYER_ANIMATION_FRAME_INDEX,x    ; reset player sprite index

:set_player_horizontal_flip
            jmp set_player_horizontal_flip    ; set PLAYER_SPRITE_FLIP bit 6 (horizontal flip) if facing left

; player aim direction offsets, specify which sprite table to use based on aim direction
; #$00 means to use player_frame_sprite_tbl_00 (walking with gun in hand)
;      unless there is still recoil from a shot, then use player_frame_sprite_tbl_01
player_frame_sprite_type_tbl ENT
            db    $00,$02,$00,$03,$00,$00,$03,$00,$02,$00

; pointer table for which sprite to load for player based on aim direction and whether there is gun recoil  (#$05 * #$02 = #$0a bytes)
player_frame_sprite_ptr_tbl ENT
            dw    player_frame_sprite_tbl_00    ; CPU address $b0d1 - walking with gun in hand
            dw    player_frame_sprite_tbl_01    ; CPU address $b0d7 - walking with gun and recoil
            dw    player_frame_sprite_tbl_02    ; CPU address $b0dd - outdoor walking aiming up
            dw    player_frame_sprite_tbl_03    ; CPU address $b0e3 - outdoor walking aiming down
            dw    player_frame_sprite_tbl_04    ; CPU address $b0e9 - indoor level

; walking with gun in hand
player_frame_sprite_tbl_00 ENT
            db    $02,$03,$04,$05,$03,$06

; outdoor walking aiming in walking direction
; sprite_0d, sprite_0e, sprite_0f
player_frame_sprite_tbl_01 ENT
            db    $0d,$0e,$0f,$0d,$0e,$0f

; outdoor walking aiming up
; sprite_10, sprite_11, sprite_12
player_frame_sprite_tbl_02 ENT
            db    $10,$11,$12,$10,$11,$12

; outdoor walking aiming down
; sprite_13, sprite_14, sprite_15
player_frame_sprite_tbl_03 ENT
            db    $13,$14,$15,$13,$14,$15

; indoor level
; sprite_51, sprite_52, sprite_53
player_frame_sprite_tbl_04 ENT
            db    $51,$52,$53,$51,$52,$53

set_outdoor_player_death_sprite ENT
            inc PLAYER_SPECIAL_SPRITE_TIMER,x    ; increment player death sprite timer
            lda PLAYER_SPECIAL_SPRITE_TIMER,x    ; load player death sprite timer
            and #$07    ; move to next animation, every #$08 frames
            bne :continue    ; don't move to next frame, timer isn't divisible by #$08
            inc PLAYER_ANIMATION_FRAME_INDEX,x    ; #$08th frame move to next sprite in animation
            lda PLAYER_ANIMATION_FRAME_INDEX,x    ; load sprite animation number
            cmp #$05    ; see if past the last frame of the animation
            bcc :continue    ; continue if not the last frame of animation
            lda #$04    ; went past last frame, show last frame of sprite (sprite_0c)
            sta PLAYER_ANIMATION_FRAME_INDEX,x    ; set sprite frame number to #$04 (sprite_0c)

:continue
            lda PLAYER_ANIMATION_FRAME_INDEX,x    ; load sprite animation frame number
            asl    ; double since each entry in player_death_sprite_tbl is #$02 bytes
            tay    ; transfer to y for offset
            jsr   _R2_006    ; load sprite_code
            sta PLAYER_SPRITE_CODE,x    ; set sprite code
            jsr   _R2_007    ; load sprite attributes
            sta PLAYER_SPRITE_FLIP,x    ; store whether sprite is flipped horizontally and/or vertically
            lda PLAYER_DEATH_FLAG,x    ; player death flag
            and #$02    ; keep bit 1 (player facing left when hit flag)
            beq :exit    ; branch to not flip sprite if player was facing right when hit
            lda PLAYER_SPRITE_FLIP,x    ; facing left when hit, load player sprite horizontal and vertical flip flags
            eor #$40    ; flip bit 6 (swap horizontal flip direction)
            sta PLAYER_SPRITE_FLIP,x    ; save updated horizontal flip information

:exit
            rts

; PLAYER_SPRITE_CODE and sprite horizontal/vertical flip data (#$0a bytes)
; byte 0 - PLAYER_SPRITE_CODE
; byte 1 - SPRITE_ATTR
player_death_sprite_tbl ENT
            db    $0a,$00    ; sprite_0a - player hit (frame 1) (sprite_0a)
            db    $0b,$00    ; sprite_0b - player hit (frame 2) (sprite_0b)
            db    $0a,$c0    ; sprite_0a - player hit (frame 1) (sprite_0a) - flip vertically and horizontally
            db    $0b,$c0    ; sprite_0b - player hit (frame 2) (sprite_0b) - flip vertically and horizontally
            db    $0c,$00    ; sprite_0c - player lying on ground (sprite_0c)

set_player_sprite_05 ENT
            lda #$05    ; a = #$05 (sprite_05) - player walking (frame 4)

set_player_sprite_to_a ENT
            sta PLAYER_SPRITE_CODE,x    ; load player sprite (sprite code)

set_player_horizontal_flip ENT
            lda PLAYER_SPRITE_FLIP,x    ; load player sprite horizontal and vertical flip flags
            and #$3f    ; keep bits 6 and 7 (horizontal and vertical flip bits respectively)
            ldy PLAYER_AIM_DIR,x    ; which direction the player is aiming/looking
            cpy #$05    ; compare to crouching facing left
            bcc :continue    ; branch if player facing right
            ora #$40    ; player is facing left, set horizontal flip bit (bit 6)

:continue
            sta PLAYER_SPRITE_FLIP,x    ; store whether sprite is flipped horizontally and/or vertically
            rts

; sets appropriate curled up player sprite for jumping
set_player_jump_sprite ENT
            lda PLAYER_JUMP_STATUS,x    ; low nibble 1 = jumping, 0 not jumping; high nibble = facing direction
            asl    ; shift bit 7 to carry (jumping left flag)
            lda #$00    ; a = #$00 (no horizontal sprite flip)
            bcc :continue    ; continue if jumping right
            lda #$40    ; jumping left, set bit 6 (sprite horizontal flip bit)

:continue
            sta $08    ; set sprite flip bit information in $08
            lda PLAYER_SPRITE_FLIP,x    ; load player sprite horizontal and vertical flip flags
            and #$3f    ; clear PLAYER_SPRITE_FLIP horizontal and vertical flip bits
            ldy PLAYER_ANIMATION_FRAME_INDEX,x    ; load which frame of the player animation
            cpy #$02
            bcc :set_sprite_inc_frame
            ora #$c0    ; flip vertically and horizontally

:set_sprite_inc_frame
            eor $08    ; merge with sprite bit flip information, use eor in case a flip of a flip is needed
            sta PLAYER_SPRITE_FLIP,x    ; store whether sprite is flipped horizontally and/or vertically
            ldy PLAYER_ANIMATION_FRAME_INDEX,x    ; load the current animation frame of the jumping curl
            jsr   _R2_008    ; load specific curled player sprite
            sta PLAYER_SPRITE_CODE,x    ; set player sprite curl (sprite code)
            inc PLAYER_SPECIAL_SPRITE_TIMER,x
            lda PLAYER_SPECIAL_SPRITE_TIMER,x
            cmp #$05
            bcc :exit
            lda #$00    ; a = #$00
            sta PLAYER_SPECIAL_SPRITE_TIMER,x
            inc PLAYER_ANIMATION_FRAME_INDEX,x
            lda PLAYER_ANIMATION_FRAME_INDEX,x
            cmp #$04
            bcc :set_anim_frame_exit
            lda #$00    ; a = #$00

:set_anim_frame_exit
            sta PLAYER_ANIMATION_FRAME_INDEX,x

:exit
            rts

; table for player animation frames when spinning during a jump (#$04 bytes)
; sprite_08, sprite_09
player_curled_sprite_code_tbl ENT
            db    $08,$09,$08,$09

set_player_water_sprite_and_state ENT
            lda PLAYER_WATER_STATE,x
            and #$04    ; keep bits .... .x..
            bne set_player_in_water_sprite    ; branch if set player fully in water or walking out of water
            lda PLAYER_WATER_STATE,x    ; bit 2 clear, player entering water, load player water state
            and #$10    ; keep bit 4
            bne :set_enter_water_sprite    ; branch if bit 4 set
            lda #$00    ; branch 4 clear, entering water for first time, set a = #$00
            sta PLAYER_ANIMATION_FRAME_INDEX,x    ; initialize frame index to #$00
            lda #$05    ; a = #$05 (sprite_05) - player walking (frame 4)
            sta PLAYER_SPRITE_CODE,x    ; set player sprite code, player standing for #$08 frames before splash
            lda SPRITE_Y_POS,x    ; player Y position on screen
            clc    ; clear carry in preparation for addition
            adc #$10    ; move down #$10 pixels
            sta SPRITE_Y_POS,x    ; update player Y position on screen
            lda PLAYER_AIM_DIR,x    ; which direction the player is aiming/looking
            cmp #$05    ; see if facing left or right
            bcc :continue    ; branch if facing right
            lda PLAYER_WATER_STATE,x    ; player facing left, load current PLAYER_WATER_STATE
            ora #$02    ; set bit 1 to signify sprite flip needed during animation
            sta PLAYER_WATER_STATE,x    ; update PLAYER_WATER_STATE

:continue
            lda #$10    ; a = #$10
            sta PLAYER_WATER_TIMER,x    ; set entering water animation timer to #$10
            lda PLAYER_WATER_STATE,x    ; load player water state
            ora #$90    ; set bits x..x ...., specifies initialized water entrance animation
            sta PLAYER_WATER_STATE,x    ; update player water state

:set_enter_water_sprite
            lda #$00    ; a = #$00
            sta PLAYER_X_VELOCITY,x    ; stop player X velocity
            lda PLAYER_WATER_TIMER,x    ; load water animation timer
            beq set_player_in_water_sprite    ; if timer has elapsed, branch to set the correct sprite
            cmp #$0c    ; see if timer is greater than or equal to #$0c
            bcs set_player_water_sprite_flip    ; branch if timer >= #$0c to set player sprite flip (horizontal flip) for standing up above water
            lda #$73    ; PLAYER_WATER_TIMER less than #$0c, set splash sprite
            sta PLAYER_SPRITE_CODE,x    ; set player sprite (sprite_73) water splash
            cmp #$08    ; !(BUG?) always branch, doesn't compare to PLAYER_WATER_TIMER, but instead compares against #$73
; no lda PLAYER_WATER_TIMER,x before this line, so part of splash animation is missing
; same issue appears in Probotector and Japanese version of game
            bcs set_player_water_sprite_flip    ; always branch, branch to set player sprite attribute to ensure horizontal direction is correct
            lda #$18    ; dead code - a = #$18 (sprite_18) water splash/puddle
            sta PLAYER_SPRITE_CODE,x    ; dead code - set player animation frame to water splash/puddle

set_player_water_sprite_flip ENT
            dec PLAYER_WATER_TIMER,x    ; decrement water animation timer
            lda PLAYER_WATER_STATE,x    ; load player water state
            and #$02    ; keep bit 1 (horizontal flip flag)
            beq :exit    ; exit if no horizontal flip
            lda PLAYER_SPRITE_FLIP,x    ; load player sprite horizontal and vertical flip flags
            ora #$40    ; set horizontal flip (bit 6)
            sta PLAYER_SPRITE_FLIP,x    ; set sprite horizontal flip

:exit
            rts

; set sprite for player in water or walking out of water
set_player_in_water_sprite ENT
            lda PLAYER_WATER_STATE,x    ; load player water state
            and #$08    ; keep bit 3 (player walking out of water flag)
            beq :set_player_water_sprite_and_state    ; branch if player is not walking out of water
            jmp player_walk_out_of_water    ; jump if player is walking out of water

:set_player_water_sprite_and_state
            lda PLAYER_WATER_STATE,x    ; load player water state
            ora #$04    ; set bit 2
            and #$7f    ; strip bit 7
            sta PLAYER_WATER_STATE,x    ; update player water state
            lda PLAYER_AIM_DIR,x    ; which direction the player is aiming/looking
            asl    ; double since each entry is #$02 bytes
            tay    ; transfer offset to y
            lda PLAYER_RECOIL_TIMER,x    ; load current player recoil timer
            beq :in_water_not_firing    ; branch if no recoil timer
            jsr   _R2_009    ; player is firing, show firing sprite code
            sta PLAYER_SPRITE_CODE,x    ; load player sprite (sprite code)
            jsr   _R2_00a    ; load PLAYER_SPRITE_FLIP flag (whether to flip the sprite horizontally)
            jmp :set_sprite_flip_check_collision    ; set PLAYER_SPRITE_FLIP, check if collision with ground

:in_water_not_firing
            jsr   _R2_00b    ; load non-firing player in water sprite code
            sta PLAYER_SPRITE_CODE,x    ; load player sprite (sprite code)
            jsr   _R2_00c    ; load non-firing player in water sprite attribute

; input
;  * a - PLAYER_SPRITE_FLIP horizontal and vertical flip values (bit 6 and 7)
:set_sprite_flip_check_collision
            sta $01    ; set to whether to flip the sprite horizontally or vertically
            lda PLAYER_SPRITE_FLIP,x    ; load current player sprite horizontal and vertical flip flags
            and #$0f    ; strip high nibble
            ora $01    ; merge updated horizontal and vertical flip bits
            sta PLAYER_SPRITE_FLIP,x    ; set whether sprite is flipped horizontally and/or vertically
            lda FRAME_COUNTER    ; load frame counter
            and #$0f    ; keep bits .... xxxx
            bne :check_anim_frame_and_collision    ; continue if not the #$fth frame
            inc PLAYER_ANIMATION_FRAME_INDEX,x    ; move to next animation every #$0f frames

:check_anim_frame_and_collision
            lda PLAYER_ANIMATION_FRAME_INDEX,x    ; load frame of the player animation
            and #$01    ; keep bit 0
            bne :clear_sprite_flip_check_collision    ; branch if odd player animation frame
            lda PLAYER_SPRITE_FLIP,x    ; load player sprite horizontal and vertical flip flags
            ora #$08    ; set bit 3
            bne :check_ground_collision    ; always branch, see if player has collided with the ground
; and should begin animation to step out of water

:clear_sprite_flip_check_collision
            lda PLAYER_SPRITE_FLIP,x    ; load player sprite horizontal and vertical flip flags
            and #$f7    ; strip bit 3

:check_ground_collision
            sta PLAYER_SPRITE_FLIP,x    ; store whether sprite is flipped horizontally and/or vertically
            lda SPRITE_Y_POS,x    ; load player Y position on screen
            tay    ; transfer Y position to y
            lda SPRITE_X_POS,x    ; load player X position on screen
            jsr get_bg_collision    ; determine player background collision code at position (a,y)
            cmp #$02    ; see if collision code #$02 (water)
            beq :exit    ; exit if in water
            lda PLAYER_WATER_STATE,x    ; player colliding with land, set transition to start walking out of water
            ora #$88    ; set bits 3 and 7 to signal walking out of water
            sta PLAYER_WATER_STATE,x    ; update player water state
            lda #$0c    ; set timer to animate player walking out of water
            sta PLAYER_WATER_TIMER,x    ; update timer
            lda #$1a    ; a = #$1a (sprite_1a) player climbing out of water
            sta PLAYER_SPRITE_CODE,x    ; set player sprite to be climbing out of water
            lda PLAYER_AIM_DIR,x    ; which direction the player is aiming/looking
            cmp #$05    ; determine facing direction
            bcc :clear_horizontal_flip_exit    ; branch if player is facing right
            lda PLAYER_WATER_STATE,x    ; player is facing left, flip player sprite horizontally
            ora #$02    ; set bit 1 (horizontal flip flag)
            bne :set_horizontal_flip_flag_exit    ; set bit 1 in PLAYER_WATER_STATE and exit

:clear_horizontal_flip_exit
            lda PLAYER_WATER_STATE,x    ; load player water transition data
            and #$fd    ; strip bit 1 (horizontal flip flag)

:set_horizontal_flip_flag_exit
            sta PLAYER_WATER_STATE,x    ; set horizontal flip flag

:exit
            rts

; logic when player is walking out of water
; moves player forward and sets appropriate sprite
; executed repeatedly until PLAYER_WATER_TIMER,x is #$00
player_walk_out_of_water ENT
            lda #$06    ; !(OBS) unnecessary, because overwritten to #$00 by handle_player_state_calc_x_vel
            sta PLAYER_X_VELOCITY,x    ; unnecessary, set player X velocity to #$06
            lda PLAYER_WATER_TIMER,x    ; load animation timer
            beq clear_water_vars_set_y_pos    ; timer elapsed, player is now out of water
            cmp #$05    ; timer not elapsed, see if less than #$05
            bcc :almost_out_of_water    ; branch if timer is almost elapsed to set player standing sprite
            jmp set_player_water_sprite_flip    ; set player sprite attribute to ensure horizontal direction is correct

:almost_out_of_water
            lda #$05    ; a = #$05 (sprite_05) player walking (frame 4)
            sta PLAYER_SPRITE_CODE,x    ; set player sprite to walking frame
            jmp set_player_water_sprite_flip    ; set player sprite attribute to ensure horizontal direction is correct
            dec PLAYER_WATER_TIMER,x    ; decrement animation timer
            rts

; player out of water, clear water variables and adjust Y position to be on land
clear_water_vars_set_y_pos ENT
            lda #$00    ; a = #$00
            sta PLAYER_WATER_STATE,x    ; clear player in water animation
            sta PLAYER_ANIMATION_FRAME_INDEX,x    ; set player frame to first frame of walking
            lda SPRITE_Y_POS,x    ; player Y position on screen
            sec    ; set carry flag in preparation for subtraction
            sbc #$10    ; move player up so that they are on the ground and out of the water
            sta SPRITE_Y_POS,x
            rts

; table for sprites and sprite flip values for player in water when not firing (#$14 bytes)
; (cf. player_water_firing_sprite_tbl)
; each entry is for a specific PLAYER_AIM_DIR [#$00-#$09]
; sprite_19, sprite_18
player_water_sprite_tbl ENT
            db    $19,$00    ; up facing right   - sprite_19 - player in water
            db    $19,$00    ; up right          - sprite_19 - player in water
            db    $19,$00    ; right             - sprite_19 - player in water
            db    $18,$00    ; down right        - sprite_18 - water splash/puddle
            db    $18,$00    ; down facing right - sprite_18 - water splash/puddle
            db    $18,$40    ; down facing left  - sprite_18 - water splash/puddle (flipped horizontally)
            db    $18,$40    ; down left         - sprite_18 - water splash/puddle (flipped horizontally)
            db    $19,$40    ; left              - sprite_19 - player in water (flipped horizontally)
            db    $19,$40    ; left up           - sprite_19 - player in water (flipped horizontally)
            db    $19,$40    ; left facing up    - sprite_19 - player in water (flipped horizontally)

; table for sprites and sprite flip values for player in water and firing (#$14 bytes)
; (cf. player_water_sprite_tbl)
; each entry is for a specific PLAYER_AIM_DIR [#$00-#$09]
; sprite_18, sprite_1b, sprite_1c, sprite_1d
player_water_firing_sprite_tbl ENT
            db    $1b,$00    ; up facing right   - sprite_1b - player in water aiming straight up
            db    $1c,$00    ; up right          - sprite_1c - player in water aiming angled up
            db    $1d,$00    ; right             - sprite_1d - player in water aiming forward
            db    $18,$00    ; down right        - sprite_18 - water splash/puddle
            db    $18,$00    ; down facing right - sprite_18 - water splash/puddle
            db    $18,$40    ; down facing left  - sprite_18 - water splash/puddle (flipped horizontally)
            db    $18,$40    ; down left         - sprite_18 - water splash/puddle (flipped horizontally)
            db    $1d,$40    ; left              - sprite_1d - player in water aiming forward (flipped horizontally)
            db    $1c,$40    ; left up           - sprite_1c - player in water aiming angled up (flipped horizontally)
            db    $1b,$40    ; left facing up    - sprite_1b - player in water aiming straight up (flipped horizontally)

; sets the appropriate player sprite based on which sequence and which frame for indoor levels
set_indoor_player_sprite_for_sequence ENT
            lda PLAYER_SPRITE_SEQUENCE,x
            jsr run_routine_from_tbl_below    ; run routine a in the following table (indoor_player_sprite_tbl)

; pointer table for setting appropriate player sprite (#$08 * #$02 = #$10 bytes)
indoor_player_sprite_tbl ENT
            dw    player_sprite_indoor_facing_up    ; CPU address $b2c6
            dw    player_sprite_indoor_electrocuted    ; CPU address $b2ca
            dw    player_sprite_indoor_crouch    ; CPU address $b2ce
            dw    player_sprite_indoor_walking_animation    ; CPU address $b2b9
            dw    player_sprite_indoor_walking_animation    ; CPU address $b2b9
            dw    player_sprite_indoor_walking_to_back    ; CPU address $b2d3
            dw    player_sprite_indoor_dead    ; CPU address $b2ec
            dw    player_sprite_indoor_elevator    ; CPU address $b2c2 !(UNUSED)

player_sprite_indoor_walking_animation ENT
            lda PLAYER_RECOIL_TIMER,x
            beq :continue
            lda #$04    ; a = #$04

; indoor level, set player sprite based on aim direction
:continue
            jmp set_player_frame_sprite_from_a    ; player_frame_sprite_tbl_04

; unused !(UNUSED)
; elevator sprite is set with (set_player_on_elevator_sprite)
; sprite elevator isn't used on non-boss indoor level
player_sprite_indoor_elevator ENT
            lda #$91    ; a = #$91 (sprite_91) indoor boss defeated elevator with player on top
            bne set_player_sprite_code_to_a

player_sprite_indoor_facing_up ENT
            lda #$50    ; a = #$50 (sprite_50) indoor player facing up
            bne set_player_sprite_code_to_a

player_sprite_indoor_electrocuted ENT
            lda #$55    ; a = #$55 (sprite_55) indoor player electrocuted
            bne set_player_sprite_code_to_a

player_sprite_indoor_crouch ENT
            lda #$54    ; a = #$54 (sprite_54) indoor player crouch

set_player_sprite_code_to_a ENT
            sta PLAYER_SPRITE_CODE,x    ; load player sprite (sprite code)
            rts

player_sprite_indoor_walking_to_back ENT
            dec PLAYER_ANIM_FRAME_TIMER,x
            bpl :continue
            lda #$03    ; a = #$03 (sound_03)
            jsr play_sound    ; play player landing on ground or water sound
            lda #$0a    ; a = #$0a
            sta PLAYER_ANIM_FRAME_TIMER,x
            inc PLAYER_ANIMATION_FRAME_INDEX,x

:continue
            lda PLAYER_ANIMATION_FRAME_INDEX,x
            and #$01    ; keep bits .... ...x
            clc    ; clear carry in preparation for addition
            adc #$57    ; a = #$57 (sprite_57) indoor player running
            sta PLAYER_SPRITE_CODE,x    ; load player sprite (sprite code)
            rts

player_sprite_indoor_dead ENT
            lda PLAYER_SPECIAL_SPRITE_TIMER,x
            cmp #$1b
            lda #$56    ; a = #$56 (sprite_56) indoor player lying dead (frame #$02)
            bcs :continue
            inc PLAYER_SPECIAL_SPRITE_TIMER,x
            lda #$55    ; a = #$55 (sprite_55) indoor player hit by bullet frame #$01

:continue
            sta PLAYER_SPRITE_CODE,x    ; load player sprite (sprite code) sprite_55, or sprite_56
            lda #$00    ; a = #$00
            sta PLAYER_SPRITE_FLIP,x    ; store whether sprite is flipped horizontally and/or vertically
            rts

indoor_boss_set_player_sprite ENT
            lda PLAYER_SPRITE_SEQUENCE,x
            jsr run_routine_from_tbl_below    ; run routine a in the following table (indoor_boss_player_sprite_tbl)

; pointer table for ? (#$05 * #$02 = #$0a bytes)
indoor_boss_player_sprite_tbl ENT
            dw    indoor_boss_player_aiming_up_sprite    ; CPU address $b30e
            dw    indoor_boss_player_aiming_up_sprite    ; CPU address $b30e
            dw    indoor_boss_player_aiming_up_sprite    ; CPU address $b30e
            dw    set_player_frame_sprite    ; CPU address $b086
            dw    player_sprite_indoor_dead    ; CPU address $b2ec

indoor_boss_player_aiming_up_sprite ENT
            lda PLAYER_SPRITE_FLIP,x    ; load player sprite horizontal and vertical flip flags
            and #$3f    ; keep bits ..xx xxxx
            sta PLAYER_SPRITE_FLIP,x    ; store whether sprite is flipped horizontally and/or vertically
            lda #$50    ; a = #$50 (sprite_50) indoor player facing up
            sta PLAYER_SPRITE_CODE,x    ; load player sprite (sprite code)
            rts

; Level Headers - A description of each level
; loaded into memory by load_level_header in bank 7
; Level 1 - jungle
level_headers ENT
level_1_header ENT
            db    $00    ; location type: outdoor level (0 = outdoor ; 1 = indoor ; ff = indoor boss room) (LEVEL_LOCATION_TYPE)
            db    $00    ; outdoor scrolling type: horizontal scroll (0 = horizontal ; 1 = vertical)
            dw    level_1_supertiles_screen_ptr_table    ; pointer to which super-tiles are on each screen (bank 2 memory address) (see LEVEL_SCREEN_SUPERTILES_PTR)
            dw    level_1_supertile_data    ; composition of super-tiles (bank 3 memory address) (see LEVEL_SUPERTILE_DATA_PTR)
            dw    level_1_palette_data    ; super-tile palette data (bank 3 memory address) (see LEVEL_SUPERTILE_PALETTE_DATA)
            db    $0b    ; alternate graphics loading (+2) (screen where they start loading) (see LEVEL_ALT_GRAPHICS_POS)
            db    $06,$f9,$ff    ; tile collision limits (see COLLISION_CODE_X_TILE_INDEX)
            db    $05,$08,$05,$08    ; palette indexes into game_palettes for cycling the 4th nametable palette index (see LEVEL_PALETTE_CYCLE_INDEXES)
            db    $02,$03,$04,$05    ; indexes into game_palettes specifying initial background tile palette colors (see LEVEL_PALETTE_INDEX)
            db    $00,$01,$22,$07    ; indexes into game_palettes specifying sprite palette colors (see LEVEL_PALETTE_INDEX)
            db    $0b    ; section to stop scrolling at (+2) (level length) (see LEVEL_STOP_SCROLL)
            db    $00    ; specifies whether to check for bullet and/or weapon item solid bg collisions (LEVEL_SOLID_BG_COLLISION_CHECK)
            db    $00,$00,$00,$00,$00,$00    ; unused

; header for level 2 - base 1
level_2_header ENT
            db    $01    ; location type: indoor level (0 = outdoor ; 1 = indoor ; ff = indoor boss room)
            db    $00    ; outdoor scrolling type: not used for indoor level
            dw    level_2_supertiles_screen_ptr_table    ; pointer to which super-tiles are on each screen (bank 2 memory address) (see LEVEL_SCREEN_SUPERTILES_PTR)
            dw    level_2_supertile_data    ; composition of super-tiles (bank 3 memory address) (see LEVEL_SUPERTILE_DATA_PTR)
            dw    level_2_palette_data    ; super-tile palette data (bank 3 memory address) (see LEVEL_SUPERTILE_PALETTE_DATA)
            db    $04    ; alternate graphics loading (+2) (screen where they start loading) (see LEVEL_ALT_GRAPHICS_POS)
            db    $00,$ff,$ff    ; tile collision limits (see COLLISION_CODE_X_TILE_INDEX) (all tiles are empty collision code for indoor/base levels)
            db    $24,$28,$29,$28    ; palette indexes into game_palettes for cycling the 4th nametable palette index (see LEVEL_PALETTE_CYCLE_INDEXES)
            db    $09,$0a,$04,$24    ; indexes into game_palettes specifying initial background tile palette colors (see LEVEL_PALETTE_INDEX)
            db    $00,$01,$22,$2a    ; indexes into game_palettes specifying sprite palette colors (see LEVEL_PALETTE_INDEX)
            db    $05    ; section to stop scrolling at (+2) (level length) (see LEVEL_STOP_SCROLL)
            db    $00    ; specifies whether to check for bullet and/or weapon item solid bg collisions (LEVEL_SOLID_BG_COLLISION_CHECK)
            db    $00,$00,$00,$00,$00,$00    ; unused

; header for level 3 - waterfall
level_3_header ENT
            db    $00    ; location type: outdoor level (0 = outdoor ; 1 = indoor ; ff = indoor boss room) (LEVEL_LOCATION_TYPE)
            db    $01    ; scrolling type: vertical scroll (0 = horizontal ; 1 = vertical)
            dw    level_3_supertiles_screen_ptr_table    ; pointer to which super-tiles are on each screen (bank 2 memory address) (see LEVEL_SCREEN_SUPERTILES_PTR)
            dw    level_3_supertile_data    ; composition of super-tiles (bank 3 memory address) (see LEVEL_SUPERTILE_DATA_PTR)
            dw    level_3_palette_data    ; super-tile palette data (bank 3 memory address) (see LEVEL_SUPERTILE_PALETTE_DATA)
            db    $07    ; alternate graphics loading (+2) (screen where they start loading) (see LEVEL_ALT_GRAPHICS_POS)
            db    $07,$ff,$ff    ; tile collision limits (see COLLISION_CODE_X_TILE_INDEX)
            db    $0d,$0e,$0f,$00    ; palette indexes into game_palettes for cycling the 4th nametable palette index (see LEVEL_PALETTE_CYCLE_INDEXES)
            db    $0b,$0c,$04,$0d    ; indexes into game_palettes specifying initial background tile palette colors (see LEVEL_PALETTE_INDEX)
            db    $00,$01,$22,$07    ; indexes into game_palettes specifying sprite palette colors (see LEVEL_PALETTE_INDEX)
            db    $07    ; section to stop scrolling at (+2) (level length) (see LEVEL_STOP_SCROLL)
            db    $00    ; specifies whether to check for bullet and/or weapon item solid bg collisions (LEVEL_SOLID_BG_COLLISION_CHECK)
            db    $00,$00,$00,$00,$00,$00    ; unused

; header for level 4 - base 2
level_4_header ENT
            db    $01    ; location type: indoor level (0 = outdoor ; 1 = indoor ; ff = indoor boss room)
            db    $00    ; outdoor scrolling type: not used for indoor level
            dw    level_4_supertiles_screen_ptr_table    ; pointer to which super-tiles are on each screen (bank 2 memory address) (see LEVEL_SCREEN_SUPERTILES_PTR)
            dw    level_4_supertile_data    ; composition of super-tiles (bank 3 memory address) (see LEVEL_SUPERTILE_DATA_PTR) (same as level 2)
            dw    level_4_palette_data    ; super-tile palette data (bank 3 memory address) (see LEVEL_SUPERTILE_PALETTE_DATA) (same as level 2)
            db    $07    ; alternate graphics loading (+2) (screen where they start loading) (see LEVEL_ALT_GRAPHICS_POS)
            db    $00,$ff,$ff    ; tile collision limits (see COLLISION_CODE_X_TILE_INDEX) (all tiles are empty collision code for indoor/base levels)
            db    $2e,$2f,$30,$2f    ; palette indexes into game_palettes for cycling the 4th nametable palette index (see LEVEL_PALETTE_CYCLE_INDEXES)
            db    $2c,$2d,$04,$2e    ; indexes into game_palettes specifying initial background tile palette colors (see LEVEL_PALETTE_INDEX)
            db    $00,$01,$22,$2a    ; indexes into game_palettes specifying sprite palette colors (see LEVEL_PALETTE_INDEX)
            db    $08    ; section to stop scrolling at (+2) (level length) (see LEVEL_STOP_SCROLL)
            db    $00    ; specifies whether to check for bullet and/or weapon item solid bg collisions (LEVEL_SOLID_BG_COLLISION_CHECK)
            db    $00,$00,$00,$00,$00,$00    ; unused

; header for level 5 - snow field
level_5_header ENT
            db    $00    ; location type: outdoor level (0 = outdoor ; 1 = indoor ; ff = indoor boss room) (LEVEL_LOCATION_TYPE)
            db    $00    ; outdoor scrolling type: horizontal scroll (0 = horizontal ; 1 = vertical)
            dw    level_5_supertiles_screen_ptr_table    ; pointer to which super-tiles are on each screen (bank 2 memory address) (see LEVEL_SCREEN_SUPERTILES_PTR)
            dw    level_5_supertile_data    ; composition of super-tiles (bank 3 memory address) (see LEVEL_SUPERTILE_DATA_PTR)
            dw    level_5_palette_data    ; super-tile palette data (bank 3 memory address) (see LEVEL_SUPERTILE_PALETTE_DATA)
            db    $13    ; alternate graphics loading (+2) (screen where they start loading) (see LEVEL_ALT_GRAPHICS_POS)
            db    $20,$f0,$f0    ; tile collision limits (see COLLISION_CODE_X_TILE_INDEX)
            db    $62,$63,$62,$63    ; palette indexes into game_palettes for cycling the 4th nametable palette index (see LEVEL_PALETTE_CYCLE_INDEXES)
            db    $3d,$3e,$04,$62    ; indexes into game_palettes specifying initial background tile palette colors (see LEVEL_PALETTE_INDEX)
            db    $00,$01,$22,$07    ; indexes into game_palettes specifying sprite palette colors (see LEVEL_PALETTE_INDEX)
            db    $13    ; section to stop scrolling at (+2) (level length) (see LEVEL_STOP_SCROLL)
            db    $01    ; specifies whether to check for bullet and/or weapon item solid bg collisions (LEVEL_SOLID_BG_COLLISION_CHECK)
            db    $00,$00,$00,$00,$00,$00    ; unused

; header for level 6 - energy zone
level_6_header ENT
            db    $00    ; location type: outdoor level (0 = outdoor ; 1 = indoor ; ff = indoor boss room) (LEVEL_LOCATION_TYPE)
            db    $00    ; outdoor scrolling type: horizontal scroll (0 = horizontal ; 1 = vertical)
            dw    level_6_supertiles_screen_ptr_table    ; pointer to which super-tiles are on each screen (bank 2 memory address) (see LEVEL_SCREEN_SUPERTILES_PTR)
            dw    level_6_supertile_data    ; composition of super-tiles (bank 3 memory address) (see LEVEL_SUPERTILE_DATA_PTR)
            dw    level_6_palette_data    ; super-tile palette data (bank 3 memory address) (see LEVEL_SUPERTILE_PALETTE_DATA)
            db    $0b    ; alternate graphics loading (+2) (screen where they start loading) (see LEVEL_ALT_GRAPHICS_POS)
            db    $0c,$de,$de    ; tile collision limits (see COLLISION_CODE_X_TILE_INDEX)
            db    $35,$36,$37,$38    ; palette indexes into game_palettes for cycling the 4th nametable palette index (see LEVEL_PALETTE_CYCLE_INDEXES)
            db    $33,$34,$04,$35    ; indexes into game_palettes specifying initial background tile palette colors (see LEVEL_PALETTE_INDEX)
            db    $00,$01,$22,$07    ; indexes into game_palettes specifying sprite palette colors (see LEVEL_PALETTE_INDEX)
            db    $0b    ; section to stop scrolling at (+2) (level length) (see LEVEL_STOP_SCROLL)
            db    $81    ; specifies whether to check for bullet and/or weapon item solid bg collisions (LEVEL_SOLID_BG_COLLISION_CHECK)
            db    $00,$00,$00,$00,$00,$00    ; unused

; header for level 7 - hangar
level_7_header ENT
            db    $00    ; location type: outdoor level (0 = outdoor ; 1 = indoor ; ff = indoor boss room) (LEVEL_LOCATION_TYPE)
            db    $00    ; outdoor scrolling type: horizontal scroll (0 = horizontal ; 1 = vertical)
            dw    level_7_supertiles_screen_ptr_table    ; pointer to which super-tiles are on each screen (bank 2 memory address) (see LEVEL_SCREEN_SUPERTILES_PTR)
            dw    level_7_supertile_data    ; composition of super-tiles (bank 3 memory address) (see LEVEL_SUPERTILE_DATA_PTR)
            dw    level_7_palette_data    ; super-tile palette data (bank 3 memory address) (see LEVEL_SUPERTILE_PALETTE_DATA)
            db    $0d    ; alternate graphics loading (+2) (screen where they start loading) (see LEVEL_ALT_GRAPHICS_POS)
            db    $0e,$f1,$f1    ; tile collision limits (see COLLISION_CODE_X_TILE_INDEX)
            db    $47,$57,$47,$58    ; palette indexes into game_palettes for cycling the 4th nametable palette index (see LEVEL_PALETTE_CYCLE_INDEXES)
            db    $45,$46,$04,$47    ; indexes into game_palettes specifying initial background tile palette colors (see LEVEL_PALETTE_INDEX)
            db    $00,$01,$22,$07    ; indexes into game_palettes specifying sprite palette colors (see LEVEL_PALETTE_INDEX)
            db    $0d    ; section to stop scrolling at (+2) (level length) (see LEVEL_STOP_SCROLL)
            db    $81    ; specifies whether to check for bullet and/or weapon item solid bg collisions (LEVEL_SOLID_BG_COLLISION_CHECK)
            db    $00,$00,$00,$00,$00,$00    ; unused

; header for level 8 - alien's lair
level_8_header ENT
            db    $00    ; location type: outdoor level (0 = outdoor ; 1 = indoor ; ff = indoor boss room) (LEVEL_LOCATION_TYPE)
            db    $00    ; outdoor scrolling type: horizontal scroll (0 = horizontal ; 1 = vertical)
            dw    level_8_supertiles_screen_ptr_table    ; pointer to which super-tiles are on each screen (bank 2 memory address) (see LEVEL_SCREEN_SUPERTILES_PTR)
            dw    level_8_supertile_data    ; composition of super-tiles (bank 3 memory address) (see LEVEL_SUPERTILE_DATA_PTR)
            dw    level_8_palette_data    ; super-tile palette data (bank 3 memory address) (see LEVEL_SUPERTILE_PALETTE_DATA)
            db    $09    ; alternate graphics loading (+2) (screen where they start loading) (see LEVEL_ALT_GRAPHICS_POS)
            db    $05,$ef,$ef    ; tile collision limits (see COLLISION_CODE_X_TILE_INDEX)
            db    $4c,$4d,$4e,$4f    ; palette indexes into game_palettes for cycling the 4th nametable palette index (see LEVEL_PALETTE_CYCLE_INDEXES)
            db    $48,$49,$4a,$4c    ; indexes into game_palettes specifying initial background tile palette colors (see LEVEL_PALETTE_INDEX)
            db    $00,$01,$43,$44    ; indexes into game_palettes specifying sprite palette colors (see LEVEL_PALETTE_INDEX)
            db    $09    ; section to stop scrolling at (+2) (level length) (see LEVEL_STOP_SCROLL)
            db    $00    ; specifies whether to check for bullet and/or weapon item solid bg collisions (LEVEL_SOLID_BG_COLLISION_CHECK)
            db    $00,$00,$00,$00,$00,$00    ; unused

load_screen_enemy_data ENT
            lda CURRENT_LEVEL    ; current level
            asl    ; double since each entry in level_enemy_screen_ptr_ptr_tbl is 2 bytes
            tay
            jsr   _R2_00d    ; levels enemy type table for level (low byte)
            sta $08
            jsr   _R2_00e    ; levels enemy type table for level (high byte)
            sta $09
            lda LEVEL_SCREEN_NUMBER    ; load current screen number within the level
            asl    ; double since each address is 2 bytes
            tay
            jsr   _I2_01    ; load the low byte of the pointer to the screen enemy type data (level_x_enemy_screen_xx)
            sta $0a
            iny
            jsr   _I2_01    ; load the high byte of the pointer to the screen enemy type data (level_x_enemy_screen_xx)
            sta $0b
            lda LEVEL_LOCATION_TYPE    ; 0 = outdoor; 1 = indoor
            beq load_enemy_outdoor_level    ; branch for outdoor level to load enemies for current screen
            jmp load_enemy_indoor_level    ; branch for indoor level to load enemies for current screen

; outdoor
load_enemy_outdoor_level ENT
            ldy ENEMY_SCREEN_READ_OFFSET    ; current read offset for screen enemy data
            jsr   _I2_02    ; load first byte of screen enemy data (level_x_enemy_screen_xx)
            cmp #$ff    ; if #$ff no more data to read
            beq load_screen_enemy_data_exit    ; just read #$ff, exit
            sta $0f    ; store X position of enemy into $0f
            and #$fe    ; look at the last bit
            sec    ; set the carry flag in preparation for subtraction
            sbc LEVEL_SCREEN_SCROLL_OFFSET    ; subtract scrolling offset in pixels within screen, vertical scroll for indoor levels
            beq :continue    ; if the player is at the horizontal position specified, create enemy
            bcs load_screen_enemy_data_exit    ; exit if haven't reached position
            eor #$ff    ; past the horizontal position for enemy type flip all bits and add one to get how far past
            adc #$01

:continue
            sta $0e    ; store distance past the from enemy load position (usually #$0, but can be positive if player was past position)
; this happens on the vertical level when jumping
            iny
            jsr   _I2_02    ; read the enemy type and the enemy repeat data
            tax    ; temporary save a so that we can pull out the ENEMY_TYPE
            and #$3f    ; keep the enemy type bits ..xx xxxx
            sta $08    ; store enemy type into $08
            txa    ; restore full value for a
            rol
            rol
            rol    ; previous 3 rol operations moved the high 2 bits to low to bits
            and #$03    ; keep only the last 2 bits, which is the repeat value
            sta $09    ; store the number of times to repeat the enemy in $09

; read the 3rd byte of the enemy triple, which is the Y position and the enemy attribute data
; also used when enemies are repeated to load repeat enemy data Y position
read_enemy_data_byte_3 ENT
            iny
            jsr   _I2_02    ; load vertical offset and enemy attributes
            sta $0c    ; store vertical offset and enemy attributes into $0c
            jsr find_next_enemy_slot    ; find next available enemy slot, put result in x register
            beq set_enemy_slot_data    ; found enemy slot to use
            lda $0f    ; no enemy slot available, load enemy X position
            lsr    ; shift least significant bit to carry flat
            bcc load_enemy_repeat_data    ; if carry flag clear, jump
            jsr find_bullet_slot

; updates enemy slot based on CPU memory values $08, $0c, $0e, etc.
set_enemy_slot_data ENT
            lda $08
            sta ENEMY_TYPE,x    ; store current enemy type
            jsr initialize_enemy    ; initialize enemy attributes
            lda $0c    ; load vertical position and enemy attributes
            and #$0f    ; keep the least significant 4 bits (enemy attributes)
            sta ENEMY_ATTRIBUTES,x    ; store enemy attributes
            lda LEVEL_SCROLLING_TYPE    ; 0 = horizontal, indoor/base; 1 = vertical
            beq :handle_horizontal    ; handle horizontal level
            lda $0c    ; load vertical position and enemy attributes
            and #$f0    ; keep most significant 4 bits xxxx ....
            sta ENEMY_X_POS,x    ; set enemy X position on screen
            lda $0e
            sta ENEMY_Y_POS,x    ; enemy Y position on screen
            jmp load_enemy_repeat_data    ; if enemy is repeated, handle that

:handle_horizontal
            lda $0c
            and #$f0    ; keep bits xxxx ....
            sta ENEMY_Y_POS,x    ; enemy Y position on screen
            lda #$f0    ; a = #$f0
            sec    ; set carry flag in preparation for subtraction
            sbc $0e
            sta ENEMY_X_POS,x    ; set enemy X position on screen

load_enemy_repeat_data ENT
            dec $09    ; decrement enemy repeat value
            bpl read_enemy_data_byte_3    ; read Y offset and attributes for next repetition
            iny    ; increment read offset
            sty ENEMY_SCREEN_READ_OFFSET

load_screen_enemy_data_exit ENT
            rts

; indoor
; input
;  * $08 - 2 byte memory address pointing to level_enemy_screen_ptr_ptr_tbl at correct offset
;  * $a0 - 2 byte memory address pointing to correct level_x_enemy_screen_ptr_tbl offset
;          (e.g. level_x_enemy_screen_xx) for the current screen
load_enemy_indoor_level ENT
            lda ENEMY_SCREEN_READ_OFFSET    ; offset for enemy data
            bne load_screen_enemy_data_exit
            inc ENEMY_SCREEN_READ_OFFSET    ; offset for enemy data
            lda #$00    ; a = #$00
            sta INDOOR_ENEMY_ATTACK_COUNT    ; clear the number of enemy 'rounds' of attack
            sta WALL_PLATING_DESTROYED_COUNT    ; clear the number of boss platings destroyed
            sta INDOOR_RED_SOLDIER_CREATED    ; clear flag indicating that a red jumping soldier has been generated
            sta GRENADE_LAUNCHER_FLAG    ; clear the flag indicating there is a grenade launcher on screen
            jsr remove_all_enemies
            ldy #$00    ; y = #$00
            jsr   _I2_02    ; read first byte of level_x_enemy_screen_xx
; i.e. the number of cores to destroy to advance to the next room
            cmp #$ff    ; see if end of data marker
            beq load_screen_enemy_data_exit    ; exit if read all of the data
            sta WALL_CORE_REMAINING    ; set remaining cores to destroy for screen
; for level 4 boss, used to count remaining boss gemini
            cmp #$00    ; see if number of cores is #$00 (no indoor screens are configured this way)
            bne :continue    ; continue if there are cores to destroy before marking screen clear
            lda #$01    ; !(UNUSED) every screen in contra has at least one core, so this code is never executed
            sta INDOOR_SCREEN_CLEARED    ; indoor screen cleared flag (0 = not cleared; 1 = cleared)
; immediately marks screen as cleared

:continue
            iny    ; increment level_x_enemy_screen_xx read offset
            ldx #$0f    ; x = #$0f

; loop through enemy data in level_x_enemy_screen_xx
:load_indoor_enemy
            jsr   _I2_02    ; load enemy position
            cmp #$ff    ; see if end of data byte
            beq load_screen_enemy_data_exit    ; exit if read all of the data
            sta $0f    ; store enemy position in $0f
            iny    ; increment enemy data read offset
            jsr   _I2_02    ; load enemy type (and enemy position adjustment flags)
            sta $08    ; store in $08
            and #$3f    ; strip bits 6 and 7 (pos adjustment flags) to get enemy type
            sta ENEMY_TYPE,x    ; set current enemy type
            jsr initialize_enemy    ; initialize enemy attributes
            lda $0f    ; load enemy position
            and #$f0    ; keep high nibble (Y position)
            asl $08    ; see enemy Y position adjustment flag set
            bcc :get_x_pos    ; branch if no Y adjustment
            adc #$07    ; enemy Y position adjustment flag set, adjust Y position by #$07

:get_x_pos
            sta ENEMY_Y_POS,x    ; set enemy Y position on screen
            lda $0f    ; load enemy position
            asl
            asl
            asl
            asl    ; shift low nibble to high nibble
            asl $08    ; see enemy X position adjustment flag set
            bcc :set_y_attrs_continue    ; branch if no X adjustment
            adc #$07    ; enemy X position adjustment flag set, adjust Y position by #$07

:set_y_attrs_continue
            sta ENEMY_X_POS,x    ; set enemy X position on screen
            iny    ; increment enemy data read offset
            jsr   _I2_02    ; load enemy attributes
            sta ENEMY_ATTRIBUTES,x    ; set enemy attributes
            iny    ; increment enemy data read offset
            dex    ; decrement enemy slot
            bpl :load_indoor_enemy    ; continue to load next enemy if slots available
            rts

; levels enemy groups pointers (#$08 * #$02 = #$10 bytes)
level_enemy_screen_ptr_ptr_tbl ENT
            dw    level_1_enemy_screen_ptr_tbl    ; CPU address $b82b
            dw    level_2_enemy_screen_ptr_tbl    ; CPU address $b8aa
            dw    level_3_enemy_screen_ptr_tbl    ; CPU address $b90d
            dw    level_4_enemy_screen_ptr_tbl    ; CPU address $b9af
            dw    level_5_enemy_screen_ptr_tbl    ; CPU address $ba48
            dw    level_6_enemy_screen_ptr_tbl    ; CPU address $bb24
            dw    level_7_enemy_screen_ptr_tbl    ; CPU address $bbb7
            dw    level_8_enemy_screen_ptr_tbl    ; CPU address $bca9

exe_soldier_generation ENT
            lda LEVEL_SCREEN_NUMBER    ; load current screen number within the level
            cmp SOLDIER_GEN_SCREEN    ; compare it to the screen the soldiers are being generated for
            beq :run_soldier_gen_routine    ; already reset the SOLDIER_GEN_SCREEN memory, skip initialization
            sta SOLDIER_GEN_SCREEN    ; update current soldier generation screen number
            lda #$00    ; a = #$00
            sta SCREEN_GEN_SOLDIERS    ; init the number of soldiers that have been generated for the screen

:run_soldier_gen_routine
            lda SOLDIER_GENERATION_ROUTINE    ; soldier generation routine index
            jsr run_routine_from_tbl_below    ; run routine a in the following table (soldier_generation_ptr_tbl)

; pointer table for soldier generation (#$03 * #$02 = #$06 bytes)
; CPU address $b537
soldier_generation_ptr_tbl ENT
            dw    soldier_generation_00    ; CPU address $b53d
            dw    soldier_generation_01    ; CPU address $b581
            dw    soldier_generation_02    ; CPU address $b657

; determines if should generate, and if so sets SOLDIER_GENERATION_TIMER
soldier_generation_00 ENT
            jsr get_soldier_gen_timer_for_lvl    ; get the initial timer for the level
            beq soldier_generation_00_exit    ; exit if timer is #$00, don't generate soldier (indoor/base levels)
            jsr adjust_generation_timer    ; update timer based on how many times player beat game and weapon strength
            inc SOLDIER_GENERATION_ROUTINE    ; set to soldier_generation_01

soldier_generation_00_exit ENT
            rts

; get level's initial value for the soldier generation timer and store in a
; output
;  * a - soldier generation timer for current level
get_soldier_gen_timer_for_lvl ENT
            lda CURRENT_LEVEL    ; load current level
            tay    ; move current level into y
            jsr   _R2_00f    ; load soldier generation timer for level
            rts

; updates timer based on how many times player beat game and weapon strength
adjust_generation_timer ENT
            jsr get_soldier_gen_timer_for_lvl
            sta SOLDIER_GENERATION_TIMER    ; soldier generation timer
            ldy GAME_COMPLETION_COUNT    ; load the number of times the game has been completed
            beq :adjust_timer_for_weapon    ; branch if haven't yet beat the game any times
            tya
            cmp #$04    ; compare GAME_COMPLETION_COUNT to #$04
            bcc :continue    ; branch if GAME_COMPLETION_COUNT < #$04
            ldy #$03    ; maximum multiplier of increase chance for generating soldier is #$03

:continue
            lda #$28    ; lower soldier generation timer
            jsr :adjust_timer    ; subtract #$28 * GAME_COMPLETION_COUNT from SOLDIER_GENERATION_TIMER

; lower timer based on how strong the player's weapon is (#05 * PLAYER_WEAPON_STRENGTH)
:adjust_timer_for_weapon
            ldy PLAYER_WEAPON_STRENGTH    ; load player weapon strength (damage strength)
            beq :exit    ; don't generate if player's weapon strength is #$00
            lda #$05    ; subtract #$05 * PLAYER_WEAPON_STRENGTH from SOLDIER_GENERATION_TIMER

; SOLDIER_GENERATION_TIMER = SOLDIER_GENERATION_TIMER - (a*y)
:adjust_timer
            sta $08
            lda SOLDIER_GENERATION_TIMER    ; soldier generation timer

:loop
            sec    ; set carry flag in preparation for subtraction
            sbc $08    ; SOLDIER_GENERATION_TIMER - $08
            bcc :exit    ; exit when overflow
            sta SOLDIER_GENERATION_TIMER
            dey
            bne :loop

:exit
            rts

; table for soldier generation initial timer values (#$08 bytes)
; current level value stored in SOLDIER_GENERATION_TIMER
; the lower the value, the quicker a soldier is generated
; #$36 = lots of soldiers
; #$08 = insane
; #$00 = no soldier generation (indoor/base levels, and alien's lair)
level_soldier_generation_timer ENT
            db    $90,$00,$d8,$00,$d0,$c8,$c0,$00

soldier_generation_01 ENT
            lda FRAME_COUNTER    ; load frame counter
            ror
            bcc :continue    ; every other frame look at the FRAME_SCROLL to see if should only subtract by #$01
            lda FRAME_SCROLL    ; odd frame, load whether or not the screen is scrolling (#00 or #01)
            bne :frame_scrolling    ; branch if frame is scrolling

:continue
            lda SOLDIER_GENERATION_TIMER    ; soldier generation timer
            sec    ; set carry flag in preparation for subtraction
            sbc #$02
            sta SOLDIER_GENERATION_TIMER    ; soldier generation timer
            bcc gen_soldier_find_pos
            rts    ; exit soldier_generation_01

; only subtract one from SOLDIER_GENERATION_TIMER when scrolling
:frame_scrolling
            dec SOLDIER_GENERATION_TIMER    ; soldier generation timer
            beq gen_soldier_find_pos    ; timer is now #$00
            rts    ; exit soldier_generation_01

; find the appropriate position to generate the soldier
gen_soldier_find_pos ENT
            jsr adjust_generation_timer    ; reset the soldier generation timer for later
            lda FRAME_COUNTER    ; load frame counter
            adc RANDOM_NUM    ; add random number to frame counter
            and #$01    ; just care about if result is even or odd
            tay
            lda SPRITE_Y_POS,y    ; get player 1 or player 2's Y position
            bne :search_for_position    ; branch if player sprite exists
            tya    ; no player sprite (probably player 2), transfer y to a
            eor #$01    ; flip least significant bit (0 to 1, or 1 to 0)
            lda SPRITE_Y_POS,y    ; reload #$00, !(BUG?)
; the developers may have meant to do a tay before this instruction
; to switch to use the other player's Y position, but since
; they didn't, the same #$00 is read

:search_for_position
            sta $08    ; store player Y position in $08
            sta $0a    ; set stopping Y position of search
            lda FRAME_COUNTER    ; load frame counter
            and #$03    ; keep bits .... ..xx
            tay
            beq top_down_find_gen_soldier_pos    ; 1/3 chance to start with y = #$00 (top)
            dey
            beq bottom_up_find_gen_soldier_pos    ; 1/3 chance to start with y = #$f0 (bottom)
            jsr get_x_pos_check_bg_collision    ; 1/3 chance to start with y = player Y position (then search up)

; look at every #$10 pixels to see if can place a soldier at position
; start at player Y position and move up
:find_y_pos
            lda $08    ; load previous soldier generation test Y position
            sec    ; set carry flag in preparation for subtraction
            sbc #$10    ; subtract #$10 pixels from soldier generation test Y position (move up)
            sta $08    ; update soldier generation test Y position
            cmp $0a    ; compare to the player Y position
            beq gen_soldier_find_pos_exit    ; exit if reached player Y position (wrapped around screen)
            jsr check_gen_soldier_bg_collision    ; check if soldier can be generated at location ($09, $08)
            bcc :find_y_pos    ; didn't have a ground. loop to next y test position.

gen_soldier_find_pos_exit ENT
            rts

; look at every #$10 pixels to see if can place a soldier at position
; start at top of screen down until player Y position
top_down_find_gen_soldier_pos ENT
            lda #$00    ; a = #$00
            sta $08    ; set start Y position (top of screen)
            sta $0a    ; set stopping Y position of search
            jsr get_x_pos_check_bg_collision    ; determine the X position (don't bother with carry flag result)

; look at every #$10 pixels to see if can place a soldier at position
; start at the top of the screen down to bottom
:find_y_pos
            lda $08    ; load previous soldier generation test Y position
            clc    ; clear carry in preparation for addition
            adc #$10    ; add #$10 pixels from soldier generation test Y position (move down)
            sta $08    ; update soldier generation test Y position
            cmp $0a    ; compare to the top of the screen #$00
            beq gen_soldier_find_pos_exit    ; exit if reached top of screen (wrapped around)
            jsr check_gen_soldier_bg_collision    ; check if soldier can be generated at location ($09, $08)
            bcc :find_y_pos    ; didn't have a ground. loop to next y test position.
            bcs gen_soldier_find_pos_exit    ; always jump, found ground and possibly generated soldier

; look at every #$10 pixels to see if can place a soldier at position
; start at the bottom of the screen up to top
bottom_up_find_gen_soldier_pos ENT
            lda #$f0    ; a = #$f0
            sta $08    ; set start Y position (bottom of screen)
            sta $0a    ; set stopping position of search
            jsr get_x_pos_check_bg_collision    ; determine the X position (don't bother with carry flag result)

:find_y_pos
            lda $08    ; load previous soldier generation test Y position
            sec    ; set carry flag in preparation for subtraction
            sbc #$10    ; subtract #$10 pixels from soldier generation test Y position (move up)
            sta $08    ; update soldier generation test Y position
            cmp $0a    ; compare to the bottom of the screen #$00
            beq gen_soldier_find_pos_exit    ; exit if reached bottom of screen (wrapped around)
            jsr check_gen_soldier_bg_collision    ; check if soldier can be generated at location ($09, $08)
            bcc :find_y_pos    ; didn't have a ground. loop to next y test position.
            bcs gen_soldier_find_pos_exit    ; always jump, found ground and possibly generated soldier

; determine appropriate X position for soldier to generate and then
; see if there is a ground collision
get_x_pos_check_bg_collision ENT
            lda FRAME_COUNTER    ; load frame counter
            adc RANDOM_NUM    ; a = FRAME_COUNTER + RANDOM_NUM
            and #$0f    ; keep low nibble of FRAME_COUNTER + RANDOM_NUM
            tay
            jsr   _R2_010    ; load possible initial X position of generated soldier
            ldy GAME_COMPLETION_COUNT    ; load the number of times the game has been completed
            bne :check_bg_collision    ; player(s) have completed game at least once
            ldy CURRENT_LEVEL    ; current level
            bne :check_bg_collision    ; branch if not the first level
            pha    ; push gen_soldier_initial_x_pos value to stack
            lda SCREEN_GEN_SOLDIERS    ; load the number of soldiers that have been generated for the level
            cmp #$1e
            bcs :pop_x_pos_check_bg_collision    ; branch if the number of soldiers generated for frame >= #$1e
            pla    ; pop a from stack, not going to use gen_soldier_initial_x_pos value
            lda #$fc    ; set soldier generation test X position to right edge of screen
            bne :check_bg_collision    ; always branch

:pop_x_pos_check_bg_collision
            pla    ; pop a from stack

:check_bg_collision
            sta $09    ; put gen_soldier_initial_x_pos value, or #$fc into $09

; checks if soldier can be generated at location ($09, $08)
; input
;  * $09 - test point X position
;  * $08 - test point Y position
check_gen_soldier_bg_collision ENT
            lda $09    ; generated soldier possible X position
            ldy $08    ; generated soldier possible Y position
            jsr get_bg_collision    ; determine player background collision code at position (a,y)
            bcs :set_pos_adv_routine    ; floor collision, mark that soldier can be generated
            rts    ; exit soldier_generation_01

; soldier background collision
:set_pos_adv_routine
            lda $09    ; load generated soldier X position
            sta SOLDIER_GENERATION_X_POS    ; store generated soldier initial X position
            lda $08    ; load generated soldier initial Y position
            sec    ; set carry flag in preparation for subtraction
            sbc #$10    ; subtract #$10 from generated soldier initial Y position
            sta SOLDIER_GENERATION_Y_POS    ; store initial Y position
            lda SOLDIER_GENERATION_ROUTINE
            cmp #$02    ; see if routine is set to soldier_generation_02
            beq :mark_and_exit    ; see if still on soldier_generation_02
; check_gen_soldier_bg_collision is called initially and the result
; is ignored. Don't want to advance routine multiple times
            inc SOLDIER_GENERATION_ROUTINE    ; move to soldier_generation_02

:mark_and_exit
            sec    ; set carry flag, mark that a soldier can be generated at position
            rts

; table for possible initial X positions of generated soldiers (#$10 bytes)
; always either left edge (#$0a) or right edge (#$fa)
; level 1 doesn't use this table until at least #$1e (36 decimal) enemies have been
; generated for the screen. Instead soldiers always come from the right.
; Presumably this is to make the game easier in the beginning.
gen_soldier_initial_x_pos ENT
            db    $fa,$0a,$fa,$fa,$0a,$fa,$0a,$fa,$0a,$0a,$0a,$fa,$fa,$0a,$0a,$fa

soldier_generation_02 ENT
            lda CURRENT_LEVEL    ; current level
            cmp #$02    ; compare current level to #$02 (level 3 - waterfall)
            beq generate_soldier    ; don't prevent top %25 from generating soldiers for level 3 waterfall (vertical level)
            lda SOLDIER_GENERATION_Y_POS    ; load soldier initial Y position
            cmp #$40    ; compare to 25% of the vertical space, don't generate top 25% of screen
            bcs generate_soldier    ; branch if in bottom 3/4 of the screen

soldier_gen_exit_far ENT
            jmp soldier_gen_exit

generate_soldier ENT
            lda SOLDIER_GENERATION_Y_POS    ; generated soldier initial Y position on screen
            cmp #$e0    ; compare Y position to bottom extremity of screen
            bcs soldier_gen_exit_far    ; exit if soldier generation position is too low
            lda ENEMY_ATTACK_FLAG    ; see if enemies should attack
            beq soldier_gen_exit_far    ; don't generate soldier if ENEMY_ATTACK_FLAG is #$00
            lda CURRENT_LEVEL    ; current level
            cmp #$04    ; check if level 5 (snow field)
            bne :continue    ; check if in the last screens of level 5 (snow field)
            lda LEVEL_SCREEN_NUMBER    ; load current screen number within the level
            cmp #$11    ; screen #$11 of snow field
            bcc :continue    ; check for last screen of snow field
            jsr get_soldier_gen_screen_side    ; see which horizontal half of the screen soldier is being generated on
            bcc soldier_gen_exit_far    ; exit if from left half. don't generate soldiers from left

:continue
            lda SOLDIER_GENERATION_X_POS    ; load generated soldier initial X position
            ldy SOLDIER_GENERATION_Y_POS    ; load generated soldier initial Y position
            jsr get_bg_collision_far    ; determine player background collision code at position (a,y)
            bmi soldier_gen_exit_far    ; exit if collision with solid object (#$80)
            jsr get_soldier_gen_screen_side    ; see which horizontal half of the screen soldier is being generated on
            bcc :load_gen_soldier_attr    ; branch if generating on left half of the screen
            sbc #$10    ; soldier generation on right half of screen, subtract #$10 from X position

:load_gen_soldier_attr
            clc    ; clear carry in preparation for addition
            adc #$08    ; subtract #$08 from soldier generation X position
            ldy SOLDIER_GENERATION_Y_POS
            jsr get_bg_collision_far    ; determine player background collision code at position (a,y)
            bmi soldier_gen_exit_far    ; branch if collision with solid object
            jsr find_next_enemy_slot_6_to_0    ; find next available enemy slot (0-6), put result in x register
            bne soldier_gen_exit_far    ; branch if no slot was found
            lda CURRENT_LEVEL    ; current level
            asl
            tay
            jsr   _R2_011    ; load the low byte of the address
            sta $08
            jsr   _R2_012    ; load the high byte of the address
            sta $09
            lda LEVEL_SCREEN_NUMBER    ; load current screen number within the level
            beq soldier_gen_exit_far    ; first screen never has enemies, skip
            tay
            dey    ; subtract 1 since there is no screen 0 enemy
            jsr   _I2_01    ; load the yth screen's soldier's behavior
            cmp #$ff    ; see if #$ff, which means don't generate soldiers for screen
            beq soldier_gen_exit_far    ; exit
            and #$80    ; keep bits msb
            beq :cont_load_gen_soldier_attr    ; branch if msb is 0
            lda FRAME_COUNTER    ; when bit 7 is set there is a 50% probability of no generation
            ror
            bcc :cont_load_gen_soldier_attr    ; branch if even frame number
            bcs soldier_gen_exit    ; don't generate if odd frame

:cont_load_gen_soldier_attr
            jsr   _I2_01    ; reload soldier generation attribute byte for screen
            and #$40    ; keep bit 6. When bit 6 set there is a 25% probability of no generation
            beq :gen_soldier    ; bit 6 not set, continue
            lda FRAME_COUNTER    ; load frame counter
            and #$03    ; keep bits .... ..xx
            beq :gen_soldier    ; if bit 0 or bit 1 is not 0, then don't generate soldier (25% chance)
            bne soldier_gen_exit

:gen_soldier
            lda SCREEN_GEN_SOLDIERS
            cmp #$1e
            bcs init_and_generate_soldier    ; branch if more than #$1e (30 dec) soldiers have already been generated on screen
            lda GAME_COMPLETION_COUNT    ; load the number of times the game has been completed
            bne init_and_generate_soldier    ; branch if player(s) have completed game at least once
; this skips preventing a soldier from being generated near a player
; at the edge of the screen
            jmp player_edge_check    ; player(s) haven't completed game and less than #$1e soldiers
; have been generated for screen, so jump

init_and_generate_soldier ENT
            lda CURRENT_LEVEL    ; current level
            cmp #$02    ; compare level to level 3 (waterfall)
            beq :init_generated_soldier    ; initialize generated soldier without checking FRAME_SCROLL for waterfall
            lda FRAME_SCROLL    ; how much to scroll the screen (#$00 - no scroll)
            beq :init_generated_soldier    ; initialize generated soldier if not scrolling
            lda RANDOM_NUM    ; load a random number
            and #$03    ; keep bits .... ..xx
            beq create_default_soldiers    ; 1/3 chance of branching to create a soldier for each player

; initializes the ENEMY_TYPE to #$05
; initializes ENEMY_ATTRIBUTES based on slightly random value from gen_soldier_initial_attr_tbl
:init_generated_soldier
            lda #$05    ; a = #$05 (soldier)
            sta ENEMY_TYPE,x    ; set current enemy type to soldier
            jsr initialize_enemy    ; initialize enemy attributes
            jsr   _I2_01    ; load soldier_level_attributes_xx (attributes for current level soldiers)
            and #$3f    ; strip bits 6 and 7 (soldier generation probably bits)
            asl
            asl
            sta $0a    ; start to determine random position into gen_soldier_initial_attr_tbl to load
            lda FRAME_COUNTER    ; load frame counter
            and #$03    ; keep bits .... ..xx
            clc    ; clear carry in preparation for addition
            adc $0a    ; randomly add a value from 0 to 3 to soldier_level_attributes_xx value
            tay    ; move to be gen_soldier_initial_attr_tbl index
            jsr   _R2_013    ; load initial ENEMY_ATTRIBUTES value for generated soldier
            sta ENEMY_ATTRIBUTES,x
            lda RANDOM_NUM    ; load random number
            adc FRAME_COUNTER    ; add to the frame counter
            and #$02    ; keep bits .... ..x.
            beq :set_gen_soldier_pos_and_dir    ; randomly skip setting how soldiers handle ledges to 1
            ora ENEMY_ATTRIBUTES,x    ; set bit 1 of ENEMY_ATTRIBUTES (ledge handling behavior)
            sta ENEMY_ATTRIBUTES,x    ; save new ENEMY_ATTRIBUTES value

:set_gen_soldier_pos_and_dir
            lda SOLDIER_GENERATION_Y_POS    ; load the computed Y position of the generated soldier
            sta ENEMY_Y_POS,x    ; copy the computed generated soldier Y position to the enemy Y position
            jsr get_soldier_gen_screen_side    ; see which horizontal half of the screen soldier is being generated on
            sta ENEMY_X_POS,x    ; copy the computed generated soldier X position to the enemy X position
            bcs :inc_soldier_cnt_exit    ; branch if right horizontal half of the screen
            inc ENEMY_ATTRIBUTES,x    ; left half of the screen, set soldier direction to run towards the right

:inc_soldier_cnt_exit
            inc SCREEN_GEN_SOLDIERS    ; increment the total number of generated soldiers for the current screen

soldier_gen_exit ENT
            lda #$00    ; a = #$00
            sta SOLDIER_GENERATION_ROUTINE    ; reset soldier generation routine index to reset SOLDIER_GENERATION_TIMER
            rts

; compares SOLDIER_GENERATION_X_POS to the middle of the screen (#$80)
; clears carry if on left half of the screen, sets carry for right half of screen
get_soldier_gen_screen_side ENT
            lda SOLDIER_GENERATION_X_POS    ; generated soldier initial X position on screen
            cmp #$80
            rts

; 1/3 chance of happening on a screen with generating soldiers
; generates a 'default' soldier for each player, i.e. not using gen_soldier_initial_attr_tbl
create_default_soldiers ENT
            lda #$00    ; a = #$00
            sta $07    ; initial soldier X direction is to the left
            jsr get_soldier_gen_screen_side    ; see which horizontal half of the screen soldier is being generated on
            bcs :create_soldier    ; branch if soldier is generated from the right side
            inc $07    ; generated soldier generated from left side, have them run to the right

:create_soldier
            ldy #$02    ; y = #$02

:loop
            inc $06    ; increment ENEMY_ATTRIBUTES value
            tya    ; save y in stack so it can be restored after logic
            pha    ; push a to the stack
            jsr find_next_enemy_slot_6_to_0    ; find next available enemy slot, put result in x register
            bne :pop_a_soldier_gen_exit    ; can't generate soldier, clean up pushed a from stack and exit
            lda #$05    ; a = #$05 (soldier)
            sta ENEMY_TYPE,x    ; set current enemy type to soldier
            jsr initialize_enemy    ; initialize enemy attributes
            jsr :set_enemy_pos    ; set SOLDIER_GENERATION_X_POS to ENEMY_POS_X and SOLDIER_GENERATION_Y_POS to ENEMY_POS_Y
            lda $06
            and #$02    ; keep bits .... ..x.
            sta ENEMY_ATTRIBUTES,x
            pla    ; pop a from stack to restore y
            tay    ; restore y value
            asl
            asl
            asl
            asl
            clc    ; clear carry in preparation for addition
            adc ENEMY_ATTRIBUTES,x
            ora $07    ; set soldier X direction
            sta ENEMY_ATTRIBUTES,x    ; save soldier direction back in ENEMY_ATTRIBUTES
            jsr :set_enemy_pos    ; seems redundant, already was set above
            dey    ; move to player 1
            bmi soldier_gen_exit    ; finished player loop, exit
            bpl :loop

:pop_a_soldier_gen_exit
            pla
            jmp soldier_gen_exit

:set_enemy_pos
            lda SOLDIER_GENERATION_Y_POS    ; generated soldier initial Y position on screen
            sta ENEMY_Y_POS,x    ; enemy Y position on screen
            lda SOLDIER_GENERATION_X_POS    ; generated soldier initial X position on screen
            sta ENEMY_X_POS,x    ; set enemy X position on screen
            rts

; player(s) haven't completed game and less than #$1e soldiers
; see if player is close to the edge where the soldier will be generated
; if so, don't generate soldier
player_edge_check ENT
            tya    ; need to save current value of y temporarily to restore after method
            pha    ; temporarily save current value of a to stack
            ldy #$01    ; set y to start with player 2 for gen_soldier_right_side
            jsr get_soldier_gen_screen_side    ; see which horizontal half of the screen soldier is being generated on
            bcs gen_soldier_right_side    ; branch if soldier is to be generated on right half of the screen

; soldier to be generated from left side of screen
:player_loop
            jsr   _Z2_00    ; game over state (1 = game over)
            bne :move_next_player    ; skip player if in game over state
            lda SPRITE_X_POS,y    ; player X position on screen
            cmp #$40    ; left 25% of screen
            bcc restore_y_soldier_gen_exit    ; exit if player is close to the left
; where the soldier would have been generated

:move_next_player
            dey
            bpl :player_loop

restore_y_init_and_generate_soldier ENT
            pla    ; pop value a from stack
            tay    ; restore value of y from before jmp to player_edge_check
            jmp init_and_generate_soldier

restore_y_soldier_gen_exit ENT
            pla
            tay
            jmp soldier_gen_exit

; check players GAME_OVER_STATUS
; generated soldier on the right half of the screen
gen_soldier_right_side ENT
            jsr   _Z2_00    ; game over state (1 = game over)
            bne :next_player    ; branch if game over for player
            lda SPRITE_X_POS,y    ; load player's X position
            cmp #$c0    ; compare X position to 3/4 (75%) of the horizontal screen
            bcs restore_y_soldier_gen_exit    ; exit if player is close to the right
; where the soldier would have been generated

:next_player
            dey
            bpl gen_soldier_right_side    ; check player 1's game over status
            bmi restore_y_init_and_generate_soldier

; pointer table for soldier random generation (#$08 * #$02 = #$10 bytes)
soldier_level_attributes_ptr_tbl ENT
            dw    soldier_level_attributes_00    ; CPU address $b7cb
            dw    soldier_level_attributes_00    ; CPU address $b7cb
            dw    soldier_level_attributes_01    ; CPU address $b7d7
            dw    soldier_level_attributes_00    ; CPU address $b7cb
            dw    soldier_level_attributes_02    ; CPU address $b7e0
            dw    soldier_level_attributes_03    ; CPU address $b7f4
            dw    soldier_level_attributes_04    ; CPU address $b800
            dw    soldier_level_attributes_00    ; CPU address $b7cb

; related to soldier generation according to level and screen number
; each byte represents a screen of a level and how the soldier's will
; be generated on that screen
; #$ff = don't generate soldier
; #$80 = random right/left, no shooting, freq. 1 on screen
; #$40 = random right/left, no shooting, freq. 50% of 80
; #$00 = random right/left, no shooting, freq. 1 per 1.5s
; #$01 = random right/left, shoot 1-2 bullets ratio 75-25, freq. like 00
; #$02 = random right/left, shoot 1-2 bullets ratio 67-33, freq. like 00
; #$03 = random right/left, shoot 1-2 bullets ratio 67-33, freq. like 00

; #$0c bytes
soldier_level_attributes_00 ENT
            db    $80,$80,$80,$80,$80,$80,$80,$40,$40,$80,$ff,$ff

; #$09 bytes
soldier_level_attributes_01 ENT
            db    $00,$00,$00,$01,$00,$ff,$01,$ff,$ff

; #$14 bytes
soldier_level_attributes_02 ENT
            db    $01,$02,$03,$04,$03,$03,$03,$02,$ff,$04,$02,$03,$ff,$02,$03,$04
            db    $02,$ff,$ff,$ff

; #$0c bytes
soldier_level_attributes_03 ENT
            db    $00,$05,$02,$ff,$ff,$80,$05,$03,$82,$ff,$ff,$ff

; #$0f bytes
soldier_level_attributes_04 ENT
            db    $80,$05,$06,$80,$80,$05,$07,$80,$80,$04,$ff,$04,$04,$ff,$ff

; table for generated soldiers initial ENEMY_ATTRIBUTES value (#$1c bytes)
; bit 0 = running direction - 0 is left, 1 is right
; bit 1 = affects whether the soldier turns around on ledges ?
; bit 2 = whether or not the enemy shoots bullets
gen_soldier_initial_attr_tbl ENT
            db    $00,$00,$00,$00
            db    $00,$00,$00,$04
            db    $00,$00,$04,$04
            db    $00,$04,$04,$04
            db    $04,$04,$04,$04
            db    $00,$00,$00,$08
            db    $00,$00,$04,$08

; pointer table for level 1 enemy groups (d * 2 = 1a bytes)
level_1_enemy_screen_ptr_tbl ENT
            dw    level_1_enemy_screen_00    ; CPU address $b845
            dw    level_1_enemy_screen_01    ; CPU address $b858
            dw    level_1_enemy_screen_02    ; CPU address $b85c
            dw    level_1_enemy_screen_03    ; CPU address $b860
            dw    level_1_enemy_screen_04    ; CPU address $b864
            dw    level_1_enemy_screen_05    ; CPU address $b871
            dw    level_1_enemy_screen_06    ; CPU address $b87b
            dw    level_1_enemy_screen_07    ; CPU address $b87f
            dw    level_1_enemy_screen_08    ; CPU address $b886
            dw    level_1_enemy_screen_09    ; CPU address $b88d
            dw    level_1_enemy_screen_0a    ; CPU address $b895
            dw    level_1_enemy_screen_0b    ; CPU address $b899
            dw    level_1_enemy_screen_0c    ; CPU address $b8a9

; enemy format

; xx tt yy

; xx = X position
; xxxxxxxx X position

; tt = enemy type + repeat
; xx.. .... repeat
; ..xx xxxx enemy type

; yy = Y position + attributes
; xxxx x... Y position
; .... .xxx attributes
level_1_enemy_screen_00 ENT
            db    $10,$05,$60    ; soldier - runs left, doesn't shoot
            db    $40,$05,$60    ; soldier - runs left, doesn't shoot
            db    $50,$06,$c0    ; sniper - standing, shoots once per attack
            db    $60,$02,$a1    ; pill box sensor - machine gun inside
            db    $80,$05,$60    ; soldier - runs left, doesn't shoot
            db    $f0,$03,$40    ; flying capsule - rapid fire
            db    $ff

level_1_enemy_screen_01 ENT
            db    $90,$06,$c0    ; sniper - standing, shoots one bullet at a time
            db    $ff

level_1_enemy_screen_02 ENT
            db    $20,$12,$80    ; exploding bridge
            db    $ff

level_1_enemy_screen_03 ENT
            db    $40,$12,$80    ; exploding bridge
            db    $ff

level_1_enemy_screen_04 ENT
            db    $00,$04,$a0    ; rotating gun, shoots once per attack
            db    $10,$06,$60    ; sniper - standing, shoots once per attack
            db    $50,$06,$61    ; sniper - crouching, shoots once per attack
            db    $60,$03,$43    ; flying capsule - spray gun
            db    $ff

level_1_enemy_screen_05 ENT
            db    $20,$06,$41    ; sniper (enemy type #$06), attribute: 001 (crouch and shoot one bullet at a time), location: (#$20, #$40)
            db    $40,$02,$a2    ; pill box sensor (enemy type #$02), attribute: 010 (F), location: (#$40, #$a0)
            db    $80,$04,$80    ; rotating gun (enemy type #$04), attribute: 000, location: (#$80, #$80)
            db    $ff

level_1_enemy_screen_06 ENT
            db    $40,$04,$80    ; rotating gun (enemy type #$04), attribute: 000, location: (#$40, #$80)
            db    $ff

level_1_enemy_screen_07 ENT
            db    $20,$07,$a0    ; red turret (enemy type #$07), attribute: 000, location: (#$20, #$a0)
            db    $a0,$07,$41    ; red turret (enemy type #$07), attribute: 001, location: (#$a0, #$40)
            db    $ff

level_1_enemy_screen_08 ENT
            db    $00,$02,$c3    ; pill box sensor (enemy type #$02), attribute: 011 (S), location: (#$00, #$c0)
            db    $50,$06,$80    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$50, #$80)
            db    $ff

level_1_enemy_screen_09 ENT
            db    $10,$43,$40,$b4    ; flying capsule (enemy type #$03), attribute: 000 (R), location: (#$10, #$40)
; repeat: 1 [(y = #$b0, attr = 100)]
            db    $e0,$07,$81    ; red turret (enemy type #$07), attribute: 001, location: (#$e0, #$80)
            db    $ff

level_1_enemy_screen_0a ENT
            db    $c0,$04,$c0    ; rotating gun (enemy type #$04), attribute: 000, location: (#$c0, #$c0)
            db    $ff

level_1_enemy_screen_0b ENT
            db    $40,$04,$c3    ; rotating gun (enemy type #$04), attribute: 011, location: (#$40, #$c0)
            db    $a8,$10,$81    ; bomb turret (enemy type #$10), attribute: 001, location: (#$a8, #$80)
            db    $b1,$11,$b0    ; plated door (enemy type #$11), attribute: 000, location: (#$b1, #$b0)
            db    $b4,$06,$52    ; sniper (enemy type #$06), attribute: 010 (boss screen sniper), location: (#$b4, #$50)
            db    $c0,$10,$80    ; bomb turret (enemy type #$10), attribute: 000, location: (#$c0, #$80)
            db    $ff

level_1_enemy_screen_0c ENT
            db    $ff

; pointer table for level 2 enemy groups (#$06 * #$02 = #$0c bytes)
level_2_enemy_screen_ptr_tbl ENT
            dw    level_2_enemy_screen_00    ; CPU address $b8b6
            dw    level_2_enemy_screen_01    ; CPU address $b8be
            dw    level_2_enemy_screen_02    ; CPU address $b8c9
            dw    level_2_enemy_screen_03    ; CPU address $b8d7
            dw    level_2_enemy_screen_04    ; CPU address $b8e5
            dw    level_2_enemy_screen_05    ; CPU address $b8f6

; level 2 enemy data
; first byte specifies number of wall cores to destroy
; then enemies are described
; byte 0 = location of object
;  * xxxx .... - Y position * #$10
;  * .... xxxx - X position * #$10
; byte 1 = enemy type and position adjustment
;  * x... .... - Y position + #$07
;  * .x.. .... - X position + #$07
;  * ..xx xxxx object type
; byte 2 = enemy attributes
;  * xxxx .... - Y position of enemy
;  * .... xxxx - X position of enemy
level_2_enemy_screen_00 ENT
            db    $01    ; number of cores to destroy to advance to next room, if set to #$00 no electric barrier, can't advance
            db    $11,$19,$00    ; enemy type #$19 (indoor soldier generator)
            db    $68,$94,$03    ; enemy type #$14 (core), not plated, #$f0 opening delay
            db    $ff

level_2_enemy_screen_01 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $11,$59,$00    ; enemy type #$19 (indoor soldier generator)
            db    $66,$d4,$03    ; enemy type #$14 (core), not plated, #$f0 opening delay
            db    $69,$d3,$00    ; enemy type #$13 (wall turret)
            db    $ff

level_2_enemy_screen_02 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $11,$59,$00    ; enemy type #$19 (indoor soldier generator)
            db    $78,$14,$03    ; enemy type #$14 (core), not plated, #$f0 opening delay
            db    $66,$d3,$00    ; enemy type #$13 (wall turret)
            db    $69,$d3,$00    ; enemy type #$13 (wall turret)
            db    $ff

level_2_enemy_screen_03 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $11,$59,$00    ; enemy type #$19 (indoor soldier generator)
            db    $11,$1a,$00    ; enemy type #$1a (indoor roller generator)
            db    $58,$93,$00    ; enemy type #$13 (wall turret)
            db    $68,$94,$03    ; enemy type #$14 (core), not plated, #$f0 opening delay
            db    $ff

level_2_enemy_screen_04 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $11,$59,$00    ; enemy type #$19 (indoor soldier generator)
            db    $68,$94,$0b    ; enemy type #$14 (core), larger sized core
            db    $66,$d3,$00    ; enemy type #$13 (wall turret)
            db    $69,$d3,$00    ; enemy type #$13 (wall turret)
            db    $58,$13,$00    ; enemy type #$13 (wall turret)
            db    $ff

level_2_enemy_screen_05 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $48,$10,$00    ; enemy type #$10 (boss eye)
            db    $65,$08,$00    ; enemy type #$08 (wall cannon)
            db    $68,$0a,$01    ; enemy type #$0a (wall plating)
            db    $6b,$08,$00    ; enemy type #$08 (wall cannon)
            db    $95,$0a,$00    ; enemy type #$0a (wall plating)
            db    $98,$0a,$00    ; enemy type #$0a (wall plating)
            db    $9b,$0a,$00    ; enemy type #$0a (wall plating)
            db    $ff

; pointer table for level 3 enemy groups (#$0a * #$02 = #$14 bytes)
; xx = X position
; xxxxxxxx X position

; tt = enemy type + repeat
; xx...... repeat
; ..xxxxxx enemy type

; yy = Y position + attributes
; xxxxx... Y position
; .....xxx attributes
level_3_enemy_screen_ptr_tbl ENT
            dw    level_3_enemy_screen_00    ; CPU address $b921
            dw    level_3_enemy_screen_01    ; CPU address $b941
            dw    level_3_enemy_screen_02    ; CPU address $b948
            dw    level_3_enemy_screen_03    ; CPU address $b95a
            dw    level_3_enemy_screen_04    ; CPU address $b96a
            dw    level_3_enemy_screen_05    ; CPU address $b984
            dw    level_3_enemy_screen_06    ; CPU address $b994
            dw    level_3_enemy_screen_07    ; CPU address $b9a4 (boss)
            dw    level_3_enemy_screen_08    ; CPU address $b9ae (no enemy)
            dw    level_3_enemy_screen_08    ; CPU address $b9ae (no enemy)

; level 3 enemy data - section 1 (#$20 bytes)
level_3_enemy_screen_00 ENT
            db    $08,$05,$21    ; soldier (enemy type #$05), attribute: 001, location: (#$08, #$20)
            db    $22,$12,$35    ; rock cave (enemy type #$12), attribute: 101, location: (#$22, #$30)
            db    $40,$02,$92    ; pill box sensor (enemy type #$02), attribute: 010 (F), location: (#$40, #$90)
            db    $48,$05,$23    ; soldier (enemy type #$05), attribute: 011, location: (#$48, #$20)
            db    $62,$12,$d1    ; rock cave (enemy type #$12), attribute: 001, location: (#$62, #$d0)
            db    $68,$45,$33,$96    ; soldier (enemy type #$05), attribute: 011, location: (#$68, #$30)
; repeat: 1 [(y = #$90, attr = 110)]
            db    $82,$12,$b5    ; rock cave (enemy type #$12), attribute: 101, location: (#$82, #$b0)
            db    $a2,$12,$55    ; rock cave (enemy type #$12), attribute: 101, location: (#$a2, #$50)
            db    $c0,$02,$94    ; pill box sensor (enemy type #$02), attribute: 100 (L), location: (#$c0, #$90)
            db    $e2,$12,$95    ; rock cave (enemy type #$12), attribute: 101, location: (#$e2, #$90)
            db    $ff

level_3_enemy_screen_01 ENT
            db    $38,$06,$e0    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$38, #$e0)
            db    $60,$0c,$a0    ; scuba diver (enemy type #$0c), attribute: 000, location: (#$60, #$a0)
            db    $ff

level_3_enemy_screen_02 ENT
            db    $40,$04,$f5    ; rotating gun (enemy type #$04), attribute: 101, location: (#$40, #$f0)
            db    $73,$51,$53,$b2    ; moving flame (enemy type #$11), attribute: 011, location: (#$73, #$50), repeat: 1 [(y = #$b0, attr = 010)]
            db    $80,$06,$e0    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$80, #$e0)
            db    $d0,$43,$35,$a0    ; flying capsule (enemy type #$03), attribute: 101 (B), location: (#$d0, #$30), repeat: 1 [(y = #$a0, attr = 000)]
            db    $e0,$04,$10    ; rotating gun (enemy type #$04), attribute: 000, location: (#$e0, #$10)
            db    $ff

level_3_enemy_screen_03 ENT
            db    $11,$10,$50    ; floating rock (enemy type #$10), attribute: 000, location: (#$11, #$50)
            db    $20,$06,$20    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$20, #$20)
            db    $81,$10,$71    ; floating rock (enemy type #$10), attribute: 001, location: (#$81, #$70)
            db    $c0,$04,$10    ; rotating gun (enemy type #$04), attribute: 000, location: (#$c0, #$10)
            db    $d0,$0c,$50    ; scuba diver (enemy type #$0c), attribute: 000, location: (#$d0, #$50)
            db    $ff

level_3_enemy_screen_04 ENT
            db    $38,$05,$72    ; soldier (enemy type #$05), attribute: 010, location: (#$38, #$70)
            db    $50,$0c,$e0    ; scuba diver (enemy type #$0c), attribute: 000, location: (#$50, #$e0)
            db    $60,$02,$b3    ; pill box sensor (enemy type #$02), attribute: 011 (S), location: (#$60, #$b0)
            db    $88,$05,$a6    ; soldier (enemy type #$05), attribute: 110, location: (#$88, #$a0)
            db    $a0,$04,$f0    ; rotating gun (enemy type #$04), attribute: 000, location: (#$a0, #$f0)
            db    $a8,$05,$46    ; soldier (enemy type #$05), attribute: 110, location: (#$a8, #$40)
            db    $d8,$45,$85,$e4    ; soldier (enemy type #$05), attribute: 101, location: (#$d8, #$80), repeat: 1 [(y = #$e0, attr = 100)]
            db    $e0,$04,$10    ; rotating gun (enemy type #$04), attribute: 000, location: (#$e0, #$10)
            db    $ff

level_3_enemy_screen_05 ENT
            db    $20,$02,$11    ; pill box sensor (enemy type #$02), attribute: 001 (M), location: (#$20, #$10)
            db    $30,$07,$e1    ; red turret (enemy type #$07), attribute: 001, location: (#$30, #$e0)
            db    $38,$05,$66    ; soldier (enemy type #$05), attribute: 110, location: (#$38, #$60)
            db    $40,$04,$30    ; rotating gun (enemy type #$04), attribute: 000, location: (#$40, #$30)
            db    $79,$10,$81    ; floating rock (enemy type #$10), attribute: 001, location: (#$79, #$80)
            db    $ff

level_3_enemy_screen_06 ENT
            db    $28,$05,$c6    ; soldier (enemy type #$05), attribute: 110, location: (#$28, #$c0)
            db    $40,$05,$15    ; soldier (enemy type #$05), attribute: 101, location: (#$40, #$10)
            db    $58,$05,$95    ; soldier (enemy type #$05), attribute: 101, location: (#$58, #$90)
            db    $78,$06,$20    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$78, #$20)
            db    $e8,$05,$65    ; soldier (enemy type #$05), attribute: 101, location: (#$e8, #$60)
            db    $ff

level_3_enemy_screen_07 ENT
            db    $08,$05,$e4    ; soldier (enemy type #$05), attribute: 100, location: (#$08, #$e0)
            db    $a8,$55,$51,$b0    ; dragon orb (enemy type #$15), attribute: 001, location: (#$a8, #$50)
; repeat: 1 [(y = #$b0, attr = 000)]
            db    $c1,$14,$80    ; dragon (enemy type #$14), attribute: 000, location: (#$c1, #$80)

level_3_enemy_screen_08 ENT
            db    $ff

; pointer table for level 4 enemy groups (#$09 * #$02 = #$12 bytes)
level_4_enemy_screen_ptr_tbl ENT
            dw    level_4_enemy_screen_00    ; CPU address $b9c1
            dw    level_4_enemy_screen_01    ; CPU address $b9cf
            dw    level_4_enemy_screen_02    ; CPU address $b9e0
            dw    level_4_enemy_screen_03    ; CPU address $b9ee
            dw    level_4_enemy_screen_04    ; CPU address $b9fc
            dw    level_4_enemy_screen_05    ; CPU address $ba0a
            dw    level_4_enemy_screen_06    ; CPU address $ba15
            dw    level_4_enemy_screen_07    ; CPU address $ba20
            dw    level_4_enemy_screen_08    ; CPU address $ba31

; level 4 enemy data (#$87 bytes)
; first byte specifies number of wall cores to destroy
; then enemies are described
; byte 0 = location of object
;  * xxxx .... - Y position * #$10
;  * .... xxxx - X position * #$10
; byte 1 = enemy type and position adjustment
;  * x... .... - Y position + #$07
;  * .x.. .... - X position + #$07
;  * ..xx xxxx object type
; byte 2 = enemy attributes
;  * xxxx .... - Y position of enemy
;  * .... xxxx - X position of enemy
level_4_enemy_screen_00 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $11,$19,$01    ; enemy type #$19 (indoor soldier generator)
            db    $68,$94,$04    ; enemy type #$14 (core)
            db    $66,$d3,$00    ; enemy type #$13 (wall turret)
            db    $69,$d3,$00    ; enemy type #$13 (wall turret)
            db    $ff

level_4_enemy_screen_01 ENT
            db    $04    ; number of cores to destroy to advance to next room
            db    $11,$19,$01    ; enemy type #$19 (indoor soldier generator)
            db    $76,$54,$03    ; enemy type #$14 (core)
            db    $77,$54,$01    ; enemy type #$14 (core)
            db    $78,$54,$01    ; enemy type #$14 (core)
            db    $79,$54,$03    ; enemy type #$14 (core)
            db    $ff

level_4_enemy_screen_02 ENT
            db    $02    ; number of cores to destroy to advance to next room
            db    $11,$19,$01    ; enemy type #$19 (indoor soldier generator)
            db    $67,$d4,$04    ; enemy type #$14 (core)
            db    $68,$d4,$04    ; enemy type #$14 (core)
            db    $58,$93,$00    ; enemy type #$13 (wall turret)
            db    $ff

level_4_enemy_screen_03 ENT
            db    $02    ; number of cores to destroy to advance to next room
            db    $11,$19,$01    ; enemy type #$19 (indoor soldier generator)
            db    $68,$13,$00    ; enemy type #$13 (wall turret)
            db    $77,$54,$03    ; enemy type #$14 (core)
            db    $78,$54,$03    ; enemy type #$14 (core)
            db    $ff

level_4_enemy_screen_04 ENT
            db    $02    ; number of cores to destroy to advance to next room
            db    $11,$19,$01    ; enemy type #$19 (indoor soldier generator)
            db    $66,$d4,$03    ; enemy type #$14 (core)
            db    $68,$93,$00    ; enemy type #$13 (wall turret)
            db    $69,$d4,$03    ; enemy type #$14 (core)
            db    $ff

level_4_enemy_screen_05 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $11,$1a,$01    ; enemy type #$1a (indoor roller generator)
            db    $11,$19,$01    ; enemy type #$19 (indoor soldier generator)
            db    $68,$94,$03    ; enemy type #$14 (core)
            db    $ff

level_4_enemy_screen_06 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $11,$19,$01    ; enemy type #$19 (indoor soldier generator)
            db    $58,$94,$03    ; enemy type #$14 (core)
            db    $68,$93,$00    ; enemy type #$13 (wall turret)
            db    $ff

level_4_enemy_screen_07 ENT
            db    $01    ; number of cores to destroy to advance to next room
            db    $11,$19,$01    ; enemy type #$19 (indoor soldier generator)
            db    $58,$13,$00    ; enemy type #$13 (wall turret)
            db    $66,$d3,$00    ; enemy type #$13 (wall turret)
            db    $68,$94,$0b    ; enemy type #$14 (core)
            db    $69,$d3,$00    ; enemy type #$13 (wall turret)
            db    $ff

; boss screen
level_4_enemy_screen_08 ENT
            db    $02    ; number of cores to destroy to advance to next room
            db    $11,$20,$00    ; enemy type #$20 (red and blue soldier generator)
            db    $36,$5c,$00    ; enemy type #$1c (boss gemini)
            db    $39,$5c,$00    ; enemy type #$1c (boss gemini)
            db    $58,$08,$00    ; enemy type #$08 (wall turret)
            db    $85,$0a,$00    ; enemy type #$0a (wall plating)
            db    $88,$0a,$01    ; enemy type #$0a (wall plating)
            db    $8b,$0a,$00    ; enemy type #$0a (wall plating)
            db    $ff

; pointer table for level 5 enemy groups (#$16 * #$02 = #$2c bytes)
level_5_enemy_screen_ptr_tbl ENT
            dw    level_5_enemy_screen_00    ; CPU address $ba74
            dw    level_5_enemy_screen_01    ; CPU address $ba81
            dw    level_5_enemy_screen_02    ; CPU address $ba8b
            dw    level_5_enemy_screen_03    ; CPU address $ba92
            dw    level_5_enemy_screen_04    ; CPU address $ba9f
            dw    level_5_enemy_screen_05    ; CPU address $baa9
            dw    level_5_enemy_screen_06    ; CPU address $baad
            dw    level_5_enemy_screen_07    ; CPU address $bab6
            dw    level_5_enemy_screen_08    ; CPU address $babd
            dw    level_5_enemy_screen_09    ; CPU address $baca
            dw    level_5_enemy_screen_0a    ; CPU address $bad1
            dw    level_5_enemy_screen_0b    ; CPU address $bad8
            dw    level_5_enemy_screen_0c    ; CPU address $badc
            dw    level_5_enemy_screen_0d    ; CPU address $bae6
            dw    level_5_enemy_screen_0e    ; CPU address $baed
            dw    level_5_enemy_screen_0f    ; CPU address $baf7
            dw    level_5_enemy_screen_10    ; CPU address $bb01
            dw    level_5_enemy_screen_11    ; CPU address $bb05
            dw    level_5_enemy_screen_12    ; CPU address $bb12
            dw    level_5_enemy_screen_13    ; CPU address $bb1f
            dw    level_5_enemy_screen_14    ; CPU address $bb20
            dw    level_5_enemy_screen_15    ; CPU address $bb23

level_5_enemy_screen_00 ENT
            db    $20,$10,$60    ; ice grenade generator (enemy type #$10), attribute: 000, location: (#$20, #$60)
            db    $50,$10,$61    ; ice grenade generator (enemy type #$10), attribute: 001, location: (#$50, #$60)
            db    $60,$0e,$82    ; turret man (enemy type #$0e), attribute: 010, location: (#$60, #$80)
            db    $d8,$10,$60    ; ice grenade generator (enemy type #$10), attribute: 000, location: (#$d8, #$60)
            db    $ff

level_5_enemy_screen_01 ENT
            db    $00,$0e,$81    ; turret man (enemy type #$0e), attribute: 001, location: (#$00, #$80)
            db    $08,$10,$63    ; ice grenade generator (enemy type #$10), attribute: 011, location: (#$08, #$60)
            db    $80,$02,$a1    ; pill box sensor (enemy type #$02), attribute: 001 (M), location: (#$80, #$a0)
            db    $ff

level_5_enemy_screen_02 ENT
            db    $60,$0e,$82    ; turret man (enemy type #$0e), attribute: 010, location: (#$60, #$80)
            db    $c0,$0e,$b2    ; turret man (enemy type #$0e), attribute: 010, location: (#$c0, #$b0)
            db    $ff

level_5_enemy_screen_03 ENT
            db    $20,$0e,$51    ; turret man (enemy type #$0e), attribute: 001, location: (#$20, #$50)
            db    $60,$03,$30    ; flying capsule (enemy type #$03), attribute: 000 (R), location: (#$60, #$30)
            db    $d8,$10,$43    ; ice grenade generator (enemy type #$10), attribute: 011, location: (#$d8, #$40)
            db    $f0,$10,$43    ; ice grenade generator (enemy type #$10), attribute: 011, location: (#$f0, #$40)
            db    $ff

level_5_enemy_screen_04 ENT
            db    $80,$10,$53    ; ice grenade generator (enemy type #$10), attribute: 011, location: (#$80, #$50)
            db    $c0,$10,$53    ; ice grenade generator (enemy type #$10), attribute: 011, location: (#$c0, #$50)
            db    $d0,$0e,$81    ; turret man (enemy type #$0e), attribute: 001, location: (#$d0, #$80)
            db    $ff

level_5_enemy_screen_05 ENT
            db    $60,$02,$82    ; pill box sensor (enemy type #$02), attribute: 010 (F), location: (#$60, #$80)
            db    $ff

level_5_enemy_screen_06 ENT
            db    $40,$83,$30,$76,$b3    ; flying capsule (enemy type #$03), attribute: 000 (R), location: (#$40, #$30)
; repeat: 2 [(y = #$70, attr = 110 (Falcon)), (y = #$b0, attr = 011 (S))]
            db    $40,$0c,$d8    ; scuba diver (enemy type #$0c), attribute: 000, location: (#$40, #$d8)
            db    $ff

level_5_enemy_screen_07 ENT
            db    $10,$0c,$d8    ; scuba diver (enemy type #$0c), attribute: 000, location: (#$10, #$d8)
            db    $a0,$06,$80    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$a0, #$80)
            db    $ff

level_5_enemy_screen_08 ENT
            db    $00,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$00, #$b0)
            db    $40,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$40, #$b0)
            db    $80,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$80, #$b0)
            db    $c0,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$c0, #$b0)
            db    $ff

level_5_enemy_screen_09 ENT
            db    $01,$12,$32    ; tank (enemy type #$12), attribute: 010, location: (#$01, #$30)
            db    $00,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$00, #$b0)
            db    $ff

level_5_enemy_screen_0a ENT
            db    $80,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$80, #$b0)
            db    $c0,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$c0, #$b0)
            db    $ff

level_5_enemy_screen_0b ENT
            db    $a8,$0e,$a1    ; turret man (enemy type #$0e), attribute: 001, location: (#$a8, #$a0)
            db    $ff

level_5_enemy_screen_0c ENT
            db    $40,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$40, #$b0)
            db    $80,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$80, #$b0)
            db    $c0,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$c0, #$b0)
            db    $ff

level_5_enemy_screen_0d ENT
            db    $01,$12,$33    ; tank (enemy type #$12), attribute: 011, location: (#$01, #$30)
            db    $00,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$00, #$b0)
            db    $ff

level_5_enemy_screen_0e ENT
            db    $80,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$80, #$b0)
            db    $c0,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$c0, #$b0)
            db    $d0,$0e,$a1    ; turret man (enemy type #$0e), attribute: 001, location: (#$d0, #$a0)
            db    $ff

level_5_enemy_screen_0f ENT
            db    $60,$10,$52    ; ice grenade generator (enemy type #$10), attribute: 010, location: (#$60, #$50)
            db    $a0,$10,$53    ; ice grenade generator (enemy type #$10), attribute: 011, location: (#$a0, #$50)
            db    $e8,$10,$53    ; ice grenade generator (enemy type #$10), attribute: 011, location: (#$e8, #$50)
            db    $ff

level_5_enemy_screen_10 ENT
            db    $60,$02,$a4    ; pill box sensor (enemy type #$02), attribute: 100 (L), location: (#$60, #$a0)
            db    $ff

level_5_enemy_screen_11 ENT
            db    $00,$10,$80    ; ice grenade generator (enemy type #$10), attribute: 000, location: (#$00, #$80)
            db    $60,$10,$81    ; ice grenade generator (enemy type #$10), attribute: 001, location: (#$60, #$80)
            db    $b0,$0e,$81    ; turret man (enemy type #$0e), attribute: 001, location: (#$b0, #$80)
            db    $c0,$10,$82    ; ice grenade generator (enemy type #$10), attribute: 010, location: (#$c0, #$80)
            db    $ff

level_5_enemy_screen_12 ENT
            db    $00,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$00, #$b0)
            db    $40,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$40, #$b0)
            db    $80,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$80, #$b0)
            db    $c0,$13,$b0    ; ice pipe (enemy type #$13), attribute: 000, location: (#$c0, #$b0)
            db    $ff

level_5_enemy_screen_13 ENT
            db    $ff

level_5_enemy_screen_14 ENT
            db    $01,$14,$30    ; alien carrier/boss ufo (enemy type #$14), attribute: 000, location: (#$01, #$30)

level_5_enemy_screen_15 ENT
            db    $ff

level_6_enemy_screen_ptr_tbl ENT
            dw    level_6_enemy_screen_00
            dw    level_6_enemy_screen_01
            dw    level_6_enemy_screen_02
            dw    level_6_enemy_screen_03
            dw    level_6_enemy_screen_04
            dw    level_6_enemy_screen_05
            dw    level_6_enemy_screen_06
            dw    level_6_enemy_screen_07
            dw    level_6_enemy_screen_08
            dw    level_6_enemy_screen_09
            dw    level_6_enemy_screen_0a
            dw    level_6_enemy_screen_0b
            dw    level_6_enemy_screen_0c

level_6_enemy_screen_00 ENT
            db    $40,$05,$84    ; soldier (enemy type #$05), attribute: 100, location: (#$40, #$80)
            db    $60,$05,$68    ; soldier (enemy type #$05), attribute: 000, location: (#$60, #$68)
            db    $c0,$02,$a1    ; pill box sensor (enemy type #$02), attribute: 001 (M), location: (#$c0, #$a0)
            db    $e0,$06,$60    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$e0, #$60)
            db    $ff

level_6_enemy_screen_01 ENT
            db    $80,$0e,$61    ; turret man (enemy type #$0e), attribute: 001, location: (#$80, #$60)
            db    $e0,$0e,$61    ; turret man (enemy type #$0e), attribute: 001, location: (#$e0, #$60)
            db    $f0,$0e,$c1    ; turret man (enemy type #$0e), attribute: 001, location: (#$f0, #$c0)
            db    $ff

level_6_enemy_screen_02 ENT
            db    $a0,$0e,$c1    ; turret man (enemy type #$0e), attribute: 001, location: (#$a0, #$c0)
            db    $a0,$06,$90    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$a0, #$90)
            db    $ff

level_6_enemy_screen_03 ENT
            db    $40,$02,$ac    ; pill box sensor (enemy type #$02), attribute: 100 (L), location: (#$40, #$a8)
            db    $48,$10,$26    ; fire beam down (enemy type #$10), attribute: 110, location: (#$48, #$20)
            db    $c8,$10,$25    ; fire beam down (enemy type #$10), attribute: 101, location: (#$c8, #$20)
            db    $e0,$0e,$91    ; turret man (enemy type #$0e), attribute: 001, location: (#$e0, #$90)
            db    $f0,$0e,$c1    ; turret man (enemy type #$0e), attribute: 001, location: (#$f0, #$c0)
            db    $ff

level_6_enemy_screen_04 ENT
            db    $28,$10,$27    ; fire bean down (enemy type #$10), attribute: 111, location: (#$28, #$20)
            db    $b8,$91,$58,$84,$b2    ; fire bean left (enemy type #$11), attribute: 000, location: (#$b8, #$58)
; repeat: 2 [(y = #$80, attr = 100), (y = #$b0, attr = 010)]
            db    $ff

level_6_enemy_screen_05 ENT
            db    $58,$51,$6c,$99    ; fire bean left (enemy type #$11), attribute: 100, location: (#$58, #$68), repeat: 1 [(y = #$98, attr = 001)]
            db    $a8,$10,$26    ; fire bean down (enemy type #$10), attribute: 110, location: (#$a8, #$20)
            db    $a0,$02,$ad    ; pill box sensor (enemy type #$02), attribute: 101 (B), location: (#$a0, #$a8)
            db    $c8,$06,$30    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$c8, #$30)
            db    $f8,$11,$c2    ; fire bean left (enemy type #$11), attribute: 010, location: (#$f8, #$c0)
            db    $ff

level_6_enemy_screen_06 ENT
            db    $58,$51,$39,$64    ; fire bean left (enemy type #$11), attribute: 001, location: (#$58, #$38), repeat: 1 [(y = #$60, attr = 100)]
            db    $a8,$12,$6e    ; fire bean right (enemy type #$12), attribute: 110, location: (#$a8, #$68)
            db    $ff

level_6_enemy_screen_07 ENT
            db    $40,$0e,$61    ; turret man (enemy type #$0e), attribute: 001, location: (#$40, #$60)
            db    $48,$12,$99    ; fire bean right (enemy type #$12), attribute: 001, location: (#$48, #$98)
            db    $68,$10,$25    ; fire bean down (enemy type #$10), attribute: 101, location: (#$68, #$20)
            db    $a8,$12,$c0    ; fire bean right (enemy type #$12), attribute: 000, location: (#$a8, #$c0)
            db    $e8,$10,$27    ; fire bean down (enemy type #$10), attribute: 111, location: (#$e8, #$20)
            db    $ff

level_6_enemy_screen_08 ENT
            db    $60,$4e,$91,$c1    ; turret man (enemy type #$0e), attribute: 001, location: (#$60, #$90), repeat: 1 [(y = #$c0, attr = 001)]
            db    $68,$52,$6a,$ca    ; fire bean right (enemy type #$12), attribute: 010, location: (#$68, #$68), repeat: 1 [(y = #$c8, attr = 010)]
            db    $e8,$12,$64    ; fire bean right (enemy type #$12), attribute: 100, location: (#$e8, #$60)
            db    $f0,$0e,$91    ; turret man (enemy type #$0e), attribute: 001, location: (#$f0, #$90)
            db    $ff

level_6_enemy_screen_09 ENT
            db    $68,$10,$23    ; fire bean down (enemy type #$10), attribute: 011, location: (#$68, #$20)
            db    $ff

level_6_enemy_screen_0a ENT
            db    $ff

level_6_enemy_screen_0b ENT
            db    $b1,$13,$a0    ; giant boss soldier (enemy type #$13), attribute: 000, location: (#$b1, #$a0)
            db    $ff

level_6_enemy_screen_0c ENT
            db    $ff

; pointer table for level 7 enemy data (#$0f * #$02 = #$1e bytes)
; enemy format
; xx tt yy
; xx = X position
; xxxxxxxx X position

; tt = enemy type + repeat
; xx...... repeat
; ..xxxxxx enemy type

; yy = Y position + attributes
; xxxxx... Y position
; .....xxx attributes
level_7_enemy_screen_ptr_tbl ENT
            dw    level_7_enemy_screen_00    ; CPU address $bbd5
            dw    level_7_enemy_screen_01    ; CPU address $bbed
            dw    level_7_enemy_screen_02    ; CPU address $bbfd
            dw    level_7_enemy_screen_03    ; CPU address $bc0d
            dw    level_7_enemy_screen_04    ; CPU address $bc17
            dw    level_7_enemy_screen_05    ; CPU address $bc36
            dw    level_7_enemy_screen_06    ; CPU address $bc40
            dw    level_7_enemy_screen_07    ; CPU address $bc44
            dw    level_7_enemy_screen_08    ; CPU address $bc4b
            dw    level_7_enemy_screen_09    ; CPU address $bc67
            dw    level_7_enemy_screen_0a    ; CPU address $bc77
            dw    level_7_enemy_screen_0b    ; CPU address $bc81
            dw    level_7_enemy_screen_0c    ; CPU address $bc91
            dw    level_7_enemy_screen_0d    ; CPU address $bc9b
            dw    level_7_enemy_screen_0e    ; CPU address $bca8

level_7_enemy_screen_00 ENT
            db    $47,$10,$a1    ; mechanical claw (lower level)
            db    $67,$10,$a5    ; mechanical claw (lower level)
            db    $87,$10,$a9    ; mechanical claw (lower level)
            db    $97,$10,$40    ; mechanical claw (top level)
            db    $a7,$50,$44    ; mechanical claw (top level)
            db    $ad,$b7,$10    ; mechanical claw (repeat once)
            db    $48    ; repeated mechanical claw top
            db    $c7,$50,$4c    ; mechanical claw (repeat once)
            db    $a1    ; repeated mechanical claw (bottom)
            db    $ff

level_7_enemy_screen_01 ENT
            db    $00,$03,$a2    ; flying capsule
            db    $80,$15,$c0    ; mining cart (stationary)
            db    $97,$10,$42    ; mechanical claw
            db    $a7,$10,$46    ; mechanical claw
            db    $f7,$10,$ac    ; mechanical claw
            db    $ff

level_7_enemy_screen_02 ENT
            db    $07,$10,$a8    ; mechanical claw
            db    $18,$0e,$60    ; turret man
            db    $64,$11,$b0    ; spiked wall
            db    $84,$11,$b1    ; spiked wall
            db    $90,$03,$b0    ; flying capsule
            db    $ff

level_7_enemy_screen_03 ENT
            db    $04,$12,$92    ; tall spiked wall
            db    $44,$12,$92    ; tall spiked wall
            db    $84,$12,$92    ; tall spiked wall
            db    $ff

level_7_enemy_screen_04 ENT
            db    $04,$11,$72    ; rising spiked wall (enemy type #$11), attribute: 010, location: (#$04, #$70)
            db    $07,$10,$ad    ; mechanical claw (enemy type #$10), attribute: 101, location: (#$07, #$a8)
            db    $27,$50,$48,$a9    ; mechanical claw (enemy type #$10), attribute: 000, location: (#$27, #$48), repeat: 1 [(y = #$a8, attr = 001)]
            db    $47,$50,$44,$a5    ; mechanical claw (enemy type #$10), attribute: 100, location: (#$47, #$40), repeat: 1 [(y = #$a0, attr = 101)]
            db    $67,$50,$40,$a1    ; mechanical claw (enemy type #$10), attribute: 000, location: (#$67, #$40), repeat: 1 [(y = #$a0, attr = 001)]
            db    $70,$13,$40    ; mining cart generator (enemy type #$13), attribute: 000, location: (#$70, #$40)
            db    $84,$11,$73    ; rising spiked wall (enemy type #$11), attribute: 011, location: (#$84, #$70)
            db    $87,$10,$ad    ; mechanical claw (enemy type #$10), attribute: 101, location: (#$87, #$a8)
            db    $a0,$15,$c0    ; stationary mining cart (enemy type #$15), attribute: 000, location: (#$a0, #$c0)
            db    $ff

level_7_enemy_screen_05 ENT
            db    $20,$02,$65    ; pill box sensor (enemy type #$02), attribute: 101 (B), location: (#$20, #$60)
            db    $c7,$10,$4a    ; mechanical claw (enemy type #$10), attribute: 010, location: (#$c7, #$48)
            db    $e7,$10,$42    ; mechanical claw (enemy type #$10), attribute: 010, location: (#$e7, #$40)
            db    $ff

level_7_enemy_screen_06 ENT
            db    $30,$15,$c0    ; stationary mining cart (enemy type #$15), attribute: 000, location: (#$30, #$c0)
            db    $ff

level_7_enemy_screen_07 ENT
            db    $10,$13,$40    ; mining cart generator (enemy type #$13), attribute: 000, location: (#$10, #$40)
            db    $f0,$06,$60    ; sniper (enemy type #$06), attribute: 000 (stand shoot bullets 3 at a time), location: (#$f0, #$60)
            db    $ff

level_7_enemy_screen_08 ENT
            db    $00,$03,$31    ; flying capsule (enemy type #$03), attribute: 001 (M), location: (#$00, #$30)
            db    $58,$15,$c0    ; stationary mining cart (enemy type #$15), attribute: 000, location: (#$58, #$c0)
            db    $80,$03,$c3    ; flying capsule (enemy type #$03), attribute: 011 (S), location: (#$80, #$c0)
            db    $84,$12,$70    ; tall spiked wall (enemy type #$12), attribute: 000, location: (#$84, #$70)
            db    $87,$10,$ab    ; mechanical claw (enemy type #$10), attribute: 011, location: (#$87, #$a8)
            db    $a7,$10,$ab    ; mechanical claw (enemy type #$10), attribute: 011, location: (#$a7, #$a8)
            db    $c4,$12,$70    ; tall spiked wall (enemy type #$12), attribute: 000, location: (#$c4, #$70)
            db    $c7,$10,$a7    ; mechanical claw (enemy type #$10), attribute: 111, location: (#$c7, #$a0)
            db    $e7,$10,$a7    ; mechanical claw (enemy type #$10), attribute: 111, location: (#$e7, #$a0)
            db    $ff

level_7_enemy_screen_09 ENT
            db    $04,$12,$70    ; tall spiked wall (enemy type #$12), attribute: 000, location: (#$04, #$70)
            db    $07,$10,$a3    ; mechanical claw (enemy type #$10), attribute: 011, location: (#$07, #$a0)
            db    $a4,$11,$93    ; rising spiked wall (enemy type #$11), attribute: 011, location: (#$a4, #$90)
            db    $c4,$11,$97    ; rising spiked wall (enemy type #$11), attribute: 111, location: (#$c4, #$90)
            db    $e4,$11,$9b    ; rising spiked wall (enemy type #$11), attribute: 011, location: (#$e4, #$98)
            db    $ff

level_7_enemy_screen_0a ENT
            db    $d7,$10,$86    ; mechanical claw (enemy type #$10), attribute: 110, location: (#$d7, #$80)
            db    $e7,$10,$8e    ; mechanical claw (enemy type #$10), attribute: 110, location: (#$e7, #$88)
            db    $f7,$10,$86    ; mechanical claw (enemy type #$10), attribute: 110, location: (#$f7, #$80)
            db    $ff

level_7_enemy_screen_0b ENT
            db    $07,$10,$8e    ; mechanical claw (enemy type #$10), attribute: 110, location: (#$07, #$88)
            db    $17,$10,$86    ; mechanical claw (enemy type #$10), attribute: 110, location: (#$17, #$80)
            db    $27,$10,$8e    ; mechanical claw (enemy type #$10), attribute: 110, location: (#$27, #$88)
            db    $44,$11,$df    ; rising spiked wall (enemy type #$11), attribute: 111, location: (#$44, #$d8)
            db    $f0,$0e,$c0    ; turret man (enemy type #$0e), attribute: 000, location: (#$f0, #$c0)
            db    $ff

level_7_enemy_screen_0c ENT
            db    $20,$0e,$c0    ; turret man (enemy type #$0e), attribute: 000, location: (#$20, #$c0)
            db    $a8,$0e,$a0    ; turret man (enemy type #$0e), attribute: 000, location: (#$a8, #$a0)
            db    $fe,$0e,$a0    ; turret man (enemy type #$0e), attribute: 000, location: (#$fe, #$a0)
            db    $ff

level_7_enemy_screen_0d ENT
            db    $69,$17,$d1    ; mortar launcher (enemy type #$17), attribute: 001, location: (#$69, #$d0)
            db    $a9,$17,$d0    ; mortar launcher (enemy type #$17), attribute: 000, location: (#$a9, #$d0)
            db    $d9,$16,$80    ; armored door (enemy type #$16), attribute: 000, location: (#$d9, #$80)
            db    $e1,$18,$a0    ; soldier generator (enemy type #$18), attribute: 000, location: (#$e1, #$a0)
            db    $ff

level_7_enemy_screen_0e ENT
            db    $ff

; pointer table for level 8 enemy groups (#$0b * #$02 = #$16 bytes)
level_8_enemy_screen_ptr_tbl ENT
            dw    level_8_enemy_screen_00    ; CPU address $bcc0
            dw    level_8_enemy_screen_01    ; CPU address $bcc8
            dw    level_8_enemy_screen_02    ; CPU address $bcd5
            dw    level_8_enemy_screen_03    ; CPU address $bcdc
            dw    level_8_enemy_screen_04    ; CPU address $bcec
            dw    level_8_enemy_screen_05    ; CPU address $bcf3
            dw    level_8_enemy_screen_06    ; CPU address $bcfd
            dw    level_8_enemy_screen_07    ; CPU address $bd07
            dw    level_8_enemy_screen_08    ; CPU address $bd11
            dw    level_8_enemy_screen_09    ; CPU address $bd21
            dw    level_8_enemy_screen_0a    ; CPU address $bd3c

level_8_enemy_screen_ptr_tbl_end ENT
            db    $ff    ; unused byte

level_8_enemy_screen_00 ENT
            db    $40,$43,$31,$c5    ; flying capsule (enemy type #$03), attribute: 001 (M), location: (#$40, #$30), repeat: 1 [(y = #$c0, attr = 101)]
            db    $f0,$11,$a1    ; alien fetus (enemy type #$11), attribute: 001, location: (#$f0, #$a0)
            db    $ff

level_8_enemy_screen_01 ENT
            db    $60,$11,$51    ; alien fetus (enemy type #$11), attribute: 001, location: (#$60, #$50)
            db    $a0,$11,$61    ; alien fetus (enemy type #$11), attribute: 001, location: (#$a0, #$60)
            db    $a8,$11,$61    ; alien fetus (enemy type #$11), attribute: 001, location: (#$a8, #$60)
            db    $b0,$10,$60    ; alien guardian (enemy type #$10), attribute: 000, location: (#$b0, #$60)
            db    $ff

level_8_enemy_screen_02 ENT
            db    $be,$12,$40    ; alien mouth (enemy type #$12), attribute: 000, location: (#$be, #$40)
            db    $de,$12,$40    ; alien mouth (enemy type #$12), attribute: 000, location: (#$de, #$40)
            db    $ff

level_8_enemy_screen_03 ENT
            db    $1e,$12,$60    ; alien mouth (enemy type #$12), attribute: 000, location: (#$1e, #$60)
            db    $3e,$12,$60    ; alien mouth (enemy type #$12), attribute: 000, location: (#$3e, #$60)
            db    $de,$12,$60    ; alien mouth (enemy type #$12), attribute: 000, location: (#$de, #$60)
            db    $e0,$03,$c3    ; flying capsule (enemy type #$03), attribute: 011 (S), location: (#$e0, #$c0)
            db    $fe,$12,$60    ; alien mouth (enemy type #$12), attribute: 000, location: (#$fe, #$60)
            db    $ff

level_8_enemy_screen_04 ENT
            db    $de,$12,$e0    ; alien mouth (enemy type #$12), attribute: 000, location: (#$de, #$e0)
            db    $fe,$12,$e0    ; alien mouth (enemy type #$12), attribute: 000, location: (#$fe, #$e0)
            db    $ff

level_8_enemy_screen_05 ENT
            db    $1e,$12,$e0    ; alien mouth (enemy type #$12), attribute: 000, location: (#$1e, #$e0)
            db    $de,$12,$80    ; alien mouth (enemy type #$12), attribute: 000, location: (#$de, #$80)
            db    $fe,$12,$80    ; alien mouth (enemy type #$12), attribute: 000, location: (#$fe, #$80)
            db    $ff

level_8_enemy_screen_06 ENT
            db    $7e,$12,$e0    ; alien mouth (enemy type #$12), attribute: 000, location: (#$7e, #$e0)
            db    $9e,$12,$e0    ; alien mouth (enemy type #$12), attribute: 000, location: (#$9e, #$e0)
            db    $fe,$12,$80    ; alien mouth (enemy type #$12), attribute: 000, location: (#$fe, #$80)
            db    $ff

level_8_enemy_screen_07 ENT
            db    $1e,$12,$80    ; alien mouth (enemy type #$12), attribute: 000, location: (#$1e, #$80)
            db    $be,$12,$e0    ; alien mouth (enemy type #$12), attribute: 000, location: (#$be, #$e0)
            db    $de,$12,$e0    ; alien mouth (enemy type #$12), attribute: 000, location: (#$de, #$e0)
            db    $ff

level_8_enemy_screen_08 ENT
            db    $3e,$12,$60    ; alien mouth (enemy type #$12), attribute: 000, location: (#$3e, #$60)
            db    $5e,$12,$60    ; alien mouth (enemy type #$12), attribute: 000, location: (#$5e, #$60)
            db    $a0,$14,$c8    ; alien spider (enemy type #$14), attribute: 000, location: (#$a0, #$c8)
            db    $c0,$14,$c8    ; alien spider (enemy type #$14), attribute: 000, location: (#$c0, #$c8)
            db    $f0,$14,$c8    ; alien spider (enemy type #$14), attribute: 000, location: (#$f0, #$c8)
            db    $ff

level_8_enemy_screen_09 ENT
            db    $30,$14,$c8    ; alien spider (enemy type #$14), attribute: 000, location: (#$30, #$c8)
            db    $3e,$12,$e0    ; alien mouth (enemy type #$12), attribute: 000, location: (#$3e, #$e0)
            db    $70,$14,$20    ; alien spider (enemy type #$14), attribute: 000, location: (#$70, #$20)
            db    $b8,$14,$c8    ; alien spider (enemy type #$14), attribute: 000, location: (#$b8, #$c8)
            db    $c0,$15,$40    ; spider spawn (enemy type #$15), attribute: 000, location: (#$c0, #$40)
            db    $c2,$15,$c0    ; spider spawn (enemy type #$15), attribute: 000, location: (#$c2, #$c0)
            db    $d1,$16,$70    ; alien heart (enemy type #$16), attribute: 000, location: (#$d1, #$70)
            db    $e0,$15,$40    ; spider spawn (enemy type #$15), attribute: 000, location: (#$e0, #$40)
            db    $e2,$15,$c0    ; spider spawn (enemy type #$15), attribute: 000, location: (#$e2, #$c0)

; share level_8_enemy_screen_09 end of data byte with empty screen
level_8_enemy_screen_0a ENT
            db    $ff

; unused #$2c3 bytes out of #$4000 bytes total (95.68% full)
; unused 707 bytes out of 16,384 bytes total (95.68% full)
; filled with 707 #$ff bytes by contra.cfg configuration
bank_2_unused_space ENT

            ds    $C000-*,$FF
            put   rom_07_fixed.s

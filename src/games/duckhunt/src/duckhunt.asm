; PRG CRC32 checksum: 90ca616d
; CHR CRC32 checksum: 4e049e03
; Overall CRC32 checksum: 24598791
; Code base address: $c000

.setcpu "6502x"
.segment "HEADER"

.byte "NES", $1a                 ; Magic string that always begins an iNES header
.byte $01                        ; Number of 16KB PRG-ROM banks
.byte $01                        ; Number of 8KB CHR-ROM banks
.byte $01                        ; Control bits 1
.byte $00                        ; Control bits 2
.byte $00                        ; Number of 8KB PRG-RAM banks
.byte $00                        ; Video format NTSC/PAL

APU_DMC_FREQ = $4010
APU_DMC_LEN = $4013
APU_DMC_RAW = $4011
APU_DMC_START = $4012
APU_FRAME = $4017
APU_NOISE_HI = $400F
APU_NOISE_LO = $400E
APU_NOISE_VOL = $400C
APU_PL1_HI = $4003
APU_PL1_LO = $4002
APU_PL1_SWEEP = $4001
APU_PL1_VOL = $4000
APU_PL2_SWEEP = $4005
APU_PL2_VOL = $4004
APU_SND_CHN = $4015
APU_TRI_HI = $400B
APU_TRI_LINEAR = $4008
APU_TRI_LO = $400A
JOYPAD1 = $4016
JOYPAD2 = $4017
OAM_ADDR = $2003
OAM_DMA = $4014
PPU_ADDR = $2006
PPU_CTRL = $2000
PPU_DATA = $2007
PPU_MASK = $2001
PPU_SCROLL = $2005
PPU_STATUS = $2002


_var_0000_indexed = $0000
_var_0001 = $0001
_var_0002_indexed = $0002
_var_0003 = $0003
_var_0004 = $0004
Submode = $0005
_var_0006 = $0006
_var_0007 = $0007
_var_0008 = $0008
_var_0009 = $0009
_var_000a = $000A
_var_000c = $000C
_var_000d = $000D
_var_000e = $000E
_var_000f = $000F
_var_0010_indexed = $0010
_var_0011 = $0011
_var_0012_indexed = $0012
_var_0013 = $0013
_var_0014_indexed = $0014
_var_0015 = $0015
JOYPAD1MIRROR = $0016
_var_001a = $001A
_var_001b = $001B
_var_001c_indexed = $001C
_var_001d = $001D
_var_001e = $001E
_var_001f = $001F
_var_0020 = $0020
_var_0021 = $0021
_var_0022 = $0022
_var_0023 = $0023
MainMenuActive = $0024
_var_0025 = $0025
_var_0026 = $0026
WhiteBoxVisible = $0027
_var_0028 = $0028
_var_0029 = $0029
_var_002a_indexed = $002A
_var_002b_indexed = $002B
TitleScreenSongCountdown = $002D
_var_002f = $002F
_var_0030_indexed = $0030
CurrentSpritePhase = $0031
_var_0032 = $0032
_var_0033 = $0033
_var_0034 = $0034
_var_0035 = $0035
_var_0036 = $0036
_var_0037 = $0037
_var_0038 = $0038
_var_0039 = $0039
_var_003a = $003A

DuckNumber = $003B
DogColor = $003C
DuckColor = $003F

_var_0040_indexed = $0040
_var_0041_indexed = $0041
_var_0042_indexed = $0042
_var_0043_indexed = $0043
_var_0044_indexed = $0044
_var_0045 = $0045
_var_0046 = $0046
_var_0047 = $0047
_var_0048 = $0048
_var_0049 = $0049
DuckDirection = $004A
_var_004b = $004B
_var_004c = $004C
_var_004d = $004D
TargetFlyingAway = $004E
_var_0050_indexed = $0050
_var_0053 = $0053
_var_0054 = $0054
_var_0055 = $0055
_var_0056 = $0056
_var_0057 = $0057
_var_0058 = $0058
_var_005e = $005E
_var_005f = $005F
_var_0060_indexed = $0060
_var_0061_indexed = $0061
_var_0080_indexed = $0080
_var_0081_indexed = $0081
_var_0082_indexed = $0082
_var_0083_indexed = $0083
_var_0091 = $0091
_var_0093 = $0093
_var_0094 = $0094
_var_0095 = $0095
_var_0096 = $0096
_var_0097 = $0097
_var_0098 = $0098
_var_0099 = $0099
_var_009a = $009A
_var_009b = $009B
_var_009c = $009C
_var_009d = $009D
_var_009e = $009E
TargetDeactivationCountdown = $009F
_var_00a1 = $00A1
_var_00a2 = $00A2
_var_00a6 = $00A6
_var_00a7 = $00A7
_var_00a8 = $00A8
_var_00a9 = $00A9
CurrentNumberTargets = $00AA
MinimumNumShotTargets = $00AB
_var_00ad = $00AD
_var_00ae = $00AE
_var_00af = $00AF
_var_00b0 = $00B0
_var_00b1 = $00B1
_var_00b2 = $00B2
_var_00b3 = $00B3
_var_00b4 = $00B4
_var_00b5 = $00B5
_var_00b6 = $00B6
_var_00b7 = $00B7
_var_00b8 = $00B8

TargetActive = $00B9
RemainingShots = $00BA
CurrentActiveDuckTarget = $00BB
TargetFinishedFalling = $00BC
TargetShot = $00BD

NextLevelCountdown = $00BE
LevelNumber = $00C1
_var_00c2 = $00C2
_var_00c3_indexed = $00C3

; Score
; Actual size is 3 bytes - technically one var, $00C4
ScoreA = $00C4
ScoreB = $00C5
ScoreC = $00C6

_var_00c7_indexed = $00C7
_var_00c8_indexed = $00C8
_var_00c9_indexed = $00C9
_var_00ca_indexed = $00CA
_var_00d0_indexed = $00D0
_var_00d1 = $00D1
_var_00d2 = $00D2
_var_00d3 = $00D3
_var_00d4_indexed = $00D4
_var_00d8 = $00D8
_var_00d9 = $00D9
_var_00da = $00DA
_var_00db = $00DB
_var_00dc_indexed = $00DC
_var_00e0_indexed = $00E0
_var_00e4 = $00E4
_var_00e5 = $00E5
_var_00e6 = $00E6
_var_00e7 = $00E7
_var_00e9 = $00E9
_var_00ea = $00EA
_var_00eb = $00EB
_var_00ec = $00EC
_var_00ed = $00ED
_var_00ee = $00EE
_var_00ef = $00EF
_var_00f0 = $00F0
_var_00f1 = $00F1
_var_00f2 = $00F2
_var_00f3 = $00F3
_var_00f4_indexed = $00F4
_var_00f6_indexed = $00F6
_var_00f8_indexed = $00F8
_var_00f9_indexed = $00F9
_var_00fa_indexed = $00FA
_var_00fb = $00FB
_var_00fc_indexed = $00FC
_var_00fd = $00FD
_var_00fe_indexed = $00FE
_var_00ff = $00FF

; Start of Sprite data (size 100)
; more info: https://datacrystal.romhacking.net/wiki/Duck_Hunt:RAM_map
; prite data: [X, Type, Color, Y], ... 
; looks like the cdl hasn't gotten all these yet..
_var_0200_indexed = $0200
_var_02f0_indexed = $02F0
_var_02f1_indexed = $02F1
_var_02f2_indexed = $02F2
_var_02f3_indexed = $02F3
_var_02f4_indexed = $02F4
_var_02f5_indexed = $02F5
_var_02f6_indexed = $02F6
_var_02f7_indexed = $02F7

; Targets
TargetOneType = $0300
TargetOneState = $0301
TargetOneYCoordinate = $0302
TargetOneXCoordinate = $0303
TargetOneHorizontalDirection = $0304 ; might not be real, see below
TargetOneWingFrame = $0305 ; might not be real, see below

;; FIXME: In the RAM map, we have targets 1 - 4. However, we only have 1 and 2 (the Arcade vs. has 3 and 4)
;; But what is Target 3 in the vs., some of those values (like 03A0) is probably Target 2. So this needs to be
;; figured out
;; A lo

_var_030a_indexed = $030A
_var_030b_indexed = $030B
_var_0350 = $0350
_var_0351 = $0351
_var_03a0 = $03A0
_var_03a1 = $03A1
_var_03ef_indexed = $03EF
_var_03f0_indexed = $03F0
BackgroundColor = $0403
_var_0430_indexed = $0430
_var_0440_indexed = $0440
_var_0442_indexed = $0442
_var_0500_indexed = $0500
_var_0501_indexed = $0501
_var_0502 = $0502
_var_0560 = $0560
_var_0561_indexed = $0561

; RNG Seed
; actual size is 4 bytes - technically one var, $05Ec
RNGSeed1 = $05EC
RNGSeed2 = $05ED
RNGSeed3 = $05EE
RNGSeed4 = $05EF

_var_05f0_indexed = $05F0

StartButtonDown = $05FC
SelectButtonDown = $05FD

SelectedGameMode = $05FE
MenuAction = $05FF

_var_0610 = $0610
_var_0612 = $0612
_var_64fa_indexed = $64FA


.segment "CODE"

Reset:
  cld                            ; $C000  D8
  sei                            ; $C001  78

_label_c002:
  lda PPU_STATUS                 ; $C002  AD 02 20
  bpl _label_c002                ; $C005  10 FB
  ldx #$00                       ; $C007  A2 00
  stx PPU_CTRL                   ; $C009  8E 00 20
  stx PPU_MASK                   ; $C00C  8E 01 20
  dex                            ; $C00F  CA
  txs                            ; $C010  9A
  ldx a:RNGSeed1                ; $C011  AE EC 05
  ldy #$06                       ; $C014  A0 06
  sty z:_var_0001                ; $C016  84 01
  ldy #$00                       ; $C018  A0 00
  sty z:_var_0000_indexed        ; $C01A  84 00
  lda #$00                       ; $C01C  A9 00

_label_c01e:
  sta (_var_0000_indexed),Y      ; $C01E  91 00
  dey                            ; $C020  88
  bne _label_c01e                ; $C021  D0 FB
  dec z:_var_0001                ; $C023  C6 01
  bpl _label_c01e                ; $C025  10 F7
  txa                            ; $C027  8A
  bne _label_c02c                ; $C028  D0 02
  ldx #$5F                       ; $C02A  A2 5F

_label_c02c:
  stx a:RNGSeed1                ; $C02C  8E EC 05
  jsr _func_c22b                 ; $C02F  20 2B C2
  jsr _func_c23b                 ; $C032  20 3B C2
  ldy #$00                       ; $C035  A0 00
  sta PPU_SCROLL                 ; $C037  8D 05 20
  sta PPU_SCROLL                 ; $C03A  8D 05 20
  ldy #$01                       ; $C03D  A0 01
  sty z:MainMenuActive                ; $C03F  84 24
  lda #$0F                       ; $C041  A9 0F
  sta APU_SND_CHN                ; $C043  8D 15 40
  jsr _func_f581                 ; $C046  20 81 F5
  lda #$90                       ; $C049  A9 90
  sta PPU_CTRL                   ; $C04B  8D 00 20
  sta z:_var_0008                ; $C04E  85 08
  lda #$02                       ; $C050  A9 02
  sta z:_var_0009                ; $C052  85 09
  ldx #$0B                       ; $C054  A2 0B

_label_c056:
  lda a:_data_e5df_indexed,X     ; $C056  BD DF E5
  sta a:_var_05f0_indexed,X      ; $C059  9D F0 05
  dex                            ; $C05C  CA
  bpl _label_c056                ; $C05D  10 F7
  bmi _label_c07c                ; $C05F  30 1B

_label_c061:
  lda z:MainMenuActive                ; $C061  A5 24
  beq _label_c06b                ; $C063  F0 06
  lda z:_var_0026                ; $C065  A5 26
  cmp #$01                       ; $C067  C9 01
  bne _label_c06e                ; $C069  D0 03

_label_c06b:
  jsr _func_f56c                 ; $C06B  20 6C F5

_label_c06e:
  jsr _func_c348                 ; $C06E  20 48 C3
  jsr _func_c284                 ; $C071  20 84 C2
  jsr _func_c0b3                 ; $C074  20 B3 C0
  inc z:_var_002f                ; $C077  E6 2F
  jsr _func_c61e                 ; $C079  20 1E C6

_label_c07c:
  lda z:_var_0020                ; $C07C  A5 20
  bne _label_c061                ; $C07E  D0 E1
  jsr _func_c588                 ; $C080  20 88 C5
  jmp _label_c07c                ; $C083  4C 7C C0

NMI:
  php                            ; $C086  08
  pha                            ; $C087  48
  txa                            ; $C088  8A
  pha                            ; $C089  48
  tya                            ; $C08A  98
  pha                            ; $C08B  48
  lda #$00                       ; $C08C  A9 00
  sta OAM_ADDR                   ; $C08E  8D 03 20
  lda #$02                       ; $C091  A9 02
  sta OAM_DMA                    ; $C093  8D 14 40
  lda z:_var_0022                ; $C096  A5 22
  bne _label_c0a6                ; $C098  D0 0C
  jsr _func_c2bf                 ; $C09A  20 BF C2
  jsr _func_c249                 ; $C09D  20 49 C2
  jsr _func_c263                 ; $C0A0  20 63 C2
  jsr _func_c3c1                 ; $C0A3  20 C1 C3

_label_c0a6:
  ldy #$01                       ; $C0A6  A0 01
  sty z:_var_0022                ; $C0A8  84 22
  sty z:_var_0020                ; $C0AA  84 20
  pla                            ; $C0AC  68
  tay                            ; $C0AD  A8
  pla                            ; $C0AE  68
  tax                            ; $C0AF  AA
  pla                            ; $C0B0  68
  plp                            ; $C0B1  28
  rti                            ; $C0B2  40

_func_c0b3:
  lda z:MainMenuActive                ; $C0B3  A5 24
  beq _label_c0ba                ; $C0B5  F0 03
  jmp _label_c14e                ; $C0B7  4C 4E C1

_label_c0ba:
  lda z:JOYPAD1MIRROR        ; $C0BA  A5 16 - Load the joypad input as an accumulator
  and #$10                       ; $C0BC  29 10 - Check if the start button is down
  beq ClearStartButtonState                ; $C0BE  F0 5E - If the start button is not down (zero) clear the state of the start button (we know it's been pressed)
  ldy a:StartButtonDown                ; $C0C0  AC FC 05
  bne _label_c123                ; $C0C3  D0 5E
  iny                            ; $C0C5  C8
  sty a:StartButtonDown                ; $C0C6  8C FC 05
  ldy z:_var_0025                ; $C0C9  A4 25
  cpy #$10                       ; $C0CB  C0 10
  beq _label_c0ff                ; $C0CD  F0 30
  cpy #$03                       ; $C0CF  C0 03
  beq _label_c0df                ; $C0D1  F0 0C
  cpy #$04                       ; $C0D3  C0 04
  beq _label_c0df                ; $C0D5  F0 08
  cpy #$0B                       ; $C0D7  C0 0B
  beq _label_c0df                ; $C0D9  F0 04
  cpy #$0C                       ; $C0DB  C0 0C
  bne _label_c123                ; $C0DD  D0 44

_label_c0df:
  ldx #$05                       ; $C0DF  A2 05

_label_c0e1:
  lda z:_var_002a_indexed,X      ; $C0E1  B5 2A
  sta a:_var_0430_indexed,X      ; $C0E3  9D 30 04
  dex                            ; $C0E6  CA
  bpl _label_c0e1                ; $C0E7  10 F8
  lda z:_var_0009                ; $C0E9  A5 09
  and #$0E                       ; $C0EB  29 0E
  sta PPU_MASK                   ; $C0ED  8D 01 20
  sta z:_var_0009                ; $C0F0  85 09
  lda z:_var_0025                ; $C0F2  A5 25
  sta z:_var_001d                ; $C0F4  85 1D
  lda #$10                       ; $C0F6  A9 10
  sta z:_var_0025                ; $C0F8  85 25
  lda #$07                       ; $C0FA  A9 07
  jmp _label_c112                ; $C0FC  4C 12 C1

_label_c0ff:
  lda z:_var_0009                ; $C0FF  A5 09
  ora #$10                       ; $C101  09 10
  sta PPU_MASK                   ; $C103  8D 01 20
  sta z:_var_0009                ; $C106  85 09
  lda #$11                       ; $C108  A9 11
  sta z:_var_0025                ; $C10A  85 25
  lda #$30                       ; $C10C  A9 30
  sta z:_var_001c_indexed        ; $C10E  85 1C
  lda #$00                       ; $C110  A9 00

_label_c112:
  jsr _func_d464                 ; $C112  20 64 D4
  jsr _func_d4e2                 ; $C115  20 E2 D4
  jsr _func_c5d9                 ; $C118  20 D9 C5
  jmp _label_d521                ; $C11B  4C 21 D5

ClearStartButtonState:
  lda #$00                       ; $C11E  A9 00
  sta a:StartButtonDown                ; $C120  8D FC 05

_label_c123:
  lda z:_var_0025                ; $C123  A5 25
  jsr _jump_engine_c35e          ; $C125  20 5E C3

  .word _label_c81d              ; $C128  1D C8
  .word _label_c839              ; $C12A  39 C8
  .word _label_c854              ; $C12C  54 C8
  .word _label_c86e              ; $C12E  6E C8
  .word _label_d2c9              ; $C130  C9 D2
  .word _label_c5e0              ; $C132  E0 C5
  .word _label_c779              ; $C134  79 C7
  .word _label_c72c              ; $C136  2C C7
  .word _label_d54b              ; $C138  4B D5
  .word _label_d56a              ; $C13A  6A D5
  .word _label_d593              ; $C13C  93 D5
  .word _label_d5d2              ; $C13E  D2 D5
  .word _label_d2c9              ; $C140  C9 D2
  .word _label_c7ef              ; $C142  EF C7
  .word _label_c5e0              ; $C144  E0 C5
  .word _label_c5e0              ; $C146  E0 C5
  .word _label_c5e0              ; $C148  E0 C5
  .word _label_c271              ; $C14A  71 C2
  .word _label_c625              ; $C14C  25 C6

_label_c14e:
  lda #$00                       ; $C14E  A9 00
  sta a:MenuAction                ; $C150  8D FF 05 - load 0x0 as an accumulator to MenuAction, which means doing nothing, sit on idle
  lda #$01                       ; $C153  A9 01
  sta z:TargetActive                ; $C155  85 B9
  sta z:RemainingShots                ; $C157  85 BA
  lda z:_var_0026                ; $C159  A5 26
  beq _label_c18d                ; $C15B  F0 30
  jsr _func_d131                 ; $C15D  20 31 D1
  jsr _func_d160                 ; $C160  20 60 D1
  lda a:MenuAction                ; $C163  AD FF 05 - load menu action as an accumulator
  cmp #$01                       ; $C166  C9 01 - if MenuAction is set to 0x1
  beq StartGame                ; $C168  F0 0C - it means Start has been pressed, go into the game
  cmp #$02                       ; $C16A  C9 02 - if MenuAction is set to 0x2
  beq CycleGameMode                ; $C16C  F0 2B - cycle to the next gamemode
  lda z:JOYPAD1MIRROR        ; $C16E  A5 16 - Load the joypad mirror, will be used in other function calls
  and #$30                       ; $C170  29 30
  cmp #$10                       ; $C172  C9 10
  bne _label_c189                ; $C174  D0 13

StartGame:
  lda #$00                       ; $C176  A9 00 - Load accumulator to 0
  sta z:MainMenuActive                ; $C178  85 24 - Store that the main menu is not active
  sta z:_var_0025                ; $C17A  85 25
  jsr _func_d4e2                 ; $C17C  20 E2 D4
  jsr _func_c5e1                 ; $C17F  20 E1 C5
  lda #$02                       ; $C182  A9 02
  sta z:_var_002a_indexed        ; $C184  85 2A
  sta z:TitleScreenSongCountdown                ; $C186  85 2D
  rts                            ; $C188  60

_label_c189:
  ldx z:_var_0026                ; $C189  A6 26
  bne CheckSelectButtonDown                ; $C18B  D0 03

_label_c18d:
  jmp _label_c217                ; $C18D  4C 17 C2

CheckSelectButtonDown:
  cmp #$20                       ; $C190  C9 20 - Check if the select button is down on the joypad (user input is active)
  bne MarkSelectButtonUp                ; $C192  D0 15 - If not, make sure our local way of storing the select's state is showing it is up.
  lda a:SelectButtonDown                ; $C194  AD FD 05 - Load the select button's status
  bne ResetTitleScreenSongCountdown                ; $C197  D0 1E - If pressed, then it means the user is not AFK (or AFG? AFN?), so reset the title screen countdown

CycleGameMode:
  ldy a:SelectedGameMode                ; $C199  AC FE 05 - load Y to SelectedGameMode
  iny                            ; $C19C  C8 - Increment Y, also incrementing SELECTGAMEMODE
  cpy #$03                       ; $C19D  C0 03 - Compare with 0x3; SelectedGameMode should be 0x0, 0x1, or 0x2.
  bne SetGameMode                ; $C19F  D0 02 - If valid, call SetGameMode (valid option!)
  ldy #$00                       ; $C1A1  A0 00 - Otherwise, we cycled to last gamemode/final option, go back to the first

SetGameMode:
  sty a:SelectedGameMode                ; $C1A3  8C FE 05 - Store the value of what is selected to the SelectedGameMode
  jmp MarkSelectButtonDown                ; $C1A6  4C B2 C1 - Mark that the select button is down

MarkSelectButtonUp:
  cmp #$00                       ; $C1A9  C9 00 - Get the current joypad input
  bne MarkSelectButtonDown                ; $C1AB  D0 05 - If zero, there is nothing down, including select, so mark ti as down
  sta a:SelectButtonDown                ; $C1AD  8D FD 05 - TODO
  beq _label_c1bb                ; $C1B0  F0 09 - TODO

MarkSelectButtonDown:
  lda #$01                       ; $C1B2  A9 01
  sta a:SelectButtonDown                ; $C1B4  8D FD 05 - Load/store 01, marking the button down.

ResetTitleScreenSongCountdown:
  lda #$FF                       ; $C1B7  A9 FF - load the max value of the countdown (0xFF)
  sta z:TitleScreenSongCountdown                ; $C1B9  85 2D - store it to the accumulator

_label_c1bb:
  cpx #$01                       ; $C1BB  E0 01
  bne _label_c217                ; $C1BD  D0 58
  lda #$51                       ; $C1BF  A9 51
  sta a:_var_0500_indexed        ; $C1C1  8D 00 05
  lda #$24                       ; $C1C4  A9 24
  ldx #$04                       ; $C1C6  A2 04

_label_c1c8:
  sta a:_var_0501_indexed,X      ; $C1C8  9D 01 05
  dex                            ; $C1CB  CA
  bpl _label_c1c8                ; $C1CC  10 FA
  lda a:SelectedGameMode                ; $C1CE  AD FE 05
  asl a                          ; $C1D1  0A
  tax                            ; $C1D2  AA
  lda #$26                       ; $C1D3  A9 26
  sta a:_var_0501_indexed,X      ; $C1D5  9D 01 05
  ldx #$26                       ; $C1D8  A2 26
  ldy #$22                       ; $C1DA  A0 22
  jsr _func_c71d                 ; $C1DC  20 1D C7
  lda a:SelectedGameMode                ; $C1DF  AD FE 05
  asl a                          ; $C1E2  0A
  asl a                          ; $C1E3  0A
  clc                            ; $C1E4  18
  adc #$03                       ; $C1E5  69 03
  tax                            ; $C1E7  AA
  ldy #$05                       ; $C1E8  A0 05

_label_c1ea:
  lda a:_var_05f0_indexed,X      ; $C1EA  BD F0 05
  and #$0F                       ; $C1ED  29 0F
  sta a:_var_0501_indexed,Y      ; $C1EF  99 01 05
  dey                            ; $C1F2  88
  lda a:_var_05f0_indexed,X      ; $C1F3  BD F0 05
  lsr a                          ; $C1F6  4A
  lsr a                          ; $C1F7  4A
  lsr a                          ; $C1F8  4A
  lsr a                          ; $C1F9  4A
  sta a:_var_0501_indexed,Y      ; $C1FA  99 01 05
  dex                            ; $C1FD  CA
  dey                            ; $C1FE  88
  bpl _label_c1ea                ; $C1FF  10 E9
  lda a:_var_0501_indexed        ; $C201  AD 01 05
  bne _label_c20b                ; $C204  D0 05
  lda #$24                       ; $C206  A9 24
  sta a:_var_0501_indexed        ; $C208  8D 01 05

_label_c20b:
  lda #$16                       ; $C20B  A9 16
  sta a:_var_0500_indexed        ; $C20D  8D 00 05
  ldx #$12                       ; $C210  A2 12
  ldy #$23                       ; $C212  A0 23
  jsr _func_c71d                 ; $C214  20 1D C7

_label_c217:
  lda z:TitleScreenSongCountdown                ; $C217  A5 2D
  bne _label_c222                ; $C219  D0 07
  jsr _func_d509                 ; $C21B  20 09 D5
  lda #$FF                       ; $C21E  A9 FF
  sta z:TitleScreenSongCountdown                ; $C220  85 2D

_label_c222:
  lda z:_var_0026                ; $C222  A5 26
  jsr _jump_engine_c35e          ; $C224  20 5E C3

  .word _label_c5aa              ; $C227  AA C5
  .word _label_c5e0              ; $C229  E0 C5

_func_c22b:
  lda #$02                       ; $C22B  A9 02
  jsr _func_c232                 ; $C22D  20 32 C2

_func_c230:
  lda #$01                       ; $C230  A9 01

_func_c232:
  sta z:_var_0001                ; $C232  85 01
  lda #$24                       ; $C234  A9 24
  sta z:_var_0000_indexed        ; $C236  85 00
  jmp _func_c303                 ; $C238  4C 03 C3

_func_c23b:
  ldy #$00                       ; $C23B  A0 00
  lda #$F4                       ; $C23D  A9 F4

_label_c23f:
  sta a:_var_0200_indexed,Y      ; $C23F  99 00 02
  iny                            ; $C242  C8
  iny                            ; $C243  C8
  iny                            ; $C244  C8
  iny                            ; $C245  C8
  bne _label_c23f                ; $C246  D0 F7
  rts                            ; $C248  60

_func_c249:
  ldy z:_var_0023                ; $C249  A4 23
  beq _label_c262                ; $C24B  F0 15
  dey                            ; $C24D  88
  tya                            ; $C24E  98
  asl a                          ; $C24F  0A
  tay                            ; $C250  A8
  lda a:_data_e532_indexed,Y     ; $C251  B9 32 E5
  ldx a:PaletteTable,Y     ; $C254  BE 33 E5
  ldy #$00                       ; $C257  A0 00
  sty z:_var_0023                ; $C259  84 23

_label_c25b:
  sta z:_var_0000_indexed        ; $C25B  85 00
  stx z:_var_0001                ; $C25D  86 01
  jsr _func_c3b8                 ; $C25F  20 B8 C3

_label_c262:
  rts                            ; $C262  60

_func_c263:
  ldy z:WhiteBoxVisible                ; $C263  A4 27
  beq _label_c262                ; $C265  F0 FB
  ldy #$00                       ; $C267  A0 00
  sty z:WhiteBoxVisible                ; $C269  84 27
  lda #$00                       ; $C26B  A9 00
  ldx #$04                       ; $C26D  A2 04
  bne _label_c25b                ; $C26F  D0 EA

_label_c271:
  dec z:_var_001c_indexed        ; $C271  C6 1C
  bne _label_c283                ; $C273  D0 0E
  ldx #$05                       ; $C275  A2 05

_label_c277:
  lda a:_var_0430_indexed,X      ; $C277  BD 30 04
  sta z:_var_002a_indexed,X      ; $C27A  95 2A
  dex                            ; $C27C  CA
  bpl _label_c277                ; $C27D  10 F8
  lda z:_var_001d                ; $C27F  A5 1D
  sta z:_var_0025                ; $C281  85 25

_label_c283:
  rts                            ; $C283  60

_func_c284:
  ldx #$01                       ; $C284  A2 01
  stx JOYPAD1                    ; $C286  8E 16 40
  dex                            ; $C289  CA
  stx JOYPAD1                    ; $C28A  8E 16 40
  jsr _func_c291                 ; $C28D  20 91 C2
  inx                            ; $C290  E8

_func_c291:
  ldy #$08                       ; $C291  A0 08

_label_c293:
  pha                            ; $C293  48
  lda JOYPAD1,X                  ; $C294  BD 16 40
  sta z:_var_0000_indexed        ; $C297  85 00
  lsr a                          ; $C299  4A
  ora z:_var_0000_indexed        ; $C29A  05 00
  lsr a                          ; $C29C  4A
  pla                            ; $C29D  68
  rol a                          ; $C29E  2A
  dey                            ; $C29F  88
  bne _label_c293                ; $C2A0  D0 F1
  cmp a:_var_0440_indexed,X      ; $C2A2  DD 40 04
  bne _label_c2b6                ; $C2A5  D0 0F
  inc a:_var_0442_indexed,X      ; $C2A7  FE 42 04
  ldy a:_var_0442_indexed,X      ; $C2AA  BC 42 04
  cpy #$05                       ; $C2AD  C0 05
  bcc _label_c2be                ; $C2AF  90 0D
  sta z:JOYPAD1MIRROR,X      ; $C2B1  95 16
  jmp _label_c2b9                ; $C2B3  4C B9 C2

_label_c2b6:
  sta a:_var_0440_indexed,X      ; $C2B6  9D 40 04

_label_c2b9:
  lda #$00                       ; $C2B9  A9 00
  sta a:_var_0442_indexed,X      ; $C2BB  9D 42 04

_label_c2be:
  rts                            ; $C2BE  60

_func_c2bf:
  lda z:_var_0021                ; $C2BF  A5 21
  beq _label_c302                ; $C2C1  F0 3F
  lda #$61                       ; $C2C3  A9 61
  sta z:_var_0000_indexed        ; $C2C5  85 00
  lda #$05                       ; $C2C7  A9 05
  sta z:_var_0001                ; $C2C9  85 01
  lda z:_var_0008                ; $C2CB  A5 08
  and #$FB                       ; $C2CD  29 FB
  sta PPU_CTRL                   ; $C2CF  8D 00 20
  sta z:_var_0008                ; $C2D2  85 08
  ldx PPU_STATUS                 ; $C2D4  AE 02 20
  ldy #$00                       ; $C2D7  A0 00
  beq _label_c2f4                ; $C2D9  F0 19

_label_c2db:
  sta PPU_ADDR                   ; $C2DB  8D 06 20
  iny                            ; $C2DE  C8
  lda (_var_0000_indexed),Y      ; $C2DF  B1 00
  sta PPU_ADDR                   ; $C2E1  8D 06 20
  iny                            ; $C2E4  C8
  lda (_var_0000_indexed),Y      ; $C2E5  B1 00
  and #$3F                       ; $C2E7  29 3F
  tax                            ; $C2E9  AA

_label_c2ea:
  iny                            ; $C2EA  C8
  lda (_var_0000_indexed),Y      ; $C2EB  B1 00
  sta PPU_DATA                   ; $C2ED  8D 07 20
  dex                            ; $C2F0  CA
  bne _label_c2ea                ; $C2F1  D0 F7
  iny                            ; $C2F3  C8

_label_c2f4:
  lda (_var_0000_indexed),Y      ; $C2F4  B1 00
  bne _label_c2db                ; $C2F6  D0 E3
  lda #$00                       ; $C2F8  A9 00
  sta a:_var_0560                ; $C2FA  8D 60 05
  sta a:_var_0561_indexed        ; $C2FD  8D 61 05
  sta z:_var_0021                ; $C300  85 21

_label_c302:
  rts                            ; $C302  60

_func_c303:
  lda PPU_STATUS                 ; $C303  AD 02 20

_data_c306_indexed:
  lda z:_var_0008                ; $C306  A5 08
  and #$FB                       ; $C308  29 FB
  sta PPU_CTRL                   ; $C30A  8D 00 20
  sta z:_var_0008                ; $C30D  85 08
  lda #$1C                       ; $C30F  A9 1C
  clc                            ; $C311  18

_label_c312:
  adc #$04                       ; $C312  69 04
  dec z:_var_0001                ; $C314  C6 01
  bne _label_c312                ; $C316  D0 FA
  sta z:_var_0002_indexed        ; $C318  85 02
  sta PPU_ADDR                   ; $C31A  8D 06 20
  lda #$00                       ; $C31D  A9 00
  sta PPU_ADDR                   ; $C31F  8D 06 20
  ldx #$04                       ; $C322  A2 04
  ldy #$00                       ; $C324  A0 00
  lda z:_var_0000_indexed        ; $C326  A5 00

_label_c328:
  sta PPU_DATA                   ; $C328  8D 07 20
  dey                            ; $C32B  88
  bne _label_c328                ; $C32C  D0 FA
  dex                            ; $C32E  CA
  bne _label_c328                ; $C32F  D0 F7
  lda z:_var_0002_indexed        ; $C331  A5 02
  adc #$03                       ; $C333  69 03
  sta PPU_ADDR                   ; $C335  8D 06 20
  lda #$C0                       ; $C338  A9 C0
  sta PPU_ADDR                   ; $C33A  8D 06 20
  ldy #$40                       ; $C33D  A0 40
  lda #$00                       ; $C33F  A9 00

_label_c341:
  sta PPU_DATA                   ; $C341  8D 07 20
  dey                            ; $C344  88
  bne _label_c341                ; $C345  D0 FA
  rts                            ; $C347  60

_func_c348:
  ldx #$01                       ; $C348  A2 01
  dec z:_var_002a_indexed        ; $C34A  C6 2A
  bpl _label_c354                ; $C34C  10 06
  lda #$0A                       ; $C34E  A9 0A
  sta z:_var_002a_indexed        ; $C350  85 2A
  ldx #$03                       ; $C352  A2 03

_label_c354:
  lda z:_var_002b_indexed,X      ; $C354  B5 2B
  beq _label_c35a                ; $C356  F0 02
  dec z:_var_002b_indexed,X      ; $C358  D6 2B

_label_c35a:
  dex                            ; $C35A  CA
  bpl _label_c354                ; $C35B  10 F7
  rts                            ; $C35D  60

_jump_engine_c35e:               ; jump engine detected
  stx z:_var_0028                ; $C35E  86 28
  sty z:_var_0029                ; $C360  84 29
  asl a                          ; $C362  0A
  tay                            ; $C363  A8
  iny                            ; $C364  C8
  pla                            ; $C365  68
  sta z:_var_0014_indexed        ; $C366  85 14
  pla                            ; $C368  68
  sta z:_var_0015                ; $C369  85 15
  lda (_var_0014_indexed),Y      ; $C36B  B1 14
  tax                            ; $C36D  AA
  iny                            ; $C36E  C8
  lda (_var_0014_indexed),Y      ; $C36F  B1 14
  sta z:_var_0015                ; $C371  85 15
  stx z:_var_0014_indexed        ; $C373  86 14
  ldx z:_var_0028                ; $C375  A6 28
  ldy z:_var_0029                ; $C377  A4 29
  jmp (_var_0014_indexed)        ; $C379  6C 14 00

_label_c37c:
  sta PPU_ADDR                   ; $C37C  8D 06 20
  iny                            ; $C37F  C8
  lda (_var_0000_indexed),Y      ; $C380  B1 00
  sta PPU_ADDR                   ; $C382  8D 06 20
  iny                            ; $C385  C8
  lda (_var_0000_indexed),Y      ; $C386  B1 00
  asl a                          ; $C388  0A
  pha                            ; $C389  48
  lda z:_var_0008                ; $C38A  A5 08
  ora #$04                       ; $C38C  09 04
  bcs _label_c392                ; $C38E  B0 02
  and #$FB                       ; $C390  29 FB

_label_c392:
  sta PPU_CTRL                   ; $C392  8D 00 20
  sta z:_var_0008                ; $C395  85 08
  pla                            ; $C397  68
  asl a                          ; $C398  0A
  bcc _label_c39e                ; $C399  90 03
  ora #$02                       ; $C39B  09 02
  iny                            ; $C39D  C8

_label_c39e:
  lsr a                          ; $C39E  4A
  lsr a                          ; $C39F  4A
  tax                            ; $C3A0  AA

_label_c3a1:
  bcs _label_c3a4                ; $C3A1  B0 01
  iny                            ; $C3A3  C8

_label_c3a4:
  lda (_var_0000_indexed),Y      ; $C3A4  B1 00
  sta PPU_DATA                   ; $C3A6  8D 07 20
  dex                            ; $C3A9  CA
  bne _label_c3a1                ; $C3AA  D0 F5
  sec                            ; $C3AC  38
  tya                            ; $C3AD  98
  adc z:_var_0000_indexed        ; $C3AE  65 00
  sta z:_var_0000_indexed        ; $C3B0  85 00
  lda #$00                       ; $C3B2  A9 00
  adc z:_var_0001                ; $C3B4  65 01
  sta z:_var_0001                ; $C3B6  85 01

_func_c3b8:
  ldx PPU_STATUS                 ; $C3B8  AE 02 20
  ldy #$00                       ; $C3BB  A0 00
  lda (_var_0000_indexed),Y      ; $C3BD  B1 00
  bne _label_c37c                ; $C3BF  D0 BB

_func_c3c1:
  pha                            ; $C3C1  48
  lda z:_var_000a                ; $C3C2  A5 0A
  sta PPU_SCROLL                 ; $C3C4  8D 05 20
  lda z:$0B                      ; $C3C7  A5 0B
  sta PPU_SCROLL                 ; $C3C9  8D 05 20
  pla                            ; $C3CC  68
  rts                            ; $C3CD  60

_label_c3ce:
  lda #$01                       ; $C3CE  A9 01
  sta z:_var_0021                ; $C3D0  85 21
  ldy #$00                       ; $C3D2  A0 00
  lda (_var_0002_indexed),Y      ; $C3D4  B1 02
  and #$0F                       ; $C3D6  29 0F
  sta z:Submode                ; $C3D8  85 05
  lda (_var_0002_indexed),Y      ; $C3DA  B1 02
  lsr a                          ; $C3DC  4A
  lsr a                          ; $C3DD  4A
  lsr a                          ; $C3DE  4A
  lsr a                          ; $C3DF  4A
  sta z:_var_0004                ; $C3E0  85 04
  ldx a:_var_0560                ; $C3E2  AE 60 05

_label_c3e5:
  lda z:_var_0001                ; $C3E5  A5 01
  sta a:_var_0561_indexed,X      ; $C3E7  9D 61 05
  jsr _func_c426                 ; $C3EA  20 26 C4
  lda z:_var_0000_indexed        ; $C3ED  A5 00
  sta a:_var_0561_indexed,X      ; $C3EF  9D 61 05
  jsr _func_c426                 ; $C3F2  20 26 C4
  lda z:Submode                ; $C3F5  A5 05
  sta z:_var_0006                ; $C3F7  85 06
  sta a:_var_0561_indexed,X      ; $C3F9  9D 61 05

_label_c3fc:
  jsr _func_c426                 ; $C3FC  20 26 C4
  iny                            ; $C3FF  C8
  lda (_var_0002_indexed),Y      ; $C400  B1 02
  sta a:_var_0561_indexed,X      ; $C402  9D 61 05
  dec z:_var_0006                ; $C405  C6 06
  bne _label_c3fc                ; $C407  D0 F3
  jsr _func_c426                 ; $C409  20 26 C4
  stx a:_var_0560                ; $C40C  8E 60 05
  clc                            ; $C40F  18
  lda #$20                       ; $C410  A9 20
  adc z:_var_0000_indexed        ; $C412  65 00
  sta z:_var_0000_indexed        ; $C414  85 00
  lda #$00                       ; $C416  A9 00
  adc z:_var_0001                ; $C418  65 01
  sta z:_var_0001                ; $C41A  85 01
  dec z:_var_0004                ; $C41C  C6 04
  bne _label_c3e5                ; $C41E  D0 C5
  lda #$00                       ; $C420  A9 00
  sta a:_var_0561_indexed,X      ; $C422  9D 61 05
  rts                            ; $C425  60

_func_c426:
  inx                            ; $C426  E8
  txa                            ; $C427  8A
  cmp #$4F                       ; $C428  C9 4F
  bcc _label_c436                ; $C42A  90 0A
  ldx a:_var_0560                ; $C42C  AE 60 05
  lda #$00                       ; $C42F  A9 00
  sta a:_var_0561_indexed,X      ; $C431  9D 61 05
  pla                            ; $C434  68
  pla                            ; $C435  68

_label_c436:
  rts                            ; $C436  60

_func_c437:
  clc                            ; $C437  18
  adc #$01                       ; $C438  69 01
  and #$0F                       ; $C43A  29 0F
  asl a                          ; $C43C  0A
  asl a                          ; $C43D  0A
  tax                            ; $C43E  AA
  lda z:_var_0004                ; $C43F  A5 04
  beq _label_c46a                ; $C441  F0 27
  lda z:_var_00c3_indexed,X      ; $C443  B5 C3
  beq _label_c46e                ; $C445  F0 27

_label_c447:
  clc                            ; $C447  18
  lda z:ScoreC,X      ; $C448  B5 C6
  sta z:_var_0003                ; $C44A  85 03
  lda z:_var_0007                ; $C44C  A5 07
  jsr _func_c4bf                 ; $C44E  20 BF C4
  sta z:ScoreC,X      ; $C451  95 C6
  lda z:ScoreB,X      ; $C453  B5 C5
  sta z:_var_0003                ; $C455  85 03
  lda z:_var_0006                ; $C457  A5 06
  jsr _func_c4bf                 ; $C459  20 BF C4
  sta z:ScoreB,X      ; $C45C  95 C5
  lda z:ScoreA,X      ; $C45E  B5 C4
  sta z:_var_0003                ; $C460  85 03
  lda z:Submode                ; $C462  A5 05
  jsr _func_c4bf                 ; $C464  20 BF C4
  sta z:ScoreA,X      ; $C467  95 C4
  rts                            ; $C469  60

_label_c46a:
  lda z:_var_00c3_indexed,X      ; $C46A  B5 C3
  beq _label_c447                ; $C46C  F0 D9

_label_c46e:
  sec                            ; $C46E  38
  lda z:ScoreC,X      ; $C46F  B5 C6
  sta z:_var_0003                ; $C471  85 03
  lda z:_var_0007                ; $C473  A5 07
  jsr _func_c4e0                 ; $C475  20 E0 C4
  sta z:ScoreC,X      ; $C478  95 C6
  lda z:ScoreB,X      ; $C47A  B5 C5
  sta z:_var_0003                ; $C47C  85 03
  lda z:_var_0006                ; $C47E  A5 06
  jsr _func_c4e0                 ; $C480  20 E0 C4
  sta z:ScoreB,X      ; $C483  95 C5
  lda z:ScoreA,X      ; $C485  B5 C4
  sta z:_var_0003                ; $C487  85 03
  lda z:Submode                ; $C489  A5 05
  jsr _func_c4e0                 ; $C48B  20 E0 C4
  sta z:ScoreA,X      ; $C48E  95 C4
  lda z:ScoreA,X      ; $C490  B5 C4
  bne _label_c49c                ; $C492  D0 08
  lda z:ScoreB,X      ; $C494  B5 C5
  bne _label_c49c                ; $C496  D0 04
  lda z:ScoreC,X      ; $C498  B5 C6
  beq _label_c4a2                ; $C49A  F0 06

_label_c49c:
  bcs _label_c4be                ; $C49C  B0 20
  lda z:_var_00c3_indexed,X      ; $C49E  B5 C3
  eor #$FF                       ; $C4A0  49 FF

_label_c4a2:
  sta z:_var_00c3_indexed,X      ; $C4A2  95 C3
  sec                            ; $C4A4  38
  lda #$00                       ; $C4A5  A9 00
  sta z:_var_0003                ; $C4A7  85 03
  lda z:ScoreC,X      ; $C4A9  B5 C6
  jsr _func_c4e0                 ; $C4AB  20 E0 C4
  sta z:ScoreC,X      ; $C4AE  95 C6
  lda z:ScoreB,X      ; $C4B0  B5 C5
  jsr _func_c4e0                 ; $C4B2  20 E0 C4
  sta z:ScoreB,X      ; $C4B5  95 C5
  lda z:ScoreA,X      ; $C4B7  B5 C4
  jsr _func_c4e0                 ; $C4B9  20 E0 C4
  sta z:ScoreA,X      ; $C4BC  95 C4

_label_c4be:
  rts                            ; $C4BE  60

_func_c4bf:
  jsr _func_c502                 ; $C4BF  20 02 C5
  adc z:_var_0001                ; $C4C2  65 01
  cmp #$0A                       ; $C4C4  C9 0A
  bcc _label_c4ca                ; $C4C6  90 02
  adc #$05                       ; $C4C8  69 05

_label_c4ca:
  clc                            ; $C4CA  18
  adc z:_var_0002_indexed        ; $C4CB  65 02
  sta z:_var_0002_indexed        ; $C4CD  85 02
  lda z:_var_0003                ; $C4CF  A5 03
  and #$F0                       ; $C4D1  29 F0
  adc z:_var_0002_indexed        ; $C4D3  65 02
  bcc _label_c4db                ; $C4D5  90 04

_label_c4d7:
  adc #$5F                       ; $C4D7  69 5F
  sec                            ; $C4D9  38
  rts                            ; $C4DA  60

_label_c4db:
  cmp #$A0                       ; $C4DB  C9 A0
  bcs _label_c4d7                ; $C4DD  B0 F8
  rts                            ; $C4DF  60

_func_c4e0:
  jsr _func_c502                 ; $C4E0  20 02 C5
  sbc z:_var_0001                ; $C4E3  E5 01
  sta z:_var_0001                ; $C4E5  85 01
  bcs _label_c4f3                ; $C4E7  B0 0A
  adc #$0A                       ; $C4E9  69 0A
  sta z:_var_0001                ; $C4EB  85 01
  lda z:_var_0002_indexed        ; $C4ED  A5 02
  adc #$0F                       ; $C4EF  69 0F
  sta z:_var_0002_indexed        ; $C4F1  85 02

_label_c4f3:
  lda z:_var_0003                ; $C4F3  A5 03
  and #$F0                       ; $C4F5  29 F0
  sec                            ; $C4F7  38
  sbc z:_var_0002_indexed        ; $C4F8  E5 02
  bcs _label_c4ff                ; $C4FA  B0 03
  adc #$A0                       ; $C4FC  69 A0
  clc                            ; $C4FE  18

_label_c4ff:
  ora z:_var_0001                ; $C4FF  05 01
  rts                            ; $C501  60

_func_c502:
  pha                            ; $C502  48
  and #$0F                       ; $C503  29 0F
  sta z:_var_0001                ; $C505  85 01
  pla                            ; $C507  68
  and #$F0                       ; $C508  29 F0
  sta z:_var_0002_indexed        ; $C50A  85 02
  lda z:_var_0003                ; $C50C  A5 03
  and #$0F                       ; $C50E  29 0F
  rts                            ; $C510  60

_func_c511:
  lda #$00                       ; $C511  A9 00
  sta z:_var_0004                ; $C513  85 04
  clc                            ; $C515  18
  lda z:_var_0000_indexed        ; $C516  A5 00
  adc #$10                       ; $C518  69 10
  and #$F0                       ; $C51A  29 F0
  lsr a                          ; $C51C  4A
  lsr a                          ; $C51D  4A
  tay                            ; $C51E  A8
  lda z:_var_0000_indexed        ; $C51F  A5 00
  and #$07                       ; $C521  29 07
  asl a                          ; $C523  0A
  asl a                          ; $C524  0A
  tax                            ; $C525  AA

_label_c526:
  lda a:_var_00c3_indexed,Y      ; $C526  B9 C3 00
  beq _label_c57c                ; $C529  F0 51
  lda z:_var_00c7_indexed,X      ; $C52B  B5 C7
  beq _label_c555                ; $C52D  F0 26

_label_c52f:
  sec                            ; $C52F  38
  lda a:ScoreC,Y      ; $C530  B9 C6 00
  sta z:_var_0003                ; $C533  85 03
  lda z:_var_00ca_indexed,X      ; $C535  B5 CA
  jsr _func_c4e0                 ; $C537  20 E0 C4
  lda a:ScoreB,Y      ; $C53A  B9 C5 00
  sta z:_var_0003                ; $C53D  85 03
  lda z:_var_00c9_indexed,X      ; $C53F  B5 C9
  jsr _func_c4e0                 ; $C541  20 E0 C4
  lda a:ScoreA,Y      ; $C544  B9 C4 00
  sta z:_var_0003                ; $C547  85 03
  lda z:_var_00c8_indexed,X      ; $C549  B5 C8
  jsr _func_c4e0                 ; $C54B  20 E0 C4
  bcs _label_c580                ; $C54E  B0 30
  lda a:_var_00c3_indexed,Y      ; $C550  B9 C3 00
  bne _label_c585                ; $C553  D0 30

_label_c555:
  lda #$FF                       ; $C555  A9 FF
  sta z:_var_0004                ; $C557  85 04
  sec                            ; $C559  38

_label_c55a:
  tya                            ; $C55A  98
  bne _label_c57b                ; $C55B  D0 1E
  bcc _label_c56f                ; $C55D  90 10
  lda z:_var_00c7_indexed,X      ; $C55F  B5 C7
  sta z:_var_00c3_indexed        ; $C561  85 C3
  lda z:_var_00c8_indexed,X      ; $C563  B5 C8
  sta z:ScoreA        ; $C565  85 C4
  lda z:_var_00c9_indexed,X      ; $C567  B5 C9
  sta z:ScoreB        ; $C569  85 C5
  lda z:_var_00ca_indexed,X      ; $C56B  B5 CA
  sta z:ScoreC        ; $C56D  85 C6

_label_c56f:
  lda z:_var_0000_indexed        ; $C56F  A5 00
  and #$08                       ; $C571  29 08
  beq _label_c57b                ; $C573  F0 06
  dex                            ; $C575  CA
  dex                            ; $C576  CA
  dex                            ; $C577  CA
  dex                            ; $C578  CA
  bpl _label_c526                ; $C579  10 AB

_label_c57b:
  rts                            ; $C57B  60

_label_c57c:
  lda z:_var_00c7_indexed,X      ; $C57C  B5 C7
  beq _label_c52f                ; $C57E  F0 AF

_label_c580:
  lda a:_var_00c3_indexed,Y      ; $C580  B9 C3 00
  bne _label_c555                ; $C583  D0 D0

_label_c585:
  clc                            ; $C585  18
  bcc _label_c55a                ; $C586  90 D2

_func_c588:
  lda a:RNGSeed1                ; $C588  AD EC 05
  and #$02                       ; $C58B  29 02
  sta z:_var_0007                ; $C58D  85 07
  lda a:RNGSeed2                ; $C58F  AD ED 05
  and #$02                       ; $C592  29 02
  eor z:_var_0007                ; $C594  45 07
  clc                            ; $C596  18
  beq _label_c59a                ; $C597  F0 01
  sec                            ; $C599  38

_label_c59a:
  ror a:RNGSeed1                ; $C59A  6E EC 05
  ror a:RNGSeed2                ; $C59D  6E ED 05
  ror a:RNGSeed3                ; $C5A0  6E EE 05
  ror a:RNGSeed4                ; $C5A3  6E EF 05
  lda a:RNGSeed1                ; $C5A6  AD EC 05
  rts                            ; $C5A9  60

_label_c5aa:
  jsr _func_c5e1                 ; $C5AA  20 E1 C5
  jsr _func_c230                 ; $C5AD  20 30 C2
  jsr _func_c5d9                 ; $C5B0  20 D9 C5
  lda #$02                       ; $C5B3  A9 02
  sta z:_var_0001                ; $C5B5  85 01
  lda #$50                       ; $C5B7  A9 50
  sta z:_var_0000_indexed        ; $C5B9  85 00
  jsr _func_c303                 ; $C5BB  20 03 C3
  jsr _func_c23b                 ; $C5BE  20 3B C2
  jsr _func_c5d9                 ; $C5C1  20 D9 C5
  ldx #$04                       ; $C5C4  A2 04
  ldy #$E4                       ; $C5C6  A0 E4
  jsr _func_c617                 ; $C5C8  20 17 C6
  lda #$01                       ; $C5CB  A9 01
  sta z:_var_0023                ; $C5CD  85 23
  lda #$01                       ; $C5CF  A9 01
  sta a:SelectButtonDown                ; $C5D1  8D FD 05
  inc z:_var_0026                ; $C5D4  E6 26
  jmp _func_c5ee                 ; $C5D6  4C EE C5

_func_c5d9:
  jsr _func_c61e                 ; $C5D9  20 1E C6

_label_c5dc:
  lda z:_var_0020                ; $C5DC  A5 20
  beq _label_c5dc                ; $C5DE  F0 FC

_label_c5e0:
  rts                            ; $C5E0  60

_func_c5e1:
  jsr _func_c5d9                 ; $C5E1  20 D9 C5
  lda z:_var_0009                ; $C5E4  A5 09
  and #$E7                       ; $C5E6  29 E7

_label_c5e8:
  sta z:_var_0009                ; $C5E8  85 09
  sta PPU_MASK                   ; $C5EA  8D 01 20
  rts                            ; $C5ED  60

_func_c5ee:
  jsr _func_c5d9                 ; $C5EE  20 D9 C5
  lda z:_var_0009                ; $C5F1  A5 09
  ora #$18                       ; $C5F3  09 18
  bne _label_c5e8                ; $C5F5  D0 F1

_func_c5f7:
  sty z:_var_00a2                ; $C5F7  84 A2
  ldx #$00                       ; $C5F9  A2 00

_label_c5fb:
  lda a:TargetOneType,Y      ; $C5FB  B9 00 03
  sta z:_var_0030_indexed,X      ; $C5FE  95 30
  iny                            ; $C600  C8
  inx                            ; $C601  E8
  cpx #$50                       ; $C602  E0 50
  bne _label_c5fb                ; $C604  D0 F5
  rts                            ; $C606  60

_func_c607:
  ldy z:_var_00a2                ; $C607  A4 A2
  ldx #$00                       ; $C609  A2 00

_label_c60b:
  lda z:_var_0030_indexed,X      ; $C60B  B5 30
  sta a:TargetOneType,Y      ; $C60D  99 00 03
  iny                            ; $C610  C8
  inx                            ; $C611  E8
  cpx #$50                       ; $C612  E0 50
  bne _label_c60b                ; $C614  D0 F5
  rts                            ; $C616  60

_func_c617:
  stx z:_var_0000_indexed        ; $C617  86 00
  sty z:_var_0001                ; $C619  84 01
  jmp _func_c3b8                 ; $C61B  4C B8 C3

_func_c61e:
  lda #$00                       ; $C61E  A9 00
  sta z:_var_0020                ; $C620  85 20
  sta z:_var_0022                ; $C622  85 22
  rts                            ; $C624  60

_label_c625:
  lda z:TitleScreenSongCountdown                ; $C625  A5 2D
  bne _label_c62d                ; $C627  D0 04
  lda z:_var_001e                ; $C629  A5 1E
  sta z:_var_0025                ; $C62B  85 25

_label_c62d:
  rts                            ; $C62D  60

_func_c62e:
  stx z:_var_001e                ; $C62E  86 1E
  sta z:TitleScreenSongCountdown                ; $C630  85 2D
  lda #$12                       ; $C632  A9 12
  sta z:_var_0025                ; $C634  85 25
  rts                            ; $C636  60

_label_c637:
  ldy #$00                       ; $C637  A0 00
  tya                            ; $C639  98

_label_c63a:
  sta a:TargetOneType,Y      ; $C63A  99 00 03
  iny                            ; $C63D  C8
  bne _label_c63a                ; $C63E  D0 FA
  rts                            ; $C640  60

_func_c641:
  lda #$00                       ; $C641  A9 00
  ldx #$30                       ; $C643  A2 30

_label_c645:
  sta z:_var_0000_indexed,X      ; $C645  95 00
  inx                            ; $C647  E8
  bne _label_c645                ; $C648  D0 FB
  rts                            ; $C64A  60

_func_c64b:
  lda #$00                       ; $C64B  A9 00
  ldx #$7F                       ; $C64D  A2 7F

_label_c64f:
  sta z:_var_0040_indexed,X      ; $C64F  95 40
  dex                            ; $C651  CA
  bpl _label_c64f                ; $C652  10 FB
  rts                            ; $C654  60

_func_c655:
  ldx #$03                       ; $C655  A2 03
  ldy #$05                       ; $C657  A0 05

_label_c659:
  lda z:_var_00c3_indexed,X      ; $C659  B5 C3
  and #$0F                       ; $C65B  29 0F
  sta a:_var_0501_indexed,Y      ; $C65D  99 01 05
  dey                            ; $C660  88
  lda z:_var_00c3_indexed,X      ; $C661  B5 C3
  lsr a                          ; $C663  4A
  lsr a                          ; $C664  4A
  lsr a                          ; $C665  4A
  lsr a                          ; $C666  4A
  sta a:_var_0501_indexed,Y      ; $C667  99 01 05
  dex                            ; $C66A  CA
  dey                            ; $C66B  88
  bpl _label_c659                ; $C66C  10 EB
  lda #$16                       ; $C66E  A9 16
  sta a:_var_0500_indexed        ; $C670  8D 00 05
  ldx a:_data_e5dc               ; $C673  AE DC E5
  ldy a:_data_e5db               ; $C676  AC DB E5
  jmp _func_c71d                 ; $C679  4C 1D C7

_label_c67c:
  lda z:_var_000c                ; $C67C  A5 0C
  asl a                          ; $C67E  0A
  tay                            ; $C67F  A8
  lda a:_data_eb30_indexed,Y     ; $C680  B9 30 EB
  sta z:_var_0010_indexed        ; $C683  85 10
  lda a:_data_eb31_indexed,Y     ; $C685  B9 31 EB
  sta z:_var_0011                ; $C688  85 11
  ldy #$00                       ; $C68A  A0 00
  ldx #$00                       ; $C68C  A2 00

_label_c68e:
  lda (_var_0010_indexed),Y      ; $C68E  B1 10
  cmp #$AA                       ; $C690  C9 AA
  bne _label_c695                ; $C692  D0 01

_label_c694:
  rts                            ; $C694  60

_label_c695:
  clc                            ; $C695  18
  adc z:_var_00b1                ; $C696  65 B1
  cmp #$A8                       ; $C698  C9 A8
  bcc _label_c69e                ; $C69A  90 02
  lda #$F4                       ; $C69C  A9 F4

_label_c69e:
  sta z:_var_000d                ; $C69E  85 0D
  iny                            ; $C6A0  C8
  lda (_var_0010_indexed),Y      ; $C6A1  B1 10
  clc                            ; $C6A3  18
  adc z:_var_00b2                ; $C6A4  65 B2
  sta z:_var_000e                ; $C6A6  85 0E
  iny                            ; $C6A8  C8
  lda z:_var_000d                ; $C6A9  A5 0D
  sta a:_var_0200_indexed,X      ; $C6AB  9D 00 02
  inx                            ; $C6AE  E8
  lda #$56                       ; $C6AF  A9 56
  sta a:_var_0200_indexed,X      ; $C6B1  9D 00 02
  inx                            ; $C6B4  E8
  lda #$00                       ; $C6B5  A9 00
  sta a:_var_0200_indexed,X      ; $C6B7  9D 00 02
  inx                            ; $C6BA  E8
  lda z:_var_000e                ; $C6BB  A5 0E
  sta a:_var_0200_indexed,X      ; $C6BD  9D 00 02
  inx                            ; $C6C0  E8
  jmp _label_c68e                ; $C6C1  4C 8E C6

_func_c6c4:
  lda z:_var_00ad                ; $C6C4  A5 AD
  beq _label_c694                ; $C6C6  F0 CC
  lda #$00                       ; $C6C8  A9 00
  sta z:_var_00ad                ; $C6CA  85 AD

_func_c6cc:
  lda #$D6                       ; $C6CC  A9 D6
  ldy z:_var_001f                ; $C6CE  A4 1F
  cpy #$02                       ; $C6D0  C0 02
  bne _label_c6d6                ; $C6D2  D0 02
  lda #$D4                       ; $C6D4  A9 D4

_label_c6d6:
  sta z:_var_000c                ; $C6D6  85 0C
  ldx #$09                       ; $C6D8  A2 09

_label_c6da:
  ldy z:_var_000c                ; $C6DA  A4 0C
  lda a:_var_03f0_indexed,X      ; $C6DC  BD F0 03
  beq _label_c6e2                ; $C6DF  F0 01
  dey                            ; $C6E1  88

_label_c6e2:
  tya                            ; $C6E2  98
  sta a:_var_0501_indexed,X      ; $C6E3  9D 01 05
  dex                            ; $C6E6  CA
  bpl _label_c6da                ; $C6E7  10 F1

_label_c6e9:
  lda #$1A                       ; $C6E9  A9 1A
  sta a:_var_0500_indexed        ; $C6EB  8D 00 05
  ldx #$4C                       ; $C6EE  A2 4C
  ldy #$23                       ; $C6F0  A0 23
  jmp _func_c71d                 ; $C6F2  4C 1D C7

_func_c6f5:
  lda z:NextLevelCountdown                ; $C6F5  A5 BE
  beq _label_c694                ; $C6F7  F0 9B
  lda #$00                       ; $C6F9  A9 00
  sta z:NextLevelCountdown                ; $C6FB  85 BE
  ldx z:RemainingShots                ; $C6FD  A6 BA
  ldy #$00                       ; $C6FF  A0 00

_label_c701:
  cpx #$00                       ; $C701  E0 00
  beq _label_c70a                ; $C703  F0 05
  dex                            ; $C705  CA
  lda #$D9                       ; $C706  A9 D9
  bne _label_c70c                ; $C708  D0 02

_label_c70a:
  lda #$B7                       ; $C70A  A9 B7

_label_c70c:
  sta a:_var_0501_indexed,Y      ; $C70C  99 01 05
  iny                            ; $C70F  C8
  cpy #$03                       ; $C710  C0 03
  bne _label_c701                ; $C712  D0 ED
  lda #$13                       ; $C714  A9 13
  sta a:_var_0500_indexed        ; $C716  8D 00 05
  ldx #$43                       ; $C719  A2 43
  ldy #$23                       ; $C71B  A0 23

_func_c71d:
  stx z:_var_0000_indexed        ; $C71D  86 00
  sty z:_var_0001                ; $C71F  84 01
  ldx #$00                       ; $C721  A2 00
  ldy #$05                       ; $C723  A0 05
  stx z:_var_0002_indexed        ; $C725  86 02
  sty z:_var_0003                ; $C727  84 03
  jmp _label_c3ce                ; $C729  4C CE C3

_label_c72c:
  lda z:TitleScreenSongCountdown                ; $C72C  A5 2D
  beq _label_c73a                ; $C72E  F0 0A
  lda z:_var_001f                ; $C730  A5 1F
  cmp #$02                       ; $C732  C9 02
  beq _label_c739                ; $C734  F0 03
  jmp _func_cc94                 ; $C736  4C 94 CC

_label_c739:
  rts                            ; $C739  60

_label_c73a:
  ldx #$03                       ; $C73A  A2 03

_label_c73c:
  lda z:_var_00c3_indexed,X      ; $C73C  B5 C3
  sta z:_var_00c7_indexed,X      ; $C73E  95 C7
  dex                            ; $C740  CA
  bpl _label_c73c                ; $C741  10 F9
  lda z:_var_001f                ; $C743  A5 1F
  asl a                          ; $C745  0A
  asl a                          ; $C746  0A
  tay                            ; $C747  A8
  sty z:_var_000f                ; $C748  84 0F
  ldx #$00                       ; $C74A  A2 00

_label_c74c:
  lda a:_var_05f0_indexed,Y      ; $C74C  B9 F0 05
  sta z:_var_00c3_indexed,X      ; $C74F  95 C3
  iny                            ; $C751  C8
  inx                            ; $C752  E8
  cpx #$04                       ; $C753  E0 04
  bne _label_c74c                ; $C755  D0 F5
  lda #$F0                       ; $C757  A9 F0
  sta z:_var_0000_indexed        ; $C759  85 00
  jsr _func_c511                 ; $C75B  20 11 C5
  ldy z:_var_000f                ; $C75E  A4 0F
  ldx #$00                       ; $C760  A2 00

_label_c762:
  lda z:_var_00c3_indexed,X      ; $C762  B5 C3
  sta a:_var_05f0_indexed,Y      ; $C764  99 F0 05
  iny                            ; $C767  C8
  inx                            ; $C768  E8
  cpx #$04                       ; $C769  E0 04
  bne _label_c762                ; $C76B  D0 F5
  ldy #$00                       ; $C76D  A0 00
  sty z:_var_00b5                ; $C76F  84 B5
  sty z:_var_0026                ; $C771  84 26
  iny                            ; $C773  C8
  sty z:MainMenuActive                ; $C774  84 24
  jmp _func_c5e1                 ; $C776  4C E1 C5

_label_c779:
  jsr _func_d50d                 ; $C779  20 0D D5
  jsr _func_c5d9                 ; $C77C  20 D9 C5
  jsr _func_d4fa                 ; $C77F  20 FA D4
  lda #$01                       ; $C782  A9 01
  sta a:_var_03a0                ; $C784  8D A0 03
  sta a:_var_03a1                ; $C787  8D A1 03
  lda #$07                       ; $C78A  A9 07
  sta z:_var_0025                ; $C78C  85 25
  lda #$15                       ; $C78E  A9 15
  sta z:TitleScreenSongCountdown                ; $C790  85 2D
  rts                            ; $C792  60

_func_c793:
  ldx #$0A                       ; $C793  A2 0A

_label_c795:
  cpx z:MinimumNumShotTargets                ; $C795  E4 AB
  bcc _label_c79f                ; $C797  90 06
  beq _label_c79f                ; $C799  F0 04
  lda #$B7                       ; $C79B  A9 B7
  bne _label_c7a1                ; $C79D  D0 02

_label_c79f:
  lda #$D7                       ; $C79F  A9 D7

_label_c7a1:
  sta a:_var_0500_indexed,X      ; $C7A1  9D 00 05
  dex                            ; $C7A4  CA
  bne _label_c795                ; $C7A5  D0 EE
  lda #$1A                       ; $C7A7  A9 1A
  sta a:_var_0500_indexed        ; $C7A9  8D 00 05
  ldx #$6C                       ; $C7AC  A2 6C
  ldy #$23                       ; $C7AE  A0 23
  jmp _func_c71d                 ; $C7B0  4C 1D C7

_func_c7b3:
  lda z:LevelNumber                ; $C7B3  A5 C1
  sta z:_var_0003                ; $C7B5  85 03
  lda #$01                       ; $C7B7  A9 01
  clc                            ; $C7B9  18
  jsr _func_c4bf                 ; $C7BA  20 BF C4
  sta z:LevelNumber                ; $C7BD  85 C1
  lda #$12                       ; $C7BF  A9 12
  sta a:_var_0500_indexed        ; $C7C1  8D 00 05
  ldx #$DD                       ; $C7C4  A2 DD
  lda z:_var_001f                ; $C7C6  A5 1F
  cmp #$02                       ; $C7C8  C9 02
  beq _label_c7ce                ; $C7CA  F0 02
  ldx #$50                       ; $C7CC  A2 50

_label_c7ce:
  stx a:_var_0502                ; $C7CE  8E 02 05
  ldx #$00                       ; $C7D1  A2 00
  lda z:LevelNumber                ; $C7D3  A5 C1
  and #$F0                       ; $C7D5  29 F0
  beq _label_c7e1                ; $C7D7  F0 08
  lsr a                          ; $C7D9  4A
  lsr a                          ; $C7DA  4A
  lsr a                          ; $C7DB  4A
  lsr a                          ; $C7DC  4A
  sta a:_var_0501_indexed,X      ; $C7DD  9D 01 05
  inx                            ; $C7E0  E8

_label_c7e1:
  lda z:LevelNumber                ; $C7E1  A5 C1
  and #$0F                       ; $C7E3  29 0F
  sta a:_var_0501_indexed,X      ; $C7E5  9D 01 05
  ldx #$05                       ; $C7E8  A2 05
  ldy #$23                       ; $C7EA  A0 23
  jmp _func_c71d                 ; $C7EC  4C 1D C7

_label_c7ef:
  lda z:_var_009d                ; $C7EF  A5 9D
  beq _label_c7f6                ; $C7F1  F0 03
  jmp _func_c7fb                 ; $C7F3  4C FB C7

_label_c7f6:
  lda #$0A                       ; $C7F6  A9 0A
  sta z:_var_0025                ; $C7F8  85 25
  rts                            ; $C7FA  60

_func_c7fb:
  lda z:_var_002b_indexed        ; $C7FB  A5 2B
  bne _label_c81c                ; $C7FD  D0 1D
  ldy z:_var_009d                ; $C7FF  A4 9D
  beq _label_c81c                ; $C801  F0 19
  lda a:_data_ec1f_indexed,Y     ; $C803  B9 1F EC
  cmp #$AA                       ; $C806  C9 AA
  beq _label_c818                ; $C808  F0 0E
  pha                            ; $C80A  48
  iny                            ; $C80B  C8
  lda a:_data_ec1f_indexed,Y     ; $C80C  B9 1F EC
  sta z:_var_002b_indexed        ; $C80F  85 2B
  iny                            ; $C811  C8
  sty z:_var_009d                ; $C812  84 9D
  pla                            ; $C814  68
  jmp _label_d46c                ; $C815  4C 6C D4

_label_c818:
  lda #$00                       ; $C818  A9 00
  sta z:_var_009d                ; $C81A  85 9D

_label_c81c:
  rts                            ; $C81C  60

_label_c81d:
  jsr _func_c641                 ; $C81D  20 41 C6
  jsr _func_c5d9                 ; $C820  20 D9 C5
  jsr _func_c22b                 ; $C823  20 2B C2
  jsr _func_d4d9                 ; $C826  20 D9 D4
  ldx #$01                       ; $C829  A2 01
  lda a:SelectedGameMode                ; $C82B  AD FE 05
  sta z:_var_001f                ; $C82E  85 1F
  cmp #$02                       ; $C830  C9 02
  bcc _label_c836                ; $C832  90 02
  ldx #$08                       ; $C834  A2 08

_label_c836:
  stx z:_var_0025                ; $C836  86 25
  rts                            ; $C838  60

_label_c839:
  jsr _func_c5d9                 ; $C839  20 D9 C5
  ldx #$42                       ; $C83C  A2 42
  ldy #$E0                       ; $C83E  A0 E0
  jsr _func_c617                 ; $C840  20 17 C6
  lda #$02                       ; $C843  A9 02
  sta z:_var_0023                ; $C845  85 23
  lda #$02                       ; $C847  A9 02
  sta z:_var_0025                ; $C849  85 25
  jsr _func_c3c1                 ; $C84B  20 C1 C3
  jsr _func_c5ee                 ; $C84E  20 EE C5
  jmp _label_d515                ; $C851  4C 15 D5

_label_c854:
  jsr _func_d4d9                 ; $C854  20 D9 D4
  jsr _func_d2a4                 ; $C857  20 A4 D2
  jsr _func_c793                 ; $C85A  20 93 C7
  jsr _func_c7b3                 ; $C85D  20 B3 C7
  nop                            ; $C860  EA
  nop                            ; $C861  EA
  nop                            ; $C862  EA
  lda #$00                       ; $C863  A9 00
  sta z:_var_00b5                ; $C865  85 B5
  sta z:_var_009d                ; $C867  85 9D
  lda #$03                       ; $C869  A9 03
  sta z:_var_0025                ; $C86B  85 25
  rts                            ; $C86D  60

_label_c86e:
  jsr _func_d131                 ; $C86E  20 31 D1
  jsr _func_d160                 ; $C871  20 60 D1
  jsr _func_cc94                 ; $C874  20 94 CC
  jsr _func_c890                 ; $C877  20 90 C8
  jsr _func_c6f5                 ; $C87A  20 F5 C6
  jsr _func_d3d2                 ; $C87D  20 D2 D3
  jsr _func_c6c4                 ; $C880  20 C4 C6
  jsr _func_cfba                 ; $C883  20 BA CF
  jsr _func_d428                 ; $C886  20 28 D4
  jsr _func_c7fb                 ; $C889  20 FB C7
  nop                            ; $C88C  EA
  nop                            ; $C88D  EA
  nop                            ; $C88E  EA
  rts                            ; $C88F  60

_func_c890:
  lda a:TargetOneType        ; $C890  AD 00 03
  beq _label_c8a2                ; $C893  F0 0D
  ldy #$00                       ; $C895  A0 00
  sty z:_var_00a1                ; $C897  84 A1
  jsr _func_c5f7                 ; $C899  20 F7 C5
  jsr _func_c902                 ; $C89C  20 02 C9
  jsr _func_c607                 ; $C89F  20 07 C6

_label_c8a2:
  lda a:_var_0350                ; $C8A2  AD 50 03
  beq _label_c8b4                ; $C8A5  F0 0D
  ldy #$50                       ; $C8A7  A0 50
  inc z:_var_00a1                ; $C8A9  E6 A1
  jsr _func_c5f7                 ; $C8AB  20 F7 C5
  jsr _func_c902                 ; $C8AE  20 02 C9
  jsr _func_c607                 ; $C8B1  20 07 C6

_label_c8b4:
  lda z:TargetActive                ; $C8B4  A5 B9
  beq _label_c901                ; $C8B6  F0 49
  ldy z:TargetDeactivationCountdown                ; $C8B8  A4 9F
  bne _label_c8c4                ; $C8BA  D0 08
  ldy #$41                       ; $C8BC  A0 41
  lda z:RemainingShots                ; $C8BE  A5 BA
  bne _label_c8c4                ; $C8C0  D0 02
  ldy #$15                       ; $C8C2  A0 15

_label_c8c4:
  dey                            ; $C8C4  88
  sty z:TargetDeactivationCountdown                ; $C8C5  84 9F
  lda z:TargetFinishedFalling                ; $C8C7  A5 BC
  bne _label_c8fb                ; $C8C9  D0 30
  lda a:TargetOneState        ; $C8CB  AD 01 03
  bne _label_c901                ; $C8CE  D0 31
  lda a:_var_0351                ; $C8D0  AD 51 03
  bne _label_c901                ; $C8D3  D0 2C
  lda z:_var_002b_indexed        ; $C8D5  A5 2B
  bne _label_c901                ; $C8D7  D0 28
  lda #$0A                       ; $C8D9  A9 0A
  ldy #$07                       ; $C8DB  A0 07
  ldx z:TargetShot                ; $C8DD  A6 BD
  beq _label_c8e5                ; $C8DF  F0 04
  lda #$0C                       ; $C8E1  A9 0C
  ldy #$02                       ; $C8E3  A0 02

_label_c8e5:
  sta a:_var_03a1                ; $C8E5  8D A1 03
  sty z:_var_0023                ; $C8E8  84 23
  jsr _func_c5d9                 ; $C8EA  20 D9 C5
  jsr _func_d446                 ; $C8ED  20 46 D4
  lda #$40                       ; $C8F0  A9 40
  sta z:_var_002b_indexed        ; $C8F2  85 2B
  lda #$00                       ; $C8F4  A9 00
  sta z:TargetActive                ; $C8F6  85 B9
  jmp _func_d464                 ; $C8F8  4C 64 D4

_label_c8fb:
  lda z:_var_00a6                ; $C8FB  A5 A6
  beq _label_c901                ; $C8FD  F0 02
  dec z:_var_00a6                ; $C8FF  C6 A6

_label_c901:
  rts                            ; $C901  60

_func_c902:
  lda z:CurrentSpritePhase                ; $C902  A5 31
  jsr _jump_engine_c35e          ; $C904  20 5E C3

  .word _label_c5e0              ; $C907  E0 C5
  .word _label_c919              ; $C909  19 C9
  .word _label_c932              ; $C90B  32 C9
  .word _label_ca19              ; $C90D  19 CA
  .word _label_cc1f              ; $C90F  1F CC
  .word _label_cc3d              ; $C911  3D CC
  .word _label_cc4f              ; $C913  4F CC
  .word _label_cc7c              ; $C915  7C CC
  .word _label_cc8b              ; $C917  8B CC

_label_c919:
  ldx #$1F                       ; $C919  A2 1F

_label_c91b:
  lda a:_data_e5eb_indexed,X     ; $C91B  BD EB E5
  sta z:_var_0030_indexed,X      ; $C91E  95 30
  dex                            ; $C920  CA
  bpl _label_c91b                ; $C921  10 F8
  lda z:_var_00a1                ; $C923  A5 A1
  beq IncrementSpritePhase                ; $C925  F0 08
  lda #$40                       ; $C927  A9 40
  sta z:_var_0036                ; $C929  85 36
  lda #$7F                       ; $C92B  A9 7F
  sta z:_var_0037                ; $C92D  85 37

; Literally redundant, used once, this function isn't even necessary.
IncrementSpritePhase:
  inc z:CurrentSpritePhase                ; $C92F  E6 31 - Increase the current sprite phase

_label_c931:
  rts                            ; $C931  60

_label_c932:
  lda z:TargetActive                ; $C932  A5 B9
  beq _label_c931                ; $C934  F0 FB
  lda z:_var_00a6                ; $C936  A5 A6
  bne _label_c931                ; $C938  D0 F7
  jsr _func_c588                 ; $C93A  20 88 C5
  and #$0F                       ; $C93D  29 0F
  ldy z:_var_001f                ; $C93F  A4 1F
  bne _label_c946                ; $C941  D0 03
  clc                            ; $C943  18
  adc #$10                       ; $C944  69 10

_label_c946:
  cmp z:_var_009c                ; $C946  C5 9C
  bne _label_c958                ; $C948  D0 0E
  clc                            ; $C94A  18
  adc #$01                       ; $C94B  69 01
  cmp #$10                       ; $C94D  C9 10
  beq _label_c955                ; $C94F  F0 04
  cmp #$20                       ; $C951  C9 20
  bne _label_c958                ; $C953  D0 03

_label_c955:
  sec                            ; $C955  38
  sbc #$10                       ; $C956  E9 10

_label_c958:
  sta z:_var_009c                ; $C958  85 9C
  asl a                          ; $C95A  0A
  tax                            ; $C95B  AA
  lda a:_data_e60b_indexed,X     ; $C95C  BD 0B E6
  sta z:_var_0044_indexed        ; $C95F  85 44
  lda a:_data_e60c_indexed,X     ; $C961  BD 0C E6
  sta z:_var_0045                ; $C964  85 45
  jsr _func_c588                 ; $C966  20 88 C5
  and #$3F                       ; $C969  29 3F
  tay                            ; $C96B  A8
  iny                            ; $C96C  C8
  sty z:_var_00a6                ; $C96D  84 A6
  ldy #$00                       ; $C96F  A0 00
  lda (_var_0044_indexed),Y      ; $C971  B1 44
  iny                            ; $C973  C8
  sty z:_var_0047                ; $C974  84 47
  sta z:_var_0033                ; $C976  85 33
  ldy #$00                       ; $C978  A0 00
  ldx z:_var_0099                ; $C97A  A6 99
  beq _label_c980                ; $C97C  F0 02
  ldy #$02                       ; $C97E  A0 02

_label_c980:
  sty z:DogColor                ; $C980  84 3C
  inc z:_var_0099                ; $C982  E6 99
  ldx z:_var_0098                ; $C984  A6 98
  lda a:_data_e766_indexed,X     ; $C986  BD 66 E7
  cpy #$00                       ; $C989  C0 00
  beq _label_c992                ; $C98B  F0 05
  and #$0F                       ; $C98D  29 0F
  jmp _label_c996                ; $C98F  4C 96 C9

_label_c992:
  lsr a                          ; $C992  4A
  lsr a                          ; $C993  4A
  lsr a                          ; $C994  4A
  lsr a                          ; $C995  4A

_label_c996:
  sta z:DuckColor                ; $C996  85 3F
  ldx z:LevelNumber                ; $C998  A6 C1
  lda z:_var_001f                ; $C99A  A5 1F
  bne _label_c9b9                ; $C99C  D0 1B
  lda #$0B                       ; $C99E  A9 0B
  cpx #$12                       ; $C9A0  E0 12
  bcs _label_c9b2                ; $C9A2  B0 0E
  lda #$0A                       ; $C9A4  A9 0A
  cpx #$11                       ; $C9A6  E0 11
  bcs _label_c9b2                ; $C9A8  B0 08
  lda #$09                       ; $C9AA  A9 09
  cpx #$10                       ; $C9AC  E0 10
  bcs _label_c9b2                ; $C9AE  B0 02
  dex                            ; $C9B0  CA
  txa                            ; $C9B1  8A

_label_c9b2:
  tax                            ; $C9B2  AA
  lda a:_data_e75a_indexed,X     ; $C9B3  BD 5A E7
  jmp _label_c9d0                ; $C9B6  4C D0 C9

_label_c9b9:
  lda #$1B                       ; $C9B9  A9 1B
  ldx z:LevelNumber                ; $C9BB  A6 C1
  cpx #$10                       ; $C9BD  E0 10
  bcs _label_c9c9                ; $C9BF  B0 08
  dex                            ; $C9C1  CA
  txa                            ; $C9C2  8A
  sta z:_var_000c                ; $C9C3  85 0C
  asl a                          ; $C9C5  0A
  clc                            ; $C9C6  18
  adc z:_var_000c                ; $C9C7  65 0C

_label_c9c9:
  clc                            ; $C9C9  18
  adc z:DuckColor                ; $C9CA  65 3F
  tax                            ; $C9CC  AA
  lda a:_data_e73c_indexed,X     ; $C9CD  BD 3C E7

_label_c9d0:
  sta z:_var_005e                ; $C9D0  85 5E
  ldx z:LevelNumber                ; $C9D2  A6 C1
  lda #$0B                       ; $C9D4  A9 0B
  cpx #$27                       ; $C9D6  E0 27
  bcs _label_c9e2                ; $C9D8  B0 08
  lda #$0A                       ; $C9DA  A9 0A
  cpx #$24                       ; $C9DC  E0 24
  bcs _label_c9e2                ; $C9DE  B0 02
  lda #$09                       ; $C9E0  A9 09

_label_c9e2:
  sta z:_var_003a                ; $C9E2  85 3A
  lda #$00                       ; $C9E4  A9 00
  sta z:_var_0046                ; $C9E6  85 46
  sta z:_var_0042_indexed        ; $C9E8  85 42
  sta z:TargetFlyingAway                ; $C9EA  85 4E
  sta z:$4F                      ; $C9EC  85 4F
  lda #$01                       ; $C9EE  A9 01
  sta z:_var_004b                ; $C9F0  85 4B
  sta z:_var_00ae                ; $C9F2  85 AE
  lda z:_var_001f                ; $C9F4  A5 1F
  bne _label_ca0e                ; $C9F6  D0 16
  ldx z:LevelNumber                ; $C9F8  A6 C1
  lda #$7D                       ; $C9FA  A9 7D
  cpx #$11                       ; $C9FC  E0 11
  bcc _label_ca08                ; $C9FE  90 08
  lda #$5D                       ; $CA00  A9 5D
  cpx #$20                       ; $CA02  E0 20
  bcc _label_ca08                ; $CA04  90 02
  lda #$3E                       ; $CA06  A9 3E

_label_ca08:
  sta z:_var_004c                ; $CA08  85 4C
  lda #$00                       ; $CA0A  A9 00
  sta z:_var_00af                ; $CA0C  85 AF

_label_ca0e:
  inc z:CurrentActiveDuckTarget                ; $CA0E  E6 BB - increment the current duck target
  lda z:CurrentActiveDuckTarget                ; $CA10  A5 BB - store that duck target
  sta z:DuckNumber                ; $CA12  85 3B - store that to the duck number
  dec z:TargetFinishedFalling                ; $CA14  C6 BC - mark that the target finished falling to the ground
  inc z:CurrentSpritePhase                ; $CA16  E6 31 - move up the current sprite phase (TODO: Figure out what it means in this context based on call trees, this can mean the duck has or hasn't finished falling)
  rts                            ; $CA18  60

_label_ca19:
  lda z:_var_002f                ; $CA19  A5 2F
  and #$07                       ; $CA1B  29 07
  bne _label_ca22                ; $CA1D  D0 03
  jsr _func_d4ee                 ; $CA1F  20 EE D4

_label_ca22:
  lda z:TargetDeactivationCountdown                ; $CA22  A5 9F
  bne _label_ca29                ; $CA24  D0 03
  jsr _func_d52c                 ; $CA26  20 2C D5

_label_ca29:
  lda z:RemainingShots                ; $CA29  A5 BA
  bne _label_ca3e                ; $CA2B  D0 11
  lda z:TargetFlyingAway                ; $CA2D  A5 4E
  bne _label_ca3e                ; $CA2F  D0 0D
  lda #$01                       ; $CA31  A9 01
  sta z:TargetFlyingAway                ; $CA33  85 4E
  lda #$F0                       ; $CA35  A9 F0
  sta z:_var_0046                ; $CA37  85 46
  lda #$00                       ; $CA39  A9 00
  jmp _label_cb77                ; $CA3B  4C 77 CB

_label_ca3e:
  lda z:_var_001f                ; $CA3E  A5 1F
  beq _label_ca45                ; $CA40  F0 03

_label_ca42:
  jmp _label_cb59                ; $CA42  4C 59 CB

_label_ca45:
  lda z:_var_004b                ; $CA45  A5 4B
  beq _label_ca53                ; $CA47  F0 0A
  lda z:_var_0032                ; $CA49  A5 32
  cmp #$88                       ; $CA4B  C9 88
  bcs _label_ca42                ; $CA4D  B0 F3
  lda #$00                       ; $CA4F  A9 00
  sta z:_var_004b                ; $CA51  85 4B

_label_ca53:
  ldx #$01                       ; $CA53  A2 01
  lda z:_var_004c                ; $CA55  A5 4C
  beq _label_ca70                ; $CA57  F0 17
  lda z:RemainingShots                ; $CA59  A5 BA
  bne _label_ca66                ; $CA5B  D0 09
  sta z:_var_004c                ; $CA5D  85 4C

_label_ca5f:
  jsr _func_cf96                 ; $CA5F  20 96 CF
  ldx #$01                       ; $CA62  A2 01
  bne _label_ca70                ; $CA64  D0 0A

_label_ca66:
  dex                            ; $CA66  CA
  lda z:_var_002f                ; $CA67  A5 2F
  lsr a                          ; $CA69  4A
  bcc _label_ca70                ; $CA6A  90 04
  dec z:_var_004c                ; $CA6C  C6 4C
  beq _label_ca5f                ; $CA6E  F0 EF

_label_ca70:
  stx z:_var_00ae                ; $CA70  86 AE
  cpx #$01                       ; $CA72  E0 01
  beq _label_ca8a                ; $CA74  F0 14
  lda z:JOYPAD1MIRROR        ; $CA76  A5 16
  and #$0F                       ; $CA78  29 0F
  bne _label_caa8                ; $CA7A  D0 2C
  lda z:$17                      ; $CA7C  A5 17
  and #$0F                       ; $CA7E  29 0F
  bne _label_caa8                ; $CA80  D0 26
  lda #$00                       ; $CA82  A9 00
  sta z:_var_00af                ; $CA84  85 AF
  lda z:_var_00ae                ; $CA86  A5 AE
  beq _label_ca8d                ; $CA88  F0 03

_label_ca8a:
  jmp _label_cf16                ; $CA8A  4C 16 CF

_label_ca8d:
  lda z:_var_0032                ; $CA8D  A5 32
  cmp #$20                       ; $CA8F  C9 20
  bcc _label_cad1                ; $CA91  90 3E
  cmp #$90                       ; $CA93  C9 90
  bcs _label_cad7                ; $CA95  B0 40
  ldx #$00                       ; $CA97  A2 00
  lda z:_var_0033                ; $CA99  A5 33
  cmp #$10                       ; $CA9B  C9 10
  bcc _label_cae3                ; $CA9D  90 44
  ldx #$08                       ; $CA9F  A2 08
  cmp #$F0                       ; $CAA1  C9 F0
  bcs _label_cae9                ; $CAA3  B0 44

_label_caa5:
  jmp _label_cbc3                ; $CAA5  4C C3 CB

_label_caa8:
  cmp z:_var_00af                ; $CAA8  C5 AF
  beq _label_ca8a                ; $CAAA  F0 DE
  sta z:_var_00af                ; $CAAC  85 AF
  ldx #$35                       ; $CAAE  A2 35
  lsr a                          ; $CAB0  4A
  bcs _label_cabf                ; $CAB1  B0 0C
  ldx #$DB                       ; $CAB3  A2 DB
  lsr a                          ; $CAB5  4A
  bcs _label_cabf                ; $CAB6  B0 07
  ldx #$79                       ; $CAB8  A2 79
  lsr a                          ; $CABA  4A
  bcs _label_cabf                ; $CABB  B0 02
  ldx #$1F                       ; $CABD  A2 1F

_label_cabf:
  lda z:_var_002f                ; $CABF  A5 2F
  lsr a                          ; $CAC1  4A
  txa                            ; $CAC2  8A
  bcc _label_caca                ; $CAC3  90 05
  and #$0F                       ; $CAC5  29 0F
  jmp _label_cb56                ; $CAC7  4C 56 CB

_label_caca:
  lsr a                          ; $CACA  4A
  lsr a                          ; $CACB  4A
  lsr a                          ; $CACC  4A
  lsr a                          ; $CACD  4A
  jmp _label_cb56                ; $CACE  4C 56 CB

_label_cad1:
  inc z:_var_0032                ; $CAD1  E6 32
  ldy #$00                       ; $CAD3  A0 00
  beq _label_cadb                ; $CAD5  F0 04

_label_cad7:
  dec z:_var_0032                ; $CAD7  C6 32
  ldy #$02                       ; $CAD9  A0 02

_label_cadb:
  lda z:_var_0048                ; $CADB  A5 48
  and #$08                       ; $CADD  29 08
  tax                            ; $CADF  AA
  jmp _label_caed                ; $CAE0  4C ED CA

_label_cae3:
  inc z:_var_0033                ; $CAE3  E6 33
  ldy #$04                       ; $CAE5  A0 04
  bne _label_caed                ; $CAE7  D0 04

_label_cae9:
  dec z:_var_0033                ; $CAE9  C6 33
  ldy #$02                       ; $CAEB  A0 02

_label_caed:
  stx z:_var_000c                ; $CAED  86 0C
  sty z:_var_000f                ; $CAEF  84 0F
  lda z:_var_0048                ; $CAF1  A5 48
  and #$07                       ; $CAF3  29 07
  eor #$07                       ; $CAF5  49 07
  ora z:_var_000c                ; $CAF7  05 0C

_data_caf9:
  sta z:_var_000c                ; $CAF9  85 0C
  jsr _func_c588                 ; $CAFB  20 88 C5
  and #$03                       ; $CAFE  29 03
  cmp #$03                       ; $CB00  C9 03
  bne _label_cb06                ; $CB02  D0 02
  lda #$02                       ; $CB04  A9 02

_label_cb06:
  clc                            ; $CB06  18
  adc z:_var_000c                ; $CB07  65 0C
  sta z:_var_000e                ; $CB09  85 0E
  ldy z:_var_000f                ; $CB0B  A4 0F
  cmp #$00                       ; $CB0D  C9 00
  bne _label_cb1b                ; $CB0F  D0 0A
  cpy #$01                       ; $CB11  C0 01
  beq _label_cb4b                ; $CB13  F0 36
  cpy #$02                       ; $CB15  C0 02
  beq _label_cb45                ; $CB17  F0 2C
  bne _label_cb50                ; $CB19  D0 35

_label_cb1b:
  cmp #$04                       ; $CB1B  C9 04
  bne _label_cb29                ; $CB1D  D0 0A
  cpy #$00                       ; $CB1F  C0 00
  beq _label_cb50                ; $CB21  F0 2D
  cpy #$02                       ; $CB23  C0 02
  beq _label_cb4b                ; $CB25  F0 24
  bne _label_cb45                ; $CB27  D0 1C

_label_cb29:
  cmp #$08                       ; $CB29  C9 08
  bne _label_cb37                ; $CB2B  D0 0A
  cpy #$00                       ; $CB2D  C0 00
  beq _label_cb45                ; $CB2F  F0 14
  cpy #$01                       ; $CB31  C0 01
  beq _label_cb50                ; $CB33  F0 1B
  bne _label_cb4b                ; $CB35  D0 14

_label_cb37:
  cmp #$0C                       ; $CB37  C9 0C
  bne _label_cb52                ; $CB39  D0 17
  cpy #$00                       ; $CB3B  C0 00
  beq _label_cb4b                ; $CB3D  F0 0C
  cpy #$01                       ; $CB3F  C0 01
  beq _label_cb45                ; $CB41  F0 02
  bne _label_cb50                ; $CB43  D0 0B

_label_cb45:
  jsr _func_c588                 ; $CB45  20 88 C5
  asl a                          ; $CB48  0A
  bcs _label_cb50                ; $CB49  B0 05

_label_cb4b:
  dec z:_var_000e                ; $CB4B  C6 0E
  jmp _label_cb52                ; $CB4D  4C 52 CB

_label_cb50:
  inc z:_var_000e                ; $CB50  E6 0E

_label_cb52:
  lda z:_var_000e                ; $CB52  A5 0E
  and #$0F                       ; $CB54  29 0F

_label_cb56:
  jmp _label_cb77                ; $CB56  4C 77 CB

_label_cb59:
  lda z:_var_0046                ; $CB59  A5 46
  bne _label_cbc3                ; $CB5B  D0 66
  ldy z:_var_0047                ; $CB5D  A4 47
  lda (_var_0044_indexed),Y      ; $CB5F  B1 44
  iny                            ; $CB61  C8
  cmp #$FF                       ; $CB62  C9 FF
  bne _label_cb70                ; $CB64  D0 0A
  lda (_var_0044_indexed),Y      ; $CB66  B1 44
  iny                            ; $CB68  C8
  sta z:CurrentSpritePhase                ; $CB69  85 31
  lda (_var_0044_indexed),Y      ; $CB6B  B1 44
  sta z:_var_0042_indexed        ; $CB6D  85 42
  rts                            ; $CB6F  60

_label_cb70:
  sta z:_var_0046                ; $CB70  85 46
  lda (_var_0044_indexed),Y      ; $CB72  B1 44
  iny                            ; $CB74  C8
  sty z:_var_0047                ; $CB75  84 47

_label_cb77:
  sta z:_var_0048                ; $CB77  85 48
  tax                            ; $CB79  AA
  lda a:_data_e64b_indexed,X     ; $CB7A  BD 4B E6
  sta z:_var_0049                ; $CB7D  85 49
  sta z:DuckDirection                ; $CB7F  85 4A
  lda #$00                       ; $CB81  A9 00
  sta z:_var_0034                ; $CB83  85 34
  lda z:_var_0048                ; $CB85  A5 48
  cmp #$11                       ; $CB87  C9 11
  bcc _label_cba2                ; $CB89  90 17
  tax                            ; $CB8B  AA
  lda #$00                       ; $CB8C  A9 00
  cpx #$15                       ; $CB8E  E0 15
  beq _label_cbbc                ; $CB90  F0 2A
  cpx #$14                       ; $CB92  E0 14
  beq _label_cbb0                ; $CB94  F0 1A
  cpx #$13                       ; $CB96  E0 13
  beq _label_cba8                ; $CB98  F0 0E
  inc z:_var_0034                ; $CB9A  E6 34
  cpx #$12                       ; $CB9C  E0 12
  beq _label_cbb0                ; $CB9E  F0 10
  bne _label_cbbc                ; $CBA0  D0 1A

_label_cba2:
  cmp #$08                       ; $CBA2  C9 08
  bcc _label_cba8                ; $CBA4  90 02
  inc z:_var_0034                ; $CBA6  E6 34

_label_cba8:
  ldx #$0C                       ; $CBA8  A2 0C
  ldy #$E7                       ; $CBAA  A0 E7
  and #$07                       ; $CBAC  29 07
  beq _label_cbc0                ; $CBAE  F0 10

_label_cbb0:
  ldx #$05                       ; $CBB0  A2 05
  ldy #$E7                       ; $CBB2  A0 E7
  cmp #$03                       ; $CBB4  C9 03
  bcc _label_cbc0                ; $CBB6  90 08
  cmp #$06                       ; $CBB8  C9 06
  bcs _label_cbc0                ; $CBBA  B0 04

_label_cbbc:
  ldx #$1D                       ; $CBBC  A2 1D
  ldy #$E7                       ; $CBBE  A0 E7

_label_cbc0:
  jsr _func_cf0b                 ; $CBC0  20 0B CF

_label_cbc3:
  jsr _func_d81b                 ; $CBC3  20 1B D8

_label_cbc6:
  pha                            ; $CBC6  48
  lda z:_var_0032                ; $CBC7  A5 32
  cmp #$F0                       ; $CBC9  C9 F0
  bcc _label_cbd1                ; $CBCB  90 04
  pla                            ; $CBCD  68
  jmp _label_cf2a                ; $CBCE  4C 2A CF

_label_cbd1:
  lda z:_var_0046                ; $CBD1  A5 46
  beq _label_cbd7                ; $CBD3  F0 02
  dec z:_var_0046                ; $CBD5  C6 46

_label_cbd7:
  ldy z:_var_0049                ; $CBD7  A4 49

_label_cbd9:
  lda a:_data_e661_indexed,Y     ; $CBD9  B9 61 E6
  iny                            ; $CBDC  C8
  cmp #$AA                       ; $CBDD  C9 AA
  bne _label_cbe6                ; $CBDF  D0 05
  ldy z:DuckDirection                ; $CBE1  A4 4A
  jmp _label_cbd9                ; $CBE3  4C D9 CB

_label_cbe6:
  clc                            ; $CBE6  18
  adc z:_var_0032                ; $CBE7  65 32
  ldx z:_var_004b                ; $CBE9  A6 4B
  bne _label_cbf9                ; $CBEB  D0 0C
  ldx z:_var_00ae                ; $CBED  A6 AE
  bne _label_cbf9                ; $CBEF  D0 08
  cmp #$1E                       ; $CBF1  C9 1E
  bcc _label_cbfb                ; $CBF3  90 06
  cmp #$92                       ; $CBF5  C9 92
  bcs _label_cbfb                ; $CBF7  B0 02

_label_cbf9:
  sta z:_var_0032                ; $CBF9  85 32

_label_cbfb:
  lda a:_data_e661_indexed,Y     ; $CBFB  B9 61 E6
  iny                            ; $CBFE  C8
  sty z:_var_0049                ; $CBFF  84 49
  clc                            ; $CC01  18
  adc z:_var_0033                ; $CC02  65 33
  ldx z:_var_004b                ; $CC04  A6 4B
  bne _label_cc14                ; $CC06  D0 0C
  ldx z:_var_00ae                ; $CC08  A6 AE
  bne _label_cc14                ; $CC0A  D0 08
  cmp #$0E                       ; $CC0C  C9 0E
  bcc _label_cc16                ; $CC0E  90 06
  cmp #$F2                       ; $CC10  C9 F2
  bcs _label_cc16                ; $CC12  B0 02

_label_cc14:
  sta z:_var_0033                ; $CC14  85 33

_label_cc16:
  pla                            ; $CC16  68
  sec                            ; $CC17  38
  sbc #$01                       ; $CC18  E9 01
  bne _label_cbc6                ; $CC1A  D0 AA
  jmp _func_ce4d                 ; $CC1C  4C 4D CE

_label_cc1f:
  ldx z:DuckNumber                ; $CC1F  A6 3B
  lda #$01                       ; $CC21  A9 01
  sta a:_var_03ef_indexed,X      ; $CC23  9D EF 03
  lda #$01                       ; $CC26  A9 01
  sta z:_var_00ad                ; $CC28  85 AD
  sta z:_var_005e                ; $CC2A  85 5E
  lda #$12                       ; $CC2C  A9 12
  sta z:_var_004d                ; $CC2E  85 4D
  jsr _func_cf68                 ; $CC30  20 68 CF
  ldx #$13                       ; $CC33  A2 13
  ldy #$E7                       ; $CC35  A0 E7

_label_cc37:
  jsr _func_cf0b                 ; $CC37  20 0B CF
  inc z:CurrentSpritePhase                ; $CC3A  E6 31
  rts                            ; $CC3C  60

_label_cc3d:
  lda z:_var_004d                ; $CC3D  A5 4D
  beq _label_cc4c                ; $CC3F  F0 0B
  dec z:_var_004d                ; $CC41  C6 4D
  and #$0F                       ; $CC43  29 0F
  cmp #$0A                       ; $CC45  C9 0A
  bne _label_cc4c                ; $CC47  D0 03
  jsr _func_d52c                 ; $CC49  20 2C D5

_label_cc4c:
  jmp _func_ce4d                 ; $CC4C  4C 4D CE

_label_cc4f:
  jsr _func_cff9                 ; $CC4F  20 F9 CF
  jsr _func_d4f2                 ; $CC52  20 F2 D4
  lda z:_var_0033                ; $CC55  A5 33
  ldx #$48                       ; $CC57  A2 48
  cmp #$48                       ; $CC59  C9 48
  bcc _label_cc64                ; $CC5B  90 07
  ldx #$A0                       ; $CC5D  A2 A0
  cmp #$A0                       ; $CC5F  C9 A0
  bcs _label_cc64                ; $CC61  B0 01
  tax                            ; $CC63  AA

_label_cc64:
  stx a:$03A3                    ; $CC64  8E A3 03
  lda #$01                       ; $CC67  A9 01
  sta z:_var_004b                ; $CC69  85 4B
  ldx #$10                       ; $CC6B  A2 10
  stx z:_var_0048                ; $CC6D  86 48
  lda a:_data_e64b_indexed,X     ; $CC6F  BD 4B E6
  sta z:_var_0049                ; $CC72  85 49
  sta z:DuckDirection                ; $CC74  85 4A
  ldx #$18                       ; $CC76  A2 18
  ldy #$E7                       ; $CC78  A0 E7
  bne _label_cc37                ; $CC7A  D0 BB

_label_cc7c:
  lda z:_var_0032                ; $CC7C  A5 32
  cmp #$B0                       ; $CC7E  C9 B0
  bcs _label_cc85                ; $CC80  B0 03
  jmp _label_cbc3                ; $CC82  4C C3 CB

_label_cc85:
  jsr _func_d534                 ; $CC85  20 34 D5
  inc z:CurrentSpritePhase                ; $CC88  E6 31
  rts                            ; $CC8A  60

_label_cc8b:
  lda #$00                       ; $CC8B  A9 00
  sta z:CurrentSpritePhase                ; $CC8D  85 31
  ldx z:_var_0036                ; $CC8F  A6 36
  jmp _func_d042                 ; $CC91  4C 42 D0

_func_cc94:
  lda a:_var_03a0                ; $CC94  AD A0 03
  beq _label_cca8                ; $CC97  F0 0F
  lda #$02                       ; $CC99  A9 02
  sta z:_var_00a1                ; $CC9B  85 A1
  ldy #$A0                       ; $CC9D  A0 A0
  jsr _func_c5f7                 ; $CC9F  20 F7 C5
  jsr _func_cca9                 ; $CCA2  20 A9 CC
  jsr _func_c607                 ; $CCA5  20 07 C6

_label_cca8:
  rts                            ; $CCA8  60

_func_cca9:
  lda z:CurrentSpritePhase                ; $CCA9  A5 31
  jsr _jump_engine_c35e          ; $CCAB  20 5E C3

  .word _label_c5e0              ; $CCAE  E0 C5
  .word _label_ccd4              ; $CCB0  D4 CC
  .word _label_cd16              ; $CCB2  16 CD
  .word _label_cd1d              ; $CCB4  1D CD
  .word _label_cd3c              ; $CCB6  3C CD
  .word _func_ce4d               ; $CCB8  4D CE
  .word _label_cd4c              ; $CCBA  4C CD
  .word _func_ce4d               ; $CCBC  4D CE
  .word _label_cd52              ; $CCBE  52 CD
  .word _label_cd5c              ; $CCC0  5C CD
  .word _label_cd6c              ; $CCC2  6C CD
  .word _func_ce4d               ; $CCC4  4D CE
  .word _label_cd80              ; $CCC6  80 CD
  .word _func_ce4d               ; $CCC8  4D CE
  .word _label_cd9a              ; $CCCA  9A CD
  .word _label_ce18              ; $CCCC  18 CE
  .word _label_ce2e              ; $CCCE  2E CE
  .word _func_ce4d               ; $CCD0  4D CE
  .word _label_ce40              ; $CCD2  40 CE

_label_ccd4:
  ldx #$1F                       ; $CCD4  A2 1F

_label_ccd6:
  lda a:_data_e76e_indexed,X     ; $CCD6  BD 6E E7
  sta z:_var_0030_indexed,X      ; $CCD9  95 30
  dex                            ; $CCDB  CA
  bpl _label_ccd6                ; $CCDC  10 F8
  lda #$03                       ; $CCDE  A9 03
  sta z:RemainingShots                ; $CCE0  85 BA
  lda #$01                       ; $CCE2  A9 01
  sta z:NextLevelCountdown                ; $CCE4  85 BE
  sta z:_var_00ad                ; $CCE6  85 AD
  lda #$02                       ; $CCE8  A9 02
  sta z:_var_0023                ; $CCEA  85 23
  lda z:_var_0025                ; $CCEC  A5 25
  cmp #$07                       ; $CCEE  C9 07
  bne _label_ccf7                ; $CCF0  D0 05
  lda #$10                       ; $CCF2  A9 10
  sta z:CurrentSpritePhase                ; $CCF4  85 31
  rts                            ; $CCF6  60

_label_ccf7:
  lda z:LevelNumber                ; $CCF7  A5 C1
  ldy #$18                       ; $CCF9  A0 18
  ldx #$00                       ; $CCFB  A2 00
  cmp #$01                       ; $CCFD  C9 01
  beq _label_cd05                ; $CCFF  F0 04
  ldy #$50                       ; $CD01  A0 50
  ldx #$18                       ; $CD03  A2 18

_label_cd05:
  sty z:_var_0033                ; $CD05  84 33
  stx z:_var_0044_indexed        ; $CD07  86 44
  lda #$01                       ; $CD09  A9 01
  sta z:_var_009d                ; $CD0B  85 9D
  jsr _func_c5d9                 ; $CD0D  20 D9 C5
  jsr _func_f56c                 ; $CD10  20 6C F5
  inc z:CurrentSpritePhase                ; $CD13  E6 31
  rts                            ; $CD15  60

_label_cd16:
  ldx #$8E                       ; $CD16  A2 8E
  ldy #$E7                       ; $CD18  A0 E7
  jmp _label_cd44                ; $CD1A  4C 44 CD

_label_cd1d:
  lda z:_var_0035                ; $CD1D  A5 35
  cmp #$0C                       ; $CD1F  C9 0C
  bne _label_cd2e                ; $CD21  D0 0B
  inc z:_var_0044_indexed        ; $CD23  E6 44
  lda z:_var_0044_indexed        ; $CD25  A5 44
  cmp #$20                       ; $CD27  C9 20
  bcc _label_cd2e                ; $CD29  90 03
  inc z:CurrentSpritePhase                ; $CD2B  E6 31

_label_cd2d:
  rts                            ; $CD2D  60

_label_cd2e:
  jsr _func_ce4d                 ; $CD2E  20 4D CE
  lda z:_var_0033                ; $CD31  A5 33
  cmp z:_var_0045                ; $CD33  C5 45
  bne _label_cd2d                ; $CD35  D0 F6
  lda #$06                       ; $CD37  A9 06
  sta z:CurrentSpritePhase                ; $CD39  85 31
  rts                            ; $CD3B  60

_label_cd3c:
  lda #$00                       ; $CD3C  A9 00
  sta z:_var_0044_indexed        ; $CD3E  85 44
  ldx #$98                       ; $CD40  A2 98
  ldy #$E7                       ; $CD42  A0 E7

_label_cd44:
  jsr _func_cf0b                 ; $CD44  20 0B CF
  inc z:CurrentSpritePhase                ; $CD47  E6 31
  jmp _func_ce4d                 ; $CD49  4C 4D CE

_label_cd4c:
  ldx #$A7                       ; $CD4C  A2 A7
  ldy #$E7                       ; $CD4E  A0 E7
  bne _label_cd44                ; $CD50  D0 F2

_label_cd52:
  lda #$04                       ; $CD52  A9 04
  sta z:_var_009e                ; $CD54  85 9E
  ldx #$AC                       ; $CD56  A2 AC
  ldy #$E7                       ; $CD58  A0 E7
  bne _label_cd44                ; $CD5A  D0 E8

_label_cd5c:
  dec z:_var_009e                ; $CD5C  C6 9E
  lda z:_var_009e                ; $CD5E  A5 9E
  bne _label_cd69                ; $CD60  D0 07
  lda #$10                       ; $CD62  A9 10
  sta z:_var_009e                ; $CD64  85 9E
  jsr _func_d528                 ; $CD66  20 28 D5

_label_cd69:
  jmp _func_ce4d                 ; $CD69  4C 4D CE

_label_cd6c:
  lda z:_var_002b_indexed        ; $CD6C  A5 2B
  bne _label_cd2d                ; $CD6E  D0 BD
  jsr _func_d4fa                 ; $CD70  20 FA D4
  lda #$80                       ; $CD73  A9 80
  sta z:_var_0033                ; $CD75  85 33
  jsr _func_cf39                 ; $CD77  20 39 CF
  ldx #$46                       ; $CD7A  A2 46
  ldy #$E8                       ; $CD7C  A0 E8
  bne _label_cd44                ; $CD7E  D0 C4

_label_cd80:
  lda z:_var_002b_indexed        ; $CD80  A5 2B
  bne _label_cd2d                ; $CD82  D0 A9
  jsr _func_d511                 ; $CD84  20 11 D5
  jsr _func_cf39                 ; $CD87  20 39 CF
  ldx #$94                       ; $CD8A  A2 94
  ldy #$E8                       ; $CD8C  A0 E8
  lda z:TargetShot                ; $CD8E  A5 BD
  cmp #$01                       ; $CD90  C9 01
  beq _label_cd44                ; $CD92  F0 B0
  ldx #$A3                       ; $CD94  A2 A3
  ldy #$E8                       ; $CD96  A0 E8
  bne _label_cd44                ; $CD98  D0 AA

_label_cd9a:
  lda #$30                       ; $CD9A  A9 30
  sta z:_var_00a6                ; $CD9C  85 A6
  lda #$01                       ; $CD9E  A9 01
  sta z:TargetActive                ; $CDA0  85 B9
  lda #$03                       ; $CDA2  A9 03
  sta z:RemainingShots                ; $CDA4  85 BA
  lda #$01                       ; $CDA6  A9 01
  sta z:NextLevelCountdown                ; $CDA8  85 BE
  lda #$00                       ; $CDAA  A9 00
  sta z:TargetShot                ; $CDAC  85 BD
  lda #$02                       ; $CDAE  A9 02
  ldy #$01                       ; $CDB0  A0 01
  ldx z:_var_001f                ; $CDB2  A6 1F
  bne _label_cdba                ; $CDB4  D0 04
  lda #$01                       ; $CDB6  A9 01
  ldy #$00                       ; $CDB8  A0 00

_label_cdba:
  sta z:TargetFinishedFalling                ; $CDBA  85 BC
  sty a:_var_0350                ; $CDBC  8C 50 03
  sty a:_var_0351                ; $CDBF  8C 51 03
  lda #$01                       ; $CDC2  A9 01
  sta a:TargetOneType        ; $CDC4  8D 00 03
  sta a:TargetOneState        ; $CDC7  8D 01 03
  jsr _func_c588                 ; $CDCA  20 88 C5
  sta z:_var_000c                ; $CDCD  85 0C
  lda #$03                       ; $CDCF  A9 03
  ldy z:LevelNumber                ; $CDD1  A4 C1
  cpy #$01                       ; $CDD3  C0 01
  beq _label_cdd9                ; $CDD5  F0 02
  lda #$07                       ; $CDD7  A9 07

_label_cdd9:
  and z:_var_000c                ; $CDD9  25 0C
  sta z:_var_0098                ; $CDDB  85 98
  ldy #$00                       ; $CDDD  A0 00
  sty z:_var_0099                ; $CDDF  84 99
  tax                            ; $CDE1  AA
  lda a:_data_e766_indexed,X     ; $CDE2  BD 66 E7
  sta z:_var_000c                ; $CDE5  85 0C
  and #$F0                       ; $CDE7  29 F0
  lsr a                          ; $CDE9  4A
  ldy #$00                       ; $CDEA  A0 00
  jsr _func_cf44                 ; $CDEC  20 44 CF
  lda z:_var_000c                ; $CDEF  A5 0C
  and #$0F                       ; $CDF1  29 0F
  asl a                          ; $CDF3  0A
  asl a                          ; $CDF4  0A
  asl a                          ; $CDF5  0A
  jsr _func_cf44                 ; $CDF6  20 44 CF
  lda #$3F                       ; $CDF9  A9 3F
  sta a:$0400                    ; $CDFB  8D 00 04
  lda #$10                       ; $CDFE  A9 10
  sta a:$0401                    ; $CE00  8D 01 04
  sta a:$0402                    ; $CE03  8D 02 04
  lda #$00                       ; $CE06  A9 00
  sta a:$0413                    ; $CE08  8D 13 04
  lda #$01                       ; $CE0B  A9 01
  sta z:WhiteBoxVisible                ; $CE0D  85 27
  lda #$12                       ; $CE0F  A9 12
  sta z:CurrentSpritePhase                ; $CE11  85 31
  lda #$00                       ; $CE13  A9 00
  sta z:_var_0042_indexed        ; $CE15  85 42
  rts                            ; $CE17  60

_label_ce18:
  lda z:CurrentActiveDuckTarget                ; $CE18  A5 BB
  cmp #$0A                       ; $CE1A  C9 0A
  bne _label_ce29                ; $CE1C  D0 0B
  lda #$00                       ; $CE1E  A9 00
  sta z:_var_00a9                ; $CE20  85 A9
  lda #$04                       ; $CE22  A9 04
  sta z:_var_0025                ; $CE24  85 25
  jmp _func_c23b                 ; $CE26  4C 3B C2

_label_ce29:
  lda #$0E                       ; $CE29  A9 0E
  sta z:CurrentSpritePhase                ; $CE2B  85 31
  rts                            ; $CE2D  60

_label_ce2e:
  lda #$80                       ; $CE2E  A9 80
  sta z:_var_0033                ; $CE30  85 33
  lda #$01                       ; $CE32  A9 01
  sta z:_var_0038                ; $CE34  85 38
  jsr _func_cf39                 ; $CE36  20 39 CF
  ldx #$B2                       ; $CE39  A2 B2
  ldy #$E8                       ; $CE3B  A0 E8
  jmp _label_cd44                ; $CE3D  4C 44 CD

_label_ce40:
  lda z:_var_0042_indexed        ; $CE40  A5 42
  bne _func_ce4d                 ; $CE42  D0 09
  lda #$00                       ; $CE44  A9 00
  sta z:CurrentSpritePhase                ; $CE46  85 31
  ldx z:_var_0036                ; $CE48  A6 36
  jmp _func_d042                 ; $CE4A  4C 42 D0

_func_ce4d:
  lda z:_var_0042_indexed        ; $CE4D  A5 42
  beq _label_ce56                ; $CE4F  F0 05
  dec z:_var_0042_indexed        ; $CE51  C6 42
  jmp _label_d01b                ; $CE53  4C 1B D0

_label_ce56:
  ldy z:_var_0043_indexed        ; $CE56  A4 43
  lda (_var_0040_indexed),Y      ; $CE58  B1 40
  cmp #$FA                       ; $CE5A  C9 FA
  bcc _label_ce72                ; $CE5C  90 14
  inc z:_var_0043_indexed        ; $CE5E  E6 43
  sec                            ; $CE60  38
  sbc #$FA                       ; $CE61  E9 FA
  jsr _jump_engine_c35e          ; $CE63  20 5E C3

  .word _label_c5e0              ; $CE66  E0 C5
  .word _label_c5e0              ; $CE68  E0 C5
  .word _label_cf07              ; $CE6A  07 CF
  .word _label_cf00              ; $CE6C  00 CF
  .word _label_cef9              ; $CE6E  F9 CE
  .word _label_ceed              ; $CE70  ED CE

_label_ce72:
  ldy z:_var_0043_indexed        ; $CE72  A4 43
  ldx z:_var_00a1                ; $CE74  A6 A1
  cpx #$02                       ; $CE76  E0 02
  bne _label_cee6                ; $CE78  D0 6C
  ldx z:CurrentSpritePhase                ; $CE7A  A6 31
  cpx #$09                       ; $CE7C  E0 09
  beq _label_cead                ; $CE7E  F0 2D
  cpx #$0B                       ; $CE80  E0 0B
  beq _label_ce8c                ; $CE82  F0 08
  cpx #$0D                       ; $CE84  E0 0D
  beq _label_ce8c                ; $CE86  F0 04
  cpx #$11                       ; $CE88  E0 11
  bne _label_ced4                ; $CE8A  D0 48

_label_ce8c:
  ldx z:_var_0046                ; $CE8C  A6 46
  beq _label_ce9c                ; $CE8E  F0 0C
  dec z:_var_0046                ; $CE90  C6 46
  lda z:_var_0047                ; $CE92  A5 47
  clc                            ; $CE94  18
  adc z:_var_0032                ; $CE95  65 32
  sta z:_var_0032                ; $CE97  85 32
  jmp _label_d01b                ; $CE99  4C 1B D0

_label_ce9c:
  sta z:_var_0046                ; $CE9C  85 46
  iny                            ; $CE9E  C8
  lda (_var_0040_indexed),Y      ; $CE9F  B1 40
  bpl _label_cea8                ; $CEA1  10 05
  and #$7F                       ; $CEA3  29 7F
  jsr _func_d12b                 ; $CEA5  20 2B D1

_label_cea8:
  sta z:_var_0047                ; $CEA8  85 47
  jmp _label_cec9                ; $CEAA  4C C9 CE

_label_cead:
  tax                            ; $CEAD  AA
  bpl _label_ceb5                ; $CEAE  10 05
  and #$7F                       ; $CEB0  29 7F
  jsr _func_d12b                 ; $CEB2  20 2B D1

_label_ceb5:
  clc                            ; $CEB5  18
  adc z:_var_0032                ; $CEB6  65 32
  sta z:_var_0032                ; $CEB8  85 32
  iny                            ; $CEBA  C8
  lda (_var_0040_indexed),Y      ; $CEBB  B1 40
  ldx z:_var_0034                ; $CEBD  A6 34
  beq _label_cec4                ; $CEBF  F0 03
  jsr _func_d12b                 ; $CEC1  20 2B D1

_label_cec4:
  clc                            ; $CEC4  18
  adc z:_var_0033                ; $CEC5  65 33
  sta z:_var_0033                ; $CEC7  85 33

_label_cec9:
  iny                            ; $CEC9  C8
  lda (_var_0040_indexed),Y      ; $CECA  B1 40
  sta z:_var_0035                ; $CECC  85 35
  iny                            ; $CECE  C8
  sty z:_var_0043_indexed        ; $CECF  84 43
  jmp _label_d01b                ; $CED1  4C 1B D0

_label_ced4:
  cpx #$03                       ; $CED4  E0 03
  bne _label_cee6                ; $CED6  D0 0E
  lda #$02                       ; $CED8  A9 02
  ldx z:_var_0034                ; $CEDA  A6 34
  beq _label_cee1                ; $CEDC  F0 03
  jsr _func_d12b                 ; $CEDE  20 2B D1

_label_cee1:
  clc                            ; $CEE1  18
  adc z:_var_0033                ; $CEE2  65 33
  sta z:_var_0033                ; $CEE4  85 33

_label_cee6:
  lda (_var_0040_indexed),Y      ; $CEE6  B1 40
  sta z:_var_0042_indexed        ; $CEE8  85 42
  jmp _label_cec9                ; $CEEA  4C C9 CE

_label_ceed:
  ldy z:_var_0043_indexed        ; $CEED  A4 43
  lda (_var_0040_indexed),Y      ; $CEEF  B1 40
  sta z:CurrentSpritePhase                ; $CEF1  85 31
  iny                            ; $CEF3  C8
  lda (_var_0040_indexed),Y      ; $CEF4  B1 40
  sta z:_var_0042_indexed        ; $CEF6  85 42
  rts                            ; $CEF8  60

_label_cef9:
  lda #$00                       ; $CEF9  A9 00

_label_cefb:
  sta z:_var_0043_indexed        ; $CEFB  85 43
  jmp _label_ce56                ; $CEFD  4C 56 CE

_label_cf00:
  lda #$01                       ; $CF00  A9 01
  sta z:_var_0038                ; $CF02  85 38
  jmp _label_ce56                ; $CF04  4C 56 CE

_label_cf07:
  lda #$1E                       ; $CF07  A9 1E
  bne _label_cefb                ; $CF09  D0 F0

_func_cf0b:
  stx z:_var_0040_indexed        ; $CF0B  86 40
  sty z:_var_0041_indexed        ; $CF0D  84 41
  lda #$00                       ; $CF0F  A9 00
  sta z:_var_0043_indexed        ; $CF11  85 43
  sta z:_var_0042_indexed        ; $CF13  85 42
  rts                            ; $CF15  60

_label_cf16:
  lda z:_var_0032                ; $CF16  A5 32
  cmp #$08                       ; $CF18  C9 08
  bcc _label_cf2a                ; $CF1A  90 0E
  cmp #$90                       ; $CF1C  C9 90
  bcs _label_cf33                ; $CF1E  B0 13
  lda z:_var_0033                ; $CF20  A5 33
  cmp #$0C                       ; $CF22  C9 0C
  bcc _label_cf2a                ; $CF24  90 04
  cmp #$F4                       ; $CF26  C9 F4
  bcc _label_cf36                ; $CF28  90 0C

_label_cf2a:
  lda #$08                       ; $CF2A  A9 08
  sta z:CurrentSpritePhase                ; $CF2C  85 31
  lda #$00                       ; $CF2E  A9 00
  sta z:_var_0042_indexed        ; $CF30  85 42
  rts                            ; $CF32  60

_label_cf33:
  jmp _label_cad7                ; $CF33  4C D7 CA

_label_cf36:
  jmp _label_caa5                ; $CF36  4C A5 CA

_func_cf39:
  lda #$00                       ; $CF39  A9 00
  sta z:_var_0046                ; $CF3B  85 46
  sta z:_var_0047                ; $CF3D  85 47
  lda #$AC                       ; $CF3F  A9 AC
  sta z:_var_0032                ; $CF41  85 32
  rts                            ; $CF43  60

_func_cf44:
  tax                            ; $CF44  AA
  lda #$08                       ; $CF45  A9 08
  sta z:_var_000d                ; $CF47  85 0D

_label_cf49:
  lda a:_data_e724_indexed,X     ; $CF49  BD 24 E7
  sta a:BackgroundColor,Y      ; $CF4C  99 03 04
  inx                            ; $CF4F  E8
  iny                            ; $CF50  C8
  dec z:_var_000d                ; $CF51  C6 0D
  bne _label_cf49                ; $CF53  D0 F4
  rts                            ; $CF55  60

_func_cf56:
  lda z:LevelNumber                ; $CF56  A5 C1
  ldy #$02                       ; $CF58  A0 02
  cmp #$06                       ; $CF5A  C9 06
  bcc _label_cf7f                ; $CF5C  90 21
  ldy #$03                       ; $CF5E  A0 03
  cmp #$11                       ; $CF60  C9 11
  bcc _label_cf7f                ; $CF62  90 1B
  ldy #$05                       ; $CF64  A0 05
  bne _label_cf7f                ; $CF66  D0 17

_func_cf68:
  ldx z:LevelNumber                ; $CF68  A6 C1
  lda #$00                       ; $CF6A  A9 00
  cpx #$06                       ; $CF6C  E0 06
  bcc _label_cf78                ; $CF6E  90 08
  lda #$03                       ; $CF70  A9 03
  cpx #$11                       ; $CF72  E0 11
  bcc _label_cf78                ; $CF74  90 02
  lda #$06                       ; $CF76  A9 06

_label_cf78:
  clc                            ; $CF78  18
  adc z:DuckColor                ; $CF79  65 3F
  tax                            ; $CF7B  AA
  ldy a:_data_ebf1_indexed,X     ; $CF7C  BC F1 EB

_label_cf7f:
  sty z:_var_0039                ; $CF7F  84 39
  lda a:_data_ebfa_indexed,Y     ; $CF81  B9 FA EB
  sta z:_var_0006                ; $CF84  85 06
  lda #$00                       ; $CF86  A9 00
  sta z:_var_0004                ; $CF88  85 04
  sta z:Submode                ; $CF8A  85 05
  sta z:_var_0007                ; $CF8C  85 07
  lda #$0F                       ; $CF8E  A9 0F
  jsr _func_c437                 ; $CF90  20 37 C4
  jmp _func_c655                 ; $CF93  4C 55 C6

_func_cf96:
  lda z:TargetShot                ; $CF96  A5 BD -  load if the target was shot to the accumulator
  bne ReturnToSubroutineBecauseTargetWasShot                ; $CF98  D0 1F - if not zero, we shot the target, return to subroutine.
  lda #$06                       ; $CF9A  A9 06
  jsr _func_d464                 ; $CF9C  20 64 D4
  lda #$30                       ; $CF9F  A9 30
  sta z:_var_002b_indexed        ; $CFA1  85 2B
  lda #$06                       ; $CFA3  A9 06
  sta z:_var_0023                ; $CFA5  85 23
  lda #$01                       ; $CFA7  A9 01 - load 01 to the accumulator
  sta z:WhiteBoxVisible                ; $CFA9  85 27 - make the white box visible
  lda #$36                       ; $CFAB  A9 36 - load 0x36 to the accumulator
  sta a:BackgroundColor        ; $CFAD  8D 03 04 - store it to the background color, which 0x36 = red
  sta a:$0407                    ; $CFB0  8D 07 04
  sta a:$040B                    ; $CFB3  8D 0B 04
  sta a:$040F                    ; $CFB6  8D 0F 04

;; Just a random rts, used for this one purpose
ReturnToSubroutineBecauseTargetWasShot:
  rts                            ; $CFB9  60 - return to subroutine. (TODO: falls back to ignoring the rest of _func_cf96)?

_func_cfba:
  ldx #$00                       ; $CFBA  A2 00
  ldy #$00                       ; $CFBC  A0 00
  jsr _func_cfc5                 ; $CFBE  20 C5 CF
  ldx #$04                       ; $CFC1  A2 04
  ldy #$08                       ; $CFC3  A0 08

_func_cfc5:
  lda z:_var_0080_indexed,X      ; $CFC5  B5 80
  beq _label_cff8                ; $CFC7  F0 2F
  dec z:_var_0080_indexed,X      ; $CFC9  D6 80
  bne _label_cfd3                ; $CFCB  D0 06
  lda #$F4                       ; $CFCD  A9 F4
  sta z:_var_0081_indexed,X      ; $CFCF  95 81
  sta z:_var_0082_indexed,X      ; $CFD1  95 82

_label_cfd3:
  lda z:_var_0081_indexed,X      ; $CFD3  B5 81
  sta a:_var_02f0_indexed,Y      ; $CFD5  99 F0 02
  sta a:_var_02f4_indexed,Y      ; $CFD8  99 F4 02
  lda z:_var_0083_indexed,X      ; $CFDB  B5 83
  sta a:_var_02f1_indexed,Y      ; $CFDD  99 F1 02
  lda #$FF                       ; $CFE0  A9 FF
  sta a:_var_02f5_indexed,Y      ; $CFE2  99 F5 02
  lda #$00                       ; $CFE5  A9 00
  sta a:_var_02f2_indexed,Y      ; $CFE7  99 F2 02
  sta a:_var_02f6_indexed,Y      ; $CFEA  99 F6 02
  lda z:_var_0082_indexed,X      ; $CFED  B5 82
  sta a:_var_02f3_indexed,Y      ; $CFEF  99 F3 02
  clc                            ; $CFF2  18
  adc #$08                       ; $CFF3  69 08
  sta a:_var_02f7_indexed,Y      ; $CFF5  99 F7 02

_label_cff8:
  rts                            ; $CFF8  60

_func_cff9:
  ldx #$00                       ; $CFF9  A2 00
  lda z:_var_0080_indexed,X      ; $CFFB  B5 80
  beq _label_d001                ; $CFFD  F0 02
  ldx #$04                       ; $CFFF  A2 04

_label_d001:
  lda z:_var_0032                ; $D001  A5 32
  sec                            ; $D003  38
  sbc #$04                       ; $D004  E9 04
  sta z:_var_0081_indexed,X      ; $D006  95 81
  lda z:_var_0033                ; $D008  A5 33
  sec                            ; $D00A  38
  sbc #$08                       ; $D00B  E9 08
  sta z:_var_0082_indexed,X      ; $D00D  95 82
  lda z:_var_0039                ; $D00F  A5 39
  clc                            ; $D011  18
  adc #$F7                       ; $D012  69 F7
  sta z:_var_0083_indexed,X      ; $D014  95 83
  lda #$30                       ; $D016  A9 30
  sta z:_var_0080_indexed,X      ; $D018  95 80
  rts                            ; $D01A  60

_label_d01b:
  lda z:_var_0036                ; $D01B  A5 36
  sta z:_var_00b4                ; $D01D  85 B4
  lda z:_var_0035                ; $D01F  A5 35
  asl a                          ; $D021  0A
  tay                            ; $D022  A8
  lda #$C5                       ; $D023  A9 C5
  sta z:_var_0012_indexed        ; $D025  85 12
  lda #$DA                       ; $D027  A9 DA
  sta z:_var_0013                ; $D029  85 13
  lda (_var_0012_indexed),Y      ; $D02B  B1 12
  sta z:_var_0010_indexed        ; $D02D  85 10
  iny                            ; $D02F  C8
  lda (_var_0012_indexed),Y      ; $D030  B1 12
  sta z:_var_0011                ; $D032  85 11
  ldy #$00                       ; $D034  A0 00
  sty z:_var_001a                ; $D036  84 1A

_label_d038:
  ldy z:_var_001a                ; $D038  A4 1A
  lda (_var_0010_indexed),Y      ; $D03A  B1 10
  cmp #$00                       ; $D03C  C9 00
  bne _label_d050                ; $D03E  D0 10
  ldx z:_var_00b4                ; $D040  A6 B4

_func_d042:
  lda #$F4                       ; $D042  A9 F4

_label_d044:
  cpx z:_var_0037                ; $D044  E4 37
  beq _label_d04f                ; $D046  F0 07
  sta a:_var_0200_indexed,X      ; $D048  9D 00 02
  inx                            ; $D04B  E8
  jmp _label_d044                ; $D04C  4C 44 D0

_label_d04f:
  rts                            ; $D04F  60

_label_d050:
  sta z:_var_0013                ; $D050  85 13
  iny                            ; $D052  C8
  lda (_var_0010_indexed),Y      ; $D053  B1 10
  iny                            ; $D055  C8
  sta z:_var_0012_indexed        ; $D056  85 12
  lda (_var_0010_indexed),Y      ; $D058  B1 10
  iny                            ; $D05A  C8
  clc                            ; $D05B  18
  adc z:_var_0032                ; $D05C  65 32
  sta z:_var_00b1                ; $D05E  85 B1
  lda (_var_0010_indexed),Y      ; $D060  B1 10
  iny                            ; $D062  C8
  ldx z:_var_0034                ; $D063  A6 34
  beq _label_d06d                ; $D065  F0 06
  jsr _func_d12b                 ; $D067  20 2B D1
  sec                            ; $D06A  38
  sbc #$08                       ; $D06B  E9 08

_label_d06d:
  clc                            ; $D06D  18
  adc z:_var_0033                ; $D06E  65 33
  sta z:_var_00b2                ; $D070  85 B2
  sty z:_var_001a                ; $D072  84 1A
  ldy #$00                       ; $D074  A0 00
  lda (_var_0012_indexed),Y      ; $D076  B1 12
  ldx #$00                       ; $D078  A2 00
  cmp #$00                       ; $D07A  C9 00
  beq _label_d08c                ; $D07C  F0 0E
  ldx #$10                       ; $D07E  A2 10
  cmp #$01                       ; $D080  C9 01
  beq _label_d08c                ; $D082  F0 08
  ldx #$38                       ; $D084  A2 38
  cmp #$02                       ; $D086  C9 02
  beq _label_d08c                ; $D088  F0 02
  ldx #$44                       ; $D08A  A2 44

_label_d08c:
  stx z:_var_001b                ; $D08C  86 1B

_label_d08e:
  iny                            ; $D08E  C8

_label_d08f:
  lda (_var_0012_indexed),Y      ; $D08F  B1 12
  cmp #$FF                       ; $D091  C9 FF
  beq _label_d038                ; $D093  F0 A3
  cmp #$FE                       ; $D095  C9 FE
  bne _label_d0a0                ; $D097  D0 07
  inc z:_var_001b                ; $D099  E6 1B
  inc z:_var_001b                ; $D09B  E6 1B
  jmp _label_d08e                ; $D09D  4C 8E D0

_label_d0a0:
  cmp #$FD                       ; $D0A0  C9 FD
  bne _label_d0b9                ; $D0A2  D0 15
  iny                            ; $D0A4  C8
  lda (_var_0012_indexed),Y      ; $D0A5  B1 12
  clc                            ; $D0A7  18
  adc z:DogColor                ; $D0A8  65 3C
  sta z:_var_00b3                ; $D0AA  85 B3
  lda z:_var_0038                ; $D0AC  A5 38
  beq _label_d08e                ; $D0AE  F0 DE
  lda z:_var_00b3                ; $D0B0  A5 B3
  ora #$20                       ; $D0B2  09 20
  sta z:_var_00b3                ; $D0B4  85 B3
  jmp _label_d08e                ; $D0B6  4C 8E D0

_label_d0b9:
  ldx z:_var_001b                ; $D0B9  A6 1B
  lda a:_data_dcc0_indexed,X     ; $D0BB  BD C0 DC
  inc z:_var_001b                ; $D0BE  E6 1B
  clc                            ; $D0C0  18
  adc z:_var_00b1                ; $D0C1  65 B1
  jsr _func_d10e                 ; $D0C3  20 0E D1
  ldx z:_var_00b4                ; $D0C6  A6 B4
  sta a:_var_0200_indexed,X      ; $D0C8  9D 00 02
  inc z:_var_00b4                ; $D0CB  E6 B4
  lda (_var_0012_indexed),Y      ; $D0CD  B1 12
  iny                            ; $D0CF  C8
  ldx z:_var_00b4                ; $D0D0  A6 B4
  sta a:_var_0200_indexed,X      ; $D0D2  9D 00 02
  inc z:_var_00b4                ; $D0D5  E6 B4
  lda z:_var_00b3                ; $D0D7  A5 B3
  ldx z:_var_0034                ; $D0D9  A6 34
  beq _label_d0e9                ; $D0DB  F0 0C
  and #$BF                       ; $D0DD  29 BF
  sta z:_var_000c                ; $D0DF  85 0C
  lda z:_var_00b3                ; $D0E1  A5 B3
  and #$40                       ; $D0E3  29 40
  eor #$40                       ; $D0E5  49 40
  ora z:_var_000c                ; $D0E7  05 0C

_label_d0e9:
  ldx z:_var_00b4                ; $D0E9  A6 B4
  sta a:_var_0200_indexed,X      ; $D0EB  9D 00 02
  inc z:_var_00b4                ; $D0EE  E6 B4
  ldx z:_var_001b                ; $D0F0  A6 1B
  lda a:_data_dcc0_indexed,X     ; $D0F2  BD C0 DC
  inc z:_var_001b                ; $D0F5  E6 1B
  ldx z:_var_0034                ; $D0F7  A6 34
  beq _label_d0fe                ; $D0F9  F0 03
  jsr _func_d12b                 ; $D0FB  20 2B D1

_label_d0fe:
  clc                            ; $D0FE  18
  adc z:_var_00b2                ; $D0FF  65 B2
  jsr _func_d114                 ; $D101  20 14 D1
  ldx z:_var_00b4                ; $D104  A6 B4
  sta a:_var_0200_indexed,X      ; $D106  9D 00 02
  inc z:_var_00b4                ; $D109  E6 B4
  jmp _label_d08f                ; $D10B  4C 8F D0

_func_d10e:
  pha                            ; $D10E  48
  lda z:_var_0032                ; $D10F  A5 32
  jmp _label_d117                ; $D111  4C 17 D1

_func_d114:
  pha                            ; $D114  48
  lda z:_var_0033                ; $D115  A5 33

_label_d117:
  sta z:_var_000f                ; $D117  85 0F
  pla                            ; $D119  68
  pha                            ; $D11A  48
  sec                            ; $D11B  38
  sbc z:_var_000f                ; $D11C  E5 0F
  bcs _label_d123                ; $D11E  B0 03
  jsr _func_d12b                 ; $D120  20 2B D1

_label_d123:
  cmp #$30                       ; $D123  C9 30
  pla                            ; $D125  68
  bcc _label_d12a                ; $D126  90 02
  lda #$FF                       ; $D128  A9 FF

_label_d12a:
  rts                            ; $D12A  60

_func_d12b:
  eor #$FF                       ; $D12B  49 FF
  clc                            ; $D12D  18
  adc #$01                       ; $D12E  69 01
  rts                            ; $D130  60

_func_d131:
  lda JOYPAD2                    ; $D131  AD 17 40
  and #$10                       ; $D134  29 10
  cmp z:_var_00b7                ; $D136  C5 B7
  beq _label_d141                ; $D138  F0 07
  sta z:_var_00b7                ; $D13A  85 B7

_label_d13c:
  lda #$00                       ; $D13C  A9 00
  sta z:_var_00b8                ; $D13E  85 B8

_label_d140:
  rts                            ; $D140  60

_label_d141:
  inc z:_var_00b8                ; $D141  E6 B8
  ldy z:_var_00b8                ; $D143  A4 B8
  cpy #$01                       ; $D145  C0 01
  bne _label_d140                ; $D147  D0 F7
  and #$10                       ; $D149  29 10
  beq _label_d153                ; $D14B  F0 06
  lda #$01                       ; $D14D  A9 01
  sta z:_var_00b6                ; $D14F  85 B6
  bne _label_d13c                ; $D151  D0 E9

_label_d153:
  lda z:_var_00b6                ; $D153  A5 B6
  beq _label_d13c                ; $D155  F0 E5
  ldy #$00                       ; $D157  A0 00
  sty z:_var_00b6                ; $D159  84 B6
  iny                            ; $D15B  C8
  sty z:_var_00b5                ; $D15C  84 B5
  bne _label_d13c                ; $D15E  D0 DC

_func_d160:
  lda z:TargetActive                ; $D160  A5 B9
  bne _label_d169                ; $D162  D0 05

_label_d164:
  lda #$00                       ; $D164  A9 00
  sta z:_var_00b5                ; $D166  85 B5

_label_d168:
  rts                            ; $D168  60

_label_d169:
  lda z:_var_00b5                ; $D169  A5 B5
  beq _label_d168                ; $D16B  F0 FB
  lda z:RemainingShots                ; $D16D  A5 BA
  beq _label_d164                ; $D16F  F0 F3
  dec z:RemainingShots                ; $D171  C6 BA
  lda #$01                       ; $D173  A9 01
  sta z:NextLevelCountdown                ; $D175  85 BE
  lda #$00                       ; $D177  A9 00
  sta z:_var_00b5                ; $D179  85 B5
  jsr _func_d4e6                 ; $D17B  20 E6 D4
  lda #$04                       ; $D17E  A9 04
  sta z:_var_0023                ; $D180  85 23
  jsr _func_c23b                 ; $D182  20 3B C2
  jsr _func_c5e1                 ; $D185  20 E1 C5
  lda z:MainMenuActive                ; $D188  A5 24
  beq _label_d19f                ; $D18A  F0 13
  jsr _func_d4e2                 ; $D18C  20 E2 D4
  jsr _func_f56c                 ; $D18F  20 6C F5
  jsr _func_d4e6                 ; $D192  20 E6 D4
  lda #$02                       ; $D195  A9 02
  sta z:_var_00b0                ; $D197  85 B0
  lda #$FF                       ; $D199  A9 FF
  sta z:_var_000a                ; $D19B  85 0A
  bne _label_d1ca                ; $D19D  D0 2B

_label_d19f:
  lda #$05                       ; $D19F  A9 05
  sta z:_var_0023                ; $D1A1  85 23
  lda #$00                       ; $D1A3  A9 00
  sta z:_var_00b0                ; $D1A5  85 B0
  ldy #$00                       ; $D1A7  A0 00
  lda a:TargetOneType        ; $D1A9  AD 00 03
  beq _label_d1b5                ; $D1AC  F0 07
  lda a:TargetOneState        ; $D1AE  AD 01 03
  cmp #$03                       ; $D1B1  C9 03
  beq _label_d1c7                ; $D1B3  F0 12

_label_d1b5:
  lda #$01                       ; $D1B5  A9 01
  sta z:_var_00b0                ; $D1B7  85 B0
  ldy #$50                       ; $D1B9  A0 50
  lda a:_var_0350                ; $D1BB  AD 50 03
  beq _label_d1dd                ; $D1BE  F0 1D
  lda a:_var_0351                ; $D1C0  AD 51 03
  cmp #$03                       ; $D1C3  C9 03
  bne _label_d1dd                ; $D1C5  D0 16

_label_d1c7:
  jsr _func_d292                 ; $D1C7  20 92 D2

_label_d1ca:
  jsr _func_c61e                 ; $D1CA  20 1E C6

_label_d1cd:
  lda z:_var_0020                ; $D1CD  A5 20
  bne _label_d1f4                ; $D1CF  D0 23
  lda JOYPAD2                    ; $D1D1  AD 17 40
  and #$08                       ; $D1D4  29 08
  bne _label_d1cd                ; $D1D6  D0 F5
  lda z:_var_00b0                ; $D1D8  A5 B0
  jmp _label_d28a                ; $D1DA  4C 8A D2

_label_d1dd:
  lda z:_var_001f                ; $D1DD  A5 1F
  cmp #$02                       ; $D1DF  C9 02
  bne _label_d1e6                ; $D1E1  D0 03
  jmp _label_d266                ; $D1E3  4C 66 D2

_label_d1e6:
  ldy #$02                       ; $D1E6  A0 02
  sty z:_var_0023                ; $D1E8  84 23
  jsr _func_c5d9                 ; $D1EA  20 D9 C5
  ldy #$01                       ; $D1ED  A0 01
  sty z:WhiteBoxVisible                ; $D1EF  84 27
  jmp _label_d26a                ; $D1F1  4C 6A D2

_label_d1f4:
  jsr _func_c61e                 ; $D1F4  20 1E C6
  lda z:_var_0009                ; $D1F7  A5 09
  and #$E7                       ; $D1F9  29 E7
  sta z:_var_0009                ; $D1FB  85 09
  lda #$08                       ; $D1FD  A9 08
  ldy z:_var_00b0                ; $D1FF  A4 B0
  cpy #$02                       ; $D201  C0 02
  beq _label_d207                ; $D203  F0 02
  lda #$10                       ; $D205  A9 10

_label_d207:
  ora z:_var_0009                ; $D207  05 09
  sta z:_var_0009                ; $D209  85 09
  sta PPU_MASK                   ; $D20B  8D 01 20
  jsr _func_c23b                 ; $D20E  20 3B C2
  lda a:_var_0350                ; $D211  AD 50 03
  beq _label_d222                ; $D214  F0 0C
  lda a:_var_0351                ; $D216  AD 51 03
  cmp #$03                       ; $D219  C9 03
  bne _label_d222                ; $D21B  D0 05
  ldy #$50                       ; $D21D  A0 50
  jsr _func_d292                 ; $D21F  20 92 D2

_label_d222:
  lda z:_var_0020                ; $D222  A5 20
  bne _label_d270                ; $D224  D0 4A
  lda JOYPAD2                    ; $D226  AD 17 40
  and #$08                       ; $D229  29 08
  bne _label_d222                ; $D22B  D0 F5
  lda z:_var_00b0                ; $D22D  A5 B0
  cmp #$02                       ; $D22F  C9 02
  bne _label_d246                ; $D231  D0 13
  lda #$01                       ; $D233  A9 01

_label_d235:
  sta a:MenuAction                ; $D235  8D FF 05
  lda #$01                       ; $D238  A9 01
  sta z:_var_0023                ; $D23A  85 23
  lda #$00                       ; $D23C  A9 00
  sta z:_var_000a                ; $D23E  85 0A
  jsr _func_c5d9                 ; $D240  20 D9 C5
  jmp _func_c5ee                 ; $D243  4C EE C5

_label_d246:
  inc z:CurrentNumberTargets                ; $D246  E6 AA
  inc z:TargetShot                ; $D248  E6 BD
  ldx #$04                       ; $D24A  A2 04
  lda z:_var_00b0                ; $D24C  A5 B0
  bne _label_d256                ; $D24E  D0 06
  stx a:TargetOneState        ; $D250  8E 01 03
  jmp _label_d259                ; $D253  4C 59 D2

_label_d256:
  stx a:_var_0351                ; $D256  8E 51 03

_label_d259:
  lda z:_var_001f                ; $D259  A5 1F
  cmp #$02                       ; $D25B  C9 02
  beq _label_d266                ; $D25D  F0 07
  ldy #$01                       ; $D25F  A0 01
  sty z:WhiteBoxVisible                ; $D261  84 27
  iny                            ; $D263  C8
  bne _label_d268                ; $D264  D0 02

_label_d266:
  ldy #$03                       ; $D266  A0 03

_label_d268:
  sty z:_var_0023                ; $D268  84 23

_label_d26a:
  jsr _func_c23b                 ; $D26A  20 3B C2
  jmp _func_c5ee                 ; $D26D  4C EE C5

_label_d270:
  lda z:_var_00b0                ; $D270  A5 B0
  bne _label_d28a                ; $D272  D0 16
  lda a:_var_0350                ; $D274  AD 50 03
  beq _label_d259                ; $D277  F0 E0
  lda a:_var_0351                ; $D279  AD 51 03
  cmp #$03                       ; $D27C  C9 03
  bne _label_d259                ; $D27E  D0 D9
  lda #$01                       ; $D280  A9 01
  sta z:_var_00b0                ; $D282  85 B0
  jsr _func_c61e                 ; $D284  20 1E C6
  jmp _label_d222                ; $D287  4C 22 D2

_label_d28a:
  cmp #$02                       ; $D28A  C9 02
  bne _label_d259                ; $D28C  D0 CB
  lda #$02                       ; $D28E  A9 02
  bne _label_d235                ; $D290  D0 A3

_func_d292:
  lda a:TargetOneYCoordinate,Y      ; $D292  B9 02 03
  sta z:_var_00b1                ; $D295  85 B1
  lda a:TargetOneXCoordinate,Y      ; $D297  B9 03 03
  sta z:_var_00b2                ; $D29A  85 B2
  lda a:_var_030a_indexed,Y      ; $D29C  B9 0A 03
  sta z:_var_000c                ; $D29F  85 0C
  jmp _label_c67c                ; $D2A1  4C 7C C6

_func_d2a4:
  ldy z:_var_00c2                ; $D2A4  A4 C2

_label_d2a6:
  lda a:_data_ec02_indexed,Y     ; $D2A6  B9 02 EC
  cmp #$FF                       ; $D2A9  C9 FF
  bne _label_d2b1                ; $D2AB  D0 04
  ldy #$13                       ; $D2AD  A0 13
  bne _label_d2a6                ; $D2AF  D0 F5

_label_d2b1:
  iny                            ; $D2B1  C8
  sty z:_var_00c2                ; $D2B2  84 C2
  sta z:MinimumNumShotTargets                ; $D2B4  85 AB
  lda #$00                       ; $D2B6  A9 00
  sta z:CurrentActiveDuckTarget                ; $D2B8  85 BB
  sta z:CurrentNumberTargets                ; $D2BA  85 AA
  lda #$01                       ; $D2BC  A9 01
  sta a:_var_03a0                ; $D2BE  8D A0 03
  sta a:_var_03a1                ; $D2C1  8D A1 03
  lda #$FF                       ; $D2C4  A9 FF
  sta z:_var_009c                ; $D2C6  85 9C
  rts                            ; $D2C8  60

_label_d2c9:
  lda z:_var_00a9                ; $D2C9  A5 A9
  jsr _jump_engine_c35e          ; $D2CB  20 5E C3

  .word _label_d2d6              ; $D2CE  D6 D2
  .word _label_d2dd              ; $D2D0  DD D2
  .word _label_d33d              ; $D2D2  3D D3
  .word _label_d3c9              ; $D2D4  C9 D3

_label_d2d6:
  lda #$10                       ; $D2D6  A9 10
  sta z:_var_002b_indexed        ; $D2D8  85 2B
  inc z:_var_00a9                ; $D2DA  E6 A9
  rts                            ; $D2DC  60

_label_d2dd:
  lda z:_var_002b_indexed        ; $D2DD  A5 2B
  bne _label_d32a                ; $D2DF  D0 49
  ldy #$00                       ; $D2E1  A0 00
  ldx #$01                       ; $D2E3  A2 01

_label_d2e5:
  lda a:_var_03f0_indexed,X      ; $D2E5  BD F0 03
  beq _label_d2f7                ; $D2E8  F0 0D
  lda a:_var_03ef_indexed,X      ; $D2EA  BD EF 03
  bne _label_d2f7                ; $D2ED  D0 08
  inc a:_var_03ef_indexed,X      ; $D2EF  FE EF 03
  dec a:_var_03f0_indexed,X      ; $D2F2  DE F0 03
  ldy #$01                       ; $D2F5  A0 01

_label_d2f7:
  inx                            ; $D2F7  E8
  cpx #$0A                       ; $D2F8  E0 0A
  bne _label_d2e5                ; $D2FA  D0 E9
  dey                            ; $D2FC  88
  bne _label_d309                ; $D2FD  D0 0A
  lda #$00                       ; $D2FF  A9 00
  sta z:_var_00a9                ; $D301  85 A9
  jsr _func_d519                 ; $D303  20 19 D5
  jmp _func_c6cc                 ; $D306  4C CC C6

_label_d309:
  lda z:CurrentNumberTargets                ; $D309  A5 AA
  cmp z:MinimumNumShotTargets                ; $D30B  C5 AB
  bcc _label_d32b                ; $D30D  90 1C
  jsr _func_d51d                 ; $D30F  20 1D D5
  lda #$00                       ; $D312  A9 00
  sta z:NextLevelCountdown                ; $D314  85 BE
  lda #$10                       ; $D316  A9 10
  sta z:_var_002b_indexed        ; $D318  85 2B
  inc z:_var_00a9                ; $D31A  E6 A9
  lda z:LevelNumber                ; $D31C  A5 C1
  and #$0F                       ; $D31E  29 0F
  bne _label_d32a                ; $D320  D0 08
  jsr _func_c23b                 ; $D322  20 3B C2
  lda #$04                       ; $D325  A9 04
  jmp _func_d464                 ; $D327  4C 64 D4

_label_d32a:
  rts                            ; $D32A  60

_label_d32b:
  jsr _func_c23b                 ; $D32B  20 3B C2
  lda #$08                       ; $D32E  A9 08
  jsr _func_d464                 ; $D330  20 64 D4
  jsr _func_d544                 ; $D333  20 44 D5
  ldx #$06                       ; $D336  A2 06
  lda #$0C                       ; $D338  A9 0C
  jmp _func_c62e                 ; $D33A  4C 2E C6

_label_d33d:
  lda z:_var_002b_indexed        ; $D33D  A5 2B
  bne _label_d32a                ; $D33F  D0 E9
  lda #$10                       ; $D341  A9 10
  sta z:_var_002b_indexed        ; $D343  85 2B
  inc z:NextLevelCountdown                ; $D345  E6 BE - Increase the count(up, technically)
  lda z:NextLevelCountdown                ; $D347  A5 BE
  cmp #$0F                       ; $D349  C9 0F - Compare the value with 0F, the final value
  bne _label_d3ad                ; $D34B  D0 60
  lda z:CurrentNumberTargets                ; $D34D  A5 AA
  cmp #$0A                       ; $D34F  C9 0A
  bne _label_d399                ; $D351  D0 46
  jsr _func_d538                 ; $D353  20 38 D5
  lda z:LevelNumber                ; $D356  A5 C1
  ldx #$00                       ; $D358  A2 00
  cmp #$11                       ; $D35A  C9 11
  bcc _label_d369                ; $D35C  90 0B
  inx                            ; $D35E  E8
  cmp #$16                       ; $D35F  C9 16
  bcc _label_d369                ; $D361  90 06
  inx                            ; $D363  E8
  cmp #$21                       ; $D364  C9 21
  bcc _label_d369                ; $D366  90 01
  inx                            ; $D368  E8

_label_d369:
  lda a:_data_ebe9_indexed,X     ; $D369  BD E9 EB
  sta z:Submode                ; $D36C  85 05
  sta z:_var_000c                ; $D36E  85 0C
  lda a:_data_ebed_indexed,X     ; $D370  BD ED EB
  sta z:_var_0006                ; $D373  85 06
  lsr a                          ; $D375  4A
  lsr a                          ; $D376  4A
  lsr a                          ; $D377  4A
  lsr a                          ; $D378  4A
  sta z:_var_000d                ; $D379  85 0D
  lda #$00                       ; $D37B  A9 00
  sta z:_var_0004                ; $D37D  85 04
  sta z:_var_0007                ; $D37F  85 07
  lda #$0F                       ; $D381  A9 0F
  jsr _func_c437                 ; $D383  20 37 C4
  jsr _func_c655                 ; $D386  20 55 C6
  lda #$03                       ; $D389  A9 03
  sta z:_var_00a9                ; $D38B  85 A9
  lda #$A0                       ; $D38D  A9 A0
  sta z:_var_002b_indexed        ; $D38F  85 2B
  jsr _func_c23b                 ; $D391  20 3B C2
  lda #$05                       ; $D394  A9 05
  jmp _func_d464                 ; $D396  4C 64 D4

_label_d399:
  lda #$00                       ; $D399  A9 00

_label_d39b:
  ldx #$02                       ; $D39B  A2 02
  ldy z:_var_001f                ; $D39D  A4 1F
  cpy #$02                       ; $D39F  C0 02
  bne _label_d3a5                ; $D3A1  D0 02
  ldx #$09                       ; $D3A3  A2 09

_label_d3a5:
  jsr _func_c62e                 ; $D3A5  20 2E C6
  lda #$00                       ; $D3A8  A9 00
  jmp _func_d464                 ; $D3AA  4C 64 D4

_label_d3ad:
  and #$01                       ; $D3AD  29 01
  bne _label_d3b4                ; $D3AF  D0 03
  jmp _func_c6cc                 ; $D3B1  4C CC C6

_label_d3b4:
  ldx #$09                       ; $D3B4  A2 09
  lda #$D6                       ; $D3B6  A9 D6
  ldy z:_var_001f                ; $D3B8  A4 1F
  cpy #$02                       ; $D3BA  C0 02
  bne _label_d3c0                ; $D3BC  D0 02
  lda #$D4                       ; $D3BE  A9 D4

_label_d3c0:
  sta a:_var_0501_indexed,X      ; $D3C0  9D 01 05
  dex                            ; $D3C3  CA
  bpl _label_d3c0                ; $D3C4  10 FA
  jmp _label_c6e9                ; $D3C6  4C E9 C6

_label_d3c9:
  lda z:_var_002b_indexed        ; $D3C9  A5 2B
  bne _label_d3d1                ; $D3CB  D0 04
  lda #$04                       ; $D3CD  A9 04
  bne _label_d39b                ; $D3CF  D0 CA

_label_d3d1:
  rts                            ; $D3D1  60

_func_d3d2:
  lda z:WhiteBoxVisible                ; $D3D2  A5 27
  bne _label_d427                ; $D3D4  D0 51
  inc z:_var_009b                ; $D3D6  E6 9B
  ldy #$00                       ; $D3D8  A0 00
  jsr _func_d3df                 ; $D3DA  20 DF D3
  ldy #$50                       ; $D3DD  A0 50

_func_d3df:
  lda a:TargetOneType,Y      ; $D3DF  B9 00 03
  beq _label_d427                ; $D3E2  F0 43
  lda a:TargetOneState,Y      ; $D3E4  B9 01 03
  cmp #$03                       ; $D3E7  C9 03
  beq _label_d3fb                ; $D3E9  F0 10
  cmp #$08                       ; $D3EB  C9 08
  bne _label_d427                ; $D3ED  D0 38
  ldx a:_var_030b_indexed,Y      ; $D3EF  BE 0B 03
  lda a:_var_03ef_indexed,X      ; $D3F2  BD EF 03
  beq _label_d409                ; $D3F5  F0 12
  ldx #$D3                       ; $D3F7  A2 D3
  bne _label_d40b                ; $D3F9  D0 10

_label_d3fb:
  lda z:_var_009b                ; $D3FB  A5 9B
  and #$0F                       ; $D3FD  29 0F
  bne _label_d427                ; $D3FF  D0 26
  ldx #$B7                       ; $D401  A2 B7
  lda z:_var_009b                ; $D403  A5 9B
  and #$10                       ; $D405  29 10
  beq _label_d413                ; $D407  F0 0A

_label_d409:
  ldx #$D4                       ; $D409  A2 D4

_label_d40b:
  lda z:_var_001f                ; $D40B  A5 1F
  cmp #$02                       ; $D40D  C9 02
  beq _label_d413                ; $D40F  F0 02
  inx                            ; $D411  E8
  inx                            ; $D412  E8

_label_d413:
  stx a:_var_0501_indexed        ; $D413  8E 01 05
  ldx #$11                       ; $D416  A2 11
  stx a:_var_0500_indexed        ; $D418  8E 00 05
  lda a:_var_030b_indexed,Y      ; $D41B  B9 0B 03
  clc                            ; $D41E  18
  adc #$4B                       ; $D41F  69 4B
  tax                            ; $D421  AA
  ldy #$23                       ; $D422  A0 23
  jmp _func_c71d                 ; $D424  4C 1D C7

_label_d427:
  rts                            ; $D427  60

_func_d428:
  lda z:TargetActive                ; $D428  A5 B9
  beq _label_d427                ; $D42A  F0 FB
  lda z:RemainingShots                ; $D42C  A5 BA
  bne _label_d427                ; $D42E  D0 F7
  lda z:_var_009a                ; $D430  A5 9A
  and #$07                       ; $D432  29 07
  bne _label_d461                ; $D434  D0 2B
  lda z:WhiteBoxVisible                ; $D436  A5 27
  bne _label_d427                ; $D438  D0 ED
  lda z:_var_009a                ; $D43A  A5 9A
  and #$08                       ; $D43C  29 08
  beq _func_d446                 ; $D43E  F0 06
  lda #$B7                       ; $D440  A9 B7
  tax                            ; $D442  AA
  tay                            ; $D443  A8
  bne _label_d44c                ; $D444  D0 06

_func_d446:
  lda #$DA                       ; $D446  A9 DA
  ldx #$DB                       ; $D448  A2 DB
  ldy #$DC                       ; $D44A  A0 DC

_label_d44c:
  sta a:_var_0501_indexed        ; $D44C  8D 01 05
  stx a:_var_0502                ; $D44F  8E 02 05
  sty a:$0503                    ; $D452  8C 03 05
  lda #$13                       ; $D455  A9 13
  sta a:_var_0500_indexed        ; $D457  8D 00 05
  ldx #$63                       ; $D45A  A2 63
  ldy #$23                       ; $D45C  A0 23
  jsr _func_c71d                 ; $D45E  20 1D C7

_label_d461:
  inc z:_var_009a                ; $D461  E6 9A
  rts                            ; $D463  60

_func_d464:
  pha                            ; $D464  48
  jsr _func_c5d9                 ; $D465  20 D9 C5
  jsr _func_f56c                 ; $D468  20 6C F5
  pla                            ; $D46B  68

_label_d46c:
  sta z:_var_001b                ; $D46C  85 1B
  beq _label_d4bc                ; $D46E  F0 4C
  asl a                          ; $D470  0A
  tax                            ; $D471  AA
  lda a:_data_ec38_indexed,X     ; $D472  BD 38 EC
  sta z:_var_0014_indexed        ; $D475  85 14
  lda a:_data_ec39_indexed,X     ; $D477  BD 39 EC
  sta z:_var_0015                ; $D47A  85 15
  ldy #$01                       ; $D47C  A0 01
  lda (_var_0014_indexed),Y      ; $D47E  B1 14
  sta z:_var_000f                ; $D480  85 0F
  ldx #$00                       ; $D482  A2 00
  iny                            ; $D484  C8

_label_d485:
  lda (_var_0014_indexed),Y      ; $D485  B1 14
  sta a:_var_0500_indexed,X      ; $D487  9D 00 05
  iny                            ; $D48A  C8
  inx                            ; $D48B  E8
  dec z:_var_000f                ; $D48C  C6 0F
  bne _label_d485                ; $D48E  D0 F5
  lda z:_var_001b                ; $D490  A5 1B
  cmp #$01                       ; $D492  C9 01
  bne _label_d4ab                ; $D494  D0 15
  lda z:LevelNumber                ; $D496  A5 C1
  lsr a                          ; $D498  4A
  lsr a                          ; $D499  4A
  lsr a                          ; $D49A  4A
  lsr a                          ; $D49B  4A
  beq _label_d4a1                ; $D49C  F0 03
  sta a:$0518                    ; $D49E  8D 18 05

_label_d4a1:
  lda z:LevelNumber                ; $D4A1  A5 C1
  and #$0F                       ; $D4A3  29 0F
  sta a:$0519                    ; $D4A5  8D 19 05
  jmp _label_d4cf                ; $D4A8  4C CF D4

_label_d4ab:
  cmp #$05                       ; $D4AB  C9 05
  bne _label_d4cf                ; $D4AD  D0 20
  lda z:_var_000c                ; $D4AF  A5 0C
  sta a:$0521                    ; $D4B1  8D 21 05
  lda z:_var_000d                ; $D4B4  A5 0D
  sta a:$0522                    ; $D4B6  8D 22 05
  jmp _label_d4cf                ; $D4B9  4C CF D4

_label_d4bc:
  ldx #$44                       ; $D4BC  A2 44
  lda #$24                       ; $D4BE  A9 24

_label_d4c0:
  sta a:_var_0501_indexed,X      ; $D4C0  9D 01 05
  dex                            ; $D4C3  CA
  bpl _label_d4c0                ; $D4C4  10 FA
  lda #$6B                       ; $D4C6  A9 6B
  sta a:_var_0500_indexed        ; $D4C8  8D 00 05
  ldx #$CB                       ; $D4CB  A2 CB
  bne _label_d4d4                ; $D4CD  D0 05

_label_d4cf:
  ldy #$00                       ; $D4CF  A0 00
  lda (_var_0014_indexed),Y      ; $D4D1  B1 14
  tax                            ; $D4D3  AA

_label_d4d4:
  ldy #$20                       ; $D4D4  A0 20
  jmp _func_c71d                 ; $D4D6  4C 1D C7

_func_d4d9:
  jsr _func_c23b                 ; $D4D9  20 3B C2
  jsr _func_c64b                 ; $D4DC  20 4B C6
  jmp _label_c637                ; $D4DF  4C 37 C6

_func_d4e2:
  lda #$01                       ; $D4E2  A9 01
  bne _label_d500                ; $D4E4  D0 1A

_func_d4e6:
  lda #$02                       ; $D4E6  A9 02
  bne _label_d500                ; $D4E8  D0 16

_func_d4ea:
  lda #$04                       ; $D4EA  A9 04
  bne _label_d500                ; $D4EC  D0 12

_func_d4ee:
  lda #$08                       ; $D4EE  A9 08
  bne _label_d500                ; $D4F0  D0 0E

_func_d4f2:
  lda #$10                       ; $D4F2  A9 10
  bne _label_d500                ; $D4F4  D0 0A

_func_d4f6:
  lda #$20                       ; $D4F6  A9 20
  bne _label_d500                ; $D4F8  D0 06

_func_d4fa:
  lda #$40                       ; $D4FA  A9 40
  bne _label_d500                ; $D4FC  D0 02

_func_d4fe:
  lda #$80                       ; $D4FE  A9 80

_label_d500:
  ora z:_var_00f0                ; $D500  05 F0
  sta z:_var_00f0                ; $D502  85 F0
  rts                            ; $D504  60

_label_d505:
  lda #$01                       ; $D505  A9 01
  bne _label_d523                ; $D507  D0 1A

_func_d509:
  lda #$02                       ; $D509  A9 02
  bne _label_d523                ; $D50B  D0 16

_func_d50d:
  lda #$04                       ; $D50D  A9 04
  bne _label_d523                ; $D50F  D0 12

_func_d511:
  lda #$08                       ; $D511  A9 08
  bne _label_d523                ; $D513  D0 0E

_label_d515:
  lda #$10                       ; $D515  A9 10
  bne _label_d523                ; $D517  D0 0A

_func_d519:
  lda #$20                       ; $D519  A9 20
  bne _label_d523                ; $D51B  D0 06

_func_d51d:
  lda #$40                       ; $D51D  A9 40
  bne _label_d523                ; $D51F  D0 02

_label_d521:
  lda #$80                       ; $D521  A9 80

_label_d523:
  ora z:_var_00f1                ; $D523  05 F1
  sta z:_var_00f1                ; $D525  85 F1
  rts                            ; $D527  60

_func_d528:
  lda #$01                       ; $D528  A9 01
  bne _label_d546                ; $D52A  D0 1A

_func_d52c:
  lda #$02                       ; $D52C  A9 02
  bne _label_d546                ; $D52E  D0 16
  lda #$04                       ; $D530  A9 04
  bne _label_d546                ; $D532  D0 12

_func_d534:
  lda #$08                       ; $D534  A9 08
  bne _label_d546                ; $D536  D0 0E

_func_d538:
  lda #$10                       ; $D538  A9 10
  bne _label_d546                ; $D53A  D0 0A

_func_d53c:
  lda #$20                       ; $D53C  A9 20
  bne _label_d546                ; $D53E  D0 06
  lda #$40                       ; $D540  A9 40
  bne _label_d546                ; $D542  D0 02

_func_d544:
  lda #$80                       ; $D544  A9 80

_label_d546:
  ora z:_var_00f2                ; $D546  05 F2
  sta z:_var_00f2                ; $D548  85 F2
  rts                            ; $D54A  60

_label_d54b:
  jsr _func_c5d9                 ; $D54B  20 D9 C5
  ldx #$6C                       ; $D54E  A2 6C
  ldy #$E2                       ; $D550  A0 E2
  jsr _func_c617                 ; $D552  20 17 C6
  lda #$03                       ; $D555  A9 03
  sta z:_var_0023                ; $D557  85 23
  lda #$00                       ; $D559  A9 00
  sta z:_var_009d                ; $D55B  85 9D
  lda #$09                       ; $D55D  A9 09
  sta z:_var_0025                ; $D55F  85 25
  jsr _func_c3c1                 ; $D561  20 C1 C3
  jsr _func_c5ee                 ; $D564  20 EE C5
  jmp _label_d505                ; $D567  4C 05 D5

_label_d56a:
  jsr _func_d4d9                 ; $D56A  20 D9 D4
  jsr _func_d2a4                 ; $D56D  20 A4 D2
  jsr _func_c793                 ; $D570  20 93 C7
  jsr _func_c7b3                 ; $D573  20 B3 C7
  jsr _func_c5d9                 ; $D576  20 D9 C5
  jsr _func_f56c                 ; $D579  20 6C F5
  lda #$01                       ; $D57C  A9 01
  sta z:NextLevelCountdown                ; $D57E  85 BE
  lda #$03                       ; $D580  A9 03
  sta z:RemainingShots                ; $D582  85 BA
  jsr _func_c6f5                 ; $D584  20 F5 C6
  jsr _func_c6cc                 ; $D587  20 CC C6
  lda #$06                       ; $D58A  A9 06
  sta z:_var_009d                ; $D58C  85 9D
  lda #$0D                       ; $D58E  A9 0D
  sta z:_var_0025                ; $D590  85 25
  rts                            ; $D592  60

_label_d593:
  lda #$01                       ; $D593  A9 01
  sta a:TargetOneType        ; $D595  8D 00 03
  sta a:_var_0350                ; $D598  8D 50 03
  sta a:TargetOneState        ; $D59B  8D 01 03
  sta a:_var_0351                ; $D59E  8D 51 03
  lda #$30                       ; $D5A1  A9 30
  ldx z:LevelNumber                ; $D5A3  A6 C1
  cpx #$10                       ; $D5A5  E0 10
  bcs _label_d5ad                ; $D5A7  B0 04
  dex                            ; $D5A9  CA
  lda a:_data_ec17_indexed,X     ; $D5AA  BD 17 EC

_label_d5ad:
  sta z:_var_00a8                ; $D5AD  85 A8
  lda #$80                       ; $D5AF  A9 80
  sta z:_var_00a6                ; $D5B1  85 A6
  lda #$01                       ; $D5B3  A9 01
  sta z:NextLevelCountdown                ; $D5B5  85 BE
  lda #$03                       ; $D5B7  A9 03
  sta z:RemainingShots                ; $D5B9  85 BA
  lda #$02                       ; $D5BB  A9 02
  sta z:TargetFinishedFalling                ; $D5BD  85 BC
  lda #$00                       ; $D5BF  A9 00
  sta z:_var_00b5                ; $D5C1  85 B5
  sta z:TargetActive                ; $D5C3  85 B9
  sta z:TargetShot                ; $D5C5  85 BD
  jsr _func_c6f5                 ; $D5C7  20 F5 C6
  jsr _func_c6cc                 ; $D5CA  20 CC C6
  lda #$0B                       ; $D5CD  A9 0B
  sta z:_var_0025                ; $D5CF  85 25
  rts                            ; $D5D1  60

_label_d5d2:
  jsr _func_d131                 ; $D5D2  20 31 D1
  jsr _func_d160                 ; $D5D5  20 60 D1
  jsr _func_d5ee                 ; $D5D8  20 EE D5
  jsr _func_c6f5                 ; $D5DB  20 F5 C6
  jsr _func_d3d2                 ; $D5DE  20 D2 D3
  jsr _func_c6c4                 ; $D5E1  20 C4 C6
  jsr _func_cfba                 ; $D5E4  20 BA CF
  jsr _func_d428                 ; $D5E7  20 28 D4
  nop                            ; $D5EA  EA
  nop                            ; $D5EB  EA
  nop                            ; $D5EC  EA
  rts                            ; $D5ED  60

_func_d5ee:
  lda a:TargetOneType        ; $D5EE  AD 00 03
  beq _label_d600                ; $D5F1  F0 0D
  ldy #$00                       ; $D5F3  A0 00
  sty z:_var_00a1                ; $D5F5  84 A1
  jsr _func_c5f7                 ; $D5F7  20 F7 C5
  jsr _func_d652                 ; $D5FA  20 52 D6
  jsr _func_c607                 ; $D5FD  20 07 C6

_label_d600:
  lda a:_var_0350                ; $D600  AD 50 03
  beq _label_d612                ; $D603  F0 0D
  ldy #$50                       ; $D605  A0 50
  inc z:_var_00a1                ; $D607  E6 A1
  jsr _func_c5f7                 ; $D609  20 F7 C5
  jsr _func_d652                 ; $D60C  20 52 D6
  jsr _func_c607                 ; $D60F  20 07 C6

_label_d612:
  lda z:TargetFinishedFalling                ; $D612  A5 BC
  bne _label_d64b                ; $D614  D0 35
  ldx a:TargetOneState        ; $D616  AE 01 03
  ldy a:_var_0351                ; $D619  AC 51 03
  cpx #$03                       ; $D61C  E0 03
  beq _label_d627                ; $D61E  F0 07
  cpy #$03                       ; $D620  C0 03
  beq _label_d627                ; $D622  F0 03
  jsr _func_d4fe                 ; $D624  20 FE D4

_label_d627:
  cpx #$00                       ; $D627  E0 00
  bne _label_d651                ; $D629  D0 26
  cpy #$00                       ; $D62B  C0 00
  bne _label_d651                ; $D62D  D0 22
  jsr _func_d446                 ; $D62F  20 46 D4
  lda #$00                       ; $D632  A9 00
  sta z:TargetActive                ; $D634  85 B9
  lda z:CurrentActiveDuckTarget                ; $D636  A5 BB
  cmp #$0A                       ; $D638  C9 0A
  beq _label_d640                ; $D63A  F0 04
  lda #$0A                       ; $D63C  A9 0A
  bne _label_d646                ; $D63E  D0 06

_label_d640:
  lda #$00                       ; $D640  A9 00
  sta z:_var_00a9                ; $D642  85 A9
  lda #$0C                       ; $D644  A9 0C

_label_d646:
  sta z:_var_0025                ; $D646  85 25
  jmp _func_c23b                 ; $D648  4C 3B C2

_label_d64b:
  lda z:_var_00a6                ; $D64B  A5 A6
  beq _label_d651                ; $D64D  F0 02
  dec z:_var_00a6                ; $D64F  C6 A6

_label_d651:
  rts                            ; $D651  60

_func_d652:
  lda z:CurrentSpritePhase                ; $D652  A5 31
  jsr _jump_engine_c35e          ; $D654  20 5E C3

  .word _label_c5e0              ; $D657  E0 C5
  .word _label_d669              ; $D659  69 D6
  .word _label_d678              ; $D65B  78 D6
  .word _label_d6d5              ; $D65D  D5 D6
  .word _label_d752              ; $D65F  52 D7
  .word _label_d78f              ; $D661  8F D7
  .word _label_c5e0              ; $D663  E0 C5
  .word _label_c5e0              ; $D665  E0 C5
  .word _label_d7c5              ; $D667  C5 D7

_label_d669:
  ldx #$4F                       ; $D669  A2 4F

_label_d66b:
  lda a:_data_e8da_indexed,X     ; $D66B  BD DA E8
  sta z:_var_0030_indexed,X      ; $D66E  95 30
  dex                            ; $D670  CA
  bpl _label_d66b                ; $D671  10 F8
  lda #$01                       ; $D673  A9 01
  sta z:_var_00a7                ; $D675  85 A7
  rts                            ; $D677  60

_label_d678:
  lda z:_var_00a6                ; $D678  A5 A6
  bne _label_d6d4                ; $D67A  D0 58
  lda #$01                       ; $D67C  A9 01
  sta z:TargetActive                ; $D67E  85 B9
  jsr _func_c588                 ; $D680  20 88 C5
  and #$3F                       ; $D683  29 3F
  tay                            ; $D685  A8
  iny                            ; $D686  C8
  sty z:_var_00a6                ; $D687  84 A6
  jsr _func_c588                 ; $D689  20 88 C5
  and #$0F                       ; $D68C  29 0F
  cmp z:_var_009c                ; $D68E  C5 9C
  bne _label_d697                ; $D690  D0 05
  clc                            ; $D692  18
  adc #$01                       ; $D693  69 01
  and #$0F                       ; $D695  29 0F

_label_d697:
  sta z:_var_009c                ; $D697  85 9C
  asl a                          ; $D699  0A
  sta z:_var_000c                ; $D69A  85 0C
  asl a                          ; $D69C  0A
  clc                            ; $D69D  18
  adc z:_var_000c                ; $D69E  65 0C
  tax                            ; $D6A0  AA
  lda a:_data_e968_indexed,X     ; $D6A1  BD 68 E9
  sta z:_var_0044_indexed        ; $D6A4  85 44
  lda a:_data_e969_indexed,X     ; $D6A6  BD 69 E9
  sta z:_var_0043_indexed        ; $D6A9  85 43
  lda a:_data_e96a_indexed,X     ; $D6AB  BD 6A E9
  sta z:DuckDirection                ; $D6AE  85 4A
  lda a:_data_e96b_indexed,X     ; $D6B0  BD 6B E9
  sta z:_var_0042_indexed        ; $D6B3  85 42
  lda a:_data_e96c_indexed,X     ; $D6B5  BD 6C E9
  sta z:_var_0047                ; $D6B8  85 47
  lda a:_data_e96d_indexed,X     ; $D6BA  BD 6D E9
  sta z:_var_004c                ; $D6BD  85 4C
  inc z:CurrentActiveDuckTarget                ; $D6BF  E6 BB
  lda z:CurrentActiveDuckTarget                ; $D6C1  A5 BB
  sta z:DuckNumber                ; $D6C3  85 3B
  dec z:TargetFinishedFalling                ; $D6C5  C6 BC
  lda #$FF                       ; $D6C7  A9 FF
  sta z:_var_005f                ; $D6C9  85 5F
  jsr _func_d53c                 ; $D6CB  20 3C D5
  lda #$05                       ; $D6CE  A9 05
  sta z:_var_0058                ; $D6D0  85 58
  inc z:CurrentSpritePhase                ; $D6D2  E6 31

_label_d6d4:
  rts                            ; $D6D4  60

_label_d6d5:
  lda z:_var_0058                ; $D6D5  A5 58
  beq _label_d6e0                ; $D6D7  F0 07
  dec z:_var_0058                ; $D6D9  C6 58
  bne _label_d6e0                ; $D6DB  D0 03
  jsr _func_d4f6                 ; $D6DD  20 F6 D4

_label_d6e0:
  lda z:_var_004c                ; $D6E0  A5 4C
  bmi _label_d6ec                ; $D6E2  30 08
  lda z:_var_0049                ; $D6E4  A5 49
  lsr a                          ; $D6E6  4A
  lsr a                          ; $D6E7  4A
  cmp #$07                       ; $D6E8  C9 07
  bcc _label_d6ee                ; $D6EA  90 02

_label_d6ec:
  lda #$07                       ; $D6EC  A9 07

_label_d6ee:
  cmp z:_var_005f                ; $D6EE  C5 5F
  beq _label_d6fd                ; $D6F0  F0 0B
  sta z:_var_005f                ; $D6F2  85 5F
  clc                            ; $D6F4  18
  adc z:_var_00a8                ; $D6F5  65 A8
  tax                            ; $D6F7  AA
  lda a:_data_e9c8_indexed,X     ; $D6F8  BD C8 E9
  sta z:_var_005e                ; $D6FB  85 5E

_label_d6fd:
  jsr _func_d81b                 ; $D6FD  20 1B D8

_label_d700:
  pha                            ; $D700  48
  jsr _func_d8ae                 ; $D701  20 AE D8
  pla                            ; $D704  68
  sec                            ; $D705  38
  sbc #$01                       ; $D706  E9 01
  bne _label_d700                ; $D708  D0 F6
  lda z:TargetFlyingAway                ; $D70A  A5 4E
  bmi _label_d74d                ; $D70C  30 3F
  lda z:_var_0049                ; $D70E  A5 49
  cmp #$30                       ; $D710  C9 30
  bcs _label_d74d                ; $D712  B0 39
  jsr _func_d82f                 ; $D714  20 2F D8
  lda z:_var_0032                ; $D717  A5 32
  sec                            ; $D719  38
  sbc #$40                       ; $D71A  E9 40
  sta z:_var_0032                ; $D71C  85 32
  lda z:_var_0049                ; $D71E  A5 49
  lsr a                          ; $D720  4A
  tax                            ; $D721  AA
  lda a:_data_e92a_indexed,X     ; $D722  BD 2A E9
  sta z:_var_0035                ; $D725  85 35
  stx z:_var_000c                ; $D727  86 0C
  sec                            ; $D729  38
  sbc #$18                       ; $D72A  E9 18
  sta z:_var_0056                ; $D72C  85 56
  ldx z:LevelNumber                ; $D72E  A6 C1
  lda #$00                       ; $D730  A9 00
  cpx #$12                       ; $D732  E0 12
  bcc _label_d73e                ; $D734  90 08
  lda #$03                       ; $D736  A9 03
  cpx #$23                       ; $D738  E0 23
  bcc _label_d73e                ; $D73A  90 02
  lda #$06                       ; $D73C  A9 06

_label_d73e:
  clc                            ; $D73E  18
  adc z:_var_000c                ; $D73F  65 0C
  tax                            ; $D741  AA
  lda a:_data_e944_indexed,X     ; $D742  BD 44 E9
  sta z:_var_003a                ; $D745  85 3A
  jsr _func_d805                 ; $D747  20 05 D8
  jmp _label_d01b                ; $D74A  4C 1B D0

_label_d74d:
  lda #$08                       ; $D74D  A9 08
  sta z:CurrentSpritePhase                ; $D74F  85 31
  rts                            ; $D751  60

_label_d752:
  ldx z:DuckNumber                ; $D752  A6 3B
  lda #$01                       ; $D754  A9 01
  sta a:_var_03ef_indexed,X      ; $D756  9D EF 03
  sta z:_var_00ad                ; $D759  85 AD
  lda z:_var_0056                ; $D75B  A5 56
  asl a                          ; $D75D  0A
  asl a                          ; $D75E  0A
  tax                            ; $D75F  AA
  ldy #$00                       ; $D760  A0 00

_label_d762:
  lda a:_data_eaf2_indexed,X     ; $D762  BD F2 EA
  sta a:_var_0050_indexed,Y      ; $D765  99 50 00
  inx                            ; $D768  E8
  iny                            ; $D769  C8
  cpy #$04                       ; $D76A  C0 04
  bne _label_d762                ; $D76C  D0 F4
  lda #$00                       ; $D76E  A9 00
  sta z:_var_0057                ; $D770  85 57
  ldx #$00                       ; $D772  A2 00

_label_d774:
  lda z:_var_0032                ; $D774  A5 32
  jsr _func_daa5                 ; $D776  20 A5 DA
  lda z:_var_0033                ; $D779  A5 33
  jsr _func_dab5                 ; $D77B  20 B5 DA
  inx                            ; $D77E  E8
  inx                            ; $D77F  E8
  cpx #$20                       ; $D780  E0 20
  bne _label_d774                ; $D782  D0 F0
  jsr _func_cf56                 ; $D784  20 56 CF
  ldx z:_var_0036                ; $D787  A6 36
  jsr _func_d042                 ; $D789  20 42 D0
  inc z:CurrentSpritePhase                ; $D78C  E6 31
  rts                            ; $D78E  60

_label_d78f:
  jsr _func_d805                 ; $D78F  20 05 D8
  jsr _func_d93a                 ; $D792  20 3A D9
  lda z:_var_0036                ; $D795  A5 36
  sta z:_var_00b4                ; $D797  85 B4
  ldy z:_var_0050_indexed        ; $D799  A4 50
  iny                            ; $D79B  C8
  beq _label_d7a7                ; $D79C  F0 09
  ldx #$00                       ; $D79E  A2 00
  ldy #$0C                       ; $D7A0  A0 0C
  lda z:_var_0054                ; $D7A2  A5 54
  jsr _func_d7ce                 ; $D7A4  20 CE D7

_label_d7a7:
  ldy z:_var_0053                ; $D7A7  A4 53
  iny                            ; $D7A9  C8
  beq _label_d7b5                ; $D7AA  F0 09
  ldx #$10                       ; $D7AC  A2 10
  ldy #$20                       ; $D7AE  A0 20
  lda z:_var_0055                ; $D7B0  A5 55
  jsr _func_d7ce                 ; $D7B2  20 CE D7

_label_d7b5:
  lda z:_var_0057                ; $D7B5  A5 57
  cmp #$02                       ; $D7B7  C9 02
  bne _label_d7be                ; $D7B9  D0 03
  jsr _func_d4ea                 ; $D7BB  20 EA D4

_label_d7be:
  lda #$00                       ; $D7BE  A9 00
  sta z:_var_0054                ; $D7C0  85 54
  sta z:_var_0055                ; $D7C2  85 55
  rts                            ; $D7C4  60

_label_d7c5:
  lda #$00                       ; $D7C5  A9 00
  sta z:CurrentSpritePhase                ; $D7C7  85 31
  ldx z:_var_0036                ; $D7C9  A6 36
  jmp _func_d042                 ; $D7CB  4C 42 D0

_func_d7ce:
  sta z:_var_000d                ; $D7CE  85 0D
  sty z:_var_000c                ; $D7D0  84 0C
  ldy z:_var_00b4                ; $D7D2  A4 B4

_label_d7d4:
  lda z:_var_000d                ; $D7D4  A5 0D
  bne _label_d7dc                ; $D7D6  D0 04
  lda z:_var_0060_indexed,X      ; $D7D8  B5 60
  bne _label_d7e0                ; $D7DA  D0 04

_label_d7dc:
  inx                            ; $D7DC  E8
  jmp _label_d7f9                ; $D7DD  4C F9 D7

_label_d7e0:
  sta a:_var_0200_indexed,Y      ; $D7E0  99 00 02
  iny                            ; $D7E3  C8
  lda a:_data_ea30_indexed,X     ; $D7E4  BD 30 EA
  sta a:_var_0200_indexed,Y      ; $D7E7  99 00 02
  iny                            ; $D7EA  C8
  inx                            ; $D7EB  E8
  lda a:_data_ea30_indexed,X     ; $D7EC  BD 30 EA
  sta a:_var_0200_indexed,Y      ; $D7EF  99 00 02
  iny                            ; $D7F2  C8
  lda z:_var_0060_indexed,X      ; $D7F3  B5 60
  sta a:_var_0200_indexed,Y      ; $D7F5  99 00 02
  iny                            ; $D7F8  C8

_label_d7f9:
  inx                            ; $D7F9  E8
  cpx z:_var_000c                ; $D7FA  E4 0C
  bne _label_d7d4                ; $D7FC  D0 D6
  sty z:_var_00b4                ; $D7FE  84 B4
  tya                            ; $D800  98
  tax                            ; $D801  AA
  jmp _func_d042                 ; $D802  4C 42 D0

_func_d805:
  lda z:_var_00a7                ; $D805  A5 A7
  beq _label_d81a                ; $D807  F0 11
  lda #$00                       ; $D809  A9 00
  sta z:_var_00a7                ; $D80B  85 A7
  ldx z:_var_0036                ; $D80D  A6 36
  jsr _func_d042                 ; $D80F  20 42 D0
  lda #$50                       ; $D812  A9 50
  sta z:_var_0036                ; $D814  85 36
  lda #$9F                       ; $D816  A9 9F
  sta z:_var_0037                ; $D818  85 37

_label_d81a:
  rts                            ; $D81A  60

_func_d81b:
  ldx z:_var_005e                ; $D81B  A6 5E
  lda a:_data_ea00_indexed,X     ; $D81D  BD 00 EA
  pha                            ; $D820  48
  inx                            ; $D821  E8
  txa                            ; $D822  8A
  and #$03                       ; $D823  29 03
  bne _label_d82b                ; $D825  D0 04
  dex                            ; $D827  CA
  dex                            ; $D828  CA
  dex                            ; $D829  CA
  dex                            ; $D82A  CA

_label_d82b:
  stx z:_var_005e                ; $D82B  86 5E
  pla                            ; $D82D  68
  rts                            ; $D82E  60

_func_d82f:
  lda z:_var_004d                ; $D82F  A5 4D
  sec                            ; $D831  38
  sbc #$00                       ; $D832  E9 00
  tay                            ; $D834  A8
  lda z:TargetFlyingAway                ; $D835  A5 4E
  sbc #$10                       ; $D837  E9 10
  tax                            ; $D839  AA
  lda #$3B                       ; $D83A  A9 3B
  jsr _func_d8db                 ; $D83C  20 DB D8
  sty z:_var_0014_indexed        ; $D83F  84 14
  stx z:_var_0015                ; $D841  86 15
  lda z:_var_004d                ; $D843  A5 4D
  sec                            ; $D845  38
  sbc #$00                       ; $D846  E9 00
  tay                            ; $D848  A8
  lda z:TargetFlyingAway                ; $D849  A5 4E
  sbc #$10                       ; $D84B  E9 10
  tax                            ; $D84D  AA
  lda #$E7                       ; $D84E  A9 E7
  jsr _func_d8db                 ; $D850  20 DB D8
  sty z:_var_0012_indexed        ; $D853  84 12
  stx z:_var_0013                ; $D855  86 13
  lda z:_var_0048                ; $D857  A5 48
  sec                            ; $D859  38
  sbc #$00                       ; $D85A  E9 00
  tay                            ; $D85C  A8
  lda z:_var_0049                ; $D85D  A5 49
  sbc #$18                       ; $D85F  E9 18
  tax                            ; $D861  AA
  lda #$7F                       ; $D862  A9 7F
  jsr _func_d8db                 ; $D864  20 DB D8
  clc                            ; $D867  18
  tya                            ; $D868  98
  adc #$4F                       ; $D869  69 4F
  tay                            ; $D86B  A8
  txa                            ; $D86C  8A
  adc #$23                       ; $D86D  69 23
  tax                            ; $D86F  AA
  tya                            ; $D870  98
  sec                            ; $D871  38
  sbc z:_var_0014_indexed        ; $D872  E5 14
  sta z:_var_0093                ; $D874  85 93
  txa                            ; $D876  8A
  sbc z:_var_0015                ; $D877  E5 15
  cmp #$50                       ; $D879  C9 50
  ror a                          ; $D87B  6A
  sta z:_var_0094                ; $D87C  85 94
  ror z:_var_0093                ; $D87E  66 93
  ldy z:_var_0091                ; $D880  A4 91
  ldx z:$92                      ; $D882  A6 92
  lda #$6C                       ; $D884  A9 6C
  jsr _func_d8db                 ; $D886  20 DB D8
  clc                            ; $D889  18
  tya                            ; $D88A  98
  adc z:_var_0012_indexed        ; $D88B  65 12
  tay                            ; $D88D  A8
  txa                            ; $D88E  8A
  adc z:_var_0013                ; $D88F  65 13
  tax                            ; $D891  AA
  jsr _func_d907                 ; $D892  20 07 D9
  sbc #$00                       ; $D895  E9 00
  eor #$7F                       ; $D897  49 7F
  sta z:_var_0032                ; $D899  85 32
  lda z:_var_0043_indexed        ; $D89B  A5 43
  sec                            ; $D89D  38
  sbc #$00                       ; $D89E  E9 00
  tay                            ; $D8A0  A8
  lda z:_var_0044_indexed        ; $D8A1  A5 44
  sbc #$09                       ; $D8A3  E9 09
  tax                            ; $D8A5  AA
  jsr _func_d907                 ; $D8A6  20 07 D9
  eor #$80                       ; $D8A9  49 80
  sta z:_var_0033                ; $D8AB  85 33
  rts                            ; $D8AD  60

_func_d8ae:
  lda #$0F                       ; $D8AE  A9 0F

_label_d8b0:
  sec                            ; $D8B0  38
  sbc #$05                       ; $D8B1  E9 05
  tax                            ; $D8B3  AA
  ldy #$00                       ; $D8B4  A0 00
  lda z:_var_0040_indexed,X      ; $D8B6  B5 40
  bpl _label_d8bb                ; $D8B8  10 01
  dey                            ; $D8BA  88

_label_d8bb:
  clc                            ; $D8BB  18
  adc z:_var_0041_indexed,X      ; $D8BC  75 41
  sta z:_var_0041_indexed,X      ; $D8BE  95 41
  sta z:_var_0015                ; $D8C0  85 15
  tya                            ; $D8C2  98
  ldy #$00                       ; $D8C3  A0 00
  adc z:_var_0042_indexed,X      ; $D8C5  75 42
  sta z:_var_0042_indexed,X      ; $D8C7  95 42
  bpl _label_d8cc                ; $D8C9  10 01
  dey                            ; $D8CB  88

_label_d8cc:
  asl z:_var_0015                ; $D8CC  06 15
  adc z:_var_0043_indexed,X      ; $D8CE  75 43
  sta z:_var_0043_indexed,X      ; $D8D0  95 43
  tya                            ; $D8D2  98
  adc z:_var_0044_indexed,X      ; $D8D3  75 44
  sta z:_var_0044_indexed,X      ; $D8D5  95 44
  txa                            ; $D8D7  8A
  bne _label_d8b0                ; $D8D8  D0 D6
  rts                            ; $D8DA  60

_func_d8db:
  sty z:_var_0010_indexed        ; $D8DB  84 10
  stx z:_var_0011                ; $D8DD  86 11
  sta z:_var_0095                ; $D8DF  85 95
  lda #$00                       ; $D8E1  A9 00
  sta z:_var_0096                ; $D8E3  85 96
  sta z:_var_0097                ; $D8E5  85 97
  ldx #$08                       ; $D8E7  A2 08

_label_d8e9:
  ror z:_var_0095                ; $D8E9  66 95
  bcc _label_d8fa                ; $D8EB  90 0D
  clc                            ; $D8ED  18
  lda z:_var_0096                ; $D8EE  A5 96
  adc z:_var_0010_indexed        ; $D8F0  65 10
  sta z:_var_0096                ; $D8F2  85 96
  lda z:_var_0097                ; $D8F4  A5 97
  adc z:_var_0011                ; $D8F6  65 11
  sta z:_var_0097                ; $D8F8  85 97

_label_d8fa:
  asl a                          ; $D8FA  0A
  ror z:_var_0097                ; $D8FB  66 97
  ror z:_var_0096                ; $D8FD  66 96
  dex                            ; $D8FF  CA
  bne _label_d8e9                ; $D900  D0 E7
  ldy z:_var_0096                ; $D902  A4 96
  ldx z:_var_0097                ; $D904  A6 97
  rts                            ; $D906  60

_func_d907:
  sty z:_var_0096                ; $D907  84 96
  stx z:_var_0097                ; $D909  86 97
  lda #$00                       ; $D90B  A9 00
  sta z:_var_0095                ; $D90D  85 95
  ldx #$07                       ; $D90F  A2 07
  clc                            ; $D911  18
  lda z:_var_0096                ; $D912  A5 96
  adc z:_var_0093                ; $D914  65 93
  tay                            ; $D916  A8
  lda z:_var_0097                ; $D917  A5 97
  adc z:_var_0094                ; $D919  65 94

_label_d91b:
  bcc _label_d921                ; $D91B  90 04
  sty z:_var_0096                ; $D91D  84 96
  sta z:_var_0097                ; $D91F  85 97

_label_d921:
  rol z:_var_0095                ; $D921  26 95
  rol z:_var_0096                ; $D923  26 96
  rol z:_var_0097                ; $D925  26 97
  sec                            ; $D927  38
  lda z:_var_0096                ; $D928  A5 96
  sbc z:_var_0093                ; $D92A  E5 93
  tay                            ; $D92C  A8
  lda z:_var_0097                ; $D92D  A5 97
  sbc z:_var_0094                ; $D92F  E5 94
  dex                            ; $D931  CA
  bpl _label_d91b                ; $D932  10 E7
  bcs _label_d937                ; $D934  B0 01
  dex                            ; $D936  CA

_label_d937:
  lda z:_var_0095                ; $D937  A5 95
  rts                            ; $D939  60

_func_d93a:
  inc z:_var_0057                ; $D93A  E6 57
  ldy z:_var_0050_indexed        ; $D93C  A4 50
  cpy #$FF                       ; $D93E  C0 FF
  beq _label_d977                ; $D940  F0 35
  inc z:_var_0050_indexed        ; $D942  E6 50
  lda a:_data_ea50_indexed,Y     ; $D944  B9 50 EA
  sta z:_var_000c                ; $D947  85 0C
  sta z:_var_000f                ; $D949  85 0F
  cmp #$AA                       ; $D94B  C9 AA
  beq _label_d9b3                ; $D94D  F0 64
  cmp #$BB                       ; $D94F  C9 BB
  beq _label_d9ba                ; $D951  F0 67
  lda z:_var_0057                ; $D953  A5 57
  cmp z:$51                      ; $D955  C5 51
  beq _label_d9c7                ; $D957  F0 6E

_label_d959:
  ldx #$00                       ; $D959  A2 00

_label_d95b:
  stx z:_var_000d                ; $D95B  86 0D
  lda a:_data_eb22_indexed,X     ; $D95D  BD 22 EB
  sta z:_var_000e                ; $D960  85 0E
  txa                            ; $D962  8A
  asl a                          ; $D963  0A
  tax                            ; $D964  AA
  lda z:_var_0060_indexed,X      ; $D965  B5 60
  beq _label_d970                ; $D967  F0 07
  lda z:_var_0061_indexed,X      ; $D969  B5 61
  beq _label_d970                ; $D96B  F0 03
  jsr _func_d9f6                 ; $D96D  20 F6 D9

_label_d970:
  ldx z:_var_000d                ; $D970  A6 0D
  inx                            ; $D972  E8
  cpx #$06                       ; $D973  E0 06
  bne _label_d95b                ; $D975  D0 E4

_label_d977:
  ldy z:_var_0053                ; $D977  A4 53
  cpy #$FF                       ; $D979  C0 FF
  beq _label_d9e2                ; $D97B  F0 65
  inc z:_var_0053                ; $D97D  E6 53
  lda a:_data_ea8f_indexed,Y     ; $D97F  B9 8F EA
  sta z:_var_000c                ; $D982  85 0C
  cmp #$AA                       ; $D984  C9 AA
  beq _label_d9ce                ; $D986  F0 46
  cmp #$BB                       ; $D988  C9 BB
  beq _label_d9d5                ; $D98A  F0 49
  lda a:_data_eac2_indexed,Y     ; $D98C  B9 C2 EA
  sta z:_var_000f                ; $D98F  85 0F

_label_d991:
  ldx #$00                       ; $D991  A2 00

_label_d993:
  stx z:_var_000d                ; $D993  86 0D
  lda a:_data_eb28_indexed,X     ; $D995  BD 28 EB
  sta z:_var_000e                ; $D998  85 0E
  txa                            ; $D99A  8A
  asl a                          ; $D99B  0A
  clc                            ; $D99C  18
  adc #$10                       ; $D99D  69 10
  tax                            ; $D99F  AA
  lda z:_var_0060_indexed,X      ; $D9A0  B5 60
  beq _label_d9ab                ; $D9A2  F0 07
  lda z:_var_0061_indexed,X      ; $D9A4  B5 61
  beq _label_d9ab                ; $D9A6  F0 03
  jsr _func_d9f6                 ; $D9A8  20 F6 D9

_label_d9ab:
  ldx z:_var_000d                ; $D9AB  A6 0D
  inx                            ; $D9AD  E8
  cpx #$08                       ; $D9AE  E0 08
  bne _label_d993                ; $D9B0  D0 E1
  rts                            ; $D9B2  60

_label_d9b3:
  lda #$FF                       ; $D9B3  A9 FF
  sta z:_var_0050_indexed        ; $D9B5  85 50
  jmp _label_d977                ; $D9B7  4C 77 D9

_label_d9ba:
  lda #$01                       ; $D9BA  A9 01
  sta z:_var_0054                ; $D9BC  85 54
  lda #$00                       ; $D9BE  A9 00
  sta z:_var_000c                ; $D9C0  85 0C
  sta z:_var_000f                ; $D9C2  85 0F
  jmp _label_d959                ; $D9C4  4C 59 D9

_label_d9c7:
  lda z:$52                      ; $D9C7  A5 52
  sta z:_var_0053                ; $D9C9  85 53
  jmp _label_d959                ; $D9CB  4C 59 D9

_label_d9ce:
  lda #$FF                       ; $D9CE  A9 FF
  sta z:_var_0053                ; $D9D0  85 53
  jmp _label_d9e2                ; $D9D2  4C E2 D9

_label_d9d5:
  lda #$01                       ; $D9D5  A9 01
  sta z:_var_0055                ; $D9D7  85 55
  lda #$00                       ; $D9D9  A9 00
  sta z:_var_000c                ; $D9DB  85 0C
  sta z:_var_000f                ; $D9DD  85 0F
  jmp _label_d991                ; $D9DF  4C 91 D9

_label_d9e2:
  lda z:_var_0050_indexed        ; $D9E2  A5 50
  cmp #$FF                       ; $D9E4  C9 FF
  bne _label_d9f5                ; $D9E6  D0 0D
  lda z:_var_0053                ; $D9E8  A5 53
  cmp #$FF                       ; $D9EA  C9 FF
  bne _label_d9f5                ; $D9EC  D0 07
  jsr _func_cff9                 ; $D9EE  20 F9 CF
  lda #$08                       ; $D9F1  A9 08
  sta z:CurrentSpritePhase                ; $D9F3  85 31

_label_d9f5:
  rts                            ; $D9F5  60

_func_d9f6:
  lda z:_var_0057                ; $D9F6  A5 57
  and #$03                       ; $D9F8  29 03
  sta z:_var_001b                ; $D9FA  85 1B
  lda z:_var_000e                ; $D9FC  A5 0E
  jsr _jump_engine_c35e          ; $D9FE  20 5E C3

  .word _label_c5e0              ; $DA01  E0 C5
  .word _label_da21              ; $DA03  21 DA
  .word _label_da2e              ; $DA05  2E DA
  .word _label_da38              ; $DA07  38 DA
  .word _func_da40               ; $DA09  40 DA
  .word _label_da45              ; $DA0B  45 DA
  .word _label_da4d              ; $DA0D  4D DA
  .word _label_da57              ; $DA0F  57 DA
  .word _label_c5e0              ; $DA11  E0 C5
  .word _label_da61              ; $DA13  61 DA
  .word _label_da6c              ; $DA15  6C DA
  .word _label_da7d              ; $DA17  7D DA
  .word _func_da75               ; $DA19  75 DA
  .word _label_da85              ; $DA1B  85 DA
  .word _label_da90              ; $DA1D  90 DA
  .word _label_da9a              ; $DA1F  9A DA

_label_da21:
  lda z:_var_000f                ; $DA21  A5 0F
  jsr _func_dab5                 ; $DA23  20 B5 DA

_func_da26:
  lda z:_var_000c                ; $DA26  A5 0C
  jsr _func_d12b                 ; $DA28  20 2B D1
  jmp _func_daa5                 ; $DA2B  4C A5 DA

_label_da2e:
  lda z:_var_001b                ; $DA2E  A5 1B
  beq _func_da26                 ; $DA30  F0 F4
  jsr _func_da26                 ; $DA32  20 26 DA
  jmp _func_da40                 ; $DA35  4C 40 DA

_label_da38:
  lda z:_var_000f                ; $DA38  A5 0F
  jsr _func_d12b                 ; $DA3A  20 2B D1
  jsr _func_daa5                 ; $DA3D  20 A5 DA

_func_da40:
  lda z:_var_000c                ; $DA40  A5 0C
  jmp _func_dab5                 ; $DA42  4C B5 DA

_label_da45:
  jsr _func_da40                 ; $DA45  20 40 DA

_label_da48:
  lda z:_var_000f                ; $DA48  A5 0F
  jmp _func_daa5                 ; $DA4A  4C A5 DA

_label_da4d:
  lda z:_var_001b                ; $DA4D  A5 1B
  beq _label_da48                ; $DA4F  F0 F7
  jsr _func_da5c                 ; $DA51  20 5C DA
  jmp _func_da40                 ; $DA54  4C 40 DA

_label_da57:
  lda z:_var_000f                ; $DA57  A5 0F
  jsr _func_dab5                 ; $DA59  20 B5 DA

_func_da5c:
  lda z:_var_000c                ; $DA5C  A5 0C
  jmp _func_daa5                 ; $DA5E  4C A5 DA

_label_da61:
  lda z:_var_000f                ; $DA61  A5 0F
  jsr _func_d12b                 ; $DA63  20 2B D1
  jsr _func_dab5                 ; $DA66  20 B5 DA
  jmp _func_da5c                 ; $DA69  4C 5C DA

_label_da6c:
  lda z:_var_001b                ; $DA6C  A5 1B
  beq _label_da48                ; $DA6E  F0 D8
  lda z:_var_000c                ; $DA70  A5 0C
  jsr _func_daa5                 ; $DA72  20 A5 DA

_func_da75:
  lda z:_var_000c                ; $DA75  A5 0C
  jsr _func_d12b                 ; $DA77  20 2B D1
  jmp _func_dab5                 ; $DA7A  4C B5 DA

_label_da7d:
  lda z:_var_000f                ; $DA7D  A5 0F
  jsr _func_daa5                 ; $DA7F  20 A5 DA
  jmp _func_da75                 ; $DA82  4C 75 DA

_label_da85:
  jsr _func_da75                 ; $DA85  20 75 DA

_label_da88:
  lda z:_var_000f                ; $DA88  A5 0F
  jsr _func_d12b                 ; $DA8A  20 2B D1
  jmp _func_daa5                 ; $DA8D  4C A5 DA

_label_da90:
  lda z:_var_001b                ; $DA90  A5 1B
  beq _label_da88                ; $DA92  F0 F4
  jsr _func_da75                 ; $DA94  20 75 DA
  jmp _func_da26                 ; $DA97  4C 26 DA

_label_da9a:
  lda z:_var_000f                ; $DA9A  A5 0F
  jsr _func_d12b                 ; $DA9C  20 2B D1
  jsr _func_dab5                 ; $DA9F  20 B5 DA
  jmp _func_da26                 ; $DAA2  4C 26 DA

_func_daa5:
  clc                            ; $DAA5  18
  adc z:_var_0060_indexed,X      ; $DAA6  75 60
  cmp #$07                       ; $DAA8  C9 07
  bcc _label_dab0                ; $DAAA  90 04
  cmp #$C7                       ; $DAAC  C9 C7
  bcc _label_dab2                ; $DAAE  90 02

_label_dab0:
  lda #$00                       ; $DAB0  A9 00

_label_dab2:
  sta z:_var_0060_indexed,X      ; $DAB2  95 60
  rts                            ; $DAB4  60

_func_dab5:
  clc                            ; $DAB5  18
  adc z:_var_0061_indexed,X      ; $DAB6  75 61
  cmp #$07                       ; $DAB8  C9 07
  bcc _label_dac0                ; $DABA  90 04
  cmp #$F8                       ; $DABC  C9 F8
  bcc _label_dac2                ; $DABE  90 02

_label_dac0:
  lda #$00                       ; $DAC0  A9 00

_label_dac2:
  sta z:_var_0061_indexed,X      ; $DAC2  95 61
  rts                            ; $DAC4  60

.byte $0f, $db, $14, $db, $1d, $db, $26, $db, $2f, $db, $38, $db, $41, $db, $4a, $db
.byte $5b, $db, $86, $db, $6c, $db, $79, $db, $8f, $db, $9c, $db, $a9, $db, $b6, $db
.byte $c3, $db, $3a, $dc, $fa, $db, $07, $dc, $0c, $dc, $25, $dc, $d0, $db, $e5, $db
.byte $4b, $dc, $50, $dc, $61, $dc, $72, $dc, $7b, $dc, $88, $dc, $91, $dc, $9a, $dc
.byte $9f, $dc, $a8, $dc, $ad, $dc, $b6, $dc, $bb, $dc, $dd, $0c, $f0, $f0, $00, $dd
.byte $24, $f0, $f0, $dd, $e1, $ef, $08, $00, $dd, $3a, $f0, $f0, $dd, $e1, $ee, $08
.byte $00, $dd, $53, $f0, $f8, $dd, $65, $f4, $f0, $00, $dd, $6f, $f0, $f8, $dd, $81
.byte $fc, $f0, $00, $dd, $8a, $f0, $f8, $dd, $9c, $04, $f0, $00, $dd, $c3, $f0, $f0
.byte $dd, $d7, $fc, $10, $00, $dd, $e6, $f8, $f8, $dd, $ef, $ff, $f0, $dd, $f4, $f7
.byte $08, $dd, $dc, $fb, $10, $00, $dd, $fa, $f8, $f8, $dd, $ef, $fe, $f0, $dd, $f4
.byte $f6, $08, $dd, $d7, $fa, $10, $00, $de, $04, $f0, $f4, $de, $12, $f4, $04, $de
.byte $17, $08, $04, $00, $de, $1c, $f0, $fc, $de, $2a, $f4, $f4, $de, $2f, $08, $f4
.byte $00, $dd, $a5, $f0, $f0, $dd, $bd, $08, $fa, $00, $de, $90, $f8, $10, $de, $34
.byte $f0, $e8, $df, $ed, $e8, $ea, $00, $de, $90, $f8, $10, $de, $4b, $f0, $e8, $df
.byte $f2, $e0, $f0, $00, $de, $90, $f8, $10, $de, $62, $f0, $e8, $df, $ed, $e8, $ea
.byte $00, $de, $90, $f8, $10, $de, $79, $f0, $e8, $df, $f2, $e0, $f0, $00, $de, $9a
.byte $f8, $10, $de, $34, $f0, $e8, $df, $ed, $e8, $ea, $00, $de, $a4, $f0, $f8, $de
.byte $b8, $10, $f8, $de, $c0, $ed, $f0, $de, $c6, $f0, $08, $de, $cb, $fe, $f0, $00
.byte $de, $d3, $f0, $f8, $de, $e7, $10, $f8, $de, $ef, $ed, $f0, $de, $f5, $f0, $08
.byte $de, $fa, $fe, $f0, $00, $df, $02, $e0, $00, $df, $0b, $f0, $10, $df, $10, $f0
.byte $f0, $00, $df, $29, $f0, $f0, $00, $df, $3f, $ed, $f0, $df, $45, $03, $f0, $df
.byte $4b, $f0, $f8, $df, $55, $10, $f8, $df, $5d, $f0, $00, $df, $80, $04, $18, $00
.byte $df, $85, $f0, $e0, $df, $5d, $f0, $00, $df, $ab, $04, $e0, $df, $b0, $04, $18
.byte $df, $55, $10, $f8, $00, $df, $b5, $e0, $00, $df, $cb, $00, $00, $df, $da, $f0
.byte $e8, $df, $f8, $e0, $f0, $00, $df, $fe, $f8, $f4, $00, $e0, $0f, $fc, $f5, $e0
.byte $14, $fc, $03, $e0, $19, $f9, $fc, $e0, $1e, $fe, $fc, $00, $e0, $0f, $fc, $f7
.byte $e0, $14, $fc, $01, $e0, $19, $fa, $fc, $e0, $1e, $fd, $fc, $00, $e0, $0f, $fc
.byte $f8, $e0, $14, $fc, $00, $00, $e0, $23, $fc, $f7, $e0, $23, $fc, $f9, $e0, $28
.byte $fc, $01, $00, $e0, $23, $fc, $f8, $e0, $28, $fc, $00, $00, $e0, $23, $fc, $f9
.byte $e0, $28, $fc, $ff, $00, $e0, $2d, $fc, $fc, $00, $e0, $32, $fc, $fc, $e0, $32
.byte $fc, $fb, $00, $e0, $32, $fc, $fc, $00, $e0, $37, $fc, $fc, $e0, $37, $fc, $fd
.byte $00, $e0, $37, $fc, $fc, $00, $e0, $3c, $fc, $f8, $00

_data_dcc0_indexed:
.byte $00, $00, $08, $00, $10, $00, $18, $00, $00, $08, $08, $08, $10, $08, $18, $08
.byte $00, $00, $00, $08, $00, $10, $00, $18, $08, $00, $08, $08, $08, $10, $08, $18
.byte $10, $00, $10, $08, $10, $10, $10, $18, $18, $00, $18, $08, $18, $10, $18, $18
.byte $08, $20, $10, $20, $18, $20, $18, $20, $00, $00, $08, $00, $10, $00, $00, $08
.byte $08, $08, $10, $08, $00, $00, $08, $00, $00, $18, $08, $18, $01, $fd, $00, $00
.byte $01, $02, $fd, $01, $03, $fd, $00, $04, $05, $06, $07, $08, $09, $0a, $fe, $fd
.byte $01, $0b, $0c, $ff, $01, $fd, $00, $fe, $fe, $0d, $fe, $fd, $00, $0f, $10, $11
.byte $fe, $12, $13, $14, $15, $fd, $01, $16, $17, $ff, $01, $fd, $00, $fe, $fe, $18
.byte $fe, $fd, $00, $1a, $1b, $1c, $fe, $1d, $1e, $1f, $fe, $fd, $01, $20, $21, $fd
.byte $00, $22, $ff, $00, $fd, $00, $25, $26, $27, $fd, $01, $28, $fd, $40, $25, $26
.byte $27, $fd, $41, $28, $ff, $03, $fd, $00, $23, $24, $fd, $40, $23, $24, $ff, $00
.byte $fd, $00, $2a, $2b, $2c, $fd, $01, $2d, $fd, $40, $2a, $2b, $2c, $fd, $41, $2d
.byte $ff, $03, $fd, $00, $29, $fe, $fd, $40, $29, $ff, $00, $fd, $00, $2f, $30, $31
.byte $fd, $01, $32, $fd, $40, $2f, $30, $31, $fd, $41, $32, $ff, $03, $fd, $00, $2e
.byte $fe, $fd, $40, $2e, $ff, $01, $fd, $00, $33, $34, $35, $fd, $01, $36, $fd, $00
.byte $37, $38, $39, $fd, $01, $3a, $fd, $00, $fe, $3b, $3c, $3d, $ff, $01, $fd, $01
.byte $3e, $3f, $ff, $01, $fd, $00, $fe, $40, $41, $fe, $fe, $42, $43, $44, $45, $46
.byte $47, $48, $fe, $fd, $01, $49, $ff, $00, $fd, $01, $4a, $ff, $00, $fd, $01, $f6
.byte $ff, $00, $fd, $01, $03, $ff, $02, $fd, $01, $9f, $a0, $a1, $a2, $a3, $ff, $00
.byte $fd, $01, $45, $ff, $00, $fd, $00, $44, $48, $ff, $02, $fd, $01, $a4, $a5, $a6
.byte $a7, $a8, $a9, $ff, $00, $fd, $01, $ab, $ac, $fe, $fe, $0e, $19, $aa, $fd, $80
.byte $e5, $ff, $00, $fd, $81, $ea, $ff, $00, $fd, $81, $e9, $ff, $00, $fd, $41, $0e
.byte $19, $aa, $fd, $c0, $e5, $fd, $41, $ab, $ac, $ff, $00, $fd, $c1, $ea, $ff, $00
.byte $fd, $c1, $e9, $ff, $01, $fd, $03, $52, $53, $54, $fe, $55, $56, $56, $57, $5a
.byte $5b, $5c, $5d, $61, $62, $63, $64, $58, $5e, $65, $ff, $01, $fd, $03, $52, $6a
.byte $54, $fe, $55, $6b, $56, $57, $6c, $6d, $6e, $6f, $70, $71, $72, $73, $58, $5e
.byte $74, $ff, $01, $fd, $03, $75, $53, $54, $fe, $76, $56, $56, $57, $77, $78, $79
.byte $7a, $7b, $7c, $7d, $7e, $58, $5e, $7f, $ff, $01, $fd, $03, $52, $6a, $54, $fe
.byte $76, $6b, $56, $57, $80, $81, $82, $83, $85, $86, $87, $88, $58, $84, $89, $ff
.byte $02, $fd, $02, $59, $5f, $66, $fe, $60, $67, $ff, $02, $fd, $02, $4b, $4c, $4d
.byte $4e, $4f, $50, $ff, $00, $fd, $02, $cd, $ce, $cf, $fd, $03, $d0, $fd, $42, $cd
.byte $ce, $fd, $02, $d2, $fd, $03, $d3, $ff, $01, $fd, $03, $d1, $fd, $43, $d1, $ff
.byte $03, $fd, $02, $c9, $ca, $ff, $00, $fd, $02, $d4, $ff, $03, $fd, $03, $cb, $cc
.byte $d5, $d6, $ff, $00, $fd, $02, $d7, $d8, $d9, $fd, $03, $d0, $fd, $42, $d7, $d8
.byte $fd, $02, $da, $fd, $03, $d3, $ff, $01, $fd, $03, $d1, $fd, $43, $d1, $ff, $03
.byte $fd, $02, $c9, $ca, $ff, $00, $fd, $02, $d4, $ff, $03, $fd, $03, $cb, $cc, $d5
.byte $d6, $ff, $02, $fd, $03, $b3, $b4, $fe, $b9, $ba, $ff, $00, $fd, $02, $bf, $ff
.byte $01, $fd, $03, $fe, $af, $b5, $fd, $02, $bb, $fd, $03, $fe, $b0, $b6, $bc, $ad
.byte $b1, $b7, $bd, $ae, $b2, $b8, $be, $c0, $ff, $01, $fd, $03, $fe, $fe, $c1, $c2
.byte $c3, $c4, $c5, $c6, $ad, $b1, $b7, $c7, $ae, $b2, $b8, $be, $fe, $c8, $ff, $00
.byte $fd, $02, $c9, $ca, $ff, $00, $fd, $03, $db, $dc, $ff, $00, $fd, $02, $dd, $de
.byte $fd, $03, $df, $e0, $ff, $01, $fd, $03, $d1, $fd, $43, $d1, $ff, $01, $fd, $42
.byte $dd, $fd, $02, $d4, $fd, $00, $e5, $fd, $01, $e9, $fd, $42, $de, $fd, $03, $e2
.byte $e6, $fe, $e1, $e3, $fd, $01, $e7, $fe, $fd, $43, $e0, $fd, $01, $e4, $e8, $ff
.byte $00, $fd, $01, $ea, $ff, $01, $fd, $41, $e9, $fd, $40, $e5, $fd, $42, $d4, $fd
.byte $02, $dd, $fe, $fd, $43, $e6, $e2, $fd, $02, $de, $fe, $fd, $41, $e7, $fd, $43
.byte $e3, $e1, $fe, $fd, $41, $e8, $e4, $fd, $03, $e0, $ff, $00, $fd, $41, $ea, $ff
.byte $00, $fd, $01, $ea, $ff, $01, $fd, $03, $8a, $8b, $fe, $fe, $8c, $fd, $02, $8d
.byte $8e, $fe, $8f, $90, $91, $92, $93, $94, $95, $96, $ff, $01, $fd, $03, $97, $fd
.byte $02, $98, $fd, $03, $99, $fe, $9a, $9b, $9c, $ff, $01, $fd, $03, $52, $53, $54
.byte $fe, $55, $56, $56, $fe, $5a, $5b, $5c, $fe, $61, $62, $63, $ff, $01, $fd, $03
.byte $51, $ff, $02, $fd, $03, $68, $69, $ff, $00, $fd, $03, $9d, $9e, $ff, $01, $fd
.byte $00, $f2, $f3, $fd, $40, $f2, $fe, $fd, $00, $f4, $f5, $fd, $40, $f4, $ff, $00
.byte $fd, $00, $eb, $ff, $00, $fd, $40, $eb, $ff, $00, $fd, $00, $f3, $ff, $00, $fd
.byte $00, $f5, $ff, $01, $fd, $00, $ec, $ff, $01, $fd, $40, $ec, $ff, $01, $fd, $00
.byte $ef, $ff, $00, $fd, $00, $f0, $ff, $00, $fd, $00, $f1, $ff, $01, $fd, $00, $ed
.byte $ee, $ff, $23, $00, $60, $50, $23, $20, $60, $50, $23, $40, $60, $50, $23, $60
.byte $60, $50, $23, $80, $60, $50, $23, $a0, $60, $50, $22, $40, $20, $3d, $3e, $3f
.byte $40, $56, $57, $d1, $d2, $3a, $3b, $3c, $3d, $3e, $3f, $40, $39, $3a, $3b, $3c
.byte $3d, $3e, $3f, $40, $d2, $30, $31, $32, $33, $39, $3a, $3b, $3c, $22, $60, $20
.byte $95, $96, $97, $98, $58, $59, $5a, $5b, $92, $93, $94, $95, $96, $97, $98, $91
.byte $92, $93, $94, $95, $96, $97, $98, $5b, $34, $35, $36, $37, $91, $92, $93, $94
.byte $22, $80, $20, $46, $45, $48, $46, $46, $45, $46, $48, $42, $43, $44, $46, $45
.byte $48, $46, $41, $42, $43, $44, $46, $45, $48, $46, $48, $38, $45, $46, $46, $41
.byte $42, $43, $44, $22, $a0, $60, $46, $22, $a4, $01, $48, $22, $a8, $01, $47, $22
.byte $aa, $01, $48, $22, $b0, $01, $47, $22, $b2, $01, $48, $22, $ba, $01, $48, $22
.byte $c0, $20, $4c, $4d, $4e, $4f, $49, $4a, $4b, $49, $4c, $4d, $4e, $4f, $4d, $4e
.byte $4f, $49, $4a, $4b, $49, $4c, $4d, $4e, $4f, $49, $49, $4a, $4b, $49, $4c, $4d
.byte $4e, $4f, $22, $e0, $20, $52, $50, $53, $50, $50, $51, $50, $50, $52, $50, $53
.byte $50, $50, $53, $50, $50, $51, $50, $50, $52, $50, $53, $50, $50, $50, $51, $50
.byte $50, $52, $50, $53, $50, $23, $00, $01, $52, $23, $02, $02, $54, $52, $23, $0a
.byte $02, $54, $52, $23, $0d, $02, $54, $52, $23, $0f, $02, $54, $52, $23, $15, $02
.byte $54, $52, $23, $1e, $02, $54, $52, $21, $f9, $03, $28, $29, $2a, $22, $19, $03
.byte $2b, $46, $2c, $22, $38, $04, $2d, $2e, $46, $2f, $20, $81, $04, $5c, $5d, $5e
.byte $5f, $20, $a1, $05, $60, $61, $46, $62, $63, $20, $c1, $05, $64, $65, $66, $67
.byte $68, $20, $e3, $05, $69, $74, $75, $76, $6a, $21, $03, $05, $6b, $6c, $7c, $6d
.byte $6e, $21, $23, $05, $6f, $70, $71, $72, $73, $21, $40, $07, $74, $75, $76, $77
.byte $78, $79, $7a, $21, $60, $09, $7b, $7c, $7d, $7e, $7f, $80, $5d, $5e, $5f, $21
.byte $81, $09, $81, $82, $83, $84, $60, $61, $46, $62, $63, $21, $a3, $07, $85, $86
.byte $64, $87, $88, $67, $68, $21, $c3, $04, $89, $8a, $8b, $8c, $21, $e4, $02, $8d
.byte $8e, $22, $04, $02, $8f, $90, $22, $24, $02, $8f, $55, $23, $03, $02, $1b, $27
.byte $23, $23, $5b, $e3, $23, $22, $06, $e2, $e3, $e3, $e3, $e4, $e2, $23, $36, $02
.byte $e4, $e2, $23, $3e, $01, $e4, $23, $48, $56, $b7, $23, $42, $06, $e5, $d9, $d9
.byte $d9, $e7, $e5, $23, $4c, $4a, $d6, $23, $56, $02, $e7, $e5, $23, $5e, $01, $e7
.byte $23, $58, $46, $00, $23, $68, $56, $b7, $23, $62, $06, $e5, $da, $db, $dc, $e7
.byte $e5, $23, $76, $02, $e7, $e5, $23, $7e, $01, $e7, $23, $79, $05, $1c, $0c, $18
.byte $1b, $0e, $23, $83, $5b, $e9, $23, $82, $01, $e8, $23, $86, $02, $ea, $e8, $23
.byte $96, $02, $ea, $e8, $23, $9e, $01, $ea, $23, $c0, $60, $00, $23, $ca, $04, $cc
.byte $ff, $ff, $ff, $23, $d2, $04, $cc, $ff, $ff, $ff, $23, $e0, $48, $50, $23, $e1
.byte $01, $40, $23, $e8, $48, $a5, $23, $f0, $08, $aa, $aa, $aa, $fa, $fa, $ba, $fa
.byte $ba, $23, $f8, $48, $0a, $23, $48, $03, $11, $12, $1d, $00, $22, $20, $60, $b6
.byte $22, $40, $60, $b5, $22, $60, $60, $b5, $22, $80, $60, $b5, $22, $a0, $60, $b5
.byte $22, $c0, $60, $b5, $22, $e0, $60, $b5, $23, $00, $60, $b5, $21, $85, $05, $ac
.byte $ad, $ae, $c1, $c2, $21, $a4, $07, $af, $b0, $b5, $b5, $c3, $c4, $c5, $21, $b0
.byte $04, $ec, $b4, $b8, $b9, $21, $c2, $0b, $b1, $b2, $b5, $b5, $b5, $b5, $b5, $c6
.byte $c7, $c8, $c9, $21, $ce, $0f, $ca, $b4, $b5, $b5, $b5, $ed, $ba, $bb, $bc, $b3
.byte $eb, $b0, $be, $bb, $bf, $21, $e2, $59, $b5, $21, $e0, $02, $b3, $b4, $21, $eb
.byte $04, $cb, $c4, $cc, $cd, $21, $f5, $01, $bd, $21, $fb, $05, $bd, $cb, $c4, $c8
.byte $bb, $22, $00, $5d, $b5, $22, $0d, $03, $ce, $cf, $d0, $22, $1d, $03, $c3, $c0
.byte $c0, $22, $60, $06, $99, $9a, $9b, $9c, $99, $9a, $22, $80, $06, $9d, $9e, $9f
.byte $a0, $9d, $9e, $22, $a0, $06, $a1, $a2, $a3, $a4, $a1, $a2, $22, $c0, $06, $a5
.byte $a6, $a5, $a7, $a5, $a6, $22, $47, $84, $9b, $9f, $a3, $a5, $22, $48, $84, $9c
.byte $a0, $a4, $a6, $22, $4a, $02, $a8, $a9, $22, $6a, $02, $aa, $ab, $22, $58, $05
.byte $a8, $a9, $a8, $a8, $a8, $22, $77, $06, $a8, $aa, $ab, $aa, $aa, $aa, $22, $74
.byte $82, $a9, $ab, $22, $97, $01, $aa, $22, $ba, $04, $99, $9a, $9b, $9c, $22, $da
.byte $04, $9d, $9e, $9f, $a0, $22, $fa, $04, $a1, $a2, $a3, $a4, $23, $20, $60, $c0
.byte $23, $40, $60, $c0, $23, $60, $60, $c0, $23, $80, $60, $c0, $23, $a0, $60, $c0
.byte $23, $00, $60, $dd, $23, $08, $50, $df, $23, $07, $01, $de, $23, $18, $01, $e0
.byte $23, $28, $56, $e3, $23, $48, $56, $b7, $23, $68, $56, $b7, $23, $88, $56, $e9
.byte $23, $58, $46, $00, $23, $22, $06, $e2, $e3, $e3, $e3, $e4, $e2, $23, $42, $06
.byte $e5, $d9, $d9, $d9, $e7, $e5, $23, $62, $06, $e5, $da, $db, $dc, $e7, $e5, $23
.byte $82, $06, $e8, $e9, $e9, $e9, $ea, $e8, $23, $4c, $4a, $d4, $23, $03, $02, $1b
.byte $27, $23, $36, $84, $e4, $e7, $e7, $ea, $23, $37, $84, $e2, $e5, $e5, $e8, $23
.byte $3e, $84, $e4, $e7, $e7, $ea, $23, $79, $05, $1c, $0c, $18, $1b, $0e, $23, $c0
.byte $60, $00, $23, $c8, $50, $ff, $23, $e0, $48, $50, $23, $e8, $48, $55, $23, $f0
.byte $08, $aa, $aa, $aa, $fa, $fa, $ba, $fa, $ba, $23, $f8, $48, $0a, $23, $48, $03
.byte $11, $12, $1d, $00, $20, $64, $53, $b7, $20, $84, $53, $b7, $20, $a4, $53, $b7
.byte $20, $c4, $53, $b7, $20, $e4, $53, $b7, $20, $86, $82, $f5, $f4, $20, $67, $85
.byte $f0, $b7, $b7, $b7, $f1, $20, $68, $c5, $24, $20, $6b, $83, $24, $24, $f4, $20
.byte $e9, $04, $f3, $b7, $b7, $f1, $20, $6d, $c5, $24, $20, $6e, $04, $f2, $b7, $b7
.byte $f0, $20, $ee, $04, $f3, $b7, $b7, $f1, $20, $90, $02, $f5, $f6, $20, $b0, $02
.byte $f4, $f7, $20, $72, $c5, $24, $20, $75, $85, $24, $f8, $b7, $f9, $24, $20, $96
.byte $82, $f1, $f0, $21, $24, $58, $fb, $21, $49, $53, $b7, $21, $69, $52, $b7, $21
.byte $89, $52, $b7, $21, $a9, $52, $b7, $21, $c9, $52, $b7, $21, $4b, $85, $24, $fa
.byte $b7, $24, $24, $21, $4d, $c5, $24, $21, $ce, $04, $f3, $b7, $b7, $f1, $21, $50
.byte $83, $24, $24, $f4, $21, $52, $c5, $24, $21, $55, $85, $24, $f0, $b7, $f9, $24
.byte $21, $57, $c5, $24, $21, $78, $c4, $24, $21, $7b, $c4, $24, $22, $28, $0f, $10
.byte $0a, $16, $0e, $24, $0a, $24, $24, $24, $01, $24, $0d, $1e, $0c, $14, $22, $68
.byte $10, $10, $0a, $16, $0e, $24, $0b, $24, $24, $24, $02, $24, $0d, $1e, $0c, $14
.byte $1c, $22, $a8, $16, $10, $0a, $16, $0e, $24, $0c, $24, $24, $24, $0c, $15, $0a
.byte $22, $24, $1c, $11, $18, $18, $1d, $12, $17, $10, $23, $07, $0b, $1d, $18, $19
.byte $24, $1c, $0c, $18, $1b, $0e, $24, $27, $23, $45, $16, $25, $01, $09, $08, $04
.byte $24, $17, $12, $17, $1d, $0e, $17, $0d, $18, $24, $0c, $18, $ee, $15, $1d, $0d
.byte $ef, $23, $c0, $60, $00, $23, $e0, $42, $55, $23, $e2, $46, $ff, $23, $ea, $46
.byte $ff, $23, $f0, $48, $5a, $23, $f8, $48, $00, $23, $e1, $01, $55, $23, $e9, $01
.byte $55, $00

_data_e532_indexed:
.byte $40

PaletteTable:
.byte $e5, $58, $e5, $7c, $e5, $a0, $e5, $a9, $e5, $c7, $e5, $b4, $e5, $3f, $00, $10
.byte $0f, $2c, $27, $0f, $0f, $0f, $30, $30, $0f, $0f, $2a, $2a, $0f, $0f, $27, $27
.byte $3f, $10, $50, $0f, $00, $3f, $00, $20, $21, $07, $29, $0a, $21, $30, $29, $0a
.byte $21, $0f, $29, $18, $21, $0f, $30, $16, $21, $30, $0a, $0f, $21, $30, $26, $0f
.byte $21, $30, $17, $0f, $21, $07, $17, $0f, $00, $3f, $00, $20, $2c, $29, $19, $09
.byte $2c, $07, $29, $1a, $2c, $0f, $29, $10, $2c, $0f, $30, $16, $2c, $30, $0f, $0f
.byte $2c, $30, $16, $07, $2c, $30, $17, $0f, $2c, $07, $17, $0f, $00, $3f, $00, $60
.byte $0f, $3f, $03, $01, $30, $00, $3f, $00, $60, $0f, $3f, $11, $03, $30, $30, $30
.byte $00, $3f, $10, $10, $21, $30, $0a, $0f, $21, $30, $26, $0f, $21, $30, $17, $0f
.byte $21, $07, $17, $0f, $3f, $00, $10, $21, $07, $29, $0a, $21, $30, $29, $0a, $21
.byte $0f, $29, $18, $21, $0f, $30, $16, $00

_data_e5db:
.byte $23

_data_e5dc:
.byte $58, $06, $00

_data_e5df_indexed:
.byte $00, $01, $20, $00, $00, $01, $20, $00, $00, $01, $20, $00

_data_e5eb_indexed:
.byte $01, $01, $a8, $80, $00, $00, $00, $3f, $01, $00, $03, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00

_data_e60b_indexed:
.byte $76

_data_e60c_indexed:
.byte $ed, $98, $ed, $b0, $ed, $bc, $ed, $d4, $ed, $fa, $ed, $1a, $ee, $34, $ee, $4c
.byte $ee, $68, $ee, $82, $ee, $96, $ee, $b8, $ee, $d0, $ee, $f4, $ee, $0e, $ef, $2a
.byte $ef, $2d, $ef, $30, $ef, $33, $ef, $36, $ef, $39, $ef, $3c, $ef, $3f, $ef, $42
.byte $ef, $45, $ef, $48, $ef, $4b, $ef, $4e, $ef, $51, $ef, $54, $ef, $57, $ef

_data_e64b_indexed:
.byte $00, $03, $10, $17, $24, $27, $34, $3b, $48, $4b, $58, $5f, $6c, $6f, $7c, $83
.byte $90, $95, $98, $9b, $9e, $a1

_data_e661_indexed:
.byte $ff, $00, $aa, $ff, $01, $ff, $00, $ff, $00, $ff, $01, $ff, $00, $00, $00, $aa
.byte $ff, $01, $ff, $01, $00, $00, $aa, $00, $01, $ff, $01, $00, $01, $ff, $01, $00
.byte $01, $00, $00, $aa, $00, $01, $aa, $00, $01, $01, $01, $00, $01, $01, $01, $00
.byte $01, $00, $00, $aa, $01, $01, $01, $01, $00, $00, $aa, $01, $01, $01, $00, $01
.byte $00, $01, $01, $01, $00, $00, $00, $aa, $01, $00, $aa, $01, $ff, $01, $00, $01
.byte $00, $01, $ff, $01, $00, $00, $00, $aa, $01, $ff, $01, $ff, $00, $00, $aa, $00
.byte $ff, $01, $ff, $00, $ff, $01, $ff, $00, $ff, $00, $00, $aa, $00, $ff, $aa, $00
.byte $ff, $ff, $ff, $00, $ff, $ff, $ff, $00, $ff, $00, $00, $aa, $ff, $ff, $ff, $ff
.byte $00, $00, $aa, $ff, $ff, $ff, $00, $ff, $00, $ff, $ff, $ff, $00, $00, $00, $aa
.byte $02, $01, $02, $ff, $aa, $ff, $fe, $aa, $fe, $ff, $aa, $fe, $00, $aa, $fe, $01
.byte $aa, $ff, $02, $aa, $02, $00, $02, $01, $04, $02, $fe, $02, $03, $02, $04, $04
.byte $05, $fe, $14, $09, $ff, $06, $01, $04, $0a, $04, $0b, $fe, $02, $06, $02, $07
.byte $04, $08, $fe

_data_e724_indexed:
.byte $21, $30, $0a, $0f, $21, $30, $26, $0f, $21, $30, $14, $02, $21, $30, $26, $02
.byte $21, $30, $0f, $05, $21, $30, $26, $05

_data_e73c_indexed:
.byte $04, $08, $0c, $08, $0c, $10, $08, $0c, $10, $0c, $10, $14, $10, $14, $18, $10
.byte $14, $18, $14, $18, $1c, $14, $1c, $1c, $18, $1c, $1c, $1c, $1c, $20

_data_e75a_indexed:
.byte $10, $14, $14, $18, $18, $1c, $1c, $20, $20, $24, $24, $28

_data_e766_indexed:
.byte $00, $01, $10, $11, $12, $20, $21, $22

_data_e76e_indexed:
.byte $01, $01, $ac, $18, $00, $00, $00, $bf, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $60, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $06, $0c, $06, $0d, $06, $0e, $06, $0f, $fe, $00, $08, $0c, $08, $10, $08, $0c
.byte $08, $10, $08, $0c, $08, $10, $ff, $02, $01, $10, $11, $ff, $08, $01, $90, $03
.byte $12, $83, $01, $12, $83, $01, $12, $83, $01, $12, $83, $01, $12, $82, $01, $12
.byte $82, $01, $12, $82, $01, $12, $82, $01, $12, $81, $01, $12, $82, $01, $12, $81
.byte $01, $12, $81, $01, $12, $81, $01, $12, $81, $01, $12, $81, $01, $12, $81, $01
.byte $12, $84, $01, $13, $00, $01, $13, $81, $01, $13, $00, $01, $13, $81, $01, $13
.byte $00, $01, $13, $00, $01, $13, $00, $01, $13, $81, $01, $13, $fd, $00, $01, $13
.byte $00, $01, $13, $00, $01, $13, $00, $01, $13, $01, $01, $13, $00, $01, $13, $01
.byte $01, $13, $00, $01, $13, $01, $01, $13, $01, $01, $13, $01, $01, $13, $02, $01
.byte $13, $02, $01, $13, $02, $01, $13, $03, $01, $13, $03, $01, $13, $04, $00, $13
.byte $04, $00, $13, $05, $00, $13, $05, $00, $13, $05, $00, $13, $05, $00, $13, $05
.byte $00, $13, $05, $00, $13, $ff, $0e, $00, $04, $81, $16, $04, $81, $17, $04, $81
.byte $16, $04, $81, $17, $04, $81, $16, $04, $81, $17, $04, $81, $16, $04, $81, $17
.byte $04, $81, $16, $04, $81, $17, $04, $80, $16, $04, $80, $17, $04, $80, $16, $04
.byte $80, $17, $04, $80, $16, $04, $80, $17, $04, $80, $16, $04, $80, $17, $04, $02
.byte $16, $04, $02, $17, $04, $02, $16, $04, $02, $17, $04, $02, $16, $04, $02, $17
.byte $04, $02, $16, $ff, $0f, $20, $14, $82, $14, $10, $00, $14, $14, $02, $14, $14
.byte $02, $14, $ff, $0f, $20, $14, $82, $15, $10, $00, $15, $14, $02, $15, $14, $02
.byte $15, $ff, $0f, $20, $04, $81, $16, $04, $81, $17, $04, $81, $16, $04, $81, $17
.byte $04, $81, $16, $04, $81, $17, $04, $81, $16, $04, $81, $17, $04, $81, $16, $04
.byte $81, $17, $04, $80, $16, $04, $80, $17, $04, $80, $16, $fc

_data_e8da_indexed:
.byte $01, $02, $00, $00, $00, $00, $00, $4f, $00, $00, $00, $00, $00, $00, $00, $01
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $f9, $fe, $fb, $fe, $ff, $fe, $ff, $fa, $fb, $fa, $f9, $fa, $00, $00, $00, $00
.byte $fa, $fd, $fb, $fd, $fb, $fd, $fc, $fd, $fc, $fb, $fb, $fb, $fb, $fb, $fa, $fb

_data_e92a_indexed:
.byte $18, $18, $19, $1a, $1a, $1b, $1c, $1d, $1e, $1e, $1f, $1f, $20, $20, $21, $21
.byte $22, $22, $22, $22, $23, $23, $23, $23, $23, $23

_data_e944_indexed:
.byte $00, $00, $00, $01, $01, $01, $02, $02, $02, $02, $03, $03, $03, $03, $04, $04
.byte $04, $04, $04, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05
.byte $05, $05, $05, $05

_data_e968_indexed:
.byte $00

_data_e969_indexed:
.byte $00

_data_e96a_indexed:
.byte $c0

_data_e96b_indexed:
.byte $15

_data_e96c_indexed:
.byte $1e

_data_e96d_indexed:
.byte $2c, $01, $00, $c0, $0a, $1e, $30, $03, $00, $d0, $10, $1e, $25, $04, $00, $c0
.byte $00, $1c, $30, $06, $00, $c0, $0f, $1c, $30, $08, $00, $c0, $f6, $1c, $30, $09
.byte $00, $c0, $0c, $1c, $30, $0a, $00, $c0, $f4, $1c, $30, $0c, $00, $c0, $f4, $1e
.byte $2d, $0e, $00, $c0, $08, $1c, $30, $0a, $00, $c0, $00, $1d, $30, $11, $00, $b8
.byte $ee, $20, $33, $13, $00, $c8, $f0, $1c, $2a, $04, $80, $c8, $f7, $1c, $2d, $0a
.byte $80, $c8, $0b, $1c, $2d, $0f, $80, $c6, $f3, $21, $26

_data_e9c8_indexed:
.byte $14, $14, $10, $10, $10, $08, $04, $00, $18, $14, $14, $10, $0c, $08, $04, $00
.byte $1c, $18, $18, $14, $10, $0c, $08, $04, $20, $1c, $18, $14, $10, $0c, $08, $04
.byte $24, $20, $1c, $18, $14, $0c, $08, $04, $28, $24, $20, $1c, $14, $10, $0c, $08
.byte $2c, $28, $24, $20, $18, $10, $0c, $08

_data_ea00_indexed:
.byte $01, $01, $01, $01, $02, $01, $01, $01, $02, $01, $02, $01, $02, $02, $02, $01
.byte $02, $02, $02, $02, $03, $02, $03, $02, $03, $03, $03, $03, $04, $03, $04, $03
.byte $04, $04, $04, $04, $05, $05, $05, $05, $06, $06, $06, $06, $07, $07, $07, $07

_data_ea30_indexed:
.byte $ed, $40, $ed, $40, $ed, $c0, $ed, $80, $ed, $00, $ed, $00, $ed, $00, $ed, $00
.byte $ee, $40, $ee, $40, $ee, $40, $ee, $40, $ee, $00, $ee, $00, $ee, $00, $ee, $00

_data_ea50_indexed:
.byte $06, $05, $04, $03, $03, $02, $03, $03, $02, $02, $02, $02, $02, $01, $01, $02
.byte $01, $01, $01, $01, $01, $01, $01, $00, $01, $01, $01, $01, $00, $01, $01, $01
.byte $00, $01, $01, $00, $01, $00, $01, $00, $bb, $01, $00, $01, $00, $bb, $01, $00
.byte $01, $00, $bb, $01, $00, $01, $bb, $00, $01, $bb, $00, $00, $bb, $00, $aa

_data_ea8f_indexed:
.byte $02, $02, $01, $02, $02, $01, $01, $01, $01, $01, $00, $01, $00, $01, $00, $01
.byte $00, $01, $bb, $00, $00, $01, $bb, $00, $00, $01, $bb, $00, $00, $bb, $01, $00
.byte $00, $bb, $01, $00, $bb, $00, $00, $bb, $bb, $bb, $bb, $bb, $bb, $bb, $bb, $bb
.byte $bb, $bb, $aa

_data_eac2_indexed:
.byte $01, $01, $00, $01, $01, $01, $00, $01, $00, $01, $00, $00, $01, $00, $00, $00
.byte $00, $01, $00, $00, $00, $00, $00, $01, $00, $00, $00, $00, $00, $00, $01, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

_data_eaf2_indexed:
.byte $00, $06, $00, $ff, $02, $05, $02, $ff, $08, $04, $06, $ff, $0e, $04, $07, $ff
.byte $12, $05, $08, $ff, $14, $04, $0a, $ff, $ff, $00, $00, $02, $ff, $00, $00, $04
.byte $ff, $00, $00, $06, $ff, $00, $00, $0a, $ff, $00, $00, $10, $ff, $00, $00, $14

_data_eb22_indexed:
.byte $02, $04, $06, $0a, $0c, $0e

_data_eb28_indexed:
.byte $01, $03, $05, $07, $09, $0b, $0d, $0f

_data_eb30_indexed:
.byte $4a

_data_eb31_indexed:
.byte $eb, $5d, $eb, $70, $eb, $7d, $eb, $86, $eb, $8f, $eb, $92, $eb, $92, $eb, $92
.byte $eb, $95, $eb, $b6, $eb, $c9, $eb, $dc, $eb, $f4, $f4, $f4, $fc, $f4, $04, $fc
.byte $f4, $fc, $fc, $fc, $04, $04, $f4, $04, $fc, $04, $04, $aa, $f7, $f5, $f7, $fd
.byte $f7, $03, $ff, $f5, $ff, $fd, $ff, $03, $01, $f5, $01, $fd, $01, $03, $aa, $f9
.byte $f7, $f9, $ff, $f9, $01, $ff, $f7, $ff, $ff, $ff, $01, $aa, $fa, $f8, $fa, $00
.byte $fe, $f8, $fe, $00, $aa, $fa, $fa, $fa, $fe, $fe, $fa, $fe, $fe, $aa, $fc, $fc
.byte $aa, $fc, $fc, $aa, $f0, $f0, $f0, $f8, $f0, $00, $f0, $08, $f8, $f0, $f8, $f8
.byte $f8, $00, $f8, $08, $00, $f0, $00, $f8, $00, $00, $00, $08, $08, $f0, $08, $f8
.byte $08, $00, $08, $08, $aa, $f4, $f5, $f4, $fd, $f4, $03, $fc, $f5, $fc, $fd, $fc
.byte $03, $04, $f5, $04, $fd, $04, $03, $aa, $f5, $f7, $f5, $ff, $f5, $01, $fd, $f7
.byte $fd, $ff, $fd, $01, $03, $f7, $03, $ff, $03, $01, $aa, $f6, $f8, $f6, $00, $fe
.byte $f8, $fe, $00, $02, $f8, $02, $00, $aa

_data_ebe9_indexed:
.byte $01, $01, $02, $03

_data_ebed_indexed:
.byte $00, $50, $00, $00

_data_ebf1_indexed:
.byte $00, $02, $03, $01, $04, $06, $02, $05, $07

_data_ebfa_indexed:
.byte $05, $08, $10, $15, $16, $20, $24, $30

_data_ec02_indexed:
.byte $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $07, $07, $08, $08, $09, $09
.byte $09, $09, $09, $0a, $ff

_data_ec17_indexed:
.byte $00, $08, $10, $18, $18, $20, $20, $28

_data_ec1f_indexed:
.byte $28, $01, $80, $00, $00, $aa, $01, $40, $02, $10, $03, $08, $02, $10, $03, $08
.byte $02, $10, $03, $08, $02, $10, $03, $08, $00

_data_ec38_indexed:
.byte $00

_data_ec39_indexed:
.byte $aa, $4a, $ec, $70, $ec, $82, $ec, $8b, $ec, $b1, $ec, $e6, $ec, $07, $ed, $3c
.byte $ed, $cd, $24, $57, $ff, $13, $13, $13, $13, $13, $1a, $d8, $1b, $18, $1e, $17
.byte $0d, $21, $d8, $b7, $b7, $b7, $b7, $b7, $21, $d8, $b7, $b7, $b7, $b7, $b7, $21
.byte $23, $fc, $fc, $fc, $fc, $fc, $fd, $ee, $10, $35, $b7, $b7, $b7, $b7, $b7, $b7
.byte $10, $18, $fe, $b7, $b7, $b7, $b7, $b7, $b7, $ef, $04, $23, $b7, $b7, $b7, $b7
.byte $b7, $b7, $cd, $24, $57, $ff, $13, $13, $13, $13, $13, $1a, $d8, $b7, $b7, $b7
.byte $b7, $b7, $21, $d8, $10, $18, $18, $0d, $fe, $21, $d8, $b7, $b7, $b7, $b7, $b7
.byte $21, $23, $fc, $fc, $fc, $fc, $fc, $fd, $cc, $33, $5a, $ff, $13, $13, $13, $13
.byte $13, $13, $13, $13, $1a, $d8, $19, $0e, $1b, $0f, $0e, $0c, $1d, $fe, $21, $d8
.byte $b7, $b7, $b7, $b7, $b7, $b7, $b7, $b7, $21, $d8, $b7, $b7, $b7, $00, $00, $00
.byte $b7, $b7, $21, $23, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fd, $ec, $1f, $3a
.byte $ff, $13, $13, $13, $13, $13, $13, $13, $13, $1a, $d8, $0f, $15, $22, $b7, $0a
.byte $20, $0a, $22, $21, $23, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fd, $cc, $33
.byte $5a, $24, $ff, $13, $13, $13, $13, $13, $1a, $24, $24, $24, $d8, $b7, $b7, $b7
.byte $b7, $b7, $21, $24, $24, $24, $d8, $19, $0a, $1e, $1c, $0e, $21, $24, $24, $24
.byte $d8, $b7, $b7, $b7, $b7, $b7, $21, $24, $24, $24, $23, $fc, $fc, $fc, $fc, $fc
.byte $fd, $24, $24, $ab, $38, $5b, $ff, $13, $13, $13, $13, $13, $13, $13, $13, $13
.byte $1a, $d8, $b7, $b7, $b7, $b7, $b7, $b7, $b7, $b7, $b7, $21, $d8, $10, $0a, $16
.byte $0e, $b7, $18, $1f, $0e, $1b, $21, $d8, $b7, $b7, $b7, $b7, $b7, $b7, $b7, $b7
.byte $b7, $21, $23, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fd, $9c, $18, $14
.byte $10, $01, $10, $02, $20, $03, $08, $02, $08, $01, $18, $00, $10, $0e, $08, $0d
.byte $20, $0c, $08, $0d, $08, $0c, $b0, $0b, $80, $03, $40, $02, $ff, $08, $00, $88
.byte $10, $12, $28, $0f, $08, $00, $10, $01, $08, $02, $48, $03, $20, $04, $70, $0c
.byte $30, $0d, $30, $0e, $ff, $08, $00, $90, $20, $12, $60, $0d, $90, $03, $78, $02
.byte $ff, $08, $00, $78, $20, $13, $40, $0f, $10, $0e, $20, $0d, $18, $0b, $20, $0a
.byte $50, $06, $28, $04, $38, $03, $78, $02, $ff, $08, $00, $80, $10, $12, $20, $0d
.byte $08, $0e, $08, $0f, $20, $03, $10, $02, $08, $0e, $20, $0d, $08, $0e, $08, $0f
.byte $08, $01, $08, $03, $30, $04, $40, $05, $80, $0b, $30, $0e, $60, $0f, $ff, $08
.byte $00, $b8, $08, $14, $10, $04, $08, $03, $08, $02, $08, $01, $08, $00, $08, $0e
.byte $08, $0d, $08, $0c, $50, $0b, $60, $0c, $10, $0d, $40, $02, $70, $01, $ff, $08
.byte $00, $70, $18, $12, $40, $0d, $10, $0f, $10, $02, $30, $04, $20, $05, $40, $03
.byte $20, $04, $20, $03, $18, $02, $20, $01, $ff, $08, $00, $b0, $10, $14, $28, $02
.byte $18, $01, $30, $00, $10, $0f, $50, $0b, $60, $0c, $20, $0b, $70, $04, $80, $05
.byte $ff, $08, $00, $5a, $08, $13, $10, $02, $20, $0d, $10, $03, $10, $04, $10, $03
.byte $58, $0d, $28, $03, $48, $04, $10, $03, $48, $0d, $80, $03, $ff, $08, $00, $46
.byte $20, $12, $20, $0e, $38, $04, $18, $02, $10, $04, $20, $06, $08, $05, $18, $04
.byte $18, $02, $40, $01, $40, $00, $ff, $08, $00, $d0, $2a, $14, $30, $0c, $20, $0b
.byte $20, $0c, $38, $0b, $48, $0c, $40, $02, $30, $0c, $ff, $08, $00, $70, $10, $12
.byte $10, $0d, $20, $0e, $10, $0f, $10, $00, $30, $02, $10, $04, $10, $05, $60, $05
.byte $20, $0b, $40, $0c, $08, $0d, $70, $03, $30, $02, $18, $00, $ff, $08, $00, $c0
.byte $18, $12, $10, $0d, $40, $0b, $38, $0d, $08, $0b, $08, $0c, $10, $0d, $70, $03
.byte $40, $02, $40, $01, $ff, $08, $00, $90, $18, $14, $20, $02, $28, $0d, $20, $0b
.byte $20, $0b, $08, $0c, $10, $0d, $20, $03, $20, $05, $20, $04, $10, $02, $10, $03
.byte $70, $0d, $40, $04, $50, $03, $20, $02, $ff, $08, $00, $58, $1c, $14, $24, $02
.byte $08, $00, $48, $0c, $38, $0e, $50, $07, $30, $05, $30, $04, $28, $0d, $20, $02
.byte $80, $01, $ff, $08, $00, $50, $20, $12, $20, $0d, $40, $03, $30, $0c, $40, $03
.byte $30, $04, $38, $05, $08, $0b, $28, $0c, $08, $0d, $40, $03, $4a, $04, $ff, $08
.byte $00, $40, $e0, $01, $80, $e0, $02, $d0, $e0, $0e, $38, $e0, $01, $a0, $e0, $0d
.byte $30, $e0, $03, $b0, $e0, $0e, $90, $e0, $0f, $40, $e0, $03, $80, $e0, $03, $c8
.byte $e0, $0e, $50, $e0, $0f, $b8, $e0, $0d, $20, $e0, $03, $48, $e0, $01, $b8, $e0
.byte $0f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff

_data_f300_indexed:
.byte $07

_data_f301_indexed:
.byte $f0, $00, $00, $00, $d4, $00, $c8, $00, $bd, $00, $b2, $00, $a8, $00, $9f, $00
.byte $96, $00, $8d, $00, $85, $00, $7e, $00, $70, $01, $ab, $01, $93, $01, $7c, $01
.byte $67, $01, $52, $01, $3f, $01, $2d, $01, $1c, $01, $0c, $00, $fd, $00, $ee, $00
.byte $e1, $03, $57, $02, $f9, $02, $cf, $02, $a6, $02, $80, $02, $5c, $02, $3a, $02
.byte $1a, $01, $fc, $01, $df, $01, $c4, $00, $69, $00, $63, $00, $53, $00, $4a

_data_f350_indexed:
.byte $03, $06, $0c, $18, $30, $12, $24, $04, $08, $10, $20, $40, $18, $30

_func_f35e:
  lda #$00                       ; $F35E  A9 00
  beq _label_f36c                ; $F360  F0 0A

_func_f362:
  lda #$08                       ; $F362  A9 08
  bne _label_f36c                ; $F364  D0 06

_func_f366:
  lda #$0C                       ; $F366  A9 0C
  bne _label_f36c                ; $F368  D0 02

_func_f36a:
  lda #$04                       ; $F36A  A9 04

_label_f36c:
  sta z:_var_00f4_indexed        ; $F36C  85 F4
  lda #$40                       ; $F36E  A9 40
  sta z:$F5                      ; $F370  85 F5
  stx z:_var_00f6_indexed        ; $F372  86 F6
  sty z:$F7                      ; $F374  84 F7
  ldy #$00                       ; $F376  A0 00

_label_f378:
  lda (_var_00f6_indexed),Y      ; $F378  B1 F6
  sta (_var_00f4_indexed),Y      ; $F37A  91 F4
  iny                            ; $F37C  C8
  tya                            ; $F37D  98
  cmp #$04                       ; $F37E  C9 04
  bne _label_f378                ; $F380  D0 F6
  rts                            ; $F382  60

_func_f383:
  sta z:_var_00e6                ; $F383  85 E6
  lda a:_data_f846_indexed,Y     ; $F385  B9 46 F8
  tay                            ; $F388  A8
  lda a:_data_f846_indexed,Y     ; $F389  B9 46 F8
  sta z:_var_00e5                ; $F38C  85 E5
  lda a:_data_f847_indexed,Y     ; $F38E  B9 47 F8
  sta z:_var_00f8_indexed        ; $F391  85 F8
  lda a:_data_f847_indexed+1,Y   ; $F393  B9 48 F8
  sta z:_var_00f9_indexed        ; $F396  85 F9
  lda a:_data_f849_indexed,Y     ; $F398  B9 49 F8
  sta z:_var_00fa_indexed        ; $F39B  85 FA
  lda a:_data_f849_indexed+1,Y   ; $F39D  B9 4A F8
  sta z:_var_00fb                ; $F3A0  85 FB
  lda a:_data_f84b_indexed,Y     ; $F3A2  B9 4B F8
  sta z:_var_00fc_indexed        ; $F3A5  85 FC
  lda a:_data_f84b_indexed+1,Y   ; $F3A7  B9 4C F8
  sta z:_var_00fd                ; $F3AA  85 FD
  lda a:_data_f84d_indexed,Y     ; $F3AC  B9 4D F8
  sta z:_var_00fe_indexed        ; $F3AF  85 FE
  lda a:_data_f84d_indexed+1,Y   ; $F3B1  B9 4E F8
  sta z:_var_00ff                ; $F3B4  85 FF
  lda #$01                       ; $F3B6  A9 01
  sta z:_var_00d8                ; $F3B8  85 D8
  sta z:_var_00d9                ; $F3BA  85 D9
  sta z:_var_00da                ; $F3BC  85 DA
  sta z:_var_00db                ; $F3BE  85 DB
  lda #$00                       ; $F3C0  A9 00
  sta z:_var_00f3                ; $F3C2  85 F3
  sta z:_var_00d0_indexed        ; $F3C4  85 D0
  sta z:_var_00d1                ; $F3C6  85 D1
  sta z:_var_00d2                ; $F3C8  85 D2
  sta z:_var_00d3                ; $F3CA  85 D3
  sta APU_DMC_RAW                ; $F3CC  8D 11 40
  rts                            ; $F3CF  60

_func_f3d0:
  lda #$7F                       ; $F3D0  A9 7F
  sta APU_PL1_SWEEP              ; $F3D2  8D 01 40
  sta APU_PL2_SWEEP              ; $F3D5  8D 05 40
  stx z:_var_00e9                ; $F3D8  86 E9
  sty z:_var_00ea                ; $F3DA  84 EA
  rts                            ; $F3DC  60

.byte $13, $7f, $3e, $f0

_data_f3e1_indexed:
.byte $4f, $53, $58, $5e, $63, $69, $70, $76, $7e, $85, $8d, $90, $92, $93, $92, $d5
.byte $40, $c0, $b2, $df, $ff, $80, $02, $7f, $0f, $08, $00, $7f, $03, $08, $ff

_data_f400_indexed:
.byte $10

_data_f401_indexed:
.byte $00

_data_f402_indexed:
.byte $18, $10, $01, $18, $00, $01, $88, $06, $02, $40, $05, $02, $c0

_label_f40f:
  lda z:_var_00f9_indexed        ; $F40F  A5 F9
  beq _label_f451                ; $F411  F0 3E
  dec z:_var_00d8                ; $F413  C6 D8
  bne _label_f451                ; $F415  D0 3A
  ldx #$00                       ; $F417  A2 00
  lda #$23                       ; $F419  A9 23
  sta a:_var_0612                ; $F41B  8D 12 06
  lda #$2E                       ; $F41E  A9 2E
  sta a:_var_0610                ; $F420  8D 10 06
  ldy z:_var_00d0_indexed        ; $F423  A4 D0
  inc z:_var_00d0_indexed        ; $F425  E6 D0
  lda (_var_00f8_indexed),Y      ; $F427  B1 F8
  beq _label_f443                ; $F429  F0 18
  jmp _label_f51c                ; $F42B  4C 1C F5
  tya                            ; $F42E  98
  bpl _label_f43a                ; $F42F  10 09
  jsr _func_f544                 ; $F431  20 44 F5
  ldy z:_var_00d0_indexed        ; $F434  A4 D0
  inc z:_var_00d0_indexed        ; $F436  E6 D0
  lda (_var_00f8_indexed),Y      ; $F438  B1 F8

_label_f43a:
  jsr _func_f550                 ; $F43A  20 50 F5
  bne _label_f448                ; $F43D  D0 09
  ldy #$10                       ; $F43F  A0 10
  bne _label_f44a                ; $F441  D0 07

_label_f443:
  lda #$00                       ; $F443  A9 00
  jmp _label_f68c                ; $F445  4C 8C F6

_label_f448:
  ldy z:_var_00e9                ; $F448  A4 E9

_label_f44a:
  sty APU_PL1_VOL                ; $F44A  8C 00 40
  lda z:_var_00dc_indexed        ; $F44D  A5 DC
  sta z:_var_00d8                ; $F44F  85 D8

_label_f451:
  lda z:_var_00fb                ; $F451  A5 FB
  beq _label_f47e                ; $F453  F0 29
  dec z:_var_00d9                ; $F455  C6 D9
  bne _label_f47e                ; $F457  D0 25
  ldx #$01                       ; $F459  A2 01
  ldy z:_var_00d1                ; $F45B  A4 D1
  inc z:_var_00d1                ; $F45D  E6 D1
  lda (_var_00fa_indexed),Y      ; $F45F  B1 FA
  bpl _label_f46c                ; $F461  10 09
  jsr _func_f544                 ; $F463  20 44 F5
  ldy z:_var_00d1                ; $F466  A4 D1
  inc z:_var_00d1                ; $F468  E6 D1
  lda (_var_00fa_indexed),Y      ; $F46A  B1 FA

_label_f46c:
  jsr _func_f564                 ; $F46C  20 64 F5
  bne _label_f475                ; $F46F  D0 04
  ldy #$10                       ; $F471  A0 10
  bne _label_f477                ; $F473  D0 02

_label_f475:
  ldy z:_var_00ea                ; $F475  A4 EA

_label_f477:
  sty APU_PL2_VOL                ; $F477  8C 04 40
  lda z:$DD                      ; $F47A  A5 DD
  sta z:_var_00d9                ; $F47C  85 D9

_label_f47e:
  lda z:_var_00fd                ; $F47E  A5 FD
  beq _label_f4d1                ; $F480  F0 4F
  dec z:_var_00da                ; $F482  C6 DA
  bne _label_f4d1                ; $F484  D0 4B
  ldx #$02                       ; $F486  A2 02
  lda #$9B                       ; $F488  A9 9B
  sta a:_var_0610                ; $F48A  8D 10 06
  lda #$92                       ; $F48D  A9 92
  sta a:_var_0612                ; $F48F  8D 12 06
  ldy z:_var_00d2                ; $F492  A4 D2
  inc z:_var_00d2                ; $F494  E6 D2
  lda (_var_00fc_indexed),Y      ; $F496  B1 FC
  jmp _label_f51c                ; $F498  4C 1C F5
  tya                            ; $F49B  98
  bpl _label_f4bf                ; $F49C  10 21
  jsr _func_f544                 ; $F49E  20 44 F5
  ldy z:_var_00e4                ; $F4A1  A4 E4
  beq _label_f4a9                ; $F4A3  F0 04
  lda #$FF                       ; $F4A5  A9 FF
  bne _label_f4b4                ; $F4A7  D0 0B

_label_f4a9:
  clc                            ; $F4A9  18
  adc #$FE                       ; $F4AA  69 FE
  asl a                          ; $F4AC  0A
  asl a                          ; $F4AD  0A
  cmp #$3C                       ; $F4AE  C9 3C
  bcc _label_f4b4                ; $F4B0  90 02
  lda #$3C                       ; $F4B2  A9 3C

_label_f4b4:
  sta APU_TRI_LINEAR             ; $F4B4  8D 08 40
  sta z:_var_00e7                ; $F4B7  85 E7
  ldy z:_var_00d2                ; $F4B9  A4 D2
  inc z:_var_00d2                ; $F4BB  E6 D2
  lda (_var_00fc_indexed),Y      ; $F4BD  B1 FC

_label_f4bf:
  jsr _func_f568                 ; $F4BF  20 68 F5
  bne _label_f4c8                ; $F4C2  D0 04
  ldy #$00                       ; $F4C4  A0 00
  beq _label_f4ca                ; $F4C6  F0 02

_label_f4c8:
  ldy z:_var_00e7                ; $F4C8  A4 E7

_label_f4ca:
  sty APU_TRI_LINEAR             ; $F4CA  8C 08 40
  lda z:$DE                      ; $F4CD  A5 DE
  sta z:_var_00da                ; $F4CF  85 DA

_label_f4d1:
  lda z:_var_00ff                ; $F4D1  A5 FF
  beq _label_f501                ; $F4D3  F0 2C
  dec z:_var_00db                ; $F4D5  C6 DB
  bne _label_f501                ; $F4D7  D0 28
  ldx #$03                       ; $F4D9  A2 03
  lda #$EE                       ; $F4DB  A9 EE
  sta a:_var_0610                ; $F4DD  8D 10 06
  lda #$E5                       ; $F4E0  A9 E5
  sta a:_var_0612                ; $F4E2  8D 12 06
  ldy z:_var_00d3                ; $F4E5  A4 D3
  inc z:_var_00d3                ; $F4E7  E6 D3
  lda (_var_00fe_indexed),Y      ; $F4E9  B1 FE
  jmp _label_f51c                ; $F4EB  4C 1C F5
  tya                            ; $F4EE  98
  bpl _label_f4fa                ; $F4EF  10 09
  jsr _func_f544                 ; $F4F1  20 44 F5
  ldy z:_var_00d3                ; $F4F4  A4 D3
  inc z:_var_00d3                ; $F4F6  E6 D3
  lda (_var_00fe_indexed),Y      ; $F4F8  B1 FE

_label_f4fa:
  jsr _func_f502                 ; $F4FA  20 02 F5
  lda z:$DF                      ; $F4FD  A5 DF
  sta z:_var_00db                ; $F4FF  85 DB

_label_f501:
  rts                            ; $F501  60

_func_f502:
  tay                            ; $F502  A8
  lda z:_var_00f3                ; $F503  A5 F3
  cmp #$02                       ; $F505  C9 02
  beq _label_f51b                ; $F507  F0 12
  lda a:_data_f400_indexed,Y     ; $F509  B9 00 F4
  sta APU_NOISE_VOL              ; $F50C  8D 0C 40
  lda a:_data_f401_indexed,Y     ; $F50F  B9 01 F4
  sta APU_NOISE_LO               ; $F512  8D 0E 40
  lda a:_data_f402_indexed,Y     ; $F515  B9 02 F4
  sta APU_NOISE_HI               ; $F518  8D 0F 40

_label_f51b:
  rts                            ; $F51B  60

_label_f51c:
  tay                            ; $F51C  A8
  cmp #$FF                       ; $F51D  C9 FF
  beq _label_f52a                ; $F51F  F0 09
  and #$C0                       ; $F521  29 C0
  cmp #$C0                       ; $F523  C9 C0
  beq _label_f536                ; $F525  F0 0F
  jmp (_var_0610)                ; $F527  6C 10 06  jump engine detected - notes seem to be played here, whenever this jump engine is called, 0610 is F4EE

_label_f52a:
  lda z:_var_00e0_indexed,X      ; $F52A  B5 E0
  beq _label_f541                ; $F52C  F0 13
  dec z:_var_00e0_indexed,X      ; $F52E  D6 E0
  lda z:_var_00d4_indexed,X      ; $F530  B5 D4
  sta z:_var_00d0_indexed,X      ; $F532  95 D0
  bne _label_f541                ; $F534  D0 0B

_label_f536:
  tya                            ; $F536  98
  and #$3F                       ; $F537  29 3F
  sta z:_var_00e0_indexed,X      ; $F539  95 E0
  dec z:_var_00e0_indexed,X      ; $F53B  D6 E0
  lda z:_var_00d0_indexed,X      ; $F53D  B5 D0
  sta z:_var_00d4_indexed,X      ; $F53F  95 D4

_label_f541:
  jmp (_var_0612)                ; $F541  6C 12 06  jump engine detected

_func_f544:
  and #$07                       ; $F544  29 07
  clc                            ; $F546  18
  adc z:_var_00e5                ; $F547  65 E5
  tay                            ; $F549  A8
  lda a:_data_f350_indexed,Y     ; $F54A  B9 50 F3
  sta z:_var_00dc_indexed,X      ; $F54D  95 DC
  rts                            ; $F54F  60

_func_f550:
  ldx #$00                       ; $F550  A2 00

_label_f552:
  tay                            ; $F552  A8
  lda a:_data_f301_indexed,Y     ; $F553  B9 01 F3
  beq _label_f563                ; $F556  F0 0B
  sta APU_PL1_LO,X               ; $F558  9D 02 40
  lda a:_data_f300_indexed,Y     ; $F55B  B9 00 F3
  ora #$08                       ; $F55E  09 08
  sta APU_PL1_HI,X               ; $F560  9D 03 40

_label_f563:
  rts                            ; $F563  60

_func_f564:
  ldx #$04                       ; $F564  A2 04
  bne _label_f552                ; $F566  D0 EA

_func_f568:
  ldx #$08                       ; $F568  A2 08
  bne _label_f552                ; $F56A  D0 E6

_func_f56c:
  lda #$C0                       ; $F56C  A9 C0
  sta APU_FRAME                  ; $F56E  8D 17 40
  jsr _func_f6cf                 ; $F571  20 CF F6
  jsr _func_f621                 ; $F574  20 21 F6
  jsr _func_f7cc                 ; $F577  20 CC F7
  jsr _func_f591                 ; $F57A  20 91 F5
  lda #$00                       ; $F57D  A9 00
  beq _label_f58a                ; $F57F  F0 09

_func_f581:
  lda #$F4                       ; $F581  A9 F4 - Load the accumulator to 0xF4
  sta a:$0613                    ; $F583  8D 13 06 - Store it to 0613
  sta a:$0611                    ; $F586  8D 11 06 - Store it to 0611
  rts                            ; $F589  60 - Return to subroutine. These values store MIDI system messages - 0xF4 is "Undefined (Reserved)", typically reserved for manufacturers to do custom operations. Makes sense here

_label_f58a:
  sta z:_var_00f0                ; $F58A  85 F0
  sta z:_var_00f1                ; $F58C  85 F1
  sta z:_var_00f2                ; $F58E  85 F2
  rts                            ; $F590  60

_func_f591:
  lda z:_var_00f2                ; $F591  A5 F2
  lsr a                          ; $F593  4A
  bcs _label_f5a2                ; $F594  B0 0C
  lsr a                          ; $F596  4A
  bcs _label_f59a                ; $F597  B0 01
  rts                            ; $F599  60

_label_f59a:
  lda #$20                       ; $F59A  A9 20
  ldx #$F4                       ; $F59C  A2 F4
  ldy #$0F                       ; $F59E  A0 0F
  bne _label_f5a8                ; $F5A0  D0 06

_label_f5a2:
  lda #$20                       ; $F5A2  A9 20
  ldx #$EC                       ; $F5A4  A2 EC
  ldy #$0E                       ; $F5A6  A0 0E

_label_f5a8:
  sta APU_DMC_LEN                ; $F5A8  8D 13 40
  stx APU_DMC_START              ; $F5AB  8E 12 40
  sty APU_DMC_FREQ               ; $F5AE  8C 10 40
  lda #$1F                       ; $F5B1  A9 1F
  sta APU_SND_CHN                ; $F5B3  8D 15 40
  rts                            ; $F5B6  60

.byte $9f, $7f, $60, $00, $9f, $7f, $61, $00

_label_f5bf:
  ldx #$DD                       ; $F5BF  A2 DD
  ldy #$F3                       ; $F5C1  A0 F3
  jsr _func_f362                 ; $F5C3  20 62 F3
  lda #$00                       ; $F5C6  A9 00
  sta z:_var_00eb                ; $F5C8  85 EB
  sta z:_var_00ed                ; $F5CA  85 ED
  sta z:_var_00ee                ; $F5CC  85 EE
  lda #$06                       ; $F5CE  A9 06
  sta z:_var_00ef                ; $F5D0  85 EF
  lda #$3E                       ; $F5D2  A9 3E
  sta z:_var_00ec                ; $F5D4  85 EC
  lda #$40                       ; $F5D6  A9 40
  sta z:_var_00f3                ; $F5D8  85 F3

_label_f5da:
  rts                            ; $F5DA  60

_label_f5db:
  inc z:_var_00ee                ; $F5DB  E6 EE
  lda z:_var_00ee                ; $F5DD  A5 EE
  cmp #$01                       ; $F5DF  C9 01
  bne _label_f5da                ; $F5E1  D0 F7
  lda #$00                       ; $F5E3  A9 00
  sta z:_var_00ee                ; $F5E5  85 EE
  inc z:_var_00eb                ; $F5E7  E6 EB
  lda z:_var_00eb                ; $F5E9  A5 EB
  cmp z:_var_00ef                ; $F5EB  C5 EF
  beq _label_f5fb                ; $F5ED  F0 0C
  dec z:_var_00ec                ; $F5EF  C6 EC
  dec z:_var_00ec                ; $F5F1  C6 EC
  dec z:_var_00ec                ; $F5F3  C6 EC
  lda z:_var_00ec                ; $F5F5  A5 EC
  sta APU_TRI_LO                 ; $F5F7  8D 0A 40
  rts                            ; $F5FA  60

_label_f5fb:
  lda z:_var_00ef                ; $F5FB  A5 EF
  clc                            ; $F5FD  18
  adc #$06                       ; $F5FE  69 06
  sta z:_var_00ef                ; $F600  85 EF
  ldy z:_var_00ed                ; $F602  A4 ED
  lda a:_data_f3e1_indexed,Y     ; $F604  B9 E1 F3
  sta APU_TRI_LO                 ; $F607  8D 0A 40
  sta z:_var_00ec                ; $F60A  85 EC
  lda #$F0                       ; $F60C  A9 F0
  sta APU_TRI_HI                 ; $F60E  8D 0B 40
  inc z:_var_00ed                ; $F611  E6 ED
  lda z:_var_00ed                ; $F613  A5 ED
  cmp #$0E                       ; $F615  C9 0E
  bne _label_f5da                ; $F617  D0 C1
  lda #$00                       ; $F619  A9 00
  sta APU_TRI_LINEAR             ; $F61B  8D 08 40
  sta z:_var_00f3                ; $F61E  85 F3
  rts                            ; $F620  60

_func_f621:
  lda z:_var_00f0                ; $F621  A5 F0
  asl a                          ; $F623  0A
  bcs _label_f669                ; $F624  B0 43
  asl a                          ; $F626  0A
  bcs _label_f5bf                ; $F627  B0 96
  asl a                          ; $F629  0A
  bcs _label_f641                ; $F62A  B0 15
  asl a                          ; $F62C  0A
  bcs _label_f639                ; $F62D  B0 0A
  lda z:_var_00f3                ; $F62F  A5 F3
  asl a                          ; $F631  0A
  asl a                          ; $F632  0A
  bcs _label_f5db                ; $F633  B0 A6
  asl a                          ; $F635  0A
  bcs _label_f655                ; $F636  B0 1D
  rts                            ; $F638  60

_label_f639:
  ldx #$EF                       ; $F639  A2 EF
  ldy #$F3                       ; $F63B  A0 F3
  jsr _func_f35e                 ; $F63D  20 5E F3
  rts                            ; $F640  60

_label_f641:
  ldx #$F3                       ; $F641  A2 F3
  ldy #$F3                       ; $F643  A0 F3
  jsr _func_f36a                 ; $F645  20 6A F3
  lda z:_var_00f3                ; $F648  A5 F3
  ora #$20                       ; $F64A  09 20
  sta z:_var_00f3                ; $F64C  85 F3
  lda #$00                       ; $F64E  A9 00
  sta z:_var_00ef                ; $F650  85 EF
  sta z:_var_00ee                ; $F652  85 EE

_label_f654:
  rts                            ; $F654  60

_label_f655:
  inc z:_var_00ee                ; $F655  E6 EE
  lda z:_var_00ee                ; $F657  A5 EE
  cmp #$02                       ; $F659  C9 02
  bne _label_f654                ; $F65B  D0 F7
  lda #$00                       ; $F65D  A9 00
  sta z:_var_00ee                ; $F65F  85 EE
  inc z:_var_00ef                ; $F661  E6 EF
  lda z:_var_00ef                ; $F663  A5 EF
  cmp #$A0                       ; $F665  C9 A0
  bne _label_f654                ; $F667  D0 EB

_label_f669:
  lda #$10                       ; $F669  A9 10
  sta APU_PL2_VOL                ; $F66B  8D 04 40
  lda z:_var_00f3                ; $F66E  A5 F3
  and #$DF                       ; $F670  29 DF
  sta z:_var_00f3                ; $F672  85 F3
  rts                            ; $F674  60

_label_f675:
  ldx #$F7                       ; $F675  A2 F7
  ldy #$F3                       ; $F677  A0 F3
  jsr _func_f366                 ; $F679  20 66 F3
  lda #$10                       ; $F67C  A9 10
  sta APU_PL1_VOL                ; $F67E  8D 00 40
  lda z:_var_00f3                ; $F681  A5 F3
  and #$F0                       ; $F683  29 F0
  sta z:_var_00f3                ; $F685  85 F3
  rts                            ; $F687  60

_label_f688:
  lda #$00                       ; $F688  A9 00
  sta z:_var_00f3                ; $F68A  85 F3

_label_f68c:
  sta APU_TRI_LINEAR             ; $F68C  8D 08 40
  sta APU_DMC_RAW                ; $F68F  8D 11 40
  sta z:_var_00e6                ; $F692  85 E6
  sta z:_var_00e4                ; $F694  85 E4
  lda #$10                       ; $F696  A9 10
  sta APU_PL1_VOL                ; $F698  8D 00 40
  sta APU_PL2_VOL                ; $F69B  8D 04 40
  sta APU_NOISE_VOL              ; $F69E  8D 0C 40
  rts                            ; $F6A1  60

_label_f6a2:
  ldx #$FB                       ; $F6A2  A2 FB
  ldy #$F3                       ; $F6A4  A0 F3
  jsr _func_f366                 ; $F6A6  20 66 F3
  lda #$00                       ; $F6A9  A9 00
  sta z:_var_00eb                ; $F6AB  85 EB
  lda z:_var_00f3                ; $F6AD  A5 F3
  ora #$08                       ; $F6AF  09 08
  sta z:_var_00f3                ; $F6B1  85 F3

_label_f6b3:
  rts                            ; $F6B3  60

_label_f6b4:
  ldy z:_var_00eb                ; $F6B4  A4 EB
  lda a:_data_f6cb_indexed,Y     ; $F6B6  B9 CB F6
  sta APU_NOISE_LO               ; $F6B9  8D 0E 40
  inc z:_var_00eb                ; $F6BC  E6 EB
  lda z:_var_00eb                ; $F6BE  A5 EB
  cmp #$04                       ; $F6C0  C9 04
  bne _label_f6b3                ; $F6C2  D0 EF
  lda z:_var_00f3                ; $F6C4  A5 F3
  and #$FE                       ; $F6C6  29 FE
  sta z:_var_00f3                ; $F6C8  85 F3
  rts                            ; $F6CA  60

_data_f6cb_indexed:
.byte $00, $02, $01, $00

_func_f6cf:
  lda z:_var_00f0                ; $F6CF  A5 F0
  lsr a                          ; $F6D1  4A
  bcs _label_f688                ; $F6D2  B0 B4
  lsr a                          ; $F6D4  4A
  bcs _label_f6e8                ; $F6D5  B0 11
  lsr a                          ; $F6D7  4A
  bcs _label_f675                ; $F6D8  B0 9B
  lsr a                          ; $F6DA  4A
  bcs _label_f6a2                ; $F6DB  B0 C5
  lda z:_var_00f3                ; $F6DD  A5 F3
  lsr a                          ; $F6DF  4A
  lsr a                          ; $F6E0  4A
  bcs _label_f703                ; $F6E1  B0 20
  lsr a                          ; $F6E3  4A
  lsr a                          ; $F6E4  4A
  bcs _label_f6b4                ; $F6E5  B0 CD
  rts                            ; $F6E7  60

_label_f6e8:
  ldx #$FF                       ; $F6E8  A2 FF
  ldy #$F6                       ; $F6EA  A0 F6
  jsr _func_f366                 ; $F6EC  20 66 F3
  lda #$00                       ; $F6EF  A9 00
  sta z:_var_00ec                ; $F6F1  85 EC
  sta z:_var_00ed                ; $F6F3  85 ED
  sta APU_DMC_RAW                ; $F6F5  8D 11 40
  lda z:_var_00f3                ; $F6F8  A5 F3
  ora #$02                       ; $F6FA  09 02
  sta z:_var_00f3                ; $F6FC  85 F3

_label_f6fe:
  rts                            ; $F6FE  60

.byte $3f, $7f, $0f, $08

_label_f703:
  inc z:_var_00ec                ; $F703  E6 EC
  lda z:_var_00ec                ; $F705  A5 EC
  cmp #$02                       ; $F707  C9 02
  bne _label_f6fe                ; $F709  D0 F3
  lda #$00                       ; $F70B  A9 00
  sta z:_var_00ec                ; $F70D  85 EC
  ldy z:_var_00ed                ; $F70F  A4 ED
  lda a:_data_f731_indexed,Y     ; $F711  B9 31 F7
  sta APU_NOISE_LO               ; $F714  8D 0E 40
  lda a:_data_f761_indexed,Y     ; $F717  B9 61 F7
  sta APU_NOISE_VOL              ; $F71A  8D 0C 40
  inc z:_var_00ed                ; $F71D  E6 ED
  lda z:_var_00ed                ; $F71F  A5 ED
  cmp #$30                       ; $F721  C9 30
  bne _label_f730                ; $F723  D0 0B
  lda #$10                       ; $F725  A9 10
  sta APU_NOISE_VOL              ; $F727  8D 0C 40
  lda z:_var_00f3                ; $F72A  A5 F3
  and #$FD                       ; $F72C  29 FD
  sta z:_var_00f3                ; $F72E  85 F3

_label_f730:
  rts                            ; $F730  60

_data_f731_indexed:
.byte $0e, $0b, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $04, $04, $04, $04
.byte $04, $04, $03, $03, $03, $03, $03, $04, $03, $02, $02, $02, $02, $02, $02, $02
.byte $02, $01, $01, $01, $02, $02, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00

_data_f761_indexed:
.byte $3f, $3f, $3f, $3f, $3f, $3f, $3d, $3c, $38, $38, $38, $37, $37, $37, $36, $36
.byte $34, $34, $34, $34, $34, $34, $34, $34, $33, $33, $33, $33, $33, $33, $33, $33
.byte $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32

_label_f791:
  ldx #$B7                       ; $F791  A2 B7
  ldy #$F5                       ; $F793  A0 F5
  jsr _func_f35e                 ; $F795  20 5E F3
  ldx #$BB                       ; $F798  A2 BB
  ldy #$F5                       ; $F79A  A0 F5

_label_f79c:
  jsr _func_f36a                 ; $F79C  20 6A F3
  rts                            ; $F79F  60

.byte $84, $93, $70, $e3, $84, $93, $72, $e3

_label_f7a8:
  lda #$00                       ; $F7A8  A9 00
  sta APU_PL1_VOL                ; $F7AA  8D 00 40
  ldx #$A0                       ; $F7AD  A2 A0
  ldy #$F7                       ; $F7AF  A0 F7
  jsr _func_f35e                 ; $F7B1  20 5E F3
  ldx #$A4                       ; $F7B4  A2 A4
  ldy #$F7                       ; $F7B6  A0 F7
  bne _label_f79c                ; $F7B8  D0 E2

_label_f7ba:
  ldy #$06                       ; $F7BA  A0 06
  lda #$80                       ; $F7BC  A9 80
  bne _label_f82f                ; $F7BE  D0 6F

_label_f7c0:
  ldy #$04                       ; $F7C0  A0 04
  lda #$04                       ; $F7C2  A9 04
  bne _label_f826                ; $F7C4  D0 60

_label_f7c6:
  ldy #$05                       ; $F7C6  A0 05
  lda #$08                       ; $F7C8  A9 08
  bne _label_f826                ; $F7CA  D0 5A

_func_f7cc:
  lda z:_var_00f1                ; $F7CC  A5 F1
  lsr a                          ; $F7CE  4A
  bcs _label_f7fd                ; $F7CF  B0 2C
  lsr a                          ; $F7D1  4A
  bcs _label_f803                ; $F7D2  B0 2F
  lsr a                          ; $F7D4  4A
  bcs _label_f7c0                ; $F7D5  B0 E9
  lsr a                          ; $F7D7  4A
  bcs _label_f7c6                ; $F7D8  B0 EC
  lsr a                          ; $F7DA  4A
  bcs _label_f809                ; $F7DB  B0 2C
  lsr a                          ; $F7DD  4A
  bcs _label_f80f                ; $F7DE  B0 2F
  lsr a                          ; $F7E0  4A
  bcs _label_f815                ; $F7E1  B0 32
  lsr a                          ; $F7E3  4A
  bcs _label_f7ba                ; $F7E4  B0 D4
  lda z:_var_00f2                ; $F7E6  A5 F2
  asl a                          ; $F7E8  0A
  bcs _label_f81b                ; $F7E9  B0 30
  asl a                          ; $F7EB  0A
  asl a                          ; $F7EC  0A
  bcs _label_f791                ; $F7ED  B0 A2
  asl a                          ; $F7EF  0A
  bcs _label_f840                ; $F7F0  B0 4E
  asl a                          ; $F7F2  0A
  bcs _label_f7a8                ; $F7F3  B0 B3
  lda z:_var_00e6                ; $F7F5  A5 E6
  bne _label_f7fa                ; $F7F7  D0 01
  rts                            ; $F7F9  60

_label_f7fa:
  jmp _label_f40f                ; $F7FA  4C 0F F4

_label_f7fd:
  ldy #$00                       ; $F7FD  A0 00
  lda #$01                       ; $F7FF  A9 01
  bne _label_f826                ; $F801  D0 23

_label_f803:
  ldy #$03                       ; $F803  A0 03
  lda #$02                       ; $F805  A9 02
  bne _label_f82f                ; $F807  D0 26

_label_f809:
  ldy #$01                       ; $F809  A0 01
  lda #$10                       ; $F80B  A9 10
  bne _label_f826                ; $F80D  D0 17

_label_f80f:
  ldy #$07                       ; $F80F  A0 07
  lda #$20                       ; $F811  A9 20
  bne _label_f826                ; $F813  D0 11

_label_f815:
  ldy #$02                       ; $F815  A0 02
  lda #$40                       ; $F817  A9 40
  bne _label_f826                ; $F819  D0 0B

_label_f81b:
  lda #$10                       ; $F81B  A9 10
  sta APU_NOISE_VOL              ; $F81D  8D 0C 40
  ldy #$08                       ; $F820  A0 08
  lda #$EF                       ; $F822  A9 EF
  bne _label_f82f                ; $F824  D0 09

_label_f826:
  jsr _func_f383                 ; $F826  20 83 F3
  ldx #$C0                       ; $F829  A2 C0
  ldy #$C0                       ; $F82B  A0 C0
  bne _label_f836                ; $F82D  D0 07

_label_f82f:
  jsr _func_f383                 ; $F82F  20 83 F3
  ldx #$86                       ; $F832  A2 86
  ldy #$86                       ; $F834  A0 86

_label_f836:
  jsr _func_f3d0                 ; $F836  20 D0 F3
  lda #$00                       ; $F839  A9 00
  sta z:_var_00e4                ; $F83B  85 E4
  jmp _label_f40f                ; $F83D  4C 0F F4

_label_f840:
  ldy #$09                       ; $F840  A0 09
  lda #$EF                       ; $F842  A9 EF
  bne _label_f826                ; $F844  D0 E0

_data_f846_indexed:
  asl a                          ; $F846  0A

_data_f847_indexed:
  slo (_var_001c_indexed),Y      ; $F847  13 1C

_data_f849_indexed:
  and z:$2E                      ; $F849  25 2E

_data_f84b_indexed:
  rla z:_var_0040_indexed,X      ; $F84B  37 40

_data_f84d_indexed:
  eor #$52                       ; $F84D  49 52
  sre a:_data_c306_indexed+1,Y   ; $F84F  5B 07 C3
  sed                            ; $F852  F8
.byte $e2, $f8                   ; $F853  E2 F8  disambiguous instruction: nop #$F8
  php                            ; $F855  08
  sbc a:_data_f91b_indexed,Y     ; $F856  F9 1B F9
  slo z:_var_002f                ; $F859  07 2F
  sbc a:_data_f960_indexed,Y     ; $F85B  F9 60 F9
  lda (_var_00f9_indexed,X)      ; $F85E  A1 F9
  cpy a:$07F9                    ; $F860  CC F9 07
  lax a:_data_caf9+1             ; $F863  AF FA CA
.byte $fa                        ; $F866  FA  disambiguous instruction: nop
  cpx z:_var_00fa_indexed        ; $F867  E4 FA
  sbc z:_var_00fa_indexed,X      ; $F869  F5 FA
  slo z:_var_00da                ; $F86B  07 DA
  sbc a:_data_f9f7_indexed,Y     ; $F86D  F9 F7 F9
  slo (_var_00fa_indexed),Y      ; $F870  13 FA
  plp                            ; $F872  28
.byte $fa                        ; $F873  FA  disambiguous instruction: nop
  slo z:_var_002f                ; $F874  07 2F
.byte $fa                        ; $F876  FA  disambiguous instruction: nop
  rla a:_var_64fa_indexed,X      ; $F877  3F FA 64
.byte $fa                        ; $F87A  FA  disambiguous instruction: nop
.byte $80, $fa                   ; $F87B  80 FA  disambiguous instruction: nop #$FA
  slo z:_var_0091                ; $F87D  07 91
.byte $fa                        ; $F87F  FA  disambiguous instruction: nop
  txs                            ; $F880  9A
.byte $fa                        ; $F881  FA  disambiguous instruction: nop
  lax z:_var_00fa_indexed        ; $F882  A7 FA
  brk                            ; $F884  00
  brk                            ; $F885  00
  slo z:TargetShot                ; $F886  07 BD
  sed                            ; $F888  F8
  brk                            ; $F889  00
  brk                            ; $F88A  00
  brk                            ; $F88B  00
  brk                            ; $F88C  00
  brk                            ; $F88D  00
  brk                            ; $F88E  00
  brk                            ; $F88F  00
  rol z:_var_00f9_indexed        ; $F890  26 F9
  rol a                          ; $F892  2A
  sbc a:_var_0000_indexed,Y      ; $F893  F9 00 00
  brk                            ; $F896  00
  brk                            ; $F897  00
  brk                            ; $F898  00
  tax                            ; $F899  AA
  sed                            ; $F89A  F8
  lda (_var_00f8_indexed),Y      ; $F89B  B1 F8
  lax z:_var_00f8_indexed,Y      ; $F89D  B7 F8
  brk                            ; $F89F  00
  brk                            ; $F8A0  00
  brk                            ; $F8A1  00
  brk                            ; $F8A2  00
  isc a:_data_ff18_indexed,X     ; $F8A3  FF 18 FF
  brk                            ; $F8A6  00
  brk                            ; $F8A7  00
  brk                            ; $F8A8  00
  brk                            ; $F8A9  00
  sta z:$3E                      ; $F8AA  85 3E
.byte $3c, $3a, $38              ; $F8AC  3C 3A 38  disambiguous instruction: nop $383A,X
  rol z:_var_0000_indexed,X      ; $F8AF  36 00
  sta z:_var_0044_indexed        ; $F8B1  85 44

.byte $42, $40, $3e, $3c, $85, $3e, $3c, $3a, $38, $36, $c3, $80, $10, $4e, $ff, $00
.byte $84, $02, $81, $02, $2a, $2a, $02, $2c, $02, $2c, $02, $2e, $30, $02, $22, $83
.byte $02, $81, $02, $08, $02, $02, $06, $02, $06, $02, $28, $2a, $02, $22, $00, $84
.byte $02, $81, $02, $80, $46, $46, $81, $46, $02, $1c, $1e, $20, $22, $80, $28, $28
.byte $81, $2a, $02, $40, $83, $02, $81, $02, $30, $02, $02, $80, $2c, $2c, $81, $1e
.byte $20, $22, $30, $83, $02, $c6, $80, $0c, $02, $0c, $02, $18, $02, $18, $02, $4c
.byte $02, $4c, $02, $18, $02, $18, $02, $ff

_data_f91b_indexed:
.byte $c6, $81, $03, $03, $06, $06, $03, $03, $06, $03, $ff, $81, $16, $4a, $00, $80
.byte $02, $81, $16, $4a, $81, $0c, $0c, $12, $02, $0c, $02, $12, $02, $0e, $0e, $16
.byte $02, $0e, $02, $16, $02, $0c, $0c, $12, $02, $0c, $02, $12, $02, $12, $10, $0e
.byte $0c, $08, $04, $30, $02, $80, $04, $04, $81, $08, $0a, $0c, $80, $0e, $0e, $81
.byte $12, $16, $18, $48, $00

_data_f960_indexed:
.byte $80, $04, $04, $81, $04, $22, $28, $04, $22, $24, $28, $80, $2c, $2c, $81, $2c
.byte $24, $2c, $04, $2c, $80, $04, $30, $2c, $28, $80, $04, $04, $81, $22, $24, $10
.byte $28, $2a, $2c, $2e, $80, $30, $30, $81, $2e, $2c, $28, $80, $24, $24, $81, $22
.byte $1e, $02, $80, $22, $22, $81, $24, $26, $28, $80, $2c, $2c, $81, $30, $04, $08
.byte $0c, $81, $1a, $1a, $02, $20, $22, $02, $3e, $02, $3a, $3a, $02, $40, $42, $02
.byte $1a, $42, $1a, $32, $02, $34, $36, $38, $3a, $02, $3e, $82, $3e, $81, $42, $44
.byte $46, $3e, $02, $1a, $1a, $02, $38, $3a, $3a, $02, $3a, $1a, $c8, $81, $06, $03
.byte $06, $80, $09, $03, $81, $03, $03, $82, $0c, $ff, $81, $2a, $2a, $28, $02, $26
.byte $02, $24, $02, $85, $22, $81, $24, $83, $02, $81, $02, $0e, $06, $2a, $2a, $28
.byte $26, $24, $85, $22, $81, $24, $00

_data_f9f7_indexed:
.byte $81, $24, $24, $22, $02, $20, $02, $1e, $02, $85, $3e, $81, $40, $83, $02, $81
.byte $02, $2a, $24, $1c, $1a, $46, $44, $40, $85, $3e, $81, $40, $84, $02, $85, $1a
.byte $81, $1c, $83, $02, $81, $02, $4a, $14, $0e, $0a, $08, $06, $04, $85, $1a, $81
.byte $1c, $cc, $81, $06, $06, $09, $03, $ff, $82, $08, $10, $16, $48, $18, $02, $12
.byte $02, $10, $0c, $08, $06, $81, $08, $00, $81, $26, $26, $82, $2c, $81, $08, $0c
.byte $10, $16, $80, $12, $12, $81, $28, $10, $0c, $30, $2e, $30, $04, $80, $2c, $2c
.byte $81, $08, $28, $30, $80, $26, $26, $81, $2c, $22, $2c, $82, $26, $85, $1e, $81
.byte $1e, $82, $3c, $3c, $85, $3e, $81, $3e, $85, $3e, $81, $3e, $85, $42, $81, $42
.byte $85, $42, $81, $42, $82, $1e, $81, $1e, $1e, $c4, $81, $06, $82, $0c, $81, $06
.byte $80, $09, $03, $03, $03, $09, $03, $03, $03, $ff, $81, $0a, $24, $26, $28, $2e
.byte $0a, $04, $00, $80, $12, $12, $81, $0a, $0a, $80, $20, $20, $81, $28, $2e, $2a
.byte $81, $20, $02, $20, $28, $02, $28, $2a, $82, $02, $81, $0e, $08, $04, $2c, $2a
.byte $28, $24, $1e, $1c, $1a, $1e, $24, $2e, $24, $2c, $04, $28, $2e, $08, $28, $30
.byte $0e, $0c, $00, $82, $02, $81, $2c, $2c, $02, $02, $1e, $02, $02, $02, $02, $02
.byte $44, $1e, $24, $42, $1a, $2c, $44, $1e, $24, $46, $1e, $1e, $28, $82, $1e, $81
.byte $1e, $85, $22, $24, $3c, $82, $3e, $81, $3e, $85, $42, $44, $46, $1a, $c5, $81
.byte $06, $06, $06, $09, $03, $06, $ff, $ff, $ff, $55, $ad, $4a, $55, $d5, $aa, $52
.byte $55, $ad, $2a, $55, $b5, $2a, $49, $bb, $55, $45, $a9, $6e, $53, $44, $b5, $6b
.byte $15, $a5, $da, $56, $49, $a4, $fb, $96, $10, $d5, $fa, $4a, $50, $b6, $5b, $45
.byte $b2, $b6, $4b, $01, $e9, $ff, $45, $00, $ba, $ff, $01, $90, $fe, $57, $04, $b5
.byte $2f, $01, $b5, $ff, $01, $44, $fe, $1f, $01, $b0, $ff, $17, $00, $e8, $ff, $17
.byte $00, $fa, $7f, $01, $50, $fb, $1b, $41, $ea, $bf, $04, $50, $fb, $2f, $01, $d2
.byte $fe, $4b, $00, $f8, $ff, $05, $40, $fb, $4f, $40, $ea, $2b, $55, $b5, $2b, $11
.byte $d1, $fe, $45, $44, $6d, $55, $d5, $6a, $45, $d4, $fa, $2a, $49, $45, $51, $ff
.byte $6e, $04, $a0, $fe, $1f, $01, $11, $fb, $bf, $12, $10, $b5, $ff, $4a, $04, $c0
.byte $fe, $7f, $00, $a8, $ff, $15, $95, $04, $b8, $ff, $4b, $04, $e4, $fe, $17, $00
.byte $f8, $ff, $03, $00, $ee, $ff, $07, $00, $e8, $ff, $17, $00, $e8, $ff, $1f, $00
.byte $f0, $ff, $03, $00, $fe, $ff, $00, $80, $ff, $1f, $00, $f0, $ff, $1f, $00, $e0
.byte $ff, $0f, $00, $e8, $ff, $07, $00, $fe, $ff, $01, $00, $ff, $7f, $00, $a0, $ff
.byte $0f, $00, $f8, $ff, $03, $00, $fe, $7f, $00, $e0, $ff, $0f, $00, $f8, $ff, $01
.byte $80, $ff, $1f, $00, $f8, $ff, $03, $00, $fe, $1f, $00, $fe, $7f, $01, $80, $ff
.byte $07, $c0, $fe, $3f, $00, $d8, $7f, $00, $f8, $ff, $17, $00, $f8, $0f, $80, $ff
.byte $7f, $01, $80, $7f, $40, $b5, $fe, $3f, $00, $e8, $03, $f4, $bf, $e4, $5e, $01
.byte $10, $ee, $bf, $90, $ff, $05, $00, $fc, $7f, $00, $f8, $7f, $00, $f0, $ff, $01
.byte $e0, $ff, $04, $a0, $ff, $07, $80, $fe, $0f, $00, $ff, $1f, $00, $f8, $ff, $00
.byte $e0, $ff, $05, $a0, $ff, $07, $00, $fe, $3f, $00, $fa, $3f, $00, $f8, $ff, $00
.byte $ed, $17, $00, $fb, $5f, $a0, $fb, $13, $00, $fc, $3f, $00, $fb, $3f, $00, $e8
.byte $ff, $00, $e0, $ff, $07, $00, $ff, $0f, $00, $ff, $7f, $00, $e0, $7f, $01, $f0
.byte $ff, $07, $00, $fe, $1f, $00, $f8, $ff, $01, $80, $ff, $07, $80, $ff, $7f, $00
.byte $e0, $ff, $01, $a0, $ff, $0f, $00, $fa, $7f, $00, $e8, $ff, $01, $80, $ff, $1f
.byte $00, $f8, $ff, $01, $80, $ff, $1f, $00, $f8, $ff, $01, $a0, $ff, $0f, $00, $f8
.byte $ff, $01, $a0, $ff, $1f, $00, $f0, $ff, $05, $e0, $bf, $12, $00, $f8, $ff, $07
.byte $80, $fe, $3f, $00, $11, $ea, $fe, $17, $e8, $aa, $ee, $04, $a9, $15, $81, $fb
.byte $5f, $51, $a4, $fb, $01, $a0, $ff, $03, $40, $fe, $ff, $00, $c0, $ff, $47, $00
.byte $eb, $5f, $00, $b4, $ff, $0f, $00, $ec, $ff, $05, $80, $ee, $57, $11, $d5, $be
.byte $45, $a4, $d6, $aa, $54, $55, $d5, $54, $aa, $ba, $52, $d5, $b6, $54, $4a, $a9
.byte $2a, $55, $bb, $4d, $a5, $94, $6a, $ab, $4a, $55, $ad, $2b, $11, $a9, $ae, $b7
.byte $44, $da, $56, $15, $91, $fa, $ab, $14, $a5, $ad, $4a, $a4, $be, $ab, $14, $49
.byte $eb, $56, $25, $d1, $6e, $4b, $91, $54, $eb, $aa, $52, $55, $55, $53, $55, $55
.byte $55, $ab, $aa, $54, $55, $55, $ab, $aa, $54, $55, $d5, $52, $a9, $ae, $2b, $45
.byte $52, $6b, $ab, $aa, $aa, $52, $55, $55, $b5, $aa, $52, $d5, $52, $55, $55, $ad
.byte $a6, $52, $55, $55, $d5, $aa, $2a, $55, $95, $aa, $ed, $4a, $91, $d4, $6a, $ab
.byte $aa, $2a, $55, $55, $55, $55, $55, $d5, $aa, $54, $59, $ab, $2a, $55, $55, $55
.byte $55, $ad, $aa, $14, $b5, $bb, $46, $44, $d5, $ba, $aa, $aa, $52, $a5, $6a, $d5
.byte $2a, $55, $55, $2b, $55, $d5, $aa, $52, $95, $6a, $b5, $aa, $2a, $45, $ea, $7b
.byte $15, $41, $aa, $db, $5a, $95, $52, $a5, $55, $d5, $54, $55, $b5, $aa, $aa, $aa
.byte $54, $aa, $da, $5a, $a9, $54, $a9, $d4, $ee, $55, $04, $a9, $eb, $5a, $4a, $55
.byte $b5, $52, $55, $5a, $55, $ad, $56, $15, $91, $ba, $6b, $55, $49, $a9, $b6, $44
.byte $b9, $bf, $44, $a0, $ba, $6b, $52, $d5, $aa, $4a, $a9, $aa, $ad, $aa, $2b, $11
.byte $a9, $be, $2e, $45, $69, $6b, $49, $90, $fe, $5f, $00, $e8, $3f, $05, $b5, $af
.byte $12, $51, $6d, $ab, $54, $db, $12, $91, $fa, $56, $52, $6d, $53, $44, $c4, $ff
.byte $17, $00, $fd, $13, $a4, $ef, $46, $a8, $56, $95, $d5, $aa, $aa, $4a, $b2, $b6
.byte $52, $b5, $2d, $11, $91, $fe, $1f, $80, $be, $12, $ed, $4e, $52, $ad, $44, $ed
.byte $47, $50, $6f, $05, $ed, $2a, $a5, $db, $12, $41, $fa, $3f, $c0, $2e, $91, $be
.byte $15, $b5, $13, $94, $fb, $12, $65, $4b, $a9, $ad, $aa, $52, $b5, $16, $01, $ff
.byte $0f, $f0, $03, $f4, $17, $ea, $17, $c4, $5a, $b5, $15, $a9, $55, $a5, $6d, $45
.byte $ec, $5a, $04, $f9, $5f, $a0, $17, $e0, $1f, $f8, $17, $e8, $12, $f9, $47, $e8
.byte $12, $bb, $aa, $2a, $a9, $5b, $01, $fa, $1f, $f8, $04, $f8, $07, $fe, $44, $5b
.byte $90, $7b, $51, $4b, $b4, $1b, $ea, $96, $5a, $11, $e0, $ff, $c1, $16, $d0, $4f
.byte $ec, $93, $5a, $44, $ed, $56, $94, $aa, $5a, $ab, $aa, $49, $a9, $80, $ff, $87
.byte $16, $d0, $5e, $ba, $aa, $96, $94, $aa, $5b, $54, $aa, $6a, $ab, $55, $49, $15
.byte $e0, $ff, $45, $05, $aa, $57, $ad, $5a, $49, $95, $ea, $55, $94, $b4, $da, $56
.byte $a5, $b4, $04, $f8, $7f, $52, $90, $ba, $56, $ab, $95, $52, $a9, $6e, $25, $49
.byte $6d, $b5, $56, $aa, $12, $a0, $ff, $17, $11, $69, $6b, $b5, $56, $49, $a5, $ea
.byte $4d, $11, $d5, $d6, $5a, $a9, $26, $01, $fe, $5f, $44, $a4, $b6, $b5, $56, $25
.byte $a5, $ea, $36, $45, $54, $6b, $ab, $55, $55, $00, $fe, $3f, $41, $92, $b6, $d6
.byte $5a, $55, $14, $b5, $bb, $14, $91, $ee, $aa, $55, $aa, $04, $f8, $ff, $10, $52
.byte $da, $da, $5a, $55, $94, $b4, $bb, $14, $54, $eb, $aa, $5a, $55, $00, $fe, $3f
.byte $41, $51, $b6, $da, $6a, $95, $94, $b4, $bb, $12, $54, $ed, $aa, $56, $55, $00
.byte $fe, $5f, $44, $52, $ad, $b6, $6a, $95, $94, $aa, $5b, $15, $51, $eb, $aa, $aa
.byte $55, $01, $fa, $5f, $44, $4a, $ab, $d6, $aa, $87, $04, $28, $04, $28, $04, $0c
.byte $04, $0c, $04, $0c, $12, $0c, $12, $0c, $12, $48, $12, $48, $12, $48, $80, $02
.byte $00

_data_ff18_indexed:
.byte $80, $02, $87, $04, $28, $04, $28, $04, $0c, $04, $0c, $04, $0c, $12, $0c, $12
.byte $0c, $12, $48, $12, $48, $12, $48, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff

.segment "TILES"

.byte $00, $00, $00, $01, $02, $03, $03, $05, $00, $00, $00, $00, $00, $01, $01, $00
.byte $00, $60, $e0, $e0, $e0, $e0, $e0, $e0, $00, $20, $60, $e0, $60, $e0, $e0, $e0
.byte $00, $00, $00, $04, $0e, $0e, $0e, $0e, $00, $00, $00, $1a, $31, $71, $75, $75
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $60, $e0, $e0, $c0, $80
.byte $07, $07, $07, $03, $03, $01, $01, $00, $03, $03, $03, $01, $01, $00, $00, $00
.byte $f0, $f0, $f0, $f9, $fb, $f7, $cf, $bf, $f0, $f0, $f0, $f8, $fb, $ff, $ff, $ff
.byte $04, $00, $00, $c1, $e3, $ef, $df, $fe, $7b, $7f, $fe, $3d, $93, $ce, $dc, $f8
.byte $1e, $7c, $f0, $e0, $c0, $80, $00, $00, $1e, $60, $c0, $80, $00, $00, $00, $00
.byte $00, $00, $00, $01, $01, $01, $03, $0f, $00, $00, $00, $01, $01, $01, $03, $0f
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $f8
.byte $fc, $fc, $f8, $f0, $e0, $c0, $00, $00, $f8, $f0, $f0, $e0, $c0, $80, $00, $00
.byte $07, $03, $01, $00, $00, $00, $00, $00, $02, $00, $06, $0e, $0e, $04, $00, $00
.byte $fe, $fc, $f0, $00, $00, $00, $00, $00, $e0, $00, $08, $38, $70, $f0, $f0, $60
.byte $00, $00, $04, $0e, $0e, $0e, $0e, $04, $00, $00, $1a, $31, $71, $75, $75, $7b
.byte $00, $50, $70, $38, $3c, $7c, $78, $f8, $00, $50, $70, $30, $21, $63, $67, $e7
.byte $00, $00, $00, $1f, $ff, $7f, $0f, $07, $00, $00, $00, $1f, $3f, $07, $03, $03
.byte $00, $00, $01, $03, $c7, $ef, $df, $bf, $00, $00, $00, $03, $c7, $ff, $ff, $ff
.byte $00, $00, $c0, $e0, $e0, $c0, $e0, $ff, $7f, $fe, $3c, $90, $c0, $c0, $e0, $ff
.byte $03, $03, $01, $01, $01, $03, $0f, $07, $01, $01, $01, $01, $01, $03, $0f, $02
.byte $7f, $ff, $ff, $ff, $ff, $ff, $fe, $fe, $ff, $ff, $ff, $ff, $ff, $ff, $f8, $e0
.byte $ff, $ff, $ff, $ff, $ff, $c7, $03, $00, $ff, $ff, $ff, $ff, $c7, $01, $00, $00
.byte $c0, $f0, $f8, $fc, $ff, $ee, $b0, $c0, $c0, $f0, $f8, $fc, $ee, $a0, $00, $00
.byte $03, $01, $00, $00, $00, $00, $00, $00, $00, $06, $0e, $0e, $04, $00, $00, $00
.byte $fc, $f0, $00, $00, $00, $00, $00, $00, $00, $08, $38, $70, $f0, $f0, $60, $00
.byte $00, $04, $0e, $0e, $0e, $0e, $04, $00, $00, $1a, $31, $71, $75, $75, $7b, $7f
.byte $f8, $fc, $ff, $ff, $ff, $ff, $ff, $ff, $67, $b3, $b0, $d0, $f0, $f8, $f8, $f8
.byte $00, $00, $00, $00, $00, $00, $01, $03, $00, $00, $00, $00, $00, $00, $01, $03
.byte $00, $01, $03, $07, $0f, $bf, $7f, $ff, $00, $00, $03, $07, $3f, $ff, $ff, $ff
.byte $00, $c0, $e0, $e0, $c0, $c0, $80, $80, $fe, $3c, $90, $c0, $c0, $c0, $80, $80
.byte $07, $07, $0d, $1d, $33, $0f, $07, $03, $06, $05, $09, $11, $03, $0f, $02, $00
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fb, $f3, $e5, $01
.byte $c0, $c0, $e0, $e0, $f0, $f0, $f0, $f0, $c0, $c0, $e0, $e0, $f0, $f0, $f0, $f0
.byte $01, $00, $00, $00, $00, $00, $00, $00, $06, $0e, $0e, $04, $00, $00, $00, $00
.byte $f3, $01, $01, $01, $00, $00, $00, $00, $09, $38, $70, $f0, $f0, $60, $00, $00
.byte $f0, $f8, $f8, $f8, $fc, $fc, $7e, $1e, $f0, $f8, $f8, $78, $7c, $3c, $0e, $02
.byte $18, $38, $3c, $3c, $3e, $5e, $7f, $7f, $18, $18, $1c, $1c, $1e, $0e, $3f, $3f
.byte $3f, $3f, $3f, $1f, $0f, $07, $03, $01, $1f, $1f, $0f, $07, $07, $03, $01, $00
.byte $00, $00, $01, $03, $04, $00, $00, $00, $00, $00, $00, $00, $03, $07, $0f, $0f
.byte $00, $00, $03, $03, $83, $c3, $e7, $ff, $0f, $0f, $04, $01, $83, $c3, $e7, $ff
.byte $ff, $ff, $ff, $ff, $ff, $2f, $1f, $1f, $ff, $ff, $ff, $ff, $3f, $0f, $1f, $1f
.byte $1f, $1f, $1f, $0f, $07, $03, $00, $00, $1f, $0e, $04, $00, $08, $1c, $1c, $0c
.byte $00, $0f, $3f, $ff, $ff, $bf, $7f, $19, $00, $0f, $3f, $ff, $7f, $3f, $19, $00
.byte $00, $01, $03, $04, $00, $00, $00, $00, $00, $00, $00, $03, $07, $0f, $0f, $0f
.byte $00, $03, $03, $03, $03, $83, $e7, $ff, $0f, $04, $01, $03, $03, $83, $e7, $ff
.byte $ff, $ff, $ff, $ff, $6f, $1f, $1f, $1f, $ff, $ff, $ff, $7f, $0f, $1f, $1f, $1f
.byte $1f, $1f, $0f, $07, $03, $00, $00, $00, $0e, $04, $00, $08, $1c, $1c, $1c, $0c
.byte $00, $00, $01, $01, $03, $07, $0f, $00, $00, $00, $01, $01, $03, $06, $08, $00
.byte $01, $03, $04, $00, $00, $00, $00, $01, $00, $00, $03, $07, $0f, $0f, $0f, $0e
.byte $03, $03, $03, $03, $03, $07, $0f, $1f, $04, $01, $03, $03, $03, $07, $0f, $1f
.byte $3f, $3f, $77, $6f, $ff, $ff, $ff, $ff, $3f, $3f, $7f, $7f, $ff, $df, $df, $8e
.byte $df, $8f, $07, $03, $00, $00, $00, $00, $04, $00, $08, $1c, $1c, $1c, $0c, $00
.byte $00, $40, $60, $30, $00, $00, $00, $01, $00, $40, $60, $30, $00, $00, $00, $01
.byte $80, $00, $00, $00, $00, $00, $c0, $f0, $80, $00, $00, $00, $00, $00, $c0, $f1
.byte $0c, $1e, $1f, $3f, $3f, $3f, $3e, $1e, $00, $00, $00, $00, $0c, $4c, $c1, $e1
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $38, $3c, $7c, $f8, $e0
.byte $03, $07, $0f, $0f, $1f, $1f, $1d, $18, $03, $07, $0f, $0f, $1d, $1c, $10, $00
.byte $f8, $fc, $fc, $fc, $fe, $be, $1e, $0f, $f9, $fd, $fd, $bc, $3e, $1e, $0e, $07
.byte $0c, $00, $00, $00, $00, $40, $f8, $f0, $f3, $ff, $ff, $ff, $7e, $3c, $80, $c0
.byte $00, $00, $00, $00, $00, $00, $00, $00, $80, $80, $e0, $70, $10, $00, $00, $00
.byte $07, $07, $43, $c3, $87, $07, $07, $07, $03, $03, $43, $c3, $87, $06, $04, $04
.byte $fb, $ff, $ff, $ff, $ff, $fc, $fc, $fc, $fb, $ff, $ff, $c7, $04, $00, $00, $00
.byte $e1, $f3, $f8, $fc, $fc, $7c, $1c, $18, $e1, $f3, $f8, $fc, $7c, $1c, $08, $00
.byte $1f, $03, $07, $07, $06, $00, $00, $00, $f0, $ec, $f8, $70, $36, $00, $00, $00
.byte $e0, $80, $80, $00, $00, $00, $00, $00, $06, $6f, $3e, $1c, $18, $00, $00, $00
.byte $00, $00, $00, $00, $00, $01, $03, $03, $00, $00, $00, $00, $00, $00, $02, $02
.byte $00, $03, $17, $3f, $7f, $fe, $fe, $fc, $00, $03, $17, $3b, $53, $86, $06, $04
.byte $03, $03, $03, $07, $07, $07, $07, $1f, $00, $00, $00, $00, $00, $00, $00, $18
.byte $fc, $f8, $f8, $f8, $f8, $f0, $f3, $ff, $0c, $08, $08, $08, $18, $10, $12, $1e
.byte $00, $00, $04, $0e, $0e, $0e, $0e, $04, $00, $00, $1a, $31, $73, $f3, $f1, $fb
.byte $00, $17, $0f, $07, $03, $01, $01, $00, $00, $17, $0f, $03, $01, $00, $00, $00
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $f8, $f8, $f8, $f8, $f8, $70, $00, $00
.byte $ff, $ff, $ff, $ff, $fc, $f8, $f0, $c0, $3e, $3e, $3f, $0f, $00, $00, $00, $00
.byte $00, $80, $80, $00, $00, $00, $00, $00, $ff, $7e, $40, $00, $00, $00, $00, $00
.byte $7f, $0c, $00, $00, $00, $00, $00, $00, $00, $10, $f8, $f0, $e0, $40, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $80, $f0, $f8, $f8, $00, $00, $00
.byte $00, $80, $00, $18, $20, $22, $24, $3c, $00, $e0, $f0, $f8, $f8, $fe, $fc, $f8
.byte $7c, $3d, $3b, $27, $2f, $1f, $1f, $1f, $c8, $c4, $dc, $f9, $f0, $e4, $e0, $e0
.byte $3f, $3f, $3f, $3f, $3c, $00, $ff, $f8, $cc, $ca, $c8, $c0, $40, $00, $ff, $f8
.byte $00, $00, $00, $00, $00, $30, $78, $78, $00, $00, $00, $00, $00, $30, $68, $70
.byte $f8, $f0, $f8, $f8, $f8, $f8, $f8, $f0, $78, $70, $30, $00, $00, $90, $00, $00
.byte $f0, $e0, $c0, $00, $00, $00, $e0, $00, $00, $00, $00, $00, $00, $00, $e0, $00
.byte $00, $00, $80, $40, $30, $08, $04, $04, $e0, $f0, $78, $3c, $0e, $07, $03, $03
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $03, $03, $07, $07
.byte $80, $80, $00, $00, $00, $00, $00, $00, $60, $60, $70, $fe, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $80, $c0, $e0, $f8
.byte $00, $00, $00, $00, $00, $00, $00, $00, $0f, $0f, $0f, $0f, $0f, $07, $07, $07
.byte $00, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $01, $02, $02, $00, $e0, $f8, $fc, $fe, $ff, $ff, $ff
.byte $00, $07, $0f, $0f, $1f, $1f, $1f, $3f, $00, $07, $0f, $0f, $1f, $3f, $ff, $ff
.byte $00, $80, $00, $18, $20, $20, $22, $3c, $00, $e0, $f0, $f8, $f8, $f8, $fe, $fc
.byte $00, $00, $00, $00, $00, $00, $00, $00, $0f, $1f, $3f, $7f, $7f, $7f, $7c, $78
.byte $01, $02, $04, $0f, $3f, $1f, $1f, $0f, $fe, $fd, $fb, $f0, $c0, $00, $00, $00
.byte $00, $00, $00, $00, $80, $c0, $64, $34, $ff, $ff, $ff, $ff, $7f, $3f, $1b, $0b
.byte $04, $04, $04, $04, $04, $04, $06, $06, $ff, $ff, $ff, $ff, $ff, $ff, $fb, $fb
.byte $3e, $3e, $3e, $7e, $7e, $7e, $7e, $7e, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $7c, $3c, $3d, $13, $2f, $0f, $1f, $1f, $c8, $c0, $ce, $fc, $f0, $f0, $e2, $e0
.byte $0c, $1e, $fe, $fe, $fc, $fc, $fc, $fc, $0c, $1a, $3c, $3e, $9c, $00, $40, $10
.byte $00, $00, $00, $00, $20, $c0, $00, $ff, $78, $78, $f8, $f8, $f8, $f0, $e0, $ff
.byte $0e, $0f, $0f, $0f, $07, $07, $3f, $ff, $00, $00, $00, $00, $00, $00, $3c, $ff
.byte $1e, $06, $87, $e7, $f7, $f7, $f1, $ff, $01, $01, $00, $00, $40, $20, $21, $ff
.byte $02, $00, $00, $80, $c0, $e0, $e0, $fe, $ff, $fc, $fe, $7f, $3f, $1f, $9f, $ff
.byte $7e, $7e, $3e, $06, $00, $10, $08, $08, $ff, $7f, $3f, $fe, $fc, $fe, $fe, $fe
.byte $3f, $3f, $3f, $3f, $3f, $3c, $ff, $fc, $c1, $c0, $cc, $ce, $4c, $00, $ff, $fc
.byte $f8, $f8, $f0, $e0, $00, $00, $f0, $00, $00, $00, $00, $00, $00, $00, $f0, $00
.byte $00, $00, $00, $00, $00, $00, $08, $08, $00, $00, $00, $00, $00, $0c, $06, $06
.byte $04, $04, $00, $00, $00, $00, $00, $00, $02, $02, $0e, $1e, $3c, $78, $70, $70
.byte $00, $00, $00, $00, $00, $00, $00, $00, $60, $60, $fc, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $01, $01, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $fe
.byte $00, $00, $00, $00, $00, $00, $00, $03, $07, $07, $0f, $0f, $0f, $07, $03, $00
.byte $02, $0c, $3e, $3b, $01, $00, $00, $00, $fd, $f3, $c1, $c0, $e0, $f0, $f0, $f8
.byte $00, $00, $00, $00, $80, $c4, $64, $34, $ff, $ff, $ff, $ff, $7f, $3b, $1b, $0b
.byte $04, $04, $04, $04, $04, $04, $02, $0a, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $f7
.byte $01, $01, $01, $00, $00, $00, $01, $07, $00, $00, $00, $00, $00, $00, $01, $07
.byte $00, $90, $90, $a6, $cf, $7f, $ff, $ff, $f8, $78, $78, $78, $34, $02, $82, $ff
.byte $1c, $06, $02, $02, $02, $00, $0f, $ff, $03, $01, $01, $01, $01, $01, $0f, $ff
.byte $0a, $0f, $07, $00, $00, $00, $00, $f0, $f7, $f0, $f8, $ff, $ff, $ff, $ff, $ff
.byte $7e, $fe, $fe, $3e, $1c, $40, $2f, $2f, $ff, $7f, $3f, $fe, $fc, $f0, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $03, $03, $07
.byte $00, $00, $00, $00, $00, $00, $00, $00, $07, $07, $07, $07, $03, $03, $03, $03
.byte $02, $07, $07, $07, $07, $07, $07, $07, $01, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $80, $81, $81, $81, $00, $00, $ff, $ff, $7f, $7e, $7e, $7c, $7c, $3e
.byte $40, $40, $80, $02, $02, $c2, $64, $34, $bf, $bf, $7f, $fd, $fd, $3d, $1b, $0b
.byte $04, $04, $04, $04, $04, $04, $12, $12, $ff, $ff, $ff, $ff, $ff, $ff, $ef, $ef
.byte $0f, $1f, $1f, $1f, $1e, $0c, $00, $0f, $00, $00, $00, $04, $08, $00, $00, $0f
.byte $00, $00, $00, $00, $00, $00, $38, $fc, $3e, $1e, $1f, $0f, $0f, $07, $3f, $ff
.byte $1c, $00, $00, $00, $00, $40, $2e, $2f, $03, $07, $07, $07, $e7, $f3, $ff, $ff
.byte $12, $26, $3f, $0f, $00, $04, $02, $c2, $ef, $d8, $c0, $f0, $ff, $ff, $ff, $ff
.byte $7e, $7e, $3e, $fe, $ff, $ff, $ff, $ff, $ff, $7f, $3f, $3e, $1c, $82, $82, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $03, $03, $07, $1f, $1f, $1f, $1f, $1f
.byte $01, $01, $02, $03, $01, $18, $7e, $7f, $fe, $fe, $fd, $fc, $f8, $e0, $80, $00
.byte $00, $00, $00, $00, $80, $c0, $62, $32, $ff, $ff, $ff, $ff, $7f, $3f, $1d, $0d
.byte $04, $04, $04, $04, $04, $04, $0a, $0f, $ff, $ff, $ff, $ff, $ff, $ff, $f7, $f2
.byte $3e, $3e, $3e, $7e, $7e, $7e, $7e, $1e, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $0c, $0f, $0f, $0f, $0f, $07, $07, $03, $0f
.byte $1f, $0f, $07, $06, $00, $20, $17, $17, $02, $02, $04, $80, $f0, $f8, $ff, $ff
.byte $1e, $06, $00, $00, $00, $00, $03, $ff, $01, $01, $01, $01, $00, $00, $03, $ff
.byte $00, $08, $00, $00, $00, $01, $87, $ff, $f9, $f7, $ff, $ff, $ff, $fe, $f8, $fe
.byte $0e, $26, $16, $0e, $3e, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $dc, $00, $02, $02
.byte $0f, $1f, $13, $27, $26, $2e, $4e, $4c, $0f, $1f, $1f, $3b, $3a, $36, $76, $74
.byte $00, $00, $1e, $3f, $3f, $7e, $78, $70, $00, $00, $1e, $3f, $3f, $7e, $78, $70
.byte $4c, $4c, $4e, $2e, $1f, $17, $0b, $07, $74, $74, $76, $36, $13, $18, $0d, $07
.byte $70, $20, $03, $67, $e7, $cf, $cf, $8f, $70, $3e, $3f, $7c, $fc, $f8, $f9, $f9
.byte $00, $00, $00, $00, $80, $80, $c0, $c0, $00, $00, $00, $00, $00, $80, $40, $40
.byte $00, $00, $00, $00, $00, $04, $04, $04, $01, $01, $01, $01, $03, $07, $0f, $3f
.byte $0f, $0f, $0f, $07, $07, $03, $05, $03, $f8, $f8, $f8, $fc, $fd, $fe, $fe, $fc
.byte $c0, $c1, $cf, $bf, $7f, $ff, $ff, $ff, $80, $01, $41, $c0, $88, $02, $10, $00
.byte $f0, $f8, $f8, $f0, $f0, $f0, $f0, $f0, $f0, $c8, $e8, $f0, $00, $00, $00, $80
.byte $04, $04, $04, $06, $02, $02, $03, $01, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $07, $0f, $0f, $1f, $1f, $1f, $0f, $4f, $f8, $f0, $f3, $e3, $e3, $e3, $f3, $c1
.byte $ff, $ff, $ff, $ef, $c0, $80, $80, $80, $04, $00, $00, $e0, $c0, $80, $80, $80
.byte $f0, $e0, $c0, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $01, $09, $0a, $0c, $08, $00, $00, $00, $ff, $f6, $f4, $f0, $f0, $f8, $f8, $fc
.byte $ce, $87, $07, $03, $00, $00, $00, $00, $c1, $81, $01, $00, $00, $00, $00, $00
.byte $c0, $e0, $f0, $f8, $f8, $f8, $f8, $70, $00, $40, $20, $10, $10, $10, $00, $00
.byte $00, $00, $00, $80, $c0, $e0, $e0, $fe, $fc, $fe, $fe, $7f, $3f, $1f, $9f, $ff
.byte $00, $00, $00, $00, $00, $08, $05, $05, $00, $00, $00, $f8, $fc, $fe, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $ff, $f0, $00, $00, $00, $00, $00, $00, $ff, $f0
.byte $00, $00, $00, $00, $00, $80, $80, $80, $00, $00, $00, $00, $40, $60, $60, $60
.byte $80, $80, $80, $80, $80, $80, $80, $80, $60, $60, $60, $60, $60, $60, $60, $60
.byte $00, $00, $00, $07, $0f, $1f, $1f, $ff, $00, $00, $00, $07, $03, $00, $00, $e0
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $7f, $f0, $f8, $f8, $f8, $70, $00, $00, $00
.byte $0c, $00, $00, $00, $00, $00, $00, $00, $10, $f8, $f0, $e0, $40, $00, $00, $00
.byte $00, $00, $f0, $f8, $f8, $f3, $ff, $ff, $00, $00, $f0, $f8, $f8, $d2, $1e, $1e
.byte $ff, $ff, $ff, $fc, $f8, $f0, $c0, $00, $3e, $3f, $3f, $0c, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $0f, $7f, $ff, $00, $00, $00, $00, $00, $0f, $7f, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $7f, $0f, $ff, $ff, $ff, $ff, $37, $07, $03, $13
.byte $03, $03, $03, $01, $01, $00, $00, $00, $fb, $f1, $e1, $40, $00, $00, $00, $00
.byte $00, $00, $00, $00, $e3, $ff, $ff, $ff, $00, $00, $00, $00, $e2, $fe, $fe, $fe
.byte $ff, $ff, $fc, $f8, $f0, $f0, $f0, $f8, $ff, $ff, $fc, $f0, $f0, $f0, $f0, $f8
.byte $f8, $f8, $f8, $fc, $fc, $fc, $3e, $0e, $f8, $f8, $f8, $fc, $bc, $2c, $0e, $06
.byte $fe, $fe, $7e, $7c, $3c, $38, $38, $38, $f8, $f8, $7a, $7c, $3c, $38, $38, $00
.byte $00, $00, $00, $00, $20, $3a, $3e, $3f, $00, $00, $00, $00, $20, $30, $38, $3a
.byte $3f, $1f, $1f, $0f, $0f, $07, $03, $01, $3f, $1f, $1f, $0f, $0f, $07, $03, $01
.byte $00, $03, $07, $05, $01, $0b, $0f, $0f, $03, $00, $00, $02, $06, $04, $00, $00
.byte $1e, $1e, $1e, $3e, $3c, $18, $00, $00, $01, $01, $01, $05, $0b, $2e, $18, $00
.byte $20, $60, $40, $40, $40, $20, $20, $20, $10, $18, $38, $38, $38, $1c, $1c, $1e
.byte $11, $10, $08, $04, $02, $01, $00, $00, $0e, $0f, $07, $0b, $0d, $1e, $1f, $1f
.byte $04, $05, $06, $07, $03, $00, $00, $40, $9b, $da, $d9, $f8, $fc, $ff, $ff, $bf
.byte $41, $62, $3c, $00, $00, $00, $00, $00, $be, $9c, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $30, $78, $7c, $00, $00, $00, $00, $00, $30, $78, $7c
.byte $7c, $1c, $0e, $0e, $06, $04, $00, $00, $7c, $1c, $0e, $0e, $07, $07, $03, $07
.byte $00, $00, $07, $08, $00, $00, $00, $3c, $07, $07, $07, $0f, $0f, $1f, $3f, $43
.byte $03, $80, $00, $00, $00, $00, $00, $03, $fc, $7f, $ff, $ff, $ff, $ff, $ff, $fc
.byte $04, $58, $cb, $fb, $fa, $fa, $02, $07, $fb, $a7, $34, $04, $05, $05, $05, $00
.byte $07, $07, $07, $0f, $0f, $07, $03, $00, $00, $00, $00, $00, $00, $0d, $05, $03
.byte $00, $00, $38, $3c, $3a, $18, $1c, $0c, $00, $00, $38, $34, $36, $16, $1a, $0b
.byte $0e, $06, $06, $07, $0f, $1e, $0c, $00, $0d, $05, $05, $f4, $fd, $fe, $fe, $fe
.byte $01, $00, $e0, $18, $04, $02, $02, $01, $fe, $ff, $ff, $ff, $ff, $ff, $ff, $fe
.byte $00, $80, $00, $00, $10, $1c, $0e, $1b, $fe, $7f, $ff, $ff, $ef, $e3, $f1, $e0
.byte $80, $40, $20, $a0, $a0, $80, $88, $88, $70, $b8, $d8, $58, $58, $78, $70, $70
.byte $90, $90, $a0, $80, $80, $00, $00, $00, $60, $60, $40, $40, $c0, $c0, $80, $00
.byte $80, $c0, $c0, $c0, $c0, $c0, $c0, $80, $80, $40, $00, $00, $00, $00, $00, $00
.byte $00, $00, $80, $80, $10, $18, $20, $c0, $00, $70, $78, $78, $e8, $e0, $c0, $00
.byte $00, $00, $1c, $3e, $7f, $07, $03, $07, $00, $00, $1c, $3e, $7f, $07, $03, $f7
.byte $1c, $3e, $3e, $0f, $07, $07, $07, $c6, $1c, $3e, $3e, $0f, $07, $07, $ff, $fe
.byte $00, $00, $00, $00, $0c, $07, $00, $00, $00, $01, $0f, $0f, $03, $00, $00, $00
.byte $00, $01, $00, $3c, $c3, $00, $00, $00, $39, $fe, $ff, $c3, $0c, $1f, $1f, $1f
.byte $03, $00, $00, $00, $00, $80, $00, $03, $fc, $ff, $ff, $ff, $ff, $7f, $ff, $fc
.byte $32, $ca, $24, $02, $01, $01, $00, $00, $fe, $3e, $de, $ff, $ff, $ff, $ff, $ff
.byte $88, $44, $24, $a4, $a6, $8b, $89, $88, $77, $bb, $db, $5b, $59, $70, $70, $70
.byte $00, $00, $00, $00, $00, $00, $a0, $c0, $80, $80, $80, $c0, $e0, $e0, $40, $00
.byte $00, $00, $00, $01, $07, $0f, $1f, $1f, $00, $00, $00, $01, $07, $0f, $1f, $1f
.byte $3e, $3e, $3e, $3c, $1c, $1c, $0c, $00, $3e, $3e, $3e, $3c, $1c, $1c, $0c, $00
.byte $00, $00, $00, $00, $01, $01, $01, $10, $03, $07, $0f, $0f, $1f, $1f, $1f, $0f
.byte $10, $10, $08, $08, $08, $04, $03, $00, $0f, $0f, $07, $07, $07, $03, $00, $00
.byte $c0, $f0, $f6, $2e, $1e, $1e, $1e, $1e, $c6, $ff, $ff, $39, $31, $35, $33, $31
.byte $0f, $77, $ff, $ff, $ff, $ff, $ff, $ff, $3b, $0f, $02, $49, $00, $04, $91, $42
.byte $ff, $ff, $7f, $3f, $9f, $c7, $70, $1f, $3c, $44, $ee, $c4, $e0, $f8, $ff, $ff
.byte $0e, $01, $00, $01, $00, $e8, $b5, $9e, $f1, $fe, $ff, $ff, $ff, $1f, $4e, $63
.byte $80, $80, $c0, $40, $40, $40, $40, $40, $7f, $7f, $3f, $3f, $3f, $3f, $3f, $3f
.byte $ff, $ff, $f3, $c9, $c1, $a1, $10, $80, $3c, $22, $7f, $3f, $3f, $7f, $ff, $ff
.byte $60, $18, $84, $82, $83, $81, $01, $01, $9f, $e7, $7b, $7d, $fc, $7e, $fe, $fe
.byte $80, $c6, $fe, $fe, $fe, $7c, $18, $00, $80, $c6, $fe, $fe, $fe, $7c, $18, $00
.byte $00, $00, $00, $00, $80, $80, $00, $00, $c0, $e0, $f0, $f0, $f8, $f8, $f8, $fc
.byte $c0, $20, $04, $04, $0c, $08, $98, $70, $fc, $fc, $f8, $f8, $f0, $f0, $60, $00
.byte $00, $c0, $e0, $f0, $76, $2e, $1e, $1e, $00, $c0, $e6, $ff, $7f, $39, $31, $35
.byte $1e, $1e, $0f, $77, $ff, $ff, $ff, $ff, $33, $31, $3b, $0f, $02, $49, $00, $04
.byte $ff, $ff, $ff, $7f, $3f, $8f, $60, $1f, $91, $42, $3c, $c4, $c4, $f0, $ff, $ff
.byte $ff, $ff, $f3, $c9, $c1, $a1, $10, $00, $89, $42, $3e, $7f, $7f, $7f, $ff, $ff
.byte $00, $00, $00, $00, $00, $01, $03, $02, $01, $03, $07, $0f, $1f, $1e, $3c, $3c
.byte $0e, $00, $02, $0e, $06, $44, $3c, $00, $70, $7c, $7c, $78, $7c, $38, $10, $00
.byte $c0, $f0, $f6, $2e, $1e, $1e, $1e, $1e, $c6, $ff, $ff, $39, $31, $33, $33, $31
.byte $0f, $77, $ff, $ff, $ff, $ff, $7f, $3f, $3b, $0f, $02, $49, $00, $04, $11, $43
.byte $3f, $1f, $5f, $4f, $27, $10, $4f, $c0, $7f, $7f, $fd, $f8, $f8, $ff, $bf, $3f
.byte $c0, $80, $80, $80, $80, $80, $80, $80, $3f, $7f, $7f, $7f, $7f, $7f, $7f, $7f
.byte $fd, $f9, $fa, $f2, $e4, $08, $f1, $03, $ff, $ff, $3f, $9f, $1f, $ff, $fe, $fc
.byte $00, $00, $00, $00, $00, $00, $00, $01, $00, $00, $01, $03, $0f, $1f, $7f, $fe
.byte $02, $04, $08, $30, $61, $c1, $81, $83, $fc, $f8, $f0, $c0, $81, $01, $01, $03
.byte $03, $07, $07, $0d, $00, $00, $00, $00, $03, $06, $04, $08, $00, $00, $00, $00
.byte $0c, $1e, $1e, $1e, $0c, $00, $00, $00, $3c, $7e, $ff, $e9, $f3, $7f, $7e, $38
.byte $08, $08, $48, $30, $28, $00, $24, $7e, $74, $f6, $be, $de, $dc, $fc, $fc, $7e
.byte $7e, $ff, $ff, $ff, $ff, $ff, $fc, $f8, $7e, $fd, $fc, $fc, $ec, $d8, $db, $b7
.byte $f8, $f8, $7c, $3c, $38, $70, $50, $00, $37, $77, $63, $21, $30, $70, $50, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00, $60, $f0, $e0, $80, $c0, $40, $00, $00
.byte $80, $80, $80, $80, $80, $00, $00, $00, $20, $30, $30, $30, $f0, $20, $00, $00
.byte $07, $3f, $7f, $ff, $ff, $7f, $1f, $03, $00, $00, $00, $00, $80, $60, $1c, $03
.byte $00, $00, $07, $1f, $3f, $3f, $1f, $07, $00, $00, $00, $00, $00, $20, $18, $07
.byte $00, $00, $00, $00, $04, $0c, $00, $00, $00, $00, $00, $00, $00, $04, $00, $00
.byte $00, $00, $00, $00, $08, $08, $00, $00, $00, $00, $00, $00, $00, $08, $00, $00
.byte $00, $00, $7e, $ff, $ff, $3c, $00, $00, $00, $00, $00, $00, $c3, $3c, $00, $00
.byte $00, $00, $38, $7c, $7c, $00, $00, $00, $00, $00, $00, $00, $7c, $00, $00, $00
.byte $00, $00, $00, $38, $38, $00, $00, $00, $00, $00, $00, $00, $38, $00, $00, $00
.byte $00, $00, $00, $07, $1f, $3f, $7f, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $7f, $1f, $07, $00, $00, $00, $00, $80, $60, $1c, $07, $00, $00
.byte $ff, $ff, $ff, $ff, $ff, $ff, $7e, $00, $00, $00, $00, $00, $00, $c3, $7e, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00, $78, $f8, $e0, $80, $80, $c0, $60, $00
.byte $00, $07, $04, $04, $07, $01, $05, $07, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $07, $05, $05, $02, $05, $05, $07, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $27, $25, $25, $25, $25, $25, $27, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $27, $24, $24, $27, $21, $25, $27, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $27, $24, $24, $27, $25, $25, $27, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $77, $55, $15, $35, $65, $45, $77, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $75, $55, $15, $37, $61, $41, $71, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $77, $15, $15, $75, $15, $15, $77, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $77, $55, $55, $55, $55, $55, $77, $00, $00, $00, $00, $00, $00, $00, $00
.byte $c7, $b3, $39, $39, $39, $9b, $c7, $ff, $38, $4c, $c6, $c6, $c6, $64, $38, $00
.byte $e7, $c7, $e7, $e7, $e7, $e7, $81, $ff, $18, $38, $18, $18, $18, $18, $7e, $00
.byte $83, $39, $f1, $c3, $87, $1f, $01, $ff, $7c, $c6, $0e, $3c, $78, $e0, $fe, $00
.byte $81, $f3, $e7, $c3, $f9, $39, $83, $ff, $7e, $0c, $18, $3c, $06, $c6, $7c, $00
.byte $e3, $c3, $93, $33, $01, $f3, $f3, $ff, $1c, $3c, $6c, $cc, $fe, $0c, $0c, $00
.byte $03, $3f, $03, $f9, $f9, $39, $83, $ff, $fc, $c0, $fc, $06, $06, $c6, $7c, $00
.byte $c3, $9f, $3f, $03, $39, $39, $83, $ff, $3c, $60, $c0, $fc, $c6, $c6, $7c, $00
.byte $01, $39, $f3, $e7, $cf, $cf, $cf, $ff, $fe, $c6, $0c, $18, $30, $30, $30, $00
.byte $83, $39, $39, $83, $39, $39, $83, $ff, $7c, $c6, $c6, $7c, $c6, $c6, $7c, $00
.byte $83, $39, $39, $81, $f9, $f3, $87, $ff, $7c, $c6, $c6, $7e, $06, $0c, $78, $00
.byte $c7, $93, $39, $39, $01, $39, $39, $ff, $38, $6c, $c6, $c6, $fe, $c6, $c6, $00
.byte $03, $39, $39, $03, $39, $39, $03, $ff, $fc, $c6, $c6, $fc, $c6, $c6, $fc, $00
.byte $c3, $99, $3f, $3f, $3f, $99, $c3, $ff, $3c, $66, $c0, $c0, $c0, $66, $3c, $00
.byte $07, $33, $39, $39, $39, $33, $07, $ff, $f8, $cc, $c6, $c6, $c6, $cc, $f8, $00
.byte $01, $3f, $3f, $03, $3f, $3f, $01, $ff, $fe, $c0, $c0, $fc, $c0, $c0, $fe, $00
.byte $01, $3f, $3f, $03, $3f, $3f, $3f, $ff, $fe, $c0, $c0, $fc, $c0, $c0, $c0, $00
.byte $c1, $9f, $3f, $31, $39, $99, $c1, $ff, $3e, $60, $c0, $ce, $c6, $66, $3e, $00
.byte $39, $39, $39, $01, $39, $39, $39, $ff, $c6, $c6, $c6, $fe, $c6, $c6, $c6, $00
.byte $81, $e7, $e7, $e7, $e7, $e7, $81, $ff, $7e, $18, $18, $18, $18, $18, $7e, $00
.byte $00, $00, $00, $00, $ff, $ff, $ff, $ff, $00, $00, $00, $ff, $00, $00, $00, $00
.byte $39, $33, $27, $0f, $07, $23, $31, $ff, $c6, $cc, $d8, $f0, $f8, $dc, $ce, $00
.byte $9f, $9f, $9f, $9f, $9f, $9f, $81, $ff, $60, $60, $60, $60, $60, $60, $7e, $00
.byte $39, $11, $01, $01, $29, $39, $39, $ff, $c6, $ee, $fe, $fe, $d6, $c6, $c6, $00
.byte $39, $19, $09, $01, $21, $31, $39, $ff, $c6, $e6, $f6, $fe, $de, $ce, $c6, $00
.byte $83, $39, $39, $39, $39, $39, $83, $ff, $7c, $c6, $c6, $c6, $c6, $c6, $7c, $00
.byte $03, $39, $39, $39, $03, $3f, $3f, $ff, $fc, $c6, $c6, $c6, $fc, $c0, $c0, $00
.byte $00, $00, $00, $00, $80, $c0, $e0, $e0, $00, $00, $00, $c0, $60, $30, $10, $10
.byte $03, $39, $39, $31, $07, $23, $31, $ff, $fc, $c6, $c6, $ce, $f8, $dc, $ce, $00
.byte $87, $33, $3f, $83, $f9, $39, $83, $ff, $78, $cc, $c0, $7c, $06, $c6, $7c, $00
.byte $81, $e7, $e7, $e7, $e7, $e7, $e7, $ff, $7e, $18, $18, $18, $18, $18, $18, $00
.byte $39, $39, $39, $39, $39, $39, $83, $ff, $c6, $c6, $c6, $c6, $c6, $c6, $7c, $00
.byte $39, $39, $39, $11, $83, $c7, $ef, $ff, $c6, $c6, $c6, $ee, $7c, $38, $10, $00
.byte $39, $39, $29, $01, $01, $11, $39, $ff, $c6, $c6, $d6, $fe, $fe, $ee, $c6, $00
.byte $e0, $e0, $e0, $e0, $e0, $e0, $e0, $e0, $10, $10, $10, $10, $10, $10, $10, $10
.byte $99, $99, $81, $c3, $e7, $e7, $e7, $ff, $66, $66, $7e, $3c, $18, $18, $18, $00
.byte $0f, $07, $03, $00, $00, $00, $00, $00, $10, $18, $0c, $07, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $c3, $bd, $66, $5e, $5e, $66, $bd, $c3, $3c, $42, $99, $a1, $a1, $99, $42, $3c
.byte $ff, $df, $cf, $07, $03, $01, $00, $ff, $00, $20, $30, $f8, $fc, $fe, $ff, $00
.byte $ff, $83, $83, $ff, $83, $83, $ff, $ff, $00, $7c, $7c, $00, $7c, $7c, $00, $00
.byte $00, $00, $00, $00, $04, $18, $30, $1c, $00, $00, $00, $00, $06, $1f, $3f, $1f
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $40, $ec, $fe, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $80, $c0, $e0, $e0
.byte $38, $70, $70, $38, $fc, $f8, $7c, $e6, $3f, $7f, $7f, $3f, $ff, $ff, $7f, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $c0, $f0, $f8, $f8, $f0, $f8, $f0, $f8
.byte $01, $07, $0f, $0c, $1e, $1f, $0f, $1f, $01, $07, $0f, $0f, $1f, $1f, $0f, $1f
.byte $c1, $c0, $e0, $f0, $60, $c4, $06, $82, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $10, $60, $00, $fc, $fe, $fc, $fe, $fe, $fc, $fe, $fe
.byte $3f, $1f, $0f, $1f, $3f, $1f, $3f, $7f, $3f, $1f, $0f, $1f, $3f, $1f, $3f, $7f
.byte $c8, $f8, $f0, $f9, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $02, $01, $00, $91, $f3, $fb, $7f, $ff, $ff, $ff, $ff, $ff, $ff, $bf, $bf
.byte $42, $c4, $82, $17, $3e, $ff, $ff, $bf, $fe, $fc, $fe, $ff, $fe, $ff, $bf, $df
.byte $7f, $ff, $ff, $ff, $ee, $6e, $76, $30, $7f, $ff, $7f, $6f, $77, $b7, $bb, $df
.byte $f6, $f6, $e4, $e4, $c4, $40, $40, $00, $bf, $7f, $7f, $7f, $7f, $ff, $ff, $ff
.byte $ff, $ff, $db, $9b, $99, $89, $00, $00, $7d, $7d, $7d, $fd, $fe, $fe, $ff, $ff
.byte $de, $dd, $4c, $a4, $a4, $80, $80, $00, $ec, $ee, $f7, $ff, $ff, $ff, $ff, $ff
.byte $10, $14, $14, $08, $08, $08, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $08, $0c, $24, $00, $00, $00, $00, $00, $08, $0c, $24
.byte $00, $00, $00, $00, $00, $01, $22, $62, $00, $00, $00, $00, $00, $02, $24, $6c
.byte $00, $00, $00, $00, $00, $00, $08, $0c, $00, $00, $00, $00, $00, $00, $08, $0c
.byte $00, $00, $00, $00, $00, $80, $84, $cc, $00, $00, $00, $00, $00, $80, $84, $cc
.byte $00, $00, $00, $00, $40, $20, $10, $08, $00, $00, $00, $00, $00, $00, $20, $30
.byte $00, $00, $00, $00, $00, $40, $51, $51, $00, $00, $00, $00, $01, $01, $02, $82
.byte $00, $00, $00, $80, $80, $80, $00, $20, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $00, $40, $30, $00, $00, $00, $00, $00, $00, $00, $00
.byte $33, $31, $31, $10, $10, $00, $00, $00, $dd, $de, $de, $ef, $ef, $ff, $ff, $ff
.byte $80, $80, $80, $80, $04, $04, $04, $04, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $09, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $10, $10, $10, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $40, $80, $80, $88, $88, $08, $08, $08, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $22, $22, $12, $12, $12, $10, $10, $10, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $08, $08, $08, $08, $04, $04, $04, $04, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $10, $1f, $ff, $ff, $ff, $ff, $ff, $ff, $ef, $e0, $0f
.byte $00, $00, $00, $00, $00, $1c, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $e3, $00, $ff
.byte $00, $00, $00, $00, $00, $26, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $d9, $00, $ff
.byte $00, $00, $00, $00, $40, $40, $e0, $ff, $ff, $ff, $ff, $ff, $bf, $bf, $1f, $c0
.byte $00, $00, $00, $00, $00, $00, $4c, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $b3, $40
.byte $00, $00, $00, $00, $00, $00, $08, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $f7, $00
.byte $00, $00, $00, $00, $00, $10, $38, $ff, $ff, $ff, $ff, $ff, $ff, $ef, $c7, $18
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fd, $ff, $ff, $cf, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $f7, $fd, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $cf, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $f7, $fb, $e6, $ff, $ff
.byte $c0, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $ff, $fd, $f9, $f3, $f3, $00, $40, $48, $08, $22, $26, $4d, $6f
.byte $c0, $c0, $e0, $e0, $e0, $e0, $a2, $24, $00, $00, $00, $00, $00, $00, $42, $d4
.byte $e2, $62, $22, $20, $20, $00, $00, $00, $7f, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $2c, $64, $64, $60, $40, $40, $00, $00, $de, $9f, $bf, $ff, $ff, $ff, $ff, $ff
.byte $bb, $9b, $99, $18, $10, $00, $00, $00, $dd, $ed, $ef, $ef, $ef, $ff, $ff, $ff
.byte $17, $06, $06, $06, $04, $04, $00, $00, $fb, $fb, $fb, $fb, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $01, $02, $00, $00, $00, $00, $00, $00, $01, $03
.byte $00, $00, $00, $00, $00, $c0, $00, $00, $00, $01, $1d, $3f, $1f, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $19, $bb, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $02, $01, $01, $80, $80, $60, $f8, $f8, $f6, $ff, $ff
.byte $03, $02, $06, $07, $01, $02, $07, $06, $03, $03, $07, $07, $01, $03, $07, $06
.byte $00, $00, $00, $80, $00, $00, $c0, $88, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $01, $03, $00, $00, $00, $01, $00, $04, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $80, $c0, $60, $e0, $c0, $80, $c0, $00, $80, $c0, $e0, $e0, $c0, $80, $c0
.byte $01, $01, $00, $00, $00, $00, $00, $00, $01, $01, $00, $00, $00, $00, $00, $00
.byte $90, $f0, $b9, $7f, $6f, $0e, $04, $00, $ff, $ff, $bf, $7f, $6f, $0e, $04, $00
.byte $00, $81, $91, $bb, $ef, $ef, $66, $26, $ff, $ff, $ff, $ff, $ef, $ef, $46, $00
.byte $03, $02, $8a, $cf, $7b, $30, $10, $00, $ff, $fe, $fe, $ff, $7b, $30, $10, $00
.byte $c0, $c0, $00, $00, $00, $00, $00, $00, $c0, $c0, $00, $00, $00, $00, $00, $00
.byte $36, $16, $1e, $0e, $0e, $0f, $0f, $c7, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $02, $01, $01, $00, $40, $e0, $e8, $fc, $fe, $ff, $ff
.byte $7f, $3f, $07, $07, $03, $03, $03, $03, $00, $00, $00, $00, $00, $00, $00, $00
.byte $03, $80, $81, $82, $c3, $c1, $c0, $c0, $03, $00, $01, $03, $03, $01, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $22, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $02, $01, $03, $0e, $04, $06, $1e, $24, $fe, $ff, $ff, $fe, $fc, $fe, $fe, $f4
.byte $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $e0, $e0, $e0, $e0, $c0, $20, $00, $80, $00, $00, $06, $1f, $3f, $df, $ff, $7f
.byte $0f, $07, $06, $06, $03, $04, $00, $00, $0f, $05, $c0, $d8, $fc, $fb, $ff, $ff
.byte $77, $ff, $fe, $ec, $80, $00, $00, $00, $ff, $ff, $de, $0c, $00, $00, $80, $80
.byte $70, $c0, $c0, $00, $00, $00, $00, $00, $f0, $c0, $c0, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $01, $00, $01, $02, $00, $00, $00, $00, $01, $00, $01, $03
.byte $00, $00, $00, $00, $00, $80, $00, $00, $03, $1b, $3f, $df, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $18, $bb, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $02, $01, $40, $21, $61, $10, $18, $01, $83, $01, $c0, $e1, $e1, $d0, $f8
.byte $00, $00, $80, $00, $20, $e4, $ff, $7f, $ff, $ff, $ff, $ff, $ff, $ff, $bf, $37
.byte $00, $00, $00, $00, $82, $89, $de, $f6, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $76
.byte $00, $00, $00, $40, $80, $00, $00, $00, $00, $80, $c0, $c0, $80, $00, $00, $00
.byte $03, $00, $01, $02, $03, $01, $00, $00, $03, $00, $01, $03, $03, $01, $00, $00
.byte $80, $80, $00, $20, $c0, $88, $79, $6f, $ff, $ff, $ff, $ff, $ff, $bf, $7f, $6f
.byte $00, $00, $00, $00, $00, $02, $11, $39, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $38, $10, $18, $58, $38, $20, $f0, $a0, $f8, $f0, $f8, $f8, $f8, $e0, $f0, $a0
.byte $7b, $79, $79, $7b, $7b, $7b, $7f, $7f, $02, $00, $00, $00, $00, $00, $00, $00
.byte $e0, $c0, $c0, $c0, $c0, $80, $80, $80, $20, $00, $00, $00, $00, $00, $00, $00
.byte $0f, $05, $00, $00, $00, $00, $00, $00, $0f, $05, $00, $00, $00, $00, $00, $00
.byte $fe, $ef, $e5, $39, $0f, $03, $00, $00, $fe, $ee, $c4, $00, $00, $00, $00, $00
.byte $c0, $c0, $80, $80, $c0, $c0, $e0, $e0, $c0, $c0, $00, $00, $00, $00, $00, $00
.byte $7f, $7f, $7f, $7f, $7e, $7e, $7e, $7e, $00, $00, $00, $00, $20, $00, $00, $00
.byte $70, $78, $38, $3c, $1e, $1f, $0f, $0f, $00, $00, $00, $00, $00, $00, $00, $00
.byte $7e, $7e, $7e, $fe, $fe, $ff, $ff, $ff, $00, $20, $20, $00, $40, $40, $00, $00
.byte $90, $f0, $b9, $7f, $6f, $0f, $1f, $3e, $ff, $ff, $bf, $7f, $6f, $0e, $04, $00
.byte $00, $81, $91, $bb, $ef, $ef, $46, $00, $ff, $ff, $ff, $ff, $ef, $ef, $46, $00
.byte $07, $07, $03, $03, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $40, $40, $00, $10
.byte $00, $00, $01, $03, $07, $0f, $9f, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $78, $f0, $fc, $ff, $e0, $c0, $80, $80, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $7f, $7f, $7f, $7f, $7f, $7f, $10, $00, $20, $20, $00, $00, $00, $08
.byte $ff, $fe, $fe, $fc, $f8, $f8, $f0, $f0, $00, $00, $00, $00, $00, $00, $00, $00
.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $00, $20, $20, $00, $00, $00, $10, $10
.byte $f0, $e0, $e0, $c0, $c0, $c0, $c0, $c0, $00, $00, $00, $00, $00, $00, $00, $00
.byte $66, $fe, $ce, $ce, $e7, $77, $73, $73, $66, $ee, $56, $56, $7b, $fb, $bd, $bd
.byte $e5, $c7, $c7, $c6, $c6, $c4, $84, $84, $e9, $db, $db, $fb, $ff, $ff, $ff, $ff
.byte $2e, $46, $4f, $4f, $4f, $5e, $4c, $08, $4e, $86, $87, $d7, $f7, $ef, $ff, $ff
.byte $dd, $7d, $6f, $66, $b6, $b2, $90, $90, $cd, $6d, $77, $fb, $fb, $ff, $ff, $ff
.byte $08, $00, $20, $62, $22, $20, $00, $00, $90, $99, $bd, $ff, $ff, $ff, $ff, $ff
.byte $11, $10, $08, $08, $01, $01, $41, $41, $a2, $a7, $bf, $ff, $ff, $ff, $ff, $ff
.byte $20, $a8, $88, $84, $0a, $02, $00, $00, $01, $c1, $e1, $e9, $ff, $ff, $ff, $ff
.byte $08, $84, $84, $60, $20, $20, $10, $10, $31, $19, $19, $bd, $ff, $ff, $ff, $ff
.byte $01, $03, $05, $07, $0b, $1f, $37, $3b, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $80, $80, $e0, $d0, $f0, $f0, $f8, $ec, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $03, $06, $0b, $1f, $1d, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $80, $c0, $e0, $c0, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $1f, $2f, $7f, $3d, $df, $f7, $7f, $5f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $fc, $f8, $f4, $fe, $fe, $fc, $fe, $fb, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $0b, $1f, $2f, $3f, $5b, $ef, $fe, $7f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $e0, $d0, $f8, $f0, $f8, $f4, $fc, $ee, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $bf, $ef, $ff, $7f, $5b, $2f, $3b, $0f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $fe, $ee, $fa, $fc, $f4, $f8, $ec, $f8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $5f, $f7, $7f, $3f, $6f, $5b, $3e, $17, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $fe, $f4, $f8, $fc, $b4, $d8, $f8, $d0, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $03, $01, $01, $01, $01, $01, $01, $01, $ff, $fe, $fe, $fe, $fe, $fe, $fe, $fe
.byte $e0, $80, $80, $80, $80, $80, $80, $c0, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f
.byte $e0, $c0, $80, $80, $80, $80, $80, $80, $ff, $ff, $7f, $7f, $7f, $7f, $7f, $7f
.byte $08, $0c, $14, $3e, $5e, $7d, $3e, $5f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $10, $38, $5c, $7c, $fa, $5e, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $3d, $2e, $7e, $2c, $08, $08, $08, $08, $ff, $ff, $ff, $ff, $f7, $f7, $f7, $f7
.byte $ff, $ed, $be, $7c, $38, $10, $10, $10, $ff, $ff, $ff, $ff, $ff, $ef, $ef, $ef
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $07, $0f, $0f, $1f
.byte $00, $00, $00, $00, $00, $00, $00, $00, $07, $0f, $3f, $ff, $ff, $ff, $ff, $ff
.byte $60, $38, $0e, $0f, $1f, $03, $01, $00, $e0, $f8, $fe, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $07, $0f, $3f, $7f, $7f
.byte $00, $00, $00, $00, $00, $00, $00, $00, $3f, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $07, $1f, $3f, $7f
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $07, $ef, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $3f, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $07, $1f, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $00, $ff, $ff, $00, $ff, $ff, $ff, $00, $ff, $00, $00, $ff, $00, $00, $00
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $18, $0c, $07, $07, $0f, $1f, $03, $00, $f8, $fc, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $80, $f0, $fc, $fe, $ff, $00, $00, $00, $80, $f0, $fc, $fe, $ff
.byte $80, $f0, $f8, $fe, $ff, $0f, $03, $00, $80, $f0, $f8, $fe, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $f0, $fc, $ff, $ff, $00, $00, $00, $00, $f0, $fc, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $c0, $f0, $00, $00, $00, $00, $00, $00, $c0, $ff
.byte $7f, $38, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $e0, $38, $0f, $07, $07, $0f, $03, $00, $e0, $f8, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $f8, $ff, $00, $00, $00, $00, $00, $00, $f8, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $e0, $f0, $f8, $ff, $ff, $00, $00, $00, $e0, $f0, $f8, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $38, $fe, $00, $00, $00, $00, $00, $00, $38, $fe
.byte $1f, $07, $07, $0f, $1f, $03, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $ff, $7f, $1f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $80, $c0, $e0, $f0, $f8, $fc, $ff, $00, $80, $c0, $e0, $f0, $f8, $fc, $ff
.byte $03, $01, $03, $1f, $0f, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $ff, $3f, $07, $01, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $80, $f0, $f8, $fe, $ff, $ff, $ff, $ff, $80, $f0, $f8, $fe, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $c0, $f0, $f8, $fe, $00, $00, $00, $00, $c0, $f0, $f8, $fe
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $07, $1f
.byte $ff, $3f, $1f, $07, $07, $0f, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $80, $e0, $f0, $fc, $ff, $ff, $ff, $ff, $80, $e0, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $80, $c0, $e0, $3f, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $7f, $3f, $3f, $1f, $1f, $1f, $3f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $f8, $fc, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $c0, $f0, $fc, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $01, $51, $31, $00, $00, $00, $00, $00, $00, $12, $52
.byte $00, $00, $00, $00, $10, $22, $2b, $9b, $00, $00, $00, $00, $00, $02, $49, $dd
.byte $ff, $ff, $df, $bf, $bf, $ff, $ff, $ff, $00, $38, $7c, $fe, $fe, $fe, $7c, $38
.byte $ff, $c7, $83, $01, $01, $01, $83, $c7, $00, $38, $7c, $fe, $fe, $fe, $7c, $38
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $70, $f0, $30, $76, $fe, $fc, $78
.byte $ff, $8f, $0f, $cf, $89, $01, $03, $87, $00, $70, $f0, $30, $76, $fe, $fc, $78
.byte $ff, $ff, $55, $55, $55, $55, $55, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $0f, $0f, $0f, $0f, $0f, $0f, $0f, $0f, $10, $10, $10, $10, $10, $10, $10, $10
.byte $ff, $ef, $ef, $ef, $ef, $ff, $ef, $ff, $18, $2c, $2c, $2c, $2c, $00, $2c, $00
.byte $ff, $84, $9c, $84, $e4, $e4, $84, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $90, $92, $12, $92, $92, $90, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $43, $67, $67, $67, $67, $67, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $c0, $e0, $f0, $f8, $fc, $fe, $ff, $ff, $3f, $9f, $cf, $e7, $f3, $f9, $fc, $fe
.byte $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
.byte $03, $07, $0f, $1f, $3f, $7f, $ff, $ff, $fc, $f9, $f3, $e7, $cf, $9f, $3f, $7f
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $ff, $ff, $fc, $f9, $fb, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $fc
.byte $ff, $ff, $ff, $ff, $ff, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00
.byte $ff, $ff, $ff, $ff, $ff, $7f, $3f, $bf, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $7f
.byte $fb, $fb, $fb, $fb, $fb, $fb, $fb, $fb, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $bf, $bf, $bf, $bf, $bf, $bf, $bf, $bf, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f
.byte $f9, $fc, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $00, $ff, $ff, $ff, $ff, $ff, $ff, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $3f, $7f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $1f, $ff, $ff, $ff, $ff
.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $07, $1f
.byte $1f, $0f, $0f, $1f, $01, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
.byte $ff, $ff, $ff, $ff, $93, $93, $f7, $ff, $00, $00, $00, $00, $6c, $6c, $08, $00
.byte $ff, $ff, $ff, $ff, $9f, $9f, $ff, $ff, $00, $00, $00, $00, $60, $60, $00, $00
.byte $e0, $f8, $fc, $fe, $fe, $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $fe, $fe, $fc, $f8, $e0, $00, $00, $00, $00, $00, $00, $00, $00
.byte $07, $1f, $3f, $7f, $7f, $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $7f, $7f, $3f, $1f, $07, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $81, $81, $c3, $00, $00, $00, $00, $00, $00, $00, $00
.byte $c3, $81, $81, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $01, $01, $03, $03, $07, $1f, $00, $00, $00, $00, $00, $00, $00, $00
.byte $1f, $07, $03, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $00, $00, $00, $00, $00, $00
.byte $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $ff, $00, $00, $00, $00
.byte $e0, $c0, $80, $00, $00, $00, $00, $00, $10, $30, $60, $c0, $00, $00, $00, $00
.byte $99, $99, $99, $bb, $ff, $33, $33, $ff, $66, $66, $66, $44, $00, $cc, $cc, $00
.byte $00, $00, $00, $00, $03, $07, $0f, $0f, $00, $00, $00, $07, $0c, $18, $10, $10

.segment "VECTORS"

.addr NMI, Reset, Reset

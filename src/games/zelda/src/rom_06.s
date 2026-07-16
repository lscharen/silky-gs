            mx    %11
            ORG   $5000

ROMBase  EXT
            put   rom_inject_no_extin.s

            use   BeginEndVars.inc
            use   CaveVars.inc
            use   CommonVars.inc
            use   ObjVars.inc
            use   Variables.inc

SetMirrorMode  EXT

            ORG   $8000

; .INCLUDE "Variables.inc" (hoisted to file header)

; .SEGMENT "BANK_06_00"


; Imports from program bank 07




LevelBlockAddrsQ1
            dw    LevelBlockOW
            dw    LevelBlockUW1Q1
            dw    LevelBlockUW1Q1
            dw    LevelBlockUW1Q1
            dw    LevelBlockUW1Q1
            dw    LevelBlockUW1Q1
            dw    LevelBlockUW1Q1
            dw    LevelBlockUW2Q1
            dw    LevelBlockUW2Q1
            dw    LevelBlockUW2Q1

LevelInfoAddrs
            dw    LevelInfoOW
            dw    LevelInfoUW1
            dw    LevelInfoUW2
            dw    LevelInfoUW3
            dw    LevelInfoUW4
            dw    LevelInfoUW5
            dw    LevelInfoUW6
            dw    LevelInfoUW7
            dw    LevelInfoUW8
            dw    LevelInfoUW9

CommonDataBlockAddr_Bank6
            dw    CommonDataBlock_Bank6

LevelBlockAddrsQ2
            dw    LevelBlockOW
            dw    LevelBlockUW1Q2
            dw    LevelBlockUW1Q2
            dw    LevelBlockUW1Q2
            dw    LevelBlockUW1Q2
            dw    LevelBlockUW1Q2
            dw    LevelBlockUW1Q2
            dw    LevelBlockUW2Q2
            dw    LevelBlockUW2Q2
            dw    LevelBlockUW2Q2

InitMode2_Submodes ENT
    LDA GameSubmode
    JSR TableJump

InitMode2_Submodes_JumpTable
            dw    InitMode2_Sub0
            dw    InitMode2_Sub1

InitMode2_Sub0
    ; Copy level block for level.
    LDA CurLevel
    ASL
    TAX
    LDY CurSaveSlot
    LDA QuestNumbers, Y
    BNE :SecondQuest

    ; First quest.
    LDA LevelBlockAddrsQ1, X
    STA $00
    INX
    LDA LevelBlockAddrsQ1, X
    JMP :Copy

:SecondQuest
    ; Second quest.
    LDA LevelBlockAddrsQ2, X
    STA $00
    INX
    LDA LevelBlockAddrsQ2, X

:Copy
    STA $01
    JSR FetchLevelBlockDestInfo
    JSR CopyBlock
    RTS

InitMode2_Sub1
    ; Copy level info.
    LDA CurLevel
    ASL
    TAX
    LDA LevelInfoAddrs, X
    STA $00
    INX
    LDA LevelInfoAddrs, X
    STA $01
    JSR FetchLevelInfoDestInfo
    JSR CopyBlock
    LDA #$00
    STA GameSubmode
    INC IsUpdatingMode
    RTS

CopyCommonDataToRam ENT
    LDX #$00                    ; Get the source address of common data block in ROM.
    LDA CommonDataBlockAddr_Bank6, X
    STA $00
    INX
    LDA CommonDataBlockAddr_Bank6, X
    STA $01
    JSR FetchDestAddrForCommonDataBlock
    JSR CopyBlock
    LDA #$00
    STA GameSubmode
    RTS

; Returns:
; [$02:03]: destination address
; [$04:05]: end address
;
; Destination address $687E.
FetchLevelBlockDestInfo
    LDA #$7E
    STA $02
    LDA #$68
    STA $03
    LDA #$7D                    ; End address $6B7D.
    STA $04
    LDA #$6B
    STA $05
    RTS

; Returns:
; [$02:03]: destination address
; [$04:05]: end address
;
; Destination address $6B7E.
FetchLevelInfoDestInfo
    LDA #$7E
    STA $02
    LDA #$6B
    STA $03
    LDA #$7D                    ; End address $6C7D.
    STA $04
    LDA #$6C
    STA $05
    RTS

FetchDestAddrForCommonDataBlock
    LDA #$F0                    ; 67F0 to 687D (inclusive)
    STA $02
    LDA #$67
    STA $03
    LDA #$7D
    STA $04
    LDA #$68
    STA $05
    RTS

; Params:
; [$00:01]: source address
; [$02:03]: destination address
; [$04:05]: end destination address
;
; Also increments submode.
;
CopyBlock
    LDY #$00

:Loop
    LDA ($00), Y
    STA ($02), Y
    LDA $02
    CMP $04
    BNE :Next
    LDA $03
    CMP $05
    BNE :Next
    INC GameSubmode
    RTS

:Next
    LDA $02
    CLC
    ADC #$01
    STA $02
    LDA $03
    ADC #$00
    STA $03
    LDA $00
    CLC
    ADC #$01
    STA $00
    LDA $01
    ADC #$00
    STA $01
    JMP :Loop

UpdateMode2Load_Full ENT
    ; Make replacements for the second quest.
    LDY CurSaveSlot
    LDA QuestNumbers, Y
    BEQ :Exit                   ; If not second quest, then return.
    LDA CurLevel
    BEQ :PatchQ2Rooms           ; If OW, then go patch rooms.
    TAX
    ASL
    TAY

    ; Get an address for the current level that points
    ; to an array of replacement bytes for Q2 UW level info.
    ;
    ; This address array doesn't access the OW element (0).
    ; So, it overlaps the last two bytes of LevelInfoUWQ2Replacements9.
    LDA LevelInfoUWQ2ReplacementAddrs-2, Y
    STA $00
    LDA LevelInfoUWQ2ReplacementAddrs-1, Y
    STA $01

    ; Get the number of replacement bytes for Q2 UW level info.
    ; This address array doesn't access the OW element (0).
    LDY LevelInfoUWQ2ReplacementSizes-1, X

:ReplaceInfoBytes
    ; Copy bytes from Q2 replacement array to level info
    ; starting at offset $29 (shortcut position array).
    LDA ($00), Y
    STA LevelInfo_ShortcutOrItemPosArray, Y
    DEY
    BPL :ReplaceInfoBytes

:Exit
    RTS

:PatchQ2Rooms
    ; Replace attributes of several rooms in OW in second quest.
    LDY #$07

:ReplaceRoomBytes
    LDX LevelBlockAttrsBQ2ReplacementOffsets, Y
    LDA LevelBlockAttrsBQ2ReplacementValues, Y
    STA LevelBlockAttrsB, X
    DEY
    BPL :ReplaceRoomBytes
    LDA #$7B
    STA LevelBlockAttrsD+11
    LDA #$7B
    STA LevelBlockAttrsD+60
    LDA #$5A
    STA LevelBlockAttrsD+116
    LDA #$72
    STA LevelBlockAttrsA+60
    LDA #$72
    STA LevelBlockAttrsA+116
    LDA #$01
    STA LevelBlockAttrsF+60
    LDA #$00
    STA LevelBlockAttrsF+116
    RTS

LevelBlockAttrsBQ2ReplacementOffsets
            db    $0E, $0F, $22, $34, $3C, $45, $74, $8B

LevelBlockAttrsBQ2ReplacementValues
            db    $7B, $83, $84, $0F, $0B, $12, $7A, $2F

LevelInfoUWQ2Replacements1
            db    $C9, $AC, $89, $B7, $00, $E0, $77, $08
            db    $FF, $06, $01, $28, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $07, $00, $00
            db    $00, $00, $00, $00, $00, $FF, $DB, $00
            db    $00, $00, $00, $00, $00, $00, $20, $65
            db    $42, $FF, $20, $85, $02, $FF, $FB, $20
            db    $A5, $02, $FF, $67, $20, $C5, $42, $FF
            db    $FF

LevelInfoUWQ2Replacements2
            db    $C9, $AC, $89, $87, $05, $00, $75, $20
            db    $FF, $06, $03, $56, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $30, $00, $00
            db    $00, $00, $00, $30, $00, $00, $00, $00
            db    $7F, $03, $00, $00, $00, $00, $20, $67
            db    $01, $FB, $20, $82, $01, $FF, $20, $87
            db    $C3, $FF, $20, $C8, $01, $FF, $FF

LevelInfoUWQ2Replacements3
            db    $C9, $AC, $89, $37, $0D, $C8, $79, $1B
            db    $FF, $06, $02, $09, $0B, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $2B, $00, $00
            db    $00, $00, $00, $00, $7F, $EC, $7F, $00
            db    $00, $00, $00, $00, $00, $00, $20, $64
            db    $03, $FB, $FF, $FB, $20, $84, $03, $FF
            db    $67, $FF, $20, $A4, $43, $FF, $20, $C4
            db    $03, $FF, $24, $FF, $FF

LevelInfoUWQ2Replacements4
            db    $C9, $AC, $89, $86, $06, $10, $72, $00
            db    $FF, $06, $05, $21, $58, $7A, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $10, $00, $00
            db    $00, $00, $00, $00, $CF, $DB, $F3, $00
            db    $00, $00, $00, $00, $00, $00, $20, $64
            db    $43, $FF, $20, $85, $02, $FB, $FF, $20
            db    $A4, $02, $FF, $67, $20, $C4, $43, $FF
            db    $FF

LevelInfoUWQ2Replacements5
            db    $C9, $AC, $89, $87, $0A, $B0, $7D, $4F
            db    $FF, $06, $04, $0F, $6A, $7F, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $5F, $00, $00
            db    $00, $00, $00, $00, $FF, $FF, $E7, $7E
            db    $00, $00, $00, $00, $00, $00, $20, $64
            db    $04, $FF, $FF, $FF, $FB, $20, $84, $04
            db    $FF, $FF, $67, $FF, $20, $A4, $04, $FF
            db    $FF, $FB, $FF, $20, $C4, $04, $FF, $FF
            db    $FF, $67, $FF

LevelInfoUWQ2Replacements6
            db    $49, $79, $89, $56, $04, $00, $74, $16
            db    $FF, $06, $06, $03, $73, $46, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $26, $00, $00
            db    $00, $00, $00, $04, $0C, $7E, $FF, $80
            db    $F0, $00, $00, $00, $00, $00, $20, $65
            db    $03, $FB, $FF, $67, $20, $68, $C2, $FF
            db    $20, $86, $C3, $FF, $20, $85, $83, $FF
            db    $FF, $67, $20, $A3, $02, $FB, $FF, $FF

LevelInfoUWQ2Replacements7
            db    $C9, $AC, $89, $79, $0C, $C0, $7F, $2D
            db    $7F, $07, $08, $02, $03, $04, $05, $20
            db    $21, $26, $2B, $2C, $FF, $3D, $00, $00
            db    $00, $00, $FE, $FE, $82, $82, $82, $BE
            db    $80, $FF, $00, $00, $00, $00, $20, $62
            db    $C3, $FF, $20, $63, $C3, $FF, $20, $64
            db    $45, $67, $20, $69, $C4, $FF, $20, $87
            db    $C2, $FF, $20, $C2, $46, $67, $FF

LevelInfoUWQ2Replacements8
            db    $C9, $AC, $89, $57, $0C, $C0, $79, $1B
            db    $7F, $07, $07, $27, $30, $37, $60, $67
            db    $70, $FF, $FF, $FF, $FF, $1C, $00, $00
            db    $00, $00, $01, $01, $7D, $5D, $5D, $41
            db    $7F, $00, $00, $00, $00, $00, $20, $64
            db    $45, $FB, $20, $84, $05, $FF, $FB, $FB
            db    $24, $FF, $20, $A4, $43, $FF, $20, $A8
            db    $01, $FF, $20, $C2, $46, $FB, $20, $C8
            db    $01, $FF, $FF

LevelInfoUWQ2Replacements9
            db    $C9, $AC, $89, $B6, $04, $00, $74, $07
            db    $7F, $07, $09, $71, $72, $75, $76, $77
            db    $FF, $FF, $FF, $FF, $FF, $17, $00, $00
            db    $00, $00, $CC, $DE, $76, $7F, $7F, $76
            db    $DE, $CC, $00, $00, $00, $00, $20, $62
            db    $48, $FF, $20, $64, $44, $FB, $20, $83
            db    $46, $FB, $20, $84, $44, $FF, $20, $A2
            db    $08, $FF, $FF, $FB, $FF, $FF, $FB, $FF
            db    $FF, $20, $C3, $46, $67, $20, $C5, $42
            db    $FF, $FF

LevelInfoUWQ2ReplacementAddrs
            dw    LevelInfoUWQ2Replacements1
            dw    LevelInfoUWQ2Replacements2
            dw    LevelInfoUWQ2Replacements3
            dw    LevelInfoUWQ2Replacements4
            dw    LevelInfoUWQ2Replacements5
            dw    LevelInfoUWQ2Replacements6
            dw    LevelInfoUWQ2Replacements7
            dw    LevelInfoUWQ2Replacements8
            dw    LevelInfoUWQ2Replacements9

LevelInfoUWQ2ReplacementSizes
            db    $39, $37, $3D, $39, $43, $40, $3F, $43
            db    $4A

; Unknown block
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF

LevelBlockOW
            putbin dat/LevelBlockOW.dat

LevelBlockUW1Q1
            putbin dat/LevelBlockUW1Q1.dat

LevelBlockUW2Q1
            putbin dat/LevelBlockUW2Q1.dat

LevelBlockUW1Q2
            putbin dat/LevelBlockUW1Q2.dat

LevelBlockUW2Q2
            putbin dat/LevelBlockUW2Q2.dat

LevelInfoOW
            putbin dat/LevelInfoOW.dat

LevelInfoUW1
            putbin dat/LevelInfoUW1.dat

LevelInfoUW2
            putbin dat/LevelInfoUW2.dat

LevelInfoUW3
            putbin dat/LevelInfoUW3.dat

LevelInfoUW4
            putbin dat/LevelInfoUW4.dat

LevelInfoUW5
            putbin dat/LevelInfoUW5.dat

LevelInfoUW6
            putbin dat/LevelInfoUW6.dat

LevelInfoUW7
            putbin dat/LevelInfoUW7.dat

LevelInfoUW8
            putbin dat/LevelInfoUW8.dat

LevelInfoUW9
            putbin dat/LevelInfoUW9.dat
CommonDataBlock_Bank6

; .SEGMENT "BANK_06_DATA"




MenuPalettesTransferBuf ENT
            db    $3F, $00, $20, $0F, $30, $00, $12, $0F
            db    $16, $27, $36, $0F, $0C, $1C, $2C, $0F
            db    $12, $1C, $2C, $0F, $29, $27, $07, $0F
            db    $22, $27, $07, $0F, $26, $27, $07, $0F
            db    $15, $27, $30, $FF

LevelPaletteRow7TransferBuf ENT
            db    $3F, $1C, $04, $0F, $0F, $0F, $0F, $FF

LevelNumberTransferBuf ENT
            db    $20, $42, $07, $15, $0E, $1F, $0E, $15
            db    $62, $00, $FF

ColumnDirectoryOW ENT
            db    $D8, $9B, $0D, $9C, $3E, $9C, $80, $9C
            db    $C4, $9C, $F6, $9C, $32, $9D, $6D, $9D
            db    $A8, $9D, $E6, $9D, $27, $9E, $6C, $9E
            db    $A9, $9E, $DF, $9E, $21, $9F, $55, $9F

TriforceRow0TransferBuf ENT
            db    $2A, $EE, $04, $ED, $E9, $EA, $EE, $FF

TriforceRow1TransferBuf
            db    $2B, $0D, $06, $ED, $E9, $24, $24, $EA
            db    $EE, $FF

TriforceRow2TransferBuf
            db    $2B, $2C, $08, $ED, $E9, $24, $24, $24
            db    $24, $EA, $EE, $FF

TriforceRow3TransferBuf
            db    $2B, $4B, $0A, $ED, $E9, $24, $24, $24
            db    $24, $24, $24, $EA, $EE, $FF

TriforceTextTransferBuf
            db    $2B, $AC, $08, $1D, $1B, $12, $0F, $18
            db    $1B, $0C, $0E

; .SEGMENT "BANK_06_DLIST"




TransferBufAddrs
            dw    DynTileBuf
            dw    StoryTileAttrTransferBuf
            dw    Mode8TextTileBuffer
            dw    LevelPaletteRow7TransferBuf
            dw    AquamentusPaletteRow7TransferBuf
            dw    OrangeBossPaletteRow7TransferBuf
            dw    LevelNumberTransferBuf
            dw    StatusBarStaticsTransferBuf
            dw    GameTitleTransferBuf
            dw    MenuPalettesTransferBuf
            dw    Mode1TileTransferBuf
            dw    ModeFCharsTransferBuf
            dw    LevelInfo_PalettesTransferBuf
            dw    DynTileBuf
            dw    DynTileBuf
            dw    BlankTextBoxLines
            dw    GhostPaletteRow7TransferBuf
            dw    GreenBgPaletteRow7TransferBuf
            dw    BrownBgPaletteRow7TransferBuf
            dw    CellarAttrsTransferBuf
            dw    DynTileBuf
            dw    BlankPersonWares
            dw    Mode11DeadLinkPalette
            dw    LevelNumberTransferBuf
            dw    InventoryTextTransferBuf
            dw    SubmenuBoxesTopsTransferBuf
            dw    SubmenuBoxesSidesTransferBuf
            dw    GanonPaletteRow7TransferBuf
            dw    SelectedItemBoxBottomTransferBuf
            dw    UseBButtonTextTransferBuf
            dw    InventoryBoxBottomTransferBuf
            dw    CaveBgPaletteRowsTransferBuf
            dw    SubmenuMapRemainderTransferBuf
            dw    SheetMapBottomEdgeTransferBuf
            dw    LevelInfo_StatusBarMapTransferBuf
            dw    GameOverTransferBuf
            dw    SubmenuAttrs1TransferBuf
            dw    SubmenuAttrs2TransferBuf
            dw    BlankBottomRowNT2TransferBuf
            dw    BlankRowTransferBuf
            dw    SubmenuTriforceApexTransferBuf
            dw    TriforceRow0TransferBuf
            dw    TriforceRow1TransferBuf
            dw    TriforceRow2TransferBuf
            dw    TriforceRow3TransferBuf
            dw    SubmenuTriforceBottomTransferBuf
            dw    TriforceTextTransferBuf
            dw    Mode11BackgroundPaletteBottomHalfTransferBuf
            dw    Mode11PlayAreaAttrsTopHalfTransferBuf
            dw    Mode11PlayAreaAttrsBottomHalfTransferBuf
            dw    DynTileBuf
            dw    DynTileBuf
            dw    DynTileBuf
            dw    EndingPaletteTransferBuf
            dw    BombCapacityPriceTextTransferBuf
            dw    DynTileBuf
            dw    DynTileBuf
            dw    DynTileBuf
            dw    DynTileBuf
            dw    LifeOrMoneyCostTextTransferBuf
            dw    WhitePaletteBottomHalfTransferBuf
            dw    RedArmosPaletteRow7TransferBuf
            dw    GleeokPaletteRow7TransferBuf
            dw    DynTileBuf

TransferCurTileBuf ENT
    LDX TileBufSelector
    LDA TransferBufAddrs, X
    STA $00
    LDA TransferBufAddrs+1, X
    STA $01
    JSR TransferTileBuf

    ; UNKNOWN:
    ; $3D is the maximum size of the dynamic transfer buf. Is this
    ; $3F related? [0300] is only ever written.
    LDA #$3F
    STA $0300
    LDX #$00
    STX TileBufSelector
    STX SwitchNameTablesReq
    STX DynTileBufLen
    DEX
    STX DynTileBuf              ; Empty the tile buffer.
    RTS

ContinueTransferTileBuf
    ;
    ;
    ; Save VRAM address high byte.
    PHA
            JSR   STA_2006
    INY
    LDA ($00), Y                ; Read low byte of VRAM address.
            JSR   STA_2006
    INY
    LDA ($00), Y                ; Read count and attribute byte.
    ASL
    PHA
    LDA CurPpuControl_2000
    ORA #$04
    BCS :Anon0001                      ; If high bit is set, then auto-increment VRAM address by 32.
    AND #$FB
:Anon0001
            JSR   STA_2000
    STA CurPpuControl_2000
    PLA
    ASL
    PHP
    BCC :Anon0002                      ; If bit 6 is set, then repeat one tile.
    ORA #$02
    INY                         ; increment Y index to point to first byte of text.
:Anon0002
    PLP

    ; If the count was 0 (bottom 6 bits),
    ; then make it 64.
    CLC
    BNE :Anon0003
    SEC
:Anon0003
    ROR
    LSR

    ; We pulled the flags out, and we're left with a count in A.
    ; Move it to X.
    TAX

:Loop
    BCS :Anon0004                      ; If the original bit 6 is clear,
    INY                         ; then increment Y index (not repeating).
:Anon0004
    LDA ($00), Y
            JSR   STA_2007
    DEX
    BNE :Loop
    PLA                         ; Restore VRAM address high byte.

    ; If we wrote to $3Fxx, then set PPUADDR to $3F00, then $0000.
    CMP #$3F
    BNE :AdvanceSource
            JSR   STA_2006
            JSR   STX_2006
            JSR   STX_2006
            JSR   STX_2006

:AdvanceSource
    ; Advance the source address to one after the last byte read.
    SEC
    TYA
    ADC $00
    STA $00
    LDA #$00
    ADC $01
    STA $01

TransferTileBuf
            JSR   LDX_2002
    LDY #$00
    LDA ($00), Y                ; Read high byte of VRAM address.
    BPL ContinueTransferTileBuf ; End when we read a negative VRAM address.
    RTS

Mode1TileTransferBuf
            db    $23, $C0, $7F, $00, $23, $D4, $03, $40
            db    $50, $50, $23, $DC, $03, $44, $55, $55
            db    $23, $E4, $03, $44, $55, $55, $20, $A8
            db    $0F, $62, $24, $1C, $24, $0E, $24, $15
            db    $24, $0E, $24, $0C, $24, $1D, $24, $62
            db    $21, $03, $01, $69, $21, $04, $58, $6A
            db    $21, $1C, $01, $6B, $21, $23, $D0, $6C
            db    $21, $3C, $D0, $6C, $23, $23, $01, $6E
            db    $23, $24, $58, $6A, $23, $3C, $01, $6D
            db    $21, $0A, $06, $24, $17, $0A, $16, $0E
            db    $24, $21, $13, $06, $24, $15, $12, $0F
            db    $0E, $24, $22, $A6, $12, $1B, $0E, $10
            db    $12, $1C, $1D, $0E, $1B, $24, $22, $18
            db    $1E, $1B, $24, $17, $0A, $16, $0E, $22
            db    $E6, $10, $0E, $15, $12, $16, $12, $17
            db    $0A, $1D, $12, $18, $17, $24, $16, $18
            db    $0D, $0E, $FF

ModeFCharsTransferBuf
            db    $22, $05, $01, $69, $22, $06, $55, $6A
            db    $22, $1B, $01, $6B, $22, $25, $C7, $6C
            db    $22, $3B, $C7, $6C, $23, $05, $01, $6E
            db    $23, $06, $55, $6A, $23, $1B, $01, $6D
            db    $22, $26, $15, $0A, $24, $0B, $24, $0C
            db    $24, $0D, $24, $0E, $24, $0F, $24, $10
            db    $24, $11, $24, $12, $24, $13, $24, $14
            db    $22, $66, $15, $15, $24, $16, $24, $17
            db    $24, $18, $24, $19, $24, $1A, $24, $1B
            db    $24, $1C, $24, $1D, $24, $1E, $24, $1F
            db    $22, $A6, $15, $20, $24, $21, $24, $22
            db    $24, $23, $24, $62, $24, $63, $24, $28
            db    $24, $29, $24, $2A, $24, $2B, $24, $2C
            db    $22, $E6, $13, $00, $24, $01, $24, $02
            db    $24, $03, $24, $04, $24, $05, $24, $06
            db    $24, $07, $24, $08, $24, $09, $FF

GanonPaletteRow7TransferBuf
            db    $3F, $1C, $04, $0F, $16, $2C, $3C, $FF

EndingPaletteTransferBuf
            db    $3F, $08, $08, $0F, $22, $10, $00, $0F
            db    $2A, $10, $00, $3F, $1C, $04, $0F, $27
            db    $06, $16, $FF

BlankTextBoxLines
            db    $21, $A4, $58, $24, $21, $C4, $58, $24
            db    $FF

BlankPersonWares
            db    $21, $E4, $58, $24, $22, $C8, $4D, $24
            db    $FF

SubmenuTriforceApexTransferBuf
            db    $2A, $CF, $02, $ED, $EE, $FF

SubmenuTriforceBottomTransferBuf
            db    $2B, $6A, $0C, $EB, $EF, $F1, $F1, $F1
            db    $F1, $F1, $F1, $F1, $F1, $F0, $EC, $FF

GhostPaletteRow7TransferBuf
            db    $3F, $1C, $04, $0F, $30, $00, $12, $FF

GreenBgPaletteRow7TransferBuf
            db    $3F, $1C, $04, $0F, $1A, $37, $12, $FF

BrownBgPaletteRow7TransferBuf
            db    $3F, $1C, $04, $0F, $17, $37, $12, $FF

CaveBgPaletteRowsTransferBuf
            db    $3F, $08, $08, $0F, $30, $00, $12, $0F
            db    $07, $0F, $17, $FF

CellarAttrsTransferBuf
            db    $23, $D0, $60, $AA, $23, $F0, $50, $AA
            db    $FF

WhitePaletteBottomHalfTransferBuf
            db    $3F, $08, $08, $0F, $30, $30, $30, $0F
            db    $30, $30, $30, $FF

RedArmosPaletteRow7TransferBuf
            db    $3F, $1C, $04, $0F, $0F, $1C, $16, $FF

GleeokPaletteRow7TransferBuf
            db    $3F, $1C, $04, $0F, $2A, $1A, $0C, $FF

AquamentusPaletteRow7TransferBuf
            db    $3F, $1C, $04, $0F, $0A, $29, $30, $FF

OrangeBossPaletteRow7TransferBuf
            db    $3F, $1C, $04, $0F, $17, $27, $30, $FF

BombCapacityPriceTextTransferBuf
            db    $22, $CD, $04, $62, $01, $00, $00, $FF

LifeOrMoneyCostTextTransferBuf
            db    $22, $CB, $0A, $62, $01, $24, $24, $24
            db    $24, $24, $62, $05, $00, $FF

Mode8TextTileBuffer
            db    $23, $C0, $7F, $00, $21, $4A, $08, $0C
            db    $18, $17, $1D, $12, $17, $1E, $0E, $21
            db    $AA, $04, $1C, $0A, $1F, $0E, $22, $0A
            db    $05, $1B, $0E, $1D, $1B, $22, $FF

StatusBarStaticsTransferBuf
            db    $23, $C2, $0E, $40, $00, $00, $44, $55
            db    $55, $00, $00, $04, $00, $00, $44, $55
            db    $55, $20, $6F, $0E, $69, $0B, $6B, $69
            db    $0A, $6B, $24, $24, $62, $15, $12, $0F
            db    $0E, $62, $20, $CF, $06, $6E, $6A, $6D
            db    $6E, $6A, $6D, $20, $8F, $C2, $6C, $20
            db    $91, $C2, $6C, $20, $92, $C2, $6C, $20
            db    $94, $C2, $6C, $20, $6B, $84, $F7, $24
            db    $F9, $61, $FF

InventoryTextTransferBuf
            db    $29, $84, $09, $12, $17, $1F, $0E, $17
            db    $1D, $18, $1B, $22, $FF

SubmenuBoxesTopsTransferBuf
            db    $29, $C7, $04, $69, $6A, $6A, $6B, $29
            db    $CF, $01, $69, $29, $D0, $4B, $6A, $29
            db    $DB, $01, $6B, $FF

SubmenuBoxesSidesTransferBuf
            db    $29, $E7, $C2, $6C, $29, $EA, $C2, $6C
            db    $29, $EF, $C4, $6C, $29, $FB, $C4, $6C
            db    $FF

SelectedItemBoxBottomTransferBuf
            db    $2A, $27, $04, $6E, $6A, $6A, $6D, $FF

UseBButtonTextTransferBuf
            db    $2A, $42, $0C, $1E, $1C, $0E, $24, $0B
            db    $24, $0B, $1E, $1D, $1D, $18, $17, $FF

InventoryBoxBottomTransferBuf
            db    $2A, $64, $08, $0F, $18, $1B, $24, $1D
            db    $11, $12, $1C, $2A, $6F, $01, $6E, $2A
            db    $70, $4B, $6A, $2A, $7B, $01, $6D, $FF

SubmenuMapRemainderTransferBuf
            db    $2B, $43, $07, $0C, $18, $16, $19, $0A
            db    $1C, $1C, $2A, $A5, $03, $16, $0A, $19
            db    $2A, $8C, $10, $F5, $F5, $FD, $F5, $F5
            db    $FD, $F5, $F5, $FD, $F5, $F5, $F5, $FD
            db    $F5, $F5, $F5, $FF

SheetMapBottomEdgeTransferBuf
            db    $2B, $AC, $10, $F5, $FE, $F5, $F5, $F5
            db    $FE, $F5, $F5, $F5, $F5, $FE, $F5, $F5
            db    $F5, $FE, $F5, $FF

SubmenuAttrs1TransferBuf
            db    $2B, $D9, $43, $05, $2B, $DC, $4B, $00
            db    $FF

SubmenuAttrs2TransferBuf
            db    $2B, $E9, $56, $55, $FF

BlankBottomRowNT2TransferBuf
            db    $2B, $A0, $60, $24, $FF

BlankRowTransferBuf
            db    $28, $E0, $60, $24, $FF

Mode11DeadLinkPalette
            db    $3F, $10, $04, $0F, $10, $30, $00, $FF

GameOverTransferBuf
            db    $23, $E3, $03, $0F, $0F, $CF, $22, $4C
            db    $0A, $10, $0A, $16, $0E, $24, $18, $1F
            db    $0E, $1B, $24, $22, $6C, $4A, $24, $FF

Mode11BackgroundPaletteBottomHalfTransferBuf
            db    $3F, $08, $08, $0F, $17, $16, $26, $0F
            db    $17, $16, $26, $FF

Mode11PlayAreaAttrsTopHalfTransferBuf
            db    $23, $D0, $58, $FF, $FF

Mode11PlayAreaAttrsBottomHalfTransferBuf
            db    $23, $E8, $58, $FF, $FF

StoryTileAttrTransferBuf
            putbin dat/StoryTileAttrTransferBuf.dat

GameTitleTransferBuf
            putbin dat/GameTitleTransferBuf.dat

; .SEGMENT "BANK_06_ISR"




; Unknown block
            db    $78, $D8, $A9, $00, $8D, $00, $20, $A2
            db    $FF, $9A, $AD, $02, $20, $29, $80, $F0
            db    $F9, $AD, $02, $20, $29, $80, $F0, $F9
            db    $09, $FF, $8D, $00, $80, $8D, $00, $A0
            db    $8D, $00, $C0, $8D, $00, $E0, $A9, $0F
            db    $20, $98, $BF, $A9, $00, $8D, $00, $A0
            db    $4A, $8D, $00, $A0, $4A, $8D, $00, $A0
            db    $4A, $8D, $00, $A0, $4A, $8D, $00, $A0
            db    $A9, $07, $20, $AC, $BF, $4C, $40, $E4
            db    $8D, $00, $80, $4A, $8D, $00, $80, $4A
            db    $8D, $00, $80, $4A, $8D, $00, $80, $4A
            db    $8D, $00, $80, $60, $8D, $00, $E0, $4A
            db    $8D, $00, $E0, $4A, $8D, $00, $E0, $4A
            db    $8D, $00, $E0, $4A, $8D, $00, $E0, $60

; .SEGMENT "BANK_06_VEC"




; Unknown block
            db    $84, $E4, $50, $BF, $F0, $BF

; Pad up to $C000 (matching the original NES fixed-bank boundary) before
; embedding Bank07's fixed content, so it starts at the same offset in
; every bank -- see the ORG $8000 comment above.
            ds    $C000-*

; Embedded copy of Bank07's fixed $C000-$FFFF code, so JSR/JMP into
; Bank07-exported routines resolve within this same physical bank.
; Z07_EMBED_BANK tells rom_07_fixed.s which bank-grouped EXT block to
; skip (this bank's own group, since it's defined locally here).
Z07_EMBED_BANK equ 6
            put   rom_07_fixed.s


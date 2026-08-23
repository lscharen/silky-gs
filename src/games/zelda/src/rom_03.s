SetMirrorMode  EXT

            mx    %11
            ds    $5000-*

            put   ../../../rom/rom_inject.s
            put   helpers.s

            ds \,$00

; Create stubs to handle converting self-references into long addressing so it works when the ROM code is
; in another IIgs memory bank.  Our memory model keeps the PBR in a fixed bank so that any access to RAM
; or high ROM ($C000 - $FFFF) always work.  Refrences to the lower ROM ($8000 - $BFFF) need to be translated
; to the correct bank.  The stubs are used to convert the self-references into long addressing so that they work
; properly.

LDAL_PatternBlockSrcAddrsUW_X LDA_LONG_X PatternBlockSrcAddrsUW
LDAL_PatternBlockSrcAddrsOW_X LDA_LONG_X PatternBlockSrcAddrsOW
LDAL_PatternBlockSizesOW_X LDA_LONG_X PatternBlockSizesOW
LDAL_LevelPatternBlockSrcAddrs_X LDA_LONG_X LevelPatternBlockSrcAddrs
LDAL_BossPatternBlockSrcAddrs_X LDA_LONG_X BossPatternBlockSrcAddrs
LDAL_PatternBlockSizesUW_X LDA_LONG_X PatternBlockSizesUW
LDAL_PatternBlockPpuAddrs_X LDA_LONG_X PatternBlockPpuAddrs

; MMC1 memory helper for indirect loads
LDA_00_Y MMC1_LDA_IND_Y $00

            use   BeginEndVars.inc
            use   CaveVars.inc
            use   CommonVars.inc
            use   ObjVars.inc
            use   Variables.inc

; Do not encroach on WRAM (battery-backed space)
            ds    $6000-*

; Anchor label at $6C90, exported so rom_01.s's CopyCommonCodeToRam can replicate
; the shared "Bank 1 common RAM code" block into this bank too (see BANK_01_CODE.md).
            ds    $6C90-*
ROM03CodeAnchor ENT

            ds    $8000-*

; .INCLUDE "Variables.inc" (hoisted to file header)

; .SEGMENT "BANK_03_00"


; Imports from program bank 07




LevelPatternBlockSrcAddrs
            dw    PatternBlockUWSP127
            dw    PatternBlockUWSP127
            dw    PatternBlockUWSP127
            dw    PatternBlockUWSP358
            dw    PatternBlockUWSP469
            dw    PatternBlockUWSP358
            dw    PatternBlockUWSP469
            dw    PatternBlockUWSP127
            dw    PatternBlockUWSP358
            dw    PatternBlockUWSP469

BossPatternBlockSrcAddrs
            dw    PatternBlockUWSPBoss1257
            dw    PatternBlockUWSPBoss1257
            dw    PatternBlockUWSPBoss1257
            dw    PatternBlockUWSPBoss3468
            dw    PatternBlockUWSPBoss3468
            dw    PatternBlockUWSPBoss1257
            dw    PatternBlockUWSPBoss3468
            dw    PatternBlockUWSPBoss1257
            dw    PatternBlockUWSPBoss3468
            dw    PatternBlockUWSPBoss9

PatternBlockSrcAddrsUW
            dw    PatternBlockUWBG
            dw    PatternBlockUWSP

PatternBlockSrcAddrsOW
            dw    PatternBlockOWBG
            dw    PatternBlockOWSP

PatternBlockPpuAddrs
            ddb   $1700
            ddb   $08E0

PatternBlockPpuAddrsExtra
            ddb   $09E0
            ddb   $0C00

PatternBlockSizesOW
            ddb   $0820
            ddb   $0720

PatternBlockSizesUW
            ddb   $0820
            ddb   $0100
            ddb   $0220
            ddb   $0400

TransferLevelPatternBlocks ENT
    JSR TurnOffAllVideo
            JSR   LDA_2002
    JSR ResetPatternBlockIndex
    LDA CurLevel
    BNE TransferLevelPatternBlocksUW    ; Go handle UW levels.

:LoopBlockOW
    JSR FetchPatternBlockInfoOW
    JSR TransferPatternBlock_Bank3
    LDA PatternBlockIndex
    CMP #$02                    ; There are two blocks.
    BNE :LoopBlockOW            ; If we haven't transferred the second, then go do so.

ResetPatternBlockIndex
    LDA #$00
    STA PatternBlockIndex
    RTS

TransferLevelPatternBlocksUW
    JSR FetchPatternBlockAddrUW
    JSR FetchPatternBlockSizeUW
    LDA PatternBlockIndex
    CMP #$02
    BNE TransferLevelPatternBlocksUW    ; If at block index 1, then go transfer the second block.

    ; At this point, we've transferred two common blocks
    ; (BG and sprites). Now UW, transfer bosses and other
    ; specialized sprite patterns.
    JSR FetchPatternBlockAddrUWSpecial
    JSR FetchPatternBlockSizeUW
    JSR FetchPatternBlockUWBoss
    JSR FetchPatternBlockSizeUW
    JMP ResetPatternBlockIndex

FetchPatternBlockAddrUW
    LDA PatternBlockIndex
    ASL
    TAX
;    LDA PatternBlockSrcAddrsUW, X
    jsr LDAL_PatternBlockSrcAddrsUW_X
    STA $00
    INX
;    LDA PatternBlockSrcAddrsUW, X
    jsr LDAL_PatternBlockSrcAddrsUW_X
    STA $01
    RTS

; Returns:
; [$00:01]: source address
; [$03:02]: size
;
FetchPatternBlockInfoOW
    LDA PatternBlockIndex
    ASL
    TAX
;    LDA PatternBlockSrcAddrsOW, X
    jsr LDAL_PatternBlockSrcAddrsOW_X
    STA $00
;    LDA PatternBlockSizesOW, X
    jsr LDAL_PatternBlockSizesOW_X
    STA $02
    INX
;    LDA PatternBlockSrcAddrsOW, X
    jsr LDAL_PatternBlockSrcAddrsOW_X
    STA $01
;    LDA PatternBlockSizesOW, X
    jsr LDAL_PatternBlockSizesOW_X
    STA $03
    RTS

FetchPatternBlockAddrUWSpecial
    LDA CurLevel
    ASL
    TAX
;    LDA LevelPatternBlockSrcAddrs, X
    jsr LDAL_LevelPatternBlockSrcAddrs_X
    STA $00
    INX
;    LDA LevelPatternBlockSrcAddrs, X
    jsr LDAL_LevelPatternBlockSrcAddrs_X
    STA $01
    RTS

FetchPatternBlockUWBoss
    LDA CurLevel
    ASL
    TAX
;    LDA BossPatternBlockSrcAddrs, X
    jsr LDAL_BossPatternBlockSrcAddrs_X
    STA $00
    INX
;    LDA BossPatternBlockSrcAddrs, X
    jsr LDAL_BossPatternBlockSrcAddrs_X
    STA $01
    RTS

FetchPatternBlockSizeUW
    LDA PatternBlockIndex
    ASL
    TAX
;    LDA PatternBlockSizesUW, X
    jsr LDAL_PatternBlockSizesUW_X
    STA $02
    INX
;    LDA PatternBlockSizesUW, X
    jsr LDAL_PatternBlockSizesUW_X
    STA $03

; Params:
; [$00:01]: source address
; [$03:02]: size
;
; Look up and transfer destination PPU address by PatternBlockIndex.
;
TransferPatternBlock_Bank3
    LDA PatternBlockIndex
    ASL
    TAX
;    LDA PatternBlockPpuAddrs, X
    jsr LDAL_PatternBlockPpuAddrs_X
            JSR   STA_2006
    INX
;    LDA PatternBlockPpuAddrs, X
    jsr LDAL_PatternBlockPpuAddrs_X
            JSR   STA_2006
    LDY #$00                    ; Start copying.

:LoopCopy
;    LDA ($00), Y                ; Transfer 1 byte from source pattern block in ROM to PPU.
    jsr LDA_00_Y
            JSR   STA_2007

    ; Increment source address.
    LDA $00
    CLC
    ADC #$01
    STA $00
    LDA $01
    ADC #$00
    STA $01

    ; Decrement count.
    LDA $03
    SEC
    SBC #$01
    STA $03
    LDA $02
    SBC #$00
    STA $02

    ; If count is not zero, go copy more.
    LDA $02
    BNE :LoopCopy
    LDA $03
    BNE :LoopCopy
    INC PatternBlockIndex       ; Mark this block finished, and we're ready for the next one.
    RTS

PatternBlockUWBG
            putbin dat/PatternBlockUWBG.dat

PatternBlockOWBG
            putbin dat/PatternBlockOWBG.dat

PatternBlockOWSP
            putbin dat/PatternBlockOWSP.dat

PatternBlockUWSP358
            putbin dat/PatternBlockUWSP358.dat

PatternBlockUWSP469
            putbin dat/PatternBlockUWSP469.dat

PatternBlockUWSP
            putbin dat/PatternBlockUWSP.dat

PatternBlockUWSP127
            putbin dat/PatternBlockUWSP127.dat

PatternBlockUWSPBoss1257
            putbin dat/PatternBlockUWSPBoss1257.dat

PatternBlockUWSPBoss3468
            putbin dat/PatternBlockUWSPBoss3468.dat

PatternBlockUWSPBoss9
            putbin dat/PatternBlockUWSPBoss9.dat

; .SEGMENT "BANK_03_ISR"
            ds    $BF50-*



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

; .SEGMENT "BANK_03_VEC"




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
Z07_EMBED_BANK equ 3
            put   rom_07_fixed.s


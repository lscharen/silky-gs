; Cross-bank externals, grouped by originating bank. Each group is
; skipped when this file is embedded in the bank it came from (that
; bank defines these locally); see Z07_EMBED_BANK.
; Imports from bank 00
            DO    {Z07_EMBED_BANK#0}
DriveAudio EXT
            FIN

; Imports from bank 01
            DO    {Z07_EMBED_BANK#1}
CheckInitWhirlwindAndBeginUpdate EXT
CheckPassiveTileObjects EXT
CheckPowerTriforceFanfare EXT
CheckTileObjectsBlocking EXT
CopyCommonCodeToRam EXT
InitCave EXT
InitGrumble_Full EXT
InitRupeeStash_Full EXT
InitTrap_Full EXT
InitUnderworldPerson_Full EXT
InitUnderworldPersonLifeOrMoney_Full EXT
SummonWhirlwind EXT
TransferDemoPatterns EXT
UpdateCavePerson EXT
UpdateGrumble_Full EXT
UpdateRupeeStash_Full EXT
UpdateTrap_Full EXT
UpdateUnderworldPerson_Full EXT
UpdateUnderworldPersonLifeOrMoney_Full EXT
UpdateWhirlwind_Full EXT
_CalcDiagonalSpeedIndex EXT
Abs EXT
Add1ToInt16At0 EXT
AddQSpeedToPositionFraction EXT
Anim_SetSpriteDescriptorAttributes EXT
Anim_SetSpriteDescriptorRedPaletteRow EXT
Anim_WriteItemSprites EXT
Anim_WriteSpecificItemSprites EXT
Anim_WriteStaticItemSpritesWithAttributes EXT
AnimateAndDrawObjectWalking EXT
BeginShove EXT
BeginUpdateMode EXT
BoundByRoom EXT
BoundByRoomWithA EXT
CheckLinkCollision EXT
CheckMonsterCollisions EXT
CheckPersonBlocking EXT
DestroyObject_WRAM EXT
DoObjectsCollide EXT
DrawObjectWithAnim EXT
DrawObjectWithType EXT
GetDirectionsAndDistancesToTarget EXT
GetOppositeDir EXT
GetRoomFlagUWItemState EXT
HideObjectSprites EXT
ItemIdToDescriptor EXT
ItemIdToSlot EXT
ItemSlotToPaletteOffsetsOrValues EXT
Link_BeHarmed EXT
MapScreenPosToPpuAddr EXT
MoveShot EXT
PlaceWeapon EXT
PlayBoomerangSfx EXT
PlayEffect EXT
PlaySample EXT
ReverseDirections EXT
SetBoomerangSpeed EXT
ShowLinkSpritesBehindHorizontalDoors EXT
SubQSpeedFromPositionFraction EXT
TryTakeRoomItem EXT
UpdateBombFlashEffect EXT
UpdatePlayerPositionMarker EXT
UpdatePositionMarker EXT
UpdateWorldCurtainEffect EXT
WieldCandle EXT
World_ChangeRupees EXT
WriteBlankPrioritySprites EXT
            FIN

; Imports from bank 02
            DO    {Z07_EMBED_BANK#2}
InitDemo_RunTasks EXT
InitMode1_Full EXT
InitMode13_Full EXT
InitModeEandF_Full EXT
TransferCommonPatterns EXT
UpdateMode0Demo EXT
UpdateMode13WinGame EXT
UpdateMode1Menu EXT
UpdateModeDSave EXT
UpdateModeERegister EXT
UpdateModeFElimination EXT
            FIN

; Imports from bank 03
            DO    {Z07_EMBED_BANK#3}
TransferLevelPatternBlocks EXT
            FIN

; Imports from bank 04
            DO    {Z07_EMBED_BANK#4}
_InitMonsterShot_Unknown54 EXT
CheckZora EXT
DestroyCountedMonsterShot EXT
ExtractHitPointValue EXT
InitAquamentus EXT
InitArmosOrFlyingGhini EXT
InitBlueKeese EXT
InitBoulder EXT
InitBoulderSet EXT
InitBubble EXT
InitDarknut EXT
InitDigdogger1 EXT
InitDigdogger2 EXT
InitDodongo EXT
InitFastOctorock EXT
InitGanon EXT
InitGel EXT
InitGleeok EXT
InitGleeokHead EXT
InitGohma EXT
InitLamnola EXT
InitLeever EXT
InitManhandla EXT
InitMoldorm EXT
InitMonsterShot EXT
InitPatra EXT
InitPeahat EXT
InitPondFairy EXT
InitRedOrBlackKeese EXT
InitRope EXT
InitSlowOctorockOrGhini EXT
InitTektite EXT
InitWalker EXT
InitZelda EXT
RevealAndFlagSecretStairsObj EXT
SetUpDroppedItem EXT
UpdateAquamentus EXT
UpdateArmos EXT
UpdateBlock EXT
UpdateBlueLeever EXT
UpdateBlueWizzrobe EXT
UpdateBoulderSet EXT
UpdateBubble EXT
UpdateCandle EXT
UpdateDarknut EXT
UpdateDigdogger EXT
UpdateDock EXT
UpdateDodongo EXT
UpdateFireball EXT
UpdateFlyingGhini EXT
UpdateGanon EXT
UpdateGel EXT
UpdateGhini EXT
UpdateGibdo EXT
UpdateGleeok EXT
UpdateGleeokHead EXT
UpdateGohma EXT
UpdateGoriya EXT
UpdateGuardFire EXT
UpdateItem EXT
UpdateKeese EXT
UpdateLamnola EXT
UpdateLikeLike EXT
UpdateLynel EXT
UpdateManhandla EXT
UpdateMoblin EXT
UpdateMoldorm EXT
UpdateMonsterArrow EXT
UpdateMonsterShot EXT
UpdateOctorock EXT
UpdatePatra EXT
UpdatePatraChild EXT
UpdatePeahat EXT
UpdatePolsVoice EXT
UpdatePondFairy EXT
UpdateRedLeever EXT
UpdateRedWizzrobe EXT
UpdateRockOrGravestone EXT
UpdateRockWall EXT
UpdateRope EXT
UpdateStalfos EXT
UpdateStandingFire EXT
UpdateStatues EXT
UpdateTektiteOrBoulder EXT
UpdateTree EXT
UpdateVire EXT
UpdateWallmaster EXT
UpdateZelda EXT
UpdateZol EXT
UpdateZora EXT
            FIN

; Imports from bank 05
            DO    {Z07_EMBED_BANK#5}
AnimateAndDrawLinkBehindBackground EXT
CalculateNextRoomForDoor EXT
CalculateNoNextRoom EXT
ChangePlayMapSquareOW EXT
CheckBossSoundEffectUW EXT
CheckDoorway EXT
CheckLadder EXT
CheckShutters EXT
CheckSubroom EXT
CheckUnderworldSecrets EXT
CheckWarps EXT
ClearRam EXT
CreateRoomObjects EXT
DrawItemInInventoryWithX EXT
DrawLinkBetweenRooms EXT
FetchTileMapAddr EXT
FindAndSelectOccupiedItemSlot EXT
FindDoorTypeByDoorBit EXT
FindNextEdgeSpawnCell EXT
HasCompass EXT
InitMode10 EXT
InitMode11 EXT
InitMode12 EXT
InitMode3_Sub2 EXT
InitMode3_Sub3_TransferTopHalfAttrs EXT
InitMode3_Sub4_TransferBottomHalfAttrs EXT
InitMode3_Sub5 EXT
InitMode3_Sub6 EXT
InitMode3_Sub7 EXT
InitMode3_Sub8 EXT
InitMode4 EXT
InitMode6 EXT
InitMode7Submodes EXT
InitMode8 EXT
InitMode9 EXT
InitModeA EXT
InitModeB EXT
InitModeC EXT
InitModeD EXT
InitSaveRam EXT
IsDistanceSafeToSpawn EXT
Link_HandleInput EXT
MaskCurPpuMaskGrayscale EXT
SetupObjRoomBounds EXT
UpdateDoors EXT
UpdateMenuAndMeters EXT
UpdateMode10Stairs_Full EXT
UpdateMode11Death_Full EXT
UpdateMode12EndLevel_Full EXT
UpdateMode7SubmodeAndDrawLink EXT
UpdateMode8ContinueQuestion_Full EXT
WaitAndScrollToSplitBottom EXT
World_FillHearts EXT
            FIN

; Imports from bank 06
            DO    {Z07_EMBED_BANK#6}
CopyCommonDataToRam EXT
InitMode2_Submodes EXT
TransferCurTileBuf EXT
UpdateMode2Load_Full EXT
LevelPaletteRow7TransferBuf EXT
MenuPalettesTransferBuf EXT
            FIN

; .INCLUDE "Variables.inc" (hoisted to file header)
; .INCLUDE "CommonVars.inc" (hoisted to file header)

; .SEGMENT "BANK_07_00"


; Imports from program bank 00


; Imports from program bank 01


; Imports from RAM code bank 01


; Imports from program bank 02


; Imports from program bank 03


; Imports from program bank 04


; Imports from program bank 05


; Imports from program bank 06


; Imports from RAM code bank 06

; Use some space here for custom code
_TableJump
    ASL
    TAY
    PLA
    STA $00
    PLA
    STA $01
    INY

    phb             ; Force memory loads from the executing bank
    phk             ; Since Bank 7 is replicated across all banks,
    plb             ; this is valid
    
    LDA ($00),Y
    STA $02
    INY
    LDA ($00),Y
    STA $03

    plb
    jmp   JMP_IND_02

            ds    $E400-*
Z07Int_PcmSamples
            putbin dat/Z07Int_PcmSamples.dat

PlayAreaColumnAddrs ENT
            db    $30, $65, $46, $65, $5C, $65, $72, $65
            db    $88, $65, $9E, $65, $B4, $65, $CA, $65
            db    $E0, $65, $F6, $65, $0C, $66, $22, $66
            db    $38, $66, $4E, $66, $64, $66, $7A, $66
            db    $90, $66, $A6, $66, $BC, $66, $D2, $66
            db    $E8, $66, $FE, $66, $14, $67, $2A, $67
            db    $40, $67, $56, $67, $6C, $67, $82, $67
            db    $98, $67, $AE, $67, $C4, $67, $DA, $67

RunGame
    LDA #$00
    STA InitializedGame
    LDA #$05
    JSR SwitchBank
    JSR InitSaveRam
    JSR ClearRam
    JSR Z07Int_ClearAllAudioAndVideo
    LDA CurPpuControl_2000      ; Enable NMI.
    ORA #$A0
            JSR   STA_2000
    STA CurPpuControl_2000

Z07Int_LoopForever
;    JMP Z07Int_LoopForever
    rtl                         ; IIgs - an infinite loop with no work need no more attention
    nop
    nop


Z07Int_ClearAllAudioAndVideo
    LDA #$00
            JSR   STA_4011
    LDA #$0F                    ; Turn on audio except DMC.
            JSR   STA_4015

    ; Turn off video.
    ; TODO: except clipping is explicitly disabled. Why?
    LDA #$06
            JSR   STA_2001

TurnOffVideoAndClearArtifacts ENT
    JSR HideAllSprites
    JSR Z07Int_ResetPpuRegisters
    JSR TurnOffAllVideo
    LDA #$20
    JSR Z07Int_ClearNameTableWithHiAddr
    LDA #$28

Z07Int_ClearNameTableWithHiAddr
    LDX #$24
    LDY #$00
    JMP Z07Int_ClearNameTable

IsrNmi
    LDA CurPpuControl_2000
    LDX SwitchNameTablesReq
    BEQ :Z07Int_Anon0001                      ; If need to switch name tables,
    EOR #$02                    ; Switch to the other name table ($2000 <-> $2800).
:Z07Int_Anon0001
    AND #$7F                    ; Disable NMI.
    STA CurPpuControl_2000
    AND #$7E                    ; Make sure table is 0 or 2.
            JSR   STA_2000

    ; Set PPUMASK.
    ; Start with curren mask value, but ...
    LDA CurPpuMask_2001
    LDY IsSprite0CheckActive    ; If checking for sprite 0,
    BNE :Z07Int_EnableAllVideo
    LDY TileBufSelector         ; TODO: or TileBufSelector = 0 and [$17] = 0,
    BNE :Z07Int_SetPpuMask
    LDY $17
    BNE :Z07Int_SetPpuMask

:Z07Int_EnableAllVideo
    ORA #$1E                    ; then make sure all video is on.

:Z07Int_SetPpuMask
            JSR   STA_2001
    STA CurPpuMask_2001

    ; Copy all our sprites to OAM.
    LDA #$00
            JSR   STA_2003
    LDA #$02
            JSR   STA_4014

    ; Reset scroll register.
    LDA #$00
            JSR   STA_2005
            JSR   STA_2005
    LDA #$06
    JSR SwitchBank
    JSR TransferCurTileBuf

    ; Reset PPUADDR.
    ; I believe that the write of $3F00 is unneeded.
    LDA #$3F
            JSR   STA_2006
    LDA #$00
            JSR   STA_2006
            JSR   STA_2006
            JSR   STA_2006

:Z07Int_WaitVBlankEnd
    ; If Sprite 0 Hit is set,
    ; then wait for it to be cleared by the ending of VBLANK.
            JSR   LDA_2002
    AND #$40
;    BNE :Z07Int_WaitVBlankEnd
    nop                             ; IIgs -- do not busy wait for rendering.
    nop
            JSR   LDA_2002

    ; Wait for Sprite 0 hit, if needed.
    LDA IsSprite0CheckActive
    BEQ :Z07Int_CheckScroll
    LDA #$05
    JSR SwitchBank
    JSR WaitAndScrollToSplitBottom

:Z07Int_CheckScroll
    ; If updating a game mode instead of initializing one,
    ; then simply scroll for game modes 0, 5, 9, $B, $C, $13.
    LDA IsUpdatingMode
    BEQ :Z07Int_UpdateTimers
    LDA GameMode
    BEQ :Z07Int_SetScroll
    CMP #$05
    BEQ :Z07Int_SetScroll
    CMP #$09
    BEQ :Z07Int_SetScroll
    CMP #$0B
    BEQ :Z07Int_SetScroll
    CMP #$0C
    BEQ :Z07Int_SetScroll
    CMP #$13
    BNE :Z07Int_UpdateTimers

:Z07Int_SetScroll
            JSR   LDA_2002
    LDA CurHScroll
            JSR   STA_2005
    LDA CurVScroll
            JSR   STA_2005
    LDA CurPpuControl_2000
            JSR   STA_2000

:Z07Int_UpdateTimers
    ; If paused or in menu, then don't decrement timers.
    LDA MenuState
    ORA Paused
    BNE :Z07Int_CheckInput
    LDX #$26                    ; Advance the stun cycle.
    LDA #$3C
    LDY #$4E
    STX $00
    DEC $00, X
    BPL :Z07Int_DecTimers
    LDA #$09
    STA $00, X
    TYA

:Z07Int_DecTimers
    TAX                         ; Decrement timers (object and optionally stun timers).

:Z07Int_LoopTimer
    LDA $00, X
    BEQ :Z07Int_Anon0002
    DEC $00, X
:Z07Int_Anon0002
    DEX
    CPX $00
    BNE :Z07Int_LoopTimer

:Z07Int_CheckInput
    ; Sprite 0 is used for scrolling. Input isn't checked while scrolling.
    LDA IsSprite0CheckActive
    BNE :Z07Int_ScrambleRandom
    JSR Z07Int_ReadInputs

:Z07Int_ScrambleRandom
    LDX #$18                    ; Scramble the random array.
    LDY #$0D
    LDA $00, X
    AND #$02
    STA $00
    LDA $01, X
    AND #$02
    EOR $00
    CLC
    BEQ :Z07Int_LoopRandom
    SEC

:Z07Int_LoopRandom
    ROR $00, X
    INX
    DEY
    BNE :Z07Int_LoopRandom
    LDA #$00
    JSR SwitchBank
    JSR DriveAudio
    INC FrameCounter
    LDA IsUpdatingMode
    BNE :Z07Int_Update
    JSR Z07Int_InitializeGameOrMode
    JMP :Z07Int_EnableNMI

:Z07Int_Update
    JSR Z07Int_UpdateMode

:Z07Int_EnableNMI
    JSR   LDA_2002
    LDA CurPpuControl_2000
    ORA #$80
            JSR   STA_2000
    STA CurPpuControl_2000
;    RTI
    rtl                          ; IIgs - use RTL to return from simulated interrupts

Z07Int_ResetPpuRegisters
    LDA #$00
            JSR   STA_2005
    STA CurHScroll
            JSR   STA_2005
    STA CurVScroll
    LDA #$30
            JSR   STA_2000
    STA CurPpuControl_2000
    RTS

; Params:
; A: Hi byte of starting VRAM address
; X: Tile number
; Y: Tile attribute byte
;
Z07Int_ClearNameTable
    STA $00
    STX $01
    STY $02
            JSR   LDA_2002
    LDA CurPpuControl_2000      ; Make sure to auto-increment VRAM by 1.
    AND #$FB
            JSR   STA_2000
    STA CurPpuControl_2000
    LDA $00
            JSR   STA_2006
    LDY #$00
            JSR   STY_2006

    ; Fill one nametable with the tile.
    LDX #$04
    CMP #$20
    BCS :Z07Int_Anon0003
    ; Begin unverified code 1E5B6
    LDX $02                     ; UNKNOWN: Unused. Even so, it wouldn't make sense.
    ; End unverified code
:Z07Int_Anon0003
    LDY #$00
    LDA $01

:Z07Int_LoopTile
            JSR   STA_2007
    DEY
    BNE :Z07Int_LoopTile
    DEX
    BNE :Z07Int_LoopTile

    ; Fill the related attributes with the attribute byte.
    LDY $02
    LDA $00
    CMP #$20
    BCC :Z07Int_RestoreX
    ADC #$02
            JSR   STA_2006
    LDA #$C0
            JSR   STA_2006
    LDX #$40

:Z07Int_LoopAttr
            TYA
            JSR   STA_2007
    DEX
    BNE :Z07Int_LoopAttr

:Z07Int_RestoreX
    ; Set X to the passed in value.
    ; Y was already its passed in value.
    LDX $01
    RTS

; IIgs - This can be called from any ROM locations and uses the stack address to load a table.  Thus it must be
; aware of the tratment of different memory regions.
TableJump ENT
    jmp  _TableJump
;    ASL                  ; comment out three bytes to make space
;    TAY
;    PLA
    STA $00
    PLA
    STA $01
    INY
    LDA ($00),Y
    STA $02
    INY
    LDA ($00),Y
    STA $03
;    JMP ($0002)
    jmp   JMP_IND_02

HideAllSprites ENT
    LDY #$00
    LDX #$40

:Z07Int_Loop
    LDA #$F8
    STA Sprites, Y
    INY
    INY
    INY
    INY
    DEX
    BNE :Z07Int_Loop
    RTS

; Params:
; A: high byte of high address to reset
; Y: low byte of high address to reset
;
; Resets all bytes from $300 to byte Y of page A.
;
ClearRam0300UpTo ENT
    STA $01
    LDA #$00
    STA $00

:Z07Int_Loop
    LDA #$00
    STA ($00), Y
    DEY
    CPY #$FF
    BNE :Z07Int_Loop
    DEC $01
    LDA $01
    CMP #$03
    BCS :Z07Int_Loop

    ; We overwrote the dynamic transfer buf with zeroes.
    ; But the cleared state of the tile buf has the end marker at
    ; the beginning. Write the end marker.
    LDA #$FF
    STA DynTileBuf
    RTS

TurnOffAllVideo ENT
    LDA #$00
            JSR   STA_2001
    STA CurPpuMask_2001
    RTS

Z07Int_ReadInputs
    LDA #$01                    ; Signal the controllers to poll.
            JSR   STA_4016
    LDA #$00                    ; Finish polling.
            JSR   STA_4016
    STA $03
    STA $04
    TAX
    JSR Z07Int_ReadOneController
    INX

Z07Int_ReadOneController
    ; Read over and over until you get 
    ; two of the same readings in a row
    ; (three from the very beginning).
    ; [02] : previous reading in this loop
    ; [03]/2 : successive matching readings (for each controller)
    STA $02
    LDA #$01                    ; TODO: Why poll again?
            JSR   STA_4016
    LDA #$00
            JSR   STA_4016
    LDY #$08

native_joy EXT
:Z07Int_Read
;    LDA Ctrl1_4016, X
;    LSR
;    ROL ButtonsPressed, X       ; Roll the button bits in. Here ButtonsPressed means "down now".
;    LSR
;    ROL $00                     ; The expansion port reading will be in [$00].
;    DEY
;    BNE :Z07Int_Read            ; IIgs -- 12 bytes

    ldal  native_joy,x
    sta   ButtonsPressed,x
    lda   #0
    sta   $00
    nop
    nop

    LDA ButtonsPressed, X
    CMP $02
    BNE Z07Int_ReadOneController       ; If we didn't get the same reading, then try again.
    INC $03, X
    LDY $03, X
    CPY #$02
    BCC Z07Int_ReadOneController       ; If we didn't get at least two of the same readings, then try again.
    LDA $00                     ; Combine the controller and expansion inputs.
    ORA ButtonsPressed, X
    STA ButtonsPressed, X
    PHA
    EOR ButtonsDown, X
    AND ButtonsPressed, X
    STA ButtonsPressed, X       ; Now ButtonsPressed means "down now instead of before".
    PLA
    STA ButtonsDown, X
    RTS

UpdateTriforcePositionMarker ENT
    LDA CurLevel
    BEQ Z07Int_Exit                    ; If in OW, then return.
    LDA #$05
    JSR SwitchBank
    JSR HasCompass
    BEQ Z07Int_Exit                    ; If player hasn't gotten the compass, then return.
    LDA LevelInfo_TriforceRoomId
    LDX #$04
    JMP UpdatePositionMarker

CalculateNextRoom ENT
    LDY CurLevel
    BEQ Z07Int_CalculateNextRoomOW     ; If in OW, all directions are open.

    ; Look up door type for player's direction.
    LDA ObjDir
    STA $02
    LDA #$05
    JSR SwitchBank
    JSR FindDoorTypeByDoorBit
    LDY $01                     ; The same as [02].

Z07Int_CalculateNextRoom_TableJump
    STY $E7                     ; Set [E7] to a door bit/direction.
    JSR TableJump               ; A holds the door type.

Z07Int_CalculateNextRoom_JumpTable
            dw    CalculateNextRoomForDoor
            dw    CalculateNoNextRoom
            dw    CalculateNextRoomForDoor
            dw    CalculateNextRoomForDoor
            dw    CalculateNextRoomForDoor
            dw    CalculateNextRoomForDoor
            dw    CalculateNextRoomForDoor
            dw    CalculateNextRoomForDoor
            dw    CalculateNoNextRoom

Z07Int_CalculateNextRoomOW
    LDY ObjDir                  ; Use player's direction bit.
    LDA #$00                    ; Use "open" door type.
    BEQ Z07Int_CalculateNextRoom_TableJump

LevelMasks ENT
            db    $01, $02, $04, $08, $10, $20, $40, $80

MarkRoomVisited ENT
    JSR GetRoomFlags
    ORA #$20                    ; Visit state (UW)
    STA ($00), Y

Z07Int_Exit
    RTS

; Returns:
; A: flags for the room in level block world flags
; Y: room ID
; [$00:01]: address of level block world flags
;
GetRoomFlags ENT
    LDA LevelInfo_WorldFlagsAddr
    STA $00
    LDA LevelInfo_WorldFlagsAddr+1
    STA $01
    LDY RoomId
    LDA ($00), Y
    RTS

Z07Int_AnimateRoomItemOnMonster
    ; Put room item object where the first monster is.
    LDA ObjX+1
    STA ObjX+19
    LDA ObjY+1
    STA ObjY+19
    JMP Z07Int_AnimateRoomItemObject   ; Go draw the item at this position.

Z07Int_PopAndExit
    ; Pop and return.
    PLA
:Z07Int_Anon0004
    RTS

Z07Int_MoveAndDrawRoomItem
    ; If the item was taken, or it wasn't active, then return.
    JSR GetRoomFlagUWItemState
    BNE :Z07Int_Anon0004
    LDA ObjState+19             ; Room item object state
    BMI :Z07Int_Anon0004

    ; If the item type is "none" ($3F), then return.
    LDA RoomItemId
    CMP #$3F
    BEQ :Z07Int_Anon0004

    ; If there's a room item, and object 1 is a like-like, stalfos, or gibdo;
    ; then move the item along with the monster.
    LDX #$01
    LDA ObjType+1
    CMP #$17                    ; Like-Like
    BEQ Z07Int_AnimateRoomItemOnMonster
    CMP #$2A                    ; Stalfos
    BEQ Z07Int_AnimateRoomItemOnMonster
    CMP #$30                    ; Gibdo
    BEQ Z07Int_AnimateRoomItemOnMonster

    ; A monster is not carrying the item. So draw the item as usual.
    LDX #$13                    ; Room item is in object slot $13.

Z07Int_AnimateRoomItemObject
    LDA RoomItemId              ; Pass item type to AnimateItemObject.

; Params:
; A: item type
; X: object index
;
AnimateItemObject ENT
    PHA                         ; Save the item ID.

    ; If the lifetime timer of the item >= $F0 and even, then
    ; return without drawing. This makes it flash at first.
    ;
    ; [03A8][X] is used to count down the life of the item.
    LDA Item_ObjItemLifetime, X
    CMP #$F0
    BCC :Z07Int_Anon0005
    LSR
    BCC Z07Int_PopAndExit              ; Pop and return, if timer >= $F0 and even.
:Z07Int_Anon0005
    ; Copy room item object position to sprite descriptor.
    JSR Anim_FetchObjPosForSpriteDescriptor

    ; Look up the item description for this item ID.
    ; Store the item value part of it in [04].
    PLA                         ; Restore the item ID.
    TAX                         ; X now has item ID.
    LDA ItemIdToDescriptor, X
    CMP #$30
    BEQ :Z07Int_SetItemValueFF         ; If item descriptor is $30, go set item value to $FF.
    AND #$0F                    ; only take the item value part of the descriptor.

:Z07Int_SetItemValue
    STA $04                     ; [04] holds the item value.

    ; Get item slot for the item ID, and draw the item.
    LDA ItemIdToSlot, X
    TAX
    TAY                         ; Now X and Y have the item slot.
    JMP Z07Int_DrawItemBySlot

:Z07Int_SetItemValueFF
    ; Begin unverified code 1E731
    LDA #$FF                    ; Use item value $FF.
    BNE :Z07Int_SetItemValue
    ; End unverified code

; Params:
; X: item slot
; Y: item slot
; [00]: X
; [01]: Y
;
DrawItemInInventory ENT
    LDA Items, X
    STA $04                     ; The item inventory value can also serve as a palette row attribute.

; Params:
; X: item slot
; Y: item slot
; [00]: X
; [01]: Y
; [04]: item value / sprite palette row attribute
;
Z07Int_DrawItemBySlot
    LDA ItemSlotToPaletteOffsetsOrValues, X
    CPX #$16                    ; (A) If the item flashes (slots $16, $19, $1A, $1B),
    BEQ :Z07Int_Flash
    CPX #$1A
    BEQ :Z07Int_Flash
    CPX #$1B
    BEQ :Z07Int_Flash
    CPX #$19
    BNE :Z07Int_VariesByColor

:Z07Int_Flash
    LDA FrameCounter            ;  then every 4 frames,
    AND #$08
    LSR
    LSR
    LSR
    ADC #$01                    ; Switch between palettes 5 and 6.

:Z07Int_VariesByColor
    CPX #$00                    ; (B) If the item varies by color (slots 0, 2, 4, 7, $B),
    BEQ :Z07Int_AddItemAndTableValue
    CPX #$04
    BEQ :Z07Int_AddItemAndTableValue
    CPX #$02
    BEQ :Z07Int_AddItemAndTableValue
    CPX #$07
    BEQ :Z07Int_AddItemAndTableValue
    CPX #$0B
    BEQ :Z07Int_AddItemAndTableValue   ; Go add the palette offset we looked up and sprite palette row attribute.

:Z07Int_WriteSprites
    ; We got here in one of three ways:
    ;
    ; A. The item flashes. Attribute value 1 or 2 was chosen
    ;    explicitly.
    ; B. The item color varies. ItemSlotToPaletteOffsetsOrValues
    ;    held an offset that was added to base palette attribute
    ;    passed in [$04]. This corresponds to class 2 items.
    ; C. Item doesn't change color. ItemSlotToPaletteOffsetsOrValues
    ;    held absolute attributes.
    ;
    ; At this point, A holds the final sprite attributes.
    LDX #$00
    STX $0C                     ; [0C] refers to frame 0.
    LDX #$0F

    ; Write sprites.
    ; A holds the calculated sprite attributes.
    ; Y holds the item slot.
    JMP Anim_WriteStaticItemSpritesWithAttributes

:Z07Int_AddItemAndTableValue
    ; Calculate sprite attributes by adding item value / sprite palette
    ; row attribute and the element from ItemSlotToPaletteOffsetsOrValues,
    ; which here represents an offset from the palette row.
    CLC
    ADC $04                     ; Add palette offset to item value / sprite attribute we started with.
    CPX #$00                    ; If item slot is 0 and palette is 6,
    BNE :Z07Int_WriteSprites
    CMP #$02
    BNE :Z07Int_WriteSprites
    LDY #$20                    ; then make the item slot $20, a special slot to differentiate the image of the master sword.
    JMP :Z07Int_WriteSprites           ; Go write the sprites.

Z07Int_DrawStatusBarPotion
    ; We have a potion to draw.
    LDX #$07                    ; Potion item slot.
    STX SelectedItemSlot
    BNE Z07Int_DrawStatusBarItemB      ; Go draw the potion.

DrawStatusBarItemsAndEnsureItemSelected ENT
    ; Draws the selected item and the sword in the status bar.
    ; Before drawing the item, it ensures that SelectedItemSlot
    ; refers to an occupied, equippable item slot.
    ;
    ; This accounts for the fallback behavior between potions
    ; and letters and the two boomerangs.
    ;
    ; Start at slot zero. Normally, it would be used to
    ; check swords. When it's used as the selected item index;
    ; it's a pseudo-slot used for checking boomerangs.
    LDX SelectedItemSlot
    BEQ Z07Int_DrawStatusBarBoomerang  ; If pseudo-slot zero is chosen, then go check boomerangs.
    LDA Items, X
    BEQ Z07Int_CheckMissingItem        ; If there's no item in the current item slot, then go check for potions and letters.
    CPX #$0F                    ; We have an item. See if it's in the letter slot.
    BNE Z07Int_DrawStatusBarItemB      ; If it's not the letter slot, then go draw it.
    LDY Potion                  ; It's in the letter slot. See if we have a potion.
    BNE Z07Int_DrawStatusBarPotion     ; If we have a potion, then go set SelectedItemSlot to its slot, and draw it.
    LSR                         ; Otherwise, we only have a letter.
    ORA #$01                    ; Use only 1 as the palette attribute.

Z07Int_DrawStatusBarItemB
    STA $04                     ; Set palette attribute to inventory value.
    LDA #$1F                    ; Set X and Y coordinates for "B" item in status bar: ($7C, $1F).
    STA $01
    LDA #$7C
    STA $00
    LDA #$05
    JSR SwitchBank
    JSR DrawItemInInventoryWithX
    JMP Z07Int_DrawStatusBarSword      ; Go handle the sword.

Z07Int_DrawStatusBarBoomerang
    LDX #$1E                    ; Check the magic boomerang first.

:Z07Int_LoopBoomerang
    LDA Items, X
    BNE Z07Int_DrawStatusBarItemB      ; If we have one of the boomerangs, then go draw it.
    DEX
    CPX #$1C
    BNE :Z07Int_LoopBoomerang          ; Go check the next boomerang.
    LDX #$00
    JMP Z07Int_EnsureSelectedItem      ; No boomerangs. Go search for an occupied slot starting at 0.

Z07Int_FindItemOrDrawSword
    LDA Items, X

    ; If there's an item in this slot, then SelectedItemSlot was already
    ; set. Go handle the sword instead of drawing the item.
    ; Next frame, we'll draw this item.
    BNE Z07Int_DrawStatusBarSword

Z07Int_EnsureSelectedItem
    TXA                         ; Not found. Search for an occupied slot.
    TAY
    LDA #$05
    JSR SwitchBank
    LDA #$02                    ; Go backwards from current slot.
    JSR FindAndSelectOccupiedItemSlot

Z07Int_DrawStatusBarSword
    ; Handle the sword.
    LDX #$00
    LDA Items, X
    BEQ Z07Int_L1E847_Exit             ; If there's no sword, then return.
    LDA #$1F                    ; Set X and Y coordinates for "A" item in status bar: ($94, $1F).
    STA $01
    LDA #$94
    STA $00
    LDA #$05
    JSR SwitchBank
    JMP DrawItemInInventoryWithX

Z07Int_CheckMissingItem
    ; No item in slot.
    CPX #$07
    BNE Z07Int_FindItemOrDrawSword     ; If the current item slot isn't for potions, then go handle the slot almost as usual.
    LDA InvLetter               ; This slot is for potions but don't have one. Check the letter.
    BEQ Z07Int_EnsureSelectedItem      ; If we don't have a letter, then go look for an occupied slot.
    LDX #$0F                    ; We have a letter. Set SelectedItemSlot to its slot.
    STX SelectedItemSlot
    BNE Z07Int_FindItemOrDrawSword     ; Go handle the sword (indirectly).

Z07Int_CheckLiftItem
    LDA ItemTypeToLift
    BEQ Z07Int_L1E859_Exit             ; If there's no item to lift, then return.
    DEC ItemLiftTimer
    BEQ Z07Int_EndLinkLiftingItem      ; If the item lift timer has expired, go return to normal.

    ; Set player state to halted.
    LDA #$40
    STA ObjState

; Params:
; [0505]: item type
;
SetUpAndDrawLinkLiftingItem ENT
    LDA ObjX                    ; Set item X the same as Link's.
    STA ObjX+19
    LDA ObjY                    ; Set item's Y $10 pixels above Link's.
    SEC
    SBC #$10
    STA ObjY+19

; Params:
; [0505]: item type
;
DrawLinkLiftingItem ENT
    LDX #$00                    ; We're dealing with Link object.
    JSR Anim_FetchObjPosForSpriteDescriptor
    JSR Anim_SetSpriteDescriptorAttributes    ; Set 0 sprite attributes. 0 was returned above.
    STA $0C                     ; Set frame 0.
    LDA #$48                    ; Point to Link's sprites.
    STA LeftSpriteOffset
    LDA #$4C
    STA RightSpriteOffset
    LDY #$21
    JSR Anim_WriteSpecificItemSprites
    INC LeftAlignHalfWidthObj   ; Temporarily set left alignment.
    LDA ItemTypeToLift
    LDX #$13                    ; Now deal with item object.
    JSR AnimateItemObject
    DEC LeftAlignHalfWidthObj
    LDA ProcessedNarrowObj
    BEQ Z07Int_L1E847_Exit             ; If this item is half-width,

    ; Then lift with one hand.
    ; Change the right side to a tile without the arm raised.
    LDA #$08
    STA Sprites+77

Z07Int_L1E847_Exit
    RTS

Z07Int_EndLinkLiftingItem
    ; Make Link idle, and reset the item type.
    LDA #$00
    STA ObjState
    STA ItemTypeToLift

    ; If in UW, play the level's song again.
    LDY CurLevel
    BEQ Z07Int_L1E859_Exit
    LDA Z07Int_LevelSongIds, Y
    STA SongRequest

Z07Int_L1E859_Exit
    RTS

; Returns:
; A: unique room ID
; Y: room ID
;
GetUniqueRoomId ENT
    LDY RoomId
    LDA LevelBlockAttrsD, Y
    AND #$3F                    ; Unique room ID in both OW and UW.
    RTS

; Params:
; A: first tile
; X: object index
; [F7]: not 0 to switch to bank 4 before returning
;
ChangeTileObjTiles ENT
    ; First, cue the transfer of the 4 tiles to nametable 0.
    ;
    ; [05] holds the first tile.
    STA $05
    TXA                         ; Save object index.
    PHA
    LDA ObjX, X
    STA $03                     ; [03] holds the X coordinate.
    LDA ObjY, X
    STA $02                     ; [02] holds the Y coordinate.
    JSR MapScreenPosToPpuAddr
    LDX DynTileBufLen           ; Start writing from where we left off last time.

    ; Two transfer records will be written to the buffer and an end marker.
    ;
    ; Each record is 5 bytes and will transfer 2 tiles arranged vertically.
    ; In total, 11 bytes will be written.
    ;
    ; First, write the high byte of PPU address in each record.
    LDA $00
    STA DynTileBuf, X
    STA DynTileBuf+5, X

    ; Write the low address in the first record. In the second record,
    ; write (low address + 1).
    LDA $01
    STA DynTileBuf+1, X
    STA DynTileBuf+6, X
    INC DynTileBuf+6, X

    ; Write the first tile twice in each record. Patch them later.
    LDA $05
    STA DynTileBuf+3, X
    STA DynTileBuf+4, X
    STA DynTileBuf+8, X
    STA DynTileBuf+9, X

    ; If tile >= $46 and < $F3, add 2 to the tile bytes in the second record.
    ; Add 1 more to the second byte in each record.
    ; Here is an example result of this manipulation:
    ;   record 1: $70, $71
    ;   record 2: $72, $73
    CMP #$46
    BCC :Z07Int_SetCountBytes
    CMP #$F3
    BCS :Z07Int_SetCountBytes
    CLC
    ADC #$02
    STA DynTileBuf+8, X
    STA DynTileBuf+9, X
    INC DynTileBuf+4, X
    INC DynTileBuf+9, X

:Z07Int_SetCountBytes
    ; Set the count byte in each record to $82:
    ; 2 tiles arranged vertically
    LDA #$82
    STA DynTileBuf+2, X
    STA DynTileBuf+7, X

    ; Write the end marker.
    LDA #$FF
    STA DynTileBuf+10, X

    ; Update dynamic buffer length with 10 new bytes.
    TXA
    CLC
    ADC #$0A
    STA DynTileBufLen
    PLA                         ; Restore object index.
    TAX
    LDA #$05
    JSR SwitchBank

    ; Change the tiles in the play area map.
    JSR ChangePlayMapSquareOW

    ; Switch to bank 4, if requested.
    LDA ReturnToBank4
    BEQ :Z07Int_Anon0006
    LDA #$04
    JSR SwitchBank
:Z07Int_Anon0006
    LDA #$00
    STA ReturnToBank4
    RTS

; Params:
; [$0A]: tile
;
FillTileMap ENT
    LDA #$05
    JSR SwitchBank
    JSR FetchTileMapAddr
    LDY #$00

:Z07Int_Loop
    LDA $0A
    STA ($00), Y
    JSR Add1ToInt16At0
    LDA $00
    CMP #$F0
    BNE :Z07Int_Loop
    LDA $01
    CMP #$67
    BNE :Z07Int_Loop
    RTS

; Unknown block
            db    $FF, $FF

Z07Int_InitializeGameOrMode
    LDA InitializedGame
    BNE Z07Int_InitMode
    LDA #$01
    JSR SwitchBank
    JSR CopyCommonCodeToRam
    LDA #$06
    JSR SwitchBank
    JSR CopyCommonDataToRam
    LDA #$5A                    ; Mark Save RAM initialized, so we can check after reset.
    STA SaveRamBegin
    LDA #$A5
    STA SaveRamEnd
    INC InitializedGame
    RTS

Z07Int_InitMode
    LDA #$05
    JSR SwitchBank
    LDA GameMode
    JSR TableJump

Z07Int_InitMode_JumpTable
            dw    Z07Int_InitMode0
            dw    Z07Int_InitMode1
            dw    Z07Int_InitMode2
            dw    Z07Int_InitMode3
            dw    InitMode4
            dw    Z07Int_InitMode5Play
            dw    InitMode6
            dw    Z07Int_InitMode7
            dw    InitMode8
            dw    InitMode9
            dw    InitModeA
            dw    InitModeB
            dw    InitModeC
            dw    InitModeD
            dw    Z07Int_InitModeEandF
            dw    Z07Int_InitModeEandF
            dw    InitMode10
            dw    InitMode11
            dw    InitMode12
            dw    Z07Int_InitMode13

Z07Int_InitMode0
    LDA TransferredCommonPatterns
    CMP #$5A
    BEQ :Z07Int_Anon0007
    LDA #$02
    JSR SwitchBank
    JMP TransferCommonPatterns
:Z07Int_Anon0007
    LDA TransferredDemoPatterns
    CMP #$A5
    BEQ :Z07Int_Anon0008
    LDA #$01
    JSR SwitchBank
    JMP TransferDemoPatterns
:Z07Int_Anon0008
    LDA #$02
    JSR SwitchBank
    JMP InitDemo_RunTasks

Z07Int_InitMode1
    LDA #$02
    JSR SwitchBank
    JMP InitMode1_Full

Z07Int_InitMode2
    JSR TurnOffAllVideo
    LDA GameSubmode
    BNE :Z07Int_InitSubmodes

    ; Submode 0.
    ; First step, transfer level pattern blocks and copy common code.
    JSR ClearRoomHistory

    ; Clear level kill counts.
    LDY #$7F

:Z07Int_ClearCounts
    STA LevelKillCounts, Y
    DEY
    BPL :Z07Int_ClearCounts
    LDA #$03
    JSR SwitchBank
    JSR TransferLevelPatternBlocks
    LDA #$01
    JSR SwitchBank
    JSR CopyCommonCodeToRam

:Z07Int_InitSubmodes
    LDA #$06
    JSR SwitchBank
    JMP InitMode2_Submodes

Z07Int_InitMode7
    LDA #$05
    JSR SwitchBank
    JSR InitMode7Submodes
    LDA IsSprite0CheckActive
    BEQ :Z07Int_Exit                   ; If not checking sprite 0, return.

    ; After the last submode (5 or 6), sprite-0 check was enabled.
    ; So, set the appropriate mirroring for scrolling during mode update.
    LDA _Unknown_F3             ; TODO: [$F3] ?
    BNE :Z07Int_Exit
    INC _Unknown_F3

    ; If player is facing horizontally, then enable vertical mirroring;
    ; else horizontal mirroring.
    LDA ObjDir
    CMP #$04
    BCC :Z07Int_SetVertical
    LDA #$0F                    ; horizontal mirroring
    BNE :Z07Int_SetMirroring

:Z07Int_SetVertical
    LDA #$0E                    ; vertical mirroring

:Z07Int_SetMirroring
    JSR SetMMC1Control

:Z07Int_Exit
    RTS

Z07Int_InitModeEandF
    LDA #$02
    JSR SwitchBank
    JMP InitModeEandF_Full

Z07Int_InitMode13
    ; Make sure horizontal mirroring is on.
    LDA #$0F
    JSR SetMMC1Control
    LDA #$02
    JSR SwitchBank
    JMP InitMode13_Full

Z07Int_InitMode3
    LDA #$05
    JSR SwitchBank
    JSR TurnOffAllVideo
    LDA GameSubmode
    JSR TableJump

Z07Int_InitMode3_JumpTable
            dw    Z07Int_InitMode3_Sub0
            dw    Z07Int_InitMode3_Sub1
            dw    InitMode3_Sub2
            dw    InitMode3_Sub3_TransferTopHalfAttrs
            dw    InitMode3_Sub4_TransferBottomHalfAttrs
            dw    InitMode3_Sub5
            dw    InitMode3_Sub6
            dw    InitMode3_Sub7
            dw    InitMode3_Sub8

Z07Int_InitMode3_Sub0
    LDA #$01
    STA $17                     ; TODO: [17] ?
    INC GameSubmode
    JSR TurnOffVideoAndClearArtifacts

; Returns:
; A: 0
;
; Also resets [0529].
;
ClearRoomHistory ENT
    LDY #$05
    LDA #$00
    STA ForceSwordShot

:Z07Int_Loop
    ; Clear the room history.
    STA RoomHistory, Y
    DEY
    BPL :Z07Int_Loop
    RTS

; Each element is the offset of a palette row starting from
; row 4. Index by save slot number.
SaveSlotToPaletteRowOffset ENT
            db    $00, $04, $08

Z07Int_InitMode3_Sub1
    LDA CurLevel
    BNE :Z07Int_UseStartRoomId         ; If in UW, then go set room ID to StartRoomId.
    LDA CaveSourceRoomId
    CMP #$FF
    BNE :Z07Int_SetRoomId              ; If it's set to a valid room ID, then start there.

:Z07Int_UseStartRoomId
    LDA LevelInfo_StartRoomId

:Z07Int_SetRoomId
    STA RoomId
    CMP CaveSourceRoomId
    BNE PatchAndCueLevelPalettesTransferAndAdvanceSubmode    ; If CaveEnteredRoomId was valid,
    LDA #$FF                    ; then keep CaveEnteredRoomId invalid by default.
    STA CaveSourceRoomId

PatchAndCueLevelPalettesTransferAndAdvanceSubmode ENT
    LDX CurSaveSlot
    LDY SaveSlotToPaletteRowOffset, X

    ; Get the color at byte 1 of row 4, 5, or 6 of menu palettes,
    ; according to save slot. This holds Link's color in that
    ; save slot.
    LDA MenuPalettesTransferBuf+20, Y

    ; Put the value in byte 1 of row 4 of level palettes that will
    ; be transferred.
    STA LevelInfo_PalettesTransferBuf+20
    LDA #$18                    ; Cue transfer of level palettes.
    STA TileBufSelector
    INC GameSubmode
    RTS

DrawSpritesBetweenRooms ENT
    JSR HideAllSprites
    JSR UpdatePlayerPositionMarker
    JSR UpdateTriforcePositionMarker
    LDA #$05
    JSR SwitchBank
    JSR DrawLinkBetweenRooms
    JMP DrawStatusBarItemsAndEnsureItemSelected

ResetPlayerState ENT
    LDA #$00
    STA ObjState
    STA InvClock
    RTS

Z07Int_SpecialBossPaletteTransferBufSelectors
            db    $08, $36, $0A, $0A, $0A, $0A, $7C, $7C
            db    $7C

Z07Int_SpecialBossPaletteObjTypes
            db    $3D, $3E, $38, $39, $32, $31, $43, $44
            db    $45

Z07Int_InitMode5Play
    JSR DrawSpritesBetweenRooms
    JSR Link_EndMoveAndAnimate
    LDA CurLevel
    BEQ :Z07Int_InOW

    ; In UW.
    ;
    ; Certain bosses and boss-like monsters need
    ; their own palettes. If we're dealing with one, then get
    ; the matching transfer buffer selector.
    LDY #$08
    LDA ObjType+1

:Z07Int_FindSpecialBoss
    CMP Z07Int_SpecialBossPaletteObjTypes, Y
    BNE :Z07Int_NextSpecialBoss        ; If the object type doesn't match, go check the next one.
    LDX Z07Int_SpecialBossPaletteTransferBufSelectors, Y
    BNE :Z07Int_SelectTransferBufAndFinishInitPlay    ; Go cue the transfer of this palette row. The selector is in X.

:Z07Int_NextSpecialBoss
    DEY
    BPL :Z07Int_FindSpecialBoss
    BMI :Z07Int_UseLevelPalette        ; If it doesn't match any boss type, go copy and transfer level palette row 7.

:Z07Int_InOW
    ; In OW.
    ;
    ; If the room is 0F and we just walked in instead of
    ; coming out of underground; then play "secret found" tune.
    LDA RoomId
    CMP #$0F
    BNE :Z07Int_ChooseTileObjPalette
    LDA UndergroundExitType
    BNE :Z07Int_ChooseTileObjPalette
    LDA #$04
    STA Tune1Request

:Z07Int_ChooseTileObjPalette
    ; Choose a palette transfer buf for a tile object that has sprites.
    ; Rock, gravestone, Armos1, Armos2
    LDX #$20                    ; Ghost palette row
    LDA ObjType+11
    CMP #$65
    BEQ :Z07Int_SelectTransferBufAndFinishInitPlay    ; If tile object type is gravestone ($65), go cue transfer buf $20.
    CMP #$66
    BEQ :Z07Int_UseXOrGreenPalette     ; If tile object type is Armos1 ($66), go see if the room's attributes should override transfer buf $20.
    CMP #$62
    BNE :Z07Int_UseRedArmosPalette     ; If type is not rock ($62) (so Armos2), go set the right selector.

    ; It's a rock tile object.
    ; Choose palette based on inner palette attribute to match it.
    LDX #$24                    ; Brown palette row

:Z07Int_UseXOrGreenPalette
    LDY RoomId
    LDA LevelBlockAttrsB, Y
    AND #$01
    BNE :Z07Int_SelectTransferBufAndFinishInitPlay    ; If the room's inner palette attribute is odd, go cue transfer buf chosen above ($20 if Armos1, else $24).
    LDX #$22                    ; Green palette row
    BNE :Z07Int_SelectTransferBufAndFinishInitPlay    ; Else it's even, so go cue transfer buf $22.

:Z07Int_UseRedArmosPalette
    ; Tile object is Armos2. Use red Armos palette row.
    LDX #$7A
    BNE :Z07Int_SelectTransferBufAndFinishInitPlay    ; Go cue this transfer buf.

:Z07Int_UseLevelPalette
    ; Patch and cue palette row 7 transfer buf (6) with row 7
    ; of level palette.
    LDY #$03

:Z07Int_PatchColors
    LDA LevelInfo_PalettesTransferBuf+31, Y
    STA LevelPaletteRow7TransferBuf+3, Y
    DEY
    BPL :Z07Int_PatchColors
    LDX #$06

:Z07Int_SelectTransferBufAndFinishInitPlay
    STX TileBufSelector

RunCrossRoomTasksAndBeginUpdateMode_PlayModesNoCellar ENT
    ; Called in modes 5, $B, $C.
    LDA #$05
    JSR SwitchBank
    JSR SetupObjRoomBounds

RunCrossRoomTasksAndBeginUpdateMode_EnterPlayModes ENT
    ; Called in modes 4, 5, 9, $B, $C.
    LDA CurLevel
    BEQ RunCrossRoomTasksAndBeginUpdateMode
    JSR MarkRoomVisited
    JSR WriteBlankPrioritySprites

RunCrossRoomTasksAndBeginUpdateMode ENT
    ; Called in modes 4, 5, 6, 9, $B, $C.
    LDA #$05
    JSR SwitchBank
    JSR CreateRoomObjects

    ; Look for the current room in room history.
    LDY #$00
    LDX #$05
    LDA RoomId

:Z07Int_LoopHistory
    CMP RoomHistory, X
    BNE :Z07Int_Anon0009
    INY
:Z07Int_Anon0009
    DEX
    BPL :Z07Int_LoopHistory

    ; If it's not found, then store at the cycling history index.
    CPY #$00
    BNE :Z07Int_RunTasksMode5
    LDX CurRoomHistoryIndex
    STA RoomHistory, X
    INC CurRoomHistoryIndex
    LDA CurRoomHistoryIndex
    CMP #$06
    BCC :Z07Int_RunTasksMode5
    LDA #$00
    STA CurRoomHistoryIndex

:Z07Int_RunTasksMode5
    ; If not in mode 5, go start updating the mode.
    LDA GameMode
    CMP #$05
    BNE :Z07Int_BeginUpdate            ; If not in mode 5, go start updating.

    ; Run cross-room tasks that apply only to mode 5.
    LDA CurLevel
    BEQ :Z07Int_CheckWhirlwind
    LDA #$05
    JSR SwitchBank
    JSR CheckBossSoundEffectUW

:Z07Int_BeginUpdate
    JMP BeginUpdateMode

:Z07Int_CheckWhirlwind
    LDA #$01
    JSR SwitchBank
    JMP CheckInitWhirlwindAndBeginUpdate

; Unknown block
            db    $FF, $FF, $FF, $FF, $FF, $FF

Z07Int_UpdateMode
    LDA #$02
    JSR SwitchBank
    LDA GameMode
    JSR TableJump

Z07Int_UpdateMode_JumpTable
            dw    UpdateMode0Demo
            dw    UpdateMode1Menu
            dw    Z07Int_UpdateMode2Load
            dw    Z07Int_UpdateMode3Unfurl
            dw    Z07Int_UpdateMode4and6EnterLeave
            dw    Z07Int_UpdateMode5Play
            dw    Z07Int_UpdateMode4and6EnterLeave
            dw    Z07Int_UpdateMode7Scroll
            dw    Z07Int_UpdateMode8ContinueQuestion
            dw    Z07Int_UpdateMode5Play
            dw    Z07Int_UpdateMode5Play
            dw    Z07Int_UpdateMode5Play
            dw    Z07Int_UpdateMode5Play
            dw    UpdateModeDSave
            dw    UpdateModeERegister
            dw    UpdateModeFElimination
            dw    Z07Int_UpdateMode10Stairs
            dw    Z07Int_UpdateMode11Death
            dw    Z07Int_UpdateMode12EndLevel
            dw    UpdateMode13WinGame

Z07Int_UpdateMode7Scroll
    LDA #$05
    JSR SwitchBank
    JSR UpdateMode7SubmodeAndDrawLink
    LDA IsSprite0CheckActive
    BNE :Z07Int_Exit                   ; If still checking sprite 0, return.
    STA _Unknown_F3             ; TODO: Reset [$F3].
    LDA #$0F                    ; Set horizontal mirroring and our normal PRG ROM bank mode.
    JSR SetMMC1Control

:Z07Int_Exit
    RTS

Z07Int_UpdateMode8ContinueQuestion
    LDA #$05
    JSR SwitchBank
    JMP UpdateMode8ContinueQuestion_Full

Z07Int_UpdateMode10Stairs
    LDA #$05
    JSR SwitchBank
    JMP UpdateMode10Stairs_Full

Z07Int_UpdateMode11Death
    LDA #$05
    JSR SwitchBank
    JMP UpdateMode11Death_Full

Z07Int_UpdateMode12EndLevel
    LDA #$05
    JSR SwitchBank
    JMP UpdateMode12EndLevel_Full

Z07Int_UpdateMode2Load
    JSR TurnOffAllVideo
    LDA #$06
    JSR SwitchBank
    JSR UpdateMode2Load_Full

; Returns:
; A: zero
;
GoToNextMode ENT
    INC GameMode

; Sets IsUpdatingMode to 0.
; Sets submode to 0.
;
; Returns:
; A: 0
;
EndGameMode ENT
    LDA #$00
    STA IsUpdatingMode
    STA GameSubmode
    RTS

Z07Int_UpdateMode3Unfurl
    JSR UpdateWorldCurtainEffect
    LDA ObjX+12
    BNE Z07Int_L1EBF8_Exit             ; If the left column hasn't reached the left edge, then return.
    LDA #$0F                    ; Set horizontal mirroring.
    JSR SetMMC1Control
    LDA UndergroundExitType
    BEQ :Z07Int_Anon0010                      ; If underground exit type <> 0, then in OW and ...
    JMP Z07Int_GoToNextModeResetGridOffset    ; go to next mode, and reset Link's relative position.
:Z07Int_Anon0010
    JMP Z07Int_GoToNextModePlayLevelSong    ; Else go play level song, next mode, and reset Link's relative position.

Z07Int_UpdateMode4and6EnterLeave
    LDA UndergroundExitType
    BNE Z07Int_StepOutside             ; If UndergroundExitType is set, go step out of underground (or cellar).

    ; We're walking from room to room:
    ; * entering in mode 4 (method 2)
    ; * leaving in mode 6
    LDA ObjGridOffset           ; If relative position reaches 0, 8, or -8; then go to the next mode.
    BEQ Z07Int_GoToNextModeResetGridOffset
    CMP #$08
    BEQ Z07Int_GoToNextModeResetGridOffset
    CMP #$F8
    BEQ Z07Int_GoToNextModeResetGridOffset
    LDA ObjDir
    STA ObjInputDir
    STA $0F                     ; Pass direction in [0F] to MoveObject.
    LDX #$00                    ; Link object index.
    JSR MoveObject
    JMP Link_EndMoveAndAnimateInRoom

Z07Int_LevelSongIds
            db    $01, $40, $40, $40, $40, $40, $40, $40
            db    $40, $20

Z07Int_GoToNextModePlayLevelSong
    LDY CurLevel
    LDA Z07Int_LevelSongIds, Y
    STA SongRequest             ; Play the song for the level.

Z07Int_GoToNextModeResetGridOffset
    JSR GoToNextMode
    STA ObjGridOffset

Z07Int_L1EBF8_Exit
    RTS

Z07Int_StepOutside
    ; We're stepping out of underground or cellar.
    ; If in UW, then go finish the mode.
    LDA CurLevel
    BNE Z07Int_GoToNextModePlayLevelSong

    ; If the player stepped on stairs instead of an opening, then
    ; go finish the mode.
    LDA UndergroundEntranceTile
    CMP #$24
    BNE Z07Int_GoToNextModePlayLevelSong

    ; We're entering the OW room from a cave or dungeon.
    LDA #$05
    JSR SwitchBank
    JSR AnimateAndDrawLinkBehindBackground

    ; Every 4 frames, move Link up 1 pixel.
    LDA FrameCounter
    AND #$03
    BNE :Z07Int_Exit
    DEC ObjY
    LDA ObjY
    CMP StairsTargetY
    BEQ Z07Int_GoToNextModePlayLevelSong    ; If Link has reached the target position, go finish the mode.

:Z07Int_Exit
    RTS

Z07Int_UpdateMode5Play
    ; While the flute timer has not expired, return.
    LDA FluteTimer
    BNE Z07Int_L1EBF8_Exit

    ; If brightening the room, then animate it.
    LDA BrighteningRoom
    BEQ :Z07Int_CheckMenuAndPause
    LDA #$04
    JSR SwitchBank
    JMP UpdateCandle

:Z07Int_CheckMenuAndPause
    ; Check menu and pause.
    LDA MenuState
    BNE :Z07Int_CheckMenu              ; If the submenu is active, go update it.
    LDA Paused
    CMP #$02
    BEQ :Z07Int_CheckPaused            ; If involuntarily paused, skip checking Select button here. But go do pause actions.

    ; Not paused or paused voluntarily.
    ; Check Select button.
    LDA ButtonsPressed
    AND #$20
    BEQ :Z07Int_CheckPaused            ; If pressed Select,
    LDA Paused                  ; then toggle pause.
    EOR #$01
    STA Paused
    BNE :Z07Int_CheckPaused            ; If not paused,
    LDA #$0F                    ; then enable sound.
            JSR   STA_4015

:Z07Int_CheckPaused
    ; If paused, then make sure to use NT 0,
    ; update hearts and rupees, and return.
    LDA Paused
    BEQ :Z07Int_CheckMenu              ; If not paused, go update the submenu or world.
    LDA #$05
    JSR SwitchBank
    JSR MaskCurPpuMaskGrayscale
    JMP UpdateHeartsAndRupees

:Z07Int_CheckMenu
    ; Not paused.
    JSR HideObjectSprites
    LDA ButtonsDown             ; Save current direction from input buttons.
    AND #$0F
    STA ObjInputDir
    LDA MenuState
    BEQ :Z07Int_NotInMenu              ; If not in the submenu, go check Start or update the world.

    ; In submenu.
    LDA #$05
    JSR SwitchBank
    JSR MaskCurPpuMaskGrayscale
    JMP UpdateMenuAndMeters

:Z07Int_NotInMenu
    ; Not in submenu.
    LDA ButtonsPressed
    AND #$10
    BEQ Z07Int_BeginUpdateWorld        ; If Start not pressed, go update the world.
    INC MenuState               ; Else set menu state 1 to start scrolling.
    RTS

Z07Int_BeginUpdateWorld
    ; If we have the clock, then
    ; force the player's invincibility.
    LDA InvClock
    BEQ :Z07Int_NotInvincible
    LDA ObjInvincibilityTimer
    CLC
    ADC #$10
    STA ObjInvincibilityTimer

:Z07Int_NotInvincible
    ; Update the player.
    JSR UpdatePlayer
    LDA IsUpdatingMode
    BNE :Z07Int_CheckChaseTarget       ; If not updating anymore,
    JMP :Z07Int_FinishUpdatePlay       ; then we changed the mode, so don't update anything else.

:Z07Int_CheckChaseTarget
    ; If Link can be chased, then set his coordinates as the target.
    LDA ChaseOtherTarget
    BNE :Z07Int_UpdateWeapons
    LDA ObjX
    STA ChaseTargetX
    LDA ObjY
    STA ChaseTargetY

:Z07Int_UpdateWeapons
    ; Update weapons and items.
    LDX #$0D
    JSR Z07Int_UpdateSwordOrRod
    LDX #$0E
    JSR Z07Int_UpdateSwordShotOrMagicShot
    LDX #$0F
    JSR Z07Int_UpdateBoomerangOrFood
    LDX #$10
    JSR Z07Int_UpdateBombOrFire
    LDX #$11
    JSR Z07Int_UpdateBombOrFire
    LDX #$12
    JSR Z07Int_UpdateRodOrArrow

    ; If it's not time to change the chase target, then
    ; skip this and go update objects.
    LDA ChaseLongTimer
    BNE :Z07Int_LoopObject

    ; Set the chase long-timer to a random value between 0 and 7.
    LDA Random+1
    AND #$07
    STA ChaseLongTimer

    ; Switch the flag indicating whether Link is the target.
    ; If the value is 0 (Link *is* the target), then
    ; skip this and go update objects.
    LDA ChaseOtherTarget
    EOR #$01
    STA ChaseOtherTarget
    BEQ :Z07Int_LoopObject

    ; If Link's X has not changed since the last frame
    ; (when Link was the target), then XOR the chase target
    ; coordinates (which were Link's coordinates last frame).
    ;
    ; This ends up reflecting Link's coordinates across the room;
    ; so that monsters chase away from him.
    ;
    ; But if Link's X has changed since the last frame, then
    ; leave the chase target coordinates with his old coordinates.
    LDA ChaseTargetX
    CMP ObjX
    BNE :Z07Int_LoopObject
    EOR #$FF
    STA ChaseTargetX
    LDA ChaseTargetY
    EOR #$FF
    STA ChaseTargetY

:Z07Int_LoopObject
    ; Update objects from $B to 1.
    LDX CurObjIndex
    JSR DecrementInvincibilityTimer
    LDA ObjType, X
    BEQ :Z07Int_NextObject
    LDA ObjType, X
    JSR Z07Int_UpdateObject

    ; If the object is autonomous and not checking collisions itself,
    ; then see about checking collisions and drawing on its behalf.
    ;
    ; Else go loop again.
    LDX CurObjIndex
    LDA ObjMetastate, X
    BNE :Z07Int_NextObject
    LDA ObjAttr, X
    AND #$01                    ; Self checks collisions and draws
    BNE :Z07Int_NextObject

    ; If no attribute 1, then it indicates not to skip drawing. So, animate and draw.
    LDA ObjAttr, X
    AND #$04                    ; Self-draw attribute
    BNE :Z07Int_Anon0011
    JSR AnimateAndDrawObjectWalking
:Z07Int_Anon0011
    ; Either way, we'll check collisions.
    LDX CurObjIndex
    JSR CheckMonsterCollisions

:Z07Int_NextObject
    ; Bottom of the object update loop.
    DEC CurObjIndex
    BNE :Z07Int_LoopObject

    ; Set the current object slot to what it should be when we
    ; begin updating objects again next frame: $B
    ; the last object slot for monsters and tile objects
    ;
    ; Before the first frame of mode 5, the current object slot variable
    ; was set to $B in 05:87B9 (InitMode_EnterRoom).
    ;
    ; This can also be called the last slot for dynamically allocated objects.
    LDA #$0B
    STA CurObjIndex

    ; If full hearts = 0, then only a partial heart is left.
    ; So, turn on the "heart warning".
    LDA HeartValues
    AND #$0F
    BNE :Z07Int_CheckUW
    LDA Tune0Request
    ORA #$40
    STA Tune0Request

:Z07Int_CheckUW
    ; If in UW, check statues, doors, secrets, and the power triforce.
    LDA CurLevel
    BEQ :Z07Int_CheckOW
    LDA #$04
    JSR SwitchBank
    JSR UpdateStatues           ; Update statues.
    JSR UpdateTriforcePositionMarker
    LDA #$05
    JSR SwitchBank
    JSR CheckUnderworldSecrets
    JSR CheckShutters
    JSR UpdateDoors
    LDA #$01
    JSR SwitchBank
    JSR CheckPowerTriforceFanfare    ; Check triforce fanfare.
    JMP :Z07Int_TransferStatusBarMap

:Z07Int_CheckOW
    ; In OW.
    ; If game mode = 5, turn on sea sound effect if the room's
    ; attributes call for it.
    LDA GameMode
    CMP #$05
    BNE :Z07Int_CheckZora
    LDY RoomId
    LDA LevelBlockAttrsA, Y
    AND #$04                    ; Sea sound effect
    ASL
    ASL
    ASL
    JSR PlayEffect

:Z07Int_CheckZora
    ; In OW, make a zora, if applicable.
    LDA #$04
    JSR SwitchBank
    JSR CheckZora               ; Check zora.

:Z07Int_TransferStatusBarMap
    ; If there are tiles or palettes in the dynamic transfer buf, then
    ; do not handle the status bar map trigger.
    LDA DynTileBufLen
    BNE :Z07Int_FinishUpdatePlay

    ; Transfer the level's status bar map, if we got the signal.
    LDA StatusBarMapTrigger
    BEQ :Z07Int_FinishUpdatePlay
    LDA #$00
    STA StatusBarMapTrigger
    LDA #$44                    ; Cue the transfer of the level's status bar map.
    STA TileBufSelector

:Z07Int_FinishUpdatePlay
    ; These actions are done after Link is updated, regardless
    ; of whether other objects were updated.
    JSR Z07Int_CheckLiftItem
    JSR Z07Int_MoveAndDrawRoomItem
    JSR TryTakeRoomItem
    JSR DrawStatusBarItemsAndEnsureItemSelected

UpdateHeartsAndRupees ENT
    LDA #$05
    JSR SwitchBank
    JSR World_FillHearts
    JMP World_ChangeRupees

; Unknown block
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF

UpdatePlayer ENT
    LDX #$00
    JSR DecrementInvincibilityTimer

    ; If Link is halted, then return.
    LDA ObjState
    AND #$C0
    CMP #$40
    BEQ Z07Int_L1EDEA_Exit

    ; If Link is paralyzed (by a like-like), then
    ; reset input direction.
    ;
    ; As far as I can tell, ObjInputDir could have been set to 0,
    ; instead of masking with $F0 for the same effect.
    LDA LinkParalyzed
    BEQ :Z07Int_Anon0012
    LDA ObjInputDir
    AND #$F0
    STA ObjInputDir
:Z07Int_Anon0012
    LDA #$05
    JSR SwitchBank
    JSR Link_HandleInput
    JSR Walker_Move

Link_EndMoveAndAnimateInRoom ENT
    LDA GameMode
    CMP #$0A
    BEQ Z07Int_L1EDEA_Exit             ; If in mode $A, then return.
    JSR Link_EndMoveAndAnimate
    LDA CurLevel
    BEQ :Z07Int_Exit                   ; If in UW, then show link behind doors.
    JSR ShowLinkSpritesBehindHorizontalDoors

:Z07Int_Exit
    LDX #$00

; Params:
; X: 0
;
; Ensure that, if grid offset = 0, then X is a multiple of 8,
; and Y is (multiple of 8) OR 5. For example, ($30, $7D) or ($58, $B5).
;
Z07Int_EnsureObjectAligned
    LDA ObjGridOffset, X
    BNE Z07Int_L1EDEA_Exit
    LDA ObjX, X
    AND #$F8
    STA ObjX, X
    LDA ObjY, X
    AND #$F8
    ORA #$05
    STA ObjY, X

Z07Int_L1EDEA_Exit
    RTS

Z07Int_WalkableTiles
            db    $8D, $91, $9C, $AC, $AD, $CC, $D2, $D5
            db    $DF

; Params:
; X: object index
;
; Returns:
; A: tile
; [049E][X]: tile
;
GetCollidableTileStill ENT
    LDY #$00
    STY $0F
    BEQ GetCollidableTile

; Params:
; X: object index
; [0F]: direction
;
; Returns:
; A: tile
; [049E][X]: tile
;
GetCollidingTileMoving ENT
    LDY #$F8                    ; Use -8 ($F8) for the hotspot offset, if it's Link.
    CPX #$00
    BEQ :Z07Int_Anon0013                      ; If it's not Link,
    LDY #$F0                    ; then use -$10 ($F0) for the hotspot offset.
:Z07Int_Anon0013
    ; If direction is up, left, or 0,
    ; then use the offset we determined above.
    LDA $0F
    AND #$05
    BEQ GetCollidableTile

    ; Else if it's down,
    ; then use offset 8.
    LDY #$08
    AND #$04
    BNE GetCollidableTile

    ; For right, use offset $10.
    LDY #$10

; Params:
; X: object index
; Y: offset from hotspot
; [0F]: direction or 0
;
; Returns:
; A: tile
; [049E][X]: tile
;
GetCollidableTile ENT
    STY $04
    LDA ObjY, X                 ; Start with a Y coordinate $B pixels down from top of object.
    CLC
    ADC #$0B
    TAY
    PHA                         ; Save this first adjusted Y coordinate.
    LDA $0F
    AND #$0C
    BEQ :Z07Int_AdjustX                ; If direction is horizontal or 0, go adjust X coordinate.
    AND #$04                    ; If direction is down and Y coordinate < $DD,
    BEQ :Z07Int_AdjustY
    CPY #$DD
    BCS :Z07Int_AsIsX

:Z07Int_AdjustY
    PLA                         ; then pop Y coordinate,
    CLC                         ; and add [04] offset from hotspot.
    ADC $04
    PHA                         ; Save adjusted Y coordinate.

:Z07Int_AsIsX
    ; Take the X coordinate as is.
    LDY ObjX, X
    JMP :Z07Int_FetchTile

:Z07Int_AdjustX
    ; Adjust the X coordinate.
    LDY ObjX, X

    ; If direction is left and X coordinate >= $10
    ; or direction is right and X coordinate < $F0,
    LDA $0F
    AND #$01
    BEQ :Z07Int_CheckLeftBoundary
    CPY #$F0
    BCS :Z07Int_FetchTile
    BCC :Z07Int_AddHotspotOffset

:Z07Int_CheckLeftBoundary
    CPY #$10
    BCC :Z07Int_FetchTile

:Z07Int_AddHotspotOffset
    TYA                         ; then add [04] offset from hotspot.
    CLC
    ADC $04
    TAY

:Z07Int_FetchTile
    TYA
    AND #$F8                    ; Mask to make X coordinate a multiple of 8, the column size.

    ; Divide this multiple by 4 to get the offset of the 2-byte address.
    LSR
    LSR
    TAY
    LDA PlayAreaColumnAddrs, Y  ; Put the address of the column in [00:01].
    STA $00
    LDA PlayAreaColumnAddrs+1, Y
    STA $01
    PLA                         ; Restore adjusted Y coordinate.
    SEC                         ; Subtract status bar height $40 from Y coordinate.
    SBC #$40
    LSR                         ; Divide Y coordinate by 8 to get the row it sits inside.
    LSR
    LSR
    TAY
    LDA ($00), Y                ; Get the tile at this column and row.
    STA ObjCollidedTile, X      ; Store the tile in the object's tile slot.
    LDA $0F
    AND #$0C
    BEQ :Z07Int_CheckWalkable          ; If direction in [0F] is horizontal or 0, skip checking another column.

    ; The direction in [0F] is vertical. Check the tile in the next column.
    ; It might be a blocking tile. Blocking tiles are arranged after
    ; walkable tiles.
    TYA
    CLC
    ADC #$16
    TAY
    LDA ($00), Y
    CMP ObjCollidedTile, X
    BCC :Z07Int_CheckWalkable          ; If second tile number >= first tile number,
    STA ObjCollidedTile, X      ; Use the second one, because it might be blocking.

:Z07Int_CheckWalkable
    LDA ObjCollidedTile, X      ; Get the tile to return, if needed.
    LDY CurLevel
    BNE :Z07Int_Exit                   ; If in UW, then return.

    ; Look for the tile in a list of walkable tiles. If it's found,
    ; then turn it into $26 to simplify walkability tests.
    LDA ObjCollidedTile, X
    LDY #$09

:Z07Int_MatchWalkableTile
    DEY
    BMI :Z07Int_SetTile                ; If the tile wasn't found, quit the loop.
    CMP Z07Int_WalkableTiles, Y
    BNE :Z07Int_MatchWalkableTile      ; If the tile doesn't match this element, go check the next one.

    ; The tile was found in the list. Substitute $26 for it.
    LDA #$26

:Z07Int_SetTile
    STA ObjCollidedTile, X
    CPX #$00
    BNE :Z07Int_ReturnTile             ; If the object is not Link, then return without changing anything else.
    LDA RoomId
    CMP #$1F
    BNE :Z07Int_ReturnTile             ; If not in special OW room $1F, return. There's a false wall.
    LDA #$0C
    AND $0F
    BEQ :Z07Int_ReturnTile             ; If direction is horizontal or 0, then return.

    ; If Link is at X=$80, Y<$56; then set the tile to walkable tile $26.
    LDA ObjX
    CMP #$80
    BNE :Z07Int_ReturnTile
    LDA ObjY
    CMP #$56
    BCS :Z07Int_ReturnTile
    LDA #$26
    STA ObjCollidedTile

:Z07Int_ReturnTile
    LDA ObjCollidedTile, X

:Z07Int_Exit
    RTS

Obj_Shove ENT
    ; If this is not the first call to this routine for this instance of shoving (high bit is clear),
    ; then go handle it separately.
    LDA ObjShoveDir, X
    ASL
    BCC :Z07Int_MoveIfNotDone

    ; Clear the high bit, so we don't repeat this initialization.
    LSR
    STA ObjShoveDir, X

    ; If the object faces horizontally, go check which axis shove
    ; direction is on.
    LDY ObjDir, X
    CPY #$03
    BCC :Z07Int_FacingHorizontally

    ; The object faces vertically.
    ;
    ; If the shove direction is vertical, return. We're OK to shove.
    AND #$03
    BEQ :Z07Int_Exit

:Z07Int_CheckPerpendicularShove
    ; Allow a perpendicular shove, if grid offset = 0.
    LDA ObjGridOffset, X
    BEQ :Z07Int_Exit

    ; Else change the shove direction.
    ;
    ; If the object is not Link, then reset it.
    CPX #$00
    BNE ResetShoveInfo

    ; Since it's Link, shove in the opposite direction that he's facing.
    ; Begin unverified code 1EED3
    LDA ObjDir
    JSR GetOppositeDir
    STA ObjShoveDir
    ; End unverified code

:Z07Int_Exit
    RTS

:Z07Int_FacingHorizontally
    ; If shove direction is horizontal, return. We're OK to shove.
    ; Else go check the object's grid offset.
    AND #$0C
    BNE :Z07Int_CheckPerpendicularShove
    RTS

:Z07Int_MoveIfNotDone
    ; If shove distance hasn't gone down to 0, go move some more.
    ; Else reset shove info.
    LDA ObjShoveDistance, X
    BNE Z07Int_ShoveMoveMin

; Returns:
; A: 0
;
ResetShoveInfo ENT
    LDA #$00

; Params:
; A: 0
;
; Returns:
; A: 0
;
SetShoveInfoWith0 ENT
    STA ObjShoveDir, X
    STA ObjShoveDistance, X
    RTS

Z07Int_ShoveMoveMin
    ; Try to move 4 pixels. [03] is the counter.
    LDA #$04
    STA $03

:Z07Int_LoopShovePixel
    ; If the object's grid offset = 0, make sure it's aligned to the grid.
    ; Then, stop shoving if the object hits a tile.
    LDA ObjGridOffset, X
    BNE :Z07Int_CheckBoundary
    JSR Z07Int_EnsureObjectAligned
    LDA ObjShoveDir, X
    AND #$0F
    STA $0F
    JSR GetCollidingTileMoving
    CMP ObjectFirstUnwalkableTile
    BCS ResetShoveInfo

:Z07Int_CheckBoundary
    ; Regardless of the grid offset, if the object runs into the
    ; bounds of the room, then stop shoving.
    LDA ObjShoveDir, X
    AND #$0F
    JSR BoundByRoomWithA
    BEQ ResetShoveInfo

    ; If there is a grumble moblin or person in the room (regardless
    ; of which object is being shoved), then see if it's blocked by
    ; the person. Stop shoving if it is blocked.
    LDA ObjType+1
    CMP #$36
    BEQ :Z07Int_CheckBlocked
    CMP #$4B
    BCC :Z07Int_ChooseSpeed
    CMP #$53
    BCS :Z07Int_ChooseSpeed

:Z07Int_CheckBlocked
    JSR CheckPersonBlocking
    LDA $0F
    BEQ ResetShoveInfo

:Z07Int_ChooseSpeed
    ; If the direction is right or down, store 1 in [02], else -1.
    ; This is the amount to change the relevant coordinate by.
    LDY #$01
    LDA ObjShoveDir, X
    AND #$05
    BNE :Z07Int_Anon0014
    LDY #$FF
:Z07Int_Anon0014
    STY $02

    ; We're OK to change the position. So, decrease the distance
    ; that's left to move.
    DEC ObjShoveDistance, X

    ; Change the grid offset by the amount in [02] (1, -1).
    LDA ObjGridOffset, X
    CLC
    ADC $02
    STA ObjGridOffset, X

    ; If grid offset is a multiple of $10, or the object is Link and grid offset
    ; is a multiple of 8, then reset grid offset.
    AND #$0F
    BEQ :Z07Int_SetGridOffset
    CPX #$00
    BNE :Z07Int_ApplySpeed
    AND #$07
    BNE :Z07Int_ApplySpeed

:Z07Int_SetGridOffset
    STA ObjGridOffset, X

:Z07Int_ApplySpeed
    ; If the direction is horizontal, add the amount in [02] to X.
    LDA ObjShoveDir, X
    AND #$03
    BEQ :Z07Int_AddToY
    LDA ObjX, X
    CLC
    ADC $02
    STA ObjX, X
    JMP :Z07Int_NextShovePixel

:Z07Int_AddToY
    ; Else add the amount to Y coordinate.
    LDA ObjY, X
    CLC
    ADC $02
    STA ObjY, X

:Z07Int_NextShovePixel
    ; Loop again if [03] is not going down to 0.
    DEC $03
    BNE :Z07Int_LoopShovePixel
    RTS

Z07Int_FluteRoomSecretsOW
            db    $42, $06, $29, $2B, $30, $3A, $3C, $58
            db    $60, $6E, $72

WieldFlute ENT
    ; Play the flute's tune.
    LDA #$10
    STA Tune1Request

    ; Set the flute timer for $98 frames.
    LDA #$98
    STA FluteTimer

    ; In UW, go flag that we used the flute, and return.
    LDA CurLevel
    BNE :Z07Int_FlagFluteUsed

    ; If not in mode 5, return.
    LDA GameMode
    CMP #$05
    BNE :Z07Int_Exit

    ; Get and save the quest number.
    LDY CurSaveSlot
    LDA QuestNumbers, Y
    PHA

    ; Look for the current room in this list of $A that have a flute secret.
    LDA RoomId
    LDY #$0A

:Z07Int_FindSecretRoom
    CMP Z07Int_FluteRoomSecretsOW, Y
    BEQ :Z07Int_Found
    DEY
    BPL :Z07Int_FindSecretRoom
    BMI :Z07Int_FluteSecretNotFound

:Z07Int_Found
    ; Found.
    ;
    ; If it was the first room in the list, handle it specially.
    ; This room is the only one in Q1 with a flute secret. It's also
    ; the only one in the list without a flute secret in Q2.
    ;
    ; In Q2, go summon the whirlwind. In Q1, continue to reveal
    ; the secret.
    CPY #$00
    BNE :Z07Int_Normal
    PLA
    BNE :Z07Int_SummonWhirlwind
    BEQ :Z07Int_RevealSecret

:Z07Int_Normal
    ; For other rooms in the list:
    ; In Q1, go summon the whirlwind.
    ; In Q2, continue to reveal the secret.
    PLA
    BEQ :Z07Int_SummonWhirlwind

:Z07Int_RevealSecret
    ; If the cycle of colors is complete or in progress, then return. The secret is already revealed.
    LDA SecretColorCycle
    BNE :Z07Int_Exit

    ; Look for an empty slot from 9 to 1.
    LDY #$09

:Z07Int_FindEmptySlot
    DEY
    BMI :Z07Int_Exit
    LDA ObjType+1, Y
    BNE :Z07Int_FindEmptySlot

    ; If we find one, set up a flute secret object there.
    ; It will handle the rest.
    LDA #$5E
    STA ObjType+1, Y

:Z07Int_Exit
    RTS

:Z07Int_FluteSecretNotFound
    ; Not found.
    ; Pop and throw away the quest number.
    PLA

:Z07Int_SummonWhirlwind
    ; Summon the whirlwind.
    LDA #$01
    JSR SwitchBank
    JSR SummonWhirlwind
    LDA #$05                    ; Restore the bank at the beginning of the routine.
    JMP SwitchBank

:Z07Int_FlagFluteUsed
    ; Flag that we used the flute.
    LDA UsedFlute
    BNE Z07Int_L1EFCF_Exit
    INC UsedFlute

Z07Int_L1EFCF_Exit
    RTS

Walker_Move ENT
    ; If the object is being shoved, then go shove it.
    LDA ObjShoveDir, X
    BEQ :Z07Int_ChooseObjDirOrInputDir
    JMP Obj_Shove

:Z07Int_ChooseObjDirOrInputDir
    ; Summary: Choose object direction or input direction for movement as appropriate.
    ;
    ; Player: If there's input, then use input direction when grid offset = 0,
    ;         or object direction when <> 0.
    ;
    ; Other objects: Move in input direction, unless stunned or magic clock is active.
    ;
    ; if slot = 0 and grid offset <> 0 then
    ;   if input dir = 0 then
    ;     use 0
    ;   else
    ;     use object direction
    ; else
    ;   if slot <> 0 and (has clock or stunned) then
    ;     return
    ;   else
    ;     if input dir = 0
    ;       use 0
    ;     else
    ;       use input direction
    CPX #$00
    BNE :Z07Int_CheckStunned
    LDA ObjGridOffset
    BEQ :Z07Int_CheckStunned
    LDA ObjInputDir
    BEQ :Z07Int_ZeroMovingDir
    LDA ObjDir
    BNE :Z07Int_SetMovingDir

:Z07Int_CheckStunned
    CPX #$00
    BEQ :Z07Int_FilterInput
    LDA InvClock
    ORA ObjStunTimer, X
    BNE Z07Int_L1EFCF_Exit

:Z07Int_FilterInput
    LDA ObjInputDir, X
    BEQ :Z07Int_ZeroMovingDir
    JSR GetOppositeDir          ; Use this to take only one input direction, in case there are 2 (diagonal).
    LDA ReverseDirections, Y
    BNE :Z07Int_SetMovingDir

:Z07Int_ZeroMovingDir
    LDA #$00

:Z07Int_SetMovingDir
    ; Mask off everything but directions.
    ; (I don't think there's anything else)
    AND #$0F
    STA $0F                     ; [0F] holds the movement direction.

    ; [0E]: $FF, if blocked by a door
    ;       else will hold the reverse index of the direction of a doorway if found
    ; 
    LDA #$00
    STA $0E

    ; If object is Link and using or catching an item then
    ; reset movement direction.
    CPX #$00
    BNE :Z07Int_OnlyLink
    LDA ObjState, X
    AND #$F0
    CMP #$10
    BEQ :Z07Int_Anon0015
    CMP #$20
    BNE :Z07Int_OnlyLink
:Z07Int_Anon0015
    STX $0F                     ; [0F] movement direction

:Z07Int_OnlyLink
    ; If object is not Link, then skip the code below.
    CPX #$00
    BNE :Z07Int_CheckBoundary

    ; Check if tile objects block the player.
    LDA #$01
    JSR SwitchBank
    JSR CheckTileObjectsBlocking

    ; Check whether a person blocks the player.
    LDA ObjType+1
    CMP #$36                    ; Grumble moblin
    BEQ :Z07Int_CheckBlocked
    CMP #$4B                    ; Person1
    BCC :Z07Int_CheckSubroomOrDoorways
    CMP #$53                    ; Person8
    BCS :Z07Int_CheckSubroomOrDoorways

:Z07Int_CheckBlocked
    JSR CheckPersonBlocking

:Z07Int_CheckSubroomOrDoorways
    ; If in a doorway, then go check doorways instead of subrooms.
    LDA DoorwayDir
    BNE :Z07Int_CheckDoorways

    ; Check subrooms (caves and cellars) in modes 9, $B, $C.
    LDA GameMode
    CMP #$09
    BEQ :Z07Int_InSubroom
    CMP #$0B
    BEQ :Z07Int_InSubroom
    CMP #$0C
    BNE :Z07Int_SkipSubroom

:Z07Int_InSubroom
    LDA #$05
    JSR SwitchBank
    JSR CheckSubroom

    ; If game mode = 9, or in OW, or in a doorway, then skip
    ; checking room boundaries.
    LDA GameMode
    CMP #$09
    BEQ :Z07Int_CheckDoorways

:Z07Int_SkipSubroom
    LDA CurLevel
    BEQ :Z07Int_CheckDoorways
    LDA DoorwayDir
    BNE :Z07Int_CheckDoorways

:Z07Int_CheckBoundary
    ; This code applies to all objects.
    ;
    ; Prevents movement outside the walls or border of a room,
    ; even Link in front of a doorway.
    JSR BoundByRoom

:Z07Int_CheckDoorways
    ; If object is Link, and level is in UW, and mode <> 9,
    ; then check doorways.
    CPX #$00
    BNE :Z07Int_CheckTiles
    LDA CurLevel
    BEQ :Z07Int_CheckTiles
    LDA GameMode
    CMP #$09
    BEQ :Z07Int_CheckTiles
    LDA #$05
    JSR SwitchBank
    JSR CheckDoorway
    LDX #$00                    ; Restore Link's object index.

:Z07Int_CheckTiles
    ; This code applies to all objects.
    JSR Z07Int_Walker_CheckTileCollision

    ; The player will check for the ladder.
    CPX #$00
    BNE MoveObject
    LDA #$05
    JSR SwitchBank
    JSR CheckLadder             ; CheckLadder

; Params:
; X: object index
; [0F]: direction
;
MoveObject ENT
    LDA #$08                    ; Positive limit is 8 for Link.
    LDY #$F8                    ; Negative limit is -8 for Link.
    CPX #$00
    BEQ :Z07Int_Anon0016                      ; If the object isn't Link,
    LDA #$10                    ; then use $10 and -$10.
    LDY #$F0
:Z07Int_Anon0016
    STA PositiveGridCellSize    ; Store the limits that we determined.
    STY NegativeGridCellSize
    LDA $0F
    BEQ :Z07Int_Exit                   ; If direction is none, then return.

    ; To allow a wide speed range, we keep the quarter speed.
    ; Here, apply it 4 times to get the full speed.
    JSR :Z07Int_ApplyQSpeedToPosition
    JSR :Z07Int_ApplyQSpeedToPosition
    JSR :Z07Int_ApplyQSpeedToPosition

:Z07Int_ApplyQSpeedToPosition
    LDA $0F                     ; Check the direction variable for each direction bit.
    LSR
    BCS :Z07Int_Right
    LSR
    BCS :Z07Int_Left
    LSR
    BCS :Z07Int_Down

    ; Up
    JSR SubQSpeedFromPositionFraction
    LDA ObjY, X
    SBC #$00
    STA ObjY, X

:Z07Int_Exit
    RTS

:Z07Int_Down
    ; Down
    JSR AddQSpeedToPositionFraction
    LDA ObjY, X
    ADC #$00
    STA ObjY, X
    RTS

:Z07Int_Right
    ; Right
    JSR AddQSpeedToPositionFraction
    LDA ObjX, X
    ADC #$00
    STA ObjX, X
    RTS

:Z07Int_Left
    ; Left
    JSR SubQSpeedFromPositionFraction
    LDA ObjX, X
    SBC #$00
    STA ObjX, X
    RTS

; Up, down, left, right.
;
Z07Int_PlayerScreenEdgeBounds
            db    $3D, $DD, $00, $F0

; Params:
; [0E]: $FF, if blocked by a door
; [0F]: movement direction
;
; Returns:
; [0F]: untouched, or changed if blocked or need to change
;
; Summary:
;
; For the player: if at a doorway or walkable tile, check the screen edge.
; Then allow movement or go to the next room. Otherwise,
; check passive tile objects and stop moving.
;
; For other objects: First, if moving, test the colliding tile for
; walkability. Otherwise search for a walkable direction starting
; from input direction.
;
; When you find a walkable direction, see if it makes the object
; cross a boundary. If it doesn't, then make this direction
; the objection direction. Otherwise, keep looping.
;
; If no walkable direction is found, then stop moving.
;
Z07Int_Walker_CheckTileCollision
    ; if is player
    ;   if at doorway
    ;     go handle a walkable direction
    ;   if blocked by door
    ;     return
    CPX #$00
    BNE :Z07Int_CheckGridOffset
    LDA DoorwayDir
    BEQ :Z07Int_Anon0017
    JMP Z07Int_GoWalkableDir
:Z07Int_Anon0017
    LDA $0E
    BMI Z07Int_L1F148_Exit

:Z07Int_CheckGridOffset
    ; If grid offset <> 0, return.
    LDA ObjGridOffset, X
    BNE Z07Int_L1F148_Exit

    ; Grid offset = 0.
    ; The object is at a point between cells in the grid.
    ; So, we can check tiles for collision.
    ;
    ; Reset [0E] alternate direction search step.
    STA $0E

    ; If there's a movement direction, go check tile collision.
    LDA $0F
    BNE Z07Int_CheckTiles

    ; Moving direction = 0.
    ; If object is the player, return.
    CPX #$00
    BEQ Z07Int_L1F148_Exit

    ; Moving direction = 0.
    ; The object is not the player.
    ;
    ; If object does not have attribute $10, then
    ; set movement direction to input direction,
    ; and go try to turn to an unblocked direction in order to move.
    LDA ObjAttr, X
    AND #$10                    ; "Z07Int_Reverse when blocked" object attribute
    BNE Z07Int_Reverse
    LDA ObjInputDir, X
    STA $0F
    JMP Z07Int_TryNextDir

Z07Int_Reverse
    ; UNKNOWN:
    ; This seems to be unused code triggered by object attribute $10.
    ; But $10 is not used in the object attribute array at 07:FAEF.
    ; Begin unverified code 1F110
    JSR ReverseObjDir
    JMP Z07Int_CheckBoundary
    ; End unverified code

Z07Int_CheckTiles
    ; The code below applies to Link and other objects.
    ;
    ; Test the moving direction's walkability.
    ;
    ; For the player, this is enough. For other objects, this 
    ; becomes a loop looking for an unblocked direction to move in.
    ;
    ; If the colliding tile is walkable, go handle a walkable direction.
    JSR GetCollidingTileMoving
    CMP ObjectFirstUnwalkableTile
    BCC Z07Int_GoWalkableDir

    ; The colliding tile is unwalkable.
    ;
    ; If object is the player, then go check passive tile objects and
    ; the screen edge, or stop moving.
    CPX #$00
    BEQ Z07Int_PlayerUnwalkable

Z07Int_CheckObjAttr10AndAltDir
    ; Not the player.
    ; If object attribute has $10, go to the unused code above
    ; to reverse direction.
    LDA ObjAttr, X
    AND #$10
    BNE Z07Int_Reverse

Z07Int_TryNextDir
    ; Get the next direction to check, and set moving direction to it.
    ; If not at the end of the loop, go test the new direction's walkability.
    JSR Z07Int_Walker_GetNextAltDir
    STA $0F                     ; Set new moving direction, or 0 at the end of the loop.
    LDA $0E
    BNE Z07Int_CheckTiles
    RTS

Z07Int_PlayerUnwalkable
    ; Tile is not walkable. Object is player.
    ;
    ; Check passive tile objects and the screen edge, and stop moving.
    ;
    ; First, if in OW, check passive tile objects (armos and regular gravestone).
    LDA CurLevel
    BNE :Z07Int_StopMoving
    LDA #$01
    JSR SwitchBank
    JSR CheckPassiveTileObjects

:Z07Int_StopMoving
    ; Reset moving direction and buttons pressed.
    ; If in UW, we're done.
    ; In OW, go check the screen edge.
    JSR ResetMovingDir
    STA ButtonsPressed
    LDA CurLevel
    BEQ Z07Int_GoWalkableDir

Z07Int_L1F148_Exit
    RTS

; Returns:
; A: 0
; [0F]: 0
;
ResetMovingDir ENT
    LDA #$00
    STA $0F
    RTS

Z07Int_GoWalkableDir
    ; If object is not Link, then the tile is walkable. Go see if this direction
    ; makes the object cross a boundary. Then go check another direction if it does,
    ; or else make this the object direction.
    CPX #$00
    BNE Z07Int_CheckBoundary

    ; The object is Link. We end up here regardless of walkability.
    ;
    ; If not in mode 5 or ladder is in use, return.
    LDA GameMode
    CMP #$05
    BNE Z07Int_ExitX0
    LDA LadderSlot
    BNE Z07Int_L1F148_Exit

    ; If grid offset <> 0, return.
    LDA ObjGridOffset
    BNE Z07Int_ExitX0

CheckScreenEdge ENT
    LDX ObjY

    ; If not moving, then return.
    LDA ObjInputDir
    BEQ Z07Int_ExitX0

    ; If the single moving direction is vertical, use Y.
    ; Else use X coordinate.
    JSR GetOppositeDir          ; Call this to get a single moving direction.
    LDA ReverseDirections, Y
    AND #$0C
    BNE :Z07Int_Anon0018
    LDX ObjX
:Z07Int_Anon0018
    STX $00

    ; If Link's coordinate does not match the screen edge coordinate
    ; in the single moving direction, then return.
    LDA $00
    CMP Z07Int_PlayerScreenEdgeBounds, Y
    BNE Z07Int_ExitX0

    ; We're moving to the next screen.
    ; Make sure Link faces the single moving direction.
    LDA ReverseDirections, Y
    STA ObjDir

; Returns:
; X: 0 (Link's object slot)
;
GoToNextModeFromPlay ENT
    INC GameMode
    LDA #$00
    STA GameSubmode
    STA IsUpdatingMode
    STA $0F
    STA ObjState
    STA ObjShoveDir
    STA ObjShoveDistance
    STA ObjInvincibilityTimer

Z07Int_ExitX0
    LDX #$00
    RTS

Z07Int_CheckBoundary
    ; If object crossed a boundary, then go check object
    ; attribute $10 and another direction.
    ; Else set object direction to moving direction [0F] and return.
    JSR BoundByRoom
    BEQ Z07Int_CheckObjAttr10AndAltDir
    STA ObjDir, X
    RTS

; Description:
; Calculates the next alternate direction to move in while
; searching for an unblocked direction.
;
; Params:
; [0E]: the current step
;
; Returns:
; A: a direction for the current step, or 0 at the end of the loop
; [0E]: the next step, or 0 to end the loop
; ObjDir: might be modified
;
Z07Int_Walker_GetNextAltDir
    LDA $0E
    INC $0E
    JSR TableJump

Z07Int_Walker_GetNextAltDir_JumpTable
            dw    Z07Int_Walker_AltDir_GetRandomObjPerpendicularDir
            dw    Z07Int_Walker_AltDir_GetMovingOppositeDir
            dw    ReverseObjDir
            dw    Z07Int_Walker_AltDir_EndLoop

Z07Int_Walker_AltDir_GetRandomObjPerpendicularDir
    LDY #$00
    LDA Random, X
    ASL
    BCS :Z07Int_Anon0019
    INY
:Z07Int_Anon0019
    LDA ObjDir, X
    AND #$0C
    BEQ :Z07Int_Anon0020
    INY
    INY
:Z07Int_Anon0020
    LDA ReverseDirections, Y
    RTS

Z07Int_Walker_AltDir_GetMovingOppositeDir
    LDA $0F
    PHA
    AND #$0A
    BEQ :Z07Int_IncreasingDir
    PLA
    LSR
    RTS

:Z07Int_IncreasingDir
    PLA
    ASL
    RTS

ReverseObjDir ENT
    ; Note:
    ; Also reverses movement direction in [0F].
    LDA ObjDir, X
    JSR GetOppositeDir
    STA ObjDir, X
    STA $0F
    RTS

Z07Int_Walker_AltDir_EndLoop
    LDA #$00
    STA $0E
    RTS

; Description:
; Search for an unblocked direction. Set facing direction to it,
; if one is found.
;
; If not at a square boundary, then return.
;
_FaceUnblockedDir ENT
    LDA ObjGridOffset, X
    BNE Z07Int_L1F1FC_Exit

    ; Else reset [0E] to start the search for an unblocked direction.
    STA $0E

:Z07Int_LoopSearchStep
    JSR Z07Int_Walker_GetNextAltDir

    ; Set the moving direction [0F] to the direction returned.
    STA $0F

    ; But quit if none was found.
    BEQ Z07Int_L1F1FC_Exit

    ; If blocked in this direction by a tile or the room boundary,
    ; then loop again.
    JSR GetCollidingTileMoving
    CMP ObjectFirstUnwalkableTile
    BCS :Z07Int_LoopSearchStep
    JSR BoundByRoom
    BEQ :Z07Int_LoopSearchStep

    ; Set the facing direction to the one found.
    STA ObjDir, X

Z07Int_L1F1FC_Exit
    RTS

Z07Int_LinkToLadderOffsetsX
            db    $00, $00, $F0, $10

Z07Int_LinkToLadderOffsetsY
            db    $FB, $13, $03, $03

Z07Int_LinkHeadTiles
            db    $02, $06, $08, $0A

Z07Int_LinkHeadMagicShieldTiles
            db    $80, $54, $60, $60

Z07Int_LadderRoomsOW
            db    $17, $18, $19, $27, $4F, $5F

Link_EndMoveAndAnimate_Bank4 ENT
    JSR Link_EndMoveAndAnimate
    LDA #$04
    JMP SwitchBank

Link_EndMoveAndDraw_Bank1 ENT
    JSR Link_EndMoveAndDraw
:Z07Int_Anon0021
    LDA #$01
    JMP SwitchBank

Link_EndMoveAndAnimate_Bank1 ENT
    JSR Link_EndMoveAndAnimate
    JMP :Z07Int_Anon0021

Link_EndMoveAndDraw_Bank4 ENT
    JSR Link_EndMoveAndDraw
    LDA #$04
    JMP SwitchBank

; Description:
; Draw Link without animating by keeping the animation counter fixed.
;
Link_EndMoveAndDraw ENT
    LDA #$06
    STA ObjAnimCounter
    BNE Link_EndMoveAndAnimate

Link_EndMoveAndAnimateBetweenRooms ENT
    LDA CurLevel
    BNE Z07Int_L1F1FC_Exit             ; If in UW, then return.

Link_EndMoveAndAnimate ENT
    ; Switches bank: 5
    ;
    ; If teleporting by whirlwind, then return.
    LDA WhirlwindTeleportingState
    BNE Z07Int_L1F1FC_Exit

    ; If mode 4 or 6 (not a playing mode), then go check warps and animate.
    TAX
    LDA GameMode
    CMP #$06
    BEQ :Z07Int_CheckWarpsAndAnimate
    CMP #$05
    BCC :Z07Int_CheckWarpsAndAnimate

    ; If Link's grid offset = 0, go see whether we need to wield the ladder.
    ; If Link's grid offset is not a multiple of 8, go check warps and animate.
    LDA ObjGridOffset
    BEQ :Z07Int_CheckLadderRoom
    AND #$07
    BEQ :Z07Int_TruncGridOffset

:Z07Int_CheckWarpsAndAnimate
    JMP :Z07Int_CheckWarps

:Z07Int_TruncGridOffset
    ; Grid offset is a multiple of 8. So set it to 0.
    ; If not in mode 5, go check warps and animate.
    LDA #$00
    STA ObjGridOffset
    LDY GameMode
    CPY #$05
    BNE :Z07Int_CheckWarpsAndAnimate

    ; Grid offset was a multiple of 8. So, we've stepped a whole tile,
    ; and need to reset the subroom indicator.
    ;
    ; That way, we know not to go into a subroom that we just came out of.
    STA UndergroundExitType

:Z07Int_CheckLadderRoom
    ; If not in mode 5, go check warps and animate.
    LDA GameMode
    CMP #$05
    BNE :Z07Int_CheckWarpsAndAnimate

    ; If in OW and we're not in this list of 6 rooms, go check warps and animate.
    LDA CurLevel
    BNE :Z07Int_CheckLadder
    LDA RoomId
    LDY #$05

:Z07Int_LoopLadderRoom
    CMP Z07Int_LadderRoomsOW, Y
    BEQ :Z07Int_CheckLadder
    DEY
    BPL :Z07Int_LoopLadderRoom
    BMI :Z07Int_CheckWarps

:Z07Int_CheckLadder
    ; If in a doorway or missing the ladder, go check warps and animate.
    LDA DoorwayDir
    BNE :Z07Int_CheckWarps
    LDA InvLadder
    BEQ :Z07Int_CheckWarps

    ; If Link is halted or using the ladder, go check warps and animate.
    LDA ObjState
    AND #$C0
    CMP #$40
    BEQ :Z07Int_CheckWarps
    LDA LadderSlot
    BNE :Z07Int_CheckWarps

    ; Get the colliding tile in moving direction.
    LDX #$00
    LDA ObjDir
    STA $0F
    JSR GetCollidingTileMoving

    ; If in OW and tile is not water (as in < $8D or >= $99), then
    ; go check warps and animate.
    ; If in UW, and tile <> $F4, go check warps and animate.
    LDY CurLevel
    BEQ :Z07Int_CheckWaterOW
    CMP #$F4
    BEQ :Z07Int_SetUpLadder
    BNE :Z07Int_CheckWarps

:Z07Int_CheckWaterOW
    CMP #$8D
    BCC :Z07Int_CheckWarps
    CMP #$99
    BCS :Z07Int_CheckWarps

:Z07Int_SetUpLadder
    ; Look for an empty monster slot.
    ; If none found, or input dir = 0, or input direction <> facing direction,
    ; then go check warps and animate.
    JSR FindEmptyMonsterSlot
    BEQ :Z07Int_CheckWarps
    LDA ObjInputDir
    BEQ :Z07Int_CheckWarps
    LDX EmptyMonsterSlot
    CMP ObjDir
    BNE :Z07Int_CheckWarps

    ; X register now holds the ladder's slot.
    ; Set ladder slot to empty slot found.
    ; Set ladder's direction to input direction.
    STX LadderSlot
    STA ObjDir, X

    ; Add appropriate offset to player's position to set the ladder's position.
    JSR GetOppositeDir          ; Call this for the reverse direction index.
    LDA ObjX
    CLC
    ADC Z07Int_LinkToLadderOffsetsX, Y
    STA ObjX, X
    LDA ObjY
    CLC
    ADC Z07Int_LinkToLadderOffsetsY, Y
    STA ObjY, X

    ; Set the ladder object's type. Reset shove params and invincibility timer.
    LDA #$5F                    ; Ladder
    STA ObjType, X
    JSR ResetShoveInfo
    STA ObjInvincibilityTimer, X

    ; Set the initial state of the ladder.
    LDA #$01
    STA ObjState, X

:Z07Int_CheckWarps
    ; If in mode 5, check warps.
    LDX #$00                    ; Set X to 0 to refer to Link object.
    LDA GameMode
    CMP #$05
    BNE :Z07Int_Animate
    LDA ObjCollidedTile         ; Save the last collided tile.
    PHA
    LDA #$05
    JSR SwitchBank
    JSR CheckWarps
    LDX #$00                    ; Set X to 0 to refer to Link object.
    PLA
    STA ObjCollidedTile         ; Restore the last collided tile.

:Z07Int_Animate
    ; Animate Link.
    JSR Z07Int_AnimateLinkBase
    LDA GameMode
    CMP #$09
    BEQ :Z07Int_ShiftDown2Pixels       ; If in mode 9, go draw Link 2 pixels down.
    LDA CurLevel                ; In OW, draw Link 2 pixels down.
    BNE :Z07Int_ChangeLookForState

:Z07Int_ShiftDown2Pixels
    INC $01
    INC $01

:Z07Int_ChangeLookForState
    ; Now change Link's look for specific states and items.
    ;
    ; If Link is attacking or using an item,
    ; then add 4 to frame to use the "attack/use item" frames.
    LDA ObjState
    AND #$30
    CMP #$10
    BEQ :Z07Int_WieldingObject
    CMP #$20
    BNE :Z07Int_Draw

:Z07Int_WieldingObject
    TYA
    CLC
    ADC #$04
    TAY

:Z07Int_Draw
    TYA                         ; Now frame is in A.
    LDY #$00                    ; Use Link's animation.
    JSR DrawObjectWithAnim

    ; See if there's special processing needed for the shield.
    LDA InvMagicShield
    BNE :Z07Int_HandleMagicShield

    ; No magic shield.
    LDA ObjDir
    CMP #$04
    BNE Z07Int_L1F36A_Exit             ; If not facing down, then return.
    LDX #$01                    ; Get the sprite's tile.
    LDA Sprites+72, X
    CMP #$0B                    ; The tiles for shieldless Link are 8 and $A.
    BCS Z07Int_L1F36A_Exit             ; If it already has a shield, then return.
    PHA                         ; Save the sprite's original tile.
    CLC
    ADC #$50                    ; Add $50 to change 8 to $58 for one frame, and $A to $5A for the other frame.
    JMP :Z07Int_ApplyShieldSprite      ; Go apply the change.

:Z07Int_HandleMagicShield
    ; Magic shield.
    LDX #$01                    ; Look at the left tile.
    LDA ObjDir
    LSR
    BCC :Z07Int_Anon0022                      ; If facing right,
    LDX #$05                    ; then look at the right tile instead.
:Z07Int_Anon0022
    LDY #$04
    LDA Sprites+72, X           ; Get the sprite's tile.
    PHA                         ; Save the sprite's original tile.

:Z07Int_LoopHeadTile
    ; Compare the sprite's tile with 4 tiles: 1 for each direction.
    DEY
    BMI :Z07Int_FixHFlip               ; Quit the loop if we haven't found it.
    CMP Z07Int_LinkHeadTiles, Y
    BNE :Z07Int_LoopHeadTile           ; If it didn't match, go check the next one.
    LDA Z07Int_LinkHeadMagicShieldTiles, Y    ; Get the replacement tile.

:Z07Int_ApplyShieldSprite
    ; Apply the sprite's modification for the shield.
    STA Sprites+72, X

:Z07Int_FixHFlip
    PLA                         ; Restore the sprite's original tile to A.
    CMP #$0A
    BNE Z07Int_L1F36A_Exit             ; If it's not a down facing tile, then return. No attributes to change.

    ; It's a down facing tile. Make sure it's not flipped,
    ; because there's only 1 frame of downward shield tile.
    LDA Sprites+73, X
    AND #$0F
    STA Sprites+73, X

Z07Int_L1F36A_Exit
    RTS

; Sprite attributes that flip each corner of the spread shot
; differently: H, H-V, V, 0
;
Z07Int_SwordShotSpreadBaseAttr
            db    $40, $C0, $80, $00

Z07Int_UpdateSwordShotOrMagicShot
    ; If the shot is not active, return.
    LDA ObjState, X
    BEQ Z07Int_L1F36A_Exit

    ; If low bit is set, go handle shot spreading out.
    LSR
    BCC :Z07Int_Anon0023
    JMP Z07Int_SpreadShot
:Z07Int_Anon0023
    ; Move the shot.
    LDA ObjGridOffset, X
    BNE :Z07Int_Anon0024
:Z07Int_Anon0024
    LDA ObjDir, X
    JSR MoveShot

    ; If movement was blocked, go handle the situation.
    LDA $0F
    BEQ HandleShotBlocked

    ; If grid offset is a multiple of 8, reset it.
    LDA ObjGridOffset, X
    AND #$07
    BNE DrawSwordShotOrMagicShot
    STA ObjGridOffset, X

DrawSwordShotOrMagicShot ENT
    ; Prepare the sprite position.
    JSR Anim_FetchObjPosForSpriteDescriptor

    ; If the direction is horizontal, move the sprites down 3 pixels.
    LDA ObjDir, X
    PHA
    AND #$03
    BEQ :Z07Int_Flash
    LDA $01
    CLC
    ADC #$03
    STA $01

:Z07Int_Flash
    PLA

    ; Set the sprite attributes to (base attribute OR (frame counter AND 3)).
    ; This makes the shot flash by cycling all the palettes, one each frame.
    JSR GetOppositeDir          ; Call this only to get reverse direction index.
    LDA FrameCounter
    AND #$03
    ORA Z07Int_RDirectionToWeaponBaseAttribute, Y
    JSR Anim_SetSpriteDescriptorAttributes

    ; Set [0C] to the correct frame for the direction: horizontal or vertical.
    LDA Z07Int_RDirectionToWeaponFrame, Y
    STA $0C

    ; If the direction is left, flip the right facing image by setting [0F] to 1.
    CPY #$02
    BNE :Z07Int_Anon0025
    INC $0F
:Z07Int_Anon0025
    ; If this a monster's shot, choose the item slot for drawing based on object type.
    ;   $57 (sword shot) => $22
    ;   other (presumably $58 or $59, magic shot) => $23
    LDY #$22
    CPX #$0D
    BCS :Z07Int_PlayerShot
    LDA ObjType, X
    CMP #$57
    BEQ :Z07Int_WriteSprites
    BNE :Z07Int_WriteMagicSprites

:Z07Int_PlayerShot
    ; But if the player shot it, the choice depends on the shot's state.
    ;   high bit set (magic)   => $23
    ;   high bit clear (sword) => $22
    LDA ObjState, X
    ASL
    BCC :Z07Int_WriteSprites

:Z07Int_WriteMagicSprites
    LDY #$23

:Z07Int_WriteSprites
    JMP Anim_WriteItemSprites

; Params:
; X: shot object index
;
; If the object is a sword shot, go spread out the shot.
;
HandleShotBlocked ENT
    LDA ObjState, X
    ASL
    BCC Z07Int_SetShotSpreadingState

    ; This is a magic shot.
    ;
    ; If missing the magic book, go deactivate the shot object.
    LDA InvBook
    BEQ Z07Int_DeactivateShot

    ; Try to activate a fire object. Temporarily mark the candle
    ; unused, so it only has to depend on having an empty slot.
    ;
    ; If successful, Link's state will have been changed to "using item".
    ; But we don't want that in this case.
    ;
    ; For both these reasons, save state and restore it afterward.
    LDA ObjState
    PHA
    LDA UsedCandle
    PHA
    LDA #$00
    STA UsedCandle
    JSR WieldCandle
    PLA
    STA UsedCandle
    PLA
    STA ObjState

    ; State $21 means that a moving fire was just made.
    ;
    ; If it's any another value, then we didn't find an empty slot
    ; to make a fire. In this case, all that's left to do is to go
    ; deactivate the shot object.
    LDA ObjState, X
    CMP #$21
    BNE Z07Int_DeactivateLinkShot

    ; Make state $22 for a standing fire.
    INC ObjState, X

    ; Copy the shot's position and direction to the fire.
    LDY #$0E
            JSR   LDA_ObjX_Y
    STA ObjX, X
            JSR   LDA_ObjY_Y
    STA ObjY, X
            JSR   LDA_ObjDir_Y
    STA ObjDir, X

    ; The fire lasts $4F frames.
    ; Deactivate the shot.
    LDA #$4F
    STA ObjTimer, X

Z07Int_DeactivateLinkShot
    LDX #$0E

Z07Int_DeactivateShot
    JMP ResetObjState

Z07Int_SetShotSpreadingState
    ; MULTI: ObjDir -> ObjSwordShotNegativeOffset
    ;
    ; Set the state to spreading out (low bit is set).
    ;
    ; Set [98][X] to base negative offset -2. This is how far the left
    ; corners will be shown relative to the center point at object X, Y.
    ; The right corners will be shown 2 pixels in the opposite direction
    ; of the center point.
    INC ObjState, X
    LDA #$FE
    STA ObjDir, X
    RTS

Z07Int_SpreadShot
    ; MULTI: ObjDir -> ObjSwordShotNegativeOffset
    ;
    ; The shot is spreading out.
    ;
    ; Copy base negative offset in [98][X] to [02] and [03].
    ; These will be negated appropriately for each corner.
    LDA ObjDir, X
    STA $02
    STA $03

    ; Reset [0F] to not flip horizontally.
    LDA #$00
    STA $0F

    ; Loop 4 times to draw each corner of the spreading sword shot.
    ; The corners are: top-left, bottom-left, bottom-right, top-right
    LDY #$03

:Z07Int_DrawShotCorner
    TYA                         ; Save the loop index.
    PHA

    ; Save offset X [02] and Y offset [03].
    LDA $02
    PHA
    LDA $03
    PHA

    ; Calculate and set sprite attributes for this corner:
    ;   base attribute OR (frame counter AND 3)
    ;
    ; The base attribute defines how to flip the sprite.
    ; The frame counter makes the shot flash by cycling each
    ; palette row.
    LDA FrameCounter
    AND #$03
    ORA Z07Int_SwordShotSpreadBaseAttr, Y
    JSR Anim_SetSpriteDescriptorAttributes

    ; Add the object's X (the center of the spread) and the
    ; current offset in [02] to set sprite X in [00].
    LDA ObjX, X
    CLC
    ADC $02
    STA $00

    ; If sprite X >= object X and sprite X >= $FC, skip this corner.
    ; Else calculate the distance from object X to sprite X.
    CMP ObjX, X
    BCC :Z07Int_ReverseSub
    CMP #$FC
    BCS :Z07Int_NextCorner
    SEC
    SBC ObjX, X
    JMP :Z07Int_CheckDistance

:Z07Int_ReverseSub
    LDA ObjX, X
    SEC
    SBC $00

:Z07Int_CheckDistance
    ; If distance >= $20, skip this corner.
    CMP #$20
    BCS :Z07Int_NextCorner

    ; Add the object's Y (the center of the spread) and the
    ; current offset in [03] to set sprite Y in [01].
    LDA ObjY, X
    CLC
    ADC $03
    STA $01

    ; If in UW, and (sprite Y < $3E or >= $E8), then skip this corner.
    LDY CurLevel
    BEQ :Z07Int_Draw
    CMP #$3E
    BCC :Z07Int_NextCorner
    CMP #$E8
    BCS :Z07Int_NextCorner

:Z07Int_Draw
    ; Draw the corner.
    ; Pass [0C] = frame 2 (spread shot), Y = $23 (sword 2).
    LDA #$02
    STA $0C
    LDY #$23
    JSR Anim_WriteItemSprites

:Z07Int_NextCorner
    ; Prepare to process the next corner.
    ;
    ; First, restore X offset [02] and Y offset [03].
    PLA
    STA $03
    PLA
    STA $02

    ; Take turns negating X offset or Y offset for the next round.
    ; - First turn:  loop index = 3, negate Y offset [03]
    ; - Second turn: loop index = 2, negate X offset [02]
    ; - Third turn:  loop index = 1, negate Y offset [03]
    ; - Fourth turn: doesn't matter
    PLA                         ; Get the loop index.
    PHA
    TAY
    CPY #$01                    ; The first two loop indexes coincide with offset from address 0.
    BNE :Z07Int_Anon0026                      ; But for loop index 1,
    LDY #$03                    ; make the offset 3 to negate the Y offset.
:Z07Int_Anon0026
;    LDA $0000, Y
    jsr  LDA_0000_Y
    EOR #$FF
    CLC
    ADC #$01
;    STA $0000, Y
    jsr  STA_0000_Y

    ; Restore the loop index, decrement it, and loop again if >= 0.
    PLA
    TAY
    DEY
    BPL :Z07Int_DrawShotCorner

    ; MULTI: ObjDir -> ObjSwordShotNegativeOffset
    ;
    ; Decrease the base negative offset to get farther away from
    ; the center point.
    DEC ObjDir, X

    ; MULTI: ObjDir -> ObjSwordShotNegativeOffset
    ;
    ; Once the base negative offset reaches $E8, go deactivate the object.
    LDA ObjDir, X
    CMP #$E8
    BNE Z07Int_L1F49F_Exit
    JMP Z07Int_DeactivateLinkShot

Z07Int_L1F49F_Exit
    RTS

Z07Int_UpdateBoomerangOrFood
    ; If state = 0, then not active. So, return.
    LDA ObjState, X
    BEQ Z07Int_L1F49F_Exit

    ; If the high bit of state is clear, then go update the boomerang.
    ASL
    BCC UpdateArrowOrBoomerang

    ; The object is food.
    ;
    ; Once the timer has expired, increment the state and set timer to $FF.
    ; If we reach state $83, then go deactivate the object.
    ;
    ; Nothing changes between the states. So, they are used as
    ; a way to extend the timer. $2FD screen frames in total.
    LDA ObjTimer, X
    BNE :Z07Int_CheckMonsterType
    INC ObjState, X
    LDA ObjState, X
    AND #$0F
    CMP #$03
    BEQ :Z07Int_Deactivate
    LDA #$FF
    STA ObjTimer, X

:Z07Int_CheckMonsterType
    ; If the template object type in the room is one of:
    ; moblin, goriya, octorock, vire, keese
    ; then attract these monsters to the food.
    ;
    ; They will chase the food instead of Link when given a chance.
    LDA RoomObjTemplateType
    CMP #$03                    ; Blue moblin
    BCC :Z07Int_Draw
    CMP #$0B                    ; Red darknut
    BCC :Z07Int_AttractMonsters
    CMP #$12                    ; Vire
    BEQ :Z07Int_AttractMonsters
    CMP #$1B                    ; Blue keese
    BEQ :Z07Int_AttractMonsters
    CMP #$1C                    ; Red keese
    BNE :Z07Int_Draw

:Z07Int_AttractMonsters
    LDA ObjX, X
    STA ChaseTargetX
    LDA ObjY, X
    STA ChaseTargetY

:Z07Int_Draw
    ; Draw the food.
    JSR Anim_FetchObjPosForSpriteDescriptor
    LDA #$02                    ; Red sprite palette
    LDY #$06                    ; Food item slot
    JMP Anim_WriteStaticItemSpritesWithAttributes

:Z07Int_Deactivate
    JMP ResetObjState

Z07Int_BoomerangFrameCycle
            db    $00, $01, $02, $01, $00, $01, $02, $01
            db    $03

Z07Int_BoomerangBaseSpriteAttrCycle
            db    $00, $00, $00, $40, $40, $C0, $80, $80
            db    $01

Z07Int_BoomerangQSpeedFracsY
            db    $00, $20, $36, $4C, $60, $68, $70, $78
            db    $80

Z07Int_BoomerangQSpeedFracsX
            db    $80, $78, $70, $68, $60, $4C, $36, $20
            db    $00

Z07Int_RDirectionToWeaponFrame
            db    $00, $00, $01, $01

; The base sprite attribute for weapon sprites, 1 for each
; direction in reverse direction order: up, down, left, right
;
; All of them are 0, except for the element for "down".
; That one flips the vertical sword or rod image so that it points down.
;
Z07Int_RDirectionToWeaponBaseAttribute
            db    $00, $80, $00, $00

Z07Int_RDirectionToOffsetsX
            db    $FC, $FC, $00, $00

Z07Int_RDirectionToOffsetsY
            db    $00, $00, $03, $03

UpdateArrowOrBoomerang ENT
    ; If not active (state = 0), then return.
    LDA ObjState, X
    BEQ Z07Int_L1F49F_Exit

    ; Reset [00], which will hold the number of axes where the distance <= 8
    ; when calculating the angle to return to thrower.
    ; See states $40 and $50 and GetDirectionsAndDistancesToTarget.
    LDA #$00
    STA $00

    ; If not in major state $10, go check other states.
    LDA ObjState, X
    AND #$F0
    CMP #$10
    BEQ :Z07Int_State10
    JMP Z07Int_CheckState20

:Z07Int_State10
    ; State $1x. Fly away from the thrower.
    ;
    ; Reset [0E], which will indicate:
    ; - into MoveShot:   0 update grid offset, else don't
    ; - out of MoveShot: $80 if blocked
    LDA #$00
    STA $0E

    ; If the object's direction has a horizontal component, then
    ; move it horizontally.
    LDA ObjDir, X
    AND #$03
    BEQ :Z07Int_Anon0027
    JSR MoveShot
    INC $0E                     ; If MoveShot were called again, then don't update grid offset.
:Z07Int_Anon0027
    ; If the object was blocked, go handle it.
    LDA $0E
    ASL
    BCS :Z07Int_HandleBlocked

    ; If the object's direction has a vertical component, then
    ; move it vertically.
    LDA ObjDir, X
    AND #$0C
    BEQ :Z07Int_Anon0028
    JSR MoveShot
:Z07Int_Anon0028
    ; If the object was blocked, go handle it.
    LDA $0E
    ASL
    BCS :Z07Int_HandleBlocked

    ; If the object is an arrow (Link's or a monster's), go set up sprite parameters.
    CPX #$0D
    BCS :Z07Int_CheckPlayerArrow
    LDA ObjType, X
    CMP #$5B
    BEQ DrawArrow

:Z07Int_CheckPlayerArrow
    CPX #$12
    BEQ DrawArrow

    ; For boomerangs, get the absolute value of the weapon's grid offset:
    ; the distance traveled.
    LDA ObjGridOffset, X
    BPL :Z07Int_CompareLimit
    EOR #$FF
    CLC
    ADC #$01

:Z07Int_CompareLimit
    ; For boomerangs, compare it to the movement limit.
    ; If it reached the limit, set state $20 and a new movement
    ; limit of $10, and go handle the rest as if blocked.
    ; State $20 will become $30 below in Z07Int_HandleArrowOrBoomerangBlocked.
    ;
    ; Otherwise, only animate and check collision as usual.
    ;
    ; In major state $30, ObjMovingLimit is a timer to change the state to $40.
    CMP ObjMovingLimit, X
    BCC :Z07Int_AnimateBoomerang
    LDA #$10
    STA ObjMovingLimit, X
    LDA #$20
    STA ObjState, X

:Z07Int_HandleBlocked
    JMP Z07Int_HandleArrowOrBoomerangBlocked

:Z07Int_AnimateBoomerang
    JMP Z07Int_AnimateBoomerangAndCheckCollision

DrawArrow ENT
    ; This is an arrow. Set up sprite parameters.
    ;
    ; If facing left, set horizontal flipping in [0F].
    LDA #$00
    STA $0F
    LDA ObjDir, X
    CMP #$02
    BNE :Z07Int_Anon0029
    INC $0F
:Z07Int_Anon0029
    JSR GetOppositeDir          ; Get the reverse direction index that the weapon is facing.

    ; Store the weapon's frame (up or right) in [0C].
    LDA Z07Int_RDirectionToWeaponFrame, Y
    STA $0C

    ; Store the base sprite attribute in [04].
    LDA Z07Int_RDirectionToWeaponBaseAttribute, Y

Z07Int_SetAttrAndDrawArrow
    STA $04

    ; If this is a monster's arrow, add 2 to sprite attributes in [04].
    ; This chooses palette row 6.
    ;
    ; Otherwise, add the arrow item value less 1. This chooses
    ; palette row 4 if the arrow is wooden, otherwise 5 for silver.
    CPX #$0D
    BCS :Z07Int_PlayerArrow
    LDA ObjType, X
    CMP #$5B
    BNE :Z07Int_PlayerArrow
    LDA $04
    CLC
    ADC #$02
    BNE :Z07Int_SetAttr

:Z07Int_PlayerArrow
    CLC
    ADC InvArrow
    SEC
    SBC #$01

:Z07Int_SetAttr
    STA $04

    ; Copy the attribute to [05], and go draw.
    LDA $04
    STA $05
    JMP Z07Int_OffsetAndDrawArrow

Z07Int_CheckState20
    ; If major state <> $20, go check other states.
    CMP #$20
    BNE Z07Int_CheckState30

    ; State $2x. Spark.
    ;
    ; Change the state to $28, and decrement animation counter.
    ; If it hasn't reached 0, then go draw and check for collision
    ; (with Link, if this is a monster's boomerang).
    ;
    ; Minor state 8 selects the frame image and base sprite attribute
    ; for the spark.
    LDA #$28
    STA ObjState, X
    DEC ObjAnimCounter, X
    BNE Z07Int_DrawArrowOrBoomerangAndCheckCollisions

    ; Animation counter = 0.
    ;
    ; Set state to $40. It will become $50 below in
    ; Z07Int_HandleArrowOrBoomerangBlocked.
    LDA #$40
    STA ObjState, X

    ; If this is an arrow (monster's or player's), then deactivate it.
    ; Else go handle the boomerang being blocked.
    CPX #$0D
    BCS :Z07Int_CheckBoomerangBlocked
    LDA ObjType, X
    CMP #$5B
    BEQ :Z07Int_Deactivate

:Z07Int_CheckBoomerangBlocked
    CPX #$12
    BNE Z07Int_HandleArrowOrBoomerangBlocked

:Z07Int_Deactivate
    JSR ResetObjState

    ; If it's a monster's arrow, then destroy it in the monster slot,
    ; including clearing object type.
    CPX #$0D
    BCS :Z07Int_Anon0030
    JSR DestroyCountedMonsterShot
:Z07Int_Anon0030
    RTS

Z07Int_HandleArrowOrBoomerangBlocked
    ; Use animation counter to count down 3 screen frames in case the state is $20 (spark).
    LDA #$03
    STA ObjAnimCounter, X

    ; Add $10 to the state to make it $2x.
    LDA ObjState, X
    CLC
    ADC #$10
    STA ObjState, X

Z07Int_DrawArrowOrBoomerangAndCheckCollisions
    ; If the weapon is a boomerang (not a monster arrow nor player arrow),
    ; then go draw it and check for a collision.
    CPX #$0D
    BCS :Z07Int_DrawPlayerWeapon
    LDA ObjType, X
    CMP #$5B
    BEQ :Z07Int_PrepareArrow

:Z07Int_DrawPlayerWeapon
    CPX #$12
    BEQ :Z07Int_PrepareArrow
    JMP Z07Int_DrawBoomerangAndCheckCollision

:Z07Int_PrepareArrow
    ; Start preparing to draw an arrow.
    ;
    ; Set arrow slot frame 2 (spark) in [0C],
    ; and no horizontal flipping in [0F].
    LDA #$02
    STA $0C
    LDA #$00
    STA $0F

    ; Get reverse index of weapon's direction, and base sprite attribute 0,
    ; and go draw.
    LDA ObjDir, X
    JSR GetOppositeDir
    LDA #$00
    JMP Z07Int_SetAttrAndDrawArrow

Z07Int_CheckState30
    ; If major state <> $30, go check other states.
    CMP #$30
    BNE :Z07Int_CheckOtherStates

    ; State $3x. Slow down.
    ;
    ; Reset grid offset for movement.
    LDA #$00
    STA ObjGridOffset, X

    ; Go slow at q-speed fraction $40 (1 pixel a frame).
    LDA #$40
    STA ObjQSpeedFrac, X

    ; If facing left and X < 2, then go change state to $40. The
    ; boomerang is too close to the left edge of the screen.
    ; Another move might make it wrap around.
    LDA ObjDir, X
    STA $0F
    AND #$02
    BEQ :Z07Int_MoveBoomerang
    LDA ObjX, X
    CMP #$02
    BCC :Z07Int_SetState40

:Z07Int_MoveBoomerang
    ; Move the boomerang.
    JSR MoveObject

    ; Decrement timer ObjMovingLimit. Once it reaches 0, change
    ; state to $40.
    DEC ObjMovingLimit, X
    BNE :Z07Int_AnimateBoomerang

:Z07Int_SetState40
    ; Set state $40, and a time to move of $20 frames.
    ;
    ; In major state $40, ObjMovingLimit is a timer to change the state to $50.
    ;
    ; Also, animate, draw, and handle any collision (with Link, if a monster's boomerang).
    LDA #$20
    STA ObjMovingLimit, X
    LDA #$40
    STA ObjState, X

:Z07Int_AnimateBoomerang
    JMP Z07Int_AnimateBoomerangAndCheckCollision

:Z07Int_CheckOtherStates
    ; State $40 or $50. Return to thrower: $40 slow, $50 fast.
    ;
    ; The boomerang will now return. Reset the grid offset.
    LDA #$00
    STA ObjGridOffset, X

    ; Get the horizontal and vertical directions and distances to the thrower.
    CPX #$0D
    BCS :Z07Int_Anon0031
    LDA ObjRefId, X             ; Monster thrower object index
:Z07Int_Anon0031
    JSR GetDirectionsAndDistancesToTarget

    ; If the boomerang hasn't reached the thrower ([00] < 2),
    ; then go move towards the thrower, draw, and check collisions.
    LDA $00
    CMP #$02
    BNE :Z07Int_MoveTowardThrower

    ; The boomerang has reached the thrower.
    ;
    ; Reset the distance to move.
    ; If this is a monster's boomerang, go handle the monster catching it.
    LDA #$00
    STA ObjMovingLimit, X
    CPX #$0D
    BCC :Z07Int_CatchBoomerang

    ; Link has caught the boomerang.
    ;
    ; Combine Link's state with $20 for having caught the boomerang.
    ;
    ; If Link catches it some time after throwing it,
    ; his state will become $20, and he will show the catch animation.
    ;
    ; But if he catches it right after throwing it, the state becomes
    ; $30 ($10 OR $20), which is the end state of using an item.
    LDA ObjState
    ORA #$20
    STA ObjState

    ; Make to set Link's animation counter to 1, so that he picks
    ; up the new state.
    LDA #$01
    STA ObjAnimCounter

    ; Deactivate the boomerang.
    LDY #$0F
    LDA #$00
            JSR   STA_ObjState_Y
    RTS

:Z07Int_CatchBoomerang
    ; A monster caught the boomerang that it threw.
    ;
    ; Set a timer for the thrower based on a random value:
    ; < $30: $30
    ; < $70: $50
    ; Else:  $70
    LDY #$30
    LDA Random, X
    CMP #$30
    BCC :Z07Int_SetThrowerTimer
    LDY #$50
    CMP #$70
    BCC :Z07Int_SetThrowerTimer
    LDY #$70

:Z07Int_SetThrowerTimer
    TYA
    LDY ObjRefId, X
            JSR   STA_ObjTimer_Y

    ; Reset the thrower's state to make it idle or restart its state machine.
    ; Destroy the monster's boomerang.
    LDA #$00
            JSR   STA_ObjState_Y
    JMP DestroyCountedMonsterShot

:Z07Int_MoveTowardThrower
    ; Move towards the thrower.
    ;
    ; Middle speed index 4 goes equally fast in X and Y axes.
    LDY #$04
    JSR _CalcDiagonalSpeedIndex

    ; Move vertically towards the thrower.
    LDA Z07Int_BoomerangQSpeedFracsY, Y
    JSR SetBoomerangSpeed
    LDA $0A                     ; [0A] vertical direction
    STA $0F
    STA ObjDir, X
    TYA                         ; Save speed index.
    PHA
    JSR MoveObject

    ; Move horizontally towards the thrower.
    PLA
    TAY                         ; Restore speed index.
    LDA Z07Int_BoomerangQSpeedFracsX, Y
    JSR SetBoomerangSpeed
    LDA $0B                     ; [0B] horizontal direction
    STA $0F
    STA ObjDir, X
    JSR MoveObject

Z07Int_AnimateBoomerangAndCheckCollision
    ; Decrement animation counter; and when it reaches 0:
    ; 1. arm it again for 2 frames
    ; 2. advance the minor state within a cycle of 8
    ; 3. see if it's time to play the sound effect, if the boomerang belongs to Link
    DEC ObjAnimCounter, X
    BNE Z07Int_DrawBoomerangAndCheckCollision
    LDA #$02
    STA ObjAnimCounter, X
    INC ObjState, X
    LDA ObjState, X
    AND #$77
    STA ObjState, X
    CPX #$0D
    BCC Z07Int_CalcBoomerangFrame
    LDY #$02                    ; Boomerang effect
    JSR PlayBoomerangSfx

Z07Int_DrawBoomerangAndCheckCollision
    ; If the boomerang belongs to a monster, then check for
    ; collision with Link.
    ;
    ; If they collide, then set state $20 and animation counter 3.
    CPX #$0D
    BCS Z07Int_CalcBoomerangFrame
    JSR CheckLinkCollision
    LDA ShotCollidesWithLink
    BEQ Z07Int_CalcBoomerangFrame
    LDA #$03
    STA ObjAnimCounter, X
    LDA #$20
    STA ObjState, X

Z07Int_CalcBoomerangFrame
    ; The minor state (low 3 bits of state) is used to
    ; set the right frame in [0C] for this point in the spinning cycle.
    ;
    ; Reset [00] and [01]. These are the offsets for boomerang's position.
    ; In other words, don't offset the coordinate below.
    LDA #$00
    STA $00
    LDA ObjState, X
    AND #$0F
    TAY
    LDA #$00
    STA $01
    LDA Z07Int_BoomerangFrameCycle, Y
    STA $0C

    ; Store the base sprite attribute for this point in the cycle in [04].
    TYA
    LDA Z07Int_BoomerangBaseSpriteAttrCycle, Y
    STA $04

    ; If base sprite attribute in [04] = 8, then leave [04] as is.
    ; Else add the item value of the magic boomerang.
    ;
    ; If not sparking, then the magic boomerang's item value (0 or 1)
    ; in the inventory will be added to the base sprite attribute.
    ; So, palette row 4 or 5 will be chosen.
    ;
    ; If sparking, then base sprite attribute 1 from element 8 is used.
    ; Adding the inventory value results in palette row 4 or 5.
    ;
    ; None of the values in the base sprite attributes array is 8.
    ; So, this branch will never be taken. Maybe this is left over from
    ; development.
    LDY #$00
    CMP #$08
    BEQ :Z07Int_Anon0032
    LDY InvMagicBoomerang
:Z07Int_Anon0032
    TYA
    CLC
    ADC $04
    STA $04
    LDY #$1D                    ; Boomerang item slot
    JMP Z07Int_L_DrawArrowOrBoomerang

; Params:
; Y: reverse direction index that the weapon is facing
;
Z07Int_OffsetAndDrawArrow
    ; [00] and [01] will hold sprite X and Y.
    ; Begin with the horizontal and vertical offsets.
    LDA Z07Int_RDirectionToOffsetsX, Y
    STA $00
    LDA Z07Int_RDirectionToOffsetsY, Y
    STA $01
    LDY #$02                    ; Arrow item slot

Z07Int_L_DrawArrowOrBoomerang
    ; Add the weapon's true coordinates to offsets in [00] and [01].
    LDA ObjX, X
    CLC
    ADC $00
    STA $00
    LDA ObjY, X
    CLC
    ADC $01
    STA $01

    ; If state = $2x (spark), use palette row 5 to write sprites.
    ; Otherwise, use the sprite attributes we already calculated.
    LDA ObjState, X
    AND #$F0
    CMP #$20
    BNE :Z07Int_Draw
    LDA #$01
    JSR Anim_SetSpriteDescriptorAttributes

:Z07Int_Draw
    JMP Anim_WriteItemSprites

Z07Int_UpdateRodOrArrow
    ; The rod uses states $3x. Arrow uses $1x and $2x.
    LDA ObjState, X
    AND #$F0
    CMP #$30
    BCS Z07Int_UpdateSwordOrRod
    JMP UpdateArrowOrBoomerang

; 4 sets of horizontal offsets, one for each state of weapon.
; Each set contains 4 offsets in reverse direction index order:
; up, down, left, right
;
; These offsets are added to player X to get weapon X.
;
Z07Int_PlayerToWeaponOffsetsX
            db    $FF, $01, $00, $F8, $FF, $01, $F5, $0B
            db    $FF, $01, $F9, $07, $FF, $01, $FD, $03

; 4 sets of vertical offsets, one for each state of weapon.
; Each set contains 4 offsets in reverse direction index order:
; up, down, left, right
;
; These offsets are added to player Y to get weapon Y.
;
Z07Int_PlayerToWeaponOffsetsY
            db    $F7, $F2, $F5, $F5, $F6, $0D, $03, $03
            db    $F7, $09, $03, $03, $FF, $05, $03, $03

Z07Int_UpdateSwordOrRod
    ; If state = 0, the object is not active. So, return.
    LDA ObjState, X
    AND #$0F
    BEQ :Z07Int_Exit

    ; Decrement the state timer.
    ; If it hasn't expired, go move the sword or rod.
    DEC ObjAnimCounter, X
    BNE :Z07Int_DrawSwordOrRod

    ; State 2 will last 8 frames. The higher ones last 1.
    LDA ObjState, X
    AND #$0F
    TAY
    LDA #$08
    DEY
    BEQ :Z07Int_Anon0033
    LDA #$01
:Z07Int_Anon0033
    ; Set both the player's animation counter and the sword's
    ; animation counter/timer to this value.
    STA ObjAnimCounter
    STA ObjAnimCounter, X

    ; Go to the next state.
    INC ObjState, X

    ; Once we reach state 6, deactivate the object.
    ; Otherwise, go draw it.
    LDA ObjState, X
    AND #$0F
    CMP #$06
    BCC :Z07Int_DrawSwordOrRod
    JSR ResetObjState

:Z07Int_Exit
    RTS

:Z07Int_DrawSwordOrRod
    ; Reset horizontal flipping in [0F].
    LDA #$00
    STA $0F

    ; If state = 5, return without drawing.
    LDA ObjState, X
    AND #$0F
    TAY
    LDA #$FC
    CPY #$05
    BEQ :Z07Int_Exit

:Z07Int_Add4
    ; Set [00] to (state - 1) * 4:
    ; the byte offset of the beginning of a set of pixel offsets.
    CLC
    ADC #$04
    DEY
    BNE :Z07Int_Add4
    STA $00

    ; Set object's direction to player's. It might have changed
    ; since the last frame.
    LDA ObjDir
    STA ObjDir, X

    ; Add [00] and the reverse index of the direction to get
    ; the byte offset of the pixel offset.
    JSR GetOppositeDir
    TYA
    CLC
    ADC $00
    TAY

    ; Set object's X to player's X + offset for state and direction.
    ; Copy the result to [00].
    LDA ObjX
    CLC
    ADC Z07Int_PlayerToWeaponOffsetsX, Y
    STA ObjX, X
    STA $00

    ; Set object's Y to player's Y + offset for state and direction.
    ; Copy the result to [01].
    LDA ObjY
    CLC
    ADC Z07Int_PlayerToWeaponOffsetsY, Y
    STA ObjY, X
    STA $01

    ; If state = 1, use up direction.
    ; Else use object direction.
    LDA ObjState, X
    AND #$0F
    TAY
    LDA #$08
    DEY
    BEQ :Z07Int_CalcAttrs
    LDA ObjDir, X

:Z07Int_CalcAttrs
    ; Store the weapon's frame (horizontal or vertical)
    ; for the direction chosen above in [0C].
    JSR GetOppositeDir
    LDA Z07Int_RDirectionToWeaponFrame, Y
    STA $0C

    ; Calculate sprite attributes.
    ;
    ; If the weapon is the rod, calculate its sprite attributes:
    ;   base attribute OR 1
    ; So, it uses palette row 5.
    LDA Z07Int_RDirectionToWeaponBaseAttribute, Y
    CPX #$0D
    BEQ :Z07Int_CalcSwordAttrs
    ORA #$01
    JMP :Z07Int_SetAttrs

:Z07Int_CalcSwordAttrs
    ; The weapon is the sword.
    ; To calculate the sprite attributes: (item value - 1) + base attribute
    CLC
    ADC Items
    SEC
    SBC #$01

:Z07Int_SetAttrs
    ; Set sprite attributes to the calculated value above.
    JSR Anim_SetSpriteDescriptorAttributes

    ; If the direction is left, set [0F] to flip horizontally.
    CPY #$02
    BNE :Z07Int_Anon0034
    INC $0F
:Z07Int_Anon0034
    ; If state = 1, return. Don't show the weapon.
    LDA ObjState, X
    AND #$0F
    CMP #$01
    BEQ Z07Int_L1F854_Exit

    ; Set Y to the right item slot to pass to the routine to write sprites:
    ; sword or rod
    LDY #$00                    ; Sword slot
    CPX #$0D
    BEQ :Z07Int_Anon0035
    LDY #$08                    ; Rod slot
:Z07Int_Anon0035
    JSR Anim_WriteItemSprites

    ; If state <> 3, return.
    LDA ObjState, X
    AND #$0F
    CMP #$03
    BNE Z07Int_L1F854_Exit

    ; State = 3. Time to instantiate a shot.
    ;
    ; If object slot is not the rod's, go instantiate the sword shot separately.
    CPX #$12
    BNE Z07Int_MakeSwordShot

    ; Instantiate a magic shot (rod shot).
    ; Switch to the shot slot $E.
    LDX #$0E

    ; If high bit of state is set, return. It's already active.
    LDA ObjState, X
    BEQ :Z07Int_MakeMagicShot
    ASL
    BCS Z07Int_L1F854_Exit

:Z07Int_MakeMagicShot
    ; Play "magic shot" tune.
    LDA #$04
    STA Tune0Request

    ; Activate the shot object (state $80).
    LDA #$80

Z07Int_SetUpWeaponWithState
    STA ObjState, X
    LDA #$10
    JSR PlaceWeapon

    ; If the direction is horizontal, and X < $14 or >= $EC, then
    ; deactivate the shot object.
    LDA ObjDir, X
    AND #$03
    BEQ :Z07Int_ChooseSpeed
    LDA ObjX, X
    CMP #$14
    BCC ResetObjState
    CMP #$EC
    BCS ResetObjState

:Z07Int_ChooseSpeed
    ; If high bit of state is set, use $A0 else $C0 for the q-speed fraction.
    ;
    ; The high bit is set for magic shot, and reset for sword shot.
    LDY #$C0
    LDA ObjState, X
    ASL
    BCC :Z07Int_Anon0036
    LDY #$A0
:Z07Int_Anon0036
    TYA
    STA ObjQSpeedFrac, X

    ; Set the shot object's grid offset the same as the player's.
    LDA ObjGridOffset
    STA ObjGridOffset, X

Z07Int_L1F854_Exit
    RTS

; Returns:
; A: 0
;
; If it's the room item, then deactivates it.
;
ResetObjState ENT
    LDA #$00
    STA ObjState, X
    RTS

Z07Int_MakeSwordShot
    ; Try to activate a sword shot.
    ;
    ; Switch to shot slot $E.
    LDX #$0E

    ; If state <> 0, return. It's already activated.
    LDA ObjState, X
    BNE Z07Int_L1F854_Exit

    ; If [0529] is set, go activate a sword shot regardless of hearts.
    ;
    ; UNKNOWN: But I haven't found any code that sets it.
    LDA ForceSwordShot
    BNE :Z07Int_SetUp

    ; If full hearts <> (heart containers - 1), return.
    LDA HeartValues
    PHA
    AND #$0F
    STA $00
    PLA
    LSR
    LSR
    LSR
    LSR
    CMP $00
    BNE Z07Int_L1F854_Exit

    ; If partial heart is less than half full, return.
    LDA HeartPartial
    CMP #$80
    BCC Z07Int_L1F854_Exit

:Z07Int_SetUp
    LDA #$01                    ; Sword shot sound effect
    JSR PlaySample

    ; Go finish setting up a sword shot in initial state $10.
    LDA #$10
    BNE Z07Int_SetUpWeaponWithState

Z07Int_UpdateFire
    ; If this is not a walking fire (state $21), skip moving it.
    LDA ObjState, X
    CMP #$21
    BNE :Z07Int_StandingFie

    ; Move as if grid offset were 0.
    LDA ObjGridOffset, X
    PHA
    LDA #$00
    STA ObjGridOffset, X
    LDA ObjDir, X
    STA $0F
    JSR MoveObject
    PLA

    ; Add grid offset after the move to the original.
    ; This makes it continuous, and useful as a distance traveled.
    CLC
    ADC ObjGridOffset, X
    STA ObjGridOffset, X

    ; If the absolute value of grid offset < $10, go draw.
    ; 
    ; Once the absolute value of grid offset = $10,
    ; make the fire stand instead of move.
    ; Set state $22 and last $3F frames.
    JSR Abs
    CMP #$10
    BNE :Z07Int_DrawAndCheckCollisions
    LDA #$3F
    STA ObjTimer, X
    INC ObjState, X

:Z07Int_StandingFie
    ; Check a standing fire.
    ;
    ; If time has run out, deactivate the item and return.
    LDA ObjTimer, X
    BEQ ResetObjState

    ; If in UW, update the candle to brighten the room if needed.
    LDA CurLevel
    BEQ :Z07Int_DrawAndCheckCollisions
    TXA
    PHA
    LDA #$04
    JSR SwitchBank
    JSR UpdateCandle
    PLA
    TAX

:Z07Int_DrawAndCheckCollisions
    ; Advance the animation counter, and draw.
    LDA #$04                    ; 4 frames in every animation cycle.
    JSR Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor
    JSR Anim_SetObjHFlipForSpriteDescriptor
    JSR Anim_SetSpriteDescriptorRedPaletteRow
    LDA #$00                    ; A: frame 0
    STA $0C                     ; [0C]: not mirrored
    LDY #$40                    ; Y: animation index $40 (but will use $41)
    JSR DrawObjectWithType

    ; Now check for a collision with the player.
    ;
    ; First, if the player is invincible, return.
    LDA ObjInvincibilityTimer
    BNE Z07Int_L1F91D_Exit

    ; Save the object index in [00].
    STX $00

    ; Store the player's center point coordinates in [04] and [05].
    LDX #$00
    LDY #$02
    JSR Z07Int_GetWideObjectMiddle

    ; Store the fire's center point coordinates in [02] and [03].
    LDX $00
    LDY #$00
    JSR Z07Int_GetWideObjectMiddle

    ; If the objects don't collide (< $E pixels in X and Y), then return.
    LDY $00
    LDX #$00
    LDA #$0E
    JSR DoObjectsCollide
    BEQ Z07Int_L1F91D_Exit

    ; The player and the fire collide.
    ;
    ; Make the fire shove the player.
    LDX $00
    LDY #$00
    STY $00
    JSR BeginShove

    ; Harm the player $80 points.
    LDA #$00
    STA $0D
    LDA #$80
    STA $0E
    JMP Link_BeHarmed

; Params:
; X: object index
; Y: offset from [02] and [03] to store center X and Y
;
; Returns:
; [02 + Y]: center X
; [03 + Y]: center Y
;
Z07Int_GetWideObjectMiddle
    LDA ObjX, X
    CLC
    ADC #$08
;    STA $0002, Y
    jsr STA_0002_Y
    LDA ObjY, X
    CLC
    ADC #$08
;    STA $0003, Y
    jsr STA_0003_Y

Z07Int_L1F91D_Exit
    RTS

Z07Int_BombTimes
            db    $30, $18, $0C, $06

Z07Int_BombableWallHotspotsX
            db    $78, $78, $20, $D0

Z07Int_BombableWallHotspotsY
            db    $5D, $BD, $8D, $8D

Z07Int_UpdateBombOrFire
    ; If the object's not active, return.
    LDA ObjState, X
    BEQ Z07Int_L1F95F_Exit

    ; Bomb major state = $10. Fire major state = $20.
    AND #$F0
    CMP #$10
    BEQ Z07Int_UpdateBomb
    JMP Z07Int_UpdateFire

Z07Int_UpdateBomb
    ; This is a bomb.
    ;
    ; If the timer has not expired, then go draw.
    LDA ObjTimer, X
    BNE Z07Int_DrawBomb

    ; The timer has expired. Set another based on the minor state.
    ; Advance the state.
    LDA ObjState, X
    AND #$0F
    TAY
    LDA Z07Int_BombTimes-1, Y
    STA ObjTimer, X
    INC ObjState, X

    ; If the minor state = 3, play the sound effect.
    LDA ObjState, X
    AND #$0F
    PHA
    CMP #$03
    BNE :Z07Int_CheckState5
    LDA #$10
    JSR PlayEffect

:Z07Int_CheckState5
    PLA

    ; If minor state = 5, then deactivate the bomb, and return.
    CMP #$05
    BNE Z07Int_Bomb_CheckState4
    JSR ResetObjState
    STA ObjTimer, X

Z07Int_L1F95F_Exit
    RTS

Z07Int_Bomb_CheckState4
    ; If minor state <> 4, go draw.
    CMP #$04
    BNE Z07Int_DrawBomb

    ; Minor state = 4. Try to break a wall.
    ;
    ; If in OW, go draw. Rock walls have a tile object that checks for bombs.
    LDA CurLevel
    BEQ Z07Int_DrawBomb

    ; Bombs don't blast walls in cellars (mode 9). Go draw.
    LDA GameMode
    CMP #$09
    BEQ Z07Int_DrawBomb

    ; We're in UW. See if the bomb is near a bombable wall.
    LDY #$04

:Z07Int_LoopHotspot
    DEY
    BMI Z07Int_DrawBomb                ; If none is found, then go draw.

    ; If the bomb's X is not within $18 pixels of the hotspot, then
    ; go check the next hotspot.
    LDA Z07Int_BombableWallHotspotsX, Y
    SEC
    SBC ObjX, X
    JSR Abs
    CMP #$18
    BCS :Z07Int_LoopHotspot

    ; If the bomb's Y is not within $18 pixels of the hotspot, then
    ; go check the next hotspot.
    LDA Z07Int_BombableWallHotspotsY, Y
    SEC
    SBC ObjY, X
    JSR Abs
    CMP #$18
    BCS :Z07Int_LoopHotspot

    ; Store in [02] the direction corresponding to the hotspot's index.
    LDA ReverseDirections, Y
    STA $02

    ; If it was already opened or triggered, then go draw.
    AND CurOpenedDoors
    BNE Z07Int_DrawBomb
    LDA TriggeredDoorCmd
    BNE Z07Int_DrawBomb

    ; If it's not a bombable wall, go draw.
    LDA #$05
    JSR SwitchBank
    JSR FindDoorTypeByDoorBit
    CMP #$04
    BNE Z07Int_DrawBomb

    ; Trigger this bombable wall to open.
    LDA #$06
    STA TriggeredDoorCmd
    LDA $02
    STA TriggeredDoorDir

Z07Int_DrawBomb
    ; Draw the bomb or dust cloud.
    JSR Anim_FetchObjPosForSpriteDescriptor
    JSR Z07Int_DrawBombOrCloudAt

    ; If minor state = 2, we drew a bomb. So, return.
    LDA ObjState, X
    AND #$0F
    CMP #$02
    BEQ Z07Int_L1F95F_Exit

    ; Otherwise, we drew one dust cloud. Go draw the others.
    JMP Z07Int_DrawOtherBombClouds

; Params:
; X: object index
; [00]: X
; [01]: Y
;
Z07Int_DrawBombOrCloudAt
    JSR UpdateBombFlashEffect

; Params:
; X: object index
; [00]: X
; [01]: Y
;
Z07Int_DrawBombOrCloudNoFlashing
    ; Set frame image = minor state - 2.
    LDA ObjState, X
    AND #$0F
    SEC
    SBC #$02

; Params:
; A: frame image (1 to 3)
; X: object index
; [00]: X
; [01]: Y
;
Z07Int_DrawCloud
    STA $0C                     ; [0C] frame image
    LDY #$00
    STY $0F                     ; [0F] no horizontal flipping

    ; Write sprites with blue sprite palette row and bomb item slot.
    INY
    STY $04
    STY $05
    LDY #$01                    ; Bomb item slot
    JMP Anim_WriteItemSprites

Z07Int_BombCloudOffsetsY1
            db    $F3, $00, $0E

Z07Int_BombCloudOffsetsX1
            db    $F9, $0E, $07

Z07Int_BombCloudOffsetsY2
            db    $F3, $00, $0E

Z07Int_BombCloudOffsetsX2
            db    $07, $F3, $F9

Z07Int_DrawOtherBombClouds
    ; For each of 3 clouds, indexed by Y register:
    LDY #$02

:Z07Int_LoopCloud
    TYA                         ; Save cloud index.
    PHA

    ; Every other screen frame, add 6 to the index to point inside
    ; the second set of coordinates.
    LDA FrameCounter
    LSR
    BCC :Z07Int_Draw
    TYA
    CLC
    ADC #$06
    TAY

:Z07Int_Draw
    ; Set [01] to cloud position (object Y + Y offset).
    LDA ObjY, X
    CLC
    ADC Z07Int_BombCloudOffsetsY1, Y
    STA $01

    ; Set [00] to cloud position (object X + X offset).
    LDA ObjX, X
    CLC
    ADC Z07Int_BombCloudOffsetsX1, Y
    STA $00

    ; Draw the cloud at this position.
    JSR Z07Int_DrawBombOrCloudNoFlashing
    PLA                         ; Restore cloud index.
    TAY

    ; Loop while >= 0.
    DEY
    BPL :Z07Int_LoopCloud
    RTS

Z07Int_AnimateAndDrawMetaObject
    JSR Anim_FetchObjPosForSpriteDescriptor

    ; If the metastate >= $10, go animate and draw the death sparkle.
    LDA ObjMetastate, X
    CMP #$10
    BCS :Z07Int_AnimateSpark

    ; Animate and draw the spawning cloud.
    AND #$0F
    JSR Z07Int_DrawCloud

:Z07Int_CheckMetaObjTimer
    ; If the object's timer has expire, then go to the next metastate
    ; and last 6 frames.
    LDA ObjTimer, X
    BNE :Z07Int_Exit

:Z07Int_IncMetastate
    LDA #$06
    STA ObjTimer, X
    INC ObjMetastate, X

:Z07Int_Exit
    RTS

:Z07Int_AnimateSpark
    ; If metastate = $10, then go increment metastate and set
    ; object timer without drawing.
    AND #$0F
    BEQ :Z07Int_IncMetastate

    ; Set the frame image in [0C] (1, 0, 1) for the metastate.
    AND #$01
    STA $0C
    LDA #$01                    ; Normal sprite, palette 5 (blue)
    JSR Anim_SetSpriteDescriptorAttributes
    LDY #$24                    ; Death spark
    JSR Anim_WriteItemSprites
    JMP :Z07Int_CheckMetaObjTimer

; Returns:
; Y: animation frame
; [00]: object X
; [01]: object Y
; [0F]: flip horizontally
;
Z07Int_AnimateLinkBase
    LDA ObjState
    BNE AnimateObjectWalking    ; If Link isn't idle, go animate object.
    LDA GameMode
    CMP #$04
    BEQ AnimateObjectWalking    ; If in mode 4, go animate object.
    CMP #$10
    BEQ AnimateObjectWalking    ; If in mode $10, go animate object.
    LDA ObjInputDir
    BEQ Z07Int_SetUpWalkingSprites     ; If there was no direction input button, skip animating Link.

; Params:
; X: object index
;
; Returns:
; Y: animation frame
; [00]: object X
; [01]: object Y
; [0F]: flip horizontal
;
; As the object walks, the animation counter rolls down.
;
AnimateObjectWalking ENT
    DEC ObjAnimCounter, X
    BNE Z07Int_SetUpWalkingSprites

    ; Once the counter reaches 0, and if object is the player,
    ; animate Link's object state.
    CPX #$00
    BNE :Z07Int_Anon0037
    JSR Z07Int_AnimateLinkObjState
:Z07Int_Anon0037
    ; Roll over the counter (6 frames).
    LDA #$06
    STA $00
    JSR Z07Int_RollOverAnimCounter

Z07Int_SetUpWalkingSprites
    ; Set up sprite position in the descriptors.
    JSR Anim_FetchObjPosForSpriteDescriptor

    ; Set up horizontal flipping.
    LDA ObjDir, X
    AND #$0C
    BEQ Z07Int_SetUpHorizontalWalkingSprites

    ; Facing up or down.
    LDY #$03                    ; Assume animation frame 3 (up).
    AND #$08
    BNE Anim_SetObjHFlipForSpriteDescriptor
    DEY                         ; If down, then use animation frame 2 (down).

; Use the movement frame as the value for horizontal flipping.
;
; Params:
; X: object index
;
; Returns:
; [0F]: flip horizontal, based on ObjMovementFrame
;
Anim_SetObjHFlipForSpriteDescriptor ENT
    LDA ObjAnimFrame, X
    STA $0F
    RTS

Z07Int_SetUpHorizontalWalkingSprites
    ; Facing left or right.
    LDY #$00                    ; Assume animation frame 0 (legs apart).
    LDA ObjAnimFrame, X
    BEQ :Z07Int_Anon0038
    INY                         ; If walking frame 1, then animation frame 1 (legs together).
:Z07Int_Anon0038
    LDA ObjDir, X
    AND #$01
    BNE :Z07Int_Anon0039
    INC $0F                     ; Facing left. Flip horizontally.
:Z07Int_Anon0039
    RTS

; Params:
; A: new value for animation counter, in case it rolls over
; X: object index
;
; Returns:
; A: 0
; [00]: X
; [01]: Y
; [0F]: 0 for no horizontal flipping
;
Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor ENT
    STA $00
    DEC ObjAnimCounter, X
    BNE Anim_FetchObjPosForSpriteDescriptor
    JSR Z07Int_RollOverAnimCounter

; Params:
; X: object index
;
; Returns:
; A: 0
; [00]: X
; [01]: Y
; [0F]: 0 for no horizontal flipping
;
Anim_FetchObjPosForSpriteDescriptor ENT
    LDA ObjX, X
    STA $00
    LDA ObjY, X
    STA $01
    LDA #$00                    ; Don't flip horizontally
    STA $0F
    RTS

; Roll over the animation counter, and switch the movement frame.
;
; Params:
; [00]: new counter value
;
Z07Int_RollOverAnimCounter
    LDA $00
    STA ObjAnimCounter, X
    LDA ObjAnimFrame, X
    EOR #$01
    STA ObjAnimFrame, X
    RTS

Z07Int_AnimateLinkObjState
    ; If major state = $10
    ;   if minor state = 0, make it 1
    ;   else OR state with $30
    ;   go set movement frame to 1
    LDA ObjState
    AND #$30
    CMP #$10
    BNE :Z07Int_CheckState20
    LDA ObjState
    AND #$0F
    BNE :Z07Int_CombineStateWith30
    BEQ :Z07Int_IncState

:Z07Int_CheckState20
    ; If major state = $20
    ;   if minor state = 0, make it 1
    ;   else OR state with $30
    ;   go set movement frame to 1
    CMP #$20
    BNE :Z07Int_CheckState30
    LDA ObjState
    AND #$0F
    BNE :Z07Int_CombineStateWith30

:Z07Int_IncState
    INC ObjState
    JMP :Z07Int_SetMovementFrame1

:Z07Int_CombineStateWith30
    LDA ObjState
    ORA #$30
    STA ObjState

:Z07Int_SetMovementFrame1
    ; To animate the state, the animation counter had to have
    ; reached 0. Right after this routine, the counter will be
    ; rolled over, and the movement frame will be switched.
    ;
    ; So, set movement frame to 1 (legs together) at the end of
    ; the animation here, in order to immediately change it to
    ; 0 (legs apart) after this.
    LDA #$01
    STA ObjAnimFrame
    RTS

:Z07Int_CheckState30
    ; If in state $30, then make Link idle, except for halting.
    CMP #$30
    BNE :Z07Int_Anon0040
    LDA ObjState
    AND #$C0
    STA ObjState
:Z07Int_Anon0040
    RTS

; Unknown block
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF

Z07Int_ObjectTypeToAttributes
            db    $FF, $00, $00, $00, $00, $00, $00, $05
            db    $05, $05, $05, $81, $81, $81, $81, $01
            db    $01, $81, $01, $01, $43, $43, $81, $81
            db    $81, $81, $01, $81, $81, $81, $01, $81
            db    $81, $81, $81, $81, $81, $C3, $C3, $89
            db    $89, $81, $81, $89, $89, $89, $89, $83
            db    $81, $89, $89, $C9, $C9, $81, $81, $81
            db    $A9, $A9, $41, $41, $89, $89, $81, $81
            db    $81, $C1, $C1, $C1, $C1, $C1, $81, $81
            db    $81, $A1, $A1, $81, $81, $81, $81, $81
            db    $81, $81, $81, $E3, $E3, $E3, $E3, $E3
            db    $E1, $E1, $E1, $E1, $E1, $81, $81

Z07Int_ObjectTypeToHpPairs
            db    $06, $43, $25, $31, $12, $24, $81, $14
            db    $22, $42, $00, $A9, $8F, $20, $00, $3F
            db    $F9, $FA, $46, $62, $11, $2F, $FF, $FF
            db    $7F, $F6, $2F, $FF, $FF, $22, $46, $F1
            db    $F2, $AA, $AA, $FB, $BF, $F0

; Params:
; A: object type
;
Z07Int_UpdateObject
    PHA
    LDA #$04
    JSR SwitchBank
    PLA

    ; If the object was initialized, go update it.
    LDY ObjUninitialized, X
    STY $0F                     ; [0F] holds the original value of "uninitialized" flag.
    BEQ :Z07Int_Update

    ; If the object type starts with a spawning cloud
    ; (type < $53, except armos and flying ghini),
    ; then set object timer to 7.
    ;
    ; But this will be overridden during initialization.
    LDA ObjType, X
    CMP #$1E                    ; Armos
    BEQ :Z07Int_Init
    CMP #$22                    ; Flying Ghini
    BEQ :Z07Int_Init
    CMP #$53                    ; Flying Rock
    BCS :Z07Int_Init
    LDA #$07
    STA ObjTimer, X

:Z07Int_Init
    ; Flag the object initialized, and go initialize it.
    LDA #$00
    STA ObjUninitialized, X
    JMP Z07Int_InitObject

:Z07Int_Update
    ; The object was already initialized.
    ;
    ; If meta-state <> 0, go update the meta-object
    ; (spawning cloud or dying sparkle).
    LDY ObjMetastate, X
    BEQ :Z07Int_Anon0041
    JMP Z07Int_UpdateMetaObject
:Z07Int_Anon0041
    ; This is a normal update.
    ;
    ; If object type >= $6A, then switch to bank 1,
    ; and go update a cave.
    CMP #$6A
    BCC :Z07Int_NormalObject
    LDA #$01
    JSR SwitchBank
    JMP UpdateCavePerson

:Z07Int_NormalObject
    ; Else call the object update routine.
    JSR TableJump

Z07Int_UpdateObject_JumpTable
            dw    Z07Int_DoNothing
            dw    UpdateLynel
            dw    UpdateLynel
            dw    UpdateMoblin
            dw    UpdateMoblin
            dw    UpdateGoriya
            dw    UpdateGoriya
            dw    UpdateOctorock
            dw    UpdateOctorock
            dw    UpdateOctorock
            dw    UpdateOctorock
            dw    UpdateDarknut
            dw    UpdateDarknut
            dw    UpdateTektiteOrBoulder
            dw    UpdateTektiteOrBoulder
            dw    UpdateBlueLeever
            dw    UpdateRedLeever
            dw    UpdateZora
            dw    UpdateVire
            dw    UpdateZol
            dw    UpdateGel
            dw    UpdateGel
            dw    UpdatePolsVoice
            dw    UpdateLikeLike
            dw    UpdateDigdogger
            dw    Z07Int_DoNothing
            dw    UpdatePeahat
            dw    UpdateKeese
            dw    UpdateKeese
            dw    UpdateKeese
            dw    UpdateArmos
            dw    UpdateBoulderSet
            dw    UpdateTektiteOrBoulder
            dw    UpdateGhini
            dw    UpdateFlyingGhini
            dw    UpdateBlueWizzrobe
            dw    UpdateRedWizzrobe
            dw    UpdatePatraChild
            dw    UpdatePatraChild
            dw    UpdateWallmaster
            dw    UpdateRope
            dw    Z07Int_DoNothing
            dw    UpdateStalfos
            dw    UpdateBubble
            dw    UpdateBubble
            dw    UpdateBubble
            dw    Z07Int_UpdateWhirlwind
            dw    UpdatePondFairy
            dw    UpdateGibdo
            dw    UpdateDodongo
            dw    UpdateDodongo
            dw    UpdateGohma
            dw    UpdateGohma
            dw    Z07Int_UpdateRupeeStash
            dw    Z07Int_UpdateGrumble
            dw    UpdateZelda
            dw    UpdateDigdogger
            dw    UpdateDigdogger
            dw    UpdateLamnola
            dw    UpdateLamnola
            dw    UpdateManhandla
            dw    UpdateAquamentus
            dw    UpdateGanon
            dw    UpdateGuardFire
            dw    UpdateStandingFire
            dw    UpdateMoldorm
            dw    UpdateGleeok
            dw    UpdateGleeok
            dw    UpdateGleeok
            dw    UpdateGleeok
            dw    UpdateGleeokHead
            dw    UpdatePatra
            dw    UpdatePatra
            dw    Z07Int_UpdateTrap
            dw    Z07Int_UpdateTrap
            dw    Z07Int_UpdateUnderworldPerson
            dw    Z07Int_UpdateUnderworldPerson
            dw    Z07Int_UpdateUnderworldPerson
            dw    Z07Int_UpdateUnderworldPerson
            dw    Z07Int_UpdateUnderworldPerson
            dw    Z07Int_UpdateUnderworldPerson
            dw    Z07Int_UpdateUnderworldPersonLifeOrMoney
            dw    Z07Int_UpdateUnderworldPerson
            dw    UpdateMonsterShot
            dw    UpdateMonsterShot
            dw    UpdateFireball
            dw    UpdateFireball
            dw    UpdateMonsterShot
            dw    UpdateMonsterShot
            dw    UpdateMonsterShot
            dw    UpdateMonsterShot
            dw    UpdateMonsterArrow
            dw    UpdateArrowOrBoomerang
            dw    UpdateDeadDummy
            dw    Z07Int_UpdateFluteSecret
            dw    Z07Int_DoNothing
            dw    UpdateItem
            dw    UpdateDock
            dw    UpdateRockOrGravestone
            dw    UpdateRockWall
            dw    UpdateTree
            dw    UpdateRockOrGravestone
            dw    UpdateRockOrGravestone
            dw    UpdateRockWall
            dw    UpdateBlock
            dw    Z07Int_DoNothing

Z07Int_UpdateMetaObject
    JSR Z07Int_AnimateAndDrawMetaObject

    ; Go handle end metastates (4 and $14) specially.
    LDA ObjMetastate, X
    AND #$0F
    CMP #$04
    BCS Z07Int_UpdateMetaObjectEnd

Z07Int_DoNothing
    RTS

Z07Int_UpdateMetaObjectEnd
    ; Metastate = 4 or $14.
    ;
    ; If it's 4, go reset the metastate. The object is ready to update
    ; on its own.
    LDA ObjMetastate, X
    AND #$10
    BEQ :Z07Int_Reset

    ; Metastate = $14
    ;
    ; Copy the object type, so that it can be used in setting up
    ; a dropped item.
    LDA ObjType, X
    STA Item_ObjMonsterType, X

    ; Certain objects don't advance the world kill cycle.
    CMP #$5D
    BEQ :Z07Int_DropItem
    CMP #$14                    ; Child Gel
    BEQ :Z07Int_DropItem
    CMP #$1C                    ; Red Keese
    BEQ :Z07Int_DropItem

    ; Advance the world kill cycle (0 to 9).
    LDA WorldKillCycle
    CLC
    ADC #$01
    CMP #$0A
    BNE :Z07Int_Anon0042
    LDA #$00
:Z07Int_Anon0042
    STA WorldKillCycle

    ; If the object is not a zora, then increase room kill count.
    LDA ObjType, X
    CMP #$11                    ; Zora
    BEQ :Z07Int_DropItem
    INC RoomKillCount

:Z07Int_DropItem
    ; Turn this object into a dropped item.
    LDA #$60
    STA ObjType, X
    STA ObjUninitialized, X     ; Flag it uninitialized.
    LDA #$81                    ; "Custom collision check and drawing" + "Z07Int_Reverse after hitting Link"
    STA ObjAttr, X
    JSR SetUpDroppedItem

:Z07Int_Reset
    JMP ResetObjMetastate

Z07Int_InitObject
    LDX CurObjIndex

    ; We want to handle "enemies from the edges of the screen".
    ;
    ; So, if not in UW, or "enemies from edges" attribute is clear,
    ; or the object is (zora, fire, armos, whirlwind), or any object
    ; that does not spawn with a cloud (type >= $53);
    ; 
    ; then go initialize the object.
    LDA CurLevel
    BNE :Z07Int_NormalSpawn
    LDA LevelBlockAttrsByteF
    AND #$08                    ; Enemies from edges
    BEQ :Z07Int_NormalSpawn
    LDA ObjType, X
    CMP #$11                    ; Zora
    BEQ :Z07Int_NormalSpawn
    CMP #$40                    ; Fire
    BEQ :Z07Int_NormalSpawn
    CMP #$1E                    ; Armos
    BEQ :Z07Int_NormalSpawn
    CMP #$2E                    ; Whirlwind
    BEQ :Z07Int_NormalSpawn
    CMP #$53                    ; Flying rock
    BCS :Z07Int_NormalSpawn

:Z07Int_UninitMonsterFromEdge
    ; If the "monsters from edges" long timer expired, then
    ; go bring the monster in.
    ; Else revert the flag, so this monster becomes uninitialized.
    LDA MonstersFromEdgesLongTimer
    BEQ :Z07Int_InitMonsterFromEdge
    STA ObjUninitialized, X
    RTS

:Z07Int_InitMonsterFromEdge
    LDX CurObjIndex
    LDA #$05
    JSR SwitchBank
    JSR FindNextEdgeSpawnCell

    ; Extract and set the monster's location.
    LDA CurEdgeSpawnCell

    ; Square column in low nibble. Multiply by 16 to get X.
    PHA
    ASL
    ASL
    ASL
    ASL
    STA ObjX, X

    ; Square row in high nibble. Subtract 3, for the usual offset, to get Y.
    PLA
    AND #$F0
    SEC
    SBC #$03
    STA ObjY, X

    ; Set the monsters-from-edges long timer to a random value
    ; between 2 and 5. So, it will last 20 to 50 frames.
    LDA Random+1, X
    AND #$03
    CLC
    ADC #$02
    STA MonstersFromEdgesLongTimer

    ; If the distance to Link is too close to Link, then
    ; go flag the monster uninitialized again, so we can
    ; try to spawn it again next time.
    LDA #$05
    JSR SwitchBank
    JSR IsDistanceSafeToSpawn
    BCS :Z07Int_UninitMonsterFromEdge

    ; OK to spawn.
    ; In this situation, monsters don't spawn from a cloud.
    LDA #$00
    STA ObjMetastate, X

:Z07Int_NormalSpawn
    LDA #$04
    JSR SwitchBank

    ; For monsters that spawn in a cloud, set their start time to
    ; the same value as the object slot; so that they all start
    ; moving at different times.
    LDX CurObjIndex
    LDY ObjType, X
    CPY #$1E                    ; Armos
    BEQ :Z07Int_FetchAttrs
    CPY #$22                    ; Flying Ghini
    BEQ :Z07Int_FetchAttrs
    CPY #$53                    ; Flying rock
    BCS :Z07Int_FetchAttrs
    TXA
    STA ObjTimer, X

:Z07Int_FetchAttrs
    ; Store the object attributes for fast access.
    LDA Z07Int_ObjectTypeToAttributes, Y
    STA ObjAttr, X
    TYA
    STA $00                     ; [00] holds object type.

    ; Hit points are packed two values to a byte.
    ; Divide the object type in half in order to index
    ; into the hit points table.
    LSR
    TAY
    LDA Z07Int_ObjectTypeToHpPairs, Y
    JSR ExtractHitPointValue
    STA ObjHP, X

    ; If the object is a cave, go initialize it.
    LDA $00
    CMP #$6A                    ; Cave 1
    BCC :Z07Int_CheckTileObj
    LDA #$01
    JSR SwitchBank
    JMP InitCave                ; Init cave

:Z07Int_CheckTileObj
    ; If object is a cave or tile object (type >= $5F),
    ; go assign object attribute $81, and get
    ; it ready to behave autonomously and updating.
    CMP #$5F
    BCC :Z07Int_Anon0043
    JMP Z07Int_InitTileObjOrItem
:Z07Int_Anon0043
    ; Else run the object initialization routine.
    JSR TableJump

Z07Int_InitObject_JumpTable
            dw    Z07Int_DoNothing
            dw    InitWalker
            dw    InitWalker
            dw    InitWalker
            dw    InitWalker
            dw    InitWalker
            dw    InitWalker
            dw    InitSlowOctorockOrGhini
            dw    InitFastOctorock
            dw    InitSlowOctorockOrGhini
            dw    InitFastOctorock
            dw    InitDarknut
            dw    InitDarknut
            dw    InitTektite
            dw    InitTektite
            dw    InitLeever
            dw    InitLeever
            dw    ResetObjMetastateAndTimer
            dw    InitWalker
            dw    InitWalker
            dw    InitWalker
            dw    InitGel
            dw    InitWalker
            dw    InitWalker
            dw    Z07Int_DoNothing
            dw    Z07Int_DoNothing
            dw    InitPeahat
            dw    InitBlueKeese
            dw    InitRedOrBlackKeese
            dw    InitRedOrBlackKeese
            dw    InitArmosOrFlyingGhini
            dw    InitBoulderSet
            dw    InitBoulder
            dw    InitSlowOctorockOrGhini
            dw    InitArmosOrFlyingGhini
            dw    ResetObjMetastateAndTimer
            dw    ResetObjMetastateAndTimer
            dw    ResetObjMetastateAndTimer
            dw    ResetObjMetastateAndTimer
            dw    ResetObjMetastateAndTimer
            dw    InitRope
            dw    Z07Int_DoNothing
            dw    InitWalker
            dw    InitBubble
            dw    InitBubble
            dw    InitBubble
            dw    Z07Int_DoNothing
            dw    InitPondFairy
            dw    InitWalker
            dw    InitDodongo
            dw    InitDodongo
            dw    InitGohma
            dw    InitGohma
            dw    Z07Int_InitRupeeStash
            dw    Z07Int_InitGrumble
            dw    InitZelda
            dw    InitDigdogger1
            dw    InitDigdogger2
            dw    InitLamnola
            dw    InitLamnola
            dw    InitManhandla
            dw    InitAquamentus
            dw    InitGanon
            dw    Z07Int_DoNothing
            dw    Z07Int_DoNothing
            dw    InitMoldorm
            dw    InitGleeok
            dw    InitGleeok
            dw    InitGleeok
            dw    InitGleeok
            dw    InitGleeokHead
            dw    InitPatra
            dw    InitPatra
            dw    Z07Int_InitTrap
            dw    Z07Int_InitTrap
            dw    Z07Int_InitUnderworldPerson
            dw    Z07Int_InitUnderworldPerson
            dw    Z07Int_InitUnderworldPerson
            dw    Z07Int_InitUnderworldPerson
            dw    Z07Int_InitUnderworldPerson
            dw    Z07Int_InitUnderworldPerson
            dw    Z07Int_InitUnderworldPersonLifeOrMoney
            dw    Z07Int_InitUnderworldPerson
            dw    InitMonsterShot
            dw    _InitMonsterShot_Unknown54
            dw    InitMonsterShot
            dw    InitMonsterShot
            dw    InitMonsterShot
            dw    InitMonsterShot
            dw    InitMonsterShot
            dw    InitMonsterShot
            dw    ResetObjMetastate
            dw    ResetObjMetastate
            dw    UpdateDeadDummy
            dw    Z07Int_InitFluteSecret

Z07Int_UpdateWhirlwind
    LDA #$01
    JSR SwitchBank
    JMP UpdateWhirlwind_Full

Z07Int_InitRupeeStash
    LDA #$01
    JSR SwitchBank
    JMP InitRupeeStash_Full

Z07Int_UpdateRupeeStash
    LDA #$01
    JSR SwitchBank
    JMP UpdateRupeeStash_Full

Z07Int_InitTrap
    LDA #$01
    JSR SwitchBank
    JMP InitTrap_Full

Z07Int_UpdateTrap
    LDA #$01
    JSR SwitchBank
    JMP UpdateTrap_Full

Z07Int_InitUnderworldPerson
    LDA #$01
    JSR SwitchBank
    JMP InitUnderworldPerson_Full

Z07Int_InitUnderworldPersonLifeOrMoney
    LDA #$01
    JSR SwitchBank
    JMP InitUnderworldPersonLifeOrMoney_Full

Z07Int_InitGrumble
    LDA #$01
    JSR SwitchBank
    JMP InitGrumble_Full

Z07Int_UpdateUnderworldPerson
    LDA #$01
    JSR SwitchBank
    JMP UpdateUnderworldPerson_Full

Z07Int_UpdateUnderworldPersonLifeOrMoney
    LDA #$01
    JSR SwitchBank
    JMP UpdateUnderworldPersonLifeOrMoney_Full

Z07Int_UpdateGrumble
    LDA #$01
    JSR SwitchBank
    JMP UpdateGrumble_Full

; Params:
; X: object index
;
DecrementInvincibilityTimer ENT
    LDA ObjInvincibilityTimer, X
    BEQ :Z07Int_Exit                   ; If the timer is already zero, then return.
    LDA FrameCounter            ; Every two frames, decrease the timer.
    LSR
    BCS :Z07Int_Exit
    DEC ObjInvincibilityTimer, X

:Z07Int_Exit
    RTS

UpdateDeadDummy ENT
    LDA #$20                    ; Monster died sound effect
    STA Tune1Request
    LDA #$10                    ; First metastate of death spark
    STA ObjMetastate, X
    RTS

; Params:
; X: object index
;
DestroyMonster ENT
    LDA #$00

; Params:
; A: object type
; X: object index
;
SetTypeAndClearObject ENT
    STA ObjType, X
    LDA #$00
    JMP DestroyObject_WRAM

; Look for an empty object slot for a monster from $B to 1.
;
; Returns:
; A: 0 if found an empty slot
; Y: an empty slot, if found
; Z: 0 if found an empty slot
; [59]: an empty slot, if found
;
FindEmptyMonsterSlot ENT
    LDY #$0C

:Z07Int_Loop
    DEY
    BEQ :Z07Int_End
    LDA ObjType, Y
    BNE :Z07Int_Loop
    STY EmptyMonsterSlot

:Z07Int_End
    CPY #$00
    RTS

Z07Int_InitTileObjOrItem
    ; Set object attribute to $81, and go reset metastate and timer;
    ; so that the object is ready to start updating itself.
    ;
    ; Obj attr $81 = "Custom check collision and drawing"
    ;              + "Z07Int_Reverse after hitting Link"
    LDA #$81
    STA ObjAttr, X
    BNE ResetObjMetastateAndTimer

Z07Int_InitFluteSecret
    ; Summary:
    ; The flute secret object manages the secret color cycle.
    ;
    ; The flute secret object is initialized in the same frame that
    ; the flute was wielded. But this object won't update until
    ; the flute timer expires.
    LDA #$01
    STA SecretColorCycle

ResetObjMetastateAndTimer ENT
    LDA #$00
    STA ObjTimer, X

ResetObjMetastate ENT
    ; Reset the object metastate so that it's ready to start
    ; behaving autonomously (updating on its own).
    ; This is the normal state outside of the spawning cloud and
    ; the death sparkle.
    LDA #$00
    STA ObjMetastate, X
    RTS

Z07Int_WaterPaletteTransferBufTemplate
            db    $3F, $0C, $04, $0F, $17, $37, $12, $FF

Z07Int_PondCycleColors
            db    $12, $11, $22, $21, $31, $32, $33, $35
            db    $34, $36, $37, $37

Z07Int_UpdateFluteSecret
    ; If secret color cycle >= $C, return.
    LDY SecretColorCycle
    CPY #$0C
    BCS Z07Int_L1FF28_Exit

    ; 7 of every 8 frames, return.
    LDA FrameCounter
    AND #$07
    CMP #$04
    BNE Z07Int_L1FF28_Exit

    ; So, every 8 frames:
    ; 1. Increment the secret color cycle count.
    ; 2. Change the water palette.
    ;
    ; But when the count = $B, go reveal the stairs.
    INC SecretColorCycle
    CPY #$0B
    BEQ Z07Int_RevealPondStairs

; Params:
; Y: a point in the cycle (0 to $B)
;
Z07Int_CueTransferPondPaletteRow
    ; Copy water palette (palette row 3) transfer buf to dynamic
    ; transfer buf.
    TYA
    PHA
    LDY #$07

:Z07Int_CopyBytes
    LDA Z07Int_WaterPaletteTransferBufTemplate, Y
    STA DynTileBuf, Y
    DEY
    BPL :Z07Int_CopyBytes
    PLA
    TAY
    LDA Z07Int_PondCycleColors, Y      ; Patch byte 3 of palette row with the right color in the cycle.
    STA DynTileBuf+6
    CPY #$0A
    BNE Z07Int_L1FF28_Exit             ; If the index is $A,
    LDA #$99                    ; then make most water tiles (< $99) walkable.
    STA ObjectFirstUnwalkableTile

Z07Int_L1FF28_Exit
    RTS

Z07Int_RevealPondStairs
    ; Set X and Y in this slot for the stairs in the pond.
    ; Go reveal the stairs as a secret.
    LDA #$60
    STA ObjX, X
    LDA #$90
    STA ObjY, X
    JMP RevealAndFlagSecretStairsObj

AnimatePond ENT
    ; Take turns between:
    ; * 4 frames stepping the cycle
    ; * 4 frames delaying
    LDA FrameCounter
    AND #$04
    BEQ Z07Int_L1FF28_Exit
    DEC SecretColorCycle
    LDY SecretColorCycle
    JMP Z07Int_CueTransferPondPaletteRow

; .SEGMENT "BANK_07_ISR"
    ds   $FF50-*

; On reset, bank 3 (rom_02.s) is selected in for $8000-$BFFF

IsrReset ENT
;    SEI                         ; Disable interrupts.
    nop                         ; IIgs cannot have interrupts disabled

    CLD                         ; Clear decimal mode.
    LDA #$00
            JSR   STA_2000
;    LDX #$FF
;    TXS                         ; Set the stack to $01FF.
    nop                          ; IIgs sets stack before reset vector entry
    nop
    nop

:Z07Int_Anon0044
    JSR   LDA_2002
    AND #$80
;    BEQ :Z07Int_Anon0044
    nop
    nop                         ; IIgs does not need to wait for VBL in the harness
:Z07Int_Anon0045
    JSR   LDA_2002
    AND #$80                    ;   in case the first was left over from a previous run.
;    BEQ :Z07Int_Anon0045
    nop
    nop

    ORA #$FF
;    STA $8000                   ; Reset all MMC1 shift registers.
;    STA $A000
;    STA $C000
;    STA $E000
    jsr STA_MMC1_REG0            ; IIgs maps to MMC1 
    jsr STA_MMC1_REG1
    jsr STA_MMC1_REG2
    jsr STA_MMC1_REG3
    
    LDA #$0F                    ; Set our normal mirroring and PRG ROM bank mode.
    JSR SetMMC1Control
    LDA #$00                    ; Use CHR RAM bank 0 for PPU address $00000.
;    STA $A000
    jsr STA_MMC1_REG1
    LSR
;    STA $A000
    jsr STA_MMC1_REG1
    LSR
;    STA $A000
    jsr STA_MMC1_REG1
    LSR
;    STA $A000
    jsr STA_MMC1_REG1
    LSR
;    STA $A000
    jsr STA_MMC1_REG1

    LDA #$07
    JSR SwitchBank
    JMP RunGame

SetMMC1Control
;    STA $8000
    jsr  STA_MMC1_REG0
    LSR
;    STA $8000
    jsr  STA_MMC1_REG0
    LSR
;    STA $8000
    jsr  STA_MMC1_REG0
    LSR
;    STA $8000
    jsr  STA_MMC1_REG0
    LSR
;    STA $8000
    jsr  STA_MMC1_REG0
    RTS

SwitchBank
;    STA $E000
    jsr  STA_MMC1_REG3
    LSR
;    STA $E000
    jsr  STA_MMC1_REG3
    LSR
;    STA $E000
    jsr  STA_MMC1_REG3
    LSR
;    STA $E000
    jsr  STA_MMC1_REG3
    LSR
;    STA $E000
    jsr  STA_MMC1_REG3
    RTS

; .SEGMENT "BANK_07_VEC"
; Pad to $FFEB
    ds   $FFEB-*

; Unknown block
            db    $5A, $45, $4C, $44, $41, $D7, $C8, $00
            db    $00, $38, $04, $01, $04, $01, $BE

IsrVector
            dw    IsrNmi
            dw    IsrReset
            dw    $FFF0

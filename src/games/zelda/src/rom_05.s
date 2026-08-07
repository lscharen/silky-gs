; Cross-bank externals (not yet resolvable to a real bank -- see
; CLAUDE.md plan notes on deferred MMC1 bank-dispatch infra)
Abs  EXT
Add1ToInt16At0  EXT
Add1ToInt16At2  EXT
Add1ToInt16At4  EXT
AddToInt16At0  EXT
AddToInt16At2  EXT
AddToInt16At4  EXT
Anim_WriteStaticItemSpritesWithAttributes  EXT
AnimateWorldFading  EXT
BeginUpdateMode  EXT
CheckMazes  EXT
CheckPersonBlocking  EXT
CompareHeartsToContainers  EXT
DrawObjectWithAnimAndSpecificSprites  EXT
FormatStatusBarText  EXT
GetOppositeDir  EXT
GetRoomFlagUWItemState  EXT
GetShortcutOrItemXY  EXT
HideObjectSprites  EXT
InitModeB_EnterCave_Bank5  EXT
Negate  EXT
PlaceWeaponForPlayerState  EXT
PlaceWeaponForPlayerStateAndAnim  EXT
PlaceWeaponForPlayerStateAndAnimAndWeaponState  EXT
PlayEffect  EXT
PlaySample  EXT
ResetCurSpriteIndex  EXT
ResetRoomTileObjInfo  EXT
ReverseDirections  EXT
SilenceAllSound  EXT
Sub1FromInt16At4  EXT
UpdatePlayerPositionMarker  EXT
UpdateWorldCurtainEffect  EXT
WieldBomb  EXT
WieldCandle  EXT
WriteBlankPrioritySprites  EXT
ColumnDirectoryOW  EXT
LevelNumberTransferBuf  EXT
TriforceRow0TransferBuf  EXT

SetMirrorMode  EXT

            mx    %11
            ds    $5000-*

            put   ../../../rom/rom_inject.s
            put   helpers.s

            ds \,$00

            use   BeginEndVars.inc
            use   CaveVars.inc
            use   CommonVars.inc
            use   ObjVars.inc
            use   Variables.inc

; Do not encroach on WRAM (battery-backed space)
            ds    $6000-*

; Pad up to $8000
            ds    $8000-*

; .INCLUDE "Variables.inc" (hoisted to file header)
; .INCLUDE "CommonVars.inc" (hoisted to file header)

; .SEGMENT "BANK_05_00"


; Imports from RAM code bank 01


; Imports from RAM code bank 06


; Imports from program bank 07




UpdateMenuAndMeters ENT
    JSR UpdateMenu
    JMP UpdateHeartsAndRupees

UpdateMenu
    LDA MenuState
    LDY CurLevel
    BEQ :Anon0001

    ; Update menu in UW.
    JSR TableJump

UpdateMenuUW_JumpTable
            dw    UpdateMenu_Return
            dw    UpdateMenuCommon1
            dw    UpdateMenuCommon2
            dw    UpdateMenuCommon3
            dw    UpdateMenuCommon4
            dw    UpdateMenu5UW
            dw    UpdateMenuScrollDownUW
            dw    UpdateMenuActive
            dw    UpdateMenuScrollUp
:Anon0001
    ; Update menu in OW.
    JSR TableJump

UpdateMenuOW_JumpTable
            dw    UpdateMenu_Return
            dw    UpdateMenuStartOW
            dw    UpdateMenuCommon1
            dw    UpdateMenuCommon2
            dw    UpdateMenuCommon3
            dw    UpdateMenuCommon4
            dw    UpdateMenu5OW
            dw    UpdateMenuScrollDownOW
            dw    UpdateMenuActive
            dw    UpdateMenuScrollUp

UpdateMenuCommon1
    JSR HideAllSprites
    JSR UpdatePlayerPositionMarker
    JSR UpdateTriforcePositionMarker

    ; Move position markers and hardware vertical scroll position
    ; down 1 pixel.
    ;
    ; Because we'll be above the top of NT 0, switch to NT 2 to
    ; be at the bottom of NT 2.
    LDA #$EF
    STA CurVScroll
    STA SwitchNameTablesReq
    LDA #$01                    ; 1 pixel
    JSR MovePositionMarkers
    INC MenuState               ; Set menu state 2.

    ; SubmenuScrollProgress begins at $2B. Each frame it will be
    ; decremented. It encodes a submenu row index in bits 1 to 7,
    ; and a flag in bit 0.
    ;
    ; When the flag is 1, a full row of black tiles will be transferred
    ; at the current row. Otherwise, one of various static visual
    ; elements will be transferred.
    ;
    ; For example:
    ; 1. In the first frame of scrolling, $2B indicates that a full row
    ;    of black tiles must be transferred to row $15.
    ; 2. In the second frame ($2A), submenu row will again be
    ;    $15, but something else will be transferred.
    ; 3. In the third frame ($29), a full row of black tiles will be
    ;    transferred to row $14.
    LDA #$2B
    STA SubmenuScrollProgress

    ; In UW, this variable will be used to scan every room in order
    ; to build the big sheet map in the submenu. It will range
    ; from $7F to 0.
    LDA #$7F
    STA CurScanRoomId

UpdateMenu_Return
    RTS

UpdateMenuCommon2
    ; Cue the transfer of first set of submenu nametable attributes to NT 2.
    ; Advance state.
    LDA #$48

SelectTransferBufAndIncState
    STA TileBufSelector
:Anon0002
    INC MenuState
    RTS

UpdateMenuCommon3
    ; Cue the transfer of second set of submenu nametable attributes to NT 2.
    ; Advance state.
    LDA #$4A
    BNE SelectTransferBufAndIncState

UpdateMenuCommon4
    ; Cue the transfer of a blank row of tiles to the bottom of NT 2.
    ; Advance state.
    LDA #$4C
    BNE SelectTransferBufAndIncState

UpdateMenu5UW
    JSR Submenu_CueTransferRowUW
    JMP :Anon0002

UpdateMenu5OW
    ; Cue the transfer of "TRIFORCE" text.
    LDA #$5C
    BNE SelectTransferBufAndIncState

UpdateMenuScrollDownOW
    JSR Submenu_CueTransferRowOW
    JMP :Anon0003

UpdateMenuScrollDownUW
    JSR Submenu_CueTransferRowUW
:Anon0003
    ; Move position markers and advance nametable scrolling;
    ; so that we scroll down 3 pixels.
    LDA #$03
    JSR MovePositionMarkers
    LDA CurVScroll
    SEC
    SBC #$03
    STA CurVScroll

    ; There's nothing else to do until we reach hardware VScroll=$41. Return.
    CMP #$41
    BNE :Exit

    ; VScroll reached $41.
    ; Advance the submenu state.
    ; If in OW or in a cellar, we're done. Return.
    INC MenuState
    LDA CurLevel
    BEQ :Exit
    LDA GameMode
    CMP #$09
    BEQ :Exit

    ; Calculate the X coordinate of the submenu position marker.
    ;
    ; First, mask off the high nibble of the room ID and multiply by
    ; the width of a tile, 8. Store the result in [00].
    LDA RoomId
    AND #$0F
    ASL
    ASL
    ASL
    STA $00

    ; If the submenu map's rotation >= 8, it's the same as a
    ; negative or left rotation by ($10 - rotation value).
    ;
    ; Subtract the two values as shown. Multiply the result by 8,
    ; the width of a tile. Then negate it. The final result is the
    ; negative offset.
    LDA LevelInfo_SubmenuMapRotation
    CMP #$08
    BCC :ShortRotation
    LDA #$10
    SBC LevelInfo_SubmenuMapRotation
    ASL
    ASL
    ASL
    JSR Negate
    JMP :SumMarkerX

:ShortRotation
    ; The submenu map's rotation < 8.
    ; It represents the number of tiles to move right.
    ; So, multiply it by 8.
    ASL
    ASL
    ASL

:SumMarkerX
    ; Add the offset we calculated, and $62 to [00] to get
    ; the position marker's X coordinate.
    CLC
    ADC $00
    CLC
    ADC #$62
    STA Sprites+83

    ; Mask off the low nibble of room ID to get a multiple of $10.
    ; Divide by 2 to get a multiple of the tile height.
    ; Then add $69 to get the Y coordinate of the sprite.
    LDA RoomId
    AND #$F0
    LSR
    ADC #$69
    STA Sprites+80

    ; Write tile $3E (dot) and attributes 0 (Link palette row 4).
    LDA #$3E
    STA Sprites+81
    LDA #$00
    STA Sprites+82

:Exit
    RTS

UpdateMenuActive
    JSR DrawSubmenuItems
    JSR UpdateSubmenuSelection

    ; If buttons Up and A are down on the second controller, then
    ; 1. reset submenu state
    ; 2. go to mode 8
    ; 3. silence sound
    LDA ButtonsDown+1
    AND #$88
    CMP #$88
    BNE :Anon0004
    JSR EndGameMode
    STA MenuState
    LDA #$08
    STA GameMode
    LDA #$00
    STA SongEnvelopeSelector
    JMP SilenceSound
:Anon0004
    ; If Start was pressed, then hide all sprites except
    ; Link and triforce position markers, and go to the next state (scroll up).
    LDA ButtonsPressed
    AND #$10
    BEQ Exit
    LDA Sprites+84              ; Save Link's position marker's Y.
    PHA
    LDA Sprites+88              ; Save triforce's position marker's Y.
    PHA
    JSR HideAllSprites
    PLA                         ; Restore triforce's position marker's Y.
    STA Sprites+88
    PLA                         ; Restore Link's position marker's Y.
    STA Sprites+84
    INC MenuState
    RTS

UpdateMenuScrollUp
    ; Move position marker's and vertical scroll up 3 pixels.
    LDA #$FD
    JSR MovePositionMarkers
    LDA CurVScroll
    CLC
    ADC #$03
    STA CurVScroll

    ; If hardware vertical scroll still < $F0, then return.
    CMP #$F0
    BCC Exit

    ; Once vertical scroll >= $F0, switch to NT0.
    STA SwitchNameTablesReq

    ; In UW, clear the first $10 sprites. This clears the submenu cursor.
    ;
    ; UNKNOWN: But why not do this in OW, too?
    LDA CurLevel
    BEQ :Anon0005
    JSR WriteBlankPrioritySprites
:Anon0005
    ; We reached the end. So, reset hardware vertical scroll
    ; and submenu state.
    LDA #$00
    STA CurVScroll
    STA MenuState

    ; Move the position markers 2 pixels down, because we
    ; overshot and reached vertical scroll $F2.
    LDA #$02

; Params:
; A: vertical velocity of menu scrolling
;
MovePositionMarkers
    STA $00                     ; [00] holds the vertical velocity of menu scrolling.

    ; If Link's position marker is visible, then move it by the velocity in [00].
    LDA Sprites+84
    CMP #$F8
    BEQ :Anon0006
    CLC
    ADC $00
    STA Sprites+84
:Anon0006
    ; If in UW and have the compass, then move the triforce position marker.
    LDA CurLevel
    BEQ Exit
    JSR HasCompass
    BEQ Exit
    LDA Sprites+88
    CLC
    ADC $00
    STA Sprites+88

Exit
    RTS

TriforceTransferBufOffsets
            db    $00, $08, $09, $01, $0A, $0B, $12, $1E
            db    $1F, $17, $24, $25, $13, $14, $21, $13
            db    $20, $21, $15, $16, $22, $16, $22, $23

TriforceTriforceBufReplacements
            db    $E7, $E7, $F5, $E8, $F5, $E8, $E7, $E7
            db    $F5, $E8, $F5, $E8, $E5, $F5, $E5, $E8
            db    $F5, $E8, $F5, $E6, $E6, $E7, $E7, $F5

TriforceTransferBufTiles
            db    $E9, $E9, $24, $EA, $24, $EA, $E9, $E9
            db    $24, $EA, $24, $EA, $24, $24, $24, $24
            db    $24, $24, $24, $24, $24, $24, $24, $24

UpdateMenuStartOW
    ; Put the tiles into the submenu triforce transfer buffers that
    ; make it look completely empty, and no piece has been won.
    LDY #$17
:Anon0007
    LDX TriforceTransferBufOffsets, Y
    LDA TriforceTransferBufTiles, Y
    STA TriforceRow0TransferBuf+4, X
    DEY
    BPL :Anon0007

    ; Reset triforce tile slot. These range from 0 to $17.
    INY

    ; Outer loop.
    ; A level test bit in [06] will be used to see whether
    ; we have a triforce piece.
    LDA #$01
    STA $06                     ; [06] level test bit

:LoopPiece
    ; Inner loop.
    ; Each level bit will make 3 triforce tile slots be
    ; checked and replaced.
    LDA #$03
    STA $07                     ; [07] inner loop counter

:LoopTile
    ; Get the offset into the submenu triforce transfer buffers of
    ; the current tile slot.
    LDX TriforceTransferBufOffsets, Y

    ; If the level test bit is not in the triforce mask, then we don't
    ; have this piece. So, go loop again, and leave the tile in the
    ; empty state.
    LDA $06                     ; [06] level test mask
    BIT InvTriforce
    BEQ :NextLoopTile

    ; We have the triforce piece.
    ;
    ; If the base/empty tile already in the transfer buf = $E5 or $E6,
    ; then make it $F5. These are tiles that were half full, and now
    ; need to be full.
    ;
    ; Else replace it with the one at the current triforce tile slot
    ; in the replacement list.
    LDA TriforceRow0TransferBuf+4, X
    CMP #$E5
    BEQ :ReplaceWithF5
    CMP #$E6
    BEQ :ReplaceWithF5
    LDA TriforceTriforceBufReplacements, Y
    JMP :Anon0008

:ReplaceWithF5
    LDA #$F5
:Anon0008
    STA TriforceRow0TransferBuf+4, X

:NextLoopTile
    ; Bottom of the inner loop.
    ;
    ; Increment the triforce tile slot.
    ; Decrement [07] and loop again, if it's not 0.
    INY
    DEC $07                     ; [07] inner loop counter
    BNE :LoopTile

    ; Bottom of the outer loop.
    ;
    ; Shift the level test bit [06] left to test the next level.
    ; When it becomes 0, we're done.
    ASL $06
    BNE :LoopPiece
    INC MenuState
    RTS

ScrollWorld
    LDA FrameCounter

    ; The purpose of this is to delay vertical scrolling.
    ; OW: once every two frames
    ; UW: once every four frames
    ; Horizontal scrolling happens every frame.
    AND #$03
    LDY CurLevel
    BNE :Anon0009
    AND #$01
:Anon0009
    CMP VScrollStartFrame
    BNE ScrollWorldH
    LDA #$08                    ; If the player is facing up,
    BIT ObjDir
    BEQ ScrollWorldDownOrH

    ; then scroll up.
    ; Scrolling up starts from the top of NT 2 at $2800.
    DEC CurRow
    LDA ObjY                    ; Move the player down 1 tile length if not at edge.
    CMP #$DD
    BCS :Anon0010
    ADC #$08
    STA ObjY
:Anon0010
    LDA VScrollAddrLo           ; Subtract $20 from VScroll address for a row.
    SEC
    SBC #$20
    STA VScrollAddrLo
    BCS :Anon0011
    DEC VScrollAddrHi
:Anon0011
    CMP #$E0
    BNE :Exit                   ; If the result doesn't end in $E0, then return.
    LDA VScrollAddrHi
    CMP #$20
    BEQ :LimitLow               ; If the result is $20E0, then the scroll position reached the status bar. Go sanitize and keep it there.
    CMP #$27
    BNE :Exit                   ; If the result is not $27E0, then return.

    ; VScroll address is $27E0. So, we rolled from the
    ; top of NT 2 to the last row of NT 0. Change the address
    ; to $23A0, the true last row of NT 0.
    LDA #$23
    STA VScrollAddrHi
    LDA #$A0
    STA VScrollAddrLo

:Exit
    RTS

:LimitLow
    ; Don't let the scroll position go above $2100, the bottom of
    ; the status bar; nor below $2800, the top of NT 2.
    INC VScrollAddrHi

ResetVScrollLo
    LDA #$00
    STA VScrollAddrLo

IncSubmode
    INC GameSubmode             ; And we're done.
    RTS

ScrollWorldDownOrH
    LSR                         ; If the player is facing down,
    BIT ObjDir
    BEQ ScrollWorldH

    ; then scroll down.
    INC CurRow
    LDA ObjY                    ; Move the player up 1 tile length, if not at edge.
    CMP #$3E
    BCC :Anon0012
    SBC #$08
    STA ObjY
:Anon0012
    LDA VScrollAddrLo           ; Add $20 to VScroll address for a row.
    CLC
    ADC #$20
    STA VScrollAddrLo
    BCC :Anon0013
    INC VScrollAddrHi
:Anon0013
    CMP #$C0
    BNE L14287_Exit             ; If the result doesn't end in $C0, then return.
    LDA VScrollAddrHi
    CMP #$23
    BNE L14287_Exit             ; If the result is not $23C0, then return.

    ; VScroll address is $23C0, the bottom of NT 0. So, we need
    ; to roll to $2800, the top of NT 2.
    LDA #$28
    STA VScrollAddrHi
    JMP ResetVScrollLo

ScrollWorldH
    LDA #$02                    ; Use the default scroll speed: 2 pixels a frame.
    LDX #$FE
    LDY CurLevel
    BNE :Anon0014
    ASL                         ; Scroll twice as fast if in the overworld.
    LDX #$FC
:Anon0014
    STA $00                     ; [00] holds the speed.
    STX $01                     ; [01] holds the X position where we must start using NT 1.
    LDA #$02                    ; If player does not face left,
    BIT ObjDir
    BEQ ScrollWorldRight        ; then go scroll right.

    ; Scroll left.
    DEC CurColumn
    LDA ObjX                    ; Move player right by [00] if not at edge.
    CMP #$F0
    BCS :Anon0015
    ADC $00
    STA ObjX
:Anon0015
    LDA CurHScroll              ; Update nametable X scroll by speed in [00].
    SEC
    SBC $00
    STA CurHScroll
    BEQ IncSubmode              ; Stop when you've scrolled to the end (CurHScroll=0).
    CMP $01                     ; Does scroll position match reference scroll position [01]?
    BNE L14287_Exit             ; If not, then return.

SwitchToNT1
    ; When we begin scrolling left, CurHScroll = 0 and base
    ; nametable is 0. This shows the current room completely.
    ;
    ; The first time in ScrollWorld, the speed [00] will be
    ; subtracted from CurHScroll to show most of NT 0, and
    ; a little of NT 1 to its left. In other words, the
    ; scroll position now refers to a position in NT 1.
    ;
    ; [01] is this first position shown in NT 1. So, once
    ; CurHScroll matches it (in the first call to this routine),
    ; turn on this flag that makes NT 1 the base nametable.
    LDA #$01
    STA OddBaseNameTableOverride    ; Start basing the horizontal scroll position on NT 1.

L14287_Exit
    RTS

ScrollWorldRight
    LSR
    BIT ObjDir                  ; If the player isn't facing right either,
    BEQ L14287_Exit             ; then quit.
    INC CurColumn
    LDA ObjX
    CMP #$01
    BCC :Anon0016                      ; Move player left by [00] if not at edge.
    SBC $00
    STA ObjX
:Anon0016
    LDA CurHScroll              ; Update nametable X scroll by speed in [00].
    CLC
    ADC $00
    STA CurHScroll
    BNE L14287_Exit             ; If scroll position hasn't reached 0, then return.

    ; Because CurHScroll is now 0 and base nametable is 0;
    ; we would be showing the new room at the end of the scroll
    ; but with old attributes.
    ;
    ; So, now use NT 1, until after we copy the attributes.
    JSR SwitchToNT1
    JMP IncSubmode              ; Go to the next submode.

InitMode7Submodes ENT
    LDA GameSubmode
    JSR TableJump

InitMode7Submodes_JumpTable
            dw    InitMode7_Sub0
            dw    InitMode7_Sub1
            dw    InitMode7_Sub2
            dw    InitMode7_Sub3And4_TransferPlayAreaAttrsToNT2
            dw    InitMode7_Sub3And4_TransferPlayAreaAttrsToNT2
            dw    InitMode7_Sub5
            dw    InitMode7_Sub6

InitMode7_Sub1
    JSR DrawSpritesBetweenRooms
    JSR Link_EndMoveAndAnimateBetweenRooms
    LDA CurOpenedDoors          ; Assign the current opened doors to the previous one.
    STA PrevOpenedDoors

    ; If this doorway Link is entering from is not a true door,
    ; then LayOutDoors called from LayOutRoom will clear it.
    JSR SetEnteringDoorwayAsCurOpenedDoors
    DEC PrevRow                 ; TODO: ?
    INC GameSubmode
    JSR CalculateNextRoom
    LDA NextRoomId

    ; If next room ID is invalid, then return because
    ; something went wrong calculating it.
    ; The mode was changed to load the OW.
    BMI :Exit
    LDA RoomId
    PHA                         ; Save current room ID.
    LDY ObjDir
    CPY #$08

    ; If we're not going up, then temporarily set RoomId to next
    ; room; so we can draw next room in NT 2 below and
    ; subsequent submodes.
    ;
    ; Only in up direction do we draw the current room in NT 2.
    BEQ :Anon0017
    LDA NextRoomId
    STA RoomId
:Anon0017
    JSR FillPlayAreaAttrs
    LDA #$15                    ; Start at bottom row.
    STA CurRow
    LDY ObjDir
    CPY #$08
    BEQ :Anon0018                      ; If going up, then go lay out the only dynamic elements for the current room: the doors.
    JSR LayOutRoom              ; else lay out the next room.

:RestoreRoomId
    PLA                         ; Restore current room ID.
    STA RoomId

:Exit
    RTS
:Anon0018
    JSR LayOutDoorsPrev         ; Here, "previous" means "current", because we already changed TempDoorDirHeldOpen.
    JMP :RestoreRoomId          ; Go restore current room ID and return.

LayOutDoorsPrev
    LDA CurLevel
    BEQ :Anon0019                      ; If in OW, then return.
    LDA CurOpenedDoors
    PHA
    LDA PrevOpenedDoors
    STA CurOpenedDoors
    JSR LayOutDoors
    PLA
    STA CurOpenedDoors
:Anon0019
    RTS

InitMode7_Sub0
    ; If teleporting, then set the room ID to the one that will
    ; make it look like we scrolled to a dungeon entrance.
    LDA WhirlwindTeleportingState
    BEQ :Anon0020
    LDA WhirlwindPrevRoomId
    STA RoomId
:Anon0020
    LDA SecretColorCycle
    BEQ L1433A_IncSubmode       ; If we had no flute secret (pond) or it finished, then go to next submode.
    JMP AnimatePond             ; Go reverse the flute secret (pond colors).

InitMode7_Sub2
    ; This transfers a room's play area tiles to nametable 2.
    ;
    ; CurRow starts at the bottom ($15).
    JSR CopyRowToTileBuf
    LDA DynTileBuf

    ; Change the target nametable from 0 to 2.
    ;
    ; Because there's only a play area and no status bar in
    ; nametable 2, you have to add 7 to the high byte instead of 8.
    ; So, the top of the play area in NT 0 is at $2100.
    ; But the top of the play area in NT 2 is at $2800.
    ;
    ; This assumes that you want to scroll vertically, where the
    ; two scroll areas must be contiguous vertically.
    AND #$0F
    CLC
    ADC #$27
    STA DynTileBuf
    LDA ObjDir
    CMP #$04
    BCS :Anon0021                      ; If the scroll direction is not vertical,

    ; then you DO have to account for the status bar.
    ; So, add $100 (by incrementing high byte) to move
    ; everything down 64 pixels.
    ;
    ; Now the play areas will line up in NT 0 and NT 2 when
    ; we change mirroring to vertical at the end of this mode.
    INC DynTileBuf
:Anon0021
    DEC CurRow
    BPL :Anon0022

L1433A_IncSubmode
    INC GameSubmode
:Anon0022
    RTS

InitMode7_Sub3And4_TransferPlayAreaAttrsToNT2
    ; Transfer half of a room's play area attributes to nametable 2.
    ; The top half in submode 3, and the bottom half in submode 4.
    LDA #$08                    ; Test player's direction for up (8).
    BIT ObjDir
    BNE :Vertical
    LSR                         ; Test player's direction for down (4).
    BIT ObjDir
    BEQ :Horizontal

:Vertical
    ; Scrolling up or down.
    LDA #$C0                    ; This will mean PPU address $2BC0.

:TransferHalfPlayAreaAttrs
    LDY #$17                    ; This is the offset of the end of the first half of play area NT attributes.
    LDX GameSubmode
    CPX #$03
    BEQ :Anon0023                      ; If in submode 4 instead of 3,
    JSR GetPlayAreaAttrsBottomHalfInfo    ; then refer to bottom half of NT attributes.
:Anon0023
    JMP CueTransferPlayAreaAttrsHalfAndAdvanceSubmodeNT2

:Horizontal
    ; Scrolling left or right.
    ; This will mean PPU address $2BD0, 64 pixels down from
    ; the top of NT 2. See submode 2 for an explanation of
    ; offsets and mirroring for vertical scrolling.
    LDA #$D0
    BNE :TransferHalfPlayAreaAttrs    ; Go continue setting up transfer of attributes.

InitMode7_Sub5
    LDA #$00                    ; Reset fade cycle, in case we don't need to fade.
    STA FadeCycle
    LDA ObjDir
    CMP #$04
    BCS :Vertical               ; If direction is horizontal,

    ; then cue transfer of a row of blanks above the play area.
    ; This should lead to clean vertical scrolling without visual
    ; artifacts.
    ;
    ; TODO: But, maybe it doesn't work, because its address
    ; $28E0 is in NT 2, which will become a mirror of NT 0 below
    ; in this submode.
    LDY #$4E
    STY TileBufSelector

:Vertical
    CMP #$08
    BNE :CheckDark

    ; Scrolling up.

    ; Lay out the next room now, because we had to transfer
    ; the current one to NT 2 earlier. Up is the only direction
    ; that draws the current room to NT 2.
    LDA RoomId
    PHA                         ; Save current room ID.
    LDA NextRoomId              ; Lay out the next room.
    STA RoomId
    JSR LayOutRoom
    PLA                         ; Restore current room ID.
    STA RoomId

:CheckDark
    ; Scrolling in any direction.
    LDY NextRoomId
    JSR IsDarkRoom_Bank5
    BEQ InitMode7_Finish        ; If the next room is not dark, then go finish up and start updating.

    ; The next room is dark.
    LDY RoomId
    JSR IsDarkRoom_Bank5
    BNE :CheckIfLit             ; If the current room is dark by default, go see if it was lit up.

:DarkenRoom
    ; Going from room with light to a dark room.
    LDA #$00                    ; The next room will not be lit yet.
    STA CandleState
    LDA #$40                    ; Start a fade-to-black cycle.
    STA FadeCycle
    INC GameSubmode
    RTS

:CheckIfLit
    LDA CandleState
    BNE :DarkenRoom             ; If it was lit, then go start a fade-to-black cycle.

    ; Not lit. Dark to dark. Nothing to do.
    ; Go finish initializing, and begin updating the mode.
    BEQ InitMode7_Finish

InitMode7_Sub6
    JSR AnimateWorldFading
    BNE L143AD_Exit             ; If we're still fading, then return.

InitMode7_Finish
    ; Finish initializing this mode, and start updating it.
    LDA NextRoomId              ; Set current room to next room.
    STA RoomId
    JSR WriteAndEnableSprite0
    JSR BeginUpdateMode

L143AD_Exit
    RTS

Sprite0Descriptor
            db    $27, $61, $20, $58

WriteAndEnableSprite0
    LDA #$01
    STA IsSprite0CheckActive
    LDY #$03
:Anon0024
    LDA Sprite0Descriptor, Y
    STA Sprites, Y
    DEY
    BPL :Anon0024
    RTS

SetEnteringDoorwayAsCurOpenedDoors
    LDA ObjDir                  ; Calculate the opposite of the player's direction.
    LSR
    AND #$05
    STA $00
    LDA ObjDir
    ASL
    AND #$0A
    ORA $00
    STA CurOpenedDoors          ; That is the door the player's entering the new room from.
    RTS

RoomPaletteSelectorToNTAttr
            db    $00, $55, $AA, $FF

; Params:
; A: room ID
;
; Look up room attributes A for the room.
FillPlayAreaAttrs
    TAY
    LDA LevelBlockAttrsA, Y
    AND #$03                    ; Get the outer palette selector from the byte.
    TAX
    LDA RoomPaletteSelectorToNTAttr, X    ; Get the nametable attributes for the palette selector.
    LDX #$2F                    ; Fill the play area NT attributes.
:Anon0025
    STA PlayAreaAttrs, X
    DEX
    BPL :Anon0025
    LDA LevelBlockAttrsB, Y     ; Look up room attributes B for the room.
    AND #$03                    ; Get the inner palette selector.
    TAX

    ; Fill the inner play area NT attributes (offset 9 to $26).
    LDY #$09

:LoopRow
    TYA
    AND #$07                    ; Skip left and right edges.
    BEQ :NextLoopRow
    CMP #$07
    BEQ :NextLoopRow
    CPY #$21                    ; For the bottom inner NT attribute row, go combine the inner and outer attributes.
    BCS :CombineInnerOuter
    LDA RoomPaletteSelectorToNTAttr, X
    STA PlayAreaAttrs, Y

:NextLoopRow
    INY
    CPY #$27
    BCC :LoopRow                ; If we haven't finished the last inner NT attribute row, then go fill more.
    RTS

:CombineInnerOuter
    ; Combine the NT attributes at current offset with the
    ; new ones we're filling; so that new (inner) attributes
    ; affect the top half of the row.
    LDA RoomPaletteSelectorToNTAttr, X
    AND #$0F
    STA $00
    LDA PlayAreaAttrs, Y
    AND #$F0
    ORA $00
    STA PlayAreaAttrs, Y
    JMP :NextLoopRow            ; Go advance the offset and check if we're done.

UpdateMode7SubmodeAndDrawLink ENT
    JSR UpdateMode7ScrollSubmode
    JMP Link_EndMoveAndAnimateBetweenRooms

UpdateMode7ScrollSubmode
    LDA GameSubmode
    JSR TableJump

UpdateMode7ScrollSubmode_JumpTable
            dw    UpdateMode7Scroll_Sub0
            dw    UpdateMode7Scroll_Sub1
            dw    UpdateMode7Scroll_Sub2
            dw    UpdateMode7Scroll_Sub3
            dw    UpdateMode7Scroll_Sub4
            dw    UpdateMode7Scroll_Sub4And5_TransferNTAttrs
            dw    UpdateMode7Scroll_Sub6
            dw    UpdateMode7Scroll_Sub7

UpdateMode7Scroll_Sub0
    LDA #$00
    STA VScrollAddrLo           ; Reset low byte of VScroll address for vertical scrolling.
    STA CurHScroll              ; Reset horizontal scroll offset for horizontal scrolling.
    LDA #$08
    BIT ObjDir
    BNE ScrollUp                ; If scrolling up, go handle it.
    LSR
    BIT ObjDir
    BEQ ScrollHorizontal

    ; Scrolling down.
    LDA #$21                    ; Start scrolling from $2100, the top of play area in NT 0 (current room).
    STA VScrollAddrHi
    LDA #$FF                    ; Start past the first row, because the scrolling process first increments it.
    STA CurRow

Inc2Submodes
    INC GameSubmode             ; From submode 0 go to submode 2.
    INC GameSubmode
    RTS

ScrollHorizontal
    ; Scrolling left or right.
    ;
    ; Keep in mind that columns will not be copied if CurColumn
    ; is not between 1 and $20.
    ;
    ; Set up a starting column number well past the beginning or
    ; end of the play area; so that we don't write to a part of
    ; the scroll region.
    LDY #$A0                    ; $A0 in UW.
    LDX CurLevel
    BNE :Anon0026
    LDY #$E0                    ; $E0 in OW.
:Anon0026
    LSR
    BIT ObjDir
    BEQ :SetColumn

    ; Scrolling left.
    LDY #$81                    ; $81 in UW.
    LDX CurLevel
    BNE :SetColumn
    LDY #$41                    ; $41 in OW.

:SetColumn
    STY CurColumn               ; Set CurColumn to the value we determined.
    JMP Inc2Submodes            ; Go to submode 2.

ScrollUp
    ; Scrolling up.
    LDA #$28                    ; Start scrolling from $2800, the top of play area in NT 2 (current room).
    STA VScrollAddrHi
    LDA #$16                    ; Start past the last row, because the scrolling process first decrements it.
    STA CurRow
    LDA RoomId
    JSR FillPlayAreaAttrs

UpdateMode7Scroll_Sub1
    JSR ChooseAttrSourceAndDestForSubmode
    JMP CueTransferPlayAreaAttrsHalfAndAdvanceSubmodeNT0

ChooseAttrSourceAndDestForSubmode
    ; Results:
    ; A: low PPU address
    ; Y: end offset in PlayAreaAttrs to copy from
    LDA #$D0                    ; Low byte $D0 mean destination PPU address of $23D0, $27D0, $2BD0, or $2FD0.
    LDY #$17                    ; This is the offset of the end of the first half of play area NT attributes.
    LDX GameSubmode
    BEQ :Anon0027                      ; Return.

; Params:
; A: low PPU address
;
; Returns:
; A: low PPU address + $18
; Y: end offset of second half of play area NT attributes
;
GetPlayAreaAttrsBottomHalfInfo
    LDY #$2F                    ; This is the offset of the end of the second half of play area NT attributes.
    CLC
    ADC #$18                    ; Add $18 to point to the bottom half of NT attributes in PPU memory.
:Anon0027
    RTS

UpdateMode7Scroll_Sub2
    ; Calculates a VScrollingStartFrame value that enables
    ; immediate vertical scrolling in the next frame and submode.
    INC GameSubmode
    LDA FrameCounter

    ; Add 1, so that the frame value calculated in the next frame
    ; will match the VScrollingStartFrame value we calculate here.
    CLC
    ADC #$01

    ; Calculate VScrollingStartFrame the same way as the frame
    ; value in the next submode.
    AND #$03
    LDY CurLevel
    BNE :Anon0028
    AND #$01
:Anon0028
    STA VScrollStartFrame
    RTS

UpdateMode7Scroll_Sub3
    JSR ScrollWorld
    JSR CopyColumnOrRowToTileBuf
    LDA GameSubmode
    CMP #$03
    BEQ :Anon0029                      ; If the submode has advanced,
    LDY #$FF                    ; then invalidate current and previous row, and reset the current column.
    STY CurRow
    STY PrevRow
    INY
    STY CurColumn
:Anon0029
    RTS

UpdateMode7Scroll_Sub6
    LDA CurLevel
    BEQ UpdateMode7Scroll_Sub7  ; If in OW, then don't need to handle dark rooms. Go finish up.
    LDY RoomId
    JSR IsDarkRoom_Bank5
    BEQ UpdateMode7Scroll_Sub7  ; If the room isn't dark, then go finish up.

    ; Set CurRow = 0 (was $FF) to signal to mode 4 that
    ; it might need to brighten the new room, because we
    ; scrolled from a dark one.
    ;
    ; This isn't a concern, if you enter a room by any other mode.
    LDA #$00
    STA CurRow
    INC GameSubmode
    RTS

UpdateMode7Scroll_Sub7
    LDA #$01
    STA GameSubmode
    LSR
    STA IsUpdatingMode          ; Reset to initialize the next mode.
    STA $010C                   ; UNKNOWN: [$010C] seems to be a variable that's no longer used.
    STA $E7                     ; UNKNOWN: [E7] seems to be used only for calculating NextRoomId.
    STA IsSprite0CheckActive    ; Reset sprite-0 check, because we finished scrolling.
    LDA #$04                    ; Go to mode 4 submode 1.
    STA GameMode
    RTS

UpdateMode7Scroll_Sub4
    ; Transfer new room's attributes to NT 0.
    LDA #$08
    BIT ObjDir
    BEQ UpdateMode7Scroll_Sub4And5_TransferNTAttrs    ; If not facing up, then go transfer new room attributes to NT 0.
    JMP Inc2Submodes            ; Go to submode 6.

UpdateMode7Scroll_Sub4And5_TransferNTAttrs
    LDA #$D0                    ; This will be PPU address $23D0, attributes for top half of play area in NT 0.
    LDY #$17                    ; Ending offset of first half of attributes.
    LDX GameSubmode
    CPX #$04                    ; If in submode 4,
    BEQ CueTransferPlayAreaAttrsHalfAndAdvanceSubmodeNT0    ; then transfer top half.

    ; Transfer bottom half.
    PHA                         ; Save low byte of PPU address of top of play area attributes.
    LDA ObjDir
    CMP #$04
    BCS :Anon0030                      ; If scrolling horizontally,
    LDA #$00
    STA OddBaseNameTableOverride    ; then don't use NT 1 anymore.
:Anon0030
    PLA                         ; Restore low byte of PPU address of top of play area attributes.
    JSR GetPlayAreaAttrsBottomHalfInfo

; Params:
; A: low PPU address
; Y: end offset in PlayAreaAttrs to copy from
;
CueTransferPlayAreaAttrsHalfAndAdvanceSubmodeNT0
    LDX #$23                    ; High byte of destination PPU address for play area attributes.
    JMP CueTransferPlayAreaAttrsHalfAndAdvanceSubmode

CopyColumnOrRowToTileBuf
    ; Copies a row if CurRow is valid. Otherwise, tries to copy a column.
    ;
    ; If CurRow = PrevRow, does nothing. After a row is copied,
    ; PrevRow is assigned CurRow.
    LDA CurRow                  ; If CurRow is valid, then copy row.
    CMP #$16
    BCS :CheckColumn
    CMP PrevRow                 ; unless CurRow = LastRow, then don't repeat
    BEQ :Exit
    STA PrevRow
    JMP CopyRowToTileBuf

:CheckColumn
    LDA CurColumn               ; If 0 < CurColumn < $21, then copy column.
    BEQ :Exit
    CMP #$21
    BCS :Exit
    JMP CopyColumnToTileBuf

:Exit
    RTS

WaitAndScrollToSplitBottom ENT
            JSR   LDA_2002
    AND #$40
    BEQ WaitAndScrollToSplitBottom
            JSR   LDA_2002

    ; Wait cycles.
    ; TODO: Why do these differ?
    ; (cycle at 8535 - cycle at 852b) = 1005  (see CPU status in debugger)
    ; (multiply instruction timing appropriately) = 1010
    LDY #$03
:Anon0031
    LDX #$30
:Anon0032
    DEX
    BPL :Anon0032
    DEY
    BPL :Anon0031
    NOP                         ; Wait 18 cycles.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    LDA GameMode
    CMP #$08
    BCS :Anon0036
    LDA GameSubmode
    BEQ :Exit                   ; If GameSubmode is 0, then return.
    LDA ObjDir
    CMP #$04
    BCC :Anon0034                     ; TODO: If facing horizontally, then go update scroll registers.

    ; Scrolling vertically, will set PPUADDR instead of PPUSCROLL.
    ; Wait about 666 cycles.
    LDY #$5E
:Anon0033
    NOP
    DEY
    BPL :Anon0033
    NOP                         ; Wait 10 cycles.
    NOP
    NOP
    NOP
    NOP
            JSR   LDA_2002

    ; Set PPUADDR mid-frame to 
    ; achieve split-frame scrolling.
    LDA VScrollAddrHi
    LDY VScrollAddrLo
            JSR   STA_2006
            JSR   STY_2006
            JSR   LDA_2007
            JSR   LDA_2007
    RTS
:Anon0034
    LDY #$5E
:Anon0035
    NOP
    DEY
    BPL :Anon0035
    NOP
    NOP
    NOP
    LDA CurPpuControl_2000
    AND #$FE
    ORA OddBaseNameTableOverride
    STA CurPpuControl_2000
            JSR   STA_2000
    LDA CurHScroll
            JSR   STA_2005
    LDA #$00
            JSR   STA_2005

:Exit
    RTS
:Anon0036
    CMP #$11
    BCS :Anon0037                      ; If GameMode < $11,
    JMP TurnOffAllVideo         ; then turn off video and return.
:Anon0037
    LDA CurPpuControl_2000      ; else change base nametable (0 -> 1 or 2 -> 3).
    ORA #$01
    STA CurPpuControl_2000
            JSR   STA_2000
    RTS

; Unknown block
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF

InitMode8 ENT
    JSR TurnOffAllVideo
    LDA GameSubmode
    BNE :Anon0038
            STA   UndergroundExitType  ; TODO-VERIFY-DP: was forced-absolute (a:) in original
            NOP
    JSR TurnOffVideoAndClearArtifacts
    JSR PatchAndCueLevelPalettesTransferAndAdvanceSubmode
    JMP ClearRoomHistory
:Anon0038
    LDA #$04                    ; Cue the transfer of text and attributes for mode 8.
    STA TileBufSelector
    JMP BeginUpdateMode

InitModeD ENT
    JSR TurnOffVideoAndClearArtifacts
    JSR InitSaveRam

    ; If initialized save RAM, then it wasn't previously
    ; initialized or something went wrong.
    ; So, go reset the game.
    BCS :Anon0039
    JMP BeginUpdateMode
:Anon0039
    JMP IsrReset

InitMode10 ENT
    LDX #$00                    ; Get the tile the player is standing on (on the hotspot).
    JSR GetCollidableTileStill
    CMP #$24
    BNE :Anon0040                      ; If player touched any stairs tile instead of a cave or dungeon entrance, go start updating.
    LDA #$00                    ; TODO: ?
    STA SongEnvelopeSelector
    LDA #$08                    ; Stairs effect
    STA EffectRequest

    ; Set the target Y coordinate $10 pixels below current one.
    LDA ObjY
    CLC
    ADC #$10
    STA StairsTargetY
:Anon0040
    INC IsUpdatingMode
    RTS

SpawnPosListAddrsLo
            db    <SpawnPosList0
            db    <SpawnPosList1
            db    <SpawnPosList2
            db    <SpawnPosList3

SpawnPosListAddrsHi
            db    >SpawnPosList0
            db    >SpawnPosList1
            db    >SpawnPosList2
            db    >SpawnPosList3

SpawnPosList0
            db    $55, $B5, $78, $98, $7A, $9A, $6C, $AC
            db    $8D

SpawnPosList1
            db    $82, $63, $A3, $75, $95, $77, $97, $5A
            db    $BA

SpawnPosList2
            db    $A3, $75, $B5, $96, $87, $99, $7A, $BA
            db    $AC

SpawnPosList3
            db    $63, $55, $95, $76, $88, $79, $5A, $9A
            db    $6C

EnteringRoomRelativePositions
            db    $18, $E8, $28, $D8

ObjLists
            putbin dat/ObjLists.dat

ObjListAddrs
            use   dat/ObjListAddrs.inc

InitMode4 ENT
    LDX GameSubmode
    BEQ InitMode_EnterRoom      ; If in submode 0, go perform common tasks to enter a room.
    DEX
    BNE :CheckSub2

    ; Submode 1.
    ; Copies the whole play area to NT 0, one row each frame.
    ;
    ; TODO:
    ; If mode 7 scrolls to a dark room, then it sets
    ; CurRow to zero. Otherwise it would be $FF.
    ; A positive value triggers this submode 1 to transfer
    ; the whole play area.
    ;
    ; But why? As far as I can tell, the NT 0 is already in
    ; a good state reflecting the new room. The only thing
    ; needed is possibly to brighten the room by way of
    ; changing the palette.
    ;
    ; So why does mode 7 trigger this?
    ; Is there another mode that truly needs this behavior?
    LDA CurRow
    BMI :Anon0041                      ; If CurRow is negative, then go to the next submode.
    JSR CopyNextRowToTransferBuf
    BCC :Exit                   ; If the last row has been copied,
:Anon0041
    INC GameSubmode             ; then go to the next submode.

:Exit
    RTS

:CheckSub2
    DEX
    BNE InitMode4_Sub3

    ; Submode 2.
    LDY RoomId
    JSR IsDarkRoom_Bank5
    BNE InitMode4_GoToSub0      ; If this room is dark, then nothing else to do. Go to submode 0.

    ; This is a light room.
    ; See if we have to brighten it after leaving a dark room.
    LDA ObjDir
    JSR CalcNextRoomByDir

    ; Subtract RoomId from next room ID that was calculated
    ; to get room ID offset in that direction.
    SEC
    SBC RoomId
    JSR Negate                  ; We really want the opposite offset/direction.
    CLC                         ; Add the current room ID to that to get the previous room ID.
    ADC RoomId
    TAY
    JSR IsDarkRoom_Bank5
    BEQ InitMode4_GoToSub0      ; If previous room was light, then go to submode 0.

    ; The previous room was dark.
    LDA CandleState
    BNE InitMode4_GoToSub0      ; But if it was lit up, then nothing else to do. Go to submode 0.
    LDA #$C0                    ; Start a fade-to-light cycle (reverse of cycle $40).

; Params:
; A: start index of cycle
;
SetFadeCycleAndAdvanceSubmode
    STA FadeCycle
    INC GameSubmode
:Anon0042
    RTS

InitMode4_Sub3
    ; Submode 3.
    JSR AnimateWorldFading
    BNE :Anon0042                      ; If not done animating, then return.

InitMode4_GoToSub0
    LDA #$00
    STA GameSubmode
    STA CandleState
    RTS

; Description:
; Clears intraroom data.
; Set up Link to walk into a room.
; Decodes and lays out objects.
; Switches from initializing the game mode to updating it.
;
; This is called for modes 4, 9, $B, $C.
;
InitMode_EnterRoom ENT
    JSR DrawSpritesBetweenRooms
    JSR ResetPlayerState

    ; Reset [0300] to [051F].
    LDA #$05
    LDY #$1F
    JSR ClearRam0300UpTo

    ; Reset door trigger info.
    LDA #$00
    STA TriggeredDoorCmd
    STA TriggeredDoorDir

    ; Store level block attribute byte F for convenience.
    LDY RoomId
    LDA LevelBlockAttrsF, Y
    STA LevelBlockAttrsByteF
    JSR ResetInvObjState

    ; There's more than one way to enter a room.
    ;
    ; 1: Out of a cave, dungeon, or cellar
    ;     a. Walking exit
    ;     b. Next to stairs
    ; 2: Room to room
    ;
    ; Determine which one we need.
    LDA UndergroundExitType
    BEQ :Method2                ; If not leaving underground, go handle method 2.
    LDA CurLevel
    BNE :Anon0043                      ; If in UW and stepping out of cellar, Link is already where he needs to be. But go handle the rest (method 1-b).

    ; Enter method 1.
    ;
    ; Set up Link's exit from underground.
    LDY RoomId
    LDA LevelBlockAttrsA, Y
    AND #$F0                    ; X coordinate where link comes out of underground
    STA ObjX
    LDA LevelBlockAttrsF, Y
    AND #$07                    ; Square row where Link comes out of underground, starting from square row 1. See the addition below.
    ASL                         ; Multiply by $10 to get a height in pixels.
    ASL
    ASL
    ASL

    ; Add the first Y where Link can come out of underground.
    ; $4D is $50 (the second square row) - 3 (Link's offset above the row).
    ADC #$4D
    STA ObjY

    ; If the player didn't step on a cave entrance to go underground,
    ; then he used the stairs. So, skip starting the exit effect (method 1-b).
    LDY UndergroundEntranceTile
    CPY #$24                    ; $24 is black entrance, and contrasts with $70 to $73 (stairs).
    BNE :Anon0043

    ; Enter method 1-a.
    ;
    ; Store the Y coordinate that we determined as the Target Y.
    STA StairsTargetY
    CLC
    ADC #$10
    STA ObjY                    ; But have Link start walking out from $10 pixels below.
    LDA #$08                    ; Play walking sound effect.
    STA EffectRequest
:Anon0043
    ; This part is the same no matter if the player went
    ; underground by stairs or a cave entrance.
    LDA #$04
    STA ObjDir                  ; Link faces down when coming out of a cave or dungeon.
    LDA #$00
    STA DoorwayDir              ; Reset DoorwayDir, assuming there is no doorway.
    JMP :PlaceObjects           ; Go reset Link's relative position, and work on objects.

:Method2
    ; Enter method 2.
    ; Room to room.
    ;
    ; Get the direction that the player is entering from.
    LDA ObjDir
    STA DoorwayDir              ; The player entered the doorway in a room. So, set DoorwayDir.
    JSR GetOppositeDir

    ; If the player is entering from a door that was opened, then
    ; set the "close" door command.
    AND CurOpenedDoors
    STA TriggeredDoorDir
    BEQ :Anon0044
    LDA #$02
    STA TriggeredDoorCmd
:Anon0044
    ; If in OW, go reset Link's relative position, and work on objects.
    LDA CurLevel
    BEQ :PlaceObjects

    ; If facing right, then set Link's X to 0 at the left edge.
    ; If direction is left, then set Link's X to $F0 at the right edge.
    LDY #$00
    LDA ObjDir
    AND #$03
    BEQ :ChooseWalkDistance
    AND #$01
    BNE :Anon0045
    LDY #$F0
:Anon0045
    STY ObjX

:ChooseWalkDistance
    ; Choose a distance to walk depending on the door you
    ; come out of.
    ;
    ; We'll get a 0 or 1 depending on the direction of the door.
    ;
    ; If the attribute of the door is "open", "key", or "key 2";
    ; then you have shorter distance to cover. So use the
    ; previous value as is to use indexes 0 and 1.
    ;
    ; Otherwise, add 2 to use indexes 2 and 3 to walk farther
    ; to get out of the way of the wall or door.
    JSR GetPassedDoorType
    AND #$07
    BEQ :Anon0046
    CMP #$05
    BEQ :Anon0046
    CMP #$06
    BEQ :Anon0046
    INY
    INY
:Anon0046
    LDA EnteringRoomRelativePositions, Y

:PlaceObjects
    STA ObjGridOffset
    JSR SetupObjRoomBounds

    ; Set current object slot variable to $B, to be ready for the
    ; first frame of mode 5. So, that it begins updating objects
    ; at slot $B.
    LDX #$0B
    STX CurObjIndex
:Anon0047
    ; Reset common state of objects $B to 1.
    DEC ObjUninitialized, X
    JSR ResetShoveInfo
    STA ObjState, X
    STA ObjDir, X
    STA ObjStunTimer, X
    INC ObjAnimCounter, X
    INC ObjMetastate, X         ; By default, objects start in metastate 1 (first cloud state).
    LDA #$20                    ; Set the default speed.
    STA ObjQSpeedFrac, X
    DEX
    BNE :Anon0047

    ; Put the monster list ID in [02].
    LDY RoomId
    LDA LevelBlockAttrsC, Y
    PHA
    AND #$3F                    ; Low 6 bits of monster list ID
    STA $02
    LDA LevelBlockAttrsD, Y
    ASL                         ; High bit of monster list ID
    BCC :Anon0048                      ; If high bit is set in attribute byte D,
    LDA $02                     ; Then set bit 6 of monster list ID.
    CLC
    ADC #$40
    STA $02
:Anon0048
    PLA

    ; Get index of monster count from high 2 bits of attribute byte C.
    AND #$C0
    CLC
    ROL
    ROL
    ROL
    TAY

    ; Get the object count from level info.
    LDA LevelInfo_FoeCounts, Y

    ; But make the count 1, if  the object list ID >= $32 and < $62.
    ; This includes bosses and other non-recurring objects.
    LDY $02
    CPY #$62
    BCS :Anon0049
    CPY #$32
    BCC :Anon0049
    LDA #$01
:Anon0049
    STA $03                     ; Put the count in [03].

    ; Use the room history to modify the number of objects to make.
    LDA CurLevel
    BNE :Anon0050
    JSR ModifyObjCountByHistoryOW
    JMP :StoreObjCount
:Anon0050
    JSR ModifyObjCountByHistoryUW

    ; If in mode 9 (most caves), then
    ; reset object count and object list ID.
    LDA GameMode
    CMP #$09
    BNE :StoreObjCount
    LDA #$00
    STA $02
    STA $03

:StoreObjCount
    LDA $03                     ; Store the object count.
    STA RoomObjCount

    ; If object count = 0 or object list ID = 0, then
    ; skip instantiating objects.
    BEQ :SkipObjects
    LDA $02
    BEQ :SkipObjects

    ; If object list ID / object template ID >= $62,
    ; then it refers to a list. Go handle it.
    CMP #$62
    BCS :PlaceList

    ; Object list ID / object template ID refers to a
    ; repeated object.
    ;
    ; Set the object type at each element from 1 to Object Count
    ; to object template ID.
    LDX #$00
:Anon0051
    LDA $02
    STA ObjType+1, X
    INX
    DEC $03
    BNE :Anon0051
    JMP :StoreObjTemplate

:PlaceList
    ; Object list ID / object template ID truly refers to a list of object types.
    ;
    ; Get the index of the list itself by subtracting $62.
    LDA $02
    SEC
    SBC #$62

    ; Put the address of the list in [04:05].
    ASL
    TAY
    LDA ObjListAddrs, Y
    STA $04
    INY
    LDA ObjListAddrs, Y
    STA $05

    ; Copy elements from the list to ObjType up to object count [03].
    LDY #$00
:Anon0052
    LDA ($04), Y
    STA ObjType+1, Y
    INY
    CPY $03
    BNE :Anon0052

:StoreObjTemplate
    ; Remember the object template type.
    LDA ObjType+1
    STA RoomObjTemplateType

:SkipObjects
    JSR AssignObjSpawnPositions
    LDA CurLevel
    BNE :Anon0053
    JSR SetupTileObjectOW
:Anon0053
    JSR UpdatePlayerPositionMarker
    LDA #$00
    STA ObjStunTimer
    STA ObjShoveDir
    STA ObjShoveDistance
    LDA #$04
    STA ObjAnimCounter
    JSR InitLinkSpeed
    JSR RunCrossRoomTasksAndBeginUpdateMode_EnterPlayModes

DrawLinkBetweenRooms ENT
    JSR ResetCurSpriteIndex
    LDA GameMode                ; If mode is not $B nor $C (caves),
    CMP #$0B
    BEQ :Anon0054
    CMP #$0C
    BEQ :Anon0054
    JSR Link_EndMoveAndAnimateBetweenRooms
:Anon0054
    LDA UndergroundExitType
    BEQ :Anon0055                      ; If coming out of a cave or dungeon, then ...
    JSR PutLinkBehindBackground
:Anon0055
    RTS

SetupTileObjectOW
    ; If this is a room with a dock ($3F and $55), then
    ; set the dock object type ($61) in tile object slot ($B).
    LDA RoomId
    CMP #$3F
    BEQ :Anon0056
    CMP #$55
    BNE :PlaceTileObj
:Anon0056
    LDA #$61
    JMP :SetType

:PlaceTileObj
    ; There's no dock here, but there might be a tile object that
    ; we found while laying out the room. Set the type, X, and Y
    ; to the details we determined.
    LDA RoomTileObjX
    STA ObjX+11
    LDA RoomTileObjY
    STA ObjY+11
    LDA RoomTileObjType

:SetType
    STA ObjType+11
    JSR ResetRoomTileObjInfo
    STA ObjState+11             ; Activate room tile object.
    RTS

CellarKeeseXs
            db    $20, $60, $90, $D0

CellarKeeseYs
            db    $9D, $5D, $7D, $9D

; Params:
; [02]: object template ID
;
AssignObjSpawnPositions
    LDY RoomObjCount

    ; If object template type = 0 or refers to Zelda, then
    ; skip spawning normal objects.
    LDA $02
    BEQ :AssignSpecialPositions
    CMP #$37
    BEQ :AssignSpecialPositions

    ; If in OW, then see if monsters come in from the edges of the screen.
    LDA CurLevel
    BNE :Anon0057
    LDA LevelBlockAttrsByteF
    AND #$08                    ; Monsters from the edges of the screen
    BNE :AssignSpecialPositions ; If monsters come in from the edges, go skip spawning normal objects.
:Anon0057
    LDA RoomObjCount
    BEQ :AssignSpecialPositions ; If object count = 0, go skip spawning normal objects.

    ; Get the direction from Link's direction (bit).
    LDA ObjDir
    LDY #$FF
:Anon0058
    INY
    LSR
    BCC :Anon0058

    ; Put the address of the spawn list for Link's direction in [06:07].
    LDA SpawnPosListAddrsLo, Y
    STA $06
    LDA SpawnPosListAddrsHi, Y
    STA $07

    ; Assign spawn coordinates to 9 object slots.
    LDY SpawnCycle
    LDX #$01                    ; Starting at object 1.

:LoopSpawnSpot
    LDA ($06), Y                ; Get a spawn spot from the list.
    PHA
    ASL                         ; Turn the column component into an X coordinate.
    ASL
    ASL
    ASL
    STA ObjX, X
    PLA                         ; Turn the row component into a Y coordinate.
    AND #$F0
    ORA #$0D                    ; Add $D to the Y coordinate.
    STA ObjY, X
    JSR IsSafeToSpawn
    BCS :Anon0059
    INX                         ; Point to the next object.
:Anon0059
    INY                         ; Point to the next spawn spot.
    CPY #$09
    BCC :Anon0060                      ; If we went past the last spawn spot,
    LDY #$00                    ; then reset the cycle.
:Anon0060
    CPX #$0A
    BCC :LoopSpawnSpot
    STY SpawnCycle

:AssignSpecialPositions
    ; If in mode 9 (play cellar), then spawn 4 blue keeses.
    LDA GameMode
    CMP #$09
    BNE :CheckCaves             ; If not in mode 9, go check caves.
    LDX #$03
:Anon0061
    LDA #$1B                    ; Blue Keese
    STA ObjType+1, X
    LDA CellarKeeseXs, X
    STA ObjX+1, X
    LDA CellarKeeseYs, Y
    STA ObjY+1, X
    DEX
    BPL :Anon0061
    RTS

:CheckCaves
    ; If the mode is not $B nor $C (caves), then return.
    CMP #$0B
    BEQ :InCave
    CMP #$0C
    BNE :Exit

:InCave
    ; We're in a cave.
    ; Reset object types in slots 1 to 8.
    LDX #$07
    LDA #$00
:Anon0062
    STA ObjType+1, X
    DEX
    BPL :Anon0062

    ; cave index = ((cave value) >> 2) - $10
    LDY RoomId
    LDA LevelBlockAttrsB, Y
    AND #$FC                    ; Cave
    SEC
    SBC #$40
    LSR
    LSR

    ; cave dweller object type = $6A + (cave index)
    CLC
    ADC #$6A
    STA ObjType+1               ; Replace first non-Link object type with the cave dweller type.

:Exit
    RTS

; Params:
; X: object index
;
; Returns:
; C: 1 if unwalkable
;
IsSafeToSpawn
    TYA                         ; Save %Y.
    PHA
    JSR GetCollidableTileStill
    PLA                         ; Restore %Y.
    TAY
    LDA ObjCollidedTile, X
    CMP ObjectFirstUnwalkableTile
    BCS ReturnUnsafeToSpawn     ; If the tile at the object's hotspot is unwalkable, return unwalkable.

; Params:
; X: object index
;
; Returns:
; C: 1 if unwalkable
;
IsDistanceSafeToSpawn ENT
    ; Get the absolute X distance to Link.
    LDA ObjX
    SEC
    SBC ObjX, X
    JSR Abs
    CMP #$22
    BCS :Anon0063                      ; If distance > $22, return walkable.

    ; Get the absolute Y distance to Link.
    LDA ObjY
    SEC
    SBC ObjY, X
    JSR Abs
    CMP #$22
    BCC ReturnUnsafeToSpawn     ; If distance < $22, go return unwalkable.
:Anon0063
    CLC                         ; Walkable
    RTS

ReturnUnsafeToSpawn
    SEC                         ; Unwalkable
    RTS

InitMode11 ENT
    LDX #$00                    ; Decrease Link's invincibility timer. This is needed in submode 1.
    JSR DecrementInvincibilityTimer
    JSR Link_EndMoveAndAnimate
    LDA GameSubmode
    BNE InitMode11_Sub1         ; Go handle submode 1.

    ; Submode 0.
    JSR HideAllSprites
    JSR UpdateTriforcePositionMarker
    JSR DrawLinkBetweenRooms
    JSR DrawStatusBarItemsAndEnsureItemSelected
    JSR MaskCurPpuMaskGrayscale
    LDA #$00
    STA Paused
    STA HeartPartial
    JSR FormatStatusBarText
    INC GameSubmode
    LDA #$10                    ; Set the invincibility timer, so that Link will flash for a fixed amount of time.
    STA ObjInvincibilityTimer

    ; Invincibility timers count down every 2 frames, while
    ; object timers count every frame. So, these 2 timers measure
    ; about the same amount of time.
    LDA #$21
    STA ObjTimer
    RTS

InitMode11_Sub1
    LDA ObjTimer
    BNE L14A96_Exit             ; If ObjTimer hasn't expired, then return.
    JSR GetUniqueRoomId
    AND #$3E
    CMP #$3E
    BEQ :Anon0064                      ; If not in a cellar (unique room ID's $3E and $3F),
    LDA CurOpenedDoors          ; then lay out the doors again. But this seems redundant.
    STA PrevOpenedDoors
    JSR LayOutDoorsPrev
:Anon0064
    LDA #$60                    ; DeathPaletteCycle
    STA FadeCycle
    LDA #$02                    ; Set a timer. But no one waits for it?
    STA ObjTimer+10
    LDA #$00                    ; Reset submode, CurRow, and player's state.
    STA GameSubmode
    STA CurRow
    STA ObjState
    LDA #$04                    ; There will be 4 turns starting from down direction.
    STA DeathModeCounter
    STA ObjDir
    INC IsUpdatingMode          ; Start updating.

SilenceSound
    LDA #$80
    STA Tune0Request
    STA EffectRequest

L14A96_Exit
    RTS

; Params:
; X: door direction index
;
; Returns:
; Y: room ID
; [00:01]: address of level block world flags
;
SetDoorFlag
    JSR GetRoomFlags
    ORA LevelMasks, X
    STA ($00), Y
    RTS

; Params:
; X: door direction index
;
; Returns:
; Y: room ID
; [00:01]: address of level block world flags
;
ResetDoorFlag
    JSR GetRoomFlags
    LDA LevelMasks, X
    EOR #$FF
    AND ($00), Y
    STA ($00), Y
    RTS

CheckShutters ENT
    ;
    ;
    ; If the shutters have not been triggered to open, return.
    LDA ShutterTrigger
    BEQ :Anon0065

    ; Loop to look for an unopened shutter.
    ; The loop variable is a direction bit in [0E], starting with up (8).
    LDA #$08
    STA $0E

:LoopOpenedDoorBit
    ; If the door for the direction bit is not opened, go see if it's a shutter.
    LDA $0E
    AND CurOpenedDoors
    BEQ :TriggerIfShutter

:NextLoopOpenedDoorBit
    ; This door was opened. Shift the direction bit right.
    ; Loop until direction bit = 0.
    LSR $0E
    LDA $0E
    BNE :LoopOpenedDoorBit
:Anon0065
    ; If there were no unopened shutters, then turn off the shutter trigger.
    LDA #$00
    STA ShutterTrigger
    RTS

:TriggerIfShutter
    ; Pass the direction bit as an argument to get the door type.
    LDA $0E
    STA $02
    JSR FindDoorTypeByDoorBit

    ; If it's not a shutter, go loop again.
    CMP #$07
    BNE :NextLoopOpenedDoorBit

    ; If there's already a triggered door command, quit.
            LDA   TriggeredDoorCmd  ; TODO-VERIFY-DP: was forced-absolute (a:) in original
            NOP
    BNE :Anon0066

    ; Else set a command to open the door in this direction.
    LDA $02

; Params:
; A: direction
;
TriggerOpenDoor
            STA   TriggeredDoorDir  ; TODO-VERIFY-DP: was forced-absolute (a:) in original
            NOP
    LDA #$06                    ; Open door command
            STA   TriggeredDoorCmd  ; TODO-VERIFY-DP: was forced-absolute (a:) in original
            NOP
:Anon0066
    RTS

Mode8BaseSpriteValues
            db    $F3, $02, $40

Mode8SpriteYs
            db    $4F, $67, $7F

Mode8SelectionToMode
            db    $03, $0D, $00

Mode8FlashTransferRecord
            db    $23, $D2, $43, $00, $FF

Mode8FlashAttrsAddrLo
            db    $D2, $DA, $E2

UpdateMode8ContinueQuestion_Full ENT
    LDA GameSubmode
    ASL

    ; If the flag is set in submode, then go animate and
    ; handle the selection.
    BCS :AnimateSelection
    LDA ButtonsPressed
    AND #$10
    BNE :ActivateOption         ; If Start is pressed, go handle it.
    LDA ButtonsPressed
    AND #$20
    BEQ :DrawCursor             ; If Select was pressed,
    LDA #$01                    ; Play a short sound for it (same as rupee taken).
    STA Tune0Request

    ; The selection is tracked by the submode.
    ; Increase it. Wrap around, if needed.
    INC GameSubmode
    LDA GameSubmode
    CMP #$03
    BNE :DrawCursor
    LDA #$00
    STA GameSubmode

:DrawCursor
    LDY #$02                    ; Set tile, attributes, and X for selection sprite (0).
:Anon0067
    LDA Mode8BaseSpriteValues, Y
    STA Sprites+1, Y
    DEY
    BPL :Anon0067

    ; Set Y for selection sprite.
    LDY GameSubmode
    LDA Mode8SpriteYs, Y
    STA Sprites
    RTS

:ActivateOption
    LDA GameSubmode             ; Show in the submode that Start was pressed by setting high bit.
    ORA #$80
    STA GameSubmode
    LDA #$40                    ; Flash the selection for $40 frames.
    STA ObjTimer+1
    RTS

:AnimateSelection
    LDA ObjTimer+1
    BEQ :HandleActivated        ; When the timer expires, go handle the selection.

    ; Copy to dynamic tile buf the transfer record
    ; for flashing NT attributes.
    LDY #$04
:Anon0068
    LDA Mode8FlashTransferRecord, Y
    STA DynTileBuf, Y
    DEY
    BPL :Anon0068

    ; Patch the transfer record to write the low byte of the
    ; appropriate address of the attributes depending on
    ; the selection.
    LDA GameSubmode
    AND #$03
    TAY
    LDA Mode8FlashAttrsAddrLo, Y
    STA DynTileBuf+1

    ; Every 4 frames, depending on ObjTimer,
    ; change the NT attribute byte to another palette.
    LDY #$00
    LDA ObjTimer+1
    AND #$04
    BEQ :Anon0069
    LDY #$55
:Anon0069
    STY DynTileBuf+3
    RTS

:HandleActivated
    LDA GameSubmode             ; Mask the submode, so that it only holds the selection.
    AND #$03
    STA GameSubmode
    JSR ResetPlayerState

    ; Set the next game mode according to the selection.
    ; 3: Continue
    ; D: Save
    ; 0: Retry
    LDY GameSubmode
    LDA Mode8SelectionToMode, Y
    STA GameMode
    LDA HeartValues             ; Make the player start again with 3 full hearts.
    AND #$F0
    ORA #$02
    STA HeartValues
    LDA #$FF
    STA HeartPartial
    JSR EndGameMode
    CPY #$02                    ; If player chose Retry,
    BNE :Anon0070
    DEY
    STY GameSubmode             ; Start the next mode in submode 1 and updating.
    INC IsUpdatingMode
:Anon0070
    JMP SilenceAllSound

UpdateMode10Stairs_Full ENT
    LDA ObjCollidedTile
    CMP #$24
    BNE :Anon0071                      ; If player touched a stairs tile instead of a cave or dungeon entrance, go end the mode without animating Link.

    ; Update the position once every 4 frames.
    LDA FrameCounter
    AND #$03
    BNE AnimateAndDrawLinkBehindBackground    ; If it's not time to change position, go draw.
    INC ObjY                    ; Move Link down 1 pixel.
    LDA ObjY
    CMP StairsTargetY
    BNE AnimateAndDrawLinkBehindBackground    ; If Link hasn't reached the end of the walk, go draw.
:Anon0071
    LDA TargetMode              ; Else go to the target mode.
    STA GameMode
    JSR EndGameMode

AnimateAndDrawLinkBehindBackground ENT
    JSR Link_EndMoveAndAnimate

PutLinkBehindBackground
    LDA Sprites+74              ; Change priority of Link sprites $12 and $13 to show them behind the background.
    ORA #$20
    STA Sprites+74
    LDA Sprites+78
    ORA #$20
    STA Sprites+78
    RTS

CheckUnderworldSecrets ENT
    JSR CheckHasLivingMonsters

    ; If there's no secret in this room, return.
    LDA LevelBlockAttrsByteF
    AND #$07                    ; Secret trigger
    BEQ CheckSecretTriggerNone

    ; If the secret was not triggered, return.
    JSR CheckSecretTrigger
    BCC CheckSecretTriggerNone

    ; If the secret is not "foes for an item", then we're done.
    LDA LevelBlockAttrsByteF
    AND #$07                    ; Secret trigger
    CMP #$07
    BNE CheckSecretTriggerNone

    ; If the room item was already activated, or the item was
    ; already taken, then return.
    LDA ObjState+19
    BEQ CheckSecretTriggerNone
    JSR GetRoomFlagUWItemState
    BNE CheckSecretTriggerNone

    ; Else activate the room item, and play the "item appears" tune.
    LDA #$00
    STA ObjState+19
    LDA #$02
    STA Tune1Request

CheckSecretTriggerNone
    RTS

; Returns:
; C: 1 if the condition for the secret was met
;
CheckSecretTrigger
    JSR TableJump

CheckSecretTrigger_JumpTable
            dw    CheckSecretTriggerNone
            dw    CheckSecretTriggerAllDead
            dw    CheckSecretTriggerRingleader
            dw    CheckSecretTriggerLastBoss
            dw    CheckSecretTriggerBlockDoor
            dw    CheckSecretTriggerBlockStairs
            dw    CheckSecretTriggerMoneyOrLife
            dw    CheckSecretTriggerAllDead

CheckHasLivingMonsters
    ; Look for monsters in slots $C to 1 that are not bubbles.
    ; If one is found, return.
    ;
    ; Else flag Link not paralyzed (to cancel the effects of a like-like),
    ; and set the all-dead-in-room flag.
    LDY CurObjIndex

:Loop
    LDA ObjType+1, Y
    BEQ :Next
    CMP #$2B
    BCC :Exit
    CMP #$2E
    BCC :Next
    CMP #$49
    BCC :Exit

:Next
    DEY
    BPL :Loop
    LDA #$00
    STA LinkParalyzed
    INC RoomAllDead

:Exit
    RTS

CheckSecretTriggerAllDead
    ; If there are still monsters, not counting bubbles, then return C=0.
    LDA RoomAllDead
    BEQ ReturnFalse

TriggerShutters
    ; No monsters are left. Trigger shutters to open, and return C=1.
    LDA #$01
    STA ShutterTrigger
    SEC
    RTS

ReturnFalse
    CLC
    RTS

CheckSecretTriggerRingleader
    ; If the first monster slot is empty, go kill all monsters.
    LDA ObjType+1
    BEQ :KillMonsters

    ; If the first monster slot has an object other than a monster,
    ; then return C=0.
    CMP #$53
    BCC ReturnFalse

:KillMonsters
    ; For each object slot from $C to 1:
    ;
    ; If the slot is empty, or has something not a monster, or is
    ; already dying; then go loop again.
    LDY CurObjIndex

:Loop
    LDA ObjType+1, Y
    BEQ :Next
    CMP #$53
    BCS :Next
    LDA ObjMetastate+1, Y
    BNE :Next

    ; Set the object's metastate to die.
    LDA #$10
    STA ObjMetastate+1, Y

:Next
    DEY
    BPL :Loop

    ; Return C=1.
    SEC
    RTS

CheckSecretTriggerBlockDoor
    ; If the block has not been pushed completely, then return C=0.
    LDA BlockPushComplete
    BEQ ReturnFalse

    ; Else go trigger shutters to open, and return C=1.
    BNE TriggerShutters

CheckSecretTriggerBlockStairs
    ; If the block has not been pushed completely, then return C=0.
    LDA BlockPushComplete
    BEQ ReturnFalse

    ; If BlockPushComplete = 2, then it was pushed, and we already
    ; took action for the secret. So, return C=0.
    LSR
    BCC ReturnFalse

    ; Else BlockPushComplete = 1. It was pushed, but this is the
    ; first time checking it for a secret. Make it 2.
    INC BlockPushComplete
    LDX #$0B                    ; Tile object slot

    ; Stairs in UW always go at ($D0, $60).
    LDA #$D0
    STA ObjX, X
    LDA #$60
    STA ObjY, X
    LDA #$70                    ; Stairs tile
    JSR ChangeTileObjTiles

    ; Return C=1.
    SEC
    RTS

CheckSecretTriggerLastBoss
    ; If the last boss was defeated, then
    ; go trigger shutters to open, and return C=1.
    LDA LastBossDefeated
    BNE TriggerShutters

    ; Else return C=0.
    CLC
    RTS

CheckSecretTriggerMoneyOrLife
    ; If the money-or-life man is gone, then
    ; go trigger shutters to open, and return C=1.
    LDA ObjType+1
    BEQ TriggerShutters

    ; Else return C=0.
    CLC
    RTS

UpdateMode11Death_Full ENT
    LDA GameSubmode
    JSR TableJump

UpdateMode11Death_Full_JumpTable
            dw    UpdateMode11Death_Sub0
            dw    UpdateMode11Death_Sub1
            dw    UpdateMode11Death_Sub2
            dw    UpdateMode11Death_Sub3
            dw    UpdateMode11Death_Sub4
            dw    UpdateMode11Death_Sub5
            dw    UpdateMode11Death_Sub6
            dw    UpdateMode11Death_Sub7
            dw    UpdateMode11Death_Sub8_AnimateFade
            dw    UpdateMode11Death_Sub9
            dw    UpdateMode11Death_SubA
            dw    UpdateMode11Death_SubB
            dw    UpdateMode11Death_SubC

UpdateMode11Death_Sub1
    ; Submode 1 prepares bottom half of play area attributes.
    ;
    ; Play death tune.
    LDA #$80
    STA Tune1Request

UpdateMode11Death_Sub0
    ; Submode 0 prepares top half of play area attributes.
    JSR ChooseAttrSourceAndDestForSubmode

; Params:
; A: low PPU address
; Y: end offset in PlayAreaAttrs to copy from
;
CueTransferPlayAreaAttrsHalfAndAdvanceSubmodeNT2
    LDX #$2B                    ; Use nametable 2.

; Params:
; X: high PPU address
; A: low PPU address
; Y: end offset in PlayAreaAttrs to copy from
;
CueTransferPlayAreaAttrsHalfAndAdvanceSubmode
    JSR CopyPlayAreaAttrsHalfToDynTransferBuf
    INC GameSubmode
    RTS

UpdateMode11Death_Sub2
    ; Updates all play area tiles.
    JSR CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone
    BCC :Anon0072
    JSR WriteAndEnableSprite0
:Anon0072
    LDA DynTileBuf              ; Modify the transfer record, so that it changes nametable 2.
    CLC
    ADC #$08
    STA DynTileBuf
    RTS

UpdateMode11Death_Sub3
    LDA #$60                    ; Cue transfer of top half of play area attributes.

SelectTransferBufAndAdvanceSubmode
    JMP L1712E_SelectTransferBufAndAdvanceSubmode

UpdateMode11Death_Sub4
    LDA #$62                    ; Cue transfer of bottom half of play area attributes.
    JMP SelectTransferBufAndAdvanceSubmode    ; Go set this TileBufSelector value, and advance submode.

UpdateMode11Death_Sub5
    LDA #$00
    STA IsSprite0CheckActive
    LDA #$5E                    ; Cue transfer of bottom half of background palette for this mode.
    JMP SelectTransferBufAndAdvanceSubmode    ; Go set this TileBufSelector value, and advance submode.

UpdateMode11Death_Sub6
    LDA CurPpuControl_2000
    AND #$FE                    ; Make sure we're using an even nametable number.
    STA CurPpuControl_2000

L14CD7_IncSubmode
    INC GameSubmode
    RTS

UpdateMode11Death_Sub7
    LDA DeathModeCounter
    BEQ L14CD7_IncSubmode       ; Once Link has turned enough times, go to the next submode.
    LDA ObjTimer+11
    BNE :DrawLink               ; If timer hasn't expired, only redraw sprites.
    LDA #$05                    ; Once ObjTimer[11] expires, arm it again, and change direction.
    STA ObjTimer+11
    LDA ObjDir
    LSR
    LSR
    BCC :CheckOtherDirs         ; If not left, then go check other directions.

    ; Facing left.
    DEC DeathModeCounter
    LDA #$04                    ; Face the next direction (down).

:SetLinkDirAndDraw
    STA ObjDir

:DrawLink
    JMP Link_EndMoveAndAnimate  ; Go redraw Link.

:CheckOtherDirs
    ; If not right, then vertical. %A was shifted to become
    ; horizontal direction counter-clockwise from original
    ; vertical direction. Got set it and redraw.
    BNE :SetLinkDirAndDraw

    ; Facing right.
    ;
    ; Face the next direction (up).
    LDA #$08
    BNE :SetLinkDirAndDraw      ; Go set the direction and redraw.

UpdateMode11Death_Sub8_AnimateFade
    JSR AnimateWorldFading
    BEQ L14CD7_IncSubmode       ; If done, then go to the next submode.
    RTS

UpdateMode11Death_Sub9
    LDA #$2C                    ; Cue the transfer of the dead Link (grey) palette row.
    STA TileBufSelector
    LDA #$0F

    ; In these two submodes, [E5] DeathModeCounter counts down
    ; how long the spark lasts.
    STA DeathModeCounter
    LDA #$18
    BNE UpdateMode11Death_SetTimerIncSubmode    ; Go set a delay of $17 ($18-1) frames, and advance the submode.

UpdateMode11Death_SubA
    LDA ObjTimer+11
    BNE L14D55_Exit             ; Delay until the timer expires, and we can show the spark.
    LDX #$62                    ; The little spark tile.
    LDA DeathModeCounter        ; How much time is left for the spark?
    CMP #$06
    BCS :Anon0073                      ; If counter/spark timer >= 6, use little spark tile $62.
    LDX #$64                    ; Else use the big one.
:Anon0073
    LDA ObjY
    STA Sprites+72              ; Use Link's Y for both sides.
    STA Sprites+76
    STX Sprites+73              ; Use the spark tile we chose.
    STX Sprites+77
    LDA #$01                    ; Use palette 5 for the left.
    STA Sprites+74
    LDA #$41                    ; Use the same palette, but flip horizontally on the right.
    STA Sprites+78
    LDA ObjX                    ; Use Link's X.
    STA Sprites+75
    CLC                         ; The second sprite is 8 pixels to the right.
    ADC #$08
    STA Sprites+79
    DEC DeathModeCounter        ; Count down how long you see the spark.
    BNE L14D55_Exit             ; If not zero yet, then return.
    LDA #$10                    ; Play "heart taken" tune.
    STA Tune0Request
    LDA #$F8                    ; Hide the Link/spark sprites.
    STA Sprites+72
    STA Sprites+76
    LDA #$2E                    ; Set a delay of $2D ($2E-1) frames for the next submode.

UpdateMode11Death_SetTimerIncSubmode
    STA ObjTimer+11
    INC GameSubmode

L14D55_Exit
    RTS

UpdateMode11Death_SubB
    LDA ObjTimer+11
    BNE L14D55_Exit             ; If the timer hasn't expired, then return.
    LDA #$60                    ; Set a delay of $5F ($60-1) frames for the next submode.
    STA ObjTimer+11
    LDA #$46                    ; Cue transfer of "GAME OVER" text, and advance submode.
    JMP SelectTransferBufAndAdvanceSubmode

UpdateMode11Death_SubC
    LDA ObjTimer+11
    BNE :Anon0074                      ; If the timer hasn't expired, then return.
    JSR EndGameMode
    LDA #$08                    ; Go to the Continue Question mode.
    STA GameMode
    LDA #$40                    ; Request Game Over music.
    STA Tune1Request
    LDX CurSaveSlot
    LDA DeathCounts, X          ; Increase the death count for current profile.
    CMP #$FF                    ; Up to the maximum $FF.
    BEQ :Anon0074
    INC DeathCounts, X
:Anon0074
    RTS

; Three sets of border coordinates:
; - outer OW
; - outer UW
; - inner
;
; Within each set, the coordinates are arranged:
; down, up, right, left
;
BorderBounds
            db    $D6, $45, $E9, $07, $C6, $55, $D9, $17
            db    $BE, $54, $D1, $1F

Link_FilterInput
    ; [00] holds the opposite of Link's facing direction.
    LDA ObjDir
    JSR GetOppositeDir
    STA $00

    ; Call GetOppositeDir again to use this mapping:
    ; In Dir: 1 2 4 8
    ;         -------
    ; Index:  2 3 0 1
    JSR GetOppositeDir

    ; Get the appropriate coordinate for the direction:
    ; X for horizontal
    ; Y for vertical
    LDA ObjX
    CPY #$02
    BCS :Anon0075
    LDA ObjY
:Anon0075
    STA $02                     ; [02] holds the coordinate (X or Y).

    ; Mask A button and directions if inner border is crossed.
    TYA
    PHA                         ; Save reverse direction index.
    CLC
    ADC #$08                    ; Add 8 for the third set of border bounds. Each is 4 bytes.
    TAY
    LDA #$80                    ; Button A will be masked off, if boundary is crossed.
    JSR MaskInputInBorder
    PLA                         ; Restore reverse direction index.
    TAY

    ; If inner boundary was not crossed, then we'll check the outer
    ; boundary using player's direction and reverse direction index.
    LDA $01
    CMP #$FF
    BNE :Anon0076
    LDA ObjDir
    STA $00                     ; [00] now holds facing direction instead of the opposite.
    JSR GetOppositeDir          ; Get the reverse direction index for the actual facing.
:Anon0076
    ; If in UW, use the second set of bounds by adding 4
    ; to reverse direction index.
    ;
    ; Else in OW, and use first set that begins at offset 0.
    LDA CurLevel
    BEQ :Anon0077
    TYA
    CLC
    ADC #$04
    TAY
:Anon0077
    ; We won't mask buttons (A) this time. Only directions now.
    LDA #$00

; Params:
; A: mask of buttons to block
; Y: offset into BorderBounds
; [00]: direction
; [02]: coordinate
;
; Returns:
; [01]: button mask that was used
;       (set to $FF if boundary not crossed)
;
MaskInputInBorder
    STA $01

    ; If direction is positive (right or down), then go handle it separately.
    LDA $00
    AND #$0A
    BEQ :PositiveDir

    ; The direction is negative (left or up).
    ;
    ; If the coordinate does not cross (<) the boundary, then
    ; go set mask $FF, so that no button is excluded.
    LDA $02
    CMP BorderBounds, Y
    BCC :ExcludeNone

:MaskButtons
    ; The boundary was crossed. Mask buttons.
    LDA ButtonsPressed
    AND $01                     ; [01] button mask
    STA ButtonsPressed

    ; If in OW or button mask <> 0, return.
    LDA CurLevel
    BEQ :Exit
    LDA $01
    BNE :Exit

    ; Mask off input directions perpendicular to player's facing.
    LDY #$0C
    LDA ObjDir
    AND #$0C
    BNE :Anon0078
    LDY #$03
:Anon0078
    TYA
    AND ObjInputDir
    STA ObjInputDir

:Exit
    RTS

:PositiveDir
    ; The direction is positive.
    ;
    ; If the coordinate crosses (<) the boundary, then
    ; go mask buttons.
    LDA $02                     ; Get coordinate in [02].
    CMP BorderBounds, Y
    BCC :MaskButtons

:ExcludeNone
    ; The coordinate is not crossed; then set mask $FF,
    ; so that no button is excluded.
    LDA #$FF
    STA $01                     ; [01] holds button mask.

L14DFF_Exit
    RTS

WieldSword
    ; If there's no sword, return.
    LDA Items
    BEQ L14DFF_Exit

    ; Switch to the sword slot.
    LDX #$0D

    ; If state <> 0, then sword or item is in use. So, return.
    LDA ObjState, X
    BNE L14DFF_Exit

    ; The first state lasts 5 frames.
    LDA #$05
    STA ObjAnimCounter, X

    ; The initial state is 1.
    LDA #$01
    JSR WieldWeapon
    LDA #$01                    ; Sword sound effect
    JMP PlayEffect

BoomerangLimits
            db    $31, $FF

WieldItem
    ; If the letter slot is selected, return.
    LDA SelectedItemSlot
    CMP #$0F
    BEQ L14E71_Exit
    JSR TableJump

WieldItem_JumpTable
            dw    WieldBoomerang
            dw    WieldBomb
            dw    WieldArrow
            dw    WieldNothing
            dw    WieldCandle
            dw    WieldFlute
            dw    WieldFood
            dw    WieldPotion
            dw    WieldRod

WieldBoomerang
    ; If missing wooden boomerang and magic boomerang, return.
    LDA InvBoomerang
    ORA InvMagicBoomerang
    BEQ L14E71_Exit

    ; Switch to the boomerang slot.
    LDX #$0F

    ; If state in object slot <> 0 and high bit is clear, return.
    LDA ObjState, X
    BEQ :Anon0079
    ASL
    BCC L14E71_Exit
:Anon0079
    ; Set state to $10 for boomerang.
    LDA #$10
    STA ObjState, X

    ; Set the farthest distance the boomerang can fly based on
    ; the type of boomerang.
    LDY InvMagicBoomerang
    LDA BoomerangLimits, Y
    STA ObjMovingLimit, X

    ; Set up the boomerang.
    ; QSpeed = $C0 (3 pixels a frame)
    ;
    ; The first turning animation frame lasts 3 screen frames, instead of 2.
    ; Maybe it's to make up for the fact that the first screen frame isn't seen.
    JSR PlaceWeaponForPlayerState
    LDA #$C0
    STA ObjQSpeedFrac, X
    LDA #$03
    STA ObjAnimCounter, X

    ; See PlaceWeaponForPlayerStateAndAnim for the reason
    ; that Link's animation counter is set to 1.
    LDA #$01
    STA ObjAnimCounter

    ; If there's an input direction, then use it as the weapon's direction.
    ; It might be diagonal, with horizontal and vertical components.
    ; Else use Link's facing direction.
    LDA ObjInputDir
    BNE :Anon0080
    LDA ObjDir
:Anon0080
    STA ObjDir, X

L14E71_Exit
    RTS

WieldArrow
    ; If there's no bow, return.
    LDA Bow
    BEQ WieldNothing

    ; Switch to the arrow slot.
    LDX #$12

    ; If state <> 0 and high bit is clear, return.
    LDA ObjState, X
    BEQ :Anon0081
    ASL
    BCC WieldNothing
:Anon0081
    ; If there are no rupees, return.
    LDA InvRupees
    BEQ WieldNothing
    LDA #$02                    ; Boomerang/arrow sound effect
    JSR PlayEffect

    ; Post a rupee to subtract.
    INC RupeesToSubtract

    ; Arrows start in state $10.
    LDA #$10

; Params:
; A: initial state
;
WieldWeapon
    STA ObjState, X

    ; Set q-speed $C0 (3 pixels a frame).
    LDA #$C0
    STA ObjQSpeedFrac, X
    JSR PlaceWeaponForPlayerStateAndAnim

    ; If the direction is vertical, move the object right 3 pixels.
    LDA ObjDir, X
    AND #$0C
    BEQ WieldNothing
    LDA ObjX, X
    CLC
    ADC #$03
    STA ObjX, X

WieldNothing
    RTS

WieldFood
    ; Switch to the food slot.
    LDX #$0F

    ; If there's an item already active in the slot (state <> 0), return.
    LDA ObjState, X
    BNE L14EC6_Exit

    ; The first state of food lasts $FF frames.
    LDA #$FF
    STA ObjTimer, X

    ; Set up the food in state $80.
    LDA #$80
    JMP PlaceWeaponForPlayerStateAndAnimAndWeaponState

WieldPotion
    ; If there's nothing in the item slot, return.
    LDA Potion
    BEQ L14EC6_Exit

    ; We're using one potion. So decrement the item value.
    DEC Potion

    ; Flag that we're filling hearts and involuntarily paused.
    LDA #$01
    STA World_IsFillingHearts
    LDA #$02
    STA Paused

L14EC6_Exit
    RTS

WieldRod
    ; Switch to the rod slot.
    ; If it's already in use, then return.
    LDX #$12
    LDA ObjState, X
    BNE L14EC6_Exit

    ; The first state lasts 5 frames.
    LDA #$05
    STA ObjAnimCounter, X

    ; The initial state is $31.
    LDA #$31
    JMP WieldWeapon

; Params:
; [0F]: movement direction
;
; Returns:
; [0F]: untouched, or 0
;
CheckSubroom ENT
    LDA GameMode
    CMP #$09
    BNE :InCave

    ; In a cellar.
    ;
    ; If Link's Y >= $40 or input direction <> up, return.
    LDA ObjY
    CMP #$40
    BCS L14EC6_Exit
    LDA ObjInputDir
    AND #$08
    BEQ L14EC6_Exit

    ; Look for this room's ID in the 6-element cellar room array.
    LDY #$06
    LDA RoomId
    PHA
:Anon0082
    DEY
    CMP LevelInfo_CellarRoomIdArray, Y
    BNE :Anon0082

    ; Determine the destination room ID, and go there.
    ;
    ; If Link's X < $80 look in level block attributes A, else B.
    ;
    ; Note that in cellars, level block attributes A and B indicate
    ; the destination room ID only.
    TAY
    LDA ObjX
    CMP #$80
    BCS :GetRightSideRoom
    LDA LevelBlockAttrsA, Y
    JMP :Anon0083

:GetRightSideRoom
    LDA LevelBlockAttrsB, Y
:Anon0083
    JSR GoToModeAFromCellar

    ; Set Link's position in the destination room.
    PLA
    TAY
    LDA LevelBlockAttrsC, Y
    PHA
    AND #$F0
    STA ObjX
    PLA
    ASL
    ASL
    ASL
    ASL
    ORA #$0D
    STA ObjY
    RTS

:InCave
    ; In a cave.
    ;
    ; Check whether a person is blocking the upper half of the room.
    PHA
    JSR CheckPersonBlocking
    PLA

    ; If mode is not $C (shortcuts), go check the screen edge.
    CMP #$0C
    BNE CheckCaveEdge

    ; In a shortcut cave (mode $C).
    ;
    ; If grid offset <> 0, return.
    LDA ObjGridOffset
    BNE L14F72_Exit

    ; If Link's Y <> $9D, go check the screen edge.
    LDA ObjY
    CMP #$9D
    BNE CheckCaveEdge

    ; See if Link is on one of the 3 shortcut stairs.
    ; X = $50: 1
    ; X = $80: 2
    ; X = $B0: 3
    ;
    ; If he's not on any, then return.
    LDY #$01
    LDA ObjX
    CMP #$50
    BEQ :Anon0084
    INY
    CMP #$80
    BEQ :Anon0084
    INY
    CMP #$B0
    BNE L14F72_Exit
:Anon0084
    ; Look for the current room in the cellar/shortcut room array.
    STY $00
    LDY #$FF
    LDA RoomId
:Anon0085
    INY
    CMP LevelInfo_CellarRoomIdArray, Y
    BNE :Anon0085

    ; Add the value of the shortcut chosen to whatever index
    ; the current room has in the array.
    ;
    ; This yields the index of one of the three shortcut rooms
    ; after the current one.
    TYA
    CLC
    ADC $00

    ; Wrap around if needed. Go to that room by way of mode $A.
    AND #$03
    TAY
    LDA LevelInfo_CellarRoomIdArray, Y

; Params:
; A: destination room ID
;
GoToModeAFromCellar
    STA RoomId
    JSR MarkRoomVisited

GoToModeAFromCave
    LDA #$0A
    STA GameMode

EndPrepareMode
    LDA #$00
    STA GameSubmode
    STA IsUpdatingMode
    STA $0F
    STA ObjState
    STA ObjShoveDir
    STA ObjShoveDistance
    STA ObjInvincibilityTimer

L14F72_Exit
    RTS

CheckCaveEdge
    JSR CheckScreenEdge

    ; If the player touched the edge of the screen and triggered
    ; a transition to another mode, then go set up the right mode.
    LDA IsUpdatingMode
    BEQ GoToModeAFromCave
    RTS

; Params:
; [0F]: movement direction
;
; Returns:
; [0F]: movement direction or 0
;
CheckLadder ENT
    ; If the ladder's not in use, return.
    LDX LadderSlot
    BEQ :Exit

    ; If the ladder is done (state 0), go put away the ladder.
    LDA ObjState, X
    BEQ :StashLadder

    ; If the ladder is facing vertically, calculate the vertical distance
    ; between the ladder and Link.
    ; If Link's X no longer matches the ladder's, go put the ladder away.
    LDA ObjDir, X
    AND #$0C
    BEQ :Anon0086
    LDA ObjX
    CMP ObjX, X
    BNE :StashLadder
    LDA ObjY
    CLC
    ADC #$03
    SEC
    SBC ObjY, X
    JMP :CheckDistanceToLadder
:Anon0086
    ; If instead it's facing horizontally, calculate the horizontal distance
    ; between the ladder and Link.
    ; If Link's Y no longer matches the ladder's, go put the ladder away.
    LDA ObjY
    CLC
    ADC #$03
    CMP ObjY, X
    BNE :StashLadder
    LDA ObjX
    SEC
    SBC ObjX, X

:CheckDistanceToLadder
    ; If absolute distance < $10, go handle movement on the ladder and set state 2.
    ; If > $10, go put the ladder away.
    JSR Abs
    STA $00                     ; [00] holds the absolute distance between Link and the ladder in whichever axis is relevant.
    CMP #$10
    BCC :SetState2
    CMP #$10
    BNE :StashLadder

    ; Distance = $10. If player's not facing in the same direction as
    ; the ladder, go put away the ladder.
    LDA ObjDir
    CMP ObjDir, X
    BNE :StashLadder

    ; Distance = $10, and player's facing in the same direction.
    ;
    ; If the ladder's still in initial state 1, then Link's facing the
    ; ladder and had not stepped onto it yet.
    ; Go handle movement on it, but don't change state yet.
    ;
    ; But if ladder state is 2, then it means Link completely stepped
    ; off of the ladder. So the ladder should be put away. In this
    ; case, fall thru.
    LDA ObjState, X
    CMP #$01
    BEQ :HandleInput

:StashLadder
    ; Put away the ladder. Reset ladder slot and destroy the object.
    LDA #$00
    STA LadderSlot
    JSR DestroyMonster

:Exit
    RTS

:SetState2
    ;  Set state 2, because we're on the ladder.
    LDA #$02
    STA ObjState, X

:HandleInput
    ; If input direction = 0, go draw and reset moving direction.
    LDA ObjInputDir
    BEQ :DrawLadder

    ; Input direction <> 0. The player intends to move.
    ; So, see if we need to override the moving direction.
    ;
    ; A. If the distance <> 0, and they are facing the same way,
    ; go draw and set moving direction to Link's direction.
    ;
    ; This lets Link step onto the ladder. Otherwise he would have
    ; been blocked by the water.
    ;
    ; Or, Link already passed over the point right over the ladder
    ; and was allowed to move onto the tiles after the ladder.
    LDA ObjDir
    LDY $00                     ; [00] distance between Link and ladder
    BEQ :Anon0087
    CMP ObjDir, X
    BEQ :DrawLadder
:Anon0087
    ; Distance = 0, or facing different directions.
    ;
    ; B. If ladder's direction = Link's *moving* direction,
    ; then go draw and keep moving.
    ;
    ; This only applies when distance = 0. Otherwise, (A) would have caught it.
    ;
    ; Before checking the ladder, a tile collision check allowed Link
    ; to move onto the tiles after the ladder.
    ;
    ; Note that if Link is not moving, then this test will fail,
    ; and case (D) will catch it.
    LDA ObjDir, X
    CMP $0F                     ; [0F] Link's moving direction
    BEQ :DrawLadder

    ; C. If opposite of ladder's direction = Link's facing direction,
    ; then go draw and move in ladder's direction.
    ;
    ; You can always step off the ladder where you came from.
    JSR GetOppositeDir
    CMP ObjDir
    BEQ :DrawLadder

    ; D. If opposite of ladder's direction <> down,
    ; or input direction <> up,
    ; then go reset moving direction, and draw.
    ;
    ; This will catch all cases of Link facing perpendicular to
    ; ladder direction. Also, it will catch Link not moving, unless
    ; ladder direction is up and input direction is up (E).
    CMP #$04
    BNE :Anon0088
    LDA ObjInputDir
    CMP #$08
    BNE :Anon0088

    ; E. The ladder's direction is up and input direction is up.
    ;
    ; An earlier call to check tile collision would have blocked
    ; movement, because the tile under Link's top half is a water tile.
    ; But because Link is squarely on the ladder, we really have
    ; to check the tile above that one.
    ;
    ; Set moving direction to input direction (up) and switch X to
    ; the player's slot for the purpose of checking tile collision below.
    ; Based on that, we'll set moving direction according to walkability.
    JSR SetMovingDirAndSwitchToPlayerSlot

    ; Check the colliding tile as if Link was 8 pixels up.
    LDA ObjY
    PHA
    SEC
    SBC #$08
    STA ObjY
    JSR GetCollidingTileMoving
    PLA
    STA ObjY

    ; If the tile is walkable, go draw the ladder and leave the moving
    ; direction as the input direction (in a roundabout way).
    ; Else fall thru to reset moving direction and draw the ladder.
    LDA $0F
    LDY ObjCollidedTile
    CPY ObjectFirstUnwalkableTile
    BCC :HandleInput
:Anon0088
    ; Set A to reset moving direction in [0F].
    LDA #$00

:DrawLadder
    ; Draw the ladder.
    PHA
    LDX LadderSlot
    JSR Anim_FetchObjPosForSpriteDescriptor
    LDY #$0C
    LDA #$00
    JSR Anim_WriteStaticItemSpritesWithAttributes
    PLA

; Params:
; A: direction
;
; Returns:
; [0F]: direction
;
SetMovingDirAndSwitchToPlayerSlot
    STA $0F
    LDX #$00
    RTS

FindNextEdgeSpawnCell ENT
    ; Load [0A] with the value before the call.
    LDA CurEdgeSpawnCell
    STA $0A

:LoopEdgeCell
    ; Loop to look for a place to spawn a monster from the edge
    ; of the screen. Move counterclockwise, one square at a time.
    ;
    ; First, if low nibble = 0, then we're at the left edge.
    ; We'll move down $10 pixels.
    LDY #$10
    LDA $0A
    AND #$0F
    BEQ :HandleLeftOrRight

    ; Else if low nibble <> $F, then we're at the top or bottom.
    ; Don't move vertically.
    LDY #$F0
    CMP #$0F
    BNE :CheckTopOrBottom

:HandleLeftOrRight
    ; Else low nibble = $F. We're at the right edge,
    ; and we'll move up $10 pixels.
    TYA
    CLC
    ADC $0A                     ; Add $10 or -$10 at the left or right edge.
    STA $0A

:CheckTopOrBottom
    ; Next, if high nibble = $E, then we're at the bottom edge.
    ; Move right one pixel.
    LDA $0A
    AND #$F0
    CMP #$E0
    BNE :Anon0089
    INC $0A
    JMP :PointToColumn
:Anon0089
    ; Else if high nibble <> 4, then we're at the left or right.
    ; Dont' move horizontally.
    CMP #$40
    BNE :PointToColumn

    ; Else high nibble = 4. We're at the top edge.
    ; Move left 1 pixel.
    DEC $0A

:PointToColumn
    ; Time to get the address of the column.
    ; Starting at the top of the leftmost column.
    JSR FetchTileMapAddr

    ; Add $2C to the address as many times as the low nibble of [0A],
    ; in order to point to the column we want.
    LDA $0A
    AND #$0F
    TAY
    BEQ :GetRowOffset
:Anon0090
    LDA #$2C                    ; Each column is $16 tiles. Each square column has two columns.
    JSR AddToInt16At0
    DEY
    BNE :Anon0090

:GetRowOffset
    ; Turn the row part of [0A] into a tile index.
    ; row := (([0A] AND $F0) - $40) / 8
    LDA $0A
    AND #$F0
    SEC
    SBC #$40
    LSR
    LSR
    LSR
    TAY

    ; If the tile < $84, then it's walkable. So, go use it.
    ; $84 is a sand tile, which is OK for many monsters; but not
    ; when coming in from the edges.
    LDA ($00), Y
    CMP #$84
    BCC :SetSpawnCell

    ; Bottom of the loop.
    ; If you reach the original cell, then stop.
    LDA $0A
    CMP CurEdgeSpawnCell
    BNE :LoopEdgeCell

:SetSpawnCell
    ; Set the spawn cell to the one we found.
    LDA $0A
    STA CurEdgeSpawnCell
    RTS

InitModeB ENT
    LDA GameSubmode
    JSR TableJump

InitModeB_JumpTable
            dw    InitModeSubroom_Sub0
            dw    InitModeB_Sub1
            dw    InitModeSubroom_AdvanceSubmode
            dw    LayoutCaveAndAvanceSubmode
            dw    CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone
            dw    InitModeB_Sub5_FillTileAttrsAndTransferTopHalf
            dw    InitModeAOrB_TransferBottomHalfAttrs
            dw    InitModeB_EnterCave_Bank5
            dw    InitMode_WalkCave

InitModeC ENT
    LDA GameSubmode
    JSR TableJump

InitModeC_JumpTable
            dw    InitModeSubroom_Sub0
            dw    InitModeB_Sub1
            dw    InitModeSubroom_AdvanceSubmode
            dw    LayoutShortcutAndAdvanceSubmode
            dw    CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone
            dw    InitModeB_Sub5_FillTileAttrsAndTransferTopHalf
            dw    InitModeAOrB_TransferBottomHalfAttrs
            dw    InitModeB_EnterCave_Bank5
            dw    InitMode_WalkCave

ModifyObjCountByHistoryOW
    ; Look for the room in the history.
    LDY #$05
    LDA RoomId
:Anon0091
    CMP RoomHistory, Y
    BEQ :Anon0092                      ; If found, go check kill count in depth.
    DEY
    BPL :Anon0091

    ; It wasn't found. Check the kill count in the room flags.
    JSR GetRoomFlags
    AND #$07
    CMP #$07
    BNE :Anon0092                      ; If kill count < max, go check kill count in depth.

    ; The room is not in history, and all foes were defeated.
    ; So, reset the kill count in room flags.
    LDA ($00), Y
    AND #$F8
    STA ($00), Y

:Exit
    RTS
:Anon0092
    ; If kill count in room flags = 0, leave object count alone, and return.
    JSR GetRoomFlags
    AND #$07
    BEQ :Exit

    ; If kill count = 7, go reset object count and object list ID.
    ; Else subtract kill count from object count.
    CMP #$07
    BEQ :ResetObjList
    STA $04
    LDA $03
    SEC
    SBC $04
    BPL :Anon0093                      ; If the result >= 0, go set the object count to this.

:ResetObjList
    LDA #$00                    ; Else, reset object count and object list ID.
    STA $02
:Anon0093
    STA $03
    RTS

SaveKillCountOW
    JSR GetRoomFlags
    AND #$07                    ; Put kill count from the room's flags in [02].
    STA $02
    LDA ($00), Y                ; Reset kill count part of the room's flags.
    AND #$F8
    STA ($00), Y
    LDA RoomKillCount
    CMP RoomObjCount
    BCS :LimitCount             ; If RoomKillCount >= RoomFoeCount, go store the max kill count.
    AND #$07                    ; Limit RoomKillCount to 7.
    CLC                         ; Add it to kill count from flags.
    ADC $02
    CMP #$07
    BCC :Anon0094                      ; If the total > 7,

:LimitCount
    LDA #$07                    ; then limit it to 7.
:Anon0094
    ORA ($00), Y                ; Combine this new total and the room's flags.
    STA ($00), Y
    RTS

InitMode9 ENT
    LDA GameSubmode
    JSR TableJump

InitMode9_JumpTable
            dw    InitModeSubroom_Sub0
            dw    InitMode9_FadeToDark
            dw    InitModeSubroom_AnimateFade
            dw    LayoutCellarAndAdvanceSubmode
            dw    CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone
            dw    InitMode9_TransferAttrs
            dw    InitMode9_FadeToLight
            dw    InitModeSubroom_AnimateFade
            dw    InitMode9_EnterCellar
            dw    InitMode9_WalkCellar

; Description:
; This procedure is the same as DrawObjectNotMirroredOverLink
; in bank 4.
;
Unused_DrawObjectNotMirroredOverLink_Bank5
    ; Begin unverified code 15123
    LDY #$00
    BEQ Unused_DrawObjectMirroredOverLink_Bank5
    LDY #$01

; Description:
; This procedure is the same as DrawObjectMirroredOverLink
; in bank 4.
;
Unused_DrawObjectMirroredOverLink_Bank5
    STY $0C
    LDY ObjType, X
    INY
    STA $0D
    STY $0E
    STX $08
    LDA #$40
    STA LeftSpriteOffset
    LDA #$44
    JMP DrawObjectWithAnimAndSpecificSprites
    ; End unverified code

Link_ModifyDirInDoorway
    ; In a doorway (UW), you can only move in the direction
    ; that you entered it or the opposite.
    ; If not in a doorway nor moving, then return.
    LDA DoorwayDir
    BEQ :Exit
    LDY ObjInputDir
    BEQ :Exit

    ; If the facing direction is part of the input direction, then
    ; keep moving in the facing direction.
    LDA ObjDir
    AND ObjInputDir
    BNE :Anon0095

    ; If the opposite of the facing direction is part of the input direction, then
    ; face the opposite direction.
    LDA ObjDir
    JSR GetOppositeDir
    AND ObjInputDir

    ; If neither direction matched input direction, then
    ; change input direction to facing direction.
    BNE :Anon0095
    LDA ObjDir
:Anon0095
    STA ObjInputDir

:Exit
    RTS

; Description:
; This procedure is the same as HideSpritesOverLink in bank 4.
;
Unused_HideSpritesOverLink_Bank5
    ; Begin unverified code 1515F
    LDA #$F8
    STA Sprites+64
    STA Sprites+68
    RTS
    ; End unverified code

; To be considered within a doorway, one condition is that
; Link's perpendicular coordinate ([00]) has to match the doorway's
; (X=$78 for verticals, Y=$8D for horizontals).
;
; See GetPlayerCoordsForDirection.
;
DoorwayRequiredCoord
            db    $78, $78, $8D, $8D

; Player coordinate must be >= these bounds.
; Using these bounds; the player will be considered within the
; bounds of a doorway, if strictly inside or 1 pixel outside.
;
DoorwayBoundsMinOver
            db    $3D, $BD, $00, $CF

; Player coordinate must be < these bounds.
; Using these bounds; the player will be considered within the
; bounds of a doorway, if strictly inside or 1 pixel outside.
;
DoorwayBoundsMaxOver
            db    $5E, $DE, $21, $F1

; Player coordinate must be >= these bounds.
; Using these bounds; the player will be considered within the
; bounds of a doorway, if strictly inside except for 1 or 2 pixels
; at the edge.
;
DoorwayBoundsMinUnder
            db    $3D, $BF, $00, $D2

; Player coordinate must be < these bounds.
; Using these bounds; the player will be considered within the
; bounds of a doorway, if strictly inside except for 1 or 2 pixels
; at the edge.
;
DoorwayBoundsMaxUnder
            db    $5C, $DE, $1F, $F1

; Params:
; [0F]: moving direction
;
; Returns:
; [0E]: reverse index of doorway direction found, or $FF if blocked
; [0F]: untouched, or changed from 0 to a moving direction
;
; When not at or in a doorway, this function leaves
; [0F] moving direction as is.
;
; When blocked by a door, [0E] will be set to $FF. But [0F]
; will be left as is, assuming that it had been reset before this
; routine by BoundByRoom.
;
; Otherwise, [0F] will be changed from 0 to the door's direction.
;
CheckDoorway ENT
    ; If already in a doorway, go handle it separately.
    LDA DoorwayDir
    BNE :InDoorway

:SearchOverflowBounds
    ; Not in a doorway. Look for a doorway that Link might be in.
    ;
    ; To match a doorway:
    ; 1. Link's [00] coordinate has to match the doorway's
    ;    (X=$78 for verticals, Y=$8D for horizontals)
    ; 2. Link's [01] coordinate has to >=  min bound, and < max bound
    ;
    ; The "overflow" bounds are used that consider 1 pixel outside
    ; a doorway to be part of it.
    LDA ObjDir
    JSR GetPlayerCoordsForDirection
    LDY #$03

:LoopOverflowBounds
    LDA $00                     ; [00] is Link's Y, if facing horizontally; else X.
    CMP DoorwayRequiredCoord, Y
    BNE :Anon0096
    LDA $01                     ; [01] is Link's X, if facing horizontally; else Y.
    CMP DoorwayBoundsMinOver, Y
    BCC :Anon0096
    CMP DoorwayBoundsMaxOver, Y
    BCC :TestDoorwayDoor        ; If found a doorway, go see what it does when you touch it.
:Anon0096
    DEY
    BPL :LoopOverflowBounds

:NotInDoorway
    ; Not in any doorway. Reset DoorwayDir.
    ; Leave [0F] moving direction as is.
    LDA #$00
    STA DoorwayDir
    RTS

:InDoorway
    ; In a doorway. DoorwayDir is in A.
    PHA
    JSR GetPlayerCoordsForDirection
    PLA
    JSR GetOppositeDir          ; Get reverse index of doorway direction.
    LDA $01                     ; [01] is Link's X, if facing horizontally; else Y.

    ; If the player is within the bounds of the doorway for DoorwayDir
    ; (for example the left door way, if DoorwayDir = left;
    ; instead of right doorway while DoorwayDir = left),
    ; and player is facing in DoorwayDir, then go repeat the
    ; original search used to enter the doorway.
    CMP DoorwayBoundsMinOver, Y
    BCC :SearchUnderflowDoorway
    CMP DoorwayBoundsMaxOver, Y
    BCS :SearchUnderflowDoorway
    LDA DoorwayDir
    CMP ObjDir
    BEQ :SearchOverflowBounds

:SearchUnderflowDoorway
    ; The player might be in the original doorway facing backwards,
    ; outside it, or in the other doorway along the axis.
    ;
    ; Look for a doorway that Link might be in.
    ; The difference between this search and the one above
    ; is that we check the "underflow" bounds that are shorter than
    ; the full doorway length.
    LDY #$03

:LoopUnderflowDoorway
    LDA $00                     ; [00] is Link's Y, if facing horizontally; else X.
    CMP DoorwayRequiredCoord, Y
    BNE :Anon0097
    LDA $01                     ; [01] is Link's X, if facing horizontally; else Y.
    CMP DoorwayBoundsMinUnder, Y
    BCC :Anon0097
    CMP DoorwayBoundsMaxUnder, Y
    BCC :TestDoorwayDoor
:Anon0097
    DEY
    BPL :LoopUnderflowDoorway
    BMI :NotInDoorway           ; Not in a doorway. Go set DoorwayDir to 0, and leave [0F] alone.

:TestDoorwayDoor
    ;
    ;
    ; [0E] holds reverse index of doorway direction found.
    STY $0E

    ; Store input direction in [02] and [0C].
    LDA ObjInputDir
    AND #$0F
    STA $02
    STA $0C

    ; If input direction is not the doorway direction found, return.
    CMP ReverseDirections, Y
    BNE :Exit

    ; Touch the door in the direction we found.
    JSR FindDoorTypeByDoorBit
    STA $0D                     ; [0D] holds the door type.
    JSR TouchDoor               ; Can set [0E] to $FF, if a door blocks the way.

    ; If blocked, then return and leave DoorwayDir as it was.
    LDY $0E
    BMI :Exit

    ; Set variables to doorway direction found.
    LDA ReverseDirections, Y
    STA ObjDir
    STA $0F                     ; [0F] movement direction
    STA DoorwayDir

    ; Movement was not blocked at a doorway.
    ; If we're at a false wall or bombable, then go pass thru it
    ; and leave the room.
    LDA $0D
    AND #$07
    CMP #$02
    BEQ :Anon0098
    CMP #$03
    BEQ :Anon0098
    CMP #$04
    BEQ :Anon0098

:Exit
    RTS
:Anon0098
    JMP GoToNextModeFromPlay

; Params:
; A: direction
;
; Returns:
; [00]: coordinate on perpendicular axis
; [01]: coordinate on direction's axis
;
; [00]: Y if facing left or right, else X
; [01]: X if facing left or right, else Y
;
GetPlayerCoordsForDirection
    LDX ObjX
    LDY ObjY
    AND #$03
    BEQ :Anon0099
    LDY ObjX
    LDX ObjY
:Anon0099
    STX $00
    STY $01
    RTS

; Params:
; [0C]: door direction
; [0E]: reverse index of direction
;
; Returns:
; [0E]: untouched, or $FF if blocked
;
TouchDoor
    AND #$07
    JSR TableJump

TouchDoor_JumpTable
            dw    TouchDoorOpen
            dw    TouchDoorWall
            dw    TouchDoorFalse
            dw    TouchDoorFalse
            dw    TouchDoorBombable
            dw    TouchDoorKey
            dw    TouchDoorKey
            dw    TouchDoorShutter

TouchDoorWall
    LDY #$FF
    STY $0E

TouchDoorOpen
    RTS

TouchDoorFalse
    ; At first, Link's timer = 0. So set it to $18 frames, and block movement.
    ; Subsequently, block movement until timer = 1.
    LDA ObjTimer
    BEQ :SetTimer
    CMP #$01
    BNE :BlockMovement
    RTS

:SetTimer
    LDA #$18
    STA ObjTimer

:BlockMovement
    JMP TouchDoorWall

TouchDoorBombable
    ; Block movement, if this door's direction is not in the open door mask.
    LDA $0C
    AND CurOpenedDoors
    BEQ TouchDoorWall
    RTS

TouchDoorShutter
    ; If a door is triggered or this door wasn't already opened,
    ; then block movement.
    LDA TriggeredDoorCmd
    BNE TouchDoorWall
    LDA $0C
    AND CurOpenedDoors
    BEQ TouchDoorWall

    ; TODO: ?
    AND $0519
    BEQ :Anon0100
    BNE BlockUntilTime          ; Go block movement while timer <> 0.
:Anon0100
    LDA $0519
    ORA $0C
    STA $0519
    RTS

TouchDoorKey
    ; If this door was already opened, return.
    LDA $0C
    AND CurOpenedDoors
    BNE L15292_Exit

    ; If a door is triggered, go block movement while Link's timer <> 0.
    LDA TriggeredDoorCmd
    BNE BlockUntilTime

    ; If we don't have the magic key nor any normal keys, 
    ; go block movement.
    LDA InvMagicKey
    BNE :TriggerDoor
    LDA InvKeys
    BEQ BlockAtWall

    ; If we don't have the magic key, decrease the key count.
    DEC InvKeys

:TriggerDoor
    ; Trigger this door to open.
    LDA $0C
    JSR TriggerOpenDoor

    ; Set player's timer to block for $20 frames.
    LDA #$20
    STA ObjTimer

BlockAtWall
    JMP TouchDoorWall

BlockUntilTime
    ; Block movement while Link's timer <> 0.
    LDA ObjTimer
    BNE BlockAtWall

L15292_Exit
    RTS

ModifyObjCountByHistoryUW
    ; Look for the room in the history.
    LDY #$05
    LDA RoomId
:Anon0101
    CMP RoomHistory, Y
    BEQ :CalcObjCount           ; If found, go subtract kill count from object count.
    DEY
    BPL :Anon0101

    ; It wasn't found. Check the kill count in the room flags.
    JSR GetRoomFlags
    AND #$C0
    CMP #$C0
    BNE :CalcObjCount           ; If not all defeated, go subtract kill count from object count.

    ; The room is not in history, and all foes were defeated.
    ; Does the object list ID indicate a non-recurring object?
    LDA $02
    CMP #$32
    BCC :Anon0102
    CMP #$3A
    BEQ :Anon0102
    CMP #$3B
    BEQ :Anon0102
    CMP #$49
    BCC :ResetObjCount          ; If it's non-recurring, go reset the object count.
:Anon0102
    ; The object list ID is for recurring objects.
    ; So, reset the kill count in room flags and level block.
    LDA ($00), Y
    AND #$3F
    STA ($00), Y
    LDA #$00
    STA LevelKillCounts, Y
    RTS

:CalcObjCount
    ; Subtract the level block's kill count from the object count.
    LDY RoomId
    LDA $03
    SEC
    SBC LevelKillCounts, Y
    BPL :Anon0103                      ; If the result >= 0, go set the object count to this.

:ResetObjCount
    LDA #$00                    ; Else, reset object count and object list ID.
    STA $02
:Anon0103
    STA $03
    RTS

SaveKillCountUW
    JSR GetRoomFlags
    AND #$3F                    ; Reset kill count part of the room's flags.
    STA ($00), Y
    LDA RoomObjCount
    BEQ :StoreMax               ; If no monsters were made in this room, go store the max kill count.
    LDA RoomKillCount
    BEQ :Anon0104                      ; If RoomKillCount = 0, go compare it to RoomFoeCount.

    ; If the object template type is ...
    ; >= $32 and
    ; <> $3A and
    ; <> $3B and
    ; <  $49,
    ; then it refers to a non-recurring foe that shouldn't be made
    ; again. So, go store the max kill count for the room.
    ; 
    LDY RoomObjTemplateType
    CPY #$32
    BCC :Anon0104
    CPY #$3A
    BEQ :Anon0104
    CPY #$3B
    BEQ :Anon0104
    CPY #$49
    BCC :StoreMax
:Anon0104
    ; Compare RoomKillCount and RoomFoeCount.
    CMP RoomObjCount
    BCS :StoreMax               ; If RoomKillCount >= RoomFoeCount, go store the max kill count for the room.

    ; RoomKillCount < _RoomObjCount.
    ; Add RoomKillCount to level kill count for this room.
    LDY RoomId
    CLC
    ADC LevelKillCounts, Y
    STA LevelKillCounts, Y
    CMP #$03                    ; Cap the kill count to 2.
    BCC :Anon0105
    LDA #$02
:Anon0105
    CLC                         ; Shift the adjusted kill count (up to 2) into the top 2 bits.
    ROR
    ROR
    ROR
    JMP :CombineWithFlags       ; Go combine this mask with the room's flags.

:StoreMax
    LDY RoomId                  ; For this room in the level block, set kill count to max ($F).
    LDA #$0F
    STA LevelKillCounts, Y
    LDA #$C0                    ; For this room in world flags, set kill count to max (3).

:CombineWithFlags
    ORA ($00), Y                ; Combine the mask with the room's flags.
    STA ($00), Y
    RTS

BossSoundEffects
            db    $00, $10, $20, $40

CheckBossSoundEffectUW ENT
    JSR GetRoomFlags
    LDY LevelInfo_BossRoomId
    LDA ($00), Y                ; Get room flags for boss room.
    AND #$C0
    CMP #$C0
    BEQ :Anon0106                      ; If the boss was defeated, go turn off ambient sound effects.
    LDY RoomId
    LDA LevelBlockAttrsE, Y
    AND #$60                    ; Sound effect index
    ASL                         ; Shift the sound effect index to the low end of the byte.
    ROL
    ROL
    ROL
    TAX
    LDA BossSoundEffects, X
    BEQ :Anon0106                      ; If the room has no boss sound effect, go turn off any that might be playing.
    ORA #$80                    ; Add the flag to repeat
    STA SampleRequest
    RTS
:Anon0106
    LDA #$80                    ; Silence sample and tune1.
    JMP PlayEffect

; Unknown block
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF

; Params:
; [02:03]: address of door tiles for direction and face
; [04]: count of tiles remaining
; [07]: current index (0 to 3) of the tile to copy
;       to the dynamic transfer buf
; [09]: door direction index
;
; Returns:
; Z: 1 if wrote the last tile / [04] became 0
; [04]: original value - 1
; [07]: original value + 1
;
; The door face tile list at [02:03] has pairs of tiles arranged
; vertically. The point of this routine is to access them
; horizontally in order to transfer them to a nametable.
;
WriteDoorFaceTileHorizontally
    ; For the direction index in [09], look up the base offset of the
    ; set of 4 indexes in HorizontalDoorFaceIndexes that point to
    ; the door face tiles at [02:03].
    LDY $09
    LDA HorizontalDoorFaceIndexesBaseOffsets, Y

    ; Add [07] to the base offset we got above. This yields one
    ; of four consecutive indexes into HorizontalDoorFaceIndexes.
    CLC
    ADC $07                     ; Current index of a tile, abstractly (0 to 3)
    TAY

    ; With that index, look up the index to use with the door face
    ; list of tiles at [02:03].
    LDA HorizontalDoorFaceIndexes, Y
    TAY

    ; Now we can read one of four tiles inside a door face tile map,
    ; and copy it to the dynamic transfer buf.
    LDA ($02), Y
    STA DynTileBuf, X

    ; Prepare for the next call:
    ; - increment dynamic transfer buf pointer
    ; - increment index of tile to copy [07]
    ; - decrement count of tiles remaining
    INX
    INC $07
    DEC $04
    RTS

RoomLayoutsOW
            putbin dat/RoomLayoutsOW.dat

RoomLayoutOWCave0
            db    $00, $00, $95, $95, $95, $95, $95, $C2
            db    $C2, $95, $95, $95, $95, $95, $00, $00

RoomLayoutOWCave1
            db    $00, $00, $95, $95, $95, $F8, $95, $C2
            db    $F8, $95, $95, $F8, $95, $95, $00, $00

RoomLayoutOWCave2
            db    $00, $A9, $64, $66, $02, $53, $54, $D1
            db    $54, $54, $56, $02, $64, $66, $A8, $00

ColumnHeapOW0
            db    $DB, $5B, $5B, $DB, $5B, $1B, $0E, $1A
            db    $5B, $DB, $4E, $4E, $4E, $0E, $1A, $1B
            db    $DB, $4E, $32, $1B, $34, $4E, $1A, $1B
            db    $DB, $5B, $1B, $4E, $4E, $4E, $DB, $0E
            db    $32, $5B, $1B, $4E, $1A, $1B, $DB, $5B
            db    $1B, $4E, $4E, $1A, $1B, $DB, $CE, $4E
            db    $4E, $4E, $0E, $1A, $1B

ColumnHeapOW1
            db    $9B, $0C, $4E, $4E, $4E, $0E, $1A, $1B
            db    $CA, $4E, $0E, $4E, $4E, $4A, $C5, $45
            db    $05, $0B, $C5, $45, $05, $45, $45, $45
            db    $D9, $28, $59, $D9, $59, $59, $19, $D9
            db    $59, $4E, $0E, $59, $D9, $4E, $4E, $4E
            db    $0E, $59, $8E, $4E, $4E, $CE, $4E, $4E
            db    $0E

ColumnHeapOW2
            db    $D9, $59, $0E, $4E, $4E, $4E, $DB, $0E
            db    $5B, $5B, $4E, $1A, $1B, $DB, $0E, $33
            db    $5B, $1B, $4E, $1A, $1B, $CE, $4E, $4E
            db    $4E, $0E, $59, $DB, $4E, $33, $1B, $35
            db    $4E, $1A, $1B, $D9, $4E, $19, $0E, $19
            db    $4E, $D9, $0E, $19, $0E, $19, $0E, $19
            db    $0E, $D9, $4E, $0E, $19, $0E, $4E, $D9
            db    $19, $4E, $4E, $0E, $19, $D9, $0E, $59
            db    $59, $59

ColumnHeapOW3
            db    $D9, $0E, $59, $59, $19, $0E, $D9, $4E
            db    $19, $0E, $28, $4E, $59, $DB, $4E, $13
            db    $0E, $13, $4E, $1A, $1B, $DB, $0E, $13
            db    $0E, $13, $0E, $13, $0E, $1A, $1B, $DB
            db    $4E, $0E, $13, $4E, $0E, $1A, $1B, $C8
            db    $48, $17, $4E, $4E, $1A, $1B, $C5, $45
            db    $07, $4E, $4E, $1A, $1B, $C5, $45, $07
            db    $0E, $1A, $DB, $5B, $1B, $4E, $4E, $4A
            db    $DB, $4E, $4E, $15

ColumnHeapOW4
            db    $C8, $48, $17, $4E, $4E, $59, $C9, $49
            db    $18, $4E, $4E, $D9, $59, $4E, $06, $C5
            db    $45, $45, $C9, $49, $09, $0B, $49, $49
            db    $09, $C8, $48, $08, $48, $C8, $48, $17
            db    $4E, $4E, $4E, $DB, $4E, $4E, $06, $C5
            db    $45, $07, $4E, $4E, $D9, $4E, $2C, $4E
            db    $4E, $59

ColumnHeapOW5
            db    $DB, $5B, $1B, $0E, $4A, $4A, $0A, $DB
            db    $5B, $4E, $06, $C5, $45, $07, $4E, $4E
            db    $4E, $DB, $0E, $15, $48, $17, $4E, $1A
            db    $1B, $DB, $0E, $06, $45, $07, $4E, $1A
            db    $1B, $DB, $0E, $06, $05, $45, $45, $45
            db    $DB, $0E, $16, $49, $18, $4E, $1A, $1B
            db    $D9, $0E, $59, $59, $19, $0E, $CE, $4E
            db    $4E, $06, $45, $45

ColumnHeapOW6
            db    $D9, $4E, $4E, $16, $49, $49, $D9, $4E
            db    $4E, $06, $C5, $45, $07, $4E, $D9, $59
            db    $4E, $15, $48, $48, $DB, $0E, $1C, $1F
            db    $4E, $4E, $1A, $1B, $DB, $0E, $1D, $0C
            db    $4E, $4E, $1A, $1B, $DB, $0E, $1E, $20
            db    $4E, $4E, $1A, $1B, $DB, $0E, $21, $24
            db    $4E, $4E, $1A, $1B, $DB, $0E, $22, $0C
            db    $4E, $4E, $4A

ColumnHeapOW7
            db    $DB, $0E, $23, $25, $4E, $4E, $1A, $1B
            db    $DB, $4E, $0E, $26, $4E, $0E, $1A, $1B
            db    $DB, $5B, $07, $4E, $1A, $1B, $DB, $5B
            db    $07, $4E, $4E, $1A, $1B, $CE, $0E, $59
            db    $59, $19, $0E, $D9, $4E, $0E, $26, $4E
            db    $0E, $D9, $4E, $4E, $4E, $4E, $0E, $DB
            db    $4E, $19, $0E, $19, $4E, $1A, $1B, $DB
            db    $5B, $5B, $45

ColumnHeapOW8
            db    $C5, $05, $5B, $5B, $DB, $5B, $27, $0E
            db    $1A, $5B, $DB, $0E, $14, $0E, $14, $0E
            db    $14, $4E, $0E, $CA, $4A, $0A, $4E, $4E
            db    $1A, $1B, $DB, $1B, $35, $4E, $4E, $0E
            db    $1A, $1B, $9B, $27, $4E, $4E, $06, $C5
            db    $45, $05, $2F, $4E, $4E, $0E, $DB, $0E
            db    $22, $0C, $4E, $4E, $4A, $DB, $0E, $14
            db    $0E, $29, $0E, $14, $4E, $0E

ColumnHeapOW9
            db    $DB, $35, $4E, $4E, $4E, $1A, $1B, $DB
            db    $1B, $34, $4E, $06, $C5, $45, $05, $2E
            db    $4E, $4E, $0E, $CE, $0E, $14, $0E, $14
            db    $0E, $14, $0E, $1A, $1B, $CE, $0E, $14
            db    $0E, $14, $0E, $14, $4E, $0E, $DB, $4D
            db    $4D, $4D, $0D, $1A, $1B, $C5, $05, $1B
            db    $0C, $4E, $0E, $4A, $0A, $DB, $1B, $35
            db    $4E, $06, $45, $C5, $4E, $4E, $4E, $0E
            db    $45

ColumnHeapOWA
            db    $DB, $5B, $34, $4E, $4E, $1A, $1B, $DB
            db    $5B, $35, $4E, $4E, $1A, $1B, $9B, $35
            db    $4E, $4E, $4E, $0E, $33, $1B, $9B, $34
            db    $4E, $4E, $4E, $0E, $32, $1B, $9B, $34
            db    $4E, $4E, $4E, $0E, $1A, $1B, $9B, $35
            db    $4E, $4E, $4E, $0E, $1A, $1B, $DB, $5B
            db    $34, $0E, $32, $DB, $5B, $35, $0E, $33
            db    $5B, $DB, $34, $4E, $4E, $0E, $32, $DB
            db    $35, $4E, $4E, $0E, $33

ColumnHeapOWB
            db    $DB, $5B, $07, $4E, $4E, $4E, $DB, $0E
            db    $06, $05, $45, $2F, $0E, $1A, $1B, $DB
            db    $0E, $06, $05, $45, $2E, $0E, $1A, $1B
            db    $CA, $4A, $0A, $0E, $1A, $DB, $5B, $15
            db    $45, $45, $45, $DB, $4E, $4E, $4E, $0E
            db    $CA, $4E, $4E, $4E, $0E, $1A, $1B, $DB
            db    $4E, $2C, $0E, $2C, $4E, $1A, $1B, $CA
            db    $4A, $4E, $06, $45, $45

ColumnHeapOWC
            db    $9B, $35, $4E, $0E, $13, $4E, $0E, $1A
            db    $1B, $F6, $76, $0F, $4E, $1A, $1B, $5B
            db    $DB, $4D, $4D, $4D, $4D, $0D, $CE, $4E
            db    $0E, $30, $45, $45, $05, $DB, $F7, $F7
            db    $77, $77, $37, $77, $1A, $1B, $DB, $1B
            db    $34, $4E, $4E, $0E, $1A, $1B, $DB, $34
            db    $0E, $4E, $4E, $0E, $1A, $1B

ColumnHeapOWD
            db    $C5, $45, $0B, $4E, $4E, $4E, $DB, $0E
            db    $06, $45, $07, $4E, $4E, $9B, $27, $4E
            db    $4E, $4E, $0E, $1A, $1B, $9B, $27, $4E
            db    $4E, $4E, $4E, $0E, $DB, $1B, $27, $07
            db    $4E, $1A, $5B, $1B, $CE, $4E, $4E, $4E
            db    $33, $5B, $DB, $5B, $1B, $0E, $15, $48
            db    $48, $DB, $0E, $2D, $0C, $4E, $4E, $4A
            db    $DB, $0E, $1C, $1F, $0E, $1E, $20, $0E
            db    $1A, $1B

ColumnHeapOWE
            db    $C8, $48, $08, $C5, $45, $45, $08, $48
            db    $48, $DB, $35, $CE, $4E, $4E, $4E, $0E
            db    $33, $1B, $DB, $0E, $33, $5B, $27, $4E
            db    $1A, $1B, $DB, $4E, $4E, $1C, $1F, $0E
            db    $1A, $1B, $DB, $5B, $1B, $35, $4E, $33
            db    $DB, $5B, $1B, $34, $4E, $32, $DB, $4E
            db    $4E, $4E, $0E, $33

ColumnHeapOWF
            db    $9B, $5B, $34, $4E, $0E, $32, $DB, $1B
            db    $35, $4E, $0E, $33, $1B, $DB, $0E, $1E
            db    $20, $0E, $1C, $1F, $0E, $1A, $1B, $DB
            db    $4E, $4E, $1E, $20, $0E, $1A, $1B, $D9
            db    $59, $19, $4E, $4E, $59, $DB, $0E, $2D
            db    $0C, $4E, $4E, $1A, $1B, $CE, $4E, $0E
            db    $31, $05, $C5, $45, $07, $4E, $28, $59
            db    $19, $DB, $4D, $4D, $12, $4D, $1A, $1B
            db    $DB, $77, $77, $77, $37, $1A, $1B

RoomLayoutsOWAddr
            dw    RoomLayoutsOW

ColumnHeapOWAddr
            dw    ColumnHeapOW0

WallTileList
            db    $E0, $F5, $F5, $F5, $F5, $B8, $F5, $D4
            db    $F5, $F5, $F5, $C4, $DE, $DE, $BC, $C8
            db    $DE, $BC, $DE, $DE, $F5, $DC, $C4, $DE
            db    $C8, $DE, $BC, $C8, $DE, $DE, $F5, $DC
            db    $DC, $00, $C0, $D0, $DC, $00, $F5, $DC
            db    $CC, $00, $F5, $DC, $DC, $00, $F5, $CC
            db    $D0, $00, $F5, $DC, $DC, $00, $C0, $D0
            db    $DC, $00, $F5, $DC, $CC, $00, $F5, $DC
            db    $DC, $00, $D8, $CC, $D0, $00, $F5, $DC
            db    $DC, $00, $F5, $DC, $DC, $00

; 5 sets of 12 bytes laying out door faces facing E.
DoorFaceTilesE
            db    $88, $74, $8A, $24, $87, $87, $75, $89
            db    $24, $8B, $87, $87, $88, $A4, $8A, $A6
            db    $87, $87, $A5, $89, $A7, $8B, $87, $87
            db    $88, $AC, $8A, $AE, $87, $87, $AD, $89
            db    $AF, $8B, $87, $87, $DF, $DF, $DF, $DF
            db    $F5, $F5, $DF, $DF, $DF, $DF, $F5, $F5
            db    $DF, $24, $DF, $92, $F5, $F5, $24, $DF
            db    $93, $DF, $F5, $F5

; 5 sets of 12 bytes laying out door faces facing W.
DoorFaceTilesW
            db    $82, $82, $83, $24, $85, $76, $82, $82
            db    $24, $84, $77, $86, $82, $82, $83, $A0
            db    $85, $A2, $82, $82, $A1, $84, $A3, $86
            db    $82, $82, $83, $AC, $85, $AE, $82, $82
            db    $AD, $84, $AF, $86, $F5, $F5, $DE, $DE
            db    $DE, $DE, $F5, $F5, $DE, $DE, $DE, $DE
            db    $F5, $F5, $DE, $90, $DE, $24, $F5, $F5
            db    $91, $DE, $24, $DE

; 5 sets of 12 bytes laying out door faces facing S.
DoorFaceTilesS
            db    $7E, $7F, $7D, $76, $24, $7D, $74, $24
            db    $7D, $80, $81, $7D, $7E, $7F, $7D, $9C
            db    $9D, $7D, $9E, $9F, $7D, $80, $81, $7D
            db    $7E, $7F, $7D, $A8, $A9, $7D, $AA, $AB
            db    $7D, $80, $81, $7D, $DD, $DD, $F5, $DD
            db    $DD, $F5, $DD, $DD, $F5, $DD, $DD, $F5
            db    $DD, $DD, $F5, $24, $8E, $F5, $24, $8F
            db    $F5, $DD, $DD, $F5

; 5 sets of 12 bytes laying out door faces facing N.
DoorFaceTilesN
            db    $78, $79, $7A, $78, $24, $77, $78, $24
            db    $75, $78, $7B, $7C, $78, $79, $7A, $78
            db    $98, $99, $78, $9A, $9B, $78, $7B, $7C
            db    $78, $79, $7A, $78, $A8, $A9, $78, $AA
            db    $AB, $78, $7B, $7C, $F5, $DC, $DC, $F5
            db    $DC, $DC, $F5, $DC, $DC, $F5, $DC, $DC
            db    $F5, $DC, $DC, $F5, $8C, $24, $F5, $8D
            db    $24, $F5, $DC, $DC

RoomLayoutsUW
            putbin dat/RoomLayoutsUW.dat

ColumnHeapUW0
            db    $E1, $80, $C1, $00, $01, $A0, $04, $A0
            db    $01, $A0, $31, $90, $21, $90, $21, $00

ColumnHeapUW1
            db    $81, $00, $01, $04, $81, $00, $01, $00
            db    $01, $00, $81, $00, $21, $00, $81, $40
            db    $81, $20, $01, $00, $81, $00, $04, $00
            db    $01, $00, $01, $90, $41, $80

ColumnHeapUW2
            db    $D1, $80, $21, $00, $91, $20, $91, $00
            db    $01, $00, $11, $D0, $81, $00, $41, $B1
            db    $00

ColumnHeapUW3
            db    $91, $00, $A1, $00, $21, $B1, $06, $91
            db    $00, $B1, $00, $81, $00, $21, $90, $17
            db    $02

ColumnHeapUW4
            db    $91, $17, $01, $17, $81, $16, $B1, $07
            db    $91, $06, $31, $87, $31, $17, $81, $00
            db    $01, $03, $81, $00, $01, $02, $01

ColumnHeapUW5
            db    $80, $01, $10, $11, $83, $47, $83, $41
            db    $03, $D1, $03, $90, $01, $10, $91, $00
            db    $11, $90, $17, $03, $11, $C0, $11

ColumnHeapUW6
            db    $E0, $E6, $81, $C6, $81, $86, $01, $06
            db    $01, $06, $81, $06, $21, $86, $01, $26
            db    $01

ColumnHeapUW7
            db    $86, $41, $86, $01, $46, $D1, $02, $A6
            db    $01, $26, $81, $56, $81, $16, $11, $16
            db    $E7, $E5

ColumnHeapUW8
            db    $81, $10, $01, $10, $81, $27, $A1, $06
            db    $21, $80, $01, $10, $11, $82, $47, $82
            db    $41, $02, $80, $01, $10, $A1, $02, $A1
            db    $03, $21

ColumnHeapUW9
            db    $80, $27, $21, $81, $00, $02, $11, $00
            db    $81, $00, $03, $11, $00, $81, $02, $81
            db    $02, $01, $02, $01, $02, $05, $C1, $15
            db    $B1, $25, $81, $03, $81, $03, $01, $03
            db    $01, $03, $05

RoomLayoutUWCellar0
            db    $04, $04, $00, $01, $00, $00, $00, $00
            db    $00, $00, $00, $00, $01, $00, $04, $04

RoomLayoutUWCellar1
            db    $04, $04, $00, $01, $00, $00, $00, $03
            db    $03, $03, $03, $02, $03, $03, $04, $04

ColumnHeapUWCellar
            db    $82, $43, $43, $43, $02, $0C, $43, $80
            db    $41, $41, $41, $41, $43, $82, $43, $42
            db    $0C, $01, $41, $43, $82, $43, $42, $0C
            db    $03, $02, $0C, $43, $82, $43, $43, $43
            db    $43, $43

; Params:
; [02]: bitmask for target door.
;
; Returns:
; A: door type for desired direction in current room.
; [01]: same as [02] if found; $10 otherwise
; [03]: reverse direction index
;
; Door bits:
; 1: E
; 2: W
; 4: S
; 8: N
;
FindDoorTypeByDoorBit ENT
    LDA #$01                    ; Start with single-bit mask 1.
    STA $01
    LDA #$03                    ; Test 4 directions.
    STA $03

:LoopDoorBit
    LDY RoomId
    LDA LevelBlockAttrsA, Y     ; Get attr byte A for S/N doors.
    LDY $03
    CPY #$02
    BCC :Anon0107                      ; If counter >= 2, then get attr byte B instead for E/W doors.
    LDY RoomId
    LDA LevelBlockAttrsB, Y
:Anon0107
    STA $00                     ; Store either attribute byte in [$00].
    LDA $03
    AND #$01
    BNE :Anon0108                      ; If counter is even, then ...
    LSR $00                     ; Isolate N/W doors.
    LSR $00
    LSR $00
:Anon0108
    LSR $00                     ; Isolate S/E doors, if we jump here.
    LSR $00

    ; Now [$00] holds isolated door type attribute.
    ;
    ; Test mask passed in [$02] with current single-bit mask in [$01].
    LDA $02
    BIT $01
    BNE :Anon0109                      ; If they match, then go return door type for current direction.
    ASL $01                     ; Shift the single-bit mask left.
    DEC $03
    BPL :LoopDoorBit            ; Go test the next direction.
    ; Begin unverified code 1642C
    LDA #$08                    ; Else return an invalid door type.
    RTS
    ; End unverified code
:Anon0109
    LDA $00
    AND #$07
    RTS

ReachedTopWallBottom
    ; Read a zero tile. Reached the bottom of a top wall.
    ;
    ; Set up A and X to move top and bottom offsets to the next column.
    LDA #$13
    STA $06
    LDX #$19
    BNE MoveWallPtrs            ; Go move top and bottom pointers.

DecBottomOffset
    ; Subtract A=1 from bottom offset.
    JSR Sub1FromInt16At4
    JMP NextLoopWallTile        ; Go increment the wall tile list address, and continue.

FillWalls
    ; Load the address of WallTileList.
    LDA #<WallTileList
    STA $00
    LDA #>WallTileList
    STA $01

    ; Load the address of second tile in second row of PlayAreaTiles.
    ; This is where we'll start loading tiles for the room.
    LDA #$47
    STA $02
    LDA #$65
    STA $03

    ; Load the address of second last tile in second row of PlayAreaTiles.
    ; This is where we'll stop loading tiles for the room.
    LDA #$5A
    STA $04
    LDA #$65
    STA $05
    LDA #$0A                    ; Load $A pairs of tiles, top and bottom ($14 tiles total).
    STA $06
    LDY #$00

LoopWallTile
    LDA ($00), Y                ; Get a tile from wall tile list.
    BEQ ReachedTopWallBottom
    STA ($02), Y                ; Set the tile at the top and bottom locations.
    STA ($04), Y

    ; If the tile isn't the vertical line $DE nor anything >= $E2,
    ; then set the bottom tile to the next one, which is flipped
    ; vertically. For example, $E0 => $E1.
    CMP #$DE
    BEQ :Anon0110
    CMP #$E2
    BCS :Anon0110
    ADC #$01
    STA ($04), Y
:Anon0110
    LDA #$01                    ; Set A to advance to next tile in column.
    LDX #$01                    ; 1 means subtract 1 from bottom offset.
    DEC $06                     ; Decrement count.
    BNE MoveWallPtrs            ; If reached the end of the column,
    LDA #$0A                    ; then count $A tile pairs again.
    STA $06
    LDA #$0D                    ; Set A to advance to next column (at second tile).

    ; $1F means add this amount to bottom offset to move
    ; it to bottom of next column.
    LDX #$1F

MoveWallPtrs
    JSR AddToInt16At2           ; Increase top offset by 1 tile, or by another amount to get to the next column (at second tile).
    TXA                         ; We need the amount to add or subtract in A.
    DEX
    BEQ DecBottomOffset         ; If X was 1, then go subtract 1 from bottom offset.

    ; Else add the original X value to bottom offset,
    ; intending to move it to the bottom of the next column.
    JSR AddToInt16At4

NextLoopWallTile
    JSR Add1ToInt16At0          ; Increment the wall tile list address.
    CMP #<WallTileList + $4E
    BNE LoopWallTile            ; If wall tile list pointer hasn't reached the end ($94EE), go process tiles again. At this point, we'll have written the walls on the left half of the play area.

    ; Copy rotated 180 degrees, accounting for appropriate
    ; horizontal or vertical flipping of tiles.
    ;
    ; The source is in the top left.
    LDA #$30
    STA $02
    LDA #$65
    STA $03
    LDA #$EF                    ; The destination is the bottom right.
    STA $04
    LDA #$67
    STA $05

:LoopRotate
    LDA ($02), Y                ; Copy 1 tile.
    STA ($04), Y
    CMP #$DD
    BEQ :SwapWithVertical       ; If this is a horizontal line, then go flip it vertically.
    CMP #$E0                    ; Tiles >= $E0 don't need to be flipped.
    BCS :NextLoopRotate         ; Skip this if tile doesn't need to be flipped.
    CMP #$DC
    BCS :Anon0111                      ; If tile < $DC,
    ADC #$01                    ; then tile needs 2 added to rotate it 180 degrees.
    STA ($04), Y
:Anon0111
    CLC                         ; Tiles >= $DC only need 1 added to flip them.
    ADC #$01

:SetRotatedTile
    STA ($04), Y

:NextLoopRotate
    JSR Sub1FromInt16At4
    JSR Add1ToInt16At2
    CMP #$90                    ; Once source pointer reaches the middle ($6690), we're done.
    BNE :LoopRotate
    LDA $03
    CMP #$66
    BNE :LoopRotate
    RTS

:SwapWithVertical
    LDA #$DC
    BNE :SetRotatedTile

DoorBits
            db    $01, $02, $04, $08

DoorFaceTilesAddrsLo
            db    <DoorFaceTilesE
            db    <DoorFaceTilesW
            db    <DoorFaceTilesS
            db    <DoorFaceTilesN

DoorFaceTilesAddrsHi
            db    >DoorFaceTilesE
            db    >DoorFaceTilesW
            db    >DoorFaceTilesS
            db    >DoorFaceTilesN

PlayAreaDoorFaceAddrsLo
            db    <$67A1
            db    <$654F
            db    <$6676
            db    <$6665

PlayAreaDoorFaceAddrsHi
            db    >$67A1
            db    >$654F
            db    >$6676
            db    >$6665

NextDoorTileOffsets
            db    $14, $01, $01

DirIndexToDoorSecondHalfOffsets
            db    $02, $02, $2C, $2C

DirIndexToDoorColumnCount
            db    $03, $03, $02, $02

DirIndexToDoorRowCountMinusOne
            db    $01, $01, $02, $02

LayOutDoors
    ; Copies the right door face for the direction, type, and state
    ; of the door to the play area tile map.
    ;
    ; Also, clears door bits from CurOpenedDoors of doorways
    ; that are not true doors.
    LDX #$03

L_LayOutDoors_LoopDoors
    ; For each door, indexed by X, from 3 (N) to 0:
    LDA #$01

    ; For each half of a door, indexed by [06], from 1 to 0:
    ;
    ; [06] indicates whether we're handling the first half of
    ; the door: Left half for N/S, Top half for E/W.
    STA $06

L_LayOutDoors_LoopHalves
    TXA
    PHA                         ; Save the current direction index (door index).
    STA $0B                     ; [0B] holds direction index.
    LDA DoorBits, X
    STA $02                     ; [02] holds the direction (bit) for the current door.
    JSR FindDoorTypeByDoorBit

    ; Begin looking for the door face for the door type.
    ; In general, use the door type as the provisional face;
    ; except turn 4 into 8.
    CMP #$05
    BCS :DoneClosedPF           ; If door type > 4, go use it as the provisional face.
    CMP #$04
    BNE :ClearFromOpenedMask    ; Door type < 4, go process it.
    LDA #$08
    BNE :DoneClosedPF           ; Door type = 4, go use 8 as the provisional face.

:SetPF9
    ; We jump here if the door type is bombable and was opened.
    ; Change the provisional door face to value 9, which
    ; will become the "hole in the wall".
    LDA #$09
    BNE :DoneOpenPF

:ClearFromOpenedMask
    ; Door type < 4 (open or any wall), clear door bit from
    ; the mask of opened doors, because this is not a true door.
    PHA
    LDA $02                     ; [02] current direction
    EOR #$FF
    AND CurOpenedDoors
    STA CurOpenedDoors
    PLA

    ; Furthermore, if door type = 0, then use 4 as the provisional face.
    CMP #$01
    BCS :DoneClosedPF
    LDA #$04

:DoneClosedPF
    ; The door type (DT) has been mapped to a
    ; provisional door face value (PF) in %A as follows:
    ;
    ; DT PF Meaning
    ; -------------
    ; 0  4  open
    ; 1  1  wall
    ; 2  2  false wall
    ; 3  3  false wall 2
    ; 4  8  bombable
    ; 5  5  key
    ; 6  6  key 2
    ; 7  7  shutter
    ;
    ; Also at this point, the door bit in CurOpenedDoors
    ; has been cleared, if the type was "open" or any wall.
    PHA                         ; Save the provisional face.

    ; If the current direction points to a door that has been opened,
    ; then see if we need to set door flags.
    LDA CurOpenedDoors
    AND $02                     ; [02] current door direction
    TAX
    PLA                         ; Restore the provisional face.
    CPX $02
    BNE :DoneOpenPF

    ; The current direction points to a door that has been opened.
    ; It can only be "bombable", "key", "key 2", or "shutter".
    TAY                         ; Save provisional door face in Y register.
    PLA                         ; Get the direction index.
    PHA
    TAX                         ; Put direction index in X.
    TYA                         ; Restore provisional door face value.

    ; If provisional door face is not for a shutter, then
    ; it's for a "key" or "bombable". So, set the door's flag.
    ;
    ; Else it is for a shutter. Go set provisional door face to 4.
    CMP #$07
    BEQ :Anon0112                      ; If provisional door face is for "key" or "bombable",
    PHA
    JSR SetDoorFlag             ; then set the door's flag.
    PLA

    ; If the provisional door face = 8 (closed "bombable"),
    ; then go make it 9 (open "bombable").
    ; Else make it 4 (open "door").
    CMP #$08
    BEQ :SetPF9
:Anon0112
    LDA #$04

:DoneOpenPF
    ; For opened doors, the provisional door face has become:
    ;
    ; DT PF Meaning
    ; -------------
    ; 0  4  open
    ; 1  1  wall
    ; 2  2  false wall
    ; 3  3  false wall 2
    ; 4  9  bombable
    ; 5  4  key
    ; 6  4  key 2
    ; 7  4  shutter
    ; If handling the first half [06], then calculate OpenDoorwayMask.
    LDX $06
    BEQ :Anon0113
    LDX $0B                     ; [0B] direction index
    PHA
    JSR FindDoorTypeByDoorBit
    JSR CalcOpenDoorwayMask
    PLA
:Anon0113
    ; If provisional door face < 4 (any wall), then go loop another half,
    ; because the visible door face is already a wall.
    CMP #$04
    BCC :NextLoopDoorHalf

    ; For all other provisional face values, calculate:
    ; door face := provisional face - 3
    SEC
    SBC #$03
    TAY

    ; Furthermore, if the latest provisional door face >= 3, then
    ; subtract one.
    CPY #$03
    BCC :Anon0114
    DEY
:Anon0114
    ; Now Y holds the door face index (DFC closed, DFO opened) for the door type (DT).
    ;
    ; DT DFC DFO Meaning
    ; ------------------
    ; 0  1   1   open
    ; 4  4   5   bombable
    ; 5  2   1   key
    ; 6  2   1   key 2
    ; 7  3   1   shutter
    PLA                         ; Get the direction index.
    PHA
    JSR FetchDoorAddrsFaceTilesSrcAndPlayAreaDst

    ; If handling the second half, then offset to the second half
    ; of the tiles.
    LDA $06
    BNE :Anon0115
    LDA DirIndexToDoorSecondHalfOffsets, X    ; Advance destination tile address to the second half of door.
    JSR AddToInt16At0
    LDA #$06                    ; Advance source tile address to the second half of door.
    JSR AddToInt16At2
:Anon0115
    ; Fix Y at 0 for copying source tiles to destination.
    ; Pointers will be incremented instead of Y.
    LDY #$00
    LDA DirIndexToDoorColumnCount, X
    STA $05                     ; [05] holds the column count.

:LoopColumn
    ; For each column (3 or 2), indexed by [05] down to 1:
    PLA
    PHA                         ; Put the direction index in X.
    TAX

    ; For each row (2 or 3) in the door, indexed by X,
    ; starting from highest index down to 0:
    LDA DirIndexToDoorRowCountMinusOne, X
    TAX

:LoopRowTile
    LDA ($02), Y                ; Copy 1 door tile.
    STA ($00), Y
    JSR Add1ToInt16At2          ; Increment source tile address.
    LDA NextDoorTileOffsets, X  ; Get the offset needed for the next play area tile.
    JSR AddToInt16At0

    ; If we're at the last row, and the direction is horizontal (< 2), then
    ; go 1 more tile down, to start the next column at the right place.
    ; We have to compensate for the fact that E/W doors are 
    ; shorter vertically than N/S doors.
    CPX #$00
    BNE :Anon0116
    PLA                         ; Put direction index in A.
    PHA
    CMP #$02
    BCS :Anon0116                      ; If direction index is horizontal (< 2),
    JSR Add1ToInt16At0
:Anon0116
    ; Bottom of the tile row copying loop.
    ; Decrement the row index.
    DEX
    BPL :LoopRowTile

    ; Bottom of the column copying loop.
    ; Decrease the column counter.
    DEC $05
    BNE :LoopColumn

:NextLoopDoorHalf
    ; Bottom of the door halves loop.
    PLA
    TAX                         ; Restore X to the door index.
    DEC $06                     ; Decrement [06] door half counter.
    BMI :Anon0117
    JMP L_LayOutDoors_LoopHalves    ; then go handle it.
:Anon0117
    ; Bottom of the door loop.
    ; Decrement door index.
    DEX
    BMI L165D4_Exit             ; If finished the last door (X < 0), then return.
    JMP L_LayOutDoors_LoopDoors ; Go handle the next door.

; Params:
; A: direction index
; Y: face index
;
; Returns:
; X: direction index
; [$00:01]: address of door inside play area tile map
; [$02:03]: address of door tiles for direction and face
;
FetchDoorAddrsFaceTilesSrcAndPlayAreaDst
    TAX
    LDA DoorFaceTilesAddrsLo, X
    STA $02
    LDA DoorFaceTilesAddrsHi, X
    STA $03
    LDA PlayAreaDoorFaceAddrsLo, X
    STA $00
    LDA PlayAreaDoorFaceAddrsHi, X
    STA $01
:Anon0118
    DEY                         ; Add ($C * (face - 1)) to [$02:03].
    BEQ L165D4_Exit
    LDA #$0C
    JSR AddToInt16At2
    JMP :Anon0118

L165D4_Exit
    RTS

HorizontalDoorFaceIndexes
            db    $01, $03, $06, $08, $03, $05, $08, $0A
            db    $03, $06, $04, $07, $05, $08

HorizontalDoorFaceIndexesBaseOffsets
            db    $00, $04, $08, $0A

DoorVramAddrsHi
            db    $22, $22, $23, $21

DoorVramAddrsLo
            db    $5C, $42, $4F, $4F

DoorNextRoomIdOffsets
            db    $01, $FF, $10, $F0

UpdateDoors ENT
    ; If mode = $12, or door timer <> 0, or door command = 0,
    ; then return.
    LDA GameMode
    CMP #$12
    BEQ L165D4_Exit
    LDA DoorTimer
    BNE L165D4_Exit
    LDA TriggeredDoorCmd
    BEQ L165D4_Exit

    ; Turn the door command into the desired open or closed state
    ; to store in [08].
    ;
    ; cmd:  7 6 3 2 
    ; [08]: 2 0 0 0
    ;
    ; There are other combinations, but 2, 3, 6, and 7 are the only
    ; commands intended to be used.
    ;
    ; 3 is the end state of 2: close
    ; 7 is the end state of 6: open
    AND #$07
    LDY #$01
    STY $02
    BIT $02
    BEQ :Anon0119
    LSR
:Anon0119
    CMP #$02
    BNE :Anon0120

    ; Command 2 sets Link's timer to $30.
    LDY #$30
    STY ObjTimer
:Anon0120
    AND #$03
    SEC
    SBC #$01
    AND #$02
    STA $08

    ; The command to close a key door or bombable wall does not
    ; do anything.
    LDA TriggeredDoorCmd
    CMP #$05
    BCS :Anon0121
    LDA TriggeredDoorDir
    STA $02
    JSR FindDoorTypeByDoorBit
    CMP #$07
    BEQ :Anon0121
    JMP L_ResetDoorCmdAndLayOutDoors
:Anon0121
    ; TriggeredDoorCmd >= 5 or door type = 7
    ;
    ; Shutters and the commands to open a door always change
    ; tiles.
    JSR PrepareWriteHorizontalDoorTransferRecords

:LoopTransferRec
    ; Copy [06] to [04] for the call to write tiles below.
    ; We need to remember how many tiles need to be copied
    ; in each transfer record.
    LDA $06
    STA $04

    ; Write the transfer record header for the door.
    LDA $00                     ; VRAM address high byte of door
    STA DynTileBuf, X
    INX
    LDA $01                     ; VRAM address low byte of door
    STA DynTileBuf, X
    INX
    LDA $06                     ; 2 for 2 tiles
    STA DynTileBuf, X
    INX
:Anon0122
    ; Write two tiles in a short loop indexed by [04].
    JSR WriteDoorFaceTileHorizontally
    BNE :Anon0122

    ; OR the low VRAM address with $20 to go down one row
    ; in order to work on the second row of door tiles.
    LDA #$20
    ORA $01                     ; [01] low VRAM address
    STA $01

    ; Bottom of the loop.
    ; Loop again to write the second transfer record for the
    ; second pair of door tiles, if [05] has not reached 0.
    DEC $05
    BNE :LoopTransferRec

    ; Write the end marker, and update buffer length.
    LDA #$FF
    STA DynTileBuf, X
    TXA
    STA DynTileBufLen

    ; Increment the command.
    INC TriggeredDoorCmd

    ; If (new command AND 3) = 0, go update door flags and masks,
    ; and resetting the door command.
    ; This ends up catching original states 3 and 7.
    ;
    ; Else set door timer to 8 and return.
    LDA TriggeredDoorCmd
    AND #$03
    BEQ :Anon0123
    LDA #$08
    STA DoorTimer
    RTS
:Anon0123
    ; If the door command = 4 after incrementing it, then
    ; it was 3 (close door). So:
    ; 1. reset this door's flag
    ; 2. remove it from the opened door mask
    ; 3. reset the door command
    ; 4. go lay out doors in the play area map
    LDA TriggeredDoorCmd
    CMP #$04
    BNE :Anon0124
    LDX $09                     ; [09] door direction index
    JSR ResetDoorFlag
    LDA TriggeredDoorDir        ; Remove the triggered door from opened door mask.
    EOR #$0F
    AND CurOpenedDoors

L_SetOpenedDoorMaskAndResetCmdAndLayOutDoors
    STA CurOpenedDoors

L_ResetDoorCmdAndLayOutDoors
    LDA #$00                    ; Reset door command
    STA TriggeredDoorCmd
    JMP LayOutDoors
:Anon0124
    ; Door command <> 4.
    ; It must be 8, which means it was 7: open door.
    ;
    ; If the door is a shutter (7), then go add the door to the
    ; opened door mask, reset door command, and lay out doors.
    LDA TriggeredDoorDir
    STA $02
    JSR FindDoorTypeByDoorBit
    CMP #$07
    BEQ :Anon0125

    ; Else the door is not a shutter.
    LDX $09                     ; [09] door direction index
    JSR SetDoorFlag

    ; Get the next room's ID.
    TYA
    CLC
    ADC DoorNextRoomIdOffsets, X
    TAY

    ; Flip the door direction index.
    TXA
    EOR #$01
    TAX

    ; Set the door flag for the opposite door in the next room.
    LDA ($00), Y
    ORA LevelMasks, X
    STA ($00), Y
:Anon0125
    ; Add the door to the opened door mask, reset door command,
    ; and lay out doors.
    LDA TriggeredDoorDir
    ORA CurOpenedDoors
    JMP L_SetOpenedDoorMaskAndResetCmdAndLayOutDoors

; Params:
; [08]: 0 if closed
;
; Returns:
; X: current length of dynamic transfer buf
; [00]: door VRAM address high byte
; [01]: door VRAM address low byte
; [02:03]: address of door tiles for direction and face
; [05]: 2, the number of transfer records to write
; [06]: 2, the number of tiles in each record
; [07]: 0, the first index of a tile to transfer
; [09]: door direction index
;
; Note that this routine is called with triggered doors:
; doors that can change state. Their door type numbers are >= 4.
;
; If this routine were ever called with a fixed door
; ("open", "wall", or "false"), then it would produce non-sensical
; values for the door face.
;
PrepareWriteHorizontalDoorTransferRecords
    ; If triggered door type >= 5 (keys and shutter), play door sound.
    LDA TriggeredDoorDir
    STA $02
    JSR FindDoorTypeByDoorBit
    CMP #$05
    BCC :Anon0126
    PHA
    LDA #$04                    ; Door sound
    JSR PlaySample
    PLA
:Anon0126
    ; Calculate the door face index in three parts.
    ;
    ; First, turn door type 4 into 8, and 1 into 4
    ; (provisional face index in Y register).
    CMP #$04
    BNE :Anon0127
    LDA #$08
:Anon0127
    CMP #$01
    BNE :Anon0128
    ; Begin unverified code 166CD
    LDA #$04
    ; End unverified code
:Anon0128
    ; Second, subtract 3 from provisional face index.
    SEC
    SBC #$03
    TAY

    ; Lastly, if the door is closed ([08] = 0) and provisional
    ; face index >= 3, then subtract 1 from it.
    ;
    ; But if open ([08] <> 0) and provisional face index <> 5,
    ; then make it 1.
    LDA $08
    BEQ :Anon0129
    CPY #$05
    BEQ :MakeForwardIndex
    LDY #$01
:Anon0129
    CPY #$03
    BCC :MakeForwardIndex
    DEY

:MakeForwardIndex
    ; The routine that returned the door type also returned its
    ; reverse direction index in [03].
    ;
    ; We want a forward direction index. So, subtract [03] from 3.
    LDA #$03
    SEC
    SBC $03

    ; Call this to put the address of door face tiles in [02:03].
    JSR FetchDoorAddrsFaceTilesSrcAndPlayAreaDst

    ; Return the address of the door in the nametable in [01:00].
    ; Note the order is reversed, as usual with VRAM addresses.
    LDA DoorVramAddrsHi, X
    STA $00
    LDA DoorVramAddrsLo, X
    STA $01

    ; Return the direction of the door in [09], and the dynamic
    ; transfer buf length in X register.
    STX $09
    LDX DynTileBufLen

    ; Return some hardcoded values in [05], [06], [07]. See the comments above.
    LDA #$00
    STA $07
    LDA #$02
    STA $06
    STA $05
    RTS

ColumnDirectoryUW
            dw    ColumnHeapUW0
            dw    ColumnHeapUW1
            dw    ColumnHeapUW2
            dw    ColumnHeapUW3
            dw    ColumnHeapUW4
            dw    ColumnHeapUW5
            dw    ColumnHeapUW6
            dw    ColumnHeapUW7
            dw    ColumnHeapUW8
            dw    ColumnHeapUW9

PrimarySquaresUW
            db    $B0, $74, $94, $B4, $70, $68, $F4, $24

LayoutUWFloor
    JSR GetUniqueRoomId
    PHA                         ; Save unique room ID.
    LDA #<RoomLayoutsUW         ; Load the address of room column directory in [$02:03].
    STA $02
    LDA #>RoomLayoutsUW
    STA $03
    PLA                         ; Restore unique room ID.
    ASL                         ; Add ((unique room ID) * $C) to address in [$02:03]. Each unique room has $C columns.
    ASL
    STA $00
    JSR AddToInt16At2
    LDA $00
    JSR AddToInt16At2
    LDA $00
    JSR AddToInt16At2
    LDA #$8C                    ; Load the address of top-left tile in floor of play area in [$00:01].
    STA $00
    LDA #$65
    STA $01

    ; For each column in room, indexed by [06]:
    LDY #$00
    STY $06

:LoopColumnUW
    LDY $06
    LDA ($02), Y                ; Get a column descriptor.
    AND #$F0                    ; Put column table number * 2 in X.
    LSR
    LSR
    LSR
    TAX
    LDA ColumnDirectoryUW, X    ; Load the column table address for this descriptor in [$04:05].
    STA $04
    LDA ColumnDirectoryUW+1, X
    STA $05
    LDA ($02), Y                ; Get the column descriptor again.
    AND #$0F                    ; Put column index in X.
    TAX
    LDY #$00

:FindSquare
    LDA ($04), Y                ; Get a square descriptor.
    BPL :Anon0130                      ; If high bit is set,
    DEX                         ; then we've found the beginning of a column;
    BMI :FoundColumn            ; If this is the column we want, then go handle it.
:Anon0130
    INY                         ; Increment the square descriptor offset.
    JMP :FindSquare             ; Go get the next square descriptor.

:FoundColumn
    ; We found the column.
    TYA
    JSR AddToInt16At4           ; Advance the square descriptor pointer by the offset, so we don't have to keep the offset in Y.
    LDA #$00
    STA $07                     ; Reset processed row count.
    STA $08                     ; Reset repeat count.

:LoopSquareRow
    ; Write and repeat squares from the column.
    LDY #$00
    LDA ($04), Y                ; Get the square descriptor.
    AND #$07                    ; Get the square index from the descriptor.
    TAX
    LDA PrimarySquaresUW, X
    LDY #$00
    JSR WriteSquareUW
    LDA #$02                    ; Point to next square in column in play area.
    JSR AddToInt16At0
    LDY #$00
    LDA ($04), Y                ; Get the square descriptor.
    AND #$70                    ; Isolate the count.
    LSR
    LSR
    LSR
    LSR
    CMP $08
    BEQ :Anon0131                      ; If we haven't repeated this square as specified,
    INC $08                     ; then increment the processed repeat count;
    JMP :NextLoopSquareRow      ; and go increment the row, and check if we're done in this column.
:Anon0131
    LDA #$00                    ; Reset repeat count.
    STA $08
    JSR Add1ToInt16At4          ; Point to the next square descriptor.

:NextLoopSquareRow
    INC $07                     ; Increment the processed row count.
    LDA $07
    CMP #$07                    ; There are 7 square rows in UW floor.
    BCC :LoopSquareRow          ; If we haven't written 7 rows, then go process a square.
    LDA #$1E                    ; Move 2 columns right and to the top of the floor area.
    JSR AddToInt16At0
    INC $06                     ; Increment column index.
    LDA $06
    CMP #$0C
    BCS :Anon0132                      ; If we haven't processed all columns,
    JMP :LoopColumnUW           ; then go process the next one.
:Anon0132
    RTS

; Params:
; A: primary square
; Y: offset from [$00:01]
; [$00:01]: pointer to play area
;
WriteSquareUW
    CMP #$70
    BCC :WriteType2
    CMP #$F3
    BCS :WriteType2

    ; Type 1 square.
    ; Primary is the first tile. Next 3 tiles in CHR form the rest of the square.
    ; Primary >= $70 and < $F3.
    TAX
    STA ($00), Y                ; Write tile+0 to (col, row).
    INY
    INX
    TXA
    STA ($00), Y                ; Write tile+1 to (col, row+1).
    TYA
    CLC
    ADC #$15
    TAY
    INX
    TXA
    STA ($00), Y                ; Write tile+2 to (col+1, row).
    INX
    TXA

:WriteLastTile
    INY
    STA ($00), Y                ; Write last tile to (col+1, row+1).
    RTS

:WriteType2
    ; Type 2 square.
    ; Primary is a tile used for the whole square.
    ; Primary < $70 or >= $F3.
    STA ($00), Y                ; Write tile to (col, row).
    INY
    STA ($00), Y                ; Write tile to (col, row+1).
    PHA
    TYA
    CLC
    ADC #$15
    TAY
    PLA
    STA ($00), Y                ; Write tile to (col+1, row).
    JMP :WriteLastTile          ; Go write tile to (col+1, row+1).

FindAndCreatePushBlockObject
    ; Reset block state and direction.
    LDA #$00
    STA ObjState+11
    STA ObjDir+11

    ; If the unique room ID is $21, then
    ; put the push block object at ($40, $80), and go set the type.
    ;
    ; UNKNOWN:
    ; UW room layout $21 is the entrance room. But none of them
    ; have the push block flag set in LevelBlock attributes.
    JSR GetUniqueRoomId
    CMP #$21
    BNE :Anon0133
    ; Begin unverified code 167FE
    LDA #$40
    STA ObjX+11
    ASL
    STA ObjY+11
    JMP :SetType                ; Go set the object type and return.
    ; End unverified code
:Anon0133
    ; Look for a block tile in row $A of play area, starting in column 4.
    LDX #$08
    LDY #$0A

:LoopColumn
    LDA PlayAreaColumnAddrs, X
    STA $00
    LDA PlayAreaColumnAddrs+1, X
    STA $01
    LDA ($00), Y
    CMP #$B0
    BEQ :Found
    INX
    INX
    INX
    INX
    CPX #$34
    BNE :LoopColumn

:Found
    ; The block was found in a column with an address at
    ; offset %X in column table. So the column number would
    ; be (%X/2), and X coordinate ((%X/2)*8). That means
    ; multiplying %X by 4.
    TXA
    ASL
    ASL
    STA ObjX+11
    LDA #$90                    ; Row $A is at $90 from the top of the screen.
    STA ObjY+11

:SetType
    LDA #$68                    ; Block object type
    STA ObjType+11
    RTS

InitMode12 ENT
    LDA #$04                    ; Play "End Level" song.
    STA SongRequest
    LDA #$20                    ; Set decreasing column for UpdateWorldCurtainEffect.
    STA ObjX+12
    LDA #$01                    ; Set increasing column for UpdateWorldCurtainEffect.
    STA ObjX+13
    LDA #$30                    ; Set to delay $2F ($30-1) frames when updating mode.
    STA ObjTimer
    LDA #$24                    ; Fill tile map with blanks.
    STA $0A
    JSR FillTileMap
    INC IsUpdatingMode
    JSR HideObjectSprites
    LDA #$1B                    ; Triforce item type.
    STA ItemTypeToLift
    JMP SetUpAndDrawLinkLiftingItem

UpdateMode12EndLevel_Full ENT
    JSR HideObjectSprites
    JSR DrawLinkLiftingItem
    LDA GameSubmode
    JSR TableJump

UpdateMode12EndLevel_Full_JumpTable
            dw    UpdateMode12EndLevel_Sub0
            dw    UpdateMode12EndLevel_Sub1
            dw    UpdateMode12EndLevel_Sub2
            dw    UpdateMode12EndLevel_Sub3
            dw    UpdateMode12EndLevel_Sub4

UpdateMode12EndLevel_Sub0
    LDA ObjTimer
    BNE L16887_Exit             ; Delay (return) until timer expires.
    LDA #$30                    ; Set to run next submode for $2F ($30-1) frames.
    STA ObjTimer
    BNE L1688C_IncSubmode

UpdateMode12EndLevel_Sub1
    ; Flash the screen.
    ;
    ; $18 is LevelPaletteTransferBuf.
    LDY #$18
    LDA ObjTimer
    BEQ StartFillingHearts
    AND #$07                    ; Every 4 frames, switch palettes.
    CMP #$04
    BCC :Anon0134
    LDY #$78                    ; WhitePaletteBottomHalfTransferBuf
:Anon0134
    STY TileBufSelector

L16887_Exit
    RTS

StartFillingHearts
    ; Start filling hearts, and go to next submode.
    ;
    ; UNKNOWN: Why 2? Either way, non-zero works.
    LDA #$02
    STA World_IsFillingHearts

L1688C_IncSubmode
    INC GameSubmode
    RTS

UpdateMode12EndLevel_Sub2
    JSR UpdateHeartsAndRupees
    LDA World_IsFillingHearts
    BEQ :Anon0135                      ; If finished filling hearts, then go set the timer for the next submode.
    RTS

UpdateMode12EndLevel_Sub3
    LDA ObjTimer
    BNE :Anon0136
    JSR UpdateWorldCurtainEffect
    LDA ObjX+12
    CMP #$11
    BCS :Anon0136                     ; If decreasing column hasn't reached the middle (still >= $11), then return.
:Anon0135
    LDA #$80                    ; Set up a delay of $7F ($80-1) frames for next submode.
    STA ObjTimer
    INC GameSubmode
:Anon0136
    RTS

UpdateMode12EndLevel_Sub4
    LDA ObjTimer
    BNE :Anon0136
    JSR HideAllSprites
    LDA CurPpuControl_2000
    AND #$FB                    ; Make sure VRAM address increment is 1.
    STA CurPpuControl_2000
            JSR   STA_2000
    JMP EndGameMode12
:Anon0137
    ; Is in OW.
    JSR LayoutRoomOW
    JMP CheckShortcut

LayOutRoom
    JSR PatchColumnDirectoryForCellar
    LDA CurLevel
    BEQ :Anon0137

    ; Is in UW.
    ;
    ; Fill PlayArea with brick tiles that are seen at the margins.
    LDA #$F6
    STA $0A
    JSR FillTileMap
    JSR AddDoorFlagsToCurOpenedDoors
    JSR FillWalls
    JSR LayOutDoors
    JMP LayoutUWFloor

; Params:
; CurColumn: target column + 1
;
; Put $651A in [$00:01]; $16 before $6530 which is the tile map address.
;
; The first iteration of the loop below will add $16 to it before using it.
CopyColumnToTileBuf ENT
    LDA #$1A
    STA $00
    LDA #$65
    STA $01
    LDX CurColumn
    DEX                         ; Start with X = CurColumn - 1
    TXA
    LDY DynTileBufLen           ; Fill dynamic transfer buf from last position written.
    STA DynTileBuf+1, Y         ; Use PPU address $21xx: a tile along the first row in play area.
    LDA #$21
    STA DynTileBuf, Y
:Anon0138
    ; Keep adding $16 until you point to the target column.
    LDA #$16
    JSR AddToInt16At0
    DEX
    BPL :Anon0138
    LDA #$96                    ; $96: $16 tiles, vertically in nametable.
    STA DynTileBuf+2, Y
    TXA                         ; X is $FF. Use it as the end marker.
    STA DynTileBuf+25, Y
    TYA                         ; Move the dynamic transfer buf offset to X.
    TAX
    LDY #$00                    ; Reset the tile counter in [$06] and Y.
    STY $06
:Anon0139
    LDA ($00), Y                ; Load source tile in TileMap.
    STA DynTileBuf+3, X         ; Store it in dynamic transfer buf.
    JSR Add1ToInt16At0          ; Increment the source address.
    INX                         ; Increment the destination offset.
    INC $06                     ; Increment the counter.
    LDA $06
    CMP #$16
    BCC :Anon0139                      ; If we haven't copied $16 tiles, then loop again.
    INX
    INX
    INX
    STX DynTileBufLen
    RTS

CopyRowToTileBuf
    ; Put in 00:01 the address of the
    ; first tile of current row in play area.
    LDA #$65
    STA $01
    LDA CurRow
    TAX
    CLC
    ADC #$30
    STA $00
    BCC :Anon0140
    ; Begin unverified code 16932
    INC $01
    ; End unverified code
:Anon0140
    ; Indicate the target VRAM address:
    ; $2100 + (CurRow * $20)
    LDA #$20
    STA DynTileBuf
    LDA #$E0
    STA DynTileBuf+1

:Add20H
    LDA DynTileBuf+1
    CLC
    ADC #$20
    STA DynTileBuf+1
    BCC :Anon0141
    INC DynTileBuf
:Anon0141
    DEX
    BPL :Add20H
    LDA #$20                    ; Indicate 32 bytes to copy.
    STA DynTileBuf+2
    STX DynTileBuf+35           ; Put an end marker.

    ; Copy a row from column map in RAM to tile buf.
    LDX #$00
    LDY #$00
:Anon0142
    LDA ($00), Y                ; Copy a tile.
    STA DynTileBuf+3, X
    LDA #$16
    JSR AddToInt16At0           ; Advance to the tile in the same row, but next column of play area.
    INX                         ; Advance to the next tile in the row in transfer buf.
    CPX #$20
    BCC :Anon0142                      ; If we haven't written $20 tiles, then go write another.
    LDA #$23                    ; The transfer buf is $23 bytes (3 for header, $20 for payload).
    STA DynTileBufLen
    RTS

TileObjectTypes
            db    $62, $63, $64, $65, $66, $67

TileObjectPrimarySquaresOW
            db    $C8, $D8, $C4, $BC, $C0, $C0

PrimarySquaresOW
            db    $24, $6F, $F3, $FA, $98, $90, $8F, $95
            db    $8E, $90, $74, $76, $F3, $24, $26, $89
            db    $03, $04, $70, $C8, $BC, $8D, $8F, $93
            db    $95, $C4, $CE, $D8, $B0, $B4, $AA, $AC
            db    $B8, $9C, $A6, $9A, $A2, $A0, $E5, $E6
            db    $E7, $E8, $E9, $EA, $C0, $E0, $78, $7A
            db    $7E, $80, $CC, $D0, $D4, $DC, $89, $84

SecondarySquaresOW
            db    $24, $24, $24, $24, $6F, $6F, $6F, $6F
            db    $F3, $F3, $F3, $F3, $FA, $FA, $FA, $FA
            db    $98, $95, $26, $26, $90, $95, $90, $95
            db    $8F, $90, $8F, $90, $95, $96, $95, $96
            db    $8E, $93, $90, $95, $90, $95, $92, $97
            db    $74, $74, $75, $75, $76, $77, $76, $77
            db    $F3, $24, $F3, $24, $24, $24, $24, $24
            db    $26, $26, $26, $26, $89, $88, $8B, $88

LayoutRoomOW
    ; Load the address of room column directory in [$02:03].
    LDA RoomLayoutsOWAddr
    STA $02
    LDA RoomLayoutsOWAddr+1
    STA $03
    LDA #$00                    ; Reset [06] for use in multiplication below.
    STA $06
    LDX RoomId                  ; Get unique room ID (OW).
    LDA LevelBlockAttrsD, X     ; The low 6 bits have the unique room ID.

    ; Add ((unique room ID) * $10) to address in [$02:03]. Each unique room has $10 columns.
    ASL
    ASL
    ROL $06
    ASL
    ROL $06
    ASL
    ROL $06
    ADC $02
    STA $02
    LDA $06
    ADC $03
    STA $03

; Params:
; [02:03]: address of room column directory
;
; Load the address of world flags in [$08:09].
;
LayoutRoomOrCaveOW
    LDA LevelInfo_WorldFlagsAddr
    STA $08
    LDA LevelInfo_WorldFlagsAddr+1
    STA $09
    JSR FetchTileMapAddr

    ; For each column in room, indexed by [06]:
    LDA #$00
    STA $0C                     ; Reset [$0C] used for tracking repeat state.
    STA $06

:LoopColumnOW
    LDY $06
    LDA ($02), Y                ; Get a column descriptor.
    AND #$F0                    ; Put column table number * 2 in X.
    LSR
    LSR
    LSR
    TAX

    ; Load the column table address for this descriptor in [$04:05].
    LDA ColumnDirectoryOW, X
    STA $04
    LDA ColumnDirectoryOW+1, X
    STA $05
    LDA ($02), Y                ; Get the column descriptor.
    AND #$0F                    ; Put column index in X.
    TAX
    LDY #$FF
:Anon0143
    ; Look for the beginning of a column.
    INY
    LDA ($04), Y                ; Get a square descriptor.
    BPL :Anon0143                      ; If high bit is clear, then go read the next square descriptor.
    DEX
    BPL :Anon0143                      ; If this isn't the column we want, then go keep looking.

    ; We found the column.
    TYA
    JSR AddToInt16At4           ; Advance the square descriptor pointer by the offset, so we don't have to keep the offset in Y.
    LDA #$00                    ; Reset row number in [07].
    STA $07

:LoopSquareOW
    LDY #$00
    LDA ($04), Y                ; Get the square descriptor.
    AND #$3F                    ; Get square index and put it in [$0D] and X.
    STA $0D
    TAX
    LDA PrimarySquaresOW, X
    PHA                         ; Save primary square.
    LDY RoomId                  ; Get room flags.
    LDA ($08), Y
    AND #$80
    BEQ :SkipSecret             ; If the secret wasn't found in this room, then skip all this.
    PLA                         ; Restore primary square.

    ; The secret was found in this room.
    CMP #$E7
    BEQ :MakeStairs             ; If this is a tree, go turn it into stairs.
    CMP #$E6
    BEQ :MakeCave               ; If this is a rock wall, go turn it into a cave entrance.
    CMP #$EA
    BNE :RestoreSquare          ; If this not a special armos, go leave the primary as is.

:MakeStairs
    ; This is a tree or a special armos ($EA).
    ; Set the primary to stairs ($70), and square index to the
    ; first value ($10) for a type 1 square.
    LDA #$10
    STA $0D
    LDA #$70
    BNE :RestoreSquare

:MakeCave
    ; This is a rock wall. Turn it into a cave entrance.
    LDA #$0C
    STA $0D

:RestoreSquare
    PHA

:SkipSecret
    PLA                         ; Restore primary square, if it wasn't modified above.
    JSR CheckTileObject
    LDY #$00
    JSR WriteSquareOW
    LDA #$02                    ; Point to next square in column in play area.
    JSR AddToInt16At0
    LDY #$00
    LDA ($04), Y                ; Get square descriptor.
    AND #$40
    BEQ :NextSquare             ; If we need to repeat this tile,
    EOR $0C                     ; then flip [$0C].
    STA $0C
    BNE :Anon0144                      ; After the second time flipping it, [$0C] = 0, and we've repeated it once. So,

:NextSquare
    JSR Add1ToInt16At4          ; Point to the next square descriptor.
:Anon0144
    INC $07                     ; Increment the processed row count.
    LDA $07
    CMP #$0B                    ; There are $B square rows in the play area.
    BNE :LoopSquareOW           ; If we haven't written $B rows, then go process a square.

    ; At the end of a column, we've reached the top of the next one.
    ; Move one more column over to get to the next square column.
    LDA #$16
    JSR AddToInt16At0
    INC $06                     ; Increment column index.
    LDA $06
    CMP #$10
    BCS L16AF0_Exit             ; If we have processed all columns, then return.
    JMP :LoopColumnOW           ; Go process the next one.

; Params:
; A: primary square
;
; Returns:
; A: primary square corresponding to tile object, else argument
;
; Tile object primary squares $E9 and $EA are unused; which
; means that tile object types $66 and $67 are unused.
; Instead, armos is represented by primary square $C0.
;
CheckTileObject
    ; Find the index X corresponding to the primary square: $E5  => 0; $EA => 5.
    LDX #$EA
    STX $0A
    LDX #$05
:Anon0145
    CMP $0A
    BEQ :Anon0146                      ; If we found the primary, go handle it.
    DEC $0A
    DEX
    BPL :Anon0145
    BMI L16AF0_Exit             ; If the primary isn't between $E5 to $EA, then return.
:Anon0146
    LDA TileObjectPrimarySquaresOW, X
    PHA                         ; Save primary square.
    LDA TileObjectTypes, X
    STA RoomTileObjType
    LDA $06                     ; Get current column in play area where we'll put a square.
    ASL                         ; Store the X coordinate of tile object (column * $10).
    ASL
    ASL
    ASL
    STA RoomTileObjX
    LDA $07                     ; Get current row in play area where we'll put a square.
    ASL                         ; Store the Y coordinate of tile object ((row * $10) + $40).
    ASL
    ASL
    ASL
    CLC
    ADC #$40
    STA RoomTileObjY
    PLA                         ; Restore primary square.

L16AF0_Exit
    RTS

; Params:
; A: primary square
; Y: offset from [$00:01]
; [$0D]: square index
; [$00:01]: pointer to play area
;
WriteSquareOW
    LDX $0D                     ; Get square index.
    CPX #$10
    BCC :WriteType3             ; If square index < $10, go handle a secondary square.

    ; Type 1 square.
    ; Primary is the first tile. Next 3 tiles in CHR form the rest of the square.
    ; Square index >= $10.
    TAX
    STA ($00), Y                ; Write tile+0 to (col, row).
    INY
    INX
    TXA
    STA ($00), Y                ; Write tile+1 to (col, row+1).
    TYA
    CLC
    ADC #$15
    TAY
    INX
    TXA
    STA ($00), Y                ; Write tile+2 to (col+1, row).
    INX
    TXA

:WriteLastTile
    INY
    STA ($00), Y                ; Write last tile to (col+1, row+1).
    RTS

:WriteType3
    ; Type 3 square.
    ; Square index refers to a set of 4 tile indexes in secondary squares table.
    ; Square index < $10.
    TXA                         ; X := (square index * 4)
    ASL
    ASL
    TAX
    LDA SecondarySquaresOW, X
    STA ($00), Y                ; Write tile+0 to (col, row).
    INY
    INX
    LDA SecondarySquaresOW, X
    STA ($00), Y                ; Write tile+1 to (col, row+1).
    TYA
    CLC
    ADC #$15
    TAY
    INX
    LDA SecondarySquaresOW, X
    STA ($00), Y                ; Write tile+2 to (col+1, row).
    INX
    LDA SecondarySquaresOW, X
    JMP :WriteLastTile          ; Go write tile+3 to (col+1, row+1).

PatchColumnDirectoryForCellar
    ; In OW, set first address of directory to start of OW column heap, as expected.
    LDA ColumnHeapOWAddr
    LDX ColumnHeapOWAddr+1
    LDY CurLevel
    BEQ :Anon0147

    ; In UW, set the first address of column directory to start of UW cellar column heap.
    LDA #<ColumnHeapUWCellar
    LDX #>ColumnHeapUWCellar
:Anon0147
    STA ColumnDirectoryOW
    STX ColumnDirectoryOW+1
    RTS

SubroomLayoutAddrs
            dw    RoomLayoutOWCave0
            dw    RoomLayoutOWCave1
            dw    RoomLayoutUWCellar0
            dw    RoomLayoutUWCellar1

LayoutCaveAndAvanceSubmode
    LDX #$00                    ; Usual cave
:Anon0148
    LDA SubroomLayoutAddrs, X
    STA $02
    LDA SubroomLayoutAddrs+1, X
    STA $03
    INC GameSubmode
    JMP LayoutRoomOrCaveOW

LayoutShortcutAndAdvanceSubmode
    LDX #$02                    ; Offset of address of column directory of shortcut cave
    BNE :Anon0148

LayoutCellarAndAdvanceSubmode
    ; Reset CurRow for when we start transferring rows
    ; after laying out the room.
    LDA #$00
    STA CurRow

    ; Get the offset of column directory address for the kind of cellar:
    ; - tunnel $3E:   offset 4
    ; - treasure $3F: offset 6
    LDX #$04
    JSR GetUniqueRoomId
    AND #$01
    BEQ :Anon0148
    LDX #$06
    BNE :Anon0148

CheckShortcut
    JSR GetRoomFlags
    ASL
    BCS :Exit                   ; If the player found the secret, then return.
    LDA ($00), Y
    AND #$20
    BEQ :Exit                   ; If the shortcut wasn't seen in this room, then return.
    JSR FetchTileMapAddr
    JSR GetShortcutOrItemXY

    ; Divide X coordinate by 4 to get offset into column address table.
    ; Think of it this way. Divide X by 8 to get tile column number.
    ; Then multiply by 2 to turn it into an offset for an address.
    LSR
    LSR
    TAX
    LDA PlayAreaColumnAddrs, X  ; Put address of column that has X coordinate into [$00:01].
    STA $00
    LDA PlayAreaColumnAddrs+1, X
    STA $01
    TYA                         ; Subtract $40 from X coordinate to get rid of status bar.
    SEC
    SBC #$40
    LSR                         ; Divide new Y coordinate by 8 to get a tile row.
    LSR
    LSR
    TAY                         ; Keep tile row (offset) in Y register.
    LDA ($00), Y                ; Get the tile that's where the shortcut should be.
    CMP #$C4
    BEQ :WriteStairs            ; If it's a tree, go prepare a stairs square.
    CMP #$BC
    BEQ :Exit                   ; If it's a gravestone, then return.
    CMP #$D8
    BNE :WriteStairs            ; If it's not a rock wall, then go prepare a stairs square.
    LDA RoomTileObjType
    CMP #$62
    BEQ :WriteStairs            ; If the room's tile object is a rock, go prepare a stairs square.

    ; Else make the tile object nothing, and write a black tile.
    ; But this branch seems to be unused.
    ; Begin unverified code 16BAF
    LDA #$00
    STA RoomTileObjType
    LDA #$0C
    STA $0D
    ; End unverified code

:Write
    JSR WriteSquareOW

:Exit
    RTS

:WriteStairs
    LDA #$10                    ; The first type 1 square index.
    STA $0D
    LDA #$70
    BNE :Write                  ; Go write a stairs square.

ChangePlayMapSquareOW ENT
    TXA                         ; Save object index.
    PHA

    ; We're dealing with squares.
    ; So, align the object's X coordinate with 16 pixels.
    LDA ObjX, X
    AND #$F0

    ; Divide it by 4 to get the offset of the address of the column
    ; in play area map.
    ;
    ; The calculation is: address offset = (X / 8) * 2
    ; 8 for the width of the column; 2 for the width of the address
    LSR
    LSR
    TAX

    ; Store the address of the column in [00:01].
    LDA PlayAreaColumnAddrs, X
    STA $00
    LDA PlayAreaColumnAddrs+1, X
    STA $01
    PLA                         ; Get object index.
    PHA
    TAX

    ; Align the object's Y coordinate with 16 pixels.
    LDA ObjY, X
    AND #$F0

    ; Subtract $40 for the status bar; and divide by 8 for
    ; the height of each row.
    SEC
    SBC #$40
    LSR
    LSR
    LSR

    ; Add this row offset to the column address.
    JSR AddToInt16At0

    ; Assume that we'll write a type 1 square with primary square
    ; taken from [05]. If so, the square index doesn't matter
    ; as long as >= $10. See WriteSquareOW.
    LDY #$00
    LDX #$10
    LDA $05

    ; If tile < $27 or >= $F3, we'll write a type 3 square.
    ; So, we have to look up the square index corresponding
    ; to primary square/tile in [05].
    ;
    ; Look in primary square table from $E to 1. If a match is found,
    ; then the X register will have the square index value.
    CMP #$27
    BCC :Anon0149
    CMP #$F3
    BCC :Write
:Anon0149
    LDX #$0E
:Anon0150
    CMP PrimarySquaresOW, X
    BEQ :Write
    DEX
    BNE :Anon0150

:Write
    ; Write the square.
    STX $0D
    JSR WriteSquareOW
    PLA                         ; Restore object index.
    TAX
    RTS

; Returns:
; [$00:01]: address of room tile map
FetchTileMapAddr ENT
    LDA #$30
    STA $00
    LDA #$65
    STA $01
    RTS

; Returns:
; C: 1 if copied the last row
;
CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone
    JSR CopyNextRowToTransferBuf
    BCS :Anon0151                      ; If done, then go to the next submode.
    RTS

; Returns:
; C: 1 if copied the last row
;
CopyNextRowToTransferBuf
    JSR CopyRowToTileBuf
    INC CurRow
    LDA CurRow
    CMP #$16
    RTS

LayoutRoom_SubmodeTask
    JSR LayOutRoom
    LDA #$00
    STA CurRow
:Anon0151
    INC GameSubmode
    RTS

; Unknown block
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
            db    $FF, $FF, $FF, $FF, $FF, $FF

InitMode3_Sub2 ENT
    LDA RoomId
    JSR FillPlayAreaAttrs
    LDA #$18
    BNE SelectTransferBuf       ; Go cue a transfer of palettes, and go to next submode.

InitMode3_Sub3_TransferTopHalfAttrs ENT
    LDA #$D0                    ; Low byte of destination PPU address for NT attributes.
    LDY #$17                    ; Offset of the end of first half of play area NT attributes.
:Anon0152
    JMP CueTransferPlayAreaAttrsHalfAndAdvanceSubmodeNT0

InitMode3_Sub4_TransferBottomHalfAttrs ENT
    LDA #$E8                    ; Low byte of destination PPU address for NT attributes.
    LDY #$2F                    ; Offset of the end of second half of play area NT attributes.
    BNE :Anon0152

InitMode3_Sub5 ENT
    LDA #$0E                    ; Cue transfer of static elements of status bar.

SelectTransferBuf
    STA TileBufSelector

L1701A_Exit
    INC GameSubmode
    RTS

InitMode3_Sub6 ENT
    LDA CurLevel
    BEQ :Anon0153                      ; If in OW, skip checking the level's map.
    JSR HasMap
    BEQ L1701A_Exit             ; If we don't have the map, go to the next submode.
:Anon0153
    LDA #$44
    BNE SelectTransferBuf       ; Cue transfer of map in status bar, and go to next submode.

InitMode3_Sub7 ENT
    LDA LevelInfo_LevelNumber
    BEQ L1701A_Exit             ; If level is OW, then go to next submode.
    STA LevelNumberTransferBuf+9    ; Patch the level number character in "LEVEL-X" transfer buf.
    LDA #$0C                    ; Cue transfer of "LEVEL-X" text and go to next submode.
    BNE SelectTransferBuf

InitMode3_Sub8 ENT
    JSR LayOutRoom

    ; Set up columns numbers for curtain effect.
    ;
    ; Decrease from column $F ($10-1).
    LDY #$10
    STY ObjX+12
    INY                         ; Increase from column $10 ($11-1).
    STY ObjX+13
    LDA #$00                    ; TODO: ?
    STA $17
    LDA #$08                    ; Make Link face up by default.
    STA ObjDir
    LDA #$78                    ; Put Link in the middle horizontally by default.
    STA ObjX
    LDA LevelInfo_StartY        ; Put Link at StartY from level info by default.
    STA ObjY
    JMP BeginUpdateMode

; Description:
; Two sets of 5 elements:
; * left bound for objects
; * right bound for objects
; * up bound for objects
; * down bound for objects
; * first unwalkable tile
;
; The first set is for OW. The second is for UW.
;
ObjectRoomBoundsOW
            db    $11, $E0, $4E, $CD, $89

ObjectRoomBoundsUW
            db    $21, $D0, $5E, $BD, $78

SetupObjRoomBounds ENT
    LDY #$05                    ; Offset of second set of bounds.
    LDA CurLevel
    BNE :Anon0154                      ; If in UW, use second of bounds, and go copy them.

    ; Reset DoorwayDir and use first set of bounds.
    LDY #$00                    ; Offset of first set of bounds.
    STY DoorwayDir
:Anon0154
    LDX #$00
:Anon0155
    LDA ObjectRoomBoundsOW, Y
    STA RoomBoundLeft, X
    INY
    INX
    CPX #$05
    BNE :Anon0155
    RTS

LeavingRoomRelativePositions
            db    $28, $D8, $00

InitMode6 ENT
    JSR ResetPlayerState
    JSR DrawSpritesBetweenRooms
    LDA CurLevel
    BEQ :Anon0156                      ; If in UW,
    JSR WriteBlankPrioritySprites    ; then clear the sprites that go above all the rest.
:Anon0156
    JSR Link_EndMoveAndAnimateBetweenRooms
    JSR SaveKillCount
    LDA CurLevel
    BEQ :SetWalkDistance0
    JSR GetPassedDoorType       ; Get door type in direction we're facing

    ; If the door type is "false wall",
    ; then play the "found secret" tune.
    PHA
    AND #$07
    CMP #$02
    BNE :Anon0157
    LDA #$04                    ; Play "found secret" tune.
    STA Tune1Request
:Anon0157
    PLA

    ; If the player is at an "open", "key", or "shutter" door,
    ; then the player walked all the way to the edge of the play
    ; area. So, use index 2 to set Link's relative position to 0.
    ;
    ; Otherwise, the player is at wall level. Link has to walk to the
    ; edge of the play area. So, set a relative position that
    ; reflects that distance: $28 or -$28.
    ;
    ; If walking in a decreasing direction (left or up), then
    ; Link's relative position is $28 and has to decrease to 0.
    ;
    ; If walking in an increasing direction (right or down), then
    ; Link's relative position is -$28 and has to increase to 0.
    AND #$07
    CMP #$02
    BCC :SetWalkDistance0
    CMP #$05
    BCC :Anon0158

:SetWalkDistance0
    LDY #$02
:Anon0158
    LDA LeavingRoomRelativePositions, Y
    STA ObjGridOffset
    JSR RunCrossRoomTasksAndBeginUpdateMode

ResetInvObjState ENT
    ; Reset LadderSlot. No ladder is active.
    LDA #$00
    STA LadderSlot

    ; Reset ObjState of all weapons.
    LDY #$05
:Anon0159
            JSR   STA_ObjStatep13_Y
    DEY
    BPL :Anon0159
    RTS

; Returns door type in direction Link's facing (mode 6),
; or opposite direction (other modes).
;
; Returns:
; A: door type
; Y: whether Link is facing an increasing direction (right or down)
;
GetPassedDoorType
    ; If Link's direction is right or down, then 1 will be returned.
    ; Else 0.
    LDY #$00
    LDA ObjDir
    AND #$05
    BEQ :Anon0160
    INY
:Anon0160
    STY $0F

    ; If in mode 6, use Link's direction to get a door type.
    ; Else use the opposite direction.
    LDA ObjDir
    LDY GameMode
    CPY #$06
    BEQ :Anon0161
    JSR GetOppositeDir
:Anon0161
    STA $02
    JSR FindDoorTypeByDoorBit
    LDY $0F
    RTS

; Params:
; X: high PPU address
; A: low PPU address
; Y: end offset in PlayAreaAttrs to copy from
;
CopyPlayAreaAttrsHalfToDynTransferBuf
    STX DynTileBuf
    STA DynTileBuf+1
    LDX #$18
    STX DynTileBuf+2
    LDA #$FF
    STA DynTileBuf+3, X
:Anon0162
    LDA PlayAreaAttrs, Y
    STA DynTileBuf+2, X
    DEY
    DEX
    BNE :Anon0162
    RTS

InitModeA ENT
    LDA GameSubmode
    JSR TableJump

InitModeA_JumpTable
            dw    InitModeSubroom_Sub0
            dw    InitModeA_Sub1
            dw    InitModeA_Sub2
            dw    InitModeSubroom_AnimateFade
            dw    LayoutRoom_SubmodeTask
            dw    CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone
            dw    InitModeA_Sub6_FillTileAttrsAndTransferTopHalf
            dw    InitModeAOrB_TransferBottomHalfAttrs
            dw    InitModeA_Sub8
            dw    InitModeSubroom_AnimateFade
            dw    InitModeA_SubA_GoToMode4

InitModeSubroom_Sub0
    LDA #$00
    STA CurRow
    STA CurOpenedDoors
    LDA CurLevel
    BNE DrawSpritesBetweenRoomsAndAdvanceSubmode
    JSR DrawSpritesBetweenRoomsAndAdvanceSubmode
    JMP WriteAndEnableSprite0

DrawSpritesBetweenRoomsAndAdvanceSubmode
    INC GameSubmode
    JMP DrawSpritesBetweenRooms

InitMode9_TransferAttrs
    LDA #$26                    ; Cellar NT attributes

L1712E_SelectTransferBufAndAdvanceSubmode
    STA TileBufSelector

InitModeSubroom_AdvanceSubmode
    INC GameSubmode
    RTS

InitMode9_FadeToDark
    LDA #$00                    ; Light level -> dark cellar cycle
:Anon0163
    LDY CurLevel
    BEQ InitModeSubroom_AdvanceSubmode
    JSR SetFadeCycleAndAdvanceSubmode

InitModeSubroom_AnimateFade
    LDY CurLevel
    BEQ InitModeSubroom_AdvanceSubmode
    JMP UpdateMode11Death_Sub8_AnimateFade

InitMode9_FadeToLight
    LDA #$A0                    ; Dark cellar -> light cellar cycle
    BNE :Anon0163

InitModeA_Sub2
    LDA #$20                    ; Light cellar -> dark cellar cycle
    BNE :Anon0163

InitModeA_Sub8
    LDA #$80                    ; Dark cellar -> light level cycle
    BNE :Anon0163

InitModeB_Sub1
    ; Transfer the cave BG palette rows.
    LDA #$3E
    BNE L1712E_SelectTransferBufAndAdvanceSubmode

InitModeA_Sub1
    LDA CurLevel
    BNE InitModeSubroom_AdvanceSubmode

    ; Transfer the OW palette again, because it was changed
    ; for a cave.
    JMP PatchAndCueLevelPalettesTransferAndAdvanceSubmode

InitModeA_SubA_GoToMode4
    JSR ResetInvObjState
    LDA #$00
    STA GameSubmode
    LDA #$04
    STA GameMode
    RTS

InitModeA_Sub6_FillTileAttrsAndTransferTopHalf
    LDA RoomId
    JMP :Anon0164

InitModeB_Sub5_FillTileAttrsAndTransferTopHalf
    LDA #$44                    ; An OW room that has the same NT attributes as a cave.
:Anon0164
    JSR FillPlayAreaAttrs
    JMP InitMode3_Sub3_TransferTopHalfAttrs

InitModeAOrB_TransferBottomHalfAttrs
    JSR InitMode3_Sub4_TransferBottomHalfAttrs
    JMP :DisableSprite0Check
    ; Begin unverified code 17179
    INC GameSubmode
    ; End unverified code

:DisableSprite0Check
    LDA #$00
    STA IsSprite0CheckActive
    RTS

InitMode_WalkCave
    ; If reached the end of the walk, then go start updating.
    LDA ObjGridOffset
    BEQ :Anon0165

    ; Move and draw facing up.
    LDA ObjDir
    STA ObjInputDir
    STA $0F
    LDX #$00
    JSR MoveObject
    JMP Link_EndMoveAndAnimateInRoom
:Anon0165
    JMP RunCrossRoomTasksAndBeginUpdateMode

CellarLadderXs
            db    $30, $C0

InitMode9_EnterCellar
    LDA GameSubmode
    PHA                         ; Save the submode.
    JSR InitMode_EnterRoom
    JSR ResetInvObjState
    PLA                         ; Restore the submode.
    STA GameSubmode

    ; Each cellar can have two destination rooms: A and B.
    ; Tunnels use both. Treasure rooms only use room A.
    ;
    ; If the room that Link came from is the room A of this cellar,
    ; then look up the X coordinate of the ladder on the left at index 0.
    ; Else use index 1 to get the X coordinate on the right.
    LDY RoomId
    LDX #$00
    LDA CellarSourceRoomId
    CMP LevelBlockAttrsA, Y
    BEQ :Anon0166
    INX
:Anon0166
    LDA CellarLadderXs, X
    STA ObjX

    ; Link goes at Y=$41, and facing down.
    LDA #$41
    STA ObjY
    LDA #$04
    STA ObjDir

    ; Set a grid offset appropriate for the distance to travel:
    ;   ($5D - $41) = $1C = ($100 - $E4)
    LDA #$E4
    STA ObjGridOffset
    LDA #$00
    STA IsUpdatingMode
    STA DoorwayDir
    INC GameSubmode
    RTS

InitMode9_WalkCellar
    ; Set Link's input direction to the facing direction, and
    ; update the player object; so that it walks down the stairs
    ; of the cellar. Stop when it reaches Y coordinate $5D.
    LDA ObjDir
    STA ObjInputDir
    JSR UpdatePlayer
    LDA ObjY
    CMP #$5D
    BNE :Anon0167
    LDA #$00                    ; Reset player state.
    STA ObjState
    LDA #$01                    ; Remember that this is a cellar.
    STA UndergroundExitType
    STA IsUpdatingMode          ; Start updating the mode.
:Anon0167
    RTS

World_FillHearts ENT
    LDA World_IsFillingHearts
    BEQ :Exit                   ; If not filling hearts, then return.
    LDA #$10                    ; Play the "heart taken" tune.
    STA Tune0Request
    LDA HeartPartial
    CMP #$F8
    BCS :CompleteHeart          ; If HeartPartial >= $F8, go complete a heart.
    CLC                         ; else add 6.
    ADC #$06
    STA HeartPartial
    RTS

:CompleteHeart
    LDA #$00                    ; Set HeartPartial to zero for the next heart.
    STA HeartPartial
    JSR CompareHeartsToContainers
    BNE :IncHearts              ; If hearts <> heart containers, go increase hearts.

    ; They're equal, so make HeartPartial full by
    ; decreasing from 0 to $FF.
    DEC HeartPartial
    LDA #$00                    ; We reached the end. So stop filling hearts.
    STA SwordBlocked
    STA World_IsFillingHearts
    STA Paused

:Exit
    RTS

:IncHearts
    INC HeartValues
    RTS

SubmenuTransferBufSelectorsUW
            db    $00, $00, $00, $30, $32, $34, $38, $3A
            db    $3C, $00, $00, $00, $40

SubmenuTransferBufSelectorsOW
            db    $00, $00, $00, $30, $32, $34, $38, $3A
            db    $3C, $00, $00, $00, $00, $00, $00, $50
            db    $52, $54, $56, $58, $5A

Submenu_CueTransferRowUW
    ; If menu scroll value is negative, then we transferred everything.
    ; So, return.
    LDA SubmenuScrollProgress
    BMI L1725A_Exit

    ; Shift right. The value in A is now (menu scroll value) / 2,
    ; and represents the current row of the submenu being processed.
    ; The bottom bit tells us (1) whether to transfer a full row of
    ; black tiles, or (0) a row of the map or other piece of the GUI.
    ;
    ; If the bottom bit is set, go prepare the full black row.
    LSR
    TAY
    BCS PrepFullBlackRow

    ; Submenu rows $D to $15 are parts of the map.
    ; Submenu rows 0 to $C are fixed text and boxes.
    ;
    ; If submenu row < $D, cue a transfer of the static transfer
    ; buffer for this row.
    CMP #$0D
    BCS :Anon0168
    LDA SubmenuTransferBufSelectorsUW, Y

:SelectTransferBuf
    JMP SelectTransferBufAndDecCounter
:Anon0168
    ; If map row = $15, go cue the transfer of the bottom edge
    ; of the big map sheet.
    CMP #$15
    BNE :Anon0169
    LDA #$42
    JMP :SelectTransferBuf
:Anon0169
    ; Else row is between $D and $14. Prepare a map row.
    JSR Submenu_WriteSheetMapRowTransferRecord

DecSubmenuScroll
    ; Decrease the counter for the next frame.
    DEC SubmenuScrollProgress

L1725A_Exit
    RTS

PrepFullBlackRow
    ; Prepare the dynamic transfer buf with a row of blank ($24) tiles
    ; to transfer to row (7 + Y).
    ;
    ; Calculate PPU address ($28E0 + Y*$20).
    LDA #$28
    STA DynTileBuf
    LDA #$C0

:Add20H
    CLC
    ADC #$20
    BCC :Anon0170
    INC DynTileBuf              ; High PPU address
:Anon0170
    DEY
    BPL :Add20H
    STA DynTileBuf+1            ; Low PPU address
    LDA #$60
    STA DynTileBuf+2            ; Repeating 1 byte $20 times
    LDA #$24
    STA DynTileBuf+3            ; Blank tile
    LDA #$FF
    STA DynTileBuf+4            ; End marker
    JMP DecSubmenuScroll

Submenu_CueTransferRowOW
    ;
    ;
    ; If menu scroll value is negative, then we transferred everything.
    ; So, return.
    LDA SubmenuScrollProgress
    BMI L17295_Exit

    ; Shift right. The value in A is now (menu scroll value) / 2,
    ; and represents the current row of the submenu being processed.
    ; The bottom bit tells us (1) whether to transfer a full row of
    ; black tiles, or (0) a row of the triforce or other piece of the GUI.
    ;
    ; If the bottom bit is set, go prepare the full black row.
    LSR
    TAY
    BCS PrepFullBlackRow

    ; There's nothing to do for row $15.
    ; If submenu row < $15, cue a transfer of a triforce or other
    ; transfer buffer for this row.
    CMP #$15
    BCS :Anon0171
    LDA SubmenuTransferBufSelectorsOW, Y

SelectTransferBufAndDecCounter
    STA TileBufSelector
:Anon0171
    ; Decrease the counter for the next frame.
    DEC SubmenuScrollProgress

L17295_Exit
    RTS

; Indexed by reverse direction index.
;
; Is used in mapping a direction to a mask for its axis.
; For example:
; - right masks off up and down
; - up masks off left and right
;
AxisMasks
            db    $0C, $0C, $03, $03

Link_HandleInput ENT
    ; If state = 0, handle A and B buttons.
    LDA ObjState
    BNE :CheckMovement
    JSR Link_FilterInput

    ; If the sword is not blocked, then handle the sword if A is pressed.
    LDA SwordBlockedLongTimer
    ORA SwordBlocked
    BNE :Anon0172
    LDA ButtonsPressed
    AND #$80
    BEQ :Anon0172
    JSR WieldSword
:Anon0172
    ; If B is pressed, handle the item.
    LDA ButtonsPressed
    AND #$40
    BEQ :CheckMovement
    JSR WieldItem

:CheckMovement
    ; If player was shoved, return.
    LDX #$00
    LDA ObjShoveDir
    BNE L172FC_Exit

    ; If in UW, then move correctly inside doorways.
    LDA CurLevel
    BEQ :Anon0173
    JSR Link_ModifyDirInDoorway
:Anon0173
    ; Change directions according to whether the player is at an intersection point
    ; (grid offset = 0) or between points along a line (grid offset <> 0).
    LDA ObjGridOffset
    BEQ Link_ModifyDirAtGridPoint
    JMP Link_ModifyDirOnGridLine

Link_ModifyDirAtGridPoint
    ; Grid offset = 0, so A = 0 here.
    ; Reset some variables.
    ; [0B] holds input direction count.
    STA $0B
    STA $0C                     ; [0C] holds walkable direction count.
    STA Link_GoStraight         ; Reset this. We'll figure out if needs to be set again.

    ; Look for walkable directions that are components of the
    ; input directions.
    ;
    ; Keep track of how many and which directions were input
    ; directions and walkable.
    LDY #$03

:LoopDir
    LDA ObjInputDir
    AND ReverseDirections, Y
    BEQ :NextLoopDir            ; If this direction doesn't match, skip it.
    STA $0F                     ; [0F] holds the last input direction found.
    TYA                         ; Save the reverse direction index.
    PHA
    INC $0B                     ; Increment the input dir count in [0B].
    JSR GetCollidingTileMoving
    CMP ObjectFirstUnwalkableTile
    BCS :Anon0174                      ; If this is unwalkable, skip it.
    LDA $0F
    STA $0D                     ; [0D] holds the last walkable direction found.
    INC $0C                     ; Increase the walkable direction count in [0C].
:Anon0174
    PLA                         ; Restore the reverse direction index.
    TAY

:NextLoopDir
    DEY
    BPL :LoopDir

    ; If there were no input directions, then return.
    LDY $0B
    BNE HaveInput

L172FC_Exit
    RTS

HaveInput
    ; There were input directions.
    ;
    ; If there was only one input direction, go set object direction
    ; to input direction, and set Link's speed.
    ;
    ; Also, *RESET* Link_GoStraightWhenDiagInput
    ; (X is still 0, because it's Link's object index).
    LDA $0F
    CPY #$01
    BEQ :SetLinkDirAndSpeed

    ; There were more than one input directions.
    ;
    ; If none were walkable, go set input direction to 0, and return.
    LDA $0C
    BNE :Anon0175
    JMP SetLinkInputDir
:Anon0175
    ; Two input directions, and at least one of them is walkable.
    ;
    ; Make Link go straight in one direction on the next grid line.
    TAY
    INC Link_GoStraight

    ; If in OW or only one direction of the two is walkable, then go set
    ; object direction and input direction to last walkable direction
    ; found, and set Link's speed.
    ;
    ; Also, *RESET* Link_GoStraightWhenDiagInput.
    LDX #$00
    LDA $0D                     ; [0D] holds last walkable direction found.
    CPY #$01
    BEQ :SetLinkDirAndSpeed
    LDY CurLevel
    BEQ :SetLinkDirAndSpeed

    ; In UW. There are two input directions, and they're both walkable.
    ;
    ; Normally, turn to the direction that's perpendicular to object
    ; direction. But keep going straight after that, while diagonal
    ; input is held.
    ;
    ; Handle special cases for doors.

    ; 1. Link at horizontal doors.
    ;
    ; If Link's X = $20 or $D0 then
    ;   If Link's Y = $85 and facing down then
    ;     Go set object direction and input direction to object
    ;     direction, and set Link's speed. Also, *RESET*
    ;     Link_GoStraightWhenDiagInput.
    ;   Else
    ;     Go turn to the perpendicular direction
    LDY ObjX
    CPY #$20
    BEQ :Anon0176
    CPY #$D0
    BNE :Anon0177
:Anon0176
    LDY ObjY
    CPY #$85
    BNE :Anon0178
    LDA ObjDir
    AND #$04
    BEQ :Anon0178

:SetLinkDirToObjDir
    LDA ObjDir
    BNE :SetLinkDirAndSpeed
:Anon0177
    ; If allowed to turn when input is diagonal (2 directions), then
    ; go take the direction perpendicular to object direction.
    LDA ObjDir
    LDX Link_GoStraightWhenDiagInput
    BEQ :Anon0178

    ; At this point, Link_GoStraightWhenDiagInput is true.

    ; 2. Link at top door.
    ;
    ; If Link's X <> $78 or Link's Y <> $5D then
    ;   Go set object direction and input direction to object
    ;   direction, and set Link's speed. Also, *SET*
    ;   Link_GoStraightWhenDiagInput.
    LDY CurLevel
    BEQ :SetLinkDirAndSpeed     ; Also do it if in OW. But if in OW, we returned already.
    LDY ObjX
    CPY #$78
    BNE :SetLinkDirAndSpeed
    LDY ObjY
    CPY #$5D
    BNE :SetLinkDirAndSpeed

    ; If object direction is vertical then
    ;   Go set object direction and input direction to object
    ;   direction, and set Link's speed. Also, *SET*
    ;   Link_GoStraightWhenDiagInput.
    AND #$03
    BEQ :SetLinkDirToObjDir
:Anon0178
    ; Find the input direction that's perpendicular to the
    ; object's direction.
    LDA ObjDir
    INX                         ; Make sure to set Link_GoStraightWhenDiagInput.
    JSR GetOppositeDir          ; Do this to get reverse index of object direction.
    LDA ObjInputDir
    PHA                         ; Save input directions.
    AND AxisMasks, Y            ; Mask input directions with the mask for the object's direction's axis.
    STA $0C
    PLA                         ; Restore input directions.
    EOR $0C

:SetLinkDirAndSpeed
    ; Set object and input direction to value in A.
    ; Set Link_GoStraightWhenDiagInput to value X.
    STX Link_GoStraightWhenDiagInput
    JSR SetObjDirAndInputDir
    LDX #$00

InitLinkSpeed
    LDA #$60                    ; Link gets a quarter speed (QSpeed) of $60 by default (1.5 pixels a frame).
    STA $00
    LDA CurLevel
    BNE :SetSpeed               ; If in UW, go use this speed.

    ; In OW. If standing on mountain stairs, then
    ; use a lower quarter speed of $30.
    LDA ObjCollidedTile
    CMP #$74
    BEQ :Anon0179
    CMP #$75
    BNE :SetSpeed
:Anon0179
    LDA #$30
    STA $00
    CMP ObjQSpeedFrac
    BEQ :SetSpeed               ; If Link's speed is not this lower speed,
    LDA #$00                    ; then reset the position fraction.
    STA ObjPosFrac

:SetSpeed
    LDA $00
    STA ObjQSpeedFrac
:Anon0180
    RTS

Link_ModifyDirOnGridLine
    ;
    ; If not moving, then return.
    LDA ObjInputDir
    BEQ :Anon0180

    ; If there's more than one component in the input direction,
    ; then take only one of them.
    ;
    ; After this point, Y holds the reverse index of this single direction.
    JSR GetOppositeDir
    LDA ReverseDirections, Y

    ; If the single input direction matches object direction,
    ; then keep going in this direction.
    CMP ObjDir
    BEQ InitLinkSpeed

    ; If the single input direction is the opposite of object direction, then
    ; change to the single input direction.
    ORA ObjDir
    CMP #$03                    ; Combined opposite horizontals (1 OR 2).
    BEQ :Anon0181
    CMP #$0C                    ; Combined opposite verticals (4 OR 8).
    BNE :Anon0182                     ; If the directions are perpendicular, go handle this case.
:Anon0181
    LDA ReverseDirections, Y

; Params:
; A: direction
;
SetObjDirAndInputDir
    STA ObjDir

SetLinkInputDir
    STA ObjInputDir
    RTS
:Anon0182
    ; The directions are perpendicular.
    ;
    ; Keep going in facing direction, if that's what Link's been told to do.
    LDA Link_GoStraight
    BNE InitLinkSpeed

    ; Link's movement grid cell size is 8. If he's moved half that
    ; length or more, then return.
    LDA ObjGridOffset
    JSR Abs
    PHA
    LDA ObjDir
    JSR GetOppositeDir
    STA $01                     ; [01] holds the opposite of facing direction.
    PLA
    CMP #$04
    BCS :Exit

    ; If Link had turned back and is facing a grid point that he
    ; had started walking from, then return.
    LDA ObjDir
    AND #$0A
    BEQ :Anon0183
    LDA ObjGridOffset
    BPL :Exit
    BMI :ReverseDir
:Anon0183
    LDA ObjGridOffset
    BMI :Exit

:ReverseDir
    ; Reverse Link's direction.
    LDA $01
    STA ObjDir

    ; Reverse the grid offset. Yield an offset for the same position
    ; in the line, but in the opposite direction. For example,
    ; -1 => 7
    ;  3 => -5
    ;
    ; Positive offset: -8 - -offset
    ; Negative offset:  8 - -offset
    LDA #$08
    LDY ObjGridOffset
    BMI :Anon0184
    LDA #$F8
:Anon0184
    PHA
    TYA
    JSR Negate
    STA $01
    PLA
    SEC
    SBC $01
    STA ObjGridOffset

:Exit
    RTS

CheckWarps ENT
    ; If just came out of a cave, dungeon, or cellar; or if grid offset <> 0;
    ; then return.
    LDA UndergroundExitType
    ORA ObjGridOffset
    BNE L1746E_Exit

    ; If in OW room $22 and Link's X is not a multiple of 8, then return.
    ; This is a special case, because Level 6's entrance is wide.
    LDA CurLevel
    BNE :EnsureSquareX
    LDA RoomId
    CMP #$22
    BNE :EnsureSquareX
    LDA ObjX
    AND #$07
    BNE L1746E_Exit
    BEQ :EnsureSquareY

:EnsureSquareX
    ; In other OW rooms and in UW, make sure X is a multiple of $10.
    LDA ObjX
    AND #$0F
    BNE L1746E_Exit

:EnsureSquareY
    ; If Link's Y is not at ((multiple of $10) + $D), then return.
    LDA ObjY
    AND #$0F
    CMP #$0D
    BNE L1746E_Exit

    ; Check tile collision standing still.
    JSR GetCollidableTileStill

    ; If in OW, go handle the tile separately.
    LDA ObjCollidedTile
    LDY CurLevel
    BEQ HandleWarpOW

    ; In UW.
    ;
    ; If tile is not part of stairs square (tiles $70 to $74), return.
    CMP #$70
    BCC L1746E_Exit
    CMP #$74
    BCS L1746E_Exit

    ; Prepare to leave this room.
    JSR SaveKillCount
    LDA RoomId
    STA CellarSourceRoomId      ; Remember what room we were in.

    ; Look for a room in cellar array that has the current room as
    ; destination room A or B.
    LDX #$FF
:Anon0185
    INX
    LDA LevelInfo_CellarRoomIdArray, X
    TAY
    LDA RoomId
    CMP LevelBlockAttrsA, Y
    BEQ :Anon0186
    CMP LevelBlockAttrsB, Y
    BNE :Anon0185
:Anon0186
    ; Make the cellar found the current room, and the target mode 9.
    STY RoomId
    LDA #$09

SetTargetMode
    STA TargetMode

    ; If the target mode is not 9 (as in it's a cave), then silence all sound.
    CMP #$09
    BEQ :Anon0187
    JSR SilenceAllSound
    STA Tune1Request

    ; Reset the flute timer.
    STA FluteTimer
:Anon0187
    ; Go to mode $10.
    LDA #$10
    STA GameMode
    JSR MaskCurPpuMaskGrayscale
    JMP EndPrepareMode

SaveKillCount
    LDA CurLevel
    BNE :Anon0188
    JMP SaveKillCountOW
:Anon0188
    JSR SaveKillCountUW

L1746E_Exit
    RTS

HandleWarpOW
    ; Save the tile that Link is standing on; so that we know how
    ; to go underground.
    STA UndergroundEntranceTile

    ; If (tile < $70 or >= $74) except for $24 and $88; then return.
    CMP #$24
    BEQ :Anon0189
    CMP #$88
    BEQ :Anon0189
    CMP #$70
    BCC L1746E_Exit
    CMP #$74
    BCS L1746E_Exit

    ; If Link touched a stairs tile ($70 to $74), then
    ; use $70 to represent them all.
    LDA #$70
    STA ObjCollidedTile
:Anon0189
    JSR SaveKillCount

    ; Get the cave index attribute.
    LDY RoomId
    LDA LevelBlockAttrsB, Y
    AND #$FC                    ; Cave index

    ; If < $40, go deal with a level.
    ; $40 means cave index $10. Levels have cave indexes 1 to 9.
    CMP #$40
    BCC :LoadLevel

    ; If attribute <> $50, go to mode $B for a regular cave.
    LDY #$0B
    CMP #$50
    BNE :Anon0190

    ; Attribute = $50 meaning cave index $14 (shortcuts).
    ; Go to mode $C for a shortcut cave.
    INY
:Anon0190
    TYA
    JMP SetTargetMode

:LoadLevel
    ; Load a level.
    ;
    ; Shift right by two to get the level number.
    LSR
    LSR
    STA CurLevel
    LDA RoomId
    STA CaveSourceRoomId        ; Remember where we came from.
    LDA #$02                    ; Target mode is 2 to load a level.
    BNE SetTargetMode

; Returns:
; C: 1 if cleared; 0 if already cleared
;
InitSaveRam ENT
    LDA SaveRamBegin            ; If already cleared, then return false.
    CMP #$5A
    BNE :Anon0191
    LDA SaveRamEnd
    CMP #$A5
    BEQ :ReturnFalse
:Anon0191
    LDA #$FF                    ; Since we're clearing save RAM, treat file B as committed.
    STA IsSaveFileBCommitted
    STA IsSaveFileBCommitted+1
    STA IsSaveFileBCommitted+2
    LDA #$65                    ; Clear from $6530 to the end of Save RAM.
    STA $01
    LDA #$30
    STA $00
    LDY #$00
:Anon0192
    LDA #$00
    STA ($00), Y
    LDA $00
    CLC
    ADC #$01
    STA $00
    LDA $01
    ADC #$00
    STA $01
    CMP #$80
    BNE :Anon0192
    SEC                         ; Return C=1.
    RTS

:ReturnFalse
    CLC                         ; Return C=0.
    RTS

ClearRam ENT
    LDA #$07
    LDY #$FE                    ; It doesn't touch [$07FF].
    JSR ClearRam0300UpTo
    LDA #$00                    ; Clear a few individual variables that are left.
    STA ReturnToBank4
    STA TransferredCommonPatterns
    STA TransferredDemoPatterns
    STA _Unknown_F3
    LDY #$EF
:Anon0193
;    STA $0000, Y                ; Clear RAM from 0 to $EF.
    jsr STA_0000_Y
    DEY
    CPY #$FF
    BNE :Anon0193

    ; The first time looking for an edge cell to spawn a monster
    ; from, look here first.
    LDA #$40
    STA CurEdgeSpawnCell
    STA Random

    ; These are part of the IsSaveFileActive array.
    ;
    ; Mode 1 Menu checks 5 elements of the array to see
    ; if the option can be chosen. The first 3 are the save
    ; slots. The last two are the register and eliminate options.
    ;
    ; So, theses two should always be set.
    LDA #$01
    STA IsRegisterSaveFileOptionEnabled
    STA IsEliminateSaveFileOptionEnabled
    RTS

NextRoomIdOffsets
            db    $F0, $10, $FF, $01

CalculateNoNextRoom ENT
    ; Begin unverified code 17517
    LDA #$00
    STA $E7                     ; UNKNOWN: Write 0? But CalculateNextRoomForDoor reads [E7] instead.
    RTS
    ; End unverified code
:Anon0194
    ASL $00                     ; Shift single-bit mask.
    DEX
    JMP :Anon0195                      ; Go test next bit.

; Params:
; [E7]: direction
;
CalculateNextRoomForDoor ENT
    ; Map door bit/direction to an index as follows:
    ; 1: 3
    ; 2: 2
    ; 4: 1
    ; 8: 0
    ;
    ; Note that this is the opposite of the usual mapping.
    LDA #$01
    STA $00                     ; [00] holds a single-bit mask to compare
    LDX #$03                    ; Index
:Anon0195
    LDA $E7                     ; Compare direction argument to single-bit mask.
    BIT $00
    BEQ :Anon0194                     ; If they don't match, go try the next one.
    JSR GetUniqueRoomId
    STA $04E4                   ; UNKNOWN: [$04E4] holds room layout. But it's unused.
    LDA NextRoomIdOffsets, X    ; Look up offset used to calculate next room ID from current one.
    CLC
    ADC RoomId
    STA NextRoomId              ; Adding the offset to RoomId yields the room ID in the desired direction.
    LDA CurLevel
    BNE :Anon0196
    JSR CheckMazes
:Anon0196
    LDA NextRoomId
    BPL MaskCurPpuMaskGrayscale ; If the next room ID is invalid, then fall thru, and reload OW.

EndGameMode12
    JSR EndGameMode
    STA $E7                     ; UNKNOWN: Mode 2 loads a level. But it doesn't depend on [E7].
    STA CurLevel                ; Set OW (level 0).
    LDA #$02
    STA GameMode
    STA UndergroundExitType     ; Set to type 2: dungeon level.
    LDA #$80                    ; Silence the song.
    STA Tune0Request

MaskCurPpuMaskGrayscale ENT
    LDA CurPpuMask_2001
    AND #$FE
    STA CurPpuMask_2001
    RTS

; Params:
; A: direction
;
; Returns:
; A: next room ID
;
CalcNextRoomByDir
    LDX #$01
    STX $00                     ; Set up the single-bit mask.

    ; For each direction in [00]  indexed by X:
    LDX #$03
:Anon0197
    BIT $00                     ; Compare the direction argument with the single-bit mask [00].
    BNE :Anon0198                      ; If they match, go use this index.
    ASL $00
    DEX
    JMP :Anon0197                      ; Go check the next direction.
:Anon0198
    LDA NextRoomIdOffsets, X
    CLC                         ; Adding offset and room ID yields next room ID.
    ADC RoomId
    RTS

MapRowMasks
            db    $80, $40, $20, $10, $08, $04, $02, $01

Submenu_WriteSheetMapRowTransferRecord
    LDY #$10                    ; The row is $10 tiles and bytes long.

    ; Get the submenu row by dividing (current menu scrolling value) by 2.
    LDA SubmenuScrollProgress
    LSR
    TAX

    ; Write an end marker at the end of the row data.
    LDA #$FF
    STA DynTileBuf+3, Y
    LDA #$10                    ; We'll transfer $10 bytes.
    STA DynTileBuf+2

    ; Calculate PPU address ($290C + X*$20).
    LDA #$28
    STA DynTileBuf
    LDA #$EC

:Add20H
    CLC
    ADC #$20
    BCC :Anon0199
    INC DynTileBuf
:Anon0199
    DEX
    BPL :Add20H
    STA DynTileBuf+1

    ; Write a map mark in the dynamic transfer buf for each room
    ; in the range currently being scanned.
    LDA CurScanRoomId
    PHA                         ; Save the current scanned room index before writing any marks.
:Anon0200
    JSR Submenu_WriteScanningMapRoomMark    ; Y register is $10.
    DEC CurScanRoomId
    DEY
    BNE :Anon0200

    ; Restore the current scanned room index and subtract $10.
    PLA
    SEC
    SBC #$10
    STA CurScanRoomId

    ; If the level info indicates that the submenu map should be
    ; rotated horizontally, then loop to rotate right the number of
    ; bytes indicated.
    LDX LevelInfo_SubmenuMapRotation

:Rotate
    BEQ :DoneRotate
    LDA DynTileBuf+18
    PHA
    LDY #$0E
:Anon0201
    LDA DynTileBuf+3, Y
    STA DynTileBuf+4, Y
    DEY
    BPL :Anon0201
    PLA
    STA DynTileBuf+3
    DEX
    JMP :Rotate

:DoneRotate
    ; Exclude rooms that are not part of this level, and certain rooms
    ; that should never be marked visited in the submenu map.
    ;
    ; First calculate the map row:
    ; ((current menu scrolling value) / 2) - $D
    LDA SubmenuScrollProgress
    SEC
    SBC #$1A
    LSR
    TAX
    LDY #$0F

:MaskRooms
    ; For each element ($10) in the row, starting from $F:
    ; If the current row is set in the submenu map mask,
    ; then replace the tile with $F5, a blank map tile.
    LDA LevelInfo_SubmenuMapMask, Y
    AND MapRowMasks, X
    BNE :Anon0202
    LDA #$F5
    STA DynTileBuf+3, Y
:Anon0202
    DEY
    BPL :MaskRooms
    RTS

; Returns:
; A: 0 if compass of current level is missing.
;
HasCompass ENT
    LDX #$10                    ; Check compasses.
    BNE :Anon0203

; Returns:
; A: 0 if map of current level is missing.
;
HasMap
    LDX #$11                    ; Check maps.
:Anon0203
    LDA CurLevel
    BEQ :Exit                   ; If in OW, then return.
    SEC
    SBC #$01                    ; Base the level number on zero.
    CMP #$08
    BCC :Anon0204                      ; If in level 9,
    INX                         ; then check the level 9 variables.
    INX
:Anon0204
    AND #$07                    ; Sanitize the zero-based level number.
    TAY
    LDA Items, X
    AND LevelMasks, Y           ; Return the item value for the current level.

:Exit
    RTS

; Params:
; Y: offset from the third element in dynamic transfer buf
;    to write at (between 1 and $10)
;
Submenu_WriteScanningMapRoomMark
    TYA                         ; Save dynamic transfer buf offset.
    PHA
    JSR GetRoomFlags            ; Call this to load the address of level block world flags.
    LDA RoomId                  ; Save current room ID.
    PHA

    ; Temporarily set current room ID to the room ID we're scanning,
    ; in order to look up its information.
    LDA CurScanRoomId
    STA RoomId

    ; Set OpenDoorMask to $13, in case the room has not been
    ; visited. $E2 will be added, yielding $F5, which is the blank
    ; map mark tile.
    LDA #$13
    STA OpenDoorwayMask

    ; Get the currently scanned room's visit state.
    LDY RoomId
    LDA ($00), Y
    AND #$20                    ; Visit state

    ; If it's been visited, then check each of the 4 doors,
    ; and build an open door mask.
    ;
    ; Start with direction up and direction index 3.
    BEQ :WriteMapTile
    LDA #$08
    STA $02                     ; [02] holds door direction
    LDX #$03
:Anon0205
    JSR FindDoorTypeByDoorBit
    JSR CalcOpenDoorwayMask
    DEX
    LSR $02
    BNE :Anon0205

:WriteMapTile
    ; Restore current room ID and dynamic buffer offset.
    PLA
    STA RoomId
    PLA
    TAY

    ; The map marks are arranged in the same order as all the
    ; possible values of OpenDoorMask.
    ;
    ; Add $E2 for the first map mark tile, and store it in the
    ; dynamic transfer buf at the current offset.
    LDA OpenDoorwayMask
    CLC
    ADC #$E2
    STA DynTileBuf+2, Y
    RTS

; Call for each direction index (3 to 0) to build an open doorway mask
; based on doorway type and room flags. Each call will shift the next
; doorway state bit into OpenDoorwayMask.
;
; Params:
; A: door type
; X: direction index
;
; Returns:
; A: untouched
;
CalcOpenDoorwayMask
    LDY #$00
    PHA                         ; Save door type.
    CMP #$04
    BCC :ByDoorType             ; If door type < 4 (open or any wall), go shift the appropriate bit.

    ; Else we have to find out the walkability from the room flags.
    TXA
    PHA                         ; Save direction index.
    TYA
    PHA                         ; Save Y=0
    JSR GetRoomFlags
    CLC                         ; Clear carry to anticipate a zero AND result, meaning not walkable.
    AND LevelMasks, X           ; AND room flags with single-bit mask for direction.
    BEQ :Anon0206                      ; If result is not zero, then door hasn been opened,
    SEC                         ; and set carry, so that a 1 will be shifted into the mask.
:Anon0206
    PLA
    TAY                         ; Restore Y=0.
    PLA
    TAX                         ; Restore direction index in X.

:ShiftIntoMask
    LDA OpenDoorwayMask, Y
    ROL
    AND #$0F
    STA OpenDoorwayMask, Y
    PLA                         ; Restore door type.
    RTS

:ByDoorType
    ; The door type indicates the walkability.
    CMP #$00
    BEQ :ShiftIntoMask          ; If door type is "open", carry is set, and go shift a 1 into the mask.
    CLC
    BCC :ShiftIntoMask          ; Door type is a wall, carry is clear, and go shift a 0 into the mask.

AddDoorFlagsToCurOpenedDoors
    JSR GetRoomFlags
    LDX #$03

:LoopDoorBit
    LDA ($00), Y
    AND LevelMasks, X
    BEQ :Anon0207
    ORA CurOpenedDoors
    STA CurOpenedDoors
:Anon0207
    DEX
    BPL :LoopDoorBit
    RTS

SplitRoomId
    ; Begin unverified code 17680
    LDA RoomId
    PHA
    AND #$0F
    TAY
    PLA
    LSR
    LSR
    LSR
    LSR
    TAX
    RTS
    ; End unverified code

; Params:
; Y: room ID
;
; Returns:
; A: $80 if dark, else 0
;
IsDarkRoom_Bank5
    LDA CurLevel
    BEQ :Anon0208
    LDA LevelBlockAttrsE, Y
    AND #$80
:Anon0208
    RTS

SubmenuItemXs
            db    $80, $98, $AC, $B4, $C8, $80, $98, $B0
            db    $C8, $80, $94, $A0, $B0, $C0, $CC, $B0

DrawSubmenuItems
    ; Look for a magic boomerang, then a wooden boomerang.
    ; If you find one, then draw it.
    LDX #$1E
:Anon0209
    LDA Items, X
    BNE :FoundBoomerang
    DEX
    CPX #$1C
    BNE :Anon0209
    BEQ :DrawOtherItems         ; If you don't find either, skip drawing a boomerang.

:FoundBoomerang
    LDA #$36
    STA $01                     ; [01] Y
    LDA #$80
    STA $00                     ; [00] X
    TXA
    TAY                         ; Copy the item slot.
    JSR DrawItemInInventory

:DrawOtherItems
    ; Look at the rest of the items, starting at index 1.
    LDX #$01

:LoopDrawItem
    LDA Items, X

    ; If at the compass item slot, check this level's compass.
    CPX #$10
    BNE :Anon0210
    JSR HasCompass
    LDX #$10                    ; Set compass item slot $10 again.
:Anon0210
    ; If at the map item slot, check this level's map.
    CPX #$11
    BNE :Anon0211
    JSR HasMap
    LDX #$11                    ; Set map item slot $11 again.
:Anon0211
    ; If there are none of this item, then go advance the index and loop again.
    CMP #$00
    BEQ :NextLoopDrawItem

    ; If at the letter item slot, look at what's in the potion slot.
    ; If there is a potion, then go advance the index and loop again.
    ; That's because we already prepared sprites for the potion.
    CPX #$0F
    BNE :Anon0212
    LDA Potion
    BNE :NextLoopDrawItem
:Anon0212
    TXA                         ; Save the item slot.
    PHA
    TAY                         ; Save item slot to Y register. Maybe this was in anticipation of calling E735?

    ; Look up and set the X coordinate of this item.
    LDA SubmenuItemXs, X
    STA $00                     ; [00] X

    ; If the item goes in the first selectable row (item slot < 5),
    ; then go set Y coordinate to $36 and draw.
    LDA #$36
    CPX #$05
    BCC :Draw

    ; If the item goes in the second selectable row (item slot < 9 or = $F),
    ; then go set Y coordinate to $46 and draw.
    LDA #$46
    CPX #$0F
    BEQ :Draw
    CPX #$09
    BCC :Draw

    ; If the item goes in the unselectable row at the top (item slot < $10),
    ; then go set Y coordinate to $1E and draw.
    LDA #$1E
    CPX #$10
    BCC :Draw

    ; The Y coordinate of the compass is $9E; and the map's is $76.
    ; The X coordinate for both is $2C.
    LDA #$2C
    STA $00
    LDA #$9E
    CPX #$11
    BCC :Draw
    LDA #$76

:Draw
    STA $01                     ; [01] Y
    JSR DrawItemInInventoryWithX
    PLA                         ; Restore the item slot.
    TAX

:NextLoopDrawItem
    ; Loop until item slot = $12.
    INX
    CPX #$12
    BCC :LoopDrawItem
    RTS

SubmenuCursorXs
            db    $80, $98, $B0, $B0, $C8, $80, $98, $B0
            db    $C8

UpdateSubmenuSelection
    ; Pseudo-item slot 0 is for boomerangs.
    ; If it's not the currently selected item slot, then skip this.
    LDX SelectedItemSlot
    BNE :DrawBreakoutItem

    ; Look for a magic boomerang, then a wooden boomerang.
    ; If you find one, then use its item slot.
    LDX #$1E
:Anon0213
    LDA Items, X
    BNE :DrawBreakoutItem
    DEX
    CPX #$1C
    BNE :Anon0213
    BEQ :AfterBreakoutItem

:DrawBreakoutItem
    ; Draw the item in the box for the currently selected item,
    ; if we have it.
    ;
    ; There's also the special case for the letter. If the selected item
    ; is the letter, but we have a potion, then skip this.
    ;
    ; If the letter is selected and there's no potion, then make
    ; the item value 1 in [04]. Except that, the call to 05:B81C
    ; below will overwrite [04].
    LDA Items, X
    BEQ :AfterBreakoutItem
    CPX #$0F
    BNE :Anon0214
    LDA Potion
    BNE :AfterBreakoutItem
    LDA #$01                    ; Special case for letter selected and no potion.
:Anon0214
    STA $04                     ; [04] holds the item value.
    LDA #$36
    STA $01                     ; [01] Y
    LDA #$40
    STA $00                     ; [00] X
    JSR DrawItemInInventoryWithX

:AfterBreakoutItem
    ; If the selected item slot is the letter's and we have potions,
    ; then select the potion item slot.
    LDY SelectedItemSlot
    CPY #$0F
    BNE :DrawCursor
    LDY #$07
    LDA Items, Y
    BEQ :DrawCursor
    ; Begin unverified code 17764
    STY SelectedItemSlot
    ; End unverified code

:DrawCursor
    ; Look up the X coordinate for the selected item slot.
    ; Set it for the left cursor sprite.
    ; Then add 8 to set the right cursor sprite's X.
    LDA SubmenuCursorXs, Y
    STA Sprites+31
    CLC
    ADC #$08
    STA Sprites+35

    ; The Y coordinate is $36 for item slots < 5, else $46.
    LDA #$36
    CPY #$05
    BCC :Anon0215
    LDA #$46
:Anon0215
    STA Sprites+28
    STA Sprites+32

    ; $1E is the cursor tile.
    LDA #$1E
    STA Sprites+29
    STA Sprites+33

    ; Flash the cursor.
    ; Use palette rows 5 and 6 for 8 frames each.
    LDA FrameCounter
    AND #$08
    LSR
    LSR
    LSR
    ADC #$01
    STA Sprites+30

    ; Flip the right sprite horizontally.
    ORA #$40
    STA Sprites+34

    ; Has the input changed? If input direction = [EF] item search
    ; direction in the previous frame, then return.
    LDA ObjInputDir
    CMP $EF
    BEQ L177F1_Exit
    TAX                         ; Copy input direction to X register.

    ; If input direction = 0, up, or down; then we won't change
    ; the change the selected item slot forward or backward.
    ;
    ; Instead, jump to this routine to make sure an occupied slot
    ; is selected, then return.
    BEQ FindAndSelectOccupiedItemSlot
    CPX #$04
    BCS FindAndSelectOccupiedItemSlot

    ; Cue the "selection changed" tune.
    LDX #$01
    STX Tune1Request

    ; Move the selection in the input direction.
    TAX                         ; Save the input direction.
    LDA SelectedItemSlot        ; Save selected item slot.
    PHA
    TXA                         ; Restore the input direction.
    JSR FindAndSelectOccupiedItemSlot

    ; If the new item slot = old item slot, go cancel the
    ; "selection changed" tune.
    PLA                         ; Pop selected item slot.
    CMP SelectedItemSlot
    BEQ :CancelTune

    ; Else the selection changed. The new slot should have an item.
    ; If it does not, then cancel the "selection changed" tune.
    LDY SelectedItemSlot
    LDA Items, Y
    BNE :Anon0216

:CancelTune
    LSR Tune1Request
:Anon0216
    RTS

; Params:
; A: direction to search: 0=none, 1=forward, 2=backward
; Y: starting item slot
;
; Returns:
; [EF]: direction to search
;
FindAndSelectOccupiedItemSlot ENT
    STA $EF
    LDX #$09                    ; Check 9 slots.

LoopItemSlot
    JSR Cycle9InDirection
    CPY #$00
    BEQ CheckBoomerangs         ; If this is the boomerang pseudo-slot. Go check boomerangs.
    CPY #$03
    BEQ CheckNextItem           ; If it's the bow slot, then skip it. You can't select it.
    LDA Items, Y
    BNE FoundSlot               ; Found an item. Go see if the slot is OK.
    CPY #$07
    BEQ CheckLetter             ; This is the potion slot, but no potion. Go check the letter.

CheckNextItem
    DEX
    BPL LoopItemSlot            ; If there are more slots, then check the next one.
    LDY #$00                    ; We found no items. Set SelectedItemSlot to zero.

FoundSlot
    CPY #$02
    BNE SetSlotFound            ; If not the arrow, go set SelectedItemSlot.
    LDA Bow
    BEQ LoopItemSlot            ; If we don't have the bow, then keep looking for a slot.

SetSlotFound
    STY SelectedItemSlot        ; Set SelectedItemSlot to the slot we found.

L177F1_Exit
    RTS

CheckBoomerangs
    ; Check the boomerangs.
    ;
    ; Start with the magical boomerang.
    LDY #$1E
:Anon0217
    LDA Items, Y
    BNE :Anon0218                      ; We have one of the boomerangs. Go use the boomerang pseudo-slot 0.
    DEY
    CPY #$1C
    BNE :Anon0217
    LDY #$00                    ; There are no boomerangs. So continue searching where we left off.
    JMP CheckNextItem
:Anon0218
    LDY #$00                    ; Go finish up with pseudo-slot 0 for boomerangs found.
    JMP FoundSlot

CheckLetter
    ; Check the letter.
    LDY #$0F
    LDA Items, Y
    BNE :Anon0219                      ; If there's a letter, go see if there's a potion.
    LDY #$07
    BNE CheckNextItem           ; There's no letter, so continue searching where we left off.
:Anon0219
    LDA Potion
    BEQ SetSlotFound            ; If there's no potion, then go set SelectedItemSlot to the letter slot.
    ; Begin unverified code 17818
    LDY #$07
    BNE SetSlotFound
    ; End unverified code

DrawItemInInventoryWithX ENT
    ; [$00]: X
    ; [$01]: Y
    ; X: item slot
    TXA
    TAY
    JMP DrawItemInInventory

; Params:
; [$EF]: direction to search: 0=none, 1=forward, 2=backward
; Y: value to cycle
;
; If A = 0, does nothing.
; If A = 1, Y := (Y + 1) mod 9
; If A = 2, Y := (Y - 1) mod 9
;
Cycle9InDirection
    LDA $EF
    AND #$03
    BEQ :Exit
    INY
    LSR
    BCS :Anon0220
    DEY
    DEY
:Anon0220
    CPY #$FF
    BNE :Anon0221
    LDY #$08
:Anon0221
    CPY #$09
    BNE :Exit
    LDY #$00

:Exit
    RTS

CreateRoomObjects ENT
    ; Reset ObjState[$13] to activate room item object.
    LDA #$00
    STA ObjState+19

    ; If in OW, go create heart container in room 5F.
    LDA CurLevel
    BEQ :MakeHeartContainerOW

    ; If the player got the room item already, go deactivate
    ; the room item object.
    JSR GetRoomFlagUWItemState
    BNE :Deactivate

    ; Look up the item for this room, and store it.
    ; If it's item ID 3, then deactivate the object.
    ;
    ; Item ID 3 normally means the master sword. But because the
    ; usual value meaning "no item" ($3F) can't fit in the level
    ; block attribute for a room item (up to $1F); use 3 to
    ; stand in for it.
    LDY RoomId
    LDA LevelBlockAttrsE, Y
    AND #$1F                    ; Room item
    CMP #$03
    BNE :Anon0222
    DEC ObjState+19
:Anon0222
    STA RoomItemId

    ; If secret trigger is 3 "last boss" or 7 "foes for item",
    ; then deactivate room item object. They'll be activated by
    ; the secret action.
    LDA LevelBlockAttrsF, Y
    AND #$07                    ; Secret trigger
    CMP #$03
    BEQ :Deactivate
    CMP #$07
    BNE :Anon0223

:Deactivate
    DEC ObjState+19             ; Deactivate room item object by setting ObjState[$13] to $FF.
:Anon0223
    ; If there's a push block in the room, then look for where
    ; it goes, and activate it.
    LDA LevelBlockAttrsD, Y
    AND #$40                    ; Push block
    BEQ :Anon0224
    JSR FindAndCreatePushBlockObject
:Anon0224
    ; Set the X and Y for the room item object.
    JSR GetShortcutOrItemXY

:StoreLocation
    STA ObjX+19
    STY ObjY+19

    ; If the room item is a triforce piece,
    ; the move it left 8 pixels.
    LDY RoomId
    LDA LevelBlockAttrsE, Y
    AND #$1F                    ; Room item
    CMP #$1B                    ; Triforce piece
    BNE :Anon0225
    LDA ObjX+19
    SEC
    SBC #$08
    STA ObjX+19
:Anon0225
    RTS

:MakeHeartContainerOW
    ; Try to make the heart container in OW.
    LDA #$1A                    ; Heart container
    STA RoomItemId

    ; Load the coordinates of the heart container in
    ; OW room $5F.
    LDA #$C0
    LDY #$90

    ; If in mode 5, and in room $5F, then go store the coordinates
    ; in the object slot.
    LDX GameMode
    CPX #$05
    BNE :Anon0226
    LDX RoomId
    CPX #$5F
    BEQ :StoreLocation
:Anon0226
    ; Else deactivate the object.
    DEC ObjState+19
    RTS

; .SEGMENT "BANK_05_ISR"
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

SetMMC1Control_Local5 ENT
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

SwitchBank_Local5 ENT
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

; .SEGMENT "BANK_05_VEC"




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
Z07_EMBED_BANK equ 5
            put   rom_07_fixed.s


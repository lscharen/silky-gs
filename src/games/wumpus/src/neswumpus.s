BAT_BIT equ 1
PIT_BIT equ 2
WUMPUS_BIT equ 4
SLIME_BIT equ 8
CLEAR_SLIME equ $F7
DRAFT_BIT equ 16
VISITTED_BIT equ 32
CLEAR_VISITTED equ $DF
CLEAR_BAT equ $FE
SLIME_AND_DRAFT equ 24
ANY_HAZARD equ 31
;OAM_ADDR equ $2003
;OAM_DATA equ $2004
;P1_CONTROLLER equ $4016
ROOM_UP equ 0
ROOM_DOWN equ 1
ROOM_LEFT equ 2
ROOM_RIGHT equ 3
ROOM_FLAGS equ 4
ROOM_X equ 5
ROOM_Y equ 6
ROOM_TYPE equ 7
BYTES_PER_ROOM equ 8
BOARD_HEIGHT equ 7
BOARD_WIDTH equ 8
ROOM equ 0
TUNNEL1 equ 1 ;left to top
TUNNEL2 equ 2 ;left to bottom	
TUNNEL3 equ 3
TUNNEL4 equ 4
;PPU_ADDR equ $2006
;PPU_DATA equ $2007
FIRST_WUMPUS_SPRITE_Y equ 36
FIRST_WUMPUS_SPRITE_TILE equ 37
FIRST_WUMPUS_SPRITE_X equ 39

	put wumpusdefs.h
	put spritedefs.h
	put letters.h
	put nessnd.h
	put nescolors.h

CURSOR_SPR equ 6
sprites equ $200 ; 256 bytes
board equ $300 ; 8 x 8  = 64 squares x 8 ( up, dn, left, right, flags, scrX, scrY, type )
 
 
;;;;;;;;;;;;;;;
;  .inesprg 1   ; 1x 16KB PRG code
;  .ineschr 1   ; 1x  8KB CHR data
;  .inesmap 0   ; mapper 0 = NROM, no bank swapping
;  .inesmir 1   ; background mirroring
;  
;  .rsset $0000       ; put pointers in zero page
destPtrLo  equ 0   ; pointer variables are declared in RAM
destPtrHi  equ 1   ; low byte first, high byte immediately after
boardPtrLo equ 2
boardPtrHi equ 3
srcPtrLo equ 4
srcPtrHi equ 5
lastRoomPtrLo equ 6
lastRoomPtrHi equ 7
Index equ 8
temp equ 9
newRoom equ 10
counter2 equ 11
drawing equ 12  ; 0 = not drawing , 1 = drawing ($12)
upNeighbor equ 13 
leftNeighbor equ 14
rightNeighbor equ 15
;16
downNeighbor equ 16
playerRoom equ 17
counter equ 18
incAmt equ 19
cursorX equ 20
cursorY equ 21
scrX equ 22
numRooms equ 23
btnCounter equ 24 ; delay before checking button again
roomX equ 25
roomY equ 26
scrY equ 27
inputProcessed equ 28 ; 28 = $1C 
skillLevel equ 29
roomMask equ 30 ; bit to OR onto a room's flags
wumpusRoom equ 31
;32 ($20)
lastRand equ 32
buffer1Lo equ 33
buffer1Hi equ 34
buffer2Lo equ 35
buffer2Hi equ 36
playerRoomPtrLo equ 37  ; $25
playerRoomPtrHi equ 38
flip equ 39
redraw equ 40
shooting equ 41
movePlayer equ 42
mainFnLo equ 43
mainFnHi equ 44
direction equ 45 ; direction move/shoot
UpdateArrowFnLo equ 46
UpdateArrowFnHi equ 47
;48
doneFalling equ 48
batUp equ 49
batCounter equ 50
bottomTeethPtrLo equ 51
bottomTeethPtrHi equ 52
topTeethPtrLo equ 53
topTeethPtrHi equ 54
channel1PtrLo equ 55
channel1PtrHi equ 56
noteIndex equ 57
channel1Silence equ 58
channel1Index equ 59
channel2PtrLo equ 60
channel2PtrHi equ 61
channel2Silence equ 62
channel2Index equ 63
;64
smile equ 64
NMIHanlderLo equ 65
NMIHanlderHi equ 66
note equ 67
batAwake equ 68
wumpusScore equ 69
pitScore equ 70
playerScore equ 71
batRoom equ 72
noButton equ 73 ; used to check button releases
selectedOption equ 74
nmiStarted equ 75
batRoomPtrLo equ 76
batRoomPtrHi equ 77
textY equ 78
textX equ 79
;80
textPalette equ 80
buttonACounter equ 81
buttonBCounter equ 82
prevControllerState equ 83
controllerState equ 84 ;()
nmiFlag equ 85
buttonPresses equ 86 ;86 ($56)
okToRead equ 87
btnAUpCount equ 88
btnBUpCount equ 89
randHi equ 90
randLo equ 91
targetRoom equ 92
hitWumpusFlag equ 93

shadowChannel1 equ 100
shadowChannel2 equ 104

ROMBase ENT
    ds   $8000-$280
    put  ../../../rom/rom_inject.s
    ds   \,$00

; Pad from $8000 to $c000
    ds   $4000

;  .bank 0
;  .org $C000 
RESET
;  SEI          ; disable IRQs
;  CLD          ; disable decimal mode

  LDX #$40
  jsr STX_4017    ; disable APU frame IRQ
  LDX #$FF
;  TXS          ; Set up stack
  INX          ; now X = 0
  jsr STX_2000    ; disable NMI
  jsr STX_2001    ; disable rendering
  jsr STX_4010    ; disable DMC IRQs

	LDA #$00
	jsr STA_2005 ;why twice?
	jsr STA_2005

;vblankwait1:       ; First wait for vblank to make sure PPU is ready
;  jsr BIT_2002
;  BPL vblankwait1

clrmem
  LDA #$00
;  STA $0000, x
;  STA $0100, x
  STA $0200, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
;LDA #$FE  ; hide sprites
 ; STA $0200, x
  INX
  BNE clrmem
 
	;tell NMI to read controller
	lda #1
	sta inputProcessed

	lda #75
;	sta fib1
	sta randLo
	lda #255
	sta randHi

 	jsr StopMusic
	jsr InitAPU
 
	;Set buffer pointers
	lda #$20  ; first 2nd row of tiles
	sta buffer1Lo
	sta buffer2Lo
	sta buffer1Hi
	lda #$24
	sta buffer2Hi 

	lda #EASY
	sta skillLevel

;vblankwait2:       ; First wait for vblank to make sure PPU is ready
;  jsr BIT_2002
;  BPL vblankwait2

	;set tiles BEFORE drawing!
	LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
	jsr  STA_2000

	jsr ClearPPU
	jsr InitSprites
	jsr LoadPalettes
	jsr ResetScreenAttrs
 	jsr DrawTitleScreen

;vblankwait3:       ; First wait for vblank to make sure PPU is ready
;  jsr BIT_2002
;  BPL vblankwait3

	;again
	LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
	jsr STA_2000

 	LDA #%00011000   ; enable sprites, enable background, no clipping on left side
;	LDA #%00001110   ; disable sprites, enable background, no clipping on left side
	jsr STA_2001

Forever
	lda #>EndMain
	pha
	lda #<EndMain
	pha
	  
;	jmp [mainFnLo]
    lda mainFnLo
	sta :p+1
	lda mainFnLo+1
	sta :p+2
:p  jmp $0000

EndMain	 ;return label
	nop
	jsl yield
	jmp Forever     ;jump back to Forever, infinite loop


;56 rooms + 
;board is 8x7 cells visible on the screen.
;the numbers of actual rooms will be larger
InitBoard
	ldy #0
	ldx #0
	lda #0
	;clear 256 bytes (will need to clear more later)
:lp	
	sta $300,x
	sta $400,x
	sta $500,x
	inx
	bne :lp
	
	;set ptr to data to modify
	lda #>board
	sta boardPtrHi
	lda #<board
	sta boardPtrLo

	lda #0
	sta scrX
	sta scrY
	 
	
	lda #0 ; loop counter
:outerLp
	pha ; save loop counter
	
	;row (increasing x)
	lda #0
:innerLp
	pha  ; save loop counter
	lda #0
	
	;set neighbors
	
	
	;set screen x, y
	ldy #ROOM_X
	lda scrX
;	sta [boardPtrLo],y
	sta (boardPtrLo),y

	ldy #ROOM_Y
	lda scrY
;	sta [boardPtrLo],y 
	sta (boardPtrLo),y
	
	;clear flags
	ldy #ROOM_FLAGS
	lda #0
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	
	;set to normal room
	ldy #ROOM_TYPE
	lda #ROOM
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	
	;advance boardPtr to the next room
	clc
	lda boardPtrLo
	adc #BYTES_PER_ROOM
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	
	inc scrX
	
	pla ; restore loop counter
	clc
	adc #1
	cmp #BOARD_WIDTH
	bne :innerLp
	 
	;reset x
	lda #0
	sta scrX

	;increase y
	inc scrY
	
	pla ; restore loop counter
	clc
	adc #1
	cmp #BOARD_HEIGHT 
	bne :outerLp
 
	
	;put invalid coords in last room
	lda #56
	sta numRooms
	
	;set ptr to first unused room
	lda #<board
	sta lastRoomPtrLo
	lda #>board
	sta lastRoomPtrHi
	;add 448  (1C0) = 56*8
	clc
	lda #$C0
	adc lastRoomPtrLo
	sta lastRoomPtrLo
	lda lastRoomPtrHi
	adc #$01
	sta lastRoomPtrHi
	rts

;sets the neighbors number of the adjacent rooms
SetNeighbors
	lda #248
	sta upNeighbor
	lda #8
	sta downNeighbor
	lda #1
	sta rightNeighbor
	lda #255
	sta leftNeighbor
	 
	;set boardPtr
	lda #<board
	sta boardPtrLo
	lda #>board
	sta boardPtrHi
	
	ldx #0
	 
:loop
	
	ldy #ROOM_UP
	lda upNeighbor
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	iny
	lda downNeighbor
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	iny
	lda leftNeighbor
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	iny
	lda rightNeighbor
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	;update neighbors
	inc upNeighbor
	inc downNeighbor
	inc leftNeighbor
	inc rightNeighbor
	;advance board ptr to next room
	clc
	lda #BYTES_PER_ROOM
	adc boardPtrLo
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	 
	inx
	cpx #56
	bne :loop
	jsr FixTopEdgeNeighbors
	jsr FixBottomEdgeNeighbors
	jsr FixLeftEdgeNeighbors
	jsr FixRightEdgeNeighbors
	
	rts

;makes left edges wrap around to the right
FixLeftEdgeNeighbors
	;set boardPtr
	lda #<board
	sta boardPtrLo
	lda #>board
	sta boardPtrHi
	ldx #0
	lda #7
	sta leftNeighbor
:loop
	ldy #ROOM_LEFT
	lda leftNeighbor
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	clc
	adc #8
	sta leftNeighbor
	;add 8 * ROOM_SIZE to ptr
	clc
	lda boardPtrLo
	adc #64
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	inx
	cpx #7
	bne :loop
	rts

;makes right edges wrap around to the left	
FixRightEdgeNeighbors
	;set boardPtr
	lda #<board
	sta boardPtrLo
	lda #>board
	sta boardPtrHi
	;add 7*8 bytes to jump to room 7
	lda boardPtrLo
	clc
	adc #56
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	ldx #0
	stx rightNeighbor
:loop
	ldy #ROOM_RIGHT
	lda rightNeighbor
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	clc
	adc #8
	sta rightNeighbor
	;add 8 * ROOM_SIZE to ptr
	clc
	lda boardPtrLo
	adc #64
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	inx
	cpx #7
	bne :loop
	rts
 
;makes top edges wrap around to the bottom
FixTopEdgeNeighbors
	;set boardPtr
	lda #<board
	sta boardPtrLo
	lda #>board
	sta boardPtrHi
	ldx #48 ; room 0 leads up to room 48
	stx downNeighbor
	ldy #ROOM_UP
    ldx #0
:loop
	lda downNeighbor
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	inc downNeighbor
	;move to next room (add 8 to ptr)
	clc
	lda boardPtrLo
	adc #8
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	inx
	cpx #8
	bne :loop
	rts

;Makes bottom edges wrap around to the top	
FixBottomEdgeNeighbors
	;set boardPtr
	lda #<board
	sta boardPtrLo
	lda #>board
	sta boardPtrHi
	;add 6*8 bytes to start at bottom left room
	clc
	lda #$80 ; 180 = 384 bytes
	adc boardPtrLo
	sta boardPtrLo
	lda boardPtrHi
	adc #$01
	sta boardPtrHi
	
	ldx #0
	stx downNeighbor
 
:loop
	ldy #ROOM_DOWN
	lda downNeighbor
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	inc downNeighbor
	;move to next room
	clc
	lda boardPtrLo
	adc #8
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	inx
	cpx #8
	bne :loop
	rts

;places wumpus in a room that doesn't have a pits
PlaceWumpus
:lp	
	jsr GetRandRoomPtr	
	;is it a regular room?
	ldy #ROOM_TYPE
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	bne :lp	
	ldy #ROOM_FLAGS
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #PIT_BIT
	bne :lp ; if not 0, keep trying
	
	lda lastRand
	sta wumpusRoom
	
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	ora #WUMPUS_BIT
;	sta [boardPtrLo],y
	sta (boardPtrLo),y

	;save wumpus room
	lda boardPtrLo
	pha
	lda boardPtrHi
	pha
	
	;mark the current room as visitted
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	ora #VISITTED_BIT
;	sta [boardPtrLo],y 
	sta (boardPtrLo),y
	
	;set the bit to OR onto the neighbors
	lda #SLIME_BIT
	sta roomMask
	
	jsr MarkNeighbors2

	;restore wumpus room ptr
	pLa
	sta boardPtrHi
	pLa
	sta boardPtrLo
	
	;unmark the slime
	ldy #ROOM_FLAGS
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #CLEAR_SLIME
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	jsr ClearVisittedBits
	rts





;places a pit in a room that doesn't already have a pit
PlacePit
	;find a regular room	 
:lp	
	jsr GetRandRoomPtr	
	;is it a regular room?
	ldy #ROOM_TYPE
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	bne :lp	
	ldy #ROOM_FLAGS
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #PIT_BIT
	bne :lp ; if not 0, keep trying
 
	
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	ora #PIT_BIT
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	
	;mark the current room as visitted
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	ora #VISITTED_BIT
;	sta [boardPtrLo],y 
	sta (boardPtrLo),y
	
	;set the bit to OR onto the neighbors
	lda #DRAFT_BIT
	sta roomMask
	
	jsr MarkNeighbors1
	rts


;places a pit in a room that doesn't already have a pit
PlaceBat
	;find a regular room	 
:lp	
	jsr GetRandRoomPtr	
	;is it a regular room?
	ldy #ROOM_TYPE
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	bne :lp	
	ldy #ROOM_FLAGS
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #PIT_BIT
	bne :lp ; if not 0, keep trying
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #WUMPUS_BIT
	bne :lp ; if not 0, keep trying

 	;set the flag
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	ora #BAT_BIT
;	sta [boardPtrLo],y
	sta (boardPtrLo),y

	;bat asleep
	lda #0
	sta batAwake
	;save bat room
	lda lastRand  
	sta batRoom

	;save the ptr to the bat's room
	lda boardPtrLo
	sta batRoomPtrLo
	lda boardPtrHi
	sta batRoomPtrHi

 	rts

;replaces that bat after clearing the bat flag off the room
;where the bat already was
RepositionBat
;	lda [batRoomPtrLo],Y
	lda (batRoomPtrLo),y
	and #CLEAR_BAT
;	sta [batRoomPtrLo],Y
	sta (batRoomPtrLo),Y
	jsr PlaceBat
	;if new bat room is visitted
	;put bat back to sleep
	ldy #ROOM_FLAGS
;	lda [batRoomPtrLo],y
	lda (batRoomPtrLo),y
	and #VISITTED_BIT
	sta batAwake	; =
	rts

;Marks the neighbors of board ptr lo
MarkNeighbors1	
	ldy #ROOM_UP
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	jsr GetRoomPtr	; sets destPtr
	jsr MoveToEndAndSetBit

	ldy #ROOM_DOWN
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	jsr GetRoomPtr	; sets destPtr
	jsr MoveToEndAndSetBit

	ldy #ROOM_LEFT
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	jsr GetRoomPtr	; sets destPtr
	jsr MoveToEndAndSetBit
	
	ldy #ROOM_RIGHT
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	jsr GetRoomPtr	; sets destPtr
	jsr MoveToEndAndSetBit

;	jsr ClearVisittedBits  ; caused unmarked room

	rts

;marks the neighbors of board ptr
MarkNeighbors2
;Marks the neighbors of board ptr lo
 
	ldy #0 ; 0
:lp	
	pha ; save loop counter
	tya
	pha	
	
	;save start room
	lda boardPtrLo
	pha
	lda boardPtrHi
	pha

	;mark the room that ended at
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	jsr GetRoomPtr	; sets destPtr  (boardPtr not touched)
	jsr MoveToEndAndSetBit ; (clobbers boardPtr)

	;mark it as visitted	
	ldy #ROOM_FLAGS
;	lda [destPtrLo],Y
	lda (destPtrLo),Y
	ora #VISITTED_BIT
;	sta [destPtrLo],Y 
	sta (destPtrLo),Y

	;get the neighboring room
	lda destPtrLo
	sta boardPtrLo
	lda destPtrHi
	sta boardPtrHi

	;mark the four rooms adjacent to that
	jsr MarkNeighbors1
	
	pla
	sta boardPtrHi
	pla
	sta boardPtrLo
	
    pla ;restore property #
	tay
	pla ;restore loop counter
	
	iny
	cpy #4
	bne :lp
		
;	jsr ClearVisittedBits
	
	rts
 
 
;clears the visitted flags on all the rooms
ClearVisittedBits
	lda #<board
	sta boardPtrLo
	lda #>board
	sta boardPtrHi
	ldx #0
	ldy #ROOM_FLAGS
:lp
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #CLEAR_VISITTED
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	;advance ptr
	clc
	lda boardPtrLo
	adc #8
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	
	inx
	cpx numRooms
	bne :lp
	rts

;Moves to end of the tunnel to first unvisitted
;room and ors the roomMask onto its flags
;The starting room should be in destPtr
;Visitted bit should be set on calling room
;preserves boardPtr
;clobbers board ptr
MoveToEndAndSetBit
	;save ptr
	lda boardPtrLo
	pha
	lda boardPtrHi
	pha
	
	;if the starting room is a room (not a tunnel), mark it and quit
	ldy #ROOM_TYPE
;	lda [destPtrLo],y
	lda (destPtrLo),y
	beq :mark ;otherwise mark it
	
	;put starting room in boardPtr
	lda destPtrLo
	sta boardPtrLo
	lda destPtrHi
	sta boardPtrHi

:lp	

	;mark current room as visitted
	ldy #ROOM_FLAGS	
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	ora #VISITTED_BIT
;	sta [boardPtrLo],y
	sta (boardPtrLo),y


    ldy #ROOM_UP
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	bmi :dn
	jsr GetRoomPtr
	ldy #ROOM_FLAGS
;	lda [destPtrLo],y
	lda (destPtrLo),y
	and #VISITTED_BIT
	beq :visitRoom		
:dn	
    ldy #ROOM_DOWN
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	bmi :left
	jsr GetRoomPtr
	ldy #ROOM_FLAGS
;	lda [destPtrLo],y
	lda (destPtrLo),y
	and #VISITTED_BIT
	beq :visitRoom
:left
    ldy #ROOM_LEFT
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	bmi :right
	jsr GetRoomPtr
	ldy #ROOM_FLAGS
;	lda [destPtrLo],y
	lda (destPtrLo),y
	and #VISITTED_BIT
	beq :visitRoom
:right	
    ldy #ROOM_RIGHT
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	bmi :x
	jsr GetRoomPtr
	ldy #ROOM_FLAGS
;	lda [destPtrLo],y
	lda (destPtrLo),y
	and #VISITTED_BIT
	beq :visitRoom
    jmp :x  ; room looped back on itself!
:visitRoom
	;if it is a tunnel - keep going
	ldy #ROOM_TYPE
;	lda [destPtrLo],y
	lda (destPtrLo),y
	beq :mark ;otherwise mark it ( 0 == cave )
	ldy #ROOM_FLAGS
;	lda [destPtrLo],y
	lda (destPtrLo),y
	ora #VISITTED_BIT
;	sta [destPtrLo],y
	sta (destPtrLo),y
	;move to next room (destPtr -> boardPtr)
	lda destPtrLo
	sta boardPtrLo
	lda destPtrHi
	sta boardPtrHi
	jmp :lp
:mark
	ldy #ROOM_FLAGS
;	lda [destPtrLo],y
	lda (destPtrLo),y
	ora roomMask
;	sta [destPtrLo],y
	sta (destPtrLo),y
:x	;restore ptr
	pla
	sta boardPtrHi
	pla
	sta boardPtrLo
	rts
	
;Used to draw a room's tiles into the PPU
;Sets destPtrLo,Hi to the PPU address that corresponds
;to the coordinates of a room's X and Y coordinate on the screen
;The room must be pointed to by (boardPtr)
;destPtr is set as a result
SetPPUAddr
	;reset destPtr
	lda #$20  ; write to $2020  (2nd row of tile for NTSC)
	lda buffer1Lo
	sta destPtrLo
	lda buffer1Hi
	sta destPtrHi
	 
	;save room x
	ldy #ROOM_X
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	sta	roomX
	;load room y
	ldy #ROOM_Y ; y offset
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	beq :addX
	;add 128 bytes for each Y coordinate.  (Each row is 128 sprites tall in the PPU)
	asl a ; y *2
    tay  	
	clc
	lda yoffsets,y
	adc destPtrLo
	sta destPtrLo
	iny
	lda yoffsets,y
	adc destPtrHi
	sta destPtrHi
:addX	
	;add 4 times x coord 
	lda roomX
	asl a ; x 4 sprites per room
	asl a
	;add A to ptr
	clc
	adc destPtrLo
	sta destPtrLo
    lda destPtrHi
	adc #0
	sta destPtrHi
	rts

;draws room pointed to by boardPtr the roomx, roomy into the tilemap
;each room is 4x4 = 16 tiles
DrawRoom 
	
	;check room type
	ldy #ROOM_FLAGS

;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #PIT_BIT
	bne DrawPitRoom
	
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #SLIME_AND_DRAFT
	cmp #SLIME_AND_DRAFT
	beq DrawSlimeDraftRoom
	
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #DRAFT_BIT
	cmp #DRAFT_BIT
	beq DrawDraftRoom

;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #SLIME_BIT
	cmp #SLIME_BIT
	beq DrawSlimeRoom

	;fall through to draw empty
DrawEmptyRoom
	;set tile src pointer
	lda #<EmptyRoomPattern
	sta srcPtrLo
	lda #>EmptyRoomPattern
	sta srcPtrHi	
	jsr Copy16Tiles
	rts

;assumes PPU address is already set
DrawDraftRoom
	;set tile src pointer
	lda #<DraftRoomPattern
	sta srcPtrLo
	lda #>DraftRoomPattern
	sta srcPtrHi	
	jsr Copy16Tiles
	rts

DrawSlimeDraftRoom
	;set tile src pointer
	lda #<DraftSlimePattern
	sta srcPtrLo
	lda #>DraftSlimePattern
	sta srcPtrHi	
	jsr Copy16Tiles
	rts
	
DrawSlimeRoom
	;set tile src pointer
	lda #<SlimePattern
	sta srcPtrLo
	lda #>SlimePattern
	sta srcPtrHi	
	jsr Copy16Tiles
	rts


DrawPitRoom
	;set tile src pointer
	lda #<PitPattern
	sta srcPtrLo
	lda #>PitPattern
	sta srcPtrHi	
	jsr Copy16Tiles
	rts
	
;left to top
DrawTunnel1
	jsr LDA_2002
	lda destPtrHi
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006
	;copy 4
	ldx #0
	ldy #0
:loop1	
	lda Tunnel1Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #4
	bne :loop1
	jsr NextLine
	
	;copy 3 tiles
	ldx #0
:loop2	
	lda Tunnel1Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #3
	bne :loop2	
    jsr NextLine
	
	;copy 2 tiles
	ldx #0
:loop3	
	lda Tunnel1Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #2
	bne :loop3	
	rts
	
;left to bottom	
DrawTunnel2
	jsr NextLine
	ldy #0
	ldx #0
	;copy 2 tiles
:loop1	
	lda Tunnel2Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #2
	bne :loop1
	jsr NextLine
	;copy 3 tiles
	ldx #0
:loop2	
	lda Tunnel2Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #3
	bne :loop2	
    jsr NextLine
	;copy 4 tiles
	ldx #0
:loop3	
	lda Tunnel2Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #4
	bne :loop3	
	rts
	
;top to right	
DrawTunnel3
	jsr LDA_2002
	lda destPtrHi
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006
	lda #33
	sta incAmt
	ldx #0
	ldy #0
	;copy four
:loop1	
	lda Tunnel3Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #4
	bne :loop1
	jsr NextLineAndIncrement
	;copy 3 tiles
	ldx #0
	;drop down and add 1
:loop2	
	lda Tunnel3Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #3
	bne :loop2	
	jsr NextLineAndIncrement
	;copy two
	ldx #0
:loop3	
	lda Tunnel3Pattern,y
	jsr STA_2007
	iny
	inx 
	cpx #2
	bne :loop3		
	rts
	
;bottom to right	
DrawTunnel4
	lda #34
	sta incAmt
	jsr NextLineAndIncrement
	ldy #0
	;draw 2
	lda Tunnel4Pattern,y
	jsr STA_2007
	iny
	lda Tunnel4Pattern,y
	jsr STA_2007
	iny
	;draw 3
	lda #31
	sta incAmt
	jsr NextLineAndIncrement
:loop2	
	lda Tunnel4Pattern,y
	jsr STA_2007
	iny
	cpy #5
	bne :loop2
	;draw 4
	lda #31
	sta incAmt
	jsr NextLineAndIncrement
:loop3	
	lda Tunnel4Pattern,y
	jsr STA_2007
	iny
	cpy #9
	bne :loop3
	rts
	

;advanes PPU ptr by 32
;then reset PPU Addr
NextLine
	clc
	lda destPtrLo
	adc #32
	sta destPtrLo
	lda destPtrHi
	adc #0
	sta destPtrHi
	jsr LDA_2002 ; PPU latch
	lda destPtrHi
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006	
	rts
	
;advanes PPU ptr by 32
;the reset PPU Addr
NextLineAndIncrement
	clc
	lda destPtrLo
	adc incAmt
	sta destPtrLo
	lda destPtrHi
	adc #0
	sta destPtrHi
	jsr LDA_2002 ; PPU latch
	lda destPtrHi
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006	
	rts	


;sets destPtr to the room in A
GetRoomPtr
	tax
	;reset pointer
	lda #>board
	sta destPtrHi
	lda #<board
	sta destPtrLo
	;multiply room # x 8
	cpx #0
	beq :done

:mulLp
	clc
	lda destPtrLo
	adc #8
	sta destPtrLo
	lda destPtrHi
	adc #0
	sta destPtrHi
	dex
	bne :mulLp
:done
	rts

;turns destPtr into a room number
;used to determine if player hit self
GetRoomNumber
	lda destPtrLo
	pha
	lda destPtrHi
	pha
	sec
	lda destPtrHi
	sbc #$03  ; data starts at $300
	;devide remainder by 8
	lsr destPtrHi
	ror destPtrLo
	lsr destPtrHi
	ror destPtrLo
	lsr destPtrHi
	ror destPtrLo
	lda destPtrLo
	sta targetRoom
	pla
	sta destPtrHi
	pla
	sta destPtrLo
	rts


;sets boardPtr to a  random room
GetRandRoomPtr
	;reset pointer
	lda #>board
	sta boardPtrHi
	lda #<board
	sta boardPtrLo
	;get a room
	lda numRooms
	sta newRoom
	jsr NextRand
	tax
	;multiply room # x 8
	beq :done
:mulLp
	clc
	lda boardPtrLo
	adc #8
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	dex
	bne :mulLp
:done
	rts

;creates one new room
;lastRoomPtr is updated as is numRooms
CreateTunnel
	;find a regular room	 
:lp	
	jsr GetRandRoomPtr	
	;is it a regular room?
	ldy #ROOM_TYPE
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	bne :lp ; if not 0, keep trying
	
	;set screen coord of new room to screen coord of 1st room
	ldy #ROOM_X
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	ldy #ROOM_Y
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	;pick a tunnel type
	jsr NextRand
	and #$01
	beq :tunnel2
	jsr CreateTunnel1
	jmp :tunnelDone
:tunnel2
	jsr CreateTunnel2
:tunnelDone
	
	;advance lastRoomPtr by 8 bytes
	clc
	lda lastRoomPtrLo
	adc #8
	sta lastRoomPtrLo
	lda #0
	adc lastRoomPtrHi
	sta lastRoomPtrHi
	
	inc numRooms
	rts
;_| _
;  |
CreateTunnel1
	;turn the existing room into type 1
	ldy #ROOM_TYPE
	lda #TUNNEL1
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	 
	;turn the new room into type 4
	lda #TUNNEL4
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	;new room's right becomes old room's right
	ldy #ROOM_RIGHT
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	;new room's down becomes old room's down
	ldy #ROOM_DOWN
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	;1st rooms right neighbor now points left to new room
	ldy #ROOM_RIGHT
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	tax ; x = room to alter
	ldy #ROOM_LEFT
	jsr SetConnection
		
	;1st rooms lower neighbor now points up to new room
	ldy #ROOM_DOWN
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	tax ; x = room to alter
	ldy #ROOM_UP
	jsr SetConnection
	
	;1st rooms right and down become 255
	ldy #ROOM_RIGHT
	lda #255
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	ldy #ROOM_DOWN
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	
	;new room's left and up become 255
	ldy #ROOM_LEFT
	lda #255
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	ldy #ROOM_UP
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
 
	rts

;_ |_
; |	
CreateTunnel2
	;turn the existing room into type 2
	;turn the new room into type 3
		;turn the existing room into type 2
	ldy #ROOM_TYPE
	lda #TUNNEL2
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	 
	;turn the new room into type 3
	lda #TUNNEL3
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	;new room's right becomes old room's right
	ldy #ROOM_RIGHT
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	;new room's up becomes old room's up
	ldy #ROOM_UP
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	;old room's right now leads left to new room
	ldy #ROOM_RIGHT
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	tax ; x = room to alter
	ldy #ROOM_LEFT
	jsr SetConnection
	
	;old room's upper neighbor now leads down to new room
	ldy #ROOM_UP
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	tax ; x = room to alter
	ldy #ROOM_DOWN
	jsr SetConnection
	
	;1st rooms right and up become 255
	ldy #ROOM_RIGHT
	lda #255
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	ldy #ROOM_UP
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	
	;new room's left and down become 255
	ldy #ROOM_LEFT
	lda #255
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	ldy #ROOM_DOWN
;	sta [lastRoomPtrLo],y
	sta (lastRoomPtrLo),y
	
	rts

;x = room # to alter
;y = direction
;newRoom = value	
SetConnection
	;save board ptr
	lda boardPtrLo
	pha
	lda boardPtrHi
	pha
	
	;reset pointer
	lda #>board
	sta boardPtrHi
	lda #<board
	sta boardPtrLo
	;get a room
	;multiply room # x 8
	cpx #0
	beq :done
:mulLp
	clc
	lda boardPtrLo
	adc #8
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	dex
	bne :mulLp
:done
	lda newRoom
;	sta [boardPtrLo],y
	sta (boardPtrLo),y
	;restore board ptr
	pla
	sta boardPtrHi
	pla
	sta boardPtrLo
	rts

;Sets the room at boardPtr to visitted
VisitRoom
	ldy #ROOM_FLAGS
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	and #VISITTED_BIT ; already visitted
	bne :x	
;.redraw	
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	ora #VISITTED_BIT
;	sta [playerRoomPtrLo],y
	sta (playerRoomPtrLo),y
	;redraw it
	lda #1
	sta redraw

	;is there a bat there?
	;if so, put the bat sprite there
	ldy #ROOM_FLAGS
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	and #BAT_BIT
	beq :x
	jsr ShowBat
:x	rts

;sets the 8 pallets and bg color
LoadPalettes 
  jsr LDA_2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  jsr STA_2006             ; write the high byte of $3F00 address
  LDA #$00
  jsr STA_2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop
  LDA palette,x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  jsr STA_2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

	rts
	
;populates the attribute table with all the same palette
SetAttrTable
	rts
  
;copies the board into the tilemap in ram
WriteBoardToPPU
	lda #>board
	sta boardPtrHi
	lda #<board
	sta boardPtrLo
	lda #0
:loop
	pha
	
	ldy #ROOM_FLAGS
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	and #VISITTED_BIT
	beq :DrawDone0
	
	jsr SetPPUAddr  ; based on boardPtr
	
	;get room type
	jsr DrawMapLocation
:DrawDone0
	;advance pointer to next room
	clc 
	lda boardPtrLo
	adc #BYTES_PER_ROOM
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	;done?
	pla
	clc
	adc #1
	cmp numRooms
	bne :loop
	rts

DrawMapLocation
	ldy #ROOM_TYPE
;	lda [boardPtrLo],y
	lda (boardPtrLo),y
	cmp #ROOM
	bne :skip1
	jsr DrawRoom
	jmp :DrawDone
:skip1
	cmp #TUNNEL1
	bne :skip2
	jsr DrawTunnel1
	jmp :DrawDone	
:skip2
	cmp #TUNNEL2
	bne :skip3
	jsr DrawTunnel2
	jmp :DrawDone
:skip3	
	cmp #TUNNEL3
	bne :skip4
	jsr DrawTunnel3	
	jmp :DrawDone
:skip4
	cmp #TUNNEL4
	bne :skip5
	jsr DrawTunnel4	
:skip5
:DrawDone
	rts
	


ClearPalettes
	rts

;Sets the player sprite's coord
;assumes boardPtr has already been set
;to the current room
SetPlayerCoord
	jsr SetPlayerSprite
	ldy #ROOM_X
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	asl a ; x 32
	asl a
	asl a
	asl a
	asl	a
	sta PLAYER_X
	;add some to move it over
	clc
	ldy #ROOM_TYPE
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	tay
	lda playerXOffsets,y
	adc PLAYER_X
	sta PLAYER_X
	ldy #ROOM_Y
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	asl a ; x 32
	asl a
	asl a
	asl a
	asl a
	sta PLAYER_Y
	;add some to move it down
	clc
	ldy #ROOM_TYPE
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	tay
	lda playerYOffsets,y
	adc PLAYER_Y
	sta PLAYER_Y
	;draw the bottom half of the player
	lda PLAYER_X
	sta PLAYER_X+4
	lda PLAYER_Y
	clc
	adc #8
	sta PLAYER_Y+4
	rts	

SetPlayerSprite
 	lda shooting
	beq :no
	ldx #$6C   ; draw with bows
	ldy #$7C 
	bne :draw
:no
	ldx #$48  ; draw normal player
	ldy #$58 
:draw	
	stx PLAYER_SPRITE
	sty PLAYER_SPRITE+4
	rts

;hides all sprites except sprite 0 (the cursor)
InitSprites

	jsr HideSprites	


	lda #$48
	sta PLAYER_SPRITE
	lda #3
	sta PLAYER_SPRITE+1
	sta PLAYER_SPRITE+5
	 

	ldy #0  ; spr0 y
	lda #4  
	sta sprites,y

	iny 
	lda #6 ; sprite index
	sta sprites,y

	iny ;skip attrs
	iny ; x
	lda #4 ; spr 
	sta sprites,y

	lda #CURSOR_TILE
	sta CURSOR_SPRITE

	;set wumpus sprites
	ldy #FIRST_WUMPUS_SPRITE_TILE
	ldx #0
:lp	lda WumpusPattern,x
	sta $200,y
	lda #3 ; set palette to 3
	sta $201,y
	iny ; advance to next sprite
	iny
	iny
	iny
	inx
	cpx #12
	bne :lp
	rts
 
	;set palettes for 4 large bat sprites
	lda #3
	sta LARGE_BAT_ATTRS
	sta LARGE_BAT_ATTRS+4
	sta LARGE_BAT_ATTRS+8
	sta LARGE_BAT_ATTRS+12


	lda #UPPER_TEETH_TILE
	sta UPPER_TEETH_SPRITES
	sta UPPER_TEETH_SPRITES+4
	sta UPPER_TEETH_SPRITES+8

	;wumpus eyes for title
	lda WUMPUS_EYES_TILE
	sta WUMPUS_EYES_SPRITES
	sta WUMPUS_EYES_SPRITES+4
	
	;set palette
	lda #3
	sta WUMPUS_EYES_SPRITES_ATTRS
	sta WUMPUS_EYES_SPRITES_ATTRS+4

	
	rts

;sets roomPtr to address of current room's data
SetPlayerRoomPtr
	lda #0
	sta playerRoomPtrHi
	lda playerRoom
	sta playerRoomPtrLo 	
	beq :noMult
	ldy #3 ; times 8
:lp	
	clc
	asl playerRoomPtrLo
	rol playerRoomPtrHi
	dey
	bne :lp
	;add base offset
:noMult	
	;board starts at $300
	clc
	lda #>board
	adc playerRoomPtrHi
	sta playerRoomPtrHi
	rts


MoveLeft
	lda #LEFT
	sta direction
	lda #20
	sta btnCounter
	ldy #ROOM_LEFT
;	lda [playerRoomPtrLo],y
    lda (playerRoomPtrLo),y
	bmi :beep
	sta playerRoom
	;set sprite coord
	jsr SetPlayerRoomPtr
	jsr VisitRoom
	lda #1
	sta movePlayer
	jsr SetPlayerCoord
	jsr PlayFootSteps
	jsr CheckHazards
	jmp :x
:beep
	jsr PlayErrorBeep	
:x	rts
	
MoveRight
	lda #RIGHT
	sta direction
	lda #20
	sta btnCounter
	ldy #ROOM_RIGHT
;	lda [playerRoomPtrLo],y
    lda (playerRoomPtrLo),y
	bmi :beep
	sta playerRoom
	;set sprite coord
	jsr SetPlayerRoomPtr
	jsr VisitRoom
	lda #1
	sta movePlayer
	jsr SetPlayerCoord
	jsr PlayFootSteps
	jsr CheckHazards
	jmp :x
:beep
	jsr PlayErrorBeep		
:x	rts
	
MoveUp
	lda #UP
	sta direction
	lda #20
	sta btnCounter
	ldy #ROOM_UP
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	bmi :beep
	sta playerRoom
	;set sprite coord
	jsr SetPlayerRoomPtr
	jsr VisitRoom
	jsr SetPlayerCoord
	lda #1
	sta movePlayer
	jsr PlayFootSteps
	jsr CheckHazards
	jmp :x
:beep
	jsr PlayErrorBeep	
:x	rts

MoveDown
	lda #DOWN
	sta direction
	lda #20
	sta btnCounter
	ldy #ROOM_DOWN
;	lda [playerRoomPtrLo],y
	lda (playerRoomPtrLo),y
	bmi :beep
	sta playerRoom
	;set sprite coord
	jsr SetPlayerRoomPtr
	jsr VisitRoom
	jsr SetPlayerCoord
	lda #1
	sta movePlayer
	jsr PlayFootSteps
	jsr CheckHazards
	jmp :x
:beep
	jsr PlayErrorBeep	
:x	rts	

CheckHazards
	ldy #ROOM_FLAGS
;	lda [playerRoomPtrLo],Y
    lda (playerRoomPtrLo),y
	and #WUMPUS_BIT
	beq :checkPit
	jsr DeathTransition
	jmp :x	 
:checkPit
;	lda [playerRoomPtrLo],Y
    lda (playerRoomPtrLo),y
	and #PIT_BIT
	beq :noPit
	jsr PitTransition
	jmp :x	 
:noPit
;	lda [playerRoomPtrLo],Y
    lda (playerRoomPtrLo),y
	and #BAT_BIT
	beq :noBat
	lda batAwake
	beq :wakeBat
	jsr BatTransition
	jmp :x
:wakeBat
	lda #1
	sta batAwake
	jsr PlayBatSqueak
	jsr ShowBat	
:noBat
:x	rts

;puts bat icon in player room
ShowBat

;BAT_ICON_Y equ $20C
;BAT_ICON_SPRITE equ $20D
;BAT_ICON_ATTRS equ $20E
;BAT_ICON_X equ $20F

	lda #BAT_ICON
	sta BAT_ICON_SPRITE
	
	lda #3 ; palette 3
	sta BAT_ICON_ATTRS

	ldy #ROOM_X
;	lda [batRoomPtrLo],y
    lda (batRoomPtrLo),y
	asl a
	asl a
	asl a
	asl a
	asl a
	clc
	adc #$0C ; bump to center of room  
	sta BAT_ICON_X
	ldy #ROOM_Y
;	lda [batRoomPtrLo],y
    lda (batRoomPtrLo),y
	asl A
	asl a
	asl a
	asl a
	asl a
	clc
	adc #$08 ; offset from top  
	sta BAT_ICON_Y ; 3rd sprite y
	rts

PlayBatSqueak
	jsr StopMusic
	jsr InitAPU

	lda #%00000111 ;enable Sq1, Sq2 and Tri channels
	jsr STA_4015
	lda #%00101000 ; dc=0,enable len=1,variable vol,vol=8
;	sta APU_PULSE1_CFG
	jsr STA_4000
	
	lda #%11001001 ; sweep on=1, sweep period=4,neg=0,shift=001?
	sta APU_PULSE1_SWEEP
	lda #$0D  ; #269 = $10D
;	sta APU_PULSE1_FREQLO
	jsr STA_4002

	lda #%00110001  ; len =6 plus hi byte of period
;	sta APU_PULSE1_LEN_FREQHI
	jsr STA_4003
	
	lda #%11011000 ; dc=11,enable len=1,disable timer=1,variable vol,vol=10000
	sta APU_PULSE2_CFG
	lda #%11000101 ; sweep on, sweep period=4,neg=0,shift=5?
	sta APU_PULSE2_SWEEP
	lda #72  ; 
	sta APU_PULSE2_FREQLO
	lda #%01110000  ; len =14 plus hi byte of period =0
	sta APU_PULSE2_LEN_FREQHI


	rts


;Leaves a number less than 56 in A
;The last number is stored in lastRand
;NextRand
;	clc
;	lda fib1
;	adc fib2
;	ldy fib2
;	sty fib1
;	sta fib2
;:lp cmp #56
;	bcc :x ;< number of rooms?
;	sec
;	sbc #56 
;	jmp :lp
;:x	sta lastRand
;	rts

;puts the player in a safe room, then sets that room to 'visitted'
PlacePlayer
:lp
	jsr GetRandRoomPtr
	ldy #ROOM_TYPE
;	lda [boardPtrLo],y
    lda (boardPtrLo),y
	bne :lp
	ldy #ROOM_FLAGS
;	lda [boardPtrLo],y
    lda (boardPtrLo),y
    and #ANY_HAZARD
	bne :lp	
	
;	lda [boardPtrLo],y
    lda (boardPtrLo),y
	ora #VISITTED_BIT
;	sta [boardPtrLo],y 
    sta (boardPtrLo),y
	
	lda lastRand  ;last room picked
	sta playerRoom
	lda boardPtrLo
	sta playerRoomPtrLo
	lda boardPtrHi
	sta playerRoomPtrHi
	jsr SetPlayerCoord
	rts

;sets every visitted bit on every room to true
;and shows the Wumpus
ShowBoard
	lda #>board
	sta boardPtrHi
	lda #<board
	sta boardPtrLo

	ldx #0
	ldy #ROOM_FLAGS
:lp	
;	lda [boardPtrLo],y
    lda (boardPtrLo),y
	ora #VISITTED_BIT
;	sta [boardPtrLo],y
    sta (boardPtrLo),y
	;advance to next room
	clc
	lda boardPtrLo
	adc #8
	sta boardPtrLo
	lda boardPtrHi
	adc #0
	sta boardPtrHi
	inx
	cpx numRooms
	bne :lp
	rts

;positions the wumpus sprites on the room with the wumpus
ShowWumpus
	lda wumpusRoom
	jsr GetRoomPtr
	ldy #ROOM_Y
;	lda [destPtrLo],y
    lda (destPtrLo),y
	asl a
	asl a
	asl a
	asl a
	asl a
	ldy #FIRST_WUMPUS_SPRITE_Y
	;put all tiles at the same y
	ldx #0 ;loop counter
:lp	
	sta $200,y ; sprite 4 y
	iny
	iny
	iny
	iny 
	inx
	cpx #12
	bne :lp

	;put all wumpus tiles as same x
	;set wumpus x
	ldy #ROOM_X
;	lda [destPtrLo],y
    lda (destPtrLo),y
	asl a
	asl a
	asl a
	asl a
	asl a
	ldy #FIRST_WUMPUS_SPRITE_X  ; 7 ; 1st sprites x coord
	ldx #0
:lpX	
	sta $200,y ; sprite x
	iny
	iny
	iny
	iny
	inx
	cpx #12
	bne :lpX
	
	;apply x offsets to each sprite
	ldx #0
	ldy #FIRST_WUMPUS_SPRITE_X
:lp3
	clc
	lda WumpusXOffsets,x
	adc $200,y
	sta $200,y
	tya
	clc
	adc #4
	tay
	inx
	cpx #12
	bne :lp3

	;apply y offsets to each sprite
	ldx #0
	ldy #FIRST_WUMPUS_SPRITE_Y
:lp4
	clc
	lda WumpusYOffsets,x
	adc $200,y
	sta $200,y
	tya
	clc
	adc #4
	tay	
	inx
	cpx #12
	bne :lp4	
	rts
 
 

EmptyRoomPattern
	db $30,$31,$32,$33,$40,$41,$42,$43,$50,$51,$52,$53,$60,$61,$62,$63
 
DraftRoomPattern
	db $74,$75,$76,$77
	db $84,$85,$86,$87
	db $94,$95,$96,$97
	db $A4,$A5,$A6,$A7
	
SlimePattern
	db $3C,$3D,$3E,$3F,$4C,$4D,$4E,$4F,$5C,$5D,$5E,$5F,$6C,$6D,$6E,$6F
 
DraftSlimePattern
;	.DB $80,$81,$82,$83,$90,$91,$92,$93,$A0,$A1,$A2,$A3,$B0,$B1,$B2,$B3
	db $70,$71,$72,$73,$80,$81,$82,$83,$90,$91,$92,$93,$A0,$A1,$A2,$A3

;PitPattern
;	db $B0,$B1,$B2,$B3
;	db $C0,$C1,$C2,$C3
;	db $D0,$D1,$D2,$D3
;	db $E0,$E1,$E2,$E3


WumpusPattern
	db $84,$85,$86,$87
	db $94,$95,$96,$97
	db $A4,$A5,$A6,$A7

WumpusXOffsets
	db 0,8,16,24
	db 0,8,16,24
	db 0,8,16,24

WumpusYOffsets
	db 12,12,12,12
	db 20,20,20,20
	db 28,28,28,28

	
;left to top
Tunnel1Pattern
	db $34,$35,$36,$37
	db $44,$45,$46
	db $54,$55
	
;left to bottom
Tunnel2Pattern
	db $48,$49
	db $58,$59,$5A
	db $68,$69,$6A,$6B 

;top to right
Tunnel3Pattern
	db $38,$39,$3A,$3B
	db 	$49,$4A,$4B
	db 		$5A,$5B 

;bottom to right
Tunnel4Pattern
	db 		$46,$47
	db 	$55,$56,$57
	db $64,$65,$66,$67 


;the first byte of palettes 1-3 is spacer
palette
  db $0,$30,$16,$13  
  db $0,$30,$38,$22 ;tunnel
  db $0,$30,$21,$13
  db $0,$30,$17,$13   ;;background palette
;sprite palettes
  db $22,$1C,$15,$14  ; default
  db $22,$02,$15,$3C  
  db $22,$30,$16,$13    ; dead player
  db $22,$30,$16,$0D ; blue, white, red, black?   ; bat

;for PPU address (lo,hi)
yoffsets
	db 0,0 ; 0
	db $80,$0 ; 128
	db $00,$01 ;  
	db $80,$01 ; 
	db $00,$02 ; 
	db $80,$02 ; 
	db $00,$03 ; 
	db $80,$03 ; 

;y offset of player sprite for each room type
playerXOffsets	
	db 12 ; normal room	
	db 8   ; left-up tunnel
	db 8   ; left-down tunnel
	db 16  ; top-right tunnel
	db 16  ; bottom-right tunnel

;y offset of player sprite for each room type
playerYOffsets	
	db 12 ; normal room	
	db 8 ; left-up tunnel
	db 18 ; left-down tunnel	
	db 8 ; left-up tunnel
	db 18 ; left-up tunnel

IRQ
;   rti
    rts

NMI
	pha
	txa
	pha
	tya
	pha  


	;need this to hide sprites
	lda #$02 ; page 200
	jsr STA_4014       ; set the high byte (02) of the RAM address, start the transfer

	sta nmiStarted
	lda NMIHanlderLo
	sta :p+1
	lda NMIHanlderLo+1
	sta :p+2

;	jmp [NMIHanlderLo]
:p  jmp $0000


MainNMI
	lda redraw
	beq :noRedraw
	lda playerRoomPtrLo
	sta boardPtrLo
	lda playerRoomPtrHi
	sta boardPtrHi
	jsr SetPPUAddr
	jsr DrawMapLocation
	lda #0
	sta redraw
 	jmp :x
:noRedraw

	lda inputProcessed
	beq :wait  ;if not handled, don't read
	jsr ReadController
	lda #0
	sta inputProcessed
:wait
 
	;drecrement counters

	lda btnCounter
	beq :btnDone
	dec btnCounter 
:btnDone

	lda counter
	beq :x
	dec counter
:x 

  jsr PlayMusic

	lda #1
	sta nmiFlag

  LDA #$00        ;;tell the ppu there is no background scrolling
  jsr  STA_2005
  jsr  STA_2005

  pla 
  tay
  pla 
  tax
  pla  
;  rti
  rts

	put main.asm
	put nesutils.asm
	put transitions.asm
	put deathcode.asm
	put shootingcode.asm
	put pitcode.asm
	put batcode.asm
	put wincode.asm
	put scorecode.asm
	put titlecode.asm
	put rle.asm
	put reveal.asm
	put startscreencode.asm
	put shootself.asm
	put helpscreen.asm

;   .bank 1
;  .org $E000
    ds  \,$00
	ds  $300
  	put graphics.asm
	put titlemusic.asm
	put titlescreendata.asm
	put ScoreScreenData.asm
	put winmusic.asm
	put nesnotes.asm
	put nesmusic.asm
 	put helpscreendata.asm

    ds  $14F4
;  .org $FFFA     ;first of the three vectors starts here
   dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
   dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
   dw IRQ          ;external interrupt IRQ is not used in this tutorial


;;;;;;;;;;;;;;  
  
;  .bank 2
;  .org $0000
;  .incbin "wumpus.chr"   puts 8KB graphics file from SMB1
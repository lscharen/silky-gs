



;Set background to all blank tiles
ClearPPU
	jsr LDA_2002
	lda #$20
	jsr STA_2006
	lda #$00
	jsr STA_2006
	lda #SOLID_BLACK  ; blank tile
;	lda #$DC
	;write 960 tiles 32 x 30
	
	ldy #30
:outerLp	
	ldx #32 ; write 256 loop
:innerLp
	jsr STA_2007
	dex
	bne :innerLp
	dey
	bne :outerLp
	rts


;hides all sprites 
HideSprites 
	
	;now hide all the other sprites
;	lda #0 
	lda #248
	ldy #0
:lp 
	sta $200,y 
	iny
	iny
	iny
	iny
	bne :lp ; if we didn't roll-over, keep looping
	 
	rts

 ;copies a 4x4 block of tiles to the PPU
;the tiles pattern is copied from srcPtr(Pattern) to destPtr (PPU)
Copy16Tiles
	ldy #0
	lda #0 ; outer loop counter
	;now copy 4 tiles 4 times
:outerLp	
	pha
	jsr LDA_2002
	lda destPtrHi ; set PPU write address
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006
	ldx #0 ; inner loop counter
:innerLp
;	lda [srcPtrLo],y ; copy a tile
    lda (srcPtrLo),y
	jsr STA_2007
	iny ;next tile
	inx 
	cpx #4
	bne :innerLp		
	;add 32 to PPU adddr drop down a row
	clc
	lda #32
	adc destPtrLo
	sta destPtrLo
	lda #0
	adc destPtrHi
	sta destPtrHi
	pla ; restore outer loop counter
	clc
	adc #1
	cmp #4
	bne :outerLp
	rts




;copies a 4x3 block of tiles to the PPU
;the tiles pattern is copied from srcPtr(Pattern) to destPtr (PPU)
Copy12TilesH
	ldy #0
	lda #0 ; outer loop counter
	;now copy 4 tiles 4 times
:outerLp	
	pha
	jsr LDA_2002
	lda destPtrHi ; set PPU write address
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006
	ldx #0 ; inner loop counter
:innerLp
;	lda [srcPtrLo],y ; copy a tile
	lda (srcPtrLo),y
	jsr STA_2007
	iny ;next tile
	inx 
	cpx #4
	bne :innerLp		
	;add 32 to PPU adddr drop down a row
	clc
	lda #32
	adc destPtrLo
	sta destPtrLo
	lda #0
	adc destPtrHi
	sta destPtrHi
	pla ; restore outer loop counter
	clc
	adc #1
	cmp #3
	bne :outerLp
	rts




;copies a 3x4 block of tiles to the PPU
;the tiles pattern is copied from srcPtr(Pattern) to destPtr (PPU)
Copy12TilesV
	ldy #0
	lda #0 ; outer loop counter
	;now copy 4 tiles 4 times
:outerLp	
	pha
	jsr LDA_2002
	lda destPtrHi ; set PPU write address
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006
	ldx #0 ; inner loop counter
:innerLp
;	lda [srcPtrLo],y ; copy a tile
    lda (srcPtrLo),y
	jsr STA_2007
	iny ;next tile
	inx 
	cpx #3
	bne :innerLp		
	;add 32 to PPU adddr drop down a row
	clc
	lda #32
	adc destPtrLo
	sta destPtrLo
	lda #0
	adc destPtrHi
	sta destPtrHi
	pla ; restore outer loop counter
	clc
	adc #1
	cmp #4
	bne :outerLp
	rts

;copies a 4x4 block of tiles to the PPU
;the tiles pattern is copied from srcPtr(Pattern) to destPtr (PPU)
Copy2x2Tiles
	ldy #0
	lda #0 ; outer loop counter
	;now copy 4 tiles 4 times
:outerLp	
	pha
	jsr LDA_2002
	lda destPtrHi ; set PPU write address
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006
	ldx #0 ; inner loop counter
:innerLp
;	lda [srcPtrLo],y ; copy a tile
	lda (srcPtrLo),y
	jsr STA_2007
	iny ;next tile
	inx 
	cpx #2
	bne :innerLp		
	;add 32 to PPU adddr drop down a row
	clc
	lda #32
	adc destPtrLo
	sta destPtrLo
	lda #0
	adc destPtrHi
	sta destPtrHi
	pla ; restore outer loop counter
	clc
	adc #1
	cmp #2
	bne :outerLp
	rts

;increments the memory pointed to by srcPtrLo/Hi
;the lower and upper halfs are treated as separate
;based ten digits
;Good for numbers 0-99
BCDInc
	tax ; save 
	cmp #$99
	beq :roll
	txa
	and #$0F
	cmp #$09
	beq :carry
:inc
	txa ; save copy
	clc
	adc #1
	jmp :x
:roll
	lda #0
	beq :x
:carry
	txa ; get 
	clc
    adc #$10
	and #$f0 ; clear low bits
:nc 
:x   rts    

;Write a line of letter tiles into the PPU
;assumes srcPtr is set to start of word
;assumes destPtrLo/Hi is set to PPU address
DrawText
	jsr LDA_2002
	lda destPtrHi
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006
	ldy #0
:lp 
;	lda [srcPtrLo],y
	lda (srcPtrLo),y
	beq :x
	jsr STA_2007
	iny
	bne :lp
:x	
	rts

;Draw a number into the background nametable
;Assumes PPU points to where you want to draw
;A contains the number
;destPtrLo points to PPU addr
DrawBCDNumber
	tay
	pha ; save copy
	lda #<NumberTiles
	sta srcPtrLo
	lda #>NumberTiles
	sta srcPtrHi
	lda destPtrHi
	pha
	lda destPtrLo
	pha
	tya
	lsr a ; isolate digit ( div 16)
	lsr a
	lsr a
	lsr a
	asl a ; x 4 
	asl a
	clc
	adc srcPtrLo
	sta srcPtrLo
	lda srcPtrHi
	adc #0
	sta srcPtrHi

	jsr Copy2x2Tiles
;	restore PPU and add 4
	pla 
	sta destPtrLo
	pla 
	sta destPtrHi
	clc
	lda destPtrLo
	adc #2
	sta destPtrLo
	lda destPtrHi
	adc #0
	sta destPtrHi
	jsr LDA_2002  ; reset PPU_ADDR
	lda destPtrHi
	jsr STA_2006
	lda destPtrLo
	jsr STA_2006
	;reset tile pointer	
	lda #<NumberTiles
	sta srcPtrLo
	lda #>NumberTiles
	sta srcPtrHi
	;write second digit
	pla
	and #$0F ; isolate lower 4 bits
	asl a ; x 4 
	asl a
	clc
	adc srcPtrLo
	sta srcPtrLo
	lda srcPtrHi
	adc #0
	sta srcPtrHi
	jsr Copy2x2Tiles
	rts


;sets bg pal color to A
SetBackgroundColor
	tax
	jsr LDA_2002
    lda #$3f
    jsr STA_2006
    lda #$0
    jsr STA_2006
;    stx PPU_DATA
    jsr STX_2007
	rts


;disables rendering and the NMI
PPUOff
   ;wait for vblank
  lda #0
  sta nmiFlag
;:vblankwait1
;  lda nmiFlag
;  beq :vblankwait1

   LDA #%00010000   ; disable NMI, sprites from Pattern Table 0, background from Pattern Table 1
	jsr STA_2000
  

   ;turn off PPU and NMI
    LDA #%00010000   ; disable NMI, sprites from Pattern Table 0, background from Pattern Table 1
	jsr STA_2000


    lda #%00000000   ; enable sprites, enable background, no clipping on left side
	jsr STA_2001 

 

    rts

;Enables rendering and the NMI
PPUOn
  ;wait for vblank
;  lda #$80
;:vblankwait1      
;  jsr BIT_2002
;  bpl :vblankwait1

  jsr LDA_2002
  ;wait for vblank
;  lda #$80
;:vblankwait2       
;  jsr BIT_2002
;  bpl :vblankwait2


  ;wait for vblank
  jsr  LDA_2002 ; clear bit
;  lda #$80
;:vblankwait3       
;  jsr BIT_2002
;  bpl :vblankwait3


    ;turn on PPU and NMI
	LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
	jsr STA_2000

  ;wait for vblank
  jsr LDA_2002 ; clear bit
  lda #$80
;:vblankwait4       
;  jsr BIT_2002
;  bpl :vblankwait4
;	LDA #%00011000   ; enable sprites, enable background, clipping on left side
	LDA #%00011110   ; enable sprites, enable background, no clipping on left side
	jsr STA_2001

    rts

;a  = non zero if a button was pressed
AnyKey

;read controller
	jsr ReadController
	lda buttonPresses
	
	rts	

ResetScreenAttrs
	jsr  LDA_2002 ; reset PPU addr
	lda #>PPU_ATTRS
	jsr STA_2006
	lda #<PPU_ATTRS
	jsr STA_2006
	lda #$0
	ldy #$0
:lp
	jsr STA_2007
	iny
	cpy #64 
	bne :lp	
	rts

;Can't be more than 8 chars due to #of sprites on scan line
;scrptr = start of pattern
;a = start sprite

DrawSpriteText
	asl a ; start sprite times 4
	asl a 
	tax
	ldy #0
:lp 
;	lda [srcPtrLo],y
    lda (srcPtrLo),y
	beq :x
	sta $201,x
	lda textY
	sta $200,x
	lda textPalette
	sta $202,x
	lda textX
	sta $203,x
	clc
	adc #8
	sta textX
	iny ; next letter
	inx ; next sprite
	inx
	inx	
	inx
	jmp :lp
:x	rts	


;BUTTON_A = 128
;BUTTON_B = 64
;BUTTON_SELECT = 32
;BUTTON_START = 16
;BUTTON_UP = 8
;BUTTON_DOWN = 4
;BUTTON_LEFT = 2
;BUTTON_RIGHT = 1

ReadController
	;save previous button state
	lda controllerState
	sta prevControllerState

;	lda #0
;	sta controllerState
;	lda #1
;	jsr STA_4016 
;	lda #0
;	jsr STA_4016
;	ldx #0
;:lp	
;	sta STA_4016
;	lsr a; bit0 -> Carry
;	rol controllerState ; bit0 <- Carry
;	inx
;	cpx #8
;	bne :lp

native_joy    EXT
    ldal  native_joy
	sta   controllerState

;keep button A from toggling
;  lda controllerState
;  and #BUTTON_A
;  bne :ADown
;  ;a is up 
;  ldx btnAUpCount; A is up
;  cpx #2
;  beq :outA   ; button is definitely up
;  inc btnAUpCount
;  lda controllerState  ;reset it - it wasn't up long enough
;  ora #BUTTON_A
;  sta controllerState
;  jmp :outA
;:ADown
;  lda #0
;  sta btnAUpCount
;:outA

 ;repeat for B if needed later

	lda controllerState
	eor prevControllerState ; find changed buttons
	and controllerState ; compare them to presses buttons
	sta buttonPresses
 
	rts


;FakeRead
;	lda #1
;	jsr STA_4016 
;	lda #0
;	jsr STA_4016
;	ldx #8
;:lp	
;	lda	$4016
;	dex
;	bne :lp
;	rts	

DecButtonCounters
	lda buttonACounter
	beq :skip
	dec buttonACounter
:skip		
	lda buttonBCounter
	beq :x
	dec buttonBCounter
:x	rts


NextRand
	lda randLo
	and #%00000011
	beq :zero
	cmp #$03
	beq :zero
	lda #%10000000
	jmp :or
:zero
	lda #0
:or	lsr randHi
	ror randLo
	ora randHi
	sta randHi
	ldx randLo
;	dex
	txa
	;put in range 0 - 56
:lp cmp #56
	bcc :x ;< number of rooms?
	sec
	sbc #56 
	jmp :lp
:x	sta lastRand
	rts
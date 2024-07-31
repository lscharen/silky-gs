DeathMain
	;wait for music to be done
	ldy channel1Index
;	lda [channel2PtrLo],y
    lda (channel2PtrLo),y
	bne :x
	jsr ReadController
	lda buttonPresses
	and #BUTTON_A
	beq :x
	jsr TransitionScoreboard
:x    rts

DeathNMI
  
    lda smile
    bne :s 
    jsr UpdateTeeth
:s  
	jsr PlayMusic

	
    LDA #$00        ;;tell the ppu there is no background scrolling
    jsr STA_2005
    jsr STA_2005

	lda #1
	sta nmiFlag

    pla 
    tay
    pla 
    tax
    pla
;    rti
    rts


;sets the positions and ids of the arrow sprites
SetupTeeth
	lda #0
	sta smile
	lda #$40  ; 8 x 2
	sta batCounter
	lda #0
	sta doneFalling

	sta topTeethPtrLo
	lda #$22
	sta topTeethPtrHi
	
	lda #$60
	sta bottomTeethPtrLo
	lda #$23
	sta bottomTeethPtrHi

	jsr DrawTopTeeth
	jsr DrawBottomTeeth
	rts
 
 
DrawTopTeeth
	;top teeth
	jsr LDA_2002  	 ; read latch 
	lda topTeethPtrHi			 
	jsr STA_2006
	lda topTeethPtrLo
	jsr STA_2006
	;8 rows of teeth 1 top
	ldy #0
:lp1  
	lda Blanks,y
	jsr STA_2007
	iny
	cpy #96
	bne :lp1
	rts
	
DrawBottomTeeth
	;bottom teeth
	jsr LDA_2002  	 ; read latch 
	lda bottomTeethPtrHi		 
	jsr STA_2006
	lda bottomTeethPtrLo
	jsr STA_2006
	 
	ldy #0
:lp2  
	lda BottomTeeth1,y
	jsr STA_2007
	iny
	cpy #96
	bne :lp2	
	rts
 

;checks to see if done 
UpdateTeeth
	lda batCounter
	beq :s
	and #$07 ; multiple of 8?
	cmp #$04
	bne :d
	clc
	lda topTeethPtrLo
	adc #32
	sta topTeethPtrLo
	lda #0
	adc topTeethPtrHi
	sta topTeethPtrHi
	jsr DrawTopTeeth
:d	dec batCounter
	rts
:s  lda smile
    bne :x
	beq Smile
:x	rts
 
Smile 
	lda #1
	sta smile
	jsr LDA_2002  	 ; read latch 
	lda topTeethPtrHi		 
	jsr STA_2006
	lda topTeethPtrLo
	jsr STA_2006	 
	lda #TOOTH1
	jsr STA_2007
	lda #SOLID_WHITE
	jsr STA_2007
	jsr STA_2007	
	lda #TOOTH2
	;drop down
	jsr STA_2007
	clc
	lda topTeethPtrLo
	adc #$20
	sta topTeethPtrLo
	lda topTeethPtrHi
	adc #0
	sta topTeethPtrHi
	jsr LDA_2002
	lda topTeethPtrHi
	jsr STA_2006
	lda topTeethPtrLo
	jsr STA_2006
	lda #EMPTY
	jsr STA_2007
	lda #TOOTH1
	jsr STA_2007
	lda #TOOTH2
	jsr STA_2007
	lda #EMPTY
	jsr STA_2007	
	;drop 
	clc
	lda topTeethPtrLo
	adc #$20
	sta topTeethPtrLo
	lda topTeethPtrHi
	adc #0
	sta topTeethPtrHi
	jsr LDA_2002
	lda topTeethPtrHi
	jsr STA_2006
	lda topTeethPtrLo	
	jsr STA_2006
	lda #TOOTH3	
	jsr STA_2007
	lda #TOOTH4
	jsr STA_2007	
	lda #EMPTY
	jsr STA_2007
	;drop 
	clc
	lda topTeethPtrLo
	adc #$20
	sta topTeethPtrLo
	lda topTeethPtrHi
	adc #0
	sta topTeethPtrHi
	jsr LDA_2002
	lda topTeethPtrHi
	jsr STA_2006
	lda topTeethPtrLo	
	jsr STA_2006
	lda #WHITE_TILE	
	jsr STA_2007
	lda #WHITE_TILE
	jsr STA_2007	
	lda #TOOTH4
	jsr STA_2007
	;drop again
	lda topTeethPtrLo
	adc #$21
	sta topTeethPtrLo
	lda topTeethPtrHi
	adc #0
	sta topTeethPtrHi
	jsr LDA_2002
	lda topTeethPtrHi
	jsr STA_2006
	lda topTeethPtrLo	
	jsr STA_2006
	lda #WHITE_TILE	
	jsr STA_2007
	lda #WHITE_TILE
	jsr STA_2007	
	jsr STA_2007
;right tooth 
	lda #$23
	sta bottomTeethPtrHi
	lda #$1C
	sta bottomTeethPtrLo
	jsr LDA_2002  	 ; read latch 
	lda bottomTeethPtrHi		 
	jsr STA_2006
	lda bottomTeethPtrLo
	jsr STA_2006	 
	lda #TOOTH1
	jsr STA_2007
	lda #SOLID_WHITE
	jsr STA_2007
	jsr STA_2007	
	lda #TOOTH2
	;drop down
	jsr STA_2007
	clc
	lda bottomTeethPtrLo
	adc #$20
	sta bottomTeethPtrLo
	lda bottomTeethPtrHi
	adc #0
	sta bottomTeethPtrHi
	jsr LDA_2002
	lda bottomTeethPtrHi
	jsr STA_2006
	lda bottomTeethPtrLo
	jsr STA_2006
	lda #EMPTY
	jsr STA_2007
	lda #TOOTH1
	jsr STA_2007
	lda #TOOTH2
	jsr STA_2007
	lda #EMPTY
	jsr STA_2007	
	;drop 
	clc
	lda bottomTeethPtrLo
	adc #$20
	sta bottomTeethPtrLo
	lda bottomTeethPtrHi
	adc #0
	sta bottomTeethPtrHi
	jsr LDA_2002
	lda bottomTeethPtrHi
	jsr STA_2006
	lda bottomTeethPtrLo	
	jsr STA_2006
	lda #EMPTY
	jsr STA_2007
	jsr STA_2007
	lda #TOOTH3	
	jsr STA_2007
	lda #TOOTH4
	jsr STA_2007	
	;drop 
	clc
	lda bottomTeethPtrLo
	adc #$21
	sta bottomTeethPtrLo
	lda bottomTeethPtrHi
	adc #0
	sta bottomTeethPtrHi
	jsr LDA_2002
	lda bottomTeethPtrHi
	jsr STA_2006
	lda bottomTeethPtrLo	
	jsr STA_2006
	lda #TOOTH3	
	jsr STA_2007
	lda #WHITE_TILE
	jsr STA_2007	
;	lda #TOOTH4
	jsr STA_2007
	;drop again
	lda bottomTeethPtrLo
	adc #$20
	sta bottomTeethPtrLo
	lda bottomTeethPtrHi
	adc #0
	sta bottomTeethPtrHi
	jsr LDA_2002
	lda bottomTeethPtrHi
	jsr STA_2006
	lda bottomTeethPtrLo	
	jsr STA_2006
	lda #WHITE_TILE	
	jsr STA_2007	
	jsr STA_2007	
	jsr STA_2007	
;	jsr DrawEyes
	rts
 
;this is now just part of the background
DrawEyes
	 

	;set tile src pointer
;	lda #<EyePattern
;	sta srcPtrLo
;	lda #>EyePattern
;	sta srcPtrHi	

;	jsr LDA_2002
;	lda #$21
;	sta destPtrHi
;	lda #$07
;	sta destPtrLo

;	jsr Copy16Tiles

	;reset dest ptr
 
	;set tile src pointer
;	lda #<EyePattern
;	sta srcPtrLo
;	lda #>EyePattern
;	sta srcPtrHi	

;	jsr LDA_2002
;	lda #$21
;	sta destPtrHi
;	lda #$16
;	sta destPtrLo

;	jsr Copy16Tiles
	rts


RequiemTreble 
  db C4, THREE_EIGTHS_NOTE, REST, C4, QUARTER_NOTE, REST, C4, EIGHTH_NOTE, REST, C4, THREE_EIGTHS_NOTE, REST
  db DS4, QUARTER_NOTE, REST, D4, EIGHTH_NOTE, REST, D4, QUARTER_NOTE, REST, C4, EIGHTH_NOTE, REST
  db C4, QUARTER_NOTE, REST, B3, EIGHTH_NOTE, REST, C4, HALF_NOTE, STOP_MUSIC


RequiemBass 
  db G3, THREE_EIGTHS_NOTE, REST, C3, QUARTER_NOTE, REST, G3, EIGHTH_NOTE, REST, C3, THREE_EIGTHS_NOTE, REST
  db C3, QUARTER_NOTE, REST, G3, EIGHTH_NOTE, REST, G3, QUARTER_NOTE, REST, C3, EIGHTH_NOTE, REST
  db G3, QUARTER_NOTE, REST, G3, EIGHTH_NOTE, REST, C3, HALF_NOTE 
  db STOP_MUSIC

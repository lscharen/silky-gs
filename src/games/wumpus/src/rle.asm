;rle.asm
;code to decompress the tilemap into the PPU
;srcPtrLo/Hi points to the tileMap
;the tilemap ends with token that has a count of 0
RLDecompTileMap
	jsr LDA_2002 ; reset PPU addr
	lda #$20
	jsr STA_2006
	lda #$00
	jsr STA_2006

RLDecomp
	ldy #0
:lp1
;	lda [srcPtrLo],y  ; read len
    lda (srcPtrLo),y
	beq :x
	tax
	iny 	
;    lda [srcPtrLo],y  ; read token
    lda  (srcPtrLo),y

	;write symbol A to PPU X times
:lp2
	jsr STA_2007
	dex
	bne :lp2
	iny ; if rolled after, add $100 to ptr
	bne :lp1
	clc
	lda srcPtrHi
	adc #$01
	sta srcPtrHi
	jmp :lp1
:x  rts

;code to decompress the tilemap into the PPU
;srcPtrLo/Hi points to the tileMap
;the tilemap ends with token that has a count of 0
;RLDecompAttrs
;	jsr LDA_2002 ; reset PPU addr
;	lda #$20
;	jsr STA_2006
;	lda #$00
;	jsr STA_2006
;	jmp RLDecomp


	 
;NES Music
;assumes you have
;   channel1PtrLo .rs 1
;   channel1PtrHi .rs 1
;   noteIndex .rs 1
;   channel1Silence .rs 1
;   channel1Index .rs 1


;enables channel 1
InitAPU
  lda #%00000111 ;enable Sq1, Sq2 and Tri channels
	jsr STA_4015
	 
	lda #APU_PUSLE1_ENABLE.DISABLE_DECAY.DUTY_CYCLE_100.8 ; 8 = medium vol.
;  sta APU_PULSE1_CFG 
  sta shadowChannel1
  jsr STA_4000

;  sta APU_PULSE2_CFG
  sta shadowChannel2
  jsr STA_4004

    lda #0
;    sta APU_PULSE1_SWEEP
;    sta APU_PULSE2_SWEEP
    jsr  STA_4001
    jsr  STA_4005

    sta channel1Index
    sta channel2Index
  lda #1
    sta channel1Silence
    sta channel2Silence

  rts

StopMusic
  ;disable channels
  lda #0 ;enable Sq1, Sq2 and Tri channels
	jsr STA_4015

	;set pointer to not play
	lda #>NoMusic
	sta channel1PtrHi
  sta channel2PtrHi

	lda #<NoMusic
	sta channel1PtrLo
	sta channel2PtrLo
	
  lda #0
	sta channel1Index
	sta channel2Index

  lda #0
  sta channel1Silence
  sta channel2Silence
rts

;Call this at the end of the NMI so the 
;music doesn't interfere with the drawing
PlayMusic
  jsr PlayChannel1
  jsr PlayChannel2
  rts  

PlayChannel1
	ldy channel1Index
;  lda [channel1PtrLo],y
  lda (channel1PtrLo),y
  beq :x	 
	lda channel1Silence
  bne :note
    dec channel1Silence
    jmp :x 
:note
;  lda APU_STATUS
	jsr LDA_4015
  and #APU_PUSLE1_ENABLE
  bne :keepPlaying
  ;renable channel 1

	ldy channel1Index  ; get note index
  ldx channel1Index
;	lda [channel1PtrLo],y ; get note
  lda (channel1PtrLo),y
  bmi :silence ; is it a note or a rest?
  ;get that note
  asl a ; note x 2
  tay
  lda Notes,y  ; get note 
;	sta APU_PULSE1_FREQLO
  jsr STA_4002

  sty noteIndex
  txa
  tay 
  iny 
;  lda [channel1PtrLo],y	; get duration
  lda (channel1PtrLo),y
  asl a  ; left justify it to make room for freq hi
  asl a
  asl a
  ldy noteIndex
	ora Notes+1,y ; combine freq hi + len
; 	sta APU_PULSE1_LEN_FREQHI
  jsr STA_4003

  ;enable volume
  lda #$08.DISABLE_DECAY ; volume back on
;  ora APU_PULSE1_CFG
;  sta APU_PULSE1_CFG
  ora shadowChannel1
  sta shadowChannel1
  jsr STA_4000

  inc channel1Index ; skip note and fequency
  inc channel1Index
  jmp :x
:silence
  and #$7F ; clear top bit
  sta channel1Silence
  ;volume off
;  lda APU_PULSE1_CFG
;  jsr LDA_4000
  lda shadowChannel1
  and #$F0 ; volume to zero
  ;ora #DISABLE_DECAY
;  sta APU_PULSE1_CFG
  sta shadowChannel1
  jsr STA_4000
  ;next note
  inc channel1Index
:keepPlaying
:x	
	rts

PlayChannel2
	ldy channel2Index
;  lda [channel2PtrLo],y
  lda (channel2PtrLo),y
  beq :x	 
	lda channel2Silence
  bne :note
    dec channel2Silence
    jmp :x 
:note
;  lda APU_STATUS
	jsr LDA_4015

  and #APU_PUSLE2_ENABLE
  bne :keepPlaying
  ;renable channel 2

	ldy channel2Index  ; get note index
  ldx channel2Index
;	lda [channel2PtrLo],y ; get note
  lda (channel2PtrLo),y
  bmi :silence ; is it a note or a rest?
  ;get that note
  asl a ; note x 2
  tay
  lda Notes,y  ; get note 
;	sta APU_PULSE2_FREQLO
  jsr STA_4006
  sty noteIndex
  txa
  tay 
  iny 
;  lda [channel2PtrLo],y	; get duration
  lda (channel2PtrLo),y
  asl a  ; left justify it to make room for freq hi
  asl a
  asl a
  ldy noteIndex
	ora Notes+1,y ; combine freq hi + len
; 	sta APU_PULSE2_LEN_FREQHI
  jsr STA_4007
  ;enable volume
  lda #$08.DISABLE_DECAY ; volume back on
;  ora APU_PULSE2_CFG
;  sta APU_PULSE2_CFG
;  jsr ORA_4004
  ora shadowChannel2
  sta shadowChannel2
  jsr STA_4004
  inc channel2Index ; skip note and fequency
  inc channel2Index
  jmp :x
:silence
  and #$7F ; clear top bit
  sta channel2Silence
  ;volume off
;  lda APU_PULSE2_CFG
;  jsr LDA_4004
  lda shadowChannel2
  and #$F0 ; volume to zero
  ;ora #DISABLE_DECAY
;  sta APU_PULSE2_CFG
  sta shadowChannel2
  jsr STA_4004
  ;next note
  inc channel2Index
:keepPlaying
:x	
	rts

NoMusic
	db STOP_MUSIC

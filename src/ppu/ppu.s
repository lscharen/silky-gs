; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.
; Helper to perform the essential functions of rendering a frame
_ppuctrl    ds  2
_ppuscroll_y dw 0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppuscroll_x dw 0          ; Pad the top-byte with zero to allow 8- or 16-bit access
_ppumask    ds  2
_ppuversion ds  2

        mx    %00

; Alternate scanOAMSprites that unrolls the loop, uses exclusion tables and 8-bit operations
; to improve scanning speed

        mx   %00
scanOAMSprites2

; Since it's rare that all 64 sprites are active, the code is
; slightly biased for fast skipping.  Most NES games place sprites
; that are not in use below the screen, so we try to do an early
; out by testing the vertical range first.  Also, the IIgs screen
; is shorter than the NES screen, so even more sprites are rejected
; quickly.

; The first loop is optimized for exlcusions and simply
; records the index of the sprites that pass on the stack
; which can be processed with a more efficient register
; setup later.  The extra cycles saved by staying in 8-bit
; mode more than make up for the PHX instruction

; TIP: Put the exclusion tables in NES RAM space around $1000

        sep    #$30                 ; 8-bit index registers

        phb
        lda    #^ROMBase
        pha
        plb

        clc
        ldx    #OAM_START_INDEX*4   ; This is in the range [0, 252]
        txa                         ; Keep X = A
:loop
        ldy    ROMBase+DIRECT_OAM_READ,x
        ldx    y_exclude,y
        bne    :next

        DO  NO_TILE_EXCLUDE
        ELSE
        tax                         ; Restore the X-register
        ldy    ROMBase+DIRECT_OAM_READ+1,x
        ldx    tile_exclude,y
        bne    :next
        FIN

        pha                         ; Since A = X, we can just save it directly and fall through
:next
        adc    #4
        tax
        cmp    #OAM_END_INDEX*4
        bcc    :loop

; Now we have the index values on the stack.  Switch to 16-bit mode and start
; pre-computing essential data

        lda    ROMBase+DIRECT_OAM_READ,x

        rep    #$20
        ldy    #0
:loop2
        plx
        lda    ROMBase+DIRECT_OAM_READ,x
        inc
        sta    OAM_COPY,y

        lda    ROMBase+DIRECT_OAM_READ+2,x
        sta    OAM_COPY+2,y

        iny
        iny
        iny
        iny

        plb                         ; Restore the bank back to
        rts



; Scan the OAM copy and start to build up the data structures for rendering the screen.
;
; The first step is building a bitmap of lines with sprites, which are used to segment
; the screen in the "sprite" and "background" runs.
;
; There are actually two bitmaps that are used on alternating calls.  If the screen is
; scrolling, or otherwise needs to be completely drawn, just the "current" bitmap is used.
; But if we the background is not changing, then the runtime can render only lines that
; have changed from one frame to the next.

OAM_COPY      ds 256
spriteCount   dw 0
shadowBitmap0 ds 32                ; Bitmap to use when frameCount & 1 == 0
shadowBitmap1 ds 32                ; Bitmap to use when frameCount & 1 == 1
tileBitmap    ds 64                ; Bitmap that marks which rows had background tile updates (32 bytes for vertical mirroring, 64 for horizontal)

         mx   %00
scanOAMSprites

         ldx   CurrShadowBitmap

; Erase the bitmap array for the current frame

]n       equ   0
         lup   15
         stz:  ]n,x
]n       =     ]n+2
         --^

; Check if sprites are disabled

         lda   ControlBits
         and   #CTRL_SPRITE_ENABLE
         bne   *+6
         stz   spriteCount
         rts

; Check if the PPU is in 8x8 or 8x16 mode

         lda   _ppuctrl
         bit   #NES_PPUCTRL_SPRSIZE
         beq   *+5
         brl   scan8x16

; We're committed to 8x8 mode, so patch things

         stx   :pb1+1
         stx   :pb2+1

         ldx   #OAM_START_INDEX*4
         ldy   #0                     ; This is the destination index

         phd
         lda   DP_OAM
         tcd

:loop
         DO     DIRECT_OAM_READ
         ldal   ROMBase+DIRECT_OAM_READ,x  ; Copy the low word
         ELSE
         lda    PPU_OAM,x
         FIN
         inc                               ; Increment the y-coordinate to match the PPU delay
         sta    OAM_COPY,y

         SCAN_OAM_XTRA_FILTER
         bcc    :skip

         and    #$00FF              ; Isolate the Y-coordinate
         DO     NO_VERTICAL_CLIP
         cmp    #max_nes_y
         bcs    :skip
         cmp    #y_offset-7
         bcc    :skip
         ELSE
         cmp    #{max_nes_y-8}+1    ; Skip anything that is beyond this line
         bcs    :skip
         cmp    #y_offset
         bcc    :skip
         FIN

         phx
         phy

; Need to add ScrollY to the sprite Y-coordinate here because the shadow bitmap is 1:1 with the nametable
; tile rows and we need to convert from screen coordinates to nametable rows.

         asl
         tay                      ; We are drawing this sprite, so mark it in the shadow list
         ldx    y2idx,y           ; Get the index into the shadowBitmap array for this y coordinate (y -> blk_y)
         lda    y2bits,y          ; Get the bit pattern for the first byte
:pb1     ora:   $0000,x
:pb2     sta:   $0000,x

         ply
         plx

         DO     DIRECT_OAM_READ
         ldal   ROMBase+DIRECT_OAM_READ+2,x    ; Copy the high word
         ELSE
         lda    PPU_OAM+2,x
         FIN
         sta    OAM_COPY+2,y

         iny
         iny
         iny
         iny

:skip
         inx
         inx
         inx
         inx
         cpx  #OAM_END_INDEX*4
         bcc  :loop

         pld

         sty   spriteCount           ; spriteCount * 4 for easy comparison later
         rts

; Handle 8x16 sprite mode. We cheat and pretend that there are 2 8x8 sprites.  Fix once we have to handle
; a game that has >32 8x16 sprites
scan8x16

; We're committed to 8x16 mode, so patch things

         stx   :pb1+1
         stx   :pb2+1
         stx   :pb3+1
         stx   :pb4+1

; Same code as above with extra handling for 8x16 mode

         ldx   #OAM_START_INDEX*4
         ldy   #0                     ; This is the destination index

         phd
         lda   DP_OAM
         tcd

:loop
         DO     DIRECT_OAM_READ
         ldal   ROMBase+DIRECT_OAM_READ,x      ; Copy the low word
         ELSE
         lda    PPU_OAM,x
         FIN
         inc                          ; Increment the y-coordinate to match the PPU delay
         sta    OAM_COPY,y

         SCAN_OAM_XTRA_FILTER
         bcc    :skip

         and    #$00FF                ; Isolate the Y-coordinate
         DO     NO_VERTICAL_CLIP
         cmp    #max_nes_y
         bcs    :skip
         cmp    #y_offset-7
         bcc    :skip
         ELSE
         cmp    #{max_nes_y-8}+1      ; Skip anything that is beyond this line
         bcs    :skip
         cmp    #y_offset
         bcc    :skip
         FIN

         phx
         phy

         asl
         tay                      ; We are drawing this sprite, so mark it in the shadow list
         ldx    y2idx,y           ; Get the index into the shadowBitmap array for this y coordinate (y -> blk_y)
         lda    y2bits,y          ; Get the bit pattern for the first byte
:pb1     ora:   $0000,x
:pb2     sta:   $0000,x

; Do some extra work for the bottom part of the sprite
         
         ldx    y2idx+16,y
         lda    y2bits+16,y
:pb3     ora:   $0000,x
:pb4     sta:   $0000,x

         ply
         plx

         DO     DIRECT_OAM_READ
         ldal   ROMBase+DIRECT_OAM_READ+2,x    ; Copy the high word
         ELSE
         lda    PPU_OAM+2,x
         FIN
         sta    OAM_COPY+2,y

         iny
         iny
         iny
         iny

:skip
         inx
         inx
         inx
         inx
         cpx  #OAM_END_INDEX*4
         bcc  :loop

         pld

         sty   spriteCount           ; spriteCount * 4 for easy comparison later
         rts

; Screen is 200 lines tall. It's worth it be exact when building the list because one extra
; draw + shadow sequence takes at least 1,000 cycles.

; A representation of the list as [top, bot) pairs
shadowListCount dw 0            ; Pad for 16-bit comparisons
shadowListTop   ds 64
shadowListBot   ds 64

; This maps a screen y-coordinate to a byte index
y2idx   wconst32 $00                ; $0000 $0000 $0000 $0000 $0001 $0001 $0001 $0001
        wconst32 $04
        wconst32 $08
        wconst32 $0C                ; 256 bytes
        wconst32 $10
        wconst32 $14
        wconst32 $18
        wconst32 $1C

; Repeating pattern of 8 consecutive 1 bits
y2bits  wrep8 $00FF,$807F,$C03F,$E01F,$F00F,$F807,$FC03,$FE01
        wrep8 $00FF,$807F,$C03F,$E01F,$F00F,$F807,$FC03,$FE01
        wrep8 $00FF,$807F,$C03F,$E01F,$F00F,$F807,$FC03,$FE01
        wrep8 $00FF,$807F,$C03F,$E01F,$F00F,$F807,$FC03,$FE01

; 25 entries to multiply steps in the shadow bitmap to scanlines
mul8    db   $00,$08,$10,$18,$20,$28,$30,$38
        db   $40,$48,$50,$58,$60,$68,$70,$78
        db   $80,$88,$90,$98,$A0,$A8,$B0,$B8
        db   $C0,$C8,$D0,$D8,$E0,$E8,$F0,$F8

; Given a bit pattern, create a LUT that count to the first set bit (MSB -> LSB), e.g. $0F = 4, $3F = 2
offset
        db   8,7,6,6,5,5,5,5,4,4,4,4,4,4,4,4,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db   2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
        db   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
invOffset
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db   2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
        db   3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,6,6,7,8

; Mask off all of the high 1 bits, keep all of the low bits after the first zero, e.g.
; offsetMask($E3) = offsetMask(11100011) = $1F.  %11100011 & $1F = $03
offsetMask
        db   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; 127 (everything here has a 0 in the high bit)

        db   $7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F  ; $80 - $8F
        db   $7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F  ; $90 - $9F
        db   $7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F  ; $A0 - $AF
        db   $7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F  ; $B0 - $BF

        db   $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F  ; $C0 - $CF
        db   $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F  ; $D0 - $DF

        db   $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F  ; $E0 - $EF
        db   $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$07,$07,$07,$07,$03,$03,$01,$00  ; $F0 - $FF

; Change all of the 1-bits from the MSB to the first one bit to zeros, i.e. 11011000 -> 00011000
flipLeadingOnes
        db   $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F
        db   $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F
        db   $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F
        db   $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F
        db   $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
        db   $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F
        db   $60,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6A,$6B,$6C,$6D,$6E,$6F
        db   $70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7A,$7B,$7C,$7D,$7E,$7F

        db   $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F  ; $80 - $8F
        db   $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F  ; $90 - $9F
        db   $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F  ; $A0 - $AF
        db   $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F  ; $B0 - $BF

        db   $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F  ; $C0 - $CF
        db   $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F  ; $D0 - $DF

        db   $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F  ; $E0 - $EF
        db   $00,$01,$02,$03,$04,$05,$06,$07,$00,$01,$02,$03,$00,$01,$00,$00  ; $F0 - $FF

; Change all of the 0-bits from the MSB to the first zero bit to ones, i.e. 00100111 -> 11100111
flipLeadingZeros
        db   $FF,$FF,$FE,$FF,$FC,$FD,$FE,$FF,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $00 - $0F
        db   $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $10 - $1F

        db   $E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF  ; $20 - $2F
        db   $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $30 - $3F

        db   $C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF  ; $40 - $4F
        db   $D0,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF  ; $50 - $5F
        db   $E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF  ; $60 - $6F
        db   $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $70 - $7F

        db   $80,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8A,$8B,$8C,$8D,$8E,$8F  ; $80 - $8F
        db   $90,$91,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$9B,$9C,$9D,$9E,$9F  ; $90 - $9F
        db   $A0,$A1,$A2,$A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AB,$AC,$AD,$AE,$AF  ; $A0 - $AF
        db   $B0,$B1,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$BB,$BC,$BD,$BE,$BF  ; $B0 - $BF
        db   $C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF  ; $C0 - $CF
        db   $D0,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF  ; $D0 - $DF
        db   $E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF  ; $E0 - $EF
        db   $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; $F0 - $FF



; Scan the bitmap list and call BltRange on the ranges
        mx   %00
drawShadowList
        ldx  #0
        cpx  shadowListCount
        beq  :exit

:loop
        phx

        lda  shadowListBot,x
        and  #$00FF
        tay

        lda  shadowListTop,x
        and  #$00FF
        tax

        jsr  _BltRangeLite

        plx
        inx
        cpx  shadowListCount
        bcc  :loop
:exit
        rts

; Altername between BltRange and PEISlam to expose the screen
;
; Bug in BF after running for a long period of time -- hits BRK $66
exposeShadowList
:last   equ  tmp3
:top    equ  tmp4
:bottom equ  tmp5

        ldx  #0
        stx  :last
        cpx  shadowListCount
        beq  :exit
:loop
        phx

        lda  shadowListTop,x
        and  #$00FF
        sta  :top

        cmp  #200
        bcc  *+4
        brk  $44

        lda  shadowListBot,x
        and  #$00FF
        sta  :bottom

        cmp  #201
        bcc  *+4
        brk   $66

        cmp  :top
        bcs  *+4
        brk  $55

        ldx  :last
        ldy  :top
        jsr  _BltRangeLite      ; Draw the background up to this range

        ldx  :top
        ldy  :bottom
        sty  :last              ; This is where we ended
        jsr  _PEISlam           ; Expose the already-drawn sprites

        plx
        inx
        cpx  shadowListCount
        bcc  :loop

:exit
        ldx  :last              ; Expose the final part
        ldy  #y_height
        jmp  _BltRangeLite

* ; This routine needs to adjust the y-coordinates based of the offset of the GTE playfield within
* ; the PPU RAM
shadowBitmapToList
:top      equ  tmp0
:bottom   equ  tmp2
:bitfield equ  tmp4

        sep  #$30

        ldy  #y_offset_rows               ; Start at the top of the physical screen and walk the bitmap for 25 bytes (200 lines of height)
        lda  #0
        sta  shadowListCount              ; zero out the shadow list count

; This loop is called when we are not tracking a sprite range
:zero_loop
        lda  (CurrShadowBitmap),y
:zero_chk
        beq  :zero_next
        tax

        lda  {mul8-y_offset_rows},y       ; This is the scanline we're on (offset by the starting byte)
        clc
        adc  offset,x                     ; This is the first line defined by the bit pattern
        sta  :top
        bra  :one_next

:zero_next
        iny
        cpy  #y_height_rows+y_offset_rows ; +1              ; End at byte 27
        bcc  :zero_loop
        bra  :exit           ; ended while not tracking a sprite, so exit the function

:one_loop
        lda  (CurrShadowBitmap),y     ; if the next byte is all sprite, just continue
        cmp  #$FF
        beq  :one_next

* ; The byte has to look like 1..10..0  The first step is to mask off the high bits and store the result
* ; back into the shadowBitmap

        tax
        and  offsetMask,x
        sta  :bitfield

        lda  {mul8-y_offset_rows},y
        clc
        adc  invOffset,x

        ldx  shadowListCount
        sta  shadowListBot,x
        lda  :top
        sta  shadowListTop,x
        inx
        stx  shadowListCount

; Loop back to check if there is more sprite data on this byte

        lda  :bitfield
        bra  :zero_chk

:one_next
        iny
        cpy  #y_height_rows+y_offset_rows
        bcc  :one_loop

; If we end while tracking a sprite, add to the list as the last item

        ldy  shadowListCount
        lda  :top
        sta  shadowListTop,y
        lda  #y_height
        sta  shadowListBot,y
        iny
        sty  shadowListCount

:exit
        rep  #$30
        lda  shadowListCount
        cmp  #64
        bcc  *+4
        brk  $13

        rts

; Variation on shadowBitmapToList that uses a temporary variable for the current byte and does not modify
; the bitmap list itself
;
; X = bitmap address
; Y = starting byte
; A = ending byte (exclusive)
;
; Scan bytes 2 through 10 at address $1234
; X = $1234
; Y = 2
; A = 11


; Direct-page aliases used by the WALK_BITMAP macro in scanline_bitmap.s and by _drawBackground/_exposeScreen
walk_top     equ tmp3
walk_bottom  equ tmp4
walk_curr    equ tmp5
walk_prev    equ tmp6

; Setup all of the sprites from the NES OAM memory.  If possible, we read the OAM information directly
; from a game-specific area of NES RAM, rather than supporting the OAMDMA operation, to avoid extra
; copying.
;        mx  %11
;drawOAMSprites

; Step 1: Scan the OAM sprite information.  Since we're reading NES RAM, we disable interrupts so that
;         a VBL cannot fire while we sync the data.

; This step was done at the start of RenderFrame

; Step 2: Convert the bitmap to a list of (top, bottom) pairs in order to update the screen

;        jmp   shadowBitmapToList

; Dirty rendering.  Only draw differences

; Set up specialized methods to walk the bitmaps (called in 8-bit mode), guaranteed to have
; the carry clear when called, must return with the carry clear as well.
        mx   %11
_drawBackground
        phx
        phy
        php
        rep  #$30
        ldx  walk_top
        ldy  walk_bottom
        jsr  _BltRangeLite           ; BltRangeLite uses tmp0, tmp1, tmp2
        plp
        ply
        plx
        rts

        mx   %11
_exposeScreen
        phx
        phy
        php
        rep  #$30
        ldx  walk_top
        tay
        ldy  walk_bottom
        jsr  _PEISlam               ; PEISlam uses tmp0
        plp
        ply
        plx
        rts

        mx   %00
clearPreviousSprites
        WALK_BITMAP LOAD_INTERSECTION;y_offset_rows;y_ending_row;_drawBackground

exposeCurrentSprites
        WALK_BITMAP LOAD_CURRENT;y_offset_rows;y_ending_row;_exposeScreen

drawOtherLines
        WALK_BITMAP LOAD_OTHERS;y_offset_rows;y_ending_row;_drawBackground

; Handles horizontal mirroring where the top of the screen could start at any scanline.  The PPU
; emulation is based on nametable addresses, the any bitmap that marks dirty scanlines is independent
; of the YSCROLL values.  Sprites are also independent of YSCROLL values and are placed directly in
; screen-space coordinates.
;
; The trick here is to be able to generate, on the fly, a union of sprite bitmap values and tile row values. The
; extra wrinkle is that the index register is also working in screen-space, so it can directly lookup the
; sprite bitmap, but we need to adjust the tileBitmap on a per-bit basis.
LOAD_HORZ_MIRROR mac
        lda  (TileBitmap),y          ; Set TileBitmap pointer to the closest 
        lda  (CurrShadowBitmap),y    ; y = screen_y / 8

        <<<

; alignedTileBuffer = btmap fill based on YSCROLL
;
;       ldx  tile_row     ; logical row (0 - 30 for V_MIRROR, 0 - 60 for H_MIRROR)
;       ldy  y_scroll_mod_8
;       lda  y2bits,y    ; 16-bit mask value based on YSCOLL mod 8. If YSCROLL = 0, mask = $00FF.  YSCROLL = 7, mask = $FE01
;       ora  tileBitmap,x
;       sta  tileBitmap,x
;
; When blitting, set a pointer to the 
; Update the minimal amount of the screen just based on what has changed from the prior
; frame.  We track three bitmaps of information that identify which lines different
; components are on.
;
; shadowBitmap0 and shadowBitmap1 track the lines that hold sprites from the previous
; and current frame. tileBitmap marks lines that had a tile updated since the last frame.
;
; There are actually two phases to the dirty rendering.  The first is when the prior
; frame was rendered normally and the second in when the prior frame used the dirty
; renderer.
;
; When performing dirty rendering for the first time, the sprites from the last frame have
; to be erased by drawing the background on the lines previously occupied, then the new sprites
; drawn and the updated lines exposed
;
; When rendering a dirty frame, the expectation is that the next frame will use the dirty
; renderer as well, so the pipeline changes to improve efficieny.  The screen data beneath
; a sprite is saved before drawing and, on the next frame used to restore the graphic
; screen rather than re-rendering the full background.
;
; New sprites are drawn and the 8x8 patches of the previous sprites are used to update only
; the active portions of the screen.  Sprites are drawn in a top-down order, if possible
; to avoid bubbling. Exposing the erased sprites *after* drawing the current sprites will
; avoid flicker.
;
; When the drawing transitions back to a normal rendering frame, nothing special needs to
; be done as the normal blit will erase all of the previous sprites.



sprTmp0      equ pputmp
sprTmp1      equ pputmp+2
sprTmp2      equ pputmp+4
sprTmp3      equ pputmp+6
sprTmp4      equ pputmp+8
sprAddrMin   equ unused50
sprAddrMax   equ unused52

        mx   %00
drawSprites

:spriteCount equ pputmp+10
:mul160      equ pputmp+12

; Run through the copy of the OAM memory and render each sprite to the graphics screen.  Typically,
; shadowing is disabled during this routine.

; Put some variables on the direct page so we don't have to change the bank in each iteration

        lda   spriteCount
        sta   :spriteCount
        lda   #Mul160Tbl
        sta   :mul160
        lda   #^Mul160Tbl
        sta   :mul160+2

        ldx   #0
        cpx   :spriteCount
        bne   *+3
        rts

; Set up the data bank to point to the tile data

        phb                          ; Save the current data bank
        pea   #^tiledata             ; Put the tile data bank on the stack

; Determine if we are in 8x8 sprite mode, or 8x16 sprite mode.  Have a specialized loop for
; each.

        lda   _ppuctrl
        bit   #NES_PPUCTRL_SPRSIZE
        bne   :is_8x16

        plb

:oam_loop_8x8
        phx                           ; Save x

; Regardless of whether the PPUCTRL is in 8x8 or 8x16 mode, the 
; starting SHR address and palette selection is the same

        jsr   :setupSprite8

; Copy bytes 1 and 2 into temp space

        ldal  OAM_COPY+1,x
        sta   sprTmp2

; Draw the tile

        jsr   :drawSprite8x8

; Restore and continue processing the OAMtable

        plx
        inx
        inx
        inx
        inx
        cpx   :spriteCount
        bcc   :oam_loop_8x8

        plb
        plb
        rts

:is_8x16
        plb

:oam_loop_8x16
        phx                    ; Save x

; Setup the sprite

        jsr   :setupSprite16

; Copy bytes 1 and 2 into temp space
;  (only support the first nametable at the moment)

        ldal  OAM_COPY+1,x
        and   #$FFFE           ; mask low bit
        sta   sprTmp2

; Draw the top tile

        jsr   :drawSprite8x8

        lda   sprTmp1          ; Advance the address on screen
        clc
        adc   #8*160
        sta   sprTmp1

        lda   sprTmp2          ; Advance to the next tile index
        inc
        sta   sprTmp2          ; Value needs to be in accumulator and sprTmp2 for drawSprite8x8

; Draw the bottom tile

        jsr   :drawSprite8x8

        plx
        inx
        inx
        inx
        inx
        cpx   :spriteCount
        bcc   :oam_loop_8x16

        plb
        plb
        rts

:setupSprite8
        lda   #$2000+x_offset
        sta   sprAddrMin
        lda   #$2000+{{200-8}*160}+x_offset
        sta   sprAddrMax

        jsr   :setupSprite

        ; If we are in DirtyState 1 or 2, then the sprite data should be copied
        lda  DirtyState
        beq  :not_dirty8
        phx
        ldx  sprTmp1
        ldy  sprTmp3                   ; Save the clamped screen address in sprTmp3
        jsr  saveTileFromScreen8
        plx
:not_dirty8
        rts

:setupSprite16
        lda   #$2000+x_offset
        sta   sprAddrMin
        lda   #$2000+{{200-16}*160}+x_offset
        sta   sprAddrMax

        jsr   :setupSprite

        ; If we are in DirtyState 1 or 2, then the sprite data should be copied
        lda  DirtyState
        beq  :not_dirty16
        phx
        ldx  sprTmp1
        ldy  sprTmp3                   ; Save the clamped screen address in sprTmp3
        jsr  saveTileFromScreen16
        plx
:not_dirty16
        rts

; X = OAM index
:setupSprite
        ldal  OAM_COPY,x               ; Y-coordinate
        and   #$00FF
        asl
        tay
        lda  [:mul160],y
        adc  #$2000-{y_offset*160}+x_offset
        sta  sprTmp1

;        cmp  sprAddrMin
;        bcs  :chk_max
;        lda  sprAddrMin
;:chk_max
;        cmp  sprAddrMax
;        bcc  :chk_done
;        lda  sprAddrMax
;:chk_done
        sta   sprTmp3

; Do some stuff that is faster in 8-bit mode

        sep  #$20

; Set the palette pointer for this sprite

        ldal OAM_COPY+2,x              ; Put attribute byte in the high byte
        and  #$03
        asl
        adc  SwizzlePtr2+1             ; Carry is clear from the asl
        sta  ActivePtr+1               ; Select the second set of palettes

; Convert the x-coordinate.

        ldal _ppuscroll_x
        and  #$01
        adcl OAM_COPY+3,x             ; X-coordinate (In NES pixels, need to convert to IIgs bytes)
        and  #$FE                     ; Mask before the shift so that we know a 0 goes into the carry
        ror                           ; Rotate to bring the carry into the high bit in case of overflow
        rep  #$20
        and  #$00FF
        tay
        adc  sprTmp1                  ; Add to the base address calculated fom the Y-coordinate
        sta  sprTmp1                  ; This is the SHR address at which to draw the sprite

        stz  sprTmp4                  ; Assume no clipping
        tya
        cmp  #125
        bcc  :no_x_clamp

        sbc  #124                   ; get the difference
        sta  sprTmp4

        lda  #124
        clc

:no_x_clamp
        adc  sprTmp3
        sta  sprTmp3
        rts

; Calculate the on-screen address for the sprite
;
; Input:
;  X = OAM index (0, 4, 8, ..., 248, 252)
;
; Output:
;  sprTmp1 = SHR address
;  sprTmp3 = clamped SHR address
;  sprTmp4 = clipping amount (0 = no clipping)
;
; Modified:
;  sprTmp0 used for temporary data
;  ActivePtr set to sprite palette

; Draw a single 8x8 sprite
;
; X = OAM index (0, 4, 8, ..., 248, 252)
; A = OAM[1] and OAM[2], also in sprTmp2
:drawSprite8x8

; This is the point to check if there is a compiled version of this sprite

        ldx  sprTmp4        ; Test if this sprite needs clipping (first test)
        bne  as_bitmap_clip

        bit  #$2000         ; Is the priority bit set?
        bne  as_bitmap

        and  #$00FF
        asl
        tax
        ldal spr_comp_tbl,x
        DO   SHOW_DEBUG_VARS
        ldx  #$2222         ; color for missing compiled sprite
        cmp  #0             ; re-establish the equality test
        FIN
        beq  as_bitmap      ; zero value means no compiled sprite for this tile IDs

; Vector through the compiled sprite table.  The compiled sprites are in a different bank, so just check
; for a sentinel value and manually jump into the compiled sprite code to avoid a double-jump and having to
; have a second jump table in the compile sprite code bank.

        stal csd+1                     ; patch in the long address directly
        lda  sprTmp2+1                 ; load OAM[2] into accumulator
        pei  CMPL_BANK
        plb
csd     jml  $000000
draw_rtn2
        plb                           ; Return from compiled sprite
        DO   SHOW_DEBUG_VARS
        lda  #$7777
        stal outlineColor
        ldx  sprTmp1
        jmp  drawOutline
        FIN
        rts

; Finish calculating the jump address. We dispatch differently based on the horizontal flip, vertical
; flip and priority bits. when calling the rendering function, Y = screen address, X = tile data address

as_bitmap
        DO   SHOW_DEBUG_VARS
        lda  #$FFFF         ; color for priority bit
        stal outlineColor
        FIN
        lda  sprTmp2+1
        and  #$00E0
        lsr
        lsr
        lsr
        lsr
        tax

; Calculate the address of the tile data

        lda  sprTmp2-1
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data -- this clears the carry flag
        DO   SHOW_DEBUG_VARS
        jsr  (drawProcs,x)            ; Executes an RTS to return directly to caller
        ldx  sprTmp1
        jmp  drawOutline
        ELSE
        jmp  (drawProcs,x)            ; Executes an RTS to return directly to caller
        FIN

as_bitmap_clip
        lda  sprTmp2+1
        and  #$00E0
        lsr
        lsr
        lsr
        lsr
        tax
        lda  sprTmp2-1
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data -- this clears the carry flag
        jmp  (drawProcsClipped,x)

drawProcs
        dw drawTileToScreen,drawTileToScreenP,drawTileToScreenH,drawTileToScreenPH
        dw drawTileToScreenV,drawTileToScreenPV,drawTileToScreenHV,drawTileToScreenPHV

drawProcsClipped
        dw drawClippedTileToScreen,drawClippedTileToScreenP,drawClippedTileToScreenH,drawClippedTileToScreenPH
        dw drawClippedTileToScreenV,drawClippedTileToScreenPV,drawClippedTileToScreenHV,drawClippedTileToScreenPHV

; Array of dispatch addresses.  There is a special address of $0000 in the table that immediately returns
; from the compiled sprite code bank for sprites that do not have a compiled representation.
spr_comp_tbl ds 512,$00

_blitTileNoMask
; A = tile address
; Y = screen address
; X = palette select 0,2,4,6
;
; Raw data draw -- expands the tile data from w_wxxy_yzz0 to 00ww_00xx_00yy_00zz and then adds an offset based on the
; palette select

        sta   sprTmp0
        sty   sprTmp1

        txa
        and   #$0006
        asl
        sta   sprTmp3
        asl
        asl
        asl
        asl
        ora   sprTmp3
        sta   sprTmp3
        xba
        ora   sprTmp3
        sta   sprTmp3

        ldy   sprTmp0
        ldx   sprTmp1
        lda   #8
        sta   sprTmp4

]line   equ   0
:loop
        lda:  {]line*4},y                            ; Load the tile data lookup value
        lsr
        and   #$0003
        sta   sprTmp2
        lda:  {]line*4},y
        asl
        and   #$0030
        tsb   sprTmp2
        lda:  {]line*4},y
        asl
        asl
        asl
        and   #$0300
        tsb   sprTmp2
        lda:  {]line*4},y
        asl
        asl
        asl
        asl
        asl
        and   #$3000
        ora   sprTmp2
        xba
        ora   sprTmp3
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        lda:  {]line*4}+2,y
        lsr
        and   #$0003
        sta   sprTmp2
        lda:  {]line*4}+2,y
        asl
        and   #$0030
        tsb   sprTmp2
        lda:  {]line*4}+2,y
        asl
        asl
        asl
        and   #$0300
        tsb   sprTmp2
        lda:  {]line*4}+2,y
        asl
        asl
        asl
        asl
        asl
        and   #$3000
        ora   sprTmp2
        xba
        ora   sprTmp3
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

        iny
        iny
        iny
        iny

        txa
        clc
        adc   #160
        tax

        dec   sprTmp4
        beq   :done
        brl   :loop
:done
        rts

; Blits from the top-half of the tiledata bank.  Assumes no mask. This routine is used if the dirty
; renderer to selectively update the screen when a small number of backgrond tiles have changed.
;
; X = tile address
; Y = screen address
;
; Bank must be set to the tiledata bank
_blitBGTile

; Load data from the tiledata,x and store in a direct page buffer. The
; Y register is over-written.

        phy
        jsr   _copyTileToBuffer

; Copy data from the direct page buffer into the SHR screen memory

        plx
        jmp   _copyBufferToScreenNoMask

; Define the opcodes directly so we can use then in a macro.  The bracket from long-indirect addressing, e.g. [],
; causes the macro processor to get confused since variables can be written as "]x"
LDA_IND_LONG_IDX equ $B7
ORA_IND_LONG_IDX equ $17
AND_IND_LONG_IDX equ $37

drawClippedTileToScreenHV
        adc   #64

drawClippedTileToScreenV
        tax
        jsr   _copyTileToBufferV
        bra   _clippedCommon

drawClippedTileToScreenH
        adc   #64

drawClippedTileToScreen
        tax
        jsr   _copyTileToBuffer

_clippedCommon
        jsr   clipBuffer
:no_clip
        txy
        ldx   sprTmp1
        jmp   _copyBufferToScreen

; Drawing to the screen can happen two ways.
;
; If the sprite is being drawn this way, then the compiled version cannot be used for some reason.  To flexibly
; handle corner cases, the sprite data and mask are copied into temporary direct page space and then copied
; to the screen.  This helps maximize the use of registers and allows the data or mask to be altered before
; drawing, if needed.
copyTileToBufferHV
        adc   #64

copyTileToBufferV
        tax                                          ; Put the sprite data address in the register

_copyTileToBufferV
]line   equ   0
        lup   8

        ldy:  {7-]line*4},x                          ; Load the tile data lookup value
        db    LDA_IND_LONG_IDX,ActivePtr             ; Lookup the data from the swizzle table
        sta   blttmp+{]line*4}                       ; Save on the direct page

        ldy:  {7-]line*4}+2,x
        db    LDA_IND_LONG_IDX,ActivePtr
        sta   blttmp+{]line*4}+2

]line   equ   ]line+1
        --^
        rts

copyTileToBufferH
        adc   #64

copyTileToBuffer
        tax                                          ; Put the sprite data address in the register

_copyTileToBuffer
]line   equ   0
        lup   8

        ldy:  {]line*4},x                            ; Load the tile data lookup value
        db    LDA_IND_LONG_IDX,ActivePtr             ; Lookup the data from the swizzle table
        sta   blttmp+{]line*4}                       ; Save on the direct page

        ldy:  {]line*4}+2,x
        db    LDA_IND_LONG_IDX,ActivePtr
        sta   blttmp+{]line*4}+2

]line   equ   ]line+1
        --^
        rts

; Blit from the direct page buffer to the screen using the tile mask in the data bank
;
; A = tile address
; X = screen address
copyBufferToScreenH
        adc   #64

copyBufferToScreen
        tay

_copyBufferToScreen
]line   equ   0
        lup   8

        ldal  $010000+{]line*SHR_LINE_WIDTH},x       ; Load the screen data
        and:  {]line*4}+32,y                         ; mask
        ora   blttmp+{]line*4}
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; Load the screen data
        and:  {]line*4}+32+2,y                       ; mask
        ora   blttmp+{]line*4}+2
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line   equ   ]line+1
        --^
        rts

_copyBufferToScreenNoMask
]line   equ   0
        lup   8

        lda   blttmp+{]line*4}
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        lda   blttmp+{]line*4}+2
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line   equ   ]line+1
        --^
        rts

; If the tile needs to be clipped, then set the pixels in the direct page buffer to zero.  This is not exact clipping, but
; creates the illusion of the sprite being clipped.  The only time this actually matters is when dirty rendering is engaged
; and a sprite is placed with x in [125, 126, 127].
clipBuffer
        lda   sprTmp4
        bne   *+3
        rts
        dec
        beq   clipBuffer125
        dec
        beq   clipBuffer126
        bra   clipBuffer127

clipBuffer127
        sep   #$20
]line   equ   0
        lup   8
        stz   blttmp+{]line*4}+1
]line   equ   ]line+1
        --^
        rep   #$20

clipBuffer126
]line   equ   0
        lup   8
        stz   blttmp+{]line*4}+2
]line   equ   ]line+1
        --^
        rts

clipBuffer125
        sep   #$20
]line   equ   0
        lup   8
        stz   blttmp+{]line*4}+3
]line   equ   ]line+1
        --^
        rep   #$20
        rts

drawTileToScreenH

;          lda   sprTmp0
;          clc              ; There are a series of zero shifts before calling into this routine
          adc   #64
;          sta   sprTmp0

drawTileToScreen

          sta   sprTmp0

]line     equ   0
          lup   8

          ldx   sprTmp0
          ldy:  {]line*4},x                            ; Load the tile data lookup value
          lda:  {]line*4}+32,x                         ; Load the mask value
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH},x       ; Mask against the screen
          db    ORA_IND_LONG_IDX,ActivePtr             ; Merge in the remapped tile data
          stal  $010000+{]line*SHR_LINE_WIDTH},x

          ldx   sprTmp0
          ldy:  {]line*4}+2,x
          lda:  {]line*4}+32+2,x
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH}+2,x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line     equ   ]line+1
          --^

;          jmp   draw_rtn
          rts

drawTileToScreenHV

;          lda   sprTmp0
;          clc
          adc   #64
;          sta   sprTmp0

drawTileToScreenV

          sta   sprTmp0

]line     equ   0
          lup   8

          ldx   sprTmp0
          ldy:  {{7-]line}*4},x
          lda:  {{7-]line}*4}+32,x
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH},x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH},x

          ldx   sprTmp0
          ldy:  {{7-]line}*4}+2,x
          lda:  {{7-]line}*4}+32+2,x
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH}+2,x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line     equ   ]line+1
          --^

          rts

drawClippedTileToScreenPHV
drawClippedTileToScreenPH

        adc   #64

drawClippedTileToScreenPV
drawClippedTileToScreenP

        tay
        ldx   sprTmp1

        jsr   _copyMaskToBufferP      ; Build a screen mask in the direct page
        jsr   clipBuffer
;        jmp   _copyBufferToScreenP

_copyBufferToScreenP
        ldx   sprTmp0
]line   equ   0
        lup   8
        ldy:  {]line*4}+0,x

        lda   blttmp+{]line*4}
        beq   zl

        ldx   sprTmp1
        db    AND_IND_LONG_IDX,ActivePtr
        oral  $010000+{]line*SHR_LINE_WIDTH}+0,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+0,x

        ldx   sprTmp0
zl      ldy:  {]line*4}+2,x

        lda   blttmp+{]line*4}+2
        beq   zr
        ldx   sprTmp1
        db    AND_IND_LONG_IDX,ActivePtr
        oral  $010000+{]line*SHR_LINE_WIDTH}+2,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

        ldx   sprTmp0
zr
]line   equ   ]line+1
        --^
        rts

_copyMaskToBufferP
]line   equ   0
        lup   8
        ldal  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; create mask where 0 = !0 and 0 = F.
        beq   zero_left
        bit   #$F000
        beq   *+5
        ora   #$F000     ; 3+3 / 3+2+3 = 6 / 8 = ~7 cycles per pixel average
        bit   #$0F00
        beq   *+5
        ora   #$0F00
        bit   #$00F0
        beq   *+5
        ora   #$00F0
        bit   #$000F
        beq   *+5
        ora   #$000F
zero_left
        sta   blttmp+{]line*4}

        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; create mask where 0 = !0 and 0 = F.
        beq   zero_right
        bit   #$F000
        beq   *+5
        ora   #$F000     ; 3+3 / 3+2+3 = 6 / 8 = ~7 cycles per pixel average
        bit   #$0F00
        beq   *+5
        ora   #$0F00
        bit   #$00F0
        beq   *+5
        ora   #$00F0
        bit   #$000F
        beq   *+5
        ora   #$000F
zero_right
        sta   blttmp+{]line*4}+2

]line   equ   ]line+1
        --^
        rts

drawTileToScreenPHV
drawTileToScreenPH

        adc   #64

drawTileToScreenPV
drawTileToScreenP

          sta   sprTmp0

]line     equ   0
          lup   8

          ldx   sprTmp0
          ldy:  {]line*4}+0,x                          ; load the lookup value

          ldx   sprTmp1                                ; Get the screen address
          ldal  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; create mask where 0 = !0 and 0 = F.
          beq   zero_left
          bit   #$F000
          beq   *+5
          ora   #$F000     ; 3+3 / 3+2+3 = 6 / 8 = ~7 cycles per pixel average
          bit   #$0F00
          beq   *+5
          ora   #$0F00
          bit   #$00F0
          beq   *+5
          ora   #$00F0
          bit   #$000F
          beq   *+5
          ora   #$000F
zero_left
          eor   #$FFFF
          beq   skip_left                              ; zero means no sprite data will show through

          db    AND_IND_LONG_IDX,ActivePtr             ; Apply against the sprite data
          oral  $010000+{]line*SHR_LINE_WIDTH}+0,x
          stal  $010000+{]line*SHR_LINE_WIDTH}+0,x
skip_left

          ldx   sprTmp0
          ldy:  {]line*4}+2,x                          ; load the lookup value

          ldx   sprTmp1                                ; Get the screen address
          ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; create mask where F = !0 and 0 = 0.
          beq   zero_right
          bit   #$F000
          beq   *+5
          ora   #$F000
          bit   #$0F00
          beq   *+5
          ora   #$0F00
          bit   #$00F0
          beq   *+5
          ora   #$00F0
          bit   #$000F
          beq   *+5
          ora   #$000F
zero_right
          eor   #$FFFF
          beq   skip_right

          db    AND_IND_LONG_IDX,ActivePtr
          oral  $010000+{]line*SHR_LINE_WIDTH}+2,x
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x
skip_right

]line     equ   ]line+1
          --^

;          jmp   draw_rtn
          rts

incborder
        php
        sep  #$20
        ldal $E0C034
        inc
        eorl $E0C034
        and  #$0F
        eorl $E0C034
        stal $E0C034
        plp
        rts

; Copies the screen data into a buffer to be restored later.  The save buffer is just a chunk of Bank 0 memory
; that is 4kb + 256b.  The extra space is because the address of the 8x8 block is pushed last and an interrupt
; may happen during this process, so we need to keep some extra stack space available.
;
; In the worst case, we may have to save 64 8x16 sprites, which corresponds to 64 * 4 * 16 = 4096 bytes, plus
; 4 bytes per sprite for the screen and shadow addresses, which adds up to 256 additional bytes
;
; Input: X register is the SHR address
; Input: Y register is the Clamped SHR address
          mx  %00

saveTileFromScreen16

          jsr   saveTileFromScreen8
          txa
          clc
          adc   #8*160
          tax
          tya
          clc
          adc   #8*160
          tay

saveTileFromScreen8

          tsc
          sta   sprTmp0                                ; Save the current stack in the y-register

          lda   SprSaveAddr
          tcs                                          ; Set the stack to the save buffer area
          clc

]line     equ   0
          lup   8

          ldal  $010000+{]line*SHR_LINE_WIDTH},x       ; Load the screen data
          pha                                          ; Save onto the stack
          ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
          pha

]line     equ   ]line+1
          --^

          phy                                          ; Save the SHR screen address for shadowing
          phx                                          ; Save the SHR screen address of the 8x8 block
          tsc
          sta   SprSaveAddr

          lda   sprTmp0                                ; Restore the original stack
          tcs

          rts

sprBlockAddr ds 64*2           ; Maximum of 64 8x8 blocks, each with a 16-bit address 

; Expose the 8x8 blocks from the list populated by saveTileFromScreen.
        mx  %00
exposeTilesToScreen

        ldy   SprAddrCount     ; Number of sprite block addresses (x2)
        bne   :ok
        rts

:ok
        dey                    ; Can be done in any order
        dey

:loop
        ldx   sprBlockAddr,y   ; Load the screen address
]line   equ   7
        lup   8

        ldal  $010000+{]line*SHR_LINE_WIDTH},x
        stal  $010000+{]line*SHR_LINE_WIDTH},x
        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line   equ   ]line-1
        --^

        dey
        dey
        bmi   :out
        brl   :loop            ; Are there more blocks to expose?
:out
        stz   SprAddrCount
        rts

; Restores all of the saved tiles to the screen using the data from the stack.  The stack
; format is a set of nine 16-bit values.
;
;   <base_address> <tile_data x 8>
;
; The data is pushed onto the stack in top-down, left-right order so it needs to be restored
; in bottom-up, right-left order.  There can be at most 128 8x8 pixel tiles saved, so the
; stack depth is at most 128 * 9 * 2 = 2304 bytes (11 bits).

restoreTilesToScreen

        ldy   #0

        lda   SprSaveAddr                            ; If the stack is empty, do nothing
        cmp   SprSaveTop
        beq   :done

        tsx
        stx   tmp0
        tcs

:loop
        plx                                          ; Pop the SHR screen address
        pla                                          ; Pop the SHR shadow address
        sta   sprBlockAddr,y                         ; Save it for later use

]line   equ   7
        lup   8

        pla                                          ; Load the screen data (5 cycles)
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; And write back to the screen (reverse order)
        pla
        stal  $010000+{]line*SHR_LINE_WIDTH},x

]line   equ   ]line-1
        --^

        iny
        iny

:test
        tsc
        cmp   SprSaveTop
        bcc   :loop

        sta   SprSaveAddr                            ; Update the save stack pointer to indicate an empty buffer

        lda   tmp0                                   ; Restore the original stack pointer
        tcs

:done
        sty   SprAddrCount
        rts

outlineColor ds 2
drawOutline
        ldal  outlineColor
        stal  $010000+{0*SHR_LINE_WIDTH},x
        stal  $010000+{0*SHR_LINE_WIDTH}+2,x
        stal  $010000+{7*SHR_LINE_WIDTH},x
        stal  $010000+{7*SHR_LINE_WIDTH}+2,x

]line   equ   1
        lup   6
        ldal  $010000+{]line*SHR_LINE_WIDTH},x
        eorl  outlineColor
        and   #$00F0
        eorl  $010000+{]line*SHR_LINE_WIDTH},x
        stal  $010000+{]line*SHR_LINE_WIDTH},x

        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
        eorl  outlineColor
        and   #$0F00
        eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x
]line   equ   ]line+1
        --^
        rts

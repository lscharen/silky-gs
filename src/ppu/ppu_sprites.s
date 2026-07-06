; ppu_sprites.s
;
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
        mx    %00
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
;
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

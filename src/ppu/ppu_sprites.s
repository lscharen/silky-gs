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

              DO GRID_DIRTY_RENDERING
              ds \,$00             ; Page-aligned: the grid renderer reads it with 8-bit index registers
              FIN
OAM_COPY      ds 256
spriteCount   dw 0
shadowBitmap0 ds 32                ; Bitmap to use when frameCount & 1 == 0
shadowBitmap1 ds 32                ; Bitmap to use when frameCount & 1 == 1

; scanOAMSprites reads the OAM straight from NES RAM at DIRECT_OAM_READ in the ROMBase bank.
; ROMBase is at offset $0000 of its bank in every game, so with DBR set to that bank the plain
; address DIRECT_OAM_READ is the same as ROMBase+DIRECT_OAM_READ (and avoids an
; external-plus-offset relocation).

oam_stack dw    0                   ; stack pointer before pass 1 pushes the sprites that pass

         mx   %00
scanOAMSprites

; With the grid renderer, the sprite lines bitmap is only needed by a full render (and some custom
; renderers), so it is built from OAM_COPY when first asked for (ensureShadowBitmap) instead of here.

         DO    GRID_DIRTY_RENDERING
         stz   shadowBitmapValid
         ELSE
         ldx   CurrShadowBitmap

; Erase the bitmap array for the current frame

]n       equ   0
         lup   15
         stz:  ]n,x
]n       =     ]n+2
         --^
         FIN

; Check if sprites are disabled

         lda   ControlBits
         and   #CTRL_SPRITE_ENABLE
         bne   *+6
         stz   spriteCount
         rts

; Point the shadow bitmap updates at the current bitmap

         DO    GRID_DIRTY_RENDERING
         ELSE
         stx   oam_pb1+1
         stx   oam_pb2+1
         stx   oam_pb3+1
         stx   oam_pb4+1
         stx   oam_pb5+1
         stx   oam_pb6+1
         FIN

         phb
         tsc
         sta   oam_stack

; Pass 1: filter the OAM entries through the game's y_exclude and tile_exclude tables and push the
; index of each sprite that passes.  The tables live in the ROMBase bank, so with 8-bit registers
; and DBR set there, each test is a single ldx abs,y.  y_exclude also covers the vertical range
; checks (see InitYExclude).
;
; A holds the OAM index throughout (X is reloaded from it), and the carry stays clear because the
; index never passes 255.

         sep   #$30
         mx    %11
         lda   #^ROMBase
         pha
         plb

         clc
         ldx   #OAM_START_INDEX*4   ; This is in the range [0, 252]

; When the range is a multiple of 4 entries, the filter is unrolled 4 times: each entry is tested at a
; fixed offset from X, and only an entry that passes works out its index (X + offset; the carry stays
; clear).  A rejected entry costs 11 cycles instead of 20.

OAM_FILTER_REM equ {OAM_END_INDEX-OAM_START_INDEX}-{{{OAM_END_INDEX-OAM_START_INDEX}/4}*4}
OAM_UNROLL     equ {4-OAM_FILTER_REM}/4          ; 1 = unrolled, 0 = loop
OAM_END_CMP    equ 1-{OAM_END_INDEX/64}          ; 1 = compare the index with the end (OAM_END_INDEX*4 =
                                                 ; 256 doesn't fit an 8-bit compare: the carry is set
                                                 ; once the index wraps past 252)
TILE_FILTER    equ 1-NO_TILE_EXCLUDE

; (No nested conditionals: Merlin32 mishandles a DO / ELSE inside a DO that is off.)

         DO    OAM_FILTER_REM
         txa                        ; Keep X = A
oam_filter
         ldy:  DIRECT_OAM_READ,x    ; Y coordinate
         ldx   y_exclude,y
         bne   oam_next
         FIN
         DO    OAM_FILTER_REM*TILE_FILTER
         tax                        ; Restore the X-register
         ldy:  DIRECT_OAM_READ+1,x  ; tile
         ldx   tile_exclude,y
         bne   oam_next
         FIN
         DO    OAM_FILTER_REM
         pha                        ; Since A = X, we can just save it directly and fall through
oam_next
         adc   #4
         tax
         FIN
         DO    OAM_FILTER_REM*OAM_END_CMP
         cmp   #OAM_END_INDEX*4
         FIN
         DO    OAM_FILTER_REM
         bcc   oam_filter
         FIN

oam_filter4
]k       =     0
         DO    OAM_UNROLL*NO_TILE_EXCLUDE
         lup   4
         ldy:  DIRECT_OAM_READ+]k,x ; Y coordinate
         lda   y_exclude,y
         bne   *+6
         txa                        ; Push the index of an entry that passes
         adc   #]k
         pha
]k       =     ]k+4
         --^
         FIN
         DO    OAM_UNROLL*TILE_FILTER
         lup   4
         ldy:  DIRECT_OAM_READ+]k,x ; Y coordinate
         lda   y_exclude,y
         bne   *+14
         ldy:  DIRECT_OAM_READ+1+]k,x ; tile
         lda   tile_exclude,y
         bne   *+6
         txa                        ; Push the index of an entry that passes
         adc   #]k
         pha
]k       =     ]k+4
         --^
         FIN
         DO    OAM_UNROLL
         txa
         adc   #16
         tax
         FIN
         DO    OAM_UNROLL*OAM_END_CMP
         cmp   #OAM_END_INDEX*4
         FIN
         DO    OAM_UNROLL
         bcc   oam_filter4
         FIN

; Pass 2: copy the sprites that passed into OAM_COPY and mark their lines in the shadow bitmap.
; They pop off the stack highest index first, so OAM_COPY is filled from the end to keep the
; sprites in OAM order.

         phk                        ; back to the code bank
         plb
         rep   #$30
         mx    %00

         tsc
         eor   #$FFFF
         sec
         adc   oam_stack            ; number of sprites pushed = oam_stack - S
         asl
         asl
         sta   spriteCount          ; spriteCount * 4 for easy comparison later
         tay
         beq   oam_copy_done

         lda   _ppuctrl
         bit   #NES_PPUCTRL_SPRSIZE
         bne   oam_copy8x16

oam_copy8x8
         dey
         dey
         dey
         dey
         sep   #$20                 ; pull the next index (pushed as a byte)
         pla
         rep   #$20
         and   #$00FF
         tax

         ldal  ROMBase+DIRECT_OAM_READ,x    ; Y coordinate and tile
         inc                        ; Increment the y-coordinate to match the PPU delay
         sta   OAM_COPY,y

         DO    GRID_DIRTY_RENDERING
         ELSE
         phx
         phy

; Need to add ScrollY to the sprite Y-coordinate here because the shadow bitmap is 1:1 with the nametable
; tile rows and we need to convert from screen coordinates to nametable rows.

         and   #$00FF               ; Isolate the Y-coordinate
         asl
         tay                        ; We are drawing this sprite, so mark it in the shadow list
         ldx   y2idx,y              ; Get the index into the shadowBitmap array for this y coordinate (y -> blk_y)
         lda   y2bits,y             ; Get the bit pattern for the first byte
oam_pb1  ora:  $0000,x
oam_pb2  sta:  $0000,x

         ply
         plx
         FIN

         ldal  ROMBase+DIRECT_OAM_READ+2,x  ; attributes and X coordinate
         sta   OAM_COPY+2,y

         tya
         bne   oam_copy8x8

oam_copy_done
         plb
         rts

; 8x16 mode. We cheat and pretend that there are 2 8x8 sprites.  Fix once we have to handle
; a game that has >32 8x16 sprites

oam_copy8x16
         dey
         dey
         dey
         dey
         sep   #$20                 ; pull the next index (pushed as a byte)
         pla
         rep   #$20
         and   #$00FF
         tax

         ldal  ROMBase+DIRECT_OAM_READ,x    ; Y coordinate and tile
         inc                        ; Increment the y-coordinate to match the PPU delay
         sta   OAM_COPY,y

         DO    GRID_DIRTY_RENDERING
         ELSE
         phx
         phy

         and   #$00FF               ; Isolate the Y-coordinate
         asl
         tay                        ; We are drawing this sprite, so mark it in the shadow list
         ldx   y2idx,y              ; Get the index into the shadowBitmap array for this y coordinate (y -> blk_y)
         lda   y2bits,y             ; Get the bit pattern for the first byte
oam_pb3  ora:  $0000,x
oam_pb4  sta:  $0000,x

; Do some extra work for the bottom part of the sprite

         ldx   y2idx+16,y
         lda   y2bits+16,y
oam_pb5  ora:  $0000,x
oam_pb6  sta:  $0000,x

         ply
         plx
         FIN

         ldal  ROMBase+DIRECT_OAM_READ+2,x  ; attributes and X coordinate
         sta   OAM_COPY+2,y

         tya
         bne   oam_copy8x16
         bra   oam_copy_done

; ensureShadowBitmap (grid renderer builds)
;
; Make sure CurrShadowBitmap marks the lines of this frame's sprites: build it from OAM_COPY the
; first time it is asked for after scanOAMSprites.  Called by shadowBitmapToList and by custom
; renderers that read the bitmap.  DBR = the code bank.
         DO     GRID_DIRTY_RENDERING
shadowBitmapValid dw 0
sbBits   dw     0

         mx     %00
ensureShadowBitmap
         lda    shadowBitmapValid
         beq    *+3
         rts
         inc    shadowBitmapValid

         ldx    CurrShadowBitmap     ; Erase the bitmap
]n       equ    0
         lup    15
         stz:   ]n,x
]n       =      ]n+2
         --^

         ldx    spriteCount          ; (count * 4)
         beq    :done
         lda    _ppuctrl
         bit    #NES_PPUCTRL_SPRSIZE
         bne    :tall

:short   dex
         dex
         dex
         dex
         lda    OAM_COPY,x           ; first line (OAM Y + 1)
         and    #$00FF
         asl
         tay
         lda    y2bits,y
         sta    sbBits
         lda    y2idx,y
         tay
         lda    sbBits
         ora    (CurrShadowBitmap),y
         sta    (CurrShadowBitmap),y
         txa
         bne    :short
:done    rts

:tall    dex
         dex
         dex
         dex
         lda    OAM_COPY,x
         and    #$00FF
         asl
         phx
         tax                         ; both halves
         lda    y2bits,x
         ldy    y2idx,x
         ora    (CurrShadowBitmap),y
         sta    (CurrShadowBitmap),y
         lda    y2bits+16,x
         ldy    y2idx+16,x
         ora    (CurrShadowBitmap),y
         sta    (CurrShadowBitmap),y
         plx
         txa
         bne    :tall
         rts
         FIN

; InitYExclude
;
; Fill the game's y_exclude table (in the ROMBase bank) from the playfield constants: an entry is
; 0 when a sprite at that OAM Y is drawn.  This is the range the per-sprite compares used to check;
; the PPU draws a sprite one line below its OAM Y.
;
; Called once from NES_StartUp.
         DO     NO_VERTICAL_CLIP
Y_KEEP_MIN equ  y_offset-8          ; partly visible sprites are clipped by the renderer
Y_KEEP_MAX equ  max_nes_y-2
         ELSE
Y_KEEP_MIN equ  y_offset-1          ; only sprites entirely inside the playfield
Y_KEEP_MAX equ  max_nes_y-9
         FIN

         mx     %00
InitYExclude
         ldx    #0
         sep    #$20
:loop    lda    #1
         cpx    #Y_KEEP_MIN
         bcc    :store
         cpx    #Y_KEEP_MAX+1
         bcs    :store
         lda    #0
:store   stal   y_exclude,x
         inx
         cpx    #256
         bcc    :loop
         rep    #$20
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

; ppu_sprites.s
;
; Scan the OAM copy and start to build up the data structures for rendering the screen.
;
; The sprites that pass the game's filters are copied to OAM_COPY.  A full render also needs the
; bitmap of the lines with sprites, which segments the screen into "sprite" and "background" runs;
; it is built from OAM_COPY when first asked for (ensureShadowBitmap).

              DO ENABLE_DIRTY_RENDERING
              ds \,$00             ; Page-aligned: the grid renderer reads it with 8-bit index registers
              FIN
OAM_COPY      ds 256
spriteCount   dw 0
shadowBitmap0 ds 32                ; Lines with sprites, one bit per line (ensureShadowBitmap)

; scanOAMSprites reads the OAM straight from NES RAM at DIRECT_OAM_READ in the ROMBase bank.
; ROMBase is at offset $0000 of its bank in every game, so with DBR set to that bank the plain
; address DIRECT_OAM_READ is the same as ROMBase+DIRECT_OAM_READ (and avoids an
; external-plus-offset relocation).

oam_stack dw    0                   ; stack pointer before pass 1 pushes the sprites that pass

         mx   %00
scanOAMSprites

; The sprite lines bitmap is only needed by a full render (and some custom renderers), so it is built
; from OAM_COPY when first asked for (ensureShadowBitmap) instead of here.

         stz   shadowBitmapValid

; Check if sprites are disabled

         lda   ControlBits
         and   #CTRL_SPRITE_ENABLE
         bne   *+6
         stz   spriteCount
         rts

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

; Pass 2: copy the sprites that passed into OAM_COPY.
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

; The copy is the same for 8x8 and 8x16 sprites: an 8x16 sprite is one OAM entry, and the renderer
; reads the sprite size from PPUCTRL.

oam_copy
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

         ldal  ROMBase+DIRECT_OAM_READ+2,x  ; attributes and X coordinate
         sta   OAM_COPY+2,y

         tya
         bne   oam_copy

oam_copy_done
         plb
         rts

; ensureShadowBitmap
;
; Make sure shadowBitmap0 marks the lines of this frame's sprites: build it from OAM_COPY the
; first time it is asked for after scanOAMSprites.  Called by shadowBitmapToList and by custom
; renderers that read the bitmap.  DBR = the code bank.
shadowBitmapValid dw 0

; The loop index is in Y and the line's table offset in X, so the bitmap byte can be loaded straight into
; Y (ldy y2idx,x); the loop index waits in tmp0 (a leaf routine: nothing is called in between).
         mx     %00
ensureShadowBitmap
         lda    shadowBitmapValid
         beq    *+3
         rts
         inc    shadowBitmapValid

]n       equ    0                    ; Erase the bitmap
         lup    15
         stz    shadowBitmap0+]n
]n       =      ]n+2
         --^

         ldy    spriteCount          ; (count * 4)
         beq    :done
         lda    _ppuctrl
         bit    #NES_PPUCTRL_SPRSIZE
         bne    :tall

:short   dey
         dey
         dey
         dey
         sty    tmp0
         lda    OAM_COPY,y           ; first line (OAM Y + 1)
         and    #$00FF
         asl
         tax
         lda    y2bits,x
         ldy    y2idx,x
         ora    shadowBitmap0,y
         sta    shadowBitmap0,y
         ldy    tmp0
         bne    :short
:done    rts

:tall    dey
         dey
         dey
         dey
         sty    tmp0
         lda    OAM_COPY,y
         and    #$00FF
         asl
         tax                         ; both halves
         lda    y2bits,x
         ldy    y2idx,x
         ora    shadowBitmap0,y
         sta    shadowBitmap0,y
         lda    y2bits+16,x
         ldy    y2idx+16,x
         ora    shadowBitmap0,y
         sta    shadowBitmap0,y
         ldy    tmp0
         bne    :tall
         rts

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

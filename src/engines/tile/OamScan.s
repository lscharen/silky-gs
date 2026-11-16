; OamScan.s -- silky's scanOAMSprites and InitYExclude (ppu_sprites.s)
spriteCount ENT
         dw    0
OAM_COPY ENT
         ds    256

oam_stack dw    0                   ; stack pointer before pass 1 pushes the sprites that pass

         mx   %00
scanOAMSprites
; Check if sprites are disabled

         lda   S_ControlBits
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
         beq   oam_copy_done        ; (Z from the asl)

; The copy is the same for 8x8 and 8x16 sprites: an 8x16 sprite is one OAM entry, and the renderer
; reads the sprite size from PPUCTRL.
;
; 8-bit index registers: PLX pulls the pushed index byte straight into X, and Y is the OAM_COPY offset.
; 64 sprites make Y = 0 (256) to start with, which works because Y is tested after the copy.

         sep   #$10
         mx    %01
         tay
oam_copy
         dey
         dey
         dey
         dey
         plx                        ; the next index (pushed as a byte)

         ldal  ROMBase+DIRECT_OAM_READ,x    ; Y coordinate and tile
         inc                        ; Increment the y-coordinate to match the PPU delay
         sta   OAM_COPY,y

         ldal  ROMBase+DIRECT_OAM_READ+2,x  ; attributes and X coordinate
         sta   OAM_COPY+2,y

         cpy   #0
         bne   oam_copy
         rep   #$10
         mx    %00

oam_copy_done
         plb
         rts

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



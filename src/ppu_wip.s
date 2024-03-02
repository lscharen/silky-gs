; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.
const8  mac
        db    ]1,]1,]1,]1,]1,]1,]1,]1
        <<<

wconst8 mac
        dw    ]1,]1,]1,]1,]1,]1,]1,]1
        <<<

const32 mac
        const8 ]1
        const8 ]1+1
        const8 ]1+2
        const8 ]1+3
        <<<

wconst32 mac
        wconst8 ]1
        wconst8 ]1+1
        wconst8 ]1+2
        wconst8 ]1+3
        <<<

rep8    mac
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        <<<

wrep8    mac
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        <<<

        mx    %00

; Draw the valid sprites -- we have to scan the 64 sprite bytes to figure out what's visible and what's not.
; Typlically, NES games will set the y-coordinate offscreen for "unused" sprites
PPUDrawSprites

;]index  =    1                ; Always skip sprite 0 (make this configurable)
;        lup  63
;        lda  BASE+{4*]index}

;        --^
; Draw a tile from the PPU into the code field
;
; X = PPU address
DrawPPUTile
        phx                ; save
        txa
        and  #$2C00        ; Create a base pointer to the nametable
        ora  #$0300        ; page with the attributes data
        clc
        adc  #PPU_MEM
        sta  tmp1
        stz  tmp3          ; This is the palette selection

        txa
        and  #$03FF                  ; mask the address within the nametable
        tax
        ldy  #0                      ; zero out top and bottom bytes of Y/A.
        tya
        sep  #$20
        lda  PPU_ATTR_ADDR,x         ; load the nametable offset for the attribute memory (value of $C0 - $FF)
        tay
        lda  (tmp1),y                ; load the attribute byte
        and  PPU_ATTR_MASK,x         ; mask out just the bits for this metatile
        beq  :pal0                   ; if the value is zero, doesn't matter what the bits are
        bit  #$03                    ; is the value in the lowest bits
        beq  :highbits
        asl
        bra  :store

:highbits
        lsr
        bit  #$06                    ; shift until the value is in bits 1 and 2
        bne  :store
        lsr
        lsr
        bit  #$06
        bne  :store
        lsr
        lsr
:store  sta  tmp3+1                  ; put the value in the high byte
:pal0   rep  #$20
        plx

        lda  PPU_MEM-1,x   ; load the tile id into the high byte
        and  #$FF00        ; because tiles are page-aligned
        tay

        txa
        bit  #$0400
        bne  :nt2

        and  #$001F
        bra  :shared

:nt2
        and  #$001F
        ora  #$0020              ; Second table

:shared
        sta  tmp2
        txa
        and  #$03E0
        asl
        asl
        asl
        ora  tmp2
        tax

        lda  tmp3
        jmp  DrawCompiledTile

; Render and clear the queues
PPUFlushQueues
        ldy  #0
:at_loop
        lda  at_queue,y          ; load the address
        and  #$2400              ; Are we on the first or second nametable
        sta  tmp1

        lda  at_queue,y
        and  #$003F              ; Isolate the attribute offset
        asl
        tax
        lda  :corner,x           ; Load the PPU address of the corder of the metatile for this attribute byte
        ora  tmp1

        ldx  nt_queue_front
        cpx  #{NT_QUEUE_SIZE-16}*2    ; fatal errors for now
        bcc  *+4
        brk  $97

        clc
        sta  nt_queue,x
        inc
        sta  nt_queue+2,x
        inc
        sta  nt_queue+4,x
        inc
        sta  nt_queue+6,x
        adc  #32-3
        sta  nt_queue+8,x
        inc
        sta  nt_queue+10,x
        inc
        sta  nt_queue+12,x
        inc
        sta  nt_queue+14,x
        adc  #32-3
        sta  nt_queue+16,x
        inc
        sta  nt_queue+18,x
        inc
        sta  nt_queue+20,x
        inc
        sta  nt_queue+22,x
        adc  #32-3
        sta  nt_queue+24,x
        inc
        sta  nt_queue+26,x
        inc
        sta  nt_queue+28,x
        inc
        sta  nt_queue+30,x
        txa
        adc  #32
        sta  nt_queue_front

        iny
        iny
        cpy  at_queue_front
        bcc  :at_loop

        ldy  #0
:nt_loop
        ldx  nt_queue,y
        phy
        jsr  DrawPPUTile
        ply
        iny
        iny
        cpy  nt_queue_front
        bcc  :nt_loop

        stz  nt_queue_front
        stz  at_queue_front
        rts

:corner 
]row    =    0
        lup  8
        dw   {128*{]row}}+0
        dw   {128*{]row}}+4
        dw   {128*{]row}}+8
        dw   {128*{]row}}+12
        dw   {128*{]row}}+16
        dw   {128*{]row}}+20
        dw   {128*{]row}}+24
        dw   {128*{]row}}+28
]row    =    ]row+1
        --^

          mx    %11
          dw $a5a5 ; marker to find in memory
ppuaddr   ENT
          ds 2     ; 16-bit ppu address
w_bit     dw 1     ; currently writing to high or low to the address latch
vram_buff dw 0     ; latched data when reading VRAM ($0000 - $3EFF)

ppuincr   dw 1     ; 1 or 32 depending on bit 2 of PPUCTRL
spadr     dw $0000 ; Sprite pattern table ($0000 or $1000) depending on bit 3 of PPUCTRL
ntaddr    dw $2000 ; Base nametable address ($2000, $2400, $2800, $2C00), bits 0 and 1 of PPUCTRL
bgadr     dw $0000 ; Background pattern table address
ppuctrl   dw 0     ; Copy of the ppu ctrl byte
ppumask   dw 0     ; Copy of the ppu mask byte
ppustatus dw 0
oamaddr   dw 0     ; Typically this will always be 0
ppuscroll dw 0     ; Y X coordinates

ntbase    db $20,$24,$28,$2c

assert_lt mac
        cmp ]1
        bcc ok
        brk ]2
ok
        <<<

assert_x_lt mac
        cpx ]1
        bcc ok
        brk ]2
ok
        <<<

cond    mac
        bit ]1
        beq cond_0
        lda ]3
        bra cond_s
cond_0  lda ]2
cond_s  sta ]4
        <<<

; $2000 - PPUCTRL (Write only)
PPUCTRL_WRITE ENT
        php
        phb

        phk
        plb

        sta  ppuctrl
        phx

; Set the pattern table base address
        and  #$03
        tax
        lda  ntbase,x
        sta  ntaddr+1

; Set the vram increment
        lda  ppuctrl
        cond #$04;#$01;#$20;ppuincr

; Set the sprite table address
        lda  ppuctrl
        cond #$08;#$00;#$10;spadr+1

; Set the background table address
        lda  ppuctrl
        cond #$10;#$00;#$10;bgadr+1

        plx
        lda  ppuctrl
        plb
        plp
        rtl

; $2001 - PPUMASK (Write only)
PPUMASK_WRITE ENT
        stal ppumask
        rtl


; $2002 - PPUSTATUS For "ldx ppustatus"
PPUSTATUS_READ_X ENT
        php
        pha

        lda  #1
        stal w_bit             ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        tax
        and  #$7F              ; Clear the VBL flag
        stal ppustatus

        pla                    ; Restore the accumulator (return value in X)
        plp
        phx                    ; re-read x to set any relevant flags
        plx

        rtl

PPUSTATUS_READ ENT
        php

        lda  #1
        stal w_bit           ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        pha
        and  #$7F              ; Clear the VBL flag
        stal ppustatus

        pla                  ; pop the return value
        plp
        pha                  ; re-read accumulator to set any relevant flags
        pla
        rtl

; $2003
OAMADDR_WRITE ENT
        stal oamaddr
        rtl

; $2005 - PPU SCROLL
PPUSCROLL_WRITE ENT
        php
        phb
        phk
        plb
        phx
        pha

        ldx  w_bit
        sta  ppuscroll,x
        txa
        eor  #$01
        sta  w_bit

        pla
        plx
        plb
        plp
        rtl

; $2006 - PPUADDR
PPUADDR_WRITE ENT
        php
        phb
        phk
        plb
        phx
        pha

        ldx  w_bit
        sta  ppuaddr,x
;        assert_lt #$40;$D0
        txa
        eor  #$01
        sta  w_bit

        lda  ppuaddr+1             ; Stay within the mirrored memory space
        and  #$3F
        sta  ppuaddr+1

        pla
        plx
        plb
        plp
        rtl


; 2007 - PPUDATA (Read/Write)
;
; If reading from the $0000 - $3EFF range, the value from vram_buff is returned and the actual data is loaded
; post-fetch.
PPUDATA_READ ENT
        php
        phb
        phk
        plb
        phx

        rep  #$30       ; do a 16-bit update of the address
        ldx  ppuaddr
        txa
;        assert_lt #$4000;$d1

        clc
        adc  ppuincr
        and  #$3FFF
        sta  ppuaddr
        sep  #$20       ; back to 8-bit acc for the read itself

        cpx  #$3F00     ; check which range of memory we are accessing?
        bcc  :buff_read

        lda  PPU_MEM,x
        bra  :out

:buff_read
        lda  vram_buff  ; read from the buffer
        pha
        lda  PPU_MEM,x  ; put the data in the buffer for the next read
        sta  vram_buff
        pla             ; pop the return value

:out
        sep #$10
        plx
        plb
        plp

        pha
        pla
        rtl


* ;ppu_write_log_len dw 0
* ;ppu_write_log  ds 100        ; record the first 50 PPU write addresses in each frame

NT_QUEUE_SIZE     equ 2048                 ; Enough space for _every_ tile over multiple frames
nt_queue_front    dw  0
nt_queue          ds  2*{NT_QUEUE_SIZE}    ; Each entry is a PPU address

AT_QUEUE_SIZE     equ 192                  ; Enough space for _every_ attribute byte
at_queue_front    dw  0
at_queue          ds  3*{AT_QUEUE_SIZE}    ; Keep the old value, too, so we can compare

; The ppu data can be written in any order -- in particular, the PPU Nametable Attribute bytes
; can be written after the tile data in the nametable.  On hardware, changing the attribute byte
; immediately updates the palette information for the tile metablock, but we need to redraw these
; tiles ourselves.
;
; So, we have to defer the drawing of tiles until after the ROM NMI routine is complete and
; we are ready to render a new frame.  To help with ordering, the attribute bytes are stored
; in a separate queue from the regular tile bytes.
ppu_write_log_index dw 0
ppu_write_log ds  3*1024
PPUDATA_WRITE ENT
        php
        phb
        phk
        plb
        pha
        phx
        phy

        rep  #$10
        ldx  ppuaddr

        cmp  PPU_MEM,x
        beq  :nochange

        sta  PPU_MEM,x                ; Update PPU memory (8-bit write)

        rep  #$31                     ; Clear the carry, too
        txa
;        sta  ppu_write_log,y
;        iny
;        iny
;        cpy  #3*1024
;        bcc  *+5
;        ldy  #0000
;        sty  ppu_write_log_index
;        clc

        lda  ppuaddr
        adc  ppuincr
        and  #$3FFF
        sta  ppuaddr                  ; Advance to the new ppu address

; Since we've updated some PPU memory, we need to determine what area of memory it is in and
; take an appropriate action
;
; 1. In the range $2{x}00 to $2{x+3}BF -- this is tile data, so it should be queued for an update
; 2. In the range $2{x+3}C0 to $2{x+3}FF -- this is tile attribute data and should be put on a separate queue
; 3. In the range $3F00-$3FFF -- this is the palette range and executes a callback function to take a game-specific action

        txa
        and  #$03C0                   ; Is this in the tile attribute space?
        cmp  #$03C0
        bcc  :not_attr

        txa
        ldx  at_queue_front
        cpx  #AT_QUEUE_SIZE*2
        bcc  *+4
        brk  $99                   ; Fatal error if the queue size is exceeded

        sta  at_queue,x
        inx
        inx
        stx  at_queue_front
        bra  :done

:not_attr
        cpx  #$2000                ; If the value is out of range, we're done
        bcc  :done

        cpx  #$3000                ; If it's within the namespace tables, save it since
        bcc  :cache                ; we already checked for attribute memory above

        cpx   #$3F00               ; Last check, if it's in the palette memory we will do
        bcc   :done                ; some extra work
        brl   :extra

:cache
        txa                        ; This is a nametable value that's been changed, so
        ldx  nt_queue_front        ; save it to be handled during the next refresh
        cpx  #NT_QUEUE_SIZE*2
        bcc  *+4
        brk  $99                   ; Fatal error if the queue size is exceeded

        sta  nt_queue,x
        inx
        inx
        stx  nt_queue_front

:done
        sep  #$30
        ply
        plx
        pla
        plb
        plp
        rtl

:nochange
        rep  #$31
        lda  ppuaddr
        adc  ppuincr
        and  #$3FFF
        sta  ppuaddr
        bra  :done

        mx   %00

* setborder
*         php
*         sep  #$20
*         eorl $E0C034
*         and  #$0F
*         eorl $E0C034
*         stal $E0C034
*         plp
*         rts

; Do some extra work to keep palette data in sync
;
; Based on the palette data that SMB uses, we remap the NES palette entries
; based on the AreaType, so most of the PPU writes are ignored.  However,
; we do update some specific palette entries
;
; BG0,0 maps to IIgs Palette index 0    (Background color)
; BG3,1 maps to IIgs Palette index 1    (Color cycle for blocks)
; SP0,1 maps to IIgs Palette index 14   (Player primary color; changes with fire flower)
; SP0,3 maps to IIgs Palette index 15   (Player primary color; changes with fire flower)
        mx   %00
:extra
        txa
        and  #$001F
        asl
        tax
        jmp  (palTbl,x)

palTbl  dw   ppu_3F00,ppu_3F01,ppu_3F02,ppu_3F03
        dw   ppu_3F04,ppu_3F05,ppu_3F06,ppu_3F07
        dw   ppu_3F08,ppu_3F09,ppu_3F0A,ppu_3F0B
        dw   ppu_3F0C,ppu_3F0D,ppu_3F0E,ppu_3F0F
        dw   ppu_3F10,ppu_3F11,ppu_3F12,ppu_3F13
        dw   ppu_3F14,ppu_3F15,ppu_3F16,ppu_3F17
        dw   ppu_3F18,ppu_3F19,ppu_3F1A,ppu_3F1B
        dw   ppu_3F1C,ppu_3F1D,ppu_3F1E,ppu_3F1F

; Background color
ppu_3F00
        lda  PPU_MEM+$3F00
        ldx  #0
        brl  extra_out

; Shadow for background color
ppu_3F10
        lda  PPU_MEM+$3F10
        ldx  #0
        brl  extra_out


; Tile palette 3, color 1
ppu_3F0D
        lda  PPU_MEM+$3F0D
        ldx  #2
        brl  extra_out

; Sprite Palette 0, color 1
ppu_3F11
        lda  PPU_MEM+$3F11
        ldx  #28
        brl  extra_out

ppu_3F13
        lda  PPU_MEM+$3F13
        ldx  #30
        brl  extra_out

ppu_3F01
ppu_3F02
ppu_3F03

ppu_3F04
ppu_3F05
ppu_3F06
ppu_3F07

ppu_3F08
ppu_3F09
ppu_3F0A
ppu_3F0B

ppu_3F0C

ppu_3F0E
ppu_3F0F

ppu_3F12

ppu_3F14

; Allow the second sprite palette to be set by the ROM in world 4 because it switches to the bowser
; palette when player reaches the end of the level.  Mapped to IIgs palette indices 8, 9, 10
CASTLE_AREA_TYPE equ 3
ppu_3F15
        lda  LastAreaType
        cmp  #CASTLE_AREA_TYPE
        bne  no_pal

        lda  PPU_MEM+$3F15
        ldx  #8*2
        brl  extra_out
ppu_3F16
        lda  LastAreaType
        cmp  #CASTLE_AREA_TYPE
        bne  no_pal

        lda  PPU_MEM+$3F16
        ldx  #9*2
        brl  extra_out
ppu_3F17
        lda  LastAreaType
        cmp  #CASTLE_AREA_TYPE
        bne  no_pal

        lda  PPU_MEM+$3F17
        ldx  #10*2
        brl  extra_out

ppu_3F18
ppu_3F19
ppu_3F1A
ppu_3F1B

ppu_3F1C
ppu_3F1D
ppu_3F1E
ppu_3F1F
        brl  no_pal
; Exit code to set a IIgs palette entry from the PPU memory
;
; A = NES palette value
; X = IIgs Palette index
extra_out
        and  #$00FF
        asl
        tay
        lda  nesPalette,y
        stal $E19E00,x

no_pal
        sep  #$30
        ply
        plx
        pla
        plb
        plp
        rtl

* ; Trigger a copy from a page of memory to OAM.  Since this is a DMA operation, we can cheat and do a 16-bit copy
PPUDMA_WRITE ENT
        rtl                         ; Cheat like crazy and pretend it didn't happen.  Read from $0200 directly when we render

;        php
;        pha

;        rep  #$30                   ; Only copy from $202 because we always skip sprite 0
;]n      equ   0
;        lup   127
;        lda   ROMBase+$200+2+]n
;        stal  PPU_OAM+2+]n
;]n      =     ]n+2
;        --^
;        sep #$30

;        pla
;        plp
;        rtl

y_offset_rows equ 2
y_height_rows equ 25
y_offset equ {y_offset_rows*8}
y_height equ {y_height_rows*8}
; max_nes_y equ {y_height+y_offset-8}
max_nes_y equ 216
min_nes_y equ 16

* ; Scan the OAM memory and copy the values of the sprites that need to be drawn. There are two reasons to do this
* ;
* ; 1. Freeze the OAM memory at this instanct so that the NES ISR can keep running without changing values
* ; 2. We have to scan this list twice -- once to build up the shadow list and once to actually render the sprites
OAM_COPY    ds 256
spriteCount dw 0

         mx   %00
scanOAMSprites

; zero out the shadow bitmap (16-bit writes)
]n       equ   0
         lup   15
         stz   shadowBitmap+]n
]n       =     ]n+2
         --^

         ldx   #4                  ; Always skip sprite 0
         ldy   #0                  ; This is the destination index

:loop
         ldal   ROMBase+$0200,x    ; Copy the low word
         sta    OAM_COPY,y

         eor    #$FC00             ; Is the tile == $FC? This is a blank tile in this ROM
         cmp    #$0100
         bcc    :skip

         and    #$00FF            ; Isolate the Y-coordinate
         cmp    #max_nes_y+1      ; Skip anything that is beyond this line
         bcs    :skip
         cmp    #y_offset
         bcc    :skip

         phx
         phy

         asl
         tay                      ; We are drawing this sprite, so mark it in the shadow list
         ldx    y2idx,y           ; Get the index into the shadowBitmap array for this y coordinate (y -> blk_y)
         lda    y2bits,y          ; Get the bit pattern for the first byte
         ora    shadowBitmap,x
         sta    shadowBitmap,x

         ply
         plx

         ldal   ROMBase+$0202,x    ; Copy the high word
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
         cpx  #$0100
         bcc  :loop

         sty   spriteCount           ; spriteCount * 4 for easy coparison later
         rts

* ; Screen is 200 lines tall. It's worth it be exact when building the list because one extra
* ; draw + shadow sequence takes at least 1,000 cycles.
* ;shadowBitmap    ds 32              ; Provide enough space for the full ppu range (240 lines) + 16 since the y coordinate can be off-screen

* ; A representation of the list as [top, bot) pairs
shadowListCount dw 0            ; Pad for 16-bit comparisons
shadowListTop   ds 64
shadowListBot   ds 64

y2idx   wconst32 $00
        wconst32 $04
        wconst32 $08
        wconst32 $0C                ; 256 bytes
        wconst32 $10
        wconst32 $14
        wconst32 $18
        wconst32 $1C

; Repeating pattern of 8 consecutive 1 bits
;y2low   rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
;        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
;        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
;        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01

;y2high  rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
;        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
;        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
;        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE

y2bits  wrep8 $00FF,$807F,$C03F,$E01F,$F00F,$F807,$FC03,$FE01
        wrep8 $00FF,$807F,$C03F,$E01F,$F00F,$F807,$FC03,$FE01
        wrep8 $00FF,$807F,$C03F,$E01F,$F00F,$F807,$FC03,$FE01
        wrep8 $00FF,$807F,$C03F,$E01F,$F00F,$F807,$FC03,$FE01

; 25 entries to multiple steps in the shadow bitmap to scanlines
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

* ; Altername between BltRange and PEISlam to expose the screen
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

        ldx  #y_offset_rows               ; Start at the third row (y_offset = 16) walk the bitmap for 25 bytes (200 lines of height)
        lda  #0
        sta  shadowListCount  ; zero out the shadow list count

; This loop is called when we are not tracking a sprite range
:zero_loop
        ldy  shadowBitmap,x
        beq  :zero_next

        lda  {mul8-y_offset_rows},x           ; This is the scanline we're on (offset by the starting byte)
        clc
        adc  offset,y                         ; This is the first line defined by the bit pattern
        sta  :top
        bra  :one_next

:zero_next
        inx
        cpx  #y_height_rows+y_offset_rows ; +1              ; End at byte 27
        bcc  :zero_loop
        bra  :exit           ; ended while not tracking a sprite, so exit the function

:one_loop
        lda  shadowBitmap,x  ; if the next byte is all sprite, just continue
        cmp  #$FF
        beq  :one_next

* ; The byte has to look like 1..10..0  The first step is to mask off the high bits and store the result
* ; back into the shadowBitmap

        tay
        and  offsetMask,y
        sta  shadowBitmap,x

        lda  {mul8-y_offset_rows},x
        clc
        adc  invOffset,y

        ldy  shadowListCount
        sta  shadowListBot,y
        lda  :top
        sta  shadowListTop,y
        iny
        sty  shadowListCount

; Loop back to check if there is more sprite data on this byte

        bra  :zero_loop


:one_next
        inx
        cpx  #y_height_rows+y_offset_rows+1
        bcc  :one_loop

; If we end while tracking a sprite, add to the list as the last item

        ldx  shadowListCount
        lda  :top
        sta  shadowListTop,x
        lda  #y_height
        sta  shadowListBot,x
        inx
        stx  shadowListCount

:exit
        rep  #$30
        lda  shadowListCount
        cmp  #64
        bcc  *+4
        brk  $13


        rts

; Setup all of the sprites from the NES OAM memory.  If possible, we read the OAM information directly
; from a game-specific area of NES RAM, rather than supporting the OAMDMA operation, to avoid extra
; copying.

drawOAMSprites

; Step 1: Scan the OAM sprite information.  Since we're reading NES RAM, we disable interrupts so that
;         a VBL cannot fire while we sync the data.

         sei
         jsr   scanOAMSprites              ; Filter out any sprites that don't need to be drawn and mark occupied lines
         cli

; Step 2: Convert the bitmap to a list of (top, bottom) pairs in order to update the screen

         jmp   shadowBitmapToList

; Render the prepared frame date
drawScreen

; Step 1: Draw the PEA lines that have sprites on them

        jsr   drawShadowList

; Step 2: Draw the sprites

        jsr   drawSprites

; Step 3: Reveal the sprites and background using alternative render and PEI slams

        jmp   exposeShadowList

drawSprites
:tmp    equ   tmp0

; Run through the copy of the OAM memory

        ldx   #0
        cpx   spriteCount
        bne   oam_loop
        rts

oam_loop
        phx                  ; Save x

        lda   OAM_COPY,x     ; Y-coordinate
;        inc                  ; Compensate for PPU delayed scanline

        and   #$00FF
        mul160 tmp0
        clc
        adc  #$2000-{y_offset*160}+x_offset
        sta  tmp0

        lda  OAM_COPY+3,x
        lsr
        and  #$007F
        clc
        adc  tmp0
        tay

        lda  OAM_COPY+2,x
        pha
        bit  #$0040                   ; horizontal flip
        bne  :hflip

        lda  OAM_COPY,x               ; Load the tile index into the high byte (x256)
        and  #$FF00
        lsr                           ; multiple by 128
        tax
        bra  :noflip

:hflip
        lda  OAM_COPY,x               ; Load the tile index into the high byte (x256)
        and  #$FF00
        lsr                           ; multiple by 128
        adc  #64                      ; horizontal flip
        tax

:noflip
        pla
        asl
        and   #$0146                 ; Set the vflip bit, priority, and palette select bits

;        phd
;GTE_DP2 pea   $0000
;        pld
;        sec                          ; Select the sprite palettes
        jsr   drawTileToScreen
;        pld

        plx                          ; Restore the counter
        inx
        inx
        inx
        inx
        cpx   spriteCount
        bcc   oam_loop

        rts

* ; Mapping table to go from the NES y-coordinate to the proper address on-screen.  The map will always put a sprite into
* ; a legal range, but does not clip -- that must be done prior to looking up the on-screen address
* nesToShrYTbl ds 512

* ; Pass in A with the first physical line that corresponds to the top of the screen
* initNesToShrTable
* :tmp    equ   Tmp0
*         ldx  #0
*         ldy  #0
* :loop

*         iny
*         inx
*         inx
*         cpx  #$200
*         bcc  :loop
*         rts

mul160  mac
        asl
        asl
        asl
        asl
        asl
        sta  ]1
        asl
        asl
        clc
        adc  ]1
        <<<

* ; Custom tile blitter
* ;
* ; D = GTE blitter direct page space
* ; X = offset to the tile record
* ; 
*         mx    %00

* ; Temporary tile space on the direct page
* tmp_tile_data      equ 80

* DP2_TILEDATA_AND_BANK01_BANKS equ 172

* ;USER_TILE_RECORD   equ  178
* USER_TILE_ID       equ  178         ; copy of the tile id in the tile store
* ;USER_TILE_CODE_PTR equ  180         ; pointer to the code bank in which to patch
* USER_TILE_ADDR     equ  184         ; address in the tile data bank (set on entry)
* USER_FREE_SPACE    equ  186         ; a few bytes of scratch space

* USER_SCREEN_ADDR   equ  190
* USER_TEMP_0        equ  192
* USER_TEMP_1        equ  194

* LDA_IND_LONG_IDX equ $B7
* ORA_IND_LONG_IDX equ $17

* SHR_LINE_WIDTH equ 160

* ; Draw a tile to the graphics screen
* ;
* ; D = GTE Page 2
* ; X = tile address
* ; Y = screen address
* ; A = tile control bits; h ($0100), v ($0040) and palette select ($0006)
* jne     mac
*         beq   *+5
*         jmp   ]1
*         <<<

* jeq     mac
*         bne   *+5
*         jmp   ]1
*         <<<

* NESDirectTileBlitter
*         asl
*         and   #$0146                 ; Set the vflip bit, priority, and palette select bit
*         cpx   #$8000
*         jsr   drawTileToScreen       ; Just a shim since this function is called via JSL
*         rtl

drawTileToScreen
          tyx
          lda   #$ffff
]line     equ   0
          lup   8
          stal  $010000+{]line*SHR_LINE_WIDTH}+0,x
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x
]line     equ   ]line+1
          --^
          rts

*         pha
*         and   #$0006
*         sta   USER_FREE_SPACE                   ; Isolate the palette selection bits

*         clc
*         adc   #8                                ; Roll the carry bit to use as background vs sprite palette selection
* ;        rol
* ;        asl
* ;        asl
* ;        asl                                     ; carry * 8
*         adc   USER_FREE_SPACE
*         xba
*         clc
*         adcl  SwizzlePtr
*         sta   USER_FREE_SPACE
*         lda   #^AT1_T0                           ; Bank is a constant
*         sta   USER_FREE_SPACE+2                  ; Set the pointer to the right swizzle table

*         stx   USER_TILE_ADDR
*         sty   USER_SCREEN_ADDR

*         phb
*         pei   DP2_TILEDATA_AND_BANK01_BANKS
*         plb

*         pla                                      ; reload the saved accumulator
*         bit    #$0040
*         beq    :no_prio
*         bit    #$0100
*         jeq    :drawPriorityToScreen
* ;        jmp    :drawPriorityToScreenV

* :no_prio
*         bit    #$0100
*         jne    :drawTileToScreenV

* ; If we compile the sprites, then each word can be implemented as:
* ;
* ; x = screen address
* ;
* ; ldy  #LOOKUP_VAL          ; 3 constant 6-bit tile lookup value from NES CHR rom
* ; lda: 0,x                  ; 6
* ; and  #MASK                ; 3
* ; ora  [USER_FREE_SPACE],y  ; 7 lookup and merge in swizzled tile data = *(SwizzlePtr + palbits)
* ; sta: 0,x                  ; 6 = 25 cycles / word; 13 bytes
* ;
* ; There are 8 stores per tile, so 8 * 13 = 104 < 128, so we can still fit 512 tiles.  If we're selective
* ; about which tiles are compiled and which ones have H/V mirroring
* ;
* ; Current implementation below is 4+6+6+4+6+7+6 = 39 cycles
* ;
* ; Most tiles don't have 4 consecutive transparent pixels, but there will be some minor savings
* ; by avoiding those operations.  For MASK = $FFFF, the simplified code is and solid words are
* ; quite common, at least 25 - 30% of the words are solid.  So conservative estimate of
* ; 25 * 0.75 + 16 * 0.25 = ~22 cycles/word on average.  Throw in the 100% savings from MASK=0
* ; words and it's close to twice the speed of the current routine.
* ;
* ; ldy  #LOOKUP_VAL          ; 3 constant 6-bit tile lookup value from NES CHR rom
* ; lda  [USER_FREE_SPACE],y  ; 7 lookup and merge in swizzled tile data = *(SwizzlePtr + palbits)
* ; sta: 0,x                  ; 6 = 16 cycles / word

* ;]line   equ   0
* ;        lup   8
* ;        ldx   USER_TILE_ADDR
* ;        ldy:  {]line*4}+2,x                       ; Load the tile data lookup value
* ;        ldx   USER_SCREEN_ADDR
* ;        db    LDA_IND_LONG_IDX,USER_FREE_SPACE    ; Insert the actual tile data
* ;        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

* ;        ldx   USER_TILE_ADDR
* ;        ldy:  {]line*4},x                         ; Load the tile data lookup value
* ;        ldx   USER_SCREEN_ADDR
* ;        db    LDA_IND_LONG_IDX,USER_FREE_SPACE    ; Insert the actual tile data
* ;        stal  $010000+{]line*SHR_LINE_WIDTH},x

* ;]line   equ   ]line+1
* ;        --^

* ]line   equ   0
*         lup   8
*         ldx   USER_TILE_ADDR
*         ldy:  {]line*4}+2,x                       ; Load the tile data lookup value
*         lda:  {]line*4}+32+2,x                    ; Load the mask value
*         ldx   USER_SCREEN_ADDR
*         andl  $010000+{]line*SHR_LINE_WIDTH}+2,x  ; Mask against the screen
*         db    ORA_IND_LONG_IDX,USER_FREE_SPACE    ; Insert the actual tile data
*         stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

*         ldx   USER_TILE_ADDR
*         ldy:  {]line*4},x                         ; Load the tile data lookup value
*         lda:  {]line*4}+32,x                      ; Load the mask value
*         ldx   USER_SCREEN_ADDR
*         andl  $010000+{]line*SHR_LINE_WIDTH},x    ; Mask against the screen
*         db    ORA_IND_LONG_IDX,USER_FREE_SPACE    ; Insert the actual tile data
*         stal  $010000+{]line*SHR_LINE_WIDTH},x

* ]line   equ   ]line+1
*         --^

*         plb
*         plb                        ; Restore initial data bank
*         rts

* :drawTileToScreenV
* ]line   equ   0
*         lup   8
*         ldx   USER_TILE_ADDR
*         ldy:  {]line*4}+2,x                       ; Load the tile data lookup value
*         lda:  {]line*4}+32+2,x                    ; Load the mask value
*         ldx   USER_SCREEN_ADDR
*         andl  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x  ; Mask against the screen
*         db    ORA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data
*         stal  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x

*         ldx   USER_TILE_ADDR
*         ldy:  {]line*4},x                       ; Load the tile data lookup value
*         lda:  {]line*4}+32,x                    ; Load the mask value
*         ldx   USER_SCREEN_ADDR
*         andl  $010000+{{7-]line}*SHR_LINE_WIDTH},x  ; Mask against the screen
*         db    ORA_IND_LONG_IDX,USER_FREE_SPACE    ; Insert the actual tile data
*         stal  $010000+{{7-]line}*SHR_LINE_WIDTH},x

* ]line   equ   ]line+1
*         --^

*         plb
*         plb                        ; Restore initial data bank
*         rts

* :drawPriorityToScreen
* ]line   equ   0
*         lup   8
*         ldx   USER_TILE_ADDR
*         lda:  {]line*4}+32+2,x                      ; Save the inverted mask
*         eor   #$FFFF
*         sta   USER_TEMP_1

*         ldy:  {]line*4}+2,x                         ; Load the tile data lookup value
*         db    LDA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data

*         ldx   USER_SCREEN_ADDR
*         eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x
*         sta   USER_TEMP_0

* ; Convert the screen data to a mask.  Zero in screen = zero in mask, else $F
*         ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
*         bit   #$F000
*         beq   *+5
*         ora   #$F000
*         bit   #$0F00
*         beq   *+5
*         ora   #$0F00
*         bit   #$00F0
*         beq   *+5
*         ora   #$00F0
*         bit   #$000F
*         beq   *+5
*         ora   #$000F
*         eor   #$FFFF
*         and   USER_TEMP_0
*         and   USER_TEMP_1

*         eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x
*         stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

*         ldx   USER_TILE_ADDR
*         lda:  {]line*4}+32,x                      ; Save the inverted mask
*         eor   #$FFFF
*         sta   USER_TEMP_1

*         ldy:  {]line*4},x                         ; Load the tile data lookup value
*         db    LDA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data

*         ldx   USER_SCREEN_ADDR
*         eorl  $010000+{]line*SHR_LINE_WIDTH},x
*         sta   USER_TEMP_0

*         ldal  $010000+{]line*SHR_LINE_WIDTH},x
*         bit   #$F000
*         beq   *+5
*         ora   #$F000
*         bit   #$0F00
*         beq   *+5
*         ora   #$0F00
*         bit   #$00F0
*         beq   *+5
*         ora   #$00F0
*         bit   #$000F
*         beq   *+5
*         ora   #$000F
*         eor   #$FFFF
*         and   USER_TEMP_0
*         and   USER_TEMP_1

*         eorl  $010000+{]line*SHR_LINE_WIDTH},x
*         stal  $010000+{]line*SHR_LINE_WIDTH},x

* ]line   equ   ]line+1
*         --^

*         plb
*         plb                        ; Restore initial data bank
*         rts

* :drawPriorityToScreenV
* ]line   equ   0
*         lup   8
*         ldx   USER_TILE_ADDR
*         lda:  {]line*4}+32+2,x                      ; Save the inverted mask
*         eor   #$FFFF
*         sta   USER_TEMP_1

*         ldy:  {]line*4}+2,x                         ; Load the tile data lookup value
*         db    LDA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data

*         ldx   USER_SCREEN_ADDR
*         eorl  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x
*         sta   USER_TEMP_0

* ; Convert the screen data to a mask.  Zero in screen = zero in mask, else $F
*         ldal  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x
*         bit   #$F000
*         beq   *+5
*         ora   #$F000
*         bit   #$0F00
*         beq   *+5
*         ora   #$0F00
*         bit   #$00F0
*         beq   *+5
*         ora   #$00F0
*         bit   #$000F
*         beq   *+5
*         ora   #$000F
*         eor   #$FFFF
*         and   USER_TEMP_0
*         and   USER_TEMP_1

*         eorl  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x
*         stal  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x

*         ldx   USER_TILE_ADDR
*         lda:  {]line*4}+32,x                      ; Save the inverted mask
*         eor   #$FFFF
*         sta   USER_TEMP_1

*         ldy:  {]line*4},x                         ; Load the tile data lookup value
*         db    LDA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data

*         ldx   USER_SCREEN_ADDR
*         eorl  $010000+{{7-]line}*SHR_LINE_WIDTH},x
*         sta   USER_TEMP_0

*         ldal  $010000+{{7-]line}*SHR_LINE_WIDTH},x
*         bit   #$F000
*         beq   *+5
*         ora   #$F000
*         bit   #$0F00
*         beq   *+5
*         ora   #$0F00
*         bit   #$00F0
*         beq   *+5
*         ora   #$00F0
*         bit   #$000F
*         beq   *+5
*         ora   #$000F
*         eor   #$FFFF
*         and   USER_TEMP_0
*         and   USER_TEMP_1

*         eorl  $010000+{{7-]line}*SHR_LINE_WIDTH},x
*         stal  $010000+{{7-]line}*SHR_LINE_WIDTH},x
* ]line   equ   ]line+1
*         --^

*         plb
*         plb                        ; Restore initial data bank
*         rts

* ; Assume that when the tile is updated, it includes a full 10-bit value with the 
* ; palette bits included with the lookup bits
* ;
* ; If we could compile all of the tiles, then the code becomes
* ; 
* ; ldy  #DATA
* ; lda  [USER_FREE_SPACE],y
* ; sta: code,x
* ;
* ; And we save _at_least_ 11 cycles / word. 6 + 7 + 4 + 4 + 6 = 27 vs 16.
* ;
* ; Also, by exposing/short-circuiting the draw_tile stuff to avoid the GTE tile queue, we significantly
* ; reduce overhead and probably solve the tile column bug.
* NESTileBlitter
*         lda  USER_TILE_ID
*         and  #$0600                        ; Select the tile palette from the tile id
*         clc
*         adcl SwizzlePtr
*         sta  USER_FREE_SPACE
*         lda  #^AT1_T0
*         sta  USER_FREE_SPACE+2

*         ldx  USER_TILE_ADDR                ; Get the address of the tile (base only)
* ]line   equ  0
*         lup  8
*         ldy: {]line*4},x
*         db   LDA_IND_LONG_IDX,USER_FREE_SPACE
*         sta  tmp_tile_data+{]line*4}
*         ldy: {]line*4}+2,x
*         db   LDA_IND_LONG_IDX,USER_FREE_SPACE
*         sta  tmp_tile_data+{]line*4}+2
* ]line   equ  ]line+1
*         --^
*         lda  #1                            ; Request tmp_tile_data be copied to tile store
*         rtl

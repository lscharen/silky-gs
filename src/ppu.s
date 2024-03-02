; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.

const8  mac
        db    ]1,]1,]1,]1,]1,]1,]1,]1
        <<<

const32 mac
        const8 ]1
        const8 ]1+1
        const8 ]1+2
        const8 ]1+3
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
        pha                    ; spacefor result
        php
        pha

        lda  #1
        stal w_bit             ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        sta  3,s
        and  #$7F              ; Clear the VBL flag
        stal ppustatus

        pla                    ; Restore the accumulator (return value in X)
        plp
        plx

        rtl

PPUSTATUS_READ ENT
        pha                  ; space for return value
        php

        lda  #1
        stal w_bit           ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        sta  2,s
        and  #$7F              ; Clear the VBL flag
        stal ppustatus

        plp
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


ppu_write_log_len dw 0
ppu_write_log  ds 100        ; record the first 50 PPU write addresses in each frame


nt_queue_front dw 0
nt_queue_end   dw 0
nt_queue       ds 2*{NT_QUEUE_SIZE}

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

        ldy  PPU_MEM,x                ; Save in case we need to compare later
        sta  PPU_MEM,x

        rep  #$30
        txa
        clc
        adc  ppuincr
        and  #$3FFF
        sta  ppuaddr

; Anything between $2000 and $3000, we need to add to the queue.  We can't reject updates here because we may not
; actually update the GTE tile store for several game frames and the position of the tile within the tile store
; may change if the screen is scrolling
;
; There is one special case. We want the nt_queue to only be a queue of tiles to possibly redraw.  If the PPU
; data that is updated is in the attribute table area, then we do some extra work to decide which of the 16
; tiles *actually* need to be redrawn

        cpx  #$3000
        bcs  :nocache
        cpx  #$2000                ; Change to $2080 to ignore score field updates
        bcc  :nocache

        txa
        and  #$03C0
        cmp  #$03C0
        beq  :attrtbl

        jsr  :enqueue              ; Add the address in the X register to the queue

:nocache
        cpx  #$3F00
        bcc  :done
        brl  :extra

:nochange
        rep  #$30
        txa
        clc
        adc  ppuincr
        and  #$3FFF
        sta  ppuaddr

:done
        sep  #$30
        ply
        plx
        pla
        plb
        plp
        rtl

        mx   %00
:enqueue
        lda  nt_queue_end
        tay
        inc
        inc
        and  #NT_QUEUE_MOD
        cmp  nt_queue_front
        beq  :full

        sta  nt_queue_end
        txa
        sta  nt_queue,y

:full
;        lda  #1
;        jsr  setborder
        rts

:attrtbl
        txa                           ; Calculate the base address in the nametable from the attribute address
        and  #$2C00
        pha
        txa
        and  #$0007
        asl
        asl
        ora  1,s
        sta  1,s
        txa
        and  #$0038
        asl
        asl
        asl
        asl
        ora  1,s
        sta  1,s

        tya
        eor  PPU_MEM,x                ; Identify bits that have changed
        and  #$00FF
        bit  #$00C0
        beq  :skip_bot_right

        pha
        lda  3,s
        clc
        adc  #64+2                    ; offset 2 rows an 2 columns
        tax
        jsr  :enqueue_blk
        pla
:skip_bot_right

        bit  #$0030
        beq  :skip_bot_left

        pha
        lda  3,s
        clc
        adc  #64                    ; offset 2 rows
        tax
        jsr  :enqueue_blk
        pla
:skip_bot_left

        bit  #$000C
        beq  :skip_top_right

        pha
        lda  3,s
        tax
        inx
        inx
        tax
        jsr  :enqueue_blk
        pla
:skip_top_right

        bit  #$0003
        beq  :skip_top_left

        lda  1,s
        tax
        jsr  :enqueue_blk
:skip_top_left

        pla                       ; pop the base address off
        brl  :done

; Pass in PPU address in X register
:enqueue_blk
        jsr  :enqueue
        inx
        jsr  :enqueue
        txa
        clc
        adc  #32
        tax
        jsr  :enqueue
        dex
        jmp  :enqueue

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

decborder
        php
        sep  #$20
        ldal $E0C034
        dec
        eorl $E0C034
        and  #$0F
        eorl $E0C034
        stal $E0C034
        plp
        rts

setborder
        php
        sep  #$20
        eorl $E0C034
        and  #$0F
        eorl $E0C034
        stal $E0C034
        plp
        rts

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

; Allow the second sprite palette to set set by the ROM in world 4 because it switched to the bowser
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

; Trigger a copy from a page of memory to OAM.  Since this is a DMA operation, we can cheat and do a 16-bit copy
PPUDMA_WRITE ENT
        rtl
        php
        pha

        rep  #$30
]n      equ   0
        lup   128
        lda   ROMBase+$200+]n
        stal  PPU_OAM+]n
]n      =     ]n+2
        --^
        sep #$30

        pla
        plp
        rtl

y_offset_rows equ 2
y_height_rows equ 25
y_offset equ {y_offset_rows*8}
y_height equ {y_height_rows*8}
max_nes_y equ {y_height+y_offset-8}

x_offset equ 16

; Scan the OAM memory and copy the values of the sprites that need to be drawn. There are two reasons to do this
;
; This code has an optimization that it directly scans the NES RAM that would be DMA copied into the PPU
; OAM space.  This is ok, because
;
; 1. The OAM DMA occurs in the NES ROM before running any game logic
; 2. This code is running after the prior ISR, so it is loically happening at the beginning of the next NMI
;
; When scanning the OAM values, sprites that are not visible for any number of reasons are skipped and the
; sprite's y-position is adjusted based on the GTE camera view.  This allow all of the shadowBitmap and
; shadow lits work to assume an index value of zero is the top of the active play field.
OAM_COPY    ds 256
spriteCount ds 0
            db 0                 ; Pad in case we can to access using 16-bit instructions

        mx   %00
scanOAMSprites
:top_line equ Tmp5
:bot_line equ Tmp6

; In order for the shadow bitmap to be zeroed based on the active playfield, we need to adjust the NES
; sprite y-coordinates by the designated top row of the NES graphics screen, and then add an additional
; adjustment for the position of the GTE rendering window within that vertical space

        lda  NesTop
        clc
        adc  YOrigin
        sta  :top_line
        
        lda  NesBottom
        clc
        adc  YOrigin
        sta  :bot_line

        sep  #$30

        ldx  #4                  ; Always skip sprite 0
        ldy  #0

:loop
;        lda    PPU_OAM,x         ; Y-coordinate
        ldal   ROMBase+$200,x
        cmp    :bot_line
        bcs    :skip
        cmp    :top_line
        bcc    :skip
        sbc    :top_line
        sta    OAM_COPY,y         ; Keep the adjusted coordinate

;        cmp    #max_nes_y+1      ; Skip sprites that are 
;        bcs    :skip
;        cmp    #y_offset
;        bcc    :skip

;        lda    PPU_OAM+1,x       ; $FC is an empty tile, don't draw it
        ldal   ROMBase+$201,x
        cmp    #$FC
        beq    :skip
        sta    OAM_COPY+1,y

;        lda    PPU_OAM+3,x       ; If X-coordinate is off the edge skip it, too.
        ldal   ROMBase+$203,x
        cmp    #255-8
        bcs    :skip

        rep    #$20
;        lda    PPU_OAM,x
;        ldal   ROMBase+$200,x
;        sta    OAM_COPY,y
;        lda    PPU_OAM+2,x
        ldal   ROMBase+$202,x
        sta    OAM_COPY+2,y
        sep    #$20

;        jsr    debug_values

        iny
        iny
        iny
        iny

:skip
        inx
        inx
        inx
        inx
        bne  :loop

        sty  spriteCount                     ; Count * 4
        rep  #$30
        rts

debug_values
; Debug APU values
         phy
         phx

         rep    #$30

         ldx    #0
         ldy    #$FFFF
         lda    APU_STATUS
         and    #$00FF
         jsr    DrawWord

         ldx    #8*160
         ldy    #$EEEE
         lda    APU_PULSE1_REG1
         jsr    DrawWord

         ldx    #16*160
         ldy    #$EEEE
         lda    APU_PULSE1_REG3
         jsr    DrawWord

         ldx    #24*160
         ldy    #$DDDD
         lda    APU_PULSE2_REG1
         jsr    DrawWord

         ldx    #32*160
         ldy    #$DDDD
         lda    APU_PULSE2_REG3
         jsr    DrawWord

         ldx    #40*160
         ldy    #$BBBB
         lda    APU_TRIANGLE_REG1
         jsr    DrawWord

         ldx    #48*160
         ldy    #$BBBB
         lda    APU_TRIANGLE_REG3
         jsr    DrawWord

; Fetch the ensoniq parameters

         sep    #$20
         ldal   irq_volume
         stal   $e1c000+sound_control     ; access registers
         
         lda    #$80+pulse1_oscillator    ; oscillator address
         stal   $e1c000+sound_address
         ldal   $e1c000+sound_data
         ldal   $e1c000+sound_data
         xba

         lda    #$40+pulse1_oscillator    ; oscillator volume
         stal   $e1c000+sound_address
         ldal   $e1c000+sound_data
         ldal   $e1c000+sound_data

         rep    #$30
         ldx    #{8*160}+{160-16}
         ldy    #$EEEE
         jsr    DrawWord

         sep    #$20
         lda    #$20+pulse1_oscillator    ; oscillator freq high
         stal   $e1c000+sound_address
         ldal   $e1c000+sound_data
         ldal   $e1c000+sound_data
         xba

         lda    #$00+pulse1_oscillator    ; oscillator freq low
         stal   $e1c000+sound_address
         ldal   $e1c000+sound_data
         ldal   $e1c000+sound_data

         rep    #$30
         ldx    #{16*160}+{160-16}
         ldy    #$EEEE
         jsr    DrawWord


         lda    #$80+pulse2_oscillator    ; oscillator address
         stal   $e1c000+sound_address
         ldal   $e1c000+sound_data
         ldal   $e1c000+sound_data
         xba

         lda    #$40+pulse2_oscillator    ; oscillator volume
         stal   $e1c000+sound_address
         ldal   $e1c000+sound_data
         ldal   $e1c000+sound_data

         rep    #$30
         ldx    #{24*160}+{160-16}
         ldy    #$DDDD
         jsr    DrawWord

         sep    #$20
         lda    #$20+pulse2_oscillator    ; oscillator freq high
         stal   $e1c000+sound_address
         ldal   $e1c000+sound_data
         ldal   $e1c000+sound_data
         xba

         lda    #$00+pulse2_oscillator    ; oscillator freq low
         stal   $e1c000+sound_address
         ldal   $e1c000+sound_data
         ldal   $e1c000+sound_data

         rep    #$30
         ldx    #{32*160}+{160-16}
         ldy    #$DDDD
         jsr    DrawWord

         sep    #$30
         plx
         ply
         rts

; Screen is 200 lines tall. It's worth it be exact when building the list because one extra
; draw + shadow sequence takes at least 1,000 cycles.
shadowBitmap    ds 32              ; Provide enough space for the full ppu range (240 lines) + 16 since the y coordinate can be off-screen

; A representation of the list as [top, bot) pairs
shadowListCount dw 0            ; Pad for 16-bit comparisons
shadowListTop   ds 64
shadowListBot   ds 64

        mx  %00
buildShadowBitmap

; zero out the bitmap (16-bit writes)
]n      equ   0
        lup   15
        stz   shadowBitmap+]n
]n      =     ]n+2
        --^

; Run through the list of visible sprites and ORA in the bits that represent them
        sep   #$30

        ldx   #0
        cpx   spriteCount
        beq   :exit

:loop
        phx

;        ldy   PPU_OAM,x
        ldy   OAM_COPY,x
;        cpy   #max_nes_y                  ; Don't increment something right on the edge (allows )
;        iny                               ; This is the y-coordinate of the top of the sprite

        ldx   y2idx,y                     ; Get the index into the shadowBitmap array for this y coordinate (y -> blk_y)
        lda   y2low,y                     ; Get the bit pattern for the first byte
        ora   shadowBitmap,x
        sta   shadowBitmap,x
        lda   y2high,y                    ; Get the bit pattern for the second byte
        ora   shadowBitmap+1,x
        sta   shadowBitmap+1,x

        plx
        inx
        inx
        inx
        inx
        cpx   spriteCount
        bcc   :loop

:exit
        rep   #$30
        rts

; Set the SCB values equal to the bitmap to visually debug
        ldx   ScreenTop
        ldy   #0
:vloop
        lda   #8
        sta   Tmp6
        lda   shadowBitmap,y
:iloop
        asl
        pha

        lda   #0
        rol
:zero   stal  $E19D00,x
        pla

        inx
        dec   Tmp6
        bne   :iloop

        iny
        cpy   ScreenRows
        bcc   :vloop

        rep   #$30
        rts

y2idx   const32 $00
        const32 $04
        const32 $08
        const32 $0C                ; 128 bytes
        const32 $10
        const32 $14
        const32 $18
        const32 $1C

; Repeating pattern of 8 consecutive 1 bits
y2low   rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01

y2high  rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE

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
;        cpy  #201
;        bcc  *+4
;        brk  $cc

        lda  shadowListTop,x
        and  #$00FF
        tax
;        cpx  #200
;        bcc  *+4
;        brk  $dd

        lda  #0                 ; Invoke the BltRange function
        jsl  LngJmp

        plx
        inx
        cpx  shadowListCount
        bcc  :loop
:exit
        rts

; Altername between BltRange and PEISlam to expose the screen
exposeShadowList
:last   equ  Tmp0
:top    equ  Tmp1
:bottom equ  Tmp2

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
        lda  #0
        jsl  LngJmp             ; Draw the background up to this range

        ldx  :top
        ldy  :bottom
        sty  :last              ; This is where we ended
        lda  #1
        jsl  LngJmp             ; Expose the already-drawn sprites

        plx
        inx
        cpx  shadowListCount
        bcc  :loop

:exit
        ldx  :last              ; Expose the final part
        ldy  ScreenHeight
        lda  #0
        jsl  LngJmp
        rts

; This routine needs to adjust the y-coordinates based of the offset of the GTE playfield within
; the PPU RAM
shadowBitmapToList
:top      equ  Tmp0
:bottom   equ  Tmp2
:bitfield equ  Tmp4

        sep  #$30

        ldx  #0                            ; List is zero-based to the active play field
        stz  shadowListCount  ; zero out the shadow list count

; This loop is called when we are not tracking a sprite range
:zero_loop
        ldy  shadowBitmap,x
        beq  :zero_next

        lda  mul8,x                           ; This is the scanline we're on (offset by the starting byte)
        clc
        adc  offset,y                         ; This is the first line defined by the bit pattern
        sta  :top
        bra  :one_next

:zero_next
        inx
        cpx  ScreenRows
        bcc  :zero_loop
        bra  :exit           ; ended while not tracking a sprite, so exit the function

:one_loop
        lda  shadowBitmap,x  ; if the next byte is all sprite, just continue
        cmp  #$FF
        beq  :one_next

; The byte has to look like 1...10...0*.  The first step is to mask off the high bits and store the result
; back into the shadowBitmap

        tay
        and  offsetMask,y
        sta  shadowBitmap,x

;        lda  {mul8-y_offset_rows},x
        lda  mul8,x
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
        cpx  ScreenRows

        bcc  :one_loop

; If we end while tracking a sprite, add to the list as the last item

        ldx  shadowListCount
        lda  :top
        sta  shadowListTop,x
        lda  ScreenHeight
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

; Helper to bounce into the function in the FTblPtr. See IIgs TN #90
LngJmp
        sty  FTblTmp
        asl
        asl
        tay
        iny
        lda  [FTblPtr],y
        pha
        dey
        lda  [FTblPtr],y
        dec
        phb
        sta  1,s
        ldy  FTblTmp          ; Restore the y register
        rtl

; Callback for the special VOC renderer
STATE_REG_R0W0         equ   160         ; R0W0
STATE_REG_BLIT         equ   161         ; Value used for blit (could be R0W0 or R0W1)
STATE_REG_R0W1         equ   163         ; R0W1

; Draw into the PEA field and then restore
nesRenderWithErase


nesRenderWithVOC
        phb
        phd

        phk
        plb

        pha                ; Save the phase indicator
        pei   124          ; RenderFlags

        tdc                ; Keep a copy of the second page of GTE direct page space
        clc
        adc   #$0100
        sta   GTE_DP2+1

        lda   DPSave
        tcd

; Save the pointer to the function table

        sty   FTblPtr
        stx   FTblPtr+2

        pla
        sta   RenderFlags
        pla

; Check what phase we're in
;
; Phase 1: A = 0
; Phase 2: A = 1

        cmp   #0
        bne   :phase2

        sei
        jsr   scanOAMSprites              ; Filter out any sprites that don't need to be drawn
        cli
        bra   :exit

; This is phase 1.  We draw the background into the non-displayed VOC bank and then draw sprites
; on top.  Pase 2 is trivial, just switch the VOC display bank to the other SHR page

:phase2
        lda   1,s                         ; This is the original direct page address
        tax

        sep   #$20
        lda   ActiveBank                  ; If we are currently showing the Bank 00, draw to Bank 01
        beq   :draw_aux
        ldal  STATE_REG_R0W0,x
        bra   :draw_done
:draw_aux
        ldal  STATE_REG_R0W1,x
:draw_done
        stal  STATE_REG_BLIT,x            ; Tell the blitter to draw into Bank 00
        rep   #$20

        ldx   #0                          ; Blast the whole background into the non-active bank
        ldy   ScreenHeight
        lda   #0
        jsl   LngJmp
        jsr   drawSprites                 ; Draw the sprites on top

        lda   ActiveBank
        beq   :show_aux
        jsr   _VOCShowMain
        bra   :done
:show_aux
        jsr   _VOCShowAux

:done
        lda   ActiveBank              ; Toggle to max this the active bank
        eor   #$0001
        sta   ActiveBank

:exit
        pld
        plb
        rtl


; Set the display banc for the VOC
_VOCShowMain
        sep   #$20
        lda   #$19
        stal  VOC_CONTROL_REG
        rep   #$20
        rts
_VOCShowAux
        sep   #$20
        lda   #$09
        stal  VOC_CONTROL_REG
        rep   #$20
        rts

; Callback entrypoint from the GTE renderer
drawOAMSprites
        phb
        phd

        phk
        plb

        pha                ; Save the phase indicator
        pei   124          ; RenderFlags

        tdc                ; Keep a copy of the second page of GTE direct page space
        clc
        adc   #$0100
        sta   GTE_DP2+1

        lda   DPSave
        tcd

; Save the pointer to the function table

        sty   FTblPtr
        stx   FTblPtr+2

        pla
        sta   RenderFlags
        pla

; Check what phase we're in
;
; Phase 1: A = 0
; Phase 2: A = 1

        cmp   #0
        bne   :phase2

; This is phase 1.  We will build the sprite list and draw the background in the areas covered by
; sprites.  This phase draws the sprites, too


; We need to "freeze" the OAM values, otherwise they can change between when we build the rendering pipeline

        sei
        jsr   scanOAMSprites              ; Filter out any sprites that don't need to be drawn
        cli

        jsr   buildShadowBitmap           ; Run though and quickly create a bitmap of lines with sprites
        jsr   shadowBitmapToList          ; Scan the bitmap and create (top, bottom) pairs of ranges

        jsr   drawShadowList              ; Draw the background lines that have sprite on them
        jsr   drawSprites                 ; Draw the sprites on top of the lines they occupy

        bra   :exit

; In Phase 2 we scan the shadow list and alternately blit the background in empty areas and
; PEI slam the sprite regions
:phase2
        jsr   exposeShadowList            ; Show everything on the SHR screen

; Return form the callback
:exit
        pld
        plb
        rtl

drawSprites
:tmp    equ   Tmp0

        sep   #$30          ; 8-bit cpu

; Run through the copy of the OAM memory

        ldx   #0
        cpx   spriteCount
        bne   oam_loop
        rep   #$30
        rts

        mx %11
oam_loop
        phx                  ; Save x

        lda   OAM_COPY,x     ; Y-coordinate (zero based to screen)
;        inc                  ; Compensate for PPU delayed scanline

        rep   #$30
        and   #$00FF
        asl
        asl
        asl
        asl
        asl
        sta  :tmp
        asl
        asl
        clc
        adc  :tmp
        clc
        adc  ScreenBase
        sta  :tmp

        lda  OAM_COPY+3,x
        lsr
        and  #$007F
        clc
        adc  :tmp
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

        phd
GTE_DP2 pea   $0000
        pld
        sec                          ; Select the secont bank of tiles
        jsr   drawTileToScreen
        pld

;drawTilePatch
;        jsl   $000000                ; Draw the tile on the graphics screen

        sep   #$30
        plx                          ; Restore the counter
        inx
        inx
        inx
        inx
        cpx   spriteCount
        bcc   oam_loop

        rep   #$30
        rts

; Custom tile blitter
;
; D = GTE blitter direct page space
; X = offset to the tile record
; 
        mx    %00

; Temporary tile space on the direct page
tmp_tile_data      equ 80

DP2_TILEDATA_AND_BANK01_BANKS equ 172

;USER_TILE_RECORD   equ  178
USER_TILE_ID       equ  178         ; copy of the tile id in the tile store
;USER_TILE_CODE_PTR equ  180         ; pointer to the code bank in which to patch
USER_TILE_ADDR     equ  184         ; address in the tile data bank (set on entry)
USER_FREE_SPACE    equ  186         ; a few bytes of scratch space

USER_SCREEN_ADDR   equ  190
USER_TEMP_0        equ  192
USER_TEMP_1        equ  194

LDA_IND_LONG_IDX equ $B7
ORA_IND_LONG_IDX equ $17

SHR_LINE_WIDTH equ 160

; Draw a tile to the graphics screen
;
; D = GTE Page 2
; X = tile address
; Y = screen address
; A = tile control bits; h ($0100), v ($0040) and palette select ($0006)
jne     mac
        beq   *+5
        jmp   ]1
        <<<

jeq     mac
        bne   *+5
        jmp   ]1
        <<<

NESDirectTileBlitter
        asl
        and   #$0146                 ; Set the vflip bit, priority, and palette select bit
        bcs   :no_mask
        jsr   drawTileToScreen       ; Just a shim since this function is called via JSL
        rtl
:no_mask
        clc
        jsr   drawTileToScreen2
        rtl

drawTileToScreen

        stx   USER_TILE_ADDR
        sty   USER_SCREEN_ADDR

        phb
        pei   DP2_TILEDATA_AND_BANK01_BANKS
        plb

        pha
        and   #$0006                             ; Isolate the palette selection bits

        sta   USER_FREE_SPACE
        lda   #0
        rol
        asl
        asl
        asl
        adc   USER_FREE_SPACE
        xba

        adcl  SwizzlePtr
        sta   USER_FREE_SPACE
        lda   #^AT1_T0                           ; Bank is a constant
        sta   USER_FREE_SPACE+2                  ; Set the pointer to the right swizzle table

        pla
        bit    #$0040
        beq    :no_prio
        bit    #$0100
        jeq    :drawPriorityToScreen
;        jmp    :drawPriorityToScreenV

:no_prio
        bit    #$0100
        jne    :drawTileToScreenV

; If we compile the sprites, then each word can be implemented as:
;
; x = screen address
;
; ldy  #LOOKUP_VAL          ; 3 constant 6-bit tile lookup value from NES CHR rom
; lda: 0,x                  ; 6
; and  #MASK                ; 3
; ora  [USER_FREE_SPACE],y  ; 7 lookup and merge in swizzled tile data = *(SwizzlePtr + palbits)
; sta: 0,x                  ; 6 = 25 cycles / word
;
; Current implementation below is 4+6+6+4+6+7+6 = 39 cycles
;
; Most tiles don't have 4 consecutive transparent pixels, but there will be some minor savings
; by avoiding those operations.  For MASK = $FFFF, the simplified code is and solid words are
; quite common, at least 25 - 30% of the words are solid.  So conservative estimate of
; 25 * 0.75 + 16 * 0.25 = ~22 cycles/word on average.  Throw in the 100% savings from MASK=0
; words and it's close to twice the speed of the current routine.
;
; ldy  #LOOKUP_VAL          ; 3 constant 6-bit tile lookup value from NES CHR rom
; lda  [USER_FREE_SPACE],y  ; 7 lookup and merge in swizzled tile data = *(SwizzlePtr + palbits)
; sta: 0,x                  ; 6 = 16 cycles / word

]line   equ   0
        lup   8
        ldx   USER_TILE_ADDR
        ldy:  {]line*4}+2,x                       ; Load the tile data lookup value
        lda:  {]line*4}+32+2,x                    ; Load the mask value
        ldx   USER_SCREEN_ADDR
        andl  $010000+{]line*SHR_LINE_WIDTH}+2,x  ; Mask against the screen
        db    ORA_IND_LONG_IDX,USER_FREE_SPACE    ; Insert the actual tile data
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

        ldx   USER_TILE_ADDR
        ldy:  {]line*4},x                       ; Load the tile data lookup value
        lda:  {]line*4}+32,x                    ; Load the mask value
        ldx   USER_SCREEN_ADDR
        andl  $010000+{]line*SHR_LINE_WIDTH},x  ; Mask against the screen
        db    ORA_IND_LONG_IDX,USER_FREE_SPACE    ; Insert the actual tile data
        stal  $010000+{]line*SHR_LINE_WIDTH},x

]line   equ   ]line+1
        --^

        plb
        plb                        ; Restore initial data bank
        rts

:drawTileToScreenV
]line   equ   0
        lup   8
        ldx   USER_TILE_ADDR
        ldy:  {]line*4}+2,x                       ; Load the tile data lookup value
        lda:  {]line*4}+32+2,x                    ; Load the mask value
        ldx   USER_SCREEN_ADDR
        andl  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x  ; Mask against the screen
        db    ORA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data
        stal  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x

        ldx   USER_TILE_ADDR
        ldy:  {]line*4},x                       ; Load the tile data lookup value
        lda:  {]line*4}+32,x                    ; Load the mask value
        ldx   USER_SCREEN_ADDR
        andl  $010000+{{7-]line}*SHR_LINE_WIDTH},x  ; Mask against the screen
        db    ORA_IND_LONG_IDX,USER_FREE_SPACE    ; Insert the actual tile data
        stal  $010000+{{7-]line}*SHR_LINE_WIDTH},x

]line   equ   ]line+1
        --^

        plb
        plb                        ; Restore initial data bank
        rts

:drawPriorityToScreen
]line   equ   0
        lup   8
        ldx   USER_TILE_ADDR
        lda:  {]line*4}+32+2,x                      ; Save the inverted mask
        eor   #$FFFF
        sta   USER_TEMP_1

        ldy:  {]line*4}+2,x                         ; Load the tile data lookup value
        db    LDA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data

        ldx   USER_SCREEN_ADDR
        eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x
        sta   USER_TEMP_0

; Convert the screen data to a mask.  Zero in screen = zero in mask, else $F
        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
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
        eor   #$FFFF
        and   USER_TEMP_0
        and   USER_TEMP_1

        eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

        ldx   USER_TILE_ADDR
        lda:  {]line*4}+32,x                      ; Save the inverted mask
        eor   #$FFFF
        sta   USER_TEMP_1

        ldy:  {]line*4},x                         ; Load the tile data lookup value
        db    LDA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data

        ldx   USER_SCREEN_ADDR
        eorl  $010000+{]line*SHR_LINE_WIDTH},x
        sta   USER_TEMP_0

        ldal  $010000+{]line*SHR_LINE_WIDTH},x
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
        eor   #$FFFF
        and   USER_TEMP_0
        and   USER_TEMP_1

        eorl  $010000+{]line*SHR_LINE_WIDTH},x
        stal  $010000+{]line*SHR_LINE_WIDTH},x

]line   equ   ]line+1
        --^

        plb
        plb                        ; Restore initial data bank
        rts


;:drawPriorityToScreenV
;]line   equ   0
;        lup   8
;        ldx   USER_TILE_ADDR
;        lda:  {]line*4}plb
;        plb                        ; Restore initial data bank
;        rts+32+2,x                      ; Save the inverted mask
;        eor   #$FFFF
;        sta   USER_TEMP_1
;
;        ldy:  {]line*4}+2,x                         ; Load the tile data lookup value
;        db    LDA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data
;
;        ldx   USER_SCREEN_ADDR
;        eorl  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x
;        sta   USER_TEMP_0

; Convert the screen data to a mask.  Zero in screen = zero in mask, else $F
;        ldal  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x
;        bit   #$F000
;        beq   *+5
;        ora   #$F000
;        bit   #$0F00
;        beq   *+5
;        ora   #$0F00
;        bit   #$00F0
;        beq   *+5
;        ora   #$00F0
;        bit   #$000F
;        beq   *+5
;        ora   #$000F
;        eor   #$FFFF
;        and   USER_TEMP_0
;        and   USER_TEMP_1

;        eorl  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x
;        stal  $010000+{{7-]line}*SHR_LINE_WIDTH}+2,x

;        ldx   USER_TILE_ADDR
;        lda:  {]line*4}+32,x                      ; Save the inverted mask
;        eor   #$FFFF
;        sta   USER_TEMP_1

;        ldy:  {]line*4},x                         ; Load the tile data lookup value
;        db    LDA_IND_LONG_IDX,USER_FREE_SPACE      ; Insert the actual tile data

;        ldx   USER_SCREEN_ADDR
;        eorl  $010000+{{7-]line}*SHR_LINE_WIDTH},x
;        sta   USER_TEMP_0

;        ldal  $010000+{{7-]line}*SHR_LINE_WIDTH},x
;        bit   #$F000
;        beq   *+5
;        ora   #$F000
;        bit   #$0F00
;        beq   *+5
;        ora   #$0F00
;        bit   #$00F0
;        beq   *+5
;        ora   #$00F0
;        bit   #$000F
;        beq   *+5
;        ora   #$000F
;        eor   #$FFFF
;        and   USER_TEMP_0
;        and   USER_TEMP_1

;        eorl  $010000+{{7-]line}*SHR_LINE_WIDTH},x
;        stal  $010000+{{7-]line}*SHR_LINE_WIDTH},x
;]line   equ   ]line+1
        --^

;        plb
;        plb                        ; Restore initial data bank
;        rts

; Draw to the screen without any mask
drawTileToScreen2

        stx   USER_TILE_ADDR
        sty   USER_SCREEN_ADDR

        phb
        pei   DP2_TILEDATA_AND_BANK01_BANKS
        plb

        and   #$0006                             ; Isolate the palette selection bits

        sta   USER_FREE_SPACE
        lda   #0
        rol
        asl
        asl
        asl
        adc   USER_FREE_SPACE
        xba

        adcl  SwizzlePtr
        sta   USER_FREE_SPACE
        lda   #^AT1_T0                           ; Bank is a constant
        sta   USER_FREE_SPACE+2                  ; Set the pointer to the right swizzle table

;        brk   $55
        ldx   USER_SCREEN_ADDR
]line   equ   0
        lup   8
        ldy   #{]line*4}
        lda   (USER_TILE_ADDR),y
        tay
        db   LDA_IND_LONG_IDX,USER_FREE_SPACE
        stal $010000+{]line*SHR_LINE_WIDTH},x

        ldy   #{]line*4}+2
        lda   (USER_TILE_ADDR),y
        tay
        db   LDA_IND_LONG_IDX,USER_FREE_SPACE
        stal $010000+{]line*SHR_LINE_WIDTH}+2,x
]line   equ   ]line+1
        --^

        plb
        plb                        ; Restore initial data bank
        rts

; Assume that when the tile is updated, it includes a full 10-bit value with the 
; palette bits included with the lookup bits
;
; If we could compile all of the tiles, then the code becomes
; 
; ldy  #DATA
; lda  [USER_FREE_SPACE],y
; sta: code,x
;
; And we save _at_least_ 11 cycles / word. 6 + 7 + 4 + 4 + 6 = 27 vs 16.
;
; Also, by exposing/short-circuiting the draw_tile stuff to avoid the GTE tile queue, we significantly
; reduce overhead and probably solve the tile column bug.
NESTileBlitter
        lda  USER_TILE_ID
        and  #$0600                        ; Select the tile palette from the tile id
        clc
        adcl SwizzlePtr
        sta  USER_FREE_SPACE
        lda  #^AT1_T0
        sta  USER_FREE_SPACE+2

        ldx  USER_TILE_ADDR                ; Get the address of the tile (base only)
]line   equ  0
        lup  8
        ldy: {]line*4},x
        db   LDA_IND_LONG_IDX,USER_FREE_SPACE
        sta  tmp_tile_data+{]line*4}
        ldy: {]line*4}+2,x
        db   LDA_IND_LONG_IDX,USER_FREE_SPACE
        sta  tmp_tile_data+{]line*4}+2
]line   equ  ]line+1
        --^
        lda  #1                            ; Request tmp_tile_data be copied to tile store
        rtl
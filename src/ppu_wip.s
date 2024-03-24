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

; Helper to perform the essential functions of rendering a frame
_ppuctrl    ds  2
_ppuscroll  ds  2

        mx    %00

; Initialize any data structure and internal state for emulating the NES PPU
;
; Must return carry clear on success
PPUStartUp
        lda   CompileBank0+1            ; Patch some dispatch addresses with the tile compilation bank
        sta   patch0+2
        sta   patch1+2
        sta   patch2+2
        sta   patch3+2
        sta   patch4+2

        jsr   _InitPPUTileMapping       ; Set up the lookup tables in the PPU shadow RAM

        clc
        rts

; Set up the lookup table to map the PPU Nametable tiles to the PEA field.
;
; The mapping vary depending on whether horizontal or vertical mirroring is set up.
_InitPPUTileMapping
:row     equ  tmp3
:col     equ  tmp4
:ppuaddr equ  tmp5

; Run through the PEA field block addresses and then map the information to 
; the appropriate PPU Nametable locations

        stz  :row
        stz  :col

:loop
        jsr  :setHorizontalMirror

        lda  :col
        inc
        sta  :col
        cmp  #64                    ; There are two sets of 32 tiles each in the PEA field
        bcc  :loop

        stz  :col
        lda  :row
        inc
        sta  :row
        cmp  #30                    ; There are 30 rows of tiles
        bcc  :loop
        rts

; Load the information about the PEA tile at (:col, :row) and store it inthe appropriate PPU address location
:setHorizontalMirror

; First, do some pre-calculations that are the same regardless which nametable we're in

        lda  :row                    ; Multiple the row by 32
        asl
        asl
        asl
        asl
        tay                          ; Will use the for lookup later (line = row * 8)
        asl
        sta  :ppuaddr                ; Save

; Next, pick a routine to use based on which nametable the current tile is in

        lda  :col
        cmp  #32
        bcc  :left

        and  #$001F                  ; Clamp the address for nametable 1
        ora  :ppuaddr
        ora  #$2400                  ; Go to the second nametable
        sta  :ppuaddr
        bra  :common

:left
        ora  :ppuaddr                ; We already know the value is less than 32, merge with the base address
        ora  #$2000                  ; And set the offset to nametable 0
        sta  :ppuaddr

:common
        lda  :col
        asl
        asl
        tax                          ; Use this for a lookup
        clc
        lda  BTableLow,y             ; Load the base address of the PEA row
        adc  Col2CodeOffset+2,x      ; Combine with the current column (get the left half of the tile)
        ldx  :ppuaddr

        sep  #$20                         ; Switch to 8-bit mode to store the values
        stal PPU_MEM+TILE_ADDR_LO+$000,x  ; Store the low byte of the PEA tile address
        stal PPU_MEM+TILE_ADDR_LO+$800,x
        xba
        stal PPU_MEM+TILE_ADDR_HI+$000,x  ; Store the high byte of the PEA tile address
        stal PPU_MEM+TILE_ADDR_HI+$800,x

        lda  BTableHigh,y              ; Load the bank byte
        stal PPU_MEM+TILE_BANK+$000,x  ; Store it in the PPU bank (Nametable 1)
        stal PPU_MEM+TILE_BANK+$800,x  ; Store it in the PPU bank (Nametable 3)

        rep  #$21
        rts

; Sync a metatile value to the PPU data bank and to the code field
;
; This is called "sync" instead of "draw" because this routine takes care
; of updating the various shadow values in the PPU data base as well as
; actually drawing the tiles to the PEA field.
;
; There's a bit of nuance, too, because the bottow row of metatiles that corresponds
; to the top 4 bits of the PPU Attribute bytes does not actually exist and must
; be skipped.  This is detected by storing a zero in the TILE_BANK shadow memory
; since the PEA fields will never be allocated in Bank 00.
;
; X = PPU address of the top-left corner of the metatile
; A = Palette select value for all tiles
        mx    %10
SyncPPUMetatile

        stal PPU_MEM+ATTR_SHADOW+$00,x     ; Store the palette select bits in the shadow page of the PPU MEM bank ($6000 - $7FFF)
        stal PPU_MEM+ATTR_SHADOW+$01,x
        stal PPU_MEM+ATTR_SHADOW+$20,x
        stal PPU_MEM+ATTR_SHADOW+$21,x

        clc
        adc   SwizzlePtr+1                 ; Set the palette selection (used for all 4 tiles)
        sta   ActivePtr+1

        ldal  PPU_MEM+TILE_SHADOW+$00,x
;        ldal  PPU_MEM,x
        sta   patch1+2
        ldal  PPU_MEM+TILE_SHADOW+$01,x
;        ldal  PPU_MEM+1,x
        sta   patch2+2
        ldal  PPU_MEM+TILE_SHADOW+$20,x
;        ldal  PPU_MEM+32,x
        sta   patch3+2
        ldal  PPU_MEM+TILE_SHADOW+$21,x
;        ldal  PPU_MEM+33,x
        sta   patch4+2

        ldal  PPU_MEM+TILE_BANK,x     ; The tiles in the same row will have the same bank
        beq   bad_row2                ; The bottom metatile row is not defined

        phb                           ; Save the current bank

        pha                           ; Point to the PEA code bank
        plb

; Calculate a few values for the next row

        ldal  PPU_MEM+TILE_BANK+$20,x
        pha

        ldal  PPU_MEM+TILE_ADDR_HI+$20,x
        pha
        ldal  PPU_MEM+TILE_ADDR_LO+$20,x
        pha                                ; Push the address onto the stack directly instead of going through a 16-bit register

; Now get the values for the top two tiles

        ldal  PPU_MEM+TILE_ADDR_HI,x  ; Load the high byte for this tile address
        xba
        ldal  PPU_MEM+TILE_ADDR_LO,x  ; Load the low byte for this tile address
        tax

        rep   #$21                    ; 16-bit mode for the tile copy

patch1  jsl   $000000

        txa
        sec
        sbc   #6                      ; Move to the next PEA tile address
        tax

patch2  jsl   $000000

        plx                             ; Load up for the next row
        plb

patch3  jsl   $000000

        txa
        sec
        sbc   #6                      ; Move the the next PEA tile address
        tax

patch4  jsl   $000000

        plb                            ; Restore the original bank
        sep   #$20
bad_row2
        rts

; Draw an attribute from the PPU into the code field by updating any changed metatiles
;
; X = PPU attribute address
; A = Attribute value
; B = Attribute EOR value
;
; A = 8 bit, X/Y = 16bit on entry
        mx    %10
DrawPPUAttribute
        bra  :enter
:attr_diff ds 2
:attr_copy ds 2
:mt_base0    ds 2
:mt_base2    ds 2
:mt_base64   ds 2
:mt_base66   ds 2

:enter
        sta  :attr_copy             ; Keep a copy of the actual value
        xba
        sta  :attr_diff

; Since we are going to assume at least one of the metatile attributes have changed, caculate the PPU address
; of the upper-left tile of the metatiles corresponding to this attribute byte.

        rep  #$20
        txa                         ; Get the PPU attribute address ($2{n}C0 - $2{n+3}FF)
        and  #$003F                 ; Isolate the attribute offset
        asl                         ; x2 for indexing
        tay

        txa
        and  #$2C00                 ; Keep the nametable bits
        ora  :corner,y              ; Insert the relative offset within the nametable
        tax                         ; This is constant for the ATTR_SHADOW updates
        adc  #$0002                 ; adc #2 faster than two increments
        sta  :mt_base2              ; Calculate the other offsets while it's fast to do so
        adc  #$003E
        sta  :mt_base64
        adc  #$0002
        sta  :mt_base66
        sep  #$20

        lda  :attr_diff
        bit  #$03
        beq  :not_top_left

        lda  :attr_copy
        and  #$03
        asl
        jsr  SyncPPUMetatile

        lda  :attr_diff

:not_top_left
        bit  #$0C
        beq  :not_top_right

        ldx  :mt_base2
        lda  :attr_copy
        and  #$0C
        lsr
        jsr  SyncPPUMetatile

        lda  :attr_diff

:not_top_right
        bit  #$30
        beq  :not_bot_left

        ldx  :mt_base64
        lda  :attr_copy
        and  #$30
        lsr
        lsr
        lsr
        jsr  SyncPPUMetatile

        lda  :attr_diff

:not_bot_left
        bit  #$C0
        beq  :not_bot_right

        ldx  :mt_base66
        lda  :attr_copy
        and  #$C0                 ; This could be done with 4 ROL instructions instead
        lsr
        lsr
        lsr
        lsr
        lsr
        jsr  SyncPPUMetatile

:not_bot_right
        rts

; Draw a tile from the PPU into the code field
;
; X = PPU address
; A = Tile value
;
; A = 8 bit, X/Y = 16bit on entry
        mx    %10
DrawPPUTile
        sta   patch0+2                ; Put the tile ID into the page byte of the address

        clc
        ldal  PPU_MEM+ATTR_SHADOW,x   ; Load the palette select byte from shadow memory
        adc   SwizzlePtr+1
        sta   ActivePtr+1             ; Update the high byte of the active palette pointer

        ldal  PPU_MEM+TILE_BANK,x    ; Load the bank byte for tile
        beq   bad_tile               ; If the PPU address is in Attribute range, abort

        phb
        pha
        plb

        ldal  PPU_MEM+TILE_ADDR_HI,x ; Load the high byte for this tile address
        xba
        ldal  PPU_MEM+TILE_ADDR_LO,x ; Load the low byte for this tile address
        tax

        rep   #$21
patch0  jsl   $000000
        sep   #$20
        plb

bad_tile
        rts
        mx    %00

; Forward scan to mark all of the potential PPU addresses that will be updated
_UpdateShadowTiles
:nt_head   equ tmp3
:at_head   equ tmp4

        sep  #$20
        ldy  nt_queue_tail
        cpy  :nt_head                ; Are there any items on the queue?
        beq  :done                   ; No, so early exit

:loop
        ldx  nt_queue,y              ; Load the PPU address
        lda  nt_queue+2,y            ; Load the tile value
        stal PPU_MEM+TILE_SHADOW,x   ; Update the shadow memory (must happen here so value is valid for metatile update)
        lda  #1
        stal PPU_MEM+TILE_VERSION,x  ; Set a flag to track the render status of all potential tiles

        iny                          ; Go to the next queue entry (wish this could be faster...)
        iny
        iny
        iny
        cpy  #NT_QUEUE_SIZE
        bcc  *+5
        ldy  #0
        cpy  :nt_head
        bne  :loop
:done

; Do it again for the attributes (But don't update shadow memory)

        ldy  at_queue_tail
        cpy  :at_head
        beq  :done2

        lda  #1
:loop2
        ldx  at_queue,y
        stal PPU_MEM+TILE_VERSION,x        ; Mark the attribute byte ($2xC0-$2xFF) as dirty

        iny
        iny
        iny
        iny
        cpy  #AT_QUEUE_SIZE
        bcc  *+5
        ldy  #0
        cpy  :at_head
        bne  :loop2

:done2
        rep  #$20
        rts

; Render and clear the queues
;
; This is a subtly tricky routine.  The queues are filled from the ROM callbacks, which are executed from
; the VBL interrupt context.  That means the PPU_MEM and queues can change while we are executing this code.
;
; So what is the solution? We can't disable interrupts while the queues are drained because there could be
; hundreds of tiles to update and we would miss multiple VBL and ESQ interrupts.
;
; To solve this, the queues use a bit more memory and keep track of both the PPU address and the byte value.
; This allows the code to replay the PPU stores in order without worrying about the PPU_MEM being inconsistent.
; It is still necessary to write values to PPU_MEM from the interrupt callbacks, because the ROM code could
; always perform a PPU_READ to get a value back.  However, the shadow Nametable and Attribute RAM stored in the
; PPU bank are only updated as the queues are read.
;
; To avoid unecessary rendering, the queues are processed in reverse order so that only the most recent
; PPU writes are acted upon.  A lookup table is marked as each byte is updates so any redundent PPU writes
; can be skipped.
;
; The Attribute queue is processed first because each attribute change will require between 4 and 16 tiles
; to be redrawn and, since the attributes are often changed when tiles are drawn those tiles will likely
; appear on the Nametable queue as well and can then be skipped.

PPUFlushQueues
:nt_head   equ tmp3
:at_head   equ tmp4
:attr_diff equ tmp5
:attr_copy equ tmp6
:mt_base2  equ tmp7              ; metatile base PPU address
:ppu_addr  equ tmp8
:index     equ tmp9
:mt_base64 equ tmp10
:mt_base66 equ tmp11
:mt_base   equ tmp12

; First, do a fast forward scan through the nametable and attribute queue and get all of the
; tiles in the TILE_SHADOW table in sync with the PPU tiles up through the current
; frame.

        jsr  _UpdateShadowTiles

; Second, do a reverse scan through the attribute queue and update the attribute
; bytes in the TILE_SHADOW table and render the metatiles.  Also, mark which tiles
; are updated so we (a) don't update any uneccessary attributes and (b) don't draw
; tiles later that were already updated as part of the metatile update.

        ldy  :at_head               ; Start at the end of the queue (most recent data item)
        sep  #$20                   ; Start off in 8-bit mode
        brl  :at_loop_chk

:at_loop
        ldx  at_queue,y             ; Load the PPU attribute address

        ldal PPU_MEM+TILE_VERSION,x ; Load the version byte for this
        bne  *+5                    ; If it has not been processed, continue
        brl  :at_loop_chk           ; Otherwise skip to the next iteration
        lda  #0
        stal PPU_MEM+TILE_VERSION,x ; Mark this attribute byte as having been processed

        lda  at_queue+2,y           ; Load the PPU attribute value
        sta  :attr_copy             ; Keep a copy of the actual value
        eorl PPU_MEM+TILE_SHADOW,x  ; Get the bit difference from the previous applied value
        sta  :attr_diff

; Store the attribute into the shadow ram

        lda  :attr_copy
        stal PPU_MEM+TILE_SHADOW,x  ; Now that we have the diff, put the actual value into the TILE_SHADOW

;        stx  :ppu_addr              ; Save the PPU address for later
        sty  :index                 ; Save the Y-register for later

; Since we are going to assume at least one of the metatile attributes have changed, caculate the PPU address
; of the upper-left tile of the metatiles corresponding to this attribute byte.

        rep  #$20
        txa                         ; Get the PPU attribute address ($2{n}C0 - $2{n+3}FF)
        and  #$003F                 ; Isolate the attribute offset
        asl                         ; x2 for indexing
        tay

        txa
        and  #$2C00                 ; Keep the nametable bits
        ora  :corner,y              ; Insert the relative offset within the nametable
        sta  :mt_base               ; This is constant for the ATTR_SHADOW updates
        adc  #$0002
        sta  :mt_base2              ; Calculate the tile address offsets for the four
        adc  #$003E                 ; metatiles controlled by this attribute byte
        sta  :mt_base64
        adc  #$0002
        sta  :mt_base66
        sep  #$20

; Check to see if we're on the bottom row.  This row only has the top two metatiles.

        cpy  #$38*2
        bcs  :not_bot_right

; First, check the metatile bits in the attribute byte to see if a given metatile has changed its value
; from what is currently in the PPU Nametable RAM and what was last rendered into the PEA field.

        lda  :attr_diff
        bit  #$30
        beq  :not_bot_left

        ldx  :mt_base64
        lda  #0
        stal PPU_MEM+TILE_VERSION+$00,x
        stal PPU_MEM+TILE_VERSION+$01,x
        stal PPU_MEM+TILE_VERSION+$20,x
        stal PPU_MEM+TILE_VERSION+$21,x

        lda  :attr_copy
        and  #$30
        lsr
        lsr
        lsr
        jsr  SyncPPUMetatile

        lda  :attr_diff

:not_bot_left
        bit  #$C0
        beq  :not_bot_right

        ldx  :mt_base66
        lda  #0
        stal PPU_MEM+TILE_VERSION+$00,x
        stal PPU_MEM+TILE_VERSION+$01,x
        stal PPU_MEM+TILE_VERSION+$20,x
        stal PPU_MEM+TILE_VERSION+$21,x

        lda  :attr_copy
        and  #$C0                 ; This could be done with 4 ROL instructions instead
        lsr
        lsr
        lsr
        lsr
        lsr
        jsr  SyncPPUMetatile

        lda  :attr_diff

:not_bot_right
        bit  #$03
        beq  :not_top_left

; Metatile address is already in the X-register, so mark these tiles as
; being updates

        ldx  :mt_base
        lda  #0
        stal PPU_MEM+TILE_VERSION+$00,x
        stal PPU_MEM+TILE_VERSION+$01,x
        stal PPU_MEM+TILE_VERSION+$20,x
        stal PPU_MEM+TILE_VERSION+$21,x

; The first step is to calculate the tile select value and store that into the appropriate locations
; in a shadow table that is used by the low-level tile drawing code.

        lda  :attr_copy
        and  #$03
        asl
        jsr  SyncPPUMetatile

; Reload the attribute difference and proceed to the next metatile

        lda  :attr_diff

:not_top_left
        bit  #$0C
        beq  :not_top_right

        ldx  :mt_base2
        lda  #0
        stal PPU_MEM+TILE_VERSION+$00,x
        stal PPU_MEM+TILE_VERSION+$01,x
        stal PPU_MEM+TILE_VERSION+$20,x
        stal PPU_MEM+TILE_VERSION+$21,x

        lda  :attr_copy
        and  #$0C
        lsr
        jsr  SyncPPUMetatile

:not_top_right

; Restore the queue index

        ldy  :index

; This is where the loop starts.  If the queue is empty, then the first check will find that the
; front and back are equal, and do nothing.  Otherwise, the back must be beyond the front, so
; we can move to the next element (back--) and process it.
:at_loop_chk
        cpy  at_queue_tail       ; Have we reached the end of the attribute queue?
        beq  :at_done

        dey
        dey
        dey
        dey
        bpl  *+5
        ldy  #AT_QUEUE_SIZE-AT_ELEM_SIZE
        brl  :at_loop
:at_done

; Now that the queue has been drained, move the head index to the tail index position.  Since the
; head == tail, this will empty the queue.  If an interrupt has fired that extended the queue, the
; head will have moved and the tail is re-established

        ldy  :at_head
        sty  at_queue_tail

; Now, scan through the Nametable queue again and update anything that has a non-zero value in the
; TILE_VERSION lookup.  This routine runs back-to-front like the attribute processing and unlike the
; first pass over the Nametable queue.

        ldy  :nt_head
        brl  :nt_loop_chk

:nt_loop
        ldx  nt_queue,y

        ldal PPU_MEM+TILE_VERSION,x    ; If this byte is already marked, then continue
        beq  :nt_loop_chk
        lda  #0
        stal PPU_MEM+TILE_VERSION,x    ; Mark it as processed

        ldal PPU_MEM+TILE_SHADOW,x     ; Load the most recent value from the shadow memory
        phy                            ; Save the Y-register
        jsr  DrawPPUTile
        ply

:nt_loop_chk
        cpy  nt_queue_tail
        beq  :nt_done
        dey
        dey
        dey
        dey
        bpl  *+5
        ldy  #NT_QUEUE_SIZE-NT_ELEM_SIZE
        brl  :nt_loop
:nt_done

        ldy  :nt_head                  ; Move the tail of the queue up to the head
        sty  nt_queue_tail

        rep  #$30                      ; Restore 16-bit mode
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

        ldal PPU_MEM,x
        bra  :out

:buff_read
        lda  vram_buff  ; read from the buffer
        pha
        ldal PPU_MEM,x  ; put the data in the buffer for the next read
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


; This is the Nametable queue.  It records the data written to the PPU via the PPUDATA register.
NT_QUEUE_LEN      equ 4096                 ; Enough space for _every_ tile over multiple frames
NT_ELEM_SIZE      equ 4                    ; Each entry is 4 bytes
NT_QUEUE_SIZE     equ {NT_ELEM_SIZE*NT_QUEUE_LEN}
NT_QUEUE_MASK     equ {NT_QUEUE_SIZE-1}    ; Must be power of 2
NT_QUEUE_MAX      equ {NT_ELEM_SIZE*{NT_QUEUE_LEN-1}}
nt_queue_tail     dw  0
nt_queue_head     dw  0
nt_queue          ds  NT_QUEUE_SIZE        ; Each entry is a PPU address + byte

; This is the Attribute queue  It also records writes from PPUDATA in the Nametable Attribute
; part of memeory.  Because attribute changes have much more complexity, they are seggregated
; into a dedicated queue.
AT_QUEUE_LEN      equ 512                  ; Enough space for _every_ attribute byte
AT_ELEM_SIZE      equ 4
AT_QUEUE_SIZE     equ {AT_ELEM_SIZE*AT_QUEUE_LEN}
AT_QUEUE_MASK     equ {AT_QUEUE_SIZE-1}    ; Must be power of 2
AT_QUEUE_MAX      equ {AT_ELEM_SIZE*{AT_QUEUE_LEN-1}}
at_queue_tail     dw  0
at_queue_head     dw  0
at_queue          ds  AT_QUEUE_SIZE

; This is a temporary queue used while process Attribute writes.  When an attribute changes, up to 
; 16 tiles may be impacted.  The queue is set up to capture the set of affected tiles and makes sure
; that they are updates after the Nametable queue has been processed.
TMP_QUEUE_LEN     equ 960                  ; The attributes can affect at most this many tiles
TMP_ELEM_SIZE     equ 2                    ; We only save the PPU address
TMP_QUEUE_SIZE    equ {TMP_ELEM_SIZE*TMP_QUEUE_LEN}
tmp_queue_idx     dw  0
tmp_queue         ds  TMP_QUEUE_SIZE

PPUResetQueues
        stz   at_queue_head
        stz   at_queue_tail
        stz   nt_queue_head
        stz   nt_queue_tail
        rts

; This macro will slide the tail forward if the queue if full, e.g. the queue maintains at least
; the last N writes
;
; X = PPU address
; Y = PPU data
ATQueuePush mac
        sec
        lda  at_queue_head          ; Calculate the number of elements in the queue
        sbc  at_queue_tail
        and  #AT_QUEUE_MASK
        cmp  #AT_QUEUE_MAX          ; Are we at the queue's maximum?
        bcc  not_full
        jsr  incborder
        clc
        lda  at_queue_tail
        adc  #AT_ELEM_SIZE          ; Carry is clear from is_full test
        and  #AT_QUEUE_MASK
        sta  at_queue_tail
not_full
        tya
        ldy  at_queue_head
        sta  at_queue+2,y
        txa
        sta  at_queue,y

        tya
        adc  #AT_ELEM_SIZE          ; Carry is clear from is_full test
        and  #AT_QUEUE_MASK
        sta  at_queue_head
is_full
        <<<

NTQueuePush mac
        sec
        lda  nt_queue_head          ; Calculate the number of elements in the queue
        sbc  nt_queue_tail
        and  #NT_QUEUE_MASK
        cmp  #NT_QUEUE_MAX          ; Are we at the queue's maximum?
        bcc  not_full
        clc
        lda  nt_queue_tail
        adc  #NT_ELEM_SIZE          ; Carry is clear from is_full test
        and  #NT_QUEUE_MASK
        sta  nt_queue_tail
not_full
        tya
        ldy  nt_queue_head
        sta  nt_queue+2,y
        txa
        sta  nt_queue,y

        tya
        adc  #NT_ELEM_SIZE          ; Carry is clear from is_full test
        and  #NT_QUEUE_MASK
        sta  nt_queue_head
is_full
        <<<

; The ppu data can be written in any order -- in particular, the PPU Nametable Attribute bytes
; can be written after the tile data in the nametable.  On hardware, changing the attribute byte
; immediately updates the palette information for the tile metablock, but we need to redraw these
; tiles ourselves.
;
; So, we have to defer the drawing of tiles until after the ROM NMI routine is complete and
; we are ready to render a new frame.  To help with ordering, the attribute bytes are stored
; in a separate queue from the regular tile bytes.
;ppu_write_log_index dw 0
;ppu_write_log ds  3*1024

PPUDATA_WRITE ENT
        php
        phb
        phk
        plb
        pha                           ; We will abuse this location shortly...
        phx
        phy

        rep  #$10
        ldx  ppuaddr

        cpx  #$2000                   ; Restrict to the valid memory range.  May be able to remove
        bcc  :hop                     ; these checks if we put PPU memory into its own bank
        cpx  #$4000
        bcs  :hop

        ldal PPU_MEM,x                ; Load the old data byte
        eor  3,s                      ; Compare it to the new data byte
        beq  :hop                     ; Skip updating the underlying graphics if there is no change (A xor A = 0)

        xba                           ; Stash the XOR in the high byte of the accumulator (for attribute updates)
        lda  3,s                      ; Reload the original accumulator value
        stal PPU_MEM,x                ; Update PPU memory (8-bit write)

        cpx  #$3000                   ; Is it within the PPU nametables memory range?
        bcc  :in_nt

        rep  #$31                     ; Clear the carry, too
        txa
        adc  ppuincr
        and  #$3FFF
        sta  ppuaddr                  ; Advance to the new ppu address

; Since we've updated some PPU memory, we need to determine what area of memory it is in and
; take an appropriate action
;
; 1. In the range $2{x}00 to $2{x+3}BF -- this is tile data, so it should be queued for an update
; 2. In the range $2{x+3}C0 to $2{x+3}FF -- this is tile attribute data and should be put on a separate queue
; 3. In the range $3F00-$3FFF -- this is the palette range and executes a callback function to take a game-specific action

        cpx  #$3F00                   ; Is it within the PPU palette area?
        bcc  :hop2                    ; Nope, it's in no-man's land. Nothing to do.
        brl  :extra                   ; Yep, do the palette updates in a game-specific manner
:hop    brl  :nochange
:hop2   brl  :done
; The PPU wrote to some location in the Nametable RAM ($2000 - $2FFF).  Now we need to determine if it
; wrote to the nametable tile data area or the tile attribute area.  There are separate queues for each
; of these pieces of memory since each attribute byte afftect 16 tiles, it's important to process the
; attribute changes first to avoid having to redraw tiles since the IIgs does not have enough colors
; to direct support the palette indexes and has to redraw tiles when their palette changes.
:in_nt
        tay                           ; Keep a copy of the value in the Y-register (moved all 16-bits, even in 8-bit acc mode)

;        ldal PPU_MEM+TILE_VERSION,x
;        inc
;        stal PPU_MEM+TILE_VERSION,x

        rep  #$31                     ; Clear the carry, too
        txa
        adc  ppuincr
        and  #$3FFF
        sta  ppuaddr                  ; Advance to the new ppu address

;        phd                           ; Need some direct page info for rendering
;        lda   DPSave
;        pha
;        pld

        txa
        and  #$03C0                   ; Is this in the tile attribute space?
        cmp  #$03C0
        bcc  :not_attr

;        tya
;        sep  #$20
;        jsr  DrawPPUAttribute
        ATQueuePush
;        pld
        bra  :done

:not_attr
;        tya                           ; Get the tile value back into the accumulator
;        sep  #$20
;        jsr  DrawPPUTile
        NTQueuePush
;        pld
        bra   :done

:nochange
        rep  #$31
        txa
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

; Do some extra work to keep palette data in sync
;
; Based on the palette data that SMB uses, we remap the NES palette entries
; based on the AreaType, so most of the PPU writes are ignored.  However,
; we do update some specific palette entries to support some color cycling effects
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
        ldal PPU_MEM+$3F00
        ldx  #0
        brl  extra_out

; Mirror for background color
ppu_3F10
        ldal PPU_MEM+$3F10
        ldx  #0
        brl  extra_out


; Tile palette 3, color 1
ppu_3F0D
        ldal PPU_MEM+$3F0D
        ldx  #2
        brl  extra_out

; Sprite Palette 0, color 1
ppu_3F11
        ldal PPU_MEM+$3F11
        ldx  #28
        brl  extra_out

ppu_3F13
        ldal PPU_MEM+$3F13
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

        ldal PPU_MEM+$3F15
        ldx  #8*2
        brl  extra_out
ppu_3F16
        lda  LastAreaType
        cmp  #CASTLE_AREA_TYPE
        bne  no_pal

        ldal PPU_MEM+$3F16
        ldx  #9*2
        brl  extra_out
ppu_3F17
        lda  LastAreaType
        cmp  #CASTLE_AREA_TYPE
        bne  no_pal

        ldal PPU_MEM+$3F17
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
;        rtl                         ; Cheat like crazy and pretend it didn't happen.  Read from $0200 directly when we render

        php
        pha

        rep  #$30                   ; Only copy from 63 sprites because we always skip sprite 0
]n      equ   1
        lup   63
        lda   ROMBase+$200+{]n*4}
        stal  PPU_OAM+{]n*4}
        lda   ROMBase+$202+{]n*4}
        stal  PPU_OAM+2+{]n*4}
]n      =     ]n+1
        --^
        sep #$30

        pla
        plp
        rtl

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
;         ldal   ROMBase+$0200,x    ; Copy the low word
         ldal   PPU_OAM,x
         inc                       ; Increment the y-coordinate to match the PPU delay
         sta    OAM_COPY,y

         eor    #$FC00             ; Is the tile == $FC? This is a blank tile in this ROM
         cmp    #$0100
         bcc    :skip

         and    #$00FF            ; Isolate the Y-coordinate
         cmp    #{max_nes_y-8}+1      ; Skip anything that is beyond this line
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

;         ldal   ROMBase+$0202,x    ; Copy the high word
         ldal   PPU_OAM+2,x
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

         sty   spriteCount           ; spriteCount * 4 for easy comparison later
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

; This step was done at the start of RenderFrame

; Step 2: Convert the bitmap to a list of (top, bottom) pairs in order to update the screen

        jmp   shadowBitmapToList

; Render the prepared frame date
drawScreen

; Step 1: Draw the PEA lines that have sprites on them

        jsr   _ShadowOff
        jsr   drawShadowList

; Step 2: Draw the sprites

        jsr   drawSprites
        jsr   _ShadowOn

; Step 3: Reveal the sprites and background using alternating render and PEI slams

        jmp   exposeShadowList
_DebugFlower
        phx
        phy

        lda  OAM_COPY+3,x
        and  #$00FF
        ldx  #8*160
        ldy  #$FFFF
        jsr  DrawByte

        lda  _ppuscroll+1
        and  #$00FF
        ldx  #0
        ldy  #$FFFF
        jsr  DrawByte

        lda  tmp1
        and  #$00FF
        ldx  #16*160
        ldy  #$FFFF
        jsr  DrawByte

        ply
        plx
        rts

drawSprites
:tmp    equ   tmp0

; Run through the copy of the OAM memory and render each sprite to the graphics screen.  Typically,
; shadowing is disabled during this routing.

        ldx   #0
        cpx   spriteCount
        bne   oam_loop
        rts

oam_loop
        phx                           ; Save x

; First, calculate the physical location on the SHR screen at which to draw the sprite

        lda   OAM_COPY,x              ; Y-coordinate
        and   #$00FF
        mul160 tmp0
        clc
        adc  #$2000-{y_offset*160}+x_offset
        sta  tmp0

; Convert the x-coordinate.

        sep  #$20
        lda  _ppuscroll+1
        and  #$01
        clc
        adc  OAM_COPY+3,x             ; X-coordinate (In NES pixels, need to convert to IIgs bytes)
        and  #$FE                     ; Mask before the shift so that we know a 0 goes into the carry
        ror
        rep  #$20
        and  #$00FF

;        lda  OAM_COPY+3,x
;        and  #$00FE
;        lsr

        sta  tmp1
        adc  tmp0                     ; Add to the base address calculated fom the Y-coordinate
        tay                           ; This is the SHR address at which to draw the sprite

; Debug data for sprite tile $D6 (fire flower)

        lda  OAM_COPY+1,x
        and  #$00FF
        cmp  #$00D6
        bne  :nodebug
        jsr  _DebugFlower
:nodebug

; Set the palette pointer for this sprite

        lda  OAM_COPY+1,x             ; Put attribute byte in the high byte
        and  #$0300
        ora  #$0400                   ; Select the second set of palettes
        asl
        adc  SwizzlePtr               ; Carry is clear from the asl
        sta  ActivePtr
        lda  SwizzlePtr+2
        sta  ActivePtr+2

; Calculate the address of the tile data

        lda  OAM_COPY,x
        and  #$FF00
        lsr
        sta  tmp0                     ; This is loaded in the draw routines

; Now, examine the other control bits.  We dispatch differently based on the herizontal flip, vertical
; flip and priority bits. when calling the rendering function, Y = screen address, X = tile data address

        lda  OAM_COPY+2,x
        and  #$00E0
        lsr
        lsr
        lsr
        lsr
        tax
        jmp  (drawProcs,x)

draw_rtn
        plx                           ; Restore the counter
        inx
        inx
        inx
        inx
        cpx   spriteCount
        bcc   oam_loop

        rts

drawProcs
        dw drawTileToScreen,drawTileToScreenP,drawTileToScreenH,drawTileToScreenPH
        dw drawTileToScreenV,drawTileToScreenPV,drawTileToScreenHV,drawTileToScreenPHV

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

; Define the opcodes directly so we can use then in a macro.  The brancket from long-indirect addressing, e.g. [],
; causes the macro processor to get confused since variables can be written as "]x"
LDA_IND_LONG_IDX equ $B7
ORA_IND_LONG_IDX equ $17

drawTileToScreenH

          lda   tmp0
          clc
          adc   #64
          sta   tmp0

drawTileToScreen

          sty   tmp1        ; screen address

          phb
          pea   #^tiledata
          plb

]line     equ   0
          lup   8

          ldx   tmp0
          ldy:  {]line*4},x                            ; Load the tile data lookup value
          lda:  {]line*4}+32,x                         ; Load the mask value
          ldx   tmp1
          andl  $010000+{]line*SHR_LINE_WIDTH},x       ; Mask against the screen
          db    ORA_IND_LONG_IDX,ActivePtr             ; Merge in the remapped tile data
          stal  $010000+{]line*SHR_LINE_WIDTH},x

          ldx   tmp0
          ldy:  {]line*4}+2,x
          lda:  {]line*4}+32+2,x
          ldx   tmp1
          andl  $010000+{]line*SHR_LINE_WIDTH}+2,x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line     equ   ]line+1
          --^

          plb
          plb
          jmp   draw_rtn

drawTileToScreenHV

          lda   tmp0
          clc
          adc   #64
          sta   tmp0

drawTileToScreenV

          sty   tmp1        ; screen address

          phb
          pea   #^tiledata
          plb

]line     equ   0
          lup   8

          ldx   tmp0
          ldy:  {{7-]line}*4},x
          lda:  {{7-]line}*4}+32,x
          ldx   tmp1
          andl  $010000+{]line*SHR_LINE_WIDTH},x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH},x

          ldx   tmp0
          ldy:  {{7-]line}*4}+2,x
          lda:  {{7-]line}*4}+32+2,x
          ldx   tmp1
          andl  $010000+{]line*SHR_LINE_WIDTH}+2,x
          db    ORA_IND_LONG_IDX,ActivePtr
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line     equ   ]line+1
          --^

          plb
          plb
          jmp   draw_rtn

drawTileToScreenPHV
drawTileToScreenPH

          lda   tmp0
          clc
          adc   #64
          sta   tmp0

drawTileToScreenPV
drawTileToScreenP

          sty   tmp1        ; screen address

          phb
          pea   #^tiledata
          plb

]line     equ   0
          lup   8

          ldx   tmp0
          lda:  {]line*4}+32,x                         ; load the mask and invert it
          eor   #$FFFF
          sta   tmp2

          ldy:  {]line*4}+0,x                          ; load the lookup value
          db    LDA_IND_LONG_IDX,ActivePtr             ; get the correct pixel data

          ldx   tmp1                                   ; Get the screen address
          eorl  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; save a blended value of the sprite and screen data
          sta   tmp3

; Alternative to use a full branching network to shave a few cycles off
;          bit   #$F000
;          beq   :m0xxx
;          bit   #$0F00
;          beq   :mF0xx
;          bit   #$00F0
;          beq   :mFF0x
;          bit   #$000F
;          beq   :mFFF0
;          lda   #$0000 1.5 * 16 = saves 24 cycles per sprite
;          bra   :out     ; 6 / 5 = ~ 5.5 cycles per pixel + 3 for branch, but can save EOR instruction, so a wash


          ldal  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; create mask where F = !0 and 0 = 0.
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
          eor   #$FFFF
          and   tmp2                                   ; AND against the inverted sprite mask
          and   tmp3                                   ; Apply mask to the blended pixel data

          eorl  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; flip tile pixels back to original value and let sprite pixels show
          stal  $010000+{]line*SHR_LINE_WIDTH}+0,x


          ldx   tmp0
          lda:  {]line*4}+32+2,x                         ; load the mask and invert it
          eor   #$FFFF
          sta   tmp2

          ldy:  {]line*4}+2,x                          ; load the lookup value
          db    LDA_IND_LONG_IDX,ActivePtr             ; get the correct pixel data

          ldx   tmp1                                   ; Get the screen address
          eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; save a blended value of the sprite and screen data
          sta   tmp3

          ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; create mask where F = !0 and 0 = 0.
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
          and   tmp2                                   ; AND against the inverted sprite mask
          and   tmp3                                   ; Apply mask to the blended pixel data
          eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; flip tile pixels back to original value and let sprite pixels show
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line     equ   ]line+1
          --^

          plb
          plb
          jmp   draw_rtn

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
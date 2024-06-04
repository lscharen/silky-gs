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

        lda   SpriteBank0+1             ; Patch some dispatch addresses with the sprite compilation bank
        sta   csd+2

        jsr   _InitPPUTileMapping       ; Set up the lookup tables in the PPU shadow RAM

        lda   #$FFFF                    ; Set initial palette values to out-of-range values
        ldx   #0
:loop
        stal  PPU_MEM+$3F00,x
        inx
        inx
        cpx   #$20
        bcc   :loop

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

        lda  :row
        stal PPU_MEM+TILE_ROW,x
        stal PPU_MEM+TILE_ROW+$800,x

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
        sta   patch1+2
        ldal  PPU_MEM+TILE_SHADOW+$01,x
        sta   patch2+2
        ldal  PPU_MEM+TILE_SHADOW+$20,x
        sta   patch3+2
        ldal  PPU_MEM+TILE_SHADOW+$21,x
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

        plx                           ; Load up for the next row
        plb

patch3  jsl   $000000

        txa
        sec
        sbc   #6                      ; Move the the next PEA tile address
        tax

patch4  jsl   $000000

        plb                           ; Restore the original bank
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

; Clear the tile bitmap
]n      equ   0
        lup   15
        stz   tileBitmap+]n
]n      =     ]n+2
        --^

        lda  #$0000                  ; Clear the upper and lower bytes of the accumuator.  Important for things like TAX in mixed 8/16 bit modes.
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

        ldal PPU_MEM+TILE_ROW,x
        tax                          ; The high byte of A must be zero.  Even though A is 8-bit, the full 16-bit value is copied to X
        lda  #$FF
        sta  tileBitmap,x

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
; PPU writes are acted upon.  A lookup table is marked as each byte is updated so any redundent PPU writes
; can be skipped.
;
; The Attribute queue is processed first because each attribute change will require between 4 and 16 tiles
; to be redrawn and, since the attributes are often changed when tiles are drawn those tiles will likely
; appear on the Nametable queue as well and can then be skipped.
;
; Finally, as each nametable address is processed, a bitmap is updated to record which lines have updated
; background tiles.  This is used by the dirty renderer to determine which lines actually need to be drawn
; on this frame.

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
; being updated

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

; Value to mask with ppumask to allow the runtime to override some bits
ppumask_override dw $FFFF

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
; 16 tiles may be impacted.  This queue is set up to capture the set of affected tiles and makes sure
; that they are updated after the Nametable queue has been processed.
;TMP_QUEUE_LEN     equ 960                  ; The attributes can affect at most this many tiles
;TMP_ELEM_SIZE     equ 2                    ; We only save the PPU address
;TMP_QUEUE_SIZE    equ {TMP_ELEM_SIZE*TMP_QUEUE_LEN}
;tmp_queue_idx     dw  0
;tmp_queue         ds  TMP_QUEUE_SIZE

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
; to directly support the palette indexes and has to redraw tiles when their palette assignment changes.
:in_nt
        tay                           ; Keep a copy of the value in the Y-register (moves all 16-bits, even in 8-bit acc mode)

        rep  #$31                     ; Clear the carry, too
        txa
        adc  ppuincr
        and  #$3FFF
        sta  ppuaddr                  ; Advance to the new ppu address

        txa
        and  #$03C0                   ; Is this in the tile attribute space?
        cmp  #$03C0
        bcc  :not_attr

        ATQueuePush
        bra  :done

:not_attr
        NTQueuePush
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

; Do some extra work to keep palette data in sync. Because the IIgs palette is not
; large enough to accomodate all of the possible on-screen colors (16 colors vs 25 colors),
; palette handling is always a per-game issue.
;
; The only default behavior is writing the background color, which is always mapped to
; palette index 0 for convenience.

        mx   %00
:extra
        txa
        and  #$001F
        asl
        tax
        jsr  (PPU_PALETTE_DISPATCH,x)
        sep  #$30
        ply
        plx
        pla
        plb
        plp
        rtl

        mx   %00
; Background color
ppu_3F00  ldal PPU_MEM+$3F00
          stal $E19E00
          rts

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
ppu_3F0D
ppu_3F0E
ppu_3F0F  rts

ppu_3F10  ldal PPU_MEM+$3F10
          jsr  NES_ColorToIIgs
          stal $E19E00
          rts
ppu_3F11
ppu_3F12
ppu_3F13

ppu_3F14
ppu_3F15
ppu_3F16
ppu_3F17

ppu_3F18
ppu_3F19
ppu_3F1A
ppu_3F1B

ppu_3F1C
ppu_3F1D
ppu_3F1E
ppu_3F1F rts

        mx   %11
* ; Trigger a copy from a page of memory to OAM.  Since this is a DMA operation, we can cheat a little and do a 16-bit copy
PPU_OAM equ 0                       ; direct page base address
PPUDMA_WRITE ENT
        DO DIRECT_OAM_READ
        rtl                         ; Cheat a lot and pretend it didn't happen.  Read from NES RAM directly when we render
        ELSE

        php
        pha

        rep #$30
        phd
        ldal  DP_OAM
        tcd

        DO  ALLOW_SPRITE_0
        lda   ROMBase+$200
        sta   PPU_OAM
        lda   ROMBase+$202
        sta   PPU_OAM+2
        FIN

]n      equ   1
        lup   63
        lda   ROMBase+$200+{]n*4}
        sta   PPU_OAM+{]n*4}
        lda   ROMBase+$202+{]n*4}
        sta   PPU_OAM+2+{]n*4}
]n      =     ]n+1
        --^

        pld
        sep #$30

        pla
        plp
        rtl
        FIN

; Alternate scanOAMSprites that unrolls the loop, uses exclusion tables and 8-bit operations
; to improve scanning speed

        mx   %00
scanOAMSprites2

        ldx    #0
        ldy    #0                   ; clear all 16-bits
        sep    #$30                 ; 8-bit registers

; Since it's rare that all 64 sprites are active, the code is
; slightly biased for fast skipping.  Most NES games place sprites
; that are not in use below the screen, so we try to do an early
; out by testing the vertical range first.  Also, the IIgs screen
; is shorted than the NES screen, so even more sprites are rejected
; quickly.

        ldx    PPU_OAM+1            ; check for tile exclusions = 10 cycles
        lda    y_exclude,x
        bne    next

        ldy    PPU_OAM              ; check for y exclusions = 10 cycles
        lda    tile_exclude,y
        bne    next

        rep    #$20                 ; = 18 cycles
        lda    PPU_OAM+2            ; push the OAM info in reverse order
        pha
        phx
        phy

        ldx    y2idx,y              ; load the byte index (0 - 30) for this coordinate = 32
        tya                         ; Use as a lookup
        asl
        tay                         ; this polluted the high byte of Y, but has no effect
        lda    y2bits,y             ; repeats every 8 words, so don't need a 16-bit index reg
        ora    shadowBitmap0,x      ; set the eight bits in the bitfield value across two bytes
        sta    shadowBitmap0,x

        sep    #$20                 ; about 70 cycles per sprite
next
        rts
y_exclude
tile_exclude


; Scan the OAM copy and start to build up the data structures for rendering the screen.
;
; The first step is building a bitmap of lines with sprites, which are used to segment
; the screen in the "sprite" and "background" runs.
;
; There are actually two bitmaps that are used on alternating calls.  If the screen is
; scrolling, or otherwise needs to be completely drawn, just the "current" bitmap is used.
; But if we the background is not changing, then the runtime can render only lines that
; have changes from one call to the next.

OAM_COPY      ds 256
spriteCount   dw 0
shadowBitmap0 ds 32                ; Bitmap to use when frameCount & 1 == 0
shadowBitmap1 ds 32                ; Bitmap to use when frameCount & 1 == 1
tileBitmap    ds 32                ; Bitmap that marks which rows had background tile updates

         mx   %00
scanOAMSprites

         lda   frameCount          ; Determine which bitmap to use for this frame
         bit   #$0001
         beq   *+5
         brl   useOtherBitmap

; This is the code path using shadowBitmap0

]n       equ   0
         lup   15
         stz   shadowBitmap0+]n
]n       =     ]n+2
         --^

         ldx   #{1-ALLOW_SPRITE_0}*4  ; Select 0 or 1 as the starting point
         ldy   #0                     ; This is the destination index

; Check if sprites are disabled

         lda   GTEControlBits
         and   #CTRL_SPRITE_ENABLE
         beq   :disabled

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

         asl
         tay                      ; We are drawing this sprite, so mark it in the shadow list
         ldx    y2idx,y           ; Get the index into the shadowBitmap array for this y coordinate (y -> blk_y)
         lda    y2bits,y          ; Get the bit pattern for the first byte
         ora    shadowBitmap0,x
         sta    shadowBitmap0,x

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
         cpx  #$0100
         bcc  :loop

         pld

:disabled
         sty   spriteCount           ; spriteCount * 4 for easy comparison later
         rts

; This is identical to the code aove, but we're using shadowBitmap1 instead
useOtherBitmap

]n       equ   0
         lup   15
         stz   shadowBitmap1+]n
]n       =     ]n+2
         --^

         ldx   #{1-ALLOW_SPRITE_0}*4  ; Select 0 or 1 as the starting point
         ldy   #0                     ; This is the destination index

         lda   GTEControlBits
         and   #CTRL_SPRITE_ENABLE
         beq   :disabled

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

         asl
         tay                      ; We are drawing this sprite, so mark it in the shadow list
         ldx    y2idx,y           ; Get the index into the shadowBitmap array for this y coordinate (y -> blk_y)
         lda    y2bits,y          ; Get the bit pattern for the first byte
         ora    shadowBitmap1,x
         sta    shadowBitmap1,x

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
         cpx  #$0100
         bcc  :loop

         pld

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
:bitmap   equ  tmp6

        ldx  #shadowBitmap0              ; select the bitmap array for this frame
        lda  frameCount
        bit  #$0001
        beq  *+5
        ldx  #shadowBitmap1
        stx  :bitmap

        sep  #$30

        ldy  #y_offset_rows               ; Start at the top of the physical screen and walk the bitmap for 25 bytes (200 lines of height)
        lda  #0
        sta  shadowListCount              ; zero out the shadow list count

; This loop is called when we are not tracking a sprite range
:zero_loop
        lda  (:bitmap),y
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
        lda  (:bitmap),y     ; if the next byte is all sprite, just continue
        cmp  #$FF
        beq  :one_next

* ; The byte has to look like 1..10..0  The first step is to mask off the high bits and store the result
* ; back into the shadowBitmap

        tax
        and  offsetMask,x
        sta  :bitfield
;        sta  (:bitmap),y

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
;        bra  :zero_loop


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

walk_top     equ tmp3
walk_bottom  equ tmp4
walk_curr    equ tmp5
walk_prev    equ tmp6

; Macro to walk a bitmap and execute a callback function for each range 
;
; WALK_BITMAP load;first;last;callback
;
; load:     code to get byte of the bitmap array; 32 bytes long (256 bits)
; first:    byte index to start scanning
; last:     byte index to stop scanning
; callback: label of the callback function.  top/bottom indices are in tmp0/tmp1 of direct page
LOAD_CURRENT mac
        lda  (walk_curr),y
        <<<

LOAD_INV_CURRENT mac
        lda  (walk_curr),y
        eor  #$FF
        <<<

; (prev | background) & ~current
;
; de Morgan: A & ~B = ~(~A | B)
LOAD_OTHERS mac
        lda  (walk_prev),y
        ora  tileBitmap,y
        eor  #$FF
        ora  (walk_curr),y
        eor  #$FF
        <<<

LOAD_INTERSECTION  mac
        lda  shadowBitmap0,y
        and  shadowBitmap1,y
        <<<

; Scan the bitmap list and execute a callback funtion on each 1->0 transition with the [start, finish) coordinates
; saved
WALK_BITMAP mac
        stz  walk_top
        stz  walk_bottom

        php                               ; Save the status flags
        sep  #$30                         ; Do everything in 8-bit mode

        clc                               ; Guarantee carry clear on entry
        ldy  #]2

; This loop is called when we are not tracking a range of ones
zero_loop
        ]1                                ; Load a new byte from the bitmap (nested macro)
zero_chk
        bne  not_zero                     ; If it's not zero, then start processing
        iny                               ; If it is zero, then move to the next byte
        cpy  #]3
        bcc  zero_loop

        plp                               ; Ended while not tracking ones, so exit the function
        rts

not_zero
        tax                               ; Keep a copy of the accumulator
not_zero0
        bpl  starting_zero                ; If the MSB is one, then the top line is aligned

        lda  {mul8-]2},y                  ; Just load the scanline.  The offset value will be zero
        sta  walk_top

        txa                               ; There are no leading zeros, so just keep the value as-is
        bra  one_chk

starting_zero

;        clc
        lda  {mul8-]2},y                  ; This is the scanline we're on (offset by the starting byte)
        adc  offset,x                     ; This is the first line defined by the bit pattern
        sta  walk_top

        lda  flipLeadingZeros,x           ; Fill the leading zeros with ones before moving to the next phase
        bra  one_chk                      ; See if we have to end within this byte, e.g. 11110000

; This loop is called when we are tracking a range of ones
one_loop
        ]1                                ; if the next byte is all sprite, just continue

one_chk                                   ; Skip the load if coming from a 0->1 transition
        cmp  #$FF
        bne  not_ones
        iny
        cpy  #]3
        bcc  one_loop

        lda  #y_height                    ; Hit the end of the list while tracking ones, so call
        sta  walk_bottom                  ; the action
        jsr  ]4

        plp
        rts

; The byte has to look like 1..10...  If the first byte was 0..01..10..., then the zero loop above 
; will have already filled it to 1..10...

not_ones
        tax
        bmi  starting_one

        lda  {mul8-]2},y
        sta  walk_bottom

        jsr  ]4                ; callback function must return with the carry clear

        txa
        bne  not_zero0         ; Don't do a useless branch to zero_chk, but inline a bit of that loop
        iny
        cpy  #]3
        bcc  zero_loop
        plp
        rts

starting_one
;        clc                   ; only come here if the value is not equal to $FF, so it must be less, thus carry is always clear
        lda  {mul8-]2},y
        adc  invOffset,x
        sta  walk_bottom

        jsr  ]4

; Loop back to check if there are more transitions on this byte

        lda  flipLeadingOnes,x
        bne  not_zero          ; Don't do a useless branch to zero_chk, but inline a bit of that loop
        iny
        cpy  #]3
        bcc  zero_loop
        plp
        rts
        <<<

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

; Update the minimal amount of the screen just based on what had changed from the prior
; frame.  We track three bitmaps of information that identify which lines different
; components are on.
;
; shadowBitmap0 and shadowBitmap1 track the lines that hold sprites from the previous
; and current frame. tileBitmap marks lines that had a tile updated since the last frame.
        mx   %00
drawDirtyScreen

; Put pointers to the "current" and "previous".  This could br optimized by maintaining
; these pointer in the app direct page and toggling them every time the frame counter is
; incremented

        lda   frameCount
        bit   #$0001
        bne   :odd
        lda   #shadowBitmap0
        sta   walk_curr
        lda   #shadowBitmap1
        sta   walk_prev
        bra   :even
:odd
        lda   #shadowBitmap0
        sta   walk_prev
        lda   #shadowBitmap1
        sta   walk_curr
:even

; Step 1: Draw the lines that had sprites on them and need to have sprites drawn
;         this frame.  This is shadowBitmap0 AND shadowBitmap1.  This is drawn with
;         shadowing off just to prep the screen.

        jsr   _ShadowOff
        jsr   clearPreviousSprites

; Step 2: Draw the sprites

        jsr   drawSprites
        jsr   _ShadowOn

; Step 3: This is different than the non-dirty case.  Because the background is presumed to
;         not be moving, we are not as constrained to do a single top-to-bottom wipe to minimize
;         tearing.  So, instead we do two separate passes to "erase" the lines that held preior
;         sprites, but are not in the current frame, plus the background lines.
;
;         The bitmap is (prev | background) & ~current

        jsr   drawOtherLines

; Step 4: This is the PEI Slam of the current sprites.

        jsr   exposeCurrentSprites
        rts

; Render the prepared frame date
drawScreen

; Step 0: Convert the bitmap into a list since it can be reused in Steps 1 and 3

        jsr   shadowBitmapToList

; Step 1: Draw the PEA lines that have sprites on them

        jsr   _ShadowOff
        jsr   drawShadowList

; Step 2: Draw the sprites

        jsr   drawSprites
        jsr   _ShadowOn

; Step 3: Reveal the sprites and background using alternating render and PEI slams

        jmp   exposeShadowList


sprTmp0      equ pputmp
sprTmp1      equ pputmp+2
sprTmp2      equ pputmp+4
sprTmp3      equ pputmp+6

drawSprites
;:spriteCount equ tmp4    ; tmp0 - tmp3 are used in the blitters
;:mul160      equ tmp8    ; Setting this to tmp5 causes problems -- need to investigate
:spriteCount equ pputmp+8
:mul160      equ pputmp+10
:cmplbank    equ pputmp+14  ; $0100 | ^tiledata

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

        lda   1,s                    ; Construct a work with Bank $01 and tilebank for 
        xba                          ; compiled sprites to quickly set and restore the
        ora   #$0001
        sta   :cmplbank

        plb

oam_loop
        phx                           ; Save x

; First, calculate the physical location on the SHR screen at which to draw the sprite

        ldal  OAM_COPY,x               ; Y-coordinate
        and   #$00FF
        asl
        tay
        lda  [:mul160],y
        adc  #$2000-{y_offset*160}+x_offset
        sta  sprTmp0

; Do some stuff faster in 8-bit mode

        sep  #$20

; Set the palette pointer for this sprite

        ldal OAM_COPY+2,x             ; Put attribute byte in the high byte
        and  #$03
        asl
        adc  SwizzlePtr2+1             ; Carry is clear from the asl
        sta  ActivePtr+1               ; Select the second set of palettes

; Convert the x-coordinate.

        ldal _ppuscroll+1
        and  #$01
        adcl OAM_COPY+3,x             ; X-coordinate (In NES pixels, need to convert to IIgs bytes)
        and  #$FE                     ; Mask before the shift so that we know a 0 goes into the carry
        ror                           ; Rotate to bring the carry into the high bit in case of overflow
        rep  #$20
        and  #$00FF
        adc  sprTmp0                   ; Add to the base address calculated fom the Y-coordinate
        sta  sprTmp1                   ; This is the SHR address at which to draw the sprite

; This is the point to check if there is a compiled version of this sprite

        txy
        ldal OAM_COPY+1,x
        and  #$00FF
        asl
        tax
        ldal spr_comp_tbl,x
        beq  as_bitmap

; Vector through the compiled sprite table.  The compiled sprites are in a different bank, so just check
; for a sentinel value and manually jump into the compiled sprite code to avoid a double-jump and having to
; have a second jump table in the compile sprite code bank.

        tyx
        stal csd+1                     ; patch in the long address directly
        ldal OAM_COPY+2,x              ; abort if the sprite has the priority bit set
        bit  #$0020
        bne  cs_abort
        pei  :cmplbank
        plb
csd     jml  $00000

; Finish calculating the jump address. We dispatch differently based on the horizontal flip, vertical
; flip and priority bits. when calling the rendering function, Y = screen address, X = tile data address

as_bitmap
        tyx
        ldal OAM_COPY+2,x
cs_abort
        and  #$00E0
        lsr
        lsr
        lsr
        lsr
        tay

; Calculate the address of the tile data

        ldal OAM_COPY,x
        and  #$FF00
        lsr                           ; Each tile is 128 bytes of data
        sta  sprTmp0                  ; This is loaded in the draw routines

; Put the dispatch address back in X

        tyx
        jmp  (drawProcs,x)

draw_rtn2
        plb                           ; Return from compiled sprite
draw_rtn
        plx                           ; Restore the counter
        inx
        inx
        inx
        inx
        cpx   :spriteCount
        bcc   oam_loop

        plb
        plb

        rts

drawProcs
        dw drawTileToScreen,drawTileToScreenP,drawTileToScreenH,drawTileToScreenPH
        dw drawTileToScreenV,drawTileToScreenPV,drawTileToScreenHV,drawTileToScreenPHV

spr_comp_tbl ds 512,$00

; Draw a tile directly to the screen
;
; A = tile ID
; Y = screen address
; X = palette select 0,2,4,6
blitTile
        phb
        pea   #^tiledata
        plb

        cmp   #$0100
        xba
        ror
        sta   sprTmp0
        sty   sprTmp1

        txa
        sep  #$20
        clc
        adc  SwizzlePtr+1             ; Carry is clear from the asl
        sta  ActivePtr+1
        rep  #$20

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

        plb
        plb
        rts

; Define the opcodes directly so we can use then in a macro.  The bracket from long-indirect addressing, e.g. [],
; causes the macro processor to get confused since variables can be written as "]x"
LDA_IND_LONG_IDX equ $B7
ORA_IND_LONG_IDX equ $17

drawTileToScreenH

          lda   sprTmp0
;          clc              ; There are a series of zero shifts before calling into this routine
          adc   #64
          sta   sprTmp0

drawTileToScreen

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

          jmp   draw_rtn

drawTileToScreenHV

          lda   sprTmp0
;          clc
          adc   #64
          sta   sprTmp0

drawTileToScreenV

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

          jmp   draw_rtn

drawTileToScreenPHV
drawTileToScreenPH

          lda   sprTmp0
;          clc
          adc   #64
          sta   sprTmp0

drawTileToScreenPV
drawTileToScreenP

]line     equ   0
          lup   8

          ldx   sprTmp0
          lda:  {]line*4}+32,x                         ; load the mask and invert it
          eor   #$FFFF
          sta   sprTmp2

          ldy:  {]line*4}+0,x                          ; load the lookup value
          db    LDA_IND_LONG_IDX,ActivePtr             ; get the correct pixel data

          ldx   sprTmp1                                   ; Get the screen address
          eorl  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; save a blended value of the sprite and screen data
          sta   sprTmp3

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
          and   sprTmp2                                ; AND against the inverted sprite mask
          and   sprTmp3                                ; Apply mask to the blended pixel data

          eorl  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; flip tile pixels back to original value and let sprite pixels show
          stal  $010000+{]line*SHR_LINE_WIDTH}+0,x


          ldx   sprTmp0
          lda:  {]line*4}+32+2,x                         ; load the mask and invert it
          eor   #$FFFF
          sta   sprTmp2

          ldy:  {]line*4}+2,x                          ; load the lookup value
          db    LDA_IND_LONG_IDX,ActivePtr             ; get the correct pixel data

          ldx   sprTmp1                                ; Get the screen address
          eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; save a blended value of the sprite and screen data
          sta   sprTmp3

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
          and   sprTmp2                                ; AND against the inverted sprite mask
          and   sprTmp3                                ; Apply mask to the blended pixel data
          eorl  $010000+{]line*SHR_LINE_WIDTH}+2,x     ; flip tile pixels back to original value and let sprite pixels show
          stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

]line     equ   ]line+1
          --^

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
; ppu_queues.s - NT/AT Update Queues and Queue Processing
;
; Double-buffered nametable (NT) and attribute (AT) update queues that capture
; PPU tile and attribute writes made by the game ROM during NMI for deferred
; rendering.
;
; The queues are filled from the ROM callbacks, which run in the VBL interrupt
; context.  That means PPU_MEM and the queues can change while the main loop is
; draining them, so a simple single-buffer approach would produce torn frames.
;
; Solution: two parallel pairs of lists (curr and prev).  At the start of each
; render, scaffold.s atomically swaps curr↔prev (a few register moves with
; interrupts live).  PPUFreezeNametableUpdates then snapshots the prev lists
; into ATTR_SHADOW/TILE_SHADOW, PPUFlushQueuesAlt renders from those shadows,
; and by the time rendering finishes the ROM has been filling the new curr
; lists safely.
;
; The Attribute queue is processed first because each attribute change
; can force up to 16 tiles to be redrawn; tiles that were also touched by
; an attribute update carry a version stamp so the NT loop can skip them.
;
; Routines:
;   PPUFreezeNametableUpdates - Copy prev AT/NT queue entries into shadow RAM
;                               and bump PPU_VERSION.
;   PPUFlushQueuesAlt         - Render from the frozen shadows into the PEA
;                               field; sets tileBitmap dirty bits.
;   PPUResetQueues            - Reset all four queue head/tail pointers to
;                               their initial empty state (called at startup).

; ---------------------------------------------------------------------------
; Queue data structures
; ---------------------------------------------------------------------------

; Two arrays of nametable updates, split into attribute and tile addresses.
; A lookup table is maintained in order to track which nametable addresses
; have been updated over however many frames have elapsed since the last
; screen rendering, so there cannot be more than 1920 tile updates or 128
; attribute updates.
;
; The two arrays are maintained so that, when a render is triggered, the code
; can swap which list is the "active" list and then process the other list of
; updates without worrying about the ROM code mutating the data while it is
; being rendered.
NT_LIST_LEN        equ 1920                   ; 960 nametable entries per table, 2 tables
curr_nt_list_start dw 0                       ; These are on the direct page
curr_nt_list_end   dw 0
prev_nt_list_start dw {NT_LIST_LEN*2}
prev_nt_list_end   dw {NT_LIST_LEN*2}
nt_list            ds {NT_LIST_LEN*4}         ; Each list item is a 16-bit address and need space for two lists

AT_LIST_LEN        equ 128                    ; 64 attribute values per table, 2 tables
curr_at_list_start dw 0
curr_at_list_end   dw 0
prev_at_list_start dw {AT_LIST_LEN*2}
prev_at_list_end   dw {AT_LIST_LEN*2}
at_list            ds {AT_LIST_LEN*4}

; ---------------------------------------------------------------------------
; PPUFreezeNametableUpdates
; ---------------------------------------------------------------------------
; When this code is called, the pointers to the data structures used to track
; PPU updates have already been swapped, so nothing can be modified while
; processing.  The PPU state is a snapshot from the end of the last frame.

        mx  %00
PPUFreezeNametableUpdates

; TODO: If the saturation flag is set, then just copy all of the nametable and attribute data into the SHADOW
;       arrays. Not loading from at_list or nt_list saves at least 6 cycles plus a bit more if the loop is
;       parially unrolled.  The crossover point is ~2/3rds full.

        sep  #$20

        ldy  prev_at_list_start
        cpy  prev_at_list_end
        beq  :at_done
:at_loop
        ldx  at_list,y               ; get the address of the attribute byte

        ldal PPU_MEM,x               ; load the current value
        stal PPU_MEM+ATTR_SHADOW,x   ; use the attribute memory area of this block to cache the value

        iny
        iny
        cpy  prev_at_list_end
        bcc  :at_loop
:at_done

        ldy  prev_nt_list_start
        cpy  prev_nt_list_end
        beq  :nt_done
:nt_loop
        ldx  nt_list,y

        ldal PPU_MEM,x
        stal PPU_MEM+TILE_SHADOW,x

        iny
        iny
        cpy  prev_nt_list_end
        bcc  :nt_loop
:nt_done

; Increment the sentinel value for the TILE_VERSION memory

        lda  PPU_VERSION
        inc
        bne  :no_zero
        inc
:no_zero
        sta  PPU_VERSION

        rep  #$20
        rts


; ---------------------------------------------------------------------------
; PPUFlushQueuesAlt
; ---------------------------------------------------------------------------
; Flush out the update lists and render the PPU changes into the PEA field
; for display.  This routine can introspect the changes to determine what
; kind of approach to take in order to be more efficient.
;
; 1. If neither list has any changes, control falls through and returns immediately.
; 2. If there are only AT changes, only the tiles impacted by the attributes are rendered.
; 3. If there are only NT changes, no check for attribute-updated tiles is needed.
; 4. If both lists have changes, the AT list is processed first; NT tiles not already
;    updated by the AT pass are then rendered.
; 5. If the number of changes is large, all tiles are drawn without bookkeeping.

        mx    %00
PPUFlushQueuesAlt

; Clear the tile bitmap for the current frame.
]n      equ   0
        lup   30
        stz   tileBitmap+]n
]n      =     ]n+2
        --^

        sep  #$20
        ldy  prev_at_list_start
        cpy  prev_at_list_end
        beq  :nt_nocheck

:at_loop
        ldx  at_list,y

; This byte is being processed

        phy
        ldal PPU_MEM+ATTR_SHADOW,x        ; Load the temporary attribute byte
        jsr  RenderPPUAttr
        ply

        iny
        iny

        cpy  prev_at_list_end
        bne  :at_loop
        bra  :nt_check                    ; There was at least one attribute change, so check for redundent updates in the NT loop

; Render the tiles from the NT list without needing to check if it was already updated
:nt_nocheck
        ldy  prev_nt_list_start           ; get the base address of the list
        cpy  prev_nt_list_end
        beq  :nt_done

:nt_loop0
        ldx  nt_list,y

        phy
        lda  #0                           ; Clear the high byte
        xba
        ldal PPU_MEM+TILE_ROW,x           ; Get the screen row for this tile (0, 8, 16, ..., 200, 208, 216)

        tay
        lda  #$FF
        sta  tileBitmap,y                 ; Mark these 8 lines as dirty

        ldal PPU_MEM+TILE_SHADOW,x
        jsr  DrawPPUTile
        ply

        iny
        iny
        cpy  prev_nt_list_end
        bne  :nt_loop0
        bra  :nt_done

; Render the tiles from the NT, but check to see if they were already updated by the attributes list
:nt_check
        ldy  prev_nt_list_start           ; get the base address of the list
        cpy  prev_nt_list_end
        beq  :nt_done

:nt_loop
        ldx  nt_list,y

        phy
        lda  #0                           ; Clear the high byte
        xba
        ldal PPU_MEM+TILE_ROW,x           ; Get the screen row for this tile (0, 8, 16, ..., 200, 208, 216)

        tay
        lda  #$FF
        sta  tileBitmap,y                 ; Mark these 8 lines as dirty

        lda  _ppuversion
        cmpl PPU_MEM+TILE_VERSION1,x      ; Check if the attribute tile updates already drew this tile
        beq  :nt_loop_skip

        ldal PPU_MEM+TILE_SHADOW,x
        jsr  DrawPPUTile

:nt_loop_skip
        ply

        iny
        iny
        cpy  prev_nt_list_end
        bne  :nt_loop

:nt_done
        rep  #$20
        rts

; ---------------------------------------------------------------------------
; PPUResetQueues
; ---------------------------------------------------------------------------
        mx    %00
PPUResetQueues
        stz    curr_nt_list_start
        stz    curr_nt_list_end
        lda    #{NT_LIST_LEN*2}
        sta    prev_nt_list_start
        sta    prev_nt_list_end

        stz    curr_at_list_start
        stz    curr_at_list_end
        lda    #{AT_LIST_LEN*2}
        sta    prev_at_list_start
        sta    prev_at_list_end

        rts

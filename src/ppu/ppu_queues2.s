; ---------------------------------------------------------------------------
; PPUFreezeNametableUpdates
; ---------------------------------------------------------------------------
; When this code is called, the pointers to the data structures used to track
; PPU updates have already been swapped, so nothing can be modified while
; processing.  The PPU state is a snapshot from the end of the last frame.
;
; This is the simplified version where all CIRAM addresses can be added to the
; queue and they are scanned once to aggregate all tile updates based on just
; the attribute bytes.
;
; The TILE_VERSION table is also cleared inline.

        mx  %00
PPUFreezeNametableUpdates

        php
        sep  #$20

        ldy  prev_ciram_list_start
        cpy  prev_ciram_list_end
        beq  :done
:loop
        ldx  ciram_list,y            ; get the CIRAM address of the attribute byte

        lda  ciram_attr_index,x      ; get the attriute index of this address
        bmi  :is_attr                ; it is an attribute itself, so need to diff against previous attribute value

        tay                          ; this is a normal tile, so insert the bit into the attribute position
        lda  ciram_attr_bits,x
        ora  ciram_updates,y
        sta  ciram_updates,y

:is_attr
        and  #$7F
        tay
        lda   

        ldal CIRAM,x                 ; load the current value
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

        ldal CIRAM,x
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

        plp
        rts

; At this point we have a list of attribute indices with a bitmask marking which tiles need to be updated,
; so all that's left is to dispatch the bulk tile updates.  These updates a 1:1 with the backing data store
; and don't need to worry about nametable selection, mirroring or other details.



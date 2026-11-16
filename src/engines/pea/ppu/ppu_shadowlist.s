; ppu_shadowlist.s - Shadow bitmap list management
;
; Lookup tables, scanline list storage, and the routines that convert the
; sprite shadow bitmap to a compact list of scanline ranges and then consume
; that list during rendering.
;
; Separated from ppu.s to allow shadowBitmapToList to be unit-tested in isolation.

; A representation of the list as [top, bot) pairs
shadowListCount dw 0            ; Pad for 16-bit comparisons
shadowListTop   ds 64
shadowListBot   ds 64

; mul8 (bitmap steps -> scanlines) and the bit pattern tables offset, invOffset and offsetMask are
; in core/Data.s: read with 8-bit index registers, so kept page-aligned there


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

; Alternate between BltRange and PEISlam to expose the screen
;
; Bug in BF after running for a long period of time -- hits BRK $66
        mx   %00
exposeShadowList
        ldx  #0
        ldy  #y_height

; Expose the lines [X, Y) only.  The list must lie within the range (clipShadowList).
exposeShadowListRange
:last   equ  tmp3
:top    equ  tmp4
:bottom equ  tmp5
:end    equ  tmp6

        stx  :last
        sty  :end
        ldx  #0
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
        ldy  :end
        jmp  _BltRangeLite

; Clip the shadow list to the lines [A, X): ranges outside are dropped and the others are cut to fit,
; so a renderer that only sets up part of the code field never blits a line outside of it.
        mx   %00
clipShadowList
:first  equ  tmp6
:end    equ  tmp7

        sta  :first
        stx  :end
        ldx  #0                 ; Read index
        ldy  #0                 ; Write index
:loop   cpx  shadowListCount
        bcs  :done

        lda  shadowListBot,x
        and  #$00FF
        cmp  :first
        beq  :next              ; Ends at or above the first line
        bcc  :next
        cmp  :end
        bcc  *+4
        lda  :end
        sep  #$20
        sta  shadowListBot,y
        rep  #$20

        lda  shadowListTop,x
        and  #$00FF
        cmp  :end
        bcs  :next              ; Starts at or below the end
        cmp  :first
        bcs  *+4
        lda  :first
        sep  #$20
        sta  shadowListTop,y
        rep  #$20
        iny

:next   inx
        bra  :loop

:done   sty  shadowListCount
        rts

* ; Converts the shadow bitmap (shadowBitmap0) into a list of
* ; contiguous [top, bottom) scanline pairs in shadowListTop/shadowListBot.
* ; Processes y_height_rows bytes starting at byte index y_offset_rows.
        mx   %00
shadowBitmapToList
:top      equ  tmp0
:bottom   equ  tmp2
:bitfield equ  tmp4

        jsr  ensureShadowBitmap           ; (built on demand)

        sep  #$30

        ldy  #y_offset_rows               ; Start at the top of the physical screen and walk the bitmap for 25 bytes (200 lines of height)
        lda  #0
        sta  shadowListCount              ; zero out the shadow list count

; This loop is called when we are not tracking a sprite range
:zero_loop
        lda  shadowBitmap0,y
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
        lda  shadowBitmap0,y          ; if the next byte is all sprite, just continue
        cmp  #$FF
        beq  :one_next

* ; The byte has to look like 1..10..0  The first step is to mask off the high bits and store the result
* ; back into the shadowBitmap

        tax
        and  offsetMask,x
        sta  :bitfield

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

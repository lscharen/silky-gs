; scanline_bitmap.s - Scanline Bitmap Walker Macros
;
; This file defines the WALK_BITMAP macro and its associated load macros.
; Unlike the simple data-replication macros in ppu_macros.s, these macros
; generate actual 65816 code (instructions, labels, branches) at each
; invocation site.  They are kept here to make that distinction clear.
;
; The WALK_BITMAP macro scans the shadow/tile bitmaps (one bit per scanline,
; packed 8 bits per byte) looking for contiguous runs of set bits.  For each
; run it calls a user-supplied callback with the run's [top, bottom) scanline
; range in walk_top / walk_bottom on the direct page.  The callback must
; return with the carry clear.
;
; Usage:
;   WALK_BITMAP <load_macro>;<first_byte>;<last_byte>;<callback_label>
;
;   load_macro  - one of the LOAD_* macros below
;   first_byte  - starting byte index (e.g. y_offset_rows)
;   last_byte   - ending byte index, exclusive (e.g. y_ending_row)
;   callback    - subroutine invoked for each [top, bottom) range found
;
; Direct-page aliases (walk_top/walk_bottom/walk_curr/walk_prev) are defined in ppu.s
; because ppu.s is assembled before scanline_bitmap.s and forward references would
; cause phase errors.

; ---------------------------------------------------------------------------
; Load macros -- passed as the first argument to WALK_BITMAP
; ---------------------------------------------------------------------------

; Current frame sprite lines
LOAD_CURRENT mac
        lda  (CurrShadowBitmap),y
        <<<

LOAD_PREVIOUS mac
        lda  (PrevShadowBitmap),y
        <<<

; Inverse of current (lines WITHOUT sprites this frame)
LOAD_INV_CURRENT mac
        lda  (CurrShadowBitmap),y
        eor  #$FF
        <<<

; (prev | background) & ~current
; Lines that had sprites/tile-updates last frame but are clear this frame.
; de Morgan: A & ~B = ~(~A | B)
LOAD_OTHERS mac
        lda  (PrevShadowBitmap),y
        ora  tileBitmap,y
        eor  #$FF
        ora  (CurrShadowBitmap),y
        eor  #$FF
        <<<

; Lines that had sprites in BOTH the previous and current frame
LOAD_INTERSECTION  mac
        lda  shadowBitmap0,y
        and  shadowBitmap1,y
        <<<

; ---------------------------------------------------------------------------
; WALK_BITMAP -- inline bitmap range walker
; ---------------------------------------------------------------------------
;
; Scan bytes ]2 through ]3-1 of the bitmap selected by the ]1 load macro.
; For each contiguous run of 1 bits, call ]4 with:
;   walk_top    = first scanline of the run
;   walk_bottom = one past the last scanline of the run
;
; Called in 8-bit mode; carry guaranteed clear on entry to callback.

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

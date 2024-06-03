; Compile an 8x8 bitmap into executable code into the SpriteBank
;
; Y = address in the compile bank
; A = low address of bitmap
; X = high address of bitmap
;
; Algorithm is simple O(n^2), but there are only 16 words
;   Load first word
;   Emit a load instruction
;   Emit a store instruction
;   Mark word as done
;   Scan for any duplicate words and mark complete
;   Continue until no words are left
;
; This routine differs from the CompileTile routine a few way.  First, duplicate
; words that have a mask are cached to save the lookup time, but can't be used
; immediately.  Second, the compilation needs to produce vertical and horizontally
; flipped versions of the sprite, which take up more space.  So the compiled sprite
; actually has an 8-byte header with the offsets for each variant.
; Emitted code is:
;
;  ldy #data
;  lda $0000,x
;  and #mask
;  ora [ActivePtr],y
;  sta $0000,x
;
;  ldy #data
;  lda [ActivePtr],y
;  sta $0000,x
;
;  ...

BOTH_ADDR_OFFSET equ 14
HORZ_ADDR_OFFSET equ 22
VERT_ADDR_OFFSET equ 25

CompileSprite
:target equ tmp4
:source equ tmp5
:copy   equ tmp7
:flags  equ tmp8
:base   equ tmp9                 ; start of the sprite

; Sprite are called with OAM Byte 2 in the accumulator and X set to the sprite index. The
; direct page location sprTmp1 holds the SHR address.  The compiled sprite has an preamble
; that dispatches to the correct compiled tile based on the value in the accumulator
;
; This is the template code that each compiled sprite starts with
;
;            ldx   sprTmp1         ; 2 bytes
;            and   #$00C0          ; 3 bytes
;            beq   normal          ; 2 bytes
;            cmp   #$00C0          ; 3 bytes
;            bne   *+5             ; 2 bytes
;            jmp   both            ; 3 bytes
;            bit   #$0080          ; 3 bytes
;            beq   *+5             ; 2 bytes
;            jmp   horizontal      ; 3 bytes
;            jmp   vertical        ; 3 bytes = 26 bytes
; normal     ...
; horizontal ...
;            ...
;            jml   draw_rtn

        sty  :base               ; base address of the sprite
        tya
        clc
        adc  #26                 ; first byte after the preamble
        sta  :target             ; Pointer to the target code address

; Gerenate the preamble

        ldy  :base
        jsr  CompileSpritePreamble

; Build each sprite and insert it's address into the preamble code.  The normal sprite
; (no horizontal or vertical flip) doesn't need any patching because it's always located
; immediately after the preable

        ldy  :target
        jsr  CompileSpriteNormal

; Build the horizontally flipped version

        jsr  CompileSpriteHorz
        phy
        lda  :base
        clc
        adc  #HORZ_ADDR_OFFSET
        tay
        lda  1,s
        sta  [SpriteBank0],y
        ply

; Build the vertically flipped version

        jsr  CompileSpriteVert
        phy
        lda  :base
        clc
        adc  #VERT_ADDR_OFFSET
        tay
        lda  1,s
        sta  [SpriteBank0],y
        ply

; Build the vertically and horizontally flipped version

        jsr  CompileSpriteBoth
        phy
        lda  :base
        clc
        adc  #BOTH_ADDR_OFFSET
        tay
        lda  1,s
        sta  [SpriteBank0],y
        ply

; Return with the new address

        tya
        rts

CompileSpritePreamble

        lda  #$A6+{256*sprTmp1}  ; LDX dp
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$0029              ; AND #$00C0
        sta  [SpriteBank0],y
        iny
        lda  #$00C0
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$13F0              ; BEQ normal
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$00C9              ; CMP #$00C0
        sta  [SpriteBank0],y
        iny
        lda  #$00C0
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$03D0              ; BNE *+5
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$004C              ; JMP both
        sta  [SpriteBank0],y
        iny
        iny
        iny

        lda  #$0089              ; BIT #$0080
        sta  [SpriteBank0],y
        iny
        lda  #$0080
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$03F0              ; BEQ *+5
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$004C              ; JMP horizontal
        sta  [SpriteBank0],y
        iny
        iny
        iny

        lda  #$004C              ; JMP vertical
        sta  [SpriteBank0],y
        iny
        iny
        iny

        rts

CompileSpriteNormal
:target equ tmp4
:flags  equ tmp5

        ldy  :target             ; This is the pointer to the compilation bank address
        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated

; In this loop, Y and X always point to the compile bank address and data index, respectively

        ldx  #0
:loop
        lda  bit_mask,x          ; Get the flag for the current word
        and  :flags              ; Has this word already been generated?
        beq  :skip

        jsr  emit_op

:skip
        inx
        inx                      ; Advance to the next word
        cpx  #32
        bcc  :loop

:exit
        jmp  _EmitReturn

CompileSpriteHorz
:target equ tmp4
:flags  equ tmp5

        ldy  :target             ; This is the pointer to the compilation bank address
        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated

; In this loop, Y and X always point to the compile bank address and data index, respectively

        ldx  #64                 ; Move to the horizontal flipped data
:loop
        lda  bit_mask-64,x       ; Get the flag for the current word
        and  :flags              ; Has this word already been generated?
        beq  :skip

        jsr  emit_op

:skip
        inx
        inx
        cpx  #96
        bcc  :loop

:exit
        jmp  _EmitReturn

CompileSpriteVert
:target equ tmp4
:flags  equ tmp5

        ldy  :target             ; This is the pointer to the compilation bank address
        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated

; In this loop, Y and X always point to the compile bank address and data index, respectively

        ldx  #0
:loop
        lda  bit_mask,x          ; Get the flag for the current word
        and  :flags              ; Has this word already been generated?
        beq  :skip

        jsr  emit_op_flip

:skip
        inx
        inx                      ; Advance to the next word
        cpx  #32
        bcc  :loop

:exit
        jmp  _EmitReturn

CompileSpriteBoth
:target equ tmp4
:flags  equ tmp5

        ldy  :target             ; This is the pointer to the compilation bank address
        lda  #$FFFF
        sta  :flags              ; When this value is zero, all 16 words have been generated

; In this loop, Y and X always point to the compile bank address and data index, respectively

        ldx  #64
:loop
        lda  bit_mask-64,x       ; Get the flag for the current word
        and  :flags              ; Has this word already been generated?
        beq  :skip

        jsr  emit_op_flip

:skip
        inx
        inx                      ; Advance to the next word
        cpx  #96
        bcc  :loop

:exit
        jmp  _EmitReturn

_EmitReturn
        lda  #$005C           ; return instruction jumps back to draw_rtn
        sta  [SpriteBank0],y
        iny
        lda  #draw_rtn
        sta  [SpriteBank0],y
        iny
        iny
        lda  #^draw_rtn
        sta  [SpriteBank0],y
        iny

        rts

emit_op
        lda  #$00A0                 ; ldy #imm
        sta  [SpriteBank0],y
        iny
        lda  TileBuff,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  TileBuff+32,x            ; Check if the mask is zero of not
        beq  :no_mask

        lda  #$00BD                 ; lda abs,x
        sta  [SpriteBank0],y
        iny
        lda  word_addr,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$0029                 ; and #imm
        sta  [SpriteBank0],y
        iny
        lda  TileBuff+32,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$17+{ActivePtr*256}   ; ora [ActivePtr],y
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$009D                 ; sta abs,x
        sta  [SpriteBank0],y
        iny
        lda  word_addr,x
        sta  [SpriteBank0],y
        iny
        iny
        rts

:no_mask
        lda  #$B7+{ActivePtr*256}   ; lda [ActivePtr],y
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$009D                 ; sta abs,x
        sta  [SpriteBank0],y
        iny
        lda  word_addr,x
        sta  [SpriteBank0],y
        iny
        iny
        rts

emit_op_flip
        lda  #$00A0                 ; ldy #imm
        sta  [SpriteBank0],y
        iny
        lda  TileBuff,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  TileBuff+32,x            ; Check if the mask is zero or not
        beq  :no_mask_flip

        lda  #$00BD                 ; lda abs,x
        sta  [SpriteBank0],y
        iny
        lda  word_addr_flip,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$0029                 ; and #imm
        sta  [SpriteBank0],y
        iny
        lda  TileBuff+32,x
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$17+{ActivePtr*256}   ; ora [ActivePtr],y
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$009D                 ; sta abs,x
        sta  [SpriteBank0],y
        iny
        lda  word_addr_flip,x
        sta  [SpriteBank0],y
        iny
        iny
        rts

:no_mask_flip
        lda  #$B7+{ActivePtr*256}   ; lda [ActivePtr],y
        sta  [SpriteBank0],y
        iny
        iny

        lda  #$009D                 ; sta abs,x
        sta  [SpriteBank0],y
        iny
        lda  word_addr_flip,x
        sta  [SpriteBank0],y
        iny
        iny
        rts

; data tables for generating code
word_addr
        dw {0*SHR_LINE_WIDTH}+0
        dw {0*SHR_LINE_WIDTH}+2
        dw {1*SHR_LINE_WIDTH}+0
        dw {1*SHR_LINE_WIDTH}+2
        dw {2*SHR_LINE_WIDTH}+0
        dw {2*SHR_LINE_WIDTH}+2
        dw {3*SHR_LINE_WIDTH}+0
        dw {3*SHR_LINE_WIDTH}+2
        dw {4*SHR_LINE_WIDTH}+0
        dw {4*SHR_LINE_WIDTH}+2
        dw {5*SHR_LINE_WIDTH}+0
        dw {5*SHR_LINE_WIDTH}+2
        dw {6*SHR_LINE_WIDTH}+0
        dw {6*SHR_LINE_WIDTH}+2
        dw {7*SHR_LINE_WIDTH}+0
        dw {7*SHR_LINE_WIDTH}+2

word_addr_flip
        dw {7*SHR_LINE_WIDTH}+0
        dw {7*SHR_LINE_WIDTH}+2
        dw {6*SHR_LINE_WIDTH}+0
        dw {6*SHR_LINE_WIDTH}+2
        dw {5*SHR_LINE_WIDTH}+0
        dw {5*SHR_LINE_WIDTH}+2
        dw {4*SHR_LINE_WIDTH}+0
        dw {4*SHR_LINE_WIDTH}+2
        dw {3*SHR_LINE_WIDTH}+0
        dw {3*SHR_LINE_WIDTH}+2
        dw {2*SHR_LINE_WIDTH}+0
        dw {2*SHR_LINE_WIDTH}+2
        dw {1*SHR_LINE_WIDTH}+0
        dw {1*SHR_LINE_WIDTH}+2
        dw {0*SHR_LINE_WIDTH}+0
        dw {0*SHR_LINE_WIDTH}+2

bit_mask
        dw $8000,$4000,$2000,$1000,$0800,$0400,$0200,$0100,$0080,$0040,$0020,$0010,$0008,$0004,$0002,$0001
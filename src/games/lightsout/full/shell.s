;        .import main

;        .segment "HEADER"
;        .byte   "NES",$1a,$01,$01,$01,$00

;        .import __OAM_START__
;        .import srnd, rnd

;        .zeropage
        ;; Reserve 16 bytes for scratch space. This can be trashed by
        ;; any function call, potentially.
;scratch:
;        .res    16
;vstat:  .res    1
;frames: .res    1
;j0stat: .res    1
        use  nrom_128.cfg

ROMBase ENT

;        .bss
;        .align 128
        ds   $0300
vidbuf  ds   128

        ds   $8000-$380
        put  ../../../rom/rom_inject.s

;        .exportzp scratch, vstat, frames, j0stat
;        .export vidbuf

;        .code
        ds   \,$00
        ds   $F800-$8200
        org  $F800
reset   
;        sei
;        cld

;        ;; Wait two frames.
;        bit     $2002
;:       bit     $2002
;        bpl     :-
;:       bit     $2002
;        bpl     :-

        ;; Mask out sound IRQs.
        lda     #$40
        sta     $4017
        lda     #$00
        sta     $4010

        ;; Disable all graphics.
        sta     $2000
        sta     $2001

        ;; Clear out RAM.
        tax
:l0
;       sta     $000,x
;       sta     $100,x
        sta     $200,x
        sta     $300,x
        sta     $400,x
        sta     $500,x
        sta     $600,x
        sta     $700,x
        inx
        bne     :l0

        ;; Reset the stack pointer.
        dex
        txs

        ;; Clear out SPR-RAM.
        lda     #>__OAM_START__
        sta     $4014

        ;; Clear out the name tables at $2000-$2400.
        lda     #$20
        sta     $2006
        lda     #$00
        sta     $2006
        ldx     #$08
        tay
:l1     sta     $2007
        iny
        bne     :l1
        dex
        bne     :l1

        ;; Seed RNG.
        lda     #$01
        jsr     srnd

        ;; Basic init is over. Re-enable our IRQs and go to Main Program.
;        cli
        jmp     main

vblank  pha
        txa
        pha
        tya
        pha

        lda     #>__OAM_START__ ; Update sprite data
        sta     $4014

        bit     vstat
        bpl     :no_vram

        ;; Copy data out of video buffer into VRAM
        ldy     #$00
:lp     ldx     vidbuf,y
        beq     :done
        iny
        lda     vidbuf+1,y
        sta     $2006
        lda     vidbuf,y
        sta     $2006
        iny
        iny
:blk    lda     vidbuf,y
        sta     $2007
        iny
        dex
        bne     :blk
        beq     :lp
:done   stx     vstat

:no_vram
        lda     #$08            ; Reset scroll
        sta     $2005
        sta     $2005

        inc     frames          ; Bump frame counter
        jsr     rnd             ; Burn an RNG value

        ;; Read joystick
        ldx     #$01
        stx     $4016
        dex
        stx     $4016
        stx     j0stat
        ldx     #$08
:l3     lda     $4016
        lsr     a
        rol     j0stat
        dex
        bne     :l3

        pla
        tay
        pla
        tax
        pla
irq     rti

        put main.s
        put board.s
        put xorshift.s

        ds   \,$00
        ds   $FA
;        .segment "VECTORS"
        org  $FFFA
        dw   vblank,reset,irq
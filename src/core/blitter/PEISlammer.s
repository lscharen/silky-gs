; PEI Slammer: expose whole playfield lines from the shadow screen ($01/2000) to the SHR screen.
;
; PEI costs 6 cycles with a page-aligned direct page and 7 without.  Screen lines are 160 bytes apart,
; so the low byte of a line's address repeats every 8 lines (8 x 160 = 5 pages).  There is one unrolled
; chunk of code per line phase (absolute screen line mod 8), with the direct page set to the page of
; the line's words; a line that crosses a page boundary switches the direct page once in the middle.
; The chunks chain to the next phase through patched JMPs (to the next line, or to the line after next
; with CTRL_EVEN_RENDER), and the wrap from the last phase back to the first moves to the next block of
; 8 lines and opens an interrupt window.
;
; The phase constants assume the NES playfield: 128 bytes wide, starting at byte 16 of the SHR line
; (screen mode 2 and the other 128-byte modes).  _PEISlamPatch checks this.
;
; Registers inside the chunks: Y = 1280 x (absolute line / 8), the block's offset; X = lines left;
; carry clear (nothing here overflows 16 bits).
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200
            mx     %00
_PEISlam
:tmp        equ   tmp0

            cpx   #200
            bcc   *+4
            brk   $14
            cpy   #201
            bcc   *+4
            brk   $15

; Re-patch the chunk chain (and the state register values) when the render mode changes (before :tmp
; is used: the patch routine uses tmp0)

            lda   ControlBits
            and   #CTRL_EVEN_RENDER
            ora   #1                    ; (never 0, so the first call always patches)
            cmpl  peiMode
            beq   :mode_ok
            phx
            phy
            jsr   _PEISlamPatch
            ply
            plx
:mode_ok

            stx   :tmp       ; x must be less than y
            cpy   :tmp
            beq   :none
            bcs   *+3
:none       rts

            lda   ControlBits
            bit   #CTRL_EVEN_RENDER
            beq   :normal

            txa                         ; force starting line to the next even line, rounded up
            inc
            and   #$FFFE
            sta   :tmp
            tax

            tya                         ; Examples:
            dec                         ;   (0, 200) -> (0, 199)
            and   #$FFFE                ;   (1, 100) -> (2, 99)
            inc                         ;   (1, 99)  -> (2, 99)

            sec
            sbc   :tmp                  ; This is the adjusted difference

            bcs   *+3                   ; Can go negative when Y = X+1 and X is odd
            rts

            lsr
            inc                         ; Number of lines to slam
            bra   :begin

:normal     tya
            sec
            sbc   :tmp                  ; Number of lines to slam

:begin      sta   :tmp
            txa
            clc
            adc   ScreenY0              ; Absolute screen line of the first line
            pha
            clc                         ; Never write past the last screen line (the SCBs,
            adc   :tmp                  ; palettes and I/O space follow).  Checked once per
            cmp   #201                  ; call; the chunks don't check the stack.
            bcc   *+4
            brk   $85
            lda   1,s
            and   #$0007                ; Its phase selects the entry chunk
            asl
            tax
            ldal  peiChunkTbl,x
            stal  peiGo+1
            pla
            and   #$FFF8
            asl
            tax
            ldal  Mul160Tbl,x           ; 160 x (line & ~7) = 1280 x block
            tay
            ldx   :tmp                  ; Lines left

            phd                         ; The direct page and stack are restored on exit
            tsc
            stal  peiStkSave

            sep   #$20
            lda   STATE_REG_R1W1        ; (read before the direct page moves)
            sei
            stal  STATE_REG
            rep   #$21                  ; 16-bit, carry clear
peiGo       jmp   $0000

; Next block of 8 lines, with an interrupt window.  Falls into the phase 0 chunk.
peiWrap0
            tya
            adc   #1280
            tay
            sep   #$20
peiW0a      lda   #0                    ; R0W0 (patched)
            stal  STATE_REG
            rep   #$20
            ldal  peiStkSave
            tcs
            cli
            sei
            sep   #$20
peiW0b      lda   #0                    ; R1W1 (patched)
            stal  STATE_REG
            rep   #$21

; Phase 0: base $2010 (+ Y), one page
peiC0       tya
            adc   #$2010+127
            tcs
            tya
            adc   #$2000
            tcd
]dp         equ   $8E
            lup   64
            pei   ]dp
]dp         equ   ]dp-2
            --^
            dex
            beq   *+5
peiJ0       jmp   peiC1
            jmp   peiExit

; Phase 1: base $20B0, 24 words in page $21, 40 in page $20
peiC1       tya
            adc   #$20B0+127
            tcs
            tya
            adc   #$2100
            tcd
]dp         equ   $2E
            lup   24
            pei   ]dp
]dp         equ   ]dp-2
            --^
            tya
            adc   #$2000
            tcd
]dp         equ   $FE
            lup   40
            pei   ]dp
]dp         equ   ]dp-2
            --^
            dex
            beq   *+5
peiJ1       jmp   peiC2
            jmp   peiExit

; Phase 2: base $2150, one page
peiC2       tya
            adc   #$2150+127
            tcs
            tya
            adc   #$2100
            tcd
]dp         equ   $CE
            lup   64
            pei   ]dp
]dp         equ   ]dp-2
            --^
            dex
            beq   *+5
peiJ2       jmp   peiC3
            jmp   peiExit

; Phase 3: base $21F0, 56 words in page $22, 8 in page $21
peiC3       tya
            adc   #$21F0+127
            tcs
            tya
            adc   #$2200
            tcd
]dp         equ   $6E
            lup   56
            pei   ]dp
]dp         equ   ]dp-2
            --^
            tya
            adc   #$2100
            tcd
]dp         equ   $FE
            lup   8
            pei   ]dp
]dp         equ   ]dp-2
            --^
            dex
            beq   *+5
peiJ3       jmp   peiC4
            jmp   peiExit

; Phase 4: base $2290, 8 words in page $23, 56 in page $22
peiC4       tya
            adc   #$2290+127
            tcs
            tya
            adc   #$2300
            tcd
]dp         equ   $0E
            lup   8
            pei   ]dp
]dp         equ   ]dp-2
            --^
            tya
            adc   #$2200
            tcd
]dp         equ   $FE
            lup   56
            pei   ]dp
]dp         equ   ]dp-2
            --^
            dex
            beq   *+5
peiJ4       jmp   peiC5
            jmp   peiExit

; Phase 5: base $2330, one page
peiC5       tya
            adc   #$2330+127
            tcs
            tya
            adc   #$2300
            tcd
]dp         equ   $AE
            lup   64
            pei   ]dp
]dp         equ   ]dp-2
            --^
            dex
            beq   *+5
peiJ5       jmp   peiC6
            jmp   peiExit

; Phase 6: base $23D0, 40 words in page $24, 24 in page $23
peiC6       tya
            adc   #$23D0+127
            tcs
            tya
            adc   #$2400
            tcd
]dp         equ   $4E
            lup   40
            pei   ]dp
]dp         equ   ]dp-2
            --^
            tya
            adc   #$2300
            tcd
]dp         equ   $FE
            lup   24
            pei   ]dp
]dp         equ   ]dp-2
            --^
            dex
            beq   *+5
peiJ6       jmp   peiC7
            jmp   peiExit

; Phase 7: base $2470, one page
peiC7       tya
            adc   #$2470+127
            tcs
            tya
            adc   #$2400
            tcd
]dp         equ   $EE
            lup   64
            pei   ]dp
]dp         equ   ]dp-2
            --^
            dex
            beq   *+5
peiJ7       jmp   peiWrap0
            jmp   peiExit

; CTRL_EVEN_RENDER: the wrap from phase 7 continues at phase 1
peiWrap1
            tya
            adc   #1280
            tay
            sep   #$20
peiW1a      lda   #0                    ; R0W0 (patched)
            stal  STATE_REG
            rep   #$20
            ldal  peiStkSave
            tcs
            cli
            sei
            sep   #$20
peiW1b      lda   #0                    ; R1W1 (patched)
            stal  STATE_REG
            rep   #$21
            jmp   peiC1

peiExit
            sep   #$20
peiXa       lda   #0                    ; R0W0 (patched)
            stal  STATE_REG
            rep   #$20
            ldal  peiStkSave
            tcs
            cli
            pld
            rts

; Patch the state register values and the chunk chain for the render mode.  A = the mode key
; (CTRL_EVEN_RENDER | 1).  Uses tmp0.
            mx    %00
_PEISlamPatch
            phb
            phk
            plb
            sta   peiMode

            lda   ScreenWidth           ; The chunks are built for the 128-byte NES playfield
            cmp   #128
            bne   :bad
            lda   ScreenX0
            cmp   #16
            beq   :ok
:bad        brk   $16
:ok
            sep   #$20
            lda   STATE_REG_R0W0
            sta   peiW0a+1
            sta   peiW1a+1
            sta   peiXa+1
            lda   STATE_REG_R1W1
            sta   peiW0b+1
            sta   peiW1b+1
            rep   #$20

            lda   peiMode
            and   #CTRL_EVEN_RENDER
            beq   *+5
            lda   #16                   ; The even-mode targets
            clc
            adc   #14
            tax
            ldy   #14
:loop       lda   peiJmpTbl,y
            sta   tmp0
            lda   peiNextTbl,x
            sta   (tmp0)
            dex
            dex
            dey
            dey
            bpl   :loop

            plb
            rts

peiMode     dw    0                     ; CTRL_EVEN_RENDER | 1 of the current patches (0 = none yet)
peiStkSave  dw    0
peiChunkTbl dw    peiC0,peiC1,peiC2,peiC3,peiC4,peiC5,peiC6,peiC7
peiJmpTbl   dw    peiJ0+1,peiJ1+1,peiJ2+1,peiJ3+1,peiJ4+1,peiJ5+1,peiJ6+1,peiJ7+1
peiNextTbl  dw    peiC1,peiC2,peiC3,peiC4,peiC5,peiC6,peiC7,peiWrap0          ; Every line
            dw    peiC2,peiC3,peiC4,peiC5,peiC6,peiC7,peiWrap0,peiWrap1       ; CTRL_EVEN_RENDER

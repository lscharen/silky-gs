; Implementation of a PEI Slammer that updates a rectangular screen area.  The only tweak that
; this implementation does is that it does break up the slam into chunks of scan lines to allow
; time for interrupts to be serviced in a timely manner.
;
; This is a fairly basic slam in that it does not try to align the direct page.  To enhance the
; slammer, note that page-aligned addresses repeat every 8 scan lines and some lines would need
; to be split into two slams to keep the direct page aligned.
;
; At best, this saves 1 cycle per word, or 80 cycles for a full scanline
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200
            mx     %00
_PEISlam
:tmp        equ   tmp0

            cpx   #200
            bcc   *+4
            brk   $14
;                 rts
            cpy   #201
            bcc   *+4
            brk   $15
;                 rts

            stx   :tmp       ; x must be less than y
            cpy   :tmp
            bcs   *+3
            rts

            DO    DIRTY_RENDERING_VISUALS
; Set SCB values for debugging
            php
            phx
            phy
:dbg_loop
            sep  #$20
            lda  DebugSCB
            oral $E19D00,x
            stal $E19D00,x
            rep  #$30
            inx
            txa
            cmp  1,s
            bcc  :dbg_loop
            ply
            plx
            plp
            FIN

            lda   GTEControlBits
            bit   #CTRL_EVEN_RENDER
            beq   :normal

            txa                            ; force starting line to the next even line, rounded up
            inc
            and  #$FFFE
            sta  :tmp
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
            inc                         ; Halve the number of iterations

            tay

            lda   #320
            sta   :step+1                  ; double steps

            bra   :begin
:normal
            tya
            sec
            sbc   :tmp
            tay                    ; get the number of lines in the y register. This changes if we're in even mode
            lda   #160
            sta   :step+1
:begin

; Patch values because Direct Page is not available

            sep   #$20
            lda   STATE_REG_R0W0
            sta   :r0w0_p1+1
            sta   :r0w0_p2+1
            lda   STATE_REG_R1W1
            sta   :r1w1_p1+1
            rep   #$20

            lda   ScreenWidth
            dec
            sta   :screen_width_1  ; save the width-1 outside of the direct page

            lda   #:pei_end        ; patch the PEI entry address
            sec
            sbc   ScreenWidth
            sta   :inner+1

            txa
            asl
            tax
            lda   RTable,x         ; This is the right visible byte, so add one to get the 
            tax                    ; left visible byte (cache in x-reg)
            sec
            sbc   ScreenWidth
            inc

            phd                    ; save the current direct page and assign the base
            tcd                    ; screen address to the direct page register

            tsc
            sta   :stk_save        ; save the stack pointer to restore later

            clc                    ; clear before the loop -- nothing in the loop affect the carry bit
            brl   :outer           ; hop into the entry point.

]dp         equ   158
            lup   80               ; A full width screen is 160 bytes / 80 words
            pei   ]dp
]dp         equ   ]dp-2
            --^
:pei_end
            tdc                    ; Move to the next line
:step       adc   #160
            tcd
            adc   :screen_width_1
            tcs

            dey                    ; decrement the total counter, if zero then we're done
            beq   :exit

            cmp   #$9D00
            bcc   *+4
;                 beq   :exit
            brk   $85              ; Kill if stack is out of range

            dex                    ; decrement the inner counter.  Both counters are set
            beq   :restore         ; up so that they fall-through by default to save a cycle
                                   ; per loop iteration.

:inner      jmp   $0000            ; 25 cycles of overhead per line. A full width slam executes all
                                   ; 80 of the PEI instructions which we expect to take 7 cycles
                                   ; since the direct page is not aligned.  So total overhead is
                                   ; 25 / (25 + 7 * 80) = 4.27% of execution
                                   ;
                                   ; Without the interrupt breaks, we could remove the dex/beq test
                                   ; and save 4 cycles per loop which takes the overhead down to
                                   ; only 3.6%

:restore
            tsx                    ; save the current stack
            sep   #$20
:r0w0_p1    lda   #00              ; _R0W0
            stal  STATE_REG
            rep   #$20

            lda   :stk_save        ; give a few cycles to catch some interrupts
            tcs
            cli                    ; fall through here -- saves a BRA instruction

:outer
            sei
            txs                    ; set the stack address to the right edge
            ldx   #8               ; Enable interrupts at least once every 8 iterations
            sep   #$20
:r1w1_p1    lda   #00             ; _R1W1
            stal  STATE_REG
            rep   #$20
            bra   :inner

:exit
            sep    #$20
:r0w0_p2    lda    #00             ; _R0W0
            stal   STATE_REG
            rep    #$20

            lda    :stk_save
            tcs
            cli

            pld
            rts

:stk_save        ds    2
:screen_width_1  ds    2




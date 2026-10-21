; JoyProbes.s - read the game-port joystick from probes hooked into the PEA field
;
; An Apple II paddle is read by triggering its timer ($C070) and timing how long bit 7 of $C064 (X) /
; $C065 (Y) stays set.  Rather than spin, a few rows of the PEA field do it: the first row of a run (the
; strobe row) triggers the timers and records the time (VBL_VERT_REG: 2 scanlines, 127 us, per step);
; each probe row after it records the time and both timers' bits.  A sample is judged at the time it was
; taken, like the scanline interrupt reads below:
;
;   bit set at elapsed e:   the timer is longer than e   (lo = max(lo, e))
;   bit clear at elapsed e: the timer is at most e       (hi = min(hi, e))
;
; so the rows don't have to take the same time: shadow-off (sprite) rows, emulators and accelerators that
; run the rows faster only move the samples (and shorten how far a run reaches).
;
; The runs start at rows JOY_RUN_ROW_0 and JOY_RUN_ROW_1 of each blitter bank, right after an interrupt
; window, and probe every row up to the next one: interrupts are off for the whole run.  The code field runs with RAMWRT on (writes to bank $00 go to bank $01), so the probe code never
; writes the direct page: its samples go to JOY_DATA in the blitter bank itself (DBR in the code field).
; Each hooked row's probe code is in the unused start of its odd page (P1 $00 - $20) and ends with a JMP
; to the row's original exit target; the row's exits jump to it.
;
; The strobe row also sets Y = JOY_TOKEN, and a probe row only samples if Y is set: the code field never
; uses Y and _BltRangeLiteBody enters it with Y = 0, so a range that starts after a run's strobe row
; doesn't sample it (a range that ends inside a run keeps the samples taken).
;
; JoyInstallProbes (from _InitLiteBlitter, after it has set every exit) hooks the rows; JoyHarvest (end of
; RenderDraw) takes the first run with samples.  See plans/JOYSTICK_PROBE_PLAN.md.

; JoyInstallProbesL
;
; Hook the probe rows.  Called by _InitLiteBlitter after it has set every row's exits, so the exits are
; the plain next-row (or interrupt window) targets.  16-bit registers, D = the runtime's direct page.
            mx    %00
JoyInstallProbesL ENT
            DO    JOYSTICK_SUPPORT
            phb
            phk
            plb
            jsr   JoyInstallProbes
            plb
            FIN
            rtl

            DO    JOYSTICK_SUPPORT

JOY_STATS   equ   0                         ; Measurement counters (the JOYSTATS block below)

; Probe code templates.  Each is _JOY_CODE_SIZE bytes: the code, a JMP whose operand JoyInstallProbes
; sets, and padding (never executed).  The data operands are patched per row too.  They run in the code
; field: M = 1, X = 0, DBR = the blitter bank.  The ':' forces absolute addressing (JOY_DATA is below
; $100).

            mx    %10
joyTplStrobe
            ldal  $E0C070                   ; Trigger the paddle timers
            ldal  VBL_VERT_REG
joyTplStrobeT sta: JOY_DATA                 ; The start time
            ldy   #JOY_TOKEN                ; This range ran the strobe
joyTplStrobeJ jmp $0000
            ds    joyTplStrobe+_JOY_CODE_SIZE-*

joyTplProbe
            tya                             ; (JOY_TOKEN's low byte is not 0)
            beq   joyTplProbeJ              ; This range didn't run the strobe
            ldal  VBL_VERT_REG
joyTplProbeT sta: JOY_DATA                  ; The time
            ldal  $E0C064
            asl                             ; C = X running
            ldal  $E0C065
            ror                             ; Bit 7 = X running, bit 6 = Y running (the rest: floating bus)
joyTplProbeB sta: JOY_DATA                  ; The bits
joyTplProbeJ jmp $0000
            ds    joyTplProbe+_JOY_CODE_SIZE-*
            ERR   {*-joyTplStrobe}-{2*_JOY_CODE_SIZE}  ; A template is not _JOY_CODE_SIZE bytes


joyBank     dw    0                         ; Bank being hooked
joyRow0     dw    0                         ; Strobe rows of the two runs
joyRow1     dw    0
joyStep     dw    0                         ; 1, or 2 with CTRL_EVEN_RENDER
joyK        dw    0                         ; Probe rows per run
joyRun      dw    0                         ; The run's strobe row
joyRow      dw    0
joyData     dw    0                         ; The run's samples (JOY_DATA offset)
joyIdx      dw    0
joyTarget   dw    0

            mx    %00
JoyInstallProbes
            lda   joyEnabled                ; No player uses the joystick: the exits stay as they are
            bne   *+3
            rts
            lda   ControlBits
            bit   #CTRL_EVEN_RENDER
            bne   :even
            lda   #JOY_RUN_ROW_0
            sta   joyRow0
            lda   #JOY_RUN_ROW_1
            sta   joyRow1
            lda   #1
            sta   joyStep
            lda   #JOY_SAMPLES
            sta   joyK
            bra   :banks
:even       lda   #JOY_RUN_ROW_EVEN_0
            sta   joyRow0
            lda   #JOY_RUN_ROW_EVEN_1
            sta   joyRow1
            lda   #2
            sta   joyStep
            lda   #JOY_SAMPLES_EVEN
            sta   joyK

:banks      lda   #^lite_base_1
            sta   joyBank
            jsr   :bank
            lda   #^lite_base_2
            sta   joyBank

:bank       lda   joyRow0
            ldx   #JOY_DATA                 ; Slot 0
            jsr   :run
            lda   joyRow1
            ldx   #JOY_DATA+JOY_SLOT_SIZE   ; Slot 1

; A = the strobe row, X = the slot's data
:run        sta   joyRun
            sta   joyRow
            stx   joyData
            jsr   :strobe
            stz   joyIdx
:probe      lda   joyRow                    ; The next (executed) row
            clc
            adc   joyStep
            sta   joyRow
            lda   joyIdx                    ; The sample's data: 1 + 2 x index
            asl
            inc
            adc   joyData                   ; (carry clear)
            jsr   :sample
            inc   joyIdx
            lda   joyIdx
            cmp   joyK
            bcc   :probe
            rts

:ptr        equ   tmp10                     ; (and tmp11)
:dat        equ   tmp12

; Hook row joyRow as the strobe row (data at joyData)
:strobe     ldx   #joyTplStrobe
            jsr   :copy
            lda   joyData
            ldy   #_JOY_CODE_OFFSET+joyTplStrobeT+1-joyTplStrobe
            sta   [:ptr],y
            ldy   #_JOY_CODE_OFFSET+joyTplStrobeJ+1-joyTplStrobe
            bra   :link

; Hook row joyRow as a probe row (data at A: time, bits)
:sample     sta   :dat
            ldx   #joyTplProbe
            jsr   :copy
            lda   :dat
            ldy   #_JOY_CODE_OFFSET+joyTplProbeT+1-joyTplProbe
            sta   [:ptr],y
            inc
            ldy   #_JOY_CODE_OFFSET+joyTplProbeB+1-joyTplProbe
            sta   [:ptr],y
            ldy   #_JOY_CODE_OFFSET+joyTplProbeJ+1-joyTplProbe

; Y = the JMP operand's offset: it continues to the row's exit target, and the row's exits go to the probe
; code
:link       lda   joyTarget
            sta   [:ptr],y
            lda   :ptr
            clc
            adc   #_JOY_CODE_OFFSET
            ldy   #_E_JMP_OFFSET+1
            sta   [:ptr],y
            ldy   #_O_JMP_OFFSET+1
            sta   [:ptr],y
            rts

; Copy template X ($00 - $1F; its JMP operand's high byte at $20 is set by :link) to row joyRow of bank
; joyBank, and take the row's exit target (both exits go to the same place)
:copy       lda   joyRow
            xba                             ; x 256
            asl                             ; x 512 (_LINE_SPAN)
            clc
            adc   #lite_base_1              ; The row's P0 (both banks start their rows at the same offset)
            sta   :ptr
            lda   joyBank
            sta   :ptr+2
            ldy   #_E_JMP_OFFSET+1
            lda   [:ptr],y
            sta   joyTarget
            ldy   #_JOY_CODE_OFFSET
:copy_w     lda:  $0000,x
            sta   [:ptr],y
            inx
            inx
            iny
            iny
            cpy   #_JOY_CODE_OFFSET+$20
            bcc   :copy_w
            rts

; JoyHarvest
;
; Take the first run with samples since the last call (end of RenderDraw), in slot order: bank 1 slots 0
; and 1, then bank 2.  Its samples give each axis' interval [lo, hi] (joyPeaRes), for JoyGetPadL.  Taking
; a run clears every sample of every run, so the other runs of the same render are dropped (they are no
; newer).  After dirty renders (joySkipHarvest, set by JoyScanDisarm) the first full render's runs are
; dropped: a scanline-interrupt strobe can still have been timing when they strobed, and a timer that is
; running ignores a new trigger.  16-bit registers, DBR = this bank, D = the runtime's.
joyPeaRes   ds    4                         ; The last run taken: lo X, hi X, lo Y, hi Y (steps)
joyPeaReady dw    0                         ; Set when a run is taken, cleared by JoyGetPadL
joySkipHarvest dw 0
joyT0       dw    0                         ; The run being read: its start time
joyE        dw    0
joyBits     dw    0
joyLoX      dw    0
joyHiX      dw    0
joyLoY      dw    0
joyHiY      dw    0
joyValid    dw    0
joyLeftK    dw    0
joyMaxE     dw    0

            mx    %00
JoyHarvest
            lda   #JOY_DATA
            sta   tmp0
            lda   #^lite_base_1
            sta   tmp1
            sep   #$20
            mx    %10
            lda   joySkipHarvest
            bne   :skip
            ldy   #0                        ; Bank 1, slot 0
            jsr   :slot
            bcc   :take
            ldy   #JOY_SLOT_SIZE            ; Slot 1
            jsr   :slot
            bcc   :take
            lda   #^lite_base_2
            sta   tmp1
            ldy   #0
            jsr   :slot
            bcc   :take
            ldy   #JOY_SLOT_SIZE
            jsr   :slot
            bcc   :take
            rep   #$20
            mx    %00
            DO    JOY_STATS
            inc   jsRenders
            inc   jsRunsHist                ; No run published
            FIN
            rts

            mx    %10
:take       lda   joyLoX
            sta   joyPeaRes
            lda   joyHiX
            sta   joyPeaRes+1
            lda   joyLoY
            sta   joyPeaRes+2
            lda   joyHiY
            sta   joyPeaRes+3
            lda   #1
            sta   joyPeaReady
            jsr   :clear_all
            rep   #$20
            mx    %00
            DO    JOY_STATS
            inc   jsRenders
            inc   jsRunsHist+2              ; A run taken
            inc   jsValid
            lda   joyMaxE                   ; How far the run reached
            and   #$003F
            asl
            tax
            inc   jsHistE,x
            lda   joyLoX
            and   #$00FF
            cmp   #16
            bcc   *+5
            lda   #15
            asl
            tax
            inc   jsHistX,x
            lda   joyHiX
            and   #$00FF
            cmp   #16
            bcc   *+5
            lda   #15
            asl
            tax
            inc   jsHistY,x
            FIN
            rts

            mx    %10
:skip       stz   joySkipHarvest
            jsr   :clear_all
            rep   #$20
            mx    %00
            rts

; Clear the samples' times in both banks' slots
            mx    %10
:clear_all  lda   #^lite_base_1
            sta   tmp1
            jsr   :clear_bank
            lda   #^lite_base_2
            sta   tmp1
:clear_bank ldy   #1                        ; Slot 0's first sample's time
            jsr   :clear_slot
            ldy   #JOY_SLOT_SIZE+1
:clear_slot lda   #JOY_SAMPLES
            sta   joyLeftK
            lda   #0
:clear_s    sta   [tmp0],y
            iny
            iny
            dec   joyLeftK
            bne   :clear_s
            rts

; Read the run at Y (its offset in JOY_DATA): carry clear if it has samples, with the intervals in
; joyLoX / joyHiX / joyLoY / joyHiY.  8-bit A.
:slot       lda   [tmp0],y
            sta   joyT0
            iny                             ; The first sample
            lda   #0
            sta   joyLoX
            sta   joyLoY
            sta   joyValid
            sta   joyMaxE
            dec
            sta   joyHiX
            sta   joyHiY
            lda   joyK
            sta   joyLeftK
:sample     lda   [tmp0],y                  ; The time (0 = not sampled)
            beq   :next
            sec
            sbc   joyT0
            bcs   *+4
            adc   #131                      ; The counter wrapped (carry clear: adds 131)
            sta   joyE
            cmp   #JOY_MAX_E
            bcs   :next                     ; Can't be (an old sample)
            iny
            lda   [tmp0],y                  ; The bits
            dey
            sta   joyBits
            inc   joyValid
            lda   joyE
            cmp   joyMaxE
            bcc   *+5
            sta   joyMaxE

            bit   joyBits                   ; N = X running, V = Y running
            bpl   :x_low
            lda   joyE                      ; X running: lo = max(lo, e)
            cmp   joyLoX
            bcc   :x_done
            sta   joyLoX
            bra   :x_done
:x_low      lda   joyE                      ; X done: hi = min(hi, e)
            cmp   joyHiX
            bcs   :x_done
            sta   joyHiX
:x_done     bit   joyBits
            bvc   :y_low
            lda   joyE
            cmp   joyLoY
            bcc   :next
            sta   joyLoY
            bra   :next
:y_low      lda   joyE
            cmp   joyHiY
            bcs   :next
            sta   joyHiY
            bra   :next

:next       iny
            iny
            dec   joyLeftK
            bne   :sample
            lda   joyValid
            beq   :none
            clc                             ; Samples
            rts
:none       sec
            rts

; Scanline interrupts (dirty renders)
;
; The dirty renderer never runs the code field, but it leaves interrupts on nearly all the time, so the
; video hardware does the timing: while armed, the SCBs of the screen lines in joyScanLines have the
; interrupt bit set: JOY_SCAN_LINE_0 and one line per distinct threshold (JoyConfigure), at the time the
; threshold is after the strobe.  The line an interrupt arrives on says what it does (not a count of
; interrupts, which the first one after arming, anywhere on the screen, would throw off): before
; joyScanVC1 it triggers the paddle timers; after it, it reads them, if this frame's trigger happened;
; from joyScanVCLast on, it is the frame's last read.
; Every interrupt records VBL_VERT_REG and a read is judged at the time it actually happened, so an
; interrupt held up by a short sei only makes the read less useful, never wrong:
;
;   bit 7 set at elapsed e:   the timer is longer than e   (lo = max(lo, e))
;   bit 7 clear at elapsed e: the timer is at most e       (hi = min(hi, e))
;
; The interval [lo, hi] of each axis is published after the last read (joyScanRes, joyScanReady).
; The interrupts are only enabled while armed: JoyScanArm on entering the dirty renderer (gridDrawDirty),
; JoyScanDisarm before the code field runs (_BltRangeLite: every full render), the configuration screen
; and shut-down.  irqHook (rom/rom_exec.s) calls JoyScanService ahead of the firmware.  The service runs with
; any DBR, so everything it touches is addressed long.

joyScanPhase dw   0                         ; 1 = this frame's timers were triggered
joyScanT0   dw    0                         ; VBL_VERT_REG at the strobe
joyScanNow  dw    0
joyScanE    dw    0                         ; Elapsed (VBL_VERT_REG steps) at the read
joyScanLoX  dw    0                         ; This cycle's intervals
joyScanHiX  dw    0
joyScanLoY  dw    0
joyScanHiY  dw    0
joyScanTmp  dw    0
joyScanRes  ds    4                         ; The last complete cycle: lo X, hi X, lo Y, hi Y
joyScanReady dw   0                         ; Set when joyScanRes is updated

; JoyScanService
;
; Called (jsl) by irqHook for a scanline interrupt while armed, with interrupts off, native mode, 16-bit
; registers, any DBR / D.  Clears the interrupt.  Preserves every register and P (C included).
            mx    %00
JoyScanService ENT
            php
            sep   #$20
            mx    %10
            lda   #$FF-$20
            stal  VGC_INT_CLEAR             ; Clear the scanline interrupt
            ldal  VBL_VERT_REG
            stal  joyScanNow
            cmpl  joyScanVC1
            bcs   :read_line

            ldal  $E0C064                   ; Strobe, unless a timer is still running (a running
            oral  $E0C065                   ; timer ignores the trigger)
            bmi   :busy
            ldal  $E0C070
            ldal  joyScanNow
            stal  joyScanT0
            lda   #0
            stal  joyScanLoX
            stal  joyScanLoY
            dec
            stal  joyScanHiX
            stal  joyScanHiY
            lda   #1
            stal  joyScanPhase
            plp
            rtl

:busy
            DO    JOY_STATS
            rep   #$20
            ldal  jssBusy
            inc
            stal  jssBusy
            FIN
            plp
            rtl

            mx    %10
:read_line  ldal  joyScanPhase
            bne   :read
            DO    JOY_STATS                 ; No trigger this frame (armed after it, or it was late)
            rep   #$20
            ldal  jssLost
            inc
            stal  jssLost
            FIN
            plp
            rtl

            mx    %10
:read       ldal  joyScanNow
            sec
            sbcl  joyScanT0
            bcs   *+4
            adc   #131                      ; The counter wrapped (carry clear: adds 131)
            stal  joyScanE

            ldal  $E0C064
            bpl   :x_low
            ldal  joyScanE                  ; X high: lo = max(lo, e)
            cmpl  joyScanLoX
            bcc   :x_done
            stal  joyScanLoX
            bra   :x_done
:x_low      ldal  joyScanE                  ; X low: hi = min(hi, e)
            cmpl  joyScanHiX
            bcs   :x_done
            stal  joyScanHiX
:x_done
            ldal  $E0C065
            bpl   :y_low
            ldal  joyScanE
            cmpl  joyScanLoY
            bcc   :y_done
            stal  joyScanLoY
            bra   :y_done
:y_low      ldal  joyScanE
            cmpl  joyScanHiY
            bcs   :y_done
            stal  joyScanHiY
:y_done

            DO    JOY_STATS
            rep   #$30
            mx    %00
            phx
            ldal  joyScanNow                ; Reads by which read (first / last) and elapsed
            and   #$00FF
            cmpl  joyScanVCLast
            lda   #0
            bcc   *+5
            lda   #$80                      ; The last read's 64 words
            stal  joyScanTmp
            ldal  joyScanE
            and   #$003F
            asl
            oral  joyScanTmp
            tax
            ldal  jssHistE,x
            inc
            stal  jssHistE,x
            ldal  joyScanTmp                ; 0 / $80 -> 0 / 2
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            tax                             ; 0 / 2
            sep   #$20
            ldal  $E0C064
            rep   #$20
            bpl   :sx
            ldal  jssHighX,x                ; Reads with X high, by phase
            inc
            stal  jssHighX,x
:sx         plx
            sep   #$20
            mx    %10
            FIN

            ldal  joyScanNow
            cmpl  joyScanVCLast
            bcc   :more                     ; Another read to come this frame
            rep   #$20                      ; The frame's last read: publish
            mx    %00
            ldal  joyScanLoX
            and   #$00FF
            stal  joyScanTmp
            ldal  joyScanHiX
            xba
            and   #$FF00
            oral  joyScanTmp
            stal  joyScanRes                ; lo X, hi X
            ldal  joyScanLoY
            and   #$00FF
            stal  joyScanTmp
            ldal  joyScanHiY
            xba
            and   #$FF00
            oral  joyScanTmp
            stal  joyScanRes+2              ; lo Y, hi Y
            lda   #1
            stal  joyScanReady
            DO    JOY_STATS
            ldal  jssCycles
            inc
            stal  jssCycles
            FIN
            sep   #$20
            mx    %10
            lda   #0
            stal  joyScanPhase
:more       plp
            rtl

; JoyScanArm / JoyScanDisarm
;
; Enable / disable the scanline interrupts: the SCB marks and the VGC enable bit.  Disarming after dirty
; renders also drops the next full render's probe runs (joySkipHarvest).  16-bit registers, DBR = this
; bank.
            mx    %00
JoyScanArm
            lda   joyScanArmed
            bne   :done
            lda   joyEnabled                ; No player uses the joystick
            beq   :done
            DO    NO_INTERRUPTS             ; No IRQ hook to take them
            ELSE
            php
            sei
            ldy   #0
:mark       ldx   joyScanLines,y            ; Set the interrupt bit of each line's SCB
            sep   #$20
            ldal  SHR_SCB,x
            ora   #SCB_INT_BIT
            stal  SHR_SCB,x
            rep   #$20
            iny
            iny
            cpy   joyScanLineBytes
            bcc   :mark
            sep   #$20
            mx    %10
            lda   #$FF-$20
            stal  VGC_INT_CLEAR             ; No stale interrupt
            ldal  VGC_INT_REG
            ora   #$02
            stal  VGC_INT_REG               ; Enable the scanline interrupts
            rep   #$20
            mx    %00
            stz   joyScanPhase
            lda   #1
            sta   joyScanArmed
            plp
            FIN
:done       rts

            mx    %00
JoyScanDisarm
            lda   joyScanArmed
            beq   :done
            php
            sei
            sep   #$20
            mx    %10
            ldal  VGC_INT_REG
            and   #$FF-$02
            stal  VGC_INT_REG               ; Disable the scanline interrupts
            lda   #$FF-$20
            stal  VGC_INT_CLEAR
            rep   #$20
            mx    %00
            ldy   #0
:clear      ldx   joyScanLines,y            ; Clear the interrupt bit of each line's SCB
            sep   #$20
            ldal  SHR_SCB,x
            and   #$FF-SCB_INT_BIT
            stal  SHR_SCB,x
            rep   #$20
            iny
            iny
            cpy   joyScanLineBytes
            bcc   :clear
            stz   joyScanArmed
            lda   #1
            sta   joySkipHarvest
            plp
:done       rts

            mx    %00
JoyScanDisarmL ENT
            phb
            phk
            plb
            jsr   JoyScanDisarm
            plb
            rtl


; JoyConfigureL
;
; Apply the joystick settings (rom/rom_config_setup.s): whether a player uses the joystick (joyEnabled),
; each axis' thresholds and the scanline interrupt lines.  The thresholds are in VBL_VERT_REG steps
; (127 us) after the strobe: center - dz and center + dz (joyThr), with the center from the calibration
; (config_joy_cx / cy, steps x 16; 0 = not calibrated: JOY_DEFAULT_CENTER) and dz = 8 - sensitivity.
; They place the scanline interrupt lines and judge their reads, and the configuration screen's TEST.
; A probe run's samples are judged against the same thresholds less the offset (joyPeaThr, offset 0 - 7:
; config_joy_offset): the offset only changes how the probe runs are read, for when they don't reach
; the right threshold (the rows run fast, as on GSPlus).  Each left threshold is at least 1, each right
; one after it.
; Called by ApplyConfig and at start-up, before _InitRenderMode (which hooks the probe rows if enabled).
; 16-bit registers.
joyEnabled  dw    0                         ; A player uses the joystick
joyDz       dw    0
joyOff      dw    0
joyThr      ds    8                         ; Left / right X, left / right Y (steps)
joyPeaThr   ds    8                         ; The same, less the offset: for the probe runs (must follow joyThr)
joyScanLines ds   2*5                       ; The strobe line, then the read lines, ascending
joyScanLineBytes dw 0
joyScanVC1  dw    0                         ; VBL_VERT_REG from which an interrupt is a read
joyScanVCLast dw  0                         ; ... the frame's last read
joyTmp      dw    0
joyTmpPos   dw    0

            mx    %00
JoyConfigureL ENT
            phb
            phk
            plb
            jsr   JoyScanDisarm             ; (the lines are about to change)

            stz   joyEnabled
            ldal  config_input_p1_type
            cmp   #INPUT_JOYSTICK
            beq   :on
            ldal  config_input_p2_type
            cmp   #INPUT_JOYSTICK
            bne   :sens
:on         inc   joyEnabled

:sens       ldal  config_joy_sens           ; dz = 8 - sensitivity (1 - 7)
            and   #$00FF
            bne   *+5
            lda   #JOY_DEFAULT_SENS
            cmp   #8
            bcc   *+5
            lda   #7
            eor   #$FFFF
            sec
            adc   #8
            sta   joyDz
            ldal  config_joy_offset         ; 0 - 7
            and   #$0007
            sta   joyOff

            ldal  config_joy_cx
            ldx   #0
            jsr   :axis
            ldal  config_joy_cy
            ldx   #4
            jsr   :axis

; The scanline lines: the strobe line, then one per distinct threshold, at 2 lines per step
            lda   #JOY_SCAN_LINE_0
            sta   joyScanLines
            lda   #2
            sta   joyScanLineBytes
            ldx   #0
:each       phx
            lda   joyThr,x
            asl
            clc
            adc   #JOY_SCAN_LINE_0
            jsr   :insert
            plx
            inx
            inx
            cpx   #8
            bcc   :each

            lda   joyScanLines              ; From halfway between the strobe line and the first read
            clc
            adc   joyScanLines+2
            jsr   :vc
            sta   joyScanVC1
            ldy   joyScanLineBytes          ; From halfway between the last two lines
            lda   joyScanLines-4,y
            clc
            adc   joyScanLines-2,y
            jsr   :vc
            sta   joyScanVCLast
            plb
            rtl

; A = the sum of two lines: the VBL_VERT_REG value of the line halfway between them
:vc         lsr
            lsr
            clc
            adc   #$80                      ; VBL_VERT_REG = (line + $100) / 2
            rts

; A = the calibrated center (steps x 16, 0 = not calibrated), X = the axis' offset in joyThr
:axis       and   #$FFFF
            bne   *+5
            lda   #JOY_DEFAULT_CENTER*16
            clc
            adc   #8
            lsr
            lsr
            lsr
            lsr                             ; Steps
            pha
            jsr   :pair                     ; joyThr
            pla
            sec
            sbc   joyOff
            pha
            txa
            clc
            adc   #joyPeaThr-joyThr
            tax
            pla                             ; joyPeaThr

; A = the center (steps, may be negative), X = the pair's offset in joyThr: center - dz (at least 1) and
; center + dz (at least the first + 1)
:pair       pha
            sec
            sbc   joyDz
            bmi   :low1
            bne   *+5
:low1       lda   #1                        ; At least one step
            sta   joyThr,x
            pla
            clc
            adc   joyDz
            bmi   :after
            cmp   joyThr,x
            beq   :after
            bcs   :right
:after      lda   joyThr,x                  ; At least a step after the left one
            inc
:right      cmp   #JOY_MAX_THRESHOLD
            bcc   *+5
            lda   #JOY_MAX_THRESHOLD
            sta   joyThr+2,x
            rts

; Insert line A into joyScanLines (after the strobe line), keeping it sorted and without duplicates
:insert     sta   joyTmp
            ldx   #2
:find       cpx   joyScanLineBytes
            bcs   :put
            lda   joyScanLines,x
            cmp   joyTmp
            beq   :ins_done                 ; Already there
            bcs   :shift                    ; A later line: insert before it
            inx
            inx
            bra   :find
:shift      stx   joyTmpPos
            ldy   joyScanLineBytes          ; Move the later lines up
:sh_loop    cpy   joyTmpPos
            beq   :put
            lda   joyScanLines-2,y
            sta   joyScanLines,y
            dey
            dey
            bra   :sh_loop
:put        lda   joyTmp
            sta   joyScanLines,x
            inc   joyScanLineBytes
            inc   joyScanLineBytes
:ins_done   rts

; JoyGetPadL
;
; The joystick as pad bits (PAD_LEFT / RIGHT / UP / DOWN), for the input readers (_ReadJoystick).  First
; takes the new readings: a full render's probe run (JoyHarvest) and a frame's scanline interrupt reads
; (JoyScanService).  Each gives an interval for each axis' timer, [lo, hi] (the timer is longer than lo
; and at most hi), which decides the axis when it is entirely on one side of a threshold:
;
;   hi <= left threshold: left (up)   lo >= right threshold: right (down)   both inside: centered
;
; Otherwise the axis keeps its direction, unless the interval rules that direction out (lo >= the left
; threshold when it is left, hi <= the right threshold when it is right): then it is centered.
; Called with interrupts off (NES_PollInput).  16-bit registers; returns A.
joyDirX     dw    JOY_DIR_CENTER            ; JOY_DIR_LOW / CENTER / HIGH
joyDirY     dw    JOY_DIR_CENTER
joyCLo      dw    0                         ; The classifier's inputs
joyCHi      dw    0
joyCThrL    dw    0
joyCThrR    dw    0
joyTmpDir   dw    0

            mx    %00
JoyGetPadL  ENT
            phb
            phk
            plb
            lda   joyScanReady
            beq   :pea
            stz   joyScanReady
            lda   joyScanRes                ; lo X, hi X
            ldx   #0
            jsr   :axis
            sta   joyDirX
            lda   joyScanRes+2              ; lo Y, hi Y
            ldx   #4
            jsr   :axis
            sta   joyDirY

:pea        lda   joyPeaReady
            beq   :out
            stz   joyPeaReady
            lda   joyPeaRes
            ldx   #joyPeaThr-joyThr         ; The thresholds less the offset
            jsr   :axis
            sta   joyDirX
            lda   joyPeaRes+2
            ldx   #joyPeaThr-joyThr+4
            jsr   :axis
            sta   joyDirY

:out        lda   joyDirX
            ldx   joyDirY
            jsr   JoyPadBits
            plb
            rtl

; A = lo (low byte), hi (high byte, $FF = never seen done), X = the axis' thresholds' offset from joyThr
; (+ 0 = X, + 4 = Y).  Returns the axis' direction.
:axis       pha
            and   #$00FF
            sta   joyCLo
            pla
            xba
            and   #$00FF
            cmp   #$00FF
            bne   *+5
            lda   #$FFFF
            sta   joyCHi
            lda   joyThr,x
            sta   joyCThrL
            lda   joyThr+2,x
            sta   joyCThrR
            ldy   joyDirX                   ; The axis' current direction
            txa
            bit   #4
            beq   *+5
            ldy   joyDirY
            jmp   JoyClassify

; Classify joyCLo / joyCHi against joyCThrL / joyCThrR.  Y = the current direction.  Returns the direction
; in A.
JoyClassify
            lda   joyCHi
            cmp   joyCThrL
            beq   :low
            bcc   :low
            lda   joyCLo
            cmp   joyCThrR
            bcs   :high
            cmp   joyCThrL
            bcc   :keep
            lda   joyCHi
            cmp   joyCThrR
            beq   :center
            bcc   :center
:keep       cpy   #JOY_DIR_LOW              ; Straddles a threshold: keep the direction, unless the
            bne   :keep_high                ; interval rules it out
            lda   joyCLo
            cmp   joyCThrL
            bcs   :center                   ; Longer than the left threshold: not left
            tya
            rts
:keep_high  cpy   #JOY_DIR_HIGH
            bne   :same
            lda   joyCHi
            cmp   joyCThrR
            beq   :center
            bcc   :center                   ; At most the right threshold: not right
:same       tya
            rts
:low        lda   #JOY_DIR_LOW
            rts
:high       lda   #JOY_DIR_HIGH
            rts
:center     lda   #JOY_DIR_CENTER
            rts

; A = X's direction, X = Y's direction.  Returns the pad bits.
JoyPadBits  sta   joyTmpDir
            lda   #0
            cpx   #JOY_DIR_LOW
            bne   *+5
            ora   #PAD_UP
            cpx   #JOY_DIR_HIGH
            bne   *+5
            ora   #PAD_DOWN
            ldx   joyTmpDir
            cpx   #JOY_DIR_LOW
            bne   *+5
            ora   #PAD_LEFT
            cpx   #JOY_DIR_HIGH
            bne   *+5
            ora   #PAD_RIGHT
            rts

; JoyClassifyL
;
; For the configuration screen's test: X / Y = the time (steps) at which each axis' timer was first
; seen done by a busy read (JoyMeasure, $FF = it never was), so it ended in [e - 1, e].  Returns A = the
; pad bits for the current thresholds (JoyConfigureL).  16-bit registers.
joyTmpDir2  dw    0

            mx    %00
JoyClassifyL ENT
            phb
            phk
            plb
            phy
            txa
            ldx   #0
            jsr   :axis
            sta   joyTmpDir2
            pla
            pha
            ldx   #4
            jsr   :axis
            tax
            pla
            lda   joyTmpDir2
            jsr   JoyPadBits
            plb
            rtl

; A = e, X = the axis' offset in joyThr
:axis       and   #$00FF
            cmp   #$00FF
            bne   :seen
            lda   #$FFFF                    ; Never done: longer than everything
            sta   joyCHi
            sta   joyCLo
            bra   :thr
:seen       sta   joyCHi
            dec
            bpl   *+5
            lda   #0
            sta   joyCLo
:thr        lda   joyThr,x
            sta   joyCThrL
            lda   joyThr+2,x
            sta   joyCThrR
            ldy   #JOY_DIR_CENTER
            jmp   JoyClassify

            DO    JOY_STATS
; Measurement counters, found in memory by their signature
jsSig       asc   'JOYSTATS'
jsRenders   dw    0                         ; JoyHarvest calls (renders)
jsValid     dw    0                         ; Runs taken
jsRunsHist  ds    2*8                       ; Renders with no run published (+0) / a run taken (+2)
jsHistE     ds    2*64                      ; Runs taken by their last sample's time (steps): their reach
jsHistX     ds    2*16                      ; Runs taken by lo X (steps, 15 = 15 or more)
jsHistY     ds    2*16                      ; Runs taken by hi X (steps, 15 = 15 or more)

jssSig      asc   'JOYSCAN!'
jssCycles   dw    0                         ; Complete strobe-read-read cycles
jssBusy     dw    0                         ; Strobes skipped: a timer was still running
jssLost     dw    0                         ; Reads with no trigger this frame
jssHighX    ds    2*2                       ; Reads with X high: first, last
jssHistE    ds    2*64*2                    ; Reads by elapsed time: first, then last
            FIN

            ELSE
; Without joystick support: the entry points MAIN imports
JoyScanService ENT
JoyScanDisarmL ENT
JoyConfigureL ENT
            rtl
JoyGetPadL  ENT
JoyClassifyL ENT
            lda   #0
            rtl
            FIN

joyScanArmed ENT                            ; Set while the scanline interrupts are enabled
            dw    0

            mx    %00

; JoyProbes.s - the game-port joystick
;
; An Apple II paddle is read by triggering its timer ($C070) and seeing when bit 7 of $C064 (X) / $C065
; (Y) clears: the stick's position sets how long the timer runs, up to JOY_WINDOW (3.3 ms).  Rather than
; spin, the joystick is sampled while the screen is drawn, and timed by the video counter, so a reading
; doesn't depend on how fast the CPU runs.
;
; The design has two halves:
;
;   Sampling   a strobe triggers the timers and records the time and the timers' bits just before it;
;              each sample after it records the time and the bits.  Nothing else: no decisions, no
;              arithmetic.  Two sources, depending on the renderer:
;                - full renders: probe code in the PEA field's exits (the code field runs with interrupts
;                  off, a row at a time): JoyInstallProbes
;                - dirty renders: scanline interrupts on fixed lines: JoyScanService
;   Judging    JoyGetPadL, when the game asks for the controller: every sample taken since the last call
;              narrows each axis' timer down to an interval, which classifies the axis
;
; Both sources write the same record, a run: the strobe's time and bits, then the samples' (time, bits),
; where a time of 0 means no sample.  A sample is judged at the time it was taken:
;
;   timer running at elapsed e:   the timer is longer than e    (lo = max(lo, e))
;   timer done at elapsed e:      the timer is at most e        (hi = min(hi, e))
;
; so samples don't need to be evenly spaced, and a source that runs fast (shadow-off rows, accelerators,
; emulators) only reaches less far: a short run is still right, and complete if it saw both timers done.
; Every run since the last call narrows the same intervals (the stick doesn't move in a few ms).  A run
; whose strobe found a timer still running is dropped (a running timer ignores the trigger, so its samples
; time an older strobe), and if the runs disagree (lo >= hi: the stick moved), so is the whole reading.
;
; The time is read by JOY_NOW and compared by JOY_ELAPSED only: VBL_VERT_REG, 2 scanlines (127 us) per
; step.  Everything else (thresholds, calibration, windows) is in those steps.

; ---------------------------------------------------------------------------
; Sampling macros: the only code that touches the hardware
; ---------------------------------------------------------------------------

; A (8-bit) = the time, in steps (never 0: VBL_VERT_REG runs $7D - $FF)
JOY_NOW     mac
            ldal  VBL_VERT_REG
            <<<

; A (8-bit) = the time elapsed from the time at ]1 (long) to the time in A, in steps.  Clobbers C.
JOY_ELAPSED mac
            sec
            sbcl  ]1
            bcs   *+4
            adc   #JOY_FRAME_STEPS          ; The counter wrapped (carry clear: adds a frame)
            <<<

; A (8-bit) = the timers' bits: bit 7 = X running, bit 6 = Y running (the rest: floating bus)
JOY_BITS    mac
            ldal  $E0C064
            asl                             ; C = X running
            ldal  $E0C065
            ror
            <<<

; Trigger the paddle timers
JOY_STROBE  mac
            ldal  $E0C070
            <<<

; ---------------------------------------------------------------------------
; Probe runs: full renders
; ---------------------------------------------------------------------------
;
; The first row of a run (the strobe row) strobes; each row after it (the probe rows) samples.  The runs
; start at rows JOY_RUN_ROW_0 and JOY_RUN_ROW_1 of each blitter bank, right after an interrupt window, and
; take every row up to the next one, so a run is never interrupted.  The code field runs with RAMWRT on
; (writes to bank $00 go to bank $01), so the probe code never writes the direct page: its runs go to
; JOY_DATA in the blitter bank itself (DBR in the code field), one JOY_SLOT_SIZE slot per run.  Each hooked
; row's probe code is in the unused start of its odd page (P1 $00 - $20) and ends with a JMP to the row's
; original exit target; the row's exits jump to it.
;
; The strobe row also sets Y = JOY_TOKEN, and a probe row only samples if Y is set: the code field never
; uses Y and _BltRangeLiteBody enters it with Y = 0, so a range that starts after a run's strobe row
; doesn't sample (a range that ends inside a run keeps the samples taken).  A run's samples therefore
; always start with its first probe row.
;
; JoyInstallProbesL (from _InitLiteBlitter, after it has set every exit) hooks the rows.

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

; Probe code templates.  Each is _JOY_CODE_SIZE bytes: the code, a JMP whose operand JoyInstallProbes
; sets, and padding (never executed).  The data operands are patched per row too.  They run in the code
; field: M = 1, X = 0, DBR = the blitter bank.  The ':' forces absolute addressing (JOY_DATA is below
; $100).
            mx    %10
joyTplStrobe
            JOY_BITS
joyTplStrobeB sta: JOY_DATA+1               ; The bits before the strobe
            JOY_STROBE
            JOY_NOW
joyTplStrobeT sta: JOY_DATA                 ; The strobe's time
            ldy   #JOY_TOKEN                ; This range ran the strobe
joyTplStrobeJ jmp $0000
            ds    joyTplStrobe+_JOY_CODE_SIZE-*

joyTplProbe
            tya                             ; (JOY_TOKEN's low byte is not 0)
            beq   joyTplProbeJ              ; This range didn't run the strobe
            JOY_NOW
joyTplProbeT sta: JOY_DATA                  ; The time
            JOY_BITS
joyTplProbeB sta: JOY_DATA                  ; The bits
joyTplProbeJ jmp $0000
            ds    joyTplProbe+_JOY_CODE_SIZE-*
            ERR   {*-joyTplStrobe}-{2*_JOY_CODE_SIZE}  ; A template is not _JOY_CODE_SIZE bytes

joyBank     dw    0                         ; Bank being hooked
joyRow0     dw    0                         ; Strobe rows of the two runs
joyRow1     dw    0
joyStep     dw    0                         ; 1, or 2 with CTRL_EVEN_RENDER
joyK        dw    0                         ; Probe rows per run
joyRow      dw    0
joyData     dw    0                         ; The run's slot (JOY_DATA offset)
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

; A = the strobe row, X = the slot
:run        sta   joyRow
            stx   joyData
            jsr   :strobe
            stz   joyIdx
:probe      lda   joyRow                    ; The next (executed) row
            clc
            adc   joyStep
            sta   joyRow
            lda   joyIdx                    ; The sample's time: slot + 2 + 2 x index
            asl
            adc   joyData                   ; (carry clear)
            inc
            inc
            jsr   :sample
            inc   joyIdx
            lda   joyIdx
            cmp   joyK
            bcc   :probe
            rts

:ptr        equ   tmp10                     ; (and tmp11)
:dat        equ   tmp12

; Hook row joyRow as the strobe row (its time and bits at joyData)
:strobe     ldx   #joyTplStrobe
            jsr   :copy
            lda   joyData
            ldy   #_JOY_CODE_OFFSET+joyTplStrobeT+1-joyTplStrobe
            sta   [:ptr],y
            inc
            ldy   #_JOY_CODE_OFFSET+joyTplStrobeB+1-joyTplStrobe
            sta   [:ptr],y
            ldy   #_JOY_CODE_OFFSET+joyTplStrobeJ+1-joyTplStrobe
            bra   :link

; Hook row joyRow as a probe row (its time and bits at A)
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

; ---------------------------------------------------------------------------
; Scanline interrupts: dirty renders
; ---------------------------------------------------------------------------
;
; The dirty renderer never runs the code field, but it leaves interrupts on nearly all the time, so the
; video hardware does the timing: while armed, the SCBs of the lines in joyScanLines have the interrupt
; bit set: the strobe line JOY_SCAN_LINE_0, then one sample line per distinct threshold (JoyConfigureL), at
; the line the threshold's time after the strobe (2 lines per step), so each sample decides its threshold.
; The line an interrupt arrives on says what it does (not a count of interrupts, which the first one after
; arming, anywhere on the screen, would throw off): before joyScanVC1 it is the frame's strobe; after it, a
; sample, and from joyScanVCLast on, the frame's last one, which closes the run: a sample with no strobe in its frame (it came late, or the run was armed
; after it) is not taken.  JoyGetPadL takes the samples recorded so far and starts the count over, so the
; run's later samples are taken by its next call.
;
; The interrupts are only enabled while armed: JoyScanArm on entering the dirty renderer (gridDrawDirty),
; JoyScanDisarm before the code field runs (_BltRangeLite: every full render), the configuration screen
; and shut-down.  The Interrupt Manager hook irqHook (rom/rom_exec.s) calls JoyScanService directly,
; without the firmware (there is no IRQ.SCAN handler).

joyScanRun  ds    2+{2*JOY_SCAN_READS}      ; The run: strobe time and bits, then (time, bits) per sample
joyScanN    dw    0                         ; Bytes of samples recorded since JoyGetPadL took them
joyScanOpen dw    0                         ; Set by the strobe, cleared by the last sample

; JoyScanService
;
; Called (jsl) by irqHook for a scanline interrupt while armed, with interrupts off, native mode, 16-bit
; registers, any DBR / D.  Clears the interrupt.  Preserves every register.
            mx    %00
JoyScanService ENT
            php
            pha
            phx
            phb
            phk
            plb
            sep   #$20
            mx    %10
            lda   #$FF-$20
            stal  VGC_INT_CLEAR             ; Clear the scanline interrupt
            JOY_BITS
            xba                             ; (kept in B)
            JOY_NOW
            cmp   joyScanVC1
            bcs   :sample

            JOY_STROBE                      ; The strobe: its bits are from before it
            JOY_NOW
            sta   joyScanRun
            xba
            sta   joyScanRun+1
            ldx   #0
            stx   joyScanN
            inx
            stx   joyScanOpen
            bra   :out

:sample     ldx   joyScanOpen               ; No strobe this frame
            beq   :out
            ldx   joyScanN
            cpx   #2*JOY_SCAN_READS         ; (can't be: one per line)
            bcs   :out
            sta   joyScanRun+2,x            ; The time
            cmp   joyScanVCLast             ; C = the frame's last sample
            xba
            sta   joyScanRun+3,x            ; The bits
            inx
            inx
            stx   joyScanN
            bcc   :out
            ldx   #0
            stx   joyScanOpen

:out        plb
            plx
            rep   #$20
            pla
            plp
            rtl

; JoyScanArm / JoyScanDisarm
;
; Enable / disable the scanline interrupts: the SCB marks and the VGC enable bit.  16-bit registers, DBR =
; this bank.  Preserve X and Y (_BltRangeLite's range).
            mx    %00
JoyScanArm
            lda   joyScanArmed
            bne   :done
            lda   joyEnabled                ; No player uses the joystick
            beq   :done
            DO    1-NO_INTERRUPTS           ; (none without irqHook to take them; no ELSE: inside the
            php                             ; skipped DO JOYSTICK_SUPPORT, Merlin32 assembles an ELSE branch)
            sei
            phx
            phy
            stz   joyScanOpen               ; Nothing until the next strobe
            stz   joyScanN
            ldy   #0
            sep   #$20
            mx    %10
:mark       ldx   joyScanLines,y            ; Set the interrupt bit of each line's SCB
            ldal  SHR_SCB,x
            ora   #SCB_INT_BIT
            stal  SHR_SCB,x
            iny
            iny
            cpy   joyScanLineEnd
            bcc   :mark
            lda   #$FF-$20
            stal  VGC_INT_CLEAR             ; No stale interrupt
            ldal  VGC_INT_REG
            ora   #$02
            stal  VGC_INT_REG               ; Enable the scanline interrupts
            rep   #$20
            mx    %00
            lda   #1
            sta   joyScanArmed
            ply
            plx
            plp
            FIN
:done       rts

            mx    %00
JoyScanDisarm
            lda   joyScanArmed
            beq   :done
            php
            sei
            phx
            phy
            sep   #$20
            mx    %10
            ldal  VGC_INT_REG
            and   #$FF-$02
            stal  VGC_INT_REG               ; Disable the scanline interrupts
            lda   #$FF-$20
            stal  VGC_INT_CLEAR
            ldy   #0
:clear      ldx   joyScanLines,y            ; Clear the interrupt bit of each line's SCB
            ldal  SHR_SCB,x
            and   #$FF-SCB_INT_BIT
            stal  SHR_SCB,x
            iny
            iny
            cpy   joyScanLineEnd
            bcc   :clear
            rep   #$20
            mx    %00
            stz   joyScanArmed
            ply
            plx
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

; ---------------------------------------------------------------------------
; Judging
; ---------------------------------------------------------------------------

; Each axis' interval, narrowed by the samples judged: lo X, hi X, lo Y, hi Y (bytes, steps; hi = $FF:
; never seen done)
joyIv       ds    4
joyTaken    dw    0                         ; A sample was judged
joyE        dw    0                         ; The sample's elapsed time (low byte)
joyRunT0    dw    0                         ; The run being judged: its strobe's time
joyRunBusy  dw    0                         ;   ... its strobe found a timer running
joyRunN     dw    0                         ;   ... its samples (probe slots: joyK)
joyRunLeft  dw    0

; Start the intervals over.  8-bit A, DBR = this bank.
            mx    %10
JoyIvReset
            lda   #0
            sta   joyIv                     ; lo X
            sta   joyIv+2                   ; lo Y
            sta   joyTaken
            dec
            sta   joyIv+1                   ; hi X
            sta   joyIv+3                   ; hi Y
            rts

; Judge a sample: A = its bits, joyE = its elapsed time.  8-bit A, 16-bit X / Y (preserved), any DBR.
            mx    %10
JoyJudge
            asl                             ; C = X running, bit 7 = Y running
            xba                             ; (kept in B)
            ldal  joyE
            bcc   :x_done
            cmpl  joyIv                     ; X running: lo = max(lo, e)
            bcc   :y
            stal  joyIv
            bra   :y
:x_done     cmpl  joyIv+1                   ; X done: hi = min(hi, e)
            bcs   :y
            stal  joyIv+1
:y          xba                             ; N = Y running
            bpl   :y_done
            ldal  joyE
            cmpl  joyIv+2                   ; Y running: lo = max(lo, e)
            bcc   :out
            stal  joyIv+2
            bra   :out
:y_done     ldal  joyE
            cmpl  joyIv+3                   ; Y done: hi = min(hi, e)
            bcs   :out
            stal  joyIv+3
:out        lda   #1
            stal  joyTaken
            rts

; Judge the run at X in the data bank (DBR) and clear its samples' times (taken).  joyRunN = its samples.
; 8-bit A, 16-bit X.
            mx    %10
JoyTakeRun
            lda:  2,x                       ; Its first sample's time: none, no samples (they start with
            beq   :none                     ; the first)
            ldal  joyRunN
            beq   :none
            lda:  0,x
            stal  joyRunT0
            lda:  1,x                       ; A timer still running at the strobe: the strobe didn't
            and   #$C0                      ; trigger it, so the samples are only cleared
            stal  joyRunBusy
            ldal  joyRunN
            stal  joyRunLeft
:sample     lda:  2,x                       ; The time (0 = not sampled)
            beq   :next
            stz:  2,x                       ; Taken
            JOY_ELAPSED joyRunT0
            cmp   #JOY_MAX_E                ; Can't be (an old sample)
            bcs   :next
            stal  joyE
            ldal  joyRunBusy
            bne   :next
            lda:  3,x                       ; The bits
            jsr   JoyJudge
:next       inx
            inx
            ldal  joyRunLeft
            dec
            stal  joyRunLeft
            bne   :sample
:none       rts

; JoyGetPadL
;
; The joystick as pad bits (PAD_LEFT / RIGHT / UP / DOWN), for the input readers (_ReadJoystick).  Takes
; every run sampled since the last call: the scanline interrupts' and the four probe slots (two in each
; blitter bank).  The intervals they leave decide each axis (JoyClassify) if they agree; otherwise, or with
; no samples, the axes keep their directions.  Called with interrupts off (NES_PollInput), so no sample is
; recorded meanwhile, any D (no direct page is used).  16-bit registers; returns A.
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
            sep   #$20
            mx    %10
            jsr   JoyIvReset

            ldy   joyScanN                  ; The scanline interrupts' samples so far
            beq   :probes
            ldx   #0
            stx   joyScanN                  ; (the run's later ones start over: same strobe)
            rep   #$20
            tya
            lsr
            sta   joyRunN
            sep   #$20
            ldx   #joyScanRun
            jsr   JoyTakeRun

:probes     rep   #$20
            lda   joyK
            sta   joyRunN
            sep   #$20
            lda   #^lite_base_1
            jsr   :bank
            lda   #^lite_base_2
            jsr   :bank

            lda   joyTaken
            beq   :out
            lda   joyIv                     ; The runs agree: lo < hi on both axes
            cmp   joyIv+1
            bcs   :out
            lda   joyIv+2
            cmp   joyIv+3
            bcs   :out
            rep   #$20
            mx    %00
            lda   joyIv                     ; lo X, hi X
            ldx   #0
            jsr   :axis
            sta   joyDirX
            lda   joyIv+2                   ; lo Y, hi Y
            ldx   #4
            jsr   :axis
            sta   joyDirY

:out        rep   #$20
            mx    %00
            lda   joyDirX
            ldx   joyDirY
            jsr   JoyPadBits
            plb
            rtl

; A = a blitter bank: take its two slots.  8-bit A.
            mx    %10
:bank       pha
            plb
            ldx   #JOY_DATA
            jsr   JoyTakeRun
            ldx   #JOY_DATA+JOY_SLOT_SIZE
            jsr   JoyTakeRun
            phk
            plb
            rts

; A = lo (low byte), hi (high byte, $FF = never seen done), X = the axis' thresholds' offset in joyThr
; (+ 0 = X, + 4 = Y).  Returns the axis' direction.
            mx    %00
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

; Classify the interval joyCLo / joyCHi (the timer is longer than lo and at most hi) against the thresholds
; joyCThrL / joyCThrR.  Y = the current direction.  Returns the direction in A.
;
;   hi <= left threshold: left (up)   lo >= right threshold: right (down)   both inside: centered
;
; Otherwise the interval straddles a threshold: the axis keeps its direction, unless the interval rules
; that direction out (lo >= the left threshold when it is left, hi <= the right threshold when it is
; right): then it is centered.
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

; ---------------------------------------------------------------------------
; Configuration
; ---------------------------------------------------------------------------

; JoyConfigureL
;
; Apply the joystick settings (rom/rom_config_setup.s): whether a player uses the joystick (joyEnabled)
; and each axis' thresholds: center - dz and center + dz (steps), with the center from the calibration
; (config_joy_cx / cy, steps x 16; 0 = not calibrated: JOY_DEFAULT_CENTER) and dz = 8 - sensitivity.
; Each left threshold is at least 2, each right one after it and at most JOY_MAX_E.  Then the scanline
; interrupts' lines: the strobe line and a sample line per distinct threshold (joyScanLines), and the
; VBL_VERT_REG values that tell them apart (joyScanVC1, joyScanVCLast).
; Called by ApplyConfig and at start-up, before _InitRenderMode (which hooks the probe rows if enabled).
; 16-bit registers.
joyEnabled  dw    0                         ; A player uses the joystick
joyDz       dw    0
joyThr      ds    8                         ; Left / right X, left / right Y (steps)
joyScanLines ds   2*{1+JOY_SCAN_READS}      ; The strobe line, then the sample lines, ascending
joyScanLineEnd dw 0                         ; (bytes)
joyScanVC1  dw    0                         ; VBL_VERT_REG from which an interrupt is a sample
joyScanVCLast dw  0                         ;   ... the frame's last sample
joyLast     dw    0
joyMin      dw    0

            mx    %00
JoyConfigureL ENT
            phb
            phk
            plb
            jsr   JoyScanDisarm             ; (re-armed by the next dirty render, if enabled)

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

            ldal  config_joy_cx
            ldx   #0
            jsr   :axis
            ldal  config_joy_cy
            ldx   #4
            jsr   :axis

; The lines: the strobe line, then the thresholds' lines (JOY_SCAN_LINE_0 + 2 per step), ascending and
; distinct: each time the smallest one after the last line taken
            lda   #JOY_SCAN_LINE_0
            sta   joyScanLines
            sta   joyLast
            ldy   #2
:next_line  lda   #$FFFF
            sta   joyMin
            ldx   #6
:cand       lda   joyThr,x
            asl
            adc   #JOY_SCAN_LINE_0          ; (carry clear: the thresholds are small)
            cmp   joyLast
            beq   :skip
            bcc   :skip
            cmp   joyMin
            bcs   :skip
            sta   joyMin
:skip       dex
            dex
            bpl   :cand
            lda   joyMin
            bmi   :lines_done               ; ($FFFF: no more)
            sta   joyScanLines,y
            sta   joyLast
            iny
            iny
            bra   :next_line
:lines_done sty   joyScanLineEnd

; VBL_VERT_REG = (line + $100) / 2.  A sample from halfway between the strobe line and the first sample
; line (the thresholds are at least 2 steps, so that is after the strobe's value); the last sample from
; halfway between the last two lines, rounded up (2 lines apart: the last line's own value)
            lda   joyScanLines
            clc
            adc   joyScanLines+2
            adc   #$200
            lsr
            lsr
            sta   joyScanVC1
            lda   joyScanLines-4,y
            clc
            adc   joyScanLines-2,y
            adc   #$202
            lsr
            lsr
            sta   joyScanVCLast
            plb
            rtl

; A = the calibrated center (steps x 16, 0 = not calibrated), X = the axis' offset in joyThr
:axis       and   #$FFFF
            bne   *+5
            lda   #JOY_DEFAULT_CENTER*16
            clc
            adc   #8                        ; (rounded)
            lsr
            lsr
            lsr
            lsr                             ; Steps
            pha
            sec
            sbc   joyDz                     ; Left: center - dz, at least 2
            bmi   :low2
            cmp   #2
            bcs   *+5
:low2       lda   #2
            sta   joyThr,x
            pla
            clc
            adc   joyDz                     ; Right: center + dz, after the left one
            cmp   joyThr,x
            beq   :after
            bcs   :right
:after      lda   joyThr,x
            inc
:right      cmp   #JOY_MAX_E
            bcc   *+5
            lda   #JOY_MAX_E
            sta   joyThr+2,x
            rts

; JoyMeasureL
;
; For the configuration screen: trigger the paddle timers and spin until both are done, with interrupts
; off, sampling as the sources above do.  Returns X / Y = the time (steps) at which each was first seen
; done ($FF = not within JOY_MAX_E), so it ended in [e - 1, e]; carry set if a timer wasn't seen done (or
; was still running from before).  16-bit registers.
joyMeasT0   dw    0

            mx    %00
JoyMeasureL ENT
            phb
            phk
            plb
            php
            sei
            sep   #$20
            mx    %10
            jsr   JoyIvReset
            ldx   #0                        ; Wait (a while) for a timer still running
:idle       JOY_BITS
            and   #$C0
            beq   :go
            dex
            bne   :idle
            bra   :timeout
:go         JOY_STROBE
            JOY_NOW
            sta   joyMeasT0
:poll       JOY_NOW
            JOY_ELAPSED joyMeasT0
            cmp   #JOY_MAX_E
            bcs   :timeout
            sta   joyE
            JOY_BITS
            pha
            jsr   JoyJudge
            pla
            and   #$C0                      ; Until both are done
            bne   :poll
            jsr   :result
            plp
            clc
            plb
            rtl

:timeout    jsr   :result
            plp
            sec
            plb
            rtl

            mx    %10
:result     rep   #$20
            mx    %00
            lda   joyIv+1                   ; hi X
            and   #$00FF
            tax
            lda   joyIv+3                   ; hi Y
            and   #$00FF
            tay
            rts

; JoyClassifyL
;
; For the configuration screen's test: X / Y = the time (steps) at which each axis' timer was first seen
; done (JoyMeasureL, $FF = it never was), so it ended in [e - 1, e].  Returns A = the pad bits for the
; current thresholds (JoyConfigureL).  16-bit registers.
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
            ldx   #4
            jsr   :axis
            tax
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

            ELSE
; Without joystick support: the entry points MAIN imports
JoyScanService ENT
JoyScanDisarmL ENT
JoyConfigureL ENT
            rtl
JoyGetPadL  ENT
JoyClassifyL ENT
JoyMeasureL ENT
            lda   #0
            sec
            rtl
            FIN

joyScanArmed ENT                            ; Set while the scanline interrupts are enabled
            dw    0

            mx    %00

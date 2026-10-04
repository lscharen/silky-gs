; Init

sound_control           =   $3c                     ;really at $e1c03c
sound_data              =   $3d                     ;really at $e1c03d
sound_address           =   $3e                     ;really at $e1c03e

sound_interrupt_ptr     =   $e1002c
irq_volume              =   $e100ca
osc_interrupt           =   $e100cc


                        mx %10

access_doc_registers    = *
                        ldal irq_volume
                        sta sound_control
                        rts

access_doc_ram          = *
                        ldal irq_volume
                        ora #%0110_0000
                        sta sound_control
                        rts

access_doc_ram_no_inc   = *
                        ldal irq_volume
                        ora #%0100_0000
                        sta sound_control
                        rts

                        mx  %00

APUStartUp
                        stal apu_mode
                        php
                        sei
                        phd
                        pea $c000
                        pld
                        jsr copy_instruments_to_doc
                        jsr setup_doc_registers
                        jsr setup_interrupt
                        pld
                        plp
                        rts

; Reload the configuration for on-the-fly changes
APUReload
                        php
                        sei
                        phd

                        pha                    ; Save the new configuration mode
                        pea  $c000
                        pld

                        jsr  stop_playing
                        jsr  stop_interrupts

                        pla
                        stal apu_mode
                        jsr  setup_doc_registers
                        jsr  setup_interrupt

                        pld
                        plp
                        rts

APUShutDown             = *
                        php
                        sei
                        phd

                        lda   #$c000
                        tcd

                        jsr   stop_playing
                        jsr   stop_interrupts

                        pld
                        plp
                        clc
                        rts

APUStop                 = *
                        php
                        sei
                        phd

                        lda   #$c000
                        tcd

                        jsr   stop_playing

                        pld
                        plp
                        clc
                        rts

stop_interrupts
                        ldal  apu_mode
                        cmp   #APU_60HZ
                        beq   :no_doc_interrupts

                        lda   backup_interrupt_ptr      ; restore old interrupt ptr
                        stal  sound_interrupt_ptr
                        lda   backup_interrupt_ptr+2
                        stal  sound_interrupt_ptr+2
:no_doc_interrupts
                        rts


stop_playing            = *

                        ldy   #10                       ; Number of oscillators (5 channels x L/R)

                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        lda   #$a0                      ; stop all oscillators in use
                        sta   sound_address
                        lda   #%11
]loop                   sta   sound_data
                        inc   sound_address
                        dey
                        bne   ]loop

                        lda   #$a0+interrupt_oscillator ; stop interrupt oscillator
                        sta   sound_address
                        lda   #3
                        sta   sound_data

                        rep   #$20
                        mx    %00
                        rts

; Copy in 4 different square wave duty cycles and a triangle wave
copy_instruments_to_doc
                        jsr setup_docram

                        lda #$0100
                        jsr make_eigth_pulse

                        lda #$0200
                        jsr make_quarter_pulse

                        lda #$0300
                        jsr make_half_pulse

                        lda #$0400
                        jsr make_inv_quarter_pulse

                        lda #$0500
                        jsr copy_triangle

                        lda #$0600
                        jsr copy_noise

;                        lda #$8000
;                        jsr gen_noise

                        rts

;--------------------------

setup_docram
                        sep #$20
                        mx  %10

                        jsr access_doc_ram

                        stz sound_address

                        lda #$80
                        ldx #256                    ;make sure that page 00 has nonzero data for interrupt
:loop                   sta sound_data
                        dex
                        bne :loop

                        rep #$20
                        mx  %00
                        rts

;--------------------------
; The pulse waves average to zero, like the NES output after its high-pass filtering.  With
; $01/$FF tables, every volume change (note on/off, envelope steps) also moved the DC level of
; the narrow duties, which the IIgs output turns into a click.  All four have the same
; peak-to-peak (145) as on the NES; the 12.5% duty sets the limit.
make_eigth_pulse
                        ldy #32
                        ldx #$FF6E                  ; 32 x +127, 224 x -18
                        jmp make_pulse

make_quarter_pulse
                        ldy #64
                        ldx #$ED5C                  ; 64 x +109, 192 x -36
                        jmp make_pulse

make_half_pulse
                        ldy #128
                        ldx #$C838                  ; 128 x +72, 128 x -72
                        jmp make_pulse

make_inv_quarter_pulse
                        ldy #192
                        ldx #$5CED                  ; 192 x -36, 64 x +109
                        jmp make_pulse

; A = DOC page << 8, Y = samples at the first level, X = first level << 8 | second level
make_pulse
                        stx pulse_levels
                        sep #$30
                        mx  %11

                        stz sound_address
                        xba
                        sta sound_address+1

                        ldx #0

:loop1
                        lda pulse_levels+1
                        sta sound_data
                        inx
                        dey
                        bne :loop1

:loop2
                        lda pulse_levels
                        sta sound_data
                        inx
                        bne :loop2

                        rep #$30
                        mx  %00
                        rts

pulse_levels            dw  0

copy_triangle
                        sep #$30
                        mx  %11

                        stz sound_address
                        xba
                        sta sound_address+1

                        ldx #0
:loop
                        lda triangle_wave,x
                        sta sound_data
                        inx
                        bne :loop

                        rep #$30
                        mx  %00
                        rts

; Generate random data from the NES APU LFSR. Make it long enough to sound good.
gen_noise

copy_noise
                        sep #$30
                        mx  %11

                        stz sound_address
                        xba
                        sta sound_address+1

                        ldx #0
:loop
                        lda noise_wave,x
                        sta sound_data
                        inx
                        bne :loop

                        rep #$30
                        mx  %00
                        rts
;--------------------------

triangle_wave
    hex 80828486888a8c8e90929496989a9c9e
    hex a0a2a4a6a8aaacaeb0b2b4b6b8babcbe
    hex c0c1c3c5c7c9cbcdcfd1d3d5d7d9dbdd
    hex dfe1e3e5e7e9ebedeff1f3f5f7f9fbfd
    hex fffdfbf9f7f5f3f1efedebe9e7e5e3e1
    hex dfdddbd9d7d5d3d1cfcdcbc9c7c5c3c1
    hex c0bebcbab8b6b4b2b0aeacaaa8a6a4a2
    hex a09e9c9a98969492908e8c8a88868482
    hex 807e7c7a78767472706e6c6a68666462
    hex 605e5c5a58565452504e4c4a48464442
    hex 413f3d3b39373533312f2d2b29272523
    hex 211f1d1b19171513110f0d0b09070503
    hex 01030507090b0d0f11131517191b1d1f
    hex 21232527292b2d2f31333537393b3d3f
    hex 41424446484a4c4e50525456585a5c5e
    hex 60626466686a6c6e70727476787a7c7e

noise_wave
    hex 8f968f763e6fd49ab1e564e295a9bcc9
    hex 717b6629e6970b865dc0e0d840d32a96
    hex 3bd4c5d407b78923d8c9766bea128e8a
    hex c9ee5ddbed3119ff14b4d9a44bfbb7c4
    hex 7a56e26e8aac9ebf1653c0260446231b
    hex 73431495fc585e943edacf8f5bb970e6
    hex 118dc361bee99c98f32d25f06a33715a
    hex 585344f7f3e2f3c36c37cfd78e40147f
    hex a4b20624ac633b42b3aac5407fac4ba9
    hex a4d71a1d020a7757ea244b103f0b7a76
    hex 9b533a60cda31e0fa2ce3491b55c4f26
    hex ea47a61f661deec128129372c3471a9b
    hex f85c3c077168d413184a139440460950
    hex dee3f9bdb65e162b08ed9231a72fb943
    hex 1ba599be80dc2812afa63cc2317cdb1a
    hex 8d99d56327bc50dc975bee94754f561b

;   hex 01ffffff0101ffffff01ffff01ff0101
;   hex ffffffffffff0101ff0101ff01ffff01
;   hex 01ff0101ffff01ffff0101ff01ff01ff
;   hex ffffffff0101010101ffff0101ff0101
;   hex ffffff0101ff01ff010101ff01010101
;   hex 0101ffffff01ffff01ff01ffff01ffff
;   hex ff01ffff0101ffff01ffffffffff01ff
;   hex ffffffffffff010101ffff01ff01ffff
;   hex 01ffffffff0101ffffffff0101ffff01
;   hex ff01ff01ff01ffff0101ff01ffffffff
;   hex ffff010101ffffffff01010101ff0101
;   hex ffffffffffffff01ff0101ffffff0101
;   hex 01ff010101ff01ffffffffff01ffffff
;   hex 01ffffffff010101ff01ffff01ff01ff
;   hex ffffffff0101ff010101ff01ffffff01
;   hex 0101010101ffff01ffff01010101ffff

;--------------------------

setup_doc_registers
                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        ldx   #pulse1_sound_settings_l
                        jsr   copy_register_config
                        ldx   #pulse1_sound_settings_r
                        jsr   copy_register_config

                        ldx   #pulse2_sound_settings_l
                        jsr   copy_register_config
                        ldx   #pulse2_sound_settings_r
                        jsr   copy_register_config

                        ldx   #triangle_sound_settings_l
                        jsr   copy_register_config
                        ldx   #triangle_sound_settings_r
                        jsr   copy_register_config

                        ldx   #noise_sound_settings_l
                        jsr   copy_register_config
                        ldx   #noise_sound_settings_r
                        jsr   copy_register_config

                        ldx   #dmc_sound_settings_l
                        jsr   copy_register_config
                        ldx   #dmc_sound_settings_r
                        jsr   copy_register_config

                        rep #$20
                        mx  %00

                        rts
copy_register_config
                        ldy   #0
:loop                   lda:  0,x                                  ; Set DOC registers for the NES channels
                        sta   sound_address
                        inx
                        lda:  0,x
                        sta   sound_data
                        inx
                        iny
                        cpy   #6                                   ; 6 pairs to describe this oscillator
                        bne   :loop
                        rts

;--------------------------

setup_interrupt         = *
                        ldal  apu_mode
                        cmp   #APU_60HZ                             ; external driver at 60Hz
                        beq   :no_doc_interrupts

                        ldal  sound_interrupt_ptr
                        sta   backup_interrupt_ptr
                        ldal  sound_interrupt_ptr+2
                        sta   backup_interrupt_ptr+2

                        lda   #$5c
                        stal  sound_interrupt_ptr
                        phk
                        phk
                        pla
                        stal  sound_interrupt_ptr+2
                        lda   #interrupt_handler
                        stal  sound_interrupt_ptr+1

                        sep   #$20
                        mx    %10

                        ldal  apu_mode
                        cmp   #APU_240HZ
                        beq   :do_240hz
                        lda   #598
                        ldy   #598/256
                        bra   :set_timer_freq
:do_240hz               lda   #1195
                        ldy   #1195/256

:set_timer_freq
                        stal  timer_sound_settings+1               ; low byte of timer frequency
                        tya
                        stal  timer_sound_settings+3               ; high byte of timer frequency
                        
                        jsr   access_doc_registers

                        ldy   #0
:loop                   lda   timer_sound_settings,y               ; Set DOC registers for the interrupt oscillator
                        sta   sound_address
                        iny
                        lda   timer_sound_settings,y
                        sta   sound_data
                        iny
                        cpy   #7*2
                        bne   :loop

                        rep #$20
                        mx  %00
:no_doc_interrupts
                        rts

interrupt_oscillator    =     31
;reference_freq          =     299                   ; interrupt frequence (60Hz)
;reference_freq          =     598                   ; interrupt frequence (120Hz)
reference_freq          =     1195                  ; interrupt frequence (240Hz)
timer_sound_settings    =     *                     ; set up oscillator 30 for interrupts
                        dfb   $00+interrupt_oscillator,reference_freq     ; frequency low register
                        dfb   $20+interrupt_oscillator,reference_freq/256 ; frequency high register
                        dfb   $40+interrupt_oscillator,0                  ; volume register, volume = 0
                        dfb   $80+interrupt_oscillator,0                  ; wavetable pointer register, point to 0
                        dfb   $c0+interrupt_oscillator,0                  ; wavetable size register, 256 byte length
                        dfb   $e1,$3e                                     ; oscillator enable register
                        dfb   $a0+interrupt_oscillator,$08                ; mode register, set to free run

pulse1_oscillator       =     0
pulse2_oscillator       =     2
triangle_oscillator     =     4
noise_oscillator        =     6
dmc_oscillator          =     8
DMC_DOC_PAGE            =     $80                   ; DOC RAM page of the decoded DMC sample ($8000-$FFFF)
DMC_TABLE_SIZE          =     $3F                   ; 32KB table, resolution 7 (one sample per FHL/512 scans)
DMC_VOLUME              =     $FF
default_freq            =     800
pulse1_sound_settings_l =     *
                        dfb   $00+pulse1_oscillator,default_freq      ; frequency low register
                        dfb   $20+pulse1_oscillator,default_freq/256  ; frequency high register
                        dfb   $40+pulse1_oscillator,0                 ; volume register, volume = 0
                        dfb   $80+pulse1_oscillator,3                 ; wavetable pointer register, point to $0300 by default (50% duty cycle)
                        dfb   $c0+pulse1_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a0+pulse1_oscillator,0                 ; mode register, set to free run

pulse1_sound_settings_r =     *
                        dfb   $01+pulse1_oscillator,default_freq      ; frequency low register
                        dfb   $21+pulse1_oscillator,default_freq/256  ; frequency high register
                        dfb   $41+pulse1_oscillator,0                 ; volume register, volume = 0
                        dfb   $81+pulse1_oscillator,3                 ; wavetable pointer register, point to $0300 by default (50% duty cycle)
                        dfb   $c1+pulse1_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a1+pulse1_oscillator,$10               ; mode register, set to free run

pulse2_sound_settings_l =     *
                        dfb   $00+pulse2_oscillator,default_freq      ; frequency low register
                        dfb   $20+pulse2_oscillator,default_freq/256  ; frequency high register
                        dfb   $40+pulse2_oscillator,0                 ; volume register, volume = 0
                        dfb   $80+pulse2_oscillator,3                 ; wavetable pointer register, point to $0300 by default (50% duty cycle)
                        dfb   $c0+pulse2_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a0+pulse2_oscillator,0                 ; mode register, set to free run

pulse2_sound_settings_r =     *
                        dfb   $01+pulse2_oscillator,default_freq      ; frequency low register
                        dfb   $21+pulse2_oscillator,default_freq/256  ; frequency high register
                        dfb   $41+pulse2_oscillator,0                 ; volume register, volume = 0
                        dfb   $81+pulse2_oscillator,3                 ; wavetable pointer register, point to $0300 by default (50% duty cycle)
                        dfb   $c1+pulse2_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a1+pulse2_oscillator,$10                 ; mode register, set to free run

triangle_sound_settings_l =     *
                        dfb   $00+triangle_oscillator,default_freq      ; frequency low register
                        dfb   $20+triangle_oscillator,default_freq/256  ; frequency high register
                        dfb   $40+triangle_oscillator,0               ; volume register, volume = 0
                        dfb   $80+triangle_oscillator,5                 ; wavetable pointer register, point to $0500
                        dfb   $c0+triangle_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a0+triangle_oscillator,0                 ; mode register, set to free run

triangle_sound_settings_r =     *
                        dfb   $01+triangle_oscillator,default_freq      ; frequency low register
                        dfb   $21+triangle_oscillator,default_freq/256  ; frequency high register
                        dfb   $41+triangle_oscillator,0               ; volume register, volume = 0
                        dfb   $81+triangle_oscillator,5                 ; wavetable pointer register, point to $0500
                        dfb   $c1+triangle_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a1+triangle_oscillator,$10                 ; mode register, set to free run

noise_sound_settings_l =     *
                        dfb   $00+noise_oscillator,default_freq      ; frequency low register
                        dfb   $20+noise_oscillator,default_freq/256  ; frequency high register
                        dfb   $40+noise_oscillator,128                 ; volume register, volume = 0
                        dfb   $80+noise_oscillator,6                 ; wavetable pointer register, point to $0600
                        dfb   $c0+noise_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a0+noise_oscillator,0                 ; mode register, set to free run

noise_sound_settings_r =     *
                        dfb   $01+noise_oscillator,default_freq      ; frequency low register
                        dfb   $21+noise_oscillator,default_freq/256  ; frequency high register
                        dfb   $41+noise_oscillator,128                 ; volume register, volume = 0
                        dfb   $81+noise_oscillator,6                 ; wavetable pointer register, point to $0600
                        dfb   $c1+noise_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a1+noise_oscillator,$10                 ; mode register, set to free run

; The DMC oscillators start out halted.  dmc_play sets the frequency and volume and keys them on.
dmc_sound_settings_l    =     *
                        dfb   $00+dmc_oscillator,0                    ; frequency low register
                        dfb   $20+dmc_oscillator,0                    ; frequency high register
                        dfb   $40+dmc_oscillator,0                    ; volume register, volume = 0
                        dfb   $80+dmc_oscillator,DMC_DOC_PAGE         ; wavetable pointer register, decoded sample at $8000
                        dfb   $c0+dmc_oscillator,DMC_TABLE_SIZE       ; wavetable size register, 32KB table
                        dfb   $a0+dmc_oscillator,$03                  ; mode register, one-shot + halted

dmc_sound_settings_r    =     *
                        dfb   $01+dmc_oscillator,0                    ; frequency low register
                        dfb   $21+dmc_oscillator,0                    ; frequency high register
                        dfb   $41+dmc_oscillator,0                    ; volume register, volume = 0
                        dfb   $81+dmc_oscillator,DMC_DOC_PAGE         ; wavetable pointer register, decoded sample at $8000
                        dfb   $c1+dmc_oscillator,DMC_TABLE_SIZE       ; wavetable size register, 32KB table
                        dfb   $a1+dmc_oscillator,$13                  ; mode register, one-shot + halted

backup_interrupt_ptr    ds  4
apu_mode                ds  2

;-----------------------------------------------------------------------------------------
; APU internals
;-----------------------------------------------------------------------------------------
                        mx  %11
clock_length_counter    mac
                        lda   ]1+{APU_PULSE1_REG1-APU_PULSE1}
                        bit   ]2
                        bne   no_count
                        lda   ]1+{APU_PULSE1_LENGTH_COUNTER-APU_PULSE1}
                        beq   no_count                        ; stops at zero (channel is silenced)
                        dec
                        sta   ]1+{APU_PULSE1_LENGTH_COUNTER-APU_PULSE1}
no_count                <<<

clock_linear_counter    mac
                        lda   ]1+{APU_TRIANGLE_START_FLAG-APU_TRIANGLE}
                        beq   do_clock
                        lda   ]1+{APU_TRIANGLE_REG1-APU_TRIANGLE}
                        and   #$7F
                        sta   ]1+{APU_TRIANGLE_LINEAR_COUNTER-APU_TRIANGLE}
                        bra   check_reset

do_clock                lda   ]1+{APU_TRIANGLE_LINEAR_COUNTER-APU_TRIANGLE}
                        beq   check_reset
                        dec
                        sta   ]1+{APU_TRIANGLE_LINEAR_COUNTER-APU_TRIANGLE}

check_reset
                        lda   ]1+{APU_TRIANGLE_REG1-APU_TRIANGLE}
                        bmi   no_reset
                        stz   ]1+{APU_TRIANGLE_START_FLAG-APU_TRIANGLE}
no_reset                <<<

clock_sweep             mac
                        lda   ]1+{APU_PULSE1_SWEEP_DIVIDER-APU_PULSE1}
                        dec
                        sta   ]1+{APU_PULSE1_SWEEP_DIVIDER-APU_PULSE1}
                        bpl   no_sweep

                        lda   #1
                        sta   ]1+{APU_PULSE1_RELOAD_FLAG-APU_PULSE1}

                        lda   ]1+{APU_PULSE1_REG2-APU_PULSE1} ; get the barrel shift argument from the register
                        bpl   no_sweep                        ; if sweep is not enabled, do nothing
                        and   #$07
                        beq   no_sweep                        ; shift must be != 0
                        asl
                        tax

                        lda   ]1+{APU_PULSE1_REG2-APU_PULSE1}  ; put the negate flag in the y register
                        and   #$08
                        tay

                        rep   #$20
                        lda   ]1+{APU_PULSE1_CURRENT_PERIOD-APU_PULSE1}
                        cmp   #8
                        bcc   no_sweep0                 ; current period must be >= 8
                        jmp   (bitshift,x)              ; shift it by the shifter amount
bitshift                da    bitshift_0,bitshift_1,bitshift_2,bitshift_3,bitshift_4,bitshift_5,bitshift_6,bitshift_7
bitshift_7              lsr
bitshift_6              lsr
bitshift_5              lsr
bitshift_4              lsr
bitshift_3              lsr
bitshift_2              lsr
bitshift_1              lsr
bitshift_0
                        cpy   #0                            ; check if the negate flag was set
                        beq   no_negate
                        eor   #$FFFF                        ; pulse 1 uses 1's complement
                        DO    ]2
                        inc
                        FIN
no_negate               clc
                        adc   ]1+{APU_PULSE1_CURRENT_PERIOD-APU_PULSE1}
                        cmp   #$800
                        bcs   no_sweep0
                        sta   ]1+{APU_PULSE1_CURRENT_PERIOD-APU_PULSE1}
no_sweep0
                        sep   #$20
no_sweep
                        lda   ]1+{APU_PULSE1_RELOAD_FLAG-APU_PULSE1} ; check if we need to reload the sweep delay
                        beq   no_reload
                        stz   ]1+{APU_PULSE1_RELOAD_FLAG-APU_PULSE1}
                        lda   ]1+{APU_PULSE1_REG2-APU_PULSE1}
                        lsr
                        lsr
                        lsr
                        lsr
                        and   #7
                        sta   ]1+{APU_PULSE1_SWEEP_DIVIDER-APU_PULSE1}
no_reload               <<<

clock_envelope          mac
                        lda   ]1+{APU_PULSE1_START_FLAG-APU_PULSE1}
                        beq   no_start
                        stz   ]1+{APU_PULSE1_START_FLAG-APU_PULSE1} ; clear the start flag
                        lda   #15
                        sta   ]1+{APU_PULSE1_ENVELOPE-APU_PULSE1} ; reset the envelope saw wave decay value
                        lda   ]1+{APU_PULSE1_REG1-APU_PULSE1}
                        and   #$0F
                        sta   ]1+{APU_PULSE1_ENVELOPE_DIVIDER-APU_PULSE1} ; reset the divider value
                        bra   envelope_out        ; nothing else to do

no_start
                        lda   ]1+{APU_PULSE1_ENVELOPE_DIVIDER-APU_PULSE1} ; clock the divider
                        dec
                        sta   ]1+{APU_PULSE1_ENVELOPE_DIVIDER-APU_PULSE1}
                        bpl   envelope_out        ; as long as divider is >=0, nothing to do

                        lda   ]1+{APU_PULSE1_REG1-APU_PULSE1}         ; reset the divider to the volume/envelope value
                        and   #$0F
                        sta   ]1+{APU_PULSE1_ENVELOPE_DIVIDER-APU_PULSE1}

                        lda   ]1+{APU_PULSE1_ENVELOPE-APU_PULSE1}
                        bne   tick_envelope

                        lda   ]1+{APU_PULSE1_REG1-APU_PULSE1} ; if decay level counter is 0, check the loop bit and set counter to 15 if loop bit is set
                        bit   #PULSE_HALT_FLAG
                        beq   envelope_out
                        lda   #16                         ; Set to 15
tick_envelope
                        dec
                        sta   ]1+{APU_PULSE1_ENVELOPE-APU_PULSE1}
envelope_out            <<<

half_frame_clock
; clock the length counters
                        clock_length_counter APU_PULSE1;#PULSE_HALT_FLAG
                        clock_length_counter APU_PULSE2;#PULSE_HALT_FLAG
                        clock_length_counter APU_TRIANGLE;#TRIANGLE_HALT_FLAG
                        clock_length_counter APU_NOISE;#NOISE_HALT_FLAG

; clock the sweep units
                        clock_sweep  APU_PULSE1;0
                        clock_sweep  APU_PULSE2;1
                        rts

quarter_frame_clock
; clock the envelopes and triangle linear counter
                        clock_linear_counter APU_TRIANGLE

                        clock_envelope APU_PULSE1
                        clock_envelope APU_PULSE2
                        clock_envelope APU_NOISE
                        rts

;-----------------------------------------------------------------------------------------
; interupt handler
;-----------------------------------------------------------------------------------------

; The frame sequencer runs the 4-step pattern (Q, Q+H, Q, Q+H at 240Hz).  The NES 5-step mode
; ($4017 bit 7) has a silent fifth step, but games such as Zelda write $4017 once per video frame,
; which clocks Q+H immediately and restarts the sequence -- that also works out to exactly
; 4 quarter-frame and 2 half-frame clocks per 1/60s, so the 4-step pattern is used for both.
apu_frame_steps      equ 4
PULSE_HALT_FLAG      equ $20
NOISE_HALT_FLAG      equ $20     ; noise and pulse channels have halt flag in same bit position in REG1
PULSE_CONST_VOL_FLAG equ $10
NOISE_CONST_VOL_FLAG equ $10
TRIANGLE_HALT_FLAG   equ $80

                        mx %11
APU_quarter_speed_driver    = *

                        phb
                        phd

                        phk
                        plb

                        pea  $c000
                        pld

; Quarter-speed driver (60Hz) -- one call covers a whole 4-step sequence: 2 half-frame and
; 4 quarter-frame clocks
                        jsr   half_frame_clock
                        jsr   quarter_frame_clock
                        jsr   quarter_frame_clock
                        jsr   half_frame_clock
                        jsr   quarter_frame_clock
                        jsr   quarter_frame_clock

                        brl   update_doc_registers

                        mx %11
interrupt_handler       = *

;                        ldal  show_border
;                        beq   :no_show
;                        ldal  $E0C034                    ; save the border color
;                        stal  border_color
;                        lda   #1
;                        jsr   setborder
;:no_show

                        phb
                        phd

                        phk
                        plb

                        clc
                        xce

                        pea  $c000
                        pld

; Make sure it's the oscillator we care about

                        ldal  osc_interrupt             ; which oscillator generated the interrupt?
                        and   #%00111110
                        cmp   #2*interrupt_oscillator
                        beq   *+5
                        brl   :not_timer                ; Only service timer interrupts

; Update the frame counter and leave the doubled countin x-register for dispatch
                        ldx   apu_frame_counter
                        inx
                        inx
                        cpx   #2*apu_frame_steps
                        bcc   *+4
                        ldx   #0
                        stx   apu_frame_counter

; Figure out which speed we are dispatching
                        lda   apu_mode
                        cmp   #APU_240HZ
                        beq   :do_240hz_mode
                        jmp   (:apu_120hz_table,x)
:do_240hz_mode          jmp   (:apu_240hz_table,x)
:apu_240hz_table        da    :quarter_frame_240,:half_frame_240,:quarter_frame_240,:half_frame_240
:apu_120hz_table        da    :half_frame_120,:half_frame_120,:half_frame_120,:half_frame_120

; Full speed emulation (240Hz)
:half_frame_240         jsr   half_frame_clock
:quarter_frame_240      jsr   quarter_frame_clock
                        bra   update_doc_registers

; Half-speed interrupts (120Hz) -- clock twice in each handler
:half_frame_120
:quarter_frame_120
                        jsr   half_frame_clock
                        jsr   quarter_frame_clock
                        jsr   quarter_frame_clock

; Apply any changes to the DOC registers
update_doc_registers

                        jsr   access_doc_registers

; Set the parameters for the first square wave channel.
;
; First, set the frequency, if the period is <8 then the pulse channel is muted,
; to test that first
                        lda   APU_PULSE1_MUTE                ; If the sweep muted the channel, no output
                        bne   :mute_pulse1
                        lda   APU_PULSE1_LENGTH_COUNTER      ; If the length counter is zero, no output
                        beq   :mute_pulse1
                        rep   #$30
                        lda   APU_PULSE1_CURRENT_PERIOD
                        cmp   #8
                        bcc   :mute_pulse1

                        cmp   _apu_pulse1_last_period         ; it's expensive to recalc frequencies, so avoid it when possible
                        beq   :freq_end_pulse1
                        sta   _apu_pulse1_last_period
                        jsr   get_pulse_freq                  ; return freq in 16-bit accumulator
                        sep   #$30

                        ldx   #$00+pulse1_oscillator
                        jsr   set_osc_register_pair
;                        stx   sound_address
;                        sta   sound_data
                        ldx   #$20+pulse1_oscillator
;                        stx   sound_address
                        xba
                        jsr   set_osc_register_pair
;                        sta   sound_data
:freq_end_pulse1        sep   #$30                           ; redundent, but avoids extra branches

                        ldx   #$80+pulse1_oscillator
;                        sta   sound_address
                        lda   APU_PULSE1_REG1                ; Get the cycle duty bits
                        jsr   set_pulse_duty_cycle

                        ldx   #$40+pulse1_oscillator
;                        sta   sound_address
                        lda   APU_PULSE1_REG1
                        bit   #PULSE_CONST_VOL_FLAG           ; Check the constant volume bit
                        bne   :set_volume_pulse1
                        lda   APU_PULSE1_ENVELOPE
                        bra   :set_volume_pulse1

:mute_pulse1
                        sep   #$30
                        ldx   #$40+pulse1_oscillator
;                        sta   sound_address
                        lda   #0
:set_volume_pulse1      jsr   set_pulse_volume


; Now do the second square wave
                        lda   APU_PULSE2_MUTE                ; If the sweep muted the channel, no output
                        bne   :mute_pulse2
                        lda   APU_PULSE2_LENGTH_COUNTER      ; If the length counter is zero, no output
                        beq   :mute_pulse2
                        rep   #$30
                        lda   APU_PULSE2_CURRENT_PERIOD
                        cmp   #8
                        bcc   :mute_pulse2

                        cmp   _apu_pulse2_last_period
                        beq   :freq_end_pulse2
                        sta   _apu_pulse2_last_period
                        jsr   get_pulse_freq                  ; return freq in 16-bic accumulator
                        sep   #$30
                        ldx   #$00+pulse2_oscillator
;                        stx   sound_address
;                        sta   sound_data
                        jsr   set_osc_register_pair
                        ldx   #$20+pulse2_oscillator
;                        stx   sound_address
                        xba
;                        sta   sound_data
                        jsr   set_osc_register_pair
:freq_end_pulse2        sep   #$30

                        ldx   #$80+pulse2_oscillator
;                        sta   sound_address
                        lda   APU_PULSE2_REG1           ; Get the cycle duty bits
                        jsr   set_pulse_duty_cycle

                        ldx   #$40+pulse2_oscillator
;                        sta   sound_address
                        lda   APU_PULSE2_REG1
                        bit   #PULSE_CONST_VOL_FLAG      ; Check the constant volume bit
                        bne   :set_volume_pulse2
                        lda   APU_PULSE2_ENVELOPE
                        bra   :set_volume_pulse2
:mute_pulse2
                        sep   #$30
                        ldx   #$40+pulse2_oscillator
;                        sta   sound_address
                        lda   #0
:set_volume_pulse2      jsr   set_pulse_volume

; Now the triangle wave.  This wave needs linear counter support to be silenced

                        lda   APU_TRIANGLE_LENGTH_COUNTER      ; If the length counter is zero, no output
                        beq   :mute_triangle
                        lda   APU_TRIANGLE_LINEAR_COUNTER      ; If the linear counter is zero, no output
                        beq   :mute_triangle
                        rep   #$30
                        lda   APU_TRIANGLE_CURRENT_PERIOD
                        cmp   #2
                        bcc   :mute_triangle

; NOTE on Triangle channel frequence from https://www.nesdev.org/wiki/APU_Triangle
;
; Unlike the pulse channels, the triangle channel supports frequencies up to the maximum frequency the
; timer will allow, meaning frequencies up to fCPU/32 (about 55.9 kHz for NTSC) are possible - far above
; the audible range. Some games, e.g. Mega Man 2, "silence" the triangle channel by setting the timer to
; zero, which produces a popping sound when an audible frequency is resumed, easily heard e.g. in Crash
; Man's stage. At the expense of accuracy, these can be eliminated in an emulator e.g. by halting the
; triangle channel when an ultrasonic frequency is set (a timer value less than 2).

                        cmp   _apu_triangle_last_period
                        beq   :freq_end_triangle
                        sta   _apu_triangle_last_period
                        jsr   get_pulse_freq                  ; return freq in 16-bic accumulator
                        lsr
                        sep   #$30
                        ldx   #$00+triangle_oscillator
;                        stx   sound_address
;                        sta   sound_data
                        jsr   set_osc_register_pair
                        ldx   #$20+triangle_oscillator
;                        stx   sound_address
                        xba
;                        sta   sound_data
                        jsr   set_osc_register_pair
:freq_end_triangle      sep   #$30

                        ldx   #$40+triangle_oscillator
;                        sta   sound_address
                        lda   #12                             ; Triangle is a bit softer than pulse channels
                        jsr   set_pulse_volume
                        bra   :end_triangle

; A silenced NES triangle doesn't drop to zero: it holds its current output level and resumes
; from the same point.  Muting by volume cut the wave at a random point, with a pop at every
; note start and stop.  Instead, a frequency of 0 stops the DOC oscillator stepping so it holds
; its current sample.  The last-period cache is cleared so the next note rewrites the frequency.
:mute_triangle
                        sep   #$30
                        lda   #0
                        ldx   #$00+triangle_oscillator
                        jsr   set_osc_register_pair
                        ldx   #$20+triangle_oscillator
                        jsr   set_osc_register_pair
                        lda   #$FF
                        sta   _apu_triangle_last_period
                        sta   _apu_triangle_last_period+1
:end_triangle

; Now the noise channel.  It's mixer volume output is ~half of the pulse channels

                        lda   APU_NOISE_LENGTH_COUNTER      ; If the length counter is zero, no output
                        beq   :mute_noise

                        ldx   #$00+noise_oscillator
;                        stx   sound_address
                        lda   APU_NOISE_CURRENT_PERIOD
;                        sta   sound_data
                        jsr   set_osc_register_pair
                        ldx   #$20+noise_oscillator
;                        stx   sound_address
                        lda   APU_NOISE_CURRENT_PERIOD+1
;                        sta   sound_data
                        jsr   set_osc_register_pair

                        ldx   #$40+noise_oscillator
;                        sta   sound_address
                        lda   APU_NOISE_REG1
                        bit   #NOISE_CONST_VOL_FLAG        ; Check the constant volume bit
                        bne   :set_volume_noise
                        lda   APU_NOISE_ENVELOPE
                        bra   :set_volume_noise
:mute_noise
                        ldx   #$40+noise_oscillator
;                        sta   sound_address
                        lda   #0
:set_volume_noise
                        and   #$0F
                        asl
                        asl
                        asl
                        pha
                        lda   APU_NOISE_REG3               ; Up the volume for low sounds
                        bit   #$08
                        beq   :high_pitch
                        pla
                        asl
                        pha
:high_pitch             pla
;                        sta   sound_data
                        jsr   set_osc_register_pair

:not_timer
no_frame
;                        ldal  show_border
;                        beq   :no_show2
;                        ldal  border_color
;                        jsr   setborder
;:no_show2

                        pld
                        plb
                        clc
                        rtl

; X = addr
; A = data
set_osc_register_pair
                        mx    %11
                        stx   sound_address
                        sta   sound_data
                        inc   sound_address
                        sta   sound_data
                        rts

; X = addr
; A = duty cycle select
set_pulse_duty_cycle
                        mx    %11
                        rol
                        rol
                        rol
                        and   #$03
                        tay

                        lda   duty_cycle_page,y
                        jmp   set_osc_register_pair
;                        sta   sound_data
;                        rts

set_pulse_volume
                        and   #$0F
                        asl
                        asl
                        asl
                        asl
                        jmp   set_osc_register_pair
;                        sta   sound_data
;                        rts

; This is a bit different because we actually calculate a scan rate directly to match the
; rate at which new samples are read form DOC RAM to the period of the noise channel
;
; IIgs Scan Rate (SR) = 894886 Hz / (OSC + 2) = 894886 Hz / 34 = 26320.1765 samples / sec
; IIgs Sample Rate = 51.406 * F_HL samples / sec

;  We have 256 samples
; NES Noise Sample Rate = 1789772 Hz / P
;
; An as example, let P = 8, so a new sample should be output 
; Solving for F_HL: F_HL = 1789772 / (51.406 * 8) = 4352
get_noise_freq


; NES freq = f_CPU / (16 * (t + 1))
;          = 1.789773 MHz / (16 * (t + 1))
;          = 111860.812 Hz / (t + 1)
;
; IIgs freq = 0.200807 * F_HL (for 32 oscillators with DOC RES = 0)
;
; Solving for F_HL = (1 / 0.200807) * 111860.812 / (t + 1)
;                  = 557056.338 / (t + 1)
;
; if t < 8 this value is out of range and the oscillator should be silenced
;
; otherwise, break apart the ratio
;
; f_HL = 10 * (55706 / (t + 1))
; 
get_pulse_freq
                        mx %00
                        and   #$7FF                     ; prevent overflow...
                        inc
                        sta   divisor
                        lda   #55706
                        sta   dividend

                        lda   #0
                        ldx   #16                       ; 16 bits of division
                        asl   dividend
:dl1                    rol
                        cmp   divisor
                        bcc   :dl2
                        sbc   divisor
:dl2                    rol   dividend
                        dex
                        bne   :dl1

                        lda   dividend
                        sta   dividend
                        asl
                        asl
                        clc
                        adc   dividend                  ; multiple by 10 to get the DOC value
                        asl
                        rts

turn_off_interrupts
                        php
                        sep   #$20
                        lda   #$a0+interrupt_oscillator
                        sta   sound_address
                        lda   #0
                        sta   sound_data
                        plp
                        rts

; Internal APU registers.
;
; These variables track the internal flags, counters and other status bits that make up 
; the core functionality of the different channel hardware

apu_frame_counter dw 0                  ; frame counter, clocked at 240Hz from the interrupt handler

duty_cycle_page dfb $01,$02,$03,$04     ; Page of DOC RAM that holds the different duty cycle wavforms
show_border     dw 0
border_color    dw 0
dividend        dw 0                    ; Used when converting from NES APU values to DOC values
divisor         dw 0

; Pulse Channel 1
APU_PULSE1      ENT
APU_PULSE1_REG1 ds 1    ; DDLC NNNN - Duty, length counter halt, constant volume/evelope, envelope period/volume
APU_PULSE1_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_PULSE1_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_PULSE1_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_PULSE1_LENGTH_COUNTER   dfb 0 ; internal register for the length counter
APU_PULSE1_RELOAD_FLAG      dfb 0 ; internal register to reload the sweep divider value
APU_PULSE1_SWEEP_DIVIDER    dfb 0 ; internal register to track the sweep divider value
APU_PULSE1_TARGET_PERIOD    dw  0 ; internal register to hold the sweep unit target period
APU_PULSE1_CURRENT_PERIOD   dw  0 ; internal register to hold the current period driving the oscillator
APU_PULSE1_MUTE             dfb 0
APU_PULSE1_START_FLAG       dfb 0 
APU_PULSE1_ENVELOPE_DIVIDER dfb 0
APU_PULSE1_ENVELOPE         dfb 0

_apu_pulse1_last_period     dw  $FFFF ; optimization


APU_PULSE2      ENT
APU_PULSE2_REG1 ds 1    ; DDLC NNNN - Duty, length counter halt, constant volume/evelope, envelope period/volume
APU_PULSE2_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_PULSE2_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_PULSE2_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_PULSE2_LENGTH_COUNTER dfb 0 ; internal register for the length counter
APU_PULSE2_RELOAD_FLAG    dfb 0 ; internal register to reload the sweep divider value
APU_PULSE2_SWEEP_DIVIDER  dfb 0 ; internal register to track the sweep divider value
APU_PULSE2_TARGET_PERIOD  dw  0 ; internal register to hold the sweep unit target period
APU_PULSE2_CURRENT_PERIOD dw  0 ; internal register to hold the current period driving the oscillator
APU_PULSE2_MUTE             dfb 0
APU_PULSE2_START_FLAG       dfb 0 
APU_PULSE2_ENVELOPE_DIVIDER dfb 0
APU_PULSE2_ENVELOPE         dfb 0

_apu_pulse2_last_period   dw  $FFFF ; optimization


APU_TRIANGLE
APU_TRIANGLE_REG1 ds 1    ; DDLC NNNN - Duty, loop envelope/disable length counter, constant volume, envelope period/volume
APU_TRIANGLE_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_TRIANGLE_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_TRIANGLE_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_TRIANGLE_LENGTH_COUNTER dfb 0
APU_TRIANGLE_CURRENT_PERIOD dw 0
APU_TRIANGLE_START_FLAG dfb 0
APU_TRIANGLE_LINEAR_COUNTER dfb 0

_apu_triangle_last_period   dw  $FFFF ; optimization


APU_NOISE
APU_NOISE_REG1 ds 1    ; --LC NNNN - length counter halt, constant volume/evelope, envelope period/volume
APU_NOISE_REG2 ds 1    ; ---- ---- - Unused
APU_NOISE_REG3 ds 1    ; M--- PPPP - Mode and period lookup
APU_NOISE_REG4 ds 1    ; llll l--- - Length counter load

APU_NOISE_LENGTH_COUNTER   dfb 0 ; internal register for the length counter
APU_NOISE_RELOAD_FLAG      dfb 0 ; unused
APU_NOISE_SWEEP_DIVIDER    dfb 0 ; unused
APU_NOISE_TARGET_PERIOD    dw  0 ; unused
APU_NOISE_CURRENT_PERIOD   dw  0 ; internal register to hold the current period driving the oscillator
APU_NOISE_MUTE             dfb 0 ; unused
APU_NOISE_START_FLAG       dfb 0 
APU_NOISE_ENVELOPE_DIVIDER dfb 0
APU_NOISE_ENVELOPE         dfb 0

_apu_noise_last_period   dw  $FFFF ; optimization


APU_STATUS      ds 1

    mx %11
APU_PULSE1_REG1_WRITE ENT
    stal  APU_PULSE1_REG1
    rtl

APU_PULSE1_REG2_WRITE ENT
    php
    pha
    stal  APU_PULSE1_REG2
    lda   #1
    stal  APU_PULSE1_RELOAD_FLAG      ; mark that this register was written to
    pla
    plp
    rtl

APU_PULSE1_REG3_WRITE ENT
    stal  APU_PULSE1_CURRENT_PERIOD
    stal  APU_PULSE1_REG3
    rtl

APU_PULSE1_REG4_WRITE ENT
    php
    phx
    pha

    stal  APU_PULSE1_REG4
    and   #$07
    stal  APU_PULSE1_CURRENT_PERIOD+1

; If the APU_STATUS bit is enabled, then load the length counter
    ldal  APU_STATUS
    bit   #$01
    beq   :no_reload

    ldal  APU_PULSE1_REG4
    and   #$F8
    lsr
    lsr
    lsr
    tax
    ldal  LengthTable,x
    stal  APU_PULSE1_LENGTH_COUNTER  ; Immediately start the counter
    lda   #1
    stal  APU_PULSE1_START_FLAG

:no_reload
    pla
    plx
    plp
    rtl

; From https://www.nesdev.org/wiki/APU_Length_Counter
LengthTable
    db    10,254, 20,  2, 40,  4, 80,  6, 160,  8, 60, 10, 14, 12, 26, 14
    db    12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30

APU_PULSE2_REG1_WRITE ENT
    stal  APU_PULSE2_REG1
    rtl

APU_PULSE2_REG2_WRITE ENT
    php
    pha
    stal  APU_PULSE2_REG2
    lda   #1
    stal  APU_PULSE2_RELOAD_FLAG
    pla
    plp
    rtl

APU_PULSE2_REG3_WRITE ENT
    stal  APU_PULSE2_CURRENT_PERIOD
    stal  APU_PULSE2_REG3
    rtl

APU_PULSE2_REG4_WRITE ENT
    php
    phx
    pha

    stal  APU_PULSE2_REG4
    and   #$07
    stal  APU_PULSE2_CURRENT_PERIOD+1

    ldal  APU_STATUS
    bit   #$02
    beq   :no_reload

    ldal  APU_PULSE2_REG4
    and   #$F8
    lsr
    lsr
    lsr
    tax
    ldal  LengthTable,x
    stal  APU_PULSE2_LENGTH_COUNTER  ; Immediately start the counter
    lda   #1
    stal  APU_PULSE2_START_FLAG

:no_reload
    pla
    plx
    plp
    rtl


APU_TRIANGLE_REG1_WRITE ENT
    stal  APU_TRIANGLE_REG1
    rtl

APU_TRIANGLE_REG2_WRITE ENT
    stal  APU_TRIANGLE_REG2
    rtl

APU_TRIANGLE_REG3_WRITE ENT
    stal  APU_TRIANGLE_CURRENT_PERIOD
    stal  APU_TRIANGLE_REG3
    rtl

APU_TRIANGLE_REG4_WRITE ENT
    php
    phx
    pha

    stal  APU_TRIANGLE_REG4
    and   #$07
    stal  APU_TRIANGLE_CURRENT_PERIOD+1

; A $400B write always sets the linear counter reload flag, even when the channel is disabled
    lda   #1
    stal  APU_TRIANGLE_START_FLAG

; The length counter only loads when the channel is enabled in $4015
    ldal  APU_STATUS
    bit   #$04
    beq   :no_reload

    ldal  APU_TRIANGLE_REG4
    and   #$F8
    lsr
    lsr
    lsr
    tax
    ldal  LengthTable,x
    stal  APU_TRIANGLE_LENGTH_COUNTER  ; Immediately start the counter

:no_reload
    pla
    plx
    plp
    rtl


APU_NOISE_REG1_WRITE ENT
    stal  APU_NOISE_REG1
    rtl

APU_NOISE_REG2_WRITE ENT
    stal  APU_NOISE_REG2
    rtl

APU_NOISE_REG3_WRITE ENT
    php
    phx
    pha

    stal  APU_NOISE_REG3
    and   #$0F
    asl
    tax
;    ldal  NoisePeriodTable,x
    ldal  EsqNoiseFreqTable,x
    stal  APU_NOISE_CURRENT_PERIOD
;    ldal  NoisePeriodTable+1,x
    ldal  EsqNoiseFreqTable+1,x
    stal  APU_NOISE_CURRENT_PERIOD+1

    pla
    plx
    plp
    rtl

APU_NOISE_REG4_WRITE ENT
    php
    phx
    pha

    stal  APU_NOISE_REG4

    ldal  APU_STATUS
    bit   #$08
    beq   :no_reload

    ldal  APU_NOISE_REG4
    and   #$F8
    lsr
    lsr
    lsr
    tax
    ldal  LengthTable,x
    stal  APU_NOISE_LENGTH_COUNTER  ; Immediately start the counter
    lda   #1
    stal  APU_NOISE_START_FLAG

:no_reload
    pla
    plx
    plp
    rtl

; Lookup from bottom 4 bits of NOISE_REG3 and pre-calculated ensoniq parameters
NoisePeriodTable  dw 4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068
;EsqNoiseFreqTable dw 8704, 4352, 2176, 1088, 544, 363, 272, 218, 172, 137, 92, 69, 46, 34, 17, 9
EsqNoiseFreqTable dw 1088, 544, 272, 136, 68, 45,34,27,22,17,12,9,6,4,2,1

APU_FORCE_OFF dw 0

APU_STATUS_FORCE
    php
    phb
    phk
    plb
    pha
    sta   APU_STATUS
    bra   force_entry

; Reading $4015 reports which channels have a length counter > 0 (bits 0-3)
APU_STATUS_READ ENT
    lda   #0
    pha                           ; build the return value

    ldal  APU_PULSE1_LENGTH_COUNTER
    beq   :pulse1_done
    lda   #$01
    ora   1,s
    sta   1,s
:pulse1_done

    ldal  APU_PULSE2_LENGTH_COUNTER
    beq   :pulse2_done
    lda   #$02
    ora   1,s
    sta   1,s
:pulse2_done

    ldal  APU_TRIANGLE_LENGTH_COUNTER
    beq   :triangle_done
    lda   #$04
    ora   1,s
    sta   1,s
:triangle_done

    ldal  APU_NOISE_LENGTH_COUNTER
    beq   :noise_done
    lda   #$08
    ora   1,s
    sta   1,s
:noise_done

    pla                           ; N/Z flags reflect the returned value
    rtl


APU_STATUS_WRITE ENT
    php
    phb
    phk
    plb
    pha
    sta   APU_STATUS

    phx
    ldx   APU_FORCE_OFF
    bne   force_exit
    plx

force_entry

; From NESDev Wiki: When the enabled bit is cleared (via $4015), the length counter is forced to 0
;             and cannot be changed until enabled is set again (the length counter's previous value is lost).
;             There is no immediate effect when enabled is set.

; Pulse 1
    bit  #$01
    bne  :pulse1_on
    stz  APU_PULSE1_LENGTH_COUNTER
:pulse1_on

; Pulse 2
    bit  #$02
    bne  :pulse2_on
    stz  APU_PULSE2_LENGTH_COUNTER
:pulse2_on

; Triangle
    bit  #$04
    bne  :triangle_on
    stz  APU_TRIANGLE_LENGTH_COUNTER
:triangle_on

; Noise
    bit  #$08
    bne  :noise_on
    stz  APU_NOISE_LENGTH_COUNTER
:noise_on

; DMC -- clearing the bit stops the sample, setting it starts one if none is playing
    bit  #$10
    bne  :dmc_on
    jsr  dmc_disable
    bra  :dmc_done
:dmc_on
    jsr  dmc_enable
:dmc_done

    pla
    plb
    plp
    rtl

force_exit
    plx
    pla
    plb
    plp
    rtl

;-----------------------------------------------------------------------------------------
; DMC (delta modulation) channel
;
; The NES DMC plays a 1-bit delta sample: each bit moves a 7-bit output level by +/-2.  Samples
; are decoded to 8-bit PCM in DOC RAM and played once on oscillators 8/9.
;
; Decimation: with 32 oscillators enabled the DOC can't step faster than 26.3kHz, so the DMC
; bit rate is reduced -- 2:1 for rate index 0-11 and 4:1 for 12-15 (~16.9-33.1kHz).
;
; Two modes, picked by CACHE_DMC_SAMPLES in the game's Main.s:
;
;  CACHE_DMC_SAMPLES = 1  The game lists its samples in DMC_SAMPLE_LIST.  APUCacheDMC decodes
;                         them all into DOC RAM at start-up, and $4015 plays the one whose
;                         $4012/$4013 match.  A sample that isn't listed is not played.
;
;  CACHE_DMC_SAMPLES = 0  Generic fallback: the sample is decoded into DOC RAM $8000-$FFFF when
;                         $4015 starts it, and re-decoded only when $4012/$4013 or the
;                         decimation change.  The game pauses while a sample decodes.
;
; DMC_SAMPLE_LIST format: a count byte, then one 3-byte entry per sample -- the $4012 address
; byte, the $4013 length byte and the $4010 rate index (which sets the decimation).
;
; $4011 (direct load) only sets the level a fallback sample starts decoding from; cached samples
; start at the middle level.  It does not change the output by itself.
;
; Not implemented: the loop and IRQ flags in $4010, and the DMC bit when reading $4015.
;-----------------------------------------------------------------------------------------

DMC_DOC_FLOOR      =  $07      ; first DOC RAM page free for cached samples (pages 0-6 hold the timer and instrument waves)
DMC_START_LEVEL    =  64       ; starting level for cached samples (no $4011 value at start-up)
DMC_CACHE_MAX      =  16       ; most samples DMC_SAMPLE_LIST can hold

APU_DMC_REG1 ds 1    ; IL-- RRRR - IRQ enable, loop, rate index
APU_DMC_REG2 ds 1    ; -DDD DDDD - direct load (starting level for the next fallback decode)
APU_DMC_REG3 ds 1    ; AAAA AAAA - sample address = $C000 + A * 64
APU_DMC_REG4 ds 1    ; LLLL LLLL - sample length = L * 16 + 1 bytes

; Decoder inputs
dmc_src_start      dw  0       ; first NES sample byte
dmc_src_end        dw  0       ; end of the NES sample data
dmc_doc_base       dw  0       ; DOC RAM address of the decoded sample
dmc_dec_shift      dw  0       ; 1 = 2:1, 2 = 4:1
dmc_start_level    dw  0       ; level the decode starts from (0-127)
dmc_bias           dw  0       ; low byte = $80 - starting level, added to each output level
dmc_outs_left      dw  0       ; output samples left in the current source byte

; Oscillator setup for the next sample
dmc_play_page      dw  0       ; DOC RAM page of the sample
dmc_play_size      dw  0       ; wavetable size register (table size and resolution)
dmc_play_shift     dw  0       ; decimation of the sample (1 = 2:1, 2 = 4:1)

; Fallback mode: the sample currently decoded at $8000
dmc_cache_key      dw  $FFFF   ; $4012/$4013 of the sample in DOC RAM
dmc_cache_shift    dw  0       ; decimation of the sample in DOC RAM (0 = nothing decoded)

; DOC frequency (FHL) for each rate index, times 4.  Output rate = 51.4066 * FHL with 32
; oscillators, so FHL = (1789773 / CPU cycles per bit) / decimation / 51.4066 -- dmc_play
; divides this by 4 * decimation.
DmcFreqTable dw  325,366,410,435,487,548,616,651,733,870,981,1088,1314,1658,1934,2579

    mx %11
APU_DMC_REG1_WRITE ENT
    stal  APU_DMC_REG1
    rtl

APU_DMC_REG2_WRITE ENT
    stal  APU_DMC_REG2
    rtl

APU_DMC_REG3_WRITE ENT
    stal  APU_DMC_REG3
    rtl

APU_DMC_REG4_WRITE ENT
    stal  APU_DMC_REG4
    rtl

; Clock one delta bit from the accumulator into the level in Y (0-127)
                        mx    %10
DMC_BIT                 mac
                        lsr                             ; next delta bit -> carry
                        bcc   dmc_bit_down
                        cpy   #126                      ; +2, unless that passes 127
                        bcs   dmc_bit_done
                        iny
                        iny
                        bra   dmc_bit_done
dmc_bit_down            cpy   #2                        ; -2, unless that passes 0
                        bcc   dmc_bit_done
                        dey
                        dey
dmc_bit_done            <<<

; Write the level in Y to DOC RAM, preserving the remaining delta bits in the accumulator.  The
; output is centred on the starting level ($80 + level - start), so a sample starts at silence
; instead of jumping to its absolute level.  The range is 1-255; a $00 would halt the DOC.
DMC_OUT                 mac
                        xba                             ; park the delta bits in B
                        tya
                        clc
                        adc   dmc_bias
                        sta   sound_data
                        xba
                        <<<

; $4015 bit 4 cleared: stop the sample
;
; Called from APU_STATUS_WRITE with B = K
                        mx    %11
dmc_disable
                        php
                        phd
                        pea   $c000
                        pld
                        sei

                        jsr   access_doc_registers
                        lda   #$a0+dmc_oscillator
                        sta   sound_address
                        lda   #$03                      ; one-shot + halted
                        sta   sound_data
                        inc   sound_address
                        lda   #$13
                        sta   sound_data

                        pld
                        plp
                        rts

; $4015 bit 4 set: start the sample, unless one is still playing
;
; Called from APU_STATUS_WRITE with B = K.  Preserves X and Y for the ROM code.
                        mx    %11
dmc_enable
                        php
                        phx
                        phy
                        phd
                        pea   $c000
                        pld
                        rep   #$10
                        mx    %10

; Writing a 1 has no effect while a sample is still playing.  The DOC sets the halt bit
; itself when a one-shot reaches the $00 at the end of the sample.

                        php
                        sei
                        jsr   access_doc_registers
                        lda   #$a0+dmc_oscillator
                        sta   sound_address
                        lda   sound_data                ; DOC register reads return the previously latched value
                        lda   sound_data
                        plp
                        lsr                             ; halt bit -> carry
                        bcs   *+5
                        brl   dmc_exit

                        DO    CACHE_DMC_SAMPLES
; Find the catalogued sample with this $4012/$4013.  Samples that aren't listed are not played.

                        ldx   #0                        ; offset into DMC_SAMPLE_LIST
                        ldy   #0                        ; sample number
dmc_find                cpy   dmc_cat_count
                        bcc   *+5
                        brl   dmc_exit
                        rep   #$20
                        lda   DMC_SAMPLE_LIST+1,x       ; $4012 | $4013 << 8
                        cmp   APU_DMC_REG3
                        sep   #$20
                        beq   dmc_found
                        inx
                        inx
                        inx
                        iny
                        bra   dmc_find
dmc_found
                        lda   dmc_cat_page,y
                        sta   dmc_play_page
                        lda   dmc_cat_size,y
                        sta   dmc_play_size
                        lda   dmc_cat_shift,y
                        sta   dmc_play_shift

                        ELSE
; Decode the sample into $8000 unless it is the one already there

                        lda   APU_DMC_REG1
                        jsr   dmc_rate_shift
                        sta   dmc_play_shift
                        lda   #$80                      ; $8000-$FFFF as one 32KB table
                        sta   dmc_play_page
                        lda   #$3F
                        sta   dmc_play_size

                        ldx   APU_DMC_REG3              ; $4012 | $4013 << 8
                        cpx   dmc_cache_key
                        bne   dmc_need_decode
                        lda   dmc_play_shift
                        cmp   dmc_cache_shift
                        beq   dmc_play
dmc_need_decode
                        stx   dmc_cache_key
                        lda   dmc_play_shift
                        sta   dmc_cache_shift
                        sta   dmc_dec_shift
                        lda   APU_DMC_REG2
                        sta   dmc_start_level
                        rep   #$30
                        mx    %00
                        lda   #$8000
                        sta   dmc_doc_base
                        txa
                        jsr   dmc_src_range
                        sep   #$20
                        mx    %10
                        jsr   dmc_decode
                        FIN

; Set up oscillators 8/9 for the sample and key them on

dmc_play
                        sep   #$30
                        mx    %11
                        php
                        sei
                        jsr   access_doc_registers      ; (clobbers A)

; FHL = DmcFreqTable / (4 * decimation), rounded

                        rep   #$30
                        mx    %00
                        lda   APU_DMC_REG1
                        and   #$000F
                        asl
                        tax
                        ldy   dmc_play_shift
                        lda   DmcFreqTable,x
                        lsr
                        lsr
                        cpy   #2
                        bcc   *+3
                        lsr                             ; 4:1
                        lsr
                        adc   #0                        ; round with the last bit shifted out
                        sep   #$30
                        mx    %11

                        ldx   #$00+dmc_oscillator       ; frequency low
                        jsr   set_osc_register_pair
                        xba
                        ldx   #$20+dmc_oscillator       ; frequency high
                        jsr   set_osc_register_pair
                        ldx   #$40+dmc_oscillator
                        lda   #DMC_VOLUME
                        jsr   set_osc_register_pair
                        ldx   #$80+dmc_oscillator
                        lda   dmc_play_page
                        jsr   set_osc_register_pair
                        ldx   #$c0+dmc_oscillator
                        lda   dmc_play_size
                        jsr   set_osc_register_pair

; A halted -> running transition resets the DOC accumulator, so the sample always starts from
; the beginning.  Halt first in case the oscillator was stopped part way through.

                        ldx   #$a0+dmc_oscillator
                        stx   sound_address
                        lda   #$03                      ; one-shot + halted
                        sta   sound_data
                        inc   sound_address
                        lda   #$13
                        sta   sound_data
                        stx   sound_address
                        lda   #$02                      ; one-shot, running
                        sta   sound_data
                        inc   sound_address
                        lda   #$12
                        sta   sound_data
                        plp

dmc_exit
                        sep   #$30
                        mx    %11
                        pld
                        ply
                        plx
                        plp
                        rts

; A = $4010 value.  Returns A = decimation shift: 1 (2:1) for rate index 0-11, 2 (4:1) for 12-15.
                        mx    %10
dmc_rate_shift
                        and   #$0F
                        cmp   #12
                        lda   #1
                        bcc   *+3
                        inc
                        rts

; A = $4012 | $4013 << 8.  Sets dmc_src_start and dmc_src_end: DMC_SAMPLE_BASE + $4012 * 64,
; $4013 * 16 + 1 bytes long.
                        mx    %00
dmc_src_range
                        pha
                        and   #$00FF
                        asl
                        asl
                        asl
                        asl
                        asl
                        asl
                        clc
                        adc   #DMC_SAMPLE_BASE
                        sta   dmc_src_start
                        pla
                        xba
                        and   #$00FF
                        asl
                        asl
                        asl
                        asl
                        sec                             ; + 1
                        adc   dmc_src_start
                        sta   dmc_src_end
                        rts

; Decode the NES sample dmc_src_start..dmc_src_end into DOC RAM at dmc_doc_base, starting at
; dmc_start_level and decimated by dmc_dec_shift.  The output ramps back to $80 and ends with a
; $00 so the one-shot halts there.
;
; The DOC is written in chunks of 8 source bytes with interrupts disabled, so the sound
; interrupt handler can't change the DOC address and mode registers in the middle of a chunk.
;
; Call with D = $C000, B = K.  Registers: X = NES source address, Y = output level (0-127),
; A = delta bits of the current byte.
                        mx    %10
dmc_decode
                        rep   #$30
                        mx    %00
                        lda   dmc_start_level
                        and   #$007F
                        tay
                        sta   dmc_bias
                        lda   #$0080
                        sec
                        sbc   dmc_bias
                        sta   dmc_bias                  ; low byte = $80 - starting level
                        ldx   dmc_src_start

                        lda   #^ROMBase                 ; the samples are read from the ROMBase bank
                        sep   #$20
                        mx    %10
                        sta   dmc_src2+3
                        sta   dmc_src4+3

                        lda   dmc_dec_shift
                        cmp   #2
                        bne   dmc_loop2
                        jmp   dmc_loop4

; 2:1 -- one output sample per two delta bits, 4 per byte
dmc_loop2
                        php
                        sei
                        jsr   dmc_chunk_addr4
dmc_src2                ldal  $000000,x                 ; bank patched above
                        pha
                        lda   #4
                        sta   dmc_outs_left
                        pla
dmc_out2                DMC_BIT
                        DMC_BIT
                        DMC_OUT
                        dec   dmc_outs_left
                        bne   dmc_out2
                        inx
                        cpx   dmc_src_end
                        bcs   dmc_end2
                        txa
                        and   #$07                      ; end of an 8-byte chunk?
                        bne   dmc_src2
                        plp
                        bra   dmc_loop2
dmc_end2                bra   dmc_finish

; 4:1 -- one output sample per four delta bits, 2 per byte
dmc_loop4
                        php
                        sei
                        jsr   dmc_chunk_addr2
dmc_src4                ldal  $000000,x                 ; bank patched above
                        pha
                        lda   #2
                        sta   dmc_outs_left
                        pla
dmc_out4                DMC_BIT
                        DMC_BIT
                        DMC_BIT
                        DMC_BIT
                        DMC_OUT
                        dec   dmc_outs_left
                        bne   dmc_out4
                        inx
                        cpx   dmc_src_end
                        bcs   dmc_finish
                        txa
                        and   #$07                      ; end of an 8-byte chunk?
                        bne   dmc_src4
                        plp
                        bra   dmc_loop4

; Ramp the output back to $80 in steps of 2, so the oscillator halting at the end doesn't click
; (the NES just holds the last level).  Outputs are always $80 + an even offset, so the ramp
; lands on $80 exactly, and it adds at most 64 samples.  Then write the $00 terminator.  Entered
; from the last chunk, with interrupts still disabled and the DOC address just past the sample.
dmc_finish
                        tya
                        clc
                        adc   dmc_bias                  ; last output value
dmc_ramp                cmp   #$80
                        beq   dmc_ramp_done
                        bcc   dmc_ramp_up
                        sbc   #2                        ; carry is set
                        bra   dmc_ramp_out
dmc_ramp_up             adc   #2                        ; carry is clear
dmc_ramp_out            sta   sound_data
                        bra   dmc_ramp
dmc_ramp_done
                        lda   #0
                        sta   sound_data
                        plp
                        rts

; Point the DOC at dmc_doc_base + (X - dmc_src_start) * outputs per byte, with auto-increment
dmc_chunk_addr4
                        rep   #$20
                        mx    %00
                        txa
                        sec
                        sbc   dmc_src_start
                        asl
                        bra   dmc_chunk_addr
                        mx    %10
dmc_chunk_addr2
                        rep   #$20
                        mx    %00
                        txa
                        sec
                        sbc   dmc_src_start
dmc_chunk_addr
                        asl
                        clc
                        adc   dmc_doc_base
                        pha
                        sep   #$20
                        mx    %10
                        jsr   access_doc_ram            ; (clobbers A)
                        pla
                        sta   sound_address
                        pla
                        sta   sound_address+1
                        rts

                        DO    CACHE_DMC_SAMPLES
; Per-sample DOC RAM placement, filled in by APUCacheDMC
dmc_cat_count      dw  0
dmc_cat_page       ds  DMC_CACHE_MAX       ; DOC RAM page
dmc_cat_size       ds  DMC_CACHE_MAX       ; wavetable size register value
dmc_cat_shift      ds  DMC_CACHE_MAX       ; decimation shift
dmc_top_page       dw  0                   ; lowest DOC RAM page allocated so far

; APUCacheDMC
;
; Decode every sample in DMC_SAMPLE_LIST into DOC RAM.  Each decoded sample needs a power-of-two
; block (256 bytes - 32KB) aligned to its size, so the blocks are placed top-down from $FFFF,
; largest first, which packs them with no gaps.  Running into the instrument waves at
; DMC_DOC_FLOOR is fatal.
;
; Called once from NES_StartUp, after APUStartUp.
                        mx    %00
APUCacheDMC
                        php
                        phb
                        phk
                        plb
                        phd
                        pea   $c000
                        pld
                        sep   #$20
                        mx    %10

                        lda   DMC_SAMPLE_LIST
                        cmp   #DMC_CACHE_MAX+1
                        bcc   *+4
                        brk   $D0                       ; too many samples for the table
                        sta   dmc_cat_count
                        stz   dmc_cat_count+1

; Pass 1: work out each sample's decimation and table size

                        ldx   #0                        ; offset into DMC_SAMPLE_LIST
                        ldy   #0                        ; sample number
dmc_size_loop
                        cpy   dmc_cat_count
                        bcs   dmc_size_done
                        lda   DMC_SAMPLE_LIST+3,x       ; rate
                        jsr   dmc_rate_shift
                        sta   dmc_cat_shift,y

; Bytes needed = source bytes * outputs per byte + ramp (64) + terminator

                        rep   #$20
                        mx    %00
                        lda   DMC_SAMPLE_LIST+2,x       ; length byte
                        and   #$00FF
                        asl
                        asl
                        asl
                        asl
                        inc                             ; source bytes
                        asl                             ; 2 outputs per byte at 4:1
                        pha
                        sep   #$20
                        mx    %10
                        lda   dmc_cat_shift,y
                        cmp   #2                        ; carry set = 4:1
                        rep   #$20
                        mx    %00
                        pla                             ; (pla leaves the carry alone)
                        bcs   *+3
                        asl                             ; 4 outputs per byte at 2:1
                        clc
                        adc   #65

; Table size code = number of bits in (bytes - 1) >> 8, so the block (256 << code) holds them

                        dec
                        xba
                        sep   #$20
                        mx    %10
                        phx
                        ldx   #0
dmc_size_find           cmp   #0
                        beq   dmc_size_found
                        lsr
                        inx
                        bra   dmc_size_find
dmc_size_found          txa
                        sta   dmc_cat_size,y            ; size code until pass 2
                        plx
                        inx
                        inx
                        inx
                        iny
                        bra   dmc_size_loop
dmc_size_done

; Pass 2: place and decode the samples, largest blocks first

                        rep   #$30
                        mx    %00
                        lda   #$0100
                        sta   dmc_top_page
                        lda   #7                        ; size code (32KB)
dmc_place_size
                        pha
                        ldy   #0
dmc_place_loop
                        cpy   dmc_cat_count
                        bcc   *+5
                        brl   dmc_place_next
                        lda   dmc_cat_size,y
                        and   #$00FF
                        cmp   1,s
                        beq   *+5
                        brl   dmc_place_skip

; Allocate a block of 1 << code pages below the last one.  (Once placed, the entry holds the
; size register value, code * 9, which can't match a smaller code later.)

                        tax
                        lda   #1
                        cpx   #0
                        beq   *+6
                        asl
                        dex
                        bne   *-2
                        sta   dmc_doc_base              ; (pages for now)
                        lda   dmc_top_page
                        sec
                        sbc   dmc_doc_base
                        bmi   dmc_no_room
                        cmp   #DMC_DOC_FLOOR
                        bcs   *+4
dmc_no_room             brk   $D1                       ; the samples don't fit in DOC RAM
                        sta   dmc_top_page
                        sep   #$20
                        mx    %10
                        sta   dmc_cat_page,y
                        rep   #$20
                        mx    %00
                        xba
                        and   #$FF00
                        sta   dmc_doc_base

; Size register: table size in bits 3-5, resolution = table size (one sample per FHL/512 scans)

                        lda   1,s
                        asl
                        asl
                        asl
                        ora   1,s
                        sep   #$20
                        mx    %10
                        sta   dmc_cat_size,y

                        lda   dmc_cat_shift,y
                        sta   dmc_dec_shift
                        stz   dmc_dec_shift+1
                        lda   #DMC_START_LEVEL
                        sta   dmc_start_level
                        rep   #$20
                        mx    %00
                        tya
                        sta   dmc_place_y
                        asl
                        adc   dmc_place_y               ; carry clear from the asl (sample number < 128)
                        tax
                        lda   DMC_SAMPLE_LIST+1,x       ; $4012 | $4013 << 8
                        jsr   dmc_src_range
                        sep   #$20
                        mx    %10
                        jsr   dmc_decode
                        rep   #$30
                        mx    %00
                        ldy   dmc_place_y

dmc_place_skip
                        iny
                        brl   dmc_place_loop
dmc_place_next
                        pla
                        dec
                        bmi   *+5
                        brl   dmc_place_size

                        pld
                        plb
                        plp
                        rts

dmc_place_y        dw  0
                        FIN

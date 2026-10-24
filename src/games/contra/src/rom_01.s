; Contra NES PRG bank 1
            mx    %11
C07_EMBED_BANK equ 1
ROMBase EXT
            put   ../../../core/Defs.s
            use   equates.inc
            ds    $5000-*
            put   ../../../rom/rom_inject.s
            put   helpers.s
            ds    $8000-*
; Contra US Disassembly - v1.4
; https://github.com/vermiceli/nes-contra-us
; Bank 1 is responsible for audio and sprites.  The audio code takes up about
; 3/4 of the bank. The remaining 1/4 of the bank is for sprite data and code to
; draw sprites.



; import labels from bank 7

; export labels used in other banks

; Every PRG ROM bank starts with a single byte specifying which number it is
            db    $01    ; The PRG ROM bank number (1)

; pointer table for music of level 1 (#$08 * #$02 = #$10 bytes)
; related to pulse channel config registers
; CPU address $8001
pulse_volume_ptr_tbl ENT
            dw    lvl_1_pulse_volume_00    ; CPU address $91dd
            dw    lvl_1_pulse_volume_01    ; CPU address $91e5
            dw    lvl_1_pulse_volume_02    ; CPU address $91ea
            dw    lvl_1_pulse_volume_03    ; CPU address $91f7
            dw    lvl_1_pulse_volume_04    ; CPU address $9204
            dw    lvl_1_pulse_volume_05    ; CPU address $9216
            dw    lvl_1_pulse_volume_06    ; CPU address $9229
            dw    lvl_1_pulse_volume_07    ; CPU address $923c

; music of level 2 (#$08 * #$02 = #$10 bytes)
            dw    lvl_2_pulse_volume_00    ; CPU address $a3db
            dw    lvl_2_pulse_volume_01    ; CPU address $a3e8
            dw    lvl_2_pulse_volume_02    ; CPU address $a3ee
            dw    lvl_2_pulse_volume_03    ; CPU address $a3f5
            dw    lvl_2_pulse_volume_04    ; CPU address $a402
            dw    lvl_2_pulse_volume_05    ; CPU address $a40f
            dw    lvl_2_pulse_volume_06    ; CPU address $a706
            dw    lvl_2_pulse_volume_07    ; CPU address $aa5f

; music of level 3 (#$08 * #$02 = #$10 bytes)
            dw    lvl_3_pulse_volume_00    ; CPU address $aa6c
            dw    lvl_3_pulse_volume_01    ; CPU address $aa73
            dw    lvl_3_pulse_volume_02    ; CPU address $ab04
            dw    lvl_3_pulse_volume_03    ; CPU address $ab11
            dw    lvl_3_pulse_volume_04    ; CPU address $ab1e
            dw    lvl_3_pulse_volume_05    ; CPU address $ab29
            dw    lvl_3_pulse_volume_06    ; CPU address $aa78
            dw    lvl_3_pulse_volume_07    ; CPU address $98ca

; music of level 4 (#$08 * #$02 = #$10 bytes)
            dw    lvl_4_pulse_volume_00    ; CPU address $98d5
            dw    lvl_4_pulse_volume_01    ; CPU address $98ea
            dw    lvl_4_pulse_volume_02    ; CPU address $98f1
            dw    lvl_4_pulse_volume_03    ; CPU address $98fd
            dw    lvl_4_pulse_volume_04    ; CPU address $9904
            dw    lvl_4_pulse_volume_05    ; CPU address $9909
            dw    lvl_4_pulse_volume_06    ; CPU address $9915
            dw    lvl_4_pulse_volume_07    ; CPU address $991c

; music of level 5 (#$08 * #$02 = #$10 bytes)
            dw    lvl_5_pulse_volume_00    ; CPU address $9928
            dw    lvl_5_pulse_volume_01    ; CPU address $9e71
            dw    lvl_5_pulse_volume_02    ; CPU address $9e7d
            dw    lvl_5_pulse_volume_03    ; CPU address $9c43
            dw    lvl_5_pulse_volume_04    ; CPU address $9c50
            dw    lvl_5_pulse_volume_05    ; CPU address $9c59
            dw    lvl_5_pulse_volume_06    ; CPU address $9c65
            dw    lvl_5_pulse_volume_07    ; CPU address $a064

; music of level 6 (#$08 * #$02 = #$10 bytes)
            dw    lvl_6_pulse_volume_00    ; CPU address $a072
            dw    lvl_6_pulse_volume_01    ; CPU address $a080
            dw    lvl_6_pulse_volume_02    ; CPU address $a088
            dw    lvl_6_pulse_volume_03    ; CPU address $9e84
            dw    lvl_6_pulse_volume_04    ; CPU address $9e90
            dw    lvl_6_pulse_volume_05    ; CPU address $9e9c
            dw    lvl_6_pulse_volume_06    ; CPU address $a713
            dw    lvl_6_pulse_volume_07    ; CPU address $a71b

; music of level 7 (#$06 * #$02 = #$0c bytes)
            dw    lvl_7_pulse_volume_00    ; CPU address $a728
            dw    lvl_7_pulse_volume_01    ; CPU address $abd2
            dw    lvl_7_pulse_volume_02    ; CPU address $abda
            dw    lvl_7_pulse_volume_03    ; CPU address $abea
            dw    lvl_7_pulse_volume_04    ; CPU address $abeb
            dw    lvl_7_pulse_volume_05    ; CPU address $aa85

; silences pulse wave channel
; after pause or level end, or anytime need to silence pulse wave channel
; input
;  * x - sound register offset
;  * y - APU channel register offset
mute_pulse_channel ENT
            lda #$30    ; a = #$30
            jsr   STA_4000_X    ; set volume to 0 and duty cycle to 25%
            jsr wait    ; execute #$0a nop instructions
            bne set_pulse_timer_and_length    ; always branch to set pulse timer and length

; mutes/unmutes pulse wave channel based on pause state
; input
;  * x - sound register offset
mute_unmute_pulse_channel ENT
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            and #$41    ; keep bits .x.. ...x
            ora PAUSE_STATE_01    ; merge with current game pause state (0 = unpaused, 1 = paused)
            bne mute_pulse_channel    ; branch if paused

; input
;  * x - sound channel register config offset
;  * y - sound channel register offset
unmute_pulse_channel ENT
            lda PULSE_VOLUME,x    ; load current volume
            ora SOUND_CFG_HIGH,x
            jsr   STA_4000_Y
            jsr wait    ; execute #$0a nop instructions

set_pulse_timer_and_length ENT
            lda SOUND_PULSE_PERIOD,x    ; load in memory pulse period value
            jsr   STA_4002_Y    ; set APU pulse period value
            jsr wait    ; execute #$0a nop instructions
            lda SOUND_PULSE_LENGTH,x    ; load in memory pulse length value
            jsr   STA_4003_Y    ; set the APU pulse channel length
            jmp wait    ; execute #$0a nop instructions

; see if pausing/unpausing
; if unpausing, turn on level music, otherwise stop bg music
sound_check_pause ENT
            lda PAUSE_STATE    ; #$01 for paused, #$00 for not paused
            cmp PAUSE_STATE_01    ; compare to last frame pause state
            beq sound_check_exit    ; pause already handled, exit
            sta PAUSE_STATE_01    ; set current pause value (0 = unpaused, 1 = paused)
            cmp #$00    ; see if unpausing
            beq :unpausing    ; if unpausing, continue to play level music
            jmp reset_channels    ; pausing, reset triangle, noise, and pulse channels to stop level music

:unpausing
            lda SOUND_CODE+4    ; load sound code for sound slot 4
            beq :toggle_pulse_channel    ; branch if not playing game pausing jingle
            lda SOUND_FLAGS+4    ; still playing game pausing jingle, load sound slot #$04 (pulse 1 channel) read index
; this is the channel that the pause jingle uses
            bpl :unmute_pulse_2    ; branch if still playing the game pausing jingle
            lda PULSE_VOL_DURATION+3
            jsr   STA_4001

; unpausing in middle of pause jingle
:unmute_pulse_2
            ldx #$04    ; x = #$04 (pulse 2 channel config register)
            ldy #$00    ; y = #$00 (pulse 1 channel register offset)
            jsr unmute_pulse_channel    ; could have been optimized to a jmp call with no rts
            rts

:toggle_pulse_channel
            lda SOUND_CODE    ; load sound slot 0's sound code (pulse 1 channel)
            beq sound_check_exit    ; exit if not playing anything
            ldx #$00    ; x = #$00
            ldy #$00    ; y = #$00
            jsr mute_unmute_pulse_channel    ; mutes/unmutes pulse wave channel based on pause state

sound_check_exit ENT
            rts

; sound and music entry point, check each sound slot and if populated, execute
; that slot's sound command
handle_sound_slots ENT
            jsr sound_check_pause    ; if unpausing, turn off level music, otherwise play music
            ldx #$00    ; initialize sound slot loop
            ldy #$00    ; initialize sound channel register offset to #$00 (pulse 1 channel)

; input
;  * x - sound slot index
;  * y - channel register offset, e.g. #$00 (pulse 1 channel), #$04 (pulse 2 channel), #$08 (triangle channel), #$0c (noise/dmc channel)
:sound_slot_loop
            stx SOUND_CURRENT_SLOT    ; set the current sound slot to the current loop index
            sty SOUND_CHNL_REG_OFFSET    ; set sound channel config register offset (#$00, #$04, #$08, or #$0c)
            lda SOUND_CODE,x    ; load sound code for sound slot
            beq :prep_next_loop    ; prep to move to next sound slot, or exit if looped through all slots
            tay    ; sound slot has a sound code, transfer sound code to offset register y
            jsr handle_sound_code    ; read and interpret sound code in slot x

:prep_next_loop
            inx    ; increment sound slot index
            cpx #$06    ; compare to after last sound slot
            beq sound_music_entry_exit    ; exit if looped through all sound slots
            cpx #$05    ; see if last sound slot
            bne :load_sound_channel_offset    ; branch if not the last sound slot
            lda #$0c    ; sound slot #$05, set sound register offset to #$0c (noise channel)
            jmp :loop_next    ; loop to last sound slot with the sound channel register to use being the noise channel

; all sound slots except #$05
; slot #$05 is always the noise channel
:load_sound_channel_offset
            txa    ; transfer sound slot index to a
            asl    ; double sound slot index
            asl    ; double sound slot index again
            and #$0f    ; keep low nibble, this is the new sound channel register offset
; (e.g. #$00 = pulse 1 channel, #$04 = pulse 2 channel)

:loop_next
            tay    ; set SOUND_CHNL_REG_OFFSET (e.g. #$00 = pulse 1 channel, #$04 = pulse 2 channel)
            jmp :sound_slot_loop

sound_music_entry_exit ENT
            rts

; read and interpret loaded sound code in slot x
; output
;  * x - sound slot with the sound code to handle
handle_sound_code ENT
            lda PAUSE_STATE_01    ; load current game pause state (0 = unpaused, 1 = paused)
            beq :check_sound_command    ; branch if game not paused
            lda SOUND_CODE,x    ; game paused, load sound code for current slot
            cmp #$54    ; see if sound code is the pause jingle (sound_54)
            bne sound_music_entry_exit    ; exit if not the game pausing jingle sound

:check_sound_command
            jsr load_sound_code_addr    ; gets the sound_xx pointer for sound slot from SOUND_CMD_LOW_ADDR and stores in ($e0)
; also sets y to point to beginning, i.e. #$00
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
; (0 = sound_xx command byte >= #$30, 1 = sound_xx command byte 0 < #$30)
            dec SOUND_CMD_LENGTH,x    ; decrement the remaining number of video frames sound should play for
; before continuing to the next sound command
            bne :pulse_vol_and_vibrato    ; branch if sound command hasn't finished executing
            jmp read_sound_command_00    ; finished with any previous sound command (or first command), read next/first sound command

:pulse_vol_and_vibrato
            and #$41    ; keep bit 0 and 6 of the sound slot's sound flags (mute flags)
            bne handle_sound_code_exit_00    ; exit if bit 0 or bit 6 is set (mute flags set)
            cpx #$02    ; compare sound slot to #$02 (triangle channel)
            beq handle_sound_code_exit_00    ; exit if sound slot #$02 (triangle channel)
            cpx #$03    ; compare sound slot to #$03 (noise/dmc channel)
            beq handle_sound_code_exit_00    ; exit if sound slot #$03 (noise/dmc channel)
            cpx #$02    ; compare sound slot to #$02 (triangle channel)
            bcs :check_pulse_volume    ; branch if sound slot #$04 (pulse 1 channel), or #$05 (noise channel)
; not sure why developer didn't compare to #$04 here since they've already compared to #$02 and #$03 !(HUH)
            lda VIBRATO_CTRL,x    ; sound slot is #$00 (pulse 1 channel) or #$01 (pulse 2 channel)
; load VIBRATO_CTRL,x (#$80 = no vibrato)
            bmi :check_pulse_volume    ; skip incrementing SOUND_VOL_TIMER,x if VIBRATO_CTRL,x is negative
            inc SOUND_VOL_TIMER,x    ; VIBRATO_CTRL,x is [#$00-#$03], increment vibrato counter (increments up to VIBRATO_DELAY)
            lda VIBRATO_DELAY,x    ; load vibrato delay amount
            cmp SOUND_VOL_TIMER,x    ; see if vibrato timer has counted up to vibrato delay, if so, start checking vibrato
            bcs :check_pulse_volume    ; branch if SOUND_VOL_TIMER,x < VIBRATO_DELAY,x (vibrato hasn't started)
            jsr pulse_sustain_note    ; sustain the current pitch with optional vibrato (note: vibrato portion not used in Contra)
; SOUND_VOL_TIMER >= VIBRATO_DELAY

; see if volume is set or should be lowered
:check_pulse_volume
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            and #$20    ; see if volume decrescendo is complete by checking bit 5
            bne :check_volume_source    ; branch if bit 5 set, indicating to no longer lower the volume (pause decrescendo)
; bit 5 not set, check where volume should come from, and set volume
            lda SOUND_VOL_ENV,x    ; see if pulse volume range amount bit 7 is set (specifying to decrescendo)
            bmi lower_pulse_volume    ; branch when bit 7 set to lower the pulse volume by using and decrementing PULSE_VOLUME,x

; SOUND_VOL_ENV is greater than or equal to #$00 or decrescendo is complete
; pulse volume control override
:check_volume_source
            lda SOUND_FLAGS,x    ; re-load the current sound slot's sound flags
            tay    ; transfer sound flags to the y register
            and #$04    ; keep bit 2
            bne handle_possible_decrescendo    ; branch if bit 2 of the sound flags are set, indicating to use existing PULSE_VOLUME and not pulse_volume_ptr_tbl
; this method handles when decrescendo should pause and continue

; shapes volume envelope for note
; set new PULSE_VOLUME,x byte from lvl_x_pulse_volume_xx based on LVL_PULSE_VOL_INDEX,x and set pulse 1 and 2 configuration (volume)
; based on newly loaded PULSE_VOLUME,x, UNKNOWN_SOUND_01, and SOUND_CFG_HIGH,x
; called for simple sound commands as well
; CPU address $8154
; input
;  * x - sound channel offset
lvl_config_pulse ENT
            lda SOUND_VOL_ENV,x    ; pulse_volume_ptr_tbl offset, i.e. the current level music segment volume envelop to use (lvl_x_pulse_volume_xx)
            asl    ; double since each entry is #$02 bytes
            tay    ; transfer to offset register
            jsr   _R1_000    ; read the low byte of the lvl_x_pulse_volume_xx address
            sta $e4    ; set the low byte of the lvl_x_pulse_volume_xx address
            jsr   _R1_001    ; read the high byte of the lvl_x_pulse_volume_xx address
            sta $e5    ; set the high byte of the lvl_x_pulse_volume_xx address

lvl_pulse_volume_byte ENT
            lda LVL_PULSE_VOL_INDEX,x    ; load read offset into lvl_x_pulse_volume_xx
            tay    ; transfer to offset register
            jsr   _I1_00    ; read byte from lvl_x_pulse_volume_xx
            cmp #$fe    ; see if reached end of data
            bcs lvl_pulse_volume_ctrl_code    ; branch if lvl_x_pulse_volume_xx byte is greater than or equal to #$fe
; to handle control code
; #$fe means to set new offset based on next byte (not used in this game)
; #$ff means to set bit 2 of SOUND_FLAGS,x then exit
            inc LVL_PULSE_VOL_INDEX,x    ; increment lvl_x_pulse_volume_xx read offset
            and #$1f    ; keep bits ...x xxxx of the lvl_x_pulse_volume_xx byte

; sets PULSE_VOLUME,x value to a, then updates APU_PULSE_CONFIG to one of
;  * (a - UNKNOWN_SOUND_01) | SOUND_CFG_HIGH,x
;  * #$00 | SOUND_CFG_HIGH,x
;  * a | SOUND_CFG_HIGH,x
; input
;  * a - the PULSE_VOLUME,x value
;  * x - current sound slot
set_pulse_config_a ENT
            sta PULSE_VOLUME,x    ; set current lvl_x_pulse_volume_xx byte

; sets APU_PULSE_CONFIG value to one of the following
; only used when setting pulse channel 1 or 2 config register
;  * (PULSE_VOLUME,x - UNKNOWN_SOUND_01) | SOUND_CFG_HIGH,x
;  * #$00 | SOUND_CFG_HIGH,x
;  * PULSE_VOLUME,x | SOUND_CFG_HIGH,x
; input
;  * a - PULSE_VOLUME,x
;  * x - current sound slot
set_pulse_config ENT
            cmp #$02
            bcc :continue    ; branch if volume is less than #$02
            sec    ; volume greater than #$02, set carry flag in preparation for subtraction
            sbc UNKNOWN_SOUND_01
            bpl :continue    ; branch if subtraction is a positive answer
            lda #$00    ; a = #$00 (negative volume, just use #$00)

:continue
            ora SOUND_CFG_HIGH,x    ; merge with high nibble of pulse config value
            jsr ldx_pulse_triangle_reg    ; set x to apu channel register [0, 1, 4, 5, 8, #$c]
            bcs :exit    ; exit if there is already a sound playing on that channel that has priority
            jsr   STA_4000_X    ; set either pulse channel 1 or 2 config
; a is either (PULSE_VOLUME,x - UNKNOWN_SOUND_01) | SOUND_CFG_HIGH,x
; or #$00 | SOUND_CFG_HIGH,x
; or PULSE_VOLUME,x | SOUND_CFG_HIGH,x

:exit
            ldx SOUND_CURRENT_SLOT    ; load current sound slot

handle_sound_code_exit_00 ENT
            rts

; handle lvl_x_pulse_volume_xx byte control code
; #$fe means to set new offset based on next byte (unused in this game)
; #$ff means to set bit 2 of SOUND_FLAGS,x then exit
; input
;  * empty flag, set when lvl_x_pulse_volume_xx byte is #$fe
lvl_pulse_volume_ctrl_code ENT
            bne disable_lvl_pulse_ctrl_exit    ; branch if #$ff, i.e. not #$fe to enable automatic decrescendo logic
; !(UNUSED) dead code, not ever executed in gameplay
; no lvl_x_pulse_volume_xx byte is #$fe
            iny    ; byte is #$fe, increment offset into lvl_x_pulse_volume_xx
            jsr   _I1_00    ; load next byte from lvl_x_pulse_volume_xx
            sta LVL_PULSE_VOL_INDEX,x    ; set new offset
            jsr check_decrescendo_end_pause    ; see if the decrescendo should resume and if so update SOUND_FLAGS,x
            jmp lvl_pulse_volume_byte    ; go back to read the next lvl_x_pulse_volume_xx byte

; set bit 2 of SOUND_FLAGS, which indicates to check handle_possible_decrescendo
; setting disables use of pulse_volume_ptr_tbl and instead use automatic decrescendo
disable_lvl_pulse_ctrl_exit ENT
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            ora #$04    ; set bit 2
            sta SOUND_FLAGS,x
            rts

; bit 2 of SOUND_FLAGS,x indicating to grab volume from memory, handling when decrescendo should pause and continue
; input
;  * y - SOUND_FLAGS,x
handle_possible_decrescendo ENT
            tya    ; transfer SOUND_FLAGS,x to a
            and #$02    ; keep bit 1
            bne resume_decrescendo    ; branch if bit 1 set
; this means both bit 1 and 2 are set, indicating DECRESCENDO_END_PAUSE has triggered
; branching will resume the decrescendo

; pulse channel only
; see if the number of remaining frames in the sound command is less than the decrescendo pause end
; if so, decrescendo should resume, specify this by setting bits 1 and 2 in the SOUND_FLAGS,x
check_decrescendo_end_pause ENT
            lda SOUND_CMD_LENGTH,x    ; load the remaining length of the sound command
            cmp DECRESCENDO_END_PAUSE,x    ; compare remaining length of the sound command to when decrescendo should resume
            bcs :exit    ; exit if shouldn't resume decrescendo
            lda SOUND_FLAGS,x    ; resume decrescendo, load the current sound slot's sound flags
            ora #$06    ; set bits 1 and 2
            sta SOUND_FLAGS,x    ; save sound flags now specify that decrescendo should resume

:exit
            rts

; lowers the pulse volume by using and decrementing PULSE_VOLUME,x
; compare to resume_decrescendo
lower_pulse_volume ENT
            dec PULSE_VOL_DURATION,x    ; decrement pulse volume decrescendo duration (how many frames to lower the volume)
            bmi :pause_decrescendo    ; if volume decrescendo length elapsed, branch to pause decrescendo
            dec PULSE_VOLUME,x    ; decrement current volume
            bmi handle_sound_code_exit_01    ; branch if volume is negative
            lda PULSE_VOLUME,x    ; re-load volume
            jmp set_pulse_config    ; set pulse channel 1 or 2 config register based on PULSE_VOLUME,x, UNKNOWN_SOUND_01, and SOUND_CFG_HIGH,x

; set bit 5 and bit 2
:pause_decrescendo
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            ora #$20    ; set bit 5 (stop decrescendo)
            sta SOUND_FLAGS,x    ; store updated sound flags
            jmp disable_lvl_pulse_ctrl_exit

; set the pulse volume by using and decrementing PULSE_VOLUME,x
; called after DECRESCENDO_END_PAUSE has triggered and the decrescendo starts again
resume_decrescendo ENT
            dec PULSE_VOLUME,x    ; decrement volume
            beq handle_sound_code_exit_01    ; branch if volume is #$00
            lda PULSE_VOLUME,x    ; re-load volume
            jmp set_pulse_config    ; set pulse channel 1 or 2 config register based on PULSE_VOLUME,x, UNKNOWN_SOUND_01, and SOUND_CFG_HIGH,x

handle_sound_code_exit_01 ENT
            inc PULSE_VOLUME,x    ; reset the previous volume level
            rts

; one of two modes (along with read_high_sound_cmd) of parsing sound commands.
; This mode is used for pulse channels only
; read sound byte and if not [#$fd-#$ff] interpret_sound_byte otherwise sound_cmd_routine_03
; SOUND_FLAGS,x is odd, indicating initial sound code byte was < #$30
; CPU address $81e7
read_low_sound_cmd ENT
            jsr   _I1_01    ; read sound_xx byte at current offset
            cmp #$fd    ; compare to #$fd
            bcc :interpret_sound_byte    ; branch if not #$fd, #$fe, nor #$ff
            and #$0f    ; sound_xx byte is either #$fd, #$fe, or #$ff, keep low nibble
            jmp sound_cmd_routine_03

:interpret_sound_byte
            jmp interpret_sound_byte    ; interprets sound_xx byte

; sustains the current pitch (PULSE_NOTE,x) with optional vibrato (not used in Contra)
; input
;  * y - sound code read offset (always #$00 from handle_sound_code -> load_sound_code_addr) !(HUH)
;  * x - sound slot, either #$00 (pulse 1 channel) or #$01 (pulse 2 channel)
; jungle and hangar level music
pulse_sustain_note ENT
            tya    ; transfer sound code read offset (#$00) to a
            pha    ; backup y to the stack
            ldy SOUND_CHNL_REG_OFFSET    ; load sound channel config register offset (#$00, #$04, #$08, or #$0c)
            sec    ; set carry flag in preparation for subtraction
            sbc VIBRATO_DELAY,x    ; negate vibrato duration (or #$100 - vibrato duration)
; y - VIBRATO_DELAY,x --> #$00 - VIBRATO_DELAY,x
            sta $e4    ; store result in $e4
            lda VIBRATO_AMOUNT,x    ; load vibrato amount to apply
            and #$f0    ; keep high nibble
            lsr
            lsr
            lsr
            lsr    ; move to low nibble
            cmp $e4    ; compare vibrato amount to negated VIBRATO_DELAY,x
            bne :check_vibrato_ctrl    ; branch if (negated $071e,x) is not equal to ($0180,x >> 4) to skip vibrato
            lda VIBRATO_DELAY,x    ; the following 8 lines of code are never executed in contra meaning no vibrato is used in contra !(UNUSED)
; also not used in Japanese version which has one extra level track 'DEMO'
; load period vibrato adjustment amount
            sta SOUND_VOL_TIMER,x    ; set vibrato counter; increments up to VIBRATO_DELAY before stopping
            inc VIBRATO_CTRL,x    ; increment vibrato control mode [#$00-#$03]
            lda VIBRATO_CTRL,x    ; load vibrato control mode [#$00-#$03]
            cmp #$04    ; see if vibrato has gone more than #$03
            bcc :check_vibrato_ctrl    ; branch if vibrato control mode has not yet gone past max value (#$03)
            lda #$00    ; a = #$00
            sta VIBRATO_CTRL,x    ; reset vibrato control mode back to #$00

:check_vibrato_ctrl
            lda VIBRATO_CTRL,x    ; load vibrato control mode [#$00-#$03]
            and #$01    ; keep bit 0
            bne :apply_vibrato    ; branch if vibrato amount is odd (#$01 or #$03)
; to add vibrato to note by pitching down (#$01) or up (#$03)
            lda PULSE_NOTE,x    ; vibrato amount is even, load existing pulse period value

; set pulse channel period to a
; pop a from stack
; input
;  * y - SOUND_CHNL_REG_OFFSET
:set_pulse_period
            jsr   STA_4002_Y
            jsr wait    ; execute #$0a nop instructions
            pla    ; restore y value from stack (by loading into a)
            tay    ; restore y value from before call
            rts

; VIBRATO_CTRL,x is #$01 or #$03 (odd), add vibrato to note by pitching up or down
:apply_vibrato
            lda VIBRATO_AMOUNT,x    ; load vibrato amount adjust
            and #$0f    ; keep low nibble
            sta $e4
            lda VIBRATO_CTRL,x    ; reload vibrato amount
            and #$02    ; keep bit 1
            bne :pitch_up    ; branch if vibrato amount is #$03
            lda $e4    ; vibrato amount is #$01, pitching down
; vibrato is #$01, add $e4 (low byte of VIBRATO_AMOUNT,x) to PULSE_NOTE,x (APU pulse period value)
            clc    ; clear carry in preparation for addition
            adc PULSE_NOTE,x    ; add $e4 to APU pulse period value
            bcc :set_pulse_period    ; set pulse channel period to a
            lda #$ff    ; overflow occurred, set maximum period (a = #$ff)
            jmp :set_pulse_period    ; set pulse channel period to a

; VIBRATO_CTRL,x is #$03, subtract $e4 (low byte of VIBRATO_AMOUNT,x) from PULSE_NOTE,x (APU pulse period value)
:pitch_up
            lda PULSE_NOTE,x    ; load note that is sustained or has the vibrato applied to, in Contra only ever sustained
            sec    ; set carry flag in preparation for subtraction
            sbc $e4    ; subtract low byte of VIBRATO_AMOUNT,x from PULSE_NOTE,x
            jmp :set_pulse_period    ; set pulse channel period to a

; called when SOUND_FLAGS,x is not zero
; input
;  * a - SOUND_FLAGS,x
;  * y - sound_xx byte read offset
read_sound_command_00 ENT
            lsr    ; shift bit 0 of SOUND_FLAGS,x to carry
; (0 = sound_xx command byte >= #$30, 1 = sound_xx command byte 0 < #$30)
            bcs read_low_sound_cmd    ; branch if byte 0 of sound_xx was less than #$30
; reads sound byte and if not [#$fd-#$ff] interpret_sound_byte otherwise sound_cmd_routine_03

; sound code starts with byte that is greater than or equal to #$30
; reads the sound byte and handles it
; input
;  * ($e0) - pointer to sound byte
;  * y - sound byte read offset
; output
;  * x - SOUND_CURRENT_SLOT [0-3]
read_high_sound_cmd ENT
            lda SOUND_CURRENT_SLOT    ; load sound slot index
            cmp #$03    ; compare to sound slot #$03 (noise/dmc channel)
            beq parse_percussion_cmd    ; branch if sound slot #$03 (noise/dmc channel)
            jsr   _I1_01    ; not noise channel, load sound byte
            and #$f0    ; keep high nibble
            cmp #$c0    ; compare to #$c0
            bcs :regular_sound_cmd    ; branch if high nibble is greater than or equal to #$c0 to process the sound command
            jmp simple_sound_cmd    ; simple sound command, just a note and length multiplier

; sound byte >= #$c0
:regular_sound_cmd
            and #$30    ; keep bits ..xx .... of high nibble
            lsr
            lsr
            lsr
            tax
            jsr   _R1_002    ; load low byte of address pointer
            sta $e4    ; set low byte of address pointer
            jsr   _R1_003    ; load high byte of address pointer
            sta $e5    ; set high byte of address pointer
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            jsr   _I1_01    ; load sound code byte
            and #$0f    ; keep low nibble
            jmp   _J1_0    ; jump to sound_cmd_routine_xx

; only for sound slot #$03 (noise and dmc channel)
parse_percussion_cmd ENT
            jsr   _I1_01    ; load sound code byte
            and #$f0    ; keep high nibble
            cmp #$f0    ; see if high nibble is #$f
            bne :continue    ; branch if high nibble isn't #$f
            jsr   _I1_01    ; high nibble is #$f
            and #$0f    ; keep low nibble
            jmp sound_cmd_routine_03    ; high nibble #$f, go to sound_cmd_routine_03 with low nibble
; either #$0e or #$f
; moves to next (child or parent) sound command
; or finished with entire sound command and re-initialize channel

; high nibble isn't #$f
:continue
            cmp #$d0
            beq :control_nibble_d    ; branch if sound command high nibble is #$0d to determine SOUND_LENGTH_MULTIPLIER
; and then loop to actually play percussion sound
            jmp calc_cmd_len_play_percussion    ; high nibble isn't #$0f nor #$d
; play percussive sound (dpcm sample)

; high nibble is #$0d (delay command)
; load low nibble and set it as SOUND_LENGTH_MULTIPLIER before looping to actually
; play the percussion sound sample
:control_nibble_d
            jsr   _I1_01    ; read slot #$03 sound command byte
            and #$0f    ; keep low nibble
            sta SOUND_LENGTH_MULTIPLIER,x    ; set sound length multiplier
            iny    ; increment sound_xx read offset
            jmp parse_percussion_cmd    ; recursively loop to read next byte of percussion command

; uses low nibble of sound_xx byte to determine sound code to play
; plays dmc sample for percussive track
; also will play sound_02 (bass drum/tom drum) for sound slots 0 and 1 (short percussive tick on noise channel)
play_percussive_sound ENT
            jsr   _I1_01    ; load sound_xx byte
            lsr
            lsr
            lsr
            lsr    ; move high nibble to low nibble
            cmp #$0c    ; see if high nibble was #$0c
            beq :exit    ; exit if high nibble was #$0c
            tax    ; transfer percussion_tbl offset to x
            sta PERCUSSION_INDEX_BACKUP    ; backup percussion_tbl offset
            jsr   _R1_004    ; load sound code based on high nibble from sound_xx
            jsr play_sound    ; play percussion sound (sound_02, sound_25, sound_5a, sound_5b, sound_5c)
            lda PERCUSSION_INDEX_BACKUP    ; restore percussion_tbl offset
            cmp #$03    ; see if shifted sound nibble offset was less than #$03
            bcc :exit    ; exit if index less than #$03
            lda #$02    ; shifted sound nibble is greater than or equal to #$03, play sound_02 (bass drum/tom drum) as well
; note that offset 5 (sound_25) is also slot #$05 and will cause sound_02 to not play
            jsr play_sound    ; play sound_02 (short percussive tick)

:exit
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            rts

; contains sound codes to play the intro theme (#$08 bytes)
; related to music tracks instruments
; CPU address $82cd
;  * sound_02 - percussive tick (bass drum/tom drum)
;  * sound_25 - game intro tune song noise explosion
;  * sound_5a - dmc sample (high hat)
;  * sound_5b - dmc sample (snare)
;  * sound_5c - dmc sample (high hat)
percussion_tbl ENT
            db    $02,$5a,$5b,$5a,$5b,$25,$5c,$5d

; low sound command - interprets sound_xx byte
; input
;  * a - sound_xx byte
;  * y - sound code read offset
interpret_sound_byte ENT
            and #$f0    ; keep high nibble
            cmp #$20    ; see if high nibble is #$20, this is a control byte
            bne :high_nibble_not_2    ; branch if high nibble isn't #$20
            jsr   _I1_01    ; high nibble is #$20, this is a control byte, reload sound byte
; #$02 - sets the number of video frames to wait before reading the next sound
; command (`SOUND_LENGTH_MULTIPLIER`) as well as the high nibble of the APU
; configuration register for the sound channel (`SOUND_CFG_HIGH`).
            and #$0f    ; keep low nibble to see if using low nibble for SOUND_LENGTH_MULTIPLIER or the entire next byte
            bne :continue    ; branch if low nibble isn't #$0f to use low nibble for SOUND_LENGTH_MULTIPLIER
            iny    ; low nibble is #$f, i.e. sound_xx byte is #$2f, use next byte as full byte multiplier
            jsr   _I1_01    ; increment sound_xx byte read offset

:continue
            sta SOUND_LENGTH_MULTIPLIER,x    ; store low nibble (or next full byte) in SOUND_LENGTH_MULTIPLIER,x
            iny    ; increment sound_xx byte read offset
            jsr   _I1_01    ; load new sound byte
            sta SOUND_CFG_HIGH,x    ; store pulse config high nibble value
            iny    ; increment sound_xx byte read offset
            beq :high_nibble_not_2    ; !(WHY?) I don't think this will branch as y wouldn't go up to #$ff
            jmp read_low_sound_cmd    ; read sound byte and if not [#$fd-#$ff] interpret_sound_byte otherwise sound_cmd_routine_03

; high nibble wasn't 2, see if #$01 (flatten note or set sweep), or not #$01 (@high_nibble_not_1)
; - #$10 will set sweep, #$1x will flatten note
:high_nibble_not_2
            cmp #$10    ; see if sound code high nibble is #$10
            bne :high_nibble_not_1    ; branch if the high nibble isn't #$1
; branching sets command length, apu channel config, and note value
            jsr   _I1_01    ; high nibble is #$1, reload full byte, if #$10 set optional sweep and continue
; otherwise flatten note (not used in Contra)
            iny    ; increment sound_xx read offset
            cmp #$10    ; compare full byte to #$10
            bne :flatten_note    ; branch if full byte of sound_xx isn't #$10 to slightly flatten the note
            jsr   _I1_01    ; sound byte is #$10, load next sound_xx byte for setting optional sweep and continue
            bne :set_sweep    ; branch if there is a sweep value to load it
            lda SOUND_FLAGS,x    ; no sweep, strip bit 7 (has sweep flag)
; load the current sound slot's sound flags
            and #$7f    ; strip bit 7 (has sweep flag)
            sta SOUND_FLAGS,x    ; set new sound flags for sound slot (disable sweep)
            lda #$7f    ; a = #$7f (pulse 1 channel disable sweep)
            bne :pulse_1_set_sweep_continue    ; always branch to continue setting APU registers

; sound byte wasn't #$00, set sweep and pulse 1 decrescendo duration PULSE_VOL_DURATION if sound slot #$04
:set_sweep
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            ora #$80    ; set bit 7
            sta SOUND_FLAGS,x    ; set bit 7 (sweep flag)
            jsr   _I1_01    ; load APU_PULSE_SWEEP value

; sets the pulse 1 channel PULSE_VOL_DURATION if current sound slot is #$04 (pulse 1 channel)
:pulse_1_set_sweep_continue
            cpx #$04    ; see if sound slot 4 (pulse 1 channel)
            bne :set_sweep_continue    ; skip setting duration if not sound slot 4
            sta PULSE_VOL_DURATION+3    ; set slot 3's (noise/dmc channel) volume duration

:set_sweep_continue
            jsr ldx_pulse_triangle_reg    ; set x to apu channel register [0, 1, 4, 5, 8, #$c]
            bcs :next_high_control_sound_byte    ; branch if there is already a sound playing on that channel that has priority
            jsr   STA_4001_X    ; enable or disable sweep

:next_high_control_sound_byte
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            iny
            jmp read_low_sound_cmd    ; read sound byte and if not [#$fd-#$ff] interpret_sound_byte otherwise sound_cmd_routine_03

:flatten_note
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            ora #$10    ; set bit 4 (slightly flatten note flag)
            sta SOUND_FLAGS,x    ; set new sound slot flag values
            jmp read_low_sound_cmd    ; read sound byte and if not [#$fd-#$ff] interpret_sound_byte otherwise sound_cmd_routine_03

; low sound command high nibble of sound code is not #$10
; now will set command length, apu channel config, note value, and then exit
; to allow sound to play for expected duration
:high_nibble_not_1
            lda SOUND_LENGTH_MULTIPLIER,x    ; load sound command length
            sta SOUND_CMD_LENGTH,x    ; set loop counter
            jsr   _I1_01    ; load volume
            cmp #$f8
            bne :set_in_mem_cfg
            iny    ; sound byte is #$f8, increment sound byte read offset
            jsr   _I1_01    ; load next sound byte

:set_in_mem_cfg
            lsr
            lsr
            lsr
            lsr    ; move high nibble to low nibble
            sta SOUND_CFG_LOW,x    ; set new PULSE_VOLUME value to high nibble of sound_xx byte
            lda SOUND_CFG_HIGH,x    ; load configuration high byte
            and #$10    ; keep bit 4 (C - constant volume flag)
            beq :dont_set_volume    ; branch to restore SOUND_CFG_HIGH,x to not include volume when setting configuration
            lda SOUND_CFG_LOW,x    ; reload high nibble of sound_xx byte
            ora SOUND_CFG_HIGH,x    ; merge previous sound byte with high nibble of current sound byte

; set config register ($4000, $4004, or $400c) and period & length register
:set_cfg_period_length
            jsr ldx_pulse_triangle_reg    ; set x to apu channel register [0, 1, 4, 5, 8, #$c]
            bcs :load_set_period_length    ; branch if there is already a sound playing on that channel that has priority
            jsr   STA_4000_X    ; set pulse, triangle, or noise channel configuration

:load_set_period_length
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            jsr   _I1_01    ; read current sound_xx byte
            and #$0f    ; keep low nibble
            sta $ef    ; store high byte (3 bits) of note period ($4003/$4007)
            iny    ; increment sound_xx read offset
            jsr   _I1_01    ; load next sound_xx byte
            sta $ee    ; store low byte of note period ($4002/$4006)
            jmp set_note    ; set note value

; C is set on APU configuration, indicating constant volume, restore full high byte of configuration
:dont_set_volume
            lda SOUND_CFG_HIGH,x    ; load high nibble for when storing in pulse config register
            jmp :set_cfg_period_length

cfg_triangle_channel ENT
            lda SOUND_TRIANGLE_CFG    ; load triangle config
            jsr   STA_4008    ; set triangle config
            jmp clear_mute_set_note

prep_pulse_set_note ENT
            lda SOUND_CFG_LOW,x    ; load new PULSE_VOLUME
            jsr set_pulse_config_a    ; sets PULSE_VOLUME,x value to a, then updates APU_PULSE_CONFIG
            lda SOUND_VOL_ENV,x    ; load the pulse volume range amount (low nibble) (how many frames to lower the volume)
            and #$0f    ; keep low nibble
            sta PULSE_VOL_DURATION,x    ; set the pulse volume decrescendo duration (how many frames to lower the volume)
            jmp clear_mute_set_note    ; set note (APU_PULSE_LENGTH) based on sound byte

; play a single note with a specified length change from previous note
; called from read_high_sound_cmd, sound byte high nibble less than #$0c
; sound_xx byte
;  * high nibble - indirect offset into note_period_tbl
;  * low nibble - multiplier to use with previous note's base length
;    for example, if the previous note was #$09 and #$04 and the low nibble is #$04, then note length will be the same
simple_sound_cmd ENT
            jsr calc_cmd_len_play_percussion    ; calculates SOUND_CMD_LENGTH and DECRESCENDO_END_PAUSE
; doesn't play any percussion since simple_sound_cmd doesn't execute for sound slot #$03
            cpx #$02    ; compare to sound slot #$02 (triangle channel)
            beq cfg_triangle_channel    ; branch if slot #$02 (triangle channel)
            lda SOUND_VOL_ENV,x    ; pulse_volume_ptr_tbl offset, i.e. the current level music segment to play (lvl_x_pulse_volume_xx)
            bmi prep_pulse_set_note
            lda #$00    ; a = #$00
            sta LVL_PULSE_VOL_INDEX,x
            sty $e6    ; backup sound_xx read offset
            jsr lvl_config_pulse    ; read lvl_x_pulse_volume_xx based on LVL_PULSE_VOL_INDEX,x and set pulse 1 and 2 configuration
            ldy $e6    ; restore sound_xx read offset

clear_mute_set_note ENT
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            and #$99    ; keep bits x..x x..x, clearing volume and mute flags
            sta SOUND_FLAGS,x    ; update sound flags
            jsr   _I1_01    ; load sound_xx byte
            and #$f0    ; keep high nibble
            lsr
            lsr
            lsr    ; shift high nibble right 3 bits
            tax    ; transfer to offset register
            tya    ; transfer sound_xx read offset to a for backing up
            pha    ; back up sound_xx read offset to stack
            ldy SOUND_CURRENT_SLOT    ; load current sound slot
            lda SOUND_PITCH_ADJ,y    ; load sound period value for slot
            beq :continue    ; if loaded value is #$00 branch
            txa    ; load the high nibble (now in low nibble) from the sound_xx byte
            clc    ; clear carry in preparation for addition
            adc SOUND_PITCH_ADJ,y    ; add adjustment to offset current note_period_tbl offset
            tax    ; set the note_period_tbl read offset

:continue
            pla    ; restore sound_xx read offset
            tay    ; restore sound_xx read offset to y
            jsr   _R1_005    ; load low period byte music note
            sta $ee    ; store low byte of note period ($4002/$4006)
            jsr   _R1_006    ; load high period byte music note
            sta $ef    ; store high byte (3 bits) of note period ($4003/$4007)
            ldx SOUND_CURRENT_SLOT    ; load current sound slot (!(HUH) this value is overwritten two lines down)
            lda SOUND_PERIOD_ROTATE,x    ; load pitch shifting amount
            tax    ; transfer amount to x

:loop
            cpx #$04    ; only shift if the value is not #$04
            beq :exit_loop    ; exit if SOUND_PERIOD_ROTATE,x is #$04
            lsr $ef    ; shift right high byte (3 bits) of note period ($4003/$4007)
            ror $ee    ; rotate low byte of note period ($4002/$4006)
            inx    ; increment shift counter
            bne :loop    ; branch until reach #$00

:exit_loop
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            cpx #$02    ; compare to sound slot #$02 (triangle channel)
            bcs set_note    ; branch if slot #$02 (triangle), #$03 (noise), #$04 (pulse 1), or #$05 (noise)
            lda VIBRATO_CTRL,x    ; sound slot is #$00 (pulse 1) or #$01 (pulse 2), load vibrato control #$80 = no vibrato
            bmi set_note    ; branch to set period and length directly if no vibrato
            lda $ee    ; load low byte of note period ($4002/$4006)
            sta PULSE_NOTE,x    ; store low byte of note period in memory for later when checking for vibrato
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            and #$10    ; keep bit 4 (slightly flatten note flag)
            beq :load_slot_set_note    ; branch if note should not be flattened slightly
            inc PULSE_NOTE,x    ; increase period, which lowers the frequency of the note

; load sound slot and set the period and length registers to specify the note to play
:load_slot_set_note
            ldx SOUND_CURRENT_SLOT    ; load current sound slot

; sets the period and length registers to specify the note to play
; input
;  * $ee - low byte of note period ($4002/$4006)
;  * $ef - high byte (3 bits) of note period ($4003/$4007)
set_note ENT
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            and #$10    ; keep bit 4 (flatten note bit)
            beq :continue_00    ; branch if bit it clear, indicating to not flatten the specified note
            inc $ee    ; increment low byte of note period ($4002/$4006), slightly flattens a note
            bne :continue_00    ; branch if no overflow occurred
            inc $ef    ; increment high byte (3 bits) of note period ($4003/$4007)

:continue_00
            lda $ef    ; load high byte (3 bits) of note period ($4003/$4007)
            cpx #$02    ; compare to sound slot #$02 (triangle channel)
            beq :set_length    ; branch if sound slot #$02 (triangle channel) to set APU_PULSE_LENGTH
            cpx #$05    ; compare to sound slot #$05 (noise channel)
            beq :continue_01    ; branch if sound slot #$05 (noise channel) to set APU_PULSE_LENGTH
; !(HUH) could have branched to @set_length directly, a already has $ef
            cmp SOUND_PULSE_LENGTH,x    ; compare to the current pulse/noise length
            bne :set_length    ; set new length if not already set
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            bmi :continue_01    ; branch if sound flags negative to set APU_PULSE_LENGTH
            lda SOUND_CFG_HIGH,x    ; load high nibble for when storing in pulse config register
            and #$10    ; keep bits ...x ....
            bne :set_period    ; skip setting APU_PULSE_LENGTH if SOUND_CFG_HIGH,x bit 4 set

:continue_01
            lda $ef

; set length and high 3 bits of timer
:set_length
            sta SOUND_PULSE_LENGTH,x    ; set in memory copy of current pulse length
            ora #$08    ; set bit 0 of high timer to be 1
            jsr ldx_pulse_triangle_reg    ; set x to apu channel register [0, 1, 4, 5, 8, #$c]
            bcs :set_period    ; branch if there is already a sound playing on that channel that has priority
            jsr   STA_4003_X    ; set duration and high 3 bits of the pulse, or triangle channel

; set low period
:set_period
            lda $ee    ; load low byte of note period ($4002/$4006)
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            cpx #$02    ; compare to sound slot #$02 (triangle channel)
            bcs :set_apu_period    ; branch if slot #$02 (triangle), #$03 (noise), #$04 (pulse 1), or #$05 (noise)
            sta SOUND_PULSE_PERIOD,x    ; set in memory pulse period value

:set_apu_period
            jsr ldx_pulse_triangle_reg    ; set x to apu channel register [0, 1, 4, 5, 8, #$c]
            bcs :restore_x_adv_sound_ptr    ; branch if there is already a sound playing on that channel that has priority
; continue to restore x to the sound slot index, update SOUND_CMD_LOW_ADDR value, and exit
            jsr   STA_4002_X    ; update APU pulse period

:restore_x_adv_sound_ptr
            ldx SOUND_CURRENT_SLOT    ; load current sound slot

; simple_sound_cmd - finished parsing 'sound command' and next frame will pick up at new location
; which is just after parsed sound command.
; updates the sound_xx read offset, i.e. SOUND_CMD_LOW_ADDR to point to current read location + 1
; game logic uses load_sound_code_addr to know where to read
; input
;  * y - current sound_xx read offset
;  * $e0 - SOUND_CMD_LOW_ADDR (address low byte)
;  * $e1 - SOUND_CMD_HIGH_ADDR (address high byte)
adv_sound_cmd_addr ENT
            iny    ; increment sound_xx sound command read offset
            tya    ; transfer sound_xx sound command read offset to a
            clc    ; clear carry in preparation for addition
            adc $e0    ; add to current read offset address low byte
            sta SOUND_CMD_LOW_ADDR,x    ; set new starting position to read sound_xx data (low byte)
            lda #$00    ; a = #$00
            adc $e1    ; add any carry from previous addition to current read offset address high byte
            sta SOUND_CMD_HIGH_ADDR,x    ; set new starting position to read sound_xx data (high byte)
            rts

; e.g. sound_1b - level 1 jungle boss siren
restore_parent_sound_cmd_addr ENT
            lda NEW_SOUND_CODE_LOW_ADDR,x    ; load new sound code address low byte
            sta $e0    ; set new sound code address low byte
            lda NEW_SOUND_CODE_HIGH_ADDR,x    ; load new sound code address high byte
            sta $e1    ; set new sound code address high byte
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            and #$f7    ; strip bit 7 (sweep flag)
            sta SOUND_FLAGS,x    ; set the sound slot's sound flags
            ldy #$00
            jmp read_sound_command_01

; sound_cmd_routine_03 - low nibble #$0f
; either initialize sound channel, or finished with 'sound_xx_part' go back to 'parent' sound command and parse it
low_nibble_f ENT
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            and #$08
            bne restore_parent_sound_cmd_addr    ; branch if bit 3 is set
            lda SOUND_CODE,x    ; bit 3 not set, load sound code
            sta $e6    ; backup sound code
            lda #$00

; input
;  * a - sound code (#$00 is always passed in)
;  * x - sound slot offset
exe_channel_init_ptr_tbl_routine ENT
            sta SOUND_CODE,x    ; clear sound code
            txa    ; transfer sound slot offset to a for doubling
            asl    ; double sound slot offset since each entry in channel_init_ptr_tbl is #$02 bytes
            tax    ; transfer back to x
            jsr   _R1_007    ; load low byte of address
            sta $e4    ; store low byte in $e4
            jsr   _R1_008    ; load high byte of address
            sta $e5    ; store high byte in $e5
            ldx SOUND_CURRENT_SLOT    ; restore current sound slot
            jmp   _J1_0

; moves to next (child or parent) sound command, or finished with entire sound command and re-initialize channel
; - could be entering a shared sound command used for playing shared sound data across different sound_xx commands (#$fd)
; - could be entering a repeat subcommand used to repeat sound parts (#$fe)
; - could be exiting a shared sound command and need to return to parent sound command (#$ff)
; - could be finished reading entire sound (#$ff)
;  * a - low nibble of sound byte value
sound_cmd_routine_03 ENT
            cmp #$0e    ; compare low nibble of sound byte to #$e
            beq :repeat_cmd    ; branch if sound command is #$fe to allow repeating a shared sound part ($e0),y+1 times
            bcs low_nibble_f
            jsr move_sound_code_read_addr    ; sound command is #$fd, move to sound command address to shared sound part beginning
            iny    ; increment sound code read offset from address byte
            tya    ; transfer sound_xx read offset to a
            clc    ; clear carry before updating ($e0)'s address
            adc $e0    ; skip the 2 address bytes that specified SOUND_CMD_LOW_ADDR
            sta NEW_SOUND_CODE_LOW_ADDR,x    ; set sound command return location low byte once shared sound command part specified in move_sound_code_read_addr executes
            lda #$00
            tay
            adc $e1    ; add any carry from low byte address to high byte
            sta NEW_SOUND_CODE_HIGH_ADDR,x    ; set sound command return location high byte once shared sound command part specified in move_sound_code_read_addr executes
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            ora #$08    ; set bit 3
            sta SOUND_FLAGS,x    ; save sound slot's flags
            jmp :load_sound_code_addr    ; gets the sound_xx pointer for sound slot from SOUND_CMD_LOW_ADDR and stores in ($e0)
; then begins reading that sound command

; #$fe command, i.e. a repeat command. Allows repeating a section of music a specified number of times
; .byte $fe,$03 ; repeat #$03 times
; .addr sound_3e
:repeat_cmd
            inc SOUND_REPEAT_COUNT,x    ; increment sound part repeat counter
            lda SOUND_REPEAT_COUNT,x    ; load current sound part repeat counter
            iny    ; increment sound code read byte offset
            jsr   _I1_02    ; compare SOUND_REPEAT_COUNT,x to sound code byte
            beq skip_3_read_sound_command_01    ; looped ($e0),y times, don't loop any more, move to next sound command
            bmi :move_sound_code_read_addr    ; branch if SOUND_REPEAT_COUNT,x < number of times to repeat shared sound part
            dec SOUND_REPEAT_COUNT,x    ; not sure if ever executed, shouldn't go past ($e0),y, but if so, decrement and repeat !(WHY?)

:move_sound_code_read_addr
            jsr move_sound_code_read_addr    ; update the sound code read address based on the next two bytes of the sound code

:load_sound_code_addr
            jsr load_sound_code_addr    ; gets the sound_xx pointer for sound slot from SOUND_CMD_LOW_ADDR and stores in ($e0)
; also sets y to point to beginning, i.e. #$00

read_sound_command_01 ENT
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            lsr    ; shift bit 0 to carry (0 = sound_xx byte >= #$30, 1 = sound_xx byte 0 < #$30)
            bcs :read_low_sound_cmd    ; branch if byte 0 of sound_xx was less than #$30
; read sound byte and if not [#$fd-#$ff] interpret_sound_byte otherwise sound_cmd_routine_03
            jmp read_high_sound_cmd    ; read sound_xx,y byte and handle it

:read_low_sound_cmd
            jmp read_low_sound_cmd    ; read sound byte and if not [#$fd-#$ff] interpret_sound_byte otherwise sound_cmd_routine_03

; skips the shared sound repeat loop counter (1 byte), and the specified address (2 bytes), then reads next sound command (read_sound_command_01)
; also resets shared sound part repeat counter
; input
;  * x - sound slot index
;  * y - sound byte read offset
skip_3_read_sound_command_01 ENT
            lda #$00    ; clear a register
            sta SOUND_REPEAT_COUNT,x    ; reset shared sound part repeat counter
            iny
            iny
            iny    ; skip #$03 bytes of sound_xx code
            tya    ; transfer sound_xx read offset to a
            clc    ; clear carry in preparation for addition
            adc $e0    ; add to sound byte read location's low byte
            sta $e0    ; set new sound code read location's low byte
            lda #$00
            tay    ; clear y register
            adc $e1    ; add any carry from previous addition into high byte of sound byte read location
            sta $e1    ; set any carry for new read location pointer address
            jmp read_sound_command_01    ; logically same as read_sound_command_00
;  (except SOUND_FLAGS are loaded within read_sound_command_00)

; set sound channel configuration (mute), advance sound command address
; input
;  * a - amount to multiply SOUND_CMD_LENGTH by
;  * y - current sound_xx read offset
sound_cmd_routine_00 ENT
            jsr calc_cmd_delay    ; multiply SOUND_CMD_LENGTH by a
            lda #$00    ; sound config low nibble = #$00 (mute sound channel)
            cpx #$02    ; see if sound slot #$02 (triangle channel)
            beq :continue
            lda SOUND_CFG_HIGH,x    ; pulse/noise channels use SOUND_CFG_HIGH,x

:continue
            jsr ldx_pulse_triangle_reg    ; set x to apu channel register [0, 1, 4, 5, 8, #$c]
            bcs :adv_read_addr    ; branch if there is already a sound playing on that channel that has priority
            jsr   STA_4000_X    ; set pulse 1, pulse 2, or triangle configuration

:adv_read_addr
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            ora #$40    ; set bit 6 (mute flag)
            sta SOUND_FLAGS,x
            jmp adv_sound_cmd_addr    ; set the sound_xx command read offset to current read location + 1

; set in memory configuration for channel, set multiplier, and sometimes read_high_sound_cmd
; input
;  * a - low nibble of sound byte value
;  * y - current sound_xx read offset
sound_cmd_routine_01 ENT
            sta SOUND_LENGTH_MULTIPLIER,x    ; store value used to calculate SOUND_CMD_LENGTH
            iny    ; increment sound code read offset
            jsr   _I1_01    ; load sound code byte
            cpx #$02    ; compare current sound slot to sound slot #$02 (triangle channel)
            beq set_sound_triangle_config    ; branch if triangle channel to set triangle config in memory and read_high_sound_cmd
            and #$0f    ; not triangle sound slot, get low nibble
            sec
            sbc UNKNOWN_SOUND_01
            bpl :set_cfg_read_sound_byte    ; if result is positive set full in memory apu config and read_high_sound_cmd
            lda #$00    ; used to set SOUND_CODE,x to #$00
            jmp exe_channel_init_ptr_tbl_routine    ; initialize sound channel

:set_cfg_read_sound_byte
            sta SOUND_CFG_LOW,x    ; set result of sound_xx low nibble - UNKNOWN_SOUND_01
            jsr   _I1_01    ; load sound code byte
            and #$f0    ; keep high nibble
            sta SOUND_CFG_HIGH,x    ; store high nibble of pulse config value (see set_pulse_config)
            iny    ; increment sound code read offset
            jsr   _I1_01    ; load sound volume envelop control byte
; when bit 7 set, automatic decrescendo, otherwise, will follow pattern from pulse_volume_ptr_tbl
            sta SOUND_VOL_ENV,x    ; set indicator whether or not to lower the volume (see @check_pulse_volume)
            iny    ; increment sound code read offset
            jsr   _I1_01    ; load sound code byte
            and #$0f
            sta UNKNOWN_SOUND_00,x    ; see calc_cmd_len_play_percussion, amount to multiply to SOUND_CMD_LENGTH,x when calculating DECRESCENDO_END_PAUSE,x
            iny
            jmp read_high_sound_cmd    ; reads sound_xx,y byte and handles it

; sets in-memory value for triangle configuration SOUND_TRIANGLE_CFG
; called only from sound_cmd_routine_01 for triangle sound slot
; input
;  * a - sound byte value that was the byte after the sound_cmd_routine_01 control byte
set_sound_triangle_config ENT
            sta SOUND_TRIANGLE_CFG    ; set in memory value for triangle config
            iny
            jmp read_high_sound_cmd    ; reads sound_xx,y byte and handles it

; set/adjust pitch, and read_high_sound_cmd
; input
;  * a - low nibble of control byte
;  * y - sound byte read offset
sound_cmd_routine_02 ENT
            cmp #$05    ; compare low nibble of sound code to #$05
; when less than #$05 it is referring to a sound slot
            bcs :high_val    ; branch if more than #$05
            sta SOUND_PERIOD_ROTATE,x    ; when not #$04, the number of times to shift the high byte of note_period_tbl into the low byte
            iny    ; increment read offset
            jmp read_high_sound_cmd    ; reads sound_xx,y byte and handles it

:high_val
            cmp #$08
            beq :flip_flatten_note_adv
            cmp #$0b
            beq :set_vibrato_vars_adv
            cmp #$0c
            beq :set_pitch_adj_adv
            iny    ; unknown low byte, move to next sound byte
            jmp read_high_sound_cmd    ; reads sound_xx,y byte and handles it

; low nibble of control byte is #$08, flip bit specifying whether to slightly flatten note
:flip_flatten_note_adv
            lda SOUND_FLAGS,x    ; load the current sound slot's sound flags
            eor #$10    ; flip bit 4 (whether or not to slightly flatten note)
            sta SOUND_FLAGS,x
            iny    ; increment sound_xx read offset
            jmp read_high_sound_cmd    ; reads sound_xx,y byte and handles it

; sound_cmd_routine_02 -> low nibble #$b
; set vibrato variables, and move to next sound byte
; jungle and hangar music
:set_vibrato_vars_adv
            iny    ; increment sound_xx read offset
            jsr   _I1_01    ; load sound_xx byte
            sta VIBRATO_DELAY,x    ; set delay until SOUND_VOL_TIMER has counted up to this value before checking vibrato
            cmp #$ff    ; see if sound_xx byte is #$ff
            beq :end_of_sound_code    ; branch if sound_xx byte is #$ff
            iny    ; increment sound_xx read offset
            jsr   _I1_01    ; load sound_xx byte
            sta VIBRATO_AMOUNT,x    ; set the amount of vibrato to apply
            lda #$00    ; a = #$00
            sta VIBRATO_CTRL,x    ; set vibrato mode to #$00
            iny    ; increment sound_xx read offset
            jmp read_high_sound_cmd    ; loop to read next sound_xx,y byte and handle it

; sound_xx byte is #$ff, read entire sound_xx code
:end_of_sound_code
            lda #$80    ; disable vibrato check
            sta VIBRATO_CTRL,x    ; set to not use vibrato (0 = yes, #$80 = no)
            iny
            jmp read_high_sound_cmd    ; read sound_xx,y byte and handle it

; sound_cmd_routine_02 -> low nibble #$c
; sets the pitch adjustment, and move to next sound byte
:set_pitch_adj_adv
            iny    ; increment sound_xx read offset
            jsr   _I1_01    ; load sound_xx byte
            jsr   _R1_009    ; double value since each entry in note_period_tbl is #$02 bytes
            sta SOUND_PITCH_ADJ,x    ; set sound period adjustment (adjusts note frequency/pitch)
            iny    ; increment sound_xx read offset
            jmp read_high_sound_cmd    ; reads sound_xx,y byte and handles it

; called from calc_cmd_len_play_percussion when sound slot is #$03 (noise/dmc channel)
; advance sound_xx read offset, and plays dpcm sample based on low nibble
adv_sound_play_percussive ENT
            jsr adv_sound_cmd_addr    ; advance the sound_xx read offset (SOUND_CMD_LOW_ADDR) to current read location + 1
            dey    ; decrement sound_xx read offset (it was incremented by adv_sound_cmd_addr)
            jmp play_percussive_sound    ; play appropriate intro sound code based on next sound_xx high nibble

; load sound_xx byte and calculate new SOUND_CMD_LENGTH and DECRESCENDO_END_PAUSE
; for simple_sound_cmd, high nibble is less than #$c
; for read_high_sound_cmd sound slot #$03, also play a percussion sound sample (adv_sound_play_percussive)
; input
;  * x - sound slot index [0-3]
calc_cmd_len_play_percussion ENT
            jsr   _I1_01    ; load sound byte
            and #$0f    ; keep low nibble

; input
;  * a - amount (+1) multiplied to SOUND_LENGTH_MULTIPLIER,x to get total delay
;        ex: a = #$03, SOUND_LENGTH_MULTIPLIER,x = #$09 => #$24 == #$04 * #$09
calc_cmd_delay ENT
            sta $e4    ; set amount of times to add $0154 to itself
            beq :skip_loop    ; don't loop if multiplier is #$00
            lda SOUND_LENGTH_MULTIPLIER,x

:calc_delay_loop
            clc    ; clear carry in preparation for addition
            adc SOUND_LENGTH_MULTIPLIER,x    ; add $0154 to itself
            dec $e4    ; decrement loop counter
            bne :calc_delay_loop    ; loop if not finished adding to itself
            beq :loop_complete    ; break loop if added $0154 $e4 times

:skip_loop
            lda SOUND_LENGTH_MULTIPLIER,x    ; load new loop counter, i.e. SOUND_LENGTH_MULTIPLIER,x * $e4

:loop_complete
            sta SOUND_CMD_LENGTH,x    ; set new $0154 value in $0100
            cpx #$02    ; compare to sound slot #$02 (triangle channel)
            bcs :continue    ; branch if slot #$02 (triangle), #$03 (noise), #$04 (pulse 1), or #$05 (noise)
            lda VIBRATO_CTRL,x    ; load whether or not to use vibrato (0 = yes, #$80 = no)
            bmi :continue    ; skip resetting SOUND_VOL_TIMER,x if VIBRATO_CTRL,x has bit 7 set
            lda #$00
            sta SOUND_VOL_TIMER,x    ; clear SOUND_VOL_TIMER,x value

:continue
            cpx #$02    ; compare to sound slot #$02 (triangle channel)
            beq :exit    ; exit if sound slot #$02 (triangle channel)
            cpx #$03    ; compare to sound slot #$03 (noise/dmc channel)
            beq adv_sound_play_percussive    ; play dmc sample if sound slot #$03 (noise/dmc channel)
            lda UNKNOWN_SOUND_00,x    ; load sound byte low nibble
            jsr :calc_decrescendo_pause_end    ; calculate the high #$02 nibbles of the #$03 nibble result of a * SOUND_CMD_LENGTH,x
            sta DECRESCENDO_END_PAUSE,x    ; set result in DECRESCENDO_END_PAUSE,x

:exit
            rts

; calculate the high #$02 nibbles of the #$03 nibble multiplication result of a * SOUND_CMD_LENGTH,x
; if the result is less than #$02 nibbles, then #$00 will be returned
; ex: a = #$0a, SOUND_CMD_LENGTH,x = #$24 -> #$0a * #$24 -> #$168 -> #$16
; ex: a = #$06, SOUND_CMD_LENGTH,x = #$24 -> #$06 * #$24 -> #$0d8 -> #$d8
; result: #$16
; input
;  * a - sound byte low nibble
;  * SOUND_CMD_LENGTH,x
; output
;  * a - the high #$02 nibbles of the #$03 nibble multiplication result of a * SOUND_CMD_LENGTH,x
:calc_decrescendo_pause_end
            and #$0f    ; keep low nibble of UNKNOWN_SOUND_00,x
; (should already be stripped to low nibble)
            sta $e4    ; set low nibble in $e4
            lda #$00
            sta $e6
            sta $e7

:loop
            dec $e4    ; decrement multiplier
            bmi :set_e7_exit    ; return high nibble of a
            clc
            lda SOUND_CMD_LENGTH,x
            adc $e6    ; add SOUND_CMD_LENGTH,x to total
            sta $e6    ; store result back in $e6
            bcc :loop    ; branch to loop if no overflow occurred
            inc $e7    ; carry occurred keep track in $e7
            bne :loop    ; always loop

; shift high nibble from a into low nibble of $e7
; any previous overflow is now in the high nibble of $e7
:set_e7_exit
            asl
            rol $e7
            asl
            rol $e7
            asl
            rol $e7
            asl
            rol $e7
            lda $e7
            rts

; gets the sound_xx pointer for sound slot from SOUND_CMD_LOW_ADDR and stores in ($e0)
; also sets y to point to beginning, i.e. #$00
load_sound_code_addr ENT
            ldy #$00    ; reset sound code read offset
            lda SOUND_CMD_LOW_ADDR,x    ; load sound_xx address low byte
            sta $e0    ; set sound_xx address low byte
            lda SOUND_CMD_HIGH_ADDR,x    ; load sound_xx address high byte
            sta $e1    ; set sound_xx address high byte
            rts

; updates the sound code read address (SOUND_CMD_LOW_ADDR) based on the next two bytes of the sound code
move_sound_code_read_addr ENT
            iny    ; increment sound code read offset
            jsr   _I1_01    ; load new sound code location low byte read offset
            sta SOUND_CMD_LOW_ADDR,x    ; set new sound code location low byte read offset
            iny    ; increment sound code read offset
            jsr   _I1_01    ; load new sound code location high byte read offset
            sta SOUND_CMD_HIGH_ADDR,x    ; set new sound code location high byte read offset
            rts

; get the APU configuration register offset (SOUND_CHNL_REG_OFFSET) for sound slot, e.g. #$01 --> #$04
; if 2 pulse channel 1 sounds are playing, this will set the carry to indicate no way to play sound
; input
;  * x - sound slot
; output
;  * x - sound channel configuration register offset
;  * carry flag - clear to update the apu register, set to not update apu register
;    when set, there is already a sound playing on that channel that has priority
ldx_pulse_triangle_reg ENT
            pha    ; backup a on the stack
            cpx #$01    ; compare to sound slot #$02 (pulse channel 2)
            bcc :move_next_apu_reg    ; branch if pulse channel 0

; requested register is not for sound slot 0
; exit with x set to SOUND_CHNL_REG_OFFSET and the carry clear
:clc_exit
            clc    ; clear carry to signal to update sound register
            ldx SOUND_CHNL_REG_OFFSET    ; load sound channel config register offset (#$00, #$04, #$08, or #$0c)
            pla    ; restore a from stack
            rts

; sound slot is #$00 (pulse channel 1), prefer sound slot #$04 (pulse 1) (higher priority)
:move_next_apu_reg
            inx
            inx
            inx
            inx
            lda SOUND_CODE,x    ; load sound slot 4's sound code to see if a sound is playing for that slot
            beq :clc_exit    ; exit if no sound is playing in slot #$4, use that slot instead of #$0
; carry will clear and x will be set to SOUND_CHNL_REG_OFFSET
            ldx SOUND_CURRENT_SLOT    ; otherwise, load current sound slot, set carry, and exit
            sec    ; set carry flag to signal to not update sound register
            pla

sound_exit_00 ENT
            rts

; mutes the current sound channel, and for sound slot 1, see if playing boss heart destroyed sound
; if so, play end of level song
; input
;  * x - current sound slot
mute_channel ENT
            lda #$30    ; a = #$30 (mute pulse channel register)
            jsr ldx_pulse_triangle_reg    ; set x to apu channel register [0, 1, 4, 5, 8, #$c]
            bcs :continue    ; branch if there is already a sound playing on that channel that has priority
            jsr   STA_4000_X    ; update pulse channel config (mute pulse channel 1 or 2 register)

:continue
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            cpx #$01    ; compare to sound slot #$01 (pulse 2 channel)
            bne sound_exit_00    ; exit if not sound slot 01
            lda $e6    ; sound slot #$01 (pulse 2 channel)
            cmp #$57    ; see if boss heart destroyed - big blast with echo
            bne sound_exit_00    ; exit if not sound_57
            lda LEVEL_END_PLAYERS_ALIVE    ; see if any players are alive still at after defeating boss heart
            beq sound_exit_00    ; exit if no players are alive
            lda #$46    ; a = #$46 (sound_46)
            jsr play_sound    ; play end of level song
; could have been optimized to a jmp and no rts !(OBS)
            rts

init_triangle_channel ENT
            lda #$0b    ; %0000 1011
            jsr   STA_4015    ; disable triangle channel (while also enabling noise, and pulse channels)
            lda #$00    ; a = #$00
            jsr   STA_4008
            lda #$0f    ; a = #$0f
            jsr   STA_4015    ; re-enable triangle channel (enable noise, triangle, and pulse channels)
            rts

init_pulse_channel ENT
            ldx SOUND_CHNL_REG_OFFSET    ; load pulse wave channel register offset, i.e. #$04 for second pulse channel #$00 for first
            lda #$30    ; a = #$30
            jsr   STA_4000_X    ; mute the pulse channel 0 register
            jsr wait    ; execute #$0a nop instructions
            lda #$7f    ; bit 7 set to 0 all other bits 1
            jsr   STA_4001_X    ; disable pulse 1 channel sweep
            txa
            lsr
            lsr
            tax
            lda SOUND_CODE,x
            beq sound_code_00    ; branch if sound code is #$00
            ldy SOUND_CHNL_REG_OFFSET    ; load sound channel config register offset (#$00, #$04, #$08, or #$0c)
            jsr mute_unmute_pulse_channel    ; mutes/unmutes pulse wave channel based on pause state
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            rts

; mutes the noise channel
mute_noise_channel ENT
            lda #$30    ; a = #$30
            jsr   STA_400C    ; initialize noise config with no volume
            lda $e6
            cmp #$4a    ; compare to the end credits music
            bne sound_exit_00
            lda #$4e    ; end credits finished, load a = #$4e (sound_4e)
            jsr play_sound    ; play after credits music (presented by konami)
; could have been optimized to jmp with no rts
            rts

sound_code_00 ENT
            ldx SOUND_CURRENT_SLOT    ; load current sound slot
            lda $e6
            jmp sound_exit_00

; pointer table for ? (#$07 * #$02 = e bytes)
channel_init_ptr_tbl ENT
            dw    mute_channel    ; CPU address $8651
            dw    mute_channel    ; CPU address $8651
            dw    init_triangle_channel    ; CPU address $8673
            dw    mute_noise_channel    ; CPU address $86a6
            dw    init_pulse_channel    ; CPU address $8683
            dw    mute_noise_channel    ; CPU address $86a6
            dw    mute_channel    ; CPU address $8651 (not sure if possible, only #$06 sound slots) !(WHY?)

; pointer table for ? (#$04 * #$02 = #$08 bytes)
sound_cmd_ptr_tbl ENT
            dw    sound_cmd_routine_00    ; CPU address $8500 - set sound channel configuration, advance sound command address
            dw    sound_cmd_routine_01    ; CPU address $8522 - set in memory configuration for channel, set multiplier, and sometimes read_high_sound_cmd
            dw    sound_cmd_routine_02    ; CPU address $855c - set/adjust pitch, and read_high_sound_cmd
            dw    sound_cmd_routine_03    ; CPU address $84a2 - move to next (child or parent) sound command, or finished with entire sound command and re-initialize channel

; table for note period to use when writing notes to the APU (#$30 bytes)
; the frequency of the pulse channels is a division of the CPU Clock (1.789773MHz NTSC, 1.662607MHz PAL)
; the output frequency (f) of the generator can be determined by the 11-bit period value (f_pulse) written to $4002-$4003/$4006-$4007
; note that triangle channel is one octave lower
; frequency = cpu_speed / (#$0f * (f_pulse + 1))
; ex: 1789773 / (#$10 * (#$06ae + 1)) => 65.38 Hz
note_period_tbl ENT
            db    $ae,$06    ; $06AE - 1,710 - 65.38 Hz (c 2/deep c)
            db    $4e,$06    ; $064E - 1,614 - 69.26 Hz (c#/d flat 2)
            db    $f4,$05    ; $05F4 - 1,524 - 73.35 Hz (d 2)
            db    $9e,$05    ; $059E - 1,438 - 77.74 Hz (d#/e flat 2)
            db    $4e,$05    ; $054E - 1,358 - 82.31 Hz (e 2)
            db    $01,$05    ; $0501 - 1,281 - 87.25 Hz (f 2)
            db    $b9,$04    ; $04B9 - 1,209 - 92.45 Hz (f#/g flat 2)
            db    $76,$04    ; $0476 - 1,142 - 97.87 Hz (g 2)
            db    $36,$04    ; $0436 - 1,078 - 103.67 Hz (g#/a flat 2)
            db    $f9,$03    ; $03F9 - 1,017 - 109.88 Hz (a 2)
            db    $c0,$03    ; $03C0 - 960 - 116.40 Hz (a#/b flat 2)
            db    $8a,$03    ; $038A - 906 - 123.33 Hz (b 2)
            db    $57,$03    ; $0357 - 855 - 130.68 Hz (c 3)
            db    $27,$03    ; $0327 - 807 - 138.44 Hz (c#/d flat 3)
            db    $fa,$02    ; $02FA - 762 - 146.61 Hz (d 3)
            db    $cf,$02    ; $02CF - 719 - 155.36 Hz (d#/e flat 3)
            db    $a7,$02    ; $02A7 - 679 - 164.50 Hz (e 3)
            db    $81,$02    ; $0281 - 641 - 174.24 Hz (f 3)
            db    $5d,$02    ; $025D - 605 - 184.59 Hz (f#/g flat 3)
            db    $3b,$02    ; $023B - 571 - 195.56 Hz (g 3)
            db    $1b,$02    ; $021B - 539 - 207.15 Hz (g#/a flat 3)
            db    $fd,$01    ; $01FD - 509 - 219.33 Hz (a 3)
            db    $e0,$01    ; $01E0 - 480 - 232.56 Hz (b 3)
            db    $c5,$01    ; $01C5 - 453 - 246.39 Hz (c 4/middle c)

; 10 nop instructions
wait ENT
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            rts

; pointer for master lookup table (#$02 bytes)
sound_master_ptr_tbl ENT
            dw    sound_table_00    ; CPU address $88e8

; set pulse channel duty cycle, volume, and sweep data, mute noise channel
init_pulse_and_noise_channels ENT
            txa    ; temporarily save current value of x to be restored after function call
            pha    ; push a to stack
            tya    ; temporarily save current value of y to be restored after function call
            pha    ; push a to stack
            lda #$00
            tax

; write #$00 to all sound slots' sound code
:loop
            sta SOUND_CODE,x
            inx
            cpx #$06
            bcc :loop
            sta UNKNOWN_SOUND_01+4
            sta UNKNOWN_SOUND_01+2
            sta UNKNOWN_SOUND_01    ; adjusts pulse channel control (see set_pulse_config)
            jsr init_triangle_channel    ; re-initialize triangle channel
            lda #$30    ; both duty cycle bits set to 1 (%0011 0000)
            jsr   STA_4000    ; set the duty cycle of pulse 1 channel to 75% high
; duty affects the audio's tone
            jsr wait    ; execute #$0a nop instructions
            jsr   STA_4004    ; set the duty cycle of pulse 2 channel to 75% high
            jsr wait    ; execute #$0a nop instructions
            jsr   STA_400C    ; mute noise channel
            jsr wait    ; execute #$0a nop instructions
            ldx #$7f    ; load disable pulse channel sweep value
            jsr   STX_4001    ; disable pulse 1 channel sweep
            jsr wait    ; execute #$0a nop instructions
            jsr   STX_4005    ; disable pulse 2 channel sweep
            pla    ; pop saved value y back from stack
            tay    ; restore y value from before init_pulse_and_noise_channels
            pla    ; pop saved value x back from stack
            tax    ; restore x value from before init_pulse_and_noise_channels
            rts

; reset triangle, pulse, and noise channels
reset_channels ENT
            jsr init_triangle_channel    ; re-initialize triangle channel
            lda #$30    ; a = #$30
            jsr   STA_4000    ; set constant volume and halt any envelope loops
            jsr wait    ; execute #$0a nop instructions
            jsr   STA_4004    ; set constant volume and halt any envelope loops
            jsr wait    ; execute #$0a nop instructions
            jsr   STA_400C    ; set constant volume and halt any envelope loops
            jsr wait    ; execute #$0a nop instructions
            ldx #$7f    ; x = #$7f
            jsr   STX_4001    ; disable pulse 1 channel sweep
            jsr wait    ; execute #$0a nop instructions
            jsr   STX_4005    ; disable pulse 2 channel sweep
            rts

; dead code, never called !(UNUSED)
bank_1_unused_label_00 ENT
            txa
            pha
            tya
            pha
            ldx #$00    ; x = #$00
            stx $e6
            lda SOUND_CODE+4
            beq :pop_and_exit
            stx SOUND_CODE+4    ; set sound channel config register offset (#$00, #$04, #$08, or #$0c)
            stx SOUND_CHNL_REG_OFFSET    ; set sound channel config register offset (#$00, #$04, #$08, or #$0c)
            jsr init_pulse_channel

:pop_and_exit
            pla
            tay
            pla
            tax
            rts

; dead code, never called !(UNUSED)
bank_1_unused_label_01 ENT
            sta UNKNOWN_SOUND_01+2
            sta UNKNOWN_SOUND_01+5
            lda #$00    ; a = #$00
            sta UNKNOWN_SOUND_01    ; reset pulse channel adjustment (see set_pulse_config)
            rts

; plays the specified sound
; input
;  * a - the sound code to play
init_sound_code_vars ENT
            sta INIT_SOUND_CODE    ; store the sound code to play
            cmp #$01
            bne :check_dmc_init    ; branch if sound code isn't #$01
            jmp init_pulse_and_noise_channels    ; sound code #$01, init pulse and noise channels
; sets pulse channel duty cycle, volume, and sweep data, mute noise channel

:check_dmc_init
            cmp #$5a    ; compare sound code to #$5a
            bcc :check_boss_heart_destroyed_sound    ; branch if sound code is less than #$5a
            jmp play_dpcm_sample    ; sound code larger than or equal to #$5a, sound code is a DPCM sample
; jump to configure DMC (delta modulation channel) and play sample

:check_boss_heart_destroyed_sound
            cmp #$57    ; compare to #$57 (sound_57) (boss heart destroyed - big blast with echo)
            bne :check_end_level_sound    ; branch if not boss heart destroyed sound
            jsr init_pulse_and_noise_channels    ; sound code #$57 - boss heart destroyed, initialize pulse and noise channels
; sets pulse channel duty cycle, volume, and sweep data, mute noise channel
            jmp :play_sound    ; play sound boss heart destroyed - big blast with echo

:check_end_level_sound
            cmp #$46    ; compare to #$46 (sound_46) (end of level song)
            bne :check_dmc_play_sound    ; branch to play the sound if not end of level song
            lda SOUND_CODE+1    ; sound code is end of level sound, load sound code of next sound channel
            cmp #$57    ; wait for SOUND_CODE of next sound channel to clear
            bne :play_end_of_level_tune    ; play end of level tune if not already playing it
            rts    ; SOUND_CODE+1 is #$57, exit

; play end of level tune if not already playing it
:play_end_of_level_tune
            cmp #$46    ; see if currently playing end of level song
            bne :check_dmc_play_sound    ; continue to play end of level tune if not already playing it
            rts    ; exit if already playing the end of level tune

; plays a sound from the sound table, but first checks for specific sounds to
; see if dmc counter needs to be cleared
; input
;  * a - sound code to play
:check_dmc_play_sound
            cmp #$2a    ; see if starting to play jungle/hangar song
            beq :init_dmc_sample_value    ; branch to clear dmc counter before playing sound if jungle/hangar
            cmp #$2e    ; see if starting to play waterfall waterfall
            bne :play_sound    ; branch to play sound without clearing dmc counter if not waterfall

; jungle, hangar, and waterfall
:init_dmc_sample_value
            lda #$00    ; a = #$00
            jsr   STA_4011    ; reset DMC starting value for sample

:play_sound
            txa    ; backup x to a
            pha    ; push a to stack (backup)
            tya    ; backup y to a
            pha    ; push a to stack (backup)
            jsr   _R1_00a    ; load low byte of sound_table_00 (only one entry in sound_master_ptr_tbl)
            sta SOUND_TABLE_PTR    ; store low byte of sound_table_00
            jsr   _R1_00b    ; load high byte of sound_table_00 (only one entry in sound_master_ptr_tbl)
            sta SOUND_TABLE_PTR+1    ; store high byte of sound_table_00
            lda #$03    ; read counter index (each entry is #$03 bytes)
            sta $ea    ; set loop counter to 3 so that the entire entry is read

; each entry in sound_master_ptr_tbl is 3 bytes, find offset based on INIT_SOUND_CODE by looping
:loop
            lda INIT_SOUND_CODE    ; load the sound code to play
            clc    ; clear carry in preparation for addition
            adc SOUND_TABLE_PTR    ; add INIT_SOUND_CODE to the low byte of the of the sound_table_00 (keeping track of if a carry happens)
            sta SOUND_TABLE_PTR    ; store offset back to SOUND_TABLE_PTR
            lda #$00
            adc SOUND_TABLE_PTR+1    ; add 1 to the high byte if a carry happened when adding INIT_SOUND_CODE to low byte
            sta SOUND_TABLE_PTR+1    ; set new value if overflow
            dec $ea    ; decrement read calculation counter (3 rounds to get actual offset into sound_table_00)
; this is essentially multiplying INIT_SOUND_CODE by 3 and adding that result to SOUND_TABLE_PTR
            bne :loop    ; continue if haven't calculated final read index
            ldy #$00    ; y = #$00
            sty $eb    ; set number of bytes read to #$00
            jsr   _I1_03    ; read first byte of sound_code entry in the sound_table_00
            lsr
            lsr
            lsr
            and #$03    ; keep bits ...x x... of original byte 0 (control byte) of sound_code entry
; this is the total number of sound slots to fill for the specified sound code
            sta $ea    ; set how many times to loop load_sound_code_entry

; read the sound code entry and load appropriate variables in memory as part of init_sound_code_vars
load_sound_code_entry ENT
            lda $eb    ; load number of entries away from initial entry to read (can be #$00)
            asl    ; double the value
            clc    ; clear carry in preparation for addition
            adc $eb    ; add entry to itself
; since each entry is #$03 bytes, multiplied by #$03 to get new offset
            tay    ; transfer sound_table_00 read offset to y
            jsr   _I1_03    ; read first byte from sound_table_00 entry triple (control byte)
            and #$07    ; keep bits .... .xxx (sound slot offset)
            tax    ; transfer offset to x
            lda INIT_SOUND_CODE    ; load the sound code to play
            cmp SOUND_CODE,x    ; see if another sound code (sound effect) is playing for the current slot
            bcc play_sound_code_exit    ; exit if a existing sound gets priority
            lda #$00    ; a = #$00
            sta SOUND_CODE,x    ; clear sound code slot value
            iny    ; increment sound_table_00 read offset
            jsr   _I1_03    ; read low byte of sound_xx address from sound_table_00 triple
            sta SOUND_CMD_LOW_ADDR,x    ; set low byte of sound_xx address
            sta $e8    ; set low byte of sound_xx address
            iny    ; increment read offset
            jsr   _I1_03    ; load high byte of sound_xx address
            sta SOUND_CMD_HIGH_ADDR,x    ; set high byte of sound_xx address
            sta $e9    ; set high byte of sound_xx address
            lda #$f8    ; a = #$f8
            sta SOUND_PULSE_LENGTH,x    ; set pulse length to #$f8 (note length 30)
            lda #$01    ; a = #$01
            sta SOUND_CMD_LENGTH,x    ; initialize SOUND_CMD_LENGTH to #$01 so that when sound command is read for the first time
; the data is parsed as a new sound and not a sound that's already playing (@check_sound_command)
            cpx #$03    ; see if sound slot is #$03 or more
            bcs :continue    ; branch if sound slot is #$03 or greater
            cpx #$02    ; see if sound slot is #$02
            beq :clear_pitch_adj    ; branch if sound slot #$02
            lda #$80    ; sound slot #$00 or #$01 (pulse channel 1 or 2) set a = #$80
            sta VIBRATO_CTRL,x    ; set to not use vibrato (0 = yes, #$80 = no)

:clear_pitch_adj
            lda #$00    ; a = #$00
            sta SOUND_PITCH_ADJ,x    ; clear sound period adjustment value

:continue
            lda #$00    ; a = #$00
            sta SOUND_REPEAT_COUNT,x    ; initialize shared sound part repeat counter to #$00
            tay    ; set sound_xx read offset to #$00
            jsr   _I1_04    ; read sound_xx byte 0
            iny    ; increment sound_xx read offset
            cmp #$30
            bcc :config_channel
            dey    ; control code greater than or equal to #$30
; y will be #$00 for setting SOUND_FLAGS,x
; indicating to use read_high_sound_cmd
            sty UNKNOWN_SOUND_01+2
            sty UNKNOWN_SOUND_01

:config_channel
            tya    ; transfer sound_xx read offset to a
            sta SOUND_FLAGS,x    ; set to either #$00 or #$01 depending whether byte 0 is greater than #$30 of sound_xx
; 0 when sound byte is greater than or equal to #$30, 1 is when sound byte is less than #$30
; this specifies whether the sound commands in the code will be processed as a 'high code', or a 'low code'
            lda INIT_SOUND_CODE    ; load sound code to play
            sta SOUND_CODE,x    ; store sound code to play in sound slot x
            txa    ; transfer sound slot index to a
            cmp #$01    ; compare to #$01 (pulse 2 channel)
            bcc move_to_pulse_2    ; branch if pulse 1 channel
            cpx #$05    ; see if sound slot #$05 (noise channel)
            bne convert_slot_to_offset    ; branch if not sound slot #$05 (noise channel)
            lda #$0c    ; sound slot #$05 (noise channel), set sound channel register offset to #$0c (noise/dmc channel)
            jmp cfg_channel

; converts the channel slot index to the channel register offset
;  * #$00: #$00 (pulse 1 channel)
;  * #$01: #$04 (pulse 2 channel)
;  * #$02: #$08 (triangle channel)
;  * #$03: #$0c (noise/dmc channel)
;  * #$04: #$00 (pulse 1 channel)
;  * #$05: do not call this method for sound slot #$05
; input
;  * a - sound slot index
; output
;  * a - sound channel register offset (#$00, #$04, #$08, or #$0c)
; note: does not work for sound slot #$05, must check if slot #$05 before calling this method
convert_slot_to_offset ENT
            asl
            asl
            and #$0f    ; keep low nibble

; configure pulse or noise channel
cfg_channel ENT
            tax    ; transfer sound channel register offset to x
            lda #$00    ; a = #$00
            cpx #$08    ; see if sound channel register offset is triangle channel
            beq :set_cfg_exit    ; exit if triangle channel
            lda #$30    ; set pulse channel or noise channel to play note indefinitely and that v bits will control volume
; until another value is written to pulse to $4000/$4004

:set_cfg_exit
            jsr   STA_4000_X    ; either set pulse channel or noise channel to #$30 or set triangle channel to #$00
            jsr wait    ; execute #$0a nop instructions
            lda #$7f    ; a = #$7f (disable sweep)
            jsr   STA_4001_X    ; disable sweep

play_sound_code_exit ENT
            inc $eb    ; move to next entry in sound_table_00
            dec $ea    ; load number of additional slots required for sound code
            bpl :load_entry
            pla
            tay
            pla
            tax
            rts

:load_entry
            jmp load_sound_code_entry

; input
;  * a - sound slot index
;  * x - sound slot
; output
;  * a - sound slot index for pulse 2 channel (#$04)
move_to_pulse_2 ENT
            ora #$04    ; set bits .... .x..
            tay
            lda SOUND_CODE,y
            bne play_sound_code_exit
            txa    ; transfer sound slot to a
            jmp convert_slot_to_offset    ; determine sound channel register offset for slot

; configure DMC (delta modulation channel) and play DPCM sample from bank 7
; !(BUG?) special sound code #$ff (used by end of snow field level after boss defeated)
; sounds like door sliding opening
;  * dpcm_sample_data_tbl offset is #$94
;  * sampling rate #$03 (5593.04 Hz), no loop
;  * counter length #$77
;  * offset #$97 --> $c000 + (#$97 * #$40) --> $e5c0 --> (collision_box_codes_03)
;  * sample length #$19
play_dpcm_sample ENT
            sec    ; set carry flag in preparation for subtraction
            sbc #$5a    ; sound codes larger than #$5a are commands to initialize the DMC
; subtract #$5a to get actual initialization values (offset to dpcm_sample_data_tbl)
            sta INIT_SOUND_CODE    ; set dpcm_sample_data_tbl offset
            tya    ; back up y register, transfer to a
            pha    ; backup a by pushing to stack
            lda INIT_SOUND_CODE    ; load dpcm_sample_data_tbl offset
            asl
            asl    ; quadruple since each entry is #$04 bytes
            tay    ; transfer to offset register
            lda #$0f    ; a = #$0f
            jsr   STA_4015    ; enable noise, triangle, and the 2 pulse channels
            jsr   _R1_00c    ; load DMC configuration (max sampling rate, no looping)
            jsr   STA_4010    ; set DMC configuration (max sampling rate, no looping)
            jsr   _R1_00d    ; load DMC counter
            jsr   STA_4011    ; set DMC counter
            jsr   _R1_00e    ; load address of DPCM sample data (this value * #$40) + $c000 is final address
            jsr   STA_4012    ; set address of DPCM sample data
            jsr   _R1_00f    ; load length of sample
            jsr   STA_4013    ; set length of sample
            lda #$1f    ; a = #$1f
            jsr   STA_4015    ; enable DMC, noise, triangle, and the 2 pulse channels
            pla    ; restore a (backup of y)
            tay    ; restore y
            rts

; table for APU configuration (#$0d bytes)
; byte 0 - APU_DMC - sampling rate (how many CPU cycles happen between playback samples), no looping
;        - always $0f, highest sampling rate. NTSC 33,143.9 Hz, PAL 33,252.1 Hz
; byte 1 - APU_DMC_COUNTER - initial sample level
; byte 2 - APU_DMC_SAMPLE_ADDR - starting memory address of sample: $c000 + (value * #$40)
; byte 3 - APU_DMC_SAMPLE_LEN - length in bytes: value * #$10 + 1
dpcm_sample_data_tbl ENT
            db    $0f,$2f,$f0,$05    ; sound_5a - sample address $fc00 (dpcm_sample_00) (#$51 bytes)
            db    $0f,$75,$f3,$25    ; sound_5b - sample address $fcc0 (dpcm_sample_01) (#$251 bytes)
            db    $0f,$00,$f0,$05    ; sound_5c - sample address $fc00 (dpcm_sample_00) (#$51 bytes)
            db    $0f

; CPU address $88e8
; main look-up table for sounds and music #$5e * #$03 = #$11a bytes)
; groups of #$03 bytes
; read by @play_sound
; byte 0 - ...y yxxx ->
;  * x - sound slot offset
;  * y - how many sound additional sound codes to play
;        note that subsequent sound codes don't read/use the y bits of their byte 0
; byte 1 and 2 - address to sound data
; see level_vert_scroll_and_song (bank 7)
sound_table_00 ENT
            db    $00,$f3,$25    ; these bytes are for dpcm_sample_data_tbl, lowest sound code is #$01
; sample address $fcc0 (dpcm_sample_01)

; unused, empty/silence (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_01    ; CPU address $8a24

; percussive tick (bass drum/tom drum), used by other sound codes (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_02    ; CPU address $8a02

; player landing on ground or water (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_03    ; CPU address $8a25

; FOOT - player landing on ground or water (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_04    ; CPU address $8a36

; ROCK - waterfall rock landing on ground (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_05    ; CPU address $8a41

; TYPE 1 - unused, keyboard typing in Japanese version of game (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_06    ; CPU address $8a78

; TYPE 1 - unused, keyboard typing in Japanese version of game (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_07    ; CPU address $8a82

; unused, rumbling (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_08    ; CPU address $8a90

; FIRE - energy zone fire beam (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_09    ; CPU address $8c81

; SHOTGUN1 - regular bullet firing (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_0a    ; CPU address $8ab3

; SHOTGUN1 - regular bullet firing (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_0b    ; CPU address $8adc

; SHOTGUN2 - M weapon firing, turret man (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_0c    ; CPU address $8b05

; SHOTGUN2 - M weapon firing, turret man (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_0d    ; CPU address $8b32

; LASER - L weapon firing (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_0e    ; CPU address $8b59

; LASER - L weapon firing (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_0f    ; CPU address $8b90

; PL FIRE - F bullet firing (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_10    ; CPU address $8bf3

; PL FIRE - F bullet firing (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_11    ; CPU address $8c07

; SPREAD - S bullet firing (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_12    ; CPU address $8c19

; SPREAD - S bullet firing (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_13    ; CPU address $8c27

; HIBIWARE - bullet shielded wall plating ting (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_14    ; CPU address $8cba

; CHAKUCHI - energy zone boss landing (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_15    ; CPU address $8d49

; DAMEGE 1 - bullet to metal collision ting (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_16    ; CPU address $8cd4

; DAMEGE 1 - bullet to metal collision ting (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_17    ; CPU address $8cf7

; DAMEGE 2 - alien heart boss hit (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_18    ; CPU address $8d1c

; TEKI OUT - enemy destroyed (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_19    ; CPU address $8d33

; HIRAI 1 - ice grenade whistling noise (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_1a    ; CPU address $8ddd

; SENSOR - level 1 jungle boss siren (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_1b    ; CPU address $8d76

; KANDEN - electrocution sound (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_1c    ; CPU address $8ea5

; KANDEN - electrocution sound (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_1d    ; CPU address $8ec6

; CAR - tank advancing (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_1e    ; CPU address $8e2f

; POWER UP - pick up weapon item (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_1f    ; CPU address $8e47

; 1UP - extra life (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_20    ; CPU address $8e5e

; HERI - helicopter rotors (pulse 1 channel)
; #$02 additional sound code entries, sound slot #$04
            db    $14
            dw    sound_21    ; CPU address $8ee3

; HERI - helicopter rotors (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_21    ; CPU address $8ee3

; HERI - helicopter rotors (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_23    ; CPU address $8f83

; BAKUHA 1 - explosion (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_24    ; CPU address $8fc2

; BAKUHA 2 - game intro explosion, indoor wall explosion, and island explosion (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_25    ; CPU address $9001

; TITLE - game intro tune (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_26    ; CPU address $9195

; TITLE - game intro tune (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_27    ; CPU address $91ab

; TITLE - game intro tune (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_28    ; CPU address $91c3

; TITLE - game intro tune (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_29    ; CPU address $91d3

; BGM 1 - level 1 jungle and level 7 hangar music (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_2a    ; CPU address $9428

; BGM 1 - level 1 jungle and level 7 hangar music (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_2b    ; CPU address $924e

; BGM 1 - level 1 jungle and level 7 hangar music (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_2c    ; CPU address $95c7

; BGM 1 - level 1 jungle and level 7 hangar music (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_2d    ; CPU address $9775

; BGM 2 - level 3 waterfall music (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_2e    ; CPU address $9985

; BGM 2 - level 3 waterfall music (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_2f    ; CPU address $9a71

; BGM 2 - level 3 waterfall music (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_30    ; CPU address $9b67

; BGM 2 - level 3 waterfall music (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_31    ; CPU address $9bce

; BGM 3 - level 5 snow field music (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_32    ; CPU address $9ca4

; BGM 3 - level 5 snow field music (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_33    ; CPU address $9d32

; BGM 3 - level 5 snow field music (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_34    ; CPU address $9d9a

; BGM 3 - level 5 snow field music (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_35    ; CPU address $9e1e

; BGM 4 - level 6 energy zone (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_36    ; CPU address $9ea8

; BGM 4 - level 6 energy zone (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_37    ; CPU address $9f46

; BGM 4 - level 6 energy zone (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_38    ; CPU address $9fb8

; BGM 4 - level 6 energy zone (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_39    ; CPU address $a003

; BGM 5 - level 8 alien's lair music (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_3a    ; CPU address $a092

; BGM 5 - level 8 alien's lair music (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_3b    ; CPU address $a1a7

; BGM 5 - level 8 alien's lair music (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_3c    ; CPU address $a295

; BGM 5 - level 8 alien's lair music (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_3d    ; CPU address $a32f

; 3D BGM - indoor/base level music (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_3e    ; CPU address $a468

; 3D BGM - indoor/base level music (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_3f    ; CPU address $a570

; 3D BGM - indoor/base level music (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_40    ; CPU address $a5eb

; 3D BGM - indoor/base level music (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_41    ; CPU address $a67a

; BOSS - indoor/base boss screen music (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_42    ; CPU address $a793

; BOSS - indoor/base boss screen music (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_43    ; CPU address $a878

; BOSS - indoor/base boss screen music (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_44    ; CPU address $a8fb

; BOSS - indoor/base boss screen music (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_45    ; CPU address $aa0e

; PCLR - end of level tune (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_46    ; CPU address $aa92

; PCLR - end of level tune (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_47    ; CPU address $aab3

; PCLR - end of level tune (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_48    ; CPU address $aad4

; PCLR - end of level tune (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_49    ; CPU address $aaef

; ENDING - end credits (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_4a    ; CPU address $ac9f

; ENDING - end credits (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_4b    ; CPU address $ad1a

; ENDING - end credits (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_4c    ; CPU address $ae05

; ENDING - end credits (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_4d    ; CPU address $ae87

; OVER - game over/after end credits, presented by konami (pulse 1 channel)
; #$03 additional sound code entries, sound slot #$00
            db    $18
            dw    sound_4e    ; CPU address $ab34

; OVER - game over/after end credits, presented by konami (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_4f    ; CPU address $ab5c

; OVER - game over/after end credits, presented by konami (triangle channel)
; #$00 additional sound code entries, sound slot #$02
            db    $02
            dw    sound_50    ; CPU address $ab86

; OVER - game over/after end credits, presented by konami (noise/dmc channel)
; #$00 additional sound code entries, sound slot #$03
            db    $03
            dw    sound_51    ; CPU address $abb2

; PL OUT - player death (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_52    ; CPU address $9117

; PL OUT - player death (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_53    ; CPU address $916a

; game pausing jingle (pulse 1 channel)
; #$00 additional sound code entries, sound slot #$04
            db    $04
            dw    sound_54    ; CPU address $8a0a

; BOSS BK - tank, boss ufo, boss giant, alien guardian destroyed (pulse 1 channel)
; #$01 additional sound code entry, sound slot #$04
            db    $0c
            dw    sound_55    ; CPU address $903c

; BOSS BK - tank, boss ufo, boss giant, alien guardian destroyed (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_56    ; CPU address $9055

; BOSS OUT - boss destroyed (pulse 1 channel)
; #$02 additional sound code entries, sound slot #$04
            db    $14
            dw    sound_57    ; CPU address $9094

; BOSS OUT - boss destroyed (pulse 2 channel)
; #$00 additional sound code entries, sound slot #$01
            db    $01
            dw    sound_58    ; CPU address $9098

; BOSS OUT - boss destroyed (noise channel)
; #$00 additional sound code entries, sound slot #$05
            db    $05
            dw    sound_59    ; CPU address $90dc

; #$00 additional sound code entries, sound slot #$03 (noise/dmc channel)
            db    $03
            dw    sound_01    ; CPU address $8a24 - 5a

; #$00 additional sound code entries, sound slot #$03 (noise/dmc channel)
            db    $03
            dw    sound_01    ; CPU address $8a24 - 5b

; #$00 additional sound code entries, sound slot #$03 (noise/dmc channel)
            db    $03
            dw    sound_01    ; CPU address $8a24 - 5c

; #$00 additional sound code entries, sound slot #$03 (noise/dmc channel)
            db    $03
            dw    sound_01    ; CPU address $8a24 - 5d

; percussive tick (bass drum/tom drum), used by other sound codes (noise channel)
; CPU address $8a02
sound_02 ENT
            db    $21,$30,$60,$03,$f8,$10,$01,$ff

; game pausing jingle (pulse 1 channel)
sound_54 ENT
            db    $25,$82,$00,$d5,$00,$8e,$00,$a9,$22,$b0,$e0,$6a,$d0,$6a,$b0,$6a
            db    $a0,$6a,$90,$6a,$70,$6a,$50,$6a,$40,$6a

; CPU address $8a24
; unused, empty/silence
sound_01 ENT
            db    $ff

; player landing on ground or water (pulse 1 channel)
; CPU address $8a25
sound_03 ENT
            db    $21,$30,$40,$f0,$00,$00,$00,$00,$21,$f0,$f8,$20,$0a,$f8,$10,$0b
            db    $ff

; FOOT - player landing on ground or water (noise channel)
; CPU address $8a36
sound_04 ENT
            db    $21,$0f,$a0,$0c,$00,$00,$23,$30,$30,$02,$ff

; ROCK - waterfall rock landing on ground (pulse 1 channel)
; CPU address $8a41
sound_05 ENT
            db    $21,$70,$10,$83,$f3,$8c,$f2,$f6,$f3,$15,$73,$77,$d3,$8c,$00,$00
            db    $d3,$15,$00,$00,$d3,$8c,$b3,$45,$33,$11,$b3,$50,$73,$33,$b4,$00
            db    $00,$00,$b2,$dd,$00,$00,$00,$00,$a3,$50,$00,$00,$73,$22,$00,$00
            db    $53,$50,$00,$00,$32,$ee,$ff

; TYPE 1 - unused, keyboard typing in Japanese version of game (pulse 1 channel)
; CPU address $8a78
sound_06 ENT
            db    $26,$30,$10,$99,$60,$8e,$f8,$20,$8e,$ff

; TYPE 1 - unused, keyboard typing in Japanese version of game (noise channel)
; CPU address $8a82
sound_07 ENT
            db    $21,$30,$b0,$06,$70,$02,$50,$06,$30,$02,$f8,$10,$02,$ff

; unused, rumbling (noise/dmc channel)
; CPU address $8a90
sound_08 ENT
            db    $21,$30,$c0,$0e,$c0,$0f,$fe,$02
            dw    sound_08

sound_08_part_00 ENT
            db    $24,$30,$a0,$0f,$90,$0e,$80,$0f,$70,$0f,$60,$0f,$50,$0f,$40,$0f
            db    $30,$0f,$f8,$20,$0f,$f8,$10,$0f,$ff

; SHOTGUN1 - regular bullet firing (pulse 1 channel)
; CPU address $8ab3
sound_0a ENT
            db    $25,$70,$10,$83,$d2,$86,$b0,$c0,$21,$f0,$a0,$09,$25,$70,$60,$f2
            db    $21,$f0,$a0,$0a,$25,$70,$51,$2b,$41,$76,$31,$d3,$f8,$22,$44,$f8
            db    $12,$dd,$f8,$13,$99,$f8,$14,$7e,$ff

; SHOTGUN1 - regular bullet firing (noise/dmc channel)
; CPU address $8adc
sound_0b ENT
            db    $21,$30,$f0,$09,$d0,$0e,$f8,$20,$0a,$f8,$20,$09,$00,$00,$fe,$02
            dw    sound_0b

; CPU address $8aee
sound_0b_part_00 ENT
            db    $23,$30,$70,$0b,$f8,$20,$0e,$30,$0e,$f8,$20,$0b,$00,$00,$30,$0a
            db    $f8,$20,$0d,$f8,$10,$0b,$ff

; SHOTGUN2 - M weapon firing, turret man (pulse 1 channel)
; CPU address $8b05
sound_0c ENT
            db    $21,$f0,$10,$83,$c2,$3b,$81,$0d,$71,$c5,$c0,$08,$fe,$02
            dw    sound_0c

sound_0c_part_00 ENT
            db    $25,$f0,$60,$f2,$21,$f0,$b0,$08,$25,$f0,$51,$2b,$41,$76,$31,$d3
            db    $f8,$22,$44,$f8,$12,$dd,$f8,$13,$99,$f8,$14,$7e,$ff

; SHOTGUN2 - M weapon firing, turret man (noise/dmc channel)
; CPU address $8b32
sound_0d ENT
            db    $21,$30,$f0,$09,$d0,$0e,$f8,$20,$0a,$f8,$10,$09,$fe,$02
            dw    sound_0d

; CPU address $8b42
sound_0d_part_00 ENT
            db    $23,$30,$70,$0b,$f8,$20,$0e,$30,$0e,$f8,$20,$0b,$00,$00,$30,$0a
            db    $f8,$20,$0d,$f8,$10,$0b,$ff

; LASER - L weapon firing (pulse 1 channel)
; CPU address $8b59
sound_0e ENT
            db    $22,$30,$10,$83,$30,$39,$40,$40,$50,$47,$60,$50,$70,$5a,$80,$65
            db    $90,$71,$a0,$7f,$a0,$8f,$90,$a0,$90,$b4,$80,$ca,$80,$e2,$80,$fe
            db    $81,$1d,$71,$40,$71,$68,$61,$94,$61,$c5,$61,$fc,$62,$36,$62,$81
            db    $52,$cf,$53,$27,$53,$8a,$ff

; LASER - L weapon firing (noise/dmc channel)
; CPU address $8b90
sound_0f ENT
            db    $21,$30,$30,$0b,$40,$0a,$50,$09,$60,$08,$70,$07,$70,$06,$80,$06
            db    $80,$06,$80,$06,$80,$06,$80,$06,$80,$06,$80,$07,$80,$06,$80,$07
            db    $80,$07,$80,$08,$80,$07,$80,$08,$80,$08,$80,$09,$80,$08,$80,$09
            db    $80,$09,$80,$0a,$70,$09,$70,$0a,$70,$0a,$70,$0b,$70,$0a,$70,$0b
            db    $70,$0b,$70,$0c,$70,$0b,$70,$0c,$70,$0c,$60,$0d,$60,$0c,$60,$0d
            db    $60,$0d,$50,$0e,$50,$0d,$50,$0e,$50,$0e,$50,$0e,$50,$0e,$40,$0e
            db    $40,$0e,$ff

; PL FIRE - F bullet firing (pulse 1 channel)
; CPU address $8bf3
sound_10 ENT
            db    $23,$f0,$10,$82,$b0,$35,$90,$50,$70,$78,$fe,$03
            dw    sound_10

sound_10_part_00 ENT
            db    $30,$b4,$f8,$21,$0d,$ff

; PL FIRE - F bullet firing (noise/dmc channel)
; CPU address $8c07
sound_11 ENT
            db    $23,$30,$40,$06,$50,$08,$60,$0a,$fe,$03
            dw    sound_11

sound_11_part_00 ENT
            db    $30,$0c,$f8,$10,$0d,$ff

; SPREAD - S bullet firing (pulse 1 channel)
; CPU address $8c19
sound_12 ENT
            db    $2a,$30,$10,$8b,$b2,$66,$72,$66,$32,$66,$f8,$12,$66,$ff

; SPREAD - S bullet firing (noise/dmc channel)
; CPU address $8c27
sound_13 ENT
            db    $21,$30,$b0,$0e,$b0,$0d,$b0,$0c,$b0,$0b,$b0,$0a,$b0,$09,$b0,$08
            db    $b0,$07,$b0,$06,$b0,$05,$70,$0e,$70,$0d,$70,$0c,$70,$0b,$70,$0a
            db    $70,$09,$70,$08,$70,$07,$70,$06,$70,$05,$30,$0e,$30,$0d,$30,$0c
            db    $30,$0b,$30,$0a,$30,$09,$30,$08,$30,$07,$30,$06,$30,$05,$f8,$10
            db    $0e,$f8,$10,$0d,$f8,$10,$0c,$f8,$10,$0b,$f8,$10,$0a,$f8,$10,$09
            db    $f8,$10,$08,$f8,$10,$07,$f8,$10,$06,$ff

; FIRE - energy zone fire beam (noise/dmc channel)
; CPU address $8c81
sound_09 ENT
            db    $22,$30,$f0,$0e,$f0,$0d,$f0,$0c,$a0,$07,$a0,$08,$b0,$09,$c0,$0a
            db    $c0,$0b,$c0,$0c,$c0,$0d,$23,$30,$f0,$0e,$e0,$0e,$d0,$0e,$c0,$0e
            db    $b0,$0e,$a0,$0e,$90,$0e,$80,$0e,$70,$0e,$60,$0e,$50,$0e,$40,$0e
            db    $30,$0e,$f8,$20,$0e,$f8,$10,$0e,$ff

; HIBIWARE - bullet shielded wall plating ting (pulse 1 channel)
; CPU address $8cba
sound_14 ENT
            db    $21,$30,$90,$20,$c0,$08,$60,$80,$fe,$02
            dw    sound_14

sound_14_part_00 ENT
            db    $30,$20,$24,$30,$30,$80,$30,$20,$50,$08,$f8,$10,$80,$ff

; DAMEGE 1 - bullet to metal collision ting (pulse 1 channel)
; CPU address $8cd4
sound_16 ENT
            db    $23,$f0,$10,$82,$b0,$33,$22,$30,$10,$8e,$b0,$66,$70,$5a,$50,$50
            db    $40,$48,$30,$40,$30,$3f,$f8,$20,$3f,$f8,$20,$3f,$f8,$10,$3f,$f8
            db    $10,$3f,$ff

; DAMEGE 1 - bullet to metal collision ting (noise/dmc channel)
; CPU address $8cf7
sound_17 ENT
            db    $21,$30,$d0,$0b,$50,$0a,$30,$09,$70,$0a,$50,$09,$50,$09,$40,$0a
            db    $40,$0b,$30,$0b,$40,$0b,$30,$0b,$f8,$20,$0b,$f8,$20,$0b,$f8,$10
            db    $0b,$f8,$10,$0a,$ff

; DAMEGE 2 - alien heart boss hit (pulse 1 channel)
; CPU address $8d1c
sound_18 ENT
            db    $21,$30,$10,$81,$f0,$59,$24,$f0,$10,$82,$f0,$fe,$c0
            dw    sound_25_part_01

sound_18_part_00 ENT
            db    $59,$70,$d5,$51,$59,$31,$7f,$ff

; TEKI OUT - enemy destroyed (pulse 1 channel)
; CPU address $8d33
sound_19 ENT
            db    $28,$b0,$10,$83,$f1,$0d,$28,$f0,$10,$82,$f0,$fe,$c0,$d5,$50,$b3
            db    $30,$a0,$f8,$10,$a0,$ff

; CHAKUCHI - energy zone boss landing (pulse 1 channel)
; CPU address $8d49
sound_15 ENT
            db    $23,$b0,$10,$82,$f2,$70,$00,$00,$23,$b0,$f1,$ab,$f1,$67,$e1,$ab
            db    $d1,$67,$c1,$ab,$b1,$67,$a1,$ab,$91,$67,$81,$ab,$71,$67,$61,$ab
            db    $51,$67,$41,$ab,$31,$67,$f8,$21,$ab,$f8,$11,$67,$ff

; SENSOR - level 1 jungle boss siren (pulse 1 channel)
; CPU address $8d76
sound_1b ENT
            db    $21,$b0,$00,$00,$fd
            dw    sound_1b_part_00
            db    $fd
            dw    sound_1b_part_00
            db    $fd
            dw    sound_1b_part_00
            db    $ff

; CPU address $8d84
sound_1b_part_00 ENT
            db    $21,$f0,$10,$85,$f8,$12,$e0,$f8,$22,$c0,$32,$a0,$42,$80,$52,$60
            db    $62,$40,$72,$20,$82,$00,$91,$e0,$a1,$c0,$b1,$a0,$c1,$80,$d1,$60
            db    $d1,$50,$d1,$48,$d1,$44,$d1,$40,$10,$86

; CPU address $8dae
sound_1b_part_01 ENT
            db    $e1,$40,$a1,$41,$fe,$0c
            dw    sound_1b_part_01

sound_1b_part_02 ENT
            db    $b1,$40,$b1,$40,$a1,$40,$a1,$40,$51,$40,$24,$f0,$10,$82,$b1,$40
            db    $b1,$40,$71,$40,$71,$40,$31,$40,$31,$40,$f8,$11,$40,$f8,$11,$40
            db    $f8,$11,$40,$f8,$11,$40,$ff

; HIRAI 1 - ice grenade whistling noise (pulse 1 channel)
; CPU address $8ddd
sound_1a ENT
            db    $23,$f0,$f8,$10,$1f,$f8,$20,$20,$30,$21,$40,$22,$50,$23,$60,$24
            db    $70,$25,$80,$26,$90,$27,$a0,$28,$a0,$29,$a0,$2a,$90,$2b,$90,$2c
            db    $90,$2d,$80,$2e,$80,$2f,$80,$30,$70,$31,$70,$32,$70,$33,$60,$34
            db    $60,$35,$60,$36,$50,$37,$50,$38,$50,$39,$40,$3a,$40,$3b,$40,$3c
            db    $30,$3d,$30,$3e,$30,$3f,$30,$40,$f8,$20,$41,$f8,$20,$42,$f8,$20
            db    $43,$ff

; CAR - tank advancing (pulse 1 channel)
; CPU address $8e2f
sound_1e ENT
            db    $21,$b0,$10,$82,$c3,$02,$21,$70,$f8,$20,$66,$21,$b0,$c3,$01,$03
            db    $01,$c3,$01,$21,$70,$30,$33,$ff

; POWER UP - pick up weapon item (pulse 1 channel)
; CPU address $8e47
sound_1f ENT
            db    $28,$b0,$10,$8b,$a3,$fa,$b1,$7d,$70,$7f,$50,$5f,$40,$5f,$30,$5f
            db    $f8,$20,$5f,$f8,$10,$5f,$ff

; 1UP - extra life (pulse 1 channel)
; CPU address $8e5e
sound_20 ENT
            db    $22,$30,$f0,$7f,$21,$30,$f0,$7f,$00,$00,$00,$00,$25,$f0,$d0,$3f
            db    $22,$30,$d0,$7f,$25,$f0,$b0,$3f,$22,$30,$b0,$7f,$25,$f0,$90,$3f
            db    $22,$30,$90,$7f,$25,$f0,$70,$3f,$22,$30,$70,$7f,$25,$f0,$50,$3f
            db    $22,$50,$30,$7f,$25,$f0,$30,$3f,$22,$30,$30,$7f,$25,$f0,$f8,$10
            db    $3f,$22,$30,$f8,$10,$7f,$ff

; KANDEN - electrocution sound (pulse 1 channel)
; CPU address $8ea5
sound_1c ENT
            db    $21,$30,$10,$89,$d1,$fd,$fe,$28
            dw    sound_1c

sound_1c_part_00 ENT
            db    $c1,$fd,$b1,$fd,$b1,$fd,$91,$fd,$91,$fd,$71,$fd,$61,$fd,$51,$fd
            db    $51,$fd,$31,$fd,$31,$fd,$ff

; KANDEN - electrocution sound (noise/dmc channel)
; CPU address $8ec6
sound_1d ENT
            db    $21,$30,$70,$06,$fe,$28
            dw    sound_1d

sound_1d_part_00 ENT
            db    $60,$06,$60,$06,$50,$06,$50,$06,$50,$06,$40,$06,$40,$06,$40,$06
            db    $30,$06,$30,$06,$ff

; HERI - helicopter rotors (pulse 1 and pulse 2 channel)
; CPU address $8ee3
sound_21 ENT
            db    $21,$30,$10,$82,$63,$83,$33,$63,$f8,$23,$53,$00,$00

; CPU address $8ef0
sound_21_part_00 ENT
            db    $73,$83,$33,$64,$f8,$23,$53,$00,$00,$fe,$0f
            dw    sound_21_part_00

; CPU address $8efd
sound_21_part_01 ENT
            db    $83,$83,$43,$65,$33,$53,$f8,$13,$33,$fe,$10
            dw    sound_21_part_01

; CPU address $8f0a
sound_21_part_02 ENT
            db    $93,$83,$43,$66,$33,$53,$f8,$13,$33,$fe,$10
            dw    sound_21_part_02

; CPU address $8f17
sound_21_part_03 ENT
            db    $a3,$83,$43,$67,$33,$53,$f8,$13,$33,$fe,$10
            dw    sound_21_part_03

; CPU address $8f24
sound_21_part_04 ENT
            db    $93,$83,$43,$66,$33,$53,$f8,$13,$33,$fe,$08
            dw    sound_21_part_04

; CPU address $8f31
sound_21_part_05 ENT
            db    $83,$83,$43,$65,$33,$53,$f8,$13,$33,$fe,$08
            dw    sound_21_part_05

; CPU address $8f3e
sound_21_part_06 ENT
            db    $73,$83,$33,$65,$f8,$23,$53,$00,$00,$fe,$08
            dw    sound_21_part_06

; CPU address $8f4b
sound_21_part_07 ENT
            db    $63,$83,$33,$63,$f8,$23,$53,$00,$00,$fe,$08
            dw    sound_21_part_07

; CPU address $8f58
sound_21_part_08 ENT
            db    $53,$83,$f8,$23,$63,$f8,$13,$53,$00,$00,$fe,$08
            dw    sound_21_part_08

; CPU address $8f66
sound_21_part_09 ENT
            db    $43,$83,$f8,$23,$63,$f8,$13,$53,$00,$00,$fe,$08
            dw    sound_21_part_09

; CPU address $8f74
sound_21_part_0a ENT
            db    $33,$83,$f8,$13,$63,$f8,$13,$53,$00,$00,$fe,$08
            dw    sound_21_part_0a
            db    $ff

; HERI - helicopter rotors (noise/dmc channel)
; CPU address $8f83
sound_23 ENT
            db    $2e,$30

; CPU address $8f85
sound_23_part_00 ENT
            db    $f8,$20,$0e,$f8,$20,$0e,$fe,$03
            dw    sound_23_part_00

; CPU address $8f8f
sound_23_part_01 ENT
            db    $30,$0e,$30,$0e,$fe,$04
            dw    sound_23_part_01

; CPU address $8f97
sound_23_part_02 ENT
            db    $40,$0e,$40,$0e,$fe,$04
            dw    sound_23_part_02

; CPU address $8f9f
sound_23_part_03 ENT
            db    $50,$0e,$50,$0e,$fe,$06
            dw    sound_23_part_03

; CPU address $8fa7
sound_23_part_04 ENT
            db    $40,$0e,$40,$0e,$fe,$04
            dw    sound_23_part_04

; CPU address $8faf
sound_23_part_05 ENT
            db    $30,$0e,$30,$0e,$fe,$04
            dw    sound_23_part_05

; CPU address $8fb7
sound_23_part_06 ENT
            db    $f8,$20,$0e,$f8,$20,$0e,$fe,$04
            dw    sound_23_part_06
            db    $ff

; BAKUHA 1 - explosion (noise/dmc channel)
; CPU address $8fc2
sound_24 ENT
            db    $21,$30,$f0,$0e,$f0,$0f,$fe,$02
            dw    sound_24

sound_24_part_00 ENT
            db    $22,$30,$f0,$0f,$f0,$08,$f0,$0f,$f0,$08,$f0,$0f,$f0,$0c,$f0,$0b
            db    $f0,$0b,$f0,$0b,$e0,$0b,$d0,$0b,$c0,$0d,$b0,$0c,$a0,$0b,$90,$0b
            db    $b0,$0b,$70,$0b,$60,$0b,$23,$30,$50,$0b,$40,$0b,$30,$0c,$f8,$20
            db    $0c,$f8,$10,$0b,$ff

; BAKUHA 2 - game intro explosion, indoor wall explosion, and island explosion (noise/dmc channel)
; CPU address $9001
sound_25 ENT
            db    $21,$30,$f0,$0e,$f0,$0f,$fe,$04
            dw    sound_25

sound_25_part_00 ENT
            db    $22,$30,$f0,$0f,$f0,$08,$f0,$0f,$27,$30,$f0,$0c,$f0,$0b,$f0,$0b
            db    $f0,$0b,$e0,$0b,$d0,$0b,$c0,$0d,$b0,$0c,$a0,$0b,$90,$0b,$80,$0b
            db    $70,$0b,$60,$0c,$50,$0b,$40,$0b,$30,$0c

; CPU address $9035
sound_25_part_01 ENT
            db    $f8,$20,$0c,$f8,$10,$0b,$ff

; BOSS BK - tank, boss ufo, boss giant, alien guardian destroyed (pulse 1 channel)
; CPU address $903c
sound_55 ENT
            db    $23,$b0,$10,$83,$d2,$11,$d2,$11,$26,$b0,$c0,$b8,$b0,$bc,$a0,$c0
            db    $90,$c5,$70,$ca,$50,$cf,$30,$d4,$ff

; BOSS BK - tank, boss ufo, boss giant, alien guardian destroyed (noise channel)
; CPU address $9055
sound_56 ENT
            db    $21,$30,$f0,$0e,$f0,$0f,$fe,$02
            dw    sound_56

sound_56_part_00 ENT
            db    $25,$30,$f0,$0f,$f0,$0a,$f0,$0f,$f0,$0a,$f0,$0f,$f0,$0c,$f0,$0c
            db    $f0,$0b,$f0,$0b,$e0,$0b,$d0,$0c,$c0,$0d,$b0,$0d,$a0,$0c,$90,$0c
            db    $b0,$0c,$70,$0c,$60,$0c,$23,$30,$50,$0c,$40,$0c,$30,$0d,$f8,$20
            db    $0d,$f8,$20,$0c,$ff

; BOSS OUT - boss destroyed (pulse 1 channel)
; CPU address $9094
sound_57 ENT
            db    $21,$b0,$00,$00

; BOSS OUT - boss destroyed (pulse 2 channel)
; CPU address $9098
sound_58 ENT
            db    $25,$b0,$10,$83,$f1,$fd,$10,$83,$f0,$fe,$2f,$b0,$10,$83,$f0,$fe
            db    $10,$83,$91,$12,$10,$83,$b1,$23,$10,$83,$d1,$01,$10,$83,$91,$12
            db    $10,$83,$51,$1d,$10,$83,$41,$2e,$10,$83,$31,$40,$10,$83,$31,$1d
            db    $10,$83,$f8,$21,$2e,$10,$83,$f8,$21,$40,$10,$83,$f8,$11,$1d,$24
            db    $b0,$00,$00,$ff

; BOSS OUT - boss destroyed (noise channel)
; CPU address $90dc
sound_59 ENT
            db    $21,$30,$f0,$0e,$f0,$0f,$fe,$04
            dw    sound_59

sound_59_part_00 ENT
            db    $22,$30,$f0,$0f,$f0,$08,$f0,$0f,$2a,$30,$f0,$0c,$f0,$0b,$f0,$0b
            db    $f0,$0b,$e0,$0b,$d0,$0b,$c0,$0d,$b0,$0c,$a0,$0b,$90,$0b,$80,$0b
            db    $70,$0b,$60,$0c,$50,$0b,$40,$0b,$30,$0c,$f8,$20,$0c,$f8,$10,$0b
            db    $ff

; PL OUT - player death (pulse 1 channel)
; CPU address $9117
sound_52 ENT
            db    $23,$f0,$10,$81,$f0,$fe,$70,$fe,$30,$fe,$22,$30,$00,$00,$22,$30
            db    $10,$83,$f0,$8e,$f0,$97,$f0,$9b,$f0,$ad,$f0,$b7,$f0,$cd,$f0,$d9
            db    $f0,$f4,$e1,$02,$e1,$21,$e1,$32,$e1,$57,$d1,$6b,$d1,$97,$d1,$af
            db    $d1,$e4,$c2,$01,$c2,$3f,$c2,$61,$c2,$ab,$b2,$d3,$b3,$2b,$b3,$5b
            db    $b3,$c4,$b3,$fa,$b4,$76,$b4,$ba,$b5,$4e,$b5,$9e,$b6,$4e,$b6,$ae
            db    $b6,$ae,$ff

; PL OUT - player death (noise channel)
; CPU address $916a
sound_53 ENT
            db    $23,$30,$50,$0c,$40,$06,$30,$03,$22,$30,$00,$00,$24,$30,$50,$02
            db    $50,$03,$50,$04,$50,$05,$50,$06,$50,$07,$60,$08,$60,$09,$60,$0a
            db    $60,$0b,$70,$0c,$70,$0d,$70,$0e,$70,$0f,$ff

; TITLE - game intro tune (pulse 1 channel)
; CPU address $9195
sound_26 ENT
            db    $e8,$d9,$f8,$87,$0a,$e3,$03,$d9,$f7,$84,$06,$e2,$93,$73,$23,$da
            db    $f7,$84,$02,$e2,$4f,$ff

; TITLE - game intro tune (pulse 2 channel)
; CPU address $91ab
sound_27 ENT
            db    $d9,$39,$86,$0a,$e3,$53,$d9,$3a,$87,$05,$e1,$03,$e2,$b3,$73,$da
            db    $38,$85,$03,$95,$e1,$21,$47,$ff

; TITLE - game intro tune (triangle channel)
; CPU address $91c3
sound_28 ENT
            db    $d9,$6f,$e3,$53,$e1,$43,$23,$e2,$b3,$da,$90,$e3,$95,$21,$97,$ff

; TITLE - game intro tune (noise/dmc channel)
; CPU address $91d3
sound_29 ENT
            db    $d9,$33,$03,$03,$33,$da,$55,$11,$17,$ff

; from pointer table at pulse_volume_ptr_tbl (level 1)
; volume envelop for pulse channel 2 on level 1
lvl_1_pulse_volume_00 ENT
            db    $05,$06,$07,$06,$05,$04,$03,$ff

; volume control 3, 4, 3, 2 loops
lvl_1_pulse_volume_01 ENT
            db    $03,$04,$03,$02,$ff

lvl_1_pulse_volume_02 ENT
            db    $07,$06,$05,$04,$03,$02,$01,$00,$00,$00,$02,$02,$ff

lvl_1_pulse_volume_03 ENT
            db    $06,$05,$04,$03,$02,$01,$00,$00,$00,$00,$01,$01,$ff

lvl_1_pulse_volume_04 ENT
            db    $07,$06,$05,$04,$03,$03,$02,$01,$00,$00,$00,$00,$00,$00,$00,$02
            db    $02,$ff

lvl_1_pulse_volume_05 ENT
            db    $07,$06,$05,$04,$03,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01
            db    $01,$01,$ff

lvl_1_pulse_volume_06 ENT
            db    $05,$04,$03,$02,$01,$01,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01
            db    $01,$01,$ff

lvl_1_pulse_volume_07 ENT
            db    $06,$05,$04,$03,$02,$02,$02,$01,$00,$00,$00,$00,$00,$00,$00,$01
            db    $01,$ff

; BGM 1 - level 1 jungle and level 7 hangar music (pulse 2 channel)
; CPU address $924e
sound_2b ENT
            db    $ec,$01,$eb,$2a,$22,$d6,$f7,$84,$00,$e1,$40,$20,$e2,$b0,$90,$b0
            db    $90,$70,$60,$70,$60,$40,$20,$40,$e3,$90,$b0,$e2,$20

; CPU address $926b
sound_2b_part_00 ENT
            db    $d6,$f0,$00,$04,$e2,$49,$b0,$c0,$90,$b1,$e1,$10,$2f,$e2,$49,$b0
            db    $c0,$90,$b1,$e1,$10,$e2,$7e,$c0,$fe,$02
            dw    sound_2b_part_00

sound_2b_part_01 ENT
            db    $d6,$f7,$02,$00,$e2,$b0,$c0,$d6,$f7,$84,$01,$b2,$e1,$12,$d6,$f7
            db    $02,$00,$20,$c0,$20,$c0,$d6,$f1,$80,$00,$c0,$20,$c0,$20,$d6,$f7
            db    $02,$00,$e1,$10,$c0,$d6,$f7,$84,$01,$12,$22,$d6,$f7,$02,$00,$40
            db    $c0,$40,$c0,$20,$d6,$f7,$84,$01,$42,$d6,$f7,$02,$00,$e2,$b0,$c0
            db    $d6,$f7,$84,$01,$b2,$e1,$12,$d6,$f7,$02,$00,$20,$c0,$20,$c0,$d6
            db    $f1,$80,$00,$c0,$20,$c0,$20,$d6,$f7,$02,$00,$e1,$10,$c0,$d6,$f7
            db    $84,$01,$12,$22,$d6,$f7,$00,$00,$43,$93,$d6,$f7,$84,$00,$e1,$60
            db    $40,$e0,$10,$e1,$b0,$90,$80,$60,$40,$60,$40,$e1,$10,$e2,$b0,$e1
            db    $10,$e2,$b0,$90,$80,$eb,$2a,$24,$d6,$f7,$85,$01,$e3,$b2,$c0,$d6
            db    $f7,$04,$00,$b0,$e2,$11,$20,$61,$41,$20,$11,$e3,$90,$d6,$f7,$84
            db    $03,$bf,$d6,$f7,$04,$00,$83,$90,$b2,$e2,$13,$20,$42,$63,$80,$91
            db    $b0,$e1,$13,$e2,$b0,$eb,$2a,$22,$d6,$f7,$84,$03,$e3,$b0,$e2,$20
            db    $40,$60,$40,$60,$e3,$b1,$b0,$e2,$20,$40,$61,$90,$80,$90,$81,$40
            db    $6f,$e3,$83,$90,$b2,$e2,$13,$20,$42,$60,$60,$60,$c0,$60,$81,$90
            db    $e1,$13,$e2,$b3,$d6,$f7,$05,$00,$e2,$90,$90,$90,$92,$90,$90,$90
            db    $91,$91,$d6,$f7,$84,$03,$82,$d6,$f7,$05,$00,$60,$60,$60,$62,$60
            db    $60,$60,$61,$61,$d6,$f7,$84,$03,$82,$d6,$f7,$05,$00,$90,$90,$90
            db    $92,$90,$90,$90,$91,$91,$d6,$f7,$84,$03,$82,$d6,$f7,$05,$00,$60
            db    $60,$60,$62,$60,$80,$90,$b0,$e1,$10,$e2,$b1,$d6,$f7,$84,$03,$82
            db    $d6,$f7,$05,$00,$e1,$10,$10,$10,$12,$10,$10,$10,$11,$11,$d6,$f7
            db    $84,$03,$e2,$b2,$d6,$f7,$05,$00,$90,$90,$90,$92,$90,$90,$90,$91
            db    $91,$d6,$f7,$84,$03,$b2,$d6,$f7,$05,$00,$e1,$10,$10,$10,$12,$10
            db    $10,$10,$11,$11,$d6,$f7,$84,$03,$22,$d6,$f7,$05,$00,$40,$40,$40
            db    $42,$40,$40,$40,$43,$d6,$f8,$00,$00,$e3,$b0,$e2,$20,$40,$60,$40
            db    $60,$e3,$b1,$b0,$e2,$20,$40,$60,$40,$60,$91,$90,$80,$90,$60,$40
            db    $60,$e3,$b1,$b0,$e2,$20,$40,$c0,$60,$c0,$80,$c0,$92,$fe,$ff
            dw    sound_2b_part_00

; BGM 1 - level 1 jungle and level 7 hangar music (pulse 1 channel)
; CPU address $9428
sound_2a ENT
            db    $ec,$01,$e8,$d6,$f6,$01,$04,$e2,$b0,$90,$60,$40,$60,$40,$20,$10
            db    $20,$10,$e3,$b0,$90,$90,$40,$60,$90,$d6,$f6,$01,$04

; CPU address $9445
sound_2a_part_00 ENT
            db    $e3,$b9,$e2,$60,$c0,$40,$61,$70,$9f,$e3,$b9,$e2,$60,$c0,$40,$61
            db    $80,$2e,$c0,$fe,$02
            dw    sound_2a_part_00

sound_2a_part_01 ENT
            db    $d6,$f7,$03,$00,$e2,$60,$c0,$62,$82,$90,$c0,$90,$c0,$d6,$b6,$85
            db    $00,$c0,$e2,$60,$90,$b0,$d6,$f7,$03,$00,$e2,$80,$c0,$82,$92,$b0
            db    $c0,$b0,$c0,$90,$d6,$f4,$81,$00,$b2,$d6,$f7,$03,$00,$e2,$60,$c0
            db    $62,$82,$90,$c0,$90,$c0,$d6,$b6,$85,$00,$c0,$e2,$60,$90,$b0,$d6
            db    $f7,$03,$00,$e2,$80,$c0,$82,$92,$d6,$f5,$83,$00,$b3,$e1,$43,$d6
            db    $f3,$81,$00,$e1,$60,$40,$60,$40,$e0,$10,$e1,$b0,$90,$80,$60,$40
            db    $60,$40,$e1,$10,$e2,$b0,$e1,$10,$e2,$b0,$d6,$f5,$83,$03,$e3,$63
            db    $d6,$f7,$07,$03,$60,$e2,$11,$20,$61,$41,$20,$11,$e3,$90,$d6,$f7
            db    $86,$00,$e4,$b0,$b0,$b1,$b0,$d6,$f7,$85,$00,$e3,$12,$22,$e4,$b0
            db    $e3,$40,$62,$d6,$f5,$07,$00,$e3,$43,$60,$82,$93,$b0,$e2,$12,$23
            db    $20,$41,$60,$93,$80,$d6,$f7,$84,$03,$e3,$b0,$e2,$20,$40,$60,$40
            db    $60,$e3,$b1,$b0,$e2,$20,$40,$61,$90,$80,$90,$81,$40,$d6,$37,$84
            db    $03,$e2,$60,$40,$60,$e3,$b1,$b0,$e2,$20,$40,$61,$90,$80,$90,$b1
            db    $e1,$10,$d6,$f7,$84,$03,$e3,$43,$60,$82,$93,$b0,$e2,$12,$20,$20
            db    $20,$c0,$20,$41,$60,$93,$83,$d6,$f7,$06,$00,$e2,$60,$60,$60,$62
            db    $60,$60,$60,$61,$61,$42,$20,$20,$20,$22,$20,$20,$20,$21,$21,$42
            db    $60,$60,$60,$62,$60,$60,$60,$61,$61,$42,$20,$20,$20,$22,$20,$40
            db    $60,$80,$90,$81,$42,$90,$90,$90,$92,$90,$90,$90,$91,$91,$82,$60
            db    $60,$60,$62,$60,$60,$60,$61,$61,$82,$90,$90,$90,$92,$90,$90,$90
            db    $91,$81,$92,$b0,$b0,$b0,$b2,$b0,$b0,$b0,$b3,$d6,$f6,$00,$00,$e3
            db    $60,$b0,$e2,$10,$20,$10,$20,$e3,$61,$60,$b0,$e2,$10,$20,$10,$20
            db    $61,$60,$40,$60,$20,$10,$20,$e3,$61,$60,$b0,$e2,$10,$c0,$d6,$f6
            db    $01,$04,$20,$c0,$40,$c0,$62,$fe,$ff
            dw    sound_2a_part_00

; BGM 1 - level 1 jungle and level 7 hangar music (triangle channel)
; CPU address $95c7 - jungle/hangar triangle
sound_2c ENT
            db    $ec,$01,$d6,$12,$e1,$40,$20,$e2,$b0,$90,$b0,$90,$70,$60,$70,$60
            db    $40,$20,$40,$e3,$90,$b0,$e2,$20

; CPU address $95df
sound_2c_part_00 ENT
            db    $d6,$0f,$e3,$b0,$90,$b0,$41,$40,$70,$90,$b0,$90,$b0,$e2,$21,$20
            db    $10,$20,$e3,$b0,$90,$b0,$41,$40,$70,$90,$b0,$c0,$e2,$20,$e3,$b0
            db    $e2,$20,$11,$e3,$90,$fe,$03
            dw    sound_2c_part_00

sound_2c_part_01 ENT
            db    $e3,$b0,$90,$b0,$41,$40,$70,$90,$b0,$90,$b0,$e2,$21,$20,$10,$20
            db    $e3,$b0,$90,$b0,$41,$40,$70,$90,$b0,$90,$b0,$e2,$21,$20,$40,$60
            db    $d6,$12,$e3,$b1,$b2,$e2,$12,$21,$e3,$b0,$e2,$41,$60,$90,$b0,$11
            db    $11,$c0,$22,$41,$41,$20,$d6,$7f,$40,$40,$40,$d6,$12,$e3,$b1,$b2
            db    $e2,$12,$21,$e3,$b0,$e2,$41,$60,$90,$b0,$11,$12,$22,$e2,$d6,$7f
            db    $40,$40,$40,$40,$90,$90,$90,$90,$d6,$10,$e1,$60,$40,$e0,$10,$e1
            db    $b0,$90,$80,$60,$40,$60,$40,$10,$e2,$b0,$e1,$10,$e2,$b0,$90,$80
            db    $d6,$10,$e3,$b1,$b1,$b0,$e2,$11,$20,$e3,$b1,$e2,$10,$21,$e3,$60
            db    $90,$a0,$b0,$b0,$b1,$b0,$d6,$1a,$e2,$12,$22,$d6,$10,$e3,$b0,$e2
            db    $40,$d6,$7f,$60,$60,$60,$d6,$0f,$41,$40,$40,$41,$40,$40,$e3,$91
            db    $90,$90,$91,$90,$90,$e2,$21,$20,$20,$21,$20,$20,$e3,$61,$60,$60
            db    $40,$60,$80,$90

; CPU address $96bc
sound_2c_part_02 ENT
            db    $b1,$b0,$b0,$fe,$04
            dw    sound_2c_part_02

; CPU address $96c3
sound_2c_part_03 ENT
            db    $e2,$21,$20,$20,$fe,$04
            dw    sound_2c_part_03

sound_2c_part_04 ENT
            db    $41,$40,$40,$41,$40,$40,$e3,$91,$90,$90,$91,$90,$90,$e2,$20,$20
            db    $21,$d6,$20,$20,$41,$20,$d6,$3f,$63,$43,$d6,$10,$e2,$60,$60,$60
            db    $60,$c1,$60,$60,$60,$60,$c0,$60,$c0,$d6,$2f,$42,$d6,$10,$20,$20
            db    $20,$20,$c1,$20,$20,$20,$20,$c0,$20,$c0,$d6,$2f,$42,$d6,$10,$60
            db    $60,$60,$60,$c1,$60,$60,$60,$60,$c0,$60,$c0,$d6,$2f,$42,$d6,$10
            db    $20,$20,$20,$20,$c1,$20,$40,$60,$80,$90,$80,$c0,$d6,$2f,$42,$d6
            db    $10,$60,$60,$60,$60,$c1,$60,$60,$60,$60,$c0,$60,$c0,$40,$60,$80
            db    $20,$20,$20,$20,$c1,$20,$20,$20,$20,$c0,$20,$c0,$20,$20,$40,$60
            db    $60,$60,$60,$c1,$60,$60,$60,$60,$c0,$60,$c0,$20,$40,$60,$40,$40
            db    $40,$40,$c1,$40,$40,$40,$40,$c1,$c3,$cf,$c7,$d6,$10,$e3,$c0,$60
            db    $c0,$80,$c0,$d6,$2f,$92,$fe,$ff
            dw    sound_2c_part_00

; BGM 1 - level 1 jungle and level 7 hangar music (noise/dmc channel)
; CPU address $9775
sound_2d ENT
            db    $d6,$00,$00,$00,$00,$fe,$03
            dw    sound_2d

; CPU address $977e
sound_2d_part_00 ENT
            db    $40,$40,$30,$40

; CPU address $9782
sound_2d_part_01 ENT
            db    $30,$30,$30,$30,$20,$00,$30,$30,$00,$10,$00,$10,$20,$30,$30,$30
            db    $30,$30,$30,$30,$20,$00,$30,$30,$00,$10,$00,$10,$20,$40,$30,$40
            db    $fe,$03
            dw    sound_2d_part_01

sound_2d_part_02 ENT
            db    $30,$30,$30,$30,$20,$00,$30,$30,$00,$10,$00,$10,$20,$30,$30,$30
            db    $30,$30,$30,$30,$20,$00,$30,$30,$20,$20,$00,$20,$20,$00,$20,$20
            db    $40,$00,$40,$30,$00,$20,$00,$30,$40,$10,$40,$10,$00,$30,$30,$30
            db    $40,$00,$40,$30,$00,$40,$00,$30,$40,$10,$40,$10,$40,$40,$30,$30
            db    $40,$00,$40,$30,$00,$40,$00,$30,$40,$10,$40,$10,$00,$30,$30,$30
            db    $40,$00,$40,$30,$00,$40,$00,$30,$40,$10,$40,$10,$40,$40,$30,$40
            db    $30,$00,$00,$00,$10,$00,$00,$00,$30,$00,$00,$00,$40,$00,$40,$40
            db    $30,$30,$30,$30,$20,$00,$30,$30,$00,$10,$00,$10,$20,$30,$30,$30
            db    $30,$30,$30,$30,$20,$00,$30,$30,$00,$10,$00,$10,$20,$30,$40,$40
            db    $30,$30,$30,$30,$20,$00,$30,$30,$00,$10,$00,$10,$20,$30,$30,$30
            db    $30,$30,$30,$30,$20,$00,$30,$30,$00,$10,$00,$10,$30,$40,$40,$40

; CPU address $9856
sound_2d_part_03 ENT
            db    $30,$30,$30,$30,$20,$00,$30,$30,$00,$10,$00,$10,$20,$30,$30,$30
            db    $fe,$03
            dw    sound_2d_part_03

sound_2d_part_04 ENT
            db    $40,$40,$40,$00,$40,$41,$40,$20,$01,$00,$20,$01,$00

; CPU address $9877
sound_2d_part_05 ENT
            db    $30,$30,$30,$30,$20,$00,$30,$30,$30,$10,$00,$10,$20,$31,$30,$fe
            db    $03
            dw    sound_2d_part_05

sound_2d_part_06 ENT
            db    $30,$30,$30,$30,$20,$00,$40,$40,$40,$20,$40,$20,$10,$40,$30,$30

; CPU address $989a
sound_2d_part_07 ENT
            db    $30,$30,$30,$30,$20,$00,$30,$30,$30,$10,$00,$10,$20,$31,$30,$fe
            db    $03
            dw    sound_2d_part_07

sound_2d_part_08 ENT
            db    $40,$40,$40,$40,$10,$00,$40,$40,$40,$40,$c1,$c3

; CPU address $98b9
sound_2d_part_09 ENT
            db    $33,$fe,$06
            dw    sound_2d_part_09

sound_2d_part_0a ENT
            db    $30,$40,$30,$40,$30,$40,$00,$30,$fe,$ff
            dw    sound_2d_part_01

lvl_3_pulse_volume_07 ENT
            db    $07,$06,$05,$04,$03,$03,$00,$00,$00,$02,$ff

lvl_4_pulse_volume_00 ENT
            db    $03,$04,$05,$06,$07,$07,$07,$06,$06,$06,$06,$05,$05,$05,$05,$04
            db    $04,$04,$04,$03,$ff

lvl_4_pulse_volume_01 ENT
            db    $06,$07,$06,$05,$04,$03,$ff

lvl_4_pulse_volume_02 ENT
            db    $06,$07,$06,$05,$04,$03,$00,$00,$00,$00,$01,$ff

lvl_4_pulse_volume_03 ENT
            db    $04,$05,$06,$05,$04,$03,$ff

lvl_4_pulse_volume_04 ENT
            db    $04,$05,$04,$03,$ff

lvl_4_pulse_volume_05 ENT
            db    $03,$04,$03,$03,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_4_pulse_volume_06 ENT
            db    $04,$05,$06,$05,$04,$03,$ff

lvl_4_pulse_volume_07 ENT
            db    $08,$07,$06,$05,$04,$03,$00,$00,$00,$00,$01,$ff

lvl_5_pulse_volume_00 ENT
            db    $ff

; CPU address $9929
sound_2e_part_00 ENT
            db    $d6,$35,$19,$03,$e2,$41,$d6,$f5,$1d,$02,$50,$71,$d6,$f5,$1c,$02
            db    $92,$51,$d6,$f5,$1d,$02,$20,$e3,$b1,$d6,$f5,$1e,$04,$e3,$90,$e2
            db    $70,$d6,$f8,$86,$0a,$e4,$92,$e3,$00,$e4,$90,$e3,$20,$20,$e4,$91
            db    $e3,$00,$00,$e4,$92,$71,$60,$fe,$02
            dw    sound_2e_part_00

sound_2e_part_01 ENT
            db    $d6,$f7,$1d,$02,$e2,$91,$70,$90,$b1,$90,$b0,$e1,$01,$e2,$b0,$e1
            db    $00,$23,$e2,$b1,$70,$b0,$e1,$01,$e2,$b0,$e1,$00,$21,$00,$20,$43
            db    $ff

; BGM 2 - level 3 waterfall music (pulse 1 channel)
; CPU address $9985
sound_2e ENT
            db    $d6,$b8,$18,$01,$e3,$9f,$e2,$2f,$4f,$7f,$d6,$b8,$18,$00,$bf,$d6
            db    $b3,$80,$01,$bf

; CPU address $9999
sound_2e_part_02 ENT
            db    $fd
            dw    sound_2e_part_00

sound_2e_part_03 ENT
            db    $d6,$f8,$87,$00,$e4,$71,$e2,$40,$e4,$90,$90,$e2,$40,$e4,$90,$90
            db    $e2,$20,$e4,$90,$90,$e2,$00,$e4,$90,$90,$e2,$41,$e4,$71,$e2,$40
            db    $e4,$90,$90,$e2,$40,$e4,$90,$90,$e2,$20,$e4,$90,$90,$e2,$00,$e4
            db    $90,$90,$e2,$41,$fd
            dw    sound_2e_part_00

sound_2e_part_04 ENT
            db    $e8,$d6,$36,$85,$00,$e2,$90,$70,$40,$20,$40,$20,$00,$e3,$90,$e2
            db    $00,$e3,$90,$70,$90,$c3,$c7,$e8,$d6,$f7,$1f,$02,$e3,$40,$40,$41
            db    $51,$51,$d6,$36,$83,$02,$e2,$01,$00,$00,$00,$00,$20,$42,$21,$41
            db    $61,$01,$00,$00,$00,$00,$20,$42,$21,$00,$e3,$b2,$e2,$01,$00,$00
            db    $00,$00,$20,$42,$21,$41,$61,$00,$20,$40,$21,$40,$60,$41,$60,$70
            db    $61,$70,$91,$fe,$ff
            dw    sound_2e_part_02

; CPU address $9a2a
sound_2e_part_05 ENT
            db    $d6,$f7,$19,$02,$e2,$91,$d6,$f7,$1a,$02,$b0,$e1,$01,$d6,$f7,$19
            db    $02,$22,$e2,$b1,$d6,$f7,$1a,$02,$70,$41,$d6,$f7,$1b,$04,$e2,$90
            db    $e1,$70,$65,$e2,$90,$e1,$60,$48,$fe,$02
            dw    sound_2e_part_05

sound_2e_part_06 ENT
            db    $d6,$f7,$19,$03,$e1,$51,$20,$50,$71,$50,$70,$91,$70,$90,$b3,$71
            db    $40,$70,$91,$70,$90,$b1,$90,$b0,$e0,$03,$ff

; BGM 2 - level 3 waterfall music (pulse 2 channel)
; CPU address $9a71
sound_2f ENT
            db    $d6,$f6,$17,$00

; CPU address $9a75
sound_2f_part_00 ENT
            db    $e1,$70,$40,$60,$71,$70,$40,$60,$70,$40,$60,$71,$70,$40,$60,$fe
            db    $06
            dw    sound_2f_part_00

; CPU address $9a88
sound_2f_part_01 ENT
            db    $fd
            dw    sound_2e_part_05

; CPU address $9a8b
sound_2f_part_02 ENT
            db    $d6,$f7,$1f,$02

; CPU address $9a8f
sound_2f_part_03 ENT
            db    $e3,$71,$e1,$90,$e2,$90,$90,$e1,$70,$e2,$90,$90,$e1,$60,$e2,$90
            db    $90,$e1,$40,$e2,$90,$90,$e1,$71,$fe,$02
            dw    sound_2f_part_03
            db    $fd
            dw    sound_2e_part_05

sound_2f_part_04 ENT
            db    $d6,$f9,$87,$00,$e1,$90,$70,$40,$20,$40,$20,$00,$e2,$90,$e1,$00
            db    $e2,$90,$70,$90,$c3,$c7,$d6,$f7,$1f,$02,$e3,$90,$90,$91,$81,$81
            db    $d6,$f8,$85,$02,$e2,$91,$90,$90,$90,$90,$b0,$e1,$02,$e2,$b1,$e1
            db    $01,$21,$e2,$91,$90,$90,$90,$90,$b0,$e1,$02,$e2,$b1,$90,$72,$91
            db    $90,$90,$90,$90,$b0,$e1,$02,$e2,$b1,$e1,$01,$21,$e2,$40,$60,$70
            db    $61,$70,$90,$71,$90,$b0,$91,$b0,$e1,$01,$fe,$ff
            dw    sound_2f_part_01

; CPU address $9b0c
sound_2f_part_05 ENT
            db    $d6,$14,$e3,$91,$d6,$0e,$e2,$00,$e3,$90,$e2,$20,$20,$d6,$14,$e3
            db    $91,$d6,$0e,$e2,$00,$00,$d6,$1b,$e3,$92,$d6,$0f,$71,$80,$fe,$04
            dw    sound_2f_part_05

sound_2f_part_06 ENT
            db    $d6,$14,$e3,$51,$d6,$0e,$90,$50,$e2,$20,$20,$d6,$14,$e3,$91,$d6
            db    $0e,$e2,$00,$00,$d6,$1b,$e3,$92,$d6,$0f,$51,$60,$d6,$15,$e3,$71
            db    $d6,$0e,$b0,$70,$e2,$20,$20,$d6,$14,$e3,$b1,$d6,$0e,$e2,$00,$00
            db    $d6,$1b,$e3,$92,$d6,$0f,$51,$60,$ff

; BGM 2 - level 3 waterfall music (triangle channel)
; CPU address $9b67
sound_30 ENT
            db    $d6,$0d,$e2

; CPU address $9b6a
sound_30_part_00 ENT
            db    $90,$fe,$60
            dw    sound_30_part_00

; CPU address $9b6f
sound_30_part_01 ENT
            db    $fd
            dw    sound_2f_part_05

; CPU address $9b72
sound_30_part_02 ENT
            db    $d6,$0f,$e3,$71,$e2,$90,$e3,$90,$90,$e2,$70,$e3,$90,$90,$e2,$60
            db    $e3,$90,$90,$e2,$40,$e3,$90,$90,$e2,$71,$fe,$02
            dw    sound_30_part_02
            db    $fd
            dw    sound_2f_part_05

sound_30_part_03 ENT
            db    $d6,$0f,$e2,$90,$70,$40,$20,$40,$20,$00,$e3,$90,$e2,$00,$e3,$90
            db    $70,$90,$c3,$c7,$90,$90,$90,$c0,$b0,$c0,$b0,$c0,$d6,$0f,$e2,$91
            db    $91,$cb,$91,$91,$c7,$71,$71,$91,$91,$cb,$e2,$90,$90,$90,$90,$c2
            db    $01,$20,$40,$20,$20,$40,$61,$fe,$ff
            dw    sound_30_part_01

; BGM 2 - level 3 waterfall music (noise/dmc channel)
; CPU address $9bce
sound_31 ENT
            db    $d6

; CPU address $9bcf
sound_31_part_00 ENT
            db    $00,$fe,$50
            dw    sound_31_part_00

; CPU address $9bd4
sound_31_part_01 ENT
            db    $40,$fe,$10
            dw    sound_31_part_01

; CPU address $9bd9
sound_31_part_02 ENT
            db    $30,$10,$30,$30,$40,$30,$00,$30,$31,$30,$30,$40,$31,$30,$30,$10
            db    $30,$30,$40,$30,$00,$30,$31,$30,$30,$40,$40,$00,$40,$fe,$07
            dw    sound_31_part_02

sound_31_part_03 ENT
            db    $40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$c3,$40,$42,$33
            db    $40,$40,$40,$c0,$40,$30,$40,$30,$31,$31,$00,$00,$01,$00,$00,$01
            db    $00,$02,$31,$31,$00,$00,$01,$00,$00,$01,$01,$01,$31,$31,$00,$00
            db    $01,$00,$00,$01,$00,$02,$30,$30,$30,$30,$40,$40,$40,$40,$40,$40
            db    $40,$40,$40,$40,$41,$fe,$ff
            dw    sound_31_part_02

lvl_5_pulse_volume_03 ENT
            db    $08,$07,$06,$05,$04,$00,$00,$00,$00,$00,$00,$01,$ff

lvl_5_pulse_volume_04 ENT
            db    $08,$07,$06,$05,$04,$03,$02,$01,$ff

lvl_5_pulse_volume_05 ENT
            db    $07,$06,$05,$04,$03,$02,$01,$00,$00,$00,$01,$ff

lvl_5_pulse_volume_06 ENT
            db    $04,$03,$02,$02,$02,$00,$00,$00,$00,$00,$01,$ff

; CPU address $9c71
sound_32_part_00 ENT
            db    $d6,$f7,$24,$00,$e2,$91,$e1,$21,$31,$20,$01,$e2,$a0,$e1,$01,$e2
            db    $71,$91,$91,$e1,$21,$31,$20,$51,$30,$71,$e2,$71,$91,$d6,$35,$25
            db    $00

; CPU address $9c92
sound_32_part_01 ENT
            db    $e1,$21,$91,$e0,$21,$e1,$91,$fe,$02
            dw    sound_32_part_01

sound_32_part_02 ENT
            db    $21,$51,$91,$91,$21,$51,$ff

; BGM 3 - level 5 snow field music (pulse 1 channel)
; CPU address $9ca4
sound_32 ENT
            db    $e8,$d6,$37,$26,$00,$e3

; CPU address $9caa
sound_32_part_03 ENT
            db    $41,$fe,$10
            dw    sound_32_part_03

sound_32_part_04 ENT
            db    $e8

; CPU address $9cb0
sound_32_part_05 ENT
            db    $d6,$f8,$86,$05,$e2,$50,$46,$d6,$36,$84,$0f,$81,$41,$81,$91,$fe
            db    $04
            dw    sound_32_part_05

sound_32_part_06 ENT
            db    $d6,$f8,$86,$05,$e2,$80,$76,$d6,$36,$84,$0f,$b1,$71,$b1,$e1,$01
            db    $fe,$04
            dw    sound_32_part_06

; CPU address $9cd7
sound_32_part_07 ENT
            db    $d6,$f8,$86,$05,$e2,$b0,$a6,$d6,$36,$84,$0f,$e2,$21,$21,$21,$21
            db    $d6,$f8,$86,$05,$e1,$10,$06,$d6,$36,$84,$0f,$e2,$41,$41,$41,$41
            db    $fe,$02
            dw    sound_32_part_07
            db    $fd
            dw    sound_32_part_00

sound_32_part_08 ENT
            db    $91,$91,$fd
            dw    sound_32_part_00

sound_32_part_09 ENT
            db    $93,$fe,$ff
            dw    sound_32_part_05

; CPU address $9d08
sound_32_part_0a ENT
            db    $d6,$f7,$24,$00,$e1,$21,$91,$a1,$90,$71,$50,$71,$01,$21,$21,$91
            db    $a1,$90,$e0,$01,$e1,$a0,$e0,$01,$e1,$01,$2f,$c1,$d6,$35,$25,$00
            db    $e1,$51,$91,$e0,$21,$01,$e1,$51,$91,$ff

; BGM 3 - level 5 snow field music (pulse 2 channel)
; CPU address $9d32
sound_33 ENT
            db    $d6,$f7,$23,$00,$e4

; CPU address $9d37
sound_33_part_00 ENT
            db    $41,$fe,$10
            dw    sound_33_part_00

; CPU address $9d3c
sound_33_part_01 ENT
            db    $d6,$f8,$86,$05,$e2,$90,$86,$d6,$37,$86,$00,$b1,$91,$b1,$e1,$01
            db    $fe,$04
            dw    sound_33_part_01

sound_33_part_02 ENT
            db    $d6,$f8,$86,$05,$e1,$00,$e2,$b6,$d6,$37,$86,$00,$e1,$21,$01,$21
            db    $31,$fe,$04
            dw    sound_33_part_02

; CPU address $9d65
sound_33_part_03 ENT
            db    $d6,$f8,$86,$05,$e1,$30,$26,$d6,$37,$86,$00,$e2,$a1,$91,$a1,$e1
            db    $01,$d6,$f8,$86,$05,$e1,$50,$46,$d6,$37,$86,$00,$e2,$a1,$91,$a1
            db    $e1,$01,$fe,$02
            dw    sound_33_part_03
            db    $fd
            dw    sound_32_part_0a

sound_33_part_04 ENT
            db    $e0,$21,$01,$fd
            dw    sound_32_part_0a

sound_33_part_05 ENT
            db    $e0,$23,$fe,$ff
            dw    sound_33_part_01

; BGM 3 - level 5 snow field music (triangle channel)
; CPU address $9d9a
sound_34 ENT
            db    $d6,$0e,$e2

; CPU address $9d9d
sound_34_part_00 ENT
            db    $41,$fe,$10
            dw    sound_34_part_00

; CPU address $9da2
sound_34_part_01 ENT
            db    $d6,$0e,$50,$d6,$20,$42,$d6,$0e,$41,$41,$41,$41,$41,$41,$fe,$04
            dw    sound_34_part_01

; CPU address $9db4
sound_34_part_02 ENT
            db    $d6,$0e,$80,$d6,$20,$72,$d6,$0e,$71,$71,$71,$71,$71,$71,$fe,$04
            dw    sound_34_part_02

; CPU address $9dc6
sound_34_part_03 ENT
            db    $d6,$0e,$e2,$b0,$d6,$20,$a2,$d6,$0e,$a1,$a1,$a1,$a1,$a1,$a1,$e1
            db    $10,$d6,$20,$02,$d6,$0e,$01,$01,$01,$01,$01,$01,$fe,$02
            dw    sound_34_part_03

sound_34_part_04 ENT
            db    $d6,$0e,$e2

; CPU address $9de9
sound_34_part_05 ENT
            db    $21,$fe,$10
            dw    sound_34_part_05

; CPU address $9dee
sound_34_part_06 ENT
            db    $21,$91,$fe,$08
            dw    sound_34_part_06

sound_34_part_07 ENT
            db    $d6,$0e,$e2

; CPU address $9df7
sound_34_part_08 ENT
            db    $21,$fe,$10
            dw    sound_34_part_08

; CPU address $9dfc
sound_34_part_09 ENT
            db    $21,$91,$fe,$08
            dw    sound_34_part_09
            db    $fe,$ff
            dw    sound_34_part_01

; CPU address $9e06
sound_34_part_0a ENT
            db    $30,$32,$31,$31,$31,$31,$41,$30,$00,$fe,$03
            dw    sound_34_part_0a

sound_34_part_0b ENT
            db    $30,$32,$31,$31,$30,$00,$31,$30,$00,$31,$ff

; BGM 3 - level 5 snow field music (noise/dmc channel)
; CPU address $9e1e
sound_35 ENT
            db    $d6

; CPU address $9e1f
sound_35_part_00 ENT
            db    $31,$fe,$10
            dw    sound_35_part_00

; CPU address $9e24
sound_35_part_01 ENT
            db    $fd
            dw    sound_34_part_0a
            db    $fd
            dw    sound_34_part_0a

; CPU address $9e2a
sound_35_part_02 ENT
            db    $30,$32,$31,$31,$31,$31,$41,$30,$00,$fe,$03
            dw    sound_35_part_02

sound_35_part_03 ENT
            db    $31,$31,$31,$31,$40,$40,$41,$40,$40,$41

; CPU address $9e41
sound_35_part_04 ENT
            db    $31,$31,$41,$31,$31,$31,$41,$30,$00,$fe,$03
            dw    sound_35_part_04

sound_35_part_05 ENT
            db    $31,$31,$41,$31,$41,$41,$41,$40,$40

; CPU address $9e57
sound_35_part_06 ENT
            db    $31,$31,$41,$31,$31,$31,$41,$30,$00,$fe,$03
            dw    sound_35_part_06

sound_35_part_07 ENT
            db    $31,$31,$41,$31,$41,$41,$40,$40,$41,$fe,$ff
            dw    sound_35_part_01

lvl_5_pulse_volume_01 ENT
            db    $08,$07,$06,$05,$04,$03,$00,$00,$00,$00,$01,$ff

lvl_5_pulse_volume_02 ENT
            db    $06,$07,$06,$05,$04,$03,$ff

lvl_6_pulse_volume_03 ENT
            db    $05,$04,$03,$03,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_6_pulse_volume_04 ENT
            db    $08,$07,$06,$05,$04,$03,$03,$00,$00,$00,$01,$ff

lvl_6_pulse_volume_05 ENT
            db    $06,$05,$04,$03,$02,$00,$00,$00,$00,$00,$01,$ff

; BGM 4 - level 6 energy zone (pulse 1 channel)
; CPU address $9ea8
sound_36 ENT
            db    $e8,$d6,$f9,$87,$00,$e3,$c8

; CPU address $9eaf
sound_36_part_00 ENT
            db    $d6,$f9,$87,$00,$e3,$70,$80,$a0,$d6,$37,$84,$05,$e2,$08,$00,$10
            db    $30,$71,$56,$50,$30,$10,$31,$19,$31,$13,$e3,$a1,$73,$e2,$08,$00
            db    $10,$30,$71,$56,$50,$30,$10,$31,$13,$d6,$38,$86,$04,$e2,$81,$73
            db    $e2,$31,$13,$e3,$a1,$73

; CPU address $9ee5
sound_36_part_01 ENT
            db    $d6,$37,$21,$00,$e2,$01,$00,$d6,$b7,$21,$00,$e3,$32,$62,$02,$fe
            db    $04
            dw    sound_36_part_01

; CPU address $9ef8
sound_36_part_02 ENT
            db    $d6,$37,$21,$00,$e3,$71,$70,$d6,$b7,$21,$00,$e3,$a2,$e2,$12,$e3
            db    $72,$fe,$03
            dw    sound_36_part_02

sound_36_part_03 ENT
            db    $d6,$37,$21,$00,$e2,$71,$70,$d6,$f7,$21,$00,$e3,$a2,$e2,$80,$80
            db    $80,$a0,$a0,$a0,$d6,$f4,$82,$00,$e0,$51,$00,$e1,$80,$e0,$00,$e1
            db    $80,$50,$80,$50,$00,$50,$00,$e2,$80,$e1,$50,$00,$e2,$80,$e1,$00
            db    $e2,$80,$50,$80,$50,$fe,$ff
            dw    sound_36_part_00

; BGM 4 - level 6 energy zone (pulse 2 channel)
; CPU address $9f46
sound_37 ENT
            db    $d6,$f9,$87,$04,$e2,$c8

; CPU address $9f4c
sound_37_part_00 ENT
            db    $d6,$f8,$85,$05,$e2,$00,$10,$30

; CPU address $9f54
sound_37_part_01 ENT
            db    $e2,$58,$50,$70,$80,$e1,$01,$e2,$a6,$a0,$80,$70,$81,$79,$81,$73
            db    $31,$03,$fe,$02
            dw    sound_37_part_01

sound_37_part_02 ENT
            db    $d6,$f7,$21,$00

; CPU address $9f6e
sound_37_part_03 ENT
            db    $e2,$51,$50,$e3,$32,$62,$02,$fe,$04
            dw    sound_37_part_03

; CPU address $9f79
sound_37_part_04 ENT
            db    $e1,$01,$00,$e3,$a2,$e2,$12,$e3,$72,$fe,$03
            dw    sound_37_part_04

sound_37_part_05 ENT
            db    $e1,$01,$00,$e3,$a2,$e1,$10,$10,$10,$30,$30,$30,$d6,$f7,$83,$00
            db    $e0,$50,$00,$e1,$80,$e0,$00,$e1,$80,$50,$80,$50,$00,$50,$00,$e2
            db    $80,$e1,$50,$00,$e2,$80,$e1,$00,$e2,$80,$50,$80,$50,$00,$fe,$ff
            dw    sound_37_part_00

; BGM 4 - level 6 energy zone (triangle channel)
; CPU address $9fb8
sound_38 ENT
            db    $d6,$0e,$e2,$c8

; CPU address $9fbc
sound_38_part_00 ENT
            db    $d6,$0e,$e2,$00,$10,$30

; CPU address $9fc2
sound_38_part_01 ENT
            db    $50,$c0,$50,$fe,$0f
            dw    sound_38_part_01

sound_38_part_02 ENT
            db    $00,$10,$30

; CPU address $9fcc
sound_38_part_03 ENT
            db    $50,$c0,$50,$fe,$0f
            dw    sound_38_part_03

sound_38_part_04 ENT
            db    $00,$10,$30,$d6,$12

; CPU address $9fd8
sound_38_part_05 ENT
            db    $e2,$52,$32,$62,$02,$fe,$04
            dw    sound_38_part_05

; CPU address $9fe1
sound_38_part_06 ENT
            db    $e2,$02,$e3,$a2,$e2,$12,$e3,$72,$fe,$03
            dw    sound_38_part_06

sound_38_part_07 ENT
            db    $e2,$01,$00,$e3,$a2,$d6,$10,$e2,$10,$10,$10,$30,$30,$30,$d6,$90
            db    $5b,$38,$fe,$ff
            dw    sound_38_part_00

; BGM 4 - level 6 energy zone (noise/dmc channel)
; CPU address $a003
sound_39 ENT
            db    $d6

; CPU address $a004
sound_39_part_00 ENT
            db    $20,$fe,$09
            dw    sound_39_part_00

; CPU address $a009
sound_39_part_01 ENT
            db    $d6,$40,$40,$40

; CPU address $a00d
sound_39_part_02 ENT
            db    $31,$30,$40,$00,$00,$31,$30,$40,$30,$30,$fe,$03
            dw    sound_39_part_02

sound_39_part_03 ENT
            db    $31,$30,$40,$00,$00,$31,$30,$40,$40,$40

; CPU address $a025
sound_39_part_04 ENT
            db    $31,$30,$40,$00,$00,$31,$30,$40,$30,$30,$fe,$03
            dw    sound_39_part_04

sound_39_part_05 ENT
            db    $31,$30,$40,$00,$00,$31,$30,$40,$40,$40

; CPU address $a03d
sound_39_part_06 ENT
            db    $31,$30,$40,$00,$00,$31,$00,$40,$00,$00,$fe,$07
            dw    sound_39_part_06

sound_39_part_07 ENT
            db    $31,$30,$40,$30,$30,$40,$40,$40,$40,$40,$40

; CPU address $a056
sound_39_part_08 ENT
            db    $30,$00,$00,$fe,$06
            dw    sound_39_part_08

sound_39_part_09 ENT
            db    $40,$40,$40,$fe,$ff
            dw    sound_39_part_01

lvl_5_pulse_volume_07 ENT
            db    $07,$06,$05,$04,$03,$03,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_6_pulse_volume_00 ENT
            db    $05,$04,$03,$03,$03,$03,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_6_pulse_volume_01 ENT
            db    $05,$06,$07,$06,$05,$04,$03,$ff

lvl_6_pulse_volume_02 ENT
            db    $0b,$0a,$09,$08,$07,$06,$05,$04,$03,$ff

; BGM 5 - level 8 alien's lair music (pulse 1 channel)
; CPU address $a092
sound_3a ENT
            db    $dc,$f7,$29,$02,$e1,$1d,$7d,$3d,$9d

; CPU address $a09b
sound_3a_part_00 ENT
            db    $d7,$37,$28,$00,$e3,$a2,$e2,$32,$a1,$e1,$31,$e2,$01,$e1,$53,$e8
            db    $d7,$b9,$87,$00,$e3,$00,$50,$50,$e2,$00,$e1,$00,$e2,$00,$e8,$fe
            db    $02
            dw    sound_3a_part_00

sound_3a_part_01 ENT
            db    $e8,$d7,$34,$82,$00,$e2,$a1

; CPU address $a0c5
sound_3a_part_02 ENT
            db    $e2,$a0,$e1,$a0,$80,$60,$50,$30,$10,$00,$e2,$a0,$80,$fe,$02
            dw    sound_3a_part_02

sound_3a_part_03 ENT
            db    $e2,$a0,$e1,$a0,$80,$60,$50,$30,$10,$00,$e8,$e8,$d7,$fa,$88,$00

; CPU address $a0e6
sound_3a_part_04 ENT
            db    $e3,$00,$e2,$00,$fe,$03
            dw    sound_3a_part_04

sound_3a_part_05 ENT
            db    $d7,$f7,$85,$00,$e4,$a0,$e3,$a0,$e4,$a1,$a1,$d7,$fa,$88,$00

sound_3a_part_06 ENT
            db    $e3,$00,$e2,$00,$fe,$03
            dw    sound_3a_part_06
            db    $d7,$f7,$85,$00,$e4,$90,$e3,$90,$e4,$91,$91,$d7,$fa,$88,$00

; CPU address $a114
sound_3a_part_08 ENT
            db    $e3,$00,$e2,$00,$fe,$03
            dw    sound_3a_part_08

sound_3a_part_09 ENT
            db    $d7,$f7,$85,$00,$e4,$80,$e3,$80,$e4,$81,$81,$d7,$37,$84,$00,$e2
            db    $30,$e3,$a0,$70,$e2,$20,$e3,$90,$60,$e2,$10,$e3,$80,$60,$e2,$00
            db    $e3,$60,$30,$d7,$fa,$88,$00

; CPU address $a143
sound_3a_part_0a ENT
            db    $e3,$00,$e2,$00,$fe,$03
            dw    sound_3a_part_0a

; CPU address $a14b
sound_3a_part_0b ENT
            db    $d7,$f7,$85,$00,$e4,$a0,$e3,$a0,$e4,$a1,$a1,$d7,$fa,$88,$00

; CPU address $a15a
sound_3a_part_0c ENT
            db    $e3,$00,$e2,$00,$fe,$03
            dw    sound_3a_part_0c

sound_3a_part_0d ENT
            db    $d7,$f7,$85,$00,$e4,$90,$e3,$90,$e4,$91,$91,$e8,$d7,$f6,$84,$02
            db    $e3,$80,$80,$80,$80,$80,$80,$81,$80,$a2,$e2,$80,$80,$80,$80,$80
            db    $80,$81,$a1,$e1,$30,$70,$60,$60,$60,$30,$30,$30,$60,$60,$20,$20
            db    $50,$50,$10,$10,$60,$60,$60,$30,$30,$30,$80,$80,$50,$50,$a0,$e0
            db    $12,$fe,$ff
            dw    sound_3a_part_00

; BGM 5 - level 8 alien's lair music (pulse 2 channel)
; CPU address $a1a7
sound_3b ENT
            db    $dc,$f7,$29,$02,$e1,$6d,$e0,$0d,$e1,$8d,$e0,$2d

; CPU address $a1b3
sound_3b_part_00 ENT
            db    $d7,$f7,$27,$00,$e2,$32,$62,$e1,$31,$61,$e2,$51,$e1,$93,$d7,$3b
            db    $89,$00,$e4,$00,$50,$50,$e3,$00,$e2,$00,$e3,$00,$fe,$02
            dw    sound_3b_part_00

; CPU address $a1d3
sound_3b_part_01 ENT
            db    $d7,$39,$86,$00,$e2,$a0,$e1,$a0,$80,$60,$50,$30,$10,$00,$e2,$a0
            db    $80,$fe,$03
            dw    sound_3b_part_01

sound_3b_part_02 ENT
            db    $d7,$37,$2a,$04,$e1,$75,$d7,$fa,$87,$00,$e4,$a0,$e3,$a0,$e4,$a1
            db    $a1,$d7,$37,$2a,$04,$e1,$65,$d7,$fa,$87,$00,$e4,$90,$e3,$90,$e4
            db    $91,$91,$d7,$37,$2a,$04,$e1,$55,$d7,$fa,$87,$00,$e4,$80,$e3,$80
            db    $e4,$81,$81,$d7,$fb,$8a,$00,$e1,$30,$e3,$a0,$70,$e2,$20,$e3,$90
            db    $60,$e2,$10,$e3,$80,$60,$e2,$00,$e3,$60,$30,$d7,$37,$2a,$04,$e1
            db    $75,$d7,$fa,$87,$00,$e4,$a0,$e3,$a0,$e4,$a1,$a1,$d7,$37,$2a,$04
            db    $e1,$65,$d7,$fa,$87,$00,$e4,$90,$e3,$90,$e4,$91,$91,$d7,$f8,$86
            db    $02,$e2,$10,$10,$10,$10,$10,$10,$11,$10,$32,$e1,$10,$10,$10,$10
            db    $10,$10,$11,$31,$70,$a0,$e0,$30,$30,$30,$e1,$a0,$a0,$a0,$e0,$20
            db    $20,$e1,$a0,$a0,$e0,$10,$10,$e1,$80,$80,$e0,$30,$30,$30,$e1,$a0
            db    $a0,$a0,$e0,$50,$50,$00,$00,$60,$82,$fe,$ff
            dw    sound_3b_part_00

; BGM 5 - level 8 alien's lair music (triangle channel)
; CPU address $a295
sound_3c ENT
            db    $d7,$12,$e2,$33,$43,$33,$43,$33,$43,$fe,$04
            dw    sound_3c

; CPU address $a2a2
sound_3c_part_00 ENT
            db    $d7,$0f,$e2,$00,$e1,$00,$fe,$16
            dw    sound_3c_part_00

sound_3c_part_01 ENT
            db    $d7,$20,$e1,$12,$02,$d7,$12,$e2,$a1,$81,$d7,$20,$a2,$82,$d7,$12
            db    $61,$51,$d7,$20,$62,$52,$d7,$12,$31,$11

; CPU address $a2c6
sound_3c_part_02 ENT
            db    $d7,$0e,$e2,$00,$e1,$00,$e2,$00,$e1,$00,$e2,$00,$e1,$00,$d7,$90
            db    $e1,$05,$fe,$03
            dw    sound_3c_part_02

sound_3c_part_03 ENT
            db    $d7,$17,$e1,$30,$e2,$a0,$70,$e1,$20,$e2,$90,$60,$e1,$10,$e2,$80
            db    $60,$e1,$00,$e2,$60,$30

sound_3c_part_04 ENT
            db    $d7,$0e,$e2,$00,$e1,$00,$e2,$00,$e1,$00,$e2,$00,$e1,$00,$d7,$90
            db    $e1,$05,$fe,$02
            dw    sound_3c_part_04
            db    $d7,$0e

; CPU address $a30a
sound_3c_part_06 ENT
            db    $e2,$10,$e1,$10,$fe,$0c
            dw    sound_3c_part_06

sound_3c_part_07 ENT
            db    $d7,$2f,$e2,$32,$32,$21,$21,$d7,$10,$10,$10,$10,$10,$d7,$2f,$32
            db    $32,$51,$51,$d7,$10,$60,$80,$80,$80,$fe,$ff
            dw    sound_3c_part_00

; BGM 5 - level 8 alien's lair music (noise/dmc channel)
; CPU address $a32f
sound_3d ENT
            db    $d7

; CPU address $a330
sound_3d_part_00 ENT
            db    $33,$fe,$16

; CPU address $a333
sound_3d_part_01 ENT
            dw    sound_3d_part_00

; CPU address $a335
sound_3d_part_02 ENT
            db    $40,$40,$40,$40,$40,$40,$40,$30

; CPU address $a33d
sound_3d_part_03 ENT
            db    $30,$30,$30,$30,$00,$00,$40,$00,$30,$00,$40,$00,$40,$00,$00,$00
            db    $30,$30,$40,$40,$40,$40,$fe,$02
            dw    sound_3d_part_03

; CPU address $a357
sound_3d_part_04 ENT
            db    $30,$00,$00,$30,$00,$00,$40,$00,$30,$00,$fe,$02
            dw    sound_3d_part_04

sound_3d_part_05 ENT
            db    $30,$00,$00,$30,$00,$00,$40,$40,$40,$40

; CPU address $a36f
sound_3d_part_06 ENT
            db    $30,$30,$30,$30,$30,$30,$40,$40,$40,$30,$40,$30,$fe,$03
            dw    sound_3d_part_06

sound_3d_part_07 ENT
            db    $40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$30,$30,$30,$30
            db    $30,$30,$40,$40,$40,$30,$40,$30,$30,$30,$30,$30,$30,$30,$40,$40
            db    $40,$40,$40,$40,$30,$30,$30,$40,$30,$30,$30,$00,$30,$40,$30,$30
            db    $30,$30,$30,$40,$30,$30,$30,$00,$30,$40,$40,$40,$40,$30,$30,$40
            db    $30,$30,$40,$30,$40,$30,$40,$40,$40,$40,$40,$30,$30,$40,$30,$30
            db    $40,$30,$40,$30,$40,$40,$40,$30,$fe,$ff
            dw    sound_3d_part_03

lvl_2_pulse_volume_00 ENT
            db    $07,$07,$06,$05,$04,$03,$00,$00,$00,$01,$01,$01,$ff

lvl_2_pulse_volume_01 ENT
            db    $07,$06,$05,$04,$03,$ff

lvl_2_pulse_volume_02 ENT
            db    $03,$04,$05,$04,$03,$02,$ff

lvl_2_pulse_volume_03 ENT
            db    $06,$07,$06,$05,$04,$03,$00,$00,$00,$00,$01,$01,$ff

lvl_2_pulse_volume_04 ENT
            db    $07,$06,$05,$04,$03,$00,$00,$00,$00,$00,$01,$01,$ff

lvl_2_pulse_volume_05 ENT
            db    $05,$04,$03,$03,$03,$00,$00,$00,$00,$00,$01,$01,$ff

; CPU address $a41c
sound_3e_part_00 ENT
            db    $d6,$35,$08,$02,$e2,$41,$41,$d6,$35,$0a,$01,$71,$41,$b2,$92,$71
            db    $fe,$03
            dw    sound_3e_part_00

sound_3e_part_01 ENT
            db    $d6,$35,$08,$02,$e2,$41,$41,$d6,$35,$0a,$01,$71,$41,$92,$b2,$e1
            db    $01

; CPU address $a44a
sound_3e_part_02 ENT
            db    $d6,$f7,$08,$02,$e2,$51,$51,$d6,$35,$0a,$01,$91,$51,$e1,$02,$e2
            db    $b2,$91,$fe,$03
            dw    sound_3e_part_02

sound_3e_part_03 ENT
            db    $d6,$f7,$08,$02,$51,$51,$d6,$35,$0a,$01,$91,$51,$b2,$e1,$02,$11
            db    $ff

; 3D BGM - indoor/base level music (pulse 1 channel)
; CPU address $a468
sound_3e ENT
            db    $ec,$01,$d6,$f7,$08,$02,$e2,$41,$41,$d6,$f5,$0a,$01,$71,$41,$b2
            db    $92,$71,$fe,$03
            dw    sound_3e

sound_3e_part_04 ENT
            db    $d6,$f7,$08,$02,$e2,$41,$41,$d6,$f5,$0a,$01,$71,$41,$92,$b2,$e1
            db    $01

; CPU address $a48f
sound_3e_part_05 ENT
            db    $d6,$f7,$08,$02,$e2,$51,$51,$d6,$f5,$0a,$01,$91,$51,$e1,$02,$e2
            db    $b2,$91,$fe,$03
            dw    sound_3e_part_05

sound_3e_part_06 ENT
            db    $d6,$f7,$08,$02,$51,$51,$d6,$f5,$0a,$01,$91,$51,$b2,$e1,$02,$11

; CPU address $a4b5
sound_3e_part_07 ENT
            db    $d6,$37,$0b,$02,$e2,$00,$01,$e3,$b4,$d6,$f7,$0d,$03,$e2,$91,$91
            db    $b3,$d6,$37,$0b,$02,$e3,$90,$91,$b4,$d6,$f7,$0d,$03,$e1,$01,$01
            db    $23,$d6,$37,$0b,$02,$e2,$00,$01,$e3,$b4,$d6,$f7,$0d,$03,$e1,$41
            db    $41,$53,$d6,$37,$0b,$02,$e3,$90,$91,$b4,$d6,$f7,$0d,$02,$e1,$90
            db    $92,$90,$92,$fd
            dw    sound_3e_part_00

; CPU address $a4fb
sound_3e_part_08 ENT
            db    $d6,$35,$84,$08,$e3,$73,$43,$83,$43,$fe,$04
            dw    sound_3e_part_08

; CPU address $a508
sound_3e_part_09 ENT
            db    $71,$71,$41,$41,$81,$81,$41,$41,$fe,$04
            dw    sound_3e_part_09
            db    $fd
            dw    sound_3e_part_00
            db    $fe,$ff
            dw    sound_3e_part_07

; CPU address $a51b
sound_3e_part_0a ENT
            db    $d6,$f7,$08,$02,$e2,$91,$91,$d6,$f7,$09,$01,$e1,$01,$e2,$91,$e1
            db    $32,$22,$01,$fe,$03
            dw    sound_3e_part_0a

sound_3e_part_0b ENT
            db    $d6,$f7,$08,$02,$e2,$91,$91,$d6,$f7,$09,$01,$e1,$01,$e2,$91,$e1
            db    $22,$32,$41

; CPU address $a545
sound_3e_part_0c ENT
            db    $d6,$f7,$08,$02,$e2,$b1,$b1,$d6,$f7,$09,$01,$e1,$21,$e2,$b1,$e1
            db    $52,$42,$21,$fe,$03
            dw    sound_3e_part_0c

sound_3e_part_0d ENT
            db    $d6,$f7,$08,$02,$e2,$b1,$b1,$d6,$f7,$09,$01,$e1,$21,$e2,$b1,$e1
            db    $42,$52,$61,$ff

; 3D BGM - indoor/base level music (pulse 2 channel)
; CPU address $a570
sound_3f ENT
            db    $ec,$01,$fd
            dw    sound_3e_part_0a

sound_3f_part_00 ENT
            db    $d6,$f7,$0b,$02,$e2,$50,$51,$44,$d6,$b7,$0c,$03,$e1,$21,$21,$43
            db    $d6,$f7,$0b,$02,$e2,$20,$21,$44,$d6,$b7,$0c,$03,$e1,$51,$51,$73
            db    $d6,$f7,$0b,$02,$e2,$50,$51,$44,$d6,$b7,$0c,$03,$e1,$91,$91,$b3
            db    $d6,$f7,$0b,$02,$e2,$20,$21,$44,$d6,$b7,$0c,$03,$e0,$20,$22,$40
            db    $42,$fd
            dw    sound_3e_part_0a

; CPU address $a5b9
sound_3f_part_01 ENT
            db    $d6,$38,$87,$08,$e2,$03,$e3,$93,$e2,$13,$e3,$93,$fe,$04
            dw    sound_3f_part_01

; CPU address $a5c9
sound_3f_part_02 ENT
            db    $e2,$01,$01,$e3,$91,$91,$e2,$11,$11,$e3,$91,$91,$fe,$04
            dw    sound_3f_part_02
            db    $fe,$ff
            dw    sound_3f

; CPU address $a5dd
sound_3f_part_03 ENT
            db    $d6,$10,$e3

; CPU address $a5e0
sound_3f_part_04 ENT
            db    $91,$fe,$20
            dw    sound_3f_part_04

; CPU address $a5e5
sound_3f_part_05 ENT
            db    $b1,$fe,$20
            dw    sound_3f_part_05
            db    $ff

; 3D BGM - indoor/base level music (triangle channel)
; CPU address $a5eb
sound_40 ENT
            db    $ec,$01,$d6,$10,$e2,$91,$91,$cb,$fe,$04
            dw    sound_40

; CPU address $a5f7
sound_40_part_00 ENT
            db    $e3,$b1,$fe,$20
            dw    sound_40_part_00

; CPU address $a5fd
sound_40_part_01 ENT
            db    $d6,$10,$e2,$50,$50,$c0,$d6,$7f,$44,$d6,$10,$21,$21,$43,$20,$20
            db    $c0,$d6,$7f,$44,$d6,$10,$51,$51,$73,$50,$50,$c0,$d6,$7f,$44,$d6
            db    $10,$91,$91,$b3,$20,$20,$c0,$d6,$7f,$44,$d6,$10,$20,$22,$40,$42
            db    $fd
            dw    sound_3f_part_03

; CPU address $a630
sound_40_part_02 ENT
            db    $d6,$15,$e2,$03,$93,$13,$93,$fe,$04
            dw    sound_40_part_02

; CPU address $a63b
sound_40_part_03 ENT
            db    $01,$01,$91,$91,$11,$11,$91,$91,$fe,$04
            dw    sound_40_part_03
            db    $fd
            dw    sound_3f_part_03
            db    $fe,$ff
            dw    sound_40_part_01

; CPU address $a64e
sound_40_part_04 ENT
            db    $31,$01,$41,$01,$31,$31,$41,$01,$fe,$03
            dw    sound_40_part_04

sound_40_part_05 ENT
            db    $31,$01,$41,$01,$31,$31,$41,$40,$40

; CPU address $a663
sound_40_part_06 ENT
            db    $31,$01,$41,$01,$31,$31,$41,$01,$fe,$03
            dw    sound_40_part_06

sound_40_part_07 ENT
            db    $31,$01,$41,$01,$40,$40,$41,$41,$40,$40,$ff

; 3D BGM - indoor/base level music (noise/dmc channel)
; CPU address $a67a
sound_41 ENT
            db    $d6,$31,$31,$03,$03,$03,$fe,$03
            dw    sound_41

sound_41_part_00 ENT
            db    $31,$31,$33,$33,$40,$40,$41

; CPU address $a68b
sound_41_part_01 ENT
            db    $31,$01,$41,$01,$31,$31,$41,$01,$fe,$03
            dw    sound_41_part_01

sound_41_part_02 ENT
            db    $31,$01,$41,$01,$31,$31,$41,$40,$40

; CPU address $a6a0
sound_41_part_03 ENT
            db    $40,$40,$30,$40,$00,$00,$31,$31,$31,$41,$00,$00,$fe,$03
            dw    sound_41_part_03

sound_41_part_04 ENT
            db    $40,$40,$30,$40,$00,$00,$31,$40,$40,$00,$00,$40,$40,$00,$00,$fd
            dw    sound_40_part_04

sound_41_part_05 ENT
            db    $31,$31,$41,$01,$31,$31,$41,$01,$31,$01,$41,$01,$31,$31,$41,$01
            db    $31,$31,$41,$01,$31,$31,$41,$01,$31,$01,$41,$01,$31,$31,$40,$40
            db    $40,$40

; CPU address $a6e4
sound_41_part_06 ENT
            db    $31,$31,$41,$31,$fe,$03
            dw    sound_41_part_06

; CPU address $a6ec
sound_41_part_07 ENT
            db    $31,$31,$41,$41

; CPU address $a6f0
sound_41_part_08 ENT
            db    $31,$31,$41,$31,$fe,$03
            dw    sound_41_part_08

sound_41_part_09 ENT
            db    $40,$40,$41,$40,$40,$40,$40,$fd
            dw    sound_40_part_04
            db    $fe,$ff
            dw    sound_41_part_03

lvl_2_pulse_volume_06 ENT
            db    $05,$06,$05,$04,$03,$02,$00,$00,$00,$00,$00,$01,$ff

lvl_6_pulse_volume_06 ENT
            db    $0c,$0b,$0a,$09,$08,$07,$06,$ff

lvl_6_pulse_volume_07 ENT
            db    $08,$07,$06,$05,$04,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_7_pulse_volume_00 ENT
            db    $0a,$09,$08,$07,$06,$05,$04,$00,$00,$00,$00,$01,$ff

; CPU address $a735
sound_43_part_00 ENT
            db    $e4,$60,$80,$60,$90,$60,$80,$60,$80,$60,$b0,$60,$80,$fe,$02
            dw    sound_43_part_00

; CPU address $a746
sound_43_part_01 ENT
            db    $e4,$80,$90,$80,$b0,$80,$90,$80,$90,$80,$e3,$10,$e4,$80,$90,$fe
            db    $02
            dw    sound_43_part_01

; CPU address $a759
sound_43_part_02 ENT
            db    $e4,$90,$b0,$90,$e3,$10,$e4,$90,$b0,$90,$b0,$90,$e3,$10,$e4,$90
            db    $b0,$fe,$02
            dw    sound_43_part_02

sound_43_part_03 ENT
            db    $e4,$b0,$e3,$10,$e4,$b0,$e3,$20,$e4,$b0,$e3,$10,$e4,$b0,$e3,$10
            db    $e4,$b0,$e3,$20,$e4,$b0,$e3,$10,$10,$20,$10,$40,$10,$20,$10,$40
            db    $10,$50,$10,$80,$ff

; BOSS - indoor/base boss screen music (pulse 1 channel)
; CPU address $a793
sound_42 ENT
            db    $d7,$36,$0e,$00,$e2,$60,$61,$60,$90,$80,$63,$40,$50,$e2,$60,$e3
            db    $61,$60,$e2,$90,$80,$91,$81,$41,$80,$81,$80,$b0,$90,$83,$60,$70
            db    $e2,$80,$e3,$81,$80,$e2,$b0,$90,$b1,$91,$81,$90,$91,$90,$e1,$10
            db    $e2,$b0,$93,$e2,$70,$80,$90,$e3,$91,$90,$e1,$10,$e2,$b0,$e1,$11
            db    $e2,$b1,$91,$b0,$b1,$b0,$e1,$20,$10,$e2,$b3,$e2,$b0,$e1,$00,$10
            db    $e2,$11,$10,$e1,$40,$50,$11,$51,$81,$fe,$02
            dw    sound_42

sound_42_part_00 ENT
            db    $e8,$d7,$38,$2f,$00,$e2,$20,$21,$e3,$b0,$b1,$d7,$38,$87,$00,$e2
            db    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$10,$20,$20,$20,$20
            db    $20,$20,$d7,$38,$2f,$00,$e2,$20,$21,$80,$81,$e1,$10,$10,$10,$10
            db    $10,$10,$10,$10,$10,$10,$10,$e2,$b0,$e1,$10,$10,$10,$10,$10,$10
            db    $e2,$60,$61,$40,$41,$d7,$38,$87,$00,$e2,$20,$20,$20,$20,$20,$20
            db    $20,$20,$20,$20,$20,$10,$20,$20,$20,$20,$20,$20,$d7,$36,$2f,$00
            db    $e2,$20,$21,$80,$81,$e1,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
            db    $10,$10,$40,$40,$40,$40,$40,$40,$d7,$f6,$2f,$00,$e8,$e1,$60,$60
            db    $60,$60,$61,$c5,$fe,$ff
            dw    sound_42

; BOSS - indoor/base boss screen music (pulse 2 channel)
; CPU address $a878
sound_43 ENT
            db    $d7,$f8,$2e,$00,$fd
            dw    sound_43_part_00
            db    $fd
            dw    sound_43_part_00

sound_43_part_04 ENT
            db    $d7,$f8,$30,$00,$e2,$60,$61,$40,$41,$d7,$f8,$87,$00,$e1,$60,$60
            db    $60,$60,$60,$60,$80,$80,$80,$80,$80,$80,$90,$90,$90,$90,$90,$90
            db    $b0,$b0,$b0,$b0,$b0,$b0,$60,$60,$60,$60,$60,$60,$80,$80,$80,$80
            db    $80,$80,$90,$90,$90,$90,$90,$90,$e0,$10,$10,$10,$10,$10,$10,$e1
            db    $60,$60,$60,$60,$60,$60,$80,$80,$80,$80,$80,$80,$90,$90,$90,$90
            db    $90,$90,$b0,$b0,$b0,$b0,$b0,$b0,$60,$60,$60,$60,$60,$60,$80,$80
            db    $80,$80,$80,$80,$90,$90,$90,$90,$90,$90,$e0,$10,$10,$10,$10,$d7
            db    $f8,$30,$00,$11,$c5,$fe,$ff
            dw    sound_43

; BOSS - indoor/base boss screen music (triangle channel)
; CPU address $a8fb
sound_44 ENT
            db    $d7,$12,$e2,$60,$60,$c0,$60,$90,$80,$d7,$7f,$63,$d7,$10,$40,$50
            db    $e2,$60,$d7,$12,$e3,$61,$60,$e2,$90,$80,$d1,$2f,$e2,$80,$dd,$28
            db    $90,$d7,$28,$81,$41,$d7,$12,$80,$80,$c0,$80,$b0,$90,$d7,$7f,$83
            db    $d7,$10,$60,$70,$e2,$80,$d7,$12,$e3,$81,$80,$e2,$b0,$90,$d7,$2f
            db    $b1,$91,$81,$d7,$12,$90,$90,$c0,$90,$e1,$10,$e2,$b0,$d7,$7f,$93
            db    $d7,$10,$e2,$70,$80,$90,$e3,$91,$90,$e1,$10,$e2,$b0,$d7,$2f,$e1
            db    $11,$e2,$b1,$91,$d7,$12,$b0,$b0,$c0,$b0,$e1,$20,$10,$d7,$7f,$e2
            db    $b3,$d7,$10,$e2,$b0,$e1,$00,$10,$d7,$12,$e2,$11,$10,$e1,$40,$50
            db    $d7,$2f,$11,$51,$81,$fe,$02
            dw    sound_44

sound_44_part_00 ENT
            db    $d7,$12,$e2,$60,$61,$40,$41,$d7,$10,$e2,$20,$20,$20,$20,$20,$20
            db    $20,$20,$20,$20,$20,$10,$20,$20,$20,$20,$20,$20,$d7,$12,$e2,$20
            db    $21,$80,$81,$d7,$10,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60
            db    $40,$60,$60,$60,$60,$60,$60,$d7,$12,$e2,$60,$61,$40,$41,$d7,$10
            db    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$10,$20,$20,$20,$20
            db    $20,$20,$d7,$12,$20,$21,$80,$81,$d7,$0f,$60,$60,$60,$60,$60,$60
            db    $80,$80,$80,$80,$80,$80,$90,$90,$90,$90,$90,$90,$d7,$0f,$60,$60
            db    $60,$60,$60,$c0,$c5,$fe,$ff
            dw    sound_44

; CPU address $a9fd
sound_45_part_00 ENT
            db    $40,$40,$00,$40,$40,$00

; CPU address $aa03
sound_45_part_01 ENT
            db    $40,$40,$40,$40,$40,$30,$fe,$03
            dw    sound_45_part_01
            db    $ff

; BOSS - indoor/base boss screen music (noise/dmc channel)
; CPU address $aa0e
sound_45 ENT
            db    $d7,$30,$40,$10,$30,$40,$30,$30,$10,$00,$10,$40,$40,$30,$40,$10
            db    $30,$40,$30,$40,$30,$40,$30,$40,$40,$fe,$07
            dw    sound_45

sound_45_part_02 ENT
            db    $30,$40,$10,$30,$40,$30,$30,$10,$00,$10,$40,$40,$30,$40,$10,$30
            db    $40,$30,$40,$40,$40,$40,$40,$40,$fd
            dw    sound_45_part_00
            db    $fd
            dw    sound_45_part_00
            db    $fd
            dw    sound_45_part_00
            db    $fd
            dw    sound_45_part_00

sound_45_part_03 ENT
            db    $40,$40,$40,$40,$40,$00,$40,$30,$40,$30,$40,$40,$fe,$ff
            dw    sound_45

lvl_2_pulse_volume_07 ENT
            db    $08,$07,$06,$05,$04,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_3_pulse_volume_00 ENT
            db    $06,$07,$06,$05,$04,$03,$ff

lvl_3_pulse_volume_01 ENT
            db    $04,$05,$04,$03,$ff

lvl_3_pulse_volume_06 ENT
            db    $09,$08,$07,$06,$05,$04,$03,$00,$00,$00,$00,$01,$ff

lvl_7_pulse_volume_05 ENT
            db    $08,$07,$06,$05,$04,$03,$03,$00,$00,$00,$00,$01,$ff

; PCLR - end of level tune (pulse 1 channel)
; CPU address $aa92 - end of level tune
sound_46 ENT
            db    $d7,$f7,$35,$00,$e1,$c0,$10,$10,$10,$12,$30,$30,$30,$30,$e2,$b0
            db    $b0,$b0,$b1,$d7,$f7,$0f,$00,$e2,$40,$50,$90,$d7,$f7,$11,$02,$bd
            db    $ff

; PCLR - end of level tune (pulse 2 channel)
; CPU address $aab3
sound_47 ENT
            db    $d7,$f7,$16,$00,$e1,$c0,$40,$40,$40,$42,$60,$60,$60,$60,$20,$20
            db    $20,$21,$d7,$f7,$0f,$00,$e2,$90,$b0,$e1,$20,$d7,$f7,$10,$02,$4d
            db    $ff

; PCLR - end of level tune (triangle channel)
; CPU address $aad4
sound_48 ENT
            db    $d7,$10,$e2,$c0,$90,$90,$90,$90,$c1,$b0,$b0,$b0,$b0,$70,$70,$70
            db    $70,$c0,$e3,$70,$90,$e2,$00,$d7,$90,$4d,$ff

; PCLR - end of level tune (noise/dmc channel)
; CPU address $aaef
sound_49 ENT
            db    $d7,$c0,$40,$40,$40,$40,$11,$40,$40,$40,$40,$40,$40,$40,$40,$c0
            db    $30,$40,$40,$40,$ff

lvl_3_pulse_volume_02 ENT
            db    $08,$07,$06,$05,$04,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_3_pulse_volume_03 ENT
            db    $06,$05,$04,$03,$03,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_3_pulse_volume_04 ENT
            db    $05,$04,$03,$02,$02,$02,$00,$00,$00,$01,$ff

lvl_3_pulse_volume_05 ENT
            db    $08,$07,$06,$05,$04,$03,$00,$00,$00,$01,$ff

; OVER - game over/after end credits, presented by konami (pulse 1 channel)
; CPU address $ab34
sound_4e ENT
            db    $e8,$d7,$b7,$12,$02,$e2,$c0,$41,$42,$d7,$f7,$13,$02,$70,$90,$b0
            db    $40,$41,$22,$03,$e1,$00,$20,$45,$e2,$22,$32,$41,$e8,$d7,$f3,$14
            db    $00,$e1,$41,$11,$e2,$a1,$97,$ff

; OVER - game over/after end credits, presented by konami (pulse 2 channel)
; CPU address $ab5c
sound_4f ENT
            db    $d7,$f8,$12,$02,$e2,$c0,$91,$92,$70,$90,$b0,$90,$91,$72,$53,$d7
            db    $38,$12,$02,$e1,$00,$20,$45,$d7,$f8,$12,$02,$e2,$72,$82,$91,$d7
            db    $37,$15,$00,$e0,$41,$11,$e1,$a1,$97,$ff

; OVER - game over/after end credits, presented by konami (triangle channel)
; CPU address $ab86
sound_50 ENT
            db    $d7,$10,$e2,$c0,$90,$c0,$90,$c0,$c0,$e3,$70,$90,$b0,$90,$91,$72
            db    $d7,$7f,$53,$d7,$2f,$e2,$00,$20,$d7,$7f,$45,$d7,$10,$e3,$72,$82
            db    $91,$d7,$0f,$e2,$41,$11,$e3,$a1,$d7,$90,$97,$ff

; OVER - game over/after end credits, presented by konami (noise/dmc channel)
; CPU address $abb2
sound_51 ENT
            db    $d7,$c0,$30,$00,$31,$c0,$00,$00,$00,$40,$40,$30,$40,$40,$30,$43
            db    $00,$00,$05,$30,$00,$00,$30,$00,$00,$31,$d7,$01,$01,$01,$01,$ff

lvl_7_pulse_volume_01 ENT
            db    $07,$08,$07,$06,$05,$04,$03,$ff

lvl_7_pulse_volume_02 ENT
            db    $07,$06,$05,$04,$03,$03,$03,$03,$03,$03,$00,$00,$00,$00,$01,$ff

lvl_7_pulse_volume_03 ENT
            db    $ff

lvl_7_pulse_volume_04 ENT
            db    $ff

; CPU address $abec
sound_4a_part_00 ENT
            db    $d6,$37,$85,$03,$e2,$75,$e4,$00,$00,$01,$01,$c1,$e2,$77,$e4,$00
            db    $00,$01,$01,$c1,$e2,$b7,$e4,$00,$00,$e2,$52,$72,$91,$47,$07,$e2
            db    $57,$52,$42,$21,$07,$e3,$42,$52,$71,$e2,$25,$70,$90,$77,$e3,$b7
            db    $b2,$e2,$02,$21,$e2,$75,$e4,$00,$00,$01,$01,$c1,$e2,$77,$e4,$00
            db    $00,$01,$01,$c1,$e2,$b7,$e4,$00,$00,$e2,$52,$72,$91,$47,$07,$27
            db    $22,$02,$e3,$b1,$e2,$07,$42,$52,$71,$e2,$25,$20,$40,$27,$70,$90
            db    $b1,$90,$b0,$e1,$01,$e2,$57,$d6,$37,$32,$00,$e1,$01,$01,$e2,$b1
            db    $e1,$03,$01,$e2,$b1,$e1,$01,$e2,$b1,$b1,$91,$b3,$b1,$91,$b1,$91
            db    $91,$71,$91,$d6,$37,$85,$03,$92,$b2,$e1,$01,$d6,$37,$84,$08,$43
            db    $23,$03,$e2,$b3,$d6,$37,$32,$00,$e1,$21,$21,$01,$23,$21,$01,$21
            db    $21,$21,$11,$23,$21,$11,$21,$21,$21,$01,$21,$d6,$37,$85,$03,$22
            db    $42,$51,$ff

; ENDING - end credits (pulse 1 channel)
; CPU address $ac9f
sound_4a ENT
            db    $e8,$fd
            dw    sound_4a_part_00

sound_4a_part_01 ENT
            db    $e1,$47,$57,$fd
            dw    sound_4a_part_00

sound_4a_part_02 ENT
            db    $e1,$47,$5f,$ff

; CPU address $acad
sound_4a_part_03 ENT
            db    $d6,$f8,$31,$03,$e2,$77,$72,$e1,$22,$09,$02,$52,$49,$92,$b2,$e0
            db    $01,$e1,$77,$47,$97,$92,$72,$51,$47,$42,$22,$01,$e2,$7f,$27,$42
            db    $52,$71,$e2,$77,$72,$e1,$22,$09,$02,$52,$49,$92,$b2,$e0,$01,$e1
            db    $77,$47,$57,$52,$42,$21,$47,$42,$22,$01,$e2,$75,$70,$90,$77,$b0
            db    $e1,$00,$21,$00,$20,$41,$d6,$f8,$31,$03,$e1,$97,$79,$53,$41,$59
            db    $43,$21,$07,$02,$22,$41,$d6,$f9,$85,$08,$e1,$93,$73,$53,$43,$d6
            db    $f8,$31,$03,$9f,$77,$72,$52,$41,$57,$52,$72,$91,$ff

; ENDING - end credits (pulse 2 channel)
; CPU address $ad1a
sound_4b ENT
            db    $fd
            dw    sound_4a_part_03

sound_4b_part_00 ENT
            db    $77,$b7,$fd
            dw    sound_4a_part_03

; CPU address $ad22
sound_4b_part_01 ENT
            db    $77,$bf,$ff

; CPU address $ad25
sound_4b_part_02 ENT
            db    $d6,$7f,$e2,$05,$d6,$0e,$00,$00,$01,$01,$c1,$00,$00,$fe,$03
            dw    sound_4b_part_02

; CPU address $ad36
sound_4b_part_03 ENT
            db    $d6,$7f,$05,$d6,$0e,$00,$00,$41,$41,$c1,$41,$d6,$7f,$55,$d6,$0e
            db    $50,$50,$51,$51,$c1,$50,$50,$d6,$7f,$45,$d6,$0e,$40,$40,$41,$41
            db    $c1,$40,$40

; CPU address $ad59
sound_4b_part_04 ENT
            db    $d6,$7f,$75,$d6,$0e,$70,$70,$71,$71,$c1,$70,$70,$fe,$02
            dw    sound_4b_part_04

; CPU address $ad69
sound_4b_part_05 ENT
            db    $d6,$7f,$e2,$05,$d6,$0e,$00,$00,$01,$01,$c1,$00,$00,$fe,$03
            dw    sound_4b_part_05

; CPU address $ad7a
sound_4b_part_06 ENT
            db    $d6,$7f,$05,$d6,$0e,$00,$00,$41,$41,$c1,$41,$d6,$7f,$55,$d6,$0e
            db    $50,$50,$51,$51,$c1,$50,$50,$d6,$7f,$45,$d6,$0e,$40,$40,$41,$41
            db    $c1,$40,$40

; CPU address $ad9d
sound_4b_part_07 ENT
            db    $d6,$7f,$75,$d6,$0e,$70,$70,$71,$71,$c1,$70,$70,$fe,$02
            dw    sound_4b_part_07

sound_4b_part_08 ENT
            db    $d6,$7f,$e2,$05,$d6,$0e,$00,$00,$01,$01,$c1,$00,$00,$d6,$7f,$e3
            db    $b5,$d6,$0e,$b0,$b0,$b1,$b1,$c1,$b0,$b0,$d6,$7f,$a5,$d6,$0e,$a0
            db    $a0,$a1,$a1,$c1,$a0,$a0,$d6,$7f,$95,$d6,$0e,$90,$90,$91,$91,$c1
            db    $90,$90,$d6,$7f,$e2,$25,$d6,$0e,$20,$20,$21,$21,$c1,$20,$20,$d6
            db    $7f,$15,$d6,$0e,$10,$10,$11,$11,$c1,$10,$10,$d6,$7f,$25,$d6,$0e
            db    $20,$20,$21,$21,$c1,$20,$20,$ff

; ENDING - end credits (triangle channel)
; CPU address $ae05
sound_4c ENT
            db    $fd
            dw    sound_4b_part_02

sound_4c_part_00 ENT
            db    $d6,$7f,$e3,$b5,$d6,$0e,$b0,$b0,$e2,$71,$71,$c1,$71,$fd
            dw    sound_4b_part_02

sound_4c_part_01 ENT
            db    $d6,$90,$e3,$bf,$b7,$ff

; CPU address $ae1e
sound_4c_part_02 ENT
            db    $d6,$31,$01,$41,$00,$00,$31,$31,$41,$01,$fe,$03
            dw    sound_4c_part_02

sound_4c_part_03 ENT
            db    $31,$01,$41,$00,$00,$31,$41,$01,$40,$40

; CPU address $ae36
sound_4c_part_04 ENT
            db    $31,$01,$41,$00,$00,$31,$31,$41,$01,$fe,$03
            dw    sound_4c_part_04

; CPU address $ae43
sound_4c_part_05 ENT
            db    $31,$01,$41,$00,$00,$31,$31,$41,$41

; CPU address $ae4c
sound_4c_part_06 ENT
            db    $31,$01,$41,$00,$00,$31,$31,$41,$01,$fe,$03
            dw    sound_4c_part_06

sound_4c_part_07 ENT
            db    $31,$01,$41,$00,$00,$31,$31,$41,$40,$40

; CPU address $ae63
sound_4c_part_08 ENT
            db    $31,$01,$41,$00,$00,$31,$31,$41,$01,$fe,$03
            dw    sound_4c_part_08

; CPU address $ae70
sound_4c_part_09 ENT
            db    $31,$01,$41,$00,$00,$31,$31,$41,$41

; CPU address $ae79
sound_4c_part_0a ENT
            db    $31,$01,$01,$30,$30,$31,$31,$41,$01,$fe,$07
            dw    sound_4c_part_0a
            db    $ff

; ENDING - end credits (noise/dmc channel)
; CPU address $ae87
sound_4d ENT
            db    $fd
            dw    sound_4c_part_02

sound_4d_part_00 ENT
            db    $31,$01,$01,$30,$30,$41,$41,$31,$40,$40,$fd
            dw    sound_4c_part_02

sound_4d_part_01 ENT
            db    $33,$03,$33,$03,$c7,$ff

; end of sound code logic, beginning of sprite code logic

; writes encoded sprite data into memory address $0200-$02ff
; which is later the address set for OAMDMA for display
; for non-hud sprites this label loads #$19 #$4-byte entries per call (#$4c bytes total)
; when SPRITE_LOAD_TYPE is #01, then the sprites on top of the screen (medals, game over)
; CPU address $ae97
draw_sprites ENT
            lda OAMDMA_CPU_BUFFER_OFFSET    ; OAMDMA_CPU_BUFFER write offset
            clc    ; clear carry in preparation for addition
            adc #$4c    ; add #$4c to OAMDMA_CPU_BUFFER, this is to support "sprite cycling"/"sprite flickering"
; since the NES can draw a maximum of 8 sprites per scan line, Contra adjusts the starting locations
; so that sprites move around in PPU memory. This will allow different sprites to load each frame
; on the same scan line. Human eyes won't notice a sprite not visible for a single frame
            sta OAMDMA_CPU_BUFFER_OFFSET    ; OAMDMA_CPU_BUFFER write offset
            sta $04    ; store OAMDMA_CPU_BUFFER write offset to $04
            ldy #$3f    ; y = #$3f (maximum number of sprite pattern tiles that NES supports)
            sty $07    ; set maximum number of sprites in $07
            lda SPRITE_LOAD_TYPE    ; if 0, load regular sprites to cpu, else load hud sprites
            beq :load_sprites_to_cpu_mem    ; load sprites to cpu
            jsr draw_hud_sprites    ; draw hud sprites

:load_sprites_to_cpu_mem
            ldx #$19    ; up to #$19 sprites possible to load

; loops through the total number of possible sprites
:load_sprite_loop
            stx $05    ; store current sprite number offset into x
            lda CPU_SPRITE_BUFFER,x    ; load sprite offset into sprite_ptr_tbl
            beq :adv_sprite    ; move to next contra sprite if this current wasn't used
            ldy SPRITE_ATTR,x    ; load sprite attribute data
            sty $00    ; set $00 to hold SPRITE_ATTR
            ldy SPRITE_Y_POS,x    ; sprite Y position on screen
            sty $01    ; set $01 to hold base Y position of sprite (sprite tiles are positioned relative to this point)
            ldy SPRITE_X_POS,x    ; sprite X position on screen
            sty $02    ; set $02 to hold base X position of sprite (sprite tiles are positioned relative to this point)
            jsr load_sprite_to_cpu_mem    ; loads all the sprite pattern tiles to the OAMDMA buffer

:adv_sprite
            ldy $07    ; load number of sprite tiles available to draw
            bmi draw_sprites_exit    ; exit if the OAMDMA is full
            ldx $05    ; load the remaining number of contra sprites left to render (sprites, not tiles)
            dex    ; decrement total sprites remaining
            bpl :load_sprite_loop    ; if contra sprites left to drawn, loop to draw it
            ldx $04    ; load OAMDMA_CPU_BUFFER write offset

; take the remaining sprite tiles that are available in the OAMDMA and blank them
:fill_unused_OAM
            lda #$f4    ; hide any sprite whose byte 0 is $ef-$ff is not displayed
            sta OAMDMA_CPU_BUFFER,x    ; write Y position as #$f4 (hidden)
            jsr adv_OAMDMA_addr    ; add #$c4 to x (move to next sprite tile location)
            dey    ; decrement remaining sprite tiles counter
            bpl :fill_unused_OAM    ; loop to hide next sprite tile if haven't hidden all leftover tiles

draw_sprites_exit ENT
            rts

; write sprite data (OAM) to OAMDMA_CPU_BUFFER from CPU SPRITE buffer data
; if a >= #$80 offset is into sprite_ptr_tbl_1
; input
;  * a - sprite code, offset into sprite_ptr_tbl_0 or sprite_ptr_tbl_1
;  * $00 - sprite attribute
;  * $01 - sprite Y position on screen
;  * $02 - sprite X position
; output
;  * $04 - the next starting position of the OAMDMA_CPU_BUFFER write offset
;  * $07 - lowers the number of remaining sprite tiles that can be drawn by the
;          NES based on how many tiles were in the sprite drawn
load_sprite_to_cpu_mem ENT
            asl    ; double since each entry in sprite_ptr_tbl is 2 bytes
            tay
            bcs :load_sprite_tbl_1    ; offset is >= #$80, use second sprite table
            jsr   _R1_010    ; use first sprite table a < #$80
            sta $08    ; store low byte of sprite address into $08
            jsr   _R1_011    ; load high byte of sprite address into a
            jmp :continue_load_sprite    ; jump to store low byte and continue loading sprite

:load_sprite_tbl_1
            jsr   _R1_012    ; load low byte of sprite address
            sta $08    ; store low byte of sprite address into $08
            jsr   _R1_013    ; load high byte of sprite address

:continue_load_sprite
            sta $09    ; store high byte of sprite address into $09
            ldy #$00    ; y = #$00
            jsr   _I1_05    ; load number of tiles first byte from sprite
            beq draw_sprites_exit    ; if #$00, exit
            iny    ; increment sprite_xx read offset
            cmp #$fe    ; check if "small" sprite
            bne :load_regular_sprite
            jmp :load_small_sprite    ; handle #$fe

:load_regular_sprite
            sta $03    ; store number of pattern tiles in sprite into $03
            lda $00    ; load SPRITE_ATTR
            and #$c8    ; keep bits xx.. x..., keep horizontal and vertical flip bits
; bit 3 signals whether to add 1 to Y position for regular sprites (not small sprites)
            sta $0b    ; store in $0b, this is later used when rendering the sprite tile
; e.g. if the sprite tile within the sprite is defined as flipped vertically or horizontally,
; and the SPRITE_ATTR specifies flipping the entire sprite, then we have to 'flip the flip', i.e. change from a 1 to a 0
            lda $00    ; reload SPRITE_ATTR, looking to see if bit 2 is set
            lsr
            lsr
            lsr
            ldx #$fc    ; x = #$fc (1111 1100) used to strip palette from sprite code's sprite tile definition
            lda #$23    ; a = #$23 (0010 0011) used to keep palette and background priority from SPRITE_ATTR
            bcs :prep_sprite_attributes    ; branch if bit 2 of SPRITE_ATTR is 1
; this means bg priority and sprite palette will be from SPRITE_ATTR and not sprite code byte 2 definition
            ldx #$ff    ; x = #$ff (1111 1111) used to keep palette and flip bits from sprite code byte 2 definition
            lda #$20    ; a = #$20 (0010 0000) used to strip palette from SPRITE_ATTR and instead use sprite code byte 2 definition

:prep_sprite_attributes
            and $00    ; keep/strip the sprite palette and bg priority from SPRITE_ATTR depending on bit 2 of SPRITE_ATTR
            sta $00    ; update $00 with new value
            stx $0d    ; store palette and flip bits from sprite code byte 2 definition if not overwritten by SPRITE_ATTR
            ldx $04    ; load OAMDMA_CPU_BUFFER write offset

:write_sprite_tile
            jsr   _I1_05    ; load first byte of sprite (Y position), or #$80 for shared sprite
            cmp #$80    ; see if using shared sprite
            bne :continue    ; not using shared sprite, continue like normal
; using shared sprite, need to update cpu read address
            lda $0b    ; load sprite effect
            and #$f7    ; strip bit 3 to prevent adding #$01 to Y position
            sta $0b    ; save sprite effect
            iny    ; increment sprite_xx read offset
            jsr   _I1_05    ; load low byte of new sprite read address
            sta $06    ; store low byte into $06
            iny    ; increment sprite_xx read offset
            jsr   _I1_05    ; load high byte of new sprite read address
            sta $09    ; replace existing read high byte in $09 with new address
            lda $06    ; load low byte
            sta $08    ; replace existing read low byte in $08 with new address
            ldy #$00    ; clear sprite_xx read offset since starting at new address

:continue
            jsr   _I1_05    ; read sprite relative Y position (Byte 0)
            sta $0c    ; store sprite tile relative Y offset
            lda $0b
            asl    ; shift sprite effect left
            and #$10    ; keep bits ...x ....
            beq :prep_y_position    ; see if bit 3 of SPRITE_ATTR is set
            inc $0c    ; bit 3 was set, add #$01 to relative Y position
; used for creating recoil effect when firing gun

:prep_y_position
            lda $0c    ; load sprite tile relative offset
            bcc :write_sprite_tile_data    ; branch bit 7 of $0b is 0
            sta $0c    ; store sprite tile relative Y offset
            lda #$f0    ; a = #$f0
            sbc $0c    ; #$f0 minus sprite tile relative Y offset
            clc

:write_sprite_tile_data
            adc $01    ; add SPRITE_Y_POS to sprite Y offset (sets tile's absolute position)
            sta OAMDMA_CPU_BUFFER,x    ; write Y position to CPU buffer
            iny    ; increment sprite_xx read offset
            jsr   _I1_05    ; read 2nd byte, which specifies pattern table tile (Byte 1)
            sta OAMDMA_CPU_BUFFER+1,x    ; write pattern tile number to CPU buffer
            iny    ; increment sprite data read offset
            jsr   _I1_05    ; read 3rd byte (sprite tile attributes) (Byte 2)
            and $0d    ; keep/strip sprite palette from sprite tile byte 2, based on bit 2 of SPRITE_ATTR
            ora $00    ; merge sprite code tile byte 2 with attribute data from SPRITE_ATTR
            eor $0b    ; exclusive or to handle flipping a flipped sprite tile, e.g. flip + flip = no flip
            sta OAMDMA_CPU_BUFFER+2,x    ; write sprite attributes to CPU buffer
            iny    ; increment sprite_xx read offset
            lda $0b
            asl
            asl
            jsr   _I1_05    ; read next byte of sprite_xx
            bcc :continue2    ; branch if no horizontal flip
            sta $0c    ; horizontal flip, store X position
            lda #$f8    ; a = #$f8
            sbc $0c
            clc

:continue2
            bmi :set_sprite_tile_x_adv_addr
            adc $02    ; add to sprite X position
            bcs :move_next_sprite_tile    ; increment read offset, set next write offset, decrement total sprite tiles

:set_x_adv_addr
            jsr set_x_adv_OAMDMA_addr    ; set sprite tile X position (a) in OAMDMA and advance OAMDMA write address

:move_next_sprite_tile
            iny    ; increment sprite_xx read offset
            dec $03    ; decrement remaining sprite tiles in sprite that is being drawn
            bne :write_sprite_tile    ; move to the next tile in the sprite to move into OAMDMA
            stx $04    ; write next OAMDMA write offset to $04
            rts

; set sprite tile's relative X position, and set next OAMDMA write address
; input
;  a - the X offset of the sprite tile from the SPRITE_X_POS
:set_sprite_tile_x_adv_addr
            adc $02    ; add to sprite x base position
            bcs :set_x_adv_addr    ; set sprite tile X position (a) in OAMDMA and advance OAMDMA write address
            bcc :move_next_sprite_tile    ; increment read offset, set next write offset, decrement total sprite tiles

; sprite code is made of a single #$03-byte entry (including #$fe)
; the second byte is the pattern table tile, and the third byte is the sprite attributes
; the X position is set to #$fc (-4 decimal) and the Y position is set to #$f8 (-8 decimal) from SPRITE_Y_POS.
:load_small_sprite
            ldx $04    ; load OAM write offset
            lda #$f8    ; a = -#$08
            clc    ; clear carry in preparation for addition
            adc $01    ; subtract #$08 from Y position
            sta OAMDMA_CPU_BUFFER,x    ; set Y position of small sprite
            jsr   _I1_05    ; load pattern tile of sprite
            sta OAMDMA_CPU_BUFFER+1,x    ; set pattern tile of small sprite
            iny    ; increment sprite_xx read offset
            jsr   _I1_05    ; load SPRITE_ATTR
            ora $00    ; merge with $00
            sta OAMDMA_CPU_BUFFER+2,x    ; store SPRITE_ATTR of small sprite
            lda $02    ; load sprite's base X position
            sec    ; set carry flag in preparation for subtraction
            sbc #$04    ; subtract #$04
            bcc :exit    ; exit if overflow
            jsr set_x_adv_OAMDMA_addr    ; set sprite tile X position (a) in OAMDMA and advance OAMDMA write address
            stx $04    ; store next OAMDMA write address in $04

:exit
            iny    ; increment sprite_xx read offset
            rts

; places the "heads up display" (HUD) sprites in the correct locations in memory $0200-$02ff
; so they are on the screen when written by OAMDMA
draw_hud_sprites ENT
            lda PLAYER_MODE    ; #$00 single player, #$01 for 2nd player
            ldy DEMO_MODE    ; #$00 not in demo mode, #$01 demo mode on
            beq :continue
            lda #$01    ; start with player 2 when not in demo mode

:continue
            sta $00    ; store current player number (used for HUD sprite palette)
            ldx $04

draw_player_hud_sprites ENT
            ldy #$04    ; y = #$04
            lda DEMO_MODE    ; #$00 not in demo mode, #$01 demo mode on
            bne :four_sprites    ; demo mode always shows GAME OVER
            ldy $00    ; load current player
            jsr   _Z1_00    ; player y game over state (1 = game over)
            ldy #$04    ; set hud_sprites base offset to show GAME OVER
            lsr
            bcs :four_sprites    ; branch if in game over
            ldy $00    ; not in game over, load number of lives remaining for current player
            jsr   _Z1_01    ; player y lives
            ldy #$00    ; set hud_sprites base offset to show medals
            cmp #$04
            bcc :draw_sprites    ; if less than #$04 lives, show that number of medals

:four_sprites
            lda #$04    ; show 4 medals on player HUD

:draw_sprites
            sta $01    ; store number of medals to draw in $01

:draw_p_sprite
            dec $01    ; decrement number of medals to draw
            bmi :move_to_next_player    ; if done drawing all sprites, move to next player
            lda #$18    ; a = #$18 (IIgs: was #$10, moved down 8 to fit the viewport)
            sta OAMDMA_CPU_BUFFER,x    ; set Y position of medal/game over hud sprite to #$18
            jsr   _R1_014    ; load HUD sprite (either medal, or game over text)
            sta OAMDMA_CPU_BUFFER+1,x    ; write tile number to OAM
            lda $00
            sta OAMDMA_CPU_BUFFER+2,x    ; write the tile attributes (blue palette for p1, red palette for p2)
            lsr    ; set carry flag if on player 2
            jsr   _R1_015    ; load X offset based on sprite number
            bcc :continue
            adc #$af    ; add #$af to sprite X offset if on player 2 (see previous lsr)

:continue
            jsr set_x_adv_OAMDMA_addr    ; set sprite tile X position (a) in OAMDMA and advance OAMDMA write address
            iny    ; increment medal sprite number (#$00 to #$04)
            jmp :draw_p_sprite

:move_to_next_player
            dec $00    ; decrement player number
            bpl draw_player_hud_sprites    ; load player 1 HUD if we were on player 2
            stx $04
            rts

; table for hud sprites, references pattern table tiles (#$10 bytes)
; medals for number of lives or
; GAME
; OVER
hud_sprites ENT
            db    $0a,$0a,$0a,$0a    ; medals
            db    $02,$04,$06,$08    ; game over text

sprite_medal_x_offset ENT
            db    $10,$1c,$28,$34
            db    $10,$1c,$28,$34

; set sprite tile X position (a) in OAMDMA and advance OAMDMA write address
set_x_adv_OAMDMA_addr ENT
            sta OAMDMA_CPU_BUFFER+3,x    ; set X position of sprite
            dec $07    ; decrement number of remaining sprite tiles that NES can draw

; adds #$c4 to x for next write location of OAMDMA sprite data
; input
;  * x - OAMDMA_CPU_BUFFER write offset
adv_OAMDMA_addr ENT
            txa    ; move current write offset to a
            clc    ; clear carry in preparation for addition
            adc #$c4    ; add #$c4 to current write offset
            tax    ; move new offset back to x
            rts

; enormous pointer table for sprites (#$cf * #$02 = #$19e bytes)
sprite_ptr_tbl_0 ENT
            dw    sprite_01    ; CPU address $b1ce - blank
            dw    sprite_02    ; CPU address $b1cf - player walking (frame 1)
            dw    sprite_03    ; CPU address $b1e4 - player walking (frame 2)
            dw    sprite_04    ; CPU address $b1f9 - player walking (frame 3)
            dw    sprite_05    ; CPU address $b20e - player walking (frame 4)
            dw    sprite_06    ; CPU address $b21a - player walking (frame 5)
            dw    sprite_07    ; CPU address $b226 - enemy bullet (snow field)
            dw    sprite_08    ; CPU address $b229 - player curled up (frame 1)
            dw    sprite_09    ; CPU address $b23a - player curled up (frame 2)
            dw    sprite_0a    ; CPU address $b247 - player hit (frame 1)
            dw    sprite_0b    ; CPU address $b258 - player hit (frame 2)
            dw    sprite_0c    ; CPU address $b269 - player lying on ground
            dw    sprite_0d    ; CPU address $b27a - player walking holding weapon out (frame 1)
            dw    sprite_0e    ; CPU address $b28a - player walking holding weapon out (frame 2)
            dw    sprite_0f    ; CPU address $b29a - player walking holding weapon out (frame 3)
            dw    sprite_10    ; CPU address $b2aa - player aiming angled up (frame 1)
            dw    sprite_11    ; CPU address $b2b6 - player aiming angled up (frame 2)
            dw    sprite_12    ; CPU address $b2c2 - player aiming angled up (frame 3)
            dw    sprite_13    ; CPU address $b2ce - player aiming angled down (frame 1)
            dw    sprite_14    ; CPU address $b2de - player aiming angled down (frame 2)
            dw    sprite_15    ; CPU address $b2ee - player aiming angled down (frame 3)
            dw    sprite_16    ; CPU address $b2fe - player aiming straight up
            dw    sprite_17    ; CPU address $b30e - player prone
            dw    sprite_18    ; CPU address $b31f - water splash/puddle (shown after sprite_73)
            dw    sprite_19    ; CPU address $b328 - player in water
            dw    sprite_1a    ; CPU address $b331 - player climbing out of water
            dw    sprite_1b    ; CPU address $b33a - player in water aiming straight up
            dw    sprite_1c    ; CPU address $b34a - player in water aiming angled up
            dw    sprite_1d    ; CPU address $b356 - player in water aiming forward
            dw    sprite_1e    ; CPU address $b366 - default bullet
            dw    sprite_1f    ; CPU address $b369 - M bullet
            dw    sprite_20    ; CPU address $b36c - S bullet, mortar
            dw    sprite_21    ; CPU address $b36f - boss turret bullet
            dw    sprite_22    ; CPU address $b372 - F bullet and snow field level boss ufo bomb
            dw    sprite_23    ; CPU address $b375 - L bullet (up)
            dw    sprite_24    ; CPU address $b378 - L bullet
            dw    sprite_25    ; CPU address $b381 - L bullet (angled)
            dw    sprite_26    ; CPU address $b384 - soldier crouched shooting
            dw    sprite_27    ; CPU address $b395 - soldier running 1
            dw    sprite_28    ; CPU address $b3a6 - soldier running 2
            dw    sprite_29    ; CPU address $b3b2 - soldier shooting angled up
            dw    sprite_2a    ; CPU address $b3c3 - hangar mine cart (frame 1)
            dw    sprite_2b    ; CPU address $b3dc - hangar mine cart (frame 2)
            dw    sprite_2c    ; CPU address $b3e8 - soldier shooting
            dw    sprite_2d    ; CPU address $b3fd - soldier shooting angled down
            dw    sprite_2e    ; CPU address $b412 - unknown (doesn't seem to be used)
            dw    sprite_2f    ; CPU address $b423 - S weapon item
            dw    sprite_30    ; CPU address $b430 - B weapon item
            dw    sprite_31    ; CPU address $b438 - F weapon item
            dw    sprite_32    ; CPU address $b440 - L weapon item
            dw    sprite_33    ; CPU address $b448 - R weapon item
            dw    sprite_34    ; CPU address $b450 - M weapon item
            dw    sprite_35    ; CPU address $b458 - big explosion
            dw    sprite_36    ; CPU address $b479 - explosion
            dw    sprite_37    ; CPU address $b48e - small explosion
            dw    sprite_38    ; CPU address $b497 - round explosion
            dw    sprite_39    ; CPU address $b4b0 - thick explosion ring
            dw    sprite_3a    ; CPU address $b4d1 - wide explosion ring
            dw    sprite_3b    ; CPU address $b4f2 - soldier running
            dw    sprite_3c    ; CPU address $b503 - soldier running
            dw    sprite_3d    ; CPU address $b514 - soldier running
            dw    sprite_3e    ; CPU address $b525 - soldier running
            dw    sprite_3f    ; CPU address $b531 - soldier running
            dw    sprite_40    ; CPU address $b53d - soldier shooting
            dw    sprite_41    ; CPU address $b54d - soldier shooting downward
            dw    sprite_42    ; CPU address $b562 - soldier shooting up angled
            dw    sprite_43    ; CPU address $b572 - rifle man shooting
            dw    sprite_44    ; CPU address $b582 - rifle man behind bush (frame 1)
            dw    sprite_45    ; CPU address $b587 - rifle man behind bush (frame 2)
            dw    sprite_46    ; CPU address $b594 - rifle man behind bush (frame 3)
            dw    sprite_47    ; CPU address $b598 - small ring explosion
            dw    sprite_48    ; CPU address $b59b - floating rock (waterfall level)
            dw    sprite_49    ; CPU address $b5b8 - bridge fire (waterfall level)
            dw    sprite_4a    ; CPU address $b5c1 - boulder (waterfall level)
            dw    sprite_4b    ; CPU address $b5da - scuba soldier hiding
            dw    sprite_4c    ; CPU address $b5e3 - scuba soldier out of water shooting up
            dw    sprite_4d    ; CPU address $b5f0 - weapon zeppelin
            dw    sprite_4e    ; CPU address $b5fd - flashing falcon weapon
            dw    sprite_4f    ; CPU address $b605 - unused blank sprite
            dw    sprite_50    ; CPU address $b606 - indoor player facing up
            dw    sprite_51    ; CPU address $b623 - indoor player strafing (frame 1)
            dw    sprite_52    ; CPU address $b633 - indoor player strafing (frame 2)
            dw    sprite_53    ; CPU address $b643 - indoor player strafing (frame 3)
            dw    sprite_54    ; CPU address $b653 - indoor player crouch
            dw    sprite_55    ; CPU address $b670 - indoor player electrocuted
            dw    sprite_56    ; CPU address $b691 - indoor player lying dead
            dw    sprite_57    ; CPU address $b6b2 - indoor player running
            dw    sprite_58    ; CPU address $b6cb - indoor player running
            dw    sprite_59    ; CPU address $b6e4 - unused blank sprite
            dw    sprite_59    ; CPU address $b6e4 - unused blank sprite
            dw    sprite_59    ; CPU address $b6e4 - unused blank sprite
            dw    sprite_59    ; CPU address $b6e4 - unused blank sprite
            dw    sprite_5d    ; CPU address $b6e5 - boss eye
            dw    sprite_5e    ; CPU address $b706 - boss eye
            dw    sprite_5f    ; CPU address $b71a - boss eye
            dw    sprite_60    ; CPU address $b72e - boss eye
            dw    sprite_61    ; CPU address $b742 - boss eye
            dw    sprite_62    ; CPU address $b74e - boss eye
            dw    sprite_63    ; CPU address $b756 - small boss eye projectile (unused)
            dw    sprite_64    ; CPU address $b75f - boss eye projectile
            dw    sprite_65    ; CPU address $b780 - unused blank sprite
            dw    sprite_65    ; CPU address $b780 - unused blank sprite
            dw    sprite_65    ; CPU address $b780 - unused blank sprite
            dw    sprite_68    ; CPU address $b781 - base 2 boss metal helmet (Godomuga) (frame 1)
            dw    sprite_69    ; CPU address $b7a2 - base 2 boss metal helmet (Godomuga) (frame 2)
            dw    sprite_6a    ; CPU address $b7be - base 2 boss metal helmet (Godomuga) (frame 3)
            dw    sprite_6b    ; CPU address $b7d2 - base 2 boss metal helmet (Godomuga) (frame 4)
            dw    sprite_6c    ; CPU address $b7de - base 2 boss metal helmet (Godomuga) (frame 5)
            dw    sprite_6d    ; CPU address $b7ea - base 2 boss metal helmet (Godomuga) bubble projectile
            dw    sprite_6e    ; CPU address $b7f3 - base 2 boss metal helmet (Godomuga) bubble projectile
            dw    sprite_6f    ; CPU address $b7fc - base 2 boss metal helmet (Godomuga) bubble projectile
            dw    sprite_70    ; CPU address $b7ff - base 2 boss metal helmet (Godomuga) bubble projectile
            dw    sprite_71    ; CPU address $b808 - base 2 boss metal helmet (Godomuga) bubble projectile
            dw    sprite_72    ; CPU address $b811 - base 2 boss metal helmet (Godomuga) bubble projectile
            dw    sprite_73    ; CPU address $b814 - water splash
            dw    sprite_74    ; CPU address $b81d - ice grenade
            dw    sprite_75    ; CPU address $b826 - ice grenade
            dw    sprite_76    ; CPU address $b82f - ice grenade
            dw    sprite_77    ; CPU address $b838 - ice grenade (vertical)
            dw    sprite_78    ; CPU address $b841 - !(UNUSED) duplicate of sprite_74 (ice grenade lean right), unused in game
            dw    sprite_79    ; CPU address $b84a - dragon boss projectile
            dw    sprite_7a    ; CPU address $b853 - dragon arm interior orb (gray)
            dw    sprite_7b    ; CPU address $b85c - dragon arm hand orb (red)
            dw    sprite_7c    ; CPU address $b865 - snow field boss mini UFO
            dw    sprite_7d    ; CPU address $b872 - snow field boss mini UFO
            dw    sprite_7e    ; CPU address $b87f - snow field boss mini UFO
            dw    sprite_7f    ; CPU address $b88c - unknown (doesn't seem to be used)

sprite_ptr_tbl_1 ENT
            dw    sprite_80    ; (offset #$00) CPU address $b88c - unknown (doesn't seem to be used)
            dw    sprite_81    ; (offset #$01) CPU address $b895 - unknown (doesn't seem to be used)
            dw    sprite_82    ; (offset #$02) CPU address $b89e - L bullet indoor level
            dw    sprite_83    ; (offset #$03) CPU address $b8a3 - L bullet indoor level
            dw    sprite_84    ; (offset #$04) CPU address $b8a8 - L bullet indoor level
            dw    sprite_85    ; (offset #$05) CPU address $b8ad - base boss level 4 blue soldier
            dw    sprite_86    ; (offset #$06) CPU address $b8c2 - base boss level 4 blue soldier
            dw    sprite_87    ; (offset #$07) CPU address $b8d3 - base boss level 4 blue soldier
            dw    sprite_88    ; (offset #$08) CPU address $b8e0 - base boss level 4 blue soldier facing out (frame 1)
            dw    sprite_89    ; (offset #$09) CPU address $b8f1 - base boss level 4 blue soldier facing out (frame 2)
            dw    sprite_8a    ; (offset #$0a) CPU address $b902 - base boss level 4 blue soldier flying (frame 1)
            dw    sprite_8b    ; (offset #$0b) CPU address $b917 - base boss level 4 blue soldier flying (frame 2)
            dw    sprite_8c    ; (offset #$0c) CPU address $b934 - base boss level 4 base 2 red soldier
            dw    sprite_8d    ; (offset #$0d) CPU address $b93c - base boss level 4 base 2 red soldier
            dw    sprite_8e    ; (offset #$0e) CPU address $b944 - base boss level 4 base 2 red soldier
            dw    sprite_8f    ; (offset #$0f) CPU address $b94c - base boss level 4 base 2 red soldier facing player
; Probotector uses sprite_88 rather than separately defining a sprite_8f
            dw    sprite_90    ; (offset #$10) CPU address $b954 - base boss level 4 base 2 red soldier facing player with weapon
            dw    sprite_91    ; (offset #$11) CPU address $b965 - indoor boss defeated elevator with player on top
            dw    sprite_92    ; (offset #$12) CPU address $b975 - L bullet indoor level
            dw    sprite_93    ; (offset #$13) CPU address $b97a - jumping man
            dw    sprite_94    ; (offset #$14) CPU address $b98b - jumping man
            dw    sprite_95    ; (offset #$15) CPU address $b99c - jumping man
            dw    sprite_96    ; (offset #$16) CPU address $b9ad - indoor soldier hit by bullet (indoor soldier, jumping man, grenade launcher, group of four soldiers)
            dw    sprite_97    ; (offset #$17) CPU address $b9be - jumping man in air
            dw    sprite_98    ; (offset #$18) CPU address $b9d3 - jumping man facing player
            dw    sprite_99    ; (offset #$19) CPU address $b9e0 - small indoor rolling grenade
            dw    sprite_9a    ; (offset #$1a) CPU address $b9e9 - closer indoor rolling grenade
            dw    sprite_9b    ; (offset #$1b) CPU address $b9f2 - even closer indoor rolling grenade
            dw    sprite_9c    ; (offset #$1c) CPU address $b9ff - closest indoor rolling grenade
            dw    sprite_9d    ; (offset #$1d) CPU address $ba0c - indoor base enemy kill explosion (frame 1)
            dw    sprite_9e    ; (offset #$1e) CPU address $ba0f - indoor base enemy kill explosion (frame 2)
            dw    sprite_9f    ; (offset #$1f) CPU address $ba18 - indoor base enemy kill explosion (frame 3)
            dw    sprite_a0    ; (offset #$20) CPU address $ba21 - indoor hand grenade
            dw    sprite_a1    ; (offset #$21) CPU address $ba2a - indoor hand grenade
            dw    sprite_a2    ; (offset #$22) CPU address $ba2f - indoor hand grenade
            dw    sprite_a3    ; (offset #$23) CPU address $ba32 - indoor hand grenade
            dw    sprite_a4    ; (offset #$24) CPU address $ba37 - indoor hand grenade
            dw    sprite_a5    ; (offset #$25) CPU address $ba3c - indoor hand grenade
            dw    sprite_a6    ; (offset #$26) CPU address $ba41 - indoor hand grenade
            dw    sprite_a7    ; (offset #$27) CPU address $ba44 - indoor hand grenade
            dw    sprite_a8    ; (offset #$28) CPU address $ba49 - indoor hand grenade
            dw    sprite_a9    ; (offset #$29) CPU address $ba4c - indoor hand grenade
            dw    sprite_aa    ; (offset #$2a) CPU address $ba50 - falcon (player select icon)
            dw    sprite_ab    ; (offset #$2b) CPU address $ba59 - Bill and Lance's hair and shirt (for Probotector - red splash behind Probotector title)
            dw    sprite_ac    ; (offset #$2c) CPU address $bab2 - alien's lair bundle (crustacean-like alien)
            dw    sprite_ad    ; (offset #$2d) CPU address $bacb - alien's lair bundle (crustacean-like alien) mouth open
            dw    sprite_ae    ; (offset #$2e) CPU address $bad7 - alien's lair bundle (crustacean-like alien)
            dw    sprite_af    ; (offset #$2f) CPU address $baf0 - alien's lair bundle (crustacean-like alien)
            dw    sprite_b0    ; (offset #$30) CPU address $bafc - poisonous insect gel
            dw    sprite_b1    ; (offset #$31) CPU address $bb05 - poisonous insect gel (frame 1)
            dw    sprite_b2    ; (offset #$32) CPU address $bb0e - poisonous insect gel (frame 2)
            dw    sprite_b3    ; (offset #$33) CPU address $bb17 - boss alien bugger insect/spider (frame 1)
            dw    sprite_b4    ; (offset #$34) CPU address $bb30 - boss alien bugger insect/spider (frame 2)
            dw    sprite_b5    ; (offset #$35) CPU address $bb51 - boss alien bugger insect/spider (frame 3)
            dw    sprite_b6    ; (offset #$36) CPU address $bb6e - boss alien eggron (alien egg)
            dw    sprite_b7    ; (offset #$37) CPU address $bb77 - energy zone boss giant armored soldier gordea
            dw    sprite_b7    ; (offset #$38) CPU address $bb77 - energy zone boss giant armored soldier gordea (sprite_b8)
            dw    sprite_b9    ; (offset #$39) CPU address $bbd0 - energy zone boss giant armored soldier gordea (legs together)
            dw    sprite_ba    ; (offset #$3a) CPU address $bc19 - energy zone boss giant armored soldier gordea (running, jumping)
            dw    sprite_bb    ; (offset #$3b) CPU address $bc45 - energy zone boss projectile (spiked disk)
            dw    sprite_bc    ; (offset #$3c) CPU address $bc4e - energy zone boss projectile (spiked disk)
            dw    sprite_bd    ; (offset #$3d) CPU address $bc57 - turret man (basquez)
            dw    sprite_be    ; (offset #$3e) CPU address $bc74 - turret man (basquez)
            dw    sprite_bf    ; (offset #$3f) CPU address $bc91 - energy zone wall fire
            dw    sprite_c0    ; (offset #$40) CPU address $bc96 - energy zone wall fire
            dw    sprite_c1    ; (offset #$41) CPU address $bc9b - energy zone ceiling fire
            dw    sprite_c2    ; (offset #$42) CPU address $bca0 - energy zone ceiling fire
            dw    sprite_c3    ; (offset #$43) CPU address $bca5 - energy zone boss giant armored soldier gordea (throwing)
            dw    sprite_c4    ; (offset #$44) CPU address $bccd - snow field ground separator
            dw    sprite_c5    ; (offset #$45) CPU address $bcd2 - green helicopter ending scene (frame 1)
            dw    sprite_c6    ; (offset #$46) CPU address $bcdb - green helicopter ending scene (frame 2)
            dw    sprite_c7    ; (offset #$47) CPU address $bce8 - green helicopter ending scene (frame 3)
            dw    sprite_c8    ; (offset #$48) CPU address $bcf1 - green helicopter ending scene (frame 4)
            dw    sprite_c9    ; (offset #$49) CPU address $bcfe - green helicopter facing forward (frame 1)
            dw    sprite_ca    ; (offset #$4a) CPU address $bd13 - green helicopter facing forward (frame 2)
            dw    sprite_cb    ; (offset #$4b) CPU address $bd30 - green helicopter facing forward (frame 3)
            dw    sprite_cc    ; (offset #$4c) CPU address $bd59 - green helicopter facing forward (frame 4)
            dw    sprite_cd    ; (offset #$4d) CPU address $bd7e - green helicopter facing forward (frame 5)
            dw    sprite_ce    ; (offset #$4e) CPU address $bdab - green helicopter facing forward (frame 6)
            dw    sprite_cf    ; (offset #$4f) CPU address $bdd0 - ending sequence mountains

; each sprite entry is defined as follows
; first byte (n) is number of tiles for sprite
; followed by n 4-byte groups
; each 4-byte group defines a block that is 2 tiles tall (8x16 pixels)
; * byte 0: Y position in pixels (relative to sprite base position (SPRITE_Y_POS), can be negative)
; * byte 1: pattern table tile index/code
;   * if even, tile is pulled from 0x0000 (sprite section) (left pattern table)
;   * if odd, tile is pulled from 0x1000 (background section) (right pattern table)
;   * one byte is for both tiles (8x16)
;     * 1st tile is byte specified
;     * 2nd tile is (byte + 1), i.e. the tile immediately after the one specified
; * byte 2: palette code, flipping, drawing priority (foreground or background)
;     * x... .... - Vertical flip
;     * .x.. .... - Horizontal flip
;     * ..x. .... - Drawing priority (whether to draw behind background or not)
;     * .... ..xx - Palette code
; * byte 3: X position in pixels (relative to sprite position (SPRITE_X_POS), can be negative)

; EXCEPTIONS
; if first byte of sprite sequence is #$fe (e.g. sprite_07), then the sprite is considered a "small sprite"
; in this case, the sprite is made of a single entry. The entire byte sequence is 3 bytes long (including #$fe)
; the second byte is the pattern table tile, and the third byte is the sprite attributes
; the X position is set to #$fc (-4 decimal) and the Y position is set to #$f8 (-8 decimal).

; if the first byte of a group sequence is #$80 (shared sprite), then the next two bytes are a CPU address to continue reading at.
; this address is then read to get the sprite CPU read address.
; this allows sprites to share parts of each other

; blank
sprite_01 ENT
            db    $00

; player walking (frame 1)
sprite_02 ENT
            db    $05
            db    $ee,$28,$01,$fb
            db    $ee,$2a,$01,$03

; no sprite code, only part of other sprite codes
player_walking_1_bottom ENT
            db    $fe,$34,$00,$f8
            db    $fe,$36,$00,$00
            db    $0e,$40,$00,$f8

; player walking (frame 2)
sprite_03 ENT
            db    $05
            db    $ef,$2c,$01,$fc
            db    $ef,$2e,$01,$04

; no sprite code, only part of other sprite codes
player_walking_2_bottom ENT
            db    $fd,$38,$00,$f8
            db    $fd,$3a,$00,$00
            db    $0d,$42,$00,$04

; player walking (frame 3)
sprite_04 ENT
            db    $05
            db    $ee,$30,$01,$fa
            db    $ee,$32,$01,$02

; no sprite code, only part of other sprite codes
player_bottom ENT
            db    $fe,$3c,$00,$f7
            db    $fe,$3e,$00,$ff
            db    $0e,$42,$00,$fe

; player walking (frame 4)
; player falling through floor, or walk off ledge
sprite_05 ENT
            db    $05
            db    $ee,$30,$01,$fa
            db    $ee,$32,$01,$02
            db    $80
            dw    player_walking_1_bottom

; player walking (frame 5)
sprite_06 ENT
            db    $05
            db    $ee,$28,$01,$fb
            db    $ee,$2a,$01,$03
            db    $80
            dw    player_bottom

; enemy bullet (snow field)
sprite_07 ENT
            db    $fe,$ec,$02

; player curled up (frame 1)
sprite_08 ENT
            db    $04
            db    $f2,$44,$01,$f8
            db    $f2,$48,$01,$00
            db    $02,$46,$00,$f8
            db    $02,$4a,$00,$00

; player curled up (frame 2)
sprite_09 ENT
            db    $03
            db    $f8,$4c,$00,$f6
            db    $f8,$4e,$01,$fe
            db    $f8,$50,$01,$06

; player hit (frame 1)
sprite_0a ENT
            db    $04
            db    $f3,$68,$01,$f6
            db    $03,$6a,$00,$f6
            db    $f7,$6c,$00,$fe
            db    $f7,$6e,$00,$06

; player hit (frame 2)
sprite_0b ENT
            db    $04
            db    $f9,$70,$00,$f8
            db    $fa,$74,$00,$ff
            db    $ea,$72,$00,$fc
            db    $ff,$76,$01,$fa

; player lying on ground
sprite_0c ENT
            db    $04
            db    $00,$78,$01,$f0
            db    $00,$7a,$01,$f8
            db    $00,$7c,$00,$00
            db    $00,$7e,$00,$08

; player walking holding weapon out (frame 1)
sprite_0d ENT
            db    $06
            db    $ee,$94,$01,$f9
            db    $ee,$96,$01,$01
            db    $ee,$98,$01,$09
            db    $80
            dw    player_walking_1_bottom

; player walking holding weapon out (frame 2)
sprite_0e ENT
            db    $06
            db    $ef,$94,$01,$f9
            db    $ef,$96,$01,$01
            db    $ef,$98,$01,$09
            db    $80
            dw    player_walking_2_bottom

; player walking holding weapon out (frame 3)
sprite_0f ENT
            db    $06

player_facing_side ENT
            db    $ee,$94,$01,$f9
            db    $ee,$96,$01,$01
            db    $ee,$98,$01,$09
            db    $80
            dw    player_bottom

; player aiming angled up (frame 1)
sprite_10 ENT
            db    $05
            db    $ee,$8c,$01,$fb
            db    $ee,$8e,$01,$03
            db    $80
            dw    player_walking_1_bottom

; player aiming angled up (frame 2)
sprite_11 ENT
            db    $05
            db    $ef,$8c,$01,$fb
            db    $ef,$8e,$01,$03
            db    $80
            dw    player_walking_2_bottom

; player aiming angled up (frame 3)
sprite_12 ENT
            db    $05
            db    $ee,$8c,$01,$fb
            db    $ee,$8e,$01,$03
            db    $80
            dw    player_bottom

; player aiming angled down (frame 1)
sprite_13 ENT
            db    $06
            db    $ee,$86,$01,$f8
            db    $ee,$88,$01,$00
            db    $f3,$8a,$01,$05
            db    $80
            dw    player_walking_1_bottom

; player aiming angled down (frame 2)
sprite_14 ENT
            db    $06
            db    $ef,$86,$01,$f8
            db    $ef,$88,$01,$00
            db    $f4,$8a,$01,$05
            db    $80
            dw    player_walking_2_bottom

; player aiming angled down (frame 3)
sprite_15 ENT
            db    $06
            db    $ee,$86,$01,$f8
            db    $ee,$88,$01,$00
            db    $f3,$8a,$01,$05
            db    $80
            dw    player_bottom

; player aiming straight up
sprite_16 ENT
            db    $06
            db    $de,$82,$01,$01
            db    $ee,$80,$01,$f9
            db    $ee,$84,$01,$01
            db    $80
            dw    player_bottom

; player prone
sprite_17 ENT
            db    $04
            db    $00,$9c,$00,$f0
            db    $00,$9e,$00,$f8
            db    $00,$a0,$01,$00
            db    $00,$a2,$01,$08

; water splash/puddle
sprite_18 ENT
            db    $02

water_splash ENT
            db    $fa,$dc,$01,$f8
            db    $fa,$dc,$41,$00

; player in water
sprite_19 ENT
            db    $02
            db    $f2,$de,$01,$f8
            db    $f2,$e0,$01,$00

; player climbing out of water
sprite_1a ENT
            db    $02
            db    $fa,$e2,$01,$f8
            db    $fa,$e4,$01,$00

; player in water aiming straight up
sprite_1b ENT
            db    $05
            db    $df,$82,$01,$01
            db    $ef,$80,$01,$f9
            db    $ef,$84,$01,$01
            db    $80
            dw    water_splash

; player in water aiming angled up
sprite_1c ENT
            db    $04
            db    $ef,$8c,$01,$fb
            db    $ef,$8e,$01,$03
            db    $80
            dw    water_splash

; player in water aiming forward
sprite_1d ENT
            db    $05
            db    $ef,$94,$01,$f9
            db    $ef,$96,$01,$01
            db    $ef,$98,$01,$09
            db    $80
            dw    water_splash

; default bullet
sprite_1e ENT
            db    $fe,$0e,$02

; M bullet
sprite_1f ENT
            db    $fe,$10,$02

; S bullet, mortar
sprite_20 ENT
            db    $fe,$12,$02

; boss turret bullet
sprite_21 ENT
            db    $fe,$14,$02

; F bullet and snow field level boss ufo bomb
sprite_22 ENT
            db    $fe,$16,$02

; L bullet (up)
sprite_23 ENT
            db    $fe,$18,$02

; L bullet
sprite_24 ENT
            db    $02
            db    $f8,$92,$02,$f4
            db    $f8,$92,$02,$fc

; L bullet (angled)
sprite_25 ENT
            db    $fe,$90,$02

; soldier crouching shooting
sprite_26 ENT
            db    $04
            db    $00,$dc,$03,$f0
            db    $00,$de,$01,$f8
            db    $00,$e0,$01,$00
            db    $00,$e2,$03,$08

; soldier running 1
sprite_27 ENT
            db    $04
            db    $f0,$d6,$01,$f8
            db    $f0,$d8,$01,$00

soldier_bottom_0 ENT
            db    $00,$ce,$03,$f8
            db    $00,$cc,$03,$00

; soldier running 2
sprite_28 ENT
            db    $04
            db    $f0,$be,$01,$f8
            db    $f0,$c0,$01,$00
            db    $80
            dw    soldier_bottom_0

; soldier shooting angled up
sprite_29 ENT
            db    $04
            db    $f0,$ae,$01,$f8
            db    $f0,$b0,$01,$00
            db    $00,$ba,$01,$f8
            db    $00,$bc,$01,$00

; hangar mine cart (frame 1)
sprite_2a ENT
            db    $06

hangar_mine_cart ENT
            db    $f6,$e4,$02,$f0
            db    $f6,$e6,$02,$f8
            db    $f6,$e8,$02,$00
            db    $f6,$fc,$02,$08
            db    $04,$ea,$00,$f9    ; wheel
            db    $04,$ea,$00,$05    ; wheel

; hangar mine cart (frame 2)
sprite_2b ENT
            db    $06
            db    $04,$ec,$00,$f9
            db    $04,$ec,$00,$05
            db    $80
            dw    hangar_mine_cart

; sniper type #$04 shooting (boss rifle man), compare sprite_43
sprite_2c ENT
            db    $05
            db    $f0,$f2,$41,$f8
            db    $f0,$b6,$01,$00
            db    $f0,$b8,$01,$08
            db    $00,$f4,$41,$f8
            db    $00,$bc,$01,$00

; soldier shooting angled down
sprite_2d ENT
            db    $05
            db    $f0,$f6,$41,$f8
            db    $f0,$aa,$01,$00
            db    $f8,$ac,$01,$08
            db    $00,$f4,$41,$f8
            db    $00,$bc,$01,$00

; unknown (doesn't seem to be used)
sprite_2e ENT
            db    $04
            db    $f0,$fa,$41,$f8
            db    $f0,$f8,$41,$00
            db    $00,$f4,$41,$f8
            db    $00,$fc,$41,$00

; S weapon item
sprite_2f ENT
            db    $03
            db    $f8,$1c,$01,$fc

weapon_wings ENT
            db    $f8,$1a,$01,$f4
            db    $f8,$1a,$41,$04

; B weapon item
sprite_30 ENT
            db    $03
            db    $f8,$1e,$01,$fc
            db    $80
            dw    weapon_wings

; F weapon item
sprite_31 ENT
            db    $03
            db    $f8,$20,$01,$fc
            db    $80
            dw    weapon_wings

; L weapon item
sprite_32 ENT
            db    $03
            db    $f8,$22,$01,$fc
            db    $80
            dw    weapon_wings

; R weapon item
sprite_33 ENT
            db    $03
            db    $f8,$24,$01,$fc
            db    $80
            dw    weapon_wings

; M weapon item
sprite_34 ENT
            db    $03
            db    $f8,$26,$01,$fc
            db    $80
            dw    weapon_wings

; big explosion
sprite_35 ENT
            db    $08
            db    $f0,$54,$02,$f0
            db    $f0,$56,$02,$f8
            db    $f0,$58,$02,$00
            db    $f0,$5a,$02,$08
            db    $00,$5a,$c2,$f0
            db    $00,$58,$c2,$f8
            db    $00,$56,$c2,$00
            db    $00,$54,$c2,$08

; explosion
sprite_36 ENT
            db    $05
            db    $f0,$56,$02,$fc
            db    $f0,$5a,$02,$04
            db    $f8,$52,$02,$f4
            db    $00,$56,$c2,$fc
            db    $00,$54,$c2,$04

; small explosion
sprite_37 ENT
            db    $02
            db    $f8,$52,$82,$f8
            db    $f4,$5a,$02,$00

; round explosion
sprite_38 ENT
            db    $06
            db    $f0,$5e,$02,$f8
            db    $f0,$5e,$42,$00
            db    $f8,$5c,$02,$f0
            db    $f8,$5c,$c2,$08
            db    $00,$5e,$82,$f8
            db    $00,$5e,$c2,$00

; thick explosion ring
sprite_39 ENT
            db    $08
            db    $f0,$60,$02,$f0
            db    $f0,$62,$02,$f8
            db    $f0,$62,$42,$00
            db    $f0,$60,$42,$08
            db    $00,$60,$82,$f0
            db    $00,$62,$82,$f8
            db    $00,$62,$c2,$00
            db    $00,$60,$c2,$08

; wide explosion ring
sprite_3a ENT
            db    $08
            db    $f0,$64,$02,$f0
            db    $f0,$66,$02,$f8
            db    $f0,$66,$42,$00
            db    $f0,$64,$42,$08
            db    $00,$64,$82,$f0
            db    $00,$66,$82,$f8
            db    $00,$66,$c2,$00
            db    $00,$64,$c2,$08

; soldier running
sprite_3b ENT
            db    $04
            db    $f0,$be,$01,$f8
            db    $f0,$c0,$01,$00

soldier_bottom_1 ENT
            db    $00,$ca,$03,$f8
            db    $00,$cc,$03,$00

; soldier running
sprite_3c ENT
            db    $04
            db    $f0,$c2,$01,$f8
            db    $f0,$c4,$01,$00
            db    $00,$ce,$03,$f8
            db    $00,$d0,$03,$00

; soldier running
sprite_3d ENT
            db    $04
            db    $f0,$c6,$01,$f8
            db    $f0,$c8,$01,$00

soldier_bottom_3 ENT
            db    $00,$d2,$03,$f8
            db    $00,$d4,$03,$00

sprite_3e ENT
            db    $04
            db    $f0,$be,$01,$f8
            db    $f0,$c0,$01,$00
            db    $80
            dw    soldier_bottom_3

sprite_3f ENT
            db    $04
            db    $f0,$c6,$01,$f8
            db    $f0,$c8,$01,$00
            db    $80
            dw    soldier_bottom_1

; soldier running
sprite_40 ENT
            db    $05
            db    $f0,$d6,$01,$f8
            db    $f0,$d8,$01,$00
            db    $f0,$da,$03,$08
            db    $80
            dw    soldier_bottom_3

; soldier shooting downward
sprite_41 ENT
            db    $05
            db    $f0,$a8,$01,$f8
            db    $f0,$aa,$01,$00
            db    $f8,$ac,$01,$08

soldier_bottom_2 ENT
            db    $00,$ba,$01,$f8
            db    $00,$bc,$01,$00

; soldier shooting up angled
sprite_42 ENT
            db    $05
            db    $f0,$ae,$01,$f8
            db    $f0,$b0,$01,$00
            db    $e0,$b2,$01,$02
            db    $80
            dw    soldier_bottom_2

; rifle man shooting (sniper type #$00 and #$01)
sprite_43 ENT
            db    $05

rifle_man_top ENT
            db    $f0,$b4,$01,$f8
            db    $f0,$b6,$01,$00
            db    $f0,$b8,$01,$08
            db    $80
            dw    soldier_bottom_2

; rifle man behind bush (frame 1)
sprite_44 ENT
            db    $01
            db    $f0,$ea,$41,$fc

; rifle man behind bush (frame 2)
sprite_45 ENT
            db    $03
            db    $f0,$f0,$41,$f8
            db    $f0,$ee,$41,$00
            db    $f0,$ec,$41,$08

; rifle man behind bush (frame 3)
; by specifying #$03 entries, only top half of soldier is drawn
; soldier_bottom_2 isn't used
sprite_46 ENT
            db    $03
            db    $80
            dw    rifle_man_top

; small ring explosion
sprite_47 ENT
            db    $fe,$0c,$02

; floating rock (waterfall level)
sprite_48 ENT
            db    $07
            db    $f0,$ee,$03,$f0
            db    $f0,$f0,$03,$f8
            db    $f0,$f0,$43,$00
            db    $f0,$ee,$43,$08
            db    $00,$f2,$03,$f4
            db    $00,$fc,$03,$fc
            db    $00,$f2,$43,$04

; bridge fire (waterfall level)
sprite_49 ENT
            db    $02
            db    $f8,$ea,$02,$f8
            db    $f8,$ec,$02,$00

; boulder (waterfall level)
sprite_4a ENT
            db    $06
            db    $f0,$e6,$03,$f4
            db    $f0,$e8,$03,$fc
            db    $f0,$d7,$03,$04
            db    $00,$d9,$03,$f4
            db    $00,$db,$03,$fc
            db    $00,$dd,$03,$04

; scuba soldier hiding
sprite_4b ENT
            db    $02
            db    $f8,$dc,$01,$f8
            db    $f8,$de,$01,$00

; scuba soldier out of water shooting up
sprite_4c ENT
            db    $03
            db    $e8,$e2,$03,$00
            db    $f8,$e0,$01,$f8
            db    $f8,$e4,$01,$00

; weapon zeppelin
sprite_4d ENT
            db    $03
            db    $f8,$a4,$01,$f4
            db    $f8,$a6,$01,$fc
            db    $f8,$a4,$41,$04

; flashing falcon weapon
sprite_4e ENT
            db    $03
            db    $f8,$00,$01,$fc
            db    $80
            dw    weapon_wings

; unused blank sprite
sprite_4f ENT
            db    $00

; indoor player facing up
sprite_50 ENT
            db    $07
            db    $de,$7c,$01,$fa
            db    $ee,$7e,$01,$f8
            db    $ee,$80,$01,$00
            db    $fe,$78,$00,$f8
            db    $fe,$78,$40,$ff
            db    $0e,$7a,$00,$f6
            db    $0e,$7a,$40,$01

; indoor player strafing (frame 1)
sprite_51 ENT
            db    $05
            db    $de,$7c,$01,$fb
            db    $ee,$8c,$01,$fa
            db    $ee,$8e,$01,$02
            db    $80
            dw    player_walking_1_bottom

; indoor player strafing (frame 2)
sprite_52 ENT
            db    $06
            db    $df,$7c,$01,$fb
            db    $ef,$8c,$01,$fa
            db    $ef,$8e,$01,$02
            db    $80
            dw    player_walking_2_bottom

; indoor player strafing (frame 3)
sprite_53 ENT
            db    $06
            db    $de,$7c,$01,$fb
            db    $ee,$8c,$01,$fa
            db    $ee,$8e,$01,$02
            db    $80
            dw    player_bottom

; indoor player crouch
sprite_54 ENT
            db    $07
            db    $f4,$82,$01,$f8
            db    $f4,$84,$01,$00
            db    $0a,$86,$00,$f4
            db    $0a,$86,$40,$04
            db    $04,$88,$00,$f8
            db    $04,$88,$40,$00
            db    $fa,$8a,$00,$fc

; indoor player electrocuted
; indoor player hit by bullet frame #$01
sprite_55 ENT
            db    $08
            db    $e2,$70,$01,$01
            db    $f5,$72,$01,$f0
            db    $ed,$74,$01,$f8
            db    $ed,$76,$01,$00
            db    $fd,$78,$00,$f8
            db    $fd,$78,$40,$ff
            db    $0d,$7a,$00,$f6
            db    $0d,$7a,$40,$01

; indoor player lying dead (frame #$02)
sprite_56 ENT
            db    $08
            db    $fa,$68,$00,$f0
            db    $fa,$6a,$00,$f8
            db    $fa,$6a,$40,$00
            db    $fa,$68,$40,$08
            db    $0a,$6c,$01,$f0
            db    $0a,$6e,$01,$f8
            db    $0a,$6e,$41,$00
            db    $0a,$6c,$41,$08

; indoor player running
sprite_57 ENT
            db    $06
            db    $f4,$94,$01,$f4
            db    $ef,$96,$01,$fc
            db    $ef,$98,$01,$04
            db    $ff,$be,$00,$f8
            db    $ff,$90,$00,$00
            db    $0f,$92,$00,$00

; indoor player running
sprite_58 ENT
            db    $06
            db    $f1,$9a,$01,$f4
            db    $f1,$9c,$01,$fc
            db    $f2,$9e,$01,$04
            db    $01,$90,$40,$fa
            db    $01,$be,$40,$02
            db    $11,$92,$40,$fa

; unused blank sprite
sprite_59 ENT
            db    $00

; boss eye
sprite_5d ENT
            db    $08
            db    $fe,$a6,$02,$f8
            db    $fe,$a6,$42,$00
            db    $fe,$9e,$03,$f8
            db    $fe,$9e,$43,$00

boss_eye_top ENT
            db    $ee,$9a,$03,$f8
            db    $ee,$9a,$43,$00
            db    $f6,$9c,$03,$f0
            db    $f6,$9c,$43,$08

; boss eye
sprite_5e ENT
            db    $08
            db    $fe,$a6,$02,$f8
            db    $fe,$a6,$42,$00
            db    $fe,$a0,$03,$f8
            db    $fe,$a0,$43,$00
            db    $80
            dw    boss_eye_top

; boss eye
sprite_5f ENT
            db    $08

boss_eye_part ENT
            db    $f6,$a8,$02,$f0
            db    $f6,$a8,$42,$08
            db    $fe,$a2,$03,$f8
            db    $fe,$a2,$43,$00
            db    $80
            dw    boss_eye_top

; boss eye
sprite_60 ENT
            db    $08
            db    $fe,$aa,$02,$f8
            db    $fe,$aa,$42,$00

boss_eye_int ENT
            db    $fe,$a4,$03,$f8
            db    $fe,$a4,$43,$00
            db    $80
            dw    boss_eye_top

; boss eye
sprite_61 ENT
            db    $08
            db    $fe,$ac,$02,$f8
            db    $fe,$ac,$42,$00
            db    $80
            dw    boss_eye_int

; boss eye
sprite_62 ENT
            db    $09
            db    $fe,$ae,$02,$fc
            db    $80
            dw    boss_eye_part

; small boss eye projectile (unused)
sprite_63 ENT
            db    $02
            db    $f8,$b0,$03,$f8
            db    $f8,$b2,$03,$00

; boss eye projectile
sprite_64 ENT
            db    $08
            db    $f0,$b4,$03,$f0
            db    $f0,$b6,$03,$f8
            db    $f0,$b8,$03,$00
            db    $f0,$ba,$03,$08
            db    $00,$bc,$03,$f0
            db    $00,$be,$03,$f8
            db    $00,$c0,$03,$00
            db    $00,$c2,$03,$08

; unused blank sprite
sprite_65 ENT
            db    $00

; base 2 boss metal helmet (Godomuga) (frame 1)
sprite_68 ENT
            db    $08
            db    $f0,$dc,$03,$f8
            db    $f0,$dc,$43,$00
            db    $00,$d2,$03,$f8
            db    $00,$d2,$43,$00
            db    $00,$d0,$03,$f0
            db    $00,$d0,$43,$08

metal_helmet_ears ENT
            db    $f0,$da,$03,$f0
            db    $f0,$da,$43,$08

; base 2 boss metal helmet (Godomuga) (frame 2)
sprite_69 ENT
            db    $08
            db    $f0,$de,$03,$f8
            db    $f0,$de,$43,$00

metal_helmet_part ENT
            db    $00,$d6,$03,$f8
            db    $00,$d6,$43,$00

metal_helmet_mouth ENT
            db    $00,$d4,$03,$f0
            db    $00,$d4,$43,$08
            db    $80
            dw    metal_helmet_ears

; base 2 boss metal helmet (Godomuga) (frame 3)
sprite_6a ENT
            db    $08
            db    $f0,$e0,$03,$f8
            db    $f0,$e0,$43,$00

metal_helmet_mouth_inside ENT
            db    $00,$d8,$03,$f8
            db    $00,$d8,$43,$00
            db    $80
            dw    metal_helmet_mouth

; base 2 boss metal helmet (Godomuga) (frame 4)
sprite_6b ENT
            db    $08
            db    $f0,$e2,$02,$f8
            db    $f0,$e2,$42,$00
            db    $80
            dw    metal_helmet_part

; base 2 boss metal helmet (Godomuga) (frame 5)
sprite_6c ENT
            db    $08
            db    $f0,$e4,$02,$f8
            db    $f0,$e4,$42,$00
            db    $80
            dw    metal_helmet_mouth_inside

; base 2 boss metal helmet (Godomuga) bubble projectile
sprite_6d ENT
            db    $02
            db    $f8,$e8,$03,$f8
            db    $f8,$e6,$02,$fe

; base 2 boss metal helmet (Godomuga) bubble projectile
sprite_6e ENT
            db    $02
            db    $f8,$ec,$03,$fa
            db    $f8,$ea,$02,$01

; base 2 boss metal helmet (Godomuga) bubble projectile
sprite_6f ENT
            db    $fe,$ec,$03

; base 2 boss metal helmet (Godomuga) bubble projectile
sprite_70 ENT
            db    $02
            db    $f8,$ea,$42,$f7
            db    $f8,$ec,$43,$fe

; base 2 boss metal helmet (Godomuga) bubble projectile
sprite_71 ENT
            db    $02
            db    $f8,$e6,$42,$fa
            db    $f8,$e8,$43,$00

; base 2 boss metal helmet (Godomuga) bubble projectile
sprite_72 ENT
            db    $fe,$ec,$02

; water splash
sprite_73 ENT
            db    $02
            db    $f8,$e6,$00,$f8
            db    $f8,$e6,$40,$00

; ice grenade lean right
sprite_74 ENT
            db    $02
            db    $f8,$e6,$00,$f8
            db    $f8,$e6,$c0,$00

; ice grenade horizontal
sprite_75 ENT
            db    $02
            db    $f8,$e8,$00,$f8
            db    $f8,$e8,$40,$00

; ice grenade tipping downward
sprite_76 ENT
            db    $02
            db    $f8,$e6,$80,$f8
            db    $f8,$e6,$40,$00

; ice grenade vertical
sprite_77 ENT
            db    $02
            db    $f8,$ea,$80,$f8
            db    $f8,$ea,$40,$00

; !(UNUSED) duplicate of sprite_74 (ice grenade lean right), unused in game
sprite_78 ENT
            db    $02
            db    $f8,$e6,$00,$f8
            db    $f8,$e6,$c0,$00

; dragon boss projectile
sprite_79 ENT
            db    $02
            db    $f8,$f4,$02,$f8
            db    $f8,$f6,$02,$00

; dragon arm interior orb (gray)
sprite_7a ENT
            db    $02
            db    $f8,$f8,$03,$f8
            db    $f8,$f8,$43,$00

; dragon arm hand orb (red)
sprite_7b ENT
            db    $02
            db    $f8,$fa,$01,$f8
            db    $f8,$fa,$41,$00

; snow field boss mini UFO
sprite_7c ENT
            db    $03
            db    $f8,$fc,$03,$f4
            db    $f8,$33,$03,$fc
            db    $f8,$35,$03,$04

; snow field boss mini UFO
sprite_7d ENT
            db    $03
            db    $f8,$37,$03,$f4
            db    $f8,$39,$03,$fc
            db    $f8,$3b,$03,$04

; snow field boss mini UFO
sprite_7e ENT
            db    $03
            db    $f8,$3d,$03,$f4
            db    $f8,$3f,$03,$fc
            db    $f8,$41,$03,$04

; unknown (doesn't seem to be used)
sprite_7f ENT
sprite_80 ENT
            db    $02
            db    $f8,$ca,$02,$f8
            db    $f8,$ca,$42,$00

; unknown (doesn't seem to be used)
sprite_81 ENT
            db    $02
            db    $f8,$cc,$02,$f8
            db    $f8,$cc,$42,$00

; L bullet indoor level shot from
;  * 27%-43% horizontal portion of the playable screen
;  * 58%-70% horizontal portion of the playable screen
sprite_82 ENT
            db    $01
            db    $f8,$a2,$02,$fc

; L bullet indoor level shot from
;  * 20%-27% horizontal portion of the playable screen
;  * 70%-80% horizontal portion of the playable screen
; same as sprite_92
sprite_83 ENT
            db    $01
            db    $f8,$a0,$02,$fc

; L bullet indoor level shot from
;  * 10%-20% horizontal portion of the playable screen
;  * 80%-90% horizontal portion of the playable screen
sprite_84 ENT
            db    $01
            db    $f8,$a2,$02,$fc

; base 2 boss blue soldier
sprite_85 ENT
            db    $05
            db    $f0,$f2,$03,$08

base_2_soldier_part ENT
            db    $f0,$ee,$03,$f8
            db    $f0,$f0,$03,$00
            db    $00,$f4,$03,$f6
            db    $00,$f6,$03,$fe

; base 2 boss blue soldier
sprite_86 ENT
            db    $04

base_2_soldier_bottom ENT
            db    $e8,$f8,$03,$fe
            db    $f8,$fa,$03,$f6
            db    $f8,$ce,$03,$fe
            db    $08,$dd,$03,$03

; base 2 boss blue soldier
sprite_87 ENT
            db    $03

base_2_soldier_bottom_2 ENT
            db    $f0,$df,$03,$f8
            db    $f0,$e1,$03,$00
            db    $00,$e3,$03,$fc

; base 2 blue soldier facing out (frame 1)
sprite_88 ENT
            db    $04

blue_soldier_facing_out ENT
            db    $f0,$e5,$43,$f9
            db    $f0,$e5,$03,$00
            db    $00,$e7,$43,$f9
            db    $00,$e7,$03,$00

; base 2 blue soldier facing out (frame 2)
sprite_89 ENT
            db    $04
            db    $f0,$e9,$43,$f9
            db    $f0,$e9,$03,$00
            db    $00,$eb,$43,$f9
            db    $00,$eb,$03,$00

; base 2 blue soldier flying (frame 1)
sprite_8a ENT
            db    $05
            db    $f0,$ed,$03,$f4
            db    $f0,$ef,$03,$fc
            db    $f0,$ed,$43,$04
            db    $00,$f1,$03,$f8
            db    $00,$f3,$03,$00

; base 2 blue soldier flying (frame 2)
sprite_8b ENT
            db    $07
            db    $f2,$f5,$03,$f4
            db    $f2,$f7,$03,$fc
            db    $f2,$f5,$43,$04
            db    $02,$f9,$03,$f8
            db    $02,$fb,$03,$00
            db    $12,$b0,$03,$f7
            db    $12,$b2,$03,$00

; base boss level 4 base 2 red soldier
sprite_8c ENT
            db    $05
            db    $f0,$fc,$02,$08
            db    $80
            dw    base_2_soldier_part

; base boss level 4 base 2 red soldier
sprite_8d ENT
            db    $05
            db    $f8,$a6,$02,$04
            db    $80
            dw    base_2_soldier_bottom

; base boss level 4 base 2 red soldier
sprite_8e ENT
            db    $04
            db    $ff,$c4,$02,$00
            db    $80
            dw    base_2_soldier_bottom_2

; base boss level 4 base 2 red soldier facing player
sprite_8f ENT
            db    $05
            db    $00,$c6,$02,$f4
            db    $80
            dw    blue_soldier_facing_out

; base boss level 4 base 2 red soldier facing player with weapon
sprite_90 ENT
            db    $04
            db    $f0,$c8,$42,$f9
            db    $f0,$c8,$02,$00
            db    $00,$ca,$02,$f8
            db    $00,$cc,$02,$00

; indoor boss defeated elevator with player on top
sprite_91 ENT
            db    $08
            db    $0c,$fd,$02,$f4
            db    $0c,$fd,$02,$fc
            db    $0c,$fd,$02,$04
            db    $80
            dw    player_facing_side

; L bullet indoor level shot from
;  * <= 10% horizontal portion of the playable screen
;  * >= 90% horizontal portion of the playable screen
; same as sprite_83
sprite_92 ENT
            db    $01
            db    $f8,$a0,$02,$fc

; jumping man
sprite_93 ENT
            db    $04
            db    $eb,$ce,$01,$ff
            db    $ec,$a8,$03,$fb
            db    $fc,$aa,$03,$f6
            db    $fb,$ac,$03,$fe

; jumping man
sprite_94 ENT
            db    $04
            db    $ed,$ae,$01,$fe
            db    $ed,$b0,$03,$fb
            db    $fd,$b2,$03,$f7
            db    $fd,$b4,$03,$ff

; jumping man
sprite_95 ENT
            db    $04
            db    $ed,$b6,$01,$ff
            db    $ed,$b8,$03,$fb
            db    $fd,$ba,$03,$f4
            db    $fd,$bc,$03,$fc

; indoor soldier hit by bullet sprite
; indoor soldier, jumping man, grenade launcher, group of four soldiers firing at player
sprite_96 ENT
            db    $04
            db    $eb,$da,$01,$ff
            db    $ed,$c0,$03,$fc
            db    $fd,$c2,$43,$f9
            db    $fd,$c2,$03,$00

; jumping man in air
sprite_97 ENT
            db    $05
            db    $e8,$d0,$01,$fa
            db    $e8,$d2,$03,$fc
            db    $f8,$d4,$03,$f4
            db    $f8,$d6,$03,$fc
            db    $f8,$d8,$03,$04

; jumping man facing player
sprite_98 ENT
            db    $03
            db    $f0,$da,$01,$ff
            db    $fc,$dc,$03,$fb
            db    $00,$de,$03,$03

; small indoor rolling grenade
sprite_99 ENT
            db    $02
            db    $fe,$e0,$01,$f8
            db    $fe,$e0,$41,$00

; closer indoor rolling grenade
sprite_9a ENT
            db    $02
            db    $fe,$e2,$01,$f8
            db    $fe,$e2,$41,$00

; even closer indoor rolling grenade
sprite_9b ENT
            db    $03
            db    $fd,$e4,$01,$f4
            db    $fd,$e6,$01,$fc
            db    $fd,$e4,$41,$04

; closest indoor rolling grenade
sprite_9c ENT
            db    $03
            db    $fc,$e8,$01,$f4
            db    $fc,$ea,$41,$fc
            db    $fc,$e8,$41,$04

; indoor base enemy kill explosion (frame 1)
sprite_9d ENT
            db    $fe,$c8,$02

; indoor base enemy kill explosion (frame 2)
sprite_9e ENT
            db    $02
            db    $f8,$ca,$02,$f8
            db    $f8,$ca,$c2,$00

; indoor base enemy kill explosion (frame 3)
sprite_9f ENT
            db    $02
            db    $f8,$cc,$02,$f8
            db    $f8,$cc,$c2,$00

; indoor hand grenade
sprite_a0 ENT
            db    $02
            db    $f8,$ec,$01,$f8
            db    $f8,$ee,$01,$00

; indoor hand grenade
sprite_a1 ENT
            db    $01
            db    $f8,$f0,$01,$fd

; indoor hand grenade
sprite_a2 ENT
            db    $fe,$f2,$01

; indoor hand grenade
sprite_a3 ENT
            db    $01
            db    $f8,$f4,$01,$fb

; indoor hand grenade
sprite_a4 ENT
            db    $01
            db    $f8,$f6,$01,$fd

; indoor hand grenade
sprite_a5 ENT
            db    $01
            db    $f8,$f8,$01,$fd

; indoor hand grenade
sprite_a6 ENT
            db    $fe,$fa,$01

; indoor hand grenade
sprite_a7 ENT
            db    $01
            db    $f8,$fc,$01,$fd

; indoor hand grenade
sprite_a8 ENT
            db    $fe,$c4,$01

; indoor hand grenade
sprite_a9 ENT
            db    $fe,$c6,$01,$00

; falcon (player select icon)
sprite_aa ENT
            db    $02
            db    $f8,$ce,$01,$f8
            db    $f8,$d0,$01,$00

; Bill and Lance's hair and shirt
; For Probotector - red splash behind Probotector title
sprite_ab ENT
            db    $16
            db    $00,$da,$01,$00
            db    $00,$de,$01,$08
            db    $00,$e2,$01,$10
            db    $10,$dc,$02,$00
            db    $10,$e0,$02,$08
            db    $10,$e4,$02,$10
            db    $20,$ea,$00,$05
            db    $20,$f4,$00,$15
            db    $30,$ec,$00,$05
            db    $30,$f6,$00,$15
            db    $40,$ee,$00,$05
            db    $40,$f8,$00,$15
            db    $fd,$d6,$02,$f8
            db    $02,$d4,$02,$f0
            db    $04,$d2,$02,$e8
            db    $0c,$d8,$02,$f8
            db    $1f,$e6,$00,$f5
            db    $1f,$e8,$00,$fd
            db    $24,$f0,$00,$0d
            db    $24,$fa,$00,$1d
            db    $34,$f2,$00,$0d
            db    $34,$fc,$00,$1d

; alien's lair bundle (crustacean-like alien)
sprite_ac ENT
            db    $06

alien_bundle ENT
            db    $00,$b0,$c2,$04
            db    $00,$b2,$c2,$fc
            db    $00,$b4,$c2,$f4
            db    $f0,$b6,$c2,$04
            db    $f0,$b8,$c2,$fc
            db    $f0,$ba,$c2,$f4

; alien's lair bundle (crustacean-like alien) mouth open
sprite_ad ENT
            db    $06
            db    $f0,$ea,$c2,$fc
            db    $f0,$ec,$c2,$f4
            db    $80
            dw    alien_bundle

; alien's lair bundle (crustacean-like alien)
sprite_ae ENT
            db    $06

alien_bundle_2 ENT
            db    $00,$f0,$c2,$04
            db    $00,$f2,$c2,$fc
            db    $00,$f4,$c2,$f4
            db    $f0,$aa,$c2,$f4
            db    $f0,$ac,$c2,$fc
            db    $f0,$ae,$c2,$fc

; alien's lair bundle (crustacean-like alien)
sprite_af ENT
            db    $06
            db    $f0,$f6,$c2,$04
            db    $f0,$a8,$c2,$fc
            db    $80
            dw    alien_bundle_2

; alien pink blob
sprite_b0 ENT
            db    $02
            db    $f8,$fa,$03,$f8
            db    $f8,$fa,$43,$00

; small alien boss spider (poisonous insect gel) (frame 1)
sprite_b1 ENT
            db    $02
            db    $f8,$fc,$03,$f8
            db    $f8,$fc,$43,$00

; small alien boss spider (poisonous insect gel) (frame 2)
sprite_b2 ENT
            db    $02
            db    $f8,$f8,$03,$f8
            db    $f8,$f8,$43,$00

; boss alien bugger insect/spider (frame 1)
sprite_b3 ENT
            db    $06
            db    $f0,$c0,$03,$f8
            db    $f0,$c2,$03,$00
            db    $00,$c4,$03,$f0
            db    $00,$c6,$03,$f8
            db    $00,$c8,$03,$00
            db    $00,$ca,$03,$08

; boss alien bugger insect/spider (frame 2)
sprite_b4 ENT
            db    $08
            db    $f1,$cc,$03,$f0
            db    $f1,$ce,$03,$f8
            db    $f1,$d0,$03,$00
            db    $f1,$d2,$03,$08
            db    $01,$d4,$03,$f0
            db    $01,$d6,$03,$f8
            db    $01,$d8,$03,$00
            db    $01,$da,$03,$08

; boss alien bugger insect/spider (frame 3)
sprite_b5 ENT
            db    $07
            db    $f0,$dc,$03,$f8
            db    $f0,$de,$03,$00
            db    $f0,$e0,$03,$08
            db    $00,$e2,$03,$f0
            db    $00,$e4,$03,$f8
            db    $00,$e6,$03,$00
            db    $00,$e8,$03,$08

; boss alien eggron (alien egg)
sprite_b6 ENT
            db    $02
            db    $f8,$bc,$03,$f8
            db    $f8,$be,$03,$00

; energy zone boss giant armored soldier
sprite_b7 ENT
            db    $16

giant_soldier_top ENT
            db    $d8,$dc,$02,$f0
            db    $d8,$de,$02,$f8
            db    $d8,$e0,$02,$00
            db    $d8,$e2,$02,$08
            db    $e4,$fd,$03,$e8
            db    $e8,$e4,$03,$e0
            db    $e8,$e6,$02,$f0
            db    $e8,$e8,$02,$f8
            db    $e8,$ea,$02,$00
            db    $e7,$a8,$03,$06
            db    $e7,$aa,$03,$0e
            db    $f7,$b4,$03,$0b

giant_soldier_bottom ENT
            db    $f8,$ac,$03,$e8
            db    $f8,$ae,$03,$f0
            db    $f8,$b0,$03,$f8
            db    $f8,$b2,$03,$00
            db    $08,$b8,$03,$e8
            db    $08,$ba,$03,$f0
            db    $08,$bc,$03,$f8
            db    $08,$be,$03,$00
            db    $08,$c0,$03,$08
            db    $08,$c2,$03,$10

; energy zone boss giant armored soldier (legs together)
sprite_b9 ENT
            db    $12
            db    $f9,$d8,$03,$f0
            db    $f9,$da,$03,$f8
            db    $f9,$ff,$03,$00
            db    $09,$b6,$03,$f0
            db    $09,$07,$03,$f8
            db    $09,$09,$03,$00
            db    $da,$dc,$02,$f0
            db    $da,$de,$02,$f8
            db    $da,$e0,$02,$00
            db    $da,$e2,$02,$08
            db    $e6,$fd,$03,$e8
            db    $ea,$e4,$03,$e0
            db    $ea,$e6,$02,$f0
            db    $ea,$e8,$02,$f8
            db    $ea,$ea,$02,$00
            db    $e9,$a8,$03,$06
            db    $e9,$aa,$03,$0e
            db    $f9,$b4,$03,$0b

; energy zone boss giant armored soldier (running, jumping)
sprite_ba ENT
            db    $15
            db    $f8,$ca,$03,$e8
            db    $f8,$cc,$03,$f0
            db    $f8,$ce,$03,$f8
            db    $f8,$d0,$03,$00
            db    $f7,$d4,$03,$08
            db    $f7,$d6,$03,$10
            db    $08,$c4,$03,$d8
            db    $08,$c6,$03,$e0
            db    $08,$c8,$03,$e8
            db    $08,$d2,$03,$00
            db    $80
            dw    giant_soldier_top

; energy zone boss projectile (spiked disk)
sprite_bb ENT
            db    $02
            db    $f8,$df,$00,$f8
            db    $f8,$df,$40,$00

; energy zone boss projectile (spiked disk)
sprite_bc ENT
            db    $02
            db    $f8,$fb,$00,$f8
            db    $f8,$fb,$40,$00

; mounted soldier (basquez)
sprite_bd ENT
            db    $07
            db    $f4,$ee,$03,$f0
            db    $f4,$f2,$03,$f8
            db    $04,$f0,$03,$f0
            db    $04,$f4,$03,$f8
            db    $04,$f8,$00,$00
            db    $f4,$f6,$01,$00
            db    $f4,$fa,$01,$08

; mounted soldier (basquez)
sprite_be ENT
            db    $07
            db    $f4,$ee,$03,$f2
            db    $f4,$f2,$03,$fa
            db    $04,$f0,$03,$f2
            db    $04,$f4,$03,$fa
            db    $04,$f8,$00,$01
            db    $f4,$f6,$01,$01
            db    $f4,$fa,$01,$09

; energy zone wall fire
sprite_bf ENT
            db    $01
            db    $ef,$33,$02,$ff

; energy zone wall fire
sprite_c0 ENT
            db    $01
            db    $ef,$35,$02,$ff

; energy zone ceiling fire
sprite_c1 ENT
            db    $01
            db    $ef,$37,$02,$fc

; energy zone ceiling fire
sprite_c2 ENT
            db    $01
            db    $ef,$39,$02,$fc

; energy zone boss giant armored soldier (throwing)
sprite_c3 ENT
            db    $13
            db    $d8,$9d,$02,$f0
            db    $d8,$d7,$02,$f8
            db    $d8,$d9,$02,$00
            db    $e0,$3d,$03,$e0
            db    $e0,$47,$03,$e8
            db    $e8,$0b,$03,$d8
            db    $e8,$9f,$02,$f0
            db    $e8,$db,$03,$f8
            db    $e8,$dd,$03,$00
            db    $80
            dw    giant_soldier_bottom

; snow field ground separator
sprite_c4 ENT
            db    $01
            db    $ff,$fd,$00,$fc

; green helicopter ending scene (frame 1)
sprite_c5 ENT
            db    $02
            db    $f8,$a8,$00,$f8
            db    $f8,$aa,$00,$00

; green helicopter ending scene (frame 2)
sprite_c6 ENT
            db    $03
            db    $f8,$ac,$00,$f8
            db    $f8,$ae,$00,$00
            db    $f8,$a6,$01,$07

; green helicopter ending scene (frame 3)
sprite_c7 ENT
            db    $02
            db    $f8,$b0,$00,$f8
            db    $f8,$b2,$00,$00

; green helicopter ending scene (frame 4)
sprite_c8 ENT
            db    $03
            db    $f8,$b4,$00,$f8
            db    $f8,$b6,$00,$00
            db    $f8,$a6,$01,$05

; green helicopter facing forward (frame 1)
sprite_c9 ENT
            db    $05
            db    $f8,$b8,$00,$f3
            db    $f8,$ba,$00,$fb
            db    $f8,$bc,$00,$03
            db    $03,$a6,$01,$fb
            db    $03,$a6,$01,$05

; green helicopter facing forward (frame 2)
sprite_ca ENT
            db    $07
            db    $f0,$be,$40,$08
            db    $f0,$c0,$40,$00
            db    $f0,$c2,$40,$f8
            db    $f0,$c4,$40,$f0
            db    $00,$c6,$40,$08
            db    $00,$c8,$40,$00
            db    $00,$ca,$40,$f8

; green helicopter facing forward (frame 3)
sprite_cb ENT
            db    $0a
            db    $f0,$cc,$00,$e8
            db    $f0,$ce,$00,$f0
            db    $f0,$d0,$00,$f8
            db    $f0,$d2,$00,$00
            db    $f0,$d4,$00,$08
            db    $f0,$d6,$00,$10
            db    $00,$d8,$00,$f8
            db    $00,$da,$00,$00
            db    $04,$a6,$01,$f8
            db    $04,$a6,$01,$07

; green helicopter facing forward (frame 4)
sprite_cc ENT
            db    $09
            db    $f0,$dc,$40,$14
            db    $f0,$de,$40,$0c
            db    $f0,$e0,$40,$04
            db    $f0,$e2,$40,$fc
            db    $f0,$e4,$40,$f4
            db    $f0,$e6,$40,$ec
            db    $00,$e8,$40,$04
            db    $00,$ea,$40,$fc
            db    $00,$ec,$40,$f4

; green helicopter facing forward (frame 5)
sprite_cd ENT
            db    $0b
            db    $f0,$ee,$40,$14
            db    $f0,$f0,$40,$0c
            db    $f0,$f2,$40,$04
            db    $f0,$e2,$40,$fc
            db    $f0,$e4,$40,$f4
            db    $f0,$f4,$40,$ec
            db    $00,$e8,$40,$04
            db    $00,$ea,$40,$fc
            db    $00,$ec,$40,$f4
            db    $0a,$a6,$01,$08
            db    $02,$a6,$01,$f7

; green helicopter facing forward (frame 6)
sprite_ce ENT
            db    $09
            db    $f0,$f6,$40,$14
            db    $f0,$de,$40,$0c
            db    $f0,$e0,$40,$04
            db    $f0,$f8,$40,$fc
            db    $f0,$fa,$40,$f4
            db    $f0,$fc,$40,$ec
            db    $00,$e8,$40,$04
            db    $00,$ea,$40,$fc
            db    $00,$ec,$40,$f4

; ending sequence mountains
sprite_cf ENT
            db    $05
            db    $00,$63,$03,$00
            db    $00,$65,$03,$08
            db    $00,$65,$03,$10
            db    $00,$65,$03,$18
            db    $00,$89,$03,$20

; unused #$21b bytes out of #$4000 bytes total (96.71% full)
; unused 539 bytes out of 16,384 bytes total (96.71% full)
; filled with 539 #$ff bytes by contra.cfg configuration
bank_1_unused_space ENT

            ds    $C000-*,$FF
            put   rom_07_fixed.s

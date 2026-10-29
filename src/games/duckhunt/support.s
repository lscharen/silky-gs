; Duck Hunt -- the support area: the routines the converted ROM's patches call (tools/convert.js,
; PATCHES), in the ROM bank below $C000.  Each patch has the size of the code it replaces, so these
; routines do what the original code did there, plus what the runtime needs (yield).
;
; Called with JSR from the ROM: 8-bit registers, DBR = the ROM bank (the NES RAM), D = the NES zero page.

            mx    %11

NES_ReadJoy EXT                               ; rom/rom_input.s (MAIN)

; Reset ($C01E): the RAM clear, sta ($00),y from $06FF down to $0000 (the pointer at $00 starts at $0600).
; Through the data bank, the zero page writes would miss the direct page, so clear it and $0200-$06FF
; directly.  Not the stack page, which the NES task is running on.  Leaves the loop's state: A = 0, Y = 0,
; $00 = 0, $01 = $FF; X (the saved RNG seed) is kept.
ClearRAM_GS
            phx
            lda   #0
            tax
:clear      sta   $00,x                       ; The zero page (the direct page)
            sta   $0200,x                     ; $0200-$06FF (the data bank)
            sta   $0300,x
            sta   $0400,x
            sta   $0500,x
            sta   $0600,x
            inx
            bne   :clear
            plx
            ldy   #0
            lda   #$FF
            sta   $01
            lda   #0
            rts

; The main loop ($C080): jsr _func_c588 / jmp _label_c07c, until the NMI has set $20.  On the NES it runs
; the RNG over and over while it waits; here the NMI runs when the ROM yields, so run it once and yield.
Idle_GS
            jsr   _func_c588
            jsl   yield
            rts

; _func_c5d9 ($C5DC): lda $20 / beq *-2, the wait for the NMI.  Yield until it has run.  Returns with
; A = $20 (non-zero), as the loop did.
WaitNMI_GS
:loop       lda   $20
            bne   :done
            jsl   yield
            bra   :loop
:done       rts

; The controller read ($C291): ldy #8 and the loop that shifts JOYPAD1,X in, A first (bit 7).  X = 0 / 1;
; the runtime's controller bytes (NES_ReadJoy) have the same layout.  Returns with Y = 0, as the loop did.
ReadJoy_GS
            jsl   NES_ReadJoy
            ldy   #0
            rts

; _func_f35e-_func_f36a ($F378): copy a channel's 4 register values, lda ($F6),y / sta ($F4),y for
; Y = 0-3, where ($F4) points at $4000 / $4004 / $4008 / $400C.  Through the data bank those stores would
; miss the APU, so each one goes to its register's hook (rom_inject.s, apu_write_tbl).  Returns with
; A = Y = 4 and the flags of the loop's last cmp #$04 (Z = 1, C = 1); X is kept.
WriteApuRegs_GS
            phx
            ldy   #0
:loop       lda   ($F6),y
            pha
            tya
            clc
            adc   $F4
            and   #$1F
            asl
            tax
            pla
            jsr   (apu_write_tbl,x)
            iny
            cpy   #4
            bne   :loop
            plx
            tya
            cmp   #$04
            rts

; The Zapper's trigger ($D131): lda JOYPAD2 (bit 4 = the trigger, bit 3 = 0 when it sees light).
; TODO: zapper detection.  For now the trigger is never pulled and no light is seen.
ReadZapper_GS
            lda   #$08
            rts

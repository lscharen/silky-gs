; Tengen Tetris -- the support area: the routines the converted ROM's patches call (tools/convert.js,
; PATCHES), in the ROM bank below $8000.  Each patch has the size of the code it replaces, so these
; routines do what the original code did there, plus what the runtime needs (yield, the APU hooks).
;
; Called with JSR from the ROM: 8-bit registers, DBR = the ROM bank (the NES RAM), D = the NES zero page.

            mx    %11

NES_ReadJoy EXT                               ; rom/rom_input.s (MAIN)
PPUSTATUS_READ EXT                            ; (declared by rom_inject.s too)

; bit PPUSTATUS.  The ROM only uses it to reset the PPU address latch before setting PPUADDR (its
; VBlank waits are patched out), so the flags are not emulated.  A is preserved.
BIT_2002
            pha
            jsl   PPUSTATUS_READ
            pla
            rts

; mainLoop ($800F): lda frameCounterLow / cmp frameCounterLowLastFrame, then beq mainLoop.  On the NES
; the loop spins until the NMI has counted a frame; here the NMI runs when the ROM yields, so yield
; unless a frame has already gone by (a wait loop inside the frame's work may have yielded).
WaitNextFrame_GS
            lda   frameCounterLow
            cmp   frameCounterLowLastFrame
            bne   :done
            jsl   yield
            lda   frameCounterLow
            cmp   frameCounterLowLastFrame
:done       rts

; L8ED0 ($8ED0): spin until currentPPUSlot = nextPPUSlot (the NMI has caught up with the staged
; writes).  Returns with Z = 1, so the beq that follows is taken, as it was.
WaitPPUSlots_GS
:loop       lda   currentPPUSlot
            cmp   nextPPUSlot
            beq   :done
            jsl   yield
            bra   :loop
:done       rts

; enableNMIAndWaitForRendering ($A3EE): spin until the NMI has sent the render slot X.  Returns with
; A = 0, as the loop did.
WaitRenderSlot_GS
:loop       lda   ppuRenderSlot0Length,x
            beq   :done
            jsl   yield
            bra   :loop
:done       rts

; waitForNMIAndDisablePPURendering ($A44E): spin until the NMI has sent every staged slot.  Returns
; with X = currentPPUSlot, as the loop did.
WaitPPUIdle_GS
:loop       ldx   currentPPUSlot
            cpx   nextPPUSlot
            bne   :wait
            lda   ppuRenderSlot0Length,x
            beq   :done
:wait       jsl   yield
            bra   :loop
:done       rts

; pollController ($A41A): the 8-bit serial read of JOY1 / JOY2.  The ROM's controller bytes have A in
; bit 0 (it shifts each bit in from the top), the runtime's (NES_ReadJoy) have A in bit 7, so the bits
; are reversed.  No expansion port controllers.  Returns with X = 0, as the loop did.
ReadControllers_GS
            phy
            ldx   #0
            jsl   NES_ReadJoy
            jsr   :reverse
            sta   player1ControllerHeld
            ldx   #1
            jsl   NES_ReadJoy
            jsr   :reverse
            sta   player2ControllerHeld
            lda   #0
            sta   player1ExpansionHeld
            sta   player2ExpansionHeld
            ldx   #0
            ply
            rts

:reverse    ldy   #8
:bit        asl
            ror   joyBits
            dey
            bne   :bit
            lda   joyBits
            rts

joyBits     ds    1

; setCNROMBank ($9EB0): stx currentCHRBank / inx.  X = 0 (the menus and the game) or 4 (the title
; screen and the leaderboard).  The NMI writes the bank (2 + currentCHRBank / 4) to the CNROM register
; every frame, through a bus conflict table at $FFF6; with 16KB of CHR-ROM that is bank 0 or 1.  Record
; it in ppu_bank and flag a change (ppu_bank_changed): the game's PRE_RENDER (CheckCHRBank, Main.s)
; copies the bank into CHR_ROM.  The NMI's write is patched out.  A is preserved; the flags are inx's.
ppu_bank    EXT                               ; rom/rom_exec.s (MAIN)
ppu_bank_changed EXT

SetCNROMBank_GS
            stx   currentCHRBank
            pha
            txa
            lsr
            lsr
            and   #$01
            cmpl  ppu_bank
            beq   :same
            stal  ppu_bank
            lda   #1
            stal  ppu_bank_changed
:same       pla
            inx
            rts

; stageCurrentAndNextSprites ($8BC8): lda generalCounter3c / ora #$20, a piece's sprite attribute: the
; palette is the piece's index (0 / 1 = the falling pieces, 2 / 3 = the next pieces), behind the
; background.  The two player palette (palettes/game_2p.txt) has no slots left for SP2 / SP3, so in a
; two player or co-op game each next piece is drawn in its player's falling piece palette (SP0 / SP1).
; Only A changes (X and Y are the caller's loop counter and OAM offset).
NextPieceAttr_GS
            lda   playMode
            beq   :onePlayer
            lda   generalCounter3c
            and   #$01
            ora   #$20
            rts
:onePlayer  lda   generalCounter3c
            ora   #$20
            rts

; The APU writes through the (apuRegister) pointer ($D8A5-$D8DA): sta (apuRegister),y goes to the
; register's hook (rom_inject.s, apu_write_tbl).  apuRegister points at $4000 / $4004 / $4008 / $400C
; and Y is 0-3.  A, X, Y and the flags are preserved, like the store.
WriteApuSlot1_GS
            ldy   #$00
            bra   StaApuIndY
WriteApuSlot2_GS
            lda   audioStagingSlot2
            bra   StaApuIndY
WriteApuSlot3_GS
            lda   audioStagingSlot3
            bra   StaApuIndY
WriteApuSlot4_GS
            lda   audioStagingSlot4

StaApuIndY
            php
            phx
            pha
            tya
            clc
            adc   apuRegister
            and   #$1F
            asl
            tax
            pla
            jsr   (apu_write_tbl,x)
            plx
            plp
            rts

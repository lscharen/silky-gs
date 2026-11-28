; SPDX-License-Identifier: Apache-2.0
;
; Optional FME-7 bank-register state, adapted from the Gimmick IIgs port.
; PUT once in the game's MAIN segment. See docs/fme7.md for integration.
;
; Call with JSL in native mode with 8-bit A and indexes. All three entries
; preserve registers (including hidden B), DBR, D, and flags. Reset takes
; the cartridge's final 8 KiB PRG bank in A and initializes all state;
; this is a software convention, not a hardware power-on guarantee.
; Route writes in $8000-$9FFF to Select and $A000-$BFFF to Write, with
; the NES write value in A. Reads in these ranges still go to PRG ROM.
;
; Bank registers retain hardware-width bits. Apply cartridge address-line
; masks when consuming the state (5A/5B use only five PRG bank bits).
; Native code/data mapping, CHR cache updates, PPU mirroring, IRQs ($D-$F),
; and Sunsoft 5B sound writes ($C000-$FFFF) require separate adapters.

               mx    %11

FME7_Reset ENT
               php
               pha
               phb
               phk
               plb
               phx
               and   #$3F
               sta   FME7_PRG+3
               ldx   #7
:clearCHR      stz   FME7_CHR,x
               dex
               bpl   :clearCHR
               stz   FME7_Command
               stz   FME7_PRG6000
               stz   FME7_PRG
               stz   FME7_PRG+1
               stz   FME7_PRG+2
               stz   FME7_Mirror
               plx
               plb
               pla
               plp
               rtl

FME7_Select ENT
               php
               pha
               phb
               phk
               plb
               and   #$0F
               sta   FME7_Command
               plb
               pla
               plp
               rtl

FME7_Write ENT
               php
               pha
               phx
               phb
               phk
               plb
               ldx   FME7_Command
               cpx   #8
               bcc   :chr
               beq   :window6000
               cpx   #12
               bcc   :prg
               beq   :mirror
               bra   :done       ; $D-$F go to the IRQ shim

:chr           sta   FME7_CHR,x
               bra   :done
:window6000    sta   FME7_PRG6000
               bra   :done
:prg           and   #$3F
               sta   FME7_PRG-9,x
               bra   :done
:mirror        and   #$03
               sta   FME7_Mirror
:done          plb
               plx
               pla
               plp
               rtl

FME7_Command ENT
               db    0
FME7_CHR ENT
               ds    8           ; 1 KiB slots from $0000 through $1C00
FME7_PRG6000 ENT
               db    0           ; bit 6 clear: ROM bank in bits 0-5
                                 ; bit 6 set: RAM if bit 7 set, else open bus
FME7_PRG ENT
               ds    4           ; 8 KiB slots at $8000/$A000/$C000/$E000
FME7_Mirror ENT
               db    0           ; vertical, horizontal, one-screen 0/1

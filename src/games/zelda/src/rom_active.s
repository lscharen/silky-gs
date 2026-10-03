; This is the bank that is the "live" NES code.  Due to all of the different pieces of 
; memory that can be set from the different bank, we are coing to do the slow thing and
; copy the 16kb of ROM code into this bank when the MMC1 registers change.  Optimization can come later.

            mx    %11
SetMirrorMode  EXT
ROMBase ENT

; Pad up to $5000
            ds    $5000-*

            put   ../../../rom/rom_inject.s
            put   helpers.s

; These tables are not replicated.  They should remain in the ROMBase bank. They *MUST* come after the
; rom_inject and helpers files and be page-aligned.
;
; These tables are in NES RAM space for efficiency.  This specifically is to allow the use of the
; 65816 ldx abs,y and ldy abs,x instructions.  The core loop that scans the sprite OAM data is
; implemented as
;
; ldy    ROMBase+DIRECT_OAM_READ,x
; ldx    y_exclude,y
            ds \,$00

y_exclude ENT                     ; Table of excluded scanlines -- kept in NES RAM bank for efficiency
            ds 24,$01
            ds 200,$00
            ds 32,$01

tile_exclude ENT                  ; Tble of excluded tiles
            ds 256,$00

            use   BeginEndVars.inc
            use   CaveVars.inc
            use   CommonVars.inc
            use   ObjVars.inc
            use   Variables.inc

; Do not encroach on WRAM (battery-backed space)
            ds    $6000-*

; Pad up to $8000
            ds    $8000-*

;            ORG   $8000

; .SEGMENT "BANK_00_ISR"
            ds    $BF50-*

; .SEGMENT "BANK_00_VEC"


; Pad up to $C000 (matching the original NES fixed-bank boundary) before
; embedding Bank07's fixed content, so it starts at the same offset in
; every bank -- see the ORG $8000 comment above.
            ds    $C000-*

; Embedded copy of Bank07's fixed $C000-$FFFF code, so JSR/JMP into
; Bank07-exported routines resolve within this same physical bank.
; Z07_EMBED_BANK tells rom_07_fixed.s which bank-grouped EXT block to
; skip (this bank's own group, since it's defined locally here).
Z07_EMBED_BANK equ 7
            put   rom_07_fixed.s

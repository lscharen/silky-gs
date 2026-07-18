            mx    %11
            ds    $5000-*

            put   ../../../rom/rom_inject.s
            put   helpers.s

            use   BeginEndVars.inc
            use   CaveVars.inc
            use   CommonVars.inc
            use   ObjVars.inc
            use   Variables.inc

            ds    $8000-*

; Technically, there should be a copy of the rom_07_fixed.s file in the
; first 16kb of memory, but this bank is only swapped in during boot and
; the code only requires the code in the upper 16kb of memory.

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


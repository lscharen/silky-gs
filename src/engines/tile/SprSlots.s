; SprSlots.s -- the compiled sprite cache's slots, for the game's flags (as silky's ppu.s).  With the shifted variants: 2KB, 4
; variants of 512 bytes, 32 slots per bank in up to 4 banks.  Without them: 512 bytes, 2 variants of 256, 128 slots in one bank.
; SPR_TALL: a whole 8x16 sprite is one routine, its key in SPR16_COMP_TBL, and the slots are twice as big.  Its variants are at the
; slot's quarters (without SPR_PIXEL_SHIFT, its halves): as is, flipped horizontally, and with SPR_PIXEL_SHIFT both shifted.
        DO    SPR_PIXEL_SHIFT
SPR_SLOT_SIZE equ $0800*{1+SPR_TALL}
SPR_BANK_SLOTS equ 32/{1+SPR_TALL}
SPR_FLIP_PAGE equ 2
SPR16_FLIP_PAGE equ 4
SPR16_SHIFT_PAGE equ 8
        ELSE
SPR_SLOT_SIZE equ $0200*{1+SPR_TALL}
SPR_BANK_SLOTS equ 128/{1+SPR_TALL}
SPR_FLIP_PAGE equ 1
SPR16_FLIP_PAGE equ 2
        FIN

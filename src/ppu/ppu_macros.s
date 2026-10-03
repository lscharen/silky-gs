; ppu_macros.s - PPU Data and Helper Macros
;
; This file contains all macro definitions used by the PPU emulation layer
; that do NOT generate executable code.  It must be included (put) before
; any file that uses these macros.
;
; Contents:
;   - Data replication macros (const8, wconst8, const32, wconst32, rep8, wrep8)
;     These emit repeated copies of constant values into the data stream, used
;     for building lookup tables (y2idx, y2bits, etc.)
;
;   - Assertion macros (assert_lt, assert_x_lt)
;     Debug helpers that trigger a BRK if a value is out of range.
;
;   - Conditional store macro (cond)
;     Stores one of two values depending on a bit test result.
;
; Note: The WALK_BITMAP macro and its associated load macros (LOAD_CURRENT,
; LOAD_INV_CURRENT, LOAD_OTHERS, LOAD_INTERSECTION) are in scanline_bitmap.s
; because they generate executable 65816 code and branch labels.

; ---------------------------------------------------------------------------
; Data replication macros
; ---------------------------------------------------------------------------

const8  mac
        db    ]1,]1,]1,]1,]1,]1,]1,]1
        <<<

wconst8 mac
        dw    ]1,]1,]1,]1,]1,]1,]1,]1
        <<<

const32 mac
        const8 ]1
        const8 ]1+1
        const8 ]1+2
        const8 ]1+3
        <<<

wconst32 mac
        wconst8 ]1
        wconst8 ]1+1
        wconst8 ]1+2
        wconst8 ]1+3
        <<<

rep8    mac
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        <<<

wrep8    mac
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        dw     ]1
        <<<

; ---------------------------------------------------------------------------
; Assertion macros
; ---------------------------------------------------------------------------

assert_lt mac
        cmp ]1
        bcc ok
        brk ]2
ok
        <<<

assert_x_lt mac
        cpx ]1
        bcc ok
        brk ]2
ok
        <<<

; cond(]1, ]2, ]3, ]4): if the accumulator bit identified by ]1 is clear,
; store ]2 in location ]4, otherwise store ]3 in location ]4
cond    mac
        bit ]1
        beq cond_0
        lda ]3
        bra cond_s
cond_0  lda ]2
cond_s  sta ]4
        <<<

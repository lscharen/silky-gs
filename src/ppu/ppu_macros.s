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
;   - Compiled background tile macros (SET_COMPILED_TILE, CALL_COMPILED_TILE)

; ---------------------------------------------------------------------------
; Compiled background tiles
; ---------------------------------------------------------------------------
;
; CompileTile (core/tiles/CompileTile.s) compiles background tile n (0 - 511: the CHR tile number, pattern
; table $1000 = 256 - 511) into the 128-byte slot at n * 128 of the compile bank -- the same offset as
; the tile's data in the tiledata bank.  A compiled tile stores every word of the tile into the code
; field except word 0, whose value it leaves in A: the caller's CALL_COMPILED_TILE stores it.  That
; keeps the worst case (16 distinct, non-zero words) at 126 bytes.
;
; Call sites are a patched jsl: PPUStartUp puts the compile bank into its bank byte, and
; SET_COMPILED_TILE points it at a tile before each call.

; Point the CALL_COMPILED_TILE at ]1 at the background tile in A (8-bit; the tile ID, in the pattern
; table bgadr selects): ]1+1 / ]1+2 = tile * 128 | bgadr_hi.  8-bit A, DBR = K; A is trashed.
SET_COMPILED_TILE mac
        lsr                           ; A = tile ID >> 1, C = tile ID bit 0
        ora   bgadr_hi+1              ; + $80 for pattern table $1000 (tiles 256 - 511)
        sta   ]1+2                    ; the address' high byte
        lda   #0
        ror                           ; tile ID bit 0 -> bit 7
        sta   ]1+1                    ; the address' low byte
        <<<

; The same with 16-bit A, the tile ID in its high byte (the low byte can be anything: e.g. a 16-bit
; load from the byte before the tile ID).  Leaves A = the slot address (tile * 128 | bgadr_hi), DBR = K.
SET_COMPILED_TILE_HI mac
        lsr                           ; tile ID * 128 + (low byte >> 1)
        and   #$FF80
        ora   bgadr_hi                ; + $8000 for pattern table $1000 (tiles 256 - 511)
        sta   ]1+1
        <<<

; Call the compiled tile set by SET_COMPILED_TILE (label this line: it is the jsl to patch).
; X = the tile's address in the code field, DBR = the code field bank, 16-bit A, C = 0.
CALL_COMPILED_TILE mac
        jsl   $000000                 ; (patched) the tile's code, which leaves word 0's value in A
        sta:  $0004,x                 ; word 0 (see CompileTile: :word_addr)
        <<<

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

; Count a compiled sprite cache event (SPR_CACHE_STATS, Defs.s): a 32-bit counter at PPU_MEM+SPR_STATS+]1.
; 16-bit A, which is trashed (and the flags); any data bank.  Nothing is assembled without the stats.
SPR_STAT mac
        DO    SPR_CACHE_STATS
        ldal  PPU_MEM+SPR_STATS+]1
        inc
        stal  PPU_MEM+SPR_STATS+]1
        bne   *+11
        ldal  PPU_MEM+SPR_STATS+]1+2
        inc
        stal  PPU_MEM+SPR_STATS+]1+2
        FIN
        <<<

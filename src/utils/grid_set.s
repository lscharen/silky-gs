*=================================================
* GridSet -- a concrete sparse set (see sparse_set.s) sized for a
* fixed grid overlaid on the playfield, used to track which grid
* cells the current and previous frame's sprites intersect (see NES
* pixel -> grid-cell mapping to be added alongside the dirty-
* rendering integration).
*
* Sized for Zelda's 256x200 playfield at 8x8 cells: 32 columns x 25
* rows = 800 cells. A game with a differently-sized playfield should
* define its own GRID_COLS/GRID_ROWS/GridSet storage rather than
* reuse this instance as-is; GridSetIsMember/GridSetCondAdd below are
* plain subroutines hardcoded to this GridSet (see sparse_set.s's
* header comment for why membership testing isn't a reusable macro),
* so a second instance needs its own copies of those two as well,
* renamed and re-pointed at its own storage/length.
*
* Requires sparse_set.s (SS_CLEAR/SS_ADD macros, ssScratch) to be
* assembled first -- see src/utils/_module.txt.
*-------------------------------------------------
GRID_COLS      equ   32
GRID_ROWS      equ   25
GRID_LEN       equ   800                      ; GRID_COLS*GRID_ROWS -- see note below

* GRID_LEN is spelled out as a literal, not GRID_COLS*GRID_ROWS, because
* Merlin32 does not reliably resolve a multi-level equ expression when it
* is substituted as a macro argument and re-used inside the macro body's
* own arithmetic (]2 appears inside "2*]2" in SS_ADD). Keep GRID_LEN in
* sync with GRID_COLS*GRID_ROWS by hand if either changes.

GridSet        ds    2+{GRID_LEN*4}           ; n + dense[GRID_LEN] + sparse[GRID_LEN]

        mx    %00
GridSetClear
        SS_CLEAR    GridSet
        rts

        mx    %00
GridSetAdd
        SS_ADD      GridSet;GRID_LEN
        rts

*-------------------------------------------------
* GridSetIsMember
*
* In:  X = index (0..GRID_LEN-1) to test
* Out: carry clear = member, carry set = not a member
* Clobbers: A, X, Y, ssScratch
*-------------------------------------------------
        mx    %00
GridSetIsMember
        stx   ssScratch             ; remember the index
        txa
        asl                         ; a = index*2 (sparse byte offset)
        tax
        ldy   GridSet+2+{2*GRID_LEN},x   ; y = sparse[index] (garbage if never written)
        cpy   GridSet               ; sparse[index] < n ?
        bcs   :notmember            ; no -- stale slot, definitely not a member

        tya
        asl                         ; a = sparse[index]*2 (dense byte offset)
        tax
        lda   GridSet+2,x           ; a = dense[sparse[index]]
        cmp   ssScratch             ; does it round-trip back to index?
        bne   :notmember

        clc
        bra   :done
:notmember
        sec
:done
        rts

*-------------------------------------------------
* GridSetCondAdd
*
* In:  X = index (0..GRID_LEN-1) to add
* Clobbers: A, X, Y, ssScratch
*
* Adds X to the set only if it is not already a member -- the safe,
* idempotent entry point for callers (like grid-cell tracking) where
* the same index can legitimately be touched more than once per
* frame.
*-------------------------------------------------
        mx    %00
GridSetCondAdd
        stx   ssScratch             ; GridSetIsMember clobbers X; keep the index
        jsr   GridSetIsMember
        bcc   :already
        ldx   ssScratch
        SS_ADD GridSet;GRID_LEN
:already
        rts

*=================================================
* Sparse Set
*
* Implements the "sparse set" data structure described at
* https://research.swtch.com/sparse -- a set of small integers
* (0..length-1) supporting O(1) add, O(1) membership test, and
* O(1) clear, at the cost of using more memory than a bitset and
* never actually zeroing that memory.
*
* Memory layout at base ]1, given a fixed ]2 (length, in elements):
*
*   base+0                    n         (1 word) -- number of members
*   base+2                    dense[0]  (length words)
*   base+2+2*length           sparse[0] (length words)
*
* dense holds the members currently in the set, in insertion order;
* only the first n entries are valid/meaningful. sparse maps a member
* value back to its slot in dense. Slots in sparse that were never
* written hold garbage, but that's harmless: is-member always double
* checks a candidate slot with dense[sparse[i]] == i before trusting
* it, so a stale/garbage sparse entry just fails that check instead
* of ever being read as ground truth.
*
* Every element (index, n, and each dense/sparse slot) is a full
* 16-bit word, since the intended use (an 800-cell playfield grid)
* exceeds 8-bit range. All code on this page assumes native mode
* with 16-bit A/M and 16-bit X/Y (MX=%00).

*-------------------------------------------------
* SS_CLEAR base
*
* Empties the set. O(1) -- just resets n to 0.
*-------------------------------------------------
SS_CLEAR    MAC                        ;]1=base
            stz       ]1
            <<<

*-------------------------------------------------
* SS_COUNT base
*
* Returns the number of elements in the set.
* O(1) -- just resets n to 0.
*-------------------------------------------------
SS_COUNT    MAC
            lda       ]1
            lsr
            <<<

*-------------------------------------------------
* SS_ADD base;length
*
* In:  A = index (0..length-1) to add. Pre-multiplied by 2.
* Clobbers: A, X, Y
*
* Adds A to the set unconditionally -- does NOT check whether it is
* already a member. Calling this twice for the same index inserts a
* duplicate entry into dense (harmless for iteration-only use, but
* wastes a slot and, if repeated enough, can overflow dense/sparse
* past `length`).
*
* This should typically *not* be used by external callers and is
* primarily an internal routine.
*
* add-member(i):
*    dense[n] = i
*    sparse[i] = n
*    n++
*-------------------------------------------------
SS_ADD      MAC
            ldy       ]1               ; load the number of elements, n * 2
            sta       ]1+2,y           ; dense[n] = index
            tax
            tya
            sta       ]1+2+{2*]2},x    ; sparse[index] = n
            inc
            inc
            sta       ]1               ; n++
            <<<

*-------------------------------------------------
* SS_ISMEMBER base
*
* Returns the number of elements in the set.
* O(1) -- just resets n to 0.
*-------------------------------------------------
SS_ISMEMBER MAC
            asl
            tax
            ldy       ]1+2+{2*]2},x    ; sparse[i]
            cpy       ]1               ; is sparse[i] < n ?
            bcs       out              ; no, return with carry set
            eor       ]1+2,y           ; dense[sparse[i]] == i?
            cmp       #1               ; EOR is zero iff A == B, so CMP #1 sets the carry flag if they are different and clears it if the are equal
out
            <<<

*-------------------------------------------------
* SS_CONDADD bas
*
* Conditionally adds a value to the sparse set if
* it does not exist.
*-------------------------------------------------
SS_CONDADD  MAC
            asl
            tax
            ldy       ]1+2+{2*]2},x    ; sparse[i]
            cpy       ]1               ; is sparse[i] < n ?
            bcs       out              ; no, return with carry set
            cmp       ]1+2,y           ; dense[sparse[i]] == i?
            bne       out

            ldy       ]1               ; load the number of elements, n * 2
            sta       ]1+2,y           ; dense[n] = index
;            tax
            tya
            sta       ]1+2+{2*]2},x    ; sparse[index] = n

            inc
            inc
            sta       ]1               ; n++
out
            <<<

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

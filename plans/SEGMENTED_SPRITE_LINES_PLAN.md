# Segmented Sprite Lines: span-only shadow-off pass + in-field span exposure ("s_exit")

## Status (2026-10-08): implemented, measured slower, reverted

Version B was built in full: S exits above and below the PEA run, per-row s_exit stubs, a shared PEI
chain, the span passes, and PEISlammer.s removed.  Spans were word-aligned.  The screens matched
(Zelda bench hashes), but it was slower: Zelda +1.26M cycles, SMB +6.2M, even after cutting the per-band
overhead (3 patch passes instead of 5, edge thresholds for the entry/exit patches, an unrolled stack
patch, a BRA chain cut).

Measured per Zelda full render (437 of them), HEAD vs the span build: shadow-off pass 6,858 vs 6,718
cycles, expose 61,474 vs 64,348.  Why:

- **Few sprite lines.**  SMB averages about 1.1 bands and 23 band lines per frame, Zelda about 1.2 bands
  and 18 lines; 81% of SMB's band lines have spans under 8 words.  The cost model below assumed about
  80 sprite lines per frame.
- **The expose can't gain.**  The PEI slam already uses aligned 6-cycle PEIs, about the cost of the
  PEAs it replaces, so all the saving has to come from the shadow-off pass: at most 5-7K per frame.
- **The patching costs as much as it saves.**  Saving, patching and restoring the PEA field per band
  measured about 10K, and still 2-3K after the optimizations.

Revisit only with a low-overhead way to segment the existing PEA field.


Revisit after the full-frame overhead work (aligned PEI slam, cached stack patch, hoisted per-call
setup) is in and measured.  The cycle numbers below are counted from the instruction timings, not
measured.

## Problem

On a full render (any scrolling frame), a line with sprites costs about twice as much as a line without:

| Line | Work | Cycles (64-word NES width) |
|---|---|---|
| No sprites | PEA with shadowing on | ~346 (64 x 5 + ~26 entry / wrap / exit) |
| Sprites | PEA with shadowing off, draw sprites, PEI slam the whole line | ~346 + ~479 (64 x 7 + ~31) = ~825 |

(Both on top of the ~57 cycles per line of code field patching every full-frame line pays.)

Every word of a sprite line is written twice: once by the shadow-off PEA, which puts the background
in bank $01 under the sprites, and once by the PEI slam, which copies it to the screen.  Only the
words under the sprites need the shadow-off copy.  A scrolling game with ~80 sprite lines spends
~38k cycles per frame on sprite lines beyond what plain lines would cost.

Per word, the shadow-on write itself is about the same cost either way (PEA 5, PEI 6-7), so skipping
shadowing on a part of the line saves little by itself.  **The saving comes from not drawing the
words outside the sprites twice.**

## Ruled out

- **Replacing the PEA field with two 32KB SHR buffers.**  Every method writes the same 16,000 words
  per full frame.  PEA (5 cycles: 3 fetch + 2 write) is within ~25% of the floor (PHA, 4, with a
  loaded register).  The only fast buffer copy, PEI (6), needs its source on the direct page, i.e.
  bank $00/$01 through RAMRD, and bank $01 has ~15KB free outside $2000-$9FFF against ~30KB per
  nametable.  lda/sta copies are ~10+ cycles per word.
- **Splitting each line into runs, dispatched line by line.**  The per-line dispatch into and out of
  the code field costs more than it saves.  Patch per band, not per line (below).
- **Three segments with a PEI on the span** (shadow off: PEA the span and draw the sprites; shadow on:
  PEA the left and right segments, PEI the span).  It's about as fast as the design below, but inside
  a band the span's columns keep the old frame for longer than the columns around them: a visible
  rectangle of stale background around the sprites.

## Design

One span per band: the union of the X extents of the sprites in a band of the shadow list, with the
gaps between sprites merged in.  The span is a min/max pair gathered while scanning OAM, rounded out
to a multiple of 4 words.  A band whose span is too wide (see the break-even below) takes today's path.

1. **Shadow off, sprite bands only: blit just the span.**  This is a narrow viewport blit with the
   existing machinery (entry BRL and stack `ldx` for the span's right edge, exit BRA at its left
   edge, save / restore of the exit operand).  It may overdraw a few bytes past the span (e.g. word
   alignment), since the expose pass rewrites them with the same background.  Do it before the
   full-frame `_BltSetupAlt`, so the full setup overwrites the entry / stack patches and only the
   span's exit operand needs restoring.
2. **Draw the sprites** (shadow still off), as now.
3. **Shadow on: one pass, top to bottom.**  Sprite lines run the normal full-width PEA line, but a
   patched branch at the span's rightmost word jumps to the row's **s_exit**, which exposes the span
   (copies its words from bank $01 back to the same addresses with shadowing on) and resumes at the
   word left of the span.  Lines without sprites are unchanged.  No stale blocks: every line is
   finished before the next one starts.

The top-level structure stays as it is: sprite vs. non-sprite lines, one exposure wipe.

### s_exit, version A: inline copy loop (~16 + 11.75 cycles per word)

S is the pointer.  Long indexed addresses carry into the bank byte, so with X = S, `ldal $00FFFF,x`
reads $01:(S-1), exactly the word the next `pha` writes back.  No per-line source address and no
`dex` chains:

```
s_exit  rep  #$20            ; M only -- V (mirroring) is untouched
        ldy  #count          ; span / 4 words, constant per band
:loop   tsx
        ldal $00FFFF,x
        pha
        ldal $00FFFD,x
        pha
        ldal $00FFFB,x
        pha
        ldal $00FFF9,x
        pha
        dey
        bne  :loop
        sep  #$20            ; the odd-edge code needs 8-bit A
        brl  resume          ; relative: one patch value for every row
```

- Flags: `rep`/`sep #$20` touch only M; `tsx`/`ldal`/`dey` only N and Z.  The V invariant holds.
- Space: ~31 bytes.  Each row's P1 $00-$20 is unused (33 bytes); `sep`/`brl` can go to the free bytes
  at P1 $F9-$FF if needed.
- Byte-exact for odd alignment: the loop copies exactly the bytes the skipped PEAs would have pushed.
- Comparison: `ldx #count / ldal $01xxxx,x / pha / ... / dex x4 / bpl` is 14.75-15.5 cycles per word
  and needs a per-line source address.

### s_exit, version B: shared PEI block (~45 + 6.5 cycles per word)

- Per-row stub (~18 bytes, in P1 $00-$20): `ldx #<resume word>`, `pea #spanD / pld`, switch the state
  register to R1W1 (read bank 1), `jmp` into a shared unrolled PEI block.  The entry point depends on
  the span width, so it is patched once per band.
- The shared block (one per blitter bank; $F100-$FFFF is free, ~3.8KB) ends with: state register
  back to the blit mode, D restored, `jmp ($0000,x)` through the stub's resume word.
- `_PEISlam` already toggles the state register this way.
- Anything in the code field that reads the direct page (the `STATE_REG_*` loads, `STK_SAVE` in the
  interrupt window) must use immediate operands patched at startup, since D is moved.
- Faster than A for spans over ~6 words.

### Open issues

- **Branch reach.**  A BRA at the span can't reach P1+$00 from P0 columns below ~$7F, and P0 has no
  free space for a trampoline.  Patch a BRL (3 bytes, over the whole PEA) instead.  Restore = $F4 +
  the saved operand.  ~42 cycles per line of setup instead of ~30 for a BRA.
- **Edges.**  A span reaching the left edge collides with the exit BRA; one starting at the right
  edge could have the entry BRL go straight to the stub.  Simplest: keep the outermost word on each
  side out of the span, or use today's path for that band.
- **Per-band setup.**  Span pass (entry, stack, exit) + s_exit (BRL, count, resume, and for B the D
  value and the PEI entry): ~300 cycles per band.  Negligible for bands of 8+ lines.
- **Interactions.**  `CTRL_EVEN_RENDER`, `clipShadowList` for split-screen ranges (Zelda, SMB's status
  bar), and `drawScreenRange` used by the grid renderer to record sprite cells.

## Cost model (per sprite line, 64-word NES width, beyond the ~57-cycle full-frame setup; W = span in words)

| Approach | W=8 | W=16 | W=24 | Stale blocks |
|---|---|---|---|---|
| Today (PEA shadow off + PEI 64 x 7) | 825 | 825 | 825 | no |
| Aligned PEI slam | ~746 | ~746 | ~746 | no |
| s_exit loop, full-width shadow-off pass | 804 | 858 | 912 | no |
| 3 segments + PEI on the span | 599 | 655 | 711 | yes |
| **Span shadow-off pass + s_exit loop (A)** | 584 | 678 | 772 | no |
| **Span shadow-off pass + PEI s_exit (B)** | 571 | 623 | 675 | no |

- A stops beating the aligned PEI slam at about W = 22 words; B at about W = 33.  Fall back per band
  with one compare.
- At 80 sprite lines and spans of 8-16 words: ~12-20k cycles per scrolling frame, against ~6k for the
  aligned PEI slam alone.

## Validation plan

- Count span widths per band over an SMB run first (a few counters) to confirm typical W is well under
  the break-even.
- Screen hashes (`gs2-bench-run.js --shots`) against the current build for Zelda; the same for a
  continuously scrolling game (SMB).
- Build all games.

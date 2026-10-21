# Joystick input without spinning: PEA-line probes + a timestamp fallback

## Goal

Read the Apple II game-port joystick (PDL0 = X at `$C064`, PDL1 = Y at `$C065`, triggered by `$C070`)
as a digital pad: per axis, **centered or not** (and which side), without the classic "strobe and count
until bit 7 drops" spin, which costs up to about 3 ms per read.

Only "not centered" matters, so the reading needs to resolve the timer duration T only around the two
dead-zone edges near the center (about 1.0 and 1.8 ms on a typical stick), not over the full travel
(0 - 3 ms). Truncating the measurement window just past the right edge is fine.

Two mechanisms, one classifier:

1. **PEA probes** (full renders): short runs of PEA rows get their exits hooked into probe code. The
   first row of a run strobes the paddles, each following row samples bit 7 of both paddles. Each PEA
   row takes a fixed time, so the number of rows the bit stayed high is T in row units. This keeps the
   joystick responsive at the blitter's stack speed.
2. **Timestamp poller** (dirty renders, and full renders where no probe run completed): strobe once, then
   at cheap poll points inside the renderer, read the paddle bits together with the video vertical
   counter.

Both give, per axis, an interval `[lo, hi)` that holds T. A sample counts only if that interval lies
entirely on one side of a threshold.

**Time base: the video vertical counter.** `VBL_VERT_REG` (`$E0C02E`, already in `Defs.s`) is bits 8-1 of
the 9-bit vertical counter. One step is 2 scanlines (127 us). It reads `$7D-$FF`, 131 steps per 16.7 ms
frame, with `d = b - a; if d < 0: d += 131`. It does not depend on CPU speed. The calibration measures
T in these units, and each probe run measures its own row time in these units. Accelerators, the FAST
BLIT mode and shadow-on vs. shadow-off passes then need no special handling.

**The counter wraps every 16.7 ms.** An elapsed time is only right if less than one frame passed. The two
kinds of observation behave differently:

- **"Bit high at elapsed e" means T > e.** If the counter wrapped, the true elapsed is e + 131k, which is
  more than e, so the statement still holds (it is just weaker). These observations are always safe.
- **"Bit low at elapsed e" means T <= e.** If the counter wrapped, this is false. These observations are
  trusted only if the time between the strobe and the poll is known to be under one frame.

The probe runs satisfy this by construction: a run is about 2 ms, with interrupts off and in one piece.
The poller satisfies it by the rules in section 2.

## 1. PEA probes

### Constraints

- **Interrupts are off** in the code field except at the interrupt windows. `_InitLiteBlitter`
  (`core/CoreImpl.s`) sends the exits of rows 4, 20, 36, 52, 68, 84 and 100 of each bank to the next row's
  `$00` window, so windows open at the start of rows 5, 21, 37, ... A run between two windows is never
  interrupted, so every interval is exactly one row's time.
- **Writes**: the blitter runs with `STATE_REG_BLIT` (RAMWRT on), so writes to bank `$00` (the direct page
  included) go to bank `$01`. Probe code doesn't write the direct page. It stores with absolute writes
  through DBR, which is the blitter bank itself (set by `_BltRangeLiteBody`, and by `lite_bank_entry_2`
  for bank 2). I/O goes through bank `$E0` (`ldal $E0C064`).
- **No JSR**: the stack is the screen.
- **Free registers at a row exit**: A (8-bit) and X are reloaded by the next row's entry. **Y is never used
  by the code field**, so it can carry state from row to row within one `_BltRangeLite` call.
- **Code space**: the odd page (P1) of every row has `$00-$20` free (33 bytes, see `TemplateLite.Macs.s`).
  Nothing executes or patches it. Each hooked row's probe goes there, inline, ending in one `jmp`.
- **Data space**: each blitter bank has free bytes between the entry stub (`$0004`) and `$0100` (now a
  `ds \,$00` pad). A fixed `JOY_DATA` block is reserved there at the same offset in both banks, so the
  same probe code works in either bank.

### Runs: two per blitter bank

| run | bank | strobe row (exit) | probe rows (exits)  | global PEA rows |
|-----|------|-------------------|---------------------|-----------------|
| 0   | 1    | 5                 | 6 .. 5+N            | 5 .. 5+N        |
| 1   | 1    | 53                | 54 .. 53+N          | 53 .. 53+N      |
| 2   | 2    | 5                 | 6 .. 5+N            | 125 .. 125+N    |
| 3   | 2    | 53                | 54 .. 53+N          | 173 .. 173+N    |

- **N = `JOY_PROBES`.** The window only has to reach the right-hand dead-zone edge, plus one row. With
  shadowing on, a row is about 200-250 us (an estimate: 64 PEAs with two shadowed writes each), so
  **N = 8 covers about 1.6-2.0 ms and N = 10 covers about 2.0-2.5 ms**. Start with 10, which costs little
  more, leaves margin for a stick whose center sits high, and fits between windows (up to 15). The
  calibration screen shows whether the right edge is inside the window (section 4).
- **The thresholds can fall in any bin.** A probe count `c` means T is in `[c*L, (c+1)*L)`, where L is
  the row time. Left is "T < thrL" and right is "T > thrR", wherever those fall: thrL is typically around
  bin 4-5, and thrR around bin 7-8. "Right" is c >= ceil(thrR / L), which includes the saturated
  `c = N` only because the window is truncated just past thrR. It is not "the last bin means right".
- **Shadow-off rows are faster.** `drawShadowList` blits the sprite lines with shadowing off, at about
  half the row time, so a run in that pass covers about 1 ms. That still decides "left". "Center" and
  "right" come out inconclusive there, and the classifier takes them from another run.
- **Coverage**: a render draws 200 of the 240 rows (a band that wraps mod 240). The 40 rows left out
  can clip at most two runs, so a plain full render completes at least two. Runs cut by range boundaries
  (sprite runs, split screens) are discarded by the guard below. If no run completes, the poller covers
  that render.
- **CTRL_EVEN_RENDER** (FAST BLIT): only even rows run, and a window comes every 8 executed rows. The
  installer hooks the executed rows: strobe at row 6, probes at 8, 10, ..., 20 (`JOY_PROBES_EVEN = 7`,
  about 1.6 ms). That is borderline for the right edge, so right in FAST BLIT may come from the poller.

### Probe code (8-bit A, 16-bit X/Y; `JD` = `JOY_DATA` + 4 * slot, slot = run index within the bank)

Strobe row (20 bytes):

```
        ldal  $E0C070          ; trigger both paddle timers
        stz   JD+0             ; cntX
        stz   JD+1             ; cntY
        ldal  VBL_VERT_REG
        sta   JD+2             ; t0
        ldy   #JOY_TOKEN       ; this range executed the strobe
        jmp   <next>           ; operand at P1+$1F: the row's original exit target
```

Probe rows 1 .. N-1 (18 bytes + jmp):

```
        ldal  $E0C064 / bpl *+5 / inc JD+0    ; still timing: count it
        ldal  $E0C065 / bpl *+5 / inc JD+1
        jmp   <next>
```

Final probe row (30 bytes + jmp, exactly the 33 available):

```
        ldal  $E0C064 / bpl *+5 / inc JD+0
        ldal  $E0C065 / bpl *+5 / inc JD+1
        cpy   #JOY_TOKEN
        bne   :skip            ; the strobe was not in this range: don't publish
        ldal  VBL_VERT_REG
        sta   JD+3             ; t1 (never 0: the counter is $7D-$FF)
:skip   jmp   <next>
```

- **Guard**: `_BltRangeLiteBody` does `ldy #0` before its `jml` into the code field. Y holds `JOY_TOKEN`
  only if this same contiguous, interrupt-free range ran the strobe row. One token value serves all runs,
  because runs don't overlap and a strobe always runs before its final row (wrap included).
- **Counter meaning**: the timer's output drops once and stays low, so `c` is the number of probes that
  saw the bit high. No "first transition" logic is needed.
- **Cost**: two slow I/O reads plus about 15 cycles per probe row, about 5 us. That is about 55 us per
  run at N = 10 and about 0.25 ms per full render (well under 1%).

### Installation (`_JoyInstallProbes`, at the end of `_InitLiteBlitter`)

`_InitLiteBlitter` already rewrites every exit when the render mode changes, and `ApplyConfig` calls it.
When any player uses JOYSTICK, after the window patching, for every hooked row in both banks:

1. Copy the template (strobe / probe / final, assembled in ENGINE; `JD` operands patched per slot) into
   the row's `P1+$00`.
2. Move the row's current exit target (`_E_JMP_OFFSET+1`) into the template's trailing `jmp` (`P1+$1F`).
3. Point both row exits (`_E_JMP_OFFSET+1`, `_O_JMP_OFFSET+1`) at `P1+$00`.

With no joystick configured nothing is installed, so the renderer costs exactly what it does today.
`_BltRangeLiteBody`'s last-line patch saves and restores whatever operand is there, so it needs no
change. The last row of a range returns without running its probe, which only means that run doesn't
publish.

### Harvest (`JoyHarvest`, end of `RenderDraw` in `ppu/ppu_frame.s`)

For each of the 4 slots, read long from both banks. If `t1 != 0` the sample is valid, with
`E = t1 - t0 (mod 131)` the run's measured time (the row time is E/N). Clear `t1`. Compare in scaled
units so there is no division: `loN = c*E`, `hiN = (c+1)*E`, against `thrL*N` and `thrR*N` (precomputed
by `ApplyConfig` for N and N_even). The products are small (c <= 15, E <= about 40), so a 4-step
shift-add does it.

## 2. Timestamp poller (dirty renders; full renders with no completed run)

The poller has to respect the wrap rule from the Goal section: a "bit low" observation is trusted only if
the time between the strobe and the poll is known to be under one frame. Polls can't measure their own
spacing, so the poller only exists in code whose poll spacing is bounded:

- **Lifetime: one render.** It is armed in `RenderDraw` (at the start of `gridDrawDirty`, or after a
  full render's harvest left an axis undecided) and disarmed unconditionally at the end of `RenderDraw`.
  It never runs in the event loop, the interrupt handler or `NES_PollInput`. Their spacing isn't
  bounded: the GS task can be suspended for a whole NES frame.
- **Disarmed at the GS→NES task switch** (one place in the scheduler), so being suspended in the middle of
  a render ends that cycle.
- **Disarmed on `_BltRangeLite` entry**: the probe runs are about to retrigger the timers.
- **Expires** when `e >= JOY_WINDOW` (just past thrR, the end of the useful window).
- **Poll sites only in dense loops**, a few hundred microseconds apart at most: once per grid row in
  `gridDrawDirty`'s erase and expose passes, once per sprite record, and `_PEISlam`'s 8-line wrap
  (`peiWrap0`). Interrupt handlers that run between two polls are short (well under a frame), so the
  spacing stays far below the 16.7 ms wrap.

Inside those limits every poll sees e = the true elapsed time, and both kinds of observation can be used.
If the render ends before an axis is decided (a short dirty render), the axis keeps its previous state
for that render. A cheap dirty render is followed quickly by the next one, which tries again.

### State (MAIN, long-addressed)

`jfArmed`, `jfT0`, `jfLoX/jfHiX/jfLoY/jfHiY` (elapsed units), and the decided flags per axis.

### Arm (`JoyFallbackArm`)

- **Don't retrigger a running timer.** Strobe only if bit 7 of both `$C064` and `$C065` is low. The
  558's timers aren't restarted by a trigger while active, so a strobe then would give a short reading.
  If either bit is high, the arm is skipped for this render. Since probe strobes are at least one render
  apart, this is rare.
- Strobe, `jfT0 = VERTCNT`, `lo = 0`, `hi = inf`, `jfArmed = 1`.

### Poll (`JOY_POLL` macro, or `jsl JoyPollL`)

```
        ldal  jfArmed / beq :out              ; disarmed: 2 instructions
        e = VERTCNT - jfT0 (mod 131); if e >= JOY_WINDOW: jfArmed = 0, out
        each undecided axis: bit 7 high -> lo = max(lo, e); low -> hi = min(hi, e)
        if both axes are decided: jfArmed = 0
```

It uses long addressing and 8-bit A, and saves and restores P. That makes it safe with any DBR, D or
stack setting (the grid renderer's DBR = `$01` passes, the PEI slammer's chunks). Disarmed cost is about
8 cycles; armed, about 50 plus two slow reads.

## 3. Classifier and output

Thresholds per axis: `thrL = c - dzL`, `thrR = c + dzR` (section 4). Per sample:

- **left (up)**: `hi <= thrL`
- **right (down)**: `lo >= thrR`
- **centered**: `lo >= thrL && hi <= thrR`
- **inconclusive**: otherwise. The interval straddles an edge, or a short window saturated below thrR.

Take the first conclusive sample of the render: PEA slots in order, then the poller. Keep the previous
state while samples are inconclusive.

- **Hysteresis** (phase 2, only if edge chatter shows up): leaving a direction needs the reading back
  inside a slightly smaller dead zone.
- **Not connected**: an open paddle input never times out. A run with `c = N` on both axes for many
  renders in a row, while calibration says the center is well inside the window, means no stick. Report
  centered and set `joyMissing` (shown on the calibration screen).
- **Output**: the result goes to `joyPad` (MAIN, PAD direction bits). `_ReadJoystick1/2` in
  `_ReadControl` takes the directions from `joyPad`, A and B from bit 7 of `$C061` / `$C062` (buttons
  0 and 1, wired together with the Apple keys), and Start and Select from the keyboard map.

## 4. Calibration

Calibration runs on the configuration screen, where spinning is fine. It uses the same time base, so its
values hold at any CPU speed and in any render mode. Only "not centered" matters, so **the center is the
one value that must be measured**.

### UI

`INPUT_TYPE_OPT_2 'JOYSTICK'` already exists; add it as an INPUT TYPE option with a conditional list:

- **`CALIBRATE`**: a new `ACTION` control type (9) in `rom_config.s`. Return calls the routine in the
  control's value word, and it is drawn like `TEXT`.
- **`SENSITIVITY 1-7`**: the existing `NUMBER_SELECT` control, setting the dead-zone width.
- **A live readout** (`X: L C R  Y: U C D`, plus `NO JOYSTICK` or `RIGHT EDGE OUT OF RANGE`), refreshed
  while the screen is up.

### `JoyCalibrate` (MAIN)

1. "CENTER THE STICK AND PRESS A BUTTON." Wait for a button (`$C061` / `$C062`) or Return through
   `_ReadRawKeypress`, never the input driver, as the config screen does today. Take 16 measurements
   with `JoyMeasure` and average them into `cx`, `cy` in units x 16 (the counter phase at the strobe is
   random, so averaging gives sub-unit resolution).
2. **Optional**, if the user keeps going: "PUSH TO EACH CORNER, PRESS A BUTTON" gives `minx/miny/maxx/maxy`,
   so the dead zone can follow each stick's travel. When skipped, the dead zone is a fixed time from
   SENSITIVITY: about `(8 - s) * 0.5` units, so s = 4 gives ±2 units, about ±250 us.
3. **`JoyMeasure`**, with interrupts off: wait until both bits are low (timeout 8 ms means `NO JOYSTICK`).
   Then strobe, take `t0 = VERTCNT`, and spin reading `$C064`, `$C065` and VERTCNT, latching the elapsed
   time when each bit drops (timeout 8 ms). It is always well under one frame, so the wrap doesn't matter.
4. **Store** `cx, cy` (and the extremes, if taken) in the config reserve. A value of 0 means not
   calibrated, so older preferences files keep loading. Without a calibration, use the nominal center of
   a 150 kOhm IIgs stick, about 1.4 ms (11 units).

### Applied (`ApplyConfig`, and at start-up after `LoadPrefData`)

- Compute `thrL`, `thrR`, and `thrL*N`, `thrR*N` for N and N_even.
- Compute `JOY_WINDOW = thrR + 2 units`.
- **Coverage check**, shown on the calibration screen: thrR must be under the probe window. The window
  is the run time E last measured by `JoyHarvest` (shadow-on) or by a short calibration blit. If not,
  show `RIGHT EDGE OUT OF RANGE`. Right then comes only from the poller, or the user lowers sensitivity.
  N is a build constant; raising it to 12 is the fix if real sticks need it.

## 5. Files

| File | Change |
|---|---|
| `core/Defs.s` | `JOY_DATA`, `_JOY_CODE_OFFSET` (P1+$00), `_JOY_JMP_OFFSET` (P1+$1E), `JOY_TOKEN`, `JOY_PROBES(_EVEN)`, run rows |
| `core/blitter/TemplateLiteBank1.s`, `TemplateLiteBank2.s` | reserve `JOY_DATA` (ENT label for the harvest) |
| `core/blitter/BlitterLite.s` | `ldy #0` before the `jml`; clear `jfArmed` in `_BltRangeLite` |
| `core/CoreImpl.s` | `_JoyInstallProbes` after the window patching; templates; `_ReadJoystick1/2` |
| `ppu/ppu_frame.s` | `JoyHarvest`, the conditional `JoyFallbackArm`, and the unconditional disarm at the end of `RenderDraw` |
| `ppu/ppu_grid_quads.s`, `core/blitter/PEISlammer.s` | `JOY_POLL` at the poll sites |
| `rom/scaffold.s` | disarm at the GS→NES task switch |
| `rom/rom_joystick.s` (new, MAIN) | poller state, classifier, `JoyMeasure`, `JoyCalibrate` |
| `rom/rom_config.s`, `rom_config_setup.s` | `ACTION` control, JOYSTICK option and list, calibration and sensitivity values from the reserve |

All of it is behind `JOYSTICK_SUPPORT equ 0/1` in each game's `Config.s`.

**Input type value**: JOYSTICK would be type 4. The `_FixPrefInputTypes` migration from the J13 change
maps an old type 4 to KEYBOARD + J13; drop that branch-only migration when JOYSTICK lands.

## 6. Verification

- `code-signature compare` with `JOYSTICK_SUPPORT 0`: only `_BltRangeLiteBody` (`ldy #0`) and
  `_BltRangeLite` (the disarm) change.
- GSSquared with a watch on `JOY_DATA`: record E per run in the shadow-on and shadow-off passes, to
  replace the row-time estimates above with measurements, and check `c` against `JoyMeasure` with the
  stick held.
- Force dirty-only rendering and check that the poller decides both axes in most renders, and that
  holding the stick off-center never reads centered after a task switch (the wrap rule).
- SMB attract-demo cycle bench with a joystick configured: expect under 1% more cycles.
- Real hardware, with a ZipGS toggled: the calibration stays valid.

## Open questions

1. N = 10 vs. 8: settle it after measuring E on GSSquared and real hardware.
2. A second joystick (PDL2/PDL3) doesn't fit in the 33 bytes per row. It would need two hooked rows per
   interval, or the final row's publish moved elsewhere.
3. Whether short dirty renders leave axes undecided too often. If they do, the fix is a few more poll
   sites inside `RenderDraw` (still inside the bounded lifetime), not polls outside the render.

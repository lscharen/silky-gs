# Joystick input without spinning

The code is `src/core/blitter/JoyProbes.s`. Its constants are in `src/core/Defs.s` (`JOY_*`).

## Goal

Read the Apple II game-port joystick as a digital pad. PDL0 = X is at `$C064` and PDL1 = Y at `$C065`;
`$C070` triggers them. Each axis reads as centered or not, and which side. The classic read strobes and
counts until bit 7 drops, which spins for up to 3.3 ms (`JOY_WINDOW`). This driver doesn't spin: it
samples the timers while the screen is drawn and times the samples with the video counter.

Only "not centered" matters. So a reading only has to place the timer's duration T relative to two
thresholds around the calibrated center, not over the whole travel.

## Design

There are two halves, kept strictly apart:

- **Sampling** happens in the code field and in interrupt handlers, so it is minimal. A **strobe** records
  the timers' bits just before it, triggers the timers, and records the time. A **sample** records the
  time and the bits. Sampling makes no decisions and does no arithmetic.
- **Judging** is done by `JoyGetPadL`, when the game asks for the controller (`_ReadJoystick`, on every
  input poll, with interrupts off). It takes every sample recorded since its last call, then classifies
  each axis.

Both sources of samples write the same record, a **run**:

```
+0  the strobe's time
+1  the bits just before the strobe     (bit 7 = X running, bit 6 = Y running)
+2  sample 0: time (0 = no sample), bits
+4  sample 1: ...
```

### Time base

All times are read by the `JOY_NOW` macro and subtracted by `JOY_ELAPSED`:

- **Units.** `VBL_VERT_REG` (`$E0C02E`) holds bits 8-1 of the vertical counter. One step is 2 scanlines
  (127 us). It reads `$7D-$FF`, which is 131 steps per frame (`JOY_FRAME_STEPS`). Elapsed time is
  `b - a`, plus 131 if that is negative.
- **Not CPU-dependent.** Nothing depends on how fast the CPU runs, so accelerators, emulators,
  shadow-off rows and FAST BLIT only change *where* the samples fall.
- **Units everywhere.** Thresholds, the calibration and the windows are all in these steps.
- **Never 0.** A time is never 0, so 0 marks a missing sample.
- **Single-scanline resolution** (`$C02F` bit 7 is V0) would only change the two macros and
  `JOY_FRAME_STEPS`. The windows are coarse enough that it isn't needed.

### Judging a sample

A sample is judged at the time it was actually taken, relative to its run's strobe. Each axis has an
interval `(lo, hi]` that contains T:

| bit at elapsed e | meaning | update |
|---|---|---|
| set (timer running) | T > e | `lo = max(lo, e)` |
| clear (timer done) | T <= e | `hi = min(hi, e)` |

- **Uneven spacing is fine.** Samples don't have to be evenly spaced; a late or early sample is still
  right.
- **Fast sources.** A source that runs fast reaches less far. Its run is still correct, and if it saw
  both timers finish it is complete.
- **Combining runs.** Every run taken by one `JoyGetPadL` call narrows the same intervals, because the
  stick doesn't move in a few milliseconds. Short runs are used as they are.
- **Busy strobe.** A run is dropped if its strobe found a timer still running: a running timer ignores
  the trigger, so the run's samples would time an older strobe. This covers a probe strobe soon after a
  scanline run, and the reverse.
- **Disagreement.** The whole reading is dropped if the runs disagree on either axis (`lo >= hi`, the
  stick moved). The axes then keep their directions.
- **Stale samples.** A sample more than `JOY_MAX_E` (8 ms) after its strobe is ignored.
- **The counter wrap.** The counter wraps every frame, so a "done" sample is only right if less than one
  frame passed since its strobe. Both sources guarantee that:
  - A probe run takes a few milliseconds with interrupts off, in one piece.
  - A scanline run only stores samples between its strobe and its frame's last sample line.

### Classifying (`JoyClassify`)

The thresholds per axis are `thrL = center - dz` and `thrR = center + dz`, in steps (`JoyConfigureL`):

- **Left (up):** `hi <= thrL`.
- **Right (down):** `lo >= thrR`.
- **Centered:** `lo >= thrL` and `hi <= thrR`.
- **Straddling** a threshold: the axis keeps its direction, unless the interval rules that direction out
  (`lo >= thrL` while left, `hi <= thrR` while right). Then it is centered.

The keep rule acts as hysteresis around each threshold when samples are far apart.

## Sources

### Probe runs (full renders)

The code field runs with interrupts off except at the interrupt windows (rows 5, 21, 37, ... of each
bank). So a run of PEA rows between two windows is never interrupted.

- **Runs.** Each blitter bank has two runs, at rows `JOY_RUN_ROW_0` (5) and `JOY_RUN_ROW_1` (53). Each
  run is a strobe row and the `JOY_SAMPLES` (15) probe rows up to the next window.
  - With `CTRL_EVEN_RENDER` only even rows run: strobes at rows 6 and 54, and `JOY_SAMPLES_EVEN` (7)
    probes each.
- **Reach.** At about 145 us per row with shadowing off and 264 us with it on (2.8 MHz), a run reaches
  about 2.2 to 4 ms.
- **Where the code goes.** Each hooked row's code is in the unused start of its odd page (`P1 $00-$20`,
  33 bytes) and ends with a `jmp` to the row's original exit target. The row's exits jump to it.
  - `JoyInstallProbes` hooks the rows. `_InitLiteBlitter` calls it after setting every exit, but only
    when a player uses the joystick.
- **Where the data goes.** The blitter runs with RAMWRT on, so the probe code never writes the direct
  page. Its runs go to `JOY_DATA` in the blitter bank itself (DBR), one `JOY_SLOT_SIZE` slot per run,
  at the same offset in both banks. `TemplateLiteBank1.s` / `2.s` reserve the space.
- **The guard.** The strobe row sets Y = `JOY_TOKEN`, and a probe row only samples if Y is set.
  - The code field never uses Y, and `_BltRangeLiteBody` enters it with Y = 0. So a range that starts
    after a run's strobe row doesn't sample.
  - A range that ends inside a run keeps the samples it took.
  - So a run's samples always start with its first probe row, and an empty first sample means an empty
    run.

Strobe row (30 bytes):

```
        JOY_BITS                ; the bits before the strobe
        sta   JD+1
        JOY_STROBE
        JOY_NOW
        sta   JD+0              ; the strobe's time
        ldy   #JOY_TOKEN
        jmp   <exit target>
```

Probe row (26 bytes):

```
        tya
        beq   :skip             ; this range didn't run the strobe
        JOY_NOW
        sta   JD+2+2k           ; the time
        JOY_BITS
        sta   JD+3+2k           ; the bits
:skip   jmp   <exit target>
```

### Scanline interrupts (dirty renders)

The dirty renderer never runs the code field and leaves interrupts on nearly all the time, so the video
hardware does the timing.

- **The lines.** A strobe at line `JOY_SCAN_LINE_0` (8), then one sample line per distinct threshold,
  at the threshold's time after the strobe (2 lines per step). `JoyConfigureL` computes the list
  (`joyScanLines`, ascending, no duplicates) and the counter values that tell the lines apart
  (`joyScanVC1`, `joyScanVCLast`).
  - With both axes sharing a center there are only 2 sample lines, so 3 interrupts a frame; at most 5.
  - Each sample decides its threshold. "Done" at the left threshold means left/up. "Running" there and
    "done" at the right one means centered. "Running" at the right one means right/down.
  - Fixed, evenly spaced samples were tried first (4, 7 steps apart) and failed: with thresholds at 8
    and 14 and samples at 7 and 14, a centered stick read "between 7 and 14". That straddles the left
    threshold, so an axis stuck at left never returned to center, and left needed a much bigger
    movement than right.
  - Each left threshold is at least 2 steps, so the first sample line is clear of the strobe's counter
    value.
- **Arming.** `JoyScanArm` (on entering `gridDrawDirty`) sets the SCB interrupt bit of those lines.
- **Disarming.** `JoyScanDisarm` runs before the code field runs (`_BltRangeLite`), in the configuration
  screen, and at shut-down.
- **Taking the interrupt.** The Interrupt Manager hook `irqHook` (`rom/rom_exec.s`), which runs first
  for every IRQ, calls `JoyScanService` directly and returns with `RTI`. It does that when:
  - the interrupt is a native-mode IRQ (the firmware's stubs enter with V set for a BRK),
  - the joystick is armed,
  - and the scanline interrupt is pending.

  This skips the firmware's dispatch. Any other pending source (VBL) holds the IRQ line, so it comes
  straight back through the firmware. There is no IRQ.SCAN handler: the scanline interrupts are only
  armed during dirty renders, which run in native mode.
- **Cost** (GSSquared, Zelda title screen):

  | path | cycles per interrupt | interrupts per frame | cycles per frame |
  |---|---|---|---|
  | through the firmware | about 712 | 8 | about 5,700 (about 12% of the CPU) |
  | `irqHook` fast path | 210 (123 in `JoyScanService`) | 3-5 | about 630-1,050 (1.4-2.3%) |

- **The service routine.** `JoyScanService` reads the bits, then the time. The line the interrupt arrived
  on says what it is:
  - **Before `joyScanVC1`** (halfway to the first sample line): the **strobe**. It records the bits
    from before the strobe, strobes, records the time, resets the sample count and opens the run.
  - **Otherwise: a sample**, stored if the run is open.
  - **From `joyScanVCLast`** (halfway between the last two sample lines): the frame's **last
    sample**, which closes the run. So a sample whose frame had no strobe (late, or armed after the
    strobe line) is never stored.
- **Taking the samples.** `JoyGetPadL` takes the samples stored so far and resets the count. The run's
  later samples belong to the same strobe and are taken by the next call.

## Configuration (`rom/rom_config_setup.s`)

- **Settings.** The joystick has two settings:
  - **CALIBRATE** stores each axis' center, `config_joy_cx` / `cy`, in steps x 16. 0 means not
    calibrated, and then `JOY_DEFAULT_CENTER` (12 steps, 1.5 ms) is used.
  - **SENSITIVITY 1-7** sets the dead zone, `dz = 8 - sensitivity` steps.
- **TEST** shows each axis' timer and direction live.
- **The measurement.** CALIBRATE and TEST measure with `JoyMeasureL` (in `JoyProbes.s`), which spins
  with interrupts off. It uses the same macros and `JoyJudge`. It returns the time each timer was first
  seen done, so the timer ended in `[e - 1, e]`.
  - CALIBRATE averages 16 measurements and subtracts half a step.
  - TEST classifies them with `JoyClassifyL`.
- **Applying the settings.** `JoyConfigureL` turns the settings into thresholds. Each left threshold is
  at least 2; each right one is after it and at most `JOY_MAX_E`. It also computes the scanline
  interrupts' lines from them.

The former OFFSET setting (thresholds moved earlier for the probe runs only, to make up for fast rows) is
gone. Samples are judged at their real times, so fast rows don't bias a reading; they only reach less
far. Its word in the preferences block is kept, unused, so saved files still load.

## Verification still to do

- **GSSquared.** With a joystick configured, watch `JOY_DATA` and `joyScanRun`:
  - Check that the probe runs' times span the expected reach in shadow-on and shadow-off passes.
  - Done in GSSquared (mouse as joystick, 2.8 MHz): centered, left, right, up and down all work in a
    dirty-render game (Zelda), and sensitivity visibly changes the dead zone.
- **Holding the stick.** Hold it left, centered and right in a full-render game (SMB, Contra) and a
  dirty-render one (Zelda, DK). Check that the direction never flickers, and that TEST agrees with play.
- **Real hardware** with a ZipGS toggled: the calibration stays valid.
- **Cost.** The SMB attract-demo cycle bench with a joystick configured should show well under 1% more
  cycles.

## Open questions

1. **GSSquared at "ludicrous" speed** gives timings that don't match its own 2.8 MHz ones; test joystick
   behavior at 2.8 MHz. In its mouse mode the axes come from the pointer's position in the window, so
   calibrate with the pointer where it will rest.
2. **A RATE setting (not done; maybe later).** Read the joystick with scanline interrupts only every 1, 2
   or 4 frames, to cut their cost to a half or a quarter. The gate goes in `irqVbl`, not `JoyScanArm`:
   the joystick stays armed across frames and renders, so `irqVbl` would count VBLs and set or clear the
   VGC scanline-enable bit each frame, clearing any stale status before enabling. `JoyScanArm` would
   enable only on an "on" frame. `JoyConfigureL` would turn the setting into a mask, and the setting
   would come from the config reserve, with 0 meaning 1. `JoyGetPadL` needs no change.
3. **A second joystick** (PDL2/PDL3) doesn't fit in the 33 bytes of a probe row. It would need two
   hooked rows per sample.

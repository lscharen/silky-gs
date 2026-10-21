# Changes

Newest first.  Each entry lists the user-visible changes since the one before it.

## 2026-10-21

### Input

- **Joystick support in every game.**  Choose JOYSTICK as the input TYPE on the INPUT menu.  The stick
  is read while the game runs without slowing it down: full renders time it with probes built into the
  scanline renderer, and dirty renders with scanline interrupts that are only on while they run.
  Joystick buttons 0 and 1 are the A and B buttons, and the keyboard keeps working alongside.
  - CALIBRATE (center the stick, then press a key), SENSITIVITY (1 - 7) and TEST (shows the direction
    each axis reads) on the INPUT menu.
  - OFFSET (0 - 7) for emulators that run the renderer faster than a real IIgs (e.g. GSPlus); leave it
    at 0 on real hardware.
- **New DRIVERS menu: BASIC or J13 keyboard driver.**
  - BASIC reads one key at a time, the last key pressed.  Its key maps now ignore Shift, Control and
    Caps Lock, so a direction key keeps working while a modifier is held as a button.  Pressing a new
    direction replaces the old one, and nothing can get stuck once the keys are released.
  - J13 (adapted from the IIgs Wolfenstein 3D port) tracks up to three held keys, so diagonals work, by
    reading the keyboard microcontroller on ROM 00 / 01 machines.  On ROM 3 and most emulators it
    works like BASIC.
- **Player 2's default keys are now W A S D** (they were I J K L, which clash with the arrow keys when
  Control, player 2's A button, is held).

### Built-in keys

- **No Control key needed any more.**  The built-in keys are now:

  | Key | Action |
  |---|---|
  | `?` | Configuration screen |
  | `!` | Redraw the whole screen |
  | `@` | Show / hide the sprites |
  | `#` | Show / hide the background |
  | `R` | Reset the game (like the NES console's RESET button) |
  | `Q` | Quit, after a confirmation screen (Y quits, N or Escape goes back) |

- A key set as a controller key now works as the controller, not as a built-in key (`?` always opens
  the configuration screen).

### Speed

- Faster dirty rendering: more of the grid work is deferred, the grid encoding dispatches straight to
  its routines, and the erase passes no longer switch data banks.
- Faster sprites: palette selection is deferred for non-compiled sprites, the OAM scan is quicker,
  and the 8x16 sprite path is streamlined.
- All 512 background tiles compile into a single bank.

### Disks

- **README.TXT** at the top level of every disk: the keys and settings that every game shares.
- `npm run build:dist` builds one 800KB disk per game.
- New icons.

### Internal

- The engine moved into its own ENGINE segment, shared by every game, with each game's constants in
  `Config.s` and its callbacks in `Hooks.s`.  This made room in the MAIN segment for every game.

## 2026-10-13

- Moved all games to the new palette build tool developed for Zelda.
  - Many palette transition issues fixed in Super Mario Bros, Mario Bros, Ice Climber and Excitebike.
- Smaller on-disk file sizes for all games (custom OMF packer).
- All games moved into separate folders on the disk image, which keeps the preference files from
  cluttering the top level.
- New default palette provided by @fatdog.
- Optimized Super Mario Bros ROM code to slightly improve the frame rate.
- Sprites can be drawn at single-pixel positions (most games; Super Mario Bros keeps 2-pixel steps).
- Fixed input handling in Wumpus.
- Restored the FAST BLIT mode (selectable in the configuration).  This mode renders only the even
  scanlines and makes scrolling games somewhat playable at stock speed.
- Lots of configuration UI changes.
  - Games can now define their own settings.
  - Configuration enabled in all games.
  - Preference files are expandable and should have a stable file format going forward.

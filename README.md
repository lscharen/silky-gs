# silky-gs

A runtime for porting NES games to the Apple IIgs. See some examples running [here](https://www.youtube.com/@iigsgamedev9752).

**silky-gs is not a NES emulator.** Each game's original 6502 code is ported to run natively on the
IIgs's 65816. The runtime stands in for the NES hardware: it records the game's PPU and APU register
writes, renders the graphics to the Super Hi-Res screen and plays the sound on the Ensoniq DOC.

## Porting process

Each port starts from a disassembly of the NES ROM, converted to Merlin32 source and then modified by
hand. Every access to the PPU and APU registers, addressing modes the 65816 can't run the same way
(such as `abs,Y` into zero page), and the mapper's bank switching are replaced with shims that call
into the engine. Hooks are added where the game needs to cooperate with the IIgs: yielding instead of
busy-waiting, removing sprite 0 hit waits, and a custom screen render routine for split-screen status
bars.

## Execution model

The engine runs two tasks that share the CPU: the NES task runs the game code, and the GS task
renders the screen and handles the IIgs side. The 60Hz vertical blank interrupt is the scheduler. At
each VBL it starts the next NES frame, which takes the place of the NES's NMI. The ROM code is
modified to yield the CPU back to the GS task whenever it would wait for the VBL, so all of the
remaining time goes to rendering. If a NES frame overruns, the GS task still gets a VBL after every
few overruns: the game slows down, but the screen keeps updating and audio and input stay
responsive.

## Features

* **Mappers**: NROM, and MMC1 PRG bank switching (each 16KB PRG bank lives in its own IIgs memory bank)
* **CHR-ROM and CHR-RAM**: CHR-ROM tiles are converted at build time; CHR-RAM writes mark tiles dirty
  and they are recompiled when next drawn
* **Nametable mirroring**: horizontal and vertical, including switching at runtime (MMC1)
* **Compiled tiles**: background tiles are compiled to 65816 code and drawn by a PEA-based blitter
* **Compiled sprites**: a per-game list of sprite tiles is compiled, with flipped variants and masks;
  other tiles are drawn from pre-shifted bitmaps. 8x8 and 8x16 sprites are both supported
* **Scrolling**: horizontal and vertical, with split-screen status bars handled by per-game renderers
* **Incremental rendering**: when the background does not scroll, only the 8x8 cells touched by
  sprites or nametable writes are redrawn
* **Audio**: both pulse channels, triangle and noise
* **Input**: keyboard or SNES MAX controller for two players, with a configurable key map
* **Settings**: an in-game configuration screen for audio, video and input options

### Not implemented

* The DMC (sample playback) audio channel; writes to `$4010-$4013` are ignored
* Sprite 0 hit and the sprite overflow flag. NES games mostly use sprite 0 hit to time a mid-frame
  scroll split, such as a status bar. Here each game supplies its own screen render routine that
  draws the split directly, so the hit isn't needed; the waits on it are removed during conversion
* Mid-frame and cycle-timed raster effects, apart from the per-game status bar splits
* Single-screen and four-screen mirroring
* MMC1 CHR bank switching, and other mappers (UxROM, CNROM, MMC3, ...)
* PPUMASK color emphasis and greyscale bits
* The APU frame counter IRQ and expansion audio

## Games

| Game | Build target | Mapper |
| --- | --- | --- |
| Super Mario Bros. | `build:smb` | NROM |
| Balloon Fight | `build:bf` | NROM |
| Donkey Kong | `build:dk` | NROM |
| Mario Bros. | `build:mb` | NROM |
| Ice Climber | `build:ic` | NROM |
| Excitebike | `build:eb` | NROM |
| Lights Out | `build:lo` | NROM |
| Wumpus | `build:wump` | NROM |
| The Legend of Zelda | `build:zelda` | MMC1, CHR-RAM |

## Prerequisites

* Windows. The disk image script is a batch file and the tool paths are Windows paths
* [Node.js](https://nodejs.org/), which runs the build scripts. `npm install` is only needed for the
  unit tests
* [Merlin32](https://www.brutaldeluxe.fr/products/crossdevtools/merlin/), the 65816 assembler
* [Cadius](https://www.brutaldeluxe.fr/products/crossdevtools/cadius/), to build the ProDOS disk image
* An Apple IIgs emulator (or a real IIgs) with a GS/OS system disk, such as GSPort, KEGS,
  GSSquared or MAME

The tool locations are set in the `config` section of `package.json`. Update the paths there to
match your installation.

## Building

```
npm run build:smb      # build one game (see the table above for the targets)
npm run build:all      # build every game
npm run build-image    # package the built games into emu/Target.2mg
```

Each game builds to `src/games/<game>/<Name>GS`, for example `src/games/smb/SuperMarioGS`. Zelda
builds to `src/games/zelda/src/ZeldaGS`. For NROM games, the build first converts the CHR-ROM into
the precompiled tile bank (`tiledata.bin`).

`npm run build-image` creates a fresh 8MB ProDOS volume, `/ClassicsGS/`, containing all of the games.
It is a data disk, so mount it next to a GS/OS boot disk and launch the games from the Finder.
`npm run run` builds the image and starts GSPort.

## References

* https://www.gridbugs.org/zelda-screen-transitions-are-undefined-behaviour/

## License

Apache-2.0

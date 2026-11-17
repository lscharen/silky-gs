# Super Mario Bros. on the tile engine

`smb-alt` is Super Mario Bros. built against the tile engine (`src/engines/tile`) instead of the PEA engine
(`src/engines/pea`). It's the same game as `../smb`: the ROM (`rom.s`), the CHR and PPU memory (`PPU.s`, `chr.bin`), the tile
data (`TileData.s`) and the palette sources (`palettes/`) are SMB's own. Only the files that depend on the engine are here.
Use it as the model for building another game on the tile engine.

Build with `npm run build:smb-alt`; `npm run build-image:smb-alt` makes `emu/SuperMarioTile.2mg` and
`emu/SuperMarioTile-boot.2mg`.

## What differs from `../smb`

| File | What it does |
|---|---|
| `SMBAlt.s` | The link file. Its ENGINE segment is `../../engines/tile/Engine.s`, which is how a game picks its engine (the build reads that line). The tile engine has two more segments, `SPRITE` (`Sprite.s`) and `SPRLIB` (`SprLib.s`), and no PEA blitter banks (`PPU1`, `PPU2`). The other segments are SMB's. |
| `Config.s` | SMB's, with `JOYSTICK_SUPPORT`, `CONFIG_VIDEO_FASTBLIT` and `CONFIG_VIDEO_STATUSBAR` set to 0. The tile engine fails the build if a game asks for any of them. |
| `TileGame.js` | What only the tile engine needs to know about the game. Its generator (`src/engines/tile/gen.js`) reads it when the game is built. The fields are documented in the file. |
| `dynart.js` | SMB's dynamic tile art: the `?` block's glyph, which the tile engine animates by itself. Optional for other games. |
| `build.js` | Generates the palette code from `../smb/palettes` into this folder, converts SMB's CHR into `../smb/tiledata.bin`, then assembles and compacts (`assembleGame` and `compactGame` from `scripts/lib/nromBuild.js`). |
| `Main.s`, `Hooks.s` | Copies of SMB's. Nothing in them is engine specific: SMB's custom render screen uses only the standard API, which both engines implement. |

## Porting another game to the tile engine

1. Copy the game's link file and change the ENGINE line to `ASM ../../engines/tile/Engine.s`. Add the `SPRITE` and `SPRLIB`
   segments, and remove the `PPU1` / `PPU2` blitter banks (see `SMBAlt.s`).
2. In `Config.s`, set `JOYSTICK_SUPPORT`, `CONFIG_VIDEO_FASTBLIT` and `CONFIG_VIDEO_STATUSBAR` to 0.
3. Write a `TileGame.js`. `solidTile` is required: the background tile (a nametable byte) that is all color 0, usually the sky or
   the blank tile.
4. Check the game's `EngineExt.s`, if it has one. Code in the engine's bank is written against that engine's internals. A
   routine that only uses the standard API (`ppu_api.s`) works on both engines. One that reaches into PEA internals needs a
   tile engine version.
5. Use `buildNromGame(gameDir, linkFile)` in `build.js`, or `assembleGame` and `compactGame` when the game's inputs live
   elsewhere (as here).

The engine contract both engines implement is in the "Engines" section of the repository's `CLAUDE.md`.

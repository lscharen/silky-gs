; Engine.s - the engine segment (ENGINE), shared by every game
;
; The PPU simulation, the renderers, the blitter, and the tile and sprite compilers, in a bank of
; their own; the rest of the runtime is in MAIN (each game's Main.s).  MAIN calls in through the long
; entry points in ppu/ppu_entry.s (and RenderLatch / RenderDraw), the NES ROM through the PPU register
; shims (ppu_regs.s).  Each game's link file assembles it with "ASM ../../Engine.s".
;
; The game's own files come from game/: Merlin32 finds a put file only relative to the source that
; puts it, so the build (assembleGame, scripts/lib/nromBuild.js) copies the game's Config.s, Hooks.s
; (the callback macros) and pal_defs.s there before assembling, and EngineExt.s (the game's code that
; runs in this bank: a custom render screen, the palette write dispatch; empty for a game without
; one).  game/ is build scratch: edit the files in the game's folder, never these copies.

            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s

            put   Externals.s
            put   core/Defs.s
            put   ImportMain.s                ; The MAIN symbols the engine uses

            put   game/Config.s
            put   game/pal_defs.s

; The page-aligned tables, at offset $0000 of the segment (no padding)
            put   core/Data.s

            mx    %00

; The engine callbacks (the macros), and the game's code in this bank
            put   game/Hooks.s
            put   game/EngineExt.s

            mput  ppu
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            put    ppu/ppu_macros.s
            put    ppu/ppu_init.s
            put    ppu/ppu_shadowlist.s
            put    ppu/ppu.s
            put    ppu/ppu_attributes.s
            put    ppu/ppu_tiles.s
            put    ppu/ppu_metatiles.s
            put    ppu/ppu_nametable2.s
            put    ppu/ppu_queues.s
            put    ppu/ppu_palette.s
            put    ppu/ppu_regs.s
            put    ppu/ppu_render.s
            put    ppu/ppu_grid.s
            put    ppu/ppu_grid_quads.s
            put    ppu/ppu_grid_marks.s
            put    ppu/ppu_sprites.s
            put    ppu/ppu_tile_blitters.s
            put    ppu/ppu_frame.s
            put    ppu/ppu_entry.s
            put    ppu/ppu_api.s
; AUTOINC:END

            put   rom/rom_color.s
            put   rom/rom_tiles.s

            put   core/CoreData.s
            put   core/blitter/BlitterLite.s
            put   core/blitter/JoyProbes.s
            put   core/blitter/PEISlammer.s
            put   core/blitter/HorzLite.s
            put   core/blitter/VertLite.s
            put   core/tiles/CompileTile.s
            put   core/sprites/CompileSprites.s

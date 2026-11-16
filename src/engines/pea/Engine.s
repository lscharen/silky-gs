; Engine.s - the PEA engine's segment (ENGINE): silky's PEA field renderer
;
; The PPU simulation, the renderers, the blitter, and the tile and sprite compilers, in a bank of
; their own; the rest of the runtime is in MAIN (each game's Main.s).  MAIN calls in through the long
; entry points in ppu/ppu_entry.s (and RenderLatch / RenderDraw), the NES ROM through the PPU register
; shims (ppu_regs.s).  A game that uses this engine assembles it with "ASM ../../engines/pea/Engine.s".
;
; The game's own files come from src/game/: Merlin32 finds a put file only relative to the source that
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

            put   ../../Externals.s

; Addresses in the blitter banks (blitter/TemplateLiteBank1.s, TemplateLiteBank2.s)
lite_start_page_1    EXT
lite_start_page_2    EXT
lite_base_1          EXT
lite_base_2          EXT

            put   ../../core/Defs.s
            put   ImportMain.s                ; The MAIN symbols the engine uses

            put   ../../game/Config.s
            put   ../../game/pal_defs.s

; The page-aligned tables, at offset $0000 of the segment (no padding)
            put   Data.s

            mx    %00

; The engine callbacks (the macros), and the game's code in this bank
            put   ../../game/Hooks.s
            put   ../../game/EngineExt.s

; The engine's part of a CHR-RAM write (ppu/ppu_regs.s PPUDATA_WRITE_CHR): A = the tile's old ChrRamDirty flags (8-bit),
; X = its index.  A background form that was clean gets a recompile stub (ChrQueueBg, ppu/ppu_metatiles.s).  A, X, Y kept
CHR_WRITE_HOOK mac
            bit   #CHRRAM_BG_DIRTY
            bne   *+5
            jsr   ChrQueueBg
            <<<

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
            put    ../../ppu/ppu_palette.s
            put    ../../ppu/ppu_regs.s
            put    ppu/ppu_render.s
            put    ppu/ppu_grid.s
            put    ppu/ppu_grid_quads.s
            put    ppu/ppu_grid_marks.s
            put    ppu/ppu_sprites.s
            put    ../../ppu/ppu_tile_blitters.s
            put    ppu/ppu_frame.s
            put    ppu/ppu_entry.s
            put    ppu/ppu_api.s
; AUTOINC:END

            put   ../../rom/rom_color.s
            put   rom_tiles.s
            put   ../../ppu/chr_convert.s

            put   CoreData.s
            put   EngineInit.s                ; What the runtime asks of an engine at start-up (ImportEngine.s)
            put   blitter/BlitterLite.s
            put   blitter/JoyProbes.s
            put   blitter/PEISlammer.s
            put   blitter/HorzLite.s
            put   blitter/VertLite.s
            put   CompileTile.s
            put   ../../core/sprites/CompileSprites.s

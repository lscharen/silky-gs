; Stats.s -- the tile engine's measurement counters: TILE_STATS, the counterpart of the PEA engine's GRID_STATS /
; GRID_CELL_STATS (ppu_grid.s, ppu_grid_quads.s).  Off in normal builds.  Front.s and Sprite.s put this file; the block
; itself (TILESTAT) is at the end of Sprite.s, and every count uses long addressing, so any data bank works.
; All counters are 32-bit.  Read by scripts/engine-stats.js.
;
; With TILE_STATS on, the sprite cache's hits and misses also go to silky's SPR_STATS block (PPU_MEM+SPR_STATS), as the PEA
; engine's drawSprites counts them; its compiles, shifts and evictions need SPR_CACHE_STATS (core/Defs.s) as well.

TILE_STATS  equ   0

SPR_STATS_A equ   $2910               ; core/Defs.s: SPR_STATS, and its counters
SPR_ST_HITS_A equ 0
SPR_ST_MISSES_A equ 4

; Count an event: a 32-bit counter.  A, X, Y and the flags are kept
TSINC       mac
            DO    TILE_STATS
            php
            pha
            ldal  ]1
            inc
            stal  ]1
            bne   *+11
            ldal  ]1+2
            inc
            stal  ]1+2
            pla
            plp
            FIN
            <<<

; Add ]2 (an immediate) to a 32-bit counter.  A, X, Y and the flags are kept
TSADD       mac
            DO    TILE_STATS
            php
            pha
            ldal  ]1
            clc
            adc   #]2
            stal  ]1
            bcc   *+11
            ldal  ]1+2
            inc
            stal  ]1+2
            pla
            plp
            FIN
            <<<

; The counters are at the end of Sprite.s (TILESTAT).  Front.s counts the frames and the changed cells

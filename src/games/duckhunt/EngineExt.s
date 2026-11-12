; Duck Hunt -- the game's code in the engine's bank (src/Engine.s puts it, staged as game/EngineExt.s)
;
; The Zapper's pointer is drawn from the background's pattern table ($1000): the sprites' ($0000) has no
; tile to spare for it (tools/convert.js, CURSOR_TILES).  In 8x8 mode drawSprites (ppu/ppu.s) sets the
; pattern table once for every sprite: sprTmp5 (the tiles' offset in the tiledata bank) and the low word
; of sprCompTbl (that table's half of the compiled sprite keys).  SPRITE_PRE_DRAW (Hooks.s) calls
; DH_PointerTable for the pointer, which selects table 1, and for the sprite drawn after it, which selects
; the sprites' table again.  The pointer is the last OAM_COPY entry (PPU_AddSprite), so it is drawn first.

; The pointer's OAM_COPY index this render (Main.s DH_ShowPointer, before the render), $FFFF if it isn't
; shown
dhPtrIdx    ENT
            dw    $FFFF
dhPtrTbl1   dw    0                       ; Non-zero while table 1 is selected for the pointer

; X = the OAM index (kept), 16-bit registers, DBR = $01, D = the runtime's direct page.  A is trashed.
            mx    %00
DH_PointerTable
            txa
            cmpl  dhPtrIdx
            bne   :restore
            lda   #$8000                  ; Pattern table 1
            sta   sprTmp5Hi               ; (sprTmp5, ppu.s)
            lda   #SPR_COMP_TBL+$1000
            sta   sprCompTbl
            lda   #1
            stal  dhPtrTbl1
            rts

:restore    ldal  spadr_hi                ; The sprites' table, as drawSprites set it ($0000 / $8000)
            sta   sprTmp5Hi
            lsr
            lsr
            lsr                           ; (carry clear)
            adc   #SPR_COMP_TBL
            sta   sprCompTbl
            lda   #0
            stal  dhPtrTbl1
            rts

; The Legend of Zelda -- the code the engine calls in its own bank
;
; The build stages this file into src/game/ and src/Engine.s puts it in the ENGINE segment: the code
; and data the renderer or the PPU write shims call with jsr or read with 16-bit addresses (a game's own
; palette dispatch table, SPRITE_PRE_DRAW's code), or that works on the engine's internals.  Main.s is in another bank: its symbols are reached with long addressing ("label EXT" here,
; "label ENT" at the definition) and so are this file's from there.

            mx    %00

; Link goes under the top and bottom doors of the dungeons by the NES limit of 8 sprites per
; scanline: WriteBlankPrioritySprites (bank 1) puts 8 transparent sprites (tile $1C, behind the
; background, X 0) at Y $3D and 8 at Y $DD in the first 16 OAM slots, Link's highest and lowest
; positions, so the NES drops every other sprite on those 16 lines.  The engine has no sprite limit,
; so ZSpriteClip hides the sprites' lines in the top band as they are drawn (sprClipTop, ppu.s).  The
; bottom band is left alone: it starts on the screen's last two lines.  Tile $1C is in tile_exclude,
; so the 16 blank sprites themselves are never drawn.
Z_TOP_BAND  equ   $3D+1                     ; the top band's first line (OAM Y + 1); 16 lines
zDoorBand   ENT                             ; non-zero while the band is on this frame (HideDoorBand)
            dw    0

; SPRITE_PRE_DRAW, while the band is on.  X = OAM index, DBR = $01.  A sprite that starts in the band
; has its lines down to the end of the band hidden (Link walking up into the door).  Sprites never start
; above the band: that is the status bar.
            mx    %00
ZSpriteClip
            ldal  OAM_COPY,x                ; first line (OAM Y + 1)
            and   #$00FF
            sec
            sbc   #Z_TOP_BAND               ; d = lines into the band
            cmp   #16
            bcs   :none                     ; above or below it
            eor   #$000F
            inc                             ; 16 - d: down to the end of the band
            stal  sprClipTop
            rts
:none       lda   #0
            stal  sprClipTop
            rts

            mx    %00

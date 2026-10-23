; The Legend of Zelda -- game definition: the engine callbacks
;
; Every callback macro the engine expands, the flags that enable them, and the code and data behind
; them.  Every segment source that assembles engine code puts this file (after Config.s).  A macro
; only produces code where the engine expands it.
;
; The code and data are in two fences, by the segment the engine calls them from:
;
;   DO SEG_MAIN    the event loop and frame hooks: PRE_EVT_LOOP, POST_EVT_LOOP, EVT_LOOP_BEGIN /
;                  END, PRE_RENDER, POST_RENDER, CONFIG_APPLY_HOOK, start-up (InitPlayfield)
;   DO SEG_ENGINE  the renderer and the PPU write shims: SPRITE_PRE_DRAW, CUSTOM_PPU_CTRL_LOCK_CODE,
;                  CUSTOM_PPU_SCROLL_LOCK_CODE, CUSTOM_RENDER_SCREEN_ADDR, PPU_PALETTE_DISPATCH
;
; A segment source sets SEG_MAIN / SEG_ENGINE to 1 for the fences it assembles.  A macro calls the
; code in its own fence with jsr; anything in the other fence is in another bank.  Each fence starts
; and ends with an explicit mx (Merlin32 tracks sep / rep even in a skipped DO block).
;
; Merlin32 ignores a put inside a put file, so pal_transitions.s is put by Main.s.

            mx    %00

; Callback before entering the main event loop
PRE_EVT_LOOP mac
;
             <<<

POST_EVT_LOOP mac
;
             <<<

EVT_LOOP_BEGIN mac
;
             <<<

; This hook happens immediately after all key presses have been handled by the scaffold and gives
; user-code a change to implement custom key commands
EVT_LOOP_END mac
;
             <<<

; Pre-render check to see if there are any background tiles queued for updates.  If so, we will do
; a regular rendering.  If not, use dirty rendering.
PRE_RENDER   mac
             jsr  ApplyMirrorMode    ; finish any mirroring-mode change requested since the last frame
             jsr  ApplyPaletteChange ; switch to a new palette detected since the last frame
             jsr  HideDoorBand       ; the NES 8-sprites-per-line limit at the top door
             <<<

POST_RENDER  mac
;
             <<<

; Callback before each sprite is set up and drawn (drawSprites, ppu.s): X = OAM index, ]1 = the
; sprite height (8 or 16), DBR = $01 (the shadow screen), 16-bit registers.  Sets sprClipTop, the lines
; to hide at the top of the sprite: here, the lines in the top door band (see HideDoorBand).
SPRITE_PRE_DRAW  mac
             ldal  zDoorBand
             beq   *+5
             jsr   ZSpriteClip
             <<<

; Non-zero if SPRITE_PRE_DRAW can set sprClipTop: the sprite renderer only tests it then
SPRITE_CLIP equ 1

; Callback after the configuration has been applied.  X = config_block_start, Y = config_game_start
CONFIG_APPLY_HOOK mac
;
             <<<

; Game-specific configuration values (none): CONFIG_GAME_DEFAULTS lays out their defaults at their IDs in
; the game's block (see rom/rom_config_setup.s, which also has the built-in values, menus and ApplyConfig)
CONFIG_GAME_DEFAULTS mac
;
             <<<

; Provide alternative ways of locking in the scroll and ppu control values after a frame
CUSTOM_PPU_CTRL_LOCK equ 0
CUSTOM_PPU_SCROLL_LOCK equ 1               ; also latches the room transition split (Z_LatchSplit)
CUSTOM_PPU_CTRL_LOCK_CODE mac
;
                          <<<
CUSTOM_PPU_SCROLL_LOCK_CODE mac
                          jsr   Z_LatchSplit
                          lda   ppuscroll
                          <<<

; Do we have a custom routine to execite RenderScreen.  If yes, put its address here
CUSTOM_RENDER_SCREEN equ 1
; (CUSTOM_RENDER_SCREEN_ADDR is in the engine fence below)

; ===========================================================================
; MAIN side: called from the event loop, the frame hooks and start-up
; ===========================================================================
            DO    SEG_MAIN
            mx    %00

zPalDirty   EXT                             ; (the engine side's, in the other segment)
zDoorBand   EXT

; Palette management.  The palettes the game uses are described in ../palettes/, and
; pal_transitions.s (generated from them) gives each one a fixed IIgs slot layout and swizzle
; tables.  A palette RAM write (Z_PalWrite) only marks the palette dirty; at the next render,
; ApplyPaletteChange (GS task) identifies the palette in palette RAM and switches to it (redrawing
; tiles when needed), or shows the changed colors in the current palette's layout.
zCurPal     dw    0                         ; PAL_* id of the palette on screen (0 = none yet)

; Point the swizzle tables at the first palette until the game sets one.  InitPlayfield is called
; by NES_StartUp.
InitPlayfield
SetDefaultPalette
            ldx   PAL_SWIZZLE_LO+2
            lda   PAL_SWIZZLE_HI+2
            jmp   NES_SetPaletteMap

; PRE_RENDER, on the GS task: if the palette RAM changed, identify the palette in it and switch to
; it, or show its changed colors in the current palette's layout
ApplyPaletteChange
            ldal  zPalDirty
            beq   :none
            ldal  _ppumask                  ; While the background is off (the game is rebuilding the
            and   #NES_PPUMASK_BG           ; screen), keep the old colors on whatever is left on the
            beq   :none                     ; screen; the new ones come with the new screen
            lda   #0
            stal  zPalDirty                 ; (first, so a write from here on is seen next time)
            ldx   zCurPal
            jsr   DetectNESPalette          ; A = Y = palette id, 0 if none
            beq   :colors                   ; not a known palette (e.g. a step of a fade)
            cmp   zCurPal
            beq   :colors
            ldx   zCurPal
            sty   zCurPal
            jmp   UpdatePalette             ; X = from, Y = to
:colors     ldy   zCurPal
            beq   :none
            jmp   LoadPaletteColors
:none       rts

; Link goes under the top door of the dungeons by the NES limit of 8 sprites per scanline (see the
; door band in the engine fence).  PRE_RENDER: the band is on if OAM 0 in NES RAM is one of the blank
; sprites: Y $3D and tile $1C, one compare (the Y too: the game hides sprites by their Y alone, so the
; tile stays in OAM 0 after a dungeon).
            mx    %00
HideDoorBand
            lda   #0
            stal  sprClipTop                ; (ZSpriteClip sets it for each sprite while the band is on)
            stal  zDoorBand
            ldal  ROMBase+DIRECT_OAM_READ   ; OAM 0: Y, tile
            cmp   #$1C3D
            bne   :off
            lda   #1
            stal  zDoorBand
:off        rts

            FIN
            mx    %00

; ===========================================================================
; ENGINE side: called from the renderer (per sprite, per render) and the PPU write shims
; ===========================================================================
            DO    SEG_ENGINE
            mx    %00

; Dispatch table for palette RAM writes: every entry goes to Z_PalWrite (palette management)
PPU_PALETTE_DISPATCH equ ZELDA_PALETTE_DISPATCH

; The custom render screen: split screen during room transitions
CUSTOM_RENDER_SCREEN_ADDR equ _RenderScreen

zPalDirty   ENT                             ; palette RAM changed since the last render
            dw    0

; Palette RAM write ($3F00-$3F1F), on the NES task.  The palette RAM is already updated: just note
; that it changed.  Everything else happens at the next render (ApplyPaletteChange), so the colors
; change together with the tiles and the PPUMASK state they go with (a game typically loads a new
; palette while the screen is blank, or before the new screen's tiles are drawn).
Z_PalWrite
            lda   #1
            sta   zPalDirty
Z_PalNone   rts

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

; Room transitions scroll the play area under a fixed status bar.  The NES does it with a sprite-0
; hit at the bottom of the status bar: the NMI shows the status bar at scroll (0,0), then
; WaitAndScrollToSplitBottom (bank 5) changes the scroll for the play area from NES scanline 64.
;
; The engine isn't cycle accurate, so the split is recorded instead: WaitAndScrollToSplitBottom calls
; Z_RecordSplit, in the NMI, which works out the play area's scroll from the game state the routine
; uses.  NES_RenderFrame latches it (Z_LatchSplit, the scroll lock) together with the PPU registers,
; the OAM and the nametable queue, so a render shows the play area at the scroll of the same NES frame
; as its tiles.  (The game state itself is a frame ahead by then: the NMI's mode update has already
; moved the scroll for the next frame and queued the row or column that goes with it.)
;
; While a split was made since the last render, this renderer redraws just the play area at that
; scroll and leaves the status bar on the screen as it is.  The rest of the time the default renderer
; is used.

Z_GameMode            equ $12               ; NES zero page variables
Z_GameSubmode         equ $13
Z_VScrollAddrHi       equ $58
Z_OddBaseNTOverride   equ $5F
Z_ObjDir              equ $98
Z_VScrollAddrLo       equ $E2
Z_CurHScroll          equ $FD
Z_CurPpuControl       equ $FF

ZELDA_SPLIT_LINE      equ 64-y_offset       ; screen line of NES scanline 64, the top of the play area
ZELDA_PF_LINES        equ y_height-ZELDA_SPLIT_LINE

zSplitSeen  dw    0                         ; NES side: a split was made since the last render
zSplitNT    dw    0                         ; NES side: the play area scroll of the last split
zSplitX     dw    0
zSplitY     dw    0
zSplitAddr  dw    0                         ; (scratch: the PPU address of a vertical split)

zPfSplit    dw    0                         ; Latched for the render: draw the screen split
zPfNT       dw    0                         ; and the play area's nametable select and scroll
zPfX        dw    0
zPfY        dw    0
zWasSplit   dw    0                         ; the previous render was split

; Called by WaitAndScrollToSplitBottom (JSL from bank 5) with the NES direct page, before it sets the
; scroll for the play area.  All registers are preserved.
            mx    %11
Z_RecordSplit ENT
            php
            phb
            phk
            plb
            rep   #$30
            pha
            phx

            lda   Z_CurPpuControl           ; The status bar is from nametable 0 or 2 at (0,0)
            and   #$0002
            sta   zSplitNT                  ; Default: the play area isn't split off
            stz   zSplitX
            stz   zSplitY

            lda   Z_GameMode
            and   #$00FF
            cmp   #$08
            bcc   :early

; GameMode 8 - $10 turn the video off below the split (the latched PPUMASK has the background and
; sprites off, so the play area is drawn blank); $11 and up switch the base nametable (0 -> 1, 2 -> 3).

            cmp   #$11
            bcc   :late_done
            lda   #$0001
            tsb   zSplitNT
:late_done  brl   :done

:early      lda   Z_GameSubmode
            and   #$00FF
            beq   :done                     ; Submode 0: the scroll isn't changed
            lda   Z_ObjDir
            and   #$00FF
            cmp   #$04
            bcs   :vertical

; Horizontal: nametable (CurPpuControl & $FE) | OddBaseNameTableOverride, X = CurHScroll.  The Y
; scroll written mid-frame doesn't move the rows, so they stay where they are.

            lda   Z_OddBaseNTOverride
            and   #$0001
            tsb   zSplitNT
            lda   Z_CurHScroll
            and   #$00FF
            sta   zSplitX
            bra   :done

; Vertical (horizontal mirroring): PPUADDR = VScrollAddr, so that nametable row (from its fine Y
; line) is drawn from NES scanline 64.  Nametable 0 is lines 0-239 of the code field and nametable 2
; lines 240-479.

:vertical   lda   Z_VScrollAddrLo
            and   #$00FF
            sta   zSplitAddr
            lda   Z_VScrollAddrHi
            and   #$00FF
            xba
            tsb   zSplitAddr                ; zSplitAddr = PPU address

            and   #$0800                    ; nametable 2?
            beq   *+5
            lda   #240
            sta   zSplitY

            lda   zSplitAddr
            and   #$03E0                    ; coarse Y << 5
            lsr
            lsr                             ; coarse Y * 8
            clc
            adc   zSplitY
            sta   zSplitY

            lda   zSplitAddr                ; The $2006 write also sets the fine Y scroll, to
            xba                             ; address bits 12-14 (2 for $2xxx), and the two $2007
            lsr                             ; reads after it, during rendering, each move it down
            lsr                             ; one more line
            lsr
            lsr
            and   #$0007
            clc
            adc   #2
            adc   zSplitY                   ; V = line of the row in the code field
            sec
            sbc   #ZELDA_SPLIT_LINE+y_offset ; scroll that puts line V at NES scanline 64
            bpl   *+6
            clc
            adc   #480
            ldx   #0
            cmp   #240
            bcc   :v_set
            sbc   #240                      ; (carry is set)
            ldx   #2
:v_set      sta   zSplitY
            stx   zSplitNT

:done       lda   #1
            sta   zSplitSeen
            plx
            pla
            plb
            plp
            rtl

; The scroll lock in NES_RenderFrame, with interrupts off: latch the split for this render
            mx    %00
Z_LatchSplit
            lda   zSplitSeen
            sta   zPfSplit
            stz   zSplitSeen
            lda   zSplitNT
            sta   zPfNT
            lda   zSplitX
            sta   zPfX
            lda   zSplitY
            sta   zPfY
            rts

            mx    %00
_RenderScreen
            lda   zPfSplit
            bne   :split

; Coming out of a transition the play area was last drawn at another scroll position, so redraw
; everything once rather than letting the dirty renderer keep it.

            lda   zWasSplit
            beq   :default
            stz   zWasSplit
            lda   #DIRTY_BIT_BG0_REFRESH
            tsb   DirtyBits
:default    jmp   RenderScreen

; Draw only the play area, at its own scroll position.  The status bar doesn't move during a
; transition, so it is left as it is on the screen.

:split      sta   zWasSplit
            jsr   _ShowDebugInfo

            lda   zPfNT
            ldx   zPfX
            ldy   zPfY
            jsr   NES_SetScroll
            lda   #ZELDA_SPLIT_LINE
            ldx   #ZELDA_PF_LINES
            jsr   drawScreenRange

            stz   DirtyBits
            rts

; Color 0: $3F00 / $3F10 is always IIgs slot 0, so it is set straight away (ppu_palette.s); the
; other color 0s aren't shown.  The rest go to Z_PalWrite.
ZELDA_PALETTE_DISPATCH
        dw   ppu_3F00,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   ppu_3F10,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite
        dw   Z_PalNone,Z_PalWrite,Z_PalWrite,Z_PalWrite

            FIN
            mx    %00

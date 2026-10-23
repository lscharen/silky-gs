; ppu_entry.s - Long entry points into the engine
;
; The engine (the ppu/ files, the blitter, the tile and sprite compilers) is assembled into its own
; segment, ENGINE, in its own bank (each game's Engine.s); the rest of the runtime (scaffold.s, the
; configuration, the APU, the game's frame hooks) is in MAIN.  MAIN calls the engine only through
; these: JSL, which set DBR to the engine bank, as the engine's routines expect, and return with RTL.
; N and Z are not preserved (PLB); C, V and the registers are.
;
; RenderLatch and RenderDraw (ppu_frame.s) are entered the same way.
;
; Everything MAIN uses from the engine is exported with ENT at its definition ("label ENT", never
; the operand form: see scripts/check-xbank.js); MAIN imports it all (ImportEngine.s).

            mx    %00

; Start-up (scaffold.s NES_StartUp)
PPUStartUpL ENT
            phb
            phk
            plb
            jsr   PPUStartUp
            plb
            rtl

InitYExcludeL ENT
            phb
            phk
            plb
            jsr   InitYExclude
            plb
            rtl

; !, the full repaint key (scaffold.s)
ForceMetatileRefreshL ENT
            phb
            phk
            plb
            jsr   ForceMetatileRefresh
            plb
            rtl

; A mirroring change (ControlBits.s ApplyMirrorMode)
PPUSetMirrorModeL ENT
            phb
            phk
            plb
            jsr   PPUSetMirrorMode
            plb
            rtl

; NES_StartUp (scaffold.s): compile every CHR-ROM tile (rom_tiles.s)
ROM_CompileBackgroundTilesL ENT
            phb
            phk
            plb
            jsr   ROM_CompileBackgroundTiles
            plb
            rtl

; NES_SetPaletteMap (rom_helpers.s)
SprRequestFlushL ENT
            phb
            phk
            plb
            jsr   SprRequestFlush
            plb
            rtl

; _SetScreenMode (Graphics.s).  Returns A.
SetScreenRectL ENT
            phb
            phk
            plb
            jsr   SetScreenRect
            plb
            rtl

; InitGraphics, _ClearShadowScreen (Graphics.s).  (_ShadowOn doesn't use DBR.)
_ShadowOnL ENT
            jsr   _ShadowOn
            rtl

; UpdatePalette (pal_transitions.s)
RefreshPPUAttributesL ENT
            phb
            phk
            plb
            jsr   RefreshPPUAttributes
            plb
            rtl

; The generated palette code (pal_transitions.s), for the palette on screen: which palette RAM writes go
; straight to an IIgs slot (ppu_palette.s).  A = the address of its 32-word table (slot * 2, or $FFFF:
; mark the palette dirty), X = the table's bank.  Interrupts are off while it is copied: the NES task
; writes palette RAM.
            mx    %00
PPU_SetPaletteWritesL ENT
            phb
            phk
            plb
            php
            sei
            sta   :src+1
            sep   #$20
            txa
            sta   :src+3
            rep   #$20
            ldx   #62
:src        ldal  $000000,x
            sta   ppuPalWrites,x
            dex
            dex
            bpl   :src
            plp
            plb
            rtl

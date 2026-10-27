; ImportEngine.s - the engine symbols the MAIN segment uses
;
; Put by every game's Main.s (the engine is in its own segment, Engine.s); the engine exports them (ppu/ppu_entry.s and ENT at their definitions).  Everything here is in another bank: call the
; routines with JSL, use long addressing for the data (scripts/check-xbank.js checks this).

; The standard API for games (ppu/ppu_api.s)
NES_SetScroll           EXT
PPU_DrawScreenRange     EXT
PPU_SetupLines          EXT
PPU_DrawScreen          EXT
PPU_ReloadCHR           EXT
_ppuctrl               EXT
_ppuscroll_x            EXT
_ppuscroll_y            EXT

; Frame render (ppu/ppu_frame.s) and the long entry points (ppu/ppu_entry.s)
RenderLatch             EXT
RenderDraw              EXT
PPUStartUpL             EXT
InitYExcludeL           EXT
ForceMetatileRefreshL   EXT
PPUSetMirrorModeL       EXT
ROM_CompileBackgroundTilesL EXT
SprRequestFlushL        EXT
SetScreenRectL          EXT
_ShadowOnL              EXT
JoyInstallProbesL       EXT
JoyScanService          EXT
JoyScanDisarmL          EXT
JoyConfigureL           EXT
JoyGetPadL              EXT
JoyClassifyL            EXT
JoyMeasureL             EXT
joyScanArmed            EXT
RefreshPPUAttributesL   EXT
PPU_SetPaletteWritesL   EXT   ; ppu/ppu_palette.s: the generated palette code (pal_transitions.s)

; Data
ppuPalDirty             EXT
Mul160Tbl               EXT
_ppumask                EXT
sprClipTop              EXT
chr_bank                EXT
ChrRamDirty             EXT
PendingMirrorMode       EXT
MirrorMaskLong          EXT
CIRAMRowMask            EXT
CIRAMColMask            EXT

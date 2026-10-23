; ImportEngine.s - the engine symbols the MAIN segment uses
;
; Put by every game's Main.s (the engine is in its own segment, Engine.s); the engine exports them (ppu/ppu_entry.s and ENT at their definitions).  Everything here is in another bank: call the
; routines with JSL, use long addressing for the data (scripts/check-xbank.js checks this).

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

; Data
ppumask_override        EXT
Mul160Tbl               EXT
_ppumask                EXT
sprClipTop              EXT
chr_bank                EXT
ChrRamDirty             EXT
PendingMirrorMode       EXT
MirrorMaskLong          EXT
CIRAMRowMask            EXT
CIRAMColMask            EXT
ppuctrl                 EXT
ppustatus               EXT

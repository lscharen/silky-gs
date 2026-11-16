; EngDefs.s -- GENERATED once from silky's core/Defs.s: the runtime's direct page (S_...) and constants, for the engine
S_ScreenHeight equ 0
S_StartX equ 22
S_ControlBits equ 26
S_DirtyBits equ 32
S_SwizzlePtr equ 34
S_UserId equ 112
SHADOW_REG equ $E0C035
SHR_PALETTES equ $E19E00
DIRTY_BIT_BG0_REFRESH equ $0010
CTRL_BKGND_ENABLE equ $0002
CTRL_SPRITE_ENABLE equ $0001
VERTICAL_MIRROR_MASK equ $07FF
NES_PPUMASK_BG equ $08
NES_PPUMASK_SPR equ $10
ppumask_override EXT
HORIZONTAL_MIRRORING equ $01
VERTICAL_MIRRORING equ $02
HORIZONTAL_MIRROR_MASK equ $0BFF
CHRRAM_BG_DIRTY equ $01
CHRRAM_SPR_DIRTY equ $02
SPR_COMP_TBL equ $7000
SPR16_KEY equ $2000
SPR16_COMP_TBL equ SPR_COMP_TBL+SPR16_KEY

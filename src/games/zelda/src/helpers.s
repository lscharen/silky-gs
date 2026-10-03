; Helpers for handling direct page opcodes
LDA_ObjDir_Y  LDA_ABS_Y ObjDir
LDA_ObjX_Y  LDA_ABS_Y ObjX
LDA_ObjXp1_Y  LDA_ABS_Y ObjX+1
LDA_ObjY_Y  LDA_ABS_Y ObjY
LDA_ObjYp1_Y  LDA_ABS_Y ObjY+1
STA_ObjState_Y  STA_ABS_Y ObjState
STA_ObjTimer_Y  STA_ABS_Y ObjTimer
STA_ObjTimerp1_Y  STA_ABS_Y ObjTimer+1

; a:sym,Y / a:sym,X helper subroutines (NES zero page lives in a different bank)
LDA_ObjDirp2_Y  LDA_ABS_Y ObjDir+2
LDA_ObjShoveDir_X  LDA_ABS_X ObjShoveDir
LDA_ObjState_X  LDA_ABS_X ObjState
LDA_ObjState_Y  LDA_ABS_Y ObjState
LDA_ObjTimer_Y  LDA_ABS_Y ObjTimer
LDA_Random_Y  LDA_ABS_Y Random
LDY_ObjStunTimer_X  LDY_ABS_X ObjStunTimer
STA_ObjDir_Y  STA_ABS_Y ObjDir
STA_ObjDirp1_Y  STA_ABS_Y ObjDir+1
STA_ObjDirp2_Y  STA_ABS_Y ObjDir+2
STA_ObjStunTimer_X  STA_ABS_X ObjStunTimer
STA_ObjX_Y  STA_ABS_Y ObjX
STA_ObjXp1_Y  STA_ABS_Y ObjX+1
STA_ObjXp2_Y  STA_ABS_Y ObjX+2
STA_ObjY_Y  STA_ABS_Y ObjY
STA_ObjYp1_Y  STA_ABS_Y ObjY+1
STA_ObjYp2_Y  STA_ABS_Y ObjY+2

; a:sym,Y / a:sym,X helper subroutines (NES zero page lives in a different bank)
STA_ObjStatep13_Y  STA_ABS_Y ObjState+13

JMP_IND_02  JMP_ABS_IND $02

; other examples found manually
LDA_0000_Y LDA_ABS_Y $0000
STA_0000_Y STA_ABS_Y $0000

LDA_0001_Y LDA_ABS_Y $0001

LDA_0002_Y LDA_ABS_Y $0002
STA_0002_Y STA_ABS_Y $0002
SBC_0002_Y SBC_ABS_Y $0002

STA_0003_Y STA_ABS_Y $0003

LDA_0004_Y LDA_ABS_Y $0004
STA_0004_Y STA_ABS_Y $0004
ORA_0004_Y ORA_ABS_Y $0004
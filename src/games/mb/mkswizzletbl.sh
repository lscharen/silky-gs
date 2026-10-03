# AllColors  dw     $0F,$06,$09,$12
#            dw     $16,$18,$19,$25
#            dw     $26,$27,$29,$2C
#            dw     $30,$35,$3C,$37


# From the game, there are two palettes but a lot of colors are not used in title screen
#
# Title
# $0F $16 $16 $16
# $0F $27 $27 $27
# $0F $30 $2C $12
# $0F $30 $29 $19
# $0F $35 $35 $35
# $0F $30 $27 $19
# $0F $30 $27 $16
# $0F $3C $12 $25
#
#
# Gameplay
# $0F $16 $16 $16
# $0F $27 $27 $27
# $0F $30 $2C $12
# $0F $30 $29 $19
# $0F $16 $37 $12
# $0F $30 $27 $19
# $0F $30 $27 $16
# $0F $3C $12 $25

# Title Screen
node ../../swizzle.js L0_T0 4 4 4
node ../../swizzle.js L0_T1 9 9 9
node ../../swizzle.js L0_T2 12 11 3
node ../../swizzle.js L0_T3 12 10 6
node ../../swizzle.js L0_S0 13 13 13
node ../../swizzle.js L0_S1 12 9 6
node ../../swizzle.js L0_S2 12 9 4
node ../../swizzle.js L0_S3 11 3 7

# Gameplay
node ../../swizzle.js AT2_T0 12 11 3
node ../../swizzle.js AT2_T1 12 10 2
node ../../swizzle.js AT2_T2 12 9 5
node ../../swizzle.js AT2_T3 12 8 1
node ../../swizzle.js AT2_S0 4 15 3
node ../../swizzle.js AT2_S1 12 9 6
node ../../swizzle.js AT2_S2 12 9 4
node ../../swizzle.js AT2_S3 11 3 7

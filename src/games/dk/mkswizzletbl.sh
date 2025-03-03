# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# The ROM sets the colors, this just provides the palette mapping

# title screen
node ../../swizzle.js L0_T0 11 15 3
node ../../swizzle.js L0_T1 9 9 9
node ../../swizzle.js L0_T2 12 12 12
node ../../swizzle.js L0_T3 12 11 7
node ../../swizzle.js L0_S0 8 13 5
node ../../swizzle.js L0_S1 12 9 7
node ../../swizzle.js L0_S2 5 12 14
node ../../swizzle.js L0_S3 2 9 1

# In the levels, the colors are mostly the same for the caracters
#
# Background = 0
# BG2: DK Color 1 = 1 ($30)
#      DK Color 2 = 2 ($36)
#      DK Color 3 = 3 ($06)
#
# BG3: XX Color 1 = 1 ($30)
#      XX Color 2 = 9 ($2C)
#      XX Color 3 = 7 ($24)
#
# SP0: JM Color 1 = 4 ($02)
#      JM Color 2 = 2 ($36)
#      JM Color 3 = 5 ($16)
#
# SP1: DY Color 1 = 1 ($30)
#      DY Color 2 = 6 ($27)
#      DY Color 3 = 7 ($24)
#
# SP2: FB Color 1 = 5 ($16)
#      FB Color 2 = 1 ($30)
#      FB Color 3 = 8 ($37)
#
# These are all the fixed colors. There are six colors
# left in the pallette and the possible color values
# of $38,$12,$25,$15,$02,$17


node ../../swizzle.js L1_T0 4 11 2
node ../../swizzle.js L1_T1 9 1 6
node ../../swizzle.js L1_T2 12 13 3
node ../../swizzle.js L1_T3 12 11 7

node ../../swizzle.js L1_S0 1 13 5
node ../../swizzle.js L1_S1 12 9 7
node ../../swizzle.js L1_S2 5 12 14
node ../../swizzle.js L1_S3 2 9 1


node ../../swizzle.js L2_T0 4 11 2
node ../../swizzle.js L2_T1 12 9 5
node ../../swizzle.js L2_T2 12 13 3
node ../../swizzle.js L2_T3 12 11 7

node ../../swizzle.js L2_S0 1 13 5
node ../../swizzle.js L2_S1 12 9 7
node ../../swizzle.js L2_S2 5 12 14
node ../../swizzle.js L2_S3 3 14 4


node ../../swizzle.js L3_T0 11 9 1
node ../../swizzle.js L3_T1 12 3 7
node ../../swizzle.js L3_T2 12 13 3
node ../../swizzle.js L3_T3 12 11 7

node ../../swizzle.js L3_S0 1 13 5
node ../../swizzle.js L3_S1 12 9 7
node ../../swizzle.js L3_S2 5 12 14
node ../../swizzle.js L3_S3 2 12 3

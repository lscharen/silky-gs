# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# Title Screen
#   0    1    2    3    4    5    6    7    8    9   10   11   12   13   14   15
# $0F, $30, $27, $2A, $15, $02, $21, $00, $10, $16, $12, $37, $21, $17, $11, $2B
node ../../swizzle.js TS_T0 1 2 3
node ../../swizzle.js TS_T1 1 2 4
node ../../swizzle.js TS_T2 1 5 6
node ../../swizzle.js TS_T3 1 7 8
node ../../swizzle.js TS_S0 9 10 11
node ../../swizzle.js TS_S1 10 9 11
node ../../swizzle.js TS_S2 9 1 6
node ../../swizzle.js TS_S3 13 14 15
#
# First Level
#   0    1    2    3    4    5    6        7        8    9   10   11   12   13   14   15
# $0F  $2A  $09  $07  $30  $27  $15/$16  $02/$11  $21  $00  $10  $12  $37  $17  $35  $2B
node ../../swizzle.js L1_T0 1 2 3
node ../../swizzle.js L1_T1 4 5 6
node ../../swizzle.js L1_T2 4 7 8
node ../../swizzle.js L1_T3 4 9 10
node ../../swizzle.js L1_S0 6 11 12
node ../../swizzle.js L1_S1 11 6 12
node ../../swizzle.js L1_S2 13 7 14
node ../../swizzle.js L1_S3 13 7 15
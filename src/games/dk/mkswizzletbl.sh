# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# The ROM sets the colors, this just provides the palette mapping
node ../../swizzle.js L0_T0 1 2 3
node ../../swizzle.js L0_T1 4 4 4
node ../../swizzle.js L0_T2 5 5 5
node ../../swizzle.js L0_T3 5 1 6
node ../../swizzle.js L0_S0 7 8 9
node ../../swizzle.js L0_S1 5 4 6
node ../../swizzle.js L0_S2 9 5 10
node ../../swizzle.js L0_S3 11 4 12

node ../../swizzle.js L1_T0 1 2 3
node ../../swizzle.js L1_T1 4 5 6
node ../../swizzle.js L1_T2 7 8 9
node ../../swizzle.js L1_T3 7 2 10
node ../../swizzle.js L1_S0 5 8 11
node ../../swizzle.js L1_S1 7 4 10
node ../../swizzle.js L1_S2 11 7 12
node ../../swizzle.js L1_S3 9 4 5

node ../../swizzle.js L2_T0 1 2 3
node ../../swizzle.js L2_T1 4 5 6
node ../../swizzle.js L2_T2 4 7 3
node ../../swizzle.js L2_T3 4 2 8
node ../../swizzle.js L2_S0 9 7 6
node ../../swizzle.js L2_S1 4 5 8
node ../../swizzle.js L2_S2 6 4 10
node ../../swizzle.js L2_S3 11 10 1

node ../../swizzle.js L3_T0 1 2 3
node ../../swizzle.js L3_T1 4 5 6
node ../../swizzle.js L3_T2 4 7 8
node ../../swizzle.js L3_T3 4 1 6
node ../../swizzle.js L3_S0 3 7 9
node ../../swizzle.js L3_S1 4 2 6
node ../../swizzle.js L3_S2 9 4 10
node ../../swizzle.js L3_S3 8 4 5

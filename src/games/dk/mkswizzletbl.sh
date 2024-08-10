# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# Single Mapping Table.  The ROM sets the colors, this just provides the palette mapping
node ../../swizzle.js L1_T0 1 2 3
node ../../swizzle.js L1_T1 4 5 6
node ../../swizzle.js L1_T2 7 8 9
node ../../swizzle.js L1_T3 7 2 10
node ../../swizzle.js L1_S0 5 8 11
node ../../swizzle.js L1_S1 7 4 10
node ../../swizzle.js L1_S2 11 7 12
node ../../swizzle.js L1_S3 9 4 5
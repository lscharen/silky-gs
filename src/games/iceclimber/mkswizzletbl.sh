# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# Single Mapping Table.  The ROM sets the colors, this just provides the palette mapping
node ../../swizzle.js L1_T0 1 2 3
node ../../swizzle.js L1_T1 4 5 6
node ../../swizzle.js L1_T2 3 7 8
node ../../swizzle.js L1_T3 9 10 11
node ../../swizzle.js L1_S0 3 2 12
node ../../swizzle.js L1_S1 3 13 12
node ../../swizzle.js L1_S2 3 14 9
node ../../swizzle.js L1_S3 3 15 8
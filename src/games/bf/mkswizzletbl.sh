# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# Single Mapping Table.  The ROM sets the colors, this just provides the palette mapping
node ../../swizzle.js L1_T0 1 2 3
node ../../swizzle.js L1_T1 4 5 6
node ../../swizzle.js L1_T2 4 5 6
node ../../swizzle.js L1_T3 4 5 6
node ../../swizzle.js L1_S0 7 8 9
node ../../swizzle.js L1_S1 8 7 9
node ../../swizzle.js L1_S2 10 11 12
node ../../swizzle.js L1_S3 13 14 15
# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# Single Mapping Table.  The ROM sets the colors, this just provides the palette mapping
node ../../swizzle.js L1_T0 1 2 3
node ../../swizzle.js L1_T1 4 5 6
node ../../swizzle.js L1_T2 7 5 2
node ../../swizzle.js L1_T3 2 5 8
node ../../swizzle.js L1_S0 9 10 1
node ../../swizzle.js L1_S1 8 11 7
node ../../swizzle.js L1_S2 8 10 2
node ../../swizzle.js L1_S3 9 12 13
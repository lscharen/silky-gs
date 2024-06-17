# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# Single Mapping Table.  The ROM sets the colors, this just provides the palette mapping
node ../../swizzle.js L1_T0 1 2 3
node ../../swizzle.js L1_T1 1 4 3
node ../../swizzle.js L1_T2 2 2 2
node ../../swizzle.js L1_T3 2 2 2
node ../../swizzle.js L1_S0 2 1 5
node ../../swizzle.js L1_S1 1 1 1
node ../../swizzle.js L1_S2 1 1 1
node ../../swizzle.js L1_S3 1 1 1
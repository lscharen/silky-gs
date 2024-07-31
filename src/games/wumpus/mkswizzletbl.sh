# Create the palette mapping tables
#
# ./mkswizzetbl.sh > pal.s
#
# Single Mapping Table.  The ROM sets the colors, this just provides the palette mapping
node ../../swizzle.js L1_T0 1 2 3    # $22, $30, $15, $14
node ../../swizzle.js L1_T1 4 5 6    # $22, $02, $38, $3C
node ../../swizzle.js L1_T2 7 2 3    # $22, $1C, $15, $14
node ../../swizzle.js L1_T3 4 5 6    # $22, $02, $38, $3C
node ../../swizzle.js L1_S0 8 9 10   # $0f, $29, $1A, $0F
node ../../swizzle.js L1_S1 5 11 10  # $0f, $38, $17, $0F
node ../../swizzle.js L1_S2 5 12 10  # $0f, $38, $21, $0F
node ../../swizzle.js L1_S3 5 11 10  # $0f, $38, $17, $0F

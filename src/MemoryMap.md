# Memory Allocations

# tiledata

A static bank of memory allocation in core/static/TileData.s.  This memory bank is used to store the converted
tile data from the NES CHR-ROM in a format that is more efficient to use when rendering to the IIgs graphic
screen.

Each NES tile is 8x8 pixels, which occupies 32 bytes of memory, so a full bank of memory can hold 1024 tiles.
However, there is no efficient way to flip tile horizontally while drawing, so each processed tile is stored
twice -- one copy in the normal orientation and one flipped on the horizontal axis.  It _is_ possible to flip
tile vertically while drawing by changing the loading order, so those tiles do not need to be pre-created.

In addition to the having to create the horizontally flipped version of each tile, a mask must be calculated
for the tiles that are used as sprites.  This results in having a total of four copies of each tile's memory
footprint -- 128 bytes per tile.

For a set of 256 sprite tiles, this requires a total of 32,768 ($8000) bytes of space.  And the first half
of the tiledata bank is used for this.

The second half of the bank is (optionally) used to store the background tiles in processed format.  Background
tiles cannot be flipped and do not require a mask, so require less total memory.  However, they are currently
stored very 128 bytes to make addressing consistent within the bank.
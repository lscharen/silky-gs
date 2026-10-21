There are many specialized blitters used for copying data from the NES ROM data
into different target locations, including the SHR graphics screen

Each blitter is an unrolled loop that works with an 8x8 tile (32 bytes)
of data.

# Direct to screen

Copies data directly from the packed NES graphics format (0000_000w_wxxy_yzz0) to the
graphics screen without masking.

* `sprTmp0` is the sprite data address
* `sprTmp1` is the screen address

```
          ldx   sprTmp0
          ldy:  {]line*4},x                            ; Load the tile data lookup value
          ldx   sprTmp1
          lda   [SwizzlePtr],y                         ; Load the remapped tile data
          stal  $010000+{]line*SHR_LINE_WIDTH},x
```

# Direct to screen (with masking)

* `sprTmp0` is the sprite data address
* `sprTmp1` is the screen address

```
          ldx   sprTmp0
          ldy:  {]line*4},x                            ; Load the tile data lookup value
          lda:  {]line*4}+32,x                         ; Load the mask value
          ldx   sprTmp1
          andl  $010000+{]line*SHR_LINE_WIDTH},x       ; Mask against the screen
          ora   [SwizzlePtr],y                         ; Merge in the remapped tile data
          stal  $010000+{]line*SHR_LINE_WIDTH},x
```

# Copy tile data to buffer

Moves a tile of data into a temporary direct page location.  This allows some opertion to be split
us and remove register pressure.

The X register is set to the sprite data and does not need to be reloaded.

```
        ldy:  {]line*4},x                            ; Load the tile data lookup value
        lda   [SwizzlePtr],y                         ; Lookup the data from the swizzle table
        sta   blttmp+{]line*4}                       ; Save on the direct page
```

# Copy tile mask to buffer

The X register is set to the sprite data and does not need to be reloaded.

There is no combined copy of tile data and mask because there is no advantage
over calling each subroutine separately

```
        lda:  {]line*4}+32,x                         ; Load the tile mask
        sta   blttmp+{]line*4}+32                    ; Save on the direct page
```

# Build priority mask to buffer

Calculates a priority sprite mask based on the screen data.  Use to support rendering with
the sprites' priority bit set.

```
        ldal  $010000+{]line*SHR_LINE_WIDTH}+0,x     ; create mask where 0 = !0 and 0 = F.
        beq   zero
        bit   #$F000
        beq   *+5
        ora   #$F000     ; 3+3 / 3+2+3 = 6 / 8 = ~7 cycles per pixel average
        bit   #$0F00
        beq   *+5
        ora   #$0F00
        bit   #$00F0
        beq   *+5
        ora   #$00F0
        bit   #$000F
        beq   *+5
        ora   #$000F
zero    eor   #$FFFF     ; This will be ANDed against sprite data, so make it zero if screen data is non-zero
        sta   blttmp+{]line*4}
```

# Draw with priority mask, on demand data

```
        lda   blttmp+{]line*4}+32                  ; load calculated mask
        beq   skip

        ldx   sprTmp0
        ldy:  {]line*4},x
        ldx   sprTmp1                              ; 4 + 6 + 4 = 14

        and   [SwizzlePtr],y
        oral  $010000+{]line*SHR_LINE_WIDTH}+0,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+0,x
skip
```

# Draw with priority mask, buffered data

```
        lda   blttmp+{]line*4}+32                  ; load calculated mask
        beq   skip
        and   blttmp+{]line*4}
        oral  $010000+{]line*SHR_LINE_WIDTH}+0,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+0,x
skip
```

# Apply edge clipping to buffered mask

When a tile is used for sprites, it can be places to extend past the right edge of the playfield.  This blitter modifies
a mask in the direct page buffer to enforce clipping.

This can actually be faster than adding an extra

```
    andl  mask_bank+{]line*SHR_LINE_WIDTH},x
```

instruction to the blitters because that would add an unconditional 96 cycles.  Whereas clipping only zeros out the edge bytes using direct page operations that take 3 or 4 cycles each, so at most 56 cycles plus overhead.

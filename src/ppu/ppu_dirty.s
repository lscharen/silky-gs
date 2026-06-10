; Support routines for dirty rendering

    mx  %00

; The physical screen must always be a multiple of 8 in the horizontal and vertical direction.  For
; dirty updates, the 8x8 grid it marked for locations where the tiles need to be updated.  If the
; display screen is aligned to the NES nametable grid (scroll_x and scroll_y are multiples of 8) then
; simple background updated like a timer or player score are 1:1 with on-screen tiles.
;
; By tracking tiles, the amount of shadow updates is generally minimized because sprites are
; often comprised of 2 to 4 tiles and sprites generally do not move quickly.  This means that
; by only marking on-screen grid locations, the amount of overdraw is reduces and by coalescing
; adjacent grid locations, the amount of overhead is curtailed.  Restricting the updates to
; the on-screen grid also means that there is no need to worry about clipping.

    mx  %00
revealTiles
        lda   tile_head
        bmi   :out                ; Nothing to reveal

:loop
        tay
        ldx   tile_list,y

; Shadow the 8x8 block

        ldal  $010000+{]line*SHR_LINE_WIDTH},x
        stal  $010000+{]line*SHR_LINE_WIDTH},x
        ldal  $010000+{]line*SHR_LINE_WIDTH}+2,x
        stal  $010000+{]line*SHR_LINE_WIDTH}+2,x

; Move to the next tile

        lda   tile_list+2,y
        bpl   :loop

:out
        rts

; 
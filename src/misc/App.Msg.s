               mx %00
HexToChar      dfb   '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'

; Convert a byte (Acc) into a string and store at (Y)
               mx    %00
ByteToString   and   #$00FF
               sep   #$20
               pha
               lsr
               lsr
               lsr
               lsr
               and   #$0F
               tax
               ldal  HexToChar,x
               sta:  $0000,y

               pla
               and   #$0F
               tax
               ldal  HexToChar,x
               sta:  $0001,y

               rep   #$20
               rts

; Convert a word (Acc) into a hexadecimal string and store at (Y)
               mx    %00
WordToString   pha
               bra   Addr2ToString

; Pass in Acc = High, X = low
               mx    %00
Addr3ToString  phx
               jsr   ByteToString
               iny
               iny
               lda   1,s
               mx    %00
Addr2ToString  xba
               jsr   ByteToString
               iny
               iny
               pla
               jsr   ByteToString
               rts

; A=Value
; X=Screen offset
               mx    %00
DrawByte       phx                  ; Save register value
               phy
               ldy   #ByteBuff+1
               jsr   ByteToString
               ply
               plx
               lda   #ByteBuff
               jsr   DrawString
               rts

; A=Value
; X=Screen offset
               mx    %00
DrawWord       phx                  ; Save register value
               phy
               ldy   #WordBuff+1
               jsr   WordToString
               ply
               plx
               lda   #WordBuff
               jsr   DrawString
               rts

               mx    %00
ClearWord      lda   #EmptyBuff
               jsr   DrawString
               rts

; DrawString
;
; A = pointer to a string with a leading length byte (in the data bank)
; X = offset from $E1/2000 of the top-left corner
; Y = colour mask for the glyph pixels (e.g. $FFFF = colour 15); preserved
;
; Draws straight to the SHR screen with the config screen's 8x8 tiles (rom_cfg_chr in
; rom/rom_config.s).  Those have A-Z, 0-9 and space; any other character is drawn blank.
               mx    %00
DrawString
               pha                        ; 1,s = string pointer
               stx   ds_pos
               sty   ds_mask
               ldy   #0
               lda   (1,s),y              ; length byte
               and   #$00FF
               sta   ds_len
               ldy   #1
:next
               cpy   ds_len
               beq   :last
               bcs   :done
:last
               lda   (1,s),y
               jsr   ds_glyph             ; A = tile address
               phy
               ldx   ds_pos
               jsr   ds_draw
               ply
               lda   ds_pos
               clc
               adc   #4                   ; 8 pixels
               sta   ds_pos
               iny
               bra   :next
:done
               pla
               ldy   ds_mask
               rts

; A = character.  Returns A = address of its rom_cfg_chr tile (the space tile if there isn't one).
               mx    %00
ds_glyph       and   #$007F
               cmp   #'A'
               bcc   :not_alpha
               cmp   #'Z'+1
               bcs   :blank
               sbc   #'A'-1               ; carry is clear: A - 'A'
               asl
               asl
               asl
               asl
               asl                        ; 32 bytes per tile
               adc   #rom_cfg_chr_a
               rts
:not_alpha     cmp   #'0'
               bcc   :blank
               cmp   #'9'+1
               bcs   :blank
               sbc   #'0'-1               ; carry is clear: A - '0'
               asl
               asl
               asl
               asl
               asl
               adc   #rom_cfg_chr_0
               rts
:blank         lda   #rom_cfg_chr_space
               rts

; A = tile address, X = screen offset.  Draws the 8 lines of the tile to $E1/2000+X.
               mx    %00
ds_draw        tay
               lda   #8
               sta   ds_lines
:line          lda:  0,y
               jsr   ds_expand
               stal  $E12000,x
               lda:  2,y
               jsr   ds_expand
               stal  $E12000+2,x
               iny
               iny
               iny
               iny
               txa
               clc
               adc   #160
               tax
               dec   ds_lines
               bne   :line
               rts

; Expand one word of tile data (w_wxxy_yzz0, four 2-bit pixels) into four SHR nibbles, the same way
; _blitTileNoMask does, then turn the set pixels into $F and apply the colour mask.
               mx    %00
ds_expand      sta   ds_src
               lsr
               and   #$0003
               sta   ds_px
               lda   ds_src
               asl
               and   #$0030
               tsb   ds_px
               lda   ds_src
               asl
               asl
               asl
               and   #$0300
               tsb   ds_px
               lda   ds_src
               asl
               asl
               asl
               asl
               asl
               and   #$3000
               ora   ds_px
               xba
               sta   ds_px
               asl
               asl
               ora   ds_px                ; 3 -> $F in each nibble
               and   ds_mask
               rts

ds_pos         dw    0
ds_mask        dw    0
ds_len         dw    0
ds_lines       dw    0
ds_src         dw    0
ds_px          dw    0

EmptyBuff      str   '    '
ByteBuff       str   '00'
WordBuff       str   '0000'
Addr3Buff      str   '000000'       ; str adds leading length byte


















































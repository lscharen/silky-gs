; Initialize the memory
;
; * $01/2000 - $01/9FFF for the shadow screen
; * $00/0000 - $00/07FF for NES RAM
; * 1 bank for cached tiles
; * 1 bank for cached sprites

               mx        %00

InitMemory
;               PushLong  #0                          ; space for result
;               PushLong  #$000800                    ; size (2k)
;               PushWord  UserId
;               PushWord  #%11000000_00010111         ; Fixed location
;               PushLong  #$010000                    ; Reserve space in Bank 01
;               _NewHandle                            ; returns LONG Handle on stack
;               plx                                   ; base address of the new handle
;               ply                                   ; high address 00XX of the new handle (bank)
;               bcs       :mem_err

               PushLong  #0                          ; space for result
               PushLong  #$008000                    ; size (32k)
               PushWord  UserId
               PushWord  #%11000000_00010111         ; Fixed location
               PushLong  #$012000
               _NewHandle                            ; returns LONG Handle on stack
               plx                                   ; base address of the new handle
               ply                                   ; high address 00XX of the new handle (bank)
               bcs       :mem_err

; Allocate a couple of banks of memory

               jsr       AllocOneBank2
               sta       CompileBank
               stz       CompileBank0

; Initialize some memory tables that point to addresses in the blitter code
InitLiteBlitter

; Fill in the BTable and BRowTable values.  There are 120 lines in each bank and each line covers two of
; the 256-pixel wide NES nametables.  The table pointers are the address of the start of each wide
; nametable row

               ldx       #0
               ldy       #lite_base

:loop1a
               tya
               sta       BTableLow,x
               sta       BTableLow+{240*2},x
               clc
               adc       #_LINE_SIZE
               tay

               lda       #^lite_base
               sta       BTableHigh,x
               sta       BTableHigh+{240*2},x

               inx
               inx
               cpx       #_LINES_PER_BANK*2
               bcc       :loop1a

               ldy       #lite_base_2
:loop1b
               tya
               sta       BTableLow,x
               sta       BTableLow+{240*2},x
               clc
               adc       #_LINE_SIZE
               tay

               lda       #^lite_base_2
               sta       BTableHigh,x
               sta       BTableHigh+{240*2},x

               inx
               inx
               cpx       #_LINES_PER_BANK*2*2
               bcc       :loop1b

; Now, fill in an alternate array that returns the address based on the tile

;               ldx       #120*2
;               ldy       #lite_base_2
;:loop2
;               lda       BTableHigh                  ; This is the same value for the lite blitter
;               sta       BRowTableHigh,x
;               sta       BRowTableHigh+{26*2},x

;               tya
;               sta       BRowTableLow,x
;               sta       BRowTableLow+{26*2},x
;               clc
;               adc       #{8*_LINE_SIZE}
;               tay

;               inx
;               inx
;               cpx       #26*2
;               bcc       :loop2

               clc
:mem_err
               rts

; Bank allocator (for one full, fixed bank of memory. Can be immediately deferenced)

AllocOneBank   PushLong  #0
               PushLong  #$10000
               PushWord  UserId
               PushWord  #%11000000_00011100
               PushLong  #0
               _NewHandle                            ; returns LONG Handle on stack
               plx                                   ; base address of the new handle
               pla                                   ; high address 00XX of the new handle (bank)
               xba                                   ; swap accumulator bytes to XX00	
               stal      :bank+2                     ; store as bank for next op (overwrite $XX00)
:bank          ldal      $000001,X                   ; recover the bank address in A=XX/00	
               rts

; Variation that returns the pointer in the X/A registers (X = low, A = high)
AllocOneBank2  PushLong  #0
               PushLong  #$10000
               PushWord  UserId
               PushWord  #%11000000_00011100
               PushLong  #0
               _NewHandle
               plx                                   ; base address of the new handle
               pla                                   ; high address 00XX of the new handle (bank)
               _Deref
               rts

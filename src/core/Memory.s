; Initialize the memory
;
; * $01/2000 - $01/9FFF for the shadow screen
; * $xx/0000 - $xx/07FF for NES RAM in the NES code bank
; * 1 bank for cached tiles
; * 1 bank for cached sprites

               mx        %00
InitMemory
               PushLong  #0                          ; space for result
               PushLong  #$008000                    ; size (32k)
               PushWord  UserId
               PushWord  #%11000000_00010111         ; Fixed location
               PushLong  #$012000
               _NewHandle                            ; returns LONG Handle on stack
               plx                                   ; base address of the new handle
               ply                                   ; high address 00XX of the new handle (bank)
               bcs       mem_err

; Allocate a couple of banks of memory

               jsr       AllocOneBank2
               sta       CompileBank
               stz       CompileBank0

               jsr       AllocOneBank2
               sta       SpriteBank
               stz       SpriteBank0

               clc
mem_err
               rts

; Bank allocator (for one full, fixed bank of memory. Can be immediately deferenced)

               mx        %00
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
               mx        %00
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

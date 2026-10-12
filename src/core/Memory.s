; Initialize the memory
;
; * $01/2000 - $01/9FFF for the shadow screen
; * $xx/0000 - $xx/07FF for NES RAM in the NES code bank
; * 1 bank for cached tiles
; * 1 - SPR_MAX_BANKS banks for cached sprites (as many as there is memory for, at least 1)

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

               ldx       #0                          ; The compiled sprite cache's banks (SprCacheInit)
:spr_bank      phx
               jsr       AllocOneBank2
               plx
               bcs       :spr_done                   ; no more memory: keep the banks there are
               sep       #$20
               stal      SprBanks,x
               rep       #$20
               inx
               cpx       #SPR_MAX_BANKS
               bcc       :spr_bank
:spr_done      txa
               stal      SprBankCount
               stz       SpriteBank0                 ; SprCompileTile sets SpriteBank to each slot's bank
               stz       SpriteBank
               sec                                   ; no bank at all is an error
               tax                                   ; (Z = no bank; the carry is kept)
               beq       mem_err
               clc
mem_err
               rts

SprBanks       ds        SPR_MAX_BANKS               ; The sprite cache's banks
SprBankCount   dw        0                           ; and how many there are (1 - SPR_MAX_BANKS)

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
               bcs       :err                        ; (carry set: no memory)
               _Deref
:err           rts

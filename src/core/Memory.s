; Initialize the memory
;
; * $01/2000 - $01/9FFF for the shadow screen
; * $xx/0000 - $xx/07FF for NES RAM in the NES code bank
; * 1 bank for the compiled background tiles: 512 slots of 128 bytes (CompileTile)
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
               bcc       *+5
               brl       mem_err

; VOC spike: the sprite plane, $E0/2000 - $E0/9FFF (with its SCBs and palettes), is written directly.  Part
; of it can already hold the Memory Manager's own master pointer blocks (owner $00FF; $E0/6000 - $73FF
; on the GSBoot disk), which can't be moved.  So: find the pages it owns (vocLoAddr, vocLen: the span
; from the first to the last owned page), reserve every free page so nothing else is put there, and
; allocate a bank to swap the span through (drawScreen, ppu/ppu_render.s): its sprite plane copy at
; B/0000 + (addr - $2000), the Memory Manager's bytes at B/8000 + (addr - $2000).
               lda       #$20
               sta       vocPage
               stz       vocRun                      ; start of the current free run (page), or 0
               stz       vocLoAddr
               stz       vocHiAddr
:probe         PushLong  #0
               pea       $00E0
               lda       vocPage
               xba
               pha
               _FindHandle
               pla
               sta       tmp0
               pla
               sta       tmp1
               ora       tmp0                        ; 0: the page is free
               beq       :free
               ldy       #6                          ; The handle's owner: the Memory Manager's own blocks are
               lda       [tmp0],y                    ; swapped; anyone else's (the P8 loader reserves the whole
               cmp       #$00FF                      ; plane for us) is left alone
               beq       :mm
               jsr       :reserve                    ; (ends the free run)
               bra       :next
:mm            lda       vocLoAddr                   ; The Memory Manager's: the span, and end the free run
               bne       :haslo
               lda       vocPage
               xba
               sta       vocLoAddr
:haslo
               lda       vocPage
               inc
               xba
               sta       vocHiAddr
               jsr       :reserve
               bra       :next
:free          lda       vocRun
               bne       :next
               lda       vocPage
               sta       vocRun
:next          inc       vocPage
               lda       vocPage
               cmp       #$A0
               bcc       :probe
               jsr       :reserve                    ; (the last run)

               lda       vocHiAddr
               sec
               sbc       vocLoAddr
               sta       vocLen                      ; 0: nothing to swap

               jsr       AllocOneBank2               ; The swap bank, zeroed (the plane starts transparent)
               bcc       *+5
               brl       mem_err
               sep       #$20
               stal      vocSwapBank
               stal      :zp+3
               rep       #$20
               ldx       #0
               lda       #0
:zp            stal      $000000,x
               inx
               inx
               bne       :zp
               bra       :voc_ok

; Reserve the free run from page vocRun to vocPage (exclusive), if there is one
:reserve       lda       vocRun
               beq       :rr
               PushLong  #0
               lda       vocPage
               sec
               sbc       vocRun
               xba                                   ; size = pages * 256
               pea       $0000
               pha
               PushWord  UserId
               PushWord  #%11000000_00010111         ; Fixed location
               pea       $00E0
               lda       vocRun
               xba
               pha
               _NewHandle
               plx
               ply
               bcc       *+4
               brk       $e3                         ; (A = the Memory Manager error)
               stz       vocRun
:rr            rts
:voc_ok


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

vocPage        dw        0
vocRun         dw        0
vocHiAddr      dw        0
vocLoAddr ENT
               dw        0                           ; (VOC spike) the span of $E0 the Memory Manager owns
vocLen ENT
               dw        0                           ;   (bytes; 0 = none)
vocSwapBank ENT
               dw        0                           ;   and the bank it is swapped through

SprBanks ENT
               ds        SPR_MAX_BANKS               ; The sprite cache's banks
SprBankCount ENT
               dw        0                           ; and how many there are (1 - SPR_MAX_BANKS)

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

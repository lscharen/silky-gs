; Loader.s - ProDOS 8 loader for the self-booting game disks (scripts/build-p8-disk.js)
;
; ProDOS 8 runs this as the disk's first SYSTEM file, at $2000 in emulation mode.  It loads GAME.IMG,
; the game linked to fixed banks by scripts/omf-static.js, and starts it the way GS/OS starts an S16
; application, so the same game binary runs either way:
;
;   1. set the prefix to the boot volume, open GAME.IMG and read its header
;   2. start the Tool Locator and reserve, with a bootstrap user ID, the memory GS/OS would have kept
;      from the Memory Manager -- $E0/2000-$9FFF, $E1/2000-$9FFF, $00/0800-$BFFF -- and every bank the
;      image goes into, then MMStartUp (it fails if the calling code isn't in allocated memory:
;      Technote #27).  $E0/2000 goes first, before the Memory Manager has any reason to put its own
;      blocks there (the Video Overlay Card's sprite plane)
;   3. zero each bank and read the segments into them, 16KB at a time through a bank 0 buffer
;   4. jump to the first segment's entry: A = the Master User ID, X = Y = 0, D = $0800, S = $17FF,
;      native mode, 16-bit registers.  The direct page starts with 'P8BT' and the quit vector ($002003,
;      Quit below), so the game can tell it isn't running under GS/OS (rom/scaffold.s)
;
; Bank 0 use: this code at $2000, the ProDOS file buffer at $4000, the header at $4400, the read buffer
; at $5000-$8FFF; the game's direct page and stack at $0800-$17FF.

            ORG   $2000
            TYP   $FF

MLI         equ   $BF00
DEVNUM      equ   $BF30                 ; the last device used: the boot device
COUT        equ   $FDED
CROUT       equ   $FD8E
PRBYTE      equ   $FDDA

IOBUF       equ   $4000
HDR         equ   $4400
BUF         equ   $5000
BUFLEN      equ   $4000

GAME_DP     equ   $0800
GAME_SP     equ   $17FF

ATTR_FIXED  equ   $C017                 ; locked, fixed, fixed address, fixed bank, no special memory

            mx    %11
            jmp   Start
            jmp   Quit                  ; $2003: the game's quit vector

Start       cld
            ldx   #0
            jsr   Print

; 1. The prefix: the boot volume, from ON_LINE for the boot device

            lda   DEVNUM
            sta   olUnit
            jsr   MLI
            db    $C5                   ; ON_LINE
            da    olParms
            bcc   *+5
            jmp   Err
            lda   volName
            and   #$0F                  ; name length
            tax
            inc                         ; + the leading '/'
            sta   pfxLen
:cp         lda   volName,x             ; volName+1.. -> pfxName+1.. (pfxName = '/')
            sta   pfxName,x
            dex
            bne   :cp
            lda   #'/'
            sta   pfxName
            jsr   MLI
            db    $C6                   ; SET_PREFIX
            da    spParms
            bcc   *+5
            jmp   Err

            jsr   MLI
            db    $C8                   ; OPEN
            da    opParms
            bcc   *+5
            jmp   Err
            lda   opRef
            sta   rdRef
            sta   clRef

            lda   #<HDR                 ; The header
            sta   rdBuf
            lda   #>HDR
            sta   rdBuf+1
            stz   rdReq
            lda   #1
            sta   rdReq+1
            jsr   MLI
            db    $CA                   ; READ
            da    rdParms
            bcc   *+5
            jmp   Err
            lda   HDR
            cmp   #'S'
            bne   :bad
            lda   HDR+1
            cmp   #'G'
            bne   :bad
            lda   HDR+2
            cmp   #'S'
            bne   :bad
            lda   HDR+3
            cmp   #'8'
            beq   :ok
:bad        lda   #$FF
            jmp   Err
:ok

; 2. The tools and the memory

            clc
            xce
            rep   #$30
            mx    %00

            ldx   #$0101                ; _TLBootInit
            jsl   $E10000
            ldx   #$0201                ; _TLStartUp
            jsl   $E10000

            pea   $0000                 ; _GetNewID: a bootstrap ID (application, aux 1)
            pea   $1100
            ldx   #$2003
            jsl   $E10000
            pla
            sta   tmpId
            bcc   *+5
            jmp   ErrN

            lda   #$E0                  ; $E0/2000 first (see the top)
            ldx   #$2000
            ldy   #$8000
            jsr   Reserve
            lda   #$E1
            ldx   #$2000
            ldy   #$8000
            jsr   Reserve
            lda   #$00
            ldx   #$0800
            ldy   #$B800
            jsr   Reserve

            lda   HDR+5                 ; Every bank of the image
            and   #$00FF
            sta   segCount
            stz   segIdx
:rb         jsr   EntryAddr
            lda   HDR,x                 ; bank
            and   #$00FF
            ldx   #$0000
            ldy   #$0000                ; (size $10000: Y = 0, see Reserve)
            jsr   Reserve
            inc   segIdx
            lda   segIdx
            cmp   segCount
            bcc   :rb

            pea   $0000                 ; _MMStartUp: the Master User ID
            ldx   #$0202
            jsl   $E10000
            pla
            sta   userId
            bcc   *+5
            jmp   ErrN

; 3. Zero the banks and load the segments

            stz   segIdx
:seg        jsr   EntryAddr
            lda   HDR,x                 ; bank
            and   #$00FF
            sta   dstBank
            lda   HDR+2,x               ; data length (at most $10000)
            sta   remain
            lda   HDR+4,x
            sta   remain+2
            stz   dstOff

            jsr   ZeroBank

:chunk      lda   remain
            ora   remain+2
            beq   :segdone
            lda   remain+2              ; n = min(remain, BUFLEN)
            bne   :full
            lda   remain
            cmp   #BUFLEN
            bcc   :part
:full       lda   #BUFLEN
:part       sta   rdReq
            lda   #BUF
            sta   rdBuf

            sec                         ; READ, in emulation mode
            xce
            mx    %11
            jsr   MLI
            db    $CA
            da    rdParms
            bcc   *+5
            jmp   Err
            lda   #'.'+$80
            jsr   COUT
            clc
            xce
            rep   #$30
            mx    %00

            lda   rdXfer
            cmp   rdReq
            beq   :xferok
            lda   #$00FE                ; (short read)
            jmp   ErrN
:xferok

            sep   #$20                  ; MVN BUF -> dstBank/dstOff
            lda   dstBank
            sta   :mv+1
            rep   #$20
            ldx   #BUF
            ldy   dstOff
            lda   rdXfer
            dec
            phb
:mv         db    $54,$00,$00           ; mvn (destination bank patched, source bank 0)
            plb

            lda   dstOff
            clc
            adc   rdXfer
            sta   dstOff
            lda   remain
            sec
            sbc   rdXfer
            sta   remain
            lda   remain+2
            sbc   #0
            sta   remain+2
            bra   :chunk

:segdone    inc   segIdx
            lda   segIdx
            cmp   segCount
            bcs   *+5
            brl   :seg

            sec                         ; CLOSE
            xce
            mx    %11
            jsr   MLI
            db    $CC
            da    clParms
            jsr   CROUT

; 4. Start the game

            clc
            xce
            rep   #$30
            mx    %00
            sep   #$20
            lda   HDR+8                 ; entry bank and offset
            sta   :go+3
            rep   #$20
            lda   HDR+6
            sta   :go+1
            lda   #GAME_DP
            tcd
            ldx   #GAME_SP
            txs
            lda   #$3850                ; 'P8'
            sta   $00
            lda   #$5442                ; 'BT'
            sta   $02
            lda   #Quit                 ; the quit vector, $00/Quit
            sta   $04
            stz   $06
            pea   $0000                 ; DBR = 0
            plb
            plb
            lda   userId
            ldx   #0
            ldy   #0
:go         jml   $000000

; The game's quit vector: back to ProDOS 8 (its QUIT shows the prompt for the next program).  Any mode.
            mx    %00
Quit        clc
            xce
            rep   #$30
            pea   $0000
            plb
            plb
            lda   #$0000
            tcd
            ldx   #$01FF
            txs
            sec
            xce
            mx    %11
            jsr   MLI
            db    $65                   ; QUIT
            da    quParms
            brk   $00

; X = the header offset of entry segIdx ($10 + segIdx * 8).  16-bit.
            mx    %00
EntryAddr   lda   segIdx
            asl
            asl
            asl
            clc
            adc   #$10
            tax
            rts

; Reserve memory with the bootstrap ID: A = bank, X = address, Y = size (0 = a whole bank).  16-bit.
            mx    %00
Reserve     sta   rsBank
            stx   rsAddr
            sty   rsSize
            pea   $0000                 ; result
            pea   $0000
            lda   rsSize                ; size (long)
            beq   :bank
            pea   $0000
            pha
            bra   :sz
:bank       pea   $0001
            pea   $0000
:sz         lda   tmpId
            pha
            pea   ATTR_FIXED
            lda   rsBank                ; location (long)
            pha
            lda   rsAddr
            pha
            ldx   #$0902                ; _NewHandle
            jsl   $E10000
            pla
            pla
            bcc   *+5
            jmp   ErrN
            rts

; Zero bank dstBank: two zero bytes at $0000, then MVN them up the bank.  16-bit.
            mx    %00
ZeroBank    sep   #$20
            lda   dstBank
            sta   :z+3
            sta   :zm+1
            sta   :zm+2
            rep   #$20
            lda   #0
:z          stal  $000000
            ldx   #$0000
            ldy   #$0002
            lda   #$FFFD
            phb
:zm         db    $54,$00,$00
            plb
            rts

; Errors: A = the error code.  ErrN from native mode.
            mx    %00
ErrN        sta   errCode
            sec
            xce
            mx    %11
            lda   errCode
Err         pha
            ldx   #msgErr-msgs
            jsr   Print
            pla
            jsr   PRBYTE
:hang       bra   :hang

; Print the message at msgs+X (zero-terminated).  Emulation mode.
            mx    %11
Print       lda   msgs,x
            beq   :done
            ora   #$80
            jsr   COUT
            inx
            bra   Print
:done       rts

msgs        db    $0D
            asc   'LOADING'
            db    0
msgErr      db    $0D
            asc   'LOAD ERROR $'
            db    0

olParms     db    2
olUnit      db    0
            da    volName
volName     ds    17

spParms     db    1
            da    pfxLen
pfxLen      db    0
pfxName     ds    17

opParms     db    3
            da    imgName
            da    IOBUF
opRef       db    0
imgName     str   'GAME.IMG'

rdParms     db    4
rdRef       db    0
rdBuf       da    0
rdReq       da    0
rdXfer      da    0

clParms     db    1
clRef       db    0

quParms     db    4,0
            da    0
            db    0
            da    0

tmpId       dw    0
userId      dw    0
errCode     dw    0
segCount    dw    0
segIdx      dw    0
dstBank     dw    0
dstOff      dw    0
remain      dw    0,0
rsBank      dw    0
rsAddr      dw    0
rsSize      dw    0

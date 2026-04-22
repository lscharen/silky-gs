*--------------------------------------------------------------
* aunit/lib/io.merlin.s  -  GS/OS file I/O helpers (Merlin32)
*
* Merlin32 syntax version of io.s for use when
* config/opts assembler = 'merlin32'.
*
* Include via a PUT directive in your master source file:
*   put  /absolute/path/to/io.merlin.s
*
* Assumes native mode with 16-bit A and X/Y (REP #$30).
*
* loaddata -- Load a file into a memory buffer
*   In:  A = low 16 bits of destination address
*        X = bank byte of destination (as 16-bit word, e.g. $0002)
*        Y = 16-bit offset of filename GSString (must be in bank 0)
*   Out: carry clear = success, carry set = GS/OS error in A
*
* savedata -- Save a memory buffer to the file 'out.dat'
*   In:  A = low 16 bits of source address
*        X = bank byte of source (as 16-bit word, e.g. $0002)
*        Y = byte count (16-bit, up to 65535)
*   Out: carry clear = success, carry set = GS/OS error in A
*--------------------------------------------------------------

*--------------------------------------------------------------
* loaddata
*--------------------------------------------------------------
loaddata
              sta   ldDataBuf        ; destination address low word
              stx   ldDataBuf+2      ; destination bank byte
              sty   ldPathname       ; filename GSString offset (bank 0)
              stz   ldPathname+2     ; filename bank = 0

              jsl   $E100A8          ; OpenGS ($2010)
              dw    $2010
              adrl  ldOpenPB
              bcs   ldError

              lda   ldRefNum
              sta   ldReadRefNum
              sta   ldCloseRefNum

              lda   #$FFFF           ; request count low word
              sta   ldReqCount
              stz   ldReqCount+2

              jsl   $E100A8          ; ReadGS ($2012)
              dw    $2012
              adrl  ldReadPB
              bcs   ldCloseErr

              jsl   $E100A8          ; CloseGS ($2014)
              dw    $2014
              adrl  ldClosePB
              clc
              rtl

ldCloseErr    jsl   $E100A8          ; CloseGS on read error
              dw    $2014
              adrl  ldClosePB
ldError       sec
              rtl

* OpenGS parameter block ($2010)
*   pCount=2: refNum (output), pathname (input)
ldOpenPB      dw    2
ldRefNum      ds    2
ldPathname    ds    4

* ReadGS parameter block ($2012)
*   pCount=4: refNum, dataBuffer, requestCount, transferCount
ldReadPB      dw    4
ldReadRefNum  ds    2
ldDataBuf     ds    4
ldReqCount    ds    4
ldXferCount   ds    4

* CloseGS parameter block ($2014)
*   pCount=1: refNum
ldClosePB     dw    1
ldCloseRefNum ds    2

*--------------------------------------------------------------
* savedata
*--------------------------------------------------------------
savedata
              sta   svDataBuf        ; source address low word
              stx   svDataBuf+2      ; source bank byte
              sty   svReqCount       ; byte count -> requestCount
              stz   svReqCount+2

              jsl   $E100A8          ; CreateGS ($2001)
              dw    $2001
              adrl  svCreatePB
              bcc   svDoOpen
              cmp   #$0047           ; $47 = file already exists, ok
              bne   svError

svDoOpen      jsl   $E100A8          ; OpenGS ($2010)
              dw    $2010
              adrl  svOpenPB
              bcs   svError

              lda   svOpenRefNum
              sta   svWriteRefNum
              sta   svCloseRefNum

              jsl   $E100A8          ; WriteGS ($2013)
              dw    $2013
              adrl  svWritePB
              bcs   svCloseErr

              jsl   $E100A8          ; CloseGS ($2014)
              dw    $2014
              adrl  svClosePB
              clc
              rtl

svCloseErr    jsl   $E100A8          ; CloseGS on write error
              dw    $2014
              adrl  svClosePB
svError       sec
              rtl

* CreateGS parameter block ($2001)
*   pCount=4: pathname, access, fileType, auxType
svCreatePB    dw    4
              adrl  svFilename        ; pathname pointer
              dw    $00C3             ; access: read+write
              dw    $0006             ; fileType: BIN ($06)
              dw    $0000             ; auxType low
              dw    $0000             ; auxType high

* OpenGS parameter block ($2010)
*   pCount=2: refNum (output), pathname (input)
svOpenPB      dw    2
svOpenRefNum  ds    2
              adrl  svFilename

* WriteGS parameter block ($2013)
*   pCount=4: refNum, dataBuffer, requestCount, transferCount
svWritePB     dw    4
svWriteRefNum ds    2
svDataBuf     ds    4
svReqCount    ds    4
svXferCount   ds    4

* CloseGS parameter block ($2014)
*   pCount=1: refNum
svClosePB     dw    1
svCloseRefNum ds    2

* Output filename as GS/OS GSString (length word + chars, no null)
svFilename    dw    7
              asc   'out.dat'

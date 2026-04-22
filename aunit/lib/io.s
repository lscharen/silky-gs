*
* tests/utils/io.s - GS/OS file I/O helpers for unit tests
*
* Assumes native mode with 16-bit A and X/Y (REP #$30 in effect).
*
* loaddata -- Load a file into a memory buffer
*   In:  A   = low 16 bits of destination address
*        X   = bank byte of destination (high word, e.g. $0003 for bank 3)
*        Y   = 16-bit offset of filename GSString (must be in bank 0)
*   Out: carry clear = success, carry set = GS/OS error in A
*        On success the file contents are at the destination address.
*        Reads up to 64 KB; actual bytes read are in ldXferCount.
*
* savedata -- Save a memory buffer to the file 'out.dat'
*   In:  A   = low 16 bits of source address
*        X   = bank byte of source (high word, e.g. $0003 for bank 3)
*        Y   = byte count (16-bit, up to 65535)
*   Out: carry clear = success, carry set = GS/OS error in A
*        Creates 'out.dat' in the current GS/OS prefix if it does not exist.
*
* GS/OS call format (see macros/EDS.GSOS.Macs.s CallGSOS macro):
*   jsl  $E100A8   ; GS/OS dispatcher
*   dw   funcCode  ; function number follows JSL inline
*   adrl paramBlk  ; 32-bit address of parameter block follows
* Carry set on return indicates an error; error code is in A.
*

*------------------------------------------------------
* loaddata
*------------------------------------------------------
loaddata    start

            sta  ldDataBuf      ; destination address low word
            stx  ldDataBuf+2    ; destination bank byte (as 16-bit word)
            sty  ldPathname     ; filename GSString offset (bank 0)
            stz  ldPathname+2   ; filename bank = 0

            jsl  $E100A8        ; OpenGS ($2010)
            dc   i2'$2010'
            dc   i4'ldOpenPB'
            bcs  ldError        ; carry set = GS/OS error

            lda  ldRefNum       ; propagate refNum to read and close records
            sta  ldReadRefNum
            sta  ldCloseRefNum

            lda  #$FFFF         ; request count low word (up to 64 KB)
            sta  ldReqCount
            stz  ldReqCount+2   ; request count high word

            jsl  $E100A8        ; ReadGS ($2012)
            dc   i2'$2012'
            dc   i4'ldReadPB'
            bcs  ldCloseErr

            jsl  $E100A8        ; CloseGS ($2014)
            dc   i2'$2014'
            dc   i4'ldClosePB'
            clc
            rtl

ldCloseErr  jsl  $E100A8        ; CloseGS on read error
            dc   i2'$2014'
            dc   i4'ldClosePB'
ldError     sec
            rtl

*-- OpenGS parameter block ($2010)
*   pCount=2: refNum (output), pathname (input)
ldOpenPB    dc   i2'2'
ldRefNum    ds   2              ; refNum (output)
ldPathname  ds   4              ; pathname pointer (input, set above)

*-- ReadGS parameter block ($2012)
*   pCount=4: refNum, dataBuffer, requestCount, transferCount
ldReadPB    dc   i2'4'
ldReadRefNum ds  2              ; refNum (input)
ldDataBuf   ds   4              ; data buffer pointer (input, set above)
ldReqCount  ds   4              ; request count (input, set above)
ldXferCount ds   4              ; transfer count (output)

*-- CloseGS parameter block ($2014)
*   pCount=1: refNum
ldClosePB   dc   i2'1'
ldCloseRefNum ds 2              ; refNum (input)

            end

*------------------------------------------------------
* savedata
*------------------------------------------------------
savedata    start

            sta  svDataBuf      ; source address low word
            stx  svDataBuf+2    ; source bank byte (as 16-bit word)
            sty  svReqCount     ; byte count -> requestCount low word
            stz  svReqCount+2   ; requestCount high word = 0

            jsl  $E100A8        ; CreateGS ($2001) - create 'out.dat'
            dc   i2'$2001'
            dc   i4'svCreatePB'
            bcc  svDoOpen       ; carry clear = created OK
            cmp  #$0047         ; error $47 = file already exists, acceptable
            bne  svError        ; any other error is fatal

svDoOpen    jsl  $E100A8        ; OpenGS ($2010) - open for writing
            dc   i2'$2010'
            dc   i4'svOpenPB'
            bcs  svError

            lda  svOpenRefNum   ; propagate refNum to write and close records
            sta  svWriteRefNum
            sta  svCloseRefNum

            jsl  $E100A8        ; WriteGS ($2013)
            dc   i2'$2013'
            dc   i4'svWritePB'
            bcs  svCloseErr

            jsl  $E100A8        ; CloseGS ($2014)
            dc   i2'$2014'
            dc   i4'svClosePB'
            clc
            rtl

svCloseErr  jsl  $E100A8        ; CloseGS on write error
            dc   i2'$2014'
            dc   i4'svClosePB'
svError     sec
            rtl

*-- CreateGS parameter block ($2001)
*   pCount=4: pathname, access, fileType, auxType
svCreatePB  dc   i2'4'
            dc   i4'svFilename'    ; pathname pointer
            dc   i2'$00C3'         ; access: allow read and write
            dc   i2'$0006'         ; fileType: BIN ($06)
            dc   i2'$0000,$0000'   ; auxType: 0

*-- OpenGS parameter block ($2010)
*   pCount=2: refNum (output), pathname (input)
svOpenPB    dc   i2'2'
svOpenRefNum ds  2              ; refNum (output)
            dc   i4'svFilename'    ; pathname pointer (static)

*-- WriteGS parameter block ($2013)
*   pCount=4: refNum, dataBuffer, requestCount, transferCount
svWritePB   dc   i2'4'
svWriteRefNum ds 2              ; refNum (input)
svDataBuf   ds   4              ; data buffer pointer (input, set above)
svReqCount  ds   4              ; request count (input, set above)
svXferCount ds   4              ; transfer count (output)

*-- CloseGS parameter block ($2014)
*   pCount=1: refNum
svClosePB   dc   i2'1'
svCloseRefNum ds 2              ; refNum (input)

*-- Output filename as GS/OS GSString (length word + chars, no null)
svFilename  dc   i2'7'
            dc   c'out.dat'

            end

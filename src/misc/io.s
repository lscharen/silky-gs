; Load a data file into the NES ROM space.  Mostly used for battery backup (WRAM) and high score data
;
; LoadROMData reads SAVE_FILENAME.  LoadROMFile reads the file named by any create record.
;
; A = number of bytes to read
; X = 16-bit address in NES ROM space
; Y = create record holding the file name (LoadROMFile only)
;
; Returns C = 0 if the file was read.  C = 1 if it does not exist (e.g. the first run) or could not be
; read; the memory may then be partially loaded.
            mx    %00
LoadROMData
            ldy        #svCreateRec
LoadROMFile
            sta        readRec+8               ; Number of bytes to read
            stz        readRec+10

            stx        readRec+4               ; Load word of target address
            lda        #^ROMBase
            sta        readRec+6

            lda:       2,y                     ; Copy file name to open rec
            sta        openRec+4
            lda:       4,y
            sta        openRec+6

:openFile   _OpenGS    openRec
            bcs        :gsosNoErr
            lda        openRec+2
            sta        readRec+2
            sta        closeRec+2

            _ReadGS    readRec
            php                                ; Close the file even if the read failed (e.g. too short)
            _CloseGS   closeRec
            plp
:gsosNoErr  rts

; Load the preference data
            mx    %00
LoadPrefData
            lda        #{config_block_end-config_block_start}
            sta        readRec+8               ; Number of bytes to read
            stz        readRec+10

            lda        #config_block_start
            sta        readRec+4               ; Load word of target address
            lda        #^config_block_start
            sta        readRec+6

            lda        pfCreateRec+2           ; Copy file name to open rec
            sta        openRec+4
            lda        pfCreateRec+4
            sta        openRec+6

:openFile   _OpenGS    openRec
            bcs        :gsosError
            lda        openRec+2
            sta        eofRec+2
            sta        readRec+2
            sta        closeRec+2

            _ReadGS    readRec
            bcs        :gsosError

:closeFile  _CloseGS   closeRec
            clc
            lda        eofRec+4                ; File Size
            rts

:gsosError  rts


; Save a range of NES memory into a data file.  Mostly used for battery backup (WRAM) and high score data
;
; SaveROMData writes SAVE_FILENAME.  SaveROMFile writes the file named by any create record.
;
; A = number of bytes to write
; X = 16-bit address in NES ROM space
; Y = create record holding the file name (SaveROMFile only)
;
; Returns C = 0 if the file was written, C = 1 if it could not be (nothing is lost but this save)
            mx    %00
SaveROMData
            ldy        #svCreateRec
SaveROMFile
            sta        writeRec+8              ; Number of bytes to write
            stz        writeRec+10

            stx        writeRec+4              ; Load word of target address
            lda        #^ROMBase
            sta        writeRec+6

            sty        :create+6               ; Point the inline CreateGS parameter block at the record
                                               ; (jsl + call number = 6 bytes; same bank as svCreateRec)
:create     _CreateGS  svCreateRec
            bcc        :noError
            cmp        #$0047                  ; File exists error is ok
            bne        :gsosError
:noError

            lda:       2,y                     ; Copy file name to open rec
            sta        openRec+4
            lda:       4,y
            sta        openRec+6

            _OpenGS    openRec
            bcs        :gsosError
            lda        openRec+2
            sta        writeRec+2
            sta        closeRec+2

            _WriteGS   writeRec
            php                                ; Close the file even if the write failed
            _CloseGS   closeRec
            plp
            rts

:gsosError  sec
            rts

; Save the preferences
            mx    %00
SavePrefData
            lda        #{config_block_end-config_block_start}
            sta        writeRec+8              ; Number of bytes to write
            stz        writeRec+10

            lda        #config_block_start
            sta        writeRec+4              ; Load word of target address
            lda        #^config_block_start
            sta        writeRec+6

            _CreateGS  pfCreateRec
            bcc        :noError
            cmp        #$0047                  ; File exists error is ok
            bne        :gsosError0
:noError

            lda        pfCreateRec+2           ; Copy file name to open rec
            sta        openRec+4
            lda        pfCreateRec+4
            sta        openRec+6

            _OpenGS    openRec
            bcs        :gsosError1
            lda        openRec+2
            sta        writeRec+2
            sta        closeRec+2

            _WriteGS   writeRec
            bcs        :gsosError2

            _CloseGS   closeRec
            clc
            rts

:gsosError0 brk        $89
:gsosError1 brk        $8A
:gsosError2 brk        $8B
            rts

svCreateRec dw         4                       ; pCount
            adrl       SAVE_FILENAME           ; filename
            dw         $00C3                   ; access flags (Allow read and write)
            dw         $005D                   ; file type
            dw         $802A,$0000             ; aux type

            DO         HAS_BACKED_WRAM
wrCreateRec dw         4                       ; pCount
            adrl       WRAM_FILENAME           ; filename -- battery-backed WRAM image ($6000-$7FFF)
            dw         $00C3                   ; access flags (Allow read and write)
            dw         $0006                   ; file type (BIN)
            dw         $0000,$0000             ; aux type
            FIN

pfCreateRec dw         4                       ; pCount
            adrl       PREF_FILENAME           ; filename
            dw         $00C3                   ; access flags (Allow read and write)
            dw         $0006                   ; file type
            dw         $0000,$0000             ; aux type

openRec     dw         2                       ; pCount
            ds         2                       ; refNum
            ds         4                       ; filename

eofRec      dw         2                       ; pCount
            ds         2                       ; refNum
            ds         4                       ; eof

readRec     dw         4                       ; pCount
            ds         2                       ; refNum
            ds         4                       ; dataBuffer
            ds         4                       ; requestCount
            ds         4                       ; transferCount

writeRec    dw         4                       ; pCount
            ds         2                       ; refNum
            ds         4                       ; dataBuffer
            ds         4                       ; requestCount
            ds         4                       ; transferCount

closeRec    dw         1                       ; pCount
            ds         2                       ; refNum
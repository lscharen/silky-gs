*--------------------------------------------------------------
* aunit/lib/aunit.merlin.s  -  AUnit assembly runtime (Merlin32)
*
* Merlin32 syntax for use with runAssemblyTest/runGeneratedTest
* when config/opts assembler = 'merlin32'.
*
* Include via a PUT directive in your master source file:
*   put  /absolute/path/to/aunit.merlin.s
*
* io.merlin.s must also be included (provides savedata).
*
* All code assumes REP #$30 (16-bit A and X/Y) is active on
* entry to each routine, exactly as in the ORCA/M version.
*
* MVN uses hardcoded bank $02 because GoldenGate loads S16
* programs at bank $02.  Both source (result buffer) and
* destination (caller memory) are in that same bank.
*
* This file has no segment wrappers (no REL / start / end).
* It is a plain textual include; the enclosing master source
* file provides the REL directive and TYP S16 link file entry.
*
* Call sequence:
*   jsl   AUnit_Init
*   jsl   FunctionUnderTest
*   php                         ; save P immediately after return
*   rep   #$30
*   jsl   AUnit_CaptureRegs     ; appends 'R' record
*   lda   #srcAddr
*   ldx   #byteCount
*   jsl   AUnit_AppendMem       ; appends 'M' record
*   jsl   AUnit_WriteResults    ; writes out.dat
*--------------------------------------------------------------

*--------------------------------------------------------------
* AUnit_Init - stamp header, reset write index and record count.
* Captures program bank into _AU_Bank for use in savedata call.
* Preserves A, X, Y.
*--------------------------------------------------------------
AUnit_Init
              pha
              rep   #$30

              lda   #$5541           ; 'AU'
              sta   _AU_Buf+0
              lda   #$544E           ; 'NT'
              sta   _AU_Buf+2
              lda   #$0001           ; version=1, status=0
              sta   _AU_Buf+4
              lda   #0
              sta   _AU_Buf+6        ; record count placeholder
              sta   _AU_WrIdx
              sta   _AU_RecCount

              sep   #$20
              phk
              pla                    ; pull K byte (8-bit pla)
              rep   #$20
              and   #$00FF
              sta   _AU_Bank

              pla
              rtl

*--------------------------------------------------------------
* AUnit_CaptureRegs - append 'R' register record.
*
* Requirements:
*   REP #$30 active.  Caller did PHP right after the tested
*   function returned, then rep #$30, then jsl AUnit_CaptureRegs.
*   Stack: SP+1..3 = our return addr;  SP+4 = saved P byte.
*
* Returns A, X, Y = tested function's output values.
*--------------------------------------------------------------
AUnit_CaptureRegs
              rep   #$30
              sta   _AU_SA
              txa
              sta   _AU_SX
              tya
              sta   _AU_SY

* P: stack offset +4 behind our 3-byte return address
              lda   4,s
              and   #$00FF
              sta   _AU_SP

* DP
              phd
              pla
              sta   _AU_SDP

* DBR
              sep   #$20
              phb
              pla
              rep   #$20
              and   #$00FF
              sta   _AU_SDBR

* K (program bank)
              sep   #$20
              phk
              pla
              rep   #$20
              and   #$00FF
              sta   _AU_SK

* SP: undo PHP(1) + JSL here(3) = +4
              tsc
              clc
              adc   #4
              sta   _AU_SSP

              ldx   _AU_WrIdx

* emit 'R' tag as low byte of 16-bit write
              lda   #'R'             ; $0052
              sta   _AU_Buf+8,x
              lda   #16
              sta   _AU_Buf+9,x

* emit 8 fields starting at WrIdx+11
              lda   _AU_SA
              sta   _AU_Buf+11,x
              lda   _AU_SX
              sta   _AU_Buf+13,x
              lda   _AU_SY
              sta   _AU_Buf+15,x
              lda   _AU_SP
              sta   _AU_Buf+17,x
              lda   _AU_SDP
              sta   _AU_Buf+19,x
              lda   _AU_SSP
              sta   _AU_Buf+21,x
              lda   _AU_SDBR
              sta   _AU_Buf+23,x
              lda   _AU_SK
              sta   _AU_Buf+25,x

* advance WrIdx by 3 (header) + 16 (payload) = 19
              txa
              clc
              adc   #19
              sta   _AU_WrIdx

              lda   _AU_RecCount
              inc   a
              sta   _AU_RecCount

* restore tested function's outputs
              lda   _AU_SA
              ldx   _AU_SX
              ldy   _AU_SY
              rtl

*--------------------------------------------------------------
* AUnit_AppendMem - append 'M' memory snapshot record.
* Source must reside in the program bank (same as DBR = $02).
*
* In (16-bit mode, DBR = program bank):
*   A = source address (low word)
*   X = byte count (1..32700)
*
* Corrupts A, X, Y.
*--------------------------------------------------------------
AUnit_AppendMem
              rep   #$30
              sta   _AU_MA           ; source address
              txa
              sta   _AU_ML           ; byte count

* payload length = 5 (bank+addr+len) + byteCount
              txa
              clc
              adc   #5
              sta   _AU_MT

              ldx   _AU_WrIdx

* emit 'M' tag
              lda   #'M'             ; $004D
              sta   _AU_Buf+8,x
              lda   _AU_MT
              sta   _AU_Buf+9,x

* mem-record header: bank(1) addrLo(2) length(2)
              lda   _AU_Bank
              sta   _AU_Buf+11,x
              lda   _AU_MA
              sta   _AU_Buf+12,x
              lda   _AU_ML
              sta   _AU_Buf+14,x

* advance WrIdx by 3+5=8
              txa
              clc
              adc   #8
              sta   _AU_WrIdx

              lda   _AU_ML
              beq   _AU_AppMDone

* MVN $02->$02: A=count-1, X=src, Y=dst
              dec   a
              sta   _AU_MT

              ldx   _AU_MA           ; source address

* dst = _AU_Buf+8 + WrIdx
              lda   _AU_WrIdx
              clc
              adc   #_AU_Buf+8
              tay

* advance WrIdx BEFORE mvn clobbers registers
              lda   _AU_WrIdx
              clc
              adc   _AU_ML
              sta   _AU_WrIdx

              lda   _AU_MT           ; count-1
              mvn   $02,$02

_AU_AppMDone
              lda   _AU_RecCount
              inc   a
              sta   _AU_RecCount
              rtl

*--------------------------------------------------------------
* AUnit_AppendValue - append 'V' named 16-bit value record.
*
* In (16-bit mode, DBR = program bank):
*   A = value
*   X = address of name string in program bank (not null-terminated)
*   Y = name length in bytes
*
* Corrupts A, X, Y.
*--------------------------------------------------------------
AUnit_AppendValue
              rep   #$30
              sta   _AU_MA          ; value
              txa
              sta   _AU_SA          ; name address
              tya
              sta   _AU_ML          ; name length

* payload = 1 (nameLen) + nameLen + 2 (value)
              clc
              adc   #3
              sta   _AU_MT

              ldx   _AU_WrIdx

* emit 'V' tag
              lda   #'V'             ; $0056
              sta   _AU_Buf+8,x
              lda   _AU_MT
              sta   _AU_Buf+9,x

* nameLen byte at WrIdx+11
              lda   _AU_ML
              sta   _AU_Buf+11,x

* advance WrIdx by 4 (3 hdr + 1 nameLen byte)
              txa
              clc
              adc   #4
              sta   _AU_WrIdx

              lda   _AU_ML
              beq   _AU_AppVSkip

* MVN for name bytes
              dec   a
              sta   _AU_MT

              ldx   _AU_SA           ; source = name address

              lda   _AU_WrIdx
              clc
              adc   #_AU_Buf+8
              tay

              lda   _AU_WrIdx
              clc
              adc   _AU_ML
              sta   _AU_WrIdx        ; advance before MVN

              lda   _AU_MT
              mvn   $02,$02

_AU_AppVSkip  anop
* write value word at current WrIdx
              ldx   _AU_WrIdx
              lda   _AU_MA
              sta   _AU_Buf+8,x

              lda   _AU_WrIdx
              clc
              adc   #2
              sta   _AU_WrIdx

              lda   _AU_RecCount
              inc   a
              sta   _AU_RecCount
              rtl

*--------------------------------------------------------------
* AUnit_WriteResults - finalize and write out.dat.
* Returns carry set on GS/OS error.
*--------------------------------------------------------------
AUnit_WriteResults
              rep   #$30

              lda   _AU_RecCount
              sta   _AU_Buf+6        ; patch record count

* total bytes = 8 (header) + WrIdx
              lda   _AU_WrIdx
              clc
              adc   #8
              tay                    ; Y = byte count

              lda   #_AU_Buf         ; low 16 bits of buffer addr
              ldx   _AU_Bank         ; program bank captured at Init
              jsl   savedata
              rtl

*--------------------------------------------------------------
* AUnit_Fail - set error status and write results.
* In (16-bit mode): A = error code 1..255
*--------------------------------------------------------------
AUnit_Fail
              and   #$00FF
              sep   #$20
              sta   _AU_Buf+5        ; status byte (8-bit store)
              rep   #$20
              jsl   AUnit_WriteResults
              rtl

*--------------------------------------------------------------
* Scratch variables
*--------------------------------------------------------------
_AU_SA        ds    2                ; saved A / name address
_AU_SX        ds    2
_AU_SY        ds    2
_AU_SP        ds    2                ; saved P flags
_AU_SDP       ds    2
_AU_SSP       ds    2
_AU_SDBR      ds    2
_AU_SK        ds    2
_AU_MA        ds    2                ; address or value scratch
_AU_ML        ds    2                ; length scratch
_AU_MT        ds    2                ; payload length / temp
_AU_WrIdx     ds    2                ; byte offset into _AU_Buf+8
_AU_RecCount  ds    2
_AU_Bank      ds    2                ; program bank captured at AUnit_Init

*--------------------------------------------------------------
* Result buffer (32 KB)
*--------------------------------------------------------------
_AU_Buf       ds    32768

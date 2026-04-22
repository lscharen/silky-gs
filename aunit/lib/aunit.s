*--------------------------------------------------------------
* aunit/lib/aunit.s  -  AUnit assembly runtime library
*
* ORCA/M syntax (GoldenGate iix assemble).
* All functions and shared data live in ONE segment so that
* intra-library 16-bit absolute references resolve at assembly
* time rather than requiring cross-segment linker fixups.
* External callers use JSL (24-bit), which works cross-segment.
*
* CRITICAL: This library stays in REP #$30 (16-bit A and X)
* throughout, because GoldenGate's ORCA assembler does NOT track
* SEP for mode switching.  After rep #$30, any lda #imm is
* assembled as a 3-byte 16-bit immediate even if sep #$20
* precedes it at runtime.  The spurious zero byte would be
* executed as BRK.
*
* Byte fields are written as the low byte of a 16-bit word.
* The adjacent byte (high byte of the word) is either zero
* (payload-len high byte, always 0 for len<=32700) or is
* immediately overwritten by the next field write.
*
* MVN bank: GoldenGate loads OMF at bank $02.  Both source
* addresses (buffer, user data) are in bank $02, so MVN uses
* $02,$02.  _AU_Bank captures the actual K at AUnit_Init time
* for the savedata call.
*
* Call sequence:
*   jsl   AUnit_Init
*   jsl   FunctionUnderTest
*   php                         ; save P immediately after return
*   rep   #$30
*   jsl   AUnit_CaptureRegs     ; appends 'R' record; A/X/Y restored
*   lda   #srcAddr              ; source low-word (bank = program bank)
*   ldx   #byteCount
*   jsl   AUnit_AppendMem       ; appends 'M' record
*   jsl   AUnit_WriteResults    ; writes out.dat
*
* Result packet format (out.dat):
*   [0..3]  'AUNT'  magic
*   [4]     1       version
*   [5]     0       status  (0=ok, nonzero=harness error)
*   [6..7]  count   record count LE16
*   [8..]   records
*
*   Record: tag(1) payloadLen(2-LE16) payload
*     'R' Register payload (16 bytes):
*           A:2 X:2 Y:2 P:2 DP:2 SP:2 DBR:2 K:2
*           (P/DBR/K: low byte = real value, high byte = 0)
*     'M' Memory payload:
*           bank:1 addrLo:2 length:2 data[length]
*     'V' Named-value payload:
*           nameLen:1 name[nameLen] value:2
*--------------------------------------------------------------
AUnit_Lib     start

*--------------------------------------------------------------
* AUnit_Init - stamp header, reset write index and record count.
* Also captures the program bank into _AU_Bank for savedata.
* Preserves A, X, Y.
*--------------------------------------------------------------
AUnit_Init    entry
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

* capture program bank (K register) for savedata bank arg
              sep   #$20
              phk
              pla                    ; pull K byte (8-bit pla, encoding $68 - no immediate)
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
AUnit_CaptureRegs entry
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

* DBR: sep/pla pulls exactly 1 byte (no immediate involved, safe)
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

* emit record header: tag='R' as low byte of 16-bit write,
* high byte ($00) lands at +9 and is overwritten by payload len.
              ldx   _AU_WrIdx

              lda   #'R'             ; = $0052 in 16-bit mode
              sta   _AU_Buf+8,x      ; +8='R', +9=$00 (overwritten next)
              lda   #16
              sta   _AU_Buf+9,x      ; +9=$10, +10=$00

* emit 8 fields (A X Y P DP SP DBR K) starting at WrIdx+11
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
* Source must reside in the program bank (same as DBR).
*
* In (16-bit mode, DBR = program bank):
*   A = source address (low word)
*   X = byte count (1..32700)
*
* Corrupts A, X, Y.
*--------------------------------------------------------------
AUnit_AppendMem entry
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

* record header: 'M' as low byte of 16-bit write
              lda   #'M'             ; = $004D in 16-bit mode
              sta   _AU_Buf+8,x      ; +8='M', +9=$00 (overwritten next)
              lda   _AU_MT
              sta   _AU_Buf+9,x      ; payloadLen at +9,+10

* mem-record header: bank(1) addrLo(2) length(2)
* Write bank as 16-bit; high byte ($00) at +12 overwritten by addrLo low.
              lda   _AU_Bank
              sta   _AU_Buf+11,x    ; bank at +11, $00 at +12
              lda   _AU_MA
              sta   _AU_Buf+12,x    ; source addr low word at +12,+13
              lda   _AU_ML
              sta   _AU_Buf+14,x    ; length at +14,+15

* advance WrIdx by 3+5=8
              txa
              clc
              adc   #8
              sta   _AU_WrIdx

              lda   _AU_ML
              beq   _AU_AppMDone

* MVN $02->$02: A=count-1, X=src, Y=dst
              dec   a
              sta   _AU_MT          ; count-1

              ldx   _AU_MA          ; source address

* dst = _AU_Buf+8+WrIdx (low 16 bits of buffer base + index)
              lda   _AU_WrIdx
              clc
              adc   #_AU_Buf+8      ; assembler uses low 16 bits
              tay

* advance WrIdx BEFORE mvn clobbers registers
              lda   _AU_WrIdx
              clc
              adc   _AU_ML
              sta   _AU_WrIdx

              lda   _AU_MT          ; count-1
              dc    h'540202'        ; mvn $02,$02 — ORCA encodes mvn operands as $00,$00

_AU_AppMDone  lda   _AU_RecCount
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
AUnit_AppendValue entry
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

* header: 'V' as low byte of 16-bit write
              lda   #'V'             ; = $0056 in 16-bit mode
              sta   _AU_Buf+8,x      ; +8='V', +9=$00 (overwritten next)
              lda   _AU_MT
              sta   _AU_Buf+9,x      ; payloadLen at +9,+10

* nameLen byte at WrIdx+11; high byte ($00) at +12 overwritten by name MVN
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
              sta   _AU_MT          ; count-1

              ldx   _AU_SA          ; source = name address

              lda   _AU_WrIdx
              clc
              adc   #_AU_Buf+8
              tay                   ; dst

              lda   _AU_WrIdx
              clc
              adc   _AU_ML
              sta   _AU_WrIdx       ; advance before MVN

              lda   _AU_MT
              dc    h'540202'        ; mvn $02,$02 — ORCA encodes mvn operands as $00,$00

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
AUnit_WriteResults entry
              rep   #$30

              lda   _AU_RecCount
              sta   _AU_Buf+6       ; patch record count

* total bytes = 8 (header) + WrIdx
              lda   _AU_WrIdx
              clc
              adc   #8
              tay                   ; Y = byte count

              lda   #_AU_Buf        ; low 16 bits of buffer addr
              ldx   _AU_Bank        ; program bank (captured at Init)
              jsl   savedata
              rtl

*--------------------------------------------------------------
* AUnit_Fail - set error status and write results.
* In (16-bit mode): A = error code 1..255
*--------------------------------------------------------------
AUnit_Fail    entry
              and   #$00FF
              sep   #$20
              sta   _AU_Buf+5       ; status byte (8-bit store, no immediate)
              rep   #$20
              jsl   AUnit_WriteResults
              rtl

*--------------------------------------------------------------
* Scratch variables
*--------------------------------------------------------------
_AU_SA        ds    2               ; saved A / name address
_AU_SX        ds    2
_AU_SY        ds    2
_AU_SP        ds    2               ; saved P flags
_AU_SDP       ds    2
_AU_SSP       ds    2
_AU_SDBR      ds    2
_AU_SK        ds    2
_AU_MA        ds    2               ; address or value scratch
_AU_ML        ds    2               ; length scratch
_AU_MT        ds    2               ; payload length / temp
_AU_WrIdx     ds    2               ; byte offset into _AU_Buf+8
_AU_RecCount  ds    2
_AU_Bank      ds    2               ; program bank captured at AUnit_Init

*--------------------------------------------------------------
* Result buffer (32 KB)
*--------------------------------------------------------------
_AU_Buf       ds    32768

              end

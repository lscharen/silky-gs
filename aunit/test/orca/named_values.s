*--------------------------------------------------------------
* named_values.s — hand-written AUnit harness
*
* Exercises AUnit_AppendValue: appends two named 16-bit values
* and one register snapshot, then writes results.
*
* Used with runAssemblyTest (ORCA/M).
*--------------------------------------------------------------
        org    $020000
Main    start

        clc
        xce              ; native mode
        rep   #$30       ; 16-bit A and X/Y

        phk
        plb              ; DBR = program bank ($02)

        jsl   AUnit_Init

* --- append named value 'result' = $1234 ---
        lda   #$1234
        ldx   #VName1
        ldy   #VName1Len
        jsl   AUnit_AppendValue

* --- append named value 'count' = $5678 ---
        lda   #$5678
        ldx   #VName2
        ldy   #VName2Len
        jsl   AUnit_AppendValue

* --- capture registers with A=$ABCD ---
        lda   #$ABCD
        php
        phk
        plb
        rep   #$30
        jsl   AUnit_CaptureRegs

        jsl   AUnit_WriteResults
        rtl

VName1      dc    c'result'
VName1Len   equ   *-VName1

VName2      dc    c'count'
VName2Len   equ   *-VName2

        end

        copy  ../../lib/aunit.s
        copy  ../../lib/io.s

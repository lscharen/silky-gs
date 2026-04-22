*--------------------------------------------------------------
* harness_fail.s — hand-written harness that calls AUnit_Fail
*
* Calls AUnit_Fail with error code 2.  This writes an AUNT packet
* with status=2 (ok=false) to out.dat and terminates.
* Used to verify that runAssemblyTest correctly returns ok=false
* with the expected status code.
*--------------------------------------------------------------
        org    $020000
Main    start

        clc
        xce              ; native mode
        rep   #$30       ; 16-bit A and X/Y

        phk
        plb              ; DBR = program bank ($02)

        jsl   AUnit_Init

        lda   #2         ; error code
        jsl   AUnit_Fail

        rtl

        end

        copy  ../../lib/aunit.s
        copy  ../../lib/io.s

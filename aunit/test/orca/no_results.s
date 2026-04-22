*--------------------------------------------------------------
* no_results.s — hand-written harness that omits AUnit_WriteResults
*
* Calls AUnit_Init then returns without ever calling
* AUnit_WriteResults, so out.dat is never written to disk.
* Used to verify that the runner detects the missing file and
* throws AssemblyError with a message containing "out.dat".
*--------------------------------------------------------------
        org    $020000
Main    start

        clc
        xce              ; native mode
        rep   #$30       ; 16-bit A and X/Y

        phk
        plb              ; DBR = program bank ($02)

        jsl   AUnit_Init

        rtl              ; exit without calling AUnit_WriteResults

        end

        copy  ../../lib/aunit.s
        copy  ../../lib/io.s

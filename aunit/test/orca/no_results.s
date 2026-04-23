*--------------------------------------------------------------
* no_results.s — hand-written harness that omits AUnit_WriteResults
*
* Minimal program that exits normally (RTL → iix BRK trap) without
* writing out.dat.  Used to verify that the runner detects the
* missing file and throws AssemblyError mentioning "out.dat".
*--------------------------------------------------------------
        org    $020000
Main    start

        clc
        xce              ; native mode
        rep   #$30       ; 16-bit A and X/Y

        rtl              ; exit without calling AUnit_WriteResults

        end

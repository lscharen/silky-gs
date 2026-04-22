*--------------------------------------------------------------
* harness_fail.s — hand-written harness that calls AUnit_Fail (Merlin32)
*
* Calls AUnit_Fail with error code 2, writing an AUNT packet with
* status=2 (ok=false) to out.dat.
* Used to verify that runAssemblyTest correctly returns ok=false
* and status=2 via the Merlin32 assembler path.
*--------------------------------------------------------------
              rel
              mx    %00               ; 16-bit A and X/Y

Main
              clc
              xce                    ; native mode
              rep   #$30             ; 16-bit A and X/Y

              phk
              plb                    ; DBR = program bank ($02)

              jsl   AUnit_Init

              lda   #2               ; error code
              jsl   AUnit_Fail

              rtl

              put   ../../lib/aunit.merlin.s
              put   ../../lib/io.merlin.s

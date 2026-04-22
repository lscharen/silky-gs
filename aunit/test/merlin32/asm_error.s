*--------------------------------------------------------------
* asm_error.s — intentional Merlin32 assembly error
*
* References an undefined label via JSL.  Merlin32 assembles
* and links in a single step, so an unresolved label causes the
* entire build to fail.  Used to verify that runAssemblyTest
* propagates the error as AssemblyError.
*--------------------------------------------------------------
              rel
              mx    %00

Main
              clc
              xce
              rep   #$30

              jsl   _AUnit_NonExistentLabel99999

              rtl

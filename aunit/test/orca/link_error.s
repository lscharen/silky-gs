*--------------------------------------------------------------
* link_error.s — intentional linker error
*
* This segment calls a label that is not defined anywhere in the
* program.  ORCA/M assembles the reference (treating it as an
* unresolved external) but the linker fails with an undefined-
* symbol error.  Used to verify that runAssemblyTest propagates
* linker failures as AssemblyError.
*--------------------------------------------------------------
LinkError     start
              jsl   _AUnit_NonExistentLabel99999
              rtl
              end

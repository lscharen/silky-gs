*--------------------------------------------------------------
* asm_error.s — intentional assembler error
*
* This file deliberately causes ORCA/M to fail during the assemble
* step by copying a file that does not exist.  Used to verify that
* runAssemblyTest / runGeneratedTest propagates the error as
* AssemblyError with a message referencing the assemble step.
*--------------------------------------------------------------
AsmError      start
              rtl
              end
              copy  _nonexistent_file_do_not_create_.s

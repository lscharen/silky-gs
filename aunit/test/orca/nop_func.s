*--------------------------------------------------------------
* nop_func.s — function under test
*
* Returns A, X, Y unchanged via RTL.
* Used to verify that the generated harness round-trips registers
* correctly without any arithmetic side-effects.
*--------------------------------------------------------------
NopFunc       start
              rtl
              end

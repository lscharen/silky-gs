*--------------------------------------------------------------
* double_a.s — function under test (Merlin32)
*
* Doubles the 16-bit accumulator (ASL A) and returns via RTL.
* Plain include file — no segment wrappers.
*--------------------------------------------------------------
DoubleA
              asl   a
              rtl

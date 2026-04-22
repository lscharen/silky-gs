*--------------------------------------------------------------
* double_a.s — function under test
*
* Doubles the 16-bit accumulator (ASL A) and returns via RTL.
* Tests arithmetic, carry flag, and zero flag round-trip.
*--------------------------------------------------------------
DoubleA       start
              asl    a
              rtl
              end

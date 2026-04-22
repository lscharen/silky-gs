*--------------------------------------------------------------
* return_x_in_a.s — function under test
*
* Copies X to A (TXA) and returns via RTL.
* Tests that the X register is correctly passed into the harness
* and that TXA produces the expected A value.
*--------------------------------------------------------------
ReturnXInA    start
              txa
              rtl
              end

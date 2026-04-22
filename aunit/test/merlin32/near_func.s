*--------------------------------------------------------------
* near_func.s — function under test (Merlin32, near-call convention)
*
* Doubles A (ASL A) and returns via RTS.
* Plain include file.  Used to exercise the jsr calling convention
* in cpu65816 with the Merlin32 assembler path.
*--------------------------------------------------------------
NearFunc
              asl   a
              rts

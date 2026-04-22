*--------------------------------------------------------------
* near_func.s — function under test (near call / RTS convention)
*
* Doubles A (ASL A) and returns via RTS.
* Used to exercise the jsr calling convention in cpu65816 — the
* generated harness emits JSR instead of JSL, and this function
* must return with RTS (16-bit return address on stack).
*--------------------------------------------------------------
NearFunc      start
              asl    a
              rts
              end

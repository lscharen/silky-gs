; MOUSE driver: the ADB mouse as an NES Zapper (INPUT_MOUSE, _ReadMouse1 / 2 in core/CoreImpl.s)
;
; This file is the only code that touches the mouse hardware.  It polls the GLU's mouse registers
; directly, with no firmware and no tool calls: $C027 bit 7 says a mouse report is waiting, and $C024 then
; reads its two bytes, X first and Y second (the ADB micro copies the mouse's Talk R0 reply straight to the
; GLU: docs/adb/adb_rom01.asm POLL_MOUSE).  Each byte's bits 0 - 6 are a 7-bit two's complement delta; bit
; 7 of the Y byte is the button, 0 = down (bit 7 of the X byte is a second button, not used).  The second
; read clears the report, so a report is read whole, and $C027 bit 1 says which byte the next read gives.
; The deltas move a pointer kept in SHR screen coordinates (0 - 319, 0 - 199).
;
; The Zapper: the trigger is PAD_RIGHT and the light sense is PAD_LEFT (the game's own code turns them into
; the $4017 bits).  The light sense is a sprite under the pointer in the sprites the NES shows, not the
; IIgs screen: the Zapper games check the light within one NES frame, which the renderer doesn't keep up
; with, and they draw their targets as sprites on a black screen for it (Duck Hunt's white boxes).  The
; NES shows the OAM page as it was at the last OAM DMA ($4014), not as the game has changed it since
; (Duck Hunt hides its boxes in NES RAM before its second light check, while the NES still shows them),
; so Mouse_OamDma (from PPUDMA_WRITE) copies the page then, while a shot can be under way: from the press
; until MOUSE_SHOT_FRAMES DMAs after the release.  The pad's light sense is the one at the press, kept
; while the button is held and dropped when it is released.
;
; The pointer is drawn by the game, as a sprite: Mouse_AddPointer from its PRE_RENDER hook.  The sprite is
; kept in the playfield (MOUSE_PTR_X_MAX / Y_MAX), and the light sense is taken at its hot spot.
;
; The mouse interrupt ($C027 bit 6) is turned off the first time the driver is used, so that no firmware
; handler takes the reports, and put back by Mouse_ShutDown.

; Built when the game's Config.s sets MOUSE_ZAPPER (INPUT_MOUSE: core/Defs.s), which must then also set
; MOUSE_OAM_SLOTS: the OAM slots, from slot 0, that the game draws its light targets in.  The file's sep / rep
; pairs are balanced, so the MX state after it is the same when it is skipped.
                  DO        MOUSE_ZAPPER

; The mouse hardware this file uses (8-bit reads only: both are read-sensitive)
MOUSE_DATA_REG    equ   $E0C024       ; The report: the X delta, then the Y delta and the button
MOUSE_STATUS_REG  equ   $E0C027       ; The GLU status: bit 7 a report is waiting, bit 6 the mouse
                                      ; interrupt is on, bit 1 the next $C024 read is the Y byte
MOUSE_STATUS_FULL equ   $80
MOUSE_STATUS_IRQ  equ   $40
MOUSE_STATUS_Y    equ   $02
MOUSE_BUTTON_UP   equ   $80           ; The Y byte: bit 7 = 1 while the button is up

MOUSE_MAX_X       equ   319           ; The pointer's range: the SHR screen
MOUSE_MAX_Y       equ   SHR_SCREEN_HEIGHT-1

MOUSE_PTR_HOT_X   equ   0             ; The hot spot: the pointer sprite's pixel on the pointer
MOUSE_PTR_HOT_Y   equ   0
MOUSE_PTR_X_MAX   equ   256-8         ; The pointer sprite's top left corner, relative to the playfield's
MOUSE_PTR_Y_MAX   equ   200-9         ; (SHR byte x_offset, line 0): 0 - X_MAX, 0 - Y_MAX

MOUSE_SHOT_FRAMES equ   30            ; OAM DMAs after the release that Mouse_OamDma still copies

; Mouse_Pad
;
; The driver's pad routine (_ReadMouse, core/CoreImpl.s): X = the player's configuration block, Y = the
; player (0 / 1), both unused (there is one mouse).  Returns A = PAD_RIGHT while the button is held, with
; PAD_LEFT if a sprite was under the pointer when it went down, and 0 while the button is up.
; 16-bit registers, DBR = the main bank.
                mx %00
Mouse_Pad         lda       mouseOn
                  bne       :on
                  jsr       Mouse_StartUp
:on               jsr       mousePoll
                  lda       mouseButton
                  beq       :up
                  lda       mousePad
                  bne       :out                ; Held: the light sense of the press
                  jsr       mouseSense          ; Just pressed: look at the sprites
                  ora       #PAD_RIGHT
                  sta       mousePad
:out              rts

:up               lda       mousePad
                  beq       :idle
                  lda       #MOUSE_SHOT_FRAMES  ; Just released: the game checks the light after this
                  sta       mouseShot
                  lda       #0                  ; The light sense goes with the button
                  sta       mousePad
:idle             rts

; Mouse_OamDma
;
; The OAM DMA ($4014 write, PPUDMA_WRITE): copy the page the NES now shows into mouseOam, for the light
; sense, while a shot can be under way (the button held, or mouseShot DMAs after the release).  A = the
; page (low byte).  Called with JML from PPUDMA_WRITE (its return address is the shim's JSL), with
; 8-bit registers and the game's data bank; returns with RTL, the registers as they were.
                mx %11
Mouse_OamDma      ENT
                  php
                  rep       #$30
                mx %00
                  phb
                  pha
                  phx
                  phy
                  phk
                  plb
                  and       #$00FF
                  tay                           ; (the page)
                  lda       mouseButton
                  bne       :copy
                  lda       mouseShot
                  beq       :out
                  dec       mouseShot
:copy             tya
                  xba
                  ora       #{MOUSE_OAM_SLOTS-1}*4
                  tax                           ; X = the page's last entry in the ROMBase bank
                  ldy       #{MOUSE_OAM_SLOTS-1}*4
:loop             ldal      ROMBase,x
                  sta       mouseOam,y
                  ldal      ROMBase+2,x
                  sta       mouseOam+2,y
                  dex
                  dex
                  dex
                  dex
                  dey
                  dey
                  dey
                  dey
                  bpl       :loop
:out              ply
                  plx
                  pla
                  plb
                  plp
                  rtl

; Mouse_StartUp
;
; Turn off the mouse interrupt, drop a report left waiting, and put the pointer in the middle of the
; screen.  Called by Mouse_Pad the first time.  16-bit registers, DBR = the main bank.
                mx %00
Mouse_StartUp     sep       #$20
                  ldal      MOUSE_STATUS_REG
                  and       #MOUSE_STATUS_IRQ
                  sta       mouseIrq            ; (for Mouse_ShutDown)
                  beq       :irq_off
                  ldal      MOUSE_STATUS_REG
                  and       #$FF-MOUSE_STATUS_IRQ
                  stal      MOUSE_STATUS_REG
:irq_off          ldal      MOUSE_STATUS_REG
                  bpl       :empty
                  and       #MOUSE_STATUS_Y
                  bne       :last               ; Only the Y byte is left
                  ldal      MOUSE_DATA_REG
:last             ldal      MOUSE_DATA_REG
:empty            rep       #$20
                  lda       #MOUSE_MAX_X/2
                  sta       mouseX
                  lda       #MOUSE_MAX_Y/2
                  sta       mouseY
                  stz       mouseButton
                  stz       mousePad
                  lda       #1
                  sta       mouseOn
                  rts

; Mouse_ShutDown
;
; Put the mouse interrupt back on if Mouse_StartUp turned it off (NES_ShutDown).  16-bit registers, DBR =
; the main bank.
                mx %00
Mouse_ShutDown    lda       mouseOn
                  beq       :out
                  stz       mouseOn
                  sep       #$20
                  lda       mouseIrq
                  beq       :done
                  ldal      MOUSE_STATUS_REG
                  ora       #MOUSE_STATUS_IRQ
                  stal      MOUSE_STATUS_REG
:done             rep       #$20
:out              rts

; Mouse_AddPointer
;
; Show the pointer: add an 8x8 sprite to this render (PPU_AddSprite, drawn under the game's sprites) with
; its hot spot (MOUSE_PTR_HOT_X / Y) on the pointer, kept in the playfield (mousePtrPos).  Nothing until the
; driver is in use.  Call from PRE_RENDER.  A = the sprite's tile (low byte) and attributes (high byte).
; 16-bit registers, DBR = the main bank.
                mx %00
Mouse_AddPointer  ldx       mouseOn
                  beq       :out
                  sta       mousePtrTile
                  jsr       mousePtrPos         ; A = the sprite's NES X, X = its line in the playfield
                  phx
                  xba                           ; X = the attributes | NES X << 8
                  sep       #$20
                  lda       mousePtrTile+1
                  rep       #$20
                  tax
                  pla                           ; The sprite's OAM Y: the playfield starts at NES line
                  clc                           ; y_offset, and the sprite's top line is OAM Y + 1
                  adc       #y_offset-1
                  sep       #$20                ; A = OAM Y | the tile << 8
                  xba
                  lda       mousePtrTile
                  xba
                  rep       #$20
                  jsl       PPU_AddSprite
:out              rts

; Mouse_SenseL
;
; The light sense now, for a game that reads it itself (Duck Hunt's light sense loops), rather than the
; pad's, which is the one at the press: A = 0 if a sprite in the game's OAM is under the pointer, $08 if
; not (the Zapper's $4017 bit 3), and $08 until the driver is in use.  Called with JSL, in any
; register widths and with any data bank and direct page; returns with them, X and Y as they were (A in
; the caller's width).
                mx %00
Mouse_SenseL      ENT
                  php
                  rep       #$30
                  phb
                  phx
                  phy
                  phk
                  plb
                  lda       mouseOn
                  beq       :dark
                  jsr       mouseSense          ; A = PAD_LEFT if light (Z from it; X is trashed)
                  bne       :lit
:dark             ldx       #$08                ; Not light
                  bra       :out
:lit              ldx       #0
:out              stx       mouseLight
                  ply
                  plx
                  plb
                  plp
                  ldal      mouseLight
                  rtl

; Read the waiting mouse report, if there is one: move the pointer (clamped to the screen) and set
; mouseButton (non-zero = down).  With no report, the pointer and the button stay as they are.
                mx %00
mousePoll         sep       #$20
                  ldal      MOUSE_STATUS_REG
                  bpl       :none               ; No report
                  and       #MOUSE_STATUS_Y
                  bne       :y                  ; Out of step: only the Y byte is left
                  ldal      MOUSE_DATA_REG      ; The X delta
                  rep       #$20
                  jsr       mouseDelta
                  clc
                  adc       mouseX
                  bpl       :x_pos
                  lda       #0
:x_pos            cmp       #MOUSE_MAX_X+1
                  bcc       :x_ok
                  lda       #MOUSE_MAX_X
:x_ok             sta       mouseX
                  sep       #$20

:y                ldal      MOUSE_DATA_REG      ; The Y delta and the button
                  rep       #$20
                  pha
                  jsr       mouseDelta
                  clc
                  adc       mouseY
                  bpl       :y_pos
                  lda       #0
:y_pos            cmp       #MOUSE_MAX_Y+1
                  bcc       :y_ok
                  lda       #MOUSE_MAX_Y
:y_ok             sta       mouseY
                  pla
                  and       #MOUSE_BUTTON_UP
                  eor       #MOUSE_BUTTON_UP    ; Non-zero = down
                  sta       mouseButton
:none             rep       #$20
                  rts

; A = a report byte (bits 8 - 15 are ignored): returns its 7-bit delta, sign-extended to 16 bits
                mx %00
mouseDelta        and       #$007F
                  eor       #$0040              ; $00 - $3F -> $40 - $7F, $40 - $7F -> $00 - $3F
                  sec
                  sbc       #$0040              ; -> $0000 - $003F, $FFC0 - $FFFF
                  rts

; The pointer sprite's position: returns A = its NES X (0 - MOUSE_PTR_X_MAX) and X = its top line in the
; playfield (0 - MOUSE_PTR_Y_MAX; NES line y_offset is the playfield's line 0), with its hot spot on the
; pointer (SHR screen coordinates) where that keeps it in that box.  No memory is written: the GS and NES
; tasks both call it.
                mx %00
mousePtrPos       lda       mouseY
                  sec
                  sbc       #MOUSE_PTR_HOT_Y
                  bpl       :y_pos
                  lda       #0
:y_pos            cmp       #MOUSE_PTR_Y_MAX+1
                  bcc       :y_ok
                  lda       #MOUSE_PTR_Y_MAX
:y_ok             tax
                  lda       mouseX              ; The playfield starts at SHR byte x_offset
                  sec
                  sbc       #{2*x_offset}+MOUSE_PTR_HOT_X
                  bpl       :x_pos
                  lda       #0
:x_pos            cmp       #MOUSE_PTR_X_MAX+1
                  bcc       :x_ok
                  lda       #MOUSE_PTR_X_MAX
:x_ok             rts

; Returns A = PAD_LEFT if an 8x8 sprite the NES shows (mouseOam: the OAM page at the last DMA, not the
; renderer's latched copy) covers the pointer sprite's hot spot, 0 if not, with Z set from A.  Any
; sprite counts, whatever its color.  Nothing is light while the game's last PPUMASK write has the sprites
; off: the screen is dark then even with the sprites in OAM (Duck Hunt's first light check, which drops
; the shot if it sees light, runs with the boxes already in OAM and the sprites and background off).
; 16-bit registers, DBR = the main bank.  X is trashed.
                mx %00
mouseSense        ldal      ppumask             ; The game's PPUMASK (not the latched _ppumask)
                  and       #$0010              ; The sprites are shown
                  beq       :dark
                  jsr       mousePtrPos         ; The hot spot's NES coordinates
                  clc
                  adc       #MOUSE_PTR_HOT_X
                  pha                           ; (3,s) its X
                  txa
                  clc
                  adc       #y_offset-1+MOUSE_PTR_HOT_Y
                  pha                           ; (1,s) its line - 1, to compare with OAM Y (top line - 1)
                  ldx       #{MOUSE_OAM_SLOTS-1}*4
:loop             lda       mouseOam,x          ; Y and the tile
                  and       #$00FF
                  eor       #$FFFF
                  sec
                  adc       1,s                 ; line - 1 - OAM Y: 0 - 7 on the sprite's lines
                  cmp       #8
                  bcs       :next
                  lda       mouseOam+2,x        ; The attributes and X
                  xba
                  and       #$00FF
                  eor       #$FFFF
                  sec
                  adc       3,s                 ; x - OAM X: 0 - 7 on the sprite's columns
                  cmp       #8
                  bcc       :hit
:next             dex
                  dex
                  dex
                  dex
                  bpl       :loop
                  lda       #0
                  bra       :out
:hit              lda       #PAD_LEFT
:out              plx
                  plx
                  cmp       #0
                  rts
:dark             lda       #0
                  rts

mouseOn           dw        0                   ; Non-zero once Mouse_StartUp has run
mouseIrq          dw        0                   ; MOUSE_STATUS_IRQ if the mouse interrupt was on (low byte)
mouseX            dw        0                   ; The pointer, in SHR screen coordinates
mouseY            dw        0
mouseButton       dw        0                   ; Non-zero while the button is down (mousePoll)
mousePad          dw        0                   ; While the button is held: PAD_RIGHT, and PAD_LEFT if the
                                                ; press saw light (the cached light sense); 0 while up
mousePtrTile      dw        0                   ; Mouse_AddPointer: the tile and attributes
mouseLight        dw        0                   ; Mouse_SenseL: the answer
mouseShot         dw        0                   ; Mouse_OamDma: the DMAs left to copy after a release
mouseOam          ds        MOUSE_OAM_SLOTS*4   ; The OAM page at the last DMA (its first slots), during a shot
                  FIN

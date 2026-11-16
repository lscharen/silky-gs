; Core engine functionality.  The idea is that that source file can be PUT into
; a main source file and all of the functionality will be available.
;
; There are some constants that must be externally defined that can affect how
; the runtime works
;
; NO_MUSIC      : Set to non-zero to avoid using any source
; NO_INTERRUPTS : Set to non-zero to avoid installing custom interrupt handlers

                  mx        %00

; Assumes the direct page is set and EngineMode and UserId has been initialized
_CoreStartUp
                  jsr       IntStartUp          ; Enable certain interrupts
                  bcs       :core_err1

                  jsr       InitMemory          ; Allocate and initialize memory for the engine
                  bcs       :core_err2

                  jsr       EngineReset         ; All of the resources are allocated, put the engine in a known state
                  jsr       InitGraphics        ; Initialize all of the graphics-related data

; Once the graphics arrays and core engine data is set up, prep the PEA field as if a render has already
; happened.  This is to put everything in a valid state because other wise if the code tried to render
; it would see that the x and p positions did not change from zero and some critical dispatch information
; would not get filled in.

                  clc
                  rts
:core_err1
                  brk $e1
                  rts
:core_err2
                  brk $e2
                  rts

_CoreShutDown
                  jsr       IntShutDown
                  rts

; Install interrupt handlers.  We use the VBL interrupt to keep animations
; moving at a consistent rate, regarless of the rendered frame rate.  The 
; one-second timer is generally just used for counters and as a handy 
; frames-per-second trigger.
IntStartUp
                  DO        NO_INTERRUPTS
                  ELSE

                  PushLong  #0
                  pea       $0015               ; Get the existing 1-second interrupt handler and save
                  _GetVector
                  PullLong  OldOneSecVec
                  bcs       :error1

                  pea       $0015               ; Set the new handler and enable interrupts
                  PushLong  #OneSecHandler
                  _SetVector
                  bcs       :error2

                  pea       $0006
                  _IntSource
                  bcs       :error3

                  pea       $0002               ; VBL interrupts on (the scheduler runs on them)
                  _IntSource
                  bcs       :error4

                  jsr       InstallIrqHandlers  ; The scheduler (IRQ.VBL) and the joystick (irqHook): rom_exec.s
                  bcs       :error5
                  bra       :done
:error1           brk       $c1
:error2           brk       $c2
:error3           brk       $c3
:error4           brk       $c4
:error5           brk       $c5
:done
                  FIN
                  rts

IntShutDown
                  DO        NO_INTERRUPTS
                  ELSE

                  jsr       RemoveIrqHandlers

                  pea       $0007               ; disable 1-second interrupts
                  _IntSource

                  pea       $0015
                  PushLong  OldOneSecVec        ; Reset the interrupt vector
                  _SetVector

                  FIN
                  rts

OldOneSecVec      ds   4

; The 1-second interrupt handler.  The VBL is handled by irqVbl (rom/rom_exec.s).
OneSecHandler     mx        %11
                  ldal      OneSecondCounter    ; Increment the count
                  inc
                  stal      OneSecondCounter

                  ldal      frameCount          ; Capture and reset the frame counter
                  stal      framesPerSecond
                  lda       #0
                  stal      frameCount

                  lda       #%10111111          ; Clear IRQ source
                  stal      $E0C032
                  clc
                  rtl

                  mx        %00

; Reset the engine to a known state
; Blitter initialization
EngineReset
                  lda       #200
                  sta       ScreenHeight
                  lda       #128
                  sta       ScreenWidth

                  stz       ScreenY0
                  stz       ScreenY1
                  stz       ScreenX0
                  stz       ScreenX1

                  stz       ScrollX
                  stz       ScrollY
                  stz       ScrollNT
                  stz       StartX
                  stz       StartY
                  stz       StartRow

                  lda       #$FFFF                 ; Mark as needing a full update
                  sta       DirtyBits

                  stz       LastRender             ; Initialize as if a full render was performed


                  lda       #CTRL_EVEN_RENDER
                  sta       ControlBits
                  stz       ControlBits

                  stz       OneSecondCounter
                  stz       LastKey

                  stz       frameCount

; Fill in the state register values

                  sep       #$20
                  ldal      STATE_REG
                  and       #$CF                       ; R0W0
                  sta       STATE_REG_R0W0             ; Put this value in to return to "normal" blitter
                  ora       #$10                       ; R0W1
                  sta       STATE_REG_BLIT             ; Running the blitter, this is the mode to put us into
                  sta       STATE_REG_R0W1
                  ora       #$20                       ; R1W1
                  sta       STATE_REG_R1W1

; Cache the bank for the PPU shadow RAM

                  lda       #^PPU_MEM
                  sta       PPU_BANK

                  rep       #$20

; The engine's own start-up (a blitter's banks, say)

                  jsl       EngineStartUpL

; Done initializing the engine

                  clc
                  rts

; A setting that changes how the engine renders has changed (the FAST BLIT option, the joystick's probes)
_InitRenderMode
                  jsl       EngineRenderModeL
                  rts


; Input routines.
;
; These are a bit tricky because we will always poll the keyboard in order to pass non-controller keystrokes
; back to the runtime. These keystrokes will be replicated for both players.
;
; The rest of the bits will be filled in by the configured input selector for each player


; Read the keyboard and paddle controls and return in a game-controller-like format.  A new key press
; that a player's keyboard map uses (kbdHandled) is a control, not a built-in key: it is taken out of
; KeyEvent so that the event loop doesn't act on it, except '?' (the configuration screen must stay
; reachable whatever the keys are set to).
                mx %00
_ReadControl
                  stz       kbdHandled
                  jsr       _KbdPoll             ; The keyboard layer: new key presses for the event loop (rom/rom_kbd_basic.s)
                  sta       LastKey              ; The most recent key, for the engine
                  sta       InputPlayer1
                  sta       InputPlayer2         ; Replicate the raw keyboard info into both players' input values
                  DO        KBD_J13
                  jsr       J13_Poll             ; The held keys, if the J13 keyboard driver is set (rom/rom_kbd_j13.s)
                  FIN

; Now read the specific input device for each player

                  ldx       config_input_p1_type ; Load the input type for player 1
                  jsr       (:input_proc1,x)
                  tsb       InputPlayer1

                  ldx       config_input_p2_type
                  jsr       (:input_proc2,x)
                  tsb       InputPlayer2

                  lda       kbdHandled
                  beq       :out
                  lda       kbdNewKey
                  beq       :out
                  ldal      KeyEvent
                  and       #$007F
                  cmp       #'?'
                  beq       :out
                  lda       #0
                  stal      KeyEvent
:out              lda       InputPlayer1
                  rts

kbdHandled        dw        0                   ; Non-zero if a player's keyboard map uses this poll's key

:input_proc1      dw        _ReadKeyboard1,_ReadSNESMAX1
                  DO        JOYSTICK_SUPPORT
                  dw        _ReadJoystick1      ; INPUT_JOYSTICK
                  FIN
                  DO        MOUSE_ZAPPER
                  DO        1-JOYSTICK_SUPPORT
                  dw        _ReadKeyboard1      ; (INPUT_JOYSTICK, not built)
                  FIN
                  dw        _ReadMouse1         ; INPUT_MOUSE
                  FIN
:input_proc2      dw        _ReadKeyboard2,_ReadSNESMAX2
                  DO        JOYSTICK_SUPPORT
                  dw        _ReadJoystick2
                  FIN
                  DO        MOUSE_ZAPPER
                  DO        1-JOYSTICK_SUPPORT
                  dw        _ReadKeyboard2
                  FIN
                  dw        _ReadMouse2
                  FIN

; Player Input Configuration offsets
PLAYER_INPUT_TYPE      equ 0
PLAYER_INPUT_KEY_LEFT  equ 2
PLAYER_INPUT_KEY_RIGHT equ 4
PLAYER_INPUT_KEY_UP    equ 6
PLAYER_INPUT_KEY_DOWN  equ 8
PLAYER_INPUT_SNESMAX_PORT equ 10
PLAYER_INPUT_BUTTON_A  equ 12
PLAYER_INPUT_BUTTON_B  equ 14
PLAYER_INPUT_KEY_UL    equ 46         ; The diagonal keys, after the original block (config_input_key_ul,
PLAYER_INPUT_KEY_UR    equ 48         ; rom/rom_config_setup.s checks the offsets)
PLAYER_INPUT_KEY_DL    equ 50
PLAYER_INPUT_KEY_DR    equ 52

; The KEYBOARD input type: the full pad, from the keyboard driver set on the DRIVERS menu
; (config_kbd_driver).
;
; A keyboard driver's pad routine (KbdDriverPad) is called once per player on every poll, with
;   X = the player's configuration block (PLAYER_INPUT_*)
;   Y = the player: 0 / 1
; Nothing is passed in from the keyboard: each driver reads the keyboard hardware itself.
; and returns A = the full pad (the high byte: PAD_BUTTON_A / B, PAD_START, ..., PAD_RIGHT).  It sets
; kbdHandled if the key is one of the player's keys (a control, not a built-in key: _ReadControl).
; 16-bit registers, DBR = the main bank; X and Y need not be preserved.
                mx %00
_ReadKeyboard1    ldx       #config_block_p1
                  ldy       #0
                  bra       _ReadKeyboard

_ReadKeyboard2    ldx       #config_block_p2
                  ldy       #1

_ReadKeyboard     phx                           ; The configuration block
                  lda       config_kbd_driver
                  cmp       #KBD_DRIVER_COUNT*2
                  bcc       *+5
                  lda       #KBD_DRIVER_BASIC   ; (an unknown driver in the preferences)
                  tax
                  lda       KbdDriverPad,x
                  sta       :driver+1
                  lda       1,s
                  tax
:driver           jsr       $0000
                  tax                           ; Never opposite directions (they break games): a driver
                  and       #PAD_LEFT+PAD_RIGHT ; picks one, this is only a safety net
                  cmp       #PAD_LEFT+PAD_RIGHT
                  bne       :lr_ok
                  txa
                  and       #$FFFF-PAD_LEFT-PAD_RIGHT
                  tax
:lr_ok            txa
                  and       #PAD_UP+PAD_DOWN
                  cmp       #PAD_UP+PAD_DOWN
                  bne       :ud_ok
                  txa
                  and       #$FFFF-PAD_UP-PAD_DOWN
                  tax
:ud_ok            txa
                  plx
                  rts

; The keyboard drivers' pad routines, by KBD_DRIVER_* / 2 (a driver that isn't built: BASIC's)
KbdDriverPad      dw        KbdBasic_Pad        ; KBD_DRIVER_BASIC (rom/rom_kbd_basic.s)
                  DO        KBD_J13
                  dw        KbdJ13_Pad          ; KBD_DRIVER_J13 (rom/rom_kbd_j13.s)
                  FIN
                  DO        1-KBD_J13
                  dw        KbdBasic_Pad
                  FIN
                  DO        KBD_ADB
                  dw        KbdAdb_Pad          ; KBD_DRIVER_ADB (rom/rom_kbd_adb.s)
                  FIN
                  DO        1-KBD_ADB
                  dw        KbdBasic_Pad
                  FIN
KBD_DRIVER_COUNT  equ       {*-KbdDriverPad}/2

; The joystick (INPUT_JOYSTICK): its directions (JoyGetPadL, core/blitter/JoyProbes.s), on top of the
; player's keyboard map (Start, Select, and the keys still work), and its buttons: the push button
; switches, mapped as the player's A / B (PAD_PUSH_BUTTONS, rom/rom_kbd_macs.s)
                  DO        JOYSTICK_SUPPORT
_ReadJoystick1    jsr       _ReadKeyboard1
                  ldx       #config_block_p1
                  bra       _ReadJoystick
_ReadJoystick2    jsr       _ReadKeyboard2
                  ldx       #config_block_p2
_ReadJoystick     PAD_PUSH_BUTTONS
                  pha
                  jsl       JoyGetPadL
                  ora       1,s
                  sta       1,s
                  pla
                  rts
                  FIN

; The mouse as a Zapper (INPUT_MOUSE): the trigger (PAD_RIGHT) and the light sense (PAD_LEFT) from
; Mouse_Pad (rom/rom_mouse.s), on top of the player's keyboard map without its left / right (Start,
; Select and the other keys still work).  Mouse_Pad's two bits are left together: this doesn't go through
; _ReadKeyboard's opposite-directions check.
                  DO        MOUSE_ZAPPER
_ReadMouse1       jsr       _ReadKeyboard1
                  ldx       #config_block_p1
                  ldy       #0
                  bra       _ReadMouse
_ReadMouse2       jsr       _ReadKeyboard2
                  ldx       #config_block_p2
                  ldy       #1
_ReadMouse        and       #$FFFF-PAD_LEFT-PAD_RIGHT
                  pha
                  jsr       Mouse_Pad
                  ora       1,s
                  sta       1,s
                  pla
                  rts
                  FIN

; Read the sensmax controller input from the configured slot n
;
; Registers: $C0{8+n}0 -- write to set latch pulse
;            $C0{8+n}0 -- read one bit at a time. Bit 7 = controller 1, Bit 6 = controller2
;            $C0{8+n}1 -- write to set clock pulse
;
; Byte 0 Buttons
;  Bit0 Right
;  Bit1 Left
;  Bit2 Down
;  Bit3 Up
;  Bit4 Start
;  Bit5 Select
;  Bit6 Y
;  Bit7 B
;
;Byte 1 Buttons
;  Bit0 Not used (Same as button not pressed)
;  Bit1 Not used (Same as button not pressed)
;  Bit2 Not used (Same as button not pressed)
;  Bit3 Not used (Same as button not pressed)
;  Bit4 Front Right
;  Bit5 Front Left
;  Bit6 X
;  Bit7 A
                mx %00
_ReadSNESMAX1     lda      InputPlayer1
                  ldx       #config_block_p1
                  jsr      _ReadSNESMAX
                  ora      SNESMAX_P1
                  rts

_ReadSNESMAX2     lda      InputPlayer2
                  ldx       #config_block_p2
                  jsr      _ReadSNESMAX
                  ora      SNESMAX_P2
                  rts

SNESMAX_P1        dw       0
SNESMAX_P2        dw       0

_ReadSNESMAX
                  php
                  sei

                  pha                           ; low byte = key code, high byte = %ABsSUDLR  S = Start, s = select
                  sep      #$20

                  lda:     PLAYER_INPUT_SNESMAX_PORT,x    ; Set to 1 - 7
                  asl
                  asl
                  asl
                  asl
                  and      #$70

                  sep      #$30
                  tax

                  ldy      #8
                  stal     $E0C080,x           ; clock the latch
:loop
                  ldal     $E0C080,x           ; first read
                  eor      #$C0                ; Invert the read bits to mark pressed buttons with a 1 instead of 0
                  rol
                  rol      SNESMAX_P1+1
                  rol
                  rol      SNESMAX_P2+1
                  stal     $E0C081,x           ; clock the shift register
                  dey
                  bne      :loop

                  rep      #$30
                  pla
                  plp
                  rts

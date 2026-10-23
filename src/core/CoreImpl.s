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

; Cache the bank values of the blitter banks

                  lda       #^lite_base_1
                  sta       BANK_VALUES
                  lda       #^lite_base_2
                  sta       BANK_VALUES+1
                  rep       #$20

                  tdc
                  ora       #BANK_VALUES-1
                  sta       STK_SAVE_BANK              ; Save the address of the direct page variables

                  lda       #^tiledata
                  xba
                  ora       #$0001
                  sta       CMPL_BANK

; One-time patching of the blitter code banks (interrupt windows and the optional even-line mode)

                  jsr       _InitLiteBlitter

; Done initializing the engine

                  clc
                  rts

; One-time patching of the blitter banks.  Nothing here depends on the mirroring mode; the only
; values changed are the operands of the exit JMPs that chain one line to the next.
;
; Every 16 lines, a line's exits jump to the interrupt window of the next line instead of its
; normal entry point.  There are 120 lines in each bank and interrupts are enabled after lines
; 4, 20, 36, 52, 68, 84 and 100.
;
; If CTRL_EVEN_RENDER is set, the even lines exit to the line after next, so only half of the
; lines are drawn.  Line 118 jumps to line 119's JML into the other bank, so line 119 is skipped
; as well.  The skipped lines are the odd code rows, which are the odd screen lines that
; _BltRangeLite assumes as long as StartRow + y_offset is even.
;
; All of the exits are rewritten, so this can be called again whenever CTRL_EVEN_RENDER changes.
FIRST_PAGE        equ       $100       ; PEA code starts at $0100 in each respective bank
_InitRenderMode
_InitLiteBlitter
:step             equ       tmp15

                  lda       #_LINE_SPAN
                  sta       :step

                  ldx       #0                   ; Every line continues to the next line
:row_loop         txa
                  clc
                  adc       #FIRST_PAGE+_LINE_SPAN+_ENTRY_OFFSET
                  jsr       :patch_exits

                  txa
                  clc
                  adc       #_LINE_SPAN
                  tax
                  cpx       #{119*_LINE_SPAN}    ; The last line in each bank is a JML to the other bank
                  bcc       :row_loop

                  lda       ControlBits
                  bit       #CTRL_EVEN_RENDER
                  beq       :int

                  asl       :step                ; Skip every other line

                  ldx       #0
:even_loop        txa
                  clc
                  adc       #FIRST_PAGE+{2*_LINE_SPAN}+_ENTRY_OFFSET
                  jsr       :patch_exits

                  txa
                  clc
                  adc       #2*_LINE_SPAN
                  tax
                  cpx       #{118*_LINE_SPAN}
                  bcc       :even_loop

; Line 118 skips line 119 too: its exits go straight to line 119's JML into the other bank, so the
; odd line 119 is not drawn and the next bank continues on its even line 0
                  ldx       #{118*_LINE_SPAN}
                  lda       #FIRST_PAGE+{119*_LINE_SPAN}+_E_JMP_OFFSET
                  jsr       :patch_exits

:int              ldx       #{4*_LINE_SPAN}
:int_loop         txa
                  clc
                  adc       #FIRST_PAGE+_INT_OFFSET
                  adc       :step
                  jsr       :patch_exits

                  txa
                  clc
                  adc       #16*_LINE_SPAN
                  tax
                  cpx       #{116*_LINE_SPAN}
                  bcc       :int_loop

                  DO        JOYSTICK_SUPPORT
                  jsl       JoyInstallProbesL    ; Hook the joystick probe rows into the exits set above
                  FIN
                  rts

; Set the next-line target of both exits of the line at offset X in both banks
:patch_exits      stal      lite_start_page_1+_E_JMP_OFFSET+1,x
                  stal      lite_start_page_1+_O_JMP_OFFSET+1,x
                  stal      lite_start_page_2+_E_JMP_OFFSET+1,x
                  stal      lite_start_page_2+_O_JMP_OFFSET+1,x
                  rts

                mx %00
WaitForKey        sep       #$20
                  stal      KBD_STROBE_REG      ; clear the strobe
:WFK              ldal      KBD_REG
                  bpl       :WFK
                  rep       #$20
                  and       #$007F
                  rts

                mx %00
ClearKbdStrobe    sep       #$20
                  stal      KBD_STROBE_REG
                  rep       #$20
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
                  stz       kbdNewKey
                  stz       kbdHandled
                  jsr       _ReadKeypress        ; Always poll for a keystroke
                  sta       InputPlayer1
                  sta       InputPlayer2         ; Replicate the raw keyboard info into both players' input values
                  jsr       J13_Poll             ; The held keys, if the J13 keyboard driver is set (rom/rom_kbd_j13.s)

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

kbdNewKey         dw        0                   ; Non-zero if this poll saw a new key press (_ReadKeypress)
kbdHandled        dw        0                   ; Non-zero if a player's keyboard map uses this poll's key

:input_proc1      dw        _ReadKeyboard1,_ReadSNESMAX1
                  DO        JOYSTICK_SUPPORT
                  dw        _ReadJoystick1      ; INPUT_JOYSTICK
                  FIN
:input_proc2      dw        _ReadKeyboard2,_ReadSNESMAX2
                  DO        JOYSTICK_SUPPORT
                  dw        _ReadJoystick2
                  FIN

; Reset the keypress state to clear the current keypress and set up to wait until the next key
; is pressed to regiter
                mx %00
_ClearKeypress
                  stz       LastKey
                  rts

                mx %00
_ReadRawKeypress
                  pea       $0000               ; temporary space
                  sep       #$20

                  ldal      KBD_REG             ; read the keyboard
                  bit       #$80                ; was the strobe bit set? If yes, then this is a new key
                  beq       :done

                  stal      KBD_STROBE_REG      ; reset the strobe
                  and       #$7F                ; isolate the key code
                  sta       LastKey
                  ora       #PAD_KEY_DOWN       ; set the keydown flag
                  sta       1,s

:done
                  rep       #$20
                  pla
                  rts

; Poll the keyboard and return the current keypress in the lower 7 bits and the KEY_DOWN
; status in the high bit. This routine does apply debounce logic.
                mx %00
_ReadKeypress
                  pea       $0000               ; temporary space
                  sep       #$20

                  ldal      KBD_REG             ; read the keyboard
                  bit       #$80                ; was the strobe bit set? If yes, then this is a new key
                  beq       :no_new_key

                  jsr       KbdAdb_FixKey       ; (the ADB driver's shifted hotkeys, rom/rom_kbd_adb.s)
                  sta       LastKey
                  sta       1,s
                  sta       kbdNewKey           ; (for _ReadControl)
                  stal      KeyEvent            ; a new press, for the event loop (NES_TakeKey)
                  stal      j13New              ; and for the J13 keyboard driver (J13_Poll)
                  ldal      MOD_REG             ; with the modifiers of the key (read before the strobe is
                  stal      KeyEvent+1          ; reset, while they still belong to it)
                  stal      KBD_STROBE_REG      ; reset the strobe
                  bra       :done               ; return the key value

:no_new_key
                  ldal      KBD_STROBE_REG      ; see if the key is being held
                  bit       #$80
                  beq       :no_key_down

; The held key is the last one pressed.  Its code stays in $C000 bits 0-6 after the strobe is cleared,
; so take it from there rather than from LastKey: if something else cleared the strobe first (e.g. a
; keyboard interrupt handler left installed by an INIT or CDA), LastKey never saw the key.
                  ldal      KBD_REG
                  ora       #$80                ; same value as when the key was new (LastKey keeps bit 7)
                  sta       LastKey
                  sta       1,s
                  bra       :done

:no_key_down
                  stz       LastKey             ; If no key is currently pressed, set the 'active' key to 0

:done
                  rep       #$20

;                  lda   1,s
;                  ldx   #32*160
;                  ldy   #$FFFF
;                  jsr   DrawWord

                  pla
                  rts

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

; The KEYBOARD input type: the directions, Start and Select from the keyboard driver set on the DRIVERS menu
; (config_kbd_driver), the buttons from the command and option keys (_KbdButtons).
;
; A keyboard driver's pad routine (KbdDriverPad) is called once per player on every poll, with
;   A = the key (_ReadKeypress: bit 7 set if a key was just pressed or one is down, the last key pressed
;       in bits 0 - 6; every player gets the same key)
;   X = the player's configuration block (PLAYER_INPUT_*)
;   Y = the player: 0 / 1
; and returns A = the pad bits (the high byte: PAD_UP, ..., PAD_START, PAD_SELECT; no buttons).  It sets
; kbdHandled if the key is one of the player's keys (a control, not a built-in key: _ReadControl).
; 16-bit registers, DBR = the main bank; X and Y need not be preserved.
                mx %00
_ReadKeyboard1    ldx       #config_block_p1
                  ldy       #0
                  bra       _ReadKeyboard

_ReadKeyboard2    ldx       #config_block_p2
                  ldy       #1

_ReadKeyboard     phx                           ; The configuration block, for the buttons
                  lda       config_kbd_driver
                  cmp       #KBD_DRIVER_COUNT*2
                  bcc       *+5
                  lda       #KBD_DRIVER_BASIC   ; (an unknown driver in the preferences)
                  tax
                  lda       KbdDriverPad,x
                  sta       :driver+1
                  lda       1,s
                  tax
                  lda       InputPlayer1        ; The key (both players have it)
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
                  jmp       _KbdButtons

; The keyboard drivers' pad routines, by KBD_DRIVER_* / 2
KbdDriverPad      dw        KbdBasic_Pad        ; KBD_DRIVER_BASIC (rom/rom_kbd_basic.s)
                  dw        KbdJ13_Pad          ; KBD_DRIVER_J13 (rom/rom_kbd_j13.s)
                  dw        KbdAdb_Pad          ; KBD_DRIVER_ADB (rom/rom_kbd_adb.s)
KBD_DRIVER_COUNT  equ       {*-KbdDriverPad}/2

; A = the pad bits, X = the player's configuration block: returns A with the buttons of the player's
; command / option keys added
_KbdButtons       pha
                  sep       #$20

                  ldal      MOD_REG             ; Load all of the modifiers
                  bit:      PLAYER_INPUT_BUTTON_A,x
                  beq       :a_is_not_pressed
                  bit:      PLAYER_INPUT_BUTTON_B,x
                  beq       :b_is_not_pressed 
                  lda       #>{PAD_BUTTON_B+PAD_BUTTON_A}
                  bra       :apply_opt
:b_is_not_pressed
                  lda       #>{PAD_BUTTON_A}
                  bra       :apply_opt
:a_is_not_pressed
                  bit:      PLAYER_INPUT_BUTTON_B,x
                  beq       :no_buttons
                  lda       #>{PAD_BUTTON_B}

:apply_opt        ora       2,s
                  sta       2,s

:no_buttons       rep       #$20
                  pla
                  rts

; The joystick (INPUT_JOYSTICK): its directions (JoyGetPadL, core/blitter/JoyProbes.s) and buttons 0 / 1
; ($C061 / $C062: A / B), on top of the player's keyboard map (Start, Select, and the keys still work)
                  DO        JOYSTICK_SUPPORT
_ReadJoystick1    jsr       _ReadKeyboard1
                  bra       _ReadJoystick
_ReadJoystick2    jsr       _ReadKeyboard2
_ReadJoystick     pha
                  jsl       JoyGetPadL
                  ora       1,s
                  sta       1,s
                  sep       #$20
                  ldal      $E0C061             ; Button 0
                  bpl       :no_a
                  lda       #>PAD_BUTTON_A
                  ora       2,s
                  sta       2,s
:no_a             ldal      $E0C062             ; Button 1
                  bpl       :no_b
                  lda       #>PAD_BUTTON_B
                  ora       2,s
                  sta       2,s
:no_b             rep       #$20
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

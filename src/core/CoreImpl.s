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

                  PushLong  #VBLTASK            ; Also register a Heart Beat Task
                  _DelHeartBeat

                  PushLong  #VBLTASK            ; Also register a Heart Beat Task
                  _SetHeartBeat
                  bcs       :error4

                  jsr       InstallIrqHook      ; Lets the scheduler switch tasks after an interrupt
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

                  jsr       RemoveIrqHook

                  pea       $0007               ; disable 1-second interrupts
                  _IntSource

                  PushLong  #VBLTASK            ; Remove our heartbeat task
                  _DelHeartBeat

                  pea       $0015
                  PushLong  OldOneSecVec        ; Reset the interrupt vector
                  _SetVector

                  FIN
                  rts

OldOneSecVec      ds   4

; Interrupt handlers. We install a heartbeat (1/60th second and a 1-second timer)
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

; This is OK, it's referenced by a long address
VBLTASK           hex       00000000
TaskCnt           dw        1
                  hex       5AA5
VblTaskCode       mx        %11
                  lda       #1
                  stal      TaskCnt            ; Reset the task count
                  DO        NO_INTERRUPTS
                  rtl
                  ELSE
                  jml       schedTask          ; Run the NES/IIgs task scheduler
                  FIN
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

; The KEYBOARD input type, through the keyboard driver set on the DRIVERS menu (config_kbd_driver): BASIC maps
; the current keypress to directional bits, J13 the held keys; both read the command and option registers
; for buttons
                mx %00
_ReadKeyboard1    ldx       #config_block_p1
                  ldy       #0                  ; Player 1's half of kbdMaps
                  lda       config_kbd_driver
                  cmp       #KBD_DRIVER_J13
                  beq       _ReadKeyboardJ13
                  lda       InputPlayer1
                  jmp       _ReadKeyboard

_ReadKeyboard2    ldx       #config_block_p2
                  ldy       #$80                ; Player 2's half of kbdMaps
                  lda       config_kbd_driver
                  cmp       #KBD_DRIVER_J13
                  beq       _ReadKeyboardJ13
                  lda       InputPlayer2
                  jmp       _ReadKeyboard

; J13: the directions, Start and Select from every held key (J13_Pad), the buttons as for BASIC
_ReadKeyboardJ13  phx
                  jsr       J13_Pad
                  pha
                  jsr       _KbdJ13Handled
                  pla
                  plx
                  pha
                  lda       #0                  ; no key: _ReadKeyboard only reads the buttons
                  jsr       _ReadKeyboard
                  ora       1,s
                  plx
                  rts

; J13: set kbdHandled if the key (InputPlayer1's low byte: every player has it) is one of the player's
; keys (j13Ids, set by J13_Pad), compared as J13 does, by ADB key code
_KbdJ13Handled    lda       InputPlayer1
                  bit       #PAD_KEY_DOWN
                  beq       :out
                  and       #PAD_KEY_MASK
                  tax
                  lda       J13_ADBKeys,x
                  and       #$00FF
                  ldx       #10
:loop             cmp       j13Ids,x
                  beq       :handled
                  dex
                  dex
                  bpl       :loop
:out              rts
:handled          lda       #1
                  sta       kbdHandled
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

; BASIC: the key in A (from _ReadKeypress: bit 7 set if a key was just pressed or one is down, the last
; key pressed in bits 0 - 6) becomes the pad bits of its kbdMaps entry.  One key gives at most one
; direction, so never two opposite ones, and nothing is kept from one poll to the next: no key down is no
; direction, and a key pressed and released between two polls still counts once.  Called with X = the
; configuration block (the buttons) and Y = the player's half of kbdMaps ($00 / $80).
_ReadKeyboard     pha                           ; low byte = key code, high byte = %ABsSUDLR  S = Start, s = select
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
                  lda       1,s                 ; the key
                  bit       #PAD_KEY_DOWN
                  beq       :done               ; none
                  and       #PAD_KEY_MASK
                  phy
                  ora       1,s                 ; in this player's map
                  ply
                  tax
                  sep       #$20
                  lda       kbdMaps,x
                  beq       :unmapped
                  sta       kbdHandled          ; (non-zero: a control, not a built-in key)
                  ora       2,s
                  sta       2,s
:unmapped         rep       #$20
:done             pla
                  rts

; kbdMaps
;
; The BASIC keyboard driver's key maps (_ReadKeyboard): the pad bits (the high byte: PAD_UP, PAD_START,
; ...) of each key code ($00 - $7F), player 1's then player 2's.  Built by KbdBuildMaps from the players'
; keys, so that a key reads the same whatever modifiers were held when it was pressed (the modifiers can
; be buttons, and $C000 keeps the code the key had when it went down):
;
;   - the player's direction keys, then Tab (Select) and Return (Start), as they are
;   - then, for a letter, its other case (Shift, Caps Lock) and its Control code, unless that is an arrow
;     key's code (Control-H, J, K and U are $08, $0A, $0B and $15): every key goes to both players, so
;     player 2's J (left) would otherwise also be player 1's down arrow
;
; An entry already set is kept, so the keys as set come first.
kbdMaps           ds        256

kbdPlayer         dw        0                   ; KbdBuildMaps: the player's half of kbdMaps
kbdBlock          dw        0                   ; ... the player's configuration block
kbdBits           dw        0                   ; ... the key's pad bits
kbdCode           dw        0                   ; ... the key

; The direction keys' offsets in a configuration block and their pad bits
KbdKeys           dw        PLAYER_INPUT_KEY_DOWN,PAD_DOWN/256
                  dw        PLAYER_INPUT_KEY_UP,PAD_UP/256
                  dw        PLAYER_INPUT_KEY_LEFT,PAD_LEFT/256
                  dw        PLAYER_INPUT_KEY_RIGHT,PAD_RIGHT/256
KbdKeysEnd

; KbdBuildMaps
;
; Build kbdMaps from the players' keys.  Called at start-up (after the preferences are loaded) and by
; ApplyConfig.  16-bit registers, DBR = the main bank.
                mx %00
KbdBuildMaps
                  ldx       #256-2
:clear            stz       kbdMaps,x
                  dex
                  dex
                  bpl       :clear
                  ldx       #config_block_p1
                  lda       #0
                  jsr       :player
                  ldx       #config_block_p2
                  lda       #$80

:player           sta       kbdPlayer
                  stx       kbdBlock
                  ldy       #0                  ; The direction keys
:exact            jsr       :key
                  jsr       :set
                  iny
                  iny
                  iny
                  iny
                  cpy       #KbdKeysEnd-KbdKeys
                  bcc       :exact
                  lda       #PAD_SELECT/256
                  sta       kbdBits
                  lda       #9                  ; Tab
                  jsr       :set
                  lda       #PAD_START/256
                  sta       kbdBits
                  lda       #13                 ; Return
                  jsr       :set

                  ldy       #0                  ; The letters' other case and Control code
:alias            jsr       :key
                  and       #$007F
                  sta       kbdCode
                  and       #$005F              ; Upper case
                  cmp       #'A'
                  bcc       :next
                  cmp       #'Z'+1
                  bcs       :next
                  lda       kbdCode
                  eor       #$0020
                  jsr       :set
                  lda       kbdCode
                  and       #$001F
                  jsr       :ctrl
:next             iny
                  iny
                  iny
                  iny
                  cpy       #KbdKeysEnd-KbdKeys
                  bcc       :alias
                  rts

; Y = the KbdKeys entry: returns the player's key in A, and its pad bits in kbdBits
:key              lda       KbdKeys+2,y
                  sta       kbdBits
                  lda       KbdKeys,y
                  clc
                  adc       kbdBlock
                  tax
                  lda:      0,x
                  rts

; A = a letter's Control code: as :set, unless it is an arrow key's code
:ctrl             cmp       #LEFT_ARROW
                  beq       :arrow
                  cmp       #RIGHT_ARROW
                  beq       :arrow
                  cmp       #UP_ARROW
                  beq       :arrow
                  cmp       #DOWN_ARROW
                  bne       :set
:arrow            rts

; A = a key code: give it kbdBits, unless it has pad bits already
:set              and       #$007F
                  ora       kbdPlayer
                  tax
                  sep       #$20
                  lda       kbdMaps,x
                  bne       :taken
                  lda       kbdBits
                  sta       kbdMaps,x
:taken            rep       #$20
                  rts

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

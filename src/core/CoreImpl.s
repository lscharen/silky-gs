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
                  jml       nmiTask            ; Jump to the NES NMI interrupt emulation
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

                  stz       DirtyState
                  stz       DebugSCB
                  stz       LastRender             ; Initialize as if a full render was performed


                  lda       #CTRL_EVEN_RENDER
                  sta       ControlBits
                  stz       ControlBits

                  stz       OneSecondCounter
                  stz       LastKey

                  lda       #1                     ; $0000 is a sentinel address, so start at $0001 for
                  sta       SpriteBankPos          ; compiled sprites

                  stz       frameCount             ; Maintain which shadow bitmap to use for a given frame
                  lda       #shadowBitmap0
                  sta       CurrShadowBitmap
                  lda       #shadowBitmap1
                  sta       PrevShadowBitmap

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
; lines are drawn.  Line 118 still continues to line 119, which jumps to the other bank.
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
                  rts

; Set the next-line target of both exits of the line at offset X in both banks
:patch_exits      stal      lite_start_page_1+_E_JMP_OFFSET+1,x
                  stal      lite_start_page_1+_O_JMP_OFFSET+1,x
                  stal      lite_start_page_2+_E_JMP_OFFSET+1,x
                  stal      lite_start_page_2+_O_JMP_OFFSET+1,x
                  rts

; Mirroring
;
; The PEA field rows map 1:1 onto the CIRAM pages, so a mirroring change only needs to update the
; address masks and the V flag that is used to enter the blitter.  Nothing in the code field is
; patched, so these are cheap enough to call whenever a mapper changes the mirroring mode.
;
; The scroll values derived by _UpdateScrollStart and the entry and exit points in the code field
; depend on the mirroring mode, so a change updates them and forces a full setup of the code field
; on the next render.
;
; With horizontal mirroring each line stays within one CIRAM page, which creates a virtual 256x480
; rendering surface.
_InitHorizontalMirroring
                  lda       #HORIZONTAL_MIRROR_MASK
                  sta       MirrorMaskLong
                  lda       #$07E0
                  sta       CIRAMRowMask         ; V = 0x3E0, H = 0x7E0
                  lda       #$001F
                  sta       CIRAMColMask         ; V = $041F, H = $001F

                  lda       #480
                  sta       MaxY
                  lda       #256
                  sta       MaxX

                  lda       #BLT_P_HORZ          ; V = 1: lines loop within their CIRAM page
                  sta       BltMirrorP

                  jsr       _UpdateScrollStart   ; The scroll values depend on the mirroring
                  lda       #DIRTY_BIT_BG0_X
                  tsb       DirtyBits
                  rts

; With vertical mirroring each line spans both CIRAM pages, which creates a virtual 512x240
; rendering surface.
_InitVerticalMirroring
                  lda       #VERTICAL_MIRROR_MASK
                  sta       MirrorMaskLong
                  lda       #$03E0
                  sta       CIRAMRowMask         ; V = 0x3E0, H = 0x7E0
                  lda       #$041F
                  sta       CIRAMColMask         ; V = $041F, H = $001F

                  lda       #240
                  sta       MaxY
                  lda       #512
                  sta       MaxX

                  stz       BltMirrorP           ; V = 0: lines continue into the other CIRAM page

                  jsr       _UpdateScrollStart   ; The scroll values depend on the mirroring
                  lda       #DIRTY_BIT_BG0_X
                  tsb       DirtyBits
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


; Read the keyboard and paddle controls and return in a game-controller-like format
                mx %00
_ReadControl
                  jsr       _ReadKeypress        ; Always poll for a keystroke
                  sta       InputPlayer1
                  sta       InputPlayer2         ; Replicate the raw keyboard info into both players' input values

; Now read the specific input device for each player

                  ldx       config_input_p1_type ; Load the input type for player 1
                  jsr       (:input_proc1,x)
                  tsb       InputPlayer1

                  ldx       config_input_p2_type
                  jsr       (:input_proc2,x)
                  tsb       InputPlayer2

                  lda       InputPlayer1
                  rts

:input_proc1      dw        _ReadKeyboard1,_ReadSNESMAX1
:input_proc2      dw        _ReadKeyboard2,_ReadSNESMAX2

; Reset the keypress state to clear the current keypress and set up to wait until the next key
; is pressed to regiter
                mx %00
_ClearKeypress
                  stz       LastKey
                  rts

; Acknowledge that a keypress has been read.  This is similar to physically clearing
; the keyboard strobe and will clear the PAD_KEY_DOWN bit, which is held so that a new
; keypress can be picked up by the user code on a differnt frame than the initial read
                mx %00
_AckKeypress
                  lda       LastKey
                  and       #$FF7F
                  sta       LastKey
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

                  stal      KBD_STROBE_REG      ; reset the strobe
                  sta       LastKey
                  sta       1,s
                  bra       :done               ; return the key value

:no_new_key
                  ldal      KBD_STROBE_REG      ; see if the key is being held
                  bit       #$80
                  beq       :no_key_down

                  lda       LastKey             ; otherwise place the last key value as the current keypress
                  sta       1,s                 ; without PAD_KEY_DOWN flag set
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

; Map the current keypress to directional bits and read the command and option registers for buttons
                mx %00
_ReadKeyboard1    lda       InputPlayer1
                  ldx       #config_block_p1
                  jmp       _ReadKeyboard

_ReadKeyboard2    lda       InputPlayer2
                  ldx       #config_block_p2
                  jmp       _ReadKeyboard

; Called with the X-register set to the configuration block
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

:no_buttons
                  lda       1,s                 ; read the current keypress
                  and       #$7F
                  cmp:      PLAYER_INPUT_KEY_DOWN,x
                  bne       :not_down
                  lda       #>PAD_DOWN
                  ora       2,s
                  bra       :done

:not_down
                  cmp:      PLAYER_INPUT_KEY_UP,x
                  bne       :not_up
                  lda       #>PAD_UP
                  ora       2,s
                  bra       :done

:not_up
                  cmp:      PLAYER_INPUT_KEY_LEFT,x
                  bne       :not_left
                  lda       #>PAD_LEFT
                  ora       2,s
                  bra       :done

:not_left
                  cmp:      PLAYER_INPUT_KEY_RIGHT,x
                  bne       :not_right
                  lda       #>PAD_RIGHT
                  ora       2,s
                  bra       :done

:not_right
                  cmp       #9           ; TAB
                  bne       :not_select
                  lda       #>PAD_SELECT
                  ora       2,s
                  bra       :done

:not_select
                  cmp       #13          ; Return
                  bne       :not_start
                  lda       #>PAD_START
                  ora       2,s
                  bra       :done

:not_start
                  lda       #0                       ; no key matches the configured directions
:done
                  ora       2,s
                  sta       2,s
                  rep       #$20
                  pla

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

; Sprite plane data and mask banks are provided as an external segment
;
; The sprite data holds a set of pre-rendered sprites that are optimized to support the rendering pipeline.  There
; are four copies of each sprite, along with the cooresponding mask laid out into 4x4 tile regions where the
; empty row and column is shared between adjacent blocks.
;
; Logically, the memory is laid out as 4 columns of sprites and 4 rows.
;
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   |   |   |   |   |   |   |   |   |   |   |   | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   | 0 | 0 |   | 1 | 1 |   | 2 | 2 |   | 3 | 3 | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   | 0 | 0 |   | 1 | 1 |   | 2 | 2 |   | 3 | 3 | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   |   |   |   |   |   |   |   |   |   |   |   | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   | 4 | 4 |   | 5 | 5 |   | 6 | 6 |   | 7 | 7 | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   | 4 | 4 |   | 5 | 5 |   | 6 | 6 |   | 7 | 7 | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   |   |   |   |   |   |   |   |   |   |   |   | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
;
; For each sprite, when it needs to be copied into an on-screen tile, it could exist at any offset compared to its
; natural alignment.  By having a buffer around the sprite data, an address pointer can be set to a different origin
; and a simple 8x8 block copy can cut out the appropriate bit of the sprite.  For example, here is a zoomed-in look
; at a sprite with an offset, O, at (-2,-3).  As shown, by selecting an appropriate origin, just the top corner
; of the sprite data will be copied.
;
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |           ||           |   ||   |   |   |   ||   |   |   |   |
; +---+-- O----------------+ --+---++---+---+---+---++---+---+---+---+..
; |   |   |                |   |   ||   |   |   |   ||   |   |   |   |
; +---+-- |                | --+---++---+---+---+---++---+---+---+---+..
; |   |   |                |   |   ||   |   |   |   ||   |   |   |   |
; +---+-- |                | --+---++---+---+---+---++---+---+---+---+..
; |   |   |                |   |   ||   |   |   |   ||   |   |   |   |
; +===+== |       ++===+== | ==+===++===+===+===+===++===+===+===+===+..
; |   |   |       ||   | S | S | S || S | S | S |   ||   |   |   |   |
; +---+-- +----------------+ --+---++---+---+---+---++---+---+---+---+..
; |   |           || S | S   S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +===+===+===+===++===+===+===+===++===+===+===+===++===+===+===+===+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   ||   | S | S | S || S | S | S |   ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .
;
; Each sprite will take up, effectively 9 tiles of storage space per 
; instance (plus edges) and there are 4 instances for the H/V bits
; and 4 more for the masks.  This results in a need for 43,264 bytes
; for all 16 sprites.

spritedata        EXT
spritemask        EXT

; Core engine functionality.  The idea is that that source file can be PUT into
; a main source file and all of the functionality will be available.
;
; There are some constancts that must be externally defined that can affect how
; the GTE runtime works
;
; NO_MUSIC      : Set to non-zero to avoid using any source
; NO_INTERRUPTS : Set to non-zero to avoid installing custom interrupt handlers

                  mx        %00

; Assumes the direct page is set and EngineMode and UserId has been initialized
_CoreStartUp
                  jsr       IntStartUp          ; Enable certain interrupts
                  bcs       :core_err

                  jsr       InitMemory          ; Allocate and initialize memory for the engine
                  bcs       :core_err

                  jsr       EngineReset         ; All of the resources are allocated, put the engine in a known state
                  jsr       InitGraphics        ; Initialize all of the graphics-related data

; Once the graphics arrays and core engine data is set up, prep the PEA field as if a render has already
; happened.  This is to put everything in a valid state because other wise if the code tried to render
; it would see that the x and p positions did not change from zero and some critical dispatch information
; would not get filled in.

;                  jsr       _ApplyBG0YPosLite
;                  jsr       _ApplyBG0XPosLite
;                  jsr       _RestoreBG0OpcodesLite
                  clc
                  rts
:core_err
                  brk $ee
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
                  bcs       :error

                  pea       $0015               ; Set the new handler and enable interrupts
                  PushLong  #OneSecHandler
                  _SetVector
                  bcs       :error

                  pea       $0006
                  _IntSource
                  bcs       :error

                  PushLong  #VBLTASK            ; Also register a Heart Beat Task
                  _SetHeartBeat
                  bcs       :error
                  bra       :done
:error
                  brk        $e0
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
                  ldal      OneSecondCounter
                  inc
                  stal      OneSecondCounter

                  lda       #%10111111          ;clear IRQ source
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

                  lda       #25
                  sta       ScreenTileHeight
                  lda       #32
                  sta       ScreenTileWidth

                  stz       StartX
                  stz       OldStartX
                  stz       StartXMod256

                  stz       StartY
                  stz       OldStartY
                  stz       StartYMod240

                  stz       DirtyBits
                  stz       LastRender             ; Initialize as if a full render was performed
;                  stz       LastPatchOffset
;                  stz       RenderCount

                  lda       #CTRL_EVEN_RENDER
                  sta       GTEControlBits
                  stz       GTEControlBits

                  stz       CompileBankTop         ; Bank for compiled tiles

                  stz       OneSecondCounter
                  stz       LastKey

                  lda       #1                     ; $0000 is a sentinel address, so start at $0001 for
                  sta       SpriteBankPos          ; compiled sprites

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
                  rep       #$20

; Insert jumps to the interrupt enable code every 16 lines

                  jsr       _InitPEAFieldInt

; If the even mode is turned on, adjust all of the even lines in the PEA field to skip their next line

                  jsr       _InitRenderMode

; Done initializing the engine

                  clc
                  rts

_InitRenderMode
                  lda       GTEControlBits
                  bit       #CTRL_EVEN_RENDER
                  beq       :no_even
                  jmp       _InitPEAFieldEven
:no_even          jmp       _InitPEAFieldAll


; Insert jumps to the interrupt enable code every 16 lines. There are 120 lines in each bank, so
; only 7 loops needed.  Interrups are set at the mid-point lines -- 4, 20, 36, 52, 68, 84, 100, 116
;
; Notice that this routine sets the low byte of the EXIT_EVEN address, while _InitPEAFieldAll and
; _InitPEAFieldEven set the high byte of EXIT_EVEN.
_InitPEAFieldInt
                  lda       #7
                  sta       tmp15

                  ldx       #_EXIT_EVEN+{_LINE_SIZE*4}+1      ; Patch the JMP operand here
:loop
                  sep       #$20
                  lda       #_ENTRY_INT
                  stal      lite_base,x
                  stal      lite_base_2,x
                  rep       #$20

                  txa
                  clc
                  adc       #{_LINE_SIZE*16}
                  tax

                  dec       tmp15
                  bne       :loop
                  rts


; Initialize the PEA fields for "normal" mode that draws all of the lines
_InitPEAFieldAll
                  lda       #119                   ; There are 120 lines in each bank
                  sta       tmp15

                  ldx       #_EXIT_EVEN+2
                  ldy       #3                    ; The first even line jumps to $3F1
:loop
                  sep       #$20
                  tya
;                  cmpl      lite_base,x
;                  beq  :ok1
;                  ldal      lite_base,x
;                  brk  $04

:ok1
                  stal      lite_base,x

;                  cmpl      lite_base_2,x
;                  beq  :ok2
;                  ldal      lite_base_2,x
;                  brk  $05

:ok2
                  stal      lite_base_2,x
                  rep       #$20

                  tya
                  clc
                  adc       #2                   ; Move this many pages up
                  tay

                  txa
                  clc
                  adc       #_LINE_SIZE          ; Step to the next line
                  tax

                  dec       tmp15
                  bne       :loop

                  rts

; Initialize the PEA fields for "even" mode where all of the odd lines are skipped
_InitPEAFieldEven
                  lda       #60                   ; There are 120 lines in each bank, we update half of them
                  sta       tmp15

                  ldx       #_EXIT_EVEN+2
                  ldy       #5                    ; The first even line jumps to $3F1, needs to go to $5xx
:loop
                  sep       #$20
                  tya
                  stal      lite_base,x
                  stal      lite_base_2,x
                  rep       #$20

                  tya
                  clc
                  adc       #4                   ; Move this many pages up
                  tay

                  txa
                  clc
                  adc       #{_LINE_SIZE*2}      ; Step to the next even line
                  tax

                  dec       tmp15
                  bne       :loop
                  rts

WaitForKey        sep       #$20
                  stal      KBD_STROBE_REG      ; clear the strobe
:WFK              ldal      KBD_REG
                  bpl       :WFK
                  rep       #$20
                  and       #$007F
                  rts

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
_ReadControl
                  jsr       _ReadKeypress        ; Always poll for a keystroke
                  sta       InputPlayer1
                  sta       InputPlayer2         ; Replicate the raw keyboard info into both player's input values

; Now read the specific input device for each player

                  ldx       config_input_p1_type ; Load the input type for player 1
                  beq       :ok
                  cpx       #2
                  beq       :ok
                  brk       $ab
:ok
;                jsr          _ReadKeyboard1
                  jsr       (:input_proc,x)
;                  jsr       _ReadKeyboard
;                  and       #$FF00
;                  tsb       InputPlayer1
;                  jsr       _ReadSNESMAX
;                  and       #$FF00
;                  tsb       InputPlayer1
                  tsb       InputPlayer1

                  lda       InputPlayer1
                  rts

;                  ldx       config_input_p2_type
;                  jsr       (:input_proc,x)
;                  tsb       InputPlayer2
;                  rts

:input_proc       dw        _ReadKeyboard1,_ReadSNESMAX1
                  dw        _ReadKeyboard2,_ReadSNESMAX2

; Poll the keyboard and return the current keypress in the lower 7 bits and the KEY_DOWN
; status in the high bit. This routine does apply debounce logic.
_ReadKeypress
                  pea       $0000               ; temporary space
                  sep       #$20

                  ldal      KBD_STROBE_REG      ; read the keyboard
                  bit       #$80
                  beq       :KbdNotDwn          ; check the key-down status

; debounce the new input

                  and       #$7F                ; save the new key code
                  cmp       LastKey             ; is it different than the last key press?
                  bne       :KbdDifferent       ; If yes, the input has no settled

                  sta       LastKey             ; save it as the current 'active' keypress
                  stal      KBD_REG             ; clear the key strobe

                  ora       #PAD_KEY_DOWN       ; set the keydown flag and save the return value
                  sta       1,s
                  bra       :KbdDown
:KbdDifferent
                  sta       LastKey             ; Just save the current key for the next time, but don't return the key code
                  bra       :KbdDown
:KbdNotDwn
                  stz       LastKey             ; If no key is currently pressed, set the 'active' key to 0
:KbdDown
                  rep       #$20
                  pla
                  rts

; Map the current keypress to directional bits and read the command and option registers for buttons
_ReadKeyboard1    lda       InputPlayer1
                  jmp       _ReadKeyboard

_ReadKeyboard2    lda       InputPlayer2
                  jsr       _ReadKeyboard
                  sta       InputPlayer2
                  rts

_ReadKeyboard     pha                           ; low byte = key code, high byte = %ABsSUDLR  S = Start, s = select

                  sep       #$20
                  ldal      OPTION_KEY_REG      ; 'B' button
                  and       #$80
                  beq       :BNotDown

                  lda       #>PAD_BUTTON_B
                  ora       2,s
                  sta       2,s

:BNotDown
                  ldal      COMMAND_KEY_REG
                  and       #$80
                  beq       :ANotDown

                  lda       #>PAD_BUTTON_A
                  ora       2,s
                  sta       2,s

:ANotDown
                  lda       1,s                 ; read the current keypress
                  and       #$7F
                  cmp       config_input_key_down
                  bne       :not_down
                  lda       #>PAD_DOWN
                  ora       2,s
                  bra       :done

:not_down
                  cmp       config_input_key_up
                  bne       :not_up
                  lda       #>PAD_UP
                  ora       2,s
                  bra       :done

:not_up
                  cmp       config_input_key_left
                  bne       :not_left
                  lda       #>PAD_LEFT
                  ora       2,s
                  bra       :done

:not_left
                  cmp       config_input_key_right
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
_ReadSNESMAX1     lda      InputPlayer1
                  jmp      _ReadSNESMAX
;                  and      #$FF00
;                  ora      InputPlayer1
;                  sta      InputPlayer1
;                  rts

_ReadSNESMAX2     lda      InputPlayer2
                  jsr      _ReadSNESMAX
                  sta      InputPlayer2
                  rts

SNESMAX_P1        ds       1
SNESMAX_P2        ds       1

_ReadSNESMAX
                  php
                  sei

                  pha                           ; low byte = key code, high byte = %ABsSUDLR  S = Start, s = select
                  sep      #$30

                  lda      config_input_snesmax_port    ; Set to 1 - 7
                  asl
                  asl
                  asl
                  asl
                  and      #$70
                  tax

                  lda      #$ff
                  sta      SNESMAX_P1
                  sta      SNESMAX_P2

                  ldy      #8
                  stal     $E0C080,x           ; clock the latch
:loop
                  ldal     $E0C080,x           ; first read
                  rol
                  rol      SNESMAX_P1
                  rol
                  rol      SNESMAX_P2
                  stal     $E0C081,x           ; clock the shift register
                  dey
                  bne      :loop

                  lda      SNESMAX_P1
                  eor      #$FF                ; SNESMAX returns 0 when button is pressed
                  sta      2,s

                  rep      #$30
                  pla
                  plp
                  rts

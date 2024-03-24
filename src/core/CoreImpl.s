; Feature flags
NO_INTERRUPTS     equ       1                   ; turn off for crossrunner debugging

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

                  jsr       _ApplyBG0YPosLite
                  jsr       _ApplyBG0XPosLite
                  clc


;                  jsr       InitSprites         ; Initialize the sprite subsystem
;                  jsr       InitTiles           ; Initialize the tile subsystem

;                  jsr       InitTimers          ; Initialize the timer subsystem
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
                  lda       #NO_INTERRUPTS
                  bne       :no_interrupts

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
:no_interrupts
                  rts

IntShutDown
                  lda       #NO_INTERRUPTS
                  bne       :no_interrupts

                  pea       $0007               ; disable 1-second interrupts
                  _IntSource

                  PushLong  #VBLTASK            ; Remove our heartbeat task
                  _DelHeartBeat

                  pea       $0015
                  PushLong  OldOneSecVec        ; Reset the interrupt vector
                  _SetVector

:no_interrupts
                  rts


; Interrupt handlers. We install a heartbeat (1/60th second and a 1-second timer)
OneSecHandler     mx        %11
                  ldal      OneSecondCounter
                  inc
                  stal      OneSecondCounter

                  lda       #%10111111          ;clear IRQ source
                  stal      $E0C032
                  clc
                  rtl

;                  phb
;                  pha

;                  rep       #$20
;                  ldal      OneSecondCounter
;                  inc
;                  stal      OneSecondCounter
;                  sep       #$20

;                  ldal      $E0C032
;                  and       #%10111111          ;clear IRQ source
;                  stal      $E0C032

;                  pla
;                  clc
;                  rtl
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
                  stz       LastPatchOffset
                  stz       RenderCount

                  lda       #CTRL_EVEN_RENDER
                  sta       GTEControlBits
                  stz       GTEControlBits

                  stz       CompileBankTop

;                  stz       SpriteBanks
;                  stz       SpriteMap
;                  stz       ActiveSpriteCount

                  stz       OneSecondCounter

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

; Insert jumps to the interrupt enable code every 16 lines. There are 120 lines in each bank, so
; only 7 loops needed.  Interrups are set at the mid-point lines -- 4, 20, 36, 52, 68, 84, 100, 116

                  lda       #7
                  sta       tmp15

                  ldx       #_EXIT_EVEN+{_LINE_SIZE*4}+1      ; Patch the JMP operand here
:lloop
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
                  bne       :lloop

; If the even mode is turned on, adjust all of the even lines in the PEA field to skip their next line

                  lda       GTEControlBits
                  bit       #CTRL_EVEN_RENDER
                  beq       :no_even

                  lda       #60                   ; There are 120 lines in each bank, we update half of them
                  sta       tmp15

                  ldx       #_EXIT_EVEN+2
                  ldy       #5                    ; The first even line jumps to $3F1, needs to go to $5xx
:eloop
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
                  bne       :eloop
:no_even

; Done initializing the engine
                  clc
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

; Read the keyboard and paddle controls and return in a game-controller-like format
_ReadControl      pea       $0000               ; low byte = key code, high byte = %------AB 

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
                  ldal      KBD_STROBE_REG      ; read the keyboard
                  bit       #$80
                  beq       :KbdNotDwn          ; check the key-down status
                  and       #$7f
                  ora       1,s
                  sta       1,s

                  cmp       LastKey
                  beq       :KbdDown
                  sta       LastKey

                  lda       #>PAD_KEY_DOWN       ; set the keydown flag
                  ora       2,s
                  sta       2,s
                  bra       :KbdDown

:KbdNotDwn
                  stz       LastKey
:KbdDown
                  rep       #$20
                  pla
                  rts



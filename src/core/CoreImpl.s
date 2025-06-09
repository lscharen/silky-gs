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

;                  lda       #25
;                  sta       ScreenTileHeight
;                  lda       #32
;                  sta       ScreenTileWidth

                  stz       StartX
;                  stz       OldStartX
                  stz       StartXMod256

                  stz       StartY
;                  stz       OldStartY
                  stz       StartYMod240

                  lda       #$FFFF                 ; Mark as needing a full update
                  sta       DirtyBits

                  stz       DirtyState
                  stz       DebugSCB
                  stz       LastRender             ; Initialize as if a full render was performed
;                  stz       LastPatchOffset
;                  stz       RenderCount

                  lda       #1
                  sta       PPU_VERSION            ; Current version for tile change tracking. Zero is an illegal value.
                  stz       PPU_CLEAR_ADDR         ; Address of memory that is incrmentally cleared

                  lda       #CTRL_EVEN_RENDER
                  sta       GTEControlBits
                  stz       GTEControlBits

;                  stz       CompileBankTop         ; Bank for compiled tiles

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

; Insert jumps to the interrupt enable code every 16 lines

;                  jsr       _InitPEAFieldInt

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
:no_even
;          jmp       _InitPEAFieldAll
                  DO    NAMETABLE_MIRRORING&HORIZONTAL_MIRRORING
                  jsr   _InitHorizontalMirroring
                  ELSE
                  jsr   _InitVerticalMirroring
                  FIN

                  rts

; Insert jumps to the interrupt enable code every 16 lines. There are 120 lines in each bank, so
; only 7 loops needed.  Interrupts are set at the mid-point lines -- 4, 20, 36, 52, 68, 84, 100, 116
;
; Notice that this routine sets the low byte of the EXIT_EVEN address, while _InitPEAFieldAll and
; _InitPEAFieldEven set the high byte of EXIT_EVEN.
;_InitPEAFieldInt
;                  lda       #7
;                  sta       tmp15
;
;                  ldx       #_EXIT_EVEN+{_LINE_SIZE_V*4}+1      ; Patch the JMP operand here
;:loop
;                  sep       #$20
;                  lda       #_ENTRY_INT
;                  stal      lite_base_1,x
;                  stal      lite_base_2,x
;                  rep       #$20
;
;                  txa
;                  clc
;                  adc       #{_LINE_SIZE_V*16}
;                  tax
;
;                  dec       tmp15
;                  bne       :loop
;                  rts

; Patch a PEA field address relative to a page offset that's in the X register
; PATCH_FIELD offset,dest.
;
; Offset by the number of bytes from the lite_base entry address and the start of the
; page-aligned line code.
FIRST_PAGE        equ       $100       ; PEA code starts at $0100 in each respective bank
PATCH_JMP         mac
                  txa
                  clc
                  IF        #=]2
                  adc       ]2+FIRST_PAGE
                  ELSE
                  adc       ]2
                  adc       #FIRST_PAGE
                  FIN
                  stal      lite_start_page_1+1+{]1},x
                  stal      lite_start_page_2+1+{]1},x
                  <<<

PATCH_ADDR        mac
                  txa
                  clc
                  IF        #=]2
                  adc       ]2+FIRST_PAGE
                  ELSE
                  adc       ]2
                  adc       #FIRST_PAGE
                  FIN
                  stal      lite_start_page_1+{]1},x
                  stal      lite_start_page_2+{]1},x
                  <<<

PATCH_VAL         mac
                  lda       ]2
                  stal      lite_start_page_1+{]1},x
                  stal      lite_start_page_2+{]1},x
                  <<<

; Mirroring
;
; The array of PEA spans need to be reconfigured depending on whether the engine is in vertical or
; horizontal mirroring mode.
;
; The configuration involved setting the prelude and epilogue instructions that bookend the core
; PEA instructions.
;
; n00: jmp even_out     ; H = jmp ${n}CF,     V = jmp ${n+1}CF
; n03: jmp odd_out      ; H = jmp ${n}CC,     V = jmp ${n+1}CC
; ...
; nC6: jmp next         ; H = jmp ${n}06,     V = jmp ${n+1}06
; nC9: jmp even_out     ; H = jmp ${n}CF,     V = jmp ${n+1}CF
; nCC: jmp odd_out      ; H = LDA #imm / PHA, V = jmp ${n+1}CC
; nCF: jmp {n+2}F1      ; H = jmp ${n+2}F1,   V = -- -- --
;
; The last lines in each bank need to be adjusted to have proper JML instructions embedded within
;
; F0CF: jml ${b^1}01F1  ; H = jml ${b^1}01F1  V = -- -- -- --
; F1CF: jml ${b^1}....  ; H = jml ${b^1}02F1  V = jml ${b^1}01F1


; Set up the PEA field for horizontal mirroring.  This creates a virtual 256x480 rendering surface. In
; this mode, each page-aligned line is updated
_InitHorizontalMirroring
                  lda       #$00FF
                  sta       MirrorMaskX
                  lda       #$01FF
                  sta       MirrorMaskY
                  lda       #480
                  sta       MaxY

; Adjust lookup tables

                  ldx       #126
:loop0
                  lda       Col2CodeOffset,x
                  sta       Col2CodeOffset+128,x                  ; For horizontal mirroring, offsets 64 - 127 are the same as 0 - 63
                  dex
                  dex
                  bpl       :loop0

; Update the flow control in the PEA fields

                  ldx       #0
:loop1
                  PATCH_JMP _LOOP_OFFSET;#_PEA_OFFSET             ; Jump around to the beginning of the line
                  PATCH_JMP _E_OUT_OFFSET;#_E_WORD_OFFSET         ; Jump to the code to push the last word for an even blit
                  PATCH_JMP _O_OUT_OFFSET;#_O_WORD_OFFSET         ; Jump to the code to push the last byte for an odd blit
                  PATCH_JMP _E_EXIT_OFFSET;#{$0200+_ENTRY_OFFSET} ; Jump to the next line
                  PATCH_JMP _O_EXIT_OFFSET;#{$0200+_ENTRY_OFFSET} ; Jump to the next line

                  PATCH_VAL {_E_WORD_OFFSET};#$00F4               ; PEA opcode (value is filled in by blitter)
                  PATCH_VAL {_O_WORD_OFFSET};#$00AD               ; LDA abs opcode (addess filled in by _O_LOAD_HI_OFFSET)
                  PATCH_ADDR {_O_LOAD_LO_OFFSET+1};#{_SAVE_OFFSET+0}
                  PATCH_ADDR {_O_LOAD_HI_OFFSET+1};#{_SAVE_OFFSET+1}

                  txa
                  clc
                  adc       #_LINE_SIZE_H
                  tax

                  cpx       #{240*256}             ; Do 240 lines per bank
                  bcc       :loop1

; The last line needs to jump to beginning of the next bank
;
;          NT1 NT2
;  Bank 1: A   C
;  Bank 2: B   D
;
; Execution order is A -> B -> C -> D -> A

                  ldx       #{238*256}
                  PATCH_VAL _E_EXIT_OFFSET;#$005C                           ; JML opcode (in both nametables)
                  PATCH_VAL _E_EXIT_OFFSET+$100;#$005C                           ; JML opcode (in both nametables)
                  PATCH_VAL _O_EXIT_OFFSET;#$005C                           ; JML opcode (in both nametables)
                  PATCH_VAL _O_EXIT_OFFSET+$100;#$005C                           ; JML opcode (in both nametables)
                  
                  lda       #_BANK_ENTRY_NT1
                  stal      lite_start_page_1+_E_EXIT_OFFSET+1,x       ; A -> B
                  stal      lite_start_page_1+_O_EXIT_OFFSET+1,x       ; A -> B
                  lda       #_BANK_ENTRY_NT2
                  stal      lite_start_page_1+_E_EXIT_OFFSET+$0100+1,x ; C -> D
                  stal      lite_start_page_1+_O_EXIT_OFFSET+$0100+1,x ; C -> D

                  lda       #_BANK_ENTRY_NT2
                  stal      lite_start_page_2+_E_EXIT_OFFSET+1,x       ; B -> C
                  stal      lite_start_page_2+_O_EXIT_OFFSET+1,x       ; B -> C
                  lda       #_BANK_ENTRY_NT1
                  stal      lite_start_page_2+_E_EXIT_OFFSET+$0100+1,x ; D -> A
                  stal      lite_start_page_2+_O_EXIT_OFFSET+$0100+1,x ; D -> A

; Enable the interrupt code on every 16th line

                  ldx       #{4*_LINE_SPAN}
                  lda       #7
                  sta       tmp15

:loop2
                  PATCH_JMP {$000+_E_EXIT_OFFSET};#{$0200+_INT_OFFSET}      ; Jump to the interrupt enable code (left nametable)
                  PATCH_JMP {$000+_O_EXIT_OFFSET};#{$0200+_INT_OFFSET}      ; Jump to the interrupt enable code (left nametable)
                  PATCH_JMP {$100+_E_EXIT_OFFSET};#{$0300+_INT_OFFSET}      ; Jump to the interrupt enable code (right nametable)
                  PATCH_JMP {$100+_O_EXIT_OFFSET};#{$0300+_INT_OFFSET}      ; Jump to the interrupt enable code (right nametable)

                  txa
                  clc
                  adc       #{16*_LINE_SPAN}
                  tax

                  dec       tmp15
                  bne       :loop2

                  rts

; Setting up for vertical mirroring is slightly different than horizontal mirroring to guarantee that the entry point
; of each line corresponds to the first nametable. This creates a virtual 512x240 rendering surface.
_InitVerticalMirroring
                  lda       #$01FF
                  sta       MirrorMaskX
                  lda       #$00FF
                  sta       MirrorMaskY
                  lda       #240
                  sta       MaxY

; Adjust lookup tables

                  ldx       #126
:loop0
                  lda       Col2CodeOffset,x
                  ora       #$0100
                  sta       Col2CodeOffset+128,x                  ; For horizontal mirroring, offsets 64 - 127 are +$100 as 0 - 63
                  dex
                  dex
                  bpl       :loop0

; Update the flow control in the PEA fields

                  ldx       #0
:loop1
                  PATCH_JMP _LOOP_OFFSET;#{_PEA_OFFSET+$100}              ; Loop around a double-width line
                  PATCH_JMP {_LOOP_OFFSET+$100};#_PEA_OFFSET

                  PATCH_JMP _E_OUT_OFFSET;#_E_WORD_OFFSET                 ; All exit points jump to code in the first page
                  PATCH_JMP _O_OUT_OFFSET;#_O_WORD_OFFSET
                  PATCH_JMP {_E_OUT_OFFSET+$100};#_E_WORD_OFFSET
                  PATCH_JMP {_O_OUT_OFFSET+$100};#_O_WORD_OFFSET

                  PATCH_VAL {_E_WORD_OFFSET+$100};#$004C                  ; JMP opcode (in second page to unify exit code)
                  PATCH_VAL {_O_WORD_OFFSET+$100};#$004C
                  PATCH_JMP {_E_WORD_OFFSET+$100};#_E_WORD_OFFSET
                  PATCH_JMP {_O_WORD_OFFSET+$100};#_O_WORD_OFFSET

                  PATCH_JMP _E_EXIT_OFFSET;#{$0200+_ENTRY_OFFSET}         ; Jump to the next line
                  PATCH_JMP _O_EXIT_OFFSET;#{$0200+_ENTRY_OFFSET}
;                  PATCH_JMP {_E_EXIT_OFFSET+$100};#{$0200+_ENTRY_OFFSET}  ; Jump to the next line
;                  PATCH_JMP {_O_EXIT_OFFSET+$100};#{$0200+_ENTRY_OFFSET}  ; Jump to the next line

                  PATCH_ADDR {_O_LOAD_LO_OFFSET+1};#{$100+_O_SAVE_EDGE}      ; All saved data is in the first page
                  PATCH_ADDR {_O_LOAD_HI_OFFSET+1};#{_SAVE_OFFSET+1}
;                  PATCH_ADDR {_O_LOAD_LO_OFFSET+$101};#{_SAVE_OFFSET+0}
;                  PATCH_ADDR {_O_LOAD_HI_OFFSET+$101};#{_SAVE_OFFSET+1}

                  txa
                  clc
                  adc       #_LINE_SIZE_V
                  tax

                  cpx       #{240*256}             ; Do 120 lines per bank
                  bcs       :out
                  brl       :loop1
:out

; The last line needs to jump to beginning of the next bank
;
;          NT1 NT2
;  Bank 1: A   C
;  Bank 2: B   D
;
; Execution order is A -> B -> A, C -> D -> C

                  ldx       #{238*256}
                  PATCH_VAL _E_EXIT_OFFSET;#$005C                           ; JML opcode (in both nametables)
                  PATCH_VAL _E_EXIT_OFFSET+$100;#$005C                           ; JML opcode (in both nametables)
                  PATCH_VAL _O_EXIT_OFFSET;#$005C                           ; JML opcode (in both nametables)
                  PATCH_VAL _O_EXIT_OFFSET+$100;#$005C                           ; JML opcode (in both nametables)
                  
                  lda       #_BANK_ENTRY_NT1
                  stal      lite_start_page_1+_E_EXIT_OFFSET+1,x       ; A -> B
                  stal      lite_start_page_1+_O_EXIT_OFFSET+1,x       ; A -> B
                  stal      lite_start_page_1+_E_EXIT_OFFSET+$0100+1,x ; C -> D
                  stal      lite_start_page_1+_O_EXIT_OFFSET+$0100+1,x ; C -> D

                  stal      lite_start_page_2+_E_EXIT_OFFSET+1,x       ; A -> B
                  stal      lite_start_page_2+_O_EXIT_OFFSET+1,x       ; A -> B
                  stal      lite_start_page_2+_E_EXIT_OFFSET+$0100+1,x ; C -> D
                  stal      lite_start_page_2+_O_EXIT_OFFSET+$0100+1,x ; C -> D

; Enable the interrupt code on every 16th line

                  ldx       #{4*_LINE_SPAN}
                  lda       #7
                  sta       tmp15

:loop2
                  PATCH_JMP {$000+_E_EXIT_OFFSET};#{$0200+_INT_OFFSET}      ; Jump to the interrupt enable code (left nametable)
                  PATCH_JMP {$000+_O_EXIT_OFFSET};#{$0200+_INT_OFFSET}
                  PATCH_JMP {$100+_E_EXIT_OFFSET};#{$0200+_INT_OFFSET}
                  PATCH_JMP {$100+_O_EXIT_OFFSET};#{$0200+_INT_OFFSET}

                  txa
                  clc
                  adc       #{16*_LINE_SPAN}
                  tax

                  dec       tmp15
                  bne       :loop2

                  rts


; Initialize the PEA fields for "normal" mode that draws all of the lines
;_InitPEAFieldAll
;                  lda       #119                   ; There are 120 lines in each bank
;                  sta       tmp15
;
;                  ldx       #_EXIT_EVEN+2
;                  ldy       #3                    ; The first even line jumps to $3F1
;:loop
;                  sep       #$20
;                  tya
;                  stal      lite_base_1,x
;                  stal      lite_base_2,x
;                  rep       #$20
;
;                  tya
;                  clc
;                  adc       #2                   ; Move this many pages up
;                  tay
;
;                  txa
;                  clc
;                  adc       #_LINE_SIZE_V          ; Step to the next line
;                  tax
;
;                  dec       tmp15
;                  bne       :loop
;
;                  rts

; Initialize the PEA fields for "even" mode where all of the odd lines are skipped
_InitPEAFieldEven
                  lda       #60                   ; There are 120 lines in each bank, we update half of them
                  sta       tmp15

                  ldx       #_EXIT_EVEN+2
                  ldy       #5                    ; The first even line jumps to $3F1, needs to go to $5xx
:loop
                  sep       #$20
                  tya
                  stal      lite_base_1,x
                  stal      lite_base_2,x
                  rep       #$20

                  tya
                  clc
                  adc       #4                   ; Move this many pages up
                  tay

                  txa
                  clc
                  adc       #{_LINE_SIZE_V*2}      ; Step to the next even line
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

; Reset the keypress state to clear the current keypress and set up to wait until the next key
; is pressed to regiter
_ClearKeypress    
                  stz       LastKey
                  rts

; Acknowledge that a keypress has been read.  This is similar to physically clearing
; the keyboard strobe and will clear the PAD_KEY_DOWN bit, which is held so that a new
; keypress can be picked up by the user code on a differnt frame than the initial read
_AckKeypress
                  lda       LastKey
                  and       #$FF7F
                  sta       LastKey
                  rts

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
_ReadKeypress
                  pea       $0000               ; temporary space
                  sep       #$20

                  ldal      KBD_REG             ; read the keyboard
                  bit       #$80                ; was the strobe bit set? If yes, then this is a new key
                  beq       :no_new_key

                  stal      KBD_STROBE_REG      ; reset the strobe
;                  and       #$7F                ; isolate the key code
                  sta       LastKey
;                  ora       #PAD_KEY_DOWN       ; set the keydown flag
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

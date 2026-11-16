; EngineInit.s -- what the runtime asks of any engine at start-up (ImportEngine.s: EngineAllocL, EngineStartUpL,
; EngineRenderModeL), for the PEA blitter: the compiled tile bank and the blitter banks' setup, out of core/Memory.s and
; core/CoreImpl.s.  All are called with the runtime's direct page.

                  mx        %00

; From InitMemory, before the sprite cache takes every bank it can: the bank for the compiled background tiles
EngineAllocL      ENT
                  jsl       AllocBankL
                  sta       CompileBank
                  stz       CompileBank0
                  rtl

; From _CoreStartUp, last: the blitter banks' values, and their one-time patching
EngineStartUpL    ENT
                  sep       #$20
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
                  rtl

; From _InitRenderMode: a setting that decides the patching has changed
EngineRenderModeL ENT
                  jsr       _InitLiteBlitter
                  rtl

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

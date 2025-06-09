; Global addresses and engine values
SHADOW_REG             equ   $E0C035
STATE_REG              equ   $E0C068
NEW_VIDEO_REG          equ   $E0C029
BORDER_REG             equ   $E0C034     ; 0-3 = border, 4-7 Text color
VBL_VERT_REG           equ   $E0C02E
VBL_HORZ_REG           equ   $E0C02F

VOC_CONTROL_REG        equ   $00C0B1

KBD_REG                equ   $E0C000
KBD_STROBE_REG         equ   $E0C010
VBL_STATE_REG          equ   $E0C019
MOD_REG                equ   $E0C025
COMMAND_KEY_REG        equ   $E0C061
OPTION_KEY_REG         equ   $E0C062

SHADOW_SCREEN          equ   $012000
SHADOW_SCREEN_SCB      equ   $019D00
SHADOW_SCREEN_PALETTES equ   $019E00
SHR_SCREEN             equ   $E12000
SHR_SCB                equ   $E19D00
SHR_PALETTES           equ   $E19E00
SHR_LINE_WIDTH         equ   160
SHR_SCREEN_HEIGHT      equ   200

; Direct page locations used by the engine
ScreenHeight           equ   0           ; Height of the playfield in scan lines
ScreenWidth            equ   2           ; Width of the playfield in bytes
ScreenY0               equ   4           ; First vertical line on the physical screen of the playfield
ScreenY1               equ   6           ; End of playfield on the physical screen. If the height is 20 and Y0 is
ScreenX0               equ   8           ; 100, then ScreenY1 = 120.
ScreenX1               equ   10
;ScreenTileHeight       equ   12          ; Height of the playfield in 8x8 blocks
;ScreenTileWidth        equ   14          ; Width of the playfield in 8x8 blocks

StartX                 equ   16          ; Which code buffer byte is the left edge of the screen. Range = 0 to 167
StartY                 equ   18          ; Which code buffer line is the top of the screen. Range = 0 to 207

CompileBank0           equ   20          ; Always zero to allow [CompileBank0],y addressing
CompileBank            equ   22          ; Data bank that holds compiled sprite code

MirrorMaskX            equ   24

StartXMod256           equ   26
StartYMod240           equ   28

GTEControlBits         equ   30          ; Enable / disable things

MirrorMaskY            equ   32

LastRender             equ   34          ; Record which render function was last executed
; CompileBankTop         equ   36          ; First free byte in the compile bank.  Grows upward in memeory.

DirtyBits              equ   38
; OldStartX              equ   40
; OldStartY              equ   42

; Application variables
SwizzlePtr             equ   44          ; Pointer to a table of 8 swizzle tables, one per palette
SwizzlePtr2            equ   52          ; Work pointer to point at the fourth palette of the active swizzle table
ActivePtr              equ   48          ; Work pointer to point at the active swizzle table

; Keep track of the current sprite bitmap and the one for the previous frame
CurrShadowBitmap       equ   56
PrevShadowBitmap       equ   58

pputmp                 equ   60          ; 16 bytes of temporary storage for the ppu subsystem

SprSaveTop             equ   76          ; Top stack address for the sprite save buffer
SprSaveAddr            equ   78          ; Current address
SprSaveCount           equ   80

PPU_BANK               equ   98

; Dirty State transition
;                                                                                                +---------------------------------------------+
;                                                                                                +----------+---------------+    +-----------+ |
;                                                                                                V          |               |    V           | |
DirtyState             equ   100          ; Track the transition from normal to dirty rendering [0] normal -+-> [1] dirty1 -+-> [2] dirty2 --+-+
DebugSCB               equ   102          ; SCB byte to use for tracing actions
;RenderCount            equ   102         ; 8-bit value tracking the number of times the PPU queues have been rendered to the PEA field
LastRead               equ   104

SpriteBank0            equ   106          ; Always zero to allow [SpriteBank0],y addressing
SpriteBank             equ   108          ; Data bank that holds compiled sprite code
SpriteBankPos          equ   110          ; Current free location in the sprite compile bank

UserId                 equ   112          ; Memory manager user Id to use
LastKey                equ   116
InputPlayer1           equ   118          ; Filled in by _ReadContollers
InputPlayer2           equ   120

ShowFPS                equ   126
; YOrigin                equ   128

MaxY                   equ   130          ; Horizontal Mirroring = 480, Vertical Virroring = 240
; VideoMode              equ   130
; AudioMode              equ   132
; BGToggle               equ   134
LastEnable             equ   136
LastStatusUdt          equ   138
ActiveBank             equ   140
ROMZeroPg              equ   142
ROMStk                 equ   144
OldOneSec              equ   146
NesTop                 equ   148
MinYScroll             equ   150
ScreenRows             equ   152
MaxYScroll             equ   154
NesBottom              equ   156
ScreenBase             equ   158

; Free space from 160 to 192
STATE_REG_R0W0         equ   160         ; R0W0
STATE_REG_BLIT         equ   162         ; Value used for blit (could be R0W0 or R0W1)
STK_SAVE               equ   164         ; Only used by the lite renderer
STATE_REG_R0W1         equ   166         ; R0W1
STATE_REG_R1W1         equ   168         ; These values all need to be 16-bit because they may be read
STK_SAVE_BANK          equ   170         ; Bank 0 locations where the data bank values for the PEA fields are stored
BANK_VALUES            equ   172         ; Room for two right here
; PPU_VERSION            equ   174         ; For tracking PPU WRITES
PPU_CLEAR_ADDR         equ   176         ; Current address for a rolling clear of PPU shadow memory

blttmp                 equ   192         ; 32 bytes of local cache/scratch space for blitter

tmp8                   equ   224         ; another 16 bytes of temporary space to be used as scratch 
tmp9                   equ   226
tmp10                  equ   228
tmp11                  equ   230
tmp12                  equ   232
tmp13                  equ   234
tmp14                  equ   236
tmp15                  equ   238

tmp0                   equ   240         ; 16 bytes of temporary space to be used as scratch 
tmp1                   equ   242
tmp2                   equ   244
tmp3                   equ   246
tmp4                   equ   248
tmp5                   equ   250
tmp6                   equ   252
tmp7                   equ   254

; Keycodes
LEFT_ARROW      equ   $08
RIGHT_ARROW     equ   $15
UP_ARROW        equ   $0B
DOWN_ARROW      equ   $0A

; DirtyBits definitions
DIRTY_BIT_BG0_X        equ   $0001     ; The horizontal scroll position has changed
DIRTY_BIT_BG0_Y        equ   $0002     ; The veritcal scroll position has changed
DIRTY_BIT_PAL_CHANGE   equ   $0004     ; There has been a palette change, force a repaint
DIRTY_BIT_BG0_REFRESH  equ   $0010     ; Force a refresh of the full background
DIRTY_BIT_SPRITE_ARRAY equ   $0040     

; ReadControl return value bits
PAD_KEY_DOWN           equ   $0080
PAD_KEY_MASK           equ   $007F
PAD_RIGHT              equ   $0100
PAD_LEFT               equ   $0200
PAD_DOWN               equ   $0400
PAD_UP                 equ   $0800
PAD_START              equ   $1000
PAD_SELECT             equ   $2000
PAD_BUTTON_A           equ   $4000
PAD_BUTTON_B           equ   $8000

; Rendering Control Bits
CTRL_SPRITE_ENABLE     equ   $0001
CTRL_BKGND_ENABLE      equ   $0002
CTRL_DIRTY_RENDER      equ   $2000                  ; Only render lines that changed from the previous frame
CTRL_GREYSCALE         equ   $4000                  ; Use a fixed greyscale palette. This is not related to the NES greyscale bit
CTRL_EVEN_RENDER       equ   $8000                  ; Only render half the scanlines for speed

; The size of each tile instruction is 3 bytes
PER_TILE_SIZE equ 3

; Turn ON/OFF dirty rendering debugging
DIRTY_RENDERING_VISUALS equ 0

; Offsets for the Lite blitter
;
; The first line of blitter code is at bank address $0100, but some of the line's code preceeds this address to
; ensure that the ciritical code path is page-aligned.  So, for example, the code for line 1 is anchored to 
; address $0200 and starts at $01F1.
;
; In vertical mirroring mode, two adjacent lines combines to make each logical line cover 512 bytes.  In horizontal
; mirroring mode, the line are independent and span 256 bytes.

_BANK_ENTRY_NT1 equ $0004
_BANK_ENTRY_NT2 equ $000C

_INT_OFFSET    equ  $00                   ; page offset for the code to enable interrupt before the line
_ENTRY_OFFSET  equ  $11                   ; page offset for each line of code
_ENTRY_PATCH   equ  $15                   ; page offset for the jmp/ldx at the top of the line
_ODD_PATCH     equ  $1C                   ; page offset for the jmp following the odd-aligned code
_E_OUT_OFFSET  equ  $1F                   ; page offset for the top jump that leads to the last word code at $E5
_O_OUT_OFFSET  equ  $22
_PEA_OFFSET    equ  $25                   ; page offset to the first PEA instruction
_LOOP_OFFSET   equ  $E5                   ; page offset for the jump after the PEA opcodes that continues drawing
;_WORD_OFFSET  equ  $E5                   ; page offset for the code that pushes the final byte/word onto the stack
_E_WORD_OFFSET equ  $E8
_O_WORD_OFFSET equ  $EF
_E_EXIT_OFFSET equ  $EB                   ; page offset of the jump that goes to the next line
_O_EXIT_OFFSET equ  $F3                   ; page offset of the jump that goes to the next line
_SAVE_OFFSET   equ  $E9                   ; page offset to the location where the PEA operand is saved
_O_LOAD_HI_OFFSET equ $EF
_O_LOAD_LO_OFFSET equ $18

_O_SAVE_EDGE   equ  $F7                  ; Empty byte to stash data in the second page for odd rendering

_ENTRY_JMP  equ  4                       ; $nF5: the jump (brl, actually) is 4 bytes after the entry byte
_ENTRY_ODD  equ  12                      ; $nFD: the brl for the odd entry is a bit further in
_EXIT_ODD   equ  475                     ; the odd enty point is just 3 bytes of code to load and push the edge byte
_EXIT_EVEN  equ  478                     ; in the second page of the blitter line
_LOW_SAVE   equ  {_EXIT_EVEN+4}          ; space to save the code field opcodes is right after the return jmp/jml
_LINE_SIZE_V equ  512                    ; number of bytes for each blitter line (vertical mirroring)
_LINE_SIZE_H equ  256                    ; number of bytes for each blitter line (horizontal mirroring)
_LINE_SPAN  equ  512                     ; always 512 bytes between adjacent vertical lines
_CODE_TOP   equ  21                      ; number of bytes from the base address of each blitter line to the first PEA instruction
_LINES_PER_BANK equ 120

; Set up some symbols to reference the different shadow memory in the PPU static bank. All of these
; shadow areas are meant to be accessed using indexed addressed with a Nametable address ($2000 - $2FFF)
; e.g. lda TILE_SHADOW,x
TILE_SHADOW  equ $2000          ; shadowed values of the nametable tiles
ATTR_SHADOW  equ $3000          ; pre-calculated attribute values derived from the attribute bytes in $2nC0 PPU RAM
TILE_BANK    equ $4000          ; pre-calculated data bank value for the location of the associated PEA field tile
TILE_ADDR_LO equ $5000          ; pre-calculated address (low byte) of the location of the PEA field tile
TILE_ADDR_HI equ $6000          ; pre-calculated address (high byte) of the location of the PEA field tile
TILE_VERSION equ $7000          ; version count of nametable byte (incremented on each PPUDATA_WRITE)
; TILE_TARGET  equ $8000          ; value of last rendered byte. If TILE_VERSION == TILE_TARGET, then no update
ATTR_ADDR    equ $8000          ; pre-calculated low byte of the attribute byte address at $2nC0+ for the PPU address
TILE_ROW     equ $9000          ; pre-calculated row of the PPU address

; Return codes from the Event Loop harness
USER_SAYS_QUIT  equ 'q'
USER_SAYS_RESET equ 'r'

; APU emulation constants
APU_60HZ  equ 0
APU_120HZ equ 1
APU_240HZ equ 2

; NES Register definitions
NES_PPUMASK_BG  equ $08
NES_PPUMASK_SPR equ $10

NES_PPUCTRL_SPRSIZE equ $20

; NES Nametable Mirroring
HORIZONTAL_MIRRORING equ $01
VERTICAL_MIRRORING   equ $02
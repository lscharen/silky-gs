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
ScreenTileHeight       equ   12          ; Height of the playfield in 8x8 blocks
ScreenTileWidth        equ   14          ; Width of the playfield in 8x8 blocks

StartX                 equ   16          ; Which code buffer byte is the left edge of the screen. Range = 0 to 167
StartY                 equ   18          ; Which code buffer line is the top of the screen. Range = 0 to 207

CompileBank0           equ   20          ; Always zero to allow [CompileBank0],y addressing
CompileBank            equ   22          ; Data bank that holds compiled sprite code

LastPatchOffset        equ   24          ; Offset into code field that was patched with BRA instructions
StartXMod256           equ   26
StartYMod240           equ   28

GTEControlBits         equ   30          ; Enable / disable things

SpriteBanks            equ   32          ; Bank bytes for the sprite data and sprite mask
LastRender             equ   34          ; Record which render function was last executed
CompileBankTop         equ   36          ; First free byte in the compile bank.  Grows upward in memeory.

DirtyBits              equ   38
OldStartX              equ   40
OldStartY              equ   42

; Application variables
SwizzlePtr             equ   44          ; Pointer to a table of 8 swizzle tables, one per palette
ActivePtr              equ   48          ; Work pointer to point at the active swizzle table
shadowBitmap           equ   52          ; Provide enough space for the full ppu range (240 lines) + 16 since the y coordinate can be off-screen
_next                  equ   shadowBitmap+32

RenderCount            equ   102         ; 8-bit value tracking the number of times the PPU queues have been rendered to the PEA field
LastRead               equ   104

TileStoreBankAndBank01 equ   106
TileStoreBankAndTileDataBank equ 108
TileStoreBankDoubled   equ   110
UserId                 equ   112         ; Memory manager user Id to use
LastKey                equ   116
LastTick               equ   118
ForceSpriteFlag        equ   120
RenderFlags            equ   124         ; Flags passed to the Render() function

ShowFPS                equ   126
YOrigin                equ   128
VideoMode              equ   130
AudioMode              equ   132
BGToggle               equ   134
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
STATE_REG_BLIT         equ   161         ; Value used for blit (could be R0W0 or R0W1)
STK_SAVE               equ   162         ; Only used by the lite renderer
STATE_REG_R0W1         equ   164         ; R0W1
STATE_REG_R1W1         equ   165

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

; EngineMode definitions
;ENGINE_MODE_TWO_LAYER  equ   $0001
;ENGINE_MODE_DYN_TILES  equ   $0002
;ENGINE_MODE_BNK0_BUFF  equ   $0004
;ENGINE_MODE_USER_TOOL  equ   $8000       ; Communicate if GTE is loaded as a system tool, or a user tool

; Render flags
RENDER_ALT_BG1         equ   $0001
RENDER_BG1_HORZ_OFFSET equ   $0002
RENDER_BG1_VERT_OFFSET equ   $0004
RENDER_BG1_ROTATION    equ   $0008
RENDER_PER_SCANLINE    equ   $0010
RENDER_WITH_SHADOWING  equ   $0020
RENDER_SPRITES_SORTED  equ   $0040      ; Draw the sprites in y-sorted order.  Otherwise, use the index.

; DirtyBits definitions
DIRTY_BIT_BG0_X        equ   $0001
DIRTY_BIT_BG0_Y        equ   $0002
DIRTY_BIT_BG1_X        equ   $0004
DIRTY_BIT_BG1_Y        equ   $0008
DIRTY_BIT_BG0_REFRESH  equ   $0010
DIRTY_BIT_BG1_REFRESH  equ   $0020
DIRTY_BIT_SPRITE_ARRAY equ   $0040

; GetAddress table IDs
scanlineHorzOffset     equ   $0001        ; Table of 416 words, a double-array of scanline offset values. Values must be in range [0, 163]
scanlineHorzOffset2    equ   $0002        ; Table of 416 words, a double-array of scanline offset values. Values must be in range [0, 163]
tileStore              equ   $0003
vblCallback            equ   $0004        ; User routine to be called by VBL interrupt.  Set to $000000 to disconnect
extSpriteRenderer      equ   $0005
rawDrawTile            equ   $0006
extBG0TileUpdate       equ   $0007
userTileCallback       equ   $0008        ; Callback for rendering custom tiles into the code field
liteBlitter            equ   $0009
userTileDirectCallback equ   $000A        ; Callback for drawing custom tiles directly to the screen buffer

; CopyPicToBG1 flags
COPY_PIC_NORMAL        equ   $0000        ; Copy into BG1 buffer in "normal mode" treating the buffer as a 164x208 pixmap with stride of 256
COPY_PIC_SCANLINE      equ   $0001        ; Copy in a way to support BG1 + RENDER_PER_SCANLINE.  Pixmap is double-width, 327x200 with stride of 327

; Script definition
YIELD                  equ   $8000
JUMP                   equ   $4000

SET_PALETTE_ENTRY      equ   $0002
SWAP_PALETTE_ENTRY     equ   $0004
SET_DYN_TILE           equ   $0006
CALLBACK               equ   $0010

; ReadControl return value bits
PAD_BUTTON_B           equ   $0100
PAD_BUTTON_A           equ   $0200
PAD_KEY_DOWN           equ   $0400

; Rendering Control Bits
CTRL_SPRITE_DISABLE    equ   $0001
CTRL_BKGND_DISABLE     equ   $0002
CTRL_GREYSCALE         equ   $4000           ; Use a fixed greyscale palette. This is not related to the NES greyscale bit
CTRL_EVEN_RENDER       equ   $8000           ; Only render half the scanlines for speed


; Tile constants
TILE_DAMAGED_BIT       equ   $8000                  ; Mark a tile as damaged (internal only)
TILE_PRIORITY_BIT      equ   $4000                  ; Put tile on top of sprite (unimplemented)
TILE_USER_BIT          equ   $2000                  ; User-defined tile.  Execute registered callback.
TILE_SOLID_BIT         equ   $1000                  ; Hint bit used in TWO_LAYER_MODE to optimize rendering
TILE_DYN_BIT           equ   $0800                  ; Is this a Dynamic Tile?
TILE_VFLIP_BIT         equ   $0400
TILE_HFLIP_BIT         equ   $0200
TILE_ID_MASK           equ   $01FF
TILE_CTRL_MASK         equ   $7E00
; TILE_PROC_MASK         equ   $7800                  ; Select tile proc for rendering

; Sprite constants
SPRITE_OVERLAY         equ   $8000                    ; This is an overlay record.  Stored as a sprite for render ordering purposes
SPRITE_COMPILED        equ   $4000                    ; This is a compiled sprite (SPRITE_DISP points to a routine in the compiled cache bank)
SPRITE_HIDE            equ   $2000                    ; Do not render the sprite
SPRITE_16X16           equ   $1800                    ; 16 pixels wide x 16 pixels tall
SPRITE_16X8            equ   $1000                    ; 16 pixels wide x 8 pixels tall
SPRITE_8X16            equ   $0800                    ; 8 pixels wide x 16 pixels tall
SPRITE_8X8             equ   $0000                    ; 8 pixels wide x 8 pixels tall
SPRITE_VFLIP           equ   $0400                    ; Flip the sprite vertically
SPRITE_HFLIP           equ   $0200                    ; Flip the sprite horizontally

; Tool error codes
NO_TIMERS_AVAILABLE  equ  10

; The size of each tile instruction is 3 bytes
PER_TILE_SIZE equ 3

; Offsets for the Lite blitter
_ENTRY_JMP  equ  4                       ; the jump (brl, actually) is 4 bytes after the entry point
_ENTRY_ODD  equ  12                      ; the brl for the odd entry is a bit further in
_EXIT_ODD   equ  475                     ; the odd enty point is just 3 bytes of code to load and push the edge byte
_EXIT_EVEN  equ  478                     ; in the second page of the blitter line
_LOW_SAVE   equ  {_EXIT_EVEN+4}          ; space to save the code field opcodes is right after the return jmp/jml
_ENTRY_INT  equ  $E1                     ; pre-code area of the next line -- just change the bottom byte of the JMP
_LINE_SIZE  equ  512                     ; number of bytes for each blitter line

_CODE_TOP   equ  21                      ; number of bytes from the base address of each blitter line to the first PEA instruction
_LINES_PER_BANK equ 120
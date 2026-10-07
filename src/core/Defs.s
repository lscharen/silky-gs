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
MOD_REG                equ   $E0C025      ; Modifier key register
COMMAND_KEY_REG        equ   $E0C061
OPTION_KEY_REG         equ   $E0C062

MOD_REG_SHIFT_DOWN     equ   $01
MOD_REG_CONTROL_DOWN   equ   $02
MOD_REG_OPTION_DOWN    equ   $40
MOD_REG_COMMAND_DOWN   equ   $80

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

; The scroll position in the form of the NES PPU registers (set by NES_SetScroll and friends)
ScrollX                equ   14          ; scroll_x (0 - 255)
ScrollY                equ   16          ; scroll_y (0 - 255)

CompileBank0           equ   18          ; Always zero to allow [CompileBank0],y addressing
CompileBank            equ   20          ; Data bank that holds compiled sprite code

; Values derived from the scroll position for the blitter.  These are the position of NES scanline 0,
; the viewport's y_offset is added by the blitter.
StartX                 equ   22          ; Byte offset of the left edge (0 - 127 H mirroring, 0 - 255 V mirroring)
StartY                 equ   24          ; Virtual line (0 - 239 V mirroring, 0 - 479 H mirroring)
StartRow               equ   12          ; StartY mod 240, the PEA row

ControlBits            equ   26          ; Enable / disable things

BltMirrorP             equ   28          ; BLT_P_HORZ for horizontal mirroring, 0 for vertical

LastRender             equ   30          ; Record which render function was last executed
DirtyBits              equ   32

; Application variables
SwizzlePtr             equ   34          ; Pointer to a table of 8 swizzle tables, one per palette
SwizzlePtr2            equ   42          ; Work pointer to point at the fourth palette of the active swizzle table
ActivePtr              equ   38          ; Work pointer to point at the active swizzle table

; Keep track of the current sprite bitmap and the one for the previous frame
CurrShadowBitmap       equ   46          ; These are 16-bit pointers
PrevShadowBitmap       equ   48

; Pointers to which block of CHR memory is for tiles vs sprites
TileChrMem             equ   50
SprChrMem              equ   54

unused59               equ   59

pputmp                 equ   60          ; 16 bytes of temporary storage for the ppu subsystem

SprSaveTop             equ   76          ; Top stack address for the sprite save buffer
SprSaveAddr            equ   78          ; Current address
SprAddrCount           equ   80          ; Number of sprites saved in the buffer
GridLPtr               equ   82          ; Grid dirty renderer (quad mode): write pointer of the cell list
NtmPtr                 equ   84          ; PPUFlushQueuesAlt: long pointer to the shadow buffer being drawn (4 bytes)
NtmTMask               equ   88          ; PPUFlushQueuesAlt: tiles written in the group this period
NtmPrev                equ   90          ; PPUFlushQueuesAlt: main bank offset of the buffer being drawn ($000 / $100)
NtmQBase               equ   92          ; PPUFlushQueuesAlt: CIRAM address of the metatile being drawn
NtmNib                 equ   94          ; PPUFlushQueuesAlt: its nibble of tiles (high byte 0)
NtmPal                 equ   96          ; PPUFlushQueuesAlt: its palette select * 2
PPU_BANK               equ   98

; Dirty State transition
;                                                                                                +---------------------------------------------+
;                                                                                                +----------+---------------+    +-----------+ |
;                                                                                                V          |               |    V           | |
DirtyState             equ   100          ; Track the transition from normal to dirty rendering [0] normal -+-> [1] dirty1 -+-> [2] dirty2 --+-+
DebugSCB               equ   102          ; SCB byte to use for tracing actions
LastRead               equ   104

SpriteBank0            equ   106          ; Always zero to allow [SpriteBank0],y addressing
SpriteBank             equ   108          ; Data bank that holds compiled sprite code
unused110              equ   110          ; (formerly SpriteBankPos; the sprite bank is now a fixed-slot cache)

UserId                 equ   112          ; Memory manager user Id to use
LastKey                equ   116
InputPlayer1           equ   118          ; Filled in by _ReadContollers
InputPlayer2           equ   120

ShowFPS                equ   126

MaxX                   equ   128          ; Horizontal Mirroring = 256, Vertical Mirroring = 512
MaxY                   equ   130          ; Horizontal Mirroring = 480, Vertical Mirroring = 240

unused132              equ   132
unused133              equ   133
unused134              equ   134
unused135              equ   135

LastEnable             equ   136
LastStatusUdt          equ   138
ActiveBank             equ   140
ROMZeroPg              equ   142
ROMStk                 equ   144
OldOneSec              equ   146
NesTop                 equ   148

; PPUFlushQueuesAlt (ppu_queues.s) locals. These must survive a nested
; `jsr SyncPPUMetatile` call (which, for HAS_CHR_RAM games, can go many
; frames deep into CheckBgTileDirty/CompileTile/FastROMTileToLookup), so
; they are NOT allowed to live in the generic tmp0-15 scratch pool -- those
; are documented as leaf-routine-only, freely reused by any callee, and
; using them here caused a real bug: CompileTile (core/tiles/CompileTile.s)
; uses tmp4/tmp5/tmp7/tmp8 as its own scratch, silently aliasing
; RenderPPUAttr's tmp5 (:attr_diff) and tmp7 (:mt_base2) whenever a dirty
; CHR-RAM tile got recompiled mid-attribute-update, corrupting the
; not-yet-consumed quadrant diff/address values.
NtmIdx                 equ   150         ; attribute index (page << 6 | offset)
NtmAttrAddr            equ   154         ; CIRAM address of the attribute byte
NtmAttr                equ   158         ; attribute value being applied

ScreenRows             equ   152

NesBottom              equ   156
;ScreenBase             equ   158

; Free space from 160 to 182
STATE_REG_R0W0         equ   160         ; R0W0
STATE_REG_BLIT         equ   162         ; Value used for blit (could be R0W0 or R0W1)
STK_SAVE               equ   164         ; Only used by the lite renderer
STATE_REG_R0W1         equ   166         ; R0W1
STATE_REG_R1W1         equ   168         ; These values all need to be 16-bit because they may be read
STK_SAVE_BANK          equ   170         ; Bank 0 locations where the data bank values for the PEA fields are stored
BANK_VALUES            equ   172         ; Room for two right here
unused174              equ   174
CMPL_BANK              equ   176         ; ^tiledata << 8 | $01 (Bank $01 in low byte)

; Temporary storage for 8x16 sprite drawing in drawSprites
sprTmp5Hi              equ   178
sprTmp6Lo              equ   180

; PPUFlushQueuesAlt locals, continued from above (same rationale)
NtmDiff                equ   182         ; attribute EOR the last applied value
NtmMask                equ   184         ; 16-bit tile mask of the group
NtmBase                equ   186         ; CIRAM address of the group's top-left tile

BltSegPage             equ   188         ; $0100 when the current _Apply segment is in CIRAM page 1, else 0

ScrollNT               equ   190         ; Nametable select (PPUCTRL bits 1:0)

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
PAD_BUTTON_B           equ   $4000
PAD_BUTTON_A           equ   $8000

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

; Debug border indicators.  Both write the border color, so turn on at most one of them.
;
; TASK_TIME_BORDER: raster bar of CPU time.  The border is TASK_COLOR_NES while the NES task (game
; logic) runs and TASK_COLOR_GS while the GS task (renderer) runs, so the height of the NES-colored
; band is the share of each 1/60s spent in game logic.  A solid NES-colored border = overrunning.
TASK_TIME_BORDER   equ 0
TASK_COLOR_GS      equ 0                ; Black
TASK_COLOR_NES     equ 12               ; Green

; APU_STATS: count the VBLs and the APU interrupts, frame sequencer clocks and DOC updates in the
; apu_stats block (apu/apu.s), to check the audio rates against the VBL in a debugger.
APU_STATS          equ 0

; GRID_FALLBACK_BORDER: color the border by why the grid renderer fell back to a full render, black
; on frames it handles (GRID_DIRTY_RENDERING only).  Values are IIgs border colors.
GRID_FALLBACK_BORDER equ 0
FB_COLOR_GRID      equ 0                ; Black      - grid frame, no fallback
FB_COLOR_SCROLL    equ 2                ; Dark blue  - scrolled (DIRTY_BIT_BG0_X / BG0_Y)
FB_COLOR_PALETTE   equ 13               ; Yellow     - background palette changed
FB_COLOR_REFRESH   equ 15               ; White      - forced refresh (DIRTY_BIT_BG0_REFRESH, other cause)
FB_COLOR_DISABLED  equ 5                ; Dark gray  - disableDirtyRendering is set
FB_COLOR_METATILES equ 1                ; Deep red   - more than GRID_MAX_METATILES redrawn (gmtOverflow)
FB_COLOR_UNALIGNED equ 9                ; Orange     - scroll position not cell-aligned
FB_COLOR_BGOFF     equ 3                ; Purple     - background disabled
FB_COLOR_MANY      equ 11               ; Pink       - gridPrepare :fb_many (currently unused)

; Offsets for the Lite blitter
;
; The first line of blitter code is at bank address $0100, but some of the line's code preceeds this address to
; ensure that the ciritical code path is page-aligned.  So, for example, the code for line 1 is anchored to 
; address $0200 and starts at $01F1.
;
; In vertical mirroring mode, two adjacent lines combines to make each logical line cover 512 bytes.  In horizontal
; mirroring mode, the line are independent and span 256 bytes.

; See TemplateLite.Macs.s for the row layout.  All offsets are relative to a row's even page (P0). The odd
; page (P1) is at +$100 and uses the same offsets for its PEA run and exit jumps.
_INT_OFFSET    equ  $00                   ; code to enable interrupts before the line
_ENTRY_OFFSET  equ  $11                   ; normal entry point for each line
_ALIGN_PATCH   equ  $15                   ; BRA (even) or LDA #imm (odd), patched per line
_EDGE_PATCH    equ  $17                   ; LDX #imm with the offset of the odd right edge byte (operand at +1)
_ENTRY_PATCH   equ  $1E                   ; BRL to the first PEA (operand at +1)
_E_OUT_OFFSET  equ  $21                   ; top jump to the even exit
_O_OUT_OFFSET  equ  $24                   ; top jump to the odd exit
_PEA_OFFSET    equ  $27                   ; first PEA instruction
_LOOP_OFFSET   equ  $E7                   ; BVC / JMP pair after the PEA run
_E_EXIT_OFFSET equ  $EF                   ; exit_even: saved PEA instruction (P1 has a JMP here)
_SAVE_OFFSET   equ  $F0                   ; saved PEA operand
_E_JMP_OFFSET  equ  $F2                   ; even exit JMP to the next line (operand at +1)
_O_EXIT_OFFSET equ  $F6                   ; exit_odd (P1 has a JMP here)
_O_JMP_OFFSET  equ  $FA                   ; odd exit JMP to the next line (operand at +1)

_LINE_SPAN  equ  512                     ; always 512 bytes between adjacent rows
_LINES_PER_BANK equ 120

; Values patched into _ALIGN_PATCH.  Even lines branch over the edge byte code to the BRL.  Odd lines
; execute a harmless 8-bit LDA #imm and fall into the code that pushes the right edge byte.
BLT_ALIGN_EVEN equ  $80+{{_ENTRY_PATCH-_ALIGN_PATCH-2}*256}
BLT_ALIGN_ODD  equ  $00A9

; Processor status values used to enter the blitter.  M = 1, X = 0 and I = 1 always.
BLT_P_BASE     equ  $24
BLT_P_HORZ     equ  $40                   ; V = 1 for horizontal mirroring

; Set up some symbols to reference the different shadow memory in the PPU static bank. All of these
; shadow areas are meant to be accessed using using an CIRAM address ($000 - $7FF)
; e.g. ldal TILE_SHADOW,x
;
; Since moving to directly modeling CIRAM, the size of each buffer could be reduces to $800 bytes.  But we are leaving them
; for now.  Justknow that only the first half od each region should have data.

TILE_SHADOW   equ $4000          ; shadowed values of the nametable tiles
ATTR_SHADOW   equ $5000          ; pre-calculated attribute values derived from the attribute bytes in $2nC0 PPU RAM

; These three tables are static since the PEA fields are 1:1 to the CIRAM layout. Note that these tables simply replicate
; information that's already in the BTableHigh and BTableLow arrays. For a given CIRAM address N, the address corresponds
; to the Nth entry in those tables.  This is just a convenient way to get the information in 8-bit mode.

TILE_BANK     equ $6000          ; pre-calculated data bank value for the location of the associated PEA field tile
TILE_ADDR_LO  equ $7000          ; pre-calculated address (low byte) of the location of the PEA field tile
TILE_ADDR_HI  equ $8000          ; pre-calculated address (high byte) of the location of the PEA field tile

; Compiled sprite cache (core/sprites/CompileSprites.s).
;
; A compiled sprite is the code for one tile with one vertical orientation, in two variants: as is and
; flipped horizontally.  The sprite compile bank is divided into fixed, unpacked slots sized for the worst case:
;
;     2 variants * (16 words * 14 bytes + 4 byte return) = 456 bytes -> 512 byte slots
;
; Slot 0 is not used because address $0000 in SPR_COMP_TBL means "not compiled", so there are at most 127.
;
; SPR_COMP_TBL maps a sprite to the address of its compiled code, or 0.  It is indexed by the "key offset":
;   key offset = (pattern table << 11) | (tile << 3) | (vertical flip << 2) | (horizontal flip << 1)
; The two horizontal flips of a key are compiled together, into one slot, so their entries are set and cleared
; together.  Everywhere else the key offset has the horizontal flip bit clear.
;
; Slots are replaced in the order they were filled (a FIFO): SPR_CURSOR goes round the slots, and the slot it
; points to is the next one used; if a key owns it (SPR_OWNER), that key is evicted.  A cache hit does not
; change anything.  A CHR-RAM write frees a key's slot, which is reused when the cursor gets back to it.
SPR_COMP_TBL  equ $9000               ; 2048 words
SPR_SLOT_SIZE equ $0200
SPR_SLOTS     equ 127                 ; the number of slots used (1 - 127)

; The number of sprite tiles compiled per drawSprites call (0 - 4; 0 never compiles).  The sprites that miss
; are drawn from their bitmaps until they are compiled.  2 was measured to be the best (docs/BENCH_ZELDA.md).
SPR_COMPILE_PER_RENDER equ 2
SPR_OWNER     equ $A000               ; 128 words, indexed by slot address >> 8: the key offset that owns the slot,
                                      ; or $FFFF if none
SPR_CURSOR    equ $A100               ; the address of the slot that is used next
SPR_PEND_CNT  equ $A102               ; byte offset of the end of the pending list
SPR_PEND      equ $A104               ; keys that missed this render, waiting to be compiled (4 words)

; $A10C-$AFFF: free (formerly the TILE_VERSION0/1 dedup tables)

;TILE_ROW      equ $B000          ; pre-calculated row of the PPU address
;TILE_COL      equ $C000          ; pre-calculated column of the PPU address

; Grid dirty renderer (ppu_grid.s): per-cell lookup tables, one word per 8x8 screen cell (max 800 cells)
GRID_CELL_SCR  equ $B000         ; SHR address of the cell
GRID_CELL_PEA  equ $B800         ; code field address of the tile shown in the cell
GRID_CELL_BANK equ $C000         ; code field bank of that tile (in both bytes)

; $C800-$CFFF / $E800-$EFFF: nametable shadow data buffers 0 / 1 (ppu_queues.s, NTM_SB0 / NTM_SB1)



; Return codes from the Event Loop harness
USER_SAYS_QUIT  equ 'q'
USER_SAYS_RESET equ 'r'

; APU emulation constants
APU_60HZ  equ 0
APU_120HZ equ 1
APU_240HZ equ 2

; Address in the ROMBase bank of the DMC sample area (NES $C000, where $4012 = 0)
DMC_SAMPLE_BASE equ $C000

; NES Register definitions
NES_PPUMASK_BG  equ $08
NES_PPUMASK_SPR equ $10

NES_PPUCTRL_SPRSIZE equ $20

; NES Nametable Mirroring
HORIZONTAL_MIRRORING equ $01
VERTICAL_MIRRORING   equ $02

HORIZONTAL_MIRROR_MASK equ $0BFF
VERTICAL_MIRROR_MASK equ $07FF

; The bench "cartridge": a tiny NES program for the engine benchmark.  It has no game logic at all.
;
;   reset : upload the palette and both nametables (scene.s, made by build.js), queue the ground music
;           and turn the screen on.  It returns, so the NES task only runs the NMI handler after this.
;   NMI   : play the music (music.s).  Nothing else: the scrolling and the sprite animation are done
;           once per render on the IIgs side (BenchStep in Main.s), so every render shows a new frame
;           and the frame rate is the speed of the engine.
;
; The code runs like any converted ROM (rom_exec.s): 8-bit registers, D = the NES zero page, DBR = this
; bank, called with JSL and returning with RTL.

ROMBase     ENT

; NES RAM ($0000 - $07FF).  The zero page and the stack live in the runtime's direct page and stack, but
; the rest is here, in this bank.  $0200 - $02FF is the OAM buffer (DIRECT_OAM_READ): Main.s fills it in.
            ds    $0800

; Variables of SMB's music player (music.s), at the same addresses as in SMB

Squ2_NoteLenBuffer    = $07b3
Squ2_NoteLenCounter   = $07b4
Squ2_EnvelopeDataCtrl = $07b5
Squ1_NoteLenCounter   = $07b6
Squ1_EnvelopeDataCtrl = $07b7
Tri_NoteLenBuffer     = $07b8
Tri_NoteLenCounter    = $07b9
Noise_BeatLenCounter  = $07ba

Square1SoundBuffer    = $f1
Square2SoundBuffer    = $f2
AreaMusicQueue        = $fb
EventMusicQueue       = $fc
AreaMusicBuffer       = $f4
EventMusicBuffer      = $07b1

MusicData             = $f5
MusicDataLow          = $f5
MusicDataHigh         = $f6
MusicOffset_Square2   = $f7
MusicOffset_Square1   = $f8
MusicOffset_Triangle  = $f9
MusicOffset_Noise     = $07b0

NoteLenLookupTblOfs   = $f0
NoiseDataLoopbackOfs  = $07c1
NoteLengthTblAdder    = $07c4
AreaMusicBuffer_Alt   = $07c5
GroundMusicHeaderOfs  = $07c7
AltRegContentFlag     = $07ca

SoundMemory           = $07b0       ; $07b0 - $07cf: the music player's RAM

GroundMusic           = %00000001
TimeRunningOutMusic   = %01000000
EndOfCastleMusic      = %00001000
VictoryMusic          = %00000100
DeathMusic            = %00000001

MusicHeaderOffsetData = MusicHeaderData-1
MHD                   = MusicHeaderData

; Zero page
ptr                   = $00         ; pointer for the nametable upload

; The runtime's ROM support code (PPU / APU register shims, yield) and its tables
            ds    $6000-*           ; (the cartridge has no WRAM)
HORIZONTAL_MIRRORING equ $01        ; From core/Defs.s, which is not included in the ROM segment
VERTICAL_MIRRORING   equ $02
            put   ../../rom/rom_inject.s

y_exclude   ENT                     ; Table of excluded sprite Y values -- filled in by InitYExclude at start-up
            ds    256

tile_exclude ENT                    ; Table of excluded tiles (non-zero = skip sprites using that tile)
            ds    256,$00

; PRG-ROM
            ds    $8000-*

            mx    %11
Reset
            lda   #$10              ; NMI off, background tiles at $1000, 8x8 sprites at $0000
            jsr   STA_2000
            lda   #$00              ; Screen off
            jsr   STA_2001

; Clear the zero page and the music player's RAM

            ldx   #0
:zp         stz   $00,x
            inx
            bne   :zp
            ldx   #$1f
:snd        stz   SoundMemory,x
            dex
            bpl   :snd

; Palette RAM ($3F00 - $3F1F)

            lda   #$3F
            jsr   STA_2006
            lda   #$00
            jsr   STA_2006
            ldx   #0
:pal        lda   BenchPalette,x
            jsr   STA_2007
            inx
            cpx   #32
            bcc   :pal

; Both nametables ($2000 and $2400, side by side with vertical mirroring), 2KB in one go

            lda   #$20
            jsr   STA_2006
            lda   #$00
            jsr   STA_2006
            lda   #<BenchNametables
            sta   ptr
            lda   #>BenchNametables
            sta   ptr+1
            ldx   #8                ; 8 pages
            ldy   #0
:nt         lda   (ptr),y
            jsr   STA_2007
            iny
            bne   :nt
            inc   ptr+1
            dex
            bne   :nt

; Start the World 1-1 music

            lda   #$0f              ; Square 1 and 2, triangle and noise on
            jsr   STA_4015
            lda   #GroundMusic
            sta   AreaMusicQueue

; Turn the screen on: NMI on, background tiles at $1000, background and sprites shown everywhere.
; The scroll and the nametable select are set for each render by BenchStep (Main.s).

            lda   #$90
            jsr   STA_2000
            lda   #$1E
            jsr   STA_2001
            rtl

; The NMI handler: only the music
NMI
            jsr   MusicHandler
            lda   #$00              ; (SoundEngine clears the queues after each call)
            sta   AreaMusicQueue
            sta   EventMusicQueue
IRQ         rtl                     ; the NMI handler is called with JSL

            put   music.s
            put   scene.s

            ds    $FFFA-*           ; Pad up to the vectors
            dw    NMI,Reset,IRQ

; rom_color.s - NES palette table and colour conversion utilities
;
; Self-contained module: no external symbol dependencies.
; Included by rom_helpers.s; can also be included alone for unit testing.
;
; Exports:
;   NES_ColorPalette  - 64-entry word table (IIgs 12-bit RGB)
;   NES_ColorToIIgs   - convert NES index in A → IIgs RGB in A (Y clobbered)
;   NES_ColorToIIgs_X - same, uses X instead of Y

            mx    %00

; NES master palette: 64 entries, each a 12-bit IIgs RGB word ($0RGB).
; Illegal/undefined NES colour indices map to black ($0000).
NES_ColorPalette
            dw    $0666   ;  0
            dw    $0029   ;  1
            dw    $000D   ;  2
            dw    $074D   ;  3
            dw    $0907   ;  4
            dw    $0B07   ;  5
            dw    $0B20   ;  6
            dw    $0940   ;  7
            dw    $0740   ;  8
            dw    $0240   ;  9
            dw    $0072   ;  10
            dw    $0090   ;  11
            dw    $0044   ;  12
            dw    $0000   ;  13 illegal
            dw    $0000   ;  14 illegal
            dw    $0000   ;  15 illegal

            dw    $0BBB   ;  16
            dw    $007E   ;  17
            dw    $004F   ;  18
            dw    $090F   ;  19
            dw    $0B0F   ;  20
            dw    $0F09   ;  21
            dw    $0F00   ;  22
            dw    $0E60   ;  23
            dw    $0970   ;  24
            dw    $0290   ;  25
            dw    $0090   ;  26
            dw    $00B7   ;  27
            dw    $0099   ;  28
            dw    $0000   ;  29 illegal
            dw    $0000   ;  30 illegal
            dw    $0000   ;  31 illegal

            dw    $0FFF   ;  32
            dw    $07BF   ;  33
            dw    $099F   ;  34
            dw    $0D6F   ;  35
            dw    $0F0F   ;  36
            dw    $0F6F   ;  37
            dw    $0F90   ;  38
            dw    $0FB0   ;  39
            dw    $0DD0   ;  40
            dw    $06D0   ;  41
            dw    $00F0   ;  42
            dw    $04FD   ;  43
            dw    $00FF   ;  44
            dw    $0440   ;  45 "illegal"
            dw    $0000   ;  46 illegal
            dw    $0000   ;  47 illegal

            dw    $0FFF   ;  48
            dw    $0BEF   ;  49
            dw    $0DBF   ;  50
            dw    $0FBF   ;  51
            dw    $0F9F   ;  52
            dw    $0FBB   ;  53
            dw    $0FD9   ;  54
            dw    $0FF4   ;  55
            dw    $0FF7   ;  56
            dw    $0BF4   ;  57
            dw    $09F6   ;  58
            dw    $04FD   ;  59
            dw    $08DF   ;  60
            dw    $0BBB   ;  61 "illegal"
            dw    $0000   ;  62 illegal
            dw    $0000   ;  63 illegal

; NES_ColorToIIgs
; A = NES colour index (0-63; high byte ignored)
; Returns: A = IIgs 12-bit RGB word, Y clobbered
            mx    %00
NES_ColorToIIgs
            and   #$003F
            asl
            tay
            lda   NES_ColorPalette,y
            rts

; NES_ColorToIIgs_X
; A = NES colour index (0-63; high byte ignored)
; Returns: A = IIgs 12-bit RGB word, X clobbered
            mx    %00
NES_ColorToIIgs_X
            and   #$003F
            asl
            tax
            lda   NES_ColorPalette,x
            rts

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
            dw    $0777   ;  0
            dw    $000f   ;  1
            dw    $000b   ;  2
            dw    $042b   ;  3
            dw    $0908   ;  4
            dw    $0a02   ;  5
            dw    $0a10   ;  6
            dw    $0810   ;  7
            dw    $0530   ;  8
            dw    $0070   ;  9
            dw    $0060   ; 10
            dw    $0050   ; 11
            dw    $0045   ; 12
            dw    $0000   ; 13 illegal
            dw    $0000   ; 14 illegal
            dw    $0000   ; 15 illegal
            dw    $0bbb   ; 16
            dw    $007f   ; 17
            dw    $005f   ; 18
            dw    $064f   ; 19
            dw    $0d0c   ; 20
            dw    $0d05   ; 21
            dw    $0f30   ; 22
            dw    $0d51   ; 23
            dw    $0a70   ; 24
            dw    $00b0   ; 25
            dw    $00a0   ; 26
            dw    $00a4   ; 27
            dw    $0088   ; 28
            dw    $0000   ; 29 illegal
            dw    $0000   ; 30 illegal
            dw    $0000   ; 31 illegal
            dw    $0fff   ; 32
            dw    $04bf   ; 33
            dw    $068f   ; 34
            dw    $097f   ; 35
            dw    $0f7f   ; 36
            dw    $0f59   ; 37
            dw    $0f75   ; 38
            dw    $0f94   ; 39
            dw    $0fb0   ; 40
            dw    $0bf1   ; 41
            dw    $05d5   ; 42
            dw    $05f9   ; 43
            dw    $00ed   ; 44
            dw    $0777   ; 45 illegal
            dw    $0000   ; 46 illegal
            dw    $0000   ; 47 illegal
            dw    $0fff   ; 48
            dw    $0adf   ; 49
            dw    $0bbf   ; 50
            dw    $0dbf   ; 51
            dw    $0fbf   ; 52
            dw    $0fab   ; 53
            dw    $0eca   ; 54
            dw    $0fda   ; 55
            dw    $0fd7   ; 56
            dw    $0df7   ; 57
            dw    $0bfb   ; 58
            dw    $0bfd   ; 59
            dw    $00ff   ; 60
            dw    $0fdf   ; 61 illegal
            dw    $0000   ; 62 illegal
            dw    $0000   ; 63 illegal

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

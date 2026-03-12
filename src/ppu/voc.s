; Support routines for setting up and targeting the Video Overlay Card in two-plane mode as described
; by dwsJason on Apple II Infinitum slack.
;
; 1. Feed the IIgs motherboard composite output into the VOC input
; 2. Set VOC to display from Main Memory Bank $E0 (bits 5:4 os $C0B1 = 01) with linearization endabled
;
; When rendering the a NES frame
;
;  1. Render the background into Bank $01 with shadowing enables to copy it to the IIgs output.  This is done
;     in a single top-down pass
;
;  2. Render the sprites into bank $E0 directly using absolute addressing.  In theory, the top half of Bank $E0
;     is shadowed from Bank $00, but that is too much complexity for little benefit.
;
;     a. The sprite rendering does need to be composited because there is no way to hide intermetiate writes
;        to Bank $E0 and not have them show up on the screen.  The VOC does not scan out IIgs memory, but captures
;        writes into its own internal memory.
;
;     b. Thus, the sprites are written into a temporary IIgs memory buffer.  Old sprites are erased by filling in all
;        zero values, the new sprites are drawn and then all of the dirty screen areas are copied into Bank $E0.
;
;     c. For eficiency, since most sprites remain spatially close to their prior position, the off-screen buffer
;        is organized into blocks and minimize the amount of copying.
;
;     d. NOTE: The priority bit for sprites can still be supported as long as the background in drawn first.  Instead
;        of testing the pixel values in Bank $E0, they need to test the values in Bank $E1.  In fact, with the VOC
;        setup, it may be possible to mimic the NES sprite priority quirk
;        https://www.nesdev.org/wiki/File:Sprite_priority_quirk.png

VOC_SLOT equ 3
VOC_CONTROL_REGISTER equ $C0B1
VOC_DISSOLVE_REGISTER equ $C0B3
VOC_BLUE_GREEN_REGISTER equ $C0B4
VOC_RED_REGISTER equ $C0B5

; Main Bank Page Select + Linearization Enable
        mx %00
SetupVOC
        php
        sep #$20

        ldal VOC_CONTROL_REGISTER
        and  #%11000111
        ora  #%00011000
        stal VOC_CONTROL_REGISTER

        ldal VOC_DISSOLVE_REGISTER      ; Bank $E0 graphics are 100% opaque.
        and  #%11111000
        stal VOC_DISSOLVE_REGISTER
        plp

; Set color index 0 to the chroma key vaue in the main memory bank ($E0) and set the VOC chroma key to this value
; to allow the background to show through the sprite layer.

        lda  #ChromaKeyRGB
        stal $E09E00
        jsr  SetChromaKey
        rts

; When targeting the VOC, the swizzle table is degenerate because we have access to two independent SHR screens, each
; with a 16-color palette, so the background and sprite palette entries are set directly
;
; NES Palette : IIgs Palette Indices
; ------------:---------------------
; BG0        -> $00, $01, $02, $03
; BG1        -> $00, $05, $06, $07
; BG1        -> $00, $09, $0A, $0B
; BG1        -> $00, $0D, $0E, $0F
;
; SP0        -> $00, $01, $02, $03
; SP1        -> $00, $05, $06, $07
; SP2        -> $00, $09, $0A, $0B
; SP3        -> $00, $0D, $0E, $0F
;
; The imporant bit is to make sure that when the background color 0 is changes that the chroma key value
; in the VOC is also updated.

; A = IIgs RGB value $0RGB, where R,G,B are 4-bit values from $0-$F
        mx %00
SetChromaKey
        php
        sep #$20

        stal VOC_BLUE_GREEN_REGISTER    ; store Blue/Green directly
        xba
        and  #$0F                       ; Mask off the Red value
        ora  #$30                       ; set blanking source to the NTSC input and genlock to NTSC
        stal VOC_RED_REGISTER           ; store Red directly (maybe set blanking to NTSC?)

        ldal VOC_CONTROL_REGISTER
        and  #%11000111
        ora  #%00011000
        stal VOC_CONTROL_REGISTER

        ldal VOC_DISSOLVE_REGISTER      ; Bank $E0 graphics are 100% opaque.
        and  #%11111000
        stal VOC_DISSOLVE_REGISTER
        plp
        rts
; Allocate 6kb of RAM for the stand and direct page.  This can be streamlines later, but the space it utilized
; as
;
; $0000: App Direct Page for primary global variables
; $0100: 256 bytes of memory used as a NES OAM mirror
; $0700: 1280 bytes of application stack space
; $1800: 4kb + 256 bytes for sprite save/restore
    ds  $1800
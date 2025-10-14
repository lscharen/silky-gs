; Allocate 6kb of RAM for the stack and direct page.  This can be streamlined later, but the space is utilized
; as
;
; $0000: App Direct Page for primary global variables
; $0100: 256 bytes of memory used as a NES OAM mirror
; $0700: 1280 bytes of application stack space
; $1800: 4kb + 512 bytes for sprite save/restore
    ds  $1900
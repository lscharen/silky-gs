; Allocate 6kb of RAM for the stand and direct page.  This can be streamlines later, but the space it utilizes
; as
;
; $0000: App Direct Page for primary global variables
; $0100: 256 bytes of memory used as a NES OAM mirror
; $0200: NES Zero Page (256 bytes)
; $0300: NES Stack Page (256 bytes)
; $0400: 4kb + 512 bytes for sprite save/restore ($1200 bytes)
; $1600: 768 bytes of application stack space
; $1900: <end>
    ds  $1900
            REL

            use   ../../../macros/Util.Macs
            use   ../../../macros/Mem.Macs

            put   ../../core/Defs.s

    mx   %00
Entry
    sta   UserId              ; boot stub leaves the Memory Manager Master
                               ; ID from MMStartUp in A; AllocOneBank (and
                               ; NewHandle generally) expects it as this
                               ; direct-page variable instead

    ; Same NewHandle call as src/core/Memory.s::AllocOneBank, for a
    ; focused test of that exact allocation pattern.
    PushLong  #0
    PushLong  #$10000
    PushWord  UserId
    PushWord  #%11000000_00011100
    PushLong  #0
    _NewHandle                 ; returns LONG Handle on stack
    plx                        ; base address of the new handle
    pla                        ; high address 00XX of the new handle (bank)
    xba                        ; swap accumulator bytes to XX00
    stal      :bank+2          ; store as bank for next op (overwrite $XX00)
:bank
    ldal      $000001,X        ; recover the bank address in A=XX/00

    rtl         ; "normal" exit 
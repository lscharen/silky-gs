; This file contains all of the core routines that should be called from the
; wrapper code.  It is expected that the wrapped defined several callback functions
; and constants that can be used to parametering the NES runtime layer

            mx %00

; Scaffold init
;
; Should be called immediately afte the application gets control from GS/OS
NES_StartUp

            sta   UserId                  ; GS/OS passes the memory manager user ID for the application into the program
            _MTStartUp                    ; Require the miscellaneous toolset to be running
            bcc   *+5
            brl   Fail

; Keep a copy of the application's direct page to be restored later

            tdc
            sta   DPSave

            clc
            adc   #$100
            sta   DP_OAM                  ; Use direct page space for the PPU OAM memory

; Set up the initial register values when transferring control to the NES ROM code

            sep   #$20
            lda   #$FF
            sta   yield_s
            rep   #$20

; Initialize some application variables

            ldal  OneSecondCounter
            sta   OldOneSec

            stz   ShowFPS
            stz   YOrigin

;            lda   #4                      ; Default to "Best" mode
;            sta   VideoMode
;            sta   AudioMode

            lda   #$0008
            sta   LastEnable

            stz   LastStatusUdt

            jsr   _GetBorderColor
            sta   BorderColor
            lda   #0
            jsr   _SetBorderColor

; Used for VOC rendering mode to togglee target of the PEA field render between
; bank $01 and $00

            lda   #1
            sta   ActiveBank

; Start up the runtime

            jsr   StartUp
            bcc   *+5
            jmp   Fail

; Initialize the PPU

            jsr   PPUStartUp
            bcc   *+5
            jmp   Fail

; Initialize the sound hardware for APU emulation

            DO    NO_INTERRUPTS
            ELSE
            lda   config_audio_quality
            jsr   APUStartUp              ; 0 = 240Hz, 1 = 120Hz, 2 = 60Hz (external)
            FIN

; Clear the IIgs screen and initialize the rendering infrastrucure

            lda   #0
            jsr   _ClearToColor
            jsr   InitPlayfield

; Convert the CHR ROM from the cart into blittable tiles

            jsr   ROM_LoadBackgroundTiles
            jsr   ROM_LoadSpriteTiles

; Now the core of the runtime has been initialized
            rts

; Catastrophic failure
Fail        brk   $FE


; Perform any initialization actions
StartUp
            jsr   PPUResetQueues
            lda   UserId
            jmp   _CoreStartUp

; Perform any shutdown/cleanup actions
ShutDown
            jmp   _CoreShutDown

; NES_ColdBoot
;
; Invoke the reset vector
NES_ColdBoot
            ldal  ROMBase+$FFFC         ; Reset Vector
            tax
            sei
            jsr   romxfer               ; Cannot allow interrupts within the rom dispatch
            cli
            rts

NES_WarmBoot
            ldal  ROMBase+$FFFC
            tax
            sei
            jsr   romxfer
            cli
            rts

; A pair of utility functions to stop/start the actual execution of the game runtime.  This is
; used to cleanly suspend the VBL interrupt driver and allow "something else" to happen.  Typically
; this can be used to invoke the configuration screen and reset the runtime in the middle of running
; a ROM.
;
; NES_StopExecution
; NES_StartExecution
NES_StopExecution
            lda  #1
            sta  skipInterruptHandling
            rts

NES_StartExecution
            lda  #0
            sta  skipInterruptHandling
            rts

; NES_EvtLoop
;
; The main control loop.  Pressing 'q' will exit the driver.
            PRE_EVT_LOOP
NES_EvtLoop
            EVT_LOOP_BEGIN

; If interrupts are disabled, then the ROM NMI interrupt needs to
; driven manually

            DO    NO_INTERRUPTS
            jsr   NES_ReadInput
            jsr   NES_TriggerNMI
            ELSE

; Wait for a frame to become available.  This almost never waits, unless
; dirty rendering mode is on and there are no updated to the screen,
; or the user is running under emulation

:spin       lda  frameReady
            bne  :spin
            inc  frameReady
            FIN

; When this code has control the ROM is not executing, so render the
; current frame

            jsr   NES_RenderFrame

; The input is read from the VBL interrupt handler.  If no
; new key input is available, then nothing else to do here

            lda   LastRead
            bit   #PAD_KEY_DOWN
            beq   NES_EvtLoop

; Isolate the keycode and handle all of the built-in
; actions.  Afterwared, allow for application-specific
; handlers.

            and   #$007F

; 'b': force the NES Background bit to be toggled

            cmp   #'b'
            bne   :not_b
            lda   ppumask_override
            eor   #NES_PPUMASK_BG
            sta   ppumask_override
            brl   NES_EvtLoop
:not_b

; 's': force the NES Sprite bit to be toggled

            cmp   #'s'
            bne   :not_s
            lda   ppumask_override
            eor   #NES_PPUMASK_SPR
            sta   ppumask_override
            brl   NES_EvtLoop
:not_s

; '?' to bring up the configuration screen and reapply the settings

            cmp   #'?'
            bne   :not_config
            jsr   stop_playing                            ; Turn off the APU (restarted in Apply Config)
            jsr   NES_StopExecution                       ; Pause emulation nicely
            jsr   ShowConfig                              ; Let the user reconfigure
            jsr   ApplyConfig                             ; Apply to the running configuration
            lda   #DIRTY_BIT_BG0_REFRESH                  ; Force a full page refresh on config exit
            tsb   DirtyBits
            jsr   NES_StartExecution
            brl   NES_EvtLoop
:not_config

; '0': force all of the APU channels to be turned off
            cmp   #'0'
            bne   :not_0
            stz   APU_FORCE_OFF
            brl   NES_EvtLoop
:not_0

; '1' - '4': toggle individual APU channels
            cmp   #'1'
            bne   :not_1
            lda   #$01
            jsr   ToggleAPUChannel
            brl   NES_EvtLoop
:not_1

            cmp   #'2'
            bne   :not_2
            lda   #$02
            jsr   ToggleAPUChannel
            brl   NES_EvtLoop
:not_2

            cmp   #'3'
            bne   :not_3
            lda   #$04
            jsr   ToggleAPUChannel
            brl   NES_EvtLoop
:not_3

            cmp   #'4'
            bne   :not_4
            lda   #$08
            jsr   ToggleAPUChannel
            brl   NES_EvtLoop
:not_4

            cmp   #'r'
            beq   :exit

            cmp   #'q'
            beq   :exit

:next_loop
            EVT_LOOP_END
            brl   NES_EvtLoop
:exit
            POST_EVT_LOOP
            rts

; Clean up the runtime
NES_ShutDown
            lda   BorderColor              ; Restore the border color
            jsr   _SetBorderColor

            DO    NO_INTERRUPTS
            ELSE
            jsr   APUShutDown
            FIN
            jsr   ShutDown
            rts

OneSecondCounter  dw  0
DPSave            dw  0
DP_OAM            dw  0
BorderColor       dw  0            ; save/restore border color

; Built-in user key actions

; Toggle an APU control bit
ToggleAPUChannel
            pha
            lda   #$0001
            stal  APU_FORCE_OFF
            pla

            php
            sep   #$30
            eorl  APU_STATUS
            jsl   APU_STATUS_FORCE
            plp
            rts


; Helper to perform the essential functions of rendering a frame
            mx  %00
NES_RenderFrame
:nt_head    equ tmp3
:at_head    equ tmp4

; First, disable interrupts and perform the most essential functions to copy any critical NES data and
; registers into local memory so that the rendering is consistent and not affected if a VBL interrupt
; occures between here and the actual screen blit

            php
            sei

            jsr   scanOAMSprites          ; Filter out any sprites that don't need to be drawn and mark occupied lines

            lda  nt_queue_head            ; These are used in PPUFlushQueues, so using tmp locations is OK
            sta  :nt_head
            lda  at_queue_head
            sta  :at_head

            DO   CUSTOM_PPU_CTRL_LOCK
            CUSTOM_PPU_CTRL_LOCK_CODE
            ELSE
            lda  ppuctrl                  ;  Cache these values that are used to set the view port
            FIN
            sta  _ppuctrl

            DO   CUSTOM_PPU_SCROLL_LOCK
            CUSTOM_PPU_SCROLL_LOCK_CODE
            ELSE
            lda  ppuscroll
            FIN
            ldal  ROMBase+$073f
            sta  _ppuscroll+1

            plp

; Allow the user code to introspect and intervene at this point

            PRE_RENDER

; Apply all of the tile updates that were made during the previous frame(s).  The color attribute bytes are always set
; in the PPUDATA hook, but then the appropriate tiles are queued up.  These tiles, the tiles written to by PPUDATA in
; the range ($2{n+0}00 - $2{n+3}C0)
;
; The queue is set up as a Set, so if the same tile is affected by more than one action, it will only be drawn once.
; Practically, most NES games already try to minimize the number of tiles to update per frame.

            jsr   PPUFlushQueues

; Finally, render the PEA field to the Super Hires screen.  The performance of the runtime is limited by this
; step and it is important to keep the high-level rendering code generalized so that optimizations, like falling
; back to a dirty-rectangle mode when the NES PPUSCROLL does not change, will be important to support good performance
; in some games -- especially early games that do not use a scrolling playfield.

            jsr   RenderScreen

; Game specific post-render logic

            POST_RENDER

; Internal post-render logic

            inc   frameCount       ; Tick over to a new frame
            rts

; Tracks the number of times NES_RenderFrame has been called
frameCount   dw  0

; Cleared when the NMI handler has run.  Used to limit updates to 60fps
frameReady   dw  0

; Set to abort from the VBL interrupt handler.  Effectively stops the execution of the ROM game code
skipInterruptHandling dw 0
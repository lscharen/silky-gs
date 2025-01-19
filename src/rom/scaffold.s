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

            lda   #$0008
            sta   LastEnable

            stz   LastStatusUdt

            jsr   _GetBorderColor
            sta   BorderColor
            lda   #0
            jsr   _SetBorderColor

; Used for VOC rendering mode to toggle target of the PEA field render between
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
; dirty rendering mode is on and there are no updates to the screen,
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

; 'f': force a full repaint of the screen
            cmp   #'f'
            bne   :not_f
            jsr   ForceMetatileRefresh
            brl   NES_EvtLoop
:not_f

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

            DO    NO_CONFIG
            ELSE
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
            FIN

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
            sta  _ppuscroll

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

            DO    CUSTOM_RENDER_SCREEN
            jsr   CUSTOM_RENDER_SCREEN_ADDR
            ELSE
            jsr   RenderScreen
            FIN

; Game specific post-render logic

            POST_RENDER

; Internal post-render logic

            inc   frameCount       ; Tick over to a new frame
            rts

; Helper functions for patching and restoring the PEA field.  These could
; be overridden for games that want to preserve the ability to switch between
; dirty an full rendering, but still have a custom screen layout
_SetupPEAField
            jsr   _BltSetup
            sta   exitOffset              ; cache the :exit_offset value returned from this function

            lda   #1
            sta   peaFieldIsPatched
            rts

_ResetPEAField
            stz   peaFieldIsPatched

            ldy   exitOffset              ; offset to patch
            jmp   _RestoreBG0OpcodesLite

_GetPPUScrollX
            sep   #$20
            lda   _ppuctrl                ; Bit 0 is the high bit of the X scroll position
            lsr                           ; put in the carry bit
            lda   _ppuscroll+1            ; load the scroll value
            ror                           ; put the high bit and divide by 2 for the engine
            rep   #$20
            and   #$00FF                  ; make sure nothing is in the high byte
            asl                           ; Put back into the NES Pixel range
            tax
            rts

_GetPPUScrollY
            sep   #$20
            lda   _ppuctrl                ; Bit 1 is the high bit of the Y scroll position
            lsr
            lsr                           ; put in the carry bit
            lda   _ppuscroll              ; load the scroll value
            ror
            rep   #$20
            rol
            and   #$01FF
            tay
            rts

; Default render screen implementation.  The user-code can override this and provide their
; own to improve performance.
RenderScreen
            jsr   _GetPPUScrollX          ; Return in X register
            jsr   _GetPPUScrollY          ; Return in Y register

            jsr   NES_SetScroll           ; Set the engine to this scroll position

            lda   ppumask                 ; honor the PPU enable flags for sprites and background
            and   ppumask_override
            and   #NES_PPUMASK_BG
            jsr   EnableBackground

            lda   ppumask
            and   ppumask_override
            and   #NES_PPUMASK_SPR
            jsr   EnableSprites

; Allow dirty rendering or not

            DO    ENABLE_DIRTY_RENDERING

; If this frame did not scroll, we can perform a dirty update

            lda   #DIRTY_BIT_BG0_X+DIRTY_BIT_BG0_Y+DIRTY_BIT_BG0_REFRESH
            bit   DirtyBits
            bne   :full_update
            lda   disableDirtyRendering
            bne   :full_update

; This is code path for performing dirty rendering.

            jsr   _BltSetupDirty
            sta   exitOffset
            jsr   drawDirtyScreen
            ldy   exitOffset
            jsr   _RestoreBG0OpcodesLite
            bra   :dirty_done

:full_update
            jsr   _BltSetup
            sta   exitOffset
            jsr   drawScreen
            ldy   exitOffset
            jsr   _RestoreBG0OpcodesLite
:dirty_done

;            lda   peaFieldIsPatched
;            bne   :no_patch
;            jsr   _SetupPEAField
;:no_patch   jsr   drawDirtyScreen
;            bra   :complete
;
;:full_update
;            lda   peaFieldIsPatched
;            beq   :no_restore
;            jsr   _ResetPEAField
;:no_restore
;            jsr   _SetupPEAField
;            jsr   drawScreen
;:complete
            ELSE

            jsr   _BltSetup
            sta   exitOffset              ; cache the :exit_offset value returned from this function

; Copy the sprites and buffer to the graphics screen

            jsr   drawScreen

; Restore the buffer

            ldy   exitOffset              ; offset to patch
            jsr   _RestoreBG0OpcodesLite
            FIN

            stz   DirtyBits
            rts

; Track if the PEA field is patched or not (for dirty rendering)
peaFieldIsPatched dw 0

; If dirty rendering is turned on, provide a way to override it
disableDirtyRendering dw 0

; PEA field offset for the right edge where the BRA instructions are patched in
exitOffset   ds 2

; Tracks the number of times NES_RenderFrame has been called
frameCount   dw  0

; Cleared when the NMI handler has run.  Used to limit updates to 60fps
frameReady   dw  0

; Set to abort from the VBL interrupt handler.  Effectively stops the execution of the ROM game code
skipInterruptHandling dw 0
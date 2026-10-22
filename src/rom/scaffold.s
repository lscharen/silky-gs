; This file contains all of the core routines that should be called from the
; wrapper code.  It is expected that the wrapped defined several callback functions
; and constants that can be used to parametering the NES runtime layer

; Scaffold init
;
; Should be called immediately after the application gets control from GS/OS and
; only called once.
;
; A = cartridge configuration.  Bits 0 and 1 are the nametable mirroring at power on
;     (HORIZONTAL_MIRRORING or VERTICAL_MIRRORING).  For mappers that can switch the
;     mirroring, like the MMC1, this is the mode at a cold start.
; X = memory manager user ID (GS/OS passes it to the application in A)
            mx    %00
NES_StartUp
            stx   UserId
            and   #HORIZONTAL_MIRRORING+VERTICAL_MIRRORING
            stal  PendingMirrorMode       ; Applied by PPUStartUp (before A is reused below)
            sep   #$20                    ; The video state to put back when the game quits
            ldal  SHADOW_REG
            sta   SavedShadow
            ldal  NEW_VIDEO_REG
            sta   SavedNewVideo
            rep   #$20
            _MTStartUp                    ; Require the miscellaneous toolset to be running
            bcc   *+5
            brl   Fail

; Keep a copy of the application's direct page to be restored later

            tdc
            sta   DPSave

            clc
            adc   #$100
            sta   DP_OAM                  ; Use direct page space for the PPU OAM memory

            clc
            adc   #$100                   ; This is the NES direct page space
            sta   DP_NES
            adc   #$1FF                   ; And the next page is the stack page

; Set up the initial register values when transferring control to the NES ROM code

            sta   nesStackTop             ; Initial NES task stack pointer

; Default bank for MMC1 games

            lda   #^ROMBase               ; Start off in Bank 0 of the ROM
            and   #$00FF
            sta   mapper_bank

            lda   #0
            stal  chr_bank                 ; Stub for future MMC1 CHR-bank switching

; Initialize some application variables

            stz   ShowFPS

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

            jsl   PPUStartUpL
            bcc   *+5
            jmp   Fail

; Build the sprite Y filter used by scanOAMSprites from this game's playfield settings

            jsl   InitYExcludeL

; Load the user preferences (PREF_FILENAME, written by NES_ShutDown).  If there is no file yet (first
; run), the defaults in rom_config_setup.s are kept.  The audio quality is used by APUStartUp below;
; the fast blit mode and the game's own values are applied here, as ApplyConfig would.

            jsr   LoadPrefData
            jsr   _FixPrefInputTypes
            jsr   KbdBuildMaps            ; The BASIC keyboard driver's key maps (rom/rom_kbd_basic.s)
            jsr   KbdAdb_Apply            ; The ADB driver's keys, and put it in if it is set (rom/rom_kbd_adb.s)
            DO    JOYSTICK_SUPPORT
            jsl   JoyConfigureL           ; The joystick settings; _InitRenderMode hooks the probe rows if used
            jsr   _InitRenderMode
            FIN
            DO    CONFIG_VIDEO_FASTBLIT
            lda   config_video_fastmode
            beq   :prefs_done
            lda   #CTRL_EVEN_RENDER
            tsb   ControlBits
            jsr   _InitRenderMode
:prefs_done
            FIN
            ldx   #config_block_start
            ldy   #config_game_start
            CONFIG_APPLY_HOOK
            rep   #$30

; Check whether the J13 keyboard driver can read the held keys from the ADB microcontroller (with interrupts off, so
; before the audio interrupts start)

            jsr   J13_Init

; Initialize the sound hardware for APU emulation

            DO    NO_INTERRUPTS
            ELSE
            lda   config_audio_quality
            jsr   APUStartUp              ; APU_60HZ (external driver), APU_120HZ or APU_240HZ
            FIN

; Decode the game's DMC samples into DOC RAM up front (see DMC_SAMPLE_LIST in Main.s)

            DO    CACHE_DMC_SAMPLES
            jsr   APUCacheDMC
            FIN

; Clear the IIgs screen and initialize the rendering infrastrucure.  Shadowing is turned on for the
; clear, so a fast blit setting from the preferences file starts with no stale lines.

            jsr   _ClearShadowScreen
            jsr   InitPlayfield

; The background tiles of both pattern tables are compiled, so the engine follows PPUCTRL like the
; hardware does: the pattern tables are at $0000 at power on (PPUCTRL = 0) and each PPUCTRL the game
; writes selects them (PPUCtrlDecode).  CHR-ROM games have their tiles converted offline into the
; tiledata bank by build.js (scripts/lib/nromBuild.js): compile all 512 now (sprites are compiled when
; they are first drawn, SprCompileTile).  CHR-RAM games don't have a fixed image -- mark every tile
; dirty instead, so DrawPPUTile / CheckBgTileDirty / sprChrCheck compile each tile the first
; time it's drawn (once the game has uploaded real data for it).

            DO    HAS_CHR_RAM
            ldx   #0
            lda   #$0303           ; both bytes = CHRRAM_BG_DIRTY+CHRRAM_SPR_DIRTY
:mtloop     stal  ChrRamDirty,x
            inx
            inx
            cpx   #512
            bcc   :mtloop
            ELSE
            jsl   ROM_CompileBackgroundTilesL
            FIN

; Battery-backed cartridges: restore the WRAM image ($6000-$7FFF of the NES address space, in the
; ROMBase bank) before any ROM code runs.  If there is no file yet (first run), WRAM is left as-is
; and the game sees the same uninitialized memory as a new cartridge.  Saved by NES_ShutDown.

            DO    HAS_BACKED_WRAM
            lda   #$2000
            ldx   #$6000
            ldy   #wrCreateRec
            jsr   LoadROMFile
            FIN

; Now the core of the runtime has been initialized
            rts

; Catastrophic failure
Fail        brk   $FE


; Perform any initialization actions
            mx  %00
StartUp
            lda   UserId
            jmp   _CoreStartUp

; Perform any shutdown/cleanup actions
            mx  %00
ShutDown
            jmp   _CoreShutDown

; NES_ColdBoot / NES_WarmBoot are in rom_exec.s

; A pair of utility functions to stop/start the actual execution of the game runtime.  This is
; used to cleanly suspend the VBL interrupt driver and allow "something else" to happen.  Typically
; this can be used to invoke the configuration screen and reset the runtime in the middle of running
; a ROM.
;
; NES_StopExecution
; NES_StartExecution
            mx  %00
NES_StopExecution
            lda  #1
            sta  skipInterruptHandling
            rts

            mx  %00
NES_StartExecution
            lda  #0
            sta  skipInterruptHandling
            rts

; NES_EvtLoop
;
; The main control loop.  Returns A = USER_SAYS_QUIT (Q, confirmed) or USER_SAYS_RESET (R).

            PRE_EVT_LOOP
            mx  %00
NES_EvtLoop
            EVT_LOOP_BEGIN

; If interrupts are disabled, then the ROM NMI interrupt needs to
; driven manually

            DO    NO_INTERRUPTS
            jsr   NES_TriggerNMI          ; (the frame reads the controller through NES_ReadJoy)
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

; Take the last new key press (each press, or auto-repeat, is one event).  If there is none,
; then nothing else to do here

            jsr   NES_TakeKey            ; (Z set if there is none)
            bne   *+5
            brl   NES_EvtLoop

; Handle all of the built-in actions with the keycode.  Afterwards, allow for
; application-specific handlers.
;
; The built-in keys are '?', the shifted number keys (! @ # ...), Q and R, so that every other key, the
; letters and the numeric keypad included, can be mapped to the controls:
;
;   ?  the configuration screen          !  force a full repaint
;   @  toggle the NES sprites            #  toggle the NES background
;   Q  quit (after a confirmation screen)
;   R  reset the console (the game's Main.s warm-boots it: USER_SAYS_RESET)
;
; A key that a player's keyboard map uses never gets here (_ReadControl takes it out of KeyEvent), so
; the controls come first; '?' always does.

; ?: bring up the configuration screen and reapply the settings

            DO    NO_CONFIG
            ELSE
            cmp   #'?'
            bne   :not_config
            jsr   NES_Pause
            jsr   ShowConfig                              ; Let the user reconfigure
            jsr   NES_Resume                              ; (applies the configuration)
            brl   NES_EvtLoop
:not_config
            FIN

; $ / % / ^ / & (shifted 4 - 7): toggle individual APU channels; * (shifted 8): force all of the APU
; channels to be turned off
;            cmp   #'$'
;            bne   :not_1
;            lda   #$01
;            jsr   ToggleAPUChannel
;            brl   NES_EvtLoop
;:not_1
;
;            cmp   #'%'
;            bne   :not_2
;            lda   #$02
;            jsr   ToggleAPUChannel
;            brl   NES_EvtLoop
;:not_2
;
;            cmp   #'^'
;            bne   :not_3
;            lda   #$04
;            jsr   ToggleAPUChannel
;            brl   NES_EvtLoop
;:not_3
;
;            cmp   #'&'
;            bne   :not_4
;            lda   #$08
;            jsr   ToggleAPUChannel
;            brl   NES_EvtLoop
;:not_4
;
;            cmp   #'*'
;            bne   :not_0
;            stz   APU_FORCE_OFF
;            brl   NES_EvtLoop
;:not_0

; ! (shifted 1): force a full repaint of the screen
            cmp   #'!'
            bne   :not_f
            jsl   ForceMetatileRefreshL
            brl   NES_EvtLoop
:not_f

; @ (shifted 2): force the NES Sprite bit to be toggled

            cmp   #'@'
            bne   :not_s
            ldal  ppumask_override
            eor   #NES_PPUMASK_SPR
            stal  ppumask_override
            brl   NES_EvtLoop
:not_s

; # (shifted 3): force the NES Background bit to be toggled

            cmp   #'#'
            bne   :not_b
            ldal  ppumask_override
            eor   #NES_PPUMASK_BG
            stal  ppumask_override
            brl   NES_EvtLoop
:not_b

; R (either case): reset the console

            cmp   #'r'
            beq   :reset
            cmp   #'R'
            bne   :not_reset
:reset      lda   #USER_SAYS_RESET
            bra   :exit
:not_reset

; Q (either case): quit, if the user confirms it

            cmp   #'q'
            beq   :quit
            cmp   #'Q'
            bne   :next_loop
:quit       jsr   NES_Pause
            jsr   ConfirmQuit                             ; (carry set: quit)
            lda   #USER_SAYS_QUIT
            bcs   :exit
            jsr   NES_Resume
            brl   NES_EvtLoop

:next_loop
            EVT_LOOP_END
            brl   NES_EvtLoop
:exit
            POST_EVT_LOOP
            rts

; NES_Pause / NES_Resume
;
; Around a screen that takes over the display and the keyboard (the configuration screen, the quit
; confirmation): stop the game, its audio and the joystick's scanline interrupts, then reapply the
; configuration (which restarts the audio) and repaint the game's screen.
            mx  %00
NES_Pause
            jsr   APUStop                                ; Turn off the APU (restarted by ApplyConfig)
            jsr   NES_StopExecution                       ; Pause emulation nicely
            DO    JOYSTICK_SUPPORT
            jsl   JoyScanDisarmL                          ; No joystick scanline interrupts there
            FIN
            rts

NES_Resume
            jsr   ApplyConfig                             ; Apply to the running configuration
            lda   #DIRTY_BIT_BG0_REFRESH                  ; Force a full page refresh
            tsb   DirtyBits
            jmp   NES_StartExecution

; Clean up the runtime
            mx  %00
NES_ShutDown
            jsr   NES_StopExecution        ; First stop the VBL task from running NES frames and the 60Hz
                                           ; audio driver while the runtime is taken down
            jsr   J13_ShutDown             ; The ADB interrupt enables, if a J13 row read is in flight
            jsr   KbdAdb_ShutDown          ; Keyboard autopolling back on, if the ADB driver is in
            DO    JOYSTICK_SUPPORT
            jsl   JoyScanDisarmL           ; The joystick's scanline interrupts, if armed
            FIN
            lda   BorderColor              ; Restore the border color
            jsr   _SetBorderColor

            DO    NO_INTERRUPTS
            ELSE
            jsr   APUShutDown
            FIN
            jsr   ShutDown

            sep   #$20                     ; The shadowing and video modes the game started with
            lda   SavedShadow
            stal  SHADOW_REG
            lda   SavedNewVideo
            stal  NEW_VIDEO_REG
            rep   #$20

; Battery-backed cartridges: write the WRAM image back out.  Done after ShutDown, when the NES task
; can no longer be scheduled, so WRAM can't change while it is being written.

            DO    HAS_BACKED_WRAM
            lda   #$2000
            ldx   #$6000
            ldy   #wrCreateRec
            jsr   SaveROMFile
            FIN

; Save the user preferences for the next run (loaded by NES_StartUp)

            jsr   SavePrefData
            rts

OneSecondCounter  dw  0
DPSave            dw  0
DP_OAM            dw  0
DP_NES ENT                         ; (read by the games' engine-side render code)
                  dw  0
BorderColor       dw  0            ; save/restore border color
SavedShadow       dw  0            ; $C035 at start-up, put back by NES_ShutDown
SavedNewVideo     dw  0            ; $C029 at start-up, put back by NES_ShutDown

; Built-in user key actions

; Toggle an APU control bit
            mx  %00
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


; Helper to perform the essential functions of rendering a frame.  The engine latches the NES state
; (RenderLatch) and draws the screen (RenderDraw, ppu_frame.s); the game's hooks run in between and
; after.
            mx  %00
NES_RenderFrame
            jsl   RenderLatch            ; Freeze the queues, latch the PPU registers and the OAM

; Allow the user code to introspect and intervene at this point

            PRE_RENDER

            jsl   RenderDraw             ; Apply the queued tile updates and draw the screen

            DO    RENDER_VBL_COUNT        ; Show the VBLs this render took at the top-left of the screen
            stz   renderActive
            lda   renderVblTicks
            ldx   #0                      ; SHR $2000
            ldy   #$FFFF                  ; colour 15
            jsr   DrawByte
            FIN

            lda   config_video_fps        ; VIDEO > SHOW FPS: renders per second at the top-left of the screen
            beq   *+5
            jsr   DrawFPS

; Game specific post-render logic

            POST_RENDER

; Internal post-render logic

            inc   frameCount       ; Tick over to a new frame
            rts

; VIDEO > SHOW FPS (config_video_fps): once a second (OneSecondCounter), draw the number of renders in
; the last second (framesPerSecond), in decimal, at the top-left of the screen (SHR $2000, the border
; left of the playfield).  Leaving the configuration screen clears the screen, which removes it when
; the option is turned off.  fpsValue keeps the number for tools that read memory.
            mx    %00
DrawFPS
            ldal  OneSecondCounter
            cmp   fpsLastSec
            beq   :out
            sta   fpsLastSec
            ldal  framesPerSecond         ; Saved (8-bit) by the one-second interrupt, which also
            and   #$00FF                  ; resets frameCount
            sta   fpsValue
            ldx   #0                      ; To two BCD digits (at most 60 renders a second)
:tens       cmp   #10
            bcc   :bcd
            sbc   #10
            inx
            bra   :tens
:bcd        sta   fpsTmp
            txa
            asl
            asl
            asl
            asl
            ora   fpsTmp
            ldx   #0                      ; SHR $2000
            ldy   #$FFFF                  ; colour 15
            jsr   DrawByte
:out        rts

fpsLastSec   dw  0
fpsValue     dw  0
fpsTmp       dw  0

; Tracks the number of times NES_RenderFrame has been called
frameCount      dw  0
framesPerSecond ENT
                dw  0

; Cleared when the NMI handler has run.  Used to limit updates to 60fps
frameReady      dw  0

; Set to abort from the VBL interrupt handler.  Effectively stops the execution of the ROM game code
skipInterruptHandling dw 0

; Flag to say if we're in pause/single-step mode
inSingleStep   dw 0

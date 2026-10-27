; ImportMain.s - the MAIN symbols the engine uses
;
; Put by src/Engine.s (the engine segment, shared by every game); MAIN exports them with ENT
; at their definitions.  Everything here is in another bank: long addressing / JSL only
; (scripts/check-xbank.js checks this).

SprBanks                EXT   ; core/Memory.s: the sprite cache's banks
SprBankCount            EXT
renderActive            EXT   ; rom/rom_exec.s: RENDER_VBL_COUNT
renderVblTicks          EXT
framesPerSecond         EXT
DP_NES                  EXT                ; rom/scaffold.s: the NES direct page (custom renderers, scroll locks)   ; rom/scaffold.s: SHOW_DEBUG_VARS
DrawByteL               EXT   ; misc/App.Msg.s: SHOW_DEBUG_VARS
DrawWordL               EXT
config_input_p1_type    EXT   ; rom/rom_config_setup.s: the joystick settings (JoyConfigureL)
config_input_p2_type    EXT
config_joy_cx           EXT
config_joy_cy           EXT
config_joy_sens         EXT

ppumask_override        EXT   ; rom/scaffold.s: PPUMASK bits the runtime overrides (RenderLatch)

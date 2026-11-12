BALLOON FIGHT FOR THE APPLE IIGS
================================

Balloon Fight (Nintendo, 1985) is a one- or two-player game of
flapping through the sky on a pair of balloons, popping the enemies'
balloons and keeping your own. Balloon Trip mode is an endless
scrolling run through a field of sparks.

This version runs the original NES program on the Apple IIgs, on
Silky-GS, a runtime for porting NES games to the IIgs. This file
describes its keys and settings.

Settings are saved in bf.prefs next to the application when you quit
with Q (see below), and are loaded the next time the game starts.


CONTROLLER (DEFAULT KEYS)
-------------------------

                Player 1         Player 2
  D-pad         Arrow keys       W A S D
  A button      Apple (Command)  Control
  B button      Option           Shift
  Start         Return           Return
  Select        Tab              Tab

The A and B buttons are modifier keys, so they can be held together
with any direction. Start and Select are the same for both players.
Player 1's keys can be changed on the INPUT menu of the configuration
screen. Player 2's keys can't be changed.

Letter keys still work with Shift, Control or Caps Lock held, so a
direction key keeps working while a modifier is held as a button.
The exception is H, J, K and U with Control: the IIgs keyboard sends
the same codes as the arrow keys for those.


BUILT-IN KEYS
-------------

  ?        Open the configuration screen
  !        Redraw the whole screen (Shift-1)
  @        Show / hide the sprites (Shift-2)
  #        Show / hide the background (Shift-3)
  R        Reset the game, like the NES console's RESET button
  Q        Quit (asks first: Y quits, N or Escape goes back)

A key that you have set as a controller key works as the controller,
not as a built-in key. The ? key always opens the configuration
screen.


CONFIGURATION SCREEN
--------------------

Press ? while the game runs. The game pauses.

  Up / Down     Move through the menu, or through a menu's settings
  Right         Go from the menu to its settings
  Left          Go back to the menu
  Space         Change the selected setting
  Return        Back to the game (Q does the same)

Changes take effect when you go back to the game. The menus are AUDIO,
VIDEO, INPUT, TURBO, DRIVERS, GAME and CREDITS.


AUDIO
  QUALITY       60 HZ, 120 HZ or 240 HZ: how often the sound is
                updated. Higher sounds closer to the NES but leaves
                less time for the game and the screen.
                The default is 60 HZ.

VIDEO
  SHOW FPS      Show the number of screen redraws per second at the
                top-left of the screen.
  SHOW NES CPU  Use the border color to show how much of the time the
                game itself takes.
  FAST BLIT     Draw only every other line of the screen: faster,
                with dark lines in between.

INPUT
  TYPE          KEYBOARD, JOYSTICK or SNES MAX (see below).

  With KEYBOARD:
  LEFT, RIGHT,  The keys for the d-pad. Select one, press Space, then
  UP, DOWN      press the new key.
  A BUTTON,     The modifier key for each button: Shift, Control,
  B BUTTON      Option or Apple. Select one, press Space, then
                press the modifier key.

  With JOYSTICK:
  CALIBRATE     Center the stick, then press a key. Do this once for
                each joystick.
  SENSITIVITY   1 - 7. Higher numbers need less stick movement to
                register a direction.
  OFFSET        0 - 7. Leave at 0 on a real IIgs. On some emulators,
                if the joystick works on the TEST screen but not
                (or only in one direction) in the game, raise the
                SENSITIVITY and try 1 - 3 here.
  TEST          Shows the direction that the stick reads, for each
                axis. Press any key to stop.
  Joystick button 0 is the A button and button 1 is the B button.
  The keyboard keys keep working with a joystick.

  With SNES MAX:
  SLOT          1 - 7: the slot of the SNES MAX card. Player 1 uses
                its first controller and player 2 its second.

TURBO
  AUTOFIRE A,   OFF, 1, 2 or 4. While the button is held, it repeats:
  AUTOFIRE B    down for that many NES frames, then up for as many (at
                60 frames a second, 1 is 30 presses a second and 4 is
                7.5). Works with every input type.

DRIVERS
  KEYBOARD      BASIC sees one key at a time: the last key pressed.
                Holding Left and pressing Up turns to Up only.

GAME
  STAR ANIM     On (the default): the background stars twinkle, as
                on the NES. Off: the stars stay still, which saves
                redrawing them.

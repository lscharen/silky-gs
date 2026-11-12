DUCK HUNT FOR THE APPLE IIGS
============================

Duck Hunt (Nintendo, 1984) was played with the NES Zapper light gun:
shoot the ducks before they fly away, with the dog to laugh at you
when you miss. Game A has one duck at a time, Game B two, and Game C
clay pigeons. On the IIgs the mouse is the Zapper.

This version runs the original NES program on the Apple IIgs, on
Silky-GS, a runtime for porting NES games to the IIgs. This file
describes its keys and settings.

Settings are saved in duckhunt.prefs next to the application when you
quit with Q (see below), and are loaded the next time the game starts.


CONTROLLER (DEFAULT KEYS)
-------------------------

                Player 1
  D-pad         Arrow keys
  A button      Apple (Command)
  B button      Option
  Start         Return
  Select        Tab

The A and B buttons are modifier keys, so they can be held together
with any direction. The keys can be changed on the INPUT menu of the
configuration screen. Duck Hunt always uses the keyboard as the
controller.

Letter keys still work with Shift, Control or Caps Lock held, so a
direction key keeps working while a modifier is held as a button.
The exception is H, J, K and U with Control: the IIgs keyboard sends
the same codes as the arrow keys for those.


MOUSE (THE ZAPPER)
------------------

Move the mouse to aim and press the mouse button to shoot. As with the
Zapper, a shot hits when a target is under the pointer at the moment
the button goes down. The pointer is hidden on the title screen (the
game's sprite colors are all black there): use Select to choose the
game and Start to begin. The GAME menu (below) has settings that make
aiming harder.


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

INPUT
  TYPE          Always KEYBOARD in Duck Hunt: the mouse is the
                Zapper.

  With KEYBOARD:
  LEFT, RIGHT,  The keys for the d-pad. Select one, press Space, then
  UP, DOWN      press the new key.
  A BUTTON,     The modifier key for each button: Shift, Control,
  B BUTTON      Option or Apple. Select one, press Space, then
                press the modifier key.

TURBO
  AUTOFIRE A,   OFF, 1, 2 or 4. While the button is held, it repeats:
  AUTOFIRE B    down for that many NES frames, then up for as many (at
                60 frames a second, 1 is 30 presses a second and 4 is
                7.5). Works with every input type.

DRIVERS
  KEYBOARD      BASIC sees one key at a time: the last key pressed.
                Holding Left and pressing Up turns to Up only.

GAME
  CURSOR SIZE   LARGE (the default): a ring with a cross in the
                middle. SMALL: a single dot.
  JITTER        0 - 3. Moves each shot a little from the pointer, at
                random: up to 1, 3 or 7 pixels in each direction for
                1, 2 and 3, so a shot at the edge of a target can
                miss. 0 (the default) shoots exactly at the pointer.
  STROBE        0, 25, 50, 75 or 100: how much of each second the
                pointer is hidden while the mouse is still (75 shows
                it for a quarter of a second and hides it for three
                quarters). It always shows while the mouse moves.
                The default is 0.

# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's id_us_2.c (the control-panel card system) and
# ck_us_2.c (the Galaxy menus it #includes), by David Gow and the Omnispeak
# authors, GPL v2 or later. Names, order and arithmetic follow omnispeak
# upstream (A10).
class_name GalMenu
extends GalGame
## The control panel (SIM-G-01i): the stack of cards, their items and
## callbacks, the main menu, new game, load and save, configure (sound, music,
## options, keyboard), paddle war and the dialogs. GalUS's US_RunCards and
## US_DrawCards stand-ins are replaced here.

/* Reconstructed Commander Keen 1-3 Source Code
 * Copyright (C) 2021-2026 K1n9_Duk3
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef __BORLANDC__
#pragma inline	// ScrollTextWindow uses inline assembly
#endif
#include "KEENDEF.H"

/*
==============================================================================

                  PREVIEWS, ABOUT ID & TITLE SCREEN ROUTINES
	
==============================================================================
*/


/*
=====================
=
= Previews
=
=====================
*/

#if VERSION >= VER_100
void Previews(void)
{
#if (EPISODE == 1)

	DrawPicFile("PREVIEW2.CK1");
	FadeIn();
	WaitVBL(300);
	FadeOut();
	DrawPicFile("PREVIEW3.CK1");
	FadeIn();
#if VERSION > VER_110
	ReadLevel(TITLEMAP);	// reload menu backgrounds (DrawPicFile trashes the level data!)
#endif
	WaitVBL(300);
	ShowText(previewsPtr, 0, 22);
#if VERSION == VER_110
	ReadLevel(TITLEMAP);	// reload menu backgrounds (DrawPicFile trashes the level data!)
#endif

#else	// EPISODE != 1

	DrawTextScreen(previewsPtr, 0, 22);
	FadeIn();
	ShowText(previewsPtr, 0, 22);
	originx = X_HIGH;

#endif	// if EPISODE == 1 ... else ...
}
#endif	// if VERSION >= VER_100


/*
=====================
=
= ShowAboutId
=
=====================
*/

void ShowAboutId(void)
{
	ControlStruct ctrl;

	originx = X_ID;
	originy = Y_ID;
	RF_ForceRefresh();
	RF_Clear();
	DrawIdScreen();
	FadeIn();
	ClearKeys();

	do
	{
		RF_Clear();
		RF_Refresh();
		if (DoFkeys())
		{
			DrawIdScreen();
		}

		ctrl = ControlPlayer(1);
	} while (!ctrl.button1 && !ctrl.button2 && !NoBiosKey(1));

	K13_StaticScreen(0);
}


/*
=====================
=
= DrawTitlePics
=
=====================
*/

void DrawTitlePics(void)
{
	DrawPic(8, 1, TITLEPIC);
#if (EPISODE == 3)
	DrawPic(19, 182, F1HELPPIC);
#else
	DrawPic(16, 182, F1HELPPIC);
#endif
}


/*
=====================
=
= DrawTitleScreen
=
=====================
*/

void DrawTitleScreen(void)
{
	uservect = DrawTitlePics;
#if VERSION > VER_100
	RF_Clear();
#endif
	RF_Refresh();
	RF_Refresh();
	uservect = NULL;
	ClearKeys();
}


/*
=====================
=
= DrawAboutId
=
=====================
*/

void DrawAboutId(void)
{
#if VERSION <= VER_110

#if VERSION < VER_100
	DrawPic(18, 23, IDLOGOPIC);
#else
	DrawPic(17, 23, IDLOGOPIC);
#endif
	sx = leftedge = 7;
	sy = 9;
	PrintGrey("We are a group of Software Artists\n");
	PrintGrey("whose goal is to bring commercial\n");
	PrintGrey("quality software to the public\n");
	PrintGrey("at shareware prices.\n\n");
	PrintGrey("Our effort is only possible with\n");
	PrintGrey("your support. Without it, we cannot\n");
	PrintGrey("continue to make this fine\n");
	PrintGrey("software so affordable.\n\n");
	PrintGrey("Thank you in advance for your\n");
	PrintGrey("contribution to the future of the\n");
	PrintGrey("growing shareware market.");
	
#else
	
	char lines[11][40] =	// Note: making this 'static' would be more efficient!
	{
		"We are a group of Software Artists\n",
#if VERSION < VER_134
		"whose goal is to bring commercial\n",
		"quality software to the public\n",
		"at shareware prices.\n\n",
		"Our effort is only possible with\n",
		"your support. Without it, we cannot\n",
		"continue to make this fine\n",
		"software so affordable.\n\n",
		"Thank you in advance for your\n",
		"contribution to the future of the\n",
		"growing shareware market."
#else
		"whose goal is to bring high quality\n",
		"PC entertainment to the public at\n",
		"reasonable prices.\n\n",
		"Our effort is only possible with\n",
		"your support. Without it, we cannot\n",
		"continue to make this fine soft-\n",
		"ware so affordable.\n\n",
		"Thank you in advance for your pur-\n",
		"chase. We will continue to provide\n",
		"the PC market with great software."
#endif
	};
	Sint16 i;

	DrawPic(17, 23, IDLOGOPIC);
	sx = leftedge = 7;
	sy = 9;
	for (i = 0; i < 11; i++)
	{
		PrintGrey(lines[i]);
	}
	
#endif
}


/*
=====================
=
= DrawIdScreen
=
=====================
*/

void DrawIdScreen(void)
{
	uservect = DrawAboutId;
	RF_ForceRefresh();
	RF_Clear();
	RF_Refresh();
	RF_Refresh();
	uservect = NULL;
	ClearKeys();
}

/*
==============================================================================

                         HIGHSCORE SCREEN ROUTINES

==============================================================================
*/


/*
=====================
=
= DrawHighscores
=
=====================
*/

void DrawHighscores(void)
{
	Sint16 tx, ty, anim, i;
	char scorestr[12];

// Keen 3 doesn't show parts or cities saved, so names and scores are moved
// a bit further to the right to compensate for that:
#if (EPISODE == 3)
#define X 5
#else
#define X 0
#endif

	DrawPic(15,  7, HIGHSCORPIC);
	DrawPic( 9+X, 44, NAMEPIC);
	DrawPic(23+X, 44, SCOREPIC);
#if (EPISODE == 1)
	DrawPic(33, 44, PARTSPIC);
#elif (EPISODE == 2)
	DrawPic(33, 40, SAVEDPIC);
#endif

	for (i = 0; i < HIGHSCORE_NUMENTRIES; i++)
	{
		tx = originx / TILEGLOBAL;	// why is this done inside the loop?
		ty = originy / TILEGLOBAL;
		anim = i % 4;
		sy = i*2 + 8;

#if (EPISODE == 1)
		// icons for the collected ship parts are placed as animating tiles in the level:
		if (highscores.gotJoystick[i])
		{
			SETTILE(tx + 14, sy/2 + ty, 0, anim + 221);
		}
		if (highscores.gotBattery[i])
		{
			SETTILE(tx + 15, sy/2 + ty, 0, anim + 237);
		}
		if (highscores.gotVacuum[i])
		{
			SETTILE(tx + 16, sy/2 + ty, 0, anim + 241);
		}
		if (highscores.gotEverclear[i])
		{
			SETTILE(tx + 17, sy/2 + ty, 0, anim + 245);
		}
#elif (EPISODE == 2)
		// draw number of cities saved:
		sx = 36;
		itoa(highscores.citiesSaved[i], scorestr, 10);
		PrintGrey(scorestr);
#endif

		// draw score and name on top of everything:
		ltoa(highscores.scores[i], scorestr, 10);
		sx = 29+X - strlen(scorestr);
		PrintGrey(scorestr);
		sx = 9+X;
		PrintGrey(highscores.names[i]);
	}

#undef X
}


/*
=====================
=
= DrawScoreScreen
=
=====================
*/

void DrawScoreScreen(void)
{
	originx = X_HIGH;
	originy = Y_HIGH;
	RF_ForceRefresh();
	RF_Clear();
	uservect = DrawHighscores;
	RF_Refresh();
	RF_Refresh();
	uservect = NULL;
}


/*
=====================
=
= ShowScoreScreen
=
=====================
*/

void ShowScoreScreen(void)
{
	ControlStruct ctrl;

	K13_StaticScreen(1);
	DrawScoreScreen();
	FadeIn();
	ClearKeys();

	do
	{
		RF_Clear();
		RF_Refresh();
		if (DoFkeys())
		{
			DrawScoreScreen();
		}

		ctrl = ControlPlayer(1);
	} while (!ctrl.button1 && !ctrl.button2 && !NoBiosKey(1));
}

/*
==============================================================================

                           SAVE & RESTORE ROUTINES

==============================================================================
*/


/*
=====================
=
= SaveMenu
=
=====================
*/

void SaveMenu(void)
{
#ifdef K13_PORT
	/* Keen Launcher: the digits-only prompt is now a cursor list, so a pad
	   (or touch arrows) can pick a slot; pressing 1-9 still works through
	   the hotkeys, and the files stay byte-identical SAVED1-9. */
	Sint16 pick = 0;
	char filename[13];

	if (!canSave)
	{
		ExpWin(22, 3);
		Print("You can SAVE the game\n");
		Print("ONLY on the World Map!\n");
		Print("    press a key:");
		ClearKeys();
		Ack();
		return;
	}

	for (;;)
	{
		char labels[9][20];
		const char *items[9];
		Sint16 i;

		for (i = 0; i < 9; i++)
		{
			sprintf(filename, "SAVED%d.%s", i + 1, _extension);
			sprintf(labels[i], "Game %d  %s", i + 1,
			        access(filename, 0) == 0 ? "SAVED" : "-");
			items[i] = labels[i];
		}
		pick = (Sint16)K13_PickMenu("Save which position?", items,
		                            "123456789", 9, pick);
		if (pick < 0)
			return;
		sprintf(filename, "SAVED%d.%s", pick + 1, _extension);
		if (access(filename, 0) != 0 || K13_Confirm("Overwrite it?"))
			break;
	}
#else
	Sint16 save = 0;
	char c;
	char filename[13] = "SAVED?.";

	strcat(filename, _extension);
	if (!canSave)
	{
		ExpWin(22, 3);
		Print("You can SAVE the game\n");
		Print("ONLY on the World Map!\n");
		Print("    press a key:");
		ClearKeys();
		Ack();
		return;
	}

	do
	{
		ExpWin(20, 3);
		Print("Which game position\n");
		Print("do you want to save?\n");
		Print("    1-9 or ESC:");
		do
		{
			c = Get() & 0xFF;
		} while (c != CHAR_ESCAPE && !(c >= '1' && c <= '9'));

		if (c == CHAR_ESCAPE)
		{
			return;
		}

		filename[5] = c;
		if (access(filename, 0) == 0)
		{
			ExpWin(20, 3);
			Print("That game position\n");
			Print("already exists!\n");
			Print("Overwrite it?:");
			do
			{
				c = toupper(Get() & 0xFF);
			} while(c != CHAR_ESCAPE && c != 'Y' && c != 'N');

			if (c == CHAR_ESCAPE)
			{
				return;
			}

			if (c == 'Y')
			{
				save++;
			}
		}
		else
		{
			save++;
		}
	} while (save == 0);
#endif

	// prepare gamestate and save it:
	gamestate.worldoriginx = worldCamX;
	gamestate.worldoriginy = worldCamY;
	gamestate.worldx = worldkeenx;
	gamestate.worldy = worldkeeny;
	SaveFile(filename, MK_FP(FP_SEG(&gamestate), FP_OFF(&gamestate)), sizeof(gamestate));

#if VERSION >= VER_100
	ExpWin(29, 3);
	Print("You can continue this game\n");
	Print("from the Main Menu next time\n");
	Print("you play. Press a key:");
	Get();
#endif
}


/*
=====================
=
= RestoreMenu
=
=====================
*/

boolean RestoreMenu(void)
{
#if VERSION < VER_100
#define WINW 20
#else
#define WINW 25
#endif
	char c;
	Sint32 size;
	char filename[13] = "SAVED?.";
#ifdef K13_PORT
	Sint16 pick = 0;
#endif

	DrawChar(sx, sy*8, ' ');	// erase cursor from Main Menu

	do
	{
#ifdef K13_PORT
		/* cursor list instead of digits-only, same as SaveMenu */
		{
			char labels[9][20];
			const char *items[9];
			Sint16 i;

			for (i = 0; i < 9; i++)
			{
				sprintf(filename, "SAVED%d.%s", i + 1, _extension);
				sprintf(labels[i], "Game %d  %s", i + 1,
				        access(filename, 0) == 0 ? "SAVED" : "-");
				items[i] = labels[i];
			}
			pick = (Sint16)K13_PickMenu("Continue which game?", items,
			                            "123456789", 9, pick);
			if (pick < 0)
				return false;
			sprintf(filename, "SAVED%d.%s", pick + 1, _extension);
			size = Verify(filename);
		}
		{
#else
		ExpWin(WINW, 2);
		oldx = sx;	// not sure why these are here...
		oldy = sy;
#if VERSION < VER_100
		Print("Continue Which Game?\n");
		Print("     1-9 or ESC:");
#else
		Print("  Continue Which Game?\n");
		Print("       1-9 or ESC:");
#endif
		do
		{
			c = Get() & 0xFF;
		} while (!(c >= '1' && c <= '9') && c != CHAR_ESCAPE);

		if (c == CHAR_ESCAPE)
		{
			return false;
		}
		else
		{
			filename[5] = c;
			strcat(filename, _extension);
			size = Verify(filename);
#endif

			if (!size)
			{
				ExpWin(WINW, 2);
#if VERSION < VER_100
				Print("That game hasn't\n");
				Print("been saved yet!:");
#else
				Print("  That game hasn't\n");
				Print("  been saved yet!:");
#endif
				Get();
			}
			else if (size == sizeof(gamestate))
			{
				LoadFile(filename, (void *)&gamestate);
				restoredGame = true;
				return true;
			}
			else
			{
				ExpWin(WINW, 2);
				// The following text didn't fit into the old window size used in
				// the beta version, that's why the window width had to be increased
				// for version 1.0 and some leading spaces had to be added in the
				// other strings above.
				Print("That file is incompatible\n");
				Print("with this verion of CK:");
				Get();
			}
		}

	} while (true);
}

/*
==============================================================================

                        HELP TEXT & STORY TEXT ROUTINES

==============================================================================
*/


/*
=====================
=
= ShowStoryText
=
=====================
*/

void ShowStoryText(void)
{
	FadeOut();
	originx = X_STORY;
	originy = Y_STORY;
	RF_ForceRefresh();
	RF_Refresh();
	FadeIn();
#if VERSION < VER_100
	PlayAnimation(storyanim);
	ShowText(storytxtPtr, 1, 20);
#else
	ShowText(storytxtPtr, 0, 16);
#endif
	FadeOut();
}


/*
=====================
=
= ShowHelpText
=
=====================
*/

/*
=====================
=
= OptionsMenu  (Keen Launcher port)
=
= Native-style settings screen: same window chrome, font and navigation
= as the original menus. Settings persist to KEENLNCH.CFG.
=
=====================
*/

/*
=====================
=
= K13_Confirm  (Keen Launcher port)
=
= A yes/no prompt in the game's own idiom, used to guard quicksave and
= quickload.  Worth guarding: with the actions on a controller it is easy to
= knock one by accident and save -- or worse, load -- at a terrible moment.
=
= Accepts Enter and Escape as well as Y and N, because a pad cannot send a
= letter: k13_pad_menu_edges turns its buttons into Enter and Escape.
=
=====================
*/

boolean K13_Confirm(char *question)
{
	Sint16 key, scan;
	char answer;

	ClearKeys();
	ExpWin((Sint16)(strlen(question) + 8), 1);
	Print(question);
	Print(" (Y/N)");
	for (;;)
	{
		key = Get();
		scan = (key >> 8) & 0xFF;
		answer = (char)toupper(key & 0xFF);
		if (answer == 'Y' || scan == 0x1C)	/* Y or Enter / pad confirm */
			return true;
		if (answer == 'N' || scan == 0x01)	/* N or Esc / pad cancel */
			return false;
	}
}


/*
=====================
=
= K13_PickMenu  (Keen Launcher port)
=
= The port's answer to every "press 1-9" / "press Y or D or T" prompt: the
= same choices as a cursor-driven list in the game's own window chrome, so
= a pad (or a touch tap through the overlay's arrows) can answer anything.
= The original single-key answers stay wired up through `hotkeys`.
=
=====================
*/

int K13_PickMenu(const char *title, const char *const *items,
                 const char *hotkeys, int nitems, int pos)
{
	Sint16 basex, basey, i, key, scan, w, l;
	char ch;

	w = (Sint16)strlen(title);
	for (i = 0; i < nitems; i++)
	{
		l = (Sint16)(strlen(items[i]) + 3);
		if (l > w)
			w = l;
	}
	ClearKeys();
	ExpWin((Sint16)(w + 1), (Sint16)(nitems + 2));
	basex = sx;
	basey = sy;
	Print((char *)title);
	for (i = 0; i < nitems; i++)
	{
		sx = (Sint16)(basex + 3);
		sy = (Sint16)(basey + 2 + i);
		Print((char *)items[i]);
	}
	if (pos < 0 || pos >= nitems)
		pos = 0;
	for (;;)
	{
		/* the blinking caret from Get() is the cursor, id-style */
		sx = (Sint16)(basex + 1);
		sy = (Sint16)(basey + 2 + pos);
		key = Get();
		scan = (key >> 8) & 0xFF;
		ch = (char)toupper(key & 0xFF);

		if (scan == 0x48)	/* up */
			pos = (pos == 0) ? (Sint16)(nitems - 1) : (Sint16)(pos - 1);
		else if (scan == 0x50)	/* down */
			pos = (pos == nitems - 1) ? 0 : (Sint16)(pos + 1);
		else if (ch == CHAR_ESCAPE)
			return -1;
		else if (ch == CHAR_ENTER || ch == ' ')
			return pos;
		else if (hotkeys)
			for (i = 0; i < nitems; i++)
				if (hotkeys[i] && hotkeys[i] != ' ' && ch == hotkeys[i])
					return i;
	}
}


/*
=====================
=
= ControlsMenu  (Keen Launcher port)
=
= Rebinding for the keyboard fire control and the four pad actions, drawn
= in the style of the game's own "Keyboard Commands" screen.  The eight
= direction keys and button1/button2 keep that original screen (F3), which
= the first row opens so players can actually find it.
=
=====================
*/

/* Controls, two pages: every keyboard key and every pad action the engine
   has, all rebindable and clearable.  `animate` runs the ExpWin expand only on
   first entry; page flips and returns redraw instantly (id's own menus never
   re-animate).  Movement and the jump/pogo keys stay on id's original
   keyboard screen, reached from row 0, so that screen keeps doing exactly
   what it always did.  Quit/Esc and the config screens are deliberately NOT
   clearable to nothing from here -- Esc always cancels prompts -- so a wild
   config can never lock the menus. */
static void ControlsMenuDraw(int page, int animate);

void ControlsMenu(void)
{
	/* land on the page for the controls in the player's hands: pad
	   plugged in -> the gamepad page, else the keyboard page */
	ControlsMenuDraw(K13_PadAttached() ? 1 : 0, 1);
}

/* countdown digit for the bind prompts, drawn where the caller parked it */
static Sint16 k13_bw_x, k13_bw_y;
static void BindTickDraw(int secs_left)
{
	if (secs_left < 0 || secs_left > 9)
		return;
	DrawChar(k13_bw_x, (Sint16)(k13_bw_y * 8), (char)('0' + secs_left));
}

#define CTL_KEYSCR 0	/* opens the original keyboard screen */
#define CTL_KEY    1	/* keyboard bind, code = K13_KEY_*  */
#define CTL_PAD    2	/* pad bind, code = K13_BIND_*      */
#define CTL_PAGE   3	/* flip to the other page           */
#define CTL_RESET  4

typedef struct
{
	char *label;
	Sint16 kind;
	Sint16 code;
} K13_CtlItem;

static const K13_CtlItem k13_ctl_keys[] = {
	{"  Move keys+buttons..", CTL_KEYSCR, 0},
	{"  Fire",           CTL_KEY, K13_KEY_FIRE},
	{"  Status",         CTL_KEY, K13_KEY_STATUS},
	{"  Quicksave",      CTL_KEY, K13_KEY_QSAVE},
	{"  Quickload",      CTL_KEY, K13_KEY_QLOAD},
	{"  Help",           CTL_KEY, K13_KEY_HELP},
	{"  Sound on/off",   CTL_KEY, K13_KEY_SOUND},
	{"  Keybd conf",     CTL_KEY, K13_KEY_KEYCONF},
	{"  Joy conf",       CTL_KEY, K13_KEY_JOYCONF},
	{"  Save Menu",      CTL_KEY, K13_KEY_SAVEMENU},
	{"  Quit proMpt",    CTL_KEY, K13_KEY_QUIT},
	{"  Score box",      CTL_KEY, K13_KEY_SCOREBOX},
	{"  Gamepad page..", CTL_PAGE, 0},
	{"  Reset to defaults", CTL_RESET, 0}
};

static const K13_CtlItem k13_ctl_pads[] = {
	{"  JuMp",           CTL_PAD, K13_BIND_JUMP},
	{"  Pogo",           CTL_PAD, K13_BIND_POGO},
	{"  Fire",           CTL_PAD, K13_BIND_FIRE},
	{"  Status",         CTL_PAD, K13_BIND_STATUS},
	{"  Quicksave",      CTL_PAD, K13_BIND_QSAVE},
	{"  Quickload",      CTL_PAD, K13_BIND_QLOAD},
	{"  Help",           CTL_PAD, K13_BIND_HELP},
	{"  Sound on/off",   CTL_PAD, K13_BIND_SOUND},
	{"  Save Menu",      CTL_PAD, K13_BIND_SAVEMENU},
	{"  Quit proMpt",    CTL_PAD, K13_BIND_QUIT},
	{"  Score box",      CTL_PAD, K13_BIND_SCOREBOX},
	{"  Keyboard page..", CTL_PAGE, 0},
	{"  Reset to defaults", CTL_RESET, 0}
};

static void ControlsMenuDraw(int page, int animate)
{
	const K13_CtlItem *items = page ? k13_ctl_pads : k13_ctl_keys;
	Sint16 nitems = (Sint16)(page ? (sizeof(k13_ctl_pads) / sizeof(k13_ctl_pads[0]))
	                              : (sizeof(k13_ctl_keys) / sizeof(k13_ctl_keys[0])));
	Sint16 pos = 0, key, scan;
	Sint16 done = 0;
	Sint16 basex, basey, i;

	if (animate)
		ExpWin(29, 18);
	else
		CenterWindow(29, 18);
	basex = sx;
	basey = sy;
	Print(page ? "    CONTROLS 2/2: GAMEPAD" : "    CONTROLS 1/2: KEYBOARD");

	for (i = 0; i < nitems; i++)
	{
		sx = basex;
		sy = (Sint16)(basey + 2 + i);
		Print(items[i].label);
	}

	do
	{
		/* value column, repainted in place.  Pad rows show both bindings --
		   a face button plus a shoulder or trigger alternate. */
		for (i = 0; i < nitems; i++)
		{
			if (items[i].kind != CTL_KEY && items[i].kind != CTL_PAD)
				continue;
			sx = (Sint16)(basex + 14);
			sy = (Sint16)(basey + 2 + i);
			Print("               ");
			sx = (Sint16)(basex + 14);
			sy = (Sint16)(basey + 2 + i);
			if (items[i].kind == CTL_KEY)
			{
				if (K13_GetKeyBind(items[i].code) == 0)
					Print("---");
				else
					printscan(K13_GetKeyBind(items[i].code));
			}
			else
			{
				if (K13_GetBind(items[i].code, 0) < 0 &&
				    K13_GetBind(items[i].code, 1) < 0)
				{
					Print("---");
				}
				else
				{
					Print(K13_PadBindName(K13_GetBind(items[i].code, 0)));
					if (K13_GetBind(items[i].code, 1) >= 0)
					{
						Print("+");
						Print(K13_PadBindName(K13_GetBind(items[i].code, 1)));
					}
				}
			}
		}

		/* selection cursor = Get()'s own blinking caret, as id's menus do */
		sx = (Sint16)(basex + 1);
		sy = (Sint16)(basey + 2 + pos);
		key = Get();
		scan = (key >> 8) & 0xFF;

		if (scan == 0x48)	/* up */
		{
			pos = (pos == 0) ? (Sint16)(nitems - 1) : (Sint16)(pos - 1);
		}
		else if (scan == 0x50)	/* down */
		{
			pos = (pos == nitems - 1) ? 0 : (Sint16)(pos + 1);
		}
		else if (scan == 0x4B || scan == 0x4D)	/* left/right flip pages */
		{
			ControlsMenuDraw(!page, 0);
			return;
		}
		else if ((key & 0xFF) == CHAR_ESCAPE)
		{
			done = 1;
		}
		else if ((key & 0xFF) == CHAR_ENTER || (key & 0xFF) == ' ')
		{
			if (items[pos].kind == CTL_KEYSCR)
			{
				CalibrateKeys();	/* the original screen, over ours */
				K13_ConfigSave();
				ControlsMenuDraw(page, 0);
				return;
			}
			else if (items[pos].kind == CTL_PAGE)
			{
				ControlsMenuDraw(!page, 0);
				return;
			}
			else if (items[pos].kind == CTL_RESET)
			{
				if (K13_Confirm("Reset controls?"))
					K13_ResetBinds();
				ControlsMenuDraw(page, 0);
				return;
			}
			else if (items[pos].kind == CTL_KEY ||
			         items[pos].kind == CTL_PAD)
			{
				/* Every row opens the same tiny action menu, so REBIND,
				   ADD and CLEAR are all visible choices a pad can make --
				   no more hidden Del-to-clear or un-cancellable prompts. */
				static const char *keyacts[3] = {"Rebind", "Clear", "Back"};
				static const char *padacts[4] =
					{"Rebind", "Add 2nd bind", "Clear", "Back"};
				int ispad = (items[pos].kind == CTL_PAD);
				int act, clear = 0;
				Sint16 code;

				act = K13_PickMenu(items[pos].label + 2,
				                   ispad ? padacts : keyacts,
				                   ispad ? "RAC " : "RC ",
				                   ispad ? 4 : 3, 0);
				if (!ispad && act == 1)
					act = 2;	/* keyboard has no alternate slot */
				if (act == 2)
					clear = 1;
				else if (act == 0 || act == 1)
				{
					/* capture in a prompt that cancels ITSELF: with the
					   pad translation paused so any button is bindable,
					   the countdown is the pad's way out */
					ExpWin(25, 1);
					if (ispad)
						Print("Pad button? cancel in ");
					else
						Print("New key?    cancel in ");
					k13_bw_x = sx;
					k13_bw_y = sy;
					if (ispad)
						code = (Sint16)K13_PadBindWait(7000, BindTickDraw);
					else
						code = (Sint16)K13_KeyBindWait(7000, BindTickDraw);
					ClearKeys();
					if (code == -2)
					{
						ExpWin(17, 1);
						Print("No pad connected.");
						Get();
					}
					else if (code == -3)
						clear = 1;	/* Backspace/Del still clears */
					else if (code >= 0 && ispad)
					{
						if (act == 0)
						{
							/* Rebind = this button and ONLY this button;
							   Add keeps the old primary as the alternate */
							K13_SetBind(items[pos].code, 0, -1);
							K13_SetBind(items[pos].code, 1, -1);
						}
						K13_BindPad(items[pos].code, code);
					}
					else if (code > 0 && !ispad)
						K13_BindKey(items[pos].code, code);
				}
				if (clear)
				{
					if (ispad)
					{
						K13_SetBind(items[pos].code, 0, -1);
						K13_SetBind(items[pos].code, 1, -1);
					}
					else
					{
						/* Esc must always answer prompts, so clearing the
						   quit key falls back to Esc instead of nothing */
						K13_SetKeyBind(items[pos].code,
						    items[pos].code == K13_KEY_QUIT ? 0x01 : 0);
					}
				}
				K13_ConfigSave();
				ControlsMenuDraw(page, 0);
				return;
			}
		}
	} while (!done);

	K13_ConfigSave();
}


/* why the Galaxy rows read N/A, instead of a mute shrug */
static void GalaxyHint(void)
{
	ExpWin(25, 3);
	Print("Borrows Keen 4 + 5\n");
#ifdef __ANDROID__
	Print("sounds. Play those two\n");
	Print("once to turn this on!");
#else
	Print("sounds. Install those\n");
	Print("two to turn this on!");
#endif
	ClearKeys();
	Get();
}

static void OptionsMenuDraw(int animate);

void OptionsMenu(void)
{
	OptionsMenuDraw(1);
}

static void OptionsMenuDraw(int animate)
{
#define OPT_ITEMS 12
	Sint16 pos = 0, i, key, scan;
	Sint16 done = 0;
	Sint16 basex, basey;
	static const Sint16 widths[4] = {0, 360, 396, 426};

	/* draw the window ONCE; only cursor + values update below (the
	   original menus never re-run the ExpWin expand animation) */
	if (animate)
		ExpWin(26, 16);
	else
	{
		/* Back-navigation from a BIGGER window (Controls is 33x18): repaint
		   the underlying screen first, or the old window's border sticks out
		   around this smaller one -- the "overlapping windows" bug.  Must
		   FORCE the refresh: the adaptive tile pass skips tiles it believes
		   unchanged, leaving slivers of the old window.  In-game (the pause
		   menu path) the level view is the underlay, not the main menu. */
		RF_ForceRefresh();
		if (level == TITLEMAP)
			DrawMainMenuScreen();
		CenterWindow(26, 16);
	}
	basex = sx;
	basey = sy;
	Print("       OPTIONS");
	sx = basex; sy = basey + 2; Print("   View size");
	sx = basex; sy = basey + 3; Print("   SMooth Motion");
	sx = basex; sy = basey + 4; Print("   Fire button");
	sx = basex; sy = basey + 5; Print("   Controls...");
	sx = basex; sy = basey + 6; Print("   Confirm quicksv");
	sx = basex; sy = basey + 7; Print("   Fullscreen");
	sx = basex; sy = basey + 8; Print("   Score box");
	sx = basex; sy = basey + 9; Print("   Sounds");
	sx = basex; sy = basey + 10; Print("   Galaxy sfx");
	sx = basex; sy = basey + 11; Print("   Galaxy tunes");
	sx = basex; sy = basey + 12; Print("   Quit game");
	sx = basex; sy = basey + 13; Print("   Exit");

	do
	{
		Sint16 w = K13_GetWideWidth();

		/* refresh the value column in place (no window redraw); it starts
		   clear of the longest label so nothing gets clipped */
		for (i = 2; i <= 11; i++)
		{
			sx = basex + 19; sy = basey + i; Print("      ");
		}
		sx = basex + 19; sy = basey + 2;
		if (w == 0)
			Print("4:3");
		else if (w == 426)
			Print("16:9");
		else
			PrintInt(w);
		sx = basex + 19; sy = basey + 3; Print(K13_GetSmooth() ? "ON" : "OFF");
		sx = basex + 19; sy = basey + 4;
		Print(K13_GetOneFire() ? "1-KEY" : "2-KEY");
		sx = basex + 19; sy = basey + 6;
		Print(K13_GetQSConfirm() ? "ON" : "OFF");
		sx = basex + 19; sy = basey + 7;
		Print(K13_IsFullscreen() ? "ON" : "OFF");
		sx = basex + 19; sy = basey + 8;
		Print(K13_GetScoreBox() ? "ON" : "OFF");
		sx = basex + 19; sy = basey + 9;
		Print(soundmode ? "ON" : "OFF");
		sx = basex + 19; sy = basey + 10;
		if (!K13_GalaxyAvail())
			Print("N/A");
		else
			Print(K13_GetGalaxySfx() ? "ON" : "OFF");
		sx = basex + 19; sy = basey + 11;
		if (!K13_GalaxyMusAvail())
			Print("N/A");
		else
			Print(K13_GetGalaxyMus() ? "ON" : "OFF");

		/* park the cursor on the selected row and let Get() animate it --
		   that blinking caret IS the selection cursor in id's own menus,
		   and Get() erases it on the way out, so nothing is left behind */
		sx = basex + 1;
		sy = basey + 2 + pos;
		key = Get();
		scan = (key >> 8) & 0xFF;

		if (scan == 0x48)	/* up */
		{
			pos = (pos == 0) ? OPT_ITEMS - 1 : pos - 1;
		}
		else if (scan == 0x50)	/* down */
		{
			pos = (pos == OPT_ITEMS - 1) ? 0 : pos + 1;
		}
		else if ((key & 0xFF) == CHAR_ESCAPE)
		{
			done = 1;
		}
		else if ((key & 0xFF) == CHAR_ENTER || (key & 0xFF) == ' ' ||
		         scan == 0x4B || scan == 0x4D)	/* select / left / right */
		{
			switch (pos)
			{
			case 0:	/* view size: cycle widths */
				for (i = 0; i < 4; i++)
					if (widths[i] == w)
						break;
				if (scan == 0x4B)	/* left = previous */
					i = (i <= 0 || i >= 4) ? 3 : i - 1;
				else
					i = (i >= 3) ? 0 : i + 1;
				K13_SetWideWidth(widths[i]);
				break;
			case 1:
				K13_SetSmooth(!K13_GetSmooth());
				break;
			case 2:
				K13_SetOneFire(!K13_GetOneFire());
				break;
			case 3:	/* Controls: rebinding screen, then redraw ours */
				ControlsMenu();
				OptionsMenuDraw(0);	/* no second open animation */
				return;
			case 4:
				K13_SetQSConfirm(!K13_GetQSConfirm());
				break;
			case 5:
				K13_ToggleFullscreen();
				/* remember it, so the next launch matches what you left */
				K13_SetFullscreen(K13_IsFullscreen());
				break;
			case 6:	/* persistent HUD, 4-6 style; also bindable in-game */
				K13_SetScoreBox(!K13_GetScoreBox());
				break;
			case 7:	/* master sound toggle (the F2 prompt, pad-friendly) */
				soundmode = soundmode ? off : spkr;
				break;
			case 8:	/* Keen 4-6 AdLib sound effects (needs sfx46/) */
				if (K13_GalaxyAvail())
					K13_SetGalaxySfx(!K13_GetGalaxySfx());
				else
				{
					GalaxyHint();
					OptionsMenuDraw(0);
					return;
				}
				break;
			case 9:	/* Keen 4-6 music (needs sfx46/*.imf) */
				if (K13_GalaxyMusAvail())
					K13_SetGalaxyMus(!K13_GetGalaxyMus());
				else
				{
					GalaxyHint();
					OptionsMenuDraw(0);
					return;
				}
				break;
			case 10: /* quit the game outright (pad/touch friendly: the
				   confirm answers to Enter/Esc, no typed letters) */
				if (K13_Confirm("Quit the game?"))
					Quit("");
				OptionsMenuDraw(0);	/* repaint after the prompt */
				return;
			case 11:
				done = 1;
				break;
			}
		}
	} while (!done);

	K13_ConfigSave();
#undef OPT_ITEMS
}


void ShowHelpText(void)
{
	Sint32 x, y;

	x = originx;
	y = originy;
	// normalize screen position for ShowText:
	TILE_ALIGN(originx);
	TILE_ALIGN(originy);
	ShowText(helptextPtr, 1, 20);
	originx = x;
	originy = y;
}


/*
=====================
=
= DrawTextEx
=
=====================
*/

void DrawTextEx(boolean useGrey, Sint16 x, Sint16 y, char *text)
{
	Sint16 oldsx, oldsy;

	// save cursor position:
	oldsx = sx;
	oldsy = sy;

	// move cursor to desited location:
	sx = x;
	sy = y;

	// draw text in the desired style:
	if (useGrey)
	{
		PrintGrey(text);
	}
	else
	{
		Print(text);
	}

	// restore old cursor position:
	sx = oldsx;
	sy = oldsy;
}


/*
=====================
=
= DrawTextWindow
=
=====================
*/

void DrawTextWindow(void)
{
	Sint16 x;

	DrawWindow(4, textWindowMinY, 43, textWindowMaxY);

	// add a sub-section at the bottom of that window:
	DrawChar(4, (textWindowMaxY+1)*8, 4);
	DrawChar(43, (textWindowMaxY+1)*8, 4);
	DrawChar(4, (textWindowMaxY+2)*8, 1);
	DrawChar(43, (textWindowMaxY+2)*8, 3);
	for (x = 5; x < 43; x++)
	{
		DrawChar(x, (textWindowMaxY+2)*8, 2);
	}
	DrawTextEx(true, 5, textWindowMaxY+1, "       ESC to Exit / \x0F \x13 to Read      ");

	// draw the visible portion of the text inside the window:
	DrawTextLines(textWindowX, textWindowMinY+1, textdataPtr, textLineOffsets, textVisibleLines);
}


/*
=====================
=
= DrawTextScreen
=
=====================
*/

#if (VERSION >= VER_120)
void DrawTextScreen(char huge *textPtr, Sint16 minY, Sint16 maxY)
{
	Sint16 lines, height;

	height = maxY - minY - 1;
	lines = GetLineOffsets(textPtr, line_offsets, 38, MAXTEXTLINES);
	textWindowX = 5;
	textWindowMinY = minY;
	textdataPtr = textPtr;
	textLineOffsets = line_offsets;
	textVisibleLines = height;
	textWindowMaxY = maxY;

	uservect = DrawTextWindow;
	RF_Refresh();
	RF_Refresh();
	uservect = NULL;
}
#endif


/*
=====================
=
= ShowText
=
=====================
*/

void ShowText(char huge *textPtr, Sint16 minY, Sint16 maxY)
{
	ControlStruct ctrl;
	Sint16 lines, line, height;

	height = maxY - minY - 1;
	lines = GetLineOffsets(textPtr, line_offsets, 38, MAXTEXTLINES);
	textWindowX = 5;
	textWindowMinY = minY;
	textdataPtr = textPtr;
	textLineOffsets = line_offsets;
	textVisibleLines = height;
	textWindowMaxY = maxY;

	uservect = DrawTextWindow;
	RF_Refresh();
	RF_Refresh();
	uservect = NULL;

	line = 0;
	WaitVBL(8);

	do
	{
		ctrl = ControlPlayer(1);

		if (keydown[KEY_UP] || ctrl.dir == north)
		{
			if (line > 0)
			{
				line--;
				ScrollTextWindow(minY+1, maxY-1, 1);
				DrawTextLines(5, minY+1, textPtr, line_offsets+line, 1);
#if VERSION > VER_120
				WaitVBL(2);	// avoid scrolling too fast
#endif
			}
		}
		else if (keydown[KEY_DOWN] || ctrl.dir == south)
		{
			if (lines - height >= line && 200-height >= line)
			{
				line++;
				ScrollTextWindow(minY+1, maxY-1, 0);
				DrawTextLines(5, maxY-1, textPtr, line_offsets+line+height-1, 1);
#if VERSION > VER_120
				WaitVBL(2);	// avoid scrolling too fast
#endif
			}
		}

		if (keydown[KEY_PGUP])
		{
			if (line - height + 1 > 0)
			{
				line -= height - 1;
			}
			else
			{
				line = 0;
			}

			DrawTextLines(5, minY+1, textPtr, line_offsets+line, height);

			// wait until key is no longer pressed:
#ifdef K13_PORT
			while (keydown[KEY_PGUP]) K13_Idle();
#else
			while (keydown[KEY_PGUP]);	
#endif
		}
		if (keydown[KEY_PGDN])
		{
			if (line + height*2 < lines)
			{
				line += height - 1;
			}
			else
			{
				line = lines - height + 1;
			}

			DrawTextLines(5, minY+1, textPtr, line_offsets+line, height);

			// wait until key is no longer pressed:
#ifdef K13_PORT
			while (keydown[KEY_PGDN]) K13_Idle();
#else
			while (keydown[KEY_PGDN]);
#endif
		}
	} while (!keydown[KEY_ESCAPE] && !ctrl.button1 && !ctrl.button2);

	// wait until the buttons are no longer pressed:
	do
	{
		ctrl = ControlPlayer(1);
	} while (ctrl.button1 || ctrl.button2);
	ClearKeys();
}

/*
==============================================================================

                           APOGEE INTRO ROUTINES

==============================================================================
*/

// the code is re-using a text window variable for the Apogee intro:
#define apogeeY textWindowX
#if VERSION < VER_100
#define APOGEE_END_Y 75
#define APOGEE_START_DELAY 20
#else
#define APOGEE_END_Y 55
#define APOGEE_START_DELAY 30
#endif


/*
=====================
=
= DrawApogeePic
=
=====================
*/

void DrawApogeePic(void)
{
	DrawPic(16, apogeeY, APOGEEPIC);
}


/*
=====================
=
= DrawIntroPics
=
=====================
*/

void DrawIntroPics(void)
{
#if VERSION < VER_100
	// "an APOGEE presentation":
	DrawPic(22, 50, ANPIC);
	DrawPic(18, 130, PRESENTPIC);
	DrawPic(16, apogeeY,    APOGEEPIC);
#else
	// "an APOGEE presentation":
	DrawPic(22, apogeeY-10, ANPIC);
	DrawPic(16, apogeeY,    APOGEEPIC);
	DrawPic(18, apogeeY+32, PRESENTPIC);

	// "of an ID SOFTWARE production":
	DrawPic(21,  99, OFANPIC);
	DrawPic(19, 114, IDSOFTPIC);
	DrawPic(19, 159, PRODUCTPIC);
#endif
}


/*
=====================
=
= ShowApogeeIntro
=
=====================
*/

void ShowApogeeIntro(void)
{
	Sint16 state, y;
	ControlStruct ctrl;
	Sint16 towait;
	Sint16 n;

	originx = X_APOGEE;
	originy = Y_APOGEE;
#if VERSION < VER_100
	towait= 200;
#else
	towait= 300;
#endif
	y = 200;
	state = 0;
	n = 0;

	RF_ForceRefresh();
	ClearKeys();
#if VERSION >= VER_100
	forcemenu = false;
#endif

	while (towait--)
	{
		RF_Clear();
		apogeeY = y;
		RF_Refresh();

		switch (state)
		{
		case 0:
			if (++n > APOGEE_START_DELAY)
			{
				n = 0;
				state++;
				uservect = DrawApogeePic;
			}
			break;

		case 1:
			if (y > APOGEE_END_Y)
			{
				y--;
			}
			else
			{
				state++;
				uservect = DrawIntroPics;
			}
		}

		ctrl = ControlPlayer(1);
		if (ctrl.button1 || ctrl.button2 || NoBiosKey(1))
		{
			towait = 0;
#if VERSION >= VER_100
			forcemenu = true;
#endif
		}
	}

	uservect = NULL;
}

/*
==============================================================================

                        ORDERING INFORMATION ROUTINES

==============================================================================
*/

#if VERSION < VER_134

/*
=====================
=
= ShowOrderingScreen
=
=====================
*/

void ShowOrderingScreen(boolean timed)
{
#if (EPISODE == 1) //---------------------------------------------------------

#if VERSION < VER_100
#define SWAPDELAY 1000
#else
#define SWAPDELAY 500
#endif

	register Sint16 frame, spr;
	ControlStruct ctrl;
	Sint16 sprites[2] = {YORPSTAND1SPR, GARGSTAND1SPR};
#if VERSION <= VER_120
	Sint32 screenys[2] = {159*PIXGLOBAL, 151*PIXGLOBAL};
#else
	Sint32 screenys[2] = {151*PIXGLOBAL, 143*PIXGLOBAL};
#endif
	Sint32 screenxs[2] = {144*PIXGLOBAL, 141*PIXGLOBAL};
	Sint16 n, towait, counter;

	frame = 0;
	n = 0;
	spr = 0;
	counter = 0;

	DrawOrderingScreen();
	FadeIn();
	ClearKeys();
	towait = SCREENTIME;

	do
	{
		ctrl = ControlPlayer(1);
		RF_Clear();

		// update sprite animation:
		if (counter % 6 == 0)
		{
			if ((frame = frame + Rnd(3) - 2) > 7 || frame < 0)
			//if (frame > 7 || frame < 0)
			{
				frame = Rnd(7*7) / 7;
			}
		}
		// change alien (Yorp/Garg) every 1000/500 refreshs:
		if (++n > SWAPDELAY)
		{
			spr ^= 1;
			n = 0;
		}
		RF_PlaceSprite(screenxs[spr] + originx, screenys[spr] + originy, sprites[spr] + frame);

		RF_Refresh();
		counter++;

		if (timed)
		{
			towait = towait - tics;
		}

		if (DoFkeys())
		{
			ClearKeys();
			DrawOrderingScreen();
		}

		if (ctrl.button1 || ctrl.button2 || NoBiosKey(1))
		{
			towait = 0;
		}

	} while (towait > 0);

#undef SWAPDELAY

#elif (EPISODE == 2) //-------------------------------------------------------

	Sint16 baseshape, towait;
	ControlStruct ctrl;
	Sint16 shapes[] = {SCRUBR1SPR, SCRUBD1SPR, SCRUBL1SPR, SCRUBU1SPR};
	Sint32 scruby = 4, scrubx = 0, xspeed = 2, yspeed = 0;
	Sint16 frame = 0;
	Sint16 var_22 = 0, var_24 = 0;	//never used!
	Sint16 counter = 0;

	DrawOrderingScreen();
	FadeIn();
	ClearKeys();
	towait = SCREENTIME;
	do
	{
		ctrl = ControlPlayer(1);
		RF_Clear();

		if (xspeed > 0)
		{
			baseshape = shapes[0];
			scrubx += PIXEL_TO_GLOBAL(xspeed);
			if (scrubx > 302*PIXGLOBAL)
			{
				xspeed = 0;
				yspeed = 2;
			}
		}
		if (xspeed < 0)
		{
			baseshape = shapes[2];
			scrubx += PIXEL_TO_GLOBAL(xspeed);
			if (scrubx < 2)
			{
				xspeed = 0;
				yspeed = -2;
			}
		}
		if (yspeed > 0)
		{
			baseshape = shapes[1];
			scruby += PIXEL_TO_GLOBAL(yspeed);
			if (scruby > 184*PIXGLOBAL)
			{
				xspeed = -2;
				yspeed = 0;
			}
		}
		if (yspeed < 0)
		{
			baseshape = shapes[3];
			scruby += PIXEL_TO_GLOBAL(yspeed);
			if (scruby < 6)
			{
				xspeed = 2;
				yspeed = 0;
			}
		}

		if ((counter % 4) == 0)
		{
			frame ^= 1;
		}

		RF_PlaceSprite(scrubx+originx, scruby+originy, baseshape+frame);

		RF_Refresh();
		counter++;

		if (timed)
		{
			towait = towait - tics;
		}

		if (DoFkeys())
		{
			ClearKeys();
			DrawOrderingScreen();
		}

		if (ctrl.button1 || ctrl.button2 || NoBiosKey(1))
		{
			towait = 0;
		}

	} while (towait > 0);

#elif (EPISODE == 3) //-------------------------------------------------------

#define KEENX (originx + 8*PIXGLOBAL)
#define KEENY (originy + 176*PIXGLOBAL)
#define FOOBX (foobx + originx)
#define FOOBY (originy + 184*PIXGLOBAL)

	ControlStruct ctrl;
	Sint32 foobx, xspeed;
	register Sint16 hidetics = 100;
	register Sint16 movetics = 0;
	Sint16 var_10 = 0, var_12 = 0, var_14 = 0;	// never used!
	Sint16 towait;
	Sint16 counter = 0;


	DrawOrderingScreen();
	FadeIn();
	ClearKeys();
	towait = SCREENTIME;
	do
	{
		ctrl = ControlPlayer(1);
		RF_Clear();

		if (movetics == 0 || movetics > 10)
		{
			RF_PlaceSprite(KEENX, KEENY, KEENWALKR1SPR);
		}
		else if (xspeed < 0)
		{
			RF_PlaceSprite(KEENX, KEENY, KEENSHOOTRSPR);
		}
		else
		{
			RF_PlaceSprite(KEENX, KEENY, KEENWALKR1SPR);
		}

		if (hidetics != 0)
		{
			hidetics--;
			if (hidetics == 0)
			{
				foobx = 340*PIXGLOBAL;
				xspeed = -PIXGLOBAL;
				movetics = Rnd(175) + 100;
			}
		}

		if (movetics != 0)
		{
			foobx += xspeed;
			if (xspeed < 0)
			{
				RF_PlaceSprite(FOOBX, FOOBY, (counter & 2)/2 + FOOBL1SPR);
			}
			else
			{
				RF_PlaceSprite(FOOBX, FOOBY, (counter & 2)/2 + FOOBR1SPR);
			}

			movetics--;
			if (movetics == 0)
			{
				if (xspeed < 0)
				{
					PlaySound(YORPSCREAMSND);
					RF_Clear();
					RF_PlaceSprite(KEENX, KEENY, KEENSHOOTRSPR);
					RF_PlaceSprite(FOOBX, FOOBY, FOOBYELL1SPR);
					RF_Refresh();
					RF_Refresh();

					RF_Clear();
					RF_PlaceSprite(KEENX, KEENY, KEENSHOOTRSPR);
					RF_PlaceSprite(FOOBX, FOOBY, FOOBYELL2SPR);
					RF_Refresh();
					RF_Refresh();

					xspeed = 6*PIXGLOBAL;
					movetics = (340*PIXGLOBAL - foobx)/(6*PIXGLOBAL);
				}
				else
				{
					hidetics = Rnd(50) + 10;
					xspeed = 0;
				}
			}
		}

		RF_Refresh();
		counter++;

		if (timed)
		{
			towait = towait - tics;
		}

		if (DoFkeys())
		{
			ClearKeys();
			DrawOrderingScreen();
		}

		if (ctrl.button1 || ctrl.button2 || NoBiosKey(1))
		{
			towait = 0;
		}

	} while (towait > 0);

#undef KEENX
#undef KEENY
#undef FOOBX
#undef FOOBY

#endif //---------------------------------------------------------------------
}


/*
=====================
=
= DrawOrderingInfo
=
=====================
*/

void DrawOrderingInfo(void)
{
#if (EPISODE == 1) //---------------------------------------------------------

	leftedge = sx = 12;
	sy = 4;
	PrintGrey("Commander Keen: Invasion\n");
	PrintGrey("of the Vorticons consists\n");
	PrintGrey("   of three unique and\n");
#if VERSION <= VER_120
	PrintGrey("  challenging episodes:\n\n");
	PrintGrey("1. Marooned on Mars   $15\n");
	PrintGrey("2. The Earth Explodes $15\n");
	PrintGrey("3. Keen Must Die!     $15\n\n");
	leftedge = sx = 4;
	PrintGrey(" Order the trilogy for $30 and you get:\n");
	PrintGrey("  * The \"Secret Hints & Tricks\" sheet\n");
	PrintGrey("  * The special \"cheat mode\" password\n");
	PrintGrey("  * The latest version of each game\n");
	PrintGrey("  * SEVERAL FREE BONUS GAMES!\n\n");
	PrintGrey("                       Mail orders to:\n");
	PrintGrey("(U.S. funds only       Apogee Software\n");
	PrintGrey("checks or M/O's        P.O. Box 476389\n");
	PrintGrey("include $2 P&H)        Garland, TX 75047\n\n");
#else
	PrintGrey("  challenging episodes:\n");
	PrintGrey("1. Marooned on Mars   $15\n");
	PrintGrey("2. The Earth Explodes $15\n");
	PrintGrey("3. Keen Must Die!     $15\n");
	leftedge = sx = 5;
#if VERSION == VER_132
	PrintGrey(" Order the trilogy for $20 and you get\n");
#else
	PrintGrey(" Order the trilogy for $30 and you get\n");
#endif
	leftedge = --sx;
	PrintGrey("  * The \"Secret Hints & Tricks\" sheet\n");
	PrintGrey("  * The special \"cheat mode\" password\n");
	PrintGrey("  * The latest version of each game\n");
#if VERSION == VER_132
	PrintGrey("  MENTION THIS GRAVIS PRE-REGISTRATION!\n\n");
#else
	PrintGrey("  * SEVERAL FREE BONUS GAMES!\n\n");
#endif
	PrintGrey("                       Mail orders to:\n");
	PrintGrey("(U.S. funds only       Apogee Software\n");
	PrintGrey("checks or M/O's        P.O. Box 476389\n");
	PrintGrey("include $2 P&H)        Garland, TX 75047\n\n\n");
	PrintGrey("Specify 5.25/3.5 disk size when ordering\n");
#endif
	sx = 0;
	PrintGrey("       Or order toll free: 1-800-852-5659    \n");

#elif (EPISODE == 2) //-------------------------------------------------------

	leftedge = sx = 6;
	sy = 3;
#if VERSION <= VER_120
	PrintGrey("  Commander Keen: Invasion of the   \n");
	PrintGrey("Vorticons consists of three unique  \n");
	PrintGrey("     and challenging episodes:\n\n");
#else
	PrintGrey("   Commander Keen: Invasion of the  \n");
	PrintGrey(" Vorticons consists of three unique \n");
	PrintGrey("      and challenging episodes:\n\n");
#endif
	PrintGrey(" Order the trilogy for $30 and get:\n");
	PrintGrey("* The \"Secret Hints & Tricks\" sheet\n");
	PrintGrey("* The special \"cheat mode\" password\n");
	PrintGrey("* The latest version of each game\n");
	PrintGrey("* SEVERAL FREE BONUS GAMES!\n\n");
	PrintGrey("          Mail orders to:\n");
	PrintGrey("          Apogee Software\n");
	PrintGrey("          P.O. Box 476389\n");
	PrintGrey("          Garland, TX 75047\n\n");
	PrintGrey("  U.S. funds only; checks or M/O's\n");
#if VERSION <= VER_120
	PrintGrey("   Include $2 postage & handling\n\n");
#else
	PrintGrey("   Include $2 postage & handling\n");
	PrintGrey("Specify 5.25/3.5 disk when ordering.\n");
#endif
	PrintGrey(" Or order toll free: 1-800-852-5659 ");

#elif (EPISODE == 3) //-------------------------------------------------------

	leftedge = sx = 4;
	sy = 4;
	PrintGrey("    Commander Keen: Invasion of the\n");
	PrintGrey("   Vorticons consists of three unique\n");
	PrintGrey("        and challenging episodes:\n\n");
	PrintGrey("   Order the trilogy for $30 and get:\n");
	PrintGrey("  * The \"Secret Hints & Tricks\" sheet\n");
	PrintGrey("  * The special \"cheat mode\" password\n");
	PrintGrey("  * The latest version of each game\n");
	PrintGrey("  * SEVERAL FREE BONUS GAMES!\n\n");
	PrintGrey(" Mail orders to:     U.S funds only;\n");
	PrintGrey(" Apogee Software     checks or M/O's.\n");
	PrintGrey(" P.O. Box 476389     Include $2 postage\n");
	PrintGrey(" Garland, TX 75047   and handling.\n\n");
#if VERSION > VER_120
	PrintGrey("Specify 5.25/3.5 disk size when ordering\n");
#endif
	PrintGrey("   Or order toll free: 1-800-852-5659 ");

#endif //---------------------------------------------------------------------
}


/*
=====================
=
= DrawOrderingScreen
=
=====================
*/

void DrawOrderingScreen(void)
{
	originx = X_ORDER;
	originy = Y_ORDER;
#if VERSION > VER_110
	// need to update tile origin for RF_PlaceSprite:
	ox = GLOBAL_TO_TILE(originx);
	oy = GLOBAL_TO_TILE(originy);
#endif

#if (EPISODE == 2)
	originy -= 4*PIXGLOBAL;	// BUG: should be adjusted BEFORE calculating oy
#endif

	RF_ForceRefresh();
	RF_Clear();
	uservect = DrawOrderingInfo;
	RF_Refresh();
	RF_Refresh();
	uservect = NULL;
	ClearKeys();
}

#endif	// if VERSION < VER_134

/*
=====================
=
= PrintGrey
=
=====================
*/

void PrintGrey(char *text)
{
	char ch;

	while ((ch = *text++) != 0)
	{
		if (ch == '\n')
		{
			sy++;
			sx = leftedge;
		}
		else if (ch == '\r')
		{
			sx = leftedge;
		}
		else
		{
			DrawChar(sx++, sy*8, ch + 0x80);	// using the later half of the font (red text on grey background)
		}
	}
}

/*
==============================================================================

                           MAPKEEN ROUTINES

==============================================================================
*/

objtype mapkeen;


/*
=====================
=
= ClipMapKeen
=
=====================
*/

boolean ClipMapKeen(objtype *ob)
{
	Sint16 extra;
	Sint16 x, y, tileleft, tileright, tiletop, tilebottom;
	boolean result;

#if VERSION > VER_100
	if (cheatmode)
	{
		return false;
	}
#endif

	ob->xmove = ob->xmove + ob->xspeed * tics;
	ob->ymove = ob->ymove + ob->yspeed * tics;

	// Note: 'mapkeen' is only used in this routine, so any
	// changes made to it are basically discarded on return.
	// Only the changes made to 'ob' will have an effect.
	mapkeen = *ob;
	result = false;

	mapkeen.bottom += mapkeen.ymove;
	mapkeen.top += mapkeen.ymove;
	tileleft = mapkeen.left / TILEGLOBAL;
	tileright = mapkeen.right / TILEGLOBAL;

	if (mapkeen.ymove > 0)
	{
		// moving down
		if (mapkeen.bottom / TILEGLOBAL != (mapkeen.bottom - mapkeen.ymove) / TILEGLOBAL)
		{
			// movement crossed a tile boundary, so check for blocking tiles (or levels):
			tilebottom = mapkeen.bottom / TILEGLOBAL;
			for (x = tileleft; x <= tileright; x++)
			{
				if (northwall[GETTILE(x,tilebottom,0)] || GETTILE(x,tilebottom,1) & infoBlockMask)
				{
					ob->yspeed = 0;
					extra = (mapkeen.bottom + 1) % TILEGLOBAL;
					ob->ymove -= extra;
					mapkeen.top -= extra;
					mapkeen.bottom -= extra;
					result = true;
					break;
				}
			}
		}
	}
	else if (mapkeen.ymove < 0)
	{
		// moving up
		if (mapkeen.top / TILEGLOBAL != (mapkeen.top - mapkeen.ymove) / TILEGLOBAL)
		{
			// movement crossed a tile boundary, so check for blocking tiles (or levels):
			tiletop = mapkeen.top / TILEGLOBAL;
			for (x = tileleft; x <= tileright; x++)
			{
				if (southwall[GETTILE(x,tiletop,0)] || GETTILE(x,tiletop,1) & infoBlockMask)
				{
					ob->yspeed = 0;
					extra = TILEGLOBAL - mapkeen.top % TILEGLOBAL;
					ob->ymove += extra;
					mapkeen.top += extra;
					mapkeen.bottom += extra;
					result = true;
					break;
				}
			}
		}
	}

	mapkeen.left += mapkeen.xmove;
	mapkeen.right += mapkeen.xmove;
	tiletop = mapkeen.top / TILEGLOBAL;
	tilebottom = mapkeen.bottom / TILEGLOBAL;

	if (mapkeen.xmove > 0)
	{
		// moving right
		if (mapkeen.right / TILEGLOBAL != (mapkeen.right - mapkeen.xmove) / TILEGLOBAL)
		{
			// movement crossed a tile boundary, so check for blocking tiles (or levels):
			tileright = mapkeen.right / TILEGLOBAL;
			for (y = tiletop; y <= tilebottom; y++)
			{
				if (westwall[GETTILE(tileright,y,0)] || GETTILE(tileright,y,1) & infoBlockMask)
				{
					ob->xspeed = 0;
					extra = (mapkeen.right + 1) % TILEGLOBAL;
					ob->xmove -= extra;
					mapkeen.left -= extra;
					mapkeen.right -= extra;
					result = true;
					break;
				}
			}
		}
	}
	else if (mapkeen.xmove < 0)
	{
		// moving left
		if (mapkeen.left / TILEGLOBAL != (mapkeen.left - mapkeen.xmove) / TILEGLOBAL)
		{
			// movement crossed a tile boundary, so check for blocking tiles (or levels):
			tileleft = mapkeen.left / TILEGLOBAL;
			for (y = tiletop; y <= tilebottom; y++)
			{
				if (eastwall[GETTILE(tileleft,y,0)] || GETTILE(tileleft,y,1) & infoBlockMask)
				{
					ob->xspeed = 0;
					extra = TILEGLOBAL - mapkeen.left % TILEGLOBAL;
					ob->xmove += extra;
					mapkeen.left += extra;
					mapkeen.right += extra;
					result |= true;
					break;
				}
			}
		}
	}
	return result;
}


/*
=====================
=
= ControlMapKeen
=
=====================
*/

void ControlMapKeen(ControlStruct ctrl, objtype *ob)
{
	Sint16 x, y, tileleft, tiletop, tileright, tilebottom;
	Sint16 spotX, spotY, move, anim;
	boolean blocked;

#if (EPISODE == 3)
	// do nothing if Keen is riding Messie:
	if (messiestate != 0)
	{
		return;
	}
#endif

	UpdateObjHitbox(ob);

	// check for level entrances (or teleporters):
	if (ctrl.button1 || ctrl.button2)
	{
		tileleft = ob->left / TILEGLOBAL;
		tileright = ob->right / TILEGLOBAL;
		tiletop = ob->top / TILEGLOBAL;
		tilebottom = ob->bottom / TILEGLOBAL;
		for (x = tileleft; x <= tileright; x++)
		{
			for (y = tiletop; y <= tilebottom; y++)
			{
				if (GETTILE(x, y, 1))
				{
					spotX = x;
					spotY = y;
					LevelNumber = GETTILE(x, y, 1);
					if (LevelNumber == 255)	// skip Keen's spawn point
						LevelNumber = 0;
				}
			}
		}
	}

	// move mapkeen:
	ob->xmove = ob->ymove = 0;
	switch (ctrl.dir)
	{
	case northwest:
		ob->ymove = -4*PIXGLOBAL;
		ob->xmove = -4*PIXGLOBAL;
		ob->shapenum = MAPKEENU1SPR;
		break;

	case north:
		ob->ymove = -4*PIXGLOBAL;
		ob->shapenum = MAPKEENU1SPR;
		break;

	case northeast:
		ob->ymove = -4*PIXGLOBAL;
		ob->xmove = 4*PIXGLOBAL;
		ob->shapenum = MAPKEENU1SPR;
		break;

	case east:
		ob->xmove = 4*PIXGLOBAL;
		ob->shapenum = MAPKEENR1SPR;
		break;

	case southeast:
		ob->ymove = 4*PIXGLOBAL;
		ob->xmove = 4*PIXGLOBAL;
		ob->shapenum = MAPKEEND1SPR;
		break;

	case south:
		ob->ymove = 4*PIXGLOBAL;
		ob->shapenum = MAPKEEND1SPR;
		break;

	case southwest:
		ob->ymove = 4*PIXGLOBAL;
		ob->xmove = -4*PIXGLOBAL;
		ob->shapenum = MAPKEEND1SPR;
		break;

	case west:
		ob->xmove = -4*PIXGLOBAL;
		ob->shapenum = MAPKEENL1SPR;
		break;
	}
	//BUG? MapKeen speed doesn't adapt to frame rate

	move = false;
	if (ob->xmove | ob->ymove)	// yes, that's a bitwise OR in the original code!
	{
		anim = (((Uint16)timecount >> 4) & 3);
		move++;
	}
	else
	{
		anim = 0;
	}

	infoBlockMask = 0x8000;
#if VERSION < VER_100
	if (keydown[KEY_TAB])
#else
	if (keydown[KEY_TAB] && keydown[KEY_LSHIFT])
#endif
	{
		infoBlockMask = 0;
	}
	// Note: Most IBM-compatibles send a temporary LSHIFT key press signal when
	// the grey arrow keys on the keyboard are pressed and NumLock is on. This
	// means you don't actually need to hold down the left Shift key in addition
	// to the Tab key when using the grey arrow keys. If NumLock is off, most
	// systems send a temporary LSHIFT key release signal when a grey arrow key
	// is pressed while the left Shift key is being held down. That means you
	// have to press the left Shift key AFTER pressing the cursor key when
	// NumLock is off and you want to use these cheat keys to bypass a level.
	// These temporary LSHIFT press/release signals are the reason why you can't
	// use the left Shift key for anything (see CalibrateKeys in IDLIB.C).

	blocked = ClipMapKeen(ob);
	ob->x += ob->xmove;
	ob->y += ob->ymove;

	if (move && !(((Uint16)timecount >> 3) & 3))
	{
		if (blocked)
		{
			PlaySound(WLDBLOCKSND);
		}
		else
		{
			PlaySound(WLDWALKSND);
		}
	}

	// scroll screen and place mapkeen sprite:
	if (ob->xmove > 0 && ob->x - originx > 11*TILEGLOBAL)
	{
		originx += ob->xmove;
		if (originx > originxmax)
		{
			originx = originxmax;
		}
	}
	else if (ob->xmove < 0 && ob->x - originx < 9*TILEGLOBAL)
	{
		originx += ob->xmove;
		if (originx < originxmin)
		{
			originx = originxmin;
		}
	}
	if (ob->ymove > 0 && ob->y - originy > 7*TILEGLOBAL)
	{
		originy += ob->ymove;
		if (originy > originymax)
		{
			originy = originymax;
		}
	}
	else if (ob->ymove < 0 && ob->y - originy < 3*TILEGLOBAL)
	{
		originy += ob->ymove;
		if (originy < originymin)
		{
			originy = originymin;
		}
	}
	ox = GLOBAL_TO_TILE(originx);
	oy = GLOBAL_TO_TILE(originy);

	RF_PlaceSprite(ob->x, ob->y, ob->shapenum+anim);

#if (EPISODE == 3)
	if (messiestate == 0)	// messiestate is always 0 here (see beginning of this function)
	{
		if (messiecooldown == 0)
		{
			Sint16 w, h;

			// check if Keen is touching the Messie sprite (assumes all Messie sprites have the same size):
			w = spritetable[MESSIELD1SPR*4].width;	// width is in bytes (8 pixels per byte)
			h = spritetable[MESSIELD1SPR*4].height;
			// Note: The check is a bit weird, as it operates on the size of the
			// Messie sprite and not its hitbox and it does not take the size of
			// the Keen sprite (nor its hitbox) into account.
			if (ob->x >= messiex && messiex+PIXEL_TO_GLOBAL(w*8l) >= ob->x
				&& ob->y >= messiey && ob->y <= messiey+(h << G_P_SHIFT))
			{
				// Keen starts riding Messie
				PlaySound(CRYSTALSND);
				messiestate++;
				messiecooldown = 30;
			}
		}
		else
		{
			messiecooldown--;
		}
	}
#endif

	// check for teleporters and BWB:
	if (LevelNumber)
	{
		if (CheckMapKeenTiles(LevelNumber, ob, spotX, spotY))
		{
			LevelNumber = 0;
		}
	}
}


/*
=====================
=
= CheckMapKeenTiles
=
=====================
*/

#pragma argsused
boolean CheckMapKeenTiles(Sint16 num, objtype *ob, Sint16 spotX, Sint16 spotY)
{
#if (EPISODE == 1) //---------------------------------------------------------

	Sint16 i;
	ControlStruct ctrl;
	Sint16 t1, t2, anim, basetile, x, y;

	if (num == 20)
	{
		ExpWin(20, 8);
		Print("Your ship is missing\nthese parts:\n\n\n\n\n");
		Print("    GO GET THEM!\n");
		Print("   press a ");
		switch (playermode[1])
		{
		case keyboard:
			Print("key:");
			break;

		default:
			Print("button:");
			break;
		}
		if (!gamestate.gotJoystick)
		{
			DrawTile(leftedge+3, (sy-4)*8, 321);
		}
		if (!gamestate.gotBattery)
		{
			DrawTile(leftedge+7, (sy-4)*8, 322);
		}
		if (!gamestate.gotVacuum)
		{
			DrawTile(leftedge+11, (sy-4)*8, 323);
		}
		if (!gamestate.gotEverclear)
		{
			DrawTile(leftedge+15, (sy-4)*8, 324);
		}

		WaitVBL(15);
		Ack();
		RF_ForceRefresh();
		return true;	// cannot enter a level here
	}

	for (i = 0; i < 3; i++)	// probably a bug
	{
		if ((num & 0x20) == 0x20)
		{
			// decode teleporter indices:
			t1 = (num & 3) - 1;
			t2 = ((num >> 2) & 3) - 1;
			// BUG? negative indices are possible but not accounted for!

			x = spotX;
			y = spotY;

			basetile = 338;
			if (warpspots[t2].tag)
			{
				basetile = 342;
			}

			PlaySound(TELEPORTSND);

			// animate the teleporter tile:
			for (i = 0; i < 16; i++)	// same loop variable as outer loop!
			{
				RF_Clear();
				RF_ForceRefresh();	// not really required here...

				if (i % 2 == 0)
				{
					if (++anim > 3)
					{
						anim = 0;
					}
				}
				SETTILE(x,y,0,anim + basetile);

				RF_Refresh();
			}

			// put "inactive" teleporter tile back on the map:
			basetile = 325;
			if (warpspots[t2].tag)
			{
				basetile = 99;
			}
			SETTILE(x,y,0,basetile);

			// move to destination:
			ob->x = oldx = worldkeenx = warpspots[t1].x;
			ob->y = oldy = worldkeeny = warpspots[t1].y;
			originx = ob->x - 9*TILEGLOBAL;
			originy = ob->y - 3*TILEGLOBAL;
			// Note: ox and oy should be updated as well,
			// otherwise RF_PlaceSprite won't work correctly for moving or
			// animated sprites!

			x = ob->x / TILEGLOBAL;
			y = ob->y / TILEGLOBAL;

			basetile = 338;
			if (warpspots[t1].tag)
			{
				basetile = 342;
			}

			// animate the teleporter tile:
			for (i = 0; i < 16; i++)	// same loop variable as outer loop!
			{
				RF_Clear();
				RF_ForceRefresh();	// not really required here...

				if (i % 2 == 0)
				{
					if (++anim > 3)
					{
						anim = 0;
					}
				}
				SETTILE(x,y,0,anim + basetile);

				RF_Refresh();
			}

			// put "inactive" teleporter tile back on the map:
			basetile = 325;
			if (warpspots[t1].tag)
			{
				basetile = 99;
			}
			SETTILE(x,y,0,basetile);

			// wait for the player to release the buttons,
			// so Keen won't enter the teleporter right away:
			do
			{
				RF_Clear();
				ctrl = ControlPlayer(1);
				RF_PlaceSprite(ob->x, ob->y, ob->shapenum);
				RF_Refresh();
				HandleUserKeys();
				DoFkeys();
			} while (ctrl.button1 || ctrl.button2);

			return true;	// cannot enter a level here
		}
	}

#elif (EPISODE == 3) //-------------------------------------------------------

	if (num == 20)
	{
		Sint16 message, y;

		message = Rnd(3);
		ExpWin(32, 6);
		y = sy;
		switch (message)
		{
		case 0:
			Print("You enter your ship, sit around\n");
			Print("for a while, get bored, then\n");
			Print("remember that you have to find\n");
			Print("the Grand Intellect!");
			break;

		case 1:
			Print("Into the ship you journey, lie\n");
			Print("about a bit, then resume your\n");
			Print("quest for the Grand Intellect!");
			break;

		case 2:
			Print("You feel like entering the ship\n");
			Print("and taking a rest, but the\n");
			Print("mystery of the Grand Intellect's\n");
			Print("identity changes your mind.");
			break;

		case 3:
			Print("Entering the ship might be a\n");
			Print("fun thing to do, but right now,\n");
			Print("you need to find the Grand\n");
			Print("Intellect and vanquish him!");
			break;
		}
		sy = y + 4;
		Print("\n         press a ");
		switch (playermode[1])
		{
		case keyboard:
			Print("key:");
			break;
		default:
			Print("button:");
		}
		ClearKeys();
		Ack();
		ClearKeys();
		RF_ForceRefresh();
		return true;	// cannot enter a level here
	}

	if ((num & 0xFF00) >= 0x2000 && (num & 0xFF00) <= 0x2200)
	{
		// info value is Messie-related data
		return true;	// cannot enter a level here
	}

	if ((num & 0xF00) == 0xF00)
	{
		Sint16 i, index, anim, tilenum;

		// decode source teleporter index:
		index = (num & 0xF0) >> 4;

		// animate the teleporter tile (and Messie):
		for (i = 0; i < 2; i++)
		{
			PlaySound(TELEPORTSND);
			for (tilenum = 130; tilenum < 134; tilenum++)
			{
				SETTILE(warps[index].x, warps[index].y, 0, tilenum);
				RF_Clear();
				RF_PlaceSprite(messiex, messiey, messieshape + (anim & 2)/2);
				RF_Refresh();
				anim++;
				WaitVBL(4);
			}
		}
		// put "inactive" teleporter tile back on the map:
		SETTILE(warps[index].x, warps[index].y, 0, 134);

		// decode destination teleporter index:
		index = num & 0xF;

		// move screen to destination:
		if (warps[index].x < 10)
		{
			originx = 2*TILEGLOBAL;
		}
		else
		{
			originx = TILE_TO_GLOBAL(warps[index].x-10);
		}
		
		if (warps[index].y < 6)
		{
			originy = 2*TILEGLOBAL;
		}
		else
		{
			originy = TILE_TO_GLOBAL(warps[index].y-6);
		}
		
		// Note: ox and oy should be updated as well, otherwise RF_PlaceSprite
		// won't work correctly for moving or animated sprites!

		// animate the teleporter tile (and Messie):
		for (i = 0; i < 2; i++)
		{
			PlaySound(TELEPORTSND);
			for (tilenum = 130; tilenum < 134; tilenum++)
			{
				SETTILE(warps[index].x, warps[index].y, 0, tilenum);
				RF_Clear();
				RF_PlaceSprite(messiex, messiey, messieshape + (anim & 2)/2);
				RF_Refresh();
				anim++;
				WaitVBL(4);
			}
		}
		// put "inactive" teleporter tile back on the map:
		SETTILE(warps[index].x, warps[index].y, 0, 134);

		// move Keen to destination:
		ob->x = TILE_TO_GLOBAL(warps[index].x);
		ob->y = TILE_TO_GLOBAL(warps[index].y);
		return true;	// cannot enter a level here
	}

#endif //---------------------------------------------------------------------

	return false;
}


/*
=====================
=
= Ack
=
= Waits for key or joystick/mouse button (and animates the cursor)
=
=====================
*/

void Ack(void)
{
	ControlStruct c;
	Sint16 done, anim;

	anim = 0;
	done = false;
	
	//
	// This routine was by far the most complicated one to get an accurate
	// reconstruction of. The calls to ControlPlayer generate an automatic
	// hidden variable on the stack, whose contents are then copied into
	// whatever struct variable the result gets assigned to. The big problem
	// was that the original code used the opposite order of what the compiler
	// kept giving me when I compiled my reconstructed code. I used a fairly
	// convoluted version with goto statements that did give me the correct
	// machine code for Keen 1 and Keen 2, but it didn't work for Keen 3,
	// because Keen 3 needs to use different compiler optimizations.
	//
	// In the end, simply adding an unused local struct variable in the inner
	// loop was enough to trick the compiler into generating the same code as
	// in the original executables. So if you ever encounter a similar problem
	// when reconstructing Turbo C++ 1.0 code, that's something you could try.
	//

	// animate cursor and wait for a key or button press:
	do
	{
		ControlStruct temp;	// never used, just here to trick the compiler
		Sint16 i;
		
		DrawChar(sx, sy*8, anim+9);
		for (i = 0; i < 6; i++)
		{
			WaitVBL(1);
			c = ControlPlayer(1);
			if (c.button1 || c.button2 || NoBiosKey(1))
			{
				done++;
				break;
			}
		}
		if (++anim > 4)
		{
			anim = 0;
		}
	} while (!done);

	// wait until buttons are no longer held down:
	do
	{
		c = ControlPlayer(1);
	} while (c.button1 | c.button2);	// yes, this is a bitwise or in the code
	
	ClearKeys();
}


/*
==============================================================================

                        SCROLLING TEXT VIEW ROUTINES

==============================================================================
*/


/*
=====================
=
= DrawTextLines
=
=====================
*/

void DrawTextLines(Sint16 x, Sint16 y, char huge *textPtr, linetype *lineoffs, Uint16 numlines)
{
	Uint16 i, line, off, len, fontoff;

	sx = x;
	sy = y;
	fontoff = 0;	// black & white font by default
	for (line = 0; line < numlines; line++)
	{
		off = lineoffs[line].off;
		if (off == 0xFFFF)
		{
			return;
		}
		len = lineoffs[line].len;

		if (*(textPtr+off+len-1) == '\r')
		{
			len--;
		}
		if (textPtr[off] == '~')
		{
			fontoff = 0x80;	// red & grey font
			off++;
			len--;
		}
		else
		{
			fontoff = 0;	// black & white font
		}

		// draw the line of text:
		for (i = 0; i < len; i++)
		{
			DrawChar(sx++, sy*8, (*(textPtr+off+i) + fontoff) & 0xFF);
		}
		// blank the rest of the line (if any):
		if (sx < 43)
		{
			CharBar(sx, sy, 42, sy, fontoff + ' ');
		}

		sy++;
		sx = x;
	}
}


/*
=====================
=
= PrepareText
=
=====================
*/

void PrepareText(char huge *textPtr)
{
	Uint16 i, len;
	char c;

#if VERSION >= VER_100
	if (textPtr == NULL)
	{
		Quit("Missing a text file!");
	}
#endif

	// This code assumes the text uses DOS-style line breaks ("\r\n"), so when
	// we see a '\r' character, we know that it will always be followed by a '\n'
	// character. The code also assumes that the text has a CTRL-Z character
	// (a.k.a. ASCII SUB, a.k.a. DOS End Of File, a.k.a. 0x1A) at the end.

	// get the length of the text, in bytes:
	for (len = 0; textPtr[len] != 0x1A; len++);

	// Remove any line breaks from the text, except for blank lines. Line breaks
	// can be forced by using a 0x1F character (CTRL-_) in the text. These forced
	// line breaks should only be placed at the end of a line in the text file.
	for (i = 0; textPtr[i] != 0x1A; i++)
	{
		c = textPtr[i];
		if (c == 0x1F)
		{
			// convert into a forced line break:
			textPtr[i] = '\r';
		}
		else if (c == '\r' && *(textPtr+i+2) != '\r')
		{
			// replace the line break (2 chars!) with a single space character:
			textPtr[i] = ' ';
			movedata(FP_SEG(textPtr+i+2), FP_OFF(textPtr+i+2), FP_SEG(textPtr+i+1), FP_OFF(textPtr+i+1), len-i);
			len--;
		}
		else if (c == '\r' && *(textPtr+i+2) == '\r')
		{
			// skip to the next non-blank line:
			while (textPtr[i] == '\r')
			{
				i += 2;
			}
			i--;	// because the for-loop will increase it at the end
		}
	}
}


/*
=====================
=
= GetLineOffsets
=
=====================
*/

Uint16 GetLineOffsets(char huge *textPtr, linetype *lineoffs, Uint16 width, Uint16 maxlines)
{
	Uint16 line, off;
	Uint16 linestart, state;

	linestart = 0;
	state = 0;
	line = 0;
	off = 0;

	do
	{
		state = 0;
		lineoffs[line].off = linestart;

		for (off = linestart; off < linestart + width; off++)
		{
			if (textPtr[off] == 0x1A)
			{
				state = 2;
				lineoffs[line].len = off - linestart;
				lineoffs[line+1].off = 0xFFFF;
				lineoffs[line+1].len = 0xFFFF;
				break;
			}
			else if (textPtr[off] == '\r')
			{
				lineoffs[line].len = off - linestart + 1;
				line++;
				linestart = off+2;	// always skip the character after the '\r' (usually '\n' or space)
				state++;
				break;
			}
		}

		if (state == 0)
		{
			// line is now too long, go back to last space character:
			for (; off > linestart; off--)
			{
				if (textPtr[off] == ' ')
				{
					lineoffs[line].len = off - linestart;
					line++;
					linestart = off+1;	// skip the space character
					break;
				}
			}
			if (off == linestart)
			{
				// didn't find a space character - use max width:
				lineoffs[line].len = width;
				line++;
				off += width;
				linestart += width;
			}
		}

		if (line == maxlines)
		{
			lineoffs[line-1].off = 0xFFFF;
			lineoffs[line-1].len = 0xFFFF;
			state = 2;
		}
	} while (state < 2);

	return line;
}


/*
=====================
=
= ScrollTextWindow
=
=====================
*/

// Note: This routine scrolls the full width of the video buffer up or down 
// by one character (8 pixels), so it's important to make sure the text window
// always fills the entire width of the displayed screen area.
void ScrollTextWindow(Sint16 minY, Sint16 maxY, Sint16 dir)
{
	Uint16 blocksize;

	blocksize = ((maxY-minY)*8) * SCREENWIDTH;
	switch (dir)
	{
	case 0:	// move graphics down (scroll up)
		outportb(GC_INDEX, GC_MODE);
		outportb(GC_INDEX+1, 1);
		outportb(SC_INDEX, SC_MAPMASK);
		outportb(SC_INDEX+1, 15);
		minY *= SCREENWIDTH*8;
		
#ifdef K13_PORT
		K13_EGAScroll(minY, minY + SCREENWIDTH*8, blocksize, 0);
#else
		asm	pushf;
		asm	push	si;
		asm	push	di;
		asm	push	ds;
		asm	mov	di, minY;
		asm	mov	si, di;
		asm	add	si, SCREENWIDTH*8;
		asm	mov	cx, blocksize;
		asm	mov	ax, screenseg;
		asm	mov	es, ax;
		asm	mov	ds, ax;
		asm	cld;
		asm	rep movsb;
		asm	pop	ds;
		asm	pop	di;
		asm	pop	si;
		asm	popf;
#endif /* K13_PORT */
		break;

	case 1:	// move graphics up (scroll down)
		outportb(GC_INDEX, GC_MODE);
		outportb(GC_INDEX+1, 1);
		outportb(SC_INDEX, SC_MAPMASK);
		outportb(SC_INDEX+1, 15);
		maxY *= SCREENWIDTH*8;
		maxY += SCREENWIDTH*8 - 1;
		
#ifdef K13_PORT
		K13_EGAScroll(maxY, maxY - SCREENWIDTH*8, blocksize, 1);
#else
		asm	pushf;
		asm	push	si;
		asm	push	di;
		asm	push	ds;
		asm	mov	di, maxY;
		asm	mov	si, di;
		asm	sub	si, SCREENWIDTH*8;
		asm	mov	cx, blocksize;
		asm	mov	ax, screenseg;
		asm	mov	es, ax;
		asm	mov	ds, ax;
		asm	std;
		asm	rep movsb;
		asm	pop	ds;
		asm	pop	di;
		asm	pop	si;
		asm	popf;
#endif /* K13_PORT */
		break;
	}
}


/*
=====================
=
= PlayAnimation
=
=====================
*/

#if VERSION < VER_100
void PlayAnimation(Sint16 *data)
{
	animtype anims[MAXANIMS];
	Sint16 i;
	
	for (i=0; i<MAXANIMS; i++)
	{
		anims[i].used = false;
	}
	
	while (*data && !bioskey(1))
	{
		switch (*data++)
		{
		case 1:
			// find an unused animation entry:
			for (i=0; i<MAXANIMS; i++)
			{
				if (!anims[i].used)
				{
					break;
				}
			}
			// WARNING: This will cause memory corruption when no unused animation
			// entry could be found!
			anims[i].used = true;
			anims[i].x = *data++;
			anims[i].y = *data++;
			anims[i].speed = *data++;
			anims[i].animdelay = *data++;
			anims[i].shapenums[0] = *data++;
			anims[i].shapenums[1] = *data++;
			anims[i].shapenums[2] = *data++;
			anims[i].shapenums[3] = *data++;
			anims[i].dirptr = *data++;
			anims[i].ID = *data++;
			anims[i].dirindex = 0;
			anims[i].frame = 0;
			break;
			
		case 2:
			switch (*data++)
			{
			case 0:
				{
					Sint16 tx, ty, tile;
					
					tx = *data++ + originx / TILEGLOBAL;
					ty = *data++ + originy / TILEGLOBAL;
					tile = *data++;
					mapplane[0][ty*mapwwide+tx] = tile;
				}
				break;
				
			case 1:
				Print((char *)(*data++));
				break;
				
			case 2:
				// set position for Print() -- in character units (8x8 pixel blocks)
				sx = *data++;
				sy = *data++;
				break;
				
			case 3:
				{
					Sint16 count = *data++;
					
					while (count--)
					{
						RF_Refresh();
					}
				}
				break;
				
			case 4:
				PlaySound(*data++);
				break;
				
			case 5:
				{
					Sint16 ID = *data++, temp;
					
					for (temp=0; temp<MAXANIMS; temp++)
					{
						if (anims[temp].ID == ID)
						{
							switch (*data++)
							{
							case 0:
								anims[temp].x = *data++;
								break;
								
							case 1:
								anims[temp].y = *data++;
								break;
								
							case 2:
								anims[temp].speed = *data++;
								break;
								
							case 3:
								anims[temp].animdelay = *data++;
								break;
								
							case 4:
								anims[temp].shapenums[0] = *data++;
								break;
								
							case 5:
								anims[temp].shapenums[1] = *data++;
								break;
								
							case 6:
								anims[temp].shapenums[2] = *data++;
								break;
								
							case 7:
								anims[temp].shapenums[3] = *data++;
								break;
								
							case 8:
								anims[temp].dirptr = *data++;
								break;
								
							case 9:
								anims[temp].ID = *data++;
								break;
							}
							break;	// exit the for-loop
						}
					}
				}
				break;
			}
			break;
			
		case 3:
			{
				Sint16 frames = *data++;
				
				while (frames-- && !bioskey(1))
				{
					Sint16 temp;
					
					RF_Clear();
					for (temp = 0; temp < MAXANIMS; temp++)
					{
						if (anims[temp].used)
						{
							Sint8 *dirptr;
							Sint16 dirindex, screenx, screeny, shapenum, speed;
							
							dirptr = (Sint8*)(anims[temp].dirptr);
							dirindex = anims[temp].dirindex;
							screenx = anims[temp].x;
							screeny = anims[temp].y;
							speed = anims[temp].speed;
							switch (dirptr[dirindex])
							{
							case east:
								screenx += speed;
								break;
								
							case west:
								screenx -= speed;
								break;
								
							case north:
								screeny -= speed;
								break;
								
							case south:
								screeny += speed;
								break;
								
							case northwest:
								screenx -= speed;
								screeny -= speed;
								break;
								
							case northeast:
								screenx += speed;
								screeny -= speed;
								break;
								
							case southwest:
								screenx -= speed;
								screeny += speed;
								break;
								
							case southeast:
								screenx += speed;
								screeny += speed;
								break;
								
							case nodir+1:
								anims[temp].dirindex = -1;
								break;
							}
							anims[temp].dirindex++;
							anims[temp].x = screenx;
							anims[temp].y = screeny;
							
							if (frames % anims[temp].animdelay == 0)
							{
								if (++anims[temp].frame > 3)
								{
									anims[temp].frame = 0;
								}
							}
							shapenum = anims[temp].shapenums[anims[temp].frame];
							RF_PlaceSprite(screenx*PIXGLOBAL + originx, screeny*PIXGLOBAL + originy, shapenum);
						}
					}
					RF_Refresh();
				}
				break;
			}
		}
	}
	
	ClearKeys();
}
#endif	// VERSION < VER_100
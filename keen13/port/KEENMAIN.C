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

#include "KEENDEF.H"

/*
=============================================================================

			       GLOBALS

=============================================================================
*/

Sint16 coverlist[600], *coverlistptr;
Sint16 oldtiles[BIGPORTSIZE], oldtiles2[BIGPORTSIZE];

Uint16 far *mapplane[4];		// points into map
Sint16 mapbwide,mapwwide,mapwidthextra,mapheight;

drawtype spritelist[500], *spritelistptr;
drawtype piclist[10], *piclistptr;
drawtype tilelist[100], *tilelistptr;
Uint16 spritesshown, picsshown, tilesshown;

Uint16 tics;
Uint32 lasttimecount;

void (*uservect)(void);

Sint16 ox, oy;	// tile origin
Sint32 originx, originy;	// origin in global units
Sint32 monxmax, monymax, originxmin, originymin;
Sint32 playerxmax, playerymax, originxmax, originymax;
Uint16 EGApage;
Sint16 cyclespeed;

boolean SNDstarted,KBDstarted;	// whether int handlers were started
boolean resetgame;
#if VERSION >= VER_100
boolean joystickok;
boolean cheatmode;
#endif

LevelDef far *levelheader;	// also used as 'bigbuffer' for loading and saving images
#if VERSION <= VER_100
void far *picbuf;
#endif

#if VERSION <= VER_120
Sint16 levelnum;	// for /LEVEL parameter (loaded from TEDLEVEL.CK?)
#endif

Sint16 LevelNumber;
Sint32 lastextra;
Sint16 lastdir;
exittype LevelDone;

Sint16 numobj;
objtype objlist[MAXOBJECTS];

// unused dummy variables (non-static: KEENDEF.H declares them extern,
// and clang rejects a static definition after an extern declaration):
ControlStruct ctrl, lastctrl;
static Sint16 keensleft, SNDstarter;

/*
=============================================================================
*/

/*
=====================
=
= RF_Clear
=
=====================
*/

void RF_Clear(void)
{
	spritesshown = picsshown = tilesshown = 0;
	spritelistptr = spritelist;
	piclistptr = piclist;
	tilelistptr = tilelist;
	coverlistptr = coverlist;

#ifdef K13_PORT
	{ /* Keen Launcher port: frame pacing, tics, and the verification
	     harness all live behind this call; the sim-visible timecount
	     advances only by whole frame tics (deterministic replays) */
		Sint16 K13_FrameTics(Sint16, Sint16);
		tics = K13_FrameTics(MINTICS, MAXTICS);
	}
#else
	do
	{
		tics = timecount-lasttimecount;
	} while (tics < MINTICS);

	if (tics > MAXTICS)
	{
		tics = MAXTICS;
	}
#endif

	lasttimecount = timecount;
}


/*
=====================
=
= RF_Refresh
=
=====================
*/

void RF_Refresh(void)
{
	register Sint16 *ptr;
	void VidRefresh(void);

	VidRefresh();
	ptr = coverlist;
	if (EGApage)
	{
		while (ptr < coverlistptr)
		{
			oldtiles[*ptr] = -1;
			ptr++;
		}
	}
	else
	{
		while (ptr < coverlistptr)
		{
			oldtiles2[*ptr] = -1;
			ptr++;
		}
	}
}


/*
=====================
=
= RF_PlaceSprite
=
=====================
*/

boolean RF_PlaceSprite(Sint32 x, Sint32 y, Sint16 shapenum)
{
	Sint16 tx, ty;
	Sint16 tx_min, tx_max, ty_min, ty_max, px, py, num, tilenum, tiletype;

#ifdef K13_PORT
	{ /* presentation-only: the wide/interpolated compositor keeps its own
	     world-space sprite list; sim flow below is untouched */
		void K13_NoteSprite(Sint32, Sint32, Sint16);
		K13_NoteSprite(x, y, shapenum);
	}
#endif

	px = (x/PIXGLOBAL) - ((originx/PIXGLOBAL) & ~15);
	py = (y/PIXGLOBAL) - ((originy/PIXGLOBAL) & ~15);

	if (px < -32 || py < -32 || px > 336 || py > 199)	// minor BUG: py check should be 'py >= 208'
	{
		return false;
	}

	num = shapenum * 4 + (px & 7)/2;
	image = spritetable[num];

	px = (px+32)/8 - 4;
	tx_min = px/2;
	if (tx_min < 0)
	{
		tx_min = 0;
	}
	else if (tx_min > PORTTILESWIDE)
	{
		return false;
	}

	tx_max = (px + image.width - 1) / 2;
	if (tx_max > PORTTILESWIDE)
	{
		tx_max = PORTTILESWIDE;
	}
	else if (tx_max < 0)
	{
		return false;
	}

	ty_min = py/16;
	if (ty_min < 0)
	{
		ty_min = 0;
	}
	else if (ty_min > PORTTILESHIGH)
	{
		return false;
	}

	ty_max = (py + image.height - 1) / 16;
	if (ty_max > PORTTILESHIGH-1)
	{
		ty_max = PORTTILESHIGH-1;
	}
	else if (ty_max < 0)
	{
		return false;
	}

	px += 4;
	py += 32;

	// WARNING: There are no safety measures to prevent the code from adding a
	// new sprite entry when the spritelist is already full! This will lead to
	// memory corruption (the data following after spritelist will be
	// overwritten with a new drawtype entry). The same applies to the tilelist
	// and coverlist arrays, accessed via tilelistptr and coverlistptr here.

	for (ty = ty_min; ty <= ty_max; ty++)
	{
		for (tx = tx_min; tx <= tx_max; tx++)
		{
			tilenum = GETTILE(tx+ox,ty+oy,0);
			tiletype = intile[tilenum];
			if (tiletype >= 0)
			{
				// add tile spot to erase list to remove the
				// sprite during the next refresh:
				*coverlistptr = ty*PORTTILESWIDE + tx;
				coverlistptr++;
			}
			else	// sprite covers a foreground tile
			{
				// add the foreground tile:
				tilelistptr->x = tx*2 + 4;
				tilelistptr->y = ty*16 + 32;
				tilelistptr->num = tilenum;

				// check if foreground tile has transparent parts:
				if (tiletype == -2)
				{
					// draw tile as masked tile:
					tilelistptr->num |= 0x8000;

					// this spot also needs to be erased:
					*coverlistptr = ty*PORTTILESWIDE + tx;
					coverlistptr++;
				}
				// non-transparent foreground tiles don't need to be
				// added to the erase list (no sprite image visible)

				tilesshown++;
				tilelistptr++;
			}
		}
	}

	spritelistptr->x = px;
	spritelistptr->y = py;
	spritelistptr->num = num;
	spritesshown++;
	spritelistptr++;

	return true;
}


/*
=====================
=
= RF_PlaceTile
=
=====================
*/

boolean RF_PlaceTile(Sint32 x, Sint32 y, Sint16 tilenum)
{
	Sint16 tx, ty;
	Sint16 tx_min, tx_max, ty_min, ty_max, px, py;

	px = (x/PIXGLOBAL) - ((originx/PIXGLOBAL) & ~15);
	py = (y/PIXGLOBAL) - ((originy/PIXGLOBAL) & ~15);

	if (px < -32 || py < -32)
	{
		return false;
	}

	px = (px+32)/8 - 4;
	tx_min = px/2;
	if (tx_min < 0)
	{
		tx_min = 0;
	}
	else if (tx_min > PORTTILESWIDE)
	{
		return false;
	}

	tx_max = (px + image.width - 1)/2;	//BUG: shouldn't use sprite width for tiles!
	if (tx_max > PORTTILESWIDE-1)
	{
		tx_max = PORTTILESWIDE-1;
	}
	else if (tx_max < 0)
	{
		return false;
	}

	ty_min = py/16;
	if (ty_min < 0)
	{
		ty_min = 0;
	}
	else if (ty_min > PORTTILESHIGH-1)
	{
		return false;
	}

	ty_max = (py + image.height - 1)/16;	//BUG: shouldn't use sprite height for tiles!
	if (ty_max > PORTTILESHIGH-1)
	{
		ty_max = PORTTILESHIGH-1;
	}
	else if (ty_max < 0)
	{
		return false;
	}

	px += 4;
	py += 32;

	// WARNING: There are no safety measures to prevent the code from adding a
	// new tile entry when the tilelist is already full! This will lead to
	// memory corruption (the data following after tilelist will be overwritten
	// with a new drawtype entry). The same applies to the coverlist array,
	// accessed via coverlistptr here.

	for (ty = ty_min; ty <= ty_max; ty++)
	{
		for (tx = tx_min; tx <= tx_max; tx++)
		{
			*coverlistptr = ty*PORTTILESWIDE + tx;
			coverlistptr++;
		}
	}

	tilelistptr->x = px;
	tilelistptr->y = py;
	tilelistptr->num = tilenum;
	tilesshown++;
	tilelistptr++;

	return true;
}

/*
=============================================================================
*/

/*
=====================
=
= ReadLevel
=
=====================
*/

void ReadLevel(Sint16 number)
{
	void far *buffPtr;
	Sint16 i, handle;
#if BIGBUFFERSIZE > 0x10000
	Sint32 size;
#else
	Sint16 size;	// BUG: causes problems with level files larger than 32k
#endif
	char numbuf[4];
	char filename[12];

	level = number;
	if (number < 10)
	{
		itoa(number, numbuf, 10);
		strcpy(filename, "LEVEL0");
	}
	else
	{
		itoa(number, numbuf, 10);
		strcpy(filename, "LEVEL");
	}
	strcat(filename, numbuf);
	strcat(filename, ".");
	strcat(filename, _extension);

#if VERSION <= VER_100
	LoadFile(filename, picbuf);
	RLEWExpand(picbuf, (Uint16 far*)bigbuffer);
#else
	handle = open(filename, O_BINARY);
	size = filelength(handle);
	close(handle);

#if BIGBUFFERSIZE > 0x10000
	buffPtr = (char far *)((char huge *)bigbuffer+((BIGBUFFERSIZE-1)-size));
#else
	buffPtr = (char far *)bigbuffer+((BIGBUFFERSIZE-1)-size);
#endif
	LoadFile(filename, buffPtr);
	RLEWExpand(buffPtr, (Uint16 far*)bigbuffer);
#endif

#if BIGBUFFERSIZE > 0x10000
	// The 'i*planesize' calculation might be unsafe because the result will be
	// treated as an unsigned 16-bit value, but the actual result might be too
	// large to fit into 16 bits (when planesize >= 0x8000, for example).
	// This should never be a problem for Keen 1-3 since the levels only have
	// 2 planes, meaning planesize will only ever be multiplied by 0 or 1.
	// But let's omit the multiplication and simply assign the plane pointers by
	// adding planesize to the previous plane pointer, just to be safe.
	mapplane[0] = (Uint16 far *)((char huge *)bigbuffer + 32);
	for (i=1; i<levelheader->planes; i++)
	{
		mapplane[i] = (Uint16 far *)((char huge *)(mapplane[i-1]) + levelheader->planesize);
	}
#else
	for (i=0; i<levelheader->planes; i++)
	{
		mapplane[i] = (Uint16 far *)(bigbuffer + i*levelheader->planesize + 32);
	}
#endif
	mapwwide = levelheader->width;
	mapheight = levelheader->height;
	mapbwide = mapwwide*2;
	mapwidthextra = mapbwide - 2*PORTTILESWIDE;

	originxmin = 2*TILEGLOBAL;
	originymin = 2*TILEGLOBAL;
	originxmax = TILE_TO_GLOBAL(levelheader->width - PORTTILESWIDE - 1);
	monxmax = TILE_TO_GLOBAL(levelheader->width - 2);
	monymax = TILE_TO_GLOBAL(levelheader->height);
	originymax = TILE_TO_GLOBAL(levelheader->height - PORTTILESHIGH - 1) + 8*PIXGLOBAL;
	playerxmax = TILE_TO_GLOBAL(levelheader->width - 3);
	playerymax = TILE_TO_GLOBAL(levelheader->height);
}


/*
=====================
=
= AskQuit
=
=====================
*/

void AskQuit(void)
{
	ClearKeys();
	if (level == TITLEMAP)
	{
		ExpWin(12, 1);
		Print("Quit (Y/N)?");
		ch = toupper(Get());
		if (ch == 'Y')
		{
			Quit("");
		}
	}
	else
	{
		ExpWin(20, 2);
		Print("Quit to (D)os or\n");
		Print("(T)itle:");
		ch = toupper(Get());
		if (ch == 'D')
		{
			Quit("");
		}
		if (ch == 'T')
		{
			resetgame = true;
		}
	}
}


#if VERSION >= VER_100

/*
=====================
=
= JoyButton
=
=====================
*/

Sint16 JoyButton(void)
{
	Uint16 portval;

	portval = inp(0x201);
	if (!(portval & 0x10))
	{
		return 1;
	}
	if (!(portval & 0x20))
	{
		return 2;
	}
	return 0;
}


/*
=====================
=
= WriteHuge	(buggy, never used!)
=
=====================
*/

void WriteHuge(Sint16 handle, void huge *buff, Sint32 size)
{
	Sint16 i, n;
	Uint8 huge *ptr;
	Uint8 tempbuff[16];

	ptr = buff;

	// BUG: this NEVER writes the last 16 bytes! (n should start at 0)
	for (n = 1; size / 16 >= n; n++)
	{
		for (i = 0; i < 16; i++)
		{
			tempbuff[i] = *ptr;
			ptr++;
		}
		if (size / 16 == n)
		{
			write(handle, tempbuff, size % 16);
		}
		else
		{
			write(handle, tempbuff, 16);
		}
	}
}


/*
=====================
=
= DrawPicFile
=
=====================
*/

void DrawPicFile(char *filename)
{
	void far *buffer;
	Sint16 picoff, screenoff;
	Sint16 y;
	Sint16 segBlue, segGreen, segRed, segIntensity;

#if VERSION <= VER_100
	buffer = picbuf;
	LoadFile(filename, picbuf);
	buffer = paralloc(0x8000);
	RLEExpand(picbuf, buffer);
#else
	buffer = bigbuffer + 0x8000;
	LoadFile(filename, buffer);
	RLEExpand(buffer, bigbuffer);
#endif

	segBlue = FP_SEG(buffer);
	segGreen = segBlue + 0x200;
	segRed = segGreen + 0x200;
	segIntensity = segRed + 0x200;

	picoff = 0;
	screenoff = 4;
	originx = originy = 0;
	RF_Clear();
	RF_Refresh();

	outport(GC_INDEX, GC_MODE);	// read mode 0
	for (y=0; y<200; y++)
	{
		outportb(SC_INDEX, SC_MAPMASK);
		outportb(SC_INDEX+1, 1);
		movedata(segBlue, picoff, screenseg, screenoff, 40);
		outportb(SC_INDEX, SC_MAPMASK);
		outportb(SC_INDEX+1, 2);
		movedata(segGreen, picoff, screenseg, screenoff, 40);
		outportb(SC_INDEX, SC_MAPMASK);
		outportb(SC_INDEX+1, 4);
		movedata(segRed, picoff, screenseg, screenoff, 40);
		outportb(SC_INDEX, SC_MAPMASK);
		outportb(SC_INDEX+1, 8);
		movedata(segIntensity, picoff, screenseg, screenoff, 40);
		picoff += 40;
		screenoff += SCREENWIDTH;
	}
	outportb(SC_INDEX, SC_MAPMASK);
	outportb(SC_INDEX+1, 0xF);
	RF_ForceRefresh();
	
#if VERSION <= VER_100
	farfree(lastparalloc);
#endif
}


/*
=====================
=
= SaveScreenshot
=
=====================
*/

void SaveScreenshot(void)
{
	Sint16 y;

#if VERSION <= VER_100
#define BUFFER picbuf
#else
#define BUFFER bigbuffer
#endif

	outport(GC_INDEX, GC_MODE);	// read mode 0
	outportb(GC_INDEX, GC_READMAP);
	outportb(GC_INDEX+1, 0);
	for (y=0; y<200; y++)
	{
		movedata(screenseg, y*48+4, FP_SEG(BUFFER), y*40, 40);
	}
	outportb(GC_INDEX, GC_READMAP);
	outportb(GC_INDEX+1, 1);
	for (y=0; y<200; y++)
	{
		movedata(screenseg, y*48+4, FP_SEG(BUFFER), y*40 + 0x2000, 40);
	}
	outportb(GC_INDEX, GC_READMAP);
	outportb(GC_INDEX+1, 2);
	for (y=0; y<200; y++)
	{
		movedata(screenseg, y*48+4, FP_SEG(BUFFER), y*40 + 0x4000, 40);
	}
	outportb(GC_INDEX, GC_READMAP);
	outportb(GC_INDEX+1, 3);
	for (y=0; y<200; y++)
	{
		movedata(screenseg, y*48+4, FP_SEG(BUFFER), y*40 + 0x6000, 40);
	}
	SaveFile("KEENSCRN.PIC", BUFFER, 0x8000);
#undef BUFFER
}

#endif	// if VERSION >= VER_100


/*
=====================
=
= DoFkeys
=
= Checks to see if an F-key is being pressed and handles it
=
=====================
*/

#ifdef K13_PORT
/* Quicksave/quickload, reached through whatever key or pad button they are
   bound to (defaults F7/F9 and the stick clicks) rather than a fixed case in
   the F-key switch, so rebinding them actually takes effect. */
void K13_DoQuickSave(void)
{
	if (!K13_GetQSConfirm() || K13_Confirm("Quicksave?"))
	{
		ExpWin(20, 1);
		Print(K13_QuickSave() ? "Quicksaved." : "Quicksave failed!");
		Get();
	}
	RF_ForceRefresh();
}

void K13_DoQuickLoad(void)
{
	{
		Sint16 qlevel = (Sint16)K13_QuickSaveLevel();

		if (qlevel < 0)
		{
			ExpWin(22, 1);
			Print("No quicksave yet.");
			Get();
		}
		else if (!K13_GetQSConfirm() || K13_Confirm("Quickload?"))
		{
			if (qlevel == level)
			{
				/* same map is already up: swap the state in place */
				if (!K13_QuickLoad())
				{
					ExpWin(22, 1);
					Print("Quickload failed!");
					Get();
				}
			}
			else
			{
				/* another level: park the request.  On the world map the
				   loop below hands over to that level and LevelLoop
				   applies the state once its map is loaded, which is what
				   makes reloading after a death work. */
				K13_QLoadRequest();
			}
		}
	}
	RF_ForceRefresh();
}
#endif

boolean DoFkeys(void)
{
	Sint32 oldtime;
#if VERSION <= VER_120
	Sint16 key = bioskey(1) / 0x100;
#endif
	Sint16 i = 0;

#if (VERSION >= VER_100) && (VERSION <= VER_120)
	if (joystickok && playermode[1] != joystick1 && JoyButton())
	{
		while (JoyButton());
		key = KEY_F4;
	}
#elif VERSION > VER_120
	NoBiosKey(1);
#endif

	if (key == 0)	//useless in v1.3+ (key is an array, this checks if the address of the array is 0)
	{
		return false;
	}

	oldtime = timecount;
	/* Dispatch on the ACTION a key is bound to rather than on fixed F-key
	   scan codes, so every one of these is rebindable and clearable.  An
	   unbound or unrecognised key falls through to default, exactly as an
	   unhandled scan code used to. */
#ifdef K13_PORT
	switch (K13_KeyAction(K13_FKEY_SCAN))
#elif VERSION <= VER_120
	switch (key)
#elif VERSION == VER_130
	switch (NBKscan)
#else
	switch (NBKscan & 0x7F)
#endif
	{
	case K13_FKEY_HELP:
#if VERSION >= VER_100
		PauseSound();
#endif
		ClearKeys();
		ShowHelpText();

		i++;
		break;

	case K13_FKEY_SOUND:
#if VERSION >= VER_100
		PauseSound();
#endif
		ClearKeys();
		ExpWin(13, 1);
		Print("Sound (Y/N)?");
		ch = toupper(Get());
		if (ch == 'N')
		{
			soundmode = 0;
		}
		else if (ch == 'Y')
		{
			soundmode = 1;
		}
		i++;
		break;

	case K13_FKEY_KEYCONF:
#if VERSION >= VER_100
		PauseSound();
#endif
		ClearKeys();
		CalibrateKeys();
		i++;
		break;

	case K13_FKEY_JOYCONF:
#if VERSION >= VER_100
		PauseSound();
#endif
		ClearKeys();
		CalibrateJoy(1);
		i++;
		break;

	case K13_FKEY_SAVEMENU:
#if VERSION >= VER_100
		PauseSound();
#endif
		SaveMenu();
		i++;
		break;

#if (VERSION >= VER_100) && (VERSION <= VER_120)
	case KEY_F8:
		SaveScreenshot();
		PlaySound(GOTBONUSSND);
		WaitEndSound();
		ClearKeys();
		break;
#endif

#ifdef K13_PORT
	/* Keen Launcher: quicksave on F7 / quickload on F9.  F5 is already the
	   save MENU here (unlike Keen 4-6, where F5 is quicksave), so the pair
	   moved to the next free keys and F9 at least matches 4-6.  Unlike the
	   F5 slots, these capture the level in progress, not just the world map. */

#endif

#ifdef K13_PORT
	case K13_KEY_QSAVE:
		PauseSound();
		ClearKeys();
		K13_DoQuickSave();
		i++;
		break;

	case K13_KEY_QLOAD:
		PauseSound();
		ClearKeys();
		K13_DoQuickLoad();
		i++;
		break;

	case K13_KEY_SCOREBOX:
		/* the persistent HUD, toggled live like Keen 4-6's SCORE BOX */
		K13_SetScoreBox(!K13_GetScoreBox());
		K13_ConfigSave();
		i++;
		break;
#endif

	case K13_FKEY_QUIT:
#if VERSION >= VER_100
		PauseSound();
#endif
		AskQuit();
		i++;
		break;

	default:
		return false;
	}
#if VERSION < VER_100
	RF_ForceRefresh();
#endif
	timecount = oldtime;

	if (i)
	{
		ClearKeys();
#if VERSION >= VER_100
		ContinueSound();
		RF_ForceRefresh();
#endif
		return true;
	}
	else
	{
		return false;
	}
}


/*
=====================
=
= GivePoints
=
=====================
*/

void GivePoints(Sint16 toadd)
{
	gamestate.score += toadd;
#if VERSION < VER_100
	if (gamestate.score - lastextra > EXTRASCORE)
#else
	if (gamestate.score - lastextra >= EXTRASCORE)
#endif
	{
		PlaySound(EXTRAMANSND);
		lastextra = (gamestate.score / EXTRASCORE) * EXTRASCORE;
		gamestate.lives++;
	}
}


/*
=====================
=
= DoCheat
=
=====================
*/

void DoCheat(void)
{
	Sint32 oldtime;
	Sint16 i;

	oldtime = timecount;
	ClearKeys();

	ExpWin(26, 4);
#if (EPISODE == 1)
	Print("You are now cheating!\n");
	Print("You just got a pogo stick,\n");
	Print("all the key cards, and\n");
	Print("lots of ray gun charges.");
#else
	Print("You are now cheating!\n");
	Print("You just got all the\n");
	Print("key cards, and lots of\n");
	Print("ray gun charges.");
#endif

	gamestate.gotPogo = true;
	gamestate.ammo = 100;
	for (i=0; i<NUMKEYS; i++)
	{
		gamestate.keys[i] = true;
	}
#if VERSION < VER_100
	infoBlockMask = 0;	// doesn't work (ControlMapKeen ALWAYS resets it)
#endif

	Get();	// wait for a keypress (with animated cursor)

	RF_ForceRefresh();
	RF_Refresh();
	RF_Refresh();

	timecount = oldtime;
	ClearKeys();
}


/*
=====================
=
= ShowStatusScreen
=
=====================
*/

void ShowStatusScreen(void)
{
	Sint16 i, y;
	Sint16 x;
	Sint32 oldtime;

	oldtime = timecount;
	ClearKeys();

	// Note: The window background is white, but the text is drawn
	// using the second part of the font (red text on grey background).
	// The blank spaces are drawn as grey blocks in the white window.

#if (EPISODE == 1) //---------------------------------------------------------

	ExpWin(28, 13);
	x = sx;
	y = sy;
	PrintGrey("    SCORE     EXTRA KEEN AT \n");
	sx = x+12;
	PrintGrey(" \n");
	PrintGrey("    KEENS       SHIP PARTS  \n");
	sx = x+14;
	PrintGrey(" \n");
	sx = x+14;
	PrintGrey(" \n");
	sx = x+14;
	PrintGrey(" \n");
	PrintGrey(" RAYGUN   POGO    KEYCARDS  \n");
	sx = x+8;
	PrintGrey(" ");
	sx += 6;
	PrintGrey(" \n");
	sx = x+8;
	PrintGrey(" ");
	sx += 6;
	PrintGrey(" \n");
	sx = x+8;
	PrintGrey(" ");
	sx += 6;
	PrintGrey(" \n");
	PrintGrey(" CHARGE  ");
	sx += 6;
	PrintGrey(" \n");
	sx = x+8;
	PrintGrey(" ");
	sx += 6;
	PrintGrey(" \n");
	PrintGrey("     PLEASE PRESS A KEY     ");

	ltoa(gamestate.score, str, 10);
	sx = x+10 - strlen(str);
	sy = y+1;
	Print(str);

	ltoa(lastextra+EXTRASCORE, str, 10);
	sx = x+26 - strlen(str);
	Print(str);

	for (i=0; i<gamestate.lives && i<6; i++)
	{
		DrawSprite(x+i*2 + 1, (y + 3)*8, KEENWALKR1SPR*4);	// *4 because each sprite has 4 shifts!
	}

	sx = x+16;
	sy = y+3;
	DrawTile(sx, sy*8 + 4, gamestate.gotJoystick? 448 : 321);
	sx += 3;
	DrawTile(sx, sy*8 + 4, gamestate.gotBattery? 449 : 322);
	sx += 3;
	DrawTile(sx, sy*8 + 4, gamestate.gotVacuum? 450 : 323);
	sx += 3;
	DrawTile(sx, sy*8 + 4, gamestate.gotEverclear? 451 : 324);

	sx = x+19;
	sy = y+7;
	if (gamestate.keys[0])
	{
		DrawTile(sx, sy*8 + 3, 424);
	}
	if (gamestate.keys[1])
	{
		DrawTile(sx + 4, sy*8 + 3, 425);
	}
	if (gamestate.keys[2])
	{
		DrawTile(sx, sy*8 + 21, 426);
	}
	if (gamestate.keys[3])
	{
		DrawTile(sx + 4, sy*8 + 21, 427);
	}

	DrawTile(x + 3, (y+7)*8 + 4, 414);	// raygun icon
	sx = x+3;
	sy = y+11;
	PrintInt(gamestate.ammo);

	if (gamestate.gotPogo)
	{
		DrawTile(x+11, (y+8)*8 + 4, 415);
	}

#elif (EPISODE == 2) //-------------------------------------------------------

	ExpWin(28, 12);
	x = sx;
	y = sy;
	PrintGrey("    SCORE     EXTRA KEEN AT \n");
	sx = x+12;
	PrintGrey(" \n");
	PrintGrey("    KEENS            PISTOL \n");
	sx = x+19;
	PrintGrey(" \n");
	sx = x+19;
	PrintGrey(" \n");
	sx = x+19;
	PrintGrey(" \n");
	PrintGrey("   TARGETS SAVED      KEYS  \n");
	sx = x+19;
	PrintGrey(" \n");
	sx = x+19;
	PrintGrey(" \n");
	sx = x+19;
	PrintGrey(" \n");
	sx = x+19;
	PrintGrey(" \n");
	PrintGrey("     PLEASE PRESS A KEY     ");

	ltoa(gamestate.score, str, 10);
	sx = x+10 - strlen(str);
	sy = y+1;
	Print(str);

	ltoa(lastextra+EXTRASCORE, str, 10);
	sx = x+26 - strlen(str);
	Print(str);

	for (i=0; i<gamestate.lives && i<9; i++)
	{
		DrawSprite(x+i*2 + 1, (y + 3)*8, KEENWALKR1SPR*4);	// *4 because each sprite has 4 shifts!
	}

	DrawTile(x+21, (y+3)*8 + 4, 414);	// raygun icon
	sx = x+24;
	sy = y+4;
	PrintInt(gamestate.ammo);

	sx = x+21;
	sy = y+7;
	if (gamestate.keys[0])
	{
		DrawTile(sx, sy*8, 424);
	}
	if (gamestate.keys[1])
	{
		DrawTile(sx + 4, sy*8, 425);
	}
	if (gamestate.keys[2])
	{
		DrawTile(sx, sy*8 + 16, 426);
	}
	if (gamestate.keys[3])
	{
		DrawTile(sx + 4, sy*8 + 16, 427);
	}

	if (gamestate.citySaved[CITY_LONDON])
	{
		sx = x;
		sy = y+7;
		Print("London");
	}
	if (gamestate.citySaved[CITY_CAIRO])
	{
		sx = x;
		sy = y+8;
		Print("Cairo");
	}
	if (gamestate.citySaved[CITY_SYDNEY])
	{
		sx = x;
		sy = y+9;
		Print("Sydney");
	}
	if (gamestate.citySaved[CITY_NEWYORK])
	{
		sx = x;
		sy = y+10;
		Print("New York");
	}
	if (gamestate.citySaved[CITY_PARIS])
	{
		sx = x+10;
		sy = y+7;
		Print("Paris");
	}
	if (gamestate.citySaved[CITY_ROME])
	{
		sx = x+10;
		sy = y+8;
		Print("Rome");
	}
	if (gamestate.citySaved[CITY_MOSCOW])
	{
		sx = x+10;
		sy = y+9;
		Print("Moscow");
	}
	if (gamestate.citySaved[CITY_WASHINGTONDC])
	{
		sx = x+10;
		sy = y+10;
		Print("Wash D.C.");
	}

#elif (EPISODE == 3) //-------------------------------------------------------

	ExpWin(28, 11);
	x = sx;
	y = sy;
	PrintGrey("    SCORE     EXTRA KEEN AT \n");
	sx = x+12;
	PrintGrey(" \n");
	PrintGrey("    KEENS            PISTOL \n");
	sx = x+19;
	PrintGrey(" \n");
	sx = x+19;
	PrintGrey(" \n");
	sx = x+19;
	PrintGrey(" \n");
	PrintGrey(" ANKH TIME      KEY CARDS   \n");
	sx = x+11;
	PrintGrey(" \n");
	sx = x+11;
	PrintGrey(" \n");
	sx = x+11;
	PrintGrey(" \n");
	PrintGrey("     PLEASE PRESS A KEY     ");

	ltoa(gamestate.score, str, 10);
	sx = x+10 - strlen(str);
	sy = y+1;
	Print(str);

	ltoa(lastextra+EXTRASCORE, str, 10);
	sx = x+26 - strlen(str);
	Print(str);

	for (i=0; i<gamestate.lives && i<9; i++)
	{
		DrawSprite(x+i*2 + 1, (y + 3)*8, KEENWALKR1SPR*4);	// *4 because each sprite has 4 shifts!
	}

	DrawTile(x+21, (y+3)*8 + 4, 216);	// raygun icon
	sx = x+24;
	sy = y+4;
	PrintInt(gamestate.ammo);

	DrawTile(x+3, (y+7)*8 + 4, 214);	// ankh icon
	sx = x+7;
	sy = y+8;
	PrintInt(ankhtime/144);	// this many seconds left

	sx = x+13;
	sy = y+8;
	if (gamestate.keys[0])
	{
		DrawTile(sx, sy*8 - 4, 217);
	}
	if (gamestate.keys[1])
	{
		DrawTile(sx + 4, sy*8 - 4, 218);
	}
	if (gamestate.keys[2])
	{
		DrawTile(sx + 8, sy*8 - 4, 219);
	}
	if (gamestate.keys[3])
	{
		DrawTile(sx + 12, sy*8 - 4, 220);
	}

#endif //---------------------------------------------------------------------

	ClearKeys();
	NoBiosKey(0);	// wait for a keypress (no animation)

	RF_ForceRefresh();
	RF_Refresh();
	RF_Refresh();
	ClearKeys();
	timecount = oldtime;
}


/*
=====================
=
= HandleUserKeys
=
=====================
*/

void HandleUserKeys(void)
{
	if (keydown[KEY_C] && keydown[KEY_T] && keydown[KEY_SPACE])
	{
		DoCheat();
	}
#if VERSION >= VER_100
	if (keydown[KEY_G] && keydown[KEY_O] && keydown[KEY_D])
	{
		ClearKeys();
		ExpWin(20, 1);
		if (cheatmode ^= true)
		{
			Print("God mode enabled");
		}
		else
		{
			Print("God mode disabled");
		}
		Get();	// wait for a keypress (with animated cursor)
		RF_ForceRefresh();
		// BUG: timing gets messed up here!
	}
	else if (K13_ActionDown(K13_KEY_STATUS))
	{
		PauseSound();
		ShowStatusScreen();
		ContinueSound();
	}
#else
	else if (K13_ActionDown(K13_KEY_STATUS))
	{
		ShowStatusScreen();
	}
#endif
}


/*
=====================
=
= Quit
=
=====================
*/

void Quit(char *error)
{
	// change to text mode (and clear the screen):
	_AX = 3;
	geninterrupt(0x10);

	if (!*error)
	{
		SaveCtrls();
	}
	else
	{
		puts(error);
	}

	if (KBDstarted)
	{
		ShutdownKbd();
	}
	if (SNDstarted)
	{
		ShutdownSound();
	}

#if VERSION >= VER_134
	if (!*error)
	{
		clrscr();
		movedata(FP_SEG(endscreen), FP_OFF(endscreen)+7, 0xB800, 0, 4000);
		gotoxy(1, 20);
		exit(0);
	}
	// BUG: version 1.34 doesn't actually exit to DOS here when an error message
	// was passed to the Quit function. That's NOT how this was supposed to work.
#else
#if VERSION < VER_100
	if (!levelnum)
#elif VERSION <= VER_120
	if (!*error && !levelnum)
#else
	if (!*error)
#endif
	{
		movedata(FP_SEG(endscreen), FP_OFF(endscreen)+7, 0xB800, 0, 4000);
	}
	gotoxy(1, 23);
	exit(0);
#endif
}


/*
=====================
=
= main
=
=====================
*/

#if VERSION == VER_130
#define MAINARGS void	// v1.3 doesn't use any parameters (neither "/LEVEL" nor "/k")
#else
#define MAINARGS Sint16 argc, char **argv
#endif

void main(MAINARGS)
{
#ifdef K13_PORT
	{
		/* fill the game-data tables from the user's own exe before ANY
		   code (SoundData, tile info, texts) can look at them */
		extern void K13_RipTables(void);
		K13_RipTables();
	}
#endif
	Sint16 i;
	Sint16 joyX, joyY;
	
#if VERSION == VER_132
	{
		extern char far introscn[];
		
		movedata(FP_SEG(introscn), FP_OFF(introscn)+7, 0xB800, 0, 4000);
		gotoxy(1, 21);
		puts("Press a key:");
		if (bioskey(1))	// if a key was pressed
		{
			bioskey(0);	// remove key from input buffer
		}
		bioskey(0);	// wait for next keypress
		gotoxy(1, 21);
	}
#endif

#if VERSION < VER_134
	strcpy(_extension, EXTENSION);
	puts(LOADMSG);
#else
	clrscr();
	textbackground(CYAN);
	textcolor(BLACK);
	strcpy(_extension, EXTENSION);
	cprintf(LOADMSG"\r\n\n");
	textbackground(BLACK);
	// Note: This code has now set both the text color and the background color
	// to black, which would make the text invisible on the screen. But these
	// colors aren't used by puts, which means the text messages following below 
	// will still be visible at startup.
#endif

#if VERSION >= VER_100
	ReadJoystick(1, &joyX, &joyY);
	if (joyX < 500)
	{
		puts("Joystick detected");
		joystickok = true;
	}
	else
	{
		puts("Joystick not detected");
		joystickok = false;
	}
#endif

#if VERSION <= VER_120
	if (argc > 1 && !strcmp(strupr(argv[1]), "/LEVEL"))
	{
		char filename[20] = "";
		
		strcpy(filename, "TEDLEVEL.");
		strcat(filename, _extension);
		LoadFile(filename, (void*)&levelnum);
		
		// Note: It might be more useful to use the following line of code
		// instead of the code above to make playtesting easier:
		
		//levelnum = atoi(argv[2]);
		
		// This would allow you to simply type "KEEN1 /LEVEL 1" at the DOS
		// prompt to playtest level 1 of Keen 1. This should be a lot easier
		// to work with than having to create a TEDLEVEL.CK? file containing
		// the desired level number.
	}
	else
	{
		levelnum = 0;
	}
#endif

#if (VERSION != VER_130) && (!defined OLDKEYBOARD)
	passtobios = true;
	if (argc > 1 && (argv[1][1] == 'K' || argv[1][1] == 'k'))
	{
		passtobios = false;
		puts("Keystrokes will not be passed to bios");
	}
#endif

	videocard = VideoID();
#if VERSION < VER_100
	if (videocard != EGAcard && videocard != VGAcard)
	{
		puts("Sorry, you need an EGA or VGA graphic card to play Commander Keen.");
		puts("Buy one!");
		exit(1);
	}
#else
	if (videocard == EGAcard)
	{
		puts("EGA card detected");
	}
	else if (videocard == VGAcard)
	{
		puts("VGA card detected");
	}
	else
	{
		puts("Hey, I don't see an EGA or VGA card here!  Do you want to run the program ");
		puts("anyway (Y = go ahead, N = quit to dos) ?");
		ClearKeys();
		i = toupper(NoBiosKey(0) & 0xFF);	//BUG: keyboard services haven't been started yet! (must use bioskey instead of NoBiosKey)
		if (i != 'Y')
		{
			exit(1);	
		}
	}
#endif

#if (VERSION > VER_130) && (defined USE_LZW)
	puts("Decompressing graphics, this may take some time...");
#endif
	LoadGraphics();

	for (i=0; i<numtiles; i++)
	{
		switch (nexttile[i])
		{
		case 1:
			tile_anim0[i] = tile_anim1[i] = tile_anim2[i] = tile_anim3[i] = (i << 5);
			break;

		case 2:
			tile_anim0[i] = tile_anim2[i] = (i << 5);
			tile_anim1[i] = tile_anim3[i] = (i << 5) + 0x20;
			i++;
			tile_anim0[i] = tile_anim2[i] = (i << 5);
			tile_anim1[i] = tile_anim3[i] = (i << 5) - 0x20;
			break;

		case 4:
			tile_anim0[i] = (i << 5);
			tile_anim1[i] = (i << 5) + 0x20;
			tile_anim2[i] = (i << 5) + 0x40;
			tile_anim3[i] = (i << 5) + 0x60;
			i++;
			tile_anim0[i] = (i << 5);
			tile_anim1[i] = (i << 5) + 0x20;
			tile_anim2[i] = (i << 5) + 0x40;
			tile_anim3[i] = (i << 5) - 0x20;
			i++;
			tile_anim0[i] = (i << 5);
			tile_anim1[i] = (i << 5) + 0x20;
			tile_anim2[i] = (i << 5) - 0x40;
			tile_anim3[i] = (i << 5) - 0x20;
			i++;
			tile_anim0[i] = (i << 5);
			tile_anim1[i] = (i << 5) - 0x60;
			tile_anim2[i] = (i << 5) - 0x40;
			tile_anim3[i] = (i << 5) - 0x20;
			break;
		}
	}

#ifdef SOUNDSLINKED
	{
		extern char far _sounds[];
		SoundData = _sounds;
	}
#else
	strcpy(str, "SOUNDS.");
	strcat(str, _extension);
	SoundData = bloadin(str);
#endif

	InitRndT(true);
	InitRnd(true);

	StartupSound();
	SNDstarted = true;

#ifdef OLDKEYBOARD
	SetupKBD();
#else
	StartupKbd();
#endif
	KBDstarted = true;

	LoadCtrls();
	playermode[1] = keyboard;	// always start in keyboard mode (in case joystick is no longer present, I guess)

	levelheader = (LevelDef far *)paralloc(BIGBUFFERSIZE);
#if VERSION <= VER_100
	picbuf = (Uint8 far *)paralloc(0x8000);
#endif
	screencenterx = SCREENWIDTH/2-1;
	cyclespeed = 7;	// this value is never actually used (see MenuLoop and WorldMap)
	timecount = lasttimecount = 0;

	DemoLoop();
}
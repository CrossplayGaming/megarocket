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
#pragma inline	// ErrorHandler uses inline assembly
#endif
#include "KEENDEF.H"

/*
==============================================================================

                            INITIALIZED VARIABLES

==============================================================================
*/

warptype warpspots[] =
{
	{28*TILEGLOBAL,  6*TILEGLOBAL, 1},
	{36*TILEGLOBAL,  5*TILEGLOBAL, 1},
	{62*TILEGLOBAL, 37*TILEGLOBAL, 0}
};

boolean showIntro = true;

char helpfile[13] = "HELPTEXT.";
#if VERSION >= VER_100
char endfile[13] = "ENDTEXT.";
#endif
char storyfile[13] = "STORYTXT.";
#if VERSION >= VER_100
char previewfile[13] = "PREVIEWS.";
#endif


#if VERSION < VER_100
//
// The following arrays define the animation that plays in the beta before the
// story text is shown. For whatever reason, this animation was removed from
// the final release version, along with the code that was used to interpret
// the animation data. Maybe the developers decided that writing the animations
// (the game over sequence in Keen 2 and all ending sequences) directly in C
// code was faster and more flexible than defining an animation "script" and
// interpreting it. The animations in the final game use several features that
// were not implemented in the beta's PlayAnimation() function, like scrolling
// the screen and changing the palette.
//
Sint8 movewest[] = {west, nodir+1};
Sint8 dontmove[] = {nodir+1};
Sint8 movenorthwest[] = {northwest, nodir+1};

#define ID 16

Sint16 storyanim[] =
{
	1, 330, 145, 4, 2, VORTLEFT1SPR, VORTLEFT2SPR, VORTLEFT3SPR, VORTLEFT4SPR, (Sint16)&movewest, ID,
	3, 30,	// animate and move for 30 frames
	2, 5, ID, 4, VORTSTAND1SPR,
	2, 5, ID, 5, VORTSTAND2SPR,
	2, 5, ID, 6, VORTSTAND1SPR,
	2, 5, ID, 7, VORTSTAND2SPR,
	2, 5, ID, 8, (Sint16)&dontmove,
	2, 3, 30,	// wait 30 frames
	3, 30,	// animate and move for 30 frames
	2, 3, 30,	// wait 30 frames
	2, 5, ID, 4, VORTLEFT1SPR,
	2, 5, ID, 5, VORTLEFT2SPR,
	2, 5, ID, 6, VORTLEFT3SPR,
	2, 5, ID, 7, VORTLEFT4SPR,
	2, 5, ID, 8, (Sint16)&movewest,
	3, 85,	// animate and move for 85 frames
	2, 0, 6, 8, 347,	// replace tile at X=6, Y=8 with tile 347
	2, 4, GOTITEMSND,
	2, 3, 30,	// wait 30 frames
	3, 23,	// animate and move for 23 frames
	2, 0, 4, 9, 348,	// replace tile at X=4, Y=9 with tile 348
	2, 4, GOTITEMSND,
	2, 3, 30,	// wait 30 frames
	3, 10,	// animate and move for 10 frames
	2, 0, 3, 8, 346,	// replace tile at X=3, Y=8 with tile 346
	2, 4, GOTITEMSND,
	2, 3, 30,	// wait 30 frames
	3, 3,	// animate and move for 3 frames
	2, 0, 2, 9, 349,	// replace tile at X=2, Y=9 with tile 349
	2, 4, GOTITEMSND,
	2, 3, 30,	// wait 30 frames
	2, 5, ID, 2, 6,	// set speed to 6
	2, 5, ID, 8, (Sint16)&movenorthwest,
	3, 40,	// animate and move for 40 frames
	2, 3, 50,	// wait 50 frames
	0	// end of animation
};

#undef ID

#endif

/*
==============================================================================

                           UNINITIALIZED VARIABLES

==============================================================================
*/


Sint16 infoBlockMask;
linetype *textLineOffsets;
char huge *textdataPtr;
Sint16 textWindowX;
Sint16 textWindowMinY;
Sint16 textVisibleLines;
Sint16 textWindowMaxY;

#if (EPISODE == 3)
Sint32 messiexmove, messieymove;
#endif

Sint32 worldkeenx, worldkeeny;

#if (EPISODE == 3)
Sint32 messiex, messiey, messiedummy;
#endif

Sint32 worldCamX, worldCamY;
char huge *storytxtPtr;

#if (EPISODE == 3)
Sint16 messiecount;
#endif

entrancetype entrances[NUMLEVELS];
linetype line_offsets[MAXTEXTLINES];
boolean restoredGame;
char huge *helptextPtr;

#if (EPISODE == 3)
Sint16 messieshape, messiecooldown;
#endif

gametype gamestate;

#if (EPISODE == 3)

warptype warps[NUMWARPS];
Sint16 messieoldtilex, messieoldtiley;
Sint16 messiestate;

#endif

Sint32 oldx, oldy;
boolean canSave;
highscoretype highscores;

#if VERSION >= VER_100
char huge *previewsPtr;
char huge *endtextPtr;
boolean forcemenu;
#endif

#if VERSION == VER_100
void interrupt (*olderror)();
#endif

/*
==============================================================================

                              IMPLEMENTATION

==============================================================================
*/


/*
=====================
=
= DemoLoop
=
=====================
*/

void DemoLoop(void)
{
	char scorefile[13] = "SCORES.";
	char names[3][15] = {"Yorpy","Gargile","Zzapp!"};
	Sint16 i;

	strcat(scorefile, _extension);
	strcat(helpfile, _extension);
	strcat(storyfile, _extension);
#if VERSION >= VER_100
	strcat(endfile, _extension);
	strcat(previewfile, _extension);
#endif

#ifndef TEXTSLINKED
	PrepareText(helptextPtr = bloadin(helpfile));
	PrepareText(storytxtPtr = bloadin(storyfile));
#if VERSION >= VER_100
	PrepareText(endtextPtr = bloadin(endfile));
	PrepareText(previewsPtr = bloadin(previewfile));
#endif
#else
	{
		extern char far helptext[];
		extern char far storytxt[];
		extern char far endtext[];
		extern char far previews[];

		PrepareText(helptextPtr = helptext);
		PrepareText(storytxtPtr = storytxt);
		PrepareText(endtextPtr = endtext);
		PrepareText(previewsPtr = previews);
	}
#endif

#if VERSION >= VER_100
#if VERSION == VER_100
	olderror = getvect(0x24);
#endif

	harderr(&ErrorHandler);

	canSave = false;
#endif

	if (access(scorefile, 0) != 0)
	{
		// highscore file doesn't exist, use defaults:
		for (i=0; i<7; i++)
		{
			highscores.scores[i] = 100;
#if VERSION >= VER_100
			highscores._unused[i] = 0;
			highscores.citiesSaved[i] = 0;
#endif
			strcpy(highscores.names[i], names[i%3]);
			highscores.gotJoystick[i] = false;
			highscores.gotBattery[i] = false;
			highscores.gotVacuum[i] = false;
			highscores.gotEverclear[i] = false;
		}
		SaveFile(scorefile, (char huge *)&highscores, sizeof(highscores));
	}
	else
	{
		// highscore file exists, read it:
		LoadFile(scorefile, (char huge *)&highscores);
	}

	FadeOut();	// fade out the "one moment" pic

	do
	{
		MenuLoop();
		WorldMap();
	} while (true);
}


/*
=====================
=
= ErrorHandler
=
=====================
*/

#if VERSION >= VER_100
Sint16 ErrorHandler(void)
{
	enum {IGNORE=0, RETRY, ABORT};

	Sint16 scan, videomode;
	Sint32 orgx, orgy;
	Uint8 palette[17] = {0, 1, 2, 3, 4, 5, 6, 7, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 3};

	orgx = originx;
	orgy = originy;
	TILE_ALIGN(originx);
	TILE_ALIGN(originy);

	// get video mode:
	asm	mov	ah, 0Fh;
	asm	int	10h;
	asm	xor	ah, ah;
	asm	mov	videomode, ax;

	if (videomode == 0xD)	// 320x200 (16 colors) graphics mode
	{
		RF_Refresh();
		DrawWindow(4, 0, 43, 5);
		Print("DISK ERROR!  I am having some problems\n");
		Print("accessing the disk drive. Put the disk\n");
		Print("back in (if it's out) and press a key\n");
		Print("to retry, or ESC to abort:");

		// apply palette (in case screen was faded out):
		_ES = FP_SEG(&palette);
		_DX = FP_OFF(&palette);
		_AX = 0x1002;
		geninterrupt(0x10);

		scan = Get();

		originx = orgx;
		originy = orgy;
		RF_Refresh();
	}
	else	// assuming we're in text mode
	{
#if VERSION <= VER_100
		printf("DISK ERROR!  I am having some problems\n");
		printf("accessing the disk drive. Please reset\n");
		printf("your computer, because things might not\n");
		printf("work correctly now.");
		
		setvect(0x24, olderror);
		// BUG: interrupt handlers for timer (sound) and keyboard haven't been
		// restored when this code aborts, leaving the system in a bad state.
#else
		printf("DISK ERROR!  I am having some problems\n");
		printf("accessing the disk drive.\n");

		// shut down subsystems for a clean abort:
		if (KBDstarted)
		{
			ShutdownKbd();
		}
		if (SNDstarted)
		{
			ShutdownSound();
		}
#endif

		hardresume(ABORT);
	}

	if ((scan & 0xFF) != CHAR_ESCAPE)	// didn't hit Escape?
	{
		hardresume(RETRY);
	}
	else
	{
		// change to text mode (and clear screen):
		_AX = 3;
		geninterrupt(0x10);

#if VERSION <= VER_100
		printf("Please reset your computer. Programs will not load correctly now.\n");
		
		setvect(0x24, olderror);
		// BUG: interrupt handlers for timer (sound) and keyboard haven't been
		// restored when this code aborts, leaving the system in a bad state.
#else
		printf("Aborting.\n");

		// shut down subsystems for a clean abort:
		if (KBDstarted)
		{
			ShutdownKbd();
		}
		if (SNDstarted)
		{
			ShutdownSound();
		}
#endif

		hardresume(ABORT);
	}
	return RETRY;
}
#endif

/*
==============================================================================

                           WORLD MAP ROUTINES

==============================================================================
*/


/*
=====================
=
= WorldMap
=
=====================
*/

void WorldMap(void)
{

	objtype *ob;
	Sint16 i;
	Sint16 exitcode;
	Sint16 saved;
	Sint16 y;
	ControlStruct ctrl;

	exitcode = ex_nothing;
	ClearKeys();
	RF_ForceRefresh();
	ReadLevel(WORLDMAP);

#if (EPISODE == 3)
	// find a place to spawn Messie:
	for (y = 0; y < mapheight; y++)
	{
		// look for a Messie path in the middle of the current map row:
		if (GETTILE(mapwwide/2, y, 1) == 0x2000)
		{
			messiecooldown = messiestate = 0;
			messieoldtilex = mapwwide/2;
			messieoldtiley = y;
			messiexmove = -MESSIESPEED*PIXGLOBAL;
			messieymove = 0;
			messiex = TILE_TO_GLOBAL(messieoldtilex);
			messiey = TILE_TO_GLOBAL(messieoldtiley);
			messieshape = MESSIELD1SPR;
			messiecount = MESSIEMOVES;
			break;
		}
	}
#endif

	if (!restoredGame)
	{
		GetPlayerPosition(&gamestate.worldx, &gamestate.worldy);
		gamestate.worldoriginx = gamestate.worldx - 9*TILEGLOBAL;
		gamestate.worldoriginy = gamestate.worldy - 3*TILEGLOBAL;
		gamestate.score = 0;
	}
	worldCamX = gamestate.worldoriginx;
	worldCamY = gamestate.worldoriginy;
	worldkeenx = gamestate.worldx;
	worldkeeny = gamestate.worldy;
	infoBlockMask = 0x8000;
#if (VERSION <= VER_110)
	lastextra = (gamestate.score / EXTRASCORE);	// doesn't work for scores >= EXTRASCORE
#else
	lastextra = (gamestate.score / EXTRASCORE) * EXTRASCORE;
#endif
	resetgame = false;
	EGApage = 0;
	cyclespeed = 3;

	do
	{
		ob = &objlist[0];
		ob->xmove = 0;
		ob->ymove = 0;
		ob->xspeed = 0;
		ob->yspeed = 0;
		ob->shapenum = MAPKEEND1SPR;

		LevelNumber = 0;
		ReadLevel(WORLDMAP);
		ScanWorldMap();

		// for all completed levels: place "done" tiles on the map and remove info values:
		for (i = 0; i < NUMLEVELS; i++)
		{
			Sint16 x, y;

			x = entrances[i].x;
			y = entrances[i].y;
			if (gamestate.leveldone[i])
			{
				switch (entrances[i].type)
				{
				case 0:	// single-tile level entrance:
					// erase level number
					SETTILE(x, y, 1, 0);
					// place "done" tile
#if (EPISODE != 3)
					SETTILE(x, y, 0, 77);
#else
					SETTILE(x, y, 0, 56);
#endif
					break;

				case 1:	// 2x2 tiles level entrance:
					// erase level numbers
					SETTILE(x,   y,   1, 0);
					SETTILE(x+1, y,   1, 0);
					SETTILE(x,   y+1, 1, 0);
					SETTILE(x+1, y+1, 1, 0);
					// place "done" tiles
#if (EPISODE != 3)
					SETTILE(x,   y,   0, 78);
					SETTILE(x+1, y,   0, 79);
					SETTILE(x,   y+1, 0, 80);
					SETTILE(x+1, y+1, 0, 81);
#else
					SETTILE(x,   y,   0, 52);
					SETTILE(x+1, y,   0, 53);
					SETTILE(x,   y+1, 0, 54);
					SETTILE(x+1, y+1, 0, 55);
#endif
				}
			}
		}

		ob->x = worldkeenx;
		ob->y = worldkeeny;
		originx = worldCamX;
		originy = worldCamY;
		RF_Clear();
		RF_Refresh();
		RF_Refresh();

#if VERSION <= VER_120
		if (!levelnum)
		{
#endif

			if (exitcode == ex_nothing)
			{
				ShowLives();
			}

			if (exitcode < ex_warped)
			{
				FadeIn();
			}

			if (exitcode == ex_nothing)
			{
				// "Keens left" window is being shown, so wait
				// for 60 VBLs or until a key/button is pressed.
				ClearKeys();
				for (i=0; i<60; i++)
				{
					WaitVBL(1);
					ctrl = ControlPlayer(1);
					if (ctrl.button1 || ctrl.button2 || NoBiosKey(1))
						break;
				}

				// wait until buttons are no longer pressed:
				do
				{
					ctrl = ControlPlayer(1);
				} while (ctrl.button1 || ctrl.button2);
			}

			ClearKeys();
			RF_ForceRefresh();	// to erase the "Keens left" window
			canSave = true;

			do
			{
				Sint16 anim;	// never properly initialized but that doesn't matter; only used in Keen 3

				RF_Clear();
#if (EPISODE == 3)
				UpdateMessie(ob);
#endif
				ControlMapKeen(ControlPlayer(1), ob);
#if (EPISODE == 3)
				RF_PlaceSprite(messiex, messiey, messieshape + (anim & 2)/2);
#endif
				RF_Refresh();

				HandleUserKeys();

				// save positions in case we're about to enter a level or save the game:
				worldkeenx = ob->x;
				worldkeeny = ob->y;
				worldCamX = originx;
				worldCamY = originy;

				DoFkeys();

				if (keydown[KEY_SPACE])	// this is redundant, HandleUserKeys() also handles this
				{
					ShowStatusScreen();
				}

#if VERSION < VER_100
				if (resetgame)
				{
					FadeOut();
					return;
				}
#else
				if (resetgame)
				{
					CheckHighScore();
					return;
				}
#endif

#if (VERSION > VER_110)
				anim++;	// for Keen 3 only
#endif
			} while (!LevelNumber);

			// Note: 'LevelNumber' could have the highest bit set if MapKeen was
			// touching a blocking level entry point on the world map. That makes
			// it unsafe to use it as an index for the leveldone array. Since the
			// original code was built for 16-bit CPUs and the leveldone array is
			// an array of 2-byte values, it meant that the highest bit of the
			// LevelNumber variable would get shifted out of the 16-bit CPU register
			// when calculating the relative offset for the array element.
			//
			// When you port this code to a different system (or when you change
			// the leveldone array into an array of bytes) you will need to mask
			// off the bit before accessing the array. The easiest way to do this
			// is to use the following line of code:
			
			// LevelNumber &= 0xFF;

#if VERSION >= VER_100
			canSave = false;
#endif
			
#if VERSION <= VER_120
		}
		else
		{
			LevelNumber = levelnum;
		}
#endif
			
		if (!gamestate.leveldone[LevelNumber-1])	// potentially unsafe
		{
			// Keen is entering a level
#if VERSION < VER_100
			canSave = false;
#endif
			PlaySound(WLDENTERSND);
#if VERSION < VER_100
			exitcode = LevelLoop(LevelNumber);	// BUG: doesn't mask off the blocking bit
#else
			exitcode = LevelLoop(LevelNumber & 0xFF);	// play that level
#endif

			if (resetgame)
			{
				resetgame = false;
#if VERSION < VER_100
				FadeOut();
				WaitEndSound();
#endif
				CheckHighScore();
				return;
			}
			else if (exitcode != ex_nothing)
			{
#if VERSION <= VER_120
				if (levelnum)
				{
					Quit("");
				}
#endif
				switch (exitcode)
				{
				case ex_completed:
					gamestate.leveldone[LevelNumber-1] = true;	// potentially unsafe
					break;

#if (EPISODE == 1)
				case ex_warped:
					WarpToSecretLevel();
					break;

#elif (EPISODE == 2)
				case ex_tantalus:
					// player activated a tantalus switch -- instant GAME OVER
					FadeOut();	// BUG: screen is already faded out
					TheEarthExplodes();
					CheckHighScore();
					return;
#endif
				}

#if (EPISODE == 1)
				if (gamestate.gotJoystick && gamestate.gotBattery && gamestate.gotVacuum && gamestate.gotEverclear)
#elif (EPISODE == 2)
				for (saved = 0, i = 0; i < NUMCITIES; i++)
				{
					saved += gamestate.citySaved[i];
				}
				if (saved == NUMCITIES)
#elif (EPISODE == 3)
				if ((LevelNumber & 0xFF) == 16)
#endif
				{
					DoFinale();
#if VERSION >= VER_100
					CheckHighScore();
					return;
#endif
				}
			}
			else	// exit code ex_nothing means Keen has died in the level
			{
				gamestate.lives--;
			}
		}
	} while (gamestate.lives > -1);

	// player ran out of lives -- GAME OVER:
	WaitEndSound();
#if (EPISODE == 2)
	TheEarthExplodes();
#elif VERSION >= VER_100
	FadeIn();
#endif

	CheckHighScore();
}


/*
=====================
=
= UpdateMessie
=
=====================
*/

#if (EPISODE == 3)

void UpdateMessie(objtype *keen)
{
	Sint16 x, y, tx, ty, infoval, done;
	ControlStruct ctrl;
	Sint16 xspeeds[9] =
	{
		-MESSIESPEED, 0, MESSIESPEED,
		-MESSIESPEED, 0, MESSIESPEED,
		-MESSIESPEED, 0, MESSIESPEED
	};
	Sint16 yspeeds[9] =
	{
		-MESSIESPEED, -MESSIESPEED, -MESSIESPEED,
		0, 0, 0,
		MESSIESPEED,  MESSIESPEED, MESSIESPEED
	};
	Sint16 messieshapes[9] =	// just Messie
	{
		MESSIEUL1SPR, MESSIEUL1SPR, MESSIEUR1SPR,
		MESSIELD1SPR, MESSIELD1SPR, MESSIERD1SPR,
		MESSIELD1SPR, MESSIERD1SPR, MESSIERD1SPR
	};
	Sint16 kessieshapes[9] =	// Keen riding on Messie's back
	{
		KESSIEUL1SPR, KESSIEUL1SPR, KESSIEUR1SPR,
		KESSIELD1SPR, KESSIELD1SPR, KESSIERD1SPR,
		KESSIELD1SPR, KESSIERD1SPR, KESSIERD1SPR
	};

	if (messiecount <= MESSIEMOVES)
	{
		messiex += messiexmove;
		messiey += messieymove;
	}

	// select the correct sprite for the current state and direction of Messie:
	for (x = 0; x < 9; x++)
	{
		if (xspeeds[x] << G_P_SHIFT == messiexmove && yspeeds[x] << G_P_SHIFT == messieymove)
		{
			if (messiestate == 0)
				messieshape = messieshapes[x];	// just Messie
			else
				messieshape = kessieshapes[x];	// Keen riding Messie
			break;
		}
	}
	// BUG: The shape should be updated at the end of this routine to avoid
	// situations where Messie with Keen on its back and the regular Keen
	// are both visible at the same time.

	if (--messiecount == 0)
	{
		messiecount = MESSIEMOVES;	// move to next tile

		tx = messiex / TILEGLOBAL;
		ty = messiey / TILEGLOBAL;

		for (x = tx-1; x < tx+2; x++)
		{
			done = 0;

			for (y = ty-1; y < ty+2; y++)
			{
				infoval = GETTILE(x, y, 1);
				if ((infoval == 0x2100 || infoval == 0x2000)
					&& (x != tx || y != ty)
					&& (x != messieoldtilex || y != messieoldtiley))
				{
					if (x < tx)
					{
						messiexmove = -MESSIESPEED*PIXGLOBAL;
					}
					else if (x > tx)
					{
						messiexmove = MESSIESPEED*PIXGLOBAL;
					}
					else
					{
						messiexmove = 0;
					}

					if (y < ty)
					{
						messieymove = -MESSIESPEED*PIXGLOBAL;
					}
					else if (y > ty)
					{
						messieymove = MESSIESPEED*PIXGLOBAL;
					}
					else
					{
						messieymove = 0;
					}

					messieoldtilex = tx;
					messieoldtiley = ty;

					// check if new spot is a seaweed spot:
					if (infoval == 0x2100)
					{
						messiecount = 130;	// stop moving for a while
					}

					done++;	// also break the x loop
					break;
				}
			}

			if (done != 0)
			{
				break;
			}
		}
	}

	// if Keen is riding Messie:
	if (messiestate != 0)
	{
		Sint16 dirtilex[8] = {0, 1, 1, 1, 0, -1, -1, -1};
		Sint16 dirtiley[8] = {-1, -1, 0, 1, 1, 1, 0, -1};

		ctrl = ControlPlayer(1);
		// check if there is a shore in the direction the player is trying to move to:
		// BUG: This code should only be executed when ctrl.dir < nodir
		// to stay within array bounds
		if (GETTILE(messiex/TILEGLOBAL + dirtilex[ctrl.dir], messiey/TILEGLOBAL + dirtiley[ctrl.dir], 1) == 0x2200)
		{
			messiestate = 0; // Keen is no longer riding Messie
			keen->x = messiex + TILE_TO_GLOBAL(dirtilex[ctrl.dir]);
			keen->y = messiey + TILE_TO_GLOBAL(dirtiley[ctrl.dir]);
			messiecooldown = 30;
		}

		// scroll the screen if necessary:
		if (messiexmove > 0 && messiex - originx > 11*TILEGLOBAL)
		{
			originx += messiexmove;
			if (originx > originxmax)
			{
				originx = originxmax;
			}
		}
		else if (messiexmove < 0 && messiex - originx < 9*TILEGLOBAL)
		{
			originx += messiexmove;
			if (originx < originxmin)
			{
				originx = originxmin;
			}
		}
		if (messieymove > 0 && messiey - originy > 7*TILEGLOBAL)
		{
			originy += messieymove;
			if (originy > originymax)
			{
				originy = originymax;
			}
		}
		else if (messieymove < 0 && messiey - originy < 3*TILEGLOBAL)
		{
			originy += messieymove;
			if (originy < originymin)
			{
				originy = originymin;
			}
		}
	}
}

#endif


/*
=====================
=
= ScanWorldMap
=
=====================
*/

void ScanWorldMap(void)
{
	Sint16 i, x, y, infoval;

	// "clear" entrance array:
	for (i = 0; i < NUMLEVELS; i++)
	{
#if VERSION <= VER_110
		entrances[infoval].x = 0;	// BUG: wrong index variable -- will cause memory corruption!
#else
		entrances[i].x = 0;
#endif
	}
#if (EPISODE == 3)
	// "clear" teleporter array:
	for (i = 0; i < NUMWARPS; i++)
	{
		warps[i].tag = 0;	// Note: this value is set but never used in Keen 3
	}
#endif

	// find all level entrances (and teleporters):
	for (y = 0; y < mapheight; y++)
	{
		for (x = 0; x < mapwwide; x++)
		{
#if VERSION <= VER_100
			infoval = GETTILE(x, y, 1) & 0x7F;	// masks off way too many bits and would cause conflicts with the teleporters in Keen 3
#else
			infoval = GETTILE(x, y, 1) & 0x7FFF;
#endif
#if (EPISODE == 3)
			if ((infoval & 0xF00) == 0xF00)
			{
				Sint16 index;

				index = (infoval & 0xF0) >> 4;
				warps[index].tag = infoval & 0xF;	// Note: this value is set but never used in Keen 3
				warps[index].x = x;
				warps[index].y = y;
			}
#endif

#if 1
#if VERSION <= VER_100
			if (infoval && entrances[infoval-1].x == 0)	// BUG: infoval must be <= NUMLEVELS to avoid memory corruption!
#else
			if (infoval > 0 && infoval < 0x100 && entrances[infoval-1].x == 0)	// BUG: infoval must be <= NUMLEVELS to avoid memory corruption!
#endif
#else
			if (infoval > 0 && infoval <= NUMLEVELS && entrances[infoval-1].x == 0)	// bug-fixed version
#endif
			{
				entrances[infoval-1].x = x;
				entrances[infoval-1].y = y;
				entrances[infoval-1].type = 0;

				// check if this is a 2x2 level entrance:
#if VERSION <= VER_100
				if ((GETTILE(x+1, y, 1) & 0x7F) == infoval)	// masks off way too many bits and would cause conflicts with the teleporters in Keen 3
#else
				if ((GETTILE(x+1, y, 1) & 0x7FFF) == infoval)
#endif
				{
					x++;
					entrances[infoval-1].type = 1;
				}
			}
		}
	}
}

/*
==============================================================================

                             FINALE ROUTINES

==============================================================================
*/

#if VERSION >= VER_100

/*
=====================
=
= EraseWindow
=
=====================
*/

void EraseWindow(void)
{
	CharBar(win_xl, win_yl, win_xh, win_yh, 0);	// fill with black char tiles
}


/*
=====================
=
= TypeText
=
=====================
*/

void TypeText(char *text)
{
	char str[2];
	Sint16 i;

	str[1] = 0;	// terminating 0
	for (i=0; strlen(text)>i; i++)
	{
		str[0] = text[i];
		Print(str);
		WaitVBL(6);
	}
}
#endif


/*
=====================
=
= DoFinale
=
=====================
*/

#if (EPISODE == 1)

void DoFinale(void)
{
#if VERSION < VER_100

	ExpWin(20, 5);
	Print("YES! YOU MADE IT!\n");
	Print("press a key:");
	Ack();
	
#else
	
	typedef struct
	{
		Sint16 x, y;
	} vector;

	Sint16 i;
	Sint32 shipx, shipy;
	Sint32 oldx, oldy;
	vector shipspeeds1[15] =	// leaving Mars
	{
		{0, -3},
		{0, -3},
		{0, -3},
		{0, -3},
		{0, -3},
		{0, -3},
		{0, -3},
		{0, -3},
		{0, -3},
		{0, -3},
		{3, -3},	// BUG? movement ends here (sum is 0)
		{3, -2},
		{3, -1},
		{3, 0},
		{0, 0}	// intended end marker
	};
	vector shipspeeds2[43] =	// from Earth to Mothership
	{
		{-3, -3},
		{-3, -3},
		{-3, -3},
		{-3, -3},
		{-3, -3},
		{-3, -3},
		{-3, -3},
		{-3, -3},
		{-3, -2},
		{-3, -2},
		{-3, -2},
		{-3, -2},
		{-3, -2},
		{-3, -2},
		{-3, -2},
		{-3, -2},
		{-3, -1},
		{-3, -1},
		{-3, -1},
		{-3, -1},
		{-3, -1},
		{-3, -1},
		{-3, -1},
		{-3, -1},
		{-3, 0},
		{-3, 0},
		{-3, 0},
		{-3, 0},
		{-3, 0},
		{-3, 0},
		{-3, 0},
		{-3, 1},
		{-3, 1},
		{-3, 2},
		{-3, 2},
		{-4, 2},
		{-4, 2},
		{-4, 2},
		{-4, 2},
		{-4, 3},
		{-3, 3},	// BUG? movement ends here (sum is 0)
		{-2, 3},
		{0, 0}	// intended end marker
	};
	vector shipspeeds3[40] =	// from Mothership to Earth
	{
		{3, -1},
		{3, -1},
		{3, -2},
		{3, -2},
		{3, -2},
		{3, -2},
		{3, -2},
		{3, -2},
		{3, 0},
		{3, 0},
		{3, 0},
		{3, 0},
		{3, 0},
		{3, 0},
		{3, 0},
		{3, 1},
		{3, 1},
		{3, 1},
		{3, 1},
		{3, 1},
		{3, 1},
		{3, 1},
		{3, 1},
		{3, 2},
		{3, 2},
		{3, 2},
		{3, 2},
		{3, 2},
		{3, 2},
		{3, 2},
		{3, 2},
		{2, 2},
		{1, 2},
		{1, 2},
		{1, 2},
		{1, 2},
		{1, 2},
		{1, 2},
		{1, 2},
		{0, 0}	// end marker
	};

	ClearKeys();

	ReadLevel(WORLDMAP);
	originx = 3*TILEGLOBAL;
	originy = 35*TILEGLOBAL;
	RF_ForceRefresh();
	RF_Clear();
	RF_PlaceSprite(13*TILEGLOBAL, 39*TILEGLOBAL, MAPKEENL1SPR);
	RF_Refresh();
	WaitVBL(300);	// wait about 5 seconds while possibly still faded out. WHY?

	DrawWindow(5, 15, 42, 20);
	FadeIn();
	TypeText("Commander Keen returns to the Bean-\n");
	TypeText("with-Bacon Megarocket and quickly\n");
	TypeText("replaces the missing parts. He must\n");
	TypeText("get home before his parents do!\n");

	ReadLevel(ENDINGMAP);	// space level
	WaitVBL(240);	// wait about 4 seconds

	FadeOut();
	originx = originy = 0;
	RF_ForceRefresh();
	RF_Clear();
	RF_Refresh();
	RF_Refresh();
	FadeIn();	// Note: ship sprite hasn't been placed yet and will be missing during the fade

	// ship leaves Mars:
	i = 0;
	shipx = 100*PIXGLOBAL;
	shipy = 80*PIXGLOBAL;
	do
	{
		shipx += shipspeeds1[i].x*(Sint16)PIXGLOBAL;
		shipy += shipspeeds1[i].y*(Sint16)PIXGLOBAL;
		RF_Clear();
		RF_PlaceSprite(shipx, shipy, SMALLSHIP1SPR);
		RF_Refresh();
		WaitVBL(4);
	} while (shipspeeds1[i].x + shipspeeds1[i++].y != 0);

	// ship flies to Earth:
	i = 0;
	do
	{
		shipx += 3*PIXGLOBAL;
		shipy += 1*PIXGLOBAL;
		RF_Clear();
		RF_PlaceSprite(shipx, shipy, SMALLSHIP1SPR);
		RF_Refresh();
	} while (i++ < 20);

	// ship flies to Earth and screen scrolls:
	i = 0;
	do
	{
		originx += 3*PIXGLOBAL;
		originy += 1*PIXGLOBAL;
		shipx += 3*PIXGLOBAL;
		shipy += 1*PIXGLOBAL;
		RF_Clear();
		RF_PlaceSprite(shipx, shipy, SMALLSHIP1SPR);
		RF_Refresh();
	} while (i++ < 200);

	// more flying and scrolling:
	i = 0;
	do
	{
		shipy += 1*PIXGLOBAL;
		if (i < 20)
			originy += 3*PIXGLOBAL;
		RF_Clear();
		RF_PlaceSprite(shipx, shipy, SMALLSHIP1SPR);
		RF_Refresh();
	} while (i++ < 60);

	// show question mark above ship:
	WaitVBL(20);
	i = 0;
	do
	{
		RF_Clear();
		RF_PlaceSprite(shipx, shipy, SMALLSHIP1SPR);
		RF_PlaceSprite(shipx + 6*PIXGLOBAL, shipy - 14*PIXGLOBAL, MARKSPR);
		RF_Refresh();
	} while (i++ < 30);

	// fly towards Mothership:
	i = 0;
	do
	{
		RF_Clear();
		shipx -= 2*PIXGLOBAL;
		RF_PlaceSprite(shipx, shipy, SMALLSHIP2SPR);
		RF_Refresh();
	} while (i++ < 50);

	// show exclamation point above ship:
	i = 0;
	do
	{
		RF_Clear();
		RF_PlaceSprite(shipx, shipy, SMALLSHIP2SPR);
		RF_PlaceSprite(shipx + 6*PIXGLOBAL, shipy - 14*PIXGLOBAL, POINTSPR);
		RF_Refresh();
	} while (i++ < 30);

	// fly back to Earth and land:
	i = 0;
	do
	{
		RF_Clear();
		shipx += shipspeeds3[i].x*(Sint16)PIXGLOBAL;
		shipy += shipspeeds3[i].y*(Sint16)PIXGLOBAL;
		RF_PlaceSprite(shipx, shipy, SMALLSHIP1SPR);
		RF_Refresh();
	} while (shipspeeds3[i].x + shipspeeds3[i++].y != 0);

	WaitVBL(60);
	FadeOut();

	// outside Billy's house at night:
	oldx = originx;
	oldy = originy;
	DrawPicFile("FINALE.CK1");
	DrawWindow(4, 15, 27, 19);
	FadeIn();

	TypeText("Keen makes it home and\n");
	TypeText("rushes to beat his\n");
	TypeText("parents upstairs.");
	WaitVBL(120);

	EraseWindow();
	WaitVBL(60);

	DrawPic(14, 0, WINDONPIC);
	PlaySound(CLICKSND);
	WaitVBL(120);

	DrawPic(14, 0, WINDOFFPIC);
	PlaySound(CLICKSND);
	WaitVBL(300);

	DrawWindow(4, 15, 27, 19);
	TypeText("Shhh, honey...let's\n");
	TypeText("see if little Billy\n");
	TypeText("is asleep.");
	WaitVBL(180);

	EraseWindow();
	WaitVBL(60);

	DrawPic(14, 0, WINDONPIC);
	PlaySound(CLICKSND);
	DrawWindow(4, 15, 27, 20);
	TypeText("Billy...? Are you a--\n");
	Print("WHAT IS THIS ONE-EYED\n");
	Print("GREEN THING IN YOUR\n");
	Print("ROOM!!!!???\n");
	WaitVBL(240);

	EraseWindow();
	DrawWindow(4, 15, 27, 18);
	TypeText("Aw, Mom, can't I\n");
	TypeText("keep him?");
	WaitVBL(180);

	EraseWindow();
	DrawWindow(4, 15, 29, 19);
	TypeText("Well, we'll talk about\n");
	TypeText("that in the morning,\n");
	TypeText("son. You get some rest.");
	WaitVBL(180);

	EraseWindow();
	DrawWindow(4, 15, 27, 17);
	TypeText("OK, Mom. Goodnight.");
	WaitVBL(180);

	DrawWindow(4, 15, 27, 17);
	TypeText("Goodnight, dear.");
	WaitVBL(180);

	EraseWindow();
	WaitVBL(60);

	DrawPic(14, 0, WINDOFFPIC);
	PlaySound(CLICKSND);
	WaitVBL(300);

	DrawPic(14, 0, WINDONPIC);
	DrawWindow(4, 15, 29, 21);
	PlaySound(CLICKSND);
	TypeText("But there is no sleep\n");
	TypeText("for Commander Keen! The\n");
	TypeText("Vorticon Mothership\n");
	TypeText("looms above, ready to\n");
	TypeText("destroy Earth!");
	WaitVBL(300);

	FadeOut();
#if VERSION > VER_100
	ReadLevel(ENDINGMAP);	// reload space level (DrawPicFile trashes the level data!)
#endif
	originx = oldx;
	originy = oldy;
	RF_ForceRefresh();
	RF_Clear();
	RF_PlaceSprite(shipx, shipy, SMALLSHIP2SPR);
	RF_Refresh();
	FadeIn();
	WaitVBL(30);

	// ship flies from Earth to the Mothership:
	i = 0;
	do
	{
		RF_Clear();
		shipx += shipspeeds2[i].x*(Sint16)PIXGLOBAL;
		shipy += shipspeeds2[i].y*(Sint16)PIXGLOBAL;
		RF_PlaceSprite(shipx, shipy, SMALLSHIP2SPR);
		RF_Refresh();
	} while (shipspeeds2[i].x + shipspeeds2[i++].y != 0);

	// turn ship around (docking onto Mothership?)
	RF_Clear();
	RF_PlaceSprite(shipx, shipy, SMALLSHIP1SPR);
	RF_Refresh();
	WaitVBL(60);

	DrawWindow(12, 3, 32, 5);
	TypeText("TO BE CONTINUED....");
	WaitVBL(400);

	// normalize horizontal screen position (for ShowText)
	TILE_ALIGN(originx);
	RF_Refresh();
	RF_Refresh();

#if VERSION > VER_110
	PlaySound(KEENSLEFTSND);
#endif
	ShowText(endtextPtr, 0, 22);
#endif
}

#endif



/*
=====================
=
= WarpToSecretLevel
=
=====================
*/

// Keen 2 and Keen 3 have an empty rountine between TypeText and CheckHighScore.
// That routine is never used in those games, but I assume it's the
// WarpToSecretLevel routine. The DoFinale for Keen 2 and Keen 3 is in the actor
// code file.

void WarpToSecretLevel(void)
{
#if (EPISODE == 1)
	objtype *ob;
	Sint16 i;
	Sint16 tx, ty, anim, tile;
	ControlStruct ctrl;

	ReadLevel(WORLDMAP);
	PlaySound(TELEPORTSND);
	ob = &objlist[0];
	ob->xmove = 0;
	ob->ymove = 0;
	ob->xspeed = 0;
	ob->yspeed = 0;
	ob->shapenum = MAPKEEND1SPR;
	ob->x = oldx = worldkeenx = warpspots[2].x;
	ob->y = oldy = worldkeeny = warpspots[2].y;
	worldCamX = originx = ob->x - 9*TILEGLOBAL;
	worldCamY = originy = ob->y - 3*TILEGLOBAL;

	RF_Clear();
	RF_ForceRefresh();
	RF_Refresh();
	FadeIn();

	tx = ob->x / TILEGLOBAL;
	ty = ob->y / TILEGLOBAL;
	tile = 338;	// teleporter on red ground
	if (warpspots[2].tag)
	{
		tile = 342;	// teleporter on icy ground
	}
	// WARNING: the 'anim' variable is not initialized!

	// animate the teleporter tile:
	for (i=0; i<16; i++)
	{
		RF_Clear();
		RF_ForceRefresh();	// not really necessary here, just makes the refresh take longer
		if (i % 2 == 0)
		{
			if (++anim > 3)
			{
				anim = 0;
			}
		}
		SETTILE(tx, ty, 0, anim + tile);
		RF_Refresh();
	}

	// put regular teleporter tile back on the map:
	tile = 325;	// teleporter on red ground
	if (warpspots[2].tag)
	{
		tile = 99;	// teleporter on icy ground
	}
	SETTILE(tx, ty, 0, tile);

	// wait for the player to stop pressing any buttons, so Keen won't enter the
	// teleporter and teleport away from the secret level after this is done:
	do
	{
		RF_Clear();
		ctrl = ControlPlayer(1);
		RF_PlaceSprite(ob->x, ob->y, ob->shapenum);
		RF_Refresh();

		HandleUserKeys();
		DoFkeys();
	} while (ctrl.button1 || ctrl.button2);

	// these are probably not necessary (already set above) but they don't cause any harm:
	worldCamX = originx;
	worldCamY = originy;
#endif
}


/*
=====================
=
= CheckHighScore
=
=====================
*/

void CheckHighScore(void)
{
	Sint16 i, rank;
	ControlStruct ctrl;
	Sint16 x, y, towait, saved;
	char buf[10];
	char scorefile[13] = "SCORES.";
	char numberstrings[7][7] = {"first", "second", "third", "fourth", "fifth", "sixth", "last"};

	strcat(scorefile, _extension);

	rank = 0;
	for (i=0; i < HIGHSCORE_NUMENTRIES; i++)
	{
		if (highscores.scores[i] < gamestate.score)
		{
			rank = i+1;
			break;
		}
	}

	TILE_ALIGN(originx);
	TILE_ALIGN(originy);
#if VERSION >= VER_100
	RF_ForceRefresh();
	RF_Clear();
#endif
	RF_Refresh();

	if (rank != 0)
	{
		// player made it into the highscores!
		// prepare a text window and draw the GAME OVER pic into that window:
		ExpWin(32, 13);
		x = sx;
		y = sy;
	}
	else
	{
		// player did NOT make it into the highscores
		// make the GAME OVER pic appear in the middle of the screen:
		sx = 7;
		sy = 10;
	}
	DrawPic(sx+9, sy*8, GAMEOVERPIC);
#if VERSION < VER_100
	FadeIn();
#endif
	PlaySound(GAMEOVERSND);

	if (rank--)
	{
		// player made it into the highscores!
		// draw some stuff:
		sx = leftedge = x+1;
		sy = y + 4;
		Print("         SCORE:");
		Print(ltoa(gamestate.score, buf, 10));
		sx = leftedge + 11;
#if (EPISODE == 1)
		if (gamestate.gotJoystick)
		{
			DrawTile(sx, (sy+2)*8 - 4, 448);
		}
		if (gamestate.gotBattery)
		{
			DrawTile(sx+2, (sy+2)*8 - 4, 449);
		}
		if (gamestate.gotVacuum)
		{
			DrawTile(sx+4, (sy+2)*8 - 4, 450);
		}
		if (gamestate.gotEverclear)
		{
			DrawTile(sx+6, (sy+2)*8 - 4, 451);
		}
#elif (EPISODE == 2)
		{
			Sint16 numsaved;

			for (numsaved = i = 0; i < NUMCITIES; i++)
			{
				numsaved += gamestate.citySaved[i];
			}
			sx = leftedge + 6;
			sy += 2;
			itoa(numsaved, buf, 10);
			Print("You saved ");
			if (numsaved == 0)
			{
				Print("no cities!");
			}
			else
			{
				Print(buf);
				if (numsaved > 1)
				{
					Print(" cities!");
				}
				else
				{
					Print(" city!");
				}
			}
			sy -= 2;
		}
#endif
		sx = leftedge;
		sy += 4;
#if VERSION < VER_100
		Print("        CONGRATULATIONS!\n");
		Print("      You got ");
#else
		Print("       CONGRATULATIONS!\n");
		Print("     You got ");
#endif
		Print(numberstrings[rank]);
		Print(" place!\n\n\nEnter your name:");

		// move lower highscore entries down by one:
		for (i = HIGHSCORE_NUMENTRIES-2; i >= rank; i--)
		{
			highscores.scores[i+1] = highscores.scores[i];
#if VERSION >= VER_100
			highscores.citiesSaved[i+1] = highscores.citiesSaved[i];
			highscores._unused[i+1] = highscores._unused[i];
#endif
			highscores.gotJoystick[i+1] = highscores.gotJoystick[i];
			highscores.gotBattery[i+1] = highscores.gotBattery[i];
			highscores.gotVacuum[i+1] = highscores.gotVacuum[i];
			highscores.gotEverclear[i+1] = highscores.gotEverclear[i];
			strcpy(highscores.names[i+1], highscores.names[i]);
		}

		// let user type in a name:
		ClearKeys();
		Input(highscores.names[rank], HIGHSCORE_NAMELENGTH);
		// and fill the remaining parts of the player's highscore entry:
		highscores.scores[rank] = gamestate.score;
		highscores.gotJoystick[rank] = gamestate.gotJoystick;
		highscores.gotBattery[rank] = gamestate.gotBattery;
		highscores.gotVacuum[rank] = gamestate.gotVacuum;
		highscores.gotEverclear[rank] = gamestate.gotEverclear;
#if VERSION >= VER_100
#if VERSION <= VER_110
		for (saved=i=0; i < NUMCITIES-1; i++)	// BUG: doesn't count all cities, but is only used by Keen 1, so it doesn't make a difference
#else
		for (saved=i=0; i < NUMCITIES; i++)
#endif
		{
			saved += gamestate.citySaved[i];
		}
		highscores.citiesSaved[rank] = saved;
		highscores._unused[rank] = gamestate._unused;
#endif

		SaveFile(scorefile, (char huge *)&highscores, sizeof(highscores));
	}

	do
	{
		ctrl = ControlPlayer(1);
	} while (ctrl.button1 || ctrl.button2);
	ClearKeys();

	// if the player didn't get a high score, keep showing the GAME OVER pic
	// for about 6 seconds or until a button/key is hit:
	if (rank < 0)
	{
		for (i = 0; i < 360; i++)
		{
			WaitVBL(1);
			ctrl = ControlPlayer(1);
			if (ctrl.button1 || ctrl.button2 || NoBiosKey(1))
			{
				break;
			}
		}
	}
	
#if VERSION < VER_100
	ClearKeys();
	FadeOut();
#else
	FadeOut();
	ClearKeys();

	ReadLevel(TITLEMAP);	// menu backgrounds
	DrawScoreScreen();
	FadeIn();
	towait = SCREENTIME;	// wait about 17 seconds
	canSave = false;	// because quitting to the title screen from the world map doesn't disable saving

	do
	{
		RF_Clear();
		RF_Refresh();
		ctrl = ControlPlayer(1);

		if (DoFkeys())
		{
			DrawScoreScreen();
		}

		towait = towait - tics;

	} while (!ctrl.button1 && !ctrl.button2 && !NoBiosKey(1) && towait > 0);

	FadeOut();
#endif
}


/*
=====================
=
= ShowLives
=
=====================
*/

void ShowLives(void)
{
	Sint16 i, x, keens;

	ExpWin(16, 4);
	x = sx;
	Print("   Keens Left");
	keens = gamestate.lives;
	if (keens > 6)
	{
		keens = 6;
	}
	for (i = 0; i < keens; i++)
	{
		DrawSprite(x + 2*i + 1, sy*8 + 11, MAPKEEND1SPR*4);	// *4 because each sprite has 4 shifts!
	}
	PlaySound(KEENSLEFTSND);
}


/*
=====================
=
= GetPlayerPosition
=
=====================
*/

void GetPlayerPosition(Sint32 *xglobal, Sint32 *yglobal)
{
	Sint16 x, y, info;

	for (y = 0; y < mapheight; y++)
	{
		for (x = 0; x < mapwwide; x++)
		{
			info = GETTILE(x, y, 1);
			if (info == 255)
			{
				*xglobal = TILE_TO_GLOBAL(x);
				*yglobal = TILE_TO_GLOBAL(y);
				return;
			}
		}
	}
}

/*
==============================================================================

                           MAIN MENU ROUTINES

==============================================================================
*/

enum
{
	mm_NewGame,
	mm_ContinueGame,
	mm_Story,
	mm_AboutID,
	mm_HighScores,
#if VERSION < VER_134
	mm_OrderingInfo,
#endif
#if VERSION >= VER_100
	mm_Previews,
#endif
	mm_RestartDemo,
	NUMMENUITEMS
};

#define MAXMENUPOS (NUMMENUITEMS-1)

/*
=====================
=
= MenuLoop
=
=====================
*/

void MenuLoop(void)
{
	ControlStruct ctrl;
	Sint16 screen, towait;
	Sint16 i;
	boolean startgame;

	// always start with a clean gamestate:
	restoredGame = false;
	gamestate.lives = 4;
	gamestate.ammo = 0;
#if (EPISODE == 1)
	gamestate.gotPogo = false;
#elif (EPISODE == 2)
	gamestate.gotPogo = true;
	gamestate.ammo = 3;
#elif (EPISODE == 3)
	gamestate.gotPogo = true;
	gamestate.ammo = 5;
#endif
	gamestate.gotJoystick = false;
	gamestate.gotBattery = false;
	gamestate.gotVacuum = false;
	gamestate.gotEverclear = false;
	for (i = 0; i < NUMCITIES; i++)
	{
		gamestate.citySaved[i] = false;
	}
	gamestate.keys[0] = false;
	gamestate.keys[1] = false;
	gamestate.keys[2] = false;
	gamestate.keys[3] = false;
	for (i = 0; i < NUMLEVELS; i++)
	{
		gamestate.leveldone[i] = false;
	}
	
#if VERSION <= VER_120
	if (levelnum)
	{
		return;
	}
#endif

	// Note: palette is always faded out when entering this routine

	do
	{
		EGApage = 0;
		cyclespeed = 3;
		RF_ForceRefresh();
		ReadLevel(TITLEMAP);	// menu backgrounds

		// Apogee intro:
		if (showIntro)
		{
			ReadLevel(TITLEMAP);	// redundant!
			originx = X_APOGEE;
			originy = Y_APOGEE;
			RF_ForceRefresh();
			RF_Clear();
			RF_Refresh();
			FadeIn();
			towait = SCREENTIME;
			screen = 4;
			ShowApogeeIntro();
			FadeOut();
			showIntro = false;
		}

		// title screen:
		towait = SCREENTIME;
		screen = 0;
		originx = X_TITLE;
		originy = Y_TITLE;
		RF_ForceRefresh();
		RF_Clear();
		DrawTitleScreen();
		FadeIn();
		ClearKeys();

		do
		{
			ctrl = ControlPlayer(1);
			RF_Clear();
			RF_Refresh();
			if (DoFkeys())
			{
				switch (screen)
				{
				case 0:
					DrawTitleScreen();
					break;

				case 1:
					DrawIdScreen();
					break;

				case 2:
					DrawScoreScreen();
					break;

#if VERSION < VER_134
				case 3:
					DrawOrderingScreen();
					RF_Refresh();
					DrawOrderingScreen();
#endif
				}
			}

			towait = towait - tics;
			if (towait <= 0)
			{
				FadeOut();
				switch (screen)
				{
				case 0:
					originx = X_ID;
					originy = Y_ID;
					DrawIdScreen();
					break;

				case 1:
					originx = X_HIGH;
					originy = Y_HIGH;
					DrawScoreScreen();
					break;

#if VERSION < VER_134
				case 2:
					screen++;
					ShowOrderingScreen(1);
					ctrl = ControlPlayer(1);
					if (NoBiosKey(1) || ctrl.button1 || ctrl.button2)
					{
						towait = SCREENTIME;
						continue;
					}
					FadeOut();
#endif
				}
				towait = SCREENTIME;
				RF_Clear();
				RF_Refresh();

#if VERSION < VER_134
				if (++screen == 4)
#else
				if (++screen == 3)
#endif
				{
					screen = 0;
					originx = X_TITLE;
					originy = Y_TITLE;
					RF_ForceRefresh();
					DrawTitleScreen();
				}
				FadeIn();
			}
#if VERSION < VER_100
		} while (!NoBiosKey(1) && !ctrl.button1 && !ctrl.button2);
#else
		} while (!NoBiosKey(1) && !ctrl.button1 && !ctrl.button2	&& !forcemenu);

		forcemenu = false;
		if (originx != X_TITLE)
		{
			FadeOut();
		}
#endif

		startgame = MainMenuLoop(screen);	// Note: parameter is ignored
	} while (!startgame);

	ClearKeys();
	FadeOut();
}


/*
=====================
=
= MainMenuLoop
=
=====================
*/

#pragma argsused
boolean MainMenuLoop(Sint16 screen)
{
	Sint16 i, anim;
	Sint16 menupos;
	boolean startgame;
	Sint16 c, delay;
	ControlStruct ctrl;

#if VERSION >= VER_100
	do
	{
		if (originx != X_TITLE)
		{
			DrawMainMenuScreen();
			FadeIn();
		}
		else
		{
			DrawMainMenuScreen();
		}
#else
		DrawMainMenu();
#endif
		ClearKeys();
		anim = menupos = 0;
		delay = 20;

		// handle menu navigation:
		do
		{
			for (i = 0; i < 6; i++)
			{
				WaitVBL(1);
				ctrl = ControlPlayer(1);
				if (ctrl.dir != nodir)
				{
					break;
				}
			}
			DrawChar(sx, sy*8, anim+9);	// draw cursor
			if (++anim > 2)
			{
				anim = 0;
			}

			switch (ctrl.dir)
			{
			case north:
				if (menupos != 0)
				{
					menupos--;
					// move up slowly:
					for (i = 0; i < 8; i++)
					{
						DrawChar(sx, sy*8 - i, anim+9);	// draw cursor
						WaitVBL(1);
						DrawChar(sx, sy*8 - i, ' ');	// erase cursor
						if (++anim > 2)
						{
							anim = 0;
						}
					}
				}
				else
				{
					menupos = MAXMENUPOS;
					DrawChar(sx, sy*8, ' ');	// erase cursor
				}
				sy = oldy + menupos;
				DrawChar(sx, sy*8, anim+9);

				while (delay-- && ctrl.dir != nodir)
				{
					ctrl = ControlPlayer(1);
					WaitVBL(1);
				}
				delay = 20;
#if VERSION > VER_130
				ClearKeys();
#endif
				break;

			case south:
				if (menupos < MAXMENUPOS)
				{
					menupos++;
					// move down slowly:
					for (i = 0; i < 8; i++)
					{
						DrawChar(sx, sy*8 + i, anim+9);	// draw cursor
						WaitVBL(1);
						DrawChar(sx, sy*8 + i, ' ');	// erase cursor
						if (++anim > 2)
						{
							anim = 0;
						}
					}
				}
				else
				{
					menupos = 0;
					DrawChar(sx, sy*8, ' ');	// erase cursor
				}
				sy = oldy + menupos;
				DrawChar(sx, sy*8, anim+9);

				while (delay-- && ctrl.dir != nodir)
				{
					ctrl = ControlPlayer(1);
					WaitVBL(1);
				}
				delay = 20;
#if VERSION > VER_130
				ClearKeys();
#endif
				break;

			default:
				WaitVBL(7);
			}

			c = NoBiosKey(1) & 0xFF;

			if (c && playermode[1] != keyboard)	// this seems odd
			{
				ctrl.button1 = true;
			}

			if ((c == ' ' || c == '\r') && playermode[1] == keyboard)
			{
				ctrl.button1 = true;
			}

			if (DoFkeys())
			{
#if VERSION < VER_100
				switch (screen)
				{
				case 0:
					DrawTitleScreen();
					break;
				case 1:
					DrawIdScreen();
					break;
				case 2:
					DrawScoreScreen();
					break;
				case 3:
					DrawOrderingScreen();
					break;
				}
				DrawMainMenuScreen();
#else
				DrawMainMenuScreen();
				sy = oldy + menupos;
#endif
			}
		} while (!ctrl.button1 && !ctrl.button2);

		// the user has selected a menu item!
		ClearKeys();
		WaitVBL(8);

		// Note: 'startgame' might still be uninitialized here!
		switch (menupos)
		{
		case mm_NewGame:
			startgame = true;
			break;

		case mm_ContinueGame:
			startgame = RestoreMenu();
			break;

		case mm_Story:
			startgame = false;
			ShowStoryText();
			break;

		case mm_AboutID:
			startgame = false;
			FadeOut();
			ShowAboutId();
			FadeOut();
			break;

		case mm_HighScores:
			startgame = false;
			FadeOut();
			ShowScoreScreen();
			FadeOut();
			break;

#if VERSION < VER_134
		case mm_OrderingInfo:
			startgame = false;
			FadeOut();
			ShowOrderingScreen(0);
			FadeOut();
			break;
#endif

#if VERSION >= VER_100
		case mm_Previews:
			startgame = false;
			FadeOut();
			Previews();
			FadeOut();
			break;
#endif

		case mm_RestartDemo:
			startgame = false;
			FadeOut();
			break;
		}

#if VERSION >= VER_100
	} while (menupos != mm_RestartDemo && !startgame);
#endif

	if (startgame)
	{
		return true;
	}
	else
	{
		return false;
	}
#undef MAXMENUPOS
}


/*
=====================
=
= DrawMainMenu
=
=====================
*/

void DrawMainMenu(void)
{
#if VERSION < VER_100
	ExpWin(18, 9);
#else
	ExpWin(18, 10);
#endif
	oldx = sx;
	oldy = sy;

	Print("   New Game\n");
	Print("   Continue Game\n");
	Print("   Story\n");
	Print("   About ID...\n");
	Print("   High Scores\n");
#if VERSION < VER_134
	Print("   Ordering Info\n");
#endif
#if VERSION < VER_100
	Print("   Resume Demo\n\n");
#else
	Print("   Previews!\n");
	Print("   Restart Demo\n\n");
#endif
	Print("Use the ");
	switch (playermode[1])
	{
	case keyboard:
		Print("arrows");
		break;

	case mouse:
		Print("mouse");
		break;

	case joystick1:
	case joystick2:
		Print("joystick");
	}
	sx = oldx + 1;
	sy = oldy;
}


/*
=====================
=
= DrawMainMenuScreen
=
=====================
*/

void DrawMainMenuScreen(void)
{
#if VERSION >= VER_100
	originx = X_TITLE;
	originy = Y_TITLE;
	RF_ForceRefresh();
	DrawTitleScreen();
#endif
	uservect = DrawMainMenu;
	RF_Refresh();
	uservect = NULL;
}

#if VERSION <= VER_110
#include "KEENSCRN.C"
#endif
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
=====================
=
= LoadLevel
=
=====================
*/

void LoadLevel(Sint16 number)
{
	Sint16 x, y, infoval;

	ReadLevel(number);

	for (y = 0; y < mapheight; y++)
	{
		for (x = 0; x < mapwwide; x++)
		{
			infoval = GETTILE(x, y, 1);
			switch (infoval)
			{
			case 1:
				SpawnGrunt(x, y);
				break;

			case 2:
				SpawnYouth(x, y);
				break;

			case 3:
				SpawnElite(x, y);
				break;

			case 4:
				SpawnScrub(x, y);
				break;

			case 5:
				SpawnGuard(x, y);
				break;

			case 6:
				SpawnPlatformX(x, y);
				break;

			case 7:
				SpawnSpark(x, y);
				break;

			case 255:
				objlist[0].x = TILE_TO_GLOBAL(x);
				objlist[0].y = TILE_TO_GLOBAL(y) + 8*PIXGLOBAL;
				break;
			}
		}
	}
}

/*
==============================================================================

                           ACTOR SPAWN ROUTINES

==============================================================================
*/


/*
=====================
=
= SpawnGrunt
=
=====================
*/

void SpawnGrunt(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = gruntobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = GruntWalk;
	ob->contact = GruntContact;
	ob->health = 1;

	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -90;
	}
	else
	{
		ob->xspeed = 90;
	}

	ob->shapenum = GRUNTSTAND1SPR;
}


/*
=====================
=
= SpawnYouth
=
=====================
*/

void SpawnYouth(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = youthobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = YouthWalk;
	ob->contact = YouthContact;
	ob->health = 1;	// doesn't matter, youth always dies when hit by any shot

	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -250;
	}
	else
	{
		ob->xspeed = 250;
	}

	ob->shapenum = YOUTHLEFT1SPR;
}


/*
=====================
=
= SpawnElite
=
=====================
*/

void SpawnElite(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = eliteobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = EliteWalk;
	ob->contact = EliteContact;
	ob->health = 2;

	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -100;
	}
	else
	{
		ob->xspeed = 100;
	}

	ob->shapenum = ELITELEFT1SPR;
}


/*
=====================
=
= SpawnScrub
=
=====================
*/

void SpawnScrub(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = scrubobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = ScrubWalkLeft;
	ob->contact = ScrubContact;
	ob->shapenum = SCRUBL1SPR;
}


/*
=====================
=
= SpawnGuard
=
=====================
*/

void SpawnGuard(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = guardobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->xspeed = 100;
	ob->think = GuardMove;
	ob->contact = GuardContact;
	ob->health = 99;	// doesn't matter, guard cannot be killed
	ob->shapenum = GUARDSTAND1SPR;
}


/*
=====================
=
= SpawnPlatformX
=
=====================
*/

void SpawnPlatformX(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = platformobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y) - 4*PIXGLOBAL;
	ob->think = PlatformMove;
	ob->contact = NullContact;
	ob->shapenum = PLATFORM1SPR;
	ob->xspeed = 75;
}


/*
=====================
=
= SpawnSpark
=
=====================
*/

void SpawnSpark(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = sparkobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = SparkThink;
	ob->contact = SparkContact;
	ob->shapenum = SPARK1SPR;
}

/*
==============================================================================

                           VORTICON GRUNT ROUTINES

==============================================================================
*/


/*
=====================
=
= GruntWalk
=
=====================
*/

void GruntWalk(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = GRUNTRIGHT1SPR;
	}
	else
	{
		obon.shapenum = GRUNTLEFT1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 3);

	if (RndT() < tics*2 && lightson)
	{
		obon.yspeed = -Rnd(300);
		obon.think = GruntJump;
	}
	else if (RndT() < tics*2)
	{
		switch (obon.xspeed)
		{
		case -90:
			obon.xspeed = -120;
			break;

		case -120:
			obon.xspeed = -90;
			break;

		case 90:
			obon.xspeed = 120;
			break;

		case 120:
			obon.xspeed = 90;
			break;
		}
	}

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -90;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 90;
	}
	if (!(block & BLOCK_DOWN))
	{
		obon.think = GruntJump;
	}
}


/*
=====================
=
= GruntJump
=
=====================
*/

void GruntJump(void)
{
	Sint16 block;

	// Note: jump sprites are mislabeled (left and right sprites are swapped)!
	if (obon.xspeed > 0)
	{
		obon.shapenum = GRUNTJUMPLSPR;
	}
	else
	{
		obon.shapenum = GRUNTJUMPRSPR;
	}

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_DOWN)
	{
		obon.think = GruntStand;
		obon.temp1 = 0;
	}
	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -90;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 90;
	}
}


/*
=====================
=
= GruntStand
=
=====================
*/

void GruntStand(void)
{
	obon.xspeed = 0;
	obon.shapenum = (((Uint16)timecount >> 5) & 3) + GRUNTSTAND1SPR;
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 >= 80)
	{
		obon.xspeed = 90;
		if (obon.x > objlist[0].x)
		{
			obon.xspeed = -obon.xspeed;
		}
		obon.think = GruntWalk;
		// BUG: xspeed should be set AFTER calling MoveObon()
	}
	DoGravity();
	MoveObon();
}


/*
=====================
=
= GruntContact
=
=====================
*/

void GruntContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj || hit->obclass == enemyshotobj)
	{
		if (--ob->health)
		{
			return;
		}

		PlaySound(VORTSCREAMSND);
		ob->temp1 = 0;
		ob->temp2 = 2;
		ob->shapenum = GRUNTDIE1SPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}

/*
==============================================================================

                          YOUTH (VORTIKID) ROUTINES

==============================================================================
*/


/*
=====================
=
= YouthWalk
=
=====================
*/

void YouthWalk(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = YOUTHRIGHT1SPR;
	}
	else
	{
		obon.shapenum = YOUTHLEFT1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 3);

	if (RndT() < tics*3)
	{
		obon.yspeed = -Rnd(400);
		obon.think = YouthJump;
	}
	DoGravity();
	block = MoveObon();

	if (!(block & BLOCK_DOWN))
	{
		obon.think = YouthJump;
	}
	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -250;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 250;
	}
}


/*
=====================
=
= YouthJump
=
=====================
*/

void YouthJump(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = YOUTHRIGHT4SPR;
	}
	else
	{
		obon.shapenum = YOUTHLEFT4SPR;
	}

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_DOWN)
	{
		obon.think = YouthWalk;
	}
	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -250;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 250;
	}
}


/*
=====================
=
= YouthContact
=
=====================
*/

void YouthContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj || hit->obclass == enemyshotobj)
	{
		PlaySound(VORTSCREAMSND);
		ob->temp1 = 0;
		ob->temp2 = 2;
		ob->shapenum = YOUTHDIE1SPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}

/*
==============================================================================

                           VORTICON ELITE ROUTINES

==============================================================================
*/


/*
=====================
=
= EliteWalk
=
=====================
*/

void EliteWalk(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = ELITERIGHT1SPR;
	}
	else
	{
		obon.shapenum = ELITELEFT1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 3);

	if (RndT() < tics*2 && lightson)
	{
		obon.yspeed = -Rnd(300);
		obon.think = EliteJump;
	}
	else if (RndT() < tics*2)
	{
		if (obon.y + 8*PIXGLOBAL == objlist[0].y)
		{
			obon.xspeed = 200;
		}
		else
		{
			obon.xspeed = 100;
		}

		if (obon.x > objlist[0].x)
		{
			obon.xspeed = -obon.xspeed;
		}
	}
	else if (RndT() < tics*2)
	{
		obon.think = EliteShoot;
		obon.temp1 = obon.temp2 = 0;
	}

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -100;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 100;
	}
	if (!(block & BLOCK_DOWN))
	{
		obon.think = EliteJump;
	}
}


/*
=====================
=
= EliteShoot
=
=====================
*/

void EliteShoot(void)
{
	Sint16 shotspeed;

	if (obon.xspeed < 0)
	{
		obon.shapenum = ELITEFIRELSPR;
	}
	else
	{
		obon.shapenum = ELITEFIRERSPR;
	}

	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 < 30)
	{
		return;
	}
	
	if (!obon.temp2)
	{
		obon.temp2 = true;
		PlaySound(TANKFIRESND);
		shotspeed = 350;
		if (obon.xspeed < 0)
		{
			shotspeed = -350;
		}
		SpawnEnemyShot(obon.x, obon.y-PIXGLOBAL, shotspeed);
	}
	if (obon.temp1 > 50)
	{
		obon.think = EliteWalk;
	}
}


/*
=====================
=
= EliteJump
=
=====================
*/

void EliteJump(void)
{
	Sint16 block;

	// Note: jump sprites are mislabeled (left and right sprites are swapped)!
	if (obon.xspeed > 0)
	{
		obon.shapenum = ELITEJUMPLSPR;
	}
	else
	{
		obon.shapenum = ELITEJUMPRSPR;
	}

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_DOWN)
	{
		obon.think = EliteWalk;
	}
	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -100;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 100;
	}
}


/*
=====================
=
= EliteContact
=
=====================
*/

void EliteContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj)
	{
		if (ob->health--)
		{
			return;
		}
		
		PlaySound(VORTSCREAMSND);
		ob->temp1 = 0;
		ob->temp2 = 2;
		ob->shapenum = ELITEDIE1SPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}

/*
==============================================================================

                              SCRUB ROUTINES

==============================================================================
*/


/*
=====================
=
= ScrubWalkLeft
=
=====================
*/

void ScrubWalkLeft(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 5) & 1) + SCRUBL1SPR;
	obon.xspeed = -80;
	obon.yspeed = 80;
	if (obon.temp1 == 0)
	{
		obon.ymove = obon.ymove + 4*PIXGLOBAL;
	}

	block = MoveObon();

	if (block & BLOCK_LEFT)
	{
		obon.think = ScrubWalkUp;
		obon.temp1 = 0;
		return;
	}
	if (!(block & BLOCK_DOWN))
	{
		if (obon.temp1)
		{
			obon.think = ScrubWalkDown;
			obon.temp1 = 0;
			obon.y += PIXGLOBAL;
			return;
		}
		else
		{
			obon.think = ScrubFall;
		}
	}
	if (obon.temp1 == 0)
	{
		obon.temp1 = 1;
	}
}


/*
=====================
=
= ScrubWalkDown
=
=====================
*/

void ScrubWalkDown(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 5) & 1) + SCRUBD1SPR;
	obon.xspeed = 80;
	obon.yspeed = 80;
	if (obon.temp1 == 0)
	{
		obon.xmove = obon.xmove + 4*PIXGLOBAL;
	}

	block = MoveObon();

	if (block & BLOCK_DOWN)
	{
		obon.think = ScrubWalkLeft;
		obon.temp1 = 0;
		return;
	}
	if (!(block & BLOCK_RIGHT))
	{
		if (obon.temp1)
		{
			obon.think = ScrubWalkRight;
			obon.temp1 = 0;
			obon.x += PIXGLOBAL;
			return;
		}
		else
		{
			obon.think = ScrubFall;
		}
	}
	if (obon.temp1 == 0)
	{
		obon.temp1 = 1;
	}
}


/*
=====================
=
= ScrubWalkRight
=
=====================
*/

void ScrubWalkRight(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 5) & 1) + SCRUBR1SPR;
	obon.xspeed = 80;
	obon.yspeed = -80;
	if (obon.temp1 == 0)
	{
		obon.ymove = obon.ymove - 4*PIXGLOBAL;
	}

	block = MoveObon();

	if (block & BLOCK_RIGHT)
	{
		obon.think = ScrubWalkDown;
		obon.temp1 = 0;
		return;
	}
	if (!(block & BLOCK_UP))
	{
		if (obon.temp1)
		{
			obon.think = ScrubWalkUp;
			obon.temp1 = 0;
			obon.y -= PIXGLOBAL;
			return;
		}
		else
		{
			obon.think = ScrubFall;
		}
	}
	if (obon.temp1 == 0)
	{
		obon.temp1 = 1;
	}
}


/*
=====================
=
= ScrubWalkUp
=
=====================
*/

void ScrubWalkUp(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 5) & 1) + SCRUBU1SPR;
	obon.xspeed = -80;
	obon.yspeed = -80;
	if (obon.temp1 == 0)
	{
		obon.xmove = obon.xmove - 4*PIXGLOBAL;
	}

	block = MoveObon();

	if (block & BLOCK_UP)
	{
		obon.think = ScrubWalkRight;
		obon.temp1 = 0;
		return;
	}
	if (!(block & BLOCK_LEFT))
	{
		if (obon.temp1)
		{
			obon.think = ScrubWalkLeft;
			obon.temp1 = 0;
			obon.x -= PIXGLOBAL;
			return;
		}
		else
		{
			obon.think = ScrubFall;
		}
	}
	if (obon.temp1 == 0)
	{
		obon.temp1 = 1;
	}
}


/*
=====================
=
= ScrubFall
=
=====================
*/

void ScrubFall(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 5) & 1) + SCRUBL1SPR;
	obon.xspeed = 0;

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_DOWN)
	{
		obon.think = ScrubWalkLeft;
		obon.temp1 = 0;
	}
}


/*
=====================
=
= ScrubContact
=
=====================
*/

void ScrubContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj || hit->obclass == enemyshotobj)
	{
		ob->temp1 = 0;
		ob->temp2 = 2;
		ob->shapenum = SCRUBSHOTSPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}

/*
==============================================================================

                            GUARD ROBOT ROUTINES

==============================================================================
*/


/*
=====================
=
= GuardMove
=
=====================
*/

void GuardMove(void)
{
	Sint16 block;

	// Note: Guard sprites are mislabeled (left and right sprites are swapped)!
	if (obon.xspeed > 0)
	{
		obon.shapenum = GUARDLEFT1SPR;
	}
	else
	{
		obon.shapenum = GUARDRIGHT1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 3);

	if (RndT() < tics)
	{
		obon.think = GuardShoot;
		obon.temp1 = obon.temp2 = 0;
	}

	block = MoveObon();

	if (block & BLOCK_LEFT)
	{
		obon.temp2 = 100;
		obon.temp1 = 0;
		obon.think = GuardStand;
	}
	else if (block & BLOCK_RIGHT)
	{
		obon.temp1 = 0;
		obon.temp2 = -100;
		obon.think = GuardStand;
	}
}


/*
=====================
=
= GuardShoot
=
=====================
*/

void GuardShoot(void)
{
	Sint16 shotspeed;

	// Note: Guard sprites are mislabeled (left and right sprites are swapped)!
	if (obon.xspeed > 0)
	{
		obon.shapenum = GUARDLEFT1SPR;
	}
	else
	{
		obon.shapenum = GUARDRIGHT1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 3);

	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 < 50)
	{
		return;
	}
	if (obon.temp1 > 150)
	{
		obon.think = GuardMove;
	}
	obon.temp2 = obon.temp2 + tics;
	if (obon.temp2 > 20)
	{
		obon.temp2 = 0;
		PlaySound(TANKFIRESND);
		shotspeed = 350;
		if (obon.xspeed < 0)
		{
			shotspeed = -350;
		}
		SpawnEnemyShot(obon.x, obon.y-4*PIXGLOBAL, shotspeed);
	}
}


/*
=====================
=
= GuardStand
=
=====================
*/

void GuardStand(void)
{
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 50)
	{
		obon.think = GuardMove;
		obon.xspeed = obon.temp2;
	}
	obon.shapenum = (((Uint16)timecount >> 4) & 1) + GUARDSTAND1SPR;
}


/*
=====================
=
= GuardContact
=
=====================
*/

#pragma argsused
void GuardContact(objtype *ob, objtype *hit)
{
	// do nothing
}

/*
==============================================================================

                           PLATFORM ROUTINES

==============================================================================
*/


/*
=====================
=
= PlatformMove
=
=====================
*/

void PlatformMove(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 5) & 1) + PLATFORM1SPR;

	block = MoveObon();

	if (block & BLOCK_LEFT)
	{
		obon.temp2 = 75;
		obon.temp1 = obon.xspeed = 0;
		obon.think = PlatformTurn;
	}
	else if (block & BLOCK_RIGHT)
	{
		obon.temp2 = -75;
		obon.temp1 = obon.xspeed = 0;
		obon.think = PlatformTurn;
	}
}


/*
=====================
=
= PlatformTurn
=
=====================
*/

void PlatformTurn(void)
{
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 75)
	{
		obon.xspeed = obon.temp2;
		obon.think = PlatformMove;
	}
}

/*
==============================================================================

                           SPARK/TANTALUS ROUTINES

==============================================================================
*/


/*
=====================
=
= SparkThink
=
=====================
*/

void SparkThink(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 3) & 3) + SPARK1SPR;

	block = MoveObon();

	// This looks like the spark was supposed to move at some point during
	// development. But since the spark's xspeed remains set to 0 when it gets
	// spawned, it won't try to move and the BLOCK_LEFT and BLOCK_RIGHT bits
	// will never be set here, so the code to change the spark's xspeed will
	// never be executed.
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 75;
	}
	else if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -75;
	}
}


/*
=====================
=
= SparkContact
=
=====================
*/

void SparkContact(objtype *ob, objtype *hit)
{
	pobjtype *pob;

	switch (level)
	{
	case 4:
		gamestate.citySaved[CITY_LONDON] = true;
		break;
	case 6:
		gamestate.citySaved[CITY_CAIRO] = true;
		break;
	case 7:
		gamestate.citySaved[CITY_SYDNEY] = true;
		break;
	case 9:
		gamestate.citySaved[CITY_NEWYORK] = true;
		break;
	case 11:
		gamestate.citySaved[CITY_PARIS] = true;
		break;
	case 13:
		gamestate.citySaved[CITY_ROME] = true;
		break;
	case 15:
		gamestate.citySaved[CITY_MOSCOW] = true;
		break;
	case 16:
		gamestate.citySaved[CITY_WASHINGTONDC] = true;
		break;
	}

	if (hit->obclass != shotobj)
	{
		return;
	}
	
	ob->obclass = nothing;
	GivePoints(10000);

	pob = FindFreePObj();
	pob->type = POBJ_TANTALUSEXPLOSION;
	pob->think = TantalusExplode;
	pob->x = GLOBAL_TO_TILE(ob->x);
	pob->y = GLOBAL_TO_TILE(ob->y);
	pob->temp1 = pob->temp2 = 0;

	pob = FindFreePObj();
	pob->type = POBJ_BORDERFLASH;
	pob->think = BorderFlash;
	pob->temp1 = 0;
}


/*
=====================
=
= ExplodeTile
=
=====================
*/

void ExplodeTile(Sint16 x, Sint16 y, Sint16 newtile)
{
	objtype *ob;

	PlaySound(SHOTHITSND);

	ob = FindFreeObj();
	ob->think = ShotSplash;
	ob->obclass = deadobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->temp1 = 0;
	ob->contact = NullContact;
	if (RndT() > 0x80)
	{
		ob->shapenum = SHOTSPLASHRSPR;
	}
	else
	{
		ob->shapenum = SHOTSPLASHLSPR;
	}

	SETTILE(x,y,0,newtile);
}


/*
=====================
=
= TantalusExplode
=
=====================
*/

void TantalusExplode(pobjtype *pob)
{
	Sint16 x, y, ix, iy;

	pob->temp1 = pob->temp1 + tics;
	if (pob->temp1 < 40)
	{
		return;
	}

	pob->temp1 -= 40;
	pob->temp2++;
	x = pob->x;
	y = pob->y;

	switch (pob->temp2)
	{
	case 1:
		// break the glass dome around the spark:
		SETTILE(x-1, y-1, 0, 143);
		SETTILE(  x, y-1, 0, 143);
		SETTILE(x+1, y-1, 0, 143);
		SETTILE(x-1,   y, 0, 546);
		SETTILE(  x,   y, 0, 547);
		SETTILE(x+1,   y, 0, 548);
		// break the tantalus switch:
		SETTILE(x-3, y+4, 0, 506);
		break;

	case 2:
		// break left electrode:
		ExplodeTile(x-2, y, 492);
		break;

	case 3:
		// break right electrode:
		ExplodeTile(x+2, y, 492);
		break;

	case 4:
	case 5:
	case 6:
		// break the shaft(?):
		ExplodeTile(x, y+pob->temp2-1, 505);
		break;

	case 7:
	case 8:
	case 9:
	case 10:
		// break the heat panel(?):
		for (iy = y+3; y+6 > iy; iy++)
		{
			ExplodeTile(x+pob->temp2-4, iy, 549);
		}
		break;

	default:
		// replace the city pic with static:
		for (ix = x-7; x-4 > ix; ix++)
		{
			for (iy = y+2; y+5 > iy; iy++)
			{
				SETTILE(ix, iy, 0, 533);
			}
		}
		pob->type = POBJ_NOTHING;
	}
}

/*
==============================================================================

                           STUNNED KEEN ROUTINES

==============================================================================
*/


/*
=====================
=
= KeenFrozen
=
=====================
*/

void KeenFrozen(void)
{
	obon.shapenum = (((Uint16)timecount >> 5) & 1) + KEENSICLE1SPR;
	obon.temp1 = obon.temp1 - tics;
	if (obon.temp1 < 0)
	{
		obon.shapenum = KEENMELTSPR;
		if (obon.temp1 < -40)
		{
			obon.think = KeenWalk;
		}
	}

	if (obon.xspeed > 0)
	{
		AccelerateX(-3);
		if (obon.xspeed < 0)
		{
			obon.xspeed = 0;
		}
	}
	else if (obon.xspeed < 0)
	{
		AccelerateX(3);
		if (obon.xspeed > 0)
		{
			obon.xspeed = 0;
		}
	}
	DoGravity();
	MoveObon();
	PlayerCheckMapBorders();
}

/*
==============================================================================

                           VORTICON ELDER MESSAGES

==============================================================================
*/


/*
=====================
=
= ShowMessage
=
=====================
*/

void ShowMessage(void)
{
	Sint32 oldtime;

	oldtime = timecount;
	CenterWindow(22, 13);

	switch (level)
	{
	case 8:
		Print("The Elder Vorticon    \n");
		Print("in the stasis field   \n");
		Print("says:                 \n");
		Print("The wise Vorticon     \n");
		Print("never jumps in the    \n");
		Print("dark.  In fact, even  \n");
		Print("unwise Vorticons will \n");
		Print("not jump in darkness. \n");
		break;

	case 10:
		Print("The Vorticon Elder    \n");
		Print("says through the      \n");
		Print("stasis field:         \n");
		Print("The Grand Intellect   \n");
		Print("is not from Vorticon  \n");
		Print("VI--he is from the    \n");
		Print("planet Earth. His evil\n");
		Print("Mind-Belts control    \n");
		Print("their minds.  They are\n");
		Print("not evil. Please do   \n");
		Print("not shoot them, human.\n");
		break;
	}

	sy = screencentery+7;
	PrintC("Press ENTER:");
	ClearKeys();
	do { /* nothing */ } while ((Get() & 0xFF) != CHAR_ENTER);

	RF_ForceRefresh();
	ClearKeys();
	timecount = oldtime;
}

/*
==============================================================================

                        GAME OVER / FINALE ANIMATIONS

==============================================================================
*/


/*
=====================
=
= TheEarthExplodes
=
=====================
*/

void TheEarthExplodes(void)
{
	// frames of the explosion animation:
	static Sint16 explFrames[] =	// relative to FIREARTH1SPR (-1 means draw nothing)
	{
		 0,  0,  1,  1,  2,  2,  3,  3,  2,  2,
		 3,  3,  2,  2,  3,  3,  2,  2,  1,  1,
		 0,  0, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1
		// Note: only the first 68 entries are ever used
	};
	// we'll have 9 spots where an explosion sprite should appear:
	// x/y position of each explosion (in half-tile units a.k.a. 8 pixels)
	static Sint16 explX[9] = {2, 1, 3, 1, 3, 0, 2, 2, 4};
	static Sint16 explY[9] = {2, 1, 1, 3, 3, 2, 0, 4, 2};
	// delay before each explosion (only first 9 entries used):
	static Sint16 explDelays[] =
	{
		0, 2, 4, 6, 8, 10,
		12, 14, 16, 18, 20,
		22, 24, 26, 28, 30,
		32, 34, 36, 38, 40
	};

	Sint16 tx, ty, i, n, frame, stage;
	Sint32 earthX, earthY, shotX, shotY, delta;

	ReadLevel(ENDINGMAP);	// space level
	originx = originy = 0;
	RF_Clear();
	RF_ForceRefresh();
	RF_Refresh();
	FadeIn();
	WaitVBL(120);

	PlaySound(TANKFIRESND);
	shotX = 6*TILEGLOBAL;
	shotY = 5*TILEGLOBAL;
	for (i = 0; i <= 20; i++)
	{
		if ((bioskey(1) & 0xFF) == CHAR_ESCAPE)	// minor BUG: should use NoBiosKey in v1.3+
		{
			bioskey(0);	// same here
			return;
		}

		RF_Clear();
		shotX = (i * (41*TILEGLOBAL)) / 20 + 6*TILEGLOBAL;
		shotY = (i * (17*TILEGLOBAL)) / 20 + 5*TILEGLOBAL;
		originx = shotX - 6*TILEGLOBAL;
		originy = shotY - 5*TILEGLOBAL;
		RF_PlaceSprite(shotX, shotY, i % 2 + TANTALUS1SPR);
		RF_Refresh();
	}

	PlaySound(EARTHPOWSND);
	earthX = 47*TILEGLOBAL;
	earthY = 22*TILEGLOBAL;
	for (n = 0; n < 60; n++)
	{
		RF_Clear();

		if (n == 20)
		{
			// erase Earth tiles from the map:
			for (tx = 0; tx <= 2; tx++)
			{
				for (ty = 0; ty <= 2; ty++)
				{
					SETTILE(tx+47, ty+22l, 0, 155);
				}
			}
		}
		if (n >= 15)
		{
			delta = 10*PIXGLOBAL * (n-15);
			RF_PlaceSprite(earthX-delta/2, earthY-delta, (n/2) % 4 + LILCHUNK1SPR);
			RF_PlaceSprite(earthX+delta/2+TILEGLOBAL, earthY-delta, (n/2) % 4 + LILCHUNK1SPR);
			RF_PlaceSprite(earthX-delta/2, earthY+delta+TILEGLOBAL, (n/2) % 4 + LILCHUNK1SPR);
			RF_PlaceSprite(earthX+delta/2+TILEGLOBAL, earthY+delta+TILEGLOBAL, (n/2) % 4 + LILCHUNK1SPR);

			RF_PlaceSprite(earthX-delta, earthY-delta/2, (n/2) % 4 + LILCHUNK1SPR);
			RF_PlaceSprite(earthX+delta+TILEGLOBAL, earthY-delta/2, (n/2) % 4 + LILCHUNK1SPR);
			RF_PlaceSprite(earthX-delta, earthY+delta/2+TILEGLOBAL, (n/2) % 4 + LILCHUNK1SPR);
			RF_PlaceSprite(earthX+delta+TILEGLOBAL, earthY+delta/2+TILEGLOBAL, (n/2) % 4 + LILCHUNK1SPR);
		}
		if (n >= 20)
		{
			delta = PIXEL_TO_GLOBAL((Sint32)(n-20) << 3);
			RF_PlaceSprite(earthX-delta, earthY-delta, (n/2) % 4 + EARTHCHUNK1SPR);
			RF_PlaceSprite(earthX+delta+TILEGLOBAL, earthY-delta, (n/2) % 4 + EARTHCHUNK1SPR);
			RF_PlaceSprite(earthX-delta, earthY+delta+TILEGLOBAL, (n/2) % 4 + EARTHCHUNK1SPR);
			RF_PlaceSprite(earthX+delta+TILEGLOBAL, earthY+delta+TILEGLOBAL, (n/2) % 4 + EARTHCHUNK1SPR);
		}

		for (i = 0; i < 9; i++)
		{
			stage = n - explDelays[i];
			if (stage >= 0)
			{
				frame = explFrames[stage];
				if (frame != -1)
				{
					RF_PlaceSprite(TILE_TO_GLOBAL((Sint32)(explX[i])+47*2)/2, TILE_TO_GLOBAL((Sint32)(explY[i])+22*2)/2, frame + FIREARTH1SPR);
				}
			}
		}

		RF_Refresh();
		WaitVBL(3);
	}
}


/*
=====================
=
= EraseWin
=
=====================
*/

void EraseWin(void)
{
	CharBar(win_xl, win_yl, win_xh, win_yh, ' ');	// place white chars
}


/*
=====================
=
= DoFinale
=
=====================
*/

void DoFinale(void)
{
	Sint16 i;
	Sint32 lameX, lameY, shipX, shipY;

	ReadLevel(ENDINGMAP);	// space level

	originx = originy = 0;
	RF_Clear();
	RF_ForceRefresh();
	shipX = 7*TILEGLOBAL;
	shipY = 3*TILEGLOBAL;
	RF_PlaceSprite(shipX, shipY, SMALLSHIPRSPR);
	RF_Refresh();
	DrawWindow(4, 17, 36, 24);
	FadeIn();
	TypeText("After disabling the weaponry of\n");
	TypeText("the Vorticon Mothership, Billy\n");
	TypeText("heads for earth.  Even great\n");
	TypeText("space heroes need a nap after\n");
	TypeText("defeating a vicious horde\n");
	TypeText("of violence-bent aliens!");
	WaitVBL(300);

	RF_ForceRefresh();
	RF_Refresh();
	for (i = 0; i <= 120; i++)
	{
		if ((bioskey(1) & 0xFF) == CHAR_ESCAPE)	// minor BUG: should use NoBiosKey in v1.3+
		{
			bioskey(0);	// same here
			return;
		}

		RF_Clear();
		shipX = (i * (648*PIXGLOBAL))/120 + 7*TILEGLOBAL;
		shipY = (i * (312*PIXGLOBAL))/120 + 3*TILEGLOBAL;
		originx = shipX - 7*TILEGLOBAL;
		originy = shipY - 3*TILEGLOBAL;
		RF_PlaceSprite(shipX, shipY, SMALLSHIPRSPR);
		RF_Refresh();
	}
	WaitVBL(120);

	FadeOut();
	RF_Clear();
	originx = 0;
	originy = 12*TILEGLOBAL;
	lameX = 10*TILEGLOBAL;
	lameY = 17*TILEGLOBAL;
	RF_PlaceSprite(lameX, lameY, LAMESHIPSPR);
	RF_Refresh();
	DrawWindow(4, 17, 36, 24);
	FadeIn();
	TypeText("The Vorticon ship limps back\n");
	TypeText("toward Vorticon VI to tell of  \n");
	TypeText("their defeat at the hands of\n");
	TypeText("Commander Keen.  The Grand\n");
	TypeText("Intellect will not be pleased.\n");
	WaitVBL(120);

	RF_ForceRefresh();
	for (i = 0; i < 120; i++)
	{
		RF_Clear();
		lameX -= PIXGLOBAL;
		lameY -= PIXGLOBAL;
		RF_PlaceSprite(lameX, lameY, LAMESHIPSPR);
		RF_Refresh();
	}

	FadeOut();
	originx &= 0xFFFF000;	// BUG: should really be 0xFFFFF000, i.e., ~(TILEGLOBAL-1)
	RF_Refresh();
	DrawPicFile("finale.ck2");
	ReadLevel(ENDINGMAP);	// reload space level (DrawPicFile trashes the level data!)
	FadeIn();
	DrawWindow(4, 18, 29, 22);
	TypeText("Wake up, Billy.  It\n");
	TypeText("Snowed last night!\n");
	TypeText("There's no school!");
	WaitVBL(120);

	EraseWin();
	DrawWindow(4, 16, 29, 24);
	TypeText("Wonderful, Mother.  That\n");
	TypeText("will give me time to rid\n");
	TypeText("the Galaxy of the\n");
	TypeText("Vorticon menace and\n");
	TypeText("discover the secret of\n");
	TypeText("the mysterious Grand\n");
	TypeText("Intellect!\n");
	WaitVBL(120);

	EraseWin();
	DrawWindow(4, 18, 29, 23);
	TypeText("Ok, hon, but you'd\n");
	TypeText("better have a nourishing\n");
	TypeText("vitamin fortified bowl\n");
	TypeText("of Sugar Stoopies first.\n");
	WaitVBL(120);

	EraseWin();
	DrawWindow(4, 18, 16, 20);
	TypeText("Ok, mom...");
	WaitVBL(120);

	EraseWin();
	DrawWindow(12, 3, 32, 5);
	TypeText("TO BE CONTINUED....");
	WaitVBL(400);

	// normalize horizontal screen position (for DrawTextScreen/ShowText)
	TILE_ALIGN(originx);
	RF_ForceRefresh();
	RF_Refresh();
	RF_Refresh();
	DrawTextScreen(endtextPtr, 0, 22);
	PlaySound(KEENSLEFTSND);
	WaitEndSound();
	ShowText(endtextPtr, 0, 22);
}

#include "KEENACTS.C"

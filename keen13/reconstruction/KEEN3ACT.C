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
				SpawnWoman(x, y);
				break;

			case 4:
				SpawnMeep(x, y);
				break;

			case 5:
				SpawnNinja(x, y);
				break;

			case 6:
				SpawnFoob(x, y);
				break;

			case 7:
				SpawnBall(x, y);
				break;

			case 8:
				SpawnJack(x, y);
				break;

			case 9:
				SpawnPlatformX(x, y);
				break;

			case 10:
				SpawnPlatformY(x, y);
				break;

			case 11:
				SpawnGrunt(x, y);
				break;

			case 12:
				SpawnSpark(x, y);
				break;

			case 13:
				SpawnHeart(x, y);
				break;

			case 14:
				SpawnTurretE(x, y);
				break;

			case 15:
				SpawnTurretS(x, y);
				break;

			case 16:
				SpawnArm(x, y);
				break;

			case 17:
				SpawnFoot(x, y, -1);
				break;

			case 18:
				SpawnFoot(x, y, 1);
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
	ob->health = 1;	// doesn't matter, youth always dies when shot by Keen

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
= SpawnWoman
=
=====================
*/

void SpawnWoman(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = womanobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = WomanWalk;
	ob->contact = WomanContact;
	ob->health = 5;
	
	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -50;
	}
	else
	{
		ob->xspeed = 50;
	}

	ob->shapenum = WOMANL1SPR;
}


/*
=====================
=
= SpawnMeep
=
=====================
*/

void SpawnMeep(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = meepobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y) + 8*PIXGLOBAL;
	ob->think = MeepWalk;
	ob->contact = MeepContact;
	ob->health = 1;

	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -65;
	}
	else
	{
		ob->xspeed = 65;
	}

	ob->shapenum = MEEPL1SPR;
}


/*
=====================
=
= SpawnNinja
=
=====================
*/

void SpawnNinja(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = ninjaobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = NinjaStand;
	ob->contact = NinjaContact;
	ob->health = 3;

	// object starts out facing Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -1;
	}
	else
	{
		ob->xspeed = 1;
	}

	ob->shapenum = NINJAL1SPR;
}


/*
=====================
=
= SpawnFoob
=
=====================
*/

void SpawnFoob(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = foobobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = FoobWalk;
	ob->contact = FoobContact;
	ob->health = 1;	// doesn't matter, foob always dies when touched by Keen or hit by any shot
	
	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -50;
	}
	else
	{
		ob->xspeed = 50;
	}

	ob->shapenum = FOOBL1SPR;
}


/*
=====================
=
= SpawnBall
=
=====================
*/

void SpawnBall(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = ballobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = BallThink;
	ob->contact = NullContact;
	ob->health = 1;	// doesn't matter (NullContact!)

	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -400;
	}
	else
	{
		ob->xspeed = 400;
	}

	if (ob->y > objlist[0].y)
	{
		ob->yspeed = -400;
	}
	else
	{
		ob->yspeed = 400;
	}

	ob->shapenum = BALLSPR;
}


/*
=====================
=
= SpawnJack
=
=====================
*/

void SpawnJack(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = jackobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = JackThink;
	ob->contact = NullContact;
	ob->health = 1;	// doesn't matter (NullContact!)

	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x > objlist[0].x)
	{
		ob->xspeed = -400;
	}
	else
	{
		ob->xspeed = 400;
	}

	if (ob->y > objlist[0].y)
	{
		ob->yspeed = -400;
	}
	else
	{
		ob->yspeed = 400;
	}

	ob->shapenum = JACK1SPR;
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
	ob->think = PlatformThink;
	ob->contact = NullContact;
	ob->shapenum = PLATFORM1SPR;
	ob->xspeed = 75;
}


/*
=====================
=
= SpawnPlatformY
=
=====================
*/

void SpawnPlatformY(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = platformobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = PlatformThink;
	ob->contact = NullContact;
	ob->shapenum = PLATFORM1SPR;
	ob->yspeed = 75;
}


/*
=====================
=
= SpawnTurretE
=
=====================
*/

void SpawnTurretE(Sint16 x, Sint16 y)
{
	pobjtype *pob;

	pob = FindFreePObj();
	pob->type = POBJ_TURRET;
	pob->x = TILE_TO_GLOBAL(x);
	pob->y = TILE_TO_GLOBAL(y);
	pob->think = TurretEThink;
}


/*
=====================
=
= SpawnTurretS
=
=====================
*/

void SpawnTurretS(Sint16 x, Sint16 y)
{
	pobjtype *pob;

	pob = FindFreePObj();
	pob->type = POBJ_TURRET;
	pob->x = TILE_TO_GLOBAL(x);
	pob->y = TILE_TO_GLOBAL(y);
	pob->think = TurretSThink;
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
=====================
=
= SpawnHeart
=
=====================
*/

void SpawnHeart(Sint16 x, Sint16 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = heartobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = HeartThink;
	ob->contact = HeartContact;
	ob->shapenum = SPARK1SPR;
	// this doesn't use the correct sprite, but it doesn't really matter (the
	// think function will update shapenum before the sprite is drawn for the
	// first time).
}


/*
=====================
=
= SpawnArm
=
=====================
*/

void SpawnArm(Sint16 x, Sint16 y)
{
	pobjtype *pob;

	pob = FindFreePObj();
	pob->type = POBJ_ARM;
	pob->x = x;
	pob->y = y;
	pob->think = ArmThink;
	pob->temp2 = 0;
	pob->temp1 = 1;
	pob->temp3 = 15;
}


/*
=====================
=
= SpawnFoot
=
=====================
*/

void SpawnFoot(Sint16 x, Sint16 y, Sint16 dir)
{
	pobjtype *pob;

	pob = FindFreePObj();
	pob->type = POBJ_FOOT;
	pob->x = x;
	pob->y = y;
	pob->temp3 = pob->temp1 = dir;
	pob->think = FootThink;
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

	if (obon.xspeed  > 0)
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

                     VORTICON YOUTH (VORTIKID) ROUTINES

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
	if (hit->obclass == shotobj)
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

                           VORTICON WOMAN ROUTINES

==============================================================================
*/


/*
=====================
=
= WomanWalk
=
=====================
*/

void WomanWalk(void)
{
	Sint16 block;
	Sint32 oldy;

	if (obon.xspeed > 0)
	{
		obon.shapenum = WOMANR1SPR;
	}
	else
	{
		obon.shapenum = WOMANL1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 1);

	oldy = obon.y;
	if (RndT() < tics)
	{
		obon.temp3 = -obon.xspeed;
		obon.temp1 = obon.temp2 = obon.xspeed = 0;
		obon.think = WomanShoot;
	}

	DoGravity();
	block = MoveObon();

	if (!(block & BLOCK_DOWN))
	{
		// no longer on solid ground (woman is not supposed to fall):
		// BUG: resetting y to oldy is useless (should set ymove to 0 here)
		obon.y = oldy;
		obon.xspeed = -obon.xspeed;
		obon.x += obon.xspeed*2;	// unclipped movement - might cause problems
	}
	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -50;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 50;
	}
}


/*
=====================
=
= WomanShoot
=
=====================
*/

void WomanShoot(void)
{
	Sint16 shotspeed;

	if (obon.temp3 < 0)
	{
		obon.shapenum = WOMANBLSPR;
	}
	else
	{
		obon.shapenum = WOMANBRSPR;
	}

	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 < 30)
	{
		return;
	}
	
	if (obon.temp2 == 0)
	{
		obon.temp2 = 1;
		PlaySound(TANKFIRESND);
		if (obon.temp3 < 0)
		{
			shotspeed = -150;
		}
		else
		{
			shotspeed = 150;
		}
		SpawnWomanShot(obon.x, obon.y-PIXGLOBAL, shotspeed);
	}
	if (obon.temp1 > 50)
	{
		obon.xspeed = obon.temp3;
		obon.think = WomanWalk;
	}
}


/*
=====================
=
= SpawnWomanShot
=
=====================
*/

void SpawnWomanShot(Sint32 x, Sint32 y, Sint16 xspeed)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = enemyshotobj;
	ob->x = x;
	ob->y = y + 13*PIXGLOBAL;
	ob->think = WomanShotThink;
	ob->xspeed = xspeed;
	ob->contact = WomanShotContact;

	if (xspeed >= 0)
	{
		ob->shapenum = ob->temp1 = WOMANFIRER1SPR;
		if (eastwall[GETTILE(GLOBAL_TO_TILE(x)+1, GLOBAL_TO_TILE(y)+1, 0)])
		{
			PlaySound(SHOTHITSND);
			ob->obclass = splashobj;
			ob->think = ShotSplash;
			ob->temp1 = 0;
			if (RndT() > 0x80)
			{
				ob->shapenum = SHOTSPLASHRSPR;
			}
			else
			{
				ob->shapenum = SHOTSPLASHLSPR;
			}
			return;
		}
	}
	else
	{
		ob->shapenum = ob->temp1 = WOMANFIREL1SPR;
		if (westwall[GETTILE(GLOBAL_TO_TILE(x), GLOBAL_TO_TILE(y)+1, 0)])
		{
			PlaySound(SHOTHITSND);
			ob->obclass = splashobj;
			ob->think = ShotSplash;
			ob->temp1 = 0;
			if (RndT() > 0x80)
			{
				ob->shapenum = SHOTSPLASHRSPR;
			}
			else
			{
				ob->shapenum = SHOTSPLASHLSPR;
			}
			return;
		}
	}
}


/*
=====================
=
= WomanShotThink
=
=====================
*/

void WomanShotThink(void)
{
	Sint16 block;

	obon.shapenum = obon.temp1 + (((Uint16)timecount >> 3) & 1);

	block = MoveObon();

	if (block)
	{
		PlaySound(SHOTHITSND);
		obon.obclass = splashobj;
		obon.think = ShotSplash;
		obon.temp1 = 0;
		if (RndT() > 0x80)
		{
			obon.shapenum = SHOTSPLASHRSPR;
		}
		else
		{
			obon.shapenum = SHOTSPLASHLSPR;
		}
		return;
	}
}


/*
=====================
=
= WomanShotContact
=
=====================
*/

void WomanShotContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == womanobj || hit->obclass == deadobj)
	{
		return;
	}
	
	PlaySound(SHOTHITSND);
	ob->think = ShotSplash;
	ob->contact = NullContact;
	ob->temp1 = 0;
	if (RndT() > 0x80)
	{
		ob->shapenum = SHOTSPLASHRSPR;
	}
	else
	{
		ob->shapenum = SHOTSPLASHLSPR;
	}
}


/*
=====================
=
= WomanContact
=
=====================
*/

void WomanContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj)
	{
		if (--ob->health)
		{
			return;
		}
		
		PlaySound(VORTSCREAMSND);
		ob->temp1 = 0;
		ob->temp2 = 2;
		ob->shapenum = WOMANDIE1SPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}

/*
==============================================================================

                               MEEP ROUTINES

==============================================================================
*/


/*
=====================
=
= MeepWalk
=
=====================
*/

void MeepWalk(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = MEEPR1SPR;
	}
	else
	{
		obon.shapenum = MEEPL1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 1);

	if (RndT() < tics)
	{
		obon.temp3 = obon.xspeed;
		obon.temp1 = obon.temp2 = obon.xspeed = 0;
		obon.think = MeepSing;
	}

	DoGravity();
	block = MoveObon();

	if (!(block & BLOCK_DOWN))
	{
		obon.temp3 = obon.xspeed;	// BUG? Meep keeps walking in old direction after singing
		obon.temp1 = obon.temp2 = obon.xspeed = 0;
		obon.think = MeepSing;
	}
	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -65;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 65;
	}
}


/*
=====================
=
= MeepSing
=
=====================
*/

void MeepSing(void)
{
	objtype *ob;

	if (obon.temp3 < 0)
	{
		obon.shapenum = MEEPSINGLSPR;
	}
	else
	{
		obon.shapenum = MEEPSINGRSPR;
	}

	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 >= 60)
	{
		if (obon.temp2 == 0)
		{
			obon.temp2 = 1;
			PlaySound(MEEPSND);
			ob = FindFreeObj();
			if (obon.temp3 < 0)
			{
				ob->x = obon.x;
				ob->shapenum = ob->temp1 = MEEPWAVEL1SPR;
				ob->xspeed = -200;
			}
			else
			{
				ob->x = obon.x + TILEGLOBAL;
				ob->xspeed = 200;
				ob->shapenum = ob->temp1 = MEEPWAVER1SPR;
			}
			ob->y = obon.y + 4*PIXGLOBAL;
			ob->think = MeepWaveThink;
			ob->contact = NullContact;
			ob->obclass = meepwaveobj;
		}
		if (obon.temp1 > 80)
		{
			obon.xspeed = obon.temp3;
			obon.think = MeepWalk;
		}
	}
}


/*
=====================
=
= MeepContact
=
=====================
*/

void MeepContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj)
	{
		if (--ob->health)
		{
			return;
		}
		
		PlaySound(VORTSCREAMSND);
		ob->temp1 = 0;
		ob->temp2 = 2;
		ob->shapenum = MEEPDIE1SPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}


/*
=====================
=
= MeepWaveThink
=
=====================
*/

void MeepWaveThink(void)
{
	obon.shapenum = obon.temp1 + (((Uint16)timecount >> 3) & 1);
	obon.xmove = obon.xspeed * tics;	// move without clipping
}

/*
==============================================================================

                     VORTICON NINJA (VORTININJA) ROUTINES

==============================================================================
*/


/*
=====================
=
= NinjaStand
=
=====================
*/

void NinjaStand(void)
{
	Sint32 ydiff;

	if (obon.x < objlist[0].x)
	{
		obon.xspeed = 250;
		obon.shapenum = NINJAR1SPR;
	}
	else
	{
		obon.xspeed = -250;
		obon.shapenum = NINJAL1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 5) & 1);

	ydiff = objlist[0].y - obon.y;
	if (ydiff > 5*TILEGLOBAL || ydiff < -5*TILEGLOBAL)
	{
		return;
	}

	if (RndT() < tics*3)
	{
		obon.yspeed = -Rnd(350);
		obon.think = NinjaJump;
	}
}


/*
=====================
=
= NinjaJump
=
=====================
*/

void NinjaJump(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = NINJAJUMPRSPR;
	}
	else
	{
		obon.shapenum = NINJAJUMPLSPR;
	}

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_DOWN)
	{
		obon.think = NinjaStand;
	}
}


/*
=====================
=
= NinjaContact
=
=====================
*/

void NinjaContact(objtype *ob, objtype *hit)
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
		ob->shapenum = NINJADIE1SPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}

/*
==============================================================================

                                FOOB ROUTINES

==============================================================================
*/


/*
=====================
=
= FoobWalk
=
=====================
*/

void FoobWalk(void)
{
	Sint16 tx;
	Sint16 ty;
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = FOOBR1SPR;
	}
	else
	{
		obon.shapenum = FOOBL1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 5) & 1);

	tx = GLOBAL_TO_TILE(obon.x);
	ty = GLOBAL_TO_TILE(obon.y);
	if (tx > ox && ty > oy && ox+19 > tx)
	{
		if ((RndT() < tics*2) & (oy+12 > ty))
		{
			obon.temp1 = 0;
			obon.think = FoobYell;
			PlaySound(YORPSCREAMSND);
		}
	}

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -50;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 50;
	}
}


/*
=====================
=
= FoobRun
=
=====================
*/

void FoobRun(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = FOOBR1SPR;
	}
	else
	{
		obon.shapenum = FOOBL1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 3) & 1);

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_LEFT)
	{
		obon.xspeed = -1;
	}
	else if (block & BLOCK_RIGHT)
	{
		obon.xspeed = 1;
	}
}


/*
=====================
=
= FoobYell
=
=====================
*/

void FoobYell(void)
{
	obon.shapenum = (((Uint16)timecount/10) & 1) + FOOBYELL1SPR;

	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 24)
	{
		// run AWAY from Keen:
		if (obon.x > objlist[0].x)
		{
			obon.xspeed = 250;
		}
		else
		{
			obon.xspeed = -250;
		}
		obon.think = FoobRun;
	}
}


/*
=====================
=
= FoobContact
=
=====================
*/

void FoobContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == keenobj || hit->obclass == shotobj || hit->obclass == enemyshotobj)
	{
		PlaySound(YORPSCREAMSND);
		ob->temp1 = 0;
		ob->temp2 = 3;
		ob->shapenum = FOOBDIE1SPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}

/*
==============================================================================

                           JACK & BALL ROUTINES

==============================================================================
*/


/*
=====================
=
= JackThink
=
=====================
*/

void JackThink(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 3) & 3) + JACK1SPR;

	block = MoveObon();

	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -400;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 400;
	}
	if (block & BLOCK_DOWN)
	{
		obon.yspeed = -400;
	}
	if (block & BLOCK_UP)
	{
		obon.yspeed = 400;
	}
}


/*
=====================
=
= BallThink
=
=====================
*/

void BallThink(void)
{
	Sint16 block;

	block = MoveObon();

	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -400;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 400;
	}
	if (block & BLOCK_DOWN)
	{
		obon.yspeed = -400;
	}
	if (block & BLOCK_UP)
	{
		obon.yspeed = 400;
	}
}

/*
==============================================================================

                           PLATFORM ROUTINES

==============================================================================
*/


/*
=====================
=
= PlatformThink
=
=====================
*/

void PlatformThink(void)
{
	Sint16 block;

	obon.shapenum = (((Uint16)timecount >> 5) & 1) + PLATFORM1SPR;

	block = MoveObon();

	if (block & BLOCK_LEFT)
	{
		obon.temp2 = 75;
		obon.temp1 = obon.temp3 = obon.xspeed = 0;
		obon.think = PlatformTurn;
	}
	else if (block & BLOCK_RIGHT)
	{
		obon.temp2 = -75;
		obon.temp1 = obon.temp3 = obon.xspeed = 0;
		obon.think = PlatformTurn;
	}
	if (block & BLOCK_UP)
	{
		obon.temp3 = 75;
		obon.temp1 = obon.temp2 = obon.yspeed = 0;
		obon.think = PlatformTurn;
	}
	else if (block & BLOCK_DOWN)
	{
		obon.yspeed = -75;
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
		obon.yspeed = obon.temp3;
		obon.think = PlatformThink;
	}
}

/*
==============================================================================

                           TURRET ROUTINES

==============================================================================
*/


/*
=====================
=
= TankShotThink
=
=====================
*/

void TankShotThink(void)
{
	Sint16 block;

	block = MoveObon();

	if (block)
	{
		PlaySound(SHOTHITSND);
		obon.obclass = splashobj;
		obon.think = ShotSplash;
		obon.temp1 = 0;
		if (RndT() > 0x80)
		{
			obon.shapenum = SHOTSPLASHRSPR;
		}
		else
		{
			obon.shapenum = SHOTSPLASHLSPR;
		}
		return;
	}
}


/*
=====================
=
= TurretEThink
=
=====================
*/

void TurretEThink(pobjtype *pob)
{
	objtype *ob;

	pob->temp1 = pob->temp1 + tics;
	if (pob->temp1 < 400)
	{
		return;
	}

	pob->temp1 -= 400;
	PlaySound(TANKFIRESND);
	ob = FindFreeObj();
	ob->shapenum = TANKSHOTSPR;
	ob->xspeed = 400;
	ob->x = pob->x;
	ob->y = pob->y + 3*PIXGLOBAL;
	ob->think = TankShotThink;
	ob->contact = NullContact;
	ob->obclass = enemyshotobj;
}


/*
=====================
=
= TurretSThink
=
=====================
*/

void TurretSThink(pobjtype *pob)
{
	objtype *ob;

	pob->temp1 = pob->temp1 + tics;
	if (pob->temp1 < 400)
	{
		return;
	}

	pob->temp1 -= 400;
	PlaySound(TANKFIRESND);
	ob = FindFreeObj();
	ob->shapenum = VTANKSHOTSPR;
	ob->yspeed = 400;
	ob->x = pob->x + 4*PIXGLOBAL;;
	ob->y = pob->y;
	ob->think = TankShotThink;
	ob->contact = NullContact;
	ob->obclass = enemyshotobj;
}

/*
==============================================================================

                           MANGLING MACHINE ROUTINES

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
	obon.shapenum = (((Uint16)timecount >> 3) & 3) + SPARK1SPR;
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
	Sint16 i;
	pobjtype *pob;

	if (hit->obclass != shotobj)
	{
		return;
	}

	ob->obclass = nothing;	// remove the spark (shot will still explode)

	pob = FindFreePObj();
	pob->type = POBJ_BORDERFLASH;
	pob->think = BorderFlash;
	pob->temp1 = 0;	// redundant (already set to 0 by FindFreePObj)

	GivePoints(1000);
	if (++sparksgone == 6)
	{
		// remove all "arm" PObjects:
		for (i = 0; i < pobjcount; i++)
		{
			if (pobjlist[i].type == POBJ_ARM)
			{
				pobjlist[i].type = POBJ_NOTHING;
			}
		}

		pob = FindFreePObj();
		pob->type = POBJ_DESTROYARMS;
		pob->think = DestroyArms;
		pob->y = 6;
		pob->temp1 = pob->temp2 = 0;	// redundant (already set to 0 by FindFreePObj)
	}
}


/*
=====================
=
= HeartThink
=
=====================
*/

void HeartThink(void)
{
	obon.shapenum = (((Uint16)timecount / 24) & 1) + HEART1SPR;
}


/*
=====================
=
= HeartContact
=
=====================
*/

void HeartContact(objtype *ob, objtype *hit)
{
	Sint16 i;
	pobjtype *pob;

	if (hit->obclass != shotobj)
	{
		return;
	}

	ob->obclass = nothing;	// remove the heart (not really necessary since we remove all objects at the end)

	pob = FindFreePObj();
	pob->type = POBJ_BORDERFLASH;
	pob->think = BorderFlash;
	pob->temp1 = 0;	// redundant (already set to 0 by FindFreePObj)

	GivePoints(1000);

	// remove all "foot" PObjects:
	for (i = 0; i < pobjcount; i++)
	{
		if (pobjlist[i].type == POBJ_FOOT)
		{
			pobjlist[i].type = POBJ_NOTHING;
		}
	}

	pob = FindFreePObj();
	pob->type = POBJ_DESTROYMACHINE;
	pob->think = DestroyManglingMachine;
	pob->y = 2;
	pob->temp1 = pob->temp2 = 0;	// redundant (already set to 0 by FindFreePObj)

	numobj = 1;	// remove all sprite-based objects except for Keen
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
	ob->temp1 = 0;	// redundant (already set to 0 by FindFreeObj)
	ob->contact = NullContact;
	if (RndT() > 0x80)
	{
		ob->shapenum = SHOTSPLASHRSPR;
	}
	else
	{
		ob->shapenum = SHOTSPLASHLSPR;
	}

	SETTILE(x, y, 0, newtile);
}


/*
=====================
=
= DestroyArms
=
=====================
*/

void DestroyArms(pobjtype *pob)
{
	Sint16 x, y;

	pob->temp1 = pob->temp1 + tics;
	if (pob->temp1 >= 30)
	{
		pob->temp1 -= 30;
		if (++pob->y == 19)
		{
			pob->type = POBJ_NOTHING;
		}
		else
		{
			y = pob->y;
			// left arm:
			for (x = 5; x <= 7; x++)
			{
				if (GETTILE(x, y, 0) != 169)
					ExplodeTile(x, y, 169);
			}
			// right arm:
			for (x = 17; x <= 19; x++)
			{
				if (GETTILE(x, y, 0) != 169)
					ExplodeTile(x, y, 169);
			}
		}
	}
}


/*
=====================
=
= DestroyManglingMachine
=
=====================
*/

void DestroyManglingMachine(pobjtype *pob)
{
	Sint16 x, y;

	pob->temp1 = pob->temp1 + tics;
	if (pob->temp1 < 20)
	{
		return;
	}
	
	pob->temp1 -= 20;
	if (++pob->y == 24)
	{
		LevelDone = ex_completed;
		pob->type = POBJ_NOTHING;
		return;
	}
	
	if (pob->y >= 19)
	{
		return;
	}
	
	y = pob->y;
	for (x = 8; x <= 16; x++)
	{
		if (GETTILE(x, y, 0) != 169)
		{
			ExplodeTile(x, y, 169);
		}
	}
}


/*
=====================
=
= ArmThink
=
=====================
*/

void ArmThink(pobjtype *pob)
{
	Sint16 x, y;

	x = pob->x;
	y = pob->y;

	pob->temp2 = pob->temp2 + tics;
	if (pob->temp2 >= pob->temp3)
	{
		pob->temp2 -= pob->temp3;

		// erase old tiles from the map:
		SETTILE(  x,   y, 0, 169);
		SETTILE(x-1,   y, 0, 169);
		SETTILE(x-1, y+1, 0, 169);
		SETTILE(x-1, y+2, 0, 169);
		SETTILE(x+1,   y, 0, 169);
		SETTILE(x+1, y+1, 0, 169);
		SETTILE(x+1, y+2, 0, 169);

		if (pob->temp1 == -1)
		{
			// arm is moving up
			if (GETTILE(x, y-1, 0) != 597)
			{
				// start moving down:
				pob->temp1 = 1;
				pob->temp3 = 15;
			}
			else
			{
				// move up:
				y--;
				pob->y--;
			}
		}
		else
		{
			// arm is moving down
			if (GETTILE(x, y+3, 0) == 471)
			{
				// start moving up:
				pob->temp1 = -1;
				pob->temp3 = 40;
			}
			else
			{
				// move down:
				SETTILE(x, y, 0, 597);
				y++;
				pob->y++;
			}
		}

		// place new tiles:
		SETTILE(  x,   y, 0, 597);
		SETTILE(x-1,   y, 0, 618);
		SETTILE(x-1, y+1, 0, 620);
		SETTILE(x-1, y+2, 0, 619);
		SETTILE(x+1,   y, 0, 618);
		SETTILE(x+1, y+1, 0, 620);
		SETTILE(x+1, y+2, 0, 619);
	}
}


/*
=====================
=
= FootThink
=
=====================
*/

void FootThink(pobjtype *pob)
{
	Sint16 x, y;

	x = pob->x;
	y = pob->y;

	pob->temp2 = pob->temp2 + tics;
	if (pob->temp2 >= 35)
	{
		pob->temp2 -= 35;

		//erase old tiles from the map:
		SETTILE(x, y, 0, 169);
		if (pob->temp3 == -1)
		{
			SETTILE(x-1, y, 0, 169);
			SETTILE(x-2, y, 0, 169);
			SETTILE(x-3, y, 0, 169);
		}
		else
		{
			SETTILE(x+1, y, 0, 169);
			SETTILE(x+2, y, 0, 169);
			SETTILE(x+3, y, 0, 169);
		}

		if (pob->temp1 == -1)
		{
			// foot is moving up
			if (GETTILE(x, y-1, 0) != 597)
			{
				// start moving down:
				pob->temp1 = 1;
			}
			else
			{
				// move up:
				y--;
				pob->y--;
			}
		}
		else
		{
			// foot is moving down
			if (GETTILE(x, y+1, 0) == 430)
			{
				// foot has hit the ground:
				pob->temp1 = -1;	// start moving up (after the pause)
				PlaySound(FOOTSLAMSND);
				pob->think = FootIdle;
				pob->temp2 = 0;
			}
			else
			{
				// move down:
				SETTILE(x, y, 0, 597);
				y++;
				pob->y++;
			}
		}

		// place new tiles:
		if (pob->temp3 == -1)
		{
			SETTILE(  x, y, 0, 622);
			SETTILE(x-1, y, 0, 623);
			SETTILE(x-2, y, 0, 623);
			SETTILE(x-3, y, 0, 621);
		}
		else
		{
			SETTILE(  x, y, 0, 621);
			SETTILE(x+1, y, 0, 623);
			SETTILE(x+2, y, 0, 623);
			SETTILE(x+3, y, 0, 622);
		}
	}
}


/*
=====================
=
= FootIdle
=
=====================
*/

void FootIdle(pobjtype *pob)
{
	pob->temp2 = pob->temp2 + tics;
	if (pob->temp2 > 200)
	{
		pob->temp2 = 0;
		pob->think = FootThink;
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
			obon.xspeed = 0;
	}
	else if (obon.xspeed < 0)
	{
		AccelerateX(3);
		if (obon.xspeed > 0)
			obon.xspeed = 0;
	}

	DoGravity();
	MoveObon();
	PlayerCheckMapBorders();
}

/*
==============================================================================

                                  MESSAGES

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
	// no messages in Keen 3...
}

/*
==============================================================================

                           BOSS INTRO ROUTINES

==============================================================================
*/


/*
=====================
=
= KeenWindow
=
=====================
*/

void KeenWindow(Sint16 width, Sint16 height)
{
	Sint16 xl, yl;

	xl = screencenterx - width/2;
	yl = 20 - height/2;
	DrawWindow(xl, yl, xl+width+1, yl+height+1);
}


/*
=====================
=
= MortWindow
=
=====================
*/

void MortWindow(Sint16 width, Sint16 height)
{
	Sint16 xl, yl;

	xl = screencenterx - width/2;
	yl = 18 - height/2;
	DrawWindow(xl, yl, xl+width+1, yl+height+1);
}


/*
=====================
=
= BossDelay
=
=====================
*/

boolean BossDelay(Sint16 vbls)
{
	Sint16 i, key;

	for (i = 0; i < vbls; i++)
	{
		WaitVBL(1);

		key = NoBiosKey(1) & 0xFF;
		if (key == CHAR_ESCAPE || key == ' ' || JoyButton())
		{
			ClearKeys();
			ctrl2.button1 = ctrl2.button2 = true;
			return true;
		}
	}

	return false;
}


/*
=====================
=
= BossTypeText
=
=====================
*/

boolean BossTypeText(char *text)
{
	char str[2];
	Uint16 i;
	Sint16 key;

	str[1] = 0;	// terminating 0
	for (i = 0; strlen(text) > i; i++)
	{
		str[0] = text[i];
		Print(str);
		WaitVBL(6);

		key = NoBiosKey(1) & 0xFF;
		if (key == CHAR_ESCAPE || key == ' ' || JoyButton())
		{
			ClearKeys();
			return true;
		}
	}

	return false;
}


/*
=====================
=
= BossLevelIntro
=
=====================
*/

//
// some inline macros to make BossLevelIntro easier to read (and modify)
//

#define TYPETEXT(t)     \
{                       \
	if (BossTypeText(t)) \
	{	                  \
		RF_Refresh();     \
		return;           \
	}                    \
}

#define DELAY(t)     \
{                    \
	if (BossDelay(t)) \
	{	               \
		RF_Refresh();  \
		return;        \
	}                 \
}

void BossLevelIntro(void)
{
	sparksgone = 0;
	PlaySound(MORTIMERSND);
	PlaySound(DOOROPENSND);	// only one sound is actually played, depending on the priorities
	WaitEndSound();

	KeenWindow(5, 1);
	RF_ForceRefresh();
	TYPETEXT("No...");
	DELAY(180);
	RF_Refresh();

	RF_ForceRefresh();
	KeenWindow(12, 1);
	TYPETEXT("It can't be!");
	DELAY(180);
	RF_Refresh();

	RF_ForceRefresh();
	KeenWindow(18, 1);
	TYPETEXT("MORTIMER McMIRE!!!");
	DELAY(240);
	RF_Refresh();

	RF_ForceRefresh();
	KeenWindow(38, 5);
	TYPETEXT("Mortimer has been a thorn in your side\n");
	TYPETEXT("for as long as you can remember.  Your\n");
	TYPETEXT("IQ test score was 314--Mortimer's was\n");
	TYPETEXT("315.  He always held that over you,\n");
	TYPETEXT("never letting you forget for one day.\n");
	DELAY(240);
	RF_Refresh();

	RF_ForceRefresh();
	KeenWindow(38, 5);
	TYPETEXT("All the practical jokes, the mental\n");
	TYPETEXT("cruelty, the swirlies--each memory\n");
	TYPETEXT("makes your teeth grit harder.  And now\n");
	TYPETEXT("he's out to destroy earth!  You have\n");
	TYPETEXT("had enough!\n");
	DELAY(240);
	RF_Refresh();

	RF_ForceRefresh();
	KeenWindow(31, 2);
	TYPETEXT("\"ALL RIGHT MORTIMER, WHAT'S THE\n");
	TYPETEXT("PROBLEM?  WHY DESTROY EARTH?\"\n");
	DELAY(180);
	RF_Refresh();

	RF_ForceRefresh();
	MortWindow(35, 4);
	TYPETEXT("\"You and all those mental wimps\n");
	TYPETEXT("deserve to die!  I'm the smartest\n");
	TYPETEXT("person in the galaxy.  Aren't I,\n");
	TYPETEXT("mister THREE FOURTEEN! Ah ha ha!\"");
	DELAY(180);
	RF_Refresh();

	RF_ForceRefresh();
	KeenWindow(34, 1);
	TYPETEXT("\"I'll get you for that, Mortimer!\"");
	DELAY(180);
	RF_Refresh();

	RF_ForceRefresh();
	MortWindow(38, 3);
	TYPETEXT("\"Come and try!  You'll never get past\n");
	TYPETEXT("my hideous Mangling Machine!  Prepare\n");
	TYPETEXT("to die, Commander Clown!\"");
	DELAY(240);
	RF_Refresh();
}

/*
==============================================================================

                           FINALE ANIMATION

==============================================================================
*/


/*
=====================
=
= PhotoFlash
=
=====================
*/

void PhotoFlash(void)
{
	Uint8 pal[17] =	// Note: making this 'static' would be more efficient
	{
		0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
		0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 3
	};

	// apply bright palette:
	_ES = FP_SEG(pal);
	_DX = FP_OFF(pal);
	_AX = 0x1002;
	geninterrupt(0x10);

	PlaySound(CLICKSND);
	WaitEndSound();
	WaitVBL(2);

	// apply normal palette:
	_ES = FP_SEG(colors[3]);
	_DX = FP_OFF(colors[3]);
	_AX = 0x1002;
	geninterrupt(0x10);
}


/*
=====================
=
= DoFinale
=
=====================
*/

#define TAKEPHOTO(x, y, t1, t2, delay) \
{                                      \
	SETTILE(x, y, 0, t1);               \
	RF_Refresh();                       \
	PhotoFlash();                       \
	SETTILE(x, y, 0, t2);               \
	RF_Refresh();                       \
	WaitVBL(delay);                     \
}

void DoFinale(void)
{
	ReadLevel(ENDINGMAP);

	originx = originy = 2*TILEGLOBAL;
	RF_Clear();
	RF_ForceRefresh();
	RF_PlaceSprite(224*PIXGLOBAL,  96*PIXGLOBAL, GRUNTRIGHT1SPR);
	RF_PlaceSprite(248*PIXGLOBAL, 104*PIXGLOBAL, KEENWALKR1SPR);
	RF_Refresh();
	FadeIn();

	DrawWindow(4, 18, 43, 23);
	TypeText("With Mortimer McMire out of the       \n");
	TypeText("picture, and his brain-wave belts no\n");
	TypeText("longer controlling them, the Vorticons\n");
	TypeText("are freed of their mental enslavement.\n");
	WaitVBL(120);

	RF_ForceRefresh();
	RF_Refresh();

	DrawWindow(4, 18, 43, 22);
	TypeText("\"Commander Keen, in honor of your     \n");
	TypeText("meritorious service in freeing us from\n");
	TypeText("the Grand Intellect's mental chains,\"\n");
	WaitVBL(120);

	RF_ForceRefresh();
	RF_Refresh();

	DrawWindow(4, 18, 43, 22);
	TypeText("\"I and the other Vorticons you haven't\n");
	TypeText("slaughtered want to award you the     \n");
	TypeText("Big V, our highest honor.\"\n");
	WaitVBL(120);

	RF_ForceRefresh();
	RF_Refresh();

	DrawWindow(17, 18, 30, 20);
	TypeText("\"Thank you!\"\n");
	WaitVBL(120);

	TAKEPHOTO(19, 5, 58, 72, 20);
	TAKEPHOTO( 3, 8, 60, 61, 10);
	TAKEPHOTO( 5, 8, 60, 61,  5);
	TAKEPHOTO(20, 5, 58, 72, 10);
	TAKEPHOTO( 8, 8, 60, 61, 15);

	WaitVBL(120);

	FadeOut();
	originx &= 0xFFFF000;	// BUG: should use 0xFFFFF000 here, i.e., ~(TILEGLOBAL-1)
	RF_Refresh();
	DrawPicFile("finale.ck3");
	FadeIn();
	ReadLevel(ENDINGMAP);	// reload level (DrawPicFile trashes the level data!)
	originx = originy = 2*TILEGLOBAL;
	WaitVBL(400);

	DrawWindow(18, 20, 29, 24);
	TypeText("The End...\n For now!\n");
	Print("    ");
	ClearKeys();
	Get();

	// normalize horizontal screen position (for DrawTextScreen/ShowText)
	TILE_ALIGN(originx);
	RF_ForceRefresh();
	RF_Refresh();
	RF_Refresh();
	DrawTextScreen(endtextPtr, 0, 22);
	PlaySound(KEENSLEFTSND);
	WaitEndSound();
	PlaySound(MORTIMERSND);
	ShowText(endtextPtr, 0, 22);
	RF_ForceRefresh();
}

#include "KEENACTS.C"
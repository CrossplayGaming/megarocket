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
				SpawnYorp(x, y);
				break;

			case 2:
				SpawnGarg(x, y);
				break;

			case 3:
				SpawnVorticon(x, y);
				break;

			case 4:
				SpawnButler(x, y);
				break;

			case 5:
				SpawnTank(x, y);
				break;

			case 6:
				SpawnCannon(x, y, 0);
				break;

			case 7:
				SpawnCannon(x, y, 1);
				break;

			case 8:
				SpawnCannon(x, y, 2);
				break;

			case 9:
				SpawnCannon(x, y, 3);
				break;

			case 10:
				SpawnChain(x, y);
				break;

			case 255:
				// Keen is always object 0, just update the position:
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
= SpawnTank
=
=====================
*/

void SpawnTank(Sint16 x, Sint16 y)
{
	objtype *ob;
	
	ob = FindFreeObj();
	ob->obclass = tankobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y) + 8*PIXGLOBAL;
	ob->xspeed = 90;

	// object starts out moving AWAY from Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x < objlist[0].x)
	{
		ob->xspeed = -ob->xspeed;
	}

#if VERSION < VER_100
	ob->think = TankMove;
#else
	ob->think = TankFall;
#endif
	ob->contact = TankContact;
	ob->shapenum = TANKSTAND1SPR;
}


/*
=====================
=
= SpawnButler
=
=====================
*/

void SpawnButler(Sint16 x, Sint16 y)
{
	objtype *ob;
	
	ob = FindFreeObj();
	ob->obclass = butlerobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->xspeed = 90;

	// object starts out moving AWAY from Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x < objlist[0].x)
	{
		ob->xspeed = -ob->xspeed;
	}

	ob->think = ButlerWalk;
	ob->contact = ButlerContact;
	ob->shapenum = CANSTAND1SPR;
}


/*
=====================
=
= SpawnVorticon
=
=====================
*/

void SpawnVorticon(Sint16 x, Sint16 y)
{
	objtype *ob;
	
	ob = FindFreeObj();
	ob->obclass = vorticonobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = VorticonWalk;
	ob->contact = VorticonContact;
	ob->health = 3;
	if (level == 16)
	{
		ob->health = 104;
	}

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

	ob->shapenum = VORTSTAND1SPR;
}


/*
=====================
=
= SpawnGarg
=
=====================
*/

void SpawnGarg(Sint16 x, Sint16 y)
{
	objtype *ob;
	
	ob = FindFreeObj();
	ob->obclass = gargobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = GargStand;
	ob->contact = GargContact;
	ob->shapenum = GARGSTAND1SPR;
}


/*
=====================
=
= SpawnYorp
=
=====================
*/

void SpawnYorp(Sint16 x, Sint16 y)
{
	objtype *ob;
	
	ob = FindFreeObj();
	ob->obclass = yorpobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y) + 8*PIXGLOBAL;
	ob->think = YorpWalk;

	// object starts out moving TOWARDS Keen (doesn't work correctly
	// when object is spawned before Keen is spawned!)
	if (ob->x < objlist[0].x)
	{
		ob->xspeed = 60;
	}
	else
	{
		ob->xspeed = -60;
	}

	ob->contact = YorpContact;
	ob->shapenum = YORPSTAND1SPR;
}


/*
=====================
=
= SpawnChain
=
=====================
*/

void SpawnChain(Sint16 x, Sint16 y)
{
	objtype *ob;
	
	ob = FindFreeObj();
	ob->obclass = chainobj;
	ob->x = TILE_TO_GLOBAL(x);
	ob->y = TILE_TO_GLOBAL(y);
	ob->think = NullThink;
	ob->contact = ChainContact;
	ob->shapenum = CHAINSPR;
}


/*
=====================
=
= SpawnCannon
=
=====================
*/

void SpawnCannon(Sint16 x, Sint16 y, Sint16 num)
{
	pobjtype *pob;

	pob = FindFreePObj();
	pob->type = POBJ_CANNON;
	pob->think = CannonThink;
	pob->temp1 = num;
	pob->x = x;
	pob->y = y;
}

/*
==============================================================================

                           YORP ROUTINES
	
==============================================================================
*/


/*
=====================
=
= YorpWalk
=
=====================
*/

void YorpWalk(void)
{
	Sint16 block;

	if (obon.yspeed == 0)	// neither jumping nor falling?
	{
		// randomly start jumping or standing still
		if (RndT() < tics)
		{
			obon.yspeed = -Rnd(128);
		}
		else if (RndT() < tics)
		{
			obon.think = YorpStand;
			obon.temp1 = 0;
		}
	}

	if (obon.xspeed > 0)
	{
		obon.shapenum = YORPRIGHT1SPR;
	}
	else
	{
		obon.shapenum = YORPLEFT1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 1);

	DoGravity();
	block = MoveObon();
	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -60;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 60;
	}
}


/*
=====================
=
= YorpStand
=
=====================
*/

void YorpStand(void)
{
	obon.xspeed = 0;
	obon.shapenum = (((Uint16)timecount >> 5) & 3) + YORPSTAND1SPR;
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 >= 200)	// Yorps stand still for about 1.4 seconds
	{
		// start walking towards Keen
		if (obon.x < objlist[0].x)
		{
			obon.xspeed = 60;
		}
		else
		{
			obon.xspeed = -60;
		}
		obon.think = YorpWalk;
		// BUG: xspeed should be set AFTER calling MoveObon()
	}
	DoGravity();
	MoveObon();
}


/*
=====================
=
= YorpStunned
=
=====================
*/

void YorpStunned(void)
{
	obon.shapenum = (((Uint16)timecount >> 4) & 1) + YORPSTUN1SPR;
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 >= 800)	// Yorps are stunned for about 5.5 seconds
	{
		obon.temp1 = 0;
		obon.think = YorpStand;
	}
	obon.xspeed = 0;
	DoGravity();
	MoveObon();
}


/*
=====================
=
= YorpContact
=
=====================
*/

void YorpContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj || hit->obclass == enemyshotobj)
	{
		ob->temp1 = 0;
		ob->temp2 = 2;
		ob->shapenum = YORPCORPSE1SPR;
		ob->think = DyingThink;
		ob->contact = NullContact;
		ob->yspeed = -80;
		PlaySound(YORPSCREAMSND);
	}
	// Note: Yorps pushing Keen is handled in KeenContact
}

/*
==============================================================================

                           GARG ROUTINES
	
==============================================================================
*/


/*
=====================
=
= GargWalk
=
=====================
*/

void GargWalk(void)
{
	Sint16 block;

	// if neither jumping nor falling nor running
	// then randomly start standing still
	if (obon.yspeed == 0 && obon.xspeed > -220 && obon.xspeed < 220 && RndT() < tics)
	{
		obon.think = GargStand;
		obon.temp1 = 0;
	}

	if (obon.xspeed > 0)
	{
		obon.shapenum = GARGRIGHT1SPR;
	}
	else
	{
		obon.shapenum = GARGLEFT1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 1);

	DoGravity();
	block = MoveObon();
	if (block & BLOCK_RIGHT)
	{
		obon.xspeed = -60;
	}
	if (block & BLOCK_LEFT)
	{
		obon.xspeed = 60;
	}

	if (block & BLOCK_DOWN)
	{
		obon.temp1 = 0;
	}
	else if (abs(obon.xspeed) == 220 && obon.temp1 == 0)	// running but not yet jumping?
	{
		// start jumping
		obon.temp1 = 1;
		obon.yspeed = -200;
	}
}


/*
=====================
=
= GargStand
=
=====================
*/

void GargStand(void)
{
	obon.xspeed = 0;
	obon.shapenum = (((Uint16)timecount >> 5) & 3) + GARGSTAND1SPR;
	obon.temp1 = obon.temp1 + tics;
	DoGravity();
	MoveObon();

	if (obon.temp1 >= 80)
	{
		if (obon.y + 8*PIXGLOBAL == objlist[0].y)	// if on same ground level as Keen
		{
			obon.xspeed = 220;	// start running
		}
		else
		{
			obon.xspeed = 60;
		}

		// run/walk towards Keen
		if (obon.x > objlist[0].x)
		{
			obon.xspeed = -obon.xspeed;
		}

		obon.think = GargWalk;
	}
}


/*
=====================
=
= GargContact
=
=====================
*/

void GargContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj || hit->obclass == enemyshotobj)
	{
		ob->temp1 = 0;
		ob->temp2 = 2;
		ob->shapenum = GARGCORPSE1SPR;
		ob->think = DyingThink;
		ob->contact = NullContact;
		ob->yspeed = -80;
		PlaySound(GARGSCREAMSND);
	}
}

/*
==============================================================================

                           VORTICON ROUTINES
	
==============================================================================
*/


/*
=====================
=
= VorticonWalk
=
=====================
*/

void VorticonWalk(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = VORTRIGHT1SPR;
	}
	else
	{
		obon.shapenum = VORTLEFT1SPR;
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 3);

	if (RndT() < tics << 1)
	{
		obon.yspeed = -Rnd(300);
		obon.think = VorticonJump;
	}
	else if (RndT() < tics << 1)
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
}


/*
=====================
=
= VorticonJump
=
=====================
*/

void VorticonJump(void)
{
	Sint16 block;

	if (obon.xspeed > 0)
	{
		obon.shapenum = VORTJUMPLSPR;
	}
	else
	{
		obon.shapenum = VORTJUMPRSPR;
	}

	DoGravity();
	block = MoveObon();
	if (block & BLOCK_DOWN)
	{
		obon.think = VorticonStand;
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
= VorticonStand
=
=====================
*/

void VorticonStand(void)
{
	obon.xspeed = 0;
	obon.shapenum = (((Uint16)timecount >> 5) & 3) + VORTSTAND1SPR;
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 >= 80)
	{
		obon.xspeed = 90;
		if (obon.x > objlist[0].x)
		{
			obon.xspeed = -obon.xspeed;
		}
		obon.think = VorticonWalk;
		// BUG: xspeed should be set AFTER calling MoveObon()
	}
	DoGravity();
	MoveObon();
}


/*
=====================
=
= VorticonContact
=
=====================
*/

void VorticonContact(objtype *ob, objtype *hit)
{
	pobjtype *pob;

	if (hit->obclass == shotobj || hit->obclass == enemyshotobj)
	{
		if (ob->health-- == 0)
		{
			PlaySound(VORTSCREAMSND);
			ob->temp1 = 0;
			ob->temp2 = 6;
			ob->shapenum = VORTDIE1SPR;
			ob->contact = NullContact;
			ob->think = DyingThink;

			pob = FindFreePObj();
			pob->type = POBJ_BORDERFLASH;
			pob->think = BorderFlash;
			pob->temp1 = 0;
		}
	}
}

/*
==============================================================================

                           BUTLER ROUTINES
	
==============================================================================
*/


/*
=====================
=
= ButlerWalk
=
=====================
*/

void ButlerWalk(void)
{
	Sint16 block;

	// Note: Butler sprites are mislabeled (left and right sprites are swapped)!
	if (obon.xspeed > 0)
	{
		obon.shapenum = CANLEFT1SPR;	// actually right-facing sprites!
	}
	else
	{
		obon.shapenum = CANRIGHT1SPR;	// actually left-facing sprites!
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 5) & 3);

	DoGravity();
	block = MoveObon();
	if (!(block & BLOCK_DOWN))
	{
		obon.xmove = -obon.xmove*2;
		obon.ymove = 0;
		obon.temp2 = -obon.xspeed;
		obon.think = ButlerStand;
		obon.temp1 = obon.xspeed = 0;
	}
	if (block & BLOCK_RIGHT)
	{
		obon.temp2 = -90;
		obon.think = ButlerStand;
		obon.temp1 = obon.xspeed = 0;
	}
	if (block & BLOCK_LEFT)
	{
		obon.temp2 = 90;
		obon.think = ButlerStand;
		obon.temp1 = obon.xspeed = 0;
	}
}


/*
=====================
=
= ButlerStand
=
=====================
*/

void ButlerStand(void)
{
#if VERSION < VER_100
	Sint16 block;
#endif

	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 50)
	{
		obon.think = ButlerWalk;
		obon.xspeed = obon.temp2;
	}
	obon.shapenum = (((Uint16)timecount >> 5) & 1) + CANSTAND1SPR;
	DoGravity();
#if VERSION < VER_100
	block = MoveObon();
#else
	MoveObon();
#endif
}


/*
=====================
=
= ButlerContact
=
=====================
*/

void ButlerContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == shotobj)
	{
		ob->temp1 = 0;
	}
}

/*
==============================================================================

                           TANK ROUTINES
	
==============================================================================
*/


/*
=====================
=
= TankMove
=
=====================
*/

void TankMove(void)
{
	Sint16 block;

	// Note: Tank sprites are mislabeled (left and right sprites are swapped)!
	if (obon.xspeed > 0)
	{
		obon.shapenum = TANKLEFT1SPR;	// actually right-facing sprites!
	}
	else
	{
		obon.shapenum = TANKRIGHT1SPR;	// actually left-facing sprites!
	}
	obon.shapenum = obon.shapenum + (((Uint16)timecount >> 3) & 3);

	if (RndT() < tics)
	{
		obon.think = TankFire;
		obon.temp1 = 0;
		obon.temp2 = 0;
		obon.temp3 = obon.xspeed;
		obon.xspeed = 0;
	}

	DoGravity();
	block = MoveObon();
#if VERSION < VER_100
	if (block & BLOCK_RIGHT)
	{
		obon.temp2 = -90;
		obon.think = TankStand;
		obon.temp1 = obon.xspeed = 0;
	}
	if (block & BLOCK_LEFT)
	{
		obon.temp2 = 90;
		obon.think = TankStand;
		obon.temp1 = obon.xspeed = 0;
	}
	if (!(block & BLOCK_DOWN))
	{
		obon.xmove = -obon.xmove * 2;
		obon.ymove = 0;
		obon.temp2 = -obon.xspeed;
		obon.think = TankStand;
		obon.temp1 = obon.xspeed = 0;
	}
#else
	obon.ymove = obon.yspeed = 0;
	if (!(block & BLOCK_DOWN))
	{
		if (obon.shapenum < TANKRIGHT1SPR)
		{
			obon.xmove = tics * -180;
			obon.temp2 = -90;
		}
		else
		{
			obon.xmove = tics * 180;
			obon.temp2 = 90;
		}
		obon.think = TankStand;
		obon.temp1 = obon.xspeed = 0;
	}
	else
	{
		if (block & BLOCK_RIGHT)
		{
			obon.temp2 = -90;
			obon.think = TankStand;
			obon.temp1 = obon.xspeed = 0;
		}
		if (block & BLOCK_LEFT)
		{
			obon.temp2 = 90;
			obon.think = TankStand;
			obon.temp1 = obon.xspeed = 0;
		}
	}
#endif
}


/*
=====================
=
= TankFall
=
=====================
*/

#if VERSION >= VER_100
void TankFall(void)
{
	Sint16 block;

	DoGravity();
	block = MoveObon();
	if (block & BLOCK_DOWN)
	{
		obon.think = TankMove;
	}
}
#endif


/*
=====================
=
= TankStand
=
=====================
*/

void TankStand(void)
{
#if VERSION < VER_100
	Sint16 block;
	
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 50)
	{
		obon.think = TankMove;
		obon.xspeed = obon.temp2;
	}
	obon.shapenum = (((Uint16)timecount >> 4) & 1) + TANKSTAND1SPR;
	DoGravity();
	block = MoveObon();
	
#else
	
	obon.temp1 = obon.temp1 + tics;
	obon.shapenum = (((Uint16)timecount >> 4) & 1) + TANKSTAND1SPR;
	if (obon.temp1 > 50)
	{
		obon.think = TankMove;
		obon.xspeed = obon.temp2;
	}
	
#endif
}


/*
=====================
=
= TankFire
=
=====================
*/

void TankFire(void)
{
	Sint16 speed;

	obon.temp1 = obon.temp1 + tics;
	if (obon.temp2 == 0 && obon.temp1 > 80)
	{
		PlaySound(TANKFIRESND);
		speed = 350;
		if (obon.temp3 < 0)	// if Tank is facing left
		{
			speed = -350;
		}
		SpawnEnemyShot(obon.x, obon.y, speed);
		obon.temp2 = 1;	// shot has been spawned
	}
	
#if VERSION < VER_100
	DoGravity();
	MoveObon();
#endif

	if (obon.temp1 > 120)
	{
		obon.temp2 = 90;
		if (obon.x > objlist[0].x)
		{
#if VERSION < VER_100
			obon.temp2 = -obon.temp2;
#else
			obon.temp2 = -90;
#endif
		}
		obon.temp1 = 0;
		obon.think = TankStand;
	}
}


/*
=====================
=
= TankContact
=
=====================
*/

#pragma argsused
void TankContact(objtype *ob, objtype *hit)
{
	// do nothing
}

/*
==============================================================================

                           CANNON & ICE ROUTINES

==============================================================================
*/


/*
=====================
=
= CannonThink
=
=====================
*/

void CannonThink(pobjtype *pob)
{
	Sint16 x, y;

	if ((Uint16)timecount >> 7 != pob->temp2)
	{
		pob->temp2 = (Uint16)timecount >> 7;
		x = pob->x;
		y = pob->y;

		if (ox-4 < x && oy-4 < y && ox+24 > x && oy+14 > y)
		{
			PlaySound(CANNONFIRESND);
			SpawnIceball(TILE_TO_GLOBAL(pob->x), TILE_TO_GLOBAL(pob->y), pob->temp1);
		}
	}
}


/*
=====================
=
= SpawnIceball
=
=====================
*/

void SpawnIceball(Sint32 x, Sint32 y, Sint16 direction)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = iceballobj;
	ob->x = x;
	ob->y = y;
	ob->think = IceballThink;

	switch (direction)
	{
	case 0:
		ob->x += TILEGLOBAL;
		ob->yspeed = -200;
		ob->xspeed = 200;
		break;

	case 1:
		ob->yspeed = -200;
		ob->xspeed = 0;
		break;

	case 2:
		ob->yspeed = 200;
		ob->xspeed = 0;
		break;

	case 3:
		ob->yspeed = -200;
		ob->xspeed = -200;
		break;
	}

	ob->contact = IceballContact;
	ob->shapenum = ICESHOTSPR;
}


/*
=====================
=
= IcechunkThink
=
=====================
*/

void IcechunkThink(void)
{
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 60)
	{
		obon.obclass = nothing;
	}
	else
	{
		DoGravity();
		// move object (chunks don't need clipping):
		obon.xmove = obon.xmove + obon.xspeed*tics;
		obon.ymove = obon.ymove + obon.yspeed*tics;
	}
}


/*
=====================
=
= IceballThink
=
=====================
*/

void IceballThink(void)
{
	Sint16 block;
	objtype *ob;

	block = MoveObon();
	if (block)
	{
		obon.obclass = nothing;

		ob = FindFreeObj();
		ob->obclass = icechunkobj;
		ob->think = IcechunkThink;
		ob->contact = NullContact;
		ob->x = obon.x;
		ob->y = obon.y;
		ob->xspeed = 300;
		ob->yspeed = 300;
		ob->shapenum = ICECHUNKSPR;

		ob = FindFreeObj();
		ob->obclass = icechunkobj;
		ob->think = IcechunkThink;
		ob->contact = NullContact;
		ob->x = obon.x;
		ob->y = obon.y;
		ob->xspeed = 300;
		ob->yspeed = -300;
		ob->shapenum = ICECHUNKSPR;

		ob = FindFreeObj();
		ob->obclass = icechunkobj;
		ob->think = IcechunkThink;
		ob->contact = NullContact;
		ob->x = obon.x;
		ob->y = obon.y;
		ob->xspeed = -300;
		ob->yspeed = 300;
		ob->shapenum = ICECHUNKSPR;

		ob = FindFreeObj();
		ob->obclass = icechunkobj;
		ob->think = IcechunkThink;
		ob->contact = NullContact;
		ob->x = obon.x;
		ob->y = obon.y;
		ob->xspeed = -300;
		ob->yspeed = -300;
		ob->shapenum = ICECHUNKSPR;

		PlaySound(CHUNKSMASHSND);
	}
}


/*
=====================
=
= IceballContact
=
=====================
*/

void IceballContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == keenobj)
	{
		ob->think = RemoveThink;
	}
	// Note: freezing Keen is handled in KeenContact
}


/*
==============================================================================

                           CHAIN & BLOCK ROUTINES
	
==============================================================================
*/


/*
=====================
=
= ChainContact
=
=====================
*/

void ChainContact(objtype *ob, objtype *hit)
{
	pobjtype *pob;

	if (hit->obclass == shotobj)
	{
		ob->think = ShotSplash;
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

		// spawn the falling block object:
		pob = FindFreePObj();
		pob->type = POBJ_BLOCKFALL;
		pob->think = BlockFall;
		pob->x = GLOBAL_TO_TILE(ob->x);
		pob->y = GLOBAL_TO_TILE(ob->y) + 1;
		pob->temp1 = 0;

		// kill the vorticon:
		
		// BUG: The following loop will either never end or lead to memory
		// corruption if the level doesn't have any Vorticons in it. Killing the
		// Vorticon "Commander" in the last level and then shooting the chain
		// will cause this problem. Also, the ob pointer starts out pointing to
		// an unused object slot. This could become a problem when the object
		// list is full (ob will initially point to the memory that follows after
		// the objlist array).
		ob = objlist + numobj;	// should really be objlist + numobj - 1
		while (ob->obclass != vorticonobj)
		{
			ob--;
		}
		PlaySound(VORTSCREAMSND);
		ob->temp1 = 0;
		ob->temp2 = 6;
		ob->shapenum = VORTDIE1SPR;
		ob->contact = NullContact;
		ob->think = DyingThink;
	}
}


/*
=====================
=
= BlockFall
=
=====================
*/

void BlockFall(pobjtype *pob)
{
	Sint16 x;

	if ((Uint16)timecount/32 == pob->temp2)
	{
		return;
	}
	
	pob->temp2 = (Uint16)timecount/32;

	// left side:
	x = pob->x - 4;
	SETTILE(x, pob->y, 0, 155);	// erase old top
	SETTILE(x, pob->y+1, 0, 476);	// place new top (replaces old bottom)
	SETTILE(x, pob->y+2, 0, 489);	// place new bottom
	// middle section:
	for (x = pob->x - 3; x <= pob->x + 3; x++)
	{
		SETTILE(x, pob->y, 0, 155);	// erase old top
		SETTILE(x, pob->y+1, 0, 477);	// place new top (replaces old bottom)
		SETTILE(x, pob->y+2, 0, 490);	// place new bottom
	}
	// right side:
	x = pob->x + 4;
	SETTILE(x, pob->y, 0, 155);	// erase old top
	SETTILE(x, pob->y+1, 0, 478);	// place new top (replaces old bottom)
	SETTILE(x, pob->y+2, 0, 491);	// place new bottom

	pob->y++;
	pob->temp1++;
	if (pob->temp1 == 4)
	{
		pob->type = POBJ_NOTHING;
	}
}

/*
==============================================================================

                           YORP/GARG STATUE MESSAGES
	
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
#if VERSION < VER_100
	CenterWindow(20, 10);
#else
	CenterWindow(21, 10);
#endif

	switch (level)
	{
	case 2:
#if VERSION < VER_100
		Print("You hear in your    \n");
		Print("mind:               \n");
		Print("                    \n");
		Print("In war, do not fire \n");
		Print("all your gleebs in  \n");
		Print("the first ten nooms.\n");
		Print("Do not waste gleebs.\n");
#else
		Print("You hear in your    \n");
		Print("mind:               \n");
		Print("                    \n");
		Print("It is too bad that  \n");
		Print("you cannot read the \n");
		Print("Standard Galactic   \n");
		Print("Alphabet, human.    \n");
#endif
		break;

	case 6:
		Print("A message echoes in \n");
		Print("your head:          \n");
		Print("                    \n");
		Print("The teleporter in   \n");
		Print("the ice will send   \n");
		Print("you to the dark side\n");
		Print("of Mars.            \n");
		break;

	case 9:
		Print("A voice buzzes in   \n");
		Print("your mind:          \n");
		Print("                    \n");
		Print("There is a hidden   \n");
		Print("city. Look in the   \n");
		Print("dark area of the    \n");
		Print("city to the south.  \n");
		break;

	case 10:
		Print("You see these words \n");
		Print("in your head:       \n");
		Print("                    \n");
		Print("You will need a     \n");
		Print("raygun in the end,  \n");
		Print("but not to shoot the\n");
		Print("Vorticon...         \n");
		break;

	case 11:
		Print("You hear in your    \n");
		Print("mind:               \n");
		Print("                    \n");
		Print(" GAAARRRRRGG!       \n");
		break;

	case 12:
		Print("A Yorpish whisper   \n");
		Print("says:               \n");
		Print("                    \n");
		Print("Look for dark, hidden\n");
		Print("bricks. You can see \n");
		Print("naught but their    \n");
		Print("upper left corner.  \n");
		break;

	case 15:
		Print("A Yorpy mind-thought\n");
		Print("bellows:            \n");
		Print("                    \n");
		Print("You cannot kill the \n");
		Print("Vorticon Commander  \n");
		Print("directly.           \n");
		break;
	}

	sy = screencentery + 5;
	PrintC("Press ENTER:");
	ClearKeys();
	while ((Get() & 0xFF) != CHAR_ENTER) /* do nothing */ ;

	RF_ForceRefresh();
	ClearKeys();
	timecount = oldtime;
}

/*
==============================================================================

                           KEENSICLE ROUTINES
	
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
		if (obon.temp1 < -50)
		{
			obon.think = KeenWalk;
		}
	}
	DoGravity();
	MoveObon();
	PlayerCheckMapBorders();
}

#include "KEENACTS.C"

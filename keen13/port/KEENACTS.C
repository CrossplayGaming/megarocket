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

//
// NOTE: This file will get included in each episode's KEEN?ACT.C file.
//

/*
==============================================================================

	GLOBALS

==============================================================================
*/

Sint16 itemScores[] = {500, 100, 200, 1000, 5000};

objtype obon;

ControlStruct ctrl, ctrl2;

pobjtype pobjlist[MAXPOBJECTS];
Sint16 pobjcount;

Sint16 switchxtile, switchytile;
boolean lightson;

objtype obon;

#if VERSION > VER_100
Sint16 ankhtime;
#endif

#if (VERSION >= VER_120)
Sint16 sparksgone;
#endif
boolean buttontouched;

/*
==============================================================================

                           ACTOR & OBJECT ROUTINES

==============================================================================
*/


/*
=====================
=
= DoorThink
=
=====================
*/

void DoorThink(pobjtype *pob)
{
	Sint16 y;

	pob->temp1 = pob->temp1 + tics;

	y = pob->temp1 / 5;
	if (y > 32)
	{
		y = 32;
		pob->type = POBJ_NOTHING;	// remove the door object
	}

	// draw the sinking door tiles:
	RF_PlaceTile(pob->x, pob->y + y*(Sint16)PIXGLOBAL, pob->temp4);
	RF_PlaceTile(pob->x, pob->y + y*(Sint16)PIXGLOBAL + TILEGLOBAL, pob->temp4 + 1);
	// draw the two tiles below the door as foreground tiles:
	RF_PlaceTile(pob->x, pob->y + 2*TILEGLOBAL, pob->temp3);
	RF_PlaceTile(pob->x, pob->y + 3*TILEGLOBAL, pob->temp2);
}


/*
=====================
=
= OpenDoor
=
=====================
*/

void OpenDoor(Sint16 x, Sint16 y)
{
	pobjtype *pob;
	Sint16 ty;
	Sint16 tiletype1, tiletype2;

	PlaySound(DOOROPENSND);

	// get top of door:
	tiletype1 = intile[GETTILE(x, y, 0)];
	tiletype2 = intile[GETTILE(x, y-1, 0)];
	if (tiletype2 == tiletype1)
	{
		ty = y-1;
	}
	else
	{
		ty = y;
	}

	// spawn a sinking door object:
	pob = FindFreePObj();
	pob->type = POBJ_OPENDOOR;
	pob->think = DoorThink;
	pob->x = TILE_TO_GLOBAL(x);
	pob->y = TILE_TO_GLOBAL(ty);
	pob->temp1 = 0;
	pob->temp2 = GETTILE(x, ty+3, 0);
	pob->temp3 = GETTILE(x, ty+2, 0);
	pob->temp4 = GETTILE(x, ty, 0);

	// lose the key:
	gamestate.keys[tiletype1-2] = false;	// tiletype 2 takes key 0, tiletype 3 takes key 1 and so on

	// remove the door tiles from the map:
#if (EPISODE != 3)
	SETTILE(x, ty, 0, 143);
	SETTILE(x, ty+1, 0, 143);
#else
	tiletype1 = GETTILE(x-1, ty, 0);
	SETTILE(x, ty, 0, tiletype1);
	SETTILE(x, ty+1, 0, tiletype1);
#endif
}


/*
=====================
=
= RemoveThink
=
=====================
*/

void RemoveThink(void)
{
	obon.obclass = nothing;
}


/*
=====================
=
= BadThink
=
=====================
*/

void BadThink(void)
{
	Quit("Bad think pointer!");
}


/*
=====================
=
= BadContact
=
=====================
*/

#pragma argsused
void BadContact(objtype *ob, objtype *hit)
{
	Quit("Bad contact pointer!");
}


/*
=====================
=
= FindFreeObj
=
=====================
*/

objtype *FindFreeObj(void)
{
	Sint16 i;
	objtype *ob;

	i = 1;
	ob = &objlist[1];	// always skip slot 0 (reserved for Keen)
	
	while (ob->obclass != nothing && i < numobj)
	{
		i++;
		ob++;
	}

	if (i >= numobj)
	{
		numobj++;
	}
	
	// WARNING: There are no safety measures to prevent the code from adding a
	// new object entry when the objlist is already full! This will lead to
	// memory corruption (the data following after objlist will be overwritten
	// with a new objtype entry).

	// initialize object:
	memset(ob, 0, sizeof(objtype));
	ob->think = BadThink;
	ob->contact = BadContact;
	ob->active = true;

	return ob;
}


/*
=====================
=
= FindFreePObj
=
=====================
*/

pobjtype *FindFreePObj(void)
{
	Sint16 i;
	pobjtype *pob;

	i = 0;
	pob = &pobjlist[0];

	while (pob->type != POBJ_NOTHING && i < pobjcount)
	{
		i++;
		pob++;
	}

	if (i >= pobjcount)
	{
		pobjcount++;
	}
	
	// WARNING: There are no safety measures to prevent the code from adding a
	// new "PObj" entry when the pobjlist is already full! This will lead to
	// memory corruption (the data following after pobjlist will be overwritten
	// with a new pobjtype entry).

	// initialize object:
	memset(pob, 0, sizeof(pobjtype));
	pob->think = (pobjthink)BadThink;

	return pob;
}


/*
=====================
=
= ObjectsCollide
=
=====================
*/

boolean ObjectsCollide(objtype *ob1, objtype *ob2)
{
	if (!ob1->left || !ob2->left)
	{
		return false;	// no hitbox data
	}

	if (ob1->right < ob2->left)
	{
		return false;
	}
	if (ob1->bottom < ob2->top)
	{
		return false;
	}
	if (ob1->left > ob2->right)
	{
		return false;
	}
	if (ob1->top > ob2->bottom)
	{
		return false;
	}

	return true;
}


/*
=====================
=
= UpdateObonHitbox
=
=====================
*/

void UpdateObonHitbox(void)
{
	Sint16 spr;

	spr = obon.shapenum*4 + (obon.x >> (G_P_SHIFT+1)) % 4;
	image = spritetable[spr];

	obon.left   = obon.x + image.xl;
	obon.right  = obon.x + image.xh;
	obon.top    = obon.y + image.yl;
	obon.bottom = obon.y + image.yh;
}


/*
=====================
=
= UpdateObjHitbox
=
=====================
*/

void UpdateObjHitbox(objtype *ob)
{
	Sint16 spr;

	spr = ob->shapenum*4 + (ob->x >> (G_P_SHIFT+1)) % 4;
	image = spritetable[spr];

	ob->left   = ob->x + image.xl;
	ob->right  = ob->x + image.xh;
	ob->top    = ob->y + image.yl;
	ob->bottom = ob->y + image.yh;
}


/*
=====================
=
= AccelerateX
=
=====================
*/

void AccelerateX(Sint16 amount)
{
	Uint16 i;

	for (i=1; i<=tics; i++)
	{
		obon.xspeed += amount;
		if (obon.xspeed > 120)
		{
			obon.xspeed = 120;
		}
		else if (obon.xspeed < -120)
		{
			obon.xspeed = -120;
		}

		if (i != tics)
		{
			obon.xmove += obon.xspeed;
		}
	}
}


/*
=====================
=
= AccelerateY
=
=====================
*/

void AccelerateY(Sint16 max, Sint16 amount)
{
	Uint16 i;

	for (i=1; i<=tics; i++)
	{
		obon.yspeed += amount;
		if (obon.yspeed > max)
		{
			obon.yspeed = max;
		}
		else if (obon.yspeed < -max)
		{
			obon.yspeed = -max;
		}

		if (i != tics)
		{
			obon.ymove += obon.yspeed;
		}
	}
}


/*
=====================
=
= DoGravity
=
=====================
*/

void DoGravity(void)
{
	Uint16 i;

	for (i=1; i<=tics; i++)
	{
		obon.yspeed += 3;
		if (obon.yspeed > 200)
		{
			obon.yspeed = 200;
		}
		else if (obon.yspeed < -400)
		{
			obon.yspeed = -400;
		}

		if (i != tics)
		{
			obon.ymove += obon.yspeed;
		}
	}
	
	// This code gradually increases yspeed for every timer tic and adds the
	// current yspeed to ymove for every tic to calculate the correct movement
	// for the given initial speed and the gravity constant. But then the
	// MoveObon code (see below) adds yspeed*tics as if the object moved with a
	// constant speed. These two approaches don't really fit together. This
	// leads to maximum jump heights depending on the frame rate to some degree.
	//
	// For example, if the initial jump speed is -216 and the game is running at
	// a constant frame time of 6 tics per frame, you would get these results:
	//
	// yspeed (old) | yspeed (new) | ymove | ymove after MoveObon |  total
	// -------------+--------------+-------+----------------------+--------
	//         -216 |         -198 | -1035 |                -2223 |  -2223
	//         -198 |         -180 |  -945 |                -2025 |  -4248
	//         -180 |         -162 |  -855 |                -1827 |  -6075
	//         -162 |         -144 |  -765 |                -1629 |  -7704
	//         -144 |         -126 |  -675 |                -1431 |  -9135
	//         -126 |         -108 |  -585 |                -1233 | -10368
	//         -108 |          -90 |  -495 |                -1035 | -11403
	//          -90 |          -72 |  -405 |                 -837 | -12240
	//          -72 |          -54 |  -315 |                 -639 | -12879
	//          -54 |          -36 |  -225 |                 -441 | -13320
	//          -36 |          -18 |  -135 |                 -243 | -13563
	//          -18 |            0 |   -45 |                  -45 | -13608
	//
	// Moving by -13608 global unit in total means moving up by a little over 53
	// pixels.
	//
	// If we take the same initial jump speed, but assume a constant frame time
	// of 15 tics per frame, the results would look like this:
	//
	// yspeed (old) | yspeed (new) | ymove | ymove after MoveObon |  total
	// -------------+--------------+-------+----------------------+--------
	//         -216 |         -171 | -2709 |                -5274 |  -5274
	//         -171 |         -126 | -2079 |                -3969 |  -9243
	//         -126 |          -81 | -1449 |                -2664 | -11907
	//          -81 |          -36 |  -819 |                -1359 | -13266
	//          -36 |            9 |  -189 |                  -54 | -13320
	//
	// That's a difference of 288 global units, which is more than 1 pixel.
	// This difference is negligable. But when Keen is using the pogo stick,
	// the code will also call AccelerateY(200, -1) as long as yspeed is still
	// negative and the jump button is still held down -- in addition to calling
	// DoGravity and MoveObon! That makes a bigger difference:
	//
	// Pogo jumping at 6 tics per frame:
	//
	// yspeed (old) | yspeed (new) | ymove | ymove after MoveObon |  total
	// -------------+--------------+-------+----------------------+--------
	//         -200 |         -188 | -2000 |                -3128 |  -3128
	//         -188 |         -176 | -1880 |                -2936 |  -6064
	//         -176 |         -164 | -1760 |                -2744 |  -8808
	//         -164 |         -152 | -1640 |                -2552 | -11360
	//         -152 |         -140 | -1520 |                -2360 | -13720
	//         -140 |         -128 | -1400 |                -2168 | -15888
	//         -128 |         -116 | -1280 |                -1976 | -17864
	//         -116 |         -104 | -1160 |                -1784 | -19648
	//         -104 |          -92 | -1040 |                -1592 | -21240
	//          -92 |          -80 |  -920 |                -1400 | -22640
	//          -80 |          -68 |  -800 |                -1208 | -23848
	//          -68 |          -56 |  -680 |                -1016 | -24864
	//          -56 |          -44 |  -560 |                 -824 | -25688
	//          -44 |          -32 |  -440 |                 -632 | -26320
	//          -32 |          -20 |  -320 |                 -440 | -26760
	//          -20 |           -8 |  -200 |                 -248 | -27008
	//           -8 |            4 |   -80 |                  -56 | -27064
	//
	// Pogo jumping at 15 tics per frame:
	//
	// yspeed (old) | yspeed (new) | ymove | ymove after MoveObon |  total
	// -------------+--------------+-------+----------------------+--------
	//         -200 |         -170 | -5600 |                -8150 |  -8150
	//         -170 |         -140 | -4760 |                -6860 | -15010
	//         -140 |         -110 | -3920 |                -5570 | -20580
	//         -110 |          -80 | -3080 |                -4280 | -24860
	//          -80 |          -50 | -2240 |                -2990 | -27850
	//          -50 |          -20 | -1400 |                -1700 | -29550
	//          -20 |           10 |  -560 |                 -410 | -29960
	//
	// Now the difference is 2896 global units, which are over 11 pixels! The
	// maximum pogo jump height at a constant 6 tics per frame would be only
	// about 105 pixels (6 tiles and 9 pixels), while 15 tics per frame would
	// allow Keen to pogo-jump up to 117 pixels high (7 tiles and 5 pixels).
	// This is a significant difference.
}


/*
=====================
=
= MoveObon
=
=====================
*/

Sint16 MoveObon(void)
{
#if VERSION < VER_100
	obon.xmove = obon.xmove + obon.xspeed*tics;
	if (obon.xmove > TILEGLOBAL)
	{
		obon.xmove = TILEGLOBAL;
	}
	else if (obon.xmove < -TILEGLOBAL)
	{
		obon.xmove = -TILEGLOBAL;
	}
	obon.ymove = obon.ymove + obon.yspeed*tics;
	if (obon.ymove > TILEGLOBAL)
	{
		obon.ymove = TILEGLOBAL;
	}
	else if (obon.ymove < -TILEGLOBAL)
	{
		obon.ymove = -TILEGLOBAL;
	}
#else
	obon.xmove = obon.xmove + obon.xspeed*tics;
	obon.ymove = obon.ymove + obon.yspeed*tics;
#endif
	return ClipMoveObon();
}


/*
=====================
=
= ClipMoveObon
=
=====================
*/

Sint16 ClipMoveObon(void)
{
	Sint16 x, y, extra;
	Sint16 tileleft, tileright, tiletop, tilebottom;
	Sint16 result;

	result = BLOCK_NONE;

#if VERSION >= VER_100
	if (obon.xmove > 15*PIXGLOBAL)
	{
		obon.xmove = 15*PIXGLOBAL;
	}
	else if (obon.xmove < -15*PIXGLOBAL)
	{
		obon.xmove = -15*PIXGLOBAL;
	}
	
	if (obon.ymove > 15*PIXGLOBAL)
	{
		obon.ymove = 15*PIXGLOBAL;
	}
	else if (obon.ymove < -15*PIXGLOBAL)
	{
		obon.ymove = -15*PIXGLOBAL;
	}
#endif

	obon.bottom += obon.ymove;
	obon.top += obon.ymove;

	tileleft = GLOBAL_TO_TILE(obon.left);
	tileright = GLOBAL_TO_TILE(obon.right);

	if (obon.ymove > 0)
	{
		// moving down
		if (GLOBAL_TO_TILE(obon.bottom) != GLOBAL_TO_TILE(obon.bottom - obon.ymove))
		{
			// movement crossed a tile boundary, so check for blocking tiles:
			tilebottom = GLOBAL_TO_TILE(obon.bottom);
			for (x=tileleft; x<=tileright; x++)
			{
				if (northwall[GETTILE(x,tilebottom,0)])
				{
					obon.yspeed = 0;
					extra = (obon.bottom+1) % TILEGLOBAL;
					obon.ymove -= extra;
					obon.top -= extra;
					obon.bottom -= extra;
					result = BLOCK_DOWN;
					break;
				}
			}
		}
	}
	else if (obon.ymove < 0)
	{
		// moving up
		if (GLOBAL_TO_TILE(obon.top) != GLOBAL_TO_TILE(obon.top - obon.ymove))
		{
			// movement crossed a tile boundary, so check for blocking tiles:
			tiletop = GLOBAL_TO_TILE(obon.top);
			for (x=tileleft; x<=tileright; x++)
			{
				if (southwall[GETTILE(x,tiletop,0)])
				{
					obon.yspeed = 0;
					extra = TILEGLOBAL - obon.top % TILEGLOBAL;
					obon.ymove += extra;
					obon.top += extra;
					obon.bottom += extra;
					result = BLOCK_UP;
					break;
				}
			}
		}
	}

	obon.left += obon.xmove;
	obon.right += obon.xmove;

	tiletop = GLOBAL_TO_TILE(obon.top);
	tilebottom = GLOBAL_TO_TILE(obon.bottom);

	if (obon.xmove > 0)
	{
		// moving right
		if (GLOBAL_TO_TILE(obon.right) != GLOBAL_TO_TILE(obon.right - obon.xmove))
		{
			// movement crossed a tile boundary, so check for blocking tiles:
			tileright = GLOBAL_TO_TILE(obon.right);
			for (y=tiletop; y<=tilebottom; y++)
			{
				if (westwall[GETTILE(tileright,y,0)])
				{
					obon.xspeed = 0;
					extra = (obon.right + 1) % TILEGLOBAL;
					obon.xmove -= extra;
					obon.left -= extra;
					obon.right -= extra;
					result |= BLOCK_RIGHT;
					break;
				}
			}
		}
	}
	else if (obon.xmove < 0)
	{
		// moving left
		if (GLOBAL_TO_TILE(obon.left) != GLOBAL_TO_TILE(obon.left - obon.xmove))
		{
			// movement crossed a tile boundary, so check for blocking tiles:
			tileleft = GLOBAL_TO_TILE(obon.left);
			for (y=tiletop; y<=tilebottom; y++)
			{
				if (eastwall[GETTILE(tileleft,y,0)])
				{
					obon.xspeed = 0;
					extra = TILEGLOBAL - obon.left % TILEGLOBAL;
					obon.xmove += extra;
					obon.left += extra;
					obon.right += extra;
					result |= BLOCK_LEFT;
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
= RideObj
=
=====================
*/

void RideObj(objtype *ob, objtype *plat)
{
	Sint16 yinto;
	Sint16 dxmove, dymove, xinto;

	obon = *ob;
	if (plat->x < obon.x)
	{
		dxmove = plat->xmove - obon.xmove + 2;
		xinto = plat->right - obon.left + 1;
	}
	else
	{
		dxmove = obon.xmove - plat->xmove + 2;
		xinto = obon.right - plat->left + 1;
	}
	if (plat->y < obon.y)
	{
		dymove = plat->ymove - obon.ymove + 2;
		yinto = plat->bottom - obon.top + 1;
	}
	else
	{
		dymove = obon.ymove - plat->ymove + 2;
		yinto = obon.bottom - plat->top + 1;
	}

	obon.xmove = obon.ymove = 0;

	if (dymove >= yinto)
	{
		if (plat->y > obon.y)
		{
			obon.xmove = plat->xmove;
#if VERSION < VER_100
			obon.ymove = -yinto;
#elif VERSION <= VER_100
			obon.ymove = -yinto - 1;
#else
			obon.ymove = -yinto - PIXGLOBAL/2;
#endif
			if (obon.think == KeenJump)
			{
				obon.think = KeenWalk;
			}
			else if (obon.think == KeenPogoAir)
			{
				obon.think = KeenPogoGround;
				obon.temp1 = 0;
				obon.temp2 = obon.xspeed;
				obon.xspeed = 0;
			}
			obon.temp4 = 1;	// is now riding a platform
			obon.yspeed = plat->yspeed;
			if (obon.yspeed < 0)
			{
#if 0
				obon.yspeed = obon.yspeed/2;
#else
				obon.yspeed /= 2;
#endif
			}
		}
		else
		{
			obon.ymove = yinto;
			if (plat->yspeed > obon.yspeed)
			{
				obon.yspeed = plat->yspeed;
			}
		}
	}
	else
	{
		if (plat->x > obon.x)
		{
			obon.xmove = -xinto;
			if (plat->xspeed < obon.xspeed)
			{
				obon.xspeed = plat->xspeed;
			}
		}
		else
		{
			obon.xmove = xinto;
			if (plat->xspeed > obon.xspeed)
			{
				obon.xspeed = plat->xspeed;
			}
		}
	}

	ClipMoveObon();
	obon.x += obon.xmove;
	obon.y += obon.ymove;
	UpdateObonHitbox();
	*ob = obon;
	ScrollScreen();
}


/*
=====================
=
= PushObj
=
=====================
*/

#if VERSION >= VER_100
void PushObj(objtype *ob, objtype *solid)
{
	obon = *ob;
#if VERSION <= VER_100
	obon.xmove = (solid->x > obon.x)? -(obon.right - solid->left + 1) : (solid->right - obon.left + 1);
#else
	// compare center position of both hitboxes and push obon
	// out of solid's hitbox, taking the shortest path:
	if ((obon.right+obon.left)/2 < (solid->left+solid->right)/2)
	{
		// obon is in the left part of solid, so push it out to the left:
		obon.xmove = -(obon.right - solid->left + 1);
		if (obon.xmove > 120)
		{
			obon.ymove = 120;	// BUG? shouldn't this set xmove?!
		}
	}
	else
	{
		// obon is in the right part of solid, so push it out to the right:
		obon.xmove = solid->right - obon.left + 1;
		if (obon.xmove < -120)
		{
			obon.ymove = -120;	// BUG? shouldn't this set xmove?!
		}
	}
#endif

	ClipMoveObon();
	obon.x += obon.xmove;
	obon.y += obon.ymove;
	UpdateObonHitbox();
	*ob = obon;
	ScrollScreen();
}
#endif


/*
=====================
=
= RemoveInactive
=
=====================
*/

boolean RemoveInactive(void)
{
	Sint16 tx, ty;

#if VERSION <= VER_110

	// prevent object from leaving the map boundaries at the sides and the top:
	if (obon.x > monxmax)
	{
		obon.x = monxmax;
	}
	else if (obon.x < 0)
	{
		obon.x = 0;
	}
	
	if (obon.y < 0)
	{
		obon.y = 0;
	}
	else if (obon.y > monymax)	// if object has fallen out of the level
	{
		obon.obclass = nothing;
		return true;
	}
	// Note that this behavior might have caused objects to get stuck at those
	// boundaries instead of being removed from the game, which might have
	// caused the object list to overflow, leading to memory corruption (the
	// data following after the objlist array would be overwritten with
	// additional objects).
	
	tx = GLOBAL_TO_TILE(obon.x);
	ty = GLOBAL_TO_TILE(obon.y);

#else

	tx = GLOBAL_TO_TILE(obon.x);
	ty = GLOBAL_TO_TILE(obon.y);

	if (obon.y < 0)
	{
		obon.y = 0;
	}

	// check if object has moved / fallen out of the level:
	if (obon.x > monxmax || obon.x < 0 || obon.y > monymax)
	{
		obon.obclass = nothing;	//remove the object
		return true;
	}
	
#endif

	// check if object is far off-screen:
	if (ox-8 > tx || oy-8 > ty || ox+28 < tx || oy+18 < ty)
	{
		if (obon.obclass < volatileobj)
		{
			obon.active = false;	// stop updating the object (for now)
		}
		else
		{
			obon.obclass = nothing;	//remove the object
		}
		return true;
	}

	return false;
}


#ifdef K13_PORT
/* Presentation-only accessors for the compositor's "ghost" pass: objects
   the engine deactivated when they left the vanilla activation window still
   exist in the sim with frozen position and shape -- the engine just stops
   placing their sprites.  In the wide view that boundary is ON SCREEN, so
   vanishing there read as edge pop-in.  The compositor draws them straight
   from this read-only sim truth; nothing here mutates state. */
Sint16 K13_GhostMax(void)
{
	return numobj;
}

int K13_GhostGet(Sint16 i, Sint32 *x, Sint32 *y, Sint16 *shape)
{
	if (i < 1 || i >= numobj)
		return 0;
	if (objlist[i].obclass == nothing || objlist[i].active)
		return 0;
	if (objlist[i].shapenum <= 0)
		return 0;
	*x = objlist[i].x;
	*y = objlist[i].y;
	*shape = objlist[i].shapenum;
	return 1;
}
#endif


/*
=====================
=
= NullThink
=
=====================
*/

void NullThink(void)
{
	// do nothing
}


/*
=====================
=
= PlayerCheckMapBorders
=
=====================
*/

void PlayerCheckMapBorders(void)
{
	// Note: This is called by Keen's think routines, which means
	// the current movement has not yet been applied to the x/y
	// coordinates. This code does not add xmove/ymove to the
	// coordinates, leading to jerky movement at the map edges.

#if 1
	// the original code:
	if (originxmin+8 > obon.x)
	{
		obon.xspeed = obon.xmove = 0;
		obon.x = originxmin+8;
	}
	else if (obon.x > playerxmax)
	{
		obon.xspeed = obon.xmove = 0;
		obon.x = playerxmax;
	}

	if (obon.y < originymin)
	{
		obon.yspeed = obon.ymove = 0;
		obon.y = originymin;
	}
	else if (obon.y > playerymax)
	{
		PlaySound(PLUMMETSND);
		WaitEndSound();
		KillKeen();
		return;
	}
#else
	// non-jerky version:
	if (originxmin+8 > obon.x+obon.xmove)
	{
		obon.xspeed = obon.xmove = 0;
		obon.x = originxmin+8;
	}
	else if (obon.x+obon.xmove > playerxmax)
	{
		obon.xspeed = obon.xmove = 0;
		obon.x = playerxmax;
	}

	if (obon.y+obon.ymove < originymin)
	{
		obon.yspeed = obon.ymove = 0;
		obon.y = originymin;
	}
	else if (obon.y+obon.ymove > playerymax)
	{
		PlaySound(PLUMMETSND);
		WaitEndSound();
		KillKeen();
	}
#endif
}


/*
=====================
=
= ScrollScreen
=
=====================
*/

void ScrollScreen(void)
{
	Sint32 x, y;
	Sint16 xmove, ymove;

	if (objlist[0].think == KeenExit || objlist[0].think == KeenDead)
	{
		return;
	}

	x = objlist[0].x;
	y = objlist[0].y;
	xmove = objlist[0].xmove;
	ymove = objlist[0].ymove;

	if (xmove > 0 && x-originx > 11*TILEGLOBAL)
	{
		originx += xmove;
		if (originx > originxmax)
		{
			originx = originxmax;
		}
	}
	else if (xmove < 0 && x-originx < 9*TILEGLOBAL)
	{
		originx += xmove;
		if (originx < originxmin)
		{
			originx = originxmin;
		}
	}

	if (ymove > 0 && y-originy > 7*TILEGLOBAL)
	{
		originy += ymove;
		if (originy > originymax)
		{
			originy = originymax;
		}
	}
	else if (ymove < 0 && y-originy < 3*TILEGLOBAL)
	{
		originy += ymove;
		if (originy < originymin)
		{
			originy = originymin;
		}
	}
}


/*
=====================
=
= TurnLightsOn
=
=====================
*/

void TurnLightsOn(void)
{
	lightson = true;
	WaitVBL(1);

	// set palette:
	_ES = FP_SEG(&colors[3]);
	_DX = FP_OFF(&colors[3]);
	_AX = 0x1002;
	geninterrupt(0x10);
}


/*
=====================
=
= TurnLightsOff
=
=====================
*/

void TurnLightsOff(void)
{
	lightson = false;
	WaitVBL(1);

	// set palette:
	_ES = FP_SEG(&colors[1]);
	_DX = FP_OFF(&colors[1]);
	_AX = 0x1002;
	geninterrupt(0x10);
}


/*
=====================
=
= ToggleSwitch
=
=====================
*/

void ToggleSwitch(void)
{
	Sint16 i;
	pobjtype *pob;
	Uint16 infoval;
	Sint16 tile;
	Sint16 tx, ty, x;
	Sint32 orgx, orgy;

	PlaySound(CLICKSND);
	if (GETTILE(switchxtile+3, switchytile+5, 0) == 479)
	{
		// Keen has flipped a tantalus switch!

		// make the screen shake:
		orgx = originx;
		orgy = originy;
		for (i=1; i<80; i++)
		{
			RF_Clear();
			originx = orgx - (Rnd(64)-32)*(Sint16)PIXGLOBAL;
			originy = orgy - (Rnd(64)-32)*(Sint16)PIXGLOBAL;
			RF_PlaceSprite(obon.x, obon.y, obon.shapenum);
			RF_Refresh();
		}

		ExpWin(5, 1);
		Print("Oops.");
		WaitVBL(100);
		LevelDone = ex_tantalus;
	}
	else
	{
		tile = GETTILE(switchxtile,switchytile,0);
		switch (tile)
		{
		case 480:
			SETTILE(switchxtile,switchytile,0,493);
			break;

		case 493:
			SETTILE(switchxtile,switchytile,0,480);
			break;

		case 271:
			if (lightson)
				TurnLightsOff();
			else
				TurnLightsOn();
			return;
		}

		// trigger bridge:
		infoval = GETTILE(switchxtile,switchytile,1);
		x = (Sint8)(infoval & 0xFF);
		tx = switchxtile + x;
		ty = switchytile + (Sint8)(infoval >> 8);

		// look for an existing bridge object with matching position:
		for (i=0; i<pobjcount; i++)
		{
			// Note: might be better to check if type is POBJ_BRIDGE here:
			if (pobjlist[i].type != POBJ_NOTHING && pobjlist[i].x == tx && pobjlist[i].y == ty)
			{
				break;
			}
		}

		if (i < pobjcount)
		{
			// found a bridge object, so change its state:
			if (pobjlist[i].think == BridgeRemove)
			{
				pobjlist[i].think = BridgeCreate;
			}
			else	// think could be either BridgeCreate or NullPThink
			{
				pobjlist[i].think = BridgeRemove;
			}
		}
		else
		{
			// found NO bridge object, so spawn a new one:
			pob = FindFreePObj();
			pob->type = POBJ_BRIDGE;
			pob->think = BridgeCreate;
			pob->x = tx;
			pob->y = ty;
			pob->temp1 = 0;
#if VERSION < VER_100
			pob->temp2 = (x > 0)? 1 : -1;
#else
			if (westwall[GETTILE(tx+1,ty,0)])
			{
				pob->temp2 = -1;
			}
			else
			{
				pob->temp2 = 1;
			}
#endif
			pob->temp3 = GETTILE(tx,ty,0);
			pob->temp4 = 0;
		}
	}
}

/*
==============================================================================

                               KEEN ROUTINES
	
==============================================================================
*/


/*
=====================
=
= KeenWalk
=
=====================
*/

void KeenWalk(void)
{
#if VERSION < VER_100
	Sint16 floor, block;
	Sint16 tx, ty;
	
	tx = GLOBAL_TO_TILE((obon.right-obon.left)/2 + obon.left);
	ty = GLOBAL_TO_TILE(obon.bottom);
	
	if (obon.temp4)
	{
		floor = 1;
	}
	else
	{
		floor = northwall[GETTILE(tx,ty+1,0)];
	}
#else
	Sint16 x;
	Sint16 floor;
	Sint16 block;
	Sint16 tileleft, tileright, tilebottom;
	Sint16 blockDown;

	if (obon.temp4)
	{
		floor = 1;
	}
	else
	{
		tileleft = GLOBAL_TO_TILE(obon.left);
		tileright = GLOBAL_TO_TILE(obon.right);
		tilebottom = GLOBAL_TO_TILE(obon.bottom)+1;
		floor = 1;
		for (x=tileleft; x<=tileright; x++)
		{
			blockDown = northwall[GETTILE(x,tilebottom,0)];
			if (blockDown > 1)
			{
				floor = blockDown;
			}
		}
	}
#endif

	if (ctrl.button1)
	{
		obon.temp3 = obon.xspeed;
		obon.xspeed = 0;
		obon.temp2 = 0;
		obon.temp1 = 0;
		if (lastdir >= 0)
		{
			obon.baseshape = KEENJUMPR1SPR;
		}
		else
		{
			obon.baseshape = KEENJUMPL1SPR;
		}
		obon.think = KeenStartJump;
	}

	if (floor < 3)
	{
		switch (ctrl.dir)
		{
		case northeast:
		case east:
		case southeast:
			AccelerateX(2);
			if (obon.xspeed < 0)
			{
				ctrl.dir = nodir;
			}
			break;

		case southwest:
		case west:
		case northwest:
			AccelerateX(-2);
			if (obon.xspeed > 0)
			{
				ctrl.dir = nodir;
			}
			break;
		}
	}

	if (floor == 1 && ctrl.dir == nodir)
	{
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
	}

	if (floor == 3)
	{
		if (lastdir > 0)
		{
			obon.xspeed = 180;
		}
		else if (lastdir < 0)
		{
			obon.xspeed = -180;
		}

	}

	if (obon.xspeed == 0)
	{
		if (lastdir >= 0)
		{
			obon.shapenum = KEENWALKR1SPR;
		}
		else
		{
			obon.shapenum = KEENWALKL1SPR;
		}
	}
	else
	{
		if (obon.xspeed > 0)
		{
			obon.shapenum = KEENWALKR1SPR;
			if (floor < 3)
			{
				obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 3);
			}
			lastdir = obon.xspeed;
		}
		else
		{
			obon.shapenum = KEENWALKL1SPR;
			if (floor < 3)
			{
				obon.shapenum = obon.shapenum + (((Uint16)timecount >> 4) & 3);
			}
			lastdir = obon.xspeed;
		}
	}

	if (obon.xspeed && (((Uint16)timecount >> 4) & 1) && floor < 3)
	{
		if (((Uint16)timecount >> 5) & 1)
		{
			PlaySound(KEENWLK2SND);
		}
		else
		{
			PlaySound(KEENWALKSND);
		}
	}

	DoGravity();
	block = MoveObon();
	PlayerCheckMapBorders();

	if (block & BLOCK_RIGHT || block & BLOCK_LEFT)
	{
		if (((Uint16)timecount >> 4) & 1)
		{
			PlaySound(KEENBLOKSND);
		}
	}

	if (!(block & BLOCK_DOWN) && !obon.temp4)
	{
		obon.think = KeenJump;
		PlaySound(PLUMMETSND);
		return;
	}

	// button1 was already checked above, not sure why this is done twice:
	if (ctrl.button1)
	{
		obon.temp3 = obon.xspeed;
		obon.xspeed = 0;
		obon.temp2 = 0;
		obon.temp1 = 0;
		if (lastdir >= 0)
		{
			obon.baseshape = KEENJUMPR1SPR;
		}
		else
		{
			obon.baseshape = KEENJUMPL1SPR;
		}
		obon.think = KeenStartJump;
	}

	if (ctrl.button2 && !ctrl2.button2)
	{
		if (buttontouched)
		{
			ToggleSwitch();
		}
		else
		{
			obon.temp1 = 0;
			obon.temp2 = obon.xspeed;
			obon.xspeed = 0;
			if (gamestate.gotPogo)
			{
				obon.think = KeenPogoGround;
			}
		}
	}

	if (ctrl.button1 && ctrl.button2 && !ctrl2.button1 && !ctrl2.button2)
	{
		obon.think = KeenShoot;
		obon.temp1 = obon.temp2 = obon.xmove = 0;
		obon.think = KeenShoot;
		if (lastdir > 0)
		{
			obon.shapenum = KEENSHOOTRSPR;
		}
		else
		{
			obon.shapenum = KEENSHOOTLSPR;
		}
	}

	if (obon.temp4)
	{
		obon.temp4--;
	}
}


/*
=====================
=
= KeenStartJump
=
=====================
*/

void KeenStartJump(void)
{
	obon.shapenum = obon.baseshape + obon.temp1 / 6;
	if (ctrl.button1)
	{
		obon.temp2 = obon.temp2 + tics*6; // build up yspeed for the jump in temp2
	}
	else if (obon.temp1 < 12)
	{
		obon.temp1 = 24 - obon.temp1;
	}

	// build up xspeed for the jump in temp3:
	switch (ctrl.dir)
	{
	case northeast:
	case east:
	case southeast:
		obon.temp3 = obon.temp3 + tics*2;
		if (obon.temp3 > 120)
		{
			obon.temp3 = 120;
		}
		break;

	case southwest:
	case west:
	case northwest:
		obon.temp3 = obon.temp3 - tics*2;
		if (obon.temp3 < -120)
		{
			obon.temp3 = -120;
		}
		break;
	}
	obon.xspeed = 0;

	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 >= 36)
	{
		// actually start the jump:
		obon.think = KeenJump;
		obon.yspeed -= obon.temp2;
		obon.xspeed = obon.temp3;
		PlaySound(KEENJUMPSND);
	}

	DoGravity();
	MoveObon();
	PlayerCheckMapBorders();

	if (ctrl.button1 && ctrl.button2)
	{
		obon.think = KeenShoot;
		obon.temp1 = obon.temp2 = obon.xmove = 0;
		obon.think = KeenShoot;
		if (lastdir > 0)
		{
			obon.shapenum = KEENSHOOTRSPR;
		}
		else
		{
			obon.shapenum = KEENSHOOTLSPR;
		}
	}
}


/*
=====================
=
= KeenJump
=
=====================
*/

void KeenJump(void)
{
	Sint16 block;

	switch (ctrl.dir)
	{
	case northeast:
	case east:
	case southeast:
		AccelerateX(2);
		if (obon.xspeed < 0)
		{
			ctrl.dir = nodir;
		}
		break;

	case southwest:
	case west:
	case northwest:
		AccelerateX(-2);
		if (obon.xspeed > 0)
		{
			ctrl.dir = nodir;
		}
		break;
	}

	if (ctrl.dir == nodir)
	{
		if (obon.xspeed > 0)
		{
			AccelerateX(-1);
			if (obon.xspeed < 0)
			{
				obon.xspeed = 0;
			}
		}
		else if (obon.xspeed < 0)
		{
			AccelerateX(1);
			if (obon.xspeed > 0)
			{
				obon.xspeed = 0;
			}
		}
	}

	if (lastdir > 0)
	{
		obon.shapenum = KEENJUMPR6SPR;
	}
	else
	{
		obon.shapenum = KEENJUMPL6SPR;
	}

	if (obon.xspeed)
	{
		lastdir = obon.xspeed;
	}

	DoGravity();
	block = MoveObon();

	if (block & BLOCK_RIGHT || block & BLOCK_LEFT)
	{
		if (((Uint16)timecount >> 4) & 1)
		{
			PlaySound(KEENBLOKSND);
		}
	}

	if (block & BLOCK_DOWN)
	{
		obon.think = KeenWalk;
		PlaySound(KEENLANDSND);
		return;
	}

	if (block & BLOCK_UP)
	{
		PlaySound(BUMPHEADSND);
	}

	PlayerCheckMapBorders();

	if (ctrl.button2 && !ctrl2.button2)
	{
		if (buttontouched)
		{
			ToggleSwitch();
		}
		else if (gamestate.gotPogo)
		{
			obon.think = KeenPogoAir;
		}
	}

	if (ctrl.button1 && ctrl.button2 && !ctrl2.button1 && !ctrl2.button2)
	{
		obon.think = KeenShoot;
		obon.temp1 = obon.temp2 = obon.xmove = 0;
		obon.think = KeenShoot;
		if (lastdir > 0)
		{
			obon.shapenum = KEENSHOOTRSPR;
		}
		else
		{
			obon.shapenum = KEENSHOOTLSPR;
		}
	}
}


/*
=====================
=
= KeenShoot
=
=====================
*/

void KeenShoot(void)
{
#ifdef K13_PORT
	K13_Trace("KeenShoot fired");
#endif
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp2 == 0 && obon.temp1 > 1)
	{
		if (gamestate.ammo)
		{
			PlaySound(KEENFIRESND);
			gamestate.ammo--;
			SpawnPlayerShot(obon.x, obon.y);
		}
		else
		{
			PlaySound(GUNCLICKSND);
		}
		obon.temp2 = 1;	// shot has been spawned
	}

	if (obon.temp1 > 30 && !ctrl.button1 && !ctrl.button2)
		obon.think = KeenWalk;

	if (obon.xspeed > 0)
	{
		AccelerateX(-1);
		if (obon.xspeed < 0)
		{
			obon.xspeed = 0;
		}
	}
	else if (obon.xspeed < 0)
	{
		AccelerateX(1);
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
=====================
=
= KeenPogoAir
=
=====================
*/

void KeenPogoAir(void)
{
	Sint16 block;

	ctrl = ControlPlayer(1);	// why read the controls here? seems odd...

	switch (ctrl.dir)
	{
	case northeast:
	case east:
	case southeast:
		AccelerateX(1);
		if (obon.xspeed < 0)
		{
			ctrl.dir = nodir;
		}
		break;

	case southwest:
	case west:
	case northwest:
		AccelerateX(-1);
		if (obon.xspeed > 0)
		{
			ctrl.dir = nodir;
		}
		break;
	}

	if (ctrl.button1 && obon.yspeed < 0)
	{
		AccelerateY(200, -1);
	}

#if VERSION >= VER_100
	if (cheatmode && ctrl.button1)
	{
		obon.yspeed = -200;
	}
#endif

	if (obon.xspeed)
	{
		lastdir = obon.xspeed;
	}

	if (lastdir >= 0)
	{
		obon.baseshape = KEENPOGOR1SPR;
	}
	else
	{
		obon.baseshape = KEENPOGOL1SPR;
	}
	obon.shapenum = obon.baseshape;

	DoGravity();
	block = MoveObon();
	if (block & BLOCK_RIGHT || block & BLOCK_LEFT)
	{
		if (((Uint16)timecount >> 4) & 1)
		{
			PlaySound(KEENBLOKSND);
		}
	}
	if (block & BLOCK_DOWN)
	{
		obon.think = KeenPogoGround;
		obon.temp1 = 0;
		obon.temp2 = obon.xspeed;
		obon.xspeed = 0;
	}
	if (block & BLOCK_UP)
	{
		PlaySound(BUMPHEADSND);
	}
	PlayerCheckMapBorders();

	if (ctrl.button2 && !ctrl2.button2)
	{
		if (buttontouched)
		{
			ToggleSwitch();
		}
		else
		{
			obon.think = KeenJump;
		}
	}

	if (ctrl.button1 && ctrl.button2)
	{
		obon.think = KeenShoot;
		obon.temp1 = obon.temp2 = obon.xmove = 0;
		obon.think = KeenShoot;
		if (lastdir > 0)
		{
			obon.shapenum = KEENSHOOTRSPR;
		}
		else
		{
			obon.shapenum = KEENSHOOTLSPR;
		}
	}

	if (obon.temp4)
	{
		obon.temp4--;
	}
}


/*
=====================
=
= KeenPogoGround
=
=====================
*/

void KeenPogoGround(void)
{
	obon.xmove = obon.xspeed = 0;
	obon.shapenum = obon.baseshape + 1;
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 22)
	{
		obon.think = KeenPogoAir;
		obon.temp4 = 0;
		obon.yspeed -= 200;
		obon.xspeed = obon.temp2;
		PlaySound(KEENJUMPSND);
	}

	if (ctrl.button2 && !ctrl2.button2)
	{
		obon.think = KeenWalk;
	}

	if (ctrl.button1 && ctrl.button2)
	{
		obon.think = KeenShoot;
		obon.temp1 = obon.temp2 = obon.xmove = 0;
		obon.think = KeenShoot;
		if (lastdir > 0)
		{
			obon.shapenum = KEENSHOOTRSPR;
		}
		else
		{
			obon.shapenum = KEENSHOOTLSPR;
		}
	}

	MoveObon();
	obon.temp4 = 0;
}


/*
=====================
=
= KeenExit
=
=====================
*/

void KeenExit(void)
{
	Sint32 tx, ty;

	tx = obon.temp1;
	ty = obon.temp2;
	obon.xmove = tics*60;
	obon.shapenum = (((Uint16)timecount >> 4) & 3) + KEENWALKR1SPR;	// KEENWALKR1 to KEENWALKR4
	lastdir = obon.xspeed;

#if (EPISODE != 3)
	RF_PlaceTile(TILE_TO_GLOBAL(tx), TILE_TO_GLOBAL(ty), 160);
	RF_PlaceTile(TILE_TO_GLOBAL(tx), TILE_TO_GLOBAL(ty+1), 160);
	RF_PlaceTile(TILE_TO_GLOBAL(tx+1), TILE_TO_GLOBAL(ty), 143);
	RF_PlaceTile(TILE_TO_GLOBAL(tx+1), TILE_TO_GLOBAL(ty+1), 143);
#else
	RF_PlaceTile(TILE_TO_GLOBAL(tx), TILE_TO_GLOBAL(ty), 257);
	RF_PlaceTile(TILE_TO_GLOBAL(tx), TILE_TO_GLOBAL(ty+1), 257);
	RF_PlaceTile(TILE_TO_GLOBAL(tx+1), TILE_TO_GLOBAL(ty), 246);
	RF_PlaceTile(TILE_TO_GLOBAL(tx+1), TILE_TO_GLOBAL(ty+1), 246);
#endif

	if (TILE_TO_GLOBAL(tx) <= obon.x)
	{
		obon.obclass = nothing;
		LevelDone = ex_completed;
	}
}


/*
=====================
=
= KeenDead
=
=====================
*/

void KeenDead(void)
{
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 >= 200)
	{
		obon.temp1 = -999;
		obon.xspeed = RndT() - 128;
		obon.yspeed = -400;
	}
	obon.shapenum = (((Uint16)timecount >> 4) & 1) + KEENISDEAD1SPR;

	// no-clipping movement:
	obon.xmove = obon.xspeed*tics;
	obon.ymove = obon.yspeed*tics;

	if (obon.bottom < originy)
	{
		obon.obclass = nothing;
	}
}


/*
=====================
=
= HurtKeen
=
=====================
*/

void HurtKeen(void)
{
#if VERSION == VER_100
	if (cheatmode)
	{
		return;
	}
#elif VERSION > VER_100 
	if (cheatmode || ankhtime)
	{
		return;
	}
#endif

	objlist[0].think = KeenDead;
	objlist[0].contact = NullContact;
	objlist[0].y += 8*PIXGLOBAL;
	objlist[0].xspeed = objlist[0].yspeed = 0;
	objlist[0].temp1 = objlist[0].xspeed = objlist[0].yspeed = 0;
	objlist[0].shapenum = KEENISDEAD1SPR;
	PlaySound(KEENDIESND);
}


/*
=====================
=
= KillKeen
=
=====================
*/

void KillKeen(void)
{
	// no cheatmode or invincilibitly check here, obon must be Keen
	obon.think = KeenDead;
	obon.contact = NullContact;
	obon.y += 8*PIXGLOBAL;
	obon.xspeed = objlist[0].yspeed = 0;	// objlist[0] is an authentic copy/paste error
	obon.temp1 = objlist[0].xspeed = objlist[0].yspeed = 0;	// objlist[0] is an authentic copy/paste error
	obon.shapenum = KEENISDEAD1SPR;
	PlaySound(KEENDIESND);
}


/*
=====================
=
= PlayerCheckTiles
=
=====================
*/

void PlayerCheckTiles(void)
{
	Sint16 x, y;
	Sint16 tileleft, tiletop, tileright, tilebottom;
	Sint16 tiletype, tile;

	if (objlist[0].think == KeenDead)
	{
		return;
	}

	buttontouched = false;
	tileleft = GLOBAL_TO_TILE(objlist[0].left);
	tileright = GLOBAL_TO_TILE(objlist[0].right);
	tiletop = GLOBAL_TO_TILE(objlist[0].top);
	tilebottom = GLOBAL_TO_TILE(objlist[0].bottom);

	for (x = tileleft; x <= tileright; x++)
	{
		for (y = tiletop; y <= tilebottom; y++)
		{
#if VERSION <= VER_100
			tiletype = intile[GETTILE(x,y,0)];
#else
			tile = GETTILE(x,y,0);
			tiletype = intile[tile];
#endif
			if (!tiletype)
			{
				continue;
			}
			
			switch (tiletype)
			{
			case 1:
				HurtKeen();
				break;

			case 2:
			case 3:
			case 4:
			case 5:
				if (gamestate.keys[tiletype-2])
				{
					OpenDoor(x, y);
				}
				else
				{
					//
					// push Keen away from door:
					//

					// Note: This aligns Keen's position on a tile boundary.
					// But since Keen's hitbox is thinner than the sprite,
					// this will lead to jerky movement if the player keeps
					// moving Keen into the door tile.
					// And since this is executed after Keen's sprite has
					// been placed, the sprite will still be drawn at the
					// old position.
					if (objlist[0].xmove > 0)
					{
						TILE_ALIGN(objlist[0].x);
					}
					else
					{
						objlist[0].x = (objlist[0].x + TILEGLOBAL) & ~(TILEGLOBAL-1);
					}
				}
				break;

			case 6:
			case 7:
			case 8:
			case 9:
			case 10:
				GivePoints(itemScores[tiletype-6]);
				PlaySound(GOTBONUSSND);
				// remove item from the map:
#if (EPISODE != 3)
				if (GETTILE(x, y, 0) < 305)	// Note: could just check the 'tile' variable here!
				{
					SETTILE(x, y, 0, 143);
				}
				else
				{
#if VERSION < VER_100
					SETTILE(x, y, 0, 305);
#else
					SETTILE(x, y, 0, 276);
#endif
				}
#else
				SETTILE(x, y, 0, (tile/13)*13);	// blank tile is always the first tile in a row of 13 tiles in the tileset
#endif
				break;

#if (EPISODE == 1)
			case 11:
			case 12:
			case 13:
			case 14:
				if (tiletype == 11)
				{
					gamestate.gotJoystick = true;
				}
				if (tiletype == 12)
				{
					gamestate.gotBattery = true;
				}
				if (tiletype == 13)
				{
					gamestate.gotVacuum = true;
				}
				if (tiletype == 14)
				{
					gamestate.gotEverclear = true;
				}
				GivePoints(10000);
				PlaySound(GOTPARTSND);
				SETTILE(x, y, 0, 143);
				break;
#endif

			case 15:
			case 16:
				if (tiletype == 15)
				{
					gamestate.ammo += 5;
				}
				if (tiletype == 16)
				{
					gamestate.gotPogo = true;
				}
				PlaySound(GOTITEMSND);
#if (EPISODE == 1)
				SETTILE(x, y, 0, 143);
#elif (EPISODE == 2)
				if (GETTILE(x, y, 0) > 305)	// Note: could just check the 'tile' variable here!
				{
					SETTILE(x, y, 0, 276);
				}
				else
				{
					SETTILE(x, y, 0, 143);
				}
#elif (EPISODE == 3)
				SETTILE(x, y, 0, (tile/13)*13);	// blank tile is always the first tile in a row of 13 tiles in the tileset
#endif
				break;

			case 17:
				if (objlist[0].think == KeenWalk)
				{
					PlaySound(LVLDONESND);
					objlist[0].think = KeenExit;
					objlist[0].contact = NullContact;
					objlist[0].temp1 = x+2;
					objlist[0].temp2 = y;
				}
				break;

			case 18:
			case 19:
			case 20:
			case 21:
				gamestate.keys[tiletype-18] = true;
				PlaySound(GETCARDSND);
#if (EPISODE != 3)
				SETTILE(x, y, 0, 143);
#else
				SETTILE(x, y, 0, (tile/13)*13);	// blank tile is always the first tile in a row of 13 tiles in the tileset
#endif
				break;

			case 22:
				ShowMessage();
#if (EPISODE == 1)
				if (level == 11)
					SETTILE(x, y, 0, 434);
				else
					SETTILE(x, y, 0, 315);
#else
				SETTILE(x, y, 0, 143);
#endif
				break;

			case 23:
			case 25:
			case 26:
				buttontouched = true;
				switchxtile = x;
				switchytile = y;
				break;

			case 24:
				LevelDone = ex_warped;
				break;

#if (EPISODE == 3) || ((EPISODE == 1) && (VERSION == VER_110))
			case 27:
				ankhtime += 1400;	// a little under 10 seconds
#if EPISODE != 1
				PlaySound(ANKHSND);
#endif
				SETTILE(x, y, 0, (tile/13)*13);	// blank tile is always the first tile in a row of 13 tiles in the tileset
				break;

			case 28:
				gamestate.ammo++;
#if EPISODE != 1
				SETTILE(x, y, 0, (tile/13)*13);	// blank tile is always the first tile in a row of 13 tiles in the tileset
#endif
				PlaySound(GOTITEMSND);
				break;
#endif
			}
		}
	}
}


/*
=====================
=
= KeenContact
=
=====================
*/

void KeenContact(objtype *ob, objtype *hit)
{
	switch (hit->obclass)
	{
#if (EPISODE == 1)

	case yorpobj:
		if (hit->think == YorpStunned)
		{
			break;
		}
		
		if (ob->yspeed <= 0 || ob->y + 8*PIXGLOBAL > hit->y)
		{
			// Yorp pushes Keen to the side:
			ob->yspeed = 0;
			if (hit->xspeed > 0)
			{
				ob->xspeed = 240;
			}
			else
			{
				ob->xspeed = -240;
			}
			PlaySound(YORPBUMPSND);
		}
		else
		{
			// Keen stuns Yorp:
			hit->think = YorpStunned;
			hit->temp1 = 0;
			ob->yspeed = 0;
			ob->think = KeenWalk;
			PlaySound(YORPBOPSND);
		}
		break;

	case butlerobj:
	case tankobj:
		// push Keen to the side:
		ob->yspeed = 0;
		if (hit->xspeed > 0)
		{
			ob->xspeed = 240;
		}
		else
		{
			ob->xspeed = -240;
		}
		PlaySound(YORPBUMPSND);
		break;

	case gargobj:
	case vorticonobj:
	case enemyshotobj:
		if (hit->obclass == enemyshotobj && ob->think == KeenFrozen)
		{
			ob->temp1 = 0;	// breaks the ice
		}
		else
		{
			HurtKeen();
		}
		break;

	case iceballobj:
		ob->think = KeenFrozen;
		ob->xspeed = hit->xspeed;
		ob->yspeed = hit->yspeed;
		ob->temp1 = 800;	// stay frozen for 5.7 seconds
		PlaySound(KEENSICLESND);
		break;

#elif (EPISODE == 2)

	case scrubobj:
	case platformobj:
		RideObj(ob, hit);
		break;

	case youthobj:
		if (ob->think == KeenFrozen)
		{
			break;
		}
		
		ob->think = KeenFrozen;
		ob->xspeed = hit->xspeed;
		ob->yspeed = hit->yspeed;
		ob->temp1 = 400;	// stay stunned for about 2.8 seconds
		break;

	case gruntobj:
	case eliteobj:
	case guardobj:
	case enemyshotobj:
		HurtKeen();
		break;

#elif (EPISODE == 3)

	case ballobj:
	case platformobj:
		RideObj(ob, hit);
		break;

	case youthobj:
		if (ob->think == KeenFrozen || cheatmode || ankhtime)
		{
			break;
		}
		
		ob->think = KeenFrozen;
		ob->xspeed = hit->xspeed;
		ob->yspeed = hit->yspeed;
		ob->temp1 = 400;	// stay stunned for about 2.8 seconds
		break;

	case womanobj:
	case meepobj:
		PushObj(ob, hit);
		break;

	case gruntobj:
	case ninjaobj:
	case jackobj:
	case enemyshotobj:
	case meepwaveobj:
		HurtKeen();
		break;

#endif
	}
}


/*
=====================
=
= SpawnPlayerShot
=
=====================
*/

void SpawnPlayerShot(Sint32 x, Sint32 y)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = shotobj;
	ob->x = x;
	ob->y = y + 9*PIXGLOBAL;
	ob->think = ShotThink;
	ob->yspeed = 0;
	ob->contact = ShotContact;
	ob->shapenum = KEENSHOTSPR;

	if (lastdir >= 0)
	{
		ob->xspeed = 400;
		// check tile, so shot won't fly through walls:
		if (eastwall[GETTILE(GLOBAL_TO_TILE(x)+1, GLOBAL_TO_TILE(y)+1, 0)])
		{
			PlaySound(SHOTHITSND);
			ob->obclass = splashobj;
			ob->think = ShotSplash;
			ob->temp1 = 0;
			if (RndT() > 128)
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
		ob->xspeed = -400;
		// check tile, so shot won't fly through walls:
		if (westwall[GETTILE(GLOBAL_TO_TILE(x), GLOBAL_TO_TILE(y)+1, 0)])
		{
			PlaySound(SHOTHITSND);
			ob->obclass = splashobj;
			ob->think = ShotSplash;
			ob->temp1 = 0;
			if (RndT() > 128)
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
= ShotSplash
=
=====================
*/

void ShotSplash(void)
{
	obon.obclass = deadobj;
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 20)
	{
		obon.obclass = nothing;
		return;
	}
}


/*
=====================
=
= ShotThink
=
=====================
*/

void ShotThink(void)
{
	Sint16 block;

	block = MoveObon();
	if (block)
	{
		PlaySound(SHOTHITSND);
		obon.obclass = splashobj;
		obon.think = ShotSplash;
		obon.temp1 = 0;
		if (RndT() > 128)
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
= ShotContact
=
=====================
*/

void ShotContact(objtype *ob, objtype *hit)
{
	if (hit->obclass == keenobj || hit->obclass == deadobj)
	{
		return;
	}
	
	PlaySound(SHOTHITSND);
	ob->think = ShotSplash;
	ob->contact = NullContact;
	ob->temp1 = 0;
	if (RndT() > 128)
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
= DeadThink
=
=====================
*/

void DeadThink(void)
{
	obon.temp1++;
	DoGravity();
	MoveObon();
}


/*
=====================
=
= DyingThink
=
=====================
*/

void DyingThink(void)
{
	obon.obclass = deadobj;
	obon.temp1 = obon.temp1 + tics;
	if (obon.temp1 > 40)
	{
		obon.temp1 -= 40;
		obon.shapenum++;
		if (--obon.temp2 == 1)	// no death animation frames left?
		{
			obon.think = DeadThink;
		}
	}
	obon.xspeed = 0;
	DoGravity();
	MoveObon();
}


/*
=====================
=
= SpawnEnemyShot
=
=====================
*/

void SpawnEnemyShot(Sint32 x, Sint32 y, Sint16 xspeed)
{
	objtype *ob;

	ob = FindFreeObj();
	ob->obclass = enemyshotobj;
	ob->x = x;
	//Note: y position is not set in Keen 3 (Keen 3 doesn't use this routine)
#if (EPISODE == 2) || ((EPISODE == 1) && (VERSION < VER_100))
	ob->y = y + 9*PIXGLOBAL;
#elif (EPISODE == 1)
	ob->y = y + 5*PIXGLOBAL;
#endif
	ob->think = ShotThink;
	ob->xspeed = xspeed;
#if VERSION < VER_100
	ob->x += ob->xspeed;
#endif
	ob->contact = EnemyShotContact;
	ob->shapenum = TANKSHOTSPR;

#if VERSION >= VER_100
	if (xspeed >= 0)
	{
		// check tile, so shot won't fly through walls:
		if (eastwall[GETTILE(GLOBAL_TO_TILE(x)+1, GLOBAL_TO_TILE(y)+1, 0)])
		{
			PlaySound(SHOTHITSND);
			ob->obclass = splashobj;
			ob->think = ShotSplash;
			ob->temp1 = 0;
			if (RndT() > 128)
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
		// check tile, so shot won't fly through walls:
		if (westwall[GETTILE(GLOBAL_TO_TILE(x), GLOBAL_TO_TILE(y)+1, 0)])
		{
			PlaySound(SHOTHITSND);
			ob->obclass = splashobj;
			ob->think = ShotSplash;
			ob->temp1 = 0;
			if (RndT() > 128)
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
#endif
}


/*
=====================
=
= EnemyShotContact
=
=====================
*/

void EnemyShotContact(objtype *ob, objtype *hit)
{
	// Note: Keen 3 has no if-check here (Keen 3 doesn't use this routine)
#if (EPISODE == 1)
	if (hit->obclass == tankobj || hit->obclass == deadobj)
	{
		return;
	}
#elif (EPISODE == 2)
	if (hit->obclass == guardobj || hit->obclass == deadobj || hit->obclass == eliteobj)
	{
		return;
	}
#endif

	PlaySound(SHOTHITSND);
	ob->think = ShotSplash;
	ob->temp1 = 0;
	ob->contact = NullContact;
	if (RndT() > 128)
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
= BorderFlash
=
=====================
*/

void BorderFlash(pobjtype *pob)
{
	pob->temp1 = pob->temp1 + tics;
	if (pob->temp1 > 300)
	{
		// set border color to cyan:
		_AH = 0x10;
		_AL = 1;
		_BH = 3;
		geninterrupt(0x10);

		// remove flasher object:
		pob->type = POBJ_NOTHING;
	}
	else
	{
		// flip border color (brown and cyan):
		if (((Uint16)timecount >> 6) & 1)
		{
			// set border color to brown:
			_AH = 0x10;
			_AL = 1;
			_BH = 14;
			geninterrupt(0x10);
		}
		else
		{
			// set border color to cyan:
			_AH = 0x10;
			_AL = 1;
			_BH = 3;
			geninterrupt(0x10);
		}
	}
}


/*
=====================
=
= BridgeCreate
=
=====================
*/

void BridgeCreate(pobjtype *pob)
{
	Sint16 x;

	pob->temp1 = pob->temp1 + tics;
	if (pob->temp1 < 12)
	{
		return;
	}
	
	pob->temp1 -= 12;
	x = pob->x + pob->temp4;
	if (GETTILE(x, pob->y, 0) != pob->temp3)
	{
		pob->think = NullPThink;	// enter waiting state
	}
	else
	{
		SETTILE(x, pob->y, 0, 270);
		pob->temp4 += pob->temp2;
	}
}


/*
=====================
=
= BridgeRemove
=
=====================
*/

void BridgeRemove(pobjtype *pob)
{
	Sint16 x;

	pob->temp1 = pob->temp1 + tics;
	if (pob->temp1 < 12)
	{
		return;
	}
	
	pob->temp1 -= 12;
	pob->temp4 -= pob->temp2;
	x = pob->x + pob->temp4;
	if (GETTILE(x, pob->y, 0) != 270)
	{
		pob->type = POBJ_NOTHING;	// remove the bridge object
	}
	else
	{
		SETTILE(x, pob->y, 0, pob->temp3);
	}
}


/*
=====================
=
= LevelLoop
=
=====================
*/

exittype LevelLoop(Sint16 currentlevel)
{
	boolean showbossintro;
	Sint16 tx, ty, i, i2;
	objtype *ob, *ob2;
	pobjtype *pob;

	// initialize object lists:
	objlist[0].obclass = keenobj;
	objlist[0].think = KeenWalk;
	objlist[0].contact = KeenContact;
	objlist[0].xspeed = objlist[0].yspeed = 0;
	objlist[0].shapenum = KEENWALKL1SPR;	// dummy value (Keen thinks before sprite is drawn)
	objlist[0].active = true;
	numobj = 1;
	pobjcount = 0;

#if (VERSION >= VER_120)
	showbossintro = true;	// only used in Keen 3
#endif
	lastdir = 1;	// Keen starts off facing right (ignore the sprite number above!)

	timecount = lasttimecount = tics = 0;
#if VERSION < VER_100
	LevelDone = 0;
#elif VERSION == VER_100
	LevelDone = cheatmode = 0;
#else
	LevelDone = cheatmode = ankhtime = 0;
#endif

	LoadLevel(currentlevel);

#ifdef K13_PORT
	/* Keen Launcher: a quickload for this level was requested, so the map is
	   now loaded and the spawned objects can be replaced with the saved ones.
	   Done here -- after LoadLevel, before the play loop -- so the restored
	   state is what the first frame sees. */
	if (K13_QLoadPending())
	{
		K13_QLoadApply();
		RF_ForceRefresh();
	}
	else
	{
#endif
	// adjust screen to center on Keen:
	originx = objlist[0].x - 10*TILEGLOBAL;
	originy = objlist[0].y - 5*TILEGLOBAL;
	if (originx < originxmin)
	{
		originx = originxmin;
	}
	if (originy < originymin)
	{
		originy = originymin;
	}
	if (originx > originxmax)
	{
		originx = originxmax;
	}
	if (originy > originymax)
	{
		originy = originymax;
	}
#ifdef K13_PORT
	}	/* end of the non-quickload path: a restore brings its own camera */
#endif

	// first refresh:
	RF_Clear();
#if VERSION <= VER_120
	if (!levelnum)	// if NOT started with /LEVEL parameter
	{
		FadeOut();
	}
#else
	FadeOut();
#endif
	lightson = true;
	RF_ForceRefresh();
	RF_Refresh();
	RF_Refresh();
	FadeIn();	// Note: no sprites are visible during the fade, only the tiles!

	ox = GLOBAL_TO_TILE(originx);
	oy = GLOBAL_TO_TILE(originy);

	do
	{
		RF_Clear();
		ctrl = ControlPlayer(1);

		// update all objects:
		ob = &objlist[0];
		for (i = 0; i < numobj; i++, ob++)
		{
			if (ob->obclass == nothing)
			{
				continue;
			}

			obon = *ob;
			if (obon.active)
			{
#if (EPISODE == 1)
				if (i == 0 || !RemoveInactive())
#else
				if (i == 0 || obon.obclass == platformobj || !RemoveInactive())
#endif
				{
					UpdateObonHitbox();
					obon.xmove = obon.ymove = 0;
					obon.think();
					obon.x += obon.xmove;
					obon.y += obon.ymove;
					UpdateObonHitbox();
				}
			}
			else
			{
				tx = GLOBAL_TO_TILE(obon.x);
				ty = GLOBAL_TO_TILE(obon.y);
				if (ox-2 < tx && oy-2 < ty && ox+23 > tx && oy+12 > ty)
				{
					obon.active = true;
#if (EPISODE == 1)
					if (obon.think == YorpStunned)
					{
						obon.think = YorpStand;
						obon.temp1 = 0;
					}
#elif (EPISODE == 3)
					if (obon.think == FoobRun)
					{
						obon.think = FoobWalk;
						if (obon.x > objlist[0].x)
						{
							obon.xspeed = 50;
						}
						else
						{
							obon.xspeed = -50;
						}
					}
#endif

					UpdateObonHitbox();
					obon.xmove = obon.ymove = 0;
					obon.think();
					obon.x += obon.xmove;
					obon.y += obon.ymove;
					UpdateObonHitbox();
				}
			}
			*ob = obon;
		}
#if 0
		//
		// allow player to scroll the screen up or down:
		//
		if (objlist[0].think == KeenWalk)
		{
			if (keydown[key[north]])
			{
				originy -= tics * (PIXGLOBAL/2);
				if (objlist[0].y - originy > 7*TILEGLOBAL)
				{
					originy = objlist[0].y - 7*TILEGLOBAL;
				}
				if (originy > originymax)
				{
					originy = originymax;
				}
				if (originy < originymin)
				{
					originy = originymin;
				}
			}
			if (keydown[key[south]])
			{
				originy += tics * (PIXGLOBAL/2);
				if (objlist[0].y - originy < 3*TILEGLOBAL)
				{
					originy = objlist[0].y - 3*TILEGLOBAL;
				}
				if (originy < originymin)
				{
					originy = originymin;
				}
				if (originy > originymax)
				{
					originy = originymax;
				}
			}
		}
#endif

		ScrollScreen();

		// check object vs. object collisions:
		ob = &objlist[0];
		for (i = 0; i < numobj; i++, ob++)
		{
			if (ob->obclass != nothing && ob->active)
			{
				ob2 = &objlist[i+1];
				for (i2 = i+1; i2 < numobj; i2++, ob2++)
				{
					if (ob2->obclass != nothing && ob2->active && ObjectsCollide(ob, ob2))
					{
						ob->contact(ob, ob2);
						ob2->contact(ob2, ob);
					}
				}
			}
		}

		// place sprites for the objects:
		ox = GLOBAL_TO_TILE(originx);
		oy = GLOBAL_TO_TILE(originy);
		// Sprites are placed in reverse order, so Keen's
		// sprite is always drawn on top of other sprites.
		ob = &objlist[numobj-1];
		for (i = numobj-1; i >= 0; i--, ob--)
		{
			if (ob->obclass != nothing && ob->active)
			{
				RF_PlaceSprite(ob->x, ob->y, ob->shapenum);
			}
		}
#if (EPISODE == 3)
		// The one exception to the rule above is the invincibility halo effect
		// in Keen 3, which is drawn on top of Keen's sprite
		if (ankhtime || cheatmode)
		{
			if (ankhtime > 250)
			{
				RF_PlaceSprite(objlist[0].x - 8*PIXGLOBAL, objlist[0].y - 8*PIXGLOBAL, (((Uint16)timecount >> 4) & 1) + GODHALOSPR);
			}
			else if (((Uint16)timecount >> 4) & 1)
			{
				RF_PlaceSprite(objlist[0].x - 8*PIXGLOBAL, objlist[0].y - 8*PIXGLOBAL, (((Uint16)timecount >> 5) & 1) + GODHALOSPR);
			}
			if ((ankhtime -= tics) < 0)
			{
				ankhtime = 0;
			}
		}
#endif

		PlayerCheckTiles();

		// update all invisible objects:
		pob = &pobjlist[0];
		for (i = 0; i < pobjcount; i++, pob++)
		{
			if (pob->type != POBJ_NOTHING)
			{
				pob->think(pob);
			}
		}

		// Note: Some invisible objects alter the tiles in the level, which can
		// cause some minor visual glitches when the altered tiles are foreground
		// tiles. The sprites have already been placed before updating the
		// invisible objects, which means any foreground tiles covering the
		// sprites will be drawn using the old tile images and positions and
		// won't match the other tiles.
		//
		// The glitches can be observed when the Vorticon Commander is crushed by
		// the falling block in Keen 1 level 16.
		//
		// There's also the fact that the PlayerCheckTiles() routine pushes Keen
		// out of the door tiles. Since this is done after Keen's sprite has been
		// placed, Keen's sprite will still be drawn touching that door tile,
		// leading to some jerky motion.
		//
		// This could easily be fixed by placing the sprites after the invisible
		// objects have been updated and the tiles have been checked.

		// update the screen:
		RF_Refresh();

		// save current input (for detecting button hits):
		ctrl2 = ctrl;

#if (EPISODE == 3)
		if (showbossintro && currentlevel == 16)
		{
			BossLevelIntro();
			showbossintro = false;
		}
#endif

		// generic UI stuff:
		HandleUserKeys();
		if (DoFkeys())
		{
			lasttimecount = timecount;
		}

		if (resetgame)
		{
			return ex_nothing;
		}

	} while (!LevelDone && objlist[0].obclass != nothing);

	WaitEndSound();
	FadeOut();

	// lose all keys:
	for (tx=0; tx<NUMKEYS; tx++)
	{
		gamestate.keys[tx] = false;
	}

	// lose items/cities if Keen died in their level
	if (LevelDone == ex_nothing)
	{
#if (EPISODE == 1)
		switch (currentlevel)
		{
		case 3:
			gamestate.gotBattery = false;
			break;

		case 4:
			gamestate.gotJoystick = false;
			break;

		case 8:
			gamestate.gotVacuum = false;
			break;

		case 16:
			gamestate.gotEverclear = false;
			break;
		}
#elif (EPISODE == 2)
		switch (currentlevel)
		{
		case 4:
			gamestate.citySaved[CITY_LONDON] = false;
			break;

		case 6:
			gamestate.citySaved[CITY_CAIRO] = false;
			break;

		case 7:
			gamestate.citySaved[CITY_SYDNEY] = false;
			break;

		case 9:
			gamestate.citySaved[CITY_NEWYORK] = false;
			break;

		case 11:
			gamestate.citySaved[CITY_PARIS] = false;
			break;

		case 13:
			gamestate.citySaved[CITY_ROME] = false;
			break;

		case 15:
			gamestate.citySaved[CITY_MOSCOW] = false;
			break;

		case 16:
			gamestate.citySaved[CITY_WASHINGTONDC] = false;
			break;
		}
#endif
	}

	return LevelDone;
}
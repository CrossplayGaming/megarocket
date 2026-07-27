/* Reconstructed Commander Keen 1-3 Source Code
 * Copyright (C) 2021-2025 K1n9_Duk3
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

#ifndef __KD_DEF_H__
#define __KD_DEF_H__

#include <BIOS.H>
#include "IDLIB.H"

/*
=============================================================================

			GLOBAL CONSTANTS

=============================================================================
*/
#define NUMLEVELS	16
#define MAXTEXTLINES 200

#define EXTRASCORE 20000

// Messie constants for Keen 3:
#define MESSIESPEED 2	// movement speed, in pixels
#define MESSIEMOVES (16/MESSIESPEED)	// must move this many times to pass through one tile

#if (EPISODE == 1)
#define NUMWARPS 3
#elif (EPISODE == 3)
#define NUMWARPS 16
#else
#define NUMWARPS 0
#endif

#define BIGBUFFERSIZE 0x10000


/*
=============================================================================

			TYPES

=============================================================================
*/

//SDL-style integer types - just to make future SDL ports easier
//(Keen Launcher port: mapped to stdint exact-width types, as the
// reconstruction's own size-check comments direct.)
#include <stdint.h>
#ifndef K13_EXACT_TYPES
#define K13_EXACT_TYPES
typedef uint16_t Uint16;
typedef int16_t Sint16;
typedef uint8_t Uint8;
typedef int8_t Sint8;
typedef uint32_t Uint32;
typedef int32_t Sint32;
#endif
//Note: only the game code (KEEN*.C) uses these!


// compile-time checks that *should* work for any C/C++ compiler:

#define VERIFY_EXPRESSION(expr, name) typedef char name[(expr)? 1 : -1];
#define VERIFY_SIZE(type, size) VERIFY_EXPRESSION(sizeof(type) == size, type##SizeTest)

/*
If you get a compiler error for any of the following lines, it means the size
check has failed and you need to change the type declaration (see above) into
the correct base type for your compiler.
*/
VERIFY_SIZE(Uint8, 1);
VERIFY_SIZE(Sint8, 1);
VERIFY_SIZE(Uint16, 2);
VERIFY_SIZE(Sint16, 2);
VERIFY_SIZE(Uint32, 4);
VERIFY_SIZE(Sint32, 4);

// size checks for IDLIB.H structures:
VERIFY_SIZE(spritetype, 0x20);
VERIFY_SIZE(pictype, 0x10);
#if VERSION >= VER_132
VERIFY_SIZE(grheadtype, 0x36);
#else
VERIFY_SIZE(grheadtype, 0x30);
#endif

/*
=============================================================================

			      REFRESH

=============================================================================
*/

#define MINTICS	6
#define MAXTICS	15

#define G_T_SHIFT	12
#define G_P_SHIFT	8

#define TILEGLOBAL	(1l << G_T_SHIFT)
#define PIXGLOBAL 	(1l << G_P_SHIFT)

#define TILE_TO_GLOBAL(n)	((Sint32)(n) << G_T_SHIFT)
#define GLOBAL_TO_TILE(n)	((Sint32)(n) >> G_T_SHIFT)
#define PIXEL_TO_GLOBAL(n)	((Sint32)(n) << G_P_SHIFT)
#define GLOBAL_TO_PIXEL(n)	((Sint32)(n) >> G_P_SHIFT)

#if VERSION <= VER_131
#define TILE_ALIGN(x) x = x & ~(TILEGLOBAL-1)
#else
#define TILE_ALIGN(x) (x) &= ~(TILEGLOBAL-1);
#endif

#define PORTTILESWIDE 21
#define PORTTILESHIGH 14
#if VERSION < VER_100
#define BIGPORTSIZE (PORTTILESHIGH*PORTTILESWIDE)
#else
#define BIGPORTSIZE ((PORTTILESHIGH+1)*(PORTTILESWIDE+1))
#endif

typedef struct
{
	Sint16 x, y;
	Sint16 num;
} drawtype;

/*
=============================================================================

			   COMMANDER KEEN MAIN

=============================================================================
*/

#define WORLDMAP  80	// level number for world map
#define ENDINGMAP 81	// level number for ending sequence
#define TITLEMAP  90	// level number for title screen, main menu, etc.

// origin positions for title screen, order screen, etc. (for TITLEMAP)
#define X_TITLE         (2*TILEGLOBAL)
#define X_ORDER         (22*TILEGLOBAL)
#define X_STORY         (42*TILEGLOBAL)
#define X_ID            (63*TILEGLOBAL)
#define X_HIGH          (84*TILEGLOBAL)
#define X_APOGEE        (104*TILEGLOBAL)

#define Y_TITLE         (2*TILEGLOBAL)
#define Y_ORDER         (2*TILEGLOBAL)
#define Y_STORY         (2*TILEGLOBAL)
#define Y_ID            (2*TILEGLOBAL-(TILEGLOBAL/4))
#define Y_HIGH          (2*TILEGLOBAL)
#define Y_APOGEE        (2*TILEGLOBAL)

#define SCREENTIME      2400    // # of tics to wait (about 145 tics per second)


typedef enum
{
	nothing,
	keenobj,
#if (EPISODE == 1)
	yorpobj,
	gargobj,
	vorticonobj,
	butlerobj,
	tankobj,
	classtype_7,
	chainobj,
	volatileobj,	// used as a marker - objects of the following types are removed when off-screen
	shotobj,
	enemyshotobj,
	icechunkobj,
	splashobj,
	deadobj,
	iceballobj,
#elif (EPISODE == 2)
	gruntobj,
	youthobj,
	eliteobj,
	scrubobj,
	guardobj,
	platformobj,
	sparkobj,
	volatileobj,	// used as a marker - objects of the following types are removed when off-screen
	shotobj,
	enemyshotobj,
	splashobj,
	deadobj,
#elif (EPISODE == 3)
	gruntobj,
	youthobj,
	womanobj,
	meepobj,
	ninjaobj,
	foobobj,
	ballobj,
	jackobj,
	platformobj,
	classtype_11,
	heartobj,
	sparkobj,
	volatileobj,	// used as a marker - objects of the following types are removed when off-screen
	shotobj,
	enemyshotobj,
	meepwaveobj,
	splashobj,
	deadobj,
#endif
	NUMCLASSTYPES
} classtype;

typedef struct objstruct
{
	classtype obclass;
	boolean active;
	Sint32 x, y;
	Sint32 left, top, right, bottom;
	Sint16 xmove, ymove;
	Sint16 xspeed, yspeed;
	Sint16 health;
	Sint16 baseshape, shapenum;
	Sint16 temp1, temp2, temp3, temp4;
	void (*think)(void);
	void (*contact)(struct objstruct*, struct objstruct*);
} objtype;
typedef void (*objcontact)(struct objstruct*, struct objstruct*);	// for typecasting


// Note:
// SHADOW KNIGHTS also uses something very similar to the following struct and
// it has the error message "PObj list overflow!" associated with it. I don't
// know what the P in "PObj" actually stands for.
typedef enum
{
	POBJ_NOTHING,
	POBJ_OPENDOOR,
	POBJ_BRIDGE,
	POBJ_CANNON,
#if (EPISODE == 1)
	POBJ_BLOCKFALL,
#endif
	POBJ_BORDERFLASH,
#if (EPISODE == 2)
	POBJ_TANTALUSEXPLOSION,
#elif (EPISODE == 3)
	POBJ_TURRET,
	POBJ_ARM,
	POBJ_FOOT,
	POBJ_DESTROYARMS,
	POBJ_DESTROYMACHINE,
#endif
	NUMPCLASSTYPES
} pobjclass;

typedef struct pobjstruct
{
	Sint32 x, y;
	pobjclass type;
	Sint16 temp1, temp2, temp3, temp4, temp5, temp6,
		temp7, temp8, temp9, temp10, temp11, temp12;
	void (*think)(struct pobjstruct*);
} pobjtype;
typedef void (*pobjthink)(struct pobjstruct*);	// for typecasting

enum
{
	CITY_LONDON,
	CITY_CAIRO,
	CITY_SYDNEY,
	CITY_NEWYORK,
	CITY_PARIS,
	CITY_ROME,
	CITY_MOSCOW,
	CITY_WASHINGTONDC,
	NUMCITIES
};

#define BLOCK_NONE  0
#define BLOCK_LEFT  1
#define BLOCK_DOWN  2
#define BLOCK_RIGHT 4
#define BLOCK_UP    8

typedef struct
{
	Sint16 x, y;
	Sint16 type;
} entrancetype;

typedef struct
{
	Sint32 x, y;
	Sint16 tag;
} warptype;

#define NUMKEYS 4

/* Keen Launcher port: gametype and highscoretype are written to disk
 * verbatim (SAVED?.CKx / SCORES.CKx), so they use 16-bit booleans and
 * Turbo C's word alignment to match the DOS file layouts exactly. */
#pragma pack(push, 2)
typedef struct
{
	Sint16 gotJoystick, gotVacuum, gotEverclear, gotPogo, gotBattery;
	Sint16 keys[NUMKEYS];
	Sint16 leveldone[NUMLEVELS];
	Sint16 lives;
	Sint16 ammo;
	Sint32 score;
	Sint32 worldx, worldy;
	Sint32 worldoriginx, worldoriginy;
	Sint16 citySaved[NUMCITIES];
#if VERSION >= VER_100
	Sint16 _unused;
#endif
} gametype;

#define HIGHSCORE_NUMENTRIES 7
#define HIGHSCORE_NAMELENGTH 12
typedef struct
{
	Sint32 scores[HIGHSCORE_NUMENTRIES];
	Sint16 gotJoystick[HIGHSCORE_NUMENTRIES];
	Sint16 gotBattery[HIGHSCORE_NUMENTRIES];
	Sint16 gotEverclear[HIGHSCORE_NUMENTRIES];
	Sint16 gotVacuum[HIGHSCORE_NUMENTRIES];
#if VERSION >= VER_100
	Sint16 citiesSaved[HIGHSCORE_NUMENTRIES];
	Sint16 _unused[HIGHSCORE_NUMENTRIES];
#endif
	char names[HIGHSCORE_NUMENTRIES][HIGHSCORE_NAMELENGTH+1];
} highscoretype;
#pragma pack(pop)

/* the DOS layouts these must match (SCORES file is 204 bytes on disk) */
typedef char k13_assert_scores[(sizeof(highscoretype) == 204) ? 1 : -1];
typedef char k13_assert_saves[
	(sizeof(gametype) == 44 + 2 * NUMLEVELS + 2 * NUMCITIES) ? 1 : -1];

typedef enum
{
	ex_nothing, ex_completed, ex_warped, ex_tantalus
} exittype;

#if VERSION <= VER_110
#define MAXOBJECTS	60
#else
#define MAXOBJECTS	80
#endif
#define MAXPOBJECTS	16

typedef struct
{
	Uint16 off, len;
} linetype;


#define MAXANIMS 10

typedef struct
{
	boolean used;
	Sint16 x, y;
	Sint16 speed;
	Sint16 animdelay;
	Sint16 shapenums[4];
	Sint16 dirptr;	// actually a (near) pointer to Sint8, but treated as a number 
	Sint16 dirindex;
	Sint16 frame;
	Sint16 ID;
} animtype;


/*
=============================================================================

			   INCLUDED DATA

=============================================================================
*/

extern char far endscreen[];

extern int nexttile[], intile[],
	northwall[], eastwall[],
	southwall[], westwall[];

/*
=============================================================================

			   KEENMAIN.C

=============================================================================
*/

extern ControlStruct ctrl, lastctrl;

extern Uint32 lasttimecount;
extern Sint32 monxmax, monymax, originxmin, originymin;
extern Sint32 playerxmax, playerymax, originxmax, originymax;
extern Sint16 ox, oy;	// tile origin
extern Sint32 originx, originy;	// origin in global units
//extern Uint16 EGApage;
extern Uint16 tilesshown;
extern drawtype *tilelistptr;

#define bigbuffer ((Uint8 far *)levelheader)
extern LevelDef far *levelheader;
extern gametype gamestate;

#ifdef K13_PORT
/* Keen Launcher: native Options screen (KEENSCRN.C) + port services */
void OptionsMenu(void);
int K13_GetWideWidth(void);
void K13_SetWideWidth(int w);
int K13_GetSmooth(void);
void K13_SetSmooth(int on);
void K13_ConfigSave(void);
void K13_ToggleFullscreen(void);
int K13_IsFullscreen(void);
int K13_GetOneFire(void);
void K13_SetOneFire(int on);

/* rebindable controls (Options -> Controls).  Pad binding codes are SDL
 * controller button numbers, plus these two for the analog triggers;
 * K13_BIND_* name the slots.  FIREKEY holds a DOS scan code, not a pad
 * code -- it is the keyboard control for one-button fire. */
#define K13_PAD_LTRIG 100
#define K13_PAD_RTRIG 101
#define K13_BIND_JUMP     0
#define K13_BIND_POGO     1
#define K13_BIND_FIRE     2
#define K13_BIND_STATUS   3
#define K13_BIND_QSAVE    4
#define K13_BIND_QLOAD    5
#define K13_BIND_HELP     6
#define K13_BIND_SOUND    7
#define K13_BIND_SAVEMENU 8
#define K13_BIND_QUIT     9
#define K13_BIND_SCOREBOX 10
#define K13_BIND_COUNT    11

/* keyboard binds, DOS scan codes.  FIRE is the one-button fire control; the
 * other three are the keys the original engine hard-coded (Space for the
 * status screen) or that this port added (quicksave/quickload), all made
 * rebindable so nothing is keyboard-only or fixed. */
#define K13_KEY_FIRE     0
#define K13_KEY_QSAVE    1
#define K13_KEY_QLOAD    2
#define K13_KEY_STATUS   3
#define K13_KEY_HELP     4
#define K13_KEY_SOUND    5
#define K13_KEY_KEYCONF  6
#define K13_KEY_JOYCONF  7
#define K13_KEY_SAVEMENU 8
#define K13_KEY_QUIT     9
#define K13_KEY_SCOREBOX 10
#define K13_KEY_COUNT    11
int K13_GetKeyBind(int which);
void K13_BindKey(int which, int scan);
void K13_BindPad(int which, int code);
void K13_SetKeyBind(int which, int scan);
/* which action a scan code is bound to, or -1.  0 as a bind means unbound:
 * every control here can be cleared.  The pad's START/BACK stay wired to menu
 * confirm/cancel no matter what, so nothing can lock you out of the menus. */
int K13_KeyAction(int scan);
/* Pad presses for an action whose keyboard key is unbound are injected on a
 * private synthetic scan code (0x60+action), so clearing a key never breaks
 * the pad.  K13_ActionDown answers "is this action held" across both. */
#define K13_SYNTH_SCAN(which) (0x60 + (which))
int K13_ActionDown(int which);
int K13_GetScoreBox(void);
int K13_GalaxyAvail(void);
int K13_GalaxyMusAvail(void);
int K13_GetGalaxyMus(void);
void K13_SetGalaxyMus(int on);
int K13_GetGalaxySfx(void);
void K13_SetGalaxySfx(int on);
void K13_SetScoreBox(int on);

/* DoFkeys switches on these.  In the port they are ACTION ids, so the keys are
 * rebindable; without the port they stay the scan codes the game shipped with,
 * leaving the original switch behaviour intact. */
#define K13_FKEY_SCAN     (NBKscan & 0x7F)
#define K13_FKEY_HELP     K13_KEY_HELP
#define K13_FKEY_SOUND    K13_KEY_SOUND
#define K13_FKEY_KEYCONF  K13_KEY_KEYCONF
#define K13_FKEY_JOYCONF  K13_KEY_JOYCONF
#define K13_FKEY_SAVEMENU K13_KEY_SAVEMENU
#define K13_FKEY_QUIT     K13_KEY_QUIT
void K13_DoQuickSave(void);
void K13_DoQuickLoad(void);
/* two slots per action: slot 0 the face button, slot 1 a shoulder or trigger
 * alternate, so "either shoulder jumps" survives becoming rebindable */
void ControlsMenu(void);
int K13_GetBackdrop(void);
void K13_SetBackdrop(int tile);
int K13_QuickSave(void);
int K13_QuickLoad(void);
int K13_QuickSaveLevel(void);
int K13_GetBind(int which, int slot);
void K13_SetBind(int which, int slot, int code);
int K13_GetFireKey(void);
void K13_SetFireKey(int scan);
void K13_ResetBinds(void);
boolean K13_Confirm(char *question);
int K13_GetQSConfirm(void);
void K13_StaticScreen(int on);
int K13_GetFullscreen(void);
void K13_SetFullscreen(int on);
void K13_SetQSConfirm(int on);
const char *K13_PadBindName(int code);
int K13_PadBindWait(void);
int K13_KeyBindWait(void);
#endif

extern boolean cheatmode;
extern Sint32 lastextra;
extern boolean resetgame;
extern exittype LevelDone;
extern Sint16 cyclespeed;
extern Uint16 tics;
extern objtype obon;

extern Sint16 numobj;
extern objtype objlist[MAXOBJECTS];
extern Sint16 pobjcount;
extern pobjtype pobjlist[MAXPOBJECTS];

extern Sint16 switchxtile, switchytile, sparksgone;
extern boolean buttontouched;
extern boolean lightson;
extern Sint16 lastdir;
extern ControlStruct ctrl, ctrl2;
extern Sint16 ankhtime;
extern Sint16 levelnum;

extern boolean SNDstarted,KBDstarted;	// whether int handlers were started

extern char huge *helptextPtr;
extern char huge *storytxtPtr;
extern char huge *endtextPtr;
extern char huge *previewsPtr;

extern Sint32 worldkeenx, worldkeeny, worldCamX, worldCamY, oldx, oldy;

#if (EPISODE == 3)
extern warptype warps[];
#endif
#if (EPISODE == 3)
extern Sint32 messiexmove, messieymove, messiex, messiey;
extern Sint16 messiecount, messieshape, messiecooldown;
extern Sint16 messieoldtilex, messieoldtiley, messiestate;
#endif

extern entrancetype entrances[NUMLEVELS];
extern boolean restoredGame, forcemenu;
extern Sint16 LevelNumber;
extern Sint16 infoBlockMask;

extern linetype *textLineOffsets;
extern char huge *textdataPtr;
extern Sint16 textWindowX, textWindowMinY, textVisibleLines, textWindowMaxY;

extern warptype warpspots[];

extern linetype line_offsets[MAXTEXTLINES];

extern boolean canSave;
extern highscoretype highscores;
/*
=============================================================================

=============================================================================
*/

void RF_Clear(void);
void RF_Refresh(void);
boolean RF_PlaceSprite(Sint32 x, Sint32 y, Sint16 shapenum);
boolean RF_PlaceTile(Sint32 x, Sint32 y, Sint16 tilenum);

void ReadLevel(Sint16 number);
void AskQuit(void);
Sint16 JoyButtonDown(void);
void WriteHuge(Sint16 handle, void huge *buff, Sint32 size);
void DrawPicFile(char *filename);
void SaveScreenshot(void);
boolean DoFkeys(void);
void GivePoints(Sint16 toadd);
void DoCheat(void);
void ShowStatusScreen(void);
void HandleUserKeys(void);
void Quit(char *error);

/*
=============================================================================

			   KEENACTS.C

=============================================================================
*/

void LoadLevel(Sint16 number);

#if (EPISODE == 1)

void SpawnTank(Sint16 x, Sint16 y);
void SpawnButler(Sint16 x, Sint16 y);
void SpawnVorticon(Sint16 x, Sint16 y);
void SpawnGarg(Sint16 x, Sint16 y);
void SpawnYorp(Sint16 x, Sint16 y);
void SpawnChain(Sint16 x, Sint16 y);
void SpawnCannon(Sint16 x, Sint16 y, Sint16 num);
void YorpWalk(void);
void YorpStand(void);
void YorpStunned(void);
void YorpContact(objtype *ob, objtype *hit);
void GargWalk(void);
void GargStand(void);
void GargContact(objtype *ob, objtype *hit);
void VorticonWalk(void);
void VorticonJump(void);
void VorticonStand(void);
void VorticonContact(objtype *ob, objtype *hit);
void ButlerWalk(void);
void ButlerStand(void);
void ButlerContact(objtype *ob, objtype *hit);
void TankMove(void);
void TankFall(void);
void TankStand(void);
void TankFire(void);
void TankContact(objtype *ob, objtype *hit);
void CannonThink(pobjtype *pob);
void SpawnIceball(Sint32 x, Sint32 y, Sint16 direction);
void IcechunkThink(void);
void IceballThink(void);
void IceballContact(objtype *ob, objtype *hit);
void ChainContact(objtype *ob, objtype *hit);
void BlockFall(pobjtype *pob);
void ShowMessage(void);
void KeenFrozen(void);

#elif (EPISODE == 2)

void SpawnGrunt(Sint16 x, Sint16 y);
void SpawnYouth(Sint16 x, Sint16 y);
void SpawnElite(Sint16 x, Sint16 y);
void SpawnScrub(Sint16 x, Sint16 y);
void SpawnGuard(Sint16 x, Sint16 y);
void SpawnPlatformX(Sint16 x, Sint16 y);
void SpawnSpark(Sint16 x, Sint16 y);
void GruntWalk(void);
void GruntJump(void);
void GruntStand(void);
void GruntContact(objtype *ob, objtype *hit);
void YouthWalk(void);
void YouthJump(void);
void YouthContact(objtype *ob, objtype *hit);
void EliteWalk(void);
void EliteShoot(void);
void EliteJump(void);
void EliteContact(objtype *ob, objtype *hit);
void ScrubWalkLeft(void);
void ScrubWalkDown(void);
void ScrubWalkRight(void);
void ScrubWalkUp(void);
void ScrubFall(void);
void ScrubContact(objtype *ob, objtype *hit);
void GuardMove(void);
void GuardShoot(void);
void GuardStand(void);
void GuardContact(objtype *ob, objtype *hit);
void PlatformMove(void);
void PlatformTurn(void);
void SparkThink(void);
void SparkContact(objtype *ob, objtype *hit);
void ExplodeTile(Sint16 x, Sint16 y, Sint16 newtile);
void TantalusExplode(pobjtype *pob);
void KeenFrozen(void);
void ShowMessage(void);
void TheEarthExplodes(void);

#elif (EPISODE == 3)

void SpawnGrunt(Sint16 x, Sint16 y);
void SpawnYouth(Sint16 x, Sint16 y);
void SpawnWoman(Sint16 x, Sint16 y);
void SpawnMeep(Sint16 x, Sint16 y);
void SpawnNinja(Sint16 x, Sint16 y);
void SpawnFoob(Sint16 x, Sint16 y);
void SpawnBall(Sint16 x, Sint16 y);
void SpawnJack(Sint16 x, Sint16 y);
void SpawnPlatformX(Sint16 x, Sint16 y);
void SpawnPlatformY(Sint16 x, Sint16 y);
void SpawnTurretE(Sint16 x, Sint16 y);
void SpawnTurretS(Sint16 x, Sint16 y);
void SpawnSpark(Sint16 x, Sint16 y);
void SpawnHeart(Sint16 x, Sint16 y);
void SpawnArm(Sint16 x, Sint16 y);
void SpawnFoot(Sint16 x, Sint16 y, Sint16 dir);
void GruntWalk(void);
void GruntJump(void);
void GruntStand(void);
void GruntContact(objtype *ob, objtype *hit);
void YouthWalk(void);
void YouthJump(void);
void YouthContact(objtype *ob, objtype *hit);
void WomanWalk(void);
void WomanShoot(void);
void SpawnWomanShot(Sint32 x, Sint32 y, Sint16 xspeed);
void WomanShotThink(void);
void WomanShotContact(objtype *ob, objtype *hit);
void WomanContact(objtype *ob, objtype *hit);
void MeepWalk(void);
void MeepSing(void);
void MeepContact(objtype *ob, objtype *hit);
void MeepWaveThink(void);
void NinjaStand(void);
void NinjaJump(void);
void NinjaContact(objtype *ob, objtype *hit);
void FoobWalk(void);
void FoobRun(void);
void FoobYell(void);
void FoobContact(objtype *ob, objtype *hit);
void JackThink(void);
void BallThink(void);
void PlatformThink(void);
void PlatformTurn(void);
void TankShotThink(void);
void TurretEThink(pobjtype *pob);
void TurretSThink(pobjtype *pob);
void SparkThink(void);
void SparkContact(objtype *ob, objtype *hit);
void HeartThink(void);
void HeartContact(objtype *ob, objtype *hit);
void ExplodeTile(Sint16 x, Sint16 y, Sint16 newtile);
void DestroyArms(pobjtype *pob);
void DestroyManglingMachine(pobjtype *pob);
void ArmThink(pobjtype *pob);
void FootThink(pobjtype *pob);
void FootIdle(pobjtype *pob);
void KeenFrozen(void);
void ShowMessage(void);
void KeenWindow(Sint16 width, Sint16 height);
void MortWindow(Sint16 width, Sint16 height);
boolean BossDelay(Sint16 vbls);
boolean BossTypeText(char *text);
void BossLevelIntro(void);
void PhotoFlash(void);

void UpdateMessie(objtype *keen);

#endif

void DoorThink(pobjtype *pob);
void OpenDoor(Sint16 x, Sint16 y);
void RemoveThink(void);
void BadThink(void);
void BadContact(objtype *ob, objtype *hit);
objtype *FindFreeObj(void);
pobjtype *FindFreePObj(void);
boolean ObjectsCollide(objtype *ob1, objtype *ob2);
void UpdateObonHitbox(void);
void UpdateObjHitbox(objtype *ob);
void AccelerateX(Sint16 amount);
void AccelerateY(Sint16 max, Sint16 amount);
void DoGravity(void);
Sint16 MoveObon(void);
Sint16 ClipMoveObon(void);
void RideObj(objtype *ob, objtype *plat);
void PushObj(objtype *ob, objtype *solid);
boolean RemoveInactive(void);
void NullThink(void);
void PlayerCheckMapBorders(void);
void ScrollScreen(void);
void TurnLightsOn(void);
void TurnLightsOff(void);
void ToggleSwitch(void);
void KeenWalk(void);
void KeenStartJump(void);
void KeenJump(void);
void KeenShoot(void);
void KeenPogoAir(void);
void KeenPogoGround(void);
void KeenExit(void);
void KeenDead(void);
void HurtKeen(void);
void KillKeen(void);
void PlayerCheckTiles(void);
void KeenContact(objtype *ob, objtype *hit);
void SpawnPlayerShot(Sint32 x, Sint32 y);
void ShotSplash(void);
void ShotThink(void);
void ShotContact(objtype *ob, objtype *hit);
void DeadThink(void);
void DyingThink(void);
void SpawnEnemyShot(Sint32 x, Sint32 y, Sint16 xspeed);
void EnemyShotContact(objtype *ob, objtype *hit);
void BorderFlash(pobjtype *pob);
void BridgeCreate(pobjtype *pob);
void BridgeRemove(pobjtype *pob);
exittype LevelLoop(Sint16 currentlevel);

#define NullContact	((objcontact)NullThink)
#define NullPThink	((pobjthink)NullThink)

/*
=============================================================================

			   KEENMENU.C

=============================================================================
*/

extern boolean showIntro;
extern Sint16 storyanim[];

void DemoLoop(void);
Sint16 ErrorHandler(void);
void WorldMap(void);
void ScanWorldMap(void);
void EraseWindow(void);
void TypeText(char *text);
void DoFinale(void);
void WarpToSecretLevel(void);
void CheckHighScore(void);
void ShowLives(void);
void GetPlayerPosition(Sint32 *xglobal, Sint32 *yglobal);
void MenuLoop(void);
boolean MainMenuLoop(Sint16 screen);
void DrawMainMenu(void);
void DrawMainMenuScreen(void);

/*
=============================================================================

			   KEENSCRN.C

=============================================================================
*/

void Previews(void);
void ShowAboutId(void);
void DrawTitlePics(void);
void DrawTitleScreen(void);
void DrawAboutId(void);
void DrawIdScreen(void);
void DrawHighscores(void);
void DrawScoreScreen(void);
void ShowScoreScreen(void);
void SaveMenu(void);
boolean RestoreMenu(void);
void ShowStoryText(void);
void ShowHelpText(void);
void DrawTextEx(boolean useGrey, Sint16 x, Sint16 y, char *text);
void DrawTextWindow(void);
void DrawTextScreen(char huge *textPtr, Sint16 minY, Sint16 maxY);
void ShowText(char huge *textPtr, Sint16 minY, Sint16 maxY);
void DrawApogeePic(void);
void DrawIntroPics(void);
void ShowApogeeIntro(void);
void ShowOrderingScreen(boolean timed);
void DrawOrderingInfo(void);
void DrawOrderingScreen(void);
void PrintGrey(char *text);

/*
=============================================================================

			   WRLDKEEN.C

=============================================================================
*/

boolean ClipMapKeen(objtype *ob);
void ControlMapKeen(ControlStruct ctrl, objtype *ob);
boolean CheckMapKeenTiles(Sint16 num, objtype *ob, Sint16 spotX, Sint16 spotY);
void Ack(void);

/*
=============================================================================

			   TEXTVIEW.C

=============================================================================
*/

void DrawTextLines(Sint16 x, Sint16 y, char huge *textPtr, linetype *lineoffs, Uint16 numlines);
void PrepareText(char huge *textPtr);
Uint16 GetLineOffsets(char huge *textPtr, linetype *lineoffs, Uint16 width, Uint16 maxlines);
void ScrollTextWindow(Sint16 minY, Sint16 maxY, Sint16 dir);

void PlayAnimation(Sint16 *data);

#endif
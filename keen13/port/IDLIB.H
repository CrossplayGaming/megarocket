/* Reconstructed Commander Keen 1-3 Source Code
 * Copyright (C) 2021-2025 K1n9_Duk3
 *
 * The code in this file is primarily based on:
 *  Hovertank 3-D Source Code
 *   Copyright (C) 1993-2014 Flat Rock Software
 *  The Catacomb Source Code
 *   Copyright (C) 1993-2014 Flat Rock Software
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

#include "VERSION.H"

/* Keen Launcher port: exact-width aliases (defined before KEENDEF.H's,
 * guarded so both spellings agree). */
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

#include <stdarg.h>
#include <dos.h>
#include <mem.h>
#include <sys\stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <alloc.h>
#ifdef _MSC_VER
#include <io.h>	/* MSVC only; POSIX equivalents come from k13_compat.h */
#endif
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <conio.h>

#ifdef K13_PORT
/* Turbo C's toupper/tolower were byte-wide: the 16-bit RTL loaded AL and
 * returned AX with AH cleared, so the game can hand them Get()'s packed
 * (scancode<<8)|ascii value directly -- which it does, in every "(Y/N)?"
 * and "(D)os or (T)itle" prompt.  MSVC's versions return anything above
 * 255 unchanged, leaving those prompts stuck on the lowercase ascii and
 * so matching none of their cases.  Restore the DOS semantics. */
#undef toupper
#undef tolower
#define toupper(c) K13_ToUpper(c)
#define tolower(c) K13_ToLower(c)
int K13_ToUpper(int c);
int K13_ToLower(int c);
#endif

#ifndef __jm__
typedef enum {false,true} boolean;
typedef unsigned char byte;
typedef unsigned int word;
#endif

#define TRUE	1
#define FALSE	0


char extern ch,str[80];		// scratch variables

#define SIGN(x) ((x)>0?1:-1)
#define ABS(x) ((int)(x)>0?(x):-(x))
#define LABS(x) ((long)(x)>0?(x):-(x))

// The MK_FP macro breaks when seg is a long int or a far pointer, here's a workaround:
#define MY_FP(seg, ofs) MK_FP((unsigned)(seg), (ofs))

#undef inport
#undef inportb
#undef outport
#undef outportb

/* With the compat macros gone, these resolve to idlib13's real functions;
 * prototypes for compilers that reject implicit declarations. */
void outportb(unsigned port, unsigned char value);
void outport(unsigned port, unsigned value);
unsigned char inportb(unsigned port);

typedef void _seg * memptr;

void extern _seg *egasprites[5];	// spriteptr for each plane
extern char far *maprle;
extern unsigned lzw_maxcode, lzw_tablesize;

/*
============================================================================

** Sound routines
** Ties into INT 8, with a timer tic at 8 * normal rate (144/sec)

============================================================================
*/

typedef enum {off,spkr,adlib} soundtype;

typedef struct {unsigned start;
		byte priority;
		byte samplerate;
		char name[12];} spksndtype;

typedef struct {char id[4];
		unsigned filelength;
		unsigned filler[5];
		spksndtype sounds[63];
		unsigned freqdata[];} SPKRtable;


soundtype extern soundmode;
char extern huge *SoundData;

extern	unsigned timerspeed;
extern	int	dontplay;
extern	unsigned inttime;
extern	long	timecount;

extern	unsigned int8hook;	// address of function to call every tic

extern	memptr	soundseg;
extern	unsigned sndptr;

void StartupSound (void);
void ShutdownSound (void);
void PlaySound (int sound);
void PauseSound (void);
void ContinueSound (void);
void StopSound (void);
void WaitEndSound (void);


/*
============================================================================

** Control routines
** Ties into INT 9 to intercept all key presses, but passes on to BIOS
** The control panel handles all this stuff!

============================================================================
*/

typedef enum BIOSKEY {
	KEY_NULL,
	KEY_ESCAPE = 1,
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_ASSIGN, KEY_BACKSPACE,
	KEY_TAB, KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_LBRACK, KEY_RBRACK, KEY_ENTER,
	KEY_CTRL, KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_COLON, KEY_QUOTE, KEY_TILDE,
	KEY_LSHIFT, KEY_BACKSLASH, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M, KEY_COMMA, KEY_PERIOD, KEY_SLASH, KEY_RSHIFT,
	KEY_NUMMUL, KEY_ALT, KEY_SPACE, KEY_CAPSLK,
	KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_NUMLK, KEY_SCRLK,
	KEY_HOME, KEY_UP, KEY_PGUP, KEY_NUMSUB, KEY_LEFT, KEY_NUM5, KEY_RIGHT, KEY_NUMADD, KEY_END, KEY_DOWN, KEY_PGDN, KEY_INS, KEY_DEL,
	KEY_F11 = 87, KEY_F12,
	KEY_FINALKEY
} BIOSKEY;

#define KEY_RETURN KEY_ENTER
#define KEY_ESC KEY_ESCAPE
#define CHAR_ESCAPE 27
#define CHAR_ENTER 13

typedef enum {north,northeast,east,southeast,south,southwest,west,
	      northwest,nodir} dirtype;

typedef struct {dirtype dir;
		boolean button1,button2;} ControlStruct;

typedef enum {keyboard,mouse,joystick1,joystick2,demo} inputtype;

enum demoenum {notdemo,demoplay,recording};
enum demoenum extern indemo;

inputtype	extern	playermode[3];
int		extern	JoyXlow[3],
			JoyXhigh[3],
			JoyYlow [3],
			JoyYhigh [3];	// 1&2 are used, 0 is just space

char		extern	key[8], keyB1, keyB2;	// scan codes for key control


void ReadJoystick (int joynum,int *xcount,int *ycount);

Sint16 JoyButton (void);
void CalibrateJoy (int joynum);
void Printscan (int sc);
void CalibrateKeys (void);

ControlStruct ControlKBD (void);
ControlStruct ControlMouse (void);
ControlStruct ControlJoystick (int joynum);
ControlStruct ControlPlayer (int player);

#ifdef OLDKEYBOARD
#define NoBiosKey bioskey
boolean		extern	keydown[128];
void extern interrupt (*oldint9) ();

void SetupKBD ();
void interrupt Int9ISR ();
void ShutdownKbd ();
#else
char		extern	keydown[128];
extern int	NBKscan,NBKascii,lastkey;
extern boolean passtobios;
// NOTES:
// - lastkey is actually a 1-byte variable, not a 2-byte int. This doesn't
//   cause any big problems, since the lastkey variable is only used once in
//   the C code. Writing to lastkey overwrites the low byte of NBKscan, but
//   since the only place where lastkey is written to is in ClearKeys, where
//   lastkey, NBKscan and NBKascii are all set to 0, this minor corruption
//   doesn't matter -- all bytes of all three variables get set to 0 anyway.
// - lastkey only exists in version 1.3, passtobios only exists in version 1.31
//   and above. It's okay to have extern declarations for variables that don't
//   actually exist, as long as the variables aren't used anywhere in the code.
//   Wrapping the variables in #if checks would just make this file even harder
//   to read. There are far more extern declarations for variables that don't
//   actually exist in the compiled executable in this file.

void StartupKbd (void);                                         /* ASM */
void ShutdownKbd (void);                                        /* ASM */
int NoBiosKey(int parm);                                        /* ASM */
#endif

/*
===========================================================================

** Miscellaneous library routines

===========================================================================
*/

void extern far *lastparalloc;

void huge *paralloc (long size);
long unsigned int LoadFile(char *filename,char huge *buffer);
void SaveFile(char *filename,char huge *buffer, long size);
void huge *bloadin (char *filename);
void huge *bloadinLZW (char *filename);
long Verify(char *filename);

void RLEWExpand (unsigned far *source, unsigned far *dest);
long RLEWCompress (unsigned far *source, long length, unsigned far *dest);

void RLEExpand (char far *source,char far *dest);
unsigned long RLECompress (char far *source, unsigned long Length, char far *dest);

void InitRnd (boolean randomize);                               /* ASM */
int Rnd (int max);                                              /* ASM */
void InitRndT (boolean randomize);                              /* ASM */
int RndT (void);                                                /* ASM */

void ClearKeys (void);


/*
============================================================================

** Graphic routines
** Edge graphic file not needed
**
** Many of these #defines are duplicates as EQUs in EDGEASM, and must be ==

============================================================================
*/

#define SC_INDEX	0x3C4
#define SC_RESET	0
#define SC_CLOCK	1
#define SC_MAPMASK	2
#define SC_CHARMAP	3
#define SC_MEMMODE	4

#define CRTC_INDEX	0x3D4
#define CRTC_H_TOTAL	0
#define CRTC_H_DISPEND	1
#define CRTC_H_BLANK	2
#define CRTC_H_ENDBLANK	3
#define CRTC_H_RETRACE	4
#define CRTC_H_ENDRETRACE 5
#define CRTC_V_TOTAL	6
#define CRTC_OVERFLOW	7
#define CRTC_ROWSCAN	8
#define CRTC_MAXSCANLINE 9
#define CRTC_CURSORSTART 10
#define CRTC_CURSOREND	11
#define CRTC_STARTHIGH	12
#define CRTC_STARTLOW	13
#define CRTC_CURSORHIGH	14
#define CRTC_CURSORLOW	15
#define CRTC_V_RETRACE	16
#define CRTC_V_ENDRETRACE 17
#define CRTC_V_DISPEND	18
#define CRTC_OFFSET	19
#define CRTC_UNDERLINE	20
#define CRTC_V_BLANK	21
#define CRTC_V_ENDBLANK	22
#define CRTC_MODE	23
#define CRTC_LINECOMPARE 24


#define GC_INDEX	0x3CE
#define GC_SETRESET	0
#define GC_ENABLESETRESET 1
#define GC_COLORCOMPARE	2
#define GC_DATAROTATE	3
#define GC_READMAP	4
#define GC_MODE		5
#define GC_MISCELLANEOUS 6
#define GC_COLORDONTCARE 7
#define GC_BITMASK	8

#define ATR_INDEX	0x3c0
#define ATR_MODE	16
#define ATR_OVERSCAN	17
#define ATR_COLORPLANEENABLE 18
#define ATR_PELPAN	19
#define ATR_COLORSELECT	20

#define SCREENWIDTH	48

#define EGAWRITEMODE(x) asm{cli;mov dx,GC_INDEX;mov ax,GC_MODE+256*x;out dx,ax;sti;}
#define EGABITMASK(x) asm{mov dx,GC_INDEX;mov ax,GC_BITMASK+256*x;out dx,ax;sti;}
#define EGAMAPMASK(x) asm{cli;mov dx,SC_INDEX;mov ax,SC_MAPMASK+x*256;out dx,ax;sti;}

typedef enum {text,CGAgr,EGAgr,VGAgr} grtype;
typedef enum {NOcard,MDAcard,CGAcard,EGAcard,MCGAcard,VGAcard,
	      HGCcard=0x80,HGCPcard,HICcard} cardtype;

cardtype extern videocard;


void WaitVBL (int num);			// waits for no sync, then sync

void EGAplane (int plane);		// read / write from plane 0-4
void EGAlatch (void);			// write mode 1, all planes enabled

cardtype VideoID (void);		// returns the display adapter installed

extern char colors[4][17];
void FadeOut (void);			// EGA 16 color palette fade
void FadeIn (void);

/*=========================================================================*/

/*
** PC-Arcade graphic file format stuff
*/

#define NUMPICS 64
#define NUMSPRITES 10

unsigned extern EGADATASTART;

/* Keen Launcher port: these describe ON-DISK layouts, so they use
 * exact-width types and byte packing; the VERIFY_SIZE checks in
 * KEENDEF.H prove the layout matches the DOS original. */
#pragma pack(push, 1)
typedef struct
{
	Sint32 latchsize;
	Sint32 spritesize;
	Sint32 picinfoStart;
	Sint32 sprinfoStart;
	Uint16 numTile8s;
	Sint32 offTile8s;
	Uint16 field_16;		// never used
	Sint32 field_18;	// never used
#if VERSION >= VER_132
	Uint16 field_1C;		// never used
	Sint32 field_1E;	// never used
#endif
	Uint16 numTile16s;
	Sint32 offTile16s;
	Uint16 numPics;
	Sint32 offPics;
	Sint16 numSprites;
	Sint32 offSprites;
	Uint16 compression;
} grheadtype;

typedef struct
{
	Sint16 width;
	Sint16 height;
	Uint32 shapeptr;		// reletive to spriteptr (file offset)
	Sint16 xl,yl,xh,yh;		// death box pixel offsets
	char name[12];
	Sint16 orgx, orgy;	// never used, could also be 4 extra chars for name
} spritetype;

typedef struct
{
	Sint16 width;
	Sint16 height;
	Uint32 shapeptr;	// file offset
	char name[8];
} pictype;
#pragma pack(pop)


int extern numchars,numtiles,numpics,numsprites;

spritetype extern image, huge *spritetable;	// grfile headers
pictype extern huge *pictable;

void extern huge *charptr;		// 8*8 tileset
void extern huge *tileptr;		// 16*16 tileset
void extern huge *picptr;		// any size picture set

extern unsigned screenseg;		// normally 0xa000
extern unsigned screenofs;		// adjustment for panning and buffers
					// from screenseg for UL corner
extern unsigned screenorigin;		// first byte viable on screen

extern Uint16 EGApage;

//
// base drawing routines, x in bytes, y in lines
//

void DrawChar (int x, int y, int charnum);
void DrawTile (int x, int y, int tilenum);
void DrawPic (int x, int y, int picnum);
void DrawSprite (int xcoord, int ycoord, int spritenum);

extern unsigned tile_anim0[], tile_anim1[], tile_anim2[], tile_anim3[];
extern void (*uservect)(void);

void RF_ForceRefresh(void);
void VidRefresh(void);

int		extern	MouseSensitivity;

/*
============================================================================

** Mid level graphic routines

============================================================================
*/

int extern sx,sy,leftedge, screencenterx ,screencentery, segoffset;
int extern win_xl,win_yl,win_xh,win_yh;

int Get (void);
int Input(char *string,int max);
unsigned InputInt(void);
void Print (const char *str);
void PrintC(char *string);
void PrintHexB(unsigned char value);
void PrintHex(unsigned value);
void PrintBin(unsigned value);
void PrintInt (int val);
void PrintLong (long val);

void DrawWindow (int xl, int yl, int xh, int yh);
void EraseWindow (void);
void CharBar (int xl,int yl, int xh, int yh, int ch);
void CenterWindow (int width, int height);
void ExpWin (int width, int height);
void ExpWinH (int width, int height);
void ExpWinV (int width, int height);
void DrawFrame(int x1,int y1,int x2,int y2,int type);


/*
============================================================================

** Game level routines

============================================================================
*/

int extern level;

/* Keen Launcher port: this overlays the on-disk level header, so it
 * uses exact-width types and byte packing */
#pragma pack(push, 1)
typedef struct { Sint16 width;
		 Sint16 height;
		 Sint16 planes;
		 Sint16 screenx;
		 Sint16 screeny;
		 Sint16 screenw;
		 Sint16 screenh;
		 Uint16 planesize;
	       } LevelDef;
#pragma pack(pop)

char	extern	*_extension;

LevelDef extern	far *levelheader;
Uint16 extern	far *mapplane[4];		// points into map
Sint16	extern	mapbwide,mapwwide,mapwidthextra,mapheight;


//
// get / set a tile value in the map
//
#define SETTILE(x,y,plane,value) *(mapplane[plane]+((y)*mapwwide+(x)))=value
#define GETTILE(x,y,plane) (*(mapplane[plane]+((y)*mapwwide+(x)) ))


void LoadCtrls (void);
void SaveCtrls (void);

void LoadGraphics (void);

/*
============================================================================

** Needed non library routines

============================================================================
*/

void Quit (char *);

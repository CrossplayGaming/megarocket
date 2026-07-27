/* Reconstructed Commander Keen 1-3 Source Code
 * Copyright (C) 2021-2026 K1n9_Duk3
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

#include "IDLIB.H"
#pragma hdrstop

/*
=============================================================================

		  Library, C section

=============================================================================
*/

#define BLANKCHAR	' '

char	ch,str[80];	// scratch space

inputtype playermode[3];

#ifdef OLDKEYBOARD
boolean		keydown[128];
#endif

int JoyXlow [3], JoyXhigh [3], JoyYlow [3], JoyYhigh [3]/*, buttonflip*/;

int MouseSensitivity;

char key[8],keyB1,keyB2;

void interrupt (*oldint9) ()=NULL;	// always present, but only used when OLDKEYBOARD is defined

char	demobuffer[5002];
char	*demoptr;
enum demoenum indemo;

////////////////////
//
// prototypes
//
////////////////////

void CalibrateJoy (int joynum);
void Printscan (int sc);
void calibratekeys (void);

//=========================================================================



////////////////
//
// CalibrateJoy
// Brings up a dialog and has the user calibrate
// either joystick1 or joystick2
//
////////////////

void CalibrateJoy (int joynum)
{
	int joy,zero,x,y;
	int stage,dx,dy,xl,yl,xh,yh;
	ControlStruct ctr;

#if VERSION < VER_100
	ExpWin (25,9);
#else
	ExpWin (28,9);
#endif

	joy = 0;
	zero = 0;	//variable is not used anywhere else
	ReadJoystick(1, &x, &y);
	if (x < 500)
		joy = 1;
	ReadJoystick(2, &x, &y);
	if (x < 500)
		joy = 2;

#if VERSION < VER_100
	Print(" Joystick Configuration\n\r");
	Print(" ----------------------\n\r");
#else
	Print("  Joystick Configuration\n\r");
	Print("  ----------------------\n\r");
#endif
	Print("Hold the joystick in the\n\r");
	Print("upper left\n\r");
#if VERSION < VER_100
	Print("corner and hit fire:");
#else
	Print("corner and press button 1:");
#endif
	stage=9;
	do				// wait for a button press
	{
		DrawChar (sx,sy*8,stage);
		WaitVBL (3);
		if (++stage==12)
			stage=9;
		ReadJoystick (joynum,&xl,&yl);
		ctr = ControlJoystick(joynum);
		if (keydown[1])
			goto done;
	} while (ctr.button1!= 1);
	DrawChar(sx,sy*8,BLANKCHAR);
	do                  		// wait for the button release
	{
		ctr = ControlJoystick(joynum);
	} while (ctr.button1);
	WaitVBL (2);			// so the button can't bounce

	Print("\n\n\rHold the joystick in the\n\r");
	Print("lower right\n\r");
#if VERSION < VER_100
	Print("corner and hit fire:");
#else
	Print("corner and press button 1:");
#endif
	do				// wait for a button press
	{
		DrawChar (sx,sy*8,stage);
		WaitVBL (3);
		if (++stage==12)
			stage=9;
		ReadJoystick (joynum,&xh,&yh);
		ctr = ControlJoystick(joynum);
		if (keydown[1])
			goto done;
	} while (ctr.button1!= 1);
	DrawChar (sx,sy*8,BLANKCHAR);
	do                  		// wait for the button release
	{
		ctr = ControlJoystick(joynum);
	} while (ctr.button1);

	//
	// figure out good boundaries
	//

	dx=(xh-xl) / 4;
	dy=(yh-yl) / 4;
	JoyXlow[joynum]=xl+dx;
	JoyXhigh[joynum]=xh-dx;
	JoyYlow[joynum]=yl+dy;
	JoyYhigh[joynum]=yh-dy;
	playermode[1]=joystick1;

done:
	ClearKeys();
}

/////////////////////////////
//
// print a representation of the scan code key
//
////////////////////////////
void printscan (int sc)
{
 char static chartable[128] =
 {'?','?','1','2','3','4','5','6','7','8','9','0','-','+','?','?',
  'Q','W','E','R','T','Y','U','I','O','P','[',']','|','?','A','S',
  'D','F','G','H','J','K','L',';','"','?','?','?','Z','X','C','V',
  'B','N','M',',','.','/','?','?','?','?','?','?','?','?','?','?',
  '?','?','?','?','?','?','?','?', 15,'?','-', 21,'5', 17,'+','?',
   19,'?','?','?','?','?','?','?','?','?','?','?','?','?','?','?',
  '?','?','?','?','?','?','?','?','?','?','?','?','?','?','?','?',
  '?','?','?','?','?','?','?','?','?','?','?','?','?','?','?','?'};

 sc = sc & 0x7f;

 if (sc==1)
   Print ("ESC");
 else if (sc==0xe)
   Print ("BKSP");
 else if (sc==0xf)
   Print ("TAB");
 else if (sc==0x1d)
   Print ("CTRL");
 else if (sc==0x2A)
   Print ("LSHIFT");
 else if (sc==0x39)
   Print ("SPACE");
 else if (sc==0x3A)
   Print ("CAPSLK");
 else if (sc>=0x3b && sc<=0x44)
 {
   char str[3];
   Print ("F");
   itoa (sc-0x3a,str,10);
   Print (str);
 }
 else if (sc==0x57)
   Print ("F11");
 else if (sc==0x59)
   Print ("F12");
 else if (sc==0x46)
   Print ("SCRLLK");
 else if (sc==0x1c)
   Print ("ENTER");
 else if (sc==0x36)
   Print ("RSHIFT");
 else if (sc==0x37)
   Print ("PRTSC");
 else if (sc==0x38)
   Print ("ALT");
 else if (sc==0x47)
   Print ("HOME");
 else if (sc==0x49)
   Print ("PGUP");
 else if (sc==0x4f)
   Print ("END");
 else if (sc==0x51)
   Print ("PGDN");
 else if (sc==0x52)
   Print ("INS");
 else if (sc==0x53)
   Print ("DEL");
 else if (sc==0x45)
   Print ("NUMLK");
/*
 else if (sc==0x48)
   Print ("UP");
 else if (sc==0x50)
   Print ("DOWN");
 else if (sc==0x4b)
   Print ("LEFT");
 else if (sc==0x4d)
   Print ("RIGHT");
*/
 else
   DrawChar(sx++, sy*8, chartable[sc]);
}

/////////////////////////////
//
// calibratekeys
//
////////////////////////////
void CalibrateKeys (void)
{
  char ch;
  int hx,hy,i,select,new;

  ExpWin (22,14);
  Print ("Keyboard Commands\n");
  Print ("-----------------");
  Print ("\n0 north    :");
  Print ("\n1 northeast:");
  Print ("\n2 east     :");
  Print ("\n3 southeast:");
  Print ("\n4 south    :");
  Print ("\n5 southwest:");
  Print ("\n6 west     :");
  Print ("\n7 northwest:");
  Print ("\n8 button1  :");
  Print ("\n9 button2  :");
  Print ("\nModify which action:");
  hx=sx;
  hy=sy;
  for (i=0;i<8;i++)
  {
    sx=26;
    sy=i+7;
    printscan (key[i]);
  }
  sx=26;
  sy=15;
  printscan (keyB1);
  sx=26;
  sy=16;
  printscan (keyB2);

  do
  {
    sx=hx;
    sy=hy;
    ch=Get() % 256;
    if (ch<'0' || ch>'9')
      continue;
    select = ch - '0';
    DrawChar (sx,sy*8,ch);
    select = ch - '0';
    Print ("\n\rPress the new key:");
    ClearKeys ();
    new=-1;
    while (!keydown[++new])
    {
#ifdef K13_PORT
      /* DOS filled keydown[] from the INT 9 ISR while this spun; our
         equivalent is the event pump, so let it run once per sweep */
      if (new >= 0x79)
        K13_Idle();
#endif
      if (new==0x79)
        new=-1;
      else if (new==0x29)
        new++;				// skip STUPID left shifts!
    }
    ClearKeys();
    Print("\r                  ");
    if (select<8)
      key[select]=new;
    if (select==8)
      keyB1=new;
    if (select==9)
      keyB2=new;
    sy=select+7;
    sx=26;
    Print("        ");
    sx=26;
    printscan (new);
    ch='0';				// so the loop continues
  } while (ch>='0' && ch<='9');
  playermode[1]=keyboard;
}

//=========================================================================

#ifdef OLDKEYBOARD

/*
The older versions of Keen 1-3 (before v1.3) used this keyboard handling code,
the later versions moved the code into the assembly portion and changed it so
that the user can prevent key presses from being passed to the BIOS keyboard
handler by starting the game with "-k" as the first parameter, see KEENMAIN.C.

The C version of this keyboard handling code was taken from PCRLIB_C.C from the
"The Catacomb" source code.
*/

/*
=======================
=
= SetupKBD
= Clears the keydown array and installs the INT 9 ISR if it isn't allready
= hooked up.
=
=======================
*/

void SetupKBD ()
{
 void far *vect = getvect (9);
 int i;

 for (i=0;i<128;i++)			/* clear our key down table */
   keydown[i]= false;

 poke (0x40,0x1c,peek(0x40,0x1a));	/* clear the bios key buffer */

 if ( &Int9ISR != vect ) 		/* is our handler allready set up? */
 {
   oldint9 = vect;
   setvect (9,Int9ISR);
 }
}


/*
=========================
=
= Int9ISR
= Called for every keypress.  Keeps track of which keys are down, and passes
= the key on to DOS after clearing the dos buffer (max 1 char in buffer).
=
=========================
*/

void interrupt Int9ISR ()
{
 int key = inportb (0x60);		/* get the key pressed */

 if (key>127)
   keydown [key-128] = false;		/* break scan code */
 else
 {
   keydown [key] = true;		/* make scan code */
   poke (0x40,0x1c,peek(0x40,0x1a));	/* clear the bios key buffer */
 }
asm {
   push ax
   push	bx
   push	cx
   push	dx
   push	si
   push	di
   push	bp
 }
 oldint9 ();				/* give it to DOS */
asm {
   pop	bp
   pop  di
   pop	si
   pop	dx
   pop	cx
   pop	bx
   pop	ax
 }
 outport (0x20,0x20);			/* tell the int manager we got it */
}



/*
===========================
=
= ShutdownKbd
= Sets the int 9 vector back to oldint 9
=
===========================
*/

void ShutdownKbd ()
{
 if (oldint9 != NULL)
   setvect (9,oldint9);
}

#endif

/*
===========================
=
= ControlKBD
=
===========================
*/

ControlStruct ControlKBD ()
{
#ifdef K13_PORT
 K13_Idle();	/* DOS interrupts updated keydown behind poll loops */
#endif
 int xmove=0,
     ymove=0;
 ControlStruct action;

 if (keydown [key[north]])
  ymove=-1;
 if (keydown [key[east]])
  xmove=1;
 if (keydown [key[south]])
  ymove=1;
 if (keydown [key[west]])
  xmove=-1;

 if (keydown [key[northeast]])
 {
   ymove=-1;
   xmove=1;
 }
 if (keydown [key[northwest]])
 {
   ymove=-1;
   xmove=-1;
 }
 if (keydown [key[southeast]])
 {
   ymove=1;
   xmove=1;
 }
 if (keydown [key[southwest]])
 {
   ymove=1;
   xmove=-1;
 }

  switch (ymove*3+xmove)
 {
   case -4: action.dir = northwest; break;
   case -3: action.dir = north; break;
   case -2: action.dir = northeast; break;
   case -1: action.dir = west; break;
   case  0: action.dir = nodir; break;
   case  1: action.dir = east; break;
   case  2: action.dir = southwest; break;
   case  3: action.dir = south; break;
   case  4: action.dir = southeast; break;
 }

 action.button1 = keydown [keyB1];
 action.button2 = keydown [keyB2];

#ifdef K13_PORT
 { void K13_ControllerBlend(ControlStruct *); K13_ControllerBlend(&action); }
#endif
 return (action);
}


/*
============================
=
= ControlMouse
=
============================
*/

ControlStruct ControlMouse ()
{
 int newx,newy,		/* mickeys the mouse has moved */
     xmove = 0,
     ymove = 0;
 ControlStruct action;

 _AX = 3;
 geninterrupt (0x33);		/* mouse status */
 newx = _CX;
 newy = _DX;
 action.button1 = _BX & 1;
 action.button2 = (_BX & 2) >> 1;

 if ((newx-320)/2>MouseSensitivity)
 {
   xmove = 1;
   newx = newx - MouseSensitivity*2;
 }
 else if ((newx-320)/2<-MouseSensitivity)
 {
   xmove = -1;
   newx = newx + MouseSensitivity*2;
 }
 if ((newy-100)>MouseSensitivity)
 {
   ymove = 1;
   newy = newy - MouseSensitivity;
 }
 else if ((newy-100)<-MouseSensitivity)
 {
   ymove = -1;
   newy = newy + MouseSensitivity;
 }

  _AX = 4;
  _CX=newx;
  _DX=newy;
  geninterrupt (0x33);		/* set mouse status */

 switch (ymove*3+xmove)
 {
   case -4: action.dir = northwest; break;
   case -3: action.dir = north; break;
   case -2: action.dir = northeast; break;
   case -1: action.dir = west; break;
   case  0: action.dir = nodir; break;
   case  1: action.dir = east; break;
   case  2: action.dir = southwest; break;
   case  3: action.dir = south; break;
   case  4: action.dir = southeast; break;
 }

 return (action);
}

/*
===============================
=
= ReadJoystick
= Just return the resistance count of the joystick
=
===============================
*/

#ifndef K13_PORT /* Keen Launcher port: replaced in idlib13.c */
void ReadJoystick (int joynum,int *xcount,int *ycount)
{
 int portval,a1,a2,xbit,ybit;

 if (joynum==1)
 {
  xbit=1;
  ybit=2;
 }
 else
 {
  xbit=4;
  ybit=8;
 }

 *xcount = 0;
 *ycount = 0;

 outportb (0x201,inportb (0x201));	/* start the signal pulse */

 asm cli;

 do
 {
   portval = inportb (0x201);
   a1 = (portval & xbit) != 0;
   a2 = (portval & ybit) != 0;
   *xcount+=a1;
   *ycount+=a2;
 } while ((a1+a2!=0) && (*xcount<500) && (*ycount<500));

 asm sti;
}


#endif /* K13_PORT */

/*
=============================
=
= ControlJoystick (joy# = 1 / 2)
=
=============================
*/

ControlStruct ControlJoystick (int joynum)
{
 int joyx = 0,joyy = 0,		/* resistance in joystick */
     xmove = 0,
     ymove = 0,
     buttons;
 ControlStruct action;

 ReadJoystick (joynum,&joyx,&joyy);
 if ( (joyx>500) | (joyy>500) )
 {
   joyx=JoyXlow [joynum] + 1;	/* no joystick connected, do nothing */
   joyy=JoyYlow [joynum] + 1;
 }

 if (joyx > JoyXhigh [joynum])
   xmove = 1;
 else if (joyx < JoyXlow [joynum])
   xmove = -1;
 if (joyy > JoyYhigh [joynum])
   ymove = 1;
 else if (joyy < JoyYlow [joynum])
   ymove = -1;

 switch (ymove*3+xmove)
 {
   case -4: action.dir = northwest; break;
   case -3: action.dir = north; break;
   case -2: action.dir = northeast; break;
   case -1: action.dir = west; break;
   case  0: action.dir = nodir; break;
   case  1: action.dir = east; break;
   case  2: action.dir = southwest; break;
   case  3: action.dir = south; break;
   case  4: action.dir = southeast; break;
 }

 buttons = inportb (0x201);	/* Get all four button status */
 if (joynum == 1)
 {
   action.button1 = ((buttons & 0x10) == 0);
   action.button2 = ((buttons & 0x20) == 0);
 }
 else
 {
   action.button1 = ((buttons & 0x40) == 0);
   action.button2 = ((buttons & 0x80) == 0);
 }
 return (action);
}


/*
=============================
=
= ControlPlayer
=
= Expects a 1 or a 2
=
=============================
*/

ControlStruct ControlPlayer (int player)
{
 ControlStruct ret;
 int val;

 if (indemo == notdemo || indemo == recording)
 {
   switch (playermode[player])
   {
     case keyboard : ret = ControlKBD (); break;
     case mouse    : ret = ControlMouse (); break;
     case joystick1: ret = ControlJoystick(1); break;
     case joystick2: ret = ControlJoystick(2); break;
   }

   //
   // recording a demo?
   //
   if (indemo == recording)
   {
     val = (ret.dir << 2) | (ret.button2 << 1) | ret.button1;
     *demoptr++=val;
   }


 }

 else

 //
 // get the command from the demo buffer
 //
 {
   val = *demoptr++;

   ret.button1 = val & 1;
   ret.button2 = (val & 2) >> 1;
   ret.dir = (dirtype) ( (val & (4+8+16+32) ) >> 2);
 }

#ifdef K13_PORT
 { /* verification harness taps the control stream here */
   ControlStruct K13_VerifyCtrl(ControlStruct);
   ret = K13_VerifyCtrl(ret);
 }
#endif
 return (ret);
}


////////////////////////
//
// RecordDemo
// Clears the demo buffer and starts capturing events
//
////////////////////////

void RecordDemo (void)
{
  demobuffer[0]=level;
  demoptr = &demobuffer[1];
  indemo = recording;
}


////////////////////////
//
// LoadDemo / SaveDemo
// Loads a demo from disk or
// saves the accumulated demo command string to disk
//
////////////////////////

void LoadDemo (int demonum)
{
  char st2[5];

  strcpy (str,"DEMO");
  itoa (demonum,st2,10);
  strcat (str,st2);
  strcat (str,".");
  strcat (str,_extension);

#ifdef K13_PORT
  /* Keen Launcher port: MK_FP(_DS, &near_obj) is just a far pointer to it */
  LoadFile (str,(char huge *)demobuffer);
#else
  LoadFile (str,MK_FP(_DS,&demobuffer));
#endif
  level=demobuffer[0];
  demoptr = &demobuffer[1];
  indemo = demoplay;
}

void SaveDemo (int demonum)
{
  char st2[5];

  strcpy (str,"DEMO");
  itoa (demonum,st2,10);
  strcat (str,st2);
  strcat (str,".");
  strcat (str,_extension);

#ifdef K13_PORT
  SaveFile (str,(char huge *)demobuffer,(demoptr-&demobuffer[0]));
#else
  SaveFile (str,MK_FP(_DS,&demobuffer),(demoptr-&demobuffer[0]));
#endif
  indemo = notdemo;
}


////////////////////////
//
// StartDemo
//
////////////////////////


#define DRAWCHAR(x,y,n) DrawChar(x,(y)*8,n)

/*
=============================================================================
**
** Miscellaneous library routines
**
=============================================================================
*/


///////////////////////////////
//
// ClearKeys
// Clears out the bios buffer and zeros out the keydown array
//
///////////////////////////////

void ClearKeys (void)
{
  int i;
#ifdef OLDKEYBOARD
  while (bioskey (1))
    bioskey(0);

  for (i=0;i<128;i++)
    keydown [i]=0;
#else
#if VERSION == VER_130
	NBKscan=NBKascii=lastkey=0;
#else
  NBKscan=NBKascii=0;
#endif
  memset (keydown,0,sizeof(keydown));
#endif
}


//==========================================================================

/*
===========================================
=
= Allocate a block aligned on a paragraph
=
===========================================
*/

void far *lastparalloc;	// global variable of the EXACT (not paralign)
				// last block, so it can be freed right

#ifndef K13_PORT /* Keen Launcher port: replaced in idlib13.c */
void huge *paralloc (long size)
{
	void huge *temp;
	word seg,ofs;

/* allocate a block with extra space */
	lastparalloc = (void far*)temp = farmalloc (size+15);
	if (temp == NULL)
	//
	// not enough memory!
	//
	{
#if VERSION <= VER_100
		Quit ("Out of memory!");
#else
		Quit ("Out of memory!  Try unloading your TSRs!");
#endif
	}

	ofs=FP_OFF(temp);
	if (ofs!=0)			/* set offset to 0 and bump segment */
	{
		seg=FP_SEG(temp);
		seg++;
		ofs=0;
		temp=MK_FP (seg,ofs);
	}
	return (void huge *) temp;
}
#endif /* K13_PORT */

//==========================================================================

/*
==============================================
=
= Load a *LARGE* file into a FAR buffer!
= by John Romero (C) 1990 PCRcade
=
==============================================
*/

#ifndef K13_PORT /* Keen Launcher port: replaced in idlib13.c */
unsigned long LoadFile(char *filename,char huge *buffer)
{
 unsigned int handle,flength1=0,flength2=0,buf1,buf2,foff1,foff2;

 buf1=FP_OFF(buffer);
 buf2=FP_SEG(buffer);

asm		mov	WORD PTR foff1,0  	// file offset = 0 (start)
asm		mov	WORD PTR foff2,0

asm		mov	dx,filename
asm		mov	ax,3d00h		// OPEN w/handle (read only)
asm		int	21h
asm		jc	out

asm		mov	handle,ax
asm		mov	bx,ax
asm		xor	cx,cx
asm		xor	dx,dx
asm		mov	ax,4202h
asm		int	21h			// SEEK (find file length)
asm		jc	out

asm		mov	flength1,ax
asm		mov	flength2,dx

asm		mov	cx,flength2
asm		inc	cx			// <- at least once!

L_1:

asm		push	cx

asm		mov	cx,foff2
asm		mov	dx,foff1
asm		mov	ax,4200h
asm		int	21h			// SEEK from start

asm		push	ds
asm		mov	bx,handle
asm		mov	cx,-1
asm		mov	dx,buf1
asm		mov	ax,buf2
asm		mov	ds,ax
asm		mov	ah,3fh			// READ w/handle
asm		int	21h
asm		pop	ds

asm		pop	cx
asm		jc	out
asm		cmp	ax,-1
asm		jne	out

asm		push	cx			// need to read the last byte
asm		push	ds			// into the segment! IMPORTANT!
asm		mov	bx,handle
asm		mov	cx,1
asm		mov	dx,buf1
asm		add	dx,-1
asm		mov	ax,buf2
asm		mov	ds,ax
asm		mov	ah,3fh
asm		int	21h
asm		pop	ds
asm		pop	cx

asm		add	buf2,1000h
asm		inc	WORD PTR foff2
asm		loop	L_1

out:

asm		mov	bx,handle		// CLOSE w/handle
asm		mov	ah,3eh
asm		int	21h

return (flength2*0x10000+flength1);

}

//===========================================================================

#endif /* K13_PORT */

/*
==============================================
=
= Save a *LARGE* file far a FAR buffer!
= by John Romero (C) 1990 PCRcade
=
==============================================
*/

#ifndef K13_PORT /* Keen Launcher port: replaced in idlib13.c */
void SaveFile(char *filename,char huge *buffer, long size)
{
 unsigned int handle,buf1,buf2,foff1,foff2;

 buf1=FP_OFF(buffer);
 buf2=FP_SEG(buffer);

asm		mov	WORD PTR foff1,0  		// file offset = 0 (start)
asm		mov	WORD PTR foff2,0

asm		mov	dx,filename
asm		mov	ax,3c00h		// CREATE w/handle (read only)
asm		xor	cx,cx
asm		int	21h
asm		jc	out

asm		mov	handle,ax
asm		cmp	word ptr size+2,0	// larger than 1 segment?
asm		je	L2

L1:

asm		push	ds
asm		mov	bx,handle
asm		mov	cx,8000h
asm		mov	dx,buf1
asm		mov	ax,buf2
asm		mov	ds,ax
asm		mov	ah,40h			// WRITE w/handle
asm		int	21h
asm		pop	ds

asm		add	buf2,800h		// bump ptr up 1/2 segment
asm		sub	WORD PTR size,8000h		// done yet?
asm		sbb	WORD PTR size+2,0
asm		cmp	WORD PTR size+2,0
asm		ja	L1
asm		cmp	WORD PTR size,8000h
asm		jae	L1

L2:

asm		push	ds
asm		mov	bx,handle
asm		mov	cx,WORD PTR size
asm		mov	dx,buf1
asm		mov	ax,buf2
asm		mov	ds,ax
asm		mov	ah,40h			// WRITE w/handle
asm		int	21h
asm		pop	ds
asm		jmp	out

out:

asm		mov	bx,handle		// CLOSE w/handle
asm		mov	ah,3eh
asm		int	21h

}

//==========================================================================


#endif /* K13_PORT */

/*
====================================
=
= bloadin
= Paraligns just enough space and bloads in the
= specified file, returning a pointer to the start
=
====================================
*/

void huge *bloadin (char *filename)
{
 int handle;
 long length;
 char huge *location;

 if ( (handle = open (filename,O_BINARY)) != -1 )
   {
    length = filelength (handle);
    location = paralloc (length);
    close (handle);
    LoadFile (filename,location);
    return location;
   }
 else
   return NULL;
}


/*==================================================================================*/

/*
============================================================================

			  GRAPHIC ROUTINES

============================================================================
*/

/*
** Graphic routines
*/

cardtype videocard;

void huge *charptr;		// 8*8 tileset
void huge *tileptr;		// 16*16 tileset
void huge *picptr;		// any size picture set
//void huge *spriteptr;		// any size masked and hit rect sprites

/*
========================
=
= egasplitscreen
=
========================
*/

void EGASplitScreen (int linenum)
{
  WaitVBL (1);
  if (videocard==VGAcard)
    linenum*=2;
  outportb (CRTC_INDEX,CRTC_LINECOMPARE);
  outportb (CRTC_INDEX+1,linenum % 256);
  outportb (CRTC_INDEX,CRTC_OVERFLOW);
  outportb (CRTC_INDEX+1, 1+16*(linenum/256));
  if (videocard==VGAcard)
  {
    outportb (CRTC_INDEX,CRTC_MAXSCANLINE);
    outportb (CRTC_INDEX+1,inportb(CRTC_INDEX+1) & (255-64));
  }
}


/*
========================
=
= crtcstart
=
========================
*/

void CRTCstart (unsigned start)
{
  WaitVBL (1);
  outportb (CRTC_INDEX,CRTC_STARTLOW);
  outportb (CRTC_INDEX+1,start & 0xFF);
  outportb (CRTC_INDEX,CRTC_STARTHIGH);
  outportb (CRTC_INDEX+1,(start >> 8));
}



/*
============================================================================

			MID LEVEL GRAPHIC ROUTINES

============================================================================
*/


int win_xl,win_yl,win_xh,win_yh;

int sx,sy,leftedge;

int screencenterx = 19,screencentery = 11;


//////////////////////////
//
// DrawWindow
// draws a bordered window and homes the cursor
//
//////////////////////////

void DrawWindow (int xl, int yl, int xh, int yh)
{
 int x,y;
 win_xl=xl;
 win_yl=yl;
 win_xh=xh;
 win_yh=yh;		// so the window can be erased
#ifdef K13_PORT
 /* AFTER win_* are set, so the port captures THIS window's rectangle */
 { void K13_DialogOpened(void); K13_DialogOpened(); }
#endif

 DRAWCHAR (xl,yl,1);
 for (x=xl+1;x<xh;x++)
   DRAWCHAR (x,yl,2);
 DRAWCHAR (xh,yl,3);
 for (y=yl+1;y<yh;y++)
 {
   DRAWCHAR (xl,y,4);
   for (x=xl+1;x<xh;x++)
     DRAWCHAR (x,y,BLANKCHAR);
   DRAWCHAR (xh,y,5);
 }
 DRAWCHAR (xl,yh,6);
 for (x=xl+1;x<xh;x++)
   DRAWCHAR (x,yh,7);
 DRAWCHAR (xh,yh,8);

 sx = leftedge = xl+1;
 sy = yl+1;
}


/////////////////////////////
//
// CenterWindow
// Centers a DrawWindow of the given size
//
/////////////////////////////

void CenterWindow (int width, int height)
{
  int xl = screencenterx-width/2;
  int yl = screencentery-height/2;

  DrawWindow (xl,yl,xl+width+1,yl+height+1);
}


/////////////////////
//
// CharBar
//
/////////////////////
void CharBar (int xl, int yl, int xh, int yh, int ch)
{
  int x,y;

  for (y=yl;y<=yh;y++)
    for (x=xl;x<=xh;x++)
      DRAWCHAR (x,y,ch);
}



///////////////////////////////
//
// ExpWin {h / v}
// Grows the window outward
//
///////////////////////////////
void ExpWin (int width, int height)
{

  if (width > 2)
  {
    if (height >2)
      ExpWin (width-2,height-2);
    else
      ExpWinH (width-2,height);
  }
  else
    if (height >2)
      ExpWinV (width,height-2);

  WaitVBL (1);
  CenterWindow (width,height);
}

void ExpWinH (int width, int height)
{
  if (width > 2)
    ExpWinH (width-2,height);

  WaitVBL (1);
  CenterWindow (width,height);
}

void ExpWinV (int width, int height)
{
  if (height >2)
    ExpWinV (width,height-2);

  WaitVBL (1);
  CenterWindow (width,height);
}


//////////////////////////////////////////////////
//
// Draw Frame 0/1 (for flashing)
//
//////////////////////////////////////////////////
void DrawFrame(int x1,int y1,int x2,int y2,int type)
{
 int loop;

 type=type*22+1;

 for (loop=x1+1;loop<x2;loop++)
   {
    DRAWCHAR(loop,y1,type+1);
    DRAWCHAR(loop,y2,type+6);
   }
 for (loop=y1+1;loop<y2;loop++)
   {
    DRAWCHAR(x1,loop,type+3);
    DRAWCHAR(x2,loop,type+4);
   }

 DRAWCHAR(x1,y1,type);
 DRAWCHAR(x2,y1,type+2);
 DRAWCHAR(x2,y2,type+7);
 DRAWCHAR(x1,y2,type+5);
}


/////////////////////////
//
// Get
// Flash a cursor at sx,sy and waits for a user NoBiosKey
//
/////////////////////////

int Get (void)
{
 int cycle,key;

#ifdef OLDKEYBOARD

#define CHECKKEY() bioskey(1)
#define GETKEY() bioskey(0)

#else

#if VERSION == VER_130
#define CHECKKEY() NoBiosKey(1)
#else
#define CHECKKEY() (NoBiosKey(1) & 0xFF)
#endif
#define GETKEY() NoBiosKey(0)

#endif

 do
 {
   cycle = 9;
   while (!(key = CHECKKEY()) && cycle<13)
   {
     DRAWCHAR (sx,sy,cycle++);
     WaitVBL (5);
   }
 } while (key == 0);
 DRAWCHAR (sx,sy,' ');
 return GETKEY();		// take it out of the buffer
}

/*
===========================================================================

		 CHARACTER BASED PRINTING ROUTINES

===========================================================================
*/


/////////////////////////
//
// Print
// Prints a string at sx,sy.  No clipping!!!
//
/////////////////////////

void Print (const char *str)
{
  unsigned char ch;

  while ((ch=*str++) != 0)
    if (ch == '\n')
    {
      sy++;
      sx=leftedge;
    }
    else if (ch == '\r')
      sx=leftedge;
    else
      DRAWCHAR (sx++,sy,ch);
}


///////////////////////////
//
// PrintInt / PrintLong
// Converts the value to a string and Prints it
//
///////////////////////////

void PrintInt (int val)
{
  itoa(val,str,10);
  Print (str);
}

void PrintLong (long val)
{
  ltoa(val,str,10);
  Print (str);
}


////////////////////////////////////////////////////////////////////
//
// Verify a file's existence
//
////////////////////////////////////////////////////////////////////
long Verify(char *filename)
{
 int handle;
 long size;

 if ((handle=open(filename,O_BINARY))==-1) return 0;
 size=filelength(handle);
 close(handle);
 return size;
}


////////////////////////////////////////////////////////////////////
//
// Print hex byte
//
////////////////////////////////////////////////////////////////////
void PrintHexB(unsigned char value)
{
 int loop;
 char hexstr[16]="0123456789ABCDEF",str[2]="";

 for (loop=0;loop<2;loop++)
   {
    str[0]=hexstr[(value>>(1-loop)*4)&15];
    Print(str);
   }
}




////////////////////////////////////////////////////////////////////
//
// Print hex
//
////////////////////////////////////////////////////////////////////
void PrintHex(unsigned value)
{
 Print("$");
 PrintHexB(value>>8);
 PrintHexB(value&0xff);
}




////////////////////////////////////////////////////////////////////
//
// Print bin
//
////////////////////////////////////////////////////////////////////
void PrintBin(unsigned value)
{
 int loop;

 Print("%");
 for (loop=0;loop<16;loop++)
    if ((value>>15-loop)&1) Print("1"); else Print("0");
}




////////////////////////////////////////////////////////////////////
//
// center Print
//
////////////////////////////////////////////////////////////////////
void PrintC(char *string)
{
 sx=1+screencenterx-(strlen(string)/2);
 Print(string);
}




////////////////////////////////////////////////////////////////////
//
// Input unsigned
//
////////////////////////////////////////////////////////////////////
unsigned InputInt(void)
{
 char string[18]="",digit,hexstr[16]="0123456789ABCDEF";
 unsigned value,loop,loop1;

 Input(string,17);
 if (string[0]=='$')
   {
    int digits;

    digits=strlen(string)-2;
    if (digits<0) return 0;

    for (value=0,loop1=0;loop1<=digits;loop1++)
      {
       digit=toupper(string[loop1+1]);
       for (loop=0;loop<16;loop++)
       if (digit==hexstr[loop])
	    {
	     value|=(loop<<(digits-loop1)*4);
	     break;
	    }
      }
   }
 else if (string[0]=='%')
   {
    int digits;

    digits=strlen(string)-2;
    if (digits<0) return 0;

    for (value=0,loop1=0;loop1<=digits;loop1++)
      {
       if (string[loop1+1]<'0' || string[loop1+1]>'1') return 0;
       value|=(string[loop1+1]-'0')<<(digits-loop1);
      }
   }
 else value=atoi(string);
 return value;
}




////////////////////////////////////////////////////////////////////
//
// line Input routine
//
////////////////////////////////////////////////////////////////////
int Input(char *string,int max)
{
	char key;
	int count=0,loop;

	do {
		key=toupper(Get()&0xff);
		if ((key==127 || key==8)&&count>0)
		{
			count--;
			DRAWCHAR(sx,sy,BLANKCHAR);
			sx--;
		}

		if (key>=' ' && key<='z' && count<max)
		{
			*(string+count++)=key;
			DRAWCHAR(sx++,sy,key);
		}

	} while (key!=27 && key!=13);

	for (loop=count;loop<max;loop++) *(string+loop)=0;

	if (key==13) return 1;
	return 0;
}

/*
===========================================================================

			     GAME ROUTINES

===========================================================================
*/

long score/*,highscore*/;
int level/*,bestlevel*/;

#ifdef K13_PORT
/* Keen Launcher port: main() strcpy's the episode extension over this;
 * DOS string literals were writable, modern .rdata is not */
static char _extension_storage[16] = "PCR";
char *_extension = _extension_storage;
#else
char *_extension = "PCR";
#endif

char far *maprle;

//LevelDef far *levelheader;
//unsigned far *mapplane[4];		// points into map
//int	mapbwide,mapwwide,mapwidthextra,mapheight;


////////////////////////
//
// loadctrls
// Tries to load the control panel settings
// creates a default if not present
//
////////////////////////

void LoadCtrls (void)
{
  int handle;

  strcpy (str,"CTLPANEL.");
  strcat (str,_extension);
  if ((handle = open(str, O_RDONLY | O_BINARY, S_IWRITE | S_IREAD)) == -1)
  //
  // set up default control panel settings
  //
  {
    soundmode=spkr;
    playermode[1] = keyboard;
    playermode[2] = joystick1;

    JoyXlow [1] = JoyXlow [2] = 20;
    JoyXhigh[1] = JoyXhigh[2] = 60;
    JoyYlow [1] = JoyYlow [2] = 20;
    JoyYhigh[1] = JoyYhigh[2] = 60;
    MouseSensitivity = 5;

    key[0] = 0x48;
    key[1] = 0x49;
    key[2] = 0x4d;
    key[3] = 0x51;
    key[4] = 0x50;
    key[5] = 0x4f;
    key[6] = 0x4b;
    key[7] = 0x47;
    keyB1 = 0x1d;
    keyB2 = 0x38;
  }
  else
  {
#ifdef K13_PORT
    /* Keen Launcher port: CTLPANEL fields are 16-bit DOS ints/enums */
    {
      Sint16 v; int i;
      read(handle, &v, 2); soundmode = (soundtype)v;
      for (i = 0; i < 3; i++) { read(handle, &v, 2); playermode[i] = (inputtype)v; }
      for (i = 0; i < 3; i++) { read(handle, &v, 2); JoyXlow[i] = v; }
      for (i = 0; i < 3; i++) { read(handle, &v, 2); JoyYlow[i] = v; }
      for (i = 0; i < 3; i++) { read(handle, &v, 2); JoyXhigh[i] = v; }
      for (i = 0; i < 3; i++) { read(handle, &v, 2); JoyYhigh[i] = v; }
      read(handle, &v, 2); MouseSensitivity = v;
      read(handle, &key, sizeof(key));
      read(handle, &keyB1, sizeof(keyB1));
      read(handle, &keyB2, sizeof(keyB2));
    }
#else
    read(handle, &soundmode, sizeof(soundmode));
    read(handle, &playermode, sizeof(playermode));
    read(handle, &JoyXlow, sizeof(JoyXlow));
    read(handle, &JoyYlow, sizeof(JoyYlow));
    read(handle, &JoyXhigh, sizeof(JoyXhigh));
    read(handle, &JoyYhigh, sizeof(JoyYhigh));
    read(handle, &MouseSensitivity, sizeof(MouseSensitivity));
    read(handle, &key, sizeof(key));
    read(handle, &keyB1, sizeof(keyB1));
    read(handle, &keyB2, sizeof(keyB2));
#endif

    close(handle);
  }
}

void SaveCtrls (void)
{
  int handle;

  strcpy (str,"CTLPANEL.");
  strcat (str,_extension);

  if ((handle = open(str, O_WRONLY | O_BINARY | O_CREAT | O_TRUNC, S_IREAD | S_IWRITE)) == -1)
    return;

#ifdef K13_PORT
  /* Keen Launcher port: keep the 16-bit DOS file layout */
  {
    Sint16 v; int i;
    v = (Sint16)soundmode; write(handle, &v, 2);
    for (i = 0; i < 3; i++) { v = (Sint16)playermode[i]; write(handle, &v, 2); }
    for (i = 0; i < 3; i++) { v = (Sint16)JoyXlow[i]; write(handle, &v, 2); }
    for (i = 0; i < 3; i++) { v = (Sint16)JoyYlow[i]; write(handle, &v, 2); }
    for (i = 0; i < 3; i++) { v = (Sint16)JoyXhigh[i]; write(handle, &v, 2); }
    for (i = 0; i < 3; i++) { v = (Sint16)JoyYhigh[i]; write(handle, &v, 2); }
    v = (Sint16)MouseSensitivity; write(handle, &v, 2);
    write(handle, &key, sizeof(key));
    write(handle, &keyB1, sizeof(keyB1));
    write(handle, &keyB2, sizeof(keyB2));
  }
#else
  write(handle, &soundmode, sizeof(soundmode));
  write(handle, &playermode, sizeof(playermode));
  write(handle, &JoyXlow, sizeof(JoyXlow));
  write(handle, &JoyYlow, sizeof(JoyYlow));
  write(handle, &JoyXhigh, sizeof(JoyXhigh));
  write(handle, &JoyYhigh, sizeof(JoyYhigh));
  write(handle, &MouseSensitivity, sizeof(MouseSensitivity));
  write(handle, &key, sizeof(key));
  write(handle, &keyB1, sizeof(keyB1));
  write(handle, &keyB2, sizeof(keyB2));
#endif

  close(handle);
}


/*
============================================================================

	    LZW COMPRESSION routines

============================================================================
*/

#ifdef USE_LZW

#define LZW_STACKSIZE 4002

unsigned long lzw_bitbuffer;
int lzw_codelen, lzw_maxcodelen, lzw_bitsavail, lzw_extrabits;
unsigned lzw_maxcode, lzw_tablesize;
char huge *lzw_dest;
char huge *lzw_compbuf;
unsigned char lzw_stack[LZW_STACKSIZE];
unsigned huge *lzw_codes;
unsigned char huge *lzw_values;

unsigned LZW_ReadCode(void);
unsigned char * LZW_ExpandCode(unsigned char *stackptr, unsigned code);
void LZW_Decompress(void);

void huge * bloadinLZW(char *filename)
{
	int handle;
	long length, complength;
	char huge *dest;
	char huge *buffer;

	length = 0;
	complength = 0;

	handle = open(filename, O_BINARY);	// BUG? result isn't checked!
	read(handle, &length, sizeof(length));
#ifdef K13_PORT
	/* Keen Launcher port: the file field is a 16-bit DOS int */
	{ Sint16 mcl16 = 0; read(handle, &mcl16, 2); lzw_maxcodelen = mcl16; }
#else
	read(handle, &lzw_maxcodelen, sizeof(lzw_maxcodelen));
#endif
	close(handle);	// BUG? why close and then re-open the file?

	dest = lzw_dest = paralloc(length);	// this quits if allocation failed

	handle = open(filename, O_BINARY);	// BUG? result isn't checked!
	complength = filelength(handle);
	close(handle);

	buffer = lzw_compbuf = farmalloc(complength);
#if VERSION > VER_100
	if (lzw_compbuf == NULL)
		Quit("Out of memory!  Try unloading your TSRs!");
#endif

	LoadFile(filename, lzw_compbuf);

	lzw_extrabits = lzw_maxcodelen - 8;
	switch (lzw_maxcodelen)
	{
	case 14:
		lzw_tablesize = 18041;
		break;
	case 13:
		lzw_tablesize = 9029;
		break;
	case 12:
		lzw_tablesize = 5021;
		break;
	}
	lzw_codelen = 9;
	lzw_maxcode = (1 << lzw_codelen)-1;
	lzw_codes = farmalloc(lzw_tablesize*sizeof(unsigned));
#if VERSION > VER_100
	if (lzw_codes == NULL)
		Quit("Out of memory!  Try unloading your TSRs!");
#endif
	lzw_values = farmalloc(lzw_tablesize);
#if VERSION > VER_100
	if (lzw_values == NULL)
		Quit("Out of memory!  Try unloading your TSRs!");
#endif
	lzw_bitsavail = 0;
	lzw_bitbuffer = 0;

	LZW_Decompress();

	farfree((void far *)lzw_codes);
	farfree((void far *)lzw_values);
	farfree((void far *)buffer);

	return dest;
}

#define RESETCODE	0x100
#define STOPCODE	0x101
#define STARTCODE	0x102

void LZW_Decompress(void)
{
	unsigned char *ptr;
	unsigned code, nextcode, prevcode, prevval;
	boolean fresh;

	nextcode = STARTCODE;
	fresh = true;
	lzw_compbuf += 6;	// skip expanded length and max code length

	while ((code = LZW_ReadCode()) != STOPCODE)
	{
		if (fresh)
		{
			fresh = false;
			prevval = prevcode = code;
			*lzw_dest++ = prevcode;
		}
		else if (code == RESETCODE)
		{
			fresh = true;
			lzw_codelen = 9;
			nextcode = STARTCODE;
			lzw_maxcode = (1 << lzw_codelen)-1;
		}
		else
		{
			if (code >= nextcode)
			{
				lzw_stack[0] = prevval;
				ptr = LZW_ExpandCode(&lzw_stack[1], prevcode);
			}
			else
			{
				ptr = LZW_ExpandCode(&lzw_stack[0], code);
			}
			prevval = *ptr;
			while (ptr >= lzw_stack)
				*lzw_dest++ = *ptr--;

			if (nextcode <= lzw_maxcode)
			{
				lzw_codes[nextcode] = prevcode;
				lzw_values[nextcode] = prevval;
				nextcode++;

				if (nextcode == lzw_maxcode && lzw_codelen < lzw_maxcodelen)
				{
					//lzw_codelen++;
					lzw_maxcode = (1 << ++lzw_codelen)-1;
				}
			}
			prevcode = code;
		}
	}
}

unsigned char * LZW_ExpandCode(unsigned char *stackptr, unsigned code)
{
	int count = 0;

	while (code > 0xFF)
	{
		*stackptr++ = lzw_values[code];
		code = lzw_codes[code];
		if (count++ >= LZW_STACKSIZE-2)	// -2 because we add another code at the end and we might have started at index 1
		{
			// this is mostly safe for Keen 1-3, but using Quit() would be better
			printf("Error during code expansion!\n");
			exit(1);
		}
	}
	*stackptr = code;

	return stackptr;
}

unsigned LZW_ReadCode(void)
{
	unsigned code;
	int val;

	// fill the bit buffer:
	while (lzw_bitsavail <= 24)
	{
		val = *lzw_compbuf & 0xFF;
		lzw_compbuf++;

		lzw_bitbuffer |= (unsigned long)val << (24-lzw_bitsavail);
		lzw_bitsavail += 8;
	}

	// get the code from the bit buffer (bitbuffer must be unsigned!):
	code = lzw_bitbuffer >> (32-lzw_codelen);

	// shift the used bits out of the bit buffer:
	lzw_bitbuffer <<= lzw_codelen;
	lzw_bitsavail -= lzw_codelen;

	return code;
}

#endif

////////////////////////////////////////////////////////////////////
//
// Fade EGA screen in
//
////////////////////////////////////////////////////////////////////
 char colors[4][17]=
{{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3},
 {0,0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,3},
 {0,0,0,0,0,0,0,0,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,3},
 {0,1,2,3,4,5,6,7,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,3}};


#ifndef K13_PORT /* Keen Launcher port: replaced in idlib13.c */
void FadeIn(void)
{
	WaitVBL(1);
	_ES=FP_SEG(&colors[0]);
	_DX=FP_OFF(&colors[0]);
	_AX=0x1002;
	geninterrupt(0x10);
	WaitVBL(8);
	_ES=FP_SEG(&colors[1]);
	_DX=FP_OFF(&colors[1]);
	_AX=0x1002;
	geninterrupt(0x10);
	WaitVBL(8);
	/*
	_ES=FP_SEG(&colors[2]);
	_DX=FP_OFF(&colors[2]);
	_AX=0x1002;
	geninterrupt(0x10);
	WaitVBL(8);
	*/
	_ES=FP_SEG(&colors[3]);
	_DX=FP_OFF(&colors[3]);
	_AX=0x1002;
	geninterrupt(0x10);
}

////////////////////////////////////////////////////////////////////
//
// Fade EGA screen out
//
////////////////////////////////////////////////////////////////////
#endif /* K13_PORT */
#ifndef K13_PORT /* Keen Launcher port: replaced in idlib13.c */
void FadeOut(void)
{
	WaitVBL(1);
	_ES=FP_SEG(&colors[3]);
	_DX=FP_OFF(&colors[3]);
	_AX=0x1002;
	geninterrupt(0x10);
	WaitVBL(8);
	_ES=FP_SEG(&colors[2]);
	_DX=FP_OFF(&colors[2]);
	_AX=0x1002;
	geninterrupt(0x10);
	WaitVBL(8);
	_ES=FP_SEG(&colors[1]);
	_DX=FP_OFF(&colors[1]);
	_AX=0x1002;
	geninterrupt(0x10);
	WaitVBL(8);
	_ES=FP_SEG(&colors[0]);
	_DX=FP_OFF(&colors[0]);
	_AX=0x1002;
	geninterrupt(0x10);
}

#endif /* K13_PORT */

////////////////////////////////////////////////////////////////////
//
// LoadGraphics
//
////////////////////////////////////////////////////////////////////

char far *spriteSourceOffset;
char far *spriteDestOffset;

spritetype image, huge *spritetable;
pictype huge *pictable;

int numchars,numtiles,numpics,numsprites;

void huge *charptr;
void huge *tileptr;
void huge *picptr;
void _seg *egasprites[5];	// spriteptr for each plane

#if VERSION >= VER_134
long latchsize;
#endif

#ifndef K13_PORT /* Keen Launcher port: replaced in idlib13.c */
void LoadGraphics(void)
{
	long spriteplanesize;
	int i, plane, p;
	boolean compression;
	unsigned size, srcseg, srcoff, dstseg, dstoff, width, height;
	char extrabits;
	grheadtype far *grhead;
	void huge *spritebuffer;
	void huge *latchbuffer;
	void far *spritebufferstart;
	void far *latchbufferstart;
	unsigned bufseg;
	char filename[13] = "?GAPICS.";
	char far *planesrc[5];
	char far *planedst[5];

	strcpy(filename, "EGAHEAD.");
	strcat(filename, _extension);

	grhead = (grheadtype far*)bloadin(filename);
	compression = grhead->compression;
	numchars = grhead->numTile8s;
	numtiles = grhead->numTile16s;
	numpics = grhead->numPics;
	numsprites = grhead->numSprites;
	spritetable = MY_FP(FP_SEG(grhead) + grhead->sprinfoStart/16, FP_OFF(grhead));

	spriteplanesize = 0;
	for (i = 0; i < grhead->numSprites*4; i++)
	{
		spriteplanesize += spritetable[i].width * spritetable[i].height;
	}
	for (i = 0; i < 5; i++)
	{
		egasprites[i] = (void _seg *)paralloc(spriteplanesize);
	}

	strcpy(filename, "EGALATCH.");
	strcat(filename, _extension);

#ifdef USE_LZW
	if (compression)
		latchbuffer = bloadinLZW(filename);
	else
#endif
		latchbuffer = bloadin(filename);
	latchbufferstart = lastparalloc;

	// start graphics mode:
	_AX = 0xD;
	geninterrupt(0x10);

	screenseg = 0xA000;
#if VERSION >= VER_100
	for (i = 0; i < 4; i++)
	{
		EGAplane(i);
		pokeb(screenseg, 0x2000, 0);
	}
#endif

	// set virtual screen width:
	outportb(CRTC_INDEX, CRTC_OFFSET);
	outportb(CRTC_INDEX+1, SCREENWIDTH/2);

	// set read/write mode 0:
	outport(GC_INDEX, GC_MODE);
	
#if VERSION >= VER_134
	latchsize = grhead->latchsize;
#define LATCHSIZE latchsize
#else
#define LATCHSIZE (grhead->latchsize)
#endif

	// move EGALATCH data into EGA memory:
	for (i = 0; i < 4; i++)
	{
		bufseg = FP_SEG(latchbuffer) + (LATCHSIZE*i)/16;
		outport(SC_INDEX, SC_MAPMASK | ((1 << i) << 8));	// write to EGA plane i
		movedata(bufseg, 0, 0xA700, 0, LATCHSIZE);
	}

	charptr = MY_FP(grhead->offTile8s/16 + 0xA700, 0);
	tileptr = MY_FP(grhead->offTile16s/16 + 0xA700, 0);
	picptr = MY_FP(grhead->offPics/16 + 0xA700, 0);
	pictable = MY_FP(FP_SEG(grhead) + grhead->picinfoStart/16, FP_OFF(grhead));

	// latch buffer is no longer needed:
	farfree(latchbufferstart);

	// set border color to (dark) cyan:
	_AH = 0x10;
	_AL = 1;
	_BH = 3;
	geninterrupt(0x10);

	// display the "ONE MOMENT" pic while we're loading the remaining graphics:
	DrawPic(15, 76, ONEMOMENPIC);
	outport(GC_INDEX, GC_MODE);

	strcpy(filename, "EGASPRIT.");
	strcat(filename, _extension);

#ifdef USE_LZW
	if (compression)
		spritebuffer = bloadinLZW(filename);
	else
#endif
		spritebuffer = bloadin(filename);
	spritebufferstart = lastparalloc;

	spriteDestOffset = spriteSourceOffset = 0;
	for (i = 0; i < numsprites; i++)
	{
		size = spritetable[i*4].width * spritetable[i*4].height;
		spriteSourceOffset = spritetable[i*4].shapeptr;
		spritetable[i*4].shapeptr = spriteDestOffset;

		//
		// copy the unshifted sprite data:
		//
		for (plane = 0; plane < 5; plane++)
		{
			planesrc[plane] = MY_FP(FP_SEG(spriteSourceOffset)+FP_SEG(spritebuffer)+(grhead->spritesize*plane)/16, FP_OFF(spriteSourceOffset));
			planedst[plane] = MY_FP(FP_SEG(spriteDestOffset)+FP_SEG(egasprites[plane]), FP_OFF(spriteDestOffset));

			movedata(FP_SEG(planesrc[plane]), FP_OFF(planesrc[plane]), FP_SEG(planedst[plane]), FP_OFF(planedst[plane]), size);
		}
		spriteDestOffset = MY_FP(FP_SEG(spriteDestOffset), FP_OFF(spriteDestOffset) + size);

		//
		// create 1st shifted copy of the sprite:
		//
		size = (spritetable+i*4)[1].width * (spritetable+i*4)[1].height;
		(spritetable+i*4)[1].shapeptr = spriteDestOffset;
		for (p = 0; p < 5; p++)
		{
			planedst[p] = MY_FP(FP_SEG((void far*)spriteDestOffset)+FP_SEG(egasprites[p]), FP_OFF(spriteDestOffset));

			dstoff = FP_OFF(planedst[p]);
			dstseg = FP_SEG(planedst[p]);
			srcoff = FP_OFF(planesrc[p]);
			srcseg = FP_SEG(planesrc[p]);
			width  = spritetable[i*4].width;
			height = spritetable[i*4].height;
			extrabits = (p == 4) * 0xFF;

			// create a copy of the image shifted 2 pixels to the right:
			asm {
				push	si;
				push	di;
				push	ds;
				mov	di, dstoff;
				mov	si, srcoff;
				mov	bx, width;
				mov	dx, height;
				mov	ax, dstseg;
				mov	es, ax;
				mov	ax, srcseg;
				mov	ds, ax;
				cld;
			}
shift1loop:
			asm {
				// copy the pixel data:
				mov	cx, bx;
				rep movsb;
				mov	al, extrabits;
				stosb;

				// shift pixel data one bit/pixel to the right:
				sub	di, bx;
				dec	di;
				mov	cx, bx;
				inc	cx;
				mov	al, extrabits;
				rcr	al, 1;
			}
shift1step1:
			asm{
				mov	al, es:[di];
				rcr	al, 1;
				mov	es:[di], al;
				inc	di;
				loop	shift1step1;

				// shift pixel data another pixel to the right:
				sub	di, bx;
				dec	di;
				mov	cx, bx;
				inc	cx;
				mov	al, extrabits;
				rcr	al, 1;
			}
shift1step2:
			asm{
				mov	al, es:[di];
				rcr	al, 1;
				mov	es:[di], al;
				inc	di;
				loop	shift1step2;
				dec	dx;
				jnz	shift1loop;
				pop	ds;
				pop	di;
				pop	si;
			}

			planesrc[p] = planedst[p];	// next shift copies the shifted data we just created
		}
		spriteDestOffset = MY_FP(FP_SEG(spriteDestOffset), FP_OFF(spriteDestOffset) + size);

		//
		// create 2nd shifted copy of the sprite:
		//
		size = (spritetable+i*4)[2].width * (spritetable+i*4)[2].height;
		(spritetable+i*4)[2].shapeptr = spriteDestOffset;
		for (p = 0; p < 5; p++)
		{
			planedst[p] = MY_FP(FP_SEG((void far*)spriteDestOffset)+FP_SEG(egasprites[p]), FP_OFF(spriteDestOffset));

			dstoff = FP_OFF(planedst[p]);
			dstseg = FP_SEG(planedst[p]);
			srcoff = FP_OFF(planesrc[p]);
			srcseg = FP_SEG(planesrc[p]);
			width  = (spritetable+i*4)[2].width;
			height = (spritetable+i*4)[2].height;
			extrabits = (p == 4) * 0xFF;

			// create a copy of the image shifted 2 pixels to the right:
			asm {
				push	si;
				push	di;
				push	ds;
				mov	di, dstoff;
				mov	si, srcoff;
				mov	bx, width;
				mov	dx, height;
				mov	ax, dstseg;
				mov	es, ax;
				mov	ax, srcseg;
				mov	ds, ax;
				cld;
			}
shift2loop:
			asm {
				// copy the pixel data:
				mov	cx, bx;
				rep movsb;

				// shift pixel data one bit/pixel to the right:
				sub	di, bx;
				mov	cx, bx;
				mov	al, extrabits;
				rcr	al, 1;
			}
shift2step1:
			asm{
				mov	al, es:[di];
				rcr	al, 1;
				mov	es:[di], al;
				inc	di;
				loop	shift2step1;

				// shift pixel data another pixel to the right:
				sub	di, bx;
				mov	cx, bx;
				mov	al, extrabits;
				rcr	al, 1;
			}
shift2step2:
			asm{
				mov	al, es:[di];
				rcr	al, 1;
				mov	es:[di], al;
				inc	di;
				loop	shift2step2;
				dec	dx;
				jnz	shift2loop;
				pop	ds;
				pop	di;
				pop	si;
			}

			planesrc[p] = planedst[p];	// next shift copies the shifted data we just created
		}
		spriteDestOffset = MY_FP(FP_SEG(spriteDestOffset), FP_OFF(spriteDestOffset) + size);

		//
		// create 3rd shifted copy of the sprite:
		//
		size = (spritetable+i*4)[3].width * (spritetable+i*4)[3].height;
		(spritetable+i*4)[3].shapeptr = spriteDestOffset;
		for (p = 0; p < 5; p++)
		{
			planedst[p] = MY_FP(FP_SEG((void far*)spriteDestOffset)+FP_SEG(egasprites[p]), FP_OFF(spriteDestOffset));

			dstoff = FP_OFF(planedst[p]);
			dstseg = FP_SEG(planedst[p]);
			srcoff = FP_OFF(planesrc[p]);
			srcseg = FP_SEG(planesrc[p]);
			width  = (spritetable+i*4)[3].width;
			height = (spritetable+i*4)[3].height;
			extrabits = (p == 4) * 0xFF;

			// create a copy of the image shifted 2 pixels to the right:
			asm {
				push	si;
				push	di;
				push	ds;
				mov	di, dstoff;
				mov	si, srcoff;
				mov	bx, width;
				mov	dx, height;
				mov	ax, dstseg;
				mov	es, ax;
				mov	ax, srcseg;
				mov	ds, ax;
				cld;
			}
shift3loop:
			asm {
				// copy the pixel data:
				mov	cx, bx;
				rep movsb;

				// shift pixel data one bit/pixel to the right:
				sub	di, bx;
				mov	cx, bx;
				mov	al, extrabits;
				rcr	al, 1;
			}
shift3step1:
			asm{
				mov	al, es:[di];
				rcr	al, 1;
				mov	es:[di], al;
				inc	di;
				loop	shift3step1;

				// shift pixel data another pixel to the right:
				sub	di, bx;
				mov	cx, bx;
				mov	al, extrabits;
				rcr	al, 1;
			}
shift3step2:
			asm{
				mov	al, es:[di];
				rcr	al, 1;
				mov	es:[di], al;
				inc	di;
				loop	shift3step2;
				dec	dx;
				jnz	shift3loop;
				pop	ds;
				pop	di;
				pop	si;
			}

			planesrc[p] = planedst[p];	// not actually required here...
		}
		spriteDestOffset = MY_FP(FP_SEG(spriteDestOffset), FP_OFF(spriteDestOffset) + size);
	}

	farfree(spritebufferstart);
}


#endif /* K13_PORT */

/*
============================================================================

	    RLEW COMPRESSION routines

============================================================================
*/

#define RLETAG 0xFEFE

/*
======================
=
= RLEWcompress
=
======================
*/

#ifndef K13_PORT /* Keen Launcher port: 'unsigned' is 32-bit here; exact-width version in idlib13.c */
long RLEWCompress (unsigned far *source, long length, unsigned far *dest)
{
  long complength;
  unsigned value,count,i;
  unsigned far *start,far *end;

  start = dest;
  dest += 2;	// leave space for length value

  end = source + (length+1)/2;

//
// compress it
//
  do
  {
    count = 1;
    value = *source++;
    while (*source == value && source<end)
    {
      count++;
      source++;
    }
    if (count>3 || value == RLETAG)
    {
    //
    // send a tag / count / value string
    //
      *dest++ = RLETAG;
      *dest++ = count;
      *dest++ = value;
    }
    else
    {
    //
    // send word without compressing
    //
      for (i=1;i<=count;i++)
        *dest++ = value;
	}

  } while (source<end);

  complength = 2*(dest-start);
  *(long far *)start = length;
  return complength;
}
#endif /* K13_PORT */

/*
======================
=
= RLEWexpand
=
======================
*/

#ifndef K13_PORT /* Keen Launcher port: 'unsigned' is 32-bit here; exact-width version in idlib13.c */
void RLEWExpand (unsigned far *source, unsigned far *dest)
{
  long length;
  unsigned value,count,i;
  unsigned far *start,far *end;

  length = *(long far *)source;
  end = dest + (length)/2;

  source+=2;		// skip length words
//
// expand it
//
  do
  {
    value = *source++;
    if (value != RLETAG)
    //
    // uncompressed
    //
      *dest++=value;
    else
    {
    //
    // compressed string
    //
      count = *source++;
      value = *source++;

      for (i=1;i<=count;i++)
        *dest++ = value;
    }
  } while (dest<end);

}
#endif /* K13_PORT */


// dummy variables:
char _unk_idlib_2[10];
#ifdef USE_LZW
char _unk_idlib_3[4];
char _unk_idlib_4[2];
#endif
char _unk_idlib_5[16];
char _unk_idlib_6[50];

#ifndef USE_LZW
char lzw_stack[2];
#endif
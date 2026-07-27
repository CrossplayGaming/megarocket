/*
Keen Launcher: Keen 1-3 port compatibility layer.

Force-included (/FI) into every translation unit BEFORE the reconstructed
sources, so their Turbo C / DOS idioms compile as portable C on modern
compilers. The reconstruction's arithmetic is left untouched; this file
only absorbs platform syntax.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
*/

#ifndef K13_COMPAT_H
#define K13_COMPAT_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ---- Memory-model keywords: meaningless on flat memory ---- */
#define far
#define near
#define huge
#define _seg
#define pascal
#define cdecl
/* 'interrupt' handlers are re-plumbed in idlib13; the keyword vanishes. */
#define interrupt

/* ---- Turbo C headers that don't exist here ---- */
/* We pre-define their guards so the #includes become no-ops, and provide
 * whatever the sources actually use ourselves. */
#define __BIOS_H   /* <bios.h>  */
#define __DOS_H    /* <dos.h>   */
#define __MEM_H    /* <mem.h>   */
#define __ALLOC_H  /* <alloc.h> */
#define __CONIO_H  /* <conio.h> */
#define _BIOS_H_
#define _CONIO_H_

/* MSVC's io.h exists; fcntl/stat exist. Turbo names: */
#ifdef _MSC_VER
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
#define open(name, flags, ...) _open((name), (flags) | _O_BINARY, 0644)
#define close _close
#define read _read
#define write _write
#define lseek _lseek
#define filelength _filelength
#define unlink _unlink
#define O_BINARY _O_BINARY
#ifndef O_RDONLY
#define O_RDONLY _O_RDONLY
#endif
#endif

/* ---- Far-heap runtime + real-mode memory model ----
 * The far heap lives inside a contiguous "DOS memory" arena, so FP_SEG /
 * FP_OFF / MK_FP / movedata keep their genuine real-mode semantics
 * (paragraph arithmetic on buffers works, e.g. DrawPicFile's plane segs).
 * Pointers outside the arena (linked globals like endscreen/colors) get
 * transient far-pointer handles.  Segments A000-AFFF address the emulated
 * EGA planes through the tracked SC/GC registers; B800 is the text page.
 */
void *k13_farmalloc(unsigned long n);
void k13_farfree(void *p);
void *k13_farcalloc(unsigned long n, unsigned long s);
unsigned k13_fpseg(const void *p);
unsigned k13_fpoff(const void *p);
void *k13_mkfp(unsigned seg, unsigned ofs);
#define farmalloc k13_farmalloc
#define farfree k13_farfree
#define farcalloc k13_farcalloc
#define coreleft() (0x8000L)
#define farcoreleft() k13_farcoreleft()
long k13_farcoreleft(void);
#define FP_SEG(p) k13_fpseg((const void *)(p))
#define FP_OFF(p) k13_fpoff((const void *)(p))
#define MK_FP(seg, ofs) k13_mkfp((unsigned)(seg), (unsigned)(ofs))

/* K13_TRACE=1 flow tracepoints (port debugging; calls marked in game code) */
void K13_Trace(const char *what);

/* Pump input + throttled present. On DOS, keydown/timecount changed behind
 * the program's back via interrupts; poll-spins in game code rely on that.
 * The port injects this into ControlKBD and the few raw keydown spins. */
void K13_Idle(void);

/* EGA screen-buffer scroll helper (replaces KEENSCRN.C inline asm) */
void K13_EGAScroll(unsigned dstoff, unsigned srcoff, unsigned count,
                   int backwards);

/* movmem/setmem (mem.h) */
#define movmem(src, dst, n) memmove((dst), (src), (size_t)(n))
#define setmem(dst, n, v) memset((dst), (v), (size_t)(n))

/* ---- Turbo C pseudo-registers + geninterrupt ----
 * Register writes land in this fake register file; geninterrupt() calls
 * into idlib13, which emulates the handful of BIOS services the game
 * uses (video mode, palette via INT 10h, etc).
 */
typedef struct K13_Regs
{
	uint16_t ax, bx, cx, dx, es, si, di;
} K13_Regs;
extern K13_Regs k13_regs;
#define _AX k13_regs.ax
#define _BX k13_regs.bx
#define _CX k13_regs.cx
#define _DX k13_regs.dx
#define _ES k13_regs.es
#define _SI k13_regs.si
#define _DI k13_regs.di
#define _AH (*((uint8_t *)&k13_regs.ax + 1))
#define _AL (*((uint8_t *)&k13_regs.ax + 0))
#define _BH (*((uint8_t *)&k13_regs.bx + 1))
#define _BL (*((uint8_t *)&k13_regs.bx + 0))
#define _CH (*((uint8_t *)&k13_regs.cx + 1))
#define _CL (*((uint8_t *)&k13_regs.cx + 0))
#define _DH (*((uint8_t *)&k13_regs.dx + 1))
#define _DL (*((uint8_t *)&k13_regs.dx + 0))
void k13_geninterrupt(int intno);
#define geninterrupt k13_geninterrupt

/* ---- Port I/O: routed to idlib13 (mostly ignored or logged) ---- */
void k13_outportb(unsigned port, unsigned char value);
void k13_outport(unsigned port, unsigned value);
unsigned char k13_inportb(unsigned port);
unsigned k13_inport(unsigned port);
#define outportb k13_outportb
#define outport k13_outport
#define inportb k13_inportb
#define inport k13_inport

/* peek/poke into emulated memory (idlib13 owns the EGA emulation) */
void k13_pokeb(unsigned seg, unsigned ofs, unsigned char value);
unsigned char k13_peekb(unsigned seg, unsigned ofs);
#define pokeb k13_pokeb
#define peekb k13_peekb
#define poke(seg, ofs, v) (void)(seg, ofs, v)
#define peek(seg, ofs) ((unsigned)0)
void k13_movedata(unsigned srcseg, unsigned srcoff, unsigned dstseg, unsigned dstoff, size_t n);
#define movedata k13_movedata

/* ---- Misc Turbo RTL ---- */
#define random(x) (rand() % (x))
#define randomize() srand(4547)
void k13_delay(unsigned ms);
#define delay k13_delay
int k13_kbhit(void);
int k13_getch(void);
#define kbhit k13_kbhit
#define getch k13_getch
#define clrscr() ((void)0)
#define textmode(m) ((void)(m))
#define gotoxy(x, y) ((void)0)

#ifdef _MSC_VER
#define strupr _strupr
#define strlwr _strlwr
#define itoa _itoa
#define ltoa _ltoa
#define ultoa _ultoa
#endif

/* Turbo C's getvect/setvect (interrupt vectors) are handled by idlib13. */
typedef void (*k13_intvec_t)(void);
k13_intvec_t k13_getvect(int intno);
void k13_setvect(int intno, k13_intvec_t vec);
#define getvect k13_getvect
#define setvect k13_setvect
#define enable() ((void)0)
#define disable() ((void)0)

#endif /* K13_COMPAT_H */

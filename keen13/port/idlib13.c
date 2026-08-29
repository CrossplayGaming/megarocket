/*
Keen Launcher: Keen 1-3 platform layer ("idlib13").

Provides what the original build got from IDASM.ASM, plus portable
replacements for the K13_PORT-fenced functions in IDLIBC.C, plus a
real-mode memory model:

  - a 640KB "DOS memory" arena backs the far heap, so FP_SEG/FP_OFF/
    MK_FP/movedata keep genuine paragraph semantics (game code does
    real segment arithmetic, e.g. DrawPicFile's per-plane segments)
  - four 64KB EGA planes are emulated, addressed through segments
    A000-AFFF and the tracked SC map-mask / GC read-map registers
  - draw routines are byte-exact plane copies mirroring IDASM.ASM

SIM-CRITICAL pieces (RNG, RLE) are instruction-faithful ports -- see
the per-function notes.  SDL presentation/input is the next milestone;
until then K13_DUMP=1 writes PPM screenshots for verification.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
*/

#include "KEENDEF.H"

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef K13_WITH_SDL
#include "SDL.h"
#endif

/* refresh-list globals defined in KEENMAIN.C (declared here because the
 * original referenced them from IDASM.ASM, not a header) */
extern Sint16 coverlist[600], *coverlistptr;
extern Sint16 oldtiles[], oldtiles2[];
extern drawtype spritelist[], *spritelistptr;
extern drawtype piclist[], *piclistptr;
extern drawtype tilelist[];
extern Uint16 spritesshown, picsshown, tilesshown;

#define K13_PORTTILECOUNT (PORTTILESWIDE * PORTTILESHIGH)

#define STUB()                                             \
	do                                                     \
	{                                                      \
		static int warned;                                 \
		if (!warned)                                       \
		{                                                  \
			warned = 1;                                    \
			fprintf(stderr, "K13 STUB: %s\n", __func__);   \
		}                                                  \
	} while (0)

/*
=============================================================================
	Real-mode memory model
	 - paragraphs 0x1000-0x9FFF: far-heap arena (inside k13_dosmem)
	 - segments  0xA000-0xAFFF: emulated EGA planes
	 - segment   0xB800:        text page (exit screen)
	 - segments  0xE000-0xE03F: transient handles for non-arena pointers
=============================================================================
*/

#define K13_ARENA_FIRST 0x1000u
#define K13_ARENA_END 0xA000u
#define K13_HANDLE_SEG 0xE000u
#define K13_NUM_HANDLES 64

static Uint8 k13_dosmem[K13_ARENA_END << 4];
static const void *k13_handles[K13_NUM_HANDLES];
static int k13_nexthandle;

static Uint8 k13_ega[4][0x10000];
static Uint8 k13_textpage[8000];

/* far-heap arena: paragraph-aligned blocks, 16-byte header */
typedef struct
{
	Uint32 size; /* payload bytes, multiple of 16 */
	Uint32 used;
	Uint32 pad[2];
} K13_Block;

static int k13_arena_ready;

static void k13_arena_init(void)
{
	K13_Block *b = (K13_Block *)(k13_dosmem + (K13_ARENA_FIRST << 4));
	b->size = ((K13_ARENA_END - K13_ARENA_FIRST) << 4) - sizeof(K13_Block);
	b->used = 0;
	k13_arena_ready = 1;
}

static K13_Block *k13_next_block(K13_Block *b)
{
	Uint8 *p = (Uint8 *)b + sizeof(K13_Block) + b->size;
	if (p >= k13_dosmem + (K13_ARENA_END << 4))
		return NULL;
	return (K13_Block *)p;
}

static void k13_coalesce(void)
{
	K13_Block *b = (K13_Block *)(k13_dosmem + (K13_ARENA_FIRST << 4));
	while (b)
	{
		K13_Block *n = k13_next_block(b);
		if (n && !b->used && !n->used)
		{
			b->size += sizeof(K13_Block) + n->size;
			continue; /* try to swallow the following block too */
		}
		b = n;
	}
}

void *k13_farmalloc(unsigned long n)
{
	Uint32 need = ((Uint32)n + 15u) & ~15u;
	int pass;

	if (!k13_arena_ready)
		k13_arena_init();
	if (need == 0)
		need = 16;

	for (pass = 0; pass < 2; pass++)
	{
		K13_Block *b = (K13_Block *)(k13_dosmem + (K13_ARENA_FIRST << 4));
		for (; b; b = k13_next_block(b))
		{
			if (b->used || b->size < need)
				continue;
			if (b->size >= need + sizeof(K13_Block) + 16)
			{
				K13_Block *rest =
					(K13_Block *)((Uint8 *)b + sizeof(K13_Block) + need);
				rest->size = b->size - need - sizeof(K13_Block);
				rest->used = 0;
				b->size = need;
			}
			b->used = 1;
			return (Uint8 *)b + sizeof(K13_Block);
		}
		k13_coalesce();
	}
	return NULL;
}

void k13_farfree(void *p)
{
	K13_Block *b;

	if (!p)
		return;
	b = (K13_Block *)((Uint8 *)p - sizeof(K13_Block));
	b->used = 0;
}

void *k13_farcalloc(unsigned long n, unsigned long s)
{
	void *p = k13_farmalloc(n * s);
	if (p)
		memset(p, 0, (size_t)(n * s));
	return p;
}

long k13_farcoreleft(void)
{
	long best = 0;
	K13_Block *b;

	if (!k13_arena_ready)
		k13_arena_init();
	k13_coalesce();
	b = (K13_Block *)(k13_dosmem + (K13_ARENA_FIRST << 4));
	for (; b; b = k13_next_block(b))
		if (!b->used && (long)b->size > best)
			best = (long)b->size;
	return best;
}

static int k13_in_dosmem(const void *p)
{
	return (const Uint8 *)p >= k13_dosmem &&
	       (const Uint8 *)p < k13_dosmem + sizeof(k13_dosmem);
}

unsigned k13_fpseg(const void *p)
{
	if (k13_in_dosmem(p))
		return (unsigned)(((const Uint8 *)p - k13_dosmem) >> 4);

	/* out-of-arena pointer (linked global): hand out a transient handle */
	{
		int idx = k13_nexthandle;
		k13_nexthandle = (k13_nexthandle + 1) % K13_NUM_HANDLES;
		k13_handles[idx] =
			(const void *)((uintptr_t)p & ~(uintptr_t)0xF);
		return K13_HANDLE_SEG + (unsigned)idx;
	}
}

unsigned k13_fpoff(const void *p)
{
	if (k13_in_dosmem(p))
		return (unsigned)(((const Uint8 *)p - k13_dosmem) & 0xF);
	return (unsigned)((uintptr_t)p & 0xF);
}

/* shadow target for video-segment far pointers (charptr etc.); nothing
 * dereferences these in the port, but they must be storable */
static Uint8 k13_vidshadow[16];

void *k13_mkfp(unsigned seg, unsigned ofs)
{
	if (seg >= K13_HANDLE_SEG && seg < K13_HANDLE_SEG + K13_NUM_HANDLES)
		return (Uint8 *)(uintptr_t)k13_handles[seg - K13_HANDLE_SEG] + ofs;
	if (seg < K13_ARENA_END)
		return k13_dosmem + ((uintptr_t)seg << 4) + ofs;
	return k13_vidshadow; /* video segments: token pointer only */
}

/*
=============================================================================
	EGA register file (fed by the game's own outport/outportb calls)
=============================================================================
*/

#define K13_SC_INDEX 0x3C4
#define K13_GC_INDEX 0x3CE
#define K13_CRTC_INDEX 0x3D4

static Uint8 k13_sc_idx, k13_gc_idx, k13_crtc_idx;
static Uint8 k13_sc_reg[8] = {0, 0, 0xF, 0, 0, 0, 0, 0}; /* [2]=mapmask */
static Uint8 k13_gc_reg[16];                             /* [4]=readmap, [5]=mode */
static Uint8 k13_crtc_reg[32];
static Uint8 k13_border;
static Uint8 k13_palette[17] = {0, 1, 2, 3, 4, 5, 6, 7,
                                0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0};

void outportb(unsigned port, unsigned char value)
{
	switch (port)
	{
	case K13_SC_INDEX: k13_sc_idx = value & 7; break;
	case K13_SC_INDEX + 1: k13_sc_reg[k13_sc_idx] = value; break;
	case K13_GC_INDEX: k13_gc_idx = value & 15; break;
	case K13_GC_INDEX + 1: k13_gc_reg[k13_gc_idx] = value; break;
	case K13_CRTC_INDEX: k13_crtc_idx = value & 31; break;
	case K13_CRTC_INDEX + 1: k13_crtc_reg[k13_crtc_idx] = value; break;
	default: break;
	}
}

void outport(unsigned port, unsigned value)
{
	/* word OUT: low byte to index port, high byte to data port */
	outportb(port, (unsigned char)(value & 0xFF));
	outportb(port + 1, (unsigned char)(value >> 8));
}

unsigned char inportb(unsigned port)
{
	(void)port;
	return 0;
}

unsigned inport(unsigned port)
{
	(void)port;
	return 0;
}

#define K13_MAPMASK (k13_sc_reg[2])
#define K13_READMAP (k13_gc_reg[4] & 3)

/*
=============================================================================
	Turbo C compat plumbing (declared in k13_compat.h)
=============================================================================
*/

K13_Regs k13_regs;

void K13_Trace(const char *what)
{
	static int on = -1;
	if (on < 0)
		on = getenv("K13_TRACE") != NULL;
	if (on)
	{
		fprintf(stderr, "K13 TP: %s\n", what);
		fflush(stderr);
	}
}

void k13_geninterrupt(int intno)
{
	if (intno == 0x10)
	{
		unsigned ah = (k13_regs.ax >> 8) & 0xFF;
		if (k13_regs.ax == 0x000D)
			return; /* set video mode 0Dh: we are always in it */
		if (k13_regs.ax == 0x1002)
		{
			/* set all palette registers, table at ES:DX */
			Uint8 *tbl = (Uint8 *)k13_mkfp(k13_regs.es, k13_regs.dx);
			memcpy(k13_palette, tbl, 17);
			return;
		}
		if (ah == 0x10 && (k13_regs.ax & 0xFF) == 1)
		{
			k13_border = (Uint8)((k13_regs.bx >> 8) & 0xFF);
			return;
		}
	}
	{
		static int warned[256];
		if (intno >= 0 && intno < 256 && !warned[intno])
		{
			warned[intno] = 1;
			fprintf(stderr, "K13 STUB: geninterrupt(0x%02X) AX=%04X\n",
			        intno, k13_regs.ax);
		}
	}
}

/* resolve a (seg,off) side of movedata/pokeb; EGA/text handled by caller */
static Uint8 *k13_seg_mem(unsigned seg, unsigned ofs)
{
	return (Uint8 *)k13_mkfp(seg, ofs);
}

void k13_movedata(unsigned srcseg, unsigned srcoff,
                  unsigned dstseg, unsigned dstoff, size_t n)
{
	int src_ega = (srcseg >= 0xA000 && srcseg < 0xB000);
	int dst_ega = (dstseg >= 0xA000 && dstseg < 0xB000);
	int dst_txt = (dstseg >= 0xB800 && dstseg < 0xC000);
	size_t i;

	if (!src_ega && !dst_ega && !dst_txt)
	{
		memmove(k13_seg_mem(dstseg, dstoff), k13_seg_mem(srcseg, srcoff), n);
		return;
	}
	if (dst_txt)
	{
		Uint32 daddr = ((dstseg - 0xB800) << 4) + dstoff;
		const Uint8 *s = k13_seg_mem(srcseg, srcoff);
		if (daddr + n <= sizeof(k13_textpage))
			memcpy(k13_textpage + daddr, s, n);
		return;
	}
	if (dst_ega && !src_ega)
	{
		/* write mode 0: store to every plane enabled in the map mask */
		Uint32 daddr = ((dstseg - 0xA000) << 4) + dstoff;
		const Uint8 *s = k13_seg_mem(srcseg, srcoff);
		Uint8 mask = K13_MAPMASK;
		int p;
		for (p = 0; p < 4; p++)
			if (mask & (1 << p))
				for (i = 0; i < n; i++)
					k13_ega[p][(daddr + i) & 0xFFFF] = s[i];
		return;
	}
	if (src_ega && !dst_ega)
	{
		/* read mode 0: read from the plane selected by GC read-map */
		Uint32 saddr = ((srcseg - 0xA000) << 4) + srcoff;
		Uint8 *d = k13_seg_mem(dstseg, dstoff);
		for (i = 0; i < n; i++)
			d[i] = k13_ega[K13_READMAP][(saddr + i) & 0xFFFF];
		return;
	}
	/* EGA -> EGA: latch copy, all planes enabled by map mask */
	{
		Uint32 saddr = ((srcseg - 0xA000) << 4) + srcoff;
		Uint32 daddr = ((dstseg - 0xA000) << 4) + dstoff;
		Uint8 mask = K13_MAPMASK;
		int p;
		for (p = 0; p < 4; p++)
			if (mask & (1 << p))
				memmove(k13_ega[p] + daddr, k13_ega[p] + saddr, n);
	}
}

void k13_pokeb(unsigned seg, unsigned ofs, unsigned char value)
{
	if (seg >= 0xA000 && seg < 0xB000)
	{
		Uint32 addr = ((seg - 0xA000) << 4) + ofs;
		int p;
		for (p = 0; p < 4; p++)
			if (K13_MAPMASK & (1 << p))
				k13_ega[p][addr & 0xFFFF] = value;
		return;
	}
	*k13_seg_mem(seg, ofs) = value;
}

unsigned char k13_peekb(unsigned seg, unsigned ofs)
{
	if (seg >= 0xA000 && seg < 0xB000)
		return k13_ega[K13_READMAP][(((seg - 0xA000) << 4) + ofs) & 0xFFFF];
	return *k13_seg_mem(seg, ofs);
}

void harderr(void *handler) { (void)handler; }
void hardresume(int rescode) { (void)rescode; }
void k13_delay(unsigned ms) { (void)ms; }
int k13_kbhit(void) { return 0; }
int k13_getch(void) { return 0; }
k13_intvec_t k13_getvect(int intno) { (void)intno; return NULL; }
void k13_setvect(int intno, k13_intvec_t vec) { (void)intno; (void)vec; }

/*
=============================================================================
	Crash reporter: prints the faulting address relative to the module base
	so the linker /MAP file resolves it to a function
=============================================================================
*/

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

static LONG WINAPI k13_crash_filter(EXCEPTION_POINTERS *ep)
{
	HMODULE base = GetModuleHandle(NULL);
	void *addr = ep->ExceptionRecord->ExceptionAddress;
	fprintf(stderr,
	        "K13 CRASH: code %08lX at %p (module base %p, offset +0x%llX)\n",
	        (unsigned long)ep->ExceptionRecord->ExceptionCode, addr,
	        (void *)base,
	        (unsigned long long)((Uint8 *)addr - (Uint8 *)base));
	fflush(stderr);
	return EXCEPTION_EXECUTE_HANDLER;
}

static void k13_install_crash_filter(void)
{
	static int done;
	if (!done)
	{
		done = 1;
		SetUnhandledExceptionFilter(k13_crash_filter);
	}
}
#else
static void k13_install_crash_filter(void) {}
#endif

/*
=============================================================================
	IDASM.ASM data
=============================================================================
*/

/* byte-wide toupper/tolower, matching Turbo C's 16-bit RTL (see IDLIB.H):
 * the game passes Get()'s packed (scancode<<8)|ascii into these */
int K13_ToUpper(int c)
{
	int b = c & 0xFF;
	return (b >= 'a' && b <= 'z') ? b - ('a' - 'A') : b;
}

int K13_ToLower(int c)
{
	int b = c & 0xFF;
	return (b >= 'A' && b <= 'Z') ? b + ('a' - 'A') : b;
}

unsigned screenseg = 0xA000;
unsigned screenofs;
unsigned screenorigin;
Uint16 EGApage;
void (*uservect)(void);

char keydown[128];
int NBKscan, NBKascii, lastkey;
boolean passtobios;

soundtype soundmode = spkr;
char huge *SoundData;
unsigned timerspeed;
int dontplay;
unsigned inttime;
long timecount;
unsigned int8hook;
memptr soundseg;
unsigned sndptr;
int SndPriority;

/* MAXTILES matches IDASM.ASM (Keen 1's tileset alone has 611 tiles) */
#define K13_MAXTILES 768 /* Keen 3 has 715 tiles */
unsigned tile_anim0[K13_MAXTILES], tile_anim1[K13_MAXTILES],
	tile_anim2[K13_MAXTILES], tile_anim3[K13_MAXTILES];

/* graphics layout resolved by LoadGraphics (plane-relative byte offsets) */
static Uint32 k13_charoff, k13_tileoff, k13_picoff;
static Uint8 *k13_sprplane[5]; /* 4 color planes + mask plane */

static Uint16 k13_ylookup[512];
static int k13_ylookup_ready;

static void k13_init_ylookup(void)
{
	int y;
	for (y = 0; y < 512; y++)
		k13_ylookup[y] = (Uint16)(y * SCREENWIDTH);
	k13_ylookup_ready = 1;
}

/* current draw page base from the (swappable) screenseg variable */
static Uint32 k13_pagebase(void)
{
	return ((Uint32)(screenseg - 0xA000)) << 4;
}

/* Static screens (menus, dialogs, status) draw straight to the page and
 * never flip the display.  The engine double-buffers, though, so screenseg
 * can point at a different page between the frame draw and the text/sprite
 * draws, scattering a popup across both pages.  While a dialog is open we
 * PIN every draw (and the present) to the page that was current when the
 * window opened, keeping the whole popup on one visible page. */
static Uint32 k13_dialog_base;
static int k13_dialog_active; /* also (re)declared in k13_compositor.inc */
static int k13_test_fired;    /* K13_TEST_STATUS pressed its Space key */
static int k13_test_seq_ran;  /* K13_TEST_SEQ has fired at least one key */

static Uint32 k13_drawbase(void)
{
	return k13_dialog_active ? k13_dialog_base : k13_pagebase();
}

/*
=============================================================================
	Record/replay verification harness (K13_RECORD=file / K13_REPLAY=file)

	Keen 1-3 pace the sim off wall-clock tics, so a recording captures the
	tic count of every frame plus every ControlPlayer result and RNG seed,
	then a replay forces the identical sequence -- fully deterministic --
	and compares a per-frame FNV-1a hash over the complete sim state.
	This locks today's sim behavior as the regression baseline, exactly
	like the omnispeak /CHECKSUM harness.
=============================================================================
*/

/* real PIT ticks, private to the platform layer: game-visible timecount
 * advances only by whole frame tics (K13_FrameTics), so the sim never
 * observes wall-clock jitter -- the key to deterministic replays */
static volatile long k13_ticks_real;
static void k13_pump(void);

/* compositor shared state (functions live in k13_compositor.inc) */
#define K13_COMP_MAXW 512
static Uint8 k13_comp[K13_COMP_MAXW * 200]; /* palette-index frame */
static int k13_comp_w;                      /* 0 = compositor off */
static int k13_smooth = 1;
static int k13_comp_have;                   /* last composed frame valid */
static void k13_comp_frame_start(Sint16 tics);
static void k13_comp_refresh_snap(void);
static int k13_compose(long num, long den);
static void k13_present_interp(void);
static Uint32 k13_prof[4]; /* compose, upload, render, present ms */
static Uint32 k13_prof_n;
static int k13_world_live_dbg(void);
static int k13_nspr_dbg(void);
static long k13_real_at_refresh;
static Uint32 k13_refresh_ms;
static Sint16 k13_frame_len_tics = 6;
static int k13_world_live; /* VidRefresh ran with uservect==NULL */


static FILE *k13_recf, *k13_repf;

/* During harness runs, input events are held here and applied only at
 * recorded boundaries (K13_FrameTics / NoBiosKey), because mid-frame
 * pumps would let later readers (DoFkeys after RF_Refresh) see state the
 * frame-start snapshot missed. Normal play applies events instantly. */
#define K13_PENDMAX 64
static struct { Uint8 sc; Uint8 down; } k13_pending[K13_PENDMAX];
static int k13_npending;

static void k13_apply_pending(void)
{
	int i;
	for (i = 0; i < k13_npending; i++)
	{
		Uint8 sc = k13_pending[i].sc;
		if (k13_pending[i].down)
		{
			keydown[sc] = 1;
			NBKscan = sc | 0x80;
		}
		else
		{
			keydown[sc] = 0;
		}
	}
	k13_npending = 0;
}
static Uint32 k13_vframe;
static int k13_verify_ready;

static void k13_verify_init(void)
{
	const char *r;

	if (k13_verify_ready)
		return;
	k13_verify_ready = 1;
	if ((r = getenv("K13_RECORD")) != NULL)
	{
		k13_recf = fopen(r, "wb");
		if (k13_recf)
			fwrite("K132", 1, 4, k13_recf);
	}
	else if ((r = getenv("K13_REPLAY")) != NULL)
	{
		char magic[4] = {0};
		k13_repf = fopen(r, "rb");
		if (k13_repf)
			fread(magic, 1, 4, k13_repf);
		if (memcmp(magic, "K132", 4) != 0)
		{
			fprintf(stderr, "K13 VERIFY: bad replay file\n");
			exit(2);
		}
	}
}

static Uint32 k13_fnv(const void *data, size_t len, Uint32 h)
{
	const Uint8 *p = (const Uint8 *)data;
	while (len--)
	{
		h ^= *p++;
		h *= 16777619u;
	}
	return h;
}

static const void *k13_RndArray_hashref(void);

/* 'K' records carry the post-call input state as well, because game code
 * (DoFkeys) reads NBKscan/keydown directly right after these calls */
static void k13_pack_keys(Uint8 bits[16])
{
	int i;
	memset(bits, 0, 16);
	for (i = 0; i < 128; i++)
		if (keydown[i])
			bits[i >> 3] |= (Uint8)(1 << (i & 7));
}

static void k13_unpack_keys(const Uint8 bits[16])
{
	int i;
	for (i = 0; i < 128; i++)
		keydown[i] = (bits[i >> 3] >> (i & 7)) & 1;
}

static void k13_verify_fail(const char *what)
{
	fprintf(stderr, "K13 VERIFY: DESYNC (%s) at frame %lu\n", what,
	        (unsigned long)k13_vframe);
	fflush(stderr);
	exit(3);
}

static void k13_verify_expect(int tag)
{
	int got = fgetc(k13_repf);
	if (got == EOF)
	{
		fprintf(stderr, "K13 VERIFY: REPLAY OK (%lu frames)\n",
		        (unsigned long)k13_vframe);
		fflush(stderr);
		exit(0);
	}
	if (got != tag)
		k13_verify_fail("record order");
}

/* RNG seed capture (called from InitRnd/InitRndT below) */
static void k13_verify_seed(Uint16 *a, Uint16 *b)
{
	k13_verify_init();
	if (k13_recf)
	{
		fputc('S', k13_recf);
		fwrite(a, 2, 1, k13_recf);
		fwrite(b, 2, 1, k13_recf);
	}
	else if (k13_repf)
	{
		k13_verify_expect('S');
		fread(a, 2, 1, k13_repf);
		fread(b, 2, 1, k13_repf);
	}
}

static int k13_replaying(void)
{
	return k13_repf != NULL;
}

/* hooks called from game code (block-scope declared at the call sites) */
ControlStruct K13_VerifyCtrl(ControlStruct c);
Sint16 K13_FrameTics(Sint16 mintics, Sint16 maxtics);
static void k13_qs_selftest(void);   /* defined with the quicksave code */

ControlStruct K13_VerifyCtrl(ControlStruct c)
{
	k13_verify_init();
	if (k13_recf)
	{
		Uint8 rec[3];
		rec[0] = (Uint8)c.dir;
		rec[1] = (Uint8)c.button1;
		rec[2] = (Uint8)c.button2;
		fputc('C', k13_recf);
		fwrite(rec, 1, 3, k13_recf);
	}
	else if (k13_repf)
	{
		Uint8 rec[3] = {0};
		k13_verify_expect('C');
		fread(rec, 1, 3, k13_repf);
		c.dir = (dirtype)rec[0];
		c.button1 = rec[1];
		c.button2 = rec[2];
	}
	return c;
}

/* complete sim state hash, split by component so desyncs name their
 * subsystem; function pointers in the obj structs are excluded */
#define K13_NUMHASH 7

static void k13_state_hashes(Uint32 out[K13_NUMHASH])
{
	Uint32 h;
	int i;

	h = 2166136261u;
	for (i = 0; i < MAXOBJECTS; i++)
		h = k13_fnv(&objlist[i], offsetof(objtype, think), h);
	out[0] = h;
	h = 2166136261u;
	for (i = 0; i < MAXPOBJECTS; i++)
		h = k13_fnv(&pobjlist[i], offsetof(pobjtype, think), h);
	out[1] = h;
	out[2] = k13_fnv(&numobj, sizeof(numobj), 2166136261u);
	out[3] = k13_fnv(&gamestate, sizeof(gamestate), 2166136261u);
	h = k13_fnv(&originx, sizeof(originx), 2166136261u);
	out[4] = k13_fnv(&originy, sizeof(originy), h);
	out[5] = k13_fnv(&level, sizeof(level), 2166136261u);
	out[6] = k13_fnv(k13_RndArray_hashref(), 17 * 2 + 8, 2166136261u);
}

static const char *k13_hash_names[K13_NUMHASH] = {
	"objlist", "pobjlist", "numobj", "gamestate", "origin", "level", "rng"
};

Sint16 K13_FrameTics(Sint16 mintics, Sint16 maxtics)
{
	Sint16 tics;
	static long lastreal;

	k13_verify_init();

	if (k13_repf)
	{
		/* replay: no pacing wait; everything comes from the recording */
		Uint32 want[K13_NUMHASH], h[K13_NUMHASH];
		Uint8 bits[16];
		int i, sc;

		k13_verify_expect('T');
		fread(&tics, 2, 1, k13_repf);
		k13_verify_expect('I');
		fread(bits, 1, 16, k13_repf);
		sc = fgetc(k13_repf);
		k13_unpack_keys(bits);
		NBKscan = sc;
		k13_verify_expect('H');
		fread(want, 4, K13_NUMHASH, k13_repf);
		k13_state_hashes(h);
		{
			int bad = -1, tag;
			for (i = 0; i < K13_NUMHASH; i++)
				if (h[i] != want[i] && bad < 0)
					bad = i;
			tag = fgetc(k13_repf);
			if (tag == 'R')
			{
				/* raw objlist follows; on mismatch, diff field-level */
				size_t osz = offsetof(objtype, think);
				int oi;
				for (oi = 0; oi < MAXOBJECTS; oi++)
				{
					Uint8 buf[128];
					fread(buf, 1, osz, k13_repf);
					if (bad == 0 &&
					    memcmp(buf, &objlist[oi], osz) != 0)
					{
						size_t b;
						fprintf(stderr,
						        "K13 VERIFY: obj %d differs at frame %lu; bytes:",
						        oi, (unsigned long)k13_vframe);
						for (b = 0; b < osz; b++)
							if (buf[b] != ((Uint8 *)&objlist[oi])[b])
								fprintf(stderr, " +%u(%02X!=%02X)",
								        (unsigned)b, buf[b],
								        ((Uint8 *)&objlist[oi])[b]);
						fputc(0x0A, stderr);
					}
				}
				fflush(stderr);
			}
			else if (tag != EOF)
			{
				ungetc(tag, k13_repf);
			}
			if (bad >= 0)
				k13_verify_fail(k13_hash_names[bad]);
		}
		k13_vframe++;
		timecount += tics;
		k13_comp_frame_start(tics);
		k13_qs_selftest();
		return tics;
	}

	/* normal play / recording: pace on the private real tick counter,
	   exactly like RF_Clear's original timecount wait; interpolated
	   compositor frames present while we wait */
	for (;;)
	{
		long real = k13_ticks_real;
		tics = (Sint16)(real - lastreal);
		if (tics >= mintics)
		{
			lastreal = real;
			break;
		}
#ifdef K13_WITH_SDL
		k13_present_interp(); /* vsync-paced when a frame composes */
		SDL_Delay(1);
		k13_pump();
#endif
	}
	if (tics > maxtics)
		tics = maxtics;

	if (k13_recf)
	{
		Uint32 h[K13_NUMHASH];
		Uint8 bits[16];
		int i;
		k13_apply_pending();
		k13_state_hashes(h);
		fputc('T', k13_recf);
		fwrite(&tics, 2, 1, k13_recf);
		k13_pack_keys(bits);
		fputc('I', k13_recf);
		fwrite(bits, 1, 16, k13_recf);
		fputc((Uint8)NBKscan, k13_recf);
		fputc('H', k13_recf);
		fwrite(h, 4, K13_NUMHASH, k13_recf);
		if (getenv("K13_STATEDUMP"))
		{
			fputc('R', k13_recf);
			for (i = 0; i < MAXOBJECTS; i++)
				fwrite(&objlist[i], 1, offsetof(objtype, think), k13_recf);
		}
		fflush(k13_recf); /* recordings survive a hard kill */
		k13_vframe++;
	}

	timecount += tics; /* the sim's clock advances in whole frame tics */
	k13_comp_frame_start(tics);
#ifdef K13_WITH_SDL
	/* K13_TEST_STATUS=N: press Space on the Nth live frame so the status
	   screen opens deterministically (repro for the static-screen path) */
	{
		static int want = -2, seen;
		if (want == -2)
		{
			const char *e = getenv("K13_TEST_STATUS");
			want = e ? atoi(e) : -1;
		}
		if (want > 0 && k13_world_live && ++seen == want)
		{
			keydown[0x39] = 1; /* Space */
			k13_test_fired = 1;
			fprintf(stderr, "K13 TEST: space injected (frame %d)\n", seen);
			fflush(stderr);
		}
	}
#endif
	return tics;
}

/*
=============================================================================
	SIM-CRITICAL: random number generators (exact IDASM.ASM ports)
=============================================================================
*/

static const unsigned char k13_rndtable[256] = {
	0, 8, 109, 220, 222, 241, 149, 107, 75, 248, 254, 140, 16, 66,
	74, 21, 211, 47, 80, 242, 154, 27, 205, 128, 161, 89, 77, 36,
	95, 110, 85, 48, 212, 140, 211, 249, 22, 79, 200, 50, 28, 188,
	52, 140, 202, 120, 68, 145, 62, 70, 184, 190, 91, 197, 152, 224,
	149, 104, 25, 178, 252, 182, 202, 182, 141, 197, 4, 81, 181, 242,
	145, 42, 39, 227, 156, 198, 225, 193, 219, 93, 122, 175, 249, 0,
	175, 143, 70, 239, 46, 246, 163, 53, 163, 109, 168, 135, 2, 235,
	25, 92, 20, 145, 138, 77, 69, 166, 78, 176, 173, 212, 166, 113,
	94, 161, 41, 50, 239, 49, 111, 164, 70, 60, 2, 37, 171, 75,
	136, 156, 11, 56, 42, 146, 138, 229, 73, 146, 77, 61, 98, 196,
	135, 106, 63, 197, 195, 86, 96, 203, 113, 101, 170, 247, 181, 113,
	80, 250, 108, 7, 255, 237, 129, 226, 79, 107, 112, 166, 103, 241,
	24, 223, 239, 120, 198, 58, 60, 82, 128, 3, 184, 66, 143, 224,
	145, 224, 81, 206, 163, 45, 63, 90, 168, 114, 59, 33, 159, 95,
	28, 139, 123, 98, 125, 196, 15, 70, 194, 253, 54, 14, 109, 226,
	71, 17, 161, 93, 186, 87, 244, 138, 20, 52, 123, 251, 26, 36,
	17, 46, 52, 231, 232, 76, 31, 221, 84, 37, 216, 165, 212, 106,
	197, 242, 98, 43, 39, 175, 254, 145, 190, 84, 118, 222, 187, 136,
	120, 163, 236, 249
};

static unsigned k13_rndindex;

void InitRndT(boolean randomize)
{
	if (!randomize)
	{
		k13_rndindex = 0;
	}
	else
	{
		Uint16 dx = (Uint16)((unsigned)(clock() / (CLOCKS_PER_SEC / 100)) & 0xFF);
		Uint16 zero = 0;
		k13_verify_seed(&dx, &zero);
		k13_rndindex = dx & 0xFF;
	}
}

int RndT(void)
{
	k13_rndindex = (k13_rndindex + 1) & 0xFF;
	return k13_rndtable[k13_rndindex];
}

static const unsigned short k13_baseRndArray[17] = {
	1, 1, 2, 3, 5, 8, 13, 21, 54, 75, 129, 204,
	323, 527, 850, 1377, 2227
};

static unsigned short k13_RndArray[17];
static unsigned short k13_LastRnd;
static int k13_indexi, k13_indexj; /* 1-based word indexes */

int Rnd(int maxval)
{
	unsigned mask, ax;
	unsigned mv = (unsigned)maxval & 0xFFFF;

	/* mask = (2^(p+1))-1 where p = position of maxval's top set bit */
	mask = 0xFFFF;
	ax = mv;
	while (!(ax & 0x8000))
	{
		ax = (ax << 1) & 0xFFFF;
		mask >>= 1;
	}

	/* NOTE: the asm's ADC runs with the carry still set from the final
	   SHL of the mask loop, so the sum always includes +1 */
	ax = (k13_RndArray[k13_indexi - 1] + k13_RndArray[k13_indexj - 1] + 1)
	     & 0xFFFF;
	k13_RndArray[k13_indexi - 1] = (unsigned short)ax;
	ax = (ax + k13_LastRnd) & 0xFFFF;
	k13_LastRnd = (unsigned short)ax;

	if (--k13_indexi == 0)
		k13_indexi = 17;
	if (--k13_indexj == 0)
		k13_indexj = 17;

	ax &= mask;
	if (ax > mv)
		ax >>= 1; /* single shift, exactly as the asm does */
	return (int)ax;
}

void InitRnd(boolean randomize)
{
	int i;

	for (i = 0; i < 17; i++)
		k13_RndArray[i] = k13_baseRndArray[i];
	k13_LastRnd = 0;
	k13_indexi = 17;
	k13_indexj = 5;

	if (randomize)
	{
		Uint16 dx = (Uint16)clock();
		Uint16 cx = (Uint16)((unsigned)clock() >> 16);
		k13_verify_seed(&dx, &cx); /* record or replay the seed */
		k13_RndArray[16] = dx;
		k13_RndArray[4] = (unsigned short)(dx ^ cx);
	}

	Rnd(0xFFFF); /* warm up generator, exactly as the asm does */
}

/* RNG state for quicksave: both generators and their cursors, matching what
 * k13_state_hashes() covers so a restored game diverges from nothing */
void K13_RndSave(FILE *f)
{
	fwrite(&k13_rndindex, sizeof(k13_rndindex), 1, f);
	fwrite(k13_RndArray, sizeof(k13_RndArray[0]), 17, f);
	fwrite(&k13_LastRnd, sizeof(k13_LastRnd), 1, f);
	fwrite(&k13_indexi, sizeof(k13_indexi), 1, f);
	fwrite(&k13_indexj, sizeof(k13_indexj), 1, f);
}

void K13_RndLoad(FILE *f)
{
	fread(&k13_rndindex, sizeof(k13_rndindex), 1, f);
	fread(k13_RndArray, sizeof(k13_RndArray[0]), 17, f);
	fread(&k13_LastRnd, sizeof(k13_LastRnd), 1, f);
	fread(&k13_indexi, sizeof(k13_indexi), 1, f);
	fread(&k13_indexj, sizeof(k13_indexj), 1, f);
}

/* packed RNG internals for the verification hash */
static const void *k13_RndArray_hashref(void)
{
	static Uint8 buf[17 * 2 + 8];
	Uint16 v;

	memcpy(buf, k13_RndArray, 34);
	memcpy(buf + 34, &k13_LastRnd, 2);
	v = (Uint16)k13_indexi;
	memcpy(buf + 36, &v, 2);
	v = (Uint16)k13_indexj;
	memcpy(buf + 38, &v, 2);
	v = (Uint16)k13_rndindex;
	memcpy(buf + 40, &v, 2);
	return buf;
}

/*
=============================================================================
	SIM-CRITICAL: byte-level RLE (exact IDASM.ASM port)

	Source starts with a 32-bit expanded length; then blocks:
	  code >= 0x80 -> literal string of (code - 0x7F) bytes follows
	  code <  0x80 -> next byte repeated (code + 3) times
	The asm subtracts each block's size from the remaining length
	*before* decoding the next block (initial subtrahend 1) and stops
	on underflow -- mirrored exactly.
=============================================================================
*/

void RLEExpand(char far *source, char far *dest)
{
	unsigned char *src = (unsigned char *)source;
	unsigned char *dst = (unsigned char *)dest;
	Sint32 remaining;
	unsigned count = 1;

	memcpy(&remaining, src, 4);
	src += 4;

	for (;;)
	{
		remaining -= (Sint32)count;
		if (remaining < 0)
			break;
		count = *src++;
		if (count >= 0x80)
		{
			count -= 0x7F;
			memcpy(dst, src, count);
			src += count;
			dst += count;
		}
		else
		{
			unsigned char b;
			count += 3;
			b = *src++;
			memset(dst, b, count);
			dst += count;
		}
	}
}

/* RLEW (word-level) codec: exact-width port of the fenced IDLIBC.C
   versions -- DOS 'unsigned' is 16 bits, MSVC's is 32 */

#define K13_RLEWTAG 0xFEFE

void RLEWExpand(unsigned far *source, unsigned far *dest)
{
	Uint16 *src = (Uint16 *)source;
	Uint16 *dst = (Uint16 *)dest;
	Uint16 *end;
	Sint32 length;
	Uint16 value, count, i;

	memcpy(&length, src, 4);
	end = dst + length / 2;
	src += 2; /* skip length words */

	do
	{
		value = *src++;
		if (value != K13_RLEWTAG)
		{
			*dst++ = value;
		}
		else
		{
			count = *src++;
			value = *src++;
			for (i = 1; i <= count; i++)
				*dst++ = value;
		}
	} while (dst < end);
}

long RLEWCompress(unsigned far *source, long length, unsigned far *dest)
{
	Uint16 *src = (Uint16 *)source;
	Uint16 *dst = (Uint16 *)dest;
	Uint16 *start = dst, *end;
	long complength;
	Uint16 value, count, i;

	dst += 2; /* leave space for length value */
	end = src + (length + 1) / 2;

	do
	{
		count = 1;
		value = *src++;
		while (*src == value && src < end)
		{
			count++;
			src++;
		}
		if (count > 3 || value == K13_RLEWTAG)
		{
			*dst++ = K13_RLEWTAG;
			*dst++ = count;
			*dst++ = value;
		}
		else
		{
			for (i = 1; i <= count; i++)
				*dst++ = value;
		}
	} while (src < end);

	complength = 2 * (long)(dst - start);
	memcpy(start, &length, 4);
	return complength;
}

unsigned long RLECompress(char far *source, unsigned long Length,
                          char far *dest)
{
	(void)source; (void)Length; (void)dest;
	Quit("RLECompress: not used by Keen 1-3 game code");
	return 0;
}

/*
=============================================================================
	Replacements for K13_PORT-fenced IDLIBC.C functions
=============================================================================
*/

extern void far *lastparalloc; /* defined in IDLIBC.C */

void huge *paralloc(long size)
{
	/* arena blocks are already paragraph-aligned */
	void *temp = k13_farmalloc((unsigned long)size + 15);
	lastparalloc = temp;
	if (temp == NULL)
		Quit("Out of memory!  Try unloading your TSRs!");
	return temp;
}

unsigned long LoadFile(char *filename, char huge *buffer)
{
	FILE *f = fopen(filename, "rb");
	long length;

	if (getenv("K13_TRACE"))
	{
		fprintf(stderr, "K13 TRACE: LoadFile(%s) -> %s\n", filename,
		        f ? "ok" : "MISSING");
		fflush(stderr);
	}
	if (!f)
		return 0;
	fseek(f, 0, SEEK_END);
	length = ftell(f);
	fseek(f, 0, SEEK_SET);
	if (length > 0)
		fread(buffer, 1, (size_t)length, f);
	fclose(f);
	return (unsigned long)length;
}

void SaveFile(char *filename, char huge *buffer, long size)
{
	FILE *f = fopen(filename, "wb");

	if (!f)
		return;
	fwrite(buffer, 1, (size_t)size, f);
	fclose(f);
}

void ReadJoystick(int joynum, int *xcount, int *ycount)
{
	(void)joynum;
	*xcount = 500;
	*ycount = 500;
}

void FadeIn(void)
{
	/* staged palette loads, mirroring the original's INT 10h sequence
	   (it skips colors[2] on fade-in) */
	WaitVBL(1);
	memcpy(k13_palette, colors[0], 17);
	WaitVBL(8);
	memcpy(k13_palette, colors[1], 17);
	WaitVBL(8);
	memcpy(k13_palette, colors[3], 17);
	WaitVBL(1);
}

void FadeOut(void)
{
	WaitVBL(1);
	memcpy(k13_palette, colors[3], 17);
	WaitVBL(8);
	memcpy(k13_palette, colors[2], 17);
	WaitVBL(8);
	memcpy(k13_palette, colors[1], 17);
	WaitVBL(8);
	memcpy(k13_palette, colors[0], 17);
	WaitVBL(1);
}

/*
=============================================================================
	LoadGraphics: portable port of the fenced IDLIBC.C original.

	EGAHEAD   = grheadtype + pictable (picinfoStart) + spritetable
	            (sprinfoStart), kept resident in the arena
	EGALATCH  = 4 planes x latchsize bytes -> EGA memory at seg A700
	EGASPRIT  = 5 planes x spritesize bytes -> sprite plane buffers,
	            plus the three 2/4/6-pixel pre-shifted copies the DOS
	            code builds with inline asm (ported below bit-exactly)
=============================================================================
*/

extern spritetype image, huge *spritetable; /* defined in IDLIBC.C */
extern pictype huge *pictable;
extern int numchars, numtiles, numpics, numsprites;
extern void huge *charptr, huge *tileptr, huge *picptr;
extern void _seg *egasprites[5];

/* far-pointer-shaped 32-bit file offset -> linear byte offset */
static Uint32 k13_farval_to_linear(Uint32 v)
{
	return ((v >> 16) << 4) + (v & 0xFFFF);
}

/* shift a row right by one pixel-bit; carry_in supplies the new MSB */
static void k13_shift_row_1bit(Uint8 *row, unsigned width, unsigned carry_in)
{
	unsigned j, carry = carry_in & 1;
	for (j = 0; j < width; j++)
	{
		unsigned newcarry = row[j] & 1;
		row[j] = (Uint8)((carry << 7) | (row[j] >> 1));
		carry = newcarry;
	}
}

void LoadGraphics(void)
{
	long spriteplanesize;
	int i, plane, c;
	boolean compression;
	grheadtype *grhead;
	Uint8 *latchbuffer, *spritebuffer;
	void *latchstart, *spritestart;
	char filename[13];

	int trace = getenv("K13_TRACE") != NULL;

	k13_install_crash_filter();
#define K13_TR(msg)                                     \
	do                                                  \
	{                                                   \
		if (trace)                                      \
		{                                               \
			fprintf(stderr, "K13 TRACE: %s\n", msg);    \
			fflush(stderr);                             \
		}                                               \
	} while (0)

	if (!k13_ylookup_ready)
		k13_init_ylookup();

	strcpy(filename, "EGAHEAD.");
	strcat(filename, _extension);
	grhead = (grheadtype *)bloadin(filename);
	K13_TR("EGAHEAD loaded");
	compression = grhead->compression;
	numchars = grhead->numTile8s;
	numtiles = grhead->numTile16s;
	numpics = grhead->numPics;
	numsprites = grhead->numSprites;
	/* MY_FP(FP_SEG(grhead)+start/16, FP_OFF(grhead)): paragraph-floored
	   byte offset from the (paragraph-aligned) header base */
	spritetable = (spritetype *)((Uint8 *)grhead +
	                             ((Uint32)grhead->sprinfoStart & ~0xFu));
	pictable = (pictype *)((Uint8 *)grhead +
	                       ((Uint32)grhead->picinfoStart & ~0xFu));

	spriteplanesize = 0;
	for (i = 0; i < grhead->numSprites * 4; i++)
		spriteplanesize += spritetable[i].width * spritetable[i].height;
	for (i = 0; i < 5; i++)
	{
		egasprites[i] = paralloc(spriteplanesize);
		k13_sprplane[i] = (Uint8 *)egasprites[i];
	}

	strcpy(filename, "EGALATCH.");
	strcat(filename, _extension);
#ifdef USE_LZW
	latchbuffer = compression ? (Uint8 *)bloadinLZW(filename)
	                          : (Uint8 *)bloadin(filename);
#else
	(void)compression;
	latchbuffer = (Uint8 *)bloadin(filename);
#endif
	latchstart = lastparalloc;
	K13_TR("EGALATCH loaded");

	/* latch data -> EGA memory at segment A700, one plane at a time */
	for (i = 0; i < 4; i++)
		memcpy(k13_ega[i] + 0x7000,
		       latchbuffer + (((Uint32)grhead->latchsize * i) & ~0xFu),
		       (size_t)grhead->latchsize);

	/* plane-relative offsets (seg A700 = plane byte 0x7000) */
	k13_charoff = 0x7000u + ((Uint32)grhead->offTile8s & ~0xFu);
	k13_tileoff = 0x7000u + ((Uint32)grhead->offTile16s & ~0xFu);
	k13_picoff = 0x7000u + ((Uint32)grhead->offPics & ~0xFu);
	charptr = k13_mkfp(0xA700 + (unsigned)(grhead->offTile8s / 16), 0);
	tileptr = k13_mkfp(0xA700 + (unsigned)(grhead->offTile16s / 16), 0);
	picptr = k13_mkfp(0xA700 + (unsigned)(grhead->offPics / 16), 0);

	farfree(latchstart);

	if (trace)
	{
		/* glyph sanity: dump plane-0 bitmaps of tile8 'm' and 'w' */
		int n, r, b;
		for (n = 109; n <= 119; n += 10)
		{
			fprintf(stderr, "K13 TILE8 %d:\n", n);
			for (r = 0; r < 8; r++)
			{
				char row[9];
				Uint8 v = k13_ega[0][k13_charoff + (Uint32)n * 8 + r];
				for (b = 0; b < 8; b++)
					row[b] = (v & (0x80 >> b)) ? '#' : '.';
				row[8] = 0;
				fprintf(stderr, "  %s\n", row);
			}
		}
		fflush(stderr);
	}

	k13_border = 3; /* dark cyan, as the original sets via INT 10h */

	K13_TR("drawing ONE MOMENT pic");
	DrawPic(15, 76, ONEMOMENPIC);

	strcpy(filename, "EGASPRIT.");
	strcat(filename, _extension);
#ifdef USE_LZW
	spritebuffer = compression ? (Uint8 *)bloadinLZW(filename)
	                           : (Uint8 *)bloadin(filename);
#else
	spritebuffer = (Uint8 *)bloadin(filename);
#endif
	spritestart = lastparalloc;
	K13_TR("EGASPRIT loaded");

	{
		Uint32 destoff = 0;

		for (i = 0; i < numsprites; i++)
		{
			spritetype *ent = &spritetable[i * 4];
			Uint32 srcoff = k13_farval_to_linear(ent[0].shapeptr);
			Uint32 size0 = (Uint32)(ent[0].width * ent[0].height);

			/* unshifted copy into the five sprite planes */
			ent[0].shapeptr = destoff;
			for (plane = 0; plane < 5; plane++)
				memcpy(k13_sprplane[plane] + destoff,
				       spritebuffer +
				           (((Uint32)grhead->spritesize * plane) & ~0xFu) +
				           srcoff,
				       size0);
			destoff += size0;

			/* build the 2/4/6-pixel shifted copies exactly like the DOS
			   asm: append the edge byte (0x00 color / 0xFF mask), then
			   two single-bit right shifts per successive copy */
			for (c = 1; c < 4; c++)
			{
				Uint32 prevoff = ent[c - 1].shapeptr;
				unsigned wprev = (unsigned)ent[c - 1].width;
				unsigned wnew = (unsigned)ent[c].width;
				unsigned h = (unsigned)ent[c].height;
				unsigned row;

				ent[c].shapeptr = destoff;
				for (plane = 0; plane < 5; plane++)
				{
					Uint8 extra = (plane == 4) ? 0xFF : 0x00;
					const Uint8 *srcp = k13_sprplane[plane] + prevoff;
					Uint8 *dstp = k13_sprplane[plane] + destoff;

					for (row = 0; row < h; row++)
					{
						memcpy(dstp, srcp, wprev);
						if (wnew > wprev)
							memset(dstp + wprev, extra, wnew - wprev);
						k13_shift_row_1bit(dstp, wnew, extra & 1);
						k13_shift_row_1bit(dstp, wnew, extra & 1);
						srcp += wprev;
						dstp += wnew;
					}
				}
				destoff += (Uint32)(wnew * h);
			}
		}
	}

	K13_TR("sprite copies built");
	farfree(spritestart);
}

/*
=============================================================================
	IDASM.ASM draw routines (byte-exact plane copies)
	x is in bytes, y in lines; the current page comes from screenseg
	(VidRefresh swaps it to the back page while composing a frame)
=============================================================================
*/

void DrawChar(int x, int y, int charnum)
{
	Uint32 dst = k13_drawbase() + k13_ylookup[y & 511] + (unsigned)x;
	Uint32 src = k13_charoff + (Uint32)charnum * 8;
	int row, p;

	for (row = 0; row < 8; row++)
	{
		for (p = 0; p < 4; p++)
			k13_ega[p][(dst) & 0xFFFF] = k13_ega[p][(src) & 0xFFFF];
		dst += SCREENWIDTH;
		src++;
	}
}

/* animation table selected by VidRefresh each frame (asm: [animtable]) */
static unsigned *k13_cur_anim = tile_anim0;

void DrawTile(int x, int y, int tilenum)
{
	Uint32 dst, src;
	int row, p;

	dst = k13_drawbase() + k13_ylookup[y & 511] + (unsigned)x;

	if (tilenum < 0)
	{
		/* masked foreground tile: color image at (t & 0x7FFF) << 5, its
		   mask stored as the following tile slot (+0x20); no animation */
		src = k13_tileoff + (Uint32)((tilenum & 0x7FFF) << 5);
		for (row = 0; row < 16; row++)
		{
			int col;
			for (col = 0; col < 2; col++)
			{
				for (p = 0; p < 4; p++)
				{
					/* the asm reads color AND mask from plane p (read
					   map select), mask living in the next tile slot */
					Uint32 d = (dst + col) & 0xFFFF;
					Uint8 mask = k13_ega[p][(src + 0x20 + col) & 0xFFFF];
					Uint8 color = k13_ega[p][(src + col) & 0xFFFF];
					k13_ega[p][d] = (Uint8)((k13_ega[p][d] & mask) |
					                        (color & (Uint8)~mask));
				}
			}
			dst += SCREENWIDTH;
			src += 2;
		}
		return;
	}

	src = k13_tileoff + k13_cur_anim[tilenum];
	for (row = 0; row < 16; row++)
	{
		for (p = 0; p < 4; p++)
		{
			k13_ega[p][dst & 0xFFFF] = k13_ega[p][src & 0xFFFF];
			k13_ega[p][(dst + 1) & 0xFFFF] = k13_ega[p][(src + 1) & 0xFFFF];
		}
		dst += SCREENWIDTH;
		src += 2;
	}
}

void DrawPic(int x, int y, int picnum)
{
	pictype *pic = &pictable[picnum];
	Uint32 src = k13_picoff + k13_farval_to_linear(pic->shapeptr);
	Uint32 dst = k13_drawbase() + k13_ylookup[y & 511] + (unsigned)x;
	int w = pic->width, h = pic->height;
	int row, col, p;

	for (row = 0; row < h; row++)
	{
		for (col = 0; col < w; col++)
			for (p = 0; p < 4; p++)
				k13_ega[p][(dst + col) & 0xFFFF] =
					k13_ega[p][(src + col) & 0xFFFF];
		dst += SCREENWIDTH;
		src += (Uint32)w;
	}
}

void DrawSprite(int xcoord, int ycoord, int spritenum)
{
	spritetype *spr = &spritetable[spritenum];
	Uint32 src = (Uint32)(Uint16)spr->shapeptr;
	Uint32 dst = k13_drawbase() + k13_ylookup[ycoord & 511] + (unsigned)xcoord;
	int w = spr->width, h = spr->height;
	int row, col, p;

	for (row = 0; row < h; row++)
	{
		for (col = 0; col < w; col++)
		{
			Uint8 mask = k13_sprplane[4][src + col];
			for (p = 0; p < 4; p++)
			{
				Uint32 d = (dst + col) & 0xFFFF;
				k13_ega[p][d] = (Uint8)((k13_ega[p][d] & mask) |
				                        k13_sprplane[p][src + col]);
			}
		}
		dst += SCREENWIDTH;
		src += (Uint32)w;
	}
}

/*
=============================================================================
	Frame presentation: PPM dump verification until SDL lands.
	K13_DUMP=1 dumps the first frames of each run to k13_frame_NNN.ppm
=============================================================================
*/

static void k13_dump_screen_at(const char *path, Uint32 start);

static void k13_dump_screen(const char *path)
{
	/* CRTC start address (regs 0xC/0xD) picks the visible page */
	Uint32 start = ((Uint32)k13_crtc_reg[0x0C] << 8) | k13_crtc_reg[0x0D];
	k13_dump_screen_at(path, start);
}

static void k13_dump_screen_at(const char *path, Uint32 start)
{
	FILE *f = fopen(path, "wb");
	int x, y, bit, p;

	if (!f)
		return;
	fprintf(f, "P6\n320 200\n255\n");
	for (y = 0; y < 200; y++)
	{
		Uint32 rowbase = start + (Uint32)y * SCREENWIDTH;
		for (x = 0; x < 40; x++)
		{
			Uint8 b[4];
			for (p = 0; p < 4; p++)
				b[p] = k13_ega[p][(rowbase + x) & 0xFFFF];
			for (bit = 7; bit >= 0; bit--)
			{
				int idx = ((b[0] >> bit) & 1) | (((b[1] >> bit) & 1) << 1) |
				          (((b[2] >> bit) & 1) << 2) |
				          (((b[3] >> bit) & 1) << 3);
				Uint8 ega = k13_palette[idx];
				Uint8 rgb[3];
				rgb[0] = (Uint8)((((ega >> 2) & 1) * 0xAA) +
				                 (((ega >> 5) & 1) * 0x55));
				rgb[1] = (Uint8)((((ega >> 1) & 1) * 0xAA) +
				                 (((ega >> 4) & 1) * 0x55));
				rgb[2] = (Uint8)(((ega & 1) * 0xAA) +
				                 (((ega >> 3) & 1) * 0x55));
				fwrite(rgb, 1, 3, f);
			}
		}
	}
	fclose(f);
}

static void k13_maybe_dump(void)
{
	static int present_no, dumped;
	char path[64];

	present_no++;
	if (!getenv("K13_DUMP") || dumped >= 200 || (present_no & 63) != 1)
		return;
	sprintf(path, "k13_frame_%03d.ppm", dumped);
	k13_dump_screen(path);
	if (getenv("K13_DUMP_PAGES"))
	{
		sprintf(path, "k13_page0_%03d.ppm", dumped);
		k13_dump_screen_at(path, 0x604);
		sprintf(path, "k13_page1_%03d.ppm", dumped);
		k13_dump_screen_at(path, 0x3604);
	}
	dumped++;
}

/* EGA palette register value -> ARGB (bits 0-2 primary BGR, 3-5 secondary) */
static Uint32 k13_ega_rgb(Uint8 v)
{
	Uint8 r = (Uint8)((((v >> 2) & 1) * 0xAA) + (((v >> 5) & 1) * 0x55));
	Uint8 g = (Uint8)((((v >> 1) & 1) * 0xAA) + (((v >> 4) & 1) * 0x55));
	Uint8 b = (Uint8)(((v & 1) * 0xAA) + (((v >> 3) & 1) * 0x55));
	return 0xFF000000u | ((Uint32)r << 16) | ((Uint32)g << 8) | b;
}

static void k13_present(void); /* defined at end of file (needs SDL state) */

/*
=============================================================================
	SDL2 presentation, input and timing.  Without SDL the build stays
	headless (PPM dumps only) for scripted verification runs.
=============================================================================
*/

#ifdef K13_WITH_SDL

static SDL_Window *k13_window;
static SDL_Renderer *k13_renderer;
static SDL_Texture *k13_texture;
static SDL_Texture *k13_texture_wide;
static SDL_Texture *k13_target;
static Uint32 k13_timebase;

/* SDL scancode -> DOS (set 1) scancode; index = SDL_Scancode */
static const Uint8 k13_scanmap[SDL_NUM_SCANCODES] = {
	[SDL_SCANCODE_A] = 0x1E, [SDL_SCANCODE_B] = 0x30,
	[SDL_SCANCODE_C] = 0x2E, [SDL_SCANCODE_D] = 0x20,
	[SDL_SCANCODE_E] = 0x12, [SDL_SCANCODE_F] = 0x21,
	[SDL_SCANCODE_G] = 0x22, [SDL_SCANCODE_H] = 0x23,
	[SDL_SCANCODE_I] = 0x17, [SDL_SCANCODE_J] = 0x24,
	[SDL_SCANCODE_K] = 0x25, [SDL_SCANCODE_L] = 0x26,
	[SDL_SCANCODE_M] = 0x32, [SDL_SCANCODE_N] = 0x31,
	[SDL_SCANCODE_O] = 0x18, [SDL_SCANCODE_P] = 0x19,
	[SDL_SCANCODE_Q] = 0x10, [SDL_SCANCODE_R] = 0x13,
	[SDL_SCANCODE_S] = 0x1F, [SDL_SCANCODE_T] = 0x14,
	[SDL_SCANCODE_U] = 0x16, [SDL_SCANCODE_V] = 0x2F,
	[SDL_SCANCODE_W] = 0x11, [SDL_SCANCODE_X] = 0x2D,
	[SDL_SCANCODE_Y] = 0x15, [SDL_SCANCODE_Z] = 0x2C,
	[SDL_SCANCODE_1] = 0x02, [SDL_SCANCODE_2] = 0x03,
	[SDL_SCANCODE_3] = 0x04, [SDL_SCANCODE_4] = 0x05,
	[SDL_SCANCODE_5] = 0x06, [SDL_SCANCODE_6] = 0x07,
	[SDL_SCANCODE_7] = 0x08, [SDL_SCANCODE_8] = 0x09,
	[SDL_SCANCODE_9] = 0x0A, [SDL_SCANCODE_0] = 0x0B,
	[SDL_SCANCODE_RETURN] = 0x1C, [SDL_SCANCODE_ESCAPE] = 0x01,
	[SDL_SCANCODE_BACKSPACE] = 0x0E, [SDL_SCANCODE_TAB] = 0x0F,
	[SDL_SCANCODE_SPACE] = 0x39, [SDL_SCANCODE_MINUS] = 0x0C,
	[SDL_SCANCODE_EQUALS] = 0x0D, [SDL_SCANCODE_LEFTBRACKET] = 0x1A,
	[SDL_SCANCODE_RIGHTBRACKET] = 0x1B, [SDL_SCANCODE_BACKSLASH] = 0x2B,
	[SDL_SCANCODE_SEMICOLON] = 0x27, [SDL_SCANCODE_APOSTROPHE] = 0x28,
	[SDL_SCANCODE_GRAVE] = 0x29, [SDL_SCANCODE_COMMA] = 0x33,
	[SDL_SCANCODE_PERIOD] = 0x34, [SDL_SCANCODE_SLASH] = 0x35,
	[SDL_SCANCODE_CAPSLOCK] = 0x3A,
	[SDL_SCANCODE_F1] = 0x3B, [SDL_SCANCODE_F2] = 0x3C,
	[SDL_SCANCODE_F3] = 0x3D, [SDL_SCANCODE_F4] = 0x3E,
	[SDL_SCANCODE_F5] = 0x3F, [SDL_SCANCODE_F6] = 0x40,
	[SDL_SCANCODE_F7] = 0x41, [SDL_SCANCODE_F8] = 0x42,
	[SDL_SCANCODE_F9] = 0x43, [SDL_SCANCODE_F10] = 0x44,
	[SDL_SCANCODE_F11] = 0x57, [SDL_SCANCODE_F12] = 0x58,
	[SDL_SCANCODE_HOME] = 0x47, [SDL_SCANCODE_UP] = 0x48,
	[SDL_SCANCODE_PAGEUP] = 0x49, [SDL_SCANCODE_LEFT] = 0x4B,
	[SDL_SCANCODE_RIGHT] = 0x4D, [SDL_SCANCODE_END] = 0x4F,
	[SDL_SCANCODE_DOWN] = 0x50, [SDL_SCANCODE_PAGEDOWN] = 0x51,
	[SDL_SCANCODE_INSERT] = 0x52, [SDL_SCANCODE_DELETE] = 0x53,
	[SDL_SCANCODE_LCTRL] = 0x1D, [SDL_SCANCODE_RCTRL] = 0x1D,
	[SDL_SCANCODE_LSHIFT] = 0x2A, [SDL_SCANCODE_RSHIFT] = 0x36,
	[SDL_SCANCODE_LALT] = 0x38, [SDL_SCANCODE_RALT] = 0x38,
	[SDL_SCANCODE_KP_ENTER] = 0x1C,
	/* keypad shares scancodes with arrows/nav on DOS keyboards */
	[SDL_SCANCODE_KP_7] = 0x47, [SDL_SCANCODE_KP_8] = 0x48,
	[SDL_SCANCODE_KP_9] = 0x49, [SDL_SCANCODE_KP_MINUS] = 0x4A,
	[SDL_SCANCODE_KP_4] = 0x4B, [SDL_SCANCODE_KP_5] = 0x4C,
	[SDL_SCANCODE_KP_6] = 0x4D, [SDL_SCANCODE_KP_PLUS] = 0x4E,
	[SDL_SCANCODE_KP_1] = 0x4F, [SDL_SCANCODE_KP_2] = 0x50,
	[SDL_SCANCODE_KP_3] = 0x51, [SDL_SCANCODE_KP_0] = 0x52,
	[SDL_SCANCODE_KP_PERIOD] = 0x53,
};

/* the game's own scan->ascii table (IDASM.ASM 'scanascii', v1.31):
 * arrows/home/end report ascii 1, modifiers and F-keys report 0 */
static const Uint8 k13_scanascii[128] = {
	0, 27, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 8, 9,
	113, 119, 101, 114, 116, 121, 117, 105, 111, 112, 91, 93, 13, 0,
	97, 115, 100, 102, 103, 104, 106, 107, 108, 59, 39, 96, 0, 92,
	122, 120, 99, 118, 98, 110, 109, 44, 46, 47, 0, 42, 0, 32, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,      /* 0x3B-0x45: F1-F10, num */
	0,                                     /* 0x46 scroll lock */
	1, 1, 1, 45, 1, 1, 1, 43, 1, 1, 1, 1, 1, /* 0x47-0x53 keypad */
	/* rest zero */
};

/*
 * DOS INT 8 equivalent.  StartupSound reprograms the PIT to divisor 0x2000,
 * so the interrupt fires at 1193182/8192 = 145.65Hz, and UpdateSPKR both
 * increments timecount and steps the speaker sequencer ONCE PER INTERRUPT.
 * Deltas are ADDED so game code that saves/restores or rewinds timecount
 * (e.g. DoFkeys) keeps working.
 */

/* speaker sequencer state (the asm's SndPtr / pause* / port 61h latch) */
static volatile Uint32 k13_sndptr;      /* byte offset into SoundData; 0=off */
static volatile Uint16 k13_pit_divisor; /* PIT channel 2 divisor of the tone */
static volatile int k13_spk_on;
static Uint32 k13_pause_sndptr;
static int k13_pause_priority;

static void k13_sound_tick(void)
{
	Uint32 p = k13_sndptr;
	Uint16 freq;

	if (!p || !SoundData)
	{
		k13_spk_on = 0;
		return;
	}
	memcpy(&freq, SoundData + p, 2);
	k13_sndptr = p + 2;
	if (freq == 0)
	{
		k13_spk_on = 0; /* rest: speaker off, keep sequencing */
	}
	else if (freq == 0xFFFF)
	{
		k13_sndptr = 0; /* end of sound */
		SndPriority = 0;
		k13_spk_on = 0;
	}
	else if (soundmode)
	{
		static int announced;
		k13_pit_divisor = freq;
		k13_spk_on = 1;
		if (!announced && getenv("K13_TRACE"))
		{
			announced = 1;
			fprintf(stderr, "K13 TP: first tone, divisor %u (%.0f Hz)\n",
			        (unsigned)freq, 1193182.0 / freq);
			fflush(stderr);
		}
	}
	else
	{
		k13_spk_on = 0;
	}
}

static Uint32 k13_timer_cb(Uint32 interval, void *param)
{
	static Uint64 prev;
	Uint64 now = SDL_GetTicks() - k13_timebase;
	/* ticks = ms * 1193182 / (8192 * 1000) */
	Uint64 want = (now * 1193182u) / 8192000u;
	Uint64 n;

	(void)param;
	for (n = prev; n < want; n++)
	{
		k13_ticks_real++;
		inttime++;
		k13_sound_tick();
	}
	prev = want;
	return interval;
}

#include "dbopl.h"

/* ---- boot-time table rip (the "recompiler") ----
 * The reconstruction links id's own data into the exe: tile attributes,
 * the DOS exit screen, and (Keen 2/3) the sounds and text pages.  None of
 * that may ship, so the port's arrays (K13TABLE.C) start zeroed and this
 * fills them from the player's KEEN?.EXE at every boot: UNLZEXE the
 * packed exe in memory, copy the v1.31 regions (v1.1 fallback for ep 1),
 * and sanity-check the result -- a faithful C port of tools/rip_keen1.py,
 * which itself replicates the reconstruction's STATIC/rip.bat flow. */

extern int nexttile[], intile[], northwall[], eastwall[], southwall[],
    westwall[];
extern char endscreen[];
#if (EPISODE != 1)
extern char _sounds[], endtext[], helptext[], previews[], storytxt[];
#endif

typedef struct
{
	Uint32 off, size;
} K13Rip;

/* LZEXE 0.91 unpack; returns malloc'd load module (no header), or NULL */
static Uint8 *k13_unlzexe(const Uint8 *d, size_t dlen, size_t *outlen)
{
	Uint16 hdrsize, cs;
	Uint32 stub, src, pos;
	Uint16 compsize;
	Uint8 *out;
	size_t olen = 0, ocap = 1 << 20;
	Uint16 bitbuf;
	int bitcnt;

	if (dlen < 0x20 || d[0] != 'M' || d[1] != 'Z')
		return NULL;
	hdrsize = (Uint16)(d[8] | (d[9] << 8));
	cs = (Uint16)(d[0x16] | (d[0x17] << 8));
	if (memcmp(d + 0x1C, "LZ91", 4) != 0)
	{
		/* already unpacked: the load module starts after its header */
		size_t mod = (size_t)hdrsize << 4;
		if (mod >= dlen)
			return NULL;
		out = (Uint8 *)malloc(dlen - mod);
		if (!out)
			return NULL;
		memcpy(out, d + mod, dlen - mod);
		*outlen = dlen - mod;
		return out;
	}
	stub = ((Uint32)cs + hdrsize) << 4;
	if (stub + 16 > dlen)
		return NULL;
	compsize = (Uint16)(d[stub + 8] | (d[stub + 9] << 8));
	src = ((Uint32)cs - compsize + hdrsize) << 4;
	out = (Uint8 *)malloc(ocap);
	if (!out)
		return NULL;

	pos = src;
#define K13_GETW() (pos + 1 < dlen ? (Uint16)(d[pos] | (d[pos + 1] << 8)) : 0), pos += 2
	bitbuf = (Uint16)(d[pos] | (d[pos + 1] << 8));
	pos += 2;
	bitcnt = 16;
#define K13_GETBIT(b)                                        	do                                                       	{                                                        		(b) = bitbuf & 1;                                    		bitbuf >>= 1;                                        		if (--bitcnt == 0)                                   		{                                                    			bitbuf = (Uint16)(d[pos] | (d[pos + 1] << 8));   			pos += 2;                                        			bitcnt = 16;                                     		}                                                    	} while (0)

	for (;;)
	{
		int b, len;
		Sint32 span;

		if (pos + 1 >= dlen)
			break; /* corrupt input: stop rather than overrun */
		K13_GETBIT(b);
		if (b)
		{
			if (olen == ocap)
			{
				ocap *= 2;
				out = (Uint8 *)realloc(out, ocap);
			}
			out[olen++] = d[pos++];
			continue;
		}
		K13_GETBIT(b);
		if (!b)
		{
			int b1, b2;
			K13_GETBIT(b1);
			K13_GETBIT(b2);
			len = ((b1 << 1) | b2) + 2;
			span = d[pos++] | 0xFF00;
		}
		else
		{
			Uint8 lo = d[pos++];
			Uint8 hi = d[pos++];
			span = lo | (((hi & ~0x07) << 5) | 0xE000);
			len = (hi & 0x07) + 2;
			if (len == 2)
			{
				len = d[pos++];
				if (len == 0)
					break; /* end of compressed data */
				if (len == 1)
					continue; /* segment change marker */
				len++;
			}
		}
		span -= 0x10000; /* negative displacement */
		while (len--)
		{
			if (olen == ocap)
			{
				ocap *= 2;
				out = (Uint8 *)realloc(out, ocap);
			}
			if ((Sint64)olen + span < 0)
				break;
			out[olen] = out[olen + span];
			olen++;
		}
	}
#undef K13_GETBIT
#undef K13_GETW
	*outlen = olen;
	return out;
}

static int k13_looks_like_tileinfo(const Uint8 *b, Uint32 size)
{
	Uint32 n = size / 12, i, small = 0, total;

	total = n * 4; /* the four wall blocks */
	for (i = 0; i < total; i++)
	{
		Sint16 v = (Sint16)(b[(2 * n + i) * 2] | (b[(2 * n + i) * 2 + 1] << 8));
		if (v >= 0 && v <= 8)
			small++;
	}
	return total > 0 && small * 100 > total * 95;
}

static int k13_looks_like_endscrn(const Uint8 *b, Uint32 size)
{
	Uint32 i, printable = 0, total = 0;

	if (size < 7 + 4000)
		return 0;
	for (i = 7; i < 7 + 4000; i += 2, total++)
	{
		Uint8 c = b[i];
		if (c == 0 || (c >= 0x20 && c < 0x7F) || c >= 0xB0)
			printable++;
	}
	return printable * 100 > total * 90;
}

static void k13_rip_fail(const char *why)
{
	char msg[512];

	snprintf(msg, sizeof(msg),
	         "Could not read the game's data tables from KEEN%d.EXE.\n\n"
	         "%s\n\n"
	         "This port needs the original v1.31 (or v1.1) executable in\n"
	         "the game folder next to the level and graphics files.",
	         EPISODE, why);
	fprintf(stderr, "K13 RIP: %s\n", msg);
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Missing game data",
	                         msg, NULL);
	exit(1);
}

void K13_RipTables(void)
{
	/* v1.31 layouts (from the reconstruction's STATIC/ripck?.pat) */
#if (EPISODE == 1)
	static const K13Rip tinf_sets[2] = {{0x130F8, 0x1CA4}, {0x131F8, 0x1CA4}};
	static const K13Rip escr_sets[2] = {{0x12080, 0xFA8}, {0x12180, 0xFA8}};
	static const int nsets = 2;
	static const char *exename = "KEEN1.EXE";
#elif (EPISODE == 2)
	static const K13Rip tinf_sets[1] = {{0x17828, 0x204C}};
	static const K13Rip escr_sets[1] = {{0x11780, 0xFA8}};
	static const int nsets = 1;
	static const char *exename = "KEEN2.EXE";
	static const K13Rip r_sounds = {0x12730, 0x310A};
	static const K13Rip r_endtext = {0x15840, 0x37C};
	static const K13Rip r_helptext = {0x15BC0, 0x7DE};
	static const K13Rip r_previews = {0x163A0, 0x715};
	static const K13Rip r_storytxt = {0x16AC0, 0xC98};
#else
	static const K13Rip tinf_sets[1] = {{0x198C8, 0x2184}};
	static const K13Rip escr_sets[1] = {{0x12AC0, 0xFA8}};
	static const int nsets = 1;
	static const char *exename = "KEEN3.EXE";
	static const K13Rip r_sounds = {0x13A70, 0x3F60};
	static const K13Rip r_helptext = {0x179D0, 0x7CC};
	static const K13Rip r_endtext = {0x181A0, 0x33C};
	static const K13Rip r_previews = {0x184E0, 0x6E4};
	static const K13Rip r_storytxt = {0x18BD0, 0xC23};
#endif
	FILE *f;
	Uint8 *raw, *mod;
	long rawlen;
	size_t modlen;
	int si, found = -1;

	f = fopen(exename, "rb");
	if (!f)
		k13_rip_fail("The executable was not found.");
	fseek(f, 0, SEEK_END);
	rawlen = ftell(f);
	fseek(f, 0, SEEK_SET);
	raw = (Uint8 *)malloc((size_t)rawlen);
	if (!raw || fread(raw, 1, (size_t)rawlen, f) != (size_t)rawlen)
		k13_rip_fail("The executable could not be read.");
	fclose(f);

	mod = k13_unlzexe(raw, (size_t)rawlen, &modlen);
	free(raw);
	if (!mod)
		k13_rip_fail("The executable is not a DOS MZ/LZEXE file.");

	for (si = 0; si < nsets; si++)
	{
		if (tinf_sets[si].off + tinf_sets[si].size <= modlen &&
		    escr_sets[si].off + escr_sets[si].size <= modlen &&
		    k13_looks_like_tileinfo(mod + tinf_sets[si].off,
		                            tinf_sets[si].size) &&
		    k13_looks_like_endscrn(mod + escr_sets[si].off,
		                           escr_sets[si].size))
		{
			found = si;
			break;
		}
	}
	if (found < 0)
	{
		free(mod);
		k13_rip_fail("The executable's layout was not recognized\n"
		             "(a modified or unsupported version?).");
	}

	/* tile attributes: 6 blocks of int16, widened to the port's ints */
	{
		const Uint8 *t = mod + tinf_sets[found].off;
		Uint32 n = tinf_sets[found].size / 12, i;
		int *dst[6];

		dst[0] = nexttile;
		dst[1] = intile;
		dst[2] = northwall;
		dst[3] = eastwall;
		dst[4] = southwall;
		dst[5] = westwall;
		for (i = 0; i < n * 6; i++)
			dst[i / n][i % n] =
				(Sint16)(t[i * 2] | (t[i * 2 + 1] << 8));
	}
	memcpy(endscreen, mod + escr_sets[found].off, escr_sets[found].size);
#if (EPISODE != 1)
	memcpy(_sounds, mod + r_sounds.off, r_sounds.size);
	memcpy(endtext, mod + r_endtext.off, r_endtext.size);
	memcpy(helptext, mod + r_helptext.off, r_helptext.size);
	memcpy(previews, mod + r_previews.off, r_previews.size);
	memcpy(storytxt, mod + r_storytxt.off, r_storytxt.size);
#endif
	free(mod);
}

/* ---- Galaxy music (Keen 4-6 IMF tracks through an embedded OPL) ----
 * Keen 1-3 shipped with no music at all, so this is pure addition: raw
 * IMF register streams extracted from the player's own Keen 4/5 data
 * (sfx46/k4mNN.imf, k5mNN.imf) are played at the id engine's 560Hz music
 * rate through dbopl, mixed under whatever sound effects mode is active.
 * Purely presentation: no game code, state or timing is touched. */
int k13_galaxymus;                    /* config toggle */
static int k13_mus_avail;             /* the episode's map track exists */
static Uint8 *k13_mus_data;           /* current track (malloc'd) */
static Uint32 k13_mus_len, k13_mus_pos;
static Chip k13_mus_chip;
static Sint32 k13_mus_wait;           /* samples until next event batch */
static Sint64 k13_mus_acc;            /* fractional sample accumulator */
static Sint16 k13_mus_want = -2;      /* level whose track should play */
static Sint16 k13_mus_have = -2;      /* level whose track IS loaded */

/* Default assignments reuse each Galaxy game's OWN level-music tables:
 * Keen 1 (Mars) plays Keen 4's set, Keen 2 (the ship) Keen 5's, and
 * Keen 3 a Keen 5 rotation saving "Mars, the Bringer of War" for
 * Mortimer.  Index = level number, 0 = world map. */
#if (EPISODE == 1)
static const char *k13_mus_level[17] = {
	"k4m00", "k4m04", "k4m03", "k4m03", "k4m02", "k4m02", "k4m04",
	"k4m03", "k4m01", "k4m01", "k4m01", "k4m02", "k4m02", "k4m02",
	"k4m02", "k4m02", "k4m02"
};
#elif (EPISODE == 2)
static const char *k13_mus_level[17] = {
	"k5m11", "k5m05", "k5m07", "k5m09", "k5m10", "k5m09", "k5m10",
	"k5m09", "k5m10", "k5m09", "k5m10", "k5m03", "k5m13", "k5m04",
	"k5m12", "k5m02", "k5m06"
};
#else
static const char *k13_mus_level[17] = {
	"k5m08", "k5m00", "k5m01", "k5m02", "k5m03", "k5m04", "k5m05",
	"k5m06", "k5m07", "k5m09", "k5m10", "k5m00", "k5m01", "k5m02",
	"k5m03", "k5m06", "k5m13"
};
#endif

int K13_GalaxyMusAvail(void)
{
	return k13_mus_avail;
}

int K13_GetGalaxyMus(void)
{
	return k13_galaxymus && k13_mus_avail;
}

void K13_SetGalaxyMus(int on)
{
	k13_galaxymus = on ? 1 : 0;
}

static void k13_mus_chip_reset(void)
{
	static int tables_ready;

	if (!tables_ready)
	{
		/* without this the wave tables are all zeros: the synth runs
		   flawlessly and outputs perfect silence */
		DBOPL_InitTables();
		tables_ready = 1;
	}
	Chip__Chip(&k13_mus_chip);
	Chip__Setup(&k13_mus_chip, 48000);
	Chip__WriteReg(&k13_mus_chip, 1, 0x20);
	k13_mus_pos = 0;
	k13_mus_wait = 0;
	k13_mus_acc = 0;
}

/* mix `samples` of music into out (called from the audio callback) */
static void k13_mus_mix(Sint16 *out, int samples)
{
	static Bit32s buf[512 * 2];
	int n = 0;

	if (!k13_galaxymus || !k13_mus_data)
		return;
	while (n < samples)
	{
		int m, i;

		if (k13_mus_wait <= 0)
		{
			/* run register events until a nonzero delay */
			while (k13_mus_pos + 4 <= k13_mus_len)
			{
				Uint8 reg = k13_mus_data[k13_mus_pos];
				Uint8 val = k13_mus_data[k13_mus_pos + 1];
				Uint16 delay = (Uint16)(k13_mus_data[k13_mus_pos + 2] |
				               (k13_mus_data[k13_mus_pos + 3] << 8));

				k13_mus_pos += 4;
				Chip__WriteReg(&k13_mus_chip, reg, val);
				if (delay)
				{
					k13_mus_acc += (Sint64)delay * 48000;
					k13_mus_wait += (Sint32)(k13_mus_acc / 560);
					k13_mus_acc %= 560;
					break;
				}
			}
			if (k13_mus_pos + 4 > k13_mus_len)
			{
				k13_mus_chip_reset(); /* loop, like Galaxy does */
				if (k13_mus_wait <= 0)
					k13_mus_wait = 48; /* guard: empty track */
			}
		}
		m = samples - n;
		if (m > k13_mus_wait)
			m = k13_mus_wait;
		if (m > 512)
			m = 512;
		Chip__GenerateBlock2(&k13_mus_chip, m, buf);
		for (i = 0; i < m; i++)
		{
			/* same 2x scale as the sfx render, backed off a step so
			   effects still read over the music */
			Sint32 v = out[n + i] + ((2 * buf[i]) * 3) / 4;
			if (v > 32767)
				v = 32767;
			else if (v < -32768)
				v = -32768;
			out[n + i] = (Sint16)v;
		}
		k13_mus_wait -= m;
		n += m;
	}
}

/* level watcher: load the right track when the game moves (game thread) */
static SDL_AudioDeviceID k13_audiodev_fwd(void);

static void k13_mus_watch(void)
{
	extern Sint16 LevelNumber;
	Sint16 lv = (Sint16)(LevelNumber & 0xFF);
	char path[64];
	FILE *f;
	Uint8 *data;
	long flen;

	if (!k13_galaxymus || !k13_mus_avail)
		return;
	if (lv < 0 || lv > 16)
		lv = 0;
	k13_mus_want = lv;
	if (k13_mus_want == k13_mus_have)
		return;
	/* same file as the current track? then just keep playing */
	if (k13_mus_have >= 0 &&
	    !strcmp(k13_mus_level[k13_mus_have], k13_mus_level[lv]))
	{
		k13_mus_have = lv;
		return;
	}
	SDL_snprintf(path, sizeof(path), "sfx46/%s.imf", k13_mus_level[lv]);
	f = fopen(path, "rb");
	if (!f)
	{
		k13_mus_have = lv; /* missing track: silence, do not retry-spam */
		if (k13_audiodev_fwd())
			SDL_LockAudioDevice(k13_audiodev_fwd());
		free(k13_mus_data);
		k13_mus_data = NULL;
		if (k13_audiodev_fwd())
			SDL_UnlockAudioDevice(k13_audiodev_fwd());
		return;
	}
	fseek(f, 0, SEEK_END);
	flen = ftell(f);
	fseek(f, 0, SEEK_SET);
	data = (Uint8 *)malloc((size_t)flen);
	if (data)
		fread(data, 1, (size_t)flen, f);
	fclose(f);
	if (k13_audiodev_fwd())
		SDL_LockAudioDevice(k13_audiodev_fwd());
	free(k13_mus_data);
	k13_mus_data = data;
	k13_mus_len = data ? (Uint32)flen : 0;
	k13_mus_chip_reset();
	if (k13_audiodev_fwd())
		SDL_UnlockAudioDevice(k13_audiodev_fwd());
	k13_mus_have = lv;
}

/* ---- Galaxy SFX (Keen 4-6 AdLib sounds, pre-rendered to WAV) ----
 * The toggle swaps the audible output only: the PC speaker sequencer keeps
 * running exactly as vanilla (SndPriority, WaitEndSound timing, pause and
 * continue) so the simulation cannot tell the difference -- its square wave
 * is simply not synthesized.  Sounds with no 4-6 equivalent play nothing,
 * matching how sparse Galaxy's own effects are. */
int k13_galaxysfx;                     /* config toggle */
static int k13_gal_avail;              /* any WAV actually loaded */

typedef struct
{
	Sint16 snd;             /* 1-3 sound number (SNDSCK*.H order)      */
	const char *wav;        /* file in sfx46/, dumped by omnispeak     */
	Sint16 *data;           /* 48kHz mono S16, NULL if missing         */
	Uint32 len;             /* in samples */
} K13_GalSnd;

static K13_GalSnd k13_gal_map[] = {
	{1,  "k4g00"},  /* WLDWALK    -> KEENWALK0 (alternates with 1)  */
	{4,  "k4g00"},  /* KEENWALK   -> KEENWALK0                      */
	{30, "k4g01"},  /* KEENWLK2   -> KEENWALK1                      */
	{6,  "k4g02"},  /* KEENJUMP   -> KEENJUMP                       */
	{7,  "k4g03"},  /* KEENLAND   -> KEENLAND                       */
	{8,  "k4g23"},  /* KEENDIE    -> KEENDIE                        */
	{9,  "k4g08"},  /* GOTBONUS   -> GOTITEM                        */
	{10, "k4g09"},  /* GOTITEM    -> GOTSTUNNER (ammo/gear pickup)  */
	{11, "k4g31"},  /* GOTPART    -> COUNCILSAVE (mission jingle)   */
	{12, "k4g04"},  /* KEENFIRE   -> KEENSHOOT                      */
	{13, "k4g07"},  /* KEENPOGO   -> KEENPOGO                       */
	{15, "k4g13"},  /* LVLDONE    -> LEVELEXIT                      */
	{18, "k5g39"},  /* TELEPORT   -> MASTERTELE                     */
	{19, "k4g40"},  /* CHUNKSMASH -> FIREBALLLAND (projectile land) */
	{21, "k4g15"},  /* BUMPHEAD   -> KEENHITCEILING                 */
	{23, "k4g33"},  /* CANNONFIRE -> BERKELOIDTHROW (lobbed shot)   */
	{25, "k4g15"},  /* CLICK      -> KEENHITCEILING (Galaxy uses the
	                   head-bump click for switch flips too)        */
	{28, "k4g17"},  /* EXTRAMAN   -> GOTEXTRALIFE                   */
	{29, "k4g06"},  /* YORPBUMP   -> SLICEBUMP                      */
	{31, "k5g33"},  /* YORPBOP    -> AMPTONSTUN                     */
	{32, "k5g55"},  /* GETCARD    -> GOTKEYCARD                     */
	{33, "k5g18"},  /* DOOROPEN   -> OPENSECURITYDOOR               */
	{36, "k4g21"},  /* GUNCLICK   -> KEENOUTOFAMMO                  */
	{37, "k4g25"},  /* SHOTHIT    -> KEENSHOTHIT                    */
	{38, "k5g29"},  /* TANKFIRE   -> ENEMYSHOOT                     */
	{34, "k4g22"},  /* YORPSCREAM -> SKYPESTSQUISH                  */
	{35, "k5g45"},  /* GARGSCREAM -> BARKSHOTDIE                    */
	{39, "k5g45"},  /* VORTSCREAM -> BARKSHOTDIE (dog-like, fits)   */
	{16, "k4g23"},  /* GAMEOVER   -> KEENDIE tune                   */
	{41, "k4g35"},  /* KEENSLEFT  -> STATUSUP blip                  */
	{40, "k4g06"},  /* KEENSICLE  -> SLICEBUMP (frozen solid)       */
#if (EPISODE == 2)
	{42, "k5g53"},  /* EARTHPOW   -> GALAXYEXPLODE                  */
#endif
#if (EPISODE == 3)
	{42, "k4g19"},  /* ANKH       -> GOTGEM chime                   */
	{43, "k5g42"},  /* MEEP       -> SHOCKSUNDBARK (sings... sort of) */
	{45, "k5g28"},  /* FOOTSLAM   -> SPINDREDSLAM                   */
#endif
};
#define K13_GAL_COUNT ((int)(sizeof(k13_gal_map) / sizeof(k13_gal_map[0])))

/* the currently sounding Galaxy voice (guarded by the SDL audio lock) */
static const Sint16 *k13_gal_ptr;
static Uint32 k13_gal_len, k13_gal_pos;
static SDL_AudioDeviceID k13_audiodev;

static SDL_AudioDeviceID k13_audiodev_fwd(void)
{
	return k13_audiodev;
}

static void k13_gal_load(void)
{
	int i, j;

	for (i = 0; i < K13_GAL_COUNT; i++)
	{
		char path[64];
		SDL_AudioSpec spec;
		Uint8 *buf;
		Uint32 blen;

		if (k13_gal_map[i].data)
			continue;
		/* the same file can back several sounds: share the buffer */
		for (j = 0; j < i; j++)
			if (!strcmp(k13_gal_map[j].wav, k13_gal_map[i].wav) &&
			    k13_gal_map[j].data)
				break;
		if (j < i)
		{
			k13_gal_map[i].data = k13_gal_map[j].data;
			k13_gal_map[i].len = k13_gal_map[j].len;
			continue;
		}
		SDL_snprintf(path, sizeof(path), "sfx46/%s.wav", k13_gal_map[i].wav);
		if (!SDL_LoadWAV(path, &spec, &buf, &blen))
			continue;
		if (spec.freq != 48000 || spec.channels != 1 ||
		    spec.format != AUDIO_S16SYS)
		{
			SDL_AudioCVT cvt;
			if (SDL_BuildAudioCVT(&cvt, spec.format, spec.channels,
			                      spec.freq, AUDIO_S16SYS, 1, 48000) < 0)
			{
				SDL_FreeWAV(buf);
				continue;
			}
			cvt.len = (int)blen;
			cvt.buf = (Uint8 *)SDL_malloc((size_t)cvt.len * cvt.len_mult);
			memcpy(cvt.buf, buf, blen);
			SDL_FreeWAV(buf);
			if (SDL_ConvertAudio(&cvt) < 0)
			{
				SDL_free(cvt.buf);
				continue;
			}
			k13_gal_map[i].data = (Sint16 *)cvt.buf;
			k13_gal_map[i].len = (Uint32)(cvt.len_cvt / 2);
		}
		else
		{
			k13_gal_map[i].data = (Sint16 *)buf;
			k13_gal_map[i].len = blen / 2;
		}
		k13_gal_avail = 1;
	}
	{
		/* music availability: the episode's world-map track must exist */
		char path[64];
		FILE *f;

		SDL_snprintf(path, sizeof(path), "sfx46/%s.imf", k13_mus_level[0]);
		f = fopen(path, "rb");
		if (f)
		{
			fclose(f);
			k13_mus_avail = 1;
		}
	}
}

int K13_GalaxyAvail(void)
{
	return k13_gal_avail;
}

int K13_GetGalaxySfx(void)
{
	return k13_galaxysfx && k13_gal_avail;
}

void K13_SetGalaxySfx(int on)
{
	k13_galaxysfx = on ? 1 : 0;
}

static void k13_gal_start(const K13_GalSnd *g)
{
	if (k13_audiodev)
		SDL_LockAudioDevice(k13_audiodev);
	if (g && g->data)
	{
		k13_gal_ptr = g->data;
		k13_gal_len = g->len;
		k13_gal_pos = 0;
	}
	else
	{
		/* unmapped sound accepted by the priority system: vanilla would
		   have replaced the audible sound, so silence replaces it here */
		k13_gal_ptr = NULL;
	}
	if (k13_audiodev)
		SDL_UnlockAudioDevice(k13_audiodev);
}

static void k13_gal_trigger(int sound)
{
	static int wldstep;
	int i;

	if (sound == 1) /* WLDWALK: alternate the two Galaxy walk sounds */
	{
		wldstep ^= 1;
		if (wldstep)
		{
			k13_gal_start(&k13_gal_map[2]); /* KEENWALK1 entry */
			return;
		}
	}
	for (i = 0; i < K13_GAL_COUNT; i++)
		if (k13_gal_map[i].snd == sound)
		{
			k13_gal_start(&k13_gal_map[i]);
			return;
		}
	k13_gal_start(NULL);
}

/* SDL audio: square wave at the PC speaker's PIT channel-2 frequency */
static void SDLCALL k13_audio_cb(void *ud, Uint8 *stream, int len)
{
	static double phase;
	Sint16 *out = (Sint16 *)stream;
	int samples = len / 2;
	int i;
	int on = k13_spk_on;
	Uint16 div = k13_pit_divisor;
	double step = 0.0;

	(void)ud;
	if (k13_galaxysfx)
	{
		/* Galaxy mode: the speaker sequencer still runs (sim timing), but
		   its square wave is muted; the WAV voice is the audible output */
		for (i = 0; i < samples; i++)
		{
			if (k13_gal_ptr && k13_gal_pos < k13_gal_len)
				out[i] = k13_gal_ptr[k13_gal_pos++];
			else
				out[i] = 0;
		}
		if (k13_gal_ptr && k13_gal_pos >= k13_gal_len)
			k13_gal_ptr = NULL;
		k13_mus_mix(out, samples);
		return;
	}
	if (on && div)
		step = (1193182.0 / (double)div) / 48000.0;
	for (i = 0; i < samples; i++)
	{
		if (on && div)
		{
			out[i] = (phase < 0.5) ? 4500 : -4500;
			phase += step;
			while (phase >= 1.0)
				phase -= 1.0;
		}
		else
		{
			out[i] = 0;
		}
	}
	k13_mus_mix(out, samples);
}

static void k13_audio_init(void)
{
	SDL_AudioSpec want, have;

	if (k13_audiodev)
		return;
	k13_gal_load();
	SDL_InitSubSystem(SDL_INIT_AUDIO);
	SDL_zero(want);
	want.freq = 48000;
	want.format = AUDIO_S16SYS;
	want.channels = 1;
	want.samples = 512;
	want.callback = k13_audio_cb;
	k13_audiodev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
	if (k13_audiodev)
		SDL_PauseAudioDevice(k13_audiodev, 0);
}

static void k13_sdl_init(void)
{
	if (k13_window)
		return;
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER |
	             SDL_INIT_GAMECONTROLLER) != 0)
	{
		fprintf(stderr, "K13: SDL_Init failed: %s\n", SDL_GetError());
		exit(1);
	}
	k13_window = SDL_CreateWindow(
#if (EPISODE == 1)
		"Commander Keen 1: Marooned on Mars",
#elif (EPISODE == 2)
		"Commander Keen 2: The Earth Explodes",
#else
		"Commander Keen 3: Keen Must Die!",
#endif
		SDL_WINDOWPOS_CENTERED,
		SDL_WINDOWPOS_CENTERED, 960, 720,
		SDL_WINDOW_RESIZABLE |
		(getenv("K13_HIDDEN") ? SDL_WINDOW_HIDDEN : 0));
	k13_renderer = SDL_CreateRenderer(k13_window, -1,
	                                  SDL_RENDERER_PRESENTVSYNC);
	if (!k13_renderer)
		k13_renderer = SDL_CreateRenderer(k13_window, -1, 0);
	SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest");
	k13_texture = SDL_CreateTexture(k13_renderer, SDL_PIXELFORMAT_ARGB8888,
	                                SDL_TEXTUREACCESS_STREAMING, 320, 200);
	SDL_SetTextureScaleMode(k13_texture, SDL_ScaleModeNearest);
	k13_texture_wide = SDL_CreateTexture(k13_renderer, SDL_PIXELFORMAT_ARGB8888,
	                                     SDL_TEXTUREACCESS_STREAMING,
	                                     K13_COMP_MAXW, 200);
	SDL_SetTextureScaleMode(k13_texture_wide, SDL_ScaleModeNearest);
	/* sharp scaling: integer 4x prescale (nearest) then a slight linear
	   fit -- crisp pixels without shimmer at non-integer window sizes */
	k13_target = SDL_CreateTexture(k13_renderer, SDL_PIXELFORMAT_ARGB8888,
	                               SDL_TEXTUREACCESS_TARGET,
	                               K13_COMP_MAXW * 4, 800);
	SDL_SetTextureScaleMode(k13_target, SDL_ScaleModeLinear);
	k13_timebase = SDL_GetTicks();
	SDL_AddTimer(7, k13_timer_cb, NULL);
	{
		void K13_ConfigLoad(void);
		K13_ConfigLoad();
	}
	/* Fullscreen by default -- this is a couch/TV collection, and a windowed
	   DOS game on a 4K display is not what anyone wants on launch.  Applied
	   after the config load so a saved preference (Options -> Fullscreen)
	   wins, and K13_WINDOWED=1 forces a window for development. */
	if (K13_GetFullscreen() && !getenv("K13_WINDOWED") &&
	    !getenv("K13_HIDDEN"))
		SDL_SetWindowFullscreen(k13_window, SDL_WINDOW_FULLSCREEN_DESKTOP);
}

/* --- game controller: blended into the keyboard path so a pad always
 * works alongside the keys (couch play, zero setup). Triggers default to
 * fire, per the user's request; face buttons are jump/fire. --- */
static SDL_GameController *k13_pad;
static int k13_pad_x, k13_pad_y;   /* -1/0/1 dpad+stick */
static int k13_pad_b1, k13_pad_b2, k13_pad_fire; /* jump / pogo / fire */
static int k13_pad_start, k13_pad_back;

static void k13_pad_open(int idx)
{
	if (k13_pad || !SDL_IsGameController(idx))
		return;
	k13_pad = SDL_GameControllerOpen(idx);
}

/* is the pad input named by a binding code currently pressed? */
static int k13_pad_read(int code)
{
	if (!k13_pad || code < 0)
		return 0;
	if (code == K13_PAD_LTRIG)
		return SDL_GameControllerGetAxis(k13_pad,
		                                 SDL_CONTROLLER_AXIS_TRIGGERLEFT) > 12000;
	if (code == K13_PAD_RTRIG)
		return SDL_GameControllerGetAxis(k13_pad,
		                                 SDL_CONTROLLER_AXIS_TRIGGERRIGHT) > 12000;
	if (code >= SDL_CONTROLLER_BUTTON_MAX)
		return 0;
	return SDL_GameControllerGetButton(k13_pad,
	                                   (SDL_GameControllerButton)code) != 0;
}

static void k13_pad_poll(void)
{
	int lx, ly;
	Uint8 dl, dr, du, dd;

	if (!k13_pad)
		return;
	if (getenv("K13_PADSYN"))
		return; /* synthetic pad; state set in the pump */
	if (!SDL_GameControllerGetAttached(k13_pad))
	{
		SDL_GameControllerClose(k13_pad);
		k13_pad = NULL;
		k13_pad_x = k13_pad_y = k13_pad_b1 = k13_pad_b2 = k13_pad_fire = 0;
		return;
	}
	dl = SDL_GameControllerGetButton(k13_pad, SDL_CONTROLLER_BUTTON_DPAD_LEFT);
	dr = SDL_GameControllerGetButton(k13_pad, SDL_CONTROLLER_BUTTON_DPAD_RIGHT);
	du = SDL_GameControllerGetButton(k13_pad, SDL_CONTROLLER_BUTTON_DPAD_UP);
	dd = SDL_GameControllerGetButton(k13_pad, SDL_CONTROLLER_BUTTON_DPAD_DOWN);
	lx = SDL_GameControllerGetAxis(k13_pad, SDL_CONTROLLER_AXIS_LEFTX);
	ly = SDL_GameControllerGetAxis(k13_pad, SDL_CONTROLLER_AXIS_LEFTY);

	k13_pad_x = dl ? -1 : dr ? 1 : (lx < -12000) ? -1 : (lx > 12000) ? 1 : 0;
	k13_pad_y = du ? -1 : dd ? 1 : (ly < -12000) ? -1 : (ly > 12000) ? 1 : 0;

	/* Vorticons scheme: jump = button1, pogo = button2, SHOOT = both.
	   So a dedicated FIRE control presses both at once (see the blend).
	   All four gameplay controls are rebindable (Options -> Controls). */
	k13_pad_b1 = k13_pad_read(K13_GetBind(K13_BIND_JUMP, 0)) ||
	             k13_pad_read(K13_GetBind(K13_BIND_JUMP, 1));
	k13_pad_b2 = k13_pad_read(K13_GetBind(K13_BIND_POGO, 0)) ||
	             k13_pad_read(K13_GetBind(K13_BIND_POGO, 1));
	k13_pad_fire = k13_pad_read(K13_GetBind(K13_BIND_FIRE, 0)) ||
	               k13_pad_read(K13_GetBind(K13_BIND_FIRE, 1));
	k13_pad_start =
		SDL_GameControllerGetButton(k13_pad, SDL_CONTROLLER_BUTTON_START);
	k13_pad_back =
		SDL_GameControllerGetButton(k13_pad, SDL_CONTROLLER_BUTTON_BACK);

	/* The status screen and quicksave/quickload are KEYS to the engine
	   (HandleUserKeys watches the status key; DoFkeys switches on the scan
	   code), so drive the bound key from the bound pad button, on edges only
	   to leave a real keyboard press alone.  Going through the key means the
	   pad reuses the whole path, confirmation prompt included. */
	if (!k13_replaying())
	{
		static const int act[][2] = {
			{K13_BIND_STATUS,   K13_KEY_STATUS},
			{K13_BIND_QSAVE,    K13_KEY_QSAVE},
			{K13_BIND_QLOAD,    K13_KEY_QLOAD},
			{K13_BIND_HELP,     K13_KEY_HELP},
			{K13_BIND_SOUND,    K13_KEY_SOUND},
			{K13_BIND_SAVEMENU, K13_KEY_SAVEMENU},
			{K13_BIND_QUIT,     K13_KEY_QUIT},
			{K13_BIND_SCOREBOX, K13_KEY_SCOREBOX}
		};
#define K13_NPADACT ((int)(sizeof(act) / sizeof(act[0])))
		static int prev[K13_NPADACT];
		int i;

		for (i = 0; i < K13_NPADACT; i++)
		{
			int on = k13_pad_read(K13_GetBind(act[i][0], 0)) ||
			         k13_pad_read(K13_GetBind(act[i][0], 1));
			int sc = K13_GetKeyBind(act[i][1]);

			/* keyboard key cleared? inject on the action's private synthetic
			   scan instead, so the pad binding keeps working regardless */
			if (sc <= 0 || sc >= 128)
				sc = K13_SYNTH_SCAN(act[i][1]);
			if (on != prev[i])
			{
				keydown[sc] = (char)(on ? 1 : 0);
				if (on)
					NBKscan = sc | 0x80;
				prev[i] = on;
			}
		}
#undef K13_NPADACT
	}
}

/* menu/dialog code reads keys, not ControlPlayer, so translate pad edges
 * into synthetic DOS key events (arrows / enter / esc) */
static void k13_pad_menu_edges(void)
{
	static int px, py, pb1, pb2, pstart, pback;
	int i;
	struct { int now, *prev, sc; } edges[] = {
		{ k13_pad_x < 0, &px, 0x4B }, { k13_pad_x > 0, &px, 0x4D },
		{ k13_pad_y < 0, &py, 0x48 }, { k13_pad_y > 0, &py, 0x50 },
		{ k13_pad_b1, &pb1, 0x1C },   /* fire  -> Enter */
		{ k13_pad_start, &pstart, 0x1C },
		{ k13_pad_b2, &pb2, 0x01 },   /* jump  -> Esc   */
		{ k13_pad_back, &pback, 0x01 },
	};
	(void)edges;
	/* x/y are level-triggered here; convert to press edges below */
	{
		int nx = (k13_pad_x != 0), ny = (k13_pad_y != 0);
		if (nx && !px)
		{
			Uint8 sc = k13_pad_x < 0 ? 0x4B : 0x4D;
			keydown[sc] = 1; NBKscan = sc | 0x80;
		}
		else if (!nx && px)
		{
			keydown[0x4B] = keydown[0x4D] = 0;
		}
		if (ny && !py)
		{
			Uint8 sc = k13_pad_y < 0 ? 0x48 : 0x50;
			keydown[sc] = 1; NBKscan = sc | 0x80;
		}
		else if (!ny && py)
		{
			keydown[0x48] = keydown[0x50] = 0;
		}
		px = nx; py = ny;
	}
	if ((k13_pad_b1 || k13_pad_start) && !pb1)
		NBKscan = 0x1C | 0x80; /* Enter */
	pb1 = (k13_pad_b1 || k13_pad_start);
	if ((k13_pad_b2 || k13_pad_back) && !pb2)
		NBKscan = 0x01 | 0x80; /* Esc */
	pb2 = (k13_pad_b2 || k13_pad_back);
	(void)i;
}

/* blended into ControlKBD: OR pad direction/buttons over the keyboard */
extern int k13_onefire; /* config: 1 = a single control fires (sets both) */

void K13_ControllerBlend(ControlStruct *a)
{
	int xmove, ymove;
	int fire;

	if (k13_pad)
	{
	/* recover x/y from the keyboard-decided dir, then OR the pad */
	switch (a->dir)
	{
	case northwest: xmove = -1; ymove = -1; break;
	case north:     xmove = 0;  ymove = -1; break;
	case northeast: xmove = 1;  ymove = -1; break;
	case west:      xmove = -1; ymove = 0;  break;
	case east:      xmove = 1;  ymove = 0;  break;
	case southwest: xmove = -1; ymove = 1;  break;
	case south:     xmove = 0;  ymove = 1;  break;
	case southeast: xmove = 1;  ymove = 1;  break;
	default:        xmove = 0;  ymove = 0;  break;
	}
	if (k13_pad_x)
		xmove = k13_pad_x;
	if (k13_pad_y)
		ymove = k13_pad_y;
	switch (ymove * 3 + xmove)
	{
	case -4: a->dir = northwest; break;
	case -3: a->dir = north; break;
	case -2: a->dir = northeast; break;
	case -1: a->dir = west; break;
	case 0:  a->dir = nodir; break;
	case 1:  a->dir = east; break;
	case 2:  a->dir = southwest; break;
	case 3:  a->dir = south; break;
	case 4:  a->dir = southeast; break;
	}
	if (k13_pad_b1)
		a->button1 = 1;
	if (k13_pad_b2)
		a->button2 = 1;
	}

	/* one-button fire (the bound fire key or pad fire): press BOTH engine
	   buttons so the shoot combo triggers. Off = authentic two-button. */
	{
		int fk = K13_GetFireKey();
		fire = (k13_pad && k13_pad_fire) ||
		       (fk > 0 && fk < 128 && keydown[fk]);
	}
	if (k13_onefire && fire)
	{
		a->button1 = 1;
		a->button2 = 1;
	}
}

/* Scripted key presses for automated repros (dev harness only).
 * K13_TEST_SEQ="ms:scan,ms:scan,..." -- scan codes in hex, times in ms
 * measured from the first live gameplay frame.  Runs from the pump, so it
 * also drives blocking screens (Get / NoBiosKey waits). */
static void k13_test_seq(void)
{
	static const char *cur;
	static int init, held;
	static Uint32 t0, release;
	Uint32 now;

	if (!init)
	{
		init = 1;
		cur = getenv("K13_TEST_SEQ");
	}
	if (!cur)
		return;
	now = SDL_GetTicks();
	if (!t0)
	{
		/* times are measured from the first live gameplay frame, so
		   gameplay repros are not hostage to boot timing; K13_TEST_ABS=1
		   measures from process start instead, for menu screens */
		if (!k13_world_live && !getenv("K13_TEST_ABS"))
			return;
		t0 = now ? now : 1;
	}
	if (held && now >= release)
	{
		keydown[held] = 0;
		held = 0;
	}
	if (!*cur)
		return;
	{
		const char *p = cur;
		long ms = strtol(p, (char **)&p, 10);
		int sc;
		if (*p == ':')
			p++;
		sc = (int)strtol(p, (char **)&p, 16);
		if (*p == ',')
			p++;
		if (now - t0 < (Uint32)ms)
			return; /* not due yet; leave the cursor where it is */
		cur = p;
		k13_test_seq_ran = 1; /* the script takes over from the auto-nav */
		keydown[sc] = 1;
		NBKscan = (Sint16)(sc | 0x80);
		held = sc;
		release = now + 150;
		fprintf(stderr, "K13 TEST: key %02X at %ums\n", sc,
		        (unsigned)(now - t0));
		fflush(stderr);
	}
}

static void k13_pump(void)
{
	SDL_Event ev;

	if (!k13_window)
		k13_sdl_init();

	while (SDL_PollEvent(&ev))
	{
		switch (ev.type)
		{
		case SDL_QUIT:
			Quit("");
			break;
		case SDL_CONTROLLERDEVICEADDED:
			k13_pad_open(ev.cdevice.which);
			break;
		case SDL_KEYDOWN:
		{
			Uint8 sc;
			if (ev.key.keysym.scancode == SDL_SCANCODE_F11 &&
			    !ev.key.repeat)
			{
				Uint32 fs = SDL_GetWindowFlags(k13_window) &
				            SDL_WINDOW_FULLSCREEN_DESKTOP;
				SDL_SetWindowFullscreen(k13_window,
				                        fs ? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP);
				break;
			}
			if (k13_replaying())
				break; /* replays must be deterministic */
			sc = k13_scanmap[ev.key.keysym.scancode];
			if (!sc)
				break;
			if (k13_recf)
			{
				if (k13_npending < K13_PENDMAX)
				{
					k13_pending[k13_npending].sc = sc;
					k13_pending[k13_npending].down = 1;
					k13_npending++;
				}
				break;
			}
			/* exactly what the Int9 ISR does: mark keydown and store
			   the make code with bit 7 as the "new key" marker */
			keydown[sc] = 1;
			NBKscan = sc | 0x80;
			break;
		}
		case SDL_KEYUP:
		{
			Uint8 sc = k13_scanmap[ev.key.keysym.scancode];
			if (!sc || k13_replaying())
				break;
			if (k13_recf)
			{
				if (k13_npending < K13_PENDMAX)
				{
					k13_pending[k13_npending].sc = sc;
					k13_pending[k13_npending].down = 0;
					k13_npending++;
				}
				break;
			}
			keydown[sc] = 0;
			break;
		}
		}
	}
	k13_test_seq();
	/* pulse Enter until the world is live (title -> menu -> New Game), so
	   the scripted repros reach gameplay on their own */
	if ((getenv("K13_TEST_STATUS") || getenv("K13_TEST_SEQ")) &&
	    !getenv("K13_TEST_ABS") && /* absolute scripts drive menus themselves */
	    !k13_test_seq_ran && !k13_world_live && !k13_dialog_active)
	{
		static Uint32 next_dn, next_up;
		Uint32 now = SDL_GetTicks();
		if (next_up && now >= next_up)
		{
			keydown[0x1C] = 0;
			next_up = 0;
		}
		if (now >= next_dn)
		{
			keydown[0x1C] = 1;
			NBKscan = 0x1C | 0x80; /* Enter */
			next_up = now + 120;
			next_dn = now + 1500;
		}
	}
	/* safety: dump whatever is on screen and bail if the repro stalls */
	if (getenv("K13_TEST_STATUS") && SDL_GetTicks() > 90000)
	{
		k13_dump_screen_at("k13_stat_stall.ppm",
		                   k13_dialog_active ? k13_dialog_base : 0x0000);
		fprintf(stderr, "K13 TEST: STALL live=%d dlg=%d fired=%d\n",
		        k13_world_live, k13_dialog_active, k13_test_fired);
		fflush(stderr);
		exit(1);
	}
	k13_pad_poll();
	/* K13_PADSYN=1: synthesize a pad walking right, to exercise the blend
	   path end-to-end without hardware (dev verification only) */
	if (getenv("K13_PADSYN"))
	{
		k13_pad = (SDL_GameController *)1; /* non-NULL sentinel */
		k13_pad_x = 1;
		k13_pad_y = 0;
		k13_pad_b1 = k13_pad_b2 = k13_pad_fire = 0;
	}
	else if (!k13_world_live || k13_dialog_active)
	{
		/* only translate the pad to menu keys OUTSIDE live gameplay --
		   in menus and in-game popups. During play the blend drives it. */
		k13_pad_menu_edges();
	}
}

#else /* !K13_WITH_SDL */

static void k13_pump(void) {}

#endif

/*
=============================================================================
	Press-to-bind support for the native Controls screen (KEENSCRN.C).
	Both waiters keep presenting while they block, so the screen stays
	live, and both accept keyboard ESC as "cancel".
=============================================================================
*/

const char *K13_PadBindName(int code)
{
	switch (code)
	{
	case 0:  return "A";
	case 1:  return "B";
	case 2:  return "X";
	case 3:  return "Y";
	case 4:  return "BACK";
	case 5:  return "GUIDE";
	case 6:  return "START";
	case 7:  return "L-STICK";
	case 8:  return "R-STICK";
	case 9:  return "LB";
	case 10: return "RB";
	case 11: return "PAD-UP";
	case 12: return "PAD-DN";
	case 13: return "PAD-LF";
	case 14: return "PAD-RT";
	case K13_PAD_LTRIG: return "L-TRIG";
	case K13_PAD_RTRIG: return "R-TRIG";
	}
	return "NONE";
}

/* wait for a pad press; returns its binding code, -1 if the player
 * cancelled with ESC, or -2 when no controller is connected */
int K13_PadBindWait(void)
{
#ifdef K13_WITH_SDL
	int i;

	if (!k13_pad)
		return -2;
	/* let go of whatever opened this prompt first */
	for (;;)
	{
		int any = 0;
		K13_Idle();
		for (i = 0; i < SDL_CONTROLLER_BUTTON_MAX; i++)
			any |= k13_pad_read(i);
		any |= k13_pad_read(K13_PAD_LTRIG) | k13_pad_read(K13_PAD_RTRIG);
		if (!any)
			break;
		if (keydown[0x01])
			return -1;
	}
	ClearKeys();
	for (;;)
	{
		K13_Idle();
		if (!k13_pad)
			return -2;
		if (keydown[0x01] || (NBKscan & 0x7F) == 0x01)
		{
			ClearKeys();
			return -1;
		}
		if (keydown[0x0E] || keydown[0x53])
		{
			ClearKeys();
			return -3;   /* Backspace/Del: clear the binding */
		}
		for (i = 0; i < SDL_CONTROLLER_BUTTON_MAX; i++)
			if (k13_pad_read(i))
				return i;
		if (k13_pad_read(K13_PAD_LTRIG))
			return K13_PAD_LTRIG;
		if (k13_pad_read(K13_PAD_RTRIG))
			return K13_PAD_RTRIG;
	}
#else
	return -2;
#endif
}

/* wait for a key; returns its DOS scan code, or -1 on ESC */
int K13_KeyBindWait(void)
{
#ifdef K13_WITH_SDL
	int sc;

	/* wait for the key that opened this prompt to come up first, or its
	   auto-repeat would bind itself a moment later */
	for (;;)
	{
		int any = 0;
		K13_Idle();
		for (sc = 1; sc < 128; sc++)
			any |= keydown[sc];
		if (!any)
			break;
	}
	ClearKeys();
	for (;;)
	{
		K13_Idle();
		for (sc = 1; sc < 128; sc++)
		{
			if (!keydown[sc])
				continue;
			ClearKeys();
			if (sc == 0x01)
				return -1;   /* Esc: keep the old binding */
			if (sc == 0x0E || sc == 0x53)
				return -3;   /* Backspace/Del: clear the binding */
			return sc;
		}
	}
#else
	return -1;
#endif
}

void K13_ToggleFullscreen(void)
{
#ifdef K13_WITH_SDL
	if (k13_window)
	{
		Uint32 fs = SDL_GetWindowFlags(k13_window) &
		            SDL_WINDOW_FULLSCREEN_DESKTOP;
		SDL_SetWindowFullscreen(k13_window,
		                        fs ? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP);
	}
#endif
}

int K13_IsFullscreen(void)
{
#ifdef K13_WITH_SDL
	return k13_window &&
	       (SDL_GetWindowFlags(k13_window) & SDL_WINDOW_FULLSCREEN_DESKTOP)
	           != 0;
#else
	return 0;
#endif
}

void K13_Idle(void)
{
#ifdef K13_WITH_SDL
	static Uint32 lastpresent;
	Uint32 now;

	k13_pump();
	now = SDL_GetTicks();
	if (now - lastpresent >= 14)
	{
		lastpresent = now;
		k13_present();
	}
#endif
}

/* Turbo C bioskey(): forwarded to the NoBiosKey machinery */
int bioskey(int cmd)
{
	return NoBiosKey(cmd);
}

void StartupKbd(void)
{
#ifdef K13_WITH_SDL
	k13_sdl_init();
#endif
}

void ShutdownKbd(void) {}

static int k13_nbk_tap(int result)
{
	k13_verify_init();
	if (k13_recf)
	{
		Sint32 v = result;
		Uint8 bits[16];
		fputc('K', k13_recf);
		fwrite(&v, 4, 1, k13_recf);
		fputc((Uint8)NBKscan, k13_recf);
		k13_pack_keys(bits);
		fwrite(bits, 1, 16, k13_recf);
		fflush(k13_recf);
	}
	return result;
}

static int k13_nbk_replay(int *result)
{
	k13_verify_init();
	if (!k13_repf)
		return 0;
	{
		Sint32 v = 0;
		Uint8 bits[16] = {0};
		k13_verify_expect('K');
		fread(&v, 4, 1, k13_repf);
		NBKscan = fgetc(k13_repf);
		fread(bits, 1, 16, k13_repf);
		k13_unpack_keys(bits);
		*result = v;
	}
	return 1;
}

int NoBiosKey(int parm)
{
#ifdef K13_WITH_SDL
	{
		int rr;
		if (k13_nbk_replay(&rr))
		{
			k13_pump(); /* keep the window alive */
			return rr;
		}
	}
	k13_pump();
	if (k13_recf)
		k13_apply_pending();
	if (parm == 0)
	{
		/* wait for a fresh make code (NBKscan bit 7), consume the
		   marker; modifier keys (ascii 0) keep waiting -- exactly the
		   v1.31 asm loop */
		for (;;)
		{
			int sc, a;
			if (!(NBKscan & 0x80))
			{
				SDL_Delay(5);
				K13_Idle(); /* pump AND present: static screens (status,
				               text pages) block here, and the last drawn
				               chars must reach the display */
				if (k13_recf)
					k13_apply_pending();
				continue;
			}
			sc = NBKscan & 0x7F;
			NBKscan = sc;
			a = k13_scanascii[sc];
			if (!a)
				continue;
			NBKascii = a;
			return k13_nbk_tap((sc << 8) | a);
		}
	}
	/* parm 1: peek; marker stays set, NBKascii side effect as in asm */
	{
		int sc, a;
		if (!(NBKscan & 0x80))
			return k13_nbk_tap(0);
		sc = NBKscan & 0x7F;
		a = k13_scanascii[sc];
		NBKascii = a;
		return k13_nbk_tap(a ? ((sc << 8) | a) : 0);
	}
#else
	(void)parm;
	return 0;
#endif
}

/* sound entries in SOUNDS.CKx: 16 bytes each -
 * {Uint16 start; Uint8 priority; Uint8 samplerate; char name[12]} */
#define K13_SND_START 0
#define K13_SND_PRIORITY 2

void StartupSound(void)
{
	if (dontplay)
		return;
#ifdef K13_WITH_SDL
	k13_audio_init();
#endif
	/* the DOS routine hooks INT 8 at PIT divisor 0x2000; our timer thread
	 * plays that role from k13_sdl_init on */
	soundmode = spkr;
}

void ShutdownSound(void)
{
#ifdef K13_WITH_SDL
	if (k13_audiodev)
	{
		SDL_CloseAudioDevice(k13_audiodev);
		k13_audiodev = 0;
	}
#endif
}

void StopSound(void)
{
	if (dontplay)
		return;
#ifdef K13_WITH_SDL
	k13_sndptr = 0;
	SndPriority = 0;
	k13_spk_on = 0;
	k13_gal_start(NULL);
#endif
}

void PlaySound(int sound)
{
	const Uint8 *hdr;
	Uint16 start;

	if (dontplay || !SoundData)
		return;
	hdr = (const Uint8 *)SoundData + (Uint32)sound * 16;
	/* asm: skip if the new sound's priority is BELOW the current one */
	if (hdr[K13_SND_PRIORITY] < (Uint8)SndPriority)
		return;
	SndPriority = hdr[K13_SND_PRIORITY];
	memcpy(&start, hdr + K13_SND_START, 2);
#ifdef K13_WITH_SDL
	k13_sndptr = start;
	if (k13_galaxysfx)
		k13_gal_trigger(sound);
#else
	(void)start;
#endif
}

void PauseSound(void)
{
	if (dontplay)
		return;
#ifdef K13_WITH_SDL
	k13_pause_sndptr = k13_sndptr;
	k13_pause_priority = SndPriority;
#endif
	StopSound();
}

void ContinueSound(void)
{
	if (dontplay)
		return;
#ifdef K13_WITH_SDL
	k13_sndptr = k13_pause_sndptr;
	SndPriority = k13_pause_priority;
#endif
}

void WaitEndSound(void)
{
	if (dontplay)
		return;
#ifdef K13_WITH_SDL
	while (k13_sndptr)
		K13_Idle();
#endif
}

void UpdateSPKR(void)
{
	/* the DOS build calls this as the INT 8 vector; our timer thread does
	 * the equivalent work in k13_timer_cb */
#ifdef K13_WITH_SDL
	k13_sound_tick();
#endif
}

void WaitVBL(int num)
{
#ifdef K13_WITH_SDL
	Uint32 end;
	if (num < 1)
		num = 1;
	end = SDL_GetTicks() + ((Uint32)num * 1000u) / 70u;
	k13_present();
	for (;;)
	{
		Uint32 now = SDL_GetTicks();
		if (now >= end)
			break;
		SDL_Delay(1);
		k13_pump();
	}
#else
	(void)num;
	k13_maybe_dump();
#endif
}

void EGAplane(int plane)
{
	/* select plane for read AND write, as the asm helper does */
	outportb(K13_GC_INDEX, 4);
	outportb(K13_GC_INDEX + 1, (Uint8)(plane & 3));
	outportb(K13_SC_INDEX, 2);
	outportb(K13_SC_INDEX + 1, (Uint8)(1 << (plane & 3)));
}

void EGAlatch(void)
{
	outportb(K13_SC_INDEX, 2);
	outportb(K13_SC_INDEX + 1, 0xF);
}

cardtype VideoID(void)
{
	return EGAcard;
}

/*
=============================================================================
	Adaptive tile refresh (VidInitDraw / DrawPage / VidRefresh), ported
	from IDASM.ASM.  Each EGA page holds a 21x14 tile field starting at
	byte 0x604 (4-byte left margin + 32-line top margin); pages live at
	segments A000/A300 (plane bytes 0x0000/0x3000).  The CRTC start
	address plus pel pan present the fine-scrolled window.
=============================================================================
*/

static Uint16 k13_drawseg = 0xA000;
static Uint16 k13_screenstart, k13_screenpan;

void VidInitDraw(void)
{
	k13_screenstart = 4;
	if (originx & 0x800)
		k13_screenstart++;
	k13_screenpan = (Uint16)((originx >> 8) & 7);

	EGApage ^= 1;
	if (EGApage & 1)
	{
		k13_drawseg = 0xA300;
		k13_screenstart += 0x3000;
	}
	else
	{
		k13_drawseg = 0xA000;
	}
	k13_screenstart += (Uint16)(((originy >> 8) & 15) * SCREENWIDTH +
	                            SCREENWIDTH * 32);
	screenseg = 0xA000 + (k13_screenstart >> 4);
}

/* one 16x16 tile, all planes, latch copy into the draw page */
static void k13_drawtile16(Uint32 src, Uint32 dst)
{
	Uint32 base = ((Uint32)(k13_drawseg - 0xA000)) << 4;
	int row, p;

	dst += base;
	for (row = 0; row < 16; row++)
	{
		for (p = 0; p < 4; p++)
		{
			k13_ega[p][dst & 0xFFFF] = k13_ega[p][src & 0xFFFF];
			k13_ega[p][(dst + 1) & 0xFFFF] = k13_ega[p][(src + 1) & 0xFFFF];
		}
		dst += SCREENWIDTH;
		src += 2;
	}
}

static void k13_drawpage(Sint16 *oldarr)
{
	Uint32 tilex = (Uint32)((originx >> 8) & 0xFFFF) >> 4;
	Uint32 tiley = (Uint32)((originy >> 8) & 0xFFFF) >> 4;
	Uint16 *maprow = mapplane[0] + tiley * (mapbwide / 2) + tilex;
	int tx, ty, idx = 0;
	Uint32 drawoff = 0x604;

	for (ty = 0; ty < PORTTILESHIGH; ty++)
	{
		for (tx = 0; tx < PORTTILESWIDE; tx++, idx++)
		{
			Uint16 img = (Uint16)k13_cur_anim[maprow[tx]];
			if ((Sint16)img != oldarr[idx])
			{
				oldarr[idx] = (Sint16)img;
				k13_drawtile16(k13_tileoff + img,
				               drawoff + (Uint32)tx * 2);
			}
		}
		maprow += mapbwide / 2;
		drawoff += 16 * SCREENWIDTH;
	}
}

static void k13_present(void); /* forward: SDL/PPM presentation below */

void VidRefresh(void)
{
	k13_mus_watch();
	Uint16 savedseg;
	Uint16 i;

	/* A real frame is being drawn, so the dialog is over: drop the pin HERE,
	   before any drawing in this refresh.  It used to be cleared at the end of
	   the refresh (in k13_comp_refresh_snap), which meant this whole frame --
	   tiles, lists and uservect -- still went through k13_drawbase()'s pinned
	   dialog page.  On the high-score screen that made DrawHighscores land on
	   the same page twice, leaving the other page with only its border tiles;
	   since the screen flips page every refresh, the text appeared to flash.
	   That is why it started right after any window closed over it. */
	k13_dialog_active = 0;
	VidInitDraw();
	screenofs = 0;

	{
		static unsigned *const animtabletable[4] = {
			tile_anim0, tile_anim1, tile_anim2, tile_anim3
		};
		k13_cur_anim = animtabletable
			[((Uint16)((Uint32)timecount >> cyclespeed) & 6) >> 1];
	}

	if (EGApage)
		k13_drawpage(oldtiles);
	else
		k13_drawpage(oldtiles2);

	/* sprites/foreground tiles/pics compose into the back page */
	savedseg = screenseg;
	screenseg = k13_drawseg;
	for (i = 0; i < spritesshown; i++)
		DrawSprite(spritelist[i].x, spritelist[i].y, spritelist[i].num);
	for (i = 0; i < tilesshown; i++)
		DrawTile(tilelist[i].x, tilelist[i].y, tilelist[i].num);
	for (i = 0; i < picsshown; i++)
		DrawPic(piclist[i].x, piclist[i].y, piclist[i].num);
	screenseg = savedseg;

	if (uservect)
		uservect();


	/* page flip: publish CRTC start + pel pan, then present the frame */
	k13_crtc_reg[0x0C] = (Uint8)(k13_screenstart >> 8);
	k13_crtc_reg[0x0D] = (Uint8)(k13_screenstart & 0xFF);
	k13_comp_refresh_snap();
	/* NOTE: no compose(1,1) here -- presenting the new frame at full
	   alpha and then rewinding to alpha~0 on the next interpolated
	   present made the whole scene sawtooth once per sim frame (the
	   "everything jitters" bug). k13_present interp-composes at the
	   monotonic ms clock instead, so the camera only glides forward. */
	k13_present();
}

void RF_ForceRefresh(void)
{
	int i;

	for (i = 0; i < K13_PORTTILECOUNT; i++)
	{
		oldtiles[i] = -1;
		oldtiles2[i] = -1;
	}
}

/* full-width screen-buffer scroll for KEENSCRN's text windows */
void K13_EGAScroll(unsigned dstoff, unsigned srcoff, unsigned count,
                   int backwards)
{
	Uint32 base = k13_drawbase();
	Uint32 d = dstoff, s = srcoff;
	int p;

	if (backwards)
	{
		/* offsets point at the LAST byte of each region */
		d = d - count + 1;
		s = s - count + 1;
	}
	for (p = 0; p < 4; p++)
		memmove(k13_ega[p] + ((base + d) & 0xFFFF),
		        k13_ega[p] + ((base + s) & 0xFFFF), count);
}

/*
=============================================================================
	Frame presentation (SDL texture upload of the visible CRTC window)
=============================================================================
*/

#ifdef K13_WITH_SDL
/* dev harness: write what is on screen right now (composed wide buffer if
 * one is live, plus the raw CRTC page view) and quit */
/* Persistent score box: a Keen 4-6 style HUD stamped into the final frame at
 * present time (never into EGA memory, so the sim and the replay baseline are
 * untouched).  Glyphs come from the game's own 8x8 font in plane memory --
 * same data DrawChar uses -- so it looks native.  Shown only over a live
 * world; page-drawn screens (menus, status, high scores) keep their space. */
static void k13_scorebox_stamp(Uint8 *pixels, int pitch, int outw,
                               const Uint32 *pal)
{
	char line[3][10];
	int row, col, gy, gx, w = 0;

	sprintf(line[0], "%7ld ", (long)gamestate.score);
	sprintf(line[1], "KEENS %2d", (int)gamestate.lives);
	sprintf(line[2], "SHOTS %2d", (int)gamestate.ammo);

	for (row = 0; row < 3; row++)
		if ((int)strlen(line[row]) > w)
			w = (int)strlen(line[row]);

	/* black outline first, then the opaque font cells */
	for (gy = 0; gy < 3 * 8 + 2; gy++)
	{
		Uint32 *out = (Uint32 *)(pixels + (size_t)(gy + 3) * pitch);
		for (gx = 0; gx < w * 8 + 2; gx++)
			if (gx + 3 < outw)
				out[gx + 3] = pal[0];
	}

	for (row = 0; row < 3; row++)
	{
		for (col = 0; col < (int)strlen(line[row]); col++)
		{
			Uint32 src = k13_charoff + (Uint32)(Uint8)line[row][col] * 8;

			for (gy = 0; gy < 8; gy++)
			{
				Uint32 *out = (Uint32 *)(pixels +
					(size_t)(row * 8 + gy + 4) * pitch);
				Uint8 b0 = k13_ega[0][(src + gy) & 0xFFFF];
				Uint8 b1 = k13_ega[1][(src + gy) & 0xFFFF];
				Uint8 b2 = k13_ega[2][(src + gy) & 0xFFFF];
				Uint8 b3 = k13_ega[3][(src + gy) & 0xFFFF];

				for (gx = 0; gx < 8; gx++)
				{
					int bit = 7 - gx;
					int ci = ((b0 >> bit) & 1) | (((b1 >> bit) & 1) << 1) |
					         (((b2 >> bit) & 1) << 2) | (((b3 >> bit) & 1) << 3);
					int px = col * 8 + gx + 4;

					if (px < outw)
						out[px] = pal[ci];
				}
			}
		}
	}
}

static void k13_test_shot(const char *stem)
{
	char path[64];

	if (k13_comp_have)
	{
		sprintf(path, "%s_comp.ppm", stem);
		{
			FILE *f = fopen(path, "wb");
			if (f)
			{
				int x, y;
				fprintf(f, "P6\n%d 200\n255\n", k13_comp_w);
				for (y = 0; y < 200; y++)
					for (x = 0; x < k13_comp_w; x++)
					{
						Uint8 ega = k13_palette[k13_comp[y * K13_COMP_MAXW + x] & 15];
						Uint8 rgb[3];
						rgb[0] = (Uint8)((((ega >> 2) & 1) * 0xAA) +
						                 (((ega >> 5) & 1) * 0x55));
						rgb[1] = (Uint8)((((ega >> 1) & 1) * 0xAA) +
						                 (((ega >> 4) & 1) * 0x55));
						rgb[2] = (Uint8)(((ega & 1) * 0xAA) +
						                 (((ega >> 3) & 1) * 0x55));
						fwrite(rgb, 1, 3, f);
					}
				fclose(f);
			}
		}
	}
	sprintf(path, "%s_crtc.ppm", stem);
	k13_dump_screen_at(path, ((Uint32)k13_crtc_reg[0x0C] << 8) |
	                             k13_crtc_reg[0x0D]);
	fprintf(stderr, "K13 TEST: shot wide=%d dlg=%d crtc=%04lX pan=%d\n",
	        k13_comp_have ? k13_comp_w : 0, k13_dialog_active,
	        (unsigned long)(((Uint32)k13_crtc_reg[0x0C] << 8) |
	                        k13_crtc_reg[0x0D]),
	        (int)k13_screenpan);
	fflush(stderr);
	exit(0);
}
#endif

/*
=============================================================================
	Letterbox treatment: a tiled backdrop drawn from the game's OWN tileset
	plus a bevelled frame around the picture, instead of plain black bars.
	Same idea as the Keen 4-6 build, and it themes itself per episode for
	free because a tile number indexes that episode's tileset.

	The pattern is rebuilt whenever the palette changes, so it darkens
	through fades along with everything else -- during a fade to black it
	goes black too, which is intentional.
=============================================================================
*/

#define K13_BD_TILES 4   /* 4x4 tiles per texture: fewer draw calls */

static SDL_Texture *k13_tex_backdrop;
static int k13_bd_tile = -2;             /* -2 unread, -1 disabled */
static Uint8 k13_bd_pal[16];             /* palette it was built with */

static int k13_backdrop_tile(void)
{
	if (k13_bd_tile == -2)
	{
		const char *e = getenv("K13_BACKDROP");
		k13_bd_tile = K13_GetBackdrop();
		if (e)
			k13_bd_tile = atoi(e);
	}
	return k13_bd_tile;
}

/* rasterise the chosen tile into a K13_BD_TILES^2 patch of EGA pixels */
static void k13_backdrop_build(void)
{
	int tile = k13_backdrop_tile();
	Uint32 pal[16];
	Uint32 *pixels;
	int pitch, i, row, col, bit;
	const int side = 16 * K13_BD_TILES;

	if (tile < 0 || tile >= K13_MAXTILES)
		return;
	if (!k13_tex_backdrop)
	{
		k13_tex_backdrop = SDL_CreateTexture(k13_renderer,
		                                     SDL_PIXELFORMAT_ARGB8888,
		                                     SDL_TEXTUREACCESS_STREAMING,
		                                     side, side);
		if (!k13_tex_backdrop)
			return;
	}
	for (i = 0; i < 16; i++)
		pal[i] = k13_ega_rgb(k13_palette[i]);
	memcpy(k13_bd_pal, k13_palette, 16);

	if (SDL_LockTexture(k13_tex_backdrop, NULL, (void **)&pixels, &pitch) != 0)
		return;
	/* Scatter the tile over the patch instead of tiling it solid: one tile
	   repeated every 16px reads as wallpaper, and the eye latches onto the
	   grid.  Leaving most cells empty keeps the backdrop quiet and makes
	   the period 64px with irregular content. */
	for (row = 0; row < side; row++)
		memset((Uint8 *)pixels + (size_t)row * pitch, 0,
		       (size_t)side * sizeof(Uint32));
	{
		static const Uint16 scatter = 0x8412;   /* 5 of 16 cells, offset rows */
		int cell;
		for (cell = 0; cell < K13_BD_TILES * K13_BD_TILES; cell++)
		{
			int ox, oy;
			if (!((scatter >> cell) & 1))
				continue;
			ox = (cell % K13_BD_TILES) * 16;
			oy = (cell / K13_BD_TILES) * 16;
			for (row = 0; row < 16; row++)
			{
				Uint32 src = k13_tileoff + (Uint32)(tile << 5) + (Uint32)row * 2;
				Uint32 *out = (Uint32 *)((Uint8 *)pixels +
				                         (size_t)(oy + row) * pitch) + ox;
				for (col = 0; col < 2; col++)
				{
					Uint8 b0 = k13_ega[0][(src + col) & 0xFFFF];
					Uint8 b1 = k13_ega[1][(src + col) & 0xFFFF];
					Uint8 b2 = k13_ega[2][(src + col) & 0xFFFF];
					Uint8 b3 = k13_ega[3][(src + col) & 0xFFFF];
					for (bit = 0; bit < 8; bit++)
					{
						int sh = 7 - bit;
						int idx = ((b0 >> sh) & 1) | (((b1 >> sh) & 1) << 1) |
						          (((b2 >> sh) & 1) << 2) |
						          (((b3 >> sh) & 1) << 3);
						out[col * 8 + bit] = pal[idx];
					}
				}
			}
		}
	}
	(void)i;
	SDL_UnlockTexture(k13_tex_backdrop);
}

/* fill the window with the pattern, then bevel the picture's edge */
static void k13_present_frame(int ww, int wh, const SDL_Rect *dst)
{
	const int side = 16 * K13_BD_TILES;
	int scale, step, x, y, i;

	if (k13_backdrop_tile() < 0)
		return;                       /* disabled: leave the bars black */
	if (!k13_tex_backdrop || memcmp(k13_bd_pal, k13_palette, 16) != 0)
		k13_backdrop_build();
	if (!k13_tex_backdrop)
		return;

	/* draw the pattern at the same zoom as the game pixels, so it reads as
	   game tiles rather than a fine mosaic */
	scale = dst->h / 240;
	if (scale < 1)
		scale = 1;
	step = side * scale;
	for (y = 0; y < wh; y += step)
		for (x = 0; x < ww; x += step)
		{
			SDL_Rect r = {x, y, step, step};
			SDL_RenderCopy(k13_renderer, k13_tex_backdrop, NULL, &r);
		}

	/* Chunky pixel-art bevel around the artwork, identical to the Keen 4-6
	   build (VL_SDL2_DrawBackdropAndFrame) so the two halves match: black
	   seam, inset bevel, flat brown face, raised bevel, black outline --
	   each layer a whole number of on-screen game pixels so it reads as
	   deliberate pixel art rather than an anti-aliased border. */
	{
		SDL_Rect r = *dst;
		int px = scale;

#define K13_GROW(rect, n) \
	do { (rect).x -= (n); (rect).y -= (n); \
	     (rect).w += 2 * (n); (rect).h += 2 * (n); } while (0)
#define K13_EDGES(rect, t, rTL, gTL, bTL, rBR, gBR, bBR) \
	do { \
		SDL_Rect _b = {(rect).x, (rect).y + (rect).h - (t), (rect).w, (t)}; \
		SDL_Rect _rr = {(rect).x + (rect).w - (t), (rect).y, (t), (rect).h}; \
		SDL_SetRenderDrawColor(k13_renderer, rBR, gBR, bBR, 255); \
		SDL_RenderFillRect(k13_renderer, &_b); \
		SDL_RenderFillRect(k13_renderer, &_rr); \
		{ \
			SDL_Rect _t = {(rect).x, (rect).y, (rect).w, (t)}; \
			SDL_Rect _l = {(rect).x, (rect).y, (t), (rect).h}; \
			SDL_SetRenderDrawColor(k13_renderer, rTL, gTL, bTL, 255); \
			SDL_RenderFillRect(k13_renderer, &_t); \
			SDL_RenderFillRect(k13_renderer, &_l); \
		} \
	} while (0)

		K13_GROW(r, px);                 /* black seam hugging the art */
		K13_EDGES(r, px, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);
		K13_GROW(r, 2 * px);             /* inset: art sits sunken */
		K13_EDGES(r, 2 * px, 0x55, 0x55, 0x55, 0xFF, 0xFF, 0x55);
		K13_GROW(r, 4 * px);             /* flat face */
		K13_EDGES(r, 4 * px, 0xAA, 0x55, 0x00, 0xAA, 0x55, 0x00);
		K13_GROW(r, 2 * px);             /* raised outer bevel */
		K13_EDGES(r, 2 * px, 0xFF, 0xFF, 0x55, 0x55, 0x55, 0x55);
		K13_GROW(r, px);                 /* black outline */
		K13_EDGES(r, px, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);

#undef K13_EDGES
#undef K13_GROW
	}
	(void)i;
}

/* dev harness: K13_TILESHEET=<first> writes a 16x16 contact sheet of the
 * episode's tiles to k13_tiles.ppm and quits, for picking a backdrop tile */
static void k13_tilesheet(int first)
{
	const int cells = 16, side = cells * 16;
	static Uint8 buf[256 * 256];
	FILE *f;
	int cell, row, col, bit, x, y;

	memset(buf, 0, sizeof(buf));
	for (cell = 0; cell < cells * cells; cell++)
	{
		int tile = first + cell;
		int ox = (cell % cells) * 16, oy = (cell / cells) * 16;
		if (tile < 0 || tile >= K13_MAXTILES)
			continue;
		for (row = 0; row < 16; row++)
		{
			Uint32 src = k13_tileoff + (Uint32)(tile << 5) + (Uint32)row * 2;
			for (col = 0; col < 2; col++)
			{
				Uint8 b0 = k13_ega[0][(src + col) & 0xFFFF];
				Uint8 b1 = k13_ega[1][(src + col) & 0xFFFF];
				Uint8 b2 = k13_ega[2][(src + col) & 0xFFFF];
				Uint8 b3 = k13_ega[3][(src + col) & 0xFFFF];
				for (bit = 0; bit < 8; bit++)
				{
					int sh = 7 - bit;
					buf[(oy + row) * side + ox + col * 8 + bit] =
						(Uint8)(((b0 >> sh) & 1) | (((b1 >> sh) & 1) << 1) |
						        (((b2 >> sh) & 1) << 2) | (((b3 >> sh) & 1) << 3));
				}
			}
		}
	}
	f = fopen("k13_tiles.ppm", "wb");
	if (f)
	{
		fprintf(f, "P6\n%d %d\n255\n", side, side);
		for (y = 0; y < side; y++)
			for (x = 0; x < side; x++)
			{
				Uint8 ega = k13_palette[buf[y * side + x] & 15];
				Uint8 rgb[3];
				rgb[0] = (Uint8)((((ega >> 2) & 1) * 0xAA) + (((ega >> 5) & 1) * 0x55));
				rgb[1] = (Uint8)((((ega >> 1) & 1) * 0xAA) + (((ega >> 4) & 1) * 0x55));
				rgb[2] = (Uint8)(((ega & 1) * 0xAA) + (((ega >> 3) & 1) * 0x55));
				fwrite(rgb, 1, 3, f);
			}
		fclose(f);
	}
	fprintf(stderr, "K13 TEST: tile sheet %d..%d\n", first, first + 255);
	fflush(stderr);
	exit(0);
}

static void k13_present(void)
{
	k13_maybe_dump();
#ifdef K13_WITH_SDL
	{
		const char *e = getenv("K13_TILESHEET");
		static int armed;
		if (e && !armed && SDL_GetTicks() > 12000)
		{
			armed = 1;
			k13_tilesheet(atoi(e));
		}
	}
	if (!k13_window)
		k13_sdl_init();
	k13_pump();
	if (!k13_comp_have)
	{
		/* interp-compose at "now" so every present source (K13_Idle,
		   WaitVBL, pacing loop) shows the same live world view */
		long num = (long)(SDL_GetTicks() - k13_refresh_ms);
		long den = ((long)k13_frame_len_tics * 8192000L) / 1193182L;
		if (den < 1)
			den = 1;
		if (num < 0)
			num = 0;
		if (num > den)
			num = den;
		{
			Uint32 t0 = SDL_GetTicks();
			k13_compose(num, den);
			k13_prof[0] += SDL_GetTicks() - t0;
		}
	}
	/* K13_TEST_STATUS: dump once the dialog has been up ~90 presents.
	   K13_TEST_SHOT=<ms>: dump at a wall-clock moment (any screen). */
	if (k13_dialog_active && k13_test_fired)
	{
		static int n;
		if (++n == 90)
			k13_test_shot("k13_shot");
	}
	{
		const char *e = getenv("K13_TEST_SHOT");
		if (e && SDL_GetTicks() >= (Uint32)atoi(e))
			k13_test_shot("k13_shot");
	}
	/* K13_ARTDUMP=<file>: wait for the TITLE SCREEN (title map panned to the
	   title pic), give it a moment to finish drawing, write it as a PPM and
	   exit.  The launcher uses this to pull each episode's own starting-
	   screen art into its tile -- rendered by the game from the player's own
	   data, so nothing is redistributed. */
	{
		const char *e = getenv("K13_ARTDUMP");

		if (e && level == TITLEMAP && originx == 2 * TILEGLOBAL)
		{
			static int settle, done;

			/* K13_ARTDUMP_STAY=1 (Android): no hidden windows there, so
			   the first natural run doubles as the art pull -- dump only
			   if the file is missing, and keep playing instead of
			   exiting. */
			if (!done && getenv("K13_ARTDUMP_STAY"))
			{
				FILE *probe = fopen(e, "rb");
				if (probe)
				{
					fclose(probe);
					done = 1;
				}
			}
			if (!done && ++settle >= 45)
			{
				done = 1;
				k13_dump_screen(e);
				/* also drop this episode's backdrop tile as a 16x16 PPM,
				   for the launcher's own background */
				{
					int tile = K13_GetBackdrop();
					FILE *bf = (tile >= 0 && tile < K13_MAXTILES)
					           ? fopen("backdrop_tile.ppm", "wb") : NULL;
					if (bf)
					{
						int row, col, bit;
						fprintf(bf, "P6\n16 16\n255\n");
						for (row = 0; row < 16; row++)
						{
							Uint32 src = k13_tileoff + (Uint32)(tile << 5) +
							             (Uint32)row * 2;
							for (col = 0; col < 2; col++)
							{
								Uint8 b0 = k13_ega[0][(src + col) & 0xFFFF];
								Uint8 b1 = k13_ega[1][(src + col) & 0xFFFF];
								Uint8 b2 = k13_ega[2][(src + col) & 0xFFFF];
								Uint8 b3 = k13_ega[3][(src + col) & 0xFFFF];
								for (bit = 0; bit < 8; bit++)
								{
									int sh = 7 - bit;
									Uint8 idx = (Uint8)(((b0 >> sh) & 1) |
									            (((b1 >> sh) & 1) << 1) |
									            (((b2 >> sh) & 1) << 2) |
									            (((b3 >> sh) & 1) << 3));
									Uint32 c = k13_ega_rgb(k13_palette[idx]);
									Uint8 rgb[3] = {(Uint8)(c >> 16),
									                (Uint8)(c >> 8), (Uint8)c};
									fwrite(rgb, 1, 3, bf);
								}
							}
						}
						fclose(bf);
					}
				}
				fprintf(stderr, "K13 ARTDUMP: %s\n", e);
				fflush(stderr);
				if (!getenv("K13_ARTDUMP_STAY"))
					exit(0);
			}
		}
	}
	/* K13_TEST_PAGEDIFF=<ms>: report how far the two EGA pages differ inside
	   the visible window, then quit.  The screen flips page every refresh, so
	   anything present on only one page is something the player sees flash.
	   This is the regression check for the dialog-pin bug that made the
	   high-score text flash once any window had closed over it: healthy
	   screens differ only by a frame of tile animation (tens of bytes), the
	   bug showed thousands. */
	{
		const char *e = getenv("K13_TEST_PAGEDIFF");

		if (e && SDL_GetTicks() >= (Uint32)atoi(e))
		{
			Uint32 st = ((Uint32)k13_crtc_reg[0x0C] << 8) | k13_crtc_reg[0x0D];
			Uint32 other = st ^ 0x3000;
			int plane, i, bad = 0;
			static int best = -1, samples;

			for (plane = 0; plane < 4; plane++)
				for (i = 0; i < SCREENWIDTH * 200; i++)
					if (k13_ega[plane][(st + i) & 0xFFFF] !=
					    k13_ega[plane][(other + i) & 0xFFFF])
						bad++;
			/* Animated tiles legitimately sit one step apart between pages, so
			   a single sample is noisy: take the MINIMUM over a window.  Real
			   content missing from a page never aligns, so it stays high. */
			if (best < 0 || bad < best)
				best = bad;
			if (++samples >= 90)
			{
				fprintf(stderr, "K13 PAGEDIFF: %d bytes (min of %d)\n",
				        best, samples);
				fflush(stderr);
				exit(0);
			}
		}
	}
	{
		static int hb;
		if (getenv("K13_TRACE") && ((++hb) & 127) == 1)
		{
			fprintf(stderr,
			        "K13 HB: tc=%ld live=%d w=%d have=%d nspr=%d\n",
			        timecount, k13_world_live_dbg(), k13_comp_w, k13_comp_have,
			        k13_nspr_dbg());
			fflush(stderr);
		}
	}
	{
		Uint32 pal[16];
		Uint32 *pixels;
		int pitch, x, y;
		SDL_Texture *srctex;
		int srcw;
		Uint32 k13_prof_t0 = SDL_GetTicks();

		for (x = 0; x < 16; x++)
			pal[x] = k13_ega_rgb(k13_palette[x]);

		if (k13_comp_have)
		{
			/* composed wide frame */
			srctex = k13_texture_wide;
			srcw = k13_comp_w;
			SDL_LockTexture(k13_texture_wide, NULL, (void **)&pixels, &pitch);
			for (y = 0; y < 200; y++)
			{
				const Uint8 *in = k13_comp + (size_t)y * K13_COMP_MAXW;
				Uint32 *out = (Uint32 *)((Uint8 *)pixels + (size_t)y * pitch);
				for (x = 0; x < srcw; x++)
					out[x] = pal[in[x] & 15];
			}
			if (K13_GetScoreBox() && k13_world_live_dbg())
				k13_scorebox_stamp((Uint8 *)pixels, pitch, srcw, pal);
			SDL_UnlockTexture(k13_texture_wide);
		}
		else
		{
			/* Classic EGA page view: present exactly what the CRTC is
			   programmed to show -- start address plus pel pan.  This is
			   the hardware behaviour, so it is right for every screen:
			   the game only ever draws to screenseg, which VidInitDraw
			   derives from that same start address (and graphics init
			   sets both to page 0).  Popups draw onto the VISIBLE page,
			   so they show up here with no special case -- and the view
			   no longer shifts by the start address' low nibble when one
			   opens, which used to jog the background sideways. */
			Uint32 start = ((Uint32)k13_crtc_reg[0x0C] << 8) |
			               k13_crtc_reg[0x0D];
			int pan = (int)k13_screenpan;
			srctex = k13_texture;
			srcw = 320;
			SDL_LockTexture(k13_texture, NULL, (void **)&pixels, &pitch);
			for (y = 0; y < 200; y++)
			{
				Uint32 rowbase = start + (Uint32)y * SCREENWIDTH;
				Uint32 *out = (Uint32 *)((Uint8 *)pixels + (size_t)y * pitch);
				for (x = 0; x < 320; x++)
				{
					Uint32 px = (Uint32)x + (Uint32)pan;
					Uint32 addr = (rowbase + (px >> 3)) & 0xFFFF;
					int bit = 7 - (int)(px & 7);
					int idx = ((k13_ega[0][addr] >> bit) & 1) |
					          (((k13_ega[1][addr] >> bit) & 1) << 1) |
					          (((k13_ega[2][addr] >> bit) & 1) << 2) |
					          (((k13_ega[3][addr] >> bit) & 1) << 3);
					out[x] = pal[idx];
				}
			}
			if (K13_GetScoreBox() && k13_world_live_dbg())
				k13_scorebox_stamp((Uint8 *)pixels, pitch, srcw, pal);
			SDL_UnlockTexture(k13_texture);
		}
		k13_comp_have = 0; /* consumed; compose refreshes it per present */
		k13_prof[1] += SDL_GetTicks() - k13_prof_t0;

		/* pass 1: integer 4x prescale into the render target (nearest) */
		{
			SDL_Rect src = {0, 0, srcw, 200};
			SDL_Rect pre = {0, 0, srcw * 4, 800};
			{
				static int traced;
				if (!traced && getenv("K13_TRACE") && srcw > 320)
				{
					int ww, wh;
					traced = 1;
					SDL_GetRendererOutputSize(k13_renderer, &ww, &wh);
					fprintf(stderr,
					        "K13 TP: present srcw=%d target=%p out=%dx%d rc=%d\n",
					        srcw, (void *)k13_target, ww, wh,
					        SDL_SetRenderTarget(k13_renderer, k13_target));
					SDL_SetRenderTarget(k13_renderer, NULL);
					fflush(stderr);
				}
			}
			SDL_SetRenderTarget(k13_renderer, k13_target);
			SDL_RenderCopy(k13_renderer, srctex, &src, &pre);
			SDL_SetRenderTarget(k13_renderer, NULL);

			/* pass 2: aspect-correct fit (EGA 1.2 pixel aspect: srcw x 240) */
			{
				int ww, wh;
				SDL_Rect dst;
				double aspect = (double)srcw / 240.0;
				SDL_GetRendererOutputSize(k13_renderer, &ww, &wh);
				if (srcw == 320 && k13_backdrop_tile() >= 0)
				{
					/* Classic 4:3 screens (menus, intros, transitions): frame
					   on ALL sides, not just where letterbox bars happen to
					   be.  Reserve 16 game px per side -- the 10 px bevel plus
					   a sliver of backdrop beyond it -- by fitting the art
					   into the window minus that margin, so the frame fully
					   surrounds the screen instead of two floating columns. */
					double sc = (ww / (aspect * 240.0 + 32.0) <
					             wh / 272.0)
					            ? ww / (aspect * 240.0 + 32.0)
					            : wh / 272.0;
					dst.w = (int)(aspect * 240.0 * sc + 0.5);
					dst.h = (int)(240.0 * sc + 0.5);
					dst.x = (ww - dst.w) / 2;
					dst.y = (wh - dst.h) / 2;
				}
				else if ((double)ww / (double)wh > aspect)
				{
					dst.h = wh;
					dst.w = (int)(wh * aspect + 0.5);
					dst.x = (ww - dst.w) / 2;
					dst.y = 0;
				}
				else
				{
					dst.w = ww;
					dst.h = (int)(ww / aspect + 0.5);
					dst.x = 0;
					dst.y = (wh - dst.h) / 2;
				}
				SDL_SetRenderDrawColor(k13_renderer, 0, 0, 0, 255);
				SDL_RenderClear(k13_renderer);
				/* tiled backdrop + bevel instead of bare black bars */
				k13_present_frame(ww, wh, &dst);
				SDL_RenderCopy(k13_renderer, k13_target, &pre, &dst);
			}
		}
		/* dev harness: K13_TEST_WINSHOT=<ms> grabs the whole window (so the
		   letterbox backdrop and frame are included), read back before the
		   swap while the backbuffer still holds this frame */
		{
			const char *e = getenv("K13_TEST_WINSHOT");
			if (e && SDL_GetTicks() >= (Uint32)atoi(e))
			{
				int ww, wh;
				SDL_GetRendererOutputSize(k13_renderer, &ww, &wh);
				{
					Uint8 *px = (Uint8 *)malloc((size_t)ww * wh * 4);
					if (px && SDL_RenderReadPixels(k13_renderer, NULL,
					                               SDL_PIXELFORMAT_ARGB8888,
					                               px, ww * 4) == 0)
					{
						FILE *f = fopen("k13_window.ppm", "wb");
						if (f)
						{
							int x, y;
							fprintf(f, "P6\n%d %d\n255\n", ww, wh);
							for (y = 0; y < wh; y++)
								for (x = 0; x < ww; x++)
								{
									Uint8 *p = px + ((size_t)y * ww + x) * 4;
									Uint8 rgb[3] = {p[2], p[1], p[0]};
									fwrite(rgb, 1, 3, f);
								}
							fclose(f);
						}
						fprintf(stderr, "K13 TEST: window shot %dx%d\n", ww, wh);
						fflush(stderr);
					}
					free(px);
				}
				exit(0);
			}
		}
		{
			Uint32 t2 = SDL_GetTicks();
			SDL_RenderPresent(k13_renderer);
			k13_prof[3] += SDL_GetTicks() - t2;
		}
		k13_prof_n++;
		if (getenv("K13_TRACE") && (k13_prof_n & 63) == 0)
		{
			fprintf(stderr, "K13 PROF n=%lu compose=%lu upload=%lu present=%lu (ms totals)\n",
			        (unsigned long)k13_prof_n, (unsigned long)k13_prof[0],
			        (unsigned long)k13_prof[1], (unsigned long)k13_prof[3]);
			fflush(stderr);
		}
	}
#endif
}

#include "k13_compositor.inc"
#include "k13_quicksave.inc"

/*
 * Self-test (K13_QS_TEST=<frame>): at that replay frame, quicksave, scramble
 * nothing, quickload, and compare the seven component hashes against what
 * they were before.  Serialisation bugs show up as a named mismatch rather
 * than as a level that feels subtly wrong hours later.
 */
static void k13_qs_selftest(void)
{
	static int done;
	const char *e = getenv("K13_QS_TEST");
	Uint32 before[K13_NUMHASH], after[K13_NUMHASH];
	int i, bad = -1;

	if (done || !e || k13_vframe != (Uint32)atoi(e))
		return;
	done = 1;

	k13_state_hashes(before);
	if (!K13_QuickSave())
	{
		fprintf(stderr, "K13 QS TEST: save refused\n");
		fflush(stderr);
		exit(1);
	}
	/* wipe the live state so a lazy load cannot pass by accident */
	memset(objlist, 0, sizeof(objlist));
	memset(pobjlist, 0, sizeof(pobjlist));
	memset(&gamestate, 0, sizeof(gamestate));
	originx = originy = 0;
	if (!K13_QuickLoad())
	{
		fprintf(stderr, "K13 QS TEST: load failed\n");
		fflush(stderr);
		exit(1);
	}
	k13_state_hashes(after);
	for (i = 0; i < K13_NUMHASH; i++)
		if (before[i] != after[i] && bad < 0)
			bad = i;
	if (bad >= 0)
		fprintf(stderr, "K13 QS TEST: FAIL -- %s differs after roundtrip\n",
		        k13_hash_names[bad]);
	else
		fprintf(stderr, "K13 QS TEST: PASS -- all %d state hashes match after "
		                "save/wipe/load at frame %lu\n",
		        K13_NUMHASH, (unsigned long)k13_vframe);
	fflush(stderr);
	exit(bad >= 0 ? 1 : 0);
}

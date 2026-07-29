/*
 * Keen Launcher -- the shell that fronts all seven games.
 *
 * Design notes it follows (DESIGN_NOTES.md):
 *   * Couch-first.  Everything is reachable with a gamepad; the keyboard is
 *     never required.  Big targets, one clear selection, no pointer.
 *   * Looks like it belongs.  EGA 16-colour palette, hard pixels, and the
 *     same five-layer bevel and starfield backdrop the games themselves draw,
 *     so the shell reads as part of the collection rather than a wrapper.
 *   * No new dependencies.  SDL2 (already vendored) plus a baked bitmap font.
 *     Deliberately no ImGui: the notes reserve it for "if used at all", and a
 *     modern widget toolkit would look foreign here.
 *
 * Slots are TABLE DRIVEN and detected at startup by looking for the files
 * each game needs.  A game that is not installed shows as unavailable rather
 * than vanishing, so the collection always reads as seven, and Keen Dreams
 * lights up on its own the moment its runtime and data are in place -- no
 * code change needed.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "SDL.h"
#include "launcher_font.h"
#include "launcher_font_big.h"

#ifdef _WIN32
#include <windows.h>
#endif

/* ------------------------------------------------------------------ canvas */

/* The canvas is a LOGICAL surface whose size follows the window.
 *
 * Stretching one fixed canvas to fit is what warped everything when the
 * window was resized.  Letterboxing would fix the warp but waste space and
 * put bars around a starfield.  Instead the pixel scale is always a whole
 * number (hard pixels, never resampled) and the logical size is simply the
 * window divided by that scale -- so a wide window gets a wider canvas and a
 * tall one gets a taller canvas, the tile grid re-centres, and nothing is
 * ever squashed.  CANVAS_MAX_* only bounds the buffer. */
#define CANVAS_MAX_W 960
#define CANVAS_MAX_H 600
#define CANVAS_MIN_W 400
#define CANVAS_MIN_H 230
#define CANVAS_REF_W 426      /* design size: scale is derived from this */
#define CANVAS_REF_H 240

/* EGA palette, same 16 colours the games use */
static const Uint32 ega[16] = {
	0xFF000000, 0xFF0000AA, 0xFF00AA00, 0xFF00AAAA,
	0xFFAA0000, 0xFFAA00AA, 0xFFAA5500, 0xFFAAAAAA,
	0xFF555555, 0xFF5555FF, 0xFF55FF55, 0xFF55FFFF,
	0xFFFF5555, 0xFFFF55FF, 0xFFFFFF55, 0xFFFFFFFF
};

static Uint32 canvas[CANVAS_MAX_W * CANVAS_MAX_H];
static int cw = CANVAS_REF_W, ch = CANVAS_REF_H;   /* current logical size */

/* Choose the largest whole-number pixel scale that still shows the design
 * area, then let the logical canvas be whatever the window can hold at that
 * scale. */
static int canvas_fit(int winw, int winh)
{
	int scale = winw / CANVAS_REF_W;
	int vs = winh / CANVAS_REF_H;

	if (vs < scale)
		scale = vs;
	if (scale < 1)
		scale = 1;

	cw = winw / scale;
	ch = winh / scale;
	if (cw > CANVAS_MAX_W) cw = CANVAS_MAX_W;
	if (ch > CANVAS_MAX_H) ch = CANVAS_MAX_H;
	if (cw < CANVAS_MIN_W) cw = CANVAS_MIN_W;
	if (ch < CANVAS_MIN_H) ch = CANVAS_MIN_H;
	return scale;
}

static void cls(int colour)
{
	int i;
	for (i = 0; i < cw * ch; i++)
		canvas[i] = ega[colour & 15];
}

static void px(int x, int y, int colour)
{
	if (x >= 0 && x < cw && y >= 0 && y < ch)
		canvas[y * cw + x] = ega[colour & 15];
}

static void bar(int x, int y, int w, int h, int colour)
{
	int i, j;
	for (j = y; j < y + h; j++)
		for (i = x; i < x + w; i++)
			px(i, j, colour);
}

static void text(int x, int y, const char *s, int colour)
{
	for (; *s; s++)
	{
		int c = (unsigned char)*s;
		if (c >= LFONT_FIRST && c <= LFONT_LAST)
		{
			int row, bit;
			const unsigned char *g = lfont[c - LFONT_FIRST];
			for (row = 0; row < LFONT_H; row++)
				for (bit = 0; bit < LFONT_W; bit++)
					if (g[row] & (1 << (7 - bit)))
						px(x + bit, y + row, colour);
		}
		x += LFONT_W;
	}
}

static int text_w(const char *s)
{
	return (int)strlen(s) * LFONT_W;
}

static void text_centred(int cx, int y, const char *s, int colour)
{
	text(cx - text_w(s) / 2, y, s, colour);
}

/* Thick display text with the games' chunky bevel: a black outline ring,
 * a bright edge up-left, a dark edge down-right, and the face on top --
 * the same emboss idiom as the title art, still hard pixels. */
static void text_big_pass(int x, int y, const char *s, int colour)
{
	for (; *s; s++)
	{
		int c = (unsigned char)*s;
		if (c >= LBFONT_FIRST && c <= LBFONT_LAST)
		{
			int row, bit;
			const unsigned short *g = lbfont[c - LBFONT_FIRST];
			for (row = 0; row < LBFONT_H; row++)
				for (bit = 0; bit < LBFONT_W; bit++)
					if (g[row] & (1 << (15 - bit)))
						px(x + bit, y + row, colour);
		}
		x += LBFONT_W;
	}
}

static int text_big_w(const char *s)
{
	return (int)strlen(s) * LBFONT_W;
}

static void text_big(int x, int y, const char *s, int face)
{
	static const int dx[8] = {-1, 0, 1, -1, 1, -1, 0, 1};
	static const int dy[8] = {-1, -1, -1, 0, 0, 1, 1, 1};
	int hi = (face | 8) == face ? 15 : (face | 8);
	int lo = face & 7;
	int i;

	for (i = 0; i < 8; i++)
		text_big_pass(x + 2 * dx[i], y + 2 * dy[i], s, 0);   /* outline */
	text_big_pass(x + 1, y + 1, s, lo);                      /* shade   */
	text_big_pass(x - 1, y - 1, s, hi);                      /* light   */
	text_big_pass(x, y, s, face);                            /* face    */
}

static void text_big_centred(int cx, int y, const char *s, int face)
{
	text_big(cx - text_big_w(s) / 2, y, s, face);
}

/* The games' five-layer frame, in miniature: black seam, sunken inset, brown
 * face, raised bevel, black outline.  Same idiom, so the shell and the games
 * feel like one product. */
static void bevel(int x, int y, int w, int h, int face)
{
	struct { int t, tl, br; } layer[5] = {
		{1, 0, 0},        /* black seam        */
		{1, 8, 14},       /* inset: dark TL    */
		{2, face, face},  /* flat face         */
		{1, 15, 8},       /* raised: light TL  */
		{1, 0, 0}         /* black outline     */
	};
	int i, g = 0;

	for (i = 0; i < 5; i++)
	{
		int t = layer[i].t;
		int ox = x - g - t, oy = y - g - t;
		int ow = w + 2 * (g + t), oh = h + 2 * (g + t);
		bar(ox, oy, ow, t, layer[i].tl);              /* top    */
		bar(ox, oy, t, oh, layer[i].tl);              /* left   */
		bar(ox, oy + oh - t, ow, t, layer[i].br);     /* bottom */
		bar(ox + ow - t, oy, t, oh, layer[i].br);     /* right  */
		g += t;
	}
}

/* Sparse starfield, the same trick as the games' letterbox backdrop: a fixed
 * pseudo-random scatter rather than a repeating tile, so it does not read as
 * wallpaper. */
static void starfield(void)
{
	unsigned seed = 0x1234;
	int i;

	cls(0);
	for (i = 0; i < (cw * ch) / 850; i++)
	{
		int x, y;
		seed = seed * 1103515245u + 12345u;
		x = (seed >> 16) % cw;
		seed = seed * 1103515245u + 12345u;
		y = (seed >> 16) % ch;
		px(x, y, ((i & 7) == 0) ? 15 : 7);
		if ((i & 3) == 0)
		{
			px(x - 1, y, 8);
			px(x + 1, y, 8);
			px(x, y - 1, 8);
			px(x, y + 1, 8);
		}
	}
}

/* ------------------------------------------------------------------- slots */

typedef struct
{
	const char *title;      /* shown large   */
	const char *subtitle;   /* shown small   */
	const char *dir;        /* working directory to launch from */
	const char *exe;        /* executable, relative to dir */
	const char *args;       /* extra arguments, or "" */
	const char *needs;      /* a data file that must exist in dir */
	int accent;             /* EGA colour for this game's tile */
	int available;          /* filled in by detect() */
	/* Title-screen art, pulled automatically the first time the game is
	 * detected: the ENGINE renders its own title screen from the player's
	 * data into artfile (so nothing is redistributed), and the launcher
	 * shows it in the tile.  artenv names an env var carrying the output
	 * path (Keen 1-3 / Dreams); artargs are extra arguments (Omnispeak's
	 * /ARTDUMP).  thumb is the decoded tile-sized image. */
	const char *artfile;
	const char *artenv;
	const char *artargs;
	Uint32 *thumb;
} Slot;

static Slot slots[] = {
	{"KEEN 1", "MAROONED ON MARS",   "keen13/gamedata",  "keen13.exe",         "",            "EGAHEAD.CK1",   9,  0,
	 "title_art.ppm", "K13_ARTDUMP", "", NULL},
	{"KEEN 2", "THE EARTH EXPLODES", "keen13/gamedata2", "keen13_ep2.exe",     "",            "EGAHEAD.CK2",   11, 0,
	 "title_art.ppm", "K13_ARTDUMP", "", NULL},
	{"KEEN 3", "KEEN MUST DIE!",     "keen13/gamedata3", "keen13_ep3.exe",     "",            "EGAHEAD.CK3",   13, 0,
	 "title_art.ppm", "K13_ARTDUMP", "", NULL},
	{"KEEN 4", "SECRET OF THE ORACLE","rt",              "omnispeak-wide.exe", "/EPISODE 4",  "EGAGRAPH.CK4",  10, 0,
	 "title_art_4.ppm", NULL, "/EPISODE 4 /ARTDUMP title_art_4.ppm /WINDOWED", NULL},
	{"KEEN 5", "THE ARMAGEDDON MACHINE","rt",            "omnispeak-wide.exe", "/EPISODE 5",  "EGAGRAPH.CK5",  14, 0,
	 "title_art_5.ppm", NULL, "/EPISODE 5 /ARTDUMP title_art_5.ppm /WINDOWED", NULL},
	{"KEEN 6", "ALIENS ATE MY BABYSITTER","rt",          "omnispeak-wide.exe", "/EPISODE 6",  "EGAGRAPH.CK6",  12, 0,
	 "title_art_6.ppm", NULL, "/EPISODE 6 /ARTDUMP title_art_6.ppm /WINDOWED", NULL},
	/* Slot 7: Keen Dreams via ReflectionHLE (refkeen).  kdreams.exe here is
	 * the DOS executable -- refkeen reads its embedded resources -- so the
	 * runtime keeps its own name.  cfg/ and data/ keep settings and saves
	 * inside the collection. */
	{"KEEN DREAMS", "THE LOST EPISODE", "keendreams/game", "reflection-kdreams.exe",
	 "-gamever kdreamse100 -cfgdir cfg -datadir data",     "egagraph.kdr",  3,  0,
	 "title_art.ppm", "KL_ARTDUMP",
	 "-gamever kdreamse100 -cfgdir artcfg -datadir data", NULL}
};

#define NSLOTS ((int)(sizeof(slots) / sizeof(slots[0])))

static char root[512];

static int file_exists(const char *path)
{
	FILE *f = fopen(path, "rb");
	if (!f)
		return 0;
	fclose(f);
	return 1;
}

/* A slot is playable only if BOTH its runtime and its data are present --
 * reporting "ready" and then failing to start would be worse than greying it
 * out, and it is the data half that is usually missing. */
static void detect(void)
{
	int i;
	for (i = 0; i < NSLOTS; i++)
	{
		char exe[768], data[768];
		snprintf(exe, sizeof(exe), "%s/%s/%s", root, slots[i].dir, slots[i].exe);
		snprintf(data, sizeof(data), "%s/%s/%s", root, slots[i].dir, slots[i].needs);
		slots[i].available = file_exists(exe) && file_exists(data);
	}
}

#define TILE_W 88
#define TILE_H 56

/* ------------------------------------------------------------- title art */

/* First-run setup feedback: the art/audio pulls run engines in HIDDEN
 * windows and block the launcher, so say what is happening on screen
 * instead of freezing silently (or, before, flashing game windows the
 * user would understandably close -- which aborted the pull). */
static void present(SDL_Renderer *ren, SDL_Texture *tex);
static SDL_Renderer *g_notice_ren;
static SDL_Texture *g_notice_tex;

static void pull_notice(const char *msg)
{
	if (!g_notice_ren)
		return;
	starfield();
	text_big_centred(cw / 2, 8, "MEGAROCKET", 14);
	text_centred(cw / 2, ch / 2 - 12, "FIRST-TIME SETUP", 14);
	text_centred(cw / 2, ch / 2 + 4, msg, 7);
	text_centred(cw / 2, ch / 2 + 20, "THIS RUNS ONCE AND TAKES A MOMENT", 8);
	present(g_notice_ren, g_notice_tex);
}

/* Blocking, dismissible error screen.
 *
 * A launch that fails silently is indistinguishable from a broken launcher:
 * the player presses Play, nothing happens, and there is no way to find out
 * why.  stderr is no help -- this is a windowed SDL app with no console
 * attached, so anything printed there is discarded.  Every failure the player
 * can actually hit needs to say what happened and what to do about it. */
static void error_notice(const char *title, const char *msg, const char *detail)
{
	SDL_Event ev;
	int waiting = 1;

	if (!g_notice_ren)
	{
		fprintf(stderr, "%s: %s%s%s\n", title, msg,
		        detail && detail[0] ? " - " : "", detail ? detail : "");
		return;
	}

	starfield();
	text_big_centred(cw / 2, 8, "MEGAROCKET", 14);
	text_centred(cw / 2, ch / 2 - 24, title, 12);
	text_centred(cw / 2, ch / 2 - 8, msg, 14);
	if (detail && detail[0])
		text_centred(cw / 2, ch / 2 + 8, detail, 7);
	text_centred(cw / 2, ch / 2 + 28, "PRESS ANY KEY OR BUTTON", 8);
	present(g_notice_ren, g_notice_tex);

	while (waiting)
	{
		while (SDL_PollEvent(&ev))
		{
			if (ev.type == SDL_KEYDOWN || ev.type == SDL_CONTROLLERBUTTONDOWN)
				waiting = 0;
			else if (ev.type == SDL_QUIT)
			{
				/* Re-post it: dismissing the error must not swallow a quit. */
				SDL_PushEvent(&ev);
				waiting = 0;
			}
		}
		SDL_Delay(16);
	}
}

/* run one engine in art-dump mode and wait for it (bounded) */
static void art_pull(const Slot *s)
{
#ifdef _WIN32
	char cwd[768], cmd[1024];
	STARTUPINFOA si;
	PROCESS_INFORMATION pi;

	snprintf(cwd, sizeof(cwd), "%s/%s", root, s->dir);

	/* the pulls render into video memory, not the screen: run them with
	   hidden windows so nothing pops up over the launcher */
	SetEnvironmentVariableA("K13_HIDDEN", "1");
	SetEnvironmentVariableA("OMNI_HIDDEN", "1");
	if (s->artenv)
	{
		SetEnvironmentVariableA(s->artenv, s->artfile);
		SetEnvironmentVariableA("K13_WINDOWED", "1"); /* no fullscreen flash */
	}
	if (s->artargs && s->artargs[0])
		snprintf(cmd, sizeof(cmd), "\"%s\\%s\" %s", cwd, s->exe, s->artargs);
	else
		snprintf(cmd, sizeof(cmd), "\"%s\\%s\"", cwd, s->exe);

	memset(&si, 0, sizeof(si));
	si.cb = sizeof(si);
	memset(&pi, 0, sizeof(pi));
	if (CreateProcessA(NULL, cmd, NULL, NULL, FALSE, 0, NULL, cwd, &si, &pi))
	{
		/* a title screen takes a few seconds; never hang the launcher */
		if (WaitForSingleObject(pi.hProcess, 30000) == WAIT_TIMEOUT)
			TerminateProcess(pi.hProcess, 1);
		CloseHandle(pi.hProcess);
		CloseHandle(pi.hThread);
	}
	if (s->artenv)
	{
		SetEnvironmentVariableA(s->artenv, NULL);
		SetEnvironmentVariableA("K13_WINDOWED", NULL);
	}
	SetEnvironmentVariableA("K13_HIDDEN", NULL);
	SetEnvironmentVariableA("OMNI_HIDDEN", NULL);
#endif
}

/* decode a P6 PPM (the engines dump 320x200) into a tile-sized thumbnail:
 * cover-fit with nearest sampling, centred crop */
static Uint32 *art_thumb(const char *path)
{
	FILE *f = fopen(path, "rb");
	int w, h, maxv, x, y;
	unsigned char *pix;
	Uint32 *out;
	double sx, sy, sc;
	int cropw, croph, offx, offy;

	if (!f)
		return NULL;
	if (fscanf(f, "P6 %d %d %d", &w, &h, &maxv) != 3 || w <= 0 || h <= 0 ||
	    w > 1024 || h > 1024)
	{
		fclose(f);
		return NULL;
	}
	fgetc(f); /* single whitespace after the header */
	pix = (unsigned char *)malloc((size_t)w * h * 3);
	if (!pix || fread(pix, 3, (size_t)w * h, f) != (size_t)w * h)
	{
		free(pix);
		fclose(f);
		return NULL;
	}
	fclose(f);

	out = (Uint32 *)malloc(sizeof(Uint32) * TILE_W * TILE_H);
	if (!out)
	{
		free(pix);
		return NULL;
	}
	sx = (double)TILE_W / w;
	sy = (double)TILE_H / h;
	sc = sx > sy ? sx : sy;               /* cover: crop the long axis */
	cropw = (int)(TILE_W / sc + 0.5);
	croph = (int)(TILE_H / sc + 0.5);
	offx = (w - cropw) / 2;
	offy = (h - croph) / 2;
	for (y = 0; y < TILE_H; y++)
		for (x = 0; x < TILE_W; x++)
		{
			int px2 = offx + (int)((x + 0.5) * cropw / TILE_W);
			int py2 = offy + (int)((y + 0.5) * croph / TILE_H);
			const unsigned char *p;

			if (px2 < 0) px2 = 0;
			if (py2 < 0) py2 = 0;
			if (px2 >= w) px2 = w - 1;
			if (py2 >= h) py2 = h - 1;
			p = pix + ((size_t)py2 * w + px2) * 3;
			out[y * TILE_W + x] =
				0xFF000000u | ((Uint32)p[0] << 16) | ((Uint32)p[1] << 8) | p[2];
		}
	free(pix);
	return out;
}

/* Background tile pulled from the installed games' own assets (each engine
 * dumps its chosen backdrop tile beside the title art).  Starfield-like
 * tiles (mostly black) scatter like the games' letterbox backdrop; solid
 * textures tile continuously through a dim so they stay behind the UI. */
static Uint32 bg_tile[16 * 16];
static int bg_have, bg_dark;

static void bg_scan(void)
{
	/* priority: Keen 1..3 starfields first, then 4..6, then Dreams */
	int i;

	if (bg_have)
		return;
	for (i = 0; i < NSLOTS; i++)
	{
		char path[768], name[64];
		const char *at;
		FILE *f;
		int w, h, maxv, n, dark = 0;
		unsigned char pix[16 * 16 * 3];

		if (!slots[i].available)
			continue;
		at = strstr(slots[i].artfile, "title_art");
		if (at)
			snprintf(name, sizeof(name), "%.*sbackdrop_tile%s",
			         (int)(at - slots[i].artfile), slots[i].artfile, at + 9);
		else
			snprintf(name, sizeof(name), "backdrop_tile.ppm");
		snprintf(path, sizeof(path), "%s/%s/%s", root, slots[i].dir, name);
		f = fopen(path, "rb");
		if (!f)
			continue;
		if (fscanf(f, "P6 %d %d %d", &w, &h, &maxv) != 3 || w != 16 || h != 16)
		{
			fclose(f);
			continue;
		}
		fgetc(f);
		if (fread(pix, 3, 16 * 16, f) != 16 * 16)
		{
			fclose(f);
			continue;
		}
		fclose(f);
		for (n = 0; n < 16 * 16; n++)
		{
			int lum = pix[n * 3] + pix[n * 3 + 1] + pix[n * 3 + 2];
			if (lum < 90)
				dark++;
			bg_tile[n] = 0xFF000000u | ((Uint32)pix[n * 3] << 16) |
			             ((Uint32)pix[n * 3 + 1] << 8) | pix[n * 3 + 2];
		}
		bg_dark = dark > (16 * 16) * 6 / 10; /* mostly black = starfield */
		bg_have = 1;
		return;
	}
}

static void bg_draw(void)
{
	int tx, ty, x, y;

	for (ty = 0; ty * 16 < ch; ty++)
		for (tx = 0; tx * 16 < cw; tx++)
		{
			/* starfield tiles scatter (5 of 16 cells, same mask as the
			   games); solid textures tile every cell, dimmed */
			int cell = (ty & 3) * 4 + (tx & 3);
			int on = bg_dark ? ((0x8412 >> cell) & 1) : 1;

			for (y = 0; y < 16; y++)
			{
				int py2 = ty * 16 + y;
				if (py2 >= ch)
					break;
				for (x = 0; x < 16; x++)
				{
					int px2 = tx * 16 + x;
					Uint32 c;
					if (px2 >= cw)
						break;
					if (!on)
					{
						canvas[py2 * cw + px2] = 0xFF000000u;
						continue;
					}
					c = bg_tile[y * 16 + x];
					if (!bg_dark)
						c = 0xFF000000u | ((c >> 1) & 0x007F7F7Fu); /* dim */
					canvas[py2 * cw + px2] = c;
				}
			}
		}
}

/* pull missing art (engines render their own title screens) + load thumbs */
static void art_refresh(void)
{
	int i;

	for (i = 0; i < NSLOTS; i++)
	{
		char path[768];

		if (!slots[i].available || slots[i].thumb)
			continue;
		snprintf(path, sizeof(path), "%s/%s/%s", root, slots[i].dir,
		         slots[i].artfile);
		if (!file_exists(path))
		{
			/* Dreams runs fullscreen by default; give the dump run its own
			   windowed cfg dir so nothing flashes over the whole screen */
			if (slots[i].artenv && slots[i].artenv[0] == 'K' &&
			    slots[i].artenv[1] == 'L')
			{
				char acdir[768], accfg[800];
				FILE *cf;

				snprintf(acdir, sizeof(acdir), "%s/%s/artcfg", root,
				         slots[i].dir);
#ifdef _WIN32
				CreateDirectoryA(acdir, NULL);
#endif
				snprintf(accfg, sizeof(accfg), "%s/reflection-kdreams.cfg",
				         acdir);
				cf = fopen(accfg, "w");
				if (cf)
				{
					fputs("fullscreen=false\n", cf);
					fclose(cf);
				}
			}
			{
				char note[96];

				snprintf(note, sizeof(note),
				         "RENDERING %s TITLE ART FROM YOUR GAME FILES",
				         slots[i].title);
				pull_notice(note);
			}
			art_pull(&slots[i]);
		}
		if (file_exists(path))
			slots[i].thumb = art_thumb(path);
	}
}

/* ---------------------------------------------------- Galaxy audio pull */

/* The Keen 1-3 Galaxy-audio toggles play sounds and music rendered from
 * the player's OWN Keen 4/5 data.  Nothing ships: when those slots are
 * READY, their engine dumps the audio locally (same idea as the title-art
 * pull) and the results are copied into each 1-3 game folder.  Without
 * Keen 4/5 the toggles simply read N/A in the games' Options menus. */

static void run_tool(const char *dir, const char *exe, const char *args)
{
#ifdef _WIN32
	char cwd[768], cmd[1152];
	STARTUPINFOA si;
	PROCESS_INFORMATION pi;

	snprintf(cwd, sizeof(cwd), "%s/%s", root, dir);
	snprintf(cmd, sizeof(cmd), "\"%s\\%s\" %s", cwd, exe, args);
	memset(&si, 0, sizeof(si));
	si.cb = sizeof(si);
	memset(&pi, 0, sizeof(pi));
	SetEnvironmentVariableA("OMNI_HIDDEN", "1");
	if (CreateProcessA(NULL, cmd, NULL, NULL, FALSE, 0, NULL, cwd, &si, &pi))
	{
		if (WaitForSingleObject(pi.hProcess, 60000) == WAIT_TIMEOUT)
			TerminateProcess(pi.hProcess, 1);
		CloseHandle(pi.hProcess);
		CloseHandle(pi.hThread);
	}
	SetEnvironmentVariableA("OMNI_HIDDEN", NULL);
#endif
}

static int copy_file_once(const char *src, const char *dst)
{
	FILE *in, *out;
	char buf[65536];
	size_t n;

	if (file_exists(dst) || !file_exists(src))
		return 0;
	in = fopen(src, "rb");
	if (!in)
		return 0;
	out = fopen(dst, "wb");
	if (!out)
	{
		fclose(in);
		return 0;
	}
	while ((n = fread(buf, 1, sizeof(buf), in)) > 0)
		fwrite(buf, 1, n, out);
	fclose(in);
	fclose(out);
	return 1;
}

static void sfx_refresh(void)
{
#ifdef _WIN32
	/* source slots: 3 = Keen 4, 4 = Keen 5 (the rt omnispeak install) */
	static const struct
	{
		int slot;
		int episode;
		const char *cache;    /* dump cache under keen13/ */
		const char *prefix;   /* file prefix in each game's sfx46/ */
	} srcs[2] = {
		{3, 4, "keen13/sfx46_k4", "k4"},
		{4, 5, "keen13/sfx46_k5", "k5"},
	};
	static const char *dests[3] = {
		"keen13/gamedata/sfx46", "keen13/gamedata2/sfx46",
		"keen13/gamedata3/sfx46"
	};
	int si, di, n;
	char path[900], dst[900], args[256];

	for (si = 0; si < 2; si++)
	{
		if (!slots[srcs[si].slot].available)
			continue;
		snprintf(path, sizeof(path), "%s/%s", root, srcs[si].cache);
		CreateDirectoryA(path, NULL);
		/* dump once per install: the first MUSIC track is the freshness
		   marker -- it is written by the second of the two dump runs, so
		   a cache interrupted between them still completes next boot */
		snprintf(path, sizeof(path), "%s/%s/m00.imf", root, srcs[si].cache);
		if (!file_exists(path))
		{
			char note[96];

			snprintf(note, sizeof(note),
			         "RENDERING GALAXY AUDIO FROM YOUR KEEN %d FILES",
			         srcs[si].episode);
			pull_notice(note);
			snprintf(args, sizeof(args),
			         "/EPISODE %d /SNDDUMP \"%s/%s\" /WINDOWED",
			         srcs[si].episode, root, srcs[si].cache);
			run_tool(slots[srcs[si].slot].dir, slots[srcs[si].slot].exe, args);
			snprintf(args, sizeof(args),
			         "/EPISODE %d /MUSDUMP \"%s/%s\" /WINDOWED",
			         srcs[si].episode, root, srcs[si].cache);
			run_tool(slots[srcs[si].slot].dir, slots[srcs[si].slot].exe, args);
		}
		for (di = 0; di < 3; di++)
		{
			snprintf(dst, sizeof(dst), "%s/%s", root, dests[di]);
			CreateDirectoryA(dst, NULL);
			for (n = 0; n < 100; n++)
			{
				snprintf(path, sizeof(path), "%s/%s/g%02d.wav", root,
				         srcs[si].cache, n);
				snprintf(dst, sizeof(dst), "%s/%s/%sg%02d.wav", root,
				         dests[di], srcs[si].prefix, n);
				copy_file_once(path, dst);
				snprintf(path, sizeof(path), "%s/%s/m%02d.imf", root,
				         srcs[si].cache, n);
				snprintf(dst, sizeof(dst), "%s/%s/%sm%02d.imf", root,
				         dests[di], srcs[si].prefix, n);
				copy_file_once(path, dst);
			}
		}
	}
#endif
}

static void launch(const Slot *s)
{
#ifdef _WIN32
	char cwd[768], cmd[1024];
	STARTUPINFOA si;
	PROCESS_INFORMATION pi;

	snprintf(cwd, sizeof(cwd), "%s/%s", root, s->dir);
	if (s->args[0])
		snprintf(cmd, sizeof(cmd), "\"%s\\%s\" %s", cwd, s->exe, s->args);
	else
		snprintf(cmd, sizeof(cmd), "\"%s\\%s\"", cwd, s->exe);

	memset(&si, 0, sizeof(si));
	si.cb = sizeof(si);
	memset(&pi, 0, sizeof(pi));
	/* The games must run with their own folder as the working directory: they
	 * find their data, config and saves relative to it. */
	if (CreateProcessA(NULL, cmd, NULL, NULL, FALSE, 0, NULL, cwd, &si, &pi))
	{
		/* Wait, so the launcher is not competing for the screen or the pad,
		 * and so returning from a game lands back here. */
		WaitForSingleObject(pi.hProcess, INFINITE);
		CloseHandle(pi.hProcess);
		CloseHandle(pi.hThread);
	}
	else
	{
		/* Name the actual cause. These are the three the player can really
		 * hit: the game folder was moved or never installed, or an antivirus
		 * quarantined the engine exe. */
		DWORD err = GetLastError();
		char detail[160];
		const char *why;

		switch (err)
		{
		case ERROR_FILE_NOT_FOUND:
			why = "THE GAME PROGRAM IS MISSING"; break;
		case ERROR_PATH_NOT_FOUND:
			why = "THE GAME FOLDER IS MISSING"; break;
		case ERROR_ACCESS_DENIED:
			why = "WINDOWS BLOCKED IT (ANTIVIRUS?)"; break;
		default:
			why = "WINDOWS REFUSED TO START IT"; break;
		}
		snprintf(detail, sizeof(detail), "%s  (ERROR %lu)", s->exe,
		         (unsigned long)err);
		fprintf(stderr, "launch failed (%lu): %s\n", (unsigned long)err, cmd);
		error_notice("COULD NOT START THE GAME", why, detail);
	}
#else
	char cmd[1024];
	snprintf(cmd, sizeof(cmd), "cd \"%s/%s\" && ./%s %s", root, s->dir, s->exe, s->args);
	system(cmd);
#endif
}

/* -------------------------------------------------------------------- draw */

#define TILE_BEVEL 6      /* the five layers add this much on every side */

/* Baked tile faces -- crisp designs from the launcher's own art, replacing
 * the shrunken title screens (fuzzy at tile size).  KEEN_TILESTYLE picks:
 *   1 = starfield: big bevelled number over sparse stars (default)
 *   2 = cartridge: accent label bands, like a cart sticker
 *   3 = minimal:   dark face, bevelled title
 *   0 = the game's own title-screen thumbnail (the old look)
 */
static int tile_style(void)
{
	static int cached = -2;

	if (cached == -2)
	{
		const char *e = getenv("KEEN_TILESTYLE");
		cached = e ? atoi(e) : 3; /* user-picked: minimal bevelled title */
	}
	return cached;
}

static void tile_face(int i, int cx, int cy, int chosen)
{
	int acc = slots[i].accent;
	int hi = (acc | 8) == acc ? 15 : (acc | 8);
	char num[4];
	/* split "KEEN DREAMS" onto two small lines; others fit one */
	const char *t1 = slots[i].title, *t2 = NULL;

	if (i == 6)
	{
		t1 = "KEEN";
		t2 = "DREAMS";
	}
	snprintf(num, sizeof(num), "%d", i + 1);

	switch (tile_style())
	{
	default:
	case 1: /* starfield */
	{
		unsigned seed = 0x9e37 + (unsigned)i * 77;
		int n;

		bar(cx, cy, TILE_W, TILE_H, 0);
		for (n = 0; n < 26; n++)
		{
			int x, y;
			seed = seed * 1103515245u + 12345u;
			x = (seed >> 16) % TILE_W;
			seed = seed * 1103515245u + 12345u;
			y = (seed >> 16) % TILE_H;
			px(cx + x, cy + y, (n % 5) ? 8 : 7);
		}
		text_big(cx + 8, cy + 8, num, acc);
		if (t2)
		{
			text(cx + 34, cy + 12, t1, 15);
			text(cx + 34, cy + 24, t2, 15);
		}
		else
			text(cx + 34, cy + 18, t1, 15);
		bar(cx + 8, cy + 42, TILE_W - 16, 2, acc);
		break;
	}
	case 2: /* cartridge label */
		bar(cx, cy, TILE_W, TILE_H, 8);
		bar(cx, cy, TILE_W, 10, acc);
		bar(cx, cy + 10, TILE_W, 3, hi);
		bar(cx, cy + TILE_H - 6, TILE_W, 6, acc);
		text_big(cx + TILE_W - 22, cy + 16, num, hi);
		if (t2)
		{
			text(cx + 6, cy + 20, t1, 15);
			text(cx + 6, cy + 32, t2, 15);
		}
		else
			text(cx + 6, cy + 26, t1, 15);
		break;
	case 3: /* minimal */
		bar(cx, cy, TILE_W, TILE_H, 0);
		if (t2)
		{
			text_big_centred(cx + TILE_W / 2, cy + 6, t1, acc);
			text(cx + TILE_W / 2 - text_w(t2) / 2, cy + 30, t2, acc);
		}
		else
			text_big_centred(cx + TILE_W / 2, cy + 14, t1, acc);
		text(cx + 3, cy + 3, num, 8);
		break;
	}

	if (chosen)
	{
		bar(cx, cy + TILE_H - 12, TILE_W, 12, 1);
		text_centred(cx + TILE_W / 2, cy + TILE_H - 10, "> PLAY <", 14);
	}
}

/* ------------------------------------------------- how-to / about pages */

static int ui_page; /* 0 = games, 1 = how to, 2 = about */

static void draw_page_frame(const char *title)
{
	if (bg_have)
		bg_draw();
	else
		starfield();
	text_big_centred(cw / 2, 8, title, 14);
	text_centred(cw / 2, ch - 22,
	             "TAB: NEXT PAGE    ESC: BACK TO GAMES", 7);
}

static void draw_howto(void)
{
	int y = 30, i;
	int lx = cw / 2 - 200;

	draw_page_frame("HOW TO");
	if (lx < 8)
		lx = 8;

	text(lx, y, "ADDING YOUR GAMES", 14); y += 13;
	text(lx, y, "Copy each game's original files into its folder next", 7); y += 10;
	text(lx, y, "to this launcher; it lights up READY right away:", 7); y += 12;
	for (i = 0; i < NSLOTS; i++)
	{
		char line[96];
		snprintf(line, sizeof(line), "%-11s %s   (needs %s)",
		         slots[i].title, slots[i].dir, slots[i].needs);
		text(lx + 8, y, line, slots[i].available ? 10 : 8);
		y += 10;
	}
	y += 4;
	text(lx, y, "CONTROLS", 14); y += 13;
	text(lx, y, "Move: arrows / d-pad / stick    Play: Enter or A", 7); y += 10;
	text(lx, y, "Quit a game to return here.  F11 toggles window.", 7); y += 10;
	text(lx, y, "In game: F5 or F7 quicksave, F9 quickload.", 7); y += 12;
	text(lx, y, "On first detection a game briefly runs to render", 8); y += 10;
	text(lx, y, "its own title art for this menu.", 8);
}

static void draw_about(void)
{
	int y = 30;
	int lx = cw / 2 - 200;

	draw_page_frame("ABOUT");
	if (lx < 8)
		lx = 8;

	text(lx, y, "MEGAROCKET", 14); y += 13;
	text(lx, y, "All seven Commander Keen games, playable from the", 7); y += 10;
	text(lx, y, "couch on a modern display: 16:9 widescreen, high-", 7); y += 10;
	text(lx, y, "refresh smooth motion, quicksave, full rebinding,", 7); y += 10;
	text(lx, y, "crisp pixels always -- and still simulation-", 7); y += 10;
	text(lx, y, "identical to DOS, proven by replaying recorded", 7); y += 10;
	text(lx, y, "input against per-frame state checksums.  It runs", 7); y += 10;
	text(lx, y, "YOUR copies; no game data is redistributed.", 7); y += 13;
	text(lx, y, "STANDING ON GIANTS", 14); y += 13;
	text(lx, y, "Keen 1-3: on K1n9_Duk3's source reconstruction.", 7); y += 10;
	text(lx, y, "Keen 4-6: on Omnispeak by David Gow.", 7); y += 10;
	text(lx, y, "Keen Dreams: on ReflectionHLE by NY00123, from", 7); y += 10;
	text(lx, y, "  id's own source release.", 7); y += 10;
	text(lx, y, "And id Software, for the games themselves.", 7); y += 13;
	text(lx, y, "Engine work, porting and features were done with", 8); y += 10;
	text(lx, y, "Claude Code (Anthropic), pair-programming style.", 8);
}

static void draw(int sel, int launching)
{
	if (ui_page == 1)
	{
		draw_howto();
		return;
	}
	if (ui_page == 2)
	{
		draw_about();
		return;
	}

	const int cols = 4, gapx = 12, gapy = 20;
	/* centre the two rows in whatever vertical space is left between the
	   title block and the footer, so a tall window spreads out rather than
	   leaving a gap at the bottom */
	const int gridh = 2 * TILE_H + gapy + TILE_BEVEL;
	int starty = 46 + ((ch - 62 - 46) - gridh) / 2;

	/* never let the top row's bevel ride up into the title block */
	if (starty < 46)
		starty = 46;
	int i;

	if (bg_have)
		bg_draw();
	else
		starfield();

	text_big_centred(cw / 2, 8, "MEGAROCKET", 14);
	text_centred(cw / 2, 28, "THE COMPLETE COLLECTION", 7);

	for (i = 0; i < NSLOTS; i++)
	{
		int row = i / cols;
		int col = i % cols;
		/* how many tiles share this row, so a short last row centres instead
		   of hanging off to the left */
		int inrow = NSLOTS - row * cols;
		int cx, cy, chosen, fill;
		char num[8];

		if (inrow > cols)
			inrow = cols;
		cx = (cw - (inrow * TILE_W + (inrow - 1) * gapx)) / 2
		     + col * (TILE_W + gapx);
		cy = starty + row * (TILE_H + gapy + TILE_BEVEL);
		chosen = (i == sel);

		bevel(cx, cy, TILE_W, TILE_H, chosen ? 7 : 6);
		/* an unavailable game is dimmed but still legible -- it has to read as
		   "coming", not as a rendering fault */
		fill = slots[i].available ? (chosen ? 1 : 0) : 8;
		bar(cx, cy, TILE_W, TILE_H, fill);

		if (slots[i].available && tile_style() == 0 && slots[i].thumb)
		{
			/* the game's own title screen fills the tile */
			int ax, ay;

			for (ay = 0; ay < TILE_H; ay++)
				for (ax = 0; ax < TILE_W; ax++)
					canvas[(cy + ay) * cw + cx + ax] =
						slots[i].thumb[ay * TILE_W + ax];
			if (chosen)
			{
				bar(cx, cy + TILE_H - 12, TILE_W, 12, 1);
				text_centred(cx + TILE_W / 2, cy + TILE_H - 10,
				             "> PLAY <", 14);
			}
		}
		else if (slots[i].available)
			tile_face(i, cx, cy, chosen);

		snprintf(num, sizeof(num), "%d", i + 1);
		text(cx + 3, cy + 3, num, slots[i].available ? 15 : 7);

		if (!slots[i].available)
		{
			text_centred(cx + TILE_W / 2, cy + 14, slots[i].title, 15);
			text_centred(cx + TILE_W / 2, cy + 32, "COMING", 0);
			text_centred(cx + TILE_W / 2, cy + 42, "SOON", 0);
		}
	}

	/* selected game's subtitle, on its own line clear of the tiles */
	text_centred(cw / 2, ch - 42,
	             slots[sel].available ? slots[sel].subtitle
	                                  : "NOT INSTALLED YET",
	             slots[sel].available ? 11 : 8);

	if (launching)
		text_centred(cw / 2, ch - 22, "STARTING...", 15);
	else
		text_centred(cw / 2, ch - 22,
		             "ARROWS MOVE   ENTER PLAY   TAB HELP   ESC QUIT", 7);
}

/* ------------------------------------------------------------------- shell */

/* Upload just the live part of the canvas and blit it at a whole-number
 * scale, centred.  Because the logical size was derived from the window,
 * the destination normally covers it exactly -- any leftover is at most a
 * scale-1 sliver of black, and never a stretched image. */
static void present(SDL_Renderer *ren, SDL_Texture *tex)
{
	int winw, winh, scale;
	SDL_Rect src, dst;

	SDL_GetRendererOutputSize(ren, &winw, &winh);
	scale = canvas_fit(winw, winh);

	src.x = src.y = 0;
	src.w = cw;
	src.h = ch;
	dst.w = cw * scale;
	dst.h = ch * scale;
	dst.x = (winw - dst.w) / 2;
	dst.y = (winh - dst.h) / 2;

	/* px() packs rows at the CURRENT logical width, so the upload pitch must
	   match that, not the buffer's maximum width */
	SDL_UpdateTexture(tex, &src, canvas, cw * 4);
	SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
	SDL_RenderClear(ren);
	SDL_RenderCopy(ren, tex, &src, &dst);
	SDL_RenderPresent(ren);
}


int main(int argc, char **argv)
{
	SDL_Window *win;
	SDL_Renderer *ren;
	SDL_Texture *tex;
	SDL_GameController *pad = NULL;
	int sel = 0, running = 1, launching = 0;
	int i;
	int stick_dir = 0;            /* current stick direction, for edge detect */
	Uint32 stick_repeat = 0;      /* when a held stick may move again */
	Uint32 input_ready = 0;       /* ignore input until this time */

	/* the launcher lives in <root>/launcher, and the games sit beside it */
	snprintf(root, sizeof(root), "%s", argv[0]);
	for (i = (int)strlen(root) - 1; i > 0; i--)
	{
		if (root[i] == '\\' || root[i] == '/')
		{
			root[i] = 0;
			break;
		}
	}
	strncat(root, "/..", sizeof(root) - strlen(root) - 1);
	if (getenv("KEEN_ROOT"))
		snprintf(root, sizeof(root), "%s", getenv("KEEN_ROOT"));

	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER) != 0)
	{
		fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
		return 1;
	}
	/* Fullscreen by default: this is a TV/couch collection, and the games it
	   launches now do the same, so the whole session stays fullscreen with no
	   window flashing between the shell and a game.  "-windowed" (or
	   KEEN_WINDOWED=1) is the escape hatch for development, and F11 still
	   toggles at runtime. */
	{
		Uint32 flags = SDL_WINDOW_RESIZABLE;
		int windowed = (getenv("KEEN_WINDOWED") != NULL);
		int a;
		for (a = 1; a < argc; a++)
			if (!strcmp(argv[a], "-windowed") || !strcmp(argv[a], "-w"))
				windowed = 1;
		if (!windowed)
			flags |= SDL_WINDOW_FULLSCREEN_DESKTOP;
		win = SDL_CreateWindow("Megarocket", SDL_WINDOWPOS_CENTERED,
		                       SDL_WINDOWPOS_CENTERED,
		                       CANVAS_REF_W * 3, CANVAS_REF_H * 3, flags);
	}
	SDL_SetWindowMinimumSize(win, CANVAS_MIN_W, CANVAS_MIN_H);
	ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
	/* one texture at the maximum logical size; only the used sub-rect is
	   uploaded and drawn, so resizing never reallocates */
	tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888,
	                        SDL_TEXTUREACCESS_STREAMING,
	                        CANVAS_MAX_W, CANVAS_MAX_H);
	SDL_SetTextureScaleMode(tex, SDL_ScaleModeNearest);   /* hard pixels */
	g_notice_ren = ren;
	g_notice_tex = tex;

	for (i = 0; i < SDL_NumJoysticks(); i++)
		if (SDL_IsGameController(i))
		{
			pad = SDL_GameControllerOpen(i);
			break;
		}

	detect();
	art_refresh();
	sfx_refresh();
	bg_scan();

	/* restore the last selected slot */
	{
		FILE *cf = fopen("keenlauncher.cfg", "r");
		if (cf)
		{
			int v;
			if (fscanf(cf, "lastslot=%d", &v) == 1 && v >= 0 && v < NSLOTS)
				sel = v;
			fclose(cf);
		}
	}

	/* KEEN_SHOT=<file>: render one frame to a PPM and quit, so the layout can
	 * be reviewed without a human at the screen */
	if (getenv("KEEN_PAGE")) /* dev: capture the how-to/about pages */
		ui_page = atoi(getenv("KEEN_PAGE"));
	if (getenv("KEEN_SHOT"))
	{
		FILE *f = fopen(getenv("KEEN_SHOT"), "wb");
		if (f)
		{
			int x, y;
			/* KEEN_SHOT_SIZE=WxH pretends the window is that size, so the
			   responsive layout can be checked at several shapes offline */
			if (getenv("KEEN_SHOT_SIZE"))
			{
				int sw = 0, sh = 0;
				if (sscanf(getenv("KEEN_SHOT_SIZE"), "%dx%d", &sw, &sh) == 2 &&
				    sw > 0 && sh > 0)
					canvas_fit(sw, sh);
			}
			draw(getenv("KEEN_SHOT_SEL") ? atoi(getenv("KEEN_SHOT_SEL")) : 0, 0);
			fprintf(f, "P6\n%d %d\n255\n", cw, ch);
			for (y = 0; y < ch; y++)
				for (x = 0; x < cw; x++)
				{
					Uint32 c = canvas[y * cw + x];
					Uint8 rgb[3];
					rgb[0] = (Uint8)((c >> 16) & 0xFF);
					rgb[1] = (Uint8)((c >> 8) & 0xFF);
					rgb[2] = (Uint8)(c & 0xFF);
					fwrite(rgb, 1, 3, f);
				}
			fclose(f);
		}
		running = 0;
	}

	while (running)
	{
		SDL_Event ev;
		int move = 0, fire = 0;
		Uint32 now = SDL_GetTicks();

		/* Analog sticks navigate too, not just the d-pad.  Axes are a
		 * position rather than an event, so they need their own edge and
		 * repeat handling: move once when pushed past the deadzone, then
		 * repeat slowly if held, and re-arm on release. */
		if (pad && now >= input_ready)
		{
			int ax = SDL_GameControllerGetAxis(pad, SDL_CONTROLLER_AXIS_LEFTX);
			int ay = SDL_GameControllerGetAxis(pad, SDL_CONTROLLER_AXIS_LEFTY);
			const int dead = 16000;          /* generous: avoids drift */
			int dx = (ax < -dead) ? -1 : (ax > dead) ? 1 : 0;
			int dy = (ay < -dead) ? -1 : (ay > dead) ? 1 : 0;
			int dir = dx ? dx : (dy ? dy * 4 : 0);

			if (!dir)
			{
				stick_dir = 0;               /* released: re-arm */
			}
			else if (dir != stick_dir || now >= stick_repeat)
			{
				move = dir;
				stick_repeat = now + (dir != stick_dir ? 380 : 170);
				stick_dir = dir;
			}
		}

		while (SDL_PollEvent(&ev))
		{
			/* during the post-game ignore window, keep pumping (so the
			 * window stays responsive) but act on nothing except a real
			 * close request */
			if (now < input_ready && ev.type != SDL_QUIT &&
			    ev.type != SDL_WINDOWEVENT)
				continue;
			switch (ev.type)
			{
			case SDL_QUIT:
				running = 0;
				break;
			case SDL_KEYDOWN:
				switch (ev.key.keysym.scancode)
				{
				case SDL_SCANCODE_ESCAPE:
					if (ui_page)
						ui_page = 0;
					else
						running = 0;
					break;
				case SDL_SCANCODE_TAB:
					ui_page = (ui_page + 1) % 3;
					break;
				case SDL_SCANCODE_LEFT:   move = -1; break;
				case SDL_SCANCODE_RIGHT:  move = 1; break;
				case SDL_SCANCODE_UP:     move = -4; break;
				case SDL_SCANCODE_DOWN:   move = 4; break;
				case SDL_SCANCODE_RETURN:
				case SDL_SCANCODE_KP_ENTER:
				case SDL_SCANCODE_SPACE:  fire = 1; break;
				case SDL_SCANCODE_F11:
					SDL_SetWindowFullscreen(win,
						(SDL_GetWindowFlags(win) & SDL_WINDOW_FULLSCREEN_DESKTOP)
							? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP);
					break;
				default: break;
				}
				break;
			case SDL_CONTROLLERBUTTONDOWN:
				switch (ev.cbutton.button)
				{
				case SDL_CONTROLLER_BUTTON_DPAD_LEFT:  move = -1; break;
				case SDL_CONTROLLER_BUTTON_DPAD_RIGHT: move = 1; break;
				case SDL_CONTROLLER_BUTTON_DPAD_UP:    move = -4; break;
				case SDL_CONTROLLER_BUTTON_DPAD_DOWN:  move = 4; break;
				case SDL_CONTROLLER_BUTTON_A:
				case SDL_CONTROLLER_BUTTON_START:      fire = 1; break;
				case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
				case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
					ui_page = (ui_page + 1) % 3;
					break;
				case SDL_CONTROLLER_BUTTON_B:
				case SDL_CONTROLLER_BUTTON_BACK:
					if (ui_page)
						ui_page = 0;
					else
						running = 0;
					break;
				default: break;
				}
				break;
			case SDL_CONTROLLERDEVICEADDED:
				if (!pad)
					pad = SDL_GameControllerOpen(ev.cdevice.which);
				break;
			case SDL_CONTROLLERDEVICEREMOVED:
				if (pad)
				{
					SDL_GameControllerClose(pad);
					pad = NULL;
				}
				break;
			}
		}

		if (ui_page)
			move = fire = 0;

		if (move)
		{
			sel += move;
			while (sel < 0)
				sel += NSLOTS;
			sel %= NSLOTS;
		}

		if (fire && !slots[sel].available)
			ui_page = 1; /* the How To page says exactly where files go */

		if (fire && slots[sel].available)
		{
			launching = 1;
			draw(sel, launching);
			present(ren, tex);

			launch(&slots[sel]);
			launching = 0;
			/* a game may have written new data (or the user installed one
			 * while we waited), so re-check availability on return */
			detect();
			art_refresh();
	sfx_refresh();
			bg_scan();

			/* Everything the player did inside the game queued up here while
			 * we blocked, and replaying it moved the selection and launched
			 * again -- which is why quitting one game could drop you into
			 * another, or quit the launcher outright.  Drain the WHOLE queue
			 * (the old call covered only keyboard-to-button event types) and
			 * then ignore input briefly, so the button that quit the game
			 * cannot also act here. */
			SDL_PumpEvents();
			SDL_FlushEvents(SDL_FIRSTEVENT, SDL_LASTEVENT);
			stick_dir = 0;
			input_ready = SDL_GetTicks() + 400;

			/* That drain also dropped any pad added/removed events from while
			 * the game held the device, so re-scan instead of trusting the old
			 * handle -- otherwise unplugging during a game leaves a dead pad
			 * and plugging one in goes unnoticed. */
			if (pad)
			{
				SDL_GameControllerClose(pad);
				pad = NULL;
			}
			for (i = 0; i < SDL_NumJoysticks(); i++)
				if (SDL_IsGameController(i))
				{
					pad = SDL_GameControllerOpen(i);
					break;
				}
		}

		draw(sel, launching);
		present(ren, tex);
		SDL_Delay(16);
	}

	{
		FILE *cf = fopen("keenlauncher.cfg", "w");
		if (cf)
		{
			fprintf(cf, "lastslot=%d", sel);
			fclose(cf);
		}
	}

	if (pad)
		SDL_GameControllerClose(pad);
	SDL_DestroyTexture(tex);
	SDL_DestroyRenderer(ren);
	SDL_DestroyWindow(win);
	SDL_Quit();
	return 0;
}

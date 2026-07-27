/*
=============================================================================
	Present-time compositor: widescreen + high-refresh interpolation.
	(#included at the end of idlib13.c; split out only for readability)

	The sim keeps composing its two 320px EGA pages untouched (the replay
	baseline stays green).  When active, this compositor re-renders the
	visible world at PRESENT time straight from mapplane + the world-space
	sprite list captured in RF_PlaceSprite, into a wider index buffer with
	the camera (and sprites) interpolated between sim frames.  Crisp
	pixels only: everything is whole-pixel placement of the original EGA
	data; scaling is sharp (integer prescale, then a slight linear fit).

	Z-order: background tiles -> sprites -> foreground tiles (intile<0,
	masked when -2) -> screen-anchored pics.  Env: K13_WIDE=0|width
	(default 426), K13_SMOOTH=0|1 (default 1).
=============================================================================
*/

#define K13_COMP_MAXW 512
#define K13_COMP_MAXSPR 500


typedef struct
{
	Sint32 wx, wy; /* world global units */
	Sint16 shape;
} K13_SprNote;

static K13_SprNote k13_spr_cur[K13_COMP_MAXSPR];  /* being captured */
static K13_SprNote k13_spr_show[K13_COMP_MAXSPR]; /* completed frame */
static K13_SprNote k13_spr_prev[K13_COMP_MAXSPR]; /* frame before that */
static int k13_nspr_cur, k13_nspr_show, k13_nspr_prev;

static Sint32 k13_cam_cur_x, k13_cam_cur_y;   /* origin px at refresh */
static Sint32 k13_cam_prev_x, k13_cam_prev_y;

static int k13_dialog_active; /* an ExpWin/DrawWindow dialog is on the page */

/* A full-screen static screen (high scores, story, ordering info) is being
 * shown.  These are drawn straight to the EGA page and are NOT a live world,
 * but `level` still holds whatever was being played, so the TITLEMAP test
 * alone does not catch them: the high-score screen shown after a game ended
 * had the compositor drawing the old level over it every other frame, which
 * is what made the text appear to flash.  Shown from the main menu the same
 * screen was fine, because there level IS TITLEMAP. */
static int k13_static_screen;
static Sint16 k13_dlg_xl, k13_dlg_yl, k13_dlg_xh, k13_dlg_yh; /* char rect */
int k13_onefire = 1; /* config: single-control fire (sets both buttons) */

/* Rebindable controls.  Pad codes are SDL_GameControllerButton values
 * (A=0 B=1 X=2 Y=3 BACK=4 START=6 LSTICK=7 RSTICK=8 LB=9 RB=10, dpad
 * 11-14) plus K13_PAD_LTRIG/RTRIG for the analog triggers; -1 = unbound.
 * Spelled numerically so this still compiles in the headless build.
 *
 * TWO slots per action, because one was a regression: the fixed layout let
 * either shoulder jump and either trigger fire, and single binding took that
 * away.  Slot 0 is the face button, slot 1 the shoulder/trigger alternate.
 * k13_bind_firekey is separate -- a DOS scan code, the keyboard's one-button
 * fire control. */
static const int k13_bind_defaults[K13_BIND_COUNT][2] = {
	{0, 10},              /* jump:      A + RB     */
	{1, 9},               /* pogo:      B + LB     */
	{2, K13_PAD_RTRIG},   /* fire:      X + R-TRIG */
	{3, 4},               /* status:    Y + BACK   */
	{8, -1},              /* quicksave: R-STICK    */
	{7, -1},              /* quickload: L-STICK    */
	{-1, -1},             /* help                  */
	{-1, -1},             /* sound toggle          */
	{-1, -1},             /* save/load menu        */
	{-1, -1},             /* quit prompt           */
	{-1, -1}              /* score box toggle      */
};

int k13_bind[K13_BIND_COUNT][2] = {
	{0, 10}, {1, 9}, {2, K13_PAD_RTRIG}, {3, 4}, {8, -1}, {7, -1},
	{-1, -1}, {-1, -1}, {-1, -1}, {-1, -1}, {-1, -1}
};

/* Keyboard binds, DOS scan codes, in K13_KEY_* order.  Defaults are what the
 * game shipped with (F1 help, F2 sound, F3/F4 the config screens, F5 the save
 * menu, Esc the quit prompt, Space the status screen) plus this port's own
 * additions (Left Shift fire, F7/F9 quicksave/quickload).  0 means unbound --
 * any of them can be cleared. */
static const int k13_keybind_defaults[K13_KEY_COUNT] = {
	0x2A,  /* fire:       Left Shift */
	0x41,  /* quicksave:  F7         */
	0x43,  /* quickload:  F9         */
	0x39,  /* status:     Space      */
	0x3B,  /* help:       F1         */
	0x3C,  /* sound:      F2         */
	0x3D,  /* keyboard:   F3         */
	0x3E,  /* joystick:   F4         */
	0x3F,  /* save menu:  F5         */
	0x01,  /* quit:       Esc        */
	0      /* score box:  unbound    */
};
int k13_keybind[K13_KEY_COUNT] = {
	0x2A, 0x41, 0x43, 0x39, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x01, 0
};

/* Persistent score box (Keen 4-6 style HUD).  Off by default: the original
 * games showed status only on the status screen. */
int k13_scorebox;

int K13_GetScoreBox(void)
{
	return k13_scorebox;
}

void K13_SetScoreBox(int on)
{
	k13_scorebox = on ? 1 : 0;
}

/* Standard rebinding semantics, shared by the Controls screen:
 * - binding STEALS: the key/button is removed from any other action first,
 *   so one input can never trigger two actions (the old silent-duplicate
 *   glitch).  If the theft would leave the Quit key unbound, Quit falls
 *   back to Esc (Esc itself is unbindable, so menus can never lock out).
 * - a pad bind ROTATES: the new button becomes primary, the old primary
 *   becomes the alternate.  Binding a button the action already has just
 *   promotes it.  One press per bind; a second bind adds the alternate. */
void K13_BindKey(int which, int scan)
{
	int i;

	if (which < 0 || which >= K13_KEY_COUNT || scan <= 0 || scan >= 128)
		return;
	for (i = 0; i < K13_KEY_COUNT; i++)
		if (i != which && k13_keybind[i] == scan)
			k13_keybind[i] = (i == K13_KEY_QUIT) ? 0x01 : 0;
	k13_keybind[which] = scan;
}

void K13_BindPad(int which, int code)
{
	int a, sl;

	if (which < 0 || which >= K13_BIND_COUNT || code < 0)
		return;
	for (a = 0; a < K13_BIND_COUNT; a++)
		for (sl = 0; sl < 2; sl++)
			if (a != which && k13_bind[a][sl] == code)
				k13_bind[a][sl] = -1;
	if (k13_bind[which][0] == code)
		return;
	if (k13_bind[which][1] == code)
	{
		k13_bind[which][1] = k13_bind[which][0];
		k13_bind[which][0] = code;
		return;
	}
	k13_bind[which][1] = k13_bind[which][0];
	k13_bind[which][0] = code;
}

int K13_GetKeyBind(int which)
{
	if (which < 0 || which >= K13_KEY_COUNT)
		return 0;
	return k13_keybind[which];
}

void K13_SetKeyBind(int which, int scan)
{
	if (which < 0 || which >= K13_KEY_COUNT)
		return;
	/* 0 clears the binding; anything outside a DOS scan code is ignored */
	if (scan == 0 || (scan > 0 && scan < 128))
		k13_keybind[which] = scan;
}

/* Which action this scan code is bound to, or -1.  Unbound entries (0) never
 * match, so a cleared control really is inert. */
int K13_KeyAction(int scan)
{
	int i;

	if (scan <= 0)
		return -1;
	/* synthetic scans map straight back to their action */
	if (scan >= 0x60 && scan < 0x60 + K13_KEY_COUNT)
		return scan - 0x60;
	for (i = 0; i < K13_KEY_COUNT; i++)
		if (k13_keybind[i] == scan)
			return i;
	return -1;
}

int K13_ActionDown(int which)
{
	int sc;

	if (which < 0 || which >= K13_KEY_COUNT)
		return 0;
	sc = k13_keybind[which];
	if (sc > 0 && sc < 128 && keydown[sc])
		return 1;
	return keydown[K13_SYNTH_SCAN(which)] != 0;
}

int K13_GetBind(int which, int slot)
{
	if (which < 0 || which >= K13_BIND_COUNT || slot < 0 || slot > 1)
		return -1;
	return k13_bind[which][slot];
}

void K13_SetBind(int which, int slot, int code)
{
	if (which < 0 || which >= K13_BIND_COUNT || slot < 0 || slot > 1)
		return;
	k13_bind[which][slot] = code;
}

int K13_GetFireKey(void)
{
	return k13_keybind[K13_KEY_FIRE];
}

void K13_SetFireKey(int scan)
{
	K13_SetKeyBind(K13_KEY_FIRE, scan);
}

void K13_ResetBinds(void)
{
	int i;

	for (i = 0; i < K13_BIND_COUNT; i++)
	{
		k13_bind[i][0] = k13_bind_defaults[i][0];
		k13_bind[i][1] = k13_bind_defaults[i][1];
	}
	for (i = 0; i < K13_KEY_COUNT; i++)
		k13_keybind[i] = k13_keybind_defaults[i];
}

/* Guard quicksave/quickload behind a yes/no prompt.  On by default: either is
 * one keypress -- or one mis-hit pad button -- away from wrecking a good run,
 * and 4-6 defaults its equivalent (ck_quickSaveConfirm) on as well. */
int k13_qsconfirm = 1;

/* Fullscreen on launch.  Default ON: this is a TV/couch collection.  The
 * Options row toggles it live and the choice is remembered. */
int k13_fullscreen = 1;

/* Bracket a page-drawn full-screen screen, so the compositor stands down for
 * it regardless of what `level` happens to be. */
void K13_StaticScreen(int on)
{
	k13_static_screen = on ? 1 : 0;
	if (getenv("K13_TRACE"))
	{
		fprintf(stderr, "K13 TP: static=%d level=%d\n", on, (int)level);
		fflush(stderr);
	}
}

int K13_GetFullscreen(void)
{
	return k13_fullscreen;
}

void K13_SetFullscreen(int on)
{
	k13_fullscreen = on ? 1 : 0;
}

/* Letterbox backdrop: a tile from THIS episode's own tileset, so the bars are
 * themed with the episode's art; -1 leaves them black.  Defaults were picked
 * by measuring every tile for darkness and subtle texture (K13_TILESHEET). */
#if (EPISODE == 1)
int k13_backdrop = 75;    /* starfield: dark with sparse sparkle */
#elif (EPISODE == 2)
int k13_backdrop = 75;    /* same starfield art in ep2's tileset */
#else
int k13_backdrop = 38;    /* ep3 keeps the starfield at a lower index */
#endif

int K13_GetQSConfirm(void)
{
	return k13_qsconfirm;
}

void K13_SetQSConfirm(int on)
{
	k13_qsconfirm = on ? 1 : 0;
}

int K13_GetBackdrop(void)
{
	return k13_backdrop;
}

void K13_SetBackdrop(int tile)
{
	k13_backdrop = tile;
}

extern int win_xl, win_yl, win_xh, win_yh; /* current window, char coords */

/* the game drew a dialog frame straight to the EGA page (F5 save, F2
 * sound, quit prompt...) -- fall back to the classic view so it shows,
 * until the next VidRefresh (gameplay resuming) clears this */
void K13_DialogOpened(void)
{
	if (!k13_dialog_active)
		k13_dialog_base = ((Uint32)(screenseg - 0xA000)) << 4; /* pin */
	k13_dialog_active = 1;
	k13_dlg_xl = (Sint16)win_xl;
	k13_dlg_yl = (Sint16)win_yl;
	k13_dlg_xh = (Sint16)win_xh;
	k13_dlg_yh = (Sint16)win_yh;
}

void K13_NoteSprite(Sint32 x, Sint32 y, Sint16 shapenum)
{
	if (k13_nspr_cur < K13_COMP_MAXSPR)
	{
		k13_spr_cur[k13_nspr_cur].wx = x;
		k13_spr_cur[k13_nspr_cur].wy = y;
		k13_spr_cur[k13_nspr_cur].shape = shapenum;
		k13_nspr_cur++;
	}
}

static void k13_comp_config(void)
{
	static int done;
	const char *e;

	if (done)
		return;
	done = 1;
	k13_comp_w = 426;
	if ((e = getenv("K13_WIDE")) != NULL)
	{
		int w = atoi(e);
		if (w == 0)
			k13_comp_w = 0;
		else if (w >= 320 && w <= K13_COMP_MAXW)
			k13_comp_w = w;
	}
	if ((e = getenv("K13_SMOOTH")) != NULL)
		k13_smooth = atoi(e) != 0;
}

/* rotate per-frame compositor state; called from K13_FrameTics */
static void k13_comp_frame_start(Sint16 tics)
{
	k13_nspr_cur = 0; /* fresh capture; compose only reads the snapshots */
	k13_frame_len_tics = (tics > 0) ? tics : 1;
}

/* snapshot at VidRefresh (sim frame presented) */
static void k13_comp_refresh_snap(void)
{
	Sint32 cx = (Sint32)(originx / PIXGLOBAL);
	Sint32 cy = (Sint32)(originy / PIXGLOBAL);

	k13_cam_prev_x = k13_cam_cur_x;
	k13_cam_prev_y = k13_cam_cur_y;
	k13_cam_cur_x = cx;
	k13_cam_cur_y = cy;
	/* teleports/level changes snap instead of gliding */
	if (k13_cam_cur_x - k13_cam_prev_x > 64 || k13_cam_prev_x - k13_cam_cur_x > 64 ||
	    k13_cam_cur_y - k13_cam_prev_y > 64 || k13_cam_prev_y - k13_cam_cur_y > 64)
	{
		k13_cam_prev_x = k13_cam_cur_x;
		k13_cam_prev_y = k13_cam_cur_y;
	}
	k13_real_at_refresh = k13_ticks_real;
#ifdef K13_WITH_SDL
	k13_refresh_ms = SDL_GetTicks();
#endif
	/* TITLEMAP is presented via page-drawn screens, never as a world
	   view -- composing it showed its raw top-left corner at boot */
	/* also require a sprite-bearing frame: world-map entry fades in and
	   shows the page-drawn "Keens left" box BEFORE the loop ever
	   places Keen -- that wait belongs to the classic view (box
	   visible, no Keen pop-in when the wide view takes over) */
	/* wide gameplay engages as soon as a live world is on screen, even
	   before the first sprite -- popups now composite OVER it, so there
	   is no 4:3<->16:9 flip at world-map entry (the "Keens Left" box) */
	k13_world_live = (uservect == NULL && level != TITLEMAP &&
	                  !k13_static_screen);

	/* the frame's sprite placements are complete here: rotate snapshots */
	memcpy(k13_spr_prev, k13_spr_show,
	       sizeof(K13_SprNote) * (size_t)k13_nspr_show);
	k13_nspr_prev = k13_nspr_show;
	memcpy(k13_spr_show, k13_spr_cur,
	       sizeof(K13_SprNote) * (size_t)k13_nspr_cur);
	k13_nspr_show = k13_nspr_cur;
}

/* draw one 16x16 map tile image (latch offset) into the buffer */
static void k13_comp_tile(Uint32 img, int dx, int dy, int masked)
{
	Uint32 src = k13_tileoff + img;
	int row, col, bit;

	for (row = 0; row < 16; row++, src += 2)
	{
		int y = dy + row;
		if (y < 0 || y >= 200)
			continue;
		for (col = 0; col < 2; col++)
		{
			Uint8 b0 = k13_ega[0][(src + col) & 0xFFFF];
			Uint8 b1 = k13_ega[1][(src + col) & 0xFFFF];
			Uint8 b2 = k13_ega[2][(src + col) & 0xFFFF];
			Uint8 b3 = k13_ega[3][(src + col) & 0xFFFF];
			Uint8 m = masked ? k13_ega[0][(src + 0x20 + col) & 0xFFFF] : 0;
			for (bit = 0; bit < 8; bit++)
			{
				int x = dx + col * 8 + bit;
				int sh = 7 - bit;
				if (x < 0 || x >= k13_comp_w)
					continue;
				if (masked && ((m >> sh) & 1))
					continue; /* transparent */
				k13_comp[y * K13_COMP_MAXW + x] =
					(Uint8)(((b0 >> sh) & 1) | (((b1 >> sh) & 1) << 1) |
					        (((b2 >> sh) & 1) << 2) | (((b3 >> sh) & 1) << 3));
			}
		}
	}
}

/* masked sprite blit (copy 0) at exact pixel position */
static void k13_comp_sprite(Sint16 shapenum, int dx, int dy)
{
	spritetype *spr;
	Uint32 src;
	int w, h, row, col, bit;

	if (!spritetable || !k13_sprplane[0])
		return;
	spr = &spritetable[shapenum * 4]; /* unshifted copy */
	src = (Uint32)(Uint16)spr->shapeptr;
	w = spr->width;
	h = spr->height;

	for (row = 0; row < h; row++)
	{
		int y = dy + row;
		if (y < 0 || y >= 200)
			continue;
		for (col = 0; col < w; col++)
		{
			Uint8 mask = k13_sprplane[4][src + row * w + col];
			Uint8 b0 = k13_sprplane[0][src + row * w + col];
			Uint8 b1 = k13_sprplane[1][src + row * w + col];
			Uint8 b2 = k13_sprplane[2][src + row * w + col];
			Uint8 b3 = k13_sprplane[3][src + row * w + col];
			for (bit = 0; bit < 8; bit++)
			{
				int x = dx + col * 8 + bit;
				int sh = 7 - bit;
				if (x < 0 || x >= k13_comp_w)
					continue;
				if ((mask >> sh) & 1)
					continue; /* transparent */
				k13_comp[y * K13_COMP_MAXW + x] =
					(Uint8)(((b0 >> sh) & 1) | (((b1 >> sh) & 1) << 1) |
					        (((b2 >> sh) & 1) << 2) | (((b3 >> sh) & 1) << 3));
			}
		}
	}
}

static Sint32 k13_lerp32(Sint32 a, Sint32 b, long num, long den)
{
	return a + (Sint32)(((Sint64)(b - a) * num) / den);
}

/* compose the frame at interpolation factor alpha = num/den */
static int k13_compose(long num, long den)
{
	Sint32 camx, camy, minx, maxx, miny, maxy;
	int tx0, ty0, tx, ty, i;
	int mapw, maph;
	unsigned *anim;

	k13_comp_config();
	if (!k13_comp_w || !k13_world_live || !mapplane[0] || mapbwide <= 0)
	{
		static int traced;
		if (!traced && getenv("K13_TRACE"))
		{
			traced = 1;
			fprintf(stderr, "K13 TP: compose reject w=%d live=%d map=%p bw=%d\n",
			        k13_comp_w, k13_world_live, (void *)mapplane[0], mapbwide);
			fflush(stderr);
		}
		return 0;
	}
	mapw = mapbwide / 2;
	maph = mapheight;
	if (mapw <= 0 || maph <= 0)
		return 0;

	if (!k13_smooth)
		num = den; /* always show the current sim frame */
	camx = k13_lerp32(k13_cam_prev_x, k13_cam_cur_x, num, den);
	camy = k13_lerp32(k13_cam_prev_y, k13_cam_cur_y, num, den);

	/* widen symmetrically around the 320 view, sliding at map edges so
	   border tiles never show (2-tile margin like the origin clamps) */
	camx -= (k13_comp_w - 320) / 2;
	minx = 2 * 16;
	maxx = mapw * 16 - 2 * 16 - k13_comp_w;
	miny = 2 * 16;
	maxy = maph * 16 - 2 * 16 - 200;
	if (maxx < minx)
		maxx = minx;
	if (maxy < miny)
		maxy = miny;
	if (camx < minx)
		camx = minx;
	if (camx > maxx)
		camx = maxx;
	if (camy < miny)
		camy = miny;
	if (camy > maxy)
		camy = maxy;

	/* background tiles */
	tx0 = camx >> 4;
	ty0 = camy >> 4;
	{
		Uint16 phase = ((Uint16)((Uint32)timecount >> cyclespeed) & 6) >> 1;
		static unsigned *const tables[4] = {tile_anim0, tile_anim1,
		                                    tile_anim2, tile_anim3};
		anim = tables[phase];
	}
	for (ty = ty0; ty <= (camy + 199) / 16 && ty < maph; ty++)
	{
		for (tx = tx0; tx <= (camx + k13_comp_w - 1) / 16 && tx < mapw; tx++)
		{
			Uint16 t = mapplane[0][ty * mapw + tx];
			if (t >= K13_MAXTILES)
				continue;
			k13_comp_tile((Uint32)anim[t], tx * 16 - camx, ty * 16 - camy, 0);
		}
	}

	/* Ghosts first (under live sprites): deactivated objects at their true
	   frozen sim positions, read straight from the object list -- the
	   engine stops placing their sprites at the vanilla activation border,
	   which the wide view puts on screen (edge pop-in otherwise). */
	{
		Sint16 K13_GhostMax(void);
		int K13_GhostGet(Sint16, Sint32 *, Sint32 *, Sint16 *);
		Sint16 gmax = K13_GhostMax(), gi;

		for (gi = 1; gi < gmax; gi++)
		{
			Sint32 gx, gy;
			Sint16 gshape;

			if (K13_GhostGet(gi, &gx, &gy, &gshape))
				k13_comp_sprite(gshape,
				                (int)(gx / PIXGLOBAL) - camx,
				                (int)(gy / PIXGLOBAL) - camy);
		}
	}

	/* sprites, interpolated in world space (match prev by list index) */
	for (i = 0; i < k13_nspr_show; i++)
	{
		Sint32 wx = k13_spr_show[i].wx, wy = k13_spr_show[i].wy;
		if (k13_smooth && i < k13_nspr_prev)
		{
			Sint32 dx = wx - k13_spr_prev[i].wx;
			Sint32 dy = wy - k13_spr_prev[i].wy;
			if (dx < 32 * (Sint32)PIXGLOBAL && dx > -32 * (Sint32)PIXGLOBAL &&
			    dy < 32 * (Sint32)PIXGLOBAL && dy > -32 * (Sint32)PIXGLOBAL)
			{
				wx = k13_lerp32(k13_spr_prev[i].wx, wx, num, den);
				wy = k13_lerp32(k13_spr_prev[i].wy, wy, num, den);
			}
		}
		k13_comp_sprite(k13_spr_show[i].shape,
		                (int)(wx / PIXGLOBAL) - camx,
		                (int)(wy / PIXGLOBAL) - camy);
	}

	/* foreground tiles straight from the map (globally z-correct) */
	for (ty = ty0; ty <= (camy + 199) / 16 && ty < maph; ty++)
	{
		for (tx = tx0; tx <= (camx + k13_comp_w - 1) / 16 && tx < mapw; tx++)
		{
			Uint16 t = mapplane[0][ty * mapw + tx];
			Sint16 cls;
			if (t >= K13_MAXTILES)
				continue;
			cls = intile[t];
			if (cls >= 0)
				continue;
			k13_comp_tile((Uint32)(t << 5), tx * 16 - camx, ty * 16 - camy,
			              cls == -2);
		}
	}

	/* screen-anchored pics (piclist), centered like the 320 view */
	for (i = 0; i < (int)picsshown; i++)
	{
		pictype *pic = &pictable[piclist[i].num];
		Uint32 src = k13_picoff + k13_farval_to_linear(pic->shapeptr);
		int px = (piclist[i].x - 4) * 8 + (k13_comp_w - 320) / 2;
		int py = piclist[i].y - 32;
		int row, col, bit;
		for (row = 0; row < pic->height; row++)
		{
			int y = py + row;
			if (y < 0 || y >= 200)
				continue;
			for (col = 0; col < pic->width; col++)
			{
				Uint8 b0 = k13_ega[0][(src + row * pic->width + col) & 0xFFFF];
				Uint8 b1 = k13_ega[1][(src + row * pic->width + col) & 0xFFFF];
				Uint8 b2 = k13_ega[2][(src + row * pic->width + col) & 0xFFFF];
				Uint8 b3 = k13_ega[3][(src + row * pic->width + col) & 0xFFFF];
				for (bit = 0; bit < 8; bit++)
				{
					int x = px + col * 8 + bit;
					int sh = 7 - bit;
					if (x < 0 || x >= k13_comp_w)
						continue;
					k13_comp[y * K13_COMP_MAXW + x] =
						(Uint8)(((b0 >> sh) & 1) | (((b1 >> sh) & 1) << 1) |
						        (((b2 >> sh) & 1) << 2) |
						        (((b3 >> sh) & 1) << 3));
				}
			}
		}
	}

	if (getenv("K13_TRACE_CAM"))
	{
		fprintf(stderr, "CAM %ld %ld %ld\n", (long)camx, num, den);
		fflush(stderr);
	}

	/* an in-game popup (save, quit, sound, "Keens Left"...) is drawn to
	   the EGA page; copy its window rectangle over the wide world so the
	   gameplay stays 16:9 behind it instead of flipping to 4:3 */
	if (k13_dialog_active)
	{
		/* The popup was drawn to the pinned page (see k13_drawbase), so
		   its bytes are at base + row*SCREENWIDTH + charcol.  Two rules:

		   - copy the window's EXACT char rect.  Any margin would paste
		     page-world bytes, and the page world sits at the sim's own
		     scroll position -- offset from the composed (interpolated,
		     wider) world -- so a margin shows up as a distorted sliver
		     along the window edge.

		   - center the rect in the wide frame.  The game centers windows
		     on screencenterx = SCREENWIDTH/2-1 = 23, i.e. on the 48-byte
		     VIRTUAL page (384px), not the 320px screen; on hardware the
		     paragraph-floored draw base cancels most of that back out.
		     Composing straight from page bytes has no such cancellation,
		     so center it explicitly -- and it stays put while scrolling
		     instead of wobbling with the pel pan as DOS does. */
		extern Uint32 k13_dialog_base;
		Uint32 base = k13_dialog_base;
		int bc0 = k13_dlg_xl, bc1 = k13_dlg_xh;
		int ly0 = k13_dlg_yl * 8, ly1 = (k13_dlg_yh + 1) * 8;
		int off = k13_comp_w / 2 - ((bc0 + bc1 + 1) * 8) / 2;
		int bc, ly, px;

		if (ly0 < 0) ly0 = 0;
		if (ly1 > 200) ly1 = 200;
		for (ly = ly0; ly < ly1; ly++)
		{
			Uint32 rowbase = base + (Uint32)ly * SCREENWIDTH;
			for (bc = bc0; bc <= bc1; bc++)
			{
				Uint32 addr = (rowbase + (Uint32)bc) & 0xFFFF;
				Uint8 b0 = k13_ega[0][addr], b1 = k13_ega[1][addr];
				Uint8 b2 = k13_ega[2][addr], b3 = k13_ega[3][addr];
				for (px = 0; px < 8; px++)
				{
					int sh = 7 - px;
					int idx = ((b0 >> sh) & 1) | (((b1 >> sh) & 1) << 1) |
					          (((b2 >> sh) & 1) << 2) | (((b3 >> sh) & 1) << 3);
					int dx = bc * 8 + px + off;
					if (dx >= 0 && dx < k13_comp_w)
						k13_comp[ly * K13_COMP_MAXW + dx] = (Uint8)idx;
				}
			}
		}
	}

	k13_comp_have = 1;
	return 1;
}

/* compose at "now" and present (called between sim frames while pacing) */
static void k13_present_interp(void)
{
#ifdef K13_WITH_SDL
	long num = (long)(SDL_GetTicks() - k13_refresh_ms);
	long den = ((long)k13_frame_len_tics * 8192000L) / 1193182L;

	if (den < 1)
		den = 1;

	if (num < 0)
		num = 0;
	if (num > den)
		num = den;
	if (k13_compose(num, den))
		k13_present();
#endif
}

static int k13_world_live_dbg(void) { return k13_world_live; }
static int k13_nspr_dbg(void) { return k13_nspr_cur; }

/*
=============================================================================
	Config accessors + persistence (KEENLNCH.CFG next to the game data)
	Called by the native Options menu (KEENSCRN.C).
=============================================================================
*/

int K13_GetWideWidth(void)
{
	k13_comp_config();
	return k13_comp_w;
}

void K13_SetWideWidth(int w)
{
	k13_comp_config();
	if (w == 0 || (w >= 320 && w <= K13_COMP_MAXW))
		k13_comp_w = w;
}

int K13_GetSmooth(void)
{
	k13_comp_config();
	return k13_smooth;
}

void K13_SetSmooth(int on)
{
	k13_comp_config();
	k13_smooth = on ? 1 : 0;
}

void K13_ConfigLoad(void)
{
	FILE *f = fopen("KEENLNCH.CFG", "r");
	int w, sm;

	k13_comp_config();
	if (!f)
		return;
	{
		int of = k13_onefire;
		int n = fscanf(f, "wide=%d smooth=%d onefire=%d", &w, &sm, &of);
		if (n >= 2)
		{
			if (w == 0 || (w >= 320 && w <= K13_COMP_MAXW))
				k13_comp_w = w;
			k13_smooth = sm ? 1 : 0;
		}
		if (n >= 3)
			k13_onefire = of ? 1 : 0;
	}
	/* second line (optional -- configs written before rebinding shipped
	   simply keep the defaults).  Accepts the older 5-value form too, where
	   each action had a single binding. */
	{
		int v[22];
		int i;
		/* Current form is 22 values (11 actions x 2 slots).  A short read means
		   an older config: 12 = 6 actions x 2, 9 = 4 actions x 2 plus the fire
		   key, 5 = 4 actions with one binding each plus the fire key.  Whatever
		   an old form did not cover keeps its default, so newly added actions
		   arrive at their defaults rather than blank. */
		int n = fscanf(f, " bind=%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,"
		                  "%d,%d,%d,%d,%d,%d,%d,%d",
		               &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6],
		               &v[7], &v[8], &v[9], &v[10], &v[11], &v[12], &v[13],
		               &v[14], &v[15], &v[16], &v[17], &v[18], &v[19],
		               &v[20], &v[21]);
		if (n >= 12 && (n & 1) == 0)
		{
			/* whole action pairs only, so a truncated file cannot half-apply */
			for (i = 0; i < n / 2 && i < K13_BIND_COUNT; i++)
			{
				k13_bind[i][0] = v[i * 2];
				k13_bind[i][1] = v[i * 2 + 1];
			}
		}
		else if (n == 9)
		{
			for (i = 0; i < 4; i++)
			{
				k13_bind[i][0] = v[i * 2];
				k13_bind[i][1] = v[i * 2 + 1];
			}
			k13_keybind[K13_KEY_FIRE] = (v[8] > 0 && v[8] < 128) ? v[8] : 0x2A;
		}
		else if (n == 5)
		{
			for (i = 0; i < 4; i++)
			{
				k13_bind[i][0] = v[i];
				k13_bind[i][1] = -1;   /* old configs had no alternate */
			}
			k13_keybind[K13_KEY_FIRE] = (v[4] > 0 && v[4] < 128) ? v[4] : 0x2A;
		}
	}
	/* Sanitize: the old two-press bind flow could write the same button into
	   both slots of an action (or onto two actions).  Heal such configs on
	   load -- first occurrence wins, duplicates clear. */
	{
		int a, b, sl, sl2;

		for (a = 0; a < K13_BIND_COUNT; a++)
			if (k13_bind[a][1] >= 0 && k13_bind[a][1] == k13_bind[a][0])
				k13_bind[a][1] = -1;
		for (a = 0; a < K13_BIND_COUNT; a++)
			for (sl = 0; sl < 2; sl++)
			{
				int code = k13_bind[a][sl];
				if (code < 0)
					continue;
				for (b = a; b < K13_BIND_COUNT; b++)
					for (sl2 = (b == a) ? sl + 1 : 0; sl2 < 2; sl2++)
						if (k13_bind[b][sl2] == code)
							k13_bind[b][sl2] = -1;
			}
	}
	{
		int k[K13_KEY_COUNT];
		int i;
		/* keys= grew with the action list; a short line just leaves the newer
		   actions at their defaults.  0 is a legitimate value here: cleared. */
		int n = fscanf(f, " keys=%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
		               &k[0], &k[1], &k[2], &k[3], &k[4], &k[5], &k[6],
		               &k[7], &k[8], &k[9], &k[10]);

		for (i = 0; i < n && i < K13_KEY_COUNT; i++)
			if (k[i] >= 0 && k[i] < 128)
				k13_keybind[i] = k[i];
	}
	{
		int sb = k13_scorebox;

		if (fscanf(f, " scorebox=%d", &sb) == 1)
			k13_scorebox = sb ? 1 : 0;
	}
	{
		extern int k13_galaxysfx, k13_galaxymus;
		int bd, qc = k13_qsconfirm, fs = k13_fullscreen, gs = k13_galaxysfx;
		int gm = k13_galaxymus;
		int n = fscanf(f, " backdrop=%d qsconfirm=%d fullscreen=%d galaxysfx=%d galaxymus=%d",
		               &bd, &qc, &fs, &gs, &gm);
		if (n >= 1)
			k13_backdrop = bd;
		if (n >= 2)
			k13_qsconfirm = qc ? 1 : 0;
		if (n >= 3)
			k13_fullscreen = fs ? 1 : 0;
		if (n >= 4)
			k13_galaxysfx = gs ? 1 : 0;
		if (n >= 5)
			k13_galaxymus = gm ? 1 : 0;
	}
	fclose(f);
}

void K13_ConfigSave(void)
{
	FILE *f = fopen("KEENLNCH.CFG", "w");

	if (!f)
		return;
	fprintf(f, "wide=%d smooth=%d onefire=%d\n", k13_comp_w,
	        k13_smooth, k13_onefire);
	fprintf(f, "bind=%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
	        k13_bind[K13_BIND_JUMP][0], k13_bind[K13_BIND_JUMP][1],
	        k13_bind[K13_BIND_POGO][0], k13_bind[K13_BIND_POGO][1],
	        k13_bind[K13_BIND_FIRE][0], k13_bind[K13_BIND_FIRE][1],
	        k13_bind[K13_BIND_STATUS][0], k13_bind[K13_BIND_STATUS][1],
	        k13_bind[K13_BIND_QSAVE][0], k13_bind[K13_BIND_QSAVE][1],
	        k13_bind[K13_BIND_QLOAD][0], k13_bind[K13_BIND_QLOAD][1],
	        k13_bind[K13_BIND_HELP][0], k13_bind[K13_BIND_HELP][1],
	        k13_bind[K13_BIND_SOUND][0], k13_bind[K13_BIND_SOUND][1],
	        k13_bind[K13_BIND_SAVEMENU][0], k13_bind[K13_BIND_SAVEMENU][1],
	        k13_bind[K13_BIND_QUIT][0], k13_bind[K13_BIND_QUIT][1],
	        k13_bind[K13_BIND_SCOREBOX][0], k13_bind[K13_BIND_SCOREBOX][1]);
	{
		int i;

		fprintf(f, "keys=");
		for (i = 0; i < K13_KEY_COUNT; i++)
			fprintf(f, "%s%d", i ? "," : "", k13_keybind[i]);
		fprintf(f, "\n");
	}
	fprintf(f, "scorebox=%d\n", k13_scorebox);
	/* fullscreen belongs here too: the loader has always read it, but the
	   writer dropped it, so the Options toggle never survived a restart */
	{
		extern int k13_galaxysfx, k13_galaxymus;
		fprintf(f, "backdrop=%d qsconfirm=%d fullscreen=%d galaxysfx=%d galaxymus=%d\n",
		        k13_backdrop, k13_qsconfirm, k13_fullscreen, k13_galaxysfx,
		        k13_galaxymus);
	}
	fclose(f);
}

int K13_GetOneFire(void)
{
	return k13_onefire;
}

void K13_SetOneFire(int on)
{
	k13_onefire = on ? 1 : 0;
}

/*
=============================================================================
	Quicksave: full simulation state, saveable mid-level.

	The game's own save files (SAVED1..9.CKx) hold gamestate only -- world
	position and inventory -- which is why the original can save on the world
	map and nowhere else.  Those files are byte-compatible with DOS and are
	NOT touched here.  This is a separate, port-only file that captures the
	whole simulation so a level can be resumed exactly.

	WHAT COUNTS AS SIMULATION STATE is not guessed: k13_state_hashes() (the
	replay harness) already enumerates it, and this saves precisely that set
	-- objlist, pobjlist, numobj, gamestate, origin, level and the RNG.  Keep
	the two in step: if a field joins the hash, it belongs in here too.

	Objects hold raw function pointers (think, contact) rather than indices
	into an action table the way Keen 4-6 does, so those are stored as names
	via the generated registry in k13_thinktable.inc.  An unknown pointer
	aborts the save instead of writing a file that would crash on load.

	THE MAP PLANES ARE SAVED TOO (v2).  v1 assumed nothing writes to
	mapplane, which is wrong: the act code edits tiles constantly --
	collected bonus items are BLANKED TILES (KEENACTS.C GotBonus), and
	switches, keycard doors, melted ice blocks and the Keen 2 city
	machines are all SETTILE calls.  Restoring objects over a freshly
	ReadLevel'd map resurrected every pickup (and re-locked every door);
	restoring over the live map kept edits made AFTER the save.  Both
	planes now round-trip, so the level comes back tile-exact.

	NOTE pobjs go through the same registry.  An earlier guess that their
	think could be rebuilt from the `type` field is wrong: POBJ_BRIDGE runs
	BridgeCreate, BridgeRemove or NullPThink depending on where it is in its
	cycle, so the type says nothing about the current behaviour.
=============================================================================
*/

#define K13_QS_MAGIC "K13QSAVE"
#define K13_QS_VERSION 2

typedef struct
{
	const char *name;
	void *fn;
} K13_FnEntry;

#include "k13_thinktable.inc"

#define K13_FNCOUNT ((int)(sizeof(k13_fntable) / sizeof(k13_fntable[0])))

/* pointer -> registry index; -1 for NULL, -2 when unknown (a bug) */
static int k13_fn_index(void *fn)
{
	int i;

	if (!fn)
		return -1;
	for (i = 0; i < K13_FNCOUNT; i++)
		if (k13_fntable[i].fn == fn)
			return i;
	return -2;
}

static void *k13_fn_lookup(int idx)
{
	if (idx < 0 || idx >= K13_FNCOUNT)
		return NULL;
	return k13_fntable[idx].fn;
}

/* the data part of an object: everything ahead of the function pointers */
#define K13_OBJ_DATA offsetof(objtype, think)
#define K13_POBJ_DATA offsetof(pobjtype, think)

static const char *k13_qs_path(void)
{
	static char path[16];
	sprintf(path, "QUICKSAV.%s", _extension);
	return path;
}

/* Returns 1 on success. Writes nothing if a behaviour function is missing
 * from the registry -- better to refuse than to save a file that cannot be
 * loaded (re-run gen_thinktable.py if this fires). */
int K13_QuickSave(void)
{
	FILE *f;
	Sint16 i;
	Sint16 hdr[4];

	for (i = 0; i < MAXOBJECTS; i++)
	{
		if (k13_fn_index((void *)objlist[i].think) == -2 ||
		    k13_fn_index((void *)objlist[i].contact) == -2)
		{
			fprintf(stderr, "K13 QUICKSAVE: object %d runs a function that is "
			                "not in k13_thinktable.inc; regenerate it\n", i);
			fflush(stderr);
			return 0;
		}
	}
	for (i = 0; i < MAXPOBJECTS; i++)
	{
		if (k13_fn_index((void *)pobjlist[i].think) == -2)
		{
			fprintf(stderr, "K13 QUICKSAVE: pobj %d runs a function that is "
			                "not in k13_thinktable.inc; regenerate it\n", i);
			fflush(stderr);
			return 0;
		}
	}

	f = fopen(k13_qs_path(), "wb");
	if (!f)
		return 0;

	fwrite(K13_QS_MAGIC, 1, 8, f);
	hdr[0] = K13_QS_VERSION;
	hdr[1] = EPISODE;
	hdr[2] = (Sint16)level;
	hdr[3] = numobj;
	fwrite(hdr, sizeof(hdr[0]), 4, f);

	fwrite(&gamestate, sizeof(gamestate), 1, f);
	fwrite(&originx, sizeof(originx), 1, f);
	fwrite(&originy, sizeof(originy), 1, f);

	for (i = 0; i < MAXOBJECTS; i++)
	{
		Sint16 fns[2];
		fwrite(&objlist[i], K13_OBJ_DATA, 1, f);
		fns[0] = (Sint16)k13_fn_index((void *)objlist[i].think);
		fns[1] = (Sint16)k13_fn_index((void *)objlist[i].contact);
		fwrite(fns, sizeof(fns[0]), 2, f);
	}
	for (i = 0; i < MAXPOBJECTS; i++)
	{
		Sint16 fn = (Sint16)k13_fn_index((void *)pobjlist[i].think);
		fwrite(&pobjlist[i], K13_POBJ_DATA, 1, f);
		fwrite(&fn, sizeof(fn), 1, f);
	}

	/* Level-scoped globals that LevelLoop resets on entry.  These are NOT in
	   k13_state_hashes() -- a gap in the harness rather than in the sim -- but
	   a restored level is wrong without them: pobjcount decides where the next
	   door or bridge is allocated, lastdir which way Keen shoots. */
	{
		Sint16 extras[6];
		extras[0] = pobjcount;
		extras[1] = lastdir;
		extras[2] = (Sint16)LevelDone;
		extras[3] = (Sint16)cheatmode;
		extras[4] = ankhtime;
		extras[5] = 0;
		fwrite(extras, sizeof(extras[0]), 6, f);
		fwrite(&timecount, sizeof(timecount), 1, f);
		fwrite(&lasttimecount, sizeof(lasttimecount), 1, f);
	}

	K13_RndSave(f);

	/* the map planes, exactly as the level stands: blanked pickups, thrown
	   switches, opened doors and all (see the header comment) */
	{
		Sint16 minfo[2];

		minfo[0] = levelheader->planes;
		minfo[1] = 0;
		fwrite(minfo, sizeof(minfo[0]), 2, f);
		fwrite(&levelheader->planesize, sizeof(levelheader->planesize), 1, f);
		for (i = 0; i < levelheader->planes; i++)
			fwrite(mapplane[i], 1, (size_t)levelheader->planesize, f);
	}
	fclose(f);
	return 1;
}

/* Restore into the live simulation. The caller is responsible for having the
 * right level's map loaded; see K13_QuickLoadLevel(). */
int K13_QuickLoad(void)
{
	FILE *f;
	char magic[8];
	Sint16 hdr[4], i;

	f = fopen(k13_qs_path(), "rb");
	if (!f)
		return 0;
	if (fread(magic, 1, 8, f) != 8 || memcmp(magic, K13_QS_MAGIC, 8) != 0)
	{
		fclose(f);
		return 0;
	}
	if (fread(hdr, sizeof(hdr[0]), 4, f) != 4 ||
	    hdr[0] != K13_QS_VERSION || hdr[1] != EPISODE)
	{
		fclose(f);
		return 0;
	}

	fread(&gamestate, sizeof(gamestate), 1, f);
	fread(&originx, sizeof(originx), 1, f);
	fread(&originy, sizeof(originy), 1, f);

	for (i = 0; i < MAXOBJECTS; i++)
	{
		Sint16 fns[2];
		fread(&objlist[i], K13_OBJ_DATA, 1, f);
		fread(fns, sizeof(fns[0]), 2, f);
		objlist[i].think = (void (*)(void))k13_fn_lookup(fns[0]);
		objlist[i].contact =
			(void (*)(objtype *, objtype *))k13_fn_lookup(fns[1]);
	}
	for (i = 0; i < MAXPOBJECTS; i++)
	{
		Sint16 fn;
		fread(&pobjlist[i], K13_POBJ_DATA, 1, f);
		fread(&fn, sizeof(fn), 1, f);
		pobjlist[i].think = (void (*)(pobjtype *))k13_fn_lookup(fn);
	}

	{
		Sint16 extras[6];
		fread(extras, sizeof(extras[0]), 6, f);
		pobjcount = extras[0];
		lastdir = extras[1];
		LevelDone = (exittype)extras[2];
		cheatmode = (boolean)extras[3];
		ankhtime = extras[4];
		fread(&timecount, sizeof(timecount), 1, f);
		fread(&lasttimecount, sizeof(lasttimecount), 1, f);
	}

	K13_RndLoad(f);

	/* map planes: the caller has this level's map loaded (same level, or
	   the pending-apply path right after ReadLevel), so the geometry always
	   matches -- the check is pure defensiveness against a truncated file */
	{
		Sint16 minfo[2];
		Uint16 psize;

		if (fread(minfo, sizeof(minfo[0]), 2, f) == 2 &&
		    fread(&psize, sizeof(psize), 1, f) == 1 &&
		    minfo[0] == levelheader->planes &&
		    psize == levelheader->planesize)
		{
			for (i = 0; i < minfo[0]; i++)
				fread(mapplane[i], 1, (size_t)psize, f);
		}
	}
	fclose(f);
	numobj = hdr[3];
	return 1;
}

/* A quickload that targets a different level cannot be applied on the spot:
 * the map has to be loaded first.  The request is parked here, the world map
 * loop hands control to that level, and LevelLoop applies the state once the
 * map is up (see the K13_PORT hooks in KEENDEMO.C and KEENACTS.C). */
static int k13_qload_pending;

int K13_QLoadPending(void)
{
	return k13_qload_pending;
}

void K13_QLoadRequest(void)
{
	k13_qload_pending = 1;
}

/* called by LevelLoop once the map is loaded */
void K13_QLoadApply(void)
{
	if (!k13_qload_pending)
		return;
	k13_qload_pending = 0;
	K13_QuickLoad();
}

/* which level a quicksave holds, or -1 if there is no usable file */
int K13_QuickSaveLevel(void)
{
	FILE *f = fopen(k13_qs_path(), "rb");
	char magic[8];
	Sint16 hdr[4];
	int lvl = -1;

	if (!f)
		return -1;
	if (fread(magic, 1, 8, f) == 8 && memcmp(magic, K13_QS_MAGIC, 8) == 0 &&
	    fread(hdr, sizeof(hdr[0]), 4, f) == 4 &&
	    hdr[0] == K13_QS_VERSION && hdr[1] == EPISODE)
		lvl = hdr[2];
	fclose(f);
	return lvl;
}

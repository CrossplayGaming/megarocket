/* Keen Launcher port: game-data tables, filled AT BOOT from the player's
 * own KEEN{1,2,3}.EXE by K13_RipTables() (idlib13.c).
 *
 * The DOS reconstruction linked this data into the executable at build
 * time (STATIC/rip.bat + ckpatch); the port used to do the same via
 * generated C arrays ripped from the user's exe.  For distribution the
 * arrays are zero here -- no id Software data ships in the binary -- and
 * the boot ripper performs the exact same UNLZEXE + offset extraction on
 * the user's exe every launch.  Array sizes are the v1.31 layouts. */

#if (EPISODE == 1)

int nexttile[611];
int intile[611];
int northwall[611];
int eastwall[611];
int southwall[611];
int westwall[611];
char endscreen[4008];

#elif (EPISODE == 2)

int nexttile[689];
int intile[689];
int northwall[689];
int eastwall[689];
int southwall[689];
int westwall[689];
char endscreen[4008];
char _sounds[12554];
char endtext[892];
char helptext[2014];
char previews[1813];
char storytxt[3224];

#else

int nexttile[715];
int intile[715];
int northwall[715];
int eastwall[715];
int southwall[715];
int westwall[715];
char endscreen[4008];
char _sounds[16224];
char helptext[1996];
char endtext[828];
char previews[1764];
char storytxt[3107];

#endif

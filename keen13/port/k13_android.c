/*
Keen Launcher: Keen 1-3 port, Android entry point.

SDLActivity dlopens the game library and calls its exported SDL_main.
The reconstruction's own entry is Borland-style `void main(Sint16, char **)`
(renamed to k13_realmain by the Android build), so wrap it — and first
chdir into the app-specific external storage directory, which stands in
for the game folder: every relative fopen/open in the engine then works
unchanged, and it is adb-pushable with no runtime permission.
*/

#include <unistd.h>
#include "SDL.h"

void k13_realmain(int argc, char **argv);

int SDL_main(int argc, char *argv[])
{
	const char *storagePath = SDL_AndroidGetExternalStoragePath();
	if (storagePath)
		chdir(storagePath);
	k13_realmain(argc, argv);
	return 0;
}

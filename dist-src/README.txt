MEGAROCKET
==========
All seven Commander Keen games, playable from the couch on a modern
display: 16:9 widescreen, high-refresh smooth motion, quicksave, full
controller support and rebinding, crisp pixels always -- and still
simulation-identical to DOS, proven by replaying recorded input against
per-frame state checksums.

Megarocket contains NO game data whatsoever.  It plays YOUR copies of
the games: every byte of id Software's data -- graphics, levels, sounds,
even the data tables inside the original executables -- is read or
reconstructed from the files you supply, on your machine, at first run.
If a slot has no data, it simply stays dark.

GETTING STARTED
---------------
1. Copy each game's original files LOOSE into its folder, next to the
   engine exe that is already there -- do NOT drop a folder inside the
   folder.  Every game folder contains a "PUT ... FILES HERE.txt" that
   lists exactly what belongs in it.  The Steam releases work great; so
   do original DOS copies.

   Right:  keen13\gamedata\KEEN1.EXE
   Wrong:  keen13\gamedata\Keen1\KEEN1.EXE

2. Run "Start Megarocket.bat" (or launcher\Megarocket.exe).
3. Slots light up READY as their files are found.  On first selection a
   game briefly runs once to render its own title art for the menu.

WHERE THE FILES GO
------------------
  KEEN 1        keen13\gamedata    needs KEEN1.EXE + all .CK1 files
  KEEN 2        keen13\gamedata2   needs KEEN2.EXE + all .CK2 files
  KEEN 3        keen13\gamedata3   needs KEEN3.EXE + all .CK3 files
  KEEN 4        rt                 needs EGAGRAPH/GAMEMAPS/AUDIO.CK4 etc.
  KEEN 5        rt                 needs the .CK5 files
  KEEN 6        rt                 needs the .CK6 files (see note below)
  KEEN DREAMS   keendreams\game    needs kdreams.exe + .KDR files

Keen 1-3 also need the original KEEN?.EXE in their folders: the engine
reads id's data tables out of it at every boot (v1.31 and v1.1
executables are supported).

KEEN 6 VERSIONS
---------------
Keen 6 shipped in versions 1.0, 1.4 and 1.5, and the engine metadata
differs.  Megarocket comes set up for v1.4 (the most common).  If your
copy is v1.0 or v1.5, copy the contents of rt\keen6-data\e10 or
rt\keen6-data\e15 over the files in rt\ first.

GALAXY AUDIO IN KEEN 1-3 (bonus)
--------------------------------
If Keen 4 and 5 are installed, the launcher renders their AdLib sound
effects and music from YOUR data (this takes a few seconds, once) and
Keen 1-3 gain two Options-menu toggles: "Galaxy sfx" and "Galaxy tunes".
Without Keen 4/5 the toggles read N/A.

IN THE GAMES
------------
  F5 / F7   quicksave      F9  quickload
  F11       toggle fullscreen
  Keen 1-3: Options menu for view size, smooth motion, rebinding,
            score box, Galaxy audio.  Keen Dreams: F6 pad rebinding.

CREDITS
-------
Megarocket stands on the shoulders of giants:
  * Keen 1-3 engine: K1n9_Duk3's GPL source reconstruction
  * Keen 4-6 engine: Omnispeak, by David Gow and contributors
  * Keen Dreams engine: ReflectionHLE (refkeen), by NY00123
  * OPL emulation: DBOPL from the DOSBox project
All engine code is GPL v2 or later; Megarocket's modifications are
likewise GPL.  Commander Keen is a trademark of its owners; this project
is an unaffiliated fan effort and includes none of their data.

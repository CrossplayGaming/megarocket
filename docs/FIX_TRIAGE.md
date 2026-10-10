# Megarocket 2.0 — Bug-Fix Triage (seed list)

Status: draft for approval, 2026-10-09. Ledger unit **FIX-03**. Feeds FIX-01 (the fix tables) and
FIX-02 (one replay case per fix). Governing decisions: J-03 (`BLUEPRINT.md`), the bug-fix list in
`MENUS.md`.

This document goes through every known-bug note in the three sources the ports are built from and
decides, for each one, whether it becomes a toggle in the in-game Fixes list.

| Verdict | Meaning |
|---|---|
| **fix** | A real defect a player would want fixed, and a toggle can switch it cleanly. The entry says what the fix changes and where the port would check the toggle. |
| **keep** | (*keep-as-feature*) A quirk players rely on or that is part of the game's feel (speedrun tricks, famous glitches). It stays as is; a toggle may be offered later. |
| **not-a-bug** | No player-visible effect in the versions Megarocket runs, a note about how the source port emulates DOS, or a bug of the source port rather than of the original game. |

Versions in play (`REFERENCES.md`): Keen 1–3 **v1.31**, Keen 4/5 **v1.4**, Keen 6 **v1.0**, Keen
Dreams **v1.00 / v1.93** (EGA). A bug that exists only in another version (e.g. the 1.0 beta or
1.34) can't happen in Megarocket, so it is marked not-a-bug for that reason.

"Provisional" means the effect could not be pinned down from the code alone. A short replay should
settle it before FIX-01 is built. These cases are collected under **Needs your judgment** at the
end.

---

## Part A — Keen 1–3 (`keen13/`, the `BUG:` annotations)

### How the grep count of 63 adds up

`grep -rn "BUG:" keen13` returns 63 lines:

| Where | Lines | What they are |
|---|---|---|
| `keen13/reconstruction/*.C` | 28 | K1n9_Duk3's annotations, the actual seed |
| `keen13/port/*.C` | 28 | The project's own C port carries the reconstruction's files with the same annotations, word for word (only the line numbers differ) |
| `keen13/port/build/CMakeCache.txt` (lines 29, 47, 73, 112, 129, 156) and `keen13/port/build/CMakeFiles/CMakeConfigureLog.yaml:79` | 7 | False matches: the text `DEBUG:` (CMake build flags) contains `BUG:` |

Each row below covers one reconstruction annotation and its copy in the port, so both line
numbers are given. The same bug is grouped only where it is plainly one defect written down twice:
V10 (the same missing clean-up on two abort paths), V16 (one check in two version variants) and
V19 (width and height in one function). That gives 25 rows for 28 annotations, or 56 grep lines.
The 7 CMake lines are false matches. 56 + 7 = **63 = the grep count.**

The port's file names are `godot/games/vorticons/vort_*.gd`; the function names follow the C source.

| ID | Source (reconstruction / port copy) | Game | What happens, in plain words | Verdict | Reason / the fix |
|---|---|---|---|---|---|
| V01 | `KEEN1ACT.C:388` / `port/KEEN1ACT.C:388` | K1 | When a Yorp finishes standing still, it gets its walking speed one frame early, so it shuffles a step during its last "standing" frame. | not-a-bug | A step of a pixel or two, one frame, not noticeable. |
| V02 | `KEEN1ACT.C:695` / `port/KEEN1ACT.C:695` | K1 | Same as V01, for the Vorticons. | not-a-bug | As V01. |
| V03 | `KEEN2ACT.C:422` / `port/KEEN2ACT.C:422` | K2 (the same unannotated code is in K3's `GruntStand`, `KEEN3ACT.C:729`) | Same as V01, for the Vorticon guards ("Grunts"). | not-a-bug | As V01. |
| V04 | `KEEN1ACT.C:1291` / `port/KEEN1ACT.C:1291` | K1 | Shooting the chain on the last level drops the block and "kills the Vorticon" by searching the creature list for any Vorticon. If the Commander is already dead (shot with the raygun), there is no Vorticon to find, and the search runs off the start of the list: the original hangs or scribbles over memory. | **fix** | Only kill a Vorticon if a live one exists; otherwise just drop the block. Read in `ChainContact` (`vort_keen1.gd:576`). **See the judgment note: the port's current handling of this case is neither the original nor the fix.** |
| V05 | `KEEN2ACT.C:1590` / `port/KEEN2ACT.C:1590` | K2 | The "Earth explodes" game-over scene is meant to be skippable with Esc. In v1.3+ the game's own keyboard handler keeps the BIOS key buffer empty, so Esc does nothing and the scene always plays to the end. | **fix** | Honour Esc as intended. Read in `TheEarthExplodes` (`vort_keen2.gd:654`, the loop that now says "no early exit"). |
| V06 | `KEEN2ACT.C:1714` / `port/KEEN2ACT.C:1714` | K2 | Same as V05, for the ending's ship-flight scene. | **fix** | Same toggle as V05. Read in `_finale_other` (`vort_keen2.gd:725`). |
| V07 | `KEEN2ACT.C:1758` / `port/KEEN2ACT.C:1758` | K2 | A screen-alignment mask has one hex digit missing. | not-a-bug | The missing digit only affects positions far beyond any map, so the result is always the same. |
| V08 | `KEEN3ACT.C:935` / `port/KEEN3ACT.C:935` | K3 | A Vorticon Mother is meant to turn round at a ledge without dropping. The code that should cancel her downward step resets the wrong value, so she still drops a fraction of a pixel at the edge. Because she then ends up slightly "inside" the ground row, she may not detect the floor on the next frames either. | not-a-bug (provisional) | From the code she may jitter or sink at ledge edges. Whether that is visible in play is unconfirmed: needs a replay look. If it shows, this becomes a fix: in `WomanWalk` (`vort_keen3.gd:429`), zero her downward move instead of resetting her height. |
| V09 | `KEEN3ACT.C:2630` / `port/KEEN3ACT.C:2630` | K3 | Same mask slip as V07. | not-a-bug | As V07. |
| V10 | `KEENDEMO.C:334`, `:368` / `port/KEENDEMO.C:333`, `:367` | K1–3 v1.0 | On a disk error, version 1.0 leaves its sound and keyboard handlers installed when it aborts to DOS. | not-a-bug | Version 1.0 only, and DOS-only (disk errors and interrupt handlers don't exist in the port). |
| V11 | `KEENDEMO.C:651` / `port/KEENDEMO.C:691` | K1 beta | Entering a level doesn't strip a flag bit from the level number. | not-a-bug | Pre-1.0 beta only. v1.31 masks it, and the port does too (`vort_demo.gd` `WorldMap`). |
| V12 | `KEENDEMO.C:688` / `port/KEENDEMO.C:728` | K2 | After Keen flips a Tantalus switch ("Oops."), the level has already faded to black, but the game fades out a second time. The fade routine starts by setting the full palette, so the "Oops." screen pops back for a moment before fading again. | **fix** | Skip the second fade. Read in `WorldMap` (`vort_demo.gd`, the `ex_tantalus` branch, line 213). The flash is worked out from the fade table (`IDLIBC.C:1842`, `colors[3]` = full palette); confirm in the replay case. |
| V13 | `KEENDEMO.C:790` / `port/KEENDEMO.C:830` | K3 | Riding Messie (the lake monster) on the map: the "Keen on Messie" picture is chosen before the code checks whether Keen got on or off, so for one frame you can see Keen on Messie's back *and* Keen standing on the shore. | **fix** | Choose Messie's picture at the end of the routine. Read in `_update_messie` (`vort_keen3.gd:1249`). |
| V14 | `KEENDEMO.C:867` / `port/KEENDEMO.C:907` | K3 | While riding Messie with no direction held, the shore check reads one entry past its direction table. | not-a-bug | The value it lands on is never a shore tile, so nothing happens (the port already skips the check, `vort_keen3.gd:1302`). |
| V15 | `KEENDEMO.C:932` / `port/KEENDEMO.C:972` | K1 ≤ v1.1 | Clearing the level-entrance list uses the wrong counter and can corrupt memory. | not-a-bug | v1.1 and earlier only. v1.31 uses the right counter. |
| V16 | `KEENDEMO.C:969`, `:971` / `port/KEENDEMO.C:1009`, `:1011` | K1–3 | Scanning the world map, a level number above the number of levels would write past the entrance list. | not-a-bug | The shipped maps only hold valid numbers. It could matter only for modded maps. |
| V17 | `KEENDEMO.C:1680` / `port/KEENDEMO.C:1724` | K1 ≤ v1.1 | The high-score "cities saved" count skips the last city. | not-a-bug | v1.1 and earlier only; those versions exist only for Keen 1, which has no cities to count. |
| V18 | `KEENMAIN.C:164` / `port/KEENMAIN.C:182` | K1–3 | A sprite just below the bottom edge of the screen (rows 200–207) is still prepared for drawing. | not-a-bug | It is off-screen anyway: wasted work only. |
| V19 | `KEENMAIN.C:303`, `:323` / `port/KEENMAIN.C:321`, `:341` | K1–3 | When the game draws a moving tile (a door sinking open, the exit door Keen walks through), it works out how much screen to redraw next frame from the size of *the last sprite drawn*, not from the tile. | not-a-bug (provisional) | Most sprites are at least a tile in size, so the area is usually big enough. If the last sprite was smaller, a sliver of the door could be left behind for a frame. Not seen yet; needs a replay look. The port mirrors it (`RF_PlaceTile`, `vort_main.gd:536`). |
| V20 | `KEENMAIN.C:379` / `port/KEENMAIN.C:397` | K1–3 | Level files over 32 KB would load wrongly. | not-a-bug | The largest shipped level is 11 KB (`LEVEL15.CK3`). Mods only. |
| V21 | `KEENMAIN.C:533` / `port/KEENMAIN.C:581` | K1–3 | A file-writing routine never writes its last 16 bytes. | not-a-bug | The routine is never called. |
| V22 | `KEENMAIN.C:1212` / `port/KEENMAIN.C:1386` | K1–3 | Toggling God mode (G+O+D) shows a message and waits for a key, but doesn't reset the game clock. The next frame runs as if a lot of time had passed (capped at 15 tics), so Keen and the creatures lurch forward at once. | **fix** | After the message, restart the frame clock (as the F-key windows already do). Read in `HandleUserKeys` (`vort_main.gd:877`). Only reachable through the cheat. |
| V23 | `KEENMAIN.C:1269` / `port/KEENMAIN.C:1443` | K1–3 v1.34 | On a fatal error, v1.34 forgets to exit to DOS. | not-a-bug | v1.34 only, and DOS-only. |
| V24 | `KEENMAIN.C:1409` / `port/KEENMAIN.C:1591` | K1–3 | The "no EGA/VGA card, run anyway (Y/N)?" prompt reads the keyboard before the keyboard handler is started. | not-a-bug | DOS hardware check. The port has no such prompt. |
| V25 | `KEENSCRN.C:1380` / `port/KEENSCRN.C:2049` | K2 | On the ordering-info screen, the view is nudged up 4 pixels after the sprite origin was computed, so sprites would sit 4 pixels off. | not-a-bug | That screen draws no sprites, only text. |

#### Not counted by the grep: the reconstruction's `BUG?` notes

The reconstruction also marks doubtful spots with `BUG?`. `grep "BUG:"` doesn't match these, so they
are outside the seed count. They are listed here so they aren't lost; none is proposed for the
first batch.

| Source | Game | What | Verdict |
|---|---|---|---|
| `KEENACTS.C:844`, `:853` | K1–3 | When one object pushes another, an over-limit push sets the up/down move instead of the left/right one. | not-a-bug: the limit can never be exceeded in that direction, so the line never runs. |
| `KEEN3ACT.C:1197` | K3 | A Meep that reaches a ledge sings, then carries on in the same direction instead of turning round. | not-a-bug (provisional): possibly why Meeps walk off ledges; needs a replay look. |
| `KEENDEMO.C:1085`, `:1133` | K1 | Two ship-flight paths in the cutscenes stop a few steps early, because a step whose x and y add up to 0 is taken as the end marker. | keep: part of the cutscenes as everyone has seen them. |
| `KEENSCRN.C:1663` | K1–3 | Keen's walking speed on the world map doesn't depend on the frame rate. | not-a-bug: the port runs the original timing. |
| `KEENSCRN.C:1846`, `:1853` | K3 | The world-map teleporter loop reuses its counter and could use negative table indices. | not-a-bug: the shipped teleporter data is valid. |
| `IDLIBC.C:1673`, `:1676`, `:1680` | K1–3 | File-open results aren't checked when unpacking graphics. | not-a-bug: DOS file handling, replaced in the port. |

---

## Part B — Keen 4–6 (`omnispeak/src`)

Method: the comments were searched for `bug`, `glitch`, `vanilla`, `original`, `quirk`,
`workaround`, `hack`, `emulat`, `disasm`, `mistake`, `should be/have`, `keenwiki` and similar
words. Each hit was read together with its code. Note that this omnispeak tree is the project's own
modified copy (the wide view, the compositor, verification hooks). Many hits are about those
changes or use "vanilla" simply to mean "the original screen/build"; they are listed at the end of
this part as screened out.

The Galaxy port (`godot/games/galaxy/`) keeps omnispeak's function names; the Keen-control code
is in `gal_play.gd`. Three omnispeak quirks already have config switches that the port carries:
`impossibleBullet`, `ck_poleDoorGlitch` and `ck_fixPlatformZLayer`. A toggle can drive those
directly.

| ID | Source | Game | What happens, in plain words | Verdict | Reason / the fix |
|---|---|---|---|---|---|
| G01 | `ck4_obj1.c:487` | K4 | The Skypest's touch handler has no "else" between "touched Keen" and "touched a shot". | not-a-bug | The note itself says there is no change in behaviour. |
| G02 | `ck5_map.c:238` | K5 | The original's map teleport/elevator loop calls a routine that doesn't refresh Keen's hit box; omnispeak substitutes one that does. | not-a-bug | Implementation detail of the source port. |
| G03 | `ck5_map.c:333` | K5 | The elevator code on the Keen 5 map "should have" set one more field on Keen. | not-a-bug | No player-visible consequence found: the field is reset when the ride ends. |
| G04 | `ck5_obj1.c:152`, `:162` | K5 | A Volte-face placed with no track next to it would get a garbage direction (omnispeak quits with an error instead). | not-a-bug | Shipped maps place them correctly. |
| G05 | `ck_game.c:661` | K4–6 | The original skips loading some "Keen counting down" pictures when memory is low. | not-a-bug | DOS memory detail. |
| G06 | `ck_inter.c:1135` | K4–6 | Omnispeak clears both screen pages after the title, unlike the original. | not-a-bug | Source-port detail. |
| G07 | `ck_keen.c:188` (also `:123`, `:186`; port `gal_play.gd:1840–1883`) | K6 (optional in K4/5) | **The "impossible bullet":** when Keen touches his own stunner shot, the game falls into the platform code and Keen can land and stand on his own shot. | **keep** | A famous Keen 6 glitch and speedrun trick. It already has a switch (`impossibleBullet`), so a later "Impossible bullet in Keen 4/5" toggle would be possible. |
| G08 | `ck_keen.c:637` | K4–6 | With the DOS `/NOPAN` option, Keen's position on a Bounder is rounded to 8 pixels, so you sometimes can't walk off a Bounder. | not-a-bug | Happens only with `/NOPAN`, which the port doesn't have. |
| G09 | `ck_keen.c:738–739` | K4–6 | Pressing Jump and Pogo in the same instant starts a jump and immediately turns it into a pogo with the jump's set-up still in place. Omnispeak's authors wonder whether this is the "impossible pogo"; a disassembly has a `return` here that would prevent it. | **keep** | Likely speedrun-relevant and part of how the controls feel. The exact effect is unconfirmed, so it should not be "fixed" on a guess. |
| G10 | `ck_keen.c:1124–1137` | K4–6 | Ledge grabbing gets unreliable above 35 frames per second; omnispeak adds K1n9_Duk3's fix. | not-a-bug | The original never runs that fast, and neither does the port's simulation ("smooth motion" only blends frames for display). |
| G11 | `ck_keen.c:1546` (port `gal_play.gd:2900`) | K4, K5 | **"Pole foreground bug":** if a moving platform interrupts Keen while he is pulling himself up onto a ledge, he stays drawn *in front of* the foreground (poles, pillars, scenery) instead of behind it, until something resets his drawing layer (e.g. another ledge climb). Keen 6 fixed this. | **fix** | Do what Keen 6 does: put Keen back on his normal layer when a platform interrupts him. Read in `CK_KeenSpecialColFunc` (`gal_play.gd:2894`), where `ck_fixPlatformZLayer` is already checked. |
| G12 | `ck_keen.c:1587–1595` (port `gal_play.gd:2932`) | K4–6 | **Pole/door trick:** if a Bounder (K4), Ampton/Korath (K5) or Gik/Flect/Blooglet (K6) knocks Keen off a pole and he enters a door before touching the ground, he walks "down" into the door and its destination is read from the wrong place. That usually ends the level, and in Keen 5 it can reach the secret level. | **keep** | A well-known exploit (KeenWiki: *Ampton Pole Push Door Trick*, *Shelley/Door Trick*, *Bounder Pole Door Glitch*) used in speedruns. It already has a switch (`ck_poleDoorGlitch`). |
| G13 | `ck_keen.c:1870–1871` | K4–6 | Note on the code that stops Keen climbing down a pole through the floor. | not-a-bug | It describes the guard, not a bug. |
| G14 | `ck_map.c:278` | K4–6 | The original stores map-Keen frame numbers off by one and adds 1 later. | not-a-bug | Data layout only. |
| G15 | `ck_map.c:455` | K4, K6 | Timing note on how the original paces the map-teleport animation. | not-a-bug | Source-port detail. |
| G16 | `ck_map.c:515` | K4, K6 | The original masks the teleport destination row to 7 bits (0x7F); omnispeak uses 8 bits. | not-a-bug | No map is 128 tiles tall, so both give the same row. |
| G17 | `ck_misc.c:406` (port `gal_act.gd:1597`) | K5 mines/Shelley bits, K6 Babobba shots | Bouncing debris looks up its bounce in an 8×8 table using a tile value that isn't limited to 0–7, so an odd floor tile would send it bouncing off at random. Omnispeak (and the port) mask the value. | not-a-bug | No player complaint is known. **Fidelity note:** the port applies omnispeak's mask even in Classic mode; whether any shipped tile has a value above 7 is unchecked. |
| G18 | `ck_misc.c:520` | K5 | The original doesn't check for a missing "next step" when debris stops; omnispeak emulates what DOS does. | not-a-bug | Emulation detail. |
| G19 | `ck_play.c:497`, `:504`, `:638` | K4–6 | An object with no current action (reachable with the no-clip cheat) makes the original read whatever sits at memory address 0. Omnispeak emulates the bytes found there. | not-a-bug | Cheat-only, and emulated faithfully. No crash in DOS. |
| G20 | `ck_play.c:690–691` | K4–6 | The F10 wall-debug overlay can draw a tile with no graphic; omnispeak uses a DOSBox memory dump as the stand-in. | not-a-bug | Debug keys only. |
| G21 | `ck_play.c:1374` | K4–6 | With two-button firing, a short delay is added before a pogo counts, to imitate the earlier games' controls. | not-a-bug | Controls emulation, not a bug. |
| G22 | `ck_play.c:1429` | K4 | Omnispeak hints that the original picks the Council-rescue music from memory past the end of its music list (landing on the Fire-key setting). Omnispeak always plays the intended tune (`ck4_specialMusic` = `WONDER_MUS`). | not-a-bug (provisional) | Whether v1.4 really does this, and what you hear in DOS, is unverified. Worth one DOSBox check (judgment note). |
| G23 | `ck_play.c:2342` | K4 | Omnispeak skips some Keen-4-only code in the collision loop ("strange Keen4 stuff"). | not-a-bug | It isn't known to be a bug of the original. It is a gap in omnispeak. If the Keen 4 replays agree, nothing to do. |
| G24 | `id_ca.c:1536` | K4 (level 10) | If an object goes through the top of the map, the original reads tile data from outside the map and the object reacts to whatever it finds. Omnispeak imitates this with a made-up formula ("not reproduced in the exact same manner"). | not-a-bug (provisional) | What the player sees is unknown. Classic parity there is only approximate (judgment note). |
| G25 | `id_rf.c:533` | K4–6 | A variable is used before it is set when tile sounds are marked. | not-a-bug | The note says it has no effect in practice. |
| G26 | `id_rf.c:860` | K4–6 | The original only updates animated tiles in the map inside its 21-tile screen buffer; tiles further away don't change. | not-a-bug | A note on original behaviour that the port keeps for simulation fidelity. Off-screen, so invisible. |
| G27 | `id_rf.c:965` | K6 (Guard Post 3) | Some levels use background tiles that have no graphic. | not-a-bug | Those tiles are hidden anyway. |
| G28 | `id_sd.c:59` (the same note is in `id_sd_dos.c:34`, `id_sd_liboplhw.c:42`, `id_sd_null.c:30`, `id_sd_opl2.c:43`, `id_sd_opl2alsa.c:37`, `id_sd_opl2lpt.c:41`, `id_sd_sdl.c:67`, `id_sd_sdl3.c:55`) | K4–6 | The original programs its sound timer with a slightly wrong constant, so the sound rate is a hair off 140/560 Hz. | not-a-bug | The port matches the original timing on purpose. |

**Screened out (read; not bug notes of the original game):**
- `#ifdef CK_VANILLA` build switches: `ck_config.h:78`, `:80`; `ck_play.c:1216`; `id_ca.c:258`;
  `id_in.c:439`; `id_in_sdl.c:443`; `id_in_sdl3.c:305`; `id_us.h:111`; `id_us_1.c:404`, `:451`,
  `:877`; `id_us_2.c:97`, `:108`, `:124`, `:138`, `:191`, `:235`, `:352`, `:604`, `:649`, `:675`,
  `:727`, `:738`, `:1112`, `:1176`, `:1225`.
- The project's wide-view and compositor notes ("vanilla" = the original 320-pixel view): `ck_map.c:79`,
  `:91`, `:261`, `:359`; `ck_play.c:2219`; `id_rf.c:62`, `:63`, `:86`, `:104`, `:181`, `:310`, `:397`,
  `:866–868`, `:1482`; `id_rf.h:49`, `:50`, `:53`, `:54`, `:63`, `:78`; `id_vl.c:976`, `:1017`, `:1038`;
  `id_vl.h:163`, `:165`, `:179`.
- Other source-port remarks: `ck5_map.c:286`; `ck_def.h:246`, `:258`; `ck_game.c:948`;
  `ck_inter.c:272`, `:923`, `:1265`; `ck_keen.c:755`; `ck_phys.c:471`; `ck_play.c:850`, `:1975`, `:2031`;
  `ck_us_2.c:1100`, `:1660` (Paddle War sprite shift); `ck_verify.c:6`; `id_ca.c:980`; `id_fs.h:75`;
  `id_in.c:110`, `:663`; `id_us_1.c:764`, `:774`; `id_vh.c:232`; `id_vl.c:52`, `:70`, `:124`;
  `id_vl.h:38`, `:55`, `:56`; `id_vl_sdl2vk.c:21`, `:450`; `ck_main.c:513` (crash-hunt handler).

---

## Part C — Keen Dreams (`refkeen/src/kdreams`)

Method: the same word search, plus the source port's own list in `REFKEEN-NOTES.txt` (lines
89–200: "Bug fixes with no practical impacts" and "Bug fixes which might have impacts"). Where a
code comment and a NOTES entry describe the same thing, they share one row.

The Dreams port (`godot/games/dreams/`) keeps refkeen's function names; play logic is in
`drm_game.gd`, actor code in `drm_acts.gd`.

| ID | Source | What happens, in plain words | Verdict | Reason / the fix |
|---|---|---|---|---|
| D01 | `kd_demo.c:80` (port note `drm_game.gd:270`) | Starting a new game doesn't reset Keen's keys. If you abandon a game while holding keys, the next game starts with them. (Losing a life does clear keys, so a normal Game Over leaves none.) The 2015 re-release fixed this. | **fix** | Zero the keys in `NewGame` (`drm_game.gd:261`), as the 2015 release does. |
| D02 | `kd_play.c:1720–1745`; `REFKEEN-NOTES.txt:186` | The "You didn't make it past… Try Again / Exit to Tuberia" box reacts to the *last key pressed*, which it never clears. If that was Space (e.g. closing the status window) and you then play without touching the keyboard (gamepad, joystick, mouse), the box skips itself on death and restarts the level. If the last key was Esc, it exits to the map without asking. | **fix** | Clear the last key before the box opens (refkeen does a version of this for its extra controls; the port doesn't yet). Read in `HandleDeath` (`drm_game.gd:2095`). Likely to hit gamepad players. |
| D03 | `kd_play.c:987`, `:1006` | Two wall-check loops compare numbers the "unsigned" way, which changes how pieces of King Boobus Tuber's explosion collide when they fly above the map. | not-a-bug | No effect on play: it only shapes the boss's death explosion as everyone has seen it. The port keeps it. |
| D04 | `kd_act1.c:238`; `kd_play.c:1354`, `:1375`, `:1382`, `:1485`; `REFKEEN-NOTES.txt:134–158` (incl. `ClipToWalls`); port `drm_acts.gd:1606` | If you load a game saved while a flower is turning back into a creature, that object can come back with no behaviour at all. The original then reads stray bytes and the object most likely sits frozen for about two minutes before doing anything. | **fix** (provisional) | A genuine save/load defect, but the exact look is unconfirmed. Fix idea: when loading, finish the "poof" (turn the flower straight back into its creature). Read in `ChangeState` (`drm_acts.gd:1603`) / `LoadGame` (`drm_game.gd`). Confirm with a replay first; not in the first batch. |
| D05 | `id_ca.c:585`, `id_mm.c:441` | While loading picture tables, the original unpacks more entries than the table holds. | not-a-bug | It overwrites unused memory in DOS; no visible effect. |
| D06 | `id_rf_a.c:92`, `:108`, `:224`, `:248`, `:253` (port `drm_rf.gd:205`) | A map uses an "empty" tile with no graphic, and the original draws it from memory address 0. The port does the same. | not-a-bug (provisional) | Which level and whether it shows is not identified. It draws as DOS does. |
| D07 | `id_us.c:548`; `REFKEEN-NOTES.txt:175` | Command-line parsing can read past the end of a parameter. | not-a-bug | DOS launcher only. |
| D08 | `id_us.c:841`, `:986`; `REFKEEN-NOTES.txt:105–132` | Text printing briefly edits the string it prints; character codes may be read as signed. | not-a-bug | Source-port safety changes; same output. |
| D09 | `id_us.c:2449`, `:2481` | v1.00's joystick calibration runs only once and accepts a calibration that didn't move. | not-a-bug | DOS joystick calibration; the port uses modern gamepads. |
| D10 | `id_us.c:3832`; `REFKEEN-NOTES.txt:110–122` | Some control-panel and high-score variables start uninitialised. | not-a-bug | The NOTES show each is always set before use. |
| D11 | `id_in.c:691`, `:729`; `REFKEEN-NOTES.txt:92–99` | Input routines read some variables before setting them. | not-a-bug | No effect (values are overwritten at once; no demo playback in Dreams). |
| D12 | `id_vw_ae.c:1247`; `REFKEEN-NOTES.txt:181` | Refkeen waits for the screen refresh in a slightly different order from the original. | not-a-bug | Source-port detail. |
| D13 | `REFKEEN-NOTES.txt:101` | Memory release could follow a null pointer. | not-a-bug | DOS memory manager; the port's is different. |
| D14 | `REFKEEN-NOTES.txt:163–173` | Sound/music mode setters can return an unset value when there is no AdLib. | not-a-bug | DOS hardware detection. |
| D15 | `REFKEEN-NOTES.txt:177` | A control-panel button routine can return an unset value when the player quits. | not-a-bug | The note says it doesn't matter in the original. |
| D16 | `REFKEEN-NOTES.txt:198` | Loading a file could open it twice without closing it. | not-a-bug | DOS file handles. |
| D17 | `kd_play.c:293` | Patch for the 2015 port when switching CGA/EGA graphics. | not-a-bug | 2015-release feature, not a DOS bug. |
| D18 | `kd_main.c:508`, `:715` | Version differences (a no-op call in v1.05, the shareware `START`/`/DETOUR` check). | not-a-bug | Launcher/version notes. |
| D19 | `id_ca.c:1579` | Refkeen quits if asked for a map that doesn't exist. | not-a-bug | Safety check added by the source port. |
| D20 | `kl_compositor.c:472` | The project's wide view showed the out-of-bounds border ring. | not-a-bug | A bug of this project's wide view (already handled), not of the game. |
| D21 | `id_heads.h:88` | A type must be unsigned for the high-score table to measure text right. | not-a-bug | Compiler-type note. |

**Screened out (read; not bug notes of the original game):** `altcontroller.c:450`, `:593`;
`gelib.c:181`; `id_ca.c:590`, `:694`, `:715`, `:755`, `:1912`; `id_in.c:855`; `id_mm.c:652`;
`id_rf.c:788`, `:1477`, `:2185`; `id_rf_a.c:428`; `id_sd.c:111`, `:211`, `:779`, `:868`, `:889`,
`:967`, `:1254`, `:1263`, `:1609`, `:2000`; `id_sd.h:220`; `id_us.c:88`, `:951`, `:2877`, `:3273`,
`:3338`; `id_vw.c:126`, `:744`; `id_vw.h:117`, `:291`; `id_vw_ac.c:43`, `:142`, `:145`, `:480`;
`id_vw_ae.c:415`, `:1045`, `:1456`; `kd_def.h:30`, `:83`, `:136`; `kd_demo.c:326`, `:987`;
`kd_keen.c:1743`; `kd_main.c:412`; `kl_compositor.c:66`, `:209`, `:411`, `:456`; `kl_compositor.h:4`,
`:9`; `kl_quicksave.c:123`; `lzhuf.c:161`; `soft.c:476`.

---

## Summary

Counts are rows (one row = one bug). The Vorticons figures in brackets are `BUG:` annotations.

| Engine | fix | keep | not-a-bug | Rows |
|---|---|---|---|---|
| Vorticons (Keen 1–3) | 6 [6] | 0 [0] | 19 [22] (2 provisional) | 25 [28] |
| Galaxy (Keen 4–6, omnispeak) | 1 | 3 | 24 (2 provisional) | 28 |
| Dreams (refkeen) | 3 (1 provisional) | 0 | 18 (1 provisional) | 21 |
| **Total** | **10** | **3** | **61** | **74** |

Keen 1–3 coverage against the grep:

| | Lines |
|---|---|
| `BUG:` annotations in `keen13/reconstruction` covered | 28 of 28 |
| Their word-for-word copies in `keen13/port` covered | 28 of 28 |
| False matches (`DEBUG:` in `keen13/port/build` CMake files) accounted for | 7 of 7 |
| **Total = `grep -rn "BUG:" keen13`** | **63 = 63** |

## Proposed first batch (for approval)

These are the clearest, most visible fixes, and each switches cleanly. Row titles are written to
fit the Fixes list ("Impossible pogo bounce" style), with the description line shown under the
selected row.

| # | Row title | Description line | Game | From |
|---|---|---|---|---|
| 1 | Chain drop after Commander | Shooting the chain no longer hangs the game when the Commander is already dead. | K1 | V04 |
| 2 | Esc skips Earth scenes | Esc skips the Earth-explodes and flight-home scenes, as the game intended. | K2 | V05, V06 |
| 3 | Tantalus double fade | The "Oops." screen no longer flashes back before the Earth explodes. | K2 | V12 |
| 4 | Messie double Keen | No frame showing Keen on Messie and on the shore at once. | K3 | V13 |
| 5 | God mode lurch | Toggling God mode no longer makes everything jump forward. | K1–3 | V22 |
| 6 | Keen over scenery | A platform cutting short a ledge climb no longer leaves Keen drawn in front of the scenery. | K4, K5 | G11 |
| 7 | Keys kept from last game | A new game starts with no keys. | Dreams | D01 |
| 8 | Death box skipped | The "Try Again / Exit to Tuberia" box always waits for your choice. | Dreams | D02 |

Kept as they are (no fix row now; a later opt-in toggle is possible): the impossible bullet (G07),
the jump+pogo "impossible pogo" (G09) and the pole/door trick (G12).

## Needs your judgment

1. **The Keen 1 chain case in the port today (V04).** The original searches past the start of the
   creature list and hangs or corrupts memory. The port's `ChainContact` (`vort_keen1.gd:593–602`)
   stops the search at slot 0, which is **Keen himself**. So in this situation the port turns Keen
   into a dying Vorticon (death sprite, no contact, `DyingThink`). That matches neither the
   original nor a sensible fix. Classic mode can't reproduce a memory-corrupting hang sensibly, so a
   decision is needed: in Classic, either apply the fix too (a documented divergence) or freeze the
   way DOS does.
2. **"Impossible pogo".** `BLUEPRINT.md:75` (J-03) names the *Vorticons* "impossible pogo" as an
   example of a bug to fix. The FIX-03 brief treats the impossible pogo as a keep-as-feature trick.
   Neither the Keen 1–3 `BUG:` notes nor omnispeak describe a Vorticons impossible pogo; the only
   "impossible pogo" note is the Galaxy one (G09, kept). Should a Vorticons row be added, and as fix
   or keep?
3. **Omnispeak's shrapnel mask (G17)** is always on in the port, including Classic. If any shipped
   Keen 5/6 tile has a top value above 7, Classic differs from DOS there. One scan of the tile info
   would settle it.
4. **Unverified original behaviour.** Keen 4 Council music (G22) and Keen 4 level 10's off-map read
   (G24, where omnispeak's imitation is approximate) are worth a DOSBox look before Classic parity
   is claimed for them.
5. **Provisional items that need a short replay:** Vorticon Mother at ledges (V08), door-tile
   redraw (V19), Keen 3 Meep at ledges (`BUG?`, `KEEN3ACT.C:1197`), the Keen Dreams flower after
   loading (D04) and the Dreams empty tile (D06). Any of these could move to **fix** once seen.
6. **God mode lurch (#5)** is reachable only through the G+O+D cheat. If Megarocket's Cheats menu
   toggles God mode without the original message window, the fix may be moot. Keep it or drop it?
7. **Toggles that already exist.** The Galaxy port already carries `impossibleBullet`,
   `ck_poleDoorGlitch` and `ck_fixPlatformZLayer` as config switches. FIX-01 can map rows onto
   them rather than adding new checks.

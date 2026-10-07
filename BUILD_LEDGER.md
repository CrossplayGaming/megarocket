# Megarocket 2.0 — Build Ledger
schema: 1
Generated 2026-10-06 · Derived from: docs/BLUEPRINT.md · Status: in-progress

`built` and `verified` are different. A unit with no passing check is not done.
A unit with no runnable check is not ready to build; it needs a harness ahead of it.

## Pre-ledger boundary

Nothing in this folder is pre-ledger *code*: the Godot project does not exist yet. The folders
`keen13/`, `omnispeak/`, `omnispeak-ref/`, `refkeen/`, `keendreams/`, `keen6/`, `keen6patch/` are
reference material copied from Megarocket, not components. Their own harnesses (`keen13/verify`,
`keendreams/verify`) are read for cases and ideas; nothing they verified counts as verified here.

## Architecture commitments

Locked once feature work begins. These are the Duke Nukem II recreation's commitments, carried
over because they were what made that port provable, with the changes seven games and Android
require (A9, A10, A14, A15).

| # | Commitment | What it buys |
|---|---|---|
| A1 | Each simulation advances only in whole original frames, one call per frame, at a fixed rate chosen by the shell: the Vorticons engine's vblank-locked tic, Galaxy's and Dreams' 70 Hz tic clock with the originals' tic-count catch-up rule reproduced. | Replays, comparison against the original, speed independent of machine. |
| A2 | Simulation arithmetic is whole-number only, through explicit 8-bit, 16-bit and 32-bit helpers that wrap as Borland C did; Galaxy's 16.16 fixed point reproduced as integers. No decimals in any simulation. | No drift. Overflow behaves as in the original. |
| A3 | No simulation touches the engine. Each draws the way its original did, into one emulated EGA card (registers, four planes, latches, panning, palette, page flipping) shared by all three engines. The picture is read back from that card. The same drawing calls also emit a draw list (what image, where, in what order) for the modern renderer. | Headless runs; pictures identical by construction; one renderer for seven games; native resolution is a redraw of the list. |
| A4 | Player input enters each simulation as the original's own per-frame control structure. Galaxy and Dreams sessions are recorded in the originals' demo formats; Vorticons in a port-own format of the same shape. Menu and hot-key input is recorded alongside. | Every session is replayable; Galaxy/Dreams demo files written here play in the originals. |
| A5 | Randomness is each original's table and index, held in simulation state. | Identical random sequences. |
| A6 | A hash of the complete simulation state is available after any frame, for every engine. | Determinism checks name the frame where two runs part. |
| A7 | The complete simulation state — including the map planes and the card — can be stored and restored. | Round-trip tests; quicksave anywhere in all seven games. |
| A8 | No wall-clock time, frame time or display size inside a simulation, except the view width in tiles, which is the original's in Classic. Actor activation reads the view width (the user's widescreen decision) through one named function per engine. | Widescreen is one number and one function; parity is claimed at the original width. |
| A9 | Shell and games are separate. The shell owns window, settings, input mapping, touch overlay, audio output, drawing, file locations, game detection and import. Each engine is a module behind one interface; each game is that engine plus an episode table. | One launcher, one options system, one touch layer for seven games. |
| A10 | Each engine's code is one class built up over a few scripts, each extending the one before, in the reference source's order, every function carrying the reference's name. The reference for Keen 1–3 is the reconstruction; for Keen 4–6 omnispeak (upstream, not the Megarocket fork); for Dreams the released original source. | A reader can check any function against its reference line by line. |
| A11 | Blocking sequences in the originals (menus, fades, waits, `IN_Ack`) are coroutines that wait on simulation frames. | Flow code stays comparable to the reference. |
| A12 | Original game files are read at run time from storage the user supplies or the app imports into. Nothing derived from them is ever written into the repository or a build. omnispeak's own metadata files are engine-own and may be bundled. | The legal line. |
| A13 | Each engine's working memory is one block with the original's allocator; a pointer is an offset into it. | Reads past the end of one allocation land where they did in the original. |
| A14 | The only native code is the OPL emulator (`d2opl`, GPL, carried from Duke), built for Windows, Linux and Android arm64/x86_64 from one CMake file. Everything else is GDScript, so the Android build is an export, not a port. | Android parity is structural, not a later effort. |
| A15 | Every added option is a shell setting, read by the shell, never by a simulation, except the widescreen activation width (A8). | The fidelity line is enforceable by grep. |
| A16 | **Controller-complete from the first screen (user, 2026-10-06).** Every function of the shell and of every game — every menu item, prompt, hot-key action, text field, cheat, option, save and load — is reachable and operable with a gamepad alone, and the path walker (HARN-09) proves it in pad-only mode. No screen-bearing unit is `verified` until that pass is in its evidence; a screen that needs a key the pad cannot produce is a failing check, not a note for later. Keyboard-only and touch-only get the same rule. | Megarocket retrofitted this late and never fully got there. Here it is a gate on every unit, not an audit at the end. |

## Harness registry

| ID | Name | Covers | Run | Cannot catch |
|---|---|---|---|---|
| HARN-01 | Oracle runner. Runs an original executable in DOSBox Staging on a scratch copy of its game, with fixed hermetic settings (normal core, fixed cycles, no sound device, no host keys bound to game keys, MIDI off), records lossless video, extracts the sequence of distinct frames. One profile per engine. | Source of truth for every `oracle` unit. | `python tools/oracle_run.py <game> <case>` | Anything the recording's frame rate cannot see (one-refresh flashes); the two Elgato/MIDI traps from the Duke project are configured out, not caught. |
| HARN-02 | Demo author. Writes Galaxy and Dreams demo files from input scripts or recordings, placing them so the original plays them; for Vorticons writes a timed-key script that DOSBox types (AUTOTYPE plus posted held keys). | Lets the oracle play any level with any inputs. | `python tools/make_demo.py <game>` | Galaxy demos carry movement and buttons only (no menus); Vorticons timed keys are not frame-exact, so its comparisons are by distinct-frame sequence. |
| HARN-03 | Port runner. Runs the port without a window on a recording; writes each frame's 320×200 picture, state hash and sound-event log. | Port side of every comparison, all engines. | `godot --headless --script tools/run_demo.gd -- <game> <case>` | The on-screen GPU drawing path (a different renderer). |
| HARN-04 | Frame comparator. Every finished game frame the port produces must appear in the original's recording, in order; reports the first failure with frame numbers and a difference picture. | All `oracle replay` rows. | `python tools/compare_frames.py <port frames> <oracle run>` | A frame both sides get wrong the same way. |
| HARN-05 | Determinism and round-trip. Same inputs twice; store and restore mid-run; compares hashes per frame; also runs with each display option toggled. | Determinism, snapshot, "display options do not affect simulation". | `godot --headless --script tools/determinism.gd -- <game>` | Errors that are deterministic. |
| HARN-06 | Still-screen capture. Drives the original to a named screen and grabs it; the port renders the same screen. | Menus, text screens, loading, ending, help pages. | `python tools/oracle_still.py <game> <screen>` | Animation timing within a screen. |
| HARN-07 | Sound log comparator. DOSBox records the original's OPL writes and speaker-port writes; the port logs its own. | Music, AdLib effects, PC-speaker effects. | `python tools/compare_audio.py <game> <case>` | How the emulated chips actually sound. |
| HARN-08 | Bad-data corpus. Missing, empty, truncated, corrupt and unknown-value versions of every file kind of every game, placed through the mods folder. | Loader error paths. | `godot --headless --script tools/fixtures.gd` | Kinds of damage not in the corpus. |
| HARN-09 | Path walker. Drives the whole program — launcher, every game's menus, in-game screens, options, save/load, text entry — by scripted and random keys and pad buttons, including back-out, mashing and input during fades; asserts it always gets back to the launcher. | Menu soft-locks, stale state, pad-only reachability, Android back handling. | `godot --headless --script tools/menu_walk.gd` | Whether a screen looks right. |
| HARN-10 | Input generator. Random and scripted input streams per level, plus recordings of real play. | Breadth of oracle replay coverage. | `python tools/gen_inputs.py <game>` | Parts of a level random input never reaches. Recordings close this. |
| HARN-11 | Layout bounds. Fails if any HUD, menu or touch-overlay element leaves the screen or overlaps, at each supported aspect and at phone sizes. | Added display modes, touch layouts. | `godot --headless --script tools/bounds.gd` | Taste. |
| HARN-12 | Clean-tree check. Fails if any original game file, or anything derived from one, is tracked or present in a build (both platforms). | Distribution. | `python tools/check_clean.py` | Re-encoded data (a table retyped as numbers). |
| HARN-13 | Detection fixtures. Fake Steam library trees, GOG registry exports, loose folders, ZIPs, Android import trees, every version and wrong version. | Launcher detection and import. | `godot --headless --script tools/detect_test.gd` | A real Steam layout the fixtures do not model. |
| HARN-14 | Session comparison. The whole program driven by keys at set times in the original (DOSBox types them) and the port; recordings compared by held pictures. | Menus and flow where no demo format reaches. | `python tools/session.py <game> <case>` | Frame-exact timing. |
| HARN-15 | Export check. Builds the Windows executable and the Android APK headless; a parity list of features is asserted present in both (same scripts, same settings keys, same version string); the APK installs and boots on the emulator to the launcher screen. | Android parity, release readiness. | `python tools/build_release.py --check` | How it feels on a real phone. |
| HARN-16 | Save-format round trip through the original. The port writes a save; DOSBox loads it in the original and a still is captured; the original's save is loaded by the port. | Original save-file compatibility. | `python tools/save_roundtrip.py <game>` | Save contents the still cannot show. |

## Units

Grouped by system, dependency order. Harness units come first and produce nothing playable.
IDs are never renumbered. Where one check covers all seven games, the unit is one row with the
game named in the evidence; where behaviour differs per engine, there is a row per engine
(V = Vorticons 1–3, G = Galaxy 4–6, D = Dreams).

### HARN — verification tools (nothing playable comes out of this group)

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| HARN-01a | DOSBox runs each original unattended with hermetic settings to a scripted end and leaves a lossless recording; two runs of the same case give the same recorded length and the same ordered sequence of held pictures. | spec | Run twice per engine, compare | | ready | | | Game loop |
| HARN-02a | A Galaxy demo file written by the tool from the original's own demo bytes is byte-identical; the original plays an authored demo and the recording shows the chosen level and inputs. | spec | Byte compare; oracle run | HARN-01a | blocked | | | Input |
| HARN-02b | A Dreams demo written by the tool plays in the original the same way. | spec | As above | HARN-01a | blocked | | | Input |
| HARN-02c | A Vorticons timed-key script typed into DOSBox produces a run whose distinct-frame sequence is reproducible across two runs. | spec | Run twice, compare | HARN-01a | blocked | | | Input |
| HARN-03a | The port's frame writer produces a frame store the comparator reads back pixel for pixel, with level starts and picture kinds intact; a store with one pixel changed has a different digest for that frame only. | spec | Round trip of a generated pattern, written by Godot and read by Python | | verified | `python tools/regress.py HARN-03a` PASS 2026-10-06: 12 written pictures read back as 9 entries identical to the pattern; planted pixel found in that picture only | 1 | Game loop |
| HARN-04a | The comparator reports zero differences for a sequence against itself and names the exact frame when one pixel is altered. | spec | Self-test with planted fault | HARN-01a | blocked | | | Game loop |
| HARN-05a | The determinism harness reports the frame of divergence when a random draw is deliberately skipped, in each engine. | spec | Self-test with planted fault | SIM-V-01, SIM-G-01, SIM-D-01 | blocked | | | Game loop |
| HARN-06a | A still capture of each original's main menu is reproducible across two runs. | spec | Run twice, compare | HARN-01a | blocked | | | Menus |
| HARN-07a | DOSBox OPL capture of a Galaxy song decodes to the song's writes in order; speaker-port capture of a Vorticons effect decodes to its frequency sequence; the comparator flags one altered write. | spec | Self-test with planted fault | HARN-01a | blocked | | | Audio |
| HARN-08a | Every file kind of every game damaged seven ways is either survived or refused with a message; the harness reports a loader that waits for ever or trips a script. | spec | Self-test with a planted silent-skip loader | DATA-01 | blocked | | | Boot |
| HARN-09a | The path walker reports a soft-lock when a back-out is deliberately disabled, reports a screen a pad alone cannot leave, and reports a function (a planted keyboard-only hot-key) a pad alone cannot trigger. It enumerates functions from the engines' own tables, so a new screen cannot be added without the walker seeing it. | spec | Self-test with three planted faults | SHELL-02 | blocked | | | Menus (A16) |
| HARN-10a | Input generator writes random and scripted streams the demo tools accept, reproducibly from a seed. | spec | Self-test | HARN-02a | blocked | | | Input |
| HARN-11a | Bounds check fails on an element deliberately placed off-screen at a phone aspect. | spec | Self-test with planted fault | SHELL-01 | blocked | | | HUD |
| HARN-12a | Clean-tree check fails when a game file is staged under another name or embedded in an APK. | spec | Self-test with planted fault | | ready | | | Distribution |
| HARN-13a | Detection fixtures reproduce a Steam library across two drives, a GOG install, a loose folder with three games, and an Android import tree; the detector names every version in each, and a planted wrong version is named as wrong. | spec | Self-test | | ready | | | Launcher |
| HARN-14a | Session comparison of the original's title loop against itself passes; against a run with one key one second late, fails naming the screen. | spec | Self-test | HARN-01a | blocked | | | Menus |
| HARN-15a | Headless export produces a Windows build and an APK; the APK boots on the emulator to the launcher; a feature deliberately removed from the Android export is named by the parity list. | spec | Self-test with planted gap | SHELL-01, NATIVE-01 | blocked | | | Distribution |
| HARN-16a | A save written by the port for each game loads in the original; a planted wrong byte is refused by the original. | spec | Self-test | HARN-06a, SAVE-01 | blocked | | | Save |

### NATIVE — the one native library

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| NATIVE-01 | `d2opl` builds for Windows x86_64, Linux x86_64 and Android arm64-v8a + x86_64 from one CMake file, and a GDScript call renders one second of a known register script to identical samples on all of them. | spec | Build matrix + sample hash | | ready | | | A14 |

### DATA — reading the original files

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| DATA-01 | Every file kind of every game loads (Vorticons: EGAHEAD/EGALATCH/EGASPRIT, LEVELnn, FINALE, texts, CTLPANEL, SCORES; Galaxy: EGAGRAPH with Huffman and the omnispeak chunk indices, GAMEMAPS/MAPHEAD with Carmack+RLEW, AUDIO/AUDIOHED, CONFIG; Dreams: its EGAGRAPH/GAMEMAPS/AUDIO variants), and an unknown value anywhere stops with the file and offset named. | spec | Loader test over the user's files; HARN-08 | | ready | | | Boot |
| DATA-02 | Each supported executable and data set is identified by checksum with its version named; the seven versions in `docs/REFERENCES.md` identify; shareware, CGA and Keen 6 v1.0 are named as unsupported with the remedy. | spec | HARN-13 | HARN-13a | blocked | | | Launcher |
| DATA-03 | Every decoded graphic of every game, exported through the art-export tool, is pixel-identical to the same graphic captured from the original's screen. | oracle | HARN-06 stills of title screens and help pages diffed against exported chunks | HARN-06a, DATA-01 | blocked | | | Modding |

### SIM — simulation cores (one group per engine)

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| SIM-V-01 | The Vorticons engine ported (IDLIBC, IDASM equivalents, KEENMAIN, KEENSCRN, KEENDEMO, KEENACTS, KEEN1/2/3ACT) runs headless from title through a level and back to the map, with the state hash defined over every variable the reference holds. | spec | HARN-03 run completes; hash covers the variable list generated from the reference | DATA-01, HARN-03a | blocked | | | Game loop |
| SIM-G-01 | The Galaxy engine ported (id_* and ck_* from omnispeak upstream, ck4/ck5/ck6 object files) runs headless through the built-in demo of each episode. | spec | As above | DATA-01, HARN-03a | blocked | | | Game loop |
| SIM-D-01 | The Dreams engine ported (id_* and kd_* from the released source) runs headless through its built-in demo. | spec | As above | DATA-01, HARN-03a | blocked | | | Game loop |
| SIM-02 | The emulated EGA card: a scripted sequence of register writes and plane writes produces the picture an EGA would, for every mode the three engines use (write modes 0–2, read modes, latches, panning, split screen, page flip, palette register writes). | spec | Golden pictures derived from the EGA specification; HARN-06 stills | | ready | | | Display |
| SIM-03 | The same inputs twice give the same per-frame hashes in every engine; store and restore at any frame gives the same hashes afterwards. | spec | HARN-05 | HARN-05a | blocked | | | Game loop |
| SIM-04 | Each engine's random table and index match the reference byte for byte. | oracle | Table dump compared | SIM-*-01 | blocked | | | Game loop |
| SIM-05 | No simulation script reads engine time, delta, window size or any shell setting; the only view-width read is the named activation function. | spec | Grep rule in the regression set | SIM-*-01 | blocked | | | A8/A15 |

### REPLAY — whole runs compared with the originals

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| REPLAY-G4 | Keen 4's built-in demos, then scripted and recorded runs of every level, match the original frame for frame in Classic view. | oracle | HARN-04 over HARN-01/HARN-03 | SIM-G-01, HARN-04a, HARN-02a | blocked | | | Game loop |
| REPLAY-G5 | Same for Keen 5. | oracle | As above | REPLAY-G4 | blocked | | | Game loop |
| REPLAY-G6 | Same for Keen 6 v1.4. | oracle | As above | REPLAY-G4 | blocked | | | Game loop |
| REPLAY-D | Same for Keen Dreams. | oracle | As above | SIM-D-01, HARN-02b | blocked | | | Game loop |
| REPLAY-V1 | Keen 1: timed-key sessions of every level match the original by distinct-frame sequence; the port's own recorded runs are bit-stable. | oracle | HARN-04 (sequence mode) over HARN-02c runs | SIM-V-01, HARN-02c | blocked | | | Game loop |
| REPLAY-V2 | Same for Keen 2. | oracle | As above | REPLAY-V1 | blocked | | | Game loop |
| REPLAY-V3 | Same for Keen 3. | oracle | As above | REPLAY-V1 | blocked | | | Game loop |
| REPLAY-08 | Every actor type of every game is reached by at least one passing case (coverage counters over the ported actor functions). | spec | Block coverage over the replay corpus | REPLAY-* | blocked | | | Progression |
| REPLAY-09 | Each game's ending sequence matches the original, driven by a cheat-warp case. | oracle | HARN-14 sessions | REPLAY-* | blocked | | | Endgame |

### SCREENS — menus, text screens, flow

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| SCR-01 | Every original screen of every game (title, menus, help pages, story, high scores, status, save/load, options, quit prompts, Paddle War, creature question, endings) renders pixel-identical to the original's still. | oracle | HARN-06 per screen | SIM-*-01, HARN-06a | blocked | | | Menus |
| SCR-02 | Menu navigation of each engine (wrap, remembered cursor, timeouts into the demo loop) matches the original. | oracle | HARN-14 sessions | SCR-01, HARN-14a | blocked | | | Menus |
| SCR-03 | Every FUNCTION of every game and the shell (enumerated by the walker from the menus, hot-key tables, prompts, text fields and cheat tables) is reached and completed by pad alone, by keyboard alone, and by touch alone; the walker always returns to the launcher; the list of functions and the device that reached each is written as evidence. | spec | HARN-09 pad-only, keyboard-only, touch-only modes | HARN-09a, SHELL-04 | blocked | | | Menus (A16) |
| SCR-04 | Vorticons' single-letter prompts (Y/N, D/T, 1–9, sound Y/N) are answerable on a pad through pick-lists that keep the original letters as hotkeys, and the original letter path still produces the original's still. | spec | HARN-09 + HARN-06 | SCR-01 | blocked | | | Menus |
| SCR-05 | Text entry (Galaxy save names, all high-score tables, Keen 6's creature answer) works with a d-pad: up/down choose a letter, right advances, left erases, confirm accepts; the saved name is what was shown. | spec | HARN-09 scripted entry; file compare | SCR-03 | blocked | | | Menus |
| SCR-06 | Each engine's key/button binding screen lets a pad rebind, add a second bind, clear, and back out, with a visible countdown on capture; the original keyboard screen still behaves as the original. | spec | HARN-09 | SCR-03 | blocked | | | Settings |
| SCR-07 | Added options screens use each engine's own window chrome, font and cursor (consistency unit across the three engines and the launcher). | judgment | Ask: side-by-side screenshots | SCR-01 | awaiting-user | | | Menus |
| SCR-08 | Mashing confirm, mashing back, and input during every fade never double-starts a level or skips a required screen. | spec | HARN-09 mash mode | SCR-03 | blocked | | | Menus |

### MENU — the added screens inside each engine's own menu system (design: docs/MENUS.md)

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| MENU-01 | Vorticons: the title menu has an *Options* row between High Scores and Ordering Info; it and F3/Start in play open the same Options window (Mode, Display, Controls, Sound, Quicksave, Fixes, Cheats, Quit game, Exit), drawn with ExpWin and the caret cursor; every row and sub-window is pad-complete. | spec | HARN-06 still (chrome equals the save menu's); HARN-09 pad-only | SCR-01, SCR-03 | blocked | | | MENUS.md |
| MENU-02 | Galaxy: MAIN gains CHEATS; CONFIGURE reads SOUND / MUSIC / DISPLAY / OPTIONS / FIXES / KEYBOARD / GAMEPAD / TOUCH; new cards carry a title drawn from the game's font in the card idiom; SVGA COMPATIBILITY is gone; every card is pad-complete. | spec | HARN-06 stills; HARN-09; HARN-12 (no derived title art) | SCR-01, SCR-03 | blocked | | | MENUS.md |
| MENU-03 | Dreams: the control panel has an *Options* button with its own two-colour icon in the panel style, opening Display / Gamepad & Touch / Fixes / Cheats / Quicksave panels in the existing button-and-caption idiom; pad-complete. | spec | HARN-06; HARN-09 | SCR-01, SCR-03 | blocked | | | MENUS.md |
| MENU-04 | The Mode row (Classic / Enhanced / Custom) exists at the top of every Options screen; choosing a mode sets every preset row; changing any row makes it read Custom; Classic equals the oracle's settings (state hash of a Classic session equals the oracle case). | spec | Settings test; HARN-05 | SHELL-05, MENU-01..03 | blocked | | | MENUS.md |
| MENU-05 | Display rows (View, Smooth motion, Scaling, Fullscreen, Pixel shape, Backdrop, Reduce flashes) are the same set in all three engines and the launcher, and each applies immediately. | spec | Row list compare; apply test | REND-02..10 | blocked | | | MENUS.md |
| MENU-06 | Consistency: in each engine the added screens use only that engine's font, window/card/panel chrome, cursor and sounds, and no two added screens differ in row idiom. | judgment | Ask: side-by-side shots (merges SCR-07) | MENU-01..03 | awaiting-user | | | MENUS.md |

### CHEAT — the cheat menu

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| CHEAT-01 | Each cheat is a flag read at one named point per engine (the originals' debug-key read sites); with every cheat off, every replay case's hash is unchanged. | spec | Grep rule + HARN-05 over the corpus | SIM-*-01 | blocked | | | MENUS.md |
| CHEAT-02 | Toggles — God mode, Infinite ammo, Infinite lives, No clipping, Jump cheat, Slow motion, Reveal secrets, Freeze enemies — each has exactly its documented effect in each engine, shown by a scripted case per cheat per engine (e.g. ammo count constant across 50 shots; Keen passes through a solid tile; actors' positions constant for 200 frames). | spec | Scripted cases, state inspection | CHEAT-01 | blocked | | | MENUS.md |
| CHEAT-03 | One-shots — Free items, Extra lives, Skip this level, Unlock the map — each applies once per activation and reports what it did; Skip marks the level done exactly as a real exit would (world-map state hash equals a played exit). | spec | Scripted cases | CHEAT-01 | blocked | | | MENUS.md |
| CHEAT-04 | Level select lists every level of the running game by its real name and starts the chosen one through the engine's own level-entry path. | spec | Walk every entry; hash of entry equals map-entered | CHEAT-01 | blocked | | | MENUS.md |
| CHEAT-05 | All cheats are off at every launch; cheat rows are greyed with no game in progress; the originals' own key combinations still work and are listed on the card. | spec | Launch test; HARN-09; replay of original codes | CHEAT-02 | blocked | | | MENUS.md |
| CHEAT-06 | A cheated session may enter the high-score table, as in the originals. | judgment | Decided J-15 | CHEAT-05 | verified | user decision 2026-10-06 | 1 | MENUS.md |

### FIX — the bug-fix list

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| FIX-01 | The fix list is generated from one table per engine (name, one-line description, flag); every row is a toggle on by default; the Classic mode turns all off; the UI shows every row with its description. | spec | Table/UI compare; HARN-09 | MENU-04 | blocked | | | MENUS.md |
| FIX-02 | Every fix has a replay case that shows the original behaviour with the fix off (matching the oracle) and the fixed behaviour with it on (matching a written expectation), and the two differ only where the description says. | oracle+spec | HARN-04 off; golden on | FIX-01, REPLAY-* | blocked | | | MENUS.md |
| FIX-03 | The seed list: every `// BUG:` annotation in the Keen 1–3 reconstruction and every known-bug note in omnispeak and the Dreams source is triaged into fix / keep-as-feature / not-a-bug, with the reason written down. | spec | Triage table complete (count equals grep count) | REPLAY-08 | blocked | | | MENUS.md |

### SHELL — launcher, settings, input, window

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| SHELL-01 | The program boots to a launcher screen showing seven tiles with found/missing status, with no games present, with some, and with all. | spec | Launch headless with fixtures; screenshot bounds | HARN-13a | blocked | | | Launcher |
| SHELL-02 | The launcher is fully navigable by keyboard, pad and touch (one horizontal scrolling row on narrow screens, grid on wide), launches a game, and returns to itself when the game quits with nothing carried over. | spec | HARN-09; state hash after return | SHELL-01 | blocked | | | Launcher |
| SHELL-03 | Steam libraries (all drives, via `libraryfolders.vdf`), GOG installs, and a chosen folder are scanned; every found game is named with its version; game folders are never written to (a read-only fixture passes). | spec | HARN-13 | HARN-13a, DATA-02 | blocked | | | Launcher |
| SHELL-04 | Input mapping: keyboard, pad (hot-plug, deadzone, remap, two-button reset) and touch overlay all deliver the same per-frame control structure to a simulation; the overlay hides while a pad is present. | spec | Scripted device events; hash equality | SIM-*-01 | blocked | | | Input |
| SHELL-05 | Settings persist, reset, survive a damaged file per value, and never reach a simulation (grep rule); per-game overrides win over global. | spec | Settings round-trip test; SIM-05 | | ready | | | Settings |
| SHELL-06 | Focus loss pauses and mutes and releases held keys; a stall of any length advances at most one catch-up frame. | spec | Scripted focus events; clock test | SIM-*-01 | blocked | | | Game loop |
| SHELL-07 | A second copy says so and waits; Enter starts it anyway. | spec | Two-process test | | ready | | | Launcher |
| SHELL-08 | Pad unplugged mid-level pauses with a prompt; reconnect or any key resumes. | spec | Scripted device events | SHELL-04 | blocked | | | Input |
| SHELL-09 | Every error message states what happened and the next step; a log file exists and its path is shown on the launcher. | spec | Fixture errors; string list | SHELL-01 | blocked | | | Launcher |

### SAVE — saves, quicksave, high scores

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| SAVE-01 | Each game reads and writes its original save format; a save written here loads in the original and vice versa. | oracle | HARN-16 | HARN-16a | blocked | | | Save |
| SAVE-02 | Quicksave stores the complete simulation (A7), including map planes and the card; quickload at any frame reproduces the hash; across a restart; across a level change; from the world map. | spec | HARN-05 round trip in all three situations | SIM-03 | blocked | | | Save |
| SAVE-03 | Corrupt, truncated and foreign saves and quicksaves are refused with a message; a save interrupted mid-write leaves the previous file intact. | spec | HARN-08 corpus; write-abort test | SAVE-01 | blocked | | | Save |
| SAVE-04 | High-score tables persist in the original formats and name entry reaches them on all devices. | spec | File compare after HARN-09 entry | SCR-05 | blocked | | | Save |

### AUDIO

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| AUDIO-01 | Galaxy IMF music through `d2opl` emits the original's OPL writes in order with the original's timing. | oracle | HARN-07 | HARN-07a, NATIVE-01 | blocked | | | Audio |
| AUDIO-02 | AdLib effects (Galaxy, Dreams) emit the original's writes on the original's frames, with the original's priority rule. | oracle | HARN-07 + event log | AUDIO-01 | blocked | | | Audio |
| AUDIO-03 | PC-speaker effects for all seven games emit the original's frequency sequence on the original's frames. | oracle | HARN-07 speaker mode | HARN-07a | blocked | | | Audio |
| AUDIO-04 | Output latency from a scripted input to the first sample is under 40 ms on Windows and under 60 ms on Android with the low-latency stream. | spec | Loopback probe | NATIVE-01, SHELL-04 | blocked | | | Audio |
| AUDIO-05 | Music and effect volume (added) scale output and persist; no audio device still runs. | spec | Settings test; null-device run | SHELL-05 | blocked | | | Audio |
| AUDIO-06 | Galaxy audio under Keen 1–3: with the toggle on, the mapped Keen 4/5 effects and tracks play on the frames the speaker effects would; the simulation hash is unchanged. | spec | Event log + HARN-05 | AUDIO-02, SIM-V-01 | blocked | | | Audio |
| AUDIO-07 | Overall sound character. | judgment | Ask: listen to each engine | AUDIO-01..03 | awaiting-user | | | Audio |

### REND — drawing, display options

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| REND-01 | The draw list rendered at 1× is pixel-identical to the card's picture for every frame of every replay case. | spec | Draw-list renderer vs card, per frame | SIM-02, REPLAY-* | blocked | | | Display |
| REND-02 | Native resolution: the draw list rendered at window size is the 1× picture scaled with no element misplaced (bounds on every sprite position scaled exactly). | spec | Position check at four sizes | REND-01 | blocked | | | Display |
| REND-03 | Smooth motion: between two simulation frames every moving element is on the segment between its two positions; teleports and spawns are not interpolated; the hash is unchanged. | spec | Interpolation assertion; HARN-05 | REND-01 | blocked | | | Display |
| REND-04 | Widescreen: the view width in tiles is settable per engine; the activation function reads it; with it at the original width the hash equals Classic; Galaxy's camera edge rules hold at every width. | spec | HARN-05 with/without; camera test | SIM-05 | blocked | | | Display |
| REND-05 | HUD placement in widescreen per engine. | judgment | Ask: mockups | REND-04 | awaiting-user | | | HUD |
| REND-06 | Palette fades and flashes advance by simulation frames and look right at 30–360 Hz; the reduced-flash option tints instead. | spec | Frame-timed test; by eye | REND-01 | blocked | | | Display |
| REND-07 | Window, borderless, fullscreen, resize, second monitor, scaling modes, 4:3-vs-square-pixel option. | spec | HARN-11 at each mode | REND-02 | blocked | | | Display |
| REND-08 | Every non-widening screen is composed by the shell as: the 320x200 card picture, pixel-identical to Classic inside its rectangle; around it a bevel frame drawn in that engine's window idiom from the draw list (not hand-painted bitmaps); outside that a backdrop tiled from the game's own tileset at the current pixel scale. The inner rectangle equals the Classic frame for every still in the SCR-01 corpus; the frame and backdrop never overlap it. | spec | Inner-rect equality over SCR-01 stills; HARN-11 bounds | REND-01, SCR-01 | blocked | | | Display |
| REND-09 | Dialogs, prompts and status windows opened over a wide view are centred in the wide field and drawn over the live wide world; the world map is wide from its first frame. No frame in any replay shows a 4:3 picture between two wide ones. | spec | HARN-04 frame scan for aspect flips over the replay corpus | REND-04, REND-08 | blocked | | | Display |
| REND-10 | The backdrop tile is a per-game setting with a default per game and a black option; changing it mid-screen redraws without touching the simulation. | spec | Settings test; HARN-05 | REND-08, SHELL-05 | blocked | | | Display |
| REND-11 | The look of the frame and the chosen backdrop tiles per game. | judgment | Ask: side-by-side screenshots per game | REND-08 | awaiting-user | | | Display |

### ANDROID

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| AND-01 | The APK exports from the same project with `d2opl` for arm64 and x86_64 and boots to the launcher on the emulator. | spec | HARN-15 | HARN-15a | blocked | | | Distribution |
| AND-02 | Game import through the system folder picker (or a ZIP) copies recognised files into app storage with per-file progress, retries, and a per-game result; the launcher re-detects without restart. | spec | HARN-13 Android tree + emulator run | SHELL-03 | blocked | | | Launcher |
| AND-03 | Touch overlay per engine (d-pad, jump, pogo/fire, menu) delivers the same control structure as a pad; hides with a pad present; bounds hold at phone aspects. | spec | SHELL-04 harness; HARN-11 | SHELL-04 | blocked | | | Input |
| AND-04 | Back gesture is Esc everywhere; the app leaves only through a game's own quit path or the launcher's. | spec | HARN-09 on the emulator | SCR-03 | blocked | | | Menus |
| AND-05 | Audio on Android uses the low-latency stream and meets AUDIO-04. | spec | Loopback probe on device | AUDIO-04 | blocked | | | Audio |
| AND-06 | The feature parity list (every setting key, every screen, every game) is identical between the Windows build and the APK. | spec | HARN-15 | AND-01 | blocked | | | Distribution |
| AND-07 | How it feels on the user's phone with a Backbone and on touch. | judgment | Ask | AND-01..06 | awaiting-user | | | Distribution |

### V15 — v1.5 goals (deferred; own blueprint pass after v1.0)

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| V15-01 | Replacement asset packs (images, sounds, songs by name, any resolution, per game) with the export tool and fallback rules of the Duke project. | spec | (blueprinted in v1.5) | REND-01 | deferred | revisit: after v1.0 release | | v1.5 |
| V15-02 | Map builder: choose a game, edit tiles/objects/flags with that game's own sets, save in the engine's level format, play in place; pad/touch-operable. | spec+judgment | (blueprinted in v1.5) | DATA-01, SIM-*-01 | deferred | revisit: after v1.0 release | | v1.5 |
| V15-03 | Player-made map library in the launcher. | spec | (blueprinted in v1.5) | V15-02 | deferred | revisit: after v1.0 release | | v1.5 |

### DIST — distribution

| ID | Claim | Class | Check | Needs | Status | Evidence | Att | From |
|---|---|---|---|---|---|---|---|---|
| DIST-01 | The repository and both builds contain no original file or derivative. | spec | HARN-12 | HARN-12a | blocked | | | Distribution |
| DIST-02 | Every source file carries the GPL notice and the attribution for its reference. | spec | Header check | | ready | | | Distribution |
| DIST-03 | A fresh checkout plus the user's game folders runs on Windows; the APK plus an import runs on Android. | spec | HARN-15 + manual | AND-01 | blocked | | | Distribution |

## Judgment queue

| ID | Question | Options | Tradeoff | Blocks | Decided |
|---|---|---|---|---|---|
| J-01 | Public name of the program. Working title "Keen Rework"; "Megarocket" is the obvious carry-over. | (a) Megarocket (b) a new name (c) decide at release | (a) continuity with the existing release and Steam entry; (b) clean break from the bundled-engine design; (c) costs nothing now | DIST-02 (file headers), SHELL-01 (title) | **2026-10-06:** Megarocket. The rebuild is Megarocket 2.0; headers, title and Steam entry keep the name. |
| J-02 | Default simulation rate presentation: the originals' speed in DOSBox today (Steam's `cycles=auto`) or the 1991 hardware rate. They differ for the Vorticons engine, which runs by vblank and so is already fixed; Galaxy/Dreams run by a 70 Hz timer and are fixed too. | (a) original tic rates (default) (b) a speed setting | (a) is what the oracle records; (b) is a presentation-only multiplier | none | **2026-10-06:** (a) original tic rates only; no speed setting. |
| J-03 | Which of the originals' known bugs get an optional fix (default off)? A list is produced during REPLAY-08 with each bug's effect. | per bug: keep / toggle | each toggle is a tested branch | none until the list exists | **2026-10-06:** FIX BY DEFAULT, toggle back to original per bug. Consequence: the Classic preset turns every fix off (bug-for-bug, oracle-comparable); the default Enhanced play has fixes on. Each fix is a listed, tested toggle. |
| J-04 | Keen 6 creature question: keep the screen with an auto-answer toggle, or always show it. | (a) show, player answers, pad text entry (b) toggle to auto-answer, default on | (b) removes a friction most players remember with dread; (a) is purer | SCR-05 (ordering only) | **2026-10-06:** (b) auto-answered by default; a toggle shows the screen. |
| J-05 | Original save-file compatibility: full two-way, or read-only. | (a) two-way (default) (b) read original, write port-own | (a) is proven by HARN-16; (b) is less work and loses nothing for players who never go back to DOS | SAVE-01 | **2026-10-06:** (a) two-way compatible, proven through HARN-16. |
| J-06 | Vorticons one-button fire: added control on by default (as Megarocket) or off (authentic). | (a) on (b) off | (a) is what you played; (b) is the original | SHELL-04 defaults | **2026-10-06:** (a) one-button fire added, on by default; two-button combo still works. |
| J-07 | Galaxy audio under Keen 1–3: carry the Megarocket feature, and default. | (a) carry, default off (b) carry, default on (c) drop | (a) keeps the toy without changing first impressions | AUDIO-06 | **2026-10-06:** (a) carried, off by default. |
| J-08 | Widescreen HUD placement per engine (Galaxy's score box, Dreams' panel, the Vorticons added score box). | mockups when REND-04 passes | taste | REND-05 | deferred to mockups (2026-10-06) |
| J-09 | Overall sound character per engine (OPL emulator choice, speaker synthesis shape, latency buffer). | listen | taste | AUDIO-07 | deferred to a build you can hear (2026-10-06) |
| J-10 | Added options screens' look across the three engines and the launcher. | side-by-side when SCR-01 passes | taste | SCR-07 | deferred to screenshots (2026-10-06) |
| J-11 | Smooth motion by eye, especially Galaxy's camera and pole climbing. | look when REND-03 passes | taste | none | deferred to a build you can see (2026-10-06) |
| J-12 | Which existing Megarocket features to carry beyond those listed: the launcher's title-art tiles (the engines render their own title screens, no data shipped), the carousel on narrow screens, the how-to page. | per feature | each is a day of shell work | SHELL-01 | **2026-10-06:** Carry all four: title-art tiles, carousel on narrow screens, how-to page, per-game accents + rocket branding. All rebuilt fresh. |
| J-14 | Frame look and backdrop tile per game for the framed screens (Megarocket used each episode's starfield tile for 1-3 and a dark tile for 4-6, with a five-layer bevel: black seam, sunken inset, flat face, raised outer bevel, outline). | per game: tile choice; frame: Megarocket's five-layer look vs each engine's own dialog border | the five-layer look is one frame for all seven; per-engine borders make each game look like itself | REND-11 | **2026-10-06:** Each engine's own dialog-border idiom (three draw-list routines); backdrop tile per game chosen later from screenshots (REND-11 stays open for that). |
| J-15 | May a session in which a cheat was used enter the high-score table? | (a) yes, as the originals (b) no, with a note on the table (c) yes but marked | (a) is faithful; (b) is what most modern ports do | CHEAT-06 | **2026-10-06:** (a) yes, as the originals. |
| J-13 | On a phone with no pad, should the Keen 1–3 two-button scheme get a third on-screen button (fire) by default? | (a) yes, one-button fire button (b) jump + pogo only | (a) matches J-06 | AND-03 | **2026-10-06:** (a) d-pad + jump, pogo and fire. |
## Regression set

Runs at every group boundary and before any push: every `verified` unit's check, in this order
(the HARN-09 pad-only walk is in every run, per A16 — a group cannot close with a function a pad cannot reach):
HARN self-tests, DATA, SIM determinism (all three engines), REPLAY corpus, SCREENS stills, HARN-09
walk, SAVE round trips, AUDIO comparisons, REND equality, HARN-12 clean tree, HARN-15 export
check. One command: `python tools/regress.py` (to be written as HARN-01a's first deliverable,
growing as units verify).

## Calibration log

| ID | Attempts | Cause | Note |
|---|---|---|---|

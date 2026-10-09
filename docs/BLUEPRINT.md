# Megarocket 2.0 — Coverage Blueprint

Generated 2026-10-06 · Status: pre-build

Public name decided 2026-10-06: **Megarocket** (this is Megarocket 2.0). This is a from-scratch successor
to the Megarocket launcher (`F:\KeenLauncher`), which bundled three separate engines behind a
shell. Here the seven games are one program, built the way the Duke Nukem II recreation was
(`F:\Dropbox\Sidescroller Recomps`): the original's code ported function for function into
GDScript, drawn through an emulated EGA card, proven against the DOS originals by machine
comparison.

## Project classification

| | |
|---|---|
| Type | Faithful recreation of seven games inside an original modern shell. The two halves follow different rules and are blueprinted separately below. |
| Games | Commander Keen 1–3 (*Invasion of the Vorticons*, 1990, the "Vorticons" engine), Keen 4–6 (*Goodbye, Galaxy!* and *Aliens Ate My Babysitter!*, 1991, the "Galaxy" engine), Keen Dreams (1991, the engine between the two). Three engines, seven games, one program. |
| Engine | Godot 4.7.2, standard build (`Godot/4.7.2/`, export templates downloaded). Game logic in GDScript. One small native library for OPL (AdLib) emulation, reused from the Duke project (`d2opl`). |
| Platforms | **Windows and Android, both required targets (user, 2026-10-06).** Linux/Steam Deck by export. Every design choice must hold on a phone: no desktop-only file assumptions, touch as a first-class input, the one native library (OPL) built for Android too. |
| Distribution | Free, GPL v2, public repository plus ready-to-run builds. **No original asset is included in any download.** The program finds the player's own copies (Steam, GOG, a folder they point it at). |
| Fidelity posture | Faithful-plus-additions. One-for-one play feel and one-for-one features first; modern quality-of-life layered on top, each switchable, with one deliberate exception (below). |
| Input | Keyboard, gamepad and touch, all first-class, every screen. No mouse needed. On-screen touch controls hide whenever a physical controller is present (the Megarocket rule). |
| Multiplayer | None. Not planned. |

## Intent summary

Seven games that a player of the originals cannot tell apart from the DOS versions in Classic
mode, then switchable to native resolution, widescreen and display-rate motion; with quicksave and
quickload in every game; found and set up with no manual file work; playable end to end on a
gamepad alone.

It ships on Windows and Android from the same project. It is deliberately not: an emulator; a container for the existing engines (omnispeak, the Keen 1–3
port, ReflectionHLE) — those are *reference material* here, not components; a remake with
redesigned content.

Quality priorities, in order:

1. Behaviour identical to the original in Classic mode, proven by machine comparison, for every game.
2. **Controller-complete from the first screen:** no function of any game or of the shell needs a mouse or keyboard, ever, and this is checked on every screen as it is built rather than audited at the end (user, 2026-10-06; Megarocket never fully got there). The shell never loses a player's progress and never leaves them stuck.
3. Modern display options look right, and the widescreen behaviour decision (below) is honoured.
4. Easy for others to build, mod and extend; the seven games share as much as the originals did.

## Reference material

| Reference | What it is | How it is used |
|---|---|---|
| `keen13/reconstruction` | K1n9_Duk3's reconstructed Keen 1–3 source (GPL v2), compiles to the shipped executables, version-switchable (1.0–1.31). | The specification for Keen 1–3. Ported function by function. |
| `keen13/port` | Megarocket's SDL port of that reconstruction, with a bit-exact replay harness (`keen13/verify`). | Second opinion; its replay cases become oracle cases. Not treated as ground truth. |
| `omnispeak` / `omnispeak-ref` | David Gow's pixel-perfect, bug-for-bug reimplementation of Keen 4–6 (GPL v2); `-ref` is the pristine upstream, `omnispeak` the Megarocket fork. | The specification for Keen 4–6 (there is no released original source). Ported function by function. Its `data/` metadata (action tables, chunk indices) is engine-own public data and may be bundled. |
| `refkeen` (`src/kdreams`) and id Software's released Keen Dreams source | The original Keen Dreams C source (GPL v2 release, 2014) as carried in ReflectionHLE. | The specification for Keen Dreams. |
| `keen6/keen6.conf`, Steam `dosbox.conf`/`keen4.conf` | How the games are sold today. | Oracle settings start from these. |
| Player's own game files | Keen 1–3 v1.31 (Steam), Keen 4/5 v1.4 (Steam `base4`/`base5`), Keen 6 v1.0 EGA (run as is by the oracle; the port reads its three version tables from the executable), Keen Dreams v1.00 (`keendreams/game`) and the 2015 Steam release (supported in v1.0, J-17). SHA-256 of each executable recorded in `docs/REFERENCES.md`. | Run in DOSBox as the oracle; read at run time by the port. Never copied into the repository. |

## Fidelity line

**Simulation, matches the original exactly:** movement, collision, enemy and object behaviour,
damage, the random-number table and index, scoring, pickups, level scripting, world-map logic,
camera movement, draw order, menu behaviour and navigation, which sounds play and when, the
original's known bugs, the original cheats, per-version differences.

**Presentation, modernised freely:** window and display mode, output resolution, frame rate between
simulation steps, aspect ratio, input devices and bindings, where files are stored, audio output,
setup, error messages, the added options screens.

Ambiguous cases, decided:

| Case | Decision |
|---|---|
| The originals' speed depends on the PC | Fixed simulation rate per engine: the Vorticons engine's vblank-locked rate, Galaxy's 70 Hz tic clock, Dreams likewise. Each game's own speed settings still exist where it had them. |
| **Widescreen shows more of the level, and actors wake when they come into view** | **Decided by the user 2026-10-06: actors adapt to the wider view.** Enemies activate and alert against what is actually on screen, not the original 320-pixel window. This is a *deliberate simulation change* when widescreen is on. Consequence: parity against the original is claimed only in Classic view; a widescreen session is not oracle-comparable and is verified by the port's own determinism and by eye. The activation rule is a single documented function per engine, so the change is one place, not a scatter. |
| Smooth motion between simulation steps | Presentation only. The simulation never knows. |
| Native resolution | The same frame redrawn from the draw list at any size; the simulation is unchanged. |
| Screens that cannot widen (title art, menus, story and help text, high scores, endings, Paddle War, dialogs) | **Framed, not letterboxed to black (user, 2026-10-06).** The 320x200 picture sits in a bevelled frame in the engine's own window idiom, over a backdrop tiled from that game's own tileset, with pop-up dialogs centred in the full 16:9 field. This is the treatment Megarocket arrived at; the DESIGN is carried, the implementation is not: it is built fresh as a shell-side composition of the draw list, so no engine code knows about it. |
| The originals' menus | Reproduced, including look, order, wrap-around and sounds. Added options live on their own screens styled to match each engine. |
| Known bugs (e.g. the Vorticons "impossible pogo", Galaxy's save-on-map-only quirks, Dreams' level-exit oddities) | **Decided 2026-10-06 (J-03): fixed by default in Enhanced play, each fix an individually listed toggle; the Classic preset turns every fix off, and that is the only mode in which parity against the original is claimed.** |
| Keen 6 copy-protection creature question | Auto-answered by default; a toggle shows the screen, where any answer passes (decided 2026-10-06, J-04). |
| Keen 4–6 shipped demos | Play as original and are the primary oracle cases for those games. |
| Original save files | Read and written in the original formats so progress carries both ways (J-05). Quicksave is a separate port-own file, as in Megarocket. |
| Keen 1–3 saves only on the world map; Galaxy saves anywhere from the menu | Kept per game. Quicksave (added) saves anywhere in all seven. |
| Vorticons two-button fire (jump+pogo together) | Kept; a one-button fire control is an added option (default on, as Megarocket shipped it) (J-07). |

## Intentional additions

Everything here is a feature. An audit must not flag it as a deviation.

- One program for all seven games, with a launcher screen in front of them.
- Runs natively; no emulator.
- First-run setup that finds the games in Steam and GOG installs automatically, or lets the player browse to a folder; per-game status; re-detects without a restart; never writes into the game folders.
- Gamepad support everywhere, including rebinding, hot-plugging, and text entry (save names, high scores, Keen 6's creature answer) on a d-pad — a gate on every screen-bearing unit (ledger A16), not a feature added after.
- Android build from the same project: touch overlay (d-pad plus buttons, per-engine layouts), game import through the system folder picker into the app's own storage, landscape lock, audio at low latency.
- Export for Android (Windows launcher): once any game is found, one button writes a folder (or ZIP) of the found games' files, organised and labelled, that the Android app imports in one pick and runs straight away (user, 2026-10-07).
- Fixed-rate simulation independent of machine speed.
- Window, borderless and fullscreen; integer and fit scaling; native resolution.
- Classic / Enhanced presets per game and globally. Classic = original rates, original bugs, original view, speaker audio; Enhanced = the fixes, widescreen, smooth motion, native resolution.
- Smooth motion at the display rate (toggle).
- Widescreen with adapted actor activation (toggle) and reworked HUD placement per engine.
- A cheat menu in every game, in the Wolf3D project's style (side-scroller cheats: god mode, infinite ammo and lives, no clipping, jump cheat, slow motion, free items, extra lives, skip level, level select, unlock the map, reveal secrets, freeze enemies; all off at launch; the originals' own codes still work) — see docs/MENUS.md.
- A bug-fix list in every game: one toggle per original bug, on by default, all off in Classic mode (J-03).
- Every addition lives inside the engine's own menu system in its own idiom (an Options row for Keen 1–3, cards for 4–6, a panel button for Dreams), with a Classic / Enhanced / Custom mode row at the top. Design in docs/MENUS.md.
- Framed presentation of every non-widening screen: bevel frame in the engine's style, backdrop tiled from the game's own art (tile chosen per game, player-overridable), dialogs centred in the wide field, the world map wide from its first frame. Designed fresh from the Megarocket precedent, not copied.
- Quicksave and quickload in every game, including mid-level in Keen 1–3 and Dreams, as a full simulation snapshot.
- Pause and mute on focus loss (toggle).
- Saves, settings, high scores and quicksaves in the per-user folder, in the originals' formats where an original format exists.
- Session recording, used for testing and offered to players.
- Galaxy audio for Keen 1–3 (the Megarocket "Galaxy sfx / tunes" feature: Keen 4/5 AdLib effects and music under the Vorticons games) as a toggle, default off (J-08).
- Sound-chip emulation (OPL) for AdLib; PC-speaker synthesis; Sound Blaster digitised effects where the original had them (Keen Dreams has none; Galaxy has none; Vorticons none — so: AdLib + speaker only).
- Optional replacement artwork and sound from a mods folder (mechanism in scope; art is a later phase).

## Coverage matrix

Verification key: **oracle replay** = same inputs through the original in DOSBox and through the
port, frames compared; **oracle still** = one captured screen compared; **oracle audio** = the
original's chip writes compared; **automated test**; **manual checklist**; **by eye / ear** = the
user decides.

### Launcher and setup (added; the app half)

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Cold start with nothing configured: a launcher screen that says which games are found, which are missing, and how to add them | required | The first thing every new user hits | automated test | catalog |
| Steam installs found automatically (library folders read from Steam's own `libraryfolders.vdf`, every drive) | required | Zero-effort setup for the common case | automated test (fixture library) | project |
| GOG installs found automatically (registry and default folders) | required | Same | automated test | project |
| A folder the player points at is scanned recursively for any of the seven games, in any mix | required | Collections, ZIPs they unpacked, old CD copies | automated test | project |
| Every supported version identified by checksum and named; unsupported versions (shareware, CGA) named plainly with what to do | required | Wrong data otherwise fails confusingly deep in play | automated test | catalog |
| Per-game status, never all-or-nothing; a game can be added later | required | Most people own some of the seven | automated test | catalog |
| Re-detection after the player fixes something, without restarting | required | Setup is a loop, not a step | automated test | catalog |
| Game folders are never written to | required | Steam verifies files; GOG folders may be read-only | automated test | project |
| Paths with spaces and non-English characters; read-only install location; no admin rights | required | This project lives in a path with spaces | automated test | catalog |
| Two copies launched at once | required | Both would write the same saves | automated test | catalog |
| Launcher usable with gamepad alone, keyboard alone, and (later) touch | required | Couch and Deck use | automated test (path walk) + manual | project |
| Every error names what happened and the next step; a log file exists and its location is shown | required | Diagnosability for other people's installs | automated test | catalog |
| Version shown in the UI | required | Bug reports | automated test | catalog |
| Android: games imported through the system folder picker (or a ZIP) into app storage; per-file progress; a failed copy is retried and reported | required | Phones have no Steam folder to scan | automated test (fixture tree) + manual | project |
| Windows: "Export for Android" on the launcher, available once at least one game is found: writes one folder (or one ZIP) holding exactly the recognised files of every found game, organised per game with a manifest, which the Android app takes in one pick and plays at once | required | Getting the user's own files onto a phone is the hardest step of the Android setup (user, 2026-10-07) | automated test (export then import round trip, fixture and emulator) + manual on the user's phone | user |
| Android: the on-screen controls hide when any physical controller is connected and return when it leaves | required | Backbone-style play | manual checklist | project |
| Android: back gesture/button maps to Esc everywhere; the app never exits on it without the game's own quit prompt | required | Accidental exits lose progress | automated test (path walk) | project |
| Android: install on a phone with no prior data, grant nothing, run | required | Cold start on the other platform | manual checklist | catalog |

### Boot and first run (per game)

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Each game's original boot sequence: title, credits/story, high scores, demo loop (Galaxy, Dreams), help text (Vorticons) | required | Fidelity; first impression | oracle still + oracle replay | project |
| Missing or corrupt file inside a found game names the file instead of crashing | required | Mod users will hand it broken files | automated test (bad-data corpus) | catalog |
| Unknown values in level, graphics or audio data stop loudly, never skipped | required | A silent skip produces a level that looks complete and is not | automated test | catalog |
| Second launch reads back everything the first wrote | required | Lost settings feel broken | automated test | catalog |
| Keen 6 creature question (copy protection) shown and passable | required | Original boot gate | oracle still | project |

### Menus and navigation

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Every original menu and text screen of all three engines drawn identically | required | Fidelity promise | oracle still | catalog |
| Cursor movement, wrap-around, remembered selection, as each engine does it | overridden-by-fidelity | "Improving" navigation changes the feel | oracle still | catalog |
| Galaxy's card-menu system interpreted in full (every card, every item type) | required | Nearly all of Keen 4–6's UI is data | automated test | project |
| Vorticons' Y/N, D/T and 1–9 single-key prompts answerable on a pad (the Megarocket pick-list treatment) | required | Pad-only play; these prompts have no original pad path | automated test (path walk) | project |
| Main menu times out into the attract loop (Galaxy, Dreams) | required | Original behaviour; demos live there | automated test | project |
| Back out from every screen at every depth lands in the right place | required | Classic soft-lock source | automated test (path walk) | catalog |
| Mashing confirm, mashing back, input during a fade | required | Can double-start a level | automated test (path walk) | catalog |
| Keyboard and gamepad pressed at once | required | Added device | automated test | catalog |
| Every screen reachable and usable with a gamepad alone, including the seven games' own options, save/load, help, and Paddle War exit | required | Steam Deck; the Megarocket audit found many gaps here | automated test (path walk) + manual | project |
| Text entry (save names, high-score names, creature answer) with a gamepad | required | No keyboard on a handheld | automated test + manual | catalog |
| Key-binding screens: each engine's own conflict rules kept; a pad can rebind, add, clear and back out | required | Megarocket's controls screen trapped pad users | automated test (path walk) | project |
| Added options screens match each engine's look | required | Should feel like part of the game | by eye | project |
| Changing resolution or widescreen while inside a menu | required | Common crash point | manual checklist | catalog |
| In-game hot-keys per engine (F-keys, Esc, pause, status) and their added pad equivalents | required | Each opens a screen from inside play | oracle still | project |
| Cheat codes and debug keys per game | required | Players expect them | automated test | project |
| Confirmation before quitting a game in progress, per engine's own way | overridden-by-fidelity | Original asks in its own way | oracle still | catalog |

### Settings

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Each game's original options (sound, music, two-button fire, keys, joystick entry) kept and persisted in its own config format | required | Fidelity | automated test | project |
| Added settings: global, with per-game override where it makes sense (view, smooth, widescreen, scaling) | required | Seven games, one feel | automated test | project |
| Every added setting applies immediately or says it needs a restart | required | Otherwise it looks broken | automated test | catalog |
| Reset to defaults restores everything, per game and globally | required | Way out of a bad configuration | automated test | catalog |
| Hand-edited or damaged settings file falls back per value, never fatal | required | Mod community edits files | automated test | catalog |
| A binding that leaves the player unable to navigate can be undone (hold-two-buttons reset) | required | Self-inflicted lockout | automated test | catalog |
| Settings changed mid-level do not disturb the simulation (except the widescreen activation rule, by design) | required | Display options must never change behaviour | automated test (state hash) | catalog |
| Joystick calibration screens | not-applicable | Modern pads need none; the entries open the pad options | — | project |

### Game loop

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Whole-level behaviour identical to the original for the same inputs, every level of every game, Classic view | required | The core promise | oracle replay | project |
| Same inputs twice give identical results, in every view mode | required | Everything else rests on this | automated test (state hash) | catalog |
| All simulation arithmetic uses the originals' 8/16-bit whole-number behaviour, including wrap-around and fixed-point | required | Decimal maths introduces drift the original never had | oracle replay | catalog |
| Simulation steps at a fixed rate regardless of display rate | required | Originals ran by machine speed | automated test | catalog |
| Display rates from 30 to 360 and uncapped | required | Modern monitors | automated test | catalog |
| A long hitch does not fast-forward the game out of control | required | Catch-up after a stall can kill the player unseen | automated test | catalog |
| Losing focus pauses and mutes; held keys are released | required | Alt-tab otherwise leaves Keen running | automated test | catalog |
| Sleep and resume | required | Deck suspends constantly | manual checklist | catalog |
| Very long sessions: counters behave as the originals' do | overridden-by-fidelity | Original counters wrap | oracle replay | catalog |
| Galaxy's palette effects, Vorticons' screen flashes, Dreams' fades at any frame rate | required | Tied to the originals' timing | oracle replay + by eye | project |
| Widescreen actor activation rule, one function per engine, documented | required | The user's one deliberate simulation change; must be contained | automated test (state hash with/without) | project |

### Input

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Inputs reach each simulation as the original's own control structure per frame (Vorticons `ControlStruct`, Galaxy `CK_input`-style frame, Dreams `ControlInfo`) | required | Makes every session recordable | automated test | project |
| Galaxy and Dreams demo formats recorded and played; files written here play in the originals | required | The originals' own replay path is the best oracle driver | oracle replay | project |
| Vorticons has no demo format: a port-own recording format plus timed-key driving of the original in DOSBox | required | Keen 1–3 need an oracle too | harness self-test | project |
| Controller unplugged mid-level pauses and prompts | required | Player cannot act while the game runs | manual checklist | catalog |
| Controller reconnected or swapped | required | Handhelds | manual checklist | catalog |
| Left and right held together resolves as each original does | overridden-by-fidelity | Defined per engine | oracle replay | catalog |
| Analog stick deadzone; stick and d-pad together | required | Drifting sticks | automated test | catalog |
| Key held across a level load or menu exit | required | Original has specific behaviour | oracle replay | catalog |
| Prompts show the bound key or button | required | Rebinding must be reflected | manual checklist | catalog |

### Save and load

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Vorticons: nine world-map saves in `SAVEDn.CKx` format; Galaxy: six named slots in `SAVEGAMn.CKx`; Dreams: its slots in its format; all readable by the originals | required | Players can carry progress both ways | automated test (round trip through the original's loader in DOSBox) | project |
| Quicksave and quickload in every game, anywhere, as a full simulation snapshot including map planes (the Megarocket pickups-reappear lesson) | required | The headline addition | automated test (state hash round trip) | project |
| Quickload after a restart, across a level change, from the world map | required | Where Megarocket's version broke | automated test | project |
| Corrupt, truncated or foreign save file rejected with a message | required | Otherwise crashes on load | automated test | catalog |
| Disk full or write interrupted leaves the previous save intact (write to temp, then rename) | required | How saves get destroyed | automated test | catalog |
| High-score tables per game; name entry; persisted in the original formats | required | Original feature | automated test | project |
| Config and saves from Megarocket (`QUICKSAV.CKx`, `KEENLNCH.CFG`) imported or at least recognised | deferred | Nice for the one existing user; the formats were port-own | — | project |
| Saves shared between the player's devices (PC and Android) | planned | The user's goal (2026-10-09); see "Save sync between devices" below | automated test (two-device simulator) + path walk | project |

### HUD and feedback

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Each engine's status display drawn identically (Vorticons status screen on demand, Galaxy score box and status window, Dreams score panel) | required | Always on screen or one key away | oracle replay | project |
| Galaxy's optional persistent score box and the Megarocket-added score box for Vorticons | required | Existing features | oracle replay / automated test | project |
| Extremes: maximum score, zero ammo, full inventory, 99 lives | required | Overflow shows here first | automated test | catalog |
| Widescreen HUD placement per engine | required | Original HUDs assume 320 wide | by eye (J-09) | project |
| Layout at 4:3, 16:10, 16:9, 21:9 and a handheld screen | required | Nothing clipped or overlapped | automated test (bounds) | catalog |

### Audio

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Galaxy music (IMF) through OPL emulation; AdLib effects for Galaxy and Dreams | required | The originals are chip instructions, not recordings | oracle audio | project |
| PC-speaker effects for all seven games, synthesised from the originals' frequency streams | required | Vorticons has nothing else | oracle audio (speaker-port writes) + by ear | project |
| Sound priority rules per engine; which effect plays on which frame | required | Part of behaviour | oracle replay (event log) | catalog |
| Music changes per level and screen; stops and restarts as original | required | Transitions are where music breaks | automated test | catalog |
| Volume controls for music and effects (added) | required | Originals had on/off only | automated test | catalog |
| Audio device removed or changed mid-session; no device at all | required | Must still run | manual + automated | catalog |
| Constant audio latency low enough not to feel late (Megarocket's Android lesson) | required | Feel | by ear + automated latency probe | project |
| Galaxy audio under Keen 1–3 (added toggle) | required | Carried feature | automated test | project |
| Overall sound character acceptable | required | Emulation choices are audible | by ear (J-10) | project |

### Progression and rules

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Vorticons: Keen's movement, pogo, raygun, world map, level completion rules, the three episodes' items and endings | required | The feel of 1–3 | oracle replay | project |
| Galaxy: Keen's full move set (pole climbing, looking, hanging, two-button fire), neural stunner, world map, level flags, the three episodes' objects and bosses | required | The feel of 4–6 | oracle replay | project |
| Dreams: flower-power throwing, the world map, the boss | required | The feel of Dreams | oracle replay | project |
| Every actor behaviour in every game (Vorticons ~30 per episode, Galaxy ~50 per episode, Dreams ~25) | required | The bulk of the game | oracle replay | project |
| Difficulty levels (Galaxy, Dreams) change which objects appear | required | Three versions of every level | oracle replay | catalog |
| Scoring, lives, extra-life thresholds, keycards, gems, ammo | required | Core rules | oracle replay | catalog |
| Death and restart: what resets and what carries | required | Where stale state shows | oracle replay | catalog |
| Secrets and hidden levels; Keen 4's Bean-with-Bacon Megarocket ending route; Keen 6's reachable ending; Keen 5's QED | required | Endings are chronically untested | manual checklist (side by side) | project |

### Level transitions, endgame

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Every level of every game loads; first and last of each | required | Endpoints are chronically untested | automated test | catalog |
| World-map ↔ level transitions, level-done sequences, "one moment" screens | required | Original sequence | oracle replay | project |
| Each game's ending and credits; return to the menu | required | Rarely exercised | manual checklist | catalog |
| Quit to menu, then to the launcher, then into another game, carries nothing over | required | Stale state across *games* is new here | automated test (state hash) | project |
| User-made levels (Vorticons level files, Galaxy GAMEMAPS patches) load | required | Mod community | automated test | project |

### Display (added)

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Classic picture pixel-identical to the original at 320×200 for all seven games | required | Parity | oracle replay | project |
| 4:3 shape by default with a square-pixel option | required | DOS pixels were taller than wide | by eye | project |
| Native resolution: the same frame redrawn from the draw list at window size | required | The headline display feature | automated test (draw list equals card picture at 1×) | project |
| Window, borderless, fullscreen; resize; second monitor; display scaling | required | Standard expectations | manual checklist | catalog |
| Smooth motion looks right for scrolling, Keen, actors, things that teleport or spawn, and Galaxy's smooth-scroll camera | required | Interpolating a teleport smears it | by eye (J-11) | project |
| Smooth motion changes nothing in the simulation | required | Parity when it is on | automated test (state hash) | project |
| Widescreen at any width; levels narrower than the view; Galaxy's map-edge camera rules | required | Some levels are small | automated test | project |
| Palette fades and flashes at any frame rate | required | Originals timed them to the display | by eye | project |
| Every non-widening screen of every game is framed over a tiled backdrop; the picture inside the frame is pixel-identical to Classic; nothing of the original is covered | required | The user's widescreen presentation standard | automated test (inner-rect equality) + by eye (J-14) | project |
| Dialogs and pop-ups opened over a wide view are centred in the wide field and composited over the live world, not over a 4:3 flip | required | Megarocket's 4:3-to-16:9 flip was the visible seam | automated test (frame diff shows no flip) | project |
| The backdrop tile per game is a setting with a sane default; black bars remain selectable | required | Taste varies; black must stay possible | automated test | project |

### Accessibility

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Option to reduce full-screen flashes | required | Seizure risk | automated test | catalog |
| Full remapping on both devices | required | One-handed play | automated test | catalog |
| Colour-blind options | deferred | Original art fixed; revisit with replacement art | — | catalog |
| Subtitles | not-applicable | No speech | — | catalog |

### Modding and replacement assets (added)

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Replacement image for any sprite, tile, backdrop or screen, matched by name; higher resolution allowed | required | The "new imagery" goal, carried from Duke | automated test | project |
| Missing or malformed replacement falls back with a note in the log | required | Partial packs are normal | automated test | catalog |
| Export tool that writes every original image to files as a starting point | required | Artists need the originals laid out | automated test | project |

### Distribution

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| No file from the original games, and nothing derived from one, in the repository or any build | required | The one legal line | automated test (clean-tree check) | project |
| GPL notices on every file; attribution to K1n9_Duk3, David Gow (omnispeak), id Software (Keen Dreams), NY00123 (ReflectionHLE) | required | Licence terms | automated test | project |
| A fresh checkout plus the player's games produces a running program | required | "Point and go" | automated test | project |
| Windows build and Android APK from the same project, same version, same features | required | Both are release targets | automated test (export both, feature parity list) | project |
| Linux build | required | Steam Deck | manual checklist | project |
| Steam Deck: gamepad-only, sleep and resume, small screen | required | Stated use | manual checklist | catalog |

### v1.5 goals (user, 2026-10-06) — planned, not in v1.0

Two systems that follow the v1.0 release. They are recorded now so v1.0's architecture keeps them
possible (the draw list keys every image by name, which is what makes replacement packs cheap;
levels are loaded through one loader per engine, which is what a map builder needs to write to).
Each gets its own blueprint pass before it is built.

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| Replacement asset packs: any sprite, tile, backdrop, screen, sound or song replaced by name from a mods folder, at any resolution, per game; export tool for the originals; missing or malformed replacement falls back with a log note | deferred (v1.5) | The Duke project's "new imagery" goal, carried | automated test | project |
| Map builder: an in-program editor where the player picks a game, draws tiles and places objects from that game's own sets, sets level flags, saves to that engine's level format, and plays the result in place | deferred (v1.5) | The user's stated goal; user levels are a big part of the Keen community | automated test (round trip through the engine's loader) + by eye | project |
| Map builder: an intuitive, pad- and touch-operable interface (A16 applies) | deferred (v1.5) | Same rule as everything else | path walk | project |
| Player-made maps in a library screen, launchable from the launcher, sharable as files | deferred (v1.5) | Playing them is the point | automated test | project |

### Save sync between devices (user, 2026-10-09) — planned

The player's progress follows them between the Windows app and the Android app, the way Steam Cloud,
Xbox and Switch saves do: when you start a game you continue from where you last played, on whichever
device, and when both devices have moved on you choose which one to continue from.

**How the platforms do it (research, 2026-10-09).** Steam Cloud downloads at game launch and uploads at
exit; when both copies changed it shows a conflict dialog with the local and the cloud copy and their
times, and the player keeps one. Xbox's Game Saves asks "Which one do you want to use?" with "This
console" or "The Xbox network (cloud data)", for the whole game at once; it also says when the game
is running on another device ("Looks like you're signed in on another device"), and when it cannot
reach the cloud it offers "Try again" or "Use offline". Switch downloads a newer cloud save
automatically while the console sleeps, and a download overwrites the console's copy for good.
Google Play Games lets a game resolve conflicts by a rule (most recently modified, longest playtime,
highest progress, last known good) or ask the player. Common to all: sync is automatic at launch and
exit; the player is only asked when both copies changed; the question names the devices and the
times. The weak spots players complain about: the words "local" and "cloud" do not say which copy is
newer, the choice is all-or-nothing for the game, and the copy not chosen is lost.

**Megarocket's design.** Familiar where they are good, better where they are weak:

| Item | Status | Why it matters | Verification | Source |
|---|---|---|---|---|
| What is shared: each game's save slots, its quicksave, its high scores (merged, not replaced); not controls, display or audio settings (per device), never the games' own files | planned | The player's progress, nothing else | automated test | user + research |
| Sync when a game is opened (fetch) and when it is saved or closed (send); in the background otherwise; play is never blocked (a few seconds of "Syncing…", then play with this device's saves) | planned | Steam's and Xbox's rhythm, which players know | automated test (simulator) | research |
| Only one device changed: its progress is taken without a question, with a short notice ("Continuing from Living-room PC · 12 min ago") | planned | No needless prompts (Switch, Steam) | automated test | research |
| Each slot on its own: different slots changed on different devices are both kept without a question (Xbox's choice is for the whole game) | planned | Fewer conflicts than the platforms | automated test | research |
| The same slot changed on both: at the game's start a choice of two cards, side by side, each naming the device and saying when, with what the save holds (game, level or map position, score, lives, items, time played) and a picture of where it was saved; "Continue from Phone" / "Continue from PC"; the newer one focused; pad, keyboard, touch | planned | The user's request: choose which device's progress to go on with, in the words players know | automated test + path walk | user + research |
| The copy not chosen is kept: a save history per game (the last versions of each slot, with device and time), restorable from the game's menu (the platforms discard it) | planned | No progress ever lost by a wrong tap | automated test | research |
| A game open on the other device: "You're playing Keen 4 on Living-room PC. Continue here?" | planned | Xbox's "signed in on another device" | automated test | research |
| The other device or the cloud unreachable: play with this device's saves ("Use offline"); the sync happens next time, by the same rules | planned | Offline play must always work | automated test | research |
| Which copy is newer decided by change counters per slot, not by the devices' clocks (wrong clocks must not lose progress); clocks only for display | planned | Clock skew is how sync loses saves | automated test | catalog |
| A transfer interrupted, a full disk, a damaged copy: the slot keeps its last good version (write aside, verify, then swap) | planned | Same rule as local saves (SAVE-03) | automated test | catalog |
| A deleted save is deleted on the other device too, and restorable from the history | planned | Otherwise deleted saves come back | automated test | catalog |
| Each save labelled with its game and version (Keen 6 v1.4, Dreams v1.93): never loaded into another | planned | Releases differ (J-19) | automated test | project |
| Turning sync on with saves on both devices: a one-time choice (keep both where they differ, or take one device's) | planned | The first sync is the riskiest | automated test + path walk | catalog |
| Transport 1, home network: pair once by scanning a code the PC shows; the two talk directly on the same Wi-Fi; no account, no server, nothing leaves the house | planned | Simplest and private; Godot's own networking | automated test + device test | user |
| Transport 2, the player's own Google Drive (its hidden app-data folder, which the app alone can see): sync anywhere; opt-in; no server of ours, no player data held by the project | planned | Away from home; every Android phone has the account | device test | research |
| Transport 3, a folder the player already syncs (Syncthing, Dropbox, OneDrive): pick it on each device | planned | Power users; Android's folder access limits it | device test | catalog |
| A sync settings page: on/off, paired devices (names editable), transports, "sync now", the history | planned | Control and trust | path walk | catalog |

Not planned: a server run by the project (accounts, passwords, hosting and security duties a free
project should not take on). Open choices for the user: J-21 (when it ships), J-22 (which transport
first), J-23 (whether the choice of cards may be skipped by a rule).

## Deferred and not-applicable

| Item | Reason |
|---|---|
| Multiplayer | None of the originals have it; not planned. |
| Joystick calibration | Not applicable to modern pads; entries open the pad options. |
| Achievements, overlays | No storefront. (Save sharing between devices is planned: see "Save sync between devices".) |
| Subtitles | No speech. |
| Colour-blind palette | Deferred to the replacement-art phase. |
| Shareware and CGA versions | Detected and named at start-up; support deferred. |
| Keen 6 v1.5 | Deferred; v1.0 (the user's copy, tables from its executable) and v1.4 (omnispeak's headers) first. v1.5 is a small delta after that. |
| Megarocket save/config import | Deferred; port-own formats, one known user. |
| macOS, web | Deferred. Design keeps them possible. Android is NOT deferred. |
| New artwork itself | Deferred to v1.5 (replacement packs). The loading mechanism is in scope for v1.0. |

## Open questions

Each has a working default so nothing is blocked. See the judgment queue in `BUILD_LEDGER.md`.

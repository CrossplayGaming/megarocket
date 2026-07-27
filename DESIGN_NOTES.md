# Keen Launcher — Design Decisions

Living record of user-approved design direction. Newest decisions at the bottom.
(Engineering state lives in session memory; this file is the product spec.)

## Settled in playtesting (July 2026)

- **Widescreen gameplay**: 426px view (~16:9 at EGA 1.2 pixel aspect), runtime-configurable
  (`rf_wideWidth` 320–432). Camera/sim math untouched — presentation-only.
- **Edge behavior**: crop slides asymmetrically at map edges so out-of-map border tiles
  ("EDGE OF MAP") are never visible.
- **Smooth motion**: full-redraw compositor; camera *and* sprites interpolated between sim
  tics, presented at display refresh. Sprites placed at whole-pixel granularity
  (`rf_spriteSubpixel`) so they move coherently with the 1px camera.
- **Pixel purity — HARD REQUIREMENT**: never filter, antialias, upscale, or otherwise alter
  the pixel art. All smoothness comes from *placement* and *timing*, never from pixel
  processing. Indexed EGA pixels end to end.
- **Scaling**: sharp-bilinear (round-up integer pre-scale, slight linear down-fit). True
  integer scaling is offered only where the math genuinely works (e.g. 320-wide view);
  the settings UI must not offer impossible combinations.
- **HUD**: scorebox and DEMO sign are present-time overlays pinned to the view — no jitter,
  no edge-slide. Overscan border emulation off by default (toggle stays available).

## Menu system (Phase 3)

- **Look**: visually match the ORIGINAL Keen menus (ComputerWrist frame, fonts, colors,
  card layout) as closely as possible. New settings integrate as native-looking entries
  and cards — no visible "modern UI" styling. Prefer extending the engine's own card/menu
  system (US_RunCards) over skinning a foreign toolkit; ImGui (if used at all) is reserved
  for launcher-level chrome outside the game window.
- **New settings to expose** (all knobs already exist in config):
  video — view width/aspect (incl. native 320), scaling mode (sharp-fit / true integer
  where valid / square-pixel), refresh handling (`rf_presentRateCap`: vsync / capped /
  uncapped), smooth scrolling toggle, compositor toggle, sprite placement granularity,
  overscan border, fullscreen;
  input — full keyboard rebind, controller mapping.
- **Controller mode**: first-class couch experience — every menu and binding screen fully
  navigable by gamepad (SDL game-controller layer: standardized cross-brand buttons,
  press-to-bind, hot-plug, deadzone tuning). TV/Steam-Deck-style: never need the keyboard.

## 4:3 art on wide displays (Phase 3 presentation polish)

- Applies to **all artwork that functions like the intro screen**: title screen, ComputerWrist
  menus, help screens, Star Wars story text, ending sequence art, high scores — every
  full-screen 4:3-native surface.
- **Never stretch, never extend the art, never black bars.** The art keeps its exact aspect,
  surrounded by a style-consistent frame, with a texture from the game's own assets tiling
  outward to fill whatever the user's display aspect requires (works for any monitor shape).
- Backdrop texture is a game tile (candidates: dark rock/wood/metal tiles from EGAGRAPH);
  per-episode theming possible. Final texture + frame choice: user judges from mockups.
- The terminator scroller (already wider than the screen and self-scrolling) is assessed
  separately — it may stay full-bleed.

## Long-term possibilities (user-proposed, approved for planning)

- **Modern Sounds toggle for Keen 1-3** (Phase 4 feature): optional replacement of the
  PC-speaker effects with AdLib effects mapped from Keen 4-6 ("jump" → Keen 4 jump, etc.).
  Mapping lives in a curated table (drafted by Claude, tuned by ear with the user).
  Only available when Keen 4-6 data is present — sounds come from the user's own files.
  Presentation-only; harness-guarded.
- **Android build** (post-1.0): the C + SDL2 stack ports cleanly (precedent: user's
  TURBOSTEIN ECWolf Android launcher). Standing constraint from now on: keep all engine
  code portable — platform-specific code stays in dev tooling / #ifdef'd backends.
  Android-specific work when the time comes: packaging, scoped-storage data import,
  touch overlay controls (physical pads already work via the SDL controller layer).
- Trivia: shared Bobby Prince composition(s) between Keen 4-6 and Catacomb 3-D era id
  titles — music heard in Keen levels is authentic (loaded from the user's AUDIO.CKx
  files only; no cross-project resources exist in the code).

## Phase placement summary

- Phase 2 (next): sim/presentation formalization + checksum verification harness.
- Phase 3: native-look menu system + settings; controller mode + mapping; framed-backdrop
  treatment for all 4:3 art; launcher shell (episode detect/select, first-run).
- Phase 4: Keen 1-3 port inherits the entire presentation + menu + input stack.
- Upstream reports owed: `last_cursor_time` uninit read (id_us_2.c); MSVC Release built
  with debug flags (CMakeLists).

## Phase 4 status (2026-07-24): Keen 1 engine FIRST LIGHT on MSVC x64

`keen13/port/` builds `keen13.exe`: the full v1.31 reconstruction (KEENMAIN /
KEENDEMO / KEENSCRN / KEEN1ACT / IDLIBC as real TUs, matching RCK1.MAK) plus
`idlib13.c`, a platform layer replacing IDASM.ASM. The game boots through
main(), loads all assets, reads the title map (LEVEL90), and runs its main
loop; `K13_DUMP=1` PPM captures show the "ONE MOMENT" pic rendered
pixel-perfect through the engine's own DrawPic.

Architecture (idlib13.c):
- Real-mode memory model: 640KB arena backs the far heap so FP_SEG/FP_OFF/
  MK_FP/movedata keep true paragraph semantics; transient handles cover
  non-arena globals; segments A000-AFFF hit 4 emulated 64KB EGA planes via
  the game's own outportb writes (SC map mask, GC read map, CRTC regs).
- SIM-CRITICAL exact ports from IDASM.ASM: Rnd (17-entry lagged-Fibonacci,
  including the always-set carry into its ADC), RndT (256-entry id table),
  RLEExpand (byte RLE), RLEW codec (word RLE, 0xFEFE tag).
- LoadGraphics ported: EGAHEAD tables resident, EGALATCH via the
  reconstruction's own C LZW, EGASPRIT with the three 2/4/6px pre-shifted
  sprite copies rebuilt bit-exactly in C.
- Draw routines are byte-exact plane copies (DrawChar/DrawTile/DrawPic/
  DrawSprite); masked-tile path still TODO.

Build-time data rip: `keen13/tools/rip_keen1.py` UNLZEXEs the user's
KEEN1.EXE and generates `port/generated/TINFCK1.C` (611-tile attribute
arrays, TILINF2C port) + `ENDSCRN1.C` (exit screen). Generated files derive
from game data - never commit/ship them.

16-bit layout traps fixed so far (audit pattern for the rest): string
literal written by strcpy (_extension), 4-byte read of 16-bit file field
(lzw_maxcodelen), 32-bit `unsigned` RLEW words, LevelDef struct overlaying
16-bit file header. LoadCtrls reads CTLPANEL.CK1 into 32-bit int structs -
same bug class, NOT yet fixed (config values will be garbage).

Next session (in-game first light):
1. Port VidRefresh/VidInitDraw/DrawPage0+1 (adaptive tile refresh, page
   flip via CRTC start, pel pan) as C over the emulated planes.
2. SDL2 window + present loop, keyboard -> NoBiosKey/keydown, timecount
   timer; then title screen -> menus -> demo playback.
3. Fix LoadCtrls/SaveCtrls 16-bit struct layouts; masked DrawTile;
   ScrollTextWindow reimplementation; staged FadeIn/FadeOut timing.
4. Input-record/replay harness for sim verification vs DOSBox.

Crash triage: exe links with /MAP; the built-in handler prints the faulting
module offset - resolve with build/Release/keen13.map.

## Phase 4 update (2026-07-24, session 2): KEEN 1 IS PLAYABLE

Full loop verified in the SDL2 window (captures in keen13/port/captures/):
Apogee intro animation -> title screen -> main menu (arrows + Enter) ->
new game -> "Keens left" box -> Mars world map (walking, camera scroll,
terrain collision) -> level entry via Ctrl on an entrance -> side-view
level with running, jumping physics, sprite animation. Help (F1) shows the
full framed text-window UI pixel-exact (glyph-diffed against the game's
own font data; Keen 1's chunky small-caps m/w just read oddly to modern
eyes - NOT a bug).

New in the platform layer (idlib13.c):
- VidInitDraw/VidRefresh/DrawPage ported: 21x14 adaptive tile refresh into
  two EGA pages (tile field at byte 0x604), page flip via CRTC start,
  pel pan, anim-phase table select from timecount; RF_ForceRefresh real.
- Masked foreground tiles (negative tilenum; mask lives in tile slot+0x20,
  read per-plane), K13_EGAScroll (ScrollTextWindow's block moves).
- SDL2: window (960x720, nearest), ARGB texture upload of the visible CRTC
  window incl. pel pan, palette from the tracked EGA registers, border
  color clear. WaitVBL paces at 70Hz wall clock and presents (fades work).
- ISR-faithful keyboard: SDL scancode -> DOS set-1 map (keypad = arrows,
  as on DOS), KEYDOWN stores make|0x80 in NBKscan exactly like Int9ISR,
  NoBiosKey(0/1) ported from the v1.31 asm incl. the game's own scanascii
  table. Timer thread = INT8: timecount/inttime advance as DELTAS so game
  code that rewinds timecount (DoFkeys) keeps working.
- K13_Idle(): pump + throttled present, injected at ControlKBD and the two
  raw keydown spin loops - DOS interrupts updated state behind poll loops;
  this is the port's equivalent. (Fixed: hangs in ShowText/menus.)
- LoadCtrls/SaveCtrls now read/write the 16-bit CTLPANEL layout.
- MAXTILES=700 for the anim tables (611 tiles in Keen 1; 512 overflowed).
- Dev tools: K13_WARP=n places Keen on level n's map entrance (like
  /TEDLEVEL); K13_DUMP=1 PPM frames; K13_DUMP_PAGES both pages; K13_TRACE
  breadcrumbs + heartbeat; crash filter + /MAP.

Known gaps / next:
- Sound is the only remaining STUB layer (PC speaker via SDL audio;
  SoundData/UpdateSPKR; sounds.ck1 already loads).
- Demo playback untested (user's gamedata has no DEMO?.CK1 files).
- Timing feels right but needs the record/replay verification harness
  (Keen 1-3 have no built-in demos - plan: input-record layer feeding
  ControlPlayer, cross-validated against DOSBox).
- DOS exit screen (B800 text page) captured but not displayed on quit.
- Presentation polish deferred to launcher integration: EGA 1.2 pixel
  aspect, integer scaling options, widescreen treatment, backdrop frame.
- K13_Trace tracepoints still in game code (env-gated, marked K13_PORT
  debug) - strip before release builds.
- Keen 2/3: EPISODE=2/3 builds of the same tree (need TINFCK2/3 rips,
  VERSION differences audit).

## Phase 4 update (2026-07-24, session 3): sound, verification, all 3 episodes

- PC SPEAKER SOUND: timer corrected to the real PIT rate (divisor 0x2000 =
  145.65Hz -- the game was running at HALF SPEED on the old 70Hz timer!).
  Speaker sequencer ported from UpdateSPKR (word freq stream per entry in
  SOUNDS.CKx; 0=rest, FFFF=end; priority gate in PlaySound), square wave
  at PIT-divisor frequency through SDL audio. Pause/Continue/WaitEnd done.
- RECORD/REPLAY VERIFICATION HARNESS (K13_RECORD=file / K13_REPLAY=file):
  deterministic sim via frame-latched timecount (sim clock advances ONLY
  by whole frame tics; the PIT thread keeps a private real-tick counter
  for pacing -- enemy anims read timecount into shapenum, which feeds
  hitboxes, so wall-clock jitter would desync replays: the root cause of
  the famous DOS Keen demo desyncs). Recordings capture per-frame tics +
  keydown/NBKscan snapshots + NoBiosKey results + RNG seeds, then 7
  per-frame component hashes (objlist/pobjlist/numobj/gamestate/origin/
  level/rng). Input is quantized to recorded boundaries during harness
  runs. K13_STATEDUMP=1 embeds raw objlist per frame; desyncs then print
  the exact object + byte offsets. VERIFIED: full session (intro, menus,
  world map, warp, level entry, run, jump) => "REPLAY OK (737 frames)".
  Baseline: keen13/verify/baseline_keen1.k13r (replay with K13_WARP=1).
  NOTE: replay must run with the same K13_WARP env as the recording.
- ALL THREE EPISODES BUILD AND BOOT: rip tool generalized (rip_keen1.py
  1 2 3) -- Keen 2/3 EXEs carry linked-in sounds + help/story/end/preview
  texts (TEXTSLINKED/SOUNDSLINKED), ripped to generated/LINKED{2,3}.C.
  CMake builds keen13 / keen13_ep2 / keen13_ep3 from one shared tree.
  Fixes: MAXTILES 700->768 (Keen 3 has 715 tiles), USE_LZW guard in
  LoadGraphics (ep 2/3 latches are uncompressed), bioskey() forward
  (KEEN2ACT DoFinale). Both episodes boot their attract cycles with
  episode-correct tilesets. Game data staged: gamedata2/ gamedata3/
  (from the user's Steam zip, v1.31).
- Playable builds staged next to each episode's data: gamedata/keen13.exe,
  gamedata2/keen13_ep2.exe, gamedata3/keen13_ep3.exe (+SDL2.dll).

Still open: DOS exit screen display on quit; DOSBox cross-validation
spot-checks; deep Keen 2/3 playtests + baselines; K13_Trace strip for
release; then launcher integration + widescreen/high-refresh presentation
(the omnispeak treatment) gated on the harness staying green.


## Phase 5 (2026-07-24, session 4): WIDESCREEN + INTERPOLATION FOR KEEN 1-3

Present-time compositor (keen13/port/k13_compositor.inc, wired in
idlib13.c): re-renders the visible world straight from mapplane + a
world-space sprite list captured in RF_PlaceSprite, into a 426px 16:9
index buffer with camera AND sprites interpolated between sim frames.
Sim untouched -- baseline replay verified green WITH the compositor live
("REPLAY OK (737 frames)"). Details:
- Z-order: background tiles -> sprites -> foreground tiles (intile<0,
  masked -2) -> screen-anchored pics (piclist, centered).
- Edge-sliding crop: camera clamps to a 2-tile margin so border tiles
  never show; symmetric widening around the 320 view otherwise.
- Sprite/camera snapshots rotate at VidRefresh (complete frames only --
  mid-frame presents composing from a half-built capture list was the
  Keen-flickers bug); interpolation in world space, index-matched, snaps
  on >32px deltas. Presents happen in the K13_FrameTics pacing loop
  (vsync), K13_Idle, and VidRefresh; every present interp-composes if
  nothing composed yet.
- Menus/text/status screens fall back to the classic 4:3 EGA page view
  automatically (compose requires uservect==NULL + live map).
- Presentation: EGA 1.2 pixel aspect both paths; sharp scaling = 4x
  integer prescale (nearest) into a render target, then slight linear
  fit. Env: K13_WIDE=0|320..512 (default 426), K13_SMOOTH=0|1 (def 1).
- All three episodes built + staged with the compositor (shared code).

Open polish: user playtest (interp feel, sound character); menu width
transition (wide->4:3 jump on menu open, like early omnispeak); level
edges beyond map bounds render black in wide (fine); backdrop frame
treatment for the letterbox areas per DESIGN directive; VIDEO-settings
style in-game toggles; exit screen; K13_Trace strip.

## Playtest round 1 fixes (2026-07-24 evening) + KEEN 6 UNBLOCKED

User-reported issues, all fixed, baseline still REPLAY OK (737 frames):
1. Boot flash (cut-off grey id-board over stars): the compositor was
   composing the raw TITLEMAP (level 90 = menu-backgrounds map) before
   the intro screens drew over the pages. Compose gate now requires
   level != TITLEMAP; intro/title/menus are always the classic view.
2. Maximize crushed the wide view to ~4:3: a stale
   SDL_RenderSetLogicalSize(960,720) from early bring-up was fighting
   the explicit aspect-fit rects. Removed; aspect now correct at any
   window size. Added F11 fullscreen-desktop toggle (handled in the SDL
   pump, not forwarded to the game).
3. Scroll jitter everywhere: interpolation alpha was quantized to whole
   PIT ticks (6.87ms steps, ~6 per frame). Alpha now measured in
   milliseconds against the frame's expected duration.

KEEN 6: the user's new copy (Documents/SPLATTER/Keen6.zip -> staged in
rt/) WORKS with Omnispeak - terminator intro + credits render (the old
v1.0 copy black-hung immediately). Slots 4-6 all playable now.

KEEN DREAMS: user delivered keendrms.zip (archived to
F:/KeenLauncher/keendreams/). 7th launcher slot; Keen Dreams has GPL
source (id release) so the port path mirrors Keen 1-3/omnispeak when
its phase begins. Launcher must be prepped for all 7 games.


## Playability parity work (2026-07-24 late): saves, controller, menus, config

Item 1 - SAVE/HIGH-SCORE FILE LAYOUT (was a live bug): gametype and
highscoretype are written to disk verbatim, but their boolean/enum
fields were 4 bytes on MSVC vs 2 on DOS. Fixed with #pragma pack(2) +
Sint16 flags, guarded by compile-time size asserts (SCORES=204 bytes).
Verified: F5 save writes a 92-byte SAVED1.CK1 (= sizeof gametype), and
Continue Game loads it, restoring Keen to the saved world-map spot.
High-scores screen renders correctly. NOTE: this changed the gamestate
byte layout, so the replay baseline was re-recorded -> baseline_keen1
.k13r now 741 frames, REPLAY OK.

Item 2 - CONTROLLER SUPPORT: SDL GameController layer in idlib13,
blended into ControlKBD so a pad always works alongside the keyboard
(couch play, zero setup). Dpad+left stick = move; A/X/either trigger =
fire (per the user's trigger-to-fire request); B/Y/shoulders = jump;
Start=Enter, Back=Esc for menus (edge-triggered synthetic key events).
Hot-plug via CONTROLLERDEVICEADDED. Verified end-to-end with a
synthetic pad (K13_PADSYN) walking Keen on the map; real-pad FEEL needs
the user's hardware.

Item 3 - NATIVE OPTIONS MENU: new 'Options' item in the main menu
(enum + Print line + switch case, matching the hand-written menu
idiom), opening OptionsMenu() in KEENSCRN.C -- same ExpWin/DrawWindow
chrome, game font, and animated Keen-face cursor as the originals.
Shows View Size (4:3 / 360 / 396 / 16:9), Smooth Motion, Fullscreen,
a Save/Load F5 hint, and Exit. Verified rendering + navigation.

Item 4 - CONFIG PERSISTENCE: KEENLNCH.CFG (next to game data) holds
wide=/smooth=; loaded at SDL init, saved on Options exit. Verified both
directions (pre-set cfg shows 360/OFF in the menu; menu exit writes the
file). F11 fullscreen toggle also exposed as a menu item.

All three episodes rebuilt + staged. Remaining for parity: letterbox
backdrop frame (item 5), controller press-to-bind screen (currently
fixed default mapping), quicksave already works via F5. Then: DOSBox
spot-checks, Keen 2/3 baselines, attract demos, exit screen, volume,
Modern Sounds, K13_Trace strip, launcher shell (7 slots).


## Playtest round 2 fixes (2026-07-24 night): dialogs stay wide + fire toggle

1. POPUPS NO LONGER FLIP TO 4:3. In-game dialogs (save, quit, sound,
   the 'Keens Left' entry box) are drawn to the EGA page; the
   compositor now keeps composing the frozen wide world and copies the
   dialog's window RECTANGLE from the page over it -- so gameplay stays
   16:9 behind the popup. Key detail: DrawChar's page base is the
   PARAGRAPH-FLOORED screen start (screenseg = start>>4), so the overlay
   iterates the window's real page bytes and maps each back to its wide
   column via (bytecol - (start&0xF))*8 - pan + shift (a naive screen-
   space copy clipped the left ~3 chars). Also dropped the 'require a
   sprite' gate, so world-map entry is 16:9 from the first frame with
   the Keens-Left box composited over it -- no more 4:3->16:9 flip when
   you gain control. Title-screen menus still use classic 4:3 (the
   compose gate is level != TITLEMAP), which is correct for the framed
   4:3 title art.

2. FIRE IS NOW A TOGGLE (keyboard AND controller). Vorticons shoots on
   button1+button2 TOGETHER (jump+pogo) -- unintuitive on a pad. Added
   a config 'onefire' (default 1) + an Options 'Fire button: 1-KEY /
   2-KEY' item. When 1-KEY, a dedicated fire control (keyboard Space,
   or pad X/Y/triggers) presses BOTH engine buttons so one press
   shoots. When 2-KEY, authentic (press both). Verified: onefire=1 ->
   Space fires KeenShoot; onefire=0 -> single Space fires nothing.
   Controller remap: A/shoulders = jump, B = pogo, X/Y/LT/RT = fire.

Baseline still REPLAY OK (741 frames). All 3 episodes rebuilt + staged.
Full controller REBINDING (custom button assignment) is still a
follow-up; the toggle + sensible defaults make the pad usable now.


## Playtest round 2 fixes (2026-07-24, late): 3 reported issues

1. POPUP FRAME CROPPED: K13_DialogOpened() was called at the TOP of
   DrawWindow, before win_xl/yl/xh/yh were assigned, so it captured the
   PREVIOUS window's rectangle -- the wide overlay then copied a too-
   small region and clipped the frame. Moved the call to AFTER win_* are
   set. Frames now composite complete.

2. OPTIONS MENU RE-ANIMATED ON SCROLL: OptionsMenu() called ExpWin()
   (which plays the window expand animation) once per loop iteration, so
   every cursor move looked like the menu reopening. Restructured to
   draw the window + labels ONCE before the loop; the loop only repaints
   the value column and moves the cursor (erase old glyph, draw new) --
   matching the original menus.

3. FIRE OPENED A BLANK WINDOW / DIDN'T FIRE: Vorticons shoots on
   button1+button2 together; I'd mapped keyboard one-button fire to
   SPACE -- but Space is the game's STATUS-SCREEN key (keydown[KEY_SPACE]
   -> ShowStatusScreen), so 'firing' popped the status window. Remapped
   keyboard one-button fire to LEFT-SHIFT (unused in-game); controller
   fire stays X/Y/LT/RT. Verified: L-Shift/onefire fires KeenShoot;
   Space still (correctly) shows status. Also gated the pad->menu-key
   synthesis to non-gameplay only, so pad B(pogo)/A(jump) no longer
   inject spurious Esc/Enter during play.

KNOWN SEPARATE BUG (pre-existing, low priority now): grey-font info
screens drawn with PrintGrey -- the STATUS screen (Space) and similar --
render with a correct frame but BLANK interior. Root cause is the
engine's double-buffering: these static screens draw straight to
screenseg's page and never flip the CRTC, and the content ends up on a
page the present isn't showing (frame + text can even land on different
pages). Attempted a page-pin (k13_dialog_base / k13_drawbase) + present-
from-screenseg; frames show but PrintGrey text still doesn't -- the
page-flip timing during these screens needs more work. NOT triggered by
normal play now that fire != Space. Deferred to task #24. The save/quit/
sound/Keens-Left dialogs (normal Print, small windows) composite fine.

Baseline REPLAY OK (741 frames) throughout; all 3 episodes rebuilt +
staged.


## Status-screen blank window: RESOLVED (2026-07-24)

The PrintGrey 'blank interior' bug was never a page/drawing bug at all.
A deterministic repro (K13_TEST_STATUS env: auto-Enter through the menu,
inject Space on the Nth live frame, dump the composed frame + pinned
page, exit) proved the pinned EGA page held the COMPLETE status screen
-- frame, grey text, sprites, tiles.  The real cause: ShowStatusScreen
waits for a key with NoBiosKey(0), whose port wait-loop pumped input but
NEVER PRESENTED.  The last present happened during the ExpWin expand
animation (before the text was drawn), so the display froze on an empty
white window forever.  Fix: the NoBiosKey(0) wait loop now calls
K13_Idle() (pump + rate-limited present) instead of raw pump.  The
status screen now composites complete over the 16:9 world.  Verified
via scripted repro dumps; replay baseline still REPLAY OK (741 frames);
all three episodes rebuilt and staged.  Lesson recorded: any DOS busy-
wait that blocks outside WaitVBL/K13_Idle freezes the displayed frame --
audit new blocking loops for a present path.


## Playtest round 3 (2026-07-24): geometry, quit dialog, rebinding

All four reports traced to real defects.  Two shared one root cause.

1. POPUPS OFF-CENTRE RIGHT + DISTORTED TEXTURE AT THEIR LEFT EDGE.
   screencenterx is set to SCREENWIDTH/2-1 = 23 (KEENMAIN), i.e. the
   game centres windows on the 48-byte VIRTUAL page (384px), not the
   320px screen.  On hardware the paragraph-floored draw base (screenseg
   = start>>4 drops a 4-5 byte low nibble) cancels most of that back
   out, so DOS lands near centre.  The compositor samples page bytes
   directly and gets no such cancellation -> ~32px right.  Now centred
   explicitly: off = comp_w/2 - rect_centre, so any window size lands
   dead centre and stays put while scrolling (DOS wobbles with the pel
   pan).  The 'distortion' was the +/-1 char margin the copy included:
   those bytes hold page-world pixels from the sim's own scroll
   position, which does not line up with the interpolated wide world.
   Copy the exact char rect and the seam is gone.

2. BACKGROUND JOGS SIDEWAYS WHEN A WINDOW OPENS (startup, fade-ins).
   Same low nibble.  The classic present had a special case that showed
   screenseg's floored base while a dialog was up, so opening a window
   shifted the whole background by 32-40px, then back on the next
   refresh.  Deleted the special case: always present from the CRTC
   start register + pel pan, which is what the hardware does and is
   therefore right for every screen (the game only ever draws to
   screenseg, which VidInitDraw derives from that same start address;
   graphics init sets both to page 0).  Geometry is now constant.

3. QUIT DIALOG: D AND T DEAD (box just closed).  Turbo C's toupper was
   byte-wide -- the 16-bit RTL loaded AL and returned AX with AH clear
   -- so the game hands it Get()'s packed (scancode<<8)|ascii directly,
   as every '(Y/N)?' and '(D)os or (T)itle' prompt does.  MSVC returns
   anything above 255 unchanged, so ch stayed lowercase 'd'/'t' and
   matched no case.  Measured in the real binary (ch=0x64); note a
   ctypes probe of ucrtbase disagreed with the compiled behaviour, so
   trust the instrumented build.  Fixed with K13_ToUpper/K13_ToLower in
   IDLIB.H under K13_PORT.  This also repairs F2 Sound (Y/N) and the
   title-screen Quit (Y/N), which were broken the same way.

4. REBINDING (Options -> Controls...).  New native-style screen:
   'Move keys+buttons..' opens the game's OWN F3 keyboard screen (8
   directions + button1/2); 'Fire key' rebinds the port's one-button
   fire control; 'Pad jump/pogo/fire/status' are press-to-bind, and
   accept the analog triggers as well as buttons.  Key names render via
   the game's own printscan().  Persisted as a 'bind=' line in
   KEENLNCH.CFG (older configs without it keep the defaults).
   Defaults: pad A/B/X/Y, fire key Left Shift.  NOTE the original F3
   screen could never have worked in this port: its key-scan loop spins
   on keydown[] with no pump, and our 'INT 9' IS the event pump, so it
   hung.  Now idles once per sweep.  Pad actions are single-bound now
   (jump was A-or-either-shoulder, fire was X-or-Y-or-either-trigger).

Selection cursors in both port menus now use Get()'s own blinking caret
at sx,sy, the way id's menus do, instead of a hand-drawn glyph -- which
also removed a stray blinking artifact parked after the last value.

Dev harness added: K13_TEST_SEQ='ms:scan,...' scripted key presses
(timed from the first live gameplay frame, or from process start with
K13_TEST_ABS=1) and K13_TEST_SHOT=<ms> to dump the screen and exit.
Both are env-gated and silent otherwise.  These made every fix above
reproducible without hand-driving menus.

Verified: baseline REPLAY OK (741 frames) after all changes; D exits
cleanly; T returns via the engine's own GAME OVER/high-score path;
rebinding Z persisted (bind=...,44) and fires, while Left Shift no
longer does; popups centred in 16:9 and correct in 4:3.  All three
episodes rebuilt and staged.


## Keen 4-6 menu pass (2026-07-24): overflow, audit, keyboard card

1. KEYBOARD CARD UNREACHABLE.  A legacy block in id_us_2.c disabled
   configure items 4 and 5 unconditionally -- those were the two "USE
   JOYSTICK #n" rows before the VIDEO card was inserted at index 3.
   After the insertion, index 4 is KEYBOARD, so the key-binding menus
   were disabled outright with nothing to ever re-enable them (nothing
   to do with a controller being connected -- the condition was
   literally `if (true)`).  Deleted rather than renumbered:
   CK_US_UpdateOptionsMenus(), called at the end of that same function,
   already derives the joystick rows' state from IN_JoyPresent().
   Lesson: index-addressed menu tables are the hazard when inserting
   items; grep every literal index after touching a card array.

2. "QUICKSAVE F5 / QUICKLOAD F9" ran past the card frame (147px in a
   138px column).  Captions are drawn in a PROPORTIONAL font, so a
   character budget cannot express "fits"; everything now measures.
   Added CK_US_CardTextLimit(card) (single source of truth for the
   pixel budget: round8(card->x+74)+8 up to the grey bar's right edge at
   75+159) and CK_US_FitCaption(buf,size,limit) (trims with an ellipsis
   by measurement).  The quicksave row falls back through shorter
   wordings before it will ellipsise, since the keys are the thing it
   exists to show: "QUICKSAVE F5 / LOAD F9" (121px) today, and it stays
   inside the frame even with names like BACKSPACE / SCROLL LOCK.
   Also fixed CK_US_SetJoystickName: it truncated by character count
   (28) and its intended "..." was itself cut off by snprintf, so a long
   device name could overflow -- now measured and fitted.

3. AUDIT TOOL: /MENUAUDIT walks every card, measures each caption with
   the real font, and reports width/limit plus any US_IS_Disabled state,
   into menuaudit.txt (stdout is dead in a windowed build).  It also
   checks worst cases the live values can't show (long key names, long
   pad names), and refuses to report if the font failed to load, since
   unloaded fonts measure zero and would "pass" everything.  Report:
   verify/menu_text_audit.txt.  Result: 0 overflows across every card in
   episodes 4 and 5, worst cases included.  Savegame names are bounded
   by design (US_LineInput caps the field at 138px).

   EPISODE 6 COULD NOT BE MEASURED: rt\ has Keen 6 game data (AUDIO,
   EGAGRAPH, GAMEMAPS, CONFIG) but none of Omnispeak's per-version
   definition files, so it quits on EPISODE.CK6.  Staging keen6e15 gives
   "invalid chunk"; keen6e14 loads but the menu font chunk comes back
   empty (audit reports FONT NOT LOADED).  So the earlier note claiming
   Keen 6 ran here does not reproduce -- Keen 6 needs its own data
   session.  Menu text is shared C code and the ep4/ep5 measurements are
   identical to each other, so the audit conclusions carry over once the
   data loads.

Sim parity re-verified after these changes: verify/run_verify.ps1 ALL
PASS (4 demos, bit-identical).  Deployed to rt\omnispeak-wide.exe.


## Keen 6: DOSBox routing (2026-07-25)

Keen 6 is the one slot that cannot use the native engine.  The user's copy
is the v1.0 release (data files dated 15 Nov 1991; KeenWiki dates v1.0 to
Nov 1991, v1.4 to Feb 1992, v1.5 to May 1993), and Omnispeak reads only
v1.4/v1.5.  Proof it is not corruption: the Desktop copy is byte-identical
to the staged one, and v1.4/v1.5's own chunk tables expect an EGAGRAPH of
~464,726 bytes against the actual 457,309 (GAMEMAPS likewise 78 bytes
short; AUDIO matches exactly, being unchanged across versions).

The community v1.0->v1.4 patch (6keen14.exe) was investigated with the
user's approval and REJECTED on evidence, not vibes: every original host
is dead, the surviving copy's PE links to 2002-03-15 (a decade after the
game, so not a FormGen-era artifact), it is unsigned with an empty version
resource, and its 393KB payload is a proprietary blob 7-Zip cannot open
that works by dropping _upd<N>.exe in TEMP and running it -- i.e. it
cannot be applied without executing an unverifiable binary.  Defender
reports it clean and the payload is probably genuine, but the community
itself is split on its provenance ("legit or some fanmade hack?") and the
archivist states he cannot verify authenticity or safety.  Not worth an
unbounded risk for one slot when a zero-risk route exists.  The file sits
unexecuted in keen6patch/ and scratchpad/.

SO: slot 6 runs under DOSBox, and the launcher shell should shell out to
keen6/play-keen6.ps1 for it while using the native exes for 1-5, making
the difference invisible to the player.  Files:
  keen6/game/        clean copy of the v1.0 data + KEEN6C.EXE
  keen6/keen6.conf   DOSBox Staging config
  keen6/play-keen6.ps1  launcher (prefers the Staging 0.82.2 build bundled
                     with DOSDECK at F:\TurboDOS\src-tauri\dosbox, falls
                     back to an installed DOSBox 0.74)

Config choices: glshader = interpolation/nearest (crisp pixels, same rule
as the native builds -- switch to crt-auto if the scanline look is ever
wanted), machine = vga (runs EGA modes correctly without SVGA quirks;
DOSDECK uses svga_s3 only because its library spans later games),
joysticktype = auto for controller play, aspect/integer_scaling = auto.
Key names were taken from the bundled build's own generated config rather
than guessed, since 0.82 renamed several.

VERIFIED: DOSBox log shows "EGA 320x200 16-colour graphics mode 0Dh at
70.086 Hz ... 1:1.2 (5:6) pixel aspect" -- the game reaches its real
graphics mode, which also proves KEEN6C.EXE is EGA-capable despite the
"C" in its name.  Takes ~20s from mount to graphics (game's own loading).

NEXT (native support, task #25): extract v1.0's tables from the user's own
KEEN6C.EXE -- no downloads, nothing of theirs modified.  Groundwork done:
the exe is LZEXE 0.91 packed (LZ91 at 0x1C), 32-byte header, compressed
image at 0x20..0x18d10 (101,616 bytes), decompressor stub at 0x18d10
(cs=0x18cf ip=0xe).  Needs an unlzexe pass, then the tables are
self-identifying: EGAHEAD = 5,561 monotonic 3-byte offsets ending exactly
at 457,309; EGADICT = 1,024-byte Huffman table (validate by decompressing
a chunk); MAPHEAD = 0xABCD tag + int32 offsets ending near 95,421.  The
uncertain part stays GFXINFOE/TILEINFO/ACTION/STRINGS, since ACTION is an
index-mapped struct table that may differ in v1.0 -- which is what
upstream's "will likely crash" warning is really about.

### Keen 6 v1.0 native support: tables extracted, numbering still open

Progress on the safe path (nothing downloaded but readable source, nothing
of the user's data modified):

1. LZEXE unpack.  My own port (tools/unlzexe.py) parses the header
   correctly -- it computes the same compressed-data start as the reference
   (0x20), confirming the info block at (cs+hdr_paras)<<4 = 0x18d10 and
   inf[4]=0x18cf paragraphs -- but its bitstream loop still trips on a
   spurious end-marker at 286 bytes.  Marked INCOMPLETE in the file so it
   can't mislead.  The canonical unlzexe.c (github.com/mywave82/unlzexe)
   was fetched, READ, and compiled with MSVC instead (needs
   -Dstrcasecmp=_stricmp), unpacking KEEN6C.EXE to 266,032 bytes.  Reading
   it also found my likely bug class: the C version copies out of a static
   (zero-filled) window, so back-references reaching before the start of
   the output legitimately yield zeros rather than being an error.

2. Tables located and VALIDATED (tools/find_keen_tables.py,
   tools/extract_keen6_v10.py).  EGAHEAD at 0x22720, EGADICT at 0x26d32,
   MAPHEAD at 0x26850.  The proof is not 'it looked plausible': EVERY one
   of the 19 non-empty chunks among the first 40 decompresses to EXACTLY
   the expanded length that chunk declares in its own header.  A wrong
   Huffman tree or wrong offsets cannot do that.  EGAHEAD also has exactly
   5,561 entries -- the same count as v1.4 -- ending precisely at 457,309,
   and its offsets track v1.4's structure one-for-one (0,93,105,3587,4821
   against 0,93,105,3583,4817).  MAPHEAD's 19 level offsets top out at
   95,379, inside the real 95,421 file, where v1.4's table demanded 95,499.
   Watch out: a raw scan reports EGAHEAD at 0x22717 because three leading
   zero entries are also monotonic; 0x22720 is the paragraph-aligned start
   that gives the matching entry count.

3. STILL BLOCKED, and on exactly the risk called out in advance.  With
   keen6e10 staged (keen6e14's set plus the three v1.0 tables), Omnispeak
   still reports FONT NOT LOADED, and scanning the first 40 chunks finds no
   id font structure anywhere.  Since decompression is proven, the reading
   is that v1.0 NUMBERS its chunks differently, so keen6e14's GFXCHUNK.CK6
   (FON_MAINFONT = 3) and GFXINFOE.CK6 are wrong here.  Supporting hint:
   GFXINFOE's word at +0x14 is 0x15AE = 5550 against EGAHEAD's 5,561.

   Next: scan all 5,561 chunks for the font structure to pin the numbering
   offset, extract v1.0's GFXINFOE from the unpacked image, rebuild
   GFXCHUNK, then re-test -- the FONT NOT LOADED guard added to /MENUAUDIT
   is the fast pass/fail signal.  ACTION/STRINGS/TILEINFO compatibility
   remains unknown after that, which is what upstream's "will likely
   crash" warning is really about.  DOSBox routing stays the answer for
   slot 6 unless and until this lands.

### Keen 6 v1.0 RUNS NATIVELY (2026-07-25)

Solved.  Keen 6 now uses the same native engine as 1-5, so it gets
widescreen, interpolation and the native menus.  DOSBox routing
(keen6/play-keen6.ps1) stays as a working fallback but is no longer the
plan for slot 6.

WHAT THE BLOCKER ACTUALLY WAS -- and a lesson about validation.  The
chunk numbering was never wrong; my Huffman dictionary was, and my test
could not tell.  The first check only compared the decompressed SIZE
against the length each chunk declares, which is close to worthless: the
expander stops the moment it has produced that many bytes, so ANY tree
that avoids an invalid node index 'passes'.  That false positive (a table
at 0x26d32) produced 19/19 'exact' matches and sent me looking for a
numbering difference that did not exist.  The honest test is that a
correct tree finishes the output exactly as the compressed input runs
out.  Adding that condition immediately found the real dictionary at
0x38912 -- which decodes chunk 4 consuming 905/905 bytes and yields a
structurally valid font (height 7, ascending glyph table, sane widths).
If a check cannot fail, it is not evidence.

Final table locations in the unpacked KEEN6C.EXE image:
  EGAHEAD  0x22720   5,561 offsets, last == 457,309 (EGAGRAPH size)
  EGADICT  0x38912   1,024 bytes (256 nodes; head is node 254)
  MAPHEAD  0x26850   0xABCD tag, 19 level offsets, max 95,379
Everything else in omnispeak/data/keen6e10/ is keen6e14's, unchanged --
so v1.0 differs from v1.4 ONLY in those three tables.  Audio is already
byte-identical between versions, and GFXCHUNK/GFXINFOE/ACTION/STRINGS/
TILEINFO turned out to be compatible as-is, which is why upstream's
"will likely crash" warning did not bite.

Note the trap for anyone redoing this: a raw scan reports EGAHEAD at
0x22717 because three leading zero entries are also monotonic.  The true
start is the paragraph-aligned 0x22720, which yields exactly 5,561
entries -- the same count as v1.4.

VERIFIED, from rt/ (the launcher's runtime folder):
  * /MENUAUDIT for episode 6: font loads, real measurements, 0 captions
    overflow, KEYBOARD enabled -- ep6 now covered by the audit like 4/5.
  * Keen 6's own demo 0 replays 730 frames through the sim with per-frame
    state checksums and exits cleanly, bit-identical across runs.  Saved
    as verify/baselines/keen6_v10_demo0.txt.  That exercises map loading,
    entity behaviour and the action tables, not just graphics.

Tools (F:\KeenLauncher	ools): find_keen_tables.py (self-validating
locator), find_egadict.py (dictionary search with the consumption test),
extract_keen6_v10.py (extract + validate; refuses a dictionary that does
not consume its input and yield a font).  unlzexe.py is my own port and
is INCOMPLETE -- the unpack was done with the canonical unlzexe.c
(github.com/mywave82/unlzexe) compiled with MSVC.

## 1-3 parity: framed letterbox backdrop (2026-07-25)

Keen 1-3 letterboxed to plain black while 4-6 had the tiled backdrop.
Closed that gap, same idea as the 4-6 build: fill the bars with a pattern
drawn from the EPISODE'S OWN tileset (so it themes itself for free) and
bevel the picture's edge.  The pattern is rebuilt whenever the palette
changes, so it darkens through fades with everything else -- black during
a fade to black, by design.

Picking the tile by eye was a mistake worth recording: tile 1 is a bright
cyan hatch that completely fights the game.  Added K13_TILESHEET=<first>,
which dumps a 16x16 contact sheet of the episode's tiles, then scored
every tile for mean luminance and standard deviation and took the dark,
lightly-textured ones.  That picked the STARFIELD tiles -- dark with
sparse sparkle, and thematically right for Keen.  Defaults: ep1 and ep2
tile 75, ep3 tile 38 (the same art at a different index; all three score
an identical mean 5.4 / sd 27.2, which is how they were identified).

One refinement: a single tile repeated every 16px reads as wallpaper and
the eye locks onto the grid.  The 4x4-tile patch now places the tile in
only 5 of its 16 cells and leaves the rest black, so the period is 64px
with irregular content and it reads as a starfield.

Config: 'backdrop=<tile>' in KEENLNCH.CFG (-1 for black bars), overridable
with K13_BACKDROP for experimenting.  Matches 4-6, where the backdrop is
likewise a config knob ('backdropTile') rather than a menu row.

Also added K13_TEST_WINSHOT=<ms>, which reads the whole window back
before the swap -- the earlier K13_TEST_SHOT only dumped the game buffer,
so it could not see the bars or the frame at all.

VERIFIED: window captures for ep1 (world map, bars top/bottom) and ep3
(space map) in port/captures/backdrop_ep*.png; replay baseline still
REPLAY OK (741 frames); all three episodes rebuilt and staged.

REMAINING 1-3 vs 4-6 GAPS: attract demos on the title loop (4-6 plays
them; 1-3 has no DEMO files in the Steam data, so they would have to be
recorded with the replay harness), quicksave/quickload (4-6 has F5/F9
plus a confirm toggle; 1-3 only has the original F5 save menu), and
replay baselines for Keen 2/3 (only Keen 1 has one).

### Frame thickened to match 4-6, and 1-3 now has a full regression gate

FRAME: the 1-3 bevel was a thin 1-2px line; it is now the same five-layer
chunky pixel-art frame the 4-6 build draws (ported from
VL_SDL2_DrawBackdropAndFrame so the halves are identical): black seam
hugging the art, 2px inset bevel (dark top-left / bright bottom-right, so
the picture reads as sunken), 4px flat brown face, 2px raised outer bevel
(bright top-left / dark bottom-right), 1px black outline -- 10 game pixels
per side, each layer a whole number of on-screen game pixels so it scales
with the display and stays crisp.  Verified by measuring a vertical scan
of the window capture: 000000 x2, ffff55 x4, aa5500 x8, 555555 x4,
000000 x2 at scale 2 -- exactly the intended layer widths.

BASELINES: Keen 2 and Keen 3 had no regression net (only Keen 1 did).
Recorded both by driving the synthetic pad (K13_PADSYN walks Keen right,
and the recorder captures the resulting ControlStruct, so pad-driven
movement is replayable): baseline_keen2.k13r (589 frames),
baseline_keen3.k13r (596 frames).  Both replay clean.

keen13/verify/run_verify.ps1 now gates all three episodes in one command,
mirroring the 4-6 runner.  Note it must set
$PSNativeCommandUseErrorActionPreference = $false and drop to
ErrorActionPreference=Continue around the call: the verdict comes out on
stderr, which PowerShell otherwise treats as a terminating error and the
run aborts before the result can be read.

  Keen 1 : PASS (741 frames)
  Keen 2 : PASS (589 frames)
  Keen 3 : PASS (596 frames)

### Frame fix for 2/3, and what in-level quicksave would take

BUILD LESSON: episodes 2 and 3 shipped with the old thin bevel because
only -t:keen13 was rebuilt after the frame change.  Rebuild ALL THREE
targets after any shared-code edit; the three exes are separate builds of
the same sources.  Fixed and confirmed by pixel scan in each episode
(ffff55 x4, aa5500 x8, 555555 x4, 000000 x2 at scale 2 -- identical to
ep1).  The three-episode gate still passes, which also proves the frame
work was presentation-only: those baselines were recorded with the older
executables.

IN-LEVEL QUICKSAVE -- feasible, and smaller than feared.  Keen 1-3 can
only save on the world map because gamestate holds world position and
nothing about the level in progress.  Lifting that means a new port-only
save file (the DOS SAVED<1-9>.CK<ep> format cannot express it, and those
must stay byte-identical -- they were verified against real DOS saves).

The useful discovery is that WE ALREADY HAVE THE SPEC.  k13_state_hashes()
in idlib13.c, written for the replay harness, enumerates exactly what
constitutes simulation state: objlist, pobjlist, numobj, gamestate,
originx/originy, level, and the RNG (index + RndArray + indexi/indexj).
Serialise that set and the save is complete by construction.

The only hard part is function pointers, and it was measured rather than
guessed: objtype holds exactly two (think, contact) and pobjtype one
(think).  Distinct functions actually assigned: 52 in ep1 (40 think + 12
contact), ~53 in ep2, ~65 in ep3.  So a ~50-65 entry registry per episode,
best generated from the *ACT.C sources into a table of { name, pointer }
pairs -- save maps pointer to index, load maps back, and an unrecognised
pointer must fail loudly at save time instead of corrupting a file.
pobjs need no registry at all: pobjtype carries a `type` field with only
12 values, so their think pointer can be rebuilt from a small switch.

Two further findings that shrink the job: no mapplane[0][...] writes exist
in KEENACTS.C, so the map is not mutated during play (doors and bridges
are pobjs drawn over it) and needs no saving -- worth confirming across
the other *ACT.C files before relying on it; and the resume path can just
load the level normally, then overwrite the hashed state and force a
refresh.  The risk to watch is a spawn-time side effect that the hash does
not cover.

Best part: the harness verifies it.  Quicksave at frame N of a replay,
quickload, and assert the seven component hashes still match the recording
-- a pass/fail test rather than a hopeful playthrough.

## In-level quicksave for 1-3 (2026-07-25)

The original can only save on the world map, because its save file holds
gamestate -- inventory and world position -- and nothing about a level in
progress.  Quicksave now captures the whole simulation, so a level can be
resumed exactly.  The DOS-compatible SAVED1..9.CKx files are untouched;
this is a separate QUICKSAV.CKx that only this port reads.

WHAT IS SAVED came straight from k13_state_hashes(), the replay harness's
state hash: objlist, pobjlist, numobj, gamestate, originx/originy, level
and the RNG.  Using the hash as the specification means the save is
complete by construction -- and the same function then verifies it.

Objects hold RAW FUNCTION POINTERS (think, contact) rather than indices
into an action table the way Keen 4-6 does, so there is nothing stable to
write down.  k13_thinktable.inc is a generated registry of { name,
pointer } pairs -- 49 entries for ep1, 48 for ep2, 61 for ep3 -- and the
saver turns a pointer into an index, the loader turns it back.  An
unrecognised pointer ABORTS THE SAVE rather than writing a file that
would crash on load.

Two corrections to earlier assumptions, both caught by checking:
  * pobjs need the registry too.  The guess that their think could be
    rebuilt from the `type` field is wrong -- POBJ_BRIDGE runs
    BridgeCreate, BridgeRemove or NullPThink depending on where it is in
    its cycle, so the type says nothing about current behaviour.
  * the generator cannot regex raw source.  KEENACTS.C is full of
    '#if (EPISODE == n)' blocks, so a text scan collected other episodes'
    functions and the table failed to link on 'FoobWalk', a Keen 2 enemy,
    in the Keen 1 build.  gen_thinktable.py now runs each file through
    cl /EP with that episode's defines and scans the preprocessed output.
    Counts dropped from 52/53/65 to 49/48/61 once the conditionals were
    resolved -- the earlier numbers were partly other episodes' code.

Also saved, though NOT part of the state hash: pobjcount, lastdir,
LevelDone, cheatmode, ankhtime, timecount, lasttimecount.  These are the
level-scoped globals LevelLoop resets on entry; a restored level is wrong
without them (pobjcount decides where the next door is allocated, lastdir
which way Keen shoots).  That is a gap in the harness's hash, not in the
simulation -- worth closing there too.

VERIFIED with a self-test that could not pass by accident: K13_QS_TEST=<n>
quicksaves at that replay frame, ZEROES objlist/pobjlist/gamestate/origin,
quickloads, and compares all seven component hashes.  PASS on 9 of 9 runs
-- three episodes x three frames each (60, 300, and near the end of each
recording).  Wiping first is the point: a loader that quietly did nothing
would otherwise look correct.  Three-episode gate still ALL PASS.

KEYS: F7 quicksaves, F9 quickloads.  F5 is already the save MENU in 1-3
(unlike 4-6, where F5 is quicksave), so the pair moved to the next free
keys, keeping F9 the same as 4-6.

REMAINING LIMITATION, stated plainly in-game rather than half-handled:
quickloading a DIFFERENT level than the one being played needs the level
dispatcher to exit and re-enter LevelLoop with a restore pending (the hook
belongs right after LoadLevel and the origin clamp, before the main loop).
Until that is wired, F9 restores only within the current level and says
"That quicksave is for another level" otherwise -- so reloading after a
death, which leaves the level, is not covered yet.

### Quicksave finished: cross-level restore + confirmation prompt

CROSS-LEVEL RESTORE.  F9 now works after a death, which is when anyone
actually reaches for it.  Dying returns Keen to the world map, and that is
the whole hook: if a quickload is pending, the world map loop steers
LevelNumber to the saved level, so its existing 'Keen is entering a level'
path runs, and LevelLoop applies the saved state after LoadLevel and before
the play loop (the non-restore branch keeps the usual centre-on-Keen camera;
a restore brings its own).  The leveldone check is bypassed while a restore
is pending, since the save's own completion flags arrive with it.  Three
small hooks, all K13_PORT-fenced: KEENDEMO.C (steer + bypass) and KEENACTS.C
(apply).

CONFIRMATION PROMPT, at the user's request and matching 4-6's
'CONFIRM QUICKSAVE' toggle.  The reasoning is sound and worth writing down:
with these actions on a controller it is easy to knock one by accident, and
an accidental LOAD is unrecoverable -- it destroys the run you were having.
So both F7 and F9 ask first, on by default, toggleable in Options and
persisted as 'qsconfirm' in KEENLNCH.CFG.

K13_Confirm() uses the game's own '(Y/N)' idiom, and deliberately ALSO
accepts Enter and Escape: a pad cannot send a letter, and
k13_pad_menu_edges turns its buttons into Enter/Escape -- so the guard
would otherwise be unanswerable in exactly the couch-play case that
motivated it.

Options grew two rows: 'Confirm quicksv ON/OFF' and an informational
'Quicksave F7/F9' so the keys are discoverable.  The first attempt clipped
('CONFIRM QUICKSON') because the value column sat at +17 and the label is 18
characters -- the same class of bug the 4-6 menu audit exists to catch.
Fixed by moving the value column to +19 rather than truncating the label;
1-3's font is fixed-width, so a character count settles it (unlike 4-6,
where the proportional font has to be measured).

KEYS: F7 quicksave, F9 quickload.  F5 remains the original save MENU.

VERIFIED: three-episode gate ALL PASS (741/589/596); quicksave roundtrip
self-test PASS on all three episodes; the prompt and the corrected Options
screen captured in port/captures/.

### Multi-bind per pad action + reset to defaults

Single binding per action was a regression I introduced: the old fixed
layout let EITHER shoulder jump and EITHER trigger fire, and making the
controls customisable quietly took that away.  Each action now has two
slots -- slot 0 the face button, slot 1 a shoulder or trigger -- so
customisation and the convenience can coexist.  Defaults: jump A+RB, pogo
B+LB, fire X+R-TRIG, status Y+BACK.

Binding a pad action prompts twice: the primary, then "Alternate,
ESC=none", so the two-slot idea is discoverable without extra menu rows.
Values render as "A+RB", and the Controls screen gained a "Reset to
defaults" row that reuses the same K13_Confirm() guard as quicksave.

KEENLNCH.CFG's bind line carries nine values now (four actions x two slots,
plus the keyboard fire key).  The loader still accepts the older five-value
form, treating each as a primary with no alternate, so existing configs are
not silently reset.

VERIFIED: config round-trips as 'bind=0,10,1,9,2,101,3,4,42'; three-episode
gate ALL PASS; quicksave self-test still PASS; screen captured in
port/captures/controls_multibind.png.

Note for future edits in k13_compositor.inc: replacing a whole block by
index is risky in that file because the config globals and their accessors
are interleaved -- doing so here silently removed k13_qsconfirm and
k13_backdrop and left stale single-slot accessors behind, which only the
compiler caught.  Prefer targeted edits.

REMAINING 1-3 vs 4-6 GAP: attract demos on the title loop.  4-6 plays the
game's own DEMO chunks; the Steam 1-3 data has none, so they have to be
recorded with K13_RECORD (K13_PADSYN gives reproducible movement) and
played back on the title screen, with a DEMO sign overlay like 4-6's.

### Attract demos: NOT DOING, on authenticity grounds (2026-07-25)

Checked the reconstruction rather than assuming.  The findings:

  * The demo MECHANISM is original to Keen 1-3.  IDLIBC.C has
    RecordDemo(), LoadDemo(), SaveDemo(), a 5002-byte demobuffer, and
    IDLIB.H's inputtype includes 'demo' alongside keyboard and joystick,
    with enum demoenum { notdemo, demoplay, recording }.  This is the
    plumbing the Galaxy engine later shipped demos with.

  * But the shipped game NEVER CALLS IT.  Grepping every game TU for
    LoadDemo / SaveDemo / demoplay call sites returns nothing.  At retail
    v1.31 the demo system is dead code -- id's internal recording tooling,
    left in the binary.  No DEMO<n>.CK<ep> files ship either, which is
    consistent.

  * Keen 1-3 already HAS an attract mode, just a different one: the loop
    pans the TITLEMAP between the Apogee screen, the title, the high
    scores and the ordering info, waiting SCREENTIME (2400 tics, ~17s) on
    each.  That is the authentic 1-3 attract experience, and it works.

So this was never a parity GAP -- 4-6 and 1-3 shipped different attract
modes, and both are present and correct.  Recording our own demos would
mean authoring content id never shipped and waking code the retail game
never ran.  User's call, and the right one: authenticity wins.  Closed.

(If it is ever wanted anyway, everything needed is in place: RecordDemo /
LoadDemo in the engine, plus K13_RECORD and K13_PADSYN in the harness.
The one wrinkle noted earlier still applies -- the replay path exits the
process at trace end and would need a non-exiting mode.)

WITH THIS CLOSED, 1-3 IS AT FEATURE PARITY WITH 4-6.  What is left is
polish, not parity: broader Keen 1 baselines, DOSBox cross-validation
spot-checks, the DOS exit screen, speaker volume, a Modern Sounds toggle,
stripping the env-gated debug traces for release, and the 7-slot launcher
shell itself (all six games now run natively).

## Launcher shell: first light (2026-07-25)

Built in C + SDL2 at launcher/, with NO new dependencies -- the network was
blocked when this was written (router curfew, which is also what the earlier
TLS revocation errors turned out to be), so this deliberately uses only what
was already vendored.  No ImGui: the design notes reserve it for "if used at
all", and a modern widget toolkit would look foreign against the games.

LOOKS LIKE IT BELONGS.  426x240 EGA-proportioned canvas scaled with hard
pixels, the 16-colour EGA palette, the same five-layer bevel the games draw
around their artwork, and the same scattered-starfield trick as the letterbox
backdrop.  The shell reads as part of the collection instead of a wrapper.

TEXT: launcher/gen_font.py bakes a 8x12 1-bit font into launcher_font.h from
a system monospace face with antialiasing off.  Baked rather than loaded so
there is no font library at runtime, and taken from a SYSTEM font rather than
the games' own so no id artwork is redistributed.  8x8 was tried first and
was too cramped (glyphs used five of eight rows).

SLOTS ARE TABLE DRIVEN AND SELF-DETECTING.  Each entry names a working
directory, an executable, arguments, and one data file that must exist; a
slot counts as playable only when BOTH its runtime and its data are found,
since claiming "ready" and then failing to start is worse than dimming it.
Unavailable games stay VISIBLE as "COMING SOON" so the collection always
reads as seven.  This is what makes Keen Dreams click into place with no code
change: drop the runtime and data into keendreams/game/ and detect() lights
slot 7 on the next start.  Detection re-runs after every game exits, so
installing something while the launcher is open is picked up too.

LAUNCHING: CreateProcess with the game's own folder as the working directory
(they resolve data, config and saves relative to it), and the launcher waits
rather than racing the game for the screen and the gamepad, so quitting a
game lands back on the shell.

COUCH-FIRST: d-pad/stick and A/Start navigate and launch, B/Back quits, and
the keyboard mirrors all of it.  Controllers hot-plug.

Layout bugs found and fixed by looking at captures rather than trusting the
arithmetic: tiles overflowed the right edge because the bevel's 6px per side
was not counted; "NOT INSTALLED" was invisible (grey text on the grey dim
fill); and the hint line collided with row two.  The last row now centres.

KEEN_SHOT=<file> renders one frame to a PPM and exits (KEEN_SHOT_SEL picks
the highlighted slot) -- that is how the layout was reviewed here.
Captures: launcher/captures/.

NEXT on the shell: per-game cover art (the tiles are currently text on a
colour), a first-run path check with a friendly message when a game's data is
missing, remembering the last played slot, and wiring slot 7 once Keen Dreams
has a runtime.

### Launcher: resize fixed properly, and all six verified launching

RESIZE.  The window stretched one fixed 426x240 canvas to fill whatever
shape it was given, so everything warped.  Letterboxing would have removed
the warp but wasted space and put bars around a starfield, which is not much
better.  The elegant answer was to stop treating the canvas as fixed: the
pixel scale is now always a WHOLE NUMBER (so pixels stay hard and are never
resampled) and the LOGICAL canvas is simply the window divided by that scale.
A wide window therefore gets a wider canvas, a tall one a taller canvas, and
the tile grid re-centres into whatever it is handed -- the UI is responsive
rather than scaled.  Starfield density follows the area so a big window does
not look sparse, and the two tile rows centre vertically between the title
and the footer.  Any leftover is at most a scale-1 sliver of black.

Verified at three shapes with KEEN_SHOT_SIZE=WxH (which fakes a window size
for the one-frame dump): 1278x720 -> 426x240 logical, 1920x820 -> 640x273,
1000x1200 -> 500x600.  No stretching in any of them; captures in
launcher/captures/resize_*.png.

ALL SIX GAMES VERIFIED LAUNCHING, using the exact command lines and working
directories the launcher uses: Keen 1-3 via their own exes in gamedata*,
Keen 4-6 via omnispeak-wide.exe /EPISODE n in rt.  Each started and was
still alive after seven seconds.

STILL TO DO -- per-game artwork on the tiles.  Plan, so it stays elegant
rather than turning the launcher into a second copy of two graphics engines:
a small offline extractor writes ONE preview image per game into
launcher/art/<slot>.ppm, taken from the USER'S OWN data (nothing shipped,
nothing redistributed), and the launcher simply draws that file if it is
there and falls back to the coloured text tile if it is not.  Both halves are
already solved elsewhere in this project: Keen 4-6 graphics are
EGAGRAPH + EGAHEAD + EGADICT, and the Huffman expander plus the planar-to-RGB
conversion were written for the Keen 6 v1.0 work (tools/extract_keen6_v10.py,
tools/find_egadict.py); Keen 1-3 tiles come out of EGALATCH.CK<n>, which the
port already rasterises for its K13_TILESHEET dump.  So the extractor is
mostly assembly of existing, tested pieces.

### Fullscreen by default, everywhere (2026-07-25)

The whole session now starts fullscreen -- launcher and all six games -- so
nothing flashes a window on the way into or out of a game on a TV.

  * Launcher: created with SDL_WINDOW_FULLSCREEN_DESKTOP.  "-windowed"
    (or KEEN_WINDOWED=1) forces a window, F11 still toggles.
  * Keen 1-3: fullscreen is now a REMEMBERED setting (k13_fullscreen,
    default on) written to KEENLNCH.CFG, applied after the config load so a
    saved preference wins over the default.  The Options row already toggled
    live; it now also stores the choice, so the next launch matches what you
    left.  K13_WINDOWED=1 forces a window for development.
  * Keen 4-6: the "fullscreen" config default flipped from false to true,
    and a /WINDOWED parm was added as the counterpart to the existing
    /FULLSCREEN.  An explicit line in OMNISPK.CFG still wins (there is none
    in rt/, so the new default applies).
  * Keen 6 under DOSBox (the fallback path) was already fullscreen = true.

VERIFIED by measuring real window rectangles against the desktop rather than
trusting the flags: on the 3840x2160 display the launcher, Keen 1 and Keen 4
all come up at full desktop size, and each escape hatch drops back to a
window (2912 / 2106 / 2188 px wide respectively).  Worth having those
hatches: if fullscreen ever misbehaves on a particular display there needs to
be a way back that does not involve editing a config blind.

Both simulation gates re-run clean afterwards -- Keen 1-3 741/589/596 frames,
Keen 4-6 all four demos bit-identical -- confirming this was presentation
only, even though it touched each engine's startup path.

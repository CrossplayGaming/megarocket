# Handoff: Commander Keen collection project — and a research question

Paste this into a fresh chat (on a connection that can reach the web) and then ask
the research question at the bottom. Everything above it is context so the answer
lands in the right place.

---

## What the project is

A personal, single-user collection that makes all seven Commander Keen games
playable on a 4K TV from the couch, with modern comfort features, while keeping
the simulation **bug-for-bug identical to DOS**. It runs from the user's own
legally-owned game data; no game assets are redistributed.

Two engines are involved, both open source (GPLv2):

- **Keen 1-3** ("Vorticons" engine) — a native port built on K1n9_Duk3's GPL
  source reconstruction, with a custom SDL2 platform layer replacing the DOS/EGA
  assembly.
- **Keen 4-6** ("Galaxy" engine) — Omnispeak, an open reimplementation.
- **Keen Dreams** (the transitional engine between those two) is next, via
  **refkeen / ReflectionHLE**, a GPLv2 source port of the official Keen Dreams
  GPL release.
- **Keen 6** additionally needed custom work: the owner's copy is v1.0, which
  Omnispeak doesn't support, so its graphics/map tables were extracted from the
  original LZEXE-packed executable to make it load.

## The quality-of-life stack that now exists

This is the thing worth reusing elsewhere. All of it was built and verified over
the past sessions:

- **Widescreen (16:9)** without distorting anything — the render buffer is
  widened and the camera origin shifted, rather than stretching a 4:3 image.
  Slides at map edges so border tiles never show.
- **High-refresh smooth motion** — the simulation still ticks at the original
  fixed rate, but the camera and every sprite are interpolated between sim
  frames at present time, so it's fluid on a 120Hz display.
- **Crisp pixels always** — no filtering, antialiasing or blurry upscaling
  anywhere; smoothness comes from placement and timing only.
- **Framed letterbox backdrop** — leftover screen area is filled with a pattern
  drawn from that episode's own tileset plus a chunky pixel-art bevel, instead
  of black bars.
- **Native-looking settings menus** — new options are added inside each game's
  original menu system so they look like id shipped them.
- **Controller-first** — full gamepad play and navigation, rebindable with two
  bindings per action, never needing a keyboard.
- **Quicksave/quickload**, including mid-level saves in Keen 1-3, which the
  original engine couldn't do.
- **A regression harness** that replays recorded input and compares per-frame
  simulation state hashes, proving each change touched only presentation and not
  the game logic.
- **A launcher shell** fronting all seven games, styled to match them.

## Why engine architecture is the crux of the question

The widescreen and interpolation work keys off the **RF tile-refresh
architecture** that id used in the Keen games. Any other game built on that same
architecture could inherit most of the stack fairly directly. A game built on a
*raycaster* (Wolfenstein-style) can't — there, "widescreen" means field-of-view
work instead, which is a different job.

So the useful question isn't "what else did id make", it's "**what else runs the
Keen tile-refresh engines, and is there open source for it**".

## What has already been established (offline, so partly unverified)

Determined by reading refkeen's own README and grepping the Keen 1-3
reconstruction source:

- **Bio Menace** (Apogee, Jim Norwood, 1993) reportedly runs the **Keen Galaxy
  engine licensed from id**, and **refkeen already ships a GPLv2 port of it**
  ("Reflection BioMenace", listed in its README). If true, this is the standout
  candidate: same architecture, source already ported.
- **refkeen also covers** Keen Dreams, Catacomb 3-D, The Catacomb Adventure
  Series, and Wolfenstein 3D — but the Catacomb/Wolf titles are raycasters, so
  only partially relevant.
- **Shadow Knights** is very likely the same Vorticons-era codebase: the Keen 1-3
  reconstruction's own comments note it "uses something very similar" to Keen's
  `pobjtype` struct and even shares the error string "PObj list overflow!".
- Other id-for-Softdisk / Gamer's Edge games of that era — Dangerous Dave in the
  Haunted Mansion, Rescue Rover 1 and 2, Slordax — are the same lineage, but no
  public source is known.

**Not verified:** Bio Menace's actual licensing history, what engine Monster Bash
really uses, and whether any source exists for the Softdisk-era titles.

---

## The research question

**Did id Software license out any of the Commander Keen engines, such that other
games exist which could receive the same quality-of-life treatment described
above?**

Specifically:

1. Which commercially released games ran the **Keen Vorticons** engine (Keen 1-3)
   or the **Keen Galaxy** engine (Keen 4-6), whether by id itself, by licensees,
   or under contract (e.g. Apogee, Softdisk / Gamer's Edge)?
2. For **Bio Menace** in particular: confirm the engine lineage and the licensing
   history, its current distribution status (it is believed to be freeware), and
   whether its source or a source port is legitimately available.
3. Is there public source for any of the Softdisk-era id titles — **Shadow
   Knights**, Dangerous Dave in the Haunted Mansion, Rescue Rover 1/2, Slordax?
4. What engine does **Monster Bash** (Apogee, 1993) actually use? It's sometimes
   described as Keen-like.
5. Any *other* Keen-engine-derived games worth knowing about, including
   well-maintained fan reimplementations, and where the game data can still be
   bought or obtained legitimately today.

For each candidate, the useful details are: **which engine**, **is there open
source or an existing source port**, **what licence**, and **how to obtain the
game data legally**. Ranking by "closest to the Keen 4-6 architecture" would be
ideal, since those inherit the existing work most easily.

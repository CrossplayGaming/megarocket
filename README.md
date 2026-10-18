# Megarocket 2.0

All seven Commander Keen games in one program, for Windows and Android: Keen 1, 2 and 3 (*Invasion of
the Vorticons*), Keen 4, 5 and 6 (*Goodbye, Galaxy!* and *Aliens Ate My Baby Sitter!*) and *Keen Dreams*.

Megarocket is a **native port**, not an emulator: each game's code is ported function for function from
its reconstructed source and runs in Godot 4. It is checked against the DOS originals by machine, picture
by picture and frame timing by frame timing, on recorded play sessions. On top of that faithful core it
adds what a modern player expects:

- **Classic or Enhanced.** Classic is the original, pixel for pixel. Enhanced adds native resolution,
  widescreen, smooth motion, quicksave and fixes for the originals' known bugs, each a setting of its own.
- **Controller and touch first.** Every screen works with a gamepad; Android has touch controls.
- **Keen's Closet.** Dress Keen: simple colour looks for his helmet, shirt, pants and shoes (the shading
  kept), or every part in any colour.
- **Asset packs and the Asset Studio.** Swap the games' pictures with your own: pick a sprite, drop a PNG
  on it, export your pack and share it.
- **Keen Maker.** Build your own levels for any of the seven games and play them, Mario Maker style:
  - whole objects (a house, a door, a sign), not the original's pieces;
  - platforms, poles and ramps dragged out to length, ground drawn in each game's own materials with its
    edges and corners fitted, and background patterns painted seamlessly;
  - a door asks for its key or gem, and links itself;
  - each game's own sounds and little animations as you build, a recently used strip, and a short
    first-time tour.

  It is all worked out from your own copies of the games when you open them.

## Your games, not ours

**Megarocket ships no game files.** It finds your Steam or GOG copies, or you point it at a folder. Keen
Maker, Keen's Closet and the Asset Studio read the art, levels and sounds from those copies when you use
them; nothing from the games is stored in this repository.

## Building

- [Godot 4.7.2](https://godotengine.org) with its export templates. The project is in `godot/`.
- The sound chip library (`native/d2opl`, an OPL2 emulation following Nuked OPL3) and the native drawing
  helpers are built by `python tools/build_native.py` (MinGW gcc for Windows, the Android NDK for Android;
  `--linux` builds Linux through WSL). Without the library the games run without AdLib sound.
- Export with the presets in `godot/export_presets.cfg` (Windows Desktop, Android).

## How it is checked

`BUILD_LEDGER.md` lists every piece of work with the check that proves it, and `docs/BLUEPRINT.md` what
must be true. `python tools/regress.py` runs the checks (`fast` or `slow`, or one by name). Most compare
the port with recordings of the DOS originals in DOSBox Staging, made from your own game files (see
`docs/REFERENCES.md`); none of those recordings is in this repository either.

## Credits and licence

Megarocket is free software under the **GNU General Public License, version 2 or later** (`LICENSE.md`).

It stands on the shoulders of:

- **Omnispeak** (David Gow, GPL v2): the reimplementation of Keen 4-6 the Galaxy port
  follows; its game definition files are in `godot/data/omnispeak`.
- **ReflectionHLE** (NY00123, GPL v2), with id Software's released Keen Dreams source: the reference for the
  Dreams port.
- **Reconstructed Commander Keen 1-3 Source Code** (K1n9_Duk3, GPL v2): the reference for the Vorticons
  port.
- **Nuked OPL3** (Nuke.YKT): the measurements of the real sound chip that `d2opl` follows.

Commander Keen is a trademark of id Software. Megarocket is a fan project, not affiliated with or endorsed
by id Software, Apogee or Bethesda.

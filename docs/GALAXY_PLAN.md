# The Galaxy engine port (Keen 4, 5 and 6) — plan

SIM-G-01 in the ledger: the Galaxy engine ported from omnispeak upstream (`omnispeak-ref/src`), running
headless through each episode's built-in demo. This file splits that unit into checkable pieces, fixes the
file order and the conventions, and is the brief for anyone (person or agent) porting a piece.

## What is ported, and from where

| Reference (omnispeak-ref/src) | Lines | Port | Unit |
|---|---|---|---|
| id_mm.c, id_ca.c (over `GalData`), id_vl.c with the DOS back-end id_vl_dos.c, id_vh.c | ~3,500 | `gal_lib.gd` | SIM-G-01a |
| id_rf.c (refresh: tile cache, update blocks, sprites, scrolling) | 1,455 | `gal_rf.gd` | SIM-G-01b |
| id_in.c (input over the machine's keyboard; demo playback/record), id_sd.c (timer, tics, sound queue; no audio out yet), id_us_1.c, id_us_2.c, id_us_textscreen.c, id_str.c, id_cfg.c (as far as the game needs) | ~4,600 | `gal_io.gd`, `gal_us.gd` | SIM-G-01c |
| ck_act.c, ck_phys.c, ck_obj.c, ck_misc.c, ck_map.c | ~3,700 | `gal_act.gd` | SIM-G-01d |
| ck_play.c, ck_keen.c | ~4,600 | `gal_play.gd` | SIM-G-01e |
| ck_main.c, ck_game.c, ck_text.c, ck_inter.c, ck_us_2.c | ~5,900 | `gal_game.gd` | SIM-G-01f |
| ck4_misc.c, ck4_map.c, ck4_obj1-3.c | ~3,100 | `gal_keen4.gd` | SIM-G-01g |
| ck5_*, ck6_* | ~6,800 | `gal_keen5.gd`, `gal_keen6.gd` | SIM-G-01h |

Not ported: every SDL, Vulkan and OpenGL back-end, icon.c, id_fs.c (files come from `GalData`), the OPL
back-ends (audio output is the shell's, AUDIO units), omnispeak's command-line and config-file extras that the
original lacks.

## Unit checks

- **SIM-G-01a (spec).** Every tile (8x8 and 16x16, masked and unmasked), every picture, masked picture and
  sprite (all four shifts) and every font string drawn through the library onto the emulated EGA card reads
  back pixel-identical to `GalData`'s own decode of the same chunk. Fades and palette writes reach the card's
  palette. Test: `godot/tests/simg01a_draw.gd`.
- **SIM-G-01b (spec).** The refresh manager over a loaded map: scrolling in all directions draws the same
  picture as drawing the map's tiles directly at that origin; sprites placed, moved and erased leave the
  background exact; animated tiles step as TILEINFO says.
- **SIM-G-01c (spec).** The 70 Hz tic clock with the original's catch-up rule; demo files from EGAGRAPH play
  their recorded control structures frame by frame; the text window and menu routines draw.
- **SIM-G-01d to h (spec, then oracle).** Each episode's built-in demos run to their end without a script
  error, Keen ending where the demo leaves him. The oracle comparison against DOSBox recordings is REPLAY-G4/5/6.

## Conventions (A10, A2, A11, A13 applied to omnispeak)

1. **One class, many scripts.** `GalLib` (gal_lib.gd) extends `RefCounted`; each later script extends the one
   before, in the table's order: GalLib → GalRF → GalIO → GalUS → GalAct → GalPlay → GalGame → GalKeen4 /
   GalKeen5 / GalKeen6 (each episode class extends GalGame).
2. **Names.** Every function, global and constant keeps omnispeak's name (`CK_PhysUpdateNormalObj`,
   `RF_PlaceSprite`, `ck_gameState`). Static helpers of a C file keep their names too.
3. **Forward calls.** C calls anything anywhere. A function called by a script earlier in the chain than the one
   that defines it is declared in `gal_decl.gd` (a stub with untyped parameters, generated from omnispeak's
   headers by `tools/gen_gal_decl.py`), which sits first in the chain (`GalDecl` → `GalLib` → ...). The
   defining script overrides it; typed overrides of the untyped stubs are fine in Godot 4.7.
4. **Function pointers.** Think, collide and draw functions, and every other function pointer, are
   `StringName`s called with `call()`. The action tables come from omnispeak's ACTION file (already parsed
   by `GalData`); an action's function names resolve to methods by name at load, and a missing method is a
   load error naming it.
5. **Structs.** `CK_object`, `CK_action`, `RF_SpriteDrawEntry` and the like are inner classes with the C
   fields by name and a `copy_from`. Object pointers are references to those instances; the object list
   keeps omnispeak's linked-list order and its free list (the order objects think in is the order they were
   allocated, which the demos depend on).
6. **Arithmetic.** Whole numbers only; `s16()`, `u16()`, `s32()` wrap as Borland C did wherever omnispeak's
   types are 16-bit (`int16_t`, `uint16_t`) and the value can overflow. Division of negative numbers truncates
   toward zero as C does (GDScript `/` on ints does too; `%` too).
7. **Time.** No wall clock. The tic counter is advanced by the machine's timer (`DosMachine`, reprogrammed to
   the original's rate); waits are synchronous against the virtual clock (A11).
8. **Drawing.** Through `EgaCard` only, the way id_vl_dos.c drives the EGA (map mask, write modes, latches,
   CRTC start, panning). The draw list for the modern renderer is emitted from the same calls (later).
9. **Randomness.** `US_RndT` over omnispeak's table, index in state.
10. **State.** Every variable that is game state is a plain member, so `state_snapshot()` (A6/A7) sees it;
    machine and data references are listed in `NOT_STATE`.

## Order of work

SIM-G-01a first (everything draws through it), then b and c, then d-f, then Keen 4's objects (g) to run Keen 4's
demos, then Keen 5 and 6 (h). Each unit's check is written before the unit and joins `tools/regress.py`.

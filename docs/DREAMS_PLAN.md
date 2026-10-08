# The Dreams engine port (Keen Dreams) — plan (draft, 2026-10-08)

SIM-D-01 in the ledger: the Dreams engine ported and running headless through its built-in demos, for the
two supported releases (v1.00 and v1.93, DATA-01D/D2). This is the draft the work starts from; the one
open decision is marked **Decide**.

## The reference

ReflectionHLE's `refkeen/src/kdreams` (GPL v2+): the released Keen Dreams source made portable, with the
assembly (`id_vw_a*.asm`, `id_rf_a.asm`, `id_us_a.asm`) re-expressed in C (`id_vw_a.c`, `id_vw_ac.c`,
`id_vw_ae.c`, `id_rf_a.c`, `id_us_a.c`), and version branches (`refkeen_current_gamever`) for every release
it supports. The port follows it function for function, keeps the branches for v1.00 and v1.93, and drops
what is ReflectionHLE's own: the `kl_*` files (its compositor, quicksave, verify, bind menu),
`altcontroller.c`, `key_scancode_converters.c`, `statetype_ptr_conversion.c` (the port has references), and
the CGA paths (`fakecgamode`; the supported releases are EGA).

| Reference | Lines | Port script (one class, in this order) |
|---|---|---|
| (declarations: structs, constants, shared globals, a stub per function) | — | `drm_decl.gd` (DrmDecl) |
| `BE_ST_*` / `BE_Cross_*`: the machine (EGA writes, CRTC start, palette, timer, speaker, OPL, text mode, files) | — | `drm_be.gd` (DrmBE) over DosMachine/EgaCard |
| id_mm.c, id_ca.c, jam_io.c, lzhuf.c, soft.c | ~4,900 | `drm_ca.gd` |
| id_vw.c, id_vw_a.c, id_vw_ac.c, id_vw_ae.c | ~4,400 | `drm_vw.gd` |
| id_rf.c, id_rf_a.c | ~3,100 | `drm_rf.gd` |
| id_in.c, id_sd.c | ~3,100 | `drm_io.gd` |
| id_us.c, id_us_a.c, id_us_s_kdreams100.c, id_us_s_kdreams192andlater.c, gelib.c | ~4,900 | `drm_us.gd` |
| kd_main.c, kd_demo.c, kd_play.c | ~3,900 | `drm_game.gd` |
| kd_keen.c, kd_act1.c, kd_act2.c | ~5,200 | `drm_acts.gd` (the leaf class `DreamsGame`) |

The declarations script comes first (unlike Galaxy, where it sat after the library): every script then
defines functions only, and none can collide. Units: SIM-D-01a (BE + CA + VW: every picture, tile, sprite
and font draws as DreamsData decodes it), b (RF: scrolling and sprites as SIM-G-01b), c (IN/SD: timer,
keys, demos), d (US: windows, menus, config), e (kd_*: the demos run to their end), then REPLAY-D against
DOSBox recordings of each release.

## Conventions

As docs/GALAXY_PLAN.md (names, forward calls, function pointers as StringNames, structs as inner classes,
wrapping arithmetic, time only through the machine, missing library functions), with these differences:

1. **Generated declarations.** `tools/gen_drm_decl.py` reads the reference's function definitions in id's
   style (the return type on the line before the name; `id0_int_t` and the other `id0_*` types), and
   every global that more than one file uses (272 of 355 by a first scan), into `drm_decl.gd`.
2. **The EGA is the card.** Where ReflectionHLE calls `BE_ST_EGAUpdateGFXByteInPlane` and its relatives,
   the port writes the emulated card's planes through DrmBE, with the map mask, write mode and latches the
   original set (ReflectionHLE skips plane maintenance; the card does it, A3).
3. **Versions.** `refkeen_current_gamever` is a member set from DreamsData's identification; both
   releases' branches are ported.
4. **Memory (Decide).** The original addresses memory by segment and offset; ReflectionHLE keeps
   segment-like buffers with wrapped access (`BE_Cross_Wrapped_*`). Two ways:
   - (a) as the Galaxy port: structs and buffers as Godot objects and arrays, wrapping only where C wraps
     (64 KB buffers kept as PackedByteArrays with wrapped helpers). Faster to write; reads past the end of
     an allocation are guarded, not reproduced.
   - (b) A13 as written: one block of working memory with the original allocator (id_mm), every pointer an
     offset into it. Reproduces out-of-bounds reads exactly; slower to write and to run, and every struct
     access becomes an offset read.
   The Galaxy port took (a) and matches omnispeak on all twelve demos; A13's guarantee is unproven there.
   Recommendation: (a), with A13 amended to "where the original's behaviour depends on it" and each such
   place found by REPLAY-D.

## Order of work

DrmDecl and DrmBE first (by hand, with the generator); then the library scripts in parallel (agents, each
in a worktree, each with its unit's check); then kd_* in two parallel halves; then the demos, compared
first with ReflectionHLE built headless (as galaxy_verify does with omnispeak), then with DOSBox.

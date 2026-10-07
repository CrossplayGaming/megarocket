# Megarocket 2.0

All seven Commander Keen games as one Godot 4 program, for Windows and Android: each original
ported function for function from its reconstructed source, drawn through an emulated EGA card,
proven against the DOS originals by machine comparison; then native resolution, widescreen, smooth
motion, quicksave and gamepad/touch play on top. No original game file ships with it: the program
finds the player's own Steam or GOG copies or lets them point at a folder.

- `docs/BLUEPRINT.md` — what must be true (the coverage matrix). The audit's standard.
- `BUILD_LEDGER.md` — what gets built, in what order, and the check that confirms each piece.
- `docs/REFERENCES.md` — the reference sources, the game files, the oracle.
- `Godot/4.7.2` — the engine build used; `Godot/templates` — export templates.
- `keen13/`, `omnispeak-ref/`, `refkeen/` — reference sources (GPL v2). Not components.

The method is the one used for the Duke Nukem II recreation in `F:\Dropbox\Sidescroller Recomps`.

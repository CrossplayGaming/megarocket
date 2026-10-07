# References

## Reference sources (copied from Megarocket; not components)

| Folder | What | Licence | Role |
|---|---|---|---|
| `keen13/reconstruction` | K1n9_Duk3, *Reconstructed Commander Keen 1-3 Source Code*, 2021–2026. Compiles to the shipped executables; `VERSION` switch covers 1.0–1.31. | GPL v2 | Specification for the Vorticons engine. |
| `keen13/port`, `keen13/verify` | Megarocket's SDL port of the above and its bit-exact replay baselines (`baseline_keen1..3.k13r`). | GPL v2 | Second opinion; replay cases. |
| `omnispeak-ref` | David Gow, *Omnispeak*, upstream. Pixel-perfect, bug-for-bug reimplementation of Keen 4–6 (v1.4 EGA, Keen 6 v1.5 too). | GPL v2 | Specification for the Galaxy engine. Port from **this** copy, not the fork. |
| `omnispeak` | The Megarocket fork (widescreen, smooth motion, audio fixes, art/sound dumps). | GPL v2 | Second opinion only. |
| `refkeen` | NY00123, *ReflectionHLE*, containing id Software's released Keen Dreams source under `src/kdreams`. | GPL v2 | Specification for Keen Dreams. |
| `keendreams/keendrms.zip` | The 1992 shareware distribution of Keen Dreams. | — | Version identification only. |
| `F:\Dropbox\Sidescroller Recomps` | The Duke Nukem II recreation: the process, the tools (`tools/`), the OPL library (`native/d2opl`). | GPL v2 | Template for everything here; `d2opl` is reused. |

## The player's game files

Never committed, never in a build. For development they live in `game_data/<game>/` (gitignored);
the program finds them in Steam/GOG installs or a chosen folder at run time.

| Game | Version | Executable | SHA-256 (first 16) | Where it is on this machine |
|---|---|---|---|---|
| Keen 1 | 1.31 (Steam) | `KEEN1.EXE` (51,190 bytes) | `8b3f829f7eeab18a` | `keen13/gamedata`, Steam `Commander Keen/base1` |
| Keen 2 | 1.31 (Steam) | `KEEN2.EXE` (58,335) | `01a05a1584c4245d` | `keen13/gamedata2`, Steam `base2` |
| Keen 3 | 1.31 (Steam) | `KEEN3.EXE` (61,599) | `ce240fee9e23e0c3` | `keen13/gamedata3`, Steam `base3` |
| Keen 4 | 1.4 EGA (Steam) | `Keen4e.exe` (105,108) | `bdbb46746e02c0dd` | Steam `base4` |
| Keen 5 | 1.4 EGA (Steam) | `Keen5e.exe` (106,417) | `77f687268be09763` | Steam `base5` |
| Keen 6 | 1.0 EGA, executable and data (data dated 15 Nov 1991, executable 12 Jan 1992); supported by reading its three version tables from the executable | `KEEN6C.EXE` (104,938) | `050dadf0c1902fcf` | `Documents\SPLATTER` (the original), `keen6/game`, `keen6patch` |
| Keen Dreams | registered 1.00 (per Megarocket's `-gamever kdreamse100`) | `kdreams.exe` (77,694) | `36a22dbd3119c0b4` | `keendreams/game` |

**Keen 6 note.** Omnispeak ships headers for v1.4 and v1.5 only; the user's copy is v1.0, and the
official `6keen14.exe` patcher rejects this pressing as "unknown version" (the file is untouched: it is
byte-identical to the original in `Documents\SPLATTER`). Megarocket established in July 2026 that v1.0
differs from v1.4 in exactly three tables (EGAHEAD, EGADICT, MAPHEAD) and that v1.4's chunk numbering,
actions, strings and tile info replay v1.0's own demo bit-exactly. The loader therefore identifies the
executable by checksum (`GalData.KNOWN_EXES`), unpacks it and takes the three tables from the load image
at 0x1FB20, 0x35D12 and 0x23C50. A v1.4 or v1.5 copy loads through omnispeak's headers as before. The
oracle runs the v1.0 executable, so Keen 6 fidelity is to v1.0. Keen 6 v1.5 is deferred.

## The oracle

DOSBox Staging (the Duke project's copy, location in `tools/config.json` once written), one hermetic
profile per engine, derived from — but not identical to — the settings the games are sold with
(Steam's `keen4.conf` uses `cycles=auto` and `core=auto`; the oracle fixes both). The traps found on
the Duke project apply unchanged: normal CPU core, no host keys bound to game keys, MIDI device off,
Elgato audio drivers stopped before any run, runs started minimised, no window tests during a run.

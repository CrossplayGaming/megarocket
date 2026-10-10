# Secrets answer key: Keen 2 (The Earth Explodes)

Every documented secret per level, from published sources, checked against the level data, as the answer
key for the "Reveal secrets" cheat and for the SecretFinder prototype (`godot/maker/secret_finder.gd`,
harness `godot/harness/secret_report.gd`). Same format and conventions as `secrets_key.md` and
`secrets_key_keen1.md`. Facts only; no game data.

## How to read this

- **Level numbers**: by level file (`LEVELnn.CK2`), the same as the wiki's level numbers. The world map
  (the Mothership blueprints) is LEVEL80.
- **Where**: tile coordinates (x, y), origin at the map's top left, from the level data.
- **Source type**:
  - *official*: CKHINT.EXE, https://keenwiki.shikadi.net/wiki/Hint_Sheet_(Invasion_of_the_Vorticons);
    3DR, http://legacy.3drealms.com/tech/keen.html.
  - *wiki*: https://keenwiki.shikadi.net/wiki/<Level_Name> (also Keen_2_Bugs, Keen_2_Easter_eggs).
  - *walkthrough*: Flaose's FAQ v2.01,
    https://gamefaqs.gamespot.com/pc/619366-commander-keen-goodbye-galaxy/faqs/23724 (section 9.2). No other
    complete Keen 2 walkthrough was found (GameFAQs' Keen 2 page could not be located; CrystalShard and
    Clownboss cover other episodes).
  - Read through Wayback Machine snapshots (wiki 2025, GameFAQs 2019).
- **Pictures** (scratchpad only): `...\scratchpad\secrets\clean\keen2_levelNN.png` (clean) and
  `...\secrets\finder\keen2_levelNN.png` (finder), under
  `C:\Users\cross\AppData\Local\Temp\claude\F--Keen-Launcher-Godot-4-Rework\bb53a150-6f98-435a-a62f-14521af8da56\`.

## Summary: Keen 2 has no tile-hidden secrets

The official hint sheet's Keen 2 section gives tactics only (Scrubs, Vorta-Cola cans, light switches, an
Impossible Pogo Trick route in a Tantalus level); none names a hidden place. The level data agrees: across
all 16 levels there is no passable tile drawn like a wall, no solid or one-way tile drawn like empty space
(a search of every pair of used tiles with different walls found none within 6 pixels of each other), and
no foreground drawn over a passable cell that hides an item. The finder flags no region in any level. What
the sources call hidden or secret below are optional rooms that are dark or out of the way, not concealed
by tiles. A "Reveal secrets" cheat would show nothing in Keen 2 unless these are wanted as "bonus areas".

## World map (LEVEL80)
- None documented. Finder: 30 "hidden platforms" listed on the map are an artefact of running the
  platform test on a top-down map (no gravity there); ignore.

## Level 1: Bottom Galley; Level 2: Engine Room B; Level 3: Engine Room A; Level 4: London Tantalus Center
- None documented. Engine Room B has an optional "bonus area full of goodies protected by a Guard Robot"
  (Flaose): open, not hidden.
- Finder: a "hidden platform" at (67, 16) in London (and the same cell in levels 6, 7, 11, 15, 16; (127, 16)
  in level 9; (47, 16) in level 13) is a one-way tile inside the solid Tantalus Ray machine, enclosed and
  unreachable: false positive.

## Level 5: Reactor Core
- **Cache of Stuffed Toy Vorticons up from the bridge** (Flaose: "head up right after the bridge to find a
  hidden cache"): three stuffed toys (5000 each) at (24-26, 13) on a small platform in the unlit part of
  the level, reached by climbing the red-brick ledges right of the plasma pit. Not concealed by tiles
  (the dark section is drawn dark but the items and ledges are visible); open. Source: walkthrough
  (Flaose only). The wiki notes the level is partly in perpetual darkness.

## Level 6: Cairo; Level 7: Sydney; Level 8: Home A; Level 9: New York; Level 10: Home B
- None documented. (Home A's food room guarded by three Guard Robots and Cairo's lower candy area with
  two Grunts are optional but in plain view.)

## Level 11: Paris Tantalus Center
- None documented as a secret. One-way holes (grey funnels: fall through, cannot jump back) are a visible
  mechanic. The "FUCL" easter egg in yellow blocks at the entrance is not a hidden area.

## Level 12: Weaponry B; Level 13: Rome; Level 14: Weaponry A
- None documented. (Rome's short route left from the start through the Elite room is a feat, not a hidden
  area.)

## Level 15: Moscow Tantalus Center
- **Second exit below the first, with a bonus room**: a narrow gap right of the upper exit door drops to a
  room with a HyperPistol, two Stuffed Toy Vorticons and hamburgers, and a second exit.
  - Upper exit (77-78, 23-24); the drop (80, 25-35); room (69-80, 31-39) with the items at (70-72, 32)
    and hamburgers (71-73, 39); second exit (77-78, 38-39).
  - Not concealed by tiles (the gap is visible); listed as a documented alternative exit.
  - Sources: wiki Moscow_Tantalus_Center ("two different exits ... both can be reached"), walkthrough
    (Flaose).

## Level 16: Washington Tantalus Center
- **Second exit below the first, with stuffed toys**: from the right of the upper exit, a drop leads past
  four HyperPistols and four Stuffed Toy Vorticons to a lower exit.
  - Upper exit (77-78, 23-24); the drops (75, 25-31) and (80, 25-41); room (73-80, 31-44) with pistols
    at (76, 36-39) and stuffed toys (78, 36-39); lower exit (72-73, 43-44).
  - Not concealed by tiles; a documented alternative exit.
  - Sources: wiki Washington_Tantalus_Center ("two exits ... one right below the other"), walkthrough
    (Flaose).

## Disagreements between sources (summary)

1. Reactor Core: Flaose calls the stuffed-toy cache "hidden"; the data shows it is only off the main path in
   an unlit section. Listed as open.
2. Moscow and Rome: the map labels are swapped (wiki Keen_2_Bugs); level numbers here follow the files
   (LEVEL15 is the Moscow picture's level, entered from the map spot labelled Rome).

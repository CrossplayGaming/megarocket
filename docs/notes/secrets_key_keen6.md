# Secrets answer key: Keen 6 (Aliens Ate My Baby Sitter!)

Every documented secret per level, from published sources, pinned to the level data, as the answer key for
the "Reveal secrets" cheat and for the SecretFinder prototype (`godot/maker/secret_finder.gd`, harness
`godot/harness/secret_report.gd`). Same format and conventions as `secrets_key.md` and
`secrets_key_keen5.md`. Facts only; no game data. Data read from the v1.4 files
(`res://data/omnispeak/keen6e14`).

## How to read this

- **Level numbers**: by map number (F10+W warp numbers, the wiki's level numbers). Map 0 is Fribbulus Xax
  (world map); map 16 is the secret Blooglab Space Station; map 17 is the Bean-with-Bacon Megarocket.
- **Where**: tile coordinates (x, y), origin at the map's top left, from the map planes; row runs are
  written `y: x-x`.
- **Hidden by**:
  - *fake wall*: a passable foreground tile drawn over Keen (misc flag 0x80) that looks like the wall
    around it; items inside are info-plane sprites drawn under it.
  - *off screen*: cells the camera never shows (the two-tile border); Keen is invisible there.
  - *invisible block*: tile 1020, solid on all sides and drawing nothing (Keen 6 uses it once on purpose,
    in the Recreational District; elsewhere it bounds the world map).
  - *hidden door*: door tiles (misc 2) that draw nothing.
- **Contents**: Bloog Soda 100, Ice Cream Bar 200, Pudding 500, Root Beer Float 1000, Banana Split 2000,
  Pizza Slice 5000, Queen Viva = 1UP; "ammo" = Neural Stunner; "drop" = Viva.
- **Source type**:
  - *official*: 3DR, http://legacy.3drealms.com/tech/keen.html (the secret level; the alphabet in a hidden
    area). No Keen 6 hint sheet was found (the wiki has no Keen 6 hint-sheet page).
  - *wiki*: https://keenwiki.shikadi.net/wiki/<Level_Name> (Bloogdome is `Bloogdome`), also Keen_6_Bugs
    and Keen_6_Easter_eggs; the wiki's Keen_6_Walkthrough is the rescued "Commander Keendom" no-points
    walkthrough ("Keendom"), https://keenwiki.shikadi.net/wiki/Keen_6_Walkthrough.
  - *walkthrough*: Flaose's FAQ v2.01 (section 9.7),
    https://gamefaqs.gamespot.com/pc/619366-commander-keen-goodbye-galaxy/faqs/23724. No other complete
    Keen 6 walkthrough was found.
  - Read through Wayback Machine snapshots (wiki 2025, GameFAQs 2019).
- **Finder**: as for Keen 5 (go-platform extension; a second run with `fore_opaque = 0.9`; stash groups from
  `godot/harness/secrets_regions.gd --look=1 --fore=0.9`). On Keen 6 the `fore_opaque` run floods several
  levels with false areas (tree trunks, building fronts, unmodelled ropes and switches), so only stash
  groups and checked cells are used here.
- **Match**: *confirmed* / *likely*, as in the Keen 5 key.
- **Pictures** (scratchpad only): every "candidate, not in any guide" is boxed in magenta, with its top-left cell, in
  `...\secrets\candidates\keen6_mapNN.png`; `...\scratchpad\secrets\clean\keen6_mapNN.png`,
  `...\secrets\finder\keen6_mapNN.png`, under
  `C:\Users\cross\AppData\Local\Temp\claude\F--Keen-Launcher-Godot-4-Rework\bb53a150-6f98-435a-a62f-14521af8da56\`.

## Map 0: Fribbulus Xax (world map)
- **The satellite to the secret level**: on the space platform beside the Bloog Control Center, Keen waits
  by the railing until a satellite carries him to the Blooglab Space Station, and back the same way.
  Satellite loading spots: info 44 at (50, 8) (platform side), info 45 at (8, 8) (Blooglab side); the
  satellite (info 89) starts at (42, 5). Not a tile secret: a waiting mechanic. Sources: official (3DR),
  wiki Blooglab_Space_Station, walkthrough (Flaose).

## Map 1: Bloogwaters Crossing
- **Compartment in the wall across the gap before the switch**: Stash (56-57, 29), (56-59, 30-33):
  2 x 200 at (56-57, 30), 2 ammo at (58-59, 30). Fake wall. Source: wiki ("a secret compartment in the
  wall across the gap right before the switch"). Finder: **found** (dent x 56-59, y 29-33). Match:
  confirmed.
- The Queen Viva in the sky at the start, reached by a moving platform from near the end (wiki, Flaose),
  is in plain view: open.
- Finder: four tall "stashes" (46-47, 4-28), (95-96, 5-28), (120-121, 3-28), (134-135, 3-28) are tree
  trunks drawn over Keen; the items at their tops are in the visible treetops: false positives.

## Map 2: Guard Post One
- **Hidden ledge in the roof near the Blue Gem, to four Neural Stunners**: riding the switch-started
  platform into the roof and jumping left catches a ledge; up-left lie the stunners. Passage (19-24, 58),
  (19-23, 56-57), (19-20, 54-55), (9-20, 50-53) with 3 x 200 at (20-22, 57); the stunners at (5-6, 50-51).
  Fake wall. Sources: wiki ("pogo up and to the left to obtain four Neural Stunner powerups"),
  walkthrough (Flaose). Finder: **found** (area x 4-23, y 50-58 with 4 ammo and 3 x 200). Match:
  confirmed.
- **Along the wall right of the last elevator**: Stash (39-42, 38-41): 2 x 500 at (40-41, 38). Fake wall.
  Source: wiki ("another secret along the wall to the right of the last elevator"). Match: likely.
- *Candidate, not in any guide*: (22-23, 24-27) with 2 x 1000 at (23, 24-25).

## Map 3: First Dome of Darkness
- **Compartment in the ceiling of the storeroom**: Stash (42-46, 56-57), (30-34, 58), (42-46, 58),
  (30-34, 59), (41-69, 59), (30-68, 60-61), (43-45, 62-63): 4 x 500 at (31-32, 59), (43, 57), (45, 57).
  Fake wall. Source: wiki. Finder: **found** (area x 30-75, y 56-63). Match: confirmed.
- **The lower of the two boxes at the right of the top half**: Stash (57-59, 42), (56-60, 43-45),
  (58-59, 46-47): 2 ammo at (60, 43-44). Fake wall. Source: wiki. Finder: **found** (shortcut x 56-60,
  y 42-47). Match: likely.
- **A sealed secret area with 600 points**: Stash (58-60, 31-34): 3 x 200 at (58-60, 32), encased in
  solid tiles, unobtainable without cheating. Source: wiki. Match: confirmed (3 x 200 = 600).
- *Candidates, not in any guide*: (8, 69-75) and (10, 69-75), each 3 x 100 (fake-wall columns).

## Map 4: Second Dome of Darkness
- **The hidden lift shaft and the top tunnel**: from the dome's right side Keen gets into a dark shaft
  outside the dome; a lift rises to a tunnel along the top of the level guarded by electrode beams, with
  points on the way and a cache at the far (left) end.
  - Shaft: (84-87, 2-66), joined to the dome at (82-83, 26-27) and (82-83, 42-44); lift (info 27, between
    B blocks at (84, 6) and (84, 44)) runs (84-86, 6-44).
  - Tunnel: (3-81, 3-5), entered through fake wall (80-81, 3-6).
  - Contents: 1UP at (4, 3), 4 ammo at (5-8, 3), 200 at (25, 4), (48, 4), (61, 4).
  - Hidden by: darkness (the shaft is drawn black outside the dome) and fake wall.
  - Sources: wiki Second_Dome_of_Darkness. Finder: one merged area x 1-87, y 2-72 (mostly false: it
    cannot follow the dome's switches).
- **Compartment with two Queen Vivas, before the shaft**: from the dome's right side at (82-83, 26), up the
  narrow shaft (82, 10-25) and through fake wall (77-81, 9-11), (81, 12) into (72-76, 9-11): 1UP at
  (73, 9) and (74, 9). Fake wall. Source: wiki ("two extra lives are waiting"). Match: confirmed (with
  (4, 3) these are the level's three Queen Vivas, as the wiki counts).
- *Candidate, not in any guide*: (23-27, 68), (23-26, 69-70), (23, 71) with 3 x 200.

## Map 5: The Bloogdome
- None documented. Items near the mines above the exit and in the nearest alcove are unreachable by
  design (wiki): not secrets. No stash in the data.

## Map 6: Bloogton Manufacturing
- **Roof above each Ceilick**: jump into the roof where a Ceilick hangs to take what it guards. Stashes
  (47-48, 86) and (11-12, 87), each 2 x 200. Fake wall. Source: walkthrough (Flaose). Finder: both
  **found** (dents). Match: confirmed.

## Map 7: Bloogton Tower
- **Secret passage beside the right elevator shaft**: from the top of the shaft, into the right wall and
  down. Stash (31-32, 33-34), (28-32, 35-38), (31-32, 39-44): 4 ammo at (31-32, 33-34), 200s at (30-31,
  35), (32, 37), (31, 39), (32, 40), (31, 42). Fake wall. Sources: walkthrough (Flaose "a secret passage
  downwards"), Keendom ("enter the secret area, grab the 2 neural stunners"). Match: likely.
- **A Queen Viva in an alcove**: Stash (28-29, 31-32): 1UP at (29, 31), next to the passage above. Fake
  wall. Source: wiki ("one Queen Viva hidden in an alcove"). Finder: **found** (the 1UP is reported
  secret). Match: confirmed.
- **Pudding in the right wall of the gap below the first Red Door**: Stash (8-12, 85-87): 2 x 500 at
  (11-12, 85). Fake wall. Source: walkthrough (Flaose). Match: likely.
- **Ice Cream Bars in the roof at the shaft's bottom** (Flaose): not pinned. The two stashes of Ice Cream
  Bars that could be it are (50-51, 88-90), (51, 91-94), (47-51, 95-97), (47-48, 98) with 3 x 200, and
  (45-49, 107-110) with 4 x 200; Flaose's words do not decide between them, and neither lies at the foot
  of the passage above.
- *Candidates, not in any guide*: (39-40, 14) 2 x 2000; (21-25, 99-103), (17-25, 104-107), (21-25,
  108-110) with 2 x 1000; an invisible block at (13, 49).

## Map 8: Bloogfoods, Inc.
- **Banana Splits in the right wall** above the small platform past the Blue and Red Doors: Stash
  (75-78, 4-5): 2 x 2000 at (76-77, 4). Fake wall. Source: walkthrough (Flaose). Match: confirmed.
- Walls in the snaking passage that Keen can jump through (wiki Keen_6_Bugs): a collision bug, not a
  secret.

## Map 9: Guard Post Two
- **Hidden tunnel right of the last pit, to a second exit**: from the right side of the dark pit (84,
  37-53), a tunnel through the rock leads to a small room and a second exit below the first.
  - Tunnel: (85, 37-53) (the pit's drawn-over edge) and (85-92, 46-48) through the rock; room (93-97,
    46-48); second exit at the right edge (98, 46-48), below the first exit (98, 34-36).
  - Upper pocket: (88-95, 40-42) joined by (96, 40-46), with drops, a 200, ammo and Bloog Sodas (finder
    area x 86-98, y 40-48).
  - Hidden by: fake wall (rock drawn over Keen).
  - Sources: wiki ("the secret exit is at the end of a hidden tunnel to the right of the last pit"; two
    exits one under the other). Flaose mentions "many secrets both high above and down below" without
    places. Finder: **found** (area x 86-98, y 40-48). Match: confirmed.

## Map 10: Bloogville
- **Pizza Slice in the right wall past the Red Door**: Stash (43-45, 34-35): 5000 at (45, 34). Fake wall.
  Source: walkthrough (Flaose). Match: confirmed.
- *Candidate, not in any guide*: (65-71, 70-71) with 5 x 500 at (67-71, 70).

## Map 11: Bloog Aeronautics and Space Administration
- **Treats in the ceiling above the pole**: Stash (35-36, 12-14): 4 x 500. Fake wall; the pole below it
  is (35, 18-23). Source: walkthrough (Flaose). Finder: **found**. Match: confirmed.
- **Unreachable alcove with two Queen Vivas and a Pudding** (documented, but unobtainable without
  cheating): Stash (67-69, 30), (66-69, 31): 1UP at (68, 30) and (69, 30), 500 at (67, 30), below the
  meeting of the two retractable bridges. Fake wall. Sources: wiki (BASA page; Keen_6_Bugs). Finder:
  items unreached. Match: confirmed.
- *Candidate, not in any guide*: (38-39, 3-5) with 4 x 500 (finder found).

## Map 12: Guard Post Three
- **Three Queen Vivas in the platform's slot**: falling down the right side of the wall into the slot the
  moving platform came out of. Stash (38-48, 59-60): 1UP at (46, 59), (47, 59), (48, 59). Fake wall.
  Sources: wiki ("three Queen Vivas hidden near the first pit"), walkthrough (Flaose; "very difficult to
  get out without dying"). Match: confirmed.
- **Hidden goodies down the right side**: hit the switch and drop off the right side hugging the wall.
  Stash (66-68, 58), (66-70, 59-62): 2 x 5000 at (66-67, 58), ammo at (66, 59). Fake wall. Source:
  walkthrough (Flaose). Match: likely.

## Map 13: Bloogbase Recreational District
- **Invisible blocks to a hidden door, six Queen Vivas and a hidden exit**: when the switch-started
  platform reaches the top of its rise, an Impossible Pogo Trick to the right lands on a row of invisible
  blocks; they lead onto the roof of the big building and a door on top of it, which drops Keen into a
  sealed column of Queen Vivas ending at a hidden exit. Once through, Keen cannot go back.
  - Invisible blocks: (60-70, 7) and (60, 8-10) (tile 1020).
  - Door: (74-75, 3-4), info pointing to (134, 19).
  - Column: fake wall (133-135, 17-25) with 1UP at (134, 19-24); room below (132-138, 26-28).
  - Hidden by: invisible blocks, fake wall.
  - Sources: wiki ("a hidden door ... accessible via a row of invisible blocks ... a column of 6 extra
    lives and a hidden exit"), walkthrough (Flaose).
  - Finder: the column is **found** as a stash; the invisible blocks are not flagged (it only tests
    one-way platforms for invisibility, and tile 1020 is solid on all sides).
- **"Monster points" in the right wall below the slope past the Yellow Door**: Stash (63-64, 36),
  (63-68, 37), (64-68, 38): 6 x 2000. Fake wall. Source: walkthrough (Flaose). Match: likely.
- *Candidates, not in any guide*: (36-41, 5-7), (39-41, 8-9) with 6 x 2000 (finder found); (74-82, 8-9)
  with 4 x 2000; an invisible block at (112, 21). Picture: `...\secrets\v_k6_13.png`.

## Map 14: Bloogbase Management District
- **Into the wall right of the starting floor, Pizza Slices and Banana Splits**: from the start, go left,
  drop off the edge into the wall to the right and keep right. Passage (116-120, 20-22), (111-123,
  23-25), (122-123, 26-29), (125-128, 32-34); pocket (122-124, 30-36). Contents: 6 x 200 at (115-121,
  22-24), 2 x 5000 at (127-128, 32), 2 x 2000 at (123, 34-35), 2 ammo at (123, 32-33). Fake wall. Source:
  walkthrough (Flaose). Finder (`fore_opaque`): **found** (area x 111-128, y 20-36). Match: confirmed.
- **Invisible platform above a flashing hazard, with stunners and goodies above it**: hidden platform cells
  (92-93, 32); stash above (89-91, 28), (89-92, 29): 200, 2 x 5000, 2 ammo. Hidden by: an invisible
  one-way platform and fake wall. Source: walkthrough (Keendom). Finder: **found** (hidden platforms and
  the dent x 89-92, y 28-29). Match: confirmed.
- **Invisible ledge near the start**: Keendom drops "to the invisible ledge below" before the red pillar;
  the finder's hidden platforms (29-30, 20) fit. Source: walkthrough (Keendom). Match: likely.
- *Candidates, not in any guide*: (25-30, 29-31) with 3 x 2000 at (27-29, 29) (unreached by the finder;
  possibly the items the wiki says a Gik-ridden switch makes reachable); hidden platform (110, 28).

## Map 15: Bloog Control Center
- **Hidden doors under the glowing orbs, to the secret area above the start**: below the orbs, every cell
  of a row is an invisible door; pressing Up there takes Keen to a secret area above the beginning, full
  of points, ammo and three Queen Vivas.
  - Hidden doors: (64-75, 36), all leading to (40, 5).
  - Secret area: (39-75, 3-18) (its middle shelf (39-70, 6-7) is solid), left by the door (41-42, 22).
  - Contents: 1UP at (42, 3), (43, 3), (44, 3); 5000 at (66-67, 3-4); rows of 100-5000 items along
    rows 3-11 (x 42-74).
  - Hidden by: hidden door.
  - Source: wiki (Bloog_Control_Center). Finder: not flagged (doors are links, and these draw nothing).
    Match: confirmed.
- **Points in the roof above the pole after the chute**: Stash (9-12, 14-16): 8 x 200. Fake wall. Source:
  walkthrough (Flaose "pogo into the roof above it for some points"). Finder: **found** (dent). Match:
  likely.

## Map 16: Blooglab Space Station (secret level)
- The level itself is the secret (reached only by the satellite).
- **Secret passage off the right edge to the alphabet translation**: riding a platform up into the roof
  and jumping right, Keen drops into a passage that runs down the right edge of the map, off screen, to a
  room at the bottom with ammo, points and a translation of the alien alphabet.
  - Passage: fake wall (53-57, 19-21), (55-70, 22-24), (62-64, 25-26); the off-screen shaft (69-70,
    25-60), (68-70, 57-58).
  - Room: (31-70, 53-60); the translation chart around (39-45, 55-57).
  - Contents: 200s along the passage at (53-63, 20-25) (about 15); in the room 10 x 5000 and 3 ammo at
    (38-44, 53-56).
  - Hidden by: fake wall, off screen.
  - Sources: official (3DR, "an english translation of the Galactic Alphabet is in a hidden area in this
    level"), wiki (Keen_6_Easter_eggs, "a secret passage off the right edge"; Blooglab_Space_Station),
    walkthrough (Flaose). Finder: **found** (stash with 85 off-screen cells, area x 31-70 y 22-60).
- **Points in the small wall right of the arch near the start**: Flaose. Not pinned: the nearest stashes
  are (39-42, 27-29), (42, 26), (42, 30-32) with 6 x 1000, and (21-23, 28-29) with a 1000; neither is
  clearly "right of the arch". *Candidates.*
- *Candidate, not in any guide*: an invisible block at (46, 41).

## Map 17: Bean-with-Bacon Megarocket
- **Secret ledges up the right wall, Pizza Slices above, and the hidden lower half**: pogoing at the right
  wall catches a ledge Keen cannot see (he is off screen); an Impossible Pogo Trick left from it reaches a
  second ledge and the Pizza Slices above; from the first ledge, right and down a shaft, a hazardous lower
  area with more goodies and the exit.
  - Shaft and ledges: (24-25, 12-44), with ledges at (22-25, 13-15) and (22-25, 42-44) (off screen).
  - Pizza Slices: 4 x 5000 at (17-19, 3-5) (open once on the ledge).
  - Lower area: (2-21, 36-65), with 2 x 5000 at (4-5, 62), 2 ammo at (4-5, 63), drops at (4-5, 65).
  - Hidden by: off screen.
  - Sources: walkthrough (Flaose; Keendom), wiki (Keen_6_Bugs "Offscreen onscreen" names this level).
    Finder (`fore_opaque`): **found** (area x 1-25, y 12-65).

## Disagreements between sources (summary)

1. Keen 6 has no hint sheet; Flaose and the wiki rarely describe the same secret, so most entries have one
   source. Where both describe one (Guard Post One's stunners, Guard Post Three's Queen Vivas, the
   Recreational District's door, the Blooglab passage) they agree with each other and with the data.
2. Guard Post Three: the wiki says the three Queen Vivas are "near the first pit"; Flaose puts them in the
   moving platform's slot. The slot (38-48, 59-60) is beside the pit: the same place.
3. BASA: the wiki lists the alcove's lives as unreachable; the data agrees (no route reaches them).

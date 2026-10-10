# Secrets answer key: Keen 5 (The Armageddon Machine)

Every documented secret per level, from published sources, pinned to the level data, as the answer key for
the "Reveal secrets" cheat and for the SecretFinder prototype (`godot/maker/secret_finder.gd`, harness
`godot/harness/secret_report.gd`). Same format and conventions as `secrets_key.md` (Keen 3 and 4). Facts
only; no game data.

## How to read this

- **Level numbers**: by map number (the same as F10+W's warp numbers and the wiki's level numbers). Map 0
  is the Omegamatic (world map); map 13 is the secret Korath III Base.
- **Where**: tile coordinates (x, y), origin at the map's top left, read off the map planes (foreground tile
  flags, info plane) and checked on rendered pictures. "Row runs" are written `y: x-x`.
- **Hidden by** (Keen 5's ways of hiding things):
  - *fake wall*: a passable foreground tile drawn over Keen (tile misc flag 0x80) that looks like the wall
    around it; items inside are info-plane sprites, drawn under it, so they do not show either.
  - *off screen*: cells the camera never shows (the two-tile border, or past a scroll block), where Keen
    is invisible.
  - *drop-through floor*: a one-way platform tile under a foreground arch, which Keen can jump down
    through.
  - *door with no destination*: a door tile whose info value is 0; the engine sends Keen to Korath III.
- **Contents**: Keen 5 point items by value: Shikadi Gum 100, Marshmallow 200, Chocolate Milk 500, Tart Stix
  1000, Sugar Stoopies Cereal 2000, Bag O' Sugar 5000, Keg O' Vitalin = 1UP; "ammo" = Neural Stunner;
  "drop" = Vitalin.
- **Source type**:
  - *official*: GGHINT.EXE (the Goodbye Galaxy on-disk hint sheet),
    https://keenwiki.shikadi.net/wiki/Hint_Sheet_(Goodbye_Galaxy); 3DR,
    http://legacy.3drealms.com/tech/keen.html.
  - *wiki*: https://keenwiki.shikadi.net/wiki/<Level_Name>, also Keen_5_Bugs and Keen_5_Easter_eggs.
  - *walkthrough*: Flaose's FAQ v2.01 (section 9.6),
    https://gamefaqs.gamespot.com/pc/619366-commander-keen-goodbye-galaxy/faqs/23724. Bill Amon's FAQ v0.3
    (.../faqs/1954) covers Keen 4 only in the snapshot read; CrystalShard's walkthrough covers Keen 4 only.
  - Read through Wayback Machine snapshots (wiki 2025, GameFAQs 2019).
- **Finder**: run as in the Keen 4 key, plus this pass's research extensions (Keen 5's go-platforms
  following info-plane arrows, purple platforms, info 69 = ammo and 70 = keycard) and a second run with
  `fore_opaque = 0.9` (a passable drawn-over-Keen tile at least 90% opaque counts as a wall). Every pinned
  stash below is a group of such fake-wall cells holding items (harness `godot/harness/secrets_regions.gd
  --look=1 --fore=0.9`). Unreachable rooms that the finder marks as secret areas because it does not model
  a mechanic are not listed.
- **Match**: *confirmed* = the source's place and contents both fit exactly one stash; *likely* = the
  contents fit and the place fits as far as the source's words allow.
- **Pictures** (scratchpad only): every "candidate, not in any guide" is boxed in magenta, with its top-left cell, in
  `...\secrets\candidates\keen5_mapNN.png`; clean renders `...\scratchpad\secrets\clean\keen5_mapNN.png` (info-plane
  item sprites are not drawn there), finder mark-ups `...\secrets\finder\keen5_mapNN.png`, under
  `C:\Users\cross\AppData\Local\Temp\claude\F--Keen-Launcher-Godot-4-Rework\bb53a150-6f98-435a-a62f-14521af8da56\`.

Official hint sheet summary for Keen 5: nine free Keens on level 1; the two level designers' names are
hidden in two levels; 30,000 hidden points near the start of Defense Tunnel Sorra; the way to the secret
level is in the Gravitational Damping Hub ("look down and translate").

## Map 0: the Omegamatic (world map)
- No hidden map items. The Korath III Base is reached only through the Gravitational Damping Hub's hidden
  teleporter (map 11); Keen arrives on Korath III's surface. The "secret elevator" outside the map (wiki
  Keen_5_Bugs) is a bug. Finder: one false area (23-26, 86-90) from the map's own walls (the invisible
  block tile 1020 bounds the map's paths).

## Map 1: Ion Ventilation System
- **Hidden ledge and passage over the top to the hull, with ten Kegs O' Vitalin**: from the moving platform
  under the downward sentry gun at the upper left, an Impossible Pogo Trick to the left catches a hidden
  ledge in the wall; Keen climbs inside the wall, crosses the whole top of the level unseen, and drops down
  a chute in the right wall to the airlock ledges outside the ship; jumping off them to the right collects
  the kegs on the way down.
  - Contents: 10 x 1UP at (52, 61), (53, 64), (52, 68), (54, 68), (52, 70), (54, 70), (52, 72), (54, 72),
    (52, 74), (54, 74); 2 ammo at (40, 52) and (38, 57) on the airlock ledges.
  - Passage cells: the ledge and shaft (7-9, 12), (7, 3-11); the crossing (8-42, 2), (7-42, 3); the chute
    (42, 4-47).
  - Secret area: the airlock ledges and the space outside the hull, (37-55, 48-77) and (44-55, 4-47).
  - Hidden by: fake wall (the ledge, shaft and crossing are inside the wall), then open space Keen
    otherwise cannot reach.
  - Sources: official (GGHINT "NINE free Keens on level 1"; 3DR, the full route), wiki
    Ion_Ventilation_System ("ten Kegs O' Vitalin hidden outdoors"), walkthrough (Flaose).
  - Finder: **found** (area x 7-56, y 2-77: 138 passage cells, all ten 1UPs and both ammo).
  - *Disagreement*: GGHINT and 3DR say nine free Keens; the wiki and Flaose say ten. The map has ten.
- *Candidates, not in any guide*: two Marshmallow pockets inside walls, (27, 31-33) with 2 x 200 and
  (20-22, 41-42) with 6 x 200 (fake walls). Picture: `...\secrets\finder\keen5_map01.png`.

## Map 2: Security Center
- **Wall right of the first pole**: Bags O' Sugar in the right wall at the bottom of the first pole. Stash
  (51-53, 63-64), (52-56, 65-66): 4 x 5000 at (55-56, 65-66). Fake wall. Sources: walkthrough (Flaose),
  wiki ("to your right, there is a hidden passage with extra points"). Match: confirmed.
- **Below the button platform**: falling left from the pole-top button platform while holding right
  lands in more hidden Sugar. Stash (26-28, 57-58): 4 x 5000. Fake wall. Source: walkthrough (Flaose).
  Match: likely.
- **Wall by the retracted bridge**: Sugar Stoopies in the wall right of the bridge (6-10, 47-48). Stash
  (12-14, 47-48): 2 x 2000 at (14, 47-48). Fake wall. Source: walkthrough (Flaose). Match: confirmed.
- **Roof left of the Blue Gem socket**: pogo up-left into the roof for Bags O' Sugar and a Keg. Stash
  (4-13, 33-34), (13, 35): 1UP at (4, 33), 6 x 5000 at (6-8, 33-34). Fake wall. Source: walkthrough
  (Flaose). Finder: **found** (area x 4-13, y 33-35). Match: confirmed.
- **Passage over the energy beams**: a hidden passage over the three beams of the upper corridor. Cells
  (28-43, 11-12), (28-29, 13-16), (42-43, 13-16); 4 x 2000 at (28-29, 15) and (42-43, 15). Fake wall.
  Source: wiki (the level walkthrough). Match: confirmed (the only hidden way across the beams).
- **Right wall of the next doorway**: after the beams and a door, goodies in the wall right of the
  doorway. Stash (35-45, 4-5): 5 x 200 at (37-41, 5), 4 x 5000 at (44-45, 4-5). Fake wall. Source:
  walkthrough (Flaose). Match: likely.
- **Wall right of the exit**: Sugar in the wall right of the exit door. Stash (68-69, 4-5): 4 x 5000.
  Fake wall. Source: walkthrough (Flaose). Match: confirmed.
- *Candidate, not in any guide*: a stash (56-63, 13), (56-65, 14), (54-57, 15), (60-65, 15), (54-57, 16)
  in the wall above the main hall: 5 x 2000, 6 x 5000, 1UP at (65, 14); 8 of its cells are off screen.
  The wiki's note that "16,000 of the points" need unconventional methods may refer to part of it; the
  sum does not match. Picture: `...\secrets\finder\keen5_map02.png` (the darker green block at the top
  right).
- Finder (without fore walls) leaves the whole top band unreached; with `fore_opaque` the stashes above
  are found.

## Map 3: Defense Tunnel Vlook
- **Wall next to the Spindred, near the start**: inside the wall, a few Gum up to the left and, to the
  right, Bags O' Sugar and a Keg. Stash entered up the shaft (179-180, 5-11); cells (174-180, 2),
  (170-187, 3-4), (170-176, 5), (179-182, 5), (185-187, 5); contents 21 x 100 at (170-176, 3-5),
  8 x 5000 at (181-182, 3-4) and (186-187, 3-4), 1UP at (187, 3). Fake wall. Source: walkthrough
  (Flaose). Match: confirmed (Flaose says "continue left" from the start; the stash is right of it).
- **Above the arch near the exit**: pogo up-left above the arch for hidden goodies and, higher up to the
  right, a hidden Keg. Stash (38-51, 2-12): 10 x 2000 at (38-40, 3-5) and (45, 7), 1UP at (51, 2); the
  shaft (44-46, 6-12) rises from the arch. Fake wall. Sources: walkthrough (Flaose); wiki ("Two Kegs O'
  Vitalin are hidden in the tunnel"). Match: confirmed.
- *Candidate, not in any guide*: (25-26, 8-10) with 2 x 2000 (fake wall).
- Finder: marks the whole left section (7-51, 2-18) as reached only through the arch stash; that is wrong
  (the section is reached through the yellow door and the switch platform, which it does not model).

## Map 4: Energy Flow Systems
- **Through the wall from the Blue Gem, down past John Romero's name to the Keg**: from the Blue Gem
  room, jump right into the wall and fall; at the bottom, left along the passage under the pipes spelling
  the designer's name, to a Keg O' Vitalin.
  - Passage cells: (38-39, 56-57), (39, 58-60), (32-39, 61-62), (32, 63-64), (39, 63-65), (34-66, 66-67),
    (59-66, 62), (60-66, 63), (65-66, 64-65).
  - Contents: 6 x 500 at (39, 57-58), (36-37, 61), (39, 64-65); 2000 at (59, 62); 1UP at (32, 65).
  - Hidden by: fake wall.
  - Sources: walkthrough (Flaose), wiki ("a single Keg O' Vitalin is hidden at the bottom of the level";
    the name easter egg). Official GGHINT: the designers' names are hidden in two levels (this one and
    map 10).
  - Finder: the passage is a "shortcut" (contacts 4) with the 500s and the 2000; the 1UP at (32, 65) is
    counted open (its cell is plain space at the passage's end).
- The fire-helix pit at the bottom left ("many hidden goodies", wiki) is an optional area behind a
  do-not-enter sign, in plain view: open.
- *Candidates, not in any guide*: (5, 47-50) and (19, 47-50), each 3 x 1000 in a one-tile wall column
  beside the two arched rooms (fake walls).

## Map 5: Defense Tunnel Burrh
- **Roof above the sentry gun, down to two extra lives**: pogo up-left into the roof above the sentry gun,
  climb and fall left. Stash (57-75, 2-3), (57-66, 4-5), (74-75, 4), (57, 6-17), (57-61, 8-9): 14 x 500 at
  (59-65, 4-5) and (57, 15), 1UP at (60, 8) and (57, 10). Fake wall. Sources: walkthrough (Flaose), wiki
  (2 extra lives). Finder: **found** (shortcut x 57-75, y 2-17). Match: confirmed.
- **Wall past Robo Red's chamber**: after the Yellow Gem, jump into the right wall to come out beyond
  Robo Red. Passage (97-99, 4), (98-103, 5), (99-103, 6), (102-103, 7-12) with 7 x 1000. Fake wall.
  Source: walkthrough (Flaose). Finder: **found** (shortcut x 97-103). Match: likely.
- **Roof right of the sentry gun**: hidden Tart Stix. Stash (139-145, 6-7), (144-145, 8-10): 9 x 1000.
  Fake wall. Source: walkthrough (Flaose). Finder: **found** (shortcut x 139-145). Match: likely.
- **Roof right of the doorway past the Yellow Door**: hidden Chocolate Milk. Stash (154-162, 10-11),
  (161-162, 12): 11 x 500. Fake wall. Source: walkthrough (Flaose). Match: confirmed.
- **Roof above the Blue Gem**: pogo straight up for points above the gem. Stash (178-179, 3-5): 2 x 2000.
  Fake wall. Source: walkthrough (Flaose). Match: confirmed.
- *Candidates, not in any guide*: (129-132, 12-15) with 2000 at (132, 13); (152-153, 14-17) with 2 x 500;
  (176-177, 15-17) with 2 x 2000 (all fake walls). Picture: `...\secrets\k5_05_r.png`,
  `...\secrets\k5_05_rr.png`.

## Map 6: Regulation Control Center
- None documented; no stash in the data. Finder: two one-cell "areas" at (5, 13-14) and (7, 13-14) are
  gaps beside a foreground fixture: noise.

## Map 7: Defense Tunnel Sorra
- **Wall right of the first drop, with Bags O' Sugar**: from the start, drop to the Gum and walk into the
  wall on the right; past a small barrier, Bags O' Sugar. Passage (39-46, 12-13), (9-46, 14),
  (9-41, 15-16), (44-71, 15-16): 4 x 500 at (40-41, 14-15), 10 x 5000 at (67-71, 15-16). Fake wall.
  Sources: official (GGHINT "30,000 hidden points near the start"), wiki ("a secret bonus area with many
  points at the right wall on the first hole"), walkthrough (Flaose). Match: confirmed.
  - *Disagreement*: GGHINT says 30,000 points; the stash holds 52,000 (ten Bags O' Sugar and four
    Chocolate Milks).
- **Wall above the non-functioning sentry gun**: Stash (88-90, 11-13): 4 x 1000. Fake wall. Source:
  walkthrough (Flaose). Match: likely.
- **Roof on either side of the exit**: left of the exit door, (187-192, 2-4), (191-192, 5), (190-194, 6):
  8 x 1000, 2 x 500; right of it, (196-197, 6-7): 2 ammo. Fake walls. Sources: walkthrough (Flaose
  "either side of the exit"), wiki (the "secret compartment" beside the downward laser, a trap in v1.4
  Apogee, fixed in the GT release). Match: confirmed.
- *Candidates, not in any guide*: (86-88, 2-3) 3 x 1000; (54-55, 5) 2 ammo; (76-77, 5-7) 3 x 5000;
  (109-111, 8-10) 6 x 500; (115-117, 7-8) 3 ammo (fake walls). Picture: `...\secrets\k5_07_m.png`.

## Map 8: Neutrino Burst Injector
- **Above the purple platforms by the Blue Gem**: jump straight up for hidden Bags O' Sugar. Stash
  (63-64, 2-3): 2 x 5000. Fake wall. Source: walkthrough (Flaose). Finder: **found**. Match: confirmed.
- **Into the wall below the switch**: fall into the wall below for points and a quick way down. Passage
  (65-66, 9), (63-66, 10-11), (66, 12-17), (64-66, 18-19): 4 x 2000 at (65-66, 9-10), 2 x 1000 at
  (66, 15-16). Fake wall. Source: walkthrough (Flaose). Match: confirmed.
- *Candidates, not in any guide*: (42, 2-6) 2 x 1000; (29-30, 7-8) 4 x 1000 (finder found); (15-17,
  28-29) 3 x 2000 (finder found); (60, 55-57) 2 x 500.

## Map 9: Defense Tunnel Teln
- **Wall next to the EXIT sign**: leap into the wall beside the exit and pogo right for Sugar Stoopies and
  Bags O' Sugar. Stash (15, 2-3), (17, 2-3), (13-17, 4-6): 2 x 2000 at (15, 2-3), 2 x 5000 at (17, 2-3).
  Fake wall. Source: walkthrough (Flaose). Match: confirmed.
- **Around the bottom of the pole (points visible and hidden)**: Stashes (190-191, 15-17), (191, 18) and
  (193-194, 15-17), (193, 18), each 3 x 1000, and (195-200, 19-20) with 4 x 1000, all beside the pole at
  x 192. Fake walls. Source: walkthrough (Flaose). Match: likely.
- **Passage with a Tart Stix stuck in a block** (wiki bug "Unobtainable candy": four candies, the fourth in
  a solid tile): stash (167-170, 2-3), (165, 4), (167, 4), (169-170, 4), (165-168, 5-6), (170, 5-7) with
  3 x 1000 at (167, 4-5), (168, 5). Fake wall. Source: wiki (Keen_5_Bugs; Defense_Tunnel_Teln). Match:
  likely (the fourth Tart Stix of the finder's region, in its area cells, is the stuck one).
- *Candidates, not in any guide*: a passage over the three phaser beams, (148-163, 12-13),
  (148-149, 14-17), (162-163, 14-16) with 4 x 200 (a shortcut, like Security Center's documented one);
  (204-205, 10-12) 2 x 500; (178, 12-13) 1000; (48, 13-16) 4 x 5000; (103-104, 16-17) 4 x 5000; the room
  behind the arch at (5-12, 16-20) with a 1UP (the wiki counts one Keg in the level). Pictures:
  `...\secrets\v_k5_09a.png`, `...\secrets\v_k5_09b.png`.

## Map 10: Brownian Motion Inducer
- **Pole into the roof with hidden Tart Stix**: Stash (14-18, 18-19), (18, 20-28): 11 x 1000 at
  (18, 18-28). Fake wall. Source: walkthrough (Flaose). Match: confirmed.
- **Into the wall and down for "mega points"**: two stashes: (46-53, 21-22), (46, 23-32), (52-53, 23-26),
  (52-62, 27-28) with 1UP at (46, 21) and 6 x 1000 at (49-51, 21-22); and (63-64, 29-32) with
  4 x 5000. Fake walls. Sources: walkthrough (Flaose), wiki (1 extra life in the level). Finder: both
  **found** (areas x 46-62 y 21-32 and x 63-64 y 29-32). Match: likely (Flaose's words do not tell the two
  apart).
- Tom Hall's name in pipes (wiki, GGHINT): an easter egg in plain view, not hidden.
- *Candidates, not in any guide*: (14, 37-39) and (16, 37-39), each 2 x 1000.
- Finder: several large "areas" (26-36, 4-13), (39-50, 4-13), (41-66, 54-69) with contacts 0 are rooms
  behind doors it cannot enter (lettered doorways A-C); not secrets.

## Map 11: Gravitational Damping Hub
- **The hidden teleporter to Korath III**: in the archway next to the exit door, a drop-through floor
  under the arch; jumping down through it leads left along a passage and down the left edge of the map,
  off screen, to the bottom left rooms, then up past a Volte-face and sentry guns to the Red Gem and a red
  door; the door beyond is a door with no destination, which sends Keen to the Korath III Base.
  - Way in: arch cells (11-12, 5-7) (foreground drawn over Keen, walkable in normal play), the
    drop-through floor (11-12, 8) (one-way platform tile 1045), then (11-12, 9).
  - Passage: (2-12, 10-11), the off-screen shaft (2, 12-61), (2-4, 62-64).
  - Secret area: the left rooms (4-17, 49-64) and (5-15, 29-48), and the keg room (13-18, 24-32).
  - Teleporter: door tiles (7-8, 33), info 0.
  - Contents on the way: Red Gem (6, 42); 1UP (15, 24); 2 x 1000 (17, 27-28); 4 ammo (17-18, 30-31);
    2 x 2000 (12, 30-31); 6 x 200 (16, 57-62); Vitalin (7-13, 58-60).
  - Hidden by: drop-through floor under a foreground arch, off screen (x = 2 is in the camera's border),
    door with no destination.
  - Sources: official (GGHINT, the sign "JUMP DOWN AT ARCH" in the alien alphabet is the "look down and
    translate" hint; 3DR, the full route), wiki Gravitational_Damping_Hub ("hidden teleporter"; "a single
    Keg O' Vitalin hidden near the secret exit"), Keen_5_Bugs (door value 0 = Korath III), walkthrough
    (Flaose).
  - Finder (`fore_opaque` 0.9): **found** as one area x 2-18, y 3-64; it also wrongly includes the exit
    room (5-10, 3-7), because it counts the arch's foreground as wall.
- **Hidden ammo above the Bags in the Volte-face's chamber**: Stash (63, 61-62): 2 ammo. Fake wall.
  Source: walkthrough (Flaose). Match: likely.
- **Wall right of the doorway, Bags O' Sugar**: Stash (31-33, 3-4), (30-33, 5-7): 6 x 5000. Fake wall.
  Source: walkthrough (Flaose). Match: confirmed.
- *Candidates, not in any guide*: (34-35, 20-21), (35, 22), (25-35, 23-24) with 4 x 5000; (65-66, 21-23)
  6 x 2000; (43-45, 24-25) 3 x 2000 (finder found); (47, 36-38) 2 x 2000; (25, 45-46) 2 x 1000. One of
  them may be Flaose's "roof on the right of the bridge" before button C (he names no contents).
  Picture: `...\secrets\v_k5_11.png`.

## Map 12: Quantum Explosion Dynamo
- **Hidden ledge at the left wall to a room of Neural Stunners, and points above it**: from the start, an
  Impossible Pogo Trick up-left grabs a hidden ledge; moving left leads to a room with ammo; above the
  left-most stunner, hidden points; back right, another hidden wall leads out under the hazards to
  points and ammo.
  - Passage cells: (32-34, 65-66), (25-32, 67), (22-32, 68), (22-25, 69), (27, 69-72), (34, 67-72),
    (10-27, 73-74), (5-6, 68-72).
  - Room (4-9, 73-74) with 3 ammo at (5-7, 73); 2 x 1000 at (5-6, 68); 2 x 1000 at (24-25, 68).
  - Hidden by: fake wall.
  - Source: walkthrough (Flaose). Finder: **found** (area x 4-34, y 65-74). Match: confirmed.
- **Roof above the cyan fusebox**: hidden Tart Stix above the fusebox at about (52, 46). Stash
  (50-56, 42-44): 5 x 1000. Fake wall. Source: walkthrough (Flaose). Finder: **found**. Match: confirmed.
- **Two Kegs in an alcove at the final doors**: Stash (35-39, 31-32): 1UP at (36, 31) and (38, 31). Fake
  wall. Source: wiki Quantum_Explosion_Dynamo ("Two Kegs O' Vitalin are hidden at the final doors").
  Match: confirmed.
- *Candidates, not in any guide*: (37-38, 13-14) 2 x 1000 (finder found); (59-62, 19-20) 2 x 1000;
  (7, 45), (7-8, 46-47), (7, 48) 2 x 1000; (15-17, 54-56) 3 x 1000 above a second fusebox (finder found);
  three "hidden platforms" (16, 13), (19, 13), (20, 16) (finder; unchecked). Picture:
  `...\secrets\v_k5_12.png`.

## Map 13: Korath III Base (secret level)
- The level itself is the secret (reached only by map 11's teleporter).
- **The secret fuse**: a fuse at the top left of the level; breaking it ends the level early and changes
  the ending. Fuse tile (top flag 0x39, the fuse Keen pogoes on) at (23, 7), in a small chamber
  (22-23, 5), (21-24, 6), (21, 7), (24, 7), (22-23, 8) inside the wall block (18-27, 3-9) at the top;
  reached with Impossible Pogo Tricks from a small alcove up the right side of the wall (Flaose). Sources: wiki Korath_III_Base, 3DR (the "transistor" that
  sometimes will not break), walkthrough (Flaose). Not hidden by tiles; the way up is a feat. Will not
  break on Easy (wiki).
- **Roof right of the arrow at the bottom**: hidden Tart Stix. Stash (27-29, 240-242): 6 x 1000. Fake
  wall. Source: walkthrough (Flaose). Finder: **found**. Match: confirmed.
- **A Keg O' Vitalin inside the wall at the top right**: stash (31-33, 3), (30-34, 4-6), (31-33, 7) with
  1UP at (32, 3), above the exit. Fake wall. Source: wiki (counts two Kegs in the level; does not place
  them). Finder: **found**. Match: likely (the other Keg, (4, 132), is reached in the open by jumping
  along the left wall, Flaose).
- *Candidate, not in any guide*: (27, 126-128) with 2 ammo.
- Finder: a large "area" (4-14, 114-218) and (27-36, 183-239) are the level's main climbs, which it cannot
  follow (go-platforms and switch platforms); not secrets.

## Disagreements between sources (summary)

1. Ion Ventilation System: nine free Keens (GGHINT, 3DR) vs ten (wiki, Flaose). The map has ten.
2. Defense Tunnel Sorra: "30,000 hidden points" (GGHINT) vs the stash's 52,000 (ten Bags O' Sugar, four
   Chocolate Milks).
3. Defense Tunnel Vlook: Flaose says to head left from the entrance to the Spindred stash; the stash lies
   right of the start (x 170-187; start at x 117).
4. Gravitational Damping Hub: the hint sheet's "look down and translate", 3DR's "between the exit door and
   the EXIT sign" and Flaose's "JUMP DOWN AT ARCH" sign all name the archway (11-13, 5-7) beside the
   exit door; its drop-through floor is (11-12, 8).

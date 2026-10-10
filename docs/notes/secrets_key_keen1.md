# Secrets answer key: Keen 1 (Marooned on Mars)

Every documented secret per level, from published sources, pinned to the level data, as the answer key for
the "Reveal secrets" cheat and for the SecretFinder prototype (`godot/maker/secret_finder.gd`, harness
`godot/harness/secret_report.gd`). Same format and conventions as `secrets_key.md` (Keen 3 and 4). Facts
only: descriptions, places and contents; no game data.

## How to read this

- **Level numbers**: by level file (`LEVELnn.CK1`), the same as the wiki's level numbers. The world map is
  LEVEL80.
- **Where**: tile coordinates (x, y), origin at the map's top left, read off the level data (tile numbers
  and their wall/`intile` properties) and checked on rendered pictures. A range (a-b, c-d) is a rectangle;
  a list is exact cells.
- **Hidden by**: how the level hides it.
  - *dark hidden brick*: a one-way platform (north wall only, tile 335) drawn as the black background but
    for its single upper-left pixel (tile 155 is the plain black background; the two differ by 1 pixel).
    The game itself hints at them (Fifth Red Rock Shrine's statue).
  - *fall-through brick*: a brick that only blocks from below (south wall only, `intile` -1, tiles 278 and
    283), drawn like the solid brick 272 (278 differs from it by 1 pixel; 283 shows faint cracks).
  - *crack*: a gap in an ice bridge (tile 402, no walls) drawn like the bridge (tile 388, north wall; 4
    pixels differ).
- **Source type**:
  - *official*: CKHINT.EXE, the on-disk hint sheet, transcribed at
    https://keenwiki.shikadi.net/wiki/Hint_Sheet_(Invasion_of_the_Vorticons); the publisher's tech page
    http://legacy.3drealms.com/tech/keen.html ("3DR"); the in-game Yorp statue messages (official text,
    quoted on the wiki level pages).
  - *wiki*: the Commander Keen Wiki level page, https://keenwiki.shikadi.net/wiki/<Level_Name>.
  - *walkthrough*: Flaose's FAQ v2.01 (covers all seven Keens),
    https://gamefaqs.gamespot.com/pc/619366-commander-keen-goodbye-galaxy/faqs/23724 (section 9.1);
    Clownboss, https://gamefaqs.gamespot.com/pc/562691-commander-keen-episode-i-marooned-on-mars/faqs/58740.
  - The wiki and GameFAQs were read through Wayback Machine snapshots (wiki 2025, GameFAQs 2019-2020).
- **Finder**: what the prototype reports (after this pass's extension for dark hidden bricks: a one-way
  platform drawn as a plain-coloured empty space but for at most 12 pixels counts as invisible).
  *found* = flagged; *open* = reached without any secret; *not flagged* = hidden by tile properties the
  finder does not model.
- **Pictures** (scratchpad only, never in the repository): every "candidate, not in any guide" is boxed in magenta, with its top-left cell, in
  `...\secrets\candidates\keen1_levelNN.png`; clean renders in
  `C:\Users\cross\AppData\Local\Temp\claude\F--Keen-Launcher-Godot-4-Rework\bb53a150-6f98-435a-a62f-14521af8da56\scratchpad\secrets\clean\keen1_levelNN.png`,
  finder mark-ups in `...\secrets\finder\keen1_levelNN.png`.

Official hint sheet summary for Keen 1: hidden bricks in the Pogo Shrine ("pogo up and to the right off
of the silver cylinders"); Red Maze City's dark area at the bottom leads to the secret city (fall down,
pull right, get frozen by the ice cannon); hidden bricks in the entrance hallway of the Vorticon
Commander's Castle lead to bonus points.

## World map (LEVEL80, Mars)

- **The Secret City's canyon**: a small enclosed canyon east of the Dark Side's mountains, holding the
  Secret City's entrance and a teleporter. Keen cannot walk there; he arrives by the teleporter at the
  end of Red Maze City's secret route. Level 14 entrance at (62-63, 30-31); its teleporter (sprite value
  46) at (62, 37); walkable canyon (61-63, 30-37). Hidden by: cliffs on every side (an enclosed
  off-path area). Sources: official (CKHINT; 3DR "how to get to the secret level"), wiki Secret_City and
  Red_Maze_City, walkthroughs (Flaose, Clownboss). Not a tile secret on the map itself. Finder: no regions
  on the map (none expected).

## Level 1: Border Town
- None documented.

## Level 2: First Red Rock Shrine
- None documented.

## Level 3: Treasury
- None documented. Flaose's teddy bear "in the small opening made of solid purple blocks" (5000 at
  (59, 32)) is in plain view; open.

## Level 4: Capital City
- None documented. The top-left lollipop is unreachable by design or bug (wiki, Flaose): not a secret.

## Level 5: Pogo Shrine
- **Hidden bricks above the exit to a secret upper area**: three dark hidden bricks stacked on the right
  of the shrine lead up past a row of fire to an upper chamber with a Garg and a teddy bear.
  - Contents: teddy bear (5000) at (6, 5).
  - Hidden platform cells: (19, 26), (19, 22), (19, 18).
  - Secret area: the upper chamber above the fire row, (2-21, 2-17) (fire along row 17 at x 4-7, 9-12,
    14-17; floor of bricks along row 18).
  - Hidden by: dark hidden bricks.
  - Sources: official (CKHINT, "hidden bricks ... to get to a higher place"), wiki Pogo_Shrine,
    walkthroughs (Flaose "grey dot above the exit"; Clownboss).
  - Finder: **found** (hidden platforms (19,18) (19,22) (19,26); area x 0-23, y 0-21 with the 5000).

## Level 6: Second Red Rock Shrine
- None documented.

## Level 7: Emerald City
- Clownboss calls a room to the right of the green climb, where a Garg guards a teddy bear, a "secret
  room". The room is in plain view and reached by visible platforms (teddy bears at (22, 36) and
  (35, 37) are open). Not hidden; listed so it is not mistaken for a missed secret.

## Level 8: Ice City
- **Crack in the ice bridge** (a trap, not a reward): one cell of the lower-left ice bridge has no floor
  but is drawn like the bridge. Cell (8, 42) (tile 402; the bridge cells (7, 42), (9-10, 42) are 388).
  Hidden by: crack. Source: walkthrough (Flaose "mind the crack in the bridge"). Finder: lists the
  neighbouring bridge cell (9, 42) and the row (57-64, 52) as "hidden platforms" because the bridge tile
  388 is within 4 pixels of the crack tile 402: false positives (the bridges are plainly visible).

## Level 9: Third Red Rock Shrine
- None documented. Its statue points to the hidden city (see level 13).

## Level 10: First Ice Shrine
- None documented.

## Level 11: Fourth Red Rock Shrine
- None documented. *Candidate, not in any guide*: a dark hidden brick at (16, 15), one step below and
  right of the brick ledge (13-15, 14) on the slope down from the exit; nothing depends on it (a helper
  step). Picture: `...\secrets\k1_11_crop.png`.

## Level 12: Fifth Red Rock Shrine
- None documented in the level. Its Yorp statue gives the official hint about dark hidden bricks
  ("naught but their upper left corner").

## Level 13: Red Maze City
- **Secret route to the teleporter to the Secret City**: at the bottom right of the maze, a dark pit
  drops past fire into a dark lower area; a dark hidden brick against the right side of the red-brick
  shaft lets Keen over a blue-brick wall; an ice cannon's shot, met in mid-pogo, carries him frozen over
  the second blue wall; past a Tank Robot are a teddy bear and the teleporter (level exit to the map's
  secret canyon).
  - Contents: teddy bear (5000) at (124, 69); teleporter (`intile` 24, warp exit) at (124, 71-72).
  - Way in: the pit (82, 59-62) from the maze floor at row 59 (fire at (81, 61), (83, 61), (81, 64),
    (83, 64)).
  - Hidden platform cell: (85, 68).
  - Secret area: (85-124, 63-72) (beyond the brick shaft; the ice cannon at about (93, 70-71), blue walls
    at (90-91, 65-72) and (103-104, 65-72)).
  - Hidden by: a dark hidden brick, and darkness (the lower area is unlit; its way in is a pit of fire).
  - Sources: official (CKHINT; 3DR; the Third Red Rock Shrine statue "look in the dark area of the city to
    the south"), wiki Red_Maze_City, walkthroughs (Flaose, Clownboss).
  - Finder: **found** (hidden platform (85, 68); area x 85-124, y 63-72 with the 5000 and both warp-exit
    cells).
  - *Disagreement*: 3DR says the way down is in "the corridor containing the yellow key card"; Flaose and
    Clownboss give the route down the right side to a dark pit; the map has one pit, (82, 59-62), and the
    yellow card is in the same lower area to the right (Flaose's second visit), so all describe the same
    place.
- The left branch of the dark area (platforms over fire and water to four teddy bears at (3, 69),
  (2-4, 70)) is described by Clownboss as optional; it is dark but not hidden by tiles: open.

## Level 14: Secret City (secret level)
- The level itself is the secret (reached only from level 13). Within it, none documented. A book at
  (13, 7) sits behind a one-tile-high passage Keen cannot enter (wiki Keen_1_Bugs): a level-design bug,
  not a secret. Finder: the book is unreached; nothing flagged.

## Level 15: Second Ice Shrine
- **Fall-through bricks** (traps, not rewards; the trick exit near the start depends on them): bricks
  that let Keen fall through from above but are drawn as solid brick.
  - Cells: the block under the trick exit's approach (11-17, 9-16); (29, 13); (38-39, 12); (70, 14);
    (75-77, 17); (103, 16); (115, 12).
  - The trick exit is the exit at (21, 7-8): walking at it from the start, Keen drops through
    (11-17, 9) into the room below; only reachable with god mode (wiki).
  - Hidden by: fall-through bricks.
  - Sources: wiki Second_Ice_Shrine ("full of fall-through bricks, which seem identical to regular
    bricks", the trick exit), walkthroughs (Flaose: under the book past the green door, in front of the
    red keycard, under the teddy bear, next to the green keycard; Clownboss: "purplish cracks").
  - Finder: not flagged (a south-wall-only tile counts as a wall; it is a trap, not a hidden way in).
  - *Disagreement*: the wiki and Flaose call them identical to regular bricks; Clownboss says they show
    purplish cracks. The data settles it: two tiles are used, 278 (1 pixel from the solid brick 272) and
    283 (faint cracks); 49 of the 65 cells are 283, and every cell outside the big block is 283.

## Level 16: Vorticon Commander's Castle
- **Hidden bricks in the entrance hallway to the battlements and goodies**: on the third grey pillar of
  the entrance hallway, dark hidden bricks lead up out of the hall to the open air above the castle and
  the platforms with points, including "ID" spelled in sodas at the top left.
  - Contents: about 50 point items in the area: sodas (200) spelling ID at (3-7, 3-6) and (11-17, 4-5);
    lollipops (100) along row 22 (x 11-41); sodas and pizza (200, 500) at (55-58, 7-9), lollipop (60, 9).
  - Hidden platform cells: (58, 53), (58, 50), (58, 47).
  - Secret area: the space above the castle wall, (0-87, 0-46) (finder area).
  - Hidden by: dark hidden bricks.
  - Sources: official (CKHINT "hidden bricks in the entrance hallway that lead to bonus points"),
    walkthroughs (Flaose "the third one. Hidden bricks!"; Clownboss), wiki (the ID easter egg only).
  - Finder: **found** (area x 0-87, y 0-46).
- **Hidden bricks up the right wall above the fireplace**: a column of dark hidden bricks on the right
  wall of the lower right chamber, an easier way up than the visible platforms. Cells (102, 34), (102,
  37), (102, 40), (102, 43), (102, 46), (102, 49), (102, 52), (102, 55), (102, 58), (102, 60), and (98, 34)
  at the end of the brick row (93-97, 34). Hidden by: dark hidden bricks. Source: walkthrough
  (Clownboss). Finder: found as hidden platforms; no area (the visible route reaches the same places).
- **Hidden bricks by the Commander's cage to the slab**: between the ice pillar and the bricks that hold
  the Vorticon Commander, dark hidden bricks lead up into a tunnel in the ceiling and onto the slab
  hanging over him (shoot its chain to drop it). Cells (90, 12), (90, 10). Hidden by: dark hidden bricks.
  Sources: walkthroughs (Flaose, Clownboss); wiki (the slab). Finder: found as hidden platforms; no area.

## Disagreements between sources (summary)

1. Red Maze City: 3DR places the way down in the yellow-keycard corridor; Flaose and Clownboss describe a
   dark pit on the right. One pit exists, (82, 59-62); the yellow card lies beyond it in the same lower
   area, so the descriptions agree.
2. Second Ice Shrine: "identical to regular bricks" (wiki, Flaose) vs "purplish cracks" (Clownboss). Both
   are right: tile 278 is a 1-pixel copy of the brick, tile 283 shows cracks.
3. Pogo Shrine: CKHINT says pogo "up and to the right off of the silver cylinders"; Flaose and Clownboss
   say the bricks are above the exit. The bricks are at x 19, above the exit (18, 31-32) and to the right
   of the cylinder pyramid: the same bricks.

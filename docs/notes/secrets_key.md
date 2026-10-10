# Secrets answer key: Keen 3 and Keen 4 (for the SecretFinder prototype)

Every known secret per level, from published sources, as the answer key that `godot/maker/secret_finder.gd`
is checked against (harness: `godot/harness/secret_report.gd`). Facts only: descriptions, places and
contents; no game data.

## How to read this

- **Level numbers**: Keen 4 by map number (the same as F10+W's warp numbers); Keen 3 by level file
  (`LEVELnn.CK3`, the same as the wiki's level numbers).
- **Where**: tile coordinates (x, y), origin at the map's top left, read off the finder's marked-up
  pictures where a secret could be placed; otherwise the source's own words.
- **Source type**:
  - *official*: id/Apogee's on-disk hint sheets (GGHINT.EXE for Keen 4-5, CKHINT.EXE for Keen 1-3,
    transcribed at https://keenwiki.shikadi.net/wiki/Hint_Sheet_(Goodbye_Galaxy) and
    https://keenwiki.shikadi.net/wiki/Hint_Sheet_(Invasion_of_the_Vorticons)), and the publisher's
    tech/hints page http://legacy.3drealms.com/tech/keen.html ("3DR"). No scanned printed hint book for
    Keen 3 or 4 was found online.
  - *wiki*: the Commander Keen Wiki level page, https://keenwiki.shikadi.net/wiki/<Level_Name>.
  - *walkthrough*: GameFAQs and similar. Flaose FAQ v2.01:
    https://gamefaqs.gamespot.com/pc/619366-commander-keen-goodbye-galaxy/faqs/23724. CrystalShard:
    .../faqs/75528. Snow Dragon: .../faqs/28590. aetherspoon: .../faqs/11167. Jefferson Davis (JD):
    .../faqs/38435. Bill Amon's Keen FAQ: .../faqs/1954 (v0.3) and ckfaq20.txt (v2.0).
  - The live wiki and GameFAQs refused automated fetching (connection refused, 403). They were read
    through Wayback Machine snapshots (wiki 2025-2026, GameFAQs 2018-2019).
- **Finder**: what the prototype reports for the secret. *found* = flagged; *open* = the finder reaches
  it without any secret (not hidden by tiles); *unreached* = no route the finder models gets there;
  *missed* = hidden by tiles but not flagged.

## Keen 4: Secret of the Oracle

Official hint sheet summary: seven free Keens on level 1; the top of the Pyramid of the Moons from the
outside; a hidden area at the top of the Cave of the Descendents; a slug in the Chasm of Chills holds a
secret; Hillville needs "a flash of insight"; free Keens in Miragia, in the Pyramid of the Ancients and
on the Isle of Fire; at least seven free Keens in the Pyramid of Shadows; the secret pyramid is reached
by way of something in the Pyramid of the Moons.

### Map 0: Shadowlands (world map)
- No hidden map items in any source. The Pyramid of the Forbidden cannot be walked to; the Foot carries
  Keen there from the Pyramid of the Moons (wiki Pyramids_of_Shadowlands; official 3DR). Finder: nothing
  flagged (none expected).

### Map 1: Border Village
- **Seven Lifewater Flasks above the underground slug shrine.** Pogo up into the ceiling from the left
  edge of the left acid pool, grab the ledge inside, ride a floating platform (it sinks), pogo to the
  flasks; leave by the alien-alphabet EXIT door. Flasks at (22..28, 37). Sources: official (hint sheet;
  3DR), wiki Border_Village, walkthroughs (Flaose, CrystalShard, aetherspoon, JD).
  Finder: **missed** (the flasks are unreached; the way in is a ledge grab through a diagonal seam of
  the shrine's ceiling, which a tile-by-tile body model does not make).
  - *Disagreement*: 3DR says pogo "up and to the right"; the wiki, Flaose and CrystalShard say up and to
    the left. Bill Amon v2.0 says 9 free Keens; everyone else says 7 (the map has 7).
  - Wiki bug note: pressing Up on the platform exits the level (its tiles carry a door flag).

### Map 2: Slug Village
- **Two hidden passages in the right wall at the bottom of the first pit** near the start: upper one 2
  candy bars (500) then a jawbreaker; through them a pole down to an ice cream (5000) and a stunner, the
  pole's top with raindrops and jawbreakers. Walkthroughs (aetherspoon, CrystalShard, JD, Snow Dragon,
  Flaose). Finder: **found**: stash (124-128, 19-21) with 2 x 500, and area (124-142, 21-34) with 5000,
  ammo, jawbreakers, drops.
- **Narrow pit with two chocolate bars, hidden right wall, long walk left**: 3 stunners, 2 jawbreakers,
  1 ice cream. Walkthroughs (same five). Finder: **found**, area (41-102, 32-40): 3 ammo, 2 x 1000, 5000.
- **Ceiling alcove** on the lower (fire-pit platform) route. Walkthroughs. Finder: **found**, stash
  (26-27, 35): 2 x 1000.
  - *Disagreement*: JD says 2 jawbreakers, CrystalShard says 2 doughnuts. The map has 2 jawbreakers
    (1000).
- Treats above a Bounder near the end (ice cream, raindrops): high up, not hidden (aetherspoon, JD).
  Finder: open (not a tile secret).

### Map 3: The Perilous Pit
- **Secret area above the Mad Mushroom next to the bridge switch**: 2 Lifewater Flasks. Wiki
  The_Perilous_Pit, walkthrough (CrystalShard). Finder: **found**, stash (9-10, 46): 2 x 1UP.
  - *Disagreement*: the wiki says you net +1 life by dying; CrystalShard says you can't get them without
    cheating.
- **Hidden wall pocket near the "HI" sign.** Walkthroughs disagree on where and what: CrystalShard,
  right of the blue key at the HI sign, jump up for two doughnuts; Flaose, right of the HI sign near the
  red-gem pole, candy; Snow Dragon, off a pole through a wall, ammo. The map has both: Finder **found**
  stash (50-56, 56-60) with 2 x 2000 (CrystalShard's) and area (48-55, 34-45) with 2 ammo (Snow Dragon's).
- **Ice cream inside the wall above some colas, below the red key**, pogo in from the right.
  Walkthrough (CrystalShard only). Finder: **found**, stash (4-5, 37): 5000.

### Map 4: Cave of the Descendents
- **Large hidden area at the top of the level**, up a hidden passage near the door hanging in mid-air.
  Official (hint sheet), wiki Cave_of_the_Descendents, walkthrough (CrystalShard). Finder: **found**,
  area (30-119, 3-22), passage at about (51-66, 14-17).
- **Secret passage in the lowest, rightmost part**: from the first falling platform into the right
  wall, a shaft of shovels, 2 Lifewater Flasks (net +1). Wiki, CrystalShard (2 ice creams, 2 one-ups).
  Finder: **found**, area (144-161, 48-76): 2 x 1UP, 2 x 5000.
- **"A whole net of less obvious passages"**: 4 ice creams and 2 stunners through a ceiling passage;
  2 ice creams above a vertical platform and a spear. Walkthrough (CrystalShard only). Finder: the first
  **found**, area (74-92, 53-62): 4 x 5000, 2 ammo. The second (120-121, 51) is in an open shaft:
  open (seen, not hidden by tiles).

### Map 5: Chasm of Chills
- **The slug's secret**: the right wall of the middle of three slug pits is a passage; fall to a door
  into a large secret room. Official (hint sheet; 3DR), walkthroughs (Flaose, CrystalShard). Finder:
  **found**, area (5-56, 48-66) (passage, candy above the door, the door at about (52, 63)) and area
  (3-115, 73-96) behind the door (only a door leads in), with the "door to four ice creams" at
  (57-60, 75-76).
- **Secret area below the exit**: a Lifewater Flask in an alcove and an offscreen passage (Keen
  invisible) with the last 16 raindrops. Wiki Chasm_of_Chills, CrystalShard. Finder: **found**, area
  (67-116, 45-72): 1UP at (104, 59), raindrops along row 70 (a scroll block's row: never on screen).
- **Route to Princess Lindsey**: a cloud you can stand on ("a black platform hidden in it", Snow Dragon;
  "pogo into the cloud", Flaose). Finder: open. The standable cloud is drawn differently from the others
  (its platform shows), so it does not count as hidden here. *Disputed classification.*
- Ice cream guarded by a Mad Mushroom (CrystalShard): (15, 59), inside the slug secret's area: found.

### Map 6: Crystalus
- No secrets (CrystalShard; wiki lists none). Finder: nothing flagged.

### Map 7: Hillville
- **Two sky areas reached by invisible "flash of insight" platforms**: left (stunners, a jawbreaker, 2
  doughnuts) and right (2 doughnuts, a jawbreaker, then by one more flash a Lifewater Flask), and a second
  area (jawbreakers, a stunner, an ice cream). Official (hint sheet; 3DR), wiki Hillville, walkthroughs
  (Flaose, aetherspoon, CrystalShard). Finder: **found**, one merged area (2-147, 3-29) above the trees,
  with 10 hidden platforms at (19,27) (24,30) (23,23) (27,22) (72,11) (127,21) (130,23) (133,24)
  (137,26) (134,30); contents include the 1UP at (77, 7), 5000 at (135, 14), ammo, jawbreakers and
  doughnuts.
  - The guides' starting points differ (Flaose: the island between the two spike pits; aetherspoon: left
    of the first pit). Both match platforms the finder lists.

### Map 8: Sand Yego
- **Invisible bricks to a floating chunk of earth** with a Lifewater Flask and goodies. Wiki Sand_Yego,
  Flaose, CrystalShard. Finder: **found**, area (19-85, 42-59) with the 1UP at (40, 47), 5000, 3 x 200,
  ammo; hidden platforms at (49,55) (49,60) (55,60).
  - *Disagreement*: the wiki and Flaose put it on the first side; CrystalShard says after the door.
- **Ice cream at the start**, reached by jumping straight up from a flash (Flaose only): 5000 at (4, 59),
  hidden platform at (8, 72). Finder: **missed** (the platform is found, but the finder's jump model is
  generous enough to reach the ice cream without it).
- "The many secrets of the hidden walls in the first area" (Snow Dragon, not itemised). Finder: 8
  stashes of items inside cliff faces drawn exactly like solid cliff: (22-23,22-23) 1000; (67-70,58-59)
  2000; (13-16,60-61) 1000; (8-9,65-67) 5000; (65-66,71-72) 500; (18-21,75-82) 1000; (27-35,75-76) 500;
  (44-45,79-80) 2 x 200. Not in any other source.

### Map 9: Miragia
- **A free Keen** (official hint sheet). Wiki: "an extra life reachable from the topmost right area"
  and "the Lifewater Flask is hidden in the lower right corner". Finder: **found**, area (68-80, 6-70):
  a glass tube entered from the top by a hidden platform at (70, 11), sodas down the tube, the 1UP at
  (77, 64) at the bottom. This settles the wiki's two sentences: both describe the same flask (enter top
  right, flask lower right).

### Map 10: Lifewater Oasis
- **Hidden passage to a secret lower tunnel** (climb up-left into the roof from the first ledge, fall
  into the lower path; a switch raises a platform; leave by a second hidden passage). Wiki
  Lifewater_Oasis, Flaose. Finder: **found**, area (3-53, 28-53) (passages down the left and right
  edges, tunnel along row 51).
- **Unreachable Lifewater pool**: 5 flasks and 49 raindrops along row 56. Official (3DR: not meant to
  be so), wiki. Finder: unreached (no route; a cheat could still show it as unreachable).
  - *Disagreement*: the wiki says 5 flasks; CrystalShard says "the dozen-or-so one-ups". The map has 5.
- **Offscreen floor in the last area** with 8 jawbreakers. Wiki. Finder: **found**, (36-47, 88-89): row
  88 is a scroll block's row and the camera never reaches below it.
- Finder also flags two item stashes not in any source: (8, 31-32) 1000 at the top of a pole inside
  the rock, (10-11, 32-35) 2 x 100.

### Map 11: Pyramid of the Moons
- **Hidden pole in the ceiling** of the lower Inchworm room, left of the four dart shooters, up to a
  small room whose door leads to a ledge with a Lifewater Flask. Official (3DR), wiki, Flaose. Finder:
  **found** as a "way up": the pole at (8, 82-86), hidden in rock and seen only from the room above. The
  flask at (46, 34) is open: the finder reaches it by other routes.
- **Second hidden passage above that door**, to a chamber of ice creams with a door to the outside top
  of the pyramid. Official (hint sheet "the top ... on the outside"; 3DR), wiki, Flaose, Snow Dragon.
  Finder: **found**, area (3-25, 62-69) with 6 x 5000, and area (2-98, 4-41) (outside the pyramid).
- **Secret level, the Foot**: gather all Inchworms. Official, wiki, walkthroughs. Not a tile secret;
  not in scope. *Disagreement*: 12 Inchworms everywhere except Snow Dragon (10).
- Mooning easter egg (wiki): not in scope.

### Map 12: Pyramid of Shadows
- **Hidden flask room in the lowest (tar-pit) area**: 6 flasks and a stunner, one more flask under the
  platform; at least seven free Keens. Official (hint sheet; 3DR), wiki, Flaose. Finder: **found**,
  shortcut (27-94, 79-97): 7 x 1UP at (30, 92) and (37-42, 94), ammo; its ways in are the corridor along
  rows 80-81 from the right side of the Council Member's pit and the passage the tar platform reaches.
  - *Disagreement*: 3DR enters from the right of the Council Member's pit (pogo up-left into the
    ceiling); the wiki and Flaose ride the tar platform in. Both ways are in the flagged region. Escape:
    wiki says a hidden pole at the far right; 3DR says jump onto the returning platform; Flaose says only
    by dying.
- **Lifewater Flask on the right of the acid pool** (wiki, Flaose): (61, 55), open (not hidden by tiles).

### Map 13: Pyramid of the Gnosticene Ancients
- **Secret passage to the free Keen** (ammo and an extra life). Official (hint sheet), wiki ("first tar
  pit ... secret passage to the left"), Flaose ("pogo into the left side of the outcropping above the
  arch"). Finder: **found**, area (9-51, 85-93): 1UP at (37, 92), ammo, 3 x 500.
- Flask above the left dart gun, collectable only in v1.0/1.1 (wiki): (4, 35), unreached in this version.

### Map 14: Pyramid of the Forbidden (secret level)
- No hidden areas (CrystalShard; wiki: its flasks are not hidden). Finder: nothing flagged.

### Map 15: Isle of Tar
- **Hidden wall right of the switch** ("walk INTO the wall on your right", toward the blue-gem area).
  Walkthroughs (Snow Dragon, Flaose, Amon v2.0). Finder: **found**, shortcut (16-17, 70-75) right of the
  bridge switch at (10, 70), leading down to area (8-30, 83-88) (2 x 5000).
- **1UP in the rock house near the exit**, from the falling black ledge. Walkthroughs (Snow Dragon,
  CrystalShard, Flaose). (101, 55): open (reached by jumping; not hidden by tiles).
- The wiki counts 2 flasks in the level; the second is in the finder's area (22-45, 46-65): a passage
  from the bridge at (18-22, 59) through the wall to a shaft and a stash under the slope with the 1UP
  at (41, 46) and 3 x 2000. Not described by any walkthrough.
- Finder also lists a "way up" at (72, 31-34): the fall below a pole into the corridor beneath.
- *Note*: CrystalShard says "a lot of secrets" but lists only the house.

### Map 16: Isle of Fire
- **Secret passage ending in a Lifewater Flask** ("a tunnel leading to ammo and a 1-up", near the
  yellow gem and switch). Official (hint sheet), wiki, Snow Dragon. Finder: **found**, area (2-53, 34-42):
  1UP at (53, 39), ammo, raindrops.
- Finder also flags a pocket (103, 34-36) with a jawbreaker in the ceiling of a corridor; not in any
  source.

### Map 17: Well of Wishes
- No secrets (CrystalShard); its flask is in plain view. Finder: nothing flagged.

### Map 18: Bean-with-Bacon Megarocket
- No secrets. Finder: nothing flagged.

## Keen 3: Keen Must Die!

Official hint sheet (CKHINT): "some plummets are necessary and some things are hidden in the heavens",
"all ankhs can be obtained", "on the final level, you can stand on the shoulders". No locations given.
Coverage is thin: Flaose's FAQ is the only complete Keen 3 walkthrough found; the wiki pages describe
layouts with few hidden areas.

### World map (LEVEL80)
- **Messie to the Secret Island (Hidden City, level 13)**: wait on the beach of the Grand Intellect's
  island. Wiki Messie / Vorticon_VI, Flaose, an Angelfire cheats page (via Wayback). A map mechanic, not
  a tile secret; not in scope.

### Level 1: Vortiville
- None documented. "TH" spelled in burgers (wiki Keen_3_Easter_eggs): an easter egg, not hidden.

### Level 2: Lower Vortiville
- None documented.

### Level 3: West Vortiville
- **A cloud you can stand on** (left of the big yellow sign, bigger than the others) leading left to a
  Stuffed Toy VortiNinja (5000) and ammo: the official "hidden in the heavens" in practice. Flaose.
  5000 at (6, 4). Finder: open. The cloud is its own tile, drawn unlike the passable clouds, and nothing
  in the tile data says it looks passable. *Not detectable by this method.*

### Level 4: Valden Park
- **Jump into the waterfall to enter the base underneath** (Flaose "secret base"; wiki "the only way
  in"). It is on the required route (red keycard). Finder: not flagged. The waterfall is foreground
  drawn over Keen; counting such foreground as solid flags the base but also floods every level with
  false areas (tried), so it is left out.

### Levels 5-8: New Vorticon, The Bonks, Beens, Hal's Kitchen
- None documented. Hal's Kitchen has unreachable areas (wiki Keen_3_Bugs, a design bug): the finder also
  leaves 54 items there unreached.

### Level 9: Fort Vorticon
- **A small "secret" area on top of the waterfall** (wiki, no contents given). The room at about
  (49-63, 2-8) with six burgers is reached up the waterfall column (57, 9-30), which is foreground water.
  Finder: not flagged (open). *Unconfirmed match.*

### Levels 10-11: Fort Cavort, Fort Vorta Bella
- None documented. (Fort Cavort v1.0 has an unreachable yellow keycard: a bug.)

### Level 12: Fort Vox
- Two exits; an alien-alphabet sign that "lies" (Flaose). Not hidden areas. Finder: nothing flagged.
  (The start corridor's green gates are one-way walls; the finder follows them.)

### Level 13: Hidden City (secret level)
- **Early second exit** reached only with the Impossible Pogo Trick (wiki Hidden_City, Flaose): a feat,
  not a hidden area.
- **Hidden dark ledges** that help Keen climb back up from the bottom (wiki). Finder: **found** as hidden
  platforms at (33,39) (40,39) (18,73) (15,80) (platform tiles within 17 pixels of the dark rock behind);
  no area is flagged, because the finder's jump reaches everything without them.
- School at the top with the alphabet translation, unreachable in v1.0, fixed in v1.31 (wiki, Flaose):
  reachable here (5000s at (75-78, 2) open).

### Level 14: Cape Canavorta
- None documented.

### Level 15: Caves of Oblivion
- **Alternate exit over the mountain** ("GO UP" sign, clouds): visible, not hidden (wiki, Flaose).
  Finder: open. Two more dark-ledge platforms found at (44, 26) and (40, 58); no area depends on them.

### Level 16: Castle of the Grand Intellect
- Safe spots (official hint sheet: the shoulders; 3DR: three different bricks on the floor). Not areas.

## Disagreements between sources (summary)

1. Border Village: pogo direction (3DR right; wiki, Flaose, CrystalShard left); 7 vs 9 flasks (Amon v2.0).
2. Pyramid of Shadows: way in, way out and count (3DR / wiki / Flaose); the map supports both ways in.
3. Inchworms: 12 vs 10 (Snow Dragon).
4. Lifewater Oasis pool: 5 flasks (wiki; the map has 5) vs "dozen-or-so" (CrystalShard).
5. Perilous Pit HI-sign pocket: three different places and contents; the map has two hidden pockets
   that between them match all three descriptions.
6. Perilous Pit flasks: net +1 by dying (wiki) vs only by cheating (CrystalShard).
7. Slug Village ceiling alcove: jawbreakers (JD; the map agrees) vs doughnuts (CrystalShard).
8. Sand Yego floating chunk: first side (wiki, Flaose) vs after the door (CrystalShard).
9. Miragia: the wiki's "topmost right" and "lower right corner" are the same flask (the map).
10. Pyramid of the Ancients: wiki's "first tar pit ... to the left" and Flaose's "outcropping above the
    arch" are the same passage (the finder's one area).
11. Keen 3 hint wording: "hidden in the heavens" (official) vs "think big clouds" (Flaose's paraphrase).

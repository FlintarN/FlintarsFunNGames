# Standard map layouts for the Warcraft RTS

Research for lobby map selection: a few "classic melee" style maps plus our own
premade maps, from 1v1 up to 8-10 players (4v4, 5v5, 8-player FFA).

Status of facts: sizes, player counts and spawn positions marked (src) come from
the linked pages. Layout details marked (mem) are from general WC3 knowledge
and were not verifiable online (Liquipedia blocks automated fetches), so treat
them as "close enough to design from", not as exact replicas.

---

## 1. Scale: WC3 cells vs our tiles

Our engine already uses WC3 footprints at 1 tile = 1 WC3 terrain cell (128
world units): town hall 4x4, gold mine 3x3, barracks 3x3, farm/burrow 2x2.
So a WC3 map "size" is directly comparable to our grid size - but WC3 sizes
include an unplayable border of a few cells, and WC3 maps are big:

| WC3 map | WC3 size | Our grid at 1:1 | Practical for us |
|---|---|---|---|
| Terenas Stand (1v1) | 84x84 | 84x84 | ~64x48 compressed |
| Echo Isles 2 (1v1) | 108x88 | 108x88 | ~80x56 compressed |
| Turtle Rock (4p) | 104x104 | 104x104 | ~96x64 or 88x88 |
| Twisted Meadows (4p) | 124x124 | 124x124 | ~96x96 |
| Gnoll Wood (6p) | 128x128 | 128x128 | ~112x96 |
| Lost Temple (4p) | 160x160 | 160x160 | too big; ~96x96 |
| Golems in the Mist (8p) | 136x136 | 136x136 | ~120x120 |
| Twisted Turtles (8p) | 252x124 | - | ~128x80 |

Rule of thumb for adapting: keep building/mine footprints and the base
"pocket" (hall-to-mine distance, tree line distance) exactly as WC3, and
compress the *empty land between bases* to ~55-70%. Our units move in tiles
per second like WC3, so compressing travel distance shortens games, which suits
an in-WoW minigame (target 10-20 min for 1v1).

Viewport: the window is ~740x460. Our current 64x40 map fits the whole window
at ~11.5 px/tile. Anything bigger needs a scrolling camera plus a minimap
(both of which WC3 players expect anyway). At ~16 px/tile the view shows ~46x28
tiles, roughly one base plus surroundings - about what WC3's camera shows.

Grid cost: 128x80 = 10,240 tiles, 144x96 = 13,824 - fine for storage; the
real cost is A* on long paths with many units. Expect to need path caching or
a coarse "region graph" (hierarchical pathing) before 8-10 player maps.

---

## 2. The classic melee maps

Common vocabulary first:
- **Main**: start location, hall + 1 mine + tree line behind.
- **Natural**: the expansion closest to the main, usually guarded by an
  orange camp and often reached through/near the main's ramp.
- **Creep camp colours** (Blizzard's guide, (src) classic.battle.net):
  green = camp level 1-9, orange = 10-19, red = 20+. Camps progress from
  easy near the start to hard in contested areas; avoid camps above ~23.
- **Neutral buildings**: Goblin Merchant (items), Tavern (hire/revive heroes),
  Mercenary Camp (hire creep units, tileset-specific), Goblin Laboratory
  (zeppelin, shredder, sappers, reveal), Marketplace (random items),
  Fountain of Health / Fountain of Mana (regen aura), Way Gates (teleport),
  Goblin Shipyard (transport boat). Blizzard's guide: pick 2-3 types per map,
  not all; place fountains and taverns equidistant from every start.
- **Melee rules from Blizzard's guide** (src): equal travel distances from
  every start to trees, mine, expansions and taverns; one or two ramps into
  the high-ground main; consistent number of entrances per start.

### Lost Temple (LT) - 4 players
- Size 160x160, Lordaeron Summer, 4 starts, FFA or 2v2, **12 gold mines** (src).
- Layout: starts in the four corners. A raised temple plateau in the middle
  with a **Fountain of Health** on top, guarded by high-level creeps (src).
  Mines ring the map: each start has a near expansion and a far expansion;
  there are **island expansions** in water (air/shipyard/teleport only) with
  red camps (Granite Golems, Red Drakes, Ogre Lords) (src).
- Camps (src): green camps on the temple sides and corners (Gnoll Brutes,
  Gnoll Poachers, Ogre Maulers); orange camps at unused spawns and near/far
  expansions (Rock Golems, Forest Troll Berserkers / Shadow Priests, Ogre
  Warriors); red camps at island and laboratory expansions.
- Neutral: 2 Goblin Merchants (guarded by Rock Golems / Troll High Priests),
  2 Goblin Laboratories, 1 central Fountain of Health (src).
- Terrain: central plateau with ramps on all sides, water around the islands.
- Why iconic: the default 4-player map since Reign of Chaos (2002); the map
  everyone learned on. The centre fountain is the natural battle point; you
  "expand or die". Lots of mines makes it a macro map.

### Turtle Rock (TR) - 4 players
- Size 104x104, Lordaeron Summer, 4 starts (src).
- Layout (mem): compact 4-corner map built around a central rock formation
  with **Sea Turtle** creeps (spiked shells reflect melee damage - (src)
  Hive), narrow paths between bases. Neutral: Tavern, Goblin Merchants,
  Goblin Laboratory, Mercenary Camps. Each main has a natural next to it.
- Patch 1.19 opened up several chokes because the narrow paths favoured
  ranged armies too much (src).
- Why iconic: small and fast; staple 2v2 and FFA map; famous for choke-point
  fights. A good lesson for us: narrow 2-tile chokes are very strong with
  ranged units - keep chokes 4+ tiles wide unless that's the point.

### Twisted Meadows (TM) - 4 players
- Size 124x124, Lordaeron Summer, spawns at clock positions 2, 5, 7, 10 (src).
- Made by Fairfax McCandlish for Blizzard's 2003 Multiplayer Map Contest (src).
- Layout: **corner islands with gold mines reachable only by air** -
  super-safe expansions for whoever has flyers/zeppelins (src). A
  **Goblin Laboratory camp right next to each main** (so zeppelins are
  available early, which is what makes the islands usable) and an orange camp
  just outside the main (src). Four kinds of neutral building: Mercenary
  Camp, Goblin Merchant, Goblin Laboratory, Tavern (src).
- Why iconic: big map, cross-map spawns, "expansions and highly teched,
  high-upkeep armies" (src). Long a ladder/tournament 4-player staple.

### Echo Isles (EI) - 2 players
- Original Blizzard 1v1 map (Frozen Throne), widely used in tournaments
  (ESWC pool) (src). Echo Isles 2 (community remake): 108x88 (src).
- Layout: two mains on opposite sides of a **central tavern**; islands
  surrounded by water, **Murloc** and **Sea Turtle** camps, Goblin Merchant,
  Marketplace, Mercenary camps (src via EI2 change notes - EI2 added green
  camps next to the tavern, an extra mine above the marketplace "to break
  stalemates", more exposed murloc camps, and moved turtle camps out of
  bottlenecks).
- Terrain: shallow water lanes (walkable) and deep water (blocked) carve
  the land into "isles" connected by shallow fords.
- Why iconic: the 1v1 map of the TFT era; middle tavern = early hero choice
  and fights over it; shallow-water routes give flank options.

### Terenas Stand (TS) - 2 players
- Terenas Stand LV (current ladder version): 84x84, Village tileset,
  2 spawns, Blizzard (src).
- Layout (mem): bases top and bottom, mirrored, central tavern, Goblin
  Merchant(s) and a few green/orange camps on the path; a natural per side.
- Why iconic: small, fast, symmetric 1v1 map that stayed in ladder pools
  across many seasons. Good model for our "small" 1v1 size.

### Secret Valley (SV) - 4 players
- Blizzard Frozen Throne ladder 4-player map (mem; no page found online).
- Layout (mem): four starts, a central valley area with neutral buildings
  (tavern / marketplace / fountain), expansions between neighbours, lots of
  trees forcing a few main lanes. Size not verified.

### Gnoll Wood (GW) - 6 players
- Size 128x128, spawns at 12, 2, 4, 6, 8, 10 o'clock, Blizzard, ROC+TFT (src).
- Layout (mem): six bases around a forested ring; gnoll camps everywhere
  (the name), central fountain/merchant area.
- Relevant to us because it is one of the few classic **6-player rotational**
  layouts: 60-degree symmetry is impossible on a square grid, so even
  Blizzard's version is only approximately symmetric. We should not try to
  make 3- or 6-fold maps.

### Plunder Isle, Northern Isles, Ancient Isles - 2 players
- All three are 1v1 maps from the Frozen Throne era/ladder (Ancient Isles is
  a common tournament map, abbreviated "AI") (src: Liquipedia map portal /
  GosuGamers). Plunder Isle got a 2.0 remake for the WC3L league (src).
- Common theme (mem): island maps with shallow-water crossings and a Goblin
  Shipyard or way gates, i.e. they reward mobility. Details not verified.

### Eight-player maps (4v4 / FFA)
- **Golems in the Mist**: 8 players, Lordaeron Summer, 136x136, spawns at
  1, 3, 4, 5, 7, 8, 10, 11 o'clock (src) - two bases per side of a square,
  rotational layout. Classic 4v4.
- **Twisted Turtles**: 8 players, 252x124, Twisted Meadows on the left and
  Turtle Rock on the right, joined by two pairs of **Way Gates** near the
  shops (src). Shows a cheap trick for big maps: two 4-player halves
  connected by teleports.
- Other classic 4v4 maps (mem): Market Square (city, central market),
  Full Scale Assault (Blizzard bonus 4v4), Deadlock, Hurricane Isle,
  Northshire. Narcomarket Square is a 12-player remake of Market Square at
  141x141 (src).
- Pattern in all of them: team bases share a "back line", allies are close
  enough to help each other (~20-30 cells), there are shared team expansions
  between allies and the contested centre holds the tavern/fountain/shop.

---

## 3. Map data format for our engine

Today the map is a Lua table of rectangles (`halls`, `mines`, `expansions`,
`forests`) mirrored by point reflection (`Mirror(st,x,y,w,h)` = 180-degree
rotation), plus seeded random clumps. That works for one map but is hard to
author and can't express water, cliffs, camps or 8-10 starts. Proposal: an
ASCII grid plus a small Lua table, stored in `Games/Warcraft/Maps/*.lua`.

### 3.1 Tile legend (one char = one tile)

| Char | Meaning | Pathing |
|---|---|---|
| `.` | grass / open ground | walk + build |
| `T` | tree (lumber) | blocks ground; harvestable |
| `~` | deep water | blocks ground; air passes |
| `,` | shallow water / ford | walk, no build |
| `#` | cliff / rock / blocked | blocks ground; air passes |
| `^` | ramp | walk, no build |
| `:` | high ground (optional, vision/miss chance later) | walk + build |
| `_` | road / no-build ground (e.g. lane edges) | walk, no build |
| `1`-`9`,`0` | start location for player 1..10 (top-left of the 4x4 hall) | |
| `G` | gold mine (top-left of 3x3 footprint) | |
| `a`-`z` | creep camp anchor; letter = key in `camps` table | |
| `S` | Goblin Merchant (shop) | |
| `V` | Tavern | |
| `X` | Mercenary Camp | |
| `L` | Goblin Laboratory | |
| `K` | Marketplace | |
| `F` / `f` | Fountain of Health / Mana | |
| `W` | Way Gate (pairs, linked in table) | |

Rules:
- Multi-tile objects are written as **one anchor char at their top-left**;
  the rest of the footprint is drawn as `.` and the loader claims it. That
  keeps the grid readable and makes "is the footprint clear?" a validator
  check instead of a drawing chore.
- Map edges are drawn explicitly (a tree or `#` border).
- Everything not in the legend is an error at load time.

### 3.2 The Lua side

```lua
ns.WC.MAPS.riverford = {
    name = "Riverford", players = 2, w = 64, h = 40,
    teams = { { 1 }, { 2 } },          -- default team layout; lobby may allow FFA
    symmetry = "rot180",               -- see 3.3
    tileset = "elwynn",
    rows = {                            -- h strings of w chars (or only the
        "TTTTTTTT...",                  -- fundamental region, see 3.3)
    },
    camps = {                           -- letter -> level + units
        a = { level = 4,  units = { "gnoll", "gnoll", "gnoll_poacher" } },
        b = { level = 12, units = { "ogre_warrior", "forest_troll", "forest_troll" }, drop = 2 },
        c = { level = 21, units = { "rock_golem", "red_drake" }, drop = 4 },
    },
    gates = { { "W1", "W2" } },         -- way gate pairs if any
    mineGold = { default = 12500, ["G@40,18"] = 8000 },  -- optional per-mine
}
```

Camp level = sum of creep levels (WC3 rule); colour on the minimap follows
green < 10 <= orange < 20 <= red. Item drop tier from level, as in the
Blizzard guide.

### 3.3 Symmetry

Fairness for a deterministic lockstep game comes from symmetry, so make it a
first-class field and let the loader generate the copies:

| `symmetry` | Author draws | Copies | Use for |
|---|---|---|---|
| `"none"` | whole map | - | custom/asymmetric scenarios (defence maps) |
| `"rot180"` | top half (h/2 rows) | 180-degree point reflection | 1v1, team-vs-team with diagonal bases (our current map) |
| `"mirrorX"` | left half | left-right mirror | team-vs-team, teams on left/right edges (4v4, 5v5) |
| `"mirrorXY"` | top-left quadrant | mirror X, then Y | 2v2 / 4 FFA / 4v4 on rectangles |
| `"rot90"` | top-left quadrant (square map only) | 4 quarter turns | 4 or 8 FFA |
| `"d4"` | upper triangle of the quadrant | diagonal reflect + 4 turns | 8 FFA with both starts per quadrant identical |

- Player numbers are remapped per copy with a `digitMap` (e.g. rot180:
  `1->2`; mirrorXY: `1->2` in X, `1->3, 2->4` in Y).
- Anchored objects must be reflected **as footprints**, not as points:
  a w x h object at (x, y) mirrors to (W - x - w, y) in X and (x, H - y - h)
  in Y; rot180 is both (exactly our current `Mirror()`); rot90 on an N x N
  map maps (x, y, w, h) to (N - y - h, x, h, w).
- Objects that must exist only **once** on the symmetry axis/centre (a
  single central tavern or fountain) go in an `overrides` list applied
  after copying, positioned so their footprint is itself symmetric (e.g. a
  2x2 fountain on the exact centre of an even-sized map).
- Anything anchored on a mirror seam gets duplicated next to itself - the
  validator should flag objects whose copy overlaps them.
- Determinism trap: even a perfectly symmetric map is not perfectly fair if
  the simulation iterates in a fixed order (player 1 first, A* neighbour
  order N,E,S,W...). That is acceptable (WC3 has it too) but tests should run
  AI vs AI on both sides and compare outcomes.
- Mirror (`mirrorX`) maps are slightly "handed" (left team's natural is on
  the same side relative to the enemy as the right team's, but flipped);
  `rot180` avoids that and is preferred for 1v1.

### 3.4 Validator (dev harness)

Run on every map in `dev/tests_wc.lua`:
1. row count/width match `w`/`h`; only legend chars.
2. every footprint lies on buildable ground and does not overlap.
3. each start has exactly one mine within ~10 tiles and trees within ~8.
4. flood-fill: every start reaches every other start by ground (unless
   the map sets `islands = true`), and every non-island mine is reachable.
5. for each start, BFS distance to own mine, nearest trees, tavern, and
   nearest expansion - all players' values must be equal (within 1 tile).
6. symmetry check: regenerate from the fundamental region and diff.

---

## 4. Proposed first maps

Sketch scale is noted per map: at 2x one char = a 2x2 block of tiles, at
4x one char = 4x4 tiles. Same legend as 3.1; lowercase letters are camps:
`a` green (level ~4-6), `b` green-plus (~8), `c` orange (~12-15), `d` orange+
(~16-18), red camps get their own letters when needed. In the real file each
anchor is a single tile; the sketches just show where things go.

### Map A - "Riverford" (1v1, 64x40, rot180) - formalise our current map

Our existing 64x40 map, extended with a natural, two contested expansions,
a central tavern and a lake/ford in two corners. Small and quick; still fits
the window without scrolling.

```
2x scale (32x20 chars = 64x40 tiles)
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
T1.....G...TTTT.........b..G.TTT
T..........TTT................TT
T.........TT.....TT...........TT
TT.......TT.....TTTT......TT..TT
TTT.a...........TTT......TTTT..T
TT......TT...............TT....T
T..G...TTT....c....##..........T
T.......T...........##....,~~~~T
TTT........S...VV.........,~~~TT
TT~~~,.........VV...S........TTT
T~~~~,....##...........T.......T
T..........##....c....TTT...G..T
T....TT...............TT......TT
T..TTTT......TTT...........a.TTT
TT..TT......TTTT.....TT.......TT
TT...........TT.....TT.........T
TT................TTT..........T
TTT.G..b.........TTTT...G.....2T
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
```
- Main + natural (`G` below the main, green camp `a`), contested mines in
  the other two corners behind a green-plus camp (`b`), orange camps (`c`)
  near the centre, one Goblin Merchant per side, a single central Tavern.
- Shallow ford `,` lets ground units take the lake shortcut; deep water
  `~` blocks.

### Map B - "Echo Ford" (1v1 or 2v2, 80x56, rot180) - Echo Isles style

```
2x scale (40x28 chars = 80x56 tiles)
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
T1......G....TTTTTT..........TTT...G...T
T.............TTT....................b.T
T..........TT.........TTTT.......TT....T
TT....a....TT........TTTT........TT...TT
TTT..........##..................L....TT
TT..G........#/.........TT...........TTT
TT.........../....b.....TT......TTT...TT
TTT.....TTT................TT...TT.....T
T......TT.........X..........TT........T
~~~,,~~~~........TT..........~~~~~~~~~~~
~~~,,~~~~~~~...................~~~~~~~~~
TT~~~~~~~~~~~~~.......c........~~,,~~~~~
TTTT~~~~~~~~~~~~~..VV.........~~~,,~~~~~
~~~~~,,~~~.........VV..~~~~~~~~~~~~~TTTT
~~~~~,,~~........c.......~~~~~~~~~~~~~TT
~~~~~~~~~...................~~~~~~~,,~~~
~~~~~~~~~~~..........TT........~~~~,,~~~
T........TT..........X.........TT......T
T.....TT...TT................TTT.....TTT
TT...TTT......TTTT...b..../...........TT
TTT...........TT........./#........G..TT
TT....L..................##..........TTT
TT...TT........TTTT........TT....a....TT
T....TT.......TTTT.........TT..........T
T.b....................TTT.............T
T...G...TTT..........TTTTTT....G......2T
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
```
- A river splits the map; a land bridge in the middle holds the Tavern
  (`VV`, one 4x4 building at the exact centre), plus two shallow fords on
  each flank. Natural on a cliff shelf with one ramp (`/`); Mercenary Camp
  (`X`) per side, Goblin Lab (`L`) behind a contested mine.
- Teaches: middle control vs flank fords, the classic Echo Isles feel.

### Map C - "Four Crowns" (4 players: 2v2 or FFA, 96x64, mirrorXY)

```
2x scale (48x32 chars = 96x64 tiles)
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
T1......G.....TTTT............TTTT.....G......2T
T.............TTT.....b..b.....TTT.............T
T.........TT..........T..T..........TT.........T
TT...a....TT......TT........TT......TT....a...TT
TTT..............TTTT......TTTT..............TTT
TT..G......##......................##......G..TT
T.........##/....................../##.........T
TT.....TT......c....TT....TT....c......TT.....TT
TTT...TTT............TT..TT............TTT...TTT
T..........TT.........L..L.........TT..........T
T....b....TT....TT............TT....TT....b....T
TT............TTTT............TTTT............TT
T..G...TT..........d........d..........TT...G..T
T.......T.S..........................S.T.......T
TT...................~~VV~~...................TT
TT...................~~VV~~...................TT
T.......T.S..........................S.T.......T
T..G...TT..........d........d..........TT...G..T
TT............TTTT............TTTT............TT
T....b....TT....TT............TT....TT....b....T
T..........TT.........L..L.........TT..........T
TTT...TTT............TT..TT............TTT...TTT
TT.....TT......c....TT....TT....c......TT.....TT
T.........##/....................../##.........T
TT..G......##......................##......G..TT
TTT..............TTTT......TTTT..............TTT
TT...a....TT......TT........TT......TT....a...TT
T.........TT..........T..T..........TT.........T
T.............TTT.....b..b.....TTT.............T
T3......G.....TTTT............TTTT.....G......4T
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
```
- Lost-Temple-lite: four corner mains, a natural each, a second expansion
  down the side, central pond with a single Tavern on an island-free
  centre (swap for a Fountain of Health for the LT feel).
- 2v2 as left (1+3) vs right (2+4): every player has an identical mirror on
  the other team; allies share the side expansions. Also works as 4 FFA.

### Map D - "Twin Valleys" (8 players, 4v4, 128x80, mirrorXY)

```
4x scale (32x20 chars = 128x80 tiles)
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
T1G...TT...a........a...TT...G5T
T......T.....TT..TT.....T......T
TT..b..T...TTT....TTT...T..b..TT
T......TT....G....G....TT......T
T2G.......d..........d.......G6T
T.....TT......S..S......TT.....T
TTT...T..................T...TTT
T..G.....TT..c....c..TT.....G..T
TT......TTT....VV....TTT......TT
TT......TTT....VV....TTT......TT
T..G.....TT..c....c..TT.....G..T
TTT...T..................T...TTT
T.....TT......S..S......TT.....T
T3G.......d..........d.......G7T
T......TT....G....G....TT......T
TT..b..T...TTT....TTT...T..b..TT
T......T.....TT..TT.....T......T
T4G...TT...a........a...TT...G8T
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
```
- West team 1-4, east team 5-8, each base ~20 tiles from its neighbour so
  allies can reinforce; a shared team expansion between each pair of
  allies (`G` at x~3), contested mines near the centre line, central Tavern.
- Per-player land is tighter than WC3 4v4 maps (16x20 tiles per base area);
  fine for our smaller armies. Variant: 4-player 2v2 version by cutting it
  in half (64x80).

### Map E - "Five Lanes" (10 players, 5v5, 144x96, mirrorX)

```
4x scale (36x24 chars = 144x96 tiles)
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
T1G...TT....a..........a....TT...G6T
T......T.......TT..TT.......T......T
TT..b..TT....TTT....TTT....TT..b..TT
T.......T..................T.......T
T2G......G....c......c....G......G7T
T.....TT........S..S........TT.....T
TTT...T....TT..........TT....T...TTT
T.........TTT..........TTT.........T
T..b.....T....d......d....T.....b..T
T3G.....TT....##....##....TT.....G8T
T.......T.....#/.VV./#.....T.......T
TT..........G....VV....G..........TT
T..b.....T....d......d....T.....b..T
T.........TTT..........TTT.........T
TTT...T....TT..........TT....T...TTT
T.....TT........S..S........TT.....T
T4G......G....c......c....G......G9T
T.......T..................T.......T
TT..b..TT....TTT....TTT....TT..b..TT
T......T.......TT..TT.......T......T
T5G...TT....a..........a....TT...G0T
T..................................T
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
```
- Five bases down each edge (players 1-5 west, 6-10 east; `0` = player 10),
  centre plateau with ramps and the Tavern. Player 3/8 is the exposed
  "middle" seat, 1/5 and 6/10 are the safer corners - normal for big team
  maps; mirrorX keeps opposite seats identical.
- Also usable for 4v4 (leave the middle seats empty and their mines as
  extra expansions) - the lobby just disables start slots.

### Map F - "Crossroads" (8 players FFA, 120x120, d4)

```
4x scale (30x30 chars = 120x120 tiles)
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
TT.....1G..TT....TT..G4.....TT
T...b.....TT......TT.....b...T
T.......a............a.......T
T.b....TT...G....G...TT....b.T
T.....TT..............TT.....T
T....T.T...c......c...T.T....T
T2..TTT....TT....TT....TTT..3T
TG.aT......T......T......Ta.GT
T............d..d............T
T.T...........##...........T.T
TTT...cTT....#..#....TTc...TTT
TT..G..T....S....S....T..G..TT
T........d.#......#.d........T
T.........#...FF...#.........T
T.........#...FF...#.........T
T........d.#......#.d........T
TT..G..T....S....S....T..G..TT
TTT...cTT....#..#....TTc...TTT
T.T...........##...........T.T
T............d..d............T
TG.aT......T......T......Ta.GT
T7..TTT....TT....TT....TTT..6T
T....T.T...c......c...T.T....T
T.....TT..............TT.....T
T.b....TT...G....G...TT....b.T
T.......a............a.......T
T...b.....TT......TT.....b...T
TT.....8G..TT....TT..G5.....TT
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
```
- Golems-in-the-Mist pattern: two starts per side of the square, a walled
  centre arena (cliff ring with 4 gaps) holding a Fountain of Health and
  four shops. d4 symmetry makes all 8 seats identical.
- Also the 4-player FFA map: use only seats 1, 3, 5, 7.

### Build order recommendation

1. **A (64x40, 1v1)** - port the current map to the new format first; it
   proves the loader, legend, symmetry and validator without needing a
   camera change.
2. **C (96x64, 2v2/4 FFA)** - first map needing scrolling + minimap, and
   the planned 2v2 target.
3. **B (80x56, 1v1)** - water/fords/ramps variety for 1v1 map choice.
4. **D (128x80, 4v4)** and **E (144x96, 5v5)** - after pathing is
   hierarchical and the net layer can carry 8-10 peers.
5. **F (120x120, 8 FFA)** - last; FFA needs alliance/defeat handling and
   is the heaviest on pathing.

### Notes for 8-10 players beyond the map itself
- **Networking**: with whispers, each command goes to N-1 peers, so 10
  players at ~4 msgs/s each is ~36 outgoing whispers/s per client - well over
  any sane budget. For 3+ players use one broadcast per lockstep turn on a
  group channel (`RAID`/`PARTY` addon messages, or a private chat channel
  for cross-group lobbies) and keep whispers for 1v1. Bundle all of a
  player's commands for a turn into one message and lengthen the turn (e.g.
  250 -> 400 ms) when the lobby has more than 4 players.
- **Simulation cost**: at 10 players x ~40 units, per-tick A* needs
  path caching, a flow field per common target, or a region graph.
- **Lobby**: map defines start slots and default teams; lobby lets the
  host leave slots empty/AI and pick FFA vs teams when the map allows it.

---

## Sources

- Blizzard melee map guidelines: https://classic.battle.net/mod/dev/melee.shtml
- Lost Temple: https://warcraft.wiki.gg/wiki/Lost_Temple_(Warcraft_III) , https://liquipedia.net/warcraft/Lost_Temple
- Turtle Rock: https://liquipedia.net/warcraft/Turtle_Rock
- Twisted Meadows: https://liquipedia.net/warcraft/Twisted_Meadows
- Echo Isles 2: https://liquipedia.net/warcraft/Echo_Isles_2 ; ESWC pool: https://www.gosugamers.net/warcraft3/news/2607-maps-and-rules-for-eswc-finals
- Terenas Stand LV: https://liquipedia.net/warcraft/Terenas_Stand_LV
- Gnoll Wood: https://liquipedia.net/warcraft/Gnoll_Wood
- Golems in the Mist: https://liquipedia.net/warcraft/Golems_in_the_Mist
- Twisted Turtles: https://liquipedia.net/warcraft/Twisted_Turtles
- Narcomarket Square: https://liquipedia.net/warcraft/Narcomarket_Square
- Lost Isles (mix of EI/TM/SV/TR zones): https://liquipedia.net/warcraft/Lost_Isles
- Plunder Isle 2.0: https://www.gosugamers.net/warcraft3/news/10488-plunder-isle-2-0-adds-spice-to-wc3l
- Map portal: https://liquipedia.net/warcraft/Portal:Maps
- Sea Turtle creeps: https://classic.hiveworkshop.com/war3/neutral/seaturtles.shtml
- Goblin Laboratory: https://warcraft.wiki.gg/wiki/Goblin_Laboratory_(Warcraft_III)
- Creeps: https://warcraft.wiki.gg/wiki/Creeps

# Other classic Warcraft III custom games

Survey of well-loved WC3 custom maps beyond Footmen Frenzy, Tower Defense,
Hero Defense and DotA (covered elsewhere), judged as candidates for our RTS
engine.

**Our constraints** (what "fit" means):
- deterministic Lua sim on a tile grid; WC3 units, buildings, heroes, A*;
- lockstep over WoW addon messages, ~4 msgs/s per player (commands, not
  state) - so games with few, coarse orders fit; twitch aiming/dodging fits
  badly because of input delay (one lockstep turn, ~250-500 ms);
- ~740x460 window; small maps preferred, scrolling acceptable;
- **must scale to 8-10 players** (new requirement). With whispers every order
  fans out to N-1 peers, so 8-10 players need one broadcast per turn on a
  group channel (RAID/PARTY addon messages or a private channel). That is the
  same network work for every game below; the ratings assume it exists and
  then judge how many orders/s the game *needs* per player.

Rating scale: **5** = natural fit, mostly reuses what we have; **3** =
doable with a few new systems; **1** = wrong genre for this engine.

Player counts and lengths are the usual public-lobby setups of the
classic (2004-2012) Battle.net era; many maps had many versions.

---

## Team / base-building games

### Castle Fight - fit 5
Two teams (classic 2v2 up to 5v5 - teams must be even) each own a castle
at one end of a lane-like field. Each player has only a builder; buildings
**spawn units automatically on a timer**, and those units walk and fight on
their own toward the enemy castle. Income arrives in intervals (plus a
bonus for kills); you choose races (Human, Orc, Undead, Elf, Nature,
Chaos...), unit-buildings, special buildings (auras, healing) and towers.
Each player has one "rescue strike" that clears their half once. A round
ends when a castle dies; matches are often best-of-several rounds.
*Players:* 2-10. *Length:* 10-25 min per round.
*Why it fits:* almost no micro - orders are "build X here" every few
seconds, so the network budget is trivial even at 10 players, and the
sim is our existing combat AI with auto-attack-move. Units are WC3 units.
*Needs:* auto-spawn buildings, lane attack-move AI for spawned units,
interval income, race/building lists (data), castle win condition,
rounds/score. Map: a long horizontal field (e.g. 128x48, mirrorX).

### Legion TD (brief - see the TD report) - fit 4
Each player builds fighters on their own lane that auto-fight waves at the
start of each round, then the survivors leak to the king; sends ("mercenaries")
go to the opposing team. 2v2 to 4v4, 30-45 min. Fits for the same reasons as
Castle Fight (place units, sim fights itself). Needs: wave phases,
per-player lanes, freeze-and-reset of units between rounds.

### Island Defense - fit 3
Asymmetric survival: up to ~9 **Builders** (races of small 1x1 units with
cheap walls/towers) versus 1-2 **Titans** (huge heroes) plus minions.
Builders harvest abundant wood and scarce gold, wall in with 1x1 gaps that
let builders walk but block 2x2 Titans/minions, tech to towers and units
and try to kill the Titan; the Titan feeds, levels and smashes bases, and
killed builders **become Titan minions** (source: Hive/SC2 remake).
*Players:* 10 (classic 9 vs 1). *Length:* 30-60 min.
*Fit:* our pathing already treats unit sizes and footprints, and walls are
just buildings. Low order rate for builders. The Titan player needs more
micro but one unit only. *Needs:* per-unit-size pathing (2x2 movers vs 1x1
gaps - important), wall buildings, repair, asymmetric win conditions,
"convert to minion", strong AI for the Titan when not human. Good 10-player
showcase.

### Troll and Elves (Troll Tag / "Trolls and Elves") - fit 3
1-2 **Trolls** hunt a team of **Elves** (6-10). Elves gather lumber, build
walls, gold mines/"wells" and towers inside a hiding spot and slowly earn
gold; trolls level up by killing and buy items. Elves win by surviving
to a timer (or, in some versions, killing the troll); trolls win by
killing all elves. *Players:* 8-12. *Length:* 20-40 min.
*Fit:* same building blocks as Island Defense but simpler economy (wood
only + passive gold). *Needs:* wall/upgradable-wall buildings, tag-style
win/timer, hunter hero with levelling, forest map with many hiding
pockets. Map 96x96-ish with dense trees.

### Tree Tag - fit 3
Ents/Infernals variant of the tag formula: **Ents** (many) hide in a huge
forest, build walls, towers and "seed" buildings for income; **Infernals**
(few) hunt and kill them; dead ents can be revived by teammates. *Players:*
8-12. *Length:* 20-40 min. Same needs as Troll and Elves plus revive.
Tree-heavy maps suit our tree tiles perfectly.

### Sheep Tag - fit 3
**Sheep** (most players) build **farms** - cheap 2x2 blockers that are the
whole game: wall mazes, stack farms, upgrade to tougher/invisible farms -
and must survive until a timer runs out; **Wolves** (2-4) chase, kill farms
and tag sheep (tagged sheep become ghosts/spirits; teammates can save them
in some versions). Rounds alternate roles. *Players:* 8-12. *Length:*
10-25 min per round. *Fit:* trivial units, but **chasing and dodging is
the whole game**, which suffers from lockstep input delay. Still very
playable if movement orders are simple click-moves. *Needs:* tag/save
rules, role swap, farm upgrades, timer. Map ~80x80 open grass.

### Vampirism (Vampirism Fire, Zero, Beast...) - fit 3
Humans (up to ~10) spawn in a town at night, rush to claim a base spot,
build walls, gold-income buildings and towers; 1-2 **Vampires** start in
their own zone, feed on kills, buy items and break bases. Humans win by
surviving to dawn / killing the vampires. Some versions: humans 10 vs
vampires 2, rounds 25-45 min (Vampirism Beast/Fire variants; long versions
2 h). *Players:* 10-12. *Fit/needs:* same family as Island Defense (walls,
towers, income buildings, a hunter hero) plus a day/night timer.

### Hero Line Wars - fit 4
Two to four teams on parallel lanes; each player has **one hero** that
defends their lane. You spend gold to **send creeps** to the enemy lane;
each send raises your **income** (paid every ~20 s). Leaking creeps costs
lives; lose all lives and you are out. Gold also buys hero items and
skills. *Players:* 6-12 (classic 3v3 to 6v6). *Length:* 30-60 min.
*Fit:* hero + creep combat we already have; sends are low-rate orders.
*Needs:* lanes, send menu with income formula, lives, hero shop, hero
respawn. Map: one lane per player, 8-10 lanes need a wide map but only
the own lane needs the camera.

### Wintermaul Wars - fit 4
Versus tower defence: each player mazes towers on their lane; waves
come at everyone, and players **send extra creeps** to opponents to
raise income (the TD agent covers the base TD). 2v2/4v4, 30-45 min. Same
blocks as Hero Line Wars minus the hero plus tower mazing.

### Risk-style (Risk Europe / Risk Devo, Lordaeron Tactics, Battle for Middle Earth-style) - fit 4
Free-for-all on a map of **territories** (Europe, Lordaeron...). Each owned
territory and city adds to periodic income; you buy units in owned cities
and march them to capture neighbouring territories (a unit standing in a
region capture point flips it). Diplomacy (alliances, gold gifts) is a big
part. *Players:* 8-12. *Length:* 45-120 min.
*Fit:* slow, strategic, few orders - excellent for lockstep, and the
"region capture" model is cheap to sim (thousands of small skirmishes,
mostly melee). *Needs:* region/territory layer over the grid, capture
points, territory income, unit purchase at cities, FFA diplomacy
(alliance flags), a big map that needs a strong minimap. Length is the
main issue for an in-WoW minigame; a "short" variant (fewer regions,
victory at 50%) helps.

### Elimination Tournament - fit 3
Each player picks a hero; rounds of **arena duels / team fights** on a small
arena; between rounds you buy items and skills. Losers are eliminated or
lose lives. *Players:* 8-12. *Length:* 30-45 min. *Fit:* hero combat
exists; arenas are tiny maps; spectating while others fight solves the
"waiting" problem. *Needs:* pick phase, arena rounds, between-round shop,
spectator camera.

### Angel Arena - fit 2
Hero arena (team vs team, often 5v5) where heroes farm creep
fields of increasing difficulty and duel in periodic arena fights; the
team that reaches a kill/round target wins. 30-60 min. *Fit:* hero-only,
large ability pool, item-heavy - needs a full ability system and lots of
content. Low priority.

### Tides of Blood - fit 2
Hero-based 3-lane team map (Dota-like) with a heavier RTS flavour:
heroes plus creeps plus buildable defences; 4v4/5v5, 40-60 min. *Fit:*
Dota-like needs (see DotA report); our engine handles creeps and heroes but
not the ability depth. Covered by the DotA option.

### Enfo's Team Survival - fit 3
Up to ~12 players, each picking a hero from many classes, defend a central
position against escalating **waves** while two teams **race to survive**
longer than the other (classic Enfo's is team vs team survival with
shared waves; you can also send bonus creeps/spells at the other team).
Rounds 30-60 min. *Fit:* our hero + wave + creep pieces; the class/ability
breadth is the cost. Close to the Hero Defense report.

### Murloc Nation - fit 2
Squad-based "murloc hero" map: each player controls a murloc that grows
via a skill tree; teams of murlocs fight on a mid-sized map; 30-45 min.
Mostly hero/ability content; little RTS. Low priority.

### Cube Defense - fit 3
Co-op defence: players (4-10) build towers and units around a shared
"cube" in the centre while waves come from all sides; mazing
is less important than coverage. 30-45 min. Reuses TD blocks; fine as a
TD variant, see TD report.

### Battleships / Battle Tanks - fit 3
Team games where each player controls **one vehicle** (ship or tank) and
buys upgrades/weapons; teams fight over lanes or capture points (Battleships
Crossfire is 3v3/6v6 sea combat with ships bought at harbours and
continuous income; Battle Tanks is tank arena with upgrades). 30-60 min,
8-12 players. *Fit:* one unit per player, simple combat - lockstep ok
because weapons are auto-attacks with range. *Needs:* ship/tank units
(not WC3 standard melee units - Battleships uses WC3 boats), capture
points, upgrade shop, respawn. Water pathing for Battleships.

---

## Arena / skill-shot / party games

### Warlock (Warlocks) - fit 1
8-10 players, each a warlock on a shrinking circular **arena over lava**.
Spells (Fireball, Homing, Lightning, Teleport, etc.) mostly do knockback;
being pushed onto lava burns you. Last warlock standing wins the round;
between rounds you buy/upgrade spells. 10 rounds, ~20-30 min. Hugely
loved, but **pure skill-shot dodging** - lockstep input delay at our
message rate ruins aiming and dodging. Also needs projectile physics and
knockback. Not a fit.

### Pudge Wars / Pudding Wars - fit 1
5v5 Pudges separated by an impassable river; the only main spell is
**Meat Hook**, aimed to drag enemies across and kill them. First team to
50 kills wins (src). 20-40 min. Pure skill shot, same problem as Warlock.
Not a fit (a slow "turn-based hook" party variant could work, but it
wouldn't feel like Pudge Wars).

### Run Kitty Run - fit 1
Co-op (up to ~10): kitties run through a long track of moving wolf
mobs; touching a wolf kills you; teammates revive by touching your
circle; levels get harder. 30-60 min. Entirely about precise dodging;
input latency kills it. Not a fit.

### Uther Party - fit 2
Mario Party-style collection of **minigames** (races, dodge, sumo,
memory, mass-unit fights, etc.) for up to 8-12 players; points per minigame,
winner after N games. ~30-45 min. Each minigame is its own mini project;
many are dodge-based (bad fit). A cut-down version with only the
latency-tolerant minigames (unit battles, auctions, memory, "last
footman standing") is possible, but it's a content mountain. Low priority,
though a few minigames could become standalone items in our casino.

### Rabbits vs Sheep - fit 2
Sheep (many) vs rabbits/wolves variants of the tag genre, often with hunger
and farming; essentially a Sheep Tag sibling. Same rating reasons.

### Bomberman (WC3 Bomberman maps) - fit 2
Grid-based Bomberman with WC3 models (4-8 players): drop bombs, blast
crates, pick power-ups. Grid logic is trivial for us, but the game needs
quick reaction and the lockstep delay hurts. Playable with longer fuses
and slower movement; better as its own minigame than inside the RTS.

### Mafia - fit 1
Social-deduction (Werewolf/Mafia) wearing WC3 models: day votes, night
kills, roles. 8-12 players, 20-40 min. Chat- and vote-driven; doesn't need
an RTS engine at all - would be a separate chat game.

---

## RPGs

### Twilight's Eve / Gaias Retaliation / Diablo-style ORPGs - fit 1
Co-op hero RPGs (up to ~6-10) with quest chains, bosses, loot and
save/load codes; 1-3 h sessions, often continued across games via codes.
Needs a huge content base, ability systems, inventory - and long sessions
don't suit an in-WoW minigame. Not a fit.

---

## Ranking - top 8 for us

Weighting: reuse of our engine (units, buildings, heroes, AI) >
tolerance of lockstep delay > works at 8-10 players > content cost.

| # | Game | Players | Why |
|---|---|---|---|
| 1 | **Castle Fight** | 2-10 | Auto-spawn buildings + our combat AI; nearly zero micro so lockstep at 10 players is easy; short rounds. Best value. |
| 2 | **Hero Line Wars** | 6-10 | Our heroes and creeps + a send/income system; low order rate; clean scaling by adding lanes. |
| 3 | **Island Defense** | 10 (9v1) | The definitive 10-player WC3 asymmetric game; walls + towers + one big hunter; reuses building/pathing; good AI-Titan fallback. |
| 4 | **Risk-style territory game** | 8-10 FFA | Slow, strategic, latency-proof; territory layer is cheap; offer a short variant to keep games under ~45 min. |
| 5 | **Legion TD** (with TD report) | 4-8 | Placement-only fighting; shares wave/lane code with #1 and #2. |
| 6 | **Troll and Elves / Tree Tag** | 8-12 | Shares 90% with Island Defense (one tag-family framework: hunters vs builders, walls, timer). |
| 7 | **Wintermaul Wars** | 4-8 | Versus TD with sends - reuses #2's send/income and the TD report's mazing. |
| 8 | **Elimination Tournament** | 8-10 | Small arenas + hero pick/shop; spectating fills downtime; good use of our hero system once abilities are richer. |

Honourable mentions: **Sheep Tag** and **Vampirism** (same tag framework as
#3/#6 - cheap once that exists), **Battleships** (if we add water units).
Avoid: Warlock, Pudge Wars, Run Kitty Run (twitch aiming/dodging), ORPGs
(content), Mafia (not an RTS).

Shared building blocks, in the order they unlock the most games:
1. Group-channel lockstep for 8-10 peers (needed by every entry above).
2. Auto-spawn buildings + attack-move lane AI + interval income (#1, #2, #5, #7).
3. Send-creeps-to-opponent with income bonus (#2, #5, #7).
4. Walls, size-aware pathing (1x1 gaps vs 2x2 movers), repair (#3, #6, Sheep Tag, Vampirism).
5. Asymmetric roles + timer win conditions (#3, #6, tag games).
6. Territory/region layer with capture and income (#4).
7. Round structure with shop phase and spectator camera (#1 rounds, #8).

---

## Sources

- Castle Fight overview/remake: https://sc2mapster.com/projects/castle-fight , https://www.curseforge.com/sc2/maps/wc3-castle-fight
- Island Defense rules (remake): https://www.sc2mapster.com/projects/island-defense-dawn-new-age
- Vampirism (team sizes, base spots, round length): https://www.hiveworkshop.com/threads/97008 , https://www.curseforge.com/sc2/maps/vampirism-zero
- Hero Line Wars (sends, income every 20 s, lives): https://tomhai.itch.io/hero-line-wars
- Enfo's Team Survival history: https://www.hiveworkshop.com/threads/enfos-team-survival-again.314128/
- Wintermaul Wars / versus TD: https://www.giga.de/tipp/die-beliebtesten-tower-defense-maps-im-ueberblick-warcraft-3-reforged/ , https://www.hiveworkshop.com/threads/tower-defense-for-beginners.215596/
- Pudge Wars rules: https://steamcommunity.com/groups/d2pudgewars
- Warlock (Warlock Brawl lineage): https://gordox.itch.io/warlock
- Sheep Tag (sheep vs wolves, farms): https://lutris.net/games/sheep-tag-2/ , https://sheeptag.createaforum.com/community-discussion/guides/
- Risk Europe / Risk in WC3: https://www.gamestar.de/artikel/fans-vereinen-risiko-und-warcraft-3-zu-einem-spiel,3419179.html , https://www.hiveworkshop.com/threads/disaster-in-europe-ideas.183965/
- Uther Party: https://www.hiveworkshop.com/threads/what-is-your-favorite-warcraft-3-map-right-now-all-time.348738
- General custom map lists: https://rankedboost.com/warcraft-3/custom-maps/ , https://www.giga.de/tipp/custom-maps-herunterladen-und-spielen-so-gehts-warcraft-3-reforged/
- Note: details for Troll and Elves, Tree Tag, Rabbits vs Sheep, Murloc Nation, Angel Arena, Tides of Blood, Battleships/Battle Tanks, Elimination Tournament, Cube Defense, Bomberman, Mafia and the ORPGs are from general community knowledge; search found no reliable rules pages, so exact numbers vary by version.

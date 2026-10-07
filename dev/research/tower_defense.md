# Tower Defense / Tower Wars — research for our WC3-style RTS

Goal: rebuild one or two classic WC3 tower-defense custom maps inside our deterministic Lua RTS
(tile grid, now 64x40; A* pathing; towers that shoot with WC3 attack/armor types; Human/Orc
units; 2-player lockstep + computer AI). **Requirement: custom games must scale to 8–10 players.**

Legend: **[src]** = taken from a source listed at the end; **[conv]** = genre convention or widely
remembered, but not confirmed by a fetched source (treat numbers as approximate); **[ours]** = our proposal.

Note on sources: most of the original WC3 map pages (wc3c, old forums, GameFAQs) are offline or
only describe hosting. Where a number could not be confirmed, it's marked [conv]. Element TD
numbers partly come from the Element TD community forum, which mixes WC3 and Element TD 2 versions.

---

## 1. The genre in one paragraph

Each player gets a **builder** (usually an invulnerable, non-blocking flying worker [src: Hive TD
tutorial]) and builds towers in a field. Creeps spawn on a timer, walk from spawn to exit, and
every creep that **leaks** (reaches the exit) costs a **life**; at 0 lives you lose [src]. In
**mazing** maps you build on the path itself to force a long snake route; the one hard rule is
**you may not fully block** the path [src]. After ~30–60 levels, or after a final boss, you win
[src]. **Tower Wars** maps (Line Tower Wars, Wintermaul Wars, Legion TD) add PvP: you spend gold on
**sends** (extra creeps into an opponent's lane) that also raise your **income** [src].

Three families:

| Family | Example maps | Who sends the creeps | Mazing? | Scales to 8–10 by… |
|---|---|---|---|---|
| Co-op maze TD | Wintermaul, Element TD, Gem TD, Burbenog, Island TD | Computer (fixed wave list) | Yes | one build area per player, shared or per-player lives |
| Tower Wars | Line Tower Wars, Wintermaul Wars | Computer + **players** (sends) | Yes, inside your own lane | one lane per player; ring or team versus |
| Legion-style | Legion TD (Mega), Legion TD 2 | Computer + players (mercenaries) | No — fixed lane, "towers" are units that fight | 4v4 teams, one lane per player |

---

## 2. Wintermaul TD (co-op maze TD, the archetype)

| Aspect | Details |
|---|---|
| Players | Up to 8 originally, 9 in Redux / One Revamped / v12 [src] |
| Map | 96x96 map (88x88 playable) [src] |
| Structure | **Co-op**: everyone shares one life pool; a leak costs all players a life; 0 lives = everyone loses [src] |
| Lives | **50** by default (One Revamped, changeable with `-s`) [src] |
| Layout | Each player has his own build area with his own **spawn point** [src: Redux "multiple spawn points, one per player area"]. Creeps walk through the player areas, then the routes **merge** into a shared middle section that leads down to one exit [conv]. So the merged section gets everyone's leaks: a strong middle mazer covers for weak players [conv] |
| Mazing | Players build on the path to make a long snake; the creeps go "whichever route is open to the next waypoint" [src]. Blocking is handled by versions in different ways: old versions made creeps attack the blocking tower [conv]; Redux **auto-sells blocking towers** [src]; One Revamped has an **anti-block system** for the spawn areas and "lane enforcement" (a tower can't shoot creeps outside its own lane) [src] |
| Juggling | Exploit: alternate blocking one side then the other so creeps turn back and forth forever [src: Wikipedia]. Later versions added an **anti-juggle** system [src] |
| Waves | **30 levels** (v12) [src]; One Revolution has **40** [src]. Waves come on a **timer**, not when the previous one is cleared [conv], so a slow defence piles creeps up. Air levels need anti-air [src]. Armor type rotates every 5 levels, so "typing" (picking damage types) matters [src]. A final boss (Duke Wintermaul) [src] |
| Creep types | Ground, **air** (ignores the maze, flies straight to the exit), **boss**, mixed waves [src]; immune/spell-immune and fast waves exist in most versions [conv] |
| Builders/races | v12: 42+ unique towers incl. Earth, Undead, Crystal towers [src]. Redux: 7 races (Human, Orc, Night Elf, Undead, Goblin, Wind, Insect) [src]. One Revolution: 49 races [src]. One Revamped: Single Race or **Double Race** (2 builders) [src] |
| Towers | Upgradeable lines; splash, single target, slows, stuns, poison, bash; Human has a **Bank** tower (gold interest) [src] |
| Economy | **Shared bounty** in Redux: every kill gives every player gold (no kill-stealing) [src]; a leaver's gold is split among the others [src]. Lumber is used to pick races/builders [src: One Revamped] |
| Selling | Sell is allowed; cancelling a build/upgrade refunds 100% [src]. Normal sell ~75% [conv] |
| Difficulty | Easy / Normal / Hard (Redux); up to Impossible = 300% creep HP (One Revamped) [src]. The first player picks [src] |
| Commands | `-next` (show next wave), `-move` (unstick creeps), `-repick`, `-random` [src] |

**Why it's fun:** shared lives makes it social ("Blue is leaking!"), mazing is a puzzle, the
merged middle is a team project, and air/armor-type waves punish one-trick builds.

---

## 3. Element TD (co-op maze TD with element picks)

| Aspect | Details |
|---|---|
| Players | Up to 8 (WC3) [conv: "(8) Element TD" map title on wc3c]; each player mazes his own area with his own creeps [conv] |
| Lives | 50 per player [conv] |
| Waves | ~55–60 waves + an endless boss in late versions (ETD2: **55 waves + endless boss**) [src]. The famous "Ronald" round is an endgame boss wave [src] |
| Modes | All Pick, Random (SR), Chaos (random elements), Short, Extreme, difficulty up to Very Hard [src] |
| Elements | Light, Darkness, Water, Fire, Nature, Earth [src]. **Cycle** Light > Darkness > Water > Fire > Nature > Earth > Light: **200%** vs the element it beats, **50%** vs the one that beats it, 100% otherwise [src] |
| Element picks | You get a pick ("summon"/lumber) every **5 waves** (1 + 11 picks by wave 50) [src]. A pick can instead raise your **interest rate** [src] or buy extra lives [src: ETD2] |
| Starting towers | Arrow and Cannon. Cannon **75 gold, 80 damage, splash** [src]. Basic towers **sell for full price** [src] |
| Element towers | Single element L1–L4: **175 / 750 / 3,000 / 9,000** gold; dual L2–L4: **600 / 1,700 / 4,700**; triple L3–L4: **1,500 / 5,000** [src]. Single towers gain ~7x stats per level, dual/triple ~5x [src]. 15 dual + 20 triple towers [src] |
| Support towers | Blacksmith (+15/30/100% damage to 4 towers), Well (+15/30/100% attack speed), Trickery (clone a tower), slows (max **66%** slow), armor reduction, damage amplification [src] |
| Economy | **Interest 2% every 15 s** of wave time (ETD2); pauses when you lose a life [src]. Wave 40 ≈ 20 gold/kill; wave 50 interest ≈ 1,200 gold/15 s [src]. Selling ≈ 99% [src] → a "sell & rebuild" meta |
| Creep types | Fast (**375 move speed vs 300**), Mechanical (invulnerable **3 s every 12 s**), Undead (revive once after **5 s** at **33% HP**), Healing (heal 20–30% to nearby on death), Regeneration (2.5%/s), Vengeful, Turbo (dash), Timewarp [src]. Element creeps carry an element armor [src] |
| Scoring | Speed, "clean" (no leaks), difficulty, net worth, endless survival [src] |

**Why it's fun:** the element pick is a meaningful build decision every 5 waves; the counter
cycle teaches typing; combining elements gives a long upgrade tree.

---

## 4. Line Tower Wars (versus, one lane per player)

| Aspect | Details |
|---|---|
| Players | **2–11** (v18.5) [src]; map **172x51** (192x64) [src]. Team version exists ("Team Line Tower Wars") [src] |
| Layout | Every player owns **one long straight lane** side by side; creeps spawn at one end and leave at the other [src]. Players build towers in their own lane and **maze** inside it [src] |
| Who attacks whom | Sends go to **the player to your right**; you defend against the player to your left (a ring) [src]. A send skips your lane and runs down the target's lane [src] |
| Lives | **30** in common versions [src]; leak = -1 life; 0 lives = out [src]. Last player alive wins [src] |
| Income | Gold income paid on a timer: **10, 15 or 20 s** depending on version [src]. Every send raises your income permanently [src]; cheaper sends give slightly better income per gold than expensive ones [src] |
| Sends | Bought at shrines (2 shrines in v18.5) [src]. Fast runners are the best life-stealers [src] |
| Towers | Simple versions: e.g. Shredder 50g (fast, short range), Launcher 100g (slow, long range), Hammer 200g [src]. Advanced versions: elemental towers + tech upgrades [src] |
| Blocking | You may not fully block; some versions punish blocking by removing your towers [src] |
| Background waves | Most versions also spawn timed computer waves into every lane so a player who never sends still has pressure [conv] |

**Why it's fun:** one decision per income tick — towers (defence) or sends (attack + income).
A strong player snowballs income; a ring means everyone is attacked by exactly one neighbour.

### Wintermaul Wars (team tower wars)
Two teams of up to **4** players, each building like normal Wintermaul, defending the team's lives,
and sending creeps to the other team [src]. Same design as Line Tower Wars, but team versus.

---

## 5. Legion TD (Mega) (team versus, units instead of towers)

| Aspect | Details |
|---|---|
| Players | 2, 4, 6 or **8** — two teams: **1v1 … 4v4** [src] |
| Layout | Symmetric: each player has a **lane**; each team has a **King** at the end of its lanes [src]. Central **arena** for events at levels 10 and 20 [src] |
| Core loop | Build "towers" that are really **units**; when the wave starts they fight the wave creeps, then reset to their placed position for the next wave [src]. No mazing: units fight in a fixed lane |
| Waves | **30 levels** + "Legion Lords"; bosses at **10, 20, 30** [src]; level 5 is a **flying** wave [src]. `-x3` mode triples creeps [src]. All lanes get the same wave at the same time [conv] |
| Leaks | Creeps that get through walk to your team's **King**, who fights them; King dies = team loses [src]. Leaked creeps give reduced bounty (`-gg` mode) [src] |
| King | Upgrade with lumber: **80 lumber per upgrade, +3 income** [src]. Max King: 18,750 HP, ~364–374 damage, ~100 HP/s regen, auras, stomp, shockwave [src]. King can move at level 30 [src] |
| Builders | 10–16 races (Beast, Mech, Nature, Shadow, Element, Ghost, Demi-Human, Marine, Elf, Arctic, Goblin, Paladin, Orc, Undead…), each with **6 tiers** of units, most upgradable 1–2 times [src] |
| Damage/armor | WC3 types: Normal, Piercing, Magic, Siege, Chaos vs Light, Medium, Heavy, Fortified, Unarmored, at **70–130%** [src] |
| Economy | **Gold** from kills + bonus gold per wave [src]. **Lumber** from **wisps** bought with gold (target ~7 wisps by level 4–9) and lumberjack upgrades [src]. Food from farms limits army size [src] |
| Sends (summons / mercenaries) | Cost lumber (later gold + lumber); each raises your income; each has a **cooldown** so you can't send infinitely [src]. Example (Mercenary builder): 25 wood → +1 income; 25 g + 50 wood → +2; 50 g + 75 wood → +3; 100 g + 100 wood → +5 [src]. Demon: 1,500 lumber, 2 min cooldown [src] |
| Income benchmarks | lvl 5: 25–35, lvl 10: 110–120, lvl 12: 180–200, lvl 17: 380–420, lvl 21: 700–750 [src] |
| Modes | All Pick, All Random, Single Draft, Host Pick; Hour Glass, Get Gold, Master Mind, Change Builder, Limit Income, x3 [src] |
| Win | Kill the enemy King [src] |

**Why it's fun:** it's an RTS battle every 40 s without micro; build order + counters; the
send/income choice of Line Tower Wars; team-mates' kings and lanes are linked.

**Fit with our engine:** very good — our Human/Orc units, attack/armor types and unit AI are
already there; Legion TD is mostly "spawn my placed units at wave start, reset afterwards".

---

## 6. Gem TD (solo maze puzzle with randomness)

| Aspect | Details |
|---|---|
| Players | Solo map; multiplayer = each player on his own copy, racing for score [conv] |
| Core rule | Each round you place **5 gem towers** anywhere (except checkpoints). Each is a random gem; you **keep 1**, the other 4 turn into **rocks** (maze walls) [src] |
| Layout | Creeps must pass **5–6 checkpoints in order** [src] → mazing between checkpoints, not one long path |
| Waves | **42 levels** [src]; **air every 4th level** (4, 8, 12 … 48 in v7.9) [src] |
| Gems | 8 types: Amethyst, Aquamarine, Diamond, Emerald, Opal, Ruby, Sapphire, Topaz [src], in qualities Chipped → Flawed → Normal → Flawless → Perfect [conv]. Gold buys **chance upgrades** (better quality odds) or extra lives [src] |
| Combos | 13 specials (Black Opal, Bloodstone, Dark Emerald, Gold, Jade, Malachite, Pink Diamond, Red Crystal, Silver, Star Ruby, Tourmaline, Uranium, Yellow Sapphire), usually from **3 gems** [src]; 92 towers in total [src] |
| Lives | HP-like lives (100) [conv] |

**Why it's fun:** a fresh puzzle every round; no economy grind; rocks are free maze walls.
**Fit:** great for solo/vs-AI; scales to 8–10 only as "everyone plays the same seed" (score race).

---

## 7. Burbenog TD and Island TD (short)

- **Burbenog TD**: co-op maze TD known as a hard map [src: SweClockers]; we found no reliable
  details beyond that. Remembered as one builder per player with many race/tower choices [conv].
- **Island TD**: we found no reliable source. Remembered as each player defending his own
  small island area with fixed creep paths [conv]. Not recommended as a reference.

---

## 8. Common rules worth copying

| Rule | What the maps do | Our proposal |
|---|---|---|
| Can't fully block | Auto-sell (Redux), anti-block system (One), creeps attack the blocker (old) [src] | **Refuse the placement** (red ghost). Before accepting a build, run one BFS from the lane's spawn to its exit with the new tiles blocked; also check that every live creep's tile still reaches the exit. No juggling possible [ours] |
| Air creeps | Ignore the maze, fly to the exit [src] | Straight line spawn → exit; only towers with `air = true` can hit them [ours] |
| Creep waves on a timer | Wintermaul, LTW [conv] | Fixed 35–45 s cadence; `-next` panel shows the next wave [ours] |
| Selling | 75% normal, 100% for cancels / basic towers (ETD) [src/conv] | 100% if built during the current build phase, else 75% [ours] |
| Armor/element counters | Rotating armor types (WM), element cycle (ETD) [src] | Reuse our WC3 attack×armor table; wave armor types rotate [ours] |
| Shared bounty | Redux [src] | Co-op: every kill pays every player in that team the bounty [ours] |
| Interest | ETD 2% / 15 s, WM Bank tower [src] | Optional: 2% of banked gold at wave end, capped [ours] |

---

## 9. Scaling to 8–10 players

### 9.1 The geometry problem
Our towers are **2x2**. A creep path needs ≥1 free tile. On 64x40:

| Players | Lane per player on 64x40 | Room for a maze? |
|---|---|---|
| 1–2 | 32x40 (or 64x20) each | Plenty — Wintermaul-style mazing |
| 4 | 16x40 each (or 2 rows of 32x20) | Good — about 7 towers across |
| 8 | 8x40 each | Poor — 3 towers across, only a zig-zag |
| 10 | 6x40 each | No real maze with 2x2 towers |

**Recommendation [ours]:** make the TD map size depend on the player count, with a fixed
**lane module of 12 wide x 40 tall** (10 tiles buildable + 1-tile wall each side), creeps
spawning at the top and leaving at the bottom.

| Players | Map size (lanes x 12 + 4 border) | Notes |
|---|---|---|
| 1–2 | 64x40 (current) — 2 wide lanes of ~30x40 | No change needed |
| 4 | 52x40 | Fits inside today's 64x40 |
| 6 | 76x40 | |
| 8 | 100x40 | |
| 10 | 124x40 | Or 2 rows of 5 lanes: 64x82 |

If the engine must stay at 64x40, use **1x1 "maze blocks" and 1x1 TD towers** in TD mode
(Gem TD's rocks are 1 tile anyway), giving 10 lanes of 6x40 with real mazing.

### 9.2 Pathing cost
With 10 lanes x ~30 creeps, per-creep A* gets expensive. Use **one flow field (BFS distance
map) per lane**, recomputed only when a tower is built/sold in that lane; each creep steps to
the neighbour tile with the lowest distance. Deterministic, O(lane tiles) per change, and the
same BFS doubles as the "can't block" check [ours].

### 9.3 Co-op vs versus splits

| Players | Co-op (vs computer) | Versus |
|---|---|---|
| 1 | Solo Wintermaul-lite or Gem TD | vs computer AI that sends (LTW) |
| 2 | 2 lanes, shared lives (50) | 1v1 LTW: each sends to the other |
| 4 | 4 lanes, shared lives | 2v2 team LTW (send to either enemy lane, or round-robin) or FFA ring |
| 6 | 6 lanes | 3v3 or FFA ring |
| 8 | 8 lanes, shared lives; optional merged "final gate" | **4v4 teams** (Legion TD / Wintermaul Wars) or FFA ring |
| 10 | 10 lanes | 5v5 teams or FFA ring |

- **FFA ring** (LTW) [src]: player i sends to player i+1 (skipping eliminated players). Simple and
  scales to any number; eliminations shrink the ring.
- **Teams** [ours]: each team has a shared life pool (or a King, Legion-style); a send goes to the
  enemy-team lane with the fewest sends queued this wave (deterministic tie-break by slot), so 4v4
  works without targeting UI.
- Empty slots / leavers: their lane keeps receiving waves but is auto-defended by the computer AI,
  or the lane is closed and its sends are re-routed [ours]. Redux splits a leaver's gold [src].
- **Lockstep:** sends and builds are just commands; with 10 players the command volume is small
  (a few per income tick).

---

## 10. Recommended first version for us

**Copy: Line Tower Wars, with Wintermaul-style mazing inside each lane, plus a co-op mode.**
Why: one lane per player isolates pathing; the same code gives co-op (computer waves, shared
lives) and versus (sends + income); it scales linearly to 10 players; it reuses our towers,
attack/armor types and A*/BFS. **Second version: Legion TD**, since our units can be the fighters.

### 10.1 Rules (v1) [ours]
- One flying **Builder** per player (no collision, can't attack).
- Build phase 20 s before wave 1, then a wave every **40 s** regardless of clears.
- Lives: co-op **50 shared**; versus **30 per player** (or per team).
- Start gold **100**. Kill bounty `1 + floor(wave / 4)`. Wave-end bonus `10 + 2*wave`.
- Versus income: every **15 s**, pay `income` gold (start 10). Sends add to income.
- Sell: 100% in the same build phase, else 75%. Can't block (BFS check).
- Win: co-op survives wave 30 (boss); versus last player/team with lives.

### 10.2 Towers (6 lines x 3 levels) — all 2x2 (or 1x1 in compact mode)

| Tower | Cost (L1/L2/L3) | Damage type | Role | Hits air? |
|---|---|---|---|---|
| Maze Block | 2 | — | Wall only, no attack | — |
| Arrow Tower | 15 / 30 / 60 | pierce | Cheap single target, range 6 | Yes |
| Cannon Tower | 25 / 50 / 100 | siege, splash 1.5 | Groups | No |
| Frost Tower | 30 / 60 / 120 | magic | Slow 30/40/50% (max slow 66% like ETD) | Yes |
| Poison Tower | 30 / 60 / 120 | normal + DoT | Good vs regen/boss | No |
| Sky Tower | 25 / 50 / 100 | pierce, x2 vs air | Anti-air only | Air only |
| Watch Tower (detector) | 40 | — | Reveals invisible in range 7 | — |

Damage roughly doubles per level so value per gold stays flat; tune with the bot harness.

### 10.3 Waves (30) [ours]

HP curve: `hp(w) = round(60 * 1.16^(w-1))` → w1 60, w5 109, w10 228, w15 478, w20 1,007,
w25 2,115, w30 4,434. Armor `floor(w/5)`. 12 creeps per wave; special waves:

| Waves | Type | Count | HP | Speed | Notes |
|---|---|---|---|---|---|
| normal | Ground (Human/Orc look) | 12 | hp(w) | 1.0 | Armor type rotates Light → Medium → Heavy every 5 waves |
| 5, 15, 25 | **Air** | 10 | 0.8x | 1.0 | Fly straight spawn → exit |
| 7, 17, 27 | **Fast** | 14 | 0.6x | 1.6 | Like ETD fast (375 vs 300) |
| 9, 19, 29 | **Spell-immune** | 12 | 1.0x | 1.0 | Ignores magic damage and slows |
| 13, 23 | **Invisible** | 12 | 0.8x | 1.0 | Needs a Watch Tower |
| 11, 21 | **Regen / Undead** | 12 | 0.9x | 1.0 | Regen 2%/s, or revive once at 33% |
| 10, 20, 30 | **Boss** | 1 (+4 adds) | 15x | 0.8 | Leak costs 5 lives; w30 is the final boss |

### 10.4 Sends (versus only) [ours, after LTW / Legion]

| Send | Cost | +Income | Unit | Cooldown |
|---|---|---|---|---|
| Kobold | 10 | +1 | weak, cheap (best income/gold, as in LTW) | none |
| Wolf | 25 | +2 | fast runner | none |
| Footman / Grunt | 50 | +3 | armored | 3 s |
| Gryphon / Wind Rider | 80 | +4 | **air** | 5 s |
| Ogre | 150 | +6 | high HP, slow | 10 s |
| Shade | 120 | +5 | invisible | 10 s |

Sends join the target's next wave (or arrive within 3 s). Send HP scales with the current wave
so late cheap sends are still relevant.

### 10.5 What changes by player count (v1) [ours]

| | 2 players | 4 players | 8–10 players |
|---|---|---|---|
| Map | 64x40, 2 lanes ~30 wide | 52x40, 4 lanes | 100–124x40 (or compact 1x1 mode on 64x40) |
| Co-op | shared 50 lives | shared 50 lives | shared 50 lives (or 75 for 10p); bounty shared |
| Versus | 1v1 | 2v2 or FFA ring | 4v4 / 5v5 or FFA ring |
| Pathing | flow field per lane | same | same; recompute only the lane that changed |
| UI | normal | normal | minimap with lane lives; camera hotkeys per lane |

---

## 11. Sources

- Hive Workshop — Tower defense for beginners: https://www.hiveworkshop.com/threads/tower-defense-for-beginners.215596/
- Hive Workshop — Ralle's tower defence guide: https://www.hiveworkshop.com/forums/f278/ralles-tower-defence-guide-34870/
- Hive Workshop — Wintermaul Redux 1.08g: https://www.hiveworkshop.com/threads/wintermaul-redux-1-08g.121401/
- Hive Workshop — Wintermaul One Revamped v4b: https://www.hiveworkshop.com/threads/wintermaul-one-revamped-v4b.212876/
- wc3maps — Wintermaul TD v12.0: https://wc3maps.com/map/299977
- Wintermaul One Revolution: https://wintermaul.one/
- ENT Gaming — Wintermaul TD thread: https://entgaming.net/forum/viewtopic.php?f=9&t=7409
- Wikipedia — Tower defense: https://en.wikipedia.org/wiki/Tower_defense
- Wikipedia — Legion TD: https://en.wikipedia.org/wiki/Legion_TD
- Hive Workshop — Legion TD Mega 3.5: https://www.hiveworkshop.com/threads/legion-td-mega-3-5-b4-3-41-unprotect.194224/
- Legion TD Mega Book (strategy guide 3.41): https://legiontd.forumotion.com/t429-legion-td-mega-book-overall-strategical-guide-3-41
- gaming-tools — Legion TD: https://gaming-tools.com/warcraft-3/legion-td/
- Legion TD 2 Wiki — Mercenary: https://legiontd2.wiki.gg/wiki/Mercenary
- EleTD forum — Beginner strategy guide: https://forums.eletd.com/topic/95770-beginner-strategy-guide/
- EleTD forum — Basics of Element TD (WC3): https://forums.eletd.com/topic/945-basics-of-element-td/
- Element TD tips (Warcraft Club blog): http://footmenfrenzy.blogspot.com/2009/07/element-tower-defense-tips-n-tricks.html
- Element TD 2 on Steam / MobyGames: https://www.mobygames.com/game/143036/element-td-2/
- Hive Workshop — Line Tower Wars v18.5.01: https://www.hiveworkshop.com/threads/line-tower-wars-v18-5-01.250346/
- Line Tower Wars walkthrough (ayumilove): https://ayumilove.wordpress.com/2009/04/16/line-tower-wars-walkthrough-tower-defense/
- Line Tower Wars: Reforged: https://www.hiveworkshop.com/threads/line-tower-wars-reforged.354130/
- Team Line Tower Wars: https://maps.w3reforged.com/maps/categories/tower-wars/team-line-tower-wars
- Maul Tactics — WC3 custom maps that became real games: https://maultactics.gg/articles/wc3-custom-maps-standalone-games
- Gem TD (gaming-tools): https://gaming-tools.com/warcraft-3/gem-td/
- Gem TD — Dota 2 Wiki: https://dota2.fandom.com/wiki/Gem_TD
- GemTD by Cecrit (itch.io): https://cecrit.itch.io/gemtd
- SweClockers TD thread (Burbenog mention): https://www.sweclockers.com/forum/post/3288243

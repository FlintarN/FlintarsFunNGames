# Footmen Frenzy / Footmen Wars — research for our WC3-style RTS

Goal: rebuild the classic WC3 custom game **Footmen Frenzy** (genre: "Footmen Wars", "footies")
inside our deterministic Lua RTS (tile grid, now 64x40; Human + Orc units/heroes/items exist;
2-player lockstep + computer AI). **Requirement: custom games must support up to 8–10 players.**

Legend: **[src]** = from a source listed in §11; **[conv]** = genre convention / widely remembered
but not confirmed by a fetched source; **[ours]** = our proposal.

Versions matter. Numbers drift between 4.x, 5.x, 6.x and 7.x (NoHunters). Where sources disagree,
both values are given. The 5.x/6.x numbers are the best documented, so they are the reference here.

---

## 1. The game in one paragraph

Up to 12 players in **4 teams of 3**, one team per **corner** of a square map. Each player owns a
**barracks** ("base"/"tier") that **spawns units automatically** for free, forever. There is **no
harvesting**: all gold comes from **killing** things. Gold buys a **hero**, **tier upgrades**
(stronger spawned units), **attack/HP upgrades** for the spawned army, **items** and
**spell-caster creeps**. When your barracks dies you are out. The last team with a barracks wins.
[src]

---

## 2. Core loop

| Aspect | Details |
|---|---|
| Players | 2–12; "full house" = **4 teams × 3** (3v3v3v3) is the intended setup. Any format from 1v1 up works [src] |
| Team colours | T1 Red/Blue/Teal, T2 Purple/Yellow/Orange, T3 Green/Pink/Grey, T4 Light Blue/Dark Green/Brown [src] |
| Layout | Square map, **4 corners** (one per team) joined by a neutral middle. Each team's 3 bases sit in a **right-triangle formation** in its corner. The base furthest from the middle (P1/P4/P7/P10) is shielded by the other two [src] |
| Centre | The **Archvault** (consumables shop + strong mana-regen aura over the paved square). Controlling it is valuable [src] |
| Other shops | Weapon Shops on the **west and east** sides, Armor Shops on the **north and south** sides; each team has **private shops** at the back of its corner that enemies are blocked from [src] |
| Taverns | Hero taverns in a blocked-off area on the left edge (between T1 and T4); camera starts there [src] |
| Start | **2,000 gold** each; heroes cost **1,900** → almost everyone buys a hero at once [src] |
| Flow | Footmen pour out of every base; armies meet in the middle and at the edges between corners. Heroes farm the stream for gold + XP, then push bases [src] |
| Lose | Your **barracks is destroyed** → you lose all units and spawning, become an observer (whole-map vision). Your gold is split evenly to the remaining players (6.x+; older: lost unless transferred) [src] |
| Leaver | Barracks and units are destroyed, gold split to the rest (6.x+) [src] |
| Win | Last team with any barracks standing [src] |
| Length | Not given by sources. Typical pub game **30–60 min** [conv]. Tier timers (§3.3) go out to 24 min, and **Tier 5** exists explicitly to break stalemates of long games [src] |
| Modes (host) | **Normal** (pick hero, tech, or buy creeps); **Random Heroes**; **Random Draft** (choose from a pool of 11 random heroes) [src]. -repick (once, full HP only) and -swap with an ally in the first 3 min if you randomed [src] |

Two strategic paths, both valid and best mixed [src]:
1. **Tech** — buy tiers + weapon/HP + racial upgrades; base also gets tougher.
2. **Stack** — items + tomes on the hero, who then farms whole armies.
3. (Rare) Mass creeps, or buy several heroes.

---

## 3. Automatic spawning

### 3.1 Basics

- The **barracks spawns units continuously, for free** [src]. Units cannot be given a rally
  point; they pile up in base unless you send them [src]. Teams often share unit control so an
  ally can send your army [src].
- Everyone starts at **Tier 0 = Footmen**. Footmen spawn every **10 s** (Dota 2 port; consistent
  with the WC3 map's "every few seconds") [src]. Footman Lv 2, no abilities; gets weapon/HP
  upgrades but no racial [src]. Bounty **35–42 g** [src].
- Each tier has its own **interval and count per spawn** (e.g. Militia spawn **2 at a time**) [src].
- Higher tier = **more base HP** for the barracks and more damage dealt to attackers; a late-game
  Tier 0/1 base dies easily [src].

### 3.2 The "special building" choice: race + tier ladder

From Tier 0 you pick one of **4 races** at a **beacon** next to the barracks (6.x). After **7 min**
the base auto-upgrades to Tier 1 of the chosen race **for free** (random race if none chosen) [src].
Older versions: Tier 1 cost 1,050 g [src].

| Tier | Human | Orc | Undead | Night Elf | Cost | Unlock time (6.x) |
|---|---|---|---|---|---|---|
| 0 | Footman | Footman | Footman | Footman | start | 0 |
| 1 | Riflemen | Grunts (5.x) / Peons (6.x+) | Ghouls | Archers | 1,050 (5.x) / free at 7 min (6.x) | 3 min (template) / 7 min (auto) |
| 2 | Militia ("Infantry") | Chaos Peons / Peons / Grunts / Berserkers (varies) | Crypt Fiends | Huntresses | 1,400 | 10 min |
| 3 | Spell Breakers | Raiders | Skeletal Mages | Druids of the Talon | 2,000 | 17 min |
| 4 | Knights | Tauren | Abominations | Dryads | 4,000 | 24 min |
| 5 | Steam/Siege Tanks | Kodo Beasts | Meat Wagons | (War) Glaives | 20,000 (5.1) / 15,000 / 40,000 (later) | — |

[src: StrategyWiki 5.1; Frenzy wiki Armies + Tiers template]. "Unlock time" = earliest game time
the tier may be bought ("tiers are delayed to encourage the usage of heroes", 5.1+).

**Switching race** ("horizontal move") at the same tier [src]:

| Current tier | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Switch cost | 100 g | 400 g | 700 g | 1,000 g | 2,000 g |

No diagonal moves (can't go Grunts → Militia directly), no downgrades. Racial upgrades stay with
the race (switch back and they return) [src]. Common trick: sit on Orc T1 (tanky, hard to farm)
while stacking items, then pay 100 g to switch before teching [src].

### 3.3 Spawn stats per race (5.x/6.x wiki; "Lv" = unit level → XP/bounty)

| Race | Tier | Unit | Lv | HP | Damage | Spawn |
|---|---|---|---|---|---|---|
| Human | 1 | Rifleman | 3 | 650 | 17–23, range 300 | 1 / 11.5 s |
| | 2 | Militia/Infantry | 2 | 600 | 20–21, Feedback | **2** / 13 s |
| | 3 | Spell Breaker | 4 | 750 | 19–21, Feedback | **2** / 14 s |
| | 4 | Knight | 4 | 1,300 | 32–40 (stun) | 1 / 9.5 s |
| | 5 | Steam Tank | 6 | 1,600 | 300 per 4 s, Blink | 1 / 7 s |
| Orc | 1 | Peon (6.x) | 2 | 525 | ensnare | 1 / 12 s |
| | 2 | Grunt | 3 | 750 | 33–36, Ensnare (3 s, 15 s cd) | 1 / 7.5 s |
| | 3 | Raider | 4 | 950 | 33–37, Ensnare | 1 / 9 s |
| | 4 | Tauren | 5 | 1,450 | 41–44, Ensnare | 1 / 12 s (11 s in 7.2) |
| | 5 | Kodo Beast | 6 | 2,500 | 141–157, cleave | 1 / 14 s |
| Undead | 1 | Ghoul | 1 | 600 | 17–19 | 1 / **7 s** (fastest T1) |
| | 2 | Crypt Fiend | 3 | 700 | 21–26, Slam (−80 % move 3 s) | 1 / 9 s |
| | 3 | Skeletal Mage | 2 | 700 | 16–17, fast attack, Slam | 1 / 9 s |
| | 4 | Abomination | 5 | 1,400 | 46–52, Slam ×n | 1 / 11.5 s (10 s in 7.2) |
| | 5 | Meat Wagon | 4 | 1,000 | 126–145 splash | 1 / 8 s |
| Night Elf | 1 | Archer | 2 | 375 | 12–14, range 500 | 1 / 10 s |
| | 2 | Huntress | 3 | 750 | 21–23 bounce, Shadowmeld | 1 / 12 s |
| | 3 | Druid of the Talon | 5 | 650 | 17–19, fast | 1 / 9 s |
| | 4 | Dryad | 6 | 875 | 26–28 ranged | 1 / **6 s** |
| | 5 | Glaive Thrower | 7 | 1,000 | 165–180, range 850 | 1 / 8 s |

Dota 2 port (simplified, every spawn 10 s), for a second reference point [src]:

| Unit | HP | Armor | Dmg | Move | Special |
|---|---|---|---|---|---|
| Footman | 450 | 2 | 12 | 270 | — |
| Rifleman | 535 | 0 | 19 | 270 | 20 %: +15 dmg, slow |
| Militia | 600 | 4 | 23 | 270 | 15 % double swing, lifesteal |
| Spell Breaker | 600 | 3 | 23 | 300 | mana burn |
| Knight | 850 | 5 | 34 | 350 | 25 % stun |
| Grunt | 700 | 1 | 21 | 270 | +10 dmg/+1 armor when stuck |
| Troll Headhunter | 500 | 0 | 29 | 270 | attack speed from missing HP |
| Raider | 610 | 1 | 30 | 350 | 25 % net 3 s |
| Tauren | 1,300 | 3 | 33 | 270 | 25 % 50 AoE |

### 3.4 Army upgrades

| Upgrade | Levels | Cost | Effect |
|---|---|---|---|
| Weapons (attack) | 15 | not found (scaling) | % attack; "attack ups do 20 % and lower" (7.1) [src] |
| Health / armor | 15 | not found (scaling) | HP for all spawned units [src] |
| Racial (from Tier 1–2 on) | 5 | **500 / 1,000 / 1,500 / 2,000 / 2,500** | see below [src] |

Weapon/HP upgrades apply to **all** future spawns regardless of tier/race; higher tiers gain more
per upgrade [src]. Racials:

| Race | Racial (5.x/6.x) | Per level |
|---|---|---|
| Human | Evasion (older: +HP & attack speed) | 20/30/40/50/60 % evasion |
| Orc | Critical Strike (older: +dmg & HP) | 15 %×2.0 → 25 %×2.25 → 35 %×2.5 → 45 %×2.75 → 60 %×3.0 |
| Undead | Unholy Frenzy (attack speed; older also move speed) | +15 % each, multiplicative (≈ +56 % at 5) |
| Night Elf | Improved Range | +100 range each |

### 3.5 Race identity

| Race | Identity [src] |
|---|---|
| Human | Underrated; Spell Breakers' Feedback hurts mana races; Knights stun; evasion racial |
| Orc | Most HP, highest damage per hit, **slow spawns**; great tanks; ensnare; Raiders give T4-level bounty while weaker |
| Undead | Many, fragile units; Slam slows; Unholy Frenzy makes them shred |
| Night Elf | All ranged, lowest HP, fast attacks; very vulnerable to AoE (Blizzard, Flamestrike) |

Counter wheel (armies of equal tier/upgrades): wiki says **Human > Night Elf > Orc > Undead > Human**;
7.2 patch notes flipped it to **Orc > UD > NE > Human > Orc** [src]. Implemented with **custom
attack/armor types per race**: 150 % vs the type it beats, 75 % vs the type it loses to, 100 %
otherwise, **35 % vs Fortified** (bases); Hero attacks 100 % to all, 50 % vs fortified; spells
100 % (75 % vs heroes in 6.5) [src].

---

## 4. Heroes

| Aspect | Details |
|---|---|
| Count | 24 Blizzard heroes + 12 custom (early 5.x) → 40 + 1 secret (5.1) → 51 + 2 secret (6.5) → 70+ (Reforged) [src] |
| How many | **Unlimited** per player, **1,900 g each** (Death Sheep, Avalanche 2,000) — but 99.9 % buy exactly one [src] |
| Random | Random pick gives a **Ring of Courage** (+1 all stats) and a tiny chance at secret heroes [src] |
| Level cap | **18**; normal abilities up to **level 6**, ultimate up to **level 3** [src] |
| Abilities | 4 per hero [src] |
| Revive | At your barracks [src] |
| Bounty | Most heroes **267 g** (base 250); Avalanche 400; secret/morphed 512 [src] |
| Roles | **Hero Killer** (Death Knight, Blademaster, Jaood), **AoE farmer** (Archmage, Blood Mage, Lich…), **Support** (Shadow Hunter, Paladin…), **Tank** (Mountain King, Tauren Chieftain, Avalanche) [src] |
| Team template | One support/tank, one AoE, one hero killer per team of 3 [src] |
| Stats | Blizzard heroes ≈ stock WC3 base values (e.g. Paladin 650 HP, Archmage 450 HP, Blademaster 550 HP; 25 HP per STR, 15 mana per INT) [src] |
| Oddballs | Death Sheep (150 HP, slow, starts with Starfall/Big Bad Voodoo/Tranquility), Avalanche (thousands of HP, 600+ dmg, only Blink active) [src] |

---

## 5. Economy

| Source | Value |
|---|---|
| Start gold | 2,000 [src] |
| Kill bounty | Footman 35–42; higher-level units more (bounty and XP scale with **unit level**) [src] |
| Hero kill | ~267 (most) [src] |
| Bought creeps | Give **more** bounty/XP than spawns → enemies focus them [src] |
| Passive income | **None** found. No mines, no interest, no harvesting [src: "gold not from harvesting… but by killing"] |
| Lumber | **Not used**; gold is the only currency [src] |
| Sharing | Gold can be given to allies; pooling to get one player to T4 is a standard strategy [src] |
| Dead/leaver gold | Split evenly to remaining players (6.x) [src] |
| Sinks (rough) | Hero 1,900 · Tiers 1,050–4,000 (T5 15–40k) · Racial 500–2,500/level · Items 100–4,000 (legendary up to 75,000) · Creeps 200–450 |

Implication: income is **proportional to how much you kill** → snowball. Losing teams can still
earn from the endless free stream; that's the comeback valve.

---

## 6. Items and shops

| Shop | Where | Content (examples, gold) [src] |
|---|---|---|
| **Archvault** | Centre (mana-regen aura) | Dust of Appearance (free), Potion of Greater Healing 125 (+500 HP), Greater Mana 100 (+400), Health Stone 250, Mana Stone 250, Scroll of Speed 100 (army move speed), Scroll of Darkness 300 (fog + hide from minimap 60 s), **Scroll of Roar 600 (+75 % dmg to units in 650)**, Mass-teleport scroll 600 (12 units), Invis+max speed scroll 700, 75 %-miss scroll 500 |
| Weapon Shop ×2 | W + E | Claws +20 (500, stackable), Orb of Frost 750, Orb of Static 750, Vampiric Potion 200, Bone Chimes 450 (15 % lifesteal aura), Totem of Might 1,200, Berserker's Axe 200 (10 % cleave) |
| Armor Shop ×2 | N + S | Crown of Kings +7 (1,150), Belt +10 STR 350, Boots +6 AGI 350, Robe +7 INT 350, Ring of Protection +6 armor 200, Ring of Regen 350, Sobi Mask 250, Circlet +2 350 |
| Personal Shop (team-only) | Back of corner | Ankh 700, Periapt +1000 HP 2,500, Potion of Invulnerability 250, Tome of Next Level 1,000, Shield of the Gods 1,400, Cloak of Immolation 1,400, Spell Shield amulet 500, **Tank Token 900** (40 s siege tank for base-killing), Scepter of Destruction 1,500 (800-dmg line) |
| Bark's Store / "Wut're ya buyin'?" | Back of corner | Town Portal (~250), **free Healing Salves** (replaced old base healing), +25 single-stat items, +15 all |
| Altar of Legends | Back of corner | Late-game game-enders: Claws +100 (3,500), Granite Golem 6,000 HP (3,500), Drake Nest (4,000), Talisman = 12 penguins with 10k HP (8,500), Altar of the Gods (map-wide Starfall, 12,000), Wedding Ring (+1000 stats, invulnerable, 75,000) |
| Creep Shop | Back of corner | Spell-caster mercenaries (below) |
| Hero Taverns | Left edge | Heroes 1,900 |

**Creep Shop** (5.x): Priest 200, Sorceress 200, Troll Witch Doctor 200, Necromancer 200, Druid of
the Claw 200, Banshee 250, Dark Troll Priest 250, Shaman 300, Peasant 300 (repairs base),
Demolisher 400 (AoE siege), Goblin Zeppelin 450. **Food cap 3** (base gives 3 food; each creep 1,
Peasant + Zeppelin free) [src]. 6.x replaced them with named custom casters (Chunsang, Durant,
Dudey, Sendo, K-Rose, Faerie Dragon…) at 200–350 g, restock 20 s [src].

Note on towers: **4.2** had buildable **towers** and random items (popular version); 5.0 removed
"base healing" in favour of salves to discourage turtling [src]. Ultimate Footmen (variant) has
very strong towers placeable "almost anywhere" — cited as a balance problem [src].

---

## 7. Creeps, neutrals, objectives

- **No neutral creep camps** in Frenzy proper: all gold comes from enemy players' units [src].
  "Creeps" in Frenzy = **bought mercenaries** (§6). Four decorative critters give nothing [src].
- **Central objective** = the Archvault area: mana-regen aura + consumables shop. No boss [src].
- Breaking stalemates is done with **Tier 5**, Tank Tokens, Altar items, and scrolls (Roar,
  Darkness, mass teleport) rather than a boss [src].

---

## 8. Well-known variants

| Variant | Differences [src] |
|---|---|
| Classic Footmen Wars (RoC era) | Start with a **Wisp**, **build your base** choosing one of 4 races → it spawns that race's T1 (Footmen/Grunts/Ghouls/Archers); buy **one hero of your race**; revive at base. Often 4×3, some 2×6 |
| Footmen Frenzy (NoHunters, 4.x → 7.x) | Reference version above. 4.2 = towers + random items; 5.x = tier delays, Tier 5, stock creeps; 6.x = beacon, free auto-T1 at 7 min, custom creeps, 51 heroes |
| Footmen Frenzy XV (Clan MoRD) | Same core, +30 heroes (22 custom + 8 "super"), own items/creeps, game optimizer options: **all random, no teching, no resource trading** |
| Ultimate Footmen | **5 tech races**, **7 tiers each** (5 main + 2 "alternate" branches), 50+ heroes, strong towers, spell-heavy |
| Reforged Footmen Frenzy (miRaculix) | 4×3, **5 tech races**, 70+ heroes tagged **Techer / Farmer / Herokiller**, items + recipes, several rule-set modes, single draft by category |
| Dota 2 Footmen Frenzy | 3v3v3v3, every spawn 10 s, 4 races × 4 tiers (1,050/1,400/2,000/4,000), 20 heroes |
| StarCraft UMS port | **8 players, 2v2v2v2**, 8 heroes, 5 footman levels — proof the formula works at 8p |

---

## 9. Design for 2 / 4 / 8–10 players [ours]

### 9.1 Layout model: "corners × slots"

Use the Frenzy topology as a **parameter**, not a fixed 4×3:

- Square-ish map, **4 corner zones**, each with **up to 3 base slots** in a triangle (front-left,
  front-right, rear). Rear slot is the "shielded" one.
- A **team owns 1 or 2 corners**. That covers every count up to 12 with the same map art.
- Neutral middle: **Archvault-style shop + mana aura** in the exact centre; weapon shops W/E,
  armor shops N/S (reuse our existing Arcane Vault / Voodoo Lounge as the shop buildings).
- Each corner: team-only shop at the back (reuse items we already have).

| Players | Default teams | Corners used | Map | Notes |
|---|---|---|---|---|
| 2 | 1v1 | 2 opposite corners (or W vs E on 64x40) | **64x40** (current) | Works today; centre shop in the middle |
| 3 | FFA 1v1v1 | 3 corners | 64x64 | 4th corner empty (or AI) |
| 4 | **2v2** (or FFA 4) | 2v2: each team 2 adjacent corners? No — keep 1 corner/team, 2 slots each | 64x64 | FFA uses all 4 corners |
| 6 | 3v3 or 2v2v2 | 2 or 3 corners | 96x96 | |
| 8 | **4 teams × 2** (Frenzy feel) or 2×4 | 4 corners × 2 slots | 96x96 | StarCraft port proves 2v2v2v2 |
| 9 | 3 × 3 | 3 corners × 3 slots | 96x96 | |
| 10 | **2 × 5** (team = 2 adjacent corners, 3+2 slots) or 5 × 2 (needs 5 zones — avoid) | 4 corners | 96x96 (or 128x80) | 4 teams 3/3/2/2 also allowed with handicap gold |

Uneven teams: give the short team **+30 % spawn rate per missing player** or let its players own
an extra (AI-less) barracks [ours]. Original Frenzy just let empty slots be empty.

### 9.2 Spawn / unit budget (lockstep performance)

Free endless spawns are the main perf risk. 10 players × 1 unit / 10 s → +60 units/min.

- **Per-player live-unit cap** for spawned units, scaled by player count:
  `cap = clamp(floor(200 / players), 16, 40)` → 2p 40, 4p 40, 8p 25, 10p 20 [ours].
  At the cap the barracks pauses (Frenzy's own map ran into this; WC3 used the food cap) [conv].
- Spawns are deterministic from game time + tier table → zero network traffic except commands.
- **Auto-send** option per player (units walk to a chosen enemy corner / the centre) because
  Frenzy has no rally point and units piling up is a known newbie mistake — cheap QoL and
  essential for AI and for 10-player games where you can't micro everything [ours].
- Higher tiers spawn **fewer, stronger** units (already true in Frenzy) → late game gets cheaper
  to simulate, not more expensive.

### 9.3 What changes by size

| | 2 players | 4 players | 8–10 players |
|---|---|---|---|
| Teams | 1v1 | 2v2 / FFA | 4×2, 3×3, 2×5 |
| Map | 64x40 | 64x64 | 96x96 |
| Spawn interval | 10 s | 10 s | 10 s, cap 20–25 units/player |
| Tier unlock times | Shortened ×0.6 (T1 at ~4 min) | ×0.8 | Frenzy timings (7/10/17/24 min) |
| Game length target | 15–25 min | 25–40 min | 40–60 min |
| Gold sharing | n/a | give-gold command | give-gold; dead/leaver gold split |
| Leavers | AI takes over | AI takes over | AI takes over, else barracks dies (Frenzy) |
| Base HP | Lower (shorter games) | normal | normal; Tier raises base HP |

---

## 10. Minimal faithful first version (scope) [ours]

**Mode: "Footmen Frenzy" — 2 players (1v1 or vs AI) on the current 64x40 map, built for 4 corners
later.** Uses only units/heroes/items we already have.

1. **Bases**: each player gets one **Barracks** (Human) / **Orc Barracks** (fortified, high HP,
   say 3,000) and nothing else to build. No workers, no gold mines, no lumber.
2. **Spawning**: every 10 s the barracks spawns its current tier unit next to itself; per-player
   cap; optional **auto-send** toggle (to enemy base).
3. **Tiers (2 races = our 2 factions, 4 tiers, mapped to existing units)**:

   | Tier | Human (have) | Orc (have) | Cost | Spawn |
   |---|---|---|---|---|
   | 0 | Footman | Footman (neutral start) | — | 1 / 10 s |
   | 1 | Rifleman | Grunt | free at 4 min (pick race) | 1 / 11 s |
   | 2 | Militia ×2 (or Priest/Sorceress mix) | Troll Headhunter | 1,400 | 2 / 13 s · 1 / 8 s |
   | 3 | Knight | Raider | 2,000 | 1 / 10 s |
   | 4 | Siege Engine (Steam Tank) | Tauren (or Kodo) | 4,000 | 1 / 12 s |

   Race switch at same tier: 100/400/700/1,000 g. No downgrades.
4. **Upgrades** at the barracks: Weapons and Armor/HP, **5 levels** in v1 (Frenzy has 15),
   each +10 % / cost 300·level; **one racial**: Human Evasion 20→40 %, Orc Critical 15 %×2→35 %×2.5,
   3 levels at 500/1,000/1,500. Reuse our Blacksmith/War Mill upgrade code paths.
5. **Hero**: start with 2,000 gold, hero costs 1,900 at a tavern panel listing our 8 heroes
   (all four Human + four Orc, cross-race allowed as in Frenzy). One hero per player in v1.
   Revive at own barracks (WC3 revive cost/time). Hero bounty ~250.
6. **Economy**: gold only from kills (unit bounty by unit level; footman ~38). No interest, no
   lumber. "Give gold to ally" command (needed once teams exist).
7. **Shops**: one centre shop (our existing items + potions + Town Portal) with a mana-regen
   aura; Scroll of Speed / Roar-style army scrolls if cheap to add.
8. **Win/lose**: barracks destroyed = out; last team standing wins. Leaver → AI (our rule) .
9. **AI**: buys hero at start; tiers up when gold ≥ next tier + reserve; buys weapon/armor
   levels otherwise; auto-send always on; hero follows its army and retreats/TPs at low HP.
   Fully bot-testable (fits "bot-test now, group-test later").

### Later (in order)

1. **4 corners + 64x64 map**, teams of 1–3 slots, FFA and 2v2 (§9).
2. **96x96 + 8–10 players** with the per-player spawn cap and dead-player gold split.
3. **Counter wheel** via per-race attack/armor types (150/100/75 %, 35 % vs fortified).
4. Tier 5 (Kodo / Steam Tank-class) as a very expensive stalemate breaker.
5. **Creep Shop**: our Priest, Sorceress, Shaman, Witch Doctor as 200–300 g mercenaries,
   **3-food cap**, higher bounty.
6. Team-only corner shops; Archvault scrolls (Roar, Speed, Darkness, mass teleport); Tank Token.
7. Undead + Night Elf races once those units exist (Ghoul/Fiend/Mage/Abom; Archer/Huntress/DotT/Dryad).
8. Hero pick modes: Random (+ small bonus ring), Random Draft (pool of N), -repick once.
9. Hero level cap 18 / ability levels 6 (needs our ability data extended past WC3's 3).
10. Altar-of-Legends-style late items; tower variant (4.2) as an optional rule.

---

## 11. Sources

- StrategyWiki — Warcraft III: The Frozen Throne/Footmen Frenzy (5.1/6.5e era; via Wayback
  snapshot): https://strategywiki.org/wiki/Warcraft_III:_The_Frozen_Throne/Footmen_Frenzy
- StrategyWiki — Footmen Wars (genre, Classic FW, FF XV, Ultimate Footmen):
  https://strategywiki.org/wiki/Warcraft_III:_Reign_of_Chaos/Footmen_Wars
- Footmen Frenzy Compendium (fandom; read via its MediaWiki API):
  - https://frenzy.fandom.com/wiki/Footmen_Frenzy
  - https://frenzy.fandom.com/wiki/Armies:General_Tips (tier table, switch costs, 15 upgrade levels, counter wheel)
  - https://frenzy.fandom.com/wiki/Human_Army · https://frenzy.fandom.com/wiki/Orc ·
    https://frenzy.fandom.com/wiki/Undead · https://frenzy.fandom.com/wiki/Night_Elf (spawn rates, HP, racials)
  - https://frenzy.fandom.com/wiki/Template:Tiers (costs + unlock times)
  - https://frenzy.fandom.com/wiki/Compendium:General_Tips (2,000 start gold, rules)
  - https://frenzy.fandom.com/wiki/Footmen_Frenzy_Guide (hero 1,900 g, damage-type chart, base layout)
  - https://frenzy.fandom.com/wiki/Gold · https://frenzy.fandom.com/wiki/Archvault ·
    https://frenzy.fandom.com/wiki/Weapons_Shop · https://frenzy.fandom.com/wiki/Armor_Shop ·
    https://frenzy.fandom.com/wiki/Personal_Shop · https://frenzy.fandom.com/wiki/Altar_of_Legends ·
    https://frenzy.fandom.com/wiki/Creep_Shop
  - https://frenzy.fandom.com/wiki/Compendium:Patch_List (7.1/7.2 changes) ·
    https://frenzy.fandom.com/wiki/Version_5.2 · https://frenzy.fandom.com/wiki/Version_5.3 ·
    https://frenzy.fandom.com/wiki/Footmen_Frenzy_on_StarCraft (8p 2v2v2v2 port)
- Dota 2 Wiki — Footmen Frenzy custom game (unit table, 10 s spawn): https://dota2.fandom.com/wiki/Footmen_Frenzy
- EyeOfGamers — Footmen Frenzy summary (bounties, 40 heroes, level 18): https://eyeofgamers.wordpress.com/games/footmen-frenzy/
- W3Reforged — Reforged Footmen Frenzy (4×3, 5 tech races, 70+ heroes, roles):
  https://maps.w3reforged.com/featured-maps/reforged-footmen-frenzy
- Hive Workshop — spawn food-limit thread (spawn caps are a known concern):
  https://www.hiveworkshop.com/threads/how-to-set-food-limit-on-a-footmen-frenzy-spawn-trigger.214378/

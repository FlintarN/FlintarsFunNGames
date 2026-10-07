# Hero Defense / Hero Survival — research for our WC3-style RTS

Goal: rebuild a classic WC3 "hero defense" custom game inside our deterministic Lua RTS
(tile grid, now 64x40; WC3 heroes with levels, 4 abilities, items, shops for Human/Orc;
2-player lockstep; computer AI). **New requirement: custom games must scale to 8–10 players.**

Legend: **[src]** = taken from a source listed at the end; **[conv]** = genre convention / widely
remembered but not confirmed by a fetched source; **[ours]** = our proposal.

---

## 1. The genre in one paragraph

Heroes (one per player, picked at a tavern or randomly) stand between spawn points and
something you must protect (a castle, a hero NPC, a "life counter" at the middle). Waves arrive
on a timer, get stronger, and are punctuated by boss waves. Killing creeps gives gold + XP;
gold buys items in shops. You lose when the protected thing dies or the lives counter hits 0;
you win by surviving the last wave / killing the final boss. Versus variants (Enfo's, Hero Line
Wars) put two teams side by side and let each team make the other's life harder.

---

## 2. The four iconic maps

### 2.1 Hero Siege / X Hero Siege (co-op castle defense)

| Aspect | Details |
|---|---|
| Players | 1–8, co-op, no AI allies [src: Xnd Hero Siege] |
| Length | ~45–90 min [src] |
| Layout | Castle in centre. Creeps arrive on **up to 8 lanes** (W, N, E, S; NW/NE/SW/SE added on extreme). Each lane has an enemy spawner ("Dark Necropolis"); **destroying it closes that lane**. After all lanes close, "mega creeps" spawn [src] |
| Two creep streams | (a) constant **lane creeps** trickling from each spawner; (b) periodic **waves** that appear "at west, north, east then south" of the castle in rotation [src] |
| Lose | Castle destroyed, or (late game) all heroes dead at once [src] |
| Win | Final boss sequence: Magtheridon (gatekeeper, spawns minions) → 4 Captains → Arthas. Before the final wave all players are teleported to the castle with a **60 s prep** timer [src] |
| Difficulty | Discovery (100,000 start gold), Easy (1,000 start gold), Normal (bosses get bonus armor), Hard (lightning bounces on wave arrival), Very Hard (dragons + assassins raid periodically), Extreme (murlocs/hydras + `-extreme N` up to 999) [src] |
| Heroes | 40+ heroes, labelled Fighter/Caster/Tank/Support/Summoner/Healer; pick modes Normal, Random, Same (all same hero), Dual (2 heroes each), Dual Random, Dual Same; one `-repick` per game [src] |
| Revive | Normal timed revive [conv]; `-revive` instantly for 5,000 gold or 50 lumber [src] |
| Economy | Gold per kill, big boss bounties scaling with difficulty and contribution; **gold→lumber** conversion (250,000 g = 250 lumber); `-gg N` give gold to ally; buy levels/tomes/damage via commands [src] |
| Shops | 7 shops: Weaponry, Armory, Artificery, Jewelry, Apothecary, Library, Workshop. Prices inflate hugely: early 1,250–25,000; mid 50k–125k; legendary 350k–500k [src] |
| Castle | Castle HP/armor upgradeable; towers and stone statues assist [src] |
| Events | Circle of power at the castle opens optional events: **Muradin** (survive 3 min vs unkillable boss → 50,000 g), **Farming** (kill max creeps in 3 min → 2,400 g + 1 lumber/creep), **Creep Slayer** (2,000 lane kills → ring), **Wave Slayer** (80 wave kills → sword + tome +100 stats), **Hero Image** (duel a clone of your hero → tome) [src] |

**Why it's fun:** power fantasy with absurd number inflation; clear spatial job ("I hold the
north lane"); closing lanes is visible progress; opt-in events are risk/reward breaks;
Dual-hero mode doubles the toy count.

### 2.2 Theramore Hero Defense (co-op, protect a VIP)

| Aspect | Details |
|---|---|
| Players | Up to 6, co-op [src] |
| Protect | Jaina Proudmoore (a unit). She dies → you lose [src] |
| Waves | **40 waves + 10 bosses** (i.e. boss every 4th wave), 13 special events (arena, PvP…) during which the wave timer pauses [src] |
| Difficulty | Easy / Normal / Hard / Impossible [src] |
| Heroes | 23 heroes; **1 innate ability + 5 learnable**, incl. an ultimate; normal abilities 5 ranks, ultimate 3 [src] |
| Economy | Gold from kills; buys **reinforcements**, upgrades, items; **33 crafting recipes**; custom stats like Spell Damage [src] |
| Extras | 8 optional quests, secrets [src] |

**Why it's fun:** a VIP that can be focused gives tension and "body-block" moments; reinforcements
let gold become army, not just items; recipes give a shopping goal.

### 2.3 Enfo's Team Survival (2 teams, parallel survival race)

| Aspect | Details |
|---|---|
| Players | 1–10, **two teams of up to 5** (MT edition: up to 4 per team on some versions) [src] |
| Layout | Two mirrored halves (West/East). Each team's monsters walk toward **their own middle/goal**. Team doesn't fight the other team directly [src] |
| Lives | **100 lives per team; every leaked creep −1 life**; in MT, hero death also costs lives [src] |
| Waves | **42 waves + bonus wave**, progressively harder; mixes plain mobs with "support monsters" (auras, spells, ranged); later waves add invisibility, stuns, crits [src] |
| Win/Lose | Survive longer than the other team / lives to 0 = lose [src] |
| Difficulty | Voted pre-game (AFK votes ignored); scales monster **max HP and base damage**: 75 / 100 / 125 / 150 / 200 % [src] |
| Heroes | 28 heroes (caster / melee / hybrid); all-pick or random (random avoids duplicates in a team); repick blocked once you've cast a spell [src] |
| Revive | Timer revive, timer shown on multiboard; **5 s divine shield** on revive [src] |
| Spellbringer | A **shared team unit** (F2) with pages of spells and summons bought with team resources; many spells **disrupt the other team** (make them leak) [src] |
| Anti-snowball | **Overpopulation**: >200 monsters alive on a side triggers a penalty/defeat [src] |
| Economy | Gold + **lumber** (lumber from certain hero abilities); bounty system tunes XP/gold [src] |

**Why it's fun:** co-op inside a team + competition between teams with zero direct PvP; the
Spellbringer gives the "send-something-nasty" thrill; the overpop cap stops endless stalling.

### 2.4 Hero Line Wars (2 teams, send creeps = income)

| Aspect | Details |
|---|---|
| Players | Classic: 2 teams; variants up to 12 (6v6); 3-hero teams in some versions [src] |
| Layout | Each team has a lane/base; creeps you **buy** walk to the **enemy's** lane; you fight what the enemy sends you [src] |
| Lives | Variants: 100 team lives, −1 per leaked creep; or lose when **15 creeps** reach your base [src] |
| Income | **Sending a creep costs gold and permanently raises your income**, paid every **10–20 s** (version-dependent) [src] |
| Hero | One hero; buy items, abilities, stats (`attributes for money`); some versions level cap 300 [src] |
| Extras | Disruption spells for gold; duel arena; neutral "Freak" bosses (lvl 120) guarding a secret shop, 10 % rare drop [src] |

**Why it's fun:** the core economic dilemma — **spend on hero power now vs. send creeps for
income + pressure**. Every decision hurts the opponent and helps you later.

### 2.5 Honourable mention: Footmen Frenzy (not defense, but same toolkit)

4 teams × 3 players; each player picks a hero; **barracks auto-spawn footmen** (barracks
upgrade through 4 tiers, also revives your hero); destroy the other teams' barracks [src].
Relevant because "auto-spawning allied units per player" is a cheap way to make 8–10 player
games feel big without micromanagement.

---

## 3. Cross-map numbers worth copying

| Thing | Typical value | Source |
|---|---|---|
| Waves | 40–42 (+ bonus/final) | Theramore, Enfo's |
| Boss cadence | every 4th–5th wave (40 waves + 10 bosses) | Theramore |
| Team lives | 100, −1 per leak | Enfo's, HLW 3-lane |
| Line-wars leak limit | 15 creeps | HLW |
| Difficulty steps | 75/100/125/150/200 % HP & dmg | Enfo's |
| Revive shield | 5 s invulnerable | Enfo's |
| Final-wave prep | 60 s | X Hero Siege |
| Income tick | 10–20 s | HLW |
| Overpop cap | 200 alive monsters / side | Enfo's |
| Pick modes | All-pick, Random, Same, Dual | X Hero Siege |
| Wave interval | 30–60 s between waves [conv] | — |

---

## 4. Design for 8–10 players (new requirement)

### 4.1 Map size

64x40 is too small for 10 heroes + 4–8 lanes of creeps. Proposal **[ours]**:

| Players | Map | Lanes / spawns | Notes |
|---|---|---|---|
| 1–2 | 64x40 (current) | 2 lanes (W, E) | Castle in centre; works today |
| 3–4 | 64x64 | 4 lanes (W, N, E, S) | One lane per player at full count |
| 5–8 | 96x96 | 4 lanes, + 4 diagonal on Hard+ | ~2 heroes per lane |
| 9–10 | 96x96 (or 128x80 for versus) | 4–8 lanes | Versus mode: 2 mirrored 64x64 halves = 128x64 |

Lanes should be **fixed paths** (marked tiles) so pathfinding cost stays flat as unit count rises.
For Enfo's-style versus, two independent mirrored halves = two co-op instances sharing a clock.

### 4.2 Enemy scaling by player count

Scale **count** first, **HP** second (count is more readable and spreads across lanes):

- `count = base * (0.6 + 0.4 * players)` → 1p 1.0x, 2p 1.4x, 4p 2.2x, 8p 3.8x, 10p 4.6x.
- `hp = base * difficultyPct * (1 + 0.05 * (players-1))` (mild, so solo-tuned waves aren't spongy).
- Bosses: `bossHp = base * (0.5 + 0.5 * players)`; add 1 extra add per 2 players.
- Lives: keep **fixed 100** (or 20 in a short mode) — more defenders already means fewer leaks.
- Gold: **per-kill bounty to the killer + 30 % shared** to all teammates (avoids last-hit fights
  among 10 players and keeps the support player rich enough).
- XP: split among heroes within range (WC3 rule), so 10 heroes don't each get full XP.

### 4.3 Simulation budget (important for lockstep)

- Hard cap of live monsters: ~**200 per side** (Enfo's overpop rule doubles as our perf cap).
  Exceeding it = extra lives lost per second, not more units.
- Prefer **fewer, stronger creeps** at high player counts beyond the cap (merge into "elite" units).
- Lockstep with 10 players: only commands go over the wire; waves are deterministic from seed + wave #.

### 4.4 What changes by size

| | 2 players | 4 players | 8–10 players |
|---|---|---|---|
| Modes | Co-op vs AI waves; or 1v1 Line Wars | Co-op; or 2v2 Enfo's/Line Wars | Co-op (8); Enfo's 5v5 / Line Wars 5v5 (10) |
| Map | 64x40, 2 lanes | 64x64, 4 lanes | 96x96 (co-op) / 128x64 (versus) |
| Waves | 20 short / 40 full | 40 | 40 + diagonal raids on Hard+ |
| Hero pick | All-pick | All-pick / random | Random-no-duplicates per team default (fewer dupes, faster start) |
| Gold sharing | Killer 100 % | Killer + 30 % shared | Killer + 30 % shared; `give gold` command |
| Leavers | AI takes hero | AI takes hero | AI takes hero; gold split to team |
| Revive | Timer 5 s + 2 s/level [conv WC3-like] | same | same, capped 30 s; altar/castle buyback for gold |

---

## 5. Recommended minimal first version (reusing what exists)

**Mode: "Castle Defense" (co-op, Hero Siege + Theramore hybrid), 1–4 players first, architected for 10.**

1. **Map**: current 64x40, castle (reuse Town Hall/Great Hall as the protected building, high HP)
   in centre; spawn points W and E (add N/S when map grows). Fixed lane tiles.
2. **Heroes**: our existing Human + Orc heroes, picked at a tavern-like panel (all-pick + Random).
   No new abilities needed.
3. **Waves**: 20 waves, one every **45 s** (first after 60 s), boss on waves 5/10/15/20.
   Enemies: reuse existing Human/Orc/neutral creep units — wave N picks from a table by tier
   (melee → ranged → casters → mixed). Final wave 20 = boss + adds, 60 s prep teleport.
   All wave content deterministic from wave number (lockstep-safe).
4. **Lose**: castle dies. Optional **lives** counter instead (20 lives, −1 per creep touching the
   castle) — simpler to tune; pick one per mode.
5. **Economy**: gold per kill = creep's existing bounty; boss bounty 200–500; killer + 30 % shared.
   Reuse existing shops/items unchanged; place a shop inside the castle area.
6. **Revive**: timer revive at castle (WC3 formula-ish), 5 s invulnerability after.
7. **Difficulty**: Easy/Normal/Hard/Insane = 75/100/150/200 % creep HP+damage.
8. **AI**: computer heroes in co-op = "hold my lane, return to shop when gold ≥ X". Bot-testable.

### Later (in order)

1. Player-count scaling (formulas §4.2) + bigger maps (64x64, 96x96) + 4 lanes.
2. Lane spawners you can destroy (X Hero Siege) — visible progress, mega creeps after.
3. Item recipes (Theramore) and a "reinforcements" shop (gold → allied units).
4. Optional events at a circle of power: Duel your clone; Farming 3 min; survive-the-boss.
5. **Enfo's mode** (2 teams, 100 lives, overpop cap) with a team **Spellbringer** that can buy
   "send extra creeps / slow their wave" spells.
6. **Hero Line Wars mode**: buy-to-send creeps with income tick every 15 s; 15-leak loss.
7. Pick modes: Same hero, Dual hero, Random-no-dupes; repick once.
8. Footmen-Frenzy-style auto-spawning allied footmen per player for 8–10p versus.

---

## 6. Sources

- Xnd Hero Siege (Hive Workshop): https://hiveworkshop.com/threads/xnd-hero-siege-1-51.316255/
- Theramore Hero Defense (Hive Workshop): https://www.hiveworkshop.com/threads/theramore-hero-defense.352648
- Enfo's Team Survival (again) (Hive Workshop): https://www.hiveworkshop.com/threads/enfos-team-survival-again.314128/
- Enfo's TS: MT Edition 1.93 (Hive Workshop): https://www.hiveworkshop.com/threads/enfos-ts-mt-edition-1-93.81150/
- Enfos Team Survival (Dota 2 custom game wiki, 100 lives / 42 waves / Spellbringer): https://dota2customgame.fandom.com/wiki/Enfos_Team_Survival
- Enfo's on classic Battle.net map vault: https://classic.battle.net/mod/mapvault_archive4.shtml
- Hero 3 Line Wars (Hive Workshop): https://www.hiveworkshop.com/threads/hero-3-line-wars-v-1-1.180497/
- Hero Line Wars concept (itch.io remake): https://tomhai.itch.io/hero-line-wars
- Hero Line Wars variants (W3Reforged map list): https://maps.w3reforged.com/maps/categories/hero-defense-and-survival/hero-line-wars-deluxe
- Footmen Frenzy (StrategyWiki): https://strategywiki.org/wiki/Warcraft_III:_The_Frozen_Throne/Footmen_Frenzy
- WC3 Tavern / heroes reference: https://warcraft.wiki.gg/wiki/Tavern_(Warcraft_III)

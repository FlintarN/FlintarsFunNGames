# DotA (Defense of the Ancients: Allstars) — research for a DotA mode

Goal: a DotA-style mode inside our WC3-style RTS (deterministic Lua, tile grid, WC3 heroes
lv 1–10 with 4 abilities, items/shops, towers, creeps, lockstep PvP, computer AI).
**Requirement: custom games support up to 8–10 players, so the target is full 5v5**, with
1v1 / 2v2 / 3v3 / 4v4 played on the *same map data*.

How sure the numbers are:
- **[S]** confirmed by a source listed at the bottom.
- **[6x]** a classic DotA Allstars 6.xx / early Dota 2 (6.xx-era) value from community
  memory. It should be right to within about 10%, but it is not quoted from a source.
- **[D2]** a modern Dota 2 value. Use it only as a guide.
We are building our own version anyway, so treat every number as a starting value to tune.

---

## 1. Map layout

### 1.1 What the original map has
- Two bases in opposite corners: **Sentinel** in the south-west (Night Elf look; its
  Ancient is the **World Tree**) and **Scourge** in the north-east (Undead look; its
  Ancient is the **Frozen Throne**) [S].
- **3 lanes** [S]:
  - **Top**: up the west edge, then along the north edge.
  - **Mid**: the diagonal between the bases.
  - **Bot**: along the south edge, then up the east edge.
- **River** runs diagonally from the north-west to the south-east and crosses mid at
  the centre [S]. Towers sit on their own side of the river [S].
- **Jungle**: the 4 triangles between the lanes, 2 per side. They hold neutral creep
  camps, including one "ancient" camp per side.
- **Towers per lane**: Tier 1 is near the river, Tier 2 is halfway to base, and Tier 3
  is at the base entrance. Two **Tier 4** towers guard the Ancient. That gives 11 towers
  per side.
- **Barracks**: each lane has a **melee** and a **ranged** barracks behind its T3, so
  6 per side. If you destroy them, that lane's enemy creeps become stronger ("super"
  creeps). If you destroy all 6, every enemy lane spawns **mega creeps** (added back in
  6.03) [S].
- **Ancient** sits in the middle of the base. It cannot be hurt until at least one lane
  is fully broken (T1→T2→T3) and both T4 towers are down.
- **Fountain** is behind the Ancient. It heals and restores mana fast for allies, has a
  very strong attack against enemies, and is where heroes spawn and respawn.
- **Shops**:
  - Several in-base shops, one per item category (each a WC3 "shop" unit selling a page
    of items), plus the hero **taverns** in the middle of the map at game start.
  - One **secret shop** per side, out in the jungle near the river. It sells advanced
    parts such as Demon Edge, Ultimate Orb, Sacred Relic, Mystic Staff, Hyperstone,
    Eaglesong, Reaver and Point Booster.
  - Two **side shops**, one near the top lane and one near the bot lane. They sell basic
    items so laners don't have to walk home.
- **Roshan**: a boss creep in a pit next to the river.
  - Killing him gives the team +200 gold each, roughly 150–400 extra to the killer, and
    the **Aegis of the Immortal** (one revive) [S].
  - He respawns about 10 min later; from 6.79 it is a random 8–11 min [S].
  - Aegis drop added in 6.36 [S].
- **Runes**: 2 rune spots in the river, with a new rune every 2 min. Types: Haste,
  Double Damage, Illusion, Invisibility, Regeneration. [6x]
- **Day/night cycle**: WC3 style, with shorter vision at night. [6x]

### 1.2 Grid geometry proposal (one map for every team size)
The map is a 96×96 tile grid. The origin is top-left and +y points south. It must be
**point-symmetric under 180° rotation**, (x,y) → (95−x, 95−y), so the deterministic
engine is fair to both sides. The original map is not perfectly symmetric; ours should be.

Our scale is `WC.XP_RANGE = 12` tiles ≈ 1200 WC3 units, so 1 tile ≈ 100 units. In
those units:
- A DotA tower's ~700 range ≈ **6–7 tiles**.
- Lane creep acquire range ≈ 5 tiles.

The real DotA map is about 140 tiles across, so 96 is a 1.5× squeeze. Mid lane is about
110 tiles long. A hero at ~3 tiles/s crosses it in about 37 s; the original took about
60 s. Lane creeps should walk at about 3.2 tiles/s.

Our current maps are 64×40, so this needs a larger grid. Pathfinding and fog-of-war cost
grow with it, so profile them before committing.

All coordinates below are for Sentinel. **Scourge = (95−x, 95−y)**.

| Object | Sentinel position (tile) | Notes |
|---|---|---|
| Fountain | (4,91) | Heal 4%/s HP+MP [6x]; attack 190+ dmg, invulnerable |
| Ancient | (11,84) | 3×3 or 4×4 footprint |
| T4 ×2 | (9,79), (16,86) | flank the Ancient |
| Top lane path | x=6 from y=78 → y=6, then y=6 → x=78 | 3–4 tiles wide |
| Mid lane path | diagonal (17,78) → (78,17) | 3 tiles wide |
| Bot lane path | y=89 from x=17 → x=89, then x=89 → y=17 | |
| Top T3 / T2 / T1 | (6,70) / (6,52) / (6,34) | barracks pair either side of T3 at (3,70),(9,70) |
| Mid T3 / T2 / T1 | (20,75) / (28,67) / (37,58) | barracks at (18,72),(23,77) |
| Bot T3 / T2 / T1 | (25,89) / (43,89) / (61,89) | barracks at (25,86),(25,92) |
| River | band along y≈x (8,8)→(87,87), 4 tiles wide | slows nothing; just open ground, lower vision optional |
| Rune spots | (34,34) and (61,61) | shared (they lie on the symmetry axis pair) |
| Roshan pit | centre, (44..51, 44..51) | Under 180° rotation the only fair single spot is the map centre. Put the pit on the river at the centre and let mid split around it: two 2-tile paths, or a bend. The original pit sat off to one side, which favoured one team. |
| Secret shop | (22,44) | Sentinel's lies in the top-mid jungle near the river |
| Side shops | top (10,12), bot (85,83) | already a symmetric pair, so neutral |
| Jungle camps (Sentinel) | small (44,72), medium (52,77), medium (20,50), large (60,70), ancient (66,80) | mid-bot triangle is the main jungle |
| Hero spawn | fountain | |

A **64×64 compact variant** can reuse the same layout: multiply the coordinates by 2/3
and keep lanes 3 tiles wide. That would be a good test map before the engine grows.

---

## 2. Creeps

### 2.1 Lane creeps
- **Timing**: the first wave spawns at 1:30 game time (3:00 in league / random-draft
  style modes), then **every 30 s** from each barracks group, in every lane [S].
- **Composition**: Sentinel sends Treants plus a Druid of the Talon; Scourge sends Ghouls
  plus a Necromancer [S].
  - Starting wave: **3 melee + 1 ranged** [S].
  - Melee count grows with time. A source gives +1 melee at 15:00, 30:00 and 45:00 [S]
    (Dota 2 era). In 6.xx it was a similar slow growth up to 5–6 melee late. [6x]
  - Siege creeps (catapult / meat wagon) were added in the late 6.xx era: 1 per wave on
    every 7th wave, later every 10th. [6x/D2]
- **Stats** [6x]:

| | HP | Damage | Armor | Range | Gold | XP |
|---|---|---|---|---|---|---|
| Melee | 550 | 19–23 | 2 | melee | ~38–48 | ~62 |
| Ranged | 300 | 21–26 | 0 | 500 | ~41–58 | ~41 |
| Siege | 550 | 35–46 (vs buildings ×) | 0 | 690 | ~66–80 | ~88 |
| Super melee / ranged | +~150% HP, +~50% dmg | | | | less gold | |
| Mega | + much more | | | | | |

- **Upgrades over time**: every 7.5 min creeps gain a little HP and damage (melee about
  +10 HP / +1 dmg each step). [6x]
- **Barracks bonuses**:
  - Killing a lane's melee barracks makes the enemy's melee creeps in that lane "super".
  - Killing the ranged barracks does the same for ranged creeps.
  - Killing all 6 barracks makes **mega creeps** in all lanes [S].
- **Pathing**: creeps follow lane waypoints. They attack whatever enemy is closest (WC3
  acquire range) and fight back against heroes who hit them.
- **Denying**: you may attack your **own** creep below **50% HP** [6x].
  - If you get the last hit, the enemy gets **no gold** and reduced XP. In late 6.xx,
    denied XP was split; 6.79 made ranged and melee heroes equal here [S].
  - Your own **towers below 10% HP** can also be denied, which cuts the enemy's gold. [6x]
  - For us: an "attack ally" command allowed only on own creeps under 50% HP.
- **Last hits**: gold goes **only to the unit that lands the killing blow**. XP is shared
  among all enemy heroes within 1200 units (1300 from 6.79) [S] — our `WC.XP_RANGE` 12.

### 2.2 Neutral creeps (jungle)
- **Camps** [6x]:
  - Per side: 1–2 small, 2 medium, 1 large and 1 **ancient** camp.
  - Ancients: Black Dragon, Granite Golem, Dark Troll Summoner type. They are too strong
    for early heroes.
- **Spawning**: at 0:30 / first wave, camps spawn from a random set for their size.
  Example: a small camp might be 2 Kobolds + 1 Kobold Foreman.
- **Respawn**: checked **every minute on the minute**. A camp refills only if its area
  is empty of units and items, so "**stacking**" works (pull the camp away just before
  :00 and a second set spawns) [S].
- Neutrals are passive until hit, then **leash** back to the camp if pulled too far.
- **Gold and XP**: per neutral, roughly the same as lane creeps; ancients give more.
  Each neutral has a WC3 ability (purge, hurl boulder, etc.). For us, start with plain
  stat-sticks.

### 2.3 Roshan [6x, approximate]
- Stats: about 5500 HP growing over time, about 75 dmg, 20 armor, Bash, Slam (AoE slow)
  and spell resistance.
- Respawn: 10 min (Allstars); later 8–11 min random [S].
- Reward: Aegis on the 1st kill. From 6.xx, later kills also drop Cheese [6x].
- For us: Roshan = a big neutral with Bash + a timed AoE stomp. Aegis = one free revive
  on the spot, expires after 5 min (later 6.xx).

---

## 3. Heroes

### 3.1 Picking modes [S]
- **-ap All Pick**: any hero from any tavern.
- **-ar All Random**: random hero, with bonus gold [6x].
- **-sd Single Draft**: choose 1 of 3 random heroes.
- **-rd Random Draft**: 20 random heroes in a pool, players pick in turns.
- **-cd Captains Draft**: 24 random, captains ban then pick.
- **-cm Captains Mode**: tournament bans and picks.
- Extra modes can be added on, e.g. `-apem`:
  - **-em** Easy Mode: more XP/gold, weaker towers.
  - **-dm** Death Match: pick a new hero on death; team loses after N deaths.
  - **-om** Only Mid: the classic 1v1 format.
  - **-id** Item Drop.
  - **-sc** Super Creeps.
  - **-du** Duplicate heroes allowed.
  - **-wtf**: no cooldowns or mana costs; Glyph is not refreshed in -wtf from 6.58 [S].
- The host (blue/pink player) types the mode in the first ~15 s.

### 3.2 Levels and XP
- **Max level 25** [S].
- Ultimate can be learned at **6 / 11 / 16** (3 ranks) [S].
- The 3 basic skills have **4 ranks**, learnable at levels 1/3/5/7.
- "**Attribute bonus**" (+2 all stats) can be learned in place of a skill. It has 10
  ranks [S].
- **Cumulative XP to reach a level** [6x]:

| Level | Total XP | Level | Total XP |
|---|---|---|---|
| 2 | 200 | 14 | 10400 |
| 3 | 500 | 15 | 11900 |
| 4 | 900 | 16 | 13500 |
| 5 | 1400 | 17 | 15200 |
| 6 | 2000 | 18 | 17000 |
| 7 | 2600 | 19 | 18900 |
| 8 | 3200 | 20 | 20900 |
| 9 | 4400 | 21 | 23000 |
| 10 | 5400 | 22 | 25200 |
| 11 | 6000 | 23 | 27500 |
| 12 | 8200 | 24 | 29900 |
| 13 | 9000 | 25 | 32400 |

  The modern Dota 2 table is different but starts the same (200/500/900/1400/2000…) and
  totals 27500 at lv 25 [S].
- **Hero kill XP**: the killed hero gives XP based on its level, shared among nearby
  enemy heroes. It is roughly 100 + 0.13 × the dead hero's total XP [6x approximate].

### 3.3 Gold
- **Starting gold** [S]:
  - 603, raised to 625 in 6.79.
  - A randomed hero gets bonus gold, about +250 in -ap. [6x]
- **Passive income** [S]:
  - 1 gold every 0.8 s (≈75/min), changed in 6.79 to 1 gold every 0.6 s (100/min).
  - It starts when the creeps spawn.
- **Hero kill bounty** [6x]:
  - Base is about **200 + 9 × victim level**, plus a streak bonus.
  - Streak bonus starts at 3 kills: "Killing Spree", "Dominating"… up to "Beyond
    Godlike". It rose from 75–600 to 125–1000 in 6.79 [S].
  - Assist gold is split among nearby heroes.
  - First Blood gives +150 to +200.
- **Death gold loss** [6x]: about **30 × level**, from unreliable gold only.
  - **Reliable gold** (passive income, hero kills, Roshan, tower team gold) is never lost.
  - **Unreliable gold** (creep kills) can be lost [S].
- **Towers**: the last hitter gets 100–200, raised to 150–250 in 6.79 [S]. The whole
  team also gets gold for each tower.

### 3.4 Death, respawn, buyback
- **Respawn** [6x]: about **4 s × hero level**, so 4 s at lv 1 and 100 s at lv 25. Later
  6.8x versions changed the low levels. Maximum is reached at lv 25 [S].
- **Buyback** [S]:
  - Cost = 100 + level² × 1.5 + game seconds × 0.25 (= minutes × 15).
  - Cooldown about 6–7 min. [6x]
  - From 6.79, after a buyback you earn no unreliable gold until your normal respawn
    would have ended, and 25% of the remaining respawn time is added to your next
    death [S].

### 3.5 Attributes [S, 6.xx values]
- **STR**: +19 HP and +0.03 HP/s regen per point.
- **AGI**: +1% attack speed and +0.14 armor per point.
- **INT**: +13 mana and +0.04 mana/s per point.
- **Primary attribute**: +1 attack damage per point.
- Each hero has base values plus per-level gains, as in our `str = { base, perLevel }`
  data.

---

## 4. Items

- **Starting purchase** with ~600 gold [6x prices]:

| Item | Price | Effect |
|---|---|---|
| Healing Salve | 100 | |
| Clarity | 50 | |
| Tango | 90 | eat trees |
| Iron Branch | 53 | +1 all |
| Gauntlets / Slippers / Mantle | 150 | +3 str / agi / int |
| Circlet | 185 | +2 all |
| Ring of Protection | 175 | +2 armor |
| Sobi Mask | 325 | mana regen |
| Ring of Regen | 350 | HP regen |
| Boots of Speed | 500 | |
| Town Portal Scroll | 135 | |
| Observer / Sentry wards | ~150 / ~200 | |

- **Recipes / combining** (added by Guinsoo in 2004) [S]:
  - Put all the parts plus a paid "recipe scroll" in your inventory and they turn into
    the upgrade.
  - Inventory is **6 slots** (WC3).
  - Examples [6x prices]:
    - **Bracer / Wraith Band / Null Talisman** = Circlet + Gauntlets / Slippers /
      Mantle + recipe (≈525).
    - **Power Treads** = Boots + Gloves of Haste + Belt of Strength (≈1400).
    - **Magic Stick → Magic Wand**.
    - **Vanguard** = Ring of Health + Vitality Booster.
    - **Mekansm**.
    - **Battle Fury** = Broadsword + Claymore + Perseverance.
    - **Desolator** = 2× Mithril Hammer + recipe.
    - **Black King Bar** = Ogre Axe + Mithril Hammer + recipe.
    - **Butterfly** = Eaglesong + Talisman of Evasion + Quarterstaff.
    - **Heart of Tarrasque** [S name].
- **Consumables**: salve, clarity, tango, TP scroll, wards, Dust of Appearance, and
  Smoke (Dota 2 only).
- **Courier**:
  - A shared team unit that carries items from shop to hero. It is bought for about
    200 gold [6x].
  - It can be upgraded to a flying courier. From 6.79 the upgrade is only allowed 3 min
    after creeps spawn [S].
  - The animal courier had 300 move speed, raised to 350 in 6.79; its HP went from 45
    to 75 in 6.79 [S].
  - Couriers can be killed; Dota 2 gives gold for it.
- **Item drops on death**: none by default. -id mode makes you drop one.

---

## 5. Towers and buildings

- **Tower stats** [6x approximate; modern Dota 2 differs]:

| | HP | Damage | Armor | Range | Atk/s |
|---|---|---|---|---|---|
| T1 | 1300 (D2 later 1800) | 100–120 | ~20 (D2: 12) [S D2] | ~700 | 1.0 |
| T2 | 1600 | 120–140 | ~20 (D2: 14) | ~700 | 1.0 |
| T3 | 1600 | 140–160 (D2 170–174) [S] | ~20 (D2: 14–16) [S] | ~700 | 1.0 |
| T4 | 1600 | 100–120 | ~20 (D2: 21) | ~700 | 1.0 |

  Building stats, all [6x]:
  - Melee barracks ≈1500 HP; ranged barracks ≈1200 HP.
  - Ancient ≈4250 HP.
  - Buildings take extra damage from siege attacks (the WC3 "Fortified" armor type).
- **Invulnerability chain**: in each lane T2 cannot be damaged until T1 is dead, then T3
  after T2, then the barracks after T3. T4s need at least one T3 dead. The Ancient needs
  both T4s dead.
- **Tower targeting**: a tower attacks the closest unit. It switches to a hero that
  attacks an allied hero in range (the "tower aggro" rule).
- **Backdoor protection** (from 6.60) [S]:
  - It covers T2+ towers, barracks and the Ancient. T1 towers never have it [S].
  - If no enemy lane creeps are near the building, it regenerates fast and takes reduced
    damage.
  - 6.60 described it as fast regeneration while attacked without creeps nearby [S].
    Dota 2 later used 50% damage reduction and 180 HP/s heal [S, D2].
  - Its purpose is to stop heroes from sneaking past the creeps to kill buildings.
- **Glyph of Fortification** [S]:
  - A team button that makes **all friendly buildings invulnerable** for 4 s (5 s from
    6.75).
  - Dota 2 later also made lane creeps invulnerable and gave towers multishot.
  - Cooldown 5 min [6x].
  - When an enemy tower dies, the team's Glyph cooldown resets [D2].
- Towers also get **"true sight"** in Dota 2. WC3 DotA used sentry wards / gems for
  revealing invisible units.

---

## 6. Win condition, match length, team sizes

- **Win**: destroy the enemy **Ancient**. There is no other way, except surrender
  (`-ff` votes, added later) or one team leaving.
- **Match length**: usually **35–50 min** in public games. A fast push can end at
  20–25 min; a turtle game can pass 60 min.
- **Team size**: 5v5, 10 player slots plus referee/observer slots [S].
- **Scaling down** (all on the same map data):

| Format | Active lanes | Notes |
|---|---|---|
| 1v1 | **Mid only** (the classic `-om` 1v1) | Side-lane towers and barracks are left out. Ancient opens when mid's T3 and the T4s fall. |
| 2v2 | **All 3 lanes, side-lane waves cut to 2 melee + 1 ranged** | Mid + one side lane would be unfair: rotation maps Sentinel's top-lane half onto Scourge's bot-lane half, so one team would get its "safe" lane and the other its "hard" lane. Alternative: mid only with 2 heroes each. Mega creeps when all *active* barracks die. |
| 3v3 | All 3 lanes | Classic 1-1-1 or 2-1-0 setups. Jungle matters less. |
| 4v4 / 5v5 | All 3 lanes + jungle + Roshan | Full rules. |

  Settings that change with team size:
  - Passive gold per minute.
  - Respawn ×0.75 for 1v1 and 2v2.
  - Creep wave size: −1 melee in 1v1.
  - XP share range.
  - Whether Roshan and the secret shop are active.

---

## 7. Recommended plan for us

### 7.1 Principle
Author the **full 5v5 map once** and drive every format from a **mode table**:
- `activeLanes = {"mid"}` / `{"mid","top"}` / `{"top","mid","bot"}`
- `jungle = true/false`
- `roshan = true/false`
- `teamSize = 1..5`

Buildings in inactive lanes are simply not placed. The invulnerability chain and the
mega-creep check only count active lanes. Any slot with no human player is **filled by
our computer AI**. This lets 5v5 be bot-tested now with 2 humans, and real player counts
can grow later.

### 7.2 Version 1 (build now)
- **Map**: the 96×96 point-symmetric layout from §1.2. Test it first as a 64×64 compact
  build if the engine isn't ready for 96×96.
- **Modes**:
  - 1v1 mid-only (the lockstep PvP target).
  - 5v5 with bots: 1–2 humans plus AI.
  - 2v2 and 3v3 on 3 lanes from the same tables.
  - Picking: **All Pick** and **All Random** only. Duplicate heroes are allowed when
    there are more than 8 players, or use `-du` logic.
- **Heroes**: all 8 existing WC3 heroes, keeping **level cap 10**, 4 abilities, ult at 6
  and our existing `WC.XP_LEVELS`.
  - Tune creep and hero XP so a laner reaches lv 6 at about 8–10 min and lv 10 at about
    25–30 min.
  - A rough fit: melee creep ≈ 25 XP and ranged ≈ 18 XP with our 200…5400 table, then
    tune in bot tests.
  - Suggested roles:
    - Melee carries: Blademaster, Mountain King.
    - Ranged nuker / pusher: Far Seer, Archmage.
    - Support / healer: Paladin, Shadow Hunter.
    - Initiator: Tauren Chieftain.
    - Caster: Blood Mage.
  - Mass Teleport fits well (it doubles as the TP scroll). Earthquake is good for
    pushing. Resurrection should revive allied **heroes** in this mode.
- **Economy**:
  - 600 starting gold; 1 gold every 0.8 s; last-hit gold only; XP in range.
  - Death loses 30 × level of unreliable gold.
  - Respawn = 4 s × level, scaled for our 10 levels: **4 + 6 × level s**, max 64 s.
  - Buyback = 100 + level² × 6 + minutes × 15, cooldown 6 min. Our levels are 2.5×
    coarser, hence the larger level term.
  - Hero bounty = 200 + 20 × level, with streak gold starting at 3 kills.
- **Creeps**:
  - 3 melee + 1 ranged every 30 s, from 1:30.
  - +1 melee at 15 / 30 min.
  - Small stat upgrade every 7.5 min.
  - Super creeps per destroyed barracks; mega creeps when all active barracks are gone.
  - **Deny** below 50% HP.
- **Buildings**:
  - Per active lane: T1–T3 + melee and ranged barracks. Plus 2 × T4, the Ancient and a
    fountain.
  - Full invulnerability chain, backdoor protection and **Glyph** (5 s, 5 min cooldown).
- **Items** (about 20, one base shop + 2 side shops):
  - Consumables: Healing Salve, Clarity, TP Scroll.
  - Stat items: Iron Branch, Gauntlets, Slippers, Mantle, Circlet.
  - Basic items: Boots, Gloves of Haste, Belt of Strength, Claws of Attack, Ring of
    Protection, Ring of Regen, Sobi Mask.
  - Recipes:
    - Bracer / Wraith Band / Null Talisman.
    - Power Treads.
    - Vanguard (as a WC3 item equivalent).
    - Desolator-like (−armor orb).
    - Black King Bar-like (spell immunity, duration shrinks with each use).
    - Heart-like.
  - 6 slots. Recipes combine automatically when the parts are in the inventory.
- **Courier**: leave it out of v1. Use side shops plus TP instead.

### 7.3 Later
1. **Jungle** neutral camps: respawn each minute if empty, leashing, stacking. Then
   **Roshan** + Aegis.
2. **Secret shop** + expensive late items (Butterfly, Battle Fury-like cleave, Divine
   Rapier-like).
3. **Courier**, shared per team and killable.
4. **Runes** in the river, every 2 min.
5. **Siege creeps**, then more picking modes (Single Draft, Random Draft, Captains Mode,
   `-em`, `-dm`).
6. Day/night vision, wards, invisibility detection.
7. Surrender vote, and reconnect / AI takeover for leavers. This is important at 10
   players.
8. Optionally raise the hero cap to 15–25 with extra ability ranks, if 10 levels feel
   short at 5v5.

### 7.4 Engine items to check
- Grid growth from 64×40 to 96×96: pathfinding cost with about 100 creeps alive.
  - Lane creeps can follow fixed **waypoints / flow fields per lane** instead of full
    A\* searches.
- Lockstep at 10 players: command batching and turn length.
- Target selection must be deterministic. Ties go to the lowest unit id.

---

## Sources
- Wikipedia, *Defense of the Ancients*: https://en.wikipedia.org/wiki/Defense_of_the_Ancients
- Warcraft Wiki, *Defense of the Ancients: Allstars* (map, spawns at 1:30 every 30 s, creep types, Roshan reward, versions): https://warcraft.wiki.gg/wiki/Defense_of_the_Ancients:_Allstars
- Wowpedia mirror: https://wowpedia.fandom.com/wiki/Defense_of_the_Ancients:_Allstars
- Liquipedia, *Version 6.79* (starting gold 603→625, gold tick, tower bounty, spree gold, XP range, Roshan 8–11 min, courier, buyback rules): https://liquipedia.net/dota2/Archive:Version_6.79
- Dota 2 Wiki, *Version 6.03* (mega creeps): https://dota2.fandom.com/wiki/Version_6.03
- Dota 2 Wiki / Liquipedia, lane creeps (30 s waves, 3 melee + 1 ranged, melee growth): https://dota2.fandom.com/wiki/Creeps , https://liquipedia.net/dota2/Lane_creep
- Dota 2 Wiki, *Experience points* (XP table, max level 25): https://dota2.fandom.com/wiki/Experience_points
- Dota 2 Wiki, *Respawn*: https://dota2.fandom.com/wiki/Respawn
- ESportsTales, buyback formula before 7.11: https://www.esportstales.com/dota-2/710-to-711-comparison-of-buyback-cost-and-aoe-assist-gold
- Liquipedia, *Glyph*, *Ancients*, *Tier 3 tower* (backdoor protection, armor tiers): https://liquipedia.net/dota2/Glyph , https://liquipedia.net/dota2/Ancients , https://liquipedia.net/dota2/Tier_3_tower
- GosuGamers, 6.60 backdoor regeneration announcement, 6.58 changelog, 6.75 release: https://www.gosugamers.net/dota/news/9786-icefrog-quick-update-about-6-60 , https://www.gosugamers.net/dota/news/9421-dota-6-58-changelog , https://www.gosugamers.net/news/21315-dota-v6-75-finally-released
- Liquipedia, *Reliable gold*: https://liquipedia.net/dota2/Reliable_gold
- StrategyWiki, Dota 2 gameplay (attribute values): https://strategywiki.org/wiki/Dota_2/Gameplay
- Game mode commands (-ap/-ar/-rd/-sd/-cd/-dm/-om/-id): https://portforward.com/games/walkthroughs/DotA/DotA-Game-Modes.htm , https://www.scribd.com/document/73580513/Dota-Commands
- Old DotA primer (lv 25, ult 6/11/16, attribute bonus): https://web.unbc.ca/~cchan/about.htm
- Roshan / Aegis (Aegis from 6.36): https://portforward.com/games/walkthroughs/DotA/Roshan.htm , https://baike.baidu.com/en/item/Roshan/3306965

Note: dota2.fandom.com, liquipedia lane-creep/buildings and dota.fandom.com pages blocked
direct fetching (HTTP 402/403). Values marked [S] from them come from search-result
extracts. Values marked [6x] should be checked against the 6.83d map's object editor data
if exact numbers ever matter.

-- Warcraft III: heroes. Data (the eight Human and Orc heroes, their
-- abilities, the summons) and the rules: levels and experience, skill
-- points, mana, casting, effects (stun, invulnerable, invisible, slow,
-- can't attack), auras, area spells, summons that expire, revival.
-- The engine calls in here at a few points (E.UnitTick, E.OnHit, E.OnDeath,
-- E.CastStep, E.WorldTick, E.HeroCommand ...); all of it is plain data in
-- the game state, deterministic, so lockstep PvP keeps working.
local ADDON, ns = ...

local WC = ns.WC
local E = WC.Engine
local U, B = WC.Units, WC.Buildings
local I = "Interface\\Icons\\"

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
WC.XP_LEVELS = { 200, 500, 900, 1400, 2000, 2700, 3500, 4400, 5400 } -- total XP for levels 2 to 10
WC.HERO_MAX = 3
WC.HERO_TIER = { [2] = { human = "keep", orc = "stronghold" }, [3] = { human = "castle", orc = "fortress" } }
WC.XP_RANGE = 12 -- heroes this close share the experience of a kill

-- A hero: str/agi/int = { at level 1, per level }. Health 100 + 25 x str,
-- mana 15 x int, damage = base + the main attribute, armour = base + agi x 0.3.
local function Hero(t)
    t.hero, t.food, t.time, t.cost = true, 5, 55, { 425, 100 }
    t.attackType, t.armorType = "hero", "hero"
    t.hp = 100 + 25 * t.str[1]
    t.damage = t.baseDamage + t[t.primary][1]
    t.armor = t.baseArmor
    return t
end
U.paladin = Hero({ name = "Paladin", npc = 12126, hotkey = "P", primary = "str", str = { 22, 2.7 }, agi = { 13, 1.5 },
    int = { 17, 1.8 }, baseDamage = 4, baseArmor = 3, cooldown = 2.2, range = 1, speed = 2.7,
    icon = I .. "Spell_Holy_HolyBolt", abilities = { "holy_light", "divine_shield", "devotion", "resurrection" } })
U.archmage = Hero({ name = "Archmage", npc = 2543, hotkey = "A", primary = "int", str = { 14, 1.8 }, agi = { 17, 1 },
    int = { 19, 3.2 }, baseDamage = 3, baseArmor = 1, cooldown = 2.13, range = 4.5, speed = 2.9,
    icon = I .. "Spell_Frost_IceStorm", abilities = { "blizzard", "water_elemental", "brilliance", "mass_teleport" } })
U.mountain_king = Hero({ name = "Mountain King", npc = 2784, hotkey = "M", primary = "str", str = { 24, 3 }, agi = { 11, 1.5 },
    int = { 15, 1.5 }, baseDamage = 3, baseArmor = 2, cooldown = 2.22, range = 1, speed = 2.7,
    icon = I .. "Spell_Nature_ThunderClap", abilities = { "storm_bolt", "thunder_clap", "bash", "avatar" } })
U.blood_mage = Hero({ name = "Blood Mage", npc = 4275, hotkey = "B", primary = "int", str = { 18, 2 }, agi = { 14, 1 },
    int = { 19, 3 }, baseDamage = 3, baseArmor = 1, cooldown = 2.13, range = 4.5, speed = 2.9,
    icon = I .. "Spell_Fire_SelfDestruct", abilities = { "flame_strike", "banish", "siphon_mana", "phoenix" } })
U.blademaster = Hero({ name = "Blademaster", npc = 3230, hotkey = "B", primary = "agi", str = { 18, 2 }, agi = { 23, 1.5 },
    int = { 16, 2 }, baseDamage = 3, baseArmor = 1, cooldown = 1.77, range = 1, speed = 2.9,
    icon = I .. "Ability_Whirlwind", abilities = { "wind_walk", "mirror_image", "critical_strike", "bladestorm" } })
U.far_seer = Hero({ name = "Far Seer", npc = 2465, hotkey = "F", primary = "int", str = { 15, 2 }, agi = { 18, 1 },
    int = { 19, 3 }, baseDamage = 3, baseArmor = 1, cooldown = 2.13, range = 4.5, speed = 2.9,
    icon = I .. "Spell_Nature_ChainLightning", abilities = { "chain_lightning", "far_sight", "feral_spirit", "earthquake" } })
U.tauren_chieftain = Hero({ name = "Tauren Chieftain", npc = 3057, hotkey = "T", primary = "str", str = { 25, 3.2 },
    agi = { 10, 1.5 }, int = { 14, 1.3 }, baseDamage = 4, baseArmor = 1, cooldown = 2.2, range = 1, speed = 2.7,
    icon = I .. "Ability_WarStomp", abilities = { "shockwave", "war_stomp", "endurance", "reincarnation" } })
U.shadow_hunter = Hero({ name = "Shadow Hunter", npc = 10540, hotkey = "S", primary = "agi", str = { 15, 2 }, agi = { 20, 1.5 },
    int = { 17, 2.5 }, baseDamage = 3, baseArmor = 2, cooldown = 2.05, range = 4.5, speed = 2.9,
    icon = I .. "Spell_Nature_HealingWaveGreater", abilities = { "healing_wave", "hex", "serpent_ward", "big_bad_voodoo" } })
B.altar_kings.trains = { "paladin", "archmage", "mountain_king", "blood_mage" }
B.altar_storms.trains = { "blademaster", "far_seer", "tauren_chieftain", "shadow_hunter" }
WC.Factions.human.heroes = B.altar_kings.trains
WC.Factions.orc.heroes = B.altar_storms.trains

-- Summoned units (they disappear when their time is up) and the hexed look.
local function Summon(t)
    t.summon, t.cost, t.time, t.food = true, { 0, 0 }, 0, 0
    t.attackType, t.armorType = t.attackType or "normal", t.armorType or "medium"
    return t
end
for lv, x in ipairs({ { 525, 20 }, { 675, 30 }, { 900, 42 } }) do
    U["water_elemental" .. lv] = Summon({ name = "Water Elemental", npc = 10955, hp = x[1], armor = 0, damage = x[2],
        cooldown = 1.5, range = 4.5, speed = 2.5, attackType = "siege", armorType = "heavy",
        icon = I .. "Spell_Frost_SummonWaterElemental" })
end
for lv, x in ipairs({ { 200, 11 }, { 250, 15 }, { 300, 19 } }) do
    U["spirit_wolf" .. lv] = Summon({ name = "Spirit Wolf", npc = 3524, hp = x[1], armor = 0, damage = x[2], cooldown = 1.35,
        range = 1, speed = 3.3, icon = I .. "Spell_Nature_SpiritWolf" })
end
for lv, x in ipairs({ 13, 25, 39 }) do
    U["serpent_ward" .. lv] = Summon({ name = "Serpent Ward", npc = 2914, hp = 135, armor = 0, damage = x, cooldown = 1.5,
        range = 5, speed = 0, attackType = "pierce", armorType = "light", icon = I .. "Spell_Nature_GuardianWard" })
end
U.phoenix1 = Summon({ name = "Phoenix", npc = 575, hp = 1250, armor = 1, damage = 61, cooldown = 1.4, range = 4.5, speed = 3,
    icon = I .. "Spell_Fire_Burnout" })
U.sheep = { name = "Sheep", npc = 1933, hp = 1, armor = 0, damage = 0, cooldown = 1, range = 1, speed = 1, cost = { 0, 0 },
    time = 0, food = 0, icon = I .. "Spell_Nature_Polymorph", look = true }

-- Abilities. target: "self" (no target), "enemy"/"ally"/"unit" (a unit),
-- "friend" (your unit or building), "point" (the ground); passive: "aura",
-- "hit" (on attack), "death". Per level: mana, cd and the numbers.
local A = {}
WC.Abilities = A
A.holy_light = { name = "Holy Light", hotkey = "T", icon = I .. "Spell_Holy_HolyBolt", target = "ally", range = 8,
    mana = { 65 }, cd = { 5 }, amount = { 200, 400, 600 }, text = "Heals a friendly unit for %d." }
A.divine_shield = { name = "Divine Shield", hotkey = "D", icon = I .. "Spell_Holy_DivineIntervention", target = "self",
    mana = { 25 }, cd = { 35, 50, 65 }, duration = { 15, 30, 45 }, text = "Invulnerable for %d seconds." }
A.devotion = { name = "Devotion Aura", hotkey = "V", icon = I .. "Spell_Holy_DevotionAura", passive = "aura", radius = 9,
    amount = { 1.5, 3, 4.5 }, text = "Nearby friendly units get +%s armour." }
A.resurrection = { name = "Resurrection", hotkey = "R", ult = true, icon = I .. "Spell_Holy_Resurrection", target = "self",
    mana = { 200 }, cd = { 240 }, amount = { 6 }, radius = 9, text = "Brings back up to %d friendly units that died nearby." }
A.blizzard = { name = "Blizzard", hotkey = "B", icon = I .. "Spell_Frost_IceStorm", target = "point", range = 8,
    mana = { 75 }, cd = { 6 }, amount = { 30, 40, 50 }, duration = { 6, 8, 10 }, radius = 2.5,
    text = "Waves of ice in an area: %d damage a second." }
A.water_elemental = { name = "Summon Water Elemental", hotkey = "W", icon = I .. "Spell_Frost_SummonWaterElemental",
    target = "self", mana = { 125 }, cd = { 20 }, summon = "water_elemental", count = { 1 }, duration = { 60 },
    text = "A Water Elemental fights for you for 60 seconds." }
A.brilliance = { name = "Brilliance Aura", hotkey = "R", icon = I .. "Spell_Holy_MagicalSentry", passive = "aura", radius = 9,
    amount = { 0.75, 1.5, 2.25 }, text = "Nearby friendly heroes get %s mana a second." }
A.mass_teleport = { name = "Mass Teleport", hotkey = "T", ult = true, icon = I .. "Spell_Arcane_TeleportStormWind",
    target = "friend", range = 999, mana = { 100 }, cd = { 20 }, amount = { 24 }, radius = 7,
    text = "Teleports the hero and up to %d units nearby to a friendly unit or building." }
A.storm_bolt = { name = "Storm Bolt", hotkey = "T", icon = I .. "Spell_Nature_ThunderClap", target = "enemy", range = 6,
    mana = { 75 }, cd = { 9 }, amount = { 100, 225, 350 }, stun = { 5 }, heroStun = { 3 },
    text = "A hammer that deals %d damage and stuns." }
A.thunder_clap = { name = "Thunder Clap", hotkey = "C", icon = I .. "Spell_Nature_ThunderClap", target = "self",
    mana = { 90 }, cd = { 6 }, amount = { 60, 100, 140 }, radius = 3, slow = { 5 },
    text = "Slams the ground: %d damage to enemies nearby, and slows them." }
A.bash = { name = "Bash", hotkey = "B", icon = I .. "Ability_Rogue_KidneyShot", passive = "hit", chance = { 20, 30, 40 },
    amount = { 25 }, stun = { 2 }, heroStun = { 1 }, text = "A %d%% chance to stun and deal 25 more damage." }
A.avatar = { name = "Avatar", hotkey = "V", ult = true, icon = I .. "Ability_Warrior_Innerrage", target = "self",
    mana = { 150 }, cd = { 180 }, duration = { 60 }, text = "Grows: +500 health, +5 armour, +20 damage for %d seconds." }
A.flame_strike = { name = "Flame Strike", hotkey = "F", icon = I .. "Spell_Fire_SelfDestruct", target = "point", range = 8,
    mana = { 135 }, cd = { 10 }, amount = { 40, 70, 105 }, duration = { 3 }, radius = 2.5,
    text = "A pillar of fire: %d damage a second in an area." }
A.banish = { name = "Banish", hotkey = "N", icon = I .. "Spell_Shadow_Cripple", target = "unit", range = 8,
    mana = { 60, 50, 40 }, cd = { 9 }, duration = { 12, 15, 18 }, heroDuration = { 4, 5, 6 },
    text = "The target can't attack for %d seconds." }
A.siphon_mana = { name = "Siphon Mana", hotkey = "E", icon = I .. "Spell_Shadow_SiphonMana", target = "enemy", range = 6,
    mana = { 0 }, cd = { 6 }, amount = { 150, 250, 350 }, text = "Drains up to %d mana from an enemy hero." }
A.phoenix = { name = "Phoenix", hotkey = "X", ult = true, icon = I .. "Spell_Fire_Burnout", target = "self",
    mana = { 150 }, cd = { 120 }, summon = "phoenix", count = { 1 }, duration = { 60 },
    text = "A Phoenix fights for you for %d seconds." }
A.wind_walk = { name = "Wind Walk", hotkey = "W", icon = I .. "Ability_Rogue_Sprint", target = "self",
    mana = { 75 }, cd = { 5 }, duration = { 20, 40, 60 }, speed = { 0.1, 0.25, 0.4 }, amount = { 40, 70, 100 },
    text = "Invisible and faster for %d seconds; the next attack hits harder." }
A.mirror_image = { name = "Mirror Image", hotkey = "R", icon = I .. "Spell_Magic_LesserInvisibilty", target = "self",
    mana = { 125, 100, 75 }, cd = { 3 }, count = { 1, 2, 3 }, duration = { 60 },
    text = "%d copies that deal no damage and take double." }
A.critical_strike = { name = "Critical Strike", hotkey = "C", icon = I .. "Ability_CriticalStrike", passive = "hit",
    chance = { 15 }, mult = { 2, 3, 4 }, text = "A 15%% chance to deal %dx damage." }
A.bladestorm = { name = "Bladestorm", hotkey = "B", ult = true, icon = I .. "Ability_Whirlwind", target = "self",
    mana = { 200 }, cd = { 180 }, duration = { 6 }, amount = { 110 }, radius = 2.5,
    text = "Spins, untouchable: %d damage a second to enemies around." }
A.chain_lightning = { name = "Chain Lightning", hotkey = "C", icon = I .. "Spell_Nature_ChainLightning", target = "enemy",
    range = 7, mana = { 120 }, cd = { 9 }, amount = { 85, 125, 180 }, jumps = { 4, 6, 8 },
    text = "Lightning that jumps between enemies: %d damage, less each jump." }
A.far_sight = { name = "Far Sight", hotkey = "F", icon = I .. "Spell_Nature_FarSight", target = "point", range = 999,
    mana = { 50, 40, 30 }, cd = { 20 }, radius = { 10, 15, 20 }, duration = { 8 },
    text = "Reveals an area anywhere for 8 seconds (radius %d)." }
A.feral_spirit = { name = "Feral Spirit", hotkey = "R", icon = I .. "Spell_Nature_SpiritWolf", target = "self",
    mana = { 75 }, cd = { 15 }, summon = "spirit_wolf", count = { 2 }, duration = { 60 },
    text = "%d Spirit Wolves fight for you for 60 seconds." }
A.earthquake = { name = "Earthquake", hotkey = "E", ult = true, icon = I .. "Spell_Nature_Earthquake", target = "point",
    range = 8, mana = { 150 }, cd = { 90 }, amount = { 50 }, duration = { 25 }, radius = 4, buildings = true,
    text = "Shakes an area: %d damage a second to buildings; units there are slowed." }
A.shockwave = { name = "Shockwave", hotkey = "W", icon = I .. "Spell_Nature_Earthquake", target = "point", range = 8,
    mana = { 100 }, cd = { 8 }, amount = { 75, 130, 200 }, length = 8,
    text = "A wave of force in a line: %d damage to enemies in its path." }
A.war_stomp = { name = "War Stomp", hotkey = "T", icon = I .. "Ability_WarStomp", target = "self",
    mana = { 90 }, cd = { 6 }, amount = { 25, 50, 75 }, radius = 3, stun = { 3, 4, 5 }, heroStun = { 1, 1.5, 2 },
    text = "Stomps: %d damage to enemies nearby, and stuns them." }
A.endurance = { name = "Endurance Aura", hotkey = "E", icon = I .. "Spell_Nature_UnyieldingStamina", passive = "aura",
    radius = 9, amount = { 0.1, 0.2, 0.3 }, attack = { 0.05, 0.1, 0.15 },
    text = "Nearby friendly units move and attack faster." }
A.reincarnation = { name = "Reincarnation", hotkey = "R", ult = true, icon = I .. "Spell_Nature_Reincarnation",
    passive = "death", cd = { 240 }, delay = { 7 }, text = "Comes back to life %d seconds after dying." }
A.healing_wave = { name = "Healing Wave", hotkey = "T", icon = I .. "Spell_Nature_HealingWaveGreater", target = "ally",
    range = 7, mana = { 90 }, cd = { 9 }, amount = { 130, 215, 300 }, jumps = { 3, 4, 5 },
    text = "Heals %d, then jumps to other wounded friends." }
A.hex = { name = "Hex", hotkey = "X", icon = I .. "Spell_Shadow_Charm", target = "enemy", range = 8,
    mana = { 70 }, cd = { 7 }, duration = { 15, 30, 45 }, heroDuration = { 7, 8, 9 },
    text = "Turns an enemy into a sheep for %d seconds." }
A.serpent_ward = { name = "Serpent Ward", hotkey = "W", icon = I .. "Spell_Nature_GuardianWard", target = "point", range = 5,
    mana = { 30 }, cd = { 6.5 }, summon = "serpent_ward", count = { 1 }, duration = { 40 },
    text = "A ward that shoots enemies for %d seconds." }
A.big_bad_voodoo = { name = "Big Bad Voodoo", hotkey = "V", ult = true, icon = I .. "Spell_Shadow_ShadowWordDominate",
    target = "self", mana = { 200 }, cd = { 180 }, duration = { 30 }, radius = 8,
    text = "Friendly units nearby are invulnerable for %d seconds." }

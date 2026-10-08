-- Warcraft 4: the WoW classes (Hero Defense's heroes). Warrior, Paladin,
-- Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid and Death Knight, each
-- played as in Classic (Forever) and Wrath (the Death Knight): rage, energy
-- and combo points, runic power, pets, forms. Up to level 25, a skill point
-- a level (Warcraft III style): four spells of four ranks, an ultimate of
-- three, and Attributes for the rest.
--
-- Spells are data: a list of effects (fx) run in order - damage, heal, a
-- damage or healing over time, a shield, a stun, a buff, an area, a summon,
-- a blink, a charge. Generic rules here; the numbers in the class tables.
-- Looks: one WoW NPC per class and side (CLASS_LOOKS) - easy to change.
local ADDON, ns = ...

local WC = ns.WC
local E = WC.Engine
local U, A = WC.Units, WC.Abilities
local I = "Interface\\Icons\\"
local ATAN2 = math.atan2 or math.atan

local C = {}
WC.Classes = C

local function At(t, lv) if type(t) ~= "table" then return t end return t[lv] or t[#t] end
C.At = At

C.NEEDS = { 1, 4, 8, 12 }        -- the hero level each rank of a spell opens at
C.ULT_NEEDS = { 6, 12, 18 }      -- an ultimate's
C.ATTR_NEEDS = { 2, 5, 9, 14, 19, 24 }
C.MAX_LEVEL = 25

---------------------------------------------------------------------------
-- Looks: a WoW NPC of the class for each side (Alliance, Horde). Classic
-- has no Horde paladins or Alliance shamans: those share one.
---------------------------------------------------------------------------
C.LOOKS = {
    warrior = { 913, 3353 },        -- Lyria Du Lac / Grezz Ragefist
    paladin = { 928, 928 },         -- Lord Grayson Shadowbreaker
    hunter = { 5516, 3352 },        -- Ulfir Ironbeard / Ormak Grimshot
    rogue = { 918, 3401 },          -- Osborne the Night Man / Shenthul
    priest = { 376, 6018 },         -- High Priestess Laurena / Ur'kyo
    shaman = { 3344, 3344 },        -- Kardris Dreamseeker
    mage = { 5498, 5882 },          -- Elsharin / Pephredo
    warlock = { 461, 3326 },        -- Demisette Cloyce / Zevrost
    druid = { 5504, 3033 },         -- Sheldras Moontree / Turak Runetotem
    death_knight = { 14516, 14516 }, -- Death Knight Darkreaver
}

---------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------
-- Every class has Attributes: +2 strength, agility and intellect a rank.
A.attributes = { name = "Attributes", hotkey = "Z", icon = I .. "INV_Misc_Book_11", passive = "stats", needs = C.ATTR_NEEDS,
    amount = { 2, 4, 6, 8, 10, 12 }, text = "+%d strength, agility and intellect." }

local function Spell(key, t)
    t.needs = t.needs or (t.ult and C.ULT_NEEDS or C.NEEDS)
    t.classSpell = true
    A[key] = t
    if t.fx then E.CAST[key] = function(st, u, lv, a, tgt, x, y) C.Run(st, u, lv, a, tgt, x, y) end end
    return t
end
C.Spell = Spell

-- Warrior (rage)
Spell("heroic_strike", { name = "Heroic Strike", hotkey = "Q", icon = I .. "Ability_Rogue_Ambush", target = "enemy", range = 1.6,
    mana = 15, cd = 3, ai = "nuke", fx = { { "damage", { 55, 100, 155, 220 }, physical = true } },
    text = "A heavy blow: %d damage." })
Spell("thunder_clap_w", { name = "Thunder Clap", hotkey = "W", icon = I .. "Spell_Nature_ThunderClap", target = "self",
    mana = 20, cd = 8, radius = 2.8, ai = "aoe_self", fx = { { "aoe", { 40, 75, 115, 160 }, slow = 4 } },
    text = "Hits every enemy around you for %d and slows them." })
Spell("charge", { name = "Charge", hotkey = "E", icon = I .. "Ability_Warrior_Charge", target = "enemy", range = 9, mana = 0,
    cd = { 15, 13, 11, 9 }, ai = "engage", fx = { { "charge" }, { "stun", { 1, 1.25, 1.5, 2 } }, { "power", 20 } },
    text = "Rush at an enemy, stun it for %s seconds and gain 20 rage." })
Spell("battle_shout", { name = "Battle Shout", hotkey = "R", icon = I .. "Ability_Warrior_BattleShout", target = "self",
    mana = 10, cd = 30, radius = 8, ai = "buff_group", fx = { { "buff", "battle_shout", 30, dmg = { 0.1, 0.15, 0.2, 0.25 }, allies = true } },
    text = "You and friends nearby hit harder for 30 seconds." })
Spell("recklessness", { name = "Recklessness", hotkey = "T", ult = true, icon = I .. "Ability_CriticalStrike", target = "self",
    mana = 0, cd = 120, ai = "burst", fx = { { "buff", "recklessness", 12, dmg = { 0.5, 0.75, 1 }, haste = { 0.3, 0.4, 0.5 }, taken = 0.2 } },
    text = "For 12 seconds: much more damage, faster attacks; you take 20% more." })

-- Paladin (mana)
Spell("holy_light_p", { name = "Holy Light", hotkey = "Q", icon = I .. "Spell_Holy_HolyBolt", target = "ally", range = 7,
    mana = { 50, 70, 90, 110 }, cd = 5, ai = "heal", fx = { { "heal", { 150, 300, 450, 600 } } }, text = "Heals a friend for %d." })
Spell("judgement", { name = "Judgement", hotkey = "W", icon = I .. "Spell_Holy_RighteousFury", target = "enemy", range = 5,
    mana = 40, cd = 8, ai = "nuke", fx = { { "damage", { 70, 130, 200, 280 } }, { "stun", 1 } },
    text = "Holy damage, %d, and a one-second stun." })
Spell("consecration", { name = "Consecration", hotkey = "E", icon = I .. "Spell_Holy_InnerFire", target = "self", radius = 3,
    mana = 60, cd = 12, ai = "aoe_self", fx = { { "field", { 15, 25, 40, 55 }, 8 } },
    text = "Holy ground round you: %d damage a second to enemies on it for 8 seconds." })
Spell("devotion_aura", { name = "Devotion Aura", hotkey = "R", icon = I .. "Spell_Holy_DevotionAura", passive = "aura", radius = 9,
    aura = { armor = { 2, 4, 6, 8 } }, text = "You and friends nearby: +%d armour." })
Spell("divine_shield_p", { name = "Divine Shield", hotkey = "T", ult = true, icon = I .. "Spell_Holy_DivineIntervention",
    target = "self", mana = 50, cd = 90, ai = "save", fx = { { "buff", "invuln", { 6, 9, 12 } }, { "heal", { 0.3, 0.4, 0.5 }, share = true } },
    text = "Can't be hurt for %d seconds, and heals you." })

-- Hunter (mana, a pet)
Spell("arcane_shot", { name = "Arcane Shot", hotkey = "Q", icon = I .. "Ability_ImpalingBolt", target = "enemy", range = 7,
    mana = 25, cd = 5, ai = "nuke", fx = { { "damage", { 60, 110, 170, 240 } } }, text = "%d arcane damage." })
Spell("multi_shot", { name = "Multi-Shot", hotkey = "W", icon = I .. "Ability_UpgradeMoonGlaive", target = "enemy", range = 7,
    mana = 40, cd = 9, ai = "nuke", fx = { { "multi", { 50, 85, 125, 170 }, n = { 3, 4, 5, 6 }, radius = 4 } },
    text = "Shoots %d damage into the target and the enemies near it." })
Spell("serpent_sting", { name = "Serpent Sting", hotkey = "E", icon = I .. "Ability_Hunter_Quickshot", target = "enemy", range = 7,
    mana = 30, cd = 6, ai = "dot", fx = { { "dot", "serpent", { 12, 20, 30, 42 }, 10 } }, text = "Poison: %d damage a second for 10 seconds." })
Spell("call_pet", { name = "Call Pet", hotkey = "R", icon = I .. "Ability_Hunter_BeastCall", target = "self", mana = 40, cd = 20,
    ai = "pet", fx = { { "pet", "pet_wolf" } }, text = "Your wolf comes (a stronger one each rank); if it fell, a new one." })
Spell("volley", { name = "Volley", hotkey = "T", ult = true, icon = I .. "Ability_Marksmanship", target = "point", range = 8, radius = 3,
    mana = 120, cd = 60, ai = "aoe_point", fx = { { "field", { 60, 95, 130 }, 5 } }, text = "Arrows rain down: %d damage a second for 5 seconds." })

-- Rogue (energy, combo points)
Spell("sinister_strike", { name = "Sinister Strike", hotkey = "Q", icon = I .. "Spell_Shadow_RitualOfSacrifice", target = "enemy",
    range = 1.6, mana = 40, cd = 1, ai = "builder", fx = { { "damage", { 45, 80, 120, 165 }, physical = true }, { "combo", 1 } },
    text = "%d damage and a combo point." })
Spell("eviscerate", { name = "Eviscerate", hotkey = "W", icon = I .. "Ability_Rogue_Eviscerate", target = "enemy", range = 1.6,
    mana = 35, cd = 1, ai = "finisher", fx = { { "finisher", { 35, 60, 90, 125 } } },
    text = "Finisher: %d damage for each combo point." })
Spell("stealth", { name = "Stealth", hotkey = "E", icon = I .. "Ability_Stealth", target = "self", mana = 0, cd = { 20, 16, 12, 8 },
    ai = "opener", fx = { { "buff", "invis", 20 }, { "buff", "ambush", 20, dmg = { 1, 1.5, 2, 2.5 } } },
    text = "Unseen until you strike; that first strike hits much harder." })
Spell("kidney_shot", { name = "Kidney Shot", hotkey = "R", icon = I .. "Ability_Rogue_KidneyShot", target = "enemy", range = 1.6,
    mana = 25, cd = 15, ai = "finisher", fx = { { "stunCombo", { 0.5, 0.75, 1, 1.25 } } },
    text = "Finisher: a stun of %s seconds for each combo point." })
Spell("adrenaline_rush", { name = "Adrenaline Rush", hotkey = "T", ult = true, icon = I .. "Spell_Shadow_ShadowWordDominate",
    target = "self", mana = 0, cd = 120, ai = "burst", fx = { { "buff", "adrenaline", 15, haste = { 0.2, 0.35, 0.5 }, energy = 2 } },
    text = "For 15 seconds: twice the energy, faster attacks." })

-- Priest (mana)
Spell("flash_heal", { name = "Flash Heal", hotkey = "Q", icon = I .. "Spell_Holy_FlashHeal", target = "ally", range = 7,
    mana = { 40, 60, 80, 100 }, cd = 4, ai = "heal", fx = { { "heal", { 120, 230, 350, 480 } } }, text = "Heals a friend for %d." })
Spell("pw_shield", { name = "Power Word: Shield", hotkey = "W", icon = I .. "Spell_Holy_PowerWordShield", target = "ally", range = 7,
    mana = 50, cd = 10, ai = "shield", fx = { { "shield", { 100, 200, 320, 450 }, 20 } }, text = "Absorbs %d damage for 20 seconds." })
Spell("sw_pain", { name = "Shadow Word: Pain", hotkey = "E", icon = I .. "Spell_Shadow_ShadowWordPain", target = "enemy", range = 7,
    mana = 30, cd = 5, ai = "dot", fx = { { "dot", "swpain", { 14, 24, 36, 50 }, 12 } }, text = "%d shadow damage a second for 12 seconds." })
Spell("renew", { name = "Renew", hotkey = "R", icon = I .. "Spell_Holy_Renew", target = "ally", range = 7, mana = 40, cd = 8,
    ai = "hot", fx = { { "hot", "renew", { 15, 28, 42, 58 }, 12 } }, text = "Heals %d a second for 12 seconds." })
Spell("prayer_of_healing", { name = "Prayer of Healing", hotkey = "T", ult = true, icon = I .. "Spell_Holy_PrayerOfHealing02",
    target = "self", radius = 10, mana = 150, cd = 50, ai = "heal_group", fx = { { "aoeheal", { 300, 500, 700 } } },
    text = "Heals you and every friend nearby for %d." })

-- Shaman (mana)
Spell("lightning_bolt", { name = "Lightning Bolt", hotkey = "Q", icon = I .. "Spell_Nature_Lightning", target = "enemy", range = 7,
    mana = { 35, 50, 65, 80 }, cd = 4, ai = "nuke", fx = { { "damage", { 75, 140, 215, 300 } } }, text = "%d nature damage." })
Spell("chain_heal", { name = "Chain Heal", hotkey = "W", icon = I .. "Spell_Nature_HealingWaveGreater", target = "ally", range = 7,
    mana = 60, cd = 7, radius = 5, ai = "heal", fx = { { "chainheal", { 120, 220, 330, 450 }, n = 3 } },
    text = "Heals %d, then jumps to two more friends (less each time)." })
Spell("frost_shock", { name = "Frost Shock", hotkey = "E", icon = I .. "Spell_Frost_FrostShock", target = "enemy", range = 6,
    mana = 40, cd = 8, ai = "nuke", fx = { { "damage", { 50, 95, 145, 200 } }, { "slow", 4 } }, text = "%d frost damage and a slow." })
Spell("windfury", { name = "Windfury Weapon", hotkey = "R", icon = I .. "Spell_Nature_Windfury", passive = "onhit",
    onhit = { chance = { 10, 15, 20, 25 }, extra = 1 }, text = "%d%% of your hits strike a second time." })
Spell("bloodlust_s", { name = "Bloodlust", hotkey = "T", ult = true, icon = I .. "Spell_Nature_BloodLust", target = "self",
    radius = 10, mana = 100, cd = 120, ai = "buff_group", fx = { { "buff", "bloodlust", { 20, 30, 40 }, allies = true } },
    text = "You and friends nearby attack and move faster for %d seconds." })

-- Mage (mana)
Spell("fireball", { name = "Fireball", hotkey = "Q", icon = I .. "Spell_Fire_FlameBolt", target = "enemy", range = 7,
    mana = { 40, 55, 70, 90 }, cd = 4, ai = "nuke", fx = { { "damage", { 90, 165, 250, 350 } }, { "dot", "burn", { 5, 9, 13, 18 }, 4 } },
    text = "%d fire damage, and it burns." })
Spell("frost_nova", { name = "Frost Nova", hotkey = "W", icon = I .. "Spell_Frost_FrostNova", target = "self", radius = 3,
    mana = 50, cd = 15, ai = "aoe_self", fx = { { "aoe", { 30, 55, 80, 110 }, root = { 2, 3, 4, 5 } } },
    text = "%d frost damage round you; enemies are frozen in place." })
Spell("blizzard_m", { name = "Blizzard", hotkey = "E", icon = I .. "Spell_Frost_IceStorm", target = "point", range = 8, radius = 3,
    mana = 70, cd = 10, ai = "aoe_point", fx = { { "field", { 20, 37, 55, 75 }, 6, slow = true } },
    text = "Ice falls: %d damage a second for 6 seconds, and slows." })
Spell("blink", { name = "Blink", hotkey = "R", icon = I .. "Spell_Arcane_Blink", target = "point", range = 8, mana = 20,
    cd = { 14, 12, 10, 8 }, ai = "escape", fx = { { "blink" } }, text = "Teleport a short way." })
Spell("water_elemental_m", { name = "Summon Water Elemental", hotkey = "T", ult = true, icon = WC.Abilities.water_elemental.icon,
    target = "self", mana = 125, cd = 60, ai = "summon", fx = { { "summon", "water_elemental", 1, 60 } },
    text = "A Water Elemental fights for you for a minute." })

-- Warlock (mana, a demon)
Spell("shadow_bolt", { name = "Shadow Bolt", hotkey = "Q", icon = I .. "Spell_Shadow_ShadowBolt", target = "enemy", range = 7,
    mana = { 40, 55, 70, 90 }, cd = 4, ai = "nuke", fx = { { "damage", { 85, 155, 235, 330 } } }, text = "%d shadow damage." })
Spell("corruption", { name = "Corruption", hotkey = "W", icon = I .. "Spell_Shadow_AbominationExplosion", target = "enemy", range = 7,
    mana = 30, cd = 4, ai = "dot", fx = { { "dot", "corruption", { 15, 26, 40, 55 }, 12 } }, text = "%d shadow damage a second for 12 seconds." })
Spell("drain_life", { name = "Drain Life", hotkey = "E", icon = I .. "Spell_Shadow_LifeDrain02", target = "enemy", range = 6,
    mana = 45, cd = 8, ai = "nuke", fx = { { "damage", { 40, 75, 115, 160 }, drain = 1 } }, text = "%d damage, and you get it as health." })
Spell("summon_voidwalker", { name = "Summon Voidwalker", hotkey = "R", icon = I .. "Spell_Shadow_SummonVoidWalker", target = "self",
    mana = 60, cd = 20, ai = "pet", fx = { { "pet", "pet_voidwalker" } }, text = "Your Voidwalker comes (stronger each rank): it holds enemies off you." })
Spell("rain_of_fire", { name = "Rain of Fire", hotkey = "T", ult = true, icon = I .. "Spell_Shadow_RainOfFire", target = "point",
    range = 8, radius = 3.2, mana = 120, cd = 45, ai = "aoe_point", fx = { { "field", { 50, 80, 110 }, 8 } },
    text = "Fire rains down: %d damage a second for 8 seconds." })

-- Druid (mana, forms)
Spell("wrath", { name = "Wrath", hotkey = "Q", icon = I .. "Spell_Nature_AbolishMagic", target = "enemy", range = 7,
    mana = { 35, 50, 65, 80 }, cd = 3, ai = "nuke", fx = { { "damage", { 70, 130, 195, 270 } } }, text = "%d nature damage." })
Spell("rejuvenation", { name = "Rejuvenation", hotkey = "W", icon = I .. "Spell_Nature_Rejuvenation", target = "ally", range = 7,
    mana = 40, cd = 5, ai = "hot", fx = { { "hot", "rejuv", { 18, 32, 48, 66 }, 12 } }, text = "Heals %d a second for 12 seconds." })
Spell("entangling_roots", { name = "Entangling Roots", hotkey = "E", icon = I .. "Spell_Nature_StrangleVines", target = "enemy",
    range = 7, mana = 50, cd = 12, ai = "nuke", fx = { { "root", { 3, 4, 5, 6 } }, { "dot", "roots", { 8, 14, 20, 28 }, 6 } },
    text = "Holds an enemy in place for %d seconds and hurts it." })
Spell("bear_form", { name = "Bear Form", hotkey = "R", icon = I .. "Ability_Racial_BearForm", target = "self", mana = 0, cd = 2,
    ai = "form", fx = { { "form", "bear", armor = { 4, 7, 10, 14 }, dmg = { 0.2, 0.3, 0.4, 0.5 }, taken = -0.15 } },
    text = "Change into a bear (again: back): +%d armour, harder hits, less damage taken." })
Spell("tranquility", { name = "Tranquility", hotkey = "T", ult = true, icon = I .. "Spell_Nature_Tranquility", target = "self",
    radius = 10, mana = 150, cd = 90, ai = "heal_group", fx = { { "hot", "tranquil", { 60, 90, 120 }, 8, allies = true } },
    text = "Heals you and friends nearby %d a second for 8 seconds." })

-- Death Knight (runic power: strikes build it, Death Coil spends it)
Spell("death_grip", { name = "Death Grip", hotkey = "Q", icon = I .. "Spell_DeathKnight_Strangulate", target = "enemy", range = 8,
    mana = 0, cd = { 20, 16, 12, 9 }, ai = "engage", fx = { { "grip" }, { "taunt" }, { "power", 10 } },
    text = "Pull an enemy to you; it has to fight you." })
Spell("icy_touch", { name = "Icy Touch", hotkey = "W", icon = I .. "Spell_DeathKnight_IceTouch", target = "enemy", range = 6, mana = 0,
    cd = 5, ai = "nuke", fx = { { "damage", { 55, 100, 150, 210 } }, { "slow", 6 }, { "power", 15 } },
    text = "%d frost damage and a slow; 15 runic power." })
Spell("plague_strike", { name = "Plague Strike", hotkey = "E", icon = I .. "Spell_DeathKnight_EmpowerRuneBlade", target = "enemy",
    range = 1.6, mana = 0, cd = 5, ai = "dot", fx = { { "damage", { 35, 60, 90, 125 }, physical = true }, { "dot", "plague", { 10, 18, 27, 38 }, 12 }, { "power", 15 } },
    text = "%d damage and a plague; 15 runic power." })
Spell("death_coil", { name = "Death Coil", hotkey = "R", icon = I .. "Spell_Shadow_DeathCoil", target = "enemy", range = 6, mana = 40,
    cd = 3, ai = "nuke", fx = { { "damage", { 120, 220, 330, 450 } } }, text = "Spend runic power: %d shadow damage." })
Spell("army_of_the_dead", { name = "Army of the Dead", hotkey = "T", ult = true, icon = I .. "Spell_DeathKnight_ArmyOfTheDead",
    target = "self", mana = 0, cd = 120, ai = "summon", fx = { { "summon", "dk_ghoul", { 4, 6, 8 }, 30 } },
    text = "Ghouls rise to fight for you for 30 seconds." })

---------------------------------------------------------------------------
-- Pets and summons (stronger each rank)
---------------------------------------------------------------------------
for lv = 1, 4 do
    WC.Derive("Units", "pet_wolf" .. lv, "creep_wolf", { name = "Wolf", hp = 260 + 180 * lv, damage = 8 + 7 * lv, armor = lv,
        cost = { 0, 0 }, food = 0, requires = false, pet = true, level = 2 })
    WC.Derive("Units", "pet_voidwalker" .. lv, "creep_ogre", { name = "Voidwalker", npc = 1860, hp = 400 + 280 * lv,
        damage = 6 + 5 * lv, armor = 3 + 2 * lv, cost = { 0, 0 }, food = 0, requires = false, pet = true, level = 2, taunts = true })
end
for lv = 1, 3 do
    WC.Derive("Units", "dk_ghoul" .. lv, "creep_kobold", { name = "Ghoul", npc = 846, hp = 200 + 120 * lv, damage = 10 + 6 * lv,
        cost = { 0, 0 }, food = 0, requires = false, level = 1 })
end

---------------------------------------------------------------------------
-- The classes
---------------------------------------------------------------------------
-- stats: str/agi/int = { at level 1, per level } (as the Warcraft III heroes:
-- health 100 + 25 x str, mana 15 x int, damage = base + the main stat).
local function Class(key, t)
    t.hero, t.food, t.time, t.cost, t.requires = true, 5, 3, { 0, 0 }, false
    t.attackType, t.armorType, t.maxLevel, t.class, t.reviveCost = "hero", "hero", C.MAX_LEVEL, key, 0
    t.hp = 100 + 25 * t.str[1]
    t.damage = t.baseDamage + t[t.primary][1]
    t.armor = t.baseArmor
    table.insert(t.abilities, "attributes")
    local looks = C.LOOKS[key]
    t.npc = looks[1]
    U["cls_" .. key] = t
    WC.Derive("Units", "cls_" .. key .. "_h", "cls_" .. key, { npc = looks[2] })
    return t
end

C.ORDER = { "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid", "death_knight" }
Class("warrior", { name = "Warrior", hotkey = "W", primary = "str", power = "rage", str = { 24, 3 }, agi = { 14, 1.5 },
    int = { 12, 1 }, baseDamage = 5, baseArmor = 4, cooldown = 1.9, range = 1, speed = 2.8, icon = I .. "INV_Sword_27",
    abilities = { "heroic_strike", "thunder_clap_w", "charge", "battle_shout", "recklessness" } })
Class("paladin", { name = "Paladin", hotkey = "P", primary = "str", str = { 22, 2.7 }, agi = { 13, 1.3 }, int = { 17, 2 },
    baseDamage = 4, baseArmor = 4, cooldown = 2.1, range = 1, speed = 2.7, icon = I .. "Spell_Holy_HolyBolt",
    abilities = { "holy_light_p", "judgement", "consecration", "devotion_aura", "divine_shield_p" } })
Class("hunter", { name = "Hunter", hotkey = "H", primary = "agi", str = { 16, 1.8 }, agi = { 22, 2.6 }, int = { 15, 1.6 },
    baseDamage = 4, baseArmor = 2, cooldown = 1.9, range = 6, speed = 2.9, icon = I .. "INV_Weapon_Bow_07",
    abilities = { "arcane_shot", "multi_shot", "serpent_sting", "call_pet", "volley" } })
Class("rogue", { name = "Rogue", hotkey = "R", primary = "agi", power = "energy", str = { 17, 1.8 }, agi = { 23, 2.8 }, int = { 12, 1 },
    baseDamage = 5, baseArmor = 2, cooldown = 1.5, range = 1, speed = 3.1, icon = I .. "Ability_Stealth",
    abilities = { "sinister_strike", "eviscerate", "stealth", "kidney_shot", "adrenaline_rush" } })
Class("priest", { name = "Priest", hotkey = "I", primary = "int", str = { 14, 1.5 }, agi = { 13, 1 }, int = { 22, 3.1 },
    baseDamage = 3, baseArmor = 1, cooldown = 2.1, range = 5, speed = 2.8, icon = I .. "Spell_Holy_PowerWordShield",
    abilities = { "flash_heal", "pw_shield", "sw_pain", "renew", "prayer_of_healing" } })
Class("shaman", { name = "Shaman", hotkey = "S", primary = "int", str = { 18, 2 }, agi = { 15, 1.4 }, int = { 20, 2.7 },
    baseDamage = 4, baseArmor = 3, cooldown = 2, range = 5, speed = 2.8, icon = I .. "Spell_Nature_BloodLust",
    abilities = { "lightning_bolt", "chain_heal", "frost_shock", "windfury", "bloodlust_s" } })
Class("mage", { name = "Mage", hotkey = "M", primary = "int", str = { 13, 1.4 }, agi = { 14, 1 }, int = { 23, 3.2 },
    baseDamage = 3, baseArmor = 1, cooldown = 2.1, range = 5.5, speed = 2.8, icon = I .. "Spell_Frost_FrostBolt02",
    abilities = { "fireball", "frost_nova", "blizzard_m", "blink", "water_elemental_m" } })
Class("warlock", { name = "Warlock", hotkey = "L", primary = "int", str = { 15, 1.6 }, agi = { 13, 1 }, int = { 22, 3 },
    baseDamage = 3, baseArmor = 1, cooldown = 2.1, range = 5, speed = 2.8, icon = I .. "Spell_Shadow_DeathCoil",
    abilities = { "shadow_bolt", "corruption", "drain_life", "summon_voidwalker", "rain_of_fire" } })
Class("druid", { name = "Druid", hotkey = "D", primary = "int", str = { 18, 2.1 }, agi = { 16, 1.6 }, int = { 20, 2.6 },
    baseDamage = 4, baseArmor = 2, cooldown = 2, range = 4.5, speed = 2.9, icon = I .. "Ability_Druid_CatForm",
    abilities = { "wrath", "rejuvenation", "entangling_roots", "bear_form", "tranquility" } })
Class("death_knight", { name = "Death Knight", hotkey = "K", primary = "str", power = "runic", str = { 24, 3 }, agi = { 13, 1.4 },
    int = { 14, 1.4 }, baseDamage = 5, baseArmor = 5, cooldown = 2, range = 1, speed = 2.7, icon = I .. "Spell_Shadow_AnimateDead",
    abilities = { "death_grip", "icy_touch", "plague_strike", "death_coil", "army_of_the_dead" } })

-- The heroes an altar offers (Alliance looks, or Horde).
function C.Heroes(horde)
    local out = {}
    for _, k in ipairs(C.ORDER) do table.insert(out, "cls_" .. k .. (horde and "_h" or "")) end
    return out
end

---------------------------------------------------------------------------
-- Running a spell's effects
---------------------------------------------------------------------------
local function Foes(st, u, x, y, r)
    local out = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and not e.dead and e.kind == "unit" and E.Foe(st, e.owner, u.owner) and not E.Untouchable(e)
            and (e.x - x) ^ 2 + (e.y - y) ^ 2 <= r * r then table.insert(out, e) end
    end
    return out
end
local function Friends(st, u, x, y, r)
    local out = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and not e.dead and e.kind == "unit" and E.Ally(st, e.owner, u.owner) and (e.x - x) ^ 2 + (e.y - y) ^ 2 <= r * r then
            table.insert(out, e)
        end
    end
    return out
end
C.Foes, C.Friends = Foes, Friends

local function Heal(st, u, t, n)
    if not t or t.dead then return end
    local before = t.hp
    t.hp = math.min(t.maxHp, t.hp + n)
    if t.hp > before then E.Emit("heal", { id = u.id, target = t.id, amount = math.floor(t.hp - before) }) end
end
C.Heal = Heal

local function Hurt(st, u, t, n, physical)
    if not t or t.dead then return end
    E.Strike(st, u, t, n, true, physical and "hero" or "spell")
end

-- Stat buffs on a unit: buffs named cls_<name> with dmg, haste, armor, speed, taken.
local function Buff(u, name, dur, f, lv)
    local b = { dmg = At(f.dmg, lv), haste = At(f.haste, lv), armor = At(f.armor, lv), speed = At(f.speed, lv), taken = At(f.taken, lv),
        energy = At(f.energy, lv) }
    E.AddBuff(u, name, dur, b)
end

function C.Run(st, u, lv, a, t, x, y)
    for _, f in ipairs(a.fx) do
        local kind = f[1]
        if kind == "damage" then
            local n = At(f[2], lv)
            Hurt(st, u, t, n, f.physical)
            if f.drain then Heal(st, u, u, n * f.drain) end
        elseif kind == "aoe" then
            for _, e in ipairs(Foes(st, u, u.x, u.y, a.radius)) do
                Hurt(st, u, e, At(f[2], lv))
                if f.slow and not e.dead then E.AddBuff(e, "slow", f.slow) end
                if f.root and not e.dead then E.AddBuff(e, "ensnare", At(f.root, lv)) end
            end
        elseif kind == "multi" then
            local hit = { t }
            for _, e in ipairs(Foes(st, u, t.x, t.y, f.radius)) do
                if e ~= t and #hit < At(f.n, lv) then table.insert(hit, e) end
            end
            for _, e in ipairs(hit) do Hurt(st, u, e, At(f[2], lv)) end
        elseif kind == "heal" then
            local who = t or u
            local n = At(f[2], lv)
            if f.share then n = who.maxHp * n end
            Heal(st, u, who, n)
        elseif kind == "aoeheal" then
            for _, e in ipairs(Friends(st, u, u.x, u.y, a.radius)) do Heal(st, u, e, At(f[2], lv)) end
        elseif kind == "chainheal" then
            local n, done, cur = At(f[2], lv), {}, t
            for _ = 1, f.n do
                if not cur then break end
                Heal(st, u, cur, n)
                done[cur] = true
                n = n * 0.7
                local nxt, worst
                for _, e in ipairs(Friends(st, u, cur.x, cur.y, a.radius or 5)) do
                    if not done[e] and e.hp < e.maxHp and (not worst or e.maxHp - e.hp > worst) then nxt, worst = e, e.maxHp - e.hp end
                end
                cur = nxt
            end
        elseif kind == "dot" or kind == "hot" then
            local list = f.allies and Friends(st, u, u.x, u.y, a.radius) or { t or u }
            for _, e in ipairs(list) do
                if e and not e.dead then
                    E.AddBuff(e, kind .. "_" .. f[2], f[4], { per = At(f[3], lv), src = u.id, owner = u.owner, tick = 1 })
                end
            end
        elseif kind == "shield" then
            E.AddBuff(t or u, "shield", f[3], { left = At(f[2], lv) })
        elseif kind == "stun" then
            if t and not t.dead then E.AddBuff(t, "stun", At(f[2], lv)) end
        elseif kind == "slow" then
            if t and not t.dead then E.AddBuff(t, "slow", At(f[2], lv)) end
        elseif kind == "root" then
            if t and not t.dead then E.AddBuff(t, "ensnare", At(f[2], lv)) end
        elseif kind == "buff" then
            local name = f[2]
            local list = f.allies and Friends(st, u, u.x, u.y, a.radius) or { u }
            for _, e in ipairs(list) do
                if name == "invuln" or name == "invis" or name == "bloodlust" then
                    E.AddBuff(e, name, At(f[3], lv))
                else
                    Buff(e, "cls_" .. name, At(f[3], lv), f, lv)
                end
            end
        elseif kind == "form" then
            local name = "cls_form_" .. f[2]
            u.buffs = u.buffs or {}
            if u.buffs[name] then u.buffs[name] = nil else Buff(u, name, 1e9, f, lv) end
        elseif kind == "field" then
            st.fields = st.fields or {}
            table.insert(st.fields, { x = x or u.x, y = y or u.y, r = a.radius, per = At(f[2], lv), left = f[3], next = 0,
                src = u.id, owner = u.owner, slow = f.slow, key = a.name })
        elseif kind == "blink" then
            local fx, fy = E.NearestFree(st, math.floor(x), math.floor(y))
            if fx then u.x, u.y, u.path = fx + 0.5, fy + 0.5, nil end
        elseif kind == "charge" or kind == "grip" then
            if t and not t.dead then
                local mover, to = kind == "charge" and u or t, kind == "charge" and t or u
                local dx, dy = mover.x - to.x, mover.y - to.y
                local d = math.max(0.01, math.sqrt(dx * dx + dy * dy))
                local fx, fy = E.NearestFree(st, math.floor(to.x + dx / d * 1.1), math.floor(to.y + dy / d * 1.1))
                if fx then mover.x, mover.y, mover.path = fx + 0.5, fy + 0.5, nil end
                if kind == "charge" then u.order = { type = "attack", target = t.id } end
            end
        elseif kind == "taunt" then
            if t and not t.dead then t.order, t.path = { type = "attack", target = u.id }, nil end
        elseif kind == "power" then
            u.mana = math.min(u.maxMana or 100, (u.mana or 0) + f[2])
        elseif kind == "combo" then
            if t then
                if u.comboOn ~= t.id then u.combo, u.comboOn = 0, t.id end
                u.combo = math.min(5, (u.combo or 0) + f[2])
            end
        elseif kind == "finisher" or kind == "stunCombo" then
            local cp = (u.comboOn == (t and t.id)) and (u.combo or 0) or 0
            cp = math.max(1, cp)
            if kind == "finisher" then Hurt(st, u, t, At(f[2], lv) * cp, true)
            elseif t and not t.dead then E.AddBuff(t, "stun", At(f[2], lv) * cp) end
            u.combo, u.comboOn = 0, nil
        elseif kind == "pet" then
            -- One pet: a new one if it fell, else it comes back to you healed.
            local pet = st.ents[u.pet or 0]
            if pet and not pet.dead then
                Heal(st, u, pet, pet.maxHp)
                local fx, fy = E.NearestFree(st, math.floor(u.x + 1), math.floor(u.y))
                if fx then pet.x, pet.y, pet.path = fx + 0.5, fy + 0.5, nil end
            else
                local fx, fy = E.NearestFree(st, math.floor(u.x + 1), math.floor(u.y))
                if fx then
                    local p = E.Spawn(st, u.owner, f[2] .. lv, fx + 0.5, fy + 0.5)
                    p.master = u.id
                    u.pet = p.id
                end
            end
        elseif kind == "summon" then
            for i = 1, At(f[3], lv) do
                local fx, fy = E.NearestFree(st, math.floor(u.x + (i - 1) % 3 - 1), math.floor(u.y + 1 + math.floor((i - 1) / 3)))
                if fx then
                    local base = f[2]
                    local s = E.Spawn(st, u.owner, U[base .. lv] and (base .. lv) or (base .. "1"), fx + 0.5, fy + 0.5)
                    s.summon, s.expire, s.master = true, st.time + f[4], u.id
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- The rules the effects need: buffs, auras, stats, power, ground effects,
-- damage over time, pets following their master. (Hooks round the engine's.)
---------------------------------------------------------------------------
-- Sum of a stat over a unit's cls_ buffs.
local function BuffSum(u, field)
    local n = 0
    for name, b in pairs(u.buffs or {}) do
        if name:sub(1, 4) == "cls_" and b[field] then n = n + b[field] end
    end
    return n
end
C.BuffSum = BuffSum

-- The best class aura of a field reaching unit u (Devotion Aura).
local function ClassAura(st, u, field)
    if not u.owner or u.owner < 1 then return 0 end
    local best = 0
    for _, id in ipairs(st.list) do
        local h = st.ents[id]
        if h and h.kind == "unit" and h.skills and E.Ally(st, h.owner, u.owner) then
            for key, lv in pairs(h.skills) do
                local a = A[key]
                if a and a.aura and a.aura[field] and (h.x - u.x) ^ 2 + (h.y - u.y) ^ 2 <= a.radius * a.radius then
                    best = math.max(best, At(a.aura[field], lv))
                end
            end
        end
    end
    return best
end
C.Aura = ClassAura

do
    local Stat = E.Stat
    function E.Stat(u, stat)
        local s = Stat(u, stat)
        local lv = u.skills and u.skills.attributes
        if lv then s = s + At(A.attributes.amount, lv) end
        return s
    end
    local Damage = E.Damage
    function E.Damage(st, u)
        local d = Damage(st, u)
        if u.buffs then
            local up = BuffSum(u, "dmg")
            local ambush = u.buffs.cls_ambush
            if ambush then up = up - ambush.dmg end -- (only the first strike: see OnHit)
            d = d * (1 + up)
        end
        return d
    end
    local ArmorOf = E.ArmorOf
    function E.ArmorOf(st, e)
        local a = ArmorOf(st, e)
        if e.kind == "unit" then a = a + BuffSum(e, "armor") + ClassAura(st, e, "armor") end
        return a
    end
    local Cooldown = E.Cooldown
    function E.Cooldown(st, u)
        local cd = Cooldown(st, u)
        local h = BuffSum(u, "haste")
        return h > 0 and cd / (1 + h) or cd
    end
    local OnHit = E.OnHit
    function E.OnHit(st, u, t, dmg)
        dmg = OnHit(st, u, t, dmg)
        local d = U[u.type]
        if not d then return dmg end
        -- Stealth's opening strike.
        if u.buffs and u.buffs.cls_ambush then
            dmg = dmg * (1 + u.buffs.cls_ambush.dmg)
            u.buffs.cls_ambush = nil
        end
        -- Windfury: a second hit.
        local wf = u.skills and u.skills.windfury
        if wf and E.Rand(st, 100) <= At(A.windfury.onhit.chance, wf) then
            dmg = dmg * 2
            E.Emit("crit", { id = u.id, target = t.id, amount = math.floor(dmg) })
        end
        -- Rage and runic power come from fighting.
        if d.power == "rage" or d.power == "runic" then
            u.mana = math.min(u.maxMana or 100, (u.mana or 0) + (d.power == "rage" and 8 or 5))
        end
        return dmg
    end
    local OnTaken = E.OnTaken
    function E.OnTaken(st, t, dmg)
        dmg = OnTaken(st, t, dmg)
        if dmg <= 0 or not t.buffs then return dmg end
        local taken = BuffSum(t, "taken")
        if taken ~= 0 then dmg = math.max(0, dmg * (1 + taken)) end
        local sh = t.buffs.shield
        if sh and sh.left then
            local soak = math.min(sh.left, dmg)
            sh.left, dmg = sh.left - soak, dmg - soak
            if sh.left <= 0 then t.buffs.shield = nil end
        end
        -- (rage: taking hits builds it too)
        if U[t.type] and U[t.type].power == "rage" then t.mana = math.min(t.maxMana or 100, (t.mana or 0) + dmg * 0.08) end
        return dmg
    end
    local Speed = E.Speed
    function E.Speed(st, u)
        local s = Speed(st, u)
        local up = BuffSum(u, "speed")
        return up ~= 0 and s * (1 + up) or s
    end
    -- Each unit's step: damage and healing over time, energy and rage, a
    -- pet keeping up with its master.
    local Tick = E.UnitTick
    function E.UnitTick(st, u, dt)
        if Tick and Tick(st, u, dt) then return true end
        local b = u.buffs
        if b then
            for name, x in pairs(b) do
                if x.per and (name:sub(1, 4) == "dot_" or name:sub(1, 4) == "hot_") then
                    x.tick = x.tick - dt
                    if x.tick <= 0 then
                        x.tick = x.tick + 1
                        local src = st.ents[x.src or 0] or { id = x.src, owner = x.owner, kind = "unit", x = u.x, y = u.y }
                        if name:sub(1, 4) == "dot_" then Hurt(st, src, u, x.per) else Heal(st, src, u, x.per) end
                        if u.dead or not st.ents[u.id] then return true end
                    end
                end
            end
        end
        local d = U[u.type]
        -- Mana classes: WoW-style regeneration (a share of the pool, more with
        -- Intellect), so healers and casters keep casting.
        if d and d.class and not d.power and u.maxMana then
            u.mana = math.min(u.maxMana, (u.mana or 0) + (0.015 * u.maxMana + 0.1 * E.Stat(u, "int")) * dt)
        end
        if d and d.power == "energy" then
            local mult = 1 + (b and b.cls_adrenaline and 1 or 0)
            u.mana = math.min(u.maxMana or 100, (u.mana or 0) + 10 * mult * dt)
        elseif d and (d.power == "rage" or d.power == "runic") then
            u.mana = math.max(0, (u.mana or 0) - 1 * dt)
        end
        if u.master and not u.order then
            local m = st.ents[u.master]
            if m and (m.x - u.x) ^ 2 + (m.y - u.y) ^ 2 > 36 then E.Order(st, u, { type = "move", x = m.x + 1, y = m.y + 1 }) end
        end
    end
    -- Ground effects (Consecration, Blizzard, Volley, Rain of Fire).
    local World = E.WorldTick
    function E.WorldTick(st, dt)
        if World then World(st, dt) end
        if not st.fields or #st.fields == 0 then return end
        local keep = {}
        for _, fd in ipairs(st.fields) do
            fd.next = fd.next - dt
            if fd.next <= 0 then
                fd.next = fd.next + 1
                fd.left = fd.left - 1
                local src = st.ents[fd.src or 0] or { id = fd.src, owner = fd.owner, kind = "unit", x = fd.x, y = fd.y }
                for _, e in ipairs(Foes(st, src, fd.x, fd.y, fd.r)) do
                    Hurt(st, src, e, fd.per)
                    if fd.slow and not e.dead then E.AddBuff(e, "slow", 1.5) end
                end
            end
            if fd.left > 0 then table.insert(keep, fd) end
        end
        st.fields = keep
    end
end

---------------------------------------------------------------------------
-- The computer: learns (ultimate first when it can, then the lowest-ranked
-- spell, then Attributes) and casts by what each spell is for (ai).
---------------------------------------------------------------------------
do
    local Learn = WC.AI.Learn
    function WC.AI.Learn(st, p, h)
        local d = U[h.type]
        if not d.class then return Learn(st, p, h) end
        while (h.points or 0) > 0 do
            local pick, low
            for _, key in ipairs(d.abilities) do
                local a = A[key]
                local lv = E.Skill(h, key)
                local need = a.needs[lv + 1]
                if need and h.level >= need and key ~= "attributes" then
                    local rank = a.ult and -1 or lv -- (an ultimate first)
                    if not low or rank < low then pick, low = key, rank end
                end
            end
            pick = pick or "attributes"
            if not E.Command(st, p, { type = "learn", unit = h.id, ability = pick }) then return end
        end
    end

    local function Hurt(e) return e.hp / e.maxHp end
    local Cast = WC.AI.HeroCast
    function WC.AI.HeroCast(st, p, h)
        local d = U[h.type]
        if not d.class then return Cast(st, p, h) end
        if h.order and h.order.type == "cast" then return end
        local near = Foes(st, h, h.x, h.y, 7)
        for _, key in ipairs(d.abilities) do
            local a = A[key]
            local lv = E.Skill(h, key)
            local cost = At(a.mana, lv) or 0
            if lv > 0 and not a.passive and not (h.cds and h.cds[key]) and (h.mana or 0) >= cost then
                local cmd
                local ai = a.ai
                local range = (a.range or 0) + 1
                local closest
                for _, e in ipairs(near) do
                    if not closest or (e.x - h.x) ^ 2 + (e.y - h.y) ^ 2 < (closest.x - h.x) ^ 2 + (closest.y - h.y) ^ 2 then closest = e end
                end
                if (ai == "nuke" or ai == "dot" or ai == "builder" or ai == "engage") and closest
                    and (closest.x - h.x) ^ 2 + (closest.y - h.y) ^ 2 <= range * range then
                    if not (ai == "dot" and closest.buffs and next(closest.buffs)) then cmd = { target = closest.id } end
                elseif ai == "finisher" and closest and (h.combo or 0) >= 3 and h.comboOn then
                    local t = st.ents[h.comboOn]
                    if t and not t.dead then cmd = { target = t.id } end
                elseif ai == "heal" or ai == "hot" or ai == "shield" then
                    -- (a heal over time or a shield: not on someone who has it already)
                    local tag = a.fx[1] and type(a.fx[1][2]) == "string" and ("hot_" .. a.fx[1][2])
                    local worst
                    for _, e in ipairs(Friends(st, h, h.x, h.y, range)) do
                        local has = e.buffs and ((ai == "shield" and e.buffs.shield) or (tag and e.buffs[tag]))
                        if Hurt(e) < (ai == "heal" and 0.6 or 0.8) and not has and (not worst or Hurt(e) < Hurt(worst)) then worst = e end
                    end
                    if worst then cmd = { target = worst.id } end
                elseif ai == "heal_group" then
                    local hurt = 0
                    for _, e in ipairs(Friends(st, h, h.x, h.y, a.radius)) do if Hurt(e) < 0.6 then hurt = hurt + 1 end end
                    if hurt >= 2 or Hurt(h) < 0.35 then cmd = {} end
                elseif ai == "aoe_self" then
                    if #Foes(st, h, h.x, h.y, a.radius) >= 2 then cmd = {} end
                elseif ai == "aoe_point" then
                    for _, e in ipairs(near) do
                        if #Foes(st, h, e.x, e.y, a.radius) >= 3 then cmd = { x = e.x, y = e.y } break end
                    end
                elseif ai == "buff_group" or ai == "burst" then
                    if #near >= 3 then cmd = {} end
                elseif ai == "save" then
                    if Hurt(h) < 0.3 and #near > 0 then cmd = {} end
                elseif ai == "escape" then
                    if Hurt(h) < 0.35 and closest then
                        local dx, dy = h.x - closest.x, h.y - closest.y
                        local dd = math.max(0.01, math.sqrt(dx * dx + dy * dy))
                        cmd = { x = h.x + dx / dd * 6, y = h.y + dy / dd * 6 }
                    end
                elseif ai == "pet" then
                    local pet = st.ents[h.pet or 0]
                    if not pet or pet.dead then cmd = {} end
                elseif ai == "summon" then
                    if #near >= 3 then cmd = {} end
                elseif ai == "opener" then
                    if #near == 0 and not (h.buffs and h.buffs.invis) then cmd = {} end
                elseif ai == "form" then
                    if not (h.buffs and h.buffs.cls_form_bear) and Hurt(h) < 0.5 and #near > 0 then cmd = {} end
                end
                if cmd then
                    cmd.type, cmd.unit, cmd.ability = "cast", h.id, key
                    if E.Command(st, p, cmd) then return end
                end
            end
        end
    end
end

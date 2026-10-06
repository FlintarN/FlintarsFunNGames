-- Hearthstone cards: data only. Values are the original Hearthstone ones
-- (Basic set, plus a few Classic cards for keywords).
--
-- A card:
--   key, name, cost, type ("minion" | "spell"), class ("neutral", "mage", "shaman", ...)
--   attack, health                      minions
--   race                                "murloc" | "beast" | "totem" | ...
--   taunt, charge, divineShield, windfury
--   spellDamage = n                     Spell Damage +n while on the board
--   aura = { attack, health, scope }    scope "others" (other friendly minions) or "adjacent"
--   freezeOnHit = true                  freezes any character this minion damages
--   battlecry = { target = spec, effects = { ... } }
--   spell = { target = spec, effects = { ... } }
--   endTurn = { effects }               at the end of its owner's turn
--   damaged = { effects }               whenever it takes damage (and survives)
--   deathrattle = { effects }
--   token = true                        not for decks (summoned or made by other cards)
--   art                                 an icon path (or one of our own textures)
--   npc                                 a WoW creature id: minions show that creature's 3D model
--                                       (the icon is the fallback while it loads)
--   school                              how its spell or battlecry looks: fire, frost, arcane,
--                                       nature, lightning, holy, physical
--
-- Target specs: "any", "minion", "enemyChar", "enemyMinion", "friendlyMinion", "friendlyChar".
-- Effects (see Engine.lua, Run): damage, missiles, heal, draw, summon,
-- summonRandom, freeze, transform, buff, mana, armor, destroy.
-- "to" picks who: target, self, myHero, enemyHero, myMinions, otherMyMinions,
-- enemyMinions, enemies, myChars, allMinions, allChars.
local ADDON, ns = ...

ns.HS = ns.HS or {}
local I = "Interface\\Icons\\"

local C = {}
ns.HS.Cards = C

local function Add(card)
    assert(not C[card.key], card.key)
    card.class = card.class or "neutral"
    C[card.key] = card
end

---------------------------------------------------------------------------
-- Tokens and The Coin
---------------------------------------------------------------------------
Add({ key = "coin", school = "holy", name = "The Coin", cost = 0, type = "spell", token = true, art = I .. "INV_Misc_Coin_01",
    text = "Gain 1 Mana Crystal this turn only.", spell = { effects = { { op = "mana", n = 1 } } } })
Add({ key = "sheep", npc = 1933, name = "Sheep", cost = 1, type = "minion", attack = 1, health = 1, race = "beast", token = true,
    art = I .. "Spell_Nature_Polymorph" })
Add({ key = "frog", npc = 13321, name = "Frog", cost = 0, type = "minion", attack = 0, health = 1, race = "beast", taunt = true,
    token = true, art = I .. "Spell_Shadow_Charm", text = "Taunt" })
Add({ key = "mirror_image_token", name = "Mirror Image", cost = 0, type = "minion", attack = 0, health = 2, taunt = true,
    token = true, class = "mage", art = I .. "Spell_Magic_LesserInvisibilty", text = "Taunt" })
Add({ key = "boar", npc = 2809, name = "Boar", cost = 1, type = "minion", attack = 1, health = 1, race = "beast", token = true,
    art = I .. "Ability_Hunter_Pet_Boar" })
Add({ key = "murloc_scout", npc = 578, name = "Murloc Scout", cost = 0, type = "minion", attack = 1, health = 1, race = "murloc",
    token = true, art = I .. "INV_Misc_Head_Murloc_01" })
Add({ key = "mechanical_dragonling", npc = 2678, name = "Mechanical Dragonling", cost = 1, type = "minion", attack = 2, health = 1,
    race = "mech", token = true, art = I .. "INV_Misc_Head_Dragon_Bronze" })

-- Shaman totems (Totemic Call).
Add({ key = "spirit_wolf", npc = 3524, name = "Spirit Wolf", cost = 2, type = "minion", attack = 2, health = 3, taunt = true,
    class = "shaman", token = true, art = I .. "Spell_Nature_SpiritWolf", text = "Taunt" })
Add({ key = "healing_totem", npc = 3527, name = "Healing Totem", cost = 1, type = "minion", attack = 0, health = 2, race = "totem",
    class = "shaman", token = true, art = I .. "INV_Spear_04",
    text = "At the end of your turn, restore 1 Health to all friendly minions.",
    endTurn = { effects = { { op = "heal", to = "myMinions", amount = 1 } } } })
Add({ key = "searing_totem", npc = 2523, name = "Searing Totem", cost = 1, type = "minion", attack = 1, health = 1, race = "totem",
    class = "shaman", token = true, art = I .. "Spell_Fire_SearingTotem" })
Add({ key = "stoneclaw_totem", npc = 3579, name = "Stoneclaw Totem", cost = 1, type = "minion", attack = 0, health = 2,
    race = "totem", class = "shaman", token = true, taunt = true, art = I .. "Spell_Nature_StoneClawTotem",
    text = "Taunt" })
Add({ key = "wrath_of_air_totem", npc = 6112, name = "Wrath of Air Totem", cost = 1, type = "minion", attack = 0, health = 2,
    race = "totem", class = "shaman", token = true, spellDamage = 1, art = I .. "Spell_Nature_SlowingTotem",
    text = "Spell Damage +1" })

---------------------------------------------------------------------------
-- Mage
---------------------------------------------------------------------------
Add({ key = "arcane_missiles", school = "arcane", name = "Arcane Missiles", cost = 1, type = "spell", class = "mage",
    art = I .. "Spell_Nature_StarFall", text = "Deal 3 damage randomly split among all enemies.",
    spell = { effects = { { op = "missiles", n = 3 } } } })
Add({ key = "mirror_image", school = "arcane", name = "Mirror Image", cost = 1, type = "spell", class = "mage",
    art = I .. "Spell_Magic_LesserInvisibilty", text = "Summon two 0/2 minions with Taunt.",
    spell = { effects = { { op = "summon", card = "mirror_image_token", n = 2 } } } })
Add({ key = "arcane_explosion", school = "arcane", name = "Arcane Explosion", cost = 2, type = "spell", class = "mage",
    art = I .. "Spell_Nature_WispSplode", text = "Deal 1 damage to all enemy minions.",
    spell = { effects = { { op = "damage", to = "enemyMinions", amount = 1, spell = true } } } })
Add({ key = "frostbolt", school = "frost", name = "Frostbolt", cost = 2, type = "spell", class = "mage",
    art = I .. "Spell_Frost_FrostBolt02", text = "Deal 3 damage to a character and Freeze it.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 3, spell = true },
        { op = "freeze", to = "target" } } } })
Add({ key = "arcane_intellect", school = "arcane", name = "Arcane Intellect", cost = 3, type = "spell", class = "mage",
    art = I .. "Spell_Holy_MagicalSentry", text = "Draw 2 cards.",
    spell = { effects = { { op = "draw", n = 2 } } } })
Add({ key = "frost_nova", school = "frost", name = "Frost Nova", cost = 3, type = "spell", class = "mage",
    art = I .. "Spell_Frost_FrostNova", text = "Freeze all enemy minions.",
    spell = { effects = { { op = "freeze", to = "enemyMinions" } } } })
Add({ key = "fireball", school = "fire", name = "Fireball", cost = 4, type = "spell", class = "mage",
    art = I .. "Spell_Fire_FlameBolt", text = "Deal 6 damage.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 6, spell = true } } } })
Add({ key = "polymorph", school = "arcane", name = "Polymorph", cost = 4, type = "spell", class = "mage",
    art = I .. "Spell_Nature_Polymorph", text = "Transform a minion into a 1/1 Sheep.",
    spell = { target = "minion", effects = { { op = "transform", to = "target", into = "sheep" } } } })
Add({ key = "water_elemental", npc = 510, name = "Water Elemental", cost = 4, type = "minion", class = "mage", attack = 3,
    health = 6, race = "elemental", freezeOnHit = true, art = I .. "Spell_Frost_FrostArmor02",
    text = "Freeze any character damaged by this minion." })
Add({ key = "flamestrike", school = "fire", name = "Flamestrike", cost = 7, type = "spell", class = "mage",
    art = I .. "Spell_Fire_SelfDestruct", text = "Deal 4 damage to all enemy minions.",
    spell = { effects = { { op = "damage", to = "enemyMinions", amount = 4, spell = true } } } })

---------------------------------------------------------------------------
-- Shaman
---------------------------------------------------------------------------
Add({ key = "ancestral_healing", school = "nature", name = "Ancestral Healing", cost = 0, type = "spell", class = "shaman",
    art = I .. "Spell_Nature_HealingWaveGreater", text = "Restore a minion to full Health and give it Taunt.",
    spell = { target = "minion", effects = { { op = "heal", to = "target", amount = 99 },
        { op = "buff", to = "target", taunt = true } } } })
Add({ key = "frost_shock", school = "frost", name = "Frost Shock", cost = 1, type = "spell", class = "shaman",
    art = I .. "Spell_Frost_FrostShock", text = "Deal 1 damage to an enemy character and Freeze it.",
    spell = { target = "enemyChar", effects = { { op = "damage", to = "target", amount = 1, spell = true },
        { op = "freeze", to = "target" } } } })
Add({ key = "rockbiter_weapon", school = "nature", name = "Rockbiter Weapon", cost = 1, type = "spell", class = "shaman",
    art = I .. "Spell_Nature_RockBiter", text = "Give a friendly character +3 Attack this turn.",
    spell = { target = "friendlyChar", effects = { { op = "buff", to = "target", attack = 3, temp = true } } } })
Add({ key = "windfury", school = "nature", name = "Windfury", cost = 2, type = "spell", class = "shaman",
    art = I .. "Spell_Nature_Windfury", text = "Give a minion Windfury.",
    spell = { target = "minion", effects = { { op = "buff", to = "target", windfury = true } } } })
Add({ key = "flametongue_totem", npc = 5950, name = "Flametongue Totem", cost = 2, type = "minion", class = "shaman",
    attack = 0, health = 3, race = "totem", aura = { attack = 2, scope = "adjacent" },
    art = I .. "Spell_Nature_GuardianWard", text = "Adjacent minions have +2 Attack." })
Add({ key = "hex", school = "nature", name = "Hex", cost = 3, type = "spell", class = "shaman",
    art = I .. "Spell_Shadow_Charm", text = "Transform a minion into a 0/1 Frog with Taunt.",
    spell = { target = "minion", effects = { { op = "transform", to = "target", into = "frog" } } } })
Add({ key = "windspeaker", npc = 4096, school = "nature", name = "Windspeaker", cost = 4, type = "minion", class = "shaman", attack = 3, health = 3,
    art = I .. "Spell_Nature_Cyclone", text = "Battlecry: Give a friendly minion Windfury.",
    battlecry = { target = "friendlyMinion", effects = { { op = "buff", to = "target", windfury = true } } } })
Add({ key = "bloodlust", school = "fire", name = "Bloodlust", cost = 5, type = "spell", class = "shaman",
    art = I .. "Spell_Nature_BloodLust", text = "Give your minions +3 Attack this turn.",
    spell = { effects = { { op = "buff", to = "myMinions", attack = 3, temp = true } } } })
Add({ key = "lightning_bolt", school = "lightning", name = "Lightning Bolt", cost = 1, type = "spell", class = "shaman", overload = 1,
    art = I .. "Spell_Nature_Lightning", text = "Deal 3 damage. Overload: (1)",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 3, spell = true } } } })
Add({ key = "feral_spirit", school = "nature", name = "Feral Spirit", cost = 3, type = "spell", class = "shaman", overload = 2,
    art = I .. "Spell_Nature_SpiritWolf", text = "Summon two 2/3 Spirit Wolves with Taunt. Overload: (2)",
    spell = { effects = { { op = "summon", card = "spirit_wolf", n = 2 } } } })
Add({ key = "lava_burst", school = "fire", name = "Lava Burst", cost = 3, type = "spell", class = "shaman", overload = 2,
    art = I .. "Spell_Fire_Volcano", text = "Deal 5 damage. Overload: (2)",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 5, spell = true } } } })
Add({ key = "earth_elemental", npc = 329, name = "Earth Elemental", cost = 5, type = "minion", class = "shaman", attack = 7,
    health = 8, race = "elemental", taunt = true, overload = 3, art = I .. "Spell_Nature_EarthElemental_Totem",
    text = "Taunt. Overload: (3)" })
Add({ key = "fire_elemental", npc = 575, school = "fire", name = "Fire Elemental", cost = 6, type = "minion", class = "shaman", attack = 6,
    health = 5, race = "elemental", art = I .. "Spell_Fire_Fire", text = "Battlecry: Deal 3 damage.",
    battlecry = { target = "any", effects = { { op = "damage", to = "target", amount = 3 } } } })

---------------------------------------------------------------------------
-- Neutral
---------------------------------------------------------------------------
Add({ key = "elven_archer", npc = 4262, school = "physical", name = "Elven Archer", cost = 1, type = "minion", attack = 1, health = 1,
    art = I .. "INV_Weapon_Bow_02", text = "Battlecry: Deal 1 damage.",
    battlecry = { target = "any", effects = { { op = "damage", to = "target", amount = 1 } } } })
Add({ key = "goldshire_footman", npc = 1423, name = "Goldshire Footman", cost = 1, type = "minion", attack = 1, health = 2,
    taunt = true, art = I .. "INV_Shield_06", text = "Taunt" })
Add({ key = "murloc_raider", npc = 515, name = "Murloc Raider", cost = 1, type = "minion", attack = 2, health = 1,
    race = "murloc", art = I .. "INV_Misc_Head_Murloc_01" })
Add({ key = "stonetusk_boar", npc = 113, name = "Stonetusk Boar", cost = 1, type = "minion", attack = 1, health = 1,
    race = "beast", charge = true, art = I .. "Ability_Hunter_Pet_Boar", text = "Charge" })
Add({ key = "voodoo_doctor", npc = 8115, school = "holy", name = "Voodoo Doctor", cost = 1, type = "minion", attack = 2, health = 1,
    art = I .. "Spell_Holy_Heal02", text = "Battlecry: Restore 2 Health.",
    battlecry = { target = "any", effects = { { op = "heal", to = "target", amount = 2 } } } })
Add({ key = "argent_squire", npc = 11099, name = "Argent Squire", cost = 1, type = "minion", attack = 1, health = 1,
    divineShield = true, art = I .. "INV_Shield_04", text = "Divine Shield" })
Add({ key = "bloodfen_raptor", npc = 4351, name = "Bloodfen Raptor", cost = 2, type = "minion", attack = 3, health = 2,
    race = "beast", art = I .. "Ability_Hunter_Pet_Raptor" })
Add({ key = "bluegill_warrior", npc = 1027, name = "Bluegill Warrior", cost = 2, type = "minion", attack = 2, health = 1,
    race = "murloc", charge = true, art = I .. "INV_Misc_Head_Murloc_01", text = "Charge" })
Add({ key = "frostwolf_grunt", npc = 12053, name = "Frostwolf Grunt", cost = 2, type = "minion", attack = 2, health = 2,
    taunt = true, art = I .. "Ability_Mount_WhiteDireWolf", text = "Taunt" })
Add({ key = "kobold_geomancer", npc = 476, name = "Kobold Geomancer", cost = 2, type = "minion", attack = 2, health = 2,
    spellDamage = 1, art = I .. "INV_Misc_Gem_Pearl_04", text = "Spell Damage +1" })
Add({ key = "murloc_tidehunter", npc = 127, name = "Murloc Tidehunter", cost = 2, type = "minion", attack = 2, health = 1,
    race = "murloc", art = I .. "INV_Misc_Head_Murloc_01", text = "Battlecry: Summon a 1/1 Murloc Scout.",
    battlecry = { effects = { { op = "summon", card = "murloc_scout" } } } })
Add({ key = "novice_engineer", npc = 7843, name = "Novice Engineer", cost = 2, type = "minion", attack = 1, health = 1,
    art = I .. "Trade_Engineering", text = "Battlecry: Draw a card.",
    battlecry = { effects = { { op = "draw", n = 1 } } } })
Add({ key = "river_crocolisk", npc = 1150, name = "River Crocolisk", cost = 2, type = "minion", attack = 2, health = 3,
    race = "beast", art = I .. "Ability_Hunter_Pet_Crocolisk" })
Add({ key = "dalaran_mage", npc = 1914, name = "Dalaran Mage", cost = 3, type = "minion", attack = 1, health = 4,
    spellDamage = 1, art = I .. "INV_Staff_13", text = "Spell Damage +1" })
Add({ key = "ironforge_rifleman", npc = 727, school = "physical", name = "Ironforge Rifleman", cost = 3, type = "minion", attack = 2, health = 2,
    art = I .. "INV_Weapon_Rifle_01", text = "Battlecry: Deal 1 damage.",
    battlecry = { target = "any", effects = { { op = "damage", to = "target", amount = 1 } } } })
Add({ key = "ironfur_grizzly", npc = 5268, name = "Ironfur Grizzly", cost = 3, type = "minion", attack = 3, health = 3,
    race = "beast", taunt = true, art = I .. "Ability_Hunter_Pet_Bear", text = "Taunt" })
Add({ key = "magma_rager", npc = 5855, name = "Magma Rager", cost = 3, type = "minion", attack = 5, health = 1,
    race = "elemental", art = I .. "Spell_Fire_LavaSpawn" })
Add({ key = "raid_leader", npc = 240, name = "Raid Leader", cost = 3, type = "minion", attack = 2, health = 2,
    aura = { attack = 1, scope = "others" }, art = I .. "INV_Banner_02", text = "Your other minions have +1 Attack." })
Add({ key = "razorfen_hunter", npc = 4531, name = "Razorfen Hunter", cost = 3, type = "minion", attack = 2, health = 3,
    art = I .. "INV_Weapon_Bow_05", text = "Battlecry: Summon a 1/1 Boar.",
    battlecry = { effects = { { op = "summon", card = "boar" } } } })
Add({ key = "shattered_sun_cleric", npc = 9449, school = "holy", name = "Shattered Sun Cleric", cost = 3, type = "minion", attack = 3, health = 2,
    art = I .. "Spell_Holy_Renew", text = "Battlecry: Give a friendly minion +1/+1.",
    battlecry = { target = "friendlyMinion", effects = { { op = "buff", to = "target", attack = 1, health = 1 } } } })
Add({ key = "scarlet_crusader", npc = 1833, name = "Scarlet Crusader", cost = 3, type = "minion", attack = 3, health = 1,
    divineShield = true, art = I .. "INV_Sword_27", text = "Divine Shield" })
Add({ key = "silverback_patriarch", npc = 1558, name = "Silverback Patriarch", cost = 3, type = "minion", attack = 1, health = 4,
    race = "beast", taunt = true, art = I .. "Ability_Hunter_Pet_Gorilla", text = "Taunt" })
Add({ key = "wolfrider", npc = 13440, name = "Wolfrider", cost = 3, type = "minion", attack = 3, health = 1, charge = true,
    art = I .. "Ability_Mount_BlackDireWolf", text = "Charge" })
Add({ key = "chillwind_yeti", npc = 7458, name = "Chillwind Yeti", cost = 4, type = "minion", attack = 4, health = 5,
    art = I .. "Spell_Frost_ChainsOfIce" })
Add({ key = "dragonling_mechanic", npc = 13601, name = "Dragonling Mechanic", cost = 4, type = "minion", attack = 2, health = 4,
    art = I .. "INV_Gizmo_01", text = "Battlecry: Summon a 2/1 Mechanical Dragonling.",
    battlecry = { effects = { { op = "summon", card = "mechanical_dragonling" } } } })
Add({ key = "gnomish_inventor", npc = 13000, name = "Gnomish Inventor", cost = 4, type = "minion", attack = 2, health = 4,
    art = I .. "INV_Gizmo_02", text = "Battlecry: Draw a card.",
    battlecry = { effects = { { op = "draw", n = 1 } } } })
Add({ key = "oasis_snapjaw", npc = 3461, name = "Oasis Snapjaw", cost = 4, type = "minion", attack = 2, health = 7,
    race = "beast", art = I .. "Ability_Hunter_Pet_Turtle" })
Add({ key = "senjin_shieldmasta", npc = 3297, name = "Sen'jin Shieldmasta", cost = 4, type = "minion", attack = 3, health = 5,
    taunt = true, art = I .. "INV_Shield_05", text = "Taunt" })
Add({ key = "booty_bay_bodyguard", npc = 4624, name = "Booty Bay Bodyguard", cost = 5, type = "minion", attack = 5, health = 4,
    taunt = true, art = I .. "INV_Sword_04", text = "Taunt" })
Add({ key = "darkscale_healer", npc = 4718, school = "holy", name = "Darkscale Healer", cost = 5, type = "minion", attack = 4, health = 5,
    art = I .. "Spell_Holy_Heal", text = "Battlecry: Restore 2 Health to all friendly characters.",
    battlecry = { effects = { { op = "heal", to = "myChars", amount = 2 } } } })
Add({ key = "gurubashi_berserker", npc = 11352, name = "Gurubashi Berserker", cost = 5, type = "minion", attack = 2, health = 7,
    art = I .. "Ability_Racial_BerserkerRage", text = "Whenever this minion takes damage, gain +3 Attack.",
    damaged = { effects = { { op = "buff", to = "self", attack = 3 } } } })
Add({ key = "stormpike_commando", npc = 13524, school = "physical", name = "Stormpike Commando", cost = 5, type = "minion", attack = 4, health = 2,
    art = I .. "INV_Weapon_Rifle_05", text = "Battlecry: Deal 2 damage.",
    battlecry = { target = "any", effects = { { op = "damage", to = "target", amount = 2 } } } })
Add({ key = "archmage", npc = 2543, name = "Archmage", cost = 6, type = "minion", attack = 4, health = 7, spellDamage = 1,
    art = I .. "Spell_Holy_MagicalSentry", text = "Spell Damage +1" })
Add({ key = "boulderfist_ogre", npc = 2562, name = "Boulderfist Ogre", cost = 6, type = "minion", attack = 6, health = 7,
    art = I .. "Spell_Nature_Strength" })
Add({ key = "lord_of_the_arena", npc = 11356, name = "Lord of the Arena", cost = 6, type = "minion", attack = 6, health = 5,
    taunt = true, art = I .. "INV_Helmet_03", text = "Taunt" })
Add({ key = "reckless_rocketeer", npc = 622, name = "Reckless Rocketeer", cost = 6, type = "minion", attack = 5, health = 2,
    charge = true, art = I .. "INV_Misc_Bomb_05", text = "Charge" })
Add({ key = "core_hound", npc = 11671, name = "Core Hound", cost = 7, type = "minion", attack = 9, health = 5, race = "beast",
    art = I .. "Ability_Hunter_Pet_CoreHound" })
Add({ key = "stormwind_champion", npc = 1756, name = "Stormwind Champion", cost = 7, type = "minion", attack = 6, health = 6,
    aura = { attack = 1, health = 1, scope = "others" }, art = I .. "INV_Sword_39",
    text = "Your other minions have +1/+1." })
Add({ key = "war_golem", npc = 2751, name = "War Golem", cost = 7, type = "minion", attack = 7, health = 7,
    art = I .. "INV_Misc_Gear_08" })

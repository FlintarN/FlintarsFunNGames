-- Hearthstone cards: data only. Values are the original Hearthstone ones
-- (Basic set, plus a few Classic cards for keywords).
--
-- A card:
--   key, name, cost, type ("minion" | "spell" | "weapon"), class ("neutral", "mage", "shaman", ...)
--   attack, health                      minions
--   attack, durability                  weapons (onAttack = { effects } when the hero swings)
--   race                                "murloc" | "beast" | "totem" | ...
--   taunt, charge, divineShield, windfury
--   spellDamage = n                     Spell Damage +n while on the board
--   aura = { attack, health, scope }    scope "others" (other friendly minions) or "adjacent"
--   freezeOnHit = true                  freezes any character this minion damages
--   battlecry = { target = spec, effects = { ... } }
--   spell = { target = spec, effects = { ... } }
--   endTurn = { effects }               at the end of its owner's turn
--   damaged = { effects }               whenever it takes damage (and survives)
--   onSummon = { filter, effects }      whenever you summon a minion (filter: maxAttack, race)
--   minionHealed = { effects }          whenever any minion is healed
--   aura = { ..., race, charge }        auras can be for one race ("beast") and give Charge;
--                                       scope "all" includes the minion itself
--   spell.filter / battlecry.filter     limits targets: maxAttack, minAttack, damaged, undamaged, race
--   spell.requires                      { weapon = true }, { boardRoom = true }, { enemyMinions = n }
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
-- summonRandom, freeze, transform, buff, mana, armor, destroy, damageRandom,
-- equip, weaponBuff, returnToHand, control, setHealth, setAttack,
-- doubleHealth, discard, copyEnemyHand, manaCrystal, doom.
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

---------------------------------------------------------------------------
-- Druid
---------------------------------------------------------------------------
Add({ key = "innervate", school = "nature", name = "Innervate", cost = 0, type = "spell", class = "druid",
    art = I .. "Spell_Nature_Lightning", text = "Gain 2 Mana Crystals this turn only.",
    spell = { effects = { { op = "mana", n = 2 } } } })
Add({ key = "moonfire", school = "arcane", name = "Moonfire", cost = 0, type = "spell", class = "druid",
    art = I .. "Spell_Nature_StarFall", text = "Deal 1 damage.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 1, spell = true } } } })
Add({ key = "claw", school = "nature", name = "Claw", cost = 1, type = "spell", class = "druid",
    art = I .. "Ability_Druid_Rake", text = "Give your hero +2 Attack this turn and 2 Armor.",
    spell = { effects = { { op = "buff", to = "myHero", attack = 2, temp = true }, { op = "armor", n = 2 } } } })
Add({ key = "mark_of_the_wild", school = "nature", name = "Mark of the Wild", cost = 2, type = "spell", class = "druid",
    art = I .. "Spell_Nature_Regeneration", text = "Give a minion Taunt and +2/+2.",
    spell = { target = "minion", effects = { { op = "buff", to = "target", attack = 2, health = 2, taunt = true } } } })
Add({ key = "wild_growth", school = "nature", name = "Wild Growth", cost = 2, type = "spell", class = "druid",
    art = I .. "Spell_Nature_ProtectionformNature", text = "Gain an empty Mana Crystal.",
    spell = { effects = { { op = "manaCrystal" } } } })
Add({ key = "healing_touch", school = "nature", name = "Healing Touch", cost = 3, type = "spell", class = "druid",
    art = I .. "Spell_Nature_HealingTouch", text = "Restore 8 Health.",
    spell = { target = "any", effects = { { op = "heal", to = "target", amount = 8 } } } })
Add({ key = "savage_roar", school = "nature", name = "Savage Roar", cost = 3, type = "spell", class = "druid",
    art = I .. "Ability_Druid_DemoralizingRoar", text = "Give your characters +2 Attack this turn.",
    spell = { effects = { { op = "buff", to = "myChars", attack = 2, temp = true } } } })
Add({ key = "swipe", school = "nature", name = "Swipe", cost = 4, type = "spell", class = "druid",
    art = I .. "INV_Misc_MonsterClaw_03", text = "Deal 4 damage to an enemy and 1 damage to all other enemies.",
    spell = { target = "enemyChar", effects = { { op = "damage", to = "target", amount = 4, spell = true },
        { op = "damage", to = "otherEnemies", amount = 1, spell = true } } } })
Add({ key = "starfire", school = "arcane", name = "Starfire", cost = 6, type = "spell", class = "druid",
    art = I .. "Spell_Arcane_StarFire", text = "Deal 5 damage. Draw a card.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 5, spell = true }, { op = "draw", n = 1 } } } })
Add({ key = "ironbark_protector", npc = 11459, name = "Ironbark Protector", cost = 8, type = "minion", class = "druid",
    attack = 8, health = 8, taunt = true, art = I .. "Spell_Nature_ResistNature", text = "Taunt" })

---------------------------------------------------------------------------
-- Hunter
---------------------------------------------------------------------------
Add({ key = "huffer", npc = 682, name = "Huffer", cost = 3, type = "minion", class = "hunter", attack = 4, health = 2,
    race = "beast", charge = true, token = true, art = I .. "Ability_Hunter_Pet_Cat", text = "Charge" })
Add({ key = "leokk", npc = 684, name = "Leokk", cost = 3, type = "minion", class = "hunter", attack = 2, health = 4,
    race = "beast", token = true, aura = { attack = 1, scope = "others" }, art = I .. "Ability_Hunter_Pet_Cat",
    text = "Your other minions have +1 Attack." })
Add({ key = "misha", npc = 10204, name = "Misha", cost = 3, type = "minion", class = "hunter", attack = 4, health = 4,
    race = "beast", taunt = true, token = true, art = I .. "Ability_Hunter_Pet_Bear", text = "Taunt" })
Add({ key = "hunters_mark", school = "physical", name = "Hunter's Mark", cost = 0, type = "spell", class = "hunter",
    art = I .. "Ability_Hunter_SniperShot", text = "Change a minion's Health to 1.",
    spell = { target = "minion", effects = { { op = "setHealth", to = "target", n = 1 } } } })
Add({ key = "arcane_shot", school = "arcane", name = "Arcane Shot", cost = 1, type = "spell", class = "hunter",
    art = I .. "Ability_ImpalingBolt", text = "Deal 2 damage.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 2, spell = true } } } })
Add({ key = "timber_wolf", npc = 69, name = "Timber Wolf", cost = 1, type = "minion", class = "hunter", attack = 1,
    health = 1, race = "beast", aura = { attack = 1, scope = "others", race = "beast" },
    art = I .. "Ability_Hunter_Pet_Wolf", text = "Your other Beasts have +1 Attack." })
Add({ key = "starving_buzzard", npc = 2829, name = "Starving Buzzard", cost = 2, type = "minion", class = "hunter",
    attack = 2, health = 1, race = "beast", art = I .. "Ability_Hunter_Pet_Vulture",
    text = "Whenever you summon a Beast, draw a card.",
    onSummon = { filter = { race = "beast" }, effects = { { op = "draw", n = 1 } } } })
Add({ key = "animal_companion", school = "nature", name = "Animal Companion", cost = 3, type = "spell", class = "hunter",
    art = I .. "Ability_Hunter_BeastCall", text = "Summon a random Beast Companion.",
    spell = { effects = { { op = "summonRandom", pool = { "huffer", "leokk", "misha" } } } } })
Add({ key = "kill_command", school = "physical", name = "Kill Command", cost = 3, type = "spell", class = "hunter",
    art = I .. "Ability_Hunter_BeastTaming", text = "Deal 3 damage. If you have a Beast, deal 5 damage instead.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 3, spell = true,
        ifRace = { race = "beast", amount = 5 } } } } })
Add({ key = "multi_shot", school = "physical", name = "Multi-Shot", cost = 4, type = "spell", class = "hunter",
    art = I .. "Ability_UpgradeMoonGlaive", text = "Deal 3 damage to two random enemy minions.",
    spell = { requires = { enemyMinions = 2 }, effects = { { op = "damageRandom", n = 2, amount = 3, spell = true } } } })
Add({ key = "houndmaster", npc = 3974, school = "nature", name = "Houndmaster", cost = 4, type = "minion",
    class = "hunter", attack = 4, health = 3, art = I .. "Ability_Hunter_Pet_Hyena",
    text = "Battlecry: Give a friendly Beast +2/+2 and Taunt.",
    battlecry = { target = "friendlyMinion", filter = { race = "beast" },
        effects = { { op = "buff", to = "target", attack = 2, health = 2, taunt = true } } } })
Add({ key = "tundra_rhino", npc = 2973, name = "Tundra Rhino", cost = 5, type = "minion", class = "hunter", attack = 2,
    health = 5, race = "beast", aura = { charge = true, scope = "all", race = "beast" },
    art = I .. "Ability_Mount_Kodo_01", text = "Your Beasts have Charge." })

---------------------------------------------------------------------------
-- Paladin
---------------------------------------------------------------------------
Add({ key = "silver_hand_recruit", npc = 68, name = "Silver Hand Recruit", cost = 1, type = "minion",
    class = "paladin", attack = 1, health = 1, token = true, art = I .. "INV_Shield_06" })
Add({ key = "blessing_of_might", school = "holy", name = "Blessing of Might", cost = 1, type = "spell",
    class = "paladin", art = I .. "Spell_Holy_FistOfJustice", text = "Give a minion +3 Attack.",
    spell = { target = "minion", effects = { { op = "buff", to = "target", attack = 3 } } } })
Add({ key = "hand_of_protection", school = "holy", name = "Hand of Protection", cost = 1, type = "spell",
    class = "paladin", art = I .. "Spell_Holy_SealOfProtection", text = "Give a minion Divine Shield.",
    spell = { target = "minion", effects = { { op = "buff", to = "target", divineShield = true } } } })
Add({ key = "humility", school = "holy", name = "Humility", cost = 1, type = "spell", class = "paladin",
    art = I .. "Spell_Holy_SealOfWisdom", text = "Change a minion's Attack to 1.",
    spell = { target = "minion", effects = { { op = "setAttack", to = "target", n = 1 } } } })
Add({ key = "lights_justice", name = "Light's Justice", cost = 1, type = "weapon", class = "paladin", attack = 1,
    durability = 4, art = I .. "INV_Mace_01" })
Add({ key = "holy_light", school = "holy", name = "Holy Light", cost = 2, type = "spell", class = "paladin",
    art = I .. "Spell_Holy_HolyBolt", text = "Restore 6 Health.",
    spell = { target = "any", effects = { { op = "heal", to = "target", amount = 6 } } } })
Add({ key = "blessing_of_kings", school = "holy", name = "Blessing of Kings", cost = 4, type = "spell",
    class = "paladin", art = I .. "Spell_Magic_MageArmor", text = "Give a minion +4/+4.",
    spell = { target = "minion", effects = { { op = "buff", to = "target", attack = 4, health = 4 } } } })
Add({ key = "consecration", school = "holy", name = "Consecration", cost = 4, type = "spell", class = "paladin",
    art = I .. "Spell_Holy_InnerFire", text = "Deal 2 damage to all enemies.",
    spell = { effects = { { op = "damage", to = "enemies", amount = 2, spell = true } } } })
Add({ key = "hammer_of_wrath", school = "holy", name = "Hammer of Wrath", cost = 4, type = "spell", class = "paladin",
    art = I .. "Spell_Holy_SealOfMight", text = "Deal 3 damage. Draw a card.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 3, spell = true }, { op = "draw", n = 1 } } } })
Add({ key = "truesilver_champion", name = "Truesilver Champion", cost = 4, type = "weapon", class = "paladin",
    attack = 4, durability = 2, art = I .. "INV_Sword_23",
    text = "Whenever your hero attacks, restore 2 Health to it.",
    onAttack = { effects = { { op = "heal", to = "myHero", amount = 2 } } } })
Add({ key = "guardian_of_kings", npc = 1842, school = "holy", name = "Guardian of Kings", cost = 7, type = "minion",
    class = "paladin", attack = 5, health = 6, art = I .. "Spell_Holy_SealOfFury",
    text = "Battlecry: Restore 6 Health to your hero.",
    battlecry = { effects = { { op = "heal", to = "myHero", amount = 6 } } } })

---------------------------------------------------------------------------
-- Priest
---------------------------------------------------------------------------
Add({ key = "holy_smite", school = "holy", name = "Holy Smite", cost = 1, type = "spell", class = "priest",
    art = I .. "Spell_Holy_HolySmite", text = "Deal 2 damage.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 2, spell = true } } } })
Add({ key = "mind_vision", school = "arcane", name = "Mind Vision", cost = 1, type = "spell", class = "priest",
    art = I .. "Spell_Holy_MindVision", text = "Put a copy of a random card in your opponent's hand into your hand.",
    spell = { effects = { { op = "copyEnemyHand" } } } })
Add({ key = "power_word_shield", school = "holy", name = "Power Word: Shield", cost = 1, type = "spell",
    class = "priest", art = I .. "Spell_Holy_PowerWordShield", text = "Give a minion +2 Health. Draw a card.",
    spell = { target = "minion", effects = { { op = "buff", to = "target", health = 2 }, { op = "draw", n = 1 } } } })
Add({ key = "northshire_cleric", npc = 951, name = "Northshire Cleric", cost = 1, type = "minion", class = "priest",
    attack = 1, health = 3, art = I .. "Spell_Holy_FlashHeal", text = "Whenever a minion is healed, draw a card.",
    minionHealed = { effects = { { op = "draw", n = 1 } } } })
Add({ key = "divine_spirit", school = "holy", name = "Divine Spirit", cost = 2, type = "spell", class = "priest",
    art = I .. "Spell_Holy_DivineSpirit", text = "Double a minion's Health.",
    spell = { target = "minion", effects = { { op = "doubleHealth", to = "target" } } } })
Add({ key = "mind_blast", school = "arcane", name = "Mind Blast", cost = 2, type = "spell", class = "priest",
    art = I .. "Spell_Shadow_UnholyFrenzy", text = "Deal 5 damage to the enemy hero.",
    spell = { effects = { { op = "damage", to = "enemyHero", amount = 5, spell = true } } } })
Add({ key = "shadow_word_pain", school = "arcane", name = "Shadow Word: Pain", cost = 2, type = "spell",
    class = "priest", art = I .. "Spell_Shadow_ShadowWordPain", text = "Destroy a minion with 3 or less Attack.",
    spell = { target = "minion", filter = { maxAttack = 3 }, effects = { { op = "destroy", to = "target" } } } })
Add({ key = "shadow_word_death", school = "arcane", name = "Shadow Word: Death", cost = 3, type = "spell",
    class = "priest", art = I .. "Spell_Shadow_DeathCoil", text = "Destroy a minion with an Attack of 5 or more.",
    spell = { target = "minion", filter = { minAttack = 5 }, effects = { { op = "destroy", to = "target" } } } })
Add({ key = "holy_nova", school = "holy", name = "Holy Nova", cost = 5, type = "spell", class = "priest",
    art = I .. "Spell_Holy_HolyNova", text = "Deal 2 damage to all enemies. Restore 2 Health to all friendly characters.",
    spell = { effects = { { op = "damage", to = "enemies", amount = 2, spell = true },
        { op = "heal", to = "myChars", amount = 2 } } } })
Add({ key = "mind_control", school = "arcane", name = "Mind Control", cost = 10, type = "spell", class = "priest",
    art = I .. "Spell_Shadow_ShadowWordDominate", text = "Take control of an enemy minion.",
    spell = { target = "enemyMinion", requires = { boardRoom = true }, effects = { { op = "control", to = "target" } } } })

---------------------------------------------------------------------------
-- Rogue
---------------------------------------------------------------------------
Add({ key = "wicked_knife", name = "Wicked Knife", cost = 1, type = "weapon", class = "rogue", attack = 1,
    durability = 2, token = true, art = I .. "INV_Weapon_ShortBlade_01" })
Add({ key = "backstab", school = "physical", name = "Backstab", cost = 0, type = "spell", class = "rogue",
    art = I .. "Ability_BackStab", text = "Deal 2 damage to an undamaged minion.",
    spell = { target = "minion", filter = { undamaged = true },
        effects = { { op = "damage", to = "target", amount = 2, spell = true } } } })
Add({ key = "deadly_poison", school = "nature", name = "Deadly Poison", cost = 1, type = "spell", class = "rogue",
    art = I .. "Ability_Poisons", text = "Give your weapon +2 Attack.",
    spell = { requires = { weapon = true }, effects = { { op = "weaponBuff", attack = 2 } } } })
Add({ key = "sinister_strike", school = "physical", name = "Sinister Strike", cost = 1, type = "spell",
    class = "rogue", art = I .. "Spell_Shadow_RitualOfSacrifice", text = "Deal 3 damage to the enemy hero.",
    spell = { effects = { { op = "damage", to = "enemyHero", amount = 3, spell = true } } } })
Add({ key = "sap", school = "physical", name = "Sap", cost = 2, type = "spell", class = "rogue",
    art = I .. "Ability_Sap", text = "Return an enemy minion to your opponent's hand.",
    spell = { target = "enemyMinion", effects = { { op = "returnToHand", to = "target" } } } })
Add({ key = "shiv", school = "physical", name = "Shiv", cost = 2, type = "spell", class = "rogue",
    art = I .. "INV_ThrowingKnife_04", text = "Deal 1 damage. Draw a card.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 1, spell = true }, { op = "draw", n = 1 } } } })
Add({ key = "fan_of_knives", school = "physical", name = "Fan of Knives", cost = 3, type = "spell", class = "rogue",
    art = I .. "INV_ThrowingKnife_02", text = "Deal 1 damage to all enemy minions. Draw a card.",
    spell = { effects = { { op = "damage", to = "enemyMinions", amount = 1, spell = true }, { op = "draw", n = 1 } } } })
Add({ key = "assassins_blade", name = "Assassin's Blade", cost = 5, type = "weapon", class = "rogue", attack = 3,
    durability = 4, art = I .. "INV_Weapon_ShortBlade_14" })
Add({ key = "assassinate", school = "physical", name = "Assassinate", cost = 5, type = "spell", class = "rogue",
    art = I .. "Ability_Rogue_Eviscerate", text = "Destroy an enemy minion.",
    spell = { target = "enemyMinion", effects = { { op = "destroy", to = "target" } } } })
Add({ key = "vanish", school = "arcane", name = "Vanish", cost = 6, type = "spell", class = "rogue",
    art = I .. "Ability_Vanish", text = "Return all minions to their owner's hand.",
    spell = { effects = { { op = "returnToHand", to = "allMinions" } } } })
Add({ key = "sprint", school = "physical", name = "Sprint", cost = 7, type = "spell", class = "rogue",
    art = I .. "Ability_Rogue_Sprint", text = "Draw 4 cards.", spell = { effects = { { op = "draw", n = 4 } } } })

---------------------------------------------------------------------------
-- Warlock
---------------------------------------------------------------------------
Add({ key = "sacrificial_pact", school = "arcane", name = "Sacrificial Pact", cost = 0, type = "spell",
    class = "warlock", art = I .. "Spell_Shadow_SacrificialShield", text = "Destroy a Demon. Restore 5 Health to your hero.",
    spell = { target = "minion", filter = { race = "demon" },
        effects = { { op = "destroy", to = "target" }, { op = "heal", to = "myHero", amount = 5 } } } })
Add({ key = "soulfire", school = "fire", name = "Soulfire", cost = 0, type = "spell", class = "warlock",
    art = I .. "Spell_Fire_Fireball02", text = "Deal 4 damage. Discard a random card.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 4, spell = true }, { op = "discard", n = 1 } } } })
Add({ key = "corruption", school = "arcane", name = "Corruption", cost = 1, type = "spell", class = "warlock",
    art = I .. "Spell_Shadow_AbominationExplosion", text = "Choose an enemy minion. At the start of your turn, destroy it.",
    spell = { target = "enemyMinion", effects = { { op = "doom", to = "target" } } } })
Add({ key = "mortal_coil", school = "arcane", name = "Mortal Coil", cost = 1, type = "spell", class = "warlock",
    art = I .. "Spell_Shadow_DeathCoil", text = "Deal 1 damage to a minion. If that kills it, draw a card.",
    spell = { target = "minion", effects = { { op = "damage", to = "target", amount = 1, spell = true,
        onKill = { { op = "draw", n = 1 } } } } } })
Add({ key = "voidwalker", npc = 1860, name = "Voidwalker", cost = 1, type = "minion", class = "warlock", attack = 1,
    health = 3, race = "demon", taunt = true, art = I .. "Spell_Shadow_SummonVoidWalker", text = "Taunt" })
Add({ key = "succubus", npc = 1863, name = "Succubus", cost = 2, type = "minion", class = "warlock", attack = 4,
    health = 3, race = "demon", art = I .. "Spell_Shadow_SummonSuccubus", text = "Battlecry: Discard a random card.",
    battlecry = { effects = { { op = "discard", n = 1 } } } })
Add({ key = "drain_life", school = "arcane", name = "Drain Life", cost = 3, type = "spell", class = "warlock",
    art = I .. "Spell_Shadow_LifeDrain02", text = "Deal 2 damage. Restore 2 Health to your hero.",
    spell = { target = "any", effects = { { op = "damage", to = "target", amount = 2, spell = true },
        { op = "heal", to = "myHero", amount = 2 } } } })
Add({ key = "shadow_bolt", school = "arcane", name = "Shadow Bolt", cost = 3, type = "spell", class = "warlock",
    art = I .. "Spell_Shadow_ShadowBolt", text = "Deal 4 damage to a minion.",
    spell = { target = "minion", effects = { { op = "damage", to = "target", amount = 4, spell = true } } } })
Add({ key = "hellfire", school = "fire", name = "Hellfire", cost = 4, type = "spell", class = "warlock",
    art = I .. "Spell_Fire_Incinerate", text = "Deal 3 damage to ALL characters.",
    spell = { effects = { { op = "damage", to = "allChars", amount = 3, spell = true } } } })
Add({ key = "dread_infernal", npc = 89, school = "fire", name = "Dread Infernal", cost = 6, type = "minion",
    class = "warlock", attack = 6, health = 6, race = "demon", art = I .. "Spell_Shadow_SummonInfernal",
    text = "Battlecry: Deal 1 damage to ALL other characters.",
    battlecry = { effects = { { op = "damage", to = "allOthers", amount = 1 } } } })

---------------------------------------------------------------------------
-- Warrior
---------------------------------------------------------------------------
Add({ key = "execute", school = "physical", name = "Execute", cost = 1, type = "spell", class = "warrior",
    art = I .. "INV_Sword_48", text = "Destroy a damaged enemy minion.",
    spell = { target = "enemyMinion", filter = { damaged = true }, effects = { { op = "destroy", to = "target" } } } })
Add({ key = "whirlwind", school = "physical", name = "Whirlwind", cost = 1, type = "spell", class = "warrior",
    art = I .. "Ability_Whirlwind", text = "Deal 1 damage to ALL minions.",
    spell = { effects = { { op = "damage", to = "allMinions", amount = 1, spell = true } } } })
Add({ key = "cleave", school = "physical", name = "Cleave", cost = 2, type = "spell", class = "warrior",
    art = I .. "Ability_Warrior_Cleave", text = "Deal 2 damage to two random enemy minions.",
    spell = { requires = { enemyMinions = 2 }, effects = { { op = "damageRandom", n = 2, amount = 2, spell = true } } } })
Add({ key = "fiery_war_axe", name = "Fiery War Axe", cost = 2, type = "weapon", class = "warrior", attack = 3,
    durability = 2, art = I .. "INV_Axe_10" })
Add({ key = "heroic_strike", school = "physical", name = "Heroic Strike", cost = 2, type = "spell", class = "warrior",
    art = I .. "Ability_Rogue_Ambush", text = "Give your hero +4 Attack this turn.",
    spell = { effects = { { op = "buff", to = "myHero", attack = 4, temp = true } } } })
Add({ key = "charge", school = "physical", name = "Charge", cost = 3, type = "spell", class = "warrior",
    art = I .. "Ability_Warrior_Charge", text = "Give a friendly minion +2 Attack and Charge.",
    spell = { target = "friendlyMinion", effects = { { op = "buff", to = "target", attack = 2, charge = true } } } })
Add({ key = "shield_block", school = "physical", name = "Shield Block", cost = 3, type = "spell", class = "warrior",
    art = I .. "Ability_Defend", text = "Gain 5 Armor. Draw a card.",
    spell = { effects = { { op = "armor", n = 5 }, { op = "draw", n = 1 } } } })
Add({ key = "warsong_commander", npc = 12864, name = "Warsong Commander", cost = 3, type = "minion",
    class = "warrior", attack = 2, health = 3, art = I .. "INV_Banner_03",
    text = "Whenever you summon a minion with 3 or less Attack, give it Charge.",
    onSummon = { filter = { maxAttack = 3 }, effects = { { op = "buff", to = "summoned", charge = true } } } })
Add({ key = "korkron_elite", npc = 14304, name = "Kor'kron Elite", cost = 4, type = "minion", class = "warrior",
    attack = 4, health = 3, charge = true, art = I .. "INV_Helmet_09", text = "Charge" })
Add({ key = "arcanite_reaper", name = "Arcanite Reaper", cost = 5, type = "weapon", class = "warrior", attack = 5,
    durability = 2, art = I .. "INV_Axe_09" })

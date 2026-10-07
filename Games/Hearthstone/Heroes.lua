-- Hearthstone heroes, hero powers and decks: data only.
--
-- A hero: key, name, class (WoW class token, for the portrait), health,
-- power = { name, cost, target = spec or nil, effects = { ... }, text, art },
-- deck = the key of its default deck in Decks.
-- A deck: a list of { cardKey, copies }; 30 cards.
-- Adding a hero = a new entry here (and its class cards in Cards.lua).
local ADDON, ns = ...

ns.HS = ns.HS or {}
local I = "Interface\\Icons\\"

local H = {}
ns.HS.Heroes = H

H.jaina = {
    key = "jaina", npc = 4968, name = "Jaina Proudmoore", class = "MAGE", health = 30, deck = "basic_mage",
    power = { name = "Fireblast", school = "fire", cost = 2, target = "any", art = I .. "Spell_Fire_FireBolt02",
        text = "Deal 1 damage.", effects = { { op = "damage", to = "target", amount = 1 } } },
}
H.thrall = {
    key = "thrall", npc = 4949, name = "Thrall", class = "SHAMAN", health = 30, deck = "basic_shaman",
    power = { name = "Totemic Call", school = "nature", cost = 2, art = I .. "Spell_Nature_StoneClawTotem",
        text = "Summon a random Totem.",
        effects = { { op = "summonRandom", unique = true,
            pool = { "healing_totem", "searing_totem", "stoneclaw_totem", "wrath_of_air_totem" } } } },
}
H.garrosh = {
    key = "garrosh", npc = 14720, name = "Garrosh Hellscream", class = "WARRIOR", health = 30, deck = "basic_warrior",
    power = { name = "Armor Up!", school = "physical", cost = 2, art = I .. "Ability_Warrior_DefensiveStance",
        text = "Gain 2 Armor.", effects = { { op = "armor", to = "myHero", n = 2 } } },
}

H.malfurion = {
    key = "malfurion", npc = 15362, name = "Malfurion Stormrage", class = "DRUID", health = 30, deck = "basic_druid",
    power = { name = "Shapeshift", school = "nature", cost = 2, art = I .. "Ability_Druid_CatForm",
        text = "+1 Attack this turn. +1 Armor.",
        effects = { { op = "buff", to = "myHero", attack = 1, temp = true }, { op = "armor", n = 1 } } },
}
H.rexxar = {
    key = "rexxar", npc = 10182, name = "Rexxar", class = "HUNTER", health = 30, deck = "basic_hunter",
    power = { name = "Steady Shot", school = "physical", cost = 2, art = I .. "INV_Weapon_Bow_07",
        text = "Deal 2 damage to the enemy hero.", effects = { { op = "damage", to = "enemyHero", amount = 2 } } },
}
H.uther = {
    key = "uther", npc = 1855, name = "Uther Lightbringer", class = "PALADIN", health = 30, deck = "basic_paladin",
    power = { name = "Reinforce", school = "holy", cost = 2, art = I .. "Spell_Holy_Resurrection",
        text = "Summon a 1/1 Silver Hand Recruit.", effects = { { op = "summon", card = "silver_hand_recruit" } } },
}
H.anduin = {
    key = "anduin", npc = 1284, -- Archbishop Benedictus: an adult human priest (no adult Anduin in classic)
    name = "Anduin Wrynn", class = "PRIEST", health = 30, deck = "basic_priest",
    power = { name = "Lesser Heal", school = "holy", cost = 2, target = "any", art = I .. "Spell_Holy_LesserHeal",
        text = "Restore 2 Health.", effects = { { op = "heal", to = "target", amount = 2 } } },
}
H.valeera = {
    key = "valeera", npc = 4163, -- Syurna: an elf woman, rogue trainer (no blood elves in classic)
    name = "Valeera Sanguinar", class = "ROGUE", health = 30, deck = "basic_rogue",
    power = { name = "Dagger Mastery", school = "physical", cost = 2, art = I .. "INV_Weapon_ShortBlade_01",
        text = "Equip a 1/2 Dagger.", effects = { { op = "equip", card = "wicked_knife" } } },
}
H.guldan = {
    key = "guldan", npc = 3216, -- Neeru Fireblade: a hooded orc warlock
    name = "Gul'dan", class = "WARLOCK", health = 30, deck = "basic_warlock",
    power = { name = "Life Tap", school = "arcane", cost = 2, art = I .. "Spell_Shadow_BurningSpirit",
        text = "Draw a card and take 2 damage.",
        effects = { { op = "draw", n = 1 }, { op = "damage", to = "myHero", amount = 2 } } },
}

local D = {}
ns.HS.Decks = D

D.basic_mage = {
    { "arcane_missiles", 2 }, { "frostbolt", 2 }, { "arcane_intellect", 2 }, { "fireball", 2 },
    { "polymorph", 1 }, { "water_elemental", 2 }, { "flamestrike", 1 }, { "arcane_explosion", 1 },
    { "bloodfen_raptor", 2 }, { "river_crocolisk", 2 }, { "novice_engineer", 1 }, { "ironforge_rifleman", 2 },
    { "razorfen_hunter", 2 }, { "chillwind_yeti", 2 }, { "senjin_shieldmasta", 2 }, { "gnomish_inventor", 1 },
    { "boulderfist_ogre", 2 }, { "archmage", 1 },
}
D.basic_shaman = {
    { "frost_shock", 2 }, { "lightning_bolt", 2 }, { "flametongue_totem", 2 }, { "feral_spirit", 2 }, { "hex", 2 },
    { "lava_burst", 1 }, { "bloodlust", 1 }, { "earth_elemental", 1 }, { "fire_elemental", 2 },
    { "bloodfen_raptor", 2 }, { "frostwolf_grunt", 2 }, { "murloc_tidehunter", 2 },
    { "ironfur_grizzly", 2 }, { "shattered_sun_cleric", 2 }, { "senjin_shieldmasta", 1 },
    { "stormpike_commando", 1 }, { "booty_bay_bodyguard", 1 }, { "darkscale_healer", 1 }, { "stormwind_champion", 1 },
}
D.basic_druid = {
    { "innervate", 2 }, { "moonfire", 2 }, { "claw", 2 }, { "mark_of_the_wild", 2 }, { "wild_growth", 2 },
    { "healing_touch", 1 }, { "savage_roar", 1 }, { "swipe", 2 }, { "starfire", 1 }, { "ironbark_protector", 1 },
    { "river_crocolisk", 2 }, { "bloodfen_raptor", 2 }, { "ironfur_grizzly", 2 }, { "chillwind_yeti", 2 },
    { "senjin_shieldmasta", 2 }, { "oasis_snapjaw", 1 }, { "boulderfist_ogre", 2 }, { "darkscale_healer", 1 },
}
D.basic_hunter = {
    { "arcane_shot", 2 }, { "hunters_mark", 1 }, { "timber_wolf", 2 }, { "animal_companion", 2 }, { "kill_command", 2 },
    { "multi_shot", 1 }, { "houndmaster", 2 }, { "starving_buzzard", 2 }, { "tundra_rhino", 1 },
    { "stonetusk_boar", 2 }, { "bloodfen_raptor", 2 }, { "river_crocolisk", 2 }, { "ironfur_grizzly", 2 },
    { "oasis_snapjaw", 1 }, { "razorfen_hunter", 2 }, { "core_hound", 1 }, { "reckless_rocketeer", 1 },
    { "silverback_patriarch", 2 },
}
D.basic_paladin = {
    { "blessing_of_might", 1 }, { "hand_of_protection", 2 }, { "humility", 1 }, { "lights_justice", 2 },
    { "holy_light", 1 }, { "blessing_of_kings", 2 }, { "consecration", 2 }, { "hammer_of_wrath", 2 },
    { "truesilver_champion", 2 }, { "guardian_of_kings", 1 },
    { "argent_squire", 2 }, { "goldshire_footman", 1 }, { "shattered_sun_cleric", 2 }, { "raid_leader", 2 },
    { "scarlet_crusader", 2 }, { "chillwind_yeti", 2 }, { "senjin_shieldmasta", 2 }, { "stormwind_champion", 1 },
}
D.basic_priest = {
    { "holy_smite", 2 }, { "mind_vision", 1 }, { "power_word_shield", 2 }, { "northshire_cleric", 2 },
    { "divine_spirit", 1 }, { "mind_blast", 1 }, { "shadow_word_pain", 2 }, { "shadow_word_death", 2 },
    { "holy_nova", 1 }, { "mind_control", 1 },
    { "voodoo_doctor", 2 }, { "river_crocolisk", 2 }, { "dalaran_mage", 2 }, { "chillwind_yeti", 2 },
    { "senjin_shieldmasta", 2 }, { "gnomish_inventor", 2 }, { "darkscale_healer", 1 }, { "boulderfist_ogre", 2 },
}
D.basic_rogue = {
    { "backstab", 2 }, { "deadly_poison", 2 }, { "sinister_strike", 1 }, { "sap", 2 }, { "shiv", 2 },
    { "fan_of_knives", 2 }, { "assassins_blade", 1 }, { "assassinate", 2 }, { "vanish", 1 }, { "sprint", 1 },
    { "elven_archer", 2 }, { "bloodfen_raptor", 2 }, { "wolfrider", 2 }, { "scarlet_crusader", 2 },
    { "chillwind_yeti", 2 }, { "gnomish_inventor", 2 }, { "stormpike_commando", 2 },
}
D.basic_warlock = {
    { "sacrificial_pact", 1 }, { "corruption", 2 }, { "mortal_coil", 2 }, { "soulfire", 2 }, { "voidwalker", 2 },
    { "succubus", 2 }, { "drain_life", 2 }, { "shadow_bolt", 2 }, { "hellfire", 1 }, { "dread_infernal", 1 },
    { "murloc_raider", 2 }, { "bloodfen_raptor", 2 }, { "river_crocolisk", 2 }, { "magma_rager", 1 },
    { "chillwind_yeti", 2 }, { "senjin_shieldmasta", 2 }, { "boulderfist_ogre", 2 },
}
D.basic_warrior = {
    { "execute", 2 }, { "whirlwind", 2 }, { "cleave", 1 }, { "charge", 1 }, { "fiery_war_axe", 2 },
    { "heroic_strike", 2 }, { "shield_block", 2 }, { "warsong_commander", 2 }, { "arcanite_reaper", 2 },
    { "korkron_elite", 2 },
    { "frostwolf_grunt", 2 }, { "bluegill_warrior", 2 }, { "wolfrider", 2 }, { "ironfur_grizzly", 2 },
    { "lord_of_the_arena", 1 }, { "gurubashi_berserker", 1 }, { "booty_bay_bodyguard", 2 },
}
D.basic_neutral = {
    { "elven_archer", 2 }, { "goldshire_footman", 2 }, { "argent_squire", 2 }, { "bloodfen_raptor", 2 },
    { "river_crocolisk", 2 }, { "frostwolf_grunt", 2 }, { "raid_leader", 2 }, { "scarlet_crusader", 2 },
    { "chillwind_yeti", 2 }, { "senjin_shieldmasta", 2 }, { "gurubashi_berserker", 2 }, { "booty_bay_bodyguard", 2 },
    { "lord_of_the_arena", 2 }, { "boulderfist_ogre", 2 }, { "core_hound", 1 }, { "war_golem", 1 },
}

-- A deck as a flat list of 30 card keys.
function ns.HS.DeckList(deckKey)
    local list = {}
    for _, e in ipairs(D[deckKey]) do
        for _ = 1, e[2] do table.insert(list, e[1]) end
    end
    return list
end

---------------------------------------------------------------------------
-- Deck building rules
---------------------------------------------------------------------------
ns.HS.DECK_SIZE = 30

-- The card class a hero may use ("mage" for Jaina), besides neutral cards.
function ns.HS.ClassOf(heroKey)
    return H[heroKey].class:lower()
end

-- How many copies a deck may hold (legendaries: 1).
function ns.HS.MaxCopies(key)
    local c = ns.HS.Cards[key]
    return c.maxCopies or (c.rarity == "legendary" and 1) or 2
end

-- Every card a hero can put in a deck, by cost then name.
function ns.HS.Collection(heroKey)
    local class = ns.HS.ClassOf(heroKey)
    local list = {}
    for key, c in pairs(ns.HS.Cards) do
        if not c.token and (c.class == "neutral" or c.class == class) then table.insert(list, key) end
    end
    table.sort(list, function(a, b)
        local ca, cb = ns.HS.Cards[a], ns.HS.Cards[b]
        if (ca.class == "neutral") ~= (cb.class == "neutral") then return cb.class == "neutral" end
        if ca.cost ~= cb.cost then return ca.cost < cb.cost end
        return ca.name < cb.name
    end)
    return list
end

-- Is this list a playable deck for the hero? ok, or false and why.
function ns.HS.CheckDeck(heroKey, list)
    local class = ns.HS.ClassOf(heroKey)
    local counts = {}
    for _, key in ipairs(list) do
        local c = ns.HS.Cards[key]
        if not c or c.token then return false, "unknown card" end
        if c.class ~= "neutral" and c.class ~= class then return false, c.name .. " is not a " .. class .. " card" end
        counts[key] = (counts[key] or 0) + 1
        if counts[key] > ns.HS.MaxCopies(key) then return false, "too many copies of " .. c.name end
    end
    if #list ~= ns.HS.DECK_SIZE then return false, #list .. "/" .. ns.HS.DECK_SIZE .. " cards" end
    return true
end

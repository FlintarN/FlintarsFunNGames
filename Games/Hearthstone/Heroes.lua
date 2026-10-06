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
    key = "garrosh", npc = 14304, name = "Garrosh Hellscream", class = "WARRIOR", health = 30, deck = "basic_neutral",
    power = { name = "Armor Up!", school = "physical", cost = 2, art = I .. "Ability_Warrior_DefensiveStance",
        text = "Gain 2 Armor.", effects = { { op = "armor", to = "myHero", n = 2 } } },
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

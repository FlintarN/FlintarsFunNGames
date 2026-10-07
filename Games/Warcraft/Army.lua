-- Warcraft III: the rest of the Human and Orc armies. New buildings and
-- units (casters, siege, beasts, flyers), air units and what can hit them,
-- splash damage, casters that autocast (Heal, Inner Fire, Slow, Bloodlust,
-- Healing Ward), shops with items for heroes, and upkeep.
local _, ns = ...

local WC = ns.WC
local E = WC.Engine
local U, B, F = WC.Units, WC.Buildings, WC.Factions
local I = "Interface\\Icons\\"

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
-- Magic attacks (casters, Gryphon Riders): good against heavy armour.
WC.DAMAGE.magic = { light = 1.25, medium = 0.75, heavy = 2, fortified = 0.35, unarmored = 1, hero = 0.5 }

local function Unit(t)
    t.attackType = t.attackType or "normal"
    t.armorType = t.armorType or "medium"
    return t
end
-- Human
U.knight = Unit({ npc = 15857, hotkey = "K", name = "Knight", hp = 835, armor = 5, damage = 34, cooldown = 1.4, range = 1,
    speed = 3.5, cost = { 245, 60 }, time = 45, food = 4, armorType = "heavy", requires = { "castle", "blacksmith", "lumber_mill" },
    icon = I .. "Ability_Mount_Charger" })
U.priest = Unit({ npc = 11053, hotkey = "P", name = "Priest", hp = 290, armor = 0, damage = 8.5, cooldown = 2, range = 6,
    speed = 2.7, cost = { 135, 10 }, time = 28, food = 2, attackType = "magic", armorType = "unarmored", mana = 200,
    autocast = { "heal", "inner_fire" }, icon = I .. "Spell_Holy_Heal" })
U.sorceress = Unit({ npc = 4566, hotkey = "S", name = "Sorceress", hp = 325, armor = 0, damage = 10, cooldown = 1.75, range = 6,
    speed = 2.7, cost = { 155, 20 }, time = 30, food = 2, attackType = "magic", armorType = "unarmored", mana = 200,
    autocast = { "slow" }, icon = I .. "Spell_Nature_Slow" })
U.siege_engine = Unit({ npc = 15364, hotkey = "E", name = "Siege Engine", hp = 700, armor = 2, damage = 50, cooldown = 2.5,
    range = 1.5, speed = 2.2, cost = { 195, 60 }, time = 45, food = 3, attackType = "siege", armorType = "fortified",
    buildingsOnly = true, icon = I .. "INV_Gizmo_02" })
U.flying_machine = Unit({ npc = 15553, hotkey = "F", name = "Flying Machine", hp = 175, armor = 1, damage = 15, cooldown = 1.5,
    range = 4, speed = 4, cost = { 90, 30 }, time = 22, food = 1, attackType = "pierce", armorType = "light", air = true,
    airOnly = true, icon = I .. "INV_Gizmo_01" })
U.mortar_team = Unit({ npc = 15435, hotkey = "M", name = "Mortar Team", hp = 360, armor = 0, damage = 55, cooldown = 3.5,
    range = 8, speed = 2.5, cost = { 180, 70 }, time = 40, food = 3, attackType = "siege", armorType = "heavy", splash = 1.5,
    groundOnly = true, icon = I .. "INV_Misc_Bomb_04" })
U.gryphon_rider = Unit({ npc = 17719, hotkey = "G", name = "Gryphon Rider", hp = 825, armor = 0, damage = 45, cooldown = 2.2,
    range = 4.5, speed = 4, cost = { 280, 70 }, time = 45, food = 4, attackType = "magic", armorType = "light", air = true,
    requires = { "castle" }, icon = I .. "Ability_Hunter_Pet_Owl" })
U.dragonhawk_rider = Unit({ npc = 3837, hotkey = "D", name = "Dragonhawk Rider", hp = 575, armor = 1, damage = 19,
    cooldown = 1.75, range = 4.5, speed = 4, cost = { 200, 30 }, time = 32, food = 3, attackType = "pierce", armorType = "light",
    air = true, icon = I .. "Ability_Hunter_Pet_DragonHawk" })
-- Orc
U.catapult = Unit({ npc = 16121, hotkey = "C", name = "Catapult", hp = 425, armor = 2, damage = 90, cooldown = 4.5, range = 9,
    speed = 2.2, cost = { 220, 50 }, time = 40, food = 4, attackType = "siege", armorType = "heavy", splash = 1.5,
    groundOnly = true, requires = { "war_mill" }, icon = I .. "INV_Misc_Bomb_02" })
U.raider = Unit({ npc = 13440, hotkey = "R", name = "Raider", hp = 610, armor = 1, damage = 24, cooldown = 1.85, range = 1,
    speed = 3.5, cost = { 180, 40 }, time = 28, food = 3, attackType = "siege", icon = I .. "Ability_Mount_WhiteDireWolf" })
U.kodo = Unit({ npc = 5523, hotkey = "K", name = "Kodo Beast", hp = 1000, armor = 1, damage = 16, cooldown = 1.45, range = 4.5,
    speed = 2.7, cost = { 255, 60 }, time = 30, food = 4, attackType = "pierce", armorType = "heavy", drums = 0.1,
    icon = I .. "Ability_Mount_Kodo_01" })
U.wind_rider = Unit({ npc = 17720, hotkey = "W", name = "Wind Rider", hp = 570, armor = 1, damage = 40, cooldown = 1.9,
    range = 4.5, speed = 4, cost = { 265, 40 }, time = 35, food = 4, attackType = "pierce", armorType = "light", air = true,
    requires = { "fortress" }, icon = I .. "Ability_Mount_Wyvern_01" })
U.batrider = Unit({ npc = 14750, hotkey = "B", name = "Troll Batrider", hp = 325, armor = 0, damage = 12, cooldown = 1.75,
    range = 4, speed = 4.2, cost = { 160, 40 }, time = 28, food = 2, attackType = "pierce", armorType = "light", air = true,
    icon = I .. "Ability_Hunter_Pet_Bat" })
U.shaman = Unit({ npc = 11683, hotkey = "S", name = "Shaman", hp = 335, armor = 0, damage = 8.5, cooldown = 2, range = 6,
    speed = 2.7, cost = { 130, 20 }, time = 30, food = 2, attackType = "magic", armorType = "unarmored", mana = 200,
    autocast = { "bloodlust" }, icon = I .. "Spell_Nature_BloodLust" })
U.witch_doctor = Unit({ npc = 11831, hotkey = "D", name = "Witch Doctor", hp = 315, armor = 0, damage = 10, cooldown = 2,
    range = 6, speed = 2.7, cost = { 145, 25 }, time = 30, food = 2, attackType = "magic", armorType = "unarmored", mana = 200,
    autocast = { "healing_ward" }, icon = I .. "Spell_Nature_HealingWaveLesser" })
U.tauren = Unit({ npc = 7725, hotkey = "T", name = "Tauren", hp = 1300, armor = 3, damage = 33, cooldown = 1.9, range = 1,
    speed = 2.7, cost = { 280, 80 }, time = 45, food = 5, splash = 1, requires = { "fortress", "war_mill" },
    icon = I .. "Ability_Warrior_WarStomp" })
U.healing_ward = Unit({ npc = 8179, name = "Healing Ward", hp = 5, armor = 0, damage = 0, cooldown = 1, range = 0, speed = 0,
    cost = { 0, 0 }, time = 0, food = 0, summon = true, noAttack = true, icon = I .. "Spell_Nature_HealingWaveLesser" })
-- The Showcase's punching bag (the engineers' Target Dummy).
U.target_dummy = Unit({ npc = 2673, name = "Target Dummy", hp = 100000, armor = 0, damage = 0, cooldown = 1, range = 0, speed = 0,
    cost = { 0, 0 }, time = 0, food = 0, noAttack = true, icon = I .. "INV_Gizmo_01" })

-- Training: who trains what.
table.insert(B.barracks.trains, "knight")
table.insert(B.orc_barracks.trains, "catapult")
B.arcane_sanctum = { hotkey = "R", name = "Arcane Sanctum", hp = 1050, armor = 5, size = 3, cost = { 150, 140 }, time = 40, food = 0,
    trains = { "priest", "sorceress" }, requires = { "keep" }, icon = I .. "Spell_Holy_MagicalSentry" }
B.workshop = { hotkey = "W", name = "Workshop", hp = 1200, armor = 5, size = 3, cost = { 140, 140 }, time = 40, food = 0,
    trains = { "siege_engine", "flying_machine", "mortar_team" }, requires = { "keep", "blacksmith" },
    icon = I .. "Trade_Engineering" }
B.gryphon_aviary = { hotkey = "G", name = "Gryphon Aviary", hp = 1050, armor = 5, size = 3, cost = { 140, 150 }, time = 45, food = 0,
    trains = { "gryphon_rider", "dragonhawk_rider" }, requires = { "keep", "lumber_mill" }, icon = I .. "Ability_Hunter_Pet_Owl" }
B.arcane_vault = { hotkey = "V", name = "Arcane Vault", hp = 485, armor = 5, size = 2, cost = { 130, 30 }, time = 30, food = 0,
    sells = { "healing_potion", "mana_potion", "town_portal", "boots", "claws", "ring" }, requires = { "town_hall" },
    icon = I .. "INV_Misc_Bag_10" }
B.spirit_lodge = { hotkey = "S", name = "Spirit Lodge", hp = 800, armor = 5, size = 3, cost = { 150, 150 }, time = 40, food = 0,
    trains = { "shaman", "witch_doctor" }, requires = { "stronghold" }, icon = I .. "Spell_Nature_BloodLust" }
B.beastiary = { hotkey = "B", name = "Beastiary", hp = 1100, armor = 5, size = 3, cost = { 145, 140 }, time = 40, food = 0,
    trains = { "raider", "kodo", "wind_rider", "batrider" }, requires = { "stronghold" }, icon = I .. "Ability_Mount_Kodo_01" }
B.tauren_totem = { hotkey = "T", name = "Tauren Totem", hp = 1200, armor = 5, size = 3, cost = { 135, 155 }, time = 45, food = 0,
    trains = { "tauren" }, requires = { "fortress", "war_mill" }, icon = I .. "Ability_Warrior_WarStomp" }
B.voodoo_lounge = { hotkey = "V", name = "Voodoo Lounge", hp = 485, armor = 5, size = 2, cost = { 130, 30 }, time = 30, food = 0,
    sells = { "healing_potion", "mana_potion", "town_portal", "boots", "claws", "ring" }, requires = { "great_hall" },
    icon = I .. "INV_Misc_Bag_10" }
for _, b in ipairs({ "arcane_sanctum", "workshop", "gryphon_aviary", "arcane_vault" }) do table.insert(F.human.builds, b) end
for _, b in ipairs({ "spirit_lodge", "beastiary", "tauren_totem", "voodoo_lounge" }) do table.insert(F.orc.builds, b) end

-- Their looks (game files, M2) and drawings if models can't load.
local M = WC.ART.models
M.arcane_sanctum = { file = 2061082, tall = 1.6, fill = 0.9 }  -- the warfront mage tower
M.workshop = { file = 189601, fill = 1.05 }                     -- (the Blacksmith's)
M.gryphon_aviary = { file = 198261, fill = 1.1 }               -- generic/human/gryphonroost01 (gallery 105)
M.arcane_vault = { file = 381045, fill = 0.9 }                 -- stormwind auction house (gallery 117)
M.spirit_lodge = { file = 2061081, tall = 1.6, fill = 0.9 }    -- the warfront orc mage tower
M.beastiary = { file = 199385 }                                -- durotarorctent02 (gallery 23)
M.tauren_totem = { file = 200577, tall = 2.0 }                 -- taurentotem01 (gallery 67)
M.voodoo_lounge = { file = 201389 }                            -- raptorhut01 (gallery 58)

-- Spells casters use by themselves (autocast), as in Warcraft III.
local A = WC.Abilities
A.heal = { name = "Heal", icon = I .. "Spell_Holy_Heal", mana = { 5 }, range = 6, amount = { 25 }, autocast = true }
A.inner_fire = { name = "Inner Fire", icon = I .. "Spell_Holy_InnerFire", mana = { 35 }, range = 7, duration = { 60 },
    autocast = true }
A.slow = { name = "Slow", icon = I .. "Spell_Nature_Slow", mana = { 50 }, range = 7, duration = { 60 }, heroDuration = { 10 },
    autocast = true }
A.bloodlust = { name = "Bloodlust", icon = I .. "Spell_Nature_BloodLust", mana = { 40 }, range = 7, duration = { 60 },
    autocast = true }
A.healing_ward_spell = { name = "Healing Ward", icon = I .. "Spell_Nature_HealingWaveLesser", mana = { 100 }, duration = { 45 },
    autocast = true }

-- Items for heroes, sold at the Arcane Vault / Voodoo Lounge.
WC.Items = {
    healing_potion = { name = "Potion of Healing", cost = 150, icon = I .. "INV_Potion_51", use = "heal", amount = 250,
        text = "Restores 250 health." },
    mana_potion = { name = "Potion of Mana", cost = 200, icon = I .. "INV_Potion_72", use = "mana", amount = 150,
        text = "Restores 150 mana." },
    town_portal = { name = "Scroll of Town Portal", cost = 350, icon = I .. "INV_Scroll_06", use = "portal",
        text = "Takes the hero and units nearby home to your hall." },
    boots = { name = "Boots of Speed", cost = 250, icon = I .. "INV_Boots_02", speed = 0.2, text = "The hero moves faster." },
    claws = { name = "Claws of Attack +6", cost = 300, icon = I .. "INV_Gauntlets_04", damage = 6, text = "+6 damage." },
    ring = { name = "Ring of Protection +2", cost = 150, icon = I .. "INV_Jewelry_Ring_03", armor = 2, text = "+2 armour." },
}
WC.ITEM_ORDER = { "healing_potion", "mana_potion", "town_portal", "boots", "claws", "ring" }
WC.ITEM_KEYS = { healing_potion = "H", mana_potion = "M", town_portal = "T", boots = "B", claws = "C", ring = "R" }
WC.SHOP_RANGE = 7
WC.UPKEEP = { { 80, 0.4, "high" }, { 50, 0.7, "low" } } -- above this much food, this share of the gold

---------------------------------------------------------------------------
-- Rules
---------------------------------------------------------------------------
local function D(u) return U[u.type] end

-- Can attacker a (a unit, or a building's turret) hit target t?
function E.CanHit(st, a, t)
    local d = a.type and U[a.type]
    local air = t.kind == "unit" and U[t.type] and U[t.type].air
    if not d then return true end -- a tower or burrow: hits ground and air
    if d.buildingsOnly and t.kind ~= "building" then return false end
    if d.airOnly and not air then return false end
    if air and (d.groundOnly or d.range <= 1.5) then return false end
    return true
end

-- What items add to a hero.
function E.ItemBonus(u, field)
    local n = 0
    for _, key in ipairs(u.items or {}) do
        local it = WC.Items[key]
        if it and it[field] then n = n + it[field] end
    end
    return n
end

-- War Drums: a Kodo Beast nearby makes friends hit harder.
function E.Drums(st, u)
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and e.owner == u.owner and U[e.type] and U[e.type].drums
            and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= 81 then
            return U[e.type].drums
        end
    end
    return 0
end

-- Gold per trip after upkeep, and its name ("low", "high", or nil).
function E.Upkeep(st, p)
    local food = st.players[p].food or 0
    for _, u in ipairs(WC.UPKEEP) do
        if food > u[1] then return u[2], u[3] end
    end
    return 1, nil
end

-- Casters: one spell a second, by themselves. Healing Wards heal.
local function Friends(st, u, r, pred)
    local best, bv
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and e.owner == u.owner and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= r * r then
            local v = pred(e)
            if v and (not bv or v > bv) then best, bv = e, v end
        end
    end
    return best
end
local function EnemyNear(st, u, r)
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and e.owner > 0 and e.owner ~= u.owner and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= r * r
            and not (E.Hidden(e) or E.Untouchable(e)) then
            return e
        end
    end
end

local AUTO = {}
AUTO.heal = function(st, u, a)
    local t = Friends(st, u, a.range, function(e)
        local miss = e.maxHp - e.hp
        return miss >= 25 and not U[e.type].summon and miss or nil
    end)
    if not t then return false end
    t.hp = math.min(t.maxHp, t.hp + a.amount[1])
    E.Emit("heal", { id = u.id, target = t.id, amount = a.amount[1] })
    return true
end
AUTO.inner_fire = function(st, u, a)
    if not EnemyNear(st, u, 10) then return false end
    local t = Friends(st, u, a.range, function(e)
        return not (e.buffs and e.buffs.innerFire) and not D(e).worker and not D(e).summon and e.maxHp or nil
    end)
    if not t then return false end
    E.AddBuff(t, "innerFire", a.duration[1])
    return true
end
AUTO.slow = function(st, u, a)
    local best
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and e.owner > 0 and e.owner ~= u.owner and not (e.buffs and e.buffs.slow)
            and not (E.Hidden(e) or E.Untouchable(e)) and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= a.range * a.range then
            if not best or E.IsHero(e) then best = e end
        end
    end
    if not best then return false end
    E.AddBuff(best, "slow", E.IsHero(best) and a.heroDuration[1] or a.duration[1])
    return true
end
AUTO.bloodlust = function(st, u, a)
    if not EnemyNear(st, u, 10) then return false end
    local t = Friends(st, u, a.range, function(e)
        return not (e.buffs and e.buffs.bloodlust) and not D(e).worker and not D(e).summon and D(e).damage > 0
            and e.maxHp or nil
    end)
    if not t then return false end
    E.AddBuff(t, "bloodlust", a.duration[1])
    return true
end
AUTO.healing_ward = function(st, u, a)
    local hurt = 0
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and e.owner == u.owner and e.hp < e.maxHp * 0.7 and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= 36 then
            hurt = hurt + 1
        end
        if e and e.type == "healing_ward" and e.owner == u.owner and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= 36 then
            return false -- one is enough here
        end
    end
    if hurt < 2 then return false end
    local fx, fy = E.NearestFree(st, math.floor(u.x), math.floor(u.y + 1))
    if not fx then return false end
    local w = E.Spawn(st, u.owner, "healing_ward", fx + 0.5, fy + 0.5)
    w.summon, w.expire = true, st.time + 45
    return true
end
local SPELL = { heal = "heal", inner_fire = "inner_fire", slow = "slow", bloodlust = "bloodlust",
    healing_ward = "healing_ward_spell" }

-- Every step for every unit, after the hero part (true: busy, skip the rest).
function E.ArmyTick(st, u, dt)
    local d = U[u.type]
    if not d then return false end
    if d.mana and u.maxMana then u.mana = math.min(u.maxMana, (u.mana or 0) + 0.75 * dt) end
    if u.type == "healing_ward" then
        u.healT = (u.healT or 0) + dt
        if u.healT >= 1 then
            u.healT = u.healT - 1
            for _, id in ipairs(st.list) do
                local e = st.ents[id]
                if e and e.kind == "unit" and e.owner == u.owner and e ~= u and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= 25 then
                    e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.02)
                end
            end
        end
        return false
    end
    if d.autocast and not st.peace and not E.CantAttack(u) then -- (the Showcase: only what you tell them)
        u.castT = (u.castT or 0) - dt
        if u.castT <= 0 then
            u.castT = 1
            for _, key in ipairs(d.autocast) do
                local a = WC.Abilities[SPELL[key]]
                if (u.mana or 0) >= a.mana[1] and AUTO[key](st, u, a) then
                    u.mana = u.mana - a.mana[1]
                    E.Emit("cast", { id = u.id, owner = u.owner, ability = SPELL[key] })
                    break
                end
            end
        end
    end
    return false
end

-- Commands: buy an item, use one.
function E.ArmyCommand(st, p, cmd)
    local pl = st.players[p]
    if cmd.type == "buy" then
        local shop = st.ents[cmd.building]
        local hero = st.ents[cmd.unit]
        local it = WC.Items[cmd.item]
        if not (shop and shop.owner == p and shop.progress >= 1 and E.Def(shop).sells) or not it then return false, "not here" end
        if not (hero and hero.owner == p and E.IsHero(hero)) or hero.illusion then return false, "a hero buys" end
        local cx, cy = E.Center(shop)
        if (hero.x - cx) ^ 2 + (hero.y - cy) ^ 2 > WC.SHOP_RANGE ^ 2 then return false, "bring a hero next to the shop" end
        hero.items = hero.items or {}
        if #hero.items >= 6 then return false, "the hero's bag is full" end
        if pl.gold < it.cost then return false, "not enough gold" end
        pl.gold = pl.gold - it.cost
        table.insert(hero.items, cmd.item)
        return true
    elseif cmd.type == "useItem" then
        local hero = st.ents[cmd.unit]
        if not (hero and hero.owner == p and hero.items) then return false end
        local key = hero.items[cmd.slot or 0]
        local it = key and WC.Items[key]
        if not it or not it.use then return false, "that works by itself" end
        if it.use == "heal" then
            hero.hp = math.min(hero.maxHp, hero.hp + it.amount)
        elseif it.use == "mana" then
            hero.mana = math.min(hero.maxMana or 0, (hero.mana or 0) + it.amount)
        elseif it.use == "portal" then
            local hall = E.Hall(st, p)
            if not hall then return false, "you have no hall" end
            E.CAST.mass_teleport(st, hero, 1, { amount = { 24 }, radius = 6 }, hall)
        end
        table.remove(hero.items, cmd.slot)
        E.Emit("useItem", { id = hero.id, owner = p, item = key })
        return true
    end
    return false, "unknown command"
end

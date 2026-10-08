-- Warcraft 4: WoW loot (Hero Defense). Items drop where creeps die, in WoW's
-- qualities (grey, white, green, blue, purple) with Classic's suffixes ("of
-- the Bear"); bosses drop their own. Heroes pick items up by walking over
-- them, drop them (Drop: someone else can take it - trading), and sell them
-- at a merchant. A class hero wears gear in six slots (one weapon, three
-- armour, two accessories: only worn gear counts) and carries six more things
-- in the bag (potions, tomes, spare gear).
--
-- A dropped item is a key: "g:<base>:<quality>:<suffix>:<level>" - its stats
-- come from the key (WC.Items fills itself in on first look), so the game
-- state stays plain text for lockstep.
local ADDON, ns = ...

local WC = ns.WC
local E = WC.Engine
local U = WC.Units
local I = "Interface\\Icons\\"

local L = {}
WC.Loot = L

L.QUALITY = {
    { name = "Poor", color = "ff9d9d9d", mult = 0.35 },
    { name = "Common", color = "ffffffff", mult = 0.6 },
    { name = "Uncommon", color = "ff1eff00", mult = 1 },
    { name = "Rare", color = "ff0070dd", mult = 1.4 },
    { name = "Epic", color = "ffa335ee", mult = 2 },
}
-- kind: weapon (damage), armor (armour), jewel (stats only).
L.BASES = {
    { "Shortsword", "INV_Sword_04", "weapon" }, { "Cleaver", "INV_Axe_04", "weapon" }, { "Mace", "INV_Mace_01", "weapon" },
    { "Dagger", "INV_Weapon_ShortBlade_05", "weapon" }, { "Staff", "INV_Staff_08", "weapon" }, { "Longbow", "INV_Weapon_Bow_05", "weapon" },
    { "Leather Tunic", "INV_Chest_Leather_01", "armor" }, { "Chain Vest", "INV_Chest_Chain_05", "armor" },
    { "Plate Helm", "INV_Helmet_03", "armor" }, { "Cloak", "INV_Misc_Cape_02", "armor" }, { "Boots", "INV_Boots_05", "armor" },
    { "Gloves", "INV_Gauntlets_05", "armor" }, { "Belt", "INV_Belt_03", "armor" },
    { "Ring", "INV_Jewelry_Ring_05", "jewel" }, { "Amulet", "INV_Jewelry_Necklace_04", "jewel" }, { "Trinket", "INV_Misc_Gem_01", "jewel" },
}
-- Classic's suffixes: which stats, and how much of each.
L.SUFFIXES = {
    { "of the Bear", str = 1, sta = 1 }, { "of the Tiger", str = 1, agi = 1 }, { "of the Monkey", agi = 1, sta = 1 },
    { "of the Eagle", int = 1, sta = 1 }, { "of the Owl", int = 1.5 }, { "of the Gorilla", str = 1, int = 1 },
    { "of the Falcon", agi = 1, int = 1 }, { "of Strength", str = 1.5 }, { "of Agility", agi = 1.5 }, { "of Stamina", sta = 1.5 },
}
local POOR = { "Tattered", "Broken", "Cracked", "Frayed", "Bent" }

-- Bosses' own drops (one of them, purple).
L.NAMED = {
    cruel_barb = { name = "Cruel Barb", icon = I .. "INV_Sword_34", damage = 22, str = 6, slot = "weapon" },
    cape_brotherhood = { name = "Cape of the Brotherhood", icon = I .. "INV_Misc_Cape_14", armor = 4, agi = 9, slot = "armor" },
    robes_arugal = { name = "Robes of Arugal", icon = I .. "INV_Chest_Cloth_17", armor = 3, int = 14, hp = 90, slot = "armor" },
    meteor_shard = { name = "Meteor Shard", icon = I .. "INV_Weapon_ShortBlade_06", damage = 20, agi = 7, slot = "weapon" },
    ravager = { name = "Ravager", icon = I .. "INV_Axe_12", damage = 42, str = 12, slot = "weapon" },
    herods_shoulder = { name = "Herod's Shoulder", icon = I .. "INV_Shoulder_10", armor = 9, str = 9, hp = 120, slot = "armor" },
    viskag = { name = "Vis'kag the Bloodletter", icon = I .. "INV_Sword_51", damage = 65, agi = 16, slot = "weapon" },
    ring_of_binding = { name = "Ring of Binding", icon = I .. "INV_Jewelry_Ring_14", armor = 14, hp = 200, slot = "jewel" },
    dragonslayers_signet = { name = "Dragonslayer's Signet", icon = I .. "INV_Jewelry_Ring_27", str = 12, agi = 12, int = 12, hp = 150, slot = "jewel" },
    hoggers_trophy = { name = "Hogger's Collar", icon = I .. "INV_Jewelry_Necklace_07", str = 4, hp = 80, slot = "jewel" },
}
L.BOSS_DROPS = {
    hd_hogger = { "hoggers_trophy" }, hd_vancleef = { "cruel_barb", "cape_brotherhood" },
    hd_arugal = { "robes_arugal", "meteor_shard" }, hd_herod = { "ravager", "herods_shoulder" },
    hd_onyxia = { "viskag", "ring_of_binding", "dragonslayers_signet" },
}

local function Stats(it)
    local out = {}
    if it.damage then table.insert(out, "+" .. it.damage .. " damage") end
    if it.armor then table.insert(out, "+" .. it.armor .. " armour") end
    for _, s in ipairs({ { "str", "Strength" }, { "agi", "Agility" }, { "int", "Intellect" } }) do
        if it[s[1]] then table.insert(out, "+" .. it[s[1]] .. " " .. s[2]) end
    end
    if it.hp then table.insert(out, "+" .. it.hp .. " health") end
    return table.concat(out, ", ")
end

-- The stats behind a key.
function L.Make(key)
    local named = key:match("^n:(.+)$")
    if named then
        local n = L.NAMED[named]
        if not n then return nil end
        local it = { name = n.name, icon = n.icon, quality = 5, damage = n.damage, armor = n.armor, str = n.str, agi = n.agi,
            int = n.int, hp = n.hp, loot = true, slot = n.slot }
        it.cost = 400
        it.text = Stats(it) .. "."
        it.color = L.QUALITY[5].color
        return it
    end
    local b, q, s, lv = key:match("^g:(%d+):(%d+):(%d+):(%d+)$")
    b, q, s, lv = tonumber(b), tonumber(q), tonumber(s), tonumber(lv)
    local base, quality = b and L.BASES[b], q and L.QUALITY[q]
    if not (base and quality) then return nil end
    local budget = (3 + lv * 1.2) * quality.mult
    local it = { icon = I .. base[2], quality = q, loot = true, color = quality.color, slot = base[3] }
    local suffix = q >= 3 and L.SUFFIXES[s]
    if base[3] == "weapon" then it.damage = math.max(1, math.floor(budget * 0.9)) end
    if base[3] == "armor" then it.armor = math.max(1, math.floor(budget * 0.25)) end
    if suffix then
        local scale = base[3] == "jewel" and 0.9 or 0.55
        for _, st in ipairs({ "str", "agi", "int" }) do
            if suffix[st] then it[st] = math.max(1, math.floor(budget * scale * suffix[st])) end
        end
        if suffix.sta then it.hp = math.max(10, math.floor(budget * scale * suffix.sta) * 10) end
    end
    if base[3] == "jewel" and not suffix then it.hp = math.max(10, math.floor(budget * 4)) end
    local name = base[1]
    if q == 1 then name = POOR[(b + lv) % #POOR + 1] .. " " .. name end
    if suffix then name = name .. " " .. suffix[1] end
    it.name = name
    it.cost = math.max(5, math.floor(budget * 12))
    it.text = (Stats(it) ~= "" and Stats(it) or "Worth a few coins") .. "."
    return it
end

-- WC.Items fills in a loot key on first look.
setmetatable(WC.Items, { __index = function(t, key)
    if type(key) ~= "string" or not key:match("^[gn]:") then return nil end
    local it = L.Make(key)
    if it then rawset(t, key, it) end
    return it
end })

-- What a creep of wave `wave` drops (keys; usually nothing). boss: its own
-- item and two more good ones.
function L.Roll(st, wave, utype)
    local out = {}
    local own = L.BOSS_DROPS[utype]
    local function One(minQ, lv)
        local r = E.Rand(st, 100)
        local q = r <= 35 and 1 or r <= 65 and 2 or r <= 93 and 3 or 4
        q = math.max(q, minQ or 1)
        local b, s = E.Rand(st, #L.BASES), E.Rand(st, #L.SUFFIXES)
        table.insert(out, string.format("g:%d:%d:%d:%d", b, q, s, lv))
    end
    if own then
        table.insert(out, "n:" .. own[E.Rand(st, #own)])
        One(3, wave + 2)
        One(3, wave + 2)
    elseif E.Rand(st, 100) <= 10 + wave then
        One(1, wave + 1)
    end
    return out
end

-- Put items down at (x, y), spread a little.
function L.Drop(st, keys, x, y)
    st.items = st.items or {}
    for i, key in ipairs(keys) do
        local a = i * 2.4
        table.insert(st.items, { key = key, x = x + math.cos(a) * 0.5, y = y + math.sin(a) * 0.5 })
    end
    while #st.items > 80 do table.remove(st.items, 1) end -- (the oldest go)
end

---------------------------------------------------------------------------
-- Gear: what a class hero wears. Six slots - a weapon, three armour, two
-- accessories (rings, amulets, trinkets). Only worn gear counts.
---------------------------------------------------------------------------
L.GEAR = { "weapon", "armor", "armor", "armor", "jewel", "jewel" }
L.GEAR_NAMES = { weapon = "Weapon", armor = "Armour", jewel = "Accessory" }
-- (the merchant's things to wear)
WC.Items.claws.slot, WC.Items.ring.slot, WC.Items.boots.slot = "jewel", "jewel", "armor"

function L.Wears(u) return U[u.type] and U[u.type].class ~= nil end

-- A free gear slot for an item (its index), or nil.
function L.FreeSlot(u, key)
    local it = WC.Items[key]
    if not (it and it.slot and L.Wears(u)) then return nil end
    u.gear = u.gear or {}
    for i, kind in ipairs(L.GEAR) do
        if kind == it.slot and not u.gear[i] then return i end
    end
end

-- How good an item is (to compare: the computer's choice).
function L.Score(key)
    local it = key and WC.Items[key]
    if not it then return 0 end
    return (it.damage or 0) * 1.5 + (it.armor or 0) * 3 + (it.str or 0) + (it.agi or 0) + (it.int or 0) + (it.hp or 0) / 10
        + (it.speed or 0) * 20
end

-- Stats: a class hero's from what it wears; other heroes' from the bag.
do
    local ItemBonus = E.ItemBonus
    function E.ItemBonus(u, field)
        if not L.Wears(u) then return ItemBonus(u, field) end
        local n = 0
        for i = 1, #L.GEAR do
            local it = u.gear and u.gear[i] and WC.Items[u.gear[i]]
            if it and it[field] then n = n + it[field] end
        end
        return n
    end
end

-- Into the bag, or straight on if a slot of its kind is free. False: no room.
function L.Give(st, h, key)
    local slot = L.FreeSlot(h, key)
    if slot then
        h.gear[slot] = key
        if E.RefreshHero then E.RefreshHero(st, h) end
        return true
    end
    h.items = h.items or {}
    if #h.items >= 6 then return false end
    table.insert(h.items, key)
    return true
end

---------------------------------------------------------------------------
-- Commands: drop an item from the bag (someone else can take it), sell one
-- at a merchant, wear one, take one off. Walking over an item picks it up.
---------------------------------------------------------------------------
do
    local Command = E.Command
    function E.Command(st, p, cmd)
        if cmd.type == "equip" or cmd.type == "unequip" then
            local h = st.ents[cmd.unit or 0]
            if not (h and h.owner == p and E.IsHero(h) and L.Wears(h)) then return false, "a hero wears it" end
            h.gear, h.items = h.gear or {}, h.items or {}
            if cmd.type == "unequip" then
                local key = h.gear[cmd.gear or 0]
                if not key then return false, "nothing there" end
                if #h.items >= 6 then return false, "the bag is full" end
                h.gear[cmd.gear] = nil
                table.insert(h.items, key)
            else
                local key = h.items[cmd.slot or 0]
                local it = key and WC.Items[key]
                if not (it and it.slot) then return false, "that isn't something to wear" end
                -- A free slot of its kind, else swap with the weakest one worn.
                local at = L.FreeSlot(h, key)
                if not at then
                    local low
                    for i, kind in ipairs(L.GEAR) do
                        if kind == it.slot and (not low or L.Score(h.gear[i]) < L.Score(h.gear[low])) then low = i end
                    end
                    at = low
                end
                local old = h.gear[at]
                h.gear[at] = key
                if old then h.items[cmd.slot] = old else table.remove(h.items, cmd.slot) end
            end
            if E.RefreshHero then E.RefreshHero(st, h) end
            E.Emit("equip", { id = h.id, owner = p })
            return true
        elseif cmd.type == "buy" then
            -- Bought gear goes straight on if there's room.
            local ok, why = Command(st, p, cmd)
            local h = st.ents[cmd.unit or 0]
            if ok and h and L.Wears(h) and h.items and h.items[#h.items] == cmd.item and L.FreeSlot(h, cmd.item) then
                table.remove(h.items)
                L.Give(st, h, cmd.item)
            end
            return ok, why
        elseif cmd.type == "dropItem" then
            local h = st.ents[cmd.unit or 0]
            if not (h and h.owner == p and E.IsHero(h)) then return false, "a hero drops it" end
            local key = h.items and h.items[cmd.slot or 0]
            if not key then return false, "nothing there" end
            table.remove(h.items, cmd.slot)
            L.Drop(st, { key }, h.x + 0.6, h.y + 0.4)
            h.dropped = { key = key, t = st.time } -- (not picked straight back up)
            if E.RefreshHero then E.RefreshHero(st, h) end
            E.Emit("dropItem", { id = h.id, owner = p, item = key })
            return true
        elseif cmd.type == "sellItem" then
            local h, shop = st.ents[cmd.unit or 0], st.ents[cmd.building or 0]
            if not (h and h.owner == p and E.IsHero(h)) then return false, "a hero sells" end
            if not (shop and E.Def(shop).sells) then return false, "sell at a merchant" end
            local cx, cy = E.Center(shop)
            if (h.x - cx) ^ 2 + (h.y - cy) ^ 2 > WC.SHOP_RANGE ^ 2 then return false, "bring the hero to the merchant" end
            local key = h.items and h.items[cmd.slot or 0]
            local it = key and WC.Items[key]
            if not it then return false, "nothing there" end
            table.remove(h.items, cmd.slot)
            local gold = math.floor((it.cost or 0) * 0.5)
            st.players[p].gold = st.players[p].gold + gold
            if E.RefreshHero then E.RefreshHero(st, h) end
            E.Emit("sellItem", { id = h.id, owner = p, item = key, gold = gold })
            return true
        end
        return Command(st, p, cmd)
    end
    -- Picking up: a hero next to an item, with room in the bag. (Melee
    -- games' creep camps do this themselves: Creeps.lua.)
    local World = E.WorldTick
    function E.WorldTick(st, dt)
        if World then World(st, dt) end
        if st.creeps or not st.items or #st.items == 0 then return end
        for i = #st.items, 1, -1 do
            local it = st.items[i]
            for _, id in ipairs(st.list) do
                local h = st.ents[id]
                if h and E.IsHero(h) and not h.illusion and not h.dead
                    and (#(h.items or {}) < 6 or L.FreeSlot(h, it.key))
                    and (h.x - it.x) ^ 2 + (h.y - it.y) ^ 2 <= 0.81
                    and not (h.dropped and h.dropped.key == it.key and st.time - h.dropped.t < 3) then
                    L.Give(st, h, it.key)
                    table.remove(st.items, i)
                    if E.RefreshHero then E.RefreshHero(st, h) end
                    E.Emit("pickup", { id = h.id, owner = h.owner, item = it.key })
                    break
                end
            end
        end
    end
end

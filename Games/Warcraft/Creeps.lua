-- Warcraft 4 creeps: neutral monster camps on the maps, as in Warcraft III.
-- They belong to a neutral player (one more seat after the real players,
-- hostile to everyone, never in the race to win). A camp stays put: its
-- creeps attack whoever comes close and walk home when led too far away.
-- Killing them gives heroes experience and the killer gold; the last one of
-- a camp drops an item that a hero picks up by walking over it.
--
-- Camps are marked on the maps (Maps.lua): "e" easy, "m" medium, "h" hard.
local ADDON, ns = ...

local WC = ns.WC
local E = WC.Engine
local U = WC.Units
local I = "Interface\\Icons\\"

-- The creeps: WoW's own (kobolds, gnolls, murlocs, wolves, Defias, ogres; Hogger).
local function Creep(t)
    t.attackType = t.attackType or "normal"
    t.armorType = t.armorType or "medium"
    t.cost, t.time, t.food, t.creep = { 0, 0 }, 0, 0, true
    return t
end
U.creep_kobold = Creep({ name = "Kobold", npc = 6, hp = 240, armor = 0, damage = 9, cooldown = 1.6, range = 1, speed = 2.4,
    level = 1, icon = I .. "INV_Misc_Head_Kobold_01" })
U.creep_wolf = Creep({ name = "Timber Wolf", npc = 299, hp = 260, armor = 1, damage = 10, cooldown = 1.3, range = 1, speed = 3.2,
    level = 2, icon = I .. "Ability_Hunter_Pet_Wolf" })
U.creep_gnoll = Creep({ name = "Gnoll Poacher", npc = 117, hp = 300, armor = 1, damage = 12, cooldown = 1.5, range = 4,
    speed = 2.5, level = 2, attackType = "pierce", icon = I .. "INV_Misc_Head_Gnoll_01" })
U.creep_murloc = Creep({ name = "Murloc Tiderunner", npc = 285, hp = 330, armor = 1, damage = 13, cooldown = 1.5, range = 1,
    speed = 2.6, level = 2, icon = I .. "INV_Misc_Head_Murloc_01" })
U.creep_thug = Creep({ name = "Defias Thug", npc = 38, hp = 480, armor = 2, damage = 17, cooldown = 1.5, range = 1, speed = 2.7,
    level = 3, icon = I .. "INV_Misc_Bandana_03" })
U.creep_ogre = Creep({ name = "Ogre Mauler", npc = 2253, hp = 900, armor = 3, damage = 27, cooldown = 1.8, range = 1, speed = 2.6,
    level = 5, armorType = "heavy", icon = I .. "INV_Misc_Head_Ogre_01" })
U.creep_hogger = Creep({ name = "Hogger", npc = 448, hp = 1300, armor = 4, damage = 34, cooldown = 1.6, range = 1, speed = 2.8,
    level = 6, armorType = "heavy", icon = I .. "INV_Misc_Head_Gnoll_01" })

-- What each kind of camp has, and what its last creep drops.
WC.CAMPS = {
    e = { level = "easy", creeps = { "creep_kobold", "creep_kobold", "creep_wolf" }, drops = { "healing_potion", "tome_xp" } },
    m = { level = "medium", creeps = { "creep_gnoll", "creep_thug", "creep_murloc", "creep_gnoll" },
        drops = { "ring", "claws", "mana_potion", "tome_xp" } },
    h = { level = "hard", creeps = { "creep_hogger", "creep_ogre", "creep_thug", "creep_gnoll" },
        drops = { "claws_9", "ring_3", "boots", "tome_xp_big" } },
}
-- Items only creeps drop (Tomes are used when picked up).
WC.Items.tome_xp = { name = "Tome of Experience", cost = 0, icon = I .. "INV_Misc_Book_09", use = "xp", amount = 100,
    onPickup = true, text = "The hero gains 100 experience." }
WC.Items.tome_xp_big = { name = "Tome of Greater Experience", cost = 0, icon = I .. "INV_Misc_Book_11", use = "xp", amount = 300,
    onPickup = true, text = "The hero gains 300 experience." }
WC.Items.claws_9 = { name = "Claws of Attack +9", cost = 0, icon = I .. "INV_Gauntlets_05", damage = 9, text = "+9 damage." }
WC.Items.ring_3 = { name = "Ring of Protection +3", cost = 0, icon = I .. "INV_Jewelry_Ring_04", armor = 3, text = "+3 armour." }

-- Neutral buildings: the Goblin Merchant (items for any hero next to it)
-- and the Mercenary Camp (creeps for hire, for anyone with a unit there).
WC.Derive("Buildings", "goblin_merchant", "arcane_vault", { name = "Goblin Merchant", requires = false, cost = { 0, 0 },
    sells = { "healing_potion", "mana_potion", "town_portal", "boots", "claws", "ring" }, neutral = true })
WC.Derive("Buildings", "mercenary_camp", "voodoo_lounge", { name = "Mercenary Camp", requires = false, cost = { 0, 0 },
    sells = false, hires = { "creep_gnoll", "creep_thug", "creep_murloc", "creep_ogre" }, neutral = true })
WC.MERC_COST = { creep_gnoll = 120, creep_thug = 175, creep_murloc = 140, creep_ogre = 340 }
WC.MERC_KEYS = { creep_gnoll = "G", creep_thug = "T", creep_murloc = "M", creep_ogre = "O" }

-- The map's neutral buildings (every melee game).
function E.SetupNeutrals(st, map)
    for _, s in ipairs(map.shops or {}) do E.SpawnBuilding(st, 0, "goblin_merchant", s[1], s[2], true) end
    for _, s in ipairs(map.mercs or {}) do E.SpawnBuilding(st, 0, "mercenary_camp", s[1], s[2], true) end
end

-- Hire a mercenary: one of your units next to the camp, and the gold.
function E.Hire(st, p, cmd)
    local b = st.ents[cmd.building]
    local d = b and E.Def(b)
    if not (d and d.hires) then return false, "not here" end
    local ok = false
    for _, ut in ipairs(d.hires) do if ut == cmd.utype then ok = true end end
    if not ok then return false, "not here" end
    local cx, cy = E.Center(b)
    local near
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "unit" and (e.x - cx) ^ 2 + (e.y - cy) ^ 2 <= WC.SHOP_RANGE ^ 2 then near = e break end
    end
    if not near then return false, "bring a unit next to the camp" end
    local cost = WC.MERC_COST[cmd.utype] or 200
    local pl = st.players[p]
    if pl.gold < cost then return false, "not enough gold" end
    local fx, fy = E.NearestFree(st, math.floor(cx), math.floor(b.y + b.size + 0.5))
    if not fx then return false, "no room" end
    pl.gold = pl.gold - cost
    local u = E.Spawn(st, p, cmd.utype, fx + 0.5, fy + 0.5)
    E.Emit("trained", { id = u.id, owner = p, type = u.type })
    E.Score(st, p, "made")
    E.Score(st, p, "mercs")
    E.Score(st, p, "madeValue", WC.MERC_COST[cmd.utype] or 0)
    return true
end

do
    local Command = E.Command
    function E.Command(st, p, cmd)
        if type(cmd) == "table" and cmd.type == "hire" then return E.Hire(st, p, cmd) end
        return Command(st, p, cmd)
    end
end

local AGGRO = 5     -- they come at you inside this many tiles of their camp
local LEASH = 9     -- and give up beyond this
local BOUNTY = 12   -- gold per creep level

-- Set up the camps (a new game on a map with camps).
function E.SetupCreeps(st, map)
    if not map.camps or #map.camps == 0 then return end
    local c = #st.players + 1
    st.players[c] = { faction = "creep", neutral = true, gold = 0, lumber = 0, food = 0, foodCap = 0, up = {}, busy = {} }
    st.creeps, st.camps, st.items = c, {}, st.items or {}
    for i, camp in ipairs(map.camps) do
        local def = WC.CAMPS[camp[3]]
        local cx, cy = camp[1] + 0.5, camp[2] + 0.5
        st.camps[i] = { x = cx, y = cy, kind = camp[3], left = #def.creeps }
        for k, ut in ipairs(def.creeps) do
            local a = (k - 1) / #def.creeps * math.pi * 2
            local fx, fy = E.NearestFree(st, math.floor(cx + math.cos(a) * 1.2), math.floor(cy + math.sin(a) * 1.2))
            if fx then
                local u = E.Spawn(st, c, ut, fx + 0.5, fy + 0.5)
                u.camp = i
                u.order = { type = "hold" }
                u.facing = a + math.pi
            end
        end
    end
end

function E.IsCreep(st, p) return st.creeps ~= nil and p == st.creeps end

-- Every step: creeps guard their camp; heroes pick up items.
function E.CreepTick(st, dt)
    if not st.creeps then return end
    st.creepT = (st.creepT or 0) + dt
    if st.creepT < 0.25 then return end
    st.creepT = 0
    for _, id in ipairs(st.list) do
        local u = st.ents[id]
        if u and u.owner == st.creeps and u.camp and not u.dead then
            local camp = st.camps[u.camp]
            local home2 = (u.x - camp.x) ^ 2 + (u.y - camp.y) ^ 2
            local o = u.order
            if o and o.type == "move" and o.home then
                -- Walking home: heal on the way, ignore fights.
                u.hp = math.min(u.maxHp, u.hp + u.maxHp * 0.05)
                if home2 < 2.5 then u.order = { type = "hold" } end
            elseif home2 > LEASH * LEASH then
                E.Order(st, u, { type = "move", x = camp.x, y = camp.y, home = true })
            elseif (not o or o.type == "hold") and (not E.IsNight(st) or u.hp < u.maxHp) then
                -- Whoever comes near the camp (the nearest one). At night they
                -- sleep, unless someone hurts them.
                local best, bd
                for _, id2 in ipairs(st.list) do
                    local e = st.ents[id2]
                    if e and E.Foe(st, u.owner, e.owner) and not e.dead and not (E.Hidden(e) or E.Untouchable(e))
                        and E.CanHit(st, u, e) then
                        local d = (e.x - camp.x) ^ 2 + (e.y - camp.y) ^ 2
                        if d <= AGGRO * AGGRO and (not bd or d < bd) then best, bd = e, d end
                    end
                end
                if best then E.Order(st, u, { type = "attack", target = best.id }) end
            end
        end
    end
    -- Items on the ground: a hero walking over one takes it (Tomes at once).
    for i = #st.items, 1, -1 do
        local it = st.items[i]
        for _, id in ipairs(st.list) do
            local h = st.ents[id]
            if h and E.IsHero(h) and not h.illusion and not h.dead and (h.x - it.x) ^ 2 + (h.y - it.y) ^ 2 <= 1 then
                local def = WC.Items[it.key]
                h.items = h.items or {}
                if def.onPickup then
                    if def.use == "xp" then E.GiveXp(st, h, def.amount) end
                    table.remove(st.items, i)
                    E.Emit("pickup", { id = h.id, owner = h.owner, item = it.key })
                    break
                elseif #h.items < 6 then
                    table.insert(h.items, it.key)
                    E.Score(st, h.owner, "items")
                    table.remove(st.items, i)
                    E.Emit("pickup", { id = h.id, owner = h.owner, item = it.key })
                    break
                end
            end
        end
    end
end

-- A creep died: gold for the killer; the camp's last one drops its item.
function E.CreepDied(st, t)
    if not (st.creeps and t.owner == st.creeps and t.camp) then return end
    local k = st.ents[t.lastHitBy or 0]
    local d = U[t.type]
    if k and st.players[k.owner] and not st.players[k.owner].neutral then
        local n = BOUNTY * (d.level or 1)
        st.players[k.owner].gold = st.players[k.owner].gold + n
        E.Emit("bounty", { owner = k.owner, amount = n, x = t.x, y = t.y })
    end
    local camp = st.camps[t.camp]
    camp.left = camp.left - 1
    if camp.left <= 0 and not camp.dropped then
        camp.dropped = true
        local drops = WC.CAMPS[camp.kind].drops
        local key = drops[st.rng % #drops + 1]
        st.rng = (st.rng * 16807) % 2147483647
        table.insert(st.items, { key = key, x = t.x, y = t.y })
        E.Emit("drop", { item = key, x = t.x, y = t.y })
    end
end

do
    local Death = E.OnDeath
    function E.OnDeath(st, t)
        if Death then Death(st, t) end
        E.CreepDied(st, t)
    end
    local World = E.WorldTick
    function E.WorldTick(st, dt)
        if World then World(st, dt) end
        E.CreepTick(st, dt)
    end
end

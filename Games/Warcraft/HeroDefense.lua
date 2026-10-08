-- Warcraft 4: Hero Defense, as Hero Siege (dev/research/hero_defense.md).
--
-- Everyone on one side: a castle in the middle of the map, four lanes into
-- it (west, north, east, south). Each player picks one hero at their altar
-- (any of the eight, free); waves of creeps come down every open lane on a
-- timer, fight the heroes and go for the castle. Only the west lane is open
-- at first: anyone can open more at the castle (for good), so a group can
-- hold one lane together, like a dungeon, or split up, one or two a lane.
-- Kills give gold (the killer most, everyone a share) for items at the
-- Goblin Merchant; fallen heroes come back at their altar by themselves.
-- Beat the last wave (a boss) and you win; lose the castle and you lose.
-- Near the castle your units heal quickly (its fountain).
local ADDON, ns = ...

local WC = ns.WC
local E = WC.Engine
local U, B = WC.Units, WC.Buildings
local I = "Interface\\Icons\\"

local HD = {
    key = "hd", name = "Hero Defense",
    text = "Everyone together: one hero each, a castle in the middle, waves of creeps down the lanes. "
        .. "Start with one lane; open more at the castle when you're ready. Lose the castle and it's over.",
    coop = true, solo = true, fullXp = true, -- (every hero near a kill gets all its experience)
    START_GOLD = 250, FIRST_WAVE = 45, WAVE_EVERY = 40, WAVES = 20, SPACING = 0.6, SHARE = 0.3,
    HEAL_RANGE = 7, HEAL = 0.03, -- (the castle's fountain: share of health a second, for your units close by)
    LANES = { "W", "N", "E", "S" },
    LANE_NAMES = { W = "West", N = "North", E = "East", S = "South" },
}
WC.Modes.hd = HD
table.insert(WC.MODE_ORDER, "hd")

---------------------------------------------------------------------------
-- The pieces (variants of the normal ones: same looks and sounds)
---------------------------------------------------------------------------
-- The heroes: the WoW classes (Classes.lua), up to level 25; an orc altar
-- shows the Horde looks.
HD.HEROES = WC.Classes.Heroes(false)
HD.HEROES_H = WC.Classes.Heroes(true)
-- The castle: tough, shoots back a little. Each player's altar: their hero.
WC.Derive("Buildings", "hd_castle", "castle", { name = "The Castle", hp = 10000, armor = 6, food = 0, hall = false,
    trains = false, hdCastle = true, requires = false, attack = { damage = 45, cooldown = 1, range = 8, type = "pierce" } })
WC.Derive("Buildings", "hd_altar", "altar_kings", { name = "Altar of Heroes", hp = 2000, cost = { 0, 0 }, time = 0, food = 10,
    trains = HD.HEROES, hdAltar = true, requires = false })
WC.Derive("Buildings", "hd_altar_orc", "altar_storms", { name = "Altar of Heroes", hp = 2000, cost = { 0, 0 }, time = 0, food = 10,
    trains = HD.HEROES_H, hdAltar = true, requires = false })
-- The merchant: potions, a few things to wear, a Tome of Experience; it
-- buys your loot too.
WC.Items.hd_tome = { name = "Tome of Experience", cost = 300, icon = I .. "INV_Misc_Book_09", use = "xp", amount = 600,
    text = "600 experience for the hero who reads it." }
WC.Derive("Buildings", "hd_merchant", "goblin_merchant", { name = "Merchant",
    sells = { "healing_potion", "mana_potion", "hd_tome", "claws", "ring", "boots" } })

-- The attackers.
local function Creep(key, base, over)
    over.hdCreep, over.cost, over.food, over.requires = true, { 0, 0 }, 0, false
    WC.Derive("Units", key, base, over)
end
-- (level: the experience they give - heroes here level fast, to about 20+ by
-- the last wave, as in Hero Siege)
Creep("hd_kobold", "creep_kobold", { level = 10 })
Creep("hd_wolf", "creep_wolf", { level = 10 })
Creep("hd_gnoll", "creep_gnoll", { level = 14 })
Creep("hd_murloc", "creep_murloc", { level = 14 })
Creep("hd_thug", "creep_thug", { level = 18 })
Creep("hd_ogre", "creep_ogre", { level = 25, hp = 650 })
-- Bosses from WoW's dungeons, every 4th wave; Onyxia last.
Creep("hd_hogger", "creep_hogger", { name = "Hogger", level = 40 })
Creep("hd_vancleef", "creep_thug", { name = "Edwin VanCleef", npc = 639, damage = 40, armor = 5, level = 50 })
Creep("hd_arugal", "creep_gnoll", { name = "Archmage Arugal", npc = 4275, damage = 45, range = 5, armor = 4, level = 55 })
Creep("hd_herod", "creep_ogre", { name = "Herod", npc = 3975, damage = 60, armor = 7, level = 65 })
Creep("hd_onyxia", "creep_ogre", { name = "Onyxia", npc = 10184, damage = 85, armor = 9, level = 80 })
HD.BOSSES = { [4] = { "hd_hogger", 1300 }, [8] = { "hd_vancleef", 2000 }, [12] = { "hd_arugal", 2600 },
    [16] = { "hd_herod", 3400 }, [20] = { "hd_onyxia", 5000 } }

-- What comes down each lane, by wave: soldiers by tier; a boss every 5th
-- wave; the Ogre Warlord on the last.
HD.TIERS = {
    { "hd_kobold" }, { "hd_kobold", "hd_wolf" }, { "hd_gnoll", "hd_wolf" }, { "hd_gnoll", "hd_murloc" },
    { "hd_thug", "hd_gnoll" }, { "hd_thug", "hd_murloc" }, { "hd_thug", "hd_thug", "hd_ogre" }, { "hd_ogre", "hd_thug" },
}

-- n: players, lanes: how many are open. Returns, per lane, a list of
-- { unit, health, damage x, bounty }, and the boss (on the first open lane)
-- if any. The group's share is spread over the open lanes: more lanes, more
-- creeps in all (more gold and experience), but fewer heroes in each.
function HD.Wave(w, n, lanes)
    lanes = lanes or 1
    local hpx = 0.55 * 1.13 ^ (w - 1) * (1 + 0.08 * (n - 1))
    local dmgx = 0.6 * 1.07 ^ (w - 1)
    local kinds = HD.TIERS[math.min(#HD.TIERS, math.floor((w - 1) / 2.5) + 1)]
    local count = math.min(12, 3 + 2 * math.ceil(n / lanes))
    local boss
    local b = HD.BOSSES[w]
    if b then
        count = math.ceil(count / 2) -- (a boss wave: fewer with it)
        local hp = 2 * b[2] * (0.6 + 0.4 * n) * (1 + w / 10)
        boss = { b[1], math.floor(hp), dmgx * 1.2, 60 + 15 * w }
    end
    local lane = {}
    for i = 1, count do
        local key = kinds[(i - 1) % #kinds + 1]
        table.insert(lane, { key, math.floor(U[key].hp * hpx), dmgx, 6 + 2 * w })
    end
    return lane, boss
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
-- The lanes' far ends (where creeps come in) on a map of w x h.
local function LaneStart(st, key)
    local cx, cy = math.floor(st.w / 2), math.floor(st.h / 2)
    if key == "W" then return 3, cy elseif key == "E" then return st.w - 4, cy
    elseif key == "N" then return cx, 3 else return cx, st.h - 4 end
end
HD.LaneStart = LaneStart

function HD.New(st, opts, map)
    local n = #st.players
    st.teams = {}
    for p = 1, n do st.teams[p] = 1 end -- (everyone on one side)
    local c = n + 1
    st.players[c] = { faction = "creep", neutral = true, gold = 0, lumber = 0, food = 0, foodCap = 0, up = {}, busy = {} }
    st.teams[c] = 2
    st.hd = { creeps = c, wave = 0, nextWave = HD.FIRST_WAVE, queue = {}, open = { W = true }, players = n }
    local castle = E.SpawnBuilding(st, 1, "hd_castle", math.floor(st.w / 2) - 2, math.floor(st.h / 2) - 2, true)
    st.hd.castle = castle.id
    for p = 1, n do
        local pl = st.players[p]
        local s = map.starts[opts.starts and opts.starts[p] or p]
        E.SpawnBuilding(st, p, pl.faction == "orc" and "hd_altar_orc" or "hd_altar", s[1], s[2], true)
        pl.gold, pl.lumber = HD.START_GOLD, 0
        pl.hd = {}
    end
    for _, sh in ipairs(map.shops or {}) do
        st.hd.shop = st.hd.shop or E.SpawnBuilding(st, 0, "hd_merchant", sh[1], sh[2], true).id
    end
end

local function Altar(st, p)
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "building" and B[e.type].hdAltar then return e end
    end
end
HD.Altar = Altar

local function Hero(st, p)
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and E.IsHero(e) and not e.illusion then return e end
    end
end
HD.Hero = Hero

---------------------------------------------------------------------------
-- Every step: waves, the creeps coming in, heroes back from the dead
---------------------------------------------------------------------------
function HD.Step(st, dt)
    local hd = st.hd
    if not hd then return end
    local castle = st.ents[hd.castle]
    if castle and st.time >= hd.nextWave and hd.wave < HD.WAVES then
        hd.wave = hd.wave + 1
        hd.nextWave = hd.nextWave + HD.WAVE_EVERY
        local lanes = 0
        for _ in pairs(hd.open) do lanes = lanes + 1 end
        local lane, boss = HD.Wave(hd.wave, hd.players, lanes)
        local t, first = st.time, nil
        for _, key in ipairs(HD.LANES) do
            if hd.open[key] then
                first = first or key
                for i, c in ipairs(lane) do
                    table.insert(hd.queue, { t = t + (i - 1) * HD.SPACING, lane = key, unit = c[1], hp = c[2], dmg = c[3], bounty = c[4] })
                end
            end
        end
        if boss then
            table.insert(hd.queue, { t = t + #lane * HD.SPACING, lane = first, unit = boss[1], hp = boss[2], dmg = boss[3],
                bounty = boss[4], boss = true })
        end
        E.Emit("hdWave", { wave = hd.wave, boss = boss and U[boss[1]].name })
    end
    local keep = {}
    for _, s in ipairs(hd.queue) do
        if st.time >= s.t and castle then
            local sx, sy = LaneStart(st, s.lane)
            local x, y = E.NearestFree(st, sx, sy)
            if x then
                local u = E.Spawn(st, hd.creeps, s.unit, x + 0.5, y + 0.5)
                u.maxHp, u.hp, u.dmgMul, u.hdBounty, u.hdBoss = s.hp, s.hp, s.dmg, s.bounty, s.boss
                local cx, cy = E.Center(castle)
                E.Order(st, u, { type = "attackMove", x = cx, y = cy })
            end
        else
            table.insert(keep, s)
        end
    end
    hd.queue = keep
    -- A creep with nothing to do (lost its fight away from the castle) heads
    -- for the castle again, so no wave can stall.
    hd.idleT = (hd.idleT or 0) + dt
    if castle and hd.idleT >= 5 then
        hd.idleT = 0
        local cx, cy = E.Center(castle)
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and e.owner == hd.creeps and not e.order then E.Order(st, e, { type = "attackMove", x = cx, y = cy }) end
        end
    end
    -- The castle's fountain: your units close to it heal quickly.
    if castle then
        local cx, cy = E.Center(castle)
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and e.kind == "unit" and e.owner ~= hd.creeps and e.hp < e.maxHp
                and (e.x - cx) ^ 2 + (e.y - cy) ^ 2 <= HD.HEAL_RANGE * HD.HEAL_RANGE then
                e.hp = math.min(e.maxHp, e.hp + e.maxHp * HD.HEAL * dt)
            end
        end
    end
    -- A fallen hero comes back at its altar by itself.
    for p = 1, hd.players do
        local pl = st.players[p]
        local altar = Altar(st, p)
        for ut, f in pairs(pl.fallen or {}) do
            if altar and not f.reviving then
                f.reviving = true
                table.insert(altar.queue, 1, "v:" .. ut)
            end
        end
    end
end

-- Over: the castle fell (everyone loses), or the last wave is beaten.
function HD.Over(st)
    local hd = st.hd
    if not hd then return false end
    if not st.ents[hd.castle] then return true, 0 end
    if hd.wave >= HD.WAVES and #hd.queue == 0 then
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and e.owner == hd.creeps then return false end
        end
        return true, 1
    end
    return false
end

-- Kills: the killer gets the bounty, everyone else a share.
function HD.OnDeath(st, t)
    local hd = st.hd
    if not (hd and t.owner == hd.creeps and t.hdBounty) then return end
    local k = st.ents[t.lastHitBy or 0]
    local killer = k and k.owner
    for p = 1, hd.players do
        local n = p == killer and t.hdBounty or math.floor(t.hdBounty * HD.SHARE)
        if n > 0 then
            st.players[p].gold = st.players[p].gold + n
            if p == killer then E.Emit("bounty", { owner = p, amount = n, x = t.x, y = t.y }) end
        end
    end
    if t.hdBoss then E.Emit("hdBoss", { name = U[t.type].name }) end
    -- Loot, where it fell.
    local drops = WC.Loot.Roll(st, hd.wave, t.type)
    if #drops > 0 then
        WC.Loot.Drop(st, drops, t.x, t.y)
        E.Emit("loot", { x = t.x, y = t.y, n = #drops, boss = t.hdBoss })
    end
end

-- The altars are holy ground: creeps leave them be (and your hero's way back).
function HD.CanHit(st, a, t)
    if t.kind == "building" and B[t.type] and B[t.type].hdAltar then return false end
    return true
end

---------------------------------------------------------------------------
-- Commands: open a lane (anyone), one hero each
---------------------------------------------------------------------------
function HD.Command(st, p, cmd)
    local hd = st.hd
    if not hd then return end
    if cmd.type == "hdLane" then
        local key = cmd.lane
        if not HD.LANE_NAMES[key] then return false, "no such lane" end
        if hd.open[key] then return false, "it's open already" end
        if not (st.players[p] and not st.players[p].neutral) then return false, "not a player" end
        hd.open[key] = true
        E.Emit("hdLane", { lane = key, owner = p })
        return true
    elseif cmd.type == "train" and U[cmd.utype] and U[cmd.utype].class then
        local pl = st.players[p]
        if Hero(st, p) or (pl.fallen and next(pl.fallen)) then return false, "one hero each" end
        local altar = st.ents[cmd.building or 0]
        for _, q in ipairs(altar and altar.queue or {}) do
            local ut = q:match("^v:(.+)$") or q
            if U[ut] and U[ut].hero then return false, "one hero each" end
        end
    elseif cmd.type == "gather" then
        return false, "nothing to gather here"
    end
end

-- What the computer buys, in order (gear goes on; potions in the bag).
HD.AI_ITEMS = { "ring", "claws", "boots", "healing_potion", "healing_potion", "healing_potion" }

---------------------------------------------------------------------------
-- The computer: picks a hero, holds a lane (the open ones shared out by
-- seat), learns and casts, goes home to heal when hurt.
---------------------------------------------------------------------------
function HD.Think(st, p)
    local hd = st.hd
    local pl = st.players[p]
    if not hd or pl.neutral then return end
    st.ai = st.ai or {}
    local mem = st.ai[p] or {}
    st.ai[p] = mem
    local altar = Altar(st, p)
    local hero = Hero(st, p)
    if not hero then
        if altar and #altar.queue == 0 and not (pl.fallen and next(pl.fallen)) then
            local list = B[altar.type].trains
            E.Command(st, p, { type = "train", building = altar.id, utype = list[(p * 3 + 1) % #list + 1] })
        end
        return
    end
    WC.AI.Learn(st, p, hero)
    WC.AI.HeroCast(st, p, hero)
    -- Wear the best: something in the bag that beats what's worn goes on.
    local Loot = WC.Loot
    for i, key in ipairs(hero.items or {}) do
        local it = WC.Items[key]
        if it and it.slot then
            local better = Loot.FreeSlot(hero, key) ~= nil
            for gi, kind in ipairs(Loot.GEAR) do
                if kind == it.slot and Loot.Score(hero.gear and hero.gear[gi]) < Loot.Score(key) then better = true end
            end
            if better and E.Command(st, p, { type = "equip", unit = hero.id, slot = i }) then break end
        end
    end
    -- A potion when badly hurt.
    if hero.hp < hero.maxHp * 0.35 then
        for i, key in ipairs(hero.items or {}) do
            if key == "healing_potion" then E.Command(st, p, { type = "useItem", unit = hero.id, slot = i }) break end
        end
    end
    local castle = st.ents[hd.castle]
    if not castle then return end
    local cx, cy = E.Center(castle)
    -- Hurt: back to the castle until healed up.
    if hero.hp < hero.maxHp * 0.3 then mem.home = true end
    if mem.home and hero.hp > hero.maxHp * 0.8 then mem.home = false end
    if mem.home then
        -- (fight by the castle while the fountain heals)
        local dx, dy = hero.x - cx, hero.y - cy
        if dx * dx + dy * dy > (HD.HEAL_RANGE - 2) ^ 2 and not (hero.order and hero.order.type == "move") then
            E.Command(st, p, { type = "move", units = { hero.id }, x = cx, y = cy + 3 })
        elseif not hero.order then
            E.Command(st, p, { type = "attackMove", units = { hero.id }, x = cx, y = cy + 3 })
        end
        return
    end
    -- Shopping, with gold to spare: the next item on the list.
    local shop = st.ents[hd.shop or 0]
    local want = HD.AI_ITEMS[(mem.bought or 0) + 1]
    if want and WC.Items[want].use and #(hero.items or {}) >= 6 then want = nil end -- (no room for it)
    if shop and want and pl.gold >= WC.Items[want].cost then
        local sx, sy = E.Center(shop)
        if (hero.x - sx) ^ 2 + (hero.y - sy) ^ 2 <= (WC.SHOP_RANGE - 1) ^ 2 then
            if E.Command(st, p, { type = "buy", building = shop.id, unit = hero.id, item = want }) then
                mem.bought = (mem.bought or 0) + 1
            end
        elseif not (hero.order and hero.order.type == "move") then
            E.Command(st, p, { type = "move", units = { hero.id }, x = sx + 1, y = sy + 3 })
        end
        return
    end
    -- My lane: the open lanes shared out by seat; stand a little way down it.
    local open = {}
    for _, key in ipairs(HD.LANES) do if hd.open[key] then table.insert(open, key) end end
    local key = open[(p - 1) % #open + 1]
    local lx, ly = LaneStart(st, key)
    local gx, gy = cx + (lx - cx) * 0.45, cy + (ly - cy) * 0.45
    if not hero.order or (st.time - (mem.sentAt or -99) > 10 and hero.order.type ~= "attack") then
        mem.sentAt = st.time
        E.Command(st, p, { type = "attackMove", units = { hero.id }, x = gx, y = gy })
    end
end

-- The top bar: the castle's health instead of lumber; the next wave and the
-- open lanes instead of food.
function HD.Panel(st, p)
    local hd = st.hd
    local castle = st.ents[hd.castle]
    local hp = castle and math.floor(castle.hp) or 0
    local lanes = 0
    for _ in pairs(hd.open) do lanes = lanes + 1 end
    local wave = hd.wave >= HD.WAVES and ("Last wave (" .. HD.WAVES .. ")")
        or string.format("Wave %d/%d in %ds", hd.wave + 1, HD.WAVES, math.max(0, math.ceil(hd.nextWave - st.time)))
    return "Castle " .. hp, wave .. "   " .. lanes .. (lanes == 1 and " lane" or " lanes"),
        castle and castle.hp < castle.maxHp * 0.3
end

-- Warcraft 4 game modes: Melee (the normal game) and custom games built on
-- the same units. A mode only says what's different: how players start, what
-- happens every step, kills, commands, the computer's play.
--
-- Variants (WC.Derive): a mode's unit or building is the normal one with a
-- few things changed (health, cost, what it trains). Everything else - its
-- model, size, sounds, spell effects, icon - comes from the normal one, so a
-- change there shows in every mode. WC.BaseOf(type) gives the normal one.
local ADDON, ns = ...

local WC = ns.WC
local E = WC.Engine
local U, B, R = WC.Units, WC.Buildings, WC.Research

WC.Modes = {}
WC.MODE_ORDER = { "melee", "footmen" }

function WC.Mode(st) return WC.Modes[st and st.mode or "melee"] or WC.Modes.melee end

WC.Modes.melee = { key = "melee", name = "Melee", text = "The normal game: a hall, workers and a gold mine. Build up and destroy every enemy building." }

---------------------------------------------------------------------------
-- Footmen Frenzy: one fortified barracks each, no workers. It spawns your
-- tier's unit every few seconds and sends them out; gold comes from kills
-- and buys tiers, weapon and armour levels, and one hero. Last barracks
-- standing wins. (dev/research/footmen.md)
---------------------------------------------------------------------------
local F = {
    key = "footmen", name = "Footmen Frenzy",
    text = "One barracks each, no workers: it sends out soldiers by itself. Kills give gold: buy better soldiers, "
        .. "upgrades and a hero. The last barracks standing wins.",
    START_GOLD = 2000, HERO_COST = 1900, CAP = 40, RESEND = 6,
}
WC.Modes.footmen = F
F.HEROES = { "paladin", "archmage", "mountain_king", "blood_mage", "blademaster", "far_seer", "tauren_chieftain",
    "shadow_hunter" }
-- What the barracks sends out, per race and tier: the unit, how often (s),
-- how many at a time.
F.TIERS = {
    human = { { unit = "footman", every = 10 }, { unit = "rifleman", every = 11 }, { unit = "knight", every = 12 },
        { unit = "gryphon_rider", every = 14 } },
    orc = { { unit = "grunt", every = 10 }, { unit = "headhunter", every = 10 }, { unit = "raider", every = 12 },
        { unit = "tauren", every = 14 } },
}

-- The heroes, for gold only (from the barracks: one per player).
local ffHeroes = {}
for _, h in ipairs(F.HEROES) do
    WC.Derive("Units", "ff_" .. h, h, { cost = { F.HERO_COST, 0 }, reviveCost = 700, time = 5 })
    table.insert(ffHeroes, "ff_" .. h)
end
F.HERO_UNITS = ffHeroes

-- The barracks: tough, no lumber, trains the heroes and revives them.
for _, race in ipairs({ "human", "orc" }) do
    local key = race == "human" and "ff_barracks" or "ff_orc_barracks"
    WC.Derive("Buildings", key, race == "human" and "barracks" or "orc_barracks", {
        name = "Frenzy Barracks", hp = 15000, armor = 10, armorType = "fortified", cost = { 0, 0 }, time = 0,
        attack = { damage = 40, cooldown = 1, range = 8, type = "pierce" }, -- it defends itself
        food = 200, trains = ffHeroes, requires = nil, ffRace = race })
    -- Its upgrades: soldiers' tier, weapons, armour.
    local names = race == "human" and { "Riflemen", "Knights", "Gryphon Riders" } or { "Headhunters", "Raiders", "Tauren" }
    R["ff_tier_" .. race] = { names = { "Train " .. names[1], "Train " .. names[2], "Train " .. names[3] }, building = key,
        hotkey = "T", levels = 3, cost = { { 500, 0 }, { 1200, 0 }, { 2200, 0 } }, time = { 10, 15, 20 },
        minTime = { 180, 420, 720 }, effect = {}, icon = race == "human" and "Interface\\Icons\\INV_Helmet_08"
            or "Interface\\Icons\\INV_Helmet_01",
        text = "Your barracks sends out stronger soldiers." }
    R["ff_weapons_" .. race] = { names = { "Weapons 1", "Weapons 2", "Weapons 3", "Weapons 4", "Weapons 5" }, building = key,
        hotkey = "W", levels = 5, cost = { { 300, 0 }, { 600, 0 }, { 900, 0 }, { 1200, 0 }, { 1500, 0 } },
        time = { 15, 20, 25, 30, 35 }, effect = { melee = 0.1, ranged = 0.1 }, icon = "Interface\\Icons\\INV_Sword_04",
        text = "Your soldiers deal 10% more damage." }
    R["ff_armor_" .. race] = { names = { "Armor 1", "Armor 2", "Armor 3", "Armor 4", "Armor 5" }, building = key,
        hotkey = "A", levels = 5, cost = { { 300, 0 }, { 600, 0 }, { 900, 0 }, { 1200, 0 }, { 1500, 0 } },
        time = { 15, 20, 25, 30, 35 }, effect = { armor = 1 }, icon = "Interface\\Icons\\INV_Shield_05",
        text = "Your units get 1 more armour." }
    for _, k in ipairs({ "ff_tier_", "ff_weapons_", "ff_armor_" }) do table.insert(WC.AI.RESEARCH, k .. race) end
end

local function Barracks(st, p)
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "building" and E.Def(e).ffRace then return e end
    end
end
F.Barracks = Barracks

-- Start: a barracks on each start, the shops, the trees. No mines, no workers.
function F.New(st, opts, map)
    for p, pl in ipairs(st.players) do
        local s = map.starts[opts.starts and opts.starts[p] or p]
        local key = pl.faction == "orc" and "ff_orc_barracks" or "ff_barracks"
        E.SpawnBuilding(st, p, key, s[1], s[2], true)
        pl.gold, pl.lumber = F.START_GOLD, 0
        pl.ff = { next = 5 } -- target nil: the rally point (or stay home)
    end
    for _, sh in ipairs(map.shops or {}) do E.SpawnBuilding(st, 0, "arcane_vault", sh[1], sh[2], true) end
end

-- Where a player's soldiers go: an enemy's barracks (Send to), else the
-- barracks' rally point; nil: they wait at home.
local function Goal(st, p)
    local t = st.players[p].ff.target
    if t == 0 then return st.w / 2, st.h / 2 end
    if t and t > 0 then
        local b = Barracks(st, t)
        if b and E.Foe(st, p, t) then return E.Center(b) end
    end
    local home = Barracks(st, p)
    if home and home.rally then return home.rally.x, home.rally.y end
end
F.Goal = Goal

local function Soldiers(st, p)
    local n, idle = 0, {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "unit" and not E.IsHero(e) and not e.dead then
            n = n + 1
            if not e.order then table.insert(idle, e.id) end
        end
    end
    return n, idle
end

-- Every step: barracks send out soldiers; idle soldiers march on; a player
-- whose barracks fell loses what's left.
function F.Step(st, dt)
    for p, pl in ipairs(st.players) do
        local ff = pl.ff
        if ff then
            local b = Barracks(st, p)
            if not b then
                if not ff.gone then
                    ff.gone = true
                    local left = {}
                    for _, id in ipairs(st.list) do
                        local e = st.ents[id]
                        if e and e.owner == p then table.insert(left, e) end
                    end
                    for _, e in ipairs(left) do E.Remove(st, e) end
                end
            else
                -- A fallen hero comes back by itself (free, after a while).
                for _, ut in ipairs(ffHeroes) do
                    local f = pl.fallen and pl.fallen[ut]
                    if f and not f.reviving then
                        f.reviving = true
                        table.insert(b.queue, 1, "v:" .. ut)
                    end
                end
                local tier = E.Level(st, p, "ff_tier_" .. E.Def(b).ffRace) + 1
                local spec = F.TIERS[E.Def(b).ffRace][tier]
                if st.time >= ff.next then
                    ff.next = st.time + spec.every
                    local n = Soldiers(st, p)
                    if n < F.CAP then
                        local x, y = E.NearestFree(st, math.floor(b.x + 1), math.floor(b.y + b.size + 1))
                        local u = E.Spawn(st, p, spec.unit, x + 0.5, y + 0.5)
                        local gx, gy = Goal(st, p)
                        if gx then E.Command(st, p, { type = "attackMove", units = { u.id }, x = gx, y = gy }) end
                    end
                end
                -- Sent at an enemy: idle soldiers march on (at a rally point they wait).
                ff.resend = (ff.resend or 0) + dt
                if ff.resend >= F.RESEND and ff.target then
                    ff.resend = 0
                    local _, idle = Soldiers(st, p)
                    local gx, gy = Goal(st, p)
                    if #idle > 0 and gx then
                        E.Command(st, p, { type = "attackMove", units = idle, x = gx, y = gy })
                    end
                end
            end
        end
    end
end

-- Gold for kills: about a quarter of what the unit costs, 250 for a hero.
function F.Bounty(t)
    if t.kind ~= "unit" then return 0 end
    if E.IsHero(t) then return 250 end
    local d = U[t.type]
    return math.max(8, math.floor((d.cost and d.cost[1] or 0) * 0.25 + 0.5))
end

function F.OnDeath(st, t)
    local k = st.ents[t.lastHitBy or 0]
    if not k or not E.Foe(st, k.owner, t.owner) then return end
    local n = F.Bounty(t)
    if n > 0 then
        st.players[k.owner].gold = st.players[k.owner].gold + n
        E.Emit("bounty", { owner = k.owner, amount = n, x = t.x, y = t.y })
    end
end

-- "Send to": where your soldiers go: an enemy's seat, 0 the middle,
-- "rally" (or nothing) the rally point.
function F.Command(st, p, cmd)
    if cmd.type == "sendTo" then
        local t = tonumber(cmd.target)
        if t and t ~= 0 and not (st.players[t] and E.Foe(st, p, t)) then return false, "not an enemy" end
        st.players[p].ff.target = t
        return true
    end
end

-- The computer: a hero first, then tiers, weapons and armour; it sends its
-- soldiers at the nearest enemy and its hero with them.
function F.Think(st, p)
    local pl = st.players[p]
    local b = Barracks(st, p)
    if not b or not pl.ff then return end
    local race = E.Def(b).ffRace
    st.ai = st.ai or {}
    local mem = st.ai[p] or {}
    st.ai[p] = mem
    -- A hero (the same one each game for this seat), or revive it.
    local hero
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and E.IsHero(e) and not e.illusion then hero = e end
    end
    if not hero then
        local pick = ffHeroes[(p * 3 + #st.players) % #ffHeroes + 1]
        local fallen = pl.fallen and pl.fallen[pick]
        if not fallen and #b.queue == 0 then
            E.Command(st, p, { type = "train", building = b.id, utype = pick })
        end
    else
        WC.AI.Learn(st, p, hero)
        WC.AI.HeroCast(st, p, hero)
    end
    -- Spend: tier when it can, else weapons and armour in turn, keeping
    -- enough for the hero when it's gone.
    local reserve = 0
    if not hero and #b.queue == 0 and not (pl.fallen and next(pl.fallen)) then reserve = F.HERO_COST end
    if #b.queue == 0 and pl.gold > reserve then
        local order = { "ff_tier_" .. race, mem.flip and "ff_armor_" .. race or "ff_weapons_" .. race,
            mem.flip and "ff_weapons_" .. race or "ff_armor_" .. race }
        for _, key in ipairs(order) do
            local r = R[key]
            local lv = E.Level(st, p, key) + 1
            if lv <= r.levels and pl.gold >= r.cost[lv][1] + 150 + reserve and E.CanResearch(st, p, key, b) then
                if E.Command(st, p, { type = "research", building = b.id, key = key }) then
                    mem.flip = not mem.flip
                    break
                end
            end
        end
    end
    -- Send at the nearest enemy still standing.
    local bx, by = E.Center(b)
    local best, bd
    for q = 1, #st.players do
        local eb = E.Foe(st, p, q) and Barracks(st, q)
        if eb then
            local x, y = E.Center(eb)
            local d = (x - bx) ^ 2 + (y - by) ^ 2
            if not bd or d < bd then best, bd = q, d end
        end
    end
    -- (The first minutes: hold the middle.)
    if best and pl.ff.target ~= best and st.time > 300 then F.Command(st, p, { type = "sendTo", target = best })
    elseif pl.ff.target == nil and st.time <= 300 then F.Command(st, p, { type = "sendTo", target = 0 }) end
    -- The hero goes with the army (home when hurt).
    if hero and not hero.order then
        local gx, gy = Goal(st, p)
        if hero.hp < hero.maxHp * 0.3 then gx, gy = bx, by + 3 end
        E.Command(st, p, { type = "attackMove", units = { hero.id }, x = gx, y = gy })
    end
end

---------------------------------------------------------------------------
-- Hooks into the engine (a mode's New, Step, OnDeath, Command, Think).
---------------------------------------------------------------------------
do
    local Death = E.OnDeath
    function E.OnDeath(st, t)
        if Death then Death(st, t) end
        local M = WC.Mode(st)
        if M.OnDeath then M.OnDeath(st, t) end
    end
    local World = E.WorldTick
    function E.WorldTick(st, dt)
        if World then World(st, dt) end
        local M = WC.Mode(st)
        if M.Step then M.Step(st, dt) end
    end
    local Command = E.Command
    function E.Command(st, p, cmd)
        local M = WC.Mode(st)
        if M.Command and type(cmd) == "table" then
            local ok, why = M.Command(st, p, cmd)
            if ok ~= nil then return ok, why end
        end
        return Command(st, p, cmd)
    end
    local Think = WC.AI.Think
    function WC.AI.Think(st, p)
        local M = WC.Mode(st)
        if M.Think then return M.Think(st, p) end
        return Think(st, p)
    end
end

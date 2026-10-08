-- Warcraft 4: Tower Defense, as Line Tower Wars (dev/research/tower_defense.md).
--
-- Every player has a lane (the maps: Maps.lua, mode "td"). Creeps come in
-- at the top of every lane in waves on a timer and walk to the exit at the
-- bottom; each one that gets out costs that player lives. A flying builder
-- puts towers anywhere in your own lane (never so they close the path), and
-- you upgrade or sell them. Gold comes from kills and an income paid every
-- few seconds; "sends" put extra creeps into the next opponent's lane and
-- raise your income for good. Out of lives: your gate falls and you're out.
-- Last player (or team) standing wins. Towers only shoot creeps in their own
-- lane, so nobody can hurt anybody else's towers.
--
-- Built on the normal game's pieces: the towers, flyers and creatures are
-- variants (WC.Derive) of the normal ones, so they look and sound the same.
local ADDON, ns = ...

local WC = ns.WC
local E = WC.Engine
local U, B, R = WC.Units, WC.Buildings, WC.Research
local I = "Interface\\Icons\\"
local ATAN2 = math.atan2 or math.atan

local TD = {
    key = "td", name = "Tower Defense",
    text = "Line Tower Wars: a lane each. Build a maze of towers; every creep that gets through costs a life. "
        .. "Send creeps into the next player's lane to raise your income. The last one with lives wins.",
    LANE_W = 10, SPAWN_Y = 2, BUILD_Y0 = 5, EXIT_Y = 33, -- (the maps: dev/make_maps.py)
    START_GOLD = 250, LIVES = 20, INCOME = 20, PAY_EVERY = 15,
    FIRST_WAVE = 40, WAVE_EVERY = 35, SPACING = 0.8,
    noFog = true, -- (every lane in sight, as in Line Tower Wars)
    solo = true,  -- (alone: no sends, hold out as long as you can)
}
WC.Modes.td = TD
table.insert(WC.MODE_ORDER, "td")

---------------------------------------------------------------------------
-- The pieces
---------------------------------------------------------------------------
-- The builder: flies, can't be hurt, puts towers down at once.
WC.Derive("Units", "td_builder", "gryphon_rider", { name = "Builder", worker = true, tdBuilder = true, speed = 7,
    cost = { 0, 0 }, food = 0, requires = false })
WC.Derive("Units", "td_builder_orc", "wind_rider", { name = "Builder", worker = true, tdBuilder = true, speed = 7,
    cost = { 0, 0 }, food = 0, requires = false })

-- Your gate at the end of your lane: your lives. It falls when they run out.
WC.Derive("Buildings", "td_gate", "town_hall", { name = "Gate", hall = false, trains = false, garrison = false, food = 0,
    cost = { 0, 0 }, time = 0, hp = 5000, tdGate = true, requires = false })
WC.Derive("Buildings", "td_gate_orc", "great_hall", { name = "Gate", hall = false, trains = false, garrison = false, food = 0,
    cost = { 0, 0 }, time = 0, hp = 5000, tdGate = true, requires = false })

-- Towers: three levels each (an upgrade turns one into the next), and a
-- cheap wall for the maze. Gold only.
TD.TOWERS = {
    { kind = "arrow", base = "guard_tower", name = "Arrow Tower", hotkey = "A", icon = I .. "INV_Weapon_Bow_07",
        text = "Fast arrows at one creep. Hits flyers.",
        levels = { { 60, 14 }, { 110, 34 }, { 220, 80 } }, attack = { cooldown = 0.8, range = 6.5, type = "pierce" } },
    { kind = "cannon", base = "cannon_tower", name = "Cannon Tower", hotkey = "C", icon = I .. "INV_Misc_Bomb_08",
        text = "Slow shells that hit a group. Ground only.",
        levels = { { 90, 35 }, { 160, 85 }, { 320, 200 } },
        attack = { cooldown = 2, range = 5.5, type = "siege", splash = 1.5, groundOnly = true } },
    { kind = "frost", base = "arcane_tower", name = "Frost Tower", hotkey = "F", icon = I .. "Spell_Frost_FrostNova",
        text = "Slows what it hits for 2.5 seconds. Hits flyers.",
        levels = { { 80, 10 }, { 150, 24 }, { 280, 55 } }, attack = { cooldown = 1.1, range = 5.5, type = "magic", slow = 2.5 } },
    { kind = "wall", base = "scout_tower", name = "Maze Wall", hotkey = "W", icon = I .. "INV_Stone_15",
        text = "No attack: a cheap block for your maze.", levels = { { 10 } } },
}
TD.BUILDS = {}  -- what the builder offers (level 1 of each)
TD.VALUE = {}   -- gold put into a tower of each type (for selling)
for _, t in ipairs(TD.TOWERS) do
    local spent = 0
    for lv, l in ipairs(t.levels) do
        local key = "td_" .. t.kind .. (lv > 1 and lv or "")
        spent = spent + l[1]
        local attack
        if l[2] then
            attack = { damage = l[2] }
            for k, v in pairs(t.attack) do attack[k] = v end
        end
        WC.Derive("Buildings", key, t.base, { name = t.name .. (lv > 1 and (" " .. lv) or ""), hotkey = t.hotkey,
            icon = t.icon, cost = { l[1], 0 }, time = 0, hp = 400 + lv * 200, armor = 5, food = 0, requires = false,
            attack = attack or false, detects = false, tdTower = true, tdKind = t.kind, tdLevel = lv, tdText = t.text })
        TD.VALUE[key] = spent
        if lv == 1 then table.insert(TD.BUILDS, key) end
        if lv > 1 then
            local from = "td_" .. t.kind .. (lv > 2 and (lv - 1) or "")
            R["td_up_" .. t.kind .. lv] = { name = "Upgrade to " .. t.name .. " " .. lv, building = from, upgrade = key,
                hotkey = "U", levels = 1, cost = { { l[1], 0 } }, time = { 2 }, icon = t.icon,
                text = string.format("%d damage (from %d).", l[2], t.levels[lv - 1][2]) }
            table.insert(WC.AI.RESEARCH, "td_up_" .. t.kind .. lv) -- (the command card lists it)
        end
    end
end

-- The creeps (the neutral side): WoW's own creatures, a little changed.
-- Health comes from the wave (TD.Health), so it's not set here.
local function Creep(key, base, over)
    over.tdCreep, over.cost, over.food, over.requires = true, { 0, 0 }, 0, false
    WC.Derive("Units", key, base, over)
end
Creep("td_kobold", "creep_kobold", { name = "Kobold", speed = 2.4, armor = 0, armorType = "unarmored" })
Creep("td_gnoll", "creep_gnoll", { name = "Gnoll", speed = 2.4, armor = 1, armorType = "light" })
Creep("td_murloc", "creep_murloc", { name = "Murloc", speed = 2.6, armor = 1, armorType = "medium" })
Creep("td_thug", "creep_thug", { name = "Defias Thug", speed = 2.3, armor = 3, armorType = "heavy" })
Creep("td_ogre", "creep_ogre", { name = "Ogre", speed = 2.0, armor = 3, armorType = "heavy" })
Creep("td_wolf", "creep_wolf", { name = "Timber Wolf", speed = 3.8, armor = 0, armorType = "light" })
Creep("td_hawk", "dragonhawk_rider", { name = "Dragonhawk", speed = 2.6, armor = 0, armorType = "light" })
Creep("td_hogger", "creep_hogger", { name = "Hogger", speed = 1.9, armor = 5, armorType = "heavy" })

-- A creep's health on wave w (about 15% more each wave).
function TD.Health(w)
    return math.floor(45 * 1.15 ^ (math.max(1, w) - 1) + 0.5)
end

-- What wave w sends down every lane: { unit, how many, health, lives a leak costs, bounty }.
local GROUND = { "td_kobold", "td_gnoll", "td_murloc", "td_thug", "td_ogre" }
function TD.Wave(w)
    local hp, bounty = TD.Health(w), 2 + math.floor(w / 3)
    if w % 10 == 0 then -- a boss, with a few guards
        return { { "td_hogger", 1, hp * 12, 5, 20 + w }, { "td_thug", 4, hp, 1, bounty } }
    elseif w % 10 == 5 then -- flyers: they go straight over the maze
        return { { "td_hawk", 8, math.floor(hp * 0.8), 1, bounty } }
    elseif w % 10 == 7 then -- fast
        return { { "td_wolf", 12, math.floor(hp * 0.6), 1, bounty } }
    end
    return { { GROUND[math.floor((w - 1) / 2) % #GROUND + 1], 10, hp, 1, bounty } }
end

-- Sends: gold for a creep in the next opponent's lane, and income for good.
TD.SENDS = {
    { unit = "td_kobold", cost = 15, income = 1, hp = 0.8, hotkey = "Q" },
    { unit = "td_wolf", cost = 30, income = 2, hp = 0.7, hotkey = "W" },
    { unit = "td_thug", cost = 60, income = 3, hp = 1.6, hotkey = "E" },
    { unit = "td_hawk", cost = 90, income = 4, hp = 1.2, hotkey = "R" },
    { unit = "td_ogre", cost = 160, income = 7, hp = 3.5, hotkey = "A" },
    { unit = "td_hogger", cost = 400, income = 15, hp = 8, hotkey = "S", lives = 3 },
}

---------------------------------------------------------------------------
-- Lanes
---------------------------------------------------------------------------
local function Lane(st, p) return st.td and st.td.lanes[p] end
TD.Lane = Lane

local function Alive(st, p)
    local pl = st.players[p]
    return pl and pl.td and pl.td.lives > 0
end
TD.Alive = Alive

-- Start: a gate at the end of each player's lane and a builder; the creeps'
-- own (neutral) side.
function TD.New(st, opts, map)
    local c = #st.players + 1
    st.players[c] = { faction = "creep", neutral = true, gold = 0, lumber = 0, food = 0, foodCap = 0, up = {}, busy = {} }
    st.td = { lanes = {}, wave = 0, nextWave = TD.FIRST_WAVE, nextPay = TD.PAY_EVERY, queue = {}, flow = {}, creeps = c }
    for p = 1, c - 1 do
        local pl = st.players[p]
        local s = map.starts[opts.starts and opts.starts[p] or p]
        local x0 = s[1] - 3
        st.td.lanes[p] = { x0 = x0, x1 = x0 + TD.LANE_W - 1 }
        local orc = pl.faction == "orc"
        E.SpawnBuilding(st, p, orc and "td_gate_orc" or "td_gate", s[1], s[2], true)
        local b = E.Spawn(st, p, orc and "td_builder_orc" or "td_builder", x0 + TD.LANE_W / 2, TD.EXIT_Y - 2.5)
        pl.gold, pl.lumber = TD.START_GOLD, 0
        pl.td = { lives = TD.LIVES, income = TD.INCOME, builder = b.id, sent = 0 }
    end
end

local function Idx(st, x, y) return y * st.w + x end

-- How far each tile of a lane is from its exit (steps), over open ground.
-- extra: tiles to count as blocked too (a tower being placed).
local function Distances(st, p, extra)
    local L = Lane(st, p)
    local dist, q, head = {}, {}, 1
    local function Open(x, y)
        if x < L.x0 or x > L.x1 or y < TD.SPAWN_Y or y > TD.EXIT_Y then return false end
        if extra and extra[Idx(st, x, y)] then return false end
        return not E.Blocked(st, x, y)
    end
    for x = L.x0, L.x1 do
        if Open(x, TD.EXIT_Y) then
            local i = Idx(st, x, TD.EXIT_Y)
            dist[i] = 0
            q[#q + 1] = i
        end
    end
    while head <= #q do
        local i = q[head]
        head = head + 1
        local x, y = i % st.w, math.floor(i / st.w)
        for _, d in ipairs({ { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
            local nx, ny = x + d[1], y + d[2]
            local j = Idx(st, nx, ny)
            if not dist[j] and Open(nx, ny) then
                dist[j] = dist[i] + 1
                q[#q + 1] = j
            end
        end
    end
    return dist
end

local function Flow(st, p)
    local f = st.td.flow[p]
    if not f then
        f = Distances(st, p)
        st.td.flow[p] = f
    end
    return f
end
local function Changed(st, p) st.td.flow[p] = nil end

-- Can player p build btype at (x, y)? In their own lane's building rows, on
-- open ground, not on a creep, and the creeps must still get through.
function TD.CanBuildAt(st, p, btype, x, y)
    local bd = B[btype]
    local L = Lane(st, p)
    if not (bd and bd.tdTower) then return false, "build towers here" end
    if not L or not Alive(st, p) then return false, "you have no lane" end
    local size = bd.size
    if x < L.x0 or x + size - 1 > L.x1 or y < TD.BUILD_Y0 or y + size - 1 > TD.EXIT_Y - 1 then
        return false, "build in your own lane"
    end
    if not E.CanPlace(st, x, y, size) then return false, "can't build there" end
    local extra = {}
    for yy = y, y + size - 1 do for xx = x, x + size - 1 do extra[Idx(st, xx, yy)] = true end end
    local creeps = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.tdLane == p and not U[e.type].air then
            local i = Idx(st, math.floor(e.x), math.floor(e.y))
            if extra[i] then return false, "a creep is in the way" end
            table.insert(creeps, i)
        end
    end
    local dist = Distances(st, p, extra)
    local through = false
    for xx = L.x0, L.x1 do if dist[Idx(st, xx, TD.BUILD_Y0 - 1)] then through = true end end
    if not through then return false, "that would close the path" end
    for _, i in ipairs(creeps) do
        if not dist[i] then return false, "that would trap a creep" end
    end
    return true
end

-- The next opponent still in the game after p (in seat order, round).
function TD.Target(st, p)
    local n = st.td.creeps - 1
    for k = 1, n - 1 do
        local q = (p - 1 + k) % n + 1
        if E.Foe(st, p, q) and Alive(st, q) then return q end
    end
end

---------------------------------------------------------------------------
-- Creeps
---------------------------------------------------------------------------
local function SpawnCreep(st, q, utype, hp, lives, bounty)
    local L = Lane(st, q)
    if not L or not Alive(st, q) then return end
    local x = L.x0 + E.Rand(st, TD.LANE_W - 2) + 0.5
    local u = E.Spawn(st, st.td.creeps, utype, x, TD.SPAWN_Y + 0.5)
    u.tdLane, u.tdLives, u.tdBounty = q, lives or 1, bounty or 1
    u.maxHp, u.hp = hp, hp
    u.facing = math.pi / 2
    return u
end
TD.SpawnCreep = SpawnCreep

-- Out of lives: the gate falls and everything of theirs goes.
local function Out(st, p)
    local gone = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and (e.owner == p or e.tdLane == p) then table.insert(gone, e) end
    end
    for _, e in ipairs(gone) do E.Remove(st, e) end
    E.Emit("tdOut", { owner = p, wave = st.td.wave })
end

local function Leak(st, u)
    local p = u.tdLane
    local pl = st.players[p]
    E.Remove(st, u)
    if not (pl and pl.td) or pl.td.lives <= 0 then return end
    pl.td.lives = math.max(0, pl.td.lives - (u.tdLives or 1))
    E.Emit("tdLeak", { owner = p, lives = pl.td.lives, x = u.x, y = u.y })
    if pl.td.lives <= 0 then Out(st, p) end
end

-- A creep's step: down its lane towards the exit, round the towers (flyers
-- straight over them). They never stop to fight.
function TD.UnitTick(st, u, dt)
    if not u.tdLane then return nil end
    local L = Lane(st, u.tdLane)
    if not L then E.Remove(st, u) return true end
    local left = (E.Speed and E.Speed(st, u) or U[u.type].speed) * dt
    for _ = 1, 4 do
        if left <= 0 then break end
        if u.y >= TD.EXIT_Y + 0.5 then Leak(st, u) return true end
        local gx, gy
        if U[u.type].air then
            gx, gy = u.x, TD.EXIT_Y + 0.6
        else
            local g = u.tdGoal
            if g and E.Blocked(st, g[1], g[2]) then g = nil end
            if g and (g[1] + 0.5 - u.x) ^ 2 + (g[2] + 0.5 - u.y) ^ 2 < 0.0025 then g = nil end
            if not g then
                -- The next tile: the neighbour closest to the exit (no cutting corners).
                local dist = Flow(st, u.tdLane)
                local cx, cy = math.floor(u.x), math.floor(u.y)
                local here = dist[Idx(st, cx, cy)]
                local best, bd
                for _, d in ipairs({ { 0, 1 }, { -1, 0 }, { 1, 0 }, { 0, -1 }, { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }) do
                    local nx, ny = cx + d[1], cy + d[2]
                    local v = dist[Idx(st, nx, ny)]
                    local diagOk = d[1] == 0 or d[2] == 0
                        or (dist[Idx(st, cx + d[1], cy)] and dist[Idx(st, cx, cy + d[2])])
                    if v and diagOk and (not bd or v < bd) then best, bd = { nx, ny }, v end
                end
                if best and (not here or bd <= here) then g = best end
                u.tdGoal = g
            end
            if g then gx, gy = g[1] + 0.5, g[2] + 0.5 else gx, gy = u.x, u.y + 1 end
        end
        local dx, dy = gx - u.x, gy - u.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 0.001 then break end
        u.facing = ATAN2(dy, dx)
        u.walkT = st.time
        local step = math.min(left, d)
        u.x, u.y = u.x + dx / d * step, u.y + dy / d * step
        left = left - step
    end
    if u.y >= TD.EXIT_Y + 0.5 then Leak(st, u) end
    return true
end

-- Towers only shoot creeps in their own lane; nothing else can be hit.
function TD.CanHit(st, a, t)
    if a.type and U[a.type] then return false end -- (units don't fight here: the builder can't)
    return t.tdLane ~= nil and t.tdLane == a.owner
end

---------------------------------------------------------------------------
-- Waves, income, kills
---------------------------------------------------------------------------
function TD.Step(st, dt)
    local td = st.td
    if not td then return end
    if st.time >= td.nextWave then
        td.wave = td.wave + 1
        td.nextWave = td.nextWave + TD.WAVE_EVERY
        local t = st.time
        for _, part in ipairs(TD.Wave(td.wave)) do
            for _ = 1, part[2] do
                for p = 1, td.creeps - 1 do
                    if Alive(st, p) then
                        table.insert(td.queue, { t = t, lane = p, unit = part[1], hp = part[3], lives = part[4], bounty = part[5] })
                    end
                end
                t = t + TD.SPACING
            end
        end
        E.Emit("tdWave", { wave = td.wave })
    end
    if st.time >= td.nextPay then
        td.nextPay = td.nextPay + TD.PAY_EVERY
        for p = 1, td.creeps - 1 do
            if Alive(st, p) then st.players[p].gold = st.players[p].gold + st.players[p].td.income end
        end
    end
    local keep = {}
    for _, s in ipairs(td.queue) do
        if st.time >= s.t then SpawnCreep(st, s.lane, s.unit, s.hp, s.lives, s.bounty)
        else table.insert(keep, s) end
    end
    td.queue = keep
end

function TD.OnDeath(st, t)
    if not t.tdLane then return end
    local pl = st.players[t.tdLane]
    if not (pl and pl.td) then return end
    local n = t.tdBounty or 1
    pl.gold = pl.gold + n
    E.Emit("bounty", { owner = t.tdLane, amount = n, x = t.x, y = t.y })
end

---------------------------------------------------------------------------
-- Commands: build (the builder, at once), sell, send
---------------------------------------------------------------------------
function TD.Command(st, p, cmd)
    local pl = st.players[p]
    if cmd.type == "build" then
        local u = st.ents[cmd.unit or 0]
        if not (u and u.owner == p and U[u.type].tdBuilder) then return false, "your builder builds" end
        local ok, why = TD.CanBuildAt(st, p, cmd.btype, cmd.x, cmd.y)
        if not ok then return false, why end
        local bd = B[cmd.btype]
        if pl.gold < bd.cost[1] then return false, "not enough gold" end
        pl.gold = pl.gold - bd.cost[1]
        local b = E.SpawnBuilding(st, p, cmd.btype, cmd.x, cmd.y, true)
        E.Score(st, p, "built")
        E.Score(st, p, "builtValue", bd.cost[1])
        E.Emit("built", { id = b.id, owner = p, type = cmd.btype })
        Changed(st, p)
        return true
    elseif cmd.type == "tdSell" then
        local b = st.ents[cmd.building or 0]
        if not (b and b.owner == p and b.kind == "building" and B[b.type].tdTower) then return false, "sell your own towers" end
        if #(b.queue or {}) > 0 then return false, "it's being upgraded" end
        local back = math.floor((TD.VALUE[b.type] or 0) * 0.75)
        pl.gold = pl.gold + back
        E.Remove(st, b)
        Changed(st, p)
        E.Emit("tdSold", { owner = p, amount = back })
        return true
    elseif cmd.type == "tdSend" then
        local s
        for _, x in ipairs(TD.SENDS) do if x.unit == cmd.unit then s = x end end
        if not s then return false, "no such send" end
        if not Alive(st, p) then return false, "you're out" end
        local q = TD.Target(st, p)
        if not q then return false, "nobody to send to" end
        if pl.gold < s.cost then return false, "not enough gold" end
        pl.gold = pl.gold - s.cost
        pl.td.income = pl.td.income + s.income
        pl.td.sent = pl.td.sent + 1
        SpawnCreep(st, q, s.unit, math.floor(TD.Health(st.td.wave) * s.hp + 0.5), s.lives or 1, math.floor(s.cost * 0.3))
        E.Emit("tdSent", { owner = p, target = q, unit = s.unit })
        return true
    elseif cmd.type == "gather" then
        return false, "nothing to gather here"
    end
end

---------------------------------------------------------------------------
-- The computer: a zig-zag maze of towers, then upgrades, and sends with
-- what's left over.
---------------------------------------------------------------------------
-- Bands of four towers across the lane, a gap at alternate ends.
local function Spots(L)
    local out = {}
    for k = 0, 4 do
        local y = TD.BUILD_Y0 + 2 + k * 5
        for i = 0, 3 do
            local x = L.x0 + (k % 2 == 0 and 0 or 2) + i * 2
            table.insert(out, { x, y })
        end
    end
    return out
end
TD.Spots = Spots
local PLAN = { "td_arrow", "td_arrow", "td_frost", "td_cannon" }

function TD.Think(st, p)
    local pl = st.players[p]
    if not (pl.td and Alive(st, p)) then return end
    local L = Lane(st, p)
    st.ai = st.ai or {}
    local mem = st.ai[p] or { next = 1 }
    st.ai[p] = mem
    local spots = Spots(L)
    -- Build the next spot of the maze.
    local busy = false
    while mem.next <= #spots do
        local s = spots[mem.next]
        local btype = PLAN[(mem.next - 1) % #PLAN + 1]
        local ok, why = TD.CanBuildAt(st, p, btype, s[1], s[2])
        if not ok and why == "a creep is in the way" then busy = true break end -- (try again soon)
        if ok then
            if pl.gold < B[btype].cost[1] then busy = true break end
            E.Command(st, p, { type = "build", unit = pl.td.builder, btype = btype, x = s[1], y = s[2] })
        end
        mem.next = mem.next + 1 -- (a spot that can't ever work is skipped)
    end
    -- Then upgrades: the weakest first.
    if not busy then
        local best, bestLv
        for _, id in ipairs(st.list) do
            local b = st.ents[id]
            if b and b.owner == p and b.kind == "building" and B[b.type].tdTower and #(b.queue or {}) == 0 then
                local d = B[b.type]
                local key = "td_up_" .. d.tdKind .. (d.tdLevel + 1)
                if R[key] and (not bestLv or d.tdLevel < bestLv) then best, bestLv = { b, key }, d.tdLevel end
            end
        end
        if best and pl.gold >= R[best[2]].cost[1][1] + 40 then
            E.Command(st, p, { type = "research", building = best[1].id, key = best[2] })
        end
    end
    -- Sends (from wave 3): a share of the money, every few seconds - the
    -- best send that share buys. Easy sends little, Hard a lot.
    local diff = pl.difficulty or st.difficulty or "normal"
    local share = diff == "hard" and 0.5 or diff == "easy" and 0.15 or 0.35
    local every = diff == "hard" and 4 or diff == "easy" and 15 or 6
    if st.td.wave >= 3 and st.time - (mem.sentAt or -999) >= every then
        for i = #TD.SENDS, 1, -1 do
            local s = TD.SENDS[i]
            if s.cost <= pl.gold * share then
                if E.Command(st, p, { type = "tdSend", unit = s.unit }) then mem.sentAt = st.time end
                break
            end
        end
    end
end

-- The top bar: lives instead of lumber; income and the next wave instead of food.
function TD.Panel(st, p)
    local pl = st.players[p]
    local td = st.td
    local lives = pl.td and pl.td.lives or 0
    local wave = string.format("Wave %d in %ds", td.wave + 1, math.max(0, math.ceil(td.nextWave - st.time)))
    return "Lives " .. lives, "Income " .. (pl.td and pl.td.income or 0) .. "   " .. wave, lives <= 5
end

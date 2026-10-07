-- Warcraft III (RTS) engine. Pure logic: one plain table holds the whole
-- game (no functions inside), randomness is seeded, entities are kept in
-- creation order, so two clients fed the same commands stay in step (PvP
-- later). The UI calls E.Step(st, dt) many times a second and E.Command
-- for what the player orders; the AI does the same for its side.
--
-- Coordinates are in tiles. Units have a float centre (x, y); buildings and
-- the gold mine have an integer top-left tile (x, y) and a square size.
local ADDON, ns = ...

ns.WC = ns.WC or {}
local E = {}
ns.WC.Engine = E

local function D() return ns.WC end
local ATAN2 = math.atan2 or math.atan -- WoW has atan2; Lua 5.4 spells it atan(y, x)
local RADIUS = 0.4       -- unit size, for ranges
local REPATH = 0.6       -- chasing: how often to look for a new path
local ACQUIRE = 0.5      -- how often idle soldiers look for enemies

local EV
local function Emit(kind, a)
    if EV then
        a = a or {}
        a.kind = kind
        table.insert(EV, a)
    end
end

local function Rand(st, n)
    st.rng = (st.rng * 16807) % 2147483647
    return math.floor(st.rng / 2147483647 * n) + 1
end
E.Rand = Rand
E.Emit = Emit

---------------------------------------------------------------------------
-- The grid
---------------------------------------------------------------------------
local function Idx(st, x, y) return y * st.w + x end

local function Inside(st, x, y) return x >= 0 and y >= 0 and x < st.w and y < st.h end

local function Blocked(st, x, y)
    if not Inside(st, x, y) then return true end
    local i = Idx(st, x, y)
    return st.trees[i] ~= nil or st.occ[i] ~= nil
end
E.Blocked = Blocked

-- Can a building of `size` go at (x, y)? Units standing there are pushed aside.
-- Building orders of player p not started yet (the current one and the
-- Shift queue): { btype, x, y, size } each.
function E.PlannedSites(st, p)
    local out = {}
    for _, id in ipairs(st.list) do
        local u = st.ents[id]
        if u and u.owner == p and u.kind == "unit" then
            local function Add(o)
                if o and o.type == "build" and not o.site then
                    table.insert(out, { btype = o.btype, x = o.x, y = o.y, size = D().Buildings[o.btype].size })
                end
            end
            Add(u.order)
            for _, o in ipairs(u.queue or {}) do Add(o) end
        end
    end
    return out
end

-- Does a planned building of player p overlap this spot?
function E.Planned(st, p, x, y, size)
    for _, s in ipairs(E.PlannedSites(st, p)) do
        if x < s.x + s.size and s.x < x + size and y < s.y + s.size and s.y < y + size then return true end
    end
    return false
end

function E.CanPlace(st, x, y, size)
    for yy = y, y + size - 1 do
        for xx = x, x + size - 1 do
            if Blocked(st, xx, yy) then return false end
        end
    end
    return true
end

local function Occupy(st, e, on)
    for yy = e.y, e.y + e.size - 1 do
        for xx = e.x, e.x + e.size - 1 do
            st.occ[Idx(st, xx, yy)] = on and e.id or nil
        end
    end
end

---------------------------------------------------------------------------
-- Pathfinding: A* over tiles, 8 directions, no cutting corners.
---------------------------------------------------------------------------
local DIRS = { { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 },
    { 1, 1, 1.414 }, { 1, -1, 1.414 }, { -1, 1, 1.414 }, { -1, -1, 1.414 } }

-- isGoal(x, y) says when to stop; (hx, hy) steers the search.
local function AStar(st, sx, sy, isGoal, hx, hy, limit)
    if isGoal(sx, sy) then return {} end
    local w = st.w
    local open, f = {}, {}
    local g, from, closed = {}, {}, {}
    local start = sy * w + sx
    local function H(x, y)
        local dx, dy = math.abs(x - hx), math.abs(y - hy)
        return math.max(dx, dy) + 0.414 * math.min(dx, dy)
    end
    -- Binary heap on f.
    local function Push(i)
        table.insert(open, i)
        local c = #open
        while c > 1 do
            local p = math.floor(c / 2)
            if f[open[p]] <= f[open[c]] then break end
            open[p], open[c] = open[c], open[p]
            c = p
        end
    end
    local function Pop()
        local top = open[1]
        local last = table.remove(open)
        if #open > 0 then
            open[1] = last
            local c = 1
            while true do
                local l, r = c * 2, c * 2 + 1
                local m = c
                if l <= #open and f[open[l]] < f[open[m]] then m = l end
                if r <= #open and f[open[r]] < f[open[m]] then m = r end
                if m == c then break end
                open[m], open[c] = open[c], open[m]
                c = m
            end
        end
        return top
    end
    g[start] = 0
    f[start] = H(sx, sy)
    Push(start)
    local steps, best, bestH = 0, start, f[start]
    while #open > 0 do
        local cur = Pop()
        if not closed[cur] then
            closed[cur] = true
            local cx, cy = cur % w, math.floor(cur / w)
            if isGoal(cx, cy) then
                best = cur
                bestH = -1
                break
            end
            local h = H(cx, cy)
            if h < bestH then best, bestH = cur, h end
            steps = steps + 1
            if steps > (limit or 4000) then break end
            for _, d in ipairs(DIRS) do
                local nx, ny = cx + d[1], cy + d[2]
                local ok = not Blocked(st, nx, ny) or isGoal(nx, ny)
                if ok and d[1] ~= 0 and d[2] ~= 0 then
                    ok = not Blocked(st, cx + d[1], cy) and not Blocked(st, cx, cy + d[2])
                end
                if ok and Inside(st, nx, ny) then
                    local ni = ny * w + nx
                    local ng = g[cur] + d[3]
                    if not closed[ni] and (g[ni] == nil or ng < g[ni]) then
                        g[ni], from[ni] = ng, cur
                        f[ni] = ng + H(nx, ny)
                        Push(ni)
                    end
                end
            end
        end
    end
    -- Walk back from the goal (or the closest we got).
    local path, i = {}, best
    while i and i ~= start do
        table.insert(path, 1, { i % w + 0.5, math.floor(i / w) + 0.5 })
        i = from[i]
    end
    return path
end
E.AStar = AStar

---------------------------------------------------------------------------
-- Entities
---------------------------------------------------------------------------
local function Center(e)
    if e.kind == "unit" then return e.x, e.y end
    return e.x + e.size / 2, e.y + e.size / 2
end
E.Center = Center

-- Distance from a unit to another thing's edge.
local function Gap(u, t)
    if t.kind == "unit" then
        local dx, dy = t.x - u.x, t.y - u.y
        return math.max(0, math.sqrt(dx * dx + dy * dy) - 2 * RADIUS)
    end
    local nx = math.max(t.x, math.min(u.x, t.x + t.size))
    local ny = math.max(t.y, math.min(u.y, t.y + t.size))
    local dx, dy = u.x - nx, u.y - ny
    return math.max(0, math.sqrt(dx * dx + dy * dy) - RADIUS)
end
E.Gap = Gap

local function Def(e)
    if e.kind == "unit" then return D().Units[e.type] end
    return D().Buildings[e.type]
end
E.Def = Def

function E.Get(st, id) return id and st.ents[id] end

---------------------------------------------------------------------------
-- Tech: requirements, research levels and what they add
---------------------------------------------------------------------------
-- Does player p have a finished building of this type (a Keep counts as a
-- Town Hall, and so on)?
function E.Has(st, p, need)
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "building" and e.progress >= 1 then
            if e.type == need then return true end
            for _, c in ipairs(Def(e).counts or {}) do
                if c == need then return true end
            end
        end
    end
    return false
end

-- The first building of `list` player p is missing (its name), or nil.
function E.Missing(st, p, list)
    for _, need in ipairs(list or {}) do
        if not E.Has(st, p, need) then return D().Buildings[need].name end
    end
end

function E.Level(st, p, key)
    local pl = st.players[p]
    return pl and pl.up and pl.up[key] or 0
end

-- Everything research adds to one effect for player p.
local function Bonus(st, p, field)
    local pl = st.players[p]
    if not pl or not pl.up then return 0 end
    local n = 0
    for key, level in pairs(pl.up) do
        local r = D().Research[key]
        local v = r and r.effect and r.effect[field]
        if v then n = n + v * level end
    end
    return n
end
E.Bonus = Bonus

-- A unit's attack range, health and damage with its owner's research.
function E.Range(st, u)
    local d = D().Units[u.type]
    return d.range + (u.type == "rifleman" and Bonus(st, u.owner, "rifleRange") or 0)
end

function E.MaxHp(st, owner, utype)
    return D().Units[utype].hp + (utype == "grunt" and Bonus(st, owner, "gruntHp") or 0)
end

function E.Damage(st, u)
    local d = D().Units[u.type]
    if d.hero and E.HeroDamage then return E.HeroDamage(st, u) end
    local dmg = d.damage
    if not d.worker then
        dmg = dmg * (1 + Bonus(st, u.owner, d.range > 1.5 and "ranged" or "melee"))
        if u.type == "grunt" then dmg = dmg + Bonus(st, u.owner, "gruntDamage") end
    end
    if E.Drums then dmg = dmg * (1 + E.Drums(st, u)) end
    if u.buffs and u.buffs.innerFire then dmg = dmg * 1.1 end
    return dmg
end

function E.ArmorOf(st, e)
    local d = Def(e)
    local a = d.armor or 0
    if e.kind == "unit" then
        if d.hero and E.HeroArmor then a = E.HeroArmor(e) end
        if not d.worker then a = a + Bonus(st, e.owner, "armor") end
        if E.Aura then a = a + E.Aura(st, e, "devotion") end
        if e.buffs and e.buffs.innerFire then a = a + 5 end
    elseif e.kind == "building" then
        a = a + Bonus(st, e.owner, "buildingArmor")
    end
    return a
end

-- A building's queue holds unit types and research ("r:keep"): what it is,
-- and how long it takes.
function E.QueueItem(st, b, q)
    if q:sub(1, 2) == "v:" then
        local ut = q:sub(3)
        local d = D().Units[ut]
        return { name = "Revive " .. d.name, icon = d.icon }, E.ReviveTime(st, b.owner, ut)
    end
    if q:sub(1, 2) == "r:" then
        local key = q:sub(3)
        local r = D().Research[key]
        local level = E.Level(st, b.owner, key) + 1
        return r, (r.time[level] or r.time[#r.time]), key, level
    end
    local d = D().Units[q]
    return d, d.time
end

-- Can player p start this research now? (true, or false and why)
function E.CanResearch(st, p, key, b)
    local r = D().Research[key]
    if not r then return false, "unknown research" end
    if b and b.type ~= r.building then return false, "not here" end
    local level = E.Level(st, p, key) + 1
    if level > (r.levels or 1) then return false, "already done" end
    if st.players[p].busy[key] then return false, "already being researched" end
    local miss = E.Missing(st, p, r.requires and r.requires[level])
    if miss then return false, "requires " .. miss end
    local at = r.minTime and r.minTime[level]
    if at and st.time < at then return false, string.format("ready at %d:%02d", math.floor(at / 60), at % 60) end
    return true
end

local function Add(st, e)
    st.nextId = st.nextId + 1
    e.id = st.nextId
    st.ents[e.id] = e
    table.insert(st.list, e.id)
    return e
end

local function NewUnit(st, owner, utype, x, y, saved)
    local hp = E.MaxHp(st, owner, utype)
    local u = Add(st, { kind = "unit", type = utype, owner = owner, x = x, y = y, hp = hp, maxHp = hp,
        cd = 0, facing = 0 })
    local d = D().Units[utype]
    if d.hero and E.InitHero then
        E.InitHero(st, u, saved)
    elseif d.mana then
        u.mana, u.maxMana = d.mana, d.mana
    end
    return u
end

local function NewBuilding(st, owner, btype, x, y, done)
    local d = D().Buildings[btype]
    local e = Add(st, { kind = d.neutral and "mine" or "building", type = btype, owner = owner, x = x, y = y,
        size = d.size, hp = done and d.hp or math.max(1, math.floor(d.hp * 0.1)), maxHp = d.hp,
        progress = done and 1 or 0, queue = {}, trainT = 0, garrison = d.garrison and {} or nil })
    Occupy(st, e, true)
    return e
end

-- Put a unit on the map (tests, and later scenarios).
function E.Spawn(st, owner, utype, x, y) return NewUnit(st, owner, utype, x, y) end
E.SpawnBuilding = NewBuilding

local function Remove(st, e)
    if e.kind ~= "unit" then Occupy(st, e, false) end
    if e.kind == "unit" and e.inside then
        local mine = st.ents[e.inside]
        if mine and mine.inside == e.id then mine.inside = nil end
        for i, id in ipairs(mine and mine.garrison or {}) do
            if id == e.id then table.remove(mine.garrison, i) break end
        end
    end
    if e.garrison then
        local cx, cy = e.x + e.size / 2, e.y + e.size / 2
        for _, id in ipairs(e.garrison) do
            local u = st.ents[id]
            if u then
                u.inside = nil
                local x, y = FreeAround(st, e, cx, cy + e.size)
                if x then u.x, u.y = x + 0.5, y + 0.5 end
            end
        end
        e.garrison = {}
    end
    st.ents[e.id] = nil
    e.dead = true
end
E.Remove = Remove

-- A free tile next to an entity's footprint, nearest to (px, py).
local function FreeAround(st, e, px, py)
    local best, bestD
    local x0, y0 = e.x - 1, e.y - 1
    local x1, y1 = e.x + e.size, e.y + e.size
    for r = 0, 6 do
        for y = y0 - r, y1 + r do
            for x = x0 - r, x1 + r do
                local edge = x == x0 - r or x == x1 + r or y == y0 - r or y == y1 + r
                if edge and not Blocked(st, x, y) then
                    local d = (x + 0.5 - px) ^ 2 + (y + 0.5 - py) ^ 2
                    if not bestD or d < bestD then best, bestD = { x, y }, d end
                end
            end
        end
        if best then return best[1], best[2] end
    end
end
E.FreeAround = FreeAround

-- The nearest free tile to (x, y).
local function NearestFree(st, x, y)
    x, y = math.floor(x), math.floor(y)
    if not Blocked(st, x, y) then return x, y end
    for r = 1, 12 do
        for yy = y - r, y + r do
            for xx = x - r, x + r do
                if (math.abs(xx - x) == r or math.abs(yy - y) == r) and not Blocked(st, xx, yy) then return xx, yy end
            end
        end
    end
    return x, y
end

---------------------------------------------------------------------------
-- A new game
---------------------------------------------------------------------------
local function Mirror(st, x, y, w, h) return st.w - x - w, st.h - y - h end

-- Teams: players with the same team number are allies (they don't fight,
-- share sight, help each other); without teams everyone is on their own.
function E.Team(st, p) return st.teams and st.teams[p] or p end
-- Do players a and b fight each other? (0 is nobody: gold mines.)
function E.Foe(st, a, b)
    return a ~= nil and b ~= nil and a > 0 and b > 0 and a ~= b and E.Team(st, a) ~= E.Team(st, b)
end
-- Are a and b on the same side (or the same player)?
function E.Ally(st, a, b)
    return a ~= nil and b ~= nil and a > 0 and b > 0 and (a == b or E.Team(st, a) == E.Team(st, b))
end

-- opts: factions = { "human", "orc" } (one per player), seed, difficulty
-- ("easy", "normal", "hard"; the AI side), map (a key in WC.Maps; Maps.lua),
-- teams = { 1, 2, 1, 2 } (a team per player; default: everyone alone),
-- difficulties = { [2] = "hard" } (per computer player), starts = { 1, 3 }
-- (which of the map's starts each player gets; default: in order).
E.NearestFree = NearestFree

function E.New(opts)
    local key = opts.map and D().Maps[opts.map] and opts.map or "riverford"
    local map = D().ParseMap(key)
    local st = { rng = math.floor(opts.seed or 1) % 2147483646 + 1, time = 0, nextId = 0, w = map.w, h = map.h,
        trees = {}, occ = {}, ents = {}, list = {}, players = {}, over = false, difficulty = opts.difficulty or "normal",
        map = key, teams = opts.teams, mode = opts.mode and D().Modes and D().Modes[opts.mode] and opts.mode or "melee" }
    for p = 1, #opts.factions do
        st.players[p] = { faction = opts.factions[p], gold = D().START.gold, lumber = D().START.lumber,
            food = 0, foodCap = 0, up = {}, busy = {}, difficulty = opts.difficulties and opts.difficulties[p] }
    end
    -- A mode can start the game its own way (Modes.lua).
    local mode = D().Modes and D().Modes[st.mode]
    if mode and mode.New then
        for _, t in ipairs(map.trees) do st.trees[Idx(st, t[1], t[2])] = D().TREE_LUMBER end
        mode.New(st, opts, map)
        E.Food(st)
        return st
    end
    -- A hall for each player on its start, then the gold mines.
    for p = 1, #st.players do
        local f = D().Factions[st.players[p].faction]
        local s = map.starts[opts.starts and opts.starts[p] or p]
        NewBuilding(st, p, f.hall, s[1], s[2], true)
    end
    for _, m in ipairs(map.mines) do
        local mine = NewBuilding(st, 0, "gold_mine", m[1], m[2], true)
        mine.gold = D().MINE_GOLD
    end
    for _, t in ipairs(map.trees) do st.trees[Idx(st, t[1], t[2])] = D().TREE_LUMBER end
    -- Workers, sent to the mine.
    for p = 1, #st.players do
        local f = D().Factions[st.players[p].faction]
        local hall = E.Hall(st, p)
        local mine = E.NearestMine(st, Center(hall))
        for i = 1, D().START.workers do
            local x, y = FreeAround(st, hall, Center(mine))
            x, y = NearestFree(st, x + (i % 3) - 1, y + math.floor(i / 3) - 1)
            local u = NewUnit(st, p, f.worker, x + 0.5, y + 0.5)
            E.Order(st, u, { type = "gather", res = "gold", target = mine.id })
        end
    end
    E.Food(st)
    return st
end

---------------------------------------------------------------------------
-- Looking things up
---------------------------------------------------------------------------
function E.Hall(st, p)
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "building" and Def(e).hall and e.progress >= 1 then return e end
    end
end

-- Where a player's base is: the hall, or any building of theirs (modes
-- without halls).
function E.Home(st, p)
    local hall = E.Hall(st, p)
    if hall then return hall end
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "building" then return e end
    end
end

-- The nearest finished drop-off of player p for res ("gold" or "lumber";
-- nil: anything). Halls take both, a lumber mill only lumber.
function E.Dropoff(st, p, x, y, res)
    local best, bd
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        local drop = e and e.kind == "building" and Def(e).dropoff
        if drop and e.owner == p and e.progress >= 1 and (drop == true or not res or drop == res) then
            local cx, cy = Center(e)
            local d = (cx - x) ^ 2 + (cy - y) ^ 2
            if not bd or d < bd then best, bd = e, d end
        end
    end
    return best
end

-- The nearest finished burrow of player p with room inside.
function E.FreeBurrow(st, p, x, y)
    local best, bd
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "building" and e.garrison and e.progress >= 1
            and #e.garrison < Def(e).garrison then
            local cx, cy = Center(e)
            local d = (cx - x) ^ 2 + (cy - y) ^ 2
            if not bd or d < bd then best, bd = e, d end
        end
    end
    return best
end

function E.NearestMine(st, x, y)
    local best, bd
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "mine" and (e.gold or 0) > 0 then
            local cx, cy = Center(e)
            local d = (cx - x) ^ 2 + (cy - y) ^ 2
            if not bd or d < bd then best, bd = e, d end
        end
    end
    return best
end

-- The nearest tree tile to (x, y), as an index.
function E.NearestTree(st, x, y, maxR)
    local cx, cy = math.floor(x), math.floor(y)
    for r = 0, maxR or 20 do
        local best, bd
        for yy = cy - r, cy + r do
            for xx = cx - r, cx + r do
                if (math.abs(xx - cx) == r or math.abs(yy - cy) == r) and Inside(st, xx, yy) then
                    local i = Idx(st, xx, yy)
                    if st.trees[i] then
                        -- Only trees a worker can stand next to.
                        local open = false
                        for _, d in ipairs(DIRS) do
                            if not Blocked(st, xx + d[1], yy + d[2]) then open = true break end
                        end
                        if open then
                            local d = (xx + 0.5 - x) ^ 2 + (yy + 0.5 - y) ^ 2
                            if not bd or d < bd then best, bd = i, d end
                        end
                    end
                end
            end
        end
        if best then return best end
    end
end

-- What's at a point: a unit first, then a building or the mine.
function E.At(st, x, y)
    local best, bd
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" then
            local d = (e.x - x) ^ 2 + (e.y - y) ^ 2
            if d < 0.36 and (not bd or d < bd) then best, bd = e, d end
        end
    end
    if best then return best end
    local o = st.occ[Idx(st, math.floor(x), math.floor(y))]
    return o and st.ents[o]
end

function E.Food(st)
    for p = 1, #st.players do
        st.players[p].food, st.players[p].foodCap = 0, 0
    end
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner > 0 then
            local pl = st.players[e.owner]
            if e.kind == "unit" then
                pl.food = pl.food + D().Units[e.type].food
            elseif e.kind == "building" then
                if e.progress >= 1 then pl.foodCap = pl.foodCap + (Def(e).food or 0) end
                for _, q in ipairs(e.queue) do
                    if D().Units[q] then pl.food = pl.food + D().Units[q].food end
                end
            end
        end
    end
    for p = 1, #st.players do st.players[p].foodCap = math.min(D().FOOD_MAX, st.players[p].foodCap) end
end

---------------------------------------------------------------------------
-- Orders
---------------------------------------------------------------------------
-- A worker comes out of the gold mine (onto the side facing its hall).
local function LeaveMine(st, u)
    local mine = st.ents[u.inside or 0]
    u.inside = nil
    if not mine then return end
    if mine.inside == u.id then mine.inside = nil end
    for i, id in ipairs(mine.garrison or {}) do
        if id == u.id then table.remove(mine.garrison, i) break end
    end
    local hall = E.Dropoff(st, u.owner, u.x, u.y, "gold")
    local hx, hy = Center(mine)
    if hall then hx, hy = Center(hall) end
    local x, y = FreeAround(st, mine, hx, hy)
    if x then u.x, u.y = x + 0.5, y + 0.5 end
end
E.LeaveMine = LeaveMine

-- Orders that never end by themselves: a Shift-queued order replaces them.
local ENDLESS = { gather = true, hold = true }

-- A building order not started yet gives its gold and lumber back.
local function Refund(st, u, o)
    if o and o.type == "build" and o.paid and not o.site then
        local pl = st.players[u.owner]
        local cost = D().Buildings[o.btype].cost
        pl.gold, pl.lumber = pl.gold + cost[1], pl.lumber + cost[2]
        o.paid = nil
    end
end

-- Would the unit queue this order (Shift) rather than start it now?
function E.Queues(u, queued)
    return queued and u.order ~= nil and not ENDLESS[u.order.type]
end

-- Give a unit an order. mode nil: replaces what it was doing and its queue
-- (unstarted buildings are refunded); "queue": after its current order
-- (Shift, like Warcraft III); "next": the next order from its own queue.
function E.Order(st, u, order, mode)
    if mode == "queue" and E.Queues(u, true) then
        u.queue = u.queue or {}
        table.insert(u.queue, order)
        return
    end
    if mode ~= "next" then
        if u.order ~= order then Refund(st, u, u.order) end
        for _, q in ipairs(u.queue or {}) do Refund(st, u, q) end
        u.queue = nil
    end
    if u.inside then LeaveMine(st, u) end
    if u.insideBuild then
        local b = st.ents[u.insideBuild]
        u.insideBuild = nil
        if b then
            local x, y = FreeAround(st, b, u.x, u.y + b.size)
            if x then u.x, u.y = x + 0.5, y + 0.5 end
        end
    end
    u.order = order
    if not order then
        u.path, u.repath, u.work = nil, 0, nil
        return
    end
    u.path, u.repath, u.work = nil, 0, nil
    if order.type == "gather" then u.phase = (u.carry and u.carry.n > 0 and u.carry.res == order.res) and "return" or "go" end
end

-- Path a unit towards a point or an entity.
local function PathTo(st, u, tx, ty, ent, adjacentTree)
    local ud = D().Units[u.type]
    if ud and ud.air then
        local gx, gy = tx, ty
        if ent then gx, gy = Center(ent) end
        u.path, u.pathi = { { gx, gy } }, 1
        return
    end
    local sx, sy = math.floor(u.x), math.floor(u.y)
    local goal, hx, hy
    if ent then
        hx, hy = Center(ent)
        local x0, y0, x1, y1 = ent.x - 1, ent.y - 1, ent.x + (ent.size or 0), ent.y + (ent.size or 0)
        if ent.kind == "unit" then
            local ex, ey = math.floor(ent.x), math.floor(ent.y)
            goal = function(x, y) return math.abs(x - ex) <= 1 and math.abs(y - ey) <= 1 end
        else
            goal = function(x, y) return x >= x0 and x <= x1 and y >= y0 and y <= y1 and not Blocked(st, x, y) end
        end
    elseif adjacentTree then
        local i = adjacentTree
        local ex, ey = i % st.w, math.floor(i / st.w)
        hx, hy = ex + 0.5, ey + 0.5
        goal = function(x, y) return math.abs(x - ex) <= 1 and math.abs(y - ey) <= 1 and not Blocked(st, x, y) end
    else
        local gx, gy = NearestFree(st, tx, ty)
        hx, hy = gx + 0.5, gy + 0.5
        goal = function(x, y) return x == gx and y == gy end
    end
    u.path = AStar(st, sx, sy, goal, hx, hy)
    u.pathi = 1
    if not ent and not adjacentTree and #u.path > 0 then
        -- End exactly where clicked (if that spot is free).
        if not Blocked(st, math.floor(tx), math.floor(ty)) then u.path[#u.path] = { tx, ty } end
    end
end

E.PathTo = PathTo

-- Move along the path. True when there's nowhere left to go.
local function Follow(st, u, dt)
    local p = u.path
    if not p or not p[u.pathi] then return true end
    local speed = E.Speed and E.Speed(st, u) or D().Units[u.type].speed
    local left = speed * dt
    while left > 0 and p[u.pathi] do
        local wx, wy = p[u.pathi][1], p[u.pathi][2]
        local dx, dy = wx - u.x, wy - u.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.001 then u.facing = ATAN2(dy, dx) end
        if d > 0.001 then u.walkT = st.time end -- for the walk animation
        if d <= left then
            u.x, u.y = wx, wy
            left = left - d
            u.pathi = u.pathi + 1
        else
            u.x, u.y = u.x + dx / d * left, u.y + dy / d * left
            left = 0
        end
    end
    return not p[u.pathi]
end

E.Follow = Follow

local function Armor(a) return a * 0.06 / (1 + 0.06 * a) end

local function Strike(st, a, t, damage, ranged, attackType)
    local armorType = Def(t).armorType or (t.kind == "unit" and "medium" or "fortified")
    local mult = (D().DAMAGE[attackType or "normal"] or {})[armorType] or 1
    local reduce = attackType == "spell" and 1 or (1 - Armor(E.ArmorOf(st, t)))
    local dmg = math.max(1, math.floor(damage * mult * reduce + 0.5))
    if E.OnTaken then dmg = math.floor(E.OnTaken(st, t, dmg) + 0.5) end
    if dmg <= 0 then return end
    t.hp = t.hp - dmg
    t.lastHitBy = a.id
    Emit("hit", { id = a.id, target = t.id, amount = dmg, ranged = ranged })
    if t.hp <= 0 and not t.dead then
        if E.OnDying and E.OnDying(st, t) then return end
        Emit("death", { id = t.id, owner = t.owner, what = t.kind, type = t.type, hero = E.IsHero and E.IsHero(t) or nil })
        if E.OnDeath then E.OnDeath(st, t) end
        if t.kind == "building" then
            -- Units still training there are lost; the food they held frees up.
            for _, q in ipairs(t.queue or {}) do
                if q:sub(1, 2) == "r:" and st.players[t.owner] then st.players[t.owner].busy[q:sub(3)] = nil end
            end
            t.queue = {}
        end
        Remove(st, t)
    end
end
E.Strike = Strike

local function Hit(st, u, t)
    local d = D().Units[u.type]
    local dmg = E.Damage(st, u)
    if E.OnHit then dmg = E.OnHit(st, u, t, dmg) end
    local tx, ty = Center(t)
    Strike(st, u, t, dmg, d.range > 1.5, d.attackType)
    if d.splash then
        -- Splash: half damage to the other side's ground things around the target.
        local near = {}
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and e ~= t and not e.dead and E.Foe(st, e.owner, u.owner) and e.kind ~= "mine"
                and not (e.kind == "unit" and D().Units[e.type].air) then
                local ex, ey = Center(e)
                local r = d.splash + (e.size or 0) / 2
                if (ex - tx) ^ 2 + (ey - ty) ^ 2 <= r * r then table.insert(near, e) end
            end
        end
        for _, e in ipairs(near) do
            if not e.dead then Strike(st, u, e, dmg * 0.5, true, d.attackType) end
        end
    end
end

-- Chase and hit a target. False when it's gone.
local function Fight(st, u, t, dt)
    if not t or t.dead or t.hp <= 0 then return false end
    if E.CanHit and not E.CanHit(st, u, t) then return false end
    local d = D().Units[u.type]
    local gap = Gap(u, t)
    if gap <= E.Range(st, u) then
        u.path = nil
        local tx, ty = Center(t)
        u.facing = ATAN2(ty - u.y, tx - u.x)
        if u.cd <= 0 and not (E.CantAttack and E.CantAttack(u)) then
            u.cd = E.Cooldown and E.Cooldown(st, u) or d.cooldown
            Hit(st, u, t)
        end
        return true
    end
    u.repath = (u.repath or 0) - dt
    if not u.path or u.repath <= 0 then
        PathTo(st, u, nil, nil, t)
        u.repath = REPATH
    end
    Follow(st, u, dt)
    return true
end

-- The nearest enemy a unit can see (units before buildings).
local function Nearest(st, u, range)
    if st.peace then return nil end -- the Showcase: nobody picks fights by themselves
    local best, bd, bestB, bdB
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and E.Foe(st, e.owner, u.owner) and e.kind ~= "mine"
            and not (E.Untouchable and (E.Untouchable(e) or E.Hidden(e)))
            and not (E.CanHit and not E.CanHit(st, u, e)) then
            local g = Gap(u, e)
            if g <= range then
                if e.kind == "unit" then
                    if not bd or g < bd then best, bd = e, g end
                elseif not bdB or g < bdB then
                    bestB, bdB = e, g
                end
            end
        end
    end
    return best or bestB
end
E.Nearest = Nearest

local function Deposit(st, u)
    local pl = st.players[u.owner]
    if u.carry and u.carry.n > 0 then
        local upkeep = (u.carry.res == "gold" and E.Upkeep) and E.Upkeep(st, u.owner) or 1
        local n = math.floor(u.carry.n * (pl.income or 1) * upkeep + 0.5)
        if u.carry.res == "gold" then pl.gold = pl.gold + n else pl.lumber = pl.lumber + n end
        Emit("deposit", { id = u.id, owner = u.owner, res = u.carry.res, n = u.carry.n })
    end
    u.carry = nil
end

local function Gather(st, u, o, dt)
    local res = o.res
    if u.phase == "return" then
        local drop = E.Dropoff(st, u.owner, u.x, u.y, u.carry and u.carry.res or res)
        if not drop then u.order = nil return end
        if Gap(u, drop) <= 1.1 then
            Deposit(st, u)
            u.phase, u.path = "go", nil
            return
        end
        if not u.path then PathTo(st, u, nil, nil, drop) end
        if Follow(st, u, dt) and Gap(u, drop) > 1.1 then u.path = nil end
        return
    end
    if res == "gold" then
        local mine = st.ents[o.target]
        if not mine or (mine.gold or 0) <= 0 then
            mine = E.NearestMine(st, u.x, u.y)
            if not mine then u.order = nil return end
            o.target = mine.id
        end
        if u.phase == "work" then
            u.work = u.work - dt
            if u.work <= 0 then
                local n = math.min(D().CARRY, mine.gold)
                mine.gold = mine.gold - n
                u.carry = { res = "gold", n = n }
                LeaveMine(st, u)
                if mine.gold <= 0 then Remove(st, mine) Emit("mineEmpty", { id = mine.id }) end
                u.phase, u.path = "return", nil
                Emit("mined", { id = u.id, owner = u.owner })
            end
            return
        end
        if Gap(u, mine) <= 1.1 then
            -- One worker in the mine at a time; the others wait at the door.
            if not mine.inside or not st.ents[mine.inside] then
                mine.inside = u.id
                u.inside = mine.id
                u.phase, u.work = "work", D().MINE_TIME
                u.path = nil
            else
                u.phase = "wait"
                u.path = nil
            end
            return
        end
        if u.phase == "wait" then u.phase = "go" end
        if not u.path then PathTo(st, u, nil, nil, mine) end
        if Follow(st, u, dt) and Gap(u, mine) > 1.1 then u.path = nil end
    else
        local tree = o.target
        if not st.trees[tree] then
            tree = E.NearestTree(st, u.x, u.y)
            if not tree then u.order = nil return end
            o.target = tree
            u.path = nil
        end
        local tx, ty = tree % st.w, math.floor(tree / st.w)
        local near = math.abs(math.floor(u.x) - tx) <= 1 and math.abs(math.floor(u.y) - ty) <= 1
        if u.phase == "work" then
            u.work = u.work - dt
            u.facing = ATAN2(ty + 0.5 - u.y, tx + 0.5 - u.x)
            if u.work <= 0 then
                local n = math.min(D().CARRY + Bonus(st, u.owner, "lumber"), st.trees[tree])
                st.trees[tree] = st.trees[tree] - n
                if st.trees[tree] <= 0 then
                    st.trees[tree] = nil
                    Emit("treeDown", { tree = tree })
                end
                u.carry = { res = "lumber", n = n }
                u.phase, u.path = "return", nil
            end
            return
        end
        if near then
            u.phase, u.work = "work", D().CHOP_TIME
            return
        end
        if not u.path then PathTo(st, u, nil, nil, nil, tree) end
        if Follow(st, u, dt) then
            u.path = nil
            local x2, y2 = math.floor(u.x), math.floor(u.y)
            if not (math.abs(x2 - tx) <= 1 and math.abs(y2 - ty) <= 1) then
                -- Couldn't reach it: after a few tries, pick another tree nearby.
                o.tries = (o.tries or 0) + 1
                if o.tries > 3 then
                    o.target = E.NearestTree(st, u.x + Rand(st, 7) - 4, u.y + Rand(st, 7) - 4) or tree
                    o.tries = 0
                end
            end
        end
    end
end

-- Does this worker count as building b right now?
local function Building(st, u, b)
    return u and not u.dead and u.order and u.order.type == "build" and u.order.site == b.id
        and (u.insideBuild == b.id or Gap(u, b) <= 1.5)
end
E.Building = Building

-- A builder is done: back to what it did before (gathering), after its queue.
local function AfterBuild(st, u)
    if not u.after then return end
    if u.queue and #u.queue > 0 then
        table.insert(u.queue, u.after)
    else
        E.Order(st, u, u.after, "next")
    end
    u.after = nil
end

local function Build(st, u, o, dt)
    if o.site then
        local b = st.ents[o.site]
        if not b or b.progress >= 1 then
            u.order, u.building = nil, nil
            AfterBuild(st, u)
            return
        end
        b.builder = u.id
        if u.insideBuild == b.id then return end
        -- Walk back to it if pushed away; orcs go inside, humans hammer next to it.
        if Gap(u, b) > 1.5 then
            if not u.path then PathTo(st, u, nil, nil, b) end
            if Follow(st, u, dt) then u.path = nil end
            return
        end
        u.path = nil
        local tx, ty = Center(b)
        u.facing = ATAN2(ty - u.y, tx - u.x)
        if D().Factions[st.players[u.owner].faction].buildInside then u.insideBuild = b.id end
        return
    end
    local size = D().Buildings[o.btype].size
    local fake = { kind = "building", x = o.x, y = o.y, size = size }
    if Gap(u, fake) <= 1.2 then
        -- Units in the way step aside; then check the ground.
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and e.kind == "unit" and e ~= u and e.x >= o.x and e.x < o.x + size and e.y >= o.y and e.y < o.y + size then
                local nx, ny = FreeAround(st, fake, e.x, e.y)
                if nx then e.x, e.y = nx + 0.5, ny + 0.5 end
            end
        end
        if u.x >= o.x and u.x < o.x + size and u.y >= o.y and u.y < o.y + size then
            local nx, ny = FreeAround(st, fake, u.x, u.y)
            if nx then u.x, u.y = nx + 0.5, ny + 0.5 end
        end
        if not E.CanPlace(st, o.x, o.y, size) then
            local pl = st.players[u.owner]
            local cost = D().Buildings[o.btype].cost
            pl.gold, pl.lumber = pl.gold + cost[1], pl.lumber + cost[2]
            Emit("cantBuild", { id = u.id, owner = u.owner })
            u.order = nil
            return
        end
        local b = NewBuilding(st, u.owner, o.btype, o.x, o.y, false)
        b.builder = u.id
        o.site = b.id
        u.building = b.id
        Emit("placed", { id = b.id, owner = u.owner, type = o.btype })
        return
    end
    if not u.path then PathTo(st, u, nil, nil, fake) end
    if Follow(st, u, dt) and Gap(u, fake) > 1.2 then
        o.tries = (o.tries or 0) + 1
        u.path = nil
        if o.tries > 3 then
            local pl = st.players[u.owner]
            local cost = D().Buildings[o.btype].cost
            pl.gold, pl.lumber = pl.gold + cost[1], pl.lumber + cost[2]
            Emit("cantBuild", { id = u.id, owner = u.owner })
            u.order = nil
        end
    end
end

-- Militia go back to being peasants (and back to work).
function E.BackToWork(st, u)
    if u.inside and not u.order then
        LeaveMine(st, u)
    end
    if u.militia then
        u.type = u.militia.was
        local d = D().Units[u.type]
        u.maxHp = d.hp
        u.hp = math.min(u.hp, u.maxHp)
        u.militia = nil
    end
    local o = u.workOrder
    u.workOrder = nil
    if not o then
        local mine = E.NearestMine(st, u.x, u.y)
        if mine then o = { type = "gather", res = "gold", target = mine.id } end
    end
    E.Order(st, u, o)
end

local function UnitStep(st, u, dt)
    u.cd = math.max(0, (u.cd or 0) - dt)
    if E.UnitTick and E.UnitTick(st, u, dt) then return end
    if u.militia then
        u.militia.t = u.militia.t - dt
        if u.militia.t <= 0 then
            E.BackToWork(st, u)
            Emit("backToWork", { id = u.id, owner = u.owner })
        end
    end
    if u.type == "headhunter" and u.hp < u.maxHp then
        local regen = Bonus(st, u.owner, "trollRegen")
        if regen > 0 then u.hp = math.min(u.maxHp, u.hp + regen * dt) end
    end
    if u.inside and not u.order then return end -- sitting in a burrow
    -- Done: the next Shift-queued order.
    if not u.order and u.queue then
        local nxt = table.remove(u.queue, 1)
        if #u.queue == 0 then u.queue = nil end
        if nxt then E.Order(st, u, nxt, "next") end
    end
    local d = D().Units[u.type]
    local o = u.order
    if not o then
        -- Idle soldiers fight what comes near (and hit back).
        if not d.worker then
            u.scan = (u.scan or 0) - dt
            if u.scan <= 0 and not (E.CantAttack and E.CantAttack(u)) then
                u.scan = ACQUIRE
                -- (wards can't walk: only what's in range)
                local t = Nearest(st, u, d.speed > 0 and D().SIGHT or E.Range(st, u))
                if t then u.order = { type = "attack", target = t.id, auto = true, homeX = u.x, homeY = u.y } end
            end
        end
        return
    end
    if o.type == "move" then
        if not u.path then PathTo(st, u, o.x, o.y) end
        if Follow(st, u, dt) then u.order, u.path = nil, nil end
    elseif o.type == "attack" then
        local t = st.ents[o.target]
        if not Fight(st, u, t, dt) then
            u.order, u.path = nil, nil
            -- Auto targets: look for the next one nearby.
            if o.auto or o.resume then
                local n = Nearest(st, u, D().SIGHT)
                if n then
                    u.order = { type = "attack", target = n.id, auto = o.auto, resume = o.resume }
                elseif o.resume then
                    E.Order(st, u, o.resume)
                end
            end
        end
    elseif o.type == "attackMove" then
        u.scan = (u.scan or 0) - dt
        if u.scan <= 0 then
            u.scan = ACQUIRE
            local t = Nearest(st, u, D().SIGHT)
            if t then
                u.order = { type = "attack", target = t.id, resume = o }
                u.path = nil
                return
            end
        end
        if not u.path then PathTo(st, u, o.x, o.y) end
        if Follow(st, u, dt) then u.order, u.path = nil, nil end
    elseif o.type == "hold" then
        local t = Nearest(st, u, E.Range(st, u))
        if t and Gap(u, t) <= E.Range(st, u) and u.cd <= 0 and not (E.CantAttack and E.CantAttack(u)) then
            local tx, ty = Center(t)
            u.facing = ATAN2(ty - u.y, tx - u.x)
            u.cd = E.Cooldown and E.Cooldown(st, u) or d.cooldown
            Hit(st, u, t)
        end
    elseif o.type == "toArms" then
        local hall = st.ents[o.hall]
        if not hall then u.order = nil return end
        if Gap(u, hall) <= 1.2 then
            local was = u.type
            u.type = "militia"
            u.militia = { t = D().MILITIA_TIME, was = was }
            u.maxHp = D().Units.militia.hp
            u.order, u.path = nil, nil
            Emit("militia", { id = u.id, owner = u.owner })
            return
        end
        if not u.path then PathTo(st, u, nil, nil, hall) end
        if Follow(st, u, dt) and Gap(u, hall) > 1.2 then u.path = nil end
    elseif o.type == "garrison" then
        local b = st.ents[o.target]
        if not b or b.progress < 1 or #b.garrison >= Def(b).garrison then
            -- Full or gone: try another burrow.
            b = E.FreeBurrow(st, u.owner, u.x, u.y)
            if not b then u.order = nil return end
            o.target = b.id
            u.path = nil
        end
        if Gap(u, b) <= 1.2 then
            table.insert(b.garrison, u.id)
            u.inside = b.id
            u.order, u.path = nil, nil
            return
        end
        if not u.path then PathTo(st, u, nil, nil, b) end
        if Follow(st, u, dt) and Gap(u, b) > 1.2 then u.path = nil end
    elseif o.type == "gather" then
        Gather(st, u, o, dt)
    elseif o.type == "cast" then
        E.CastStep(st, u, o, dt)
    elseif o.type == "build" then
        Build(st, u, o, dt)
    end
end

local function BuildingStep(st, b, dt)
    local d = Def(b)
    if b.progress < 1 then
        if not Building(st, st.ents[b.builder or 0], b) then
            b.paused = true
            return
        end
        b.paused = nil
        local before = b.progress
        b.progress = math.min(1, b.progress + dt / d.time)
        b.hp = math.min(b.maxHp, b.hp + (b.progress - before) * b.maxHp * 0.9)
        if b.progress >= 1 then
            -- Fractions add up to 999.99...: an undamaged building ends at full health.
            b.hp = math.min(b.maxHp, math.floor(b.hp + 0.5))
            Emit("built", { id = b.id, owner = b.owner, type = b.type })
            local u = st.ents[b.builder or 0]
            if u and u.order and u.order.site == b.id then
                if u.insideBuild then
                    u.insideBuild = nil
                    local x, y = FreeAround(st, b, u.x, u.y + b.size)
                    if x then u.x, u.y = x + 0.5, y + 0.5 end
                end
                u.order, u.building = nil, nil
                -- Back to what it was doing before (gathering), if anything.
                AfterBuild(st, u)
            end
        end
        return
    end
    -- Towers always shoot; burrows only with peons inside.
    local gar = b.garrison
    if d.attack and b.progress >= 1 and (not gar or #gar > 0) then
        b.cd = (b.cd or 0) - dt
        if b.cd <= 0 then
            local cx, cy = Center(b)
            local t = Nearest(st, { x = cx, y = cy, owner = b.owner, kind = "unit" }, d.attack.range + b.size / 2)
            if t then
                Strike(st, b, t, d.attack.damage, true, d.attack.type)
                b.cd = d.attack.cooldown / (gar and #gar or 1) -- more peons, faster spears
            end
        end
    end
    local q = b.queue[1]
    if q and q:sub(1, 2) == "r:" then
        local r, time, key, level = E.QueueItem(st, b, q)
        b.trainT = b.trainT + dt
        if b.trainT >= time then
            table.remove(b.queue, 1)
            b.trainT = 0
            local pl = st.players[b.owner]
            pl.up[key] = level
            pl.busy[key] = nil
            if r.upgrade then
                -- The building becomes the next one (Keep, Castle, Guard Tower...).
                local old = b.maxHp
                b.type = r.upgrade
                b.maxHp = Def(b).hp
                b.hp = math.min(b.maxHp, b.hp + (b.maxHp - old))
            end
            if r.effect and r.effect.gruntHp then
                for _, id in ipairs(st.list) do
                    local e = st.ents[id]
                    if e and e.owner == b.owner and e.type == "grunt" then
                        e.maxHp = E.MaxHp(st, b.owner, "grunt")
                        e.hp = e.hp + r.effect.gruntHp
                    end
                end
            end
            Emit("researched", { id = b.id, owner = b.owner, key = key, level = level, upgrade = r.upgrade })
        end
    elseif q and q:sub(1, 2) == "v:" then
        local ut = q:sub(3)
        b.trainT = b.trainT + dt
        if b.trainT >= E.ReviveTime(st, b.owner, ut) then
            local cx, cy = Center(b)
            local x, y = FreeAround(st, b, cx, cy + b.size)
            if x then
                table.remove(b.queue, 1)
                b.trainT = 0
                local pl = st.players[b.owner]
                local saved = pl.fallen[ut]
                pl.fallen[ut] = nil
                local u = NewUnit(st, b.owner, ut, x + 0.5, y + 0.5, saved)
                Emit("revived", { id = u.id, owner = b.owner, type = ut })
            end
        end
    elseif q then
        b.trainT = b.trainT + dt
        if b.trainT >= D().Units[q].time then
            local cx, cy = Center(b)
            local rx, ry = cx, cy + b.size
            if b.rally then rx, ry = b.rally.x, b.rally.y end
            local x, y = FreeAround(st, b, rx, ry)
            if x then
                table.remove(b.queue, 1)
                b.trainT = 0
                local u = NewUnit(st, b.owner, q, x + 0.5, y + 0.5)
                Emit("trained", { id = u.id, owner = b.owner, type = q })
                if b.rally then
                    local target = b.rally.target and st.ents[b.rally.target]
                    if target and target.kind == "mine" and D().Units[q].worker then
                        E.Order(st, u, { type = "gather", res = "gold", target = target.id })
                    elseif b.rally.tree and D().Units[q].worker then
                        E.Order(st, u, { type = "gather", res = "lumber", target = b.rally.tree })
                    else
                        E.Order(st, u, { type = "move", x = b.rally.x, y = b.rally.y })
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Commands (from the player or the AI)
---------------------------------------------------------------------------
local function Owned(st, p, ids)
    local out = {}
    for _, id in ipairs(ids or {}) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "unit" then table.insert(out, e) end
    end
    return out
end

function E.CanAfford(st, p, cost)
    local pl = st.players[p]
    return pl.gold >= cost[1] and pl.lumber >= cost[2]
end

-- cmd.type: move, attackMove, attack, gather, stop, build, train, cancel, rally.
-- Returns ok, reason.
function E.Command(st, p, cmd)
    if st.over then return false, "the game is over" end
    local t = cmd.type
    local mode = cmd.queue and "queue" or nil -- Shift: after the current order
    if t == "move" or t == "attackMove" then
        local units = Owned(st, p, cmd.units)
        -- Spread a group around the point so they don't all stack.
        for i, u in ipairs(units) do
            local ox, oy = 0, 0
            if #units > 1 then
                local ring = math.floor((i - 1) / 8) + 1
                local a = (i - 1) % 8 * math.pi / 4
                ox, oy = math.cos(a) * 0.8 * ring, math.sin(a) * 0.8 * ring
                if i == 1 then ox, oy = 0, 0 end
            end
            E.Order(st, u, { type = t, x = cmd.x + ox, y = cmd.y + oy }, mode)
        end
        return #units > 0
    elseif t == "attack" then
        local target = st.ents[cmd.target]
        if not target or target.owner == p or target.kind == "mine" then return false, "not a target" end
        for _, u in ipairs(Owned(st, p, cmd.units)) do E.Order(st, u, { type = "attack", target = target.id }, mode) end
        return true
    elseif t == "gather" then
        local n = 0
        for _, u in ipairs(Owned(st, p, cmd.units)) do
            if D().Units[u.type].worker then
                if cmd.tree then
                    E.Order(st, u, { type = "gather", res = "lumber", target = cmd.tree }, mode)
                else
                    E.Order(st, u, { type = "gather", res = "gold", target = cmd.target }, mode)
                end
                n = n + 1
            end
        end
        return n > 0, "only workers gather"
    elseif t == "stop" then
        for _, u in ipairs(Owned(st, p, cmd.units)) do E.Order(st, u, nil) end
        return true
    elseif t == "hold" then
        for _, u in ipairs(Owned(st, p, cmd.units)) do E.Order(st, u, { type = "hold" }) end
        return true
    elseif t == "callToArms" or t == "battleStations" then
        local hall = st.ents[cmd.building]
        if not hall or hall.owner ~= p or hall.kind ~= "building" then return false end
        local f = D().Factions[st.players[p].faction]
        if f.alarm ~= t then return false, "your race can't do that" end
        local hx, hy = Center(hall)
        local n = 0
        for _, id in ipairs(st.list) do
            local u = st.ents[id]
            if u and u.owner == p and u.kind == "unit" and u.type == f.worker
                and (u.x - hx) ^ 2 + (u.y - hy) ^ 2 <= D().ALARM_RADIUS ^ 2 then
                local o = u.order
                if o and o.type == "gather" then u.workOrder = o end
                if t == "callToArms" then
                    local near = E.Dropoff(st, p, u.x, u.y, "gold") or hall
                    E.Order(st, u, { type = "toArms", hall = near.id })
                else
                    local b = E.FreeBurrow(st, p, u.x, u.y)
                    if b then E.Order(st, u, { type = "garrison", target = b.id }) end
                end
                n = n + 1
            end
        end
        Emit("alarm", { owner = p, kind2 = t })
        return n > 0, "no workers nearby"
    elseif t == "backToWork" then
        local n = 0
        for _, id in ipairs(st.list) do
            local u = st.ents[id]
            if u and u.owner == p and u.kind == "unit" and (u.militia or (u.order and (u.order.type == "toArms" or u.order.type == "garrison"))
                or (u.inside and not u.order)) then
                E.BackToWork(st, u)
                n = n + 1
            end
        end
        return n > 0, "nobody to send back"
    elseif t == "resumeBuild" then
        local b = st.ents[cmd.building]
        if not b or b.owner ~= p or b.kind ~= "building" or b.progress >= 1 then return false end
        for _, u in ipairs(Owned(st, p, cmd.units)) do
            if D().Units[u.type].worker then
                local after = u.order and u.order.type == "gather" and u.order or nil
                E.Order(st, u, { type = "build", btype = b.type, x = b.x, y = b.y, site = b.id })
                u.after = after
                b.builder = u.id
                return true
            end
        end
        return false, "a worker builds"
    elseif t == "returnRes" then
        -- Carry the load home, then back to the same work.
        local n = 0
        for _, u in ipairs(Owned(st, p, cmd.units)) do
            if u.carry and u.carry.n > 0 then
                local o = u.order
                if not (o and o.type == "gather" and o.res == u.carry.res) then
                    if u.carry.res == "gold" then
                        local mine = E.NearestMine(st, u.x, u.y)
                        o = { type = "gather", res = "gold", target = mine and mine.id }
                    else
                        o = { type = "gather", res = "lumber", target = E.NearestTree(st, u.x, u.y) }
                    end
                end
                E.Order(st, u, o)
                u.phase = "return"
                n = n + 1
            end
        end
        return n > 0, "nothing to bring back"
    elseif t == "build" then
        local u = st.ents[cmd.unit]
        if not u or u.owner ~= p or not D().Units[u.type].worker then return false, "a worker builds" end
        local f = D().Factions[st.players[p].faction]
        local allowed = false
        for _, b in ipairs(f.builds) do if b == cmd.btype then allowed = true end end
        if not allowed then return false, "your race can't build that" end
        local bd = D().Buildings[cmd.btype]
        local miss = E.Missing(st, p, bd.requires)
        if miss then return false, "requires " .. miss end
        if not E.CanAfford(st, p, bd.cost) then return false, "not enough gold or lumber" end
        if not E.CanPlace(st, cmd.x, cmd.y, bd.size) or E.Planned(st, p, cmd.x, cmd.y, bd.size) then
            return false, "can't build there"
        end
        local pl = st.players[p]
        pl.gold, pl.lumber = pl.gold - bd.cost[1], pl.lumber - bd.cost[2]
        local queued = E.Queues(u, cmd.queue)
        local after = u.order and u.order.type == "gather" and u.order or nil
        E.Order(st, u, { type = "build", btype = cmd.btype, x = cmd.x, y = cmd.y, paid = true }, mode)
        if not queued then u.after = after end
        return true
    elseif t == "train" then
        local b = st.ents[cmd.building]
        if not b or b.owner ~= p or b.kind ~= "building" or b.progress < 1 then return false, "not ready" end
        local ok = false
        for _, ut in ipairs(Def(b).trains or {}) do if ut == cmd.utype then ok = true end end
        if not ok then return false, "can't train that here" end
        if #b.queue >= 5 then return false, "the queue is full" end
        local ud = D().Units[cmd.utype]
        local miss = E.Missing(st, p, ud.requires)
        if miss then return false, "requires " .. miss end
        if ud.hero then
            local okHero, why = E.CanTrainHero(st, p, cmd.utype)
            if not okHero then return false, why end
        end
        if not E.CanAfford(st, p, ud.cost) then return false, "not enough gold or lumber" end
        E.Food(st)
        local pl = st.players[p]
        if pl.food + ud.food > pl.foodCap then return false, "build more " .. (pl.faction == "orc" and "burrows" or "farms") end
        pl.gold, pl.lumber = pl.gold - ud.cost[1], pl.lumber - ud.cost[2]
        table.insert(b.queue, cmd.utype)
        E.Food(st)
        return true
    elseif t == "buy" or t == "useItem" then
        return E.ArmyCommand(st, p, cmd)
    elseif t == "learn" or t == "cast" or t == "revive" then
        return E.HeroCommand(st, p, cmd, mode)
    elseif t == "research" then
        local b = st.ents[cmd.building]
        if not b or b.owner ~= p or b.kind ~= "building" or b.progress < 1 then return false, "not ready" end
        local ok, why = E.CanResearch(st, p, cmd.key, b)
        if not ok then return false, why end
        if #b.queue >= 5 then return false, "the queue is full" end
        local r = D().Research[cmd.key]
        local cost = r.cost[E.Level(st, p, cmd.key) + 1]
        if not E.CanAfford(st, p, cost) then return false, "not enough gold or lumber" end
        local pl = st.players[p]
        pl.gold, pl.lumber = pl.gold - cost[1], pl.lumber - cost[2]
        pl.busy[cmd.key] = true
        table.insert(b.queue, "r:" .. cmd.key)
        return true
    elseif t == "cancel" then
        local b = st.ents[cmd.building]
        if not b or b.owner ~= p or #b.queue == 0 then return false end
        local q = table.remove(b.queue)
        if #b.queue == 0 then b.trainT = 0 end
        local pl = st.players[p]
        local cost
        if q:sub(1, 2) == "r:" then
            local key = q:sub(3)
            cost = D().Research[key].cost[E.Level(st, p, key) + 1]
            pl.busy[key] = nil
        elseif q:sub(1, 2) == "v:" then
            local ut = q:sub(3)
            cost = E.ReviveCost(st, p, ut)
            if pl.fallen and pl.fallen[ut] then pl.fallen[ut].reviving = nil end
        else
            cost = D().Units[q].cost
        end
        pl.gold, pl.lumber = pl.gold + cost[1], pl.lumber + cost[2]
        E.Food(st)
        return true
    elseif t == "surrender" then
        -- Give up: everything of yours goes; your allies play on.
        local mine = {}
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and e.owner == p then table.insert(mine, e) end
        end
        for _, e in ipairs(mine) do Remove(st, e) end
        E.Food(st)
        Emit("surrendered", { owner = p })
        return true
    elseif t == "cancelBuild" then
        -- Cancel a building still going up: 75% back, like Warcraft III.
        local b = st.ents[cmd.building]
        if not b or b.owner ~= p or b.kind ~= "building" or b.progress >= 1 then return false end
        local cost = Def(b).cost
        local pl = st.players[p]
        pl.gold = pl.gold + math.floor(cost[1] * 0.75)
        pl.lumber = pl.lumber + math.floor(cost[2] * 0.75)
        for _, id in ipairs(st.list) do
            local u = st.ents[id]
            if u and u.kind == "unit" and u.order and u.order.site == b.id then E.Order(st, u, nil) end
        end
        Remove(st, b)
        E.Food(st)
        Emit("cancelled", { id = b.id, owner = p, type = b.type })
        return true
    elseif t == "rally" then
        local b = st.ents[cmd.building]
        if not b or b.owner ~= p then return false end
        b.rally = { x = cmd.x, y = cmd.y, target = cmd.target, tree = cmd.tree }
        return true
    end
    return false, "unknown command"
end

---------------------------------------------------------------------------
-- Time passes
---------------------------------------------------------------------------
-- A fingerprint of the game (lockstep: both sides must get the same one).
function E.Hash(st)
    local a, b, c = 0, 0, 0
    for k, id in ipairs(st.list) do
        local e = st.ents[id]
        if e then
            a = a + id * (e.x * 3.1 + e.y * 7.3)
            b = b + k * (e.hp + (e.progress or 0) * 11)
            c = c + #(e.order and e.order.type or "") * id
        end
    end
    for i, p in ipairs(st.players) do
        a = a + i * (p.gold * 2 + p.lumber * 5)
        for key, level in pairs(p.up or {}) do c = c + #key * level * i end
    end
    for i, n in pairs(st.trees) do c = c + i % 97 * n end
    return string.format("%.6f:%.6f:%d:%d", a, b, c, #st.list)
end

function E.Step(st, dt)
    if st.over then return {} end
    local events = {}
    EV = events
    st.time = st.time + dt
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e then
            if e.kind == "unit" then UnitStep(st, e, dt)
            elseif e.kind == "building" then BuildingStep(st, e, dt) end
        end
    end
    if E.WorldTick then E.WorldTick(st, dt) end
    -- Units don't stack: standing units that overlap push apart. Units on
    -- the move pass through (pushing walkers apart can deadlock two units
    -- heading for the same spot), and so do harvesting workers (as in
    -- Warcraft III) and units in a mine or burrow.
    local movers = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        local walking = e and e.path and e.path[e.pathi or 1]
        if e and e.kind == "unit" and not e.inside and not e.insideBuild and not walking and not D().Units[e.type].air
            and not (e.order and e.order.type == "gather") then
            table.insert(movers, e)
        end
    end
    for i = 1, #movers do
        local a = movers[i]
        for j = i + 1, #movers do
            local b = movers[j]
            local dx, dy = b.x - a.x, b.y - a.y
            local d2 = dx * dx + dy * dy
            if d2 < 0.36 then
                local d = math.sqrt(d2)
                if d < 0.01 then dx, dy, d = (Rand(st, 3) - 2) * 0.1 + 0.05, 0.05, 0.1 end
                local push = (0.6 - d) * 0.25
                local px, py = dx / d * push, dy / d * push
                if not Blocked(st, math.floor(a.x - px), math.floor(a.y - py)) then a.x, a.y = a.x - px, a.y - py end
                if not Blocked(st, math.floor(b.x + px), math.floor(b.y + py)) then b.x, b.y = b.x + px, b.y + py end
            end
        end
    end
    -- Forget the dead.
    local keep = {}
    for _, id in ipairs(st.list) do if st.ents[id] then table.insert(keep, id) end end
    st.list = keep
    E.Food(st)
    -- Whoever has no buildings left is out; the last team standing wins.
    local has, teams, last = {}, {}, nil
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.kind == "building" and e.owner > 0 then has[e.owner] = true end
    end
    local alive = 0
    for p = 1, #st.players do
        if has[p] then
            local t = E.Team(st, p)
            if not teams[t] then teams[t], alive = true, alive + 1 end
            last = last or p
        elseif not st.players[p].out then
            st.players[p].out = true
            Emit("defeated", { owner = p })
        end
    end
    if alive <= 1 then
        st.over = true
        st.winner = last or 0 -- a player of the winning team
        Emit("over", { winner = st.winner })
    end
    EV = nil
    return events
end

-- Count a player's things: units by type, buildings by type (finished or not).
function E.Count(st, p)
    local c = { units = {}, buildings = {}, building = {}, army = 0, workers = 0 }
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p then
            if e.kind == "unit" then
                c.units[e.type] = (c.units[e.type] or 0) + 1
                if D().Units[e.type].worker then c.workers = c.workers + 1 else c.army = c.army + 1 end
            elseif e.kind == "building" then
                if e.progress >= 1 then c.buildings[e.type] = (c.buildings[e.type] or 0) + 1
                else c.building[e.type] = (c.building[e.type] or 0) + 1 end
            end
        end
    end
    return c
end

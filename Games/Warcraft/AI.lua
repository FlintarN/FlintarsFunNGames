-- Warcraft III (RTS) AI: a build order and attack waves. It only uses
-- E.Command, like a player, so it can't cheat. Call AI.Think about once a
-- second; it keeps its memory in st.ai[p] (plain data, saved with the game).
local ADDON, ns = ...

ns.WC = ns.WC or {}
local AI = {}
ns.WC.AI = AI

local function E() return ns.WC.Engine end
local function D() return ns.WC end

-- A free spot for a building near (cx, cy), with a tile of space around it.
function AI.FindSpot(st, cx, cy, size)
    cx, cy = math.floor(cx), math.floor(cy)
    for r = 3, 14 do
        for dy = -r, r do
            for dx = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local x, y = cx + dx, cy + dy
                    if E().CanPlace(st, x - 1, y - 1, size + 2) then return x, y end
                end
            end
        end
    end
end

local function Mine(st, p)
    local hall = E().Hall(st, p)
    if not hall then return nil end
    return E().NearestMine(st, E().Center(hall))
end

-- What the computer researches, in order of preference.
AI.RESEARCH = { "keep", "stronghold", "guard_tower", "swords", "melee_o", "gunpowder", "ranged_o", "plating",
    "armor_o", "harvest", "long_rifles", "berserker", "regeneration", "masonry", "defenses", "castle", "fortress" }

function AI.Think(st, p)
    st.ai = st.ai or {}
    local diff = D().DIFFICULTY[st.difficulty or "normal"] or D().DIFFICULTY.normal
    local mem = st.ai[p] or { wave = diff.wave, waves = 0 }
    st.ai[p] = mem
    st.players[p].income = diff.income
    -- Easy thinks less often.
    mem.tick = (mem.tick or 0) + 1
    if mem.tick % diff.think ~= 0 then return end
    local E_ = E()
    local pl = st.players[p]
    local f = D().Factions[pl.faction]
    local hall = E_.Hall(st, p)
    local count = E_.Count(st, p)
    local workers, army, onGold, onWood, idle = {}, {}, 0, 0, {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "unit" then
            if D().Units[e.type].worker then
                table.insert(workers, e)
                local o = e.order
                if not o then table.insert(idle, e)
                elseif o.type == "gather" and o.res == "gold" then onGold = onGold + 1
                elseif o.type == "gather" then onWood = onWood + 1 end
            else
                table.insert(army, e)
            end
        end
    end

    -- Idle workers go to work: about five on gold, the rest on lumber.
    local mine = Mine(st, p)
    for _, u in ipairs(idle) do
        if mine and onGold < 5 then
            E_.Command(st, p, { type = "gather", units = { u.id }, target = mine.id })
            onGold = onGold + 1
        else
            local cx, cy = u.x, u.y
            if hall then cx, cy = E_.Center(hall) end
            local tree = E_.NearestTree(st, cx, cy)
            if tree then E_.Command(st, p, { type = "gather", units = { u.id }, tree = tree }) onWood = onWood + 1 end
        end
    end

    if not hall then return end
    local hx, hy = E_.Center(hall)

    -- A builder: someone chopping wood if possible.
    local function Builder()
        for _, u in ipairs(workers) do
            if u.order and u.order.type == "gather" and u.order.res == "lumber" and not u.carry then return u end
        end
        for _, u in ipairs(workers) do
            if not (u.order and u.order.type == "build") then return u end
        end
    end
    local function Build(btype)
        local bd = D().Buildings[btype]
        if not E_.CanAfford(st, p, bd.cost) then return false end
        local u = Builder()
        if not u then return false end
        -- Away from the mine side, so the mining path stays open.
        local mx, my = hx, hy
        if mine then mx, my = E_.Center(mine) end
        local x, y = AI.FindSpot(st, hx + (hx - mx) * 0.6, hy + (hy - my) * 0.6, bd.size)
        if not x then return false end
        return E_.Command(st, p, { type = "build", unit = u.id, btype = btype, x = x, y = y })
    end

    -- Supply first.
    local building = count.building[f.farm] or 0
    if pl.foodCap < D().FOOD_MAX and pl.foodCap - pl.food <= 4 and building == 0 then
        if Build(f.farm) then return end
    end
    -- Workers.
    if count.workers < diff.workers and #hall.queue == 0 then
        E_.Command(st, p, { type = "train", building = hall.id, utype = f.worker })
    end
    -- A barracks, then a second one later.
    local barracks = (count.buildings[f.barracks] or 0) + (count.building[f.barracks] or 0)
    if barracks == 0 and count.workers >= 6 then
        if Build(f.barracks) then return end
    elseif barracks == 1 and diff.secondRax and st.time > diff.secondRax and pl.gold > 450 then
        Build(f.barracks)
    end
    -- The smithy (Blacksmith / War Mill): ranged units and upgrades.
    local smith = (count.buildings[f.smith] or 0) + (count.building[f.smith] or 0)
    if barracks >= 1 and smith == 0 and count.workers >= 7 and pl.gold > 220 then
        if Build(f.smith) then return end
    end
    -- Humans also want a Lumber Mill (Guard Towers, Masonry, faster lumber).
    if f.mill ~= f.smith then
        local mill = (count.buildings[f.mill] or 0) + (count.building[f.mill] or 0)
        if smith >= 1 and mill == 0 and st.time > 240 and pl.gold > 180 then
            if Build(f.mill) then return end
        end
    end
    -- Research (not on Easy): the hall's next tier after a while, then
    -- upgrades, one at a time, keeping gold for the army.
    if diff.research ~= false and st.time > 240 then
        for _, id in ipairs(st.list) do
            local b = st.ents[id]
            if b and b.owner == p and b.kind == "building" and b.progress >= 1 and #b.queue == 0 then
                for _, key in ipairs(AI.RESEARCH) do
                    local r = D().Research[key]
                    if r.building == b.type and E_.CanResearch(st, p, key, b) and (not r.upgrade or not D().Buildings[r.upgrade].hall
                        or st.time > 420) then
                        local cost = r.cost[E_.Level(st, p, key) + 1]
                        if pl.gold >= cost[1] and pl.lumber >= cost[2] then
                            E_.Command(st, p, { type = "research", building = b.id, key = key })
                            mem.save = nil
                        elseif pl.lumber >= cost[2] and not mem.save then
                            -- Save up for it: soldiers wait a little.
                            mem.save = { gold = cost[1], since = st.time }
                        end
                        break
                    end
                end
            end
        end
    end
    -- A tower by the hall (not on Easy).
    local towers = (count.buildings[f.tower] or 0) + (count.building[f.tower] or 0)
        + (f.tower == "scout_tower" and ((count.buildings.guard_tower or 0) + (count.building.guard_tower or 0)) or 0)
    if diff.alarm and barracks >= 1 and towers == 0 and st.time > 300 and pl.gold > 300 then
        if Build(f.tower) then return end
    end
    -- Soldiers: melee and ranged in turn (unless saving up for research).
    if mem.save and (pl.gold >= mem.save.gold or st.time - mem.save.since > 25) then mem.save = nil end
    local saving = mem.save ~= nil
    for _, id in ipairs(saving and {} or st.list) do
        local b = st.ents[id]
        if b and b.owner == p and b.type == f.barracks and b.progress >= 1 and #b.queue < 2 then
            mem.flip = not mem.flip
            local ut = mem.flip and f.melee or f.ranged
            if not E_.Command(st, p, { type = "train", building = b.id, utype = ut }) then
                E_.Command(st, p, { type = "train", building = b.id, utype = mem.flip and f.ranged or f.melee })
            end
        end
    end

    -- Defend: enemies near the base pull the army home.
    local threat
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner ~= p and e.owner > 0 and e.kind == "unit" then
            if (e.x - hx) ^ 2 + (e.y - hy) ^ 2 < 14 * 14 then threat = e break end
        end
    end
    local ids = {}
    for _, u in ipairs(army) do table.insert(ids, u.id) end
    if diff.alarm and threat and not mem.alarm and #army < 4 then
        if E_.Command(st, p, { type = f.alarm, building = hall.id }) then mem.alarm = st.time end
    elseif not threat and mem.alarm and st.time - mem.alarm > 8 then
        E_.Command(st, p, { type = "backToWork" })
        mem.alarm = nil
    end
    if threat and #ids > 0 then
        E_.Command(st, p, { type = "attackMove", units = ids, x = threat.x, y = threat.y })
        mem.defending = true
        return
    end
    -- Attack in waves that grow each time.
    -- Out of money for more soldiers for a while: go with what we have.
    local cheapest = math.min(D().Units[f.melee].cost[1], D().Units[f.ranged].cost[1])
    if pl.gold >= cheapest then mem.broke = nil elseif not mem.broke then mem.broke = st.time end
    local stuck = mem.broke and st.time - mem.broke > 45 and #army >= 3
    if (#army >= mem.wave or stuck) and st.time >= diff.firstAttack then
        local target = E_.Hall(st, 3 - p)
        local tx, ty
        if target then
            tx, ty = E_.Center(target)
        else
            for _, id in ipairs(st.list) do
                local e = st.ents[id]
                if e and e.owner == 3 - p and e.kind == "building" then tx, ty = E_.Center(e) break end
            end
        end
        if tx then
            E_.Command(st, p, { type = "attackMove", units = ids, x = tx, y = ty })
            mem.waves = mem.waves + 1
            mem.wave = math.min(diff.waveMax, mem.wave + diff.waveGrow)
        end
    elseif mem.defending then
        mem.defending = false
        -- Back to a spot in front of the base.
        local idleArmy = {}
        for _, u in ipairs(army) do if not u.order then table.insert(idleArmy, u.id) end end
        if #idleArmy > 0 then
            E_.Command(st, p, { type = "move", units = idleArmy, x = hx + (st.w / 2 - hx) * 0.15, y = hy + (st.h / 2 - hy) * 0.15 })
        end
    end
end

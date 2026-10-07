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

-- Heroes the computer likes, in order; how many per difficulty.
AI.HEROES = { human = { "mountain_king", "paladin", "archmage", "blood_mage" },
    orc = { "blademaster", "far_seer", "tauren_chieftain", "shadow_hunter" } }
AI.HERO_COUNT = { easy = 1, normal = 2, hard = 3 }

local function Dist2(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end

-- Enemy units (not buildings) within r of (x, y).
local function EnemiesNear(st, p, x, y, r)
    local out = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and E().Foe(st, e.owner, p) and not (E().Untouchable(e) or E().Hidden(e))
            and (e.x - x) ^ 2 + (e.y - y) ^ 2 <= r * r then
            table.insert(out, e)
        end
    end
    return out
end

-- Spend skill points: the ultimate when allowed, else the lowest of the
-- first three (in order).
function AI.Learn(st, p, h)
    local list = D().Units[h.type].abilities
    while (h.points or 0) > 0 do
        local pick
        if h.level >= 6 and E().Skill(h, list[4]) == 0 then pick = list[4] end
        if not pick then
            local best
            for i = 1, 3 do
                local lv = E().Skill(h, list[i])
                if lv < 3 and h.level >= lv * 2 + 1 and (not best or lv < best) then pick, best = list[i], lv end
            end
        end
        if not pick or not E().Command(st, p, { type = "learn", unit = h.id, ability = pick }) then return end
    end
end

-- One spell a second, when it helps.
function AI.HeroCast(st, p, h)
    if h.order and h.order.type == "cast" then return end
    local A = D().Abilities
    for _, key in ipairs(D().Units[h.type].abilities) do
        local a = A[key]
        local lv = E().Skill(h, key)
        local mana = a.mana and (a.mana[lv] or a.mana[#a.mana]) or 0
        if lv > 0 and not a.passive and not (h.cds and h.cds[key]) and (h.mana or 0) >= mana then
            local range = (a.range or 0) + 1
            local cmd
            if a.target == "ally" then
                local worst, best
                for _, id in ipairs(st.list) do
                    local e = st.ents[id]
                    if e and e.kind == "unit" and e.owner == p and e.hp < e.maxHp * 0.55 and Dist2(e, h) <= range * range then
                        local missing = e.maxHp - e.hp
                        if not best or missing > best then worst, best = e, missing end
                    end
                end
                if worst then cmd = { target = worst.id } end
            elseif a.target == "enemy" or a.target == "unit" then
                local foes = EnemiesNear(st, p, h.x, h.y, range)
                local pick
                for _, e in ipairs(foes) do
                    local hero = E().IsHero(e)
                    if key == "siphon_mana" then
                        if hero and (e.mana or 0) > 50 then pick = e end
                    elseif hero then
                        pick = e
                    elseif not pick and (key == "storm_bolt" or key == "chain_lightning") then
                        pick = e
                    end
                end
                if pick then cmd = { target = pick.id } end
            elseif a.target == "point" then
                if key == "earthquake" then
                    for _, id in ipairs(st.list) do
                        local e = st.ents[id]
                        if e and e.kind == "building" and E().Foe(st, e.owner, p) and Dist2(e, h) <= range * range then
                            local cx, cy = E().Center(e)
                            cmd = { x = cx, y = cy }
                            break
                        end
                    end
                elseif key == "serpent_ward" then
                    if #EnemiesNear(st, p, h.x, h.y, 6) > 0 then cmd = { x = h.x + 1, y = h.y } end
                elseif key ~= "far_sight" then
                    for _, e in ipairs(EnemiesNear(st, p, h.x, h.y, range)) do
                        if #EnemiesNear(st, p, e.x, e.y, a.radius or 2) >= 3 then
                            cmd = { x = e.x, y = e.y }
                            break
                        end
                    end
                end
            elseif a.target == "friend" then
                if h.hp < h.maxHp * 0.25 and #EnemiesNear(st, p, h.x, h.y, 6) > 0 then
                    local hall = E().Hall(st, p)
                    if hall then cmd = { target = hall.id } end
                end
            elseif a.target == "self" then
                local close = #EnemiesNear(st, p, h.x, h.y, 3.5)
                local around = #EnemiesNear(st, p, h.x, h.y, 8)
                if key == "divine_shield" then
                    if h.hp < h.maxHp * 0.3 and around > 0 then cmd = {} end
                elseif key == "thunder_clap" or key == "war_stomp" or key == "bladestorm" then
                    if close >= 3 then cmd = {} end
                elseif key == "avatar" or key == "big_bad_voodoo" then
                    if around >= 5 then cmd = {} end
                elseif key == "resurrection" then
                    local n = 0
                    for _, c in ipairs(st.corpses or {}) do
                        if c.owner == p and (c.x - h.x) ^ 2 + (c.y - h.y) ^ 2 <= 81 then n = n + 1 end
                    end
                    if n >= 3 then cmd = {} end
                elseif key == "wind_walk" then
                    if h.hp < h.maxHp * 0.25 and around > 0 then cmd = {} end
                elseif a.summon or key == "mirror_image" then
                    if around > 0 then cmd = {} end
                end
            end
            if cmd then
                cmd.type, cmd.unit, cmd.ability = "cast", h.id, key
                if E().Command(st, p, cmd) then return end
            end
        end
    end
end

-- Buildings for more kinds of units, in order.
AI.TECH = { human = { "arcane_sanctum", "workshop", "gryphon_aviary" }, orc = { "beastiary", "spirit_lodge", "tauren_totem" } }

-- What the computer researches, in order of preference.
AI.RESEARCH = { "keep", "stronghold", "guard_tower", "swords", "melee_o", "gunpowder", "ranged_o", "plating",
    "armor_o", "harvest", "long_rifles", "berserker", "regeneration", "masonry", "defenses", "castle", "fortress" }

function AI.Think(st, p)
    st.ai = st.ai or {}
    local level = st.players[p].difficulty or st.difficulty or "normal"
    local diff = D().DIFFICULTY[level] or D().DIFFICULTY.normal
    local mem = st.ai[p] or { wave = diff.wave, waves = 0 }
    st.ai[p] = mem
    st.players[p].income = diff.income
    -- Easy thinks less often.
    mem.tick = (mem.tick or 0) + 1
    if mem.tick % diff.think ~= 0 then return end
    local E_ = E()
    local pl = st.players[p]
    local f = D().Factions[pl.faction]
    -- Heroes first (the rest below can stop early): skills and spells.
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and E_.IsHero(e) and not e.illusion then
            AI.Learn(st, p, e)
            AI.HeroCast(st, p, e)
        end
    end
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
    -- Later buildings for more kinds of units, as the hall's tier allows.
    if diff.research ~= false and pl.gold > 320 then
        for _, bt in ipairs(AI.TECH[pl.faction] or {}) do
            local have = (count.buildings[bt] or 0) + (count.building[bt] or 0)
            if have == 0 and not E_.Missing(st, p, D().Buildings[bt].requires) then
                if Build(bt) then return end
                break
            end
        end
    end
    -- An altar, heroes (revived when they fall), skills and spells.
    if f.altar then
        local altars = (count.buildings[f.altar] or 0) + (count.building[f.altar] or 0)
        if barracks >= 1 and smith >= 1 and altars == 0 and pl.gold > 250 then
            if Build(f.altar) then return end
        end
        local altar
        for _, id in ipairs(st.list) do
            local b = st.ents[id]
            if b and b.owner == p and b.type == f.altar and b.progress >= 1 then altar = b end
        end
        local heroes = 0
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and e.owner == p and E_.IsHero(e) and not e.illusion then heroes = heroes + 1 end
        end
        if altar and #altar.queue == 0 then
            local revived = false
            for ut, fallen in pairs(pl.fallen or {}) do
                if not fallen.reviving and not revived then
                    revived = E_.Command(st, p, { type = "revive", building = altar.id, utype = ut })
                end
            end
            if not revived and heroes < (AI.HERO_COUNT[level] or 2) then
                for _, ut in ipairs(AI.HEROES[pl.faction] or {}) do
                    if E_.CanTrainHero(st, p, ut) then
                        if E_.Command(st, p, { type = "train", building = altar.id, utype = ut }) then
                            mem.save = nil
                        elseif not (mem.save and mem.save.hero) then
                            -- Save up for the hero (before research): soldiers wait a little.
                            mem.save = { gold = D().Units[ut].cost[1], since = st.time, hero = true }
                        end
                        break
                    end
                end
            end
        end
    end
    -- Research (not on Easy): the hall's next tier after a while, then
    -- upgrades, one at a time, keeping gold for the army.
    if diff.research ~= false and st.time > 240 and not (mem.save and mem.save.hero) then
        for _, id in ipairs(st.list) do
            local b = st.ents[id]
            if b and b.owner == p and b.kind == "building" and b.progress >= 1 and #b.queue == 0 then
                for _, key in ipairs(AI.RESEARCH) do
                    local r = D().Research[key]
                    if r.building == b.type and E_.CanResearch(st, p, key, b) and (not r.upgrade or not D().Buildings[r.upgrade].hall
                        or st.time > 360) then
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
    if mem.save and (pl.gold >= mem.save.gold + 50 or st.time - mem.save.since > 45) then mem.save = nil end
    local saving = mem.save ~= nil
    for _, id in ipairs(saving and {} or st.list) do
        local b = st.ents[id]
        local bd = b and b.kind == "building" and E_.Def(b)
        if b and b.owner == p and bd and bd.trains and not bd.hall and b.progress >= 1 and #b.queue < 2
            and not D().Units[bd.trains[1]].hero then
            -- Each building trains its units in turn (what it can afford and has the tech for).
            mem.rot = (mem.rot or 0) + 1
            local n = #bd.trains
            for k = 0, n - 1 do
                local ut = bd.trains[(mem.rot + k) % n + 1]
                if E_.Command(st, p, { type = "train", building = b.id, utype = ut }) then break end
            end
        end
    end

    -- Defend: enemies near the base pull the army home.
    local threat
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and E().Foe(st, e.owner, p) and e.kind == "unit" and not st.players[e.owner].neutral then -- (not creeps)
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
        -- The nearest enemy player's hall (or any building of theirs).
        local tx, ty, best
        for q = 1, #st.players do
            if E_.Foe(st, p, q) then
                local target = E_.Hall(st, q)
                if not target then
                    for _, id in ipairs(st.list) do
                        local e = st.ents[id]
                        if e and e.owner == q and e.kind == "building" then target = e break end
                    end
                end
                if target then
                    local cx, cy = E_.Center(target)
                    local d = (cx - hx) ^ 2 + (cy - hy) ^ 2
                    if not best or d < best then tx, ty, best = cx, cy, d end
                end
            end
        end
        -- Only those not already in a fight (a new order would pull them out of it).
        -- (Every 30 s the marching ones too, in case they're stuck on the way.)
        local go = {}
        local fresh = st.time - (mem.sentAt or -999) >= 30
        for _, u in ipairs(army) do
            local o = u.order
            if not o or not (o.type == "attack" or (o.type == "attackMove" and not fresh)) then table.insert(go, u.id) end
        end
        if fresh and #go > 0 then mem.sentAt = st.time end
        if tx and #go > 0 then
            E_.Command(st, p, { type = "attackMove", units = go, x = tx, y = ty })
            if #go >= #army / 2 then
                mem.waves = mem.waves + 1
                mem.wave = math.min(diff.waveMax, mem.wave + diff.waveGrow)
            end
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

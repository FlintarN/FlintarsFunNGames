-- Warcraft III (RTS): the engine and the AI, without any UI.
local WC = ns.WC
local E = WC.Engine

local function Run(st, seconds, dt, ai)
    dt = dt or 0.1
    local t, think = 0, 0
    while t < seconds and not st.over do
        E.Step(st, dt)
        t = t + dt
        think = think + dt
        if ai and think >= 1 then
            think = 0
            for _, p in ipairs(ai) do WC.AI.Think(st, p) end
        end
    end
end

local function Units(st, p, utype)
    local out = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and e.kind == "unit" and (not utype or e.type == utype) then table.insert(out, e) end
    end
    return out
end

function WcEngineTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 3 })
    local c1, c2 = E.Count(st, 1), E.Count(st, 2)
    check(c1.workers == 5 and c2.workers == 5, "wc: five workers each")
    check(c1.buildings.town_hall == 1 and c2.buildings.great_hall == 1, "wc: a hall each")
    check(E.NearestMine(st, 0, 0) and E.NearestMine(st, 64, 40) and E.NearestMine(st, 0, 0) ~= E.NearestMine(st, 64, 40), "wc: a mine each")
    local trees = 0
    for _ in pairs(st.trees) do trees = trees + 1 end
    check(trees > 300, "wc: forests (" .. trees .. " trees)")
    check(st.players[1].foodCap == 12 and st.players[1].food == 5, "wc: food 5/12")
    -- The map is mirrored: both halls can reach each other.
    local h1, h2 = E.Hall(st, 1), E.Hall(st, 2)
    local x1, y1 = E.Center(h1)
    local x2, y2 = E.Center(h2)
    local path = E.AStar(st, math.floor(x1), math.floor(y1) + 3,
        function(x, y) return math.abs(x - x2) < 3 and math.abs(y - y2) < 3 end, x2, y2, 20000)
    check(#path > 20, "wc: there's a way from base to base (" .. #path .. " steps)")

    -- Mining.
    local gold0 = st.players[1].gold
    Run(st, 30)
    check(st.players[1].gold > gold0 + 50, "wc: workers bring gold (" .. st.players[1].gold - gold0 .. " in 30 s)")

    -- Lumber.
    local w = Units(st, 1, "peasant")[1]
    local tree = E.NearestTree(st, x1, y1)
    E.Command(st, 1, { type = "gather", units = { w.id }, tree = tree })
    local lumber0 = st.players[1].lumber
    Run(st, 40)
    check(st.players[1].lumber > lumber0, "wc: a worker chops lumber (" .. st.players[1].lumber - lumber0 .. ")")

    -- Training: costs gold and food, the unit walks out.
    local before = #Units(st, 1, "peasant")
    local gold = st.players[1].gold
    check(E.Command(st, 1, { type = "train", building = h1.id, utype = "peasant" }), "wc: train a peasant")
    check(st.players[1].gold == gold - 75 and st.players[1].food == 6, "wc: it costs 75 gold and a food")
    check(not E.Command(st, 1, { type = "train", building = h1.id, utype = "footman" }), "wc: the hall can't train footmen")
    Run(st, 11)
    check(#Units(st, 1, "peasant") == before + 1, "wc: the peasant comes out")

    -- Building: a farm raises the food cap.
    st.players[1].gold, st.players[1].lumber = 1000, 1000
    local spot = { WC.AI.FindSpot(st, x1 + 4, y1 + 4, 2) }
    check(spot[1] ~= nil, "wc: a place for a farm")
    check(E.Command(st, 1, { type = "build", unit = w.id, btype = "farm", x = spot[1], y = spot[2] }), "wc: build a farm")
    check(not E.Command(st, 1, { type = "build", unit = w.id, btype = "orc_burrow", x = spot[1], y = spot[2] }), "wc: humans can't build orc burrows")
    Run(st, 40)
    check(E.Count(st, 1).buildings.farm == 1 and st.players[1].foodCap == 18, "wc: the farm is up, food 18")
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.type == "farm" then check(e.hp == e.maxHp, "wc: a finished farm has full health (not 499/500)") end
    end
    check(w.order and w.order.type == "gather", "wc: the builder goes back to work")
    -- Food limit.
    st.players[1].gold = 99999
    local bx, by = WC.AI.FindSpot(st, x1 + 6, y1 + 6, 3)
    E.Command(st, 1, { type = "build", unit = w.id, btype = "barracks", x = bx, y = by })
    Run(st, 45)
    local rax
    for _, id in ipairs(st.list) do if st.ents[id].type == "barracks" then rax = st.ents[id] end end
    check(rax and rax.progress >= 1, "wc: barracks built")
    local ok, why
    for _ = 1, 6 do ok, why = E.Command(st, 1, { type = "train", building = rax.id, utype = "rifleman" }) end
    check(not ok and why and why:find("farms") ~= nil, "wc: no food, no rifleman (" .. tostring(why) .. ")")
    E.Command(st, 1, { type = "cancel", building = rax.id })
    check(#rax.queue >= 1, "wc: cancel gives one back")

    -- Fighting: a footman kills a peon; idle soldiers hit back.
    st = E.New({ factions = { "human", "orc" }, seed = 5 })
    local fm = E.Spawn(st, 1, "footman", 32, 20)
    local peon = E.Spawn(st, 2, "peon", 33, 20)
    E.Command(st, 1, { type = "attack", units = { fm.id }, target = peon.id })
    Run(st, 30)
    check(peon.dead and not fm.dead, "wc: the footman kills the peon")
    local grunt = E.Spawn(st, 2, "grunt", 36, 20)
    Run(st, 3)
    check(fm.order and fm.order.type == "attack" and fm.order.target == grunt.id, "wc: an idle footman takes on the grunt in sight")
    Run(st, 40)
    check(fm.dead or grunt.dead, "wc: one of them falls")
    -- Ranged: riflemen shoot from afar.
    local rf = E.Spawn(st, 1, "rifleman", 30, 25)
    local tgt = E.Spawn(st, 2, "peon", 34, 25)
    E.Command(st, 1, { type = "attack", units = { rf.id }, target = tgt.id })
    Run(st, 1)
    check(math.abs(rf.x - 30) < 0.5 and tgt.hp < tgt.maxHp, "wc: a rifleman shoots from range")
    -- Attack-move picks fights on the way.
    local fm2 = E.Spawn(st, 1, "footman", 10, 20)
    local p2 = E.Spawn(st, 2, "peon", 16, 21)
    E.Command(st, 1, { type = "attackMove", units = { fm2.id }, x = 40, y = 20 })
    Run(st, 45)
    check(p2.dead, "wc: attack-move fights what it meets")

    -- Losing every building ends the game.
    st = E.New({ factions = { "human", "orc" }, seed = 7 })
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 2 and e.kind == "building" then
            e.hp = 1
            local x, y = E.Center(e)
            local r = E.Spawn(st, 1, "rifleman", x, y + e.size)
            E.Command(st, 1, { type = "attack", units = { r.id }, target = e.id })
        end
    end
    Run(st, 20)
    check(st.over and st.winner == 1, "wc: no buildings left, no game")
end

-- Whole games, AI against AI.
function WcAIGames()
    local wins, minutes = { 0, 0, [0] = 0 }, 0
    for seed = 1, 3 do
        local st = E.New({ factions = seed % 2 == 0 and { "orc", "human" } or { "human", "orc" }, seed = seed * 31 })
        Run(st, 75 * 60, 0.2, { 1, 2 })
        check(st.over, "wc: AI game " .. seed .. " ends (" .. math.floor(st.time / 60) .. " min)")
        local c = E.Count(st, st.winner or 1)
        check((c.buildings.farm or 0) + (c.buildings.orc_burrow or 0) >= 1, "wc: the winner built farms")
        wins[st.winner or 0] = wins[st.winner or 0] + 1
        minutes = minutes + st.time / 60
    end
    print(string.format("  wc: AI games: p1 %d, p2 %d, draws %d; %.1f min a game", wins[1], wins[2], wins[0], minutes / 3))
end

-- The page: start, select, build, train, command, play on.
function WcPageTests()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    Advance(0)
    ns.Cards.Tick(true)
    -- Fullscreen: on for this game, off again on a tab without it.
    check(ns.UI.fullButton:IsShown(), "wc page: a Fullscreen button")
    ns.UI:ToggleFull()
    check(ns.UI.full and ns.UI.backdrop:IsShown() and ns.UI.frame:GetScale() > 1, "wc page: fullscreen fills the screen")
    ns.UI:SelectTab("home")
    check(not ns.UI.full and not ns.UI.backdrop:IsShown(), "wc page: other tabs use the normal window")
    ns.UI:SelectTab("warcraft")
    check(ns.UI.full, "wc page: fullscreen is remembered")
    ns.UI:ToggleFull()
    check(not ns.UI.full and ns.UI.frame:GetScale() == (ns.db.scale or 1), "wc page: back to the window")
    local view = ns.UI.pages.warcraft.view
    check(view.overlay:IsShown() and #view.picks == 2, "wc page: choose a side")
    check(math.floor(ns.UI.frame:GetWidth() + 0.5) == 760, "wc page: the bigger window")
    view.picks[1]._scripts.OnClick()
    local st = view.st
    check(st and st.players[1].faction == "human" and not view.overlay:IsShown(), "wc page: a game as Human")
    check(ns.Solo.Running("warcraft") and ns.db.warcraft.game == st, "wc page: running and saved")
    local function Run(seconds)
        for _ = 1, math.floor(seconds / 0.1) do view:Tick(0.1) end
    end
    Run(2)
    -- Select a worker by clicking where it stands.
    local worker
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 1 and e.type == "peasant" and not e.inside then worker = e break end
    end
    view:SelectAt(worker.x, worker.y)
    check(#view.sel == 1 and view.sel[1] == worker.id, "wc page: click selects a worker")
    -- Double-click: every peasant on screen; Ctrl+1 keeps them as group 1.
    view:SelectAt(worker.x, worker.y)
    local all = #view.sel
    check(all > 1, "wc page: double-click selects all peasants on screen (" .. all .. ")")
    local oldCtrl = IsControlKeyDown
    IsControlKeyDown = function() return true end
    view:Key("1")
    IsControlKeyDown = oldCtrl
    view.lastClick = nil
    view:SelectAt(worker.x, worker.y)
    check(#view.sel == 1, "wc page: one click again: one")
    view:Key("1")
    check(#view.sel == all, "wc page: 1 selects group 1 again")
    view.sel, view.lastClick = { worker.id }, nil
    -- Depth: a unit lower on the map has its camera nearer (so it's drawn in front).
    Advance(0.5)
    view:Draw()
    view:Draw()
    local near, far
    for id, f in pairs(view.unitFrames) do
        local e = st.ents[id]
        if e and f.model and f.model.depth then
            if not near or e.y > near.y + 0.6 then near = { y = e.y, d = f.model.depth } end
            if not far or e.y < far.y - 0.6 then far = { y = e.y, d = f.model.depth } end
        end
    end
    check(near and far, "wc page: units have a depth")
    if near and far and near.y > far.y then check(near.d < far.d, "wc page: lower on the map, nearer the camera") end
    view:Draw()
    local labels = {}
    for _, c in ipairs(view.cmds) do if c:IsShown() then table.insert(labels, c.title) end end
    check(#labels == 7, "wc page: worker commands like Warcraft III (" .. table.concat(labels, ", ") .. ")")
    -- Build a farm: B opens the build menu, F picks the farm, then a click.
    view:Key("B")
    view:Draw()
    check(view.menu == "build", "wc page: B opens the build menu")
    view:Key("F")
    check(view.place and view.place.btype == "farm", "wc page: F starts placing a farm")
    local hall = ns.WC.Engine.Hall(st, 1)
    local hx, hy = ns.WC.Engine.Center(hall)
    local sx, sy = ns.WC.AI.FindSpot(st, hx + 5, hy + 5, 2)
    view:PlaceAt(sx + 1, sy + 1)
    check(view.place == nil and worker.order and worker.order.type == "build", "wc page: the worker goes to build")
    Run(30)
    check(ns.WC.Engine.Count(st, 1).buildings.farm == 1, "wc page: the farm is built")
    -- Train from the hall with T.
    view:SelectAt(hx, hy)
    view:Draw()
    view:Key("P")
    check(#hall.queue == 1, "wc page: P trains a peasant")
    -- Rally the hall onto the mine with Y: new peasants go mining.
    local mineE = ns.WC.Engine.NearestMine(st, hx, hy)
    local rmx, rmy = ns.WC.Engine.Center(mineE)
    view:Key("Y")
    check(view.targeting == "rally", "wc page: Y sets a rally point")
    view:TargetAt(rmx, rmy)
    check(hall.rally and hall.rally.target == mineE.id, "wc page: rallied to the mine")
    view:Draw()
    check(view.rallyFlag:IsShown(), "wc page: the rally flag shows")
    Run(12)
    local newest
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 1 and e.type == "peasant" then newest = e end
    end
    check(newest and newest.order and newest.order.type == "gather" and newest.order.res == "gold", "wc page: the new peasant goes to the mine")
    -- Box select and move.
    view:SelectBox(hx - 8, hy - 8, hx + 12, hy + 12)
    local n = #view:MyUnits()
    check(n >= 5, "wc page: drag selects your units (" .. n .. ")")
    local fx, fy = 30, 20
    while ns.WC.Engine.Blocked(st, fx, fy) or ns.WC.Engine.At(st, fx + 0.5, fy + 0.5) do fx = fx + 1 end
    view:Smart(fx + 0.5, fy + 0.5)
    local moving = 0
    for _, id in ipairs(view.sel) do
        local e = st.ents[id]
        if e and e.order and e.order.type == "move" then moving = moving + 1 end
    end
    check(moving >= 5, "wc page: right-click moves them")
    -- Right-click the mine with workers: they gather.
    local mine = ns.WC.Engine.NearestMine(st, hx, hy)
    local mx, my = ns.WC.Engine.Center(mine)
    view:Smart(mx, my)
    local gathering = 0
    for _, id in ipairs(view.sel) do
        local e = st.ents[id]
        if e and e.order and e.order.type == "gather" then gathering = gathering + 1 end
    end
    check(gathering >= 5, "wc page: right-click the mine to gather")
    -- Not enough gold: a message, nothing spent.
    st.players[1].gold = 0
    view:SelectAt(hx, hy)
    view:Train("peasant")
    check(view.status:GetText():find("gold") ~= nil, "wc page: not enough gold says so")
    -- Play on for a while with the AI on the other side.
    st.players[1].gold = 500
    Run(60)
    check(ns.WC.Engine.Count(st, 2).workers > 5, "wc page: the computer builds up too")
    -- Hiding the tab pauses the game.
    local t = st.time
    ns.UI:SelectTab("home")
    Advance(0)
    Run(5)
    check(st.time == t, "wc page: switching tabs pauses")
    ns.UI:SelectTab("warcraft")
    Advance(0)
    Run(1)
    check(st.time > t, "wc page: and it carries on")
    -- Win: wipe the enemy's buildings.
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 2 and e.kind == "building" then e.hp = 0 st.ents[id] = nil end
    end
    Run(1)
    check(st.over and view.overlay:IsShown() and view.overTitle:GetText() == "Victory!", "wc page: victory")
    check(ns.db.warcraft.wins == 1 and ns.db.warcraft.game == nil, "wc page: the win counts")
    check(not ns.Solo.Running("warcraft"), "wc page: the tab can go")
end

-- Workers like Warcraft III: one in the mine at a time, units don't stack.
function WcWorkerTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 9 })
    local mine = E.NearestMine(st, 0, 0)
    local most, sawWait, sawInside = 0, false, false
    for _ = 1, 400 do
        E.Step(st, 0.05)
        local inside = 0
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e.kind == "unit" and e.owner == 1 then
                if e.inside == mine.id then inside = inside + 1 sawInside = true end
                if e.phase == "wait" then sawWait = true end
            end
        end
        if inside > most then most = inside end
    end
    check(most == 1 and sawInside, "wc: one worker in the mine at a time (" .. most .. ")")
    check(sawWait, "wc: the others wait their turn")
    -- A worker told to do something else comes out of the mine.
    local inside
    for _ = 1, 60 do
        E.Step(st, 0.05)
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e.kind == "unit" and e.owner == 1 and e.inside then inside = e end
        end
        if inside then break end
    end
    check(inside ~= nil, "wc: someone is in the mine")
    E.Command(st, 1, { type = "move", units = { inside.id }, x = 20, y = 20 })
    check(not inside.inside and mine.inside == nil and not E.Blocked(st, math.floor(inside.x), math.floor(inside.y)), "wc: ordered away, it steps out")
    -- Soldiers sent to one spot spread out instead of stacking.
    local a, b = E.Spawn(st, 1, "footman", 30, 20), E.Spawn(st, 1, "footman", 30.05, 20)
    for _ = 1, 40 do E.Step(st, 0.05) end
    local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
    check(d > 0.45, "wc: units push apart (" .. string.format("%.2f", d) .. ")")
end


-- Hold position, return resources, idle workers.
function WcCommandTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 21 })
    local fm = E.Spawn(st, 1, "footman", 30, 20)
    E.Command(st, 1, { type = "hold", units = { fm.id } })
    local peon = E.Spawn(st, 2, "peon", 34, 20)
    for _ = 1, 40 do E.Step(st, 0.05) end
    check(math.abs(fm.x - 30) < 0.3 and fm.order and fm.order.type == "hold", "wc: hold position stays put")
    peon.x, peon.y = 31, 20
    for _ = 1, 60 do E.Step(st, 0.05) end
    check(peon.hp < peon.maxHp, "wc: but hits what comes in range")
    -- Return resources: a worker with a load goes home with it.
    local w
    for _ = 1, 400 do
        E.Step(st, 0.05)
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e.owner == 1 and e.kind == "unit" and e.carry and e.carry.res == "gold" then w = e end
        end
        if w then break end
    end
    check(w ~= nil, "wc: a worker carrying gold")
    E.Command(st, 1, { type = "move", units = { w.id }, x = 20, y = 20 })
    for _ = 1, 20 do E.Step(st, 0.05) end
    local gold = st.players[1].gold
    check(E.Command(st, 1, { type = "returnRes", units = { w.id } }), "wc: return resources")
    for _ = 1, 300 do
        E.Step(st, 0.05)
        if not w.carry then break end
    end
    check(not w.carry and st.players[1].gold >= gold + 10 and w.order and w.order.type == "gather", "wc: brought home, back to the mine")
end

-- Building like Warcraft III: the builder stays; leaving pauses it.
function WcBuildTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 31 })
    st.players[1].gold, st.players[1].lumber = 5000, 5000
    local hall = E.Hall(st, 1)
    local hx, hy = E.Center(hall)
    local ws = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 1 and e.kind == "unit" then table.insert(ws, e) end
    end
    local w = ws[1]
    local x1, y1 = WC.AI.FindSpot(st, hx + 5, hy + 5, 2)
    E.Command(st, 1, { type = "build", unit = w.id, btype = "farm", x = x1, y = y1 })
    local farm
    for _ = 1, 300 do
        E.Step(st, 0.05)
        if w.order and w.order.site then farm = st.ents[w.order.site] break end
    end
    check(farm and farm.progress < 1, "wc: the farm goes down")
    for _ = 1, 60 do E.Step(st, 0.05) end
    local p1 = farm.progress
    check(p1 > 0, "wc: it goes up while the peasant works")
    -- Another order: the farm waits.
    local x2, y2 = WC.AI.FindSpot(st, hx - 6, hy + 8, 2)
    E.Command(st, 1, { type = "build", unit = w.id, btype = "farm", x = x2, y = y2 })
    for _ = 1, 60 do E.Step(st, 0.05) end
    check(farm.progress == p1 and farm.paused, "wc: no peasant, no progress (one building at a time)")
    -- Another peasant takes over.
    local w2 = ws[2]
    E.Command(st, 1, { type = "resumeBuild", units = { w2.id }, building = farm.id })
    for _ = 1, 600 do
        E.Step(st, 0.05)
        if farm.progress >= 1 then break end
    end
    check(farm.progress >= 1 and not w2.order or (w2.order and w2.order.type ~= "build"), "wc: a second peasant finishes it")
    -- A lumber mill takes lumber, not gold.
    local lx, ly = WC.AI.FindSpot(st, hx + 8, hy - 2, 3)
    local mill = E.SpawnBuilding(st, 1, "lumber_mill", lx, ly, true)
    check(E.Dropoff(st, 1, lx + 1.5, ly + 1.5, "lumber") == mill, "wc: lumber goes to the lumber mill")
    check(E.Dropoff(st, 1, lx + 1.5, ly + 1.5, "gold") == hall, "wc: gold still goes to the hall")
    check(not E.Command(st, 2, { type = "build", unit = ws[3].id, btype = "lumber_mill", x = lx, y = ly + 5 }), "wc: orcs have no lumber mill")
    -- A tower shoots enemies in range by itself.
    local tx, ty = WC.AI.FindSpot(st, hx - 8, hy + 2, 2)
    local tower = E.SpawnBuilding(st, 1, "guard_tower", tx, ty, true)
    local foe = E.Spawn(st, 2, "grunt", tx + 4, ty + 1)
    foe.order = { type = "hold" }
    local hp0 = foe.hp
    for _ = 1, 40 do E.Step(st, 0.05) end
    check(foe.hp < hp0, "wc: the guard tower shoots")
    local ax, ay = WC.AI.FindSpot(st, hx + 2, hy + 9, 3)
    check(E.Command(st, 1, { type = "build", unit = ws[4].id, btype = "altar_kings", x = ax, y = ay }), "wc: humans can build an altar")
    -- Orcs build from inside.
    st.players[2].gold, st.players[2].lumber = 5000, 5000
    local oh = E.Hall(st, 2)
    local ox, oy = E.Center(oh)
    local peon
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 2 and e.kind == "unit" then peon = e break end
    end
    local bx, by = WC.AI.FindSpot(st, ox - 6, oy - 6, 2)
    E.Command(st, 2, { type = "build", unit = peon.id, btype = "orc_burrow", x = bx, y = by })
    local inside = false
    for _ = 1, 400 do
        E.Step(st, 0.05)
        if peon.insideBuild then inside = true break end
    end
    check(inside, "wc: the peon goes inside to build")
    for _ = 1, 600 do
        E.Step(st, 0.05)
        if not peon.insideBuild then break end
    end
    check(not peon.insideBuild and not E.Blocked(st, math.floor(peon.x), math.floor(peon.y)), "wc: and comes out when it's done")
end

-- Call to Arms and Battle Stations.
function WcAlarmTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 41 })
    local hall = E.Hall(st, 1)
    for _ = 1, 40 do E.Step(st, 0.05) end
    check(E.Command(st, 1, { type = "callToArms", building = hall.id }), "wc: Call to Arms")
    for _ = 1, 200 do E.Step(st, 0.05) end
    local militia = 0
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 1 and e.type == "militia" then militia = militia + 1 end
    end
    check(militia >= 4, "wc: peasants turn into militia (" .. militia .. ")")
    check(E.Command(st, 1, { type = "backToWork" }), "wc: Back to Work")
    local back = 0
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 1 and e.type == "peasant" and e.order and e.order.type == "gather" then back = back + 1 end
    end
    check(back >= 4, "wc: back to the mine (" .. back .. ")")
    -- Militia wear off by themselves.
    E.Command(st, 1, { type = "callToArms", building = hall.id })
    for _ = 1, math.floor((WC.MILITIA_TIME + 15) / 0.05) do E.Step(st, 0.05) end
    local left = 0
    for _, id in ipairs(st.list) do if st.ents[id].type == "militia" then left = left + 1 end end
    check(left == 0, "wc: after 45 seconds they're peasants again")
    -- Orcs: peons into a burrow; the burrow shoots.
    st.players[2].gold, st.players[2].lumber = 5000, 5000
    local oh = E.Hall(st, 2)
    local ox, oy = E.Center(oh)
    local bx, by = WC.AI.FindSpot(st, ox - 5, oy - 5, 2)
    local peon
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 2 and e.kind == "unit" then peon = e break end
    end
    E.Command(st, 2, { type = "build", unit = peon.id, btype = "orc_burrow", x = bx, y = by })
    for _ = 1, 900 do E.Step(st, 0.05) end
    local burrow
    for _, id in ipairs(st.list) do if st.ents[id].type == "orc_burrow" then burrow = st.ents[id] end end
    check(burrow and burrow.progress >= 1, "wc: a burrow")
    check(E.Command(st, 2, { type = "battleStations", building = oh.id }), "wc: Battle Stations")
    for _ = 1, 800 do
        E.Step(st, 0.05)
        if #burrow.garrison == 4 then break end
    end
    check(#burrow.garrison == 4, "wc: four peons inside (" .. #burrow.garrison .. ")")
    local fx, fy = E.Center(burrow)
    local foe = E.Spawn(st, 1, "footman", fx + 4, fy)
    E.Command(st, 1, { type = "hold", units = { foe.id } })
    for _ = 1, 60 do E.Step(st, 0.05) end
    check(foe.hp < foe.maxHp, "wc: the burrow shoots")
    E.Command(st, 2, { type = "backToWork" })
    check(#burrow.garrison == 0, "wc: back to work empties it")
end

-- Difficulty and the walk animation flag.
function WcDifficultyTests()
    local D = WC.DIFFICULTY
    check(D.easy.workers < D.normal.workers and D.normal.workers < D.hard.workers, "wc: difficulty: more workers on harder levels")
    check(D.easy.firstAttack > D.normal.firstAttack and D.normal.firstAttack > D.hard.firstAttack, "wc: difficulty: earlier attacks on harder levels")
    local st = E.New({ factions = { "human", "orc" }, seed = 51, difficulty = "hard" })
    check(st.difficulty == "hard", "wc: the game keeps its difficulty")
    WC.AI.Think(st, 2)
    check(st.players[2].income == 1.25 and (st.players[1].income or 1) == 1, "wc: hard gives the computer more per trip, not you")
    -- No attack before the first-attack time, whatever the army.
    st = E.New({ factions = { "human", "orc" }, seed = 52, difficulty = "easy" })
    for i = 1, 10 do E.Spawn(st, 2, "grunt", 50 + (i % 3), 30 + math.floor(i / 3)) end
    for _ = 1, 3 do WC.AI.Think(st, 2) WC.AI.Think(st, 2) end
    local attacking = false
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 2 and e.order and e.order.type == "attackMove" then attacking = true end
    end
    check(not attacking, "wc: easy waits before its first attack")
    -- Walking units are marked for the walk animation.
    local fm = E.Spawn(st, 1, "footman", 30, 20)
    E.Command(st, 1, { type = "move", units = { fm.id }, x = 34, y = 20 })
    E.Step(st, 0.05)
    check(fm.walkT == st.time, "wc: a walking unit is flagged as walking")
end

-- Games on each difficulty finish.
function WcDifficultyGames()
    for _, key in ipairs({ "easy", "hard" }) do
        local st = E.New({ factions = { "human", "orc" }, seed = 77, difficulty = key })
        local t, think = 0, 0
        while t < 45 * 60 and not st.over do
            E.Step(st, 0.2)
            t = t + 0.2
            think = think + 0.2
            if think >= 1 then think = 0 WC.AI.Think(st, 1) WC.AI.Think(st, 2) end
        end
        check(st.over, "wc: an AI game on " .. key .. " ends (" .. math.floor(st.time / 60) .. " min)")
    end
end

function WcGalleryTests()
    SlashCmdList.FNGWCGALLERY("")
    local g = ns.WarcraftPage.galleryFrame
    check(g and g:IsShown() and g.cells[1].num:GetText() == "1", "wc gallery: opens on page 1")
    g.next._scripts.OnClick()
    check(g.page == 2 and g.cells[1].num:GetText() == "19", "wc gallery: next page")
end

-- Shift: orders queue up instead of replacing (Warcraft III).
function WcQueueTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 41 })
    local fm = E.Spawn(st, 1, "footman", 30, 20)
    E.Command(st, 1, { type = "move", units = { fm.id }, x = 34, y = 20 })
    E.Command(st, 1, { type = "move", units = { fm.id }, x = 34, y = 24, queue = true })
    check(fm.order.x == 34 and fm.order.y == 20 and #fm.queue == 1, "wc queue: the second move waits")
    for _ = 1, 200 do E.Step(st, 0.05) end
    check(math.abs(fm.x - 34) < 0.6 and math.abs(fm.y - 24) < 0.6, "wc queue: then it goes on")
    -- A plain order clears the queue.
    E.Command(st, 1, { type = "move", units = { fm.id }, x = 30, y = 20 })
    E.Command(st, 1, { type = "move", units = { fm.id }, x = 30, y = 24, queue = true })
    E.Command(st, 1, { type = "move", units = { fm.id }, x = 36, y = 20 })
    check(fm.queue == nil and fm.order.x == 36, "wc queue: no Shift, no queue")

    -- Two buildings in a row: a then b, paid up front, refunded if cancelled.
    st.players[1].gold, st.players[1].lumber = 1000, 1000
    local hall = E.Hall(st, 1)
    local hx, hy = E.Center(hall)
    local w
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 1 and e.type == "peasant" then w = e break end
    end
    local x1, y1 = WC.AI.FindSpot(st, hx + 6, hy + 6, 2)
    E.Command(st, 1, { type = "build", unit = w.id, btype = "farm", x = x1, y = y1 })
    local x2, y2 = WC.AI.FindSpot(st, hx + 10, hy + 6, 2)
    check(not E.Command(st, 1, { type = "build", unit = w.id, btype = "farm", x = x1, y = y1, queue = true }),
        "wc queue: not on top of a planned farm")
    check(E.Command(st, 1, { type = "build", unit = w.id, btype = "farm", x = x2, y = y2, queue = true }), "wc queue: shift-build a second farm")
    check(st.players[1].gold == 1000 - 160 and #w.queue == 1, "wc queue: both paid, the second waits")
    for _ = 1, 2400 do E.Step(st, 0.05) end
    check((E.Count(st, 1).buildings.farm or 0) == 2, "wc queue: both farms built, one after the other")
    check(w.order and w.order.type == "gather", "wc queue: then back to work")
    -- Cancelling a queue refunds the farms not started.
    local x3, y3 = WC.AI.FindSpot(st, hx - 8, hy + 6, 2)
    local x4, y4 = WC.AI.FindSpot(st, hx - 8, hy + 10, 2)
    local gold = st.players[1].gold
    E.Command(st, 1, { type = "build", unit = w.id, btype = "farm", x = x3, y = y3 })
    E.Command(st, 1, { type = "build", unit = w.id, btype = "farm", x = x4, y = y4, queue = true })
    E.Command(st, 1, { type = "stop", units = { w.id } })
    check(st.players[1].gold == gold, "wc queue: stop gives the money back")
end

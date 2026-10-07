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
        Run(st, 40 * 60, 0.2, { 1, 2 })
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
    view:Draw()
    local labels = {}
    for _, c in ipairs(view.cmds) do if c:IsShown() then table.insert(labels, c.title) end end
    check(#labels == 4, "wc page: worker commands: attack, stop, farm, barracks (" .. table.concat(labels, ", ") .. ")")
    -- Build a farm with F and a click.
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
    view:Key("T")
    check(#hall.queue == 1, "wc page: T trains a peasant")
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

-- Warcraft 4: Tower Defense (Games/Warcraft/TowerDefense.lua), the rules
-- without the UI.
local WC = ns.WC
local E = WC.Engine
local TD = WC.Modes.td

local function Run(st, seconds, ai)
    local t, think = 0, 0
    while t < seconds and not st.over do
        E.Step(st, 0.1)
        t = t + 0.1
        think = think + 0.1
        if ai and think >= 1 then
            think = 0
            for _, p in ipairs(ai) do WC.AI.Think(st, p) end
        end
    end
end

local function Count(st, fn)
    local n = 0
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and fn(e) then n = n + 1 end
    end
    return n
end

function WcTdTests()
    -- The maps.
    for _, key in ipairs({ "td_duel", "td_four", "td_eight" }) do
        local ok, bad = WC.CheckMap(key)
        check(ok, "td map " .. key .. " checks out (" .. table.concat(bad or {}, "; ") .. ")")
    end
    local three = WC.MapsFor(3, "td")
    check(#three == 2 and three[1] == "td_four", "td: three players get the 4- and 8-lane maps")
    check(WC.MODE_ORDER[3] == "td", "td: a mode in the lobby")

    -- A game for two.
    local st = E.New({ factions = { "human", "orc" }, map = "td_duel", mode = "td", seed = 4 })
    local p1, p2 = st.players[1], st.players[2]
    check(p1.gold == TD.START_GOLD and p1.td.lives == TD.LIVES and p2.td.lives == TD.LIVES, "td: gold and lives to start")
    check(st.players[3] and st.players[3].neutral, "td: the creeps' side")
    local L1, L2 = TD.Lane(st, 1), TD.Lane(st, 2)
    check(L1 and L2 and L2.x0 > L1.x1, "td: a lane each, side by side")
    local builder = st.ents[p1.td.builder]
    check(builder and WC.Units[builder.type].tdBuilder and WC.Units[builder.type].air, "td: a flying builder")
    check(Count(st, function(e) return e.owner == 1 and e.kind == "building" and WC.Buildings[e.type].tdGate end) == 1, "td: a gate")

    -- Building: only in your own lane, in the building rows.
    check(not TD.CanBuildAt(st, 1, "td_arrow", L2.x0, 10), "td: not in someone else's lane")
    check(not TD.CanBuildAt(st, 1, "td_arrow", L1.x0, TD.SPAWN_Y), "td: not where creeps come in")
    check(not TD.CanBuildAt(st, 1, "guard_tower", L1.x0, 10), "td: only tower defense towers")
    local ok = E.Command(st, 1, { type = "build", unit = p1.td.builder, btype = "td_arrow", x = L1.x0, y = 10 })
    check(ok and p1.gold == TD.START_GOLD - 60, "td: an Arrow Tower, paid")
    check(Count(st, function(e) return e.type == "td_arrow" and e.progress >= 1 end) == 1, "td: up at once")

    -- Never close the path: a full row across the lane is refused at the last gap.
    p1.gold = 1000
    for i = 1, 4 do
        E.Command(st, 1, { type = "build", unit = p1.td.builder, btype = "td_wall", x = L1.x0 + i * 2, y = 10 })
    end
    local walls = Count(st, function(e) return e.owner == 1 and e.type == "td_wall" end)
    local _, why = TD.CanBuildAt(st, 1, "td_wall", L1.x0 + 8, 10)
    check(walls == 3 and why == "that would close the path", "td: the last gap stays open (" .. walls .. ", " .. tostring(why) .. ")")

    -- Selling: three quarters back.
    local wall
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.type == "td_wall" then wall = e end end
    local before = p1.gold
    check(E.Command(st, 1, { type = "tdSell", building = wall.id }) and p1.gold == before + 7, "td: sell for 75%")

    -- Upgrading: research turns the tower into the next level.
    local arrow
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.type == "td_arrow" then arrow = e end end
    check(E.Command(st, 1, { type = "research", building = arrow.id, key = "td_up_arrow2" }), "td: upgrade an Arrow Tower")
    Run(st, 3)
    check(arrow.type == "td_arrow2", "td: it's an Arrow Tower 2 now (" .. tostring(arrow.type) .. ")")

    -- Waves: creeps come into both lanes and walk down.
    Run(st, TD.FIRST_WAVE + 6 - st.time)
    local in1 = Count(st, function(e) return e.tdLane == 1 end)
    local in2 = Count(st, function(e) return e.tdLane == 2 end)
    check(st.td.wave == 1 and in1 > 0 and in2 > 0, "td: wave 1 in both lanes (" .. in1 .. ", " .. in2 .. ")")
    -- Towers only shoot their own lane's creeps.
    local c2
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.tdLane == 2 then c2 = e end end
    check(not E.CanHit(st, { owner = 1, x = 0, y = 0, kind = "unit" }, c2), "td: a tower can't shoot another lane")
    check(E.CanHit(st, { owner = 2, x = 0, y = 0, kind = "unit" }, c2), "td: a tower shoots its own lane")
    check(not E.CanHit(st, builder, c2) and not E.CanHit(st, { owner = 2, kind = "unit" }, builder), "td: nobody hits the builders")

    -- Player 2 has no towers: creeps get out and cost lives; player 1's tower kills some (bounty).
    local gold1 = p1.gold
    Run(st, 40)
    check(p2.td.lives < TD.LIVES, "td: leaks cost lives (" .. p2.td.lives .. ")")
    check(p1.gold > gold1, "td: kills and income pay gold")

    -- Sends: into the next opponent's lane, and income for good.
    local inc = p1.td.income
    local n2 = Count(st, function(e) return e.tdLane == 2 end)
    p1.gold = p1.gold + 100
    check(E.Command(st, 1, { type = "tdSend", unit = "td_wolf" }), "td: send a wolf")
    check(p1.td.income == inc + 2 and Count(st, function(e) return e.tdLane == 2 end) == n2 + 1, "td: it runs in player 2's lane, +2 income")
    check(TD.Target(st, 1) == 2 and TD.Target(st, 2) == 1, "td: two players send to each other")

    -- Out of lives: player 2's gate falls, player 1 wins.
    Run(st, 600)
    check(st.over and st.winner == 1 and p2.td.lives == 0, "td: out of lives, out (" .. tostring(st.winner) .. ")")
    check(Count(st, function(e) return e.owner == 2 end) == 0, "td: nothing of theirs is left")
end

-- Alone: no opponent, no sends; the game goes on until your lives run out.
function WcTdSoloTests()
    local st = E.New({ factions = { "human" }, map = "td_duel", mode = "td", seed = 3 })
    Run(st, 30)
    check(not st.over, "td solo: a game alone doesn't end at once")
    check(TD.Target(st, 1) == nil and not E.Command(st, 1, { type = "tdSend", unit = "td_kobold" }), "td solo: nobody to send to")
    Run(st, 900)
    check(st.over and st.players[1].td.lives == 0, "td solo: over when your lives run out (wave " .. st.td.wave .. ")")
    local ok = ns.WarcraftLobby.CanStart({ mode = "td", map = "td_duel", slots = { { kind = "host", team = 1, race = "human" }, { kind = "open", team = 2 } } })
    local melee = ns.WarcraftLobby.CanStart({ mode = "melee", map = "riverford", slots = { { kind = "host", team = 1, race = "human" }, { kind = "open", team = 2 } } })
    check(ok and not melee, "td solo: the lobby starts Tower Defense alone (not melee)")
end

-- Two computers play a whole game, and the same seed plays the same game.
function WcTdAiTests()
    local function Game(seed)
        local st = E.New({ factions = { "human", "orc", "human" }, map = "td_four", mode = "td", seed = seed,
            difficulties = { [1] = "normal", [2] = "normal", [3] = "hard" } })
        local towers, sent = 0, 0
        Run(st, 3600, { 1, 2, 3 })
        for p = 1, 3 do sent = sent + st.players[p].td.sent end
        return st, sent
    end
    local st, sent = Game(7)
    local towers = 0
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.kind == "building" and WC.Buildings[e.type].tdTower then towers = towers + 1 end end
    check(st.over and st.winner, "td ai: three computers finish a game (wave " .. st.td.wave .. ", " .. math.floor(st.time / 60) .. " min)")
    check(sent > 0, "td ai: the computers send creeps (" .. sent .. ")")
    print(string.format("  td: three computers: winner %s at wave %d after %.1f min, %d sends", tostring(st.winner), st.td.wave, st.time / 60, sent))
    local again = Game(7)
    check(E.Hash(again) == E.Hash(st), "td ai: the same seed plays the same game")
end

-- The screen: Tower Defense from the lobby, the builder's towers, the gate's
-- sends, a tower's upgrade and sell, the top bar.
function WcTdPageTests()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    ns.db.warcraft.lobby = nil
    view:ShowLobby()
    local f = view.lobbyFrame
    local modeB
    for _, b in ipairs(f.modes) do if b.key == "td" then modeB = b end end
    check(modeB ~= nil, "td lobby: a Tower Defense button")
    modeB._scripts.OnClick()
    local lb = ns.db.warcraft.lobby
    check(lb.mode == "td" and lb.map == "td_duel" and f.maps[1].key == "td_duel", "td lobby: it picks a lane map")
    f.rows[2].who._scripts.OnClick() -- a computer opponent
    f.start._scripts.OnClick()
    local st = view.st
    check(st and st.mode == "td" and st.td, "td page: a Tower Defense game")
    local me = st.players[1]
    local L = TD.Lane(st, 1)
    local function Titles()
        view:Draw()
        local t = {}
        for _, c in ipairs(view.cmds) do if c:IsShown() then t[#t + 1] = c.title end end
        return table.concat(t, " | ")
    end
    local function Click(title)
        view:Draw()
        for _, c in ipairs(view.cmds) do if c:IsShown() and c.title == title then c.action() return true end end
    end
    view:Draw()
    check(view.lumberText:GetText():find("^Lives 20") and view.foodText:GetText():find("Income", 1, true),
        "td page: lives and income in the top bar (" .. tostring(view.lumberText:GetText()) .. ")")

    -- The builder: its towers; put an Arrow Tower in the lane.
    view.sel = { me.td.builder }
    local card = Titles()
    check(not card:find("Gather", 1, true), "td page: the builder doesn't gather (" .. card .. ")")
    check(Click("Build (B)"), "td page: the builder builds")
    local all = Titles()
    check(all:find("Build Arrow Tower (A)", 1, true) and all:find("Build Cannon Tower (C)", 1, true)
        and all:find("Build Frost Tower (F)", 1, true) and all:find("Build Maze Wall (W)", 1, true)
        and not all:find("Farm", 1, true), "td page: the tower menu (" .. all .. ")")
    Click("Build Arrow Tower (A)")
    check(view.place and view.place.btype == "td_arrow", "td page: placing an Arrow Tower")
    view:PlaceAt(L.x0 + 1, 11)
    local tower
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.owner == 1 and e.type == "td_arrow" then tower = e end end
    check(tower and tower.x == L.x0 and tower.y == 10, "td page: it stands where you clicked")
    -- Not in the other lane.
    local L2 = TD.Lane(st, 2)
    view.sel = { me.td.builder }
    Click("Build (B)")
    Titles()
    Click("Build Arrow Tower (A)")
    view:PlaceAt(L2.x0 + 1, 11)
    local theirs = 0
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.owner == 1 and e.x == L2.x0 then theirs = theirs + 1 end end
    check(theirs == 0, "td page: no towers in someone else's lane")
    view.place = nil

    -- A tower: upgrade and sell.
    view.sel = { tower.id }
    all = Titles()
    check(all:find("Upgrade to Arrow Tower 2", 1, true) and all:find("Sell (X)", 1, true), "td page: upgrade and sell (" .. all .. ")")

    -- The gate: sends.
    local gate
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.owner == 1 and e.kind == "building" and WC.Buildings[e.type].tdGate then gate = e end end
    view.sel = { gate.id }
    all = Titles()
    check(all:find("Send Kobold (Q)", 1, true) and all:find("Send Hogger (S)", 1, true), "td page: the sends (" .. all .. ")")
    local inc = me.td.income
    Click("Send Kobold (Q)")
    check(me.td.income == inc + 1, "td page: a send raises your income")
    ns.db.warcraft.lobby = nil
    view:Quit()
end

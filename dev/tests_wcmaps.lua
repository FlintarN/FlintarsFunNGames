-- Warcraft maps: every map is well made and fair, games start on it, the
-- computer can play it, and you can pick it.
local WC = ns.WC
local E = WC.Engine

function WcMapTests()
    for _, key in ipairs(WC.MAP_ORDER) do
        local ok, bad = WC.CheckMap(key)
        check(ok, "wc maps: " .. key .. " is well made (" .. table.concat(bad, "; ") .. ")")
    end
    check(#WC.MapsFor(2) >= 4 and #WC.MapsFor(4) >= 1, "wc maps: four or more for two players, one for four")
    -- A game on each map: halls on the starts, mines, trees, workers at work.
    for _, key in ipairs(WC.MapsFor(2)) do
        local st = E.New({ factions = { "human", "orc" }, seed = 5, map = key })
        local p = WC.ParseMap(key)
        local h1, h2 = E.Hall(st, 1), E.Hall(st, 2)
        local mines, trees = 0, 0
        for _, id in ipairs(st.list) do if st.ents[id].type == "gold_mine" then mines = mines + 1 end end
        for _ in pairs(st.trees) do trees = trees + 1 end
        check(st.map == key and st.w == p.w and h1 and h1.x == p.starts[1][1] and h2.y == p.starts[2][2]
            and mines == #p.mines and trees == #p.trees, "wc maps: a game on " .. key)
        -- The computer plays both sides for 8 minutes: it gathers, builds and finds the enemy.
        for _ = 1, 8 * 60 * 20 do
            E.Step(st, 0.05)
            if math.floor(st.time * 20 + 0.5) % 20 == 0 then WC.AI.Think(st, 1) WC.AI.Think(st, 2) end
            if st.over then break end
        end
        local c1, c2 = E.Count(st, 1), E.Count(st, 2)
        local built1, built2 = 0, 0
        for _, n in pairs(c1.buildings) do built1 = built1 + n end
        for _, n in pairs(c2.buildings) do built2 = built2 + n end
        check(built1 >= 4 and built2 >= 4, "wc maps: the computer builds up on " .. key .. " (" .. built1 .. ", " .. built2 .. ")")
    end
    -- The Single Player lobby: pick a map, seats, teams; Start Game.
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    local Lb = ns.WarcraftLobby
    ns.db.warcraft.lobby = nil
    view:ShowMenu()
    view.soloButton._scripts.OnClick()
    local f = view.lobbyFrame
    check(f:IsShown() and f.rows[1]:IsShown() and f.rows[2]:IsShown() and not f.rows[3]:IsShown(),
        "wc lobby: Single Player opens the lobby: you and a computer")
    check(f.start:IsEnabled(), "wc lobby: ready to start")
    local function MapButton(key) for _, b in ipairs(f.maps) do if b.key == key then return b end end end
    MapButton("echo_ford")._scripts.OnClick()
    check(ns.db.warcraft.lobby.map == "echo_ford" and f.mapLong:GetText() == WC.Maps.echo_ford.text, "wc lobby: pick a map")
    f.start._scripts.OnClick()
    check(view.st.map == "echo_ford" and #view.st.players == 2 and math.abs(view.mm:GetWidth() - view.st.w * view.mmScale) < 0.01,
        "wc lobby: the game is on that map, the minimap fits it")
    -- Four players, two teams.
    view:ShowLobby()
    MapButton("four_crowns")._scripts.OnClick()
    check(f.rows[4]:IsShown() and ns.db.warcraft.lobby.slots[3].kind == "closed", "wc lobby: four seats on Four Crowns")
    f.rows[3].who._scripts.OnClick()
    f.rows[4].who._scripts.OnClick()
    f.rows[4].who._scripts.OnClick() -- Normal > Hard
    f.rows[3].team._scripts.OnClick() -- team 3 > 4
    for _ = 1, 2 do f.rows[3].team._scripts.OnClick() end -- > 1 > 2? (cycles 1..4)
    local lb = ns.db.warcraft.lobby
    lb.slots[1].team, lb.slots[2].team, lb.slots[3].team, lb.slots[4].team = 1, 2, 1, 2
    Lb.Draw(view)
    check(lb.slots[4].kind == "cpu" and lb.slots[4].diff == "hard" and f.rows[4].who:GetText() == "Computer (Hard)",
        "wc lobby: a Hard computer in seat 4")
    f.start._scripts.OnClick()
    local st = view.st
    check(#st.players == 4 and E.Ally(st, 1, 3) and E.Foe(st, 1, 2) and st.players[4].difficulty == "hard",
        "wc lobby: a 2v2 game: you and seat 3 against 2 and 4")
    check(not st.over, "wc lobby: under way")
    -- Everyone on one team can't start.
    view:ShowLobby()
    for i = 1, 4 do lb.slots[i].team = 1 end
    Lb.Draw(view)
    check(not f.start:IsEnabled(), "wc lobby: one team only: Start is greyed out")
    -- A 2v2 played out by the computer (all four seats).
    local g = E.New({ factions = { "human", "orc", "orc", "human" }, teams = { 1, 2, 1, 2 }, seed = 3, map = "four_crowns" })
    for _ = 1, 30 * 60 * 20 do
        E.Step(g, 0.05)
        if math.floor(g.time * 20 + 0.5) % 20 == 0 then for p = 1, 4 do WC.AI.Think(g, p) end end
        if g.over then break end
    end
    check(g.over and g.winner > 0, "wc lobby: a 2v2 computer game ends with a winner (" .. math.floor(g.time / 60) .. " min, team "
        .. tostring(g.over and E.Team(g, g.winner)) .. ")")
    ns.db.warcraft.lobby = nil
    ns.db.warcraft.map = nil
    view:Quit()
end

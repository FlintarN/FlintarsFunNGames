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
    -- Pick a map on the Single Player screen; the game uses it.
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    view:ShowMenu()
    view.soloButton._scripts.OnClick()
    check(view.mapRow:IsShown(), "wc maps: a map choice for Single Player")
    ns.db.warcraft.map = "riverford"
    view.mapRow.next._scripts.OnClick()
    local picked = ns.db.warcraft.map
    check(picked ~= "riverford" and view.mapRow.name:GetText() == WC.Maps[picked].name, "wc maps: > picks the next map")
    view.picks[1]._scripts.OnClick()
    check(view.st.map == picked and math.abs(view.mm:GetWidth() - view.st.w * view.mmScale) < 0.01,
        "wc maps: the game is on that map, the minimap fits it")
    view:ShowMenu()
    view.queueButton._scripts.OnClick()
    check(not view.mapRow:IsShown(), "wc maps: no map choice when finding an opponent")
    ns.db.warcraft.map = nil
    view:Quit()
end

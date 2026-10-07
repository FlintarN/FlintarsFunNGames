-- Creeps: camps on the maps, guarding, going home, gold, experience, drops.
local WC = ns.WC
local E = WC.Engine

function WcCreepTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 2, map = "riverford", creeps = true })
    local c = st.creeps
    local n = 0
    for _, id in ipairs(st.list) do if st.ents[id].owner == c then n = n + 1 end end
    check(c == 3 and st.players[c].neutral and #st.camps == 6 and n >= 18, "creeps: six camps on Riverford (" .. n .. " creeps)")
    check(E.PlayerCount(st) == 2 and E.Foe(st, 1, c) and E.Foe(st, 2, c), "creeps: a neutral side, everyone's enemy")
    for _ = 1, 20 do E.Step(st, 0.05) end
    check(not st.over, "creeps: they don't count in who wins")
    -- They come at you near the camp, and go home when led away.
    local camp = st.camps[1]
    local fm = E.Spawn(st, 1, "footman", camp.x + 3.5, camp.y)
    fm.order = { type = "hold" }
    for _ = 1, 20 do E.Step(st, 0.05) end
    local chasing
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == c and e.camp == 1 and e.order and e.order.type == "attack" then chasing = e end
    end
    check(chasing ~= nil, "creeps: they attack a footman next to their camp")
    chasing.x, chasing.y = camp.x + 12, camp.y
    for _ = 1, 10 do E.Step(st, 0.05) end
    check(chasing.order and chasing.order.home, "creeps: led too far, they walk home")
    -- A hero clears a camp: gold, experience, an item to pick up.
    local g = E.New({ factions = { "human", "orc" }, seed = 2, map = "riverford", creeps = true })
    local cp = g.camps[2]
    local hero = E.Spawn(g, 1, "mountain_king", cp.x + 2, cp.y)
    hero.level, hero.hp, hero.maxHp = 10, 99999, 99999
    local gold, xp = g.players[1].gold, hero.xp or 0
    for _ = 1, 120 * 20 do
        E.Step(g, 0.05)
        if not g.camps[2].dropped and not hero.order then E.Command(g, 1, { type = "attackMove", units = { hero.id }, x = cp.x, y = cp.y }) end
        if g.camps[2].dropped then break end
    end
    check(g.camps[2].dropped and #g.items == 1 and g.players[1].gold > gold, "creeps: camp cleared: gold and a dropped item ("
        .. (g.players[1].gold - gold) .. " gold)")
    local it = g.items[1]
    hero.level, hero.xp = 1, 0
    E.Command(g, 1, { type = "move", units = { hero.id }, x = it.x, y = it.y })
    for _ = 1, 10 * 20 do E.Step(g, 0.05) if #g.items == 0 then break end end
    check(#g.items == 0, "creeps: the hero walks over the item and takes it (" .. it.key .. ")")
    -- The computer plays a whole game with creeps on the map.
    local a = E.New({ factions = { "human", "orc" }, seed = 6, map = "echo_ford", creeps = true })
    for _ = 1, 40 * 60 * 20 do
        E.Step(a, 0.05)
        if math.floor(a.time * 20 + 0.5) % 20 == 0 then WC.AI.Think(a, 1) WC.AI.Think(a, 2) end
        if a.over then break end
    end
    check(a.over and a.winner > 0 and a.winner <= 2, "creeps: a computer game with creeps ends with a player winning ("
        .. math.floor(a.time / 60) .. " min)")
    -- The lobby's games have creeps.
    check(ns.WarcraftLobby.GameOptions(ns.WarcraftLobby.Default("riverford")).creeps == true, "creeps: lobby games have them")
end

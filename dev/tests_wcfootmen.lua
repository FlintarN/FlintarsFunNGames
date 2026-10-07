-- Footmen Frenzy: the mode's start, spawning, bounties, tiers, heroes, the
-- computer playing it out, and the lobby and command card for it.
local WC = ns.WC
local E = WC.Engine
local F = WC.Modes.footmen

function WcFootmenTests()
    local st = E.New({ factions = { "human", "orc", "orc", "human" }, seed = 21, map = "frenzy_fields", mode = "footmen" })
    check(st.mode == "footmen", "ff: a Footmen Frenzy game")
    local ok = true
    for p = 1, 4 do
        local b = F.Barracks(st, p)
        if not b or st.players[p].gold ~= F.START_GOLD then ok = false end
    end
    local units, shops = 0, 0
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.kind == "unit" then units = units + 1 end
        if e.type == "arcane_vault" and e.owner == 0 then shops = shops + 1 end
    end
    check(ok and units == 0 and shops == 1, "ff: a barracks each, 2000 gold, no workers, a shop in the middle")
    check(WC.BaseOf("ff_barracks") == "barracks" and WC.Buildings.ff_barracks.hp > WC.Buildings.barracks.hp
        and WC.Units.ff_paladin.npc == WC.Units.paladin.npc and WC.Units.ff_paladin.cost[1] == F.HERO_COST,
        "ff: variants keep the normal look (model) and change only their numbers")
    -- The barracks sends soldiers out on their own.
    for _ = 1, 25 * 20 do E.Step(st, 0.05) end
    local n = 0
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 1 and e.type == "footman" then n = n + 1 end
    end
    check(n >= 2, "ff: footmen spawn every 10 seconds (" .. n .. " in 25 s)")
    -- Tiers wait for their time, then cost gold.
    local b1 = F.Barracks(st, 1)
    local okR, why = E.Command(st, 1, { type = "research", building = b1.id, key = "ff_tier_human" })
    check(not okR and why == "ready at 3:00", "ff: the next tier opens at 3:00 (" .. tostring(why) .. ")")
    -- A hero from the barracks, for gold only.
    local gold = st.players[1].gold
    check(E.Command(st, 1, { type = "train", building = b1.id, utype = "ff_paladin" }), "ff: hire a hero at the barracks")
    check(st.players[1].gold == gold - F.HERO_COST, "ff: the hero costs " .. F.HERO_COST)
    -- Bounty: killing an enemy pays.
    local foe = E.Spawn(st, 2, "grunt", 30, 30)
    local mine = E.Spawn(st, 1, "knight", 30.6, 30)
    gold = st.players[1].gold
    foe.hp = 1
    E.Command(st, 1, { type = "attack", units = { mine.id }, target = foe.id })
    for _ = 1, 40 do E.Step(st, 0.05) end
    check(st.players[1].gold > gold, "ff: gold for the kill (" .. (st.players[1].gold - gold) .. ")")
    -- Send to: an enemy's barracks.
    check(E.Command(st, 1, { type = "sendTo", target = 2 }) and st.players[1].ff.target == 2, "ff: send your soldiers at player 2")
    check(not E.Command(st, 1, { type = "sendTo", target = 1 }), "ff: not at yourself")

    -- Four computers play it out: they hire heroes, tier up, and someone wins.
    local g = E.New({ factions = { "human", "orc", "human", "orc" }, seed = 8, map = "frenzy_fields", mode = "footmen" })
    local heroes, tiers = 0, 0
    for _ = 1, 45 * 60 * 20 do
        E.Step(g, 0.05)
        if math.floor(g.time * 20 + 0.5) % 20 == 0 then for p = 1, 4 do WC.AI.Think(g, p) end end
        if g.over then break end
    end
    for p = 1, 4 do
        if E.Level(g, p, "ff_tier_human") + E.Level(g, p, "ff_tier_orc") > 0 then tiers = tiers + 1 end
        if g.players[p].fallen and next(g.players[p].fallen) then heroes = heroes + 1 end
    end
    for _, id in ipairs(g.list) do if g.ents[id] and E.IsHero(g.ents[id]) then heroes = heroes + 1 end end
    check(g.over, "ff: four computers finish a game (" .. math.floor(g.time / 60) .. " min, winner " .. tostring(g.winner) .. ")")
    check(heroes >= 1 and tiers >= 1, "ff: they hired heroes (" .. heroes .. ") and tiered up (" .. tiers .. ")")
    print("  ff: four computers: " .. math.floor(g.time / 60) .. " min, winner " .. tostring(g.winner))

    -- The lobby: Footmen Frenzy and its map; the barracks' command card.
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    ns.db.warcraft.lobby = nil
    view:ShowLobby()
    local f = view.lobbyFrame
    local modeB
    for _, b in ipairs(f.modes) do if b.key == "footmen" then modeB = b end end
    modeB._scripts.OnClick()
    local lb = ns.db.warcraft.lobby
    check(lb.mode == "footmen" and lb.map == "frenzy_fields" and f.maps[1].key == "frenzy_fields" and not f.maps[2]:IsShown(),
        "ff lobby: Footmen Frenzy picks its map")
    f.rows[3].who._scripts.OnClick()
    f.rows[4].who._scripts.OnClick()
    f.start._scripts.OnClick()
    local s2 = view.st
    check(s2.mode == "footmen" and #s2.players == 4, "ff lobby: a four-player Footmen Frenzy game")
    local b = F.Barracks(s2, 1)
    view.sel = { b.id }
    view:Draw()
    local titles = {}
    for _, c in ipairs(view.cmds) do if c:IsShown() then titles[#titles + 1] = c.title end end
    local all = table.concat(titles, " | ")
    check(all:find("Hire a Hero", 1, true) and all:find("Weapons 1", 1, true) and all:find("Armor 1", 1, true)
        and all:find("Train Riflemen", 1, true) and all:find("Send to: the middle", 1, true),
        "ff card: a hero, weapons, armour, the next tier, send to (" .. all .. ")")
    for _, c in ipairs(view.cmds) do if c:IsShown() and c.title == "Hire a Hero (H)" then c.action() end end
    view:Draw()
    titles = {}
    for _, c in ipairs(view.cmds) do if c:IsShown() then titles[#titles + 1] = c.title end end
    all = table.concat(titles, " | ")
    check(all:find("Train Paladin", 1, true) and all:find("Train Shadow Hunter", 1, true) and view.cmds[12].title == "Back",
        "ff card: Hire a Hero lists all eight (" .. all .. ")")
    ns.db.warcraft.lobby = nil
    view:Quit()
end

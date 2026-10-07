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
    -- Soldiers wait at home without a rally point; with one they go there.
    local function NewOnes(p, utype)
        local out = {}
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e.owner == p and e.type == utype then table.insert(out, e) end
        end
        return out
    end
    local waiting = true
    for _, u in ipairs(NewOnes(1, "footman")) do if u.order then waiting = false end end
    check(waiting, "ff: without a rally point the soldiers wait at home")
    E.Command(st, 1, { type = "rally", building = b1.id, x = 20, y = 20 })
    st.players[1].ff.next = 0
    E.Step(st, 0.05)
    local list = NewOnes(1, "footman")
    local last = list[#list]
    check(last.order and math.abs(last.order.x - 20) < 1, "ff: with a rally point they go there")
    check(E.Command(st, 1, { type = "sendTo", target = 2 }) and st.players[1].ff.target == 2, "ff: send your soldiers at player 2")
    check(not E.Command(st, 1, { type = "sendTo", target = 1 }), "ff: not at yourself")
    -- A fallen hero comes back by itself.
    local hero
    for _ = 1, 20 * 20 do
        E.Step(st, 0.05)
        for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.owner == 1 and E.IsHero(e) then hero = e end end
        if hero then break end
    end
    check(hero ~= nil, "ff: the hero arrives")
    hero.hp = 1
    local killer = E.Spawn(st, 2, "grunt", hero.x + 0.6, hero.y)
    E.Command(st, 2, { type = "attack", units = { killer.id }, target = hero.id })
    local back
    for _ = 1, 90 * 20 do
        E.Step(st, 0.05)
        local alive
        for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.owner == 1 and E.IsHero(e) then alive = e end end
        if st.players[1].fallen and st.players[1].fallen.ff_paladin and not alive then back = "dead" end
        if back == "dead" and alive then back = "back" break end
    end
    check(back == "back", "ff: the fallen hero comes back by itself (" .. tostring(back) .. ")")

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
        and all:find("Train Riflemen", 1, true) and all:find("Send to: nowhere (they wait)", 1, true),
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

-- Subgroups: a hero and footmen selected; click the footman icon for its
-- commands, Tab back to the hero, double-click for just one unit.
function WcSubgroupTests()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    view:NewGame("human", 31)
    local st = view.st
    local hall = E.Hall(st, 1)
    local hx, hy = E.Center(hall)
    local ids = {}
    for i = 1, 4 do table.insert(ids, E.Spawn(st, 1, "footman", hx + 4 + i * 0.6, hy + 4).id) end
    local pal = E.Spawn(st, 1, "paladin", hx + 4, hy + 5)
    table.insert(ids, pal.id)
    view.sel = ids
    view.camX, view.camY = hx * 20 - 300, hy * 20 - 150
    view:Draw()
    local function Has(title)
        for _, c in ipairs(view.cmds) do if c:IsShown() and c.title and c.title:find(title, 1, true) then return true end end
    end
    check(Has("Holy Light"), "wc subgroup: a group with a hero shows the hero's spells first")
    local footIcon
    for i, t in ipairs(view.groupIcons) do if t:IsShown() and st.ents[t.id].type == "footman" then footIcon = i break end end
    view.groupIcons[footIcon]._scripts.OnClick()
    check(not Has("Holy Light") and Has("Move") and #view.sel == 5, "wc subgroup: click a footman: its commands, the group stays")
    view:Key("TAB")
    view:Draw()
    check(Has("Holy Light"), "wc subgroup: Tab: back to the hero")
    local heroIcon
    for i, t in ipairs(view.groupIcons) do if t:IsShown() and t.id == pal.id then heroIcon = i end end
    view.groupIcons[heroIcon]._scripts.OnClick()
    view.groupIcons[heroIcon]._scripts.OnClick()
    check(#view.sel == 1 and view.sel[1] == pal.id, "wc subgroup: double-click: just the hero")
    view:Quit()
end

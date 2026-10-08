-- Warcraft 4: Hero Defense (Games/Warcraft/HeroDefense.lua), the rules and
-- the screen.
local WC = ns.WC
local E = WC.Engine
local HD = WC.Modes.hd

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

local function Creeps(st, fn)
    local n = 0
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == st.hd.creeps and (not fn or fn(e)) then n = n + 1 end
    end
    return n
end

function WcHdTests()
    local ok, bad = WC.CheckMap("hd_castle")
    check(ok, "hd map checks out (" .. table.concat(bad or {}, "; ") .. ")")
    check(WC.MapsFor(1, "hd")[1] == "hd_castle" and WC.MODE_ORDER[4] == "hd", "hd: a mode with its map")

    local st = E.New({ factions = { "human", "orc" }, map = "hd_castle", mode = "hd", seed = 2, teams = { 1, 2 } })
    local p1, p2 = st.players[1], st.players[2]
    check(E.Ally(st, 1, 2) and E.Foe(st, 1, st.hd.creeps), "hd: everyone on one side, the creeps against them")
    local castle = st.ents[st.hd.castle]
    check(castle and WC.Buildings[castle.type].hdCastle and castle.x == 30 and castle.y == 30, "hd: the castle in the middle")
    local a1, a2 = HD.Altar(st, 1), HD.Altar(st, 2)
    check(a1 and a2 and st.ents[st.hd.shop or 0], "hd: an altar each and a merchant")
    check(p1.gold == HD.START_GOLD and st.hd.open.W and not st.hd.open.N, "hd: gold to start, the west lane open")
    Run(st, 1)
    check(not st.over, "hd: a game together doesn't end at once")

    -- One hero each, free.
    check(E.Command(st, 1, { type = "train", building = a1.id, utype = "cls_paladin" }), "hd: a hero at the altar")
    local again, why = E.Command(st, 1, { type = "train", building = a1.id, utype = "cls_mage" })
    check(not again and why == "one hero each", "hd: one hero each (" .. tostring(why) .. ")")
    E.Command(st, 2, { type = "train", building = a2.id, utype = "cls_mage_h" })
    Run(st, 5)
    local h1, h2 = HD.Hero(st, 1), HD.Hero(st, 2)
    check(h1 and h2 and p1.gold == HD.START_GOLD, "hd: both heroes out, nothing paid")

    -- Wave 1: down the west lane only.
    Run(st, HD.FIRST_WAVE + 3 - st.time)
    local west = Creeps(st, function(e) return e.x < 20 end)
    check(st.hd.wave == 1 and west > 0 and west == Creeps(st), "hd: wave 1 comes down the west lane (" .. west .. ")")
    -- Anyone opens a lane, once.
    check(E.Command(st, 2, { type = "hdLane", lane = "N" }) and st.hd.open.N, "hd: player 2 opens the north lane")
    check(not E.Command(st, 1, { type = "hdLane", lane = "N" }), "hd: it's open already")
    Run(st, HD.FIRST_WAVE + HD.WAVE_EVERY + 4 - st.time)
    check(Creeps(st, function(e) return e.y < 20 end) > 0, "hd: wave 2 comes down the north lane too")

    -- Gold: the killer gets the bounty, everyone else a share.
    local c
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.owner == st.hd.creeps then c = e end end
    local g1, g2, bounty = p1.gold, p2.gold, c.hdBounty
    c.hp = 1
    E.Strike(st, h1, c, 50, false, "normal")
    check(p1.gold == g1 + bounty and p2.gold == g2 + math.floor(bounty * HD.SHARE),
        "hd: the killer gets " .. bounty .. ", the other " .. math.floor(bounty * HD.SHARE))

    -- The fountain: hurt units by the castle heal.
    h2.x, h2.y, h2.order, h2.path = 32, 36, nil, nil
    h2.hp = math.floor(h2.maxHp / 2)
    local before = h2.hp
    Run(st, 2)
    check(h2.hp > before + h2.maxHp * 0.04, "hd: the castle heals heroes next to it")
    -- Creeps leave the altars alone.
    check(not E.CanHit(st, c, a1), "hd: the altars can't be hit")

    -- A fallen hero comes back at its altar, by itself.
    E.Strike(st, c, h1, 99999, false, "normal")
    check(not HD.Hero(st, 1) and p1.fallen and next(p1.fallen), "hd: player 1's hero falls")
    Run(st, 2)
    check(a1.queue[1] and a1.queue[1]:sub(1, 2) == "v:", "hd: it's on its way back at the altar")
    Run(st, 60)
    check(HD.Hero(st, 1) ~= nil, "hd: and it's back")

    -- The castle falls: everyone loses.
    castle.hp = 1
    E.Strike(st, c, castle, 100, false, "siege")
    Run(st, 1)
    check(st.over and st.winner == 0, "hd: the castle falls, the game is lost")
end

-- Two computers on one lane win the game; the same seed plays the same game.
function WcHdAiTests()
    local function Game()
        local st = E.New({ factions = { "human", "orc" }, map = "hd_castle", mode = "hd", seed = 5 })
        Run(st, 1500, { 1, 2 })
        return st
    end
    local st = Game()
    check(st.over and st.winner == 1 and st.hd.wave == HD.WAVES, "hd ai: two computers hold one lane to the end (wave "
        .. st.hd.wave .. ", winner " .. tostring(st.winner) .. ")")
    local lv = 0
    for p = 1, 2 do local h = HD.Hero(st, p) if h then lv = math.max(lv, h.level) end end
    check(lv >= 6, "hd ai: their heroes grew (level " .. lv .. ")")
    print(string.format("  hd: two computers, one lane: winner %s after %.1f min, best hero level %d", tostring(st.winner), st.time / 60, lv))
    check(E.Hash(Game()) == E.Hash(st), "hd ai: the same seed plays the same game")

    -- The lobby starts it alone, or with everyone on one team.
    local L = ns.WarcraftLobby
    check(L.CanStart({ mode = "hd", map = "hd_castle", slots = { { kind = "host", team = 1, race = "human" }, { kind = "open", team = 2 } } }),
        "hd lobby: alone")
    check(L.CanStart({ mode = "hd", map = "hd_castle", slots = { { kind = "host", team = 1, race = "human" }, { kind = "cpu", team = 1, race = "orc", diff = "normal" } } }),
        "hd lobby: everyone on one team")
end

-- The screen: from the lobby, the altar's heroes, the castle's lanes, the top bar.
function WcHdPageTests()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    ns.db.warcraft.lobby = nil
    view:ShowLobby()
    local f = view.lobbyFrame
    for _, b in ipairs(f.modes) do if b.key == "hd" then b._scripts.OnClick() end end
    check(ns.db.warcraft.lobby.mode == "hd" and f.maps[1].key == "hd_castle", "hd lobby: Hero Defense and its map")
    f.start._scripts.OnClick()
    local st = view.st
    check(st and st.mode == "hd" and st.hd, "hd page: a game alone")
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
    check(view.lumberText:GetText():find("^Castle 10000") and view.foodText:GetText():find("1 lane", 1, true),
        "hd page: the castle and lanes in the top bar (" .. tostring(view.foodText:GetText()) .. ")")
    -- The altar: all eight heroes.
    view.sel = { HD.Altar(st, 1).id }
    local all = Titles()
    check(all:find("Warrior", 1, true) and all:find("Death Knight", 1, true) and all:find("Druid", 1, true),
        "hd page: the altar offers the heroes (" .. all .. ")")
    -- The castle: the lanes.
    view.sel = { st.hd.castle }
    all = Titles()
    check(all:find("West lane: open", 1, true) and all:find("Open the North lane (N)", 1, true), "hd page: the castle's lanes (" .. all .. ")")
    Click("Open the North lane (N)")
    check(st.hd.open.N, "hd page: open the north lane")
    ns.db.warcraft.lobby = nil
    view:Quit()
end

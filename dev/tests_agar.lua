-- Agar.io: the arena, practice bots, and Live between real players.
local S = ns.Session
local AG = ns.Games.agario

local function View() return ns.UI.pages.agario.view end
-- Run the arena for `seconds` (the canvas's game loop, frame by frame).
function AgarRun(seconds)
    local view = View()
    local c = view.canvas
    for _ = 1, math.floor(seconds / 0.05) do
        Advance(0.05)
        c._scripts.OnUpdate(c, 0.05)
    end
end

function AgarPractice()
    SlashCmdList.FUNNGAMES("")
    ns.UI:SelectTab("agario")
    Advance(0)
    View().practiceButton._scripts.OnClick()
    Advance(3)
    local s = S.Get("agario")
    check(s and #s.players == 5, "agar: four bots in the lobby")
    View().buttons.start._scripts.OnClick()
    check(s.phase == "rolling", "agar: arena open")
    AgarRun(0.1)
    local view = View()
    check(view.rt and view.me and view.me.alive, "agar: you're in the arena")
    local n = 0
    for _ in pairs(view.bots) do n = n + 1 end
    check(n == 4 and #view.food == AG.FOOD, "agar: four bots and the dots")

    -- Move right with D.
    local x0 = view.me.x
    view.held.D = true
    AgarRun(0.5)
    view.held.D = nil
    check(view.me.x > x0 + 30, "agar: D moves you right")

    -- Eat a smaller bot sitting on you.
    -- Set the scene: both alive, the other bots far away and small (they
    -- wander, and could eat one of us first).
    local bot = view.bots.Ragnar
    for name, b in pairs(view.bots) do
        if name ~= "Ragnar" then b.x, b.y, b.r = 50, 50, 5 end
    end
    view.me.alive, bot.alive = true, true
    view.me.x, view.me.y = AG.ARENA_W / 2, AG.ARENA_H / 2
    bot.x, bot.y, bot.r = view.me.x, view.me.y, 5
    view.me.r = 20
    AgarRun(0.05)
    check(not bot.alive and view.me.r > 20, "agar: you swallow a smaller bot")
    AgarRun(3.2)
    check(view.bots.Ragnar.alive, "agar: the bot comes back")

    -- A big bot eats you.
    local big = view.bots.Jaina
    for name, b in pairs(view.bots) do
        if name ~= "Jaina" then b.x, b.y, b.r = 50, 50, 5 end
    end
    view.me.alive, big.alive = true, true
    big.x, big.y, big.r = view.me.x, view.me.y, 60
    view.me.r = 12
    AgarRun(0.05)
    check(not view.me.alive and view.eatenBy == "Jaina", "agar: a bigger bot swallows you")
    check(view.center:GetText():find("Jaina", 1, true), "agar: it says who ate you")
    view.canvas._scripts.OnMouseDown(view.canvas, "LeftButton")
    check(view.me.alive and view.me.r == AG.START_R, "agar: click to jump back in")
    check(ns.db.best and ns.db.best.agarioMass and ns.db.best.agarioMass >= AG.Mass(20), "agar: best mass saved")
    -- Mass: every dot is +1; small blobs never shrink, big ones slowly do.
    local r = AG.START_R
    local m0 = AG.Mass(r)
    for _ = 1, 50 do r = AG.Feed(r) end
    check(AG.Mass(r) == m0 + 50, "agar: 50 dots = 50 more mass (" .. m0 .. " -> " .. AG.Mass(r) .. ")")
    check(AG.Decay(r, 60) == r, "agar: a small blob doesn't shrink")
    local big = math.sqrt(1000 * AG.DOT)
    local after = AG.Mass(AG.Decay(big, 1))
    check(after < 1000 and after >= 998, "agar: a big blob loses a little mass a second (" .. after .. ")")
    check(view.rows[1]:GetText() ~= "", "agar: the leaderboard fills")

    -- No cap at 89 any more: big blobs grow on, and the camera zooms out.
    view.me.r = 150
    AgarRun(1)
    check(view.me.r > 140 and view.zoom < 0.7, "agar: you can grow big, the camera zooms out (" .. math.floor(view.me.r) .. ")")
    local r0 = view.me.r
    view.food[1].x, view.food[1].y = view.me.x, view.me.y
    AgarRun(0.05)
    check(view.me.r - r0 < 0.2, "agar: a dot means little to a big blob")

    -- Leaving the tab stops the arena link.
    ns.UI:SelectTab("stats")
    Advance(0)
    check(view.rt == nil, "agar: switching tabs pauses the arena")
    ns.UI:SelectTab("agario")
    AgarRun(0.1)
    check(view.rt ~= nil, "agar: back in when you return")
    view:CloseArena()
    check(S.Get("agario") == nil, "agar: closed")
end

-- Real players over the realm channel.
function AgarHost()
    SlashCmdList.FUNNGAMES("")
    ns.UI:SelectTab("agario")
    Advance(0)
    ns.db.arcadeScope = "realm"
    Advance(0)
    View().createButton._scripts.OnClick()
    View().buttons.start._scripts.OnClick()
    check(S.Get("agario").phase == "rolling", "agar: host opened the arena")
end

function AgarJoin()
    SlashCmdList.FUNNGAMES("")
    ns.UI:SelectTab("agario")
    Advance(0)
    local list = S.Lobbies("agario")
    check(#list == 1, "agar: " .. PLAYER_NAME .. " sees the open arena")
    View().lobbyList.rows[1].join._scripts.OnClick()
end

function AgarSees(name)
    local view = View()
    local p = view.rt and view.rt.peers[name]
    check(p and p.state.x and p.state.r, "agar: " .. PLAYER_NAME .. " sees " .. name .. "'s blob")
    return p and p.state.x or 0
end

function AgarPlace(x, y, r)
    local me = View().me
    me.x, me.y, me.r = x, y, r
end

function AgarAlive()
    return View().me.alive
end

function AgarHide()
    ns.UI:SelectTab("stats")
    Advance(0)
end

function AgarGone(name)
    check(View().rt.peers[name] == nil, "agar: " .. name .. " left " .. PLAYER_NAME .. "'s arena")
end

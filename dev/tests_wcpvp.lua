-- Warcraft III PvP: lockstep on its own (two games, lost messages), then
-- two players over a code lobby.
local WC = ns.WC
local E = WC.Engine
local L = ns.Lockstep
local S = ns.Session

-- Two lockstep games wired to each other in memory; every third message is
-- lost on the way. Both sides give commands; the games must stay the same.
function WcLockstepTests(lose)
    lose = lose or 3
    local sts = {}
    local inbox = { {}, {} }
    local sent = 0
    local gs = {}
    for seat = 1, 2 do
        sts[seat] = E.New({ factions = { "human", "orc" }, seed = 4242 })
        gs[seat] = L.New({ id = "test-" .. seat, seat = seat, peer = "x",
            hash = function() return E.Hash(sts[seat]) end,
            send = function(data)
                sent = sent + 1
                if lose == 0 or sent % lose ~= 0 then table.insert(inbox[3 - seat], data) end
            end })
    end
    local now = 0
    local function Workers(st, p)
        local out = {}
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e.owner == p and e.kind == "unit" then table.insert(out, e.id) end
        end
        return out
    end
    for frame = 1, 1200 do -- 60 seconds at 20 frames a second
        now = now + 0.05
        -- Now and then each side gives orders: train a worker, move some.
        for seat = 1, 2 do
            local st = sts[seat]
            if frame % 97 == seat * 11 then
                gs[seat]:Command({ type = "train", building = E.Hall(st, seat).id, utype = seat == 1 and "peasant" or "peon" })
            end
            if frame % 151 == seat * 7 then
                local ws = Workers(st, seat)
                gs[seat]:Command({ type = "move", units = { ws[1], ws[2] }, x = 20 + seat + frame % 9 * 0.37, y = 18.25 })
            end
        end
        for seat = 1, 2 do
            local g, st = gs[seat], sts[seat]
            for _, data in ipairs(inbox[seat]) do g:Receive(ns.Serialize.Decode(data), now) end
            inbox[seat] = {}
            g:Update(now)
            g.acc = (g.acc or 0) + 0.05
            while g.acc >= L.TURN and g:CanRun() do
                g.acc = g.acc - L.TURN
                g:Run(function(bySeat)
                    for p = 1, 2 do
                        for _, c in ipairs(bySeat[p] or {}) do E.Command(st, p, c) end
                    end
                    for _ = 1, 5 do E.Step(st, 0.05) end
                end)
            end
        end
    end
    -- 60 seconds is 240 turns; losing every third message makes the game wait now and then.
    local want = lose == 0 and 230 or 150
    check(gs[1].turn > want and gs[2].turn > want, "wc lockstep: both games ran (" .. gs[1].turn .. ", " .. gs[2].turn
        .. " turns, losing " .. (lose == 0 and "nothing" or ("1 in " .. lose)) .. ")")
    -- Bring the slower one level, then compare.
    local t = math.min(gs[1].turn, gs[2].turn)
    check(math.abs(gs[1].turn - gs[2].turn) <= L.DELAY + 1, "wc lockstep: neither runs ahead of the other's commands")
    check(not gs[1].desync and not gs[2].desync, "wc lockstep: the fingerprints always matched")
    local same = 0
    for turn, h in pairs(gs[1].hashes) do
        if gs[2].hashes[turn] then
            check(h == gs[2].hashes[turn], "wc lockstep: same game at turn " .. turn)
            same = same + 1
        end
    end
    check(same >= 5, "wc lockstep: fingerprints compared (" .. same .. ")")
    check(#Workers(sts[1], 1) > 5, "wc lockstep: the orders really happened (trained workers)")
end

local function View() return ns.UI.pages.warcraft.view end

local function Open()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    Advance(0)
end

function WcPvpHost()
    Open()
    local v = View()
    v.friendButton._scripts.OnClick()
    ns.db.arcadeScope = "code"
    Advance(0)
    v.createButton._scripts.OnClick()
    return S.Get("warcraft").code
end

function WcPvpJoin(code)
    Open()
    local v = View()
    v.friendButton._scripts.OnClick()
    v.codeBox:SetText(code)
    v.codeBox._scripts.OnEnterPressed(v.codeBox)
end

function WcPvpStart()
    local v = View()
    v:Refresh()
    check(#S.Get("warcraft").players == 2, "wc pvp: Bob is in the lobby")
    v.pvpButtons.start._scripts.OnClick()
end

function WcPvpRace(f)
    local v = View()
    v:Refresh()
    check(v.picks[1]:IsShown(), "wc pvp: " .. PLAYER_NAME .. " picks a race")
    for _, b in ipairs(v.picks) do if b.faction == f then b._scripts.OnClick() end end
end

-- A quarter second of play on this client (the driver frame's work).
function WcPvpRun(frames)
    local v = View()
    v:Refresh()
    for _ = 1, frames or 5 do v:LockstepTick(0.05) end
end

-- Some orders from this side.
function WcPvpOrder(n)
    local v = View()
    local st = v.st
    if not st or not v.ls then return end
    local seat = v.ls.seat
    if n % 2 == 0 then
        v:Cmd({ type = "train", building = E.Hall(st, seat).id, utype = seat == 1 and "peasant" or "peon" })
    else
        local ids = {}
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e.owner == seat and e.kind == "unit" and #ids < 2 then table.insert(ids, e.id) end
        end
        v:Cmd({ type = "move", units = ids, x = 30 + n * 0.11, y = 20 })
    end
end

function WcPvpTurn() return View().ls and View().ls.turn or -1 end
function WcPvpHash(turn) return View().ls and View().ls.hashes[turn] or "" end
function WcPvpInfo()
    local v = View()
    return v.ls and (v.ls.seat .. ":" .. tostring(v.ls.desync)) or "none"
end

function WcPvpSurrender()
    S.Act("warcraft", "surrender")
end

function WcPvpEnd(expectWin)
    local s = S.Get("warcraft")
    local v = View()
    v:Refresh()
    check(s and s.phase == "done", "wc pvp: " .. PLAYER_NAME .. " sees the game end")
    check(v.overlay:IsShown() and v.overTitle:GetText() == (expectWin and "Victory!" or "Defeat"),
        "wc pvp: " .. PLAYER_NAME .. " sees " .. (expectWin and "Victory" or "Defeat") .. " (" .. tostring(v.overTitle:GetText()) .. ")")
    check(v.ls == nil, "wc pvp: the lockstep stops")
end

-- Group games: this file runs in every player's VM; run.mjs calls the
-- functions on the right player.
local S = ns.Session

function HostOpen(kind)
    ns.UI:ShowGame(kind)
    local view = ns.UI.pages[kind].view
    Advance(0)
    check(view.groupButton._enabled ~= false, kind .. ": group game allowed in a group")
    view.groupButton._scripts.OnClick()
    check(S.Get(kind) and S.Get(kind).phase == "lobby" and not S.Get(kind).test, kind .. ": host opened a group game")
end

function CheckPoppedUp(kind)
    local s = S.Get(kind)
    check(s and s.phase == "lobby" and s.host == (HOST_NAME or "Flintar"), kind .. ": " .. PLAYER_NAME .. " got the game")
    check(ns.UI.frame and ns.UI.frame:IsShown() and ns.UI.tab == kind, kind .. ": window popped up on the game tab")
end

function ClickJoin(kind)
    Advance(0)
    local view = ns.UI.pages[kind].view
    check(view.buttons.join:IsShown(), kind .. ": Join offered")
    view.buttons.join._scripts.OnClick()
end

function HostStart(kind, seats)
    local s = S.Get(kind)
    check(#s.players == seats, kind .. ": " .. seats .. " players seated")
    ns.UI.pages[kind].view.buttons.start._scripts.OnClick()
    check(s.phase == "rolling", kind .. ": started")
end

function ClickRollIfMyTurn(kind)
    local s = S.Get(kind)
    if not s then return "none" end
    ns.UI:SelectTab(kind)
    Advance(0)
    if s.phase == "rolling" and S.MyTurn(s) then
        ns.UI.pages[kind].view.buttons.roll._scripts.OnClick()
    end
    return s.phase
end

function CheckDone(kind)
    local s = S.Get(kind)
    check(s and s.phase == "done" and s.result, kind .. ": " .. PLAYER_NAME .. " sees the game finished")
    -- Every roll in the log was seen in this player's own chat.
    local all = true
    for _, e in ipairs(s.log) do
        if not ns.Rolls.Saw(e.name, e.roll, e.lo, e.hi) then all = false end
    end
    check(all and #s.log > 0, kind .. ": " .. PLAYER_NAME .. " verified every roll")
end

function CheckLedgers(kind)
    local s = S.Get(kind)
    local h = ns.db.history[1]
    check(h and h.id == s.id, kind .. ": " .. PLAYER_NAME .. " recorded the game")
    local r = s.result
    local expect = (r.payee == PLAYER_NAME and r.amount) or (r.payer == PLAYER_NAME and -r.amount) or 0
    check(h and ns.Stats.Net(h) == expect, kind .. ": " .. PLAYER_NAME .. " stats match the result")
    -- The tab: what I'm owed by (or owe) the other player matches the result.
    local other = r.payee == PLAYER_NAME and r.payer or r.payee
    if r.payee == PLAYER_NAME or r.payer == PLAYER_NAME then
        TAB_EXPECT = TAB_EXPECT or {}
        TAB_EXPECT[other] = (TAB_EXPECT[other] or 0) + expect
        check(ns.Tab.Balance(other) == TAB_EXPECT[other], kind .. ": " .. PLAYER_NAME .. " tab with " .. other .. " adds up")
    end
    ns.UI:SelectTab("stats")
    Advance(0)
    check(ns.StatsPage.recentList.rows[1] and ns.StatsPage.recentList.rows[1]:IsShown(), kind .. ": stats tab lists it")
end

function CloseGame(kind)
    ns.UI:SelectTab(kind)
    Advance(0)
    ns.UI.pages[kind].view.buttons.close._scripts.OnClick()
    check(S.Get(kind) == nil, kind .. ": " .. PLAYER_NAME .. " closed the finished game")
end

function WrongRangeRoll()
    check(S.MyTurn(S.Get("deathroll")), "Bob's turn")
    RandomRoll(1, 50) -- typed by hand, wrong range
end

function CheckWrongRangeBanner()
    local s = S.Get("deathroll")
    check(s.banner:find("does not count"), "wrong range is not counted")
    check(S.Find(s, "Bob") and s.players[2].roll == nil, "Bob still has to roll")
end

-- Bob's addon claims to be the host and sends a game where Alice won big.
function SpoofHost()
    local fake = { id = "x", kind = "highlow", host = "Flintar", phase = "done", players = { { name = "Alice" } }, seq = 99,
        result = { payer = "Flintar", payee = "Bob", amount = 9999 } }
    ns.Net.Send("S", ns.Serialize.Encode(fake))
end

function CheckNotSpoofed()
    check(S.Get("highlow") == nil, "a game sent by someone else than its host is ignored")
end

-- A host that makes up a roll: the players' copies flag it.
function FakeTimelineCheck()
    local s = S.Get("deathroll")
    -- A number the host never really rolled (by now it has rolled 1-1000
    -- a few hundred times, so a fixed number like 777 is sometimes real).
    local fake = 777
    while ns.Rolls.Saw("Flintar", fake, 1, 1000) do fake = fake % 1000 + 1 end
    table.insert(s.log, { name = "Flintar", roll = fake, lo = 1, hi = 1000 })
    check(ns.Rolls.Saw("Flintar", fake, 1, 1000) == false, "a made-up roll is not verified")
    table.remove(s.log)
end

---------------------------------------------------------------------------
-- Poker with real players
---------------------------------------------------------------------------
POKER_DONE = 0
function PokerGroupStep(maxHands)
    local s = S.Get("poker")
    if not s then return "none" end
    ns.UI:SelectTab("poker")
    Advance(0)
    ns.Cards.Tick(true)
    local view = ns.UI.pages.poker.view
    local PK = ns.Games.poker
    -- Secrets never travel in the game copy.
    if not S.IsHost(s) then
        check(s._hole == nil and s._secret == nil and s._board == nil, "poker: " .. PLAYER_NAME .. " gets no hidden cards")
        if s.phase == "rolling" and s.stage ~= "over" then
            check(s.reveal == nil and s.secret == nil, "poker: nothing revealed mid-hand")
        end
    end
    if s.phase == "rolling" and s.stage ~= "cut" and s.stage ~= "over" then
        local mine = S.MyCards(s)
        check(mine ~= nil, "poker: " .. PLAYER_NAME .. " got their cards")
        for key in pairs(S.private) do
            check(key:find(s.id, 1, true) == 1, "poker: only own cards are known")
        end
    end
    if s.stage == "over" then
        check(PK.Verify(s, S.MyCards(s)) == true, "poker: " .. PLAYER_NAME .. " verified the deal")
    end
    if view.buttons.cut:IsShown() then
        view.buttons.cut._scripts.OnClick()
    elseif S.MyTurn(s) then
        if math.random(4) == 1 and view.buttons.raise._enabled ~= false then
            view.buttons.raise._scripts.OnClick()
        else
            view.buttons.call._scripts.OnClick()
        end
    elseif S.IsHost(s) and s.stage == "over" then
        POKER_DONE = POKER_DONE + 1
        if POKER_DONE >= maxHands then
            view.buttons.endTable._scripts.OnClick()
            AnswerPopup()
        else
            view.buttons.deal._scripts.OnClick()
        end
    end
    return s.phase
end

function PokerGroupCheckEnd()
    local s = S.Get("poker")
    check(s and s.phase == "done", "poker: " .. PLAYER_NAME .. " sees the table closed")
    local h = ns.db.history[1]
    check(h and h.kind == "poker" and h.id == s.id, "poker: " .. PLAYER_NAME .. " recorded the table")
    local me
    for _, p in ipairs(s.players) do if p.name == PLAYER_NAME then me = p end end
    check(h and ns.Stats.Net(h) == me.net, "poker: " .. PLAYER_NAME .. " stats match the table")
end

---------------------------------------------------------------------------
-- Slot machine with real players: the host is the house.
---------------------------------------------------------------------------
function SlotsGroupPull(n)
    local s = S.Get("slots")
    local view = ns.UI.pages.slots.view
    ns.UI:SelectTab("slots")
    Advance(0)
    for _ = 1, 200 do
        if not view:IsSpinning() then break end
        Advance(0.05)
        view:Animate(GetTime(), 0.05)
    end
    Advance(0) -- (a frame: the Spin button catches up after the reels land)
    if S.MyTurn(s) and view.buttons.spin._enabled ~= false then
        view.buttons.spin._scripts.OnClick()
    end
end

function SlotsGroupCheck()
    local s = S.Get("slots")
    check(s.house == "Flintar" and not S.Game(s):Expect(s, "Flintar"), "slots: the house can't pull its own lever")
    check((s.spins or 0) >= 20, "slots: " .. PLAYER_NAME .. " sees the players' spins (" .. tostring(s.spins) .. ")")
    local sum = 0
    for _, p in ipairs(s.players) do sum = sum + (p.net or 0) end
    check(sum == 0, "slots: " .. PLAYER_NAME .. " sees a zero-sum machine")
    for _, e in ipairs(s.log) do
        check(ns.Rolls.Saw(e.name, e.roll, e.lo, e.hi), "slots: " .. PLAYER_NAME .. " saw " .. e.name .. "'s spin")
    end
end

---------------------------------------------------------------------------
-- Disconnects with real players
---------------------------------------------------------------------------
function DcGroupPlayerOffline(name, offline)
    OFFLINE[name] = offline or nil
    Fire("UNIT_CONNECTION", "party1", not offline)
end

function DcHostSeesOffline(kind, name)
    local s = S.Get(kind)
    local _, p = S.Find(s, name)
    check(p and p.offline and not p.out, kind .. ": the game waits for " .. name)
    check((CHAT[#CHAT] or ""):find(name .. " went offline", 1, true), kind .. ": the host is told about " .. name)
end

function DcHostSeesBack(kind, name)
    local _, p = S.Find(S.Get(kind), name)
    check(p and not p.offline and not p.out, kind .. ": " .. name .. " back in the game")
end

function DcPlayerSeesTag(kind, name)
    local _, p = S.Find(S.Get(kind), name)
    check(p and p.offline, kind .. ": " .. PLAYER_NAME .. " sees " .. name .. " offline")
end

function DcHostGone(kind)
    local s = S.Get(kind)
    check(S.HostOffline(s), kind .. ": " .. PLAYER_NAME .. " sees the host offline")
    ns.UI:SelectTab(kind)
    Advance(0)
    local view = ns.UI.pages[kind].view
    check(view.buttons.close:IsShown() and view.buttons.close:GetText() == "Leave game", kind .. ": Leave game offered")
    if view.buttons.roll then check(view.buttons.roll._enabled == false, kind .. ": Roll! greyed out while the host is away") end
end

-- A /reload: forget everything, then log in again.
function DcReload()
    for k in pairs(S.sessions) do S.sessions[k] = nil end
    for k in pairs(S.private) do S.private[k] = nil end
    ns.UI.frame:Hide()
    Fire("PLAYER_ENTERING_WORLD", false, true)
    Advance(4)
end

function DcAfterReload(kind)
    local s = S.Get(kind)
    check(s and s.phase == "rolling" and ns.UI.frame:IsShown() and ns.UI.tab == kind, kind .. ": " .. PLAYER_NAME .. " is back in the game after a reload")
    if kind == "poker" and s.stage ~= "cut" and s.stage ~= "over" then
        check(S.MyCards(s) ~= nil, "poker: " .. PLAYER_NAME .. " got the cards back after a reload")
    end
end

---------------------------------------------------------------------------
-- Roulette with real players: the host is the house, the ball passes on.
---------------------------------------------------------------------------
function RouletteGroupBet(spot)
    ns.UI:SelectTab("roulette")
    Advance(0)
    local view = ns.UI.pages.roulette.view
    view.cells[spot]._scripts.OnClick(view.cells[spot], "LeftButton")
    for _ = 1, 20 do
        Advance(0.1)
        view:Animate(GetTime(), 0.1)
    end
end

function RouletteGroupThrow()
    local view = ns.UI.pages.roulette.view
    check(S.MyTurn(S.Get("roulette")), "roulette: " .. PLAYER_NAME .. " throws")
    view.buttons.throw._scripts.OnClick()
    Advance(1)
end

function RouletteGroupCheck(round)
    local s = S.Get("roulette")
    check(s.last and s.last.round == round, "roulette: " .. PLAYER_NAME .. " saw round " .. round)
    check(ns.Rolls.Saw(s.last.thrower, s.last.number + 1, 1, 37), "roulette: " .. PLAYER_NAME .. " saw the throw")
    local sum = 0
    for _, p in ipairs(s.players) do sum = sum + p.net end
    check(sum == 0, "roulette: zero-sum for " .. PLAYER_NAME)
end

function PortraitCheck()
    local s = S.Get("poker")
    for _, p in ipairs(s.players) do
        check(p.class == "WARRIOR", "poker: " .. PLAYER_NAME .. " knows " .. p.name .. "'s class")
    end
    ns.UI:SelectTab("poker")
    Advance(0)
    local view = ns.UI.pages.poker.view
    local faces = 0
    for _, seat in ipairs(view.seats) do
        if seat:IsShown() and seat.portrait.face:IsShown() then faces = faces + 1 end
    end
    check(faces == #s.players, "poker: " .. PLAYER_NAME .. " sees a portrait on every seat (" .. faces .. ")")
end

---------------------------------------------------------------------------
-- Blackjack with real players: the host deals.
---------------------------------------------------------------------------
function BjGroupStep()
    local s = S.Get("blackjack")
    if not s then return "none" end
    ns.UI:SelectTab("blackjack")
    Advance(0)
    ns.Cards.Tick(true)
    local view = ns.UI.pages.blackjack.view
    local BJ = ns.Games.blackjack
    if s.stage == "bets" and not S.IsHost(s) and not s.bets[PLAYER_NAME] then
        view.betBox:SetCopper(s.minBet)
        view.placeBet._scripts.OnClick()
        Advance(1)
    elseif s.stage == "bets" and view.buttons.deal:IsShown() and view.buttons.deal._enabled ~= false then
        view.buttons.deal._scripts.OnClick()
    elseif S.MyTurn(s) then
        local _, me = S.Find(s, PLAYER_NAME)
        if BJ.Total(me.hand) < 16 then view.buttons.hit._scripts.OnClick() else view.buttons.stand._scripts.OnClick() end
    elseif s.stage == "over" then
        check(BJ.Verify(s) == true, "blackjack: " .. PLAYER_NAME .. " checked the deal")
        local sum = 0
        for _, p in ipairs(s.players) do sum = sum + p.net end
        check(sum == 0, "blackjack: zero-sum for " .. PLAYER_NAME)
        if S.IsHost(s) then
            BJ_GROUP_ROUNDS = (BJ_GROUP_ROUNDS or 0) + 1
            if BJ_GROUP_ROUNDS >= 2 then
                S.Act("blackjack", "end")
            else
                view.buttons.next._scripts.OnClick()
            end
        end
    end
    return s.phase
end

---------------------------------------------------------------------------
-- Raffle with real players
---------------------------------------------------------------------------
function RaffleGroupBuy(n)
    ns.UI:SelectTab("raffle")
    Advance(0)
    local view = ns.UI.pages.raffle.view
    view.want = n
    view.buy._scripts.OnClick()
end

function RaffleGroupDraw()
    local view = ns.UI.pages.raffle.view
    ns.UI:SelectTab("raffle")
    Advance(0)
    check(view.buttons.draw._enabled ~= false, "raffle: the organizer can draw")
    view.buttons.draw._scripts.OnClick()
    Advance(1)
end

function RaffleGroupCheck(winner)
    local s = S.Get("raffle")
    check(s.phase == "done" and s.draw, "raffle: " .. PLAYER_NAME .. " saw the draw")
    check(ns.Rolls.Saw(s.host, s.draw.ticket, 1, s.draw.tickets), "raffle: " .. PLAYER_NAME .. " saw the organizer's roll")
    check(ns.Games.raffle.Owner(s, s.draw.ticket) == s.draw.winner, "raffle: winner holds the ticket for " .. PLAYER_NAME)
    if PLAYER_NAME == s.draw.winner or s.draw.winner == "Flintar" then
        check(ns.db.history[1] and ns.db.history[1].kind == "raffle", "raffle: recorded for " .. PLAYER_NAME)
    end
    RAFFLE_WINNER = s.draw.winner
end

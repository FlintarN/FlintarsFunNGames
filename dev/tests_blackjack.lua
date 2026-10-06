-- Blackjack: hand totals, every outcome on a chosen deck, and a practice table.
local BJ = ns.Games.blackjack
local S = ns.Session
local function Card(rank, suit) return ((suit or 1) - 1) * 13 + (rank - 1) end

-- Totals
local t, soft = BJ.Total({ Card(14), Card(13) })
check(t == 21 and soft and BJ.IsBlackjack({ Card(14), Card(13) }), "A K is blackjack")
check(BJ.Total({ Card(14), Card(14), Card(9) }) == 21, "A A 9 is 21")
check(BJ.Total({ Card(13), Card(12), Card(5) }) == 25, "K Q 5 busts")
t, soft = BJ.Total({ Card(14), Card(6) })
check(t == 17 and soft, "A 6 is soft 17")
check(not BJ.IsBlackjack({ Card(7), Card(7), Card(7) }), "three cards to 21 is not blackjack")

-- One round on a chosen deck. Deal order with one player:
-- player, dealer up, player, dealer hole, then hits and dealer draws.
local realDeck = ns.Fair.Deck
local function Round(cards, moves)
    local rest = {}
    for i = 1, 52 do rest[i] = i end
    local deck = {}
    for _, c in ipairs(cards) do table.insert(deck, c) end
    for _, c in ipairs(rest) do table.insert(deck, c) end
    ns.Fair.Deck = function() return deck end
    local s = { phase = "rolling", host = "H", test = false, players = { { name = "H" }, { name = "P" } } }
    BJ:Setup(s, { minBet = 100, maxBet = 1000, houseCap = 0 })
    BJ:Begin(s)
    check(s.cutter == "P", "the player cuts")
    BJ:Act(s, "P", "bet:200")
    BJ:Apply(s, "P", 12345)
    for _, m in ipairs(moves or {}) do BJ:Act(s, "P", m) end
    ns.Fair.Deck = realDeck
    return s, s.players[2]
end

local s, p = Round({ Card(10), Card(10), Card(7), Card(6), Card(5) }, { "stand" })
check(s.stage == "over" and BJ.Total(s.dealer) == 21 and p.result == -200, "dealer draws 10 6 5 to 21 and beats 17")
s, p = Round({ Card(14), Card(10), Card(13), Card(9) })
check(p.result == 300 and s.stage == "over", "blackjack pays 3 to 2 (no moves needed)")
s, p = Round({ Card(10), Card(10), Card(6), Card(7), Card(9) }, { "hit" })
check(p.state == "bust" and p.result == -200 and #s.dealer == 2, "player busts; the dealer doesn't draw")
s, p = Round({ Card(6), Card(10), Card(5), Card(6), Card(10), Card(9) }, { "double" })
check(p.wager == 400 and BJ.Total(p.hand) == 21 and p.result == 400, "double: one card, twice the bet, 21 beats dealer bust")
s, p = Round({ Card(10), Card(10), Card(8), Card(8) }, { "stand" })
check(p.result == 0, "18 against 18 is a push")
s, p = Round({ Card(10), Card(14), Card(7), Card(6) }, { "stand" })
check(#s.dealer == 2 and BJ.Total(s.dealer) == 17 and p.result == 0, "dealer stands on soft 17 (push with 17)")
s, p = Round({ Card(10), Card(14), Card(5), Card(13), Card(6) }, { "hit" })
check(BJ.Total(p.hand) == 21 and p.result == -200, "a dealer blackjack beats a three-card 21")
check(s.players[1].net == 200, "the house took the other side")

-- The deal check, with the real deck.
do
    -- A random deck can deal a blackjack, which ends the round at once;
    -- deal again until there is a round to play.
    local t2
    for cut = 777, 900 do
        t2 = { phase = "rolling", host = "H", players = { { name = "H" }, { name = "P" } } }
        BJ:Setup(t2, { minBet = 100, maxBet = 1000, houseCap = 0 })
        BJ:Begin(t2)
        BJ:Act(t2, "P", "bet:100")
        check(BJ:Expect(t2, "P") ~= nil and t2.dealer[2] == nil, "bets open, nothing dealt")
        BJ:Apply(t2, "P", cut)
        if t2.stage == "play" then break end
    end
    check(t2.dealer[2] == 0 and t2.dealt[t2.holeAt] == 0, "the dealer's second card is hidden while you play")
    check(BJ.Verify(t2) == nil, "nothing to check mid-round")
    BJ:Act(t2, "P", "stand")
    check(BJ.Verify(t2) == true, "honest deal checks out after the round")
    t2.dealt[1] = (t2.dealt[1] % 52) + 1
    check(BJ.Verify(t2) == false, "a card that isn't from the sealed deck is caught")
end

-- Bets
do
    local t3 = { phase = "rolling", host = "H", players = { { name = "H" }, { name = "P" } } }
    BJ:Setup(t3, { minBet = 100, maxBet = 1000, houseCap = 0 })
    BJ:Begin(t3)
    check(BJ:Act(t3, "P", "bet:50") == false and BJ:Act(t3, "P", "bet:5000") == false, "bets outside min/max refused")
    check(BJ:Act(t3, "H", "bet:100") == false, "the dealer can't bet")
end

---------------------------------------------------------------------------
-- Practice through the page
---------------------------------------------------------------------------
function BlackjackStart()
    SlashCmdList.FUNNGAMES("")
    ns.UI:SelectTab("blackjack")
    Advance(0)
    local view = ns.UI.pages.blackjack.view
    view.practiceButton._scripts.OnClick()
    Advance(2)
    local s = S.Get("blackjack")
    check(s.house == "Gazlowe" and #s.players == 4, "blackjack: Gazlowe deals, two bots join")
    view.buttons.start._scripts.OnClick()
    Advance(0)
    check(view.betBox:IsShown() and view.betBox:GetCopper() == s.minBet, "blackjack: your bet box starts at the min bet")
    view.betBox:SetCopper(2500)
    view.placeBet._scripts.OnClick()
    Advance(3) -- bots bet too
    check(s.bets.Flintar == 2500, "blackjack: bet placed")
    local bots = 0
    for who in pairs(s.bets) do if who ~= "Flintar" then bots = bots + 1 end end
    check(bots == 2, "blackjack: both bots bet")
    check(view.buttons.deal._enabled ~= false, "blackjack: you can deal")
    view.buttons.deal._scripts.OnClick()
end

BJ_ROUNDS = 0
function BlackjackStep()
    local s = S.Get("blackjack")
    local view = ns.UI.pages.blackjack.view
    ns.UI:SelectTab("blackjack")
    Advance(2)
    ns.Cards.Tick(true)
    if s.phase ~= "rolling" then return "done" end
    if s.stage == "play" then
        check(view.dealerCards[2] and view.dealerCards[2].card == 0, "blackjack: the hole card is face down during play")
        local _, me = S.Find(s, "Flintar")
        if S.MyTurn(s) then
            check(view.buttons.hit._enabled ~= false and view.buttons.stand._enabled ~= false, "blackjack: Hit and Stand on your turn")
            -- your cards on your seat, face up
            local seat
            for _, st in ipairs(view.seats) do
                if st:IsShown() and (st.name:GetText() or ""):find("Flintar", 1, true) then seat = st end
            end
            check(seat and seat.cards[1].card == me.hand[1] and seat.cards[2].card == me.hand[2], "blackjack: your cards face up on your seat")
            if BJ.Total(me.hand) < 15 then view.buttons.hit._scripts.OnClick() else view.buttons.stand._scripts.OnClick() end
        else
            check(view.buttons.hit._enabled == false, "blackjack: Hit greyed out while waiting")
        end
    elseif s.stage == "over" then
        local sum = 0
        for _, p in ipairs(s.players) do sum = sum + p.net end
        check(sum == 0, "blackjack: house and players add up to zero")
        check(BJ.Verify(s) == true, "blackjack: deal checked")
        check(view.dealerCards[2].card == s.dealer[2] and s.dealer[2] > 0, "blackjack: the hole card is turned over")
        BJ_ROUNDS = BJ_ROUNDS + 1
        if BJ_ROUNDS >= 4 then
            view.buttons.endTable._scripts.OnClick()
            AnswerPopup()
            return "done"
        end
        view.buttons.next._scripts.OnClick()
        Advance(3)
        check(s.stage == "bets" and s.bets.Flintar == 2500, "blackjack: next round keeps your bet")
        view.buttons.deal._scripts.OnClick()
    end
    return "going"
end

function BlackjackEnd()
    local s = S.Get("blackjack")
    check(s.phase == "done" and s.result.transfers, "blackjack: closed with a settlement")
    check(#ns.db.history == 0, "blackjack: practice stays out of the stats")
    ns.UI.pages.blackjack.view.buttons.close._scripts.OnClick()
end

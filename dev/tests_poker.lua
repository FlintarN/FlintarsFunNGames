-- Poker: hand ranking, the sealed deck, and a practice table with bots.
local PK = ns.Games.poker
local S = ns.Session

-- SHA-256 known answers.
check(ns.Fair.Hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "sha-256 of abc")
check(ns.Fair.Hash("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "sha-256 of empty")
check(ns.Fair.Hash(string.rep("a", 100)) == "2816597888e4a0d3a36b82b83316ab32680eb8f00f8cd3b904d681246d285a0e", "sha-256 over two blocks")

-- Deck: a shuffle of 1-52, the same for the same secret and cut.
local d1, d2, d3 = ns.Fair.Deck("s", 5), ns.Fair.Deck("s", 5), ns.Fair.Deck("s", 6)
local seen, same, diff = {}, true, false
for i = 1, 52 do
    seen[d1[i]] = true
    if d1[i] ~= d2[i] then same = false end
    if d1[i] ~= d3[i] then diff = true end
end
local all = true
for c = 1, 52 do if not seen[c] then all = false end end
check(all and #d1 == 52, "deck holds every card once")
check(same and diff, "deck depends on secret and cut only")

-- Cards: rank 2-14, suit 1-4.
local function Card(rank, suit) return (suit - 1) * 13 + (rank - 1) end
check(PK.Rank(Card(14, 1)) == 14 and PK.Suit(Card(14, 1)) == 1 and PK.Rank(Card(2, 4)) == 2, "card numbering")

local function Hand(list)
    local out = {}
    for _, rs in ipairs(list) do table.insert(out, Card(rs[1], rs[2])) end
    return out
end
local royal = PK.Best(Hand({ { 14, 2 }, { 13, 2 }, { 12, 2 }, { 11, 2 }, { 10, 2 }, { 2, 1 }, { 3, 3 } }))
local quads = PK.Best(Hand({ { 9, 1 }, { 9, 2 }, { 9, 3 }, { 9, 4 }, { 13, 1 }, { 2, 2 }, { 3, 2 } }))
local boat = PK.Best(Hand({ { 9, 1 }, { 9, 2 }, { 9, 3 }, { 4, 4 }, { 4, 1 }, { 2, 2 }, { 3, 2 } }))
local wheel = PK.Best(Hand({ { 14, 1 }, { 2, 2 }, { 3, 3 }, { 4, 4 }, { 5, 1 }, { 9, 2 }, { 13, 2 } }))
local six = PK.Best(Hand({ { 6, 1 }, { 2, 2 }, { 3, 3 }, { 4, 4 }, { 5, 1 }, { 9, 2 }, { 13, 2 } }))
local twoPair = PK.Best(Hand({ { 14, 1 }, { 14, 2 }, { 8, 3 }, { 8, 4 }, { 5, 1 }, { 5, 2 }, { 13, 2 } }))
check(royal[1] == 9 and PK.Describe(royal) == "Royal flush", "royal flush")
check(PK.Compare(royal, quads) == 1 and PK.Compare(quads, boat) == 1, "royal > quads > full house")
check(wheel[1] == 5 and wheel[2] == 5, "A-2-3-4-5 is a five-high straight")
check(PK.Compare(six, wheel) == 1, "six-high straight beats the wheel")
check(twoPair[1] == 3 and twoPair[2] == 14 and twoPair[3] == 8 and twoPair[4] == 13, "best two pair keeps the king kicker")
check(PK.Describe(boat) == "Full house, 9s over 4s", "describe full house: " .. PK.Describe(boat))
check(PK.DescribeCards(Hand({ { 12, 1 }, { 12, 3 } })) == "Pair of Queens", "describe pocket pair")

-- Raise limits.
local t = { phase = "rolling", players = { { name = "A", net = 0 }, { name = "B", net = 0 }, { name = "C", net = 0 } } }
PK:Setup(t, { bet = 10, maxRaise = 50 })
t.dealer, t.stage, t.hand = 1, "preflop", 1
t.pot, t.board, t._board, t._hole = 0, {}, { 1, 2, 3, 4, 5 }, {}
for _, p in ipairs(t.players) do p.bet = 0 end
t.high, t.raises, t.lastRaise, t.toAct = 10, 1, 10, 1
t.players[3].bet = 10
local lo, hi = PK:RaiseRange(t, "A")
check(lo == 10 and hi == 50, "min raise is the big blind, max is the table's")
check(PK:Act(t, "A", "raise:5") == false, "a raise below the minimum is refused")
check(PK:Act(t, "A", "raise:60") == false, "a raise above the max is refused")
check(PK:Act(t, "A", "raise:30") == true and t.high == 40 and t.players[1].bet == 40, "raise by 30 makes it 40 to call")
lo = PK:RaiseRange(t, "B")
check(lo == 30, "after a raise of 30 the minimum raise is 30")
check(PK:Act(t, "B", "raise:30") and PK:Act(t, "C", "raise:30"), "re-raises")
check(PK:RaiseRange(t, "A") == nil, "four bets: no more raising this round")

-- A tampered deal is caught.
local fake = { players = { { name = "A" }, { name = "B" } }, board = {}, cut = 7 }
fake.secret = "abc"
fake.commit = ns.Fair.Hash("abc")
check(PK.Verify(fake) == true, "honest deal verifies")
fake.commit = ns.Fair.Hash("xyz")
check(PK.Verify(fake) == false, "secret swapped after the seal is caught")
fake.commit = ns.Fair.Hash("abc")
fake.board = { ns.Fair.Deck("abc", 7)[9] }
check(PK.Verify(fake) == false, "a board card that is not from the deck is caught")

---------------------------------------------------------------------------
-- Practice table through the window
---------------------------------------------------------------------------
local function NetSum(s)
    local sum = 0
    for _, p in ipairs(s.players) do sum = sum + (p.net or 0) end
    return sum
end

function PokerPracticeStart()
    SlashCmdList.FUNNGAMES("")
    ns.UI:SelectTab("poker")
    local view = ns.UI.pages.poker.view
    Advance(0)
    check(view.setup:IsShown(), "poker: setup shows")
    -- Help: rules for every game, hand rankings on poker.
    local UI = ns.UI
    for _, kind in ipairs(ns.GAME_ORDER) do
        UI:SelectTab(kind)
        Advance(0)
        check(UI.rulesButton:IsShown() and UI.handsButton:IsShown() == (kind == "poker"), kind .. ": help buttons")
        UI.rulesButton._scripts.OnClick()
        check(ns.Help:IsShown() and ns.Help.text:GetText():find("The idea", 1, true), kind .. ": rules open")
        UI.rulesButton._scripts.OnClick()
        check(not ns.Help:IsShown(), kind .. ": Rules again closes them")
    end
    UI:SelectTab("poker")
    Advance(0)
    UI.handsButton._scripts.OnClick()
    check(ns.Help:IsShown() and ns.Help.rows[1]:IsShown() and ns.Help.rows[1].cards[1].card == 13 * 1 + 13, "poker: hand rankings with example cards")
    ns.Help:ShowHands({ cat = 2, high = 10 })
    check(ns.Help.rows[9].mine:GetText() == "Your hand" and ns.Help.rows[1].mine:GetText() == "", "poker: your hand is highlighted")
    ns.Help:ShowHands({ cat = 9, high = 9 })
    check(ns.Help.rows[2].mine:GetText() == "Your hand" and ns.Help.rows[1].mine:GetText() == "", "poker: straight flush is not called royal")
    UI:SelectTab("stats")
    check(not ns.Help:IsShown() and not UI.rulesButton:IsShown(), "help closes when changing tabs")
    UI:SelectTab("poker")
    Advance(0)

    view.practiceButton._scripts.OnClick()
    check(S.Get("poker") and S.Get("poker").test, "poker: practice table opened")
end

function PokerAfterJoin()
    local s = S.Get("poker")
    local view = ns.UI.pages.poker.view
    check(#s.players == 4, "poker: three bots sat down")
    check(s.players[1].class == "WARRIOR" and s.players[2].class ~= nil, "poker: everyone's class is known")
    ns.UI:SelectTab("poker")
    Advance(0)
    local mine = view.seats[1].portrait
    check(mine.face._portrait == "player" and mine.face:IsShown(), "poker: your own portrait in your seat")
    local bot = view.seats[2].portrait
    check(not bot.face:IsShown() and bot.class._tex:find("UI-Classes-Circles", 1, true), "poker: bots show their class icon")
    view.buttons.start._scripts.OnClick()
    check(s.phase == "rolling" and s.stage == "cut", "poker: first hand waits for the cut")
    check(s.cutter ~= "Flintar", "poker: the host never cuts when someone else can")
end

POKER_HANDS = 0
-- One step: act if it's my turn, deal the next hand if it's over.
function PokerStep(maxHands)
    local s = S.Get("poker")
    if not s then return "none" end
    ns.UI:SelectTab("poker")
    Advance(0)
    ns.Cards.Tick(true)
    local view = ns.UI.pages.poker.view
    check(NetSum(s) + (s.pot or 0) == 0 or s.stage == "over" or s.stage == "cut", "poker: no gold appears or vanishes")
    if s.stage == "over" then
        check(NetSum(s) == 0, "poker: hand settled to zero-sum")
        check(PK.Verify(s, S.MyCards(s)) == true, "poker: practice deal verifies")
        POKER_HANDS = POKER_HANDS + 1
        if POKER_HANDS >= maxHands then
            view.buttons.endTable._scripts.OnClick()
            AnswerPopup()
        else
            view.buttons.deal._scripts.OnClick()
        end
    elseif s.stage ~= "cut" and not S.MyTurn(s) and S.Find(s, "Flintar") and not select(2, S.Find(s, "Flintar")).folded then
        check(view.buttons.fold:IsShown() and view.buttons.fold._enabled == false, "poker: move buttons greyed out, not hidden, while waiting")
        check(view.buttons.deal:IsShown() and view.buttons.deal._enabled == false, "poker: Next hand greyed out mid-hand")
    elseif S.MyTurn(s) then
        local mine = S.MyCards(s)
        local seat = view.seats[1] -- you always sit at the bottom
        check(mine and seat.cards[1].card == mine[1] and seat.cards[2].card == mine[2], "poker: my cards are face up in my seat")
        check(view.buttons.fold:IsShown() and view.buttons.call:IsShown(), "poker: move buttons on my turn")
        check(view.buttons.fold._enabled ~= false and view.buttons.call._enabled ~= false, "poker: move buttons usable on my turn")
        -- Mix it up a little so raises and folds get tested too.
        local pick = math.random(10)
        if pick <= 2 and view.buttons.raise:IsShown() and view.buttons.raise._enabled ~= false then
            local min, max = PK:RaiseRange(s, "Flintar")
            check(view.buttons.box:IsShown() and view.buttons.box:GetCopper() == min, "poker: raise box starts at the minimum")
            local high = s.high
            if pick == 1 then
                view.buttons.box:SetCopper(999999999) -- too much: clamped to the max raise
                view.buttons.raise._scripts.OnClick()
                check(s.high == high + max or not S.Get("poker"), "poker: a raise above the max is clamped")
            else
                view.buttons.pot._scripts.OnClick()
                local want = math.max(min, math.min(max, s.pot))
                check(view.buttons.box:GetCopper() == want, "poker: Pot fills in the pot size")
                view.buttons.raise._scripts.OnClick()
                check(s.high == high + want, "poker: raised by the amount in the box")
            end
        elseif pick == 10 then
            view.buttons.fold._scripts.OnClick()
        else
            view.buttons.call._scripts.OnClick()
        end
    end
    return s.phase
end

function PokerPracticeEnd()
    local s = S.Get("poker")
    Advance(5)
    check(s.phase == "done" and s.result and s.result.transfers, "poker: table closed with a settlement")
    local paid, got = 0, 0
    for _, t in ipairs(s.result.transfers) do
        paid = paid + t.amount
        check(t.amount > 0, "poker: payments are positive")
    end
    for _, p in ipairs(s.players) do if p.net > 0 then got = got + p.net end end
    check(paid == got, "poker: payments cover every winner exactly")
    check(#ns.db.history == 0, "poker: practice is not in the stats")
    local view = ns.UI.pages.poker.view
    view.buttons.close._scripts.OnClick()
    Advance(0)
    check(S.Get("poker") == nil and view.setup:IsShown(), "poker: Close returns to setup")
end

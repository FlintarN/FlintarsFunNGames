-- Poker: Texas Hold'em for 2-6 players, kept simple.
--
-- Betting: blinds are half the big blind and the big blind. A bet or raise
-- can be any amount from the minimum (the big blind, or the last raise if it
-- was bigger) up to the table's max raise, with at most four bets per round
-- (a bet and three raises). Nobody has a stack: each player's running total
-- (net) goes up and down, and when the host ends the table the addon works
-- out who pays whom. No stacks means no all-ins and no side pots.
--
-- Each hand: the host's addon seals a secret (see Core\Fair.lua), a player
-- cuts the deck with a real /roll, the deck is shuffled from secret + cut,
-- hole cards are whispered to each player, and the secret is shown when the
-- hand is over so every addon can check the deal.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "poker",
    name = "Poker",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconPoker",
    short = "Texas Hold'em for 2-6 players. Raise what you like, settle up at the end.",
    rules = "Texas Hold'em. Raise any amount from the big blind up to the table's max raise, "
        .. "up to four bets per round. Each hand a player cuts the deck with a real /roll. "
        .. "Your running total shows on your seat; when the host ends the table, losers pay winners.",
    fairness = "The deck is sealed before the cut and checked by every addon after each hand, so the host "
        .. "can't stack it. The host's addon does deal the cards, so play with people you trust.",
    minPlayers = 2,
    maxPlayers = 6,
    practiceBots = 3,
    fields = {
        { key = "bet", label = "Big blind", money = true, default = 1000, min = 2, max = 10000000 },
        { key = "maxRaise", label = "Max raise", money = true, default = 10000, min = 2, max = 100000000 },
    },
}
ns.Games.poker = G

local CUT_MAX = 1000000
local MAX_BETS = 4
local STREETS = { preflop = "flop", flop = "turn", turn = "river", river = "showdown" }
local BOARD_SHOWN = { preflop = 0, flop = 3, turn = 4, river = 5 }

---------------------------------------------------------------------------
-- Cards: 1-52. Rank 2-14 (14 = ace), suit 1-4 (spades, hearts, diamonds, clubs).
---------------------------------------------------------------------------
function G.Rank(c) return (c - 1) % 13 + 2 end
function G.Suit(c) return math.floor((c - 1) / 13) + 1 end

local RANK_NAME = { [11] = "Jack", [12] = "Queen", [13] = "King", [14] = "Ace" }
local function RankName(r, plural)
    local n = RANK_NAME[r] or tostring(r)
    if plural then return n == "6" and "Sixes" or (n .. "s") end
    return n
end

local CATEGORY = { "High card", "Pair", "Two pair", "Three of a kind", "Straight", "Flush",
    "Full house", "Four of a kind", "Straight flush" }

-- Score of exactly five cards: { category, tiebreak ranks... }, compare in order.
local function Score5(cards)
    local ranks, counts, flush = {}, {}, true
    for i, c in ipairs(cards) do
        local r = G.Rank(c)
        ranks[i] = r
        counts[r] = (counts[r] or 0) + 1
        if G.Suit(c) ~= G.Suit(cards[1]) then flush = false end
    end
    table.sort(ranks, function(a, b) return a > b end)

    local straightHigh
    local unique = {}
    for r in pairs(counts) do table.insert(unique, r) end
    if #unique == 5 then
        table.sort(unique, function(a, b) return a > b end)
        if unique[1] - unique[5] == 4 then
            straightHigh = unique[1]
        elseif unique[1] == 14 and unique[2] == 5 then
            straightHigh = 5 -- A-2-3-4-5
        end
    end

    -- Groups: biggest count first, then highest rank.
    local groups = {}
    for r, n in pairs(counts) do table.insert(groups, { r = r, n = n }) end
    table.sort(groups, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.r > b.r
    end)
    local byGroup = {}
    for _, g in ipairs(groups) do table.insert(byGroup, g.r) end

    if straightHigh and flush then return { 9, straightHigh } end
    if groups[1].n == 4 then return { 8, unpack(byGroup) } end
    if groups[1].n == 3 and groups[2].n == 2 then return { 7, unpack(byGroup) } end
    if flush then return { 6, unpack(ranks) } end
    if straightHigh then return { 5, straightHigh } end
    if groups[1].n == 3 then return { 4, unpack(byGroup) } end
    if groups[1].n == 2 and groups[2].n == 2 then return { 3, unpack(byGroup) } end
    if groups[1].n == 2 then return { 2, unpack(byGroup) } end
    return { 1, unpack(ranks) }
end

function G.Compare(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x > y and 1 or -1 end
    end
    return 0
end

-- Best five of any number of cards (5-7).
function G.Best(cards)
    local best
    local n = #cards
    if n < 5 then return nil end
    local pick = {}
    local function Try(start, depth)
        if depth > 5 then
            local score = Score5(pick)
            if not best or G.Compare(score, best) > 0 then best = { unpack(score) } end
            return
        end
        for i = start, n - (5 - depth) do
            pick[depth] = cards[i]
            Try(i + 1, depth + 1)
        end
    end
    Try(1, 1)
    return best
end

function G.Describe(score)
    if not score then return "" end
    local cat, r = score[1], score[2]
    if cat == 9 then return r == 14 and "Royal flush" or "Straight flush" end
    if cat == 8 then return "Four " .. RankName(r, true) end
    if cat == 7 then return "Full house, " .. RankName(r, true) .. " over " .. RankName(score[3], true) end
    if cat == 6 then return "Flush, " .. RankName(r) .. " high" end
    if cat == 5 then return "Straight, " .. RankName(r) .. " high" end
    if cat == 4 then return "Three " .. RankName(r, true) end
    if cat == 3 then return "Two pair, " .. RankName(r, true) .. " and " .. RankName(score[3], true) end
    if cat == 2 then return "Pair of " .. RankName(r, true) end
    return RankName(r) .. " high"
end

-- Describe a partial hand too (two hole cards before the flop).
function G.DescribeCards(cards)
    if #cards >= 5 then return G.Describe(G.Best(cards)) end
    if #cards == 2 then
        local a, b = G.Rank(cards[1]), G.Rank(cards[2])
        if a == b then return "Pair of " .. RankName(a, true) end
        local hi, lo = math.max(a, b), math.min(a, b)
        return RankName(hi) .. "-" .. RankName(lo) .. (G.Suit(cards[1]) == G.Suit(cards[2]) and ", suited" or "")
    end
    return ""
end

---------------------------------------------------------------------------
-- Seats
---------------------------------------------------------------------------
local function Player(s, name)
    for i, p in ipairs(s.players) do
        if p.name == name then return p, i end
    end
end

local function NextSeat(s, i)
    return i % #s.players + 1
end

-- Next seat after i still in the hand.
local function NextActive(s, i)
    for _ = 1, #s.players do
        i = NextSeat(s, i)
        if not s.players[i].folded then return i end
    end
end

local function ActiveCount(s)
    local n = 0
    for _, p in ipairs(s.players) do
        if not p.folded then n = n + 1 end
    end
    return n
end

local function Pay(s, p, amount)
    p.bet = p.bet + amount
    p.net = p.net - amount
    s.pot = s.pot + amount
end

---------------------------------------------------------------------------
-- A hand
---------------------------------------------------------------------------
-- Players dealt in: everyone the host hasn't continued without.
local function SeatedCount(s)
    local n = 0
    for _, p in ipairs(s.players) do
        if not p.out then n = n + 1 end
    end
    return n
end

-- The player to the dealer's right cuts: never someone sitting out, and
-- never the host if anyone else can.
local function PickCutter(s)
    local n = #s.players
    local i, fallback = s.dealer, nil
    for _ = 1, n do
        i = ((i - 2) % n) + 1
        local p = s.players[i]
        if not p.out then
            if p.name ~= s.host then return p.name end
            fallback = fallback or p.name
        end
    end
    return fallback
end

local function NewHand(s)
    s.hand = (s.hand or 0) + 1
    -- The button moves to the next player still at the table.
    local d = s.dealer or 0
    for _ = 1, #s.players do
        d = d % #s.players + 1
        if not s.players[d].out then break end
    end
    s.dealer = d
    s._secret = ns.Fair.NewSecret()
    s.commit = ns.Fair.Hash(s._secret)
    s.secret, s.cut, s.reveal, s.winners, s.winText = nil, nil, nil, nil, nil
    s.board, s._board = {}, nil
    s.pot, s.high, s.raises, s.toAct = 0, 0, 0, nil
    s._hole = {}
    for _, p in ipairs(s.players) do
        p.bet, p.acted = 0, nil
        p.folded = p.out or nil -- sitting out: no cards this hand
    end
    s.cutter = PickCutter(s)
    s.stage = "cut"
    s.banner = "Hand " .. s.hand .. ": " .. s.cutter .. " cuts the deck."
end

local function StartStreet(s, stage)
    s.stage = stage
    s.high, s.raises, s.lastRaise = 0, 0, 0
    for _, p in ipairs(s.players) do p.bet, p.acted = 0, nil end
    for i = 1, BOARD_SHOWN[stage] do s.board[i] = s._board[i] end
    s.toAct = NextActive(s, s.dealer)
end

local function EndHand(s, winners, text)
    local share = math.floor(s.pot / #winners)
    local rest = s.pot - share * #winners
    for i, name in ipairs(winners) do
        local p = Player(s, name)
        p.net = p.net + share + (i == 1 and rest or 0)
    end
    s.winners = winners
    s.winText = text
    s.lastPot = s.pot
    s.stage = "over"
    s.toAct = nil
    s.secret = s._secret -- now everyone can check the deal
    if #winners == 1 then
        s.banner = winners[1] .. " wins " .. ns.Money(s.pot) .. (text and (" with " .. text) or "") .. "."
    else
        s.banner = table.concat(winners, " and ") .. " split " .. ns.Money(s.pot) .. (text and (" with " .. text) or "") .. "."
    end
end

local function Showdown(s)
    for i = 1, 5 do s.board[i] = s._board[i] end
    local best, winners = nil, {}
    s.reveal = {}
    -- Order from the dealer's left, so the odd gold goes there.
    local i = s.dealer
    for _ = 1, #s.players do
        i = NextSeat(s, i)
        local p = s.players[i]
        if not p.folded then
            local hole = s._hole[p.name]
            s.reveal[p.name] = hole
            local cards = { hole[1], hole[2], unpack(s.board) }
            local score = G.Best(cards)
            local cmp = best and G.Compare(score, best) or 1
            if cmp > 0 then
                best, winners = score, { p.name }
            elseif cmp == 0 then
                table.insert(winners, p.name)
            end
        end
    end
    EndHand(s, winners, G.Describe(best):lower())
end

-- After a move: hand over, next round, or next player.
local function Advance(s)
    if ActiveCount(s) == 1 then
        for _, p in ipairs(s.players) do
            if not p.folded then return EndHand(s, { p.name }) end
        end
    end
    local done = true
    for _, p in ipairs(s.players) do
        if not p.folded and (not p.acted or p.bet ~= s.high) then done = false end
    end
    if not done then
        s.toAct = NextActive(s, s.toAct)
        return
    end
    local nextStage = STREETS[s.stage]
    if nextStage == "showdown" then return Showdown(s) end
    StartStreet(s, nextStage)
    s.banner = ({ flop = "The flop.", turn = "The turn.", river = "The river." })[nextStage]
end

-- The cut is in: shuffle, deal, post the blinds.
local function Deal(s)
    local deck = ns.Fair.Deck(s._secret, s.cut)
    local n = #s.players
    for i, p in ipairs(s.players) do
        if not p.folded then ns.Session.SendPrivate(s, p.name, { deck[2 * i - 1], deck[2 * i] }) end
    end
    s._board = { deck[2 * n + 1], deck[2 * n + 2], deck[2 * n + 3], deck[2 * n + 4], deck[2 * n + 5] }
    StartStreet(s, "preflop")
    -- Heads-up the dealer posts the small blind.
    local sb = SeatedCount(s) == 2 and s.dealer or NextActive(s, s.dealer)
    local bb = NextActive(s, sb)
    Pay(s, s.players[sb], s.sb)
    Pay(s, s.players[bb], s.bet)
    s.high, s.raises, s.lastRaise = s.bet, 1, s.bet
    s.toAct = NextActive(s, bb)
    s.banner = s.players[sb].name .. " and " .. s.players[bb].name .. " post the blinds."
end

local function Settle(s)
    return ns.Stats.SettleNets(s.players)
end

---------------------------------------------------------------------------
-- Rules interface (see ns.Session)
---------------------------------------------------------------------------
function G:Setup(s, settings)
    s.bet = settings.bet
    s.sb = math.max(1, math.floor(settings.bet / 2))
    s.maxRaise = math.max(settings.maxRaise or settings.bet, settings.bet)
end

-- How much the player to act may bet or raise by, or nil.
function G:RaiseRange(s, name)
    if not self:IsTurn(s, name) or s.raises >= MAX_BETS then return nil end
    local max = s.maxRaise or s.bet
    local min = math.min(math.max(s.bet, s.lastRaise or 0), max)
    return min, max
end

function G:Begin(s)
    for _, p in ipairs(s.players) do p.net = 0 end
    s.dealer = nil
    NewHand(s)
end

-- Only the cutter rolls, and only to cut.
function G:Expect(s, name)
    if s.phase == "rolling" and s.stage == "cut" and s.cutter == name then return 1, CUT_MAX end
end

function G:Apply(s, name, roll)
    s.cut = roll
    Deal(s)
end

function G:IsTurn(s, name)
    if s.phase ~= "rolling" or not s.toAct then return false end
    local p = s.players[s.toAct]
    return p ~= nil and p.name == name
end

-- What the player to act may do: list of { action, label }.
function G:Options(s, name)
    if not self:IsTurn(s, name) then return {} end
    local p = Player(s, name)
    local out = { { "fold", "Fold" } }
    if p.bet == s.high then
        table.insert(out, { "check", "Check" })
    else
        table.insert(out, { "call", "Call " .. ns.Money(s.high - p.bet) })
    end
    if self:RaiseRange(s, name) then
        table.insert(out, { "raise", s.high == 0 and "Bet" or "Raise" })
    end
    return out
end

function G:Act(s, name, action)
    -- The host runs the table between hands.
    if action == "deal" then
        if name ~= s.host or s.stage ~= "over" then return false end
        if SeatedCount(s) < 2 then return false, "Two players are needed at the table." end
        NewHand(s)
        return true
    elseif action == "end" then
        if name ~= s.host or not (s.stage == "over" or s.stage == "cut") then return false end
        -- A hand that was never dealt costs nothing.
        s.phase = "done"
        s.stage = nil
        local transfers = Settle(s)
        local hands = s.hand - ((s.cut == nil) and 1 or 0)
        s.result = { transfers = transfers, summary = "Poker, " .. hands .. (hands == 1 and " hand" or " hands") }
        s.banner = #transfers == 0 and "The table is closed. Everyone broke even." or "The table is closed."
        return true
    end

    if not self:IsTurn(s, name) then return false, "Not your turn." end
    local p = Player(s, name)
    local amount
    action, amount = action:match("^(%a+):?(%d*)$")
    amount = tonumber(amount)
    if action == "fold" then
        p.folded = true
        s.banner = name .. " folds."
    elseif action == "check" then
        if p.bet ~= s.high then return false end
        s.banner = name .. " checks."
    elseif action == "call" then
        if p.bet >= s.high then return false end
        Pay(s, p, s.high - p.bet)
        s.banner = name .. " calls."
    elseif action == "raise" then
        local min, max = self:RaiseRange(s, name)
        amount = amount or min
        if not min or amount < min or amount > max then return false, "Raise between " .. ns.Money(min) .. " and " .. ns.Money(max) .. "." end
        local bet = s.high == 0
        s.high = s.high + amount
        s.lastRaise = amount
        s.raises = s.raises + 1
        Pay(s, p, s.high - p.bet)
        for _, q in ipairs(s.players) do q.acted = nil end
        s.banner = name .. (bet and " bets " or " raises to ") .. ns.Money(s.high) .. "."
    else
        return false
    end
    p.acted = true
    Advance(s)
    return true
end

G.dropText = "They fold this hand and sit out until they're back. Their total still counts at the end."

-- Continue without a player: fold them, sit them out from the next hands.
function G:Drop(s, name)
    local p, i = Player(s, name)
    if s.stage == "cut" and s.cutter == name then
        s.cutter = PickCutter(s)
        s.banner = name .. " is out. " .. tostring(s.cutter) .. " cuts the deck instead."
        return
    end
    if s.stage == "cut" or s.stage == "over" or p.folded then return end
    p.folded = true
    s.banner = name .. " is out and folds."
    if s.toAct == i then
        Advance(s)
    elseif ActiveCount(s) == 1 then
        for _, q in ipairs(s.players) do
            if not q.folded then return EndHand(s, { q.name }) end
        end
    end
end

-- Brought back by the host: dealt in from the next hand.
function G:Undrop(s, name)
    s.banner = name .. " is back in and will be dealt in next hand."
end

-- Back again: dealt in from the next hand.
function G:Rejoin(s, name)
    local p = Player(s, name)
    p.out = nil
    s.banner = name .. " is back and will be dealt in next hand."
end

-- Bots: a little sense, a little luck.
function G:BotAct(s, name)
    local p = Player(s, name)
    local hole = s._hole[name]
    local cards = { hole[1], hole[2] }
    for _, c in ipairs(s.board) do table.insert(cards, c) end
    local strength
    if #cards < 5 then
        local a, b = G.Rank(hole[1]), G.Rank(hole[2])
        strength = (a == b and 3) or ((a >= 12 or b >= 12) and 2) or ((a + b >= 18) and 2) or 1
    else
        local cat = G.Best(cards)[1]
        strength = (cat >= 3 and 3) or (cat == 2 and 2) or 1
    end
    local roll = math.random()
    local toCall = s.high - p.bet
    local min, max = self:RaiseRange(s, name)
    local function Raise(mult)
        return "raise:" .. math.min(max, min * mult)
    end
    if strength == 3 and min and roll < 0.7 then return Raise(math.random(1, 4)) end
    if toCall == 0 then
        if strength >= 2 and min and roll < 0.25 then return Raise(math.random(1, 2)) end
        return "check"
    end
    if strength >= 2 or roll < 0.35 then return "call" end
    return "fold"
end

function G:Status(s)
    if s.phase == "lobby" then return "Blinds " .. ns.Money(s.sb) .. " / " .. ns.Money(s.bet) .. ", max raise " .. ns.Money(s.maxRaise or s.bet) end
    if s.stage == "cut" then return s.cutter .. " cuts the deck" end
    if s.stage == "over" then return "Hand " .. s.hand .. " is over" end
    if s.toAct then return s.players[s.toAct].name .. "'s turn" end
end

function G:RangeText() return nil end
function G:RollText() return "" end

-- After a hand: does everything the host showed match the sealed secret?
-- Returns true, false (something does not match) or nil (nothing to check yet).
function G.Verify(s, myCards)
    if not (s.secret and s.cut and s.commit) then return nil end
    if ns.Fair.Hash(s.secret) ~= s.commit then return false end
    local deck = ns.Fair.Deck(s.secret, s.cut)
    local n = #s.players
    for i = 1, #s.board do
        if s.board[i] ~= deck[2 * n + i] then return false end
    end
    for i, p in ipairs(s.players) do
        local shown = s.reveal and s.reveal[p.name]
        if shown and (shown[1] ~= deck[2 * i - 1] or shown[2] ~= deck[2 * i]) then return false end
        if p.name == ns.Me() and myCards and (myCards[1] ~= deck[2 * i - 1] or myCards[2] ~= deck[2 * i]) then
            return false
        end
    end
    return true
end

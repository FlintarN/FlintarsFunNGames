-- Blackjack: one player deals (the house), up to five play against them.
--
-- Each round: players set a bet between the table's min and max, then a
-- player cuts the sealed deck with a real /roll ("Deal"). Everyone gets two
-- cards face up, the dealer one up and one face down. Players hit, stand
-- or double in turn; then the dealer shows the hidden card and draws to 17
-- (standing on soft 17). A win pays 1 to 1, a blackjack 3 to 2, a tie
-- gives the bet back. A dealer blackjack beats any other 21.
--
-- Fair deck: as in poker (Core\Fair.lua) the host seals a secret before
-- the cut, the deck comes from secret + cut, and every card dealt is
-- checked against it after the round. The dealer's play is fixed by the
-- rules, so knowing the deck wouldn't help the house.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "blackjack",
    name = "Blackjack",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconBlackjack",
    short = "Beat the dealer to 21 without going over. Blackjack pays 3 to 2.",
    rules = "One player deals. Everyone else bets, gets two cards and hits or stands to get closer to 21 "
        .. "than the dealer without going over. Blackjack pays 3 to 2. Settle up when the dealer closes the table.",
    fairness = "The deck is sealed before a player cuts it with a real /roll, and every card is checked after "
        .. "the round. The dealer's moves are fixed (draw to 17), so the dealer can't play the deck.",
    minPlayers = 2,
    maxPlayers = 6,
    practiceBots = 2,
    joinAnytime = true,
    fields = {
        { key = "minBet", label = "Min bet", money = true, default = 1000, min = 1, max = 10000000 },
        { key = "maxBet", label = "Max bet", money = true, default = 10000, min = 1, max = 100000000 },
        { key = "houseCap", label = "House bankroll (0 = no cap)", money = true, default = 0, min = 0, max = 1000000000 },
    },
}
ns.Games.blackjack = G

local HOUSE_BOT = "Gazlowe"
local CUT_MAX = 1000000

---------------------------------------------------------------------------
-- Hands (cards 1-52 as in poker: rank 2-14, 14 = ace)
---------------------------------------------------------------------------
local function Rank(c) return (c - 1) % 13 + 2 end

-- Best total of a hand, and whether an ace still counts 11 ("soft").
function G.Total(cards)
    local total, aces = 0, 0
    for _, c in ipairs(cards) do
        if c and c > 0 then
            local r = Rank(c)
            if r == 14 then
                total, aces = total + 11, aces + 1
            elseif r >= 10 then
                total = total + 10
            else
                total = total + r
            end
        end
    end
    while total > 21 and aces > 0 do
        total, aces = total - 10, aces - 1
    end
    return total, aces > 0
end

function G.IsBlackjack(cards)
    return #cards == 2 and G.Total(cards) == 21
end

local function Player(s, name)
    for i, p in ipairs(s.players) do
        if p.name == name then return p, i end
    end
end

-- Who cuts next: a real player (not the house, not a bot, still in).
local function NextCutter(s, after)
    local n = #s.players
    local _, i = Player(s, after or "")
    i = i or 0
    for _ = 1, n do
        i = i % n + 1
        local p = s.players[i]
        if not (p.house or p.bot or p.out or p.offline) then return p.name end
    end
end

local function Draw(s, hidden)
    local c = s._deck[s.next]
    s.next = s.next + 1
    table.insert(s.dealt, hidden and 0 or c)
    return c
end

---------------------------------------------------------------------------
-- A round
---------------------------------------------------------------------------
local function NewRound(s)
    s.round = (s.round or 0) + 1
    s.stage = "bets"
    s._secret = ns.Fair.NewSecret()
    s.commit = ns.Fair.Hash(s._secret)
    s.secret, s.cut, s._deck, s.next = nil, nil, nil, nil
    s.dealt, s.dealer, s.order, s.turn = {}, {}, {}, nil
    s._hole, s.holeAt = nil, nil
    for _, p in ipairs(s.players) do
        p.hand, p.wager, p.state, p.result = nil, nil, nil, nil
    end
    s.cutter = s.cutter and NextCutter(s, s.cutter) or NextCutter(s)
    s.banner = "Round " .. s.round .. ": place your bets. " .. tostring(s.cutter) .. " deals when ready."
end

local function Close(s, why)
    s.phase = "done"
    local transfers = ns.Stats.SettleNets(s.players)
    local rounds = (s.round or 1) - (s.stage == "bets" and 1 or 0)
    s.result = { transfers = transfers, summary = "Blackjack, " .. rounds .. (rounds == 1 and " round" or " rounds") }
    s.banner = why or "The table is closed."
end

-- Pay out: compare everyone with the dealer.
local function Settle(s)
    local house = Player(s, s.house)
    local dealerTotal = G.Total(s.dealer)
    local dealerBJ = G.IsBlackjack(s.dealer)
    local parts = {}
    for _, name in ipairs(s.order) do
        local p = Player(s, name)
        local total = G.Total(p.hand)
        local delta
        if p.state == "bust" then
            delta = -p.wager
        elseif G.IsBlackjack(p.hand) then
            delta = dealerBJ and 0 or math.floor(p.wager * 3 / 2)
        elseif dealerBJ or (dealerTotal <= 21 and dealerTotal > total) then
            delta = -p.wager
        elseif dealerTotal > 21 or total > dealerTotal then
            delta = p.wager
        else
            delta = 0
        end
        p.result = delta
        p.net = (p.net or 0) + delta
        house.net = (house.net or 0) - delta
        table.insert(parts, name .. (delta > 0 and (" +" .. ns.Money(delta)) or (delta < 0 and (" -" .. ns.Money(-delta)) or " push")))
    end
    s.stage = "over"
    s.turn = nil
    s.secret = s._secret -- everyone can check the deal now
    local dealerText = dealerBJ and "Dealer blackjack!" or (dealerTotal > 21 and "Dealer busts!" or ("Dealer has " .. dealerTotal .. "."))
    s.banner = dealerText .. "  " .. table.concat(parts, ", ")
    if s.houseCap and (house.net or 0) <= -s.houseCap then
        Close(s, s.banner .. " The house has paid out its bankroll, so the table closes.")
    end
end

-- The dealer turns over the hidden card and draws to 17.
local function DealerPlay(s)
    s.stage = "dealer"
    s.dealer[2] = s._hole
    s.dealt[s.holeAt] = s._hole
    local anyoneLeft = false
    for _, name in ipairs(s.order) do
        local p = Player(s, name)
        if p.state ~= "bust" and not G.IsBlackjack(p.hand) then anyoneLeft = true end
    end
    if anyoneLeft then
        while G.Total(s.dealer) < 17 do
            table.insert(s.dealer, Draw(s))
        end
    end
    Settle(s)
end

-- Next player still to act, or the dealer's turn.
local function Advance(s)
    local i = s.turn or 0
    while true do
        i = i + 1
        local name = s.order[i]
        if not name then return DealerPlay(s) end
        local p = Player(s, name)
        if p.state == "playing" then
            if p.out then
                p.state = "stand" -- skipped by the host: stands as is
            else
                s.turn = i
                return
            end
        end
    end
end

-- The cut is in: shuffle, deal two each, the dealer's second face down.
local function Deal(s)
    s._deck = ns.Fair.Deck(s._secret, s.cut)
    s.next = 1
    s.order = {}
    for _, p in ipairs(s.players) do
        local bet = s.bets[p.name]
        if bet and not p.house and not p.out then
            table.insert(s.order, p.name)
            p.hand, p.wager, p.state = {}, bet, "playing"
        end
    end
    for round = 1, 2 do
        for _, name in ipairs(s.order) do
            table.insert(Player(s, name).hand, Draw(s))
        end
        if round == 1 then
            table.insert(s.dealer, Draw(s))
        else
            s._hole = Draw(s, true)
            s.holeAt = #s.dealt
            table.insert(s.dealer, 0)
        end
    end
    for _, name in ipairs(s.order) do
        local p = Player(s, name)
        if G.IsBlackjack(p.hand) then p.state = "blackjack" end
    end
    s.stage = "play"
    s.turn = 0
    s.banner = "Cards are out."
    Advance(s)
end

---------------------------------------------------------------------------
-- Rules interface (see ns.Session)
---------------------------------------------------------------------------
function G:Setup(s, settings)
    s.minBet = settings.minBet
    s.maxBet = math.max(settings.maxBet or settings.minBet, settings.minBet)
    s.houseCap = (settings.houseCap or 0) > 0 and settings.houseCap or nil
    if s.test then
        s.house = HOUSE_BOT
        table.insert(s.players, 1, { name = HOUSE_BOT, bot = true, house = true, class = "ROGUE" })
    else
        s.house = s.host
        s.players[1].house = true
    end
end

function G:Begin(s)
    for _, p in ipairs(s.players) do p.net = 0 end
    s.bets = {}
    NewRound(s)
end

-- Only the cutter rolls, once at least one bet is down.
function G:Expect(s, name)
    if s.phase == "rolling" and s.stage == "bets" and s.cutter == name and next(s.bets) then return 1, CUT_MAX end
end

function G:Apply(s, name, roll)
    s.cut = roll
    Deal(s)
end

function G:IsTurn(s, name)
    return s.phase == "rolling" and s.stage == "play" and s.turn ~= nil and s.order[s.turn] == name
end

function G.CanDouble(s, name)
    local p = Player(s, name)
    return G:IsTurn(s, name) and p.hand and #p.hand == 2
end

function G:Act(s, name, action)
    if action == "end" then
        if name ~= s.host then return false end
        Close(s)
        return true
    elseif action == "next" then
        if name ~= s.host or s.stage ~= "over" then return false end
        NewRound(s)
        return true
    end
    local p = Player(s, name)
    if not p or p.house then return false end

    local amount = tonumber(action:match("^bet:(%d+)$") or "")
    if amount then
        if s.stage ~= "bets" or p.out then return false end
        if amount == 0 then
            s.bets[name] = nil
        elseif amount < s.minBet or amount > s.maxBet then
            return false, "Bets are " .. ns.Money(s.minBet) .. " to " .. ns.Money(s.maxBet) .. "."
        else
            s.bets[name] = amount
        end
        return true, nil, true -- soft
    end

    if not self:IsTurn(s, name) then return false, "Not your turn." end
    if action == "hit" then
        table.insert(p.hand, Draw(s))
        local total = G.Total(p.hand)
        if total > 21 then
            p.state = "bust"
            s.banner = name .. " busts with " .. total .. "."
            Advance(s)
        elseif total == 21 then
            p.state = "stand"
            s.banner = name .. " has 21."
            Advance(s)
        else
            s.banner = name .. " hits: " .. total .. "."
        end
    elseif action == "stand" then
        p.state = "stand"
        s.banner = name .. " stands on " .. G.Total(p.hand) .. "."
        Advance(s)
    elseif action == "double" then
        if #p.hand ~= 2 then return false end
        p.wager = p.wager * 2
        table.insert(p.hand, Draw(s))
        local total = G.Total(p.hand)
        p.state = total > 21 and "bust" or "stand"
        s.banner = name .. " doubles: " .. total .. (total > 21 and ", bust." or ".")
        Advance(s)
    else
        return false
    end
    return true
end

G.dropText = "They stand on their cards this round and sit out until they're back."

function G:Drop(s, name)
    if self:IsTurn(s, name) then
        Player(s, name).state = "stand"
        s.banner = name .. " is out and stands."
        Advance(s)
    end
    if s.cutter == name then s.cutter = NextCutter(s, name) end
end

function G:Rejoin(s, name)
    Player(s, name).out = nil
    if not s.cutter then s.cutter = NextCutter(s) end
    s.banner = name .. " is back at the table."
end

-- Bots: put a bet down each round, play a simple strategy.
function G:BotThink(s, name)
    if s.phase ~= "rolling" or s.stage ~= "bets" or s.bets[name] then return nil end
    return "bet:" .. math.min(s.maxBet, s.minBet * math.random(1, 3))
end

function G:BotAct(s, name)
    local p = Player(s, name)
    local total, soft = G.Total(p.hand)
    local up = Rank(s.dealer[1])
    up = up == 14 and 11 or math.min(up, 10)
    if #p.hand == 2 and (total == 10 or total == 11) and up < 10 then return "double" end
    if total >= 17 and not (soft and total == 17) then return "stand" end
    if total >= 13 and up <= 6 and not soft then return "stand" end
    return "hit"
end

function G:Status(s)
    if s.phase == "lobby" then return s.house .. " deals. Bets " .. ns.Money(s.minBet) .. " to " .. ns.Money(s.maxBet) end
    if s.stage == "bets" then return "Place your bets. " .. tostring(s.cutter) .. " deals." end
    if s.stage == "play" and s.turn then return s.order[s.turn] .. "'s turn" end
    if s.stage == "over" then return "Round " .. s.round .. " is over" end
end

function G:RangeText() return nil end
function G:RollText() return "" end

-- After a round: does every card dealt match the sealed deck?
function G.Verify(s)
    if not (s.secret and s.cut and s.commit) then return nil end
    if ns.Fair.Hash(s.secret) ~= s.commit then return false end
    local deck = ns.Fair.Deck(s.secret, s.cut)
    for i, c in ipairs(s.dealt or {}) do
        if c ~= deck[i] then return false end
    end
    return true
end

-- Roulette: a European wheel (0-36). One player is the house; everyone else
-- puts chips on the table, and one player throws the ball each round (it
-- passes round the table). The throw is a real /roll 1-37: the ball lands
-- on the roll minus one, so anyone can check it.
--
-- Bets are kept per round as a "slip" per player (spot -> chips). Like the
-- slot machine there are no stacks: running totals, settled when the house
-- closes the table. Optional caps as on the slot machine.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"

local G = {
    key = "roulette",
    name = "Roulette",
    icon = ART .. "IconRoulette",
    short = "Throw the ball into the wheel. Bet on numbers, colours and more.",
    rules = "One player is the house. Everyone else puts chips on the table, then one player throws the ball. "
        .. "Where it lands decides who wins: a single number pays 35 to 1, red or black 1 to 1. "
        .. "When the house closes the table, everyone settles up.",
    fairness = "Every throw is a real /roll 1-37 that the whole group sees: the ball lands on the roll "
        .. "minus one (0-36). Anyone can check it, and nobody can steer it.",
    minPlayers = 2,
    maxPlayers = 10,
    practiceBots = 2,
    joinAnytime = true,
    fields = {
        { key = "chip", label = "Chip value", money = true, default = 1000, min = 1, max = 10000000 },
        { key = "playerCap", label = "Max loss per player (0 = no cap)", money = true, default = 0, min = 0, max = 100000000 },
        { key = "houseCap", label = "House bankroll (0 = no cap)", money = true, default = 0, min = 0, max = 1000000000 },
    },
}
ns.Games.roulette = G

local HOUSE_BOT = "Gazlowe"
local MAX_CHIPS = 100 -- per spot
local HISTORY = 12

G.WHEEL = { 0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
    5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26 }
G.RED = {}
for _, n in ipairs({ 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }) do G.RED[n] = true end

-- Where each number sits on the wheel (1-37), for the ball.
G.POCKET = {}
for i, n in ipairs(G.WHEEL) do G.POCKET[n] = i end

function G.Color(n)
    if n == 0 then return "green" end
    return G.RED[n] and "red" or "black"
end

-- Every place a chip can go. Outside bets lose on 0.
G.OUTSIDE = {
    red = { "Red", 1, function(n) return G.RED[n] == true end },
    black = { "Black", 1, function(n) return n > 0 and not G.RED[n] end },
    odd = { "Odd", 1, function(n) return n % 2 == 1 end },
    even = { "Even", 1, function(n) return n > 0 and n % 2 == 0 end },
    low = { "1 - 18", 1, function(n) return n >= 1 and n <= 18 end },
    high = { "19 - 36", 1, function(n) return n >= 19 end },
    d1 = { "1st 12", 2, function(n) return n >= 1 and n <= 12 end },
    d2 = { "2nd 12", 2, function(n) return n >= 13 and n <= 24 end },
    d3 = { "3rd 12", 2, function(n) return n >= 25 end },
    c1 = { "Column 1", 2, function(n) return n > 0 and n % 3 == 1 end },
    c2 = { "Column 2", 2, function(n) return n > 0 and n % 3 == 2 end },
    c3 = { "Column 3", 2, function(n) return n > 0 and n % 3 == 0 end },
}

-- spot -> name, pays (to 1), wins(n); nil for no such spot.
function G.Spot(spot)
    local n = tonumber((spot or ""):match("^n(%d+)$"))
    if n and n >= 0 and n <= 36 then
        return tostring(n), 35, function(x) return x == n end
    end
    local o = G.OUTSIDE[spot]
    if o then return o[1], o[2], o[3] end
end

-- What a slip wins or loses when the ball lands on n (copper, + or -).
function G.SlipResult(slip, n, chip)
    local total = 0
    for spot, chips in pairs(slip) do
        local _, pays, wins = G.Spot(spot)
        if pays then
            total = total + (wins(n) and chips * chip * pays or -chips * chip)
        end
    end
    return total
end

function G.SlipChips(slip)
    local n = 0
    for _, chips in pairs(slip or {}) do n = n + chips end
    return n
end

-- "n17=2,red=1" <-> { n17 = 2, red = 1 }
function G.EncodeSlip(slip)
    local parts = {}
    for spot, chips in pairs(slip) do
        if chips > 0 then table.insert(parts, spot .. "=" .. chips) end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

function G.DecodeSlip(text)
    local slip = {}
    for spot, chips in (text or ""):gmatch("([%w]+)=(%d+)") do
        chips = tonumber(chips)
        if not G.Spot(spot) or chips < 1 or chips > MAX_CHIPS then return nil end
        slip[spot] = chips
    end
    return slip
end

local function Player(s, name)
    for i, p in ipairs(s.players) do
        if p.name == name then return p, i end
    end
end

-- Who throws next: the next real player (not the house, not a bot, still in).
local function NextThrower(s, after)
    local n = #s.players
    local _, i = Player(s, after or "")
    i = i or 0
    for _ = 1, n do
        i = i % n + 1
        local p = s.players[i]
        if not (p.house or p.bot or p.out or p.offline) then return p.name end
    end
end

---------------------------------------------------------------------------
-- Rules interface (see ns.Session)
---------------------------------------------------------------------------
function G:Setup(s, settings)
    s.chip = settings.chip
    s.playerCap = (settings.playerCap or 0) > 0 and settings.playerCap or nil
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
    s.round = 1
    s.bets = {}
    s.history = {}
    s.thrower = NextThrower(s)
    s.banner = "Place your bets! " .. tostring(s.thrower) .. " throws the ball."
end

-- Only the thrower rolls, and only while bets are open.
function G:Expect(s, name)
    if s.phase == "rolling" and s.thrower == name then return 1, 37 end
end

local function Close(s, why)
    s.phase = "done"
    local transfers = ns.Stats.SettleNets(s.players)
    s.result = { transfers = transfers, summary = "Roulette, " .. ((s.round or 1) - 1) .. (s.round == 2 and " spin" or " spins") }
    s.banner = why or "The table is closed."
end

-- The ball landed.
function G:Apply(s, name, roll)
    local n = roll - 1
    local house = Player(s, s.house)
    local results = {}
    local parts = {}
    for who, slip in pairs(s.bets) do
        local p = Player(s, who)
        if p then
            local delta = G.SlipResult(slip, n, s.chip)
            p.net = (p.net or 0) + delta
            house.net = (house.net or 0) - delta
            results[who] = delta
            table.insert(parts, who .. " " .. (delta >= 0 and "+" or "-") .. ns.Money(math.abs(delta)))
        end
    end
    table.sort(parts)
    s.last = { round = s.round, number = n, thrower = name, results = results }
    table.insert(s.history, 1, n)
    while #s.history > HISTORY do table.remove(s.history) end
    local color = G.Color(n)
    s.banner = n .. " " .. color:sub(1, 1):upper() .. color:sub(2) .. "!"
        .. (#parts > 0 and ("  " .. table.concat(parts, ", ")) or "  No bets on the table.")

    if s.houseCap and (house.net or 0) <= -s.houseCap then
        return Close(s, s.banner .. " The house has paid out its bankroll, so the table closes.")
    end
    -- Next round: the ball passes on, bets start fresh.
    s.round = s.round + 1
    s.bets = {}
    s.thrower = NextThrower(s, name) or name
end

function G:Act(s, name, action)
    if action == "end" then
        if name ~= s.host then return false end
        Close(s)
        return true
    end
    local text = action:match("^slip:(.*)$")
    if not text then return false end
    local p = Player(s, name)
    if not p or p.house or p.out then return false end
    local slip = G.DecodeSlip(text)
    if not slip then return false, "That bet isn't on the table." end
    local stake = G.SlipChips(slip) * s.chip
    if s.playerCap and -(p.net or 0) + stake > s.playerCap then
        return false, "That's over the table limit of " .. ns.Money(s.playerCap) .. "."
    end
    s.bets[name] = next(slip) and slip or nil
    return true, nil, true -- soft: many small changes, sent a moment later
end

G.dropText = "Their total stays and counts when the table closes."

function G:Drop(s, name)
    if s.thrower == name then
        s.thrower = NextThrower(s, name)
        s.banner = name .. " is out. " .. tostring(s.thrower) .. " throws the ball instead."
    end
end

function G:Rejoin(s, name)
    Player(s, name).out = nil
    if not s.thrower then s.thrower = NextThrower(s) end
    s.banner = name .. " is back at the table."
end

-- Bots put a few chips down once a round.
function G:BotThink(s, name)
    s._botRound = s._botRound or {}
    if s.phase ~= "rolling" or s.bets[name] or s._botRound[name] == s.round then return nil end
    s._botRound[name] = s.round
    local spots = { "red", "black", "odd", "even", "low", "high", "d1", "d2", "d3", "n" .. math.random(0, 36), "n17" }
    local slip = {}
    for _ = 1, math.random(1, 3) do
        local spot = spots[math.random(#spots)]
        slip[spot] = (slip[spot] or 0) + math.random(1, 3)
    end
    return "slip:" .. G.EncodeSlip(slip)
end

function G:Status(s)
    if s.phase == "lobby" then return s.house .. " runs the table. Chips are " .. ns.Money(s.chip) end
    if s.phase == "rolling" then
        return "Round " .. s.round .. ": place your bets. " .. tostring(s.thrower or "Nobody") .. " throws the ball."
    end
end

function G:RangeText() return nil end
function G:RollText() return "" end

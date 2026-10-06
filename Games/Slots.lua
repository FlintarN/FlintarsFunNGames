-- Slot Machine: one player is the house, everyone else pulls the lever.
--
-- Every spin is a real /roll 1-512, and the three reels are read straight
-- from the number (512 = 8 x 8 x 8 stops), so anyone can check a spin and
-- nobody can fake one. Each spin costs the bet and pays bet x the paytable.
-- Like poker there are no stacks: running totals, settled when the house
-- closes the machine. Over time the machine pays back about 96%.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"

local G = {
    key = "slots",
    name = "Slot Machine",
    icon = ART .. "IconSlots",
    short = "Pull the lever: three of a kind pays up to 75 times your bet.",
    rules = "One player is the house and opens the machine. Everyone else pulls the lever as often as they like: "
        .. "each spin costs the bet and pays what the paytable says. When the house closes the machine, "
        .. "everyone settles up with the house.",
    fairness = "Every spin is a real /roll 1-512, and the reels are read straight from the number, "
        .. "so anyone can check a spin. Over time the machine pays back about 96% of what goes in.",
    minPlayers = 2,
    maxPlayers = 10,
    practiceBots = 0,
    joinAnytime = true,
    fields = {
        { key = "bet", label = "Bet per spin", money = true, default = 1000, min = 1, max = 10000000 },
        { key = "playerCap", label = "Max loss per player (0 = no cap)", money = true, default = 0, min = 0, max = 100000000 },
        { key = "houseCap", label = "House bankroll (0 = no cap)", money = true, default = 0, min = 0, max = 1000000000 },
    },
}
ns.Games.slots = G

G.ROLL = 512
G.SYMBOLS = {
    cherry = { name = "Cherry", tex = ART .. "SlotCherry" },
    lemon = { name = "Lemon", tex = ART .. "SlotLemon" },
    bell = { name = "Bell", tex = ART .. "SlotBell" },
    bar = { name = "BAR", tex = ART .. "SlotBar" },
    gem = { name = "Gem", tex = ART .. "SlotGem" },
    seven = { name = "Seven", tex = ART .. "SlotSeven" },
}
G.SYMBOL_LIST = { "cherry", "lemon", "bell", "bar", "gem", "seven" }
-- The eight stops on every reel: cherries and lemons are common.
G.STOPS = { "cherry", "cherry", "lemon", "lemon", "bell", "bar", "gem", "seven" }

-- First match wins. "any" is any symbol.
G.PAYS = {
    { { "seven", "seven", "seven" }, 75, "Jackpot!" },
    { { "gem", "gem", "gem" }, 30 },
    { { "bar", "bar", "bar" }, 20 },
    { { "bell", "bell", "bell" }, 15 },
    { { "lemon", "lemon", "lemon" }, 10 },
    { { "cherry", "cherry", "cherry" }, 10 },
    { { "cherry", "cherry", "any" }, 4 },
    { { "cherry", "any", "any" }, 1 },
}

local BOT_SPINS = 8
local HOUSE_BOT = "Gazlowe"

-- Roll 1-512 -> three symbols.
function G.Reels(roll)
    local v = roll - 1
    return { G.STOPS[math.floor(v / 64) + 1], G.STOPS[math.floor(v / 8) % 8 + 1], G.STOPS[v % 8 + 1] }
end

-- Multiplier and the paytable line for three symbols.
function G.Payout(reels)
    for _, line in ipairs(G.PAYS) do
        local ok = true
        for i = 1, 3 do
            if line[1][i] ~= "any" and line[1][i] ~= reels[i] then ok = false end
        end
        if ok then return line[2], line end
    end
    return 0
end

local function Player(s, name)
    for _, p in ipairs(s.players) do
        if p.name == name then return p end
    end
end

function G:Setup(s, settings)
    s.bet = settings.bet
    -- Optional caps (0 = none): what one player can lose, what the house can lose.
    s.playerCap = (settings.playerCap or 0) > 0 and settings.playerCap or nil
    s.houseCap = (settings.houseCap or 0) > 0 and settings.houseCap or nil
    if s.test then
        -- Practice: a goblin runs the machine and you play.
        s.house = HOUSE_BOT
        table.insert(s.players, 1, { name = HOUSE_BOT, bot = true, house = true, class = "ROGUE" })
    else
        s.house = s.host
        s.players[1].house = true
    end
end

function G:Begin(s)
    for _, p in ipairs(s.players) do p.net, p.spins = 0, 0 end
    s.spins = 0
    s.banner = "The machine is open. Pull the lever!"
end

function G:Expect(s, name)
    if s.phase ~= "rolling" or name == s.house then return nil end
    local p = Player(s, name)
    if not p or p.out or p.offline or (p.bot and (p.spins or 0) >= BOT_SPINS) then return nil end
    if G.AtLimit(s, p) then return nil end
    return 1, G.ROLL
end

-- One more spin would take this player past the max loss.
function G.AtLimit(s, p)
    return s.playerCap ~= nil and (p.net or 0) - s.bet < -s.playerCap
end

local function Close(s, why)
    s.phase = "done"
    local transfers = ns.Stats.SettleNets(s.players)
    s.result = { transfers = transfers, summary = "Slot machine, " .. (s.spins or 0) .. ((s.spins == 1) and " spin" or " spins") }
    s.banner = why or "The machine is closed."
end

function G:Apply(s, name, roll)
    local p, house = Player(s, name), Player(s, s.house)
    local reels = G.Reels(roll)
    local mult, line = G.Payout(reels)
    local win = s.bet * mult
    p.net = (p.net or 0) + win - s.bet
    house.net = (house.net or 0) - (win - s.bet)
    p.spins = (p.spins or 0) + 1
    s.spins = (s.spins or 0) + 1
    s.lastSpin = { n = s.spins, name = name, roll = roll, reels = reels, mult = mult, win = win }
    if mult >= 10 then
        s.banner = (line[3] or "Three of a kind!") .. " " .. name .. " wins " .. ns.Money(win) .. "!"
    elseif mult > 0 then
        s.banner = name .. " wins " .. ns.Money(win) .. "."
    else
        s.banner = name .. " spins... no luck."
    end
    -- The house's bankroll is gone: pay this spin in full, then close.
    if s.houseCap and (house.net or 0) <= -s.houseCap then
        Close(s, s.banner .. " The house has paid out its bankroll, so the machine closes.")
    end
end

G.dropText = "Their total stays and counts when the machine closes."

function G:Rejoin(s, name)
    Player(s, name).out = nil
    s.banner = name .. " is back at the machine."
end

-- The house closes the machine: settle everyone with the house.
function G:Act(s, name, action)
    if action ~= "end" or name ~= s.host then return false end
    Close(s)
    return true
end

function G:Status(s)
    if s.phase == "lobby" then return s.house .. " runs the machine. Bet " .. ns.Money(s.bet) .. " per spin" end
    if s.phase == "rolling" and (s.playerCap or s.houseCap) then
        local caps = {}
        if s.playerCap then table.insert(caps, "max loss " .. ns.Money(s.playerCap)) end
        if s.houseCap then table.insert(caps, "bankroll " .. ns.Money(s.houseCap)) end
        return (s.spins or 0) .. " spins, " .. table.concat(caps, ", ")
    end
    if s.phase == "rolling" then return (s.spins or 0) .. ((s.spins == 1) and " spin" or " spins") .. " so far" end
end

function G:RangeText() return nil end
function G:RollText() return "" end

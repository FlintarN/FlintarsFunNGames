-- High-Low, the classic: everyone rolls 1 - max once. The lowest roller pays
-- the highest roller the difference. Ties for highest or lowest are settled
-- by tiebreaker rolls between the tied players (the payout still uses the
-- first rolls). If everyone rolls the same, everyone rolls again.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "highlow",
    name = "High-Low",
    icon = "Interface\\Icons\\INV_Misc_Coin_02",
    short = "The classic. Everyone rolls, lowest pays highest the difference.",
    rules = "Everyone rolls 1 - max once. The lowest roller pays the highest roller the difference "
        .. "between their rolls, times what each point is worth. Ties for highest or lowest roll again "
        .. "to break the tie.",
    minPlayers = 2,
    practiceBots = 3,
    fields = {
        { key = "max", label = "Max roll", default = 100, min = 2, max = 1000000 },
        { key = "unit", label = "Each point is worth", money = true, default = 100, min = 1, max = 10000000 },
    },
}
ns.Games.highlow = G

local function Player(s, name)
    for _, p in ipairs(s.players) do
        if p.name == name then return p end
    end
end

local function Has(list, name)
    for _, n in ipairs(list) do
        if n == name then return true end
    end
    return false
end

local function Names(list)
    return table.concat(list, ", ")
end

G.dropText = "They leave this round; it is settled between the others."

function G:Setup(s, settings)
    s.max = settings.max
    s.unit = settings.unit
end

function G:Begin(s)
    s.stage = "main"
    s.tb, s.high, s.low, s.amount = nil, nil, nil, nil
    for _, p in ipairs(s.players) do p.roll, p.tb = nil, nil end
    s.banner = "Everyone rolls 1 - " .. s.max .. "."
end

function G:Expect(s, name)
    if s.phase ~= "rolling" then return nil end
    local p = Player(s, name)
    if not p or p.out then return nil end
    if s.stage == "main" and not p.roll then return 1, s.max end
    if s.stage == "tb" and Has(s.tb.names, name) and not p.tb then return 1, s.max end
    return nil
end

local function StartTiebreak(s, side, names, again)
    s.stage = "tb"
    s.tb = { side = side, names = names }
    for _, n in ipairs(names) do Player(s, n).tb = nil end
    s.banner = (again and "Tied again" or ("Tie for " .. (side == "high" and "highest" or "lowest")))
        .. "! " .. Names(names) .. " roll again."
end

-- The names in a list that are still in (not skipped). Lists keep everyone,
-- so a player who is brought back counts again.
local function InOnly(s, list)
    local out = {}
    for _, n in ipairs(list) do
        if not Player(s, n).out then table.insert(out, n) end
    end
    return out
end

local function Resolve(s)
    local high, low = InOnly(s, s.high), InOnly(s, s.low)
    if #high > 1 then return StartTiebreak(s, "high", high) end
    if #low > 1 then return StartTiebreak(s, "low", low) end
    s.stage, s.tb = nil, nil
    s.phase = "done"
    -- A winner or loser who was skipped after rolling still counts.
    s.result = { payer = low[1] or s.low[1], payee = high[1] or s.high[1], amount = s.amount }
end

-- The names in `list` whose value is the best (highest or lowest).
local function Best(list, value, highest)
    local best
    for _, n in ipairs(list) do
        local v = value(n)
        if not best or (highest and v > best) or (not highest and v < best) then best = v end
    end
    local out = {}
    for _, n in ipairs(list) do
        if value(n) == best then table.insert(out, n) end
    end
    return out, best
end

-- Everyone still in has rolled: work out the result (or the next tiebreak).
local function Progress(s)
    if s.stage == "main" then
        local all = {}
        for _, q in ipairs(s.players) do
            if not q.out then
                if not q.roll then return end
                table.insert(all, q.name)
            end
        end
        local function main(n) return Player(s, n).roll end
        local high, hi = Best(all, main, true)
        local low, lo = Best(all, main, false)
        if hi == lo then
            for _, q in ipairs(s.players) do q.roll = nil end
            s.banner = "Everyone rolled " .. hi .. ". Everyone rolls again!"
            return
        end
        s.high, s.low, s.amount = high, low, (hi - lo) * (s.unit or 1)
        return Resolve(s)
    end

    -- Tiebreaker: only players still in count.
    local names = InOnly(s, s.tb.names)
    for _, n in ipairs(names) do
        if not Player(s, n).tb then return end
    end
    local side = s.tb.side
    local winners = Best(names, function(n) return Player(s, n).tb end, side == "high")
    if #winners > 1 then return StartTiebreak(s, side, winners, true) end
    if side == "high" then s.high = winners else s.low = winners end
    return Resolve(s)
end

function G:Apply(s, name, roll)
    local p = Player(s, name)
    if s.stage == "main" then
        p.roll = roll
        s.banner = name .. " rolled " .. roll .. "."
    else
        p.tb = roll
        s.banner = name .. " rolled " .. roll .. " in the tiebreaker."
    end
    return Progress(s)
end

-- Skipping this player would leave fewer than two.
function G:DropEnds(s, name)
    local n = 0
    for _, q in ipairs(s.players) do
        if not q.out and q.name ~= name then n = n + 1 end
    end
    return n < 2
end

-- Continue without a player: the round goes on between the others.
function G:Drop(s, name)
    local left = 0
    for _, q in ipairs(s.players) do
        if not q.out then left = left + 1 end
    end
    if left < 2 then
        s.phase = "cancelled"
        s.banner = "Not enough players left, so the game is off. No one pays."
        return
    end
    return Progress(s)
end

function G:Status(s)
    if s.phase == "lobby" then return "Max roll " .. s.max .. ", each point " .. ns.Money(s.unit or 1) end
    if s.phase == "rolling" then
        local waiting = 0
        for _, p in ipairs(s.players) do
            if self:Expect(s, p.name) then waiting = waiting + 1 end
        end
        local what = s.stage == "tb" and "Tiebreaker: " or ""
        return what .. "waiting for " .. waiting .. (waiting == 1 and " roll" or " rolls")
    end
end

function G:RangeText(s)
    if s.phase == "lobby" or s.phase == "rolling" then return "1 - " .. s.max end
end

function G:RollText(s, p)
    local t = p.roll and tostring(p.roll) or ""
    if p.tb then t = t .. " |cffaaaaaa(tie " .. p.tb .. ")|r" end
    return t
end

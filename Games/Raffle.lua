-- Raffle: the organizer opens it, players buy tickets, one ticket is drawn.
--
-- Tickets are numbered in seat order (the first player's are #1-#n, the
-- next player's follow on). The organizer closes sales and does a real
-- /roll 1-N, N = tickets sold; whoever holds that ticket wins the pot,
-- minus an optional organizer's cut. Anyone can check the numbering, so
-- nobody can steer the draw. The organizer may buy tickets too.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "raffle",
    name = "Raffle",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconRaffle",
    short = "Buy tickets; one is drawn with a real /roll. The winner takes the pot.",
    rules = "The organizer sets a ticket price. Everyone buys as many tickets as they like (up to the limit), "
        .. "then the organizer draws one ticket with a real /roll. Whoever holds it wins the pot.",
    fairness = "The draw is a real /roll 1-N (N = tickets sold) that the whole group sees, and everyone can see "
        .. "which ticket numbers are whose. Nobody can steer it, the organizer included.",
    minPlayers = 2,
    maxPlayers = 40,
    practiceBots = 3,
    joinAnytime = true,
    fields = {
        { key = "price", label = "Ticket price", money = true, default = 1000, min = 1, max = 10000000 },
        { key = "maxTickets", label = "Max tickets per player", default = 10, min = 1, max = 1000 },
        { key = "cut", label = "Organizer's cut in % (0 = none)", default = 0, min = 0, max = 50 },
    },
}
ns.Games.raffle = G

local function Player(s, name)
    for _, p in ipairs(s.players) do
        if p.name == name then return p end
    end
end

-- Who holds which numbers: { { name, from, to, count } } in seat order.
function G.Ranges(s)
    local list, n = {}, 0
    for _, p in ipairs(s.players) do
        local count = s.tickets and s.tickets[p.name] or 0
        if count > 0 then
            table.insert(list, { name = p.name, from = n + 1, to = n + count, count = count })
            n = n + count
        end
    end
    return list, n
end

function G.Owner(s, ticket)
    for _, r in ipairs(G.Ranges(s)) do
        if ticket >= r.from and ticket <= r.to then return r.name end
    end
end

function G.Pot(s)
    local _, n = G.Ranges(s)
    return n * s.price, n
end

-- Two different players need tickets for a draw to mean anything.
local function Buyers(s)
    local n = 0
    for _, count in pairs(s.tickets or {}) do
        if count > 0 then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Rules interface (see ns.Session)
---------------------------------------------------------------------------
function G:Setup(s, settings)
    s.price = settings.price
    s.maxTickets = settings.maxTickets
    s.cut = settings.cut or 0
end

function G:Begin(s)
    for _, p in ipairs(s.players) do p.net = 0 end
    s.tickets = {}
    s.stage = "selling"
    s.banner = "Tickets are on sale! " .. ns.Money(s.price) .. " each."
end

function G.CanDraw(s)
    return s.phase == "rolling" and (s.stage == "selling" or s.stage == "closed") and Buyers(s) >= 2
end

-- The organizer draws: /roll 1 - tickets sold, once sales are closed.
function G:Expect(s, name)
    if s.phase == "rolling" and s.stage == "closed" and name == s.host then
        local _, n = G.Ranges(s)
        return 1, n
    end
end

function G:Apply(s, name, roll)
    local pot, n = G.Pot(s)
    local winner = G.Owner(s, roll)
    local cut = math.floor(pot * (s.cut or 0) / 100)
    for _, r in ipairs(G.Ranges(s)) do
        local p = Player(s, r.name)
        p.net = (p.net or 0) - r.count * s.price
    end
    local w = Player(s, winner)
    w.net = w.net + pot - cut
    local host = Player(s, s.host)
    host.net = (host.net or 0) + cut
    s.draw = { ticket = roll, winner = winner, pot = pot, cut = cut, tickets = n }
    s.phase = "done"
    s.stage = "drawn"
    s.result = { transfers = ns.Stats.SettleNets(s.players), summary = "Raffle, " .. n .. " tickets" }
    s.banner = "Ticket #" .. roll .. "! " .. winner .. " wins " .. ns.Money(pot - cut) .. "."
        .. (cut > 0 and (" " .. s.host .. " keeps " .. ns.Money(cut) .. ".") or "")
end

function G:Act(s, name, action)
    if s.phase ~= "rolling" then return false end
    -- The organizer closes sales (the draw follows), or opens them again.
    if action == "close" or action == "reopen" then
        if name ~= s.host then return false end
        if action == "close" then
            if not G.CanDraw(s) then return false, "At least two players need tickets." end
            s.stage = "closed"
            s.banner = "Sales are closed. " .. s.host .. " draws the winning ticket..."
        else
            s.stage = "selling"
            s.banner = "Tickets are on sale again."
        end
        return true
    end
    local n = tonumber(action:match("^buy:(%d+)$") or "")
    if not n or s.stage ~= "selling" then return false end
    local p = Player(s, name)
    if not p or p.out then return false end
    if n > s.maxTickets then return false, "The limit is " .. s.maxTickets .. " tickets each." end
    s.tickets[name] = n > 0 and n or nil
    return true, nil, true -- soft
end

G.dropText = "Their tickets stay in the draw."

function G:Rejoin(s, name)
    Player(s, name).out = nil
    s.banner = name .. " is back."
end

-- Bots buy a handful of tickets once.
function G:BotThink(s, name)
    if s.phase ~= "rolling" or s.stage ~= "selling" or s.tickets[name] then return nil end
    return "buy:" .. math.random(1, math.min(5, s.maxTickets))
end

function G:Status(s)
    if s.phase == "lobby" then return "Tickets " .. ns.Money(s.price) .. " each" end
    local pot, n = G.Pot(s)
    if s.phase == "rolling" then return n .. (n == 1 and " ticket" or " tickets") .. " sold, pot " .. ns.Money(pot) end
end

function G:RangeText() return nil end
function G:RollText() return "" end

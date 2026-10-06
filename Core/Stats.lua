-- Stats: every finished game you played in, kept across sessions.
-- Practice games and cancelled games are never recorded.
local ADDON, ns = ...

local Stats = {}
ns.Stats = Stats

local KEEP = 300

function Stats:Record(s)
    if s.test or not s.result then return end
    local me = ns.Me()
    if not ns.Session.Find(s, me) then return end
    -- A rematch in the same lobby is its own game (recordId).
    local id = s.recordId or s.id
    for _, h in ipairs(ns.db.history) do
        if h.id == id then return end
    end
    local names = {}
    for _, p in ipairs(s.players) do table.insert(names, p.name) end
    -- Dice games have one payer; a poker table settles with several payments.
    local transfers = s.result.transfers
    if not transfers and not s.result.payer then
        transfers = {} -- an Arcade game: no money, just who won
    elseif not transfers then
        transfers = { { payer = s.result.payer, payee = s.result.payee, amount = s.result.amount } }
    end
    local nets = {}
    for _, t in ipairs(transfers) do
        nets[t.payer] = (nets[t.payer] or 0) - t.amount
        nets[t.payee] = (nets[t.payee] or 0) + t.amount
    end
    table.insert(ns.db.history, 1, {
        id = id,
        kind = s.kind,
        t = ns.Now(),
        me = me,
        host = s.host,
        players = names,
        transfers = transfers,
        net = nets[me] or 0,
        summary = s.result.summary,
        won = s.result.winner ~= nil and s.result.winner == me or nil,
        lost = s.result.winner ~= nil and s.result.winner ~= me or nil,
    })
    while #ns.db.history > KEEP do table.remove(ns.db.history) end
    ns.Tab.AddGame(s.kind, transfers, me)
    ns.Changed()
end

-- Payments that settle a table of running totals ({ name, net }): the
-- biggest loser pays the biggest winner first.
function Stats.SettleNets(players)
    local losers, winners = {}, {}
    for _, p in ipairs(players) do
        if (p.net or 0) < 0 then table.insert(losers, { name = p.name, left = -p.net }) end
        if (p.net or 0) > 0 then table.insert(winners, { name = p.name, left = p.net }) end
    end
    table.sort(losers, function(a, b) return a.left > b.left end)
    table.sort(winners, function(a, b) return a.left > b.left end)
    local transfers = {}
    local w = 1
    for _, l in ipairs(losers) do
        while l.left > 0 and winners[w] do
            local amount = math.min(l.left, winners[w].left)
            table.insert(transfers, { payer = l.name, payee = winners[w].name, amount = amount })
            l.left = l.left - amount
            winners[w].left = winners[w].left - amount
            if winners[w].left == 0 then w = w + 1 end
        end
    end
    return transfers
end

-- What this game meant for you: +amount, -amount or 0.
function Stats.Net(h)
    return h.net or 0
end

-- One line for the Recent games list.
function Stats.Describe(h)
    if h.summary then return h.summary end
    local t = h.transfers and h.transfers[1]
    if not t then return "No one paid" end
    return t.payer .. " paid " .. t.payee .. " " .. ns.Money(t.amount)
end

-- Totals for one game type, or all of them when kind is nil.
function Stats:Summary(kind)
    local sum = { played = 0, won = 0, lost = 0, net = 0, best = 0, worst = 0 }
    for _, h in ipairs(ns.db.history) do
        if not kind or h.kind == kind then
            local net = Stats.Net(h)
            sum.played = sum.played + 1
            if net > 0 or h.won then sum.won = sum.won + 1 end
            if net < 0 or h.lost then sum.lost = sum.lost + 1 end
            sum.net = sum.net + net
            sum.best = math.max(sum.best, net)
            sum.worst = math.min(sum.worst, net)
        end
    end
    return sum
end

-- Everyone you have played with: games together and gold between you.
function Stats:Ledger()
    local by = {}
    for _, h in ipairs(ns.db.history) do
        for _, name in ipairs(h.players) do
            if name ~= h.me then
                local e = by[name] or { name = name, games = 0, net = 0 }
                by[name] = e
                e.games = e.games + 1
            end
        end
        for _, t in ipairs(h.transfers or {}) do
            if t.payee == h.me and by[t.payer] then by[t.payer].net = by[t.payer].net + t.amount end
            if t.payer == h.me and by[t.payee] then by[t.payee].net = by[t.payee].net - t.amount end
        end
    end
    local list = {}
    for _, e in pairs(by) do table.insert(list, e) end
    table.sort(list, function(a, b)
        if a.games ~= b.games then return a.games > b.games end
        return a.name < b.name
    end)
    return list
end

-- Clears the history only; the Settle up tab (who still owes whom) stays.
function Stats:Reset()
    wipe(ns.db.history)
    ns.Changed()
end

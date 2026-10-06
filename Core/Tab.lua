-- Tab: who owes whom, across games, until it is paid.
--
-- Every finished game you played in adds to a running balance per player
-- (positive = they owe you). Nothing has to be paid right away.
--
-- Paying is tracked, never done: when a trade with someone on your tab
-- completes, the addon reads how much gold went each way and counts it as
-- a payment, up to what is owed (so buying an item from them doesn't wipe
-- the debt). Every change is logged and can be undone.
local ADDON, ns = ...

local T = {}
ns.Tab = T

local LOG_KEEP = 100

local function DB()
    ns.db.tab = ns.db.tab or { balances = {}, log = {} }
    return ns.db.tab
end

function T.Balance(name)
    return DB().balances[name] or 0
end

-- Change what `name` owes you by `delta` and write it down.
function T.Apply(name, delta, why, text)
    if delta == 0 then return end
    local db = DB()
    local b = (db.balances[name] or 0) + delta
    db.balances[name] = b ~= 0 and b or nil
    table.insert(db.log, 1, { t = ns.Now(), name = name, delta = delta, why = why, text = text })
    while #db.log > LOG_KEEP do table.remove(db.log) end
    ns.Changed()
end

-- A finished game: add the payments that involve you.
function T.AddGame(kind, transfers, me)
    local G = ns.Games[kind]
    local label = G and G.name or kind
    for _, t in ipairs(transfers) do
        if t.payee == me then
            T.Apply(t.payer, t.amount, "game", label .. ": " .. t.payer .. " owes you " .. ns.Money(t.amount))
        elseif t.payer == me then
            T.Apply(t.payee, -t.amount, "game", label .. ": you owe " .. t.payee .. " " .. ns.Money(t.amount))
        end
    end
end

-- Everyone with an open balance, biggest first.
function T.List()
    local list = {}
    for name, b in pairs(DB().balances) do
        table.insert(list, { name = name, balance = b })
    end
    table.sort(list, function(a, b)
        if math.abs(a.balance) ~= math.abs(b.balance) then return math.abs(a.balance) > math.abs(b.balance) end
        return a.name < b.name
    end)
    return list
end

-- Totals: owed to you, you owe.
function T.Totals()
    local owed, owe = 0, 0
    for _, b in pairs(DB().balances) do
        if b > 0 then owed = owed + b else owe = owe - b end
    end
    return owed, owe
end

function T.Settle(name)
    local b = T.Balance(name)
    if b == 0 then return end
    T.Apply(name, -b, "manual", "Marked as paid: " .. name .. (b > 0 and " paid you " or ", you paid ") .. ns.Money(math.abs(b)))
end

function T.Log()
    return DB().log
end

-- Take back one logged change (a trade that wasn't a payment, say).
function T.Undo(entry)
    if entry.undone or entry.why == "undo" then return end
    entry.undone = true
    T.Apply(entry.name, -entry.delta, "undo", "Undone: " .. (entry.text or ""))
end

function T.Remind(name)
    local b = T.Balance(name)
    if b <= 0 then return end
    local text = "Flintar's Fun 'n' Games: from our games you owe me " .. ns.MoneyPlain(b) .. "."
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if send then send(text, "WHISPER", nil, name) end
end

function T.Reset()
    local db = DB()
    wipe(db.balances)
    wipe(db.log)
    ns.Changed()
end

---------------------------------------------------------------------------
-- Watching trades (read-only)
---------------------------------------------------------------------------
local trade -- { name, mine, theirs } while a trade window is open

local function Snapshot()
    if not trade then return end
    if GetPlayerTradeMoney then trade.mine = GetPlayerTradeMoney() or 0 end
    if GetTargetTradeMoney then trade.theirs = GetTargetTradeMoney() or 0 end
end

ns.On("TRADE_SHOW", function()
    local name = UnitName("NPC") -- the trade partner
    if not name and TradeFrameRecipientNameText then name = TradeFrameRecipientNameText:GetText() end
    trade = name and { name = ns.Short(name), mine = 0, theirs = 0 } or nil
end)
ns.On("TRADE_MONEY_CHANGED", Snapshot)
ns.On("TRADE_ACCEPT_UPDATE", Snapshot)
ns.On("PLAYER_TRADE_MONEY", Snapshot)

-- A completed trade: count gold that settles an open balance.
function T.TradeDone(name, received, sent)
    local net = (received or 0) - (sent or 0)
    local b = T.Balance(name)
    if net > 0 and b > 0 then
        local paid = math.min(net, b)
        T.Apply(name, -paid, "trade", "Trade: " .. name .. " paid you " .. ns.Money(paid))
        ns.Print(name .. " paid you " .. ns.Money(paid) .. " in a trade. "
            .. (T.Balance(name) > 0 and ("Still owes " .. ns.Money(T.Balance(name)) .. ".") or "All square now."))
    elseif net < 0 and b < 0 then
        local paid = math.min(-net, -b)
        T.Apply(name, paid, "trade", "Trade: you paid " .. name .. " " .. ns.Money(paid))
        ns.Print("You paid " .. name .. " " .. ns.Money(paid) .. " in a trade. "
            .. (T.Balance(name) < 0 and ("You still owe " .. ns.Money(-T.Balance(name)) .. ".") or "All square now."))
    end
end

ns.On("UI_INFO_MESSAGE", function(a, b)
    local done = ERR_TRADE_COMPLETE or "Trade complete."
    if not trade or (a ~= done and b ~= done) then return end
    local t = trade
    trade = nil
    T.TradeDone(t.name, t.theirs, t.mine)
end)

ns.On("TRADE_CLOSED", function()
    -- The completion message comes just before or after the close; give it a moment.
    local t = trade
    ns.After(1, function()
        if trade == t then trade = nil end
    end)
end)

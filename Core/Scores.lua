-- Scores: high scores for the solo Arcade games, and shared leaderboards.
--
-- Your best per game is kept. A new best is announced to your guild and,
-- when realm lobbies are on, to the realm channel (the same channels the
-- lobbies use). Opening a leaderboard asks the others for their bests;
-- they answer after a short random wait so a busy channel isn't flooded.
--
-- Messages: SC = "my best" (scope, game, score, class), SQ = "send me
-- your best for this game" (scope, game).
local ADDON, ns = ...

local Sc = {}
ns.Scores = Sc

local KEEP_DAYS = 30
local SCOPES = { "guild", "realm" }
-- Boards that aren't a game of their own (letters and digits only).
Sc.EXTRA = { hearthstonepvp = true } -- Hearthstone: PvP wins

local function DB()
    ns.db.scores = ns.db.scores or {}
    ns.db.boards = ns.db.boards or {}
    return ns.db.scores, ns.db.boards
end

local function Better(game, a, b)
    if b == nil then return true end
    if ns.Games[game] and ns.Games[game].lowerIsBetter then return a < b end
    return a > b
end

function Sc.Best(game)
    local scores = DB()
    local mine = scores[game]
    return mine and mine.best
end

local function Reachable(scope)
    if scope == "realm" and ns.db.realmLobbies == false then return false end
    return ns.Net.Route(scope) ~= nil
end

local function Announce(game, scope)
    local best = Sc.Best(game)
    if not best or not Reachable(scope) then return end
    local class = ns.Session.ClassOf(ns.Me()) or ""
    ns.Net.Send("SC", scope .. "\t" .. game .. "\t" .. best .. "\t" .. class, scope)
end

-- A finished run. Returns true when it's a new best.
function Sc.Submit(game, score)
    local scores = DB()
    scores[game] = scores[game] or {}
    local mine = scores[game]
    mine.runs = (mine.runs or 0) + 1
    if not Better(game, score, mine.best) then return false end
    mine.best, mine.at = score, ns.Now()
    for _, scope in ipairs(SCOPES) do Announce(game, scope) end
    ns.Changed()
    return true
end

-- Top entries for a game in a scope ("me", "guild", "realm"), you included.
function Sc.Board(game, scope, limit)
    local _, boards = DB()
    local list = {}
    local me = ns.Me()
    local best = Sc.Best(game)
    if best then table.insert(list, { name = me, score = best, class = ns.Session.ClassOf(me), me = true }) end
    if scope ~= "me" then
        local now = ns.Now()
        for name, e in pairs((boards[game] or {})[scope] or {}) do
            if name ~= me and now - (e.t or 0) < KEEP_DAYS * 86400 then
                table.insert(list, { name = name, score = e.s, class = e.c })
            end
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return Better(game, a.score, b.score) end
        return a.name < b.name
    end)
    while #list > (limit or 10) do table.remove(list) end
    return list
end

-- Ask the others for their bests (at most once a minute per game and scope).
local asked = {}
function Sc.Ask(game)
    for _, scope in ipairs(SCOPES) do
        local key = game .. ":" .. scope
        if Reachable(scope) and ns.Now() - (asked[key] or 0) > 60 then
            asked[key] = ns.Now()
            ns.Net.Send("SQ", scope .. "\t" .. game, scope)
        end
    end
end

ns.Net.On("SC", function(sender, data)
    local scope, game, score, class = data:match("^(%a+)\t([%w]+)\t(%-?[%d%.]+)\t(%u*)$")
    score = tonumber(score)
    if not (scope and score and (ns.Games[game] or Sc.EXTRA[game])) or (scope ~= "guild" and scope ~= "realm") then return end
    local _, boards = DB()
    boards[game] = boards[game] or {}
    boards[game][scope] = boards[game][scope] or {}
    local cur = boards[game][scope][sender]
    if cur and not Better(game, score, cur.s) and cur.s ~= score then return end
    boards[game][scope][sender] = { s = score, c = class ~= "" and class or nil, t = ns.Now() }
    ns.Changed()
end)

local answered = {}
ns.Net.On("SQ", function(_, data)
    local scope, game = data:match("^(%a+)\t([%w]+)$")
    if not (scope and game and Sc.Best(game)) then return end
    local key = game .. ":" .. scope
    if ns.Now() - (answered[key] or 0) < 60 then return end
    answered[key] = ns.Now()
    ns.After(0.5 + math.random() * 3.5, function() Announce(game, scope) end)
end)

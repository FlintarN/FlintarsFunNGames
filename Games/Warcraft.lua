-- Warcraft 4: a real-time strategy game, against the computer (solo) or
-- other players, on the engine in Games\Warcraft\ (data, maps, engine, AI)
-- and the page in UI\WarcraftPage.lua.
--
-- Games with other players start in a lobby like the other Arcade games
-- (Session), with Warcraft's own lobby screen (UI\WarcraftLobby.lua): the
-- host picks the map and who sits where (players, computers, closed); each
-- player picks their race and team. s.lobby holds it, the host shares it.
-- On Start the host rolls random races and deals a seed (s.game); then every
-- client runs the same deterministic engine in lockstep (Core\Lockstep.lua):
-- only commands travel. The session only hears about the end (which team
-- won, or that the games drifted apart).
--
-- The realm queue (Find an Opponent) still pairs two players who pick a race
-- each first ("races" stage).
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "warcraft",
    arcade = true,
    section = "blizzard", -- the home page's Blizzard Games section
    solo = true,
    name = "Warcraft 4",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconWarcraft",
    short = "Real-time strategy: gather gold and lumber, build a base, crush the enemy.",
    how = "Left-click or drag to select, right-click to move, attack or gather. A attacks, S stops.",
    rules = "Gather gold and lumber, build farms and barracks, train an army and destroy every enemy building. "
        .. "Play the computer, or friends from your group, guild or realm: up to eight players, in teams.",
    scoreLabel = "Wins",
    window = { 760, 560 },
    fullscreen = true, -- offers a Fullscreen button
    fields = {},
    -- Lobbies: the host alone can start against computers; seats come from
    -- the map (see MaxPlayers).
    minPlayers = 1,
    maxPlayers = 8,
    practiceBots = 0,
    lobbyActs = true,
    afterGame = { rematch = true },
    dropText = "The game waits for them, or you can close the lobby.",
}
ns.Games.warcraft = G

local RACES = { human = true, orc = true, random = true }

-- A new lobby: the host in seat 1, an open seat for each other start.
local function Fit(lobby)
    local m = ns.WC.Maps[lobby.map] or ns.WC.Maps.riverford
    for i = 1, m.players do
        if not lobby.slots[i] then
            lobby.slots[i] = { kind = i == 1 and "host" or "open", race = i % 2 == 1 and "human" or "orc", team = i }
        end
        local s = lobby.slots[i]
        if (s.team or 0) > m.players or (s.team or 0) < 1 then s.team = i end
    end
    for i = #lobby.slots, m.players + 1, -1 do table.remove(lobby.slots, i) end
end

function G:Setup(s)
    s.lobby = { map = "riverford", mode = "melee", slots = {} }
    Fit(s.lobby)
end

-- The lobby as the lobby screen sees it: the host's seat and the open seats
-- filled by the players who joined (in the order they came), from me's
-- point of view (kind "me" for my seat, "player" for the others).
function G.LobbyView(s, me)
    local lobby = s.lobby or { map = "riverford", slots = {} }
    local others = {}
    for _, p in ipairs(s.players) do
        if p.name ~= s.host then table.insert(others, p.name) end
    end
    local out = { map = lobby.map, mode = lobby.mode, creeps = lobby.creeps, slots = {}, online = true }
    local k = 0
    for i, slot in ipairs(lobby.slots) do
        local v = { race = slot.race, team = slot.team, diff = slot.diff, kind = slot.kind }
        if slot.kind == "host" then
            v.name = s.host
        elseif slot.kind == "open" then
            k = k + 1
            v.name = others[k]
        end
        if v.name then
            v.kind = v.name == me and "me" or "player"
            v.ready = v.name == s.host or (lobby.ready and lobby.ready[v.name]) or false
        end
        out.slots[i] = v
    end
    return out
end

-- Seats that can take a player (the host's and the open ones).
function G.MaxPlayers(s)
    local n = 0
    for _, slot in ipairs(s.lobby and s.lobby.slots or {}) do
        if slot.kind == "host" or slot.kind == "open" then n = n + 1 end
    end
    return math.max(1, n)
end

function G:CanStart(s)
    if #s.players > G.MaxPlayers(s) then return false, "More players than seats." end
    for _, p in ipairs(s.players) do
        if p.name ~= s.host and not (s.lobby.ready and s.lobby.ready[p.name]) then
            return false, "Waiting for " .. p.name .. " to be ready."
        end
    end
    return ns.WarcraftLobby.CanStart(G.LobbyView(s))
end

function G.Seat(s, name)
    if s.game and s.game.names then
        for seat, n in pairs(s.game.names) do
            if n == name then return seat end
        end
        return nil
    end
    for i, p in ipairs(s.players) do
        if p.name == name then return i end
    end
end

function G:Begin(s)
    s.score = s.score or {}
    for _, p in ipairs(s.players) do s.score[p.name] = s.score[p.name] or 0 end
    s.result = nil
    s.games = (s.games or 0) + 1
    s.recordId = s.id .. ":" .. s.games
    if s.queued then
        -- The realm queue: two players pick a race each first.
        s.stage = "races"
        s.races = {}
        s.game = nil
        s.banner = "Choose your race."
        return
    end
    local view = G.LobbyView(s)
    local o = ns.WarcraftLobby.GameOptions(view, math.random)
    s.game = { map = o.map, mode = o.mode, creeps = o.creeps, factions = o.factions, teams = o.teams, starts = o.starts, difficulties = o.difficulties,
        cpus = o.cpus, names = o.names }
    s.seed = math.random(1, 2000000000)
    s.stage = "play"
    s.banner = "The battle begins."
end

function G:Expect() return nil end

function G:IsTurn(s, name)
    return s.phase == "rolling" and s.stage == "races" and s.races ~= nil and not s.races[name]
end

-- The players (names) on a seat's team.
local function TeamOf(s, seat)
    local g = s.game
    if not g then return {} end
    local out = {}
    for p, name in pairs(g.names or {}) do
        if (g.teams[p] or p) == (g.teams[seat] or seat) then table.insert(out, name) end
    end
    table.sort(out)
    return out
end

local function Finish(s, winners, summary)
    s.phase, s.stage = "done", "over"
    if winners and #winners > 0 then
        for _, name in ipairs(winners) do s.score[name] = (s.score[name] or 0) + 1 end
        local who = table.concat(winners, " and ")
        s.result = { winner = winners[1], winners = winners, summary = summary or ("Warcraft 4, " .. who .. " won") }
        s.banner = who .. (#winners > 1 and " win!" or " wins!")
    else
        s.result = { summary = summary or "Warcraft 4, no winner" }
        s.banner = summary or "No winner."
    end
end

-- Did this player win the finished game?
function G.Won(s, name)
    for _, w in ipairs(s.result and s.result.winners or {}) do
        if w == name then return true end
    end
    return s.result ~= nil and s.result.winner == name
end

-- The lobby: the host picks the map and who sits where; a player sets their
-- own race and team (the host also sets the computers').
local function LobbyAct(s, name, verb, arg)
    local lobby = s.lobby
    local host = name == s.host
    if verb == "ready" then
        -- A player (not the host) says they're ready, or not.
        if host or not G.Seat(s, name) then return false end
        lobby.ready = lobby.ready or {}
        lobby.ready[name] = arg ~= "off" or nil
        return true
    end
    if verb == "creeps" then
        if not host then return false end
        lobby.creeps = arg ~= "off"
        return true
    end
    if verb == "mode" then
        if not host or not ns.WC.Modes[arg] or lobby.mode == arg then return false end
        local maps = ns.WC.MapsFor(#s.players, arg)
        if #maps == 0 then return false end
        lobby.mode, lobby.map = arg, maps[1]
        Fit(lobby)
        return true
    end
    if verb == "map" then
        local m = ns.WC.Maps[arg]
        if not host or not m or m.players < #s.players or (m.mode or "melee") ~= (lobby.mode or "melee") then return false end
        lobby.map = arg
        Fit(lobby)
        lobby.ready = nil -- a new map: everyone checks again
        return true
    end
    local i, value = arg:match("^(%d+):?(.*)$")
    i = tonumber(i)
    local slot = i and lobby.slots[i]
    if not slot then return false end
    local view = G.LobbyView(s, name).slots[i]
    local mine = view.kind == "me"
    if verb == "who" then
        -- open > computer (Normal, Hard, Easy) > closed > open; not a seat someone sits in.
        if not host or view.kind == "me" or view.kind == "player" then return false end
        if slot.kind == "open" then slot.kind, slot.diff = "cpu", "normal"
        elseif slot.kind == "cpu" then
            if slot.diff == "normal" then slot.diff = "hard"
            elseif slot.diff == "hard" then slot.diff = "easy"
            else slot.kind = "closed" end
        elseif slot.kind == "closed" then slot.kind = "open" end
        return true
    elseif verb == "race" then
        if not RACES[value] or not (mine or (host and slot.kind == "cpu")) then return false end
        slot.race = value
        return true
    elseif verb == "team" then
        local n = tonumber(value)
        local m = ns.WC.Maps[lobby.map]
        if not n or n < 1 or n > m.players or not (mine or (host and slot.kind == "cpu")) then return false end
        slot.team = n
        return true
    end
    return false
end

function G:Act(s, name, action)
    local verb, arg = action:match("^(%a+):?(.*)$")
    if s.phase == "lobby" then return LobbyAct(s, name, verb, arg or "") end
    if verb == "rematch" then
        if name ~= s.host or s.phase ~= "done" then return false end
        s.phase = "rolling"
        self:Begin(s)
        return true
    end
    local seat = G.Seat(s, name)
    if not seat or s.phase ~= "rolling" then return false end
    if verb == "race" then
        if s.stage ~= "races" or s.races[name] or not ns.WC.Factions[arg] then return false end
        s.races[name] = arg
        s.banner = name .. " plays " .. ns.WC.Factions[arg].name .. "."
        for _, p in ipairs(s.players) do
            if not s.races[p.name] then return true end
        end
        local names, factions = {}, {}
        for i, p in ipairs(s.players) do names[i], factions[i] = p.name, s.races[p.name] end
        s.game = { map = "riverford", factions = factions, teams = { 1, 2 }, starts = { 1, 2 }, difficulties = {},
            cpus = {}, names = names }
        s.stage = "play"
        s.seed = math.random(1, 2000000000)
        s.banner = "The battle begins."
        return true
    elseif verb == "won" then
        -- Any player's game says which seat's team won (all see the same thing).
        local w = tonumber(arg)
        if s.stage ~= "play" or not (s.game and s.game.factions[w or 0]) then return false end
        local winners = TeamOf(s, w)
        Finish(s, winners, #winners == 0 and "Warcraft 4, the computer won" or nil)
        return true
    elseif verb == "surrender" then
        -- (In a game the surrender is a command in the game itself; this is
        -- for a game that can't go on: the other team wins if there's one.)
        if s.stage ~= "play" then return false end
        local teams, other = {}, nil
        for p, n in pairs(s.game.names) do
            local t = s.game.teams[p] or p
            if n ~= name and t ~= (s.game.teams[seat] or seat) then teams[t] = true other = p end
        end
        local count = 0
        for _ in pairs(teams) do count = count + 1 end
        Finish(s, count == 1 and TeamOf(s, other) or nil, "Warcraft 4, " .. name .. " surrendered")
        return true
    elseif verb == "desync" then
        if s.stage ~= "play" then return false end
        Finish(s, nil, "The games drifted apart (out of sync). No winner.")
        return true
    end
    return false
end

-- The host skipped a player who went offline (group lobbies). Two players:
-- the other wins. More: the computer takes their seat over (the host's game
-- page hands it on: UI\WarcraftPage.lua, P:TakeOver).
function G:Drop(s, name)
    if s.stage ~= "play" then return end
    local humans = 0
    for _ in pairs(s.game and s.game.names or {}) do humans = humans + 1 end
    if humans == 2 then
        for p, n in pairs(s.game.names) do
            if n ~= name then return Finish(s, TeamOf(s, p), "Warcraft 4, " .. name .. " left") end
        end
    end
    s.game.leaving = s.game.leaving or {}
    s.game.leaving[name] = true
end

-- Practice bot (the queue's races stage only).
function G:BotAct(s, name)
    if s.stage == "races" then return "race:" .. (math.random() < 0.5 and "human" or "orc") end
end

function G:Status(s)
    if s.phase == "lobby" then return #s.players .. "/" .. G.MaxPlayers(s) .. " players" end
    if s.stage == "races" then return "Choosing races" end
    if s.stage == "play" then return "Battle" end
end

function G:RangeText() return nil end
function G:RollText() return "" end

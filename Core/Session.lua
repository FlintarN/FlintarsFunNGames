-- Session: one running game per game type, shared with the group.
--
-- The host's addon runs the game. It only counts a roll when its own client
-- sees the game's roll message, with the range the game asked for. After
-- every change it sends the whole game to the group; the other addons show
-- that copy and check each roll against the roll messages they saw.
--
-- Messages: S = the game (host -> group), J / L = join / leave (player ->
-- host), A = a move like fold or call (player -> host), H = your private
-- cards (host -> one player, whispered), Q = "send me the games you are
-- running" (after a /reload).
--
-- Games live here, not in the window, so changing tabs or closing the
-- window never loses a game.
local ADDON, ns = ...

local S = {}
ns.Session = S

S.sessions = {}
S.closed = {} -- game ids you closed from the tab: never picked up again
local BOTS = { "Ragnar", "Jaina", "Thrall", "Sylvanas", "Arthas", "Anduin", "Varian", "Illidan" }
-- Bots' classes, for their portraits (class icons).
local BOT_CLASS = { Ragnar = "WARRIOR", Jaina = "MAGE", Thrall = "SHAMAN", Sylvanas = "HUNTER", Arthas = "PALADIN",
    Anduin = "PRIEST", Varian = "WARRIOR", Illidan = "ROGUE", Gazlowe = "ROGUE" }
local LOG_SIZE = 15

function S.Get(kind)
    return S.sessions[kind]
end

function S.IsActive(s)
    return s ~= nil and (s.phase == "lobby" or s.phase == "rolling")
end

function S.IsHost(s)
    return s ~= nil and s.host == ns.Me()
end

function S.Find(s, name)
    if not s then return nil end
    for i, p in ipairs(s.players) do
        if p.name == name then return i, p end
    end
end

function S.Game(s)
    return ns.Games[s.kind]
end

-- The unit token ("player", "party2", "raid14") for someone in your group.
function S.UnitFor(name)
    if name == ns.Me() then return "player" end
    local raid = IsInRaid and IsInRaid()
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    for i = 1, n do
        local unit = raid and ("raid" .. i) or ("party" .. i)
        if ns.Short(UnitName(unit)) == name then return unit end
    end
end

-- Class file name ("MAGE") of a player or practice bot, if it can be found.
function S.ClassOf(name)
    if BOT_CLASS[name] then return BOT_CLASS[name] end
    local unit = S.UnitFor(name)
    if unit and UnitClass then return select(2, UnitClass(unit)) end
end

-- Your turn: the game wants a roll from you, or (card games) a move.
function S.IsTurn(s, name)
    if not s then return false end
    local G = S.Game(s)
    if G:Expect(s, name) ~= nil then return true end
    return G.IsTurn ~= nil and G:IsTurn(s, name) and true or false
end

function S.MyTurn(s)
    return S.IsTurn(s, ns.Me())
end

function S.MaxPlayers(s)
    local G = S.Game(s)
    if G.MaxPlayers then return G.MaxPlayers(s) end
    return G.maxPlayers or 40
end

-- Where a game is played: "group" (default, and always for the casino),
-- "guild", "realm" or a private "code" lobby. See Core\Net.lua.
function S.Scope(s)
    if s.scope == "code" then return "code:" .. tostring(s.code) end
    return s.scope or "group"
end

function S.InGroupScope(s)
    return (s.scope or "group") == "group"
end

local function Broadcast(s)
    if s.test then return end
    ns.Net.Send("S", ns.Serialize.Encode(s), S.Scope(s))
end

-- A player's message to the host: over the group in a group game,
-- otherwise by whisper (works anywhere on the realm).
local function ToHost(s, cmd, data)
    if S.InGroupScope(s) then return ns.Net.Send(cmd, data) end
    return ns.Net.Whisper(cmd, data, s.host)
end

-- Five letters and digits that are easy to read out (no 0/O, 1/I).
function S.NewCode()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local out = {}
    for i = 1, 5 do
        local k = math.random(1, #chars)
        out[i] = chars:sub(k, k)
    end
    return table.concat(out)
end

local HostAct

local function DriveBots(s)
    if not s.test or s.phase ~= "rolling" then return end
    local G = S.Game(s)
    s._pending = s._pending or {}
    for _, p in ipairs(s.players) do
        if p.offline or p.out then
            -- An offline bot (practice: /gamble dc) does nothing until it's back.
        elseif p.bot and not s._pending[p.name] and G.BotAct and G.IsTurn and G:IsTurn(s, p.name) then
            s._pending[p.name] = true
            ns.After(0.9 + math.random() * 1.0, function()
                s._pending[p.name] = nil
                if S.sessions[s.kind] ~= s or not G:IsTurn(s, p.name) then return end
                HostAct(s, p.name, G:BotAct(s, p.name))
            end)
        elseif p.bot and not s._pending[p.name] and G.BotThink then
            -- Bots that act without a turn (roulette chips).
            local action = G:BotThink(s, p.name)
            if action then
                s._pending[p.name] = true
                ns.After(0.5 + math.random() * 1.5, function()
                    s._pending[p.name] = nil
                    if S.sessions[s.kind] == s and s.phase == "rolling" then HostAct(s, p.name, action) end
                end)
            end
        elseif p.bot and not s._pending[p.name] and G:Expect(s, p.name) then
            s._pending[p.name] = true
            ns.After(0.6 + math.random() * 0.9, function()
                s._pending[p.name] = nil
                if S.sessions[s.kind] ~= s then return end
                local lo, hi = G:Expect(s, p.name)
                if lo then ns.Rolls.Dispatch(p.name, math.random(lo, hi), lo, hi) end
            end)
        end
    end
end

-- The host changed the game: tell everyone, keep a copy for /reload.
-- `soft` changes (like chips going on a roulette table) are sent a moment
-- later, together, so a burst of clicks doesn't flood the group.
function S.Update(s, soft)
    s.seq = (s.seq or 0) + 1
    s.touched = ns.Now()
    if S.IsHost(s) and not s.test then
        if soft then
            if not s._sendLater then
                s._sendLater = true
                ns.After(0.4, function()
                    s._sendLater = nil
                    if S.sessions[s.kind] == s then Broadcast(s) end
                end)
            end
        else
            Broadcast(s)
        end
        ns.db.active[s.kind] = S.IsActive(s) and s or nil
    end
    if s.phase == "done" then ns.Stats:Record(s) end
    if S.IsHost(s) and S.TrackWaiting then S.TrackWaiting(s) end
    DriveBots(s)
    ns.Changed()
end

---------------------------------------------------------------------------
-- Host actions
---------------------------------------------------------------------------
-- Returns true, or false and the reason.
function S.Open(kind, settings, test, scope)
    if S.IsActive(S.sessions[kind]) then return false, "A game is already running." end
    scope = test and "group" or (scope or "group")
    local code
    if not test then
        if scope == "group" and not ns.Net.Channel() then
            return false, "Join a party or raid first. Everyone in the group sees each other's rolls, so nobody can fake one."
        elseif scope == "guild" and not ns.Net.Route("guild") then
            return false, "You're not in a guild."
        elseif scope == "realm" and not ns.Net.JoinChannel(ns.Net.REALM_CHANNEL) then
            return false, "Joining the realm channel... try again in a moment."
        elseif scope == "code" then
            code = S.NewCode()
            ns.Net.JoinChannel(ns.Net.CodeChannel(code))
        end
    end
    local G = ns.Games[kind]
    local me = ns.Me()
    local s = {
        id = me .. "-" .. ns.Now() .. "-" .. math.random(1000, 9999),
        kind = kind,
        host = me,
        phase = "lobby",
        players = { { name = me, class = S.ClassOf(me) } },
        log = {},
        seq = 0,
        created = ns.Now(),
    }
    if test then s.test = true end
    if scope ~= "group" then s.scope, s.code = scope, code end
    G:Setup(s, settings)
    s.banner = test and "Practice game: the bots join by themselves. No gold, no stats."
        or "Waiting for players to join."
    S.sessions[kind] = s
    S.Update(s)

    if test then
        for i = 1, G.practiceBots do
            ns.After(0.5 * i, function() S.AddBot(kind) end)
        end
    end
    return true
end

-- Practice games only: a fake player that joins now and rolls by itself.
function S.AddBot(kind)
    local s = S.sessions[kind]
    if not (s and s.test and S.CanJoin(s)) or #s.players >= S.MaxPlayers(s) then return end
    for _, name in ipairs(BOTS) do
        if not S.Find(s, name) then
            table.insert(s.players, { name = name, bot = true, class = BOT_CLASS[name], net = s.phase == "rolling" and 0 or nil })
            s.banner = name .. " joined."
            S.Update(s)
            return
        end
    end
end

function S.CanAddBot(s)
    if not (s and s.test and S.CanJoin(s)) or #s.players >= S.MaxPlayers(s) then return false end
    for _, name in ipairs(BOTS) do
        if not S.Find(s, name) then return true end
    end
    return false
end

function S.Start(kind)
    local s = S.sessions[kind]
    if not (S.IsHost(s) and s.phase == "lobby") then return false end
    local G = S.Game(s)
    if #s.players < G.minPlayers then return false, "You need at least " .. G.minPlayers .. " players." end
    if G.CanStart then
        local ok, why = G:CanStart(s)
        if not ok then return false, why end
    end
    s.phase = "rolling"
    s.log = {}
    G:Begin(s)
    S.Update(s)
    if S.MyTurn(s) then ns.UI:YourTurn(kind) end
    return true
end

function S.Cancel(kind)
    local s = S.sessions[kind]
    if not (S.IsHost(s) and S.IsActive(s)) then return end
    s.phase = "cancelled"
    s.banner = "The game was cancelled. No one pays."
    S.Update(s)
end

---------------------------------------------------------------------------
-- Player actions
---------------------------------------------------------------------------
-- Seats open: the lobby, or any time for games like the slot machine.
function S.CanJoin(s)
    if not s then return false end
    return s.phase == "lobby" or (s.phase == "rolling" and S.Game(s).joinAnytime == true)
end

function S.Join(kind)
    local s = S.sessions[kind]
    if not S.CanJoin(s) or S.Find(s, ns.Me()) then return end
    if #s.players >= S.MaxPlayers(s) then return end
    ToHost(s, "J", s.id)
    s._joining = true
    ns.Changed()
end

function S.Leave(kind)
    local s = S.sessions[kind]
    if not s or s.phase ~= "lobby" then return end
    if S.IsHost(s) then return S.Cancel(kind) end
    ToHost(s, "L", s.id)
end

-- Ask the game for a real roll, with the range this game needs right now.
function S.Roll(kind)
    local s = S.sessions[kind]
    if not s then return end
    if S.HostOffline(s) then return end -- the host couldn't see the roll
    local lo, hi = S.Game(s):Expect(s, ns.Me())
    if lo then ns.Rolls.Roll(lo, hi) end
end

-- A move in a card game ("fold", "call", ... or the host's "deal" / "end").
function HostAct(s, name, action)
    local G = S.Game(s)
    -- After a game ends, only what the game allows then (a rematch).
    if s.phase == "done" and not (G.afterGame and G.afterGame[action:match("^%a+") or ""]) then return false end
    local wasMine = S.MyTurn(s)
    local ok, why, soft = G:Act(s, name, action)
    if ok then
        S.Update(s, soft)
        if not wasMine and S.MyTurn(s) then ns.UI:YourTurn(s.kind) end
    end
    return ok, why
end

function S.Act(kind, action)
    local s = S.sessions[kind]
    -- Moves while a game runs; after it ends the game decides (a rematch).
    -- (Games with lobbyActs take moves in the lobby too: seats, races, the map.)
    local lobby = s and s.phase == "lobby" and S.Game(s).lobbyActs
    if not s or not (s.phase == "rolling" or s.phase == "done" or lobby) or S.HostOffline(s) then return false end
    if S.IsHost(s) then return HostAct(s, ns.Me(), action) end
    ToHost(s, "A", s.id .. " " .. action)
    return true
end

---------------------------------------------------------------------------
-- Private cards. The host keeps everyone's in s._hole (never sent in the
-- game); each player gets their own by whisper.
---------------------------------------------------------------------------
S.private = {}

local function PrivateKey(s, hand)
    return s.id .. ":" .. tostring(hand or s.hand)
end

function S.SendPrivate(s, name, cards)
    s._hole = s._hole or {}
    s._hole[name] = cards
    if name == ns.Me() then
        S.private[PrivateKey(s)] = cards
    elseif not s.test then
        ns.Net.Whisper("H", ns.Serialize.Encode({ id = s.id, hand = s.hand, cards = cards }), name)
    end
end

function S.MyCards(s)
    if not s then return nil end
    return S.private[PrivateKey(s)]
end

ns.Net.On("H", function(sender, data)
    local m = ns.Serialize.Decode(data)
    if type(m) ~= "table" or type(m.cards) ~= "table" then return end
    -- Only the host of a game we know may hand us cards for it.
    for _, s in pairs(S.sessions) do
        if s.id == m.id and s.host == sender then
            S.private[PrivateKey(s, m.hand)] = m.cards
            ns.Changed()
            return
        end
    end
    -- The game itself may still be on its way: keep the cards for it.
    if m.id and m.id:sub(1, #sender + 1) == sender .. "-" then
        S.private[m.id .. ":" .. tostring(m.hand)] = m.cards
    end
end)

---------------------------------------------------------------------------
-- Lobbies outside the group: a browser of open guild and realm lobbies,
-- and private lobbies joined by code.
---------------------------------------------------------------------------
S.lobbies = {} -- game id -> { s = game, seen = time }
local LOBBY_TTL = 40

-- Open lobbies of one game you could join, newest first.
function S.Lobbies(kind)
    local list, now, me = {}, ns.Now(), ns.Me()
    for id, L in pairs(S.lobbies) do
        local open = L.s.phase == "lobby" or (L.s.phase == "rolling" and ns.Games[L.s.kind].joinAnytime)
        if now - L.seen > LOBBY_TTL or not open then
            S.lobbies[id] = nil
        elseif L.s.kind == kind and L.s.host ~= me then
            table.insert(list, L.s)
        end
    end
    table.sort(list, function(a, b) return (a.created or 0) > (b.created or 0) end)
    return list
end

function S.JoinLobby(id)
    local L = S.lobbies[id]
    if not L or S.IsActive(S.sessions[L.s.kind]) then return false end
    S.lobbies[id] = nil
    S.sessions[L.s.kind] = L.s
    S.Join(L.s.kind)
    return true
end

-- Join a private lobby by its code: listen on its channel, ask the host.
function S.JoinCode(code)
    code = (code or ""):upper():gsub("[^%w]", "")
    if #code < 4 then return false, "That code looks too short." end
    S.pendingCode = code
    -- Joining a channel takes a moment (sometimes several seconds), and a
    -- message sent before that is lost: ask the host again every two seconds
    -- until they answer (or a minute has passed).
    local tries = 0
    local function Ask()
        if S.pendingCode ~= code or tries >= 30 then return end
        tries = tries + 1
        ns.Net.JoinChannel(ns.Net.CodeChannel(code))
        ns.Net.Send("Q", "", "code:" .. code)
        ns.After(2, Ask)
    end
    ns.After(1, Ask)
    return true
end

local function LeaveCode(s)
    if s and s.scope == "code" and s.code then ns.Net.LeaveChannel(ns.Net.CodeChannel(s.code)) end
end

local function Forget(kind)
    local s = S.sessions[kind]
    -- Forget this game's private cards.
    for key in pairs(S.private) do
        if s and key:sub(1, #s.id + 1) == s.id .. ":" then S.private[key] = nil end
    end
    LeaveCode(s)
    S.sessions[kind] = nil
    ns.Changed()
end

-- Put a finished or cancelled game away so the setup shows again.
function S.Dismiss(kind)
    local s = S.sessions[kind]
    -- A player may also walk away from a game whose host went offline.
    if S.IsActive(s) and not S.HostOffline(s) then return end
    Forget(kind)
end

-- "I'm done with this" (right-click on the game's tab). The host closes
-- the game for everyone; a player gets up from the lobby, or walks away
-- from a running game (the host can skip them). Either way it's gone
-- from this screen and doesn't come back.
function S.Close(kind)
    local s = S.sessions[kind]
    if not s then return end
    if S.IsHost(s) then
        if S.IsActive(s) then
            S.Cancel(kind)
        elseif S.Game(s).arcade and s.phase == "done" then
            s.phase, s.banner = "cancelled", "The lobby is closed."
            S.Update(s)
        end
    elseif s.phase == "lobby" and S.Find(s, ns.Me()) then
        S.Leave(kind)
    end
    S.closed[s.id] = true
    Forget(kind)
end

---------------------------------------------------------------------------
-- Rolls seen in chat
---------------------------------------------------------------------------
ns.Rolls.OnRoll(function(name, roll, lo, hi)
    local wrong
    for _, kind in ipairs(ns.GAME_ORDER) do
        local s = S.sessions[kind]
        if s and s.phase == "rolling" and S.IsHost(s) then
            local G = S.Game(s)
            local elo, ehi = G:Expect(s, name)
            if elo and elo == lo and ehi == hi then
                local wasMine = S.MyTurn(s)
                s.rolls = (s.rolls or 0) + 1
                table.insert(s.log, { n = s.rolls, name = name, roll = roll, lo = lo, hi = hi, tb = s.stage == "tb" or nil })
                while #s.log > LOG_SIZE do table.remove(s.log, 1) end
                G:Apply(s, name, roll)
                S.Update(s)
                if not wasMine and S.MyTurn(s) then ns.UI:YourTurn(kind) end
                return
            elseif elo then
                wrong = wrong or { s = s, lo = elo, hi = ehi }
            end
        end
    end
    if wrong then
        wrong.s.banner = name .. " rolled " .. lo .. " - " .. hi .. ", but this game needs "
            .. wrong.lo .. " - " .. wrong.hi .. ". That roll does not count."
        S.Update(wrong.s)
        return
    end
    if ns.debug then
        for _, kind in ipairs(ns.GAME_ORDER) do
            local s = S.sessions[kind]
            if s and s.phase == "rolling" then
                ns.Print("debug: " .. kind .. " did not take " .. name .. "'s roll (host " .. s.host
                    .. (S.IsHost(s) and ", that's you" or "") .. ", waiting for "
                    .. tostring(S.Game(s).Status and S.Game(s):Status(s)) .. ")")
            end
        end
    end
    -- Other players' copies redraw so the check marks catch up.
    ns.Changed()
end)

---------------------------------------------------------------------------
-- Messages from the group
---------------------------------------------------------------------------
ns.Net.On("S", function(sender, data)
    local s = ns.Serialize.Decode(data)
    if type(s) ~= "table" or type(s.players) ~= "table" or not ns.Games[s.kind] then return end
    if s.host ~= sender then return end -- only the host can describe its game
    local me = ns.Me()
    local cur = S.sessions[s.kind]
    local same = cur and cur.id == s.id
    if same and (s.seq or 0) <= (cur.seq or 0) then return end
    -- A game that's over (and that you already put away) isn't picked up again.
    if not same and (s.phase == "done" or s.phase == "cancelled") then return end
    if S.closed[s.id] then return end -- you closed it from its tab
    -- Guild, realm and code lobbies don't pop up on everyone's screen.
    if not S.InGroupScope(s) and not same and not S.Find(s, me) then
        if s.scope == "code" and S.pendingCode == s.code then
            S.pendingCode = nil -- you typed this code: take it and sit down
        else
            S.lobbies[s.id] = { s = s, seen = ns.Now() }
            ns.Changed()
            return
        end
    end
    if not same and S.IsActive(cur) and (S.IsHost(cur) or S.Find(cur, me)) then
        return -- busy in another game of this type
    end
    s.log = s.log or {}
    local wasMine = same and S.MyTurn(cur)
    S.sessions[s.kind] = s
    if s.phase == "done" then ns.Stats:Record(s) end
    if not same and s.phase == "lobby" and ns.db.popup and S.InGroupScope(s) then ns.UI:ShowGame(s.kind) end
    if not same and not S.InGroupScope(s) then
        ns.UI:ShowGame(s.kind)
        if s.phase == "lobby" and not S.Find(s, me) then S.Join(s.kind) end
    end
    -- Back after a disconnect or /reload: open the game you're seated in.
    if not same and s.phase == "rolling" and S.Find(s, me) then ns.UI:ShowGame(s.kind) end
    if not wasMine and S.MyTurn(s) then ns.UI:YourTurn(s.kind) end
    -- Some games answer by themselves (Battleship: "was that a hit?"),
    -- whether or not their tab is open.
    local G = S.Game(s)
    if G.OnState then ns.After(0, function() if S.sessions[s.kind] == s then G:OnState(s) end end) end
    ns.Changed()
end)

local function Hosted(sender, id)
    for _, s in pairs(S.sessions) do
        if s.id == id and S.IsHost(s) and not s.test then return s end
    end
end

ns.Net.On("J", function(sender, id)
    local s = Hosted(sender, id)
    if not S.CanJoin(s) then return end
    if not S.Find(s, sender) then
        if #s.players >= S.MaxPlayers(s) then
            s.banner = sender .. " wanted to join, but the table is full."
            return S.Update(s)
        end
        table.insert(s.players, { name = sender, class = S.ClassOf(sender), net = s.phase == "rolling" and 0 or nil })
        s.banner = sender .. " joined."
    end
    S.Update(s) -- also answers a repeated join
end)

ns.Net.On("L", function(sender, id)
    local s = Hosted(sender, id)
    if not s or s.phase ~= "lobby" then return end
    local i = S.Find(s, sender)
    if i then
        table.remove(s.players, i)
        s.banner = sender .. " left."
        S.Update(s)
    end
end)

ns.Net.On("A", function(sender, data)
    local id, action = data:match("^(%S+) (%S+)$")
    local s = id and Hosted(sender, id)
    if not s or not (s.phase == "rolling" or s.phase == "done" or (s.phase == "lobby" and S.Game(s).lobbyActs)) then return end
    HostAct(s, sender, action)
end)

ns.Net.On("Q", function(sender)
    for _, s in pairs(S.sessions) do
        if S.IsHost(s) and S.IsActive(s) and not s.test then
            Broadcast(s)
            -- A player who reloaded mid-hand needs their cards again.
            local cards = s._hole and s._hole[sender]
            if cards then
                ns.Net.Whisper("H", ns.Serialize.Encode({ id = s.id, hand = s.hand, cards = cards }), sender)
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Group changes, /reload
---------------------------------------------------------------------------
local function InGroup(name)
    if name == ns.Me() then return true end
    if UnitInParty and UnitInParty(name) then return true end
    if UnitInRaid and UnitInRaid(name) then return true end
    return false
end

---------------------------------------------------------------------------
-- Disconnects. The game never waits by force: when a player goes offline
-- (or leaves the group) the host is asked whether to wait for them or go on
-- without them. A player who comes back catches up by themselves (their
-- addon asks with Q after logging in).
---------------------------------------------------------------------------
S.fakeOffline = {}   -- practice: bots switched off with /gamble dc
S.hostGone = {}      -- game id -> true while its host is offline (players' side)

local UnitFor = S.UnitFor

-- Can this player still play: in the group and online?
function S.Connected(s, name)
    if name == ns.Me() then return true end
    if s.test then return not S.fakeOffline[name] end
    if not InGroup(name) then return false end
    local unit = UnitFor(name)
    if unit and UnitIsConnected and not UnitIsConnected(unit) then return false end
    return true
end

function S.HostOffline(s)
    return s ~= nil and not S.IsHost(s) and S.hostGone[s.id] == true
end

-- Host side: remember since when the game waits on each player.
function S.TrackWaiting(s)
    s._since = s._since or {}
    for _, p in ipairs(s.players) do
        if S.IsTurn(s, p.name) then
            s._since[p.name] = s._since[p.name] or ns.Now()
        else
            s._since[p.name] = nil
        end
    end
end

-- How long the game has waited on this player, in seconds.
function S.WaitedFor(s, name)
    local since = s._since and s._since[name]
    return since and (ns.Now() - since) or 0
end

-- The host may skip this player: offline, or a minute without a move.
function S.CanSkip(s, name)
    if not (S.IsHost(s) and s.phase == "rolling") or name == s.host then return false end
    local _, p = S.Find(s, name)
    if not p or p.out or p.house then return false end
    return p.offline == true or S.WaitedFor(s, name) >= 60
end

function S.CanBringBack(s, name)
    if not (S.IsHost(s) and s.phase == "rolling") then return false end
    local _, p = S.Find(s, name)
    return p ~= nil and p.out == true and not p.house
end

-- Would skipping this player leave too few to play (and so end the game)?
function S.DropEnds(s, name)
    local G = S.Game(s)
    return G.DropEnds ~= nil and G:DropEnds(s, name) == true
end

-- Host: changed their mind, the player is in again (and waited for).
function S.Undrop(kind, name)
    local s = S.sessions[kind]
    if not S.CanBringBack(s, name) then return end
    local _, p = S.Find(s, name)
    local G = S.Game(s)
    p.out = nil
    s.banner = name .. " is back in" .. (p.offline and "; the game waits for them." or ".")
    if G.Undrop then G:Undrop(s, name) end
    S.Update(s)
end

-- Host: carry on without this player (Skip). Undone with Bring back.
function S.Drop(kind, name)
    local s = S.sessions[kind]
    if not (S.IsHost(s) and s.phase == "rolling") or name == s.host then return end
    local _, p = S.Find(s, name)
    if not p or p.out then return end
    local G = S.Game(s)
    local wasMine = S.MyTurn(s)
    p.out = true
    s.banner = name .. " is out" .. (p.offline and " (offline)." or ".")
    if G.Drop then G:Drop(s, name) end
    S.Update(s)
    if not wasMine and S.MyTurn(s) then ns.UI:YourTurn(kind) end
end

-- Check everyone's connection; tell the host about changes.
function S.CheckConnections()
    for _, s in pairs(S.sessions) do
        if S.IsActive(s) and S.InGroupScope(s) then
            if S.IsHost(s) then
                local changed = false
                for i = #s.players, 1, -1 do
                    local p = s.players[i]
                    local on = p.house or S.Connected(s, p.name)
                    if s.phase == "lobby" and not on and p.name ~= s.host then
                        -- Not playing yet: just free the seat.
                        s.banner = p.name .. " left."
                        table.remove(s.players, i)
                        changed = true
                    elseif s.phase == "rolling" and not on and not p.offline then
                        p.offline = true
                        s.banner = p.name .. " went offline."
                        changed = true
                        if not p.out then ns.UI:PlayerOffline(s, p.name) end
                    elseif on and p.offline then
                        p.offline = nil
                        local G = S.Game(s)
                        if p.out and G.Rejoin then
                            G:Rejoin(s, p.name)
                        else
                            s.banner = p.name .. " is back" .. (p.out and ", and plays again next game." or "!")
                        end
                        changed = true
                    end
                end
                if changed then S.Update(s) end
                S.TrackWaiting(s)
            elseif not s.test then
                if not InGroup(s.host) then
                    s.phase = "cancelled"
                    s.banner = s.host .. " left the group, so the game is off."
                    ns.Changed()
                else
                    local gone = not S.Connected(s, s.host)
                    if gone ~= (S.hostGone[s.id] == true) then
                        S.hostGone[s.id] = gone or nil
                        ns.Changed()
                    end
                end
            end
        end
    end
end

ns.On("GROUP_ROSTER_UPDATE", function() S.CheckConnections() end)
ns.On("UNIT_CONNECTION", function() S.CheckConnections() end)

-- A slow heartbeat: connections, and the Skip buttons after a minute.
local beats = 0
local function Heartbeat()
    S.CheckConnections()
    beats = beats + 1
    if beats % 3 == 0 then
        for _, s in pairs(S.sessions) do
            local open = s.phase == "lobby" or (s.phase == "rolling" and S.Game(s).joinAnytime)
            if S.IsHost(s) and open and not S.InGroupScope(s) then Broadcast(s) end
        end
    end
    for _, s in pairs(S.sessions) do
        if S.IsActive(s) then
            ns.Changed()
            break
        end
    end
    ns.After(5, Heartbeat)
end
ns.After(5, Heartbeat)

-- Practice: switch a bot off or back on.
function S.ToggleBot(name)
    for _, s in pairs(S.sessions) do
        if s.test and S.Find(s, name) then
            S.fakeOffline[name] = not S.fakeOffline[name] or nil
            S.CheckConnections()
            return true, S.fakeOffline[name] and "offline" or "back online"
        end
    end
    return false
end

-- After a /reload the host picks its games back up.
function S.Restore()
    local me = ns.Me()
    for kind, s in pairs(ns.db.active) do
        if ns.Games[kind] and s.host == me and S.IsActive(s) and ns.Now() - (s.touched or s.created or 0) < 3600 then
            s._pending = nil
            S.sessions[kind] = s
            if s._hole and s._hole[me] then S.private[PrivateKey(s)] = s._hole[me] end
        else
            ns.db.active[kind] = nil
        end
    end
end

ns.On("PLAYER_ENTERING_WORLD", function()
    ns.After(3, function()
        if ns.Net.Route("guild") then ns.Net.Send("Q", "", "guild") end
        if not ns.Net.Channel() then return end
        ns.Net.Send("Q", "")
        for _, s in pairs(S.sessions) do
            if S.IsHost(s) and S.IsActive(s) then Broadcast(s) end
        end
    end)
end)

-- Queue: find an opponent on your realm for a two-player Arcade game, like
-- Hearthstone's "Play". Works for any game kind (Warcraft III later).
--
-- While you're queued your addon says so on the hidden realm channel every
-- few seconds (MQ). When two queued players see each other, the one whose
-- name sorts first hosts: it opens a private-code lobby and whispers the
-- code to the other (MI), who joins it at once. When both are seated the
-- host starts the game; each side's page then picks the deck chosen before
-- queueing. If the invite isn't taken within a few seconds, both keep
-- looking.
--
-- Messages: MQ = "kind" (I'm looking, realm channel), MI = "kind\tcode"
-- (join my lobby, whisper).
local ADDON, ns = ...

local Q = {}
ns.Queue = Q

Q.PING = 4        -- seconds between "I'm looking" messages
Q.SEEN = 15       -- someone counts as looking for this long after their last message
Q.INVITE = 12     -- seconds an invite waits for its answer

Q.queued = {}     -- kind -> { since, hosting = name, invited = time }
Q.seen = {}       -- kind -> name -> last time they said they're looking

local function Now() return ns.Now() end

-- How many others are looking for this game right now.
function Q.Others(kind)
    local n = 0
    for _, t in pairs(Q.seen[kind] or {}) do
        if Now() - t <= Q.SEEN then n = n + 1 end
    end
    return n
end

function Q.IsQueued(kind)
    return Q.queued[kind] ~= nil
end

function Q.Since(kind)
    local q = Q.queued[kind]
    return q and (Now() - q.since) or 0
end

local function Ping(kind)
    local q = Q.queued[kind]
    if q and not q.hosting and not q.joining then ns.Net.Send("MQ", kind, "realm") end
end

-- Join the queue (false, why if the realm channel can't be used).
function Q.Join(kind)
    if ns.db.realmLobbies == false then return false, "Realm lobbies are off in Settings." end
    local S = ns.Session
    if S.IsActive(S.Get(kind)) then return false, "You're already in a lobby or game. Close it first." end
    if S.Get(kind) then S.Dismiss(kind) end -- a finished one: put it away
    ns.Net.JoinChannel(ns.Net.REALM_CHANNEL)
    Q.queued[kind] = { since = Now() }
    local function Loop()
        if not Q.queued[kind] then return end
        Ping(kind)
        Q.Check(kind)
        ns.After(Q.PING, Loop)
    end
    ns.After(0.5, Loop)
    ns.Changed()
    return true
end

function Q.Leave(kind)
    local q = Q.queued[kind]
    Q.queued[kind] = nil
    -- An invite of ours nobody took: close that lobby.
    local s = ns.Session.Get(kind)
    if q and q.hosting and s and ns.Session.IsHost(s) and s.phase == "lobby" then
        ns.Session.Cancel(kind)
        ns.Session.Dismiss(kind)
    end
    ns.Changed()
end

-- Matched: out of the queue (the game takes over).
local function Matched(kind)
    Q.queued[kind] = nil
    ns.Changed()
end

-- Who we're trying to get into a game with right now (invited or inviting), or nil.
function Q.Partner(kind)
    local q = Q.queued[kind]
    return q and (q.hosting or q.joiningWith)
end

-- Host side: is our invited player seated? Start. Taking too long? Give up
-- on them and keep looking.
function Q.Check(kind)
    local q = Q.queued[kind]
    if not q then return end
    local S = ns.Session
    local s = S.Get(kind)
    -- Guest side: seated in their lobby (matched), or it never came (look again).
    if q.joining then
        if s and S.Find(s, ns.Me()) then
            Matched(kind)
        elseif Now() - q.joining > Q.INVITE then
            q.joining, q.joiningWith = nil, nil
        end
        return
    end
    if not q.hosting then return end
    if s and S.IsHost(s) and s.phase == "lobby" and #s.players >= 2 then
        Matched(kind)
        S.Start(kind)
        return
    end
    if Now() - q.invited > Q.INVITE then
        q.hosting, q.invited = nil, nil
        if s and S.IsHost(s) and s.phase == "lobby" then
            S.Cancel(kind)
            S.Dismiss(kind)
        end
    end
end

-- Someone else is looking: the name that sorts first hosts.
ns.Net.On("MQ", function(sender, kind)
    if not ns.Games[kind] or sender == ns.Me() then return end
    Q.seen[kind] = Q.seen[kind] or {}
    Q.seen[kind][sender] = Now()
    local q = Q.queued[kind]
    if not q or q.hosting or ns.Me() > sender then return end
    if ns.Session.IsActive(ns.Session.Get(kind)) then return end
    local ok = ns.Session.Open(kind, {}, false, "code")
    local s = ns.Session.Get(kind)
    if not ok or not s then return end
    s.queued = true
    q.hosting, q.invited = sender, Now()
    ns.Net.Whisper("MI", kind .. "\t" .. s.code, sender)
    ns.Changed()
end)

-- An invite: take it if we're still looking and not hosting one ourselves.
ns.Net.On("MI", function(sender, data)
    local kind, code = data:match("^(%w+)\t(%w+)$")
    local q = kind and Q.queued[kind]
    if not q or q.hosting then return end
    if q.joining or ns.Session.IsActive(ns.Session.Get(kind)) then return end
    q.joining, q.joiningWith = Now(), sender
    ns.Session.JoinCode(code)
    ns.Changed()
end)

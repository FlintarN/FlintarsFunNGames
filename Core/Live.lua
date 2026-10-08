-- Live: the engine for real-time multiplayer games (Agar.io and friends).
--
-- It rides on a Session lobby, so a live game gets lobbies, scopes (group,
-- guild, realm, private code), joining and practice for free. On top:
--   * each player owns its own state (Live.SetMine) and sends it a few
--     times a second over the lobby's scope;
--   * everyone else's state arrives in `rt.peers`, smoothed between
--     updates (Live.Smooth), and players who go quiet are dropped;
--   * one-off events (Live.Event: "I ate Bob") go out at once.
-- A game never touches Net itself.
--
-- Messages: LV = a player's state, LE = an event. Both carry the game id.
local ADDON, ns = ...

local Live = {}
ns.Live = Live

local runtimes = {} -- game id -> runtime

local function Now() return GetTime and GetTime() or 0 end

-- Start (or get) the live runtime for a game.
-- opts: rate (seconds between sends), timeout (drop after silence),
--       onEvent(rt, sender, kind, data)
function Live.Attach(s, opts)
    local rt = runtimes[s.id]
    if rt then return rt end
    opts = opts or {}
    rt = {
        s = s,
        id = s.id,
        rate = opts.rate or 0.4,
        timeout = opts.timeout or 8,
        onEvent = opts.onEvent,
        peers = {},   -- name -> { state, prev, t, prevT, seen }
        lastSend = 0,
    }
    runtimes[s.id] = rt
    return rt
end

function Live.Get(id)
    return runtimes[id]
end

-- Stop: tell the others we left, forget everything.
function Live.Detach(id)
    local rt = runtimes[id]
    if not rt then return end
    Live.Event(rt, "leave", "")
    runtimes[id] = nil
end

local function Send(rt, cmd, payload)
    local s = rt.s
    if s.test then return end -- practice: nothing leaves this client
    if cmd == "LV" then
        -- Positions, several a second: over the fast prefixes, and only the
        -- latest one waits if WoW's send limit holds them up.
        ns.Net.SendFast(cmd, rt.id .. "\t" .. payload, ns.Session.Scope(s), "LV" .. rt.id)
    else
        ns.Net.Send(cmd, rt.id .. "\t" .. payload, ns.Session.Scope(s))
    end
end

-- Your own state: sent at the runtime's rate by Live.Tick.
function Live.SetMine(rt, state)
    rt.mine = state
end

function Live.Event(rt, kind, data)
    Send(rt, "LE", kind .. "\t" .. (data or ""))
    -- Practice: deliver locally so bots can react.
    if rt.s.test and rt.onEvent then rt.onEvent(rt, ns.Me(), kind, data or "") end
end

-- Call every frame: sends your state when due, drops silent players.
function Live.Tick(rt)
    local now = Now()
    if rt.mine and now - rt.lastSend >= rt.rate then
        rt.lastSend = now
        Send(rt, "LV", ns.Serialize.Encode(rt.mine))
    end
    for name, p in pairs(rt.peers) do
        if now - p.seen > rt.timeout then rt.peers[name] = nil end
    end
end

-- A peer's state now, moving smoothly from the previous update to the
-- latest one (numbers only; everything else as last sent).
function Live.Smooth(rt, p)
    if not p.prev or not p.prevT then return p.state end
    local span = math.max(0.05, p.t - p.prevT)
    local k = math.min(1, (Now() - p.t) / span)
    local out = {}
    for key, v in pairs(p.state) do
        local a = p.prev[key]
        if type(v) == "number" and type(a) == "number" then
            out[key] = a + (v - a) * k
        else
            out[key] = v
        end
    end
    return out
end

-- Practice bots (or tests) feed a peer directly.
function Live.Feed(rt, name, state)
    local p = rt.peers[name]
    local now = Now()
    if p then
        p.prev, p.prevT = p.state, p.t
        p.state, p.t, p.seen = state, now, now
    else
        rt.peers[name] = { state = state, t = now, seen = now }
    end
end

local function Split(data)
    local id, rest = data:match("^([^\t]+)\t(.*)$")
    return id, rest
end

ns.Net.On("LV", function(sender, data)
    local id, payload = Split(data)
    local rt = id and runtimes[id]
    if not rt then return end
    local state = ns.Serialize.Decode(payload)
    if type(state) == "table" then Live.Feed(rt, sender, state) end
end)

ns.Net.On("LE", function(sender, data)
    local id, payload = Split(data)
    local rt = id and runtimes[id]
    if not rt then return end
    local kind, rest = payload:match("^([^\t]*)\t?(.*)$")
    if kind == "leave" then
        rt.peers[sender] = nil
    end
    if rt.onEvent then rt.onEvent(rt, sender, kind, rest) end
end)

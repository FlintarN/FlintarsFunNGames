-- Lockstep: several players run the same deterministic game (Warcraft 4),
-- and only the commands travel. Time is cut into turns (TURN seconds of
-- game); a command given now is scheduled DELAY turns ahead, and a turn only
-- runs when every player's commands for it are known. Everyone then applies
-- the same commands in the same order (seat 1, 2, 3, ...), so the games stay
-- identical. Seats the computer plays aren't here: every client runs the
-- computer itself, inside the turns (see UI\WarcraftPage.lua).
--
-- Each message (the fast prefixes) says "I've sent everything up to turn T"
-- (t), "I have yours up to turn A" for each other seat (a), and carries my
-- commands for the turns someone hasn't confirmed yet (c), so a lost message
-- is simply covered by the next one. Every HASH turns each side sends a
-- fingerprint of the game; if any differ the games have drifted apart.
-- Messages go once to the whole group when everyone is in it, else by
-- whisper to each player.
--
--   local g = ns.Lockstep.New({ id = gameId, seat = 1, peers = { [2] = "Bob", [3] = "Cara" },
--       hash = function() return E.Hash(st) end })
--   (two players: peer = "Bob" instead of peers)
--   g:Command(cmd)              -- my command, for a later turn
--   g:Update(now)               -- every frame: sends when due
--   while g:CanRun() do g:Run(function(bySeat) ...apply and simulate... end) end
local ADDON, ns = ...

local L = {}
ns.Lockstep = L

L.TURN = 0.25  -- seconds of game per turn
L.DELAY = 2    -- a command runs this many turns after it was given
L.SEND = 0.25  -- at most one message this often
L.BEAT = 0.5   -- and at least this often (a lost message is covered soon)
L.HASH = 20    -- turns between fingerprints

local games = {} -- id -> game (to deliver messages)
local G = {}
G.__index = G

-- What the others will get: through the wire and back, so everyone applies
-- exactly the same numbers.
local function Clean(cmd)
    return ns.Serialize.Decode(ns.Serialize.Encode(cmd))
end

function L.New(o)
    local peers = o.peers or { [3 - o.seat] = o.peer }
    local g = setmetatable({
        id = o.id, seat = o.seat, peers = peers, hash = o.hash, send = o.send,
        turn = 0,                    -- the next turn to run
        mine = {},                   -- turn -> my commands
        theirs = {},                 -- seat -> turn -> commands
        myThru = L.DELAY - 1,        -- my commands are final up to here
        thru = {},                   -- seat -> their commands are known up to here
        acked = {},                  -- seat -> they have mine up to here
        heard = {},                  -- seat -> when last heard from
        lastSend = -100, dirty = true,
        hashes = {}, theirHashes = {},
    }, G)
    for seat in pairs(peers) do
        g.theirs[seat], g.thru[seat], g.acked[seat], g.theirHashes[seat] = {}, L.DELAY - 1, -1, {}
    end
    games[g.id] = g
    return g
end

function L.Stop(g)
    if g then games[g.id] = nil end
end

function G:Command(cmd)
    local t = self.turn + L.DELAY
    self.mine[t] = self.mine[t] or {}
    table.insert(self.mine[t], Clean(cmd))
    self.dirty = true
end

-- The lowest turn every other player has of mine.
function G:MinAcked()
    local low
    for _, a in pairs(self.acked) do if not low or a < low then low = a end end
    return low or self.turn
end

-- Everyone else in my group? Then one message reaches them all.
local function AllInGroup(peers)
    if not (ns.Net.Channel and ns.Net.Channel()) or not UnitInParty then return false end
    for _, name in pairs(peers) do
        if not (UnitInParty(name) or (UnitInRaid and UnitInRaid(name))) then return false end
    end
    return true
end

function G:Send(now)
    -- Mine are kept until everyone has them (a message may be lost) and this
    -- side has run that turn.
    local low = self:MinAcked()
    for t in pairs(self.mine) do
        if t <= low and t < self.turn then self.mine[t] = nil end
    end
    local c = {}
    for t = low + 1, self.turn + L.DELAY do
        if self.mine[t] and #self.mine[t] > 0 then table.insert(c, { t, self.mine[t] }) end
    end
    local a = {}
    for seat, thru in pairs(self.thru) do table.insert(a, { seat, thru }) end
    table.sort(a, function(x, y) return x[1] < y[1] end)
    local msg = { i = self.id, s = self.seat, t = self.myThru, a = a, c = c }
    if self.lastHash then msg.h = self.lastHash end
    local data = ns.Serialize.Encode(msg)
    if self.send then
        self.send(data)
    elseif next(self.peers) then
        if AllInGroup(self.peers) then
            ns.Net.SendFast("LS", data, "group")
        else
            for _, name in pairs(self.peers) do ns.Net.WhisperFast("LS", data, name) end
        end
    end
    self.lastSend, self.dirty = now, false
end

function G:Update(now)
    self.myThru = math.max(self.myThru, self.turn + L.DELAY - 1)
    local since = now - self.lastSend
    if (self.dirty and since >= L.SEND) or since >= L.BEAT then self:Send(now) end
end

function G:CanRun()
    if self.desync then return false end
    for _, thru in pairs(self.thru) do
        if thru < self.turn then return false end
    end
    return true
end

-- Seconds since the quietest other player was last heard from, and their
-- seat (nil: nobody heard yet).
function G:Silence(now)
    local worst, who
    for seat in pairs(self.peers) do
        local h = self.heard[seat]
        local s = h and (now - h) or nil
        if s and (not worst or s > worst) then worst, who = s, seat end
    end
    return worst, who
end

-- Who are we waiting for right now? (seats whose commands for this turn are missing)
function G:Waiting()
    local out = {}
    for seat, thru in pairs(self.thru) do
        if thru < self.turn then table.insert(out, seat) end
    end
    table.sort(out)
    return out
end

-- Run the next turn: fn(bySeat) applies { [seat] = cmds, ... } in seat
-- order and simulates the turn.
function G:Run(fn)
    local t = self.turn
    local bySeat = {}
    bySeat[self.seat] = self.mine[t] or {}
    for seat in pairs(self.peers) do
        bySeat[seat] = self.theirs[seat][t] or {}
        self.theirs[seat][t] = nil
    end
    fn(bySeat)
    self.turn = t + 1
    if t > 0 and t % L.HASH == 0 and self.hash then
        local h = tostring(self.hash())
        self.hashes[t] = h
        self.lastHash = { t, h }
        for seat in pairs(self.peers) do self:Check(seat, t) end
    end
end

function G:Check(seat, t)
    local mine, theirs = self.hashes[t], self.theirHashes[seat] and self.theirHashes[seat][t]
    if mine and theirs and mine ~= theirs then self.desync = t end
end

function G:Receive(msg, now)
    local seat = tonumber(msg.s)
    if not seat then -- an older two-player message: the one other seat
        seat = next(self.peers)
    end
    if not seat or not self.peers[seat] then return end
    self.heard[seat] = now
    if type(msg.t) == "number" then self.thru[seat] = math.max(self.thru[seat], msg.t) end
    if type(msg.a) == "number" then
        self.acked[seat] = math.max(self.acked[seat], msg.a)
    elseif type(msg.a) == "table" then
        for _, pair in ipairs(msg.a) do
            if type(pair) == "table" and pair[1] == self.seat and type(pair[2]) == "number" then
                self.acked[seat] = math.max(self.acked[seat], pair[2])
            end
        end
    end
    for _, tc in ipairs(msg.c or {}) do
        local t, cmds = tc[1], tc[2]
        if type(t) == "number" and t >= self.turn and type(cmds) == "table" then self.theirs[seat][t] = cmds end
    end
    if type(msg.h) == "table" and type(msg.h[1]) == "number" then
        self.theirHashes[seat][msg.h[1]] = tostring(msg.h[2])
        self:Check(seat, msg.h[1])
    end
end

ns.Net.On("LS", function(sender, data)
    local msg = ns.Serialize.Decode(data)
    if type(msg) ~= "table" then return end
    local g = games[msg.i]
    if not g then return end
    local seat = tonumber(msg.s) or next(g.peers)
    local name = seat and g.peers[seat]
    if name and (name == sender or ns.Short(name) == sender) then g:Receive(msg, GetTime and GetTime() or 0) end
end)

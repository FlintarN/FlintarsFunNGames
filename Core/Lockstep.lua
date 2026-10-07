-- Lockstep: two players run the same deterministic game (Warcraft III), and
-- only the commands travel. Time is cut into turns (TURN seconds of game);
-- a command given now is scheduled DELAY turns ahead, and a turn only runs
-- when both sides' commands for it are known. Both sides then apply the
-- same commands in the same order (chair 1, then chair 2), so the two games
-- stay identical.
--
-- Messages (whisper, the fast prefixes) say "I've sent everything up to turn
-- T" (t), "I have yours up to turn A" (a), and carry my commands for the
-- turns the other side hasn't confirmed yet (c), so a lost message is simply
-- covered by the next one. Every HASH turns each side sends a fingerprint of
-- the game; if they differ the games have drifted apart (a desync).
--
--   local g = ns.Lockstep.New({ id = gameId, seat = 1, peer = "Bob",
--       hash = function() return E.Hash(st) end })
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

-- What the other side will get: through the wire and back, so both apply
-- exactly the same numbers.
local function Clean(cmd)
    return ns.Serialize.Decode(ns.Serialize.Encode(cmd))
end

function L.New(o)
    local g = setmetatable({
        id = o.id, seat = o.seat, peer = o.peer, hash = o.hash, send = o.send,
        turn = 0,                    -- the next turn to run
        mine = {}, theirs = {},      -- turn -> list of commands
        myThru = L.DELAY - 1,        -- my commands are final up to here
        theirThru = L.DELAY - 1,     -- theirs are known up to here
        acked = -1,                  -- they have mine up to here
        lastSend = -100, dirty = true,
        hashes = {}, theirHashes = {},
        lastHeard = nil,
    }, G)
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

function G:Send(now)
    -- Mine are kept until the other side has them (a message may be lost)
    -- and this side has run that turn.
    for t in pairs(self.mine) do
        if t <= self.acked and t < self.turn then self.mine[t] = nil end
    end
    local c = {}
    for t = self.acked + 1, self.turn + L.DELAY do
        if self.mine[t] and #self.mine[t] > 0 then table.insert(c, { t, self.mine[t] }) end
    end
    local msg = { i = self.id, t = self.myThru, a = self.theirThru, c = c }
    if self.lastHash then msg.h = self.lastHash end
    local data = ns.Serialize.Encode(msg)
    if self.send then self.send(data) else ns.Net.WhisperFast("LS", data, self.peer) end
    self.lastSend, self.dirty = now, false
end

function G:Update(now)
    self.myThru = math.max(self.myThru, self.turn + L.DELAY - 1)
    local since = now - self.lastSend
    if (self.dirty and since >= L.SEND) or since >= L.BEAT then self:Send(now) end
end

function G:CanRun()
    return not self.desync and self.theirThru >= self.turn
end

-- Seconds since the other side was last heard from (nil: not yet).
function G:Silence(now)
    return self.lastHeard and (now - self.lastHeard) or nil
end

-- Run the next turn: fn(bySeat) applies { [1] = cmds, [2] = cmds } and
-- simulates the turn.
function G:Run(fn)
    local t = self.turn
    local bySeat = {}
    bySeat[self.seat] = self.mine[t] or {}
    bySeat[3 - self.seat] = self.theirs[t] or {}
    fn(bySeat)
    self.theirs[t] = nil -- (mine stay until acknowledged: see Send)
    self.turn = t + 1
    if t > 0 and t % L.HASH == 0 and self.hash then
        local h = tostring(self.hash())
        self.hashes[t] = h
        self.lastHash = { t, h }
        self:Check(t)
    end
end

function G:Check(t)
    local mine, theirs = self.hashes[t], self.theirHashes[t]
    if mine and theirs and mine ~= theirs then self.desync = t end
end

function G:Receive(msg, now)
    self.lastHeard = now
    if type(msg.t) == "number" then self.theirThru = math.max(self.theirThru, msg.t) end
    if type(msg.a) == "number" then self.acked = math.max(self.acked, msg.a) end
    for _, tc in ipairs(msg.c or {}) do
        local t, cmds = tc[1], tc[2]
        if type(t) == "number" and t >= self.turn and type(cmds) == "table" then self.theirs[t] = cmds end
    end
    if type(msg.h) == "table" and type(msg.h[1]) == "number" then
        self.theirHashes[msg.h[1]] = tostring(msg.h[2])
        self:Check(msg.h[1])
    end
end

ns.Net.On("LS", function(sender, data)
    local msg = ns.Serialize.Decode(data)
    if type(msg) ~= "table" then return end
    local g = games[msg.i]
    if g and (g.peer == sender or ns.Short(g.peer) == sender) then g:Receive(msg, GetTime and GetTime() or 0) end
end)

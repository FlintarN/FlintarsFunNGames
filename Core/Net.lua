-- Net: addon messages. Long messages are cut into numbered chunks and put
-- back together on the other side.
--
-- Where a message goes is its "scope":
--   "group"       your party or raid (the casino always uses this)
--   "guild"       the guild addon channel
--   "realm"       a hidden chat channel every Arcade player on the realm joins
--                 (same faction: WoW keeps custom channels per faction)
--   "code:K7QX2"  a hidden chat channel just for one private lobby
-- Messages to one player (private cards, players talking to a host outside
-- a group) go by whisper.
--
-- Wire format: "<cmd>:<msgId>:<part>/<parts>@<from>:<data>". <from> is the
-- sender's own name as their game gives it (UnitName), so everyone uses the
-- same name for them: WoW hands the receiver "Name-Realm" on Retail, and
-- names on WoW Forever are two words ("First Last"), which the two sides
-- may not write the same way.
local ADDON, ns = ...

local Net = {}
ns.Net = Net

Net.PREFIX = "FunNGames"
Net.REALM_CHANNEL = "FunNGamesRealm"
-- Real-time games (Warcraft 4 lockstep) send several messages a second, to
-- several players. WoW lets each prefix send about one a second after a
-- short burst, so those messages take turns over prefixes of their own.
Net.FAST = { "FunNGamesL1", "FunNGamesL2", "FunNGamesL3", "FunNGamesL4", "FunNGamesL5", "FunNGamesL6",
    "FunNGamesL7", "FunNGamesL8" }
local FAST = {}
for _, p in ipairs(Net.FAST) do FAST[p] = true end
-- Every prefix: a long message (a Hearthstone board is a dozen parts) has
-- its parts dealt over all of them, as each has its own send limit.
local ALL = { Net.PREFIX }
for _, p in ipairs(Net.FAST) do ALL[#ALL + 1] = p end
local spreadNext = 0
local fastNext = 0
local MAX = 250 -- bytes in one addon message, with room to spare (WoW allows 255)

local SendAddon = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix

local handlers = {}
-- Where to whisper everyone we've heard from: their name -> the sender WoW
-- gave us ("Name-Realm" on Retail; a whisper to another realm needs it, or
-- WoW sends it to a namesake on ours, or nowhere).
local address = {}
local function Squash(s) return ((s or ""):lower():gsub("[%s%-']", "")) end
local function MyRealm(realm)
    return Squash(realm) == Squash(GetNormalizedRealmName and GetNormalizedRealmName())
        or Squash(realm) == Squash(GetRealmName and GetRealmName())
end

-- The address to whisper a player at.
function Net.Full(name)
    if not name then return name end
    return address[name] or name
end

-- The name a message is from: the one the sender put in it, when it really is
-- the player WoW says sent it (same letters, maybe with a realm after);
-- otherwise WoW's sender without the realm.
local function From(raw, said)
    if said and said ~= "" then
        local a, b = Squash(raw), Squash(said)
        if a:sub(1, #b) == b then return said end
    end
    return ns.Short(raw)
end
local partial = {} -- sender .. msgId -> { parts, got, n }
local nextId = 0

function Net:Init()
    if RegisterPrefix then
        RegisterPrefix(Net.PREFIX)
        for _, p in ipairs(Net.FAST) do RegisterPrefix(p) end
    end
end

function Net.On(cmd, fn)
    handlers[cmd] = fn
end

-- The group chat the game would use for us, or nil when not in a group.
function Net.Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then
        if LE_PARTY_CATEGORY_INSTANCE and LE_PARTY_CATEGORY_HOME
            and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
            return "INSTANCE_CHAT"
        end
        return "PARTY"
    end
end

---------------------------------------------------------------------------
-- Hidden channels (realm, private codes)
---------------------------------------------------------------------------
function Net.CodeChannel(code)
    return "FNG" .. code
end

local function ChannelId(name)
    local id = GetChannelName and GetChannelName(name)
    if id and id ~= 0 then return id end
end

-- Keep our channels out of the chat windows.
local function Hide(name)
    if not ChatFrame_RemoveChannel then return end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame then pcall(ChatFrame_RemoveChannel, frame, name) end
    end
end

-- Join a hidden channel. Returns true once it's usable (joining can take a
-- moment the first time).
function Net.JoinChannel(name)
    if ChannelId(name) then return true end
    if JoinTemporaryChannel then JoinTemporaryChannel(name) end
    Hide(name)
    ns.After(1, function() Hide(name) end)
    return ChannelId(name) ~= nil
end

function Net.LeaveChannel(name)
    if ChannelId(name) and LeaveChannelByName then LeaveChannelByName(name) end
end

-- Can a scope be reached right now?
function Net.Route(scope)
    scope = scope or "group"
    if scope == "group" then return Net.Channel() end
    if scope == "guild" then
        if IsInGuild and IsInGuild() then return "GUILD" end
        return nil
    end
    local name = scope == "realm" and Net.REALM_CHANNEL or Net.CodeChannel(scope:match("^code:(.+)$") or "")
    local id = ChannelId(name)
    if id then return "CHANNEL", id end
end

---------------------------------------------------------------------------
-- WoW's limit: each prefix may send a burst of about ten messages, then
-- about one a second, and newer clients DROP what goes over (a lost game
-- update left the other player waiting forever). So we keep to it: what
-- can't go now waits its turn, in order.
---------------------------------------------------------------------------
Net.BURST, Net.PER_SECOND = 10, 1
local buckets = {} -- prefix -> { tokens, t }
local queue = {}   -- prefix -> { { msg, chatType, target, key }, ... }
local draining = {}
local R = Enum and Enum.SendAddonMessageResult
local THROTTLED = { [R and R.AddonMessageThrottle or 3] = true, [R and R.ChannelThrottle or 8] = true }

local function Clock() return GetTime and GetTime() or ns.Now() end

local function Token(prefix)
    local now = Clock()
    local b = buckets[prefix]
    if not b then
        b = { tokens = Net.BURST, t = now }
        buckets[prefix] = b
    end
    b.tokens = math.min(Net.BURST, b.tokens + (now - b.t) * Net.PER_SECOND)
    b.t = now
    if b.tokens < 1 then return false end
    b.tokens = b.tokens - 1
    return true
end

local function Drain(prefix)
    local q = queue[prefix]
    while q[1] and Token(prefix) do
        local m = q[1]
        local r = SendAddon(prefix, m.msg, m.chatType, m.target)
        if ns.debug then
            -- (Retail returns a result: 0 or true is sent, anything else was refused.)
            ns.Print("debug: send " .. m.msg:match("^[^:]*:[^:]*:[^@]*") .. " on " .. m.chatType .. " "
                .. tostring(m.target or "") .. " -> " .. tostring(r) .. (#q > 1 and (", " .. (#q - 1) .. " waiting") or ""))
        end
        if THROTTLED[r] then
            buckets[prefix].tokens = 0 -- WoW says wait: try this one again in a moment
            break
        end
        table.remove(q, 1)
    end
    if q[1] and not draining[prefix] then
        draining[prefix] = true
        ns.After(0.25, function()
            draining[prefix] = nil
            Drain(prefix)
        end)
    end
end

-- How many messages are waiting their turn.
function Net.Waiting()
    local n = 0
    for _, q in pairs(queue) do n = n + #q end
    return n
end

---------------------------------------------------------------------------
-- Sending and receiving
---------------------------------------------------------------------------
-- `key`: a newer message with the same key replaces one still waiting (a
-- game's state: only the latest matters).
local function Queue(prefix)
    local q = queue[prefix]
    if not q then
        q = {}
        queue[prefix] = q
    end
    return q
end

local function SendParts(cmd, data, chatType, target, prefix, key)
    data = data or ""
    if key then
        key = key .. "|" .. chatType .. "|" .. tostring(target)
        for _, q in pairs(queue) do
            for j = #q, 1, -1 do
                if q[j].key == key then table.remove(q, j) end
            end
        end
    end
    nextId = (nextId % 999) + 1
    local me = ns.Me() or ""
    -- (The header: cmd, id up to 3 digits, part/parts up to 3/3, the name.)
    local chunk = MAX - (#cmd + 12 + #me)
    local n = math.max(1, math.ceil(#data / chunk))
    local used = {}
    for i = 1, n do
        local part = data:sub((i - 1) * chunk + 1, i * chunk)
        local p = prefix
        if not p and n > 1 then
            spreadNext = spreadNext % #ALL + 1
            p = ALL[spreadNext]
        end
        p = p or Net.PREFIX
        local q = Queue(p)
        q[#q + 1] = { msg = cmd .. ":" .. nextId .. ":" .. i .. "/" .. n .. "@" .. me .. ":" .. part,
            chatType = chatType, target = target, key = key }
        used[p] = true
    end
    for p in pairs(used) do Drain(p) end
    return true
end

-- `key` (optional): see SendParts.
function Net.Send(cmd, data, scope, key)
    local chatType, target = Net.Route(scope)
    if not (chatType and SendAddon) then return false end
    return SendParts(cmd, data, chatType, target, nil, key)
end

-- To one player, on the fast prefixes (real-time games).
function Net.WhisperFast(cmd, data, target)
    if not SendAddon then return false end
    fastNext = fastNext % #Net.FAST + 1
    return SendParts(cmd, data, "WHISPER", Net.Full(target), Net.FAST[fastNext])
end

-- To a whole scope (the group) on the fast prefixes: one message for everyone.
-- `key` (optional): see SendParts.
function Net.SendFast(cmd, data, scope, key)
    local chatType, target = Net.Route(scope)
    if not (chatType and SendAddon) then return false end
    fastNext = fastNext % #Net.FAST + 1
    return SendParts(cmd, data, chatType, target, Net.FAST[fastNext], key)
end

-- To one player only (private cards; a player talking to a host).
function Net.Whisper(cmd, data, target)
    if not SendAddon then return false end
    return SendParts(cmd, data, "WHISPER", Net.Full(target))
end

-- Is this sender me? Channels can give the name with the realm in other
-- forms ("Name-Realm", "Name Realm"), so compare without them.
function Net.IsMe(sender)
    if not sender then return false end
    if ns.Short(sender) == ns.Me() then return true end
    local name, realm = UnitName("player"), GetRealmName and GetRealmName() or ""
    local s = Squash(sender)
    return s == Squash(name) or s == Squash(name .. realm)
end

function Net.Receive(raw, message)
    if Net.IsMe(raw) then return end
    local cmd, id, i, n, said, data = message:match("^(%w+):(%d+):(%d+)/(%d+)@([^:]*):(.*)$")
    local sender = From(raw, said)
    if ns.debug then
        ns.Print("debug: got " .. tostring(cmd) .. " " .. tostring(i) .. "/" .. tostring(n) .. " from " .. raw
            .. " (says " .. tostring(said) .. ") -> " .. sender)
    end
    if not cmd then return end
    -- Our own message coming back, in a form IsMe didn't know.
    local realm = raw:match("%-(.+)$")
    if sender == ns.Me() and (not realm or MyRealm(realm)) then return end
    address[sender] = raw
    i, n = tonumber(i), tonumber(n)
    if n > 1 then
        local key = raw .. ":" .. id
        local p = partial[key]
        if not p or p.n ~= n then
            p = { n = n, got = 0, parts = {} }
            partial[key] = p
        end
        if not p.parts[i] then
            p.parts[i] = data
            p.got = p.got + 1
        end
        if p.got < n then return end
        partial[key] = nil
        data = table.concat(p.parts)
    end
    local fn = handlers[cmd]
    if fn then fn(sender, data) end
end

ns.On("CHAT_MSG_ADDON", function(prefix, message, _, sender)
    if prefix == Net.PREFIX or FAST[prefix] then Net.Receive(sender, message) end
end)

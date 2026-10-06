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
-- Wire format: "<cmd>:<msgId>:<part>/<parts>:<data>"
local ADDON, ns = ...

local Net = {}
ns.Net = Net

Net.PREFIX = "FunNGames"
Net.REALM_CHANNEL = "FunNGamesRealm"
local CHUNK = 220

local SendAddon = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix

local handlers = {}
local partial = {} -- sender .. msgId -> { parts, got, n }
local nextId = 0

function Net:Init()
    if RegisterPrefix then RegisterPrefix(Net.PREFIX) end
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
-- Sending and receiving
---------------------------------------------------------------------------
local function SendParts(cmd, data, chatType, target)
    data = data or ""
    nextId = (nextId % 999) + 1
    local n = math.max(1, math.ceil(#data / CHUNK))
    for i = 1, n do
        local part = data:sub((i - 1) * CHUNK + 1, i * CHUNK)
        SendAddon(Net.PREFIX, cmd .. ":" .. nextId .. ":" .. i .. "/" .. n .. ":" .. part, chatType, target)
    end
    return true
end

function Net.Send(cmd, data, scope)
    local chatType, target = Net.Route(scope)
    if not (chatType and SendAddon) then return false end
    return SendParts(cmd, data, chatType, target)
end

-- To one player only (private cards; a player talking to a host).
function Net.Whisper(cmd, data, target)
    if not SendAddon then return false end
    return SendParts(cmd, data, "WHISPER", target)
end

function Net.Receive(sender, message)
    sender = ns.Short(sender)
    if sender == ns.Me() then return end
    local cmd, id, i, n, data = message:match("^(%w+):(%d+):(%d+)/(%d+):(.*)$")
    if not cmd then return end
    i, n = tonumber(i), tonumber(n)
    if n > 1 then
        local key = sender .. ":" .. id
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
    if prefix == Net.PREFIX then Net.Receive(sender, message) end
end)

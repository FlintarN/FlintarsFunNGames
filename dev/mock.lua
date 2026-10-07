-- Minimal WoW API mock for Flintar's Fun 'n' Games tests. One copy per simulated
-- player (each runs in its own Lua VM); run.mjs passes addon messages and
-- roll results between them.
local methods = {}
setmetatable(methods, { __index = function(_, k)
    if type(k) == "string" and k:match("^[A-Z]") then return function() end end
end })
local Obj = { __index = methods }
EVENTS = {}
CHAT = {}
TIMERS = {}
CLOCK = 1000

local function new(kind, name, parent)
    local o = setmetatable({ _kind = kind, _scripts = {}, _shown = true, _parent = parent }, Obj)
    if parent and type(parent) == "table" then
        parent._children = parent._children or {}
        table.insert(parent._children, o)
    end
    if name then _G[name] = o end
    return o
end

function methods:SetScript(k, f) self._scripts[k] = f end
function methods:GetScript(k) return self._scripts[k] end
function methods:HookScript(k, f)
    local old = self._scripts[k]
    self._scripts[k] = old and function(...) old(...) f(...) end or f
end
function methods:Show()
    local was = self._shown
    self._shown = true
    if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
end
-- Hiding a frame fires OnHide on it and on its shown children (as WoW does).
local function FireHide(f)
    if f._scripts.OnHide then f._scripts.OnHide(f) end
    for _, c in ipairs(f._children or {}) do
        if c._shown then FireHide(c) end
    end
end
function methods:Hide()
    local was = self._shown
    self._shown = false
    if was then FireHide(self) end
end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self._shown end
function methods:IsVisible() return self._shown end
function methods:SetText(t) self._text = t end
function methods:GetText() return self._text end
function methods:SetChecked(v) self._checked = v end
function methods:GetChecked() return self._checked end
function methods:SetEnabled(v) self._enabled = v and true or false end
function methods:Enable() self._enabled = true end
function methods:Disable() self._enabled = false end
function methods:IsEnabled() return self._enabled ~= false end
function methods:SetTexture(t) self._tex = t return true end
function methods:CreateTexture() return new("Texture", nil, self) end
function methods:CreateFontString() return new("FontString", nil, self) end
function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods:GetWidth() return self._w or 500 end
function methods:GetHeight() return self._h or 400 end
function methods:SetSize(w, h) self._w, self._h = w, h end
function methods:SetWidth(w) self._w = w end
function methods:SetHeight(h) self._h = h end
function methods:GetCenter() return 0, 0 end
function methods:GetEffectiveScale() return 1 end
function methods:SetScale(k) self._scale = k end
-- 3D: model scenes have actors with a bounding box; creatures have a display id.
function methods:CreateActor()
    local a = new("Actor", nil, self)
    function a:GetActiveBoundingBox() return -1, -1, 0, 1, 1, 2 end
    function a:SetPosition(x, y, z) self._pos = { x, y, z } end
    return a
end
function methods:GetDisplayInfo() return 4321 end
function methods:GetScale() return self._scale or 1 end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:RegisterEvent(e)
    EVENTS[e] = EVENTS[e] or {}
    table.insert(EVENTS[e], self)
end
function methods:CreateAnimationGroup()
    local ag = new("AnimationGroup")
    function ag:CreateAnimation() return new("Animation") end
    function ag:Play() self._playing = true end
    function ag:Stop() self._playing = false end
    return ag
end

function Fire(event, ...)
    for _, f in ipairs(EVENTS[event] or {}) do f._scripts.OnEvent(f, event, ...) end
end

-- Run timers that are due by CLOCK (all of them when `all`).
function Advance(seconds)
    CLOCK = CLOCK + (seconds or 0)
    local again = true
    while again do
        again = false
        for i, t in ipairs(TIMERS) do
            if t.at <= CLOCK then
                table.remove(TIMERS, i)
                t.fn()
                again = true
                break
            end
        end
    end
end

CreateFrame = function(kind, name, parent, template)
    local f = new(kind, name, parent)
    if template == "ButtonFrameTemplate" then f.Inset = new("Frame", nil, f) end
    if template == "UIPanelScrollFrameTemplate" then f.ScrollBar = new("Slider", nil, f) end
    return f
end
UIParent = new("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
Minimap = new("Frame", "Minimap")
GameTooltip = new("GameTooltip", "GameTooltip")
GameTooltip_Hide = function() end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(CHAT, m) end }
UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}
StaticPopup_Show = function(name, _, _, data) POPUP = { which = name, data = data } end
StaticPopup_Hide = function() POPUP = nil end
function AnswerPopup() StaticPopupDialogs[POPUP.which].OnAccept(nil, POPUP.data) POPUP = nil end
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
C_Timer = { After = function(d, fn) table.insert(TIMERS, { at = CLOCK + d, fn = fn }) end }
GetTime = function() return CLOCK end
time = function() return math.floor(CLOCK) end
date = os.date
math.atan2 = math.atan2 or math.atan
GetCoinTextureString = function(c)
    local out = {}
    local g, s, k = c // 10000, (c // 100) % 100, c % 100
    if g > 0 then table.insert(out, math.floor(g) .. "g") end
    if s > 0 then table.insert(out, math.floor(s) .. "s") end
    if k > 0 then table.insert(out, math.floor(k) .. "c") end
    return table.concat(out, " ")
end
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"

-- The player and their group.
PLAYER_NAME = PLAYER_NAME or "Flintar"
GROUP = GROUP or {}  -- names of the others in the party
UnitName = function(u) if u == "player" then return PLAYER_NAME end end
IsInRaid = function() return false end
IsInGroup = function() return #GROUP > 0 end
UnitInParty = function(n) for _, g in ipairs(GROUP) do if g == n then return true end end return false end
UnitInRaid = function() return nil end

-- Outgoing traffic, picked up by run.mjs.
OUTBOX = {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel) table.insert(OUTBOX, { "addon", prefix, msg, channel }) end,
}
-- Real rolls: the "server" (run.mjs) decides the number via ROLL_SOURCE.
ROLL_SOURCE = function(lo, hi) return math.random(lo, hi) end
RandomRoll = function(lo, hi)
    table.insert(OUTBOX, { "roll", PLAYER_NAME, ROLL_SOURCE(lo, hi), lo, hi })
end

-- WoW's bit library (Lua 5.1 BitOp), on Lua 5.4 operators.
local function I(x) return math.tointeger(math.floor(x) % 4294967296) end
bit = {
    band = function(a, ...) local r = I(a) for _, b in ipairs({ ... }) do r = r & I(b) end return r end,
    bor = function(a, ...) local r = I(a) for _, b in ipairs({ ... }) do r = r | I(b) end return r end,
    bxor = function(a, ...) local r = I(a) for _, b in ipairs({ ... }) do r = r ~ I(b) end return r end,
    bnot = function(a) return (~I(a)) & 0xFFFFFFFF end,
    rshift = function(a, n) return I(a) >> n end,
    lshift = function(a, n) return (I(a) << n) & 0xFFFFFFFF end,
}
unpack = table.unpack
C_ChatInfo.SendAddonMessage = function(prefix, msg, channel, target)
    table.insert(OUTBOX, { "addon", prefix, msg, channel, target or "" })
end
function methods:GetFrameLevel() return self._level or 1 end
function methods:SetFrameLevel(l) self._level = l end
function methods:GetParent() return self._parent end

-- Trading
TRADE_PARTNER, TRADE_MINE, TRADE_THEIRS = nil, 0, 0
local baseUnitName = UnitName
UnitName = function(u) if u == "NPC" then return TRADE_PARTNER end return baseUnitName(u) end
GetPlayerTradeMoney = function() return TRADE_MINE end
GetTargetTradeMoney = function() return TRADE_THEIRS end
ERR_TRADE_COMPLETE = "Trade complete."
WHISPERS = {}
SendChatMessage = function(msg, channel, _, target) table.insert(WHISPERS, { msg, channel, target }) end

-- Group units and connections: party1..N are the others in GROUP.
OFFLINE = {}
GetNumGroupMembers = function() return #GROUP > 0 and #GROUP + 1 or 0 end
local unitNameBefore = UnitName
UnitName = function(u)
    local i = type(u) == "string" and tonumber(u:match("^party(%d+)$"))
    if i then return GROUP[i] end
    return unitNameBefore(u)
end
UnitIsConnected = function(u) local n = UnitName(u) return n ~= nil and not OFFLINE[n] end

-- Single-player tests: rolls come straight back as system messages.
DIRECT_ROLLS = false
local queuedRoll = RandomRoll
RandomRoll = function(lo, hi)
    if not DIRECT_ROLLS then return queuedRoll(lo, hi) end
    Fire("CHAT_MSG_SYSTEM", PLAYER_NAME .. " rolls " .. ROLL_SOURCE(lo, hi) .. " (" .. lo .. "-" .. hi .. ")")
end
function methods:SetPoint(...) self._point = { ... } end

-- Portraits and classes.
PORTRAITS = {}
SetPortraitTexture = function(tex, unit) tex._portrait = unit table.insert(PORTRAITS, unit) end
UnitExists = function(u) return u == "player" or UnitName(u) ~= nil end
CLASS_ICON_TCOORDS = { WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.5, 0, 0.25 }, SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
    HUNTER = { 0, 0.25, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 }, PRIEST = { 0.5, 0.75, 0.25, 0.5 },
    ROGUE = { 0.5, 0.75, 0, 0.25 } }
UnitClass = function(u) if UnitExists(u) then return "Warrior", "WARRIOR", 1 end end

-- Sounds: count what plays.
SOUNDS = {}
SOUNDKIT = setmetatable({}, { __index = function(_, k) return k end })
PlaySound = function(kit) table.insert(SOUNDS, kit) end

-- Guild and hidden chat channels.
IN_GUILD = false
IsInGuild = function() return IN_GUILD end
CHANNELS, CHANNEL_NAMES, NEXT_CHANNEL = {}, {}, 5
JoinTemporaryChannel = function(name)
    if not CHANNELS[name] then
        CHANNELS[name] = NEXT_CHANNEL
        CHANNEL_NAMES[NEXT_CHANNEL] = name
        NEXT_CHANNEL = NEXT_CHANNEL + 1
    end
end
GetChannelName = function(name) return CHANNELS[name] or 0 end
LeaveChannelByName = function(name)
    local id = CHANNELS[name]
    if id then CHANNEL_NAMES[id] = nil end
    CHANNELS[name] = nil
end
C_ChatInfo.SendAddonMessage = function(prefix, msg, channel, target)
    if channel == "CHANNEL" then target = CHANNEL_NAMES[target] end
    table.insert(OUTBOX, { "addon", prefix, msg, channel, target or "" })
end

-- Mouse and combat
MOUSE_DOWN = false
IsMouseButtonDown = function() return MOUSE_DOWN end
InCombatLockdown = function() return false end
CURSOR_X, CURSOR_Y = 0, 0
GetCursorPosition = function() return CURSOR_X, CURSOR_Y end

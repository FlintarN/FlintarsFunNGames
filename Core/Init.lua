-- Flintar's Fun 'n' Games: casino and arcade games for your group, guild or realm, in one window.
--
-- Init owns the namespace, the event bus, saved variables, small helpers and
-- the slash command. Everything else hangs off `ns`.
local ADDON, ns = ...

ns.TITLE = "Flintar's Fun 'n' Games"
ns.ICON = "Interface\\Icons\\INV_Misc_Dice_01"

-- The games (Games\*.lua fill ns.Games), in the order the window shows them.
ns.Games = {}
ns.GAME_ORDER = { "deathroll", "highlow", "poker", "blackjack", "slots", "roulette", "raffle", "tictactoe", "battleship", "agario", "snake", "g2048", "mines", "tetris", "flappy", "wordle", "shooter", "candycrush", "angrybirds", "hearthstone", "warcraft" }
ns.CustomPages = {} -- games with their own page (UI\PokerPage.lua)

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Flintar's Fun 'n' Games:|r " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Game events: several handlers per event
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(...) end
end)

---------------------------------------------------------------------------
-- Change bus: anything that alters a game or the stats calls ns.Changed();
-- the window redraws once, a moment later.
---------------------------------------------------------------------------
local listeners = {}
local pending = false

function ns.OnChange(fn)
    table.insert(listeners, fn)
end

local function FireChange()
    pending = false
    for _, fn in ipairs(listeners) do fn() end
end

function ns.Changed()
    if pending then return end
    pending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, FireChange)
    else
        FireChange()
    end
end

function ns.After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- Names without the realm, so "Bob-Realm" from a roll and "Bob" from the
-- group roster are the same player.
function ns.Short(name)
    if not name then return nil end
    return (name:gsub("%-.*$", ""))
end

function ns.Me()
    return ns.Short(UnitName("player"))
end

-- Money is always copper. Shown with the game's coin icons: 1g 20s 5c.
local CoinString = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString

-- "1g 20s 5c" as plain text (for chat, where icons can't go).
function ns.MoneyPlain(c)
    c = math.floor(tonumber(c) or 0)
    if c <= 0 then return "0" end
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then table.insert(out, g .. "g") end
    if s > 0 then table.insert(out, s .. "s") end
    if k > 0 then table.insert(out, k .. "c") end
    return table.concat(out, " ")
end

function ns.Money(c)
    c = math.floor(tonumber(c) or 0)
    if c <= 0 then return "0" end
    if CoinString then return CoinString(c) end
    return ns.MoneyPlain(c)
end

function ns.Signed(c)
    c = math.floor(tonumber(c) or 0)
    if c > 0 then return "|cff40ff40+|r" .. ns.Money(c) end
    if c < 0 then return "|cffff5050-|r" .. ns.Money(-c) end
    return "|cffcccccc0|r"
end

function ns.Now()
    return time and time() or 0
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local DEFAULTS = {
    popup = true,         -- open the window when someone starts a game
    turnPopup = true,     -- open the window when it's your turn
    sound = true,         -- every sound the addon makes
    alertSound = true,    -- your-turn and disconnect alerts
    minimap = true,
    realmLobbies = true,  -- join the hidden realm channel for Arcade lobbies
    scale = 1,
    minimapAngle = 200,
    settings = {},
    history = {},
    recorded = {},
    active = {},
}

local function ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
                ApplyDefaults(db[k], v)
            else
                db[k] = v
            end
        elseif type(v) == "table" and type(db[k]) == "table" then
            ApplyDefaults(db[k], v)
        end
    end
end

-- Settings tab, "Reset all": everything back to a fresh install, except
-- games in progress.
function ns.ResetAll()
    local db = ns.db
    local active = db.active
    wipe(db)
    db.v3 = true
    ApplyDefaults(db, DEFAULTS)
    db.active = active or {}
    ns.Minimap:SetShown(true)
    ns.UI:ApplyScale()
    ns.UI:ResetPosition()
end

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    FlintarsFunNGamesDB = FlintarsFunNGamesDB or {}
    -- v0.1 kept its data in a different shape; v0.3 moved money from gold to
    -- copper. Start clean either way.
    if not FlintarsFunNGamesDB.v3 then
        wipe(FlintarsFunNGamesDB)
        FlintarsFunNGamesDB.v3 = true
    end
    ApplyDefaults(FlintarsFunNGamesDB, DEFAULTS)
    ns.db = FlintarsFunNGamesDB

    ns.Net:Init()
    ns.Session:Restore()
    ns.Minimap:Build()
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local HELP = {
    "/fng - open or close the window",
    "/fng popup - turn the automatic pop-up on or off",
    "/fng reset - move the window back to the middle of the screen",
    "/fng mute - turn the addon's sounds off or on",
    "/fng debug - print what the addon reads from roll messages",
    "/fng dc <bot> - practice: make a bot go offline, or come back",
}

SLASH_FUNNGAMES1 = "/fng"
SLASH_FUNNGAMES2 = "/funngames"
SLASH_FUNNGAMES3 = "/fng"
SlashCmdList.FUNNGAMES = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "" then
        ns.UI:Toggle()
    elseif cmd == "popup" then
        ns.db.popup = not ns.db.popup
        ns.Print("Pop-up when someone starts a game: " .. (ns.db.popup and "on" or "off"))
    elseif cmd:match("^dc ") then
        local name = strtrim(msg):sub(4)
        name = name:sub(1, 1):upper() .. name:sub(2):lower()
        local ok, state = ns.Session.ToggleBot(name)
        ns.Print(ok and (name .. " is " .. state .. ".") or ("No practice bot called " .. name .. "."))
    elseif cmd == "debug" then
        ns.debug = not ns.debug
        ns.Print("Debug: " .. (ns.debug and "on (roll messages are printed in chat)" or "off"))
    elseif cmd == "mute" then
        ns.db.sound = ns.db.sound == false
        ns.Print("Sounds: " .. (ns.db.sound and "on" or "off") .. " (more options on the Settings tab)")
        ns.Changed()
    elseif cmd == "reset" then
        ns.db.windowPos = nil
        ns.UI:ResetPosition()
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
end

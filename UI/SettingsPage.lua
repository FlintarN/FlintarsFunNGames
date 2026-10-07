-- Settings tab: sound and window options on the left, your saved data on
-- the right (each clear asks first), and an About line at the bottom.
local ADDON, ns = ...

local W = ns.Widgets
local P = {}
ns.SettingsPage = P

local SCALES = { 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3 }

-- A checkbox with a label; get() reads the setting, set(v) writes it.
local function Check(parent, y, label, help, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", 12, y)
    cb.label = W.Label(parent, label, "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ns.Changed()
    end)
    W.Tooltip(cb, label, help)
    cb.get = get
    return cb
end

-- A "clear" row: what it is, how much there is, and the button.
local function DataRow(parent, y, label, button, confirm, count, run)
    local l = W.Label(parent, label, "GameFontHighlight")
    l:SetPoint("TOPLEFT", 14, y)
    local c = W.Label(parent, "", "GameFontDisableSmall")
    c:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
    local b = W.Button(parent, button, 96, function()
        W.Confirm(confirm, function()
            run()
            ns.Changed()
        end)
    end, 22)
    b:SetPoint("TOPRIGHT", -12, y + 3)
    return { count = c, button = b, get = count }
end

function P:Build(page)
    -- Sound and window
    local left = W.Panel(page, "Sound and window")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT", 0, 40)
    left:SetWidth(262)
    local db = function() return ns.db end
    self.checks = {
        Check(left, -32, "Game sounds", "Everything inside the games: dice, cards, coins, reels, and Warcraft III's "
            .. "voices, battles, spells and warnings.",
            function() return db().sound ~= false end, function(v) db().sound = v end),
        Check(left, -58, "Alerts", "When it's your turn, and when a player disconnects. Works even with Game sounds off.",
            function() return db().alertSound ~= false end, function(v) db().alertSound = v end),
        Check(left, -84, "Pop up when a game starts", "Open the window when someone in your group starts a game.",
            function() return db().popup ~= false end, function(v) db().popup = v end),
        Check(left, -110, "Open the window on your turn", "If the window is closed when it's your turn, open it.",
            function() return db().turnPopup ~= false end, function(v) db().turnPopup = v end),
        Check(left, -136, "Minimap button", "The dice on the edge of the minimap.",
            function() return db().minimap ~= false end, function(v)
                db().minimap = v
                ns.Minimap:SetShown(v)
            end),
        Check(left, -162, "Realm lobbies (Arcade)", "Join a hidden realm channel so you can see and host Arcade lobbies "
            .. "open to the whole realm. It never shows in your chat.",
            function() return db().realmLobbies ~= false end, function(v)
                db().realmLobbies = v
                if not v then ns.Net.LeaveChannel(ns.Net.REALM_CHANNEL) end
            end),
    }

    local sizeLabel = W.Label(left, "Window size", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", 16, -200)
    self.sizeText = W.Label(left, "", "GameFontNormal")
    self.sizeText:SetPoint("LEFT", sizeLabel, "RIGHT", 60, 0)
    local function Step(dir)
        local cur = ns.db.scale or 1
        local i = 4
        for k, v in ipairs(SCALES) do
            if math.abs(v - cur) < 0.01 then i = k end
        end
        i = math.max(1, math.min(#SCALES, i + dir))
        ns.db.scale = SCALES[i]
        ns.UI:ApplyScale()
        ns.Changed()
    end
    self.smaller = W.Button(left, "-", 26, function() Step(-1) end, 22)
    self.smaller:SetPoint("RIGHT", self.sizeText, "LEFT", -6, 0)
    self.bigger = W.Button(left, "+", 26, function() Step(1) end, 22)
    self.bigger:SetPoint("LEFT", self.sizeText, "RIGHT", 6, 0)

    -- Your data
    local right = W.Panel(page, "Your data")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 40)
    self.rows = {
        DataRow(right, -32, "Statistics", "Clear", "Clear all your statistics (game history)? This cannot be undone.",
            function()
                local n = #ns.db.history
                return n .. (n == 1 and " game recorded" or " games recorded")
            end,
            function() ns.Stats:Reset() end),
        DataRow(right, -72, "Settle up", "Clear", "Forget who owes whom? This cannot be undone.",
            function()
                local n = #ns.Tab.List()
                return n == 0 and "All square" or (n .. (n == 1 and " open balance" or " open balances"))
            end,
            function() ns.Tab.Reset() end),
        DataRow(right, -112, "Game settings", "Reset", "Forget the bets, chip values and caps each game remembers?",
            function()
                local n = 0
                for _ in pairs(ns.db.settings) do n = n + 1 end
                return n == 0 and "Nothing saved" or (n .. (n == 1 and " game remembered" or " games remembered"))
            end,
            function() wipe(ns.db.settings) end),
        DataRow(right, -152, "Window position", "Reset", "Move the window back to the middle of the screen?",
            function() return ns.db.windowPos and "Moved" or "In the middle" end,
            function()
                ns.db.windowPos = nil
                ns.UI:ResetPosition()
            end),
        DataRow(right, -192, "Everything", "Reset all", "Reset EVERYTHING: statistics, Settle up, game settings and "
            .. "these settings, as if freshly installed? Games in progress are not touched.",
            function() return "Back to a fresh install" end,
            function() ns.ResetAll() end),
    }

    local about = W.Label(page, "", "GameFontDisableSmall")
    about:SetPoint("BOTTOMLEFT", 4, 20)
    about:SetPoint("RIGHT", -4, 0)
    about:SetJustifyH("LEFT")
    local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata or function() end)(ADDON, "Version")
    about:SetText(ns.TITLE .. (version and (" " .. version) or "") .. " by FlintarN.   "
        .. "/fng opens the window (/gamble works too), /fng help lists the commands.")
end

function P:Refresh()
    for _, cb in ipairs(self.checks) do cb:SetChecked(cb.get()) end
    self.sizeText:SetText(math.floor((ns.db.scale or 1) * 100 + 0.5) .. "%")
    self.smaller:SetEnabled((ns.db.scale or 1) > SCALES[1] + 0.01)
    self.bigger:SetEnabled((ns.db.scale or 1) < SCALES[#SCALES] - 0.01)
    for _, row in ipairs(self.rows) do row.count:SetText(row.get()) end
    self.rows[1].button:SetEnabled(#ns.db.history > 0)
    self.rows[2].button:SetEnabled(#ns.Tab.List() > 0 or #ns.Tab.Log() > 0)
    self.rows[3].button:SetEnabled(next(ns.db.settings) ~= nil)
    self.rows[4].button:SetEnabled(ns.db.windowPos ~= nil)
end

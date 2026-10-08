-- Arcade: the setup panel every Arcade game shares (no money).
--
-- Left: how to play. Right: who can join (Group / Guild / Realm / Private
-- code), Create lobby and Practice, joining by code, and a browser of open
-- guild and realm lobbies for this game.
local ADDON, ns = ...

local W = ns.Widgets
local A = {}
ns.Arcade = A

A.SCOPES = {
    { key = "group", label = "Group", help = "Your party or raid." },
    { key = "guild", label = "Guild", help = "Anyone in your guild, wherever they are. It shows in their lobby list." },
    { key = "realm", label = "Realm", help = "Anyone on the realm with the addon (your faction). It shows in their lobby list." },
    { key = "code", label = "Private code", help = "Only people you give the code to." },
}
local SCOPE_NAME = { group = "Group", guild = "Guild", realm = "Realm", code = "Code" }

local function Session(self) return ns.Session.Get(self.kind) end

-- Is this scope usable right now? (true) or (false, why)
function A.ScopeReady(scope)
    if scope == "group" then
        if ns.Net.Channel() then return true end
        return false, "You're not in a party or raid."
    elseif scope == "guild" then
        if ns.Net.Route("guild") then return true end
        return false, "You're not in a guild."
    elseif scope == "realm" then
        if ns.db.realmLobbies == false then return false, "Realm lobbies are off in Settings." end
        return true
    end
    return true
end

local function LobbyRow(row)
    row.join = W.Button(row, "Join", 50, nil, 18)
    row.join:SetPoint("RIGHT", -2, 0)
    row.info = W.Label(row, "", "GameFontDisableSmall")
    row.info:SetPoint("RIGHT", row.join, "LEFT", -6, 0)
    row.name = W.Label(row, "", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetPoint("RIGHT", row.info, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
end

-- Build on a page object (self.kind, self.G set); fills self.setup.
-- onBack (optional): a Back button at the bottom of the left column (the
-- games with their own main menu: Hearthstone 2, Warcraft 4).
function A.BuildSetup(self, parent, onBack)
    local G = self.G
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.setup = v

    local how = W.Panel(v, "How to play")
    how:SetPoint("TOPLEFT")
    how:SetPoint("BOTTOMLEFT")
    how:SetWidth(232)
    local art = how:CreateTexture(nil, "ARTWORK")
    art:SetSize(56, 56)
    art:SetPoint("TOP", 0, -34)
    art:SetTexture(G.icon)
    art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local name = W.Label(how, G.name, "GameFontNormalLarge")
    name:SetPoint("TOP", art, "BOTTOM", 0, -8)
    local note = W.Label(how, "Arcade games are just for fun: no bets, nothing to pay.", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 14, onBack and 46 or 14)
    note:SetPoint("RIGHT", -14, 0)
    note:SetJustifyH("LEFT")
    if onBack then
        local back = W.Button(how, "Back", 90, onBack, 22)
        back:SetPoint("BOTTOMLEFT", 12, 12)
        self.setupBack = back
    end
    -- The rules fill the space above the note (cut short rather than run over it).
    local rules = W.Label(how, G.rules, "GameFontHighlight")
    rules:SetPoint("TOPLEFT", 14, -126)
    rules:SetPoint("RIGHT", -14, 0)
    rules:SetPoint("BOTTOM", note, "TOP", 0, 8)
    rules:SetJustifyH("LEFT")
    rules:SetJustifyV("TOP")

    local play = W.Panel(v, "Play")
    play:SetPoint("TOPLEFT", how, "TOPRIGHT", 8, 0)
    play:SetPoint("BOTTOMRIGHT")

    -- Who can join: four radio buttons.
    local who = W.Label(play, "Who can join", "GameFontNormalSmall")
    who:SetPoint("TOPLEFT", 14, -30)
    self.scopeChecks = {}
    for i, sc in ipairs(A.SCOPES) do
        local cb = CreateFrame("CheckButton", nil, play, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", 10 + ((i - 1) % 2) * 140, -44 - math.floor((i - 1) / 2) * 22)
        cb.label = W.Label(play, sc.label, "GameFontHighlight")
        cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        cb.scope = sc.key
        cb:SetScript("OnClick", function()
            ns.db.arcadeScope = sc.key
            if sc.key == "realm" then ns.Net.JoinChannel(ns.Net.REALM_CHANNEL) end
            A.RefreshSetup(self)
        end)
        W.Tooltip(cb, sc.label, function()
            local ok, why = A.ScopeReady(sc.key)
            return ok and sc.help or ("|cffff6060" .. why .. "|r")
        end)
        self.scopeChecks[i] = cb
    end

    self.createButton = W.Button(play, "Create lobby", 130, function() A.Open(self, false) end, 24)
    self.createButton:SetPoint("TOPLEFT", 12, -96)
    self.practiceButton = W.Button(play, "Practice vs bot", 130, function() A.Open(self, true) end, 24)
    self.practiceButton:SetPoint("LEFT", self.createButton, "RIGHT", 6, 0)
    W.Tooltip(self.practiceButton, "Practice vs bot", "Play a bot, just you.")

    -- Join by code.
    local codeLabel = W.Label(play, "Have a code?", "GameFontNormalSmall")
    codeLabel:SetPoint("TOPLEFT", 14, -132)
    local box = CreateFrame("EditBox", nil, play, "InputBoxTemplate")
    box:SetSize(80, 20)
    box:SetPoint("LEFT", codeLabel, "RIGHT", 12, 0)
    box:SetAutoFocus(false)
    if box.SetMaxLetters then box:SetMaxLetters(6) end
    box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(b)
        b:ClearFocus()
        A.JoinCode(self)
    end)
    self.codeBox = box
    local joinCode = W.Button(play, "Join", 56, function() A.JoinCode(self) end, 20)
    joinCode:SetPoint("LEFT", box, "RIGHT", 6, 0)
    W.Tooltip(joinCode, "Join with a code", "Type the code the host gave you.")

    self.setupHint = W.Label(play, "", "GameFontHighlightSmall")
    self.setupHint:SetPoint("TOPLEFT", 14, -156)
    self.setupHint:SetPoint("RIGHT", -12, 0)
    self.setupHint:SetJustifyH("LEFT")

    -- Open lobbies (guild and realm).
    local lobbies = W.Label(play, "Open lobbies", "GameFontNormal")
    lobbies:SetPoint("TOPLEFT", 14, -182)
    local line = W.Divider(play)
    line:SetPoint("TOPLEFT", 10, -198)
    line:SetPoint("TOPRIGHT", -10, -198)
    self.lobbyList = W.ScrollList(play, 22, LobbyRow)
    self.lobbyList:Inset(8, -202, 8, 8)
    self.lobbyEmpty = W.Label(play, "No open lobbies right now.", "GameFontDisable")
    self.lobbyEmpty:SetPoint("TOP", 0, -230)
end

function A.Open(self, test)
    local scope = ns.db.arcadeScope or "group"
    local ok, why = A.ScopeReady(scope)
    if not test and not ok then
        self.setupHint:SetText("|cffff6060" .. why .. "|r")
        return
    end
    local done, err = ns.Session.Open(self.kind, {}, test, scope)
    if done then
        W.PlaySound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    else
        self.setupHint:SetText("|cffff6060" .. tostring(err) .. "|r")
    end
end

function A.JoinCode(self)
    local ok, why = ns.Session.JoinCode(self.codeBox:GetText())
    self.setupHint:SetText(ok and "Looking for that lobby..." or ("|cffff6060" .. why .. "|r"))
end

function A.RefreshSetup(self)
    -- Realm lobbies need the hidden realm channel.
    if ns.db.realmLobbies ~= false then ns.Net.JoinChannel(ns.Net.REALM_CHANNEL) end
    local chosen = ns.db.arcadeScope or "group"
    for _, cb in ipairs(self.scopeChecks) do
        cb:SetChecked(cb.scope == chosen)
        local ok = A.ScopeReady(cb.scope)
        cb.label:SetTextColor(ok and 1 or 0.5, ok and 1 or 0.5, ok and 1 or 0.5)
    end
    local ok, why = A.ScopeReady(chosen)
    self.createButton:SetEnabled(ok)
    if not ok then self.setupHint:SetText("|cffaaaaaa" .. why .. "|r") end

    local list = ns.Session.Lobbies(self.kind)
    for i, s in ipairs(list) do
        local row = self.lobbyList:Row(i)
        row.name:SetText(s.host .. "'s lobby")
        row.info:SetText(SCOPE_NAME[s.scope or "group"] .. "  " .. #s.players .. "/" .. (self.G.maxPlayers or "?"))
        row.join:SetScript("OnClick", function() ns.Session.JoinLobby(s.id) end)
        row.join:SetEnabled(#s.players < (self.G.maxPlayers or 99))
    end
    self.lobbyList:SetCount(#list)
    self.lobbyEmpty:SetShown(#list == 0)
end

-- The host ends the lobby for everyone, also after a finished game.
function A.CloseLobby(self)
    local S = ns.Session
    local s = Session(self)
    if not (s and S.IsHost(s)) then return end
    if S.IsActive(s) then
        S.Cancel(self.kind)
    else
        s.phase = "cancelled"
        s.banner = "The lobby is closed."
        S.Update(s)
    end
    S.Dismiss(self.kind)
end

-- A line for a running lobby: where it's open, and the code if private.
function A.ScopeLine(s)
    if s.test then return "Practice" end
    if s.scope == "code" then return "Private lobby. Code: |cffffd100" .. tostring(s.code) .. "|r (share it with friends)" end
    return "Open to: " .. SCOPE_NAME[s.scope or "group"]
end

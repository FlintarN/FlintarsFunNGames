-- GamePage: one tab per game, built from the game's rules module.
--
-- No game: "How to play" and a "New game" panel (group game or practice).
-- A game: the players on the left, the card table on the right (dice, the
-- roll range, what just happened, recent rolls) and the buttons below.
--
-- The dice tumble and the spinning number are only a show: the number it
-- lands on is the one from the game's roll message.
local ADDON, ns = ...

local W = ns.Widgets
local Page = {}
Page.__index = Page
ns.GamePage = Page

local ROW_H = 22
local DICE = "Interface\\Icons\\INV_Misc_Dice_02"
local ICON_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ICON_WAIT = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local ICON_LOST = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local ICON_WON = "Interface\\Icons\\INV_Misc_Coin_01"
local CROWN = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12:0:0|t"

local function Now()
    return GetTime and GetTime() or 0
end

local function Session(self)
    return ns.Session.Get(self.kind)
end

---------------------------------------------------------------------------
-- Setup view
---------------------------------------------------------------------------
function Page:BuildSetup(parent)
    local G = self.G
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.setup = v

    local how = W.Panel(v, "How to play")
    how:SetPoint("TOPLEFT")
    how:SetPoint("BOTTOMLEFT")
    how:SetWidth(262)

    local art = how:CreateTexture(nil, "ARTWORK")
    art:SetSize(64, 64)
    art:SetPoint("TOP", 0, -38)
    art:SetTexture(G.icon)
    art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local frame = how:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame:SetPoint("TOPLEFT", art, -3, 3)
    frame:SetPoint("BOTTOMRIGHT", art, 3, -3)
    frame:SetColorTexture(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 1)

    local name = W.Label(how, G.name, "GameFontNormalLarge")
    name:SetPoint("TOP", art, "BOTTOM", 0, -10)

    local rules = W.Label(how, G.rules, "GameFontHighlight")
    rules:SetPoint("TOPLEFT", 16, -150)
    rules:SetPoint("RIGHT", -16, 0)
    rules:SetJustifyH("LEFT")
    rules:SetSpacing(3)

    local fair = W.Label(how, G.fairness or ("Every roll is a real /roll that the whole group sees. "
        .. "A check mark next to a roll means your own game client saw it too."), "GameFontDisableSmall")
    fair:SetPoint("BOTTOMLEFT", 16, 16)
    fair:SetPoint("RIGHT", -16, 0)
    fair:SetJustifyH("LEFT")

    local new = W.Panel(v, "New game")
    new:SetPoint("TOPLEFT", how, "TOPRIGHT", 8, 0)
    new:SetPoint("BOTTOMRIGHT")

    self.fields = {}
    local saved = ns.db.settings[self.kind] or {}
    ns.db.settings[self.kind] = saved
    for i, field in ipairs(G.fields) do
        local box
        if field.money then
            box = W.MoneyBox(new, field.label)
            box:SetPoint("TOPLEFT", 14, -56 - (i - 1) * 48)
            box:SetCopper(saved[field.key] or field.default)
        else
            box = W.NumberBox(new, field.label, 100)
            box:SetPoint("TOPLEFT", 24, -56 - (i - 1) * 48)
            box:SetText(tostring(saved[field.key] or field.default))
        end
        box.field = field
        table.insert(self.fields, box)
    end

    local y = -56 - #G.fields * 48 - 6
    self.groupButton = W.Button(new, "Start a group game", 200, function() self:Open(false) end, 26)
    self.groupButton:SetPoint("TOPLEFT", 20, y)
    W.Tooltip(self.groupButton, "Start a group game",
        "Opens the game for your party or raid. Everyone with Flintar's Fun 'n' Games gets a window to join.")

    self.practiceButton = W.Button(new, "Practice with bots", 200, function() self:Open(true) end, 26)
    self.practiceButton:SetPoint("TOPLEFT", self.groupButton, "BOTTOMLEFT", 0, -8)
    W.Tooltip(self.practiceButton, "Practice with bots",
        "Play alone against bots who join and roll by themselves. Your own rolls are real /rolls. "
        .. "No gold, nothing is sent to anyone, and nothing goes into your stats.")

    self.setupHint = W.Label(new, "", "GameFontHighlightSmall")
    self.setupHint:SetPoint("TOPLEFT", self.practiceButton, "BOTTOMLEFT", 0, -14)
    self.setupHint:SetPoint("RIGHT", -16, 0)
    self.setupHint:SetJustifyH("LEFT")
end

-- What this game remembers between tables. Looked up each time: Settings
-- can wipe it (Reset game settings / Reset all).
function Page:Saved()
    local saved = ns.db.settings[self.kind]
    if not saved then
        saved = {}
        ns.db.settings[self.kind] = saved
    end
    return saved
end

function Page:Settings()
    local out, saved = {}, self:Saved()
    for _, box in ipairs(self.fields) do
        local f = box.field
        local n = f.money and box:GetCopper() or math.floor(box:GetNumberOr(f.default))
        n = math.max(f.min, math.min(f.max, n))
        if f.money then box:SetCopper(n) else box:SetText(tostring(n)) end
        out[f.key] = n
        saved[f.key] = n
    end
    return out
end

function Page:Open(test)
    for _, box in ipairs(self.fields) do box:ClearFocus() end
    local ok, why = ns.Session.Open(self.kind, self:Settings(), test)
    if ok then
        W.PlaySound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    else
        self.setupHint:SetText("|cffff6060" .. why .. "|r")
    end
end

---------------------------------------------------------------------------
-- Game view: players
---------------------------------------------------------------------------
local function BuildPlayerRow(row)
    row.status = row:CreateTexture(nil, "ARTWORK")
    row.status:SetSize(16, 16)
    row.status:SetPoint("LEFT", 4, 0)
    row.name = W.Label(row, "", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.status, "RIGHT", 4, 0)
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(14, 14)
    row.check:SetPoint("RIGHT", -4, 0)
    row.roll = W.Label(row, "", "GameFontNormal")
    row.roll:SetPoint("RIGHT", row.check, "LEFT", -4, 0)
    row.skip = W.SkipButton(row)
    row.skip:SetPoint("RIGHT", -2, 0)
    -- The name gets everything left of the roll.
    row.name:SetPoint("RIGHT", row.roll, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(s)
        if not s.tip then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.tip[1], 1, 0.82, 0)
        GameTooltip:AddLine(s.tip[2], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

-- Did this client see the player's last roll in chat?
local function Verified(s, name)
    for i = #s.log, 1, -1 do
        local e = s.log[i]
        if e.name == name then return ns.Rolls.Saw(e.name, e.roll, e.lo, e.hi) end
    end
    return nil
end

function Page:RefreshPlayers(s)
    local G, me = self.G, ns.Me()
    for i, p in ipairs(s.players) do
        local row = self.list:Row(i)
        local name = p.name
        if p.name == me then name = "|cffffd100" .. name .. "|r" end
        if p.name == s.host then name = name .. " " .. CROWN end
        if p.bot then name = name .. " |cff888888(bot)|r" end
        name = name .. W.PlayerTag(p)
        row.name:SetText(name)
        row.roll:SetText(G:RollText(s, p))

        local r = s.result
        if r and r.payee == p.name then
            row.status:SetTexture(ICON_WON)
            row.status:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        elseif r and r.payer == p.name then
            row.status:SetTexture(ICON_LOST)
            row.status:SetTexCoord(0, 1, 0, 1)
        elseif G:Expect(s, p.name) then
            row.status:SetTexture(ICON_WAIT)
            row.status:SetTexCoord(0, 1, 0, 1)
        else
            row.status:SetTexture(nil)
        end

        row.tip = nil
        row.check:SetTexture(nil)
        if p.roll or p.tb then
            local seen = Verified(s, p.name)
            if seen then
                row.check:SetTexture(ICON_READY)
                row.tip = { p.name, "Your game client saw this roll in chat." }
            elseif seen == false then
                row.check:SetTexture(ICON_WAIT)
                row.tip = { p.name, "Your game client has not seen this roll yet. "
                    .. "If it never shows up, the host's number did not come from a real /roll." }
            end
        end
    end
    -- Host: Skip for anyone the game is stuck on.
    for i, p in ipairs(s.players) do
        local row = self.list:Row(i)
        local can = W.UpdateSkip(row.skip, self.kind, s, p.name)
        row.roll:SetShown(not can)
        row.check:SetShown(not can)
    end
    self.list:SetCount(#s.players)
    self.playersPanel.title:SetText("Players (" .. #s.players .. ")")
end

---------------------------------------------------------------------------
-- Game view: the card table
---------------------------------------------------------------------------
function Page:BuildTable(v)
    local t = W.Panel(v)
    t:SetPoint("TOPLEFT", self.playersPanel, "TOPRIGHT", 8, 0)
    t:SetPoint("BOTTOMRIGHT", 0, 34)
    -- Green felt over the marble, so the table reads as a card table.
    local felt = t:CreateTexture(nil, "BORDER", nil, 2)
    felt:SetPoint("TOPLEFT", 3, -3)
    felt:SetPoint("BOTTOMRIGHT", -3, 3)
    felt:SetColorTexture(0.09, 0.36, 0.19, 0.8)
    self.tablePanel = t

    self.status = W.Label(t, "", "GameFontNormalLarge")
    self.status:SetPoint("TOP", 0, -14)

    -- The die: a framed icon that tumbles when someone rolls.
    local die = CreateFrame("Frame", nil, t)
    die:SetSize(52, 52)
    die:SetPoint("TOP", 0, -40)
    local dieBorder = die:CreateTexture(nil, "BACKGROUND")
    dieBorder:SetPoint("TOPLEFT", -2, 2)
    dieBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    dieBorder:SetColorTexture(0, 0, 0, 0.8)
    die.tex = die:CreateTexture(nil, "ARTWORK")
    die.tex:SetAllPoints()
    die.tex:SetTexture(DICE)
    die.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.die = die
    -- Animate the texture, not the frame: newer clients only rotate textures.
    if die.tex.CreateAnimationGroup then
        local ag = die.tex:CreateAnimationGroup()
        local spin = ag:CreateAnimation("Rotation")
        spin:SetDegrees(-720)
        spin:SetDuration(0.7)
        if spin.SetSmoothing then spin:SetSmoothing("OUT") end
        local grow = ag:CreateAnimation("Scale")
        if grow.SetScaleFrom then
            grow:SetScaleFrom(1, 1)
            grow:SetScaleTo(1.35, 1.35)
        elseif grow.SetScale then
            grow:SetScale(1.35, 1.35)
        end
        grow:SetDuration(0.35)
        grow:SetOrder(1)
        local shrink = ag:CreateAnimation("Scale")
        if shrink.SetScaleFrom then
            shrink:SetScaleFrom(1.35, 1.35)
            shrink:SetScaleTo(1, 1)
        elseif shrink.SetScale then
            shrink:SetScale(1 / 1.35, 1 / 1.35)
        end
        shrink:SetDuration(0.35)
        shrink:SetOrder(2)
        self.tumble = ag
    end

    self.number = W.BigLabel(t, 40)
    self.number:SetPoint("TOP", die, "BOTTOM", 0, -12)
    self.caption = W.Label(t, "", "GameFontHighlightSmall")
    self.caption:SetPoint("TOP", self.number, "BOTTOM", 0, -4)
    self.caption:SetTextColor(0.85, 0.85, 0.85)

    self.banner = W.Label(t, "", "GameFontHighlight")
    self.banner:SetPoint("TOP", self.caption, "BOTTOM", 0, -12)
    self.banner:SetPoint("LEFT", 14, 0)
    self.banner:SetPoint("RIGHT", -14, 0)

    self.result = W.Label(t, "", "GameFontNormalLarge")
    self.result:SetPoint("TOP", self.banner, "BOTTOM", 0, -10)
    self.result:SetPoint("LEFT", 14, 0)
    self.result:SetPoint("RIGHT", -14, 0)

    local logTitle = W.Label(t, "Recent rolls", "GameFontNormalSmall")
    logTitle:SetPoint("BOTTOMLEFT", 14, 82)
    local line = W.Divider(t)
    line:SetPoint("TOPLEFT", logTitle, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", -14, 0)
    self.logLines = {}
    for i = 1, 5 do
        local fs = W.Label(t, "", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", logTitle, "BOTTOMLEFT", 0, -6 - (i - 1) * 13)
        fs:SetPoint("RIGHT", -14, 0)
        fs:SetJustifyH("LEFT")
        self.logLines[i] = fs
    end

    -- Spins the number while the die tumbles.
    t:SetScript("OnUpdate", function() self:TickSpin() end)
end

-- Start the show: the die tumbles, the number spins through lo..hi, then
-- lands on `final` (or keeps spinning until it is known).
function Page:Spin(lo, hi, final, caption)
    self.spin = { lo = lo, hi = math.max(lo, hi), final = final, ends = Now() + 0.75, next = 0, caption = caption }
    if self.tumble then
        self.tumble:Stop()
        self.tumble:Play()
    end
    self.caption:SetText(caption or "")
end

function Page:TickSpin()
    local sp = self.spin
    if not sp then return end
    local t = Now()
    if sp.final and t >= sp.ends then
        self.spin = nil
        self.number:SetText(tostring(sp.final))
        self.number:SetTextColor(1, 1, 1)
        self.shown = { untilT = t + 2.5 }
        W.PlaySound("LOOTWINDOW_COIN_SOUND")
        ns.After(2.6, function() ns.Changed() end)
        return
    end
    if not sp.final and t >= sp.ends + 3 then
        self.spin = nil -- the roll never came (wrong range, lag): give up
        ns.Changed()
        return
    end
    if t >= sp.next then
        sp.next = t + 0.05
        self.number:SetText(tostring(math.random(sp.lo, sp.hi)))
        self.number:SetTextColor(1, 0.82, 0)
    end
end

function Page:FlashRoll() end

function Page:RefreshTable(s)
    local G = self.G
    self.status:SetText(G:Status(s) or "")

    -- A new roll in the log: play it out.
    local last = s.log[#s.log]
    local key = last and (s.id .. ":" .. (last.n or #s.log))
    if key and key ~= self.lastRollKey then
        local first = self.lastRollKey == nil and self.lastId ~= s.id
        self.lastRollKey = key
        if not first then
            local caption = last.name .. " rolled" .. (last.tb and " (tiebreaker)" or "")
            if self.spin and not self.spin.final and last.name == ns.Me() then
                self.spin.final = last.roll
                self.spin.caption = caption
                self.caption:SetText(caption)
            else
                self:Spin(last.lo, last.hi, last.roll, caption)
            end
        end
    end
    self.lastId = s.id

    if not self.spin and not (self.shown and Now() < self.shown.untilT) then
        local range = G:RangeText(s)
        if s.phase == "done" and s.result then
            self.number:SetText(last and tostring(last.roll) or "")
            self.caption:SetText(last and (last.name .. " rolled") or "")
        elseif range then
            self.number:SetText(range)
            self.caption:SetText("roll range")
        else
            self.number:SetText("")
            self.caption:SetText("")
        end
        self.number:SetTextColor(1, 1, 1)
    end

    self.banner:SetText(s.banner or "")

    local r, me = s.result, ns.Me()
    if s.phase == "done" and r then
        local text = r.payer .. " pays " .. r.payee .. " " .. ns.Money(r.amount)
        if r.payee == me then
            text = "|cff40ff40You win!|r " .. r.payer .. " pays you " .. ns.Money(r.amount)
        elseif r.payer == me then
            text = "|cffff5050You lose.|r Pay " .. r.payee .. " " .. ns.Money(r.amount)
        end
        if s.test then text = text .. "\n|cff888888(practice: no gold changes hands)|r" end
        self.result:SetText(text)
    elseif s.phase == "cancelled" then
        self.result:SetText("|cffaaaaaaGame cancelled|r")
    else
        self.result:SetText("")
    end

    for i = 1, #self.logLines do
        local e = s.log[#s.log - i + 1]
        if e then
            local seen = ns.Rolls.Saw(e.name, e.roll, e.lo, e.hi)
            local mark = seen and "|TInterface\\RaidFrame\\ReadyCheck-Ready:10:10|t " or "   "
            self.logLines[i]:SetText(mark .. e.name .. " rolled |cffffffff" .. e.roll .. "|r (" .. e.lo .. "-" .. e.hi .. ")"
                .. (e.tb and " |cffaaaaaatiebreaker|r" or ""))
        else
            self.logLines[i]:SetText("")
        end
    end
end

---------------------------------------------------------------------------
-- Game view: buttons
---------------------------------------------------------------------------
function Page:BuildButtons(v)
    local kind = self.kind
    local S = ns.Session
    self.buttons = {}
    local function Add(key, text, w, onClick, title, help)
        local b = W.Button(v, text, w, onClick, 26)
        if title then W.Tooltip(b, title, help) end
        self.buttons[key] = b
        return b
    end
    Add("join", "Join", 90, function() S.Join(kind) end,
        "Join", "Take a seat in this game.")
    Add("leave", "Leave", 90, function() S.Leave(kind) end,
        "Leave", "Get up before the game starts.")
    Add("bot", "+ Bot", 80, function() S.AddBot(kind) end,
        "Add a bot", "A fake player that joins and rolls by itself (practice only).")
    Add("start", "Start", 100, function()
        local ok, why = S.Start(kind)
        if not ok and why then self.hint:SetText("|cffff6060" .. why .. "|r") end
    end, "Start", "Close the seats and start rolling.")
    Add("cancel", "Cancel", 90, function()
        W.Confirm("Cancel this game? No one pays.", function() S.Cancel(kind) end)
    end, "Cancel", "Stop the game. No one pays.")
    Add("again", "Play again", 110, function()
        local test = Session(self).test
        S.Dismiss(kind)
        self:Open(test)
    end, "Play again", "Start a new game with the same settings.")
    Add("close", "Close", 90, function() S.Dismiss(kind) end,
        "Close", "Put this game away and go back to the setup.")

    local roll = Add("roll", "Roll!", 130, function()
        local s = Session(self)
        local lo, hi = self.G:Expect(s, ns.Me())
        if not lo then return end
        self:Spin(lo, hi, nil, "rolling...")
        S.Roll(kind)
    end)
    W.Tooltip(roll, "Roll!", function()
        local s = Session(self)
        if not s then return "Not your turn yet." end
        local lo, hi = self.G:Expect(s, ns.Me())
        if lo then return "Does a real /roll " .. lo .. "-" .. hi .. " for you." end
        return "Not your turn yet."
    end)
    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 4, 8)
    self.hint:SetJustifyH("LEFT")
end

local ORDER = { "close", "again", "cancel", "roll", "start", "bot", "leave", "join" }

function Page:RefreshButtons(s)
    local S, me, G = ns.Session, ns.Me(), self.G
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local show = {
        join = s.phase == "lobby" and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and s.phase == "lobby",
        start = s.phase == "lobby" and host,
        roll = s.phase == "rolling" and seated,
        cancel = host and S.IsActive(s),
        again = host and not S.IsActive(s),
        close = not S.IsActive(s) or S.HostOffline(s),
    }
    self.buttons.close:SetText(S.IsActive(s) and "Leave game" or "Close")
    local right
    for _, key in ipairs(ORDER) do
        local b = self.buttons[key]
        b:SetShown(show[key])
        if show[key] then
            b:ClearAllPoints()
            if right then b:SetPoint("RIGHT", right, "LEFT", -6, 0) else b:SetPoint("BOTTOMRIGHT", 0, 2) end
            right = b
        end
    end
    self.buttons.start:SetEnabled(#s.players >= G.minPlayers)
    self.buttons.join:SetEnabled(not s._joining and #s.players < S.MaxPlayers(s))
    self.buttons.bot:SetEnabled(S.CanAddBot(s))

    local mine = S.MyTurn(s)
    self.buttons.roll:SetEnabled(mine and not S.HostOffline(s))

    local hint = ""
    if s.phase == "lobby" and not host then
        hint = seated and ("Waiting for " .. s.host .. " to start.") or (s._joining and "Joining..." or "")
    elseif s.phase == "lobby" and #s.players < G.minPlayers then
        hint = "Waiting for players to join."
    elseif s.phase == "rolling" and not seated then
        hint = "You are watching this game."
    elseif s.phase == "rolling" and not mine then
        hint = "Waiting for the others to roll."
    end
    if S.HostOffline(s) then hint = W.HOST_OFFLINE end
    self.hint:SetText(hint)
    -- Keep the hint clear of the buttons.
    self.hint:SetPoint("RIGHT", right or self.hint:GetParent(), right and "LEFT" or "RIGHT", -8, 0)
end

---------------------------------------------------------------------------
-- Build and refresh
---------------------------------------------------------------------------
function Page.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind] }, Page)
    self:BuildSetup(parent)

    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v

    local pp = W.Panel(v, "Players")
    pp:SetPoint("TOPLEFT")
    pp:SetPoint("BOTTOMLEFT", 0, 34)
    pp:SetWidth(230)
    self.playersPanel = pp
    self.list = W.ScrollList(pp, ROW_H, BuildPlayerRow)
    self.list:Inset(6, -28, 6, 6)

    self:BuildTable(v)
    self:BuildButtons(v)
    return self
end

function Page:Refresh()
    local s = Session(self)
    self.setup:SetShown(s == nil)
    self.game:SetShown(s ~= nil)
    if not s then
        self.lastRollKey, self.lastId, self.spin, self.shown = nil, nil, nil, nil
        return self:RefreshSetup()
    end
    self:RefreshPlayers(s)
    self:RefreshTable(s)
    self:RefreshButtons(s)
end

function Page:RefreshSetup()
    -- Settings were reset: show the defaults again.
    if not ns.db.settings[self.kind] then
        for _, box in ipairs(self.fields) do
            local f = box.field
            if f.money then box:SetCopper(f.default) else box:SetText(tostring(f.default)) end
        end
        self:Saved()
    end
    local inGroup = ns.Net.Channel() ~= nil
    self.groupButton:SetEnabled(inGroup)
    if inGroup then
        self.setupHint:SetText("Everyone in your group with Flintar's Fun 'n' Games gets a window to join.")
    else
        self.setupHint:SetText("Join a party or raid to play for real: everyone in a group sees "
            .. "each other's rolls. Until then, practice with bots.")
    end
end

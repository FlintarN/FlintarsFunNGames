-- SlotsPage: the slot machine. Paytable and players on the left, the
-- machine on the right: a blinking marquee, three reels behind a payline,
-- and a lever.
--
-- Pulling the lever (or Spin!) starts the reels at once and asks the game
-- for a real /roll 1-512. When the roll comes back the reels stop one by
-- one on the symbols read from it. Other players' spins play out the same
-- way. The animation is only a show: the roll decides everything.
local ADDON, ns = ...

local W = ns.Widgets
local C = ns.Cards
local GP = ns.GamePage
local P = setmetatable({}, { __index = GP })
P.__index = P
ns.SlotsPage = P

local SYM, SYM_H = 60, 70           -- symbol size, distance between symbols on a reel
local REEL_W, REEL_H = 84, 120
local SPEED = 1100                   -- pixels per second while spinning
local BULBS = 11
local BULB_COLORS = { { 1, 0.82, 0.1 }, { 1, 0.25, 0.2 } }

local function Session(self) return ns.Session.Get(self.kind) end
local function Now() return GetTime and GetTime() or 0 end
local function Icon(key, size) return "|T" .. ns.Games.slots.SYMBOLS[key].tex .. ":" .. (size or 14) .. ":" .. (size or 14) .. "|t" end
local function RandomSymbol() return ns.Games.slots.STOPS[math.random(#ns.Games.slots.STOPS)] end

---------------------------------------------------------------------------
-- A reel: a window with three symbols that scroll downwards.
---------------------------------------------------------------------------
local Reel = {}
Reel.__index = Reel

local function NewReel(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(REEL_W, REEL_H)
    if f.SetClipsChildren then f:SetClipsChildren(true) end
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\AddOns\\FlintarsFunNGames\\Art\\SlotReel")
    local self = setmetatable({ frame = f, offset = 0, mode = "still", syms = {}, keys = {} }, Reel)
    for k = 1, 3 do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetSize(SYM, SYM)
        self.syms[k] = t
    end
    -- Shade the top and bottom so it reads as a drum.
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
        local sh = f:CreateTexture(nil, "OVERLAY")
        sh:SetPoint(side .. "LEFT")
        sh:SetPoint(side .. "RIGHT")
        sh:SetHeight(18)
        sh:SetColorTexture(0, 0, 0, 0.25)
    end
    self:Set({ RandomSymbol(), RandomSymbol(), RandomSymbol() })
    return self
end

-- keys: top, middle, bottom.
function Reel:Set(keys)
    for k = 1, 3 do self.keys[k] = keys[k] end
    self.offset = 0
    self:Draw()
end

function Reel:Draw()
    for k = 1, 3 do
        local t = self.syms[k]
        t:SetTexture(ns.Games.slots.SYMBOLS[self.keys[k]].tex)
        t:ClearAllPoints()
        t:SetPoint("CENTER", self.frame, "CENTER", 0, (2 - k) * SYM_H + self.offset)
    end
end

-- Move everything one symbol down; a new symbol comes in at the top.
function Reel:Shift(newTop)
    self.keys[3] = self.keys[2]
    self.keys[2] = self.keys[1]
    self.keys[1] = newTop or RandomSymbol()
    self.offset = self.offset + SYM_H
end

function Reel:Spin()
    self.mode = "spin"
end

-- Land on `key` in the middle, `at` seconds from now.
function Reel:StopAt(key, at)
    self.stopKey, self.stopAt = key, at
end

function Reel:Update(now, dt)
    if self.mode == "spin" then
        self.offset = self.offset - SPEED * dt
        while self.offset <= -SYM_H do self:Shift() end
        if self.stopAt and now >= self.stopAt then
            -- The result comes in at the top and slides down into the middle.
            self.keys[1] = self.stopKey
            self.mode = "stop"
            self.from, self.t0 = self.offset, now
        end
        self:Draw()
    elseif self.mode == "stop" then
        local t = math.min(1, (now - self.t0) / 0.4)
        -- Ease out, overshooting the line a little and settling back.
        local c1 = 1.70158
        local e = 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
        self.offset = self.from + (-SYM_H - self.from) * e
        if t >= 1 then
            self.keys = { RandomSymbol(), self.keys[1], self.keys[2] }
            self.offset = 0
            self.mode = "still"
            self.stopAt = nil
            if self.onStop then self.onStop() end
        end
        self:Draw()
    end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function BuildPayRow(parent, i, line)
    local y = -26 - (i - 1) * 21
    local text = ""
    for k = 1, 3 do
        local key = line[1][k]
        text = text .. (key == "any" and "|cff888888  -  |r" or Icon(key, 16)) .. " "
    end
    local l = W.Label(parent, text, "GameFontHighlight")
    l:SetPoint("TOPLEFT", 10, y)
    local m = W.Label(parent, "x" .. line[2], line[2] >= 10 and "GameFontNormal" or "GameFontHighlight")
    m:SetPoint("TOPRIGHT", -10, y - 1)
end

local function BuildPlayerRow(row)
    row.net = W.Label(row, "", "GameFontHighlightSmall")
    row.net:SetPoint("RIGHT", -2, 0)
    -- The name gets everything left of the total.
    row.name = W.Label(row, "", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetPoint("RIGHT", row.net, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
end

function P:BuildMachine(v)
    local G = self.G
    local pay = W.Panel(v, "Paytable")
    pay:SetPoint("TOPLEFT")
    pay:SetSize(172, 26 + #G.PAYS * 21 + 6)
    for i, line in ipairs(G.PAYS) do BuildPayRow(pay, i, line) end
    W.Tooltip(pay, "Paytable", "What a spin pays, times the bet. A dash means any symbol. "
        .. "Cherries only count from the left.")

    local players = W.Panel(v, "Players")
    players:SetPoint("TOPLEFT", pay, "BOTTOMLEFT", 0, -6)
    players:SetPoint("BOTTOMLEFT", 0, 34)
    players:SetWidth(172)
    self.playersPanel = players
    self.list = W.ScrollList(players, 18, BuildPlayerRow)
    self.list:Inset(6, -26, 6, 6)

    -- The machine body: a red cabinet with a gold rim.
    local m = W.Panel(v)
    m:SetPoint("TOPLEFT", pay, "TOPRIGHT", 8, 0)
    m:SetPoint("BOTTOMRIGHT", 0, 34)
    if m.SetBackdropBorderColor then m:SetBackdropBorderColor(1, 0.8, 0.3, 1) end
    local body = m:CreateTexture(nil, "BORDER", nil, 2)
    body:SetPoint("TOPLEFT", 3, -3)
    body:SetPoint("BOTTOMRIGHT", -3, 3)
    body:SetColorTexture(0.32, 0.04, 0.06, 0.85)
    self.machine = m

    self.title = W.BigLabel(m, 22, "GameFontNormalHuge")
    self.title:SetPoint("TOP", -14, -22)
    self.title:SetText("LUCK IS A DRUG")

    -- Marquee bulbs above and below the title.
    self.bulbs = {}
    for row = 1, 2 do
        for i = 1, BULBS do
            local b = m:CreateTexture(nil, "OVERLAY")
            b:SetSize(10, 10)
            b:SetTexture("Interface\\AddOns\\FlintarsFunNGames\\Art\\SlotBulb")
            if b.SetBlendMode then b:SetBlendMode("ADD") end
            b:SetPoint("CENTER", self.title, "CENTER", (i - (BULBS + 1) / 2) * 22, row == 1 and 18 or -18)
            table.insert(self.bulbs, b)
        end
    end

    -- Three reels in a gold frame, with the payline across.
    local window = CreateFrame("Frame", nil, m)
    window:SetSize(3 * REEL_W + 2 * 8 + 12, REEL_H + 12)
    window:SetPoint("TOP", -14, -64)
    local frameTex = window:CreateTexture(nil, "BACKGROUND")
    frameTex:SetAllPoints()
    frameTex:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
    local inner = window:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", 3, -3)
    inner:SetPoint("BOTTOMRIGHT", -3, 3)
    inner:SetColorTexture(0.05, 0.02, 0.02, 1)
    self.reels = {}
    for i = 1, 3 do
        local r = NewReel(window)
        r.frame:SetPoint("LEFT", 6 + (i - 1) * (REEL_W + 8), 0)
        self.reels[i] = r
    end
    local line = CreateFrame("Frame", nil, window)
    line:SetAllPoints()
    line:SetFrameLevel(window:GetFrameLevel() + 10)
    local pl = line:CreateTexture(nil, "OVERLAY")
    pl:SetPoint("LEFT", 2, 0)
    pl:SetPoint("RIGHT", -2, 0)
    pl:SetHeight(2)
    pl:SetColorTexture(1, 0.2, 0.2, 0.7)
    self.window = window

    -- The lever, right of the reels: a rod down to the base, a red knob on top.
    local base = m:CreateTexture(nil, "ARTWORK")
    base:SetSize(16, 22)
    base:SetPoint("LEFT", window, "RIGHT", 8, -20)
    base:SetColorTexture(0.55, 0.45, 0.25, 1)
    local knob = CreateFrame("Button", nil, m)
    knob:SetSize(26, 26)
    knob:SetFrameLevel(m:GetFrameLevel() + 10)
    local kt = knob:CreateTexture(nil, "ARTWORK")
    kt:SetAllPoints()
    kt:SetTexture("Interface\\AddOns\\FlintarsFunNGames\\Art\\SlotKnob")
    local rod = m:CreateTexture(nil, "ARTWORK", nil, 1)
    rod:SetWidth(5)
    rod:SetPoint("TOP", knob, "CENTER", 0, 0)
    rod:SetPoint("BOTTOM", base, "CENTER", 0, 0)
    rod:SetColorTexture(0.75, 0.75, 0.78, 1)
    knob:SetScript("OnClick", function() self:Pull() end)
    W.Tooltip(knob, "Pull the lever", "Spin! A real /roll 1-512 decides the reels.")
    self.knob, self.leverBase = knob, base
    self:PlaceKnob(0)

    -- What just happened.
    self.win = W.BigLabel(m, 24, "GameFontNormalHuge")
    self.win:SetPoint("TOP", window, "BOTTOM", 0, -12)
    self.banner = W.Label(m, "", "GameFontHighlight")
    self.banner:SetPoint("TOP", self.win, "BOTTOM", 0, -6)
    self.banner:SetPoint("LEFT", 12, 0)
    self.banner:SetPoint("RIGHT", -12, 0)
    self.log = W.Label(m, "", "GameFontHighlightSmall")
    self.log:SetPoint("BOTTOM", 0, 10)
    self.log:SetPoint("LEFT", 12, 0)
    self.log:SetPoint("RIGHT", -12, 0)

    m:SetScript("OnUpdate", function(_, elapsed) self:Animate(Now(), elapsed or 0) end)
    self.blink = 0
end

function P:PlaceKnob(down)
    self.knob:ClearAllPoints()
    self.knob:SetPoint("CENTER", self.leverBase, "CENTER", 0, 62 - down)
end

function P:BuildButtons(v)
    local S, kind = ns.Session, self.kind
    self.buttons = {}
    local function Add(key, text, w, onClick, title, help)
        local b = W.Button(v, text, w, onClick, 26)
        if title then W.Tooltip(b, title, help) end
        self.buttons[key] = b
        return b
    end
    Add("join", "Join", 80, function() S.Join(kind) end, "Join", "Step up to the machine.")
    Add("leave", "Leave", 80, function() S.Leave(kind) end, "Leave", "Step away before it opens.")
    Add("bot", "+ Bot", 70, function() S.AddBot(kind) end, "Add a bot", "A fake player who pulls the lever a few times (practice only).")
    Add("start", "Open machine", 120, function()
        local ok, why = S.Start(kind)
        if not ok and why then self.hint:SetText("|cffff6060" .. why .. "|r") end
    end, "Open machine", "Let the players pull the lever.")
    Add("spin", "Spin!", 130, function() self:Pull() end, "Spin!",
        "Pull the lever: a real /roll 1-512 decides the reels.")
    Add("endTable", "Close machine", 120, function()
        W.Confirm("Close the machine and settle up?", function() S.Act(kind, "end") end)
    end, "Close machine", "Stop and work out who pays whom.")
    Add("cancel", "Cancel", 80, function()
        W.Confirm("Cancel this game? No one pays.", function() S.Cancel(kind) end)
    end, "Cancel", "Stop the game. No one pays.")
    Add("again", "Play again", 100, function()
        local test = Session(self).test
        S.Dismiss(kind)
        self:Open(test)
    end, "Play again", "Open the machine again with the same bet.")
    Add("close", "Close", 80, function() S.Dismiss(kind) end, "Close", "Put the machine away.")

    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 4, 9)
    self.hint:SetJustifyH("LEFT")
end

local ORDER = { "close", "again", "endTable", "cancel", "spin", "start", "bot", "leave", "join" }

function P.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind] }, P)
    self:BuildSetup(parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    self:BuildMachine(v)
    self:BuildButtons(v)
    return self
end

---------------------------------------------------------------------------
-- Spinning
---------------------------------------------------------------------------
function P:IsSpinning()
    for _, r in ipairs(self.reels) do
        if r.mode ~= "still" then return true end
    end
    return false
end

-- Your pull: lever down, reels spinning, ask the game for the roll.
function P:Pull()
    local s = Session(self)
    if not (s and ns.Session.MyTurn(s)) or self.waiting or ns.Session.HostOffline(s) then return end
    self.waiting = Now()
    self.win:SetText("")
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
    C.Tween(0.45, function(t)
        self:PlaceKnob(math.sin(t * math.pi) * 48)
    end)
    for _, r in ipairs(self.reels) do r:Spin() end
    ns.Session.Roll(self.kind)
    ns.Changed() -- Spin! greys out until the reels land
end

-- Stop the reels on a spin's result, one after another.
function P:Land(spin, quick)
    self.landing = spin
    local now = Now()
    local first = quick and 0.15 or 0.6
    for i, r in ipairs(self.reels) do
        if r.mode == "still" then r:Spin() end
        r:StopAt(spin.reels[i], now + first + (i - 1) * 0.35)
        r.onStop = function()
            W.PlaySound("U_CHAT_SCROLL_BUTTON")
            if i == 3 then self:Landed(spin) end
        end
    end
end

function P:Landed(spin)
    self.landing = nil
    self.waiting = nil
    ns.Changed() -- Spin! can be clicked again
    local s = Session(self)
    if spin.mult > 0 then
        local text = spin.mult >= 10 and "|cffffd100WIN x" .. spin.mult .. "!|r" or "|cff40ff40Win x" .. spin.mult .. "|r"
        self.win:SetText(text .. "  " .. ns.Money(spin.win))
        self.blink = spin.mult >= 10 and 3 or 1
        local m = self.machine
        local coins = math.min(14, 2 + spin.mult)
        for i = 1, coins do
            local a = math.random() * math.pi
            C.Coin(m, -14, 20, -14 + math.cos(a) * 120, -60 - math.random() * 40, i * 0.04)
        end
        W.PlaySound(spin.mult >= 30 and "LEVELUP" or "LOOTWINDOW_COIN_SOUND")
    else
        self.win:SetText("|cff999999No win|r")
    end
    -- Someone spun while we were showing this one: show theirs next.
    if self.pending and s and self.pending.n ~= spin.n then
        local nextSpin = self.pending
        self.pending = nil
        self:Land(nextSpin, true)
    end
end

function P:Animate(now, dt)
    for _, r in ipairs(self.reels) do r:Update(now, dt) end
    -- Your roll never came (wrong range, lag): stop the reels where they are.
    if self.waiting and not self.landing and now - self.waiting > 6 then
        self.waiting = nil
        for _, r in ipairs(self.reels) do
            r.mode = "still"
            r:Set(r.keys)
        end
        ns.Changed()
    end
    -- Marquee: chase slowly, flash fast after a win.
    self.blinkT = (self.blinkT or 0) + dt
    local speed = self.blink > 0 and 0.08 or 0.35
    if self.blinkT >= speed then
        self.blinkT = 0
        self.phase = ((self.phase or 0) + 1) % 2
        if self.blink > 0 then
            self.blinkCount = (self.blinkCount or 0) + 1
            if self.blinkCount > 20 * self.blink then
                self.blink, self.blinkCount = 0, 0
            end
        end
        for i, b in ipairs(self.bulbs) do
            local c = BULB_COLORS[((i + self.phase) % 2) + 1]
            b:SetVertexColor(c[1], c[2], c[3])
        end
    end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function P:Refresh()
    local s = Session(self)
    self.setup:SetShown(s == nil)
    self.game:SetShown(s ~= nil)
    if not s then
        self.spinKey, self.lastId = nil, nil
        return self:RefreshSetup()
    end

    -- A new spin on this machine: play it. Everyone has a machine of their
    -- own, so a player sees only their own spins (others' are in the list
    -- below); the house, who doesn't pull, watches every spin.
    local spin = s.lastSpin
    for _, p in ipairs(s.players) do
        if p.name == ns.Me() and not p.house then spin = p.last end
    end
    local key = spin and (s.id .. ":" .. spin.n)
    if key ~= self.spinKey then
        local fresh = self.lastId == s.id
        self.spinKey = key
        if spin and fresh then
            if self.landing then
                self.pending = spin
            else
                self:Land(spin, spin.name ~= ns.Me())
            end
        elseif spin then
            for i, r in ipairs(self.reels) do r:Set({ RandomSymbol(), spin.reels[i], RandomSymbol() }) end
        end
    end
    self.lastId = s.id

    local status = self.G:Status(s)
    self.banner:SetText((s.banner or "") .. (status and s.phase == "rolling" and ("\n|cffaaaaaa" .. status .. "|r") or ""))
    local lines = {}
    for i = #s.log, math.max(1, #s.log - 2), -1 do
        local e = s.log[i]
        local reels = self.G.Reels(e.roll)
        local mult = self.G.Payout(reels)
        table.insert(lines, e.name .. " " .. Icon(reels[1]) .. Icon(reels[2]) .. Icon(reels[3])
            .. (mult > 0 and (" |cff40ff40x" .. mult .. "|r") or ""))
    end
    self.log:SetText(table.concat(lines, "   "))

    -- Players: the house first, then everyone's running total.
    local me = ns.Me()
    for i, p in ipairs(s.players) do
        local row = self.list:Row(i)
        local name = p.name
        if p.name == me then name = "|cffffd100" .. name .. "|r" end
        if p.house then name = name .. " |cffaaaaaa(house)|r" elseif p.bot then name = name .. " |cff888888(bot)|r" end
        name = name .. W.PlayerTag(p)
        row.name:SetText(name)
        row.net:SetText(s.phase == "lobby" and "" or ns.Signed(p.net or 0))
    end
    self.list:SetCount(#s.players)

    self:RefreshButtons(s)
end

function P:RefreshButtons(s)
    local S, me, G = ns.Session, ns.Me(), self.G
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local canSpin = S.MyTurn(s)
    local show = {
        join = S.CanJoin(s) and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and S.CanJoin(s),
        start = s.phase == "lobby" and host,
        spin = s.phase == "rolling" and seated and s.house ~= me,
        endTable = s.phase == "rolling" and host,
        cancel = s.phase == "lobby" and host,
        again = host and not S.IsActive(s),
        close = not S.IsActive(s) or S.HostOffline(s),
    }
    self.buttons.close:SetText(S.IsActive(s) and "Leave game" or "Close")
    local right
    for _, key in ipairs(ORDER) do
        local b = self.buttons[key]
        b:SetShown(show[key] and true or false)
        if show[key] then
            b:ClearAllPoints()
            if right then b:SetPoint("RIGHT", right, "LEFT", -4, 0) else b:SetPoint("BOTTOMRIGHT", 0, 2) end
            right = b
        end
    end
    self.buttons.start:SetEnabled(#s.players >= G.minPlayers)
    self.buttons.spin:SetEnabled(canSpin and not self.waiting and not S.HostOffline(s))
    self.buttons.join:SetEnabled(not s._joining and #s.players < G.maxPlayers)
    self.buttons.bot:SetEnabled(S.CanAddBot(s))

    local hint = ""
    if s.phase == "lobby" then
        hint = host and (s.test and "Gazlowe runs the machine; you play." or "You are the house. Waiting for players.")
            or (seated and ("Waiting for " .. s.house .. " to open the machine.") or "")
    elseif s.phase == "rolling" and s.house == me then
        hint = "You are the house: players pull, you pay out (or collect)."
    elseif s.phase == "rolling" and seated and G.AtLimit(s, select(2, S.Find(s, me))) then
        hint = "You've hit the table limit (" .. ns.Money(s.playerCap) .. "). No more spins at this machine."
    elseif s.phase == "done" and s.result then
        local parts = {}
        for _, t in ipairs(s.result.transfers or {}) do
            table.insert(parts, t.payer .. " pays " .. t.payee .. " " .. ns.Money(t.amount))
        end
        hint = #parts > 0 and table.concat(parts, ", ") or "Everyone broke even."
        if s.test then hint = hint .. " |cff888888(practice)|r" end
    end
    if S.HostOffline(s) then hint = W.HOST_OFFLINE end
    self.hint:SetText(hint)
    if right then self.hint:SetPoint("RIGHT", right, "LEFT", -8, 0) end
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.slots = P.New

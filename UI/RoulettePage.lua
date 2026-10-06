-- RoulettePage: the wheel on the left, results and players on the right,
-- and the betting table along the bottom.
--
-- Your chips are kept on your own "slip" while you click, and sent to the
-- host a moment after you stop (so a burst of clicks is one message).
-- The ball's flight is only a show: it lands where the thrower's /roll says.
-- The number ring stays still and the ball moves, so the ball always ends
-- in exactly the right pocket; the centre turns to make it feel alive.
local ADDON, ns = ...

local W = ns.Widgets
local C = ns.Cards
local GP = ns.GamePage
local P = setmetatable({}, { __index = GP })
P.__index = P
ns.RoulettePage = P

local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"
local TAU = math.pi * 2
local STEP = TAU / 37
local WHEEL = 196
local ORBIT_R = WHEEL / 2 * (241 / 256)   -- the wooden track
local POCKET_R = WHEEL / 2 * (178 / 256)  -- the pockets
local CELL_H, ZERO_W, COL_W = 26, 30, 30
local COLORS = {
    red = { 0.62, 0.08, 0.10 },
    black = { 0.10, 0.10, 0.12 },
    green = { 0.06, 0.40, 0.18 },
    felt = { 0.10, 0.33, 0.18 },
}

local function Session(self) return ns.Session.Get(self.kind) end
local function Now() return GetTime and GetTime() or 0 end
local function Copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

---------------------------------------------------------------------------
-- Build: the wheel
---------------------------------------------------------------------------
function P:BuildWheel(v)
    local panel = W.Panel(v)
    panel:SetPoint("TOPLEFT")
    panel:SetSize(214, 210)
    local felt = panel:CreateTexture(nil, "BORDER", nil, 2)
    felt:SetPoint("TOPLEFT", 3, -3)
    felt:SetPoint("BOTTOMRIGHT", -3, 3)
    felt:SetColorTexture(0.09, 0.30, 0.16, 0.85)

    local wheel = CreateFrame("Frame", nil, panel)
    wheel:SetSize(WHEEL, WHEEL)
    wheel:SetPoint("CENTER")
    local ring = wheel:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints()
    ring:SetTexture(ART .. "RouletteWheel")
    self.hub = wheel:CreateTexture(nil, "ARTWORK", nil, 2)
    self.hub:SetSize(WHEEL * 0.42, WHEEL * 0.42)
    self.hub:SetPoint("CENTER")
    self.hub:SetTexture(ART .. "RouletteHub")
    self.ball = wheel:CreateTexture(nil, "OVERLAY")
    self.ball:SetSize(11, 11)
    self.ball:SetTexture(ART .. "RouletteBall")
    self.ball:Hide()
    self.wheel = wheel
    self.hubAngle, self.hubSpeed = 0, 0.25
    self.mode = "hidden"
    wheel:SetScript("OnUpdate", function(_, elapsed) self:Animate(Now(), elapsed or 0) end)
end

---------------------------------------------------------------------------
-- Build: results and players
---------------------------------------------------------------------------
local function BuildPlayerRow(row)
    row.net = W.Label(row, "", "GameFontHighlightSmall")
    row.net:SetPoint("RIGHT", -2, 0)
    row.name = W.Label(row, "", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetPoint("RIGHT", row.net, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.skip = W.SkipButton(row)
    row.skip:SetPoint("RIGHT", -2, 0)
end

function P:BuildInfo(v)
    local info = W.Panel(v)
    info:SetPoint("TOPLEFT", 222, 0)
    info:SetPoint("TOPRIGHT")
    info:SetHeight(210)

    self.number = W.BigLabel(info, 30, "GameFontNormalHuge")
    self.number:SetPoint("TOPLEFT", 12, -12)
    self.numberInfo = W.Label(info, "", "GameFontHighlight")
    self.numberInfo:SetPoint("LEFT", self.number, "RIGHT", 10, 0)
    self.mine = W.Label(info, "", "GameFontNormal")
    self.mine:SetPoint("TOPLEFT", self.number, "BOTTOMLEFT", 0, -6)

    -- The last numbers, newest first.
    self.history = {}
    for i = 1, 12 do
        local box = CreateFrame("Frame", nil, info)
        box:SetSize(22, 18)
        box:SetPoint("TOPLEFT", 12 + (i - 1) * 24, -70)
        box.bg = box:CreateTexture(nil, "ARTWORK")
        box.bg:SetAllPoints()
        box.text = W.Label(box, "", "GameFontHighlightSmall")
        box.text:SetPoint("CENTER")
        box:Hide()
        self.history[i] = box
    end

    self.banner = W.Label(info, "", "GameFontHighlightSmall")
    self.banner:SetPoint("TOPLEFT", 12, -94)
    self.banner:SetPoint("RIGHT", -12, 0)
    self.banner:SetJustifyH("LEFT")

    local list = W.ScrollList(info, 16, BuildPlayerRow)
    list:Inset(8, -126, 8, 6)
    self.list = list
end

---------------------------------------------------------------------------
-- Build: the betting table
---------------------------------------------------------------------------
function P:BuildCell(board, spot, label, color, x, y, w, h)
    local b = CreateFrame("Button", nil, board)
    b:SetSize(w, h)
    b:SetPoint("TOPLEFT", x, y)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.45)
    local bg = b:CreateTexture(nil, "BORDER")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    local c = COLORS[color]
    bg:SetColorTexture(c[1], c[2], c[3], 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    b.win = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.win:SetAllPoints()
    b.win:SetColorTexture(1, 0.82, 0.1, 0.45)
    if b.win.SetBlendMode then b.win:SetBlendMode("ADD") end
    b.win:Hide()
    b.label = W.Label(b, label, "GameFontHighlight")
    b.label:SetPoint("CENTER")
    -- Chips on this spot: a coin with a count.
    b.coin = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.coin:SetSize(13, 13)
    b.coin:SetPoint("TOPRIGHT", -1, -1)
    b.coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    b.coin:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = W.Label(b, "", "GameFontNormalSmall")
    b.count:SetPoint("RIGHT", b.coin, "LEFT", -1, 0)
    b.coin:Hide()
    b.spot = spot
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            self:AddChips(spot, -1)
        else
            self:AddChips(spot, IsShiftKeyDown and IsShiftKeyDown() and 5 or 1)
        end
    end)
    W.Tooltip(b, label, function() return self:SpotTip(spot) end)
    self.cells[spot] = b
    return b
end

function P:BuildBoard(v)
    local board = W.Panel(v)
    board:SetPoint("TOPLEFT", 0, -216)
    board:SetPoint("BOTTOMRIGHT", 0, 34)
    self.board = board
    self.cells = {}
    local width = 538 - 8 - ZERO_W - COL_W - 4
    local cw = math.floor(width / 12)
    local left = 4 + ZERO_W + 2
    self:BuildCell(board, "n0", "0", "green", 4, -4, ZERO_W, CELL_H * 3)
    for col = 1, 12 do
        for row = 1, 3 do
            local n = 3 * col - (row - 1)
            self:BuildCell(board, "n" .. n, tostring(n), ns.Games.roulette.Color(n), left + (col - 1) * cw, -4 - (row - 1) * CELL_H, cw, CELL_H)
        end
    end
    -- Columns pay 2 to 1 (top row is column 3).
    for row = 1, 3 do
        self:BuildCell(board, "c" .. (4 - row), "2:1", "felt", left + 12 * cw + 2, -4 - (row - 1) * CELL_H, COL_W, CELL_H)
    end
    local y = -4 - 3 * CELL_H - 2
    for i, spot in ipairs({ "d1", "d2", "d3" }) do
        self:BuildCell(board, spot, ns.Games.roulette.OUTSIDE[spot][1], "felt", left + (i - 1) * 4 * cw, y, 4 * cw, 20)
    end
    y = y - 22
    for i, spot in ipairs({ "low", "even", "red", "black", "odd", "high" }) do
        local color = (spot == "red" or spot == "black") and spot or "felt"
        self:BuildCell(board, spot, ns.Games.roulette.OUTSIDE[spot][1], color, left + (i - 1) * 2 * cw, y, 2 * cw, 20)
    end
end

---------------------------------------------------------------------------
-- Build: buttons
---------------------------------------------------------------------------
function P:BuildButtons(v)
    local S, kind = ns.Session, self.kind
    self.buttons = {}
    local function Add(key, text, w, onClick, title, help)
        local b = W.Button(v, text, w, onClick, 26)
        if title then W.Tooltip(b, title, help) end
        self.buttons[key] = b
        return b
    end
    Add("join", "Join", 70, function() S.Join(kind) end, "Join", "Take a place at the table.")
    Add("leave", "Leave", 70, function() S.Leave(kind) end, "Leave", "Step away before it opens.")
    Add("bot", "+ Bot", 64, function() S.AddBot(kind) end, "Add a bot", "A fake player who bets each round (practice only).")
    Add("start", "Open table", 100, function()
        local ok, why = S.Start(kind)
        if not ok and why then self.hint:SetText("|cffff6060" .. why .. "|r") end
    end, "Open table", "Let the bets begin.")
    Add("throw", "Throw the ball", 120, function() self:Throw() end, "Throw the ball",
        "No more bets! Does a real /roll 1-37: the ball lands on the roll minus one.")
    Add("clear", "Clear bets", 86, function() self:ClearChips() end, "Clear bets", "Take all your chips back.")
    Add("endTable", "Close table", 100, function()
        W.Confirm("Close the table and settle up?", function() S.Act(kind, "end") end)
    end, "Close table", "Stop and work out who pays whom.")
    Add("cancel", "Cancel", 70, function()
        W.Confirm("Cancel this game? No one pays.", function() S.Cancel(kind) end)
    end, "Cancel", "Stop the game. No one pays.")
    Add("again", "Play again", 90, function()
        local test = Session(self).test
        S.Dismiss(kind)
        self:Open(test)
    end, "Play again", "Open the table again with the same chips.")
    Add("close", "Close", 70, function() S.Dismiss(kind) end, "Close", "Put the table away.")

    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 4, 9)
    self.hint:SetJustifyH("LEFT")
end

local ORDER = { "close", "again", "endTable", "cancel", "throw", "clear", "start", "bot", "leave", "join" }

function P.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind], slip = {} }, P)
    self:BuildSetup(parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    self:BuildWheel(v)
    self:BuildInfo(v)
    self:BuildBoard(v)
    self:BuildButtons(v)
    return self
end

---------------------------------------------------------------------------
-- Betting
---------------------------------------------------------------------------
function P:CanBet(s)
    local S, me = ns.Session, ns.Me()
    if not (s and s.phase == "rolling") or S.HostOffline(s) or self.throwing then return false end
    local _, p = S.Find(s, me)
    return p ~= nil and not p.house and not p.out
end

function P:AddChips(spot, k)
    local s = Session(self)
    if not self:CanBet(s) then return end
    self.slipKey = s.id .. ":" .. tostring(s.round) -- these chips are for this round
    local slip = Copy(self.slip)
    slip[spot] = math.max(0, math.min(100, (slip[spot] or 0) + k))
    if slip[spot] == 0 then slip[spot] = nil end
    -- Respect the table limit before sending.
    local _, p = ns.Session.Find(s, ns.Me())
    local stake = self.G.SlipChips(slip) * s.chip
    if s.playerCap and -(p.net or 0) + stake > s.playerCap then
        self.limitNote = "That's over the table limit of " .. ns.Money(s.playerCap) .. "."
        return self:RefreshButtons(s)
    end
    self.limitNote = nil
    self.slip = slip
    if k > 0 then W.PlaySound("LOOTWINDOW_COIN_SOUND") end
    self:SendSoon()
    self:DrawChips(s)
    self:RefreshButtons(s)
end

function P:ClearChips()
    local s = Session(self)
    if not self:CanBet(s) then return end
    self.slip = {}
    self:SendSoon()
    self:DrawChips(s)
    self:RefreshButtons(s)
end

-- Send the slip half a second after the last click.
function P:SendSoon()
    self.sendAt = Now() + 0.5
end

function P:SendNow()
    self.sendAt = nil
    local text = self.G.EncodeSlip(self.slip)
    if text ~= self.sent then
        self.sent = text
        ns.Session.Act(self.kind, "slip:" .. text)
    end
end

-- No more bets: send the last chips, then the real /roll.
function P:Throw()
    local s = Session(self)
    if not (s and ns.Session.MyTurn(s)) or ns.Session.HostOffline(s) or self.throwing then return end
    self:SendNow()
    self.throwing = Now()
    self:StartSpin()
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
    -- Give the chips a moment to reach the host before the ball lands.
    ns.After(ns.Session.IsHost(s) and 0 or 0.6, function() ns.Session.Roll(self.kind) end)
    self:RefreshButtons(s)
end

function P:SpotTip(spot)
    local s = Session(self)
    local name, pays = self.G.Spot(spot)
    local lines = { "Pays " .. pays .. " to 1." }
    if s then
        local mine = self.slip[spot] or 0
        if mine > 0 then table.insert(lines, "Your chips: " .. mine .. " (" .. ns.Money(mine * s.chip) .. ")") end
        for who, slip in pairs(s.bets or {}) do
            if who ~= ns.Me() and slip[spot] then table.insert(lines, who .. ": " .. slip[spot]) end
        end
    end
    table.insert(lines, "|cffaaaaaaLeft-click: 1 chip, shift-click: 5, right-click: take one back.|r")
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- The ball
---------------------------------------------------------------------------
function P:PlaceBall()
    local a, r = self.ballAngle or 0, self.ballR or ORBIT_R
    self.ball:ClearAllPoints()
    self.ball:SetPoint("CENTER", self.wheel, "CENTER", r * math.sin(a), r * math.cos(a))
end

function P:StartSpin()
    if self.mode == "spin" or self.mode == "land" then return end
    self.mode = "spin"
    self.ballAngle = self.ballAngle or 0
    self.ballR = ORBIT_R
    self.hubSpeed = 2.5
    self.ball:Show()
end

-- Land the ball on n: a few more turns, slowing down, dropping into the pocket.
function P:Land(n, quick)
    if self.mode ~= "spin" then self:StartSpin() end
    local target = (self.G.POCKET[n] - 1) * STEP
    local a0 = self.ballAngle
    local back = (a0 - target) % TAU
    self.land = { n = n, t0 = Now(), dur = quick and 2.4 or 3.4, a0 = a0,
        delta = -(back + TAU * (quick and 2 or 3)) }
    self.mode = "land"
end

function P:Animate(now, dt)
    -- The centre turns, slowing down to a lazy spin.
    self.hubSpeed = math.max(0.25, (self.hubSpeed or 0.25) - dt * 0.5)
    self.hubAngle = (self.hubAngle or 0) + self.hubSpeed * dt
    if self.hub.SetRotation then self.hub:SetRotation(self.hubAngle) end

    if self.mode == "spin" then
        self.ballAngle = (self.ballAngle - 2.2 * TAU * dt) % TAU
        self.ballR = ORBIT_R
        self:PlaceBall()
        -- Your roll never came (wrong range, lag): stop where it is.
        if self.throwing and now - self.throwing > 8 then
            self.throwing = nil
            self.mode = self.restN and "rest" or "hidden"
            self.ball:SetShown(self.restN ~= nil)
            ns.Changed()
        end
    elseif self.mode == "land" then
        local L = self.land
        local t = math.min(1, (now - L.t0) / L.dur)
        local e = 1 - (1 - t) ^ 3
        self.ballAngle = L.a0 + L.delta * e
        -- Off the track and into the pockets, with a little bounce.
        if t < 0.55 then
            self.ballR = ORBIT_R
        elseif t < 0.85 then
            local k = (t - 0.55) / 0.3
            self.ballR = ORBIT_R + (POCKET_R - ORBIT_R) * k + math.sin(k * math.pi * 3) * 4 * (1 - k)
        else
            self.ballR = POCKET_R
        end
        self:PlaceBall()
        if t >= 1 then
            self.mode = "rest"
            self.restN = L.n
            self.ballAngle = (self.G.POCKET[L.n] - 1) * STEP
            self.ballR = POCKET_R
            self:PlaceBall()
            self:Landed(L.n)
        end
    end

    -- Send chips after the last click.
    if self.sendAt and now >= self.sendAt then self:SendNow() end
end

function P:Landed(n)
    self.throwing = nil
    self.shownN = n
    local s = Session(self)
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
    -- Light up every winning spot for a few seconds.
    for spot, cell in pairs(self.cells) do
        local _, _, wins = self.G.Spot(spot)
        cell.win:SetShown(wins(n))
    end
    self.winUntil = Now() + 4
    ns.After(4.1, function() ns.Changed() end)
    local mine = s and s.last and s.last.results and s.last.results[ns.Me()]
    if mine and mine > 0 then
        W.PlaySound("LOOTWINDOW_COIN_SOUND")
        for i = 1, 8 do
            local a = math.random() * math.pi
            C.Coin(self.wheel, 0, 0, math.cos(a) * 80, -40 - math.random() * 50, i * 0.05)
        end
    end
    ns.Changed()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function P:DrawChips(s)
    local me = ns.Me()
    for spot, cell in pairs(self.cells) do
        local total = self.slip[spot] or 0
        for who, slip in pairs(s.bets or {}) do
            if who ~= me then total = total + (slip[spot] or 0) end
        end
        cell.coin:SetShown(total > 0)
        cell.count:SetText(total > 0 and tostring(total) or "")
    end
end

local function ColorText(n)
    local c = ns.Games.roulette.Color(n)
    local hex = c == "red" and "|cffe23b3b" or (c == "green" and "|cff3ec46d" or "|cffdddddd")
    return hex .. n .. "|r", c
end

function P:DrawResult(s)
    local n = self.shownN
    if n == nil then
        self.number:SetText("")
        self.numberInfo:SetText(s.phase == "rolling" and "Place your bets!" or "")
        self.mine:SetText("")
    else
        local text, color = ColorText(n)
        self.number:SetText(text)
        local words = { color:sub(1, 1):upper() .. color:sub(2) }
        if n > 0 then
            table.insert(words, n % 2 == 1 and "Odd" or "Even")
            table.insert(words, n <= 18 and "1-18" or "19-36")
        end
        self.numberInfo:SetText(table.concat(words, "  "))
        local mine = s.last and s.last.number == n and s.last.results[ns.Me()]
        if mine and mine > 0 then
            self.mine:SetText("|cff40ff40You win|r " .. ns.Money(mine))
        elseif mine and mine < 0 then
            self.mine:SetText("|cffff5050You lose|r " .. ns.Money(-mine))
        else
            self.mine:SetText("")
        end
    end
    for i, box in ipairs(self.history) do
        local h = s.history and s.history[i]
        -- Hold the newest number back until the ball has landed.
        if self.mode == "land" and s.history then h = s.history[i + 1] end
        if h then
            local c = COLORS[ns.Games.roulette.Color(h)]
            box.bg:SetColorTexture(c[1], c[2], c[3], 1)
            box.text:SetText(tostring(h))
            box:Show()
        else
            box:Hide()
        end
    end
    if not (self.winUntil and Now() < self.winUntil) then
        for _, cell in pairs(self.cells) do cell.win:Hide() end
    end
end

function P:Refresh()
    local s = Session(self)
    self.setup:SetShown(s == nil)
    self.game:SetShown(s ~= nil)
    if not s then
        self.lastKey, self.lastId, self.shownN, self.restN = nil, nil, nil, nil
        self.mode = "hidden"
        self.ball:Hide()
        return self:RefreshSetup()
    end

    -- A new round: your slip starts from what the host has for you.
    local roundKey = s.id .. ":" .. tostring(s.round)
    if roundKey ~= self.slipKey then
        self.slipKey = roundKey
        self.slip = Copy(s.bets and s.bets[ns.Me()])
        self.sent = self.G.EncodeSlip(self.slip)
        self.sendAt = nil
    end

    -- The ball landed (here or for the thrower): play it out.
    local last = s.last
    local key = last and (s.id .. ":" .. last.round)
    if key ~= self.lastKey then
        local fresh = self.lastId == s.id
        self.lastKey = key
        if last and fresh then
            self:Land(last.number, last.thrower ~= ns.Me())
        elseif last then
            self.mode = "rest"
            self.restN, self.shownN = last.number, last.number
            self.ballAngle = (self.G.POCKET[last.number] - 1) * STEP
            self.ballR = POCKET_R
            self.ball:Show()
            self:PlaceBall()
        end
    end
    self.lastId = s.id

    self.banner:SetText(s.banner or "")
    self:DrawResult(s)
    self:DrawChips(s)

    local me = ns.Me()
    for i, p in ipairs(s.players) do
        local row = self.list:Row(i)
        local name = p.name
        if p.name == me then name = "|cffffd100" .. name .. "|r" end
        if p.house then name = name .. " |cffaaaaaa(house)|r" elseif p.bot then name = name .. " |cff888888(bot)|r" end
        if s.thrower == p.name and s.phase == "rolling" then name = name .. " |cffffd100(throws)|r" end
        name = name .. W.PlayerTag(p)
        row.name:SetText(name)
        row.net:SetText(s.phase == "lobby" and "" or ns.Signed(p.net or 0))
        row.net:SetShown(not W.UpdateSkip(row.skip, self.kind, s, p.name))
    end
    self.list:SetCount(#s.players)
    self:RefreshButtons(s)
end

function P:RefreshButtons(s)
    local S, me, G = ns.Session, ns.Me(), self.G
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local canBet = self:CanBet(s)
    local show = {
        join = S.CanJoin(s) and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and S.CanJoin(s),
        start = s.phase == "lobby" and host,
        throw = s.phase == "rolling" and seated and s.house ~= me,
        clear = s.phase == "rolling" and seated and s.house ~= me,
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
    self.buttons.throw:SetEnabled(S.MyTurn(s) and not S.HostOffline(s) and not self.throwing)
    self.buttons.clear:SetEnabled(canBet and next(self.slip) ~= nil)
    self.buttons.join:SetEnabled(not s._joining and #s.players < G.maxPlayers)
    self.buttons.bot:SetEnabled(S.CanAddBot(s))

    local hint = ""
    if s.phase == "lobby" then
        hint = host and (s.test and "Gazlowe runs the table; you play." or "You are the house. Waiting for players.")
            or (seated and ("Waiting for " .. s.house .. " to open the table.") or "")
    elseif s.phase == "rolling" and s.house == me then
        hint = "You are the house. " .. tostring(s.thrower or "Nobody") .. " throws the ball."
    elseif s.phase == "rolling" and seated then
        local chips = G.SlipChips(self.slip)
        hint = "Chip " .. ns.Money(s.chip) .. ". Your bets: " .. chips .. (chips == 1 and " chip" or " chips")
            .. (chips > 0 and (" (" .. ns.Money(chips * s.chip) .. ")") or "")
        if self.limitNote then hint = "|cffff6060" .. self.limitNote .. "|r" end
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
ns.CustomPages.roulette = P.New

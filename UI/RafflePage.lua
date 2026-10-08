-- RafflePage: a big golden ticket with the pot on the left, everyone's
-- tickets on the right, and your ticket count along the bottom.
--
-- The draw: the number on the ticket spins through the ticket numbers,
-- slows down and stops on the drawn one; then the winner's portrait shows
-- and coins fly to it. Only a show: the organizer's /roll decides.
local ADDON, ns = ...

local W = ns.Widgets
local C = ns.Cards
local GP = ns.GamePage
local P = setmetatable({}, { __index = GP })
P.__index = P
ns.RafflePage = P

local function Session(self) return ns.Session.Get(self.kind) end
local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function BuildRow(row)
    row.chance = W.Label(row, "", "GameFontHighlightSmall")
    row.chance:SetPoint("RIGHT", -4, 0)
    row.count = W.Label(row, "", "GameFontNormalSmall")
    row.count:SetPoint("RIGHT", -46, 0)
    row.name = W.Label(row, "", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.skip = W.SkipButton(row)
    row.skip:SetPoint("RIGHT", -2, 0)
end

function P:BuildStage(v)
    local stage = W.Panel(v)
    stage:SetPoint("TOPLEFT")
    stage:SetPoint("BOTTOMLEFT", 0, 66)
    stage:SetWidth(300)
    local felt = stage:CreateTexture(nil, "BORDER", nil, 2)
    felt:SetPoint("TOPLEFT", 3, -3)
    felt:SetPoint("BOTTOMRIGHT", -3, 3)
    felt:SetColorTexture(0.20, 0.07, 0.24, 0.8)
    self.stage = stage

    self.pot = W.BigLabel(stage, 22, "GameFontNormalHuge")
    self.pot:SetPoint("TOP", 0, -14)
    self.sold = W.Label(stage, "", "GameFontHighlight")
    self.sold:SetPoint("TOP", self.pot, "BOTTOM", 0, -4)

    local ticket = CreateFrame("Frame", nil, stage)
    ticket:SetSize(256, 128)
    ticket:SetPoint("TOP", 0, -62)
    local tex = ticket:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\AddOns\\FlintarsFunNGames\\Art\\RaffleTicket")
    self.ticket = ticket
    self.number = W.BigLabel(ticket, 44, "GameFontNormalHuge")
    self.number:SetPoint("CENTER", -26, 0)
    self.number:SetTextColor(0.45, 0.25, 0.05)
    self.number:SetShadowOffset(0, 0)

    -- The winner, under the ticket.
    self.winnerPortrait = W.Portrait(stage, 44)
    self.winnerPortrait:SetPoint("TOP", ticket, "BOTTOM", -60, -8)
    self.winnerPortrait:Hide()
    self.winner = W.Label(stage, "", "GameFontNormalLarge")
    self.winner:SetPoint("LEFT", self.winnerPortrait, "RIGHT", 8, 6)
    self.winnerLine = W.Label(stage, "", "GameFontHighlight")
    self.winnerLine:SetPoint("TOPLEFT", self.winner, "BOTTOMLEFT", 0, -3)

    self.banner = W.Label(stage, "", "GameFontHighlightSmall")
    self.banner:SetPoint("BOTTOM", 0, 10)
    self.banner:SetPoint("LEFT", 10, 0)
    self.banner:SetPoint("RIGHT", -10, 0)

    stage:SetScript("OnUpdate", function() self:Animate(Now()) end)
end

function P:BuildList(v)
    local panel = W.Panel(v, "Tickets")
    panel:SetPoint("TOPLEFT", self.stage, "TOPRIGHT", 8, 0)
    panel:SetPoint("BOTTOMRIGHT", 0, 66)
    self.list = W.ScrollList(panel, 20, BuildRow)
    self.list:Inset(6, -28, 6, 6)
    self.listPanel = panel
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
    Add("join", "Join", 70, function() S.Join(kind) end, "Join", "Take part in the raffle.")
    Add("leave", "Leave", 70, function() S.Leave(kind) end, "Leave", "Step out before sales open.")
    Add("bot", "+ Bot", 64, function() S.AddBot(kind) end, "Add a bot", "A fake player who buys a few tickets (practice only).")
    Add("start", "Open sales", 100, function()
        local ok, why = S.Start(kind)
        if not ok and why then self.hint:SetText("|cffff6060" .. why .. "|r") end
    end, "Open sales", "Let everyone buy tickets.")
    Add("draw", "Draw winner", 110, function() self:Draw() end, "Draw winner",
        "Close sales and draw one ticket with a real /roll 1 - tickets sold.")
    Add("cancel", "Cancel", 70, function()
        W.Confirm("Cancel the raffle? No one pays.", function() S.Cancel(kind) end)
    end, "Cancel", "Call it off. No one pays.")
    Add("again", "New raffle", 96, function()
        local test = Session(self).test
        S.Dismiss(kind)
        self:Open(test)
    end, "New raffle", "Start another raffle with the same price.")
    Add("close", "Close", 70, function() S.Dismiss(kind) end, "Close", "Put the raffle away.")

    -- Your tickets: - count +, then Buy.
    self.mineLabel = W.Label(v, "Your tickets", "GameFontNormal")
    self.mineLabel:SetPoint("BOTTOMLEFT", 6, 40)
    self.minus = W.Button(v, "-", 24, function() self:Step(-1) end, 20)
    self.minus:SetPoint("LEFT", self.mineLabel, "RIGHT", 8, 0)
    self.mine = W.Label(v, "0", "GameFontNormalLarge")
    self.mine:SetPoint("LEFT", self.minus, "RIGHT", 6, 0)
    self.mine:SetWidth(28)
    self.plus = W.Button(v, "+", 24, function() self:Step(1) end, 20)
    self.plus:SetPoint("LEFT", self.mine, "RIGHT", 6, 0)
    self.buy = W.Button(v, "Buy", 70, function() self:Buy() end, 20)
    self.buy:SetPoint("LEFT", self.plus, "RIGHT", 8, 0)
    W.Tooltip(self.buy, "Buy", "Set how many tickets you hold. You pay the price for each when the raffle is settled.")
    self.cost = W.Label(v, "", "GameFontHighlightSmall")
    self.cost:SetPoint("LEFT", self.buy, "RIGHT", 8, 0)

    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 4, 9)
    self.hint:SetJustifyH("LEFT")
end

local ORDER = { "close", "again", "cancel", "draw", "start", "bot", "leave", "join" }

function P.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind], want = 1 }, P)
    self:BuildSetup(parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    self:BuildStage(v)
    self:BuildList(v)
    self:BuildButtons(v)
    return self
end

---------------------------------------------------------------------------
-- Buying and drawing
---------------------------------------------------------------------------
function P:Step(dir)
    local s = Session(self)
    if not s then return end
    self.want = math.max(0, math.min(s.maxTickets, (self.want or 0) + dir))
    self:RefreshButtons(s)
end

function P:Buy()
    local s = Session(self)
    if not s then return end
    ns.Session.Act(self.kind, "buy:" .. self.want)
    W.PlaySound("LOOTWINDOW_COIN_SOUND")
end

-- Close sales, then the real /roll.
function P:Draw()
    local s = Session(self)
    if not (s and ns.Session.IsHost(s) and self.G.CanDraw(s)) then return end
    -- Sales close first; if a roll got lost, Draw just rolls again.
    if s.stage == "selling" then ns.Session.Act(self.kind, "close") end
    self:StartSpin()
    ns.After(s.test and 0.3 or 0.8, function() ns.Session.Roll(self.kind) end)
end

---------------------------------------------------------------------------
-- The draw animation
---------------------------------------------------------------------------
function P:StartSpin()
    local _, n = self.G.Ranges(Session(self) or { players = {} })
    self.spin = { n = math.max(1, n), next = 0, start = Now() }
end

-- The drawn ticket arrived: spin on a while, slow down, land on its number,
-- a short pause, then the winner (nothing else on the page tells before).
local SPIN_FOR, PAUSE = 3.2, 0.6

function P:Land(draw)
    self.spin = self.spin or { n = draw.tickets, next = 0, start = Now() }
    self.spin.n = draw.tickets
    self.spin.final = draw
    self.spin.ends = Now() + SPIN_FOR
end

function P:Animate(now)
    local sp = self.spin
    if not sp then return end
    if sp.final and now >= sp.ends then
        if not sp.landed then
            -- On the number: hold it a moment before saying whose it is.
            sp.landed = now
            self.number:SetText("#" .. sp.final.ticket)
            W.PlaySound("U_CHAT_SCROLL_BUTTON")
        elseif now >= sp.landed + PAUSE then
            self.spin = nil
            self:ShowWinner(sp.final, true)
        end
        return
    end
    if not sp.final and now - sp.start > 8 then -- the roll never came
        self.spin = nil
        self.number:SetText("")
        ns.Changed()
        return
    end
    if now >= sp.next then
        -- Ticks slow down as the end comes near.
        local left = sp.final and math.max(0, sp.ends - now) or 2
        sp.next = now + 0.04 + (2 - math.min(2, left)) * 0.14
        self.number:SetText("#" .. math.random(1, sp.n))
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
    end
end

function P:ShowWinner(draw, animate)
    local s = Session(self)
    self.revealed = s and (s.id .. ":" .. draw.ticket)
    self.number:SetText("#" .. draw.ticket)
    local _, p = ns.Session.Find(s, draw.winner)
    self.winnerPortrait:SetPlayer(draw.winner, p and p.class)
    self.winnerPortrait:Show()
    self.winner:SetText(draw.winner .. " wins!")
    self.winnerLine:SetText(ns.Money(draw.pot - draw.cut) .. (draw.cut > 0 and ("  (" .. ns.Money(draw.cut) .. " to the organizer)") or ""))
    if animate then
        for i = 1, 10 do
            C.Coin(self.stage, 0, 40, -60 + math.random(-10, 10), -110, i * 0.05)
        end
        W.PlaySound(draw.winner == ns.Me() and "LEVELUP" or "LOOTWINDOW_COIN_SOUND")
        ns.Changed() -- the list and the banner may tell now
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
        self.drawKey, self.lastId, self.spin, self.revealed = nil, nil, nil, nil
        return self:RefreshSetup()
    end

    -- The draw: play it once (or just show it when opening the page later).
    local draw = s.draw
    local key = draw and (s.id .. ":" .. draw.ticket)
    if key ~= self.drawKey then
        local fresh = self.lastId == s.id
        self.drawKey = key
        if draw and fresh then
            self:Land(draw)
        elseif draw then
            self:ShowWinner(draw, false)
        end
    end
    if not draw then
        self.winnerPortrait:Hide()
        self.winner:SetText("")
        self.winnerLine:SetText("")
        if not self.spin then self.number:SetText("") end
    end
    if self.lastId ~= s.id then self.want = (s.tickets and s.tickets[ns.Me()]) or 1 end
    self.lastId = s.id

    local pot, n = self.G.Pot(s)
    self.pot:SetText("Pot " .. (pot > 0 and ns.Money(pot) or "0"))
    self.sold:SetText(n .. (n == 1 and " ticket" or " tickets") .. " at " .. ns.Money(s.price)
        .. ((s.cut or 0) > 0 and ("  (" .. s.cut .. "% to " .. s.host .. ")") or ""))
    -- While the ticket spins, nothing tells who won.
    local hide = draw ~= nil and self.revealed ~= key
    self.banner:SetText(hide and "Drawing the winning ticket..." or (s.banner or ""))

    -- Everyone's tickets: numbers and chance.
    local ranges = self.G.Ranges(s)
    local held = {}
    for _, r in ipairs(ranges) do held[r.name] = r end
    local me = ns.Me()
    for i, p in ipairs(s.players) do
        local row = self.list:Row(i)
        local name = p.name
        if p.name == me then name = "|cffffd100" .. name .. "|r" end
        if p.name == s.host then name = name .. " |cffaaaaaa(organizer)|r" end
        if p.bot then name = name .. " |cff888888(bot)|r" end
        row.name:SetText(name .. W.PlayerTag(p))
        local r = held[p.name]
        if r then
            row.count:SetText(r.count .. "x  #" .. r.from .. (r.to > r.from and ("-" .. r.to) or ""))
            row.chance:SetText(math.floor(r.count / n * 100 + 0.5) .. "%")
        else
            row.count:SetText("|cff888888no tickets|r")
            row.chance:SetText("")
        end
        if draw and not hide and draw.winner == p.name then row.chance:SetText("|cffffd100Winner|r") end
        row.chance:SetShown(not W.UpdateSkip(row.skip, self.kind, s, p.name))
    end
    self.list:SetCount(#s.players)
    self.listPanel.title:SetText("Tickets (" .. n .. ")")
    self:RefreshButtons(s)
end

function P:RefreshButtons(s)
    local S, me, G = ns.Session, ns.Me(), self.G
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local away = S.HostOffline(s)
    local show = {
        join = S.CanJoin(s) and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and S.CanJoin(s),
        start = s.phase == "lobby" and host,
        draw = s.phase == "rolling" and host,
        cancel = host and S.IsActive(s),
        again = host and not S.IsActive(s),
        close = not S.IsActive(s) or away,
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
    self.buttons.draw:SetEnabled(G.CanDraw(s) and not self.spin)
    self.buttons.join:SetEnabled(not s._joining and #s.players < G.maxPlayers)
    self.buttons.bot:SetEnabled(S.CanAddBot(s))

    -- Your tickets row: visible during the raffle, usable while sales are open.
    local buying = s.phase == "rolling" and seated and s.stage == "selling" and not away
    for _, w in ipairs({ self.mineLabel, self.minus, self.mine, self.plus, self.buy, self.cost }) do
        w:SetShown(s.phase == "rolling" and seated)
    end
    local have = s.tickets and s.tickets[me] or 0
    self.mine:SetText(tostring(self.want))
    self.minus:SetEnabled(buying and self.want > 0)
    self.plus:SetEnabled(buying and self.want < s.maxTickets)
    self.buy:SetEnabled(buying and self.want ~= have)
    self.cost:SetText((have > 0 and ("You hold " .. have .. ": " .. ns.Money(have * s.price)) or "You hold none")
        .. (self.want ~= have and ("  -> " .. self.want) or ""))

    local hint = ""
    if s.phase == "lobby" then
        hint = host and "You organize. Waiting for players." or (seated and ("Waiting for " .. s.host .. " to open sales.") or "")
    elseif s.phase == "rolling" and host then
        hint = G.CanDraw(s) and "Draw when everyone has their tickets." or "At least two players need tickets."
    elseif s.phase == "done" and s.result then
        local parts = {}
        for _, t in ipairs(s.result.transfers or {}) do
            table.insert(parts, t.payer .. " pays " .. t.payee .. " " .. ns.Money(t.amount))
        end
        hint = #parts > 0 and table.concat(parts, ", ") or "No one pays."
        if s.test then hint = hint .. " |cff888888(practice)|r" end
    end
    if away then hint = W.HOST_OFFLINE end
    self.hint:SetText(hint)
    if right then self.hint:SetPoint("RIGHT", right, "LEFT", -8, 0) end
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.raffle = P.New

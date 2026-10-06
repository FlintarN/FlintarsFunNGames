-- BlackjackPage: the dealer along the top, up to five players along the
-- bottom, the shoe on the left. Same cards and dealing as poker
-- (ns.Cards: the card widget, ns.Cards.Deal: fly from the deck and turn).
--
-- Like the poker page it compares each new copy of the game with the last
-- one it drew and animates the difference: cards fly from the shoe, the
-- dealer's hidden card turns over, coins move with the results.
local ADDON, ns = ...

local W = ns.Widgets
local C = ns.Cards
local GP = ns.GamePage
local P = setmetatable({}, { __index = GP })
P.__index = P
ns.BlackjackPage = P

local CARD, DEALER_CARD = 30, 38
local SHOE = { -205, 108 }
local SEAT_W, SEAT_H, SEAT_Y = 100, 64, -116
local MAX_SEATS = 5

local function Session(self) return ns.Session.Get(self.kind) end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function BuildSeat(parent)
    local seat = W.Panel(parent)
    seat:SetSize(SEAT_W, SEAT_H)
    seat.portrait = W.Portrait(seat, 34)
    seat.portrait:SetPoint("TOPLEFT", 3, -4)
    -- Three short lines next to the portrait: name, bet, running total;
    -- the hand's status (Stands, Bust, Wins 30s) along the bottom.
    seat.name = W.Label(seat, "", "GameFontNormalSmall")
    seat.name:SetPoint("TOPLEFT", 40, -6)
    seat.name:SetPoint("RIGHT", -4, 0)
    seat.name:SetJustifyH("LEFT")
    seat.name:SetWordWrap(false)
    seat.bet = W.Label(seat, "", "GameFontHighlightSmall")
    seat.bet:SetPoint("TOPLEFT", seat.name, "BOTTOMLEFT", 0, -2)
    seat.bet:SetPoint("RIGHT", -4, 0)
    seat.bet:SetJustifyH("LEFT")
    seat.bet:SetWordWrap(false)
    seat.net = W.Label(seat, "", "GameFontHighlightSmall")
    seat.net:SetPoint("TOPLEFT", seat.bet, "BOTTOMLEFT", 0, -2)
    seat.status = W.Label(seat, "", "GameFontHighlightSmall")
    seat.status:SetPoint("BOTTOMLEFT", 6, 5)
    seat.status:SetPoint("RIGHT", -4, 0)
    seat.status:SetJustifyH("LEFT")
    seat.skip = W.SkipButton(seat)
    seat.skip:SetPoint("BOTTOMRIGHT", -3, 3)
    seat.cards = {}
    return seat
end

function P:BuildTable(v)
    local t = W.Panel(v)
    t:SetPoint("TOPLEFT")
    t:SetPoint("BOTTOMRIGHT", 0, 66)
    local felt = t:CreateTexture(nil, "BORDER", nil, 2)
    felt:SetPoint("TOPLEFT", 3, -3)
    felt:SetPoint("BOTTOMRIGHT", -3, 3)
    felt:SetColorTexture(0.09, 0.36, 0.19, 0.8)
    self.tablePanel = t

    -- The shoe: a short stack of backs.
    for k = 3, 1, -1 do
        local d = C.New(t, DEALER_CARD)
        d:SetCard(0)
        d:Place(SHOE[1] - k, SHOE[2] + k)
    end

    -- The dealer.
    self.dealerPortrait = W.Portrait(t, 40)
    self.dealerPortrait:SetPoint("CENTER", t, "CENTER", -120, 112)
    self.dealerName = W.Label(t, "", "GameFontNormal")
    self.dealerName:SetPoint("TOP", self.dealerPortrait, "BOTTOM", 0, -2)
    self.dealerTotal = W.Label(t, "", "GameFontNormalLarge")
    self.dealerTotal:SetPoint("LEFT", t, "CENTER", 110, 112)
    self.dealerCards = {}

    -- One message line in the middle of the table.
    self.banner = W.Label(t, "", "GameFontNormal")
    self.banner:SetPoint("CENTER", t, "CENTER", 0, 44)
    self.banner:SetWidth(480)
    self.check = W.Label(t, "", "GameFontDisableSmall")
    self.check:SetPoint("TOPRIGHT", -10, -8)

    self.seats = {}
    for i = 1, MAX_SEATS do
        local seat = BuildSeat(t)
        seat.total = W.Label(t, "", "GameFontNormal")
        self.seats[i] = seat
    end
end

-- A card on a hand, made when first needed. Later cards draw over earlier
-- ones (each its own frame level, so suits never show through).
local function HandCard(parent, list, k, size, base)
    local card = list[k]
    if not card then
        card = C.New(parent, size)
        card.frame:SetFrameLevel(base + k * 3)
        list[k] = card
    end
    return card
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
    local function Act(action) return function() S.Act(kind, action) end end
    Add("join", "Join", 70, function() S.Join(kind) end, "Join", "Take a seat at the table.")
    Add("leave", "Leave", 70, function() S.Leave(kind) end, "Leave", "Get up before the table opens.")
    Add("bot", "+ Bot", 64, function() S.AddBot(kind) end, "Add a bot", "A fake player (practice only).")
    Add("start", "Open table", 100, function()
        local ok, why = S.Start(kind)
        if not ok and why then self.hint:SetText("|cffff6060" .. why .. "|r") end
    end, "Open table", "Let the bets begin.")
    Add("deal", "Deal", 70, function() S.Roll(kind) end, "Deal",
        "Cut the sealed deck with a real /roll 1-1000000 and deal. Bets close.")
    Add("hit", "Hit", 60, Act("hit"), "Hit", "Take another card.")
    Add("stand", "Stand", 64, Act("stand"), "Stand", "Keep what you have.")
    Add("double", "Double", 70, Act("double"), "Double", "Double your bet, take exactly one more card.")
    Add("next", "Next round", 96, Act("next"), "Next round", "Clear the table and open the bets again.")
    Add("endTable", "Close table", 96, function()
        W.Confirm("Close the table and settle up?", function() S.Act(kind, "end") end)
    end, "Close table", "Stop and work out who pays whom.")
    Add("cancel", "Cancel", 70, function()
        W.Confirm("Cancel this game? No one pays.", function() S.Cancel(kind) end)
    end, "Cancel", "Stop the game. No one pays.")
    Add("again", "Play again", 90, function()
        local test = Session(self).test
        S.Dismiss(kind)
        self:Open(test)
    end, "Play again", "Open the table again with the same bets.")
    Add("close", "Close", 70, function() S.Dismiss(kind) end, "Close", "Put the table away.")

    -- Your bet, on its own row above the buttons.
    local box = W.MoneyBox(v)
    box:SetPoint("BOTTOMLEFT", 70, 36)
    box.onEnter = function() self:PlaceBet() end
    self.betBox = box
    self.betLabel = W.Label(v, "Your bet", "GameFontNormal")
    self.betLabel:SetPoint("RIGHT", box, "LEFT", -6, 0)
    self.placeBet = W.Button(v, "Place bet", 84, function() self:PlaceBet() end, 20)
    self.placeBet:SetPoint("LEFT", box, "RIGHT", 6, 0)
    W.Tooltip(self.placeBet, "Place bet", function()
        local s = Session(self)
        return s and ("Between " .. ns.Money(s.minBet) .. " and " .. ns.Money(s.maxBet) .. ".") or nil
    end)
    self.removeBet = W.Button(v, "Sit out", 70, function() S.Act(kind, "bet:0") end, 20)
    self.removeBet:SetPoint("LEFT", self.placeBet, "RIGHT", 4, 0)
    W.Tooltip(self.removeBet, "Sit out", "No bet this round: you're not dealt in.")

    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 4, 9)
    self.hint:SetJustifyH("LEFT")
end

local ORDER = { "close", "again", "endTable", "cancel", "next", "double", "stand", "hit", "deal", "start", "bot", "leave", "join" }

function P.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind] }, P)
    self:BuildSetup(parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    self:BuildTable(v)
    self:BuildButtons(v)
    return self
end

function P:PlaceBet()
    local s = Session(self)
    if not s then return end
    self.betBox:ClearFocus()
    local amount = math.max(s.minBet, math.min(s.maxBet, self.betBox:GetCopper()))
    self.betBox:SetCopper(amount)
    ns.Session.Act(self.kind, "bet:" .. amount)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- The players at the table (not the dealer), in seat order.
local function Seated(s)
    local list = {}
    for _, p in ipairs(s.players) do
        if not p.house and #list < MAX_SEATS then table.insert(list, p) end
    end
    return list
end

local function SeatX(i, n) return (i - (n + 1) / 2) * 106 end
local function HandPos(seat, k) return seat.x - 22 + (k - 1) * 15, SEAT_Y + SEAT_H / 2 + 34 end
local function DealerPos(k) return -50 + (k - 1) * 26, 108 end

function P:ClearCards()
    for _, seat in ipairs(self.seats) do
        for _, card in ipairs(seat.cards) do C.Deal(card, nil) end
    end
    for _, card in ipairs(self.dealerCards) do C.Deal(card, nil) end
end

function P:Refresh()
    local s = Session(self)
    self.setup:SetShown(s == nil)
    self.game:SetShown(s ~= nil)
    if not s then
        self.prev = nil
        self:ClearCards()
        return self:RefreshSetup()
    end
    local prev = self.prev
    local animate = prev ~= nil and prev.id == s.id
    if not animate or prev.round ~= s.round then self:ClearCards() end
    local t = self.tablePanel
    local base = t:GetFrameLevel()
    local players = Seated(s)

    -- Seats
    for i, seat in ipairs(self.seats) do
        local p = players[i]
        seat:SetShown(p ~= nil)
        seat.total:SetShown(p ~= nil)
        if p then
            seat.x = SeatX(i, #players)
            seat:ClearAllPoints()
            seat:SetPoint("CENTER", t, "CENTER", seat.x, SEAT_Y)
            seat.total:ClearAllPoints()
            seat.total:SetPoint("CENTER", t, "CENTER", seat.x, SEAT_Y + SEAT_H / 2 + 68)
        end
    end

    -- Cards: dealt round-robin as at a real table (first cards, then hits).
    local delay = 0
    local most = #(s.dealer or {})
    for _, p in ipairs(players) do most = math.max(most, p.hand and #p.hand or 0) end
    for k = 1, math.max(most, 2) do
        for i, p in ipairs(players) do
            local seat = self.seats[i]
            local want = p.hand and p.hand[k] or nil
            if want or seat.cards[k] then
                local card = HandCard(t, seat.cards, k, CARD, base + 6)
                local x, y = HandPos(seat, k)
                delay = C.Deal(card, want, x, y, animate, delay, SHOE[1], SHOE[2])
            end
        end
        local want = s.dealer and s.dealer[k] or nil
        if want or self.dealerCards[k] then
            local card = HandCard(t, self.dealerCards, k, DEALER_CARD, base + 6)
            local x, y = DealerPos(k)
            delay = C.Deal(card, want, x, y, animate, delay, SHOE[1], SHOE[2])
        end
    end

    -- Seat texts
    local me = ns.Me()
    for i, p in ipairs(players) do
        local seat = self.seats[i]
        local name = p.name
        if p.name == me then name = "|cffffd100" .. name .. "|r" end
        if p.bot then name = "|cffaaaaaa" .. name .. "|r" end -- bots in grey
        seat.name:SetText(name .. W.PlayerTag(p))
        seat.portrait:SetPlayer(p.name, p.class, p.out or p.offline or p.state == "bust")
        local bet = p.wager or (s.bets and s.bets[p.name])
        seat.bet:SetText(bet and ("Bet " .. ns.Money(bet)) or "|cff888888No bet|r")
        seat.net:SetText(ns.Signed(p.net or 0))
        local status, total = "", ""
        if p.hand then
            local v = self.G.Total(p.hand)
            total = tostring(v)
            if p.state == "bust" then
                status, total = "|cffff5050Bust|r", "|cffff5050" .. v .. "|r"
            elseif self.G.IsBlackjack(p.hand) then
                status, total = "|cffffd100Blackjack!|r", "|cffffd100BJ|r"
            elseif p.state == "stand" then
                status = "Stands"
            end
        end
        if p.result then
            status = p.result > 0 and ("|cff40ff40Wins|r " .. ns.Money(p.result))
                or (p.result < 0 and ("|cffff5050Loses|r " .. ns.Money(-p.result)) or "Push")
        end
        seat.status:SetText(status)
        seat.total:SetText(total)
        local turn = ns.Session.IsTurn(s, p.name)
        if seat.SetBackdropBorderColor then
            if turn then seat:SetBackdropBorderColor(1, 0.85, 0.2, 1) else seat:SetBackdropBorderColor(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 1) end
        end
        local can = W.UpdateSkip(seat.skip, self.kind, s, p.name)
        seat.status:SetShown(not can)
    end

    -- The dealer
    local _, house = ns.Session.Find(s, s.house)
    if house then self.dealerPortrait:SetPlayer(house.name, house.class) end
    self.dealerName:SetText("Dealer: " .. tostring(s.house))
    if s.dealer and #s.dealer > 0 then
        local shown = {}
        for _, c in ipairs(s.dealer) do if c > 0 then table.insert(shown, c) end end
        local v = self.G.Total(shown)
        self.dealerTotal:SetText(v > 21 and ("|cffff5050" .. v .. "|r") or tostring(v))
    else
        self.dealerTotal:SetText("")
    end

    self.banner:SetText(s.banner or "")
    local ok = self.G.Verify(s)
    if ok == true then
        self.check:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t Deal checked: it matches the sealed deck")
    elseif ok == false then
        self.check:SetText("|cffff5050The deal does NOT match the sealed deck!|r")
    elseif s.commit then
        self.check:SetText("Deck sealed " .. s.commit:sub(1, 8) .. "...")
    else
        self.check:SetText("")
    end

    -- Results: coins to winners, from losers to the dealer.
    if animate and s.stage == "over" and prev.stage ~= "over" then
        local won = false
        for i, p in ipairs(players) do
            local seat = self.seats[i]
            if p.result and p.result > 0 then
                for c = 0, 3 do C.Coin(t, -120, 112, seat.x, SEAT_Y, 0.4 + c * 0.07) end
                if p.name == me then won = true end
            elseif p.result and p.result < 0 then
                C.Coin(t, seat.x, SEAT_Y, -120, 112, 0.4)
            end
        end
        ns.After(0.4, function() W.PlaySound(won and "LOOTWINDOW_COIN_SOUND" or "U_CHAT_SCROLL_BUTTON") end)
    end

    self.prev = { id = s.id, round = s.round, stage = s.stage }
    self:RefreshButtons(s)
end

function P:RefreshButtons(s)
    local S, me, G = ns.Session, ns.Me(), self.G
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local playing = s.phase == "rolling"
    local _, mine = S.Find(s, me)
    local player = seated and mine and not mine.house
    local away = S.HostOffline(s)
    local show = {
        join = S.CanJoin(s) and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and S.CanJoin(s),
        start = s.phase == "lobby" and host,
        deal = playing and player,
        hit = playing and player,
        stand = playing and player,
        double = playing and player,
        next = playing and host,
        endTable = playing and host,
        cancel = s.phase == "lobby" and host,
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
    local myTurn = G:IsTurn(s, me) and not away
    self.buttons.start:SetEnabled(#s.players >= G.minPlayers)
    self.buttons.deal:SetEnabled(G:Expect(s, me) ~= nil and not away)
    self.buttons.hit:SetEnabled(myTurn)
    self.buttons.stand:SetEnabled(myTurn)
    self.buttons.double:SetEnabled(myTurn and G.CanDouble(s, me))
    self.buttons.next:SetEnabled(s.stage == "over")
    self.buttons.join:SetEnabled(not s._joining and #s.players < G.maxPlayers)
    self.buttons.bot:SetEnabled(S.CanAddBot(s))

    -- Your bet row: during the game, usable while bets are open.
    local betting = playing and player and s.stage == "bets" and not mine.out and not away
    for _, w in ipairs({ self.betBox, self.betLabel, self.placeBet, self.removeBet }) do w:SetShown(playing and player) end
    self.betBox:SetEnabled(betting)
    self.placeBet:SetEnabled(betting)
    self.removeBet:SetEnabled(betting and s.bets[me] ~= nil)
    local key = s.id .. ":" .. tostring(s.round)
    if key ~= self.betKey then
        self.betKey = key
        self.betBox:SetCopper(s.bets and s.bets[me] or s.minBet)
    end

    local hint = ""
    if s.phase == "lobby" then
        hint = host and (s.test and "Gazlowe deals; you play." or "You deal. Waiting for players.")
            or (seated and ("Waiting for " .. s.house .. " to open the table.") or "")
    elseif playing and s.house == me then
        hint = "You deal. " .. (G:Status(s) or "")
    elseif playing and player then
        if s.stage == "bets" then
            hint = s.bets[me] and ("Bet placed: " .. ns.Money(s.bets[me])) or "No bet yet"
        elseif mine.hand then
            hint = "You have " .. G.Total(mine.hand)
        end
    elseif s.phase == "done" and s.result then
        local parts = {}
        for _, tr in ipairs(s.result.transfers or {}) do
            table.insert(parts, tr.payer .. " pays " .. tr.payee .. " " .. ns.Money(tr.amount))
        end
        hint = #parts > 0 and table.concat(parts, ", ") or "Everyone broke even."
        if s.test then hint = hint .. " |cff888888(practice)|r" end
    end
    if away then hint = W.HOST_OFFLINE end
    self.hint:SetText(hint)
    if right then self.hint:SetPoint("RIGHT", right, "LEFT", -8, 0) end
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.blackjack = P.New

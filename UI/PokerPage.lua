-- PokerPage: the poker table. Six seats around a felt table, the board in
-- the middle, the deck on the left. You sit at the bottom, cards face up.
--
-- The page compares each new copy of the game with the last one it drew and
-- animates the difference: cards fly from the deck and turn over, coins fly
-- into the pot and out to the winner, the dealer button slides along.
-- Opening the page (or a new game) just draws everything in place.
local ADDON, ns = ...

local W = ns.Widgets
local C = ns.Cards
local GP = ns.GamePage
local P = setmetatable({}, { __index = GP })
P.__index = P
ns.PokerPage = P

-- Seat centres on the table (table centre = 0,0); slot 1 is you.
local SEATS = { { 0, -110 }, { -180, -98 }, { -180, 98 }, { 0, 110 }, { 180, 98 }, { 180, -98 } }
local SEAT_W, SEAT_H = 150, 60
local SMALL, BOARD = 22, 38
local DECK = { -150, 0 }
local POT = { 0, 44 }

local function Session(self) return ns.Session.Get(self.kind) end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function BuildSeat(parent)
    local seat = W.Panel(parent)
    seat:SetSize(SEAT_W, SEAT_H)

    seat.glow = seat:CreateTexture(nil, "BACKGROUND", nil, -1)
    seat.glow:SetPoint("TOPLEFT", -5, 5)
    seat.glow:SetPoint("BOTTOMRIGHT", 5, -5)
    seat.glow:SetColorTexture(1, 0.8, 0.2, 0.7)
    seat.glow:Hide()
    if seat.glow.CreateAnimationGroup then
        local ag = seat.glow:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        if a.SetFromAlpha then
            a:SetFromAlpha(0.25)
            a:SetToAlpha(1)
        end
        a:SetDuration(0.7)
        seat.pulse = ag
    end

    -- Portrait on the left; the hole cards fan over its lower corner.
    seat.portrait = W.Portrait(seat, 44)
    seat.portrait:SetPoint("LEFT", 5, 1)

    seat.name = W.Label(seat, "", "GameFontNormal")
    seat.name:SetPoint("TOPLEFT", 64, -9)
    seat.name:SetPoint("RIGHT", seat, "RIGHT", -6, 0)
    seat.name:SetJustifyH("LEFT")
    seat.name:SetWordWrap(false)
    seat.net = W.Label(seat, "", "GameFontHighlightSmall")
    seat.net:SetPoint("TOPLEFT", seat.name, "BOTTOMLEFT", 0, -4)
    seat.status = W.Label(seat, "", "GameFontHighlightSmall")
    seat.status:SetPoint("TOPLEFT", seat.net, "BOTTOMLEFT", 0, -3)
    seat.status:SetTextColor(0.85, 0.85, 0.85)
    seat.skip = W.SkipButton(seat)
    seat.skip:SetPoint("BOTTOMRIGHT", -4, 4)
    return seat
end

function P:BuildTable(v)
    local t = W.Panel(v)
    t:SetPoint("TOPLEFT")
    t:SetPoint("BOTTOMRIGHT", 0, 64)
    local felt = t:CreateTexture(nil, "BORDER", nil, 2)
    felt:SetPoint("TOPLEFT", 3, -3)
    felt:SetPoint("BOTTOMRIGHT", -3, 3)
    felt:SetColorTexture(0.09, 0.36, 0.19, 0.8)
    -- A lighter oval in the middle, like a table's playing area.
    local spot = t:CreateTexture(nil, "BORDER", nil, 3)
    spot:SetSize(330, 150)
    spot:SetPoint("CENTER")
    spot:SetColorTexture(0.2, 0.55, 0.3, 0.25)
    self.tablePanel = t

    self.seats = {}
    for i, pos in ipairs(SEATS) do
        local seat = BuildSeat(t)
        seat:SetPoint("CENTER", t, "CENTER", pos[1], pos[2])
        seat.x, seat.y = pos[1], pos[2]
        seat.cards = { C.New(t, SMALL), C.New(t, SMALL) }
        -- Cards draw over the portrait, the right one over the left one. Each
        -- card needs its own frame level, or the back card's suit symbols
        -- (a higher draw layer) show through the front card.
        for k, card in ipairs(seat.cards) do card.frame:SetFrameLevel(seat:GetFrameLevel() + 4 + k * 3) end
        self.seats[i] = seat
    end

    -- The deck: two backs, slightly offset.
    for k = 2, 1, -1 do
        local d = C.New(t, BOARD)
        d:SetCard(0)
        d:Place(DECK[1] - k, DECK[2] + k)
    end
    self.board = {}
    for i = 1, 5 do self.board[i] = C.New(t, BOARD) end

    self.pot = W.Label(t, "", "GameFontNormalLarge")
    self.pot:SetPoint("CENTER", t, "CENTER", POT[1], POT[2])

    self.status = W.Label(t, "", "GameFontNormal")
    self.status:SetPoint("CENTER", t, "CENTER", 0, -42)
    self.banner = W.Label(t, "", "GameFontHighlightSmall")
    self.banner:SetPoint("CENTER", t, "CENTER", 0, -57)

    self.check = W.Label(t, "", "GameFontDisableSmall")
    self.check:SetPoint("BOTTOMRIGHT", -10, 6)

    -- Dealer button: a gold coin with a D.
    local d = CreateFrame("Frame", nil, t)
    d:SetSize(20, 20)
    d:SetFrameLevel(t:GetFrameLevel() + 15)
    local dt = d:CreateTexture(nil, "ARTWORK")
    dt:SetAllPoints()
    dt:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    dt:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local dl = W.Label(d, "D", "GameFontNormalSmall")
    dl:SetPoint("CENTER", 0, 0)
    dl:SetTextColor(0.2, 0.1, 0)
    d:Hide()
    self.dealerButton = d
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
    Add("join", "Join", 80, function() S.Join(kind) end, "Join", "Take a seat at this table.")
    Add("leave", "Leave", 80, function() S.Leave(kind) end, "Leave", "Get up before the game starts.")
    Add("bot", "+ Bot", 70, function() S.AddBot(kind) end, "Add a bot", "A fake player (practice only).")
    Add("start", "Start", 80, function()
        local ok, why = S.Start(kind)
        if not ok and why then self.hint:SetText("|cffff6060" .. why .. "|r") end
    end, "Start", "Close the seats and deal the first hand.")
    Add("cut", "Cut the deck!", 130, function() S.Roll(kind) end, "Cut the deck",
        "Does a real /roll 1-1000000. The deck was sealed before your cut, so nobody could have picked it.")
    Add("fold", "Fold", 60, Act("fold"), "Fold", "Give up this hand.")
    Add("call", "Check", 90, Act("call"))

    -- Raise: type an amount (gold / silver / copper) or use Min / Pot / Max.
    -- These sit on their own row, above the move buttons.
    local box = W.MoneyBox(v)
    box.onEnter = function() self:Raise() end
    box.onChange = function() self:RaiseLabel() end
    self.buttons.box = box
    local function Quick(key, label, help, value)
        local b = Add(key, label, 40, function()
            local amount = value()
            if amount then
                box:SetCopper(amount)
                box:ClearFocus()
            end
        end, label, help)
        b:SetHeight(20)
    end
    Quick("min", "Min", "The smallest raise allowed.", function() return (self:RaiseRange()) end)
    Quick("pot", "Pot", "Raise by the size of the pot (up to the max raise).", function()
        local s, min, max = Session(self), self:RaiseRange()
        if not min then return nil end
        return math.max(min, math.min(max, s.pot or 0))
    end)
    Quick("max", "Max", "The table's max raise.", function() return select(2, self:RaiseRange()) end)
    self.buttons.max:SetPoint("BOTTOMRIGHT", 0, 32)
    self.buttons.pot:SetPoint("RIGHT", self.buttons.max, "LEFT", -2, 0)
    self.buttons.min:SetPoint("RIGHT", self.buttons.pot, "LEFT", -2, 0)
    box:SetPoint("RIGHT", self.buttons.min, "LEFT", -6, 0)
    Add("raise", "Raise", 150, function() self:Raise() end, "Raise",
        "Raise by the amount in the box. Everyone else then has to call, raise again or fold.")
    Add("deal", "Next hand", 100, Act("deal"), "Next hand", "Deal the next hand.")
    Add("endTable", "End table", 90, function()
        W.Confirm("End the table and settle up?", function() S.Act(kind, "end") end)
    end, "End table", "Stop playing and work out who pays whom.")
    Add("cancel", "Cancel", 80, function()
        W.Confirm("Cancel this game? No one pays.", function() S.Cancel(kind) end)
    end, "Cancel", "Stop the game. No one pays.")
    Add("again", "Play again", 100, function()
        local test = Session(self).test
        S.Dismiss(kind)
        self:Open(test)
    end, "Play again", "Open a new table with the same bet size.")
    Add("close", "Close", 80, function() S.Dismiss(kind) end, "Close", "Put this table away.")

    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 6, 36)
    self.hint:SetJustifyH("LEFT")
end

-- The bottom row, right to left (the raise amount row sits above it).
local ORDER = { "close", "again", "endTable", "cancel", "deal", "raise", "call", "fold",
    "cut", "start", "bot", "leave", "join" }
local RAISE_ROW = { "box", "min", "pot", "max" }

function P:RaiseRange()
    local s = Session(self)
    if not s then return nil end
    return self.G:RaiseRange(s, ns.Me())
end

-- The amount in the box, kept inside the allowed range.
function P:RaiseAmount()
    local min, max = self:RaiseRange()
    if not min then return nil end
    return math.max(min, math.min(max, self.buttons.box:GetCopper()))
end

function P:RaiseLabel()
    local s, amount = Session(self), self:RaiseAmount()
    if not (s and amount) then return end
    local verb = (s.high or 0) == 0 and "Bet " or "Raise +"
    self.buttons.raise:SetText(verb .. ns.Money(amount))
end

function P:Raise()
    local amount = self:RaiseAmount()
    if not amount then return end
    self.buttons.box:SetCopper(amount)
    ns.Session.Act(self.kind, "raise:" .. amount)
end

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

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- Which slot each player sits in: you at the bottom, the rest clockwise.
local function SlotOf(s)
    local n = #s.players
    local mine = ns.Session.Find(s, ns.Me()) or 1
    local slot = {}
    for i = 1, n do slot[i] = ((i - mine) % n) + 1 end
    return slot
end

-- Card positions on the table.
-- Over the lower right of the portrait, slightly fanned.
local function SmallPos(seat, k) return seat.x - SEAT_W / 2 + 30 + (k - 1) * 12, seat.y - 14 - (k - 1) * 2 end
local function BoardPos(i) return (i - 3) * (BOARD + 6), 0 end

-- Cards come out of the deck on the left (shared dealing: ns.Cards.Deal).
local function Show(card, want, x, y, animate, delay)
    return C.Deal(card, want, x, y, animate, delay, DECK[1], DECK[2])
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
    if not animate or prev.hand ~= s.hand then
        self:ClearCards()
        if animate then prev.nets = nil end
    end
    self:DrawSeats(s, prev, animate)
    self:DrawBoard(s, animate)
    self:DrawMoney(s, prev, animate)
    self:RefreshButtons(s)

    local nets = {}
    for _, p in ipairs(s.players) do nets[p.name] = p.net end
    self.prev = { id = s.id, hand = s.hand, stage = s.stage, dealer = s.dealer, nets = nets, pot = s.pot,
        winners = s.winners and table.concat(s.winners, ",") }
end

function P:ClearCards()
    for _, seat in ipairs(self.seats) do
        for _, c in ipairs(seat.cards) do Show(c, nil) end
    end
    for _, c in ipairs(self.board) do Show(c, nil) end
end

function P:DrawSeats(s, prev, animate)
    local me = ns.Me()
    local slots = SlotOf(s)
    local dealt = s.phase ~= "lobby" and s.stage ~= "cut" and s.stage ~= nil
    local G = self.G
    for _, seat in ipairs(self.seats) do seat:Hide() end

    -- Deal order: from the dealer's left, one card each, twice round.
    local n = #s.players
    local order = {}
    for i = 1, n do order[((i - (s.dealer or 1) - 1) % n) + 1] = i end
    local delay = 0
    for round = 1, 2 do
        for _, i in ipairs(order) do
            local p = s.players[i]
            local seat = self.seats[slots[i]]
            local want
            if dealt and not p.folded then
                want = (s.reveal and s.reveal[p.name] and s.reveal[p.name][round]) or 0
            end
            if p.name == me and dealt then
                -- Yours face up (face down until they arrive); still shown after you fold.
                local mine = ns.Session.MyCards(s)
                want = mine and mine[round] or 0
            end
            local x, y = SmallPos(seat, round)
            delay = Show(seat.cards[round], want, x, y, animate, delay)
        end
    end

    for i, p in ipairs(s.players) do
        local seat = self.seats[slots[i]]
        seat:Show()
        local name = p.name
        if p.name == me then name = "|cffffd100" .. name .. "|r" end
        if p.bot then name = name .. " |cff888888(bot)|r" end
        name = name .. W.PlayerTag(p)
        seat.name:SetText(name)
        seat.portrait:SetPlayer(p.name, p.class, (p.folded and s.stage ~= "over") or p.out or p.offline)
        seat.net:SetText(ns.Signed(p.net or 0))
        local status = ""
        local won = false
        for _, w in ipairs(s.winners or {}) do
            if w == p.name then won = true end
        end
        if s.phase == "lobby" then
            status = p.name == s.host and "Host" or "Seated"
        elseif won then
            status = "|cff40ff40Wins|r " .. ns.Money(math.floor((s.lastPot or 0) / #s.winners))
        elseif p.offline then
            status = "|cffff6060Offline|r"
        elseif p.out then
            status = "Sitting out"
        elseif p.folded then
            status = "Folded"
        elseif s.stage == "cut" and s.cutter == p.name then
            status = "Cuts the deck"
        elseif (p.bet or 0) > 0 then
            status = "Bet " .. ns.Money(p.bet)
        end
        seat.status:SetText(status)
        W.UpdateSkip(seat.skip, self.kind, s, p.name)
        seat:SetAlpha(p.folded and s.stage ~= "over" and 0.55 or 1)
        local turn = ns.Session.IsTurn(s, p.name)
        seat.glow:SetShown(turn)
        if seat.pulse then
            if turn then seat.pulse:Play() else seat.pulse:Stop() end
        end
        local hl = won and s.reveal ~= nil
        seat.cards[1]:SetHighlight(hl)
        seat.cards[2]:SetHighlight(hl)
    end

    -- Dealer button: top right of the dealer's seat, sliding when it moves.
    local d = self.dealerButton
    if s.dealer and s.phase ~= "lobby" then
        local seat = self.seats[slots[s.dealer]]
        local tx, ty = seat.x + SEAT_W / 2 - 4, seat.y + SEAT_H / 2 - 4
        d:Show()
        if animate and prev.dealer and prev.dealer ~= s.dealer and d.x then
            local fx, fy = d.x, d.y
            C.Tween(0.5, function(t)
                d:ClearAllPoints()
                d:SetPoint("CENTER", self.tablePanel, "CENTER", fx + (tx - fx) * t, fy + (ty - fy) * t)
            end)
        else
            d:ClearAllPoints()
            d:SetPoint("CENTER", self.tablePanel, "CENTER", tx, ty)
        end
        d.x, d.y = tx, ty
    else
        d:Hide()
    end

    -- Your hand, in words.
    local mine = ns.Session.MyCards(s)
    if mine and dealt then
        local cards = { mine[1], mine[2] }
        for _, c in ipairs(s.board or {}) do table.insert(cards, c) end
        self.handText = G.DescribeCards(cards)
    else
        self.handText = nil
    end
end

function P:DrawBoard(s, animate)
    local delay = 0.1
    for i = 1, 5 do
        local x, y = BoardPos(i)
        delay = Show(self.board[i], s.board and s.board[i] or nil, x, y, animate, delay)
    end

    self.pot:SetText((s.pot or 0) > 0 and ("Pot " .. ns.Money(s.pot)) or "")
    self.status:SetText(self.G:Status(s) or "")
    self.banner:SetText(s.banner or "")

    local ok = self.G.Verify(s, ns.Session.MyCards(s))
    if ok == true then
        self.check:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t Deal checked: it matches the sealed deck")
    elseif ok == false then
        self.check:SetText("|cffff5050The deal does NOT match the sealed deck!|r")
    elseif s.commit then
        self.check:SetText("Deck sealed " .. s.commit:sub(1, 8) .. "...")
    else
        self.check:SetText("")
    end
end

function P:DrawMoney(s, prev, animate)
    if not animate then return end
    local slots = SlotOf(s)
    local t = self.tablePanel
    -- Someone paid in: a coin from their seat to the pot.
    if prev.nets then
        local k = 0
        for i, p in ipairs(s.players) do
            local before = prev.nets[p.name]
            if before and p.net < before and not (s.winners and prev.stage == "over") then
                local seat = self.seats[slots[i]]
                ns.Cards.Coin(t, seat.x, seat.y, POT[1], POT[2], k * 0.08)
                k = k + 1
            end
        end
        if k > 0 then W.PlaySound("LOOTWINDOW_COIN_SOUND") end
    end
    -- A hand was won: the pot flies to the winners.
    local w = s.winners and table.concat(s.winners, ",")
    if w and w ~= prev.winners then
        for i, p in ipairs(s.players) do
            for _, name in ipairs(s.winners) do
                if name == p.name then
                    local seat = self.seats[slots[i]]
                    for c = 0, 4 do
                        ns.Cards.Coin(t, POT[1], POT[2], seat.x, seat.y, 0.6 + c * 0.07)
                    end
                end
            end
        end
        ns.After(0.6, function() W.PlaySound("LOOTWINDOW_COIN_SOUND") end)
    end
end

function P:RefreshButtons(s)
    local S, me, G = ns.Session, ns.Me(), self.G
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local playing = s.phase == "rolling"
    local options = {}
    for _, o in ipairs(G:Options(s, me)) do options[o[1]] = o[2] end
    -- During a hand your move buttons stay put, greyed out until it's your turn.
    local _, mine = S.Find(s, me)
    local inHand = playing and mine ~= nil and s.stage ~= nil and s.stage ~= "cut" and s.stage ~= "over"
        and not mine.folded
    local show = {
        join = s.phase == "lobby" and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and s.phase == "lobby",
        start = s.phase == "lobby" and host,
        cut = playing and seated and s.stage == "cut",
        fold = inHand,
        call = inHand,
        raise = inHand,
        -- The host's table buttons stay put, usable between hands.
        deal = playing and host,
        endTable = playing and host,
        cancel = s.phase == "lobby" and host,
        again = host and not S.IsActive(s),
        close = not S.IsActive(s) or S.HostOffline(s),
    }
    self.buttons.close:SetText(S.IsActive(s) and "Leave game" or "Close")
    if S.HostOffline(s) then options = {} end -- no moves while the host can't see them
    local label = options.check or options.call
    if not label and inHand then
        label = (mine.bet or 0) >= (s.high or 0) and "Check" or ("Call " .. ns.Money(s.high - mine.bet))
    end
    self.buttons.call:SetText(label or "Check")
    self.buttons.call:SetScript("OnClick", function() S.Act(self.kind, options.check and "check" or "call") end)
    self.buttons.cut:SetEnabled(G:Expect(s, me) ~= nil and not S.HostOffline(s))
    self.buttons.deal:SetEnabled(s.stage == "over")
    self.buttons.endTable:SetEnabled(s.stage == "over" or s.stage == "cut")
    self.buttons.join:SetEnabled(not s._joining and #s.players < G.maxPlayers)
    self.buttons.bot:SetEnabled(S.CanAddBot(s))
    self.buttons.fold:SetEnabled(options.fold ~= nil)
    self.buttons.call:SetEnabled((options.check or options.call) ~= nil)
    self.buttons.raise:SetEnabled(options.raise ~= nil)
    for _, key in ipairs(RAISE_ROW) do
        self.buttons[key]:SetShown(inHand and true or false)
        self.buttons[key]:SetEnabled(options.raise ~= nil)
    end
    if not options.raise then self.buttons.raise:SetText((s.high or 0) == 0 and "Bet" or "Raise") end
    -- A new turn: start the box at the smallest raise.
    local turnKey = options.raise and (s.id .. ":" .. s.hand .. ":" .. s.stage .. ":" .. s.raises) or nil
    if turnKey ~= self.raiseTurn then
        self.raiseTurn = turnKey
        local min = self:RaiseRange()
        if min then self.buttons.box:SetCopper(min) end
    end
    self:RaiseLabel()

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

    local hint = self.handText and ("|cffffd100" .. self.handText .. "|r") or ""
    if s.phase == "lobby" then
        hint = host and "Waiting for players (2-6)." or (seated and ("Waiting for " .. s.host .. " to deal.") or "")
    elseif s.phase == "done" and s.result then
        local lines = {}
        for _, t in ipairs(s.result.transfers or {}) do
            table.insert(lines, t.payer .. " pays " .. t.payee .. " " .. ns.Money(t.amount))
        end
        hint = #lines > 0 and table.concat(lines, "\n") or "Everyone broke even."
        if s.test then hint = hint .. "\n|cff888888(practice: no gold changes hands)|r" end
    elseif s.phase == "cancelled" then
        hint = "Game cancelled."
    elseif playing and not seated then
        hint = "You are watching this table."
    end
    if S.HostOffline(s) then hint = W.HOST_OFFLINE end
    self.hint:SetText(hint)
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.poker = P.New

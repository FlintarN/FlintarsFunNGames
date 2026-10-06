-- Cards: a playing card widget with our own art (Art\*.tga), plus a tiny
-- tween engine for movement and flips. Everything is done by hand in one
-- OnUpdate (positions, widths, alpha), so it works on any client.
local ADDON, ns = ...

local W = ns.Widgets
local C = {}
ns.Cards = C

local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"
local SUITS = { "SuitSpade", "SuitHeart", "SuitDiamond", "SuitClub" }
local RANK_TEXT = { [11] = "J", [12] = "Q", [13] = "K", [14] = "A" }
local CARD_V = 180 / 256 -- the card fills the top of its 128x256 texture

local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Tweens: { from, to, dur, delay, step(t 0..1), done() }
---------------------------------------------------------------------------
local tweens = {}
local driver = CreateFrame("Frame")

local function Ease(t) return 1 - (1 - t) * (1 - t) * (1 - t) end -- fast, then settle

function C.Tween(dur, step, done, delay)
    local tw = { start = Now() + (delay or 0), dur = dur, step = step, done = done }
    table.insert(tweens, tw)
    driver:Show()
    return tw
end

-- Run every tween to the given time (or to the end when `finish`, including
-- tweens that finishing ones start, like a flip after a card lands).
function C.Tick(finish)
    if finish then
        for _ = 1, 10 do
            if #tweens == 0 then break end
            C.Step(true)
        end
        return
    end
    C.Step(false)
end

function C.Step(finish)
    local t = Now()
    for i = #tweens, 1, -1 do
        local tw = tweens[i]
        local p = finish and 1 or (t - tw.start) / tw.dur
        if p >= 0 then
            if p >= 1 then
                table.remove(tweens, i)
                tw.step(1)
                if tw.done then tw.done() end
            else
                tw.step(Ease(p))
            end
        end
    end
    if #tweens == 0 then driver:Hide() end
end

function C.Cancel(tw)
    for i = #tweens, 1, -1 do
        if tweens[i] == tw then table.remove(tweens, i) end
    end
end

driver:SetScript("OnUpdate", function() C.Tick(false) end)
driver:Hide()

---------------------------------------------------------------------------
-- Card widget. card:SetCard(c): nil = hidden, 0 = face down, 1-52 = face up.
-- Positions are CENTER offsets inside `parent`, so cards can fly around it.
---------------------------------------------------------------------------
local Card = {}
Card.__index = Card

function C.New(parent, w)
    local h = math.floor(w * 1.4 + 0.5)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    local self = setmetatable({ frame = f, w = w, h = h, x = 0, y = 0 }, Card)

    self.front = f:CreateTexture(nil, "ARTWORK")
    self.front:SetAllPoints()
    self.front:SetTexture(ART .. "CardFront")
    self.front:SetTexCoord(0, 1, 0, CARD_V)

    self.back = f:CreateTexture(nil, "ARTWORK")
    self.back:SetAllPoints()
    self.back:SetTexture(ART .. "CardBack")
    self.back:SetTexCoord(0, 1, 0, CARD_V)

    self.rank = W.BigLabel(f, math.max(9, math.floor(w * 0.34)), "GameFontNormalLarge")
    self.rank:SetPoint("TOPLEFT", w * 0.1, -h * 0.06)
    self.rank:SetShadowOffset(0, 0)

    self.pip = f:CreateTexture(nil, "OVERLAY")
    self.pip:SetSize(w * 0.24, w * 0.24)
    self.pip:SetPoint("TOP", self.rank, "BOTTOM", 0, -1)

    self.big = f:CreateTexture(nil, "OVERLAY")
    self.big:SetSize(w * 0.52, w * 0.52)
    self.big:SetPoint("CENTER", w * 0.08, -h * 0.1)

    self.glow = f:CreateTexture(nil, "BACKGROUND")
    self.glow:SetPoint("TOPLEFT", -3, 3)
    self.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    self.glow:SetColorTexture(1, 0.82, 0, 0.9)
    self.glow:Hide()

    self:SetCard(nil)
    return self
end

-- Show the face (or back) at once.
function Card:SetCard(c)
    self.card = c
    local f = self.frame
    if c == nil then
        f:Hide()
        return
    end
    f:Show()
    local up = c ~= 0
    self.front:SetShown(up)
    self.back:SetShown(not up)
    self.rank:SetShown(up)
    self.pip:SetShown(up)
    self.big:SetShown(up)
    if up then
        local r, suit = ns.Games.poker.Rank(c), ns.Games.poker.Suit(c)
        self.rank:SetText(RANK_TEXT[r] or tostring(r))
        if suit == 2 or suit == 3 then
            self.rank:SetTextColor(0.78, 0.1, 0.13)
        else
            self.rank:SetTextColor(0.1, 0.1, 0.12)
        end
        self.pip:SetTexture(ART .. SUITS[suit])
        self.big:SetTexture(ART .. SUITS[suit])
    end
end

function Card:SetHighlight(on)
    self.glow:SetShown(on and true or false)
end

function Card:Place(x, y)
    self.x, self.y = x, y
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", self.frame:GetParent(), "CENTER", x, y)
end

function Card:Stop()
    if self.move then C.Cancel(self.move) end
    if self.flip then C.Cancel(self.flip) end
    self.move, self.flip = nil, nil
    self.frame:SetWidth(self.w)
    self.frame:SetAlpha(1)
end

-- Fly from (fx, fy) to (tx, ty), fading in. `then` runs on landing.
function Card:Fly(fx, fy, tx, ty, delay, after)
    self:Stop()
    self:Place(fx, fy)
    self.frame:SetAlpha(0)
    self.move = C.Tween(0.35, function(t)
        self.frame:SetAlpha(math.min(1, t * 3))
        self:Place(fx + (tx - fx) * t, fy + (ty - fy) * t)
    end, function()
        self.move = nil
        if after then after() end
    end, delay)
    -- Until the delay is over, stay invisible where the deck is.
end

-- Turn the card over: squeeze to nothing, swap faces, open up again.
function Card:FlipTo(c, delay)
    if self.flip then C.Cancel(self.flip) end
    local w = self.w
    local swapped = false
    ns.After(delay or 0, function() W.PlaySound("IG_ABILITY_PAGE_TURN") end)
    self.flip = C.Tween(0.3, function(t)
        local k = t < 0.5 and (1 - t * 2) or ((t - 0.5) * 2)
        if t >= 0.5 and not swapped then
            swapped = true
            self:SetCard(c)
        end
        self.frame:SetWidth(math.max(0.5, w * k))
        -- Text does not squeeze, so hide it while the card is thin.
        local thin = k < 0.6
        if self.card and self.card ~= 0 then self.rank:SetShown(not thin) end
    end, function()
        self.flip = nil
        self.frame:SetWidth(w)
        if self.card and self.card ~= 0 then self.rank:SetShown(true) end
    end, delay)
end

---------------------------------------------------------------------------
-- Dealing, shared by every card game: show `want` on a card (nil = gone,
-- 0 = face down, 1-52 = face up) at x, y. Animated: a card that appears
-- flies in from the deck at (fromX, fromY) and turns over if it should be
-- face up; a face-down card turns over in place. Returns the delay for the
-- next card, so a deal can be staggered.
---------------------------------------------------------------------------
function C.Deal(card, want, x, y, animate, delay, fromX, fromY)
    delay = delay or 0
    if card.target == want then return delay end
    local had = card.target
    card.target = want
    if want == nil then
        card:Stop()
        card:SetCard(nil)
        return delay
    end
    if not animate then
        card:Stop()
        card:SetCard(want)
        card:Place(x, y)
        return delay
    end
    if had == nil then
        card:SetCard(0)
        card:Fly(fromX or 0, fromY or 0, x, y, delay, function()
            if want ~= 0 and card.target == want then card:FlipTo(want) end
        end)
        return delay + 0.12
    end
    card:Place(x, y)
    card:FlipTo(want, delay)
    return delay + 0.08
end

---------------------------------------------------------------------------
-- A coin that flies from one place to another (bets into the pot, the pot
-- to the winner).
---------------------------------------------------------------------------
local coins = {}

function C.Coin(parent, fx, fy, tx, ty, delay)
    local f
    for _, c in ipairs(coins) do
        if not c.busy and c:GetParent() == parent then
            f = c
            break
        end
    end
    if not f then
        f = CreateFrame("Frame", nil, parent)
        f:SetSize(18, 18)
        f:SetFrameLevel(parent:GetFrameLevel() + 20)
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        table.insert(coins, f)
    end
    f.busy = true
    f:Show()
    f:SetAlpha(0)
    C.Tween(0.45, function(t)
        f:SetAlpha(t < 0.85 and 1 or (1 - (t - 0.85) / 0.15))
        f:ClearAllPoints()
        -- A little arc on the way.
        f:SetPoint("CENTER", parent, "CENTER", fx + (tx - fx) * t, fy + (ty - fy) * t + math.sin(t * math.pi) * 18)
    end, function()
        f:Hide()
        f.busy = false
    end, delay)
end

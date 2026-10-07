-- HearthstonePage: the board. Everything it shows comes from the engine's
-- state (ns.HS.Engine); every action goes through E.Apply and the events
-- that come back are played as animations (lunges, numbers, fades, cards
-- flying). Player 1 is you; player 2 is the AI or, in PvP, the other player:
-- the host's game is shown mirrored to whoever sits in chair 2, so "you"
-- are always player 1 here (see P:PvpView).
local ADDON, ns = ...

local W = ns.Widgets
local A = ns.Arcade
local K = ns.Kit
local C = ns.Cards
local P = {}
P.__index = P
ns.HearthstonePage = P

local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"
local CARD_V = 356 / 512 -- card frames fill the top of their texture
local BW, BH = 738, 462 -- the page (Hearthstone asks for a bigger window: G.window)
local CX = 369 -- the middle of the board
local ME, AIP = 1, 2
local HAND_W, HAND_H = 86, 120
local MIN_W, MIN_H, MIN_GAP = 60, 76, 10
local HERO = 84
local POWER_X = CX + 82
local MANA_X = 500
local DECK_X, DECK_Y = 695, { 262, 104 }
local Y = { enemyHand = 30, enemyHero = 58, enemyBoard = 142, mid = 182, myBoard = 222, myHero = 306, hand = 404 }
local TINT = {
    neutral = { 1, 0.95, 0.86 }, mage = { 0.84, 0.8, 1 }, shaman = { 0.74, 0.86, 1 },
    warrior = { 1, 0.8, 0.74 }, druid = { 0.95, 0.84, 0.66 }, hunter = { 0.8, 0.96, 0.72 },
    paladin = { 1, 0.93, 0.62 }, priest = { 1, 1, 1 }, rogue = { 0.78, 0.78, 0.8 }, warlock = { 0.86, 0.74, 0.96 },
}

local function HS() return ns.HS end
local function E() return ns.HS.Engine end
local function Card(key) return ns.HS.Cards[key] end
local function Now() return GetTime and GetTime() or 0 end

local function Save()
    local rec = ns.db.hearthstone or {}
    ns.db.hearthstone = rec
    rec.wins, rec.losses = rec.wins or 0, rec.losses or 0
    rec.streak, rec.best = rec.streak or 0, rec.best or 0
    return rec
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function Badge(parent, tex, size, font)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.bg = f:CreateTexture(nil, "ARTWORK")
    f.bg:SetAllPoints()
    f.bg:SetTexture(ART .. tex)
    f.text = W.BigLabel(f, font, "GameFontNormalHuge")
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetTextColor(1, 1, 1)
    local face = f.text:GetFont()
    if face then f.text:SetFont(face, font, "OUTLINE") end
    return f
end

-- A WoW creature's 3D model in place of a card's picture (cards with
-- `npc`). The icon stays as the fallback until the model has loaded.
-- Creatures can have several looks; the first one that loads is kept
-- (by display id, saved) so every copy of a card looks the same. Models
-- that haven't loaded yet are asked again now and then (P:Tick).
local MODELS = setmetatable({}, { __mode = "k" })

-- Creature id -> model (display) id. Heroes with a `display` use that model
-- directly: newer creatures the server may not know, from the game files.
local function Looks()
    local rec = Save()
    if not rec.looks or not rec.looksHeroes then
        rec.looks = rec.looks or {}
        for _, h in pairs(ns.HS.Heroes) do
            if h.display then rec.looks[h.npc] = h.display end
        end
        rec.looksHeroes = true
    end
    return rec.looks
end

local function LoadModel(m)
    local look = Looks()[m.npc]
    if look and m.SetDisplayInfo then m:SetDisplayInfo(look) else m:SetCreature(m.npc) end
    if m.zoom and m.SetPortraitZoom then m:SetPortraitZoom(m.zoom) end
    m.tried = GetTime and GetTime() or 0
end

local function MakeModel(parent, art, level)
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, parent)
    if not ok or not m or not m.SetCreature then return nil end
    m:SetFrameLevel(parent:GetFrameLevel() + (level or 1))
    m.art = art
    m.waits = pcall(m.SetScript, m, "OnModelLoaded", function(self)
        self.loaded = true
        if self.npc and not Looks()[self.npc] and self.GetDisplayInfo then
            local look = self:GetDisplayInfo()
            if look and look > 0 then Looks()[self.npc] = look end
        end
        if self.zoom and self.SetPortraitZoom then self:SetPortraitZoom(self.zoom) end
        if self.npc and self.art then self.art:Hide() end
    end)
    -- Models forget themselves when hidden: load again when shown.
    m:SetScript("OnShow", function(self) if self.npc then LoadModel(self) end end)
    m:Hide()
    MODELS[m] = true
    return m
end

-- Show creature `npc` in model `m` (or just the icon when there's none).
local function SetModel(m, art, npc, zoom)
    if not m then return end
    if not npc then
        m.npc = nil
        m:Hide()
        art:Show()
        return
    end
    m.zoom = zoom
    if m.npc ~= npc then
        m.npc, m.loaded = npc, false
        if m.ClearModel then m:ClearModel() end
        LoadModel(m)
    end
    if m.SetPortraitZoom then m:SetPortraitZoom(zoom) end
    m:Show()
    art:SetShown(m.waits and not m.loaded)
end

-- Preloading: a few invisible models load creatures in the background, so
-- cards show their model at once (and every copy gets the same look).
local PRELOADERS = 4
local queue, queued = {}, {}

-- Every creature a set of cards can show: the cards, what they summon or
-- transform into, plus heroes and their hero powers.
function P.CreaturesFor(cardKeys, heroKeys)
    local out, seen = {}, {}
    local function Add(npc) if npc and not seen[npc] then seen[npc] = true table.insert(out, npc) end end
    local function Effects(list)
        for _, e in ipairs(list or {}) do
            local c = e.card and ns.HS.Cards[e.card]
            if c then Add(c.npc) end
            c = e.into and ns.HS.Cards[e.into]
            if c then Add(c.npc) end
            for _, key in ipairs(e.pool or {}) do Add(ns.HS.Cards[key] and ns.HS.Cards[key].npc) end
        end
    end
    for _, key in ipairs(cardKeys or {}) do
        local c = ns.HS.Cards[key]
        if c then
            Add(c.npc)
            for _, part in ipairs({ "battlecry", "spell", "deathrattle", "endTurn", "damaged" }) do
                Effects(c[part] and c[part].effects)
            end
        end
    end
    for _, hk in ipairs(heroKeys or {}) do
        local h = ns.HS.Heroes[hk]
        if h then
            Add(h.npc)
            Effects(h.power and h.power.effects)
        end
    end
    return out
end

-- Queue creatures to load (`front`: before anything already waiting).
function P.Preload(npcs, front)
    local add = {}
    for _, npc in ipairs(npcs) do
        if not Looks()[npc] then
            if not queued[npc] then
                queued[npc] = true
                table.insert(add, npc)
            elseif front then
                -- Already waiting: move it up.
                for i, x in ipairs(queue) do
                    if x == npc then
                        table.remove(queue, i)
                        table.insert(add, npc)
                        break
                    end
                end
            end
        end
    end
    if front then
        for i = #add, 1, -1 do table.insert(queue, 1, add[i]) end
    else
        for _, npc in ipairs(add) do table.insert(queue, npc) end
    end
end
P.preloadQueue = queue

function P:PreloadTick()
    if not self.loaders then
        self.loaders = {}
        for i = 1, PRELOADERS do
            local ok, m = pcall(CreateFrame, "PlayerModel", nil, self.board)
            if not ok or not m or not m.SetCreature then break end
            m:SetSize(40, 40)
            m:SetPoint("TOPLEFT", 4 + i * 2, -4)
            m:SetAlpha(0)
            m:EnableMouse(false)
            pcall(m.SetScript, m, "OnModelLoaded", function(l)
                if l.npc and not Looks()[l.npc] and l.GetDisplayInfo then
                    local look = l:GetDisplayInfo()
                    if look and look > 0 then Looks()[l.npc] = look end
                end
                l.npc = nil
            end)
            self.loaders[i] = m
        end
    end
    local now = Now()
    for _, l in ipairs(self.loaders) do
        if l.npc and now - l.started > 3 then
            -- Not loaded in time: try once more later.
            l.tries = (l.tries or 0) + 1
            if l.tries < 2 then table.insert(queue, l.npc) end
            l.npc = nil
        end
        if not l.npc and #queue > 0 then
            l.npc = table.remove(queue, 1)
            l.started = now
            if l.ClearModel then l:ClearModel() end
            l:SetCreature(l.npc)
        end
    end
end

-- Ask again for models still waiting (the creature wasn't ready yet).
local function RetryModels()
    local now = GetTime and GetTime() or 0
    for m in pairs(MODELS) do
        if m.npc and m.waits and not m.loaded and m:IsVisible() and now - (m.tried or 0) > 1.5 then
            LoadModel(m)
        end
    end
end

-- A card face (hand, preview, enemy plays). Works at any size.
local function MakeCard(parent, w, h)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(w, h)
    f.artBg = f:CreateTexture(nil, "ARTWORK", nil, -2)
    f.artBg:SetColorTexture(0.12, 0.1, 0.08, 1)
    f.art = f:CreateTexture(nil, "ARTWORK", nil, -1)
    f.artBg:SetAllPoints(f.art)
    f.model = MakeModel(f, f.art, 1)
    if f.model then f.model:SetAllPoints(f.art) end
    -- The frame, back and text sit above the model.
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(f:GetFrameLevel() + 2)
    f.top = top
    f.frame = top:CreateTexture(nil, "ARTWORK", nil, 1)
    f.frame:SetAllPoints()
    f.back = top:CreateTexture(nil, "ARTWORK", nil, 2)
    f.back:SetAllPoints()
    f.back:SetTexture(ART .. "HsCardBack")
    f.back:SetTexCoord(0, 1, 0, CARD_V)
    local bs = math.floor(w * 0.34)
    f.gem = Badge(f, "HsGem", bs, math.max(9, math.floor(w * 0.2)))
    f.gem:SetPoint("CENTER", f, "TOPLEFT", w * 0.13, -h * 0.08)
    f.atk = Badge(f, "HsAttack", bs, math.max(9, math.floor(w * 0.19)))
    f.atk:SetPoint("CENTER", f, "BOTTOMLEFT", w * 0.13, h * 0.08)
    f.hp = Badge(f, "HsHealth", bs, math.max(9, math.floor(w * 0.19)))
    f.hp:SetPoint("CENTER", f, "BOTTOMRIGHT", -w * 0.13, h * 0.08)
    for _, b in ipairs({ f.gem, f.atk, f.hp }) do b:SetFrameLevel(f:GetFrameLevel() + 3) end
    -- A thin green edge on cards you can play now.
    f.ready = f:CreateTexture(nil, "BACKGROUND")
    f.ready:SetPoint("TOPLEFT", -2, 2)
    f.ready:SetPoint("BOTTOMRIGHT", 2, -2)
    f.ready:SetColorTexture(0.3, 1, 0.3, 0.85)
    f.ready:Hide()
    local big = w >= 80
    f.name = W.Label(top, "", big and "GameFontNormal" or "GameFontNormalSmall")
    local face = f.name:GetFont()
    if big then
        f.name:SetPoint("CENTER", f, "TOPLEFT", w / 2, -h * 0.567)
        f.name:SetWidth(w * 0.86)
        f.name:SetWordWrap(false)
        f.name:SetTextColor(1, 1, 1)
        if face then f.name:SetFont(face, math.max(7, math.floor(w * 0.075)), "OUTLINE") end
    else
        -- Small cards: the name in the text box, up to two lines.
        f.name:SetPoint("CENTER", f, "TOPLEFT", w / 2, -h * 0.77)
        f.name:SetWidth(w * 0.78)
        f.name:SetWordWrap(true)
        if f.name.SetMaxLines then f.name:SetMaxLines(2) end
        f.name:SetTextColor(0.15, 0.1, 0.05)
        if face then f.name:SetFont(face, 8, "") end
        f.name:SetShadowOffset(0, 0)
    end
    f.desc = W.Label(top, "", "GameFontBlackSmall")
    f.desc:SetPoint("CENTER", f, "TOPLEFT", w / 2, -h * 0.775)
    f.desc:SetWidth(w * 0.74)
    f.desc:SetTextColor(0.15, 0.1, 0.05)
    f.desc:SetShown(w >= 80)
    local df = f.desc:GetFont()
    if df and w < 120 then f.desc:SetFont(df, 7, "") end
    f.race = W.Label(top, "", "GameFontDisableSmall")
    f.race:SetPoint("BOTTOM", 0, h * 0.035)
    f.race:SetShown(w >= 100)

    -- key: which card; hidden: show the back; stats: { attack, health, max } for a minion on the board.
    function f:SetCard(key, hidden, stats)
        self.key = key
        local show = not hidden and key ~= nil
        self.back:SetShown(not show)
        self.art:SetShown(show)
        self.artBg:SetShown(show)
        if not show and self.model then SetModel(self.model, self.art, nil) self.art:Hide() end
        self.frame:SetShown(show)
        self.gem:SetShown(show)
        self.name:SetShown(show)
        self.desc:SetShown(show and w >= 80)
        self.race:SetShown(show and w >= 100)
        if not show then
            self.atk:Hide()
            self.hp:Hide()
            return
        end
        local c = Card(key)
        local minion = c.type == "minion"
        local weapon = c.type == "weapon"
        self.frame:SetTexture(ART .. (minion and "HsCardMinion" or "HsCardSpell"))
        self.frame:SetTexCoord(0, 1, 0, CARD_V)
        local tint = TINT[c.class] or TINT.neutral
        self.frame:SetVertexColor(tint[1], tint[2], tint[3])
        self.art:ClearAllPoints()
        if minion then
            self.art:SetPoint("TOPLEFT", w * 0.18, -h * 0.085)
            self.art:SetPoint("BOTTOMRIGHT", -w * 0.18, h * 0.49)
        else
            self.art:SetPoint("TOPLEFT", w * 0.15, -h * 0.095)
            self.art:SetPoint("BOTTOMRIGHT", -w * 0.15, h * 0.515)
        end
        self.art:SetTexture(c.art)
        if c.art:find("\\Icons\\") then self.art:SetTexCoord(0.08, 0.92, 0.08, 0.92) else self.art:SetTexCoord(0, 1, 0, 1) end
        SetModel(self.model, self.art, c.npc, 0.6)
        self.gem.text:SetText(tostring(c.cost))
        self.name:SetText(c.name)
        self.desc:SetText(c.text or "")
        self.race:SetText(c.race and (c.race:sub(1, 1):upper() .. c.race:sub(2)) or "")
        self.atk:SetShown(minion or weapon)
        self.hp:SetShown(minion or weapon)
        if weapon then
            self.atk.text:SetText(tostring(c.attack))
            self.hp.text:SetText(tostring(c.durability))
            self.atk.text:SetTextColor(1, 1, 1)
            self.hp.text:SetTextColor(1, 1, 1)
            self.hp.bg:SetTexture(ART .. "HsArmor")
        else
            self.hp.bg:SetTexture(ART .. "HsHealth")
        end
        if minion then
            local atk, hp, max = c.attack, c.health, c.health
            if stats then atk, hp, max = stats[1], stats[2], stats[3] end
            self.atk.text:SetText(tostring(atk))
            self.hp.text:SetText(tostring(hp))
            self.atk.text:SetTextColor(1, atk > c.attack and 0.4 or 1, atk > c.attack and 0.4 or 1)
            if hp < max then self.hp.text:SetTextColor(1, 0.3, 0.3)
            elseif max > c.health then self.hp.text:SetTextColor(0.4, 1, 0.4)
            else self.hp.text:SetTextColor(1, 1, 1) end
            if stats then self.atk.text:SetTextColor(atk > c.attack and 0.4 or 1, 1, atk > c.attack and 0.4 or 1) end
        end
    end
    return f
end

P.MakeCard = MakeCard -- the deck builder uses the same cards

-- A minion on the board.
local function MakeMinion(parent)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(MIN_W, MIN_H)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.taunt = f:CreateTexture(nil, "BACKGROUND")
    f.taunt:SetTexture(ART .. "HsTaunt")
    f.taunt:SetPoint("CENTER", 0, -2)
    f.taunt:SetSize(MIN_W + 18, MIN_H + 16)
    f.art = f:CreateTexture(nil, "ARTWORK")
    f.art:SetPoint("TOPLEFT", 4, -4)
    f.art:SetPoint("BOTTOMRIGHT", -4, 4)
    if f.CreateMaskTexture then
        local mask = f:CreateMaskTexture()
        if mask then
            mask:SetTexture(ART .. "HsOvalMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(f.art)
            f.art:AddMaskTexture(mask)
        end
    end
    f.artBg = f:CreateTexture(nil, "ARTWORK", nil, -1)
    f.artBg:SetTexture(ART .. "HsOvalMask")
    f.artBg:SetVertexColor(0.16, 0.13, 0.1)
    f.artBg:SetAllPoints(f.art)
    f.model = MakeModel(f, f.art, 1)
    if f.model then
        -- A model is a rectangle: keep it inside the oval.
        f.model:SetSize((MIN_W - 8) * 0.74, (MIN_H - 8) * 0.74)
        f.model:SetPoint("CENTER", f.art, "CENTER", 0, 1)
    end
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(f:GetFrameLevel() + 2)
    f.top = top
    f.frozen = top:CreateTexture(nil, "ARTWORK", nil, 2)
    f.frozen:SetAllPoints()
    f.frozen:SetTexture(ART .. "HsFrozen")
    f.ring = top:CreateTexture(nil, "OVERLAY")
    f.ring:SetAllPoints()
    f.ring:SetTexture(ART .. "HsMinionRing")
    f.divine = top:CreateTexture(nil, "OVERLAY", nil, 1)
    f.divine:SetPoint("TOPLEFT", -6, 6)
    f.divine:SetPoint("BOTTOMRIGHT", 6, -6)
    f.divine:SetTexture(ART .. "HsDivine")
    f.atk = Badge(f, "HsAttack", 24, 13)
    f.atk:SetPoint("CENTER", f, "BOTTOMLEFT", 6, 7)
    f.hp = Badge(f, "HsHealth", 24, 13)
    f.hp:SetPoint("CENTER", f, "BOTTOMRIGHT", -6, 7)
    f.atk:SetFrameLevel(f:GetFrameLevel() + 4)
    f.hp:SetFrameLevel(f:GetFrameLevel() + 4)
    f.doom = top:CreateTexture(nil, "OVERLAY", nil, 3)
    f.doom:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    f.doom:SetSize(18, 18)
    f.doom:SetPoint("TOPRIGHT", 2, 2)
    f.doom:Hide()
    f.zzz = W.Label(top, "z z", "GameFontHighlightSmall")
    f.zzz:SetPoint("TOP", 0, 6)
    f.zzz:SetTextColor(0.8, 0.85, 1)
    return f
end

-- A hero: portrait in a gold frame, health, armor, attack, frozen.
local function MakeHero(parent)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(HERO, HERO)
    f.portrait = W.Portrait(f, HERO - 12)
    f.portrait:SetPoint("CENTER")
    if f.portrait.ring then f.portrait.ring:Hide() end
    f.model = MakeModel(f, f.portrait.class, 3)
    if f.model then
        -- Inset so the square model's corners stay under the gold frame.
        f.model:SetPoint("TOPLEFT", 11, -11)
        f.model:SetPoint("BOTTOMRIGHT", -11, 11)
    end
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(f:GetFrameLevel() + 4)
    f.frame = top:CreateTexture(nil, "OVERLAY", nil, 1)
    f.frame:SetPoint("TOPLEFT", -8, 8)
    f.frame:SetPoint("BOTTOMRIGHT", 8, -8)
    f.frame:SetTexture(ART .. "HsHeroFrame")
    f.frozen = top:CreateTexture(nil, "OVERLAY", nil, 2)
    f.frozen:SetAllPoints()
    f.frozen:SetTexture(ART .. "HsFrozen")
    f.hp = Badge(f, "HsHealth", 32, 16)
    f.hp:SetPoint("CENTER", f, "BOTTOMRIGHT", -4, 10)
    f.armor = Badge(f, "HsArmor", 28, 14)
    f.armor:SetPoint("BOTTOM", f.hp, "TOP", 0, -4)
    f.atk = Badge(f, "HsAttack", 32, 16)
    f.atk:SetPoint("CENTER", f, "BOTTOMLEFT", 4, 10)
    for _, x in ipairs({ f.hp, f.armor, f.atk }) do x:SetFrameLevel(f:GetFrameLevel() + 8) end
    -- The weapon, left of the portrait.
    local wpn = CreateFrame("Frame", nil, f)
    wpn:SetSize(46, 46)
    wpn:SetPoint("RIGHT", f, "LEFT", -12, -4)
    wpn.icon = wpn:CreateTexture(nil, "ARTWORK")
    wpn.icon:SetPoint("TOPLEFT", 5, -5)
    wpn.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    if wpn.CreateMaskTexture then
        local mask = wpn:CreateMaskTexture()
        if mask then
            mask:SetTexture(ART .. "HsOvalMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(wpn.icon)
            wpn.icon:AddMaskTexture(mask)
        end
    end
    wpn.ring = wpn:CreateTexture(nil, "OVERLAY")
    wpn.ring:SetAllPoints()
    wpn.ring:SetTexture(ART .. "HsMinionRing")
    wpn.atk = Badge(wpn, "HsAttack", 22, 12)
    wpn.atk:SetPoint("CENTER", wpn, "BOTTOMLEFT", 4, 5)
    wpn.dur = Badge(wpn, "HsArmor", 22, 12)
    wpn.dur:SetPoint("CENTER", wpn, "BOTTOMRIGHT", -4, 5)
    wpn.atk:SetFrameLevel(wpn:GetFrameLevel() + 2)
    wpn.dur:SetFrameLevel(wpn:GetFrameLevel() + 2)
    wpn:EnableMouse(true)
    wpn:Hide()
    f.weapon = wpn
    return f
end

local function MakePower(parent)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(52, 52)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 4, -4)
    f.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    if f.CreateMaskTexture then
        local mask = f:CreateMaskTexture()
        if mask then
            mask:SetTexture(ART .. "HsOvalMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(f.icon)
            f.icon:AddMaskTexture(mask)
        end
    end
    f.ring = f:CreateTexture(nil, "OVERLAY")
    f.ring:SetAllPoints()
    f.ring:SetTexture(ART .. "HsMinionRing")
    f.cost = Badge(f, "HsGem", 22, 12)
    f.cost:SetPoint("CENTER", f, "TOP", 0, -1)
    f.cost:SetFrameLevel(f:GetFrameLevel() + 2)
    return f
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function P.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind], minions = {}, handCards = {}, free = {} }, P)
    -- PvP: the Arcade lobby panel (who can join, create, practice, join by code).
    A.BuildSetup(self, parent)
    self.setup:Hide()
    local back = W.Button(self.setup, "Back", 90, function()
        self.setupOpen = false
        self:ShowStart()
        self:Refresh()
    end, 22)
    back:SetPoint("BOTTOMLEFT", 10, 10)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    local panel = W.Panel(v)
    panel:SetAllPoints()
    local b = CreateFrame("Frame", nil, v)
    b:SetSize(BW, BH)
    b:SetPoint("TOPLEFT")
    b:SetFrameLevel(panel:GetFrameLevel() + 2) -- always above the marble panel
    self.board = b
    b:EnableMouse(true)
    b:SetScript("OnMouseDown", function(_, button) if button == "RightButton" then self:Cancel() end end)

    -- The table: wood, a stone rim, the sandy field, hero pedestals.
    local table_ = b:CreateTexture(nil, "BACKGROUND")
    table_:SetAllPoints()
    table_:SetTexture(ART .. "HsBoard")
    table_:SetTexCoord(0, 1, 0, 640 / 1024)

    self.heroes = { MakeHero(b), MakeHero(b) }
    K.Place(self.heroes[ME], b, CX, Y.myHero)
    K.Place(self.heroes[AIP], b, CX, Y.enemyHero)
    self.powers = { MakePower(b), MakePower(b) }
    K.Place(self.powers[ME], b, POWER_X, Y.myHero + 8)
    K.Place(self.powers[AIP], b, POWER_X, Y.enemyHero + 8)
    self.powers[ME].x, self.powers[ME].y = POWER_X, Y.myHero + 8
    self.powers[AIP].x, self.powers[AIP].y = POWER_X, Y.enemyHero + 8
    for i = 1, 2 do
        local h = self.heroes[i]
        h:SetFrameLevel(b:GetFrameLevel() + 5)
        h:SetScript("OnClick", function() self:ClickEntity(i) end)
        h:SetScript("OnEnter", function() self:HoverHero(i) end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local pw = self.powers[i]
        pw:SetScript("OnClick", function() if i == ME then self:ClickPower() end end)
        pw:SetScript("OnEnter", function() self:HoverPower(i) end)
        pw:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Mana.
    self.mana, self.crystals = {}, {}
    for i = 1, 2 do
        local y = i == ME and Y.myHero or Y.enemyHero
        self.mana[i] = W.BigLabel(b, 14, "GameFontHighlightLarge")
        self.mana[i]:SetPoint("CENTER", b, "TOPLEFT", MANA_X, -y)
        self.crystals[i] = {}
        for j = 1, 10 do
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetTexture(ART .. "HsCrystal")
            t:SetSize(13, 13)
            K.Place(t, b, MANA_X + 26 + (j - 1) * 13, y)
            self.crystals[i][j] = t
        end
    end
    self.deckText = { W.Label(b, "", "GameFontDisableSmall"), W.Label(b, "", "GameFontDisableSmall") }
    self.decks = {}
    for i = 1, 2 do
        local d = CreateFrame("Frame", nil, b)
        d:SetSize(44, 62)
        K.Place(d, b, DECK_X, DECK_Y[i])
        d.layers = {}
        for k = 1, 3 do
            local t = d:CreateTexture(nil, "ARTWORK", nil, -k)
            t:SetTexture(ART .. "HsCardBack")
            t:SetTexCoord(0, 1, 0, CARD_V)
            t:SetSize(44, 62)
            t:SetPoint("CENTER", (k - 1) * 1.5, (k - 1) * 1.5)
            d.layers[k] = t
        end
        self.decks[i] = d
        self.deckText[i]:SetPoint("TOP", d, "BOTTOM", 0, -2)
    end

    -- End Turn: yellow while you have moves, green when you're done, grey on their turn.
    local e = CreateFrame("Button", nil, b)
    e:SetSize(104, 52)
    K.Place(e, b, 677, Y.mid)
    e.bg = e:CreateTexture(nil, "ARTWORK")
    e.bg:SetAllPoints()
    e.bg:SetTexture(ART .. "HsEndTurn")
    local label = W.Label(e, "END TURN", "GameFontNormal")
    label:SetPoint("CENTER", 0, 1)
    local lf = label:GetFont()
    if lf then label:SetFont(lf, 12, "OUTLINE") end
    e:SetFontString(label)
    local hl = e:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(ART .. "HsEndTurn")
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.25)
    e:SetScript("OnClick", function() self:EndTurn() end)
    W.Tooltip(e, "End turn", "Hand the turn to your opponent. It turns green when you have nothing left to do.")
    self.endButton = e

    -- Left side: the run's numbers, a New game button, the hovered card.
    self.statsText = W.Label(b, "", "GameFontHighlightSmall")
    self.statsText:SetPoint("TOPLEFT", 6, -6)
    self.statsText:SetJustifyH("LEFT")
    self.newButton = W.Button(b, "New game", 80, function() self:ShowStart() end, 20)
    self.newButton:SetPoint("TOPLEFT", 4, -40)
    self.status = W.Label(b, "", "GameFontNormal")
    self.status:SetPoint("CENTER", b, "TOPLEFT", CX, -Y.mid)
    self.status:SetTextColor(1, 0.9, 0.5)

    self.preview = MakeCard(b, 150, 209)
    self.preview:SetPoint("LEFT", 6, 8)
    self.preview:SetFrameLevel(b:GetFrameLevel() + 40)
    self.preview:EnableMouse(false)
    self.preview:Hide()

    -- Targeting line (when the client has lines).
    -- It lives on its own frame above minions, heroes and cards.
    local arrowLayer = CreateFrame("Frame", nil, b)
    arrowLayer:SetAllPoints()
    arrowLayer:SetFrameLevel(b:GetFrameLevel() + 55)
    if arrowLayer.CreateLine then
        local ok, l = pcall(arrowLayer.CreateLine, arrowLayer, nil, "OVERLAY")
        if ok and l then
            l:SetThickness(4)
            l:SetColorTexture(1, 0.3, 0.2, 0.85)
            l:Hide()
            self.arrow = l
        end
    end

    -- PvP: give up this game.
    self.concede = W.Button(b, "Concede", 76, function()
        W.Confirm("Concede this game?", function() ns.Session.Act(self.kind, "concede") end)
    end, 20)
    self.concede:SetPoint("TOPLEFT", 8, -8)
    self.concede:Hide()

    -- Where a dragged minion will land.
    self.marker = b:CreateTexture(nil, "OVERLAY")
    self.marker:SetColorTexture(1, 0.82, 0.2, 0.9)
    self.marker:SetSize(3, MIN_H + 6)
    self.marker:Hide()

    -- Floating numbers and banners sit above everything.
    self.fx = CreateFrame("Frame", nil, b)
    self.fx:SetAllPoints()
    self.fx:SetFrameLevel(b:GetFrameLevel() + 50)
    self.numFree, self.ghostFree, self.fxFree = {}, {}, {}
    self.banner = W.BigLabel(self.fx, 26, "GameFontNormalHuge")
    self.banner:SetPoint("CENTER", b, "TOPLEFT", CX, -Y.mid)
    self.banner:Hide()

    -- Start / game over panel.
    local o = CreateFrame("Frame", nil, b)
    o:SetAllPoints()
    o:SetFrameLevel(b:GetFrameLevel() + 60)
    o:EnableMouse(true)
    local shade = o:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.72)
    self.overlay = o
    self.overTitle = W.BigLabel(o, 26, "GameFontNormalHuge")
    self.overTitle:SetPoint("TOP", 0, -46)
    self.overSub = W.Label(o, "", "GameFontHighlight")
    self.overSub:SetPoint("TOP", self.overTitle, "BOTTOM", 0, -8)
    self.overSub:SetWidth(BW - 80)
    self.pick = {}
    local heroes = {}
    for key in pairs(ns.HS.Heroes) do table.insert(heroes, key) end
    table.sort(heroes)
    for i, key in ipairs(heroes) do
        local h = ns.HS.Heroes[key]
        local btn = CreateFrame("Button", nil, o)
        btn:SetSize(100, 120)
        local perRow = 5
        local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
        local inRow = math.min(perRow, #heroes - row * perRow)
        btn:SetPoint("TOP", (col - (inRow - 1) / 2) * 116, -96 - row * 132)
        btn.portrait = W.Portrait(btn, 72)
        btn.portrait:SetPoint("TOP")
        btn.portrait:SetPlayer(h.name, h.class)
        if btn.portrait.ring then btn.portrait.ring:Hide() end
        btn.model = MakeModel(btn.portrait, btn.portrait.class, 3)
        if btn.model then
            btn.model:SetPoint("TOPLEFT", 9, -9)
            btn.model:SetPoint("BOTTOMRIGHT", -9, 9)
            SetModel(btn.model, btn.portrait.class, h.npc, 0.95)
        end
        -- The gold frame on top hides the model's square corners.
        local ring = CreateFrame("Frame", nil, btn.portrait)
        ring:SetAllPoints()
        ring:SetFrameLevel(btn.portrait:GetFrameLevel() + 6)
        local rt = ring:CreateTexture(nil, "OVERLAY")
        rt:SetPoint("TOPLEFT", -7, 7)
        rt:SetPoint("BOTTOMRIGHT", 7, -7)
        rt:SetTexture(ART .. "HsHeroFrame")
        btn.label = W.Label(btn, h.name, "GameFontNormal")
        btn.label:SetPoint("TOP", btn.portrait, "BOTTOM", 0, -4)
        btn.label:SetWidth(110)
        btn.power = W.Label(btn, h.power.name, "GameFontDisableSmall")
        btn.power:SetPoint("TOP", btn.label, "BOTTOM", 0, -2)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        btn:SetScript("OnClick", function() self:ShowDecks(key) end)
        W.Tooltip(btn, h.name, "Play as " .. h.name .. ". Hero power: " .. h.power.name .. " (" .. h.power.text .. ")")
        btn.key = key
        self.pick[i] = btn
    end
    -- Step two: which deck.
    self.deckRows = {}
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, o)
        row:SetSize(440, 28)
        row:SetPoint("TOP", 0, -104 - (i - 1) * 32)
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.06 or 0.03)
        row.name = W.Label(row, "", "GameFontHighlight")
        row.name:SetPoint("LEFT", 10, 0)
        row.name:SetWidth(200)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.count = W.Label(row, "", "GameFontNormalSmall")
        row.count:SetPoint("LEFT", 214, 0)
        row.play = W.Button(row, "Play", 60, function()
            if self.pvp then return self:PvpDeck(self.deckHero, row.deck) end
            self:NewGame(self.deckHero, nil, row.deck.cards)
        end, 22)
        row.play:SetPoint("RIGHT", -128, 0)
        row.edit = W.Button(row, "Edit", 56, function()
            self.overlay:Hide()
            ns.HearthstoneDecks.Open(self, self.deckHero, row.deck.index)
        end, 22)
        row.edit:SetPoint("LEFT", row.play, "RIGHT", 4, 0)
        row.delete = W.Button(row, "Delete", 60, function()
            local index = row.deck.index
            W.Confirm("Delete the deck \"" .. row.deck.name .. "\"?", function()
                table.remove(ns.HearthstoneDecks.Saved(), index)
                self:ShowDecks(self.deckHero)
            end)
        end, 22)
        row.delete:SetPoint("LEFT", row.edit, "RIGHT", 4, 0)
        row:Hide()
        self.deckRows[i] = row
    end
    self.newDeckButton = W.Button(o, "New deck", 100, function()
        self.overlay:Hide()
        ns.HearthstoneDecks.Open(self, self.deckHero)
    end, 24)
    self.newDeckButton:SetPoint("BOTTOM", -56, 30)
    self.backButton = W.Button(o, "Back", 100, function() self:ShowStart() end, 24)
    self.backButton:SetPoint("LEFT", self.newDeckButton, "RIGHT", 12, 0)

    self.friendButton = W.Button(o, "Play a friend", 140, function()
        self.setupOpen = true
        self:Refresh()
    end, 24)
    self.friendButton:SetPoint("BOTTOM", 0, 30)
    W.Tooltip(self.friendButton, "Play a friend", "Open a lobby for your group, guild, realm or a private code, "
        .. "or join someone else's. You each pick a hero and a deck.")
    -- PvP lobby: who's in, and the buttons for what you can do now.
    self.lobbyText = W.Label(o, "", "GameFontHighlight")
    self.lobbyText:SetPoint("TOP", self.overSub, "BOTTOM", 0, -16)
    self.lobbyText:SetWidth(BW - 120)
    self.pvpButtons = {}
    local S = ns.Session
    local function PvpButton(key, label, width, fn, tip)
        local btn = W.Button(o, label, width, fn, 24)
        if tip then W.Tooltip(btn, label, tip) end
        btn:Hide()
        self.pvpButtons[key] = btn
    end
    PvpButton("start", "Start", 100, function() S.Start(self.kind) end)
    PvpButton("bot", "Add bot", 100, function() S.AddBot(self.kind) end)
    PvpButton("rematch", "Rematch", 100, function() S.Act(self.kind, "rematch") end, "Play again, same opponent.")
    PvpButton("leave", "Leave", 100, function() S.Leave(self.kind) S.Dismiss(self.kind) self:Refresh() end)
    PvpButton("close", "Close lobby", 110, function() A.CloseLobby(self) self:Refresh() end)
    PvpButton("done", "Back", 100, function() S.Dismiss(self.kind) self:Refresh() end)

    self.againButton = W.Button(o, "Play again", 110, function() self:ShowStart() end, 26)
    self.againButton:SetPoint("TOP", self.overSub, "BOTTOM", 0, -20)
    self.resumeButton = W.Button(o, "Back to the game", 140, function() self.overlay:Hide() end, 22)
    self.resumeButton:SetPoint("BOTTOM", 0, 30)

    local everything = {}
    for key in pairs(ns.HS.Cards) do table.insert(everything, key) end
    table.sort(everything)
    local heroes = {}
    for key in pairs(ns.HS.Heroes) do table.insert(heroes, key) end
    table.sort(heroes)
    P.Preload(P.CreaturesFor(everything, heroes))

    v:SetScript("OnUpdate", function() self:Tick() end)
    v:SetScript("OnHide", function() self:Cancel() GameTooltip:Hide() end)

    local saved = Save().game
    if saved and saved.players and not saved.over then
        self.st = saved
        self.overlay:Hide()
        ns.Solo.SetRunning(kind, true)
    else
        self:ShowStart()
    end
    self:Draw()
    return self
end

---------------------------------------------------------------------------
-- Games
---------------------------------------------------------------------------
function P:ShowStart()
    self.overlay:Show()
    self.overTitle:SetText("Choose your hero")
    self.overTitle:SetTextColor(1, 0.82, 0)
    self.overSub:SetText(self.pvp and "Pick your hero, then a deck. Your opponent does the same."
        or "Play the computer (your opponent is picked at random), or a friend.")
    self:PvpButtons({})
    self.lobbyText:SetText("")
    self.friendButton:SetShown(not self.pvp)
    for _, b in ipairs(self.pick) do b:Show() end
    for _, r in ipairs(self.deckRows) do r:Hide() end
    self.newDeckButton:Hide()
    self.backButton:Hide()
    self.againButton:Hide()
    self.resumeButton:SetShown(not self.pvp and self.st ~= nil and not self.st.over)
    -- Side by side when both show.
    self.resumeButton:ClearAllPoints()
    self.friendButton:ClearAllPoints()
    if self.resumeButton:IsShown() and self.friendButton:IsShown() then
        self.resumeButton:SetPoint("BOTTOMRIGHT", self.overlay, "BOTTOM", -6, 30)
        self.friendButton:SetPoint("BOTTOMLEFT", self.overlay, "BOTTOM", 6, 30)
    else
        self.resumeButton:SetPoint("BOTTOM", 0, 30)
        self.friendButton:SetPoint("BOTTOM", 0, 30)
    end
end

-- Step two: the hero's decks (the basic one, then yours).
function P:ShowDecks(heroKey)
    self.deckHero = heroKey
    self.overlay:Show()
    local h = ns.HS.Heroes[heroKey]
    self.overTitle:SetText(h.name)
    self.overTitle:SetTextColor(1, 0.82, 0)
    self.overSub:SetText("Choose a deck, or build your own.")
    for _, b in ipairs(self.pick) do b:Hide() end
    self.againButton:Hide()
    self.resumeButton:Hide()
    self.friendButton:Hide()
    local decks = ns.HearthstoneDecks.For(heroKey)
    for i, row in ipairs(self.deckRows) do
        local d = decks[i]
        row:SetShown(d ~= nil)
        if d then
            row.deck = d
            row.name:SetText(d.name)
            local ok, why = ns.HS.CheckDeck(heroKey, d.cards)
            row.count:SetText(ok and "|cff40ff4030 cards|r" or ("|cffff6060" .. why .. "|r"))
            row.play:SetEnabled(ok)
            row.edit:SetShown(not d.basic)
            row.delete:SetShown(not d.basic)
        end
    end
    self.newDeckButton:Show()
    self.newDeckButton:SetEnabled(#decks < #self.deckRows)
    self.backButton:Show()
end

function P:NewGame(heroKey, seed, cards)
    local others = {}
    for key in pairs(ns.HS.Heroes) do if key ~= heroKey then table.insert(others, key) end end
    table.sort(others)
    local foe = others[math.random(#others)]
    local st = E().New({ heroes = { heroKey, foe }, decks = cards and { cards } or nil,
        seed = seed or math.random(1, 2000000000) })
    self.st = st
    Save().game = st
    local keys = {}
    for i = 1, 2 do
        for _, k in ipairs(st.players[i].deck) do table.insert(keys, k) end
        for _, c in ipairs(st.players[i].hand) do table.insert(keys, c.key) end
    end
    P.Preload(P.CreaturesFor(keys, { st.players[1].heroKey, st.players[2].heroKey }), true)
    self.overlay:Hide()
    self.sel = nil
    self.counted = false
    self.busyUntil = Now() + 0.6
    ns.Solo.SetRunning(self.kind, true)
    self:Draw()
    self:Banner(st.active == ME and "You go first" or "Your opponent goes first", 1.2)
    W.PlaySound("IG_MAINMENU_OPTION")
    ns.Changed()
end

-- Stop without counting it (closing the tab).
function P:Quit()
    if self.pvp then return self:LeavePvp() end
    if not self.st then return end
    self.st = nil
    Save().game = nil
    ns.Solo.SetRunning(self.kind, false)
    self:ShowStart()
    self:Draw()
    ns.Changed()
end

function P:GameOver()
    local st = self.st
    local rec = Save()
    local won = st.winner == ME
    if not self.counted then
        self.counted = true
        if won then
            rec.wins = rec.wins + 1
            rec.streak = rec.streak + 1
            rec.best = math.max(rec.best, rec.streak)
            ns.Scores.Submit(self.kind, rec.wins)
        elseif st.winner ~= 0 then
            rec.losses = rec.losses + 1
            rec.streak = 0
        end
    end
    rec.game = nil
    ns.Solo.SetRunning(self.kind, false)
    self.overlay:Show()
    for _, b in ipairs(self.pick) do b:Hide() end
    for _, r in ipairs(self.deckRows) do r:Hide() end
    self.newDeckButton:Hide()
    self.backButton:Hide()
    self.resumeButton:Hide()
    self.againButton:Show()
    self.overTitle:SetText(won and "Victory!" or (st.winner == 0 and "Draw" or "Defeat"))
    self.overTitle:SetTextColor(won and 1 or 0.9, won and 0.82 or 0.3, won and 0 or 0.3)
    self.overSub:SetText(string.format("Wins %d, losses %d. Win streak %d (best %d).", rec.wins, rec.losses,
        rec.streak, rec.best))
    W.PlaySound(won and "LEVELUP" or "RAID_WARNING")
    ns.Changed()
end

---------------------------------------------------------------------------
-- Doing things
---------------------------------------------------------------------------
function P:Busy()
    return (self.busyUntil or 0) > Now()
end

function P:MyTurn()
    return self.st and not self.st.over and self.st.active == ME and not self:Busy()
end

function P:Do(action)
    if self.pvp then return self:PvpDo(action) end
    local st = self.st
    local before = self:Positions()
    local ok, events = E().Apply(st, action)
    if not ok then
        self:Say(events or "Can't do that")
        return false
    end
    self.sel = nil
    self:Animate(events, before)
    return true
end

function P:Say(text)
    self.status:SetText(text)
    self.sayUntil = Now() + 1.6
end

function P:EndTurn()
    if not self:MyTurn() then return end
    self:Do({ type = "end" })
end

function P:Cancel()
    self.sel = nil
    if self.arrow then self.arrow:Hide() end
    if self.st then self:Draw() end
end

local function Contains(list, id)
    for _, x in ipairs(list or {}) do if x == id then return true end end
    return false
end

function P:ClickHand(c)
    if not self:MyTurn() then return end
    local t = E().PlayTargets(self.st, ME, c)
    if t == false then
        local card = Card(c.key)
        self:Say(card.cost > self.st.players[ME].mana and "Not enough mana" or "You can't play that now")
        return
    end
    if t == nil then return self:Do({ type = "play", card = c.id }) end
    self.sel = { kind = "card", id = c.id, targets = t }
    self:Draw()
end

function P:ClickPower()
    if not self:MyTurn() then return end
    local t = E().PowerTargets(self.st, ME)
    if t == false then
        local p = self.st.players[ME]
        self:Say(p.powerUsed and "Already used this turn" or "Not enough mana")
        return
    end
    if t == nil then return self:Do({ type = "power" }) end
    self.sel = { kind = "power", targets = t }
    self:Draw()
end

function P:ClickEntity(id)
    if not self:MyTurn() then return end
    local st = self.st
    local sel = self.sel
    if sel and Contains(sel.targets, id) then
        if sel.kind == "card" then return self:Do({ type = "play", card = sel.id, target = id, pos = sel.pos }) end
        if sel.kind == "power" then return self:Do({ type = "power", target = id }) end
        if sel.kind == "attack" then return self:Do({ type = "attack", attacker = sel.id, target = id }) end
    end
    local ent, owner = E().Find(st, id)
    if ent and owner == ME and E().CanAttack(st, ent) then
        if sel and sel.kind == "attack" and sel.id == id then return self:Cancel() end
        self.sel = { kind = "attack", id = id, targets = E().AttackTargets(st, ME) }
        return self:Draw()
    end
    if ent and owner == ME and not sel then
        if ent.key and ent.sleeping and not ent.charge then self:Say("It just arrived: it can attack next turn")
        elseif ent.frozen then self:Say("Frozen")
        elseif E().Attack(ent) <= 0 then self:Say(ent.key and "No Attack" or "")
        else self:Say("Already attacked") end
    end
    self:Cancel()
end

---------------------------------------------------------------------------
-- Dragging cards from the hand
---------------------------------------------------------------------------
-- The mouse in board coordinates (from the top-left).
function P:BoardCursor()
    local b = self.board
    local left, top = b:GetLeft(), b:GetTop()
    local mx, my = GetCursorPosition()
    local scale = b:GetEffectiveScale()
    return mx / scale - (left or 0), (top or 0) - my / scale
end

local DROP_LINE = Y.hand - 70 -- above this the card is on the board

function P:DragStart(f)
    if not self:MyTurn() then return end
    local x, y = self:BoardCursor()
    self.drag = { f = f, id = f.id, sx = x, sy = y }
end

-- Which character is at (x, y), if any.
function P:EntityAt(x, y)
    for i = 1, 2 do
        local h = self.heroes[i]
        if h.x and math.abs(x - h.x) <= HERO / 2 and math.abs(y - h.y) <= HERO / 2 then return i end
    end
    for id, f in pairs(self.minions) do
        if f:IsShown() and f.x and math.abs(x - f.x) <= MIN_W / 2 + 2 and math.abs(y - f.y) <= MIN_H / 2 + 2 then
            return id
        end
    end
end

-- The board spot (1 = far left) for a minion dropped at x.
function P:InsertPos(x)
    local n = 0
    for j, m in ipairs(self.st.players[ME].board) do
        local f = self.minions[m.id]
        if f and f.x and f.x < x then n = j end
    end
    return n + 1
end

function P:DragMove(x, y)
    local d = self.drag
    if not x then x, y = self:BoardCursor() end
    if not d.moved and (math.abs(x - d.sx) > 8 or math.abs(y - d.sy) > 8) then
        d.moved = true
        self.preview:Hide()
        self.sel = nil
    end
    if not d.moved then return end
    d.f:SetFrameLevel(self.board:GetFrameLevel() + 45)
    K.Place(d.f, self.board, x, y)
    -- A minion over the board: show where it will go.
    local c = E().Find(self.st, d.id)
    local card = c and Card(c.key)
    if card and card.type == "minion" and y < DROP_LINE then
        local board = self.st.players[ME].board
        local pos = self:InsertPos(x)
        local mx
        if #board == 0 then mx = CX
        elseif pos > #board then mx = (self.minions[board[#board].id].x or 0) + MIN_W / 2 + MIN_GAP / 2
        else mx = (self.minions[board[pos].id].x or 0) - MIN_W / 2 - MIN_GAP / 2 end
        K.Place(self.marker, self.board, mx, Y.myBoard)
        self.marker:Show()
    else
        self.marker:Hide()
    end
end

function P:DragEnd(x, y)
    local d = self.drag
    self.drag = nil
    self.marker:Hide()
    if not d or not d.moved then return end -- a plain click: OnClick handles it
    d.f.dragged = true
    local st = self.st
    local c = st and E().Find(st, d.id)
    if not c or not self:MyTurn() or y >= DROP_LINE then return self:Draw() end -- back to the hand
    local t = E().PlayTargets(st, ME, c)
    local card = Card(c.key)
    if t == false then
        self:Say(card.cost > st.players[ME].mana and "Not enough mana" or "You can't play that now")
        return self:Draw()
    end
    if card.type == "minion" then
        local pos = self:InsertPos(x)
        if t == nil then return self:Do({ type = "play", card = c.id, pos = pos }) end
        self.sel = { kind = "card", id = c.id, targets = t, pos = pos }
        self:Say("Choose a target")
        return self:Draw()
    end
    if t == nil then return self:Do({ type = "play", card = c.id }) end
    local hit = self:EntityAt(x, y)
    if hit and Contains(t, hit) then return self:Do({ type = "play", card = c.id, target = hit }) end
    self.sel = { kind = "card", id = c.id, targets = t }
    self:Say("Choose a target")
    self:Draw()
end

-- The AI's moves, one at a time with a pause between.
function P:Tick()
    local st = self.st
    if self.sayUntil and Now() > self.sayUntil then
        self.status:SetText("")
        self.sayUntil = nil
    end
    self:PreloadTick()
    if (self.nextRetry or 0) <= Now() then
        self.nextRetry = Now() + 1
        RetryModels()
    end
    if self.arrow and self.sel then self:DrawArrow() end
    if self.drag then self:DragMove() end
    local can = st ~= nil and st.active == ME and not st.over and not self:Busy() and not self.overlay:IsShown()
    if self.canAct ~= can then
        self.canAct = can
        self.endButton:SetEnabled(can)
        if st then self:Draw() end -- playable cards light up again
    end
    if self.pvp then return self:PvpTick() end
    if not st or st.over or self.overlay:IsShown() then return end
    if st.active == AIP and not self:Busy() then
        local wait = self.aiWait or 0
        if wait == 0 then
            self.aiWait = Now() + 1.0 -- slow enough to follow
        elseif Now() >= wait then
            self.aiWait = 0
            local a = ns.HS.AI.Choose(st)
            self:Do(a)
        end
    end
end

---------------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------------
-- Where everything is right now (board coordinates), by id.
function P:Positions()
    local pos = {}
    for i = 1, 2 do
        local h = self.heroes[i]
        pos[i] = { h.x or 0, h.y or 0, art = nil }
    end
    for id, f in pairs(self.minions) do
        if f:IsShown() then pos[id] = { f.x, f.y, art = f.art:GetTexture() } end
    end
    for id, f in pairs(self.handCards) do
        if f:IsShown() then pos[id] = { f.x, f.y } end
    end
    return pos
end

function P:Number(x, y, text, r, g, b, delay)
    local fs = table.remove(self.numFree)
    if not fs then
        fs = W.BigLabel(self.fx, 22, "GameFontNormalHuge")
        local face = fs:GetFont()
        if face then fs:SetFont(face, 22, "THICKOUTLINE") end
    end
    fs:Show()
    fs:SetText(text)
    fs:SetTextColor(r, g, b)
    fs:SetAlpha(0)
    K.Place(fs, self.board, x, y)
    C.Tween(0.9, function(k)
        fs:SetAlpha(k < 0.15 and k / 0.15 or (1 - (k - 0.15) / 0.85))
        K.Place(fs, self.board, x, y - 18 * k)
    end, function()
        fs:Hide()
        table.insert(self.numFree, fs)
    end, delay or 0)
end

function P:Banner(text, dur)
    self.banner:SetText(text)
    self.banner:Show()
    self.banner:SetAlpha(0)
    C.Tween(dur or 1, function(k)
        self.banner:SetAlpha(k < 0.2 and k / 0.2 or (k > 0.8 and (1 - k) / 0.2 or 1))
    end, function() self.banner:Hide() end)
end

-- A copy of a minion's look that fades where it died.
function P:Ghost(x, y, art, delay)
    local t = table.remove(self.ghostFree) or self.fx:CreateTexture(nil, "ARTWORK")
    t:Show()
    t:SetTexture(art)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t:SetSize(MIN_W - 8, MIN_H - 8)
    K.Place(t, self.board, x, y)
    t:SetAlpha(0)
    C.Tween(0.5, function(k)
        t:SetAlpha(1 - k)
        t:SetSize((MIN_W - 8) * (1 + k * 0.4), (MIN_H - 8) * (1 + k * 0.4))
        t:SetDesaturated(true)
    end, function()
        t:Hide()
        table.insert(self.ghostFree, t)
    end, delay)
end

-- Spell colours by school (cards and hero powers say which).
local SCHOOL = {
    fire = { 1, 0.45, 0.1 }, frost = { 0.45, 0.8, 1 }, arcane = { 0.8, 0.45, 1 }, nature = { 0.45, 1, 0.4 },
    lightning = { 0.7, 0.88, 1 }, holy = { 1, 0.92, 0.45 }, physical = { 1, 0.85, 0.6 },
}
local ENEMY_SHOW = 0.85 -- the opponent's card is shown this long before it happens
local ENEMY_LUNGE, MY_LUNGE = 0.6, 0.4

-- Glowing bits for spells (pooled).
function P:FxTex(name)
    local t = table.remove(self.fxFree)
    if not t then t = self.fx:CreateTexture(nil, "OVERLAY") end
    t:SetTexture(ART .. name)
    t:SetTexCoord(0, 1, 0, 1)
    if t.SetBlendMode then t:SetBlendMode("ADD") end
    t:SetVertexColor(1, 1, 1)
    t:SetAlpha(0)
    t:Show()
    return t
end

function P:FxDone(t)
    t:Hide()
    table.insert(self.fxFree, t)
end

-- A flash that swells and fades at (x, y).
function P:Burst(x, y, color, delay, size, tex)
    local t = self:FxTex(tex or "Blob")
    if not tex then t:SetVertexColor(color[1], color[2], color[3]) end
    K.Place(t, self.board, x, y)
    C.Tween(0.4, function(k)
        local s = size * (0.35 + k)
        t:SetSize(s, s)
        t:SetAlpha(1 - k)
    end, function() self:FxDone(t) end, delay)
end

-- A bolt with a short trail flying from one point to another in an arc.
function P:Bolt(x1, y1, x2, y2, color, delay, dur, size)
    local parts = {}
    for i = 1, 4 do
        local t = self:FxTex("Blob")
        t:SetVertexColor(color[1], color[2], color[3])
        local s = (size or 22) * (1.15 - i * 0.2)
        t:SetSize(s, s)
        parts[i] = t
    end
    local dist = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local arc = math.min(40, dist * 0.18)
    C.Tween(dur, function(k)
        for i, t in ipairs(parts) do
            local kk = math.max(0, k - (i - 1) * 0.07)
            K.Place(t, self.board, x1 + (x2 - x1) * kk, y1 + (y2 - y1) * kk - math.sin(math.pi * kk) * arc)
            t:SetAlpha(1 - (i - 1) * 0.25)
        end
    end, function() for _, t in ipairs(parts) do self:FxDone(t) end end, delay)
end

-- A wave across one side of the board (Flamestrike, Frost Nova...).
function P:Wave(y, color, delay)
    local t = self:FxTex("Blob")
    t:SetVertexColor(color[1], color[2], color[3])
    K.Place(t, self.board, CX, y)
    C.Tween(0.55, function(k)
        t:SetSize(490 * (0.3 + 0.8 * k), 84 * (1 - 0.3 * k))
        t:SetAlpha(k < 0.3 and k / 0.3 or (1 - (k - 0.3) / 0.7))
    end, function() self:FxDone(t) end, delay)
end

-- Play one action's events. `before` = positions before it happened.
-- Each event gets a time: spells fly first, numbers wait for the hit, the
-- board redraws when the last blow lands.
function P:Animate(events, before)
    local st = self.st
    local lead = 0
    for _, ev in ipairs(events) do
        if ev.kind == "play" and ev.owner == AIP then lead = ENEMY_SHOW break end
    end
    local at = {}      -- event index -> when it shows
    local idAt = {}    -- entity id -> when it was last hit
    local last = lead
    local ctx
    local shownCard = false
    for i, ev in ipairs(events) do
        local k = ev.kind
        if k == "play" then
            local card = Card(ev.key)
            local from = (ev.owner == ME and before[ev.id]) or before[ev.owner]
            local color = SCHOOL[card.school or (card.type == "spell" and "arcane" or "physical")]
            local mode = "bolt"
            if card.type == "spell" then
                local sp = card.spell or {}
                if not sp.target then
                    mode = (sp.effects and sp.effects[1] and sp.effects[1].op == "missiles") and "missiles" or "area"
                end
            end
            ctx = { from = from, color = color, mode = mode, start = lead + 0.05, n = 0, hits = {}, waves = {} }
            if ev.owner == AIP and not shownCard then
                -- Show what the opponent played, before it happens.
                shownCard = true
                self.preview:SetCard(ev.key)
                self.preview:Show()
                self.previewUntil = Now() + lead + 1.4
            end
        elseif k == "power" then
            local h = ns.HS.Heroes[st.players[ev.owner].heroKey]
            local pw = self.powers[ev.owner]
            ctx = { from = { pw.x, pw.y }, color = SCHOOL[h.power.school or "arcane"], mode = ev.target and "bolt" or "area",
                start = lead + 0.05, n = 0, hits = {}, waves = {} }
            if not ev.target then
                self:Burst(pw.x, pw.y, ctx.color, ctx.start, 50)
            end
        elseif k == "attack" then
            local enemy = st.active == AIP
            local dur = enemy and ENEMY_LUNGE or MY_LUNGE
            ctx = { attack = true, start = lead + dur / 2 }
            local a, t = before[ev.attacker], before[ev.target]
            local f = ev.attacker <= 2 and self.heroes[ev.attacker] or self.minions[ev.attacker]
            if a and t and f then
                local fx, fy = a[1], a[2]
                f:SetFrameLevel(self.board:GetFrameLevel() + 30)
                C.Tween(dur, function(kk)
                    local d = kk < 0.5 and (kk / 0.5) or (1 - (kk - 0.5) / 0.5)
                    d = d * d * (3 - 2 * d) * 0.78
                    K.Place(f, self.board, fx + (t[1] - fx) * d, fy + (t[2] - fy) * d)
                end, function() f:SetFrameLevel(self.board:GetFrameLevel() + 10) end, lead)
                self:Burst(t[1], t[2], SCHOOL.physical, ctx.start, 40)
            end
            W.PlaySound("U_CHAT_SCROLL_BUTTON")
        elseif k == "damage" or k == "heal" or k == "freeze" or k == "shield" or k == "buff" or k == "transform"
            or k == "armor" or k == "bounce" or k == "steal" or k == "doom" then
            local p = before[ev.id]
            local d = ctx and ctx.start or lead
            if ctx and not ctx.attack and p then
                if ctx.mode == "bolt" then
                    if not ctx.hits[ev.id] then
                        local from = ctx.from or p
                        self:Bolt(from[1], from[2], p[1], p[2], ctx.color, ctx.start, 0.38)
                        ctx.hits[ev.id] = ctx.start + 0.38
                        self:Burst(p[1], p[2], ctx.color, ctx.hits[ev.id], 48)
                    end
                    d = ctx.hits[ev.id]
                elseif ctx.mode == "missiles" and k == "damage" then
                    local launch = ctx.start + ctx.n * 0.22
                    ctx.n = ctx.n + 1
                    local from = ctx.from or p
                    self:Bolt(from[1], from[2], p[1], p[2], ctx.color, launch, 0.32, 15)
                    d = launch + 0.32
                    self:Burst(p[1], p[2], ctx.color, d, 30)
                else
                    -- Area: a wave across the row, then each target flashes.
                    local row = math.abs(p[2] - Y.enemyBoard) < 30 and Y.enemyBoard
                        or (math.abs(p[2] - Y.myBoard) < 30 and Y.myBoard or nil)
                    if row and not ctx.waves[row] then
                        ctx.waves[row] = true
                        self:Wave(row, ctx.color, ctx.start)
                    end
                    d = ctx.start + 0.3
                    if not ctx.hits[ev.id] then
                        ctx.hits[ev.id] = d
                        self:Burst(p[1], p[2], ctx.color, d, 40)
                    end
                end
            end
            if k == "freeze" and p then self:Burst(p[1], p[2], nil, d, 56, "HsFrozen") end
            at[i] = d
            idAt[ev.id] = d
            if d > last then last = d end
        elseif k == "death" then
            at[i] = (idAt[ev.id] or last) + 0.2
            if at[i] > last then last = at[i] end
        elseif k == "turn" then
            ctx = nil
        end
    end

    for i, ev in ipairs(events) do
        local p = ev.id and before[ev.id]
        local d = at[i] or last
        if ev.kind == "damage" and p then
            self:Number(p[1], p[2] - 6, "-" .. ev.amount, 1, 0.25, 0.2, d)
        elseif ev.kind == "heal" and p then
            self:Number(p[1], p[2] - 6, "+" .. ev.amount, 0.3, 1, 0.3, d)
        elseif ev.kind == "shield" and p then
            self:Number(p[1], p[2] - 6, "Blocked", 1, 0.85, 0.3, d)
        elseif ev.kind == "freeze" and p then
            self:Number(p[1], p[2] - 6, "Frozen", 0.6, 0.85, 1, d)
        elseif ev.kind == "armor" and p then
            self:Number(p[1], p[2] - 6, "+" .. ev.amount .. " Armor", 0.8, 0.8, 0.85, d)
        elseif ev.kind == "bounce" and p then
            self:Number(p[1], p[2] - 6, "Returned", 0.8, 0.8, 1, d)
        elseif ev.kind == "steal" and p then
            self:Number(p[1], p[2] - 6, "Stolen", 0.85, 0.5, 1, d)
        elseif ev.kind == "doom" and p then
            self:Number(p[1], p[2] - 6, "Corrupted", 0.7, 0.4, 0.9, d)
        elseif ev.kind == "weaponBreak" and p then
            self:Number(p[1] - 60, p[2], "Broken", 0.8, 0.8, 0.8, d)
        elseif ev.kind == "discard" and ev.owner == ME then
            self:Say("Discarded " .. Card(ev.key).name)
        elseif ev.kind == "death" and p and p.art then
            self:Ghost(p[1], p[2], p.art, d)
        elseif ev.kind == "fatigue" then
            local h = before[ev.owner]
            if h then self:Number(h[1], h[2] - 30, "Fatigue", 0.9, 0.5, 0.9, d) end
        elseif ev.kind == "burn" and ev.owner == ME then
            self:Say("Hand full: " .. Card(ev.key).name .. " burned")
        elseif ev.kind == "turn" then
            if ev.owner == ME then self:Banner("Your turn", 1.1) end
        end
    end
    -- The redraw comes when the last blow lands: new minions pop in, the board slides.
    local redraw = last
    self.busyUntil = Now() + redraw + 0.45
    C.Tween(0.01, function() end, function()
        self:Draw(true, before)
        if st.over then
            C.Tween(0.01, function() end, function() self:GameOver() end, 0.8)
        end
    end, redraw)
    ns.Changed()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function Move(f, board, x, y, animate, fromX, fromY, dur)
    f.x, f.y = x, y
    if animate and fromX and (math.abs(fromX - x) > 0.5 or math.abs(fromY - y) > 0.5) then
        C.Tween(dur or 0.22, function(k)
            local e = 1 - (1 - k) * (1 - k)
            K.Place(f, board, fromX + (x - fromX) * e, fromY + (y - fromY) * e)
        end)
    else
        K.Place(f, board, x, y)
    end
end

function P:MinionFrame(id)
    local f = self.minions[id]
    if f then return f, false end
    f = table.remove(self.free) or MakeMinion(self.board)
    f:SetFrameLevel(self.board:GetFrameLevel() + 10)
    f:SetScript("OnClick", function(_, button)
        if button == "RightButton" then return self:Cancel() end
        self:ClickEntity(f.id)
    end)
    f:SetScript("OnEnter", function() self:HoverMinion(f.id) end)
    f:SetScript("OnLeave", function() self:HoverEnd() end)
    self.minions[id] = f
    f.id = id
    return f, true
end

function P:HandFrame(id)
    local f = self.handCards[id]
    if f then return f, false end
    f = MakeCard(self.board, HAND_W, HAND_H)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetScript("OnClick", function(_, button)
        if f.dragged then f.dragged = nil return end -- that was a drag, not a click
        if button == "RightButton" then return self:Cancel() end
        local c = E().Find(self.st, f.id)
        if c then self:ClickHand(c) end
    end)
    f:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and f.mine then self:DragStart(f) end
    end)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and self.drag and self.drag.f == f then self:DragEnd(self:BoardCursor()) end
    end)
    f:SetScript("OnEnter", function()
        if not f.mine then return end
        f:SetFrameLevel(self.board:GetFrameLevel() + 35)
        K.Place(f, self.board, f.x, f.y - 14)
        self.preview:SetCard(f.key)
        self.preview:Show()
    end)
    f:SetScript("OnLeave", function()
        if self.drag and self.drag.f == f and self.drag.moved then return end
        f:SetFrameLevel(self.board:GetFrameLevel() + 20 + (f.slot or 0))
        K.Place(f, self.board, f.x, f.y)
        self:HoverEnd()
    end)
    self.handCards[id] = f
    f.id = id
    return f, true
end

-- Where the n-th of `count` things in a row goes.
local function RowX(i, count, width, gap, centre)
    local total = count * width + (count - 1) * gap
    return centre - total / 2 + (i - 1) * (width + gap) + width / 2
end

function P:Draw(animate, before)
    local st = self.st
    before = before or {}
    local centre = CX
    local rec = Save()
    self.statsText:SetText(string.format("Wins %d, losses %d\nStreak %d (best %d)", rec.wins, rec.losses, rec.streak, rec.best))
    if self.previewUntil and Now() > self.previewUntil then
        self.preview:Hide()
        self.previewUntil = nil
    end
    local seen = {}
    if not st then
        for _, f in pairs(self.minions) do f:Hide() end
        for _, f in pairs(self.handCards) do f:Hide() end
        for i = 1, 2 do self.heroes[i]:Hide() self.powers[i]:Hide() self.mana[i]:SetText("") end
        for i = 1, 2 do for j = 1, 10 do self.crystals[i][j]:Hide() end self.deckText[i]:SetText("") end
        self.endButton:Disable()
        return
    end
    local sel = self.sel
    local targets = {}
    for _, id in ipairs(sel and sel.targets or {}) do targets[id] = true end
    local myTurn = st.active == ME and not st.over

    -- Heroes and hero powers.
    for i = 1, 2 do
        local p = st.players[i]
        local h = ns.HS.Heroes[p.heroKey]
        local hf = self.heroes[i]
        hf:Show()
        hf.x, hf.y = centre, i == ME and Y.myHero or Y.enemyHero
        K.Place(hf, self.board, hf.x, hf.y)
        hf.portrait:SetPlayer(h.name, h.class)
        SetModel(hf.model, hf.portrait.class, h.npc, 0.95)
        hf.hp.text:SetText(tostring(p.hero.health))
        hf.hp.text:SetTextColor(1, p.hero.health < p.hero.maxHealth and 0.35 or 1, p.hero.health < p.hero.maxHealth and 0.35 or 1)
        hf.armor:SetShown(p.hero.armor > 0)
        hf.armor.text:SetText(tostring(p.hero.armor))
        local atk = E().Attack(p.hero)
        hf.atk:SetShown(atk > 0)
        hf.atk.text:SetText(tostring(atk))
        hf.frozen:SetShown(p.hero.frozen == true)
        local wp = p.hero.weapon
        hf.weapon:SetShown(wp ~= nil)
        if wp then
            local wc = Card(wp.key)
            hf.weapon.icon:SetTexture(wc.art)
            hf.weapon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            hf.weapon.atk.text:SetText(tostring(wp.attack))
            hf.weapon.dur.text:SetText(tostring(wp.durability))
            hf.weapon.key = wp.key
            if not hf.weapon.hooked then
                hf.weapon.hooked = true
                hf.weapon:SetScript("OnEnter", function(w)
                    if not w.key then return end
                    self.preview:SetCard(w.key)
                    self.preview:Show()
                    self.previewUntil = nil
                end)
                hf.weapon:SetScript("OnLeave", function() self:HoverEnd() end)
            end
        end
        local ring = hf.frame
        if targets[i] then ring:SetVertexColor(1, 0.35, 0.25)
        elseif i == ME and myTurn and E().CanAttack(st, p.hero) then ring:SetVertexColor(0.4, 1, 0.4)
        else ring:SetVertexColor(1, 1, 1) end
        local pw = self.powers[i]
        pw:Show()
        pw.icon:SetTexture(h.power.art)
        pw.cost.text:SetText(tostring(h.power.cost))
        local usable = i == ME and myTurn and E().PowerTargets(st, ME) ~= false
        pw.icon:SetDesaturated(p.powerUsed)
        pw.ring:SetVertexColor(usable and 0.4 or 1, 1, usable and 0.4 or 1)
        -- Mana.
        self.mana[i]:SetText(p.mana .. "/" .. p.maxMana)
        for j = 1, 10 do
            local t = self.crystals[i][j]
            t:SetShown(j <= p.maxMana)
            if j <= p.mana then t:SetVertexColor(1, 1, 1) t:SetAlpha(1)
            elseif j > p.maxMana - p.locked then t:SetVertexColor(1, 0.3, 0.3) t:SetAlpha(0.9)
            else t:SetVertexColor(0.5, 0.5, 0.5) t:SetAlpha(0.6) end
        end
        self.deckText[i]:SetText(#p.deck > 0 and (#p.deck .. " left") or "Empty")
        local d = self.decks[i]
        d:SetShown(#p.deck > 0)
        d.layers[2]:SetShown(#p.deck >= 10)
        d.layers[3]:SetShown(#p.deck >= 20)
    end

    -- Boards.
    for i = 1, 2 do
        local p = st.players[i]
        local y = i == ME and Y.myBoard or Y.enemyBoard
        for j, m in ipairs(p.board) do
            seen[m.id] = true
            local f, new = self:MinionFrame(m.id)
            f:Show()
            local x = RowX(j, #p.board, MIN_W, MIN_GAP, centre)
            local c = Card(m.key)
            f.art:SetTexture(c.art)
            if c.art:find("\\Icons\\") then f.art:SetTexCoord(0.08, 0.92, 0.08, 0.92) else f.art:SetTexCoord(0, 1, 0, 1) end
            SetModel(f.model, f.art, c.npc, 0.8)
            f.taunt:SetShown(m.taunt == true)
            f.doom:SetShown(m.doomedBy ~= nil)
            f.divine:SetShown(m.divineShield == true)
            f.frozen:SetShown(m.frozen == true)
            f.zzz:SetShown(i == ME and myTurn and m.sleeping and not (m.charge or m.auraCharge) and true or false)
            local atk = E().Attack(m)
            f.atk.text:SetText(tostring(atk))
            f.atk.text:SetTextColor(1, atk > (c.attack or 0) and 1 or 1, atk > (c.attack or 0) and 0.4 or 1)
            if atk > (c.attack or 0) then f.atk.text:SetTextColor(0.45, 1, 0.45) else f.atk.text:SetTextColor(1, 1, 1) end
            f.hp.text:SetText(tostring(m.health))
            if m.health < m.maxHealth then f.hp.text:SetTextColor(1, 0.35, 0.35)
            elseif m.maxHealth > (c.health or 0) then f.hp.text:SetTextColor(0.45, 1, 0.45)
            else f.hp.text:SetTextColor(1, 1, 1) end
            if targets[m.id] then f.ring:SetVertexColor(1, 0.35, 0.25)
            elseif sel and sel.kind == "attack" and sel.id == m.id then f.ring:SetVertexColor(1, 0.85, 0.2)
            elseif i == ME and myTurn and E().CanAttack(st, m) then f.ring:SetVertexColor(0.4, 1, 0.4)
            else f.ring:SetVertexColor(1, 1, 1) end
            if new and animate then
                -- Played from the hand: fly from where the card was; summoned: pop in.
                local from = before[m.id]
                Move(f, self.board, x, y, true, from and from[1] or x, from and from[2] or y, 0.25)
                if not from then
                    f:SetScale(0.3)
                    C.Tween(0.2, function(k) f:SetScale(0.3 + 0.7 * k) end, function() f:SetScale(1) end)
                end
            else
                Move(f, self.board, x, y, animate and f.x ~= nil, f.x, f.y)
            end
        end
    end
    for id, f in pairs(self.minions) do
        if not seen[id] then
            f:Hide()
            self.minions[id] = nil
            f.x, f.y = nil, nil
            table.insert(self.free, f)
        end
    end

    -- Hands: yours face up at the bottom, theirs face down at the top.
    local handSeen = {}
    for i = 1, 2 do
        local p = st.players[i]
        local n = #p.hand
        local mine = i == ME
        local w = mine and HAND_W or 30
        local gap = mine and math.min(6, (440 - n * w) / math.max(1, n - 1)) or math.min(2, (170 - n * w) / math.max(1, n - 1))
        for j, c in ipairs(p.hand) do
            handSeen[c.id] = true
            local f, new = self:HandFrame(c.id)
            f.mine = mine
            f.slot = j
            f:Show()
            f:SetSize(w, mine and HAND_H or 42)
            if mine then
                f:SetCard(c.key)
                local playable = myTurn and E().PlayTargets(st, ME, c) ~= false
                f.frame:SetAlpha(1)
                f.gem.text:SetTextColor(1, 1, 1)
                f.ready:SetShown(playable and not self:Busy())
                if sel and sel.kind == "card" and sel.id == c.id then
                    f.ready:SetColorTexture(1, 0.82, 0.2, 0.95)
                    f.ready:Show()
                else
                    f.ready:SetColorTexture(0.3, 1, 0.3, 0.85)
                end
            else
                f:SetCard(nil, true)
                f.ready:Hide()
            end
            f:SetFrameLevel(self.board:GetFrameLevel() + 20 + j)
            local x = mine and RowX(j, n, w, gap, centre) or RowX(j, n, w, gap, 230)
            local y = mine and Y.hand or Y.enemyHand
            if self.drag and self.drag.f == f and self.drag.moved then
                f.x, f.y = x, y -- being dragged: it stays under the mouse
            elseif new and animate then
                -- Drawn: slide in from the deck.
                Move(f, self.board, x, y, true, DECK_X, DECK_Y[i], 0.3)
            else
                Move(f, self.board, x, y, animate and f.x ~= nil, f.x, f.y)
            end
        end
    end
    for id, f in pairs(self.handCards) do
        if not handSeen[id] then
            f:Hide()
            self.handCards[id] = nil
        end
    end

    self.endButton:SetEnabled(myTurn and not self:Busy() and not self.overlay:IsShown())
    self.endButton:SetText(st.over and "GAME OVER" or (st.active == ME and "END TURN" or "ENEMY TURN"))
    local moves = false
    if myTurn then
        for _, a in ipairs(E().Legal(st)) do if a.type ~= "end" then moves = true break end end
    end
    if not myTurn then self.endButton.bg:SetVertexColor(0.55, 0.55, 0.55)
    elseif moves then self.endButton.bg:SetVertexColor(1, 0.85, 0.3)
    else self.endButton.bg:SetVertexColor(0.45, 1, 0.4) end
    if self.arrow and not sel then self.arrow:Hide() end
end

function P:DrawArrow()
    local sel = self.sel
    local from
    if sel.kind == "card" then from = self.handCards[sel.id]
    elseif sel.kind == "power" then from = self.powers[ME]
    elseif sel.kind == "attack" then from = sel.id <= 2 and self.heroes[sel.id] or self.minions[sel.id] end
    if not from then return self.arrow:Hide() end
    local b = self.board
    local left, top = b:GetLeft(), b:GetTop()
    if not left then return end
    local fx, fy = from:GetCenter()
    local mx, my = GetCursorPosition()
    local scale = b:GetEffectiveScale()
    self.arrow:SetStartPoint("BOTTOMLEFT", b, fx - left, fy - (top - BH))
    self.arrow:SetEndPoint("BOTTOMLEFT", b, mx / scale - left, my / scale - (top - BH))
    self.arrow:Show()
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
function P:HoverMinion(id)
    local m = self.st and E().Find(self.st, id)
    if not m then return end
    self.preview:SetCard(m.key, false, { E().Attack(m), m.health, m.maxHealth })
    self.preview:Show()
    self.previewUntil = nil
end

function P:HoverEnd()
    if not self.previewUntil then self.preview:Hide() end
end

function P:HoverHero(i)
    if not self.st then return end
    local p = self.st.players[i]
    local h = ns.HS.Heroes[p.heroKey]
    GameTooltip:SetOwner(self.heroes[i], "ANCHOR_RIGHT")
    GameTooltip:SetText(h.name, 1, 0.82, 0)
    GameTooltip:AddLine(string.format("Health %d/%d%s", p.hero.health, p.hero.maxHealth,
        p.hero.armor > 0 and (", Armor " .. p.hero.armor) or ""), 1, 1, 1)
    GameTooltip:AddLine("Cards in hand " .. #p.hand .. ", in deck " .. #p.deck, 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function P:HoverPower(i)
    if not self.st then return end
    local h = ns.HS.Heroes[self.st.players[i].heroKey]
    GameTooltip:SetOwner(self.powers[i], "ANCHOR_RIGHT")
    GameTooltip:SetText(h.power.name .. " (" .. h.power.cost .. " mana)", 1, 0.82, 0)
    GameTooltip:AddLine("Hero Power: " .. h.power.text, 1, 1, 1, true)
    GameTooltip:Show()
end

function P:Refresh()
    local s = ns.Session.Get(self.kind)
    if s or self.setupOpen or self.pvp then return self:RefreshPvp(s) end
    if not self.st then return end
    if self.st.over and not self.overlay:IsShown() then self:GameOver() end
    self:Draw()
end

---------------------------------------------------------------------------
-- PvP (a Session lobby; the host runs the engine: Games\Hearthstone.lua)
---------------------------------------------------------------------------
-- Which buttons the overlay shows (keys of self.pvpButtons), in a row.
function P:PvpButtons(keys)
    for _, b in pairs(self.pvpButtons) do b:Hide() end
    local width = 0
    for _, key in ipairs(keys) do width = width + self.pvpButtons[key]:GetWidth() + 8 end
    local x = -width / 2
    for _, key in ipairs(keys) do
        local b = self.pvpButtons[key]
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", self.overlay, "BOTTOM", x, 30)
        b:Show()
        x = x + b:GetWidth() + 8
    end
end

-- Hide the start screen's own buttons (the PvP screens use their own).
function P:PvpScreen(title, sub, lobby, keys)
    self.overlay:Show()
    for _, b in ipairs(self.pick) do b:Hide() end
    for _, r in ipairs(self.deckRows) do r:Hide() end
    for _, b in ipairs({ self.newDeckButton, self.backButton, self.againButton, self.resumeButton, self.friendButton }) do
        b:Hide()
    end
    self.overTitle:SetText(title)
    self.overTitle:SetTextColor(1, 0.82, 0)
    self.overSub:SetText(sub or "")
    self.lobbyText:SetText(lobby or "")
    self:PvpButtons(keys or {})
end

-- Your hand from the host's whisper (by card id); the cards not here yet are
-- left out until it comes.
local function MyKeys(s)
    local keyOf = {}
    for _, c in ipairs(ns.Session.MyCards(s) or {}) do keyOf[c.id] = c.key end
    return keyOf
end

-- The game as you may see it, with you as player 1.
function P:PvpView(s)
    local v = E().Copy(s.view)
    local seat = self.G.Seat(s, ns.Me()) or 1
    local keyOf = MyKeys(s)
    local hand = {}
    for _, c in ipairs(v.players[seat].hand) do
        c.key = keyOf[c.id]
        if c.key then table.insert(hand, c) end
    end
    v.players[seat].hand = hand
    if seat == 2 then v = E().Mirror(v) end
    return v
end

function P:PvpEvents(s)
    local seat = self.G.Seat(s, ns.Me()) or 1
    local keyOf = MyKeys(s)
    local out = {}
    for i, ev in ipairs(s.events or {}) do
        local c = E().Copy(ev)
        if c.kind == "draw" and c.owner == seat then c.key = keyOf[c.id] end
        out[i] = c
    end
    if seat == 2 then out = E().Mirror(out) end
    return out
end

function P:PvpDeck(heroKey, deck)
    local text = "deck:" .. heroKey
    if not deck.basic then text = text .. ":" .. table.concat(deck.cards, ",") end
    local ok, why = ns.Session.Act(self.kind, text)
    if ok == false then self:Say(why or "The host didn't take it") end
    self:Refresh()
end

function P:PvpDo(action)
    local s = ns.Session.Get(self.kind)
    if not (s and self:MyTurn()) then return false end
    local seat = self.G.Seat(s, ns.Me())
    local a = seat == 2 and E().Mirror(action) or action
    local ok, why = ns.Session.Act(self.kind, "do:" .. self.G.EncodeAction(a))
    if ok == false then
        self:Say(why or "Can't do that")
        return false
    end
    self.sel = nil
    if self.arrow then self.arrow:Hide() end
    self.busyUntil = Now() + 0.25 -- until the host's answer comes back
    return true
end

-- Leave PvP for the solo game again.
function P:LeavePvp()
    self.pvp, self.pvpGame, self.pvpStep, self.setupOpen = nil, nil, nil, false
    self.concede:Hide()
    local saved = Save().game
    self.st = (saved and saved.players and not saved.over) and saved or nil
    self:ShowStart()
    if self.st then self:Draw() end
end

function P:RefreshPvp(s)
    local S, me = ns.Session, ns.Me()
    if not s then
        -- The lobby panel (or back from a game).
        if self.pvp then self:LeavePvp() end
        self.setup:SetShown(self.setupOpen)
        self.game:SetShown(not self.setupOpen)
        if self.setupOpen then A.RefreshSetup(self) end
        return
    end
    self.setupOpen = false
    self.setup:Hide()
    self.game:Show()
    if not self.pvp then
        self.pvp = true
        self.pvpGame, self.pvpStep = nil, nil
    end
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local names = {}
    for _, p in ipairs(s.players) do table.insert(names, p.name .. (p.name == s.host and " (host)" or "")) end
    local who = "Players: " .. table.concat(names, ", ")
    self.concede:SetShown(s.phase == "rolling" and s.stage == "play" and seated)

    if s.phase == "lobby" then
        local keys = {}
        if host then
            if s.test and S.CanAddBot(s) then table.insert(keys, "bot") end
            table.insert(keys, "start")
            table.insert(keys, "close")
        elseif seated then
            table.insert(keys, "leave")
        end
        self:PvpScreen("Hearthstone: lobby", A.ScopeLine(s), who .. "\n\n"
            .. (#s.players < 2 and "Waiting for an opponent..." or (host and "Start when you're ready." or "Waiting for the host to start.")),
            keys)
        self.pvpButtons.start:SetEnabled(#s.players >= 2)
        return
    elseif s.phase == "cancelled" then
        self:PvpScreen("The lobby is closed", s.banner or "", "", { "done" })
        return
    end

    if s.stage == "decks" then
        if seated and not (s.chosen and s.chosen[me]) then
            -- Pick a hero and deck (the normal start screen, sent to the host).
            if not self.picking then
                self.picking = true
                self:ShowStart()
            end
        else
            self.picking = false
            local waiting = {}
            for _, p in ipairs(s.players) do
                if not (s.chosen and s.chosen[p.name]) then table.insert(waiting, p.name) end
            end
            self:PvpScreen("Ready", "Waiting for " .. table.concat(waiting, ", ") .. " to choose a deck...", who,
                host and { "close" } or { "leave" })
        end
        return
    end
    self.picking = false

    -- The game itself.
    if s.view then
        if s.recordId ~= self.pvpGame then
            self.pvpGame, self.pvpStep, self.counted = s.recordId, nil, false
            local keys = {}
            for i = 1, 2 do
                for _, c in ipairs(s.view.players[i].hand) do if c.key then table.insert(keys, c.key) end end
            end
            P.Preload(P.CreaturesFor(keys, { s.view.players[1].heroKey, s.view.players[2].heroKey }), true)
        end
        local cards = S.MyCards(s)
        if s.step ~= self.pvpStep then
            local first = self.pvpStep == nil
            local before = not first and self:Positions() or nil
            self.pvpStep, self.pvpCards = s.step, cards
            self.st = self:PvpView(s)
            if s.view.turn ~= self.pvpTurn then
                self.pvpTurn, self.turnSeen = s.view.turn, Now()
            end
            if not (s.phase == "done" and first) then self.overlay:Hide() end
            if first then
                self:Draw()
                self:Banner(self.st.active == ME and "You go first" or "Your opponent goes first", 1.2)
            else
                self:Animate(self:PvpEvents(s), before)
            end
        elseif cards ~= self.pvpCards then
            -- Your hand arrived after the board.
            self.pvpCards = cards
            self.st = self:PvpView(s)
            self:Draw()
        end
    end
    if s.phase == "done" then self:PvpOver(s) end
end

-- The game is over: who won, the score in this lobby, rematch or leave.
function P:PvpOver(s)
    local S, me = ns.Session, ns.Me()
    if self:Busy() then return end -- let the last blows land first
    local won = s.result and s.result.winner == me
    local draw = s.result and not s.result.winner
    if not self.counted and not s.test and S.Find(s, me) then
        self.counted = true
        local rec = Save()
        rec.pvpWins, rec.pvpLosses = rec.pvpWins or 0, rec.pvpLosses or 0
        if won then rec.pvpWins = rec.pvpWins + 1 elseif not draw then rec.pvpLosses = rec.pvpLosses + 1 end
        W.PlaySound(won and "LEVELUP" or "RAID_WARNING")
    end
    local score = {}
    for _, p in ipairs(s.players) do table.insert(score, p.name .. " " .. ((s.score and s.score[p.name]) or 0)) end
    local rec = Save()
    local keys = S.IsHost(s) and { "rematch", "close" } or { "leave" }
    self:PvpScreen(won and "Victory!" or (draw and "Draw" or "Defeat"), s.banner or "",
        "Score: " .. table.concat(score, "  -  ") .. string.format("\nYour PvP record: %d wins, %d losses.",
            rec.pvpWins or 0, rec.pvpLosses or 0), keys)
    self.overTitle:SetTextColor(won and 1 or 0.9, won and 0.82 or 0.3, won and 0 or 0.3)
end

-- Every frame in PvP: the turn clock on the End Turn button.
function P:PvpTick()
    local s = ns.Session.Get(self.kind)
    if s and s.phase == "done" and s.view and not self.overlay:IsShown() and not self:Busy() then
        return self:PvpOver(s)
    end
    local st = self.st
    if not st or st.over or self.overlay:IsShown() or not self.turnSeen then return end
    local left = math.ceil(self.G.TURN_TIME - (Now() - self.turnSeen))
    if left <= 20 and left >= 0 and st.active == ME then
        self.endButton:SetText("END TURN (" .. left .. ")")
        self.ticking = true
    elseif self.ticking then
        self.ticking = false
        self:Draw()
    end
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.hearthstone = P.New

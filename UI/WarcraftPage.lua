-- WarcraftPage: the RTS. A scrolling map on top, a Warcraft-style panel at
-- the bottom (minimap, what's selected, the command card). Everything is
-- drawn from the engine's state (ns.WC.Engine); the player's clicks become
-- E.Command calls, the AI runs every second for the other side.
local ADDON, ns = ...

local W = ns.Widgets
local K = ns.Kit
local P = {}
P.__index = P
ns.WarcraftPage = P

local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"
local BW, BH = 738, 462
local BAR = 22                  -- resource bar
local VIEW_H = 344              -- the map view
local TILE = 20                 -- pixels per tile
local STEP = 0.05               -- engine step
local ME, CPU = 1, 2
local MM_SCALE = 2              -- minimap pixels per tile
local EDGE, SCROLL = 10, 650    -- edge scrolling
local TEAM = { { 0.25, 0.55, 1 }, { 1, 0.25, 0.2 } }
local BUILDING_ART = {
    town_hall = "WcTownHall", farm = "WcFarm", barracks = "WcBarracks",
    great_hall = "WcGreatHall", orc_burrow = "WcBurrow", orc_barracks = "WcOrcBarracks", gold_mine = "WcMine",
}

local function WC() return ns.WC end
local function E() return ns.WC.Engine end
local function Now() return GetTime and GetTime() or 0 end

local function Save()
    local rec = ns.db.warcraft or {}
    ns.db.warcraft = rec
    rec.wins, rec.losses = rec.wins or 0, rec.losses or 0
    return rec
end

---------------------------------------------------------------------------
-- Unit models: each unit is its WoW creature. A creature's look is saved
-- the first time it loads, so every copy matches and later loads are quick.
---------------------------------------------------------------------------
local MODEL_W, MODEL_H = 40, 48
local ANIM = { stand = 0, death = 1, walk = 4, attack = 17, dead = 6 }

local function Looks()
    local rec = Save()
    rec.looks = rec.looks or {}
    return rec.looks
end

local function LoadModel(m)
    local look = Looks()[m.npc]
    if look and m.SetDisplayInfo then m:SetDisplayInfo(look) else m:SetCreature(m.npc) end
    m.anim = nil
    m.tried = Now()
end

local function MakeModel(parent)
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, parent)
    if not ok or not m or not m.SetCreature then return nil end
    m:SetSize(MODEL_W, MODEL_H)
    m.waits = pcall(m.SetScript, m, "OnModelLoaded", function(self)
        self.loaded = true
        if self.npc and not Looks()[self.npc] and self.GetDisplayInfo then
            local look = self:GetDisplayInfo()
            if look and look > 0 then Looks()[self.npc] = look end
        end
        if self.SetPortraitZoom then self:SetPortraitZoom(0) end
        self.anim = nil
    end)
    m:SetScript("OnShow", function(self) if self.npc then LoadModel(self) end end)
    return m
end

-- Which animation fits what the unit is doing.
local function AnimFor(u, moved)
    local o = u.order
    if moved then return ANIM.walk end
    local d = ns.WC.Units[u.type]
    if (u.cd or 0) > d.cooldown - 0.45 and o and o.type == "attack" then return ANIM.attack end
    if u.phase == "work" and o and o.type == "gather" and o.res == "lumber" then return ANIM.attack end
    if o and o.type == "build" and o.site then return ANIM.attack end
    return ANIM.stand
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function P.New(parent, kind)
    local self = setmetatable({ kind = kind, sel = {}, camX = 0, camY = 0, acc = 0, think = 0,
        treeTex = {}, unitFrames = {}, framePool = {}, corpses = {}, buildTex = {}, fxFree = {}, mmTrees = {} }, P)
    self.setup = CreateFrame("Frame", nil, parent)
    self.setup:Hide()
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    local panel = W.Panel(v)
    panel:SetAllPoints()
    local b = CreateFrame("Frame", nil, v)
    b:SetSize(BW, BH)
    b:SetPoint("TOPLEFT")
    b:SetFrameLevel(panel:GetFrameLevel() + 2)
    self.board = b

    -- Resource bar (on its own frame, above the map).
    local barFrame = CreateFrame("Frame", nil, b)
    barFrame:SetPoint("TOPLEFT")
    barFrame:SetPoint("TOPRIGHT")
    barFrame:SetHeight(BAR)
    barFrame:SetFrameLevel(b:GetFrameLevel() + 30)
    local bar = barFrame:CreateTexture(nil, "BACKGROUND")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(BAR)
    bar:SetColorTexture(0.06, 0.05, 0.04, 0.95)
    local function Res(icon, x)
        local t = barFrame:CreateTexture(nil, "ARTWORK")
        t:SetTexture(ART .. icon)
        t:SetSize(16, 16)
        t:SetPoint("TOPLEFT", x, -3)
        local l = W.Label(barFrame, "", "GameFontHighlight")
        l:SetPoint("LEFT", t, "RIGHT", 4, 0)
        return l
    end
    self.goldText = Res("WcGold", 300)
    self.lumberText = Res("WcLumber", 390)
    self.foodText = Res("WcFood", 480)
    self.clock = W.Label(barFrame, "", "GameFontNormalSmall")
    self.clock:SetPoint("TOPRIGHT", -8, -5)
    self.statsText = W.Label(barFrame, "", "GameFontDisableSmall")
    self.statsText:SetPoint("TOPLEFT", 8, -5)
    self.newButton = W.Button(barFrame, "New game", 80, function() self:ShowStart() end, 18)
    self.newButton:SetPoint("TOPLEFT", 160, -2)
    local idle = CreateFrame("Button", nil, barFrame)
    idle:SetSize(70, 18)
    idle:SetPoint("TOPLEFT", 640, -2)
    idle.icon = idle:CreateTexture(nil, "ARTWORK")
    idle.icon:SetSize(16, 16)
    idle.icon:SetPoint("LEFT")
    idle.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    idle.text = W.Label(idle, "", "GameFontHighlightSmall")
    idle.text:SetPoint("LEFT", idle.icon, "RIGHT", 3, 0)
    idle:SetScript("OnClick", function() self:NextIdleWorker() end)
    W.Tooltip(idle, "Idle workers", "Select the next worker with nothing to do (and look at it).")
    self.idleButton = idle

    -- The map view.
    local view = CreateFrame("Frame", nil, b)
    view:SetPoint("TOPLEFT", 0, -BAR)
    view:SetSize(BW, VIEW_H)
    if view.SetClipsChildren then view:SetClipsChildren(true) end
    view:EnableMouse(true)
    self.view = view
    self.ground = view:CreateTexture(nil, "BACKGROUND")
    self.ground:SetAllPoints()
    local okWrap = pcall(self.ground.SetTexture, self.ground, ART .. "WcGrass", "REPEAT", "REPEAT")
    if not okWrap then self.ground:SetTexture(ART .. "WcGrass") end
    local function Layer(level)
        local f = CreateFrame("Frame", nil, view)
        f:SetAllPoints()
        f:SetFrameLevel(view:GetFrameLevel() + level)
        return f
    end
    self.treeLayer = Layer(1)
    self.buildLayer = Layer(2)
    self.unitLayer = Layer(4)
    self.fxLayer = Layer(8)
    self.box = self.fxLayer:CreateTexture(nil, "OVERLAY")
    self.box:SetColorTexture(0.3, 1, 0.3, 0.18)
    self.box:Hide()
    self.ghost = self.fxLayer:CreateTexture(nil, "OVERLAY")
    self.ghost:SetAlpha(0.6)
    self.ghost:Hide()
    self.rallyFlag = self.fxLayer:CreateTexture(nil, "OVERLAY")
    self.rallyFlag:SetTexture(ART .. "WcFlag")
    self.rallyFlag:SetSize(18, 22)
    self.rallyFlag:Hide()
    self.marker = self.fxLayer:CreateTexture(nil, "OVERLAY")
    self.marker:SetTexture(ART .. "WcSelect")
    self.marker:Hide()
    self.status = W.Label(self.fxLayer, "", "GameFontNormal")
    self.status:SetPoint("TOP", 0, -8)
    self.status:SetTextColor(1, 0.85, 0.3)

    view:SetScript("OnMouseDown", function(_, button) self:MouseDown(button) end)
    view:SetScript("OnMouseUp", function(_, button) self:MouseUp(button) end)
    self.keys = K.Keys(view, { UP = true, DOWN = true, LEFT = true, RIGHT = true, A = true, B = true, F = true,
        C = true, G = true, H = true, M = true, O = true, P = true, R = true, S = true, T = true, W = true, Y = true },
        function(key) self:Key(key) end)

    -- The bottom panel: minimap, selection, command card.
    local hud = CreateFrame("Frame", nil, b)
    hud:SetPoint("TOPLEFT", 0, -(BAR + VIEW_H))
    hud:SetPoint("BOTTOMRIGHT")
    hud:SetFrameLevel(view:GetFrameLevel() + 20)
    hud:EnableMouse(true)
    local hbg = hud:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(0.1, 0.08, 0.06, 1)
    local edge = hud:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("TOPRIGHT")
    edge:SetHeight(2)
    edge:SetColorTexture(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 1)
    self.hud = hud

    local mm = CreateFrame("Frame", nil, hud)
    mm:SetSize(64 * MM_SCALE, 40 * MM_SCALE)
    mm:SetPoint("TOPLEFT", 6, -7)
    mm:EnableMouse(true)
    local mbg = mm:CreateTexture(nil, "BACKGROUND")
    mbg:SetAllPoints()
    mbg:SetColorTexture(0.2, 0.32, 0.14, 1)
    self.mm = mm
    self.mmDots = K.Pool(mm, function(parent)
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1)
        return t
    end)
    self.mmCam = {}
    for i = 1, 4 do
        local t = mm:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetColorTexture(1, 1, 1, 0.9)
        self.mmCam[i] = t
    end
    mm:SetScript("OnMouseDown", function(_, button) self:MinimapClick(button) end)

    -- Selection info.
    self.portrait = hud:CreateTexture(nil, "ARTWORK")
    self.portrait:SetSize(48, 48)
    self.portrait:SetPoint("TOPLEFT", 150, -10)
    self.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.selName = W.Label(hud, "", "GameFontNormal")
    self.selName:SetPoint("TOPLEFT", self.portrait, "TOPRIGHT", 8, -2)
    self.selHp = W.Label(hud, "", "GameFontHighlightSmall")
    self.selHp:SetPoint("TOPLEFT", self.selName, "BOTTOMLEFT", 0, -3)
    self.selStatus = W.Label(hud, "", "GameFontDisableSmall")
    self.selStatus:SetPoint("TOPLEFT", self.selHp, "BOTTOMLEFT", 0, -3)
    self.selStatus:SetWidth(260)
    self.selStatus:SetJustifyH("LEFT")
    self.groupIcons = {}
    for i = 1, 12 do
        local t = hud:CreateTexture(nil, "ARTWORK")
        t:SetSize(24, 24)
        t:SetPoint("TOPLEFT", 150 + ((i - 1) % 8) * 27, -10 - math.floor((i - 1) / 8) * 27)
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        t:Hide()
        self.groupIcons[i] = t
    end
    self.queueButtons = {}
    for i = 1, 5 do
        local q = CreateFrame("Button", nil, hud)
        q:SetSize(24, 24)
        q:SetPoint("TOPLEFT", 150 + (i - 1) * 27, -62)
        q.icon = q:CreateTexture(nil, "ARTWORK")
        q.icon:SetAllPoints()
        q.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        q:SetScript("OnClick", function() self:CancelTrain() end)
        W.Tooltip(q, "Training", "Click to cancel the last one (you get the gold back).")
        q:Hide()
        self.queueButtons[i] = q
    end
    self.progress = hud:CreateTexture(nil, "ARTWORK")
    self.progress:SetColorTexture(0.3, 0.8, 0.3, 1)
    self.progress:SetHeight(4)
    self.progress:Hide()

    -- Command card: 4 x 2 buttons.
    self.cmds = {}
    for i = 1, 8 do
        local c = CreateFrame("Button", nil, hud)
        c:SetSize(46, 38)
        c:SetPoint("TOPLEFT", 520 + ((i - 1) % 4) * 52, -8 - math.floor((i - 1) / 4) * 42)
        local cb = c:CreateTexture(nil, "BACKGROUND")
        cb:SetAllPoints()
        cb:SetColorTexture(0, 0, 0, 1)
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetPoint("TOPLEFT", 2, -2)
        c.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.hotkey = W.Label(c, "", "NumberFontNormalSmall")
        c.hotkey:SetPoint("TOPRIGHT", -2, -2)
        local hl = c:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.15)
        c:SetScript("OnClick", function() if c.action then c.action() end end)
        c:SetScript("OnEnter", function()
            if not c.title then return end
            GameTooltip:SetOwner(c, "ANCHOR_TOP")
            GameTooltip:SetText(c.title, 1, 0.82, 0)
            if c.tip then GameTooltip:AddLine(c.tip, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c:Hide()
        self.cmds[i] = c
    end

    -- Start / game over overlay.
    local o = CreateFrame("Frame", nil, b)
    o:SetAllPoints()
    o:SetFrameLevel(b:GetFrameLevel() + 80)
    o:EnableMouse(true)
    local shade = o:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.75)
    self.overlay = o
    self.overTitle = W.BigLabel(o, 26, "GameFontNormalHuge")
    self.overTitle:SetPoint("TOP", 0, -60)
    self.overSub = W.Label(o, "", "GameFontHighlight")
    self.overSub:SetPoint("TOP", self.overTitle, "BOTTOM", 0, -8)
    self.overSub:SetWidth(BW - 120)
    self.picks = {}
    for i, f in ipairs({ "human", "orc" }) do
        local btn = CreateFrame("Button", nil, o)
        btn:SetSize(150, 170)
        btn:SetPoint("TOP", (i - 1.5) * 190, -130)
        local art = btn:CreateTexture(nil, "ARTWORK")
        art:SetSize(128, 128)
        art:SetPoint("TOP")
        art:SetTexture(ART .. (f == "human" and "WcTownHall" or "WcGreatHall"))
        local label = W.Label(btn, WC().Factions[f].name, "GameFontNormalLarge")
        label:SetPoint("TOP", art, "BOTTOM", 0, -6)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        btn:SetScript("OnClick", function() self:NewGame(f) end)
        W.Tooltip(btn, "Play " .. WC().Factions[f].name, "Your opponent plays the other side.")
        btn.faction = f
        self.picks[i] = btn
    end
    self.againButton = W.Button(o, "Play again", 110, function() self:ShowStart() end, 26)
    self.againButton:SetPoint("TOP", self.overSub, "BOTTOM", 0, -20)
    self.resumeButton = W.Button(o, "Back to the game", 140, function() self:Resume() end, 22)
    self.resumeButton:SetPoint("BOTTOM", 0, 30)

    v:SetScript("OnUpdate", function(_, elapsed) self:Tick(elapsed) end)
    v:SetScript("OnHide", function()
        if not self.paused then self.autoPaused = true end
        self:Pause()
    end)
    v:SetScript("OnShow", function() if self.st and not self.st.over and not self.overlay:IsShown() then self:Resume() end end)

    local saved = Save().game
    if saved and saved.players and not saved.over then
        self.st = saved
        self:CenterOn(E().Hall(saved, ME))
        self:Resume()
        ns.Solo.SetRunning(kind, true)
    else
        self:ShowStart()
    end
    self:Refresh()
    return self
end

---------------------------------------------------------------------------
-- Games
---------------------------------------------------------------------------
function P:ShowStart()
    self:Pause()
    self.overlay:Show()
    self.overTitle:SetText("Choose your side")
    self.overTitle:SetTextColor(1, 0.82, 0)
    self.overSub:SetText("Build up your base, train an army and destroy every enemy building. The computer plays the other side.")
    for _, p in ipairs(self.picks) do p:Show() end
    self.againButton:Hide()
    self.resumeButton:SetShown(self.st ~= nil and not self.st.over)
end

function P:NewGame(faction, seed)
    local other = faction == "human" and "orc" or "human"
    self.st = E().New({ factions = { faction, other }, seed = seed or math.random(1, 2000000000) })
    Save().game = self.st
    self.sel, self.place, self.targeting = {}, nil, nil
    self.counted = false
    self.treeDirty = true
    self:BuildMinimapTrees()
    self:CenterOn(E().Hall(self.st, ME))
    ns.Solo.SetRunning(self.kind, true)
    self:Resume()
    W.PlaySound("IG_MAINMENU_OPTION")
    ns.Changed()
end

function P:Resume()
    if not self.st then return end
    self.overlay:Hide()
    self.paused = false
    if self.view.KeysOn then self.view:KeysOn() end
    if not self.mmBuilt then self:BuildMinimapTrees() end
    self.treeDirty = true
end

function P:Pause()
    self.paused = true
    self.drag = nil
    self.box:Hide()
    if self.view.KeysOff then self.view:KeysOff() end
end

function P:Quit()
    self.st = nil
    Save().game = nil
    ns.Solo.SetRunning(self.kind, false)
    self:ShowStart()
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
            ns.Scores.Submit(self.kind, rec.wins)
        else
            rec.losses = rec.losses + 1
        end
    end
    rec.game = nil
    ns.Solo.SetRunning(self.kind, false)
    self:Pause()
    self.overlay:Show()
    for _, p in ipairs(self.picks) do p:Hide() end
    self.resumeButton:Hide()
    self.againButton:Show()
    self.overTitle:SetText(won and "Victory!" or "Defeat")
    self.overTitle:SetTextColor(won and 1 or 0.9, won and 0.82 or 0.3, won and 0 or 0.3)
    self.overSub:SetText(string.format("%d:%02d played. Wins %d, losses %d.", math.floor(st.time / 60),
        math.floor(st.time % 60), rec.wins, rec.losses))
    W.PlaySound(won and "LEVELUP" or "RAID_WARNING")
    ns.Changed()
end

---------------------------------------------------------------------------
-- Time
---------------------------------------------------------------------------
function P:Tick(elapsed)
    elapsed = math.min(elapsed or 0, 0.25)
    local st = self.st
    if self.sayUntil and Now() > self.sayUntil then
        self.status:SetText("")
        self.sayUntil = nil
    end
    if not st then return end
    if not self.paused and not st.over then
        self:Scroll(elapsed)
        self.acc = self.acc + elapsed
        while self.acc >= STEP do
            self.acc = self.acc - STEP
            local events = E().Step(st, STEP)
            self:Events(events)
            self.think = self.think + STEP
            if self.think >= 1 then
                self.think = 0
                WC().AI.Think(st, CPU)
            end
            if st.over then break end
        end
        if st.over then
            self:Draw()
            return self:GameOver()
        end
    end
    self:Draw()
end

function P:Say(text)
    self.status:SetText(text)
    self.sayUntil = Now() + 2
end

-- Sounds and little effects for what just happened.
function P:Events(events)
    for _, ev in ipairs(events) do
        if ev.kind == "hit" then
            local a, t = self.st.ents[ev.id], self.st.ents[ev.target]
            if a and ev.ranged then
                local tx, ty
                if t then tx, ty = E().Center(t) end
                local ax, ay = E().Center(a)
                if tx then self:Shot(ax, ay, tx, ty) end
            end
        elseif ev.kind == "death" then
            if ev.owner == ME and ev.what == "building" then self:Say("One of your buildings was destroyed!") end
            local f = self.unitFrames[ev.id]
            if f and ev.what == "unit" then
                self.unitFrames[ev.id] = nil
                f.corpseUntil = Now() + 2.5
                table.insert(self.corpses, f)
                if f.model and f.model:IsShown() then
                    f.model:SetAnimation(ANIM.death)
                    f.model.anim = ANIM.death
                end
                f.hp:Hide() f.hpBg:Hide() f.sel:Hide() f.carry:Hide()
            end
        elseif ev.kind == "alarm" then
            if ev.owner == ME then
                self:Say(ev.kind2 == "callToArms" and "To arms!" or "Battle stations!")
            else
                self:Say("The enemy sounds the alarm!")
            end
            W.PlaySound("RAID_WARNING")
        elseif ev.kind == "trained" and ev.owner == ME then
            W.PlaySound("U_CHAT_SCROLL_BUTTON")
        elseif ev.kind == "built" and ev.owner == ME then
            self:Say(WC().Buildings[ev.type].name .. " finished")
            W.PlaySound("IG_MAINMENU_OPTION")
        elseif ev.kind == "cantBuild" and ev.owner == ME then
            self:Say("Can't build there")
        elseif ev.kind == "treeDown" then
            self.treeDirty = true
            local px = self.mmTrees[ev.tree]
            if px then px:Hide() end
        elseif ev.kind == "placed" then
            self.treeDirty = true
        end
    end
end

-- A shot flying from a ranged unit.
function P:Shot(x1, y1, x2, y2)
    local t = table.remove(self.fxFree) or self.fxLayer:CreateTexture(nil, "ARTWORK")
    t:SetTexture(ART .. "Blob")
    t:SetVertexColor(1, 0.9, 0.4)
    t:SetSize(6, 6)
    t:Show()
    ns.Cards.Tween(0.15, function(k)
        local x, y = x1 + (x2 - x1) * k, y1 + (y2 - y1) * k
        t:ClearAllPoints()
        t:SetPoint("CENTER", self.view, "TOPLEFT", x * TILE - self.camX, -(y * TILE - self.camY))
    end, function()
        t:Hide()
        table.insert(self.fxFree, t)
    end)
end

---------------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------------
function P:ClampCam()
    local st = self.st
    if not st then return end
    self.camX = math.max(0, math.min(self.camX, st.w * TILE - BW))
    self.camY = math.max(0, math.min(self.camY, st.h * TILE - VIEW_H))
end

function P:CenterOn(e)
    if not e then return end
    local x, y = E().Center(e)
    self.camX, self.camY = x * TILE - BW / 2, y * TILE - VIEW_H / 2
    self:ClampCam()
    self.treeDirty = true
end

function P:Cursor()
    local v = self.view
    local left, top = v:GetLeft(), v:GetTop()
    local mx, my = GetCursorPosition()
    local scale = v:GetEffectiveScale()
    return mx / scale - (left or 0), (top or 0) - my / scale
end

-- The mouse in map tiles.
function P:World()
    local sx, sy = self:Cursor()
    return (sx + self.camX) / TILE, (sy + self.camY) / TILE, sx, sy
end

function P:Scroll(dt)
    local dx, dy = 0, 0
    local held = self.keys or {}
    if held.LEFT then dx = dx - 1 end
    if held.RIGHT then dx = dx + 1 end
    if held.UP then dy = dy - 1 end
    if held.DOWN then dy = dy + 1 end
    if self.view:IsMouseOver() and not self.drag then
        local sx, sy = self:Cursor()
        if sx < EDGE then dx = dx - 1 elseif sx > BW - EDGE then dx = dx + 1 end
        if sy < EDGE then dy = dy - 1 elseif sy > VIEW_H - EDGE then dy = dy + 1 end
    end
    if dx ~= 0 or dy ~= 0 then
        self.camX = self.camX + dx * SCROLL * dt
        self.camY = self.camY + dy * SCROLL * dt
        self:ClampCam()
        self.treeDirty = true
    end
end

function P:MinimapClick(button)
    local st = self.st
    if not st or self.paused then return end
    local left, top = self.mm:GetLeft(), self.mm:GetTop()
    local mx, my = GetCursorPosition()
    local scale = self.mm:GetEffectiveScale()
    local x, y = (mx / scale - (left or 0)) / MM_SCALE, ((top or 0) - my / scale) / MM_SCALE
    if button == "RightButton" then
        local ids = self:MyUnits()
        if #ids > 0 then E().Command(st, ME, { type = "move", units = ids, x = x, y = y }) end
        return
    end
    self.camX, self.camY = x * TILE - BW / 2, y * TILE - VIEW_H / 2
    self:ClampCam()
    self.treeDirty = true
end

---------------------------------------------------------------------------
-- Selecting and commanding
---------------------------------------------------------------------------
function P:Selected()
    local out = {}
    for _, id in ipairs(self.sel) do
        local e = self.st and self.st.ents[id]
        if e then table.insert(out, e) end
    end
    self.sel = {}
    for _, e in ipairs(out) do table.insert(self.sel, e.id) end
    return out
end

function P:MyUnits()
    local ids = {}
    for _, e in ipairs(self:Selected()) do
        if e.owner == ME and e.kind == "unit" then table.insert(ids, e.id) end
    end
    return ids
end

-- Click at a map point: select what's there (Shift adds units).
function P:SelectAt(x, y, add)
    local e = E().At(self.st, x, y) or E().At(self.st, x, y + 0.7) or E().At(self.st, x, y + 1.3)
    if not e then
        if not add then self.sel = {} end
        return
    end
    if add and e.owner == ME and e.kind == "unit" then
        for i, id in ipairs(self.sel) do
            if id == e.id then table.remove(self.sel, i) return end
        end
        table.insert(self.sel, e.id)
    else
        self.sel = { e.id }
    end
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
end

-- Drag a box: your units inside it.
function P:SelectBox(x1, y1, x2, y2, add)
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    local picked = {}
    for _, id in ipairs(self.st.list) do
        local e = self.st.ents[id]
        if e and e.owner == ME and e.kind == "unit" and e.x >= minX and e.x <= maxX and e.y >= minY and e.y <= maxY then
            table.insert(picked, id)
        end
    end
    if add then for _, id in ipairs(picked) do table.insert(self.sel, id) end
    elseif #picked > 0 then self.sel = picked end
end

-- Right-click: move, attack, gather, or set a rally point.
function P:Smart(x, y)
    local st = self.st
    local target = E().At(st, x, y) or E().At(st, x, y + 0.7)
    local tree = st.trees[math.floor(y) * st.w + math.floor(x)] and (math.floor(y) * st.w + math.floor(x)) or nil
    local units = self:MyUnits()
    self:Mark(x, y)
    if #units == 0 then
        -- A building of yours: set its rally point.
        local b = self:Selected()[1]
        if b and b.owner == ME and b.kind == "building" then
            E().Command(st, ME, { type = "rally", building = b.id, x = x, y = y,
                target = target and target.kind == "mine" and target.id or nil, tree = tree })
            self:Say("Rally point set")
        end
        return
    end
    if target and target.owner ~= ME and target.owner > 0 then
        return E().Command(st, ME, { type = "attack", units = units, target = target.id })
    end
    local workers, others = {}, {}
    for _, id in ipairs(units) do
        local u = st.ents[id]
        if WC().Units[u.type].worker then table.insert(workers, id) else table.insert(others, id) end
    end
    if target and target.owner == ME and target.kind == "building" and target.progress < 1 and #workers > 0 then
        E().Command(st, ME, { type = "resumeBuild", units = workers, building = target.id })
        return
    end
    if target and target.kind == "mine" and #workers > 0 then
        E().Command(st, ME, { type = "gather", units = workers, target = target.id })
        if #others > 0 then E().Command(st, ME, { type = "move", units = others, x = x, y = y }) end
        return
    end
    if tree and #workers > 0 then
        E().Command(st, ME, { type = "gather", units = workers, tree = tree })
        if #others > 0 then E().Command(st, ME, { type = "move", units = others, x = x, y = y }) end
        return
    end
    E().Command(st, ME, { type = "move", units = units, x = x, y = y })
end

function P:Mark(x, y)
    local m = self.marker
    m:Show()
    m:SetVertexColor(0.3, 1, 0.3)
    ns.Cards.Tween(0.4, function(k)
        m:ClearAllPoints()
        m:SetPoint("CENTER", self.view, "TOPLEFT", x * TILE - self.camX, -(y * TILE - self.camY))
        m:SetSize(24 * (1 - k * 0.6), 16 * (1 - k * 0.6))
        m:SetAlpha(1 - k)
    end, function() m:Hide() end)
end

function P:MouseDown(button)
    if not self.st or self.paused then return end
    local x, y, sx, sy = self:World()
    if self.place then
        if button == "RightButton" then self.place = nil self.ghost:Hide() return end
        return self:PlaceAt(x, y)
    end
    if self.targeting then
        if button == "RightButton" then self.targeting = nil self:Say("") return end
        return self:TargetAt(x, y)
    end
    if self.menu and button == "RightButton" then self.menu = nil return end
    if button == "LeftButton" then
        self.drag = { x = x, y = y, sx = sx, sy = sy }
    else
        self:Smart(x, y)
    end
end

function P:MouseUp(button)
    if button ~= "LeftButton" or not self.drag or not self.st then return end
    local x, y, sx, sy = self:World()
    local d = self.drag
    self.drag = nil
    self.box:Hide()
    local add = IsShiftKeyDown and IsShiftKeyDown()
    if math.abs(sx - d.sx) < 5 and math.abs(sy - d.sy) < 5 then
        self:SelectAt(x, y, add)
    else
        self:SelectBox(d.x, d.y, x, y, add)
    end
end

-- The second click of a targeted command (attack, move, gather, rally).
function P:TargetAt(x, y)
    local mode = self.targeting
    self.targeting = nil
    self:Say("")
    if mode == "attack" then return self:AttackAt(x, y) end
    local st = self.st
    self:Mark(x, y)
    if mode == "move" then
        local units = self:MyUnits()
        if #units > 0 then E().Command(st, ME, { type = "move", units = units, x = x, y = y }) end
    elseif mode == "gather" then
        self:Smart(x, y)
    elseif mode == "rally" then
        local b = self:Selected()[1]
        local target = E().At(st, x, y)
        local i = math.floor(y) * st.w + math.floor(x)
        if b then
            E().Command(st, ME, { type = "rally", building = b.id, x = x, y = y,
                target = target and target.kind == "mine" and target.id or nil, tree = st.trees[i] and i or nil })
        end
    end
end

function P:AttackAt(x, y)
    self.targeting = nil
    local units = self:MyUnits()
    if #units == 0 then return end
    local target = E().At(self.st, x, y)
    self:Mark(x, y)
    if target and target.owner ~= ME and target.owner > 0 then
        E().Command(self.st, ME, { type = "attack", units = units, target = target.id })
    else
        E().Command(self.st, ME, { type = "attackMove", units = units, x = x, y = y })
    end
end

-- Building placement follows the mouse; the top-left tile is under the cursor's corner.
function P:PlaceSpot(x, y)
    local size = WC().Buildings[self.place.btype].size
    return math.floor(x - size / 2 + 0.5), math.floor(y - size / 2 + 0.5), size
end

function P:PlaceAt(x, y)
    local bx, by = self:PlaceSpot(x, y)
    local ok, why = E().Command(self.st, ME, { type = "build", unit = self.place.unit, btype = self.place.btype, x = bx, y = by })
    if ok then
        self.place = nil
        self.ghost:Hide()
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
    else
        self:Say(why or "Can't build there")
    end
end

function P:StartPlace(btype)
    local worker
    for _, e in ipairs(self:Selected()) do
        if e.owner == ME and e.kind == "unit" and WC().Units[e.type].worker then worker = e break end
    end
    if not worker then return end
    if not E().CanAfford(self.st, ME, WC().Buildings[btype].cost) then return self:Say("Not enough gold or lumber") end
    self.place = { btype = btype, unit = worker.id }
    self.targeting = nil
    self.ghost:SetTexture(ART .. BUILDING_ART[btype])
    self:Say("Click where to build (right-click cancels)")
end

function P:Train(utype)
    local b = self:Selected()[1]
    if not b then return end
    local ok, why = E().Command(self.st, ME, { type = "train", building = b.id, utype = utype })
    if not ok then self:Say(why and (why:sub(1, 1):upper() .. why:sub(2)) or "Can't train that") end
end

function P:CancelTrain()
    local b = self:Selected()[1]
    if b then E().Command(self.st, ME, { type = "cancel", building = b.id }) end
end

function P:Target(mode, text)
    self.targeting = mode
    self.place = nil
    self:Say(text .. " (right-click cancels)")
end

function P:Hold()
    local units = self:MyUnits()
    if #units > 0 then E().Command(self.st, ME, { type = "hold", units = units }) end
end

function P:ReturnRes()
    local units = self:MyUnits()
    if #units > 0 then
        local ok, why = E().Command(self.st, ME, { type = "returnRes", units = units })
        if not ok then self:Say("Nothing to bring back") end
    end
end

function P:IdleWorkers()
    local out = {}
    if not self.st then return out end
    for _, id in ipairs(self.st.list) do
        local e = self.st.ents[id]
        if e and e.owner == ME and e.kind == "unit" and WC().Units[e.type].worker and not e.order then table.insert(out, e) end
    end
    return out
end

function P:NextIdleWorker()
    local list = self:IdleWorkers()
    if #list == 0 then return end
    self.idleIndex = ((self.idleIndex or 0) % #list) + 1
    local u = list[self.idleIndex]
    self.sel = { u.id }
    self.menu = nil
    self:CenterOn(u)
end

function P:Alarm()
    local b = self:Selected()[1]
    if not b then return end
    local f = WC().Factions[self.st.players[ME].faction]
    local ok, why = E().Command(self.st, ME, { type = f.alarm, building = b.id })
    if not ok then self:Say(why and (why:sub(1, 1):upper() .. why:sub(2)) or "Nobody answers") end
end

function P:Stop()
    local units = self:MyUnits()
    if #units > 0 then E().Command(self.st, ME, { type = "stop", units = units }) end
end

function P:Key(key)
    if not self.st or self.paused then return end
    local cmd
    for _, c in ipairs(self.cmds) do
        if c:IsShown() and c.key == key and c:IsEnabled() then cmd = c end
    end
    if cmd and cmd.action then cmd.action() end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function Place(region, parent, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
end

function P:BuildMinimapTrees()
    local st = self.st
    if not st then return end
    for _, t in pairs(self.mmTrees) do t:Hide() end
    self.mmTreePool = self.mmTreePool or {}
    local used = 0
    self.mmTrees = {}
    for i in pairs(st.trees) do
        used = used + 1
        local t = self.mmTreePool[used]
        if not t then
            t = self.mm:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(0.08, 0.3, 0.1, 1)
            t:SetSize(MM_SCALE, MM_SCALE)
            self.mmTreePool[used] = t
        end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", (i % st.w) * MM_SCALE, -math.floor(i / st.w) * MM_SCALE)
        t:Show()
        self.mmTrees[i] = t
    end
    for j = used + 1, #self.mmTreePool do self.mmTreePool[j]:Hide() end
    self.mmBuilt = true
end

function P:DrawTrees()
    local st = self.st
    local x0, y0 = math.floor(self.camX / TILE) - 1, math.floor(self.camY / TILE) - 1
    local x1, y1 = x0 + math.ceil(BW / TILE) + 2, y0 + math.ceil(VIEW_H / TILE) + 2
    local used = 0
    for y = math.max(0, y0), math.min(st.h - 1, y1) do
        for x = math.max(0, x0), math.min(st.w - 1, x1) do
            if st.trees[y * st.w + x] then
                used = used + 1
                local t = self.treeTex[used]
                if not t then
                    t = self.treeLayer:CreateTexture(nil, "ARTWORK")
                    t:SetTexture(ART .. "WcTree")
                    t:SetSize(TILE + 8, TILE + 8)
                    self.treeTex[used] = t
                end
                t:Show()
                Place(t, self.view, x * TILE + TILE / 2 - self.camX, y * TILE + TILE / 2 - 4 - self.camY)
            end
        end
    end
    for j = used + 1, #self.treeTex do self.treeTex[j]:Hide() end
end

function P:UnitFrame(id, utype)
    local f = self.unitFrames[id]
    if f and f.type == utype then return f end
    if f then self:FreeFrame(f) end -- it changed (a peasant became militia)
    local pool = self.framePool[utype] or {}
    self.framePool[utype] = pool
    f = table.remove(pool)
    if not f then
        f = CreateFrame("Frame", nil, self.unitLayer)
        f:SetSize(22, 22)
        f:EnableMouse(false)
        f.type = utype
        f.team = f:CreateTexture(nil, "BACKGROUND")
        f.team:SetTexture(ART .. "WcSelect")
        f.team:SetPoint("CENTER", 0, -6)
        f.team:SetSize(22, 11)
        f.sel = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.sel:SetTexture(ART .. "WcSelect")
        f.sel:SetPoint("CENTER", 0, -6)
        f.sel:SetSize(30, 15)
        -- The icon, shown until the model loads (and at the view's edges).
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("TOPLEFT", 3, -3)
        f.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if f.CreateMaskTexture then
            local mask = f:CreateMaskTexture()
            if mask then
                mask:SetTexture(ART .. "HsOvalMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(f.icon)
                f.icon:AddMaskTexture(mask)
            end
        end
        f.icon:SetTexture(WC().Units[utype].icon)
        f.ring = f:CreateTexture(nil, "OVERLAY")
        f.ring:SetAllPoints(f.icon)
        f.ring:SetTexture(ART .. "WcRing")
        f.model = MakeModel(f)
        if f.model then
            f.model:SetPoint("BOTTOM", f, "CENTER", 0, -8)
            f.model.npc = WC().Units[utype].npc
            f.model:SetFrameLevel(f:GetFrameLevel() + 1)
        end
        local top = CreateFrame("Frame", nil, f)
        top:SetAllPoints()
        top:SetFrameLevel(f:GetFrameLevel() + 3)
        f.hpBg = top:CreateTexture(nil, "OVERLAY", nil, 1)
        f.hpBg:SetColorTexture(0, 0, 0, 0.8)
        f.hpBg:SetSize(20, 3)
        f.hpBg:SetPoint("BOTTOM", f, "CENTER", 0, MODEL_H - 12)
        f.hp = top:CreateTexture(nil, "OVERLAY", nil, 2)
        f.hp:SetColorTexture(0.2, 1, 0.2, 1)
        f.hp:SetHeight(3)
        f.hp:SetPoint("LEFT", f.hpBg, "LEFT")
        f.carry = top:CreateTexture(nil, "OVERLAY", nil, 3)
        f.carry:SetSize(10, 10)
        f.carry:SetPoint("CENTER", f, "CENTER", 9, 4)
    end
    f.corpseUntil = nil
    f:SetAlpha(1)
    self.unitFrames[id] = f
    return f
end

function P:FreeFrame(f)
    f:Hide()
    local pool = self.framePool[f.type] or {}
    self.framePool[f.type] = pool
    table.insert(pool, f)
end

function P:Draw()
    local st = self.st
    if not st then return end
    self:ClampCam()
    local cx, cy = self.camX, self.camY
    -- Ground scrolls with the camera.
    self.ground:SetTexCoord(cx / 256, (cx + BW) / 256, cy / 256, (cy + VIEW_H) / 256)
    if self.treeDirty or self.lastCamX ~= cx or self.lastCamY ~= cy then
        self:DrawTrees()
        self.treeDirty = false
        self.lastCamX, self.lastCamY = cx, cy
    end
    local selected = {}
    for _, id in ipairs(self.sel) do selected[id] = true end
    -- Buildings and the mine.
    local bi, ui = 0, 0
    self.mmDots:Begin()
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind ~= "unit" then
            bi = bi + 1
            local t = self.buildTex[bi]
            if not t then
                t = { art = self.buildLayer:CreateTexture(nil, "ARTWORK"), sel = self.buildLayer:CreateTexture(nil, "BORDER"),
                    bar = self.buildLayer:CreateTexture(nil, "OVERLAY"), barBg = self.buildLayer:CreateTexture(nil, "OVERLAY", nil, -1),
                    team = self.buildLayer:CreateTexture(nil, "OVERLAY", nil, 1) }
                t.sel:SetColorTexture(0.3, 1, 0.3, 0.35)
                t.barBg:SetColorTexture(0, 0, 0, 0.8)
                self.buildTex[bi] = t
            end
            local px, py = e.x * TILE - cx, e.y * TILE - cy
            local size = e.size * TILE
            t.art:SetTexture(ART .. BUILDING_ART[e.type])
            t.art:SetSize(size + 4, size + 4)
            Place(t.art, self.view, px + size / 2, py + size / 2)
            t.art:SetAlpha((e.progress or 1) < 1 and 0.5 + 0.5 * e.progress or 1)
            t.art:Show()
            t.sel:SetShown(selected[id] == true)
            t.sel:SetSize(size + 6, size + 6)
            Place(t.sel, self.view, px + size / 2, py + size / 2)
            -- A team flag, a health bar when hurt or selected, progress while building.
            if e.owner > 0 then
                local col = TEAM[e.owner]
                t.team:SetColorTexture(col[1], col[2], col[3], 1)
                t.team:SetSize(8, 8)
                Place(t.team, self.view, px + 5, py + 5)
                t.team:Show()
            else
                t.team:Hide()
            end
            local showBar = e.owner > 0 and (selected[id] or e.hp < e.maxHp or (e.progress or 1) < 1)
            t.barBg:SetShown(showBar)
            t.bar:SetShown(showBar)
            if showBar then
                local frac = (e.progress or 1) < 1 and e.progress or (e.hp / e.maxHp)
                t.barBg:SetSize(size, 4)
                Place(t.barBg, self.view, px + size / 2, py - 3)
                t.bar:SetSize(math.max(1, size * frac), 4)
                t.bar:ClearAllPoints()
                t.bar:SetPoint("LEFT", t.barBg, "LEFT")
                if (e.progress or 1) < 1 then t.bar:SetColorTexture(0.9, 0.8, 0.2, 1) else t.bar:SetColorTexture(0.2, 1, 0.2, 1) end
            end
            -- Minimap.
            local dot = self.mmDots:Get()
            if e.owner > 0 then
                local col = TEAM[e.owner]
                dot:SetColorTexture(col[1], col[2], col[3], 1)
            else
                dot:SetColorTexture(1, 0.85, 0.2, 1)
            end
            dot:SetSize(e.size * MM_SCALE, e.size * MM_SCALE)
            dot:ClearAllPoints()
            dot:SetPoint("TOPLEFT", self.mm, "TOPLEFT", e.x * MM_SCALE, -e.y * MM_SCALE)
        end
    end
    for j = bi + 1, #self.buildTex do
        local t = self.buildTex[j]
        t.art:Hide() t.sel:Hide() t.bar:Hide() t.barBg:Hide() t.team:Hide()
    end
    -- Units.
    local seen = {}
    local now = Now()
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" then
            local dot = self.mmDots:Get()
            local col = TEAM[e.owner]
            dot:SetColorTexture(col[1], col[2], col[3], 1)
            dot:SetSize(MM_SCALE + 1, MM_SCALE + 1)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", self.mm, "TOPLEFT", e.x * MM_SCALE, -e.y * MM_SCALE)
            local px, py = e.x * TILE - cx, e.y * TILE - cy
            if not e.inside and not e.insideBuild and px > -30 and px < BW + 30 and py > -10 and py < VIEW_H + 50 then
                seen[id] = true
                local f = self:UnitFrame(id, e.type)
                f:Show()
                f.team:SetVertexColor(col[1], col[2], col[3])
                f.ring:SetVertexColor(col[1], col[2], col[3])
                f.sel:SetShown(selected[id] == true)
                f.sel:SetVertexColor(0.3, 1, 0.3)
                local hurt = e.hp < e.maxHp
                f.hpBg:SetShown(hurt or selected[id] == true)
                f.hp:SetShown(hurt or selected[id] == true)
                f.hp:SetWidth(math.max(1, 20 * e.hp / e.maxHp))
                local frac = e.hp / e.maxHp
                f.hp:SetColorTexture(frac > 0.5 and 0.2 or 1, frac > 0.25 and 1 or 0.2, 0.2, 1)
                if e.carry then
                    f.carry:SetTexture(ART .. (e.carry.res == "gold" and "WcGold" or "WcLumber"))
                    f.carry:Show()
                else
                    f.carry:Hide()
                end
                f:ClearAllPoints()
                f:SetPoint("CENTER", self.view, "TOPLEFT", px, -py)
                -- Always the model (the panels above the map hide anything poking out).
                local m = f.model
                if m then
                    if not m:IsShown() then m:Show() end
                    if m.waits and not m.loaded and now - (m.tried or 0) > 2 then LoadModel(m) end
                    f.icon:Hide()
                    f.ring:Hide()
                    if m.SetFacing then m:SetFacing(math.pi / 2 - (e.facing or 0)) end
                    local moved = f.lastX and (math.abs(f.lastX - e.x) + math.abs(f.lastY - e.y)) > 0.005
                    local anim = AnimFor(e, moved)
                    if m.anim ~= anim and m.SetAnimation then
                        m:SetAnimation(anim)
                        m.anim = anim
                    end
                else
                    f.icon:Show()
                    f.ring:Show()
                end
                f.lastX, f.lastY = e.x, e.y
            end
        end
    end
    for id, f in pairs(self.unitFrames) do
        if not seen[id] then
            self.unitFrames[id] = nil
            self:FreeFrame(f)
        end
    end
    -- Bodies fade, then go back to the pool.
    for i = #self.corpses, 1, -1 do
        local f = self.corpses[i]
        local left = (f.corpseUntil or 0) - now
        if left <= 0 then
            table.remove(self.corpses, i)
            self:FreeFrame(f)
        else
            f:SetAlpha(math.min(1, left / 1.2))
            if f.model and f.model.anim == ANIM.death and left < 1.6 and f.model.SetAnimation then
                f.model:SetAnimation(ANIM.dead)
                f.model.anim = ANIM.dead
            end
        end
    end
    self.mmDots:End()
    -- The camera on the minimap.
    local mx, my = cx / TILE * MM_SCALE, cy / TILE * MM_SCALE
    local mw, mh = BW / TILE * MM_SCALE, VIEW_H / TILE * MM_SCALE
    local c = self.mmCam
    c[1]:SetSize(mw, 1) c[1]:ClearAllPoints() c[1]:SetPoint("TOPLEFT", self.mm, "TOPLEFT", mx, -my)
    c[2]:SetSize(mw, 1) c[2]:ClearAllPoints() c[2]:SetPoint("TOPLEFT", self.mm, "TOPLEFT", mx, -(my + mh))
    c[3]:SetSize(1, mh) c[3]:ClearAllPoints() c[3]:SetPoint("TOPLEFT", self.mm, "TOPLEFT", mx, -my)
    c[4]:SetSize(1, mh) c[4]:ClearAllPoints() c[4]:SetPoint("TOPLEFT", self.mm, "TOPLEFT", mx + mw, -my)
    -- The drag box, the placement ghost.
    if self.drag then
        local _, _, sx, sy = self:World()
        local d = self.drag
        local w, h = math.abs(sx - d.sx), math.abs(sy - d.sy)
        if w > 4 or h > 4 then
            self.box:Show()
            self.box:ClearAllPoints()
            self.box:SetPoint("TOPLEFT", self.view, "TOPLEFT", math.min(sx, d.sx), -math.min(sy, d.sy))
            self.box:SetSize(w, h)
        end
    end
    if self.place then
        local x, y = self:World()
        local bx, by, size = self:PlaceSpot(x, y)
        self.ghost:Show()
        self.ghost:SetSize(size * TILE, size * TILE)
        self.ghost:ClearAllPoints()
        self.ghost:SetPoint("TOPLEFT", self.view, "TOPLEFT", bx * TILE - cx, -(by * TILE - cy))
        local ok = E().CanPlace(st, bx, by, size)
        self.ghost:SetVertexColor(ok and 0.5 or 1, ok and 1 or 0.3, ok and 0.5 or 0.3)
    else
        self.ghost:Hide()
    end
    -- The rally point of the selected building.
    local sb = #self.sel == 1 and st.ents[self.sel[1]]
    if sb and sb.owner == ME and sb.rally then
        self.rallyFlag:Show()
        self.rallyFlag:ClearAllPoints()
        self.rallyFlag:SetPoint("BOTTOMLEFT", self.view, "TOPLEFT", sb.rally.x * TILE - cx - 3, -(sb.rally.y * TILE - cy))
    else
        self.rallyFlag:Hide()
    end
    local idle = self:IdleWorkers()
    self.idleButton:SetShown(#idle > 0)
    if #idle > 0 then
        self.idleButton.icon:SetTexture(WC().Units[WC().Factions[st.players[ME].faction].worker].icon)
        self.idleButton.text:SetText("Idle: " .. #idle)
    end
    self:DrawPanel()
end

-- Resources, what's selected and the command card.
function P:DrawPanel()
    local st = self.st
    local pl = st.players[ME]
    self.goldText:SetText(tostring(pl.gold))
    self.lumberText:SetText(tostring(pl.lumber))
    self.foodText:SetText(pl.food .. "/" .. pl.foodCap)
    if pl.food >= pl.foodCap then self.foodText:SetTextColor(1, 0.3, 0.3) else self.foodText:SetTextColor(1, 1, 1) end
    self.clock:SetText(string.format("%d:%02d", math.floor(st.time / 60), math.floor(st.time % 60)))
    local rec = Save()
    self.statsText:SetText(string.format("Wins %d, losses %d", rec.wins, rec.losses))

    local sel = self:Selected()
    local first = sel[1]
    for _, t in ipairs(self.groupIcons) do t:Hide() end
    for _, q in ipairs(self.queueButtons) do q:Hide() end
    self.progress:Hide()
    self.portrait:SetShown(first ~= nil and #sel == 1)
    self.selName:SetText("")
    self.selHp:SetText("")
    self.selStatus:SetText("")
    if #sel > 1 then
        for i = 1, math.min(12, #sel) do
            local d = E().Def(sel[i])
            self.groupIcons[i]:SetTexture(d.icon)
            self.groupIcons[i]:Show()
        end
        self.selStatus:ClearAllPoints()
        self.selStatus:SetPoint("TOPLEFT", 150, -66)
        self.selStatus:SetText(#sel .. " units selected")
    elseif first then
        self.selStatus:ClearAllPoints()
        self.selStatus:SetPoint("TOPLEFT", self.selHp, "BOTTOMLEFT", 0, -3)
        local d = E().Def(first)
        self.portrait:SetTexture(d.icon)
        self.selName:SetText(d.name)
        if first.kind == "mine" then
            self.selHp:SetText("Gold left: " .. (first.gold or 0))
        else
            self.selHp:SetText(string.format("%d / %d", math.max(0, math.floor(first.hp)), first.maxHp))
        end
        local o = first.order
        local status = ""
        if first.kind == "unit" then
            if not o then status = "Idle"
            elseif o.type == "gather" then status = first.carry and ("Bringing back " .. first.carry.res) or ("Gathering " .. o.res)
            elseif o.type == "build" then status = "Building a " .. WC().Buildings[o.btype].name
            elseif o.type == "attack" then status = "Attacking"
            elseif o.type == "attackMove" then status = "Attack-moving"
            elseif o.type == "move" then status = "Moving"
            elseif o.type == "hold" then status = "Holding position"
            elseif o.type == "toArms" then status = "Answering the call to arms"
            elseif o.type == "garrison" then status = "Running to a burrow" end
            if first.militia then status = string.format("Militia: %d s left. %s", math.ceil(first.militia.t), status) end
        elseif first.kind == "building" then
            if first.garrison and first.progress >= 1 then
                status = "Peons inside: " .. #first.garrison .. "/" .. E().Def(first).garrison
            end
            if first.progress < 1 then
                status = string.format("Under construction: %d%%", math.floor(first.progress * 100))
                if first.paused then status = status .. " (paused: right-click it with a worker to carry on)" end
            elseif first.queue[1] then
                local ud = WC().Units[first.queue[1]]
                status = string.format("Training %s: %d%%", ud.name, math.floor(first.trainT / ud.time * 100))
                for i, q in ipairs(first.queue) do
                    self.queueButtons[i].icon:SetTexture(WC().Units[q].icon)
                    self.queueButtons[i]:SetShown(first.owner == ME)
                end
            elseif first.owner == ME and E().Def(first).trains then
                status = "Right-click the map to set a rally point."
            end
        end
        if first.owner ~= ME and first.owner > 0 then status = "Enemy" end
        self.selStatus:SetText(status)
    end
    self:DrawCommands(sel)
end

local IC = "Interface\\Icons\\"

function P:DrawCommands(sel)
    local st = self.st
    local list = {}
    local mine = {}
    for _, e in ipairs(sel) do if e.owner == ME then table.insert(mine, e) end end
    local f = WC().Factions[st.players[ME].faction]
    local hasWorker, hasUnit, carrying = false, false, false
    for _, e in ipairs(mine) do
        if e.kind == "unit" then
            hasUnit = true
            if WC().Units[e.type].worker then
                hasWorker = true
                if e.carry then carrying = true end
            end
        end
    end
    if not hasWorker then self.menu = nil end
    local function Cost(c) return c[1] .. " gold" .. (c[2] > 0 and (", " .. c[2] .. " lumber") or "") end
    local function Add(item) table.insert(list, item) end
    if hasWorker and self.menu == "build" then
        -- The worker's build menu.
        for _, bt in ipairs(f.builds) do
            local bd = WC().Buildings[bt]
            local tip = Cost(bd.cost)
            if bd.food and bd.food > 0 then tip = tip .. ". Gives " .. bd.food .. " food." end
            if bd.trains then
                local names = {}
                for _, ut in ipairs(bd.trains) do table.insert(names, WC().Units[ut].name) end
                tip = tip .. " Trains " .. table.concat(names, " and ") .. "."
            end
            Add({ icon = bd.icon, key = bd.hotkey, title = "Build " .. bd.name .. " (" .. bd.hotkey .. ")", tip = tip,
                cost = bd.cost, action = function() self.menu = nil self:StartPlace(bt) end })
        end
        list[8] = { icon = IC .. "Spell_ChargeNegative", key = nil, title = "Back", tip = "Back to the commands (or right-click).",
            action = function() self.menu = nil end }
    elseif hasUnit then
        Add({ icon = IC .. "Ability_Rogue_Sprint", key = "M", title = "Move (M)", tip = "Then click where to go.",
            action = function() self:Target("move", "Click where to move") end })
        Add({ icon = IC .. "Spell_Nature_TimeStop", key = "S", title = "Stop (S)", tip = "Stop what they're doing.",
            action = function() self:Stop() end })
        Add({ icon = IC .. "Ability_Defend", key = "H", title = "Hold Position (H)",
            tip = "Stand still and only fight what comes in range.", action = function() self:Hold() end })
        Add({ icon = IC .. "Ability_SteelMelee", key = "A", title = "Attack (A)",
            tip = "Then click: an enemy to attack it, or the ground to attack-move there.",
            action = function() self:Target("attack", "Click a target or a spot") end })
        if hasWorker then
            Add({ icon = IC .. "INV_Pick_02", key = "G", title = "Gather (G)", tip = "Then click the gold mine or a tree.",
                action = function() self:Target("gather", "Click the gold mine or a tree") end })
            Add({ icon = IC .. "INV_Misc_Bag_10", key = "R", title = "Return Resources (R)",
                tip = "Bring what they carry back to the hall, then carry on.", enabled = carrying,
                action = function() self:ReturnRes() end })
            Add({ icon = IC .. "INV_Hammer_20", key = "B", title = "Build (B)", tip = "Open the build menu.",
                action = function() self.menu = "build" end })
        end
    end
    local b = #mine == 1 and mine[1].kind == "building" and mine[1].progress >= 1 and mine[1]
    if b then
        for _, ut in ipairs(E().Def(b).trains or {}) do
            local ud = WC().Units[ut]
            Add({ icon = ud.icon, key = ud.hotkey, title = "Train " .. ud.name .. " (" .. ud.hotkey .. ")", cost = ud.cost,
                tip = string.format("%s, %d food. %d health, %d damage%s.", Cost(ud.cost), ud.food, ud.hp, ud.damage,
                    ud.range > 1.5 and ", ranged" or ""),
                action = function() self:Train(ut) end })
        end
        local fac = WC().Factions[st.players[ME].faction]
        if E().Def(b).hall or (E().Def(b).garrison and fac.alarm == "battleStations") then
            if fac.alarm == "callToArms" then
                list[6] = { icon = IC .. "Ability_Warrior_BattleShout", key = "C", title = "Call to Arms (C)",
                    tip = "Ring the alarm: peasants nearby run to the hall and fight as Militia for 45 seconds.",
                    action = function() self:Alarm() end }
            else
                list[6] = { icon = IC .. "Ability_Warrior_BattleShout", key = "B", title = "Battle Stations (B)",
                    tip = "Peons nearby run into the burrows (4 each); burrows with peons attack enemies.",
                    action = function() self:Alarm() end }
            end
            list[7] = { icon = IC .. "INV_Pick_02", key = "W", title = "Back to Work (W)",
                tip = "Everyone called to arms goes back to work.", action = function()
                    E().Command(st, ME, { type = "backToWork" })
                end }
        end
        if E().Def(b).trains then
            list[8] = { icon = IC .. "INV_Misc_Flag_01", key = "Y", title = "Set Rally Point (Y)",
                tip = "Then click: where new units go. On the gold mine or a tree, new workers start gathering.",
                action = function() self:Target("rally", "Click where new units should go") end }
        end
    end
    for i, c in ipairs(self.cmds) do
        local item = list[i]
        c:SetShown(item ~= nil)
        if item then
            c.icon:SetTexture(item.icon)
            c.title, c.tip, c.action, c.key = item.title, item.tip, item.action, item.key
            c.hotkey:SetText(item.key or "")
            local can = (not item.cost or E().CanAfford(st, ME, item.cost)) and item.enabled ~= false
            c:SetEnabled(can)
            c.icon:SetDesaturated(not can)
        end
    end
end

function P:Refresh()
    if self.st and self.st.over and not self.overlay:IsShown() then self:GameOver() end
    -- Back on the tab after switching away: carry on.
    if self.autoPaused and self.st and not self.st.over and not self.overlay:IsShown() and self.game:IsVisible() then
        self.autoPaused = false
        self:Resume()
    end
    self:Draw()
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.warcraft = P.New

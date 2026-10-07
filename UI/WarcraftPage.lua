-- WarcraftPage: the RTS. A scrolling map on top, a Warcraft-style panel at
-- the bottom (minimap, what's selected, the command card). Everything is
-- drawn from the engine's state (ns.WC.Engine); the player's clicks become
-- E.Command calls, the AI runs every second for the other side. In PvP both
-- players' pages run the same game in lockstep (Core\Lockstep.lua): your
-- clicks become commands for a later turn, the other player's arrive by
-- whisper, and "you" (ME) are whichever chair you sit in.
local ADDON, ns = ...

local W = ns.Widgets
local A = ns.Arcade
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
local ME, CPU = 1, 2           -- your chair and the computer's (nil in PvP)
local MM_SCALE = 2              -- minimap pixels per tile
local EDGE, SCROLL = 28, 650    -- edge scrolling: pixels from the map's edge, speed
local TEAM = { { 0.25, 0.55, 1 }, { 1, 0.25, 0.2 } }
local BUILDING_ART = {
    town_hall = "WcTownHall", farm = "WcFarm", barracks = "WcBarracks", lumber_mill = "WcBarracks", guard_tower = "WcFarm", altar_kings = "WcFarm",
    watch_tower = "WcBurrow", altar_storms = "WcBurrow",
    great_hall = "WcGreatHall", orc_burrow = "WcBurrow", orc_barracks = "WcOrcBarracks", gold_mine = "WcMine",
    keep = "WcTownHall", castle = "WcTownHall", stronghold = "WcGreatHall", fortress = "WcGreatHall",
    blacksmith = "WcBarracks", war_mill = "WcOrcBarracks", scout_tower = "WcFarm",
    arcane_sanctum = "WcTownHall", workshop = "WcBarracks", gryphon_aviary = "WcFarm", arcane_vault = "WcFarm",
    spirit_lodge = "WcBurrow", beastiary = "WcOrcBarracks", tauren_totem = "WcGreatHall", voodoo_lounge = "WcBurrow",
}
-- A building's flat art (ghost, plans, the fallback): one for every building.
local function ArtOf(btype)
    return ART .. (BUILDING_ART[btype] or "WcBarracks")
end

local function WC() return ns.WC end
local function E() return ns.WC.Engine end
local function Snd() return ns.WC.Sounds end
local function Now() return GetTime and GetTime() or 0 end
local ATAN2 = math.atan2 or math.atan

-- Shift held: orders go after the current one (Warcraft III's order queue).
local function Shift() return IsShiftKeyDown and IsShiftKeyDown() and true or nil end

local function Save()
    local rec = ns.db.warcraft or {}
    ns.db.warcraft = rec
    rec.wins, rec.losses = rec.wins or 0, rec.losses or 0
    return rec
end

---------------------------------------------------------------------------
-- Unit models: each unit is its WoW creature, by its display id (found once
-- per creature with a hidden model frame, then saved: see P:Probe).
---------------------------------------------------------------------------
local MODEL_W, MODEL_H = 40, 48
-- A unit's model frame is this much bigger than the unit itself (and the
-- camera that much further away), so heads, weapons and wings aren't cut off.
local MODEL_PAD = 1.8
-- How tall a unit stands next to the buildings (1 = the old, too-big size).
local UNIT_SIZE = 0.7
-- A unit's height on screen in pixels, and where its feet are (below the frame's centre).
local UNIT_PX, UNIT_FEET = MODEL_H / 1.1 * UNIT_SIZE, -6
local ANIM = { stand = 0, death = 1, walk = 4, attack = 17, dead = 6, fly = 135 }

-- How units look next to each other: bigger heroes, beasts and machines
-- (their models are all fitted to one height first).
local UNIT_LOOK = {
    peasant = 0.85, peon = 0.85, knight = 1.25, tauren = 1.4, kodo = 1.6, raider = 1.25, siege_engine = 1.35,
    catapult = 1.3, mortar_team = 0.95, gryphon_rider = 1.45, wind_rider = 1.45, dragonhawk_rider = 1.3,
    batrider = 1.15, flying_machine = 1.1, sheep = 0.55, healing_ward = 0.8, target_dummy = 0.9,
    water_elemental1 = 1.2, water_elemental2 = 1.3, water_elemental3 = 1.4, phoenix1 = 1.5,
    spirit_wolf1 = 0.9, spirit_wolf2 = 1, spirit_wolf3 = 1.1,
}
local HERO_LOOK = 1.25
-- What a buff does to the look: size, grey (desaturated), animation speed,
-- see-through, spinning (Bladestorm).
local BUFF_LOOK = {
    avatar = { scale = 1.5, desat = 0.85 },
    bloodlust = { scale = 1.2, speed = 1.4 },
    slow = { speed = 0.6 },
    noAttack = { alpha = 0.45, desat = 0.6 },
    bladestorm = { spin = true, speed = 1.6 },
    stun = { speed = 0 },
    windwalk = { alpha = 0.45 },
}
P.UNIT_LOOK, P.BUFF_LOOK = UNIT_LOOK, BUFF_LOOK

local function Looks()
    local rec = Save()
    -- Version 2: older saves could give one creature's look to the next
    -- creature asked about (heroes and priests all looked the same).
    if rec.looksV ~= 2 then rec.looks, rec.looksV = {}, 2 end
    rec.looks = rec.looks or {}
    return rec.looks
end

-- Depth. WoW draws all 3D model frames into one shared depth buffer, so
-- overlapping models cut into each other whatever their frame level. To get
-- 2D layering (lower on the map = in front), every model frame uses the same
-- near and far clip, and its camera stands at a distance set by its map row
-- (see P:PlanDepth): further up the map, further away. A narrower lens makes
-- up for the distance, so the model fills the same pixels as before.
local NEAR, FAR = 20, 200000
local RADIUS = {} -- model file or display id -> its size (radius around where the camera looks)

-- The camera's forward and right directions (right: from the client, or worked out).
local function CameraDirs(sc, yaw, pitch)
    local f = { math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), -math.sin(pitch) }
    local r = { -math.sin(yaw), math.cos(yaw), 0 }
    if sc.GetCameraForward then
        local x, y, z = sc:GetCameraForward()
        if x then f = { x, y, z } end
    end
    if sc.GetCameraRight then
        local x, y, z = sc:GetCameraRight()
        if x then r = { x, y, z } end
    end
    return f, r
end

-- Point the camera at (tx, ty, tz) from `dist0` away with the usual lens, or,
-- with a depth set, from that far away with a lens narrowed to match.
local function Camera(sc, tx, ty, tz, dist0, pitch)
    local view = ns.WC.ART.view
    local d, fov = dist0, view.fov
    if sc.depth then
        d = sc.depth
        fov = 2 * math.atan(math.tan(view.fov / 2) * dist0 / d)
        if sc.SetCameraNearClip then sc:SetCameraNearClip(NEAR) end
        if sc.SetCameraFarClip then sc:SetCameraFarClip(FAR) end
    end
    if sc.SetCameraFieldOfView then sc:SetCameraFieldOfView(fov) end
    sc:SetCameraOrientationByYawPitchRoll(view.yaw, pitch, 0)
    local f = CameraDirs(sc, view.yaw, pitch)
    sc:SetCameraPosition(tx - f[1] * d, ty - f[2] * d, tz - f[3] * d)
end

-- A world object (building, tree, mine) from its file id, in a ModelScene:
-- once the model has loaded, its bounding box tells how big it is, and the
-- camera is placed to fit it, looking down at an angle like Warcraft III.
local function MakeDoodad(parent)
    local ok, sc = pcall(CreateFrame, "ModelScene", nil, parent)
    if not ok or not sc or not sc.CreateActor then return nil end
    local actor = sc:CreateActor()
    if not actor or not actor.SetModelByFileID then return nil end
    sc.actor = actor
    local view = ns.WC.ART.view
    if sc.SetCameraFieldOfView then sc:SetCameraFieldOfView(view.fov) end
    if sc.SetCameraNearClip then sc:SetCameraNearClip(0.1) end
    if sc.SetCameraFarClip then sc:SetCameraFarClip(5000) end
    -- Stand the model on the ground at the frame's centre, its width
    -- filling fp pixels (a building's footprint): see Fit.
    function sc:Ground(fp, look)
        if self.fp ~= fp or self.look ~= look then
            self.fp, self.look, self.sig = fp, look, nil
        end
    end
    -- How far the camera stands (set from the map row; nil: just fit it).
    function sc:SetDepth(d)
        if self.depth ~= d then
            self.depth, self.sig = d, nil
            if self.file then self:Fit() end
        end
    end
    function sc:AimGround(x1, y1, z1, x2, y2, z2)
        local look = self.look
        local w = math.max(x2 - x1, y2 - y1, 0.01)
        local h = math.max(z2 - z1, 0.01)
        -- Pixels per model unit: fill the footprint, but not too tall.
        local scale = math.min((look.fill or 1) * self.fp / w, (look.tall or view.tall) * self.fp / h)
        local fh = self:GetHeight()
        if not fh or fh <= 0 then return false end
        local dist = fh / (2 * math.tan(view.fov / 2) * scale)
        self.rr = math.sqrt(((x2 - x1) / 2) ^ 2 + ((y2 - y1) / 2) ^ 2 + h * h)
        Camera(self, (x1 + x2) / 2, (y1 + y2) / 2, z1, dist, view.bpitch)
        return true
    end
    function sc:Aim(cx, cy, cz, r)
        local fit = ns.WC.ART.fit[self.file] or {}
        cz = cz + r * (fit.up or 0)
        self.rr = r * (1 + (fit.up or 0))
        Camera(self, cx, cy, cz, r / math.tan(view.fov / 2) * view.margin * (fit.margin or 1), view.pitch)
    end
    function sc:Fit()
        local x1, y1, z1, x2, y2, z2
        if actor.GetActiveBoundingBox then x1, y1, z1, x2, y2, z2 = actor:GetActiveBoundingBox() end
        if not x1 or not x2 then
            self:Aim(0, 0, 5, 20) -- size unknown yet: look from far away
            return false
        end
        local cx, cy, cz = (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2
        local r = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2) / 2
        local sig = string.format("%.2f %.2f %.2f %.2f %s %s %s", cx, cy, cz, r, tostring(self.fp),
            tostring(self.GetHeight and self:GetHeight()), tostring(self.depth))
        if r <= 0.01 then
            self:Aim(0, 0, 5, 20)
            return false
        end
        if sig == self.sig then return true end
        self.sig = sig
        if self.fp then
            if not self:AimGround(x1, y1, z1, x2, y2, z2) then self.sig = nil end
        else
            self:Aim(cx, cy, cz, r)
        end
        if self.rr then RADIUS[self.file] = self.rr end
        self.fitted = true
        return true
    end
    -- Models load in steps: keep checking their size for a few seconds and
    -- refit whenever it changes.
    sc:SetScript("OnUpdate", function(self, elapsed)
        if not self.file then return end
        self.watch = (self.watch or 0) + elapsed
        if self.watch > 4 then return end
        self.tick = (self.tick or 0) + elapsed
        if self.tick < 0.1 then return end
        self.tick = 0
        self:Fit()
    end)
    function sc:Use(file, facing)
        if self.file == file then
            if not self.fitted then self:Fit() end
            return
        end
        self.file, self.fitted, self.sig, self.watch = file, false, nil, 0
        if actor.SetOnModelLoadedCallback then
            actor:SetOnModelLoadedCallback(function() sc:Fit() end)
        end
        actor:SetModelByFileID(file)
        if actor.SetYaw then actor:SetYaw(facing or 0) end
        self:Fit()
    end
    return sc
end

-- A unit: its WoW creature (by display id) in a ModelScene, fitted to the
-- frame by its height, seen from the same angle as the buildings.
local function MakeUnitModel(parent)
    local ok, sc = pcall(CreateFrame, "ModelScene", nil, parent)
    if not ok or not sc or not sc.CreateActor then return nil end
    local actor = sc:CreateActor()
    if not actor or not actor.SetModelByCreatureDisplayID then return nil end
    sc:SetSize(MODEL_W * MODEL_PAD, MODEL_H * MODEL_PAD)
    sc.actor = actor
    local view = ns.WC.ART.view
    function sc:SetDepth(d)
        if self.depth ~= d then
            self.depth, self.sig = d, nil
            self:Fit()
        end
    end
    function sc:Fit()
        if not self.disp or not actor.GetActiveBoundingBox then return false end
        local x1, y1, z1, x2, y2, z2 = actor:GetActiveBoundingBox()
        if not x1 or not x2 or (z2 - z1) <= 0.01 then return false end
        local sig = string.format("%.2f %.2f %.2f %s", x1, z1, z2, tostring(self.depth))
        self.loaded = true
        if sig == self.sig then return true end
        self.sig = sig
        local h = z2 - z1
        self.rr = math.sqrt(((x2 - x1) / 2) ^ 2 + ((y2 - y1) / 2) ^ 2 + (h / 2) ^ 2)
        RADIUS["unit"] = math.max(RADIUS["unit"] or 0, self.rr)
        -- Its height fills most of the frame.
        Camera(self, (x1 + x2) / 2, (y1 + y2) / 2, z1 + h / 2, (h * 0.55 * MODEL_PAD / UNIT_SIZE) / math.tan(view.fov / 2), view.bpitch)
        return true
    end
    sc:SetScript("OnUpdate", function(self, elapsed)
        if not self.disp then return end
        self.watch = (self.watch or 0) + elapsed
        if self.watch > 4 and self.loaded then return end
        self.tick = (self.tick or 0) + elapsed
        if self.tick < 0.1 then return end
        self.tick = 0
        self:Fit()
    end)
    function sc:UseCreature(disp)
        if self.disp == disp then return end
        self.disp, self.sig, self.watch, self.loaded, self.anim = disp, nil, 0, false, nil
        actor:SetModelByCreatureDisplayID(disp)
        self:Fit()
    end
    -- Some units are a model file rather than a creature (the Catapult).
    function sc:UseFile(file)
        if self.disp == "f" .. file then return end
        self.disp, self.sig, self.watch, self.loaded, self.anim = "f" .. file, nil, 0, false, nil
        actor:SetModelByFileID(file)
        self:Fit()
    end
    -- Bigger or smaller (the frame grows with it, so nothing is cut off),
    -- and greyer.
    sc.k = 1
    function sc:SetLook(k, desat)
        if self.k ~= k then
            self.k = k
            self:SetSize(MODEL_W * MODEL_PAD * k, MODEL_H * MODEL_PAD * k)
            self:ClearAllPoints()
            self:SetPoint("CENTER", self:GetParent(), "CENTER", 0, UNIT_FEET + UNIT_PX * k / 2)
        end
        if self.desat ~= desat then
            self.desat = desat
            if actor.SetDesaturation then actor:SetDesaturation(desat) end
        end
    end
    function sc:HasAnimation(anim)
        if actor.HasAnimation then return actor:HasAnimation(anim) end
        return false
    end
    -- Facing a screen direction (0 right, pi/2 down, towards the viewer): the
    -- same turn the old unit frames used (SetFacing(pi/2 - phi)), counted
    -- from looking straight at the camera.
    function sc:SetFacing(phi)
        local f = CameraDirs(self, view.yaw, view.bpitch)
        local toCamera = ATAN2(-f[2], -f[1])
        if actor.SetYaw then actor:SetYaw(toCamera + math.pi / 2 - phi) end
    end
    function sc:SetAnimation(anim, speed)
        if actor.SetAnimation then actor:SetAnimation(anim, 0, speed or 1) end
    end
    return sc
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
    local self = setmetatable({ kind = kind, G = ns.Games[kind], sel = {}, camX = 0, camY = 0, acc = 0, think = 0,
        treeTex = {}, unitFrames = {}, framePool = {}, corpses = {}, buildTex = {}, fxFree = {}, mmTrees = {},
        explored = {}, vis = {}, known = {} }, P)
    -- PvP: the Arcade lobby panel (who can join, create, practice, join by code).
    A.BuildSetup(self, parent)
    self.setup:Hide()
    local back = W.Button(self.setup, "Back", 90, function()
        self.setupOpen = false
        self:ShowMenu()
        self:Refresh()
    end, 22)
    back:SetPoint("BOTTOMLEFT", 10, 10)
    -- A PvP game runs even with the tab or window closed (the other player
    -- would wait otherwise): this frame drives it.
    self.driver = CreateFrame("Frame", nil, UIParent)
    self.driver:SetScript("OnUpdate", function(_, elapsed)
        if self.ls then self:LockstepTick(elapsed) end
    end)
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
    barFrame:SetFrameLevel(b:GetFrameLevel() + 480)
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
    self.newButton = W.Button(barFrame, "Menu", 80, function() self:ShowMenu() end, 18)
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
    local okWrap = pcall(self.ground.SetTexture, self.ground, ns.WC.ART.ground, "REPEAT", "REPEAT")
    if not okWrap then self.ground:SetTexture(ns.WC.ART.ground) end
    local function Layer(level)
        local f = CreateFrame("Frame", nil, view)
        f:SetAllPoints()
        f:SetFrameLevel(view:GetFrameLevel() + level)
        return f
    end
    -- Buildings and units share one depth order: whatever stands lower on the
    -- map (its feet, a building's bottom edge) is drawn in front (see Depth).
    self.treeLayer = Layer(1)
    self.buildLayer = Layer(2)
    self.unitLayer = Layer(2)
    self.buildTop = Layer(410) -- building health bars and team flags, above everything on the map
    self.fogLayer = Layer(415) -- fog of war over everything on the map
    self.fogTex = {}
    self.fxLayer = Layer(420)
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
        C = true, G = true, H = true, M = true, O = true, P = true, R = true, S = true, T = true, W = true, Y = true,
        D = true, E = true, U = true, N = true, V = true, X = true, K = true,
        L = true, ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, ["6"] = true, ["7"] = true,
        ["8"] = true, ["9"] = true, ["0"] = true },
        function(key) self:Key(key) end)

    -- The bottom panel: minimap, selection, command card.
    local hud = CreateFrame("Frame", nil, b)
    hud:SetPoint("TOPLEFT", 0, -(BAR + VIEW_H))
    hud:SetPoint("BOTTOMRIGHT")
    hud:SetFrameLevel(view:GetFrameLevel() + 450)
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

    -- A hero's bag: six items (click to use).
    self.itemButtons = {}
    for i = 1, 6 do
        local b = CreateFrame("Button", nil, hud)
        b:SetSize(24, 24)
        b:SetPoint("TOPLEFT", 500 + ((i - 1) % 2) * 28, -6 - math.floor((i - 1) / 2) * 28)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.7)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.15)
        b:SetScript("OnClick", function()
            if b.hero and b.item then self:Cmd({ type = "useItem", unit = b.hero, slot = i }) end
        end)
        b:SetScript("OnEnter", function()
            local it = b.item and WC().Items[b.item]
            if not it then return end
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(it.name, 1, 0.82, 0)
            GameTooltip:AddLine(it.text .. (it.use and " Click to use." or ""), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        self.itemButtons[i] = b
    end

    -- Command card: 4 x 3 buttons.
    self.cmds = {}
    for i = 1, 12 do
        local c = CreateFrame("Button", nil, hud)
        c:SetSize(38, 28)
        c:SetPoint("TOPLEFT", 566 + ((i - 1) % 4) * 41, -4 - math.floor((i - 1) / 4) * 30)
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
        if c.SetMotionScriptsWhileDisabled then c:SetMotionScriptsWhileDisabled(true) end
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
    o:SetFrameLevel(b:GetFrameLevel() + 520)
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
        btn:SetScript("OnClick", function() self:PickSide(f) end)
        W.Tooltip(btn, "Play " .. WC().Factions[f].name, "Your opponent plays the other side.")
        btn.faction = f
        self.picks[i] = btn
    end
    self.diffButtons = {}
    local diffLabel = W.Label(o, "Computer:", "GameFontNormal")
    diffLabel:SetPoint("TOP", -150, -322)
    self.diffLabel = diffLabel
    for i, key in ipairs({ "easy", "normal", "hard" }) do
        local d = WC().DIFFICULTY[key]
        local btn = W.Button(o, d.name, 80, function()
            Save().difficulty = key
            self:ShowStart()
        end, 22)
        btn:SetPoint("LEFT", diffLabel, "RIGHT", 10 + (i - 1) * 86, 0)
        btn.key = key
        self.diffButtons[i] = btn
    end
    self.againButton = W.Button(o, "Main menu", 110, function() self:ShowMenu() end, 26)
    self.againButton:SetPoint("TOP", self.overSub, "BOTTOM", 0, -20)
    self.resumeButton = W.Button(o, "Back to the game", 140, function() self:Resume() end, 22)
    self.resumeButton:SetPoint("BOTTOM", 0, 30)
    self.backButton = W.Button(o, "Back", 100, function() self:ShowMenu() end, 24)
    self.backButton:SetPoint("BOTTOMLEFT", 16, 16)

    -- The main menu, like Warcraft III's: Single Player, Find an Opponent, Play a Friend.
    local menu = CreateFrame("Frame", nil, o)
    menu:SetAllPoints()
    menu:SetFrameLevel(o:GetFrameLevel() + 4)
    menu.logo = W.BigLabel(menu, 38, "GameFontNormalHuge")
    menu.logo:SetPoint("TOP", 0, -26)
    menu.logo:SetText("WARCRAFT III")
    menu.logo:SetTextColor(1, 0.8, 0.25)
    menu.sub = W.Label(menu, "Reign of Chaos", "GameFontNormal")
    menu.sub:SetPoint("TOP", menu.logo, "BOTTOM", 0, -2)
    menu.sub:SetTextColor(0.85, 0.75, 0.55)
    local box = W.MenuFrame(menu)
    box:SetSize(340, 268)
    box:SetPoint("TOP", 0, -92)
    self.soloButton = W.MenuButton(box, "Single Player", "Play against the computer", 290, 62, function()
        self.mode = "solo"
        self:ShowStart()
    end)
    self.soloButton:SetPoint("TOP", 0, -22)
    self.queueButton = W.MenuButton(box, "Find an Opponent", "Anyone on your realm who wants a game", 290, 62, function()
        self.mode = "queue"
        self:ShowStart()
    end)
    self.queueButton:SetPoint("TOP", self.soloButton, "BOTTOM", 0, -12)
    self.friendButton = W.MenuButton(box, "Play a Friend", "Your group, guild, realm or a private code", 290, 62, function()
        self.setupOpen = true
        self:Refresh()
    end)
    self.friendButton:SetPoint("TOP", self.queueButton, "BOTTOM", 0, -12)
    self.menuResume = W.MenuButton(menu, "Back to the game", nil, 180, 36, function() self:Resume() end)
    self.menuResume:SetPoint("TOP", box, "BOTTOM", 0, -14)
    self.demoButton = W.MenuButton(menu, "Showcase", nil, 140, 30, function() self:StartDemo() end)
    self.demoButton:SetPoint("BOTTOMRIGHT", -16, 16)
    W.Tooltip(self.demoButton, "Showcase", "Every building, unit and hero on one map, with names. Heroes cast all their spells in turn.")
    menu:Hide()
    self.mainMenu = menu
    self.lobbyText = W.Label(o, "", "GameFontHighlight")
    self.lobbyText:SetPoint("TOP", self.overSub, "BOTTOM", 0, -18)
    self.lobbyText:SetWidth(BW - 140)
    self.pvpButtons = {}
    local S = ns.Session
    local function PvpButton(key, label, width, fn)
        local btn = W.Button(o, label, width, fn, 24)
        btn:Hide()
        self.pvpButtons[key] = btn
    end
    PvpButton("start", "Start", 100, function() S.Start(self.kind) end)
    PvpButton("bot", "Add bot", 100, function() S.AddBot(self.kind) end)
    PvpButton("rematch", "Rematch", 100, function() S.Act(self.kind, "rematch") end)
    PvpButton("leave", "Leave", 100, function() S.Leave(self.kind) S.Dismiss(self.kind) self:Refresh() end)
    PvpButton("close", "Close lobby", 110, function() A.CloseLobby(self) self:Refresh() end)
    PvpButton("done", "Back", 100, function() S.Dismiss(self.kind) self:Refresh() end)
    PvpButton("cancelQueue", "Cancel", 100, function() self:CancelQueue() end)
    -- In a PvP game: give up, or win when the other player is gone.
    self.surrender = W.Button(self.fxLayer, "Surrender", 90, function()
        W.Confirm("Surrender this game?", function() S.Act(self.kind, "surrender") end)
    end, 20)
    self.surrender:SetPoint("TOPRIGHT", -8, -6)
    self.surrender:Hide()
    self.claim = W.Button(self.fxLayer, "Claim victory", 120, function() self:ClaimVictory() end, 22)
    self.claim:SetPoint("TOP", self.status, "BOTTOM", 0, -6)
    self.claim:Hide()

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
        self:ShowMenu()
    end
    self:Refresh()
    return self
end

---------------------------------------------------------------------------
-- Games
---------------------------------------------------------------------------
-- The main menu.
function P:ShowMenu()
    if not self.ls then self:Pause() end
    self.mode = nil
    self.overlay:Show()
    self:HideScreens()
    self.mainMenu:Show()
    self.overTitle:SetText("")
    self.overSub:SetText("")
    self.menuResume:SetShown(not self.pvp and self.st ~= nil and not self.st.over)
end

-- Everything the overlay can show, off.
function P:HideScreens()
    self.mainMenu:Hide()
    for _, p in ipairs(self.picks) do p:Hide() end
    self.diffLabel:Hide()
    for _, b in ipairs(self.diffButtons) do b:Hide() end
    for _, b in ipairs({ self.againButton, self.resumeButton, self.backButton }) do b:Hide() end
    self.lobbyText:SetText("")
    self:PvpButtons({})
end

-- Pick a race: for a game against the computer, the queue, or a PvP lobby.
function P:ShowStart()
    if not self.ls then self:Pause() end
    self.overlay:Show()
    self:HideScreens()
    self.overTitle:SetText(self.pvp and "Choose your race" or self.mode == "queue" and "Find an Opponent" or "Single Player")
    self.overTitle:SetTextColor(1, 0.82, 0)
    local solo = not self.pvp and self.mode ~= "queue"
    self.overSub:SetText(self.pvp and "Pick your race. Your opponent picks theirs."
        or self.mode == "queue" and "Pick your race, then we look for an opponent on your realm."
        or "Build up your base, train an army and destroy every enemy building. The computer plays the other side.")
    for _, p in ipairs(self.picks) do p:Show() end
    local chosen = Save().difficulty or "normal"
    self.diffLabel:SetShown(solo)
    for _, b in ipairs(self.diffButtons) do
        b:SetShown(solo)
        b:SetEnabled(b.key ~= chosen) -- the chosen one is greyed out
    end
    self.backButton:SetShown(not self.pvp)
end

function P:PickSide(faction)
    if self.pvp then
        ns.Session.Act(self.kind, "race:" .. faction)
        self:Refresh()
    elseif self.mode == "queue" then
        self:StartQueue(faction)
    else
        self:NewGame(faction)
    end
end

function P:NewGame(faction, seed)
    ME, CPU = 1, 2
    local other = faction == "human" and "orc" or "human"
    self.groups, self.lastClick, self.lastGroup = {}, nil, nil
    self.explored, self.vis, self.known, self.fogAt = {}, {}, {}, 0
    self.st = E().New({ factions = { faction, other }, seed = seed or math.random(1, 2000000000),
        difficulty = Save().difficulty or "normal" })
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
    if ns.Queue.IsQueued(self.kind) then ns.Queue.Leave(self.kind) end
    if self.pvp then return self:LeavePvp() end
    local demo = self.st and self.st.demo
    self.st = nil
    if not demo then Save().game = nil end
    ns.Solo.SetRunning(self.kind, false)
    self:ShowMenu()
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
    self:HideScreens()
    self.againButton:Show()
    self.overTitle:SetText(won and "Victory!" or "Defeat")
    self.overTitle:SetTextColor(won and 1 or 0.9, won and 0.82 or 0.3, won and 0 or 0.3)
    self.overSub:SetText(string.format("%s, %d:%02d played. Wins %d, losses %d.",
        WC().DIFFICULTY[st.difficulty or "normal"].name, math.floor(st.time / 60),
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
    self:FadeFlash()
    if self.ls then
        if not self.paused then self:Scroll(elapsed) end
        self:Draw()
        return
    end
    if not self.paused and not st.over then
        self:Scroll(elapsed)
        self.acc = self.acc + elapsed
        while self.acc >= STEP do
            self.acc = self.acc - STEP
            local events = E().Step(st, STEP)
            self:Events(events)
            if st.demo then self:DemoTick(STEP) end
            self.think = self.think + STEP
            if self.think >= 1 and CPU then
                self.think = 0
                WC().AI.Think(st, CPU)
            end
            if st.over then break end
        end
        if st.over then
            self:Draw()
            if self.pvp then return self:PvpGameEnded() end
            return self:GameOver()
        end
    end
    self:Draw()
end

function P:FadeFlash()
    if self.flashTex and self.flashUntil then
        local left = self.flashUntil - Now()
        if left <= 0 then self.flashTex:Hide() self.flashUntil = nil else self.flashTex:SetAlpha(math.min(1, left)) end
    end
end

local WARN = { "^Not enough", "^Can't", "^Requires", "^Bring a hero", "^The hero's bag", "^Not ready" }
function P:Say(text)
    if Snd() then
        for _, w in ipairs(WARN) do
            if tostring(text):find(w) then W.PlayFile(Snd().Error, "alert") break end
        end
    end
    self.status:SetText(text)
    self.sayUntil = Now() + 2
end

-- Sounds and little effects for what just happened.
function P:Events(events)
    self:SpellEvents(events)
    self:Sounds(events)
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
        elseif ev.kind == "cast" then
            local a = WC().Abilities[ev.ability]
            if ev.owner == ME then self:Say(a.name) end
            if ev.x then self:Flash(ev.x, ev.y, ev.ability) end
            W.PlaySound("U_CHAT_SCROLL_BUTTON")
        elseif ev.kind == "bolt" then
            local a, t = self.st.ents[ev.id], self.st.ents[ev.target]
            if a and t then
                local ax, ay = E().Center(a)
                local tx, ty = E().Center(t)
                self:Shot(ax, ay, tx, ty)
            end
        elseif ev.kind == "levelUp" and ev.owner == ME then
            self:Say(WC().Units[ev.type].name .. " reached level " .. ev.level .. "!")
            W.PlaySound("LEVELUP")
        elseif ev.kind == "heroDied" then
            self:Say(ev.owner == ME and ("Your " .. WC().Units[ev.type].name .. " has fallen. Revive at the altar.")
                or ("Enemy " .. WC().Units[ev.type].name .. " slain!"))
        elseif ev.kind == "revived" and ev.owner == ME then
            self:Say(WC().Units[ev.type].name .. " is back!")
        elseif ev.kind == "researched" and ev.owner == ME then
            local r = WC().Research[ev.key]
            self:Say(ev.upgrade and (WC().Buildings[ev.upgrade].name .. " ready")
                or ((r.names and r.names[ev.level] or r.name) .. " researched"))
            W.PlaySound("IG_MAINMENU_OPTION")
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
    elseif ns.UI.full and not self.drag and GetCursorPosition and UIParent:IsMouseOver() then
        -- Fullscreen: the mouse at the edge of the screen scrolls too (like Warcraft III).
        local s = UIParent:GetEffectiveScale()
        local mx, my = GetCursorPosition()
        mx, my = mx / s, my / s
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        if mx < 6 then dx = dx - 1 elseif mx > w - 6 then dx = dx + 1 end
        if my > h - 6 then dy = dy - 1 elseif my < 6 then dy = dy + 1 end
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
        if #ids > 0 then self:Cmd({ type = "move", units = ids, x = x, y = y }) end
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
    local e = self:SeenAt(x, y) or self:SeenAt(x, y + 0.7) or self:SeenAt(x, y + 1.3)
    if not e then
        if not add then self.sel = {} end
        return
    end
    -- Double-click (or Ctrl+click) one of your units: all of that type on screen.
    local last = self.lastClick
    local double = last and last.type == e.type and last.id == e.id and Now() - last.t < 0.4
    self.lastClick = { id = e.id, type = e.type, t = Now() }
    if e.owner == ME and e.kind == "unit" and (double or (IsControlKeyDown and IsControlKeyDown())) then
        self:SelectType(e.type, add)
        self:Voice(e, "what")
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
    if e.owner == ME and e.kind == "unit" and Snd() and Snd().Voices[e.type] then
        self:Voice(e, "what")
    else
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
    end
end

-- All your units of a type that are on screen.
function P:SelectType(utype, add)
    local x0, y0 = self.camX / TILE, self.camY / TILE
    local x1, y1 = x0 + BW / TILE, y0 + VIEW_H / TILE
    local picked = add and self.sel or {}
    local have = {}
    for _, id in ipairs(picked) do have[id] = true end
    for _, id in ipairs(self.st.list) do
        local e = self.st.ents[id]
        if e and e.owner == ME and e.kind == "unit" and e.type == utype and not have[id]
            and e.x >= x0 and e.x <= x1 and e.y >= y0 and e.y <= y1 then
            table.insert(picked, id)
        end
    end
    self.sel = picked
end

-- Control groups, like Warcraft III: Ctrl+number sets, Shift+number adds,
-- the number selects it (twice quickly: the camera jumps there).
function P:Group(n)
    self.groups = self.groups or {}
    local ctrl = IsControlKeyDown and IsControlKeyDown()
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    local mine = {}
    for _, e in ipairs(self:Selected()) do
        if e.owner == ME then table.insert(mine, e.id) end
    end
    if ctrl or (shift and self.groups[n]) then
        local g = ctrl and {} or self.groups[n]
        local have = {}
        for _, id in ipairs(g) do have[id] = true end
        for _, id in ipairs(mine) do if not have[id] then table.insert(g, id) end end
        if #g > 0 then
            self.groups[n] = g
            self:Say("Group " .. n .. ": " .. #g)
        end
        return
    end
    local g = self.groups[n]
    if not g then return end
    local alive = {}
    for _, id in ipairs(g) do if self.st.ents[id] then table.insert(alive, id) end end
    self.groups[n] = alive
    if #alive == 0 then return end
    local last = self.lastGroup
    if last and last.n == n and Now() - last.t < 0.4 then self:CenterOn(self.st.ents[alive[1]]) end
    self.lastGroup = { n = n, t = Now() }
    self.sel = { unpack(alive) }
    self.menu = nil
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
    if #picked > 0 then self:Voice(self.st.ents[picked[1]], "what") end
end

-- Right-click: move, attack, gather, or set a rally point.
function P:Smart(x, y)
    local st = self.st
    local target = self:SeenAt(x, y) or self:SeenAt(x, y + 0.7)
    local tree = st.trees[math.floor(y) * st.w + math.floor(x)] and (math.floor(y) * st.w + math.floor(x)) or nil
    local units = self:MyUnits()
    self:Mark(x, y)
    if #units == 0 then
        -- A building of yours: set its rally point.
        local b = self:Selected()[1]
        if b and b.owner == ME and b.kind == "building" then
            self:Cmd({ type = "rally", building = b.id, x = x, y = y,
                target = target and target.kind == "mine" and target.id or nil, tree = tree })
            self:Say("Rally point set")
        end
        return
    end
    local q = Shift()
    if target and target.owner ~= ME and target.owner > 0 then
        return self:Cmd({ type = "attack", units = units, target = target.id, queue = q })
    end
    local workers, others = {}, {}
    for _, id in ipairs(units) do
        local u = st.ents[id]
        if WC().Units[u.type].worker then table.insert(workers, id) else table.insert(others, id) end
    end
    if target and target.owner == ME and target.kind == "building" and target.progress < 1 and #workers > 0 then
        self:Cmd({ type = "resumeBuild", units = workers, building = target.id })
        return
    end
    if target and target.kind == "mine" and #workers > 0 then
        self:Cmd({ type = "gather", units = workers, target = target.id, queue = q })
        if #others > 0 then self:Cmd({ type = "move", units = others, x = x, y = y, queue = q }) end
        return
    end
    if tree and #workers > 0 then
        self:Cmd({ type = "gather", units = workers, tree = tree, queue = q })
        if #others > 0 then self:Cmd({ type = "move", units = others, x = x, y = y, queue = q }) end
        return
    end
    self:Cmd({ type = "move", units = units, x = x, y = y, queue = q })
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
    if mode == "cast" then
        local target = self:SeenAt(x, y) or self:SeenAt(x, y + 0.7)
        local ok, why = self:Cmd({ type = "cast", unit = self.castHero, ability = self.castKey,
            target = target and target.id, x = x, y = y, queue = Shift() })
        if not ok and why then self:Say(why:sub(1, 1):upper() .. why:sub(2)) end
        return
    end
    if mode == "move" then
        local units = self:MyUnits()
        if #units > 0 then self:Cmd({ type = "move", units = units, x = x, y = y, queue = Shift() }) end
    elseif mode == "gather" then
        self:Smart(x, y)
    elseif mode == "rally" then
        local b = self:Selected()[1]
        local target = E().At(st, x, y)
        local i = math.floor(y) * st.w + math.floor(x)
        if b then
            self:Cmd({ type = "rally", building = b.id, x = x, y = y,
                target = target and target.kind == "mine" and target.id or nil, tree = st.trees[i] and i or nil })
        end
    end
end

function P:AttackAt(x, y)
    self.targeting = nil
    local units = self:MyUnits()
    if #units == 0 then return end
    local target = self:SeenAt(x, y)
    self:Mark(x, y)
    if target and target.owner ~= ME and target.owner > 0 then
        self:Cmd({ type = "attack", units = units, target = target.id, queue = Shift() })
    else
        self:Cmd({ type = "attackMove", units = units, x = x, y = y, queue = Shift() })
    end
end

-- Building placement follows the mouse; the top-left tile is under the cursor's corner.
function P:PlaceSpot(x, y)
    local size = WC().Buildings[self.place.btype].size
    return math.floor(x - size / 2 + 0.5), math.floor(y - size / 2 + 0.5), size
end

function P:PlaceAt(x, y)
    local bx, by = self:PlaceSpot(x, y)
    local q = Shift()
    local ok, why = self:Cmd({ type = "build", unit = self.place.unit, btype = self.place.btype, x = bx, y = by,
        queue = q })
    if ok then
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
        -- Shift: keep placing more of them, while there's money.
        if q and E().CanAfford(self.st, ME, WC().Buildings[self.place.btype].cost) then return end
        self.place = nil
        self.ghost:Hide()
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
    self.ghost:SetTexture(ArtOf(btype))
    self:Say("Click where to build (right-click cancels)")
end

function P:Research(key)
    local b = self:Selected()[1]
    if not b then return end
    local ok, why = self:Cmd({ type = "research", building = b.id, key = key })
    if not ok and why then self:Say(why:sub(1, 1):upper() .. why:sub(2)) end
end

function P:Train(utype)
    local b = self:Selected()[1]
    if not b then return end
    local ok, why = self:Cmd({ type = "train", building = b.id, utype = utype })
    if not ok then self:Say(why and (why:sub(1, 1):upper() .. why:sub(2)) or "Can't train that") end
end

function P:CancelTrain()
    local b = self:Selected()[1]
    if b then self:Cmd({ type = "cancel", building = b.id }) end
end

function P:Target(mode, text)
    self.targeting = mode
    self.place = nil
    self:Say(text .. " (right-click cancels)")
end

function P:CastAbility(hero, key)
    local a = WC().Abilities[key]
    if a.target == "self" then
        local ok, why = self:Cmd({ type = "cast", unit = hero.id, ability = key })
        if not ok and why then self:Say(why:sub(1, 1):upper() .. why:sub(2)) end
        return
    end
    self.castHero, self.castKey = hero.id, key
    self:Target("cast", a.name .. ": click " .. (a.target == "point" and "where" or "a target"))
end

function P:Revive(utype)
    local b = self:Selected()[1]
    if not b then return end
    local ok, why = self:Cmd({ type = "revive", building = b.id, utype = utype })
    if not ok and why then self:Say(why:sub(1, 1):upper() .. why:sub(2)) end
end

-- A ring where a spell lands, in its colour.
local FLASH = { blizzard = { 0.5, 0.8, 1 }, flame_strike = { 1, 0.5, 0.1 }, earthquake = { 0.7, 0.5, 0.2 },
    far_sight = { 0.6, 0.9, 1 }, shockwave = { 0.9, 0.7, 0.3 }, serpent_ward = { 0.3, 1, 0.3 } }
function P:Flash(x, y, key)
    local a = WC().Abilities[key]
    local col = FLASH[key] or { 1, 1, 0.6 }
    local r = a and (type(a.radius) == "table" and a.radius[1] or a.radius) or 1
    local t = self.flashTex or self.fxLayer:CreateTexture(nil, "OVERLAY")
    self.flashTex = t
    t:SetTexture(ART .. "WcSelect")
    t:SetVertexColor(col[1], col[2], col[3])
    t:SetSize(r * 2 * TILE, r * TILE * 1.4)
    t:ClearAllPoints()
    t:SetPoint("CENTER", self.view, "TOPLEFT", x * TILE - self.camX, -(y * TILE - self.camY))
    t:SetAlpha(1)
    t:Show()
    self.flashUntil = Now() + 1.2
end

function P:Hold()
    local units = self:MyUnits()
    if #units > 0 then self:Cmd({ type = "hold", units = units }) end
end

function P:ReturnRes()
    local units = self:MyUnits()
    if #units > 0 then
        local ok, why = self:Cmd({ type = "returnRes", units = units })
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
    local ok, why = self:Cmd({ type = f.alarm, building = b.id })
    if not ok then self:Say(why and (why:sub(1, 1):upper() .. why:sub(2)) or "Nobody answers") end
end

function P:Stop()
    local units = self:MyUnits()
    if #units > 0 then self:Cmd({ type = "stop", units = units }) end
end

function P:Key(key)
    if not self.st or self.paused then return end
    local n = key:match("^(%d)$")
    if n then return self:Group(tonumber(n)) end
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

---------------------------------------------------------------------------
-- Fog of war: black where you've never been, dim where you've been but
-- see nothing now. Enemy units show only in sight; enemy buildings stay
-- once found (like Warcraft III).
---------------------------------------------------------------------------
-- How far an entity of yours sees.
local function ViewOf(e)
    local V = WC().VIEW
    if e.kind == "unit" then return WC().Units[e.type].worker and V.worker or V.unit end
    local d = WC().Buildings[e.type]
    if d.attack then return V.tower end
    return d.hall and V.hall or V.building
end

function P:UpdateFog()
    local st = self.st
    if st.demo then
        local vis = {}
        for i = 0, st.w * st.h - 1 do vis[i], self.explored[i] = true, true end
        self.vis = vis
        return
    end
    local vis, explored = {}, self.explored
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == ME and not e.inside then
            local cx, cy = e.x, e.y
            if e.kind ~= "unit" then cx, cy = e.x + e.size / 2, e.y + e.size / 2 end
            local r = ViewOf(e)
            for ty = math.max(0, math.floor(cy - r)), math.min(st.h - 1, math.floor(cy + r)) do
                for tx = math.max(0, math.floor(cx - r)), math.min(st.w - 1, math.floor(cx + r)) do
                    if (tx + 0.5 - cx) ^ 2 + (ty + 0.5 - cy) ^ 2 <= r * r then
                        local i = ty * st.w + tx
                        vis[i], explored[i] = true, true
                    end
                end
            end
        end
    end
    -- Far Sight.
    for _, r in ipairs(st.reveals or {}) do
        if r.owner == ME then
            for ty = math.max(0, math.floor(r.y - r.r)), math.min(st.h - 1, math.floor(r.y + r.r)) do
                for tx = math.max(0, math.floor(r.x - r.r)), math.min(st.w - 1, math.floor(r.x + r.r)) do
                    if (tx + 0.5 - r.x) ^ 2 + (ty + 0.5 - r.y) ^ 2 <= r.r * r.r then
                        local i = ty * st.w + tx
                        vis[i], explored[i] = true, true
                    end
                end
            end
        end
    end
    self.vis = vis
    -- Enemy buildings seen once stay known.
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind ~= "unit" and not self.known[id] and self:TileSeen(e, vis) then self.known[id] = true end
    end
end

-- Any tile of e's footprint in sight?
function P:TileSeen(e, vis)
    local st = self.st
    vis = vis or self.vis
    local size = e.size or 1
    for ty = math.floor(e.y), math.floor(e.y + size - 0.01) do
        for tx = math.floor(e.x), math.floor(e.x + size - 0.01) do
            if vis[ty * st.w + tx] then return true end
        end
    end
    return false
end

-- Can you see this entity now?
function P:Sees(e)
    if e.owner == ME then return true end
    if e.kind ~= "unit" then return self.known[e.id] == true or self:TileSeen(e) end
    if E().Hidden and E().Hidden(e) then return false end
    return self.vis[math.floor(e.y) * self.st.w + math.floor(e.x)] == true
end

-- What's at that spot, if you can see it.
function P:SeenAt(x, y)
    local e = E().At(self.st, x, y)
    if e and self:Sees(e) then return e end
end

function P:DrawFog()
    local st = self.st
    local cx, cy = self.camX, self.camY
    local x0, y0 = math.max(0, math.floor(cx / TILE)), math.max(0, math.floor(cy / TILE))
    local x1 = math.min(st.w - 1, math.floor((cx + BW) / TILE))
    local y1 = math.min(st.h - 1, math.floor((cy + VIEW_H) / TILE))
    local used = 0
    for ty = y0, y1 do
        for tx = x0, x1 do
            local i = ty * st.w + tx
            if not self.vis[i] then
                used = used + 1
                local t = self.fogTex[used]
                if not t then
                    t = self.fogLayer:CreateTexture(nil, "ARTWORK")
                    t:SetSize(TILE + 1, TILE + 1)
                    self.fogTex[used] = t
                end
                t:SetColorTexture(0, 0, 0, self.explored[i] and 0.5 or 1)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.view, "TOPLEFT", tx * TILE - cx, -(ty * TILE - cy))
                t:Show()
            end
        end
    end
    for j = used + 1, #self.fogTex do self.fogTex[j]:Hide() end
    -- The minimap, in blocks of 4 tiles.
    self.mmFog = self.mmFog or {}
    local n = 0
    for by = 0, st.h - 1, 4 do
        for bx = 0, st.w - 1, 4 do
            local seen, now = false, false
            for ty = by, math.min(st.h - 1, by + 3) do
                for tx = bx, math.min(st.w - 1, bx + 3) do
                    local i = ty * st.w + tx
                    if self.vis[i] then now = true end
                    if self.explored[i] then seen = true end
                end
            end
            if not now then
                n = n + 1
                local t = self.mmFog[n]
                if not t then
                    t = self.mm:CreateTexture(nil, "OVERLAY")
                    t:SetSize(4 * MM_SCALE, 4 * MM_SCALE)
                    self.mmFog[n] = t
                end
                t:SetColorTexture(0, 0, 0, seen and 0.45 or 0.95)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.mm, "TOPLEFT", bx * MM_SCALE, -by * MM_SCALE)
                t:Show()
            end
        end
    end
    for j = n + 1, #self.mmFog do self.mmFog[j]:Hide() end
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
    local art = ns.WC.ART
    local x0, y0 = math.floor(self.camX / TILE) - 2, math.floor(self.camY / TILE) - 2
    local x1, y1 = x0 + math.ceil(BW / TILE) + 4, y0 + math.ceil(VIEW_H / TILE) + 4
    x0, y0 = x0 - x0 % 2, y0 - y0 % 2
    self.treeModels = self.treeModels or {}
    self.floorTex = self.floorTex or {}
    self.shadeTex = self.shadeTex or {}
    -- The forest floor: dark leaf ground under every tree tile, so forests read as walls.
    local floors = 0
    for y = math.max(0, y0), math.min(st.h - 1, y1 + 1) do
        for x = math.max(0, x0), math.min(st.w - 1, x1 + 1) do
            if st.trees[y * st.w + x] then
                floors = floors + 1
                local f = self.floorTex[floors]
                if not f then
                    f = self.treeLayer:CreateTexture(nil, "BACKGROUND")
                    pcall(f.SetTexture, f, art.forestFloor, "REPEAT", "REPEAT")
                    f:SetVertexColor(art.forestShade, art.forestShade, art.forestShade)
                    f:SetSize(TILE + 1, TILE + 1)
                    self.floorTex[floors] = f
                end
                f:SetTexCoord((x % 4) / 4, (x % 4 + 1) / 4, (y % 4) / 4, (y % 4 + 1) / 4)
                f:Show()
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", self.view, "TOPLEFT", x * TILE - self.camX, -(y * TILE - self.camY))
            end
        end
    end
    for j = floors + 1, #self.floorTex do self.floorTex[j]:Hide() end
    local used = 0
    for by = math.max(0, y0), math.min(st.h - 1, y1), 2 do
        for bx = math.max(0, x0), math.min(st.w - 1, x1), 2 do
            local n = 0
            for dy = 0, 1 do
                for dx = 0, 1 do
                    if st.trees[(by + dy) * st.w + bx + dx] then n = n + 1 end
                end
            end
            if n > 0 then
                used = used + 1
                local t = self.treeModels[used]
                if not t then
                    t = MakeDoodad(self.treeLayer) or self.treeLayer:CreateTexture(nil, "ARTWORK")
                    if not t.Use then t:SetTexture(ART .. "WcTree") end
                    self.treeModels[used] = t
                end
                local size = TILE * 2 * art.treeGrow * (n >= 3 and 1 or 0.8)
                t:SetSize(size, size)
                if t.Use then
                    local file = art.trees[(bx / 2 + by / 2) % #art.trees + 1]
                    t.row = by + 2
                    t:SetDepth(self:DepthAt(t.row, RADIUS[file] or 25))
                    t:Use(file, (bx * 7 + by * 3) % 6)
                end
                t:Show()
                Place(t, self.view, (bx + 1) * TILE - self.camX, (by + 1) * TILE - self.camY - art.treeY)
                -- A soft shadow at its foot.
                local sh = self.shadeTex[used]
                if not sh then
                    sh = self.treeLayer:CreateTexture(nil, "BORDER")
                    sh:SetTexture(ART .. "Blob")
                    sh:SetVertexColor(0, 0, 0)
                    sh:SetAlpha(0.45)
                    self.shadeTex[used] = sh
                end
                sh:SetSize(size * 0.8, size * 0.45)
                sh:Show()
                Place(sh, self.view, (bx + 1) * TILE - self.camX + 4, (by + 1) * TILE - self.camY + 4)
            end
        end
    end
    for j = used + 1, #self.treeModels do self.treeModels[j]:Hide() end
    for j = used + 1, #self.shadeTex do self.shadeTex[j]:Hide() end
end

-- The frame level for something standing at map row y (half-tile steps,
-- four levels each: a unit's frame, model and health bar fit in one step).
function P:Depth(y)
    return self.buildLayer:GetFrameLevel() + 1 + math.max(0, math.min(100, math.floor(y * 2))) * 4
end

-- The depth plan: each half row of the map gets a slice of distance from the
-- camera, thick enough for the biggest model standing on it; the bottom row
-- is nearest. A model stands in its row's slice, so anything lower on the map
-- is always nearer than anything higher up, whatever their shapes.
local DEPTH_BASE = 60 -- the nearest slice (beyond the near clip)
function P:PlanDepth()
    local st = self.st
    local thick = {}
    local function Add(row, r)
        local b = math.floor(row * 2)
        thick[b] = math.max(thick[b] or 0, 2 * r)
    end
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind ~= "unit" then
            local look = ns.WC.ART.models[e.type]
            Add(e.y + e.size, look and RADIUS[look.file] or 30)
        end
    end
    local treeR = 0
    for _, file in ipairs(ns.WC.ART.trees) do treeR = math.max(treeR, RADIUS[file] or 25) end
    for i in pairs(st.trees) do
        local y = math.floor(i / st.w)
        Add(y - y % 2 + 2, treeR)
    end
    local unitThick = 2 * (RADIUS.unit or 3) + 1
    local plan, off = {}, DEPTH_BASE
    for b = st.h * 2 + 4, -4, -1 do
        plan[b] = off
        off = off + math.max(thick[b] or 0, unitThick) + 1
    end
    self.depthPlan = plan
end

-- The camera distance for a model of size rr standing at map row `row`.
function P:DepthAt(row, rr)
    local plan = self.depthPlan
    if not plan then return nil end
    local b = math.max(-4, math.min(self.st.h * 2 + 4, math.floor(row * 2)))
    return (plan[b] or DEPTH_BASE) + rr
end

-- A creature's display id (the unit model needs it): load the creature once
-- in a tiny model frame and read it; saved for next time.
function P:Probe(npc)
    local m = self.prober
    if m == false then return end
    if not m then
        local ok
        ok, m = pcall(CreateFrame, "PlayerModel", nil, self.view)
        if not ok or not m or not m.SetCreature or not m.GetDisplayInfo then
            self.prober = false
            return
        end
        m:SetSize(8, 8)
        m:SetPoint("TOPLEFT", 0, 0)
        m:SetAlpha(0.01)
        pcall(m.SetScript, m, "OnModelLoaded", function(s)
            local d = s:GetDisplayInfo()
            if s.npc and d and d > 0 and d ~= s.oldDisp then Looks()[s.npc] = d end
        end)
        self.prober = m
    end
    -- Right after switching creatures the frame still reports the last
    -- one's look: only a new look counts.
    if m.npc and not Looks()[m.npc] then
        local d = m:GetDisplayInfo()
        if d and d > 0 and d ~= m.oldDisp then Looks()[m.npc] = d end
    end
    -- One creature at a time; give each a couple of seconds to load.
    if m.npc and not Looks()[m.npc] and Now() - (m.t or 0) < 2 then return end
    if m.npc == npc and Looks()[npc] then return end
    m.oldDisp = m.GetDisplayInfo and m:GetDisplayInfo() or nil
    if m.oldDisp == 0 then m.oldDisp = nil end
    m.npc, m.t = npc, Now()
    m:SetCreature(npc)
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
        f.model = MakeUnitModel(f)
        if f.model then
            f.model:SetPoint("CENTER", f, "CENTER", 0, UNIT_FEET + UNIT_PX / 2)
            f.model.npc = WC().Units[utype].npc
            f.model.fileId = WC().Units[utype].file
            -- A flyer's shadow on the ground.
            if WC().Units[utype].air then
                f.shadow = f:CreateTexture(nil, "BACKGROUND")
                f.shadow:SetTexture(ART .. "Blob")
                f.shadow:SetVertexColor(0, 0, 0, 0.45)
                f.shadow:SetSize(24, 10)
            end
            f.model:SetFrameLevel(f:GetFrameLevel() + 1)
        end
        local top = CreateFrame("Frame", nil, f)
        top:SetAllPoints()
        top:SetFrameLevel(f:GetFrameLevel() + 3)
        f.top = top
        f.hpBg = top:CreateTexture(nil, "OVERLAY", nil, 1)
        f.hpBg:SetColorTexture(0, 0, 0, 0.8)
        f.hpBg:SetSize(20, 3)
        f.hpBg:SetPoint("BOTTOM", f, "CENTER", 0, UNIT_FEET + UNIT_PX + 3)
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
    local rep = TILE * ns.WC.ART.groundRepeat
    self.ground:SetTexCoord(cx / rep, (cx + BW) / rep, cy / rep, (cy + VIEW_H) / rep)
    if self.treeDirty or self.lastCamX ~= cx or self.lastCamY ~= cy then
        self:DrawTrees()
        self.treeDirty = false
        self.lastCamX, self.lastCamY = cx, cy
    end
    -- Fog of war.
    if Now() >= (self.fogAt or 0) then
        self.fogAt = Now() + 0.2
        self:UpdateFog()
        self.fogDirty = true
    end
    if self.fogDirty or self.fogCamX ~= cx or self.fogCamY ~= cy then
        self.fogDirty, self.fogCamX, self.fogCamY = false, cx, cy
        self:DrawFog()
    end
    -- Buildings ordered but not started yet: faint ghosts.
    self.planTex = self.planTex or {}
    local plans = E().PlannedSites(st, ME)
    for i, s in ipairs(plans) do
        local t = self.planTex[i]
        if not t then
            t = self.buildLayer:CreateTexture(nil, "BORDER")
            t:SetVertexColor(0.5, 1, 0.5)
            t:SetAlpha(0.35)
            self.planTex[i] = t
        end
        local size = s.size * TILE
        t:SetTexture(ArtOf(s.btype))
        t:SetSize(size, size)
        Place(t, self.view, s.x * TILE - cx + size / 2, s.y * TILE - cy + size / 2)
        t:Show()
    end
    for i = #plans + 1, #self.planTex do self.planTex[i]:Hide() end
    -- Depth: lower on the map = nearer the camera = in front (see PlanDepth).
    self:PlanDepth()
    for _, t in ipairs(self.treeModels or {}) do
        if t.SetDepth and t.row and t:IsShown() then t:SetDepth(self:DepthAt(t.row, RADIUS[t.file] or 25)) end
    end
    local selected = {}
    for _, id in ipairs(self.sel) do selected[id] = true end
    -- Buildings and the mine.
    local bi, ui = 0, 0
    self.mmDots:Begin()
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind ~= "unit" and self:Sees(e) then
            bi = bi + 1
            local t = self.buildTex[bi]
            if not t then
                t = { art = self.buildLayer:CreateTexture(nil, "ARTWORK"), sel = self.buildLayer:CreateTexture(nil, "BORDER"),
                    bar = self.buildTop:CreateTexture(nil, "OVERLAY"), barBg = self.buildTop:CreateTexture(nil, "OVERLAY", nil, -1),
                    team = self.buildTop:CreateTexture(nil, "OVERLAY", nil, 1) }
                t.sel:SetTexture(ART .. "WcSelect")
                t.sel:SetVertexColor(0.3, 1, 0.3)
                t.barBg:SetColorTexture(0, 0, 0, 0.8)
                self.buildTex[bi] = t
            end
            local px, py = e.x * TILE - cx, e.y * TILE - cy
            local size = e.size * TILE
            local look = ns.WC.ART.models[e.type]
            if t.model == nil then t.model = MakeDoodad(self.buildLayer) or false end
            local alpha = (e.progress or 1) < 1 and 0.45 + 0.55 * e.progress or 1
            if not t.shadow then
                t.shadow = self.buildLayer:CreateTexture(nil, "BACKGROUND")
                t.shadow:SetTexture(ART .. "Blob")
                t.shadow:SetVertexColor(0, 0, 0)
                t.shadow:SetAlpha(0.5)
            end
            t.shadow:SetSize(size * 1.25, size * 0.8)
            Place(t.shadow, self.view, px + size / 2 + 4, py + size / 2 + 6)
            t.shadow:Show()
            if t.model and look then
                -- A big frame centred on the footprint: the model stands at its centre.
                local fs = size * 2 * ((look.tall or ns.WC.ART.view.tall) + 0.6)
                t.model:SetSize(fs, fs)
                -- Lower on the map (bigger bottom row): in front.
                local lv = self:Depth(e.y + e.size)
                if t.model:GetFrameLevel() ~= lv then t.model:SetFrameLevel(lv) end
                t.model:Ground(size, look)
                t.model:SetDepth(self:DepthAt(e.y + e.size, RADIUS[look.file] or 30))
                t.model:Use(look.file, look.facing)
                Place(t.model, self.view, px + size / 2, py + size / 2)
                t.model:SetAlpha(alpha)
                t.model:Show()
                t.art:Hide()
            else
                t.art:SetTexture(ArtOf(e.type))
                t.art:SetSize(size + 4, size + 4)
                Place(t.art, self.view, px + size / 2, py + size / 2)
                t.art:SetAlpha(alpha)
                t.art:Show()
            end
            t.sel:SetShown(selected[id] == true)
            t.sel:SetSize(size * 1.3, size * 0.9)
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
        if t.model then t.model:Hide() end
        if t.shadow then t.shadow:Hide() end
    end
    -- Units.
    local seen = {}
    local now = Now()
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and self:Sees(e) then
            local dot = self.mmDots:Get()
            local col = TEAM[e.owner]
            dot:SetColorTexture(col[1], col[2], col[3], 1)
            dot:SetSize(MM_SCALE + 1, MM_SCALE + 1)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", self.mm, "TOPLEFT", e.x * MM_SCALE, -e.y * MM_SCALE)
            local px, py = e.x * TILE - cx, e.y * TILE - cy
            if not e.inside and not e.insideBuild and px > -30 and px < BW + 30 and py > -10 and py < VIEW_H + 50 then
                seen[id] = true
                local look = (e.buffs and e.buffs.hex) and "sheep" or e.type
                local f = self:UnitFrame(id, look)
                f:Show()
                f:SetAlpha((e.illusion or (e.buffs and e.buffs.windwalk)) and 0.55 or 1)
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
                local air = WC().Units[e.type] and WC().Units[e.type].air
                local lift = air and (30 + math.sin(now * 2 + id) * 3) or 0
                f:SetPoint("CENTER", self.view, "TOPLEFT", px, -(py - lift))
                if f.shadow then
                    f.shadow:ClearAllPoints()
                    f.shadow:SetPoint("CENTER", f, "CENTER", 0, -6 - lift)
                end
                local lv = self:Depth(e.y)
                if f.depth ~= lv then
                    f.depth = lv
                    f:SetFrameLevel(lv)
                    if f.model then f.model:SetFrameLevel(lv + 1) end
                    if f.top then f.top:SetFrameLevel(lv + 3) end
                end
                -- Always the model (the panels above the map hide anything poking out).
                local m = f.model
                local disp = m and (m.fileId or Looks()[m.npc])
                if m and not disp then self:Probe(m.npc) end
                if m and disp then
                    if not m:IsShown() then m:Show() end
                    if m.fileId then m:UseFile(m.fileId) else m:UseCreature(disp) end
                    m:SetDepth(self:DepthAt(e.y, RADIUS.unit or 3))
                    f.icon:SetShown(not m.loaded)
                    f.ring:SetShown(not m.loaded)
                    -- Its look: the unit's size, then what its buffs do.
                    local ud = WC().Units[e.type]
                    local k = UNIT_LOOK[look] or (ud and ud.hero and HERO_LOOK) or 1
                    local desat, speed, spin, alpha = 0, 1, false, nil
                    for buff in pairs(e.buffs or {}) do
                        local L = BUFF_LOOK[buff]
                        if L then
                            k = k * (L.scale or 1)
                            desat = math.max(desat, L.desat or 0)
                            speed = speed * (L.speed or 1)
                            spin = spin or L.spin
                            alpha = L.alpha or alpha
                        end
                    end
                    m:SetLook(k, desat)
                    if alpha then f:SetAlpha(alpha) end
                    -- Bladestorm: spinning round with the blade out.
                    m:SetFacing(spin and (now * 14) or (e.facing or math.pi / 2))
                    -- Walking: it moved within the last few engine steps (frames come
                    -- faster than steps, so a per-frame check would flicker).
                    local moved = e.walkT and st.time - e.walkT < 0.16
                    local anim = spin and ANIM.attack or AnimFor(e, moved)
                    if air and anim ~= ANIM.attack and m:HasAnimation(ANIM.fly) then anim = ANIM.fly end
                    if (m.anim ~= anim or m.speed ~= speed) and m.SetAnimation then
                        m:SetAnimation(anim, speed)
                        m.anim, m.speed = anim, speed
                    end
                else
                    if m then m:Hide() end
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
    local _, upkeep = E().Upkeep(self.st, ME)
    self.foodText:SetText(pl.food .. "/" .. pl.foodCap .. (upkeep and ("  |cffffd100" .. (upkeep == "high" and "High" or "Low")
        .. " upkeep|r") or ""))
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
        self.selName:SetText(d.name .. (first.level and (" (level " .. first.level .. ")") or "")
            .. (first.illusion and " (image)" or first.summon and " (summoned)" or ""))
        if first.kind == "mine" then
            self.selHp:SetText("Gold left: " .. (first.gold or 0))
        else
            local text = string.format("%d / %d", math.max(0, math.floor(first.hp)), first.maxHp)
            if first.maxMana and first.maxMana > 0 then
                text = text .. string.format("   |cff6fa8ffMana %d / %d|r", math.floor(first.mana), first.maxMana)
            end
            self.selHp:SetText(text)
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
            if o and o.type == "cast" then status = "Casting " .. WC().Abilities[o.ability].name end
            if first.level and not first.illusion then
                local need = WC().XP_LEVELS[first.level]
                status = (need and string.format("XP %d / %d. ", first.xp, need) or "Top level. ")
                    .. ((first.points or 0) > 0 and ("|cff40ff40" .. first.points .. " skill point" .. (first.points > 1 and "s" or "") .. " (O)|r. ") or "")
                    .. status
            end
            local fx = {}
            for name, label in pairs({ stun = "Stunned", invuln = "Invulnerable", slow = "Slowed", hex = "Hexed",
                noAttack = "Banished", windwalk = "Invisible", avatar = "Avatar", bladestorm = "Bladestorm",
                reinc = "Reincarnating" }) do
                if first.buffs and first.buffs[name] then table.insert(fx, label) end
            end
            table.sort(fx)
            if #fx > 0 then status = status .. "  |cffffd100" .. table.concat(fx, ", ") .. "|r" end
            if first.expire then status = status .. string.format("  (%d s left)", math.ceil(first.expire - self.st.time)) end
        elseif first.kind == "building" then
            if first.garrison and first.progress >= 1 then
                status = "Peons inside: " .. #first.garrison .. "/" .. E().Def(first).garrison
            end
            if first.progress < 1 then
                status = string.format("Under construction: %d%%", math.floor(first.progress * 100))
                if first.paused then status = status .. " (paused: right-click it with a worker to carry on)" end
            elseif first.queue[1] then
                local d, time, key, level = E().QueueItem(self.st, first, first.queue[1])
                local what = key and (d.names and d.names[level] or d.name) or d.name
                status = string.format("%s %s: %d%%", key and "Researching" or "Training", what,
                    math.floor(first.trainT / time * 100))
                for i, q in ipairs(first.queue) do
                    local qd = E().QueueItem(self.st, first, q)
                    self.queueButtons[i].icon:SetTexture(qd.icon)
                    self.queueButtons[i]:SetShown(first.owner == ME)
                end
            elseif first.owner == ME and E().Def(first).trains then
                status = "Right-click the map to set a rally point."
            end
        end
        if first.owner ~= ME and first.owner > 0 then status = "Enemy" end
        self.selStatus:SetText(status)
    end
    local bagHero = sel[1] and sel[1].owner == ME and E().IsHero(sel[1]) and not sel[1].illusion and sel[1]
    for i, b in ipairs(self.itemButtons) do
        local key = bagHero and bagHero.items and bagHero.items[i]
        b:SetShown(bagHero ~= nil and bagHero ~= false)
        b.hero, b.item = bagHero and bagHero.id, key
        b.icon:SetTexture(key and WC().Items[key].icon or nil)
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
    local hero
    for _, e in ipairs(mine) do
        if E().IsHero(e) and not e.illusion then hero = e break end
    end
    if not hasWorker and self.menu == "build" then self.menu = nil end
    if not hero and self.menu == "learn" then self.menu = nil end
    local function Cost(c) return c[1] .. " gold" .. (c[2] > 0 and (", " .. c[2] .. " lumber") or "") end
    local function Add(item) table.insert(list, item) end
    local A = WC().Abilities
    if hero and self.menu == "learn" then
        -- Spend a skill point.
        for _, key in ipairs(WC().Units[hero.type].abilities) do
            local a = A[key]
            local lv = E().Skill(hero, key) + 1
            local top = a.ult and 1 or 3
            local need = a.ult and 6 or (lv * 2 - 1)
            local can = (hero.points or 0) > 0 and lv <= top and hero.level >= need
            local amount = a.amount and (a.amount[math.min(lv, #a.amount)]) or (a.duration and a.duration[math.min(lv, #a.duration)])
                or (a.count and a.count[math.min(lv, #a.count)]) or (a.mult and a.mult[math.min(lv, #a.mult)])
                or (a.chance and a.chance[math.min(lv, #a.chance)]) or (a.radius and type(a.radius) == "table" and a.radius[1]) or 0
            local tip = string.format(a.text or "", amount)
            if lv > top then tip = "|cff40ff40Fully learned.|r " .. tip
            elseif hero.level < need then tip = "|cffff6060Needs hero level " .. need .. ".|r " .. tip
            else tip = string.format("Level %d of %d. ", lv, top) .. tip end
            Add({ icon = a.icon, key = a.hotkey, title = "Learn " .. a.name .. " (" .. a.hotkey .. ")", tip = tip,
                enabled = can, action = function()
                    self:Cmd({ type = "learn", unit = hero.id, ability = key })
                    if (hero.points or 0) <= 1 then self.menu = nil end
                end })
        end
        list[12] = { icon = IC .. "Spell_ChargeNegative", key = nil, title = "Back", tip = "Back to the commands.",
            action = function() self.menu = nil end }
    elseif hasWorker and self.menu == "build" then
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
            local miss = E().Missing(st, ME, bd.requires)
            if miss then tip = "|cffff6060Requires " .. miss .. ".|r " .. tip end
            Add({ icon = bd.icon, key = bd.hotkey, title = "Build " .. bd.name .. " (" .. bd.hotkey .. ")", tip = tip,
                cost = bd.cost, enabled = miss == nil, action = function() self.menu = nil self:StartPlace(bt) end })
        end
        list[12] = { icon = IC .. "Spell_ChargeNegative", key = nil, title = "Back", tip = "Back to the commands (or right-click).",
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
        if hero and (hero.points or 0) > 0 then
            -- Like Warcraft III's "+": skill points to spend.
            list[5] = { icon = IC .. "Spell_Holy_Heal02", key = "O", title = "Hero Abilities (O)",
                tip = "|cff40ff40" .. hero.points .. " skill point" .. (hero.points > 1 and "s" or "") .. " to spend.|r Learn or improve an ability.",
                action = function() self.menu = "learn" end }
        end
        if hero then
            for slot, key in ipairs(WC().Units[hero.type].abilities) do
                local a = A[key]
                local lv = E().Skill(hero, key)
                local mana = a.mana and (a.mana[lv] or a.mana[#a.mana]) or 0
                local tip
                if lv == 0 then
                    tip = "|cffaaaaaaNot learned yet.|r"
                else
                    local amount = a.amount and (a.amount[math.min(lv, #a.amount)]) or (a.duration and a.duration[math.min(lv, #a.duration)])
                        or (a.count and a.count[math.min(lv, #a.count)]) or (a.mult and a.mult[math.min(lv, #a.mult)])
                        or (a.chance and a.chance[math.min(lv, #a.chance)]) or (a.radius and type(a.radius) == "table" and a.radius[lv]) or 0
                    tip = string.format("Level %d. ", lv) .. string.format(a.text or "", amount)
                    if a.passive then
                        tip = tip .. " |cffaaaaaa(Works by itself.)|r"
                    else
                        tip = tip .. string.format(" %d mana.", mana)
                        local cd = hero.cds and hero.cds[key]
                        if cd then tip = tip .. string.format(" |cffff6060Ready in %d s.|r", math.ceil(cd)) end
                    end
                end
                local ready = lv > 0 and not a.passive and not (hero.cds and hero.cds[key]) and (hero.mana or 0) >= mana
                list[8 + slot] = { icon = a.icon, key = (not a.passive and lv > 0) and a.hotkey or nil,
                    title = a.name .. ((not a.passive and lv > 0) and (" (" .. a.hotkey .. ")") or ""), tip = tip,
                    enabled = ready, action = function() self:CastAbility(hero, key) end }
            end
        end
        if hasWorker then
            while #list < 4 do table.insert(list, false) end
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
            local fallen = st.players[ME].fallen and st.players[ME].fallen[ut]
            local miss = E().Missing(st, ME, ud.requires)
            if ud.hero and not miss then
                local ok, why = E().CanTrainHero(st, ME, ut)
                if not ok and not fallen then miss = why:gsub("^requires ", "") end
            end
            if fallen then
                local cost = E().ReviveCost(st, ME, ut)
                Add({ icon = ud.icon, key = ud.hotkey, title = "Revive " .. ud.name .. " (" .. ud.hotkey .. ")", cost = cost,
                    tip = string.format("%s. Back at level %d with all its skills.", Cost(cost), fallen.level),
                    enabled = not fallen.reviving, action = function() self:Revive(ut) end })
            else
            local tip = string.format("%s, %d food. %d health, %d damage%s.", Cost(ud.cost), ud.food,
                E().MaxHp(st, ME, ut), ud.damage, ud.range > 1.5 and ", ranged" or "")
            if miss then tip = "|cffff6060Requires " .. miss .. ".|r " .. tip end
            if ud.hero then
                tip = string.format("%s, %d food. A hero: gains levels, learns four abilities (the last at level 6).",
                    Cost(ud.cost), ud.food)
                if miss then tip = "|cffff6060" .. miss:sub(1, 1):upper() .. miss:sub(2) .. ".|r " .. tip end
            end
            Add({ icon = ud.icon, key = ud.hotkey, title = "Train " .. ud.name .. " (" .. ud.hotkey .. ")", cost = ud.cost,
                tip = tip, enabled = miss == nil, action = function() self:Train(ut) end })
            end
        end
        -- A shop: items for the hero standing next to it.
        if E().Def(b).sells then
            local cx, cy = E().Center(b)
            local buyer
            for _, id in ipairs(st.list) do
                local e = st.ents[id]
                if e and e.owner == ME and E().IsHero(e) and not e.illusion
                    and (e.x - cx) ^ 2 + (e.y - cy) ^ 2 <= WC().SHOP_RANGE ^ 2 then buyer = e break end
            end
            for _, key in ipairs(E().Def(b).sells) do
                local it = WC().Items[key]
                local hk = WC().ITEM_KEYS[key]
                local tip = it.cost .. " gold. " .. it.text
                if not buyer then tip = "|cffff6060Bring a hero next to the shop.|r " .. tip end
                Add({ icon = it.icon, key = hk, title = "Buy " .. it.name .. " (" .. hk .. ")", cost = { it.cost, 0 }, tip = tip,
                    enabled = buyer ~= nil, action = function()
                        local ok, why = self:Cmd({ type = "buy", building = b.id, unit = buyer.id, item = key })
                        if not ok and why then self:Say(why:sub(1, 1):upper() .. why:sub(2)) end
                    end })
            end
        end
        -- Research and upgrades done here.
        for _, key in ipairs(WC().AI.RESEARCH) do
            local r = WC().Research[key]
            local level = E().Level(st, ME, key) + 1
            if r.building == b.type and level <= (r.levels or 1) then
                local name = r.names and r.names[level] or r.name
                local ok, why = E().CanResearch(st, ME, key, b)
                local tip = Cost(r.cost[level]) .. ". " .. (r.text or "")
                if (r.levels or 1) > 1 then tip = tip .. string.format(" (level %d of %d)", level, r.levels) end
                if not ok then tip = "|cffff6060" .. why:sub(1, 1):upper() .. why:sub(2) .. ".|r " .. tip end
                Add({ icon = r.icon, key = r.hotkey, title = name .. " (" .. r.hotkey .. ")", cost = r.cost[level],
                    tip = tip, enabled = ok, action = function() self:Research(key) end })
            end
        end
        local fac = WC().Factions[st.players[ME].faction]
        if E().Def(b).hall or (E().Def(b).garrison and fac.alarm == "battleStations") then
            if fac.alarm == "callToArms" then
                list[9] = { icon = IC .. "Ability_Warrior_BattleShout", key = "C", title = "Call to Arms (C)",
                    tip = "Ring the alarm: peasants nearby run to the hall and fight as Militia for 45 seconds.",
                    action = function() self:Alarm() end }
            else
                list[9] = { icon = IC .. "Ability_Warrior_BattleShout", key = "B", title = "Battle Stations (B)",
                    tip = "Peons nearby run into the burrows (4 each); burrows with peons attack enemies.",
                    action = function() self:Alarm() end }
            end
            list[10] = { icon = IC .. "INV_Pick_02", key = "W", title = "Back to Work (W)",
                tip = "Everyone called to arms goes back to work.", action = function()
                    self:Cmd({ type = "backToWork" })
                end }
        end
        if E().Def(b).trains then
            list[12] = { icon = IC .. "INV_BannerPVP_02", key = "Y", title = "Set Rally Point (Y)",
                tip = "Then click: where new units go. On the gold mine or a tree, new workers start gathering.",
                action = function() self:Target("rally", "Click where new units should go") end }
        end
    end
    -- Cancel: a building going up, an upgrade, or the last unit in training.
    local sb = #mine == 1 and mine[1].kind == "building" and mine[1]
    if sb and sb.progress < 1 then
        list = {}
        list[12] = { icon = IC .. "Spell_ChargeNegative", title = "Cancel", tip = "Stop building it. You get 75% of the cost back.",
            action = function() self:Cmd({ type = "cancelBuild", building = sb.id }) end }
    elseif sb and #sb.queue > 0 then
        local last = E().QueueItem(st, sb, sb.queue[#sb.queue])
        list[11] = { icon = IC .. "Spell_ChargeNegative", title = "Cancel",
            tip = "Cancel the last one in the queue" .. (last and last.name and (" (" .. last.name .. ")") or "")
                .. ". You get the cost back.", action = function() self:CancelTrain() end }
    end
    for i, c in ipairs(self.cmds) do
        local item = list[i] or nil
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
    local s = ns.Session.Get(self.kind)
    if s or self.setupOpen or self.pvp then return self:RefreshPvp(s) end
    if self.st and self.st.over and not self.overlay:IsShown() then self:GameOver() end
    -- Back on the tab after switching away: carry on.
    if self.autoPaused and self.st and not self.st.over and not self.overlay:IsShown() and self.game:IsVisible() then
        self.autoPaused = false
        self:Resume()
    end
    self:Draw()
end

---------------------------------------------------------------------------
-- PvP (a Session lobby for the setup, then lockstep: Core\Lockstep.lua)
---------------------------------------------------------------------------
local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end

---------------------------------------------------------------------------
-- Sound (Games/Warcraft/Sounds.lua): voices, combat, spells, warnings.
---------------------------------------------------------------------------

-- A unit says something: what (selected), yes, attack, ready, pissed, done.
function P:Voice(e, kind)
    local v = e and Snd() and Snd().Voices[e.type]
    if not v then return end
    -- Clicked again and again: it gets annoyed (Warcraft III).
    if kind == "what" then
        local c = self.clicks
        if c and c.id == e.id and Now() - c.t < 2 then c.n, c.t = c.n + 1, Now() else c = { id = e.id, n = 1, t = Now() } end
        self.clicks = c
        if c.n >= 4 and v.pissed then
            local i = (c.n - 4) % #v.pissed + 1
            return W.PlayFile(v.pissed[i], "voice")
        end
    end
    local list = v[kind] or v.yes or v.what
    if list then W.PlayFile(list, "voice") end
end

-- Units you ordered acknowledge (one voice, not one per unit).
function P:Acknowledge(cmd)
    if self.lastAck and Now() - self.lastAck < 0.3 then return end
    local t = cmd.type
    local kind = (t == "attack" or t == "attackMove") and "attack"
        or ((t == "move" or t == "gather" or t == "build" or t == "resumeBuild" or t == "returnRes" or t == "hold"
            or t == "stop" or t == "patrol") and "yes") or nil
    if not kind then return end
    local id = cmd.unit or (cmd.units and cmd.units[1])
    local e = id and self.st.ents[id]
    if e and e.owner == ME then
        self.lastAck = Now()
        self:Voice(e, kind)
    end
end

-- Is this spot on screen (and in sight)? Sounds only for what you'd see.
function P:OnScreen(x, y)
    local px, py = x * TILE - self.camX, y * TILE - self.camY
    return px > -40 and px < BW + 40 and py > -40 and py < VIEW_H + 40
end

function P:Sounds(events)
    local S = Snd()
    if not S then return end
    local st = self.st
    self.sndN, self.sndT = self.sndN or 0, self.sndT or 0
    if Now() - self.sndT > 0.25 then self.sndN, self.sndT = 0, Now() end
    local function Room() -- at most a few at once
        if self.sndN >= 3 then return false end
        self.sndN = self.sndN + 1
        return true
    end
    for _, ev in ipairs(events) do
        local k = ev.kind
        if k == "hit" then
            local a, t = st.ents[ev.id], st.ents[ev.target]
            if t and t.owner == ME and (not self.alarmT or Now() - self.alarmT > 20) and not self:OnScreen(t.x, t.y) then
                self.alarmT = Now()
                W.PlayFile(S.UnderAttack, "alert")
                self:Say(t.kind == "unit" and "Our forces are under attack!" or "Our base is under attack!")
            end
            if a and t and self:OnScreen(t.x, t.y) and self:Sees(t) and Room() then
                local ud = WC().Units[a.type]
                local at = (ud and ud.attackType) or "normal"
                local list = S.Hit.normal
                if a.kind ~= "unit" then list = S.Hit.gun
                elseif at == "siege" then list = S.Hit.siege
                elseif at == "magic" then list = S.Hit.magic
                elseif ev.ranged then list = S.GUNS[a.type] and S.Hit.gun or S.Hit.pierce
                elseif t.kind ~= "unit" then list = S.Hit.building end
                local v = S.Voices[a.type]
                if v and v.hit and math.random() < 0.3 then list = v.hit end
                W.PlayFile(list, "game")
            end
        elseif k == "death" then
            local f = self.unitFrames[ev.id]
            if ev.what == "building" then
                W.PlayFile(S.Collapse, "game")
            elseif f and Room() then
                local v = S.Voices[ev.type]
                if v and v.death then W.PlayFile(v.death, "game") end
            end
        elseif k == "cast" then
            local caster = st.ents[ev.id]
            local id = S.Spells[ev.ability]
            if id and caster and (caster.owner == ME or self:OnScreen(caster.x, caster.y)) then W.PlayFile(id, "game") end
        elseif k == "trained" and ev.owner == ME then
            self:Voice({ type = ev.type, id = ev.id }, "ready")
        elseif k == "revived" and ev.owner == ME then
            self:Voice({ type = ev.type, id = ev.id }, "ready")
        elseif k == "built" and ev.owner == ME then
            local w = Snd().Voices[WC().Factions[st.players[ME].faction].worker]
            if w and w.done then W.PlayFile(w.done, "voice") end
        elseif k == "levelUp" and ev.owner == ME then
            W.PlayFile(S.LevelUp, "game")
        end
    end
end

-- A command from your clicks. In PvP it's checked on a copy of the game (so
-- you hear "not enough gold" at once) and runs in a later turn on both sides.
function P:Cmd(cmd)
    local ok, why
    if not self.ls then
        ok, why = E().Command(self.st, ME, cmd)
    else
        ok, why = E().Command(Copy(self.st), ME, cmd)
        if ok then self.ls:Command(cmd) end
    end
    if ok then self:Acknowledge(cmd) end
    return ok, why
end

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

function P:PvpScreen(title, sub, lobby, keys)
    self:Pause()
    self.overlay:Show()
    for _, p in ipairs(self.picks) do p:Hide() end
    self.diffLabel:Hide()
    for _, b in ipairs(self.diffButtons) do b:Hide() end
    for _, b in ipairs({ self.againButton, self.resumeButton, self.backButton }) do b:Hide() end
    self.mainMenu:Hide()
    self.overTitle:SetText(title)
    self.overTitle:SetTextColor(1, 0.82, 0)
    self.overSub:SetText(sub or "")
    self.lobbyText:SetText(lobby or "")
    self:PvpButtons(keys or {})
end

-- Find an opponent: into the realm queue with this race.
function P:StartQueue(faction)
    local ok, why = ns.Queue.Join(self.kind)
    if not ok then
        self.overSub:SetText("|cffff6060" .. tostring(why) .. "|r")
        return
    end
    self.queueRace = faction
    self:QueueScreen()
end

function P:QueueScreen()
    local t = ns.Queue.Since(self.kind)
    local partner = ns.Queue.Partner(self.kind)
    local others = ns.Queue.Others(self.kind)
    self:PvpScreen("Finding Opponent...", WC().Factions[self.queueRace or "human"].name,
        string.format("Searching %d:%02d", math.floor(t / 60), math.floor(t % 60)) .. "\n"
            .. (partner and ("Found " .. partner .. ", setting up the game...")
                or (others > 0 and (others .. (others == 1 and " other player" or " other players") .. " looking on your realm"))
                or "Nobody else is looking right now. Keep the window open, or ask a friend!"), { "cancelQueue" })
end

function P:CancelQueue()
    ns.Queue.Leave(self.kind)
    self.queueRace, self.mode = nil, nil
    self:ShowMenu()
end

-- The PvP game starts on this client: same seed and races on both sides.
function P:StartPvp(s)
    local me = ns.Me()
    local seat = self.G.Seat(s, me) or 1
    ME = seat
    CPU = s.test and (3 - seat) or nil -- practice: the computer plays the bot
    local factions = { s.races[s.players[1].name], s.races[s.players[2].name] }
    self.groups, self.lastClick, self.lastGroup = {}, nil, nil
    self.explored, self.vis, self.known, self.fogAt = {}, {}, {}, 0
    self.st = E().New({ factions = factions, seed = s.seed, difficulty = "normal" })
    self.sel, self.place, self.targeting = {}, nil, nil
    self.counted, self.reported, self.pvpGame = false, false, s.recordId
    self.acc, self.think = 0, 0
    self.treeDirty = true
    self:BuildMinimapTrees()
    self:CenterOn(E().Hall(self.st, ME))
    if not s.test then
        local other = s.players[3 - seat].name
        local st = self.st
        self.ls = ns.Lockstep.New({ id = s.recordId, seat = seat, peer = other,
            hash = function() return E().Hash(st) end })
        self.pvpStart = Now()
    end
    self.claim:Hide()
    self:Resume()
    self:Say("You play " .. WC().Factions[factions[seat]].name .. ". Destroy every enemy building!")
end

-- Every frame (even with the window closed): run the turns both sides have.
function P:LockstepTick(elapsed)
    local st, ls = self.st, self.ls
    if not st or st.over then return end
    elapsed = math.min(elapsed or 0, 0.25)
    ls:Update(Now())
    local TURN = ns.Lockstep.TURN
    self.acc = math.min(self.acc + elapsed, TURN * 4)
    while self.acc >= TURN and ls:CanRun() do
        self.acc = self.acc - TURN
        ls:Run(function(bySeat)
            for seat = 1, 2 do
                for _, c in ipairs(bySeat[seat] or {}) do E().Command(st, seat, c) end
            end
            for _ = 1, math.floor(TURN / STEP + 0.5) do
                self:Events(E().Step(st, STEP))
                if st.over then break end
            end
        end)
        if st.over then break end
    end
    if ls.desync and not self.reported then
        self.reported = true
        ns.Session.Act(self.kind, "desync")
    end
    if st.over then return self:PvpGameEnded() end
    -- Stuck waiting for the other player?
    local waiting = not ls:CanRun() and self.acc >= TURN
    local silence = ls:Silence(Now()) or (Now() - (self.pvpStart or Now()))
    if waiting and silence > 2 then
        local s = ns.Session.Get(self.kind)
        local other = s and s.players[3 - ME] and s.players[3 - ME].name or "the other player"
        self.status:SetText("Waiting for " .. other .. "... (" .. math.floor(silence) .. "s)")
        self.sayUntil = Now() + 0.5
        self.claim:SetShown(silence > 45)
    else
        self.claim:Hide()
    end
end

-- The other player has been gone a long time: the game is yours.
function P:ClaimVictory()
    local s = ns.Session.Get(self.kind)
    if not s then return end
    local other = s.players[3 - ME]
    -- Their surrender, on their behalf: the host records it; a guest asks the host.
    ns.Session.Act(self.kind, "won:" .. ME)
    self.claim:Hide()
end

function P:PvpGameEnded()
    if not self.reported then
        self.reported = true
        if self.st.winner and self.st.winner > 0 then ns.Session.Act(self.kind, "won:" .. self.st.winner) end
    end
    self:Refresh()
end

function P:LeavePvp()
    if self.ls then ns.Lockstep.Stop(self.ls) end
    self.ls, self.pvp, self.pvpGame, self.setupOpen = nil, nil, nil, false
    self.surrender:Hide()
    self.claim:Hide()
    ME, CPU = 1, 2
    local saved = Save().game
    self.st = (saved and saved.players and not saved.over) and saved or nil
    if self.st then self:CenterOn(E().Hall(self.st, ME)) self.treeDirty = true self:BuildMinimapTrees() end
    self.mode = nil
    self:ShowMenu()
end

function P:RefreshPvp(s)
    local S, me = ns.Session, ns.Me()
    if not s then
        if self.pvp then self:LeavePvp() end
        if ns.Queue.IsQueued(self.kind) then
            self.setup:Hide()
            self.game:Show()
            return self:QueueScreen()
        end
        self.setup:SetShown(self.setupOpen)
        self.game:SetShown(not self.setupOpen)
        if self.setupOpen then A.RefreshSetup(self) end
        return
    end
    self.setupOpen = false
    self.setup:Hide()
    self.game:Show()
    -- Our own queue lobby, nobody in it yet: still looking.
    if s.phase == "lobby" and s.queued and #s.players < 2 and ns.Queue.IsQueued(self.kind) then
        self.pvp = nil
        return self:QueueScreen()
    end
    self.pvp = true
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local names = {}
    for _, p in ipairs(s.players) do table.insert(names, p.name .. (p.name == s.host and " (host)" or "")) end
    local who = "Players: " .. table.concat(names, ", ")
    self.surrender:SetShown(s.phase == "rolling" and s.stage == "play" and seated and not s.test)

    if s.phase == "lobby" then
        if s.queued and #s.players >= 2 then
            return self:PvpScreen("Opponent found!", "Getting the game ready...", who, {})
        end
        local keys = {}
        if host then
            if s.test and S.CanAddBot(s) then table.insert(keys, "bot") end
            table.insert(keys, "start")
            table.insert(keys, "close")
        elseif seated then
            table.insert(keys, "leave")
        end
        self:PvpScreen("Warcraft III: lobby", A.ScopeLine(s), who .. "\n\n"
            .. (#s.players < 2 and "Waiting for an opponent..." or (host and "Start when you're ready." or "Waiting for the host to start.")),
            keys)
        self.pvpButtons.start:SetEnabled(#s.players >= 2)
        return
    elseif s.phase == "cancelled" then
        return self:PvpScreen("The lobby is closed", s.banner or "", "", { "done" })
    end

    if s.stage == "races" then
        if seated and not s.races[me] then
            if self.queueRace then
                local f = self.queueRace
                self.queueRace = nil
                S.Act(self.kind, "race:" .. f)
                return
            end
            if self.screen ~= "races" then
                self.screen = "races"
                self:ShowStart()
            end
        else
            self.screen = nil
            local waiting = {}
            for _, p in ipairs(s.players) do
                if not s.races[p.name] then table.insert(waiting, p.name) end
            end
            self:PvpScreen("Ready", "Waiting for " .. table.concat(waiting, ", ") .. " to choose a race...", who,
                host and { "close" } or { "leave" })
        end
        return
    end
    self.screen = nil

    if s.stage == "play" and s.recordId ~= self.pvpGame and seated then
        self:StartPvp(s)
    end
    if s.phase == "done" then
        if self.ls then ns.Lockstep.Stop(self.ls) self.ls = nil end
        self.surrender:Hide()
        self.claim:Hide()
        local won = s.result and s.result.winner == me
        local draw = s.result and not s.result.winner
        if not self.counted and not s.test and seated then
            self.counted = true
            local rec = Save()
            rec.pvpWins, rec.pvpLosses = rec.pvpWins or 0, rec.pvpLosses or 0
            if won then
                rec.pvpWins = rec.pvpWins + 1
                ns.Scores.Submit("warcraftpvp", rec.pvpWins)
            elseif not draw then
                rec.pvpLosses = rec.pvpLosses + 1
            end
            W.PlaySound(won and "LEVELUP" or "RAID_WARNING")
        end
        local rec = Save()
        local score = {}
        for _, p in ipairs(s.players) do table.insert(score, p.name .. " " .. ((s.score and s.score[p.name]) or 0)) end
        self:PvpScreen(won and "Victory!" or (draw and "No winner" or "Defeat"), s.banner or "",
            "Score: " .. table.concat(score, "  -  ") .. string.format("\nYour PvP record: %d wins, %d losses.",
                rec.pvpWins or 0, rec.pvpLosses or 0), host and { "rematch", "close" } or { "leave" })
        self.overTitle:SetTextColor(won and 1 or 0.9, won and 0.82 or 0.3, won and 0 or 0.3)
    end
end

function P:FlashRoll() end

-- A gallery of candidate world models (/wcgallery), numbered, to pick
-- which one each building should use.
local GALLERY = {
    { 189620, "goldmine" }, { 189629, "humanguardtower" }, { 189632, "humanwatchtower" },
    { 189288, "abandonedhumanguardtower" }, { 189601, "blacksmith" }, { 189611, "distillery" },
    { 189445, "barnduskwood" }, { 190505, "westfallchurch" }, { 190508, "westfallgrainsilo01" },
    { 190517, "westfallshed" }, { 190519, "westfallwindmill" }, { 197108, "humantentlarge" },
    { 197109, "humantentmedium" }, { 194961, "hu_tent01" }, { 242691, "duskwood_human_farm_closed" },
    { 242696, "redridge_human_farm_closed" }, { 190060, "karazahn_rrh_house" }, { 189375, "gypsywagon" },
    { 190599, "westfallhaywagon" }, { 189810, "haystack01" }, { 189200, "orctent (burning steppes)" },
    { 199384, "durotarorctent01" }, { 199385, "durotarorctent02" }, { 199387, "orctent01" },
    { 199389, "orctent02" }, { 353154, "orctent03" }, { 353155, "orctent04" },
    { 190175, "trollwatchtower" }, { 189359, "gnolltent02" }, { 189361, "gnolltent03" },
    { 190408, "losttreehuts01" }, { 190430, "waterhut01" }, { 191492, "ogrila_hut" },
    { 192682, "om_tent_01 (ogre)" }, { 192683, "om_tent_02 (ogre)" }, { 192684, "om_tent_03 (ogre)" },
    { 191824, "ao_windmill (ancient orc)" }, { 199134, "orcpvpbonfirelarge" }, { 189118, "orcbonfire" },
    { 192542, "dr_tent_01 (draenei)" }, { 192252, "be_tent01 (blood elf)" }, { 189923, "elwynnfirtree01" },
    { 242692, "duskwood_lumbermill" }, { 242697, "redridge_lumbermill" }, { 203656, "arathifarmhouse01" },
    { 203657, "arathifarmhouse02" }, { 204144, "tirisfallwindmill" }, { 200566, "taurenwindmilla" },
    { 200567, "taurenwindmillb" }, { 198459, "shack" }, { 197835, "generalaltar01" },
    { 197831, "altar01" }, { 197832, "altar02" }, { 189141, "lavaaltar" },
    { 201982, "nightelfguardtower" }, { 203634, "alteracwatertower" }, { 202687, "tanariswatertower" },
    { 201389, "raptorhut01" }, { 201390, "raptorhut02" }, { 200332, "quillboar_hut01" },
    { 197120, "centaurtent01" }, { 197121, "centaurtent02" }, { 202016, "furbolgtent" },
    { 197791, "goblintent01" }, { 197793, "goblintent03" }, { 197795, "goblintent05" },
    { 200577, "taurentotem01" }, { 200580, "taurentotem04" }, { 200583, "taurentotem07" },
    { 191823, "ao_totem01 (ancient orc)" }, { 192666, "om_forge_01 (ogre)" }, { 192363, "dr_forge_01 (draenei)" },
    { 192030, "be_forge (blood elf)" }, { 195006, "id_forge (iron dwarf)" }, { 243047, "dalaran_forge" },
    { 197395, "forgebonfire (dwarf)" }, { 255405, "fb_loghouse_darkshore_01" }, { 194711, "fb_loghouse_gh_01" },
    { 196220, "oracle_hut01" }, { 192645, "nagapagodahut01" }, { 194857, "fk_tent01 (forsaken)" },
    { 195139, "sc_tent1 (scourge)" }, { 197388, "excavationtent01" }, { 197383, "excavationtentpavillion" },
    { 251634, "argentcrusade_opentent" }, { 243395, "he_tent_01 (high elf)" }, { 190409, "losttreehuts02" },
    { 190431, "waterhut02" }, { 200353, "satyrtent01" }, { 189170, "lavashrine01" },
    { 201267, "neshrine (night elf)" }, { 194797, "guardtower_intact_fade" }, { 190153, "holdingpen" },
    { 198389, "peasantlumber01" }, { 198339, "deadminelumberpilelarge" }, { 194962, "hu_tent02" },
    { 192543, "dr_tent_02 (draenei)" }, { 192253, "be_tent02 (blood elf)" },
    -- 99+: more human and Elwynn-style buildings.
    { 242690, "duskwood_barn_closed" }, { 242695, "redridge_barn_closed" }, { 242693, "duskwood_stable" },
    { 242698, "redridge_stable" }, { 190511, "lighthousered" }, { 190515, "westfalllighthouse" },
    { 198261, "gryphonroost01" }, { 2016715, "kultiras_gryphonroost01" }, { 2016718, "kultiras_gryphonroost02" },
    { 1881269, "human_siegetower" }, { 1127093, "ashran alliance tower" }, { 975083, "garrison_guardshack" },
    { 219314, "humantanktower" }, { 2061082, "warfront magictower (human)" }, { 2065485, "warfront barn (human)" },
    { 1910329, "warfront barracks (orc)" }, { 2061081, "warfront magictower (orc)" }, { 368823, "stormwind_bank_gold" },
    { 381045, "stormwind auctionhouse01" }, { 452147, "stormwind_enchantingshop" }, { 452149, "stormwind_inscriptionshop" },
    { 452151, "stormwind_jewelcraftingshop" }, { 452153, "stormwind_miningshop" }, { 189641, "stormwindgate" },
    { 306203, "worgen_guardhouse_01" }, { 306223, "worgen_guardhouse_02" }, { 305999, "worgen_windmill_01" },
    { 306001, "worgen_windmill_02" }, { 304345, "worgen_stable_01" }, { 304422, "worgen_stable_02" },
    { 312267, "worgen_forge_01" }, { 2321274, "arathi windmill 01" }, { 2321275, "arathi windmill 02" },
    { 2321276, "arathi windmill 03" }, { 1709395, "kultiras_chickencoop" }, { 948466, "garrison_farm_well" },
    { 198672, "wreckedbuilding base01" }, { 198673, "wreckedbuilding base02" }, { 198674, "wreckedbuilding base03" },
    { 929365, "garrison blacksmith forge" }, { 1958817, "kultiras blacksmith forge" }, { 959598, "salvageyard forge" },
    -- 141+: more buildings (no bonfires or totems).
    { 1083858, "ashran alliance lumbershack" }, { 1083871, "ashran alliance towershack" }, { 1083857, "ashran alliance tenttown" },
    { 1083866, "ashran alliance tent" }, { 1850545, "human_tent01 (bfa)" }, { 1990244, "human_tent02 (bfa)" },
    { 1990237, "human_tent03 (bfa)" }, { 1634387, "kultiras_tent01" }, { 1634680, "kultiras_tent02" },
    { 1659553, "kultiras_tent03" }, { 942929, "garrison enchanting tent" }, { 950140, "garrison jewelcrafting tent" },
    { 951937, "garrison inscription tent" }, { 951944, "garrison tailoring tent" }, { 198621, "stormwind vendortent01" },
    { 384480, "stormwind vendortent02" }, { 194712, "loghouse_gh_02" }, { 194713, "loghouse_gh_03" },
    { 255406, "loghouse_darkshore_02" }, { 255407, "loghouse_darkshore_03" }, { 1501498, "karazhan opera house" },
    { 1676043, "witch_hut01" }, { 793024, "dalaran tower base" }, { 1121823, "night elf druid tower" },
    { 571929, "pandaren house woodframe" }, { 574603, "pandaren countryhouse" }, { 1080965, "draenor house set 1" },
    { 1080966, "draenor house set 2" }, { 1080967, "draenor house set 3" }, { 1080969, "draenor house set 4" },
    { 1080664, "draenor storagehut" }, { 1080668, "draenor fishinghut" }, { 1006258, "orc garrison guardshack" },
    { 1135244, "ashran horde tower" }, { 1083861, "ashran horde townhall entrance" }, { 1883494, "horde siegetower" },
    { 959163, "warsong_tent01" }, { 959686, "warsong_tent_grunt01" }, { 875065, "orcclans_tent01" },
    { 987012, "shadowmoon_tent01" }, { 1116048, "bleedinghollow_tent01" }, { 874687, "ironhorde_tent01" },
    { 878882, "ironhorde_tent02" }, { 999668, "ironhorde gunbunker" }, { 2322505, "warsong bg orctent01" },
    { 2322506, "warsong bg orctent02" }, { 660417, "orctent05" }, { 412262, "dragonmaw_orctent01" },
    { 1134449, "legion_barracks01" }, { 1266313, "legion_barrackssmall01" }, { 981084, "highmaul tower02" },
    { 981086, "highmaul tower03" }, { 309145, "goblin_guardtower_01" }, { 316229, "pygmy_guard_tower" },
    { 200660, "undercitytower01" }, { 200661, "undercitytower02" }, { 1091580, "murloc_hut01" },
    { 1811536, "quillboar_hut01 (bfa)" }, { 195726, "wolvar_hut01" }, { 376272, "earthen_building_01" },
    { 667816, "troll_tent_01" }, { 1608321, "blood troll tent01" }, { 2176404, "venture company tent" },
}
local COLS, ROWS = 6, 3

function P.Gallery()
    local g = P.galleryFrame
    if not g then
        g = W.TryCreate("Frame", "FunNGamesWcGallery", UIParent, "ButtonFrameTemplate", "BasicFrameTemplateWithInset")
        g:SetSize(780, 560)
        g:SetPoint("CENTER")
        g:SetFrameStrata("DIALOG")
        g:SetMovable(true)
        g:EnableMouse(true)
        g:RegisterForDrag("LeftButton")
        g:SetScript("OnDragStart", g.StartMoving)
        g:SetScript("OnDragStop", g.StopMovingOrSizing)
        W.SetTitle(g, "Warcraft III: building models")
        if W.SetPortrait then W.SetPortrait(g, ns.ICON) end
        tinsert(UISpecialFrames, "FunNGamesWcGallery")
        g.cells = {}
        for i = 1, COLS * ROWS do
            local c = CreateFrame("Frame", nil, g)
            c:SetSize(118, 140)
            c:SetPoint("TOPLEFT", 18 + ((i - 1) % COLS) * 124, -70 - math.floor((i - 1) / COLS) * 148)
            local bg = c:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.18, 0.28, 0.12, 1)
            c.scene = MakeDoodad(c)
            if c.scene then
                c.scene:SetPoint("TOPLEFT", 2, -2)
                c.scene:SetPoint("BOTTOMRIGHT", -2, 30)
            end
            c.num = W.BigLabel(c, 18, "GameFontNormalHuge")
            c.num:SetPoint("BOTTOMLEFT", 4, 12)
            c.name = W.Label(c, "", "GameFontHighlightSmall")
            c.name:SetPoint("BOTTOMLEFT", 4, 2)
            c.name:SetPoint("RIGHT", -2, 0)
            c.name:SetJustifyH("LEFT")
            c.name:SetWordWrap(false)
            g.cells[i] = c
        end
        g.pageText = W.Label(g, "", "GameFontHighlight")
        g.pageText:SetPoint("BOTTOM", 0, 14)
        g.prev = W.Button(g, "< Prev", 80, function() g.page = g.page - 1 P.GalleryDraw() end, 22)
        g.prev:SetPoint("RIGHT", g.pageText, "LEFT", -12, 0)
        g.next = W.Button(g, "Next >", 80, function() g.page = g.page + 1 P.GalleryDraw() end, 22)
        g.next:SetPoint("LEFT", g.pageText, "RIGHT", 12, 0)
        g.hint = W.Label(g, "Tell which number to use for each building.", "GameFontDisableSmall")
        g.hint:SetPoint("TOPLEFT", 70, -38)
        g.page = 1
        P.galleryFrame = g
    end
    g:Show()
    P.GalleryDraw()
end

function P.GalleryDraw()
    local g = P.galleryFrame
    local per = COLS * ROWS
    local pages = math.ceil(#GALLERY / per)
    g.page = math.max(1, math.min(g.page, pages))
    for i, c in ipairs(g.cells) do
        local n = (g.page - 1) * per + i
        local item = GALLERY[n]
        c:SetShown(item ~= nil)
        if item then
            c.num:SetText(tostring(n))
            c.name:SetText(item[2])
            if c.scene then c.scene:Use(item[1], 0.5) end
        end
    end
    g.pageText:SetText("Page " .. g.page .. " / " .. pages)
    g.prev:SetEnabled(g.page > 1)
    g.next:SetEnabled(g.page < pages)
end

SLASH_FNGWCGALLERY1 = "/wcgallery"
SlashCmdList.FNGWCGALLERY = function() P.Gallery() end

-- Tuning the world-model camera live: /wcview pitch 0.9 (or yaw, fov, margin).
SLASH_FNGWCVIEW1 = "/wcview"
SlashCmdList.FNGWCVIEW = function(msg)
    local key, value = (msg or ""):match("^(%a+)%s+([%-%d%.]+)")
    local view = ns.WC.ART.view
    if key and view[key] ~= nil then view[key] = tonumber(value) end
    ns.Print(string.format("Warcraft view: yaw %.2f, pitch %.2f, bpitch %.2f, fov %.2f, margin %.2f, tall %.2f",
        view.yaw, view.pitch, view.bpitch, view.fov, view.margin, view.tall))
    local page = ns.UI.pages and ns.UI.pages.warcraft and ns.UI.pages.warcraft.view
    if not page then return end
    local function Refit(m)
        if m and m.Fit then
            if m.SetCameraFieldOfView then m:SetCameraFieldOfView(view.fov) end
            m.sig = nil
            m:Fit()
        end
    end
    for _, t in ipairs(page.buildTex or {}) do Refit(t.model) end
    for _, f in pairs(page.unitFrames or {}) do
        if f.model then
            f.model.sig = nil
            f.model:Fit()
        end
    end
    for _, m in ipairs(page.treeModels or {}) do Refit(m) end
end

---------------------------------------------------------------------------
-- Spell effects: WoW's own spell models (M2 files from the game, ids from
-- the community listfile) shown where a spell lands, on the units it
-- affects while it lasts, and under heroes with an aura.
---------------------------------------------------------------------------
local YARD_PX = UNIT_PX / 2.2 -- a unit is about 2.2 yards tall
local FX_SIZE = 150
local FX_MAX = 40

-- One-shot effects when a spell is cast: file, where (target, caster or
-- point), scale, how long it shows (area spells: as long as they last).
local SPELL_FX = {
    resurrection = { 166704, "caster", 2, 2.5 },
    blizzard = { 165716, "point", 1.6, "duration" },
    flame_strike = { 166190, "point", 1.4, "duration" },
    earthquake = { 166285, "point", 2, "duration" },
    water_elemental = { 167178, "caster", 1, 1.5 },
    mass_teleport = { 167094, "caster", 1.5, 2 },
    storm_bolt = { 166841, "target", 1, 1 },
    thunder_clap = { 167120, "caster", 1.6, 1.5 },
    siphon_mana = { 166538, "target", 1, 1.5 },
    phoenix = { 166112, "caster", 1.2, 1.5 },
    wind_walk = { 166951, "caster", 1, 1 },
    mirror_image = { 165715, "caster", 1.2, 1 },
    far_sight = { 166064, "point", 1.5, 2 },
    feral_spirit = { 166994, "caster", 1.2, 1.5 },
    shockwave = { 166306, "point", 1.4, 1.5 },
    war_stomp = { 166306, "caster", 1.6, 1.5 },
    hex = { 166649, "target", 1, 1.2 },
    serpent_ward = { 166994, "point", 1, 1.2 },
    big_bad_voodoo = { 166826, "caster", 2, 2 },
    healing_ward_spell = { 166293, "caster", 1, 1.5 },
}
-- While a unit has the buff: file, scale, height (yards above the ground).
local BUFF_FX = {
    stun = { 166988, 1, 2.2 },
    invuln = { 166342, 1, 0 },
    avatar = { 166420, 1.4, 1.2 },
    bladestorm = { 167199, 1.2, 0.6 },
    noAttack = { 165651, 1, 1 },
    innerFire = { 166417, 1, 0 },
    slow = { 166898, 1, 0 },
    bloodlust = { 165727, 1, 2 },
    reinc = { 166927, 1.2, 0 },
}
-- Under a hero who has learned the aura.
local AURA_FX = { devotion = 165948, brilliance = 165759, endurance = 166557 }
-- Other moments.
local EVENT_FX = {
    heal = { 166273, 1, 1 },
    bolt = { 165780, 1, 0.8 },
    levelUp = { 166464, 1, 2 },
    reincarnated = { 166927, 1.4, 2 },
    crit = { 166893, 1, 0.8 },
    bash = { 166841, 1, 0.8 },
}
local ITEM_FX = { healing_potion = 166204, mana_potion = 166539, town_portal = 167094 }
P.SPELL_FX, P.BUFF_FX, P.AURA_FX = SPELL_FX, BUFF_FX, AURA_FX

local function MakeFx(parent)
    local ok, sc = pcall(CreateFrame, "ModelScene", nil, parent)
    if not ok or not sc or not sc.CreateActor then return nil end
    local actor = sc:CreateActor()
    if not actor or not actor.SetModelByFileID then return nil end
    sc.actor = actor
    sc:SetSize(FX_SIZE, FX_SIZE)
    function sc:Aim()
        local view = ns.WC.ART.view
        local yards = FX_SIZE / (YARD_PX * (self.scale or 1))
        Camera(self, 0, 0, self.z or 1, (yards / 2) / math.tan(view.fov / 2), view.bpitch)
    end
    function sc:SetDepth(d)
        if self.depth ~= d then
            self.depth = d
            self:Aim()
        end
    end
    function sc:Play(file, scale, z, restart)
        self.scale, self.z = scale or 1, z or 1
        if self.file ~= file or restart then
            if actor.ClearModel then actor:ClearModel() end
            actor:SetModelByFileID(file)
            self.file = file
        end
        if actor.SetAnimation then actor:SetAnimation(0) end
        self:Aim()
    end
    return sc
end

-- Start an effect: on a unit (follows it) or on a spot.
function P:FxStart(key, file, opts)
    self.fx = self.fx or {}
    self.fxPool = self.fxPool or {}
    local fx = self.fx[key]
    if not fx then
        local n = 0
        for _ in pairs(self.fx) do n = n + 1 end
        if n >= FX_MAX then return end
        local sc = table.remove(self.fxPool) or MakeFx(self.unitLayer)
        if not sc then return end
        fx = { sc = sc }
        self.fx[key] = fx
        opts.restart = true
    end
    fx.id, fx.x, fx.y, fx.untilT, fx.seen = opts.id, opts.x, opts.y, opts.untilT, true
    fx.sc:Show()
    if fx.file ~= file or opts.restart then
        fx.file = file
        fx.sc:Play(file, opts.scale, opts.z, opts.restart)
    end
    return fx
end

function P:FxStop(key)
    local fx = self.fx and self.fx[key]
    if not fx then return end
    fx.sc:Hide()
    table.insert(self.fxPool, fx.sc)
    self.fx[key] = nil
end

-- Effects for what just happened (called with the engine's events).
function P:SpellEvents(events)
    local st = self.st
    self.fxN = self.fxN or 0
    local function OnSpot(file, x, y, scale, dur, z)
        if not (self.vis and self.vis[math.floor(y) * st.w + math.floor(x)]) then return end
        self.fxN = self.fxN + 1
        self:FxStart("s" .. self.fxN, file, { x = x, y = y, scale = scale, z = z or 0.3, untilT = Now() + dur })
    end
    local function OnUnit(file, id, scale, dur, z)
        local e = st.ents[id]
        if not e or not self:Sees(e) then return end
        self.fxN = self.fxN + 1
        self:FxStart("s" .. self.fxN, file, { id = id, scale = scale, z = z or 1, untilT = Now() + dur })
    end
    for _, ev in ipairs(events) do
        local s = ev.kind == "cast" and SPELL_FX[ev.ability]
        if s then
            local a = WC().Abilities[ev.ability]
            local dur = s[4]
            if dur == "duration" then
                local d = a.duration
                dur = type(d) == "table" and (d[ev.lv or 1] or d[#d]) or d or 2
            end
            if s[2] == "point" and ev.x then
                OnSpot(s[1], ev.x, ev.y, s[3], dur)
            elseif s[2] == "target" and ev.target then
                OnUnit(s[1], ev.target, s[3], dur)
            else
                OnUnit(s[1], ev.id, s[3], dur, 0.3)
            end
        end
        local x = EVENT_FX[ev.kind]
        if x then OnUnit(x[1], ev.target or ev.id, x[2], 1.5, x[3]) end
        if ev.kind == "useItem" and ITEM_FX[ev.item] then OnUnit(ITEM_FX[ev.item], ev.id, 1, 1.5, 0.3) end
    end
end

-- Every frame: buffs and auras on the units in sight, effects follow their
-- units, finished ones go.
function P:DrawFx()
    local st = self.st
    if not st then return end
    self.fx = self.fx or {}
    for _, fx in pairs(self.fx) do if not fx.untilT then fx.seen = false end end
    local cx, cy = self.camX, self.camY
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and not e.inside and not e.insideBuild then
            local px, py = e.x * TILE - cx, e.y * TILE - cy
            if px > -40 and px < BW + 40 and py > -20 and py < VIEW_H + 60 and self:Sees(e) then
                for buff in pairs(e.buffs or {}) do
                    local b = BUFF_FX[buff]
                    if b then self:FxStart("b" .. id .. buff, b[1], { id = id, scale = b[2], z = b[3] }) end
                end
                if e.skills then
                    for key, file in pairs(AURA_FX) do
                        if (e.skills[key] or 0) > 0 then self:FxStart("a" .. id .. key, file, { id = id, scale = 1.6, z = 0 }) end
                    end
                end
            end
        end
    end
    local now = Now()
    local gone = {}
    for key, fx in pairs(self.fx) do
        local e = fx.id and st.ents[fx.id]
        local x, y
        if fx.id then
            if e then x, y = e.x, e.y end
        else
            x, y = fx.x, fx.y
        end
        if not x or (fx.untilT and now > fx.untilT) or (not fx.untilT and not fx.seen) then
            table.insert(gone, key)
        else
            local sc = fx.sc
            local lift = e and WC().Units[e.type] and WC().Units[e.type].air and 18 or 0
            local up = (sc.z or 1) * YARD_PX * (sc.scale or 1) * 0.85
            sc:ClearAllPoints()
            sc:SetPoint("CENTER", self.view, "TOPLEFT", x * TILE - cx, -(y * TILE - cy - lift) + up)
            sc:SetFrameLevel(self:Depth(y) + 2)
            sc:SetDepth(self:DepthAt(y, 6))
            if fx.untilT then sc:SetAlpha(math.min(1, (fx.untilT - now) / 0.4)) else sc:SetAlpha(1) end
        end
    end
    for _, key in ipairs(gone) do self:FxStop(key) end
end

do
    local Draw = P.Draw
    function P:Draw()
        Draw(self)
        self:DrawFx()
    end
end

---------------------------------------------------------------------------
-- Showcase: every building, unit and hero on one open map, with names, for
-- you to try out. Nothing moves or fights unless you tell it to; heroes know
-- every ability, mana and cooldowns refill, Target Dummies to hit. Nothing
-- is saved or counted. Main menu > Showcase, or /wcdemo.
---------------------------------------------------------------------------
local DEMO_EXTRA = { human = { "keep", "castle", "guard_tower" }, orc = { "stronghold", "fortress" } }
local DEMO_UNITS = {
    human = { "peasant", "militia", "footman", "rifleman", "knight", "priest", "sorceress", "siege_engine",
        "mortar_team", "flying_machine", "gryphon_rider", "dragonhawk_rider" },
    orc = { "peon", "grunt", "headhunter", "raider", "kodo", "tauren", "shaman", "witch_doctor", "catapult",
        "wind_rider", "batrider" },
}
local DEMO_HEROES = { "paladin", "archmage", "mountain_king", "blood_mage", "blademaster", "far_seer",
    "tauren_chieftain", "shadow_hunter" }

function P:StartDemo()
    if self.pvp or self.ls then return end
    ME, CPU = 1, nil
    local st = E().New({ factions = { "human", "orc" }, seed = 7, difficulty = "normal" })
    st.demo, st.peace = true, true
    local all = {}
    for _, id in ipairs(st.list) do table.insert(all, st.ents[id]) end
    for _, e in ipairs(all) do E().Remove(st, e) end
    st.trees = {}
    -- A strip of forest along the top, for the trees.
    for x = 0, st.w - 1 do st.trees[x] = 50 end
    local labels = {}
    local function Label(e, text) table.insert(labels, { id = e.id, text = text }) end
    -- Buildings: Human, then Orc.
    local y = 2
    for _, f in ipairs({ "human", "orc" }) do
        local list = {}
        for _, b in ipairs(WC().Factions[f].builds) do table.insert(list, b) end
        for _, b in ipairs(DEMO_EXTRA[f]) do table.insert(list, b) end
        local x, tallest = 1, 0
        for _, bt in ipairs(list) do
            local size = WC().Buildings[bt].size
            if x + size > st.w - 1 then x, y, tallest = 1, y + tallest + 2, 0 end
            local b = E().SpawnBuilding(st, 1, bt, x, y, true)
            Label(b, WC().Buildings[bt].name)
            x = x + size + 1
            tallest = math.max(tallest, size)
        end
        y = y + tallest + 1
    end
    local mine = E().SpawnBuilding(st, 0, "gold_mine", st.w - 5, 2, true)
    mine.gold = 99999
    Label(mine, "Gold Mine")
    -- Units: a row per side.
    y = y + 1
    for _, f in ipairs({ "human", "orc" }) do
        local x = 2
        for _, ut in ipairs(DEMO_UNITS[f]) do
            if WC().Units[ut] then
                local u = E().Spawn(st, 1, ut, x, y)
                Label(u, WC().Units[ut].name)
                x = x + 3.5
            end
        end
        y = y + 3
    end
    -- Heroes, knowing every ability.
    y = y + 1
    local x = 3
    for _, ht in ipairs(DEMO_HEROES) do
        if x > st.w - 4 then x, y = 3, y + 6 end
        local h = E().Spawn(st, 1, ht, x, y)
        h.level = 10
        for _, key in ipairs(WC().Units[ht].abilities) do
            h.skills[key] = WC().Abilities[key].ult and 1 or 3
        end
        h.points = 0
        Label(h, WC().Units[ht].name)
        x = x + 7
    end
    -- Target Dummies below them: right-click one to attack, or cast on it.
    y = y + 5
    for i = 0, 5 do
        local d = E().Spawn(st, 2, "target_dummy", 6 + i * 9, y)
        Label(d, "Target Dummy")
    end
    -- Player 2 needs a building, or the game would end.
    E().SpawnBuilding(st, 2, "orc_burrow", st.w - 3, st.h - 3, true)
    E().Food(st)
    st.players[1].gold, st.players[1].lumber = 99999, 99999
    self.demoLabels = labels
    self.st = st
    self.groups, self.lastClick, self.lastGroup = {}, nil, nil
    self.explored, self.vis, self.known, self.fogAt = {}, {}, {}, 0
    self.sel, self.place, self.targeting = {}, nil, nil
    self.counted = true
    self.treeDirty = true
    self.mmBuilt = false
    self:BuildMinimapTrees()
    self.camX, self.camY = 0, 0
    self:Resume()
    self:Say("Showcase: everything is yours to try. Right-click a Target Dummy to attack it.")
end

-- Every step: health, mana and cooldowns refill, so you can keep trying.
function P:DemoTick(dt)
    local st = self.st
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" then
            if e.owner == 2 then e.maxHp = math.max(e.maxHp, 100000) end
            if e.hp < e.maxHp * 0.6 then e.hp = e.maxHp end
            if e.maxMana then e.mana = e.maxMana end
            if e.cds then e.cds = {} end
        end
    end
end

-- Names under everything (and the spell each hero cast last).
function P:DrawDemoLabels()
    self.demoText = self.demoText or {}
    local st = self.st
    local on = st and st.demo and self.demoLabels
    local casts = {}
    for i, l in ipairs(on or {}) do
        local fs = self.demoText[i]
        if not fs then
            fs = W.Label(self.fxLayer, "", "GameFontHighlightSmall")
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetShadowOffset(1, -1)
            self.demoText[i] = fs
        end
        local e = st.ents[l.id]
        if e then
            local x, y = e.x, e.y + 0.6
            if e.kind ~= "unit" then x, y = e.x + e.size / 2, e.y + e.size + 0.2 end
            fs:ClearAllPoints()
            fs:SetPoint("TOP", self.view, "TOPLEFT", x * TILE - self.camX, -(y * TILE - self.camY))
            fs:SetText(l.text .. (casts[l.id] and ("\n|cff80c0ff" .. casts[l.id] .. "|r") or ""))
            fs:Show()
        else
            fs:Hide()
        end
    end
    for i = #(on or {}) + 1, #self.demoText do self.demoText[i]:Hide() end
end

do
    local Draw = P.Draw
    function P:Draw()
        Draw(self)
        self:DrawDemoLabels()
    end
end

SLASH_FNGWCDEMO1 = "/wcdemo"
SlashCmdList.FNGWCDEMO = function()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local page = ns.UI.pages.warcraft
    if page and page.view then page.view:StartDemo() end
end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.warcraft = P.New

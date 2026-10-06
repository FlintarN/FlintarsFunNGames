-- Kit: the building blocks for Arcade games that draw and move things
-- every frame (Agar.io, Snake, Tetris...). A game picks what it needs:
--   K.Canvas(parent)          a clipped game area with a dark background
--   K.Pool(canvas, make)      reuse textures/labels frame after frame
--   K.Loop(frame, step)       call step(dt) every frame while shown
--   K.Keys(frame, keys, down, up)  take only these keys while the game is up
--   K.MouseDir(frame)         direction from the frame's centre to the cursor
local ADDON, ns = ...

local K = {}
ns.Kit = K

K.ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"

K.CLASS_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1.00, 0.96, 0.41 }, PRIEST = { 0.95, 0.95, 0.95 }, SHAMAN = { 0.00, 0.44, 0.87 },
    MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1.00, 0.49, 0.04 },
}

function K.ClassColor(class)
    return K.CLASS_COLORS[class or ""] or { 0.6, 0.6, 0.6 }
end

function K.Canvas(parent)
    local c = CreateFrame("Frame", nil, parent)
    if c.SetClipsChildren then c:SetClipsChildren(true) end
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.bg:SetColorTexture(0.05, 0.06, 0.08, 1)
    c:EnableMouse(true)
    return c
end

-- A pool of regions. Each frame: pool:Begin(), then pool:Get() for every
-- thing to draw, then pool:End() hides the rest.
function K.Pool(canvas, make)
    local pool = { items = {}, used = 0 }
    function pool:Begin() self.used = 0 end
    function pool:Get()
        self.used = self.used + 1
        local item = self.items[self.used]
        if not item then
            item = make(canvas)
            self.items[self.used] = item
        end
        item:Show()
        return item
    end
    function pool:End()
        for i = self.used + 1, #self.items do self.items[i]:Hide() end
    end
    return pool
end

-- Put a region's centre at (x, y) measured from the canvas's top-left.
function K.Place(region, canvas, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", canvas, "TOPLEFT", x, -y)
end

-- step(dt) every frame while `frame` is shown; dt is capped so a hitch
-- doesn't teleport things.
function K.Loop(frame, step)
    frame:SetScript("OnUpdate", function(_, elapsed)
        step(math.min(elapsed or 0, 0.1))
    end)
end

-- Take only `keys` (a set: { W = true, A = true }) while the game is up;
-- every other key still reaches the game world. Off in combat, where the
-- client restricts keyboard capture: the mouse controls still work.
function K.Keys(frame, keys, down, up)
    local held = {}
    frame.keysHeld = held
    frame:SetScript("OnKeyDown", function(self, key)
        local mine = keys[key] == true
        if self.SetPropagateKeyboardInput and not (InCombatLockdown and InCombatLockdown()) then
            self:SetPropagateKeyboardInput(not mine)
        end
        if mine then
            held[key] = true
            if down then down(key) end
        end
    end)
    frame:SetScript("OnKeyUp", function(_, key)
        if keys[key] then
            held[key] = nil
            if up then up(key) end
        end
    end)
    function frame:KeysOn()
        if InCombatLockdown and InCombatLockdown() then return end
        if self.EnableKeyboard then self:EnableKeyboard(true) end
    end
    function frame:KeysOff()
        wipe(held)
        if self.EnableKeyboard and not (InCombatLockdown and InCombatLockdown()) then self:EnableKeyboard(false) end
    end
    return held
end

-- Unit vector from the frame's centre to the cursor, or nil when on it.
function K.MouseDir(frame)
    local cx, cy = frame:GetCenter()
    if not cx then return nil end
    local mx, my = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    local dx, dy = mx / scale - cx, my / scale - cy
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 6 then return nil end
    return dx / len, -dy / len -- screen down = +y
end

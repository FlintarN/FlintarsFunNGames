-- /wc3dtest: which way of drawing makes WoW layer overlapping 3D models like
-- 2D (lower on the map = in front)? Each panel draws three farms the way the
-- game does (one model frame each, overlapping) plus a tower behind them,
-- and tries one fix. The panel where the lowest farm is fully in front and
-- the tower is behind is the fix to use.
local _, ns = ...

local FARM, TOWER = 242696, 2061081
local PW, PH, FS = 180, 260, 120 -- panel, model frame
local YAW, PITCH, FOV = math.pi, 0.55, 0.6

-- One model frame. how(i, dist, r) returns near, far, distance, fov for the
-- i-th item from the front (1 = lowest on the map).
local function Item(parent, file, x, y, i, how)
    local sc = CreateFrame("ModelScene", nil, parent)
    if not sc.CreateActor then return end
    sc:SetSize(FS, FS)
    sc:SetPoint("TOPLEFT", x, -y)
    local a = sc:CreateActor()
    a:SetModelByFileID(file)
    sc:SetScript("OnUpdate", function(self)
        local x1, y1, z1, x2, y2, z2 = a:GetActiveBoundingBox()
        if not x1 or not x2 or x2 <= x1 then return end
        local cx, cy, cz = (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2
        local r = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2) / 2
        local dist = r / math.tan(FOV / 2)
        local near, far, d, fov = how(i, dist, r)
        self:SetCameraFieldOfView(fov)
        if self.SetCameraNearClip then self:SetCameraNearClip(near) end
        if self.SetCameraFarClip then self:SetCameraFarClip(far) end
        self:SetCameraOrientationByYawPitchRoll(YAW, PITCH, 0)
        local fx, fy, fz = 1, 0, 0
        if self.GetCameraForward then
            local gx, gy, gz = self:GetCameraForward()
            if gx then fx, fy, fz = gx, gy, gz end
        end
        self:SetCameraPosition(cx - fx * d, cy - fy * d, cz - fz * d)
    end)
end

-- The fixes. The plain one is today's game.
local FIXES = {
    { name = "as now", how = function(_, dist) return 0.1, 5000, dist, FOV end },
    -- Near clip close to the model for the front one, far for the back
    -- ones: the depth each writes is squeezed into its own band.
    { name = "near clip A", how = function(i, dist, r)
        local c = ({ 0.9, 0.45, 0.2, 0.08 })[i]
        return (dist - r) * c, 100000, dist, FOV
    end },
    { name = "near clip B", how = function(i, dist, r)
        local c = ({ 0.08, 0.2, 0.45, 0.9 })[i]
        return (dist - r) * c, 100000, dist, FOV
    end },
    -- The camera further away for the back ones, with a narrower lens so
    -- they look the same size.
    { name = "distance", how = function(i, dist, r)
        local d = dist + (i - 1) * 3 * r
        return 1, 100000, d, 2 * math.atan(math.tan(FOV / 2) * dist / d)
    end },
}

local function Open()
    local g = ns.WcDepthTest
    if not g then
        g = CreateFrame("Frame", "FunNGamesWc3dTest", UIParent, "BasicFrameTemplateWithInset")
        g:SetSize(#FIXES * (PW + 10) + 30, PH + 90)
        g:SetPoint("CENTER")
        g:SetFrameStrata("DIALOG")
        g:SetMovable(true)
        g:EnableMouse(true)
        g:RegisterForDrag("LeftButton")
        g:SetScript("OnDragStart", g.StartMoving)
        g:SetScript("OnDragStop", g.StopMovingOrSizing)
        tinsert(UISpecialFrames, "FunNGamesWc3dTest")
        local title = g:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
        title:SetText("Warcraft III 3D test: where is the lowest farm fully in front?")
        for p, fix in ipairs(FIXES) do
            local panel = CreateFrame("Frame", nil, g)
            panel:SetSize(PW, PH)
            panel:SetPoint("TOPLEFT", 20 + (p - 1) * (PW + 10), -40)
            local bg = panel:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.25, 0.4, 0.15, 1)
            -- Front to back (so frame order alone would get it wrong): three
            -- farms, each higher up (further back), then the tower behind.
            Item(panel, FARM, 40, 130, 1, fix.how)
            Item(panel, FARM, 30, 90, 2, fix.how)
            Item(panel, FARM, 20, 50, 3, fix.how)
            Item(panel, TOWER, 50, 0, 4, fix.how)
            local label = g:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            label:SetPoint("TOP", panel, "BOTTOM", 0, -6)
            label:SetText(p .. ": " .. fix.name)
        end
        ns.WcDepthTest = g
    end
    g:Show()
end

SLASH_FNGWC3DTEST1 = "/wc3dtest"
SlashCmdList.FNGWC3DTEST = Open

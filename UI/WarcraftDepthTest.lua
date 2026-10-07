-- /wc3dtest: a test window for drawing the Warcraft III map as ONE 3D scene
-- (so things lower on the map are always in front). Three panels try the
-- same layout at different camera distances; the one that shows three farms
-- stacked correctly (the lowest in front) tells which distances WoW draws.
local ADDON, ns = ...

local ATAN2 = math.atan2 or math.atan
local FARM, TOWER = 242696, 2061081
local PW, PH = 240, 300 -- each panel

-- A scene whose actors are placed by screen pixel and depth row.
-- base: camera distance of the front row.
local function MakeScene(parent, base)
    local sc = CreateFrame("ModelScene", nil, parent)
    if not sc.CreateActor then return nil end
    sc:SetSize(PW, PH)
    local yaw, pitch, fov = math.pi, 0.55, 0.05
    sc:SetCameraFieldOfView(fov)
    if sc.SetCameraNearClip then sc:SetCameraNearClip(base / 3) end
    if sc.SetCameraFarClip then sc:SetCameraFarClip(base * 100) end
    sc:SetCameraPosition(0, 0, 0)
    sc:SetCameraOrientationByYawPitchRoll(yaw, pitch, 0)
    local f = { math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), -math.sin(pitch) }
    local r = { math.sin(yaw), -math.cos(yaw), 0 }
    if sc.GetCameraForward then
        local x, y, z = sc:GetCameraForward()
        if x then f = { x, y, z } end
    end
    if sc.GetCameraRight then
        local x, y, z = sc:GetCameraRight()
        if x then r = { x, y, z } end
    end
    local u = { r[2] * f[3] - r[3] * f[2], r[3] * f[1] - r[1] * f[3], r[1] * f[2] - r[2] * f[1] }
    if sc.GetCameraUp then
        local x, y, z = sc:GetCameraUp()
        if x then u = { x, y, z } end
    end
    local F = (PH / 2) / math.tan(fov / 2)
    local yaw0 = ATAN2(f[2], f[1]) + math.pi
    sc.items = {}
    -- A model whose base centre stands at (px, py), `size` pixels wide, at depth row `row`.
    function sc:Add(file, px, py, row, size)
        local a = self:CreateActor()
        a:SetModelByFileID(file)
        table.insert(self.items, { a = a, px = px, py = py, row = row, size = size })
    end
    function sc:Place()
        for _, it in ipairs(self.items) do
            local a = it.a
            local x1, y1, z1, x2, y2, z2 = a:GetActiveBoundingBox()
            if x1 and x2 and x2 > x1 then
                local k = it.size / math.max(x2 - x1, y2 - y1)
                local t = base * 1.035 ^ ((20 - it.row) * 4)
                local s = k * t / F
                local sx, sy = (it.px - PW / 2) / F, (PH / 2 - it.py) / F
                local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
                local c, si = math.cos(yaw0), math.sin(yaw0)
                local rx, ry = mx * c - my * si, mx * si + my * c
                a:SetYaw(yaw0)
                a:SetScale(s)
                a:SetPosition((f[1] + r[1] * sx + u[1] * sy) * t - s * rx, (f[2] + r[2] * sx + u[2] * sy) * t - s * ry,
                    (f[3] + r[3] * sx + u[3] * sy) * t - s * z1)
            end
        end
    end
    return sc
end

local function Open()
    local g = ns.WcDepthTest
    if not g then
        g = CreateFrame("Frame", "FunNGamesWc3dTest", UIParent, "BasicFrameTemplateWithInset")
        g:SetSize(3 * PW + 60, PH + 80)
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
        title:SetText("Warcraft III: 3D test - which panel shows the farms?")
        g.scenes = {}
        for i, base in ipairs({ 15, 150, 1500 }) do
            local bg = g:CreateTexture(nil, "BACKGROUND")
            bg:SetSize(PW, PH)
            bg:SetPoint("TOPLEFT", 20 + (i - 1) * (PW + 10), -50)
            bg:SetColorTexture(0.25, 0.4, 0.15, 1)
            local sc = MakeScene(g, base)
            if sc then
                sc:SetPoint("TOPLEFT", bg, "TOPLEFT")
                -- Three farms in a column, each a bit lower (and so in front),
                -- and a tower behind them.
                sc:Add(TOWER, 150, 120, 6, 45)
                sc:Add(FARM, 120, 150, 8, 70)
                sc:Add(FARM, 120, 190, 10, 70)
                sc:Add(FARM, 120, 230, 12, 70)
                table.insert(g.scenes, sc)
            end
            local label = g:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            label:SetPoint("TOP", bg, "BOTTOM", 0, -4)
            label:SetText(tostring(i))
        end
        g:SetScript("OnUpdate", function(self, elapsed)
            self.t = (self.t or 0) + elapsed
            if self.t < 0.2 then return end
            self.t = 0
            for _, sc in ipairs(self.scenes) do sc:Place() end
        end)
        ns.WcDepthTest = g
    end
    g:Show()
end

SLASH_FNGWC3DTEST1 = "/wc3dtest"
SlashCmdList.FNGWC3DTEST = Open

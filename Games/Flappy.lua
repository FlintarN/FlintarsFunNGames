-- Flappy Bird: a solo Arcade game. Flap through the gaps between the pipes.
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games
local W = setmetatable({}, { __index = function(_, k) return ns.Widgets[k] end })

local G = {
    key = "flappy",
    arcade = true,
    solo = true,
    name = "Flappy Bird",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconFlappy",
    short = "Flap through the pipes. One touch and it's over.",
    how = "Space, Up or W (or click) to flap. Fly through the gaps; the pipes and the ground end the run. P pauses.",
    rules = "Flap to stay in the air and pass through the gaps between the pipes. Every pipe is a point.",
    scoreLabel = "Pipes",
    canvas = { 320, 320 },
    keys = { SPACE = true, UP = true, W = true },
    fields = {},
}
ns.Games.flappy = G

local BIRD_X, R = 80, 11
local GROUND = 296
local GRAVITY, FLAP = 950, -290
local PIPE_W, GAP, SPACING, SPEED = 46, 98, 170, 120
G.BIRD_X, G.R, G.GROUND, G.PIPE_W, G.GAP = BIRD_X, R, GROUND, PIPE_W, GAP

function G:Build(view)
    local cv = view.canvas
    cv.bg:SetColorTexture(0.42, 0.75, 0.9, 1)
    -- A paler band low in the sky and a few far-off hills.
    local haze = cv:CreateTexture(nil, "BACKGROUND", nil, 1)
    haze:SetColorTexture(0.6, 0.85, 0.93, 1)
    haze:SetSize(320, 90)
    K.Place(haze, cv, 160, GROUND - 45)
    for i = 0, 4 do
        local hill = cv:CreateTexture(nil, "BACKGROUND", nil, 2)
        hill:SetTexture(K.ART .. "Blob")
        hill:SetVertexColor(0.5, 0.78, 0.5)
        hill:SetSize(120, 70)
        K.Place(hill, cv, i * 80 - 20, GROUND)
    end
    view.pipes = K.Pool(cv, function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(PIPE_W, 320)
        local function Part(cap)
            local t = f:CreateTexture(nil, cap and "OVERLAY" or "ARTWORK")
            t:SetColorTexture(cap and 0.30 or 0.38, cap and 0.62 or 0.72, cap and 0.22 or 0.26, 1)
            local edge = f:CreateTexture(nil, cap and "OVERLAY" or "ARTWORK", nil, 1)
            edge:SetColorTexture(0.6, 0.9, 0.45, 0.8)
            edge:SetWidth(4)
            edge:SetPoint("TOPLEFT", t, "TOPLEFT", 4, 0)
            edge:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 4, 0)
            return t
        end
        f.top, f.topCap, f.bottom, f.bottomCap = Part(), Part(true), Part(), Part(true)
        return f
    end)
    local ground = CreateFrame("Frame", nil, cv)
    ground:SetFrameLevel(cv:GetFrameLevel() + 10)
    ground:SetPoint("TOPLEFT", cv, "TOPLEFT", 0, -GROUND)
    ground:SetPoint("BOTTOMRIGHT")
    local dirt = ground:CreateTexture(nil, "BACKGROUND")
    dirt:SetAllPoints()
    dirt:SetColorTexture(0.86, 0.75, 0.45, 1)
    local grass = ground:CreateTexture(nil, "ARTWORK")
    grass:SetColorTexture(0.45, 0.75, 0.25, 1)
    grass:SetPoint("TOPLEFT")
    grass:SetPoint("TOPRIGHT")
    grass:SetHeight(5)
    view.stripes = {}
    for i = 1, 14 do
        local s = ground:CreateTexture(nil, "ARTWORK", nil, 1)
        s:SetColorTexture(0.36, 0.64, 0.2, 1)
        s:SetSize(12, 5)
        view.stripes[i] = s
    end
    view.ground = ground
    view.birdFrame = CreateFrame("Frame", nil, cv)
    view.birdFrame:SetFrameLevel(cv:GetFrameLevel() + 12)
    view.birdFrame:SetAllPoints()
    view.bird = view.birdFrame:CreateTexture(nil, "ARTWORK")
    view.bird:SetTexture(K.ART .. "FlappyBird")
    view.bird:SetSize(34, 34)
    view.hint = W.Label(view.birdFrame, "Press Space to flap", "GameFontHighlightLarge")
    view.hint:SetPoint("TOP", 0, -60)
end

function G:Start(view)
    view.y, view.vy, view.t, view.scroll = 150, 0, 0, 0
    view.started = false
    view.list = {}
end

local function AddPipe(view, x)
    table.insert(view.list, { x = x, gap = math.random(70, GROUND - 70) })
end

local function Flap(view)
    view.vy = FLAP
    if not view.started then
        view.started = true
        AddPipe(view, 360)
    end
    W.Sfx("flap")
end

function G:Key(view) Flap(view) end
function G:Click(view) Flap(view) end

-- Does the bird at height y touch this pipe?
function G.Hits(pipe, y)
    if math.abs(pipe.x - BIRD_X) >= PIPE_W / 2 + R - 3 then return false end
    return y - R + 3 < pipe.gap - GAP / 2 or y + R - 3 > pipe.gap + GAP / 2
end

function G:Step(view, dt)
    view.t = view.t + dt
    if not view.started then
        view.y = 150 + math.sin(view.t * 4) * 6
        view.scroll = view.scroll + SPEED * dt
        return self:Draw(view)
    end
    view.vy = math.min(view.vy + GRAVITY * dt, 520)
    view.y = math.max(R, view.y + view.vy * dt)
    view.scroll = view.scroll + SPEED * dt
    local last = view.list[#view.list]
    if last and last.x < 320 + PIPE_W - SPACING then AddPipe(view, last.x + SPACING) end
    for i = #view.list, 1, -1 do
        local p = view.list[i]
        p.x = p.x - SPEED * dt
        if not p.passed and p.x + PIPE_W / 2 < BIRD_X - R then
            p.passed = true
            view:SetScore(view.score + 1)
            W.Sfx("point")
        end
        if p.x < -PIPE_W then table.remove(view.list, i) end
    end
    self:Draw(view)
    if view.y + R >= GROUND then
        view.y = GROUND - R
        return view:Over(view.score, "Splat!", "crash")
    end
    for _, p in ipairs(view.list) do
        if G.Hits(p, view.y) then return view:Over(view.score, "Bonk!", "crash") end
    end
end

function G:Draw(view)
    local cv = view.canvas
    view.pipes:Begin()
    for _, p in ipairs(view.list) do
        local f = view.pipes:Get()
        K.Place(f, cv, p.x, 160)
        local top, bottom = p.gap - GAP / 2, p.gap + GAP / 2
        f.top:ClearAllPoints()
        f.top:SetPoint("TOPLEFT", 3, 0)
        f.top:SetPoint("TOPRIGHT", -3, 0)
        f.top:SetHeight(math.max(1, top - 14))
        f.topCap:ClearAllPoints()
        f.topCap:SetPoint("TOPLEFT", 0, -(top - 14))
        f.topCap:SetSize(PIPE_W, 14)
        f.bottomCap:ClearAllPoints()
        f.bottomCap:SetPoint("TOPLEFT", 0, -bottom)
        f.bottomCap:SetSize(PIPE_W, 14)
        f.bottom:ClearAllPoints()
        f.bottom:SetPoint("TOPLEFT", 3, -(bottom + 14))
        f.bottom:SetPoint("BOTTOMRIGHT", -3, 0)
    end
    view.pipes:End()
    local off = view.scroll % 24
    for i, s in ipairs(view.stripes) do
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", view.ground, "TOPLEFT", (i - 1) * 24 - off, 0)
    end
    K.Place(view.bird, cv, BIRD_X, view.y)
    local tilt = view.started and math.max(-1.3, math.min(0.45, -view.vy / 600)) or 0
    if view.bird.SetRotation then view.bird:SetRotation(tilt) end
    view.hint:SetShown(not view.started and view.running ~= false)
end

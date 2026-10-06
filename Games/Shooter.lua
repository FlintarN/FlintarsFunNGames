-- Space Shooter: a solo Arcade game in the Space Invaders mould. Waves of
-- invaders march side to side and creep down; shoot them before they land.
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games
local W = setmetatable({}, { __index = function(_, k) return ns.Widgets[k] end })

local G = {
    key = "shooter",
    arcade = true,
    solo = true,
    name = "Space Shooter",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconShooter",
    short = "Waves of invaders. Shoot them down before they land.",
    how = "Left / Right (A / D) to move, hold Space to shoot. Three lives; every wave is faster. P pauses.",
    rules = "Shoot the invaders before they reach the ground. Clear a wave and a faster one comes.",
    canvas = { 320, 320 },
    keys = { LEFT = true, RIGHT = true, A = true, D = true, SPACE = true, UP = true, W = true },
    fields = {},
}
ns.Games.shooter = G

local SIZE = 320
local PLAYER_Y, PLAYER_SPEED = 292, 190
local COLS, ROWS, DX, DY = 8, 4, 30, 24
local SHOT_SPEED, SHOT_CD = 330, 0.32
local ROW_KIND = {
    { points = 30, color = { 1, 0.45, 0.8 } },
    { points = 20, color = { 0.4, 0.85, 1 } },
    { points = 10, color = { 0.5, 1, 0.45 } },
    { points = 10, color = { 0.5, 1, 0.45 } },
}
G.PLAYER_Y = PLAYER_Y

function G:Build(view)
    local cv = view.canvas
    cv.bg:SetColorTexture(0.02, 0.02, 0.06, 1)
    view.stars = {}
    for i = 1, 40 do
        local t = cv:CreateTexture(nil, "BACKGROUND", nil, 1)
        local far = i % 3 ~= 0
        t:SetColorTexture(1, 1, 1, far and 0.35 or 0.8)
        t:SetSize(far and 1 or 2, far and 1 or 2)
        view.stars[i] = { t = t, x = math.random(0, SIZE), y = math.random(0, SIZE), speed = far and 12 or 30 }
    end
    view.alienPool = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetTexture(K.ART .. "Alien")
        t:SetSize(22, 22)
        return t
    end)
    view.shotPool = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetColorTexture(1, 1, 1, 1)
        return t
    end)
    view.boomPool = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(K.ART .. "Blob")
        t:SetBlendMode("ADD")
        return t
    end)
    view.ship = cv:CreateTexture(nil, "ARTWORK", nil, 2)
    view.ship:SetTexture(K.ART .. "Ship")
    view.ship:SetSize(28, 28)
    view.lifeIcons = {}
    for i = 1, 3 do
        local t = cv:CreateTexture(nil, "OVERLAY")
        t:SetTexture(K.ART .. "Ship")
        t:SetSize(12, 12)
        t:SetPoint("TOPRIGHT", -4 - (i - 1) * 14, -4)
        view.lifeIcons[i] = t
    end
    view.waveText = W.Label(cv, "", "GameFontNormalSmall")
    view.waveText:SetPoint("TOPLEFT", 6, -5)
    view.banner = W.BigLabel(cv, 22, "GameFontNormalHuge")
    view.banner:SetPoint("CENTER", 0, 20)
end

local function NewWave(view)
    view.wave = view.wave + 1
    view.aliens = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            table.insert(view.aliens, { r = r, c = c, alive = true })
        end
    end
    view.ox, view.oy = 40, 34 + math.min(60, (view.wave - 1) * 8)
    view.dir = 1
    view.alienShots, view.shots = {}, {}
    view.fireIn = 1.5
    view.bannerTime = 1.6
    view.banner:SetText("Wave " .. view.wave)
end

function G:Start(view)
    view.x, view.lives, view.wave = SIZE / 2, 3, 0
    view.cooldown, view.hurt, view.t = 0, 0, 0
    view.booms = {}
    NewWave(view)
end

local function AlienPos(view, a)
    return view.ox + (a.c - 1) * DX, view.oy + (a.r - 1) * DY
end
G.AlienPos = AlienPos

local function Alive(view)
    local n = 0
    for _, a in ipairs(view.aliens) do if a.alive then n = n + 1 end end
    return n
end

local function Boom(view, x, y, size, color)
    table.insert(view.booms, { x = x, y = y, t = 0, size = size, color = color })
end

function G:Key(view, key)
    if (key == "SPACE" or key == "UP" or key == "W") and view.cooldown <= 0 then
        table.insert(view.shots, { x = view.x, y = PLAYER_Y - 14 })
        view.cooldown = SHOT_CD
    end
end

local function Hurt(view)
    if view.hurt > 0 then return end
    view.lives = view.lives - 1
    Boom(view, view.x, PLAYER_Y, 50, { 1, 0.6, 0.2 })
    W.PlaySound("RAID_WARNING")
    if view.lives <= 0 then return view:Over(view.score, "Shot down") end
    view.hurt = 1.8
end

function G:Step(view, dt)
    view.t = view.t + dt
    local held = view.held or {}
    if held.LEFT or held.A then view.x = math.max(16, view.x - PLAYER_SPEED * dt) end
    if held.RIGHT or held.D then view.x = math.min(SIZE - 16, view.x + PLAYER_SPEED * dt) end
    view.cooldown = view.cooldown - dt
    view.hurt = math.max(0, view.hurt - dt)
    if (held.SPACE or held.UP or held.W) then self:Key(view, "SPACE") end
    for _, s in ipairs(view.stars) do
        s.y = s.y + s.speed * dt
        if s.y > SIZE then s.y, s.x = 0, math.random(0, SIZE) end
    end
    for i = #view.booms, 1, -1 do
        local b = view.booms[i]
        b.t = b.t + dt
        if b.t > 0.4 then table.remove(view.booms, i) end
    end
    if view.bannerTime > 0 then
        view.bannerTime = view.bannerTime - dt
        return self:Draw(view)
    end

    -- The formation: faster as it thins out and wave by wave.
    local alive = Alive(view)
    local speed = 14 + view.wave * 5 + (1 - alive / (ROWS * COLS)) * 60
    view.ox = view.ox + view.dir * speed * dt
    local minX, maxX, maxY = SIZE, 0, 0
    for _, a in ipairs(view.aliens) do
        if a.alive then
            local x, y = AlienPos(view, a)
            minX, maxX, maxY = math.min(minX, x), math.max(maxX, x), math.max(maxY, y)
        end
    end
    if (view.dir > 0 and maxX > SIZE - 14) or (view.dir < 0 and minX < 14) then
        view.dir = -view.dir
        view.oy = view.oy + 10
    end
    if maxY >= PLAYER_Y - 18 then
        view.lives = 0
        return view:Over(view.score, "Invaded!")
    end

    -- Invaders fire from the bottom of a random column.
    view.fireIn = view.fireIn - dt
    if view.fireIn <= 0 then
        view.fireIn = math.max(0.35, 1.3 - view.wave * 0.12) * (0.6 + math.random() * 0.8)
        local lowest = {}
        for _, a in ipairs(view.aliens) do
            if a.alive and (not lowest[a.c] or a.r > lowest[a.c].r) then lowest[a.c] = a end
        end
        local pick = {}
        for _, a in pairs(lowest) do table.insert(pick, a) end
        if #pick > 0 then
            local a = pick[math.random(#pick)]
            local x, y = AlienPos(view, a)
            table.insert(view.alienShots, { x = x, y = y + 10 })
        end
    end

    -- Our shots.
    for i = #view.shots, 1, -1 do
        local s = view.shots[i]
        s.y = s.y - SHOT_SPEED * dt
        local hit = false
        for _, a in ipairs(view.aliens) do
            if a.alive then
                local x, y = AlienPos(view, a)
                if math.abs(s.x - x) < 12 and math.abs(s.y - y) < 11 then
                    a.alive = false
                    hit = true
                    view:SetScore(view.score + ROW_KIND[a.r].points * view.wave)
                    Boom(view, x, y, 34, ROW_KIND[a.r].color)
                    W.PlaySound("U_CHAT_SCROLL_BUTTON")
                    break
                end
            end
        end
        if hit or s.y < -10 then table.remove(view.shots, i) end
    end
    -- Theirs.
    for i = #view.alienShots, 1, -1 do
        local s = view.alienShots[i]
        s.y = s.y + (120 + view.wave * 8) * dt
        if math.abs(s.x - view.x) < 12 and math.abs(s.y - PLAYER_Y) < 11 and view.hurt <= 0 then
            table.remove(view.alienShots, i)
            Hurt(view)
            if not view.running then return end
        elseif s.y > SIZE + 10 then
            table.remove(view.alienShots, i)
        end
    end
    if Alive(view) == 0 then
        view:SetScore(view.score + 100 * view.wave)
        W.PlaySound("LEVELUP")
        NewWave(view)
    end
    self:Draw(view)
end

function G:Draw(view)
    local cv = view.canvas
    for _, s in ipairs(view.stars) do K.Place(s.t, cv, s.x, s.y) end
    view.alienPool:Begin()
    local wobble = math.floor(view.t * 2.5) % 2 == 0
    for _, a in ipairs(view.aliens) do
        if a.alive then
            local t = view.alienPool:Get()
            local col = ROW_KIND[a.r].color
            t:SetVertexColor(col[1], col[2], col[3])
            t:SetSize(wobble and 22 or 20, wobble and 20 or 22)
            K.Place(t, cv, AlienPos(view, a))
        end
    end
    view.alienPool:End()
    view.shotPool:Begin()
    for _, s in ipairs(view.shots) do
        local t = view.shotPool:Get()
        t:SetColorTexture(1, 0.95, 0.4, 1)
        t:SetSize(2, 9)
        K.Place(t, cv, s.x, s.y)
    end
    for _, s in ipairs(view.alienShots) do
        local t = view.shotPool:Get()
        t:SetColorTexture(1, 0.3, 0.3, 1)
        t:SetSize(3, 8)
        K.Place(t, cv, s.x, s.y)
    end
    view.shotPool:End()
    view.boomPool:Begin()
    for _, b in ipairs(view.booms) do
        local t = view.boomPool:Get()
        local k = b.t / 0.4
        t:SetVertexColor(b.color[1], b.color[2], b.color[3])
        t:SetAlpha(1 - k)
        t:SetSize(b.size * (0.4 + k), b.size * (0.4 + k))
        K.Place(t, cv, b.x, b.y)
    end
    view.boomPool:End()
    K.Place(view.ship, cv, view.x, PLAYER_Y)
    view.ship:SetAlpha((view.hurt > 0 and math.floor(view.hurt * 10) % 2 == 0) and 0.25 or 1)
    for i, t in ipairs(view.lifeIcons) do t:SetShown(i <= view.lives) end
    view.waveText:SetText("Wave " .. view.wave)
    view.banner:SetShown(view.bannerTime > 0)
end

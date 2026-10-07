-- Angry Birds: a solo Arcade game. Fling boulders at the murlocs hiding in
-- their forts of wood and stone. Knock out every murloc to clear a level;
-- run out of boulders and the run ends.
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games
local W = setmetatable({}, { __index = function(_, k) return ns.Widgets[k] end })

local G = {
    key = "angrybirds",
    arcade = true,
    solo = true,
    name = "Angry Birds",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconAngryBirds",
    short = "Fling boulders, topple forts, knock out the murlocs.",
    how = "Drag back from the sling and let go to fire. Or: Up / Down to aim, Left / Right for power, Space to fire. P pauses.",
    rules = "Knock out every murloc with the boulders you have. Leftover boulders are bonus points.",
    canvas = { 320, 320 },
    keys = { UP = true, DOWN = true, LEFT = true, RIGHT = true, W = true, S = true, A = true, D = true, SPACE = true },
    fields = {},
}
ns.Games.angrybirds = G

local GROUND = 292
local SLING_X, SLING_Y = 44, 238
local CELL, COLS, X0 = 16, 9, 170
local GRAVITY, MAX_SPEED, MAX_PULL = 380, 470, 54
local BOULDER_R = 7
local HP = { W = 1, S = 2 }
G.GROUND, G.CELL, G.X0, G.SLING_X, G.SLING_Y = GROUND, CELL, X0, SLING_X, SLING_Y

-- Bottom row last. W wood, S stone, M murloc.
local LEVELS = {
    { "....M....",
      "...WWW...",
      "...W.W..." },
    { "..M...M..",
      "..W...W..",
      "..W.M.W..",
      "..WWWWW.." },
    { "....M....",
      "...SSS...",
      "..MW.WM..",
      "..WWWWW..",
      "..W.M.W.." },
    { ".M.....M.",
      ".W..M..W.",
      ".W.SSS.W.",
      ".WMW.WMW.",
      ".SSSSSSS." },
    { "....M....",
      "....S....",
      "...MWM...",
      "..SSSSS..",
      "..W.M.W..",
      "M.W...W.M",
      "SSSSSSSSS" },
}

-- Levels after the hand-made ones: a few random towers with a murloc on top.
local function RandomLevel(n)
    local h = 4 + math.min(4, math.floor(n / 3))
    local rows = {}
    for r = 1, h do rows[r] = {} for c = 1, COLS do rows[r][c] = "." end end
    local towers = math.min(4, 2 + math.floor(n / 4))
    local used = {}
    for _ = 1, towers do
        local c
        repeat c = math.random(1, COLS) until not used[c]
        used[c] = true
        local height = math.random(1, h - 1)
        local mat = math.random() < math.min(0.6, n * 0.06) and "S" or "W"
        for r = h, h - height + 1, -1 do rows[r][c] = mat end
        rows[h - height][c] = "M"
    end
    local out = {}
    for r = 1, h do out[r] = table.concat(rows[r]) end
    return out
end

local function CellRect(c, r) -- c 0..COLS-1, r 0 = bottom row
    local x = X0 + c * CELL
    return x, GROUND - (r + 1) * CELL, x + CELL, GROUND - r * CELL
end

function G:Build(view)
    local cv = view.canvas
    cv.bg:SetColorTexture(0.5, 0.78, 0.95, 1)
    local far = cv:CreateTexture(nil, "BACKGROUND", nil, 1)
    far:SetColorTexture(0.68, 0.87, 0.97, 1)
    far:SetSize(320, 110)
    K.Place(far, cv, 160, GROUND - 55)
    for i = 0, 3 do
        local hill = cv:CreateTexture(nil, "BACKGROUND", nil, 2)
        hill:SetTexture(K.ART .. "Blob")
        hill:SetVertexColor(0.45, 0.68, 0.42)
        hill:SetSize(160, 80)
        K.Place(hill, cv, i * 100 + 10, GROUND + 4)
    end
    local ground = cv:CreateTexture(nil, "BORDER")
    ground:SetColorTexture(0.38, 0.6, 0.25, 1)
    ground:SetPoint("TOPLEFT", 0, -GROUND)
    ground:SetPoint("BOTTOMRIGHT")
    local dirt = cv:CreateTexture(nil, "BORDER", nil, 1)
    dirt:SetColorTexture(0.45, 0.32, 0.18, 1)
    dirt:SetPoint("TOPLEFT", 0, -GROUND - 6)
    dirt:SetPoint("BOTTOMRIGHT")
    -- The sling: a post and a fork.
    local function Wood(w, h, x, y)
        local t = cv:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetColorTexture(0.42, 0.26, 0.12, 1)
        t:SetSize(w, h)
        K.Place(t, cv, x, y)
    end
    Wood(6, GROUND - SLING_Y, SLING_X, (GROUND + SLING_Y) / 2)
    Wood(5, 16, SLING_X - 6, SLING_Y - 6)
    Wood(5, 16, SLING_X + 6, SLING_Y - 6)
    Wood(17, 5, SLING_X, SLING_Y + 2)
    view.blockPool = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetSize(CELL, CELL)
        return t
    end)
    view.murlocPool = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "ARTWORK", nil, 2)
        t:SetTexture(K.ART .. "Murloc")
        return t
    end)
    view.dotPool = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 0.8)
        t:SetSize(3, 3)
        return t
    end)
    view.puffPool = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "OVERLAY", nil, 1)
        t:SetTexture(K.ART .. "Blob")
        return t
    end)
    view.boulder = cv:CreateTexture(nil, "ARTWORK", nil, 3)
    view.boulder:SetTexture(K.ART .. "Boulder")
    view.boulder:SetSize(BOULDER_R * 2 + 2, BOULDER_R * 2 + 2)
    view.ammo = {}
    for i = 1, 6 do
        local t = cv:CreateTexture(nil, "ARTWORK", nil, 2)
        t:SetTexture(K.ART .. "Boulder")
        t:SetSize(11, 11)
        K.Place(t, cv, SLING_X - 14 - i * 12, GROUND - 6)
        view.ammo[i] = t
    end
    view.levelText = W.Label(cv, "", "GameFontNormal")
    view.levelText:SetPoint("TOPLEFT", 6, -6)
    view.banner = W.BigLabel(cv, 22, "GameFontNormalHuge")
    view.banner:SetPoint("CENTER", 0, 40)
end

local function Load(view, n)
    view.level = n
    local rows = LEVELS[n] or RandomLevel(n)
    view.cells, view.murlocs = {}, 0
    for r = 0, 13 do view.cells[r] = {} end
    for i, line in ipairs(rows) do
        local r = #rows - i
        for c = 0, COLS - 1 do
            local ch = line:sub(c + 1, c + 1)
            if ch == "M" then
                view.cells[r][c] = { kind = "M" }
                view.murlocs = view.murlocs + 1
            elseif HP[ch] then
                view.cells[r][c] = { kind = ch, hp = HP[ch] }
            end
        end
    end
    view.shotsLeft = math.min(5, math.max(3, view.murlocs + 1))
    view.ball, view.falling, view.fallTime = nil, false, 0
    view.state = "aim"
    view.banner:SetText("Level " .. n)
    view.bannerTime = 1.3
end

function G:Start(view)
    view.angle, view.power = 0.6, 0.75
    view.puffs = {}
    view.aimRepeat = 0
    Load(view, 1)
end

local function Velocity(view)
    local v = view.power * MAX_SPEED
    return math.cos(view.angle) * v, -math.sin(view.angle) * v
end

function G.Fire(view)
    if view.state ~= "aim" or view.shotsLeft <= 0 then return end
    local vx, vy = Velocity(view)
    view.ball = { x = SLING_X, y = SLING_Y, vx = vx, vy = vy, t = 0, spin = 0 }
    view.shotsLeft = view.shotsLeft - 1
    view.state = "flying"
    view.dragging = nil
    W.Sfx("launch")
end

function G:Key(view, key)
    if key == "SPACE" then return G.Fire(view) end
    self:Aim(view, key)
end

function G:Aim(view, key)
    if key == "UP" or key == "W" then view.angle = math.min(1.45, view.angle + 0.035) end
    if key == "DOWN" or key == "S" then view.angle = math.max(-0.4, view.angle - 0.035) end
    if key == "RIGHT" or key == "D" then view.power = math.min(1, view.power + 0.02) end
    if key == "LEFT" or key == "A" then view.power = math.max(0.2, view.power - 0.02) end
end

function G:Click(view, x, y, button)
    if button == "LeftButton" and view.state == "aim" then view.dragging = true end
end

-- Pulling back from the sling sets angle and power.
local function Drag(view, x, y)
    local dx, dy = SLING_X - x, SLING_Y - y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 4 then return end
    view.power = math.max(0.2, math.min(1, len / MAX_PULL))
    view.angle = (math.atan2 or math.atan)(-dy, dx)
    view.angle = math.max(-0.4, math.min(1.45, view.angle))
end

local function Puff(view, x, y, color, size)
    table.insert(view.puffs, { x = x, y = y, t = 0, color = color, size = size or 26 })
end

local function Pop(view, r, c)
    view.cells[r][c] = nil
    view.murlocs = view.murlocs - 1
    view:SetScore(view.score + 500)
    local x1, y1, x2, y2 = CellRect(c, r)
    Puff(view, (x1 + x2) / 2, (y1 + y2) / 2, { 0.5, 1, 0.5 }, 34)
    W.Sfx("pop")
end
G.Pop = Pop

local function Smash(view, r, c)
    local cell = view.cells[r][c]
    cell.hp = cell.hp - 1
    local x1, y1, x2, y2 = CellRect(c, r)
    if cell.hp <= 0 then
        view.cells[r][c] = nil
        view:SetScore(view.score + (cell.kind == "S" and 100 or 50))
        Puff(view, (x1 + x2) / 2, (y1 + y2) / 2, cell.kind == "S" and { 0.7, 0.7, 0.75 } or { 0.75, 0.5, 0.25 })
        return true
    end
end

-- Which cell a point is in, if any.
local function CellAt(x, y)
    if x < X0 or x >= X0 + COLS * CELL or y >= GROUND then return end
    local c = math.floor((x - X0) / CELL)
    local r = math.floor((GROUND - y) / CELL)
    if r < 0 or r > 13 then return end
    return r, c
end

-- The boulder hits the fort: one thud at most every 0.15 s.
local function Thud(view)
    local now = GetTime()
    if now - (view.thudAt or -1) < 0.15 then return end
    view.thudAt = now
    W.Sfx("hit")
end

local function MoveBall(view, dt)
    local b = view.ball
    b.t = b.t + dt
    b.vy = b.vy + GRAVITY * dt
    b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
    b.spin = b.spin - b.vx * dt / BOULDER_R
    -- Hit the fort?
    for _, p in ipairs({ { 0, 0 }, { BOULDER_R, 0 }, { -BOULDER_R, 0 }, { 0, BOULDER_R }, { 0, -BOULDER_R } }) do
        local r, c = CellAt(b.x + p[1], b.y + p[2])
        local cell = r and view.cells[r][c]
        if cell then
            local speed = math.sqrt(b.vx * b.vx + b.vy * b.vy)
            if cell.kind == "M" then
                Pop(view, r, c)
                b.vx, b.vy = b.vx * 0.8, b.vy * 0.8
            elseif speed > 110 and Smash(view, r, c) then
                b.vx, b.vy = b.vx * 0.55, b.vy * 0.55
                Thud(view)
            else
                -- Bounce off: back out and turn round.
                Thud(view)
                b.x, b.y = b.x - b.vx * dt, b.y - b.vy * dt
                if p[1] ~= 0 then b.vx = -b.vx * 0.3 else b.vy = -b.vy * 0.3 end
                b.vx = b.vx * 0.7
            end
            view.falling = true
            break
        end
    end
    if b.y + BOULDER_R >= GROUND then
        b.y = GROUND - BOULDER_R
        b.vy = -b.vy * 0.35
        b.vx = b.vx * 0.6
    end
    local speed = math.sqrt(b.vx * b.vx + b.vy * b.vy)
    if b.x > 340 or b.x < -20 or b.t > 6 or (speed < 25 and b.y >= GROUND - BOULDER_R - 1) then
        view.ball = nil
    end
end

-- Anything with nothing under it drops one row. A murloc that falls two
-- rows, or gets landed on, is knocked out.
local function Settle(view)
    local moved = false
    for r = 1, 13 do
        for c = 0, COLS - 1 do
            local cell = view.cells[r][c]
            if cell then
                local below = view.cells[r - 1][c]
                if below and below.kind == "M" and cell.kind ~= "M" then
                    Pop(view, r - 1, c)
                    below = nil
                end
                if not below then
                    view.cells[r - 1][c] = cell
                    view.cells[r][c] = nil
                    cell.fell = (cell.fell or 0) + 1
                    moved = true
                end
            end
        end
    end
    for r = 0, 13 do
        for c = 0, COLS - 1 do
            local cell = view.cells[r][c]
            if cell and cell.fell then
                local landed = r == 0 or view.cells[r - 1][c]
                if landed and not moved then
                    if cell.kind == "M" and cell.fell >= 2 then Pop(view, r, c) end
                    cell.fell = nil
                end
            end
        end
    end
    return moved
end
G.Settle = Settle

function G:Step(view, dt)
    for i = #view.puffs, 1, -1 do
        local p = view.puffs[i]
        p.t = p.t + dt
        if p.t > 0.45 then table.remove(view.puffs, i) end
    end
    if view.bannerTime > 0 then view.bannerTime = view.bannerTime - dt end
    if view.state == "aim" then
        local held = view.held or {}
        view.aimRepeat = view.aimRepeat - dt
        if view.aimRepeat <= 0 then
            for key in pairs(held) do self:Aim(view, key) end
            view.aimRepeat = 0.03
        end
        if view.dragging then
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                G.Fire(view)
            else
                Drag(view, view:Cursor())
            end
        end
    elseif view.state == "flying" then
        if view.ball then
            local steps = math.max(1, math.ceil(dt * MAX_SPEED / 4))
            for _ = 1, steps do
                if not view.ball then break end
                MoveBall(view, dt / steps)
            end
        end
        view.fallTime = view.fallTime + dt
        if view.fallTime >= 0.07 then
            view.fallTime = 0
            view.falling = Settle(view)
        end
        if not view.ball and not view.falling then
            if view.murlocs <= 0 then
                view:SetScore(view.score + view.shotsLeft * 300 + view.level * 200)
                view.state = "cleared"
                view.wait = 1.4
                view.banner:SetText("Level cleared!")
                view.bannerTime = 1.4
                W.Sfx("win")
            elseif view.shotsLeft <= 0 then
                view.state = "done"
                return view:Over(view.score, "Out of boulders")
            else
                view.state = "aim"
            end
        end
    elseif view.state == "cleared" then
        view.wait = view.wait - dt
        if view.wait <= 0 then Load(view, view.level + 1) end
    end
    self:Draw(view)
end

function G:Draw(view)
    local cv = view.canvas
    view.blockPool:Begin()
    view.murlocPool:Begin()
    for r = 0, 13 do
        for c = 0, COLS - 1 do
            local cell = view.cells[r][c]
            if cell then
                local x1, y1, x2, y2 = CellRect(c, r)
                if cell.kind == "M" then
                    local t = view.murlocPool:Get()
                    t:SetSize(CELL + 3, CELL + 3)
                    K.Place(t, cv, (x1 + x2) / 2, (y1 + y2) / 2 - 1)
                else
                    local t = view.blockPool:Get()
                    t:SetTexture(K.ART .. (cell.kind == "S" and "Stone" or "Wood"))
                    local cracked = cell.hp < HP[cell.kind]
                    t:SetVertexColor(cracked and 0.7 or 1, cracked and 0.7 or 1, cracked and 0.7 or 1)
                    K.Place(t, cv, (x1 + x2) / 2, (y1 + y2) / 2)
                end
            end
        end
    end
    view.blockPool:End()
    view.murlocPool:End()
    -- The aim: a dotted arc.
    view.dotPool:Begin()
    if view.state == "aim" then
        local vx, vy = Velocity(view)
        local x, y = SLING_X, SLING_Y
        for i = 1, 40 do
            local step = 0.035
            vy = vy + GRAVITY * step
            x, y = x + vx * step, y + vy * step
            if y > GROUND or x > 320 then break end
            if i % 2 == 0 and i <= 24 then
                local t = view.dotPool:Get()
                t:SetAlpha(1 - i / 30)
                K.Place(t, cv, x, y)
            end
        end
    end
    view.dotPool:End()
    local b = view.ball
    if b then
        view.boulder:Show()
        K.Place(view.boulder, cv, b.x, b.y)
        if view.boulder.SetRotation then view.boulder:SetRotation(b.spin) end
    elseif view.state == "aim" and view.shotsLeft > 0 then
        view.boulder:Show()
        local pull = view.power * 14
        K.Place(view.boulder, cv, SLING_X - math.cos(view.angle) * pull, SLING_Y + math.sin(view.angle) * pull)
    else
        view.boulder:Hide()
    end
    for i, t in ipairs(view.ammo) do
        t:SetShown(i <= view.shotsLeft - ((view.state == "aim") and 1 or 0))
    end
    view.puffPool:Begin()
    for _, p in ipairs(view.puffs) do
        local t = view.puffPool:Get()
        local k = p.t / 0.45
        t:SetVertexColor(p.color[1], p.color[2], p.color[3])
        t:SetAlpha(0.8 * (1 - k))
        t:SetSize(p.size * (0.5 + k), p.size * (0.5 + k))
        K.Place(t, cv, p.x, p.y)
    end
    view.puffPool:End()
    view.levelText:SetText("Level " .. view.level .. "   Murlocs: " .. view.murlocs)
    view.banner:SetShown(view.bannerTime > 0)
end

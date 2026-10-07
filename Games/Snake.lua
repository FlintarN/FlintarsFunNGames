-- Snake: a solo Arcade game on the Solo page (UI\Solo.lua). Eat apples to
-- grow; the walls and your own tail end the run. It speeds up as you grow.
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games

local G = {
    key = "snake",
    arcade = true,
    solo = true,
    name = "Snake",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconSnake",
    short = "The classic: eat apples, grow longer, don't bite your tail.",
    how = "Arrow keys or W A S D to turn. Eat the apples; walls and your own tail end the run. P pauses.",
    rules = "Steer the snake to the apples. Each apple makes you longer and a little faster.",
    scoreLabel = "Apples",
    canvas = { 320, 320 },
    keys = { UP = true, DOWN = true, LEFT = true, RIGHT = true, W = true, A = true, S = true, D = true },
    fields = {},
}
ns.Games.snake = G

local N, CELL = 20, 16
local DIRS = { UP = { 0, -1 }, W = { 0, -1 }, DOWN = { 0, 1 }, S = { 0, 1 },
    LEFT = { -1, 0 }, A = { -1, 0 }, RIGHT = { 1, 0 }, D = { 1, 0 } }

function G:Build(view)
    local c = view.canvas
    -- A soft checkerboard, drawn once.
    for y = 0, N - 1 do
        for x = 0, N - 1 do
            if (x + y) % 2 == 0 then
                local t = c:CreateTexture(nil, "BACKGROUND", nil, 1)
                t:SetColorTexture(1, 1, 1, 0.025)
                t:SetSize(CELL, CELL)
                t:SetPoint("TOPLEFT", x * CELL, -y * CELL)
            end
        end
    end
    view.body = K.Pool(c, function(cv)
        local t = cv:CreateTexture(nil, "ARTWORK")
        t:SetTexture(K.ART .. "Blob")
        return t
    end)
    view.apple = c:CreateTexture(nil, "ARTWORK", nil, 2)
    view.apple:SetTexture(K.ART .. "Blob")
    view.apple:SetVertexColor(0.9, 0.15, 0.15)
    view.apple:SetSize(CELL - 2, CELL - 2)
end

local function Free(view)
    local taken = {}
    for _, seg in ipairs(view.snake) do taken[seg[1] .. "," .. seg[2]] = true end
    for _ = 1, 500 do
        local x, y = math.random(0, N - 1), math.random(0, N - 1)
        if not taken[x .. "," .. y] then return { x, y } end
    end
end

function G:Start(view)
    view.snake = { { 10, 10 }, { 9, 10 }, { 8, 10 } }
    view.dir = { 1, 0 }
    view.turns = {}
    view.tick = 0
    view.apple_at = Free(view)
end

-- Turns queue up (two at most), so quick double-taps work.
function G:Key(view, key)
    local d = DIRS[key]
    if not d or #view.turns >= 2 then return end
    local last = view.turns[#view.turns] or view.dir
    if d[1] == -last[1] and d[2] == -last[2] then return end -- no reversing
    if d[1] == last[1] and d[2] == last[2] then return end
    table.insert(view.turns, d)
end

function G:Step(view, dt)
    view.tick = view.tick + dt
    local speed = math.max(0.06, 0.14 - #view.snake * 0.002)
    if view.tick < speed then return end
    view.tick = 0
    if #view.turns > 0 then view.dir = table.remove(view.turns, 1) end
    local head = view.snake[1]
    local nx, ny = head[1] + view.dir[1], head[2] + view.dir[2]
    local grow = view.apple_at and nx == view.apple_at[1] and ny == view.apple_at[2]
    if nx < 0 or nx >= N or ny < 0 or ny >= N then return view:Over(view.score, "Crashed!", "crash") end
    for i = 1, #view.snake - (grow and 0 or 1) do
        local seg = view.snake[i]
        if seg[1] == nx and seg[2] == ny then return view:Over(view.score, "Bit your tail!", "crash") end
    end
    table.insert(view.snake, 1, { nx, ny })
    if grow then
        view:SetScore(view.score + 1)
        view.apple_at = Free(view)
        ns.Widgets.Sfx("eat")
    else
        table.remove(view.snake)
    end
    self:Draw(view)
end

function G:Draw(view)
    local c = view.canvas
    view.body:Begin()
    local n = #view.snake
    for i, seg in ipairs(view.snake) do
        local t = view.body:Get()
        local k = 1 - (i - 1) / math.max(1, n) * 0.5
        if i == 1 then t:SetVertexColor(0.55, 1, 0.45) else t:SetVertexColor(0.2 * k, 0.8 * k, 0.25 * k) end
        local size = i == 1 and CELL + 1 or CELL - 1
        t:SetSize(size, size)
        K.Place(t, c, seg[1] * CELL + CELL / 2, seg[2] * CELL + CELL / 2)
    end
    view.body:End()
    if view.apple_at then
        K.Place(view.apple, c, view.apple_at[1] * CELL + CELL / 2, view.apple_at[2] * CELL + CELL / 2)
    end
end

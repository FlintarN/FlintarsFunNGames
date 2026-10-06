-- 2048: a solo Arcade game. Slide the tiles; equal tiles merge into one.
-- Tiles glide to their new place and merged tiles pop.
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games
local W = setmetatable({}, { __index = function(_, k) return ns.Widgets[k] end })

local G = {
    key = "g2048",
    arcade = true,
    solo = true,
    name = "2048",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\Icon2048",
    short = "Slide the tiles, merge the numbers, reach 2048.",
    how = "Arrow keys or W A S D slide every tile. Two equal tiles that meet merge into one. P pauses.",
    rules = "Slide tiles to merge equal numbers. Your score goes up by every merged tile.",
    canvas = { 320, 320 },
    keys = { UP = true, DOWN = true, LEFT = true, RIGHT = true, W = true, A = true, S = true, D = true },
    fields = {},
}
ns.Games.g2048 = G

local N, TILE, GAP = 4, 70, 8
local COLORS = {
    [2] = { 0.93, 0.89, 0.85 }, [4] = { 0.93, 0.88, 0.78 }, [8] = { 0.95, 0.69, 0.47 },
    [16] = { 0.96, 0.58, 0.39 }, [32] = { 0.96, 0.49, 0.37 }, [64] = { 0.96, 0.37, 0.23 },
    [128] = { 0.93, 0.81, 0.45 }, [256] = { 0.93, 0.80, 0.38 }, [512] = { 0.93, 0.78, 0.31 },
    [1024] = { 0.93, 0.77, 0.25 }, [2048] = { 0.93, 0.76, 0.18 },
}
local MOVES = { UP = { 0, -1 }, W = { 0, -1 }, DOWN = { 0, 1 }, S = { 0, 1 },
    LEFT = { -1, 0 }, A = { -1, 0 }, RIGHT = { 1, 0 }, D = { 1, 0 } }

local function Pos(c, r) return GAP + (c - 1) * (TILE + GAP) + TILE / 2, GAP + (r - 1) * (TILE + GAP) + TILE / 2 end

function G:Build(view)
    local cv = view.canvas
    cv.bg:SetColorTexture(0.47, 0.43, 0.39, 1)
    for r = 1, N do
        for c = 1, N do
            local t = cv:CreateTexture(nil, "BACKGROUND", nil, 2)
            t:SetColorTexture(0.80, 0.75, 0.70, 1)
            t:SetSize(TILE, TILE)
            K.Place(t, cv, Pos(c, r))
        end
    end
    view.tilePool = K.Pool(cv, function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(TILE, TILE)
        f.bg = f:CreateTexture(nil, "ARTWORK")
        f.bg:SetAllPoints()
        f.text = W.BigLabel(f, 30, "GameFontNormalHuge")
        f.text:SetPoint("CENTER")
        f.text:SetShadowOffset(0, 0)
        return f
    end)
end

local function Empty(view)
    local free = {}
    for r = 1, N do for c = 1, N do if not view.grid[r][c] then table.insert(free, { r, c }) end end end
    return free
end

local function Spawn(view)
    local free = Empty(view)
    if #free == 0 then return end
    local rc = free[math.random(#free)]
    local tile = { v = math.random() < 0.9 and 2 or 4, r = rc[1], c = rc[2], born = true }
    view.grid[rc[1]][rc[2]] = tile
end

function G:Start(view)
    view.grid = {}
    for r = 1, N do view.grid[r] = {} end
    view.won = false
    Spawn(view)
    Spawn(view)
end

-- Slide everything in direction d. Returns whether anything moved.
local function Slide(view, d)
    local dx, dy = d[1], d[2]
    local moved, gained = false, 0
    local order = {}
    for i = 1, N do order[i] = (dx > 0 or dy > 0) and (N + 1 - i) or i end
    for _, row in ipairs(view.grid) do for _, t in pairs(row) do t.fromR, t.fromC, t.merged, t.born = t.r, t.c, nil, nil end end
    for line = 1, N do
        for _, k in ipairs(order) do
            local r, c = dy ~= 0 and k or line, dx ~= 0 and k or line
            local t = view.grid[r][c]
            if t then
                local nr, nc = r, c
                while true do
                    local tr, tc = nr + dy, nc + dx
                    if tr < 1 or tr > N or tc < 1 or tc > N then break end
                    local other = view.grid[tr][tc]
                    if not other then
                        nr, nc = tr, tc
                    elseif other.v == t.v and not other.merged and not t.merged then
                        -- Merge into the other tile.
                        view.grid[r][c] = nil
                        other.v = other.v * 2
                        other.merged = true
                        other.fromR, other.fromC = t.fromR, t.fromC
                        gained = gained + other.v
                        moved = true
                        t = nil
                        break
                    else
                        break
                    end
                end
                if t and (nr ~= r or nc ~= c) then
                    view.grid[r][c] = nil
                    view.grid[nr][nc] = t
                    t.r, t.c = nr, nc
                    moved = true
                end
            end
        end
    end
    return moved, gained
end

local function CanMove(view)
    if #Empty(view) > 0 then return true end
    for r = 1, N do
        for c = 1, N do
            local v = view.grid[r][c].v
            if (r < N and view.grid[r + 1][c].v == v) or (c < N and view.grid[r][c + 1].v == v) then return true end
        end
    end
    return false
end

function G:Key(view, key)
    local d = MOVES[key]
    if not d then return end
    local moved, gained = Slide(view, d)
    if not moved then return end
    view:SetScore(view.score + gained)
    Spawn(view)
    self:Draw(view, true)
    for _, row in ipairs(view.grid) do
        for _, t in pairs(row) do
            if t.v == 2048 and not view.won then
                view.won = true
                W.PlaySound("LEVELUP")
            end
        end
    end
    if not CanMove(view) then view:Over(view.score, "No more moves") end
end

G.CanMove = CanMove

function G:Draw(view, animate)
    local cv = view.canvas
    view.tilePool:Begin()
    for _, row in ipairs(view.grid) do
        for _, t in pairs(row) do
            local f = view.tilePool:Get()
            local col = COLORS[t.v] or { 0.24, 0.23, 0.20 }
            f.bg:SetColorTexture(col[1], col[2], col[3], 1)
            f.text:SetText(tostring(t.v))
            local dark = t.v <= 4
            f.text:SetTextColor(dark and 0.47 or 1, dark and 0.43 or 1, dark and 0.40 or 1)
            local face = f.text:GetFont()
            if face then f.text:SetFont(face, t.v < 100 and 30 or (t.v < 1000 and 26 or 20), "") end
            local x, y = Pos(t.c, t.r)
            if animate and t.fromR and (t.fromR ~= t.r or t.fromC ~= t.c) then
                local fx, fy = Pos(t.fromC, t.fromR)
                ns.Cards.Tween(0.09, function(k) K.Place(f, cv, fx + (x - fx) * k, fy + (y - fy) * k) end)
            else
                K.Place(f, cv, x, y)
            end
            if animate and (t.merged or t.born) then
                f:SetSize(TILE * 0.4, TILE * 0.4)
                ns.Cards.Tween(0.14, function(k)
                    local s = TILE * (0.4 + 0.6 * k + (t.merged and math.sin(k * math.pi) * 0.15 or 0))
                    f:SetSize(s, s)
                end, nil, t.born and 0.08 or 0)
            else
                f:SetSize(TILE, TILE)
            end
        end
    end
    view.tilePool:End()
end

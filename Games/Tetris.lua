-- Tetris: a solo Arcade game that follows the Tetris Guideline.
--   7-bag, 5 next pieces, hold, ghost piece
--   SRS rotation both ways with the official wall-kick tables
--   Guideline gravity: (0.8 - (level - 1) * 0.007) ^ (level - 1) seconds per row
--   Lock delay 0.5 s with move reset (15 resets), soft drop 20x gravity
--   DAS 167 ms / ARR 33 ms
--   Scoring: singles to Tetrises, T-spins (full and mini, 3-corner rule),
--   back-to-back x1.5, combos, perfect clears; level up every 10 lines
--   Spawn above the field (rows 21-22) and drop one row; block out / lock out
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games
local W = setmetatable({}, { __index = function(_, k) return ns.Widgets[k] end })

local G = {
    key = "tetris",
    arcade = true,
    solo = true,
    name = "Tetris",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconTetris",
    short = "Falling blocks by the official rules: hold, T-spins, back-to-backs.",
    how = "Left / Right move, Up or X turn right, Z or Ctrl turn left, Down soft drop, Space hard drop, C or Shift hold. P pauses.",
    rules = "Clear lines by filling them. Guideline rules: SRS kicks, hold, T-spins, back-to-back and combos.",
    canvas = { 320, 320 },
    keys = {
        UP = true, DOWN = true, LEFT = true, RIGHT = true, W = true, A = true, S = true, D = true,
        SPACE = true, X = true, Z = true, Q = true, E = true, C = true,
        LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    },
    fields = {},
}
ns.Games.tetris = G

local COLS, ROWS, HIDDEN, CELL = 10, 20, 4, 16
local TOP = -HIDDEN       -- board rows run TOP .. ROWS-1; below 0 is above the visible field
local BX = 74             -- the board's left edge on the canvas
local DAS, ARR = 0.167, 0.033
local LOCK_DELAY, MAX_RESETS = 0.5, 15
local SOFT_FACTOR = 20
local CLEAR_DELAY = 0.25
G.COLS, G.ROWS, G.TOP = COLS, ROWS, TOP

-- Spawn orientation (state 0); the rest come from turning the n x n box.
local PIECES = {
    I = { n = 4, cells = { { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 } }, color = { 0.15, 0.85, 0.95 } },
    O = { n = 2, cells = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }, color = { 0.98, 0.85, 0.2 } },
    T = { n = 3, cells = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } }, color = { 0.7, 0.35, 0.9 } },
    S = { n = 3, cells = { { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } }, color = { 0.35, 0.85, 0.35 } },
    Z = { n = 3, cells = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } }, color = { 0.95, 0.3, 0.3 } },
    J = { n = 3, cells = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } }, color = { 0.3, 0.45, 0.95 } },
    L = { n = 3, cells = { { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } }, color = { 0.98, 0.6, 0.2 } },
}
local ORDER = { "I", "O", "T", "S", "Z", "J", "L" }

-- SRS kicks (x right, y UP as in the Guideline; flipped when used).
-- States: 0 spawn, 1 R, 2 two turns, 3 L.
local KICKS = {
    ["0>1"] = { { 0, 0 }, { -1, 0 }, { -1, 1 }, { 0, -2 }, { -1, -2 } },
    ["1>0"] = { { 0, 0 }, { 1, 0 }, { 1, -1 }, { 0, 2 }, { 1, 2 } },
    ["1>2"] = { { 0, 0 }, { 1, 0 }, { 1, -1 }, { 0, 2 }, { 1, 2 } },
    ["2>1"] = { { 0, 0 }, { -1, 0 }, { -1, 1 }, { 0, -2 }, { -1, -2 } },
    ["2>3"] = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, -2 }, { 1, -2 } },
    ["3>2"] = { { 0, 0 }, { -1, 0 }, { -1, -1 }, { 0, 2 }, { -1, 2 } },
    ["3>0"] = { { 0, 0 }, { -1, 0 }, { -1, -1 }, { 0, 2 }, { -1, 2 } },
    ["0>3"] = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, -2 }, { 1, -2 } },
}
local KICKS_I = {
    ["0>1"] = { { 0, 0 }, { -2, 0 }, { 1, 0 }, { -2, -1 }, { 1, 2 } },
    ["1>0"] = { { 0, 0 }, { 2, 0 }, { -1, 0 }, { 2, 1 }, { -1, -2 } },
    ["1>2"] = { { 0, 0 }, { -1, 0 }, { 2, 0 }, { -1, 2 }, { 2, -1 } },
    ["2>1"] = { { 0, 0 }, { 1, 0 }, { -2, 0 }, { 1, -2 }, { -2, 1 } },
    ["2>3"] = { { 0, 0 }, { 2, 0 }, { -1, 0 }, { 2, 1 }, { -1, -2 } },
    ["3>2"] = { { 0, 0 }, { -2, 0 }, { 1, 0 }, { -2, -1 }, { 1, 2 } },
    ["3>0"] = { { 0, 0 }, { 1, 0 }, { -2, 0 }, { 1, -2 }, { -2, 1 } },
    ["0>3"] = { { 0, 0 }, { -1, 0 }, { 2, 0 }, { -1, 2 }, { 2, -1 } },
}

local LINE_POINTS = { [0] = 0, 100, 300, 500, 800 }
local TSPIN_POINTS = { [0] = 400, 800, 1200, 1600 }
local MINI_POINTS = { [0] = 100, 200, 400 }
local PERFECT_POINTS = { 800, 1200, 1800, 2000 }
local NAMES = { "Single", "Double", "Triple", "Tetris" }

local MOVE = { LEFT = -1, A = -1, RIGHT = 1, D = 1 }
local TURN = { UP = 1, W = 1, X = 1, E = 1, Z = -1, Q = -1, LCTRL = -1, RCTRL = -1 }
local HOLD = { C = true, LSHIFT = true, RSHIFT = true }

-- Seconds per row at a level (Guideline formula).
function G.Gravity(level)
    return (0.8 - (level - 1) * 0.007) ^ (level - 1)
end

function G:Build(view)
    local cv = view.canvas
    local well = cv:CreateTexture(nil, "BACKGROUND", nil, 1)
    well:SetColorTexture(0, 0, 0, 0.55)
    well:SetSize(COLS * CELL + 4, ROWS * CELL)
    K.Place(well, cv, BX + COLS * CELL / 2, ROWS * CELL / 2)
    for x = 1, COLS - 1 do
        local t = cv:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetColorTexture(1, 1, 1, 0.03)
        t:SetSize(1, ROWS * CELL)
        K.Place(t, cv, BX + x * CELL, ROWS * CELL / 2)
    end
    view.blocks = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetTexture(K.ART .. "Block")
        return t
    end)
    local function Label(text, x, y, font)
        local l = W.Label(cv, text, font or "GameFontNormal")
        l:SetPoint("TOPLEFT", x, -y)
        return l
    end
    Label("Hold", 8, 6)
    Label("Next", BX + COLS * CELL + 10, 6)
    Label("Lines", 8, 150)
    Label("Level", 8, 200)
    view.linesText = W.BigLabel(cv, 20, "GameFontHighlightLarge")
    view.linesText:SetPoint("TOPLEFT", 8, -166)
    view.levelText = W.BigLabel(cv, 20, "GameFontHighlightLarge")
    view.levelText:SetPoint("TOPLEFT", 8, -216)
    view.callout = W.Label(cv, "", "GameFontNormalLarge")
    view.callout:SetPoint("TOP", cv, "TOPLEFT", BX + COLS * CELL / 2, -70)
    view.callout:SetWidth(COLS * CELL + 40)
end

local function Cells(kind, rot)
    local p = PIECES[kind]
    local out = {}
    for i, c in ipairs(p.cells) do
        local x, y = c[1], c[2]
        for _ = 1, rot % 4 do x, y = p.n - 1 - y, x end -- clockwise (screen y points down)
        out[i] = { x, y }
    end
    return out
end
G.Cells = Cells

local function Filled(view, x, y)
    if x < 0 or x >= COLS or y >= ROWS or y < TOP then return true end
    return view.board[y][x] ~= nil
end

local function Fits(view, kind, rot, px, py)
    for _, c in ipairs(Cells(kind, rot)) do
        if Filled(view, c[1] + px, c[2] + py) then return false end
    end
    return true
end
G.Fits = Fits

local function Refill(view)
    while #view.queue < 7 do
        local bag = {}
        for i, k in ipairs(ORDER) do bag[i] = k end
        for i = #bag, 2, -1 do
            local j = math.random(i)
            bag[i], bag[j] = bag[j], bag[i]
        end
        for _, k in ipairs(bag) do table.insert(view.queue, k) end
    end
end

local function Callout(view, text)
    view.callout:SetText(text)
    view.calloutTime = 1.4
end

-- A new piece above the field (rows 21-22), dropped one row if it can.
local function Spawn(view, kind)
    if not kind then
        Refill(view)
        kind = table.remove(view.queue, 1)
        Refill(view)
    end
    local p = { kind = kind, rot = 0, x = kind == "O" and 4 or 3, y = -2, resets = 0, lockT = 0 }
    if not Fits(view, kind, 0, p.x, p.y) then
        view.piece = nil
        return view:Over(view.score, "Block out")
    end
    if Fits(view, kind, 0, p.x, p.y + 1) then p.y = p.y + 1 end
    p.lowest = p.y
    view.piece = p
    view.fall = 0
end

function G:Start(view)
    view.board = {}
    for y = TOP, ROWS - 1 do view.board[y] = {} end
    view.queue, view.hold, view.holdUsed = {}, nil, false
    view.lines, view.level, view.combo, view.b2b = 0, 1, -1, false
    view.flash, view.flashRows, view.das, view.calloutTime = nil, nil, nil, 0
    Spawn(view)
end

local function Grounded(view)
    local p = view.piece
    return not Fits(view, p.kind, p.rot, p.x, p.y + 1)
end

-- After a successful move or turn: the lock timer restarts (15 times).
local function Moved(view)
    local p = view.piece
    if Grounded(view) then
        if p.resets < MAX_RESETS then
            p.lockT = 0
            p.resets = p.resets + 1
        end
    end
end

local function Shift(view, dx)
    local p = view.piece
    if p and Fits(view, p.kind, p.rot, p.x + dx, p.y) then
        p.x = p.x + dx
        p.lastRot = false
        Moved(view)
        return true
    end
end

local function Rotate(view, dir)
    local p = view.piece
    if not p or p.kind == "O" then return end
    local to = (p.rot + dir) % 4
    local table_ = (p.kind == "I" and KICKS_I or KICKS)[p.rot .. ">" .. to]
    for i, k in ipairs(table_) do
        local x, y = p.x + k[1], p.y - k[2]
        if Fits(view, p.kind, to, x, y) then
            p.rot, p.x, p.y = to, x, y
            p.lastRot, p.kick = true, i
            if p.y > p.lowest then p.lowest, p.resets, p.lockT = p.y, 0, 0 end
            Moved(view)
            return true
        end
    end
end
G.Rotate = Rotate

-- T-spin by the 3-corner rule: "full", "mini" or nil.
local function TSpin(view, p)
    if p.kind ~= "T" or not p.lastRot then return nil end
    local cx, cy = p.x + 1, p.y + 1
    local tl, tr = Filled(view, cx - 1, cy - 1), Filled(view, cx + 1, cy - 1)
    local br, bl = Filled(view, cx + 1, cy + 1), Filled(view, cx - 1, cy + 1)
    local count = (tl and 1 or 0) + (tr and 1 or 0) + (br and 1 or 0) + (bl and 1 or 0)
    if count < 3 then return nil end
    local front = ({ [0] = { tl, tr }, [1] = { tr, br }, [2] = { br, bl }, [3] = { bl, tl } })[p.rot]
    if (front[1] and front[2]) or p.kick == 5 then return "full" end
    return "mini"
end
G.TSpin = TSpin

local function Lock(view, dropped)
    local p = view.piece
    local spin = TSpin(view, p)
    local above = true
    for _, c in ipairs(Cells(p.kind, p.rot)) do
        local y = c[2] + p.y
        if y >= 0 then above = false end
        view.board[y][c[1] + p.x] = p.kind
    end
    view.piece = nil
    view.holdUsed = false
    if above then return view:Over(view.score, "Lock out") end

    local full, left = {}, 0
    for y = TOP, ROWS - 1 do
        local n = 0
        for x = 0, COLS - 1 do if view.board[y][x] then n = n + 1 end end
        if n == COLS then table.insert(full, y) else left = left + n end
    end
    local n = #full
    local level = view.level
    local base, name
    if spin == "full" then
        base, name = TSPIN_POINTS[n], "T-Spin" .. (n > 0 and (" " .. NAMES[n]) or "")
    elseif spin == "mini" then
        base, name = MINI_POINTS[n] or 0, "Mini T-Spin" .. (n > 0 and (" " .. NAMES[n]) or "")
    else
        base, name = LINE_POINTS[n], n > 0 and NAMES[n] or nil
    end
    local text = {}
    if n > 0 then
        local hard = n == 4 or spin ~= nil
        if hard and view.b2b then
            base = base * 1.5
            table.insert(text, "Back-to-Back")
        end
        view.b2b = hard
        view.combo = view.combo + 1
        if view.combo > 0 then
            base = base + 50 * view.combo
            table.insert(text, "Combo " .. view.combo)
        end
        if left == 0 then
            local pc = (n == 4 and view.b2b and text[1] == "Back-to-Back") and 3200 or PERFECT_POINTS[n]
            base = base + pc
            table.insert(text, "Perfect Clear!")
        end
    else
        view.combo = -1
    end
    if name then table.insert(text, 1, name) end
    if #text > 0 then Callout(view, table.concat(text, "\n")) end
    view:SetScore(view.score + math.floor(base * level))

    if n > 0 then
        view.flashRows, view.flash = full, CLEAR_DELAY
        W.Sfx((n == 4 or spin) and "big" or "line")
    else
        if spin then W.Sfx("big") elseif not dropped then W.Sfx("land") end
        Spawn(view)
    end
end

-- Remove the flashed rows and drop everything above.
local function Clear(view)
    local gone = {}
    for _, y in ipairs(view.flashRows) do gone[y] = true end
    local rows, keep = {}, ROWS - 1
    for y = ROWS - 1, TOP, -1 do
        if not gone[y] then
            rows[keep] = view.board[y]
            keep = keep - 1
        end
    end
    for y = keep, TOP, -1 do rows[y] = {} end
    view.board = rows
    view.lines = view.lines + #view.flashRows
    local level = view.level
    view.level = math.floor(view.lines / 10) + 1
    if view.level > level then W.Sfx("levelup") end
    view.flash, view.flashRows = nil, nil
    Spawn(view)
end
G.Clear = Clear

local function Hold(view)
    local p = view.piece
    if not p or view.holdUsed then return end
    local kind = view.hold
    view.hold = p.kind
    view.holdUsed = true
    Spawn(view, kind)
    view.holdUsed = true
end

function G:Key(view, key)
    if not view.piece then return end
    if MOVE[key] then
        if Shift(view, MOVE[key]) then W.Sfx("move") end
        view.das = { key = key, dx = MOVE[key], t = DAS }
    elseif TURN[key] then
        if Rotate(view, TURN[key]) then W.Sfx("rotate") end
    elseif HOLD[key] then
        Hold(view)
    elseif key == "SPACE" then
        local p = view.piece
        local dropped = 0
        while Fits(view, p.kind, p.rot, p.x, p.y + 1) do
            p.y = p.y + 1
            dropped = dropped + 1
        end
        if dropped > 0 then p.lastRot = false end
        view:SetScore(view.score + dropped * 2)
        W.Sfx("drop")
        Lock(view, true)
    end
    if view.running then self:Draw(view) end
end

function G:Step(view, dt)
    view.calloutTime = math.max(0, (view.calloutTime or 0) - dt)
    if view.flash then
        view.flash = view.flash - dt
        if view.flash <= 0 then Clear(view) end
        if view.running then self:Draw(view) end
        return
    end
    local p = view.piece
    if not p then return end
    local held = view.held or {}

    -- Auto-repeat: after DAS, one cell every ARR.
    local das = view.das
    if das then
        if not held[das.key] then
            view.das = nil
        else
            das.t = das.t - dt
            while das.t <= 0 do
                if not Shift(view, das.dx) then das.t = 0 break end
                das.t = das.t + ARR
            end
        end
    end

    -- Gravity (several rows a frame at high levels); soft drop is 20x.
    local soft = held.DOWN or held.S
    local g = G.Gravity(view.level)
    if soft then g = g / SOFT_FACTOR end
    view.fall = view.fall + dt
    while view.fall >= g do
        if Grounded(view) then
            view.fall = 0
            break
        end
        view.fall = view.fall - g
        p.y = p.y + 1
        p.lastRot = false
        if soft then view:SetScore(view.score + 1) end
        if p.y > p.lowest then p.lowest, p.resets, p.lockT = p.y, 0, 0 end
    end

    -- Lock delay while resting on something.
    if Grounded(view) then
        p.lockT = p.lockT + dt
        if p.lockT >= LOCK_DELAY or p.resets >= MAX_RESETS then
            Lock(view)
        end
    end
    if view.running then self:Draw(view) end
end

local function Block(view, x, y, color, alpha, size)
    local t = view.blocks:Get()
    t:SetVertexColor(color[1], color[2], color[3])
    t:SetAlpha(alpha or 1)
    t:SetSize(size or CELL, size or CELL)
    K.Place(t, view.canvas, x, y)
end

-- A small piece in the hold / next boxes, centred on (cx, cy).
local function Preview(view, kind, cx, cy, size, dim)
    local p = PIECES[kind]
    local minX, maxX, minY, maxY = 9, -1, 9, -1
    for _, c in ipairs(p.cells) do
        minX, maxX = math.min(minX, c[1]), math.max(maxX, c[1])
        minY, maxY = math.min(minY, c[2]), math.max(maxY, c[2])
    end
    local w, h = (maxX - minX + 1) * size, (maxY - minY + 1) * size
    local col = dim and { 0.4, 0.4, 0.4 } or p.color
    for _, c in ipairs(p.cells) do
        Block(view, cx - w / 2 + (c[1] - minX + 0.5) * size, cy - h / 2 + (c[2] - minY + 0.5) * size, col, 1, size)
    end
end

function G:Draw(view)
    view.blocks:Begin()
    local flashing = {}
    for _, y in ipairs(view.flashRows or {}) do flashing[y] = true end
    local blink = math.floor((view.flash or 0) * 20) % 2 == 0
    for y = 0, ROWS - 1 do
        for x = 0, COLS - 1 do
            local kind = view.board[y][x]
            if kind then
                local col = (flashing[y] and blink) and { 1, 1, 1 } or PIECES[kind].color
                Block(view, BX + x * CELL + CELL / 2, y * CELL + CELL / 2, col)
            end
        end
    end
    local p = view.piece
    if p then
        local gy = p.y
        while Fits(view, p.kind, p.rot, p.x, gy + 1) do gy = gy + 1 end
        local col = PIECES[p.kind].color
        for _, c in ipairs(Cells(p.kind, p.rot)) do
            if gy ~= p.y and c[2] + gy >= 0 then
                Block(view, BX + (c[1] + p.x) * CELL + CELL / 2, (c[2] + gy) * CELL + CELL / 2, col, 0.22)
            end
        end
        -- Fades a little as the lock timer runs out.
        local fade = Grounded(view) and (1 - 0.35 * (p.lockT / LOCK_DELAY)) or 1
        for _, c in ipairs(Cells(p.kind, p.rot)) do
            if c[2] + p.y >= 0 then
                Block(view, BX + (c[1] + p.x) * CELL + CELL / 2, (c[2] + p.y) * CELL + CELL / 2, col, fade)
            end
        end
    end
    if view.hold then Preview(view, view.hold, 36, 46, 12, view.holdUsed) end
    local nx = BX + COLS * CELL + 39
    for i = 1, 5 do
        local kind = view.queue[i]
        if kind then
            if i == 1 then
                Preview(view, kind, nx, 46, 12)
            else
                Preview(view, kind, nx, 70 + i * 36, 9)
            end
        end
    end
    view.blocks:End()
    view.linesText:SetText(tostring(view.lines))
    view.levelText:SetText(tostring(view.level))
    view.callout:SetShown((view.calloutTime or 0) > 0)
end

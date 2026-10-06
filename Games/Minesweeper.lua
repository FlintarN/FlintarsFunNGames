-- Minesweeper: a solo Arcade game. Clear the field without hitting a mine.
-- The first click is always safe; empty areas open up by themselves.
-- Your score is your time, so lower is better.
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games
local W = setmetatable({}, { __index = function(_, k) return ns.Widgets[k] end })

local G = {
    key = "mines",
    arcade = true,
    solo = true,
    name = "Minesweeper",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconMines",
    short = "Clear the field, flag the mines. Beat your fastest time.",
    how = "Left-click to open a square, right-click to flag a mine. Numbers tell how many mines touch that square.",
    rules = "Open every square that isn't a mine. A number shows how many of the eight squares around it hide mines.",
    scoreLabel = "Time",
    lowerIsBetter = true,
    canvas = { 312, 312 },
    keys = {},
    fields = {},
}
ns.Games.mines = G

local N, MINES, CELL = 12, 22, 26
local NUM_COLORS = {
    { 0.25, 0.45, 1 }, { 0.2, 0.7, 0.25 }, { 0.9, 0.25, 0.25 }, { 0.45, 0.25, 0.85 },
    { 0.7, 0.35, 0.1 }, { 0.1, 0.65, 0.65 }, { 0.15, 0.15, 0.15 }, { 0.5, 0.5, 0.5 },
}

function G.FormatScore(t)
    t = math.floor(t or 0)
    return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

function G:Build(view)
    local cv = view.canvas
    view.cells = {}
    for r = 1, N do
        view.cells[r] = {}
        for c = 1, N do
            local f = CreateFrame("Frame", nil, cv)
            f:SetSize(CELL - 1, CELL - 1)
            f:SetPoint("TOPLEFT", (c - 1) * CELL, -(r - 1) * CELL)
            f.bg = f:CreateTexture(nil, "BACKGROUND")
            f.bg:SetAllPoints()
            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetPoint("TOPLEFT", 3, -3)
            f.icon:SetPoint("BOTTOMRIGHT", -3, 3)
            f.text = W.Label(f, "", "GameFontNormalLarge")
            f.text:SetPoint("CENTER", 0, 1)
            f.text:SetShadowOffset(0, 0)
            view.cells[r][c] = f
        end
    end
    view.left = W.Label(view.panel, "", "GameFontNormal")
    view.left:SetPoint("BOTTOMLEFT", 12, 8)
end

local function Around(r, c, fn)
    for dr = -1, 1 do
        for dc = -1, 1 do
            local rr, cc = r + dr, c + dc
            if (dr ~= 0 or dc ~= 0) and rr >= 1 and rr <= N and cc >= 1 and cc <= N then fn(rr, cc) end
        end
    end
end

function G:Start(view)
    view.mine, view.open, view.flag, view.near = {}, {}, {}, {}
    for r = 1, N do view.mine[r], view.open[r], view.flag[r], view.near[r] = {}, {}, {}, {} end
    view.placed, view.time, view.opened, view.boom = false, 0, 0, nil
end

-- Mines go down after the first click, never on or next to it.
local function Lay(view, r0, c0)
    local count = 0
    while count < MINES do
        local r, c = math.random(1, N), math.random(1, N)
        if not view.mine[r][c] and (math.abs(r - r0) > 1 or math.abs(c - c0) > 1) then
            view.mine[r][c] = true
            count = count + 1
        end
    end
    for r = 1, N do
        for c = 1, N do
            local n = 0
            Around(r, c, function(rr, cc) if view.mine[rr][cc] then n = n + 1 end end)
            view.near[r][c] = n
        end
    end
    view.placed = true
end

-- Open a square; empty ones open everything around them.
local function Open(view, r, c)
    local stack = { { r, c } }
    while #stack > 0 do
        local rc = table.remove(stack)
        local rr, cc = rc[1], rc[2]
        if not view.open[rr][cc] and not view.flag[rr][cc] then
            view.open[rr][cc] = true
            view.opened = view.opened + 1
            if view.near[rr][cc] == 0 then
                Around(rr, cc, function(r2, c2) table.insert(stack, { r2, c2 }) end)
            end
        end
    end
end

function G:Click(view, x, y, button)
    local r, c = math.floor(y / CELL) + 1, math.floor(x / CELL) + 1
    if r < 1 or r > N or c < 1 or c > N then return end
    self:Press(view, r, c, button)
end

function G:Press(view, r, c, button)
    if view.open[r][c] then return end
    if button == "RightButton" then
        view.flag[r][c] = not view.flag[r][c] or nil
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
        return self:Draw(view)
    end
    if view.flag[r][c] then return end
    if not view.placed then Lay(view, r, c) end
    if view.mine[r][c] then
        view.boom = { r, c }
        self:Draw(view)
        W.PlaySound("RAID_WARNING")
        return view:Over(nil, "Boom!")
    end
    Open(view, r, c)
    self:Draw(view)
    if view.opened == N * N - MINES then
        view:Over(math.floor(view.time), "Cleared!")
    end
end

function G:Step(view, dt)
    if view.placed then
        view.time = view.time + dt
        view:SetScore(math.floor(view.time))
    end
end

function G:Draw(view)
    local flags = 0
    for r = 1, N do
        for c = 1, N do
            local f = view.cells[r][c]
            local open = view.open[r][c]
            local showMine = view.boom and view.mine[r][c]
            if open then
                f.bg:SetColorTexture(0.17, 0.18, 0.21, 1)
            else
                local v = ((r + c) % 2 == 0) and 0.42 or 0.38
                f.bg:SetColorTexture(v, v + 0.02, v + 0.06, 1)
            end
            if view.boom and view.boom[1] == r and view.boom[2] == c then f.bg:SetColorTexture(0.7, 0.12, 0.12, 1) end
            if showMine then
                f.icon:SetTexture(K.ART .. "MineBomb")
                f.icon:Show()
            elseif view.flag[r][c] then
                f.icon:SetTexture(K.ART .. "MineFlag")
                f.icon:Show()
                flags = flags + 1
            else
                f.icon:Hide()
            end
            local n = open and view.near[r][c] or 0
            f.text:SetText(n > 0 and tostring(n) or "")
            if n > 0 then
                local col = NUM_COLORS[n]
                f.text:SetTextColor(col[1], col[2], col[3])
            end
        end
    end
    view.left:SetText("Mines left: " .. (MINES - flags))
end

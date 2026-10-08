-- Candy Crush: a solo Arcade match-3 with the raid target icons. Swap two
-- neighbours to line up three or more. Four or more in a line leaves a
-- Skull: swap it to blow up everything around it. 25 moves per run.
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games
local W = setmetatable({}, { __index = function(_, k) return ns.Widgets[k] end })

local G = {
    key = "candycrush",
    arcade = true,
    solo = true,
    name = "Candy Crush",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconCandyCrush",
    short = "Match three raid marks or more. Make Skulls, chain combos.",
    how = "Click a mark, then a neighbour to swap them. Line up 3+ of a kind. Four or more makes a Skull bomb. P pauses.",
    rules = "Swap neighbouring marks to make lines of three or more. You have 25 moves.",
    canvas = { 312, 312 },
    keys = {},
    fields = {},
}
ns.Games.candycrush = G

local N, CELL, MOVES = 8, 38, 25
local SKULL = 7
local KINDS = 6
-- Index into UI-RaidTargetingIcons (4 x 4): star, circle, diamond, triangle, moon, cross; skull.
local ICON = { 1, 2, 3, 4, 5, 7, [SKULL] = 8 }
local FALL_SPEED, SWAP_SPEED = 11, 7
G.N, G.SKULL, G.MOVES = N, SKULL, MOVES

local function IconCoords(t, i)
    i = ICON[i] - 1
    local x, y = (i % 4) * 0.25, math.floor(i / 4) * 0.25
    t:SetTexCoord(x, x + 0.25, y, y + 0.25)
end

function G:Build(view)
    local cv = view.canvas
    cv.bg:SetColorTexture(0.1, 0.07, 0.13, 1)
    for r = 1, N do
        for c = 1, N do
            local t = cv:CreateTexture(nil, "BACKGROUND", nil, 1)
            local v = ((r + c) % 2 == 0) and 0.06 or 0.03
            t:SetColorTexture(1, 1, 1, v)
            t:SetSize(CELL, CELL)
            t:SetPoint("TOPLEFT", (c - 1) * CELL + 4, -(r - 1) * CELL - 4)
        end
    end
    view.select = cv:CreateTexture(nil, "BORDER")
    view.select:SetColorTexture(1, 0.82, 0, 0.35)
    view.select:SetSize(CELL, CELL)
    view.gemPool = K.Pool(cv, function(parent)
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        return t
    end)
    view.movesText = W.Label(view.panel, "", "GameFontNormal")
    view.movesText:SetPoint("BOTTOMLEFT", 12, 8)
    view.comboText = W.BigLabel(cv, 26, "GameFontNormalHuge")
    view.comboText:SetPoint("CENTER")
end

local function Center(c, r) return 4 + (c - 0.5) * CELL, 4 + (r - 0.5) * CELL end

local function NewGem(kind, c, r)
    return { kind = kind, px = c, py = r }
end

-- Runs of three or more: returns a set of "r,c" keys and the runs.
local function Find(grid)
    local hit, runs = {}, {}
    local function Scan(getter, horizontal)
        for a = 1, N do
            local b = 1
            while b <= N do
                local g = getter(a, b)
                local len = 1
                while g and g.kind ~= SKULL and b + len <= N do
                    local h = getter(a, b + len)
                    if not h or h.kind ~= g.kind then break end
                    len = len + 1
                end
                if g and g.kind ~= SKULL and len >= 3 then
                    local cells = {}
                    for k = 0, len - 1 do
                        local r, c = horizontal and a or b + k, horizontal and b + k or a
                        hit[r .. "," .. c] = true
                        table.insert(cells, { r, c })
                    end
                    table.insert(runs, cells)
                end
                b = b + len
            end
        end
    end
    Scan(function(r, c) return grid[r][c] end, true)
    Scan(function(c, r) return grid[r][c] end, false)
    return hit, runs
end
G.Find = Find

local function Fill(view)
    view.grid = {}
    for r = 1, N do
        view.grid[r] = {}
        for c = 1, N do
            local kind
            repeat
                kind = math.random(KINDS)
                local left = c > 2 and view.grid[r][c - 1].kind == kind and view.grid[r][c - 2].kind == kind
                local up = r > 2 and view.grid[r - 1][c].kind == kind and view.grid[r - 2][c].kind == kind
            until not left and not up
            view.grid[r][c] = NewGem(kind, c, r - N - 1) -- drop in from above
        end
    end
end

local function Swapped(grid, r1, c1, r2, c2)
    grid[r1][c1], grid[r2][c2] = grid[r2][c2], grid[r1][c1]
end

local function HasMove(grid)
    for r = 1, N do
        for c = 1, N do
            if grid[r][c].kind == SKULL then return true end
            for _, d in ipairs({ { 0, 1 }, { 1, 0 } }) do
                local r2, c2 = r + d[1], c + d[2]
                if r2 <= N and c2 <= N then
                    Swapped(grid, r, c, r2, c2)
                    local hit = next((Find(grid)))
                    Swapped(grid, r, c, r2, c2)
                    if hit then return true end
                end
            end
        end
    end
    return false
end
G.HasMove = HasMove

function G:Start(view)
    Fill(view)
    view.moves, view.combo, view.sel = MOVES, 0, nil
    view.dying, view.pending, view.resolving = {}, nil, true
    view.comboTime = 0
end

local function Kill(view, r, c)
    local g = view.grid[r][c]
    if not g then return 0 end
    view.grid[r][c] = nil
    g.t = 0
    table.insert(view.dying, g)
    return 1
end

local function Explode(view, r, c)
    local n = 0
    for rr = r - 1, r + 1 do
        for cc = c - 1, c + 1 do
            if rr >= 1 and rr <= N and cc >= 1 and cc <= N then n = n + Kill(view, rr, cc) end
        end
    end
    view:SetScore(view.score + n * 15)
    W.Sfx("special")
end

-- Gems fall into the gaps, new ones drop in from the top.
local function Collapse(view)
    for c = 1, N do
        local write = N
        for r = N, 1, -1 do
            local g = view.grid[r][c]
            if g then
                view.grid[r][c] = nil
                view.grid[write][c] = g
                write = write - 1
            end
        end
        for r = write, 1, -1 do
            view.grid[r][c] = NewGem(math.random(KINDS), c, r - write - 0.5)
        end
    end
end

function G:Swap(view, r1, c1, r2, c2)
    if view.resolving or view.moves <= 0 then return end
    if math.abs(r1 - r2) + math.abs(c1 - c2) ~= 1 then return end
    local grid = view.grid
    Swapped(grid, r1, c1, r2, c2)
    view.sel = nil
    view.combo = 0
    view.resolving = true
    view.lastSwap = { r2, c2 }
    if grid[r2][c2].kind == SKULL or grid[r1][c1].kind == SKULL then
        view.moves = view.moves - 1
        if grid[r2][c2].kind == SKULL then Explode(view, r2, c2) end
        if grid[r1][c1] and grid[r1][c1].kind == SKULL then Explode(view, r1, c1) end
        return
    end
    W.Sfx("swap")
    if next((Find(grid))) then
        view.moves = view.moves - 1
    else
        view.pending = { r1, c1, r2, c2 } -- no match: swap back once it lands
    end
end

function G:Click(view, x, y)
    local c, r = math.floor((x - 4) / CELL) + 1, math.floor((y - 4) / CELL) + 1
    if r < 1 or r > N or c < 1 or c > N or view.resolving then return end
    local s = view.sel
    if s and math.abs(s[1] - r) + math.abs(s[2] - c) == 1 then
        return self:Swap(view, s[1], s[2], r, c)
    end
    -- Clicking the selected candy again lets go of it. (Not `x and nil or y`:
    -- that's never nil in Lua.)
    if s and s[1] == r and s[2] == c then view.sel = nil else view.sel = { r, c } end
    W.Sfx("click")
    self:Draw(view)
end

-- One pass of the cascade once everything has landed.
local function Resolve(view)
    local hit, runs = Find(view.grid)
    if next(hit) then
        view.combo = view.combo + 1
        local skulls = {}
        for _, run in ipairs(runs) do
            if #run >= 4 then
                -- The Skull stays where you swapped, or mid-run in a cascade.
                local at = run[math.ceil(#run / 2)]
                for _, rc in ipairs(run) do
                    if view.lastSwap and rc[1] == view.lastSwap[1] and rc[2] == view.lastSwap[2] then at = rc end
                end
                table.insert(skulls, at)
            end
        end
        local n = 0
        for key in pairs(hit) do
            local r, c = key:match("(%d+),(%d+)")
            n = n + Kill(view, tonumber(r), tonumber(c))
        end
        for _, at in ipairs(skulls) do
            view.grid[at[1]][at[2]] = NewGem(SKULL, at[2], at[1])
        end
        view:SetScore(view.score + n * 10 * view.combo + #skulls * 50)
        if view.combo >= 2 then
            view.comboText:SetText("Combo x" .. view.combo)
            view.comboTime = 0.9
        end
        view.pending = nil
        W.Sfx(view.combo >= 3 and "combo" or #skulls > 0 and "special" or "match")
        return
    end
    if view.pending then
        local p = view.pending
        view.pending = nil
        Swapped(view.grid, p[1], p[2], p[3], p[4])
        W.Sfx("wrong")
        return
    end
    view.resolving, view.lastSwap = false, nil
    if view.moves <= 0 then return view:Over(view.score, "Out of moves") end
    if not HasMove(view.grid) then
        -- Stuck: shuffle the board.
        local kinds = {}
        for r = 1, N do for c = 1, N do table.insert(kinds, view.grid[r][c].kind) end end
        repeat
            for i = #kinds, 2, -1 do
                local j = math.random(i)
                kinds[i], kinds[j] = kinds[j], kinds[i]
            end
            local i = 0
            for r = 1, N do for c = 1, N do i = i + 1; view.grid[r][c].kind = kinds[i] end end
        until HasMove(view.grid) and not next((Find(view.grid)))
    end
end

function G:Step(view, dt)
    local moving = false
    for r = 1, N do
        for c = 1, N do
            local g = view.grid[r][c]
            if g then
                local speed = (g.py < r - 1.01) and FALL_SPEED or SWAP_SPEED
                local step = speed * dt
                if g.px ~= c then
                    g.px = g.px + math.max(-step, math.min(step, c - g.px))
                    moving = true
                end
                if g.py ~= r then
                    g.py = g.py + math.max(-step, math.min(step, r - g.py))
                    moving = true
                end
            end
        end
    end
    for i = #view.dying, 1, -1 do
        local g = view.dying[i]
        g.t = g.t + dt
        if g.t >= 0.2 then table.remove(view.dying, i) end
    end
    view.comboTime = math.max(0, view.comboTime - dt)
    if not moving and #view.dying == 0 and view.resolving then
        local holes = false
        for r = 1, N do for c = 1, N do if not view.grid[r][c] then holes = true end end end
        if holes then Collapse(view) else Resolve(view) end
    end
    self:Draw(view)
end

function G:Draw(view)
    local cv = view.canvas
    view.gemPool:Begin()
    local function Gem(g, size, alpha)
        local t = view.gemPool:Get()
        IconCoords(t, g.kind)
        t:SetSize(size, size)
        t:SetAlpha(alpha)
        local x, y = Center(g.px, g.py)
        K.Place(t, cv, x, y)
    end
    for r = 1, N do
        for c = 1, N do
            local g = view.grid[r][c]
            if g then Gem(g, CELL - 6, 1) end -- the canvas clips the ones still above
        end
    end
    for _, g in ipairs(view.dying) do
        local k = g.t / 0.2
        Gem(g, (CELL - 6) * (1 + k * 0.5), 1 - k)
    end
    view.gemPool:End()
    if view.sel then
        view.select:Show()
        view.select:ClearAllPoints()
        view.select:SetPoint("TOPLEFT", (view.sel[2] - 1) * CELL + 4, -(view.sel[1] - 1) * CELL - 4)
    else
        view.select:Hide()
    end
    view.comboText:SetShown(view.comboTime > 0)
    view.movesText:SetText("Moves left: " .. view.moves)
end

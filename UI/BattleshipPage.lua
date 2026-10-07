-- BattleshipPage: your fleet on the left, the enemy's waters on the right.
-- Placing: hover to preview (green fits, red doesn't), click to place,
-- right-click or Rotate to turn, click a placed ship to pick it up again.
-- Battle: click a square in the enemy's waters on your turn.
local ADDON, ns = ...

local W = ns.Widgets
local C = ns.Cards
local A = ns.Arcade
local P = setmetatable({}, { __index = A })
P.__index = P
ns.BattleshipPage = P

local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"
local CELL, GAP = 25, 2

local function Session(self) return ns.Session.Get(self.kind) end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function BuildGrid(self, panel, mine)
    local G = self.G
    local N = G.SIZE
    local grid = CreateFrame("Frame", nil, panel)
    local size = N * CELL + (N - 1) * GAP
    grid:SetSize(size, size)
    grid:SetPoint("TOP", 7, -42)
    local cells = {}
    for r = 1, N do
        cells[r] = {}
        local rl = W.Label(grid, tostring(r), "GameFontDisableSmall")
        rl:SetPoint("RIGHT", grid, "TOPLEFT", -4, -(r - 1) * (CELL + GAP) - CELL / 2)
        for c = 1, N do
            if r == 1 then
                local cl = W.Label(grid, string.char(64 + c), "GameFontDisableSmall")
                cl:SetPoint("BOTTOM", grid, "TOPLEFT", (c - 1) * (CELL + GAP) + CELL / 2, 2)
            end
            local b = CreateFrame("Button", nil, grid)
            b:SetSize(CELL, CELL)
            b:SetPoint("TOPLEFT", (c - 1) * (CELL + GAP), -(r - 1) * (CELL + GAP))
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b.water = b:CreateTexture(nil, "BACKGROUND")
            b.water:SetAllPoints()
            local v = ((r + c) % 2 == 0) and 0.02 or 0
            b.water:SetColorTexture(0.10 + v, 0.24 + v, 0.42 + v, 1)
            b.ship = b:CreateTexture(nil, "BORDER")
            b.ship:SetPoint("TOPLEFT", 1, -1)
            b.ship:SetPoint("BOTTOMRIGHT", -1, 1)
            b.ship:SetTexture(ART .. "BsShip")
            b.ship:Hide()
            b.preview = b:CreateTexture(nil, "ARTWORK")
            b.preview:SetAllPoints()
            b.preview:Hide()
            b.mark = b:CreateTexture(nil, "OVERLAY")
            b.mark:SetSize(CELL, CELL)
            b.mark:SetPoint("CENTER")
            b.mark:Hide()
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.15)
            b.r, b.c = r, c
            if mine then
                b:SetScript("OnEnter", function() self:Preview(r, c) end)
                b:SetScript("OnLeave", function() self:Preview(nil) end)
                b:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then self:Rotate() else self:PlaceAt(r, c) end
                end)
            else
                b:SetScript("OnClick", function() self:Fire(r, c) end)
            end
            cells[r][c] = b
        end
    end
    return cells
end

function P:BuildGame(v)
    self.banner = W.Label(v, "", "GameFontNormal")
    self.banner:SetPoint("TOP", 0, -2)

    local left = W.Panel(v, "Your fleet")
    left:SetPoint("TOPLEFT", 0, -20)
    left:SetPoint("BOTTOMLEFT", 0, 64)
    left:SetWidth(265)
    self.leftPanel = left
    local right = W.Panel(v, "Enemy waters")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 64)
    self.rightPanel = right

    self.myCells = BuildGrid(self, left, true)
    self.theirCells = BuildGrid(self, right, false)
    self.myInfo = W.Label(left, "", "GameFontHighlightSmall")
    self.myInfo:SetPoint("BOTTOMLEFT", 10, 8)
    self.myInfo:SetPoint("RIGHT", -10, 0)
    self.myInfo:SetJustifyH("LEFT")
    self.theirInfo = W.Label(right, "", "GameFontHighlightSmall")
    self.theirInfo:SetPoint("BOTTOMLEFT", 10, 8)
    self.theirInfo:SetPoint("RIGHT", -10, 0)
    self.theirInfo:SetJustifyH("LEFT")

    -- Placing controls, on the row above the buttons.
    local function Small(text, w, fn, help)
        local b = W.Button(v, text, w, fn, 20)
        W.Tooltip(b, text, help)
        return b
    end
    self.placeLabel = W.Label(v, "", "GameFontNormal")
    self.placeLabel:SetPoint("BOTTOMLEFT", 6, 40)
    self.rotate = Small("Rotate", 64, function() self:Rotate() end, "Turn the ship (or right-click the board).")
    self.random = Small("Random", 64, function() self:RandomFleet() end, "Place the whole fleet at random.")
    self.clear = Small("Clear", 54, function() self:ClearFleet() end, "Take all your ships off the board.")
    self.ready = Small("Ready", 64, function() self:Ready() end, "Lock your fleet in. Only a sealed fingerprint of it is sent.")
    self.ready:SetPoint("BOTTOMRIGHT", 0, 36)
    self.clear:SetPoint("RIGHT", self.ready, "LEFT", -4, 0)
    self.random:SetPoint("RIGHT", self.clear, "LEFT", -4, 0)
    self.rotate:SetPoint("RIGHT", self.random, "LEFT", -4, 0)
end

function P:BuildButtons(v)
    local S, kind = ns.Session, self.kind
    self.buttons = {}
    local function Add(key, text, w, onClick, title, help)
        local b = W.Button(v, text, w, onClick, 26)
        if title then W.Tooltip(b, title, help) end
        self.buttons[key] = b
        return b
    end
    Add("join", "Join", 70, function() S.Join(kind) end, "Join", "Take the empty seat.")
    Add("leave", "Leave", 70, function() S.Leave(kind) end, "Leave", "Leave the lobby.")
    Add("bot", "+ Bot", 64, function() S.AddBot(kind) end, "Add a bot", "Play a bot (practice only).")
    Add("start", "Start", 80, function() S.Start(kind) end, "Start", "Both players place their ships.")
    Add("rematch", "Rematch", 90, function() S.Act(kind, "rematch") end, "Rematch", "Play again; the other player fires first.")
    Add("cancel", "Close lobby", 100, function()
        W.Confirm("Close this lobby?", function() self:CloseLobby() end)
    end, "Close lobby", "End the lobby for everyone.")
    Add("close", "Close", 70, function() S.Dismiss(kind) end, "Close", "Put the game away.")
    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 4, 9)
    self.hint:SetJustifyH("LEFT")
end

function P.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind], horiz = true }, P)
    A.BuildSetup(self, parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    self:BuildGame(v)
    self:BuildButtons(v)
    return self
end


---------------------------------------------------------------------------
-- Placing your fleet
---------------------------------------------------------------------------
function P:Placing(s)
    s = s or Session(self)
    return s and s.phase == "rolling" and s.stage == "placing" and not s.ready[ns.Me()]
end

-- The next ship still to place (index), or nil when all are on the board.
function P:NextShip()
    for i in ipairs(self.G.SHIPS) do
        if not self.board:find(tostring(i), 1, true) then return i end
    end
end

function P:Preview(r, c)
    self.hover = r and { r, c } or nil
    self:DrawMine(Session(self))
end

function P:Rotate()
    self.horiz = not self.horiz
    self:DrawMine(Session(self))
end

function P:PlaceAt(r, c)
    if not self:Placing() then return end
    local G = self.G
    local here = G.Cell(self.board, r, c)
    if here ~= 0 then
        self.board = G.Remove(self.board, here) -- pick it up again
    else
        local i = self:NextShip()
        if not i then return end
        local cells = G.Cells(self.board, r, c, G.SHIPS[i].size, self.horiz)
        if not cells then return end
        self.board = G.Put(self.board, cells, i)
        W.Sfx("place")
    end
    self:Refresh()
end

function P:RandomFleet()
    if not self:Placing() then return end
    self.board = self.G.Random()
    self:Refresh()
end

function P:ClearFleet()
    if not self:Placing() then return end
    self.board = self.G.Empty()
    self:Refresh()
end

function P:Ready()
    local s = Session(self)
    if not (self:Placing(s) and self.G.Complete(self.board)) then return end
    local salt = ns.Fair.NewSecret()
    self.G.mine[s.id] = { board = self.board, salt = salt }
    ns.Session.Act(self.kind, "ready:" .. self.G.Seal(self.board, salt))
end

function P:Fire(r, c)
    local s = Session(self)
    if not (s and s.stage == "battle" and ns.Session.MyTurn(s)) or ns.Session.HostOffline(s) then return end
    ns.Session.Act(self.kind, "shot:" .. r .. "," .. c)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function Pop(tex, size)
    tex:SetSize(6, 6)
    C.Tween(0.25, function(t)
        local k = 6 + (size - 6) * t + math.sin(t * math.pi) * 6
        tex:SetSize(k, k)
    end)
end

-- One cell's marker: hit, miss or nothing (popping in when new). True when new.
local function Mark(cell, res, animate)
    local was = cell.res
    cell.res = res
    if res == "hit" then
        cell.mark:SetTexture(ART .. "BsHit")
        cell.mark:Show()
    elseif res == "miss" then
        cell.mark:SetTexture(ART .. "BsMiss")
        cell.mark:Show()
    else
        cell.mark:Hide()
    end
    if res and res ~= was and animate then
        Pop(cell.mark, CELL)
        return true
    end
end

function P:DrawMine(s)
    if not s then return end
    local G, me = self.G, ns.Me()
    local N = G.SIZE
    local shots = s.shots and s.shots[me] or {}
    -- Preview cells for the ship being placed.
    local preview, fits = {}, false
    if self.hover and self:Placing(s) and G.Cell(self.board, self.hover[1], self.hover[2]) == 0 then
        local i = self:NextShip()
        if i then
            local cells = G.Cells(self.board, self.hover[1], self.hover[2], G.SHIPS[i].size, self.horiz)
            fits = cells ~= nil
            if not cells then
                cells = {}
                for k = 0, G.SHIPS[i].size - 1 do
                    table.insert(cells, self.horiz and { self.hover[1], self.hover[2] + k } or { self.hover[1] + k, self.hover[2] })
                end
            end
            for _, rc in ipairs(cells) do preview[G.Key(rc[1], rc[2])] = true end
        end
    end
    local sunk = {}
    for _, i in ipairs(s.sunk and s.sunk[me] or {}) do sunk[i] = true end
    for r = 1, N do
        for c = 1, N do
            local cell = self.myCells[r][c]
            local ship = G.Cell(self.board, r, c)
            cell.ship:SetShown(ship ~= 0)
            if ship ~= 0 then
                local v = sunk[ship] and 0.45 or 1
                cell.ship:SetVertexColor(v, v, v)
            end
            if preview[G.Key(r, c)] then
                cell.preview:SetColorTexture(fits and 0.2 or 0.8, fits and 0.8 or 0.2, 0.2, 0.55)
                cell.preview:Show()
            else
                cell.preview:Hide()
            end
            if Mark(cell, shots[G.Key(r, c)], self.animate) then self.newShot = shots[G.Key(r, c)] end
        end
    end
end

function P:DrawTheirs(s)
    local G, me = self.G, ns.Me()
    local other
    for _, p in ipairs(s.players) do if p.name ~= me then other = p.name end end
    local shots = (other and s.shots and s.shots[other]) or {}
    local reveal = other and s.reveals and s.reveals[other]
    local canFire = s.stage == "battle" and ns.Session.MyTurn(s) and not ns.Session.HostOffline(s)
    for r = 1, G.SIZE do
        for c = 1, G.SIZE do
            local cell = self.theirCells[r][c]
            local res = shots[G.Key(r, c)]
            -- After the game, their ships show (where you never found them, faded).
            local ship = reveal and G.Cell(reveal.board, r, c) or 0
            cell.ship:SetShown(ship ~= 0)
            if ship ~= 0 then cell.ship:SetVertexColor(0.55, 0.55, 0.6, res and 1 or 0.6) end
            if Mark(cell, res, self.animate) then self.newShot = res end
            cell:SetEnabled(canFire and res == nil)
        end
    end
    return other
end

local function CheckText(s, name)
    local ok = ns.Games.battleship.Check(s, name)
    if ok == true then return " |TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t board checked" end
    if ok == false then return " |cffff5050board does NOT match!|r" end
    return ""
end

function P:Refresh()
    local s = Session(self)
    self.setup:SetShown(s == nil)
    self.game:SetShown(s ~= nil)
    if not s then return A.RefreshSetup(self) end
    local S, me, G = ns.Session, ns.Me(), self.G

    -- Your board: from your seal once ready, else the one you're placing.
    local key = s.id .. ":" .. tostring(s.games)
    if key ~= self.boardKey then
        self.boardKey = key
        local mine = G.mine[s.id]
        self.board = mine and mine.board or G.Empty()
        self.animate = false
    end
    if s.stage ~= "placing" and G.mine[s.id] then self.board = G.mine[s.id].board end

    local animate = self.animate
    self.newShot = nil
    self:DrawMine(s)
    local other = self:DrawTheirs(s)
    self.animate = true

    -- One sound for what just happened: the end, a sinking, or a shot.
    local sunkN = 0
    for _, list in pairs(s.sunk or {}) do sunkN = sunkN + #list end
    local ended = s.phase == "done" and s.result and s.result.winner and not self.cheered
    if ended then self.cheered = true elseif s.phase ~= "done" then self.cheered = nil end
    if animate then
        if ended then
            W.Sfx(s.result.winner == me and "win" or "lose")
        elseif sunkN > (self.sunkN or 0) then
            W.Sfx("sink")
        elseif self.newShot then
            W.Sfx(self.newShot)
        end
    end
    self.sunkN = sunkN

    self.banner:SetText(s.banner or (G:Status(s) or ""))
    local afloat = #G.SHIPS - #(s.sunk and s.sunk[me] or {})
    if s.phase == "lobby" then
        self.myInfo:SetText(A.ScopeLine(s))
        self.theirInfo:SetText(#s.players < 2 and "Waiting for an opponent..." or ("Opponent: " .. tostring(other)))
    else
        self.myInfo:SetText("Afloat: " .. afloat .. "/" .. #G.SHIPS .. "   Wins: " .. ((s.score and s.score[me]) or 0) .. CheckText(s, me))
        local theirs = other and (#G.SHIPS - #(s.sunk and s.sunk[other] or {})) or 0
        self.theirInfo:SetText(tostring(other) .. ": " .. theirs .. "/" .. #G.SHIPS .. " afloat   Wins: "
            .. ((other and s.score and s.score[other]) or 0) .. (other and CheckText(s, other) or ""))
    end

    -- Placing row
    local placing = self:Placing(s)
    for _, w in ipairs({ self.placeLabel, self.rotate, self.random, self.clear, self.ready }) do
        w:SetShown(s.phase == "rolling" and s.stage == "placing")
    end
    for _, b in ipairs({ self.rotate, self.random, self.clear }) do b:SetEnabled(placing) end
    self.ready:SetEnabled(placing and G.Complete(self.board))
    local nxt = self:NextShip()
    if s.ready and s.ready[me] then
        self.placeLabel:SetText("|cff40ff40Ready.|r Waiting for the other fleet...")
    elseif nxt then
        self.placeLabel:SetText("Place your " .. G.SHIPS[nxt].name .. " (" .. G.SHIPS[nxt].size .. ")  "
            .. (self.horiz and "across" or "down"))
    else
        self.placeLabel:SetText("Fleet placed. Click Ready.")
    end

    self:RefreshButtons(s)
end

function P:RefreshButtons(s)
    local S, me, G = ns.Session, ns.Me(), self.G
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local show = {
        join = S.CanJoin(s) and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and s.phase == "lobby",
        start = s.phase == "lobby" and host,
        rematch = host and (s.phase == "done" or s.phase == "rolling"),
        cancel = host and s.phase ~= "cancelled",
        close = (not host and (not S.IsActive(s) or S.HostOffline(s))) or s.phase == "cancelled",
    }
    local right
    for _, key in ipairs({ "close", "cancel", "rematch", "start", "bot", "leave", "join" }) do
        local b = self.buttons[key]
        b:SetShown(show[key] and true or false)
        if show[key] then
            b:ClearAllPoints()
            if right then b:SetPoint("RIGHT", right, "LEFT", -4, 0) else b:SetPoint("BOTTOMRIGHT", 0, 2) end
            right = b
        end
    end
    self.buttons.start:SetEnabled(#s.players >= G.minPlayers)
    self.buttons.rematch:SetEnabled(s.phase == "done")
    self.buttons.join:SetEnabled(not s._joining and #s.players < G.maxPlayers)
    self.buttons.bot:SetEnabled(S.CanAddBot(s))
    local hint = ""
    if s.stage == "battle" then
        hint = S.MyTurn(s) and "Your turn: fire at the enemy's waters." or (s.pending and "Waiting for the answer..." or "Their turn.")
    elseif s.phase == "done" then
        hint = host and "Rematch to play again." or "Waiting for a rematch..."
    end
    if S.HostOffline(s) then hint = W.HOST_OFFLINE end
    self.hint:SetText(hint)
    if right then self.hint:SetPoint("RIGHT", right, "LEFT", -8, 0) end
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.battleship = P.New

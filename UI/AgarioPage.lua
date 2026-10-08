-- AgarioPage: the arena. Lobby and setup come from the Arcade panel; the
-- arena is drawn with the Kit (canvas, pools, loop, keys) and shared with
-- the others through Live. Practice bots live only on this client.
local ADDON, ns = ...

local W = ns.Widgets
local K = ns.Kit
local A = ns.Arcade
local P = setmetatable({}, { __index = A })
P.__index = P
ns.AgarioPage = P

local FOOD_COLORS = {
    { 1, 0.35, 0.35 }, { 0.35, 1, 0.45 }, { 0.4, 0.55, 1 }, { 1, 0.9, 0.3 },
    { 1, 0.4, 1 }, { 0.35, 1, 1 }, { 1, 0.6, 0.2 }, { 0.75, 0.45, 1 },
}
local KEYS = { W = true, A = true, S = true, D = true, UP = true, DOWN = true, LEFT = true, RIGHT = true }

local function Session(self) return ns.Session.Get(self.kind) end
local function Dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function MakeBlob(canvas)
    local t = canvas:CreateTexture(nil, "ARTWORK")
    t:SetTexture(K.ART .. "Blob")
    return t
end

local function MakeLabel(canvas)
    local fs = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local face = fs:GetFont()
    if face then fs:SetFont(face, 10, "OUTLINE") end
    return fs
end

local function MakeLine(canvas)
    local t = canvas:CreateTexture(nil, "BACKGROUND", nil, 2)
    t:SetColorTexture(1, 1, 1, 0.05)
    return t
end

function P:BuildGame(v)
    local G = self.G
    local c = K.Canvas(v)
    c:SetPoint("TOPLEFT")
    c:SetPoint("BOTTOMRIGHT", 0, 34)
    self.canvas = c

    -- The arena floor (lighter than the outside) and its edge.
    self.floor = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    self.floor:SetColorTexture(0.09, 0.11, 0.14, 1)
    self.edges = {}
    for i = 1, 4 do
        local e = c:CreateTexture(nil, "BACKGROUND", nil, 3)
        e:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.5)
        self.edges[i] = e
    end
    self.lines = K.Pool(c, MakeLine)
    self.foodPool = K.Pool(c, function(cv)
        local t = cv:CreateTexture(nil, "BORDER")
        t:SetTexture(K.ART .. "Blob")
        return t
    end)
    self.blobs = K.Pool(c, MakeBlob)
    self.labels = K.Pool(c, MakeLabel)

    -- Overlays
    self.size = W.Label(c, "", "GameFontNormal")
    self.size:SetPoint("TOPLEFT", 8, -8)
    self.best = W.Label(c, "", "GameFontDisableSmall")
    self.best:SetPoint("TOPLEFT", self.size, "BOTTOMLEFT", 0, -3)
    local board = CreateFrame("Frame", nil, c)
    board:SetSize(140, 92)
    board:SetPoint("TOPRIGHT", -6, -6)
    local bbg = board:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints()
    bbg:SetColorTexture(0, 0, 0, 0.45)
    local title = W.Label(board, "Top 5", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -4)
    self.rows = {}
    for i = 1, 5 do
        local r = W.Label(board, "", "GameFontHighlightSmall")
        r:SetPoint("TOPLEFT", 6, -6 - i * 14)
        r:SetPoint("RIGHT", -6, 0)
        r:SetJustifyH("LEFT")
        r:SetWordWrap(false)
        self.rows[i] = r
    end
    self.center = W.Label(c, "", "GameFontNormalLarge")
    self.center:SetPoint("CENTER", 0, 20)
    self.centerSub = W.Label(c, "", "GameFontHighlight")
    self.centerSub:SetPoint("TOP", self.center, "BOTTOM", 0, -6)
    self.scopeLine = W.Label(c, "", "GameFontDisableSmall")
    self.scopeLine:SetPoint("BOTTOMLEFT", 8, 6)

    c:SetScript("OnMouseDown", function()
        if self.me and not self.me.alive and self.rt then self:Respawn() end
    end)
    self.held = K.Keys(c, KEYS)
    K.Loop(c, function(dt) self:Step(dt) end)
    -- Leaving the arena view (tab switch, closing the window): stop sharing.
    c:SetScript("OnHide", function() self:Pause() end)
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
    Add("join", "Join", 70, function() S.Join(kind) end, "Join", "Join the arena.")
    Add("leave", "Leave", 70, function() S.Leave(kind) end, "Leave", "Leave the lobby.")
    Add("bot", "+ Bot", 64, function() S.AddBot(kind) end, "Add a bot", "A bot blob (practice only).")
    Add("start", "Open arena", 100, function() S.Start(kind) end, "Open arena", "Start: everyone in the lobby drops in.")
    Add("cancel", "Close arena", 100, function()
        W.Confirm("Close the arena for everyone?", function() self:CloseArena() end)
    end, "Close arena", "End it for everyone.")
    Add("close", "Leave arena", 90, function()
        local s = Session(self)
        if s and S.IsActive(s) then s.phase = "cancelled" end
        S.Dismiss(kind)
    end, "Leave", "Leave the arena.")
    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 4, 9)
    self.hint:SetJustifyH("LEFT")
end

function P.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind], food = {}, bots = {} }, P)
    A.BuildSetup(self, parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    self:BuildGame(v)
    self:BuildButtons(v)
    return self
end

---------------------------------------------------------------------------
-- The arena
---------------------------------------------------------------------------
function P:SpawnFood(i)
    local G = self.G
    self.food[i] = { x = math.random(10, G.ARENA_W - 10), y = math.random(10, G.ARENA_H - 10), c = math.random(#FOOD_COLORS) }
end

function P:Respawn()
    local G = self.G
    self.me = { x = math.random(80, G.ARENA_W - 80), y = math.random(80, G.ARENA_H - 80), r = G.START_R, alive = true }
    self.eatenBy = nil
end

-- Join the arena: food, a fresh blob, the Live link, keys.
function P:Enter(s)
    self.rt = ns.Live.Attach(s, {
        rate = 0.35, timeout = 6,
        onEvent = function(rt, sender, kind, data) self:OnEvent(sender, kind, data) end,
    })
    for i = 1, self.G.FOOD do self:SpawnFood(i) end
    self:Respawn()
    self.bots = {}
    if s.test then
        for _, p in ipairs(s.players) do
            if p.bot then self:NewBot(p.name, p.class) end
        end
    end
    self.canvas:KeysOn()
end

function P:Pause()
    if self.rt then
        ns.Live.Detach(self.rt.id)
        self.rt = nil
    end
    if self.canvas.KeysOff then self.canvas:KeysOff() end
    self:SaveBest()
end

function P:SaveBest()
    if not self.peak then return end
    ns.db.best = ns.db.best or {}
    ns.db.best.agario = math.max(ns.db.best.agario or 0, math.floor(self.peak))
end

-- Players I swallowed lately (name -> when): they go in my state for a few
-- seconds, so a victim who missed the "eat" message still finds out, and
-- I don't draw them again from a position they sent before they knew.
local ATE_FOR = 3

function P:OnEvent(sender, kind, data)
    if kind ~= "eat" then return end
    if data == ns.Me() then
        if self.me and self.me.alive then
            self.me.alive = false
            self.eatenBy = sender
            self:SaveBest()
            W.Sfx("eaten")
        end
    elseif self.rt then
        self.rt.peers[data] = nil
    end
end

---------------------------------------------------------------------------
-- Practice bots: chase smaller blobs, flee bigger ones, graze otherwise.
---------------------------------------------------------------------------
function P:NewBot(name, class)
    local G = self.G
    self.bots[name] = { name = name, class = class, x = math.random(80, G.ARENA_W - 80),
        y = math.random(80, G.ARENA_H - 80), r = G.START_R + math.random(0, 8), alive = true }
end

function P:StepBots(dt)
    local G = self.G
    for name, b in pairs(self.bots) do
        if not b.alive then
            b.dead = (b.dead or 0) + dt
            if b.dead > 3 then
                self:NewBot(name, b.class)
            end
        else
            -- Pick a target: something to eat, or a threat to run from.
            local tx, ty, flee
            local best = 220
            local others = { self.me }
            for _, o in pairs(self.bots) do if o ~= b and o.alive then table.insert(others, o) end end
            for _, o in ipairs(others) do
                if o and o.alive then
                    local d = Dist(b.x, b.y, o.x, o.y)
                    if d < best then
                        if o.r < b.r * G.EAT_RATIO then tx, ty, best, flee = o.x, o.y, d, false
                        elseif b.r < o.r * G.EAT_RATIO and d < 160 then tx, ty, best, flee = o.x, o.y, d, true end
                    end
                end
            end
            if not tx then
                local nearest = 1e9
                for _, f in ipairs(self.food) do
                    local d = Dist(b.x, b.y, f.x, f.y)
                    if d < nearest then nearest, tx, ty = d, f.x, f.y end
                end
            end
            local dx, dy = (tx or b.x) - b.x, (ty or b.y) - b.y
            if flee then dx, dy = -dx, -dy end
            local len = math.max(1, math.sqrt(dx * dx + dy * dy))
            local speed = G.SPEED * (G.START_R / b.r) ^ 0.45 * 0.85
            b.x = math.max(b.r, math.min(G.ARENA_W - b.r, b.x + dx / len * speed * dt))
            b.y = math.max(b.r, math.min(G.ARENA_H - b.r, b.y + dy / len * speed * dt))
            -- Bots eat dots and each other too.
            for i, f in ipairs(self.food) do
                if Dist(b.x, b.y, f.x, f.y) < b.r then
                    b.r = G.Feed(b.r)
                    self:SpawnFood(i)
                end
            end
            for _, o in pairs(self.bots) do
                if o ~= b and o.alive and o.r < b.r * G.EAT_RATIO and Dist(b.x, b.y, o.x, o.y) < b.r then
                    b.r = G.Swallow(b.r, o.r)
                    o.alive = false
                end
            end
            -- A bot can eat you.
            local me = self.me
            if me.alive and me.r < b.r * G.EAT_RATIO and Dist(b.x, b.y, me.x, me.y) < b.r then
                b.r = G.Swallow(b.r, me.r)
                self:OnEvent(name, "eat", ns.Me())
            end
            b.r = G.Decay(b.r, dt)
        end
    end
end

---------------------------------------------------------------------------
-- A frame
---------------------------------------------------------------------------
-- Everyone else: other players (smoothed) and practice bots.
function P:Others()
    local list = {}
    if self.rt then
        for name, p in pairs(self.rt.peers) do
            local st = ns.Live.Smooth(self.rt, p)
            -- Their state says they ate me (the "eat" message may have got lost).
            if type(p.state.a) == "table" and self.me and self.me.alive then
                for _, who in ipairs(p.state.a) do
                    if who == ns.Me() then self:OnEvent(name, "eat", who) end
                end
            end
            local ate = self.ate and self.ate[name]
            if ate and GetTime() - ate < ATE_FOR then st = nil end
            if st and st.x and st.r then
                table.insert(list, { name = name, x = st.x, y = st.y, r = st.r, class = st.c, peer = true })
            end
        end
    end
    for name, b in pairs(self.bots) do
        if b.alive then table.insert(list, { name = name, x = b.x, y = b.y, r = b.r, class = b.class, bot = b }) end
    end
    return list
end

-- A gulp, at most every 0.1 s.
function P:Gulp()
    local now = GetTime()
    if now - (self.gulpAt or -1) < 0.1 then return end
    self.gulpAt = now
    W.Sfx("eat")
end

function P:Move(dt)
    local G, me = self.G, self.me
    if not me.alive then return end
    local dx, dy = 0, 0
    local h = self.held
    if h.W or h.UP then dy = dy - 1 end
    if h.S or h.DOWN then dy = dy + 1 end
    if h.A or h.LEFT then dx = dx - 1 end
    if h.D or h.RIGHT then dx = dx + 1 end
    if dx == 0 and dy == 0 and IsMouseButtonDown and IsMouseButtonDown("LeftButton") and self.canvas:IsMouseOver() then
        dx, dy = K.MouseDir(self.canvas)
        dx, dy = dx or 0, dy or 0
    end
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        local speed = G.SPEED * (G.START_R / me.r) ^ 0.45
        me.x = math.max(me.r, math.min(G.ARENA_W - me.r, me.x + dx / len * speed * dt))
        me.y = math.max(me.r, math.min(G.ARENA_H - me.r, me.y + dy / len * speed * dt))
    end
    -- Dots
    for i, f in ipairs(self.food) do
        if Dist(me.x, me.y, f.x, f.y) < me.r then
            me.r = G.Feed(me.r)
            self:SpawnFood(i)
            self:Gulp()
        end
    end
    -- Smaller blobs
    for _, o in ipairs(self:Others()) do
        if o.r < me.r * G.EAT_RATIO and Dist(me.x, me.y, o.x, o.y) < me.r then
            me.r = G.Swallow(me.r, o.r)
            if o.bot then
                o.bot.alive = false
            else
                ns.Live.Event(self.rt, "eat", o.name)
                self.rt.peers[o.name] = nil
                self.ate = self.ate or {}
                self.ate[o.name] = GetTime()
            end
            self:Gulp()
        end
    end
    me.r = G.Decay(me.r, dt)
    self.peak = math.max(self.peak or 0, me.r) -- your biggest this time
end

function P:Step(dt)
    local s = Session(self)
    if not s then return end
    local seated = ns.Session.Find(s, ns.Me()) ~= nil
    if s.phase ~= "rolling" or not seated then
        if self.rt then self:Pause() end
        return self:DrawWaiting(s)
    end
    if not self.rt then self:Enter(s) end
    self:Move(dt)
    if s.test then self:StepBots(dt) end
    local me = self.me
    local ate
    for name, t in pairs(self.ate or {}) do
        if GetTime() - t < ATE_FOR then
            ate = ate or {}
            table.insert(ate, name)
        else
            self.ate[name] = nil
        end
    end
    ns.Live.SetMine(self.rt, me.alive and {
        x = math.floor(me.x), y = math.floor(me.y), r = math.floor(me.r * 10) / 10, c = ns.Session.ClassOf(ns.Me()),
        a = ate,
    } or nil)
    ns.Live.Tick(self.rt)
    self:Draw()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function P:DrawWaiting(s)
    self.lines:Begin() self.lines:End()
    self.foodPool:Begin() self.foodPool:End()
    self.blobs:Begin() self.blobs:End()
    self.labels:Begin() self.labels:End()
    for _, r in ipairs(self.rows) do r:SetText("") end
    self.size:SetText("")
    self.best:SetText("")
    local names = {}
    for _, p in ipairs(s.players) do table.insert(names, p.name) end
    if s.phase == "lobby" then
        self.center:SetText("Waiting for the arena to open")
        self.centerSub:SetText("In the lobby: " .. table.concat(names, ", "))
    elseif s.phase == "rolling" then
        self.center:SetText("The arena is open")
        self.centerSub:SetText("Click Join to drop in.")
    else
        self.center:SetText("The arena is closed")
        self.centerSub:SetText("")
    end
    self.scopeLine:SetText(A.ScopeLine(s))
end

function P:Draw()
    local G, me, c = self.G, self.me, self.canvas
    local cw, ch = c:GetWidth(), c:GetHeight()
    local camX, camY = me.x, me.y
    -- Zoom out smoothly as you grow.
    local target = G.Zoom(me.r)
    self.zoom = self.zoom and (self.zoom + (target - self.zoom) * 0.08) or target
    local z = self.zoom
    local function Screen(x, y) return (x - camX) * z + cw / 2, (y - camY) * z + ch / 2 end

    -- Floor, edges, grid
    local x0, y0 = Screen(0, 0)
    local x1, y1 = Screen(G.ARENA_W, G.ARENA_H)
    self.floor:ClearAllPoints()
    self.floor:SetPoint("TOPLEFT", c, "TOPLEFT", x0, -y0)
    self.floor:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", x1, -y1)
    local e = self.edges
    e[1]:ClearAllPoints() e[1]:SetPoint("TOPLEFT", c, "TOPLEFT", x0, -y0) e[1]:SetSize(x1 - x0, 2)
    e[2]:ClearAllPoints() e[2]:SetPoint("TOPLEFT", c, "TOPLEFT", x0, -y1) e[2]:SetSize(x1 - x0, 2)
    e[3]:ClearAllPoints() e[3]:SetPoint("TOPLEFT", c, "TOPLEFT", x0, -y0) e[3]:SetSize(2, y1 - y0)
    e[4]:ClearAllPoints() e[4]:SetPoint("TOPLEFT", c, "TOPLEFT", x1, -y0) e[4]:SetSize(2, y1 - y0)
    self.lines:Begin()
    for gx = 100, G.ARENA_W - 1, 100 do
        local sx = Screen(gx, 0)
        if sx > 0 and sx < cw then
            local l = self.lines:Get()
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", c, "TOPLEFT", sx, -math.max(0, y0))
            l:SetSize(1, math.min(ch, y1) - math.max(0, y0))
        end
    end
    for gy = 100, G.ARENA_H - 1, 100 do
        local _, sy = Screen(0, gy)
        if sy > 0 and sy < ch then
            local l = self.lines:Get()
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", c, "TOPLEFT", math.max(0, x0), -sy)
            l:SetSize(math.min(cw, x1) - math.max(0, x0), 1)
        end
    end
    self.lines:End()

    -- Food
    self.foodPool:Begin()
    for _, f in ipairs(self.food) do
        local sx, sy = Screen(f.x, f.y)
        if sx > -6 and sx < cw + 6 and sy > -6 and sy < ch + 6 then
            local t = self.foodPool:Get()
            local col = FOOD_COLORS[f.c]
            t:SetVertexColor(col[1], col[2], col[3])
            local fs = math.max(4, 9 * z)
            t:SetSize(fs, fs)
            K.Place(t, c, sx, sy)
        end
    end
    self.foodPool:End()

    -- Blobs, smallest first so bigger ones draw over them.
    local all = self:Others()
    if me.alive then table.insert(all, { name = ns.Me(), x = me.x, y = me.y, r = me.r, class = ns.Session.ClassOf(ns.Me()), mine = true }) end
    table.sort(all, function(a, b) return a.r < b.r end)
    self.blobs:Begin()
    self.labels:Begin()
    for i, o in ipairs(all) do
        local sx, sy = Screen(o.x, o.y)
        local rr = o.r * z
        if sx > -rr and sx < cw + rr and sy > -rr and sy < ch + rr then
            local t = self.blobs:Get()
            local col = K.ClassColor(o.class)
            t:SetVertexColor(col[1], col[2], col[3], o.mine and 1 or 0.92)
            t:SetSize(rr * 2, rr * 2)
            t:SetDrawLayer("ARTWORK", math.min(7, math.floor(i / 4) - 4))
            K.Place(t, c, sx, sy)
            if rr >= 12 then
                local l = self.labels:Get()
                l:SetText(o.name)
                K.Place(l, c, sx, sy)
            end
        end
    end
    self.blobs:End()
    self.labels:End()

    -- Leaderboard
    table.sort(all, function(a, b) return a.r > b.r end)
    for i, row in ipairs(self.rows) do
        local o = all[i]
        if o then
            row:SetText((o.mine and "|cff40ff40" or "|cffdddddd") .. i .. ". " .. o.name .. "  " .. math.floor(o.r) .. "|r")
        else
            row:SetText("")
        end
    end
    self.size:SetText(me.alive and ("Size " .. math.floor(me.r)) or "|cffff6060Eaten!|r")
    self.best:SetText("Best " .. math.max(ns.db.best and ns.db.best.agario or 0, math.floor(self.peak or me.r)))
    if me.alive then
        self.center:SetText("")
        self.centerSub:SetText("")
    else
        self.center:SetText("|cffff6060Eaten" .. (self.eatenBy and (" by " .. self.eatenBy) or "") .. "!|r")
        self.centerSub:SetText("Click to jump back in.")
    end
    self.scopeLine:SetText(A.ScopeLine(Session(self)))
end

---------------------------------------------------------------------------
-- Lobby and buttons
---------------------------------------------------------------------------
function P:CloseArena()
    local S = ns.Session
    local s = Session(self)
    if not (s and S.IsHost(s)) then return end
    if s.phase == "rolling" then
        S.Act(self.kind, "end")
    elseif S.IsActive(s) then
        S.Cancel(self.kind)
    end
    S.Dismiss(self.kind)
end

function P:Refresh()
    local s = Session(self)
    self.setup:SetShown(s == nil)
    self.game:SetShown(s ~= nil)
    if not s then return A.RefreshSetup(self) end
    local S, me = ns.Session, ns.Me()
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local show = {
        join = S.CanJoin(s) and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and s.phase == "lobby",
        start = s.phase == "lobby" and host,
        cancel = host and S.IsActive(s),
        close = not host or not S.IsActive(s),
    }
    self.buttons.close:SetText(S.IsActive(s) and "Leave arena" or "Close")
    local right
    for _, key in ipairs({ "close", "cancel", "start", "bot", "leave", "join" }) do
        local b = self.buttons[key]
        b:SetShown(show[key] and true or false)
        if show[key] then
            b:ClearAllPoints()
            if right then b:SetPoint("RIGHT", right, "LEFT", -4, 0) else b:SetPoint("BOTTOMRIGHT", 0, 2) end
            right = b
        end
    end
    self.buttons.join:SetEnabled(not s._joining and #s.players < self.G.maxPlayers)
    self.buttons.bot:SetEnabled(S.CanAddBot(s))
    local hint = ""
    if s.phase == "rolling" and seated then hint = "W A S D or hold the left mouse button to move." end
    if s.phase == "lobby" then hint = #s.players .. " in the lobby." end
    if S.HostOffline(s) then hint = W.HOST_OFFLINE end
    self.hint:SetText(hint)
    if right then self.hint:SetPoint("RIGHT", right, "LEFT", -8, 0) end
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.agario = P.New

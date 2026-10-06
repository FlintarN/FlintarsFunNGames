-- Solo: the page every single-player Arcade game uses. The game area on
-- the left (a Kit canvas), the score, best, New game / Pause and a
-- leaderboard (You / Guild / Realm) on the right.
--
-- A solo game module only writes its rules and drawing:
--   G.solo = true, G.canvas = { w, h }, G.keys = { UP = true, ... }
--   G:Start(view)            a fresh game
--   G:Step(view, dt)         every frame while playing (optional)
--   G:Key(view, key)         a key went down (optional)
--   G:Click(view, x, y, btn) the canvas was clicked (optional; x, y from top-left)
--   G:Draw(view)             draw the current state
-- and calls view:SetScore(n) and view:Over(score, text) when the run ends.
local ADDON, ns = ...

local W = ns.Widgets
local K = ns.Kit
local So = {}
ns.Solo = So

local running = {} -- game key -> true while a run is going (its tab stays up)

function So.Running(kind)
    return running[kind] == true
end

-- For solo games with their own page (Hearthstone): keep the tab up while on.
function So.SetRunning(kind, on)
    running[kind] = on and true or nil
end

local P = {}
P.__index = P

local SCOPES = { { "me", "You" }, { "guild", "Guild" }, { "realm", "Realm" } }

function So.New(parent, kind)
    local G = ns.Games[kind]
    local self = setmetatable({ kind = kind, G = G, score = 0, board = "me" }, P)
    -- No lobby for solo games: the page is the game.
    self.setup = CreateFrame("Frame", nil, parent)
    self.setup:Hide()
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v

    -- The game area, centred in its panel.
    local panel = W.Panel(v)
    panel:SetPoint("TOPLEFT")
    panel:SetPoint("BOTTOMLEFT")
    panel:SetWidth(G.canvas[1] + 24)
    self.panel = panel
    local c = K.Canvas(panel)
    c:SetSize(G.canvas[1], G.canvas[2])
    c:SetPoint("CENTER")
    self.canvas = c
    -- P pauses in every solo game, except typing games where P is a letter.
    local keys = G.typing and {} or { P = true }
    for k in pairs(G.keys or {}) do keys[k] = true end
    self.held = K.Keys(c, keys, function(key)
        if key == "P" and not G.typing then return self:TogglePause() end
        if self.running and not self.paused and G.Key then G:Key(self, key) end
    end)
    c:SetScript("OnMouseDown", function(_, button)
        if not (self.running and not self.paused and G.Click) then return end
        local x, y = self:Cursor()
        G:Click(self, x, y, button)
    end)
    K.Loop(c, function(dt)
        if self.running and not self.paused and G.Step then G:Step(self, dt) end
    end)
    c:SetScript("OnHide", function() self:Pause(true) end)

    -- Overlay for paused / game over.
    self.overlay = CreateFrame("Frame", nil, c)
    self.overlay:SetAllPoints()
    self.overlay:SetFrameLevel(c:GetFrameLevel() + 20)
    local shade = self.overlay:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.6)
    self.overlayText = W.Label(self.overlay, "", "GameFontNormalHuge")
    self.overlayText:SetPoint("CENTER", 0, 14)
    self.overlaySub = W.Label(self.overlay, "", "GameFontHighlight")
    self.overlaySub:SetPoint("TOP", self.overlayText, "BOTTOM", 0, -8)
    self.overlaySub:SetWidth(G.canvas[1] - 30)

    -- Right side: score, best, buttons, leaderboard.
    local side = W.Panel(v, G.name)
    side:SetPoint("TOPLEFT", panel, "TOPRIGHT", 8, 0)
    side:SetPoint("BOTTOMRIGHT")
    local scoreLabel = W.Label(side, G.scoreLabel or "Score", "GameFontNormalSmall")
    scoreLabel:SetPoint("TOPLEFT", 12, -30)
    self.scoreText = W.BigLabel(side, 24, "GameFontNormalHuge")
    self.scoreText:SetPoint("TOPLEFT", scoreLabel, "BOTTOMLEFT", 0, -4)
    self.bestText = W.Label(side, "", "GameFontHighlightSmall")
    self.bestText:SetPoint("TOPLEFT", self.scoreText, "BOTTOMLEFT", 0, -4)
    self.newButton = W.Button(side, "New game", 90, function() self:Start() end, 22)
    self.newButton:SetPoint("TOPLEFT", 10, -96)
    self.pauseButton = W.Button(side, "Pause", 70, function() self:TogglePause() end, 22)
    self.pauseButton:SetPoint("LEFT", self.newButton, "RIGHT", 4, 0)
    W.Tooltip(self.pauseButton, "Pause", "Or press P. Switching tabs pauses too.")
    self.howText = W.Label(side, G.how or "", "GameFontDisableSmall")
    self.howText:SetPoint("TOPLEFT", 12, -124)
    self.howText:SetPoint("RIGHT", -10, 0)
    self.howText:SetJustifyH("LEFT")

    local boardTitle = W.Label(side, "Leaderboard", "GameFontNormal")
    boardTitle:SetPoint("TOPLEFT", 12, -168)
    self.boardTabs = {}
    for i, sc in ipairs(SCOPES) do
        local b = W.Button(side, sc[2], 52, function()
            self.board = sc[1]
            ns.Scores.Ask(kind)
            self:DrawBoard()
        end, 18)
        b:SetPoint("TOPLEFT", 10 + (i - 1) * 54, -186)
        b.scope = sc[1]
        self.boardTabs[i] = b
    end
    self.rows = {}
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, side)
        row:SetSize(150, 16)
        row:SetPoint("TOPLEFT", 12, -208 - (i - 1) * 17)
        row.name = W.Label(row, "", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT")
        row.name:SetPoint("RIGHT", -50, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.score = W.Label(row, "", "GameFontNormalSmall")
        row.score:SetPoint("RIGHT")
        self.rows[i] = row
    end
    self.boardEmpty = W.Label(side, "", "GameFontDisableSmall")
    self.boardEmpty:SetPoint("TOPLEFT", 12, -212)
    self.boardEmpty:SetPoint("RIGHT", -10, 0)
    self.boardEmpty:SetJustifyH("LEFT")

    if G.Build then G:Build(self) end
    self:ShowOverlay("Ready?", "Click New game to start.")
    return self
end

---------------------------------------------------------------------------
-- The run
---------------------------------------------------------------------------
function P:Start()
    self.score = 0
    self.running, self.paused, self.over = true, false, false
    running[self.kind] = true
    self.overlay:Hide()
    self.G:Start(self)
    self.canvas:KeysOn()
    self:SetScore(0)
    self.G:Draw(self)
    ns.Changed()
end

function P:SetScore(n)
    self.score = n
    self.scoreText:SetText(self.G.FormatScore and self.G.FormatScore(n) or tostring(n))
end

-- The run is over: score it, show it, offer another go.
function P:Over(score, text)
    if self.over then return end
    self.over, self.running = true, false
    running[self.kind] = nil
    if score ~= nil then self:SetScore(score) end
    local best = score ~= nil and ns.Scores.Submit(self.kind, self.score)
    self:ShowOverlay(text or "Game over", (best and "|cff40ff40New best!|r  " or "") .. "Click New game to play again.")
    W.PlaySound(best and "LEVELUP" or "U_CHAT_SCROLL_BUTTON")
    self.canvas:KeysOff()
    ns.Changed()
end

-- Stop a run without scoring it (closing the game from its tab).
function P:Quit()
    if not self.running then return end
    self.running, self.paused, self.over = false, false, false
    running[self.kind] = nil
    self.canvas:KeysOff()
    self:ShowOverlay("Ready?", "Click New game to start.")
    ns.Changed()
end

function P:Pause(silent)
    if not self.running or self.paused then return end
    self.paused = true
    self.canvas:KeysOff()
    self:ShowOverlay("Paused", "Press P or click Pause to carry on.")
    if not silent then ns.Changed() end
end

function P:TogglePause()
    if not self.running then return end
    if self.paused then
        self.paused = false
        self.overlay:Hide()
        self.canvas:KeysOn()
    else
        self:Pause()
    end
    self:Refresh()
end

function P:ShowOverlay(text, sub)
    self.overlayText:SetText(text)
    self.overlaySub:SetText(sub or "")
    self.overlay:Show()
end

---------------------------------------------------------------------------
-- Drawing the side panel
---------------------------------------------------------------------------
function P:DrawBoard()
    local G = self.G
    local list = ns.Scores.Board(self.kind, self.board, 8)
    for i, row in ipairs(self.rows) do
        local e = list[i]
        row:SetShown(e ~= nil)
        if e then
            local col = K.ClassColor(e.class)
            local name = i .. ". " .. e.name
            row.name:SetText(e.me and ("|cffffd100" .. name .. "|r") or name)
            if not e.me then row.name:SetTextColor(col[1], col[2], col[3]) else row.name:SetTextColor(1, 1, 1) end
            row.score:SetText(G.FormatScore and G.FormatScore(e.score) or tostring(e.score))
        end
    end
    local empty = ({ me = "Play a game to set your best.", guild = "No guild scores yet. They show up as guildies play.",
        realm = "No realm scores yet. They show up as others play." })[self.board]
    self.boardEmpty:SetText(#list == 0 and empty or "")
    for _, b in ipairs(self.boardTabs) do b:SetEnabled(b.scope ~= self.board) end
end

function P:Refresh()
    local G = self.G
    local best = ns.Scores.Best(self.kind)
    self.bestText:SetText("Best: " .. (best and (G.FormatScore and G.FormatScore(best) or tostring(best)) or "-"))
    self.pauseButton:SetText(self.paused and "Resume" or "Pause")
    self.pauseButton:SetEnabled(self.running == true)
    self:DrawBoard()
    if not self.asked then
        self.asked = true
        ns.Scores.Ask(self.kind)
    end
end

-- The mouse in canvas coordinates (from the top-left).
function P:Cursor()
    local c = self.canvas
    local left, top = c:GetLeft(), c:GetTop()
    local mx, my = GetCursorPosition()
    local scale = c:GetEffectiveScale()
    return mx / scale - (left or 0), (top or 0) - my / scale
end

function P:FlashRoll() end

-- Solo games register like this (in their page file or the game file).
function So.Register(kind)
    ns.CustomPages = ns.CustomPages or {}
    ns.CustomPages[kind] = So.New
end

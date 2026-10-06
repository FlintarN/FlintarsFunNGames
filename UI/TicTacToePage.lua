-- TicTacToePage: the players on the left (portrait, mark, score), the board
-- on the right. Marks pop in when placed; the winning line glows gold.
local ADDON, ns = ...

local W = ns.Widgets
local C = ns.Cards
local A = ns.Arcade
local P = setmetatable({}, { __index = A })
P.__index = P
ns.TicTacToePage = P

local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"
local CELL, GAP, MARK = 86, 6, 70
local MARK_TEX = { X = ART .. "TttX", O = ART .. "TttO" }

local function Session(self) return ns.Session.Get(self.kind) end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function PlayerBlock(parent, y)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(184, 62)
    b:SetPoint("TOPLEFT", 8, y)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetAllPoints()
    b.border:SetColorTexture(1, 0.82, 0.1, 0.35)
    b.border:Hide()
    b.portrait = W.Portrait(b, 44)
    b.portrait:SetPoint("LEFT", 4, 0)
    b.name = W.Label(b, "", "GameFontNormal")
    b.name:SetPoint("TOPLEFT", 54, -10)
    b.name:SetPoint("RIGHT", -30, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.score = W.Label(b, "", "GameFontHighlightSmall")
    b.score:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetSize(24, 24)
    b.mark:SetPoint("TOPRIGHT", -4, -6)
    b.skip = W.SkipButton(b)
    b.skip:SetPoint("BOTTOMRIGHT", -4, 4)
    return b
end

function P:BuildGame(v)
    local left = W.Panel(v, "Players")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT", 0, 34)
    left:SetWidth(200)
    self.blocks = { PlayerBlock(left, -30), PlayerBlock(left, -98) }
    self.vs = W.Label(left, "", "GameFontDisable")
    self.vs:SetPoint("TOPLEFT", 14, -168)
    self.scopeLine = W.Label(left, "", "GameFontHighlightSmall")
    self.scopeLine:SetPoint("BOTTOMLEFT", 10, 10)
    self.scopeLine:SetPoint("RIGHT", -10, 0)
    self.scopeLine:SetJustifyH("LEFT")

    local board = W.Panel(v)
    board:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    board:SetPoint("BOTTOMRIGHT", 0, 34)
    local felt = board:CreateTexture(nil, "BORDER", nil, 2)
    felt:SetPoint("TOPLEFT", 3, -3)
    felt:SetPoint("BOTTOMRIGHT", -3, 3)
    felt:SetColorTexture(0.24, 0.16, 0.09, 0.85)
    self.board = board

    self.banner = W.Label(board, "", "GameFontNormal")
    self.banner:SetPoint("TOP", 0, -10)

    local grid = CreateFrame("Frame", nil, board)
    local size = 3 * CELL + 2 * GAP
    grid:SetSize(size, size)
    grid:SetPoint("TOP", 0, -32)
    self.cells = {}
    for i = 1, 9 do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local c = CreateFrame("Button", nil, grid)
        c:SetSize(CELL, CELL)
        c:SetPoint("TOPLEFT", col * (CELL + GAP), -row * (CELL + GAP))
        local bg = c:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.93, 0.86, 0.68, 1)
        local inner = c:CreateTexture(nil, "BORDER")
        inner:SetPoint("TOPLEFT", 3, -3)
        inner:SetPoint("BOTTOMRIGHT", -3, 3)
        inner:SetColorTexture(0.86, 0.77, 0.56, 1)
        c.glow = c:CreateTexture(nil, "BORDER", nil, 2)
        c.glow:SetAllPoints()
        c.glow:SetColorTexture(1, 0.82, 0.1, 0.55)
        c.glow:Hide()
        c.hl = c:CreateTexture(nil, "HIGHLIGHT")
        c.hl:SetAllPoints()
        c.hl:SetColorTexture(1, 1, 1, 0.18)
        c.mark = c:CreateTexture(nil, "ARTWORK")
        c.mark:SetSize(MARK, MARK)
        c.mark:SetPoint("CENTER")
        c.mark:Hide()
        c:SetScript("OnClick", function() self:Mark(i) end)
        self.cells[i] = c
    end
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
    Add("bot", "+ Bot", 64, function() S.AddBot(kind) end, "Add a bot", "Play against a bot (practice only).")
    Add("start", "Start", 80, function()
        local ok, why = S.Start(kind)
        if not ok and why then self.hint:SetText("|cffff6060" .. why .. "|r") end
    end, "Start", "Start the first game.")
    Add("rematch", "Rematch", 90, function() S.Act(kind, "rematch") end, "Rematch", "Play again; the other player starts.")
    Add("cancel", "Close lobby", 100, function()
        W.Confirm("Close this lobby?", function() self:CloseLobby() end)
    end, "Close lobby", "End the lobby for everyone.")
    Add("close", "Close", 70, function() S.Dismiss(kind) end, "Close", "Put the game away.")

    self.hint = W.Label(v, "", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 4, 9)
    self.hint:SetJustifyH("LEFT")
end

local ORDER = { "close", "cancel", "rematch", "start", "bot", "leave", "join" }

function P.New(parent, kind)
    local self = setmetatable({ kind = kind, G = ns.Games[kind] }, P)
    A.BuildSetup(self, parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    self.game = v
    self:BuildGame(v)
    self:BuildButtons(v)
    return self
end

function P:Mark(i)
    local s = Session(self)
    if not (s and ns.Session.MyTurn(s)) or s.board[i] ~= "" or ns.Session.HostOffline(s) then return end
    ns.Session.Act(self.kind, "mark:" .. i)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- A mark appears: pop it in from small.
local function PopIn(tex)
    tex:SetSize(20, 20)
    C.Tween(0.25, function(t)
        local k = 20 + (MARK - 20) * t + math.sin(t * math.pi) * 10
        tex:SetSize(k, k)
    end)
end

function P:Refresh()
    local s = Session(self)
    self.setup:SetShown(s == nil)
    self.game:SetShown(s ~= nil)
    if not s then
        self.prevBoard = nil
        return A.RefreshSetup(self)
    end
    local S, me = ns.Session, ns.Me()

    -- Board
    local animate = self.prevBoard and self.prevId == s.id and self.prevGames == s.games
    local inLine = {}
    for _, i in ipairs(s.line or {}) do inLine[i] = true end
    for i, c in ipairs(self.cells) do
        local m = s.board and s.board[i] or ""
        if m ~= "" then
            c.mark:SetTexture(MARK_TEX[m])
            c.mark:Show()
            if animate and self.prevBoard[i] == "" then
                PopIn(c.mark)
                W.PlaySound("U_CHAT_SCROLL_BUTTON")
            end
        else
            c.mark:Hide()
        end
        c.glow:SetShown(inLine[i] == true)
        c:SetEnabled(S.MyTurn(s) and m == "" and not S.HostOffline(s))
    end
    if s.board then
        self.prevBoard = { unpack(s.board) }
    end
    self.prevId, self.prevGames = s.id, s.games
    if animate and s.phase == "done" and s.result and s.result.winner and not self.cheered then
        self.cheered = true
        W.PlaySound(s.result.winner == me and "LEVELUP" or "U_CHAT_SCROLL_BUTTON")
    elseif s.phase ~= "done" then
        self.cheered = nil
    end

    -- Players
    for k, b in ipairs(self.blocks) do
        local p = s.players[k]
        b:SetShown(p ~= nil)
        if p then
            local name = p.name
            if p.name == me then name = "|cffffd100" .. name .. "|r" end
            if p.bot then name = "|cffaaaaaa" .. name .. "|r" end
            b.name:SetText(name .. W.PlayerTag(p))
            b.portrait:SetPlayer(p.name, p.class, p.offline or p.out)
            local mark = s.marks and s.marks[p.name]
            b.mark:SetShown(mark ~= nil)
            if mark then b.mark:SetTexture(MARK_TEX[mark]) end
            b.score:SetText(s.score and ("Wins: " .. (s.score[p.name] or 0)) or (k == 1 and "Host" or ""))
            b.border:SetShown(S.IsTurn(s, p.name))
            W.UpdateSkip(b.skip, self.kind, s, p.name)
        end
    end
    self.vs:SetText((s.games and s.games > 0) and ("Game " .. s.games .. (s.draws and s.draws > 0 and ("  (" .. s.draws .. " drawn)") or "")) or "")
    self.scopeLine:SetText(A.ScopeLine(s))
    self.banner:SetText(s.banner or "")
    self:RefreshButtons(s)
end

function P:RefreshButtons(s)
    local S, me, G = ns.Session, ns.Me(), self.G
    local host, seated = S.IsHost(s), S.Find(s, me) ~= nil
    local away = S.HostOffline(s)
    local show = {
        join = S.CanJoin(s) and not seated,
        leave = s.phase == "lobby" and seated and not host,
        bot = s.test and s.phase == "lobby",
        start = s.phase == "lobby" and host,
        rematch = host and (s.phase == "done" or s.phase == "rolling"),
        cancel = host and s.phase ~= "cancelled",
        close = (not host and (not S.IsActive(s) or away)) or s.phase == "cancelled",
    }
    self.buttons.close:SetText(S.IsActive(s) and "Leave game" or "Close")
    local right
    for _, key in ipairs(ORDER) do
        local b = self.buttons[key]
        b:SetShown(show[key] and true or false)
        if show[key] then
            b:ClearAllPoints()
            if right then b:SetPoint("RIGHT", right, "LEFT", -4, 0) else b:SetPoint("BOTTOMRIGHT", 0, 2) end
            right = b
        end
    end
    self.buttons.start:SetEnabled(#s.players >= G.minPlayers)
    self.buttons.rematch:SetEnabled(s.phase == "done" and not away)
    self.buttons.join:SetEnabled(not s._joining and #s.players < G.maxPlayers)
    self.buttons.bot:SetEnabled(S.CanAddBot(s))

    local hint = ""
    if s.phase == "lobby" then
        hint = #s.players < 2 and (host and "Waiting for an opponent..." or "") or (host and "Ready: click Start." or "Waiting for the host to start.")
    elseif s.phase == "rolling" then
        hint = S.MyTurn(s) and "Your turn: click a square." or (seated and "Their turn." or "You are watching.")
    elseif s.phase == "done" then
        hint = host and "Rematch to play again, or close the lobby." or "Waiting for a rematch..."
    end
    if away then hint = W.HOST_OFFLINE end
    self.hint:SetText(hint)
    if right then self.hint:SetPoint("RIGHT", right, "LEFT", -8, 0) end
end

function P:FlashRoll() end

ns.CustomPages = ns.CustomPages or {}
ns.CustomPages.tictactoe = P.New

-- Main window: the game's portrait window (ButtonFrameTemplate) with icon
-- tabs down the right edge, the same way the Forever client's own windows
-- do it. One tab to pick a game, one per game, one for stats.
--
-- Pages only draw; the games themselves live in ns.Session, so switching
-- tabs or closing the window never loses a game.
local ADDON, ns = ...

local W = ns.Widgets
local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 560, 480
local TAB_SIZE, TAB_GAP, TAB_BORDER = 44, 8, 2

UI.pages = {}
UI.tabs = {}

local function TabList()
    local list = { { key = "home", label = "Games", icon = ns.ICON, help = "Pick a game to play." } }
    for _, kind in ipairs(ns.GAME_ORDER) do
        local G = ns.Games[kind]
        table.insert(list, { key = kind, label = G.name, icon = G.icon, help = G.short })
    end
    table.insert(list, { key = "settle", label = "Settle up", icon = "Interface\\Icons\\INV_Misc_Note_01",
        help = "Who owes whom across games, and what has been paid." })
    table.insert(list, { key = "stats", label = "Statistics", icon = "Interface\\Icons\\INV_Misc_Book_09",
        help = "Your wins, losses and gold, game by game and player by player." })
    table.insert(list, { key = "settings", label = "Settings", icon = "Interface\\Icons\\INV_Misc_Gear_01",
        help = "Sounds, pop-ups, the minimap button, window size, and clearing your data." })
    return list
end

local function SideTab(parent, icon)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(TAB_SIZE, TAB_SIZE)

    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)

    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetPoint("TOPLEFT", TAB_BORDER + 2, -(TAB_BORDER + 2))
    tab.icon:SetPoint("BOTTOMRIGHT", -(TAB_BORDER + 2), TAB_BORDER + 2)
    tab.icon:SetTexture(icon)
    tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    tab.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = tab:CreateTexture(nil, "OVERLAY")
        if side == "TOP" or side == "BOTTOM" then
            e:SetPoint(side .. "LEFT")
            e:SetPoint(side .. "RIGHT")
            e:SetHeight(TAB_BORDER)
        else
            e:SetPoint("TOP" .. side)
            e:SetPoint("BOTTOM" .. side)
            e:SetWidth(TAB_BORDER)
        end
        table.insert(tab.edges, e)
    end

    local hl = tab:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", TAB_BORDER, -TAB_BORDER)
    hl:SetPoint("BOTTOMRIGHT", -TAB_BORDER, TAB_BORDER)
    hl:SetColorTexture(1, 1, 1, 0.15)

    -- A dot in the corner while a game is running on this tab.
    tab.badge = tab:CreateTexture(nil, "OVERLAY", nil, 7)
    tab.badge:SetSize(14, 14)
    tab.badge:SetPoint("TOPRIGHT", 4, 4)
    tab.badge:SetTexture("Interface\\COMMON\\Indicator-Green")
    tab.badge:Hide()

    function tab:SetSelected(selected)
        local c = selected and W.GOLD or W.BRONZE
        for _, e in ipairs(self.edges) do e:SetColorTexture(c[1], c[2], c[3], 1) end
        self.icon:SetDesaturated(not selected)
        local v = selected and 1 or 0.75
        self.icon:SetVertexColor(v, v, v)
    end

    -- "running": green dot; "turn": yellow dot (your turn to roll).
    function tab:SetBadge(state)
        if state == "turn" then
            self.badge:SetTexture("Interface\\COMMON\\Indicator-Yellow")
        else
            self.badge:SetTexture("Interface\\COMMON\\Indicator-Green")
        end
        self.badge:SetShown(state ~= nil)
    end
    return tab
end

function UI:BuildTabs(f)
    for i, t in ipairs(TabList()) do
        local tab = SideTab(f, t.icon)
        tab.key = t.key
        local game = ns.Games[t.key] ~= nil
        if game then tab:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        tab:SetScript("OnClick", function(_, button)
            if button == "RightButton" and game then return UI:CloseGame(t.key) end
            W.PlaySound("IG_CHARACTER_INFO_TAB")
            UI:SelectTab(t.key)
        end)
        W.Tooltip(tab, t.label, game and (t.help .. "\n|cff9d9d9dRight-click: close this game.|r") or t.help)
        table.insert(self.tabs, tab)
    end
end

-- Game tabs only show while that game has a table, or while you look at
-- it; Games, Settle up and Statistics always show. Visible tabs stack
-- from the top with no gaps.
-- Which side you're on: "casino" or "arcade". Set by the home page's
-- switch and by opening a game; Statistics and Settings keep it.
function UI:Side()
    local G = ns.Games[self.tab or ""]
    if G then return G.arcade and "arcade" or "casino" end
    if self.tab == "settle" then return "casino" end
    if self.tab == "home" then return ns.db.homeSection or "casino" end
    return self.side or ns.db.homeSection or "casino"
end

UI.FOOTER = {
    casino = "Every number comes from the game's own /roll, so no one can fake a roll.",
    arcade = "Arcade: just for fun, no betting.",
}

function UI:LayoutTabs()
    -- Money things (Settle up) only on the casino side.
    self.side = self:Side()
    local i = 0
    for _, tab in ipairs(self.tabs) do
        local game = ns.Games[tab.key] ~= nil
        local show = not game or ns.Session.Get(tab.key) ~= nil or tab.key == self.tab
            or (ns.Solo and ns.Solo.Running(tab.key)) -- a solo run in progress keeps its tab
        if tab.key == "settle" then show = self.side == "casino" end
        tab:SetShown(show)
        if show then
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 2, -40 - i * (TAB_SIZE + TAB_GAP))
            i = i + 1
        end
    end
end

-- Right-click on a game's tab: done with it. Asks first only when that
-- would end something for others, or throw away a run.
function UI:CloseGame(kind)
    local S, G = ns.Session, ns.Games[kind]
    local s = S.Get(kind)
    local function Close()
        if S.Get(kind) then S.Close(kind) end
        local page = self.pages[kind]
        if page and page.view and page.view.Quit then page.view:Quit() end
        W.PlaySound("IG_MAINMENU_OPTION")
        if self.tab == kind then self:SelectTab("home") else self:Refresh() end
    end
    local ask
    if ns.Solo and ns.Solo.Running(kind) then
        ask = "Quit this " .. G.name .. " run? It won't count."
    elseif s and S.IsActive(s) then
        if S.IsHost(s) and #s.players > 1 then
            ask = "Close " .. G.name .. " for everyone?" .. (G.arcade and "" or " No one pays.")
        elseif s.phase == "rolling" and not S.IsHost(s) and S.Find(s, ns.Me()) then
            ask = "Walk away from this " .. G.name .. " game? The host will have to skip you."
        end
    end
    if ask then W.Confirm(ask, Close) else Close() end
end

-- Some games want a bigger window (G.window). It grows or shrinks smoothly,
-- keeping its top-left corner where it is.
function UI:ApplySize(key, instant)
    local f = self.frame
    if not f then return end
    local G = ns.Games[key]
    local w, h = WIDTH, HEIGHT
    if G and G.window then w, h = G.window[1], G.window[2] end
    local cw, ch = f:GetWidth() or w, f:GetHeight() or h
    if math.abs(cw - w) < 1 and math.abs(ch - h) < 1 then return end
    local left, top = f:GetLeft(), f:GetTop()
    if left and top then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        ns.db.windowPos = { "TOPLEFT", "BOTTOMLEFT", left, top }
    end
    local token = {}
    self.sizing = token
    if instant or not f:IsShown() then return f:SetSize(w, h) end
    ns.Cards.Tween(0.18, function(k)
        if self.sizing ~= token then return end
        local e = 1 - (1 - k) * (1 - k)
        f:SetSize(cw + (w - cw) * e, ch + (h - ch) * e)
    end, function() if self.sizing == token then f:SetSize(w, h) end end)
end

function UI:SelectTab(key)
    self.tab = key
    self:ApplySize(key)
    if ns.Help then ns.Help:Hide() end
    for k, page in pairs(self.pages) do page.frame:SetShown(k == key) end
    for _, tab in ipairs(self.tabs) do tab:SetSelected(tab.key == key) end
    self:Refresh()
end

---------------------------------------------------------------------------
-- Main frame
---------------------------------------------------------------------------
function UI:ApplyScale()
    if self.frame then self.frame:SetScale(ns.db.scale or 1) end
end

function UI:ResetPosition()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER")
end

function UI:Build()
    if self.frame then return end
    local f = W.TryCreate("Frame", "FunNGamesFrame", UIParent, "ButtonFrameTemplate", "BasicFrameTemplateWithInset")
    f:SetSize(WIDTH, HEIGHT)
    f:SetScale(ns.db.scale or 1)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, relPoint, x, y = s:GetPoint()
        ns.db.windowPos = { point, relPoint, x, y }
    end)
    local pos = ns.db.windowPos
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("CENTER")
    end
    tinsert(UISpecialFrames, "FunNGamesFrame") -- Escape closes it
    f:Hide()
    f:SetScript("OnShow", function()
        W.PlaySound("IG_CHARACTER_INFO_OPEN")
        UI:Refresh()
    end)
    f:SetScript("OnHide", function() W.PlaySound("IG_CHARACTER_INFO_CLOSE") end)

    W.SetTitle(f, ns.TITLE)
    W.SetPortrait(f, ns.ICON)
    if f.Inset then
        f.Inset:ClearAllPoints()
        f.Inset:SetPoint("TOPLEFT", 4, -60)
        f.Inset:SetPoint("BOTTOMRIGHT", -6, 26)
    end

    -- Subtitle next to the portrait, like Blizzard's windows.
    self.subtitle = W.Label(f, "", "GameFontHighlight")
    self.subtitle:SetPoint("TOPLEFT", 66, -36)
    self.subtitle:SetPoint("RIGHT", -16, 0)
    self.subtitle:SetJustifyH("LEFT")

    -- Bottom strip: a hint on the left, the pop-up switch on the right.
    self.footer = W.Label(f, "", "GameFontDisableSmall")
    self.footer:SetPoint("BOTTOMLEFT", 14, 8)
    self.footer:SetText(UI.FOOTER.casino)
    local popup = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    popup:SetSize(22, 22)
    popup:SetPoint("BOTTOMRIGHT", -96, 2)
    popup:SetScript("OnClick", function(s) ns.db.popup = s:GetChecked() and true or false end)
    local pl = W.Label(f, "Pop up", "GameFontNormalSmall")
    pl:SetPoint("LEFT", popup, "RIGHT", 0, 1)
    W.Tooltip(popup, "Pop up", "Open this window when someone in your group starts a game.")
    self.popupCheck = popup

    local function Page()
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", 10, -66)
        p:SetPoint("BOTTOMRIGHT", -12, 32)
        return p
    end

    -- Help buttons, top right: the rules of this tab's game, and for poker the hand rankings.
    self.rulesButton = W.Button(f, "Rules", 70, function()
        if ns.Help:IsShown() and ns.Help.mode == "rules" then return ns.Help:Hide() end
        ns.Help.mode = "rules"
        ns.Help:ShowRules(UI.tab)
    end, 22)
    self.rulesButton:SetPoint("TOPRIGHT", -14, -32)
    W.Tooltip(self.rulesButton, "Rules", "How this game works, in plain words.")
    self.handsButton = W.Button(f, "Hand rankings", 110, function()
        if ns.Help:IsShown() and ns.Help.mode == "hands" then return ns.Help:Hide() end
        ns.Help.mode = "hands"
        ns.Help:ShowHands(UI:MyPokerHand())
    end, 22)
    self.handsButton:SetPoint("RIGHT", self.rulesButton, "LEFT", -4, 0)
    W.Tooltip(self.handsButton, "Hand rankings", "Every poker hand from best to worst, with examples. "
        .. "During a hand, yours is highlighted.")

    self.frame = f
    ns.Help:Build(f)
    self.pages.home = { frame = Page() }
    ns.HomePage:Build(self.pages.home.frame)
    for _, kind in ipairs(ns.GAME_ORDER) do
        local page = { frame = Page() }
        local G = ns.Games[kind]
        page.view = (ns.CustomPages[kind] or (G.solo and ns.Solo.New) or ns.GamePage.New)(page.frame, kind)
        self.pages[kind] = page
    end
    self.pages.settle = { frame = Page() }
    ns.SettlePage:Build(self.pages.settle.frame)
    self.pages.stats = { frame = Page() }
    ns.StatsPage:Build(self.pages.stats.frame)
    self.pages.settings = { frame = Page() }
    ns.SettingsPage:Build(self.pages.settings.frame)

    self:BuildTabs(f)
    self:SelectTab("home")
end

local SUBTITLES = {
    home = "What do you want to play?",
    stats = "Statistics",
    settings = "Settings",
    settle = "Settle up: who owes whom",
}

function UI:Refresh()
    if not self.frame then return end
    self:LayoutTabs()
    if self.footer then self.footer:SetText(UI.FOOTER[self.side] or "") end
    for _, tab in ipairs(self.tabs) do
        local s = ns.Session.Get(tab.key)
        if ns.Session.MyTurn(s) then
            tab:SetBadge("turn")
        elseif ns.Session.IsActive(s) then
            tab:SetBadge("running")
        else
            tab:SetBadge(nil)
        end
    end
    if not self.frame:IsShown() then return end
    self.popupCheck:SetChecked(ns.db.popup)
    local G = ns.Games[self.tab]
    self.subtitle:SetText(G and G.name or SUBTITLES[self.tab] or "")
    self.rulesButton:SetShown(G ~= nil)
    self.handsButton:SetShown(self.tab == "poker")
    -- Keep the highlighted hand current while the rankings are open.
    if ns.Help:IsShown() and ns.Help.mode == "hands" then ns.Help:ShowHands(self:MyPokerHand()) end
    if self.tab == "home" then
        ns.HomePage:Refresh()
    elseif self.tab == "settle" then
        ns.SettlePage:Refresh()
    elseif self.tab == "stats" then
        ns.StatsPage:Refresh()
    elseif self.tab == "settings" then
        ns.SettingsPage:Refresh()
    else
        self.pages[self.tab].view:Refresh()
    end
end

-- The category of your best poker hand right now (5+ cards known), or nil.
function UI:MyPokerHand()
    local s = ns.Session.Get("poker")
    local mine = ns.Session.MyCards(s)
    if not (mine and s.board and #s.board >= 3) then return nil end
    local cards = { mine[1], mine[2] }
    for _, c in ipairs(s.board) do table.insert(cards, c) end
    local best = ns.Games.poker.Best(cards)
    return best and { cat = best[1], high = best[2] }
end

-- Host: a player went offline. The game waits; Skip is next to their name.
function UI:PlayerOffline(s, name)
    local G = ns.Games[s.kind]
    ns.Print(name .. " went offline in " .. G.name .. ". The game waits for them; click Skip next to their name "
        .. "to go on without them (you can bring them back).")
    W.PlaySound("RAID_WARNING", true)
end

function UI:Toggle()
    self:Build()
    self.frame:SetShown(not self.frame:IsShown())
end

-- Open the window on a game's tab (someone started a game, or you clicked Play).
function UI:ShowGame(kind)
    self:Build()
    self.frame:Show()
    self:SelectTab(kind)
end

-- It just became your turn: make sure you notice.
function UI:YourTurn(kind)
    W.PlaySound("READY_CHECK", true)
    self:Build()
    if not self.frame:IsShown() and ns.db.turnPopup ~= false then self:ShowGame(kind) end
    local page = self.pages[kind]
    if page and page.view.FlashRoll then page.view:FlashRoll() end
end

ns.OnChange(function() UI:Refresh() end)

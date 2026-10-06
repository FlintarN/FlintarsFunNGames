-- Home: "What do you want to play?" A card per game, plus the games that
-- are coming later (greyed out).
local ADDON, ns = ...

local W = ns.Widgets
local Home = {}
ns.HomePage = Home


local COLS = 4
local CARD_W, CARD_H, GAP = 122, 150, 8
local BAR_ROOM = 22 -- kept free on the right for the scroll bar, so both sections line up

local function IconFrame(parent, icon, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetColorTexture(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 1)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexture(icon)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return f
end

-- A compact card: icon and status on top, the name, a short description,
-- and Play along the bottom. Four to a row.
local function Card(parent, info)
    local c = W.Panel(parent)
    c:SetSize(CARD_W, CARD_H)

    c.icon = IconFrame(c, info.icon, 32)
    c.icon:SetPoint("TOPLEFT", 10, -10)

    c.state = W.Label(c, "", "GameFontHighlightSmall")
    c.state:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 6, -2)
    c.state:SetPoint("RIGHT", -6, 0)
    c.state:SetJustifyH("LEFT")
    if c.state.SetMaxLines then c.state:SetMaxLines(2) end

    c.name = W.Label(c, info.name, "GameFontNormalLarge")
    c.name:SetPoint("TOPLEFT", 10, -48)
    c.name:SetPoint("RIGHT", -6, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)

    c.desc = W.Label(c, info.short, "GameFontHighlightSmall")
    c.desc:SetPoint("TOPLEFT", 10, -68)
    c.desc:SetPoint("RIGHT", -8, 0)
    c.desc:SetJustifyH("LEFT")
    c.desc:SetTextColor(0.85, 0.85, 0.85)
    if c.desc.SetMaxLines then c.desc:SetMaxLines(4) end

    c.button = W.Button(c, "Play", CARD_W - 20, nil, 22)
    c.button:SetPoint("BOTTOM", 0, 8)
    return c
end

-- The two sections: Casino (money games) and Arcade (just for fun).
local SECTIONS = {
    { key = "casino", label = "Casino", help = "Games for gold: dice, cards, slots, roulette, raffles." },
    { key = "arcade", label = "Arcade", help = "Just for fun, no betting. Play your group, your guild, the realm, or friends with a code." },
}

local function SectionOf(kind)
    return ns.Games[kind].arcade and "arcade" or "casino"
end

-- Place a card at slot i of the grid.
local function Place(c, i, w)
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", col * (w + GAP), -row * (CARD_H + GAP))
    c:SetWidth(w)
    c.button:SetWidth(w - 20)
end

function Home:Build(page)
    -- Section switch along the top.
    self.sectionButtons = {}
    for i, sec in ipairs(SECTIONS) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(120, 24)
        b:SetPoint("TOPLEFT", (i - 1) * 126, 0)
        b.label = W.Label(b, sec.label, "GameFontNormalLarge")
        b.label:SetPoint("CENTER")
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("BOTTOMLEFT", 6, 0)
        b.bar:SetPoint("BOTTOMRIGHT", -6, 0)
        b.bar:SetHeight(2)
        b.bar:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript("OnClick", function()
            W.PlaySound("IG_CHARACTER_INFO_TAB")
            ns.db.homeSection = sec.key
            ns.UI:Refresh() -- the side changes: tabs and footer follow
        end)
        W.Tooltip(b, sec.label, sec.help)
        b.key = sec.key
        self.sectionButtons[i] = b
    end
    self.sectionHint = W.Label(page, "", "GameFontDisableSmall")
    self.sectionHint:SetPoint("TOPRIGHT", -4, -8)

    -- Who owes whom, at a glance (details on the Settle up tab).
    self.tabLine = W.Label(page, "", "GameFontHighlight")
    self.tabLine:SetPoint("BOTTOMLEFT", 4, 6)

    local line = W.Divider(page)
    line:SetPoint("TOPLEFT", 0, -26)
    line:SetPoint("TOPRIGHT", 0, -26)

    -- The cards scroll once a section has more than fits; the bar only
    -- shows then, but its room is always kept.
    local sf = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -34)
    sf:SetPoint("BOTTOMRIGHT", -BAR_ROOM, 24)
    local bar = type(sf.ScrollBar) == "table" and sf.ScrollBar or nil
    if bar then
        -- Place it ourselves (inside the window); the arrows sit 16 above and below.
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", page, "TOPRIGHT", -3, -34 - 16)
        bar:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -3, 24 + 16)
    end
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(COLS * CARD_W + (COLS - 1) * GAP, 10)
    sf:SetScrollChild(content)
    self.scroll, self.content = sf, content
    sf:SetScript("OnSizeChanged", function() if self.section then self:Refresh() end end)

    self.cards = {}
    for _, kind in ipairs(ns.GAME_ORDER) do
        local G = ns.Games[kind]
        local c = Card(content, G)
        c.kind = kind
        c.section = SectionOf(kind)
        c.button:SetScript("OnClick", function()
            W.PlaySound("IG_MAINMENU_OPTION")
            ns.UI:SelectTab(kind)
        end)
        table.insert(self.cards, c)
    end
end

function Home:Refresh()
    local section = ns.db.homeSection or "casino"
    for _, b in ipairs(self.sectionButtons) do
        local on = b.key == section
        b.bar:SetShown(on)
        b.label:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0 or 0.6)
    end
    self.sectionHint:SetText(section == "arcade" and "Just for fun: no bets." or "Games for gold.")
    local count = 0
    for _, c in ipairs(self.cards) do
        if c.section == section then count = count + 1 end
    end
    local rows = math.ceil(count / COLS)
    local height = rows * CARD_H + math.max(0, rows - 1) * GAP
    local sf = self.scroll
    local needed = height > (sf:GetHeight() or 0) + 0.5 and (sf:GetHeight() or 0) > 0
    local bar = type(sf.ScrollBar) == "table" and sf.ScrollBar or nil
    if bar then bar:SetShown(needed) end
    if not needed then sf:SetVerticalScroll(0) end
    if self.section ~= section then sf:SetVerticalScroll(0) end
    self.section = section
    local w = CARD_W
    self.content:SetHeight(math.max(10, height))
    local slot = 0
    for _, c in ipairs(self.cards) do
        local show = c.section == section
        c:SetShown(show)
        if show then
            slot = slot + 1
            Place(c, slot, w)
        end
    end

    local owed, owe = ns.Tab.Totals()
    if (ns.db.homeSection or "casino") == "casino" and (owed > 0 or owe > 0) then
        self.tabLine:SetText("Owed to you: |cff40ff40" .. ns.Money(owed) .. "|r     You owe: |cffff5050"
            .. ns.Money(owe) .. "|r     (see Settle up)")
    else
        self.tabLine:SetText("")
    end
    for _, c in ipairs(self.cards) do
        local s = ns.Session.Get(c.kind)
        if ns.Session.MyTurn(s) then
            c.state:SetText("|cffffd100Your turn!|r")
            c.button:SetText("Go")
        elseif ns.Session.IsActive(s) then
            local text = s.phase == "lobby" and "Waiting" or "Running"
            c.state:SetText("|cff40ff40" .. text .. "|r (" .. #s.players .. ")")
            c.button:SetText("Resume")
        else
            c.state:SetText("")
            c.button:SetText("Play")
        end
    end
end

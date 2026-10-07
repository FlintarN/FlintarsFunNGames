-- Widgets: small helpers shared by the pages. Built from the game's own
-- templates and art so it looks like the Forever client's own windows, with
-- a plain fallback where a template is missing.
local ADDON, ns = ...

local W = {}
ns.Widgets = W

W.BRONZE = { 0.80, 0.64, 0.36 }
W.GOLD = { 1, 0.82, 0 }

function W.TryCreate(kind, name, parent, template, fallback)
    local ok, frame = pcall(CreateFrame, kind, name, parent, template)
    if ok and frame then return frame, true end
    return CreateFrame(kind, name, parent, fallback), false
end

function W.Button(parent, text, w, onClick, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    -- Greyed-out buttons still show their tooltip (it says why).
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    return b
end

-- A main menu like Hearthstone's: a framed stone box and big stone buttons.
local MENU_BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil
function W.MenuFrame(parent, edge)
    local f = CreateFrame("Frame", nil, parent, MENU_BACKDROP)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\FrameGeneral\\UI-Background-Rock", edgeFile =
            "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", tile = true, tileSize = 128, edgeSize = edge or 32,
            insets = { left = 10, right = 10, top = 10, bottom = 10 } })
    end
    return f
end

function W.MenuButton(parent, text, sub, w, h, fn)
    local btn = CreateFrame("Button", nil, parent, MENU_BACKDROP)
    btn:SetSize(w, h)
    if btn.SetBackdrop then
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile =
            "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        btn:SetBackdropColor(0.24, 0.17, 0.1, 1)
    end
    local shine = btn:CreateTexture(nil, "ARTWORK")
    shine:SetPoint("TOPLEFT", 5, -5)
    shine:SetPoint("BOTTOMRIGHT", -5, 5)
    shine:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
    shine:SetVertexColor(0.55, 0.45, 0.32)
    shine:SetAlpha(0.5)
    btn.label = W.BigLabel(btn, h >= 50 and 22 or 15, "GameFontNormalHuge")
    btn.label:SetPoint("CENTER", 0, sub and 7 or 0)
    btn.label:SetText(text)
    btn.label:SetTextColor(1, 0.86, 0.4)
    if sub then
        btn.sub = W.Label(btn, sub, "GameFontHighlightSmall")
        btn.sub:SetPoint("TOP", btn.label, "BOTTOM", 0, -3)
        btn.sub:SetTextColor(0.85, 0.8, 0.7)
    end
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 5, -5)
    hl:SetPoint("BOTTOMRIGHT", -5, 5)
    hl:SetColorTexture(1, 0.8, 0.3, 0.14)
    btn:SetScript("OnClick", function()
        W.PlaySound("IG_MAINMENU_OPTION")
        fn()
    end)
    return btn
end

function W.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetText(text or "")
    return fs
end

-- A label in a bigger size of the game's own font (for numbers and titles).
function W.BigLabel(parent, size, font)
    local fs = W.Label(parent, "", font or "GameFontNormalHuge")
    local face, _, flags = fs:GetFont()
    if face then fs:SetFont(face, size, flags) end
    return fs
end

-- Hover help. Hooked rather than set, so the template's own hover still works.
function W.Tooltip(widget, title, line)
    local function Show(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(title, 1, 0.82, 0)
        local text = type(line) == "function" and line(s) or line
        if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end
    if widget.HookScript and widget:GetScript("OnEnter") then
        widget:HookScript("OnEnter", Show)
        widget:HookScript("OnLeave", GameTooltip_Hide)
    else
        widget:SetScript("OnEnter", Show)
        widget:SetScript("OnLeave", GameTooltip_Hide)
    end
end

function W.SetPortrait(f, tex)
    if f.SetPortraitToAsset then
        f:SetPortraitToAsset(tex)
        return
    end
    local p = f.portrait or (f.PortraitContainer and f.PortraitContainer.portrait)
    if not p then return end
    if SetPortraitToTexture then SetPortraitToTexture(p, tex) else p:SetTexture(tex) end
end

function W.SetTitle(f, text)
    if f.SetTitle then
        f:SetTitle(text)
    elseif f.TitleText then
        f.TitleText:SetText(text)
    else
        local t = W.Label(f, text, "GameFontHighlight")
        t:SetPoint("TOP", 0, -5)
    end
end

-- Every sound goes through here, so Settings can mute the addon. Alerts
-- (your turn, a disconnect) have their own switch.
function W.PlaySound(kit, alert)
    local db = ns.db or {}
    if alert then
        if db.alertSound == false then return end
    elseif db.sound == false then
        return
    end
    if PlaySound and SOUNDKIT and SOUNDKIT[kit] then PlaySound(SOUNDKIT[kit]) end
end

-- The Arcade games' sounds: WoW game files by name, so every game picks from
-- one palette (W.Sfx("line")). Ids from the community listfile.
W.SFX = {
    click = 567489, move = 567576, rotate = 567472, drop = 567566, land = 567567,
    line = 567428, big = 567413, levelup = 567431, eat = 567546, crash = 567955, flap = 567673,
    point = 567428, merge = 567568, reveal = 567562, flag = 567551, boom = 567962, win = 567408,
    lose = 567488, type = 567489, enter = 567566, right = 567568, close = 567551, wrong = 567415,
    swap = 567576, match = 567568, combo = 567413, special = 568429, launch = 567673, hit = 567567,
    pop = 567962, shoot = 567721, enemyHit = 567880, explode = 567955, powerup = 567431,
    place = 567566, miss = 567557, sink = 567955, grow = 567546, split = 567673, eaten = 567488,
}

function W.Sfx(name)
    return W.PlayFile(W.SFX[name], "game")
end

-- A sound file from the game (by file id). kind "game": a game sound (Game
-- sounds on); "voice": the same, but a new voice cuts off the last one, like
-- Warcraft III; "alert": an alert (Alerts on).
local lastVoice
function W.PlayFile(id, kind)
    local db = ns.db or {}
    if not id then return end
    if kind == "alert" then
        if db.alertSound == false then return end
    elseif db.sound == false then
        return
    end
    if type(id) == "table" then id = id[math.random(#id)] end
    if not PlaySoundFile then return end
    if kind == "voice" and lastVoice and StopSound then StopSound(lastVoice, 100) end
    local ok, willPlay, handle = pcall(PlaySoundFile, id, "SFX")
    if kind == "voice" and ok and willPlay then lastVoice = handle end
    return ok and willPlay
end

---------------------------------------------------------------------------
-- Panel: a framed box with the game's dark marble background and a bronze
-- tooltip border, with an optional gold title along the top.
---------------------------------------------------------------------------
local BACKDROP = {
    bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 256, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function W.Panel(parent, title)
    local p = W.TryCreate("Frame", nil, parent, "BackdropTemplate")
    if p.SetBackdrop then
        p:SetBackdrop(BACKDROP)
        p:SetBackdropColor(1, 1, 1, 1)
        p:SetBackdropBorderColor(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 1)
    end
    -- Darken the marble so text reads well on it.
    local shade = p:CreateTexture(nil, "BORDER")
    shade:SetPoint("TOPLEFT", 3, -3)
    shade:SetPoint("BOTTOMRIGHT", -3, 3)
    shade:SetColorTexture(0, 0, 0, 0.2)
    if title then
        local bar = p:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", 4, -4)
        bar:SetPoint("TOPRIGHT", -4, -4)
        bar:SetHeight(20)
        bar:SetColorTexture(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 0.25)
        p.title = W.Label(p, title, "GameFontNormal")
        p.title:SetPoint("TOPLEFT", 10, -7)
    end
    return p
end

-- A thin gold line, as Blizzard uses under headings.
function W.Divider(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.35)
    return t
end

-- A labelled number box. box:GetNumberOr(default) reads it back.
function W.NumberBox(parent, label, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width or 80, 20)
    box:SetAutoFocus(false)
    if box.SetNumeric then box:SetNumeric(true) end
    if box.SetMaxLetters then box:SetMaxLetters(7) end
    box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    box.label = W.Label(parent, label, "GameFontNormalSmall")
    box.label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 2)
    function box:GetNumberOr(default)
        return tonumber(self:GetText()) or default
    end
    return box
end

---------------------------------------------------------------------------
-- Money box: gold, silver and copper fields with the game's coin icons.
-- box:GetCopper() / box:SetCopper(c); box.onChange and box.onEnter are
-- optional callbacks. Tab moves to the next field.
---------------------------------------------------------------------------
local COINS = {
    { "Interface\\MoneyFrame\\UI-GoldIcon", 44, 6 },
    { "Interface\\MoneyFrame\\UI-SilverIcon", 24, 2 },
    { "Interface\\MoneyFrame\\UI-CopperIcon", 24, 2 },
}

function W.MoneyBox(parent, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(172, 20) -- three boxes with their coin icons
    f.fields = {}
    local prev
    for i, coin in ipairs(COINS) do
        local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        box:SetSize(coin[2], 20)
        box:SetAutoFocus(false)
        if box.SetNumeric then box:SetNumeric(true) end
        if box.SetMaxLetters then box:SetMaxLetters(coin[3]) end
        box:SetJustifyH("RIGHT")
        if prev then
            box:SetPoint("LEFT", prev, "RIGHT", 8, 0)
        else
            box:SetPoint("LEFT", 6, 0)
        end
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(13, 13)
        icon:SetPoint("LEFT", box, "RIGHT", 2, 0)
        icon:SetTexture(coin[1])
        box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
        box:SetScript("OnEnterPressed", function(b)
            b:ClearFocus()
            if f.onEnter then f.onEnter() end
        end)
        box:SetScript("OnTabPressed", function()
            local nextBox = f.fields[i % #COINS + 1]
            nextBox:SetFocus()
            if nextBox.HighlightText then nextBox:HighlightText() end
        end)
        box:SetScript("OnTextChanged", function()
            if f.onChange then f.onChange() end
        end)
        f.fields[i] = box
        prev = icon
    end
    if label then
        f.label = W.Label(parent, label, "GameFontNormalSmall")
        f.label:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 2)
    end

    function f:GetCopper()
        local g = tonumber(self.fields[1]:GetText()) or 0
        local s = math.min(99, tonumber(self.fields[2]:GetText()) or 0)
        local c = math.min(99, tonumber(self.fields[3]:GetText()) or 0)
        return g * 10000 + s * 100 + c
    end

    function f:SetCopper(c)
        c = math.max(0, math.floor(tonumber(c) or 0))
        self.fields[1]:SetText(tostring(math.floor(c / 10000)))
        self.fields[2]:SetText(tostring(math.floor(c / 100) % 100))
        self.fields[3]:SetText(tostring(c % 100))
    end

    function f:ClearFocus()
        for _, box in ipairs(self.fields) do box:ClearFocus() end
    end

    -- Greyed out and not editable when off.
    function f:SetEnabled(on)
        for _, box in ipairs(self.fields) do
            box:EnableMouse(on and true or false)
            if not on then box:ClearFocus() end
        end
        self:SetAlpha(on and 1 or 0.45)
    end
    return f
end

---------------------------------------------------------------------------
-- Disconnects: a tag after a player's name, the host's question, and the
-- line players see while the host is offline.
---------------------------------------------------------------------------
function W.PlayerTag(p)
    if p.offline then return " |cffff6060(offline)|r" end
    if p.out then return " |cff888888(out)|r" end
    return ""
end

W.HOST_OFFLINE = "|cffff6060The host is offline.|r The game goes on when they're back, or you can leave."

-- The host's switch on a player row or seat: Skip (go on without them) or
-- Bring back (wait for them again). It can be flipped any time.
function W.SkipButton(parent)
    local b = W.Button(parent, "Skip", 44, nil, 18)
    W.Tooltip(b, "Skip or bring back", function(self)
        if self.mode == "back" then return "Put them back in. The game waits for them again." end
        return "Go on without them for now (offline, or a minute without a move). You can bring them back."
    end)
    b:Hide()
    return b
end

-- Show the right switch for this player, or hide it.
function W.UpdateSkip(b, kind, s, name)
    local S = ns.Session
    if S.CanSkip(s, name) then
        b.mode = "skip"
        b:SetText("Skip")
        b:SetWidth(44)
        b:SetScript("OnClick", function()
            if S.DropEnds(s, name) then
                W.Confirm("Skip " .. name .. "? Only one player would be left, so the game ends and no one pays.",
                    function() S.Drop(kind, name) end)
            else
                S.Drop(kind, name)
            end
        end)
        b:Show()
    elseif S.CanBringBack(s, name) then
        b.mode = "back"
        b:SetText("Bring back")
        b:SetWidth(74)
        b:SetScript("OnClick", function() S.Undrop(kind, name) end)
        b:Show()
    else
        b:Hide()
    end
    return b:IsShown()
end

---------------------------------------------------------------------------
-- Portrait: a round character portrait in a gold ring. The class icon sits
-- underneath, so it shows whenever the game can't draw the portrait (too
-- far away, a practice bot, not in your group).
---------------------------------------------------------------------------
local ART = "Interface\\AddOns\\FlintarsFunNGames\\Art\\"
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"

function W.Portrait(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.back = f:CreateTexture(nil, "BACKGROUND")
    f.back:SetAllPoints()
    f.back:SetTexture(ART .. "PortraitBack")
    f.class = f:CreateTexture(nil, "BORDER")
    f.class:SetPoint("TOPLEFT", size * 0.12, -size * 0.12)
    f.class:SetPoint("BOTTOMRIGHT", -size * 0.12, size * 0.12)
    f.face = f:CreateTexture(nil, "ARTWORK")
    f.face:SetPoint("TOPLEFT", size * 0.1, -size * 0.1)
    f.face:SetPoint("BOTTOMRIGHT", -size * 0.1, size * 0.1)
    f.ring = f:CreateTexture(nil, "OVERLAY")
    f.ring:SetAllPoints()
    f.ring:SetTexture(ART .. "PortraitRing")

    -- name: who; class: "MAGE" or nil; dim: grey it out (folded, away).
    function f:SetPlayer(name, class, dim)
        local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if coords then
            self.class:SetTexture(CLASS_ICONS)
            self.class:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            self.class:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            self.class:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        local unit = ns.Session.UnitFor(name)
        if unit and SetPortraitTexture and UnitExists and UnitExists(unit) then
            SetPortraitTexture(self.face, unit)
            self.face:Show()
        else
            self.face:Hide()
        end
        self.face:SetDesaturated(dim and true or false)
        self.class:SetDesaturated(dim and true or false)
        local v = dim and 0.6 or 1
        self.face:SetVertexColor(v, v, v)
        self.class:SetVertexColor(v, v, v)
    end
    return f
end

---------------------------------------------------------------------------
-- "Are you sure?"
---------------------------------------------------------------------------
StaticPopupDialogs.FUNNGAMES_CONFIRM = {
    text = "%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
    OnAccept = function(_, data) data.onYes() end,
}

function W.Confirm(text, onYes)
    StaticPopup_Hide("FUNNGAMES_CONFIRM")
    StaticPopup_Show("FUNNGAMES_CONFIRM", text, nil, { onYes = onYes })
end

---------------------------------------------------------------------------
-- A scrolling list of rows that the caller fills.
-- list:Row(i) builds or reuses row i; list:SetCount(n) hides the rest.
---------------------------------------------------------------------------
function W.ScrollList(parent, rowH, buildRow)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    sf:SetScript("OnSizeChanged", function(_, w)
        content:SetWidth(w)
    end)

    local list = { frame = sf, content = content, rows = {}, count = 0 }
    local bar = sf.ScrollBar
    if type(bar) ~= "table" then bar = nil end

    -- Place the list inside its panel. The right edge leaves room for the
    -- scroll bar only while it is needed.
    function list:Inset(left, top, right, bottom)
        self.inset = { left, top, right, bottom }
        self:Fit()
    end

    function list:Fit()
        local i = self.inset
        if not i then return end
        local h = sf:GetHeight() or 0
        local needed = h > 0 and self.count * rowH > h + 0.5
        if bar then bar:SetShown(needed) end
        if not needed then sf:SetVerticalScroll(0) end
        sf:ClearAllPoints()
        sf:SetPoint("TOPLEFT", i[1], i[2])
        sf:SetPoint("BOTTOMRIGHT", -((needed or not bar) and (i[3] + 20) or i[3]), i[4])
    end

    function list:Row(i)
        local row = self.rows[i]
        if row then return row end
        row = CreateFrame("Frame", nil, content)
        row:SetHeight(rowH)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
        row:SetPoint("RIGHT", content, "RIGHT")
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0)
        buildRow(row)
        self.rows[i] = row
        return row
    end

    function list:SetCount(n)
        for i = 1, #self.rows do self.rows[i]:SetShown(i <= n) end
        content:SetHeight(math.max(1, n * rowH))
        if n ~= self.count then
            self.count = n
            self:Fit()
        end
    end

    -- The panel's height is only known once it's laid out.
    parent:HookScript("OnSizeChanged", function() list:Fit() end)

    return list
end

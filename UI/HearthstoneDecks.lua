-- Hearthstone deck builder: your class's cards and neutral cards on the
-- left (filters, pages), the deck on the right. Click a card to add it,
-- click a row to take one out. Decks live in ns.db.hearthstone.decks as
-- { name, hero, cards = { key, ... } }.
local ADDON, ns = ...

local W = ns.Widgets
local D = {}
ns.HearthstoneDecks = D

local COLS, ROWS = 4, 2
local CARD_W, CARD_H = 104, 145
local COSTS = { "All", "0", "1", "2", "3", "4", "5", "6", "7+" }

local function HS() return ns.HS end
local function Card(key) return ns.HS.Cards[key] end

function D.Saved()
    local rec = ns.db.hearthstone
    rec.decks = rec.decks or {}
    return rec.decks
end

-- The decks a hero can use: the basic one first, then yours.
function D.For(heroKey)
    local out = { { name = "Basic deck", hero = heroKey, cards = HS().DeckList(HS().Heroes[heroKey].deck), basic = true } }
    for i, d in ipairs(D.Saved()) do
        if d.hero == heroKey then
            local copy = { name = d.name, hero = d.hero, cards = d.cards, index = i }
            table.insert(out, copy)
        end
    end
    return out
end

local function Count(list, key)
    local n = 0
    for _, k in ipairs(list) do if k == key then n = n + 1 end end
    return n
end

local function Build(page)
    local b = page.board
    local f = CreateFrame("Frame", nil, b)
    f:SetAllPoints()
    f:SetFrameLevel(b:GetFrameLevel() + 80)
    f:EnableMouse(true)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.04, 0.03, 0.96)
    local side = W.Panel(f)
    side:SetPoint("TOPLEFT", 466, -4)
    side:SetPoint("BOTTOMRIGHT", -4, 4)

    f.title = W.Label(f, "", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -10)

    -- Filters: class / neutral, then mana cost.
    f.tabs = {}
    for i, key in ipairs({ "class", "neutral" }) do
        local btn = W.Button(f, key == "class" and "Class" or "Neutral", 70, function()
            f.filterClass = key
            f.page = 1
            D.Refresh(f)
        end, 20)
        btn:SetPoint("TOPLEFT", 14 + (i - 1) * 74, -34)
        btn.key = key
        f.tabs[i] = btn
    end
    f.costs = {}
    for i, label in ipairs(COSTS) do
        -- "All" is no cost filter (nil). (Not `i == 1 and nil or ...`: that's
        -- never nil in Lua, it gave -1 and hid every card.)
        local cost
        if i > 1 then cost = i - 2 end
        local btn = W.Button(f, label, i == 1 and 36 or 26, function()
            f.filterCost = cost
            f.page = 1
            D.Refresh(f)
        end, 20)
        btn:SetPoint("TOPLEFT", 170 + (i == 1 and 0 or 40 + (i - 2) * 28), -34)
        btn.cost = cost
        f.costs[i] = btn
    end

    -- The card grid.
    f.cards = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            local card = ns.HearthstonePage.MakeCard(f, CARD_W, CARD_H)
            card:SetPoint("TOPLEFT", 14 + (c - 1) * (CARD_W + 8), -62 - (r - 1) * (CARD_H + 8))
            card.count = W.Label(card.top or card, "", "GameFontHighlight")
            card.count:SetPoint("TOP", card, "BOTTOM", 0, 14)
            local cf = card.count:GetFont()
            if cf then card.count:SetFont(cf, 11, "OUTLINE") end
            card:SetScript("OnClick", function() D.Add(f, card.key) end)
            table.insert(f.cards, card)
        end
    end
    f.prev = W.Button(f, "<", 30, function() f.page = f.page - 1 D.Refresh(f) end, 22)
    f.prev:SetPoint("TOPLEFT", 150, -372)
    f.pageText = W.Label(f, "", "GameFontHighlight")
    f.pageText:SetPoint("LEFT", f.prev, "RIGHT", 10, 0)
    f.next = W.Button(f, ">", 30, function() f.page = f.page + 1 D.Refresh(f) end, 22)
    f.next:SetPoint("LEFT", f.pageText, "RIGHT", 10, 0)
    f.hint = W.Label(f, "Click a card to add it. Click a card in your deck to take it out.", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", 14, 30)

    -- The deck.
    f.name = CreateFrame("EditBox", nil, side, "InputBoxTemplate")
    f.name:SetSize(200, 20)
    f.name:SetPoint("TOPLEFT", 16, -12)
    f.name:SetAutoFocus(false)
    f.name:SetMaxLetters(24)
    f.name:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    f.name:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    f.countText = W.Label(side, "", "GameFontNormal")
    f.countText:SetPoint("TOPRIGHT", -12, -16)
    f.list = W.ScrollList(side, 18, function(row)
        row.cost = W.Label(row, "", "GameFontNormalSmall")
        row.cost:SetPoint("LEFT", 4, 0)
        row.cost:SetWidth(18)
        row.cost:SetTextColor(0.5, 0.75, 1)
        row.name = W.Label(row, "", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", 26, 0)
        row.name:SetPoint("RIGHT", -28, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.copies = W.Label(row, "", "GameFontNormalSmall")
        row.copies:SetPoint("RIGHT", -6, 0)
        row:EnableMouse(true)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.12)
        row:SetScript("OnMouseUp", function() D.Remove(f, row.key) end)
        row:SetScript("OnEnter", function()
            page.preview:SetCard(row.key)
            page.preview:SetFrameLevel(f:GetFrameLevel() + 20)
            page.preview:ClearAllPoints()
            page.preview:SetPoint("RIGHT", side, "LEFT", -6, 0)
            page.preview:Show()
        end)
        row:SetScript("OnLeave", function()
            page.preview:Hide()
            page.preview:ClearAllPoints()
            page.preview:SetPoint("LEFT", 6, 8)
            page.preview:SetFrameLevel(b:GetFrameLevel() + 40)
        end)
    end)
    f.list:Inset(8, -40, 8, 84)
    f.save = W.Button(side, "Save", 80, function() D.Save(f) end, 22)
    f.save:SetPoint("BOTTOMLEFT", 10, 34)
    f.fill = W.Button(side, "Auto-fill", 80, function() D.AutoFill(f) end, 22)
    f.fill:SetPoint("LEFT", f.save, "RIGHT", 6, 0)
    W.Tooltip(f.fill, "Auto-fill", "Fill the rest of the deck from the basic deck, then other cards.")
    f.clear = W.Button(side, "Clear", 80, function() wipe(f.deck) D.Refresh(f) end, 22)
    f.clear:SetPoint("BOTTOMLEFT", 10, 8)
    f.back = W.Button(side, "Cancel", 80, function() D.Close(f) end, 22)
    f.back:SetPoint("LEFT", f.clear, "RIGHT", 6, 0)
    f.page, f.owner = 1, page
    f:Hide()
    return f
end

-- Open the builder for `heroKey`: a saved deck (`index`) or a new one.
function D.Open(page, heroKey, index)
    page.deckBuilder = page.deckBuilder or Build(page)
    local f = page.deckBuilder
    local saved = index and D.Saved()[index]
    f.hero, f.index = heroKey, index
    f.deck = {}
    for i, key in ipairs(saved and saved.cards or {}) do f.deck[i] = key end
    local h = HS().Heroes[heroKey]
    f.name:SetText(saved and saved.name or ("My " .. h.name:match("^%S+") .. " deck"))
    f.title:SetText((saved and "Edit deck" or "New deck") .. ": " .. h.name)
    f.filterClass, f.filterCost, f.page = "class", nil, 1
    f.tabs[1]:SetText(HS().ClassOf(heroKey):gsub("^%l", string.upper))
    f:Show()
    D.Refresh(f)
    return f
end

function D.Close(f)
    f:Hide()
    f.owner:ShowDecks(f.hero)
end

function D.Add(f, key)
    if not key then return end
    if #f.deck >= HS().DECK_SIZE then return f.owner:Say("Your deck is full") end
    if Count(f.deck, key) >= HS().MaxCopies(key) then return f.owner:Say("No more copies of that card") end
    table.insert(f.deck, key)
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
    D.Refresh(f)
end

function D.Remove(f, key)
    for i = #f.deck, 1, -1 do
        if f.deck[i] == key then
            table.remove(f.deck, i)
            break
        end
    end
    D.Refresh(f)
end

-- The basic deck's cards first, then anything that still fits.
function D.AutoFill(f)
    local size = HS().DECK_SIZE
    local function Try(key)
        if #f.deck < size and Count(f.deck, key) < HS().MaxCopies(key) then
            table.insert(f.deck, key)
            return true
        end
    end
    for _, key in ipairs(HS().DeckList(HS().Heroes[f.hero].deck)) do Try(key) end
    local pool = HS().Collection(f.hero)
    for _ = 1, 200 do
        if #f.deck >= size then break end
        Try(pool[math.random(#pool)])
    end
    D.Refresh(f)
end

function D.Save(f)
    local name = f.name:GetText()
    if not name or name:match("^%s*$") then name = "My deck" end
    local list = {}
    for i, key in ipairs(f.deck) do list[i] = key end
    local decks = D.Saved()
    if f.index and decks[f.index] then
        decks[f.index] = { name = name, hero = f.hero, cards = list }
    else
        table.insert(decks, { name = name, hero = f.hero, cards = list })
        f.index = #decks
    end
    W.PlaySound("IG_MAINMENU_OPTION")
    D.Close(f)
end

-- What the grid shows with the current filters.
local function Shown(f)
    local out = {}
    for _, key in ipairs(HS().Collection(f.hero)) do
        local c = Card(key)
        local classOk = (f.filterClass == "neutral") == (c.class == "neutral")
        local costOk = f.filterCost == nil or (f.filterCost >= 7 and c.cost >= 7) or c.cost == f.filterCost
        if classOk and costOk then table.insert(out, key) end
    end
    return out
end
D.Shown = Shown

function D.Refresh(f)
    local list = Shown(f)
    local per = COLS * ROWS
    local pages = math.max(1, math.ceil(#list / per))
    f.page = math.max(1, math.min(f.page, pages))
    for i, card in ipairs(f.cards) do
        local key = list[(f.page - 1) * per + i]
        card:SetShown(key ~= nil)
        if key then
            card:SetCard(key)
            local n, max = Count(f.deck, key), HS().MaxCopies(key)
            card.count:SetText(n > 0 and (n .. "/" .. max) or "")
            local full = n >= max
            card.frame:SetAlpha(full and 0.45 or 1)
            card.art:SetAlpha(full and 0.45 or 1)
            if card.model then card.model:SetAlpha(full and 0.45 or 1) end
        end
    end
    f.pageText:SetText("Page " .. f.page .. "/" .. pages)
    f.prev:SetEnabled(f.page > 1)
    f.next:SetEnabled(f.page < pages)
    for _, btn in ipairs(f.tabs) do btn:SetEnabled(btn.key ~= f.filterClass) end
    for _, btn in ipairs(f.costs) do btn:SetEnabled(btn.cost ~= f.filterCost) end

    -- The deck, by cost.
    local keys, counts = {}, {}
    for _, key in ipairs(f.deck) do
        if not counts[key] then table.insert(keys, key) end
        counts[key] = (counts[key] or 0) + 1
    end
    table.sort(keys, function(a, b)
        local ca, cb = Card(a), Card(b)
        if ca.cost ~= cb.cost then return ca.cost < cb.cost end
        return ca.name < cb.name
    end)
    for i, key in ipairs(keys) do
        local row = f.list:Row(i)
        row.key = key
        local c = Card(key)
        row.cost:SetText(tostring(c.cost))
        row.name:SetText(c.name)
        if c.class ~= "neutral" then row.name:SetTextColor(0.75, 0.75, 1) else row.name:SetTextColor(1, 1, 1) end
        row.copies:SetText(counts[key] > 1 and ("x" .. counts[key]) or "")
    end
    f.list:SetCount(#keys)
    local n = #f.deck
    f.countText:SetText(n .. "/" .. HS().DECK_SIZE)
    if n == HS().DECK_SIZE then f.countText:SetTextColor(0.4, 1, 0.4) else f.countText:SetTextColor(1, 0.82, 0) end
    f.fill:SetEnabled(n < HS().DECK_SIZE)
    f.clear:SetEnabled(n > 0)
end
